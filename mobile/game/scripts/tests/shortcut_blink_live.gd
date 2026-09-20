extends Node
## Local Codex regression for same-room Blink through closed shortcut mouths.
## Controlled geometry/resource/pose fixture; every measured cast is native a3.
const Domain := preload("res://scripts/tests/shortcut_domain_live.gd")
var r
var g: Game
var p: Player
var pending := Callable()
var probe: Dictionary = {}
var watching := false
var landing: Dictionary = {}
var held_key := 0
var rows: Array = []
var cases: Array = []
var originals: Array = []
var scenery: StaticBody2D
const SAVE_SLOT := 98
var saved_files: Dictionary = {}

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
	if is_instance_valid(q.scenery): q.scenery.queue_free()
	if is_instance_valid(q.g): q.g.no_saves = true
	var file_restore: Dictionary = q._restore_files()
	if not file_restore.errors.is_empty(): error += "; save fixture cleanup failed"
	q._check("runtime.completed", error == "", error)
	var failures := 0
	for row in q.rows:
		if not bool(row.passed): failures += 1
	var receipt: Dictionary = {"rig": "shortcuts --blink-mouth", "save_arrival": rig.flag("save-arrival"), "checks": q.rows,
		"failures": failures, "error": error, "cases": q.cases, "originals": q.originals,
		"complete": error == "" and failures == 0,
		"scope": "Disposable solo Mage; selected seeded E/W shortcut, both endpoint rooms marked cleared, posed heroes and facing, mana/cooldown reset per cast, camera shake/framing/smoothing disabled; one synthetic layer1 scenery slab. Native keyboard a3 intent only; no direct ability dispatch. First post-Player-physics observation freezes actor. Optional save-arrival uses synthetic slot98 positions with real autosave/load and exact file restoration. No earned-route, unlock interaction, combat balance, ENet or physical-device claim.",
		"cleanup": {"key_released": q.held_key == 0, "player_physics_stopped": not is_instance_valid(q.p) or not q.p.is_physics_processing(), "disposable_world_not_restored": true, "save_files": file_restore}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir + "/blink_receipt.json", FileAccess.WRITE)
	if file == null:
		error += "; could not write Blink receipt"
	else:
		file.store_string(JSON.stringify(receipt, "\t")); file.flush()
		if file.get_error() != OK: error += "; could not finish Blink receipt"
		file.close()
	q.queue_free()
	print("SHORTCUT BLINK: checks=%d failures=%d" % [receipt.checks.size(), failures])
	return error if error != "" else ("Shortcut Blink strict checks failed" if failures > 0 else "")

