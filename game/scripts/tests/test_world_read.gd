extends RefCounted
const Floor := preload("res://scripts/room_floor.gd")
const Dressing := preload("res://scripts/floor_dressing.gd")
const FEATHER := 34.0   # the band's soft edge, pinned for the render check


# Real actor types/layers, with no AI, input, stats or campaign side effects.
class BrushPlayer extends Player:
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 13.0
		add_child(shape)
		set_process(false)
		set_physics_process(false)


class BrushEnemy extends Enemy:
	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 13.0
		add_child(shape)
		set_physics_process(false)


## Physics regression shared by systems and the walk-through capture rig.
## All nodes are owned fixtures far from campaign actors; no shared state loan.
static func foliage(t: Node) -> String:
	var g: Game = t.game
	var fixture := Node2D.new()
	fixture.position = Vector2(-100000, -100000)
	g.world.add_child(fixture)
	var kept_shake := g.shake_amt
	var kept_shake_input := g._shake_in_amt
	var kept_attacks := g._ground_attacks.duplicate()
	var kept_paused := g.get_tree().paused
	var error := await _foliage_contract(g, fixture)
	g.get_tree().paused = kept_paused
	g.shake_amt = kept_shake
	g._shake_in_amt = kept_shake_input
	for attack in g._ground_attacks.duplicate():
		if not attack in kept_attacks and is_instance_valid(attack):
			attack.free()
	fixture.free()  # also kills any bound decay tween on every failure path
	if error == "": error = _planted_understory(g)
	if error == "":
		print("FOLIAGE PASS: idle, player/enemy contact, settle, isolated materials, mirrored scatter bush, settles under pause, area and telegraph impacts, read-only targeting and canopy control")
	return error


static func _foliage_contract(g: Game, fixture: Node2D) -> String:
	var bushes: Array[Node2D] = []
	var names := ["bush", "bush2", "bush3", "bush_autumn", "grass", "grass2",
		"grass3", "grass_autumn", "grass_frost", "flower", "cattail", "cattail2",
		"cattail3", "frost_reeds"]
	for i in names.size():
		var plant := g._structure_sprite(names[i], 100.0, true)
		plant.position.x = i * 250.0
		fixture.add_child(plant)
		bushes.append(plant)
		if not plant.has_node("FoliageRustle"):
			return "%s has no interaction sensor (old idle-wind behavior)" % names[i]
		if plant is AnimatedSprite2D and (plant.is_playing() or plant.frame != 0):
			return "%s still plays an idle art loop" % names[i]
		if plant.material == Art.wind_material() or float(plant.material.get_shader_parameter("amp")) != 0.0:
			return "%s has idle wind motion" % names[i]
	var tree := g._structure_sprite("tree_green", 180.0, true)
	fixture.add_child(tree)
	if tree.material != Art.wind_material() or (tree is AnimatedSprite2D and not tree.is_playing()):
		return "canopy wind/animation changed"
	var bush := bushes[0]
	var sensor = bush.get_node("FoliageRustle")   # untyped: script members below
	var wind: ShaderMaterial = bush.material
	await g.get_tree().create_timer(0.15).timeout
	if float(wind.get_shader_parameter("amp")) != 0.0:
		return "empty bush started rustling"
	var hero := BrushPlayer.new()
	hero.game = g
	hero.position = Vector2(-200, 0)
	fixture.add_child(hero)
	var enemy := BrushEnemy.new()
	enemy.game = g
	enemy.position = Vector2(-200, 100)
	fixture.add_child(enemy)
	for actor in [hero, enemy]:
		var who := "player" if actor == hero else "enemy"
		# A zero-velocity positional update is how remote shells can enter.
		await g.get_tree().create_timer(0.08).timeout
		actor.global_position = sensor.global_position
		await g.get_tree().create_timer(0.08).timeout
		if float(wind.get_shader_parameter("amp")) <= 0.0:
			return "body-entered did not rustle for the %s" % who
		if float(bushes[1].material.get_shader_parameter("amp")) != 0.0:
			return "brushing one bush shook a distant bush"
		# Staying inside must settle too: presence alone is not interaction.
		await g.get_tree().create_timer(Balance.FOLIAGE_RUSTLE_DECAY + 0.15).timeout
		if float(wind.get_shader_parameter("amp")) != 0.0:
			return "stationary %s kept bush rustling" % who
		actor.position = Vector2(-200, 0)
		await g.get_tree().create_timer(0.08).timeout
	var error := await _scatter_bush(g, fixture, hero)
	if error != "":
		return error
	# Aim queries cannot stir foliage; an empty damaging sweep must do so.
	g.player._enemies_within(sensor.global_position, 20.0)
	if float(wind.get_shader_parameter("amp")) != 0.0:
		return "target query rustled a bush"
	g.player._area_hit_targets(sensor.global_position, 20.0)
	if float(wind.get_shader_parameter("amp")) <= 0.0:
		return "area damage missed an empty bush"
	# A solo pause (menu, talk, choice) stops the tree but not the shader's
	# clock: the rustle must still settle instead of shaking until it ends.
	g.get_tree().paused = true
	await g.get_tree().create_timer(Balance.FOLIAGE_RUSTLE_DECAY + 0.15).timeout
	var paused_amp := float(wind.get_shader_parameter("amp"))
	g.get_tree().paused = false   # the caller restores the entry state
	if paused_amp != 0.0:
		return "a rustle caught by a pause kept shaking through it"
	# Real enemy impact seam: a zero-damage solo/host burst (the bloat pop) and
	# the guest's visual-only mirror must both rustle, so every peer agrees.
	for mirrored in [false, true]:
		_still(sensor)
		await g.telegraph(sensor.global_position, 20.0, 0.05, 0.0,
			{"net_visual": mirrored, "impact_sfx": ""})
		if float(wind.get_shader_parameter("amp")) <= 0.0:
			return "%s zero-damage telegraph impact did not rustle" % ("mirrored" if mirrored else "solo")
	return ""


