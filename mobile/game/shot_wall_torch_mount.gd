extends ShotRig
## --baseline records old mount/depth findings; fixture failures remain failures.
## Actual generated door geometry, native poses and ordinary keyboard movement.
const Mount := preload("res://scripts/door_torch_mount.gd")
const SEED := 903126
var checks: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var views: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var failures := 0
var held := {}
var disk := {}
var baseline := false
var initial_speed := 0.0
var frozen: Array[Node] = []


func _ready() -> void:
	baseline = flag("baseline")
	var home := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _check("isolated_qa_home", home.to_lower().contains("/build/qa/"), {"path": home}):
		finish(1)
		return
	_snapshot_disk()
	get_window().size = Vector2i(1280, 720)
	seed(SEED)
	await boot("warrior", arg("chapter", "ch1"), false)
	var error := await _run()
	_release()
	for actor in frozen:
		if is_instance_valid(actor):
			actor.set_physics_process(true)
	if game != null:
		game.hud.cancel_conversation()
		game.request_pause(false)
	if error != "":
		_check("fixture_complete", false, {"error": error})
		shot("diagnostic_failure", error)
	_restore_disk()
	_write_report()
	print("WALL TORCH MOUNT: %d checks, %d failures, %d findings, %d views, %d input legs; %s" %
		[checks.size(), failures, findings.size(), views.size(), legs.size(), "BASELINE ONLY" if baseline else "regression"])
	finish(1 if failures > 0 else 0)


func _on_watchdog() -> void:
	_release()
	_restore_disk()
	super._on_watchdog()


func _run() -> String:
	game.play_started = true
	game.state = Game.ST_PLAYING
	game.menus.close()
	game.request_pause(false)
	game.dev_god = false
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.settings["combat_framing"] = false
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	initial_speed = game.player.speed
	if not await _settle():
		return "Boot reveal did not settle"
	seed(SEED)
	game.wander_seed = SEED
	game.switch_chapter(arg("chapter", "ch1"), true)
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	var selections: Array[Dictionary] = []
	for direction in ["W", "S", "N", "E"]:
		var chosen := -1
		for zi in game.rooms.size():
			if not game.rooms[zi]["exits"].has(direction):
				continue
			if chosen < 0:
				chosen = zi
			if Terrains.wall_for(String(game.terrain_by_zone[zi])) == "wall_wood":
				chosen = zi
				break
		if chosen < 0:
			return "Generated graph lacks an actual %s door" % direction
		selections.append({"room": chosen, "direction": direction})
	# A different real wall material uses the same mount path. Prefer a normal
	# room rather than entering a boss presentation solely for a material control.
	for zi in game.rooms.size():
		if Terrains.wall_for(String(game.terrain_by_zone[zi])) == "wall_wood" \
				or game.room_type(zi) == "boss" or game.rooms[zi]["exits"].is_empty():
			continue
		selections.append({"room": zi, "direction": String(game.rooms[zi]["exits"].keys()[0]), "material_control": true})
		break
	# The narrowest real inset mouth in this graph; do not invent a corridor.
	var narrow := -1
	var narrow_area := INF
	for zi in game.rooms.size():
		if game.room_rect(zi) == game.play_rect(zi) or game.rooms[zi]["exits"].is_empty():
			continue
		var area: float = game.play_rect(zi).get_area()
		if area < narrow_area:
			narrow = zi
			narrow_area = area
	if not _check("actual_narrow_room_available", narrow >= 0):
		return "Generated graph lacks a real narrow/inset door control"
	selections.append({"room": narrow, "direction": String(game.rooms[narrow]["exits"].keys()[0]), "inset_control": true})
	for index in selections.size():
		var chosen: Dictionary = selections[index]
		var zi: int = chosen.room
		var direction: String = chosen.direction
		var inward := _inward(direction)
		var door := _mouth(zi, direction)
		if not await _pose(zi, door + inward * 165.0):
			return "Door pose/reveal failed"
		var sources := _sources(zi, direction)
		if not _check("%d/%s/two_real_pillars" % [zi, direction], sources.size() == 2):
			return "Expected two actual door-side pillar sprites"
		var kind := "inset" if chosen.has("inset_control") else "material" if chosen.has("material_control") else "door"
		await _capture("%02d_%s_%s" % [index + 1, direction.to_lower(), kind], zi, direction, sources)
	var primary: Dictionary = selections[0] # W: open space for the small front/back route lies east.
	var room: int = primary.room
	if not await _pose(room, _mouth(room, "W") + Vector2(165, 0)):
		return "Primary revisit failed"
	var pair := _sources(room, "W")
	if pair.size() != 2:
		return "Primary pair disappeared"
	var source: Sprite2D = pair[1]
	# All frames are observed from the normal animation, never assigned.
	var seen := {}
	# Native HDR readback can consume seconds; observe naturally within a
	# bounded wall-clock window without mistaking capture cost for a stuck loop.
	var deadline := Time.get_ticks_msec() + 30000
	while seen.size() < source.hframes and Time.get_ticks_msec() < deadline:
		var frame := source.frame
		if not seen.has(frame):
			await _capture("animation", room, "W", pair, source)
			# Screenshot readback can span a later process interval; credit the
			# frame actually recorded after post_draw, not the earlier wait value.
			seen[int(views[-1]["pillars"][1]["frame"])] = true
		await get_tree().process_frame
	if not _check("natural_animation_all_frames", seen.size() == source.hframes, {"seen": seen.keys()}):
		return "Animation did not cycle"
	var base := _world_rect(source, Mount.geometry(source)["footprint"])
	var front := Vector2(base.get_center().x, base.end.y)
	# Added after the original ABCD86 baseline: these setup poses isolate the
	# shared feet threshold. They are not extra baselined movement inputs.
	if not baseline:
		for feet_delta in [-3.0, 3.0]:
			var at := front + Vector2(0, feet_delta - Player.HERO_FEET_ANCHOR)
			if not await _pose(room, at):
				return "Near-threshold depth pose failed"
			var label := "depth_near_behind" if feet_delta < 0 else "depth_near_in_front"
			await _capture(label, room, "W", pair)
			if not _near_depth_check(label, source, feet_delta):
				return "Shared feet threshold/occlusion check failed"
	if not await _pose(room, front + Vector2(0, -28)):
		return "Behind-pillar pose failed"
	await _capture("depth_behind", room, "W", pair)
	var finish_at := game.free_spawn_pos(front + Vector2(0, 28), game.room_center(room))
	for point in [front + Vector2(60, -28), front + Vector2(60, 28), finish_at]:
		if not await _walk_to(point):
			return "Ordinary around-pillar route was blocked"
	await _capture("depth_in_front", room, "W", pair)
	# A separate setup at the genuine road mouth; two real input legs stay in
	# the room so no story gate or neighbor state must be manipulated.
	var lane := _mouth(room, "W") + Vector2(Game.TILE + 32, 0)
	if not await _pose(room, lane):
		return "Road-mouth pose failed"
	var mechanics := _mechanics(room)
	if not await _walk_to(lane + Vector2(160, 0)) or not await _walk_to(lane):
		return "Ordinary road-mouth route was blocked"
	_check("road_mechanics_unchanged", mechanics == _mechanics(room))
	_check("normal_hero_input_positive", legs.size() == 5 and game.player.is_physics_processing()
		and not game.dev_god and is_equal_approx(game.player.speed, initial_speed) and not game.player.dead)
	await _capture("road_mouth_after_input", room, "W", pair)
	return ""


