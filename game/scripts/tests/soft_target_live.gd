extends RefCounted
## Controlled retreat fixture: ordinary player physics and real key events.
const Clearance := preload("res://scripts/ui/hud_clearance.gd")
var r: ShotRig
var g: Game
var p: Player
var baseline := false
var room := -1
var origin := Vector2.INF
var actors: Array[Enemy] = []
var rows: Array[Dictionary] = []
var views: Array[Dictionary] = []
var motions: Array[Dictionary] = []


static func run(rig: ShotRig) -> String:
	var t := new()
	t.r = rig; t.g = rig.game; t.p = rig.game.local_player
	t.baseline = rig.flag("baseline")
	return await t._run()


func _check(id: String, good: bool, detail: Variant, anticipated := false) -> void:
	rows.append({"id": id, "status": "pass" if good else "baseline_finding" if baseline and anticipated else "fail", "detail": detail})
	print("SOFT TARGET ", id, ": ", rows.back().status)


func _run() -> String:
	var old_dir := r.shot_dir
	r.shot_dir = old_dir.path_join("soft_target")
	var hp := p.hp; var xp := p.xp; var gold := p.gold
	var fresh: bool = g.no_saves and not g.net_online() and not g.dev_god and not p.dead
	_check("fresh", fresh, "Disposable no-save solo profile; no stats, damage or target grants")
	if fresh:
		if await _prepare():
			await _case("right", 1.0)
			await _retire()
			await _case("left", -1.0)
	await _retire()
	_check("no_rewards_or_wounds", p.hp == hp and p.xp == xp and p.gold == gold, {"hp": p.hp, "xp": p.xp, "gold": p.gold})
	_check("keys_released", not Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_D), "Both movement keys released")
	var findings: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": findings.append(String(row.id))
	var expected: Array[String] = []
	if baseline: expected.assign(["right.retreat_kept", "left.retreat_kept"])
	_check("baseline_exact", findings == expected, {"expected": expected, "actual": findings})
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var receipt := {"rows": rows, "views": views, "motions": motions, "baseline": baseline,
		"findings": findings, "failures": failures, "complete": failures == 0,
		"scope": "Disposable authored Village Outskirts; original enemies retired without kills, room marked cleared and hazards delayed. Static props/walls/collision stay intact. Initial and mirrored hero/actor poses are controlled; actors use real factory art with frozen AI. Actual A/D input and normal local physics acquire and switch targets; no target fields, ability calls, damage, XP, resources or cooldowns assigned. Motion samples are physics-boundary observations before the next step, not contact-time probes. Screenshots remain native rendered frames. No earned encounter, natural enemy AI, device or visual-acceptance claim. No-save world setup is disposable; wrapper exits after receipt. Native PNGs require manual review."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "Cannot write soft-target receipt"
	file.store_string(JSON.stringify(receipt, "\t") + "\n"); file.close()
	r.shot_dir = old_dir
	return "" if failures == 0 else "Soft-target fixture failed: %d" % failures


func _prepare() -> bool:
	r.step("controlled quiet road, original collision and local input")
	g.play_started = true; g.state = Game.ST_PLAYING; g.hud.visible = true
	g.menus.close(); g.request_pause(false)
	for i in g.zones.size():
		if String(g.zones[i].name) == "Village Outskirts": room = i
	_check("room_found", room >= 0, room)
	if room < 0: return false
	p.global_position = g.room_center(room); g._enter_room(room)
	for e in r.get_tree().get_nodes_in_group("enemies"):
		if g.world.is_ancestor_of(e):
			e.set_physics_process(false)
			e.queue_free()
	await r.skip_dialogue()
	g.terrain_event_t = 10000.0; g.hazard_tick = 10000.0
	g.current_boss = null; g.bosses.clear()
	g.zone_alive[room] = 0; g.cleared[room] = true; g.boss_spawned[room] = true
	g.refresh_quest()
	await r.frames(3)
	var center: Vector2 = g.play_rect(room).get_center()
	for dy in [0.0, 100.0, -100.0, 180.0, -180.0]:
		var candidate := center + Vector2(0, dy)
		var transform := p.global_transform; transform.origin = candidate
		var clear := not p.test_move(transform, Vector2(130, 0)) and not p.test_move(transform, Vector2(-130, 0))
		for dx in [-320.0, -140.0, 140.0, 320.0]:
			var desired := candidate + Vector2(dx, 65)
			var actual := g.free_spawn_pos(desired, candidate)
			clear = clear and actual.distance_to(desired) <= 8.0 and not g._pos_in_wall(actual)
		if clear: origin = candidate; break
	_check("corridor_clear", origin.is_finite(), "130px both directions swept with real hero collision; actor poses use free_spawn_pos")
	if not origin.is_finite(): return false
	p.global_position = origin
	await r.sim_wait(4.0) # Arrival title must finish before screenshot evidence.
	_check("live_input", _live() and p.aim_focus() == null and p.locked_target == null, _frame())
	return _live() and p.aim_focus() == null and p.locked_target == null


func _case(id: String, side: float) -> void:
	r.step(id + " retreat with two chasers behind")
	p.global_position = origin
	var committed := _spawn("wolf", origin + Vector2(-side * 320, 65))
	await _walk(id + ".acquire", -side)
	_check(id + ".acquired", p.soft_target == committed and p.aim_focus() == committed and p.locked_target == null, _frame())
	var near := _spawn("beastkin_raider", origin + Vector2(-side * 140, 65))
	await r.sim_wait(0.6)
	_check(id + ".idle_kept", p.soft_target == committed and p.aim_focus() == committed, _frame())
	_check(id + ".opposite_side", p._side_of(committed) == -side and p._side_of(near) == -side
		and not committed.is_physics_processing() and not near.is_physics_processing(), _frame())
	await _capture(id + "_01_committed")
	var samples: Array[Dictionary] = await _walk(id + ".retreat", side)
	var kept := p.soft_target == committed and p.aim_focus() == committed
	var exact_old := p.soft_target == near and p.aim_focus() == near
	for frame in samples:
		kept = kept and int(frame.soft) == committed.get_instance_id() and int(frame.aim) == committed.get_instance_id()
		exact_old = exact_old and int(frame.soft) in [committed.get_instance_id(), near.get_instance_id()]
		exact_old = exact_old and int(frame.aim) in [committed.get_instance_id(), near.get_instance_id()] and int(frame.locked) == 0
	_check(id + ".retreat_kept", kept, {"committed": committed.get_instance_id(), "near": near.get_instance_id(), "end": _frame()}, true)
	if baseline: _check(id + ".exact_old_target", exact_old, "Only nearer opposite-side chaser may replace original; final aim must match it")
	await _capture(id + "_02_retreat")
	var ahead := _spawn("wolf", p.global_position + Vector2(side * 260, 65))
	await _walk(id + ".steer_to_enemy", side)
	_check(id + ".positive_switch", p.soft_target == ahead and p.aim_focus() == ahead and p.locked_target == null, _frame())
	await _capture(id + "_03_positive")


func _spawn(kind: String, desired: Vector2) -> Enemy:
	var actual := g.free_spawn_pos(desired, p.global_position)
	_check("spawn_%d.clear" % actors.size(), actual.distance_to(desired) <= 8.0 and not g._pos_in_wall(actual), {"desired": _v(desired), "actual": _v(actual)})
	var e := Enemy.make(g, kind, actual, 1, 1.0)
	g.world.add_child(e); e.set_physics_process(false); actors.append(e)
	return e


func _walk(id: String, side: float) -> Array[Dictionary]:
	var start := p.global_position
	var key := KEY_D if side > 0 else KEY_A
	var samples: Array[Dictionary] = []
	var deadline := Time.get_ticks_msec() + 3000
	_key(key, true)
	while Time.get_ticks_msec() < deadline:
		await r.get_tree().physics_frame
		samples.append(_frame())
		if not _live() or p.global_position.distance_to(start) >= 42.0: break
	_key(key, false)
	await r.frames(2)
	var travel := p.global_position - start
	_check(id + ".movement", _live() and travel.x * side >= 35.0 and absf(travel.y) <= 5.0 and samples.size() >= 3, {"travel": _v(travel), "samples": samples.size()})
	motions.append({"id": id, "key": int(key), "start": _v(start), "finish": _v(p.global_position), "samples": samples})
	return samples


func _capture(id: String) -> void:
	await r.frames(2); await RenderingServer.frame_post_draw
	var body := Clearance.body_rect(p)
	var visible := body.has_area() and g.get_viewport_rect().encloses(body)
	for e in actors:
		body = Clearance.body_rect(e)
		visible = visible and body.has_area() and g.get_viewport_rect().encloses(body)
	_check(id + ".bodies_in_view", visible, "Production body bounds proxy; inspect actual native art and UI")
	views.append({"id": id, "path": r.shot(id), "state": _frame()})


func _retire() -> void:
	_key(KEY_A, false); _key(KEY_D, false)
	for e in actors:
		if is_instance_valid(e): e.queue_free()
	actors.clear()
	await r.frames(3)


func _live() -> bool:
	return not r.get_tree().paused and p.is_physics_processing() and g.is_processing() and not g.input_overlay_up() and not p.dead and g.cur_room == room


func _frame() -> Dictionary:
	var aim := p.aim_focus()
	var actor_states: Array[Dictionary] = []
	for e in actors:
		if is_instance_valid(e):
			actor_states.append({"id": e.get_instance_id(), "kind": e.kind, "level": e.level, "position": _v(e.global_position), "hp": e.hp, "frozen_ai": not e.is_physics_processing()})
	return {"position": _v(p.global_position), "physics_frame": Engine.get_physics_frames(),
		"actors": actor_states,
		"soft": p.soft_target.get_instance_id() if is_instance_valid(p.soft_target) else 0,
		"aim": aim.get_instance_id() if is_instance_valid(aim) else 0,
		"locked": p.locked_target.get_instance_id() if is_instance_valid(p.locked_target) else 0,
		"hud_target": g.hud.target_bar_unit.get_instance_id() if is_instance_valid(g.hud.target_bar_unit) else 0,
		"hp": p.hp, "room": g.cur_room, "live": _live()}


func _key(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key; event.physical_keycode = key; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()


func _v(at: Vector2) -> Array:
	return [at.x, at.y]
