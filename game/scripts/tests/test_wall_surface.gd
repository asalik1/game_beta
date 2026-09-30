extends RefCounted
## Geometry fixtures own every node; live layout checks only read fresh rooms
## (the one torch pair they build to measure is retired before returning).
const Surface := preload("res://scripts/wall_surface.gd")
const Barrier := preload("res://scripts/shortcut_barrier.gd")


## Stacked cells with authored play rects: 0 above 1, and 2 east of 1.
class Stack extends Game:
	var rectangles: Array[Rect2] = []
	func play_rect(i: int) -> Rect2: return rectangles[i]


static func run(_runner: Node) -> String:
	var g := Game.new()
	var holder := Node2D.new()
	g.world = holder
	var error := _geometry(g)
	holder.free()
	g.free()
	if error == "":
		var stack := Stack.new()
		var stack_world := Node2D.new()
		stack.world = stack_world
		error = _stacked(stack)
		if error == "": error = _vignette_geometry(stack)
		stack_world.free()
		stack.free()
	if error == "":
		print("ok: wall relief rises into cap, side faces meet unchanged colliders, native and legacy texture scales")
		print("ok: stacked rooms keep faces, mass, camera and canopy off the next floor; pilasters, returns, lane backdrop")
	return error


static func _geometry(g: Game) -> String:
	var hero_height: float = Player.HERO_TARGET_BODY * Balance.CHAR_RENDER_SCALE
	if Balance.WALL_FACE_H < hero_height * 1.1 or Balance.WALL_FACE_H > hero_height * 1.3:
		return "north wall is not 1.1-1.3 hero bodies tall"
	if Balance.WALL_CAP_DEPTH < 150.0 or Balance.WALL_CAP_DEPTH > 250.0:
		return "wall mass does not sink within 150-250px"
	if Balance.WALL_SIDE_FACE_W < 12.0 or Balance.WALL_SIDE_FACE_W > 16.0:
		return "side wall has no narrow visible face"
	# Use real factory colliders; the old 22px downward face fails the seam check.
	var rect := Rect2(320, 240, 600, Game.TILE)
	# "light" is an existing procedural texture with no wall_field override,
	# exercising the real legacy path without mutating the shared art cache.
	for wall in ["wallblock", "wall_moss", "light"]:
		g._wall(rect, wall, "SEW")
		var spr: Sprite2D = g._wall_sink.back()
		var body := g.world.get_child(g.world.get_child_count() - 2) as StaticBody2D
		var shape := body.get_child(0) as CollisionShape2D
		if (shape.shape as RectangleShape2D).size != rect.size or body.position != rect.get_center():
			return "wall presentation changed collision"
		var error := _faces(g, spr, rect)
		if error != "": return error
		# No room lies north of this lone wall: the face keeps its full height.
		if not is_equal_approx(_face(spr, "S").size.y, Balance.WALL_FACE_H):
			return "an unobstructed north face lost height"
	return ""


static func _faces(g: Game, spr: Sprite2D, rect: Rect2) -> String:
	for side in ["S", "E", "W"]:
		var face := spr.get_node_or_null("Face" + side) as Sprite2D
		if face == null: return "wall missing face " + side
		if not _face(spr, side).is_equal_approx(Surface.face_rect(g, rect, side)):
			return "wall face moved the floor seam: " + side
		if face.z_index <= 0 or face.material == null:
			return "wall cap hides its face or face has no gradient"
	var south := spr.get_node("ShadowS") as Sprite2D
	if not is_equal_approx(south.position.y * spr.scale.y, rect.size.y):
		return "north shadow starts below the collision seam"
	return ""


## World rect of a relief face (Rect2() when absent). `offset` is the world
## position of the carrier's parent when that is not the world itself.
static func _face(spr: Sprite2D, side: String, offset := Vector2.ZERO) -> Rect2:
	var face := spr.get_node_or_null("Face" + side) as Sprite2D
	if face == null: return Rect2()
	return Rect2(offset + spr.position + face.position * spr.scale, face.region_rect.size * spr.scale)


