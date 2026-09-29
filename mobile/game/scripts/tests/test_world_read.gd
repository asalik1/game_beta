extends RefCounted
const Floor := preload("res://scripts/room_floor.gd")
const FEATHER := 34.0   # the band's soft edge, pinned for the render check


## Renderer-only companion, run by `shot.bat polish --world-read` in the same
## locked session. Renders the real road_band shader from a real road_layout()
## (all four arms, an inset room, a river crossing, the stone rim) and checks
## the drawn road against game_world.road_curve(), the mirror scenery uses:
## both arms bend, widths vary, every door lane and the crossing stay on the
## straight lane, and the rim runs along the sides but never across a doorway.
static func rendered(rig: Node) -> String:
	var g: Game = rig.game
	var kept_exits: Dictionary = g.rooms[0]["exits"]
	g.rooms[0]["exits"] = {"W": 1, "E": 1, "N": 1, "S": 1}
	var road: Dictionary = g.road_layout(0)
	g.rooms[0]["exits"] = kept_exits
	road["bounds"] = Vector4(300, 150, 1812, 1098)   # an inset room: doors at these edges
	road["pins"] = [Vector4(0, 380, 560, 0)]          # a river crossing on the west arm
	road["seed"] = 0.8                                # bends every arm by > 50 px
	road["meander"] = Balance.ROAD_MEANDER_PX
	var viewport := SubViewport.new()
	viewport.size = Vector2i(g.ROOM_W, g.ROOM_H)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rig.add_child(viewport)
	var band := Sprite2D.new()
	band.texture = Art.tex("white")
	band.centered = false
	band.scale = Vector2(viewport.size) / band.texture.get_size()
	var mat := ShaderMaterial.new()
	mat.shader = g._road_shader()
	g.road_uniforms(mat, road)
	mat.set_shader_parameter("stone_edge_px", Balance.ROAD_STONE_EDGE_PX)
	mat.set_shader_parameter("stone_edge_darken", Balance.ROAD_STONE_EDGE_DARKEN)
	mat.set_shader_parameter("path_color", Color.WHITE)
	mat.set_shader_parameter("feather", FEATHER)
	mat.set_shader_parameter("wobble", 0.0)
	mat.set_shader_parameter("mottle", 0.0)
	mat.set_shader_parameter("noise_tex", Art.tex("noise"))
	band.material = mat
	viewport.add_child(band)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	viewport.queue_free()
	var lane: Vector2 = road["lane"]
	var half: float = float(road["band"]) * 0.5
	# Samples per arm (W, E, N, S), clear of the other arms. The first/last
	# entries sit at or past the inset door edge; 400-540 is the crossing.
	var samples := [[150, 300, 400, 470, 540, 650, 750, 850],
		[1300, 1400, 1500, 1600, 1700, 1812, 1962],
		[100, 150, 200, 250, 300, 350, 400, 440],
		[810, 870, 930, 990, 1050, 1098, 1150]]
	var widths: Array[float] = []
	for arm in 4:
		var horizontal := arm < 2
		var bend := 0.0
		for s in samples[arm]:
			var run := _run(img, int(s), horizontal)
			if run.x < 0: return "rendered road is missing at %d" % s
			var drawn := float(run.x + run.y) * 0.5 + 0.5 - (lane.y if horizontal else lane.x)
			var curve: Vector2 = g.road_curve(road, arm, float(s) + 0.5)
			if absf(drawn - curve.x) > 2.0:
				return "drawn road and road_curve() disagree by %.1f px (arm %d at %d)" % [drawn - curve.x, arm, s]
			var width := float(run.y - run.x + 1)
			if absf(width - (2.0 * half * curve.y - FEATHER)) > 3.0:
				return "drawn road width and road_curve() disagree (arm %d at %d)" % [arm, s]
			widths.append(width)
			var pinned: bool = (arm == 0 and (s <= 300 or (s >= 400 and s <= 540))) \
				or (arm == 1 and s >= 1812) or (arm == 2 and s <= 150) or (arm == 3 and s >= 1098)
			if pinned and absf(drawn) > 1.5:
				return "rendered road left the straight lane at a door or crossing (arm %d at %d)" % [arm, s]
			bend = maxf(bend, absf(drawn))
		if bend < 20.0: return "rendered road arm %d remains a straight band" % arm
	if widths.max() - widths.min() < 8.0: return "rendered road width never varies"
	# Laid-stone rim: dark along the long sides, never a bar across a doorway.
	# The run's first pixel sits FEATHER/2 inside the band edge; the rim is
	# darkest just past FEATHER.
	var top := _run(img, 650, true).x
	var centre: float = img.get_pixel(650, int(lane.y + g.road_curve(road, 0, 650.5).x)).r
	if img.get_pixel(650, top + int(FEATHER * 0.5) + 1).r > centre * 0.8:
		return "stone path lost its darker inset edge"
	var inset := int(FEATHER) + 1
	for door in [Vector2i(inset, int(lane.y)), Vector2i(g.ROOM_W - 1 - inset, int(lane.y)),
			Vector2i(int(lane.x), g.TILE + inset), Vector2i(int(lane.x), g.ROOM_H - g.TILE - 1 - inset)]:
		if img.get_pixel(door.x, door.y).r < centre * 0.95:
			return "stone edge draws a bar across the doorway at %s" % door
	print("ok: rendered road bends every arm, varies width, matches road_curve and holds door lanes, crossings and the stone rim")
	return ""


