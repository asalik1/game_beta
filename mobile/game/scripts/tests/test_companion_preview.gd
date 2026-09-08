extends RefCounted
const Preview := preload("res://scripts/ui/companion_preview.gd")
const Pet := preload("res://scripts/pet_visual.gd")


static func run(t: Node) -> String:
	var clip := Control.new()
	clip.size = Vector2(160, 100)
	clip.clip_contents = true
	t.add_child(clip)
	var error := _checks(clip)
	clip.free()
	if error == "":
		print("ok: companion previews fit all six full cycles in both menu sizes, hold their scale, rest, stop outside clipped/hidden menus and safely rebuild")
	return error


static func _checks(clip: Control) -> String:
	var preview := Preview.new()
	clip.add_child(preview)
	preview.set_process(false)
	for id in Pet.ORDER:
		for dimensions in [Vector2(78, 74), Vector2(64, 64)]:
			preview.setup(id, dimensions)
			var pet: Sprite2D = preview.visual
			var pixels := pet.texture.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			var cell := Vector2i(pixels.get_width() / pet.hframes, pixels.get_height())
			var poses: Array[Rect2] = []
			for frame in pet.hframes:
				var used := Rect2(pixels.get_region(Rect2i(Vector2i(frame * cell.x, 0), cell)).get_used_rect())
				used.position -= Vector2(cell) * 0.5
				poses.append(used)
			var seen := {}
			var scale_before := pet.scale
			for sample in 100:
				preview._process(0.05)
				seen[pet.frame] = true
				var bounds := poses[pet.frame]
				bounds.position = (bounds.position + pet.offset) * pet.scale + pet.position
				bounds.size *= pet.scale
				if not Rect2(Vector2.ZERO, dimensions).encloses(bounds) or pet.scale != scale_before:
					return "%s clips or changes scale in %s at frame %d: %s" % [id, dimensions, pet.frame, bounds]
			if seen.size() != pet.hframes:
				return id + " does not preview its whole movement cycle"
			preview._clock = Balance.PET_PREVIEW_WALK_SECONDS
			preview._process(0.01)
			if not pet.flying and pet.frame != 0:
				return id + " does not rest between preview walks"
			var age_before: float = pet.age
			clip.hide()
			preview._process(0.2)
			clip.show()
			preview.position.y = 150
			preview._process(0.2)
			preview.position.y = 0
			if pet.age != age_before:
				return id + " keeps animating outside a hidden or clipped menu"
	preview.setup("missing_pet")
	preview._process(0.2)
	if preview.visual.texture != null:
		return "reusing an empty preview retained the previous creature"
	return ""