func _pose(room: int, at: Vector2) -> bool:
	_release()
	game._enter_room(room)
	# Room entry resets this timer; keep this mount-only fixture free of random
	# terrain events through native frame reads and the subsequent input legs.
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	game.player.global_position = game.free_spawn_pos(at, game.room_center(room))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.is_physics_processing():
			node.set_physics_process(false)
			frozen.append(node)
	game.player.locked_target = null
	await skip_dialogue()
	if not await _settle():
		return false
	await get_tree().create_timer(0.8, true).timeout
	return game.cur_room == room and not get_tree().paused and game.player.is_physics_processing()


func _settle() -> bool:
	var until := Time.get_ticks_msec() + 9000
	var stable := 0
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		stable = 0 if _reveal_pending() else stable + 1
		if stable >= 3:
			return true
	return false


func _reveal_pending() -> bool:
	if game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active:
		return true
	for child in game.hud.get_children():
		if child is Cutscene:
			return true
	if is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible:
		return true
	return game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01


func _sources(room: int, direction: String) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	var info: Dictionary = Art.anim_info("torch_pillar")
	var pr := game.play_rect(room)
	var door := _mouth(room, direction)
	for node in game.world.find_children("*", "Sprite2D", true, false):
		var source := node as Sprite2D
		if source.has_meta("cast_shadow") or source.texture != info.get("tex") or source.hframes != int(info.get("frames", 0)):
			continue
		var at := game.world.to_local(source.global_position)
		if not pr.grow(1.0).has_point(at):
			continue
		if source.get_parent().has_meta("door_torch"):
			if int(source.get_parent().get_meta("door_torch_room")) == room \
					and String(source.get_parent().get_meta("door_torch_direction")) == direction:
				result.append(source)
		elif absf(at.x - door.x) < 150 and absf(at.y - door.y) < 150:
			result.append(source)
	result.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.global_position.y < b.global_position.y)
	return result


