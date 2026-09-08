extends RefCounted
## Presentation only. Frame the same opponent the reticle already reveals.

var room := -1
var hero_id := 0
var previous := Vector2.ZERO


static func compose(velocity: Vector2, speed: float, focus: Vector2, has_focus: bool,
		base_zoom: float, viewport: Vector2, lead: float) -> Dictionary:
	var look := velocity.limit_length(maxf(1.0, speed)) / maxf(1.0, speed) * Balance.CAMERA_LOOKAHEAD_PX
	var zoom := 1.0
	if has_focus:
		look = (focus * Balance.CAMERA_FOCUS_SHARE + look * Balance.CAMERA_FOCUS_MOVE_SHARE) \
			.limit_length(Balance.CAMERA_FOCUS_MAX_OFFSET)
	look *= lead
	if has_focus:
		# Leave room for bodies and the HUD, not just two point-sized feet.
		var half := viewport * 0.5 - Balance.CAMERA_FRAME_MARGIN
		var extent := Vector2(maxf(absf(look.x), absf(focus.x - look.x)),
			maxf(absf(look.y), absf(focus.y - look.y))) + Balance.CAMERA_FRAME_BODY
		zoom = clampf(minf(half.x / maxf(1.0, extent.x * base_zoom),
			half.y / maxf(1.0, extent.y * base_zoom)), Balance.CAMERA_FRAME_MIN_ZOOM, 1.0)
	return {"look": look, "zoom": zoom}


func tick(g: Game, delta: float) -> void:
	var p: Player = g.local_player
	if not is_instance_valid(p) or not p.global_position.is_finite():
		return
	var base_zoom: float = g.camera.zoom.x / g._cam_zoom_mult
	var focus := Vector2.ZERO
	var active := false
	if not p.dead and not p.downed and not p.ghost and not g.input_overlay_up() \
			and bool(g.settings.get("combat_framing", true)):
		var target: CharacterBody2D = p.aim_focus()
		if is_instance_valid(target) and target.global_position.is_finite():
			# No new scans through fog or into neighbouring rooms. Rivals use
			# aim_focus's existing duel eligibility just like every ability.
			active = target is Player or (target is Enemy and (target.zone_idx < 0 or target.zone_idx == g.cur_room))
			focus = target.global_position - p.global_position
	var vel := p.velocity if p.velocity.is_finite() and not p.dead else Vector2.ZERO
	var desired := compose(vel, p.speed, focus, active, base_zoom,
		g.get_viewport_rect().size, float(g.settings.get("camera_lead", 1.0)))
	var reset := hero_id != p.get_instance_id() or room != g.cur_room \
		or previous.distance_to(p.global_position) > Balance.CAMERA_FRAME_TELEPORT
	hero_id = p.get_instance_id()
	room = g.cur_room
	previous = p.global_position
	if reset:
		g._cam_look = Vector2.ZERO
		g._cam_zoom_mult = 1.0
	else:
		# Exponential easing has the same response at 30, 60 and 144 fps.
		g._cam_look = g._cam_look.lerp(desired["look"], 1.0 - exp(-Balance.CAMERA_LOOKAHEAD_EASE * delta))
		g._cam_zoom_mult = lerpf(g._cam_zoom_mult, desired["zoom"], 1.0 - exp(-Balance.CAMERA_ZOOM_EASE * delta))
	g.camera.zoom = Vector2.ONE * base_zoom * g._cam_zoom_mult
	g.camera.offset = g._cam_look + (g._shake_kick \
		+ Vector2(randf_range(-1, 1), randf_range(-1, 1)) * g.shake_amt) \
		* float(g.settings.get("camera_shake", 1.0))
