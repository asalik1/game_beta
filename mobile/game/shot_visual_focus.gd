extends ShotRig
## Actual ch3 room composition baseline; setup teleports and frozen actor scripts.
## No enemies are removed, killed or cleared. This is NOT ordinary combat QA.
## Publish beside the other game/ rigs, then: shot.bat visual_focus --timeout=300
## Normal 1280x720 HUD/camera. Warm samples exclude setup, screenshots and JSON I/O.

const WORLD_SEED := 903126
const NORMAL_ZOOM := 1.12
const WARM_FRAMES := 30
const SAMPLE_FRAMES := 90
const REVEAL_TIMEOUT_MS := 12000
const BASELINE_REVISION := "c0b685127fa1986959681a28c4c4a9a09d9dc3e5"
const VIEWS := [
	{"id": "01_vigil_ilse", "room": "The Vigil Gate", "interactable": "cantor_ilse"},
	{"id": "02_vigil_authored_provision_point", "room": "The Vigil Gate", "at": Vector2(1050, 590)},
	{"id": "03_vigil_center", "room": "The Vigil Gate", "at": Vector2(1056, 700)},
	{"id": "04_vigil_doorway", "room": "The Vigil Gate", "door": true},
	{"id": "05_misted_fields_center", "room": "The Misted Fields", "at": Vector2(1056, 700)},
	{"id": "06_misted_fields_alder", "room": "The Misted Fields", "at": Vector2(425, 950)},
	{"id": "07_pilgrims_rest_merchant", "room": "Pilgrims' Rest", "interactable": "merchant"},
	{"id": "08_cathedral_stone_control", "room": "The Cathedral Approach", "at": Vector2(1056, 700)},
	{"id": "09_vigil_fenna", "room": "The Vigil Gate", "interactable": "old_fenna"},
]

var checks: Array[Dictionary] = []
var views: Array[Dictionary] = []
var failures := 0
var setup: Dictionary = {}


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(WORLD_SEED)
	await boot("warrior", "ch3", false)
	game.play_started = true
	game.state = Game.ST_PLAYING
	game.menus.close()
	game.request_pause(false)
	game.hud.visible = true
	game.settings["touch_controls"] = flag("touch")
	game.settings["touch_layout"] = {}
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.dev_god = false
	# Camera framing is a target-dependent presentation offset/zoom. Keep the
	# ordinary idle camera for these poses, including the normal room limits.
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.camera.position = Vector2.ZERO
	game.camera.zoom = Vector2.ONE * NORMAL_ZOOM
	game._cam_zoom_mult = 1.0
	game._cam_look = Vector2.ZERO
	game._shake_kick = Vector2.ZERO
	game.shake_amt = 0.0
	game.player.clear_local_intents()
	_freeze_actors()
	await skip_dialogue()
	if not await _settle("boot"):
		_complete()
		return
	# boot/class selection generates a seed. Rebuild through the actual chapter
	# path with a fixed seed only after the boot cinematic has really finished.
	seed(WORLD_SEED)
	game.wander_seed = WORLD_SEED
	game.switch_chapter("ch3", true)
	_freeze_actors()
	_quiet_timers()
	await skip_dialogue()
	if not await _settle("fixed_world"):
		_complete()
		return
	setup = {"world_seed": WORLD_SEED, "global_seed_before_rebuild": WORLD_SEED,
		"baseline_revision": BASELINE_REVISION, "source_label": arg("label", "baseline"),
		"source_revision": arg("revision", BASELINE_REVISION),
		"source_hashes": {"game_world": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"art": FileAccess.get_sha256("res://scripts/art.gd"), "balance": FileAccess.get_sha256("res://scripts/balance.gd"),
			"ch3_zones": FileAccess.get_sha256("res://scripts/content/ch3_zones.gd")},
		"fixture": "Direct room-entry teleports; hero/enemy scripts frozen. Actual generated rooms, source enemies and story locks retained. No combat or traversal claim.",
		"god_mode": false, "no_saves": game.no_saves, "random_terrain_events": false,
		"npc_emotes": false, "combat_camera_framing": false, "camera_smoothing": false,
		"hud_visible": game.hud.visible, "touch_mode": game.touch_mode,
		"normal_zoom": NORMAL_ZOOM, "viewport": _xy(get_viewport().get_visible_rect().size),
		"renderer": RenderingServer.get_current_rendering_method(),
		"hdr_2d": get_viewport().use_hdr_2d, "vsync_mode": DisplayServer.window_get_vsync_mode(),
		"engine_max_fps": Engine.max_fps, "time_scale": Engine.time_scale,
		"script_sha256": FileAccess.get_sha256(get_script().resource_path)}
	_check("fixed_actual_ch3", game.chapter_id == "ch3" and game.wander_seed == WORLD_SEED and game.no_saves)
	_check("normal_viewport", get_viewport().get_visible_rect().size == Vector2(1280, 720))
	_check("offline_fixture", not game.net_online())
	_check("requested_control_mode", game.touch_mode == flag("touch"))
	for spec in VIEWS:
		if failures > 0:
			break
		await _view(spec)
	_check("nine_complete_views", views.size() == VIEWS.size())
	_complete()