static func _stacked(g: Stack) -> String:
	var w := float(Game.ROOM_W)
	var h := float(Game.ROOM_H)
	var gap := float(Game.DOOR_TILES * Game.TILE)
	g.rooms = [{"coord": Vector2i(0, 0), "origin": Vector2.ZERO, "exits": {"S": true}},
		{"coord": Vector2i(0, 1), "origin": Vector2(0, h), "exits": {"N": true, "E": true}},
		{"coord": Vector2i(1, 1), "origin": Vector2(w, h), "exits": {"W": true}}]
	g.coord_to_room = {Vector2i(0, 0): 0, Vector2i(0, 1): 1, Vector2i(1, 1): 2}
	g.zones = [{"type": "safe"}, {"type": "safe"}, {"type": "safe"}]
	g.zone_count = 3
	g.terrain_by_zone = ["ph_castle", "ph_castle", "ph_castle"]
	# Full-size over full-size (safe hubs, boss arenas): only the two 48px
	# walls separate the floors, so nothing may rise more than one tile.
	g.rectangles = [Rect2(0, 0, w, h), Rect2(0, h, w, h), Rect2(w, h, w, h)]
	var upper_floor: Rect2 = g.play_rect(0).grow(-Game.TILE)
	var pr: Rect2 = g.play_rect(1)
	if not is_equal_approx(Surface.north_headroom(g, 1), Game.TILE):
		return "stacked full-size rooms report the wrong wall band"
	if Surface.view_bounds(g, 1, pr).position.y < upper_floor.end.y - 0.01:
		return "camera headroom shows the floor of the room above"
	var mass_rect := Surface.mass_rect(g, 1)
	if mass_rect.intersects(upper_floor) or mass_rect.end != g.room_rect(1).end:
		return "wall mass paints the floor of the room above"
	var north_wall := Rect2(pr.position.x, pr.position.y, w * 0.4, Game.TILE)
	g._wall(north_wall, "wall_castle", "S")
	var wall_spr: Sprite2D = g._wall_sink.back()
	var face := _face(wall_spr, "S")
	if face.intersects(upper_floor) or not is_equal_approx(face.position.y, upper_floor.end.y) \
			or not is_equal_approx(face.end.y, north_wall.end.y):
		return "north face does not fill exactly the shared wall band: %s" % face
	# Behind the open north door the band above the cell belongs to room 0.
	# The mass is cut there; a dark strip under every floor layer fills it
	# until room 0 (or its corridor preview) paints its own doorway floor.
	var lane: Rect2 = Surface.floor_regions(g, 1)[1]
	if not is_equal_approx(lane.position.y, mass_rect.position.y):
		return "north lane cut does not reach the top of the mass"
	var strip := Surface.lane_backdrop(g, 1)
	if strip == null:
		return "open north door above the cell shows the clear color"
	var strip_rect := Rect2(strip.polygon[0], strip.polygon[2] - strip.polygon[0])
	var band := Rect2(lane.position.x, mass_rect.position.y, gap, h - mass_rect.position.y)
	var strip_z := strip.z_index
	strip.free()
	if not strip_rect.is_equal_approx(band) or strip_z >= -11:
		return "north lane backdrop misses the band or covers a floor layer"
	# Pilasters share the wall's face top; west/east ones carry the wall's side face.
	wall_spr.material = Surface.cap_material(g, 1)
	g.zone_wall_sprites[1] = [wall_spr]
	g._wall_posts(1, pr, g.rooms[1]["exits"], gap, "wall_castle")
	var sides := {}
	for post: Sprite2D in g.zone_posts.get(1, []):
		if post.material != wall_spr.material:
			return "wall post allocated its own wall-top material"
		if post.modulate != Terrains.wall_tint_for("ph_castle") or post.self_modulate != g.POST_SHADE:
			return "post shade darkens its faces instead of its top alone"
		var size: Vector2 = post.region_rect.size * post.scale
		if post.position.y == pr.position.y and size == Vector2(g.POST_W, Game.TILE + g.POST_DROP):
			sides["N"] = true
			var post_face := _face(post, "S")
			if not is_equal_approx(post_face.position.y, face.position.y) \
					or not is_equal_approx(post_face.end.y, post.position.y + size.y):
				return "north pilaster lip is out of line with its wall"
		elif post.position.x == pr.position.x and size == Vector2(Game.TILE + g.POST_DROP, g.POST_W):
			sides["W"] = true
			var step_end: float = pr.position.x + Game.TILE + g.POST_DROP
			var side_face := _face(post, "E")
			if not side_face.is_equal_approx(Rect2(step_end - Balance.WALL_SIDE_FACE_W, post.position.y,
					Balance.WALL_SIDE_FACE_W, g.POST_W)):
				return "west pilaster has no side face on its step"
		elif post.position.x == pr.end.x - Game.TILE - g.POST_DROP and size.y == g.POST_W:
			sides["E"] = true
			if not _face(post, "W").has_area():
				return "east pilaster has no side face on its step"
	if sides.size() != 3:
		return "pilaster fixture built no north/west/east run: %s" % str(sides.keys())
	for post in g.zone_posts[1]:
		post.free()
	g.zone_posts.erase(1)
	# Forest canopy hangs from the risen wall top, never over room 0's floor.
	g.terrain_by_zone[1] = "darkwood"
	g._canopy_overhang(1, pr, g.rooms[1]["exits"], gap)
	var canopies: Array = g.zone_canopy.get(1, [])
	var canopy_error := "" if not canopies.is_empty() else "forest canopy fixture built nothing"
	if canopy_error == "": canopy_error = canopy_overlap(g, 1)
	for leaves: Sprite2D in canopies:
		if leaves.position.y < upper_floor.end.y - 0.01:
			canopy_error = "forest canopy covers the floor of the room above"
		leaves.free()
	g.zone_canopy.erase(1)
	g.terrain_by_zone[1] = "ph_castle"
	if canopy_error != "": return canopy_error
	# Shortcut returns stand on walkable floor: faces stay on their footprint,
	# tops take the room's wall-top shading. North (48x96) and east (96x48).
	for dir in ["N", "E"]:
		var gate := Barrier.make(g, 1, dir)
		var returns := 0
		var return_error := ""
		for piece in gate.get_children():
			if not piece is Sprite2D or (piece as Sprite2D).z_index != -5:
				continue
			var cap := piece as Sprite2D
			returns += 1
			var footprint := Rect2(gate.position + cap.position, cap.region_rect.size * cap.scale)
			var return_face := _face(cap, "S", gate.position)
			if not cap.material is ShaderMaterial:
				return_error = "shortcut return cap keeps a full-bright top"
			elif not return_face.has_area() or not footprint.grow(0.01).encloses(return_face):
				return_error = "shortcut return face rises over walkable floor (%s)" % dir
		gate.free()
		if return_error != "":
			return return_error
		if returns != 4:
			return "shortcut fixture built %d stone returns (%s)" % [returns, dir]
	# A lone room at the map edge keeps the whole silhouette and headroom.
	g.coord_to_room.erase(Vector2i(0, 0))
	var lone_rise := Surface.north_rise(g, 1)
	var lone_view := Surface.view_rise(g, 1)
	g.coord_to_room[Vector2i(0, 0)] = 0
	if not is_equal_approx(lone_rise, Balance.WALL_FACE_H - Game.TILE) \
			or not is_equal_approx(lone_view, lone_rise + Balance.WALL_LIP_W):
		return "room with nothing north lost its wall silhouette"
	# An inset room below keeps the full rise inside its own margin: no mass
	# above its cell, so no lane backdrop either.
	g.rectangles[1] = Rect2(96, h + 100, w - 192, h - 200)
	var inset_rise := Surface.north_rise(g, 1)
	var inset_mass := Surface.mass_rect(g, 1)
	var inset_strip := Surface.lane_backdrop(g, 1)
	if inset_strip != null:
		inset_strip.free()
		return "inset room paints a lane backdrop inside its own cell"
	if not is_equal_approx(inset_rise, Balance.WALL_FACE_H - Game.TILE) or inset_mass != g.room_rect(1):
		return "inset room lost its full wall rise or grew its mass out of its cell"
	return ""


