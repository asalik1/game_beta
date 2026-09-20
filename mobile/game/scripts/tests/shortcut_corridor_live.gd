extends Node
## DeepSeek Flash advisory; locally corrected diagnostic. No camera writes.
const Domain := preload("res://scripts/tests/shortcut_domain_live.gd")
const Selector := preload("res://scripts/shortcut_gate.gd")
const Bounds := preload("res://scripts/ui/hud_clearance.gd")
const WALK_MS := 12000
var r: ShotRig
var g: Game
var p: Player
var held := 0
var selected: Dictionary = {}
var checks: Array = []
var walks: Array = []
var originals: Array = []
var camera_defaults: Dictionary = {}
var observed_source := -1
var observed_destination := -1

static func run(rig: ShotRig) -> String:
	var q := new()
	q.r = rig
	rig.add_child(q)
	var error: String = await q._run()
	q._release()
	if is_instance_valid(q.p): q.p.clear_local_intents()
	q._check("runtime.completed", error == "", error)
	var receipt := {"rig": "shortcuts --corridor-camera", "complete": error == "",
		"horizontal": rig.flag("corridor-horizontal"), "lazy_build": rig.flag("corridor-lazy"), "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"hot_arrival": rig.flag("corridor-hot"), "planned_walks": 1 if rig.flag("corridor-hot") else 4,
		"camera_accepted": false, "navigation_complete": q.walks.size() == (1 if rig.flag("corridor-hot") else 4) and q.walks.all(func(w: Dictionary) -> bool: return bool(w.get("reached", false)) and w.get("error", "") == ""),
		"error": error, "selection": q.selected,
		"checks": q.checks, "walks": q.walks, "originals": q.originals,
		"initial_camera": q.camera_defaults, "cleanup": {"key_released": q.held == 0,
		"no_signal_observer_installed": true, "disposable_world_not_restored": true},
		"scope": "Controlled solo Warrior HOT arrival: ONE forward original unlocked corridor, source-only cleared/zero-alive loan, unbuilt/unvisited/uncleared authored combat destination. No shortcut-open flag loan, no enemy spawn/freeze/aggro/HP/god manipulation. Normal entry spawns real enemies; native movement continues to120px inside destination. Pose before walk and terrain-timer suppression remain controlled setup. Default camera and live AI; no ordinary-campaign, combat-balance, save, ENet or physical-device claim." if rig.flag("corridor-hot") else "Controlled solo Warrior, first qualifying seeded axis-specific shortcut and original unlocked connector; rooms pre-cleared, shortcut flag loaned, poses only before each walk. Default camera/framing/zoom/smoothing/lead/shake; native W/S or A/D continuously held through inset corridor to 120px inside destination play rect. Terrain event timer held high during setup and each rendered observation. No ordinary campaign, earned unlock, combat, save, ENet or physical-device claim.",
		"measurement_limits": ["HudClearance body_rect is an authored body proxy, NOT exact painted alpha bounds.",
		"HUD intersections are visible Control rectangles, NOT opaque pixel occlusion.",
		"Samples are once per rendered frame; streak duration is observed first-to-last offscreen sample time.",
		"PNG readback/write blocks this main thread while input remains held; elapsed wall time includes that cost.",
		"A completed diagnostic does not mean camera visibility passed; inspect offscreen samples and originals."]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir + "/corridor_receipt.json", FileAccess.WRITE)
	if file == null: error += "; receipt open failed"
	else:
		file.store_string(JSON.stringify(receipt, "\t")); file.flush()
		if file.get_error() != OK: error += "; receipt write failed"
		file.close()
	print("SHORTCUT CORRIDOR: walks=%d checks=%d complete=%s" % [q.walks.size(), q.checks.size(), str(error == "")])
	q.queue_free()
	return error

