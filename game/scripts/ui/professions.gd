class_name UIProfessions
## The Professions workshop (redesign 2026-09-20): a two-pane bench instead of
## the old dense recipe ledger. LEFT — a 240px rail of the three trade cards
## (browse-only; selecting never spends or swaps) plus the Alchemy brewing
## entry. RIGHT — the selected trade's header (mastery band + climb, and an
## explicit Choose/Swap action when it is not active), a Craft gear / Blueprints
## tab pair, a slot selector and F–A grade strip, and ONE focused recipe detail
## with a single Craft call to action. A static builder taking the Menus
## instance, like ui/alchemy.gd and ui/wardrobe.gd.
##
## The heavy lifting is in Professions (logic) + balance.gd (knobs); this file
## is pure display + the click-throughs. All ACTIONS — locking a trade,
## crafting, buying a blueprint — gate on being AT Crownfall (chapter_id ==
## "capital"), the capital-is-the-shop law; the panel still SHOWS your progress
## anywhere. Clean potion brewing lives in ui/alchemy.gd. Browsing state lives
## only in the refresh `view` Dictionary: a fresh external open(m) always
## resets to the active trade and its defaults, so nothing persists across
## hero/world/seed.

const CRAFT_GRADES := ["F", "E", "D", "C", "B", "A"]  # S is drop-only (never craftable)
const TABS := ["craft", "blueprints"]

# Body/action text stays bright even for an F recipe; grade color is only ever
# an accent (tab underline, grade chip, card edge) — never the reading color.
const TEXT_BRIGHT := Color(0.94, 0.95, 0.98)
const TEXT_BODY := Color(0.85, 0.87, 0.92)
const GOOD := Color(0.72, 0.92, 0.76)
const BAD := Color(1.0, 0.70, 0.52)

const TRADE_ROLE := {
	"blacksmith": "Weapons · Helmets",
	"alchemist": "Charms · Gloves · Potions",
	"tailor": "Armor · Pants · Boots",
}


## `msg`/`msg_color` show the last in-place action's result; `slot` is the
## legacy focus hint (kept for signature compatibility — external callers use
## open(m) only). `view` is the same-panel browse state {trade, slot, grade,
## tab, focus}; unknown or missing keys fall back to the active-trade defaults.
static func open(m: Menus, msg := "", msg_color := Color(0.8, 0.85, 1.0), slot := "",
		view: Dictionary = {}) -> void:
	var g := m.game
	if not is_instance_valid(g) or not g.has_local_player():
		return
	var p: Player = g.local_player
	var at_capital: bool = g.chapter_id == "capital"
	var state := _state(p, slot, view)
	var vbox := m._open("Professions", 1180, 660, true)
	m.current = "professions"
	var shell: Control = m.root
	# Every deferred browse/focus callback re-verifies this exact shell, hero,
	# world and seed — a menu NAME match alone never authorizes anything.
	var token := {
		"game": g.get_instance_id(),
		"player": p.get_instance_id(),
		"world": g.world.get_instance_id() if is_instance_valid(g.world) else 0,
		"seed": g.wander_seed,
	}

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)
	_trade_rail(m, body, shell, token, p, state)
	_workbench(m, body, shell, token, p, at_capital, state)

	# The result notice is its own visible bottom row, preserved with the
	# selection through every transaction rebuild.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	vbox.add_child(foot)
	var notice_text := msg if msg != "" else "Crafted work goes to your pack — or your mailbox when the pack is full."
	var notice := m._lbl(foot, notice_text, 16, msg_color if msg != "" else UITheme.TEXT_MUTED)
	notice.name = "ProfResult"
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.custom_minimum_size = Vector2(520, 40)
	var purse := m._lbl(foot, "Gold %d   ·   Pack %d / %d" % [p.gold, p.bag_used(), p.bag_capacity()],
		16, Color(1.0, 0.85, 0.35))
	purse.name = "ProfPurse"
	purse.autowrap_mode = TextServer.AUTOWRAP_OFF
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	purse.custom_minimum_size.x = 250
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m._hint(vbox)
	_restore(m, shell, token, state)


