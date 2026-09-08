extends Control
## UI owns this clock; world followers retain their normal external animation.
const Pet := preload("res://scripts/pet_visual.gd")
static var _bounds_cache := {}
var visual: Sprite2D
var pet_id := ""
var _clock := 0.0
var _native_scale := Vector2.ONE
var _rest_offset := Vector2.ZERO
var _bounds := Rect2()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout)
	add_to_group("companion_previews")


func setup(id: String, dimensions := Vector2(78, 74)) -> void:
	if is_instance_valid(visual):
		visual.hide()
		visual.queue_free()
	pet_id = id
	_clock = 0.0
	_bounds = Rect2()
	custom_minimum_size = dimensions
	size = dimensions
	visual = Pet.new()
	visual.setup(id)
	add_child(visual)
	if visual.texture == null:
		return
	_native_scale = visual.scale
	_rest_offset = visual.offset
	_bounds = _measure(visual)
	_layout()
	visual.animate(0.0, true, Balance.PET_STRIDE_SPEED)


func _layout() -> void:
	if not is_instance_valid(visual) or _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return
	# Union of the actual visible pixels of EVERY frame. Reserve the hover/hop
	# headroom outside that union so a wing tip cannot clip halfway through.
	var headroom: float = Balance.PET_HOVER_HEIGHT + Balance.PET_HOVER_BOB if visual.flying else Balance.PET_HOP_HEIGHT + Balance.PET_REST_BOB
	var width := maxf(1.0, size.x - 8.0)
	var height := maxf(1.0, size.y - 8.0 - headroom)
	var fit := minf(_native_scale.x, minf(width / _bounds.size.x, height / _bounds.size.y))
	visual.scale = Vector2.ONE * fit
	var bounds := _bounds
	bounds.position += _rest_offset
	visual.position = Vector2(size.x * 0.5 - bounds.get_center().x * fit,
		size.y - 4.0 - bounds.end.y * fit)


func _process(delta: float) -> void:
	if not is_instance_valid(visual) or visual.texture == null or is_queued_for_deletion() or not _on_screen():
		return
	_clock += delta
	var cycle: float = Balance.PET_PREVIEW_WALK_SECONDS + Balance.PET_PREVIEW_REST_SECONDS
	var moving: bool = fmod(_clock, cycle) < Balance.PET_PREVIEW_WALK_SECONDS
	visual.animate(delta, moving, Balance.PET_STRIDE_SPEED if moving else 0.0)


func _on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	var area := get_global_rect().intersection(get_viewport_rect())
	var ancestor := get_parent()
	while ancestor != null and area.has_area():
		if ancestor is Control and ancestor.clip_contents:
			area = area.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return area.has_area()


static func _measure(pet: Sprite2D) -> Rect2:
	var key := pet.texture.get_rid()
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var cell := Vector2i(pet.texture.get_width() / maxi(1, pet.hframes),
		pet.texture.get_height() / maxi(1, pet.vframes))
	var pixels := pet.texture.get_image()
	var bounds := Rect2(Vector2(cell) * -0.5, Vector2(cell))
	if pixels != null:
		if pixels.is_compressed():
			pixels.decompress()
		var occupied := Rect2i()
		for frame in pet.hframes * pet.vframes:
			var origin := Vector2i(frame % pet.hframes, frame / pet.hframes) * cell
			var used := pixels.get_region(Rect2i(origin, cell)).get_used_rect()
			if used.has_area():
				occupied = used if not occupied.has_area() else occupied.merge(used)
		if occupied.has_area():
			bounds = Rect2(occupied)
			bounds.position -= Vector2(cell) * 0.5
	_bounds_cache[key] = bounds
	return bounds
