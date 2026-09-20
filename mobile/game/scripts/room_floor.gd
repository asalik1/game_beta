extends RefCounted
## Shared presentation only: callers own registration and room lifecycle.

static func add_ground(g: Game, parent: Node2D, zi: int, terrain: Dictionary) -> Sprite2D:
	var ground := Sprite2D.new()
	ground.texture = Art.ground(terrain["ground"], terrain["path"], g.TILES_W, g.TILES_H,
		zi * 1000 + 7, g.rooms[zi]["exits"].keys())
	ground.centered = false
	ground.position = g.rooms[zi]["origin"]
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	ground.modulate = Balance.FLOOR_LAYER_MODULATE
	parent.add_child(ground)
	return ground


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
		poly.modulate = Balance.FLOOR_LAYER_MODULATE
		parent.add_child(poly)
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
