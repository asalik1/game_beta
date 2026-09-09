extends ShotRig
## Candidate-only diagnostic; publish to game/ before using the muted runner.
## shot.bat pebble_prop --baseline --timeout=240 [--touch]
## Five terrain backdrops, seven posed captures; no gameplay/collision claim.

const WORLD_SEED := 903127
const TERRAINS := ["graveyard", "village", "darkwood", "desert", "ice"]
const COLUMN_X := [-165.0, 0.0, 165.0]
const ROW_Y := [-60.0, 0.0, 60.0]
var checks: Array[Dictionary] = []
var views: Array[Dictionary] = []
var ambient_settling: Array[Dictionary] = []
var specimens: Array[Dictionary] = []
var failures := 0
var origin := Vector2.ZERO
var original: Texture2D
var candidate: Texture2D
var original_signature: Dictionary = {}
var overlay: CanvasLayer
var caption: Label
var column_labels: Array[Label] = []
var row_labels: Array[Label] = []


func _ready() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _check("isolated_qa_directory", user_path.to_lower().contains("/build/qa/"), user_path):
		finish(1)
		return
	get_window().size = Vector2i(1280, 720)
	seed(WORLD_SEED)
	await boot("warrior", "ch3")
	game.play_started = true
	game.state = Game.ST_PLAYING
	game.menus.close()
	game.request_pause(false)
	game.settings["combat_framing"] = false
	game.settings["camera_shake"] = 0.0
	game.camera.position_smoothing_enabled = false
	game.settings["touch_controls"] = flag("touch")
	game.refresh_touch_mode()
	game._apply_touch_mode()
	if not await _settle_reveal():
		_complete()
		return
	_check("isolated_muted_boot", game.no_saves and not game.net_online() and AudioServer.is_bus_mute(0))
	_check("native_viewport", get_viewport().get_visible_rect().size == Vector2(1280, 720))
	_check("logical_family_unchanged", Terrains.prop_base("pebble") == "pebble" and not Terrains.SOLID_DECOR.has("pebble"))
	original = Art.tex("pebble")
	candidate = Art.tex("rock2")
	if not _check("reference_textures", original != null and candidate != null):
		_complete()
		return
	original_signature = _signature(original)
	_check("direct_pebble_reference_dimensions", original.get_size() == Vector2(128, 104))
	_check("rock2_reference_dimensions", candidate.get_size() == Vector2(160, 110))
	_check("distinct_reference_resources", original != candidate)
	_check("logical_authored_width", float(Balance.SCENERY_RENDER_WIDTH.get("pebble", 0.0)) == 24.0)
	origin = game.room_center(game.cur_room)
	game.player.global_position = origin + Vector2(220, 130)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	# Stop root gameplay/camera/timers only after the real reveal completes.
	# Children still render terrain shaders/ambient presentation normally.
	game.set_process(false)
	game.set_physics_process(false)
	hide_hud()
	_build_labels()
	for terrain_id in TERRAINS:
		await _terrain_case(String(terrain_id))
	_check("direct_pebble_still_same_resource", Art.tex("pebble") == original)
	_check("direct_pebble_pixels_unchanged", _signature(Art.tex("pebble")) == original_signature)
	_check("seven_complete_views", views.size() == 7)
	_complete()


