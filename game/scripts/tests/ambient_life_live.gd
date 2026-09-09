extends RefCounted
## Native-only isolated QA. Population probes use real Ambience and shadows;
## the independent legacy recipe pins full-room counts and placement RNG.
const EncounterUI := preload("res://scripts/ui/encounter_status.gd")
const SEEDS := [17, 41, 203]
const MOTION_TIMES := [0.0, 0.8, 1.6, 2.4, 3.2, 4.0]


static func run(r: Node) -> String:
	var g: Game = r.game
	var keep := {"settings": g.settings.duplicate(true), "time_scale": Engine.time_scale,
		"processing": g.is_processing(), "physics": g.player.is_physics_processing()}
	var report := {"baseline": r.flag("baseline"), "checks": 0, "failures": [], "findings": [],
		"cases": [], "views": [], "motion": [], "limits": "Controlled seeded world. Actors posed; population rebuilt through real Ambience.populate. No combat, rewards, input or physical-device coverage. Motion uses production tweens at time_scale 1; seeded homes are repeatable but motion phases are not identical between runs."}
	await _execute(r, report)
	g.set_process(bool(keep.processing))
	g.player.set_physics_process(bool(keep.physics))
	g.settings = keep.settings
	g.refresh_touch_mode()
	g._apply_touch_mode()
	Engine.time_scale = float(keep.time_scale)
	var path: String = r.shot_dir.path_join("ambient.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot write ambient native report"
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("AMBIENT QA: checks=%d failures=%d expected_findings=%d" % [report.checks, report.failures.size(), report.findings.size()])
	return "" if report.failures.is_empty() else str(report.failures[0])


static func _check(report: Dictionary, ok: bool, label: String, presentation := false) -> void:
	report.checks += 1
	if ok:
		return
	if presentation and bool(report.baseline):
		report.findings.append(label)
		print("AMBIENT BASELINE FINDING: " + label)
	else:
		report.failures.append(label)
		print("AMBIENT FAILURE: " + label)


static func _execute(r: Node, report: Dictionary) -> void:
	var g: Game = r.game
	Engine.time_scale = 1.0
	g.wander_seed = 17
	g.switch_chapter("ch1", true)
	await r.frames(4)
	await r.skip_dialogue()
	g.terrain_event_t = 10000.0
	g.settings["camera_shake"] = 0.0
	g.settings["combat_framing"] = false
	g.camera.position_smoothing_enabled = false
	g.player.set_physics_process(false)
	g.set_process(false) # fixture controls the camera; fauna keeps processing normally
	if r.flag("touch"):
		g.settings["touch_controls"] = true
		g.refresh_touch_mode()
		g._apply_touch_mode()
	var compact := -1
	var full := -1
	for i in g.zones.size():
		if str(g.zones[i].name) == "Village Outskirts": compact = i
		if str(g.zones[i].name) == "Emberfall Village": full = i
	_check(report, compact >= 0 and full >= 0, "actual compact and full village rooms exist")
	if compact < 0 or full < 0:
		return
	_check(report, g.no_saves and Engine.time_scale == 1.0, "isolated profile and real-time simulation")
	# A compact/full matrix over both affected biomes. Darkwood is an explicit
	# terrain-id override for the population-only probe, not an authored world.
	for terrain in ["village", "darkwood"]:
		for room in [compact, full]:
			for world_seed in SEEDS:
				_census(g, report, room, terrain, world_seed, room == compact)
	_boundary_controls(g, report, full)
	g.wander_seed = 17
	var panel: Control = EncounterUI.make(g.hud, "AmbientPopulationFixture", Color(0.96, 0.81, 0.48), true)
	(panel.get_node("Title") as Label).text = "AMBIENT POPULATION · QA"
	(panel.get_node("Hint") as Label).text = "Controlled view · No live encounter"
	for spec in [[compact, "compact"], [full, "full"]]:
		var room: int = spec[0]
		var label: String = spec[1]
		r.step("ambient " + label + " native view")
		g.player.global_position = g.room_center(room)
		g._enter_room(room)
		await r.skip_dialogue()
		g.terrain_event_t = 10000.0
		g.player.global_position = g.play_rect(room).get_center() + Vector2(-220, -60)
		# Game's per-frame presentation is suspended for this posed camera.
		# Keep its location label truthful, then let arrival/lighting settle.
		g.hud.set_zone(String(g.zones[room].name))
		_check(report, g.hud.zone_label.text == String(g.zones[room].name), "native room label matches posed location")
		g.camera.global_position = g.play_rect(room).get_center()
		g.camera.zoom = Vector2.ONE
		g.camera.force_update_scroll()
		_replace_room_fauna(g, room)
		var fauna := _room_fauna(g, room)
		(panel.get_node("Detail") as Label).text = "%s room · %d fauna · Seed 17" % [label.capitalize(), fauna.size()]
		await r.sim_wait(4.0)
		await RenderingServer.frame_post_draw
		var shot_path: String = r.shot(label + "_settled")
		report.views.append({"label": label, "image": shot_path, "room": room,
			"rect": str(g.play_rect(room)), "camera": str(g.camera.global_position),
			"geometry": _geometry(g, room), "fauna": _manifest(fauna)})
		if label == "compact":
			r.sim_reset()
			var begun := Time.get_ticks_msec()
			var first: Array = []
			var moved_kinds := {}
			for i in MOTION_TIMES.size():
				await r.sim_wait_until(float(MOTION_TIMES[i]))
				await RenderingServer.frame_post_draw
				var states := _motion(fauna)
				if i == 0: first = states.duplicate(true)
				else:
					for j in mini(first.size(), states.size()):
						if states[j].kind == first[j].kind and states[j].position != first[j].position:
							moved_kinds[String(states[j].kind)] = true
				var image_path: String = r.shot("compact_motion_%02d" % i)
				report.motion.append({"image": image_path, "nominal_seconds": MOTION_TIMES[i],
					"sim_seconds": r.sim_t, "wall_seconds": (Time.get_ticks_msec() - begun) / 1000.0,
					"time_scale": Engine.time_scale, "states": states})
			_check(report, _motion(fauna) != first, "production fauna actually moves/animates during four-second sequence")
			_check(report, bool(moved_kinds.get("bird", false)), "a production bird changes position during the sequence")
			_check(report, bool(moved_kinds.get("butterfly", false)), "a production butterfly changes position during the sequence")
			_check(report, Engine.time_scale == 1.0, "motion sequence remains at real-time speed")
	panel.queue_free()


static func _census(g: Game, report: Dictionary, room: int, terrain: String, world_seed: int, compact: bool) -> void:
	var old_terrain: String = g.terrain_by_zone[room]
	var old_seed := g.wander_seed
	g.terrain_by_zone[room] = terrain
	g.wander_seed = world_seed
	var legacy := _legacy_manifest(g.play_rect(room), room, world_seed)
	var first := Ambience.populate(g, room)
	var actual := _manifest(first)
	var shadow_count := 0
	var flit_count := 0
	for c in first:
		if c.mode == "flit":
			flit_count += 1
		for child in c.get_children():
			if child.has_meta("cast_shadow"): shadow_count += 1
		_check(report, c.spr.texture != null and c.spr.texture.resource_path.begins_with("res://assets/sprites/critter_"), "actual fauna uses installed strip: %s" % c.kind)
		var expected_scale := 0.3 if c.kind == "butterfly" else 0.31875
		_check(report, is_equal_approx(c.spr.scale.x, expected_scale), "fauna keeps authored render scale")
		if c.kind == "bird" and c.mode == "flit":
			_check(report, c.reactive and c._perch_tex != null, "bird keeps startle and forage strip")
			var water: Rect2 = (g.rivers[room]["rect"] as Rect2).grow(40.0) if g.rivers.has(room) else Rect2()
			_check(report, c.no_land == water, "bird retains real river exclusion")
			var expected_hazards := 0
			for hz in g.hazards:
				if hz.zone == room: expected_hazards += 1
			_check(report, c.no_land_circles.size() == expected_hazards, "bird retains real hazard exclusions")
	_check(report, shadow_count == flit_count, "every real flitting critter has exactly one cast shadow")
	if compact:
		_check(report, actual.size() <= 9 and actual.size() >= 6, "compact %s seed %d has 6–9 social fauna, found %d" % [terrain, world_seed, actual.size()], true)
		var birds := 0
		var butterflies := 0
		var sky := 0
		for c in actual:
			if c.mode == "soar": sky += 1
			elif c.kind == "bird": birds += 1
			elif c.kind == "butterfly": butterflies += 1
		_check(report, birds >= 2 and butterflies >= 2 and sky >= 2, "compact room retains social pairs in all three groups")
		for record in actual:
			_check(report, legacy.has(record), "retained fauna keeps original seeded home/sky assignment")
	else:
		_check(report, actual == legacy, "full %s seed %d exactly preserves legacy population and homes" % [terrain, world_seed])
	for c in first: c.free()
	var second := Ambience.populate(g, room)
	_check(report, _manifest(second) == actual, "repeated population is deterministic for same room/seed")
	for c in second: c.free()
	report.cases.append({"terrain": terrain, "room": room, "seed": world_seed,
		"controlled_terrain_override": terrain != old_terrain, "compact": compact,
		"rect": str(g.play_rect(room)), "legacy_count": legacy.size(), "actual_count": actual.size(),
		"shadow_count": shadow_count, "actual": actual, "legacy": legacy})
	g.terrain_by_zone[room] = old_terrain
	g.wander_seed = old_seed


## Boundary probes deliberately override one real room's scale and terrain.
## They are population controls, not claims about an authored darkwood/storm map.
static func _boundary_controls(g: Game, report: Dictionary, full: int) -> void:
	var combat := -1
	var smallest := 1.0
	var combat_floor := pow(1.0 - Balance.ROOM_SIZE_VAR, 2.0)
	for i in g.zones.size():
		if g.room_type(i) != "combat" or String(g.zones[i].get("boss", "")) != "" \
				or float(g.zones[i].get("room_scale", 1.0)) < 1.0:
			continue
		var area: float = g.play_rect(i).get_area() / g.room_rect(i).get_area()
		if area < smallest:
			combat = i
			smallest = area
	_check(report, combat >= 0 and smallest >= combat_floor - 0.0001,
		"actual ordinary combat area stays above its declared lower bound")
	if combat >= 0:
		_population_control(g, report, combat, "village", "actual ordinary combat geometry", false, false)
	var had_scale: bool = g.zones[full].has("room_scale")
	var old_scale: Variant = g.zones[full].get("room_scale", 1.0)
	# Bracket the policy boundary with a small explicit margin. Computing an
	# exact decimal .65 area through Vector2 float geometry is not an exact test.
	for terrain in ["village", "darkwood"]:
		for spec in [[0.649, true, "below compact boundary"], [0.651, false, "above compact boundary"],
				[combat_floor, false, "ordinary combat minimum"]]:
			g.zones[full]["room_scale"] = sqrt(float(spec[0]))
			var area: float = g.play_rect(full).get_area() / g.room_rect(full).get_area()
			_check(report, absf(area - float(spec[0])) < 0.0001, "controlled area reaches " + String(spec[2]))
			_population_control(g, report, full, terrain, String(spec[2]), bool(spec[1]), true)
	# A small non-target biome exercises the same soar helper while preserving
	# the independent legacy storm count and seeded assignments exactly.
	g.zones[full]["room_scale"] = 0.5
	_population_control(g, report, full, "storm", "unaffected biome at quarter area", false, true)
	if had_scale:
		g.zones[full]["room_scale"] = old_scale
	else:
		g.zones[full].erase("room_scale")


static func _population_control(g: Game, report: Dictionary, room: int, terrain: String,
		label: String, reduced: bool, controlled_scale: bool) -> void:
	var old_terrain: String = g.terrain_by_zone[room]
	var old_seed := g.wander_seed
	g.terrain_by_zone[room] = terrain
	g.wander_seed = 17
	var pr := g.play_rect(room)
	var legacy := _legacy_storm_manifest(pr, room, 17) if terrain == "storm" \
		else _legacy_manifest(pr, room, 17)
	var fauna := Ambience.populate(g, room)
	var actual := _manifest(fauna)
	if reduced:
		_check(report, actual.size() < legacy.size(), "%s %s actually reduces population" % [terrain, label], true)
		for record in actual:
			_check(report, legacy.has(record), "boundary reduction preserves retained seeded assignments")
		var groups := {}
		for record in actual:
			var key: String = String(record.kind) + "/" + String(record.mode)
			groups[key] = int(groups.get(key, 0)) + 1
		_check(report, int(groups.get("bird/flit", 0)) >= 2 and int(groups.get("bird/soar", 0)) >= 2
			and int(groups.get("butterfly/flit", 0)) >= 2, "boundary reduction retains social pairs")
	else:
		_check(report, actual == legacy, "%s %s preserves exact legacy population and assignments" % [terrain, label])
	for c in fauna: c.free()
	report.cases.append({"terrain": terrain, "room": room, "seed": 17, "control": label,
		"controlled_terrain_override": terrain != old_terrain, "controlled_room_scale": controlled_scale,
		"compact": reduced, "rect": str(pr), "area_fraction": pr.get_area() / g.room_rect(room).get_area(),
		"legacy_count": legacy.size(), "actual_count": actual.size(), "actual": actual, "legacy": legacy})
	g.terrain_by_zone[room] = old_terrain
	g.wander_seed = old_seed


static func _legacy_storm_manifest(pr: Rect2, room: int, world_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = room * 991 + world_seed
	var rows: Array = []
	var n := 3 + rng.randi_range(0, 3)
	var direction := 1 if rng.randf() < 0.5 else -1
	var band := pr.position.y + rng.randf_range(24.0, pr.size.y * 0.3)
	for i in n:
		rows.append(_record("bird", "soar", Vector2.ZERO, direction, band, float(i) * rng.randf_range(60.0, 110.0)))
	return rows


static func _record(kind: String, mode: String, home: Vector2, direction := 0, band := -1.0, offset := 0.0) -> Dictionary:
	return {"kind": kind, "mode": mode, "home": str(home), "heading": direction, "band": band, "offset": offset}


static func _legacy_manifest(pr: Rect2, room: int, world_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = room * 991 + world_seed
	var rows: Array = []
	_legacy_group(rows, rng, pr, "bird", 4, 7, 95.0)
	_legacy_group(rows, rng, pr, "butterfly", 3, 6, 80.0)
	var n := 2 + rng.randi_range(0, 2)
	var direction := 1 if rng.randf() < 0.5 else -1
	var band := pr.position.y + rng.randf_range(24.0, pr.size.y * 0.3)
	for i in n:
		rows.append(_record("bird", "soar", Vector2.ZERO, direction, band, float(i) * rng.randf_range(60.0, 110.0)))
	if rng.randf() < 0.4:
		_legacy_group(rows, rng, pr, "bird", 2, 3, 70.0)
	return rows


static func _legacy_group(rows: Array, rng: RandomNumberGenerator, pr: Rect2, kind: String, lo: int, hi: int, spread: float) -> void:
	var center := pr.position + Vector2(rng.randf_range(spread + 60.0, pr.size.x - spread - 60.0),
		rng.randf_range(spread + 60.0, pr.size.y - spread - 60.0))
	var n := rng.randi_range(lo, hi)
	for i in n:
		var home := center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		rows.append(_record(kind, "flit", home))


static func _manifest(nodes: Array) -> Array:
	var rows: Array = []
	for c in nodes:
		rows.append(_record(c.kind, c.mode, c.home, c.soar_dir, c.soar_y0, c.soar_x_off))
	return rows


static func _room_fauna(g: Game, room: int) -> Array:
	var result: Array = []
	for node in g.zone_scenery.get(room, []):
		if is_instance_valid(node) and node is Ambience.Critter:
			result.append(node)
	return result


static func _replace_room_fauna(g: Game, room: int) -> void:
	for node in _room_fauna(g, room):
		g.zone_scenery[room].erase(node)
		node.free()
	for node in Ambience.populate(g, room):
		g.zone_scenery[room].append(node)


static func _motion(nodes: Array) -> Array:
	var rows: Array = []
	for c in nodes:
		rows.append({"kind": c.kind, "mode": c.mode, "position": str(c.position),
			"frame": c.spr.frame, "grounded": c.grounded, "fled": c.fled})
	return rows


static func _geometry(g: Game, room: int) -> Array:
	var rows: Array = []
	for node in g.zone_scenery.get(room, []):
		if not is_instance_valid(node) or node is Ambience.Critter or not node is Node2D:
			continue
		rows.append({"type": node.get_class(), "position": str(node.global_position)})
	return rows
