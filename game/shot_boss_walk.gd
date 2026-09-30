extends ShotRig
## shot.bat boss_walk --fixed-fps=60 --no-import --timeout=240
## Presentation-only straight-line fixture, no AI/camera/collision/party state.
## Real strip loader, Enemy scale/anchor/render tail; 61 consecutive 1x frames.
## Checks the source strips (test_boss_walk) and the rendered feet line per tick.
const Walk := preload("res://scripts/tests/test_boss_walk.gd")
const Ch2 := preload("res://scripts/content/ch2_bosses.gd")
const SAMPLE_FPS := 60
const SAMPLE_COUNT := 61
var bodies: Array[Enemy] = []
var samples: Array = []
var traces: Array = []


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.12)
	background.size = Vector2(1280, 720)
	add_child(background)
	var errors := []
	for i in Walk.CASES.size():
		var key: String = Walk.CASES[i][0]
		var direction: String = Walk.CASES[i][1]
		var stats: Dictionary = Story.ENEMIES.get(key, Ch2.ENEMIES.get(key, {}))
		# Korrag's encounter key differs from its sprite key.
		if stats.is_empty():
			for candidate: Dictionary in Ch2.ENEMIES.values():
				if candidate.get("sprite", "") == key:
					stats = candidate
		var e := Enemy.new()
		e._sprite_key = key
		e._gait_shape = Art.gait_shape(key)
		e.art_scale = float(stats.scale)
		e.render_mult = Balance.CHAR_RENDER_SCALE
		e.speed = float(stats.speed)
		e.velocity = Vector2.RIGHT * e.speed
		e.sprite = Sprite2D.new()
		e.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		e.add_child(e.sprite)
		e._strip_idle = Art.anim_info(key)
		e._apply_strip(e._strip_idle)
		var info: Dictionary = Art.walk_info(key) if direction == "" else Art.dir_set(key + "_walk_codex")[direction]
		e._apply_strip(info)
		e.position = Vector2(200 + (i % 2) * 630, 190 + (i / 2) * 335)
		add_child(e)
		# READY re-enables physics for any script with _physics_process, so turn
		# it off after entering the tree: this fixture has no game for the AI.
		e.set_physics_process(false)
		bodies.append(e)
		var metrics := Walk.measure(e.sprite.texture)
		samples.append(metrics)
		var error := Walk.check(key, metrics)
		if error != "":
			errors.append(error)
		var label := Label.new()
		label.text = "%s %s  %d frames / %.0f fps / speed %.0f" % [key, direction, e.anim_frames,
			e.anim_fps * Balance.MOB_WALK_CLOCK, e.speed]
		label.position = Vector2(20 + (i % 2) * 630, 20 + (i / 2) * 335)
		add_child(label)
	# Rendered feet line relative to the node, per boss: last value and max step.
	var feet_last: Array[float] = []
	var feet_steps: Array[float] = []
	feet_last.resize(bodies.size())
	feet_steps.resize(bodies.size())
	# Include t=0 and the loop wrap; nominal 60 Hz via runner, Engine.time_scale=1.
	for tick in SAMPLE_COUNT:
		await get_tree().process_frame
		for i in bodies.size():
			var e := bodies[i]
			if tick > 0:
				e.position += e.velocity / SAMPLE_FPS
				e.anim_t += Balance.MOB_WALK_CLOCK / SAMPLE_FPS
			e.sprite.frame = int(e.anim_t * e.anim_fps) % e.anim_frames
			# No world fixture: suppress only the dust/audio callback, not body motion.
			e._steps = e.anim_t * e.anim_fps * 2.0 / e.anim_frames
			e._render_tail(1.0 / SAMPLE_FPS, true)
			var m: Dictionary = samples[i][e.sprite.frame]
			var center := e.sprite.to_global(Vector2(m.cx, m.cy) - Vector2.ONE * float(m.cell) / 2.0 + e.sprite.offset)
			var upper := e.sprite.to_global(Vector2(m.upper_cx, m.upper_cy) - Vector2.ONE * float(m.cell) / 2.0 + e.sprite.offset)
			var feet := e.sprite.to_global(Vector2(0, float(m.feet) - float(m.cell) / 2.0) + e.sprite.offset)
			# Source strips can be clean while the render path (strip offset or the
			# _render_tail feet pin) makes the feet pop, so check what is drawn too.
			var feet_residual := feet.y - e.position.y
			if tick > 0:
				feet_steps[i] = maxf(feet_steps[i], absf(feet_residual - feet_last[i]))
			feet_last[i] = feet_residual
			traces.append({"boss": e._sprite_key, "tick": tick, "time": float(tick) / SAMPLE_FPS,
				"frame": e.sprite.frame, "node_x": e.position.x, "node_y": e.position.y,
				"center_x": center.x, "center_y": center.y, "feet_x": feet.x, "feet_y": feet.y,
				"upper_x": upper.x, "upper_y": upper.y,
				"scale_x": e.sprite.scale.x, "scale_y": e.sprite.scale.y,
				"offset_y": e.sprite.offset.y, "rotation": e.sprite.rotation, "source": m})
		await RenderingServer.frame_post_draw
		shot("f_%04d" % tick)
	for i in bodies.size():
		var key := bodies[i]._sprite_key
		print("WALK RENDER %s feet_step_px=%.3f" % [key, feet_steps[i]])
		if feet_steps[i] > Balance.BOSS_WALK_RENDER_FEET_STEP_MAX:
			errors.append("%s: rendered feet-line step %.3f px > %.3f px" % [key, feet_steps[i],
				Balance.BOSS_WALK_RENDER_FEET_STEP_MAX])
	var file := FileAccess.open(shot_dir.path_join("trajectory.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": SAMPLE_FPS, "traces": traces, "errors": errors}, "\t"))
	file.close()
	for error: String in errors:
		print("BOSS WALK REGRESSION FAIL: " + error)
	if errors.is_empty():
		print("BOSS WALK REGRESSION PASS")
	finish(0 if errors.is_empty() else 1)
