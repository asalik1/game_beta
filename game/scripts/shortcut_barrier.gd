extends RefCounted
## Shortcut-only paired thresholds. One registered StaticBody owns ALL shapes,
## so unchanged Game.open_edge disables both mouths synchronously and fades the
## complete assembly. No authored gate, wall, lock or camera policy is changed.


static func make(g: Game, from_room: int, direction: String) -> StaticBody2D:
	var neighbor: int = g.neighbor(from_room, direction)
	# Stable child order and root position regardless of which endpoint builds.
	var a: int = mini(from_room, neighbor)
	var b: int = maxi(from_room, neighbor)
	var a_dir: String = direction if a == from_room else String(g.OPP[direction])
	var gate := StaticBody2D.new()
	gate.name = "ShortcutBarrier"
	gate.add_to_group("shortcut_barrier")
	gate.position = g.door_pos(a, a_dir)
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate.y_sort_enabled = true
	for endpoint in [[a, a_dir], [b, String(g.OPP[a_dir])]]:
		var zone: int = int(endpoint[0])
		var dir: String = String(endpoint[1])
		var inward: Vector2 = -Vector2(Vector2i(g.DIRS[dir]))
		var tangent: Vector2 = inward.orthogonal()
		var mouth: Vector2 = _mouth(g, zone, dir)
		var tile: float = float(g.TILE)
		var vertical: bool = dir in ["E", "W"]
		# The threshold stands two tiles inside play_rect so the southern bars
		# clear the ability HUD and the northern approach keeps the hero visible.
		# Short returns join the threshold back to the existing wall band.
		var inner_face: Vector2 = mouth + inward * tile
		var center: Vector2 = inner_face + inward * (tile * 1.5)
		var span: float = float(g.DOOR_TILES) * tile
		var bar_size: Vector2 = Vector2(tile, span) if vertical else Vector2(span, tile)
		_add_piece(g, gate, center, bar_size, zone, "bar")
		# Returns overlap the old wall by half a tile and join the main bar
		# along a half-tile edge. Visible tiles match every collision footprint.
		for side in [-1.0, 1.0]:
			var support_center: Vector2 = inner_face + inward * (tile * 0.5) \
				+ tangent * (span + tile) * 0.5 * side
			var support_size := Vector2(tile * 2.0, tile) if vertical else Vector2(tile, tile * 2.0)
			_add_piece(g, gate, support_center, support_size, zone,
				"return_left" if side < 0.0 else "return_right")
	g.world.add_child(gate)
	return gate


## The clearing remains after opening, so the earned return route stays legible.
static func clearing(g: Game, zone: int) -> Dictionary:
	if g.shortcut_edge.is_empty() or zone not in [int(g.shortcut_edge.a), int(g.shortcut_edge.b)]:
		return {}
	var other: int = int(g.shortcut_edge.b) if zone == int(g.shortcut_edge.a) else int(g.shortcut_edge.a)
	for direction in ["N", "E", "S", "W"]:
		if g.neighbor(zone, direction) == other:
			var inward: Vector2 = -Vector2(Vector2i(g.DIRS[direction]))
			var center: Vector2 = _mouth(g, zone, direction) + inward * float(g.TILE) * 2.5
			return {"pos": center, "radius": Balance.SHORTCUT_MOUTH_CLEARANCE}
	return {}


static func _mouth(g: Game, zone: int, direction: String) -> Vector2:
	# Preserve CELL-centered lanes: asymmetric play_rect center is NOT the
	# corridor center. Change only the axis along which the door is crossed.
	var p: Vector2 = g.door_pos(zone, direction)
	var room: Rect2 = g.play_rect(zone)
	match direction:
		"N": p.y = room.position.y
		"S": p.y = room.end.y
		"W": p.x = room.position.x
		"E": p.x = room.end.x
	return p


static func _add_piece(g: Game, gate: StaticBody2D, center: Vector2,
		size: Vector2, zone: int, role: String) -> void:
	var local: Vector2 = center - gate.position
	var cs := CollisionShape2D.new()
	cs.name = "Mouth_%d_%s" % [zone, role]
	cs.position = local
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	gate.add_child(cs)
	# Existing soft contact texture, sized from actual output footprint rather
	# than hardcoded source dimensions. Shade lies under the lower edge.
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.position = local + Vector2(0, size.y * 0.5)
	shadow.scale = Vector2(size.x, size.y * 0.5) / shadow.texture.get_size()
	shadow.z_index = -1
	gate.add_child(shadow)
	if role == "bar":
		# A complete painted gate, with a genuine side view for E/W travel.
		# Sort at its ground pivot; the illustration rises above that footing.
		var upright := Node2D.new()
		upright.position = local
		gate.add_child(upright)
		var side_view: bool = size.y > size.x
		var sprite := Sprite2D.new()
		sprite.texture = Art.tex("shortcut_gate_side" if side_view else "shortcut_gate_front")
		var canvas: Vector2 = Balance.SHORTCUT_GATE_SIDE_CANVAS if side_view else Balance.SHORTCUT_GATE_FRONT_CANVAS
		sprite.scale = canvas / sprite.texture.get_size()
		sprite.position = Balance.SHORTCUT_GATE_SIDE_OFFSET if side_view else Balance.SHORTCUT_GATE_FRONT_OFFSET
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		upright.add_child(sprite)
	else:
		# Low stone returns use the established wall material/relief, matching
		# their solid footprints rather than stacking front-facing gate tiles.
		var cap := Sprite2D.new()
		var wall_material: String = Terrains.wall_for(String(g.terrain_by_zone[zone]))
		g._wall_dress(cap, wall_material, size)
		cap.modulate = Terrains.wall_tint_for(String(g.terrain_by_zone[zone]))
		cap.centered = false
		cap.position = local - size * 0.5
		cap.z_index = -5
		gate.add_child(cap)
		g._wall_relief(cap, wall_material, Rect2(center - size * 0.5, size), "SE")
