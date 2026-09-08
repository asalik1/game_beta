extends CanvasLayer
## A viewport-local pointer covers custom gear cards and map drags as well as
## ordinary Buttons. D-pad snaps between visible controls; right stick scrolls.
var pad: Node
var cursor := Vector2(640, 360)
var pointer_down := false
var click_root: Control
var paint: Control
var hints: Label
var key_root: Control
var text_target: LineEdit
var uppercase := false
var _scroll_clock := 0.0
var _snap_pending := false


func _ready() -> void:
	layer = 90
	paint = Control.new()
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paint.z_index = 100
	paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paint)
	paint.draw.connect(_draw_pointer)
	hints = Label.new()
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 13)
	hints.add_theme_color_override("font_color", Color(0.92, 0.87, 0.70))
	hints.add_theme_color_override("font_outline_color", Color(0.025, 0.03, 0.04))
	hints.add_theme_constant_override("outline_size", 6)
	add_child(hints)
	refresh_hints()


func keyboard_open() -> bool:
	return is_instance_valid(key_root)


func _root() -> Control:
	return key_root if keyboard_open() else pad.game.menus.root


func refresh_hints() -> void:
	if hints == null:
		return
	var g: Game = pad.game
	if keyboard_open():
		hints.text = "Left stick: cursor   •   D-pad: next key   •   %s: type   •   %s: backspace   •   %s: done" % [pad.label("interact"), pad.label("potion_next"), pad.label("cancel")]
	elif g.menus != null and g.menus.is_open():
		hints.text = "Left stick: cursor   •   D-pad: snap   •   Right stick: scroll   •   %s: select / drag   •   %s: back" % [pad.label("interact"), pad.label("cancel")]
		if g.menus.current == "fishing":
			hints.text = "%s: cast / strike / hold to reel   •   Left stick + %s: select lure   •   %s: leave" % [pad.label("a1"), pad.label("interact"), pad.label("cancel")]
		elif get_viewport().gui_get_focus_owner() is LineEdit:
			hints.text += "   •   %s: keyboard" % pad.label("potion")
	elif g.hud != null and g.hud.choices_active:
		hints.text = "D-pad ↑ ↓: choose   •   %s: confirm" % pad.label("interact")
	elif g.hud != null and g.hud.dialogue_active:
		hints.text = "%s: reveal / continue" % pad.label("interact")
	else:
		hints.text = "R3: lock / cycle · Right stick: choose · %s: release\nD-pad: map / bag / skills / codex · %s: pause" % [pad.label("cancel"), pad.label("pause")]
	if g.hud != null and g.hud.dialogue_hint != null:
		g.hud.dialogue_hint.text = "%s ▸" % pad.label("interact") if pad.active else ("TAP ▸" if g.touch_mode else "SPACE / click ▸")


func context_changed() -> void:
	if keyboard_open() and not _text_target_valid():
		close_keyboard()
	_snap_pending = true
	refresh_hints()


func _process(delta: float) -> void:
	if keyboard_open() and not _text_target_valid():
		close_keyboard()
	visible = pad.active and pad.focused
	if not visible:
		return
	var extent := get_viewport().get_visible_rect().size
	hints.position = Vector2(12, extent.y - 24)
	hints.size = Vector2(extent.x - 24, 22)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 13)
	if not pad.game.menus.is_open() and not keyboard_open():
		hints.position = Vector2(14, extent.y - 44)
		hints.size = Vector2(430, 42)
		hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hints.add_theme_font_size_override("font_size", 11)
	if _snap_pending and _root() != null:
		_snap_pending = false
		_snap(Vector2.ZERO)
	if pad.game.menus.is_open() or keyboard_open():
		var move: Vector2 = pad.stick()
		if move != Vector2.ZERO:
			var speed: float = lerpf(Balance.PAD_CURSOR_SLOW, Balance.PAD_CURSOR_FAST, float(pad.game.settings.get("pad_cursor_speed", Balance.PAD_CURSOR_DEFAULT)))
			move_cursor(cursor + move * speed * minf(delta, Balance.PAD_FRAME_CAP))
		_scroll_clock -= delta
		var scroll: Vector2 = pad.stick(true)
		if absf(scroll.y) > Balance.PAD_SCROLL_THRESHOLD and _scroll_clock <= 0.0:
			_scroll_clock = Balance.PAD_SCROLL_REPEAT
			var wheel := MOUSE_BUTTON_WHEEL_DOWN if scroll.y > 0 else MOUSE_BUTTON_WHEEL_UP
			_mouse_button(wheel, true)
			_mouse_button(wheel, false) # do not leave the viewport's mouse capture latched
	refresh_hints()
	paint.queue_redraw()


