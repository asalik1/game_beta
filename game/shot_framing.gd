extends ShotRig
## Camera composition, target feedback and movement fault reproduction.


func _ready() -> void:
	await boot("archer", "ch1", false)
	var error: String = preload("res://scripts/tests/test_framing.gd").run(self)
	if error != "":
		push_error(error)
		finish(1)
		return
	error = await _hitstop_probe()
	if error != "":
		push_error(error)
		finish(1)
		return
	error = await _wall_probe()
	if error != "":
		push_error(error)
		finish(1)
		return
	if flag("fault-probe"):
		finish()
		return
	await _visuals()
	if game._touch_hud.visible:
		push_error("touch combat buttons remained visible under the paused comfort menu")
		finish(1)
		return
	finish()


func _hitstop_probe() -> String:
	step("zero-time hit-stop with overlapping bodies")
	var p: Player = game.local_player
	var e := spawn_enemy("wolf", p.global_position + Vector2(40, 0))
	await frames(2)
	# Deliberately overlap: collision recovery used to move bodies even
	# while the player's view was frozen, then divide displacement by zero.
	e.global_position = p.global_position + Vector2(12, 0)
	var ep := e.global_position
	var pp := p.global_position
	var clock := e.anim_t
	game.hit_stop(0.3)
	await get_tree().create_timer(0.1, true, false, true).timeout
	var error := ""
	if e.global_position != ep or p.global_position != pp or e.anim_t != clock:
		error = "overlapping actors moved or animated during hit-stop"
	if not e.get_real_velocity().is_finite() or not p.get_real_velocity().is_finite():
		error = "zero-time collision step poisoned an actor's measured velocity"
	await get_tree().create_timer(0.25, true, false, true).timeout
	e.queue_free()
	if error == "":
		print("ok: live hit-stop freezes overlapping bodies without invalid measured velocity")
	return error


func _wall_probe() -> String:
	step("four-direction wall collision and measured travel")
	var p: Player = game.local_player
	var saved := {"position": p.global_position, "velocity": p.velocity,
		"mask": p.collision_mask, "layer": p.collision_layer,
		"physics": p.is_physics_processing(), "process": game.is_processing()}
	var enemies := {}
	for other in get_tree().get_nodes_in_group("enemies"):
		enemies[other] = other.is_physics_processing()
		other.set_physics_process(false)
	game.set_process(false)
	p.set_physics_process(false)
	var e := spawn_enemy("wolf", p.global_position)
	e.set_physics_process(false)
	# Isolate the fixture from scenery, gates and incidental projectiles.
	var layer := 1 << 25
	var wall := StaticBody2D.new()
	wall.collision_layer = layer
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 400)
	shape.shape = rect
	wall.add_child(shape)
	game.world.add_child(wall)
	var origin: Vector2 = saved["position"]
	var error := ""
	for unit in [p, e]:
		unit.collision_layer = 0
		unit.collision_mask = layer
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			unit.global_position = origin
			wall.global_position = origin + direction * 48
			wall.rotation = direction.angle()
			await get_tree().physics_frame
			for i in 16:
				await get_tree().physics_frame
				unit.velocity = direction * 240
				unit._move_body()
			var displacement: Vector2 = unit.global_position - origin
			var travel: float = displacement.dot(direction)
			if travel < 1.0 or travel > 32.0 or absf(displacement.dot(direction.orthogonal())) > 0.25:
				error = "actor failed to approach and stop at a wall consistently in direction %s" % direction
			if unit.velocity.length() > 1.0:
				error = "blocked actor still reported walking speed to its animation clock"
			if error != "":
				break
		if error != "":
			break
	e.queue_free()
	wall.queue_free()
	p.global_position = saved["position"]
	p.velocity = saved["velocity"]
	p.collision_mask = saved["mask"]
	p.collision_layer = saved["layer"]
	p.set_physics_process(saved["physics"])
	game.set_process(saved["process"])
	for other in enemies:
		if is_instance_valid(other):
			other.set_physics_process(enemies[other])
	if error == "":
		print("ok: hero and wolf stop at all four wall orientations; blocked stride speed is zero")
	return error


func _visuals() -> void:
	var p: Player = game.local_player
	p.char_name = "The Uncrowned"
	p.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	apply_terrain("keep", 2)
	await sim_wait(4.0)
	p.set_physics_process(false)
	game.camera.position_smoothing_enabled = false
	game.settings["camera_shake"] = 0.0
	for pair in [["east", Vector2(650, 0)], ["north", Vector2(0, -370)]]:
		step("ranged encounter " + pair[0])
		var e := spawn_enemy("beastkin_raider", p.global_position + pair[1])
		e.set_physics_process(false)
		e.alerted = true
		p.locked_target = e
		# Match the old camera's real combat multiplier for the comparison.
		game.set_process(false)
		game.camera.zoom = Vector2.ONE * 1.12 * 1.08
		game.camera.offset = Vector2.ZERO
		game.hud.track_target_bar(e)
		await frames(3)
		shot(pair[0] + "_before")
		game.camera.zoom = Vector2.ONE * 1.12
		game._cam_zoom_mult = 1.0
		game.camera_framing.hero_id = 0
		game.set_process(true)
		await sim_wait(2.5)
		shot(pair[0] + "_framed")
		e.hp = e.max_hp * 0.42
		game.hud.track_target_bar(e)
		await frames(1)
		shot(pair[0] + "_damage")
		await sim_wait(1.6)
		shot(pair[0] + "_settled")
		e.queue_free()
		p.locked_target = null
	await sim_wait(2.0)
	shot("exploration_restored")
	step("boss damage feedback")
	var boss := Boss.make_boss(game, "cinderhide", p.global_position + Vector2(250, -80), p.level)
	boss.zone_idx = game.cur_room
	game.hud._boss_splash_shown[boss.display_name] = true
	game.add_enemy(boss)
	boss.set_physics_process(false)
	game.current_boss = boss
	game.bosses.append(boss)
	p.locked_target = boss
	await sim_wait(2.0)
	boss.hp = boss.max_hp * 0.55
	game.hud.track_target_bar(boss)
	await frames(1)
	shot("boss_damage")
	await sim_wait(1.5)
	shot("boss_settled")
	game.bosses.erase(boss)
	game.current_boss = null
	p.locked_target = null
	boss.queue_free()
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await frames(3)
	shot("comfort")
	game.menus.close()
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await sim_wait(0.3)
	shot("touch_comfort")