func _view(spec: Dictionary) -> void:
	var id := String(spec["id"])
	step(id)
	var room := _room_named(String(spec["room"]))
	if not _check(id + "/room_exists", room >= 0):
		return
	# Re-seed immediately before any lazy build so a different renderer's boot
	# timing cannot change cosmetic global-RNG draws in that room's factory.
	seed(WORLD_SEED + room * 101)
	game.player.global_position = game.room_pos(room, 1056, 700)
	game._enter_room(room)
	_freeze_actors()
	_quiet_timers()
	var pos: Vector2
	var direction := ""
	var focus: Dictionary = {}
	if spec.has("interactable"):
		for entry in game.interactables:
			var npc: Node2D = entry.get("node") as Node2D
			if is_instance_valid(npc) and game.room_at_pos(npc.global_position) == room \
					and String(entry.get("sprite_name", "")) == String(spec["interactable"]):
				focus = entry
				break
		if not _check(id + "/spawned_interactable", not focus.is_empty()):
			return
		var focus_npc: Node2D = focus["node"]
		pos = focus_npc.global_position + Vector2.DOWN * minf(60.0, float(focus.get("reach", Balance.INTERACT_RANGE)) * 0.75)
	elif bool(spec.get("door", false)):
		var exits: Dictionary = game.rooms[room]["exits"]
		for dir in ["E", "N", "W", "S"]:
			if exits.has(dir):
				direction = dir
				break
		if not _check(id + "/actual_door", direction != ""):
			return
		var inward: Vector2 = {"E": Vector2.LEFT, "N": Vector2.DOWN,
			"W": Vector2.RIGHT, "S": Vector2.UP}[direction]
		pos = game.door_pos(room, direction) + inward * 175.0
		var pr := game.play_rect(room).grow(-100.0)
		pos = Vector2(clampf(pos.x, pr.position.x, pr.end.x), clampf(pos.y, pr.position.y, pr.end.y))
	else:
		var authored: Vector2 = spec["at"]
		pos = game.room_pos(room, authored.x, authored.y)
	game.player.global_position = pos
	game.player.velocity = Vector2.ZERO
	game.camera.reset_smoothing()
	await skip_dialogue()
	if not await _settle(id):
		return
	await frames(WARM_FRAMES)
	var before := _actor_state(room)
	var warm := await _sample_frames()
	var after := _actor_state(room)
	_check(id + "/frozen_actors_stable", before == after, {"before": before, "after": after})
	_check(id + "/normal_camera", game.camera.zoom.is_equal_approx(Vector2.ONE * NORMAL_ZOOM)
		and game.camera.offset.is_zero_approx(), {"zoom": _xy(game.camera.zoom), "offset": _xy(game.camera.offset)})
	_check(id + "/settled_hud", not _reveal_pending() and game.hud.visible and not game.menus.is_open()
		and not get_tree().paused, _reveal_state())
	_check(id + "/correct_room", game.cur_room == room and game.room_at_pos(game.player.global_position) == room)
	if not focus.is_empty():
		var npc: Node2D = focus["node"]
		var prompt: Label = focus["prompt"]
		_check(id + "/actual_interaction_reach", game.player.global_position.distance_to(npc.global_position)
			< float(focus.get("reach", Balance.INTERACT_RANGE)) and prompt.is_visible_in_tree(),
			{"sprite": focus["sprite_name"], "prompt": prompt.text, "distance": game.player.global_position.distance_to(npc.global_position),
			"reach": float(focus.get("reach", Balance.INTERACT_RANGE))})
	if failures > 0:
		return
	var terrain: Dictionary = Terrains.get_terrain(game.terrain_by_zone[room])
	var info := {"id": id, "room": room, "room_name": game.zones[room]["name"],
		"room_type": game.room_type(room), "terrain": game.terrain_by_zone[room], "ground": terrain.get("ground", ""),
		"ground_field": _field_provenance(room, String(terrain.get("ground", ""))),
		"world_seed": game.wander_seed, "room_cosmetic_seed": WORLD_SEED + room * 101,
		"room_origin": _xy(game.rooms[room]["origin"]), "room_rect": _rect(game.room_rect(room)),
		"play_rect": _rect(game.play_rect(room)), "exits": game.rooms[room]["exits"],
		"view_spec": {"authored_position": _xy(spec.get("at", Vector2.ZERO)), "door": direction,
			"spawned_interactable": String(spec.get("interactable", ""))},
		"hero_position": _xy(game.player.global_position), "camera_node": _xy(game.camera.global_position),
		"camera_screen_center": _xy(game.camera.get_screen_center_position()), "camera_zoom": _xy(game.camera.zoom),
		"camera_limits": [game.camera.limit_left, game.camera.limit_top, game.camera.limit_right, game.camera.limit_bottom],
		"ambient": [game.ambient.color.r, game.ambient.color.g, game.ambient.color.b, game.ambient.color.a],
		"room_cleared": bool(game.cleared.get(room, false)), "room_alive_counter": int(game.zone_alive.get(room, 0)),
		"actors": after, "inventory": _room_inventory(room), "reveal": _reveal_state(), "warm_frames": warm}
	info["capture"] = shot(id, "posed actual ch3; seed=%d room=%d; frozen actors; normal HUD/zoom" % [WORLD_SEED, room])
	views.append(info)
	_write_report()


