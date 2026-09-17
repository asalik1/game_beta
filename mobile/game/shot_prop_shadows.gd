extends ShotRig
## Shared prop shadow captures and actual interaction/grounding contracts.
## shot.bat prop_shadows --timeout=300
## Real ch3 floor/lighting and real obstacle/structure factories, isolated no_saves.
## Controlled views hide existing room scenery, then place one real prop at a time.
const CASES := [
	{"name": "tombstone3", "mirror": false, "label": "01_cluster_normal"},
	{"name": "tombstone3", "mirror": true, "label": "02_cluster_mirrored"},
	{"name": "tombstone", "label": "03_tombstone"},
	{"name": "tombstone2", "label": "04_tombstone2"},
	{"name": "grave_statue", "label": "05_grave_statue"},
	{"name": "grave_angel", "label": "06_grave_angel"},
	{"name": "grave_deadtree", "label": "07_dead_tree"},
	{"name": "tree_green2", "label": "08_animated_tree", "motion": true},
	{"name": "town_fountain", "label": "09_fountain", "structure": true, "motion": true},
	{"name": "log", "label": "10_log"},
	{"name": "rock", "label": "11_rock"},
	{"name": "coffin", "label": "12_coffin"},
	{"name": "fence", "label": "13_wide_fence"},
]
var samples: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var failures := 0
var hidden_scenery := 0
var fixture_origin := Vector2.ZERO
var npc_interactions := 0
var npc_observations: Dictionary = {}


func _ready() -> void:
	if flag("chests"):
		await preload("res://scripts/tests/chest_grounding_live.gd").run(self)
		return
	await boot("warrior", "ch3", false)
	game.play_started = true
	game.menus.close()
	game.wander_seed = 902026
	game.switch_chapter("ch3", true)
	game.request_pause(false)
	game.hud.visible = true
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	await skip_dialogue()
	await frames(6)
	_check("isolated_boot", game.no_saves and not get_tree().paused)
	_check("actual_graveyard_room", game.chapter_id == "ch3" and String(game.zones[game.cur_room].get("type", "")) == "safe")
	fixture_origin = game.room_center(game.cur_room)
	game.player.global_position = fixture_origin + Vector2(0, 170)
	game.camera.global_position = fixture_origin
	await _settle()
	await RenderingServer.frame_post_draw
	shot("00_actual_vigil_gate", "normal room scenery and HUD before controlled fixture")
	# Hide only the real room's scenery for repeatable close-ups; retain the
	# production floor, terrain tint, shaders and lighting. No asset edits.
	for node in game.zone_scenery.get(game.cur_room, []):
		if is_instance_valid(node) and node is CanvasItem:
			(node as CanvasItem).visible = false
			hidden_scenery += 1
	hide_hud()
	game.camera.zoom = Vector2(1.25, 1.25)
	for spec in CASES:
		await _case(spec)
	await _interactive_prop_case()
	_write_report()
	print("PROP SHADOWS: %d checks, %d failures; real prop factories, frames and interactions" % [checks.size(), failures])
	finish(1 if failures > 0 else 0)


func _case(spec: Dictionary) -> void:
	var name := String(spec.name)
	var label := String(spec.label)
	step(label)
	var point := _fixture_position(spec)
	var body: StaticBody2D
	if bool(spec.get("structure", false)):
		body = game._add_structure(name, point)
	else:
		body = game._add_obstacle(name, point, 1.0)
	var source := _source(body)
	_check(label + "/source", source != null)
	if source == null:
		body.queue_free()
		await frames(2)
		return
	var casts: Array[Node2D] = []
	for child in body.get_children():
		if child is Node2D and child.has_meta("cast_shadow"):
			casts.append(child as Node2D)
	_check(label + "/has_cast", not casts.is_empty())
	var world_rect := _body_bounds(body, false)
	game.player.global_position = point + Vector2(430, 240)
	game.camera.global_position = world_rect.get_center()
	await _settle()
	if spec.has("mirror"):
		_check(label + "/requested_mirror", (source.scale.x < 0.0) == bool(spec.mirror))
	if not bool(spec.get("structure", false)):
		_check(label + "/requested_variant", Terrains.prop_variant(name, int(point.x * 31.0 + point.y * 17.0)) == name)
	await _capture(label, spec, body, source, casts)
	if bool(spec.get("motion", false)):
		var start_frame := int(source.get("frame")) if source is AnimatedSprite2D else -1
		var deadline := Time.get_ticks_msec() + 2500
		while source is AnimatedSprite2D and int(source.get("frame")) == start_frame and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(label + "/animated_source", source is AnimatedSprite2D)
		_check(label + "/animation_advanced", source is AnimatedSprite2D and int(source.get("frame")) != start_frame)
		await _capture(label + "_motion", spec, body, source, casts)
	body.queue_free()
	await frames(3)