## The scatter path owners see most: a real bush obstacle from _add_obstacle,
## mirrored like half the field, so the sensor must follow a negative x scale.
static func _scatter_bush(g: Game, fixture: Node2D, hero: Node2D) -> String:
	var plant: Node2D = null
	var body: StaticBody2D = null
	for k in 16:
		body = g._add_obstacle("bush", fixture.global_position + Vector2(k * 250.0, 700.0))
		body.reparent(fixture)   # freed with the fixture on every exit path
		for child in body.get_children():
			if child.has_node("FoliageRustle"):
				plant = child
		if plant != null and plant.scale.x < 0.0:
			break
		plant = null
		body.free()
		body = null
	if plant == null:
		return "no mirrored scatter bush with an interaction sensor"
	var wind := plant.material as ShaderMaterial
	if wind == null or wind == Art.wind_material() or float(wind.get_shader_parameter("amp")) != 0.0:
		return "scatter bush obstacle idles in the shared wind"
	if plant is AnimatedSprite2D and plant.is_playing():
		return "scatter bush obstacle still plays its idle loop"
	for child in body.get_children():
		if child.has_meta("cast_shadow") and child.material != wind:
			return "scatter bush cast shadow no longer sways with its bush"
	var sensor = plant.get_node("FoliageRustle")
	hero.global_position = sensor.global_position
	await g.get_tree().create_timer(0.08).timeout
	var amp := float(wind.get_shader_parameter("amp"))
	hero.position = Vector2(-200, 0)
	_still(sensor)
	await g.get_tree().create_timer(0.08).timeout
	if amp <= 0.0:
		return "brushing a mirrored scatter bush did not rustle it"
	return ""


## Settle a fixture plant at once between probes (no wait on its decay).
static func _still(sensor) -> void:
	if sensor.decay != null:
		sensor.decay.kill()
	sensor.wind.set_shader_parameter("amp", 0.0)


