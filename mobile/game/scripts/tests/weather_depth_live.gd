extends RefCounted
## `shot.bat ambient_life --weather-depth`: production weather, controlled
## safe-room terrain overrides, held-key lateral walking and real room entry.
const Config := preload("res://scripts/tests/test_weather_depth.gd")

static func run(r: Node) -> String:
	var g: Game = r.game
	var error := Config.run(g)
	if error != "": return error
	var keep := {"settings": g.settings.duplicate(true), "terrains": g.terrain_by_zone.duplicate(),
		"room": g.cur_room, "position": g.player.global_position, "processing": g.is_processing(),
		"physics": g.player.is_physics_processing(), "started": g.play_started,
		"visited": g.visited.duplicate(true), "doors": g.door_seen.duplicate(true),
		"safe": g.last_safe_room, "last": g.last_room, "event": g.terrain_event_t,
		"zoom": g.camera.zoom, "smooth": g.camera.position_smoothing_enabled,
		"camera_position": g.camera.position, "camera_offset": g.camera.offset,
		"time_scale": Engine.time_scale, "velocity": g.player.velocity}
	var report := {"checks": 0, "failures": [], "views": [], "probes": [],
		"limits": "Controlled safe rooms with weather-only terrain overrides. Native held-key walking; room changes use production _enter_room. No combat or online session exercised. Frozen rendered clones isolate particle drag, with a local-space positive control."}
	await _execute(r, report)
	_check(report, report.probes.size() == 12, "all six world-space probes and local-space controls completed")
	_press(false)
	g.player.set_physics_process(false)
	g.settings = keep.settings
	g.terrain_by_zone = keep.terrains
	g.player.global_position = keep.position
	g._enter_room(keep.room)
	g.play_started = keep.started
	g.visited = keep.visited
	g.door_seen = keep.doors
	g.last_safe_room = keep.safe
	g.last_room = keep.last
	g.terrain_event_t = keep.event
	g.camera.zoom = keep.zoom
	g.camera.position_smoothing_enabled = keep.smooth
	g.camera.position = keep.camera_position
	g.camera.offset = keep.camera_offset
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	g._update_ambient_fx()
	g.player.velocity = keep.velocity
	g.player.clear_local_intents()
	g.player.set_physics_process(keep.physics)
	g.set_process(keep.processing)
	Engine.time_scale = keep.time_scale
	var file := FileAccess.open(r.shot_dir.path_join("weather.json"), FileAccess.WRITE)
	if file == null: return "cannot write weather report"
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("WEATHER QA: checks=%d failures=%d" % [report.checks, report.failures.size()])
	if report.failures.is_empty():
		print("WEATHER DEPTH PASS: preset budgets, stationary, lateral walk, room transitions and frozen world-space render controls")
		return ""
	return str(report.failures[0])


static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label)
		print("WEATHER FAILURE: " + label)


