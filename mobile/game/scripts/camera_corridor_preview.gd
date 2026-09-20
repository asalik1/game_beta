extends Node2D
## Unvisited approach scenery only. No collision, actors or discovery changes.
const Floor := preload("res://scripts/room_floor.gd")
var room := -1
var entry := ""
var terrain_id := ""

static func update(g: Game, selection: Dictionary) -> void:
	if not is_instance_valid(g.world): return
	var old: Node2D = g.world.get_node_or_null("CorridorPreview")
	var zi := int(selection.get("room", -1))
	var side := String(selection.get("entry", ""))
	var wanted: bool = zi >= 0 and zi < g.rooms.size() and not g.built.get(zi, false)
	if is_instance_valid(old):
		if wanted and old.room == zi and old.entry == side and old.terrain_id == g.terrain_by_zone[zi]: return
		g.world.remove_child(old)
		old.queue_free()
	if not wanted: return
	var preview := new()
	preview.name = "CorridorPreview"
	preview.room = zi
	preview.entry = side
	preview.terrain_id = g.terrain_by_zone[zi]
	g.world.add_child(preview)
	preview._build(g)


func _build(g: Game) -> void:
	var terrain: Dictionary = Terrains.get_terrain(terrain_id)
	Floor.add_ground(g, self, room, terrain)
	Floor.field(g, self, room, terrain)
	var full: Rect2 = g.room_rect(room)
	var play: Rect2 = g.play_rect(room)
	var lane: Vector2 = g.door_pos(room, entry)
	var half: float = float(g.DOOR_TILES * g.TILE) * 0.5
	var tile: float = g.TILE
	var wt: String = Terrains.wall_for(terrain_id)
	# Dress just the visible entrance, using the same texture and relief as
	# real walls. These sprites never enter the world's wall/collision registry.
	if entry in ["N", "S"]:
		var near: float = full.position.y if entry == "N" else play.end.y
		var far: float = play.position.y if entry == "N" else full.end.y
		var y: float = play.position.y if entry == "N" else play.end.y - tile
		var relief := "S" if entry == "N" else ""
		_wall(g, Rect2(play.position.x, y, lane.x - half - play.position.x, tile), wt, relief)
		_wall(g, Rect2(lane.x + half, y, play.end.x - lane.x - half, tile), wt, relief)
		_wall(g, Rect2(lane.x - half - tile, near, tile, far - near), wt)
		_wall(g, Rect2(lane.x + half, near, tile, far - near), wt)
		if far - near >= g.CURTAIN_MIN_INSET:
			var curtain: float = full.position.y if entry == "N" else full.end.y - tile
			_wall(g, Rect2(full.position.x, curtain, lane.x - half - full.position.x, tile), wt, relief)
			_wall(g, Rect2(lane.x + half, curtain, full.end.x - lane.x - half, tile), wt, relief)
	else:
		var near: float = full.position.x if entry == "W" else play.end.x
		var far: float = play.position.x if entry == "W" else full.end.x
		var x: float = play.position.x if entry == "W" else play.end.x - tile
		var relief := "E" if entry == "W" else ""
		_wall(g, Rect2(x, play.position.y, tile, lane.y - half - play.position.y), wt, relief)
		_wall(g, Rect2(x, lane.y + half, tile, play.end.y - lane.y - half), wt, relief)
		_wall(g, Rect2(near, lane.y - half - tile, far - near, tile), wt)
		_wall(g, Rect2(near, lane.y + half, far - near, tile), wt)
		if far - near >= g.CURTAIN_MIN_INSET:
			var curtain: float = full.position.x if entry == "W" else full.end.x - tile
			_wall(g, Rect2(curtain, full.position.y, tile, lane.y - half - full.position.y), wt, relief)
			_wall(g, Rect2(curtain, lane.y + half, tile, full.end.y - lane.y - half), wt, relief)


func _wall(g: Game, rect: Rect2, wt: String, relief := "") -> void:
	if not rect.has_area(): return
	var sprite := Sprite2D.new()
	g._wall_dress(sprite, wt, rect.size)
	sprite.centered = false
	sprite.position = rect.position
	sprite.z_index = -5
	sprite.modulate = Terrains.wall_tint_for(terrain_id)
	add_child(sprite)
	g._wall_relief(sprite, wt, rect, relief)
