extends RefCounted
## Optional nested probe at north_edge_live's settled north waypoint.
## No camera writes: lead is the real comfort preference; physics stays live.
const Clearance := preload("res://scripts/ui/hud_clearance.gd")
var q: RefCounted
var g: Game
var p: Player
var baseline := false
var rows: Array[Dictionary] = []
var views: Array[Dictionary] = []
var motions: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var wolf: Enemy


static func run(probe: RefCounted) -> Dictionary:
	var test := new()
	test.q = probe
	test.g = probe.g
	test.p = probe.p
	test.baseline = probe.r.flag("camera-baseline")
	return await test._run()


func _check(id: String, ok: bool, detail: Variant, anticipated := false) -> void:
	var status := "pass" if ok else "baseline_finding" if baseline and anticipated else "fail"
	rows.append({"id": id, "status": status, "detail": detail})
	print("CAMERA LEAD ", id, ": ", status)


func _run() -> Dictionary:
	var old_dir: String = q.r.shot_dir
	var old_lead: float = float(g.settings.get("camera_lead", 1.0))
	q.r.shot_dir = old_dir.path_join("camera_lead")
	_check("isolated_mode", not q.baseline and not q.r.flag("extra"),
		"Use --camera-baseline only, never the older --baseline or --extra flags")
	_check("default_lead", is_equal_approx(old_lead, 1.0), old_lead)
	_check("fresh", g.no_saves and not g.net_online() and not g.dev_god and not p.dead
		and p.locked_target == null and p.aim_focus() == null and not g.input_overlay_up(),
		"fresh quiet road, no target, no combat or stat grants")
	_check("tab_binding", int(g.binds.get("target", KEY_TAB)) == KEY_TAB, g.binds.get("target"))
	_check("ordinary_framing", bool(g.settings.get("combat_framing", true))
		and g.shake_amt < 0.01 and g._shake_kick.length() < 0.01,
		"real combat framing enabled; no shake impulse to confound north clipping")
	await _exercise()
	q._release()
	if is_instance_valid(wolf): wolf.queue_free()
	g.settings["camera_lead"] = old_lead
	await q.r.frames(3)
	_check("input_released", not Input.is_key_pressed(KEY_TAB) and not Input.is_key_pressed(KEY_SPACE)
		and not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_key_pressed(KEY_W)
		and not Input.is_key_pressed(KEY_S), "all synthetic presses released")
	var findings: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": findings.append(String(row.id))
	var expected: Array[String] = []
	if baseline: expected.append("lead_one.hero_in_view")
	_check("baseline_exact", findings == expected, {"actual": findings, "expected": expected})
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var report := {"baseline": baseline, "rows": rows, "views": views, "motions": motions,
		"inputs": inputs, "failures": failures, "findings": findings.size(), "complete": failures == 0,
		"scope": "Controlled existing-room native-render probe. Parent clears enemies and delays hazards but retains static walls/props; initial corridor placement and room re-entry are direct. Travel uses held W/S and target selection uses parsed Tab/Space input, not direct lock assignment. One real factory wolf has frozen AI and no injected damage; no earned encounter or physical-device claim. Camera, local hero physics, smoothing, limits, zoom and HUD run normally. Lead 1 versus 0 is a real comfort setting and can change both offset AND zoom. Body rect is production class-height proxy, not painted-alpha evidence; inspect original PNGs. Motion samples are frame-sampled, not every physics instant. Only the settled lead-one viewport failure is an anticipated baseline finding."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(q.r.shot_dir)))
	var file := FileAccess.open(String(q.r.shot_dir).path_join("acceptance.json"), FileAccess.WRITE)
	if file == null:
		report.complete = false
		report["write_error"] = "Cannot write camera-lead receipt"
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	q.r.shot_dir = old_dir
	return report