## T53 draw order and extent: a rooted tree or backdrop crossing the north
## wall band must draw over the wall foliage, and the foliage must stay above
## the wall faces it dresses. Both bounds are measured from nodes the real
## factories build (probe props are planted and freed here), never literals.
## Also used by the capture rig's old-settings negative controls.
static func canopy_overlap(g: Game, i: int) -> String:
	var leaves: Array = g.zone_canopy.get(i, [])
	if leaves.is_empty(): return "canopy overlap fixture has no wall foliage"
	var carriers: Array = []
	carriers.append_array(g.zone_wall_sprites.get(i, []))
	carriers.append_array(g.zone_posts.get(i, []))
	var face_z := -INF
	for carrier in carriers:
		if not is_instance_valid(carrier): continue
		for side in ["S", "E", "W"]:
			var face := (carrier as Node).get_node_or_null("Face" + side) as CanvasItem
			if face != null: face_z = maxf(face_z, _abs_z(face))
	if face_z == -INF: return "canopy overlap fixture has no wall face to order against"
	var pr := g.play_rect(i)
	var probe := g._add_obstacle("tree_autumn", pr.position + Vector2(120.0, 100.0), 1.0)
	var backdrop := g._add_backdrop("tree_autumn", pr.position + Vector2(300.0, 80.0), 230.0)
	var prop_z := INF
	for root: Node in [probe, backdrop]:
		for child in root.get_children():
			if child.has_meta("occlusion_sort_y"): prop_z = minf(prop_z, _abs_z(child))
	probe.free()
	backdrop.free()
	if prop_z == INF: return "canopy overlap probes built no rooted crown"
	for strip: Sprite2D in leaves:
		if _abs_z(strip) >= prop_z:
			return "wall foliage overlays rooted canopies"
		if _abs_z(strip) <= face_z:
			return "wall foliage sits behind the wall faces it dresses"
		# Unit scale over the whole source height: every painted row shows at
		# its authored size (a 0.75 squash flattened the fringe in review).
		if strip.scale != Vector2.ONE:
			return "wall foliage is squashed off its painted scale"
		if strip.region_rect.position.y != 0.0 or strip.region_rect.size.y != strip.texture.get_height():
			return "wall foliage crops the painted canopy fringe"
		var mat := strip.material as ShaderMaterial
		if mat == null or mat.shader != preload("res://shaders/wall_canopy.gdshader"):
			return "wall foliage has hard rectangular span edges"
		if mat.get_shader_parameter("extent") != strip.region_rect.size \
				or mat.get_shader_parameter("feather") != Vector2.ONE * Balance.WALL_CANOPY_FEATHER:
			return "wall foliage feather misses its rendered span"
	return ""


