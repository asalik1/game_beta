extends ShotRig
## Real input, ordinary combat and pricing checks; --art isolates the cart view.
const Caravan := preload("res://scripts/road_caravan.gd")
var held := {}


func _ready() -> void:
	await boot(arg("class", "warrior"), "ch1", not flag("combat"))
	if arg("seed") != "":
		game.wander_seed = int(arg("seed"))
		game.switch_chapter("ch1", true)
		await frames(3)
		await skip_dialogue()
	game.terrain_event_t = 10000.0
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.player.set_physics_process(false)
	if flag("placement"):
		var placement_error := await preload("res://scripts/tests/caravan_placement_live.gd").run(self)
		if placement_error != "":
			push_error(placement_error)
			return finish(1)
		return finish()
	if not flag("art"):
		var error := await _checks()
		_release()
		if error != "":
			await _capture("diagnostic")
			push_error(error)
			return finish(1)
		return finish()
	var room := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		push_error("caravan art fixture has no road")
		return finish(1)
	game.player.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await sim_wait(2.5)
	var cart := Node2D.new()
	game.world.add_child(cart)
	cart.global_position = game.free_spawn_pos(game.room_center(room) + Vector2(40, -70), game.room_center(room))
	var body := Sprite2D.new()
	body.texture = load("res://assets/sprites/road_caravan_cart.png")
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.scale = Vector2.ONE * Balance.CARAVAN_ART_WIDTH / body.texture.get_width()
	body.position = (Vector2(0.5, 0.5) - Vector2(0.59, 0.76)) * Balance.CARAVAN_ART_WIDTH
	cart.add_child(body)
	game.player.global_position = cart.global_position + Vector2(130, 80)
	await sim_wait(0.3)
	shot("01_loaded_cart_at_game_scale")
	game.player.global_position = cart.global_position + Vector2(25, 30)
	await sim_wait(0.3)
	shot("02_walk_in_front")
	game.player.global_position = cart.global_position + Vector2(0, -30)
	await sim_wait(0.3)
	shot("03_walk_behind")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.player.global_position = cart.global_position + Vector2(140, 80)
	await sim_wait(0.3)
	shot("04_touch_road_scale")
	print("ok: original caravan cart displayed at game scale, with front/behind y-sort and touch context")
	finish()


func _press(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _release() -> void:
	for key in held:
		_press(int(key), false)
	game.player.clear_local_intents()


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label)


func _until(check: Callable, seconds := 6.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not check.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.03, true).timeout
	return check.call()