## Resolve the browse view: every field validated against real data, missing or
## stale fields reset to the active trade (or Blacksmith pre-lock) defaults.
static func _state(p: Player, slot_hint: String, view: Dictionary) -> Dictionary:
	var state := {"trade": "", "slot": "", "grade": "", "tab": "craft", "focus": "", "blueprint_grade": "B"}
	for key in state.keys():
		if view.has(key):
			state[key] = String(view[key])
	if not (String(state.trade) in Balance.PROFESSION_ORDER):
		state.trade = p.profession if p.profession != "" else String(Balance.PROFESSION_ORDER[0])
	var slots: Array = Professions.slots_of(String(state.trade))
	if not (String(state.slot) in slots):
		state.slot = slot_hint if slot_hint in slots else String(slots[0])
	if not (String(state.grade) in CRAFT_GRADES):
		state.grade = "F"
		if String(state.trade) == p.profession:
			for index in range(CRAFT_GRADES.size() - 1, -1, -1):
				var candidate := String(CRAFT_GRADES[index])
				if Professions.craft_blocked(p, String(state.slot), candidate) == "":
					state.grade = candidate
					break
	if not (String(state.tab) in TABS):
		state.tab = "craft"
	if not (String(state.blueprint_grade) in Items.BLUEPRINT_GRADES):
		state.blueprint_grade = "B"
	return state


## Bind an action to the actual visible bench and owning hero/world. The
## screen owns the gesture lifetime; Professions still owns recipe economics.
static func _action_scope(m: Menus) -> Dictionary:
	if not is_instance_valid(m) or not is_instance_valid(m.game) \
			or not m.game.has_local_player() or not is_instance_valid(m.game.world) \
			or not is_instance_valid(m.root):
		return {}
	return {"game": weakref(m.game), "player": weakref(m.game.local_player),
		"world": weakref(m.game.world), "shell": weakref(m.root),
		"seed": m.game.wander_seed}


## Claim the whole panel once before the first transaction. Replaced and
## fading roots can still exist this frame; none may act on their successor.
static func _claim_action(m: Menus, scope: Dictionary) -> bool:
	if not is_instance_valid(m) or m.is_queued_for_deletion() or scope.is_empty():
		return false
	var g: Game = scope.game.get_ref() as Game
	var p: Player = scope.player.get_ref() as Player
	var world: Node2D = scope.world.get_ref() as Node2D
	var shell: Control = scope.shell.get_ref() as Control
	if not is_instance_valid(g) or not is_instance_valid(p) \
			or not is_instance_valid(world) or not is_instance_valid(shell):
		return false
	if g.is_queued_for_deletion() or p.is_queued_for_deletion() \
			or world.is_queued_for_deletion() or shell.is_queued_for_deletion():
		return false
	if m.game != g or m.root != shell or m.current != "professions" \
			or g.local_player != p or p.game != g or g.world != world \
			or g.wander_seed != int(scope.seed):
		return false
	if g.dedicated or g.chapter_id != "capital" or g.pvp_active \
			or not g.play_started or g.state != Game.ST_PLAYING \
			or p.dead or p.downed or p.ghost or p.hp <= 0.0:
		return false
	if bool(shell.get_meta("professions_action_claimed", false)):
		return false
	shell.set_meta("professions_action_claimed", true)
	return true


## Browse authority for the SAME live panel: exact shell + owning hero, world
## and seed. Weakrefs are unnecessary — only currently-valid nodes are compared.
static func _owns(m: Variant, shell: Variant, token: Dictionary) -> bool:
	if not is_instance_valid(m) or m.is_queued_for_deletion():
		return false
	if not is_instance_valid(shell) or shell.is_queued_for_deletion():
		return false
	if m.root != shell or m.current != "professions":
		return false
	var g: Game = m.game
	if not is_instance_valid(g) or g.is_queued_for_deletion() or not g.has_local_player():
		return false
	if not is_instance_valid(g.world) or g.world.is_queued_for_deletion():
		return false
	if g.local_player.is_queued_for_deletion() or g.local_player.game != g:
		return false
	return g.get_instance_id() == int(token.game) \
		and g.local_player.get_instance_id() == int(token.player) \
		and g.world.get_instance_id() == int(token.world) \
		and g.wander_seed == int(token.seed)


## Same-panel refresh: current selection + the caller's changes. Never fires
## against a replaced shell or a different hero/world/seed.
static func _reopen(m: Menus, shell: Variant, token: Dictionary, state: Dictionary,
		changes: Dictionary) -> void:
	if not _owns(m, shell, token):
		return
	var view: Dictionary = state.duplicate(true)
	view.merge(changes, true)
	open(m, "", Color(0.8, 0.85, 1.0), "", view)


