extends RefCounted
## One selected clean-potion recipe. The Alchemy order owns every transaction;
## this screen owns input, its shell lifetime, and the remembered reading view.
const Alchemy := preload("res://scripts/alchemy.gd")
const MEMORY := "alchemy_view"
const TEXT := Color(0.9, 0.9, 0.9)


class QuoteWatch extends Node:
	var menus: Menus
	var shell: Control
	var signature := 0
	var remaining := 0.0
	var read_signature := Callable()
	var refresh := Callable()
	var touches := {}
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				touches[event.index] = true
			else:
				touches.erase(event.index)
	func _process(delta: float) -> void:
		if not is_instance_valid(menus) or not is_instance_valid(shell) \
				or menus.root != shell or menus.current != "alchemy":
			set_process(false)
			return
		remaining -= delta
		if remaining > 0.0:
			return
		remaining = Balance.ACTIVITY_BOARD_REFRESH
		var next: int = int(read_signature.call())
		if next != signature and touches.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			refresh.call()


static func open(m: Menus, notice := "", notice_color := Color(0.72, 0.92, 0.76), changes: Dictionary = {}) -> void:
	var g := m.game
	if not is_instance_valid(g) or not g.has_local_player():
		return
	var p: Player = g.local_player
	var state := _remember(m)
	state.merge(changes, true)
	if not Alchemy.shapes().has(String(state.shape)):
		state.shape = "health_instant"
	var grades: Array[String] = Alchemy.grades(String(state.shape))
	if not grades.has(String(state.grade)):
		state.grade = grades[0]
	m.set_meta(MEMORY, state)
	var order: RefCounted = Alchemy.prepare(g, String(state.shape), String(state.grade))
	var quote: Dictionary = order.view()
	var box := m._open("Alchemy — Kesh's brewing bench", 1180, 660, true)
	m.current = "alchemy"
	var shell: Control = m.root
	var action_used: Array[bool] = [false]
	var active := "Alchemist active" if p.profession == "alchemist" else ("No active trade" if p.profession == "" else Professions.trade_name(p.profession) + " active")
	var mastery: int = Professions.points(p, "alchemist")
	var until_next: int = Balance.mastery_to_next(mastery)
	var climb := "Mastered" if until_next <= 0 else "%d to next band" % until_next
	var summary := m._lbl(box, "%s  ·  Alchemy: %s, %d mastery (%s)  ·  Pack %d / %d" % [
		active, Professions.band(p, "alchemist"), mastery, climb, p.bag_used(), p.bag_capacity()], 15, UITheme.TEXT_MUTED)
	summary.name = "AlchemyProgress"
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	_recipe_rail(m, body, shell, state)
	_recipe_detail(m, body, shell, state, order, quote, action_used, notice, notice_color)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	box.add_child(foot)
	var back := m._btn(foot, "Back to Professions", func() -> void:
		if _owns(m, shell):
			_remember(m)
			m.controller_back(), UITheme.GOLD_BRIGHT)
	back.name = "AlchemyReturn"
	back.custom_minimum_size = Vector2(240, 44)
	var note := m._lbl(foot, "Choose bottles in Inventory → Potions. Slot changes apply at the next door.\nGrand potions use Kesh's separate Synthesis bench.", 13, UITheme.TEXT_MUTED)
	note.name = "AlchemyUseHint"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.custom_minimum_size.x = 500
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m._hint(box, "ESC / controller Back / X / outside returns to Professions", "Tap X or outside to return to Professions")
	_watch(m, shell)
	_restore(m, shell, state)