func _field_provenance(room: int, kind: String) -> Dictionary:
	var tex: Texture2D = Art.ground_field(kind)
	var source := tex.resource_path if tex != null else ""
	var poly: Polygon2D = game.zone_fields.get(room) as Polygon2D
	var rendered: Texture2D = poly.texture if is_instance_valid(poly) else null
	return {"kind": kind, "resource_path": source, "dimensions": _xy(tex.get_size()) if tex != null else [],
		"world_period": Art.ground_field_period(kind),
		"source_sha256": FileAccess.get_sha256(source) if source != "" and FileAccess.file_exists(source) else "",
		"rendered_resource_path": rendered.resource_path if rendered != null else "",
		"rendered_texture_is_art_lookup": rendered != null and rendered == tex}


func _freeze_actors() -> void:
	game.player.velocity = Vector2.ZERO
	game.player.set_process(false)
	game.player.set_physics_process(false)
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy:
			n.set_process(false)
			n.set_physics_process(false)


func _quiet_timers() -> void:
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	# The inactivity safety net can otherwise reposition a source straggler.
	# No timer / actor changes are applied during the measured frame window.
	game._straggler_idle = -1.0e9


func _actor_state(room: int) -> Dictionary:
	var enemies: Array[Dictionary] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.zone_idx == room and not e.is_queued_for_deletion():
			enemies.append({"kind": e.kind, "position": _xy(e.global_position), "hp": e.hp,
				"process": e.is_processing(), "physics": e.is_physics_processing()})
	return {"hero_position": _xy(game.player.global_position), "hero_hp": game.player.hp,
		"hero_mp": game.player.mp, "hero_process": game.player.is_processing(),
		"hero_physics": game.player.is_physics_processing(), "enemies": enemies}


