extends RefCounted
## Systems/quick regression for touch revive intent and the Settings editor.
## Direct _input matches autotest's touch overlay gate: headless does not route
## Input.parse_input_event to _input. No real transport or revive RPC is mocked.


static func suite(game: Node) -> String:
	var tree := game.get_tree()
	var mi: Node = game.get_node("/root/MobileInput")
	var kept := {}
	for key in ["touch_mode", "play_started", "state", "interact_in_range", "process_mode", "talk_cd", "no_saves"]:
		kept[key] = game.get(key)
	var held := {}
	for key in ["move", "a1", "a2", "a3", "ult", "potion", "potion_next", "interact", "active"]:
		held[key] = mi.get(key)
	var settings: Dictionary = game.settings.duplicate(true)
	var paused: bool = tree.paused
	var pad_active: bool = game.gamepad.active
	var finale_active: bool = game.chapter_finale.active
	var track: String = game.current_track
	var hud_kept := {}
	for key in ["visible", "dialogue_active", "choices_active", "chat_active"]:
		hud_kept[key] = game.hud.get(key)
	var menus: Node = game.menus
	var menu_root: Control = menus.root
	var menu_kept := {}
	for key in ["current", "settings_return", "title_stage"]:
		menu_kept[key] = menus.get(key)
	if menu_root != null:
		menu_root.hide()
	menus.root = null
	menus.current = ""
	# Freeze simulation independently of pause, so the old editor's unpause
	# cannot move the fixture. TouchHud and Menus process ALWAYS, even at boot.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.no_saves = true
	game.play_started = true
	game.state = game.ST_PLAYING
	game.gamepad.active = false
	game.chapter_finale.active = false
	game.hud.dialogue_active = false
	game.hud.choices_active = false
	game.hud.chat_active = false
	game.settings["touch_layout"] = {}
	game.touch_mode = true
	game._apply_touch_mode()
	var th: Node = game._touch_hud
	th._layout()
	th._release_everything()
	tree.paused = true
	var errors: Array[String] = []
	await _check_act(game, th, mi, errors)
	th._release_everything()
	await _check_editor(game, th, mi, errors)

	# Cleanup is outside the checks: every failed assertion still restores all
	# borrowed state before the caller queues _fail/quit.
	if th._edit_mode:
		th.exit_edit_mode()
	th._release_everything()
	menus.close()
	menus.root = menu_root
	for key in menu_kept:
		menus.set(key, menu_kept[key])
	if menu_root != null:
		menu_root.show()
	game.settings = settings
	game.set_music(track)
	game.gamepad.active = pad_active
	game.chapter_finale.active = finale_active
	for key in kept:
		game.set(key, kept[key])
	game._apply_touch_mode()
	if game._touch_hud != null:
		game._touch_hud._layout()
	for key in hud_kept:
		game.hud.set(key, hud_kept[key])
	for key in held:
		mi.set(key, held[key])
	tree.paused = paused
	return "; ".join(errors)