func _exercise() -> void:
	var north := p.global_position
	var hp := p.hp
	var world_id := g.world.get_instance_id()
	await _observe("no_target")
	var desired := north + Vector2(0, 170)
	var actual := g.free_spawn_pos(desired, north)
	wolf = Enemy.make(g, "wolf", actual, 1)
	wolf.zone_idx = int(q.room)
	g.world.add_child(wolf)
	wolf.set_physics_process(false)
	await q.r.frames(3)
	_check("wolf_south", absf(actual.x - north.x) <= 20.0 and absf(actual.y - desired.y) <= 20.0
		and not wolf.dying and not wolf.untargetable and not wolf.is_physics_processing(),
		{"wanted": _v(desired), "actual": _v(actual), "hero": _v(north)})
	_check("pre_tab_unlocked", p.locked_target == null, "soft acquisition is allowed before explicit Tab")
	await _tap(KEY_TAB)
	_check("tab_locked", p.locked_target == wolf and p.aim_focus() == wolf,
		"normal HUD event -> player lock intent -> production cycle_target")
	await q.r.sim_wait(2.0)
	var one := await _observe("lead_one", true)
	_check("lead_one.target", _target_live(), _frame())
	_check("lead_one.focus_samples", _all_target(one), "same frozen wolf in every settled frame")
	if baseline:
		var sustained := true
		for sample in one.samples: sustained = sustained and float(sample.body[1]) < -1.0
		_check("baseline.sustained_top_clip", sustained and one.samples.size() >= 3,
			"Every settled sample must show at least 1px top clipping; a one-frame transient does not prove this hypothesis")
	g.settings["camera_lead"] = 0.0
	await q.r.sim_wait(2.0)
	var zero := await _observe("lead_zero")
	_check("lead_zero.target", _target_live() and g._cam_look.length() < 0.75, _frame())
	_check("lead_zero.focus_samples", _all_target(zero), "same frozen wolf in every settled frame")
	_check("same_actor_positions", p.global_position.distance_to(north) < 0.5
		and wolf.global_position.distance_to(actual) < 0.5 and p.hp == hp,
		{"hero": _v(p.global_position), "wolf": _v(wolf.global_position), "hp": p.hp})
	await _tap(KEY_SPACE)
	_check("space_unlocked", p.locked_target == null, "Space drops hard lock; ordinary soft focus may remain")
	wolf.queue_free() # Fixture retirement, NOT a kill or combat reward.
	await q.r.frames(3)
	g.settings["camera_lead"] = 1.0
	await q.r.sim_wait(2.0)
	_check("target_removed", p.aim_focus() == null and not g.reticle.visible
		and g.hud.target_bar_unit == null, _frame())
	await _observe("target_removed")
	await _walk("camera_inward", north.y + 150.0)
	await q.r.sim_wait(1.5)
	await _observe("inward")
	await _walk("camera_outward", north.y)
	await q.r.sim_wait(1.5)
	await _observe("north_return")
	await _tap(KEY_ESCAPE)
	_check("menu_open", g.menus.is_open() and q.r.get_tree().paused, g.menus.current)
	await _tap(KEY_ESCAPE)
	_check("menu_closed", not g.input_overlay_up() and not q.r.get_tree().paused, g.menus.current)
	# Always restore a failed native menu close before continuing the probe.
	if g.menus.is_open(): g.menus.close()
	await q.r.sim_wait(1.5)
	await _observe("menu_return")
	var away := 0 if int(q.room) != 0 else 1
	p.global_position = g.room_center(away)
	g._enter_room(away)
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	await q.r.skip_dialogue()
	await q.r.sim_wait(0.5)
	_check("away_room", g.cur_room == away, g.cur_room)
	p.global_position = north
	g._enter_room(int(q.room))
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	await q.r.skip_dialogue()
	await q.r.sim_wait(2.0)
	_check("room_restored", g.cur_room == int(q.room) and g.world.get_instance_id() == world_id
		and p.global_position.distance_to(north) < 0.5 and p.hp == hp, _frame())
	await _observe("room_return")
	if q.r.flag("camera-edges"):
		_check("edges.strict_only", not baseline, "directional cases require strict camera mode")
		if not baseline:
			await preload("res://scripts/tests/camera_edge_extra.gd").run(self)