## First/last pixel with alpha > 0.5 across a column (horizontal arm) or a
## row (vertical arm) of the render; (-1, -1) when the band is absent.
static func _run(img: Image, at: int, horizontal: bool) -> Vector2i:
	var first := -1
	var last := -1
	for i in (img.get_height() if horizontal else img.get_width()):
		var alpha := img.get_pixel(at, i).a if horizontal else img.get_pixel(i, at).a
		if alpha > 0.5:
			if first < 0: first = i
			last = i
	return Vector2i(first, last)


static func run(t: Node) -> String:
	var g: Game = t.game
	# Isolate road probes from existing rooms/marks, including failure exits.
	var rooms: Array = g.rooms
	var zones: Array = g.zones
	var terrains: Array = g.terrain_by_zone
	var rivers: Dictionary = g.rivers
	var marks: Dictionary = g.zone_road_marks
	g.rooms = rooms.duplicate(true)
	g.zones = zones.duplicate(true)
	g.terrain_by_zone = terrains.duplicate()
	g.rivers = rivers.duplicate(true)
	g.zone_road_marks = {}
	var error := _roads(g)
	for nodes in g.zone_road_marks.values():
		for node in nodes:
			node.free()
	g.rooms = rooms
	g.zones = zones
	g.terrain_by_zone = terrains
	g.rivers = rivers
	g.zone_road_marks = marks
	if error == "": error = _palette()
	if error == "": error = _floors(g)
	if error == "": error = _backdrops(g)
	if error == "":
		print("ok: world read (seeded road arms, crossings, prop clearance, dark wear, stone edge, warm value floor, grounded arches)")
	return error


static func _road_material(g: Game, zi: int) -> ShaderMaterial:
	g._mark_roads(zi)
	var marks: Array = g.zone_road_marks[zi]
	return null if marks.is_empty() else (marks[0] as Sprite2D).material as ShaderMaterial


static func _roads(g: Game) -> String:
	var seeds: Array[float] = []
	for zi in [0, 1]:
		g.rooms[zi]["exits"] = {"W": 1, "E": 1, "N": 1, "S": 1}
		g.terrain_by_zone[zi] = "magma"
		g.rivers.erase(zi)
		g.zones[zi]["backdrops"] = []
		var mat := _road_material(g, zi)
		var road: Sprite2D = g.zone_road_marks[zi][0]
		if road.modulate.r > 0.0 or road.modulate.g > 0.0 or road.modulate.b > 0.0:
			return "magma road still adds a pale smoke wash"
		var amplitude = mat.get_shader_parameter("meander_px")
		if amplitude == null or float(amplitude) < 40.0 or float(amplitude) > 80.0:
			return "road meander must be 40-80 world pixels"
		if float(mat.get_shader_parameter("width_variation")) <= 0.0:
			return "road widths still form a fixed cross"
		var phases: PackedFloat32Array = mat.get_shader_parameter("arm_offsets")
		for i in 4:
			for j in i:
				if is_equal_approx(phases[i], phases[j]):
					return "road arms share a phase"
		var pr := g.play_rect(zi)
		var origin: Vector2 = g.rooms[zi]["origin"]
		if mat.get_shader_parameter("play_bounds") != Vector4(pr.position.x - origin.x,
				pr.position.y - origin.y, pr.end.x - origin.x, pr.end.y - origin.y):
			return "road meander is not pinned at the actual inset door lanes"
		# Every arm is centred on its door lane, whatever the band width knob.
		var layout: Dictionary = g.road_layout(zi)
		var doors: PackedVector2Array = layout["doors"]
		for i in (layout["arms"] as Array).size():
			var arm: Rect2 = layout["arms"][i]
			var horizontal := arm.size.x > arm.size.y
			if absf((arm.get_center().y - g.ROOM_H * 0.5) if horizontal else (arm.get_center().x - g.ROOM_W * 0.5)) > 0.5:
				return "road arm %d is off its door lane" % i
			# The stone rim runs on past the doorway end only (W/N start, E/S end).
			var door_at_start := arm.position.x <= 0.0 if horizontal else arm.position.y <= g.TILE
			if (doors[i].x > 0.0) != door_at_start or (doors[i].y > 0.0) == door_at_start:
				return "road arm %d marks the wrong end as its doorway" % i
		seeds.append(float(mat.get_shader_parameter("room_seed")))
		var rebuilt := _road_material(g, zi)
		if not is_equal_approx(seeds[-1], float(rebuilt.get_shader_parameter("room_seed"))):
			return "rebuilding a room rerolled its roads"
	if is_equal_approx(seeds[0], seeds[1]): return "different rooms share a road seed"
	var error := _crossings(g)
	if error == "": error = _prop_clearance(g)
	if error == "": error = _stone_edges(g)
	return error