func _room_inventory(room: int) -> Dictionary:
	var roots: Array = game.zone_scenery.get(room, [])
	var props: Array[Dictionary] = []
	var root_obstacles := 0
	for n in roots:
		if not is_instance_valid(n):
			continue
		if n is StaticBody2D:
			root_obstacles += 1
		if n is Node2D and (n.has_meta("prop") or n.has_meta("building") or n.has_meta("structure") or n.has_meta("terrain_landmark")):
			props.append({"prop": n.get_meta("prop", ""), "building": n.get_meta("building", ""),
				"structure": n.get_meta("structure", ""), "landmark": n.get_meta("terrain_landmark", ""),
				"position": _xy(n.global_position), "scale": _xy(n.scale)})
	var lights: Array[Dictionary] = []
	var world_static_bodies := 0
	var stack: Array[Node] = [game.world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Node2D and game.room_at_pos(node.global_position) == room:
			if node is StaticBody2D:
				world_static_bodies += 1
			if node is PointLight2D:
				lights.append({"position": _xy(node.global_position), "energy": node.energy,
					"visible": node.is_visible_in_tree(), "texture_scale": node.texture_scale})
	var npcs: Array[Dictionary] = []
	for entry in game.interactables:
		var n: Node2D = entry.get("node") as Node2D
		if is_instance_valid(n) and game.room_at_pos(n.global_position) == room:
			var prompt: Label = entry.get("prompt") as Label
			npcs.append({"prompt": prompt.text if is_instance_valid(prompt) else "", "position": _xy(n.global_position),
				"sprite_name": String(entry.get("sprite_name", "")), "reach": float(entry.get("reach", Balance.INTERACT_RANGE)),
				"convo": n.get_meta("quest_convo", ""), "scenery_prop": n.get_meta("scenery_prop", false)})
	return {"scenery_root_count": roots.size(), "scenery_obstacle_bodies": root_obstacles,
		"tagged_prop_count": props.size(), "tagged_props": props,
		"world_static_bodies_in_cell_including_walls": world_static_bodies,
		"world_point_light_count_in_cell": lights.size(), "world_point_lights": lights,
		"interactables": npcs, "scope": "Current room cell; world subtree only for bodies/lights. Hero-attached lights excluded. Scenery roots also include floor wear and decorative sprites."}


func _sample_frames() -> Dictionary:
	var wall_ms: Array[float] = []
	var process_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		wall_ms.append(float(now - previous) / 1000.0)
		previous = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"warmup_frames": WARM_FRAMES, "samples": SAMPLE_FRAMES,
		"scope": "Warm posed world + normal HUD, hero/enemy scripts frozen. Frame wall intervals include pacing; TIME_PROCESS is engine process time. Not GPU timing or live-combat performance.",
		"wall_interval_ms": _stats(wall_ms), "process_ms": _stats(process_ms), "draw_calls": _stats(draw_calls)}


func _stats(values: Array[float]) -> Dictionary:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in values:
		total += v
	return {"min": sorted[0], "median": sorted[floori(sorted.size() * 0.5)],
		"p95": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95) - 1)],
		"max": sorted[-1], "mean": total / values.size(), "raw": values}


func _room_named(value: String) -> int:
	for i in game.zones.size():
		if String(game.zones[i].get("name", "")) == value:
			return i
	return -1


func _reveal_state() -> Dictionary:
	var children := 0
	for child in game.hud.get_children():
		if child is Cutscene:
			children += 1
	return {"cinematic_children": children, "cinematic_mode": game.hud._cinematic_mode,
		"cutscene_active": game.cutscene != null, "dialogue": game.hud.dialogue_active,
		"announcement": is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible,
		"choices": game.hud.choices_active, "overlay_alpha": game.hud.overlay.color.a,
		"title_alpha": game.hud.title_label.modulate.a, "subtitle_alpha": game.hud.subtitle_label.modulate.a}


func _reveal_pending() -> bool:
	if game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active:
		return true
	for child in game.hud.get_children():
		if child is Cutscene:
			return true
	if is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible:
		return true
	return game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01


func _settle(label: String) -> bool:
	# Cutscene.finish clears game.cutscene before its deferred normal title.
	# Observe both the remaining child/mode and later title; never force alpha.
	var deadline := Time.get_ticks_msec() + REVEAL_TIMEOUT_MS
	var stable := 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		stable = 0 if _reveal_pending() else stable + 1
		if stable >= 3:
			break
	return _check(label + "/reveal_finished", stable >= 3, _reveal_state())


func _xy(v: Vector2) -> Array:
	return [v.x, v.y]


func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _check(label: String, passed: bool, details: Dictionary = {}) -> bool:
	checks.append({"check": label, "passed": passed, "details": details})
	if not passed:
		failures += 1
		print("VISUAL FOCUS CHECK FAILED: ", label, " ", JSON.stringify(details))
	return passed


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		print("VISUAL FOCUS REPORT WRITE FAILED: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"setup": setup, "checks": checks, "failures": failures, "views": views}, "\t"))
	file.close()


func _complete() -> void:
	_write_report()
	print("VISUAL FOCUS: %d checks, %d failures, %d posed views; no ordinary combat claim" % [checks.size(), failures, views.size()])
	finish(1 if failures > 0 else 0)
