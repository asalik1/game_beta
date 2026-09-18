extends ShotRig
const ControllerSettings := preload("res://scripts/ui/controller_settings.gd")
const UIFishing := preload("res://scripts/ui/fishing.gd")
var clicks := 0
var decision := -1


func _ready() -> void:
	if flag("interaction-copy"):
		var root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
		if not root.contains("/build/qa/") or flag("keyboard-hints") or flag("pad-context") or flag("no-capture"):
			push_error("Interaction-copy requires isolated build/qa profile and exclusive capture mode")
			finish(1)
			return
	elif flag("interaction-copy-guards"):
		push_error("Interaction-copy guards require interaction-copy mode")
		finish(1)
		return
	await boot("archer", "ch1", false)
	# The rig's direct pick_class seam skips the real name-entry confirmation.
	game.play_started = true
	game.hud.visible = true
	await sim_wait(4.0)
	if flag("interaction-copy"):
		var copy_error: String = await preload("res://scripts/tests/interaction_copy_live.gd").run(self)
		if copy_error != "": push_error(copy_error)
		finish(0 if copy_error == "" else 1)
		return
	if flag("keyboard-hints"):
		var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/")
		if not user_root.to_lower().contains("/build/qa/"):
			push_error("Keyboard-hints fixture requires isolated build/qa APPDATA")
			finish(1)
			return
		var hints_error: String = await preload("res://scripts/tests/keyboard_hints_live.gd").run(self)
		if hints_error != "": push_error(hints_error)
		finish(0 if hints_error == "" else 1)
		return
	if flag("pad-context"):
		var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/")
		if not user_root.to_lower().contains("/build/qa/"):
			push_error("Pad-context fixture requires isolated build/qa APPDATA")
			finish(1)
			return
		var context_error: String = await preload("res://scripts/tests/pad_context_live.gd").run(self)
		if context_error != "": push_error(context_error)
		finish(0 if context_error == "" else 1)
		return
	var error: String = preload("res://scripts/tests/test_gamepad.gd").run(self)
	if error == "":
		error = await _exercise()
	if error != "":
		push_error(error)
		finish(1)
		return
	print("ok: controller gameplay, trigger buffer, overlay release, pointer click/drag/scroll, keyboard, dialogue, target flick, fishing, touch handoff and disconnect")
	finish()


func _button(button: JoyButton, down: bool, device := 27) -> void:
	# Synthetic input must not depend on which app the user has foregrounded.
	game.gamepad.focused = true
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _axis(axis: JoyAxis, value: float) -> void:
	game.gamepad.focused = true
	var event := InputEventJoypadMotion.new()
	event.device = 27
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(button: JoyButton) -> void:
	_button(button, true)
	_button(button, false)