func _run() -> String:
	var home: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not home.contains("/build/qa/session-sept20/claude-shortcuts/") or r.flag("no-capture"):
		return "isolated shortcut QA profile and native captures required"
	selected = _select()
	if selected.is_empty(): return "no qualifying first seed in 1000..1199"
	await r.boot("warrior", "ch1", false)
	g = r.game; p = g.local_player
	if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
		return "boot did not become playable"
	if not g.no_saves or g.net_online() or g.guest_world or g.dev_god: return "unexpected boot mode"
	p.set_physics_process(false)
	g._wipe_chapter_flags(); g.wander_seed = int(selected.seed)
	g.switch_chapter("ch1", true)
	await r.skip_dialogue()
	p = g.local_player
	p.set_physics_process(false)
	if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
		return "seeded boot did not become playable"
	camera_defaults = _camera_policy()
	if not _check("setup.default_camera", bool(camera_defaults.smoothing) and bool(camera_defaults.framing)
			and is_equal_approx(float(camera_defaults.lead), 1.0), camera_defaults): return "default camera precondition failed"
	if r.flag("corridor-hot"): return await _run_hot()
	if not _check("setup.live_graph", g.shortcut_edge == selected.shortcut
			and _ordinary(g, int(selected.control.a), int(selected.control.b)), selected): return "live graph differs from selector"
	var rooms: Array = [int(selected.shortcut.a), int(selected.shortcut.b), int(selected.control.a), int(selected.control.b)]
	for zi in rooms:
		g.cleared[zi] = true; g.zone_alive[zi] = 0
	if not r.flag("corridor-lazy"):
		for zi in rooms: g._build_room(zi)
	g.set_flag(String(selected.shortcut.flag), true)
	g.terrain_event_t = 10000.0
	await r.get_tree().create_timer(0.9).timeout
	if not _check("setup.open", g._edge_unlocked(int(selected.shortcut.a), int(selected.shortcut.b))
			and not g.gates.has(g._edge_key(int(selected.shortcut.a), int(selected.shortcut.b))), "explicit flag loan, genuine fade"):
		return "shortcut did not open"
	var forward: String = _forward()
	for kind in ["shortcut", "control"]:
		var edge: Dictionary = selected[kind]
		var near_room: int = int(edge.a) if g.neighbor(int(edge.a), forward) == int(edge.b) else int(edge.b)
		var far_room: int = int(edge.b) if near_room == int(edge.a) else int(edge.a)
		for direction in [forward, _opposite(forward)]:
			var source: int = near_room if direction == forward else far_room
			var destination: int = far_room if direction == forward else near_room
			var error: String = await _walk(String(kind) + "_" + direction, source, destination, direction)
			if error != "": return error
	var visibility_failures := 0
	for row in walks:
		if not _check(String(row.label) + ".fully_in_view", int(row.partially_clipped_frames) == 0,
				{"fully_outside_frames": row.fully_outside_frames, "partially_clipped_frames": row.partially_clipped_frames,
				"max_offscreen_observed_ms": row.max_offscreen_observed_ms, "minimum_margin": row.min_signed_margin}): visibility_failures += 1
	return "Visibility findings in %d of four completed walks" % visibility_failures if visibility_failures > 0 else ""

