extends "res://scripts/tests/shortcut_blink_live.gd"
## Native Paladin-only companion; reuses owned Blink input/physics sampling.
var target: Enemy

static func run(rig: ShotRig) -> String:
	var q := new()
	q.r = rig
	q.process_physics_priority = 1000
	rig.add_child(q)
	var error: String = await q._run()
	q.watching = false
	q.pending = Callable()
	q._release()
	if is_instance_valid(q.p): q.p.set_physics_process(false)
	if is_instance_valid(q.target): q.target.queue_free()
	q._check("runtime.completed", error == "", error)
	var failures := 0
	for row in q.rows:
		if not bool(row.passed): failures += 1
	var receipt: Dictionary = {"rig": "shortcuts --paladin-mouth", "checks": q.rows,
		"failures": failures, "error": error, "cases": q.cases, "originals": q.originals,
		"complete": error == "" and failures == 0,
		"scope": "Disposable Paladin on selected E/W shortcut, cleared rooms, posed hero and frozen factory wolf beyond each bar. Native keyboard a1; fresh mana, a1 and leap cooldown loans per case. Actual aim selection required; no direct ability call or assigned target. Closed/open gate fixture states and camera controls. No earned-route, combat balance, save, ENet or physical-device claim.",
		"cleanup": {"key_released": q.held_key == 0, "player_physics_stopped": not is_instance_valid(q.p) or not q.p.is_physics_processing(), "disposable_world_not_restored": true}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir + "/paladin_receipt.json", FileAccess.WRITE)
	if file == null:
		error += "; could not write Paladin receipt"
	else:
		file.store_string(JSON.stringify(receipt, "\t")); file.flush()
		if file.get_error() != OK: error += "; could not finish Paladin receipt"
		file.close()
	q.queue_free()
	print("SHORTCUT PALADIN: checks=%d failures=%d" % [receipt.checks.size(), failures])
	return error if error != "" else ("Shortcut Paladin strict checks failed" if failures > 0 else "")

func _run() -> String:
	var home: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not home.contains("/build/qa/session-sept20/claude-shortcuts/") or r.flag("no-capture"):
		return "fresh isolated shortcut profile and original captures required"
	await r.boot("paladin", "ch1", false)
	g = r.game; p = g.local_player
	if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
		return "boot did not become playable"
	if not g.no_saves or g.net_online() or g.guest_world or g.dev_god:
		return "unexpected save/network/god mode"
	p.set_physics_process(false)
	var seed_value := -1
	var selected: Dictionary = {}
	for candidate in range(1000, 1200):
		var fixture: Game = Domain._fixture(candidate, true)
		var edge: Dictionary = fixture.shortcut_edge.duplicate(true)
		var horizontal: bool = not edge.is_empty() and int(edge.a) != 0 and int(edge.b) != 0 \
			and Vector2i(fixture.rooms[int(edge.a)].coord).y == Vector2i(fixture.rooms[int(edge.b)].coord).y
		fixture.free()
		if horizontal:
			seed_value = candidate; selected = edge; break
	if seed_value < 0: return "bounded seed scan found no E/W fixture"
	g._wipe_chapter_flags(); g.wander_seed = seed_value
	g.switch_chapter("ch1", true)
	await r.skip_dialogue()
	if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
		return "rebuilt fixture not playable"
	p = g.local_player; p.set_physics_process(false)
	g.settings["camera_shake"] = 0.0; g.settings["combat_framing"] = false
	g.settings["touch_controls"] = false; g.refresh_touch_mode(); g._apply_touch_mode()
	g.camera.position_smoothing_enabled = false; g.terrain_event_t = 10000.0
	g.gust_vec = Vector2.ZERO
	if g.shortcut_edge != selected: return "live graph disagrees with seed fixture"
	var a := int(selected.a); var b := int(selected.b)
	for zi in [a, b]:
		g.cleared[zi] = true; g.zone_alive[zi] = 0; g._build_room(zi)
	var key: String = g._edge_key(a, b)
	if not g.gates.has(key) or g._edge_unlocked(a, b): return "fresh closed gate missing"
	var gate: StaticBody2D = g.gates[key] as StaticBody2D
	var geometry: Array = []
	for child in gate.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			geometry.append({"name": child.name, "position": _v(child.global_position), "size": _v(child.shape.size), "disabled": child.disabled})
	if not _check("setup.six_mouth_shapes", geometry.size() == 6 and gate.collision_layer == 1,
			{"seed": seed_value, "edge": selected, "gate_id": gate.get_instance_id(), "shapes": geometry}):
		return "shortcut shape contract changed"
	for phase in ["closed", "open"]:
		if phase == "open":
			g.set_flag(String(selected.flag), true)
			if not _check("setup.open_atomic", not g.gates.has(key) and gate.collision_layer == 0, "real gate body disabled"):
				return "open fixture did not clear gate"
			await r.get_tree().create_timer(0.9).timeout
		for zi in [a, b]:
			var other: int = b if zi == a else a
			var direction: Vector2 = Vector2.RIGHT if g.neighbor(zi, "E") == other else Vector2.LEFT
			var dir: String = "E" if direction.x > 0.0 else "W"
			var mouth: Vector2 = g.door_pos(zi, dir)
			var rect: Rect2 = g.play_rect(zi)
			mouth.x = rect.end.x if dir == "E" else rect.position.x
			var err: String = await _leap(dir + "." + phase, zi, mouth, direction, phase == "closed")
			if err != "": return err
	return ""