## Production decor as the procedural rooms planted it (the systems tier and
## the capture rig both stand in Emberfall, whose terrain scatters grass,
## flowers and bushes). Every understory sticker is still, carries its sensor
## and still kicks leaves when walked through. Amplitude is not checked here:
## a live actor may have brushed one a moment ago.
static func _planted_understory(g: Game) -> String:
	var stickers := 0
	for zi in g.zone_scenery:
		for node in g.zone_scenery[zi]:
			if not is_instance_valid(node) or not (node is Sprite2D or node is AnimatedSprite2D):
				continue
			if not node.has_node("FoliageRustle"):
				continue
			stickers += 1
			if node.material == Art.wind_material():
				return "an understory sticker in room %d still sways in the idle wind" % zi
			if node is AnimatedSprite2D and node.is_playing():
				return "an understory sticker in room %d still plays its idle loop" % zi
			if node is Sprite2D and not g._rustles(node):
				return "walking through an understory sticker in room %d no longer kicks leaves" % zi
	print("ok: %d planted understory stickers are still, sensed and kick walk-through leaves" % stickers)
	return ""


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
	if error == "": error = _dressing(g)
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


## Pure layout probes use the isolated rooms/terrains in run(). Node probes
## lend a fresh scenery dictionary (and the capital's chapter id, which keys
## road seeds) and restore them on every failure path.
static func _dressing(g: Game) -> String:
	var scenery: Dictionary = g.zone_scenery
	var kept_seed: int = g.wander_seed
	var chapter: String = g.chapter_id
	g.zone_scenery = {0: []}
	g.wander_seed = 42017
	var error := _dressing_contract(g)
	_free_lent(g)
	if error == "": error = _civic_contract(g)
	_free_lent(g)
	g.zone_scenery = scenery
	g.wander_seed = kept_seed
	g.chapter_id = chapter
	return error


static func _free_lent(g: Game) -> void:
	for nodes in g.zone_scenery.values():
		for node in nodes:
			if is_instance_valid(node): node.free()
	g.zone_scenery = {0: []}