func _capture(label: String, room: int, direction: String, sources: Array[Sprite2D], animation_source: Sprite2D = null) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	if animation_source != null:
		label = "animation_%d_%02d" % [animation_source.frame, views.size()]
	var row := {"view": label, "room": room, "direction": direction, "terrain": game.terrain_by_zone[room],
		"mechanics": _mechanics(room), "hero": str(game.player.global_position), "pillars": []}
	for source in sources:
		var geometry := Mount.geometry(source)
		var footprint := _world_rect(source, geometry["footprint"])
		var used := _world_rect(source, geometry["used"])
		var wall_hits := 0
		for wall in game.zone_wall_sprites.get(room, []):
			var rect: Rect2 = wall.get_meta("wall_rect")
			if String(wall.get_meta("wall_relief", "")).contains("S"):
				rect.size.y += Game.WALL_FACE_H
			if footprint.intersects(rect):
				wall_hits += 1
		var parent := source.get_parent() as Node2D
		var painted_front := game.world.to_global(Vector2(footprint.get_center().x, footprint.end.y))
		var shared_sort_y := painted_front.y - Player.HERO_FEET_ANCHOR
		var owns_shadow := false
		for child in parent.get_children():
			if child is CanvasItem and child.has_meta("cast_shadow") and child.visible:
				owns_shadow = true
		var lane := _lane(room, direction)
		var measurement := {"frame": source.frame, "used": str(used), "footprint": str(footprint),
			"wall_intersections": wall_hits, "lane_intersection": footprint.intersects(lane),
			"root": str(parent.position), "root_z": parent.z_index, "source_z": source.z_index,
			"painted_front": str(painted_front), "shared_sort_y": shared_sort_y,
			"actual_sort_y": parent.global_position.y,
			"occlusion_sort_y": float(source.get_meta("occlusion_sort_y", parent.global_position.y)),
			"occluder_group": source.is_in_group("structure_occluders"),
			"owns_contact_shadow": owns_shadow, "mounted_root": parent.has_meta("door_torch")}
		row.pillars.append(measurement)
		_probe(label + "/plinth_on_floor", wall_hits == 0 and not footprint.intersects(lane), measurement)
		_probe(label + "/ground_depth_and_contact", parent.has_meta("door_torch") and parent.z_index == 0
			and source.z_index == 0 and not parent.y_sort_enabled and owns_shadow, measurement)
		_probe(label + "/shared_feet_sort_and_occlusion", parent.has_meta("door_torch")
			and is_equal_approx(parent.global_position.y, shared_sort_y)
			and source.is_in_group("structure_occluders")
			and is_equal_approx(float(source.get_meta("occlusion_sort_y", parent.global_position.y)), shared_sort_y)
			and float(source.get_meta("occlusion_radius", 0.0)) > 0.0, measurement)
	views.append(row)
	shot(label, "actual generated door; setup poses/frozen enemies; keyboard movement only in recorded legs")


func _near_depth_check(label: String, source: Sprite2D, expected_delta: float) -> bool:
	var footprint := _world_rect(source, Mount.geometry(source)["footprint"])
	var front := game.world.to_global(Vector2(footprint.get_center().x, footprint.end.y))
	var hero_feet := game.player.global_position + Vector2(0, Player.HERO_FEET_ANCHOR)
	var alpha := 0.0
	for probe in Balance.PLAYER_OCCLUSION_PROBES:
		alpha = maxf(alpha, game.player._visual_alpha_at(source, game.player.global_position + probe))
	var key := source.get_instance_id()
	var clip = game.player._occlusion_clips.get(key)
	var outlined := is_instance_valid(clip)
	var clipped: bool = outlined and clip.get_parent() == source \
		and source.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW
	var behind := expected_delta < 0.0
	var detail := {"hero_feet": str(hero_feet), "painted_front": str(front),
		"feet_delta": hero_feet.y - front.y, "expected_delta": expected_delta,
		"probe_alpha": alpha, "covering": game.player._covering_structures().has(source),
		"outline_present": outlined, "outline_clipped_to_source": clipped}
	views[-1]["near_depth"] = detail
	var reached := _check(label + "/actual_feet_pose", absf(hero_feet.y - front.y - expected_delta) < 1.0, detail)
	var overlapping := _check(label + "/real_painted_overlap", alpha >= Balance.PLAYER_OCCLUSION_ALPHA_THRESHOLD, detail)
	var outline_ok := _check(label + "/standard_outline_threshold", bool(detail["covering"]) == behind
		and outlined == behind and (not behind or clipped), detail)
	return reached and overlapping and outline_ok


func _world_rect(source: Sprite2D, rect: Rect2) -> Rect2:
	var local := Rect2(rect.position - Vector2(source.texture.get_width() / source.hframes,
		source.texture.get_height() / source.vframes) * 0.5, rect.size)
	var xf: Transform2D = game.world.global_transform.affine_inverse() * source.global_transform
	var result := Rect2(xf * local.position, Vector2.ZERO)
	for point in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		result = result.expand(xf * point)
	return result


