extends ShotRig
const Fishing := preload("res://scripts/fishing.gd")
const UIFishing := preload("res://scripts/ui/fishing.gd")


func _ready() -> void:
	await boot("archer", "ch1", false)
	var error: String = preload("res://scripts/tests/test_fishing.gd").run(self)
	if error != "":
		push_error(error)
		finish(1)
		return
	error = await _river()
	if error != "":
		push_error(error)
		finish(1)
		return
	print("ok: fishing world entry, live keyboard and pointer holds, claim, journal, cancellation, threat gate, touch and repaint cleanup")
	finish()


func _river() -> String:
	step("discover the village's generated river branch")
	var zi := -1
	for i in game.zone_count:
		if game.zones[i].name == "Stillwater Reach":
			zi = i
	if zi < 0 or game.rooms[zi].exits.is_empty():
		return "Stillwater is not connected to the generated map"
	for dir in game.rooms[zi].exits:
		var host := game.neighbor(zi, dir)
		if host < 0 or game.terrain_by_zone[host] != "village":
			return "Stillwater did not attach to the village area"
	var p: Player = game.local_player
	p.fishing_book = {}
	p.global_position = game.room_center(zi)
	game._enter_room(zi)
	await skip_dialogue()
	var spot: Node2D = null
	for candidate in get_tree().get_nodes_in_group("fishing_spots"):
		if candidate.zone == zi:
			spot = candidate
	if spot == null:
		return "authored Stillwater river did not build its fishing nook"
	p.global_position = spot.global_position + Vector2(-50, 0)
	game.camera.position_smoothing_enabled = false
	game.camera.offset = Vector2.ZERO
	await sim_wait(3.5)
	shot("river_nook")
	var menu := UIFishing.open(game.menus, spot, zi)
	await sim_wait(0.4)
	if menu == null:
		return "quiet fishing nook refused its player"
	shot("choose_lure")
	step("play a complete catch through real keyboard / button input")
	menu.model.rng.seed = 1907
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	if menu.model.state != "waiting":
		return "Space did not cast"
	for i in 500:
		await get_tree().process_frame
		if menu.model.state == "bite":
			break
	if menu.model.state != "bite":
		return "live cast never reached its bite"
	shot("bite")
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	if menu.model.state != "reeling":
		return "Space did not strike the bite"
	var saw_surge := false
	var pointer_down := false
	for i in 4000:
		var held: bool = not menu.model.surge() and not menu.model.warning() and menu.model.tension < 0.70
		if held != pointer_down:
			menu.reel.emit_signal("button_down" if held else "button_up")
			pointer_down = held
		await get_tree().process_frame
		if menu.model.surge() and not saw_surge:
			saw_surge = true
			shot("surge")
		if menu.model.state != "reeling":
			break
	menu.reel.emit_signal("button_up")
	await frames(2)
	if menu.model.state != "landed" or not menu.model.claimed or p.fishing_book.size() != 1:
		return "live fishing loop failed to land and record one fish: " + menu.model.state
	shot("landed")
	game.menus.open_codex("fishing")
	await frames(4)
	shot("catch_journal")
	game.menus.close()
	await frames(3)
	var before := p.fishing_book.duplicate(true)
	menu = UIFishing.open(game.menus, spot, zi)
	menu.model.state = "landed"
	menu.model.length_cm = 25
	game.menus.close()  # a closing/fading root must not pay on its last frame
	await frames(4)
	if before != p.fishing_book:
		return "closing fishing panel claimed a late catch"
	menu = UIFishing.open(game.menus, spot, zi)
	menu._cast()
	p.hp -= 1  # live-session damage: the overlay must stop immediately
	await frames(3)
	if game.menus.current == "fishing":
		return "damage failed to cancel fishing"
	var enemy := spawn_enemy("wolf", p.global_position + Vector2(180, 0))
	enemy.set_physics_process(false)
	if Fishing.blocked(game, spot, zi) == "":
		return "enemy near the bank failed to block fishing"
	enemy.queue_free()
	await frames(3)
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	menu = UIFishing.open(game.menus, spot, zi)
	await sim_wait(0.4)
	shot("touch_fishing")
	if game._touch_hud.visible or menu.reel.custom_minimum_size.y < 48:
		return "touch fishing retained combat controls or undersized reel button"
	menu.cast_button.emit_signal("pressed")
	if menu.model.state != "waiting":
		return "touch/mouse Cast failed"
	menu.model.state = "bite"
	menu.reel.emit_signal("button_down")
	if menu.model.state != "reeling" or not menu.hold_pointer:
		return "touch hold did not hook and reel"
	menu.reel.emit_signal("button_up")
	if menu.hold_pointer:
		return "touch release left the line reeling"
	game.menus.close()
	await frames(3)
	step("room repaint cleans up old interaction entries")
	game._spawn_scenery(zi)
	await frames(4)
	var count := 0
	for entry in game.interactables:
		if entry.get("fishing", false) and is_instance_valid(entry.node) and entry.node.zone == zi:
			count += 1
	if count != 1:
		return "terrain repaint left %d fishing interaction entries" % count
	return ""


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