## A river's bridge and an arcade's arch sit on the straight lane: the road
## holds it there (the bridge is built on it, the arch collider gap is cut on it).
static func _crossings(g: Game) -> String:
	var origin: Vector2 = g.rooms[0]["origin"]
	g.rooms[0]["exits"] = {"W": 1, "E": 1, "N": 1, "S": 1}
	g.terrain_by_zone[0] = "marsh"   # a dirt track over a field: a drawn road
	g.rivers[0] = {"rect": Rect2(origin + Vector2(380, 0), Vector2(150, g.ROOM_H))}
	var wet: Dictionary = g.road_layout(0)
	for x in [350.0, 380.0, 455.0, 530.0, 560.0]:
		var curve: Vector2 = g.road_curve(wet, 0, x)
		if absf(curve.x) > 0.01 or absf(curve.y - 1.0) > 0.001:
			return "road bends or swells off the straight lane over the bridge"
	var mat := _road_material(g, 0)
	if int(mat.get_shader_parameter("pin_count")) != 1:
		return "the road shader never hears about the river crossing"
	# A channel close enough for a north-south arm's swing keeps that arm straight.
	g.rivers[0] = {"rect": Rect2(origin + Vector2(g.ROOM_W * 0.5 - 200.0, 0), Vector2(120, g.ROOM_H))}
	var near: Dictionary = g.road_layout(0)
	for y in range(80, 1180, 40):
		if absf(g.road_curve(near, 2, float(y)).x) > 0.01 or absf(g.road_curve(near, 3, float(y)).x) > 0.01:
			return "a north-south road swings into the river beside it"
	g.rivers.erase(0)
	# The arcade's arch frames the north road on the straight lane.
	g.rooms[0]["exits"] = {"N": 1, "S": 1}
	g.terrain_by_zone[0] = "capital_civic"
	g.zones[0]["backdrops"] = [{"name": "capital_city_arcade", "x": 1056, "y": 405, "w": 1653.75}]
	var arcade: Dictionary = g.road_layout(0)
	if float(arcade["meander"]) <= 0.0: return "the capital path lost its curve (arch pin untested)"
	var base_y: float = g.room_pos(0, 1056, 405).y - origin.y
	for y in [base_y - 200.0, base_y - 60.0, base_y, base_y + 40.0]:
		if y > g.TILE and absf(g.road_curve(arcade, 0, y).x) > 0.01:
			return "the north road bends off the arcade's arch at y %d" % int(y)
	g.zones[0]["backdrops"] = []
	return ""


