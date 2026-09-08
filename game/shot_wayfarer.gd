extends ShotRig
const Escort := preload("res://scripts/wayfarer.gd")
const Guide := preload("res://scripts/quest_guide.gd")


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.player.set_physics_process(false)
	game.player.hurt_cd = 9999.0
	var zi := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			zi = i
	game.player.global_position = game.room_center(zi)
	game._enter_room(zi)
	await skip_dialogue()
	await frames(3)
	var v := Escort.find(game)
	if v == null:
		return _fail("no traveler in the real outskirts")
	var p := game.player
	p.global_position = v.global_position + Vector2(0, 60)
	zoom(1.15)
	await sim_wait(3.5)
	shot("a_traveler_near_home")
	if not game.side_quest_available("one_more_mile"):
		return _fail("traveler not discoverable as a giver")
	# Route reservation must actually be traversable through the room's props.
	var query := PhysicsRayQueryParameters2D.create(v.start, v.goal, 1)
	if not game.world.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return _fail("scenery blocks the escort road")
	v.interact()
	await skip_dialogue()
	if not game.get_flag("sq_on_one_more_mile", false):
		return _fail("real conversation failed to accept the escort")
	v.interact()
	await frames(2)
	shot("escort_invitation")
	var start_button := game.menus.root.find_child("Escort_start", true, false)
	if start_button == null:
		return _fail("no explicit escort start")
	start_button.pressed.emit()
	if not v.active() or not game._room_hot(zi):
		return _fail("start did not reserve the encounter")
	v.request(p, "wait")
	await _wait_notices()
	v.request(p, "follow")
	var feet := {}
	for i in 8:
		p.global_position = v.global_position + Vector2(0, 60)
		await sim_wait(0.13)
		feet[v.body.frame] = true
		if i in [0, 2, 4, 6]:
			shot("walking_%d" % i)
	if feet.size() < 4:
		return _fail("traveler slid with a static animation")
	p.global_position = v.global_position + Vector2(0, 60)
	v.request(p, "wait")
	var at: Vector2 = v.global_position
	await sim_wait(0.35)
	if v.global_position != at or v.body.frame != 1:
		return _fail("wait order did not hold his position/stance")
	shot("hold_here")
	v.request(p, "follow")
	p.global_position = v.global_position + Vector2(0, 330)
	at = v.global_position
	await sim_wait(0.3)
	if v.global_position != at:
		return _fail("traveler walked away without company")
	p.global_position = v.global_position + Vector2(0, 60)
	game.menus.open_pause()
	at = v.global_position
	await get_tree().create_timer(0.3, true).timeout
	if v.global_position != at:
		return _fail("solo pause advanced escort movement")
	game.menus.close()
	while v.phase == 1:
		p.global_position = v.global_position + Vector2(0, 60)
		await frames(2)
	if v.phase != 2 or v.arrival_points.size() != 2:
		return _fail("first encounter lacked warning")
	shot("treeline_warning")
	await sim_wait(Balance.ESCORT_WARNING_SECONDS + 0.2)
	if v._living().size() != 2:
		return _fail("first pursuers absent")
	shot("protect_tovin")
	v.resolve = 1.0
	p.global_position = v.global_position + Vector2(0, 330)
	await sim_wait(0.4)
	if v.phase != 0 or not v._living().is_empty() or game._room_hot(zi):
		return _fail("failure did not reset and clean pursuers")
	shot("safe_to_retry")
	p.global_position = v.global_position + Vector2(0, 60)
	v.request(p, "start")
	game._death_world_reset(zi)
	if v.active():
		return _fail("death left a live escort")
	p.global_position = v.global_position + Vector2(0, 60)
	v.request(p, "start")
	v.request(p, "stop")
	if v.active():
		return _fail("stop did not end the escort")
	var wire_error: String = await preload("res://scripts/tests/test_escort_network.gd").run(self, v)
	if wire_error != "":
		return _fail(wire_error)
	game.flags["sq_on_one_more_mile"] = true
	var destination := Guide.destination(game, Guide.step(game, "one_more_mile"))
	if destination.is_empty() or destination.point.distance_to(v.global_position) > 1.0:
		return _fail("Journal could not find the moving quest actor")
	var purge: int = game.zone_alive[zi]
	v.request(p, "start")
	for encounter in 2:
		while v.phase == 1:
			p.global_position = v.global_position + Vector2(0, 60)
			await frames(2)
		if v.phase != 2 or v.stage != encounter + 1:
			return _fail("escort checkpoint order drifted")
		await sim_wait(Balance.ESCORT_WARNING_SECONDS + 0.2)
		var rng_before := game.loot_rng.state
		for e in v._living():
			e.take_damage(e.max_hp * 10, Vector2.RIGHT, false, true)
		await frames(3)
		if game.zone_alive[zi] != purge or game.loot_rng.state != rng_before:
			return _fail("escort foes paid loot or changed room purge")
	while v.phase == 1:
		p.global_position = v.global_position + Vector2(0, 60)
		await frames(2)
	if v.phase != 4 or not game.get_flag(Escort.DONE, false) or not game.title_available("road_companion"):
		return _fail("physical arrival did not finish/earn title")
	await _wait_notices()
	shot("home_at_the_fire")
	v.interact()
	await skip_dialogue()
	if not game.get_flag(Escort.KEPT, false):
		return _fail("recognition scene did not leave its persistent mark")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await _wait_notices()
	shot("touch_homecoming")
	print("ok: live escort opt-in, reserved road, actual walk frames, wait/follow/distance, pause, warnings, retry, death/stop, two fights, loot isolation, route, arrival/title, recognition and touch")
	finish()


func _wait_notices() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	await frames(3)
	while (is_instance_valid(game.hud._ann_active) or not game.hud._ann_queue.is_empty()) \
		and Time.get_ticks_msec() < deadline:
		await sim_wait(0.1)


func _fail(text: String) -> void:
	push_error(text)
	shot("failed")
	finish(1)