func _terrain_case(terrain_id: String) -> void:
	step("pebble backdrop " + terrain_id)
	seed(WORLD_SEED)
	# Use the real repaint without ShotRig.apply_terrain's immediate color
	# assignment: that assignment races the real Game's local mood tween.
	game.apply_terrain(game.cur_room, terrain_id)
	game.terrain_event_t = 1.0e9
	game.hazard_tick = 1.0e9
	game.npc_emote_t = 1.0e9
	# Actual floor/road/ambient tint, but hide generated clutter to compare
	# these explicitly placed specimens. This is not an authored biome room.
	for node in game.zone_scenery.get(game.cur_room, []):
		if is_instance_valid(node) and node is CanvasItem:
			(node as CanvasItem).visible = false
	_clear_specimens()
	if not await _settle_ambient(terrain_id):
		return
	var variations := [Balance.SCENERY_SCALE_JITTER.x, 1.0, Balance.SCENERY_SCALE_JITTER.y]
	for row in ROW_Y.size():
		# The actual column uses its real anchor for the production hash. The
		# two reference columns deliberately reuse it for like-for-like lean,
		# mirror and value; their display positions differ only by column.
		var variation_anchor := origin + Vector2(float(COLUMN_X[0]), float(ROW_Y[row]))
		for column in COLUMN_X.size():
			var vis: Node2D
			if column == 0:
				vis = game._prop_visual("pebble")
			else:
				var reference := Sprite2D.new()
				reference.texture = original if column == 1 else candidate
				vis = reference
			if not _check(terrain_id + "/static_specimen_%d_%d" % [row, column], vis is Sprite2D and (vis as Sprite2D).texture != null):
				vis.free()
				continue
			var native: Vector2 = game._visual_size(vis)
			var variation := float(variations[row])
			var scale_value: float = game._scenery_render_scale(vis, "pebble", variation)
			var anchor := origin + Vector2(float(COLUMN_X[column]), float(ROW_Y[row]))
			vis.scale = Vector2.ONE * scale_value
			vis.position = anchor - Vector2(0, native.y * scale_value * 0.5 - 5.0)
			vis.z_index = -8
			game._apply_scenery_variation(vis, "pebble", variation_anchor)
			game.world.add_child(vis)
			var tex := (vis as Sprite2D).texture
			var resolved := "pebble" if tex == original else ("rock2" if tex == candidate else "unknown")
			var label := "%s/r%d/c%d" % [terrain_id, row, column]
			_check(label + "/width", is_equal_approx(native.x * absf(vis.scale.x), 24.0 * variation))
			_check(label + "/bottom_before_lean", is_equal_approx(vis.position.y + native.y * scale_value * 0.5, anchor.y + 5.0))
			if column == 0:
				_check(label + "/known_actual_texture", resolved != "unknown")
				if not flag("baseline"):
					_check(label + "/optimized_texture_identity", tex == candidate)
			var data := {"column": column, "row": row, "logical_key": "pebble", "resolved_texture_key": resolved,
				"source_asset": "res://assets/sprites/%s.png" % resolved if resolved != "unknown" else "",
				"texture_resource_path": tex.resource_path, "actual_factory": column == 0,
				"reference_only": column != 0, "texture_dimensions": _xy(tex.get_size()), "frame_dimensions": _xy(native),
				"world_dimensions_before_lean": _xy(native * scale_value), "variation": variation,
				"anchor": _xy(anchor), "variation_anchor": _xy(variation_anchor), "position": _xy(vis.position),
				"scale": _xy(vis.scale), "rotation": vis.rotation, "modulate": [vis.modulate.r, vis.modulate.g, vis.modulate.b, vis.modulate.a],
				"texture_filter": vis.texture_filter, "frame": (vis as Sprite2D).frame, "hframes": (vis as Sprite2D).hframes,
				"vframes": (vis as Sprite2D).vframes}
			specimens.append({"node": vis, "data": data})
	_check(terrain_id + "/nine_specimens", specimens.size() == 9)
	await _capture_case(terrain_id, 1.0)
	if terrain_id in ["graveyard", "ice"]:
		await _capture_case(terrain_id, 2.0)


func _capture_case(terrain_id: String, camera_zoom: float) -> void:
	zoom(camera_zoom)
	game.camera.global_position = origin
	game.camera.force_update_scroll()
	await frames(5)
	var actual_items: Array[Dictionary] = []
	for specimen in specimens:
		var vis: Sprite2D = specimen["node"] as Sprite2D
		var data: Dictionary = specimen["data"].duplicate(true)
		var screen_box := vis.get_global_transform_with_canvas() * vis.get_rect()
		data["screen_aabb"] = [screen_box.position.x, screen_box.position.y, screen_box.size.x, screen_box.size.y]
		data["screen_dimensions_before_lean"] = _xy(game._visual_size(vis) * vis.scale.abs() * camera_zoom)
		data["visible"] = vis.is_visible_in_tree()
		_check(terrain_id + "/on_screen_%s_%s_%s" % [camera_zoom, data.row, data.column],
			vis.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(screen_box))
		actual_items.append(data)
	for column in COLUMN_X.size():
		var point := origin + Vector2(float(COLUMN_X[column]), -105)
		column_labels[column].position = game.world.get_global_transform_with_canvas() * point - Vector2(75, 10)
	for row in ROW_Y.size():
		var point := origin + Vector2(-260, float(ROW_Y[row]) - 4)
		row_labels[row].position = game.world.get_global_transform_with_canvas() * point - Vector2(65, 8)
	caption.text = "PEBBLE MATERIAL QA — %s — camera %.1fx\nPosed god-stats fixture; isolated, clutter hidden; no combat/collision proof.\nLeft: actual factory | Center: unchanged original | Right: proposed rock2 reference" % [terrain_id, camera_zoom]
	await frames(2)
	await RenderingServer.frame_post_draw
	var id := terrain_id + ("_native" if camera_zoom == 1.0 else "_detail_2x")
	var target: Color = Terrains.get_terrain(terrain_id)["tint"]
	var actual: Color = game.ambient.color
	# Verify the exact rendered-frame state again; never save an off-target
	# image as one of the intended-biome appearance cases.
	if not _check(id + "/ambient_at_capture", _color_near(actual, target),
		{"target": _rgba(target), "actual": _rgba(actual)}):
		return
	var path := shot(id, "three labeled 24px logical-width columns; settled terrain tint; synthetic placement and god stats")
	var ground := String(Terrains.get_terrain(terrain_id)["ground"])
	var field: Texture2D = Art.ground_field(ground)
	views.append({"id": id, "capture": path, "terrain_backdrop": terrain_id,
		"actual_room_name": String(game.zones[game.cur_room].get("name", "")), "camera_zoom": _xy(game.camera.zoom),
		"camera_screen_center": _xy(game.camera.get_screen_center_position()), "hero_position": _xy(game.player.global_position),
		"hero_hp": game.player.hp, "hero_mp": game.player.mp,
		"ambient": _rgba(actual), "ambient_target": _rgba(target), "ambient_settled": _color_near(actual, target),
		"ground": ground, "ground_source": field.resource_path if field != null else "",
		"ground_period": Art.ground_field_period(ground), "specimens": actual_items})


