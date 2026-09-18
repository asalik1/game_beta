extends Node
## One local device adapter. Combat goes through the existing intent/buffer
## seam; menu pointer events stay inside this viewport and never move the OS cursor.
const PadUI := preload("res://scripts/ui/gamepad_cursor.gd")
const BUTTON_ACTIONS := {JOY_BUTTON_RIGHT_SHOULDER: "a3", JOY_BUTTON_LEFT_SHOULDER: "ult",
	JOY_BUTTON_A: "interact", JOY_BUTTON_X: "potion", JOY_BUTTON_Y: "potion_next"}
const LABELS := {"a1": "RT", "a2": "LT", "a3": "RB", "ult": "LB", "interact": "A",
	"potion": "X", "potion_next": "Y", "target": "R3", "inventory": "D-pad ←",
	"skills": "D-pad →", "codex": "D-pad ↓", "map": "D-pad ↑", "cancel": "B", "pause": "Menu"}
const PS_LABELS := {"RT": "R2", "LT": "L2", "RB": "R1", "LB": "L1", "A": "×",
	"B": "○", "X": "□", "Y": "△", "Menu": "Options"}
var game: Game
var device := -1
var active := false
var focused := true
var buttons := {}
var axes := {}
var rearm := false
var ui: CanvasLayer
var choice_index := 0
var _context := ""
var _target_ready := true
var _triggers := {"a1": false, "a2": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = PadUI.new()
	ui.pad = self
	add_child(ui)
	Input.joy_connection_changed.connect(_connection)


func label(action: String) -> String:
	var value: String = LABELS.get(action, action)
	var scheme: String = game.settings.get("pad_labels", "auto")
	var name_lower := Input.get_joy_name(device).to_lower() if device >= 0 else ""
	if scheme == "playstation" or (scheme == "auto" and ("playstation" in name_lower or "dualsense" in name_lower or "dualshock" in name_lower or "ps4" in name_lower or "ps5" in name_lower)):
		return PS_LABELS.get(value, value)
	return value


static func radial(raw: Vector2, deadzone: float) -> Vector2:
	if not raw.is_finite():
		return Vector2.ZERO
	var dz := clampf(deadzone, Balance.PAD_DEADZONE_MIN, Balance.PAD_DEADZONE_MAX)
	var length := minf(raw.length(), 1.0)
	return Vector2.ZERO if length <= dz else raw.normalized() * ((length - dz) / (1.0 - dz))


func stick(right := false) -> Vector2:
	var first := JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X
	return radial(Vector2(float(axes.get(first, 0.0)), float(axes.get(first + 1, 0.0))), float(game.settings.get("pad_deadzone", Balance.PAD_DEADZONE)))


func held(action: String) -> bool:
	if not active or not focused or rearm or game.input_overlay_up():
		return false
	if action in ["a1", "a2"]:
		return bool(_triggers[action])
	for button in BUTTON_ACTIONS:
		if BUTTON_ACTIONS[button] == action:
			return bool(buttons.get(button, false))
	return false


func movement() -> Vector2:
	return stick() if active and focused and not rearm and not game.input_overlay_up() else Vector2.ZERO


func _neutral() -> bool:
	return not true in buttons.values() and stick() == Vector2.ZERO and stick(true) == Vector2.ZERO \
		and not _triggers.a1 and not _triggers.a2


func cancel_held() -> void:
	buttons.clear()
	axes.clear()
	_triggers = {"a1": false, "a2": false}
	rearm = true
	if ui != null:
		ui.cancel_pointer()
	if is_instance_valid(game.local_player):
		game.local_player.clear_local_intents()
		game.local_player.intent_lock = false
		game.local_player.intent_lock_release = false


func _connection(id: int, connected: bool) -> void:
	if id != device or connected:
		return
	cancel_held()
	device = -1
	_set_active(false)
	if game.play_started and not game.input_overlay_up():
		game.hud._on_escape()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		cancel_held()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true


func _set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if not on:
		cancel_held()
		if ui != null:
			ui.close_keyboard()
	elif game._touch_hud != null:
		game._touch_hud._release_everything()
	if game.hud != null:
		game.hud.set_touch_mode(game.touch_mode and not active)
		for hint in game.hud.hint_labels:
			hint.visible = not active and not game.touch_mode
	if ui != null:
		ui.refresh_hints()
	game.refresh_interaction_copy()


func _input(event: InputEvent) -> void:
	if event.has_meta("pad_pointer") or not focused:
		return
	if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed \
			or event is InputEventMouseMotion and event.relative.length() > Balance.PAD_MOUSE_WAKE \
			or event is InputEventScreenTouch and event.pressed:
		var keyboard_was_open: bool = ui.keyboard_open()
		_set_active(false)
		if keyboard_was_open and (event is InputEventMouseButton or event is InputEventScreenTouch):
			get_viewport().set_input_as_handled() # dismissing the keyboard cannot click through it
		return
	if not event is InputEventJoypadButton and not event is InputEventJoypadMotion:
		return
	var meaningful: bool = event.pressed if event is InputEventJoypadButton else absf(event.axis_value) > Balance.PAD_WAKE_AXIS
	if event.device != device:
		if not meaningful or (device >= 0 and not _neutral()):
			return
		cancel_held()
		device = event.device
		rearm = false
		if active:
			game.refresh_interaction_copy()
	if meaningful:
		_set_active(true)
	_sync_context()
	if event is InputEventJoypadMotion:
		axes[event.axis] = event.axis_value if is_finite(event.axis_value) else 0.0
		if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			var slot := "a1" if event.axis == JOY_AXIS_TRIGGER_RIGHT else "a2"
			var was: bool = _triggers[slot]
			_triggers[slot] = event.axis_value > (Balance.PAD_TRIGGER_OFF if was else Balance.PAD_TRIGGER_ON)
			if not was and _triggers[slot] and _can_play():
				game.local_player.queue_ability(slot)
			if slot == "a1" and was != _triggers[slot] and game.menus.current == "fishing":
				var fishing := game.menus.root.find_child("FishingPanel", true, false)
				if fishing != null:
					fishing.pad_reel(_triggers[slot])
	else:
		var was: bool = buttons.get(event.button_index, false)
		buttons[event.button_index] = event.pressed
		if not event.pressed or not was:
			_button(event.button_index, event.pressed)
	if rearm and _neutral():
		rearm = false
	# No second activation through Godot's built-in ui_accept joy bindings.
	get_viewport().set_input_as_handled()


func _can_play() -> bool:
	return active and focused and not rearm and game.play_started and game.state == Game.ST_PLAYING \
		and is_instance_valid(game.local_player) and not game.local_player.dead \
		and not game.local_player.downed and not game.local_player.ghost and not game.input_overlay_up()


func _button(button: int, down: bool) -> void:
	if ui.keyboard_open():
		ui.menu_button(button, down)
		return
	var m: Menus = game.menus
	if m.is_open():
		if m.current == "title" and m.title_stage == "cover" and down:
			m.open_slots()
		elif button in [JOY_BUTTON_B, JOY_BUTTON_START] and down:
			ui.cancel_pointer()
			m.controller_back()
		else:
			ui.menu_button(button, down)
		return
	if not down:
		return
	var h: Hud = game.hud
	if h.chat_active:
		if button == JOY_BUTTON_B:
			h._close_chat()
		elif button == JOY_BUTTON_X:
			ui.open_keyboard(h.chat_input)
		return
	if h.choices_active:
		if button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN] and h.choice_count > 0:
			h._set_choice_hover(choice_index, false)
			choice_index = posmod(choice_index + (-1 if button == JOY_BUTTON_DPAD_UP else 1), h.choice_count)
			h._set_choice_hover(choice_index, true)
		elif button == JOY_BUTTON_A:
			h._choose(choice_index)
		return
	if h.dialogue_active:
		if button == JOY_BUTTON_A:
			if h.log_panel != null and h.log_panel.visible:
				h.log_panel.visible = false
			elif not h._reveal_complete():
				h._finish_reveal()
			else:
				h._advance_dialogue()
		return
	if game.state == Game.ST_VICTORY:
		if button == JOY_BUTTON_A:
			game.victory_dismiss()
		return
	if button == JOY_BUTTON_START:
		h._on_escape()
		return
	if not _can_play():
		return
	match button:
		JOY_BUTTON_BACK, JOY_BUTTON_DPAD_LEFT: m.open_inventory()
		JOY_BUTTON_DPAD_RIGHT: m.open_skills()
		JOY_BUTTON_DPAD_UP: m.open_map()
		JOY_BUTTON_DPAD_DOWN: m.open_codex()
		JOY_BUTTON_RIGHT_STICK: game.local_player.intent_lock = true
		JOY_BUTTON_B: game.local_player.intent_lock_release = true
		JOY_BUTTON_LEFT_STICK:
			if game.net_online():
				h.open_chat()
				ui.open_keyboard(h.chat_input)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			game.local_player.queue_ability(BUTTON_ACTIONS[button])


