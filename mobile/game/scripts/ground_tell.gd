extends Node2D
## A fixed boundary with a fuse that closes clockwise at impact. Rendering only:
## the attack owns damage, cancellation and the lifetime of this child.

var radius := 80.0
var tint := Color(1.0, 0.35, 0.2)
var safe := false
var decoy := false
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	name = "GroundTellClock"
	z_index = -4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _draw() -> void:
	var steps := clampi(ceili(radius * 0.8), 40, 128)
	var color := Color(tint.r, tint.g, tint.b, 0.85).lightened(0.25)
	# A dark keyline preserves the silhouette on pale ice or orange magma.
	draw_arc(Vector2.ZERO, radius, 0, TAU, steps, Color(0.015, 0.02, 0.025, 0.85), 5.0, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, steps, Color(color, 0.52), 1.4, true)
	if progress > 0.0:
		var end := -PI * 0.5 + TAU * progress
		var fuse_color := color.lerp(Color(1.0, 0.95, 0.8), 0.60)
		if decoy:
			fuse_color.a *= 0.45 + 0.45 * sin(progress * TAU * 9.0)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, end, maxi(2, ceili(steps * progress)), fuse_color, 3.0, true)
		var tip := Vector2.from_angle(end) * radius
		draw_circle(tip, 2.8, fuse_color)
	# Inward refuge marks distinguish safe shelters beyond their green tint.
	if safe:
		for i in 4:
			var axis := Vector2.from_angle(i * PI * 0.5)
			var tangent := axis.orthogonal()
			var tip := axis * (radius - 11.0)
			draw_polyline(PackedVector2Array([axis * (radius - 4.0) - tangent * 4.0,
				tip, axis * (radius - 4.0) + tangent * 4.0]), color, 2.0, true)