## Props keep off the DRAWN road: where it bends, the clearance bends with it.
static func _prop_clearance(g: Game) -> String:
	g.rooms[0]["exits"] = {"W": 1, "E": 1}
	g.terrain_by_zone[0] = "village"
	g.rivers.erase(0)
	var road: Dictionary = g.road_layout(0)
	if float(road["meander"]) <= 0.0: return "a drawn dirt track lost its curve"
	road["seed"] = 0.8          # a known bulge; the rule must hold for any seed
	road["bounds"] = Vector4(0, 0, g.ROOM_W, g.ROOM_H)
	road["pins"] = []
	var inset: Vector2 = road["inset"]
	var lane: Vector2 = road["lane"]
	var best := Vector2.ZERO
	var best_x := 0.0
	for x in range(200, 880, 10):
		var curve: Vector2 = g.road_curve(road, 0, float(x))
		if absf(curve.x) > absf(best.x):
			best = curve
			best_x = float(x)
	if absf(best.x) < 30.0: return "prop clearance probe found no road bend"
	var side := signf(best.x)
	var reach := Balance.ROAD_PROP_CLEAR.y + float(road["band"]) * 0.5 * (best.y - 1.0)
	var on_road := Vector2(best_x, lane.y + best.x + side * (reach - 4.0)) - inset
	if absf(on_road.y + inset.y - lane.y) < Balance.ROAD_PROP_CLEAR.y:
		return "prop clearance probe landed inside the straight lane"
	if not g._lane_blocked(road, on_road): return "a prop can stand on the bent road"
	if g._lane_blocked(road, Vector2(best_x, lane.y + best.x + side * (reach + 4.0)) - inset):
		return "prop clearance no longer follows the road's bend"
	if not g._lane_blocked(road, Vector2(best_x, lane.y - side * (Balance.ROAD_PROP_CLEAR.y - 4.0)) - inset):
		return "the straight east-west door lane is no longer kept clear"
	return ""


## The laid-stone edge belongs to capital holystone paths only.
static func _stone_edges(g: Game) -> String:
	g.rooms[0]["exits"] = {"W": 1, "E": 1, "N": 1, "S": 1}
	for id in ["capital_civic", "capital_wayfinder", "holy"]:
		g.terrain_by_zone[0] = id
		var edge = _road_material(g, 0).get_shader_parameter("stone_edge_px")
		var px := 0.0 if edge == null else float(edge)
		if id == "holy" and px != 0.0: return "stone edge leaked onto a non-capital holystone road"
		if id != "holy" and (px < 6.0 or px > 10.0): return "capital stone path lost its inset edge: " + id
	return ""


static func _palette() -> String:
	var original_sums := {"keep": 2.46, "capital_wayfinder": 2.82,
		"capital_choir": 2.80, "capital_approach": 2.89}
	for id in original_sums:
		var tint: Color = Terrains.DATA[id]["tint"]
		if minf(tint.r, minf(tint.g, tint.b)) < 0.6 or (tint.r + tint.g + tint.b) / 3.0 < 0.75:
			return "fortress tint below the value floor: " + id
		if tint.r < tint.g or tint.g < tint.b: return "fortress tint still lilac/blue: " + id
		if not is_equal_approx(tint.r + tint.g + tint.b, original_sums[id]):
			return "fortress hue change also changed average value: " + id
		var floor_color := Floor.floor_modulate(Terrains.DATA[id])
		if floor_color.b > floor_color.r: return "fortress floor adds a blue cast: " + id
	for id in Terrains.DATA:
		if id == "keep" or String(id).begins_with("capital_"): continue
		if Floor.floor_modulate(Terrains.DATA[id]) != Balance.FLOOR_LAYER_MODULATE:
			return "fortress floor modulation leaked into " + id
	return ""


## The fortress modulate shifts hue at the same value, and a repainted floor
## (dev terrain paint, rigs) picks up the new terrain's modulate every time.
static func _floors(g: Game) -> String:
	var fort := Balance.FORTRESS_FLOOR_MODULATE
	var base := Balance.FLOOR_LAYER_MODULATE
	if absf((fort.r + fort.g + fort.b) - (base.r + base.g + base.b)) / 3.0 > 0.005:
		return "fortress floor modulate changed the floor's value, not only its hue"
	if fort.b > fort.g or fort.g > fort.r: return "fortress floor modulate is not warm"
	var keep: Dictionary = Terrains.DATA["keep"]
	var village: Dictionary = Terrains.DATA["village"]
	var scratch := Node2D.new()
	g.add_child(scratch)
	var error := ""
	var ground := Floor.add_ground(g, scratch, 0, keep)
	if ground.modulate != fort: error = "keep ground misses the fortress modulate"
	Floor.repaint_ground(g, ground, 0, village)
	if error == "" and ground.modulate != base: error = "a repainted ground kept the fortress modulate"
	var poly := Floor.field(g, scratch, 0, keep)
	if error == "" and (poly == null or poly.modulate != fort):
		error = "keep field misses the fortress modulate"
	if poly != null:
		var reused := Floor.field(g, scratch, 0, village, poly)
		if error == "" and (reused != poly or poly.modulate != base):
			error = "a reused field kept the fortress modulate"
	scratch.free()
	return error