static func _recipe_rail(m: Menus, parent: Control, shell: Control, state: Dictionary) -> void:
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 270
	rail.add_theme_constant_override("separation", 8)
	parent.add_child(rail)
	UITheme.header(m._lbl(rail, "POTION RECIPES", 16, UITheme.GOLD_BRIGHT))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	rail.add_child(filters)
	for spec in [["all", "All"], ["ready", "Brewable"]]:
		var key := String(spec[0])
		var button := m._btn(filters, String(spec[1]), func() -> void:
			_reopen(m, shell, {"filter": key, "rail_scroll": 0}), UITheme.GOLD_BRIGHT)
		UITheme.tab(button, String(state.filter) == key)
		button.name = "AlchemyFilter_" + key
		button.custom_minimum_size = Vector2(126, 44)
	var scroll := ScrollContainer.new()
	scroll.name = "AlchemyRecipeScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for raw in Alchemy.shapes():
		var fs := String(raw)
		var ready := 0
		for grade in Alchemy.grades(fs):
			if bool(Alchemy.quote(m.game, fs, String(grade)).get("allowed", false)):
				ready += 1
		var selected := fs == String(state.shape)
		if String(state.filter) == "ready" and ready == 0 and not selected:
			continue
		var available: Array[String] = Alchemy.grades(fs)
		var preview: Dictionary = Alchemy.recipe(fs, String(state.grade) if available.has(String(state.grade)) else available[0])
		var text_value := String(Items.POTION_ACCORD_NOUN[fs])
		if ready > 0:
			text_value += "\n%d grade%s brewable" % [ready, "" if ready == 1 else "s"]
		elif selected and String(state.filter) == "ready":
			text_value += "\nSelected · not currently brewable"
		else:
			text_value += "\nInspect ingredients & requirements"
		var button := m._btn(list, text_value, func() -> void:
			_reopen(m, shell, {"shape": fs, "detail_scroll": 0}), UITheme.GOLD_BRIGHT if selected else TEXT,
			true, Art.consumable_icon(preview.item))
		UITheme.tab(button, selected)
		button.name = "AlchemyShape_" + fs
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(270, 52)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_constant_override("icon_max_width", 30)
		button.clip_text = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		button.tooltip_text = String(preview.item.desc)
	var source := m._lbl(rail, "Use carried herbs + reagents of the bottle's grade. Find them on creatures and in supply chests.", 13, UITheme.TEXT_MUTED)
	source.custom_minimum_size.x = 270
	var help := m._btn(rail, "Ingredient sources", func() -> void:
		if _owns(m, shell):
			_reopen(m, shell, {"sources": not bool(state.get("sources", false)), "detail_scroll": 0}), UITheme.TEXT_MUTED)
	help.name = "AlchemySources"
	help.custom_minimum_size.y = 44
	help.tooltip_text = "Show where carried herbs and reagents are found."


