extends RefCounted

const Framing := preload("res://scripts/camera_framing.gd")
const Trail := preload("res://scripts/health_trail.gd")


static func run(t: Node) -> String:
	var error := _presentation()
	if error == "":
		error = shake_contracts(t.game)
	if error == "":
		error = preload("res://scripts/tests/test_camera_corridor.gd").run(t)
	if error == "":
		error = _motion(t.game)
	if error == "":
		print("ok: target camera bounds, health-trail identity/heals and finite movement recovery")
	return error


const SHAKE_STATE := ["shake_amt", "_shake_kick", "_shake_time", "_shake_in_amt", "_shake_in_kick"]


static func shake_contracts(g: Game) -> String:
	var saved := {"settings": g.settings.duplicate(true)}
	for key in SHAKE_STATE:
		saved[key] = g.get(key)
	# The wiring check runs the real camera tick at zero delta (no easing).
	var cam := g.camera
	var framing: RefCounted = g.camera_framing
	var view := {"offset": cam.offset, "position": cam.position, "zoom": cam.zoom,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom],
		"look": g._cam_look, "mult": g._cam_zoom_mult, "room": framing.room,
		"hero": framing.hero_id, "previous": framing.previous,
		"eased": framing.limits}
	var error := _shake_contracts(g)
	for key in saved:
		g.set(key, saved[key])
	cam.offset = view.offset
	cam.position = view.position
	cam.zoom = view.zoom
	cam.limit_left = view.limits[0]
	cam.limit_top = view.limits[1]
	cam.limit_right = view.limits[2]
	cam.limit_bottom = view.limits[3]
	g._cam_look = view.look
	g._cam_zoom_mult = view.mult
	framing.room = view.room
	framing.hero_id = view.hero
	framing.previous = view.previous
	framing.limits = view.eased
	return error


static func _rest(g: Game, clock := 0.0) -> void:
	g.shake_amt = 0.0
	g._shake_kick = Vector2.ZERO
	g._shake_in_amt = 0.0
	g._shake_in_kick = Vector2.ZERO
	g._shake_time = clock


## Largest rendered offset of one beat from rest, sampled finely for 0.5 s.
static func _peak(g: Game, amount: float, kick: float, clock: float) -> float:
	_rest(g, clock)
	g.shake(amount, Vector2.RIGHT, kick)
	var peak := 0.0
	for i in 121:
		g._tick_shake(0.0 if i == 0 else 1.0 / 240.0)
		peak = maxf(peak, g._shake_offset().length())
	return peak