static func _dressing_contract(g: Game) -> String:
	g.terrain_by_zone[0] = "keep"
	g.rivers.erase(0)
	g.zones[0] = {"type": "safe", "room_scale": 1.0, "backdrops": []}
	g.rooms[0]["scale"] = Vector2.ONE
	g.rooms[0]["exits"] = {"W": 1, "E": 1, "N": 1, "S": 1}
	var first := Dressing.wear_plan(g, 0)
	if first != Dressing.wear_plan(g, 0): return "floor wear rerolls on repaint"
	g.wander_seed += 1
	var changed := Dressing.wear_plan(g, 0)
	g.wander_seed -= 1
	if first == changed: return "floor wear ignores the room's run seed"
	var lit := 0
	var edge := 0
	var bounds := Dressing.inner(g, 0)
	for patch in first:
		if patch.size.x < 400.0 or patch.size.x > 900.0: return "floor wear is not room-scale (400-900px)"
		if patch.alpha < 0.15 or patch.alpha > 0.30: return "floor wear alpha leaves the quiet macro band"
		var uv: Vector2 = (patch.pos - bounds.position) / bounds.size
		if minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y)) <= 0.20: edge += 1
		if Floor.edge_value(patch.pos - g.room_rect(0).position, Floor.inner_floor(g, 0)) > 0.98: lit += 1
	if lit < 2 or edge <= first.size() / 2: return "wear lacks lit-centre patches or a wall/corner bias"
	# Exercise the production spawn, so keeping a correct unused planner cannot pass.
	g._spawn_floor_wear(0, Terrains.DATA["keep"], g.play_rect(0))
	if g.zone_scenery[0].size() != first.size(): return "production floor wear does not use the macro plan"
	for i in first.size():
		var sprite: Sprite2D = g.zone_scenery[0][i]
		if not sprite.has_meta("floor_wear") or sprite.position != first[i].pos or not (sprite.texture.get_size() * sprite.scale).is_equal_approx(first[i].size):
			return "production wear scale/position differs from the repaint-stable plan"
		if sprite.z_index != -9 or sprite.modulate.r != 0.0: return "wear competes with ground tells"
		if g._rustles(sprite): return "floor wear throws grass-rustle leaves"
		var mat := sprite.material as ShaderMaterial
		if mat == null or mat.get_shader_parameter("noise_scales") != Balance.FLOOR_WEAR_NOISE_SCALES: return "production wear misses the tuned noise scales"
	# The second, lower-frequency field is the one that breaks the repeat.
	var scales := Balance.FLOOR_WEAR_NOISE_SCALES
	if scales.x <= 0.0 or scales.y < scales.x * 2.0 or not Dressing.WearShader.code.contains("noise_scales.y"):
		return "wear lost its second low-frequency noise multiply"
	# Real production visuals: an understory grass tuft (still until touched)
	# keeps kicking leaves, a tree sticker in the shared wind does too, and a
	# rigid pebble beside them never does.
	var tuft := g._prop_visual("grass")
	var stone := g._prop_visual("pebble")
	var sway := Sprite2D.new()
	sway.material = Art.wind_material()
	var tuft_rustles := tuft is Sprite2D and g._rustles(tuft as Sprite2D)
	var stone_rustles := stone is Sprite2D and g._rustles(stone as Sprite2D)
	var sways := g._rustles(sway)
	tuft.free()
	stone.free()
	sway.free()
	if not tuft_rustles: return "walking through grass no longer kicks leaves"
	if not sways: return "swaying decor no longer rustles"
	if stone_rustles: return "a rigid pebble throws grass-rustle leaves"
	var road := g.road_layout(0)
	var pr := g.play_rect(0)
	var group := Dressing.wall_plan(g, 0, [], [])
	if group.is_empty(): return "no wall-base dressing in a clear keep fixture"
	if group != Dressing.wall_plan(g, 0, [], []): return "wall dressing rerolls on repaint"
	var counts := {}
	for spec in group:
		counts[spec.cluster] = int(counts.get(spec.cluster, 0)) + 1
		var half: Vector2 = spec.size * 0.5
		for off in [Vector2.ZERO, -half, half, Vector2(half.x, -half.y), Vector2(-half.x, half.y)]:
			if g._lane_blocked(road, spec.pos + off - pr.position): return "wall dressing covers a door lane or curved road"
		var gap: Vector2 = (spec.pos - bounds.position).min(bounds.end - spec.pos)
		if minf(gap.x, gap.y) > 100.0: return "wall dressing drifted into fighting space"
	for n in counts.values():
		if n < 3 or n > 6: return "wall-base cluster is not 3-6 members"
	# An occupied anchor and a reservation must EACH displace the first cluster.
	var anchor: Vector2 = group[0].pos - pr.position
	var keep_off := Balance.WALL_DRESS_ANCHOR_CLEAR + (Balance.WALL_DRESS_SIZE * 0.5).length()
	for spec in Dressing.wall_plan(g, 0, [], [anchor]):
		if spec.pos.distance_to(group[0].pos) < keep_off: return "wall dressing piles onto an existing prop or landmark"
	for spec in Dressing.wall_plan(g, 0, [{"pos": anchor, "radius": 200.0}], []):
		if spec.pos.distance_to(group[0].pos) < 200.0: return "wall dressing ignores reservations"
	# The production spawn: every planned member lands as plain decor. Stones
	# are the scatter's solid ground rock at a uniform scale; only the soft
	# moss/dust drifts are translucent, and nothing throws rustle leaves.
	Dressing.spawn_details(g, 0, [], [], [])
	var members := 0
	for node in g.zone_scenery[0]:
		if not node.has_meta("wall_base"): continue
		members += 1
		var sprite := node as Sprite2D
		if sprite == null or sprite.get_child_count() != 0: return "new floor dressing added collision/actor nodes"
		if g._rustles(sprite): return "wall dressing throws grass-rustle leaves"
		if sprite.material == null:
			if sprite.texture == Art.tex("pebble"): return "wall pebbles use the round ambience stone, not the ground rock"
			if sprite.modulate.a < 1.0 or not is_equal_approx(absf(sprite.scale.x), sprite.scale.y):
				return "wall stones render see-through or squashed"
	if members != group.size() or members < 3: return "production wall dressing does not use the cluster plan"
	# Authored civic data belongs to the capital path, never random terrain scatter.
	var authored_rooms := 0
	for zone in CapitalHub.CHAPTER.zones:
		if zone.terrain not in ["capital_civic", "capital_approach"]: continue
		var kinds := {}
		for spec in zone.get("floor_dressing", []):
			kinds[spec.kind] = true
			if spec.key != "glow" and not FileAccess.file_exists("res://assets/sprites/%s.png" % spec.key): return "civic dressing references missing art"
		if kinds.size() != 3: return "civic room lacks authored planters, puddles and banners"
		authored_rooms += 1
	if authored_rooms != 4: return "capital dressing coverage changed"
	print("ok: macro wear 400-900px, lit-centre coverage, seeded repaint, 3-6 wall clusters, lane/anchor clearance, decor-only walls, no stray rustle")
	return ""