static func _recipe_detail(m: Menus, parent: Control, shell: Control, state: Dictionary, order: RefCounted,
		quote: Dictionary, action_used: Array[bool], notice: String, notice_color: Color) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var grades := HBoxContainer.new()
	grades.add_theme_constant_override("separation", 8)
	column.add_child(grades)
	for raw in Alchemy.grades(String(state.shape)):
		var grade := String(raw)
		var button := m._btn(grades, grade, func() -> void:
			_reopen(m, shell, {"grade": grade, "detail_scroll": 0}), UITheme.GOLD_BRIGHT)
		UITheme.tab(button, grade == String(state.grade), Items.GRADE_COLOR[grade])
		button.name = "AlchemyGrade_" + grade
		button.custom_minimum_size = Vector2(56, 44)
		button.tooltip_text = "%s grade · %s mastery" % [grade, _required_band(grade)]
	var scroll := ScrollContainer.new()
	scroll.name = "AlchemyDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	scroll.add_child(details)
	var item: Dictionary = quote.get("item", {})
	var grade := String(state.grade)
	if bool(state.get("sources", false)):
		m._lbl(details, "Ingredient sources", 16, UITheme.GOLD_BRIGHT)
		m._lbl(details, "Carry herbs and reagents at the recipe's exact grade. Claim mailed ingredients before brewing.", 14, UITheme.TEXT_MUTED)
		if grade == "A":
			m._lbl(details, "A-grade ingredients come from NG+ boss supplies: Chapter 4 onward in NG+1, or Chapter 1 onward in NG+2. The first journey's creatures and supply chests do not provide A ingredients.", 14, UITheme.TEXT_MUTED)
		elif grade in ["C", "B"]:
			m._lbl(details, "Boss supply chests and bundles can contain C/B herbs and reagents. Creature drops remain F/E, or E/D from elites.", 14, UITheme.TEXT_MUTED)
		else:
			m._lbl(details, "For F/E herbs, hunt plant and fungal creatures in Sporewood or the Blooming Deep; their elites yield E/D. Beasts, humanoids and void creatures can yield reagents at those grades. Boss supplies can also contain both ingredients.", 14, UITheme.TEXT_MUTED)
	var card := UITheme.card(details, Items.GRADE_COLOR[grade])
	var product := HBoxContainer.new()
	product.add_theme_constant_override("separation", 16)
	card.add_child(product)
	_icon(product, Art.consumable_icon(item), 64)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product.add_child(words)
	var name := m._lbl(words, String(item.get("name", "Unavailable recipe")), 21, Items.GRADE_COLOR[grade])
	name.name = "AlchemyProductName"
	name.custom_minimum_size.x = 480
	var effect := m._lbl(words, String(item.get("desc", "")), 16, TEXT)
	effect.name = "AlchemyProductEffect"
	effect.custom_minimum_size.x = 480
	var required := _required_band(grade)
	var requirement := "Grade %s · Requires %s mastery" % [grade, required]
	if grade in Items.BLUEPRINT_GRADES:
		requirement += " · Blueprint known" if bool(quote.get("blueprint_known", false)) else " · Blueprint not learned"
	else:
		requirement += " · No blueprint needed"
	m._lbl(details, requirement, 14, UITheme.TEXT_MUTED).name = "AlchemyRequirements"
	if grade in Items.BLUEPRINT_GRADES and not bool(quote.get("blueprint_known", false)):
		var learn_order: RefCounted = Alchemy.prepare(m.game, String(state.shape), grade, "blueprint")
		var learning: Dictionary = learn_order.view()
		var learn := m._btn(details, "Learn blueprint — %d gold" % int(learning.fee), func() -> void:
			if _owns(m, shell) and not action_used[0]:
				action_used[0] = true
				_learn(m, learn_order, required), UITheme.GOLD_BRIGHT, bool(learning.allowed))
		learn.name = "AlchemyLearnBlueprint"
		learn.custom_minimum_size.y = 44
		var learn_note := "Learn now; %s mastery is needed to brew. Bosses can also drop this recipe." % required
		if not bool(learning.allowed):
			learn_note = String(learning.reason)
		m._lbl(details, learn_note, 13, UITheme.TEXT_MUTED)
	UITheme.rule(column)
	_ingredient(m, column, "herb", grade, int(quote.get("herbs_have", 0)), int(quote.get("herbs", 0)))
	_ingredient(m, column, "reagent", grade, int(quote.get("reagents_have", 0)), int(quote.get("reagents", 0)))
	var fee := int(quote.get("fee", 0))
	var fee_text := "Fee %d gold · Have %d gold · +%d Alchemist mastery" % [fee, m.game.local_player.gold, int(quote.get("mastery_gain", 0))]
	var discount := roundi((1.0 - float(quote.get("favor_multiplier", 1.0))) * 100.0)
	if discount > 0:
		fee_text += " · Kesh favor: %d%% fee discount" % discount
	m._lbl(column, fee_text, 14, UITheme.GOLD_BRIGHT).name = "AlchemyFee"
	var brew := m._btn(column, "Brew one — %d gold" % fee, func() -> void:
		if not _owns(m, shell) or action_used[0]:
			return
		action_used[0] = true
		_remember(m)
		var result: Dictionary = Alchemy.commit(order)
		_settled(m, result), UITheme.GOLD_BRIGHT, bool(quote.get("allowed", false)))
	brew.name = "AlchemyBrew"
	brew.custom_minimum_size.y = 44
	var message := notice
	var color := notice_color
	if not bool(quote.get("allowed", false)):
		message += ("\n" if message != "" else "") + String(quote.get("reason", "Recipe unavailable."))
		if notice == "":
			color = Color(1.0, 0.72, 0.54)
	elif message == "":
		message = "Makes one bottle. If the pack remains full after brewing, the bottle goes to your mailbox."
	var result_line := m._lbl(column, message, 14, color)
	result_line.name = "AlchemyResult"
	result_line.custom_minimum_size.y = 38


