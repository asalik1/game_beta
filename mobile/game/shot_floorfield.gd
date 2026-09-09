extends ShotRig
## Screenshot the ground FLOOR for a set of terrains, painted onto the room the
## hero is standing in, at NATIVE zoom (1.0) so the floor resolution reads
## honestly next to the crisp props/hero. Validates the authored ground_field
## pipeline (GPU-tiled crisp base + transparent-base detail + road band).
##   shot.bat floorfield --terrains=keep,graveyard,holy --timeout=120
## Default set covers a field kind (keep) and a still-procedural kind (graveyard)
## so both render paths are proven in one run.


var ambient_settling: Array[Dictionary] = []
var material_views: Array[Dictionary] = []
var material_signatures: Dictionary = {}
var external_candidate: Texture2D
var external_candidate_path := ""


func _ready() -> void:
	await boot("warrior", "ch1")
	if flag("compare"):
		await _compare_painted()
		return
	hide_hud()
	zoom(1.0)
	var ids := arg("terrains", "keep,graveyard").split(",", false)
	var burst := int(arg("burst", "0"))   # >0: capture a frame series (for a motion GIF)
	for tid in ids:
		step("paint " + tid)
		apply_terrain(tid, game.cur_room)
		await sim_wait(0.5)
		if burst > 0:
			for i in burst:
				await sim_wait(0.09)
				shot("burst_%s_%02d" % [tid, i], "terrain=" + tid)
		else:
			shot("floor_" + tid, "terrain=" + tid)
	finish()


## Same room, props, camera and light; only the field texture changes.
## shot.bat floorfield --compare --timeout=180 [--mobile]
func _compare_painted() -> void:
	# Candidate review loads a preserved master without installing it, changing
	# Art's cache, or claiming that the production/Codex path uses it already.
	var candidate: Texture2D = null
	var candidate_path := arg("candidate", "")
	var candidate_period := float(arg("period", "512"))
	if candidate_path != "":
		var source := Image.load_from_file(candidate_path)
		if source == null or source.is_empty() or not is_finite(candidate_period) or candidate_period <= 0.0:
			push_error("invalid external floor candidate or period")
			_finish_compare(1)
			return
		source.generate_mipmaps()
		candidate = ImageTexture.create_from_image(source)
		external_candidate = candidate
		external_candidate_path = candidate_path
		print("CANDIDATE ONLY: ", candidate_path, " size=", source.get_size(), " world_period=", candidate_period)
	if flag("bypass-canvas-post"):
		game.glow_env.environment.background_mode = Environment.BG_CLEAR_COLOR
	if not await _capture_color_check():
		_finish_compare(1)
		return
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	var p := game.player
	p.set_physics_process(false)
	game.talked_to_elder = true
	game.set_flag("met_elder")
	p.global_position = game.room_center(2) + Vector2(0, 210)
	game._enter_room(2)
	await skip_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	await sim_wait(4.5)
	game.camera.global_position = p.global_position
	var enemy := spawn_enemy("beastkin_raider", p.global_position + Vector2(145, -80))
	enemy.set_physics_process(false)
	var terrain_ids := arg("terrains", "village,darkwood,desert,ice").split(",", false)
	if terrain_ids.is_empty():
		push_error("floor comparison requires at least one terrain")
		_finish_compare(1)
		return
	for tid in terrain_ids:
		step("compare " + tid)
		# Observe the real local fade; do not race it with the ShotRig color override.
		game.apply_terrain(2, tid)
		game.terrain_event_t = 10000.0
		game.hazard_tick = 10000.0
		if not await _settle_ambient(tid):
			_finish_compare(1)
			return
		var terrain := Terrains.get_terrain(tid)
		var kind := String(terrain.ground)
		var field: Polygon2D = game.zone_fields.get(2) as Polygon2D
		if field == null:
			push_error("missing material field for " + tid)
			_finish_compare(1)
			return
		var painted: Texture2D = candidate if candidate != null else field.texture
		if painted == null or (candidate == null and not painted.resource_path.ends_with("_painterly.png")):
			push_error("painted field missing for " + kind)
			_finish_compare(1)
			return
		if not painted.get_image().has_mipmaps():
			push_error("painted field lacks mipmaps: " + kind)
			_finish_compare(1)
			return
		zoom(1.0)
		var before: Texture2D = field.texture if candidate != null else load("res://assets/sprites/ground_field_%s.png" % kind)
		field.texture = before
		if candidate == null:
			field.uv = field.polygon
			field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		await frames(3)
		if not await _material_shot(tid + "_before", tid):
			_finish_compare(1)
			return
		game._apply_ground_field(2, terrain)
		if candidate != null:
			_candidate_on_field(field, candidate, candidate_period)
		await frames(3)
		if not await _material_shot(tid + "_painted", tid):
			_finish_compare(1)
			return
		zoom(2.0)
		await frames(3)
		if not await _material_shot(tid + "_painted_detail", tid):
			_finish_compare(1)
			return
		zoom(1.0)
		game.telegraph(p.global_position + Vector2(-175, -40), 100, 2.0, 0,
			{"net_visual": true, "color": Color(1.0, 0.28, 0.14, 0.6), "shape": "cone", "dir": Vector2.DOWN})
		game.telegraph_safe([p.global_position + Vector2(160, 130)], 90, 2.0, 0,
			{"net_visual": true, "decoys": [p.global_position + Vector2(-190, 140)]})
		await sim_wait(1.25)
		if not await _material_shot(tid + "_combat_readability", tid):
			_finish_compare(1)
			return
		game.cancel_ground_attacks()
		if candidate != null:
			# Move only the diagnostic camera to inspect both tile axes. Posed
			# actors and synthetic tells establish appearance, not combat feel.
			var camera_origin := game.camera.global_position
			var screen_origin := p.get_global_transform_with_canvas().origin
			for offset in [Vector2(candidate_period * 0.5, 0), Vector2(0, -candidate_period * 0.5)]:
				game.camera.global_position = camera_origin + offset
				await frames(4)
				var screen_now := p.get_global_transform_with_canvas().origin
				var moved: float = absf(screen_now.x - screen_origin.x) if offset.x != 0.0 else absf(screen_now.y - screen_origin.y)
				if moved < minf(80.0, candidate_period * 0.25):
					push_error("candidate camera sweep was clamped before crossing a visible material span")
					_finish_compare(1)
					return
				print("CANDIDATE CAMERA: requested=", offset, " actual_screen_delta=", screen_now - screen_origin)
				if not await _material_shot(tid + ("_candidate_join_x" if offset.x != 0.0 else "_candidate_join_y"), tid):
					_finish_compare(1)
					return
			game.camera.global_position = camera_origin
			continue
		# A real Codex thumbnail must use the same floor at its world scale.
		var preview := Art.ground_preview(kind, terrain.path, 44, 26, 2007)
		if preview == null:
			push_error("missing terrain preview: " + tid)
			_finish_compare(1)
			return
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(4)
	if not await _material_shot("painted_floor_touch", String(game.terrain_by_zone[2])):
		_finish_compare(1)
		return
	if candidate != null:
		print("ok: candidate-only material comparison: calibrated before/after, mipmaps, native/detail, synthetic tells and two-axis joins; not installed or ordinary combat")
		_finish_compare()
		return
	game.menus.open_codex("terrains")
	await frames(4)
	shot("painted_terrain_codex")
	game.menus.close()
	game.request_pause(false)
	print("ok: installed painted fields: same-scene before/after, mipmaps, native/detail, synthetic tells, non-null preview API and Codex open, touch layout")
	_finish_compare()


