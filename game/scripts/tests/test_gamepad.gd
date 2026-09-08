extends RefCounted
const Pad := preload("res://scripts/gamepad.gd")


static func run(_t: Node) -> String:
	for dz in [0.08, 0.18, 0.4]:
		for degrees in range(0, 360, 5):
			var dir := Vector2.RIGHT.rotated(deg_to_rad(degrees))
			if Pad.radial(dir * dz * 0.99, dz) != Vector2.ZERO:
				return "stick drift crossed the radial deadzone"
			var half := Pad.radial(dir * lerpf(dz, 1.0, 0.5), dz)
			if not is_equal_approx(half.length(), 0.5) or half.normalized().dot(dir) < 0.999:
				return "gentle walking lost its magnitude or direction"
			if not is_equal_approx(Pad.radial(dir * 2, dz).length(), 1.0):
				return "diagonal input exceeded or failed to reach full speed"
	if Pad.radial(Vector2(NAN, 1), 0.18) != Vector2.ZERO or Pad.radial(Vector2.INF, 0.18) != Vector2.ZERO:
		return "invalid device axes reached movement"
	var p := Pad.new()
	p.buttons = {JOY_BUTTON_A: true}
	if p.held("interact") or p.movement() != Vector2.ZERO:
		p.free()
		return "an inactive controller contributed held input"
	p.free()
	print("ok: gamepad radial deadzone, 216 directions, analog speed caps, invalid axes and inactive-device isolation")
	return ""
