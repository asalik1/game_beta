class_name Menus extends CanvasLayer
## All full-screen menus: class select, inventory, skill tree, merchant
## shop, evolution choice, and keybinding. One menu open at a time;
## opening a menu pauses the game.

var game: Node2D
var root: Control = null          # the currently open panel (null = closed)
var current := ""
var listening_action := ""        # keybind screen: waiting for a key press
var shop_zone := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


func is_open() -> bool:
	return root != null


func close() -> void:
	if root:
		root.queue_free()
		root = null
	listening_action = ""
	# Boot menus unpause only once the game actually starts.
	if current != "class_select" and current != "title":
		get_tree().paused = false
	current = ""
	if game.play_started:
		game.autosave()  # menus are where gear/talents/purchases change


# ------------------------------------------------------------ scaffolding ---

func _open(title: String, w := 960.0, h := 560.0) -> VBoxContainer:
	if root:
		root.queue_free()
	get_tree().paused = true
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var frame := ColorRect.new()
	frame.color = Color(0.9, 0.8, 0.5)
	frame.position = Vector2(640 - w / 2 - 3, 360 - h / 2 - 3)
	frame.size = Vector2(w + 6, h + 6)
	root.add_child(frame)
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.08, 0.13, 0.98)
	panel.position = Vector2(640 - w / 2, 360 - h / 2)
	panel.size = Vector2(w, h)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = panel.position + Vector2(24, 16)
	vbox.size = Vector2(w - 48, h - 32)
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 26)
	tl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vbox.add_child(tl)
	return vbox


