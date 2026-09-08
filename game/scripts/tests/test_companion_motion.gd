extends RefCounted
const Pet := preload("res://scripts/pet_visual.gd")


static func run(_t: Node) -> String:
	for id in Pet.ORDER:
		var pet := Pet.new()
		pet.setup(id)
		var error := _check(pet, id)
		pet.free()
		if error != "":
			return error
	print("ok: all six pets load eight real movement frames, hold scale through the cycle, settle grounded idle and keep flying wingbeats alive")
	return ""


static func _check(pet: Sprite2D, id: String) -> String:
	if not pet._motion_clip or pet.hframes != 8 or pet.texture.get_width() != pet.texture.get_height() * 8:
		return id + " fell back to a static portrait"
	var scale_before := pet.scale
	var seen := {}
	for i in 32:
		pet.animate(0.0625, true, Balance.PET_STRIDE_SPEED)
		seen[pet.frame] = true
		if pet.scale != scale_before or not pet.offset.is_finite():
			return id + " changed body size or lost its frame anchor"
	if seen.size() < 7:
		return id + " did not play its actual movement cycle"
	pet.animate(0.1, false)
	if not pet.flying:
		if pet.frame != 0:
			return id + " walked in place while resting"
		pet.animate(0.7, false)
		if pet.frame != 0:
			return id + " left its idle stance without movement"
	else:
		var frame_before: int = pet.frame
		pet.animate(1.0 / float(Balance.PET_MOTION_FPS[id]) * 1.1, false)
		if pet.frame == frame_before:
			return id + " stopped beating its wings while hovering"
	return ""