static func _shake_contracts(g: Game) -> String:
	# Own every initial condition: no reliance on the preceding campaign.
	g.settings["camera_shake"] = 1.0
	_rest(g)
	for i in 100:
		g.shake(Balance.HIT_SHAKE_CRIT, Vector2.DOWN, Balance.HIT_SHAKE_KICK)
	g._tick_shake(0.0)
	if g._shake_kick.length() > Balance.CAMERA_SHAKE_KICK_MAX_PX + 0.0001 \
			or g._shake_offset().length() > Balance.CAMERA_SHAKE_MAX_PX + 0.0001:
		return "rapid impacts exceeded the total displacement cap"
	# The heaviest authored beat on top of a saturated recoil: the SUM clamps.
	g.shake(14.0)
	g._tick_shake(0.0)
	var reached := false
	for i in 64:
		g._shake_time = i / 64.0
		var radius := g._shake_offset().length()
		if radius > Balance.CAMERA_SHAKE_MAX_PX + 0.0001:
			return "a heavy beat over rapid impacts exceeded the total displacement cap"
		reached = reached or radius > Balance.CAMERA_SHAKE_MAX_PX - 0.0001
	if not reached:
		return "a saturated impact never reached the displacement cap"
	var full := g._shake_offset()
	for gain in [0.0, 0.25, 0.5, 1.0]:
		g.settings["camera_shake"] = gain
		if not g._shake_offset().is_equal_approx(full * gain):
			return "impact cap changed the linear comfort preference"
	g.settings["camera_shake"] = 0.0
	if g._shake_offset() != Vector2.ZERO:
		return "0% camera shake still moved the camera"
	g.settings["camera_shake"] = 1.0
	# Re-rendering one instant (including a zero-delta freeze) must be stable.
	for i in 20:
		g._tick_shake(0.0)
		if g._shake_offset() != full:
			return "camera impact moved while simulation time was frozen"
	# A hit reaches the screen at full size on its first frame at any frame
	# rate (the old order decayed it by one frame before anyone saw it), and
	# later frames decay by the real frame time.
	for hz in [30, 60, 144]:
		_rest(g)
		for i in 3:
			g._tick_shake(1.0 / hz)
		g.shake(0.0, Vector2.RIGHT, Balance.HIT_SHAKE_KICK)
		g._tick_shake(1.0 / hz)
		if not g._shake_offset().is_equal_approx(Vector2(Balance.HIT_SHAKE_KICK, 0.0)):
			return "a %d fps frame showed the hit recoil below full size" % hz
		g._tick_shake(1.0 / hz)
		var decayed := Balance.HIT_SHAKE_KICK * exp(-Balance.HIT_SHAKE_KICK_DECAY / hz)
		if not g._shake_offset().is_equal_approx(Vector2(decayed, 0.0)):
			return "the recoil did not decay by the real %d fps frame time" % hz
	# Heavy beats (ults, slams, getting hit) stay the loud ones and keep their
	# tiers, whatever the waveform clock reads when they land.
	for i in 32:
		var clock := i / 32.0
		var hit := _peak(g, Balance.HIT_SHAKE, Balance.HIT_SHAKE_KICK, clock)
		var heavy_6 := _peak(g, 6.0, 0.0, clock)
		var heavy_9 := _peak(g, 9.0, 0.0, clock)
		var heavy_14 := _peak(g, 14.0, 0.0, clock)
		if heavy_6 <= hit or heavy_9 <= heavy_6 or heavy_14 <= heavy_9:
			return "heavy beats lost their order over an ordinary hit (hit %.2f, 6: %.2f, 9: %.2f, 14: %.2f px)" % [
				hit, heavy_6, heavy_9, heavy_14]
	# Production wiring: Game's per-frame camera tick writes this offset.
	_rest(g)
	g.shake(0.0, Vector2.RIGHT, Balance.HIT_SHAKE_KICK)
	for i in 2:
		g._tick_camera(0.0)
		if not g.camera.offset.is_equal_approx(Vector2(Balance.HIT_SHAKE_KICK, 0.0)):
			return "the camera tick did not show the hit recoil at full size"
	g.settings["camera_shake"] = 0.0
	g._tick_camera(0.0)
	if g.camera.offset != Vector2.ZERO:
		return "0% camera shake still moved the rendered camera"
	g.settings["camera_shake"] = 1.0
	# Same scripted strikes and boss footfalls, with independent render and
	# physics subdivisions. Every event lands on a common 1/6-second boundary
	# and shows on that frame; any split of the time after it gives the same
	# motion (a live frame can only land up to one frame after its event).
	var reference: Array[Vector2] = []
	for render_hz in [30, 60, 144]:
		for physics_hz in [30, 60, 144]:
			_rest(g)
			var samples: Array[Vector2] = []
			for beat in 12:
				if beat < 4:
					for hit in 4:
						g.shake(Balance.HIT_SHAKE, Vector2.RIGHT, Balance.HIT_SHAKE_KICK)
				elif beat < 6:
					g.shake(Balance.BOSS_STEP_SHAKE)
				g._tick_shake(0.0)
				# Split at both clocks' boundaries, without quantizing event time.
				var elapsed := 0.0
				var render_step := 1
				var physics_step := 1
				while elapsed < 1.0 / 6.0 - 0.0000001:
					var next := minf(minf(float(render_step) / render_hz,
						float(physics_step) / physics_hz), 1.0 / 6.0)
					g._tick_shake(next - elapsed)
					elapsed = next
					if elapsed >= float(render_step) / render_hz - 0.0000001: render_step += 1
					if elapsed >= float(physics_step) / physics_hz - 0.0000001: physics_step += 1
					if g._shake_offset().length() > Balance.CAMERA_SHAKE_MAX_PX + 0.0001:
						return "mixed-rate sequence exceeded the displacement cap"
				samples.append(g._shake_offset())
			if reference.is_empty():
				reference = samples
			for i in samples.size():
				if samples[i].distance_to(reference[i]) > 0.0001:
					return "camera recovery depends on render/physics subdivisions"
			if g.shake_amt != 0.0 or g._shake_kick != Vector2.ZERO or g._shake_offset() != Vector2.ZERO:
				return "camera failed to settle exactly after the last footfall"
	print("ok: impact cap, linear comfort, frozen waveform, full-size first frame at 30/60/144 fps, heavy-beat tiers, camera wiring and nine clock pairs")
	return ""