## The authored capital pieces through the production spawn, each civic room
## rebuilt from its own content (arcade, landmarks, furniture, wear) on the
## capital's own road seed: dressing_room() then proves every piece landed,
## stays decor-only and is not buried under later-drawn architecture.
static func _civic_contract(g: Game) -> String:
	g.chapter_id = "capital"   # the caller restores it
	var rooms := 0
	for zi in CapitalHub.CHAPTER.zones.size():
		var zone: Dictionary = CapitalHub.CHAPTER.zones[zi]
		if (zone.get("floor_dressing", []) as Array).is_empty(): continue
		var error := _civic_room(g, zi, zone)
		_free_lent(g)
		if error != "": return error
		rooms += 1
	if rooms != 4: return "capital dressing coverage changed"
	return ""


static func _civic_room(g: Game, zi: int, zone: Dictionary) -> String:
	g.zones[zi] = zone.duplicate(true)
	g.terrain_by_zone[zi] = zone.terrain
	g.rivers.erase(zi)
	var exits := {}
	for dir in zone.exits: exits[dir] = zi
	g.rooms[zi]["exits"] = exits
	g.rooms[zi]["scale"] = Vector2.ONE
	g.zone_scenery[zi] = []
	var origin := g.play_rect(zi).position
	var room_scale := float(zone.get("room_scale", 1.0))
	g._spawn_floor_wear(zi, Terrains.get_terrain(zone.terrain), g.play_rect(zi))
	for backdrop in zone.get("backdrops", []):
		g.zone_scenery[zi].append(g._add_backdrop(backdrop.name,
			g.room_pos(zi, backdrop.x, backdrop.y), float(backdrop.w) * room_scale))
	var reserved: Array = []
	var placed: Array = []
	for spec in zone.get("landmarks", []) + zone.get("furnishings", []):
		var at := g.room_pos(zi, spec.x, spec.y)
		placed.append(at - origin)
		reserved.append({"pos": at - origin, "radius": float(spec.get("clearance", 190.0))})
		g.zone_scenery[zi].append(g._add_structure(spec.name, at))
	Dressing.spawn_details(g, zi, reserved, placed, zone.floor_dressing)
	return dressing_room(g, zi)


## Production room coverage (the bundled captures after placement, and the
## systems tier's rebuilt capital rooms).
static func dressing_room(g: Game, zi: int) -> String:
	var wear := 0
	var civic := 0
	var walls := 0
	var hidden := 0.0
	var images := {}
	var road := g.road_layout(zi)
	var origin := g.play_rect(zi).position
	for node in g.zone_scenery.get(zi, []):
		if not is_instance_valid(node): continue
		if node.has_meta("floor_wear"): wear += 1
		if node.has_meta("civic_dressing"): civic += 1
		if node.has_meta("wall_base"): walls += 1
		if node.has_meta("civic_dressing") or node.has_meta("wall_base") or node.has_meta("floor_wear"):
			var sprite := node as Sprite2D
			if sprite == null or sprite.get_child_count() != 0: return "dressing added a collider in room %d" % zi
			if g._rustles(sprite): return "floor dressing throws grass-rustle leaves in room %d" % zi
			if node.has_meta("floor_wear"): continue
			var centre := sprite.to_global(sprite.get_rect().get_center())
			if g._lane_blocked(road, centre - origin): return "dressing entered a road lane in room %d" % zi
			if not node.has_meta("civic_dressing"): continue
			var share := _hidden_share(g, zi, sprite, images)
			hidden = maxf(hidden, share)
			if share > HIDDEN_MAX:
				return "authored %s at %s is %d%% hidden behind later-drawn scenery in room %d" \
					% [node.get_meta("civic_dressing"), sprite.position, roundi(share * 100.0), zi]
	if wear < 6: return "production room %d lost its macro floor wear" % zi
	if civic != (g.zones[zi].get("floor_dressing", []) as Array).size(): return "capital authored dressing was dropped by clearance in room %d" % zi
	if g.terrain_by_zone[zi] == "keep" and walls < 3: return "keep room %d has no complete wall cluster" % zi
	if String(g.terrain_by_zone[zi]).begins_with("capital_") and walls > 0: return "generated wall scatter leaked into capital room %d" % zi
	print("ok: dressed room %d wear=%d wall-members=%d civic=%d worst-hidden=%d%%" % [zi, wear, walls, civic, roundi(hidden * 100.0)])
	return ""


