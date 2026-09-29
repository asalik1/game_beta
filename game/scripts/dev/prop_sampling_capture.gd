extends RefCounted
## One bundled regression + old/new sampling review, no second engine boot:
## shot.bat polish --prop-sampling --gif --zoom=1.12 --fixed-fps=30 --no-import --timeout=300
## Matched native-size foliage, furniture legs and fire on a matte floor.
## The before is the old effective NEAREST sampler, applied only to disposable
## visuals. Identical authored frames and subpixel camera positions in both.
const FPS := 30
const PAN_FRAMES := 90
const PAN_STEP := Vector2(0.35, 0.12)


static func run(rig: Node) -> String:
	var error := preload("res://scripts/tests/test_prop_shadows.gd").run_sampling()
	if error != "":
		return error
	var g: Game = rig.game
	var visible := g.world.visible
	var process := g.process_mode
	var camera_process := g.camera.process_mode
	var camera_position := g.camera.global_position
	var camera_offset := g.camera.offset
	var ambient := g.ambient.color
	var fixture := Node2D.new()
	rig.add_child(fixture)
	g.world.hide()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	g.camera.offset = Vector2.ZERO
	g.ambient.color = Color.WHITE
	error = await _capture(rig, fixture, camera_position)
	fixture.free()
	g.world.visible = visible
	g.process_mode = process
	g.camera.process_mode = camera_process
	g.camera.global_position = camera_position
	g.camera.offset = camera_offset
	g.camera.force_update_scroll()
	g.ambient.color = ambient
	if error == "":
		print("PROP SAMPLING PASS: fresh-factory regression and matched before/after slow pans")
	return error


static func _capture(rig: Node, fixture: Node2D, center: Vector2) -> String:
	var g: Game = rig.game
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2(-900, -600), Vector2(900, -600), Vector2(900, 600), Vector2(-900, 600)])
	floor.position = center
	floor.color = Color(0.24, 0.27, 0.22)
	floor.z_index = -10
	fixture.add_child(floor)
	var visuals: Array[Node2D] = []
	var filters: Dictionary = {}
	var names := ["tree_green", "camp_workbench", "hideout_table", "camp_bonfire", "book"]
	var positions := [Vector2(-260, -35), Vector2(-60, 35), Vector2(105, 35), Vector2(260, 40), Vector2(0, 140)]
	for i in names.size():
		var src := g._prop_visual(names[i])
		var body := Node2D.new()
		fixture.add_child(body)
		body.position = center + positions[i]
		body.add_child(src)
		src.scale = Vector2.ONE * g._scenery_render_scale(src, names[i])
		if src is AnimatedSprite2D:
			(src as AnimatedSprite2D).pause()
		g._prop_cast_shadow(body, src)
		visuals.append(src)
		for child in body.get_children():
			filters[child] = child.texture_filter
	var root := ProjectSettings.globalize_path(rig.shot_dir)
	for mode in ["before", "after"]:
		rig.step("prop sampling " + mode)
		var folder: String = root + "/gif_sampling_" + mode
		DirAccess.make_dir_recursive_absolute(folder)
		for node in filters:
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if mode == "before" else filters[node]
		for frame in PAN_FRAMES:
			for src in visuals:
				if src is AnimatedSprite2D:
					var anim := src as AnimatedSprite2D
					var phase := float(frame) * anim.sprite_frames.get_animation_speed("default") / FPS
					anim.set_frame_and_progress(int(phase) % anim.sprite_frames.get_frame_count("default"), fposmod(phase, 1.0))
			g.camera.global_position = center + PAN_STEP * frame
			g.camera.force_update_scroll()
			await rig.get_tree().process_frame
			await RenderingServer.frame_post_draw
			if frame % 2 == 0 and (rig.flag("gif") or frame == 0):
				var img: Image = rig.capture_image()
				if img.save_png(folder + "/f_%04d.png" % (frame / 2)) != OK:
					return "could not save sampling capture"
				rig.shots_taken += 1
	return ""
