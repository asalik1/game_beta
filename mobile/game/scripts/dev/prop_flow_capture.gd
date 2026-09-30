extends RefCounted
## shot.bat polish --liquid-flow --gif --fixed-fps=30 --timeout=180
## Native factories, authored widths and 1x camera. Four loops at real 6fps.
## This controlled fixture proves playback; originals are for visual review.
const NAMES := ["sewer_outfall", "sewer_outfall", "garden_fountain", "capital_crown_fountain"]
const OFFSETS := [-390, -190, 30, 340]
const CAPTURE_FRAMES := 80


static func run(rig: Node) -> String:
	var g: Game = rig.game
	var original := g.world
	var fixture := Node2D.new()
	rig.add_child(fixture)
	original.hide()
	# Keep the fixture processing independently of the frozen campaign.
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	g.world = fixture
	var result: String = await _capture(rig, fixture)
	g.world = original
	fixture.free()
	original.show()
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.camera.process_mode = Node.PROCESS_MODE_INHERIT
	return result


static func _capture(rig: Node, fixture: Node2D) -> String:
	var g: Game = rig.game
	var center := g.room_center(0)
	g.camera.offset = Vector2.ZERO
	g.camera.zoom = Vector2.ONE
	g.camera.global_position = center
	g.camera.limit_left = int(center.x - 900)
	g.camera.limit_right = int(center.x + 900)
	g.camera.limit_top = int(center.y - 600)
	g.camera.limit_bottom = int(center.y + 600)
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	g.ambient.color = Color.WHITE
	var floor_base := Polygon2D.new()
	floor_base.polygon = PackedVector2Array([center + Vector2(-900, -600), center + Vector2(900, -600),
		center + Vector2(900, 600), center + Vector2(-900, 600)])
	floor_base.color = Color(0.16, 0.17, 0.14)
	floor_base.z_index = -100
	fixture.add_child(floor_base)
	var visuals: Array[AnimatedSprite2D] = []
	var transforms: Array[Transform2D] = []
	var seen: Array[Dictionary] = []
	for i in NAMES.size():
		var body: StaticBody2D = g._add_structure(NAMES[i], center + Vector2(OFFSETS[i], 80))
		var visual: AnimatedSprite2D = null
		for child in body.get_children():
			if child is AnimatedSprite2D and not child.has_meta("cast_shadow"):
				visual = child
				break
		if visual == null or not visual.is_playing():
			return NAMES[i] + " is not a playing AnimatedSprite2D"
		if visual.sprite_frames.get_frame_count("default") != 4:
			return NAMES[i] + " is missing its four frames"
		if i < 2 and not is_equal_approx(g._visual_size(visual).x * visual.scale.x, 140.0):
			return "outfall no longer uses its authored 140px width"
		if i == 1: visual.flip_h = not visuals[0].flip_h
		visual.set_frame_and_progress(0, 0.0)
		visuals.append(visual)
		transforms.append(visual.global_transform)
		seen.append({})
	await rig.frames(3)
	var out_dir := ProjectSettings.globalize_path(rig.shot_dir + "/gif_liquid_flow")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in CAPTURE_FRAMES:
		await rig.get_tree().process_frame
		await RenderingServer.frame_post_draw
		for i in visuals.size():
			seen[i][visuals[i].frame] = true
			if visuals[i].global_transform != transforms[i]:
				return NAMES[i] + " moved its rigid transform"
		var img: Image = rig.capture_image()
		img.save_png(out_dir + "/f_%04d.png" % f)
		rig.shots_taken += 1
	for i in seen.size():
		if seen[i].size() != 4: return NAMES[i] + " did not play every frame"
	print("LIQUID FLOW PASS: four native props, all four frames, fixed transforms, outfall 140px, camera 1x")
	return ""