func _candidate_on_field(field: Polygon2D, tex: Texture2D, period: float) -> void:
	field.texture = tex
	var uv := PackedVector2Array()
	for point in field.polygon:
		uv.append(point * float(tex.get_width()) / period)
	field.uv = uv
	field.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A known UI swatch catches missing/doubled gamma conversion in screenshots.
func _capture_color_check() -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var colors := [Color(0.5, 0.25, 0.75, 1.0), Color(0.025, 0.035, 0.055, 1.0), Color(0.12, 0.18, 0.3, 1.0)]
	for i in colors.size():
		var rect := ColorRect.new()
		rect.color = colors[i]
		rect.position = Vector2(400 + i * 100, 250)
		rect.size = Vector2(80, 80)
		layer.add_child(rect)
	await frames(3)
	var captured := capture_image()
	layer.queue_free()
	await frames(2)
	var measured := []
	for i in colors.size():
		var actual := captured.get_pixel(440 + i * 100, 290)
		var wanted: Color = colors[i]
		measured.append(actual)
		if absf(actual.r - wanted.r) > 0.006 or absf(actual.g - wanted.g) > 0.006 or absf(actual.b - wanted.b) > 0.006:
			push_error("screenshot color-space mismatch: expected " + str(wanted) + ", got " + str(actual))
			return false
	print("ok: screenshot sRGB calibration (midtone + near-black) ", measured, " renderer=", RenderingServer.get_current_rendering_method())
	return true


## The production repaint owns an unexposed 0.6s ambient tween. Match the
## installed pebble QA's bounded observation, without forcing any color.
func _settle_ambient(terrain_id: String) -> bool:
	var target: Color = Terrains.get_terrain(terrain_id)["tint"]
	var start := Time.get_ticks_msec()
	var deadline := start + 8000
	var stable := 0
	var observed_frames := 0
	var actual: Color = game.ambient.color
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		observed_frames += 1
		actual = game.ambient.color
		if Time.get_ticks_msec() >= deadline:
			break # A stalled frame cannot complete the sample set after timeout.
		stable = stable + 1 if _color_near(actual, target) else 0
		if stable >= 3:
			break
	var receipt := {"terrain": terrain_id, "target": _rgba(target), "actual": _rgba(actual),
		"settled": stable >= 3, "stable_frames": stable, "observed_process_frames": observed_frames,
		"elapsed_wall_msec": Time.get_ticks_msec() - start, "timeout_msec": 8000,
		"rgba_absolute_tolerance": 0.0001, "forced_color": false}
	ambient_settling.append(receipt)
	print("FLOOR AMBIENT: ", JSON.stringify(receipt))
	if stable < 3:
		push_error("floor ambient target did not settle: " + terrain_id)
	return stable >= 3