func _fixture_position(spec: Dictionary) -> Vector2:
	# Use the production seeded variant/mirror rules rather than changing a
	# sprite after its shadow has already copied the original transform.
	var name := String(spec.name)
	if bool(spec.get("structure", false)):
		return fixture_origin
	var family := Terrains.prop_base(name)
	for dx in range(0, 48):
		for dy in range(0, 16):
			var point := fixture_origin + Vector2(dx, dy)
			if Terrains.prop_variant(name, int(point.x * 31.0 + point.y * 17.0)) != name:
				continue
			var mirrored := absi(("%s_%d_%d" % [family, int(point.x), int(point.y)]).hash()) % 2 == 1
			if not spec.has("mirror") or mirrored == bool(spec.mirror):
				return point
	_check(String(spec.label) + "/fixture_position", false)
	return fixture_origin


func _source(body: Node2D) -> Node2D:
	var base := game._base_sprite_of(body)
	if base != null:
		return base
	for child in body.get_children():
		if child.has_meta("cast_shadow"):
			continue
		if child is AnimatedSprite2D:
			return child as Node2D
		if child is Sprite2D and (child as Sprite2D).texture != Art.tex("shadow"):
			return child as Node2D
	return null


func _interactive_prop_case() -> void:
	step("14_interactive_tombstone")
	# Use the shipped lore prop factory and conversation. Only the surrounding
	# interactable list is isolated, so a hidden room NPC cannot win nearest-E.
	var saved_interactables: Array = game.interactables.duplicate()
	var npc: Node2D = game._make_npc("tombstone", fixture_origin,
		"E — Read", _read_fixture_tombstone, "ch3_lore_chapel")
	var source := _source(npc) as Sprite2D
	var casts: Array[Node2D] = []
	for child in npc.get_children():
		if child is Node2D and child.has_meta("cast_shadow"):
			casts.append(child as Node2D)
	var entry: Dictionary = {}
	for candidate in game.interactables:
		if candidate.get("node") == npc:
			entry = candidate
	_check("npc/real_factory_entry", source != null and not entry.is_empty())
	_check("npc/scenery_classification", Terrains.is_prop_sprite("tombstone") and bool(npc.get_meta("scenery_prop", false)))
	_check("npc/shared_scenery_cast", casts.size() == 1 and casts[0] is Sprite2D and String(casts[0].get_meta("cast_shadow_mode", "")) == "hug")
	if source == null or entry.is_empty():
		game.interactables = saved_interactables
		npc.queue_free()
		await frames(3)
		return
	game.interactables = [entry]
	var rest := _sprite_pose(source)
	var cast_rest: Array[Dictionary] = []
	for cast in casts:
		cast_rest.append(_sprite_pose(cast as Sprite2D))
	game.player.global_position = fixture_origin + Vector2(180, 80)
	game.camera.global_position = _body_bounds(npc, false).get_center()
	await _stationary_prop_window("npc/idle", source, casts, rest, cast_rest)
	await _capture("14_interactive_tombstone_idle", {"name": "tombstone"}, npc, source, casts)
	var side_rows: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var label := "15_interactive_tombstone_from_left" if side < 0.0 else "16_interactive_tombstone_from_right"
		step(label)
		game.hud.visible = true
		game.player.global_position = fixture_origin + Vector2(side * 45.0, 30.0)
		game.talk_cd = 0.0
		await frames(3)
		var before := npc_interactions
		_interact_key(true)
		await frames(3)
		_interact_key(false)
		await frames(2)
		_check(label + "/ordinary_key_action", npc_interactions == before + 1)
		_check(label + "/real_dialogue_open", game.hud.dialogue_active or game.hud.choices_active)
		_check(label + "/hero_faces_stone", game.player.look_sign == -side and game.player.facing == Vector2(-side, 0.0))
		_check(label + "/prop_pose_unchanged_during_read", _sprite_pose(source) == rest)
		_check(label + "/no_person_facing_owner", game.active_facing_interactable.is_empty())
		side_rows.append({"side": side, "input": "InputEventKey through player intents",
			"action_count": npc_interactions, "hero_look_sign": game.player.look_sign,
			"hero_facing": str(game.player.facing), "dialogue_active": game.hud.dialogue_active,
			"source": _visual_record(source)})
		await skip_dialogue()
		await frames(6)
		_check(label + "/dialogue_closed", not game.hud.dialogue_active and not game.hud.choices_active and not get_tree().paused)
		hide_hud()
		await _stationary_prop_window(label + "/after_read", source, casts, rest, cast_rest)
		await _capture(label, {"name": "tombstone"}, npc, source, casts)
	npc_observations["interactions"] = side_rows
	npc_observations["scenery_prop"] = npc.get_meta("scenery_prop", false)
	npc_observations["factory"] = "Game._make_npc"
	npc_observations["conversation"] = "ch3_lore_chapel"
	game.interactables = saved_interactables
	npc.queue_free()
	await frames(3)