static func _touch(th: Node, pos: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	th._input(event)


static func _check_act(game: Node, th: Node, mi: Node, errors: Array[String]) -> void:
	game.interact_in_range = true
	th._process(0.0)
	var pos: Vector2 = th._btns["interact"]["center"]
	_touch(th, pos, true)
	if not mi.interact:
		errors.append("touch Act: press did not immediately hold interact")
	# Wall-clock wait crosses LONG_PRESS while _process continues under pause.
	await game.get_tree().create_timer(th.LONG_PRESS + 0.15).timeout
	if not mi.interact or (th._info != null and th._info.visible):
		errors.append("touch Act: long hold lost revive intent or opened an info card")
	_touch(th, pos, false)
	# The hold already reached the sim. A trailing tap pulse would outlive the
	# finger and fire the interaction a second time once talk_cd runs out.
	th._process(0.0)
	if mi.interact:
		errors.append("touch Act: release after a hold did not clear interact")
	_touch(th, pos, true)
	_touch(th, pos, false)
	if not mi.interact:
		errors.append("touch Act: sub-frame tap did not pulse interact")
	th._process(0.0)
	if not mi.interact:
		errors.append("touch Act: sub-frame tap pulse ended before the sim could see it")
	await game.get_tree().create_timer(th.TAP_PULSE + 0.1).timeout
	if mi.interact:
		errors.append("touch Act: tap pulse never cleared interact")
	# A previous tap must not expire a new hold (including a second finger).
	_touch(th, pos, true)
	_touch(th, pos, true, 1)
	_touch(th, pos, false, 1)
	await game.get_tree().create_timer(th.TAP_PULSE + 0.1).timeout
	if not mi.interact:
		errors.append("touch Act: an older release pulse cancelled a held finger")
	th._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if mi.interact or not th._btn_touch.is_empty():
		errors.append("touch Act: focus loss did not cancel hold")
	_touch(th, pos, true)
	game.menus.open_pause()
	await game.get_tree().process_frame
	th._process(0.0)
	if mi.interact:
		errors.append("touch Act: menu did not cancel hold")
	game.menus.close()
	game.get_tree().paused = true
	# The other buttons retain their explain-on-hold behavior.
	th._process(0.0)
	pos = th._btns["a1"]["center"]
	_touch(th, pos, true)
	await game.get_tree().create_timer(th.LONG_PRESS + 0.15).timeout
	if mi.a1 or th._info == null or not th._info.visible:
		errors.append("touch Act: ability long-press explanation regressed")
	_touch(th, pos, false)
	if mi.a1:
		errors.append("touch Act: explained ability fired on release")


static func _check_editor(game: Node, th: Node, mi: Node, errors: Array[String]) -> void:
	for back in ["pause", "title"]:
		game.play_started = back == "pause"
		game.menus.open_settings(back)
		await game.get_tree().process_frame
		game.menus._open_layout_editor()
		await game.get_tree().process_frame
		if not game.get_tree().paused or not th._edit_mode or not th._enabled or not th.visible:
			errors.append("touch editor: %s entry did not stay paused and editable" % back)
		var pos: Vector2 = th._btns["interact"]["center"]
		_touch(th, pos, true)
		if mi.interact or mi.move != Vector2.ZERO:
			errors.append("touch editor: dragging leaked gameplay input")
		_touch(th, pos, false)
		th.exit_edit_mode()
		await game.get_tree().process_frame
		if th._edit_mode or th._edit_ui.visible or not game.menus.is_open() \
				or game.menus.current != "settings" or not game.get_tree().paused:
			errors.append("touch editor: %s Done did not return to paused Settings" % back)
		game.menus.controller_back()
		await game.get_tree().process_frame
		if game.menus.current != back or (back == "title" and game.menus.title_stage != "slots"):
			errors.append("touch editor: %s Settings Back lost its origin" % back)
		game.menus.close()
	# ESC (or a pad's Start) leaves the editor the way Done does, even at boot
	# where ESC used to be refused.
	for back in ["pause", "title"]:
		game.play_started = back == "pause"
		game.get_tree().paused = true
		game.menus.open_settings(back)
		await game.get_tree().process_frame
		game.menus._open_layout_editor()
		await game.get_tree().process_frame
		game.hud._on_escape()
		await game.get_tree().process_frame
		if th._edit_mode or th._edit_ui.visible or game.menus.current != "settings" \
				or game.menus.settings_return != back or not game.get_tree().paused:
			errors.append("touch editor: %s ESC did not leave the editor for paused Settings" % back)
		game.menus.close()
	# A menu opened over the editor (the HUD's gear or a pad button) ends it in
	# place: Settings is not reopened on top, and closing that menu resumes
	# plain play, never a live editor that swallows every touch.
	game.play_started = true
	game.get_tree().paused = true
	game.menus.open_settings("pause")
	await game.get_tree().process_frame
	game.menus._open_layout_editor()
	await game.get_tree().process_frame
	game.menus.open_pause()
	await game.get_tree().process_frame
	th._process(0.0)
	if th._edit_mode or th._enabled or th._edit_ui.visible or game.menus.current != "pause":
		errors.append("touch editor: a menu opened over it left the editor live")
	game.menus.close()
	await game.get_tree().process_frame
	th._process(0.0)
	if th._edit_mode or th._edit_ui.visible:
		errors.append("touch editor: closing a menu over it resumed the world into the editor")
	game.get_tree().paused = true
	# A session keeps running under the editor: a run that ends mid-edit takes
	# the screen the same way (the editor closes; Settings is not reopened).
	game.menus.open_settings("pause")
	await game.get_tree().process_frame
	game.menus._open_layout_editor()
	await game.get_tree().process_frame
	th._process(0.0)
	var editing: bool = th._edit_mode
	game.state = game.ST_VICTORY
	th._process(0.0)
	if not editing or th._edit_mode or th._edit_ui.visible or game.menus.is_open():
		errors.append("touch editor: a run ending mid-edit left the editor up")
	game.state = game.ST_PLAYING
	game.get_tree().paused = true
	# Boot without a menu must still reject gameplay touches, even unpaused.
	game.play_started = false
	game.get_tree().paused = false
	th._process(0.0)
	_touch(th, Vector2(200, 500), true)
	if th._enabled or th.visible or mi.active:
		errors.append("touch editor: pre-play controls remained live outside edit mode")