func _color_near(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.0001 and absf(actual.g - expected.g) <= 0.0001 \
		and absf(actual.b - expected.b) <= 0.0001 and absf(actual.a - expected.a) <= 0.0001


func _rgba(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


## Receipts describe the actual field at capture, including the legacy Before
## texture in installed mode and the empty resource_path of an ImageTexture.
func _material_shot(id: String, terrain_id: String) -> bool:
	await RenderingServer.frame_post_draw
	var field: Polygon2D = game.zone_fields.get(2) as Polygon2D
	if field == null or field.texture == null or field.polygon.size() != 4 or field.uv.size() != 4:
		push_error("invalid four-corner field at capture: " + id)
		return false
	var target: Color = Terrains.get_terrain(terrain_id)["tint"]
	var actual: Color = game.ambient.color
	var signature := _texture_signature(field.texture)
	if signature.is_empty():
		return false
	var polygon: Array = []
	var uv: Array = []
	for i in 4:
		polygon.append([field.polygon[i].x, field.polygon[i].y])
		uv.append([field.uv[i].x, field.uv[i].y])
	var world_x := field.to_global(field.polygon[1]).distance_to(field.to_global(field.polygon[0]))
	var world_y := field.to_global(field.polygon[3]).distance_to(field.to_global(field.polygon[0]))
	var uv_x := field.uv[1].distance_to(field.uv[0])
	var uv_y := field.uv[3].distance_to(field.uv[0])
	if world_x <= 0.0 or world_y <= 0.0 or uv_x <= 0.0 or uv_y <= 0.0:
		push_error("degenerate material UVs at capture: " + id)
		return false
	var kind := String(Terrains.get_terrain(terrain_id)["ground"])
	var receipt := {"id": id, "terrain": terrain_id, "ground": kind, "texture": signature,
		"polygon": polygon, "uv": uv, "field_position": [field.position.x, field.position.y],
		"measured_uv_world_period": [field.texture.get_width() * world_x / uv_x, field.texture.get_height() * world_y / uv_y],
		"configured_ground_period": Art.ground_field_period(kind), "requested_candidate_period": float(arg("period", "512")),
		"texture_filter": field.texture_filter, "texture_repeat": field.texture_repeat,
		"field_modulate": _rgba(field.modulate), "field_self_modulate": _rgba(field.self_modulate),
		"ambient_actual": _rgba(actual), "ambient_target": _rgba(target), "ambient_settled": _color_near(actual, target),
		"camera_zoom": [game.camera.zoom.x, game.camera.zoom.y], "touch_mode": game.touch_mode,
		"capture": ""}
	material_views.append(receipt)
	if not _color_near(actual, target):
		push_error("refusing off-target floor capture: " + id)
		return false
	receipt["capture"] = shot(id)
	print("FLOOR MATERIAL: ", JSON.stringify(receipt))
	return _write_compare_report(false, -1)


func _texture_signature(tex: Texture2D) -> Dictionary:
	var key := tex.get_instance_id()
	if material_signatures.has(key):
		return material_signatures[key]["receipt"]
	var external: bool = external_candidate != null and tex == external_candidate
	var source_path: String = external_candidate_path if external else tex.resource_path
	var source_hash := FileAccess.get_sha256(source_path)
	var pixels: Image = tex.get_image()
	if source_path == "" or source_hash.length() != 64 or pixels == null:
		push_error("missing material source/hash/image for " + source_path)
		return {}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pixels.get_data())
	var receipt := {"resource_path": tex.resource_path, "source_path": source_path, "source_file_sha256": source_hash,
		"external_candidate": external, "texture_class": tex.get_class(), "texture_instance_id": key,
		"dimensions": [tex.get_width(), tex.get_height()], "image_dimensions": [pixels.get_width(), pixels.get_height()],
		"image_format": pixels.get_format(), "image_has_mipmaps": pixels.has_mipmaps(),
		"image_data_sha256": digest.finish().hex_encode()}
	# Keep exact texture identity alive; do not alias signatures through a RID.
	material_signatures[key] = {"texture": tex, "receipt": receipt}
	return receipt


func _write_compare_report(complete: bool, exit_code: int) -> bool:
	var path := shot_dir.path_join("observations.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write floor comparison report: " + path)
		return false
	file.store_string(JSON.stringify({"complete": complete, "exit_code": exit_code,
		"scope": "Repainted room 2; frozen actors/god stats and synthetic tells; host renderer, not ordinary combat or device proof",
		"candidate_only": external_candidate != null, "candidate_path": external_candidate_path,
		"candidate_changes_Art_cache": false, "no_saves": game.no_saves,
		"renderer": RenderingServer.get_current_rendering_method(), "script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"ambient_settling": ambient_settling, "material_views": material_views}, "\t"))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written:
		push_error("failed writing floor comparison report: " + path)
	return written


func _finish_compare(exit_code := 0) -> void:
	var written := _write_compare_report(exit_code == 0, exit_code)
	finish(exit_code if written else 1)