func _select() -> Dictionary:
	if r.flag("corridor-hot"): return _select_hot()
	var forward: String = _forward()
	for seed_value in range(1000, 1200):
		# Read original graph BEFORE installation, preventing a shortcut-as-control.
		var fixture: Game = Domain._fixture(seed_value, false)
		var controls: Array = []
		for a in range(1, fixture.zone_count):
			var b: int = fixture.neighbor(a, forward)
			if _ordinary(fixture, a, b): controls.append({"a": a, "b": b})
		fixture._install_shortcut()
		var edge: Dictionary = fixture.shortcut_edge.duplicate(true)
		var ok: bool = not edge.is_empty() and int(edge.a) > 0 and int(edge.b) > 0
		var control: Dictionary = {}
		if ok:
			ok = fixture.neighbor(int(edge.a), forward) == int(edge.b) or fixture.neighbor(int(edge.a), _opposite(forward)) == int(edge.b)
			for candidate in controls:
				if r.flag("corridor-lazy") and (int(candidate.a) in [int(edge.a), int(edge.b)] or int(candidate.b) in [int(edge.a), int(edge.b)]): continue
				control = candidate; break
		ok = ok and not control.is_empty()
		var result: Dictionary = {}
		if ok: result = {"seed": seed_value, "shortcut": edge, "control": control,
			"forward": forward, "lazy_disjoint_pairs": r.flag("corridor-lazy"),
			"selection": "First qualifying seed; first reciprocal unlocked original %s edge in numeric room order%s. No retry after runtime failure." % [forward, "; disjoint from shortcut endpoints for lazy fresh destinations" if r.flag("corridor-lazy") else ""]}
		fixture.free()
		if ok: return result
	return {}

func _select_hot() -> Dictionary:
	# Ordinary original graph only. A seed is accepted by metadata, never retried after play.
	var direction: String = _forward()
	for seed_value in range(1000, 1200):
		var fixture: Game = Domain._fixture(seed_value, false)
		var result: Dictionary = {}
		for source in range(1, fixture.zone_count):
			var destination: int = fixture.neighbor(source, direction)
			if not _ordinary(fixture, source, destination) or not _hot_destination(fixture, destination): continue
			result = {"seed": seed_value, "source": source, "destination": destination, "forward": direction,
				"destination_authored_enemies": (fixture.zones[destination].get("enemies", []) as Array).size(),
				"selection": "First seed1000..1199, first numeric source with reciprocal original unlocked %s edge and nonboss authored combat destination with positive entry inset. No installed shortcut required, no runtime retries." % direction}
			break
		fixture.free()
		if not result.is_empty(): return result
	return {}

func _hot_destination(fixture: Game, zi: int) -> bool:
	if not Selector.valid_room(fixture, zi) or fixture.room_type(zi) != "combat": return false
	if (fixture.zones[zi].get("enemies", []) as Array).is_empty(): return false
	var play: Rect2 = fixture.play_rect(zi)
	var cell: Rect2 = fixture.room_rect(zi)
	return play.position.x > cell.position.x if _forward() == "E" else play.position.y > cell.position.y

func _destination_state(zi: int) -> Dictionary:
	return {"built": bool(g.built.get(zi, false)), "visited": bool(g.visited.get(zi, false)),
		"cleared": bool(g.cleared.get(zi, false)), "zone_alive": int(g.zone_alive.get(zi, 0))}

