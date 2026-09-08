extends Control
## A pause-aware solo minigame / live co-op overlay. Root identity and safety
## are checked before ticking or claiming; closing a fading shell cancels it.
const Fishing := preload("res://scripts/fishing.gd")
var m: Menus
var spot: Node2D
var zone := -1
var shell: Control
var model := Fishing.new()
var lure := "fly"
var hold_pointer := false
var hold_key := false
var hold_pad := false
var focus_guard := false
var start_hp := 0.0
var caption: Label
var instruction: Label
var input_hint: Label
var result: Label
var reel: Button
var cast_button: Button
var lure_buttons: Array[Button] = []
var view: Control
var art: TextureRect
var status_before := ""
var pulse := 0.0
var river_style: StyleBoxFlat


static func open(menus: Menus, target: Node2D, zi: int) -> Control:
	if Fishing.blocked(menus.game, target, zi) != "":
		return null
	var box := menus._open("Stillwater • fishing", 940, 650, true)
	menus.current = "fishing"
	var panel := new()
	panel.name = "FishingPanel"
	panel.m = menus
	panel.spot = target
	panel.zone = zi
	panel.shell = menus.root
	panel.start_hp = menus.game.local_player.hp
	panel.model.rng.randomize()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	panel.build()
	return panel


func build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	river_style = _water_style()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var water := Fishing.water_at(m.game, zone)
	m._lbl(column, "%s  /  %s water  /  catch & release" % [m.game.zones[zone].name, water], 14, UITheme.GOLD)
	var lures := HBoxContainer.new()
	lures.add_theme_constant_override("separation", 8)
	column.add_child(lures)
	for id in Fishing.LURES:
		var key := String(id)
		var button := m._btn(lures, String(Fishing.LURES[id]), func() -> void: _choose_lure(key))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40
		lure_buttons.append(button)
	view = Control.new()
	view.custom_minimum_size = Vector2(0, 220)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(view)
	view.draw.connect(_draw_water)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(art)
	caption = m._lbl(column, "A quiet stretch of river", 24, Color(0.93, 0.88, 0.72))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction = m._lbl(column, "Choose a lure. Cast, then strike when the float dips.", 16)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result = m._lbl(column, "No bait costs. No bag space. Every fish swims free.", 14, Color(0.65, 0.76, 0.77))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	cast_button = m._btn(actions, "Cast line", _cast, Color(0.57, 0.87, 0.81))
	reel = m._btn(actions, "Strike / hold to reel", func() -> void: pass, Color(0.97, 0.80, 0.43))
	# Physical hold semantics work on mouse and touch. Keyboard uses its own
	# press edge; focused Button key activation must not double-hook the fish.
	reel.focus_mode = Control.FOCUS_NONE
	reel.button_down.connect(_press)
	reel.button_up.connect(func() -> void: hold_pointer = false)
	for b in [cast_button, reel]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	m._btn(footer, "Catch journal", func() -> void: m.open_codex("fishing"))
	m._btn(footer, "Leave river", func() -> void: m.close())
	for b in footer.get_children():
		b.custom_minimum_size = Vector2(120, 40)
	var hint := m._lbl(footer, "Space: cast / strike / hold to reel" if not m.game.touch_mode else "Hold Reel • lift your finger to ease tension", 13, Color(0.72, 0.82, 0.83))
	input_hint = hint
	hint.custom_minimum_size = Vector2(420, 40)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_choose_lure(lure)
	_refresh()


func _active() -> bool:
	return is_instance_valid(m) and m.root == shell and m.current == "fishing"


func _choose_lure(id: String) -> void:
	if model.state in ["waiting", "bite", "reeling"]:
		return
	lure = id
	result.text = {"fly": "Reed fly • favours Greyrun Dace", "spinner": "Copper spinner • favours Copperfin", "feather": "Moon feather • favours Glass Eel and rare Crown Koi"}[id]
	for i in lure_buttons.size():
		UITheme.tab(lure_buttons[i], Fishing.LURES.keys()[i] == lure, Color(0.61, 0.86, 0.81))


func _cast() -> void:
	if not _active() or Fishing.blocked(m.game, spot, zone) != "":
		return
	hold_pointer = false
	hold_key = false
	if model.cast(Fishing.water_at(m.game, zone), lure):
		m.game.sfx("splash", 1.0, 0.0, -8.0)
		_refresh()


func _press() -> void:
	if not _active():
		return
	hold_pointer = true
	if model.state in ["waiting", "bite"]:
		model.hook()
	_refresh()