func _lbl(parent: Node, text: String, size := 15, color := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable, color := Color(1, 1, 1), enabled := true, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if icon:
		b.icon = icon
	if enabled:
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Row with a gear icon + colored text (for non-clickable item displays).
func _item_row(parent: Node, item: Dictionary, text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var icon := TextureRect.new()
	icon.texture = Art.icon_for(item)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	var l := _lbl(hbox, text, 14, Items.GRADE_COLOR[item["grade"]])
	# Wrapping labels inside an HBox collapse without a minimum width.
	l.custom_minimum_size = Vector2(320, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Hover tooltip comparing an item against what's equipped in its slot.
func _diff_tip(item: Dictionary) -> String:
	return Items.diff_text(item, game.player.equipment.get(item["slot"]))


func _hint(vbox: Node, text := "ESC to close") -> void:
	var l := _lbl(vbox, text, 13, Color(0.55, 0.55, 0.55))
	l.size_flags_vertical = Control.SIZE_SHRINK_END


# ------------------------------------------------------------ title screen ---

## Shown at boot when saves exist: continue a character or start fresh.
func open_title() -> void:
	var vbox := _open("EMBERFALL", 760, 560)
	current = "title"
	_lbl(vbox, "Chapter 1: The Hollow King", 15, Color(0.75, 0.75, 0.75))

	_lbl(vbox, "— CONTINUE —", 15, Color(0.95, 0.85, 0.5))
	for s in SaveGame.list():
		var slot: int = s["slot"]
		var cls_info: Dictionary = Classes.CLASSES.get(s["cls"], {})
		var cname: String = cls_info.get("name", s["cls"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)
		var icon: Texture2D = Art.tex(cls_info["sprite"]) if cls_info.has("sprite") else null
		var resume := func() -> void:
			if root:
				root.queue_free()
				root = null
			current = ""
			game.load_save(slot)
		var b := _btn(row, "  %s — Lv %d" % [cname, s["level"]], resume, Color(0.6, 1.0, 0.6), true, icon)
		b.custom_minimum_size = Vector2(360, 0)
		b.tooltip_text = Story.QUESTS.get(s["quest"], "")
		var when := Time.get_datetime_string_from_unix_time(s["saved_at"]).replace("T", "  ")
		var wl := _lbl(row, when, 12, Color(0.55, 0.58, 0.66))
		wl.custom_minimum_size = Vector2(170, 0)
		var erase := func() -> void:
			SaveGame.delete(slot)
			if SaveGame.list().is_empty():
				open_class_select()
			else:
				open_title()
		_btn(row, " ✕ ", erase, Color(1, 0.5, 0.5))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	_btn(vbox, "  ⚔  New Game  ", func() -> void: open_class_select(), Color(0.95, 0.85, 0.5))
	_hint(vbox, "Continue a saved hero, or forge a new one")


# ------------------------------------------------------------ class select ---

func open_class_select() -> void:
	var vbox := _open("Choose your class", 1180, 620)
	current = "class_select"
	_lbl(vbox, "This choice defines your four abilities and your three THEMES — elemental playstyles that change how your abilities behave, unlocked as you level.", 15, Color(0.75, 0.75, 0.75))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var idx := 1
	for id in Classes.CLASSES:
		var c: Dictionary = Classes.CLASSES[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(272, 0)
		col.add_theme_constant_override("separation", 6)
		hbox.add_child(col)

		var icon := TextureRect.new()
		icon.texture = Art.tex(c["sprite"])
		icon.custom_minimum_size = Vector2(96, 96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		col.add_child(icon)

		_lbl(col, c["name"], 20, Color(0.95, 0.85, 0.5))
		_lbl(col, c["desc"], 13, Color(0.8, 0.8, 0.8))
		if c.has("passive"):
			_lbl(col, "★ " + c["passive"]["text"], 12, Color(0.5, 0.95, 0.8))
		var theme_names: Array = []
		for theme in Classes.THEMES[id]:
			theme_names.append(theme["name"])
		_lbl(col, "Themes: " + " / ".join(theme_names), 12, Color(0.7, 0.8, 0.95))
		for slot in ["a1", "a2", "a3", "ult"]:
			var ab: Dictionary = c["abilities"][slot]
			var tag: String = "ULT" if slot == "ult" else slot.to_upper()
			_lbl(col, "%s %s — %s" % [tag, ab["name"], ab["desc"]], 12, Color(0.65, 0.7, 0.8))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		_btn(col, "  Choose %s  (%d)" % [c["name"], idx], func() -> void: pick_class(id), Color(0.6, 1.0, 0.6))
		idx += 1


func pick_class(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.on_class_chosen(id)


# --------------------------------------------------------------- inventory ---

func open_inventory(tab := "gear") -> void:
	var vbox := _open("Inventory — %d gold" % game.player.gold, 1120, 640)
	current = "inventory"

	# Subtabs: gear management / full character sheet.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Gear  ", func() -> void: open_inventory("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Stats  ", func() -> void: open_inventory("stats"),
		Color(0.95, 0.85, 0.5) if tab == "stats" else Color(0.6, 0.6, 0.6))
	if tab == "stats":
		_build_stats_tab(vbox, game.player)
		return
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	left.add_theme_constant_override("separation", 6)
	hbox.add_child(left)
	_lbl(left, "EQUIPPED", 16, Color(0.95, 0.85, 0.5))
	_lbl(left, "(click an item to manage its gem sockets)", 12, Color(0.55, 0.55, 0.6))
	for slot in Items.SLOTS:
		if game.player.equipment.has(slot):
			var item: Dictionary = game.player.equipment[slot]
			var open_cb := func() -> void:
				open_item_panel(item)
			# Title on a fixed-width clipped button; stats wrap in a label
			# below it — long S-item text can no longer blow up the layout.
			var b := _btn(left, Items.title(item), open_cb, Items.GRADE_COLOR[item["grade"]], true, Art.icon_for(item))
			b.custom_minimum_size = Vector2(430, 0)
			b.clip_text = true
			b.tooltip_text = Items.describe(item) + "\n\nClick to view sockets and remove/insert gems"
			var dl := _lbl(left, Items.describe(item), 12, Color(Items.GRADE_COLOR[item["grade"]], 0.8))
			dl.custom_minimum_size = Vector2(430, 0)
		else:
			_lbl(left, "     %s — empty" % slot.capitalize(), 14, Color(0.45, 0.45, 0.45))
	_lbl(left, "(full character sheet in the Stats tab)", 12, Color(0.55, 0.55, 0.6))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)
	_lbl(right, "BACKPACK (%d/%d) — click an item to equip it" % [game.player.backpack.size(), Player.BACKPACK_MAX], 16, Color(0.95, 0.85, 0.5))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in game.player.backpack:
		var it: Dictionary = item
		var equip_cb := func() -> void:
			game.player.equip(it)
			open_inventory()  # refresh
		var b := _btn(list, "%s  %s" % [Items.title(it), Items.describe(it)],
			equip_cb, Items.GRADE_COLOR[it["grade"]], true, Art.icon_for(it))
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Items.describe(it) + "\n\nEQUIP — diff:\n" + _diff_tip(it)

	# ------------------------------------------------------------- gems ---
	var gem_head := HBoxContainer.new()
	gem_head.add_theme_constant_override("separation", 12)
	right.add_child(gem_head)
	var gh := _lbl(gem_head, "GEM BAG (%d) — click an EQUIPPED item on the left to socket them" % game.player.gem_bag.size(), 15, Color(0.95, 0.85, 0.5))
	gh.custom_minimum_size = Vector2(420, 0)
	if not game.player.gem_bag.is_empty():
		var auto_cb := func() -> void:
			var n: int = game.player.auto_synthesize()
			game.spawn_text(game.player.global_position + Vector2(0, -60),
				"%d GEM UPGRADES" % n if n > 0 else "NOTHING TO MERGE", Color(0.6, 0.9, 1.0))
			open_inventory()
		var ab := _btn(gem_head, "⚒ Auto-synthesize ALL", auto_cb, Color(0.6, 0.9, 1.0))
		ab.tooltip_text = "Merge every 3-of-a-kind until nothing can be merged.\nGems socketed in your equipped gear level up FIRST\n(each uses two matching gems from the bag)."
	if game.player.gem_bag.is_empty():
		_lbl(right, "No loose gems. They drop from chests.", 12, Color(0.5, 0.5, 0.55))
	else:
		# Compact two-column grid in its own capped scroll area — a gem
		# hoard scrolls here instead of crushing the backpack list above.
		var groups := _gem_groups()
		var keys := _sorted_gem_keys(groups)
		var gscroll := ScrollContainer.new()
		gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var gem_rows := ceili(keys.size() / 2.0)
		gscroll.custom_minimum_size = Vector2(0, minf(34.0 * gem_rows + 6.0, 176.0))
		right.add_child(gscroll)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gscroll.add_child(grid)
		for key in keys:
			var group: Dictionary = groups[key]
			var g: Dictionary = group["gem"]
			var count: int = group["count"]
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			grid.add_child(line)
			var gl := _lbl(line, "%s  x%d" % [Items.gem_title(g), count], 13, Items.gem_color(g))
			gl.custom_minimum_size = Vector2(190, 0)
			gl.autowrap_mode = TextServer.AUTOWRAP_OFF
			gl.clip_text = true
			gl.mouse_filter = Control.MOUSE_FILTER_STOP
			gl.tooltip_text = "%s  x%d" % [Items.gem_title(g), count]
			if count >= 3 and g["lvl"] < Items.GEM_MAX_LEVEL:
				var synth_cb := func() -> void:
					game.player.synthesize(g["stat"], g["lvl"])
					open_inventory()
				var sb := _btn(line, "⚒ 3→Lv%d" % (g["lvl"] + 1), synth_cb, Color(0.6, 0.9, 1.0))
				sb.tooltip_text = "Synthesize three %s into one Lv%d" % [Items.gem_title(g), g["lvl"] + 1]
	_hint(vbox, "ESC / I to close")


## Gem-group keys ordered by stat name, then level descending —
## a stable, scannable order no matter what the bag looks like.
func _sorted_gem_keys(groups: Dictionary) -> Array:
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b) -> bool:
		var ga: Dictionary = groups[a]["gem"]
		var gb: Dictionary = groups[b]["gem"]
		if ga["stat"] == gb["stat"]:
			return int(ga["lvl"]) > int(gb["lvl"])
		return String(ga["stat"]) < String(gb["stat"]))
	return keys


## Full character sheet: every stat on its own row, with a hover tooltip
## explaining what it does — so players learn what to invest in.
func _build_stats_tab(vbox: VBoxContainer, p: Player) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	_lbl(list, "ATTRIBUTES  (hover any stat to learn what it does)", 16, Color(0.95, 0.85, 0.5))
	for attr in Classes.ATTR_NAMES:
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == attr
		_stat_row(list, "%s%s" % [attr, "  ★" if is_primary else ""], str(p.attr_total(attr)),
			Classes.attr_help(p.cls, attr),
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9))
	if p.unspent_attr > 0:
		_lbl(list, "     %d unspent points — allocate in the skill menu (T)" % p.unspent_attr, 13, Color(0.5, 1.0, 0.5))

	_lbl(list, "COMBAT", 16, Color(0.95, 0.85, 0.5))
	var rows := [
		["Combat Rating", str(p.combat_rating()), "Your whole build boiled down to one power number: attack, crits, penetration, defenses, mobility — everything counts."],
		["ATK (%s)" % Classes.CLASSES[p.cls]["dmg_type"], str(int(p.atk)), "Base damage of all your abilities. Your class deals %s damage." % Classes.CLASSES[p.cls]["dmg_type"]],
		["Crit chance", "%d%%" % int(Stats.crit_curve(p.crit) * 100), "Chance a hit deals bonus damage. Diminishing returns past 70%. DoTs and TRUE damage never crit."],
		["Crit damage", "x%.2f" % p.crit_dmg, "How hard your critical hits land."],
		["Combo", "%d%%" % int(Stats.combo_curve(p.combo) * 100), "Chance an ability skips its cooldown AND refunds mana (capped at 60%). Ultimates excluded."],
		["Phys Pen", str(int(p.physpen)), "Ignores enemy physical resistance. Any EXCESS beyond their resistance becomes bonus damage."],
		["Magic Pen", str(int(p.magpen)), "Ignores enemy magic resistance. Any EXCESS beyond their resistance becomes bonus damage."],
		["DEX", str(int(p.dex)), "Hit rate: reduces the enemy's chance to EVADE your attacks. Only matters against evasive enemies (spiders, witches)."],
		["Haste", "%d%%" % int(p.cdr * 100), "Reduces all ability cooldowns."],
	]
	for r in rows:
		_stat_row(list, r[0], r[1], r[2])

	_lbl(list, "DEFENSE", 16, Color(0.95, 0.85, 0.5))
	var rows2 := [
		["HP", "%d / %d" % [int(p.hp), int(p.max_hp)], "Your health. Dying respawns you at the zone entrance."],
		["Mana", "%d / %d" % [int(p.mp), int(p.max_mp)], "Fuel for abilities. Regenerates over time (mages regenerate 50% faster)."],
		["Phys Res", str(int(p.physres)), "Reduces physical damage taken (diminishing returns — never reaches 100%)."],
		["Magic Res", str(int(p.magres)), "Reduces magic damage taken (diminishing returns). TRUE damage ignores all resistances."],
		["Crit Res", str(int(p.critres)), "Shaves the enemy's chance to critically hit you."],
		["Evasion", "%d%%" % int(Stats.eva_curve(p.eva) * 100), "Chance to fully dodge a hit. Countered by the attacker's DEX. Capped at 60%."],
	]
	for r in rows2:
		_stat_row(list, r[0], r[1], r[2])

	_lbl(list, "UTILITY", 16, Color(0.95, 0.85, 0.5))
	var rows3 := [
		["Speed", str(int(p.speed)), "How fast you move. Ice patches boost it; void rifts slow it."],
		["Lifesteal", "%d%%" % int(p.lifesteal * 100), "Heals you for a share of damage dealt. AoE hits only steal a third."],
		["Greed", "%d%%" % int(Stats.greed_gold(p.greed) * 100), "Bonus gold from every source. Above 30% it also nudges chest drop rates. Strong diminishing returns past 50%."],
	]
	for r in rows3:
		_stat_row(list, r[0], r[1], r[2])
	_hint(vbox, "ESC / I to close")


## One stat line: name, value, and a hover tooltip that explains it.
func _stat_row(parent: Node, stat_name: String, value: String, tip: String, color := Color(0.85, 0.85, 0.9)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = tip
	parent.add_child(row)
	var n := _lbl(row, stat_name, 14, color)
	n.custom_minimum_size = Vector2(220, 0)
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	n.tooltip_text = tip
	var v := _lbl(row, value, 14, Color(1, 1, 1))
	v.custom_minimum_size = Vector2(160, 0)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.tooltip_text = tip
	var hint := _lbl(row, "🛈", 12, Color(0.5, 0.55, 0.65))
	hint.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.tooltip_text = tip


## Bag gems grouped by stat+level: key -> {gem, count}.
func _gem_groups() -> Dictionary:
	var groups := {}
	for gem in game.player.gem_bag:
		var key := "%s_%d" % [gem["stat"], gem["lvl"]]
		if not groups.has(key):
			groups[key] = {"gem": gem, "count": 0}
		groups[key]["count"] += 1
	return groups


## Item detail: full stats + per-socket gem management.
func open_item_panel(item: Dictionary) -> void:
	var p: Player = game.player
	var vbox := _open(Items.title(item), 900, 620)
	current = "item_panel"

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vbox.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Art.icon_for(item)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var d := _lbl(head, Items.describe(item), 14, Items.GRADE_COLOR[item["grade"]])
	d.custom_minimum_size = Vector2(760, 0)

	var slots: int = item.get("gem_slots", 0)
	var gems: Array = item.get("gems", [])
	_lbl(vbox, "GEM SOCKETS (%d/%d filled)" % [gems.size(), slots], 16, Color(0.95, 0.85, 0.5))
	if slots == 0:
		_lbl(vbox, "This item has no sockets — only B-grade gear and above can hold gems.", 13, Color(0.55, 0.55, 0.6))
	for i in slots:
		if i < gems.size():
			var g: Dictionary = gems[i]
			var idx := i
			var rm_cb := func() -> void:
				game.player.remove_gem(item, idx)
				open_item_panel(item)
			_btn(vbox, "Socket %d:  %s    — click to REMOVE (back to bag)" % [i + 1, Items.gem_title(g)],
				rm_cb, Items.gem_color(g))
		else:
			_lbl(vbox, "Socket %d:  (empty)" % (i + 1), 13, Color(0.55, 0.55, 0.6))

	if slots > gems.size():
		if p.gem_bag.is_empty():
			_lbl(vbox, "No gems in your bag to insert (they drop from chests).", 12, Color(0.5, 0.5, 0.55))
		else:
			_lbl(vbox, "INSERT FROM BAG:", 15, Color(0.95, 0.85, 0.5))
			# Scrollable two-column grid — big bags stay inside the panel.
			var groups := _gem_groups()
			var iscroll := ScrollContainer.new()
			iscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			iscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(iscroll)
			var igrid := GridContainer.new()
			igrid.columns = 2
			igrid.add_theme_constant_override("h_separation", 12)
			igrid.add_theme_constant_override("v_separation", 4)
			igrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			iscroll.add_child(igrid)
			for key in _sorted_gem_keys(groups):
				var group: Dictionary = groups[key]
				var g2: Dictionary = group["gem"]
				var ins_cb := func() -> void:
					game.player.embed_gem_into(item, g2)
					open_item_panel(item)
				var ib := _btn(igrid, "%s  x%d — insert" % [Items.gem_title(g2), group["count"]], ins_cb, Items.gem_color(g2))
				ib.clip_text = true
				ib.custom_minimum_size = Vector2(400, 0)
				ib.tooltip_text = "%s  x%d" % [Items.gem_title(g2), group["count"]]
	_hint(vbox, "ESC to go back to inventory")


# -------------------------------------------------------------- skill tree ---

## Which glyph represents a skill cell's effect.
func _cell_glyph(cell: Dictionary) -> String:
	if cell.has("amod"):
		for slot in cell["amod"]:
			if cell["amod"][slot].has("cd"):
				return "ic_cd"
		return "ab_slash"
	var bonus: Dictionary = cell.get("bonus", {})
	for stat in bonus:
		match stat:
			"crit", "crit_dmg": return "ic_crit"
			"hp_pct", "hp_flat": return "ic_hp"
			"mp_flat", "lifesteal": return "ic_mp"
			"speed_pct": return "ab_roll"
			"physres", "magres", "critres": return "ab_shield"
			"physpen", "magpen": return "ic_pen"
			"combo": return "ic_combo"
			"eva": return "ab_blink"
			"dex": return "ic_eye"
			"greed": return "ic_coin"
			"atk_pct": return "ab_slash"
	return "ic_crit"

func open_skills(tab := "talents") -> void:
	var p: Player = game.player
	var vbox := _open("%s — %s" % [Classes.CLASSES[p.cls]["name"], "Skill Tree" if tab == "talents" else "Attributes"], 1120, 640)
	current = "skills"

	# Subtabs: talents / attribute allocation.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Talents (%d pts)  " % p.skill_points, func() -> void: open_skills("talents"),
		Color(0.95, 0.85, 0.5) if tab == "talents" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Attributes (%d pts)  " % p.unspent_attr, func() -> void: open_skills("attributes"),
		Color(0.95, 0.85, 0.5) if tab == "attributes" else Color(0.6, 0.6, 0.6))

	if tab == "attributes":
		_build_attributes_tab(vbox, p)
		return

	_lbl(vbox, "Rows unlock as you level. Spend up to %d points per row, spread across its 3 columns (max %d per skill). Each column follows one of your themes." % [Skills.MAX_PER_ROW, Skills.MAX_PER_CELL], 13, Color(0.6, 0.62, 0.68))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Column headers = the class themes.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	list.add_child(head)
	var pad := _lbl(head, "", 13)
	pad.custom_minimum_size = Vector2(120, 0)
	for theme in Classes.THEMES[p.cls]:
		var h := _lbl(head, theme["name"].to_upper(), 15, theme["color"])
		h.custom_minimum_size = Vector2(288, 0)

	for r in Skills.TREES[p.cls].size():
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)
		list.add_child(row_box)
		var unlocked: bool = p.level >= Skills.ROW_LEVELS[r]
		var spent := Skills.points_in_row(p.cls, r, p.tree_points)
		var row_l := _lbl(row_box, "Lv.%d\n%d/%d pts" % [Skills.ROW_LEVELS[r], spent, Skills.MAX_PER_ROW], 13,
			Color(0.95, 0.85, 0.5) if unlocked else Color(0.4, 0.4, 0.45))
		row_l.custom_minimum_size = Vector2(120, 0)
		var col_idx := 0
		for cell in Skills.TREES[p.cls][r]:
			var cd: Dictionary = cell
			var theme_col: Color = Classes.THEMES[p.cls][col_idx]["color"]
			col_idx += 1
			var pts: int = p.tree_points.get(cd["id"], 0)
			var can: bool = p.skill_points > 0 and Skills.can_add(p.cls, cd["id"], p.tree_points, p.level)
			var color := Color(0.5, 1.0, 0.5) if pts > 0 else (Color(1, 1, 1) if can else Color(0.45, 0.45, 0.45))
			var add_cb := func() -> void:
				if game.player.add_tree_point(cd["id"]):
					open_skills()
			var b := _btn(row_box, "%s  [%d/%d]\n%s" % [cd["name"], pts, Skills.MAX_PER_CELL, cd["desc"]],
				add_cb, color, can or pts > 0,
				Art.glyph_tex(_cell_glyph(cd), theme_col if unlocked else Color(0.4, 0.4, 0.45)))
			b.custom_minimum_size = Vector2(288, 0)
			if not can:
				b.disabled = true

	# ------------------------------------------------- theme assignment ---
	var next_note := "" if p.themes_known >= 3 else " — next unlocks at Lv %d" % Classes.THEME_LEVELS[mini(p.themes_known, 2)]
	_lbl(vbox, "ABILITY VARIANTS — click an ability to choose its theme (%d/3 unlocked%s)" % [p.themes_known, next_note], 15, Color(0.95, 0.85, 0.5))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	vbox.add_child(trow)
	for slot in ["a1", "a2", "a3", "ult"]:
		var s: String = slot
		var theme := Classes.theme_by_id(p.cls, p.ability_theme.get(s, ""))
		var label: String = theme.get("name", "Base")
		var tcolor: Color = theme.get("color", Color(0.75, 0.75, 0.8))
		var pick_cb := func() -> void:
			open_theme_picker(s)
		_btn(trow, "%s: %s ▾" % [Classes.ability(p.cls, s)["name"], label], pick_cb,
			tcolor, p.themes_known > 0, Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][s], tcolor))
	_hint(vbox, "ESC / T to close — themes change how your abilities behave")


