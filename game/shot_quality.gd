extends ShotRig
## Visual clarity and the lifetime/pause contracts behind dangerous ground.


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.player.char_name = "The Uncrowned"
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	await sim_wait(3.0)
	var error: String = await preload("res://scripts/tests/test_quality.gd").run(self)
	if error != "":
		push_error(error)
		finish(1)
		return
	step("ground attack pause contract")
	var p: Player = game.player
	p.hurt_cd = 0.0
	p.shield = 0.0
	p.hp = p.max_hp
	game.telegraph(p.global_position, 90.0, 0.35, 12.0)
	await sim_wait(0.08)
	var before := p.hp
	get_tree().paused = true
	await get_tree().create_timer(0.65, true).timeout
	get_tree().paused = false
	if p.hp < before:
		push_error("ground attack resolved while the solo world was paused")
		finish(1)
		return
	await sim_wait(0.5)
	if p.hp >= before:
		push_error("ground attack failed to resume after unpausing")
		finish(1)
		return
	error = await _visuals()
	if error != "":
		push_error(error)
		finish(1)
		return
	finish()


func _visuals() -> String:
	var p: Player = game.player
	game.talked_to_elder = true
	game.set_flag("met_elder")
	game.quest_key = "fangmaw"
	p.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	await sim_wait(3.5)
	game.camera.global_position = p.global_position
	for terrain in ["keep", "ice", "magma", "darkwood"]:
		step("ground timing on " + terrain)
		apply_terrain(terrain, 2)
		game.terrain_event_t = 10000.0
		game.hazard_tick = 10000.0
		await sim_wait(0.6)
		if terrain == "keep":
			var field: Polygon2D = game.zone_fields[2]
			field.texture = load("res://assets/sprites/ground_field_stone.png")
			field.self_modulate = Color.WHITE
			field.uv = field.polygon
			field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			await frames(2)
			shot("keep_floor_before")
			game._apply_ground_field(2, Terrains.get_terrain("keep"))
			await frames(2)
			shot("keep_floor_after")
		game.telegraph(p.global_position + Vector2(-170, -20), 88, 1.8, 0,
			{"net_visual": true, "color": Color(1.0, 0.28, 0.14, 0.6), "shape": "cone", "dir": Vector2.DOWN})
		game.telegraph_safe([p.global_position + Vector2(160, -20)], 88, 1.8, 0,
			{"net_visual": true, "decoys": [p.global_position + Vector2(340, 105)]})
		await sim_wait(0.3)
		shot(terrain + "_early")
		await sim_wait(1.0)
		shot(terrain + "_late")
		await sim_wait(1.1)
		game.cancel_ground_attacks()
	step("foliage comparison")
	var center := p.global_position
	var tree := game._add_obstacle("tree_autumn", center + Vector2(160, 50), 1.0)
	var e := spawn_enemy("beastkin_raider", center + Vector2(160, -20))
	e.set_physics_process(false)
	e.alerted = true
	p.locked_target = e
	game.settings["combat_foliage"] = false
	await sim_wait(0.6)
	shot("foliage_before")
	game.settings["combat_foliage"] = true
	await sim_wait(0.6)
	shot("foliage_after")
	var faded := false
	for child in tree.get_children():
		if child.is_in_group("combat_foliage") and child.self_modulate.a < 0.5:
			faded = true
	if not faded:
		return "real target foliage did not fade"
	p.locked_target = null
	e.queue_free()
	tree.queue_free()
	await frames(2)
	step("notification composition")
	game.hud.announce("LORE UNEARTHED — A vow beneath the ash", Color(0.8, 0.9, 1.0), 2.2, "lore")
	game.hud.announce("QUEST COMPLETE — The road to the keep", Color(0.9, 0.8, 0.5), 2.2, "quest")
	game.hud.announce("NEW PATH UNLOCKED — Return to the field atlas", Color(0.6, 0.95, 0.75), 2.2, "victory")
	await sim_wait(0.8)
	shot("notification_queue")
	if game.hud._ann_stack != 1 or game.hud._ann_queue.size() != 2:
		return "announcements did not serialize to one plaque"
	var active: Panel = game.hud._ann_active
	game.menus.open_pause()
	await sim_wait(0.2)
	if active.visible:
		return "notification obscured a menu"
	await sim_wait(3.8)
	game.menus.close()
	await sim_wait(0.2)
	if game.hud._ann_active != active or not active.visible:
		return "notification reading time elapsed behind the menu"
	shot("notification_resumed")
	game.hud.flash_title("THE ROAD REMEMBERS", "An arrival title and a pending discovery", 0.6, false)
	await sim_wait(0.3)
	shot("arrival_without_overlap")
	if active.visible:
		return "announcement overlapped an arrival title"
	await sim_wait(1.5)
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await sim_wait(0.3)
	shot("touch_comfort")
	game.menus.close()
	# A real rebuild, not just calling the cancellation helper.
	step("chapter rebuild cancels pending attacks")
	game.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.8, 0, {"root": 2.0})
	game.telegraph(p.global_position, 90, 0.8, 0, {"root": 2.0, "fireball": true})
	game.switch_chapter("ch1", true)
	await skip_dialogue()
	await sim_wait(1.0)
	if p.rooted_time > 0.0 or not game._ground_attacks.is_empty():
		return "old encounter attack survived chapter rebuild"
	return ""
