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
var arrival_failures: Array = []
var arrival_controls: Array = []
var arrival_boot: Dictionary = {}
var world_prompt: Dictionary = {}

static func run(rig: ShotRig) -> String:
	var q := new()
	q.r = rig
	rig.add_child(q)
	var error: String = await q._run()
	if error == "" and rig.flag("arrival-readability"):
		if rig.flag("arrival-rebuild-controls"): await q._arrival_default_control()
		if rig.flag("arrival-ownership-controls"): await q._arrival_ownership_controls()
		if not q.arrival_failures.is_empty(): error = "Arrival readability findings; inspect named strict rows"
	q._release()
	if is_instance_valid(q.p): q.p.clear_local_intents()
	q._check("runtime.completed", error == "", error)
	var receipt := {"rig": "shortcuts --corridor-camera", "complete": error == "",
		"horizontal": rig.flag("corridor-horizontal"), "lazy_build": rig.flag("corridor-lazy"), "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"hot_arrival": rig.flag("corridor-hot"), "planned_walks": 1 if rig.flag("corridor-hot") else 4,
		"camera_accepted": false, "navigation_complete": q.walks.size() == (1 if rig.flag("corridor-hot") else 4) and q.walks.all(func(w: Dictionary) -> bool: return bool(w.get("reached", false)) and w.get("error", "") == ""),
		"error": error, "selection": q.selected,
		"arrival_readability": rig.flag("arrival-readability"), "arrival_ownership": rig.flag("arrival-ownership-controls"), "arrival_failures": q.arrival_failures,
		"arrival_controls": q.arrival_controls, "arrival_boot": q.arrival_boot,
		"arrival_scope": "Optional per-render live-entry observations. Default-entry control erases only current cleared-room visited metadata, calls ordinary one-argument _enter_room and restores visited after passive settling. The default-entry control refills the ordinary room potion budget and is not a boot/load substitute. A separate passive real boot observation is recorded here; actual load observations are in the optional solo-controls receipt. No guest/pocket claim. No title/overlay writes during walks. Optional ownership controls run only after every walk completes and make deliberate production HUD calls; each arrival_controls row carries its own scope.",
		"checks": q.checks, "walks": q.walks, "originals": q.originals, "world_prompt": q.world_prompt,
		"initial_camera": q.camera_defaults, "cleanup": {"key_released": q.held == 0,
		"no_signal_observer_installed": not RenderingServer.frame_post_draw.is_connected(q._arrival_boot_frame), "disposable_world_not_restored": true},
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
	if r.flag("world-prompt-probe") and (not r.flag("corridor-hot") or not r.flag("corridor-camera")
			or r.flag("corridor-lazy") or r.flag("corridor-horizontal")
			or r.flag("arrival-rebuild-controls") or r.flag("arrival-ownership-controls")):
		return "world-prompt-probe requires hot south corridor mode without lazy/rebuild/ownership controls"
	if r.flag("arrival-readability") and not (r.flag("corridor-hot") or r.flag("corridor-lazy")):
		return "arrival-readability requires hot or lazy corridor mode"
	if r.flag("arrival-rebuild-controls") and (not r.flag("arrival-readability") or r.flag("corridor-hot")):
		return "rebuild control requires arrival-readability with cleared lazy mode"
	if r.flag("arrival-ownership-controls") and (not r.flag("arrival-readability") or not r.flag("corridor-lazy") or r.flag("corridor-hot")):
		return "ownership controls require arrival-readability with cleared lazy mode"
	var home: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not home.contains("/build/qa/session-sept20/claude-shortcuts/") or r.flag("no-capture"):
		return "isolated shortcut QA profile and native captures required"
	selected = _select()
	if selected.is_empty(): return "no qualifying first seed in 1000..1199"
	if r.flag("arrival-readability"): RenderingServer.frame_post_draw.connect(_arrival_boot_frame)
	await r.boot("warrior", "ch1", false)
	g = r.game; p = g.local_player
	var boot_ready: bool = await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0)
	if r.flag("arrival-readability"):
		# The intro completion is deferred beyond ShotRig.boot's return.
		# Keep the passive observer attached through the first playable draw.
		if boot_ready: await RenderingServer.frame_post_draw
		RenderingServer.frame_post_draw.disconnect(_arrival_boot_frame)
		_arrival_check("arrival.boot_observed", not arrival_boot.is_empty(), arrival_boot)
	if not boot_ready:
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
	if r.flag("world-prompt-probe"):
		var prompt_error: String = await _world_prompt_probe()
		if prompt_error != "": return prompt_error
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
	if r.flag("arrival-readability"):
		var source_clear: bool = await r._until(func() -> bool: return (g.hud.title_label.modulate.a == 0.0
			and g.hud.subtitle_label.modulate.a == 0.0 and g.hud.overlay.color.a == 0.0), 8.0)
		_arrival_check(label + ".arrival_source_clear", source_clear, _arrival_presentation())
		if not source_clear: return label + ": source presentation did not fully settle"
	var row: Dictionary = {"label": label, "source": source, "destination": destination, "direction": direction,
		"source_play_rect": _rect(g.play_rect(source)), "destination_play_rect": _rect(g.play_rect(destination)),
		"mouth": _v(mouth), "far_mouth": _v(far_mouth), "cell_boundary": _v(g.door_pos(source, direction)),
		"start": _v(start), "finish": _v(finish), "midpoint": _v(mid), "samples": [], "captures": [],
		"fully_outside_frames": 0, "partially_clipped_frames": 0, "max_offscreen_observed_ms": 0,
		"min_signed_margin": 1000000.0, "error": ""}
	walks.append(row)
	if r.flag("arrival-readability"):
		row["arrival"] = {"first_visit": not bool(g.visited.get(destination, false)),
			"world_id": g.world.get_instance_id(), "entry": {}, "max_overlay": 0.0,
			"title_peak": 0.0, "title_seen": false, "expected_title": String(g.zones[destination]["name"])}
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
		if r.flag("arrival-readability"):
			_arrival_observe(row.arrival, sample)
			if row.arrival.entry.is_empty() and int(sample.cur_room) == destination:
				row.arrival.entry = sample.duplicate(true)
				if not _shot(row, "first_entry", sample): row.error = "first entry capture missing"; break
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
	if r.flag("arrival-readability"): _arrival_observe(row.arrival, _sample(Time.get_ticks_msec() - started))
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
	if r.flag("arrival-readability"): _arrival_finalize(row)
	return "" if row.error == "" else label + ": " + String(row.error)

