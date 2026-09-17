extends RefCounted
## Strict directional extension; shares camera_lead_live's receipt and helpers.
const Clearance := preload("res://scripts/ui/hud_clearance.gd")
var c: RefCounted
var q: RefCounted
var g: Game
var p: Player


static func run(camera_probe: RefCounted) -> void:
	var helper := new()
	helper.c = camera_probe
	helper.q = camera_probe.q
	helper.g = camera_probe.g
	helper.p = camera_probe.p
	await helper._exercise()


func _exercise() -> void:
	var north := p.global_position
	var hp := p.hp
	var bounds: Rect2 = q.bounds
	var south_y := bounds.end.y - 100.0
	var transform := p.global_transform
	var south_clear := not p.test_move(transform, Vector2(0, south_y - north.y))
	c._check("edges.south_corridor", south_clear,
		{"start": c._v(north), "south_y": south_y, "collision_mask": p.collision_mask})
	if not south_clear: return # Rejected fixture, not an excuse to teleport past props.
	c._check("edges.default_lead", is_equal_approx(float(g.settings.get("camera_lead", 1.0)), 1.0),
		"strict directional extension never writes camera position, offset, zoom or preference")
	await c._walk("edges_south_route", south_y)
	await q.r.sim_wait(2.0)
	await _target_case("south", Vector2(0, -170))
	# Choose a horizontal static-prop-clear route reachable from this vertical
	# corridor. No placement shortcut: both legs are subsequently held input.
	var lane := Vector2.INF
	var horizontal_side := ""
	for dy in [0.0, -150.0, 150.0, -300.0, 300.0]:
		var corner := Vector2(p.global_position.x, bounds.get_center().y + dy)
		transform = p.global_transform
		if p.test_move(transform, corner - p.global_position): continue
		transform.origin = corner
		for side in ["east", "west"]:
			var edge_x: float = bounds.end.x - 100.0 if side == "east" else bounds.position.x + 100.0
			if not p.test_move(transform, Vector2(edge_x - corner.x, 0)):
				lane = Vector2(edge_x, corner.y)
				horizontal_side = side
				break
		if lane.is_finite(): break
	c._check("edges.horizontal_corridor", lane.is_finite(),
		{"lane": c._v(lane) if lane.is_finite() else [], "side": horizontal_side,
		"scope": "Choose east first, west fallback; all static collision remains enabled"})
	if lane.is_finite():
		await c._walk("edges_horizontal_approach", lane.y)
		await _walk_x("edges_horizontal_outward", lane.x)
		await q.r.sim_wait(2.0)
		await _target_case("horizontal", Vector2(-170, 0) if horizontal_side == "east" else Vector2(170, 0))
		await _walk_x("edges_horizontal_return", north.x)
	# Even a missing horizontal corridor preserves the north return and state.
	await c._walk("edges_north_restore", north.y)
	await q.r.sim_wait(2.0)
	await c._observe("edges_north_restored")
	c._check("edges.restored", p.global_position.distance_to(north) <= 28.0
		and p.hp == hp and g.cur_room == int(q.room) and p.aim_focus() == null
		and not g.reticle.visible and is_equal_approx(float(g.settings.get("camera_lead", 1.0)), 1.0)
		and not Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_D), c._frame())


