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
	# Text-only reader: never added to the tree, no device, network or save.
	var reader := Game.new()
	reader.gamepad = p
	p.game = reader
	var copy_error := _prompt_copy(reader, p)
	reader.gamepad = null
	p.game = null
	reader.free()
	p.free()
	if copy_error != "":
		return copy_error
	print("ok: whole-key touch/controller copy plus gamepad radial deadzone, 216 directions, analog speed caps, invalid axes and inactive-device isolation")
	return ""


static func _prompt_copy(g: Game, pad: Node) -> String:
	g.settings["pad_labels"] = "xbox"
	var untouched := [
		"Close this panel or press ESC — your party session stays active",
		"Close this panel or press ESC — you stay with the party",
		"and press ESC; Press ESC; hold ESC; Hold ESC",
		"press ECHO; press E1; press Quarter; Press Tactics; press Spacebar",
		"depress E; depress Q; withhold T",
	]
	var prompts := [
		["walk up to her and press E", "walk up to her and tap Act", "walk up to her and press A"],
		["walk up to him and press E.", "walk up to him and tap Act.", "walk up to him and press A."],
		["and press E", "and tap Act", "and press A"],
		["Hold E — Pull the cart", "Hold Act — Pull the cart", "Hold A — Pull the cart"],
		["press E or press ESC", "tap or press ESC", "press A or press ESC"],
		["press E, press Q; press Space; press T.", "tap, tap the potion button; tap; tap Skills.", "press A, press X; press A; press D-pad →."],
		["Press Q / Press Space", "Tap the potion button / Tap", "Press X / Press A"],
		["E — Talk", "Talk", "A — Talk"],
	]
	for mode in ["keyboard", "touch", "pad"]:
		g.touch_mode = mode == "touch"
		pad.active = mode == "pad"
		for text in untouched:
			if g.touchify(text) != text or g.ui_copy(text) != text:
				return "%s copy rewrote part of a longer word/key: %s" % [mode, text]
		for row in prompts:
			var column := 1 if mode == "touch" else (2 if mode == "pad" else 0)
			if g.touchify(row[0]) != row[column]:
				return "%s copy lost a complete key prompt: %s" % [mode, row[0]]
	return ""
