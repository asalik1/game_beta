extends RefCounted

const Framing := preload("res://scripts/camera_framing.gd")
const Trail := preload("res://scripts/health_trail.gd")


static func run(t: Node) -> String:
	var error := _presentation()
	if error == "":
		error = _motion(t.game)
	if error == "":
		print("ok: target camera bounds, health-trail identity/heals and finite movement recovery")
	return error


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