func _run() -> String:
	var home: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not home.contains("/build/qa/session-sept20/claude-shortcuts/") or r.flag("no-capture"):
		return "fresh isolated shortcut profile and original captures required"
	await r.boot("mage", "ch1", false)
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
	for zi in [a, b]:
		var other: int = b if zi == a else a
		var dir: String = "E" if g.neighbor(zi, "E") == other else "W"
		var out: Vector2 = Vector2.RIGHT if dir == "E" else Vector2.LEFT
		var mouth: Vector2 = g.door_pos(zi, dir)
		var rect: Rect2 = g.play_rect(zi)
		mouth.x = rect.end.x if dir == "E" else rect.position.x
		var shape: CollisionShape2D = gate.get_node_or_null("Mouth_%d_bar" % zi) as CollisionShape2D
		if shape == null or not shape.shape is RectangleShape2D: return "named mouth bar absent"
		if not _check(dir + ".bar_contract", shape.shape.size == Vector2(48, 144)
				and shape.global_position.distance_to(mouth - out * 120.0) < 0.01,
				{"mouth": _v(mouth), "center": _v(shape.global_position), "size": _v(shape.shape.size)}): return "unexpected bar dimensions"
		for kind in ["closed_cross", "closed_near_edge"]:
			var distance: float = 240.0 if kind == "closed_cross" else 360.0
			var err: String = await _cast(dir + "." + kind, zi, mouth - out * distance, out, mouth, gate, kind)
			if err != "": return err
	# Opening is an explicit fixture loan; native latch use belongs to solo/party QA.
	g.set_flag(String(selected.flag), true)
	if not _check("setup.open_atomic", not g.gates.has(key) and gate.collision_layer == 0 and not g._shortcut_closed(a, b), "same body disabled before fade"):
		return "open fixture did not clear the registered body"
	await r.get_tree().create_timer(0.9).timeout
	for zi in [a, b]:
		var other: int = b if zi == a else a
		var dir: String = "E" if g.neighbor(zi, "E") == other else "W"
		var out: Vector2 = Vector2.RIGHT if dir == "E" else Vector2.LEFT
		var mouth: Vector2 = g.door_pos(zi, dir)
		var rect: Rect2 = g.play_rect(zi)
		mouth.x = rect.end.x if dir == "E" else rect.position.x
		var err: String = await _cast(dir + ".open_cross", zi, mouth - out * 240.0, out, mouth, null, "open_cross")
		if err != "": return err
	# An ordinary scenery body must remain crossable when only its midpoint is solid.
	var dir: String = "E" if g.neighbor(a, "E") == b else "W"
	var out: Vector2 = Vector2.RIGHT if dir == "E" else Vector2.LEFT
	var mouth: Vector2 = g.door_pos(a, dir)
	var rect: Rect2 = g.play_rect(a)
	mouth.x = rect.end.x if dir == "E" else rect.position.x
	scenery = StaticBody2D.new(); scenery.collision_layer = 1; scenery.collision_mask = 0
	scenery.position = mouth - out * 160.0
	var block := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = Vector2(16, 80)
	block.shape = box; scenery.add_child(block)
	var paint := Polygon2D.new(); paint.polygon = PackedVector2Array([Vector2(-8,-40),Vector2(8,-40),Vector2(8,40),Vector2(-8,40)])
	paint.color = Color(0.4, 0.5, 0.65); scenery.add_child(paint); g.world.add_child(scenery)
	var scenery_error: String = await _cast("scenery.positive", a, mouth - out * 240.0, out, mouth, scenery, "scenery")
	if scenery_error != "": return scenery_error
	scenery.queue_free(); scenery = null
	await r.frames(2)
	if r.flag("save-arrival"):
		return await _save_arrivals(selected, seed_value)
	return ""


func _save_arrivals(edge: Dictionary, seed_value: int) -> String:
	# Explicit synthetic old-position saves, not earned gameplay or a native menu claim.
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SAVE_SLOT) + suffix
		saved_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var zi := int(edge.a)
	var other := int(edge.b)
	var dir: String = "E" if g.neighbor(zi, "E") == other else "W"
	var out: Vector2 = Vector2.RIGHT if dir == "E" else Vector2.LEFT
	var mouth: Vector2 = g.door_pos(zi, dir)
	var rect: Rect2 = g.play_rect(zi)
	mouth.x = rect.end.x if dir == "E" else rect.position.x
	for data in [[80.0, false, "closed_behind"], [120.0, false, "closed_inside"], [80.0, true, "opened_unchanged"]]:
		var inward := float(data[0]); var opened := bool(data[1]); var label := "save." + String(data[2])
		r.step(label)
		g.no_saves = true; p.set_physics_process(false); p.clear_local_intents()
		g.set_flag(String(edge.flag), opened)
		g._enter_room(zi)
		p.global_position = mouth - out * inward; p.velocity = Vector2.ZERO
		g.save_slot = SAVE_SLOT; g.no_saves = false
		# Primary JSON immediately after this synchronous autosave, never fallback .bak.
		g.autosave()
		g.no_saves = true
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path(SAVE_SLOT)))
		if not raw is Dictionary: return label + ": no primary JSON after autosave"
		var world: Dictionary = SaveGame.world_of(raw)
		var saved_position: Vector2 = mouth - out * inward
		if not _check(label + ".primary_saved", world.get("pos", []) == _v(saved_position)
				and int(world.get("cur_room", -1)) == zi and int(world.get("wander_seed", -1)) == seed_value
				and bool(world.get("flags", {}).get(String(edge.flag), false)) == opened,
				{"position": world.get("pos", []), "room": world.get("cur_room", -1), "opened": opened}):
			return label + ": saved fixture fields disagree"
		var prior_world: int = g.world.get_instance_id()
		g.load_save(SAVE_SLOT)
		p = g.local_player; p.set_physics_process(false)
		await r.frames(3)
		var observed: Dictionary = await _sample(func() -> Dictionary: return {
			"position": _v(p.global_position), "hits": _hits(p.global_position),
			"world_changed": g.world.get_instance_id() != prior_world, "room": g.room_at_pos(p.global_position)})
		if observed.is_empty(): return label + ": load physics observation timed out"
		var end: Vector2 = p.global_position
		var end_inward: float = (mouth - end).dot(out)
		_check(label + ".new_world_contract", bool(observed.world_changed) and g.wander_seed == seed_value
			and g.shortcut_edge == edge and g._edge_unlocked(zi, other) == opened, observed)
		_check(label + ".arrival_safe", observed.hits.is_empty() and int(observed.room) == zi
			and absf(end.y - saved_position.y) < 0.01 and (end.distance_to(saved_position) < 0.01 if opened else end_inward >= 157.0 and end_inward <= 180.0),
			{"saved": _v(saved_position), "actual": _v(end), "actual_inward": end_inward, "hits": observed.hits})
		cases.append({"label": label, "fixture_position": _v(saved_position), "opened": opened, "load": observed})
		if not await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0):
			return label + ": reload presentation did not settle"
		await r._capture(label.replace(".", "_")); originals.append(label.replace(".", "_"))
	return ""

