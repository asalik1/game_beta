extends RefCounted
## Shared presentation only: callers own registration and room lifecycle.
static var _fire_contact: GradientTexture2D
static var _falloff_cache: Dictionary = {}   # cell-local layout key -> baked ImageTexture
const FALLOFF_CACHE_MAX := 64                  # distinct layouts kept; beyond that, rebuild from scratch


## Baked world-space edge light over the room's whole grid cell: no processing,
## camera dependence or ambient tint multiplication. The falloff starts at the
## walls' inner faces and holds its edge value everywhere outside them, so door
## corridors, the margin behind an inset room's walls, corner bites and the
## neighbouring cell all meet the doorway at one value (no seam). The quad is
## anchored at the cell's bottom edge: the y-sorted world then draws it after
## every other z -9 floor overlay in the room (water, wear, footprints), so
## those darken with the floor instead of popping out of the frame.
static func vignette(g: Game, parent: Node2D, zi: int, existing: Polygon2D = null) -> Polygon2D:
	var poly := existing if is_instance_valid(existing) else Polygon2D.new()
	if poly.get_parent() == null:
		parent.add_child(poly)
	var cell := g.room_rect(zi)
	poly.name = "RoomFloorVignette"
	poly.z_as_relative = false
	poly.z_index = -9
	poly.position = Vector2(cell.position.x, cell.end.y)
	poly.polygon = PackedVector2Array([Vector2(0, -cell.size.y), Vector2(cell.size.x, -cell.size.y),
		Vector2(cell.size.x, 0), Vector2.ZERO])
	var size := Balance.ROOM_FALLOFF_TEX_SIZE
	poly.uv = PackedVector2Array([Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)])
	poly.texture = falloff_texture(g, zi)
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	poly.material = material
	return poly


## The wall surface's inner floor in cell-local space. The north boundary is
## the face top PLUS its actual height: upward faces end at the collision seam,
## even when north headroom clips their height. Adding WALL_FACE_H below that
## seam would incorrectly move the darkest band into the walkable room.
static func inner_floor(g: Game, zi: int) -> Rect2:
	var floor: Rect2 = preload("res://scripts/wall_surface.gd").floor_regions(g, zi)[0]
	floor.position -= g.room_rect(zi).position
	return floor


## One baked texture per cell-local layout, shared by every room (and repaint,
## and corridor preview) with the same walls. The texels are 8-bit sRGB like
## every sprite, so 0.75 is a display value on each renderer: HDR 2D decodes it
## to linear light and the phone's Compatibility renderer multiplies it as
## stored. Values round up, so no texel falls below the value floor.
static func falloff_texture(g: Game, zi: int) -> ImageTexture:
	var cell := g.room_rect(zi)
	var inner := inner_floor(g, zi)
	var notches: Array = []
	for notch: Rect2 in g.room_notches(zi):
		notches.append(Rect2(notch.position - cell.position, notch.size))
	var key := "%s|%s|%s" % [cell.size, inner, notches]
	var cached: ImageTexture = _falloff_cache.get(key)
	if cached != null:
		return cached
	var size := Balance.ROOM_FALLOFF_TEX_SIZE
	var texel := cell.size / float(size)
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var i := 0
	for y in size:
		for x in size:
			var value := edge_value((Vector2(x, y) + Vector2(0.5, 0.5)) * texel, inner, notches)
			var byte := mini(255, ceili(value * 255.0))
			data[i] = byte
			data[i + 1] = byte
			data[i + 2] = byte
			data[i + 3] = 255
			i += 4
	var texture := ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data))
	if _falloff_cache.size() >= FALLOFF_CACHE_MAX:
		_falloff_cache.clear()
	_falloff_cache[key] = texture
	return texture