func _sample(elapsed: int) -> Dictionary:
	var body: Rect2 = Bounds.body_rect(p)
	var viewport: Rect2 = g.get_viewport_rect()
	var intersection: Rect2 = body.intersection(viewport)
	var area: float = maxf(0.0, body.size.x) * maxf(0.0, body.size.y)
	var ratio: float = intersection.get_area() / area if area > 0.0 else 0.0
	var margins: Array = [body.position.x - viewport.position.x, body.position.y - viewport.position.y,
		viewport.end.x - body.end.x, viewport.end.y - body.end.y]
	var sample: Dictionary = {"t_ms": elapsed, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
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
	if r.flag("arrival-readability"): sample["presentation"] = _arrival_presentation()
	return sample

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


func _arrival_presentation() -> Dictionary:
	return {"overlay_alpha": g.hud.overlay.color.a,
		"title": g.hud.title_label.text, "title_alpha": g.hud.title_label.modulate.a,
		"title_visible": g.hud.title_label.is_visible_in_tree(), "title_position": _v(g.hud.title_label.position),
		"subtitle": g.hud.subtitle_label.text, "subtitle_alpha": g.hud.subtitle_label.modulate.a,
		"subtitle_visible": g.hud.subtitle_label.is_visible_in_tree(), "subtitle_position": _v(g.hud.subtitle_label.position),
		"world_id": g.world.get_instance_id(), "room": g.cur_room,
		"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames()}

func _arrival_observe(arrival: Dictionary, sample: Dictionary) -> void:
	var view: Dictionary = sample.presentation
	arrival.max_overlay = maxf(float(arrival.max_overlay), float(view.overlay_alpha))
	if bool(view.title_visible):
		arrival.title_peak = maxf(float(arrival.title_peak), float(view.title_alpha))
		if float(view.title_alpha) > 0.01 and String(view.title) == String(arrival.expected_title):
			arrival.title_seen = true

func _arrival_check(id: String, passed: bool, actual: Variant) -> void:
	_check(id, passed, actual)
	if not passed: arrival_failures.append(id)

func _arrival_finalize(row: Dictionary) -> void:
	var a: Dictionary = row.arrival
	var entry: Dictionary = a.entry
	var id: String = String(row.label)
	_arrival_check(id + ".arrival_entry", not entry.is_empty() and bool(entry.get("native_key_held", false))
		and int(entry.get("cur_room", -1)) == int(row.destination)
		and int(entry.get("presentation", {}).get("world_id", -1)) == int(a.world_id), entry)
	# Compare in Color's storage precision, the same representation as the overlay;
	# this is not an epsilon around the existing dip policy.
	var dip_bound: float = Color(0, 0, 0, Balance.ROOM_DIP_A).a
	_arrival_check(id + ".arrival_no_blackout", float(a.max_overlay) <= dip_bound,
		{"first_visit": a.first_visit, "max_overlay": a.max_overlay, "dip_bound": dip_bound})
	_arrival_check(id + ".arrival_title", bool(a.title_seen) if bool(a.first_visit) else float(a.title_peak) <= 0.01,
		{"first_visit": a.first_visit, "title_seen": a.title_seen, "title_peak": a.title_peak, "expected_title": a.expected_title})

func _arrival_default_control() -> void:
	# Cleared lazy fixture only; no enemy/pawn/overlay loans and no live-entry API substitution.
	var zi: int = g.cur_room
	var ready: bool = bool(g.cleared.get(zi, false)) and not g._room_hot(zi) and g.hud.overlay.color.a == 0.0
	_arrival_check("arrival.default_setup", ready, {"room": zi, "cleared": g.cleared.get(zi), "hot": g._room_hot(zi)})
	if not ready: return
	var had_visited: bool = g.visited.has(zi)
	var visited_before: Variant = g.visited.get(zi)
	g.visited.erase(zi)
	g._enter_room(zi)
	var synchronous: Dictionary = _arrival_presentation()
	_arrival_check("arrival.default_full_fade", float(synchronous.overlay_alpha) == 1.0
		and String(synchronous.title) == String(g.zones[zi]["name"]), synchronous)
	await RenderingServer.frame_post_draw
	var early: Dictionary = _arrival_presentation()
	var row: Dictionary = {"label": "default_entry", "captures": []}
	_arrival_check("arrival.default_original", _shot(row, "early", early), early)
	await r.get_tree().create_timer(0.25).timeout
	var later: Dictionary = _arrival_presentation()
	_arrival_check("arrival.default_interpolation", float(later.overlay_alpha) < float(synchronous.overlay_alpha)
		and float(later.overlay_alpha) >= 0.0 and float(later.title_alpha) > 0.01, later)
	var settled: bool = await r._until(func() -> bool: return (g.hud.title_label.modulate.a <= 0.01
		and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a == 0.0), 8.0)
	if had_visited: g.visited[zi] = visited_before
	else: g.visited.erase(zi)
	_arrival_check("arrival.default_settled", settled, _arrival_presentation())
	_arrival_check("arrival.default_visited_restored", g.visited.has(zi) == had_visited
		and g.visited.get(zi) == visited_before, {"before": visited_before, "after": g.visited.get(zi)})
	arrival_controls.append({"synchronous": synchronous, "early": early, "later": later,
		"scope": "One-argument current-room entry with visited erase/restoration. Does not establish boot/load/online behavior."})


func _arrival_boot_frame() -> void:
	# Passive observer around the unchanged ShotRig.boot/real intro callback.
	# No captured world/hero: boot can replace the current world synchronously.
	if not arrival_boot.is_empty() or not is_instance_valid(r.game) or not r.game.play_started: return
	g = r.game
	arrival_boot = _arrival_presentation()
	arrival_boot["expected_title"] = String(g.zones[g.cur_room]["name"])
	arrival_boot["expected_subtitle"] = String(Story.chapter(g.chapter_id)["name"])
	arrival_boot["scope"] = "First post-draw observed after real initial intro callback; not synchronous alpha=1 or tween duration proof."
	_arrival_check("arrival.boot_full_fade", float(arrival_boot.overlay_alpha) > Color(0, 0, 0, Balance.ROOM_DIP_A).a
		and String(arrival_boot.title) == String(arrival_boot.expected_title)
		and String(arrival_boot.subtitle) == String(arrival_boot.expected_subtitle), arrival_boot)
	var row: Dictionary = {"label": "boot", "captures": []}
	_arrival_check("arrival.boot_original", _shot(row, "first_render", arrival_boot), arrival_boot)


## Ownership controls: deliberately controlled production HUD calls that pit a
## previous shared-title/overlay owner against a replacing owner. Presentation
## ownership only: no cleared/zone_alive writes, no spawn/HP/god/camera
## mutation, and NOT native movement, real death or end-game proof - the
## preceding native walks are the movement evidence. Bounded independent
## checks; a failed settle between controls stops further controls after its
## strict row is recorded, with no metadata left mutated.
func _arrival_ownership_controls() -> void:
	if not await _ownership_settled("ownership.baseline_settled"): return
	await _ownership_live_entry()
	if not await _ownership_settled("ownership.live_entry_settled"): return
	await _ownership_boss_replace()
	if not await _ownership_settled("ownership.boss_replace_settled"): return
	await _ownership_end_screen()
	if not await _ownership_settled("ownership.end_screen_settled"): return
	await _ownership_death_dim()


func _ownership_settled(id: String) -> bool:
	# Storage-exact endpoints: every production owner tweens or stamps these
	# exact final values, so no tolerance is applied at settle.
	var settled: bool = await r._until(func() -> bool: return (g.hud.title_label.modulate.a == 0.0
		and g.hud.subtitle_label.modulate.a == 0.0 and g.hud.overlay.color.a == 0.0), 8.0)
	_arrival_check(id, settled, _arrival_presentation())
	return settled


## Control 1: a short previous card owns a genuine full fade; an immediate
## live first-visit entry must take the shared labels without cutting that
## owned overlay fade short. Erases ONLY the current cleared room's visited
## metadata and restores it synchronously right after the entry call (no
## failure path can escape the restore); built is never erased, and the live
## entry refills the ordinary room potion budget on this disposable cleared
## QA fixture. World identity is asserted unchanged.
func _ownership_live_entry() -> void:
	var zi: int = g.cur_room
	var ready: bool = bool(g.cleared.get(zi, false)) and not g._room_hot(zi)
	_arrival_check("ownership.live_entry_setup", ready, {"room": zi, "cleared": g.cleared.get(zi), "hot": g._room_hot(zi)})
	if not ready: return
	var expected_title: String = String(g.zones[zi]["name"])
	var world_before: int = g.world.get_instance_id()
	var had_visited: bool = g.visited.has(zi)
	var visited_before: Variant = g.visited.get(zi)
	g.visited.erase(zi)
	g.hud.flash_title("PREVIOUS ARRIVAL", "", 0.05)
	var started: int = Time.get_ticks_msec()
	var held_deadline: SceneTreeTimer = r.get_tree().create_timer(1.5)
	var fade_deadline: SceneTreeTimer = r.get_tree().create_timer(2.0)
	g._enter_room(zi, true)
	var synchronous: Dictionary = _arrival_presentation()
	if had_visited: g.visited[zi] = visited_before
	else: g.visited.erase(zi)
	_arrival_check("ownership.live_entry_visited_restored", g.visited.has(zi) == had_visited
		and g.visited.get(zi) == visited_before, {"had": had_visited, "before": visited_before, "after": g.visited.get(zi)})
	_arrival_check("ownership.live_entry_synchronous", float(synchronous.overlay_alpha) == 1.0
		and String(synchronous.title) == expected_title, synchronous)
	var row: Dictionary = {"label": "ownership_live_entry", "captures": []}
	await RenderingServer.frame_post_draw
	var first: Dictionary = _arrival_presentation()
	_arrival_check("ownership.live_entry_owned_fade_original", _shot(row, "owned_fade", first), first)
	# Passive per-render observation only; the fade alpha is never written to.
	var fade_samples: Array = [{"t_ms": Time.get_ticks_msec() - started, "overlay_alpha": float(first.overlay_alpha)}]
	var monotone: bool = true
	var completed: bool = false
	var previous: float = float(first.overlay_alpha)
	while fade_deadline.time_left > 0.0:
		await RenderingServer.frame_post_draw
		var alpha: float = g.hud.overlay.color.a
		fade_samples.append({"t_ms": Time.get_ticks_msec() - started, "overlay_alpha": alpha})
		if alpha > previous: monotone = false
		previous = alpha
		if alpha == 0.0:
			completed = true
			break
	_arrival_check("ownership.live_entry_owned_fade", monotone and completed,
		{"monotone": monotone, "completed": completed, "samples": fade_samples.size(), "last_alpha": previous})
	# The replaced short card would have finished leaving by ~1.32s; the live
	# room card holds TITLE_HOLD and is still fully up at 1.5s. Transform and
	# text together catch old-tween interference, not just a text swap.
	# Use the scene clock that drives the tweens; PNG conversion can stall the
	# main thread and wall time alone would test the replacement too early.
	if held_deadline.time_left > 0.0: await held_deadline.timeout
	var held_card: Dictionary = _arrival_presentation()
	# Animated Vector2 components can retain float residue (e.g. 199.99905
	# for a 200px rest position). Use the engine's float comparison for the
	# transform only; title opacity and identity remain exact.
	_arrival_check("ownership.live_entry_card_held", float(held_card.title_alpha) == 1.0
		and String(held_card.title) == expected_title
		and is_equal_approx(float(held_card.title_position[1]), g.hud.TITLE_REST_Y)
		and g.hud.title_label.scale == Vector2.ONE
		and int(held_card.world_id) == world_before, held_card)
	_arrival_check("ownership.live_entry_card_original", _shot(row, "held_card", held_card), held_card)
	arrival_controls.append({"control": "live_entry_ownership", "room": zi,
		"before": synchronous, "after": held_card, "fade_samples": fade_samples, "captures": row.captures,
		"scope": "Deliberate full-fade flash_title immediately replaced by live _enter_room on the current cleared room; only visited metadata was erased and synchronously restored. Entry refills the ordinary room potion budget on this disposable cleared fixture; no world rebuild. Shared-label/overlay ownership only; alpha alone does not establish pixel brightness - captures are reviewed separately."})


## Control 2: a boss banner owns the shared title with its own scale/fade
## tween; an immediate live room_title must take the labels and hold them,
## and the retired banner tween must not fade or rescale the replacement.
func _ownership_boss_replace() -> void:
	var zi: int = g.cur_room
	var expected_title: String = String(g.zones[zi]["name"])
	g.hud.boss_banner("CONTROL BOSS")
	var held_deadline: SceneTreeTimer = r.get_tree().create_timer(1.9)
	g.hud.room_title(expected_title)
	var synchronous: Dictionary = _arrival_presentation()
	var row: Dictionary = {"label": "ownership_boss_replace", "captures": []}
	await r.get_tree().create_timer(0.9).timeout
	var resting: Dictionary = _arrival_presentation()
	_arrival_check("ownership.boss_replace_resting", float(resting.title_alpha) == 1.0
		and String(resting.title) == expected_title
		and is_equal_approx(float(resting.title_position[1]), g.hud.TITLE_REST_Y)
		and g.hud.title_label.scale == Vector2.ONE, resting)
	# The replaced banner would already be leaving by ~1.64s; the live card
	# holds TITLE_HOLD and must still be fully up at ~1.9s.
	if held_deadline.time_left > 0.0: await held_deadline.timeout
	var held_card: Dictionary = _arrival_presentation()
	_arrival_check("ownership.boss_replace_card_held", float(held_card.title_alpha) == 1.0
		and String(held_card.title) == expected_title, held_card)
	_arrival_check("ownership.boss_replace_original", _shot(row, "held_card", held_card), held_card)
	var overlay_settled: bool = await r._until(func() -> bool: return g.hud.overlay.color.a == 0.0, 8.0)
	_arrival_check("ownership.boss_replace_overlay_settled", overlay_settled, _arrival_presentation())
	arrival_controls.append({"control": "boss_banner_replaced_by_room_title", "room": zi,
		"before": synchronous, "resting": resting, "after": held_card, "captures": row.captures,
		"scope": "Deliberate boss_banner immediately replaced by the new room_title production API using the real current room name. Shared-label ownership only; no boss fight, combat or campaign claim."})


## Control 3: show_end_screen is terminal presentation; an in-flight short
## card and its owned overlay fade must not later fade the end labels or
## erase the stamped end dim.
func _ownership_end_screen() -> void:
	g.hud.flash_title("OLD CARD", "", 0.05)
	g.hud.show_end_screen("CONTROL END", "Controlled presentation", Color.GOLD)
	var synchronous: Dictionary = _arrival_presentation()
	var end_alpha: float = Color(0, 0, 0, 0.75).a
	var row: Dictionary = {"label": "ownership_end_screen", "captures": []}
	await r.get_tree().create_timer(1.5).timeout
	var held: Dictionary = _arrival_presentation()
	_arrival_check("ownership.end_screen_held", float(held.title_alpha) == 1.0
		and float(held.subtitle_alpha) == 1.0
		and String(held.title) == "CONTROL END" and String(held.subtitle) == "Controlled presentation"
		and float(held.title_position[1]) == g.hud.TITLE_REST_Y
		and float(held.subtitle_position[1]) == g.hud.SUBTITLE_REST_Y
		and g.hud.title_label.scale == Vector2.ONE
		and g.hud.overlay.color.a == end_alpha, held)
	_arrival_check("ownership.end_screen_original", _shot(row, "held_end", held), held)
	# Production reset only; text identity is deliberately not asserted here.
	g.hud.dim(0.0)
	g.hud.flash_title("", "", 0.0, false)
	var cleared_after: bool = await r._until(func() -> bool: return (g.hud.title_label.modulate.a == 0.0
		and g.hud.subtitle_label.modulate.a == 0.0 and g.hud.overlay.color.a == 0.0), 8.0)
	_arrival_check("ownership.end_screen_cleared", cleared_after, _arrival_presentation())
	arrival_controls.append({"control": "end_screen_ownership",
		"before": synchronous, "after": held, "end_overlay_alpha": end_alpha, "captures": row.captures,
		"scope": "Deliberate short flash_title immediately replaced by show_end_screen, then cleared through production dim(0.0) and an empty no-overlay flash_title. Controlled presentation only; not a real victory or defeat flow claim."})


## Control 4: explicit controlled HUD calls for the death beat - NOT an
## actual death. An arrival full fade must yield the overlay to death_dim's
## ramp, dim(0.0) must clear it durably, and dim(0.0) must also cancel a
## ramp mid-flight so no retired tween re-dims afterwards.
func _ownership_death_dim() -> void:
	var target_alpha: float = Color(0, 0, 0, Balance.DEATH_DIM).a
	g.hud.flash_title("PRE-DEATH ARRIVAL", "", 0.05)
	g.hud.death_dim(Balance.DEATH_DIM, Balance.DEATH_DIM_RAMP)
	g.hud.flash_title("YOU DIED", "Controlled presentation", 1.4, false)
	var synchronous: Dictionary = _arrival_presentation()
	var row: Dictionary = {"label": "ownership_death_dim", "captures": []}
	await r.get_tree().create_timer(maxf(float(Balance.DEATH_DIM_RAMP), 0.55) + 0.3).timeout
	var dimmed: Dictionary = _arrival_presentation()
	_arrival_check("ownership.death_dim_target", g.hud.overlay.color.a == target_alpha,
		{"target": target_alpha, "presentation": dimmed})
	_arrival_check("ownership.death_dim_original", _shot(row, "death_dim", dimmed), dimmed)
	g.hud.dim(0.0)
	await r.get_tree().create_timer(0.6).timeout
	var after_clear: Dictionary = _arrival_presentation()
	_arrival_check("ownership.death_dim_cleared", g.hud.overlay.color.a == 0.0, after_clear)
	g.hud.death_dim(Balance.DEATH_DIM, Balance.DEATH_DIM_RAMP)
	g.hud.dim(0.0)
	await r.get_tree().create_timer(float(Balance.DEATH_DIM_RAMP) + 0.1).timeout
	var cancelled: Dictionary = _arrival_presentation()
	_arrival_check("ownership.death_dim_cancelled", g.hud.overlay.color.a == 0.0, cancelled)
	var settled: bool = await _ownership_settled("ownership.death_dim_final_settled")
	arrival_controls.append({"control": "death_dim_ownership", "settled": settled,
		"before": synchronous, "dimmed": dimmed, "after_clear": after_clear, "cancelled": cancelled,
		"death_target_alpha": target_alpha, "captures": row.captures,
		"scope": "Explicit controlled flash_title/death_dim/dim calls; not an actual death, respawn, game_flow reset or end-game claim."})


func _world_prompt_probe() -> String:
	# Original hot-room chest only. No spawn, pose, timer, actor or HUD writes.
	world_prompt = {"complete": false, "error": "", "failures": 0, "views": [], "input": {},
		"sources": {"helper": FileAccess.get_sha256("res://scripts/tests/shortcut_corridor_live.gd"),
			"game": FileAccess.get_sha256("res://scripts/game.gd"), "factory": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"alpha": FileAccess.get_sha256("res://scripts/tests/npc_prompt_live.gd"),
			"text": FileAccess.get_sha256("res://scripts/tests/capital_arrival_live.gd")},
		"scope": "Original selected live cursed chest after controlled hot-S corridor arrival. Native one-edge interact and real Cancel. No respawn/reroll/lifespan loan, no healing or actor pose. Alpha bounds include carried art; text cells are shaped bounds. No physical-device, ordinary campaign or universal HUD-clearance claim."}
	_release()
	var selection: Dictionary = _world_prompt_selection()
	world_prompt["selection"] = selection.observation
	var entry: Dictionary = selection.entry
	if not bool(selection.valid): return _world_prompt_end("incomplete: original live chest is not the selected nearest entry")
	var node: Node2D = entry.node
	var label: Label = entry.prompt
	var sprite: Sprite2D = entry.sprite
	var action: Callable = entry.action
	var reach: float = float(entry.get("reach", Balance.INTERACT_RANGE))
	var style: Dictionary = _world_prompt_style(label)
	var paint = preload("res://scripts/tests/npc_prompt_live.gd").new()
	var text_measure = preload("res://scripts/tests/capital_arrival_live.gd").new()
	var shape: Dictionary = text_measure._fountain_text(label)
	var full := Rect2(Vector2(shape.outer.position[0], shape.outer.position[1]), Vector2(shape.outer.size[0], shape.outer.size[1]))
	var hero: Rect2 = paint._painted(p.sprite)
	var body: Rect2 = paint._painted(sprite)
	var hud_hits: Array = _hud_intersections(full)
	var supplemental: Dictionary = {"boss": g.hud.boss_box, "mob": g.hud.mob_box, "rival": g.hud.rival_box,
		"wayfinder": g.hud.wayfinder.quest_root, "target_cue": g.hud.combat_feedback.target_cue}
	for slot in g.hud.party_slots: supplemental["party_" + str(slot.root.get_instance_id())] = slot.root
	for key in supplemental:
		var control: Control = supplemental[key] as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		var bounds: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		if bounds.has_area() and full.intersects(bounds): hud_hits.append({"name": key, "rect": _rect(bounds)})
	var view := {"prompt": shape, "hero": _rect(hero), "chest": _rect(body), "hud_hits": hud_hits,
		"viewport": _rect(g.get_viewport_rect()), "position": _v(label.position),
		"has_npc_anchor": label.has_meta("npc_prompt_anchor"),
		"npc_anchor": _v(label.get_meta("npc_prompt_anchor")) if label.has_meta("npc_prompt_anchor") else [],
		"node_id": node.get_instance_id(), "prompt_id": label.get_instance_id(), "style": style,
		"authored": String(label.get_meta("interaction_authored_copy", "")), "timer_left": selection.observation.timer_left}
	world_prompt.views.append(view)
	_world_prompt_check("painted_bodies", hero.has_area() and body.has_area(), view)
	_world_prompt_check("complete_copy", bool(shape.complete) and float(shape.alpha) >= 0.99
		and label.text == g.interaction_copy("E — The chest whispers") and label.z_index == Balance.INTERACT_PROMPT_Z, shape)
	_world_prompt_check("hero_clear", hero.has_area() and not full.intersects(hero), view)
	_world_prompt_check("chest_clear", body.has_area() and not full.intersects(body), view)
	_world_prompt_check("viewport", g.get_viewport_rect().encloses(full), view)
	_world_prompt_check("hud_clear", hud_hits.is_empty(), hud_hits)
	_world_prompt_capture("world_prompt_selected")
	# Clearance findings remain strict, but do not prevent an independent action proof.
	var cooldown_ready: bool = await r._until(func() -> bool: return g.talk_cd <= 0.0, 1.0)
	selection = _world_prompt_selection()
	world_prompt["before_key_selection"] = selection.observation
	if not cooldown_ready or not bool(selection.valid) or selection.entry.get("node") != node:
		return _world_prompt_end("incomplete: chest expired or selection changed before the single interaction edge")
	var code: int = int(g.binds.get("interact", KEY_E))
	if not _world_prompt_check("input_ready", not Input.is_key_pressed(code) and p.is_physics_processing()
		and g.can_process() and not g.input_overlay_up() and not r.get_tree().paused
		and not p.dead and not p.downed and not p.ghost, {"code": code, "talk_cd": g.talk_cd}):
		return _world_prompt_end("incomplete: native interaction preconditions failed")
	var before: Dictionary = _world_prompt_economy()
	world_prompt["before"] = before
	var input := {"code": code, "process_start": Engine.get_process_frames(), "physics_start": Engine.get_physics_frames()}
	held = code; _key(code, true)
	await r.frames(2)
	input["held_after_process"] = Input.is_key_pressed(code)
	await r.get_tree().physics_frame
	await r.get_tree().physics_frame
	input["held_before_release"] = Input.is_key_pressed(code)
	input["process_steps"] = Engine.get_process_frames() - int(input.process_start)
	input["physics_steps"] = Engine.get_physics_frames() - int(input.physics_start)
	_release()
	input["released"] = not Input.is_key_pressed(code)
	world_prompt.input = input
	_world_prompt_check("single_edge_held", bool(input.held_after_process) and bool(input.held_before_release)
		and int(input.process_steps) >= 2 and int(input.physics_steps) >= 2 and bool(input.released), input)
	await r.frames(2)
	var opened: bool = g.menus.current == "confirm" and is_instance_valid(g.menus.root)
	if not _world_prompt_check("confirm_opened", opened, g.menus.current):
		return _world_prompt_end("native interaction did not open confirmation")
	var message := "The chest whispers promises. Open it, and every monster in this room grows CRUELER (+%d%% damage, faster) until the room is purged — but the purge unlocks its hoard: a golden chest and a gem, guaranteed. Open it?" % int((Balance.CURSE_DMG_MULT - 1.0) * 100)
	_world_prompt_check("confirm_message", _world_prompt_find(g.menus.root, message, false) != null, message)
	await RenderingServer.frame_post_draw
	_world_prompt_capture("world_prompt_confirmation")
	var cancel: Button = _world_prompt_find(g.menus.root, "Cancel", true) as Button
	if cancel == null:
		await _world_prompt_cancel_cleanup()
		return _world_prompt_end("visible enabled Cancel button missing")
	_world_prompt_click(cancel.get_global_rect().get_center())
	await r.frames(2)
	var closed: bool = not g.menus.is_open() and not r.get_tree().paused
	_world_prompt_check("cancel_closed", closed, {"menu": g.menus.current, "paused": r.get_tree().paused})
	if not closed:
		await _world_prompt_cancel_cleanup()
		return _world_prompt_end("native Cancel did not close confirmation")
	var after: Dictionary = _world_prompt_economy()
	world_prompt["after"] = after
	_world_prompt_check("cancel_no_transaction", before == after, {"before": before, "after": after})
	# The ordinary offer timer resumes with Cancel. A genuine expiry is incomplete,
	# never rewritten into a passing action check or blamed on the cancel callback.
	selection = _world_prompt_selection()
	world_prompt["after_cancel_selection"] = selection.observation
	if not bool(selection.valid) or selection.entry.get("node") != node:
		return _world_prompt_end("incomplete: original chest expired or selection changed after Cancel")
	_world_prompt_check("identity_reach_action_style", selection.entry.prompt == label and selection.entry.action == action
		and float(selection.entry.get("reach", Balance.INTERACT_RANGE)) == reach
		and _world_prompt_style(label) == style, selection.observation)
	await RenderingServer.frame_post_draw
	_world_prompt_capture("world_prompt_after_cancel")
	return _world_prompt_end("")


func _world_prompt_selection() -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var rows: Array = []
	var visible := 0
	for candidate in g.interactables:
		var node: Node2D = candidate.get("node") as Node2D
		var label: Label = candidate.get("prompt") as Label
		if not is_instance_valid(node) or not is_instance_valid(label): continue
		var current: bool = is_instance_valid(g.world) and g.world.is_ancestor_of(node) and not node.is_queued_for_deletion()
		var distance: float = p.global_position.distance_to(node.global_position)
		var reach: float = float(candidate.get("reach", Balance.INTERACT_RANGE))
		if label.is_visible_in_tree(): visible += 1
		rows.append({"node_id": node.get_instance_id(), "prompt_id": label.get_instance_id(), "distance": distance,
			"reach": reach, "eligible": distance < reach, "current_world": current,
			"visible": label.is_visible_in_tree(), "text": label.text,
			"authored": String(label.get_meta("interaction_authored_copy", ""))})
		if distance < reach and distance < nearest_distance:
			nearest = candidate; nearest_distance = distance
	var left := -1.0
	var valid := false
	var winner_id := 0
	if not nearest.is_empty():
		var node: Node2D = nearest.node
		var label: Label = nearest.prompt
		winner_id = node.get_instance_id()
		for child in node.get_children():
			if child is Timer and not child.is_stopped(): left = child.time_left; break
		valid = left > 0.0 and visible == 1 and g.interact_in_range and not g.input_overlay_up()
		valid = valid and is_instance_valid(g.world) and g.world.is_ancestor_of(node) and not node.is_queued_for_deletion()
		valid = valid and label.is_visible_in_tree() and not label.is_queued_for_deletion()
		valid = valid and String(label.get_meta("interaction_authored_copy", "")) == "E — The chest whispers"
		valid = valid and String(nearest.get("sprite_name", "")) == String(Items.CHEST_TIERS.gold.sprite)
		valid = valid and is_instance_valid(nearest.get("sprite")) and nearest.sprite is Sprite2D
	return {"entry": nearest, "valid": valid, "observation": {"candidates": rows, "winner_id": winner_id,
		"visible_count": visible, "timer_left": left, "valid_original_chest": valid,
		"room": g.cur_room, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames()}}


func _world_prompt_style(label: Label) -> Dictionary:
	return {"size": _v(label.size), "font": label.get_theme_font("font").get_instance_id(),
		"font_size": label.get_theme_font_size("font_size"), "outline": label.get_theme_constant("outline_size"),
		"pill": label.get_theme_stylebox("normal").get_instance_id(), "z": label.z_index,
		"clip": label.clip_text, "ratio": label.visible_ratio, "lines": label.max_lines_visible,
		"text": label.text, "authored": String(label.get_meta("interaction_authored_copy", ""))}


func _world_prompt_economy() -> Dictionary:
	return {"gold": p.gold, "backpack": p.backpack.duplicate(true), "materials": p.materials.duplicate(true),
		"consumables": p.consumables.duplicate(true), "equipment": p.equipment.duplicate(true),
		"curse_flag": g.get_flag(g._curse_flag(g.cur_room), false), "curse_pending": g.curse_pending.duplicate(true)}


func _world_prompt_find(node: Node, text: String, button: bool) -> Control:
	if button and node is Button and node.is_visible_in_tree() and not node.disabled and node.text.strip_edges() == text: return node
	if not button and node is Label and node.is_visible_in_tree() and node.text == text: return node
	for child in node.get_children():
		var found: Control = _world_prompt_find(child, text, button)
		if found != null: return found
	return null


func _world_prompt_click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at
	Input.parse_input_event(move); Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at; event.global_position = at; event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()


func _world_prompt_cancel_cleanup() -> void:
	_release()
	if g.menus.current != "confirm": return
	held = KEY_ESCAPE; _key(held, true)
	await r.frames(2)
	_release()
	await r.frames(2)
	world_prompt["cleanup_confirm_closed"] = not g.menus.is_open()


func _world_prompt_capture(name: String) -> void:
	var path: String = r.shot(name)
	var record := {"path": path, "state": name, "exists": FileAccess.file_exists(path), "scope": "live cursed-chest prompt and native cancel probe"}
	originals.append(record)
	_world_prompt_check("capture." + name, bool(record.exists), record)


func _world_prompt_check(id: String, passed: bool, detail: Variant) -> bool:
	if not passed: world_prompt.failures = int(world_prompt.failures) + 1
	return _check("world_prompt." + id, passed, detail)


func _world_prompt_end(error: String) -> String:
	_release()
	world_prompt.error = error if error != "" else "World prompt strict findings; inspect native evidence" if int(world_prompt.failures) > 0 else ""
	world_prompt.complete = String(world_prompt.error) == ""
	_check("world_prompt.complete", bool(world_prompt.complete), world_prompt)
	return String(world_prompt.error)
