extends RefCounted
## shot.bat framing --impacts --no-import: frame-by-frame offset capture.
## Scripted production shake calls isolate camera response from damage RNG;
## boss footfalls use the same strength as the production footstep caller.

const SHAKE_STATE := ["shake_amt", "_shake_kick", "_shake_time", "_shake_in_amt", "_shake_in_kick"]


static func run(r: ShotRig) -> String:
	var g: Game = r.game
	var saved := {}
	for key in SHAKE_STATE + ["terrain_event_t", "hazard_tick"]:
		saved[key] = g.get(key)
	var settings := g.settings.duplicate(true)
	var offset := g.camera.offset
	var fps := Engine.max_fps
	var physics := Engine.physics_ticks_per_second
	var scale := Engine.time_scale
	var vsync := DisplayServer.window_get_vsync_mode()
	var actors := {}
	for actor in r.get_tree().get_nodes_in_group("enemies") + [g.local_player]:
		actors[actor] = actor.is_physics_processing()
		actor.set_physics_process(false)
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	g.settings["hit_stop"] = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.time_scale = 1.0
	var error: String = preload("res://scripts/tests/test_framing.gd").shake_contracts(g)
	var captures: Array[Dictionary] = []
	if error == "":
		for hz in [30, 60, 144]:
			Engine.max_fps = hz
			Engine.physics_ticks_per_second = hz
			await r.frames(4)
			for gain in [1.0, 0.0]:
				r.step("camera impacts %d Hz / comfort %.0f%%" % [hz, gain * 100.0])
				var capture := await _sequence(r, hz, gain)
				captures.append(capture)
				if capture.error != "" and error == "": error = capture.error
	# Restore on every assertion failure too. Each sequence waits out its real
	# hit-stop before returning, so no timer can overwrite the restored scale.
	for actor in actors:
		if is_instance_valid(actor): actor.set_physics_process(actors[actor])
	for key in saved: g.set(key, saved[key])
	g.settings = settings
	g.camera.offset = offset
	Engine.max_fps = fps
	Engine.physics_ticks_per_second = physics
	Engine.time_scale = scale
	DisplayServer.window_set_vsync_mode(vsync)
	if captures.size() == 6:
		for index in [2, 4]:
			var first := captures[index]
			var base := captures[0]
			# Impulses show at full size on their first rendered frame, so the
			# impact itself must match exactly across rates. The whole-sequence
			# peak also depends on where the ambient waveform sits on the frames
			# each rate happens to draw; it is receipt-only.
			var recoil_delta := (first.recoil_first as Vector2).distance_to(base.recoil_first)
			var saturated_delta := (first.saturated_first as Vector2).distance_to(base.saturated_first)
			print("CAMERA RATE COMPARISON %d vs 30 Hz: first-frame recoil delta=%.5f px saturated delta=%.5f px sequence peak delta=%.4f px recovery delta=%.4f s" % [
				first.hz, recoil_delta, saturated_delta, float(first.peak) - float(base.peak),
				float(first.recovery) - float(base.recovery)])
			if recoil_delta > 0.001 or saturated_delta > 0.001:
				error = "first-frame impact size depends on the render rate"
			if absf(float(first.recovery) - float(base.recovery)) > 0.1:
				error = "render-rate recovery diverged by more than 100 ms"
	var path := r.shot_dir.path_join("camera_impacts.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write camera impact frame capture"
	file.store_string(JSON.stringify({"error": error, "captures": captures,
		"scope": "Production shake/tick/framing and real solo hit-stop; scripted hit, heavy-beat and boss-footfall strengths, frozen actors. Numeric rendered-frame captures, not an earned combat encounter."}, "\t"))
	file.close()
	print("CAMERA IMPACT CAPTURE: ", ProjectSettings.globalize_path(path))
	if error == "": print("CAMERA IMPACTS PASS: 30/60/144 Hz, full-size first frames, rapid hits, heavy beat, boss steps, 0% comfort and hit-stop recovery")
	return error


static func _sequence(r: ShotRig, hz: int, gain: float) -> Dictionary:
	var g: Game = r.game
	g.shake_amt = 0.0
	g._shake_kick = Vector2.ZERO
	g._shake_in_amt = 0.0
	g._shake_in_kick = Vector2.ZERO
	g._shake_time = 0.0
	g.settings["camera_shake"] = gain
	# From rest: a lone recoil, then a saturated recoil with a real hit-stop
	# (each must show at full size on its first frame). Then six rapid
	# strikes, the heaviest authored beat (mage meteor, shake 14) and three
	# boss footfalls.
	var events := [[0.05, "recoil"], [0.5, "saturated"], [1.0, "hit"], [1.08, "hit"],
		[1.16, "hit"], [1.24, "hit"], [1.32, "hit"], [1.4, "hit"], [1.7, "heavy"],
		[1.9, "step"], [2.1, "step"], [2.3, "step"]]
	var recoil := Vector2(Balance.HIT_SHAKE_KICK, 0.0) * gain
	var saturated := Vector2(0.0, -Balance.CAMERA_SHAKE_KICK_MAX_PX) * gain
	var event := 0
	var kind := ""
	var elapsed := 0.0
	var last_event := 0.0
	var recovery := -1.0
	var peak := 0.0
	var hits_peak := 0.0
	var heavy_peak := 0.0
	var recoil_first := Vector2(INF, INF)
	var saturated_first := Vector2(INF, INF)
	var frozen_frames := 0
	var previous_frozen := false
	var previous_offset := Vector2.ZERO
	var error := ""
	var samples: Array[Dictionary] = []
	var wall_start := Time.get_ticks_usec()
	while elapsed < 3.0:
		await r.get_tree().process_frame
		var delta := r.get_process_delta_time()
		elapsed += delta
		var fired := ""
		while event < events.size() and elapsed >= float(events[event][0]):
			fired = String(events[event][1])
			match fired:
				"recoil":
					g.shake(0.0, Vector2.RIGHT, Balance.HIT_SHAKE_KICK)
				"saturated":
					g.shake(0.0, Vector2.UP, Balance.CAMERA_SHAKE_KICK_MAX_PX * 2.0)
					g.hit_stop(0.12)
				"hit":
					g.shake(Balance.HIT_SHAKE, Vector2.RIGHT, Balance.HIT_SHAKE_KICK)
				"heavy":
					g.shake(14.0)
				_:
					g.shake(Balance.BOSS_STEP_SHAKE)
			kind = fired
			last_event = elapsed
			event += 1
		await RenderingServer.frame_post_draw
		var offset := g.camera.offset
		if fired == "recoil":
			recoil_first = offset
		elif fired == "saturated":
			saturated_first = offset
		var frozen: bool = g._hitstop_active and delta == 0.0
		if frozen:
			frozen_frames += 1
			if not offset.is_equal_approx(saturated):
				error = "real hit-stop did not hold the impact at full size"
			if previous_frozen and offset.distance_to(previous_offset) > 0.0001:
				error = "rendered waveform moved during real hit-stop"
		previous_frozen = frozen
		previous_offset = offset
		peak = maxf(peak, offset.length())
		if kind == "hit": hits_peak = maxf(hits_peak, offset.length())
		if kind == "heavy": heavy_peak = maxf(heavy_peak, offset.length())
		if offset.length() > Balance.CAMERA_SHAKE_MAX_PX + 0.0001:
			error = "rendered impacts exceeded the total displacement cap"
		if gain == 0.0 and offset != Vector2.ZERO:
			error = "0% comfort produced nonzero rendered displacement"
		if event == events.size() and recovery < 0.0 and g.shake_amt == 0.0 and g._shake_kick == Vector2.ZERO:
			recovery = elapsed - last_event
		samples.append({"t": elapsed, "dt": delta, "offset": [offset.x, offset.y], "frozen": frozen, "event": fired})
	var wall_seconds := float(Time.get_ticks_usec() - wall_start) / 1000000.0
	if not recoil_first.is_equal_approx(recoil):
		error = "the first rendered frame showed the hit recoil below full size"
	if not saturated_first.is_equal_approx(saturated):
		error = "the first rendered frame did not show the saturated recoil at the kick cap"
	if frozen_frames < 2: error = "did not observe enough real hit-stop frames"
	if g._hitstop_active or Engine.time_scale != 1.0: error = "hit-stop did not release cleanly"
	if recovery < 0.0 or recovery > 0.7 or g.camera.offset != Vector2.ZERO:
		error = "camera failed to recover after the final footfall"
	if gain > 0.0 and hits_peak < Balance.HIT_SHAKE_KICK:
		error = "scripted strikes never reached the rendered camera"
	if gain > 0.0 and heavy_peak <= hits_peak:
		error = "the heaviest beat shook less than a run of ordinary hits"
	print("CAMERA IMPACT %d Hz gain=%.1f: first recoil=%.4f px saturated=%.4f px hits peak=%.4f px heavy peak=%.4f px sequence peak=%.4f px recovery=%.4f s observed=%.1f fps frozen=%d" % [
		hz, gain, recoil_first.length(), saturated_first.length(), hits_peak, heavy_peak, peak,
		recovery, samples.size() / wall_seconds, frozen_frames])
	return {"hz": hz, "gain": gain, "peak": peak, "hits_peak": hits_peak, "heavy_peak": heavy_peak,
		"recoil_first": recoil_first, "saturated_first": saturated_first, "recovery": recovery,
		"observed_fps": samples.size() / wall_seconds, "frozen_frames": frozen_frames,
		"error": error, "samples": samples}
