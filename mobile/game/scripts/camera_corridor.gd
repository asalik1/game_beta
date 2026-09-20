extends RefCounted
## Presentation-only doorway accommodation. No world build/visit/lock mutations.
## Stateless: a room/hero/world replacement cannot retain a previous edge.

static func apply(g: Game, p: Player) -> void:
	if not is_instance_valid(g.camera) or g.cur_room < 0 or g.cur_room >= g.rooms.size():
		return
	var ordinary: Rect2 = g.play_rect(g.cur_room)
	var preview := {}
	var bounds: Rect2 = effective_bounds(g, p, ordinary, preview)
	preload("res://scripts/camera_corridor_preview.gd").update(g, preview)
	g.camera.limit_left = int(bounds.position.x)
	g.camera.limit_top = int(bounds.position.y)
	g.camera.limit_right = int(bounds.end.x)
	g.camera.limit_bottom = int(bounds.end.y)


static func effective_bounds(g: Game, p: Player, ordinary: Rect2, preview: Dictionary = {}) -> Rect2:
	preview.clear()
	if not is_instance_valid(p) or p.dead or p.downed or p.ghost \
			or not p.global_position.is_finite() or g.room_at_pos(p.global_position) != g.cur_room:
		return ordinary
	var position: Vector2 = p.global_position
	var exits: Dictionary = g.rooms[g.cur_room]["exits"]
	var best_weight := 0.0
	var best: Rect2 = ordinary
	for value in exits.keys():
		var direction := String(value)
		if not direction in ["N", "S", "E", "W"]:
			continue
		var opposite: String = {"N": "S", "S": "N", "E": "W", "W": "E"}[direction]
		var neighbor: int = g.neighbor(g.cur_room, direction)
		if neighbor < 0 or neighbor >= g.rooms.size():
			continue
		var other_exits: Dictionary = g.rooms[neighbor]["exits"]
		# neighbor() means coordinate adjacency, not an authored connection.
		if not other_exits.has(opposite) or g.neighbor(neighbor, opposite) != g.cur_room \
				or not g._edge_unlocked(g.cur_room, neighbor):
			continue
		var other: Rect2 = g.play_rect(neighbor)
		var vertical: bool = direction in ["N", "S"]
		var lane: Vector2 = g.door_pos(g.cur_room, direction)
		var transverse: float = absf(position.x - lane.x) if vertical else absf(position.y - lane.y)
		if transverse > float(g.DOOR_TILES * g.TILE) * 0.5:
			continue
		var low: float
		var high: float
		if vertical:
			low = ordinary.end.y if direction == "S" else other.end.y
			high = other.position.y if direction == "S" else ordinary.position.y
		else:
			low = ordinary.end.x if direction == "E" else other.end.x
			high = other.position.x if direction == "E" else ordinary.position.x
		if high < low:
			continue
		var axial: float = position.y if vertical else position.x
		var zoom: float = g.camera.zoom.y if vertical else g.camera.zoom.x
		if not is_finite(zoom) or zoom <= 0.0:
			continue
		# Existing body/HUD framing allowance determines the approach apron.
		# Apply after combat zoom; do not change zoom, lead, smoothing or shake.
		var allowance: Vector2 = Balance.CAMERA_FRAME_MARGIN + Balance.CAMERA_FRAME_BODY
		var apron: float = (allowance.y if vertical else allowance.x) / zoom
		var distance_inside: float = maxf(low - axial, axial - high)
		var weight: float = clampf(1.0 - maxf(0.0, distance_inside) / apron, 0.0, 1.0)
		if weight <= best_weight:
			continue
		# Same pair envelope from either side of the CELL transition. Blend
		# only on approaches inside rooms; the entire corridor uses weight1.
		var envelope: Rect2 = ordinary.merge(other)
		best = Rect2(ordinary.position.lerp(envelope.position, weight),
			ordinary.size.lerp(envelope.size, weight))
		best_weight = weight
		preview.clear()
		if not g.built.get(neighbor, false):
			preview["room"] = neighbor
			preview["entry"] = opposite
	return best