func _exercise() -> String:
	var pad: Node = game.gamepad
	var p: Player = game.local_player
	var m: Menus = game.menus
	step("analog movement and buffered triggers")
	_tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_LEFT_X, 0.59)
	p._poll_local_intents()
	if not is_equal_approx(p.intent_move.x, 0.5):
		return "half stick did not produce half speed: %s / %s / %s / %s" % [p.intent_move, pad.axes, pad.rearm, pad.focused]
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	if not p.action_buffer.has_press("a1", Time.get_ticks_msec() / 1000.0) or not pad.held("a1"):
		return "trigger did not queue and hold basic attack: active=%s focus=%s rearm=%s play=%s dead=%s overlay=%s trigger=%s pending=%s now=%s" % [pad.active, pad.focused, pad.rearm, game.play_started, p.dead, game.input_overlay_up(), pad._triggers, p.action_buffer.pending, Time.get_ticks_msec() / 1000.0]
	p.action_buffer.clear()
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.5)
	if not pad.held("a1") or not p.action_buffer.pending.is_empty():
		return "trigger hysteresis retriggered the buffer"
	_tap(JOY_BUTTON_START)
	await frames(2)
	if not m.is_open() or pad.held("a1") or not p.action_buffer.pending.is_empty():
		return "pause failed to stop a held trigger"
	get_tree().paused = false # co-op's overlay policy: physics continues behind menus
	p._physics_process(1.0 / 60.0)
	if p.intent_move != Vector2.ZERO or p.intent_a1 or p.intent_lock:
		return "controller input leaked under an unpaused overlay"
	_tap(JOY_BUTTON_B)
	p._poll_local_intents()
	if p.intent_a1:
		return "held trigger leaked back out of pause before release"
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	await frames(2)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	if not pad.held("a1"):
		return "released trigger never rearmed"
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	p.action_buffer.clear()
	step("actual menu buttons, controller cursor and settings")
	_tap(JOY_BUTTON_DPAD_LEFT)
	await frames(4)
	if m.current != "inventory":
		return "D-pad left failed to open the bag"
	shot("inventory")
	_tap(JOY_BUTTON_B)
	_tap(JOY_BUTTON_START)
	await frames(3)
	var before: Vector2 = pad.ui.cursor
	_axis(JOY_AXIS_LEFT_X, 0.8)
	await sim_wait(0.2)
	_axis(JOY_AXIS_LEFT_X, 0)
	if pad.ui.cursor.x <= before.x:
		return "left stick failed to move the menu cursor"
	var box := m._open("Controller interaction lab", 800, 560, true)
	m.current = "controller_test"
	var button := m._btn(box, "Click exactly once", func() -> void: clicks += 1)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(600, 50)
	slider.max_value = 100
	box.add_child(slider)
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(600, 40)
	field.text = "old"
	box.add_child(field)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 200)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	for i in 20:
		m._btn(list, "Scrollable row %d" % i, func() -> void: pass).custom_minimum_size = Vector2(500, 40)
	await frames(5)
	pad.ui.move_cursor(button.get_global_rect().get_center())
	_tap(JOY_BUTTON_A)
	if clicks != 1:
		return "controller pointer clicked %d times instead of once" % clicks
	var sr := slider.get_global_rect()
	pad.ui.move_cursor(sr.position + Vector2(5, 25))
	_button(JOY_BUTTON_A, true)
	pad.ui.move_cursor(sr.position + Vector2(sr.size.x * 0.8, 25))
	_button(JOY_BUTTON_A, false)
	if slider.value < 70:
		return "controller drag failed to adjust slider"
	pad.ui.move_cursor(scroll.get_global_rect().get_center())
	_axis(JOY_AXIS_RIGHT_Y, 0.9)
	await sim_wait(0.35)
	_axis(JOY_AXIS_RIGHT_Y, 0)
	if scroll.scroll_vertical <= 0:
		return "right stick failed to scroll a real container"
	field.grab_focus()
	field.select_all()
	_tap(JOY_BUTTON_X)
	await frames(4)
	if not pad.ui.keyboard_open():
		return "controller keyboard did not open"
	var key: Button = _find_button(pad.ui.key_root, "q")
	if key == null:
		return "keyboard keys missing"
	pad.ui.move_cursor(key.get_global_rect().get_center())
	await frames(2)
	_tap(JOY_BUTTON_A)
	if field.text != "q":
		return "controller typing did not replace the selected text: %s rect=%s cursor=%s hovered=%s active=%s visible=%s" % [field.text, key.get_global_rect(), pad.ui.cursor, get_viewport().gui_get_hovered_control(), pad.active, pad.ui.visible]
	_tap(JOY_BUTTON_Y)
	if field.text != "":
		return "controller backspace did not delete the typed character"
	pad.ui._type("River")
	shot("keyboard")
	_tap(JOY_BUTTON_B)
	if pad.ui.keyboard_open() or not m.is_open():
		return "closing keyboard closed its parent menu"
	field.grab_focus()
	_tap(JOY_BUTTON_X)
	await frames(2)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	if pad.active or pad.ui.keyboard_open():
		return "keyboard handoff left the controller keyboard blocking input"
	var escape_up := escape.duplicate()
	escape_up.pressed = false
	Input.parse_input_event(escape_up)
	Input.flush_buffered_events()
	# Escape also closed the lab. Reopen a tiny lab for the cancelled-press check.
	_tap(JOY_BUTTON_B)
	box = m._open("Controller interruption", 800, 560, true)
	m.current = "controller_test"
	button = m._btn(box, "Click exactly once", func() -> void: clicks += 1)
	await frames(3)
	pad.ui.move_cursor(button.get_global_rect().get_center())
	_button(JOY_BUTTON_A, true)
	ControllerSettings.open(m)
	_button(JOY_BUTTON_A, false)
	if clicks != 1:
		return "an interrupted controller press activated the old menu"
	await frames(5)
	shot("controller_settings")
	_tap(JOY_BUTTON_B)
	if m.current != "settings":
		return "controller settings back did not return to settings"
	m.close()
	await frames(3)
	_tap(JOY_BUTTON_DPAD_UP)
	await frames(4)
	var atlas := m.root.find_child("FieldAtlas", true, false)
	if atlas == null:
		return "D-pad up failed to open the atlas"
	pad.ui.move_cursor(atlas.chart.get_global_rect().get_center())
	var old_zoom: float = atlas._zoom
	_axis(JOY_AXIS_RIGHT_Y, -0.9)
	await sim_wait(0.25)
	_axis(JOY_AXIS_RIGHT_Y, 0)
	if atlas._zoom <= old_zoom:
		return "controller scroll failed to zoom the atlas"
	shot("field_atlas")
	_tap(JOY_BUTTON_B)
	step("dialogue decisions and target direction")
	game.hud.dialogue_choice("The ferryman", "Which road calls to you?", ["Follow the river.", "Take the old road."], func(value: int) -> void: decision = value)
	await frames(2)
	_tap(JOY_BUTTON_DPAD_DOWN)
	await frames(2)
	shot("dialogue_choice")
	_tap(JOY_BUTTON_A)
	if decision != 1 or game.hud.choices_active:
		return "D-pad dialogue selection chose the wrong response"
	var left := Enemy.make(game, "wolf", p.global_position + Vector2(-180, 0), -1, 1.0)
	var right := Enemy.make(game, "wolf", p.global_position + Vector2(180, 0), -1, 1.0)
	game.world.add_child(left)
	game.world.add_child(right)
	left.set_physics_process(false)
	right.set_physics_process(false)
	_axis(JOY_AXIS_RIGHT_X, 1)
	await frames(2)
	if p.locked_target != right:
		return "right-stick flick did not select right-hand target"
	shot("target_lock")
	_axis(JOY_AXIS_RIGHT_X, 0)
	await frames(2)
	_axis(JOY_AXIS_RIGHT_X, -1)
	await frames(2)
	if p.locked_target != left:
		return "second stick flick did not select left-hand target"
	_axis(JOY_AXIS_RIGHT_X, 0)
	_tap(JOY_BUTTON_B)
	await frames(2)
	if p.locked_target != null:
		return "cancel failed to release target lock"
	left.queue_free()
	right.queue_free()
	step("controller fishing and device handoff")
	var zi := -1
	for i in game.zone_count:
		if game.zones[i].name == "Stillwater Reach": zi = i
	p.global_position = game.room_center(zi)
	game._enter_room(zi)
	await skip_dialogue()
	var spot: Node2D
	for candidate in get_tree().get_nodes_in_group("fishing_spots"):
		if candidate.zone == zi: spot = candidate
	p.global_position = spot.global_position + Vector2(-50, 0)
	var fishing := UIFishing.open(m, spot, zi)
	await frames(3)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	if fishing.model.state != "waiting":
		return "trigger failed to cast at the river"
	fishing.model.step(fishing.model.bite_at, false)
	for i in 50:
		fishing.model.step(0.1, false)
		if fishing.model.state == "bite": break
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	if fishing.model.state != "reeling" or not fishing.hold_pad:
		return "trigger failed to hook / hold the reel"
	await frames(3)
	shot("fishing")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	if fishing.hold_pad:
		return "released trigger left the fishing line held"
	m.close()
	game.set_touch_controls(true)
	await frames(3)
	if game._touch_hud.visible:
		return "touch HUD obscured controller mode"
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(1200, 30)
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	var touch_up := touch.duplicate()
	touch_up.pressed = false
	Input.parse_input_event(touch_up)
	Input.flush_buffered_events()
	await frames(3)
	if pad.active or not game._touch_hud.visible:
		return "touch failed to reclaim mobile controls"
	m.open_settings()
	await frames(4)
	shot("touch_settings")
	m.close()
	game.set_touch_controls(false)
	_tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_LEFT_X, 1)
	pad._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if pad.focused or pad.movement() != Vector2.ZERO or not pad.buttons.is_empty():
		return "focus loss left gamepad input held"
	pad._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_X, 1)
	pad._connection(27, false)
	p._poll_local_intents()
	if pad.active or p.intent_move != Vector2.ZERO or not m.is_open():
		return "disconnect failed to clear movement and open pause"
	shot("disconnect_pause")
	return ""


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and node.text == text_value:
		return node
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null: return found
	return null