## Effective canvas z of a node: relative z_index values sum up the chain.
static func _abs_z(item: Node) -> float:
	var z := 0
	var node := item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative: break
		node = node.get_parent()
	return float(z)


static func _lane_backdrop(g: Game, i: int) -> Node:
	for node in g.world.get_children():
		if int(node.get_meta("wall_lane_backdrop", -1)) == i:
			return node
	return null


static func run_room(g: Game, i: int) -> String:
	var regions := Surface.floor_regions(g, i)
	var pr := g.play_rect(i)
	if regions[0] != pr.grow(-Game.TILE):
		return "wall mass masks a different playable rect"
	if regions.size() != g.rooms[i]["exits"].size() + 1:
		return "wall mass omitted a door corridor"
	var mass_top := Surface.mass_rect(g, i).position.y
	for dir: String in g.rooms[i]["exits"]:
		var door: Vector2 = g.door_pos(i, dir)
		# North headroom must extend the opening through the raised silhouette,
		# otherwise the new mass paints a bar across a connected room's lane.
		if dir == "N":
			door.y = mass_top
		var found := false
		for region in regions:
			if region.grow(0.01).has_point(door): found = true
		if not found: return "wall mass paints over door " + dir
	# Nothing of this room may be drawn on the floor of the room to its north.
	var above: int = g.neighbor(i, "N")
	var above_floor := Rect2()
	if above >= 0:
		above_floor = g.play_rect(above).grow(-Game.TILE)
		if Surface.mass_rect(g, i).intersects(above_floor):
			return "wall mass paints the floor of the room above"
		if Surface.view_bounds(g, i, pr).position.y < above_floor.end.y - 0.01:
			return "camera headroom shows the floor of the room above"
	var backdrop := _lane_backdrop(g, i)
	var wants_backdrop: bool = mass_top < g.room_rect(i).position.y and g.rooms[i]["exits"].has("N")
	if wants_backdrop != (backdrop != null):
		return "north lane above the cell is %s" % ("left to the clear color" if wants_backdrop else "backed needlessly")
	var masses := 0
	for cap: Sprite2D in g.zone_wall_sprites.get(i, []):
		if not cap.material is ShaderMaterial:
			return "wall cap retained full-bright floor-like material"
		if cap.has_meta("wall_mass"):
			masses += 1
			if not cap.material.get_shader_parameter("cut_floor"):
				return "wall mass covers playable floor"
		elif cap.get_meta("wall_relief", "").contains("S"):
			var face := _face(cap, "S")
			if not face.has_area(): return "built north wall has no tall face"
			var wr: Rect2 = cap.get_meta("wall_rect")
			if not is_equal_approx(face.end.y, wr.end.y):
				return "built face extends onto walkable floor"
			if above >= 0 and face.intersects(above_floor):
				return "north face climbs onto the floor of the room above"
	if masses != 1: return "room needs one masked wall mass"
	var cap_material := g._room_cap_material(i)
	for post: Sprite2D in g.zone_posts.get(i, []):
		if post.material != cap_material:
			return "wall post allocated its own wall-top material"
		if above >= 0 and _face(post, "S").intersects(above_floor):
			return "pilaster face climbs onto the floor of the room above"
	for leaves: Sprite2D in g.zone_canopy.get(i, []):
		if leaves.position.y < pr.position.y - Surface.north_headroom(g, i) - 0.01:
			return "forest canopy covers the floor of the room above"
	if not g.zone_canopy.get(i, []).is_empty():
		var canopy_error := canopy_overlap(g, i)
		if canopy_error != "": return canopy_error
	var error := _north_torches(g, i)
	if error != "": return error
	print("ok: wall mass/corridors/torch seams chapter=%s room=%d" % [g.chapter_id, i])
	return ""


