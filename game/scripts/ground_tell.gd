extends Node2D
## Rendering only. The owning attack supplies progress and owns damage,
## cancellation and lifetime. An analytic rim stays smooth at any camera zoom.

const COMET_SHADER := preload("res://shaders/ground_comet.gdshader")

var radius := 80.0
var tint := Color(1.0, 0.35, 0.2)
var safe := false
var decoy := false
var orbit_only := false  # intact terrain weapon: a quiet marker, not a fuse
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
	_comet.material.set_shader_parameter("orbit_only", orbit_only)
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
## hard rim underneath the analytic countdown; the boundary belongs to the rim.
static func make_fill(at_radius: float) -> Polygon2D:
	var surface := _surface(at_radius)
	surface.name = "GroundTellFill"
	surface.set_meta("ground_attack_fill", true)
	surface.material.set_shader_parameter("fill_only", true)
	return surface


func _update_comet() -> void:
	if not is_instance_valid(_comet):
		return
	_comet.material.set_shader_parameter("progress", progress)
	var signal_alpha := 1.0
	if decoy:
		signal_alpha = 0.45 + 0.45 * sin(progress * TAU * 9.0)
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
