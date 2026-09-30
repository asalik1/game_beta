extends RefCounted
## Focused native observations. Use shot.bat tells --comet --fixed-fps=30.
## No manual progress assignment: captures sample the production tween/physics.

const Terrain := preload("res://scripts/reactive_terrain.gd")
const Clock := preload("res://scripts/ground_tell.gd")
const RADIUS := 90.0
const FUSE := 2.4
# Optional preview: 81 captured frames at 15fps = one 5.4s intact breath.
const MOTION_PROCESS_FPS := 30.0
const MOTION_STRIDE := 2
const MOTION_FRAMES := 81
var checks: Array = []
var captures: Array = []
var failures := 0
var baseline := false
var motion: Dictionary = {}


## Owner's replacement contract: exact posed fuse samples through the real
## boss style merger and production ground renderer, plus native pixel probes.
## shot.bat tells --urgency --timeout=240
func run_urgency(t: ShotRig) -> String:
	checks.clear()
	captures.clear()
	failures = 0
	t.shot_dir = t.shot_dir.path_join("urgency")
	await t.boot("warrior", "ch1", false)
	var g: Game = t.game
	var saved_pause := t.get_tree().paused
	var saved_position := g.player.global_position
	var saved_camera := g.camera.global_position
	var saved_zoom := g.camera.zoom
	var saved_hud := g.hud.visible
	var saved_smoothing := g.camera.position_smoothing_enabled
	var saved_attacks: Array = g._ground_attacks.duplicate()
	t.get_tree().paused = true
	g.hud.visible = false
	g.camera.position_smoothing_enabled = false
	g.camera.zoom = Vector2.ONE
	var center := saved_position + Vector2(0, -110)
	g.camera.global_position = center
	g.player.global_position = center + Vector2(0, 220)
	# Separate neutral viewport makes opposite samples independent of floor
	# wear, scenery and lighting. It uses the very same production shader.
	# A Godot 4 viewport already owns a fresh World2D (there is no
	# own_world_2d property; only 3D worlds are shared by default).
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	t.add_child(viewport)
	var sample := Clock.new()
	sample.position = Vector2(128, 128)
	sample.radius = RADIUS
	viewport.add_child(sample)
	for kind: String in ["fangmaw", "morwen"]:
		var boss := Boss.new()
		boss.kind = kind
		boss.position = center + Vector2(240, 0)
		var opts := {"net_visual": true, "dir": Vector2.RIGHT}
		boss._apply_tell_style(opts, center)
		boss.free()
		g.telegraph(center, RADIUS, FUSE, 0.0, opts)
		var attack: Node2D = g._ground_attacks.back()
		var tell: Node2D = attack.get_node("GroundTellClock")
		var theme: Color = Color.TRANSPARENT if kind == "fangmaw" else Balance.BOSS_TELL.morwen.color
		sample.tint = tell.tint
		sample.hot_ramp = tell.hot_ramp
		var last := Color.TRANSPARENT
		for phase: float in [0.0, 0.5, 0.9, 1.0]:
			tell.progress = phase
			sample.progress = phase
			var expected := Clock.ramp(theme, phase)
			var actual: Color = tell.get_node("CometRim").material.get_shader_parameter("tint")
			_check(kind + " rim follows ramp", _rgb_near(actual, expected), {"phase": phase})
			for surface: CanvasItem in tell.surfaces:
				_check(kind + " fill/accent follows ramp", _rgb_near(surface.modulate, expected))
			if kind == "morwen":
				_check("Morwen stays green", actual.g > actual.r and actual.g > actual.b
					and absf(actual.h - theme.h) < 0.001)
				if phase > 0.0:
					_check("green saturation and brightness rise", actual.s > last.s and actual.v > last.v)
			elif phase == 0.0:
				_check("Fangmaw begins yellow", actual.r > 0.9 and actual.g > 0.8 and actual.b < 0.5)
			elif phase == 1.0:
				_check("Fangmaw ends red", actual.r > 0.9 and actual.g < 0.2 and actual.b < 0.1)
			last = actual
			await t.frames(2)
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			# Pixel centers mirrored about (128,128): same radius, opposite angle.
			for point: Vector2i in [Vector2i(38, 128), Vector2i(128, 38), Vector2i(64, 64)]:
				var opposite := Vector2i(255, 255) - point
				var a := pixels.get_pixelv(point)
				var b := pixels.get_pixelv(opposite)
				_check(kind + " opposite rim pixels match", _rgb_near(a, b, 0.015)
					and absf(a.a - b.a) < 0.015 and a.a > 0.1, {"phase": phase, "point": str(point)})
			if phase < 1.0:
				captures.append(t.shot("%s_%02d" % [kind, roundi(phase * 100)], "posed exact fuse phase; production tell"))
		attack.queue_free()
		await t.frames(2)
	# All shapes, themes, and intermediate values share the same continuous RGB.
	for shape: String in ["disc", "cone", "line", "ring", "cross", "square"]:
		g.telegraph(center, RADIUS, FUSE, 0.0, {"shape": shape, "color": Balance.BOSS_TELL.morwen.color, "net_visual": true})
		var attack: Node2D = g._ground_attacks.back()
		var tell: Node2D = attack.get_node("GroundTellClock")
		_check(shape + " binds all surfaces", tell.surfaces.size() == (1 if shape == "disc" else 2))
		for phase: float in [0.0, 0.5, 1.0]:
			tell.progress = phase
			for surface: CanvasItem in tell.surfaces:
				_check(shape + " RGB", _rgb_near(surface.modulate, Clock.ramp(tell.tint, phase)))
		attack.queue_free()
		await t.frames(1)
	# Pale-floor legibility (review round 1): a primed Rimeheart draws no fill,
	# so its edge is the whole warning, and Whitepelt is the palest boss tell.
	# Same exact posed phases on real ice; the dark keyline must hold the edge.
	var zi: int = g.cur_room
	var saved_flags: Dictionary = g.flags.duplicate(true)
	t.apply_terrain("ice", zi)
	# After the repaint: it rebuilds the room's scenery, so an earlier copy
	# would hold freed props.
	var saved_scenery: Array = g.zone_scenery.get(zi, []).duplicate()
	# Room camera limits can clamp the view away from `center`: frame both
	# subjects on the world point actually drawn at the middle of the screen.
	var vp := g.get_viewport()
	var view: Vector2 = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
	var rime: StaticBody2D = Terrain.install(g, zi, 9902, "rime", view + Vector2(-260, 0))
	rime.set_physics_process(false)
	var primed: bool = rime.prime()
	_check("Rimeheart primes on ice", primed and is_instance_valid(rime.clock))
	var pale_opts := {"net_visual": true, "dir": Vector2.RIGHT}
	var pelt := Boss.new()
	pelt.kind = "whitepelt"
	pelt._apply_tell_style(pale_opts, center)
	pelt.free()
	g.telegraph(view + Vector2(300, 0), RADIUS, FUSE, 0.0, pale_opts)
	var pale_attack: Node2D = g._ground_attacks.back()
	var pale_tell: Node2D = pale_attack.get_node("GroundTellClock")
	for phase: float in [0.0, 0.5, 0.9]:
		pale_tell.progress = phase
		if is_instance_valid(rime.clock):
			rime.clock.progress = phase
			var rime_tint: Color = rime.clock.get_node("CometRim").material.get_shader_parameter("tint")
			_check("Rimeheart rim follows its frost ramp", _rgb_near(rime_tint,
				Clock.ramp(Terrain.TYPES.rime.color, phase)), {"phase": phase})
		await t.frames(2)
		captures.append(t.shot("pale_floor_%02d" % roundi(phase * 100),
			"primed Rimeheart (left) and Whitepelt (right) on ice; posed exact fuse phase"))
	pale_attack.queue_free()
	rime.queue_free()
	await t.frames(2)
	g.zone_scenery[zi] = saved_scenery
	g.flags = saved_flags
	for row: Dictionary in Balance.BOSS_TELL.values():
		var theme: Color = row.color
		var previous := Clock.ramp(theme, 0.0)
		for i in range(1, 101):
			var color := Clock.ramp(theme, float(i) / 100.0)
			_check("theme hue preserved without steps", absf(color.h - theme.h) < 0.001
				and _rgb_near(color, previous, 0.03))
			previous = color
	_check("nine phase captures", captures.size() == 9)
	# Restore every borrowed world/presentation field even when checks failed.
	viewport.queue_free()
	await t.frames(2)
	_check("owned attacks retired", g._ground_attacks == saved_attacks)
	g.player.global_position = saved_position
	g.camera.global_position = saved_camera
	g.camera.zoom = saved_zoom
	g.camera.position_smoothing_enabled = saved_smoothing
	g.hud.visible = saved_hud
	t.get_tree().paused = saved_pause
	var report := {"checks": checks, "failures": failures, "captures": captures,
		"method": "production boss style and ground renderer; exact posed phases; native opposite pixel samples",
		"limitations": ["not ordinary live combat", "no remote peer connected"]}
	var file := FileAccess.open(t.shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		return "could not write urgency observations"
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("URGENCY CHECKS: %d checks, %d failures, %d captures" % [checks.size(), failures, captures.size()])
	return "" if failures == 0 else "%d urgency checks failed" % failures


func _rgb_near(a: Color, b: Color, tolerance := 0.001) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func run(t: ShotRig) -> String:
	baseline = t.flag("baseline")
	t.shot_dir = t.shot_dir.path_join("comet")
	await t.boot("warrior", "ch1", false)
	var g: Game = t.game
	_check("isolated no-save fixture", g.no_saves)
	_check("fixture starts unpaused", not t.get_tree().paused)
	if not g.no_saves or t.get_tree().paused:
		return "comet fixture requires a no-save, unpaused game"
	var saved_flags: Dictionary = g.flags.duplicate(true)
	var saved_settings: Dictionary = g.settings.duplicate(true)
	var saved_root: float = g.player.rooted_time
	var saved_hp: float = g.player.hp
	g.settings["camera_shake"] = 0.0
	g.settings["hit_stop"] = false
	g.camera.position_smoothing_enabled = false
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	g.player.global_position = g.room_center(2)
	g._enter_room(2)
	await t.skip_dialogue()
	for group: String in ["enemies", "projectiles", "reactive_terrain"]:
		for node: Node in t.get_tree().get_nodes_in_group(group):
			node.queue_free()
	g.zone_alive[2] = 0
	g.cleared[2] = true
	g.boss_spawned[2] = true
	g.player.set_physics_process(false)
	g.player.rooted_time = 0.0
	t.hide_hud()
	t.zoom(1.0)
	await t.frames(2)
	var error: String = await _visuals(t)
	# Cleanup also runs after any observation failure.
	t.get_tree().paused = false
	g.cancel_ground_attacks()
	for prop: Node in t.get_tree().get_nodes_in_group("reactive_terrain"):
		prop.queue_free()
	await t.frames(2)
	g.flags = saved_flags
	g.settings = saved_settings
	g.player.rooted_time = saved_root
	g.player.hp = saved_hp
	# This isolated presentation fixture clears encounter props for framing.
	# Retire invalid references; restoring a pre-clear array would revive them.
	for zi in g.zone_scenery:
		var live_scenery: Array = []
		for item in g.zone_scenery[zi]:
			if is_instance_valid(item):
				live_scenery.append(item)
		g.zone_scenery[zi] = live_scenery
	_check("all ground attacks retired", g._ground_attacks.is_empty())
	_check("fifteen native captures", captures.size() == 15, {"count": captures.size()})
	if error != "":
		_check(error, false)
	var report := {"rig": "tells_comet", "complete": error == "", "baseline": baseline,
		"renderer": RenderingServer.get_current_rendering_method(), "no_saves": g.no_saves,
		"checks": checks, "failures": failures, "captures": captures,
		"limitations": ["fixed-fps native phase samples, not an FPS benchmark", "QA room/position setup; no ordinary combat claim",
			"idle series uses actual physics; terrain/falling warnings use actual production calls",
			"root must reject shader errors from both renderer output streams"], "sources": {}}
	if not motion.is_empty():
		report["motion"] = motion
	for path: String in ["res://scripts/ground_tell.gd", "res://shaders/ground_comet.gdshader",
		"res://scripts/reactive_terrain.gd", "res://scripts/game_base.gd", "res://scripts/balance.gd",
		"res://scripts/tests/comet_ground_live.gd", "res://shot_tells.gd"]:
		report.sources[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(t.shot_dir))
	var file := FileAccess.open(t.shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		return "could not write comet observations"
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("COMET CHECKS: %d checks, %d failures, %d captures" % [checks.size(), failures, captures.size()])
	return "" if failures == 0 else "%d comet checks failed" % failures


func _visuals(t: ShotRig) -> String:
	var g: Game = t.game
	var center: Vector2 = g.room_center(2)
	g.camera.global_position = center
	g.player.global_position = center + Vector2(0, 190)
	for terrain: String in ["keep", "ice", "magma"]:
		t.step("comet phases on " + terrain)
		t.apply_terrain(terrain, 2)
		g.terrain_event_t = 10000.0
		g.hazard_tick = 10000.0
		await t.sim_wait(0.3)
		g.telegraph(center + Vector2(-240, -40), RADIUS, FUSE, 0.0,
			{"net_visual": true, "color": Color(1.0, 0.35, 0.18, 0.6)})
		var hostile: Node2D = g._ground_attacks.back()
		var clock: Node2D = hostile.get_node("GroundTellClock")
		g.telegraph_safe([center + Vector2(0, -40)], RADIUS, FUSE, 0.0,
			{"net_visual": true, "decoys": [center + Vector2(240, -40)]})
		var shelter: Node2D = g._ground_attacks.back()
		var previous := -1.0
		for phase: float in [0.15, 0.5, 0.82]:
			if not await _wait_progress(t, clock, phase):
				return "warning retired before the requested phase"
			var clocks: Array = _clocks(hostile) + _clocks(shelter)
			_check("three clocks " + terrain, clocks.size() == 3)
			for row: Dictionary in clocks:
				_check("original radius " + terrain, is_equal_approx(float(row.radius), RADIUS), row)
			_check("clock advances " + terrain, float(clock.progress) > previous,
				{"previous": previous, "progress": clock.progress, "target": phase})
			previous = float(clock.progress)
			await _capture(t, "%s_phase_%02d" % [terrain, roundi(phase * 100)], {"clocks": clocks})
			if terrain == "keep" and phase == 0.15:
				await _pause_check(t, clock, "attack tween")
		g.cancel_ground_attacks()
		await t.frames(2)
		_check("phase attack cancelled " + terrain, not is_instance_valid(clock))

	t.step("intact Cask natural breath")
	t.apply_terrain("keep", 2)
	g.terrain_event_t = 10000.0
	g.player.global_position = center + Vector2(-65, 0)
	var prop: StaticBody2D = Terrain.install(g, 2, 9901, "ember", center)
	var marker: Node2D = prop.get_node_or_null("ReactiveReadyMarker")
	_check("analytic intact marker present", baseline or marker != null,
		{"present": marker != null, "baseline": baseline})
	var last_progress := -1.0
	var last_alpha := -1.0
	for frame: int in 4:
		await t.sim_wait(0.18)
		var details := {"phase": prop.phase, "remaining": prop.remaining,
			"marker_present": marker != null, "physics_frame": Engine.get_physics_frames()}
		if marker != null:
			# The visible term: the whole ring's alpha, uniform around the circle.
			var rim: Polygon2D = marker.get_node("CometRim")
			var alpha: float = float(rim.material.get_shader_parameter("signal_alpha"))
			details["marker_progress"] = marker.progress
			details["marker_signal_alpha"] = alpha
			_check("intact breath phase advances", float(marker.progress) > last_progress, details)
			_check("intact ring breathes", not is_equal_approx(alpha, last_alpha), details)
			_check("intact ring keeps its theme tint", _rgb_near(rim.material.get_shader_parameter("tint"),
				Terrain.TYPES.ember.color), details)
			last_progress = float(marker.progress)
			last_alpha = alpha
		await _capture(t, "intact_breath_%02d" % frame, details)
	if t.flag("motion"):
		if baseline or marker == null:
			return "motion preview requires the revised intact marker"
		var motion_error: String = await _record_motion(t, prop, marker)
		if motion_error != "":
			return motion_error
	if marker != null:
		await _pause_check(t, marker, "intact prop physics")
	var primed: bool = prop.prime()
	_check("production prime succeeds", primed)
	if not primed:
		return "could not prime the observed Cask"
	await t.frames(3)
	if not is_instance_valid(prop.clock):
		return "primed Cask clock missing"
	_check("prop keeps original fuse and radius", prop.phase == 1 and prop.remaining > 0.0
		and prop.remaining <= Balance.REACTIVE_FUSE and is_equal_approx(float(prop.clock.radius), Balance.REACTIVE_RADIUS),
		{"phase": prop.phase, "remaining": prop.remaining, "radius": prop.clock.radius})
	if marker != null:
		_check("idle marker hidden during danger", not marker.visible)
	await _pause_check(t, prop.clock, "primed prop physics")
	prop.queue_free()
	await t.frames(2)

	t.step("actual falling fireball warning")
	g.player.global_position = center
	g.player.rooted_time = 0.0
	g.telegraph(center, RADIUS, FUSE, 0.0, {"fireball": true, "root": 2.0,
		"color": Color(1.0, 0.4, 0.18, 0.6)})
	var attack: Node2D = g._ground_attacks.back()
	var falling_clock: Node2D = attack.get_node("GroundTellClock")
	var falling: Sprite2D
	for child: Node in attack.get_children():
		if child is Sprite2D and child.z_index == Balance.FALLING_OBJECT_Z_INDEX:
			falling = child
	_check("production falling sprite present", is_instance_valid(falling))
	if not is_instance_valid(falling):
		return "falling sprite missing"
	var last_y: float = falling.position.y
	for phase: float in [0.3, 0.78]:
		if not await _wait_progress(t, falling_clock, phase):
			return "falling warning retired before capture"
		var falling_y: float = falling.position.y
		_check("falling object descends", falling_y > last_y, {"previous_y": last_y, "y": falling_y})
		last_y = falling_y
		await _capture(t, "falling_phase_%02d" % roundi(phase * 100),
			{"clocks": _clocks(attack), "falling_position": [falling.position.x, falling.position.y]})
	g.cancel_ground_attacks()
	await t.sim_wait(FUSE + 0.2)
	_check("cancel retires falling object and warning", not is_instance_valid(falling) and not is_instance_valid(falling_clock))
	_check("cancel prevents pending root", g.player.rooted_time == 0.0)
	return ""


func _wait_progress(t: ShotRig, clock: Node2D, target: float) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while is_instance_valid(clock) and float(clock.progress) < target:
		if Time.get_ticks_msec() > deadline:
			return false
		await t.frames(1)
	return is_instance_valid(clock)


func _clocks(attack: Node2D) -> Array:
	var result: Array = []
	for child: Node in attack.get_children():
		if child.get_script() == Clock:
			var row := {"radius": child.radius, "progress": child.progress,
				"safe": child.safe, "decoy": child.decoy,
				"position": [child.global_position.x, child.global_position.y]}
			var rim: Polygon2D = child.get_node_or_null("CometRim")
			row["analytic"] = rim != null
			if rim != null:
				row["shader_radius"] = rim.material.get_shader_parameter("radius")
				var shader_tint: Color = rim.material.get_shader_parameter("tint")
				var theme: Color = Color.TRANSPARENT if child.hot_ramp else child.tint
				var expected: Color = child.tint if child.orbit_only else Clock.ramp(theme, child.progress)
				row["shader_tint"] = [shader_tint.r, shader_tint.g, shader_tint.b]
				_check("shader follows authoritative clock", is_equal_approx(float(row.shader_radius), float(child.radius))
					and _rgb_near(shader_tint, expected), row)
			_check("analytic warning present", baseline or rim != null, row)
			result.append(row)
	return result


func _pause_check(t: ShotRig, clock: Node2D, label: String) -> void:
	t.get_tree().paused = true
	var before: float = clock.progress
	await t.get_tree().create_timer(0.25, true).timeout
	_check(label + " pauses", is_instance_valid(clock) and is_equal_approx(float(clock.progress), before),
		{"before": before, "after": clock.progress if is_instance_valid(clock) else -1.0})
	t.get_tree().paused = false


func _capture(t: ShotRig, name: String, details: Dictionary) -> void:
	t.get_tree().paused = true
	await t.frames(2)
	var path: String = t.shot(name)
	captures.append({"name": name, "path": path, "process_frame": Engine.get_process_frames(), "details": details})
	t.get_tree().paused = false


func _check(label: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"check": label, "passed": passed, "details": details})
	if not passed:
		failures += 1
		print("COMET CHECK FAILED: ", label, " ", JSON.stringify(details))


## Optional artifact only: native crops, no pause, no extra t.shot count, no
## manual progress assignment. Run --comet --motion --fixed-fps=30 --timeout=360.
func _record_motion(t: ShotRig, prop: StaticBody2D, marker: Node2D) -> String:
	var balance_script: Script = load("res://scripts/balance.gd")
	var constants: Dictionary = balance_script.get_script_constant_map()
	var period: float = float(constants.get("REACTIVE_MARKER_BREATHE_SECONDS", 0.0))
	var expected_seconds := MOTION_FRAMES * MOTION_STRIDE / MOTION_PROCESS_FPS
	_check("motion spans one configured breath", is_equal_approx(period, expected_seconds),
		{"configured_period": period, "capture_seconds": expected_seconds})
	if not is_equal_approx(period, expected_seconds):
		return "motion sampling no longer matches the intact marker period"
	var directory: String = t.shot_dir.path_join("gif_intact_breath")
	var absolute: String = ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		return "motion directory already exists; use a fresh isolated profile"
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return "could not create motion capture directory"
	await RenderingServer.frame_post_draw
	var start_progress: float = marker.progress
	var previous_progress := start_progress
	var previous_frame: int = Engine.get_process_frames()
	var elapsed := 0.0
	var frame_rows: Array = []
	motion = {"complete": false, "directory": absolute, "fps": MOTION_PROCESS_FPS / MOTION_STRIDE,
		"configured_period": period, "start_progress": start_progress, "frames": frame_rows,
		"method": "native ShotRig HDR-correct capture cropped in engine; real physics progress; no pause"}
	t.step("one native intact breath")
	for index: int in MOTION_FRAMES:
		for _tick: int in MOTION_STRIDE:
			await t.frames(1)
			var delta: float = t.get_process_delta_time()
			if absf(delta - 1.0 / MOTION_PROCESS_FPS) > 0.0001:
				return "motion preview requires --fixed-fps=30"
			elapsed += delta
		# The marker uniform and the viewport are now from the same drawn frame.
		await RenderingServer.frame_post_draw
		if not is_instance_valid(prop) or not is_instance_valid(marker) or t.get_tree().paused:
			return "motion subject retired or paused during its breath"
		var progress: float = marker.progress
		var advance := fposmod(progress - previous_progress, 1.0)
		var expected_advance := MOTION_STRIDE / MOTION_PROCESS_FPS / period
		var current_frame: int = Engine.get_process_frames()
		_check("native motion phase spacing", absf(advance - expected_advance) <= 0.003,
			{"frame": index, "previous": previous_progress, "progress": progress, "advance": advance})
		_check("native motion frame spacing", current_frame - previous_frame == MOTION_STRIDE,
			{"frame": index, "previous_process_frame": previous_frame, "process_frame": current_frame})
		var image: Image = t.capture_image()
		var screen: Vector2 = prop.get_global_transform_with_canvas().origin
		var crop := Rect2i(Vector2i(screen) + Vector2i(-144, -152), Vector2i(288, 240))
		if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(crop):
			return "native motion crop leaves the viewport"
		var frame_path: String = absolute.path_join("f_%04d.png" % index)
		if image.get_region(crop).save_png(frame_path) != OK:
			return "could not save native breath motion frame"
		frame_rows.append({"index": index, "path": frame_path, "progress": progress,
			"process_frame": current_frame, "physics_frame": Engine.get_physics_frames(),
			"elapsed_sim": elapsed, "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
			"radius": marker.radius, "prop_phase": prop.phase})
		previous_frame = current_frame
		previous_progress = progress
	_check("native motion contains 81 frames", frame_rows.size() == MOTION_FRAMES)
	_check("native motion retains intact prop", prop.phase == 0)
	_check("native motion lasts one breath", absf(elapsed - period) <= 0.0001,
		{"elapsed_sim": elapsed, "configured_period": period})
	motion["elapsed_sim"] = elapsed
	motion["end_progress"] = marker.progress
	motion["complete"] = true
	return ""