func _run_hot() -> String:
	var source: int = int(selected.source)
	var destination: int = int(selected.destination)
	if not _check("hot.original_combat_edge", _ordinary(g, source, destination) and _hot_destination(g, destination), selected):
		return "hot route disagrees with original graph selection"
	var before: Dictionary = _destination_state(destination)
	if not _check("hot.destination_untouched", not before.built and not before.visited and not before.cleared and int(before.zone_alive) == 0, before):
		return "hot destination is not fresh/uncleared"
	# Only the source metadata is loaned; source construction remains _walk's ordinary entry.
	g.cleared[source] = true; g.zone_alive[source] = 0
	g.terrain_event_t = 10000.0
	var flag_name: String = String(g.shortcut_edge.get("flag", ""))
	var flag_before: bool = bool(g.get_flag(flag_name, false)) if flag_name != "" else false
	var error: String = await _walk("hot_" + _forward(), source, destination, _forward())
	if error != "": return error
	var row: Dictionary = walks[0]
	var first: Dictionary = row.get("first_hot", {})
	var arrival: Dictionary = row.get("hot_arrival", {})
	var failed := false
	if not _check("hot.native_inside_corridor", not first.is_empty() and bool(first.get("before_destination_mouth", false))
			and bool(first.get("native_key_held", false)) and bool(first.get("destination_hot", false))
			and int(first.get("destination_alive", 0)) > 0 and int(first.get("cur_room", -1)) == destination, first): failed = true
	if not _check("hot.settled_live_arrival", int(arrival.get("cur_room", -1)) == destination
			and bool(arrival.get("destination_hot", false)) and int(arrival.get("destination_alive", 0)) > 0
			and not bool(arrival.get("hero_incapacitated", true)) and float(arrival.get("hp", 0.0)) > 0.0
			and not bool(arrival.get("body_empty", true)), arrival): failed = true
	var flag_after: bool = bool(g.get_flag(flag_name, false)) if flag_name != "" else false
	if not _check("hot.no_shortcut_open_loan", flag_after == flag_before, {"flag": flag_name, "before": flag_before, "after": flag_after}): failed = true
	if not _check("hot.fully_in_view", int(row.partially_clipped_frames) == 0 and float(arrival.get("minimum_margin", -1.0)) >= 0.0,
			{"walk_clipped_frames": row.partially_clipped_frames, "fully_outside_frames": row.fully_outside_frames,
			"arrival_ratio": arrival.get("visible_ratio", 0.0), "arrival_minimum_margin": arrival.get("minimum_margin", -1.0), "max_offscreen_observed_ms": row.max_offscreen_observed_ms}): failed = true
	return "Hot arrival strict findings; inspect complete native evidence" if failed else ""