func _restore_files() -> Dictionary:
	var record := {"files": [], "errors": []}
	for path in saved_files:
		if saved_files[path] == null:
			if FileAccess.file_exists(path):
				var removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				if removed != OK: record.errors.append("remove failed: " + String(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null: record.errors.append("restore open failed: " + String(path))
			else:
				file.store_buffer(saved_files[path]); file.flush()
				if file.get_error() != OK: record.errors.append("restore write failed: " + String(path))
				file.close()
		var exists: bool = FileAccess.file_exists(path)
		var exact: bool = not exists if saved_files[path] == null else exists and FileAccess.get_file_as_bytes(path) == saved_files[path]
		record.files.append({"path": path, "originally_present": saved_files[path] != null, "restored_exact": exact})
		if not exact: record.errors.append("restoration mismatch: " + String(path))
	return record

func _cast(label: String, zi: int, start: Vector2, direction: Vector2, mouth: Vector2, obstacle: StaticBody2D, kind: String) -> String:
	r.step(label)
	_release(); p.set_physics_process(false); p.clear_local_intents()
	p.global_position = start; p.velocity = Vector2.ZERO; p.facing = direction
	p.locked_target = null; p.soft_target = null; p.mp = p.max_mp; p.cds.a3 = 0.0
	g._enter_room(zi)
	await r.frames(4)
	if not await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0):
		return label + ": arrival presentation did not settle"
	var wanted: Vector2 = g.clamp_to_zone(start + direction * 190.0, start)
	var before: Dictionary = await _sample(func() -> Dictionary: return {
		"start_hits": _hits(start), "wanted_hits": _hits(wanted),
		"middle_hits": _hits(mouth - direction * 120.0 if kind == "closed_cross" else (start + wanted) * 0.5), "position": _v(p.global_position)})
	if before.is_empty(): return label + ": physics probe timed out"
	var expected_inward: float = 170.0 if kind == "closed_near_edge" else 80.0
	var body_ok := false
	for child in p.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D and not child.disabled:
			body_ok = is_equal_approx(child.shape.radius, 13.0) and child.position == Vector2.ZERO
	var setup_ok: bool = body_ok and p.collision_mask == 5 and before.start_hits.is_empty() and before.wanted_hits.is_empty() \
		and p.global_position.distance_to(start) < 0.01 and not g.input_overlay_up() and not r.get_tree().paused \
		and p.cls == "mage" and p._tfx.is_empty() and p.combo == 0.0 and not p.dead and not p.downed and not p.ghost \
		and p.frozen_time <= 0.0 and p.rooted_time <= 0.0 and absf((mouth - wanted).dot(direction) - expected_inward) < 0.01
	if kind == "closed_cross" or kind == "scenery":
		setup_ok = setup_ok and is_instance_valid(obstacle) and before.middle_hits.has(obstacle.get_instance_id())
	if kind == "closed_near_edge": setup_ok = setup_ok and before.middle_hits.is_empty()
	before.merge({"start": _v(start), "wanted": _v(wanted), "mouth": _v(mouth), "direction": _v(direction),
		"kind": kind, "mana": p.mp, "cost": p.ability_cost("a3"), "cd": p.ability_cd("a3"), "room": zi,
		"motion_faults": p.motion_faults, "radius": 13.0, "mask": p.collision_mask})
	var row: Dictionary = {"label": label, "before": before}; cases.append(row)
	if not _check(label + ".preconditions", setup_ok, before): return label + ": fixture precondition failed"
	landing = {}; watching = true; held_key = int(g.binds.a3)
	_key(held_key, true); p.set_physics_process(true)
	if not await r._until(func() -> bool: return not landing.is_empty(), 2.0):
		watching = false; _release(); p.set_physics_process(false)
		return label + ": no native Blink cast observed"
	row.landing = landing.duplicate(true)
	var end: Vector2 = p.global_position
	_check(label + ".native_single_cast", bool(landing.key_down) and bool(landing.intent) and landing.move == [0.0,0.0]
		and absf(float(before.mana) - float(landing.mp) - float(before.cost)) < 0.01
		and absf(float(landing.cd) - float(before.cd)) < 0.01, landing)
	_check(label + ".safe_same_room", landing.hits.is_empty() and end.is_finite() and g.room_at_pos(end) == zi
		and p.motion_faults == int(before.motion_faults) and p.velocity == Vector2.ZERO
		and absf(end.y - start.y) < 0.01, landing)
	var inward: float = (mouth - end).dot(direction)
	if kind == "closed_cross":
		_check(label + ".closed_mouth_blocks", inward >= 157.0 - 0.01 and inward <= 160.0
			and (end - start).dot(direction) > 60.0, {"actual_inward": inward, "bar_inner_face": 144.0, "body_radius": 13.0})
	else:
		_check(label + ".endpoint_preserved", end.distance_to(wanted) < 0.01, {"actual": _v(end), "wanted": _v(wanted)})
	await r.get_tree().create_timer(0.6).timeout # let ordinary Blink flash/trails settle; measured landing is already frozen
	await r._capture(label.replace(".", "_"))
	originals.append(label.replace(".", "_"))
	return ""

func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var work: Callable = pending; pending = Callable(); probe = work.call()
	if not watching or not is_instance_valid(p) or float(p.cds.a3) <= 0.0: return
	landing = {"position": _v(p.global_position), "mp": p.mp, "cd": p.cds.a3,
		"key_down": Input.is_key_pressed(held_key), "intent": p.intent_a3, "move": _v(p.intent_move),
		"hits": _hits(p.global_position), "physics_frame": Engine.get_physics_frames()}
	p.set_physics_process(false); watching = false; _release()

func _sample(work: Callable) -> Dictionary:
	probe = {}; pending = work
	if not await r._until(func() -> bool: return not probe.is_empty(), 3.0): pending = Callable()
	return probe.duplicate(true)

func _hits(at: Vector2) -> Array:
	var ids: Array = []
	var excluded: Array[RID] = [p.get_rid()]
	for other in p.get_collision_exceptions():
		if is_instance_valid(other): excluded.append(other.get_rid())
	for owner in p.get_shape_owners():
		if p.is_shape_owner_disabled(owner): continue
		for i in p.shape_owner_get_shape_count(owner):
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = p.shape_owner_get_shape(owner, i)
			query.transform = p.global_transform * p.shape_owner_get_transform(owner)
			query.transform.origin += at - p.global_position
			query.collision_mask = p.collision_mask; query.exclude = excluded; query.margin = p.safe_margin
			query.collide_with_bodies = true; query.collide_with_areas = false
			for hit in p.get_world_2d().direct_space_state.intersect_shape(query, 32):
				ids.append(int(hit.collider_id))
	return ids

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func _release() -> void:
	if held_key != 0: _key(held_key, false)
	held_key = 0

func _check(id: String, ok: bool, actual: Variant = null) -> bool:
	rows.append({"id": id, "passed": ok, "actual": actual})
	return ok

func _v(value: Vector2) -> Array: return [value.x, value.y]