## Deterministic north anchor: the live layout may lack a north door, so
## build a pair on this room's north seam, measure it, then retire it.
static func _north_torches(g: Game, i: int) -> String:
	var first := g.world.get_child_count()
	var pr := g.play_rect(i)
	preload("res://scripts/door_torch_mount.gd").build(g, i, Vector2(pr.get_center().x, pr.position.y), false)
	var built: Array[Node] = []
	for n in range(first, g.world.get_child_count()):
		built.append(g.world.get_child(n))
	var checked := 0
	var error := ""
	for node in built:
		if not node.has_meta("door_torch"):
			continue
		checked += 1
		var pillar := node.get_node("Pillar") as Sprite2D
		var geometry: Dictionary = preload("res://scripts/door_torch_mount.gd").geometry(pillar)
		var foot: Rect2 = geometry["footprint"]
		var top: Vector2 = pillar.global_transform * (foot.position - geometry["size"] * 0.5)
		var seam: float = pr.position.y + Game.TILE
		if node.get_meta("door_torch_direction", "") != "N" \
				or not is_equal_approx(top.y, seam + Balance.DOOR_TORCH_GROUND_CLEARANCE):
			error = "north torch plinth was displaced by the upward face"
	for node in built:
		if is_instance_valid(node):
			node.free()
	if error == "" and checked != 2:
		error = "north torch fixture built %d pillars, not a pair" % checked
	return error


## Reconcile the floor-light boundary with native upward wall faces, including
## stacked-room clipping and inset rooms. A blind 22px -> 106px substitution
## compiles but fails these seam and falloff checks.
static func _vignette_geometry(g: Stack) -> String:
	var floor_light := preload("res://scripts/room_floor.gd")
	var w := float(Game.ROOM_W)
	var h := float(Game.ROOM_H)
	for inset in [0.0, 120.0]:
		g.rectangles = [Rect2(0, 0, w, h), Rect2(inset, h + inset, w - 2 * inset, h - 2 * inset),
			Rect2(w, h, w, h)]
		for zi in [0, 1]:
			var play := g.play_rect(zi)
			var wall := Rect2(play.position, Vector2(play.size.x, Game.TILE))
			g._wall(wall, "wallblock", "S")
			var native_face := _face(g._wall_sink.back(), "S")
			var inner := floor_light.inner_floor(g, zi)
			var cell := g.room_rect(zi)
			var north := native_face.position.y + native_face.size.y - cell.position.y
			if not is_equal_approx(inner.position.y, north):
				return "vignette north falloff does not start at the native wall face's foot"
			if not Rect2(inner.position + cell.position, inner.size).is_equal_approx(play.grow(-Game.TILE)):
				return "vignette inner faces disagree with the walkable floor seams"
			var seam := Vector2(inner.get_center().x, north)
			if floor_light.edge_value(seam, inner) != Balance.ROOM_FLOOR_VALUE_MIN \
					or floor_light.edge_value(seam + Vector2(0, Balance.ROOM_EDGE_WIDTH * 0.5), inner) <= Balance.ROOM_FLOOR_VALUE_MIN:
				return "vignette falloff does not brighten inward from the upward wall's foot"
	print("ok: vignette inner faces match native wall feet in full, inset and height-clipped stacked rooms")
	return ""