func _text_target_valid() -> bool:
	if not is_instance_valid(text_target) or not text_target.is_visible_in_tree():
		return false
	if text_target == pad.game.hud.chat_input:
		return pad.game.hud.chat_active
	return pad.game.menus.is_open() and pad.game.menus.root.is_ancestor_of(text_target)


func move_cursor(point: Vector2) -> void:
	var extent := get_viewport().get_visible_rect().size
	var old := cursor
	cursor = point.clamp(Vector2.ONE, extent - Vector2.ONE)
	var event := InputEventMouseMotion.new()
	event.position = cursor
	event.global_position = cursor
	event.relative = cursor - old
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pointer_down else 0
	_push(event)


func _push(event: InputEvent) -> void:
	event.set_meta("pad_pointer", true)
	get_viewport().push_input(event, true)


func _mouse_button(button: MouseButton, down: bool, at := Vector2.INF) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = cursor if at == Vector2.INF else at
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
	_push(event)


func cancel_pointer() -> void:
	if pointer_down:
		pointer_down = false
		# Release outside all controls: an interrupted press must never buy,
		# equip, or activate a new panel that replaced the old one.
		# BaseButton decides release activation from its hover state, not the
		# release coordinate alone. Move outside first to clear that state.
		var leave := InputEventMouseMotion.new()
		leave.position = Vector2(-100, -100)
		leave.global_position = leave.position
		leave.relative = leave.position - cursor
		leave.button_mask = MOUSE_BUTTON_MASK_LEFT
		_push(leave)
		_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(-100, -100))
	click_root = null


func menu_button(button: int, down: bool) -> void:
	if button == JOY_BUTTON_A:
		if down:
			pointer_down = true
			click_root = _root()
			move_cursor(cursor)
			_mouse_button(MOUSE_BUTTON_LEFT, true)
		elif pointer_down:
			if is_instance_valid(click_root) and click_root == _root():
				pointer_down = false
				_mouse_button(MOUSE_BUTTON_LEFT, false)
			else:
				cancel_pointer()
			click_root = null
		return
	if not down:
		return
	if button == JOY_BUTTON_B and keyboard_open():
		close_keyboard()
	elif button == JOY_BUTTON_X:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit:
			open_keyboard(focus)
	elif button == JOY_BUTTON_Y and keyboard_open():
		_backspace()
	elif not pointer_down:
		match button:
			JOY_BUTTON_DPAD_UP: _snap(Vector2.UP)
			JOY_BUTTON_DPAD_DOWN: _snap(Vector2.DOWN)
			JOY_BUTTON_DPAD_LEFT: _snap(Vector2.LEFT)
			JOY_BUTTON_DPAD_RIGHT: _snap(Vector2.RIGHT)


func _candidates(node: Node, out: Array[Control], clip: Rect2) -> void:
	if node is Control:
		if not node.is_visible_in_tree() or node.is_queued_for_deletion():
			return
		var rect: Rect2 = node.get_global_rect()
		if node.clip_contents:
			clip = clip.intersection(rect)
		var hit := rect.intersection(clip)
		var clickable: bool = node is BaseButton and not node.disabled or node is LineEdit or node is Slider
		clickable = clickable or (node.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and not node.get_signal_connection_list("gui_input").is_empty())
		if clickable and hit.size.x > 4 and hit.size.y > 4:
			out.append(node)
	for child in node.get_children():
		_candidates(child, out, clip)