static func _ingredient(m: Menus, parent: Control, family: String, grade: String, have: int, need: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	_icon(row, Art.material_ui_icon(family, grade), 32)
	var label := m._lbl(row, "%s · %s grade" % [String(Items.MATERIALS[family][grade]), grade], 15, TEXT)
	label.custom_minimum_size.x = 280
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var counts := "Have %d / Need %d" % [have, need]
	if have < need:
		counts += " · Short %d" % (need - have)
	var amount := m._lbl(row, counts, 15, Color(1.0, 0.68, 0.53) if have < need else Color(0.7, 0.95, 0.75))
	amount.name = "AlchemyIngredient_" + family
	amount.custom_minimum_size.x = 260
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func _icon(parent: Control, texture: Texture2D, side: float) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


static func _required_band(grade: String) -> String:
	for raw in Balance.MASTERY_BANDS:
		var band := String(raw)
		if Items.GRADES.find(grade) <= Items.GRADES.find(String(Balance.MASTERY_BAND_MAX_GRADE[band])):
			return band
	return "Master"


static func _learn(m: Menus, order: RefCounted, required: String) -> void:
	_remember(m)
	var quote: Dictionary = order.view()
	var used: Array[bool] = [false]
	# open_confirm checks its own exact shell BEFORE closing and invoking Yes.
	# Its cancellation callback restores this recipe and never commits the order.
	m.open_confirm("Learn the %s-grade %s blueprint for %d gold?\n\n%s mastery is needed to brew it. Learning never grants mastery or a bottle." % [
		String(quote.grade), String(Items.POTION_ACCORD_NOUN[String(quote.shape)]), int(quote.fee), required],
		func() -> void:
			if used[0]:
				return
			used[0] = true
			var result: Dictionary = Alchemy.commit(order)
			_settled(m, result), func() -> void:
			if not used[0]:
				used[0] = true
				open(m))


static func _settled(m: Menus, result: Dictionary) -> void:
	if not bool(result.ok):
		open(m, String(result.reason), Color(1.0, 0.7, 0.52))
		return
	m.game.sfx("chest")
	if result.has("blueprint"):
		open(m, "Learned %s. Paid %d gold." % [String(result.blueprint.name), int(result.fee)])
	else:
		var where := "Sent to your mailbox." if bool(result.mailed) else "Added to your pack."
		open(m, "Brewed %s. %s Paid %d gold; +%d mastery." % [
			String(result.item.name), where, int(result.fee), int(result.mastery_gain)])


static func _owns(m: Menus, shell: Control) -> bool:
	return is_instance_valid(m) and is_instance_valid(shell) and not shell.is_queued_for_deletion() \
		and m.root == shell and m.current == "alchemy"


## Menus.controller_back calls this for every Alchemy exit gesture.
static func back(m: Menus) -> void:
	_remember(m)
	m.open_professions()


static func _reopen(m: Menus, shell: Control, changes: Dictionary) -> void:
	if _owns(m, shell):
		open(m, "", Color(0.72, 0.92, 0.76), changes)


static func _remember(m: Menus) -> Dictionary:
	var owner: int = m.game.local_player.get_instance_id()
	var saved: Dictionary = m.get_meta(MEMORY, {})
	var state: Dictionary = saved.duplicate(true)
	if int(state.get("owner", 0)) != owner:
		state = {"owner": owner, "shape": "health_instant", "grade": "F", "filter": "all", "rail_scroll": 0, "detail_scroll": 0, "focus": "AlchemyShape_health_instant", "sources": false}
	if m.current == "alchemy" and is_instance_valid(m.root):
		for spec in [["AlchemyRecipeScroll", "rail_scroll"], ["AlchemyDetailScroll", "detail_scroll"]]:
			var scroll := m.root.find_child(String(spec[0]), true, false) as ScrollContainer
			if scroll != null:
				state[String(spec[1])] = scroll.scroll_vertical
		var focus := m.get_viewport().gui_get_focus_owner()
		if is_instance_valid(focus) and m.root.is_ancestor_of(focus):
			state.focus = String(focus.name)
	m.set_meta(MEMORY, state)
	return state


static func _restore(m: Menus, shell: Control, state: Dictionary) -> void:
	await m.get_tree().process_frame
	if not _owns(m, shell):
		return
	var focus := shell.find_child(String(state.focus), true, false) as Control
	if focus == null or (focus is BaseButton and focus.disabled):
		focus = shell.find_child("AlchemyGrade_" + String(state.grade), true, false) as Control
	if focus != null and focus.is_visible_in_tree() and focus.focus_mode != Control.FOCUS_NONE:
		focus.grab_focus()
	for spec in [["AlchemyRecipeScroll", "rail_scroll"], ["AlchemyDetailScroll", "detail_scroll"]]:
		var scroll := shell.find_child(String(spec[0]), true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = int(state[String(spec[1])])


static func _signature(m: Menus) -> int:
	var g := m.game
	if not is_instance_valid(g) or not g.has_local_player():
		return 0
	var p: Player = g.local_player
	return hash([p.get_instance_id(), g.chapter_id, g.wander_seed, g.world.get_instance_id() if is_instance_valid(g.world) else 0,
		p.profession, p.gold, p.materials, p.mastery, p.blueprints, p.bag_used(), p.bag_capacity(),
		g.favor_price_mult("kesh"), g.play_started, g.state, g.pvp_active, p.dead, p.downed, p.ghost, p.hp <= 0.0])


static func _watch(m: Menus, shell: Control) -> void:
	var watcher := QuoteWatch.new()
	watcher.menus = m
	watcher.shell = shell
	watcher.signature = _signature(m)
	watcher.read_signature = func() -> int: return _signature(m)
	watcher.refresh = func() -> void: open(m, "Your ingredients or recipe requirements changed.", UITheme.TEXT_MUTED)
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	shell.add_child(watcher)