func _checks() -> String:
	var room := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		return "caravan has no starting road fixture"
	game.player.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await sim_wait(4.0)
	for entry in game.interactables.duplicate():
		var actor: Variant = entry.get("node")
		if is_instance_valid(actor) and actor.has_meta("road_context"):
			game._remove_interactable(actor)
	game._road_card_node(room, "caravan")
	var offer: Node2D
	for entry in game.interactables:
		if is_instance_valid(entry.node) and entry.node.has_meta("road_context"):
			offer = entry.node
	if offer == null:
		return "caravan road offer did not materialize"
	game.player.global_position = offer.global_position + Vector2(20, 30)
	game.talk_cd = 0.0
	_press(int(game.binds.interact), true)
	if not await _until(func() -> bool: return game.menus.current == "road_choice"):
		return "Interact did not open the actual caravan offer"
	_release()
	await _capture("01_trader_offer")
	var accept: Button
	for button in game.menus.root.find_children("*", "Button", true, false):
		if button.text.contains("Help free the cart"):
			accept = button
	if accept == null or accept.disabled:
		return "caravan help choice unavailable on a clear road"
	accept.pressed.emit()
	var cart := Caravan.find(game, room)
	if cart == null:
		_record_placement(room)
		return "accepted offer failed to install a clear cart"
	print("CARAVAN WORLD: seed=%d room=%d position=%s" % [game.wander_seed, room, cart.global_position])
	game.player.global_position = cart.handle.global_position + Vector2(-25, 30)
	await _capture("02_warned_attack")
	if flag("visibility"):
		return await preload("res://scripts/tests/caravan_visibility_live.gd").run(self, cart)
	if flag("combat"):
		return await preload("res://scripts/tests/caravan_combat_live.gd").run(self, cart)
	if not await _until(func() -> bool: return cart.phase == Caravan.WORKING):
		return "first caravan attack did not arrive"
	for enemy in cart.enemies:
		enemy.set_physics_process(false)
		enemy.global_position = cart.global_position + Vector2(350, 100)
	game.hud.dialogue([["Merchant", "The wheel can wait a moment."]])
	await frames(3)
	if not get_tree().paused or cart.status.visible:
		return "a paused dialogue retained the encounter panel over its words"
	await _capture("dialogue_hides_the_objective")
	await skip_dialogue()
	await frames(3)
	if not cart.status.visible:
		return "the caravan objective did not return after dialogue"
	var threat: Enemy = cart.enemies[0]
	threat.global_position = cart.global_position + Vector2(80, 20)
	var initial_integrity: float = cart.integrity
	_press(int(game.binds.interact), true)
	await sim_wait(1.2)
	_release()
	if cart.tugs != 0 or cart.integrity >= initial_integrity:
		return "real hold input ignored nearby load pressure"
	await _capture("03_clear_the_load_before_pulling")
	threat.global_position = cart.global_position + Vector2(350, -100)
	_press(int(game.binds.interact), true)
	if not await _until(func() -> bool: return cart.tugs == 6):
		return "holding Interact beside a nested handle did not free half the wheel"
	_release()
	if cart.wave != 1:
		return "second attack skipped the first living attackers"
	await _capture("04_half_free_attackers_remain")
	for enemy in cart.enemies.duplicate():
		enemy.take_damage(999999.0, Vector2.LEFT)
	if not await _until(func() -> bool: return cart.phase == Caravan.PREPARING and cart.wave == 2):
		return "real first-wave deaths did not trigger the second warning"
	await _capture("05_second_attack_warning")
	if not await _until(func() -> bool: return cart.phase == Caravan.WORKING):
		return "second caravan attack did not arrive"
	for enemy in cart.enemies.duplicate():
		enemy.take_damage(999999.0, Vector2.LEFT)
	if not await _until(func() -> bool: return cart.pending_deaths.is_empty()):
		return "second wave did not settle its actual deaths"
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(3)
	if not game.interact_in_range:
		return "touch Act did not become available beside the nested cart handle"
	await _capture("06_touch_help_at_the_shafts")
	_press(int(game.binds.interact), true)
	if not await _until(func() -> bool: return cart.phase == Caravan.COMPLETE):
		return "freed wheel and actual deaths did not supply the road"
	_release()
	await _capture("07_caravan_saved")
	if not Caravan.supplied(game) or game._room_hot(room):
		return "rescue lost its trade benefit or sealed its room"
	game.menus.open_shop(room, "buy")
	await _capture("08_supplied_merchant")
	game.menus.close()
	print("ok: caravan offer and pulling through real Interact input, warned waves, pressure, actual deaths, touch Act eligibility, open doors and supplied merchant")
	if flag("prices"):
		return await preload("res://scripts/tests/caravan_prices_live.gd").run(self, room)
	return ""


func _record_placement(room: int, label := "placement") -> void:
	var bounds := game.play_rect(room).grow(-Balance.CARAVAN_INSET)
	var observations := []
	for ring in 4:
		for spoke in 8:
			var point := (game.room_center(room) + Vector2.from_angle(TAU * spoke / 8.0) * ring * Balance.CARAVAN_PLACEMENT_STEP).clamp(bounds.position, bounds.end)
			var neighbors := []
			for interaction in game.interactables:
				var actor: Variant = interaction.get("node")
				if is_instance_valid(actor) and actor is Node2D and not actor.is_queued_for_deletion() and float(interaction.get("reach", Balance.INTERACT_RANGE)) > 0.0:
					var separation: float = actor.global_position.distance_to(point + Balance.CARAVAN_HANDLE_OFFSET)
					if separation < Balance.CARAVAN_INTERACTION_CLEARANCE:
						neighbors.append({"name": actor.name, "position": str(actor.global_position), "distance": separation})
			var blocked := []
			for offset in [Vector2.ZERO, Balance.CARAVAN_HANDLE_OFFSET, Vector2(-100, -50), Vector2(80, -50), Vector2(-100, 70), Vector2(80, 70)]:
				var sample: Vector2 = point + offset
				if game._pos_in_wall(sample) or game.free_spawn_pos(sample, game.room_center(room)).distance_to(sample) > 1.0:
					blocked.append(str(sample))
			observations.append({"point": str(point), "neighbors": neighbors, "blocked": blocked})
	var report := {"seed": game.wander_seed, "room": room, "bounds": str(bounds),
		"eligible": Caravan.Hunt.eligible(game, room), "hot": game._room_hot(room),
		"supplied": Caravan.supplied(game), "active": Caravan.active_in(game),
		"used": game.get_flag(game._road_flag(room), false),
		"busy": Caravan.Context.blocking_name(game, room), "candidates": observations}
	if not _write_report(label, report):
		push_error("could not write caravan placement diagnostics")
	print("CARAVAN PLACEMENT FAILURE: seed=%d room=%d bounds=%s; details in %s.json" % [game.wander_seed, room, bounds, label])


func _write_report(label: String, data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir)) != OK:
		return false
	var file := FileAccess.open(shot_dir.path_join(label + ".json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