func _ordinary(fixture: Game, a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or not Selector.valid_room(fixture, a) or not Selector.valid_room(fixture, b): return false
	var forward: String = _forward()
	if fixture.neighbor(a, forward) != b or fixture.neighbor(b, _opposite(forward)) != a: return false
	if not (fixture.rooms[a]["exits"] as Dictionary).has(forward) or not (fixture.rooms[b]["exits"] as Dictionary).has(_opposite(forward)): return false
	if fixture.edge_locks.has(fixture._edge_key(a, b)): return false
	var gap: float = fixture.play_rect(b).position.x - fixture.play_rect(a).end.x if forward == "E" else fixture.play_rect(b).position.y - fixture.play_rect(a).end.y
	return gap > 1.0

func _mouth(zi: int, direction: String) -> Vector2:
	var point: Vector2 = g.door_pos(zi, direction)
	var rect: Rect2 = g.play_rect(zi)
	if direction in ["S", "N"]:
		point.y = rect.end.y if direction == "S" else rect.position.y
	else:
		point.x = rect.end.x if direction == "E" else rect.position.x
	return point

func _forward() -> String: return "E" if r.flag("corridor-horizontal") else "S"
func _opposite(direction: String) -> String: return {"N": "S", "S": "N", "E": "W", "W": "E"}[direction]
func _axis(direction: String) -> Vector2: return {"N": Vector2.UP, "S": Vector2.DOWN, "E": Vector2.RIGHT, "W": Vector2.LEFT}[direction]
func _movement_key(direction: String) -> int: return {"N": KEY_W, "S": KEY_S, "E": KEY_D, "W": KEY_A}[direction]

func _walk(label: String, source: int, destination: int, direction: String) -> String:
	r.step(label)
	observed_source = source; observed_destination = destination
	_release(); p.clear_local_intents(); p.set_physics_process(false)
	var axis: Vector2 = _axis(direction)
	var mouth: Vector2 = _mouth(source, direction)
	var far_mouth: Vector2 = _mouth(destination, _opposite(direction))
	var start: Vector2 = mouth - axis * 240.0
	var finish: Vector2 = far_mouth + axis * 120.0
	var mid: Vector2 = (mouth + far_mouth) * 0.5
	p.global_position = start; p.velocity = Vector2.ZERO
	g._enter_room(source); g.terrain_event_t = 10000.0
	await r.get_tree().create_timer(1.0).timeout
	if not await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0):
		return label + ": room presentation did not settle"
	var row: Dictionary = {"label": label, "source": source, "destination": destination, "direction": direction,
		"source_play_rect": _rect(g.play_rect(source)), "destination_play_rect": _rect(g.play_rect(destination)),
		"mouth": _v(mouth), "far_mouth": _v(far_mouth), "cell_boundary": _v(g.door_pos(source, direction)),
		"start": _v(start), "finish": _v(finish), "midpoint": _v(mid), "samples": [], "captures": [],
		"fully_outside_frames": 0, "partially_clipped_frames": 0, "max_offscreen_observed_ms": 0,
		"min_signed_margin": 1000000.0, "error": ""}
	walks.append(row)
	if r.flag("corridor-hot"):
		var hot_initial: Dictionary = _destination_state(destination)
		if not _check(label + ".fresh_after_source_entry", not hot_initial.built and not hot_initial.visited and not hot_initial.cleared
				and int(hot_initial.zone_alive) == 0 and not g._room_hot(source), hot_initial):
			row.error = "source entry altered hot destination or source remains hot"
			return label + ": " + String(row.error)
	if r.flag("corridor-lazy"):
		var initial_built: bool = bool(g.built.get(destination, false))
		var initial_visited: bool = bool(g.visited.get(destination, false))
		var fresh_destination: bool = direction == _forward()
		row["lazy_initial"] = {"built": initial_built, "visited": initial_visited, "fresh_expected": fresh_destination}
		if not _check(label + ".lazy_initial", (not initial_built and not initial_visited) if fresh_destination else (initial_built and initial_visited), row.lazy_initial):
			row.error = "lazy destination precondition failed"
			return label + ": " + String(row.error)
	if not _check(label + ".setup", g.cur_room == source and g.room_at_pos(start) == source
			and g.play_rect(source).has_point(start) and g.play_rect(destination).has_point(finish)
			and not g._pos_in_wall(start) and not g.input_overlay_up() and not r.get_tree().paused
			and not p.dead and not p.downed and not p.ghost and g.is_processing()
			and Bounds.body_rect(p).has_area() and _camera_policy() == camera_defaults, {"start": _v(start), "camera": _camera_policy()}): return label + ": setup failed"
	await RenderingServer.frame_post_draw
	if not _shot(row, "approach", _sample(0)): return label + ": approach capture missing"
	p.set_physics_process(true)
	held = _movement_key(direction)
	_key(held, true)
	var started: int = Time.get_ticks_msec()
	var outside_since := -1
	var mid_written := false
	var off_written := false
	var reached := false
	while Time.get_ticks_msec() - started < WALK_MS:
		await RenderingServer.frame_post_draw
		g.terrain_event_t = 10000.0
		var sample: Dictionary = _sample(Time.get_ticks_msec() - started)
		row.samples.append(sample)
		if r.flag("corridor-hot") and not row.has("first_hot") and int(sample.cur_room) == destination and bool(sample.destination_hot) and int(sample.destination_alive) > 0:
			var first: Dictionary = sample.duplicate(true)
			first["before_destination_mouth"] = (p.global_position - far_mouth).dot(axis) < 0.0
			row["first_hot"] = first
			if not _shot(row, "first_hot", first): row.error = "first hot capture missing"; break
		if r.flag("corridor-lazy"):
			var destination_entered: bool = int(sample.cur_room) == destination
			var both_ready: bool = bool(sample.destination_built) and bool(sample.destination_visited)
			var neither_ready: bool = not bool(sample.destination_built) and not bool(sample.destination_visited)
			if (destination_entered and not both_ready) or (direction == _forward() and not destination_entered and not neither_ready):
				row.error = "destination build/visit did not follow ordinary room entry"; break
		if bool(sample.body_empty): row.error = "authored body measurement became empty"; break
		row.min_signed_margin = minf(float(row.min_signed_margin), float(sample.minimum_margin))
		if bool(sample.fully_outside):
			row.fully_outside_frames += 1
			if outside_since < 0: outside_since = int(sample.t_ms)
			row.max_offscreen_observed_ms = maxi(int(row.max_offscreen_observed_ms), int(sample.t_ms) - outside_since)
		else: outside_since = -1
		# Area division can round below one even with every edge well inside.
		# Signed rectangle boundaries retain strict subpixel clipping detection.
		if float(sample.minimum_margin) < 0.0: row.partially_clipped_frames += 1
		if bool(sample.fully_outside) and not off_written:
			off_written = true
			if not _shot(row, "first_offscreen", sample): row.error = "offscreen capture missing"; break
		if not mid_written and (p.global_position - mid).dot(axis) >= 0.0:
			mid_written = true
			if not _shot(row, "midcorridor", sample): row.error = "midcorridor capture missing"; break
		if p.dead or p.downed or p.ghost or g.input_overlay_up() or r.get_tree().paused:
			row.error = "death/overlay/pause during walk"; break
		if not p.is_physics_processing() or not Input.is_physical_key_pressed(held):
			row.error = "native held input or actor processing lost"; break
		if g.cur_room == destination and g.room_at_pos(p.global_position) == destination and (p.global_position - finish).dot(axis) >= 0.0:
			reached = true; break
	_release()
	row.walk_elapsed_ms = Time.get_ticks_msec() - started
	row.terminal_position = _v(p.global_position)
	row.reached = reached
	if r.flag("corridor-lazy"):
		if not _check(label + ".lazy_lifecycle", reached and row.error == "" and bool(g.built.get(destination, false)) and bool(g.visited.get(destination, false)),
				{"built": g.built.get(destination, false), "visited": g.visited.get(destination, false), "room": g.cur_room, "error": row.error}):
			if row.error == "": row.error = "lazy lifecycle did not complete"
	if not reached and row.error == "": row.error = "12-second continuous walk did not reach destination inset"
	_check(label + ".continuous_route", reached and mid_written and row.error == "", {"reached": reached, "mid_written": mid_written, "samples": row.samples.size(), "error": row.error})
	# Physics stays enabled after release; let ordinary movement/camera settle.
	await r.get_tree().create_timer(1.0).timeout
	var presentation_settled: bool = await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0)
	if not _check(label + ".terminal_presentation", presentation_settled, "passive title/subtitle/overlay wait after key release"):
		row.error = "terminal presentation did not settle"
	await RenderingServer.frame_post_draw
	if r.flag("corridor-hot"):
		row["hot_arrival"] = _sample(Time.get_ticks_msec() - started)
		if not _shot(row, "settled_arrival" if reached and presentation_settled else "failure", row.hot_arrival):
			row.error = "terminal capture missing"
	else:
		if not _shot(row, "settled_arrival" if reached and presentation_settled else "failure", _sample(Time.get_ticks_msec() - started)):
			row.error = "terminal capture missing"
	if not _check(label + ".camera_unchanged", _camera_policy() == camera_defaults, _camera_policy()): row.error = "camera policy changed"
	return "" if row.error == "" else label + ": " + String(row.error)

