extends Node2D
## Rendering only. The owning attack supplies progress and owns damage,
## cancellation and lifetime. An analytic rim stays smooth at any camera zoom.

const COMET_SHADER := preload("res://shaders/ground_comet.gdshader")

var radius := 80.0
var tint := Color(1.0, 0.35, 0.2)
var safe := false
var decoy := false
var orbit_only := false  # intact terrain weapon: a quiet breathing marker, not a fuse
var hot_ramp := false  # unthemed/neutral physical danger only
# Untyped on purpose: a bound accent has its own lifetime, and a freed entry
# must be rejected before it reaches color_surface's typed parameter.
var surfaces: Array = []
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_update_comet()

var _comet: Polygon2D


func _ready() -> void:
	name = "GroundTellClock"
	z_index = -4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_comet = _surface(radius)
	_comet.name = "CometRim"
	_comet.material.set_shader_parameter("tint", Color(tint, 1.0))
	add_child(_comet)
	_update_comet()
	queue_redraw()


static func _surface(at_radius: float) -> Polygon2D:
	var surface := Polygon2D.new()
	var extent: float = at_radius + float(Balance.GROUND_TELL_STYLE.halo_width) * 2.0
	surface.polygon = PackedVector2Array([Vector2(-extent, -extent),
		Vector2(extent, -extent), Vector2(extent, extent), Vector2(-extent, extent)])
	var mat := ShaderMaterial.new()
	mat.shader = COMET_SHADER
	mat.set_shader_parameter("radius", at_radius)
	for key: String in Balance.GROUND_TELL_STYLE:
		mat.set_shader_parameter(key, Balance.GROUND_TELL_STYLE[key])
	surface.material = mat
	return surface


## The existing fill-alpha tweens still drive this sibling. No upscaled 64px
## hard rim underneath the analytic warning; the boundary belongs to the rim.
static func make_fill(at_radius: float) -> Polygon2D:
	var surface := _surface(at_radius)
	surface.name = "GroundTellFill"
	surface.set_meta("ground_attack_fill", true)
	surface.material.set_shader_parameter("fill_only", true)
	return surface


## Transparent means no ability theme: the neutral yellow/orange/red family.
## Themed tells keep their hue, including pale frost and Morwen's green rain.
static func ramp(theme_color: Color, fuse_t: float) -> Color:
	var t := pow(clampf(fuse_t, 0.0, 1.0), Balance.GROUND_TELL_RAMP_CURVE)
	if theme_color == Color.TRANSPARENT:
		return Balance.GROUND_TELL_HOT_START.lerp(Balance.GROUND_TELL_HOT_END, t)
	var saturation := lerpf(theme_color.s * Balance.GROUND_TELL_PALE_SATURATION,
		maxf(theme_color.s, Balance.GROUND_TELL_BOLD_SATURATION), t)
	if is_zero_approx(theme_color.s):
		saturation = 0.0  # an achromatic ability must not acquire an arbitrary red hue
	var value := lerpf(Balance.GROUND_TELL_PALE_VALUE, Balance.GROUND_TELL_BOLD_VALUE, t)
	return Color.from_hsv(theme_color.h, saturation, value, theme_color.a)


## Callers pass a LIVE surface: Godot rejects a freed object at this typed
## parameter before the body runs, so validity is checked by the caller.
static func color_surface(surface: CanvasItem, theme_color: Color, fuse_t: float) -> void:
	surface.modulate = Color(ramp(theme_color, fuse_t), surface.modulate.a)


## The tween belongs to the surface, so it can never step a freed surface.
static func animate_surface(surface: CanvasItem, theme_color: Color, fuse: float) -> void:
	color_surface(surface, theme_color, 0.0)
	surface.create_tween().tween_method(func(t: float) -> void: color_surface(surface, theme_color, t), 0.0, 1.0, fuse)


func bind_surface(surface: CanvasItem) -> void:
	surfaces.append(surface)
	color_surface(surface, Color.TRANSPARENT if hot_ramp else tint, progress)


func _update_comet() -> void:
	if not is_instance_valid(_comet):
		return
	var theme := Color.TRANSPARENT if hot_ramp else tint
	_comet.material.set_shader_parameter("tint", Color(tint if orbit_only else ramp(theme, progress), 1.0))
	# Validity is tested on the untyped Variant; dead entries are pruned.
	for i in range(surfaces.size() - 1, -1, -1):
		var surface: Variant = surfaces[i]
		if is_instance_valid(surface):
			color_surface(surface, theme, progress)
		else:
			surfaces.remove_at(i)
	var signal_alpha := 1.0
	if decoy:
		signal_alpha = 0.45 + 0.45 * sin(progress * TAU * 9.0)
	elif orbit_only:
		# Idle interactable cue: the whole ring breathes evenly, one cycle per
		# loop of progress. Uniform around the circle, so it never reads as a clock.
		signal_alpha = lerpf(Balance.REACTIVE_MARKER_BREATHE_FLOOR, 1.0, 0.5 - 0.5 * cos(progress * TAU))
	_comet.material.set_shader_parameter("signal_alpha", signal_alpha)


func _draw() -> void:
	# Inward refuge marks distinguish safe shelters beyond their green tint.
	if safe:
		var color := Color(tint.r, tint.g, tint.b, 0.85).lightened(0.25)
		for i in 4:
			var axis := Vector2.from_angle(i * PI * 0.5)
			var tangent := axis.orthogonal()
			var tip := axis * (radius - 11.0)
			draw_polyline(PackedVector2Array([axis * (radius - 4.0) - tangent * 4.0,
				tip, axis * (radius - 4.0) + tangent * 4.0]), color, 2.0, true)
