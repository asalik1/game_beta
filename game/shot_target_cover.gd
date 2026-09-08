extends ShotRig
## Actual authored cover, animated source tracking, target loss and touch UI.


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	var p := game.player
	p.set_physics_process(false)
	game.talked_to_elder = true
	game.set_flag("met_elder")
	p.global_position = game.room_center(2) + Vector2(0, 210)
	game._enter_room(2)
	await skip_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	await sim_wait(4.5)
	game.camera.global_position = p.global_position
	var enemy := spawn_enemy("beastkin_raider", p.global_position + Vector2(145, -80))
	enemy.set_physics_process(false)
	p.locked_target = enemy
	apply_terrain("darkwood", 2)
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	game.settings["combat_foliage"] = false
	await sim_wait(1.2)
	shot("01_visibility_off")
	game.settings["combat_foliage"] = true
	await sim_wait(0.5)
	var clarity: Node = game.hud.combat_foliage
	if not _check_target(clarity, enemy):
		return
	shot("02_target_behind_log")
	# Hold physics still while the production animation seam changes the clip,
	# anchor and frame count, keeping the same log over every rendered pose.
	enemy.play_action("attack")
	if enemy._strip_action.is_empty():
		push_error("target cover: raider action art did not load")
		finish(1)
		return
	for i in 3:
		enemy._advance_action_anim(1.0 / enemy.anim_fps)
		await frames(3)
		if not _check_target(clarity, enemy):
			return
		shot("03_action_pose_%d" % i)
	enemy.untargetable = true
	p.locked_target = null
	await sim_wait(0.25)
	if not clarity._outlines.is_empty():
		push_error("target cover: lost target retained a frozen silhouette")
		finish(1)
		return
	shot("04_lost_target_clears")
	enemy.untargetable = false
	p.locked_target = enemy
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await sim_wait(0.4)
	if not _check_target(clarity, enemy):
		return
	shot("05_touch_target_behind_log")
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await frames(3)
	shot("06_touch_visibility_setting")
	game.menus.close()
	enemy.queue_free()
	await frames(4)
	if not clarity._outlines.is_empty():
		push_error("target cover: freed target retained a silhouette")
		finish(1)
		return
	print("ok: target visibility live: opaque authored log, covering-foliage fade, three actual action poses, target loss/deletion and touch presentation")
	finish()


func _check_target(clarity: Node, enemy: Enemy) -> bool:
	var log_found := false
	# Seeded scenery can put the neighboring canopy beside the target. Only
	# actually covering trees should fade; a non-covering tree stays opaque.
	var foliage_ok := true
	for entry in clarity._faded.values():
		if entry.covered and is_instance_valid(entry.visual) and entry.visual.self_modulate.a > 0.3:
			foliage_ok = false
	for outline in clarity._outlines.values():
		if not is_instance_valid(outline):
			continue
		var visual: Node2D = outline.get_parent()
		if visual.get_parent().get_meta("prop", "") == "log":
			log_found = is_equal_approx(visual.self_modulate.a, 1.0) \
				and visual.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW
		if outline.texture != enemy.sprite.texture or outline.frame != enemy.sprite.frame \
			or not outline.global_transform.is_equal_approx(enemy.sprite.global_transform):
			push_error("target cover: outline does not match live animation")
			finish(1)
			return false
	if not log_found or not foliage_ok or game.hud.target_bar_unit != enemy:
		print("TARGET FIXTURE: log=", log_found, " foliage=", foliage_ok,
			" target=", game.hud.target_bar_unit == enemy, " outlines=", clarity._outlines.size(),
			" faded=", clarity._faded.size(), " enemy=", enemy.global_position)
		for entry in clarity._faded.values():
			print("TARGET FOLIAGE: ", entry)
		shot("fixture_failure")
		push_error("target cover: authored log/tree/target fixture diverged")
		finish(1)
		return false
	return true