func _target_live() -> bool:
	return is_instance_valid(wolf) and p.locked_target == wolf and p.aim_focus() == wolf \
		and g.hud.target_bar_unit == wolf and g.reticle.visible \
		and g.reticle.global_position.distance_to(wolf.global_position) < 0.1


func _all_target(view: Dictionary) -> bool:
	if not is_instance_valid(wolf): return false
	for sample in view.samples:
		if int(sample.target_id) != wolf.get_instance_id(): return false
	return not view.samples.is_empty()


func _observe(id: String, anticipated := false) -> Dictionary:
	await q.r.frames(2)
	var samples: Array[Dictionary] = []
	var contained := true
	var live := true
	var deadline := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var frame := _frame()
		samples.append(frame)
		contained = contained and bool(frame.body_in_view)
		live = live and bool(frame.live)
		await q.r.get_tree().process_frame
	var evidence := {"id": id, "samples": samples}
	views.append(evidence)
	_check(id + ".live_samples", samples.size() >= 3 and live, {"samples": samples.size(), "all_live": live})
	_check(id + ".hero_in_view", contained, evidence, anticipated)
	var bounds: Rect2 = q.bounds
	_check(id + ".limits", g.camera.limit_left == int(bounds.position.x)
		and g.camera.limit_top == int(bounds.position.y) and g.camera.limit_right == int(bounds.end.x)
		and g.camera.limit_bottom == int(bounds.end.y) and g.camera.position_smoothing_enabled,
		_frame())
	q.r.shot("camera_" + id, "live camera/body proxy; frozen wolf; inspect original pixels; not an earned encounter")
	return evidence


func _walk(id: String, target_y: float) -> void:
	var samples: Array[Dictionary] = []
	var sampler := func() -> void: samples.append(_frame())
	q.r.get_tree().process_frame.connect(sampler)
	await q._walk(id, target_y)
	q.r.get_tree().process_frame.disconnect(sampler)
	motions.append({"id": id, "samples": samples})
	# Trace transitions without asserting a new movement-easing design.
	_check(id + ".sampled", samples.size() >= 3, samples.size())


func _tap(key: int) -> void:
	var before := Engine.get_physics_frames()
	q._press(key, true)
	# Wall-clock process-always timer works while the native pause menu is up.
	await q.r.get_tree().create_timer(0.12, true).timeout
	q._release()
	await q.r.frames(3)
	inputs.append({"key": key, "physics_before": before, "physics_after": Engine.get_physics_frames(),
		"released": not Input.is_key_pressed(key), "paused_after": q.r.get_tree().paused})


func _frame() -> Dictionary:
	var body := Clearance.body_rect(p)
	var viewport := g.get_viewport_rect()
	var canvas := p.get_canvas_transform()
	return {"physics_frame": Engine.get_physics_frames(), "ticks_msec": Time.get_ticks_msec(),
		"hero": _v(p.global_position), "body": _rect(body), "body_in_view": body.has_area() and viewport.encloses(body),
		"viewport": _rect(viewport), "rendered_world_view": _rect(canvas.affine_inverse() * viewport),
		"canvas_transform": [canvas.x.x, canvas.x.y, canvas.y.x, canvas.y.y, canvas.origin.x, canvas.origin.y],
		"camera_node_world": _v(g.camera.global_position), "camera_screen_center": _v(g.camera.get_screen_center_position()),
		"camera_offset": _v(g.camera.offset), "camera_zoom": _v(g.camera.zoom), "ordinary_look": _v(g._cam_look),
		"lead": g.settings.get("camera_lead", 1.0), "hp": p.hp, "room": g.cur_room,
		"live": p.is_physics_processing() and g.is_processing() and not q.r.get_tree().paused
			and not g.input_overlay_up() and not p.dead,
		"target_id": p.aim_focus().get_instance_id() if is_instance_valid(p.aim_focus()) else 0}


func _v(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