static func _execute(r: Node, report: Dictionary) -> void:
	var g: Game = r.game
	var rooms: Array[int] = []
	for i in g.zones.size():
		if g.room_safe(i):
			rooms.append(i)
			if rooms.size() == 2: break
	_check(report, rooms.size() == 2, "two safe rooms available")
	if rooms.size() < 2: return
	Engine.time_scale = 1.0
	g.set_process(false)
	g.player.set_physics_process(false)
	g.play_started = false # no first-visit offers/cards during the fixture
	g.settings["camera_shake"] = 0.0
	g.settings["combat_framing"] = false
	g.settings["weather_quality"] = "high"
	g.camera.position_smoothing_enabled = false
	g.camera.zoom = Vector2.ONE
	for terrain in ["storm", "ice", "darkwood"]:
		r.step("weather " + terrain)
		g.player.set_physics_process(false)
		g.terrain_by_zone[rooms[0]] = terrain
		g.terrain_by_zone[rooms[1]] = terrain
		g.player.global_position = g.room_center(rooms[0]) + Vector2(-180, 0)
		g._enter_room(rooms[0])
		await r.skip_dialogue()
		g.camera.force_update_scroll()
		g._update_ambient_fx()
		await _wait(r, 1.0)
		await _view(r, report, terrain + "_stationary")
		for layer in ["distant", "near"]:
			var source: CPUParticles2D = g.ambient_fx_distant if layer == "distant" else g.ambient_fx
			await _drag_probe(r, report, source, terrain + "_" + layer)
		var start := g.player.global_position
		# Production wiring: shove the weather off the camera, then let the game's own
		# _process (which owns the per-frame weather update) pull it back while walking.
		for emitter in [g.ambient_fx, g.ambient_fx_distant]:
			emitter.global_position += Vector2(500, 300)
		g.set_process(true)
		g.player.set_physics_process(true)
		_press(true)
		for frame in 4:
			await _wait(r, 0.25, true)
			for emitter in [g.ambient_fx, g.ambient_fx_distant]:
				_check(report, emitter.global_position.distance_to(g.camera.get_screen_center_position()) < 24.0,
					terrain + " game process keeps weather on the camera")
			_check(report, g.player.intent_move.x > 0.0, terrain + " held key reaches movement intent")
			await _view(r, report, terrain + "_walk_%d" % frame)
		_press(false)
		await r.frames(2)
		g.set_process(false)
		g.player.set_physics_process(false)
		_check(report, g.player.global_position.x - start.x > 100.0, terrain + " hero walks laterally over 100px")
		_check(report, absf(g.player.global_position.y - start.y) < 16.0, terrain + " walk stays lateral")
		var old := [g.ambient_fx, g.ambient_fx_distant]
		# Teleport with production smoothing on: the camera glides from the old room, so
		# weather must be seeded where it will END, not where the glide starts.
		g.camera.position_smoothing_enabled = true
		g.player.global_position = g.room_center(rooms[1])
		g._enter_room(rooms[1])
		g.camera.reset_smoothing()
		g.camera.force_update_scroll()
		g.camera.position_smoothing_enabled = false
		var landed := g.camera.get_screen_center_position()
		var half := g.get_viewport_rect().size / g.camera.zoom * 0.5
		for emitter in [g.ambient_fx, g.ambient_fx_distant]:
			var gap: Vector2 = (emitter.global_position - landed).abs()
			_check(report, gap.x + half.x <= emitter.emission_rect_extents.x + 1.0
				and gap.y + half.y <= emitter.emission_rect_extents.y + 1.0,
				terrain + " teleport weather covers where the camera lands")
		for node in old:
			_check(report, not node.is_inside_tree() and node.is_queued_for_deletion(), terrain + " old room weather retired immediately")
		g.camera.force_update_scroll()
		g._update_ambient_fx()
		await _wait(r, 0.5)
		for node in old:
			_check(report, not is_instance_valid(node), terrain + " old room emitter freed")
		await _view(r, report, terrain + "_room_transition")


## real = leave the frame to the game's own _process (production camera + weather).
static func _wait(r: Node, seconds: float, real := false) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await r.get_tree().process_frame
		if real: continue
		r.game._tick_camera(r.get_process_delta_time())
		r.game.camera.force_update_scroll()
		r.game._update_ambient_fx()


static func _press(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = down
	Input.parse_input_event(event)


static func _view(r: Node, report: Dictionary, label: String) -> void:
	var g: Game = r.game
	await RenderingServer.frame_post_draw
	var spec: Dictionary = Terrains.AMBIENTS[Terrains.get_terrain(g.terrain_by_zone[g.cur_room]).ambient]
	_check(report, g.ambient_fx.amount + g.ambient_fx_distant.amount <= int(spec.amount), label + " bounded total")
	_check(report, g.ambient_fx.global_position.distance_to(g.camera.get_screen_center_position()) < 24.0, label + " camera centered")
	report.views.append({"image": r.shot(label), "hero": str(g.player.global_position),
		"camera": str(g.camera.get_screen_center_position()), "near": g.ambient_fx.amount,
		"distant": g.ambient_fx_distant.amount, "room": g.cur_room})


## Freeze the particle simulation, translate ONLY its source, compare pixels.
## A local-space control must move; world-space output must remain byte-identical.
## Clones keep the production art/size/velocity/count; only emission timing and
## area are tightened so every layer is visibly populated in the probe viewport.
static func _drag_probe(r: Node, report: Dictionary, source: CPUParticles2D, label: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	r.add_child(viewport)
	for local in [false, true]:
		var emitter := source.duplicate() as CPUParticles2D
		emitter.local_coords = local
		emitter.position = Vector2(240, 100)
		emitter.emission_rect_extents = Vector2(40, 30)
		emitter.preprocess = 0.0
		emitter.explosiveness = 1.0
		viewport.add_child(emitter)
		emitter.restart()
		await r.sim_wait(0.15)
		emitter.speed_scale = 0.0
		await r.frames(3)
		await RenderingServer.frame_post_draw
		var before := viewport.get_texture().get_image()
		_check(report, before.get_used_rect().has_area(), label + " visible frozen particles local=" + str(local))
		emitter.position.x += 160.0
		await r.frames(3)
		await RenderingServer.frame_post_draw
		var after := viewport.get_texture().get_image()
		var identical: bool = before.get_data() == after.get_data()
		_check(report, identical != local, label + " frozen particle translation local=" + str(local))
		report.probes.append({"layer": label, "local_control": local, "identical_pixels": identical,
			"painted_rect": str(before.get_used_rect())})
		if not local:
			before.save_png(r.shot_dir.path_join(label + "_frozen_before.png"))
			after.save_png(r.shot_dir.path_join(label + "_frozen_after.png"))
		emitter.free()
	viewport.free()