func _leap(label: String, zi: int, mouth: Vector2, direction: Vector2, closed: bool) -> String:
	r.step(label)
	_release(); p.set_physics_process(false); p.clear_local_intents()
	if is_instance_valid(target):
		target.queue_free()
		await r.frames(2)
	var start: Vector2 = mouth - direction * 240.0
	p.global_position = start; p.velocity = Vector2.ZERO; p.facing = direction
	p.locked_target = null; p.soft_target = null
	p.mp = p.max_mp; p.cds.a1 = 0.0; p.judgment_leap_cd = 0.0
	g._enter_room(zi)
	target = Enemy.make(g, "wolf", mouth - direction * 22.0, 1)
	target.zone_idx = zi
	g.world.add_child(target)
	target.set_physics_process(false); target.set_process(false)
	target.max_hp = 10000.0; target.hp = target.max_hp
	await r.frames(4)
	if not await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0):
		return label + ": arrival presentation did not settle"
	var wanted: Vector2 = g.clamp_to_zone(target.global_position - direction * 58.0, target.global_position)
	var before: Dictionary = await _sample(func() -> Dictionary: return {"start_hits": _hits(start), "wanted_hits": _hits(wanted), "middle_hits": _hits(mouth - direction * 120.0)})
	if before.is_empty(): return label + ": physics sample timed out"
	var body_ok := false
	for child in p.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D and not child.disabled:
			body_ok = is_equal_approx(child.shape.radius, 13.0) and child.position == Vector2.ZERO
	var ready: bool = body_ok and p.cls == "paladin" and p.collision_mask == 5 and p.auto_aim(300.0) == target \
		and p._tfx.is_empty() and not g.input_overlay_up() and not r.get_tree().paused \
		and not p.dead and not p.downed and not p.ghost and p.frozen_time <= 0.0 and p.rooted_time <= 0.0 \
		and before.start_hits.is_empty() and before.wanted_hits.is_empty() \
		and p.global_position.distance_to(start) < 0.01 and absf((mouth - wanted).dot(direction) - 80.0) < 0.01
	if closed:
		var edge: Dictionary = g.shortcut_edge
		var body: StaticBody2D = g.gates.get(g._edge_key(int(edge.a), int(edge.b))) as StaticBody2D
		ready = ready and is_instance_valid(body) and before.middle_hits.has(body.get_instance_id())
	before.merge({"start": _v(start), "wanted": _v(wanted), "target": _v(target.global_position), "target_level": target.level,
		"target_hp": target.hp, "mana": p.mp, "cost": p.ability_cost("a1"), "cd": p.ability_cd("a1"), "motion_faults": p.motion_faults})
	var row: Dictionary = {"label": label, "before": before}; cases.append(row)
	if not _check(label + ".preconditions", ready, before): return label + ": controlled leap setup failed"
	landing = {}; watching = true; held_key = int(g.binds.a1)
	_key(held_key, true); p.set_physics_process(true)
	if not await r._until(func() -> bool: return not landing.is_empty(), 2.0):
		watching = false; _release(); p.set_physics_process(false)
		return label + ": no actual native Judgment leap observed"
	row.landing = landing.duplicate(true)
	var end: Vector2 = p.global_position
	_check(label + ".native_leap", bool(landing.key_down) and bool(landing.intent) and landing.move == [0.0,0.0]
		and absf(float(before.mana) - float(landing.mp) - float(before.cost)) < 0.01
		and absf(float(landing.cd) - float(before.cd)) < 0.01 and float(landing.leap_cd) > 0.0, landing)
	_check(label + ".safe_same_room", landing.hits.is_empty() and end.is_finite() and g.room_at_pos(end) == zi
		and p.motion_faults == int(before.motion_faults) and p.velocity == Vector2.ZERO and absf(end.y - start.y) < 0.01, landing)
	var inward: float = (mouth - end).dot(direction)
	_check(label + ".landing", (inward >= 157.0 - 0.01 and inward <= 160.0 and (end-start).dot(direction) > 60.0)
		if closed else end.distance_to(wanted) < 0.01, {"inward": inward, "wanted": _v(wanted), "actual": _v(end)})
	_check(label + ".target_survived", is_instance_valid(target) and not target.dying and target.hp > 0.0, "factory target stays alive; no kill reward")
	await r.get_tree().create_timer(0.6).timeout
	await r._capture(label.replace(".", "_")); originals.append(label.replace(".", "_"))
	return ""

func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var work: Callable = pending; pending = Callable(); probe = work.call()
	if not watching or not is_instance_valid(p) or float(p.cds.a1) <= 0.0 or p.judgment_leap_cd <= 0.0: return
	landing = {"position": _v(p.global_position), "mp": p.mp, "cd": p.cds.a1, "leap_cd": p.judgment_leap_cd,
		"key_down": Input.is_key_pressed(held_key), "intent": p.intent_a1, "move": _v(p.intent_move),
		"hits": _hits(p.global_position), "physics_frame": Engine.get_physics_frames()}
	p.set_physics_process(false); watching = false; _release()
