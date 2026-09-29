extends RefCounted
## Presentation only: all geometry is measured from existing collision seams.
## Walls rise only into space nobody walks on: this room's own north margin
## and the wall band of the room north of it, never onto that room's floor.
const SHADER := preload("res://shaders/wall_surface.gdshader")


## Non-walkable depth above room i's play rect: its own north margin plus,
## when a room lies to the north, that room's south margin and south wall.
## INF at a map edge (nothing else is ever drawn there).
static func north_headroom(g, i: int) -> float:
	var above: int = g.neighbor(i, "N")
	if above < 0:
		return INF
	return g.play_rect(i).position.y - (g.play_rect(above).end.y - Game.TILE)


## The highest point a south face at `rect` may reach: the floor edge of the
## room north of the cell that holds it. -INF when no room lies north.
static func face_ceiling(g, rect: Rect2) -> float:
	var room: int = g.room_at_pos(rect.get_center())
	if room < 0:
		return -INF
	var above: int = g.neighbor(room, "N")
	return -INF if above < 0 else g.play_rect(above).end.y - Game.TILE


## How far room i's north faces rise above its play rect.
static func north_rise(g, i: int) -> float:
	return minf(maxf(0.0, Balance.WALL_FACE_H - Game.TILE), north_headroom(g, i))


## Camera headroom over room i: the risen face plus a sliver of dark mass,
## still never past the floor edge of the room to the north.
static func view_rise(g, i: int) -> float:
	return minf(north_rise(g, i) + Balance.WALL_LIP_W, north_headroom(g, i))


static func view_bounds(g, i: int, rect: Rect2) -> Rect2:
	# Keep the upward silhouette in frame without expanding the playable rect.
	return rect.grow_individual(0, view_rise(g, i), 0, 0)


## The dark surround: room i's cell plus the camera headroom above it.
static func mass_rect(g, i: int) -> Rect2:
	var full: Rect2 = g.room_rect(i)
	var margin: float = g.play_rect(i).position.y - full.position.y
	return full.grow_individual(0, maxf(0.0, view_rise(g, i) - margin), 0, 0)


static func floor_regions(g, i: int) -> Array[Rect2]:
	var pr: Rect2 = g.play_rect(i)
	var full: Rect2 = g.room_rect(i)
	var floor := pr.grow(-Game.TILE)
	var gap: float = Game.DOOR_TILES * Game.TILE
	# Above the cell the north lane is the next room's doorway floor.
	var north_top: float = mass_rect(g, i).position.y
	var regions: Array[Rect2] = [floor]
	for dir: String in g.rooms[i]["exits"]:
		match dir:
			"N": regions.append(Rect2(full.get_center().x - gap / 2.0, north_top, gap, floor.position.y - north_top))
			"S": regions.append(Rect2(full.get_center().x - gap / 2.0, floor.end.y, gap, full.end.y - floor.end.y))
			"W": regions.append(Rect2(full.position.x, full.get_center().y - gap / 2.0, floor.position.x - full.position.x, gap))
			"E": regions.append(Rect2(floor.end.x, full.get_center().y - gap / 2.0, full.end.x - floor.end.x, gap))
	return regions


static func _bounds(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y)


static func mass(g, i: int, wall_tex: String) -> Sprite2D:
	var rect := mass_rect(g, i)
	var spr := Sprite2D.new()
	g._wall_dress(spr, wall_tex, rect.size)
	spr.centered = false
	spr.position = rect.position
	spr.z_index = -6
	spr.set_meta("wall_rect", rect)
	spr.set_meta("wall_mass", true)
	spr.material = cap_material(g, i, true)
	return spr


## Above the cell, the mass is cut away over an open north door's lane so the
## next room's doorway floor shows there. Until that room (or its corridor
## preview) is built, this dark strip fills the lane instead of the renderer's
## clear color. It sits under every floor layer (ground -10, field -11).
static func lane_backdrop(g, i: int) -> Polygon2D:
	var full: Rect2 = g.room_rect(i)
	var top: float = mass_rect(g, i).position.y
	if top >= full.position.y or not g.rooms[i]["exits"].has("N"):
		return null
	var gap: float = Game.DOOR_TILES * Game.TILE
	var x: float = full.get_center().x - gap / 2.0
	var strip := Polygon2D.new()
	strip.polygon = PackedVector2Array([Vector2(x, top), Vector2(x + gap, top),
		Vector2(x + gap, full.position.y), Vector2(x, full.position.y)])
	strip.color = Balance.WALL_CAP_DARK
	strip.z_index = -12
	strip.set_meta("wall_lane_backdrop", i)
	return strip