# -------------------------------------------------------------- trade rail ---

static func _trade_rail(m: Menus, parent: Control, shell: Control, token: Dictionary,
		p: Player, state: Dictionary) -> void:
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 240
	rail.add_theme_constant_override("separation", 10)
	parent.add_child(rail)
	UITheme.header(m._lbl(rail, "TRADES", 16, UITheme.GOLD_BRIGHT))
	for raw in Professions.trades():
		var trade := String(raw)
		var active: bool = trade == p.profession
		var selected: bool = trade == String(state.trade)
		var card := m._btn(rail, "", func() -> void:
			_reopen(m, shell, token, state, {"trade": trade, "slot": "", "grade": "",
				"focus": "ProfTrade_" + trade}), TEXT_BRIGHT)
		_selection_style(card, selected, GOOD if active else UITheme.GOLD, true)
		card.name = "ProfTrade_" + trade
		card.custom_minimum_size = Vector2(240, 104)
		var contents := VBoxContainer.new()
		contents.position = Vector2(14, 10)
		contents.size = Vector2(212, 84)
		contents.add_theme_constant_override("separation", 5)
		card.add_child(contents)
		var title := m._lbl(contents, Professions.trade_name(trade) + (" · Active" if active else ""), 17, TEXT_BRIGHT)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		m._lbl(contents, String(TRADE_ROLE[trade]), 14, TEXT_BODY)
		var points := Professions.points(p, trade)
		m._lbl(contents, "%s · %d mastery" % [Balance.mastery_band(points), points], 14, UITheme.TEXT_MUTED)
		_ignore_pointer(contents)
		card.tooltip_text = "Browse only. Changing your active trade requires the explicit Choose or Activate action."
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(gap)
	var brew_icon: Texture2D = Art.consumable_icon({"sprite": "consumables/apprentices_health_potion"})
	var brew := m._btn(rail, "", func() -> void:
		if _owns(m, shell, token):
			m.open_alchemy(), TEXT_BRIGHT)
	_selection_style(brew, false)
	brew.name = "ProfessionsAlchemy"
	brew.custom_minimum_size = Vector2(240, 64)
	var brewing := HBoxContainer.new()
	brewing.position = Vector2(12, 8)
	brewing.size = Vector2(216, 48)
	brewing.add_theme_constant_override("separation", 10)
	brew.add_child(brewing)
	_icon(brewing, brew_icon, 48)
	var brewing_text := m._lbl(brewing, "Alchemy bench", 17, TEXT_BRIGHT)
	brewing_text.custom_minimum_size.x = 150
	brewing_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ignore_pointer(brewing)
	brew.tooltip_text = "Browse and brew potions. Brewing requires Alchemist active in Crownfall."


## Navigation stays quiet; the filled gold treatment belongs to paid actions.
static func _selection_style(button: Button, selected: bool, accent := UITheme.GOLD,
		rail := false) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.13, 0.17) if selected else Color(0.055, 0.065, 0.085)
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(12)
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	if selected:
		normal.border_color = accent
		if rail: normal.border_width_left = 3
		else: normal.border_width_bottom = 2
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.15, 0.17, 0.21)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", TEXT_BRIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", TEXT_BRIGHT)


static func _primary_style(button: Button) -> void:
	var bold := UITheme.body_bold_font()
	if bold != null: button.add_theme_font_override("font", bold)
	var normal := StyleBoxFlat.new()
	normal.bg_color = UITheme.GOLD
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(12)
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = UITheme.GOLD_BRIGHT
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.09, 0.105, 0.135)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.08, 0.065, 0.035))
	button.add_theme_color_override("font_disabled_color", Color(0.66, 0.69, 0.75))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _detail_card(parent: Control, accent: Color) -> PanelContainer:
	var card := UITheme.card(parent, accent)
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	card.add_theme_stylebox_override("panel", style)
	return card