func _input(event: InputEvent) -> void:
	if not _active() or not event is InputEventKey or event.keycode != KEY_SPACE or event.echo:
		return
	hold_key = event.pressed
	if event.pressed:
		if model.state in ["ready", "escaped", "landed"]:
			_cast()
		elif model.state in ["waiting", "bite"]:
			model.hook()
	get_viewport().set_input_as_handled()


func pad_reel(down: bool) -> void:
	if not _active():
		return
	hold_pad = down
	if down:
		if model.state in ["ready", "escaped", "landed"]:
			_cast()
		elif model.state in ["waiting", "bite"]:
			model.hook()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		hold_key = false
		hold_pointer = false
		hold_pad = false
		focus_guard = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_guard = false


func _process(delta: float) -> void:
	if not _active():
		set_process(false)
		return
	if not is_instance_valid(spot) or m.game.cur_room != zone or m.game.local_player.dead \
			or m.game.local_player.downed or m.game.local_player.hp < start_hp \
			or Fishing.blocked(m.game, spot, zone) != "":
		m.close()
		return
	# Losing window focus must not turn a held reel into an unattended catch.
	start_hp = m.game.local_player.hp
	if focus_guard:
		return
	pulse += minf(delta, Balance.FISH_MAX_DELTA)
	input_hint.text = "%s: cast / strike / hold to reel" % m.game.gamepad.label("a1") if m.game.gamepad != null and m.game.gamepad.active else ("Hold Reel • lift your finger to ease tension" if m.game.touch_mode else "Space: cast / strike / hold to reel")
	if m.game.gamepad == null or not m.game.gamepad.active or not m.game.gamepad.focused:
		hold_pad = false
	model.step(delta, hold_pointer or hold_key or hold_pad)
	if model.state == "landed" and not model.claimed:
		var caught := model.claim(m.game.local_player)
		if not caught.is_empty():
			m.game.unlock_achievement("first_fish")
			if m.game.local_player.fishing_book.size() == Fishing.ORDER.size():
				m.game.unlock_achievement("riverkeeper")
			m.game.autosave()
			result.text = "%s • %.1f cm • released to the river" % [
				"NEW SPECIES" if caught.first else ("PERSONAL BEST" if caught.record else "CATCH RECORDED"), model.length_cm]
	if status_before != model.state:
		_refresh()
	if model.state == "reeling":
		caption.text = "SURGE — let it run" if model.surge() else ("Getting restless… release soon" if model.warning() else "Steady water — reel it in")
		instruction.text = "Landing %d%%   •   Line tension %d%%" % [int(model.progress * 100), int(model.tension * 100)]
	view.queue_redraw()


func _refresh() -> void:
	var changed := status_before != model.state
	status_before = model.state
	var busy: bool = model.state in ["waiting", "bite", "reeling"]
	cast_button.disabled = busy
	reel.disabled = not busy
	for b in lure_buttons:
		b.disabled = busy
	art.visible = model.state in ["reeling", "landed"]
	if art.visible:
		art.texture = Fishing.texture(model.species)
	match model.state:
		"ready": pass
		"waiting":
			caption.text = "Watch the float…"
			instruction.text = "Wait for the sharp dip, then tap Strike." if m.game.touch_mode else "Wait for the sharp dip, then click Strike or press Space."
			result.text = "The river takes its own time."
		"bite":
			caption.text = "BITE! Strike now"
			instruction.text = "Tap Strike, then hold to reel." if m.game.touch_mode else "Click Strike or press Space, then hold to reel."
			if changed:
				m.game.sfx("splash", 1.5, 0.0, -4.0)
		"reeling":
			result.text = "Clean hook — keep the line cool for a larger catch." if model.clean_hook else "Reel in calm water. Release when the fish surges."
		"landed":
			if changed:
				m.game.sfx("ward", 1.1, 0.0, -6.0)
			caption.text = Fishing.SPECIES[model.species].name
			instruction.text = "%.1f cm  •  %d of 4 species recorded" % [model.length_cm, m.game.local_player.fishing_book.size()]
			cast_button.text = "Cast again"
		"escaped":
			caption.text = "Back to the river"
			instruction.text = model.result_text
			result.text = "Nothing lost. Change your lure or try another cast."
			cast_button.text = "Try again"