static func _presentation() -> String:
	var viewport := Vector2(1280, 720)
	var idle := Framing.compose(Vector2.ZERO, 250, Vector2.ZERO, false, 1.12, viewport, 1.0)
	if idle.look != Vector2.ZERO or idle.zoom != 1.0:
		return "empty scene changed the camera composition"
	var close := Framing.compose(Vector2.ZERO, 250, Vector2(75, 0), true, 1.12, viewport, 1.0)
	if close.zoom != 1.0:
		return "close melee changed the authored base zoom"
	for focus in [Vector2(680, 0), Vector2(0, -390), Vector2(-400, 240)]:
		var frame := Framing.compose(Vector2(-250, 0), 250, focus, true, 1.12, viewport, 1.0)
		if frame.zoom < Balance.CAMERA_FRAME_MIN_ZOOM or frame.zoom > 1.0 \
				or frame.look.length() > Balance.CAMERA_FOCUS_MAX_OFFSET + 0.001:
			return "combat camera exceeded its motion/zoom bounds"
		var old_pos: Vector2 = focus * 1.12 * 1.08
		var new_pos: Vector2 = (focus - frame.look) * 1.12 * float(frame.zoom)
		if new_pos.length() >= old_pos.length():
			return "framing did not bring the distant target further into view"
	var fixed := Framing.compose(Vector2(250, 0), 250, Vector2(600, 0), true, 1.12, viewport, 0.0)
	if fixed.look != Vector2.ZERO:
		return "zero camera lead still moved the composition"
	var trail := Trail.new()
	trail.step(1, 1.0, 0.0)
	if trail.step(1, 0.6, 0.016) != 1.0 or trail.step(1, 0.6, 0.2) != 1.0:
		return "damage trail did not hold the lost health"
	trail.step(1, 0.4, 0.1)
	if trail.step(1, 0.4, 0.3) != 1.0:
		return "second hit did not refresh the damage reading time"
	if trail.step(1, 0.4, 2.0) != 0.4:
		return "damage trail failed to settle"
	if trail.step(1, 0.7, 0.0) != 0.7 or trail.step(2, 0.2, 0.0) != 0.2:
		return "healing or a target switch fabricated a damage trail"
	return ""


static func _motion(g: Game) -> String:
	# A transient invalid force used to survive position recovery in anim_t:
	# the body returned home, but int(NAN) % six kept producing frame -2.
	var p: Player = g.local_player
	var e := Enemy.make(g, "wolf", p.global_position + Vector2(210, 0), -1, 1.0)
	g.world.add_child(e)
	e.set_physics_process(false)
	e.alerted = true
	e.force_aggro = true
	var gust: Vector2 = g.gust_vec
	e._physics_process(1.0 / 60.0)
	g.gust_vec = Vector2(NAN, NAN)
	e._physics_process(1.0 / 60.0)
	g.gust_vec = gust
	for i in 3:
		e._physics_process(1.0 / 60.0)
	var error := ""
	if p.motion_mode != CharacterBody2D.MOTION_MODE_FLOATING or e.motion_mode != CharacterBody2D.MOTION_MODE_FLOATING:
		error = "top-down actors still use platformer floor/ceiling collision rules"
	if not e.global_position.is_finite() or not e.velocity.is_finite() or not is_finite(e.anim_t):
		error = "one invalid movement force permanently poisoned an enemy's position or animation clock"
	if e.sprite.frame < 0 or e.sprite.frame >= e.sprite.hframes * e.sprite.vframes:
		error = "recovered enemy retained an invalid animation frame"
	e.global_position = Vector2(NAN, NAN)
	e.anim_t = NAN
	e._physics_process(1.0 / 60.0)
	if not is_finite(e.anim_t) or not e.global_position.is_finite() or e.motion_faults < 2:
		error = "legacy enemy position recovery left its old poisoned clock intact"
	e.queue_free()
	var saved := {}
	for key in ["global_position", "velocity", "strip_t", "_stride_ph", "_gait_step", "motion_faults", "last_motion_fault"]:
		saved[key] = p.get(key)
	var time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	p.velocity = Vector2(250, 0)
	p._move_body()
	if p.global_position != saved["global_position"]:
		error = "hero collision moved during zero-time hit-stop"
	Engine.time_scale = time_scale
	p.velocity = Vector2(NAN, NAN)
	p._move_body()
	if not p.global_position.is_finite() or not p.velocity.is_finite():
		error = "hero integrated an invalid force"
	p.global_position = Vector2(NAN, NAN)
	p.strip_t = NAN
	p._stride_ph = NAN
	p._move_body()
	if not p.global_position.is_finite() or not is_finite(p.strip_t) or not is_finite(p._stride_ph):
		error = "hero position recovery left its poisoned animation phase intact"
	for key in saved:
		p.set(key, saved[key])
	return error