const HIDDEN_MAX := 0.30   # share of an authored piece later-drawn scenery may cover

## Share of a dressing sprite's painted samples that opaque scenery drawn
## AFTER it covers: a higher z, or the same z sorted further south in the
## y-sorted world. Occluders = structure/facade art (structure_occluders)
## plus the arcade's foundation band and contact shadow.
static func _hidden_share(g: Game, zi: int, sprite: Sprite2D, images: Dictionary) -> float:
	var z := _z_of(sprite)
	var sort_y := _sort_y(g, sprite)
	var occluders: Array[Sprite2D] = []
	for node in g.zone_scenery.get(zi, []):
		if not is_instance_valid(node) or node == sprite: continue
		var candidates: Array = [node]
		candidates.append_array((node as Node).find_children("*", "Sprite2D", true, false))
		for candidate in candidates:
			var o := candidate as Sprite2D
			if o == null or not o.visible: continue
			if not o.is_in_group("structure_occluders") and String(o.get_parent().name) != "BackdropGrounding": continue
			var oz := _z_of(o)
			if oz > z or (oz == z and _sort_y(g, o) > sort_y):
				occluders.append(o)
	var painted := 0
	var covered := 0
	var rect := sprite.get_rect()
	for i in 7:
		for j in 7:
			var local := rect.position + rect.size * Vector2(0.1 + i * 0.8 / 6.0, 0.1 + j * 0.8 / 6.0)
			# The piece's own painted texels (a tinted puddle is faint by design).
			if _alpha_at(sprite, local, images) / maxf(0.001, sprite.modulate.a) < 0.3: continue
			painted += 1
			var at := sprite.to_global(local)
			for o in occluders:
				if _alpha_at(o, o.to_local(at), images) >= 0.5:
					covered += 1
					break
	return 1.0 if painted == 0 else float(covered) / float(painted)


## Texture alpha x modulate alpha at a sprite-local point (0 off its art).
static func _alpha_at(sprite: Sprite2D, local: Vector2, images: Dictionary) -> float:
	var rect := sprite.get_rect()
	if sprite.texture == null or not rect.has_point(local): return 0.0
	var uv := (local - rect.position) / rect.size
	if sprite.flip_h: uv.x = 1.0 - uv.x
	if sprite.flip_v: uv.y = 1.0 - uv.y
	if not images.has(sprite.texture):
		var img := sprite.texture.get_image()
		if img != null and img.is_compressed(): img.decompress()
		images[sprite.texture] = img
	var image: Image = images[sprite.texture]
	if image == null: return 0.0
	var px := Vector2i((uv * Vector2(image.get_size())).floor()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(px).a * sprite.modulate.a * sprite.self_modulate.a


static func _z_of(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative: break
		node = node.get_parent()
	return z


## The world y-sorts each direct child on its own y, except that a child with
## y_sort_enabled (a structure body) sorts its children individually.
static func _sort_y(g: Game, item: Node2D) -> float:
	var node := item
	while node.get_parent() != g.world:
		var parent := node.get_parent() as Node2D
		if parent == null or parent.y_sort_enabled: break
		node = parent
	return node.global_position.y


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