static func _ignore_pointer(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_pointer(child as Control)


static func _workbench(m: Menus, parent: Control, shell: Control, token: Dictionary,
		p: Player, at_capital: bool, state: Dictionary) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)
	var trade := String(state.trade)
	_trade_header(m, column, p, at_capital, trade, state)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for spec in [["craft", "Craft gear"], ["blueprints", "Blueprints"]]:
		var key := String(spec[0])
		var tab := m._btn(tabs, String(spec[1]), func() -> void:
			_reopen(m, shell, token, state, {"tab": key, "focus": "ProfTab_" + key}), TEXT_BRIGHT)
		_selection_style(tab, String(state.tab) == key)
		tab.name = "ProfTab_" + key
		tab.add_theme_font_size_override("font_size", 16)
		tab.custom_minimum_size = Vector2(170, 44)
	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 24)
	column.add_child(selectors)
	var slot_group := VBoxContainer.new()
	selectors.add_child(slot_group)
	m._lbl(slot_group, "GEAR SLOT", 14, UITheme.TEXT_MUTED)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	slot_group.add_child(slots)
	for raw in Professions.slots_of(trade):
		var cslot := String(raw)
		var button := m._btn(slots, cslot.capitalize(), func() -> void:
			_reopen(m, shell, token, state, {"slot": cslot, "focus": "ProfSlot_" + cslot}), TEXT_BRIGHT)
		_selection_style(button, cslot == String(state.slot))
		button.name = "ProfSlot_" + cslot
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(102, 44)
	var grade_group := VBoxContainer.new()
	selectors.add_child(grade_group)
	m._lbl(grade_group, "QUALITY" if String(state.tab) == "craft" else "BLUEPRINT", 14, UITheme.TEXT_MUTED)
	var grades := HBoxContainer.new()
	grades.add_theme_constant_override("separation", 5)
	grade_group.add_child(grades)
	var crafting: bool = String(state.tab) == "craft"
	var choices: Array = CRAFT_GRADES if crafting else Items.BLUEPRINT_GRADES
	for raw in choices:
		var grade := String(raw)
		var field := "grade" if crafting else "blueprint_grade"
		var name := ("ProfGrade_" if crafting else "ProfBlueprintGrade_") + grade
		var button := m._btn(grades, grade, func() -> void:
			var changes := {"focus": name}
			changes[field] = grade
			_reopen(m, shell, token, state, changes), TEXT_BRIGHT)
		_selection_style(button, grade == String(state[field]), Items.GRADE_COLOR[grade])
		button.name = name
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(46, 44)
	if crafting:
		_craft_pane(m, column, shell, token, p, at_capital, state)
	else:
		_blueprint_pane(m, column, p, at_capital, trade, state)