func _sample(elapsed: int) -> Dictionary:
	var body: Rect2 = Bounds.body_rect(p)
	var viewport: Rect2 = g.get_viewport_rect()
	var intersection: Rect2 = body.intersection(viewport)
	var area: float = maxf(0.0, body.size.x) * maxf(0.0, body.size.y)
	var ratio: float = intersection.get_area() / area if area > 0.0 else 0.0
	var margins: Array = [body.position.x - viewport.position.x, body.position.y - viewport.position.y,
		viewport.end.x - body.end.x, viewport.end.y - body.end.y]
	return {"t_ms": elapsed, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"position": _v(p.global_position), "velocity": _v(p.velocity), "cur_room": g.cur_room,
		"hp": p.hp, "max_hp": p.max_hp, "since_hurt": p.since_hurt, "hurt_cd": p.hurt_cd,
		"hero_incapacitated": p.dead or p.downed or p.ghost, "destination_cleared": g.cleared.get(observed_destination, false),
		"destination_hot": g._room_hot(observed_destination), "destination_alive": int(g.zone_alive.get(observed_destination, 0)),
		"source_built": g.built.get(observed_source, false), "source_visited": g.visited.get(observed_source, false),
		"destination_built": g.built.get(observed_destination, false), "destination_visited": g.visited.get(observed_destination, false),
		"room_at_pos": g.room_at_pos(p.global_position), "camera_center": _v(g.camera.get_screen_center_position()),
		"limits": [g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom],
		"zoom": _v(g.camera.zoom), "camera_position": _v(g.camera.position), "camera_offset": _v(g.camera.offset),
		"smoothing": g.camera.position_smoothing_enabled, "sprite_draw_rect": _sprite_rect(), "body_proxy": _rect(body), "viewport": _rect(viewport),
		"body_empty": area <= 0.0, "visible_ratio": ratio, "fully_outside": area > 0.0 and ratio <= 0.0,
		"margins_left_top_right_bottom": margins, "minimum_margin": margins.min(),
		"hud_rect_intersections": _hud_intersections(body), "native_key_held": held != 0 and Input.is_physical_key_pressed(held)}

