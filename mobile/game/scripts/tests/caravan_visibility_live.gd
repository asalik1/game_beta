extends RefCounted
## Real caravan art: covered hero/target, front sorting and owner cleanup.

static func run(r: Node, cart: Node2D) -> String:
	var g: Game = r.game
	var p: Player = g.player
	cart.set_physics_process(false)
	for attacker in cart.enemies:
		attacker.set_physics_process(false)
		attacker.global_position = cart.global_position + Vector2(400, 300)
	var body: Sprite2D
	for child in cart.get_children():
		if child is Sprite2D:
			body = child
			break
	if body == null:
		return "production caravan has no rendered cart body"
	p.global_position = cart.global_position + Vector2(-12, -35)
	g.camera.global_position = cart.global_position + Vector2(0, -30)
	await r.frames(5)
	await r._capture("visibility_01_hero_behind_cart")
	var covered := false
	for probe in Balance.PLAYER_OCCLUSION_PROBES:
		covered = covered or p._visual_alpha_at(body, p.global_position + probe) >= Balance.PLAYER_OCCLUSION_ALPHA_THRESHOLD
	if not covered:
		return "cart visibility fixture did not actually cover the hero"
	var key := body.get_instance_id()
	if not body.is_in_group("structure_occluders") or not p._occlusion_clips.has(key):
		return "the real cart hides its hero without a clipped silhouette"
	if body.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW or not is_equal_approx(body.self_modulate.a, 1.0):
		return "cart hero visibility faded or replaced the opaque cart"
	p.global_position = cart.global_position + Vector2(0, 45)
	await r.frames(5)
	if p._occlusion_clips.has(key):
		return "the cart outlines a hero who stands in front of it"
	await r._capture("visibility_02_hero_in_front")
	var enemy := Enemy.make(g, "beastkin_raider", cart.global_position + Vector2(-12, -35), cart.zone, 1.0)
	g.world.add_child(enemy)
	enemy.set_physics_process(false)
	p.global_position = cart.global_position + Vector2(105, 35)
	p.locked_target = enemy
	g.settings["combat_foliage"] = true
	await r.sim_wait(0.4)
	var clarity: Node = g.hud.combat_foliage
	if g.hud.target_bar_unit != enemy or not clarity._outlines.has(key):
		return "the selected enemy disappears behind the cart"
	await r._capture("visibility_03_target_behind_cart")
	enemy.play_action("attack")
	for pose in 3:
		enemy._advance_action_anim(1.0 / enemy.anim_fps)
		await r.frames(3)
		var outline = clarity._outlines.get(key)
		if not is_instance_valid(outline) or outline.texture != enemy.sprite.texture or outline.frame != enemy.sprite.frame:
			return "cart target silhouette did not follow its real attack pose"
		await r._capture("visibility_04_attack_%d" % pose)
	# Shared mask owners: disabling target visibility must retain the hero.
	p.global_position = cart.global_position + Vector2(20, -35)
	g.settings["combat_foliage"] = false
	await r.sim_wait(0.3)
	if clarity._outlines.has(key) or not p._occlusion_clips.has(key) or body.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW:
		return "disabled target visibility removed the hero's cart mask"
	await r._capture("visibility_05_hero_keeps_shared_mask")
	g.settings["combat_foliage"] = true
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	await r.sim_wait(0.3)
	if not clarity._outlines.has(key) or not p._occlusion_clips.has(key):
		return "touch view lost the hero or target behind the cart"
	await r._capture("visibility_06_touch_shared_cart")
	enemy.queue_free()
	p.locked_target = null
	await r.frames(5)
	if clarity._outlines.has(key) or not p._occlusion_clips.has(key):
		return "removing the target stranded its outline or removed the hero"
	cart.cancel()
	await r.frames(5)
	if p._occlusion_clips.has(key) or clarity._outlines.has(key):
		return "retiring the cart left stale silhouette references"
	await r._capture("visibility_07_cart_cleanup")
	print("ok: real cart hero/target silhouettes, opaque front sorting, three animated attack poses, shared masks, touch and retirement cleanup")
	return ""