func _read_fixture_tombstone() -> void:
	npc_interactions += 1
	game.run_convo_id("ch3_lore_chapel")


func _interact_key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = int(game.binds.get("interact", KEY_E))
	event.physical_keycode = event.keycode
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _sprite_pose(sprite: Sprite2D) -> Dictionary:
	if sprite == null:
		return {}
	return {"texture": sprite.texture, "transform": sprite.transform,
		"hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame,
		"flip_h": sprite.flip_h, "flip_v": sprite.flip_v, "offset": sprite.offset,
		"centered": sprite.centered, "material": sprite.material}


func _stationary_prop_window(label: String, source: Sprite2D, casts: Array[Node2D], rest: Dictionary, cast_rest: Array[Dictionary]) -> void:
	# Exceed the old maximum initial breath delay + full bob (2.76s), sampling
	# actual frames rather than trusting a timer after a long capture frame.
	var start := Time.get_ticks_msec()
	var count := 0
	var stationary := true
	var cast_stationary := true
	var matching := true
	while Time.get_ticks_msec() - start < 6000:
		await get_tree().process_frame
		count += 1
		stationary = stationary and _sprite_pose(source) == rest
		for i in casts.size():
			var cast := casts[i] as Sprite2D
			cast_stationary = cast_stationary and _sprite_pose(cast) == cast_rest[i]
			matching = matching and cast != null and cast.texture == source.texture \
				and cast.frame == source.frame and cast.hframes == source.hframes \
				and cast.flip_h == source.flip_h and cast.flip_v == source.flip_v
		if Time.get_ticks_msec() - start >= 3200 and count >= 20:
			break
	_check(label + "/sampling_window", count >= 20 and Time.get_ticks_msec() - start >= 3200)
	_check(label + "/stationary_pose", stationary)
	_check(label + "/stationary_cast", cast_stationary)
	_check(label + "/matching_cast", matching)
	npc_observations[label] = {"sampled_frames": count, "elapsed_ms": Time.get_ticks_msec() - start,
		"stationary": stationary, "cast_stationary": cast_stationary, "matching_cast": matching}