static func cap_material(g, i: int, cut_floor := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var regions := floor_regions(g, i)
	mat.set_shader_parameter("floor_rect", _bounds(regions[0]))
	var lanes: Array[Vector4] = []
	for n in range(1, regions.size()):
		lanes.append(_bounds(regions[n]))
	mat.set_shader_parameter("lane_count", lanes.size())
	lanes.resize(4)
	mat.set_shader_parameter("lanes", lanes)
	mat.set_shader_parameter("cut_floor", cut_floor)
	mat.set_shader_parameter("cap_depth", Balance.WALL_CAP_DEPTH)
	mat.set_shader_parameter("cap_edge", Balance.WALL_CAP_EDGE)
	mat.set_shader_parameter("cap_dark", Balance.WALL_CAP_DARK)
	return mat


## `face_top` (world y) overrides where a south face starts: pilasters share
## their wall's lip, free-standing blocks keep their face on their own
## footprint. Either way the face never climbs past face_ceiling().
static func face_rect(g, rect: Rect2, side: String, face_top := INF) -> Rect2:
	match side:
		"S":
			var top: float = face_top if is_finite(face_top) else rect.end.y - Balance.WALL_FACE_H
			top = minf(maxf(top, face_ceiling(g, rect)), rect.end.y)
			return Rect2(rect.position.x, top, rect.size.x, rect.end.y - top)
		"E": return Rect2(rect.end.x - Balance.WALL_SIDE_FACE_W, rect.position.y, Balance.WALL_SIDE_FACE_W, rect.size.y)
		_: return Rect2(rect.position.x, rect.position.y, Balance.WALL_SIDE_FACE_W, rect.size.y)


static func relief(g, spr: Sprite2D, wall_tex: String, rect: Rect2, sides: String, face_top := INF) -> void:
	for child in spr.get_children():
		spr.remove_child(child)
		child.queue_free()
	var k := spr.scale.x
	for side in ["S", "E", "W"]:
		if not sides.contains(side):
			continue
		var fr := face_rect(g, rect, side, face_top)
		if not fr.has_area():
			continue
		var face := Sprite2D.new()
		face.name = "Face" + side
		g._wall_dress(face, wall_tex, fr.size)
		face.scale = Vector2.ONE
		face.centered = false
		face.position = (fr.position - rect.position) / k
		face.z_index = 1
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("face", true)
		mat.set_shader_parameter("face_size", fr.size / k)
		mat.set_shader_parameter("face_axis", 1 if side == "S" else 0)
		mat.set_shader_parameter("reverse_face", side == "W")
		mat.set_shader_parameter("lip_width", Balance.WALL_LIP_W / k)
		mat.set_shader_parameter("ao_width", (Balance.WALL_AO_H if side == "S" else Balance.WALL_SIDE_AO_W) / k)
		mat.set_shader_parameter("face_top", Balance.WALL_FACE_TOP)
		mat.set_shader_parameter("face_base", Balance.WALL_FACE_BASE)
		mat.set_shader_parameter("face_ao", Balance.WALL_FACE_AO)
		mat.set_shader_parameter("face_lip", Balance.WALL_FACE_LIP)
		face.material = mat
		spr.add_child(face)
		var shadow := Sprite2D.new()
		shadow.name = "Shadow" + side
		shadow.texture = Art.tex("softshadow")
		shadow.centered = false
		var tex_size := shadow.texture.get_size()
		if side == "S":
			shadow.position = Vector2(0, rect.size.y / k)
			shadow.scale = Vector2(rect.size.x, Balance.WALL_SHADOW_H) / k / tex_size
		else:
			shadow.rotation = -PI / 2.0 if side == "E" else PI / 2.0
			shadow.position = Vector2(rect.size.x, rect.size.y) / k if side == "E" else Vector2.ZERO
			shadow.scale = Vector2(rect.size.y, Balance.WALL_SIDE_SHADOW_W) / k / tex_size
		shadow.modulate.a = Balance.WALL_SHADOW_A if side == "S" else Balance.WALL_SIDE_SHADOW_A
		shadow.z_index = -3
		spr.add_child(shadow)