## Attribute allocation: +5 points per level, converted at CLASS
## scaling ratios (your class page shows exactly what a point buys YOU).
func _build_attributes_tab(vbox: VBoxContainer, p: Player) -> void:
	_lbl(vbox, "Every level grants 5 attribute points. Conversion depends on your class — %s scales best with %s." % [Classes.CLASSES[p.cls]["name"], Classes.CLASSES[p.cls]["primary"]], 13, Color(0.6, 0.62, 0.68))
	_lbl(vbox, "Unspent: %d points" % p.unspent_attr, 18, Color(0.5, 1.0, 0.5) if p.unspent_attr > 0 else Color(0.6, 0.6, 0.65))
	for attr in Classes.ATTR_NAMES:
		var a: String = attr
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == a
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var name_l := _lbl(row, "%s  %d%s" % [a, p.attr_points[a], "  ★" if is_primary else ""], 17,
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9))
		name_l.custom_minimum_size = Vector2(140, 0)
		_btn(row, " +1 ", func() -> void:
			game.player.add_attr_points(a, 1)
			open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
		_btn(row, " +5 ", func() -> void:
			game.player.add_attr_points(a, 5)
			open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
		var desc := _lbl(row, Classes.attr_text(p.cls, a), 13, Color(0.68, 0.7, 0.78))
		desc.custom_minimum_size = Vector2(620, 0)
	_lbl(vbox, "YOUR STATS", 16, Color(0.95, 0.85, 0.5))
	_lbl(vbox, p.stat_sheet(), 13, Color(0.75, 0.78, 0.85))
	_hint(vbox, "ESC / T to close")


## Dedicated variant chooser: shows the base ability and every theme
## variant with its icon and exactly what it changes.
func open_theme_picker(slot: String) -> void:
	var p: Player = game.player
	var ab := Classes.ability(p.cls, slot)
	var vbox := _open("%s — choose a variant" % ab["name"], 940, 620)
	current = "theme_pick"

	var base_row := HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 12)
	vbox.add_child(base_row)
	var base_icon := TextureRect.new()
	base_icon.texture = Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot])
	base_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_row.add_child(base_icon)
	var base_l := _lbl(base_row, "BASE — %s" % ab["desc"], 14, Color(0.85, 0.85, 0.9))
	base_l.custom_minimum_size = Vector2(780, 0)

	var is_base: bool = p.ability_theme.get(slot, "") == ""
	var none_cb := func() -> void:
		game.player.set_ability_theme(slot, "")
		open_skills()
	_btn(vbox, ("●  " if is_base else "   ") + "Use BASE (no theme)", none_cb, Color(0.85, 0.85, 0.9),
		true, Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot]))

	for i in Classes.THEMES[p.cls].size():
		var theme: Dictionary = Classes.THEMES[p.cls][i]
		var unlocked: bool = i < p.themes_known
		var selected: bool = p.ability_theme.get(slot, "") == theme["id"]
		var tcolor: Color = theme["color"] if unlocked else Color(0.4, 0.4, 0.45)
		var pick := func() -> void:
			game.player.set_ability_theme(slot, theme["id"])
			open_skills()
		var title: String = ("●  " if selected else "   ") + theme["name"].to_upper()
		if not unlocked:
			title += "   (unlocks at Lv %d)" % Classes.THEME_LEVELS[i]
		_btn(vbox, title, pick, tcolor, unlocked,
			Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot], tcolor))
		# What this theme does to THIS ability — every pair is unique.
		var vdesc := Classes.variant_desc(p.cls, slot, theme["id"])
		var vfx := Classes.fx_text(Classes.ability_fx(p.cls, slot, theme["id"]))
		var d := _lbl(vbox, vdesc + ("\n" + vfx if vfx != "" else ""), 12,
			Color(0.68, 0.7, 0.78) if unlocked else Color(0.45, 0.45, 0.5))
		d.custom_minimum_size = Vector2(860, 0)
	_hint(vbox, "ESC to go back to the skill tree")


