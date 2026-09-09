extends ShotRig
## Screenshot the ground FLOOR for a set of terrains, painted onto the room the
## hero is standing in, at NATIVE zoom (1.0) so the floor resolution reads
## honestly next to the crisp props/hero. Validates the authored ground_field
## pipeline (GPU-tiled crisp base + transparent-base detail + road band).
##   shot.bat floorfield --terrains=keep,graveyard,holy --timeout=120
## Default set covers a field kind (keep) and a still-procedural kind (graveyard)
## so both render paths are proven in one run.


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
			finish(1)
			return
		source.generate_mipmaps()
		candidate = ImageTexture.create_from_image(source)
		print("CANDIDATE ONLY: ", candidate_path, " size=", source.get_size(), " world_period=", candidate_period)
	if flag("bypass-canvas-post"):
		game.glow_env.environment.background_mode = Environment.BG_CLEAR_COLOR
	if not await _capture_color_check():
		finish(1)
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
	for tid in arg("terrains", "village,darkwood,desert,ice").split(",", false):
		step("compare " + tid)
		apply_terrain(tid, 2)
		game.terrain_event_t = 10000.0
		game.hazard_tick = 10000.0
		await sim_wait(0.8)
		var terrain := Terrains.get_terrain(tid)
		var kind := String(terrain.ground)
		var field: Polygon2D = game.zone_fields[2]
		var painted: Texture2D = candidate if candidate != null else field.texture
		if painted == null or (candidate == null and not painted.resource_path.ends_with("_painterly.png")):
			push_error("painted field missing for " + kind)
			finish(1)
			return
		if not painted.get_image().has_mipmaps():
			push_error("painted field lacks mipmaps: " + kind)
			finish(1)
			return
		zoom(1.0)
		var before: Texture2D = field.texture if candidate != null else load("res://assets/sprites/ground_field_%s.png" % kind)
		field.texture = before
		if candidate == null:
			field.uv = field.polygon
			field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		await frames(3)
		shot(tid + "_before")
		game._apply_ground_field(2, terrain)
		if candidate != null:
			_candidate_on_field(field, candidate, candidate_period)
		await frames(3)
		shot(tid + "_painted")
		zoom(2.0)
		await frames(3)
		shot(tid + "_painted_detail")
		zoom(1.0)
		game.telegraph(p.global_position + Vector2(-175, -40), 100, 2.0, 0,
			{"net_visual": true, "color": Color(1.0, 0.28, 0.14, 0.6), "shape": "cone", "dir": Vector2.DOWN})
		game.telegraph_safe([p.global_position + Vector2(160, 130)], 90, 2.0, 0,
			{"net_visual": true, "decoys": [p.global_position + Vector2(-190, 140)]})
		await sim_wait(1.25)
		shot(tid + "_combat_readability")
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
					finish(1)
					return
				print("CANDIDATE CAMERA: requested=", offset, " actual_screen_delta=", screen_now - screen_origin)
				shot(tid + ("_candidate_join_x" if offset.x != 0.0 else "_candidate_join_y"))
			game.camera.global_position = camera_origin
			continue
		# A real Codex thumbnail must use the same floor at its world scale.
		var preview := Art.ground_preview(kind, terrain.path, 44, 26, 2007)
		if preview == null:
			push_error("missing terrain preview: " + tid)
			finish(1)
			return
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(4)
	shot("painted_floor_touch")
	if candidate != null:
		print("ok: candidate-only material comparison: calibrated before/after, mipmaps, native/detail, synthetic tells and two-axis joins; not installed or ordinary combat")
		finish()
		return
	game.menus.open_codex("terrains")
	await frames(4)
	shot("painted_terrain_codex")
	game.menus.close()
	game.request_pause(false)
	print("ok: installed painted fields: same-scene before/after, mipmaps, native/detail, synthetic tells, non-null preview API and Codex open, touch layout")
	finish()


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