func _draw_water() -> void:
	var s := view.size
	var rect := Rect2(Vector2.ZERO, s)
	view.draw_style_box(river_style, rect)
	# Code-native water animation, not a baked illustration: the float,
	# line and ripples respond to the actual bite and reel states.
	for i in 11:
		var y := 18.0 + i * (s.y - 35) / 11.0
		var points := PackedVector2Array()
		for x in range(12, int(s.x) - 10, 12):
			points.append(Vector2(x, y + sin(x * 0.025 + pulse * 0.6 + i) * 3))
		view.draw_polyline(points, Color(0.25, 0.47, 0.47, 0.18), 1, true)
	if model.state == "landed":
		art.modulate = Color.WHITE
		art.size = Vector2(300, minf(s.y + 24, 300))
		art.position = (s - art.size) * 0.5
		return
	if model.state == "reeling":
		art.size = Vector2(155, 110)
		art.position = Vector2(lerpf(s.x * 0.75, s.x * 0.28, model.progress), s.y * 0.2 + sin(pulse * 2) * 8)
		art.modulate = Color(0.58, 0.79, 0.79, 0.72)
	var float_pos := Vector2(s.x * 0.5 + sin(pulse * 1.1) * 12, s.y * 0.45 + sin(pulse * 2.0) * 3)
	if model.state == "bite":
		float_pos.y += 10 + sin(pulse * 28) * 4
	if model.state == "reeling":
		float_pos.x += sin(pulse * (7 if model.surge() else 2)) * (48 if model.surge() else 14)
	var tint := Color(0.96, 0.66, 0.37) if model.surge() and model.state == "reeling" else Color(0.61, 0.88, 0.83)
	for i in 3:
		var t := fmod(pulse * 0.5 + i / 3.0, 1.0)
		view.draw_set_transform(float_pos, 0, Vector2(1, 0.4))
		view.draw_arc(Vector2.ZERO, 12 + t * 65, 0, TAU, 48, Color(tint, (1 - t) * 0.4), 1.5, true)
		view.draw_set_transform(Vector2.ZERO)
	if model.state in ["waiting", "bite", "reeling"]:
		view.draw_line(Vector2(s.x * 0.22, s.y), float_pos, Color(0.9, 0.86, 0.65, 0.6), 1.3, true)
	view.draw_line(float_pos - Vector2(0, 15), float_pos + Vector2(0, 5), Color(0.18, 0.14, 0.11), 7, true)
	view.draw_line(float_pos - Vector2(0, 14), float_pos - Vector2(0, 5), Color(0.93, 0.48, 0.32), 5, true)
	view.draw_line(float_pos - Vector2(0, 4), float_pos + Vector2(0, 3), Color(0.97, 0.92, 0.77), 5, true)
	if model.state == "reeling":
		_bar(Rect2(36, s.y - 47, s.x - 72, 10), model.progress, Color(0.42, 0.82, 0.75))
		_bar(Rect2(36, s.y - 27, s.x - 72, 7), model.tension,
			Color(0.97, 0.47, 0.34) if model.tension > 0.7 else Color(0.94, 0.76, 0.39))


func _bar(rect: Rect2, value: float, tint: Color) -> void:
	view.draw_rect(rect, Color(0.015, 0.035, 0.045, 0.9))
	view.draw_rect(Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)), tint)


func _water_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.19, 0.21)
	style.border_color = Color(0.32, 0.52, 0.48, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


static func journal(menus: Menus, list: VBoxContainer) -> void:
	var book: Dictionary = menus.game.local_player.fishing_book
	menus._lbl(list, "%d / 4 species • catch journal" % book.size(), 23, UITheme.GOLD)
	var text := menus._lbl(list, "Fish at Stillwater Reach, near Emberfall, or at the tackle boxes beside marsh rivers. All three lures are free. Catch and release all four species to earn the Riverkeeper title.", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 650
	var help := menus._lbl(list, "Cast → wait for BITE → strike → hold to reel. Release during surges and when tension runs high. A quick, cool-headed catch improves its size. Space works on keyboard; the Reel button supports mouse and touch.", 14, Color(0.68, 0.80, 0.80))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 650
	for id in Fishing.ORDER:
		var def: Dictionary = Fishing.SPECIES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Fishing.texture(id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(120, 112)
		icon.modulate = Color.WHITE if book.has(id) else Color(0.74, 0.76, 0.78)
		row.add_child(icon)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		menus._lbl(column, def.name, 20, def.color)
		var record: Dictionary = book.get(id, {})
		menus._lbl(column, "Best %.1f cm  •  %d released" % [float(record.get("best", 0)), int(record.get("count", 0))] if not record.is_empty() else "Not yet recorded", 14, Color(0.92, 0.87, 0.72))
		var note := menus._lbl(column, def.note, 14, Color(0.70, 0.76, 0.77))
		note.custom_minimum_size.x = 480
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