# -------------------------------------------------------------------- shop ---

func open_shop(zone: int) -> void:
	shop_zone = zone
	# Each merchant keeps their stock until you buy it out.
	if not game.shop_stock.has(zone):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var tier: String = ["wood", "silver", "silver", "gold"][zone]
		var stock: Array = []
		for i in 3:
			stock.append(Items.roll_item(tier, rng, game.player.cls))
		game.shop_stock[zone] = stock

	var p: Player = game.player
	var vbox := _open("Merchant — you have %d gold" % p.gold, 1120, 600)
	current = "shop"
	_lbl(vbox, "\"Ah, a customer! Dangerous roads make good business.\"", 14, Color(0.75, 0.7, 0.6))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 26)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# ------------------------------------------------------ BUY column ---
	var buy := VBoxContainer.new()
	buy.custom_minimum_size = Vector2(640, 0)
	buy.add_theme_constant_override("separation", 6)
	hbox.add_child(buy)
	_lbl(buy, "BUY", 16, Color(0.95, 0.85, 0.5))

	var buy_potion := func() -> void:
		if p.gold >= 25 and p.potions < 5:
			p.gold -= 25
			p.potions += 1
			game.sfx("potion")
		open_shop(zone)
	_btn(buy, "Health Potion — 25 gold  (you have %d, max 5)" % p.potions,
		buy_potion, Color(1.0, 0.5, 0.5), p.gold >= 25 and p.potions < 5)

	for item in game.shop_stock[zone]:
		var it: Dictionary = item
		var cost := Items.price(it) * 2
		var buy_item := func() -> void:
			if p.gold >= cost:
				p.gold -= cost
				game.shop_stock[zone].erase(it)
				p.add_item(it)
				game.sfx("potion")
			open_shop(zone)
		var bb := _btn(buy, "%s  %s — %d gold" % [Items.title(it), Items.describe(it), cost],
			buy_item, Items.GRADE_COLOR[it["grade"]], p.gold >= cost, Art.icon_for(it))
		bb.clip_text = true
		bb.custom_minimum_size = Vector2(640, 0)
		bb.tooltip_text = "%s — %d gold\n%s\n\nDiff vs equipped:\n%s" % [Items.title(it), cost, Items.describe(it), _diff_tip(it)]

	_lbl(buy, "UPGRADE", 16, Color(0.95, 0.85, 0.5))
	for slot in ["weapon", "armor"]:
		if p.equipment.has(slot):
			var item: Dictionary = p.equipment[slot]
			var cost := Items.upgrade_cost(item)
			var do_upgrade := func() -> void:
				if p.gold >= cost:
					p.gold -= cost
					item["plus"] += 1
					p.recalc()
					game.sfx("levelup")
				open_shop(zone)
			_btn(buy, "%s → +%d  (main stat +15%%) — %d gold" % [Items.title(item), item["plus"] + 1, cost],
				do_upgrade, Color(0.6, 0.9, 1.0), p.gold >= cost, Art.icon_for(item))

	# ----------------------------------------------------- SELL column ---
	var sell := VBoxContainer.new()
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell.add_theme_constant_override("separation", 6)
	hbox.add_child(sell)
	_lbl(sell, "SELL FROM BACKPACK", 16, Color(0.95, 0.85, 0.5))
	if p.backpack.is_empty():
		_lbl(sell, "Nothing to sell.", 13, Color(0.5, 0.5, 0.5))
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sell.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		var total := 0
		for item in p.backpack:
			var it: Dictionary = item
			var value := maxi(1, Items.price(it) / 2)
			total += value
			var sell_one := func() -> void:
				p.strip_gems(it)  # gems pop back into your bag
				p.backpack.erase(it)
				p.gain_gold(value)
				game.sfx("potion")
				open_shop(zone)
			var sb := _btn(list, "%s — sell for %d gold" % [Items.title(it), value],
				sell_one, Items.GRADE_COLOR[it["grade"]], true, Art.icon_for(it))
			sb.clip_text = true
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sell_all := func() -> void:
			for item in p.backpack:
				p.strip_gems(item)
			p.gain_gold(total)
			p.backpack.clear()
			game.sfx("potion")
			open_shop(zone)
		_btn(sell, "SELL ALL (%d items) — %d gold" % [p.backpack.size(), total],
			sell_all, Color(1.0, 0.9, 0.4))
	_hint(vbox)


