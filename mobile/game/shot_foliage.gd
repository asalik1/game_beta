extends ShotRig
## One locked run: regression plus real input walking through planted bushes.
## shot.bat foliage --no-import --fixed-fps=30 --timeout=240


func _ready() -> void:
	await boot("warrior", "ch1")
	await sim_wait(2.0)
	var error: String = await preload("res://scripts/tests/test_world_read.gd").foliage(self)
	if error != "":
		print("FOLIAGE FAIL: " + error)
		finish(1)
		return
	error = await _walkthrough()
	if error != "": print("FOLIAGE CAPTURE FAIL: " + error)
	finish(0 if error == "" else 1)


func _walkthrough() -> String:
	var p := game.player
	var kept_pos := p.position
	var kept_mask := p.collision_mask
	var kept_zoom := game.camera.zoom
	var kept_camera_position := game.camera.position
	var kept_hud := game.hud.visible
	var kept_smoothing := game.camera.position_smoothing_enabled
	var kept_game_process := game.is_processing()
	# Controlled road fixture: real movement input/animation; no incidental
	# obstacle can block this demonstration. Restore the loan even on failure.
	p.collision_mask = 0
	hide_hud()
	zoom(2.0)
	game.camera.position_smoothing_enabled = false
	var start := p.global_position
	var plants: Array[Node2D] = []
	for i in 3:
		var plant := game._prop_visual(["bush", "bush3", "bush_autumn"][i])
		var size := game._visual_size(plant)
		plant.scale = Vector2.ONE * (100.0 / size.x)
		plant.position = start + Vector2(110 + i * 70, -size.y * plant.scale.y * 0.30)
		plant.z_index = -1
		game.world.add_child(plant)
		plants.append(plant)
	await frames(3)
	# Fixed camera keeps the stationary bushes easy to compare through time.
	game.set_process(false)
	game.camera.global_position = start + Vector2(140, 0)
	var dir := ProjectSettings.globalize_path(shot_dir + "/gif_walkthrough")
	DirAccess.make_dir_recursive_absolute(dir)
	var seen_rustle := false
	for i in 120:
		if i == 25: _walk_key(true)
		if i == 75: _walk_key(false)
		await get_tree().process_frame
		game.camera.global_position = start + Vector2(140, 0)
		await RenderingServer.frame_post_draw
		for plant in plants:
			if float(plant.material.get_shader_parameter("amp")) > 0.0:
				seen_rustle = true
		# Raw readback like shot_polish's GIF frames: capture_image()'s HDR
		# conversion is a per-pixel script loop, too slow to repeat for 120
		# frames under the watchdog. Motion review, not color review.
		get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [dir, i])
	var traveled := p.global_position.distance_to(start)
	var settled := true
	for plant in plants:
		settled = settled and float(plant.material.get_shader_parameter("amp")) == 0.0
		plant.free()
	_walk_key(false)
	p.position = kept_pos
	p.collision_mask = kept_mask
	game.camera.zoom = kept_zoom
	game.camera.position = kept_camera_position
	game.camera.position_smoothing_enabled = kept_smoothing
	game.set_process(kept_game_process)
	game.hud.visible = kept_hud
	if not seen_rustle or traveled < 260.0 or not settled:
		return "walk distance=%.1f rustled=%s settled=%s" % [traveled, seen_rustle, settled]
	print("FOLIAGE CAPTURE PASS: 120 frames, real walk input, distance=%.1f, rustled and settled; %s" % [traveled, dir])
	return ""


func _walk_key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = down
	Input.parse_input_event(event)