func _sprite_rect() -> Array:
	# Actual Sprite2D draw rectangle including transparent texels, not alpha bounds.
	if not is_instance_valid(p.sprite) or not p.sprite.is_visible_in_tree(): return []
	var local: Rect2 = p.sprite.get_rect()
	var transform: Transform2D = p.sprite.get_global_transform_with_canvas()
	var first: Vector2 = transform * local.position
	var rect := Rect2(first, Vector2.ZERO)
	for point in [local.position + Vector2(local.size.x, 0), local.end, local.position + Vector2(0, local.size.y)]:
		rect = rect.expand(transform * Vector2(point))
	return _rect(rect)

func _hud_intersections(body: Rect2) -> Array:
	var result: Array = []
	var panels: Dictionary = {"vitals": g.hud.vitals_panel, "info": g.hud.info_panel,
		"quest": g.hud.quest_panel, "avatar": g.hud.avatar_root, "minimap": g.hud.minimap_root}
	for i in g.hud.slot_boxes.size(): panels["ability_%d" % i] = g.hud.slot_boxes[i].get("bg")
	for name in panels:
		var panel: Control = panels[name] as Control
		if not is_instance_valid(panel) or not panel.is_visible_in_tree(): continue
		var rect: Rect2 = panel.get_global_rect()
		if rect.intersects(body): result.append({"name": name, "rect": _rect(rect), "intersection": _rect(rect.intersection(body))})
	return result

func _shot(row: Dictionary, state: String, sample: Dictionary) -> bool:
	var before: int = Time.get_ticks_msec()
	var path: String = r.shot(String(row.label) + "_" + state)
	var record := {"path": path, "state": state, "sample": sample,
		"capture_cost_ms": Time.get_ticks_msec() - before, "exists": FileAccess.file_exists(path)}
	row.captures.append(record); originals.append(record)
	return bool(record.exists)

func _camera_policy() -> Dictionary:
	return {"smoothing": g.camera.position_smoothing_enabled, "smoothing_speed": g.camera.position_smoothing_speed,
		"framing": g.settings.get("combat_framing", true), "lead": g.settings.get("camera_lead", 1.0),
		"shake": g.settings.get("camera_shake", 1.0)}

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

func _release() -> void:
	if held != 0: _key(held, false)
	held = 0

func _check(id: String, passed: bool, actual: Variant) -> bool:
	checks.append({"id": id, "passed": passed, "actual": actual})
	return passed

func _v(value: Vector2) -> Array: return [value.x, value.y]
func _rect(value: Rect2) -> Array: return [value.position.x, value.position.y, value.size.x, value.size.y]