func _mouth(room: int, direction: String) -> Vector2:
	var at := game.door_pos(room, direction)
	var pr := game.play_rect(room)
	if direction in ["W", "E"]:
		at.x = clampf(at.x, pr.position.x, pr.end.x)
	else:
		at.y = clampf(at.y, pr.position.y, pr.end.y)
	return at


func _lane(room: int, direction: String) -> Rect2:
	var at := _mouth(room, direction)
	var half := Game.DOOR_TILES * Game.TILE * 0.5
	var pr := game.play_rect(room)
	return Rect2(pr.position.x, at.y - half, pr.size.x, half * 2) if direction in ["W", "E"] \
		else Rect2(at.x - half, pr.position.y, half * 2, pr.size.y)


func _inward(direction: String) -> Vector2:
	return {"W": Vector2.RIGHT, "E": Vector2.LEFT, "N": Vector2.DOWN, "S": Vector2.UP}[direction]


func _mechanics(room: int) -> Dictionary:
	var walls: Array = []
	for sprite in game.zone_wall_sprites.get(room, []):
		walls.append(str(sprite.get_meta("wall_rect")))
	var locks := {}
	for direction in game.rooms[room]["exits"]:
		locks[direction] = game._edge_unlocked(room, game.neighbor(room, String(direction)))
	var glows := 0
	for source in game.world.find_children("*", "Sprite2D", true, false):
		if source.texture == Art.tex("glow"):
			glows += 1
	return {"play_rect": str(game.play_rect(room)), "full_rect": str(game.room_rect(room)),
		"exits": game.rooms[room]["exits"].duplicate(true), "locks": locks, "wall_rects": walls,
		"world_bodies": game.world.find_children("*", "StaticBody2D", true, false).size(),
		"world_point_lights": game.world.find_children("*", "PointLight2D", true, false).size(), "world_glow_sprites": glows}


func _walk_to(target: Vector2) -> bool:
	var start := game.player.global_position
	var until := Time.get_ticks_msec() + 6000
	var count := 0
	while Time.get_ticks_msec() < until and game.player.global_position.distance_to(target) > 8:
		if game.input_overlay_up() or get_tree().paused:
			break
		var delta := target - game.player.global_position
		_press(KEY_A, delta.x < -4)
		_press(KEY_D, delta.x > 4)
		_press(KEY_W, delta.y < -4)
		_press(KEY_S, delta.y > 4)
		count += 1
		await get_tree().process_frame
	_release()
	await frames(3)
	var record := {"start": str(start), "end": str(game.player.global_position), "target": str(target), "input_frames": count}
	legs.append(record)
	return _check("ordinary_walk", count > 0 and start.distance_to(game.player.global_position) > 1
		and start.distance_to(game.player.global_position) >= start.distance_to(target) - 12
		and game.player.global_position.distance_to(target) <= 11 and is_equal_approx(game.player.speed, initial_speed), record)


func _press(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _release() -> void:
	for key in held:
		_press(int(key), false)
	if game != null and game.has_local_player():
		game.player.clear_local_intents()


func _check(label: String, okay: bool, detail := {}) -> bool:
	checks.append({"check": label, "pass": okay, "detail": detail})
	if not okay:
		failures += 1
	return okay


func _probe(label: String, okay: bool, detail := {}) -> void:
	if baseline and not okay:
		findings.append({"finding": label, "detail": detail})
	else:
		_check(label, okay, detail)


func _snapshot_disk() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".json"):
			disk[file] = FileAccess.get_file_as_bytes("user://" + file)


func _restore_disk() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().contains("/build/qa/"):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".json") and not disk.has(file):
			dir.remove(file)
	for file in disk:
		var out := FileAccess.open("user://" + file, FileAccess.WRITE)
		if out != null:
			out.store_buffer(disk[file])
			out.close()
		_check("restored_user_json/" + file, FileAccess.get_file_as_bytes("user://" + file) == disk[file])


func _write_report() -> void:
	var out := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if out == null:
		return
	out.store_string(JSON.stringify({"baseline": baseline, "seed": SEED, "checks": checks,
		"failures": failures, "findings": findings, "views": views, "legs": legs,
		"source_sha256": {"world": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"balance": FileAccess.get_sha256("res://scripts/balance.gd"), "mount": FileAccess.get_sha256("res://scripts/door_torch_mount.gd"),
			"rig": FileAccess.get_sha256("res://shot_wall_torch_mount.gd"), "art": FileAccess.get_sha256("res://assets/sprites/torch_pillar_anim.png")},
		"scope": "Actual generated geometry; setup poses, frozen enemies; five ordinary keyboard legs; host-rendered source, not device/touch validation"}, "\t"))
	out.close()
