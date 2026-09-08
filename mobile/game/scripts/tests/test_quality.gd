extends RefCounted


static func run(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var saved := {"hp": p.hp, "root": p.rooted_time, "physics": p.is_physics_processing(),
		"terrain": g.terrain_event_t, "paused": t.get_tree().paused,
		"settings": g.settings.duplicate(true), "lock": p.locked_target}
	var enemies := {}
	for e in t.get_tree().get_nodes_in_group("enemies"):
		enemies[e] = e.is_physics_processing()
		e.set_physics_process(false)
	g.menus.close()
	p.set_physics_process(false)
	g.terrain_event_t = 10000.0
	p.rooted_time = 0.0
	var error := await _ground_contracts(t)
	if error == "":
		error = _foliage_contracts(g)
	g.cancel_ground_attacks()
	t.get_tree().paused = saved["paused"]
	p.hp = saved["hp"]
	p.rooted_time = saved["root"]
	p.set_physics_process(saved["physics"])
	g.terrain_event_t = saved["terrain"]
	g.settings = saved["settings"]
	p.locked_target = saved["lock"] if is_instance_valid(saved["lock"]) else null
	for e in enemies:
		if is_instance_valid(e):
			e.set_physics_process(enemies[e])
	if error == "":
		print("ok: ground warnings pause/resume/cancel, guest effects cannot hurt, targeted foliage restores")
	return error


static func _ground_contracts(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	for safe in [false, true]:
		if safe:
			g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.22, 0)
		else:
			g.telegraph(p.global_position, 80, 0.22, 0)
		var attack: Node2D = g._ground_attacks.back()
		var clock: Node2D = attack.get_node("GroundTellClock")
		await t.get_tree().create_timer(0.06).timeout
		t.get_tree().paused = true
		var progress: float = clock.progress
		var rim := g.hud.danger_rect.modulate.a if safe else 0.0
		await t.get_tree().create_timer(0.32, true).timeout
		if not is_instance_valid(clock) or not is_equal_approx(clock.progress, progress):
			return "ground warning advanced while the solo world was paused"
		if safe and not is_equal_approx(g.hud.danger_rect.modulate.a, rim):
			return "shelter's screen warning advanced while its ground fuse was paused"
		t.get_tree().paused = false
		await t.get_tree().create_timer(0.26).timeout
		if is_instance_valid(clock):
			return "ground warning failed to resolve after unpausing"
		g.cancel_ground_attacks()
		await t.get_tree().process_frame
	# Cancel both attacks before their callbacks, including a falling sprite and
	# safe shelter. The stale callbacks must not apply their root to the hero.
	g.telegraph(p.global_position, 90, 0.15, 0, {"root": 2.0, "fireball": true})
	g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.15, 0, {"root": 2.0})
	g.cancel_ground_attacks()
	await t.get_tree().create_timer(0.25).timeout
	if p.rooted_time > 0.0 or not g._ground_attacks.is_empty():
		return "cancelled ground attack retained its visual or applied a status"
	if g.hud.danger_rect.modulate.a > 0.001:
		return "cancelled shelter left a danger wash behind"
	# Mirrors must still show the marker but cannot apply local damage/statuses.
	var hp := p.hp
	g.telegraph(p.global_position, 90, 0.1, 9999, {"net_visual": true, "root": 2.0})
	await t.get_tree().create_timer(0.18).timeout
	g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.1, 9999, {"net_visual": true, "root": 2.0})
	await t.get_tree().create_timer(0.18).timeout
	if p.hp < hp or p.rooted_time > 0.0:
		return "visual-only guest ground attack applied local damage or control"
	return ""


static func _foliage_contracts(g: Game) -> String:
	var p: Player = g.local_player
	var e := Enemy.make(g, "wolf", p.global_position + Vector2(100, 0), -1, 1.0)
	g.world.add_child(e)
	e.set_physics_process(false)
	var saved_target = g.hud.target_bar_unit
	g.hud.target_bar_unit = e
	# Opaque test canopy: transforms/probes are real, independent of art luck.
	var pixels := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var leaf := Sprite2D.new()
	leaf.texture = ImageTexture.create_from_image(pixels)
	leaf.scale = Vector2(60, 60)
	leaf.position = e.global_position + Vector2(0, -30)
	leaf.set_meta("occlusion_sort_y", e.global_position.y + 120)
	leaf.set_meta("occlusion_radius", 180.0)
	leaf.add_to_group("combat_foliage")
	g.world.add_child(leaf)
	var clarity: Node = g.hud.combat_foliage
	g.settings["combat_foliage"] = true
	clarity._sample()
	clarity._process(0.3)
	var error := ""
	if leaf.self_modulate.a > Balance.COMBAT_FOLIAGE_ALPHA + 0.01:
		error = "foreground foliage still hides the target"
	g.settings["combat_foliage"] = false
	clarity._sample()
	clarity._process(0.3)
	if leaf.self_modulate.a < 0.99:
		error = "disabling combat foliage failed to restore its original alpha"
	g.settings["combat_foliage"] = true
	leaf.remove_from_group("combat_foliage")
	clarity._sample()
	clarity._process(0.3)
	if leaf.self_modulate.a < 0.99:
		error = "a non-foliage structure was made transparent"
	g.hud.target_bar_unit = saved_target if is_instance_valid(saved_target) else null
	leaf.queue_free()
	e.queue_free()
	return error