func _build_labels() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 180
	add_child(overlay)
	caption = _label("", Vector2(1160, 82))
	caption.position = Vector2(60, 10)
	var names := ["ACTUAL factory", "ORIGINAL pebble", "CANDIDATE rock2"]
	for text_value in names:
		column_labels.append(_label(String(text_value), Vector2(150, 30)))
	for text_value in ["min jitter", "24px base", "max jitter"]:
		row_labels.append(_label(String(text_value), Vector2(130, 24)))


func _label(value: String, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = value
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.77))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	overlay.add_child(label)
	return label


func _signature(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var img := tex.get_image()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(img.get_data())
	return {"size": _xy(tex.get_size()), "format": img.get_format(), "mipmaps": img.has_mipmaps(),
		"pixel_sha256": hash_context.finish().hex_encode()}


func _clear_specimens() -> void:
	for item in specimens:
		var node: Node = item["node"]
		if is_instance_valid(node):
			node.queue_free()
	specimens.clear()


func _settle_reveal() -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	var stable := 0
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		var pending := game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active
		for child in game.hud.get_children():
			if child is Cutscene:
				pending = true
		pending = pending or (is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible)
		pending = pending or game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01
		stable = 0 if pending else stable + 1
		if stable >= 3:
			break
	return _check("real_reveal_settled", stable >= 3)


func _settle_ambient(terrain_id: String) -> bool:
	# Game.apply_terrain owns a local (unexposed) 0.6s ambient tween. There
	# is no ambient-tween field to await, so observe its actual target color.
	# A fixed timer or frame count can pass while a long frame stalls a tween.
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
		stable = stable + 1 if _color_near(actual, target) else 0
		if stable >= 3:
			break
	var receipt := {"terrain": terrain_id, "target": _rgba(target), "actual": _rgba(actual),
		"settled": stable >= 3, "stable_frames": stable, "observed_process_frames": observed_frames,
		"elapsed_wall_msec": Time.get_ticks_msec() - start, "timeout_msec": 8000,
		"rgba_absolute_tolerance": 0.0001, "forced_color": false}
	ambient_settling.append(receipt)
	return _check(terrain_id + "/ambient_target_settled", stable >= 3, receipt)


func _color_near(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.0001 and absf(actual.g - expected.g) <= 0.0001 \
		and absf(actual.b - expected.b) <= 0.0001 and absf(actual.a - expected.a) <= 0.0001


func _rgba(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


func _xy(value: Vector2) -> Array:
	return [value.x, value.y]


func _check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "pass": passed, "detail": detail})
	if not passed:
		failures += 1
		print("PEBBLE CHECK FAILED: ", label, " ", detail)
	return passed


func _complete() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var report := {"checks": checks, "failures": failures, "views": views, "ambient_settling": ambient_settling, "baseline": flag("baseline"),
		"fixture": "One isolated Game; god stats and fixed specimens on repainted real floor/tint; normal HUD hidden; no ordinary combat or collision claim.",
		"world_seed": WORLD_SEED, "source_world_sha256": FileAccess.get_sha256("res://scripts/game_world.gd"),
		"script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"renderer": RenderingServer.get_current_rendering_method(), "touch_mode": game.touch_mode if game != null else false,
		"project_default_texture_filter": ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		"direct_pebble_reference": original_signature,
		"source_pebble_sha256": FileAccess.get_sha256("res://assets/sprites/pebble.png"),
		"source_rock2_sha256": FileAccess.get_sha256("res://assets/sprites/rock2.png")}
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	_clear_specimens()
	print("PEBBLE PROP: %d checks, %d failures, %d posed views" % [checks.size(), failures, views.size()])
	finish(1 if failures > 0 else 0)