func _snap(direction: Vector2) -> void:
	if _root() == null:
		return
	var candidates: Array[Control] = []
	_candidates(_root(), candidates, get_viewport().get_visible_rect())
	var best: Control
	var score := INF
	for c in candidates:
		var diff := _visible_center(c) - cursor
		if direction != Vector2.ZERO and diff.dot(direction) <= Balance.PAD_SNAP_MIN:
			continue
		var cost := diff.length()
		if direction != Vector2.ZERO:
			cost += absf(diff.cross(direction)) * Balance.PAD_SNAP_CROSS_WEIGHT
		if cost < score:
			score = cost
			best = c
	if best != null:
		move_cursor(_visible_center(best))


func _visible_center(control: Control) -> Vector2:
	var rect := control.get_global_rect().intersection(get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect.get_center()


func _draw_pointer() -> void:
	if not pad.game.menus.is_open() and not keyboard_open():
		return
	var color := Color(1.0, 0.9, 0.59) if not pointer_down else Color(0.52, 0.95, 0.84)
	paint.draw_circle(cursor, 11, Color(0.02, 0.025, 0.035, 0.92))
	paint.draw_arc(cursor, 10, 0, TAU, 32, color, 2, true)
	paint.draw_circle(cursor, 2, color)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		paint.draw_line(cursor + dir * 13, cursor + dir * 17, color, 2, true)


func open_keyboard(target: LineEdit) -> void:
	close_keyboard()
	text_target = target
	key_root = Control.new()
	key_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(key_root)
	UITheme.apply(key_root)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.035, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_root.add_child(dim)
	UITheme.panel(key_root, Vector2(240, 296), Vector2(800, 374))
	var column := VBoxContainer.new()
	column.position = Vector2(264, 312)
	column.size = Vector2(752, 344)
	key_root.add_child(column)
	var preview := Label.new()
	preview.name = "TextPreview"
	preview.text = target.text
	preview.custom_minimum_size.y = 30
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(preview)
	var grid := GridContainer.new()
	grid.columns = 10
	column.add_child(grid)
	for letter in "1234567890qwertyuiopasdfghjkl-zxcvbnm,.'/:@_+!?()=":
		var value: String = letter.to_upper() if uppercase else letter
		var b: Button = pad.game.menus._btn(grid, value, func() -> void: _type(value))
		b.custom_minimum_size = Vector2(70, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
	var row := HBoxContainer.new()
	column.add_child(row)
	for spec in [["Space", " "], ["Backspace", "back"], ["Shift", "shift"], ["Done", "done"]]:
		var value: String = spec[1]
		var b: Button = pad.game.menus._btn(row, spec[0], func() -> void: _special_key(value))
		b.custom_minimum_size = Vector2(180, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
	cursor = Vector2(640, 480)
	_snap_pending = true


func _type(value: String) -> void:
	if is_instance_valid(text_target):
		if text_target.has_selection():
			_delete_selection()
		text_target.insert_text_at_caret(value)
		text_target.text_changed.emit(text_target.text)
		key_root.find_child("TextPreview", true, false).text = text_target.text


func _backspace() -> void:
	if is_instance_valid(text_target):
		if text_target.has_selection():
			_delete_selection()
		elif text_target.caret_column > 0:
			var from := text_target.caret_column - 1
			text_target.delete_text(from, text_target.caret_column)
			text_target.caret_column = from
		text_target.text_changed.emit(text_target.text)
		key_root.find_child("TextPreview", true, false).text = text_target.text


func _delete_selection() -> void:
	var from := text_target.get_selection_from_column()
	text_target.delete_text(from, text_target.get_selection_to_column())
	text_target.deselect()
	text_target.caret_column = from


func close_keyboard() -> void:
	cancel_pointer()
	if keyboard_open():
		key_root.queue_free()
		key_root = null
	_snap_pending = true


func _special_key(value: String) -> void:
	match value:
		"back": _backspace()
		"shift":
			uppercase = not uppercase
			open_keyboard(text_target)
		"done":
			if text_target == pad.game.hud.chat_input and is_instance_valid(text_target):
				pad.game.hud._on_chat_submit(text_target.text)
			close_keyboard()
		_: _type(value)