func _target_case(id: String, inward: Vector2) -> void:
	var start := p.global_position
	var desired := start + inward
	var actual := g.free_spawn_pos(desired, start)
	c.wolf = Enemy.make(g, "wolf", actual, 1)
	c.wolf.zone_idx = int(q.room)
	g.world.add_child(c.wolf)
	c.wolf.set_physics_process(false)
	await q.r.frames(3)
	c._check("edges." + id + ".fixture", actual.distance_to(desired) <= 20.0
		and not c.wolf.is_physics_processing() and not c.wolf.dying and not c.wolf.untargetable
		and p.locked_target == null,
		{"hero": c._v(start), "desired": c._v(desired), "actual": c._v(actual), "inward": c._v(inward)})
	await c._tap(KEY_TAB)
	c._check("edges." + id + ".tab_lock", p.locked_target == c.wolf and p.aim_focus() == c.wolf,
		"actual parsed Tab and live player intent consumption; no direct target assignment")
	await q.r.sim_wait(2.0)
	var sampled: Array[Dictionary] = []
	var sampler := func() -> void:
		var target_body := Clearance.body_rect(c.wolf)
		sampled.append({"camera": c._frame(), "target_body": c._rect(target_body),
			"target_world": c._v(c.wolf.global_position), "target_live": c._target_live(),
			"target_in_view": target_body.has_area() and g.get_viewport_rect().encloses(target_body)})
	RenderingServer.frame_post_draw.connect(sampler)
	await c._observe("edges_" + id + "_locked")
	RenderingServer.frame_post_draw.disconnect(sampler)
	var visible := true
	var identity := true
	var finite := true
	for sample in sampled:
		visible = visible and bool(sample.target_in_view) and bool(sample.camera.body_in_view)
		identity = identity and bool(sample.target_live)
		for key in ["hero", "body", "canvas_transform", "camera_node_world", "camera_screen_center", "camera_offset", "camera_zoom", "ordinary_look"]:
			for value in sample.camera[key]: finite = finite and is_finite(float(value))
		for value in sample.target_body: finite = finite and is_finite(float(value))
	c.views[-1]["directional_targets"] = sampled
	c._check("edges." + id + ".both_bodies", sampled.size() >= 3 and visible, {"samples": sampled.size()})
	c._check("edges." + id + ".same_target", identity and p.global_position.distance_to(start) < 0.5
		and c.wolf.global_position.distance_to(actual) < 0.5, "both posed actors remain stationary; real HUD/reticle remain attached")
	c._check("edges." + id + ".camera_finite", finite, {"samples": sampled.size()})
	await c._tap(KEY_SPACE)
	c._check("edges." + id + ".unlock", p.locked_target == null, "Space releases hard lock")
	c.wolf.queue_free()
	await q.r.frames(3)
	await q.r.sim_wait(2.0)
	c._check("edges." + id + ".retired", p.aim_focus() == null and not g.reticle.visible
		and g.hud.target_bar_unit == null, "fixture removal, no damage/kill/reward")
	await c._observe("edges_" + id + "_retired")


func _walk_x(id: String, target_x: float) -> void:
	q.r.step("held horizontal route " + id)
	var start := p.global_position
	var direction := signf(target_x - start.x)
	var key := KEY_D if direction > 0 else KEY_A
	var samples: Array[Dictionary] = []
	var deadline := Time.get_ticks_msec() + 10000
	q._press(key, true)
	while Time.get_ticks_msec() < deadline:
		await q.r.get_tree().process_frame
		samples.append(c._frame())
		if (target_x - p.global_position.x) * direction <= 8.0: break
		if g.cur_room != int(q.room) or p.dead or g.input_overlay_up(): break
	q._release()
	await q.r.frames(2)
	var finish := p.global_position
	var evidence := {"id": id, "start": c._v(start), "finish": c._v(finish), "target_x": target_x,
		"held_key": int(key), "samples": samples}
	c.motions.append(evidence)
	c._check(id + ".input_reached", absf(finish.x - target_x) <= 28.0 and absf(finish.y - start.y) <= 8.0
		and start.distance_to(finish) >= 100.0 and g.cur_room == int(q.room) and samples.size() >= 3, evidence)
	var live := true
	for frame in samples: live = live and bool(frame.live)
	c._check(id + ".live_samples", live and p.is_physics_processing() and g.is_processing()
		and not q.r.get_tree().paused and not g.input_overlay_up() and not p.dead,
		{"samples": samples.size(), "all_live": live})