static func _trade_header(m: Menus, column: VBoxContainer, p: Player, at_capital: bool,
		trade: String, state: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	var title := m._lbl(words, Professions.trade_name(trade),
		20, TEXT_BRIGHT)
	title.name = "ProfTradeName"
	title.custom_minimum_size.x = 420
	UITheme.header(title)
	var mpts := Professions.points(p, trade)
	var band := Balance.mastery_band(mpts)
	var tonext := Balance.mastery_to_next(mpts)
	var climb := "Mastered" if tonext <= 0 else "%d to %s" % [tonext, _next_band(band)]
	var mastery := m._lbl(words, "%s · %d mastery · Craft up to %s · %s" % [band, mpts,
		Balance.mastery_max_grade(mpts), climb], 14, TEXT_BODY)
	mastery.name = "ProfMastery"
	mastery.custom_minimum_size.x = 420
	words.add_child(_band_bar(mpts))
	if trade != p.profession:
		var free_lock := p.profession == ""
		var cost := 0 if free_lock else Professions.swap_cost(p)
		var caption := "Choose %s — free" % Professions.trade_name(trade) if free_lock \
			else "Activate — %d gold" % cost
		var enabled := at_capital and (free_lock or p.gold >= cost)
		var act := m._btn(head, caption, _lock_cb(m, trade, state),
			UITheme.GOLD_BRIGHT if enabled else UITheme.TEXT_MUTED, enabled)
		act.name = "ProfActivate"
		_primary_style(act)
		act.add_theme_font_size_override("font_size", 16)
		act.custom_minimum_size = Vector2(280, 46)
		act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		act.alignment = HORIZONTAL_ALIGNMENT_CENTER
		act.tooltip_text = ("Visit Crownfall to activate a trade. " if not at_capital else "") \
			+ "Mastery persists across swaps. The swap price doubles with each swap this week and resets at the weekly turn."



## Fraction of the way from the current band's threshold to the next band's.
static func _band_progress(pts: int) -> float:
	var band := Balance.mastery_band(pts)
	var idx: int = Balance.MASTERY_BANDS.find(band)
	if idx < 0 or idx >= Balance.MASTERY_BANDS.size() - 1:
		return 1.0
	var lo := int(Balance.MASTERY_THRESHOLDS[band])
	var hi := int(Balance.MASTERY_THRESHOLDS[Balance.MASTERY_BANDS[idx + 1]])
	return clampf(float(pts - lo) / float(maxi(1, hi - lo)), 0.0, 1.0)


static func _next_band(band: String) -> String:
	var idx: int = Balance.MASTERY_BANDS.find(band)
	if idx < 0 or idx >= Balance.MASTERY_BANDS.size() - 1:
		return band
	return String(Balance.MASTERY_BANDS[idx + 1])


## A thin gold mastery bar — restrained, no per-row borders.
static func _band_bar(pts: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = _band_progress(pts)
	bar.custom_minimum_size = Vector2(320, 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = UITheme.SURFACE
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.GOLD
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# ------------------------------------------------------------------- craft ---

static func _craft_pane(m: Menus, column: VBoxContainer, shell: Control, token: Dictionary,
		p: Player, at_capital: bool, state: Dictionary) -> void:
	var cslot := String(state.slot)
	var grade := String(state.grade)
	var grade_color: Color = Items.GRADE_COLOR[grade]
	var fam := Balance.craft_material(cslot)
	var need := int(Balance.CRAFT_MATERIAL_COST.get(grade, 0))
	var fee := int(Balance.CRAFT_GOLD_FEE.get(grade, 0))
	var have := p.material_count(fam, grade)
	var gain := int(Balance.CRAFT_MASTERY_BY_GRADE.get(grade, 0))
	var blocked := Professions.craft_blocked(p, cslot, grade)
	if not at_capital:
		blocked = "Visit the Crownfall benches to craft."
	elif p.profession != String(state.trade):
		blocked = "Activate %s to craft its recipes." % Professions.trade_name(String(state.trade))
	var enabled: bool = at_capital and p.profession == String(state.trade) and blocked == ""

	var card := _detail_card(column, grade_color)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	# The illustration plate: the 128px painted codex master shown at 64px
	# (>=2x source fidelity), with the grade chip as the only colored marker.
	var plate := PanelContainer.new()
	var plate_sb := StyleBoxFlat.new()
	plate_sb.bg_color = UITheme.SURFACE_RAISED
	plate_sb.set_corner_radius_all(9)
	plate_sb.set_content_margin_all(14.0)
	plate.add_theme_stylebox_override("panel", plate_sb)
	plate.custom_minimum_size = Vector2(140, 118)
	row.add_child(plate)
	var plate_box := VBoxContainer.new()
	plate_box.add_theme_constant_override("separation", 6)
	plate_box.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(plate_box)
	var art_row := CenterContainer.new()
	plate_box.add_child(art_row)
	_icon(art_row, Art.codex_item_icon(cslot, grade, _class_noun(p.cls, cslot)), 64)
	var chip := m._lbl(plate_box, "Grade %s" % grade, 14, grade_color)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 5)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title := m._lbl(words, "%s — grade %s" % [cslot.capitalize(), grade], 18, TEXT_BRIGHT)
	title.name = "ProfRecipeName"
	title.custom_minimum_size.x = 460
	var summary := "%s gear · attributes vary with each craft" % p.cls.capitalize()
	if grade == "A":
		summary += " · may become a named masterpiece"
	var fit := m._lbl(words, summary, 16, TEXT_BODY)
	fit.custom_minimum_size.x = 460
	var ing := HBoxContainer.new()
	ing.add_theme_constant_override("separation", 10)
	words.add_child(ing)
	_icon(ing, Art.material_ui_icon(fam, grade), 40)
	var mat_name := String(Items.MATERIALS.get(fam, {}).get(grade, fam.capitalize()))
	var mat := m._lbl(ing, "%s · grade %s" % [mat_name, grade], 16, TEXT_BODY)
	mat.custom_minimum_size.x = 250
	mat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var counts := m._lbl(ing, "Have %d / Need %d" % [have, need], 16, GOOD if have >= need else BAD)
	counts.name = "ProfIngredient"
	counts.autowrap_mode = TextServer.AUTOWRAP_OFF
	counts.custom_minimum_size.x = 180
	counts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var costs := m._lbl(words, "Fee %d gold · +%d mastery" % [fee, gain],
		16, UITheme.GOLD_BRIGHT)
	costs.name = "ProfCosts"
	costs.custom_minimum_size.x = 460
	if blocked != "" or not at_capital:
		var why := blocked if blocked != "" \
			else "The benches are in Crownfall — travel to the capital (⌂) to craft."
		var reason := m._lbl(words, why, 16, BAD)
		reason.name = "ProfBlocked"
		reason.custom_minimum_size.x = 460

	var craft := m._btn(column, "Craft %s %s — %d gold" % [grade, cslot.capitalize(), fee],
		_craft_cb(m, cslot, grade, state), UITheme.GOLD_BRIGHT if enabled else UITheme.TEXT_MUTED, enabled)
	_primary_style(craft)
	craft.name = "ProfCraft"
	craft.add_theme_font_size_override("font_size", 17)
	craft.custom_minimum_size = Vector2(320, 46)
	craft.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	craft.alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft.tooltip_text = "Spends %d %s (grade %s) and %d gold. The piece goes to your pack, or your mailbox if the pack is full." \
		% [need, fam, grade, fee]


## Deterministic class-fit noun for the DETAIL ART only (first entry of the
## class matrix — no RNG, and the text never promises this exact make).
static func _class_noun(cls: String, slot: String) -> String:
	if slot == "weapon":
		return Items.class_weapon_noun(cls)
	var per_class: Dictionary = Items.CLASS_GEAR.get(cls, {})
	var shapes: Array = per_class.get(slot, [])
	return String(shapes[0]) if not shapes.is_empty() else ""


# -------------------------------------------------------------- blueprints ---

static func _blueprint_pane(m: Menus, column: VBoxContainer, p: Player, at_capital: bool,
		trade: String, state: Dictionary) -> void:
	var bslot := String(state.slot)
	var grade := String(state.blueprint_grade)
	var price := Balance.blueprint_price(bslot, grade)
	var known := p.has_blueprint(bslot, grade)
	var mine: bool = trade == p.profession
	var enabled: bool = at_capital and mine and p.gold >= price and not known
	var card := _detail_card(column, Items.GRADE_COLOR[grade])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	var art := CenterContainer.new()
	art.custom_minimum_size = Vector2(140, 150)
	row.add_child(art)
	_icon(art, Art.codex_item_icon(bslot, grade, _class_noun(p.cls, bslot)), 64)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	row.add_child(words)
	m._lbl(words, "Generic %s %s blueprint" % [grade, bslot.capitalize()], 18, TEXT_BRIGHT)
	m._lbl(words, "Unlocks grade-%s %s crafting. Requires %s mastery to craft." %
		[grade, bslot.to_lower(), _required_band(grade)], 16, TEXT_BODY)
	m._lbl(words, "Learn at the bench or find the blueprint on a boss.", 16, TEXT_BODY)
	m._lbl(words, "Price %d gold" % price, 16, UITheme.GOLD_BRIGHT)
	if known:
		var label := m._lbl(words, "Known · ready when your mastery permits", 16, GOOD)
		label.name = "ProfKnown_" + grade
	elif not enabled:
		var reason := "Activate %s to learn its recipes." % Professions.trade_name(trade)
		if not at_capital:
			reason = "Visit the Crownfall benches to learn blueprints."
		elif mine:
			reason = "Needs %d gold." % price
		m._lbl(words, reason, 16, BAD)
	var learn := m._btn(column, "Blueprint known" if known else "Learn blueprint — %d gold" % price,
		_buy_cb(m, bslot, grade, state), UITheme.GOLD_BRIGHT if enabled else UITheme.TEXT_MUTED, enabled)
	_primary_style(learn)
	learn.name = "ProfLearn"
	learn.add_theme_font_size_override("font_size", 17)
	learn.custom_minimum_size = Vector2(320, 46)
	learn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


static func _required_band(grade: String) -> String:
	for raw in Balance.MASTERY_BANDS:
		var band := String(raw)
		if Items.GRADES.find(grade) <= Items.GRADES.find(String(Balance.MASTERY_BAND_MAX_GRADE[band])):
			return band
	return "Master"


static func _icon(parent: Control, texture: Texture2D, side: float) -> void:
	# Never enlarge a legacy 32px fallback into a painted material tile.
	if texture == null or texture.get_width() < side * 2.0 or texture.get_height() < side * 2.0:
		return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


# ------------------------------------------------------------ transactions ---

static func _lock_cb(m: Menus, trade: String, state: Dictionary) -> Callable:
	var scope := _action_scope(m)
	var view: Dictionary = state.duplicate(true)
	view.focus = "ProfActivate"
	return func() -> void:
		if not _claim_action(m, scope):
			return
		var p: Player = m.game.local_player
		var r := Professions.lock_trade(p, trade)
		if not r["ok"]:
			open(m, String(r["reason"]), BAD, "", view)
			return
		m.game.sfx("equip")
		m.game.autosave()
		var paid := "" if int(r["cost"]) == 0 else "   (-%d gold)" % int(r["cost"])
		open(m, "Locked %s.%s" % [Professions.trade_name(trade), paid], GOOD, "", view)


static func _craft_cb(m: Menus, cslot: String, grade: String, state: Dictionary) -> Callable:
	var scope := _action_scope(m)
	var view: Dictionary = state.duplicate(true)
	view.focus = "ProfCraft"
	return func() -> void:
		if not _claim_action(m, scope):
			return
		var g := m.game
		var p: Player = g.local_player
		if p.profession != String(view.trade) or not (cslot in Professions.slots_of(String(view.trade))):
			open(m, "Activate the selected trade before crafting.", BAD, "", view)
			return
		var r := Professions.craft(p, cslot, grade, g.loot_rng)
		if not r["ok"]:
			open(m, String(r["reason"]), BAD, "", view)
			return
		var item: Dictionary = r["item"]
		var banked := p.add_item(item)
		if not banked:
			g.send_mail("Your crafted gear",
				"The bench was ready but your bag was full — the piece waits here.",
				[{"kind": "item", "item": item}])
		g.sfx("chest")
		p.recalc()
		g.autosave()
		var tag := "Promoted to a NAMED unique!  " if bool(r["promoted"]) else ""
		var mailed := "" if banked else "   (mailed — bag was full)"
		open(m, "%sCrafted %s  (+%d mastery)%s" % [tag, Items.title(item), int(r["mastery_gain"]), mailed],
			Color(1.0, 0.85, 0.4) if bool(r["promoted"]) else GOOD, "", view)


static func _buy_cb(m: Menus, bslot: String, grade: String, state: Dictionary) -> Callable:
	var scope := _action_scope(m)
	var view: Dictionary = state.duplicate(true)
	view.focus = "ProfLearn"
	return func() -> void:
		if not _claim_action(m, scope):
			return
		var p: Player = m.game.local_player
		if p.profession != String(view.trade) or not (bslot in Professions.slots_of(String(view.trade))):
			open(m, "Activate the selected trade before learning its recipes.", BAD, "", view)
			return
		var r := Professions.buy_blueprint(p, bslot, grade)
		if not r["ok"]:
			open(m, String(r["reason"]), BAD, "", view)
			return
		m.game.sfx("chest")
		m.game.autosave()
		open(m, "Learned Generic %s %s.   (-%d gold)" % [grade, bslot.capitalize(), int(r["cost"])],
			GOOD, "", view)


# ------------------------------------------------------------------- focus ---

## Deferred focus restore. Re-verifies the exact shell/hero/world/seed after
## the frame wait — a newer menu or a replaced world is never touched. After a
## successful transaction the SAME action refocuses if still enabled; when it
## is gone or disabled, focus falls back to the (non-payable) selected grade or
## tab, so a repeated accept can never spend a different transaction.
static func _restore(m: Menus, shell: Control, token: Dictionary, state: Dictionary) -> void:
	var menu_ref: WeakRef = weakref(m)
	var shell_ref: WeakRef = weakref(shell)
	await m.get_tree().process_frame
	var live_menu: Variant = menu_ref.get_ref()
	var live_shell: Variant = shell_ref.get_ref()
	if not _owns(live_menu, live_shell, token):
		return
	var names: Array[String] = [String(state.focus),
		("ProfGrade_" + String(state.grade)) if String(state.tab) == "craft"
		else ("ProfBlueprintGrade_" + String(state.blueprint_grade)), "ProfTab_" + String(state.tab)]
	for name in names:
		if name == "":
			continue
		var control: Control = live_shell.find_child(name, true, false) as Control
		if control == null or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		control.grab_focus()
		return