# ------------------------------------------------------------------- codex ---

const BOSS_KINDS := ["fangmaw", "morwen", "vargoth"]

func open_codex(tab := "monsters") -> void:
	var vbox := _open("Codex", 1000, 620)
	current = "codex"

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Monsters  ", func() -> void: open_codex("monsters"),
		Color(0.95, 0.85, 0.5) if tab == "monsters" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Gear  ", func() -> void: open_codex("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Terrains  ", func() -> void: open_codex("terrains"),
		Color(0.95, 0.85, 0.5) if tab == "terrains" else Color(0.6, 0.6, 0.6))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if tab == "monsters":
		_codex_monsters(list)
	elif tab == "terrains":
		_codex_terrains(list)
	else:
		_codex_gear(list)
	_hint(vbox, "ESC / C to close")


## Rounded, padded card panel — shared row container for codex galleries.
func _card(parent: Container) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	return card


func _codex_monsters(list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	for section in [false, true]:  # regular monsters first, then bosses
		_lbl(list, "— BOSSES —" if section else "— MONSTERS —", 16, Color(1, 0.5, 0.5) if section else Color(0.95, 0.85, 0.5))
		for kind in Story.ENEMIES:
			var is_boss: bool = kind in BOSS_KINDS
			if is_boss != section:
				continue
			var st: Dictionary = Story.ENEMIES[kind]

			# One boxed card per monster.
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			_card(list).add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.tex(st["sprite"])
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 2)
			row.add_child(info)

			# Name .......................................... Lv badge
			var head := HBoxContainer.new()
			info.add_child(head)
			var name_l := _lbl(head, st["name"], 16, Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
			name_l.custom_minimum_size = Vector2(560, 0)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lv_l := _lbl(head, "Lv %d" % st.get("level", 1), 15, Color(0.95, 0.85, 0.5))
			lv_l.custom_minimum_size = Vector2(120, 0)
			lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

			# Aligned stat columns.
			var cols := HBoxContainer.new()
			info.add_child(cols)
			for pair in [["HP", int(st["hp"])], ["DMG", int(st["dmg"])], ["SPD", int(st["speed"])],
					["XP", st["xp"]], ["Gold", st.get("gold", 0)]]:
				var c := _lbl(cols, "%s %s" % [pair[0], str(pair[1])], 13, Color(0.78, 0.8, 0.86))
				c.custom_minimum_size = Vector2(105, 0)
			var type_l := _lbl(cols, "Ranged caster" if st["ranged"] else "Melee", 13, Color(0.6, 0.7, 0.85))
			type_l.custom_minimum_size = Vector2(130, 0)

			# Scaling: growth + projections, in two quiet sublines.
			var at25 := Story.enemy_stats_at(kind, 25)
			var at50 := Story.enemy_stats_at(kind, 50)
			var g1 := _lbl(info, "Growth per level:   HP +%d%%   ·   DMG +%d%%" %
				[int(st.get("hp_g", 0.1) * 100), int(st.get("dmg_g", 0.1) * 100)], 12, Color(0.55, 0.65, 0.8))
			g1.custom_minimum_size = Vector2(700, 0)
			var g2 := _lbl(info, "Projected:   Lv 25 → %d HP, %d DMG        Lv 50 → %d HP, %d DMG" %
				[int(at25["hp"]), int(at25["dmg"]), int(at50["hp"]), int(at50["dmg"])], 12, Color(0.5, 0.55, 0.66))
			g2.custom_minimum_size = Vector2(700, 0)


func _codex_terrains(list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var patch_desc := {
		"lava": "Lava pools — the floor burns anyone standing in them, you AND monsters",
		"ice": "Sheet ice — slippery patches speed everyone up by 35%",
		"poison": "Poison pools — standing in them poisons you",
		"heal": "Blessed ground — standing in it slowly heals you",
		"slow": "Clinging murk — wading through slows you by 30%",
	}
	var event_desc := {
		"magma_rain": "Magma rain — molten rock crashes onto telegraphed spots and the floor collapses into lava",
		"grave_spawn": "Restless dead — zombies periodically claw out of the ground beside you",
		"gust": "Sandstorm gusts — sudden wind shoves everyone sideways",
		"lightning": "Lightning strikes — bolts hammer telegraphed spots around you",
		"shard": "Shard eruptions — crystal bursts explode at random spots",
	}
	var ambient_desc := {
		"leaves_green": "drifting green leaves", "leaves_autumn": "falling autumn leaves",
		"fireflies": "fireflies", "embers": "rising embers", "snow": "falling snow",
		"rain": "heavy rain", "sand": "blowing sand", "mist": "creeping mist",
		"twinkle": "twinkling lights", "motes": "drifting void motes",
		"sparkle": "golden sparkles", "spores": "floating spores",
	}
	# Which Chapter 1 zone (if any) uses each terrain.
	var found_in := {}
	for zone in Story.ZONES:
		found_in[zone.get("terrain", "")] = zone["name"]

	for id in Terrains.DATA:
		var t: Dictionary = Terrains.DATA[id]
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		_card(list).add_child(info)

		# Name ................................... where it appears
		var head := HBoxContainer.new()
		info.add_child(head)
		var name_l := _lbl(head, t["name"], 16, Color(1, 1, 1))
		name_l.custom_minimum_size = Vector2(560, 0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where: String = found_in.get(id, "")
		var where_l := _lbl(head, where if where != "" else "Beyond Chapter 1", 13,
			Color(0.95, 0.85, 0.5) if where != "" else Color(0.55, 0.58, 0.66))
		where_l.custom_minimum_size = Vector2(220, 0)
		where_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var amb: String = t.get("ambient", "")
		var w := _lbl(info, "Weather:   " + String(ambient_desc.get(amb, "still air")),
			13, Color(0.7, 0.72, 0.78))
		w.custom_minimum_size = Vector2(700, 0)

		var quirks: Array = []
		for p in t.get("patches", []):
			var d: String = patch_desc.get(p["type"], "")
			if p.get("drift", false):
				d += " — and the clouds DRIFT, so keep moving"
			quirks.append(d)
		if t.get("event", "") != "":
			quirks.append(event_desc.get(t["event"], ""))
		if t.get("mp_boost", false):
			quirks.append("Latent magic — your mana recovers much faster here")
		if quirks.is_empty():
			quirks.append("No hazards — safe ground")
		for q in quirks:
			var ql := _lbl(info, "◆ " + String(q), 13, Color(0.55, 0.65, 0.8))
			ql.custom_minimum_size = Vector2(700, 0)


func _codex_gear(list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var slot_desc := {
		"weapon": "Main stat: ATK. Upgradeable at merchants.",
		"armor": "Main stat: HP. Upgradeable at merchants.",
		"boots": "Main stat: move speed.",
		"charm": "Main stat: cooldown reduction (Haste).",
	}

	# ------------------ visual gallery: every shape at every grade ------
	for slot in Items.SLOTS:
		_lbl(list, "— %sS — %s" % [slot.to_upper(), slot_desc[slot]], 16, Color(0.95, 0.85, 0.5))
		for noun in Art.GEAR_SHAPES[slot]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_card(list).add_child(row)
			var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
			var name_l := _lbl(row, "%s\n%s" % [noun, tag], 13, Color(0.85, 0.85, 0.9))
			name_l.custom_minimum_size = Vector2(110, 34)
			for g in Items.GRADES:
				var cell := VBoxContainer.new()
				cell.custom_minimum_size = Vector2(48, 0)
				row.add_child(cell)
				var icon := TextureRect.new()
				icon.texture = Art.item_icon(slot, g, noun)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cell.add_child(icon)
				var gl := Label.new()
				gl.text = g
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				gl.add_theme_font_size_override("font_size", 12)
				gl.add_theme_color_override("font_color", Items.GRADE_COLOR[g])
				cell.add_child(gl)

	# --------------------------------------- named epics & legendaries --
	_lbl(list, "— EPIC UNIQUES (A) — found in silver and golden chests —", 16, Items.GRADE_COLOR["A"])
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_card(list).add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(slot, "A")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := _lbl(row, "  ·  ".join(Items.A_NAMES[slot]), 13, Items.GRADE_COLOR["A"])
		l.custom_minimum_size = Vector2(780, 0)

	_lbl(list, "— LEGENDARY (S) — class exclusive, golden chests only —", 16, Items.GRADE_COLOR["S"])
	for cls in Items.S_GEAR:
		# One card per class holding its four legendary pieces.
		var cls_box := VBoxContainer.new()
		cls_box.add_theme_constant_override("separation", 4)
		_card(list).add_child(cls_box)
		_lbl(cls_box, Classes.CLASSES[cls]["name"].to_upper(), 14, Color(0.95, 0.85, 0.5))
		for slot in Items.SLOTS:
			var special: Dictionary = Items.S_GEAR[cls][slot]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			cls_box.add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.item_icon(slot, "S", special.get("noun", ""))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var extra := ""
			if special.has("passive"):
				extra = "  ★ " + Items.PASSIVES[special["passive"]]
			elif special.has("subs"):
				var bits: Array = []
				for stat in special["subs"]:
					bits.append("%s +%d%%" % [Items.STAT_LABEL[stat], int(round(special["subs"][stat] * 100))])
				extra = "  (" + ", ".join(bits) + ")"
			var l := _lbl(row, special["name"] + extra, 13, Items.GRADE_COLOR["S"])
			l.custom_minimum_size = Vector2(780, 0)

	# ------------------------------------------------- rules of thumb ---
	_lbl(list, "— GRADES & CHESTS —", 16, Color(0.95, 0.85, 0.5))
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", 2)
	_card(list).add_child(rules)
	for g in Items.GRADES:
		var subs := maxi(0, (Items.GRADES.find(g) - 1) / 2)
		_lbl(rules, "%s   %s   —   power ×%.2f, up to %d bonus stat%s" %
			[g, Items.GRADE_PREFIX[g], Items.GRADE_MULT[g], subs, "" if subs == 1 else "s"],
			14, Items.GRADE_COLOR[g])
	var chests := VBoxContainer.new()
	chests.add_theme_constant_override("separation", 2)
	_card(list).add_child(chests)
	_lbl(chests, "Wooden chest — drops from monsters (common). Contains F to C gear.", 14, Color(0.8, 0.65, 0.45))
	_lbl(chests, "Silver chest — drops from monsters (rare). Contains D to A gear.", 14, Color(0.8, 0.82, 0.9))
	_lbl(chests, "Golden chest — every boss drops one. Contains B to S gear.", 14, Color(1.0, 0.85, 0.35))
	_lbl(chests, "Bonus stats: ATK%, HP%, Crit, Haste, Speed, Lifesteal, Armor, Greed (gold).", 13, Color(0.7, 0.72, 0.78))


# ---------------------------------------------------------------- dev mode ---

## Debug panel (F1, only when launched via dev_mode.bat). Lets the
## tester change class/level/gear/terrain/bosses instantly instead of
## replaying from scratch.
func open_dev() -> void:
	var p: Player = game.player
	var vbox := _open("DEV PANEL — zone %d (%s)" % [game.last_zone, game.terrain_by_zone[clampi(game.last_zone, 0, 3)]], 1160, 660)
	current = "dev"

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# ------------------------------------------------------- character ---
	_lbl(list, "CHARACTER", 16, Color(0.95, 0.85, 0.5))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	list.add_child(row1)
	_btn(row1, ("■ God mode ON" if game.dev_god else "□ God mode off"), func() -> void:
		game.dev_god = not game.dev_god
		open_dev(), Color(0.5, 1.0, 0.5) if game.dev_god else Color(1, 1, 1))
	_btn(row1, "+1 level", func() -> void:
		game.player.gain_xp(game.player.xp_needed())
		open_dev())
	_btn(row1, "+5 levels", func() -> void:
		for i in 5:
			game.player.gain_xp(game.player.xp_needed())
		open_dev())
	_btn(row1, "+500 gold", func() -> void:
		game.player.gold += 500
		open_dev())
	_btn(row1, "Max potions", func() -> void:
		game.player.potions = 5
		open_dev())
	_btn(row1, "Heal + reset CDs", func() -> void:
		game.player.hp = game.player.max_hp
		game.player.mp = game.player.max_mp
		for key in game.player.cds:
			game.player.cds[key] = 0.0
		open_dev())
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	list.add_child(row2)
	for id in Classes.CLASSES:
		var cid: String = id
		_btn(row2, "Class: " + Classes.CLASSES[id]["name"], func() -> void:
			game.player.set_class(cid)
			game.player._update_weapon_visual()
			open_dev(), Color(0.6, 0.9, 1.0))

	# ------------------------------------------------------------ items ---
	_lbl(list, "ITEMS & GEMS", 16, Color(0.95, 0.85, 0.5))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	list.add_child(row3)
	for grade in ["C", "B", "A", "S"]:
		var g: String = grade
		_btn(row3, "Give %s item" % g, func() -> void:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			game.player.add_item(Items.roll_item_of(Items.SLOTS[rng.randi_range(0, 3)], g, rng, game.player.cls))
			open_dev(), Items.GRADE_COLOR[g])
	_btn(row3, "Give 5 gems", func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 5:
			game.player.gem_bag.append(Items.random_gem(rng, 1))
		game.player.gem_bag.append(Items.random_gem(rng, 3))
		open_dev())

	# ------------------------------------------------------------ world ---
	_lbl(list, "WORLD", 16, Color(0.95, 0.85, 0.5))
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 8)
	list.add_child(row4)
	for zi in 4:
		var z: int = zi
		_btn(row4, "Go zone %d" % z, func() -> void:
			game.player.global_position = Vector2(z * Game.ZONE_W + 300.0, 360.0)
			close())
	_btn(row4, "Clear zone monsters", func() -> void:
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and not (e is Boss) and e.zone_idx == game.last_zone:
				e.take_damage(9999999.0)
		open_dev())
	var row5 := HBoxContainer.new()
	row5.add_theme_constant_override("separation", 8)
	list.add_child(row5)
	for kind in ["fangmaw", "morwen", "vargoth"]:
		var k: String = kind
		_btn(row5, "Spawn " + k, func() -> void:
			if is_instance_valid(game.current_boss):
				game.current_boss.queue_free()
			game.current_boss = Boss.make_boss(game, k, game.player.global_position + Vector2(320, 0))
			game.add_child(game.current_boss)
			game.hud.show_boss_bar(Story.ENEMIES[k]["name"])
			game.set_music("boss_" + k)
			close(), Color(1, 0.6, 0.6))
	_btn(row5, "Kill boss", func() -> void:
		if is_instance_valid(game.current_boss):
			game.current_boss.take_damage(9999999.0)
		open_dev())

	# ------------------------------------------------------------ audio ---
	_lbl(list, "AUDIO (browse every track and sound in the game)", 16, Color(0.95, 0.85, 0.5))
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	list.add_child(arow)
	var ml := _lbl(arow, "Music:", 14)
	ml.custom_minimum_size = Vector2(60, 0)
	var mopt := OptionButton.new()
	mopt.add_item("(silence)")
	var mkeys: Array = game.music_tracks.keys()
	mkeys.sort()
	for k in mkeys:
		mopt.add_item(k)
		if k == game.current_track:
			mopt.select(mopt.item_count - 1)
	mopt.item_selected.connect(func(idx: int) -> void:
		game.set_music("" if idx == 0 else mkeys[idx - 1])
	)
	arow.add_child(mopt)
	var sl := _lbl(arow, "   Play SFX once:", 14)
	sl.custom_minimum_size = Vector2(140, 0)
	var sopt := OptionButton.new()
	sopt.add_item("(choose a sound)")
	var skeys: Array = game.sounds.keys()
	skeys.sort()
	for k in skeys:
		sopt.add_item(k)
	sopt.item_selected.connect(func(idx: int) -> void:
		if idx > 0:
			game.sfx(skeys[idx - 1])
	)
	arow.add_child(sopt)

	# --------------------------------------------------------- terrains ---
	_lbl(list, "TERRAIN (applies to the zone you're standing in)", 16, Color(0.95, 0.85, 0.5))
	var trow: HBoxContainer = null
	var count := 0
	for tid in Terrains.DATA:
		if count % 5 == 0:
			trow = HBoxContainer.new()
			trow.add_theme_constant_override("separation", 8)
			list.add_child(trow)
		count += 1
		var t: String = tid
		var active: bool = game.terrain_by_zone[clampi(game.last_zone, 0, 3)] == t
		_btn(trow, ("● " if active else "") + Terrains.DATA[t]["name"], func() -> void:
			game.apply_terrain(game.last_zone, t)
			close(), Color(0.5, 1.0, 0.5) if active else Color(1, 1, 1))
	_hint(vbox, "ESC / F1 to close")


# ---------------------------------------------------------------- keybinds ---

func open_keybinds() -> void:
	var vbox := _open("Keybinds — click an action, then press a key", 700, 520)
	current = "keybinds"
	var actions := {
		"a1": "Ability 1", "a2": "Ability 2", "a3": "Ability 3", "ult": "Ultimate",
		"potion": "Drink potion", "interact": "Talk / interact",
		"inventory": "Inventory", "skills": "Skill tree", "codex": "Codex",
		"target": "Switch target lock",
	}
	for action in actions:
		var act: String = action
		var key_name := OS.get_keycode_string(game.binds[act])
		var text: String = "%s    —    [ %s ]" % [actions[act], key_name]
		if listening_action == act:
			text = "%s    —    press any key..." % actions[act]
		var rebind_cb := func() -> void:
			listening_action = act
			open_keybinds()
		_btn(vbox, text, rebind_cb, Color(1, 1, 0.6) if listening_action == act else Color(1, 1, 1))
	_lbl(vbox, "Movement is always WASD / arrows. ESC closes menus.", 13, Color(0.6, 0.6, 0.6))
	_hint(vbox)


# ------------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	# Keybind capture takes priority over everything.
	if listening_action != "" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			game.binds[listening_action] = event.keycode
			game.save_binds()
		listening_action = ""
		open_keybinds()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if current == "class_select":
			var ids: Array = Classes.CLASSES.keys()
			var num: int = event.keycode - KEY_1
			if num >= 0 and num < ids.size():
				pick_class(ids[num])
				get_viewport().set_input_as_handled()
			return  # can't ESC out of class select
		if current == "title" or current == "class_select":
			return  # boot menus: no escaping into a paused void
		if event.keycode == KEY_ESCAPE \
				or (current == "inventory" and event.keycode == game.binds["inventory"]) \
				or (current == "skills" and event.keycode == game.binds["skills"]) \
				or (current == "codex" and event.keycode == game.binds["codex"]) \
				or (current == "dev" and event.keycode == KEY_F1):
			if current == "theme_pick":
				open_skills()  # back to the tree, not out of the menu
			elif current == "item_panel":
				open_inventory()  # back to the bag
			else:
				close()
			get_viewport().set_input_as_handled()