func _sprites(root: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in root.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			out.append(child as Node2D)
		out.append_array(_sprites(child))
	return out


func _body_bounds(body: Node2D, canvas: bool) -> Rect2:
	var bounds := Rect2()
	var found := false
	for sprite in _sprites(body):
		var extent := game._visual_size(sprite)
		if sprite is Sprite2D:
			extent /= Vector2(maxi(1, (sprite as Sprite2D).hframes), maxi(1, (sprite as Sprite2D).vframes))
		var at: Vector2 = sprite.get("offset")
		if bool(sprite.get("centered")):
			at -= extent * 0.5
		var transform: Transform2D = sprite.get_global_transform_with_canvas() if canvas else sprite.global_transform
		for corner in [at, at + Vector2(extent.x, 0), at + extent, at + Vector2(0, extent.y)]:
			var point: Vector2 = transform * corner
			if not found:
				bounds = Rect2(point, Vector2.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	return bounds


func _capture(label: String, spec: Dictionary, body: Node2D, source: Node2D, casts: Array[Node2D]) -> void:
	await RenderingServer.frame_post_draw
	var row := {"label": label, "prop": spec.name, "structure": spec.get("structure", false),
		"body_position": str(body.global_position), "source": _visual_record(source),
		"camera_zoom": str(game.camera.zoom), "casts": [], "scenery_hidden": hidden_scenery,
		"process_frame": Engine.get_process_frames()}
	if game.has_method("_shadow_bottom_ratio"):
		row["footprint_ratio"] = float(game.call("_shadow_bottom_ratio", source))
	for cast in casts:
		row.casts.append(_visual_record(cast))
		_check(label + "/cast_behind_prop", cast.z_index < source.z_index)
		if source is AnimatedSprite2D and cast is AnimatedSprite2D:
			_check(label + "/frame_sync", (source as AnimatedSprite2D).frame == (cast as AnimatedSprite2D).frame)
		if cast.has_meta("cast_shadow_mode") and cast.visible:
			for child in body.get_children():
				if child is CanvasItem and child.has_meta("prop_contact_shadow"):
					_check(label + "/ground_contact", child.visible == (String(cast.get_meta("cast_shadow_mode")) == "projected"))
	row["fullframe"] = shot(label, "shared prop factory, native framebuffer")
	var image := capture_image()
	var bounds := _body_bounds(body, true).grow(16.0)
	var crop := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_check(label + "/native_crop", crop.has_area())
	if crop.has_area():
		var path := ProjectSettings.globalize_path(shot_dir.path_join(label + "_close.png"))
		image.get_region(crop).save_png(path)
		row["native_closeup"] = path
		row["crop_rect"] = str(crop)
	row["visual_canvas_bounds"] = str(bounds)
	samples.append(row)
	_write_report()


func _visual_record(sprite: Node2D) -> Dictionary:
	var texture: Texture2D = null
	var frame := 0
	if sprite is Sprite2D:
		texture = (sprite as Sprite2D).texture
		frame = (sprite as Sprite2D).frame
	elif sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		frame = animated.frame
		texture = animated.sprite_frames.get_frame_texture(animated.animation, frame)
	return {"type": sprite.get_class(), "position": str(sprite.position), "scale": str(sprite.scale),
		"rotation": sprite.rotation, "skew": sprite.skew, "offset": str(sprite.get("offset")),
		"flip_h": sprite.get("flip_h"), "frame": frame, "z_index": sprite.z_index,
		"global_transform": str(sprite.global_transform), "modulate": str(sprite.modulate),
		"material": sprite.material.get_class() if sprite.material != null else "none",
		"texture_size": str(texture.get_size()) if texture != null else "null",
		"texture_path": texture.resource_path if texture != null else "null",
		"cast_shadow": sprite.has_meta("cast_shadow"), "projected_scale_y": sprite.scale.y < 0.0,
		"shadow_mode": String(sprite.get_meta("cast_shadow_mode", "projected" if sprite.scale.y < 0.0 else "hug")) if sprite.has_meta("cast_shadow") else "source"}


func _settle() -> void:
	# Several real frames after capture/boot keep camera and animation sampling
	# separate from a long synchronous frame. No speed, shadow or material changes.
	await frames(6)
	var until := Time.get_ticks_msec() + 220
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed:
		failures += 1
		print("PROP SHADOW CHECK FAILED: ", label)


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		print("PROP SHADOW REPORT WRITE FAILED: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"no_saves": game.no_saves, "wander_seed": game.wander_seed,
		"shots": shots_taken, "context_fullframe": ProjectSettings.globalize_path(shot_dir.path_join("00_actual_vigil_gate.png")),
		"room": game.zones[game.cur_room].get("name", ""), "terrain": game.terrain_by_zone[game.cur_room],
		"purpose": "shared shadow geometry and actual interaction captures; visual review remains required",
		"renderer": RenderingServer.get_current_rendering_method(), "scenery_hidden_in_fixture": hidden_scenery,
		"samples": samples, "npc_observations": npc_observations, "checks": checks, "failures": failures}, "\t"))
	file.close()