func _sync_context() -> void:
	var next := "play"
	if game.menus.is_open():
		next = "menu:%d:%s" % [game.menus.root.get_instance_id(), game.menus.current]
	elif game.hud.choices_active:
		next = "choice:%s" % game.hud.text_label.text
	elif game.hud.dialogue_active:
		next = "dialogue"
	elif game.hud.chat_active:
		next = "chat"
	elif game.state != Game.ST_PLAYING:
		next = "state:%d" % game.state
	if next != _context:
		_context = next
		rearm = not _neutral()
		ui.cancel_pointer()
		choice_index = 0
		if active and game.hud.choices_active:
			game.hud._set_choice_hover(0, true)
		# The observed non-play edge already cancelled pre-overlay input.
		# Returning to play must preserve a fresh post-close buffered tap.
		if next != "play" and is_instance_valid(game.local_player):
			game.local_player.action_buffer.clear()
		ui.context_changed()


func _process(_delta: float) -> void:
	_sync_context()
	if not active or not focused:
		return
	if rearm and _neutral():
		rearm = false
	var aim := stick(true)
	if aim.length() < Balance.PAD_TARGET_RELEASE:
		_target_ready = true
	elif _target_ready and aim.length() >= Balance.PAD_TARGET_FLICK and _can_play():
		_target_ready = false
		game.local_player.lock_toward(aim.normalized())