static func _backdrops(g: Game) -> String:
	var art_error := _arch_matches_art()
	if art_error != "": return art_error
	for width in [900.0, 1190.7, 1653.75]:
		var arcade := g._add_backdrop("capital_city_arcade", Vector2(-4900, -4900), width)
		var error := _grounding_contract(arcade, width)
		arcade.free()
		if error != "": return error
	# These landmarks already have silhouette-hugging shadows: do not stack a second one.
	for id in ["capital_watchtower", "capital_emberward_gate", "capital_crown_spire_gate"]:
		var landmark := g._add_structure(id, Vector2(-4900, -4900))
		var shadows := 0
		for child in landmark.get_children():
			if child.has_meta("cast_shadow"): shadows += 1
		landmark.free()
		if shadows == 0: return "capital landmark lacks a contact shadow: " + id
	return ""


## The authored arch_span must match the painted opening at the art's solid
## base: transparent just inside each end, opaque pier just outside it.
static func _arch_matches_art() -> String:
	var def: Dictionary = Terrains.STRUCTURES["capital_city_arcade"]
	var img: Image = Art.tex(String(def["sprite"])).get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var base := -1
	for y in range(img.get_height() - 1, -1, -1):
		var solid := 0
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5: solid += 1
		if solid * 2 >= int(w * 0.9):
			base = y
			break
	if base < 0: return "arcade art has no solid base row"
	var span: Vector2 = def["arch_span"]
	var src := float(w) / float(def["w"])
	var left := int(round(w * 0.5 + span.x * src))
	var right := int(round(w * 0.5 + span.y * src))
	if img.get_pixel(left - 3, base).a < 0.5 or img.get_pixel(right + 3, base).a < 0.5:
		return "arcade grounding runs into the painted arch"
	if img.get_pixel(left + 3, base).a > 0.5 or img.get_pixel(right - 3, base).a > 0.5:
		return "arcade grounding stops short of the arch piers"
	return ""


static func _grounding_contract(arcade: Node2D, width: float) -> String:
	var contact := arcade.get_node_or_null("BackdropGrounding") as Node2D
	if contact == null: return "arcade still floats without a foundation/contact shadow"
	var visual: Node2D = null
	for child in arcade.get_children():
		if child is Node2D and (child as Node2D).is_in_group("structure_occluders"):
			visual = child
	if visual == null: return "arcade lost its facade"
	if contact.z_index >= visual.z_index: return "arcade grounding draws over the facade"
	var def: Dictionary = Terrains.STRUCTURES["capital_city_arcade"]
	var arch: Vector2 = (def["arch_span"] as Vector2) * (width / float(def["w"])) \
		+ Vector2.ONE * visual.position.x
	var shadows := 0
	var bases := 0
	for child in contact.get_children():
		var sprite := child as Sprite2D
		var size: Vector2 = sprite.texture.get_size() * sprite.scale
		var left: float = sprite.position.x
		var right: float = left + size.x
		if left < arch.y - 0.01 and right > arch.x + 0.01:
			return "arcade foundation/shadow closes the painted arch"
		if absf(right - arch.x) > 0.01 and absf(left - arch.y) > 0.01:
			return "arcade grounding stops short of the arch piers"
		if left < visual.position.x - width * 0.5 - 0.01 or right > visual.position.x + width * 0.5 + 0.01:
			return "arcade grounding exceeds the facade width"
		if sprite.texture == Art.tex("softshadow"):
			shadows += 1
			if not is_equal_approx(sprite.position.y, Balance.BACKDROP_BASE_Y + Balance.BACKDROP_FOUNDATION_HEIGHT):
				return "arcade contact shadow does not start under the foundation"
			if size.y < 40.0 or size.y > 60.0 or not is_equal_approx(sprite.modulate.a, 0.5):
				return "arcade contact shadow lost its soft 40-60px strip"
		elif sprite.texture == Art.tex("white"):
			bases += 1
			if not is_equal_approx(sprite.position.y, Balance.BACKDROP_BASE_Y):
				return "arcade foundation is not at the facade's opaque base"
			if size.y < 6.0 or size.y > 10.0:
				return "arcade foundation is not a narrow stone band"
		else:
			return "arcade grounding has an unexpected piece"
	if shadows != 2 or bases != 2:
		return "arcade grounding must be a foundation band and a shadow either side of the arch"
	return ""