## Floor multiply at cell-local `at`: 1.0 in the lit middle, easing down to
## ROOM_FLOOR_VALUE_MIN at the walls' inner faces (corner bites included) and
## holding it outside them. The band shortens in a room too small for two full
## bands, so every room keeps a lit centre.
static func edge_value(at: Vector2, inner: Rect2, notches: Array = []) -> float:
	var reach := (inner.size * 0.5).min(Vector2.ONE * Balance.ROOM_EDGE_WIDTH).max(Vector2.ONE)
	var distance := (at - inner.position).min(inner.end - at).max(Vector2.ZERO)
	var edge := Vector2.ONE - Vector2(
		smoothstep(0.0, reach.x, distance.x),
		smoothstep(0.0, reach.y, distance.y))
	var shade := maxf(edge.x, edge.y)
	for notch: Rect2 in notches:
		var gap := (notch.position - at).max(at - notch.end).max(Vector2.ZERO).length()
		shade = maxf(shade, 1.0 - smoothstep(0.0, Balance.ROOM_EDGE_WIDTH, gap))
	return maxf(Balance.ROOM_FLOOR_VALUE_MIN, 1.0 - Balance.ROOM_EDGE_DARKEN * shade
		- Balance.ROOM_CORNER_DARKEN * edge.x * edge.y)


## Soft black annulus below the additive pool, with a clear centre. The child
## inherits only its source pool's modulation, not an independent pulse.
static func fire_contact_texture() -> GradientTexture2D:
	if _fire_contact == null:
		_fire_contact = GradientTexture2D.new()
		_fire_contact.width = Balance.FIRE_CONTACT_TEX_SIZE
		_fire_contact.height = Balance.FIRE_CONTACT_TEX_SIZE
		_fire_contact.fill = GradientTexture2D.FILL_RADIAL
		_fire_contact.fill_from = Vector2.ONE * 0.5
		_fire_contact.fill_to = Vector2(1.0, 0.5)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, Balance.FIRE_CONTACT_INNER, Balance.FIRE_CONTACT_PEAK, 1.0])
		gradient.colors = PackedColorArray([Color.TRANSPARENT, Color.TRANSPARENT,
			Color(0, 0, 0, Balance.FIRE_CONTACT_ALPHA), Color.TRANSPARENT])
		_fire_contact.gradient = gradient
	return _fire_contact


static func floor_modulate(terrain: Dictionary) -> Color:
	if terrain == Terrains.DATA["keep"] or String(terrain.get("name", "")).begins_with("Crownfall "):
		return Balance.FORTRESS_FLOOR_MODULATE
	return Balance.FLOOR_LAYER_MODULATE


static func add_ground(g: Game, parent: Node2D, zi: int, terrain: Dictionary) -> Sprite2D:
	var ground := Sprite2D.new()
	repaint_ground(g, ground, zi, terrain)
	ground.centered = false
	ground.position = g.rooms[zi]["origin"]
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	parent.add_child(ground)
	return ground


## Texture and floor modulate travel together, so a terrain repaint never
## keeps the previous terrain's cast (keep/capital stone is warmer).
static func repaint_ground(g: Game, ground: Sprite2D, zi: int, terrain: Dictionary) -> void:
	ground.texture = Art.ground(terrain["ground"], terrain["path"], g.TILES_W, g.TILES_H,
		zi * 1000 + 7, g.rooms[zi]["exits"].keys())
	ground.modulate = floor_modulate(terrain)


static func field(g: Game, parent: Node2D, zi: int, terrain: Dictionary, existing: Polygon2D = null) -> Polygon2D:
	var gk := String(terrain.get("ground", ""))
	var tex: Texture2D = Art.ground_field(gk)
	if tex == null:
		if is_instance_valid(existing): existing.queue_free()
		return null
	var poly: Polygon2D = existing if is_instance_valid(existing) else null
	if poly == null:
		poly = Polygon2D.new()
		poly.z_index = -11
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.polygon = PackedVector2Array([
			Vector2.ZERO, Vector2(g.ROOM_W, 0),
			Vector2(g.ROOM_W, g.ROOM_H), Vector2(0, g.ROOM_H)])
		parent.add_child(poly)
	poly.modulate = floor_modulate(terrain)
	poly.texture = tex
	var gain := float(Balance.GROUND_FIELD_GAIN.get(gk, 1.0))
	poly.self_modulate = Color(gain, gain, gain)
	var density := float(tex.get_width()) / Art.ground_field_period(gk)
	var uv := PackedVector2Array()
	for point in poly.polygon: uv.append(point * density)
	poly.uv = uv
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if density > 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	poly.position = g.rooms[zi]["origin"]
	return poly
