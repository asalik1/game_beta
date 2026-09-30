extends RefCounted
const Threshold := preload("res://scripts/door_threshold.gd")
const FishingSpot := preload("res://scripts/fishing_spot.gd")
# Fixture rooms: 0 full size, 7 an authored 0.72 room, 1 and 2 SMALL rooms whose
# hashed asymmetric insets put the N (1) or S (2) wall close to the centre.
const SMALL_ROOMS := [1, 2]


## Synchronous production placement fixtures: no AI/ticks, no accumulated state.
## Every field loan and every spawned node is restored even on the first failure.
static func run(t: Node) -> String:
	var g: Game = t.game
	var saved := {}
	for key in ["rooms", "zones", "terrain_by_zone", "rivers", "world", "zone_scenery",
			"hazards", "interactables", "chapter_id", "wander_seed", "zone_count",
			"coord_to_room", "edge_locks", "pocket_room", "shortcut_edge", "pvp_active", "endgame_active", "weekly_active"]:
		saved[key] = g.get(key)
	var fixture := Node2D.new()
	t.add_child(fixture)
	g.world = fixture
	g.rooms = []
	g.zones = []
	g.terrain_by_zone = []
	g.zone_count = 8
	g.chapter_id = "threshold_fixture"
	g.wander_seed = 42017
	g.pocket_room = -1
	g.shortcut_edge = {}
	g.coord_to_room = {}
	g.edge_locks = {}
	g.zone_scenery = {}
	g.hazards = []
	g.interactables = []
	g.rivers = {}
	g.pvp_active = false
	g.endgame_active = false
	g.weekly_active = false
	for i in g.zone_count:
		g.rooms.append({"origin": Vector2(-100000, -100000), "scale": Vector2.ONE,
			"coord": Vector2i.ZERO, "exits": {"N": 1, "S": 1, "W": 1, "E": 1}})
		g.zones.append({"name": "threshold fixture", "type": "dead_end" if i in SMALL_ROOMS else "combat",
			"enemies": [] if i in SMALL_ROOMS else [["wolf", 500, 500, 0]]})
		g.terrain_by_zone.append("darkwood")
	var error := _contract(g)
	if error == "": error = _authored(g)
	_clear(g)
	fixture.free()
	for key in saved: g.set(key, saved[key])
	if error == "": print("DOOR THRESHOLD PASS: all terrain seeds, inset mouths, full factory footprints, density, deterministic rebuilds and hazard negative controls")
	return error


static func _clear(g: Game) -> void:
	for node in g.world.get_children(): node.free()
	g.zone_scenery = {}
	g.hazards = []
	g.interactables = []
	g.rivers = {}


static func _contract(g: Game) -> String:
	# Old _pool_blocked accepted this exact arrival point; assert the production
	# seeded-pool guard, not only the new geometry helper.
	var mouth := Vector2(g.room_center(0).x, g.play_rect(0).position.y + 100)
	for type in ["poison", "slow", "lava"]:
		if not g._pool_blocked(0, mouth, 65): return "old threshold pool placement accepted " + type
		# Live combat pools are NOT filtered: a boss/mob pool lands where it was
		# telegraphed (Cinderhide tags hazards.back() right after the call).
		g._add_hazard(0, type, mouth, 65, 10.0)
		if g.hazards.size() != 1 or g.hazards.back().pos != mouth:
			return "the shared combat hazard factory dropped a telegraphed %s pool on a door apron" % type
		_clear(g)
	var early := _small_rooms(g)
	if early == "": early = _fishing(g)
	if early != "": return early
	var road := g.road_layout(0)
	var pr := g.play_rect(0)
	for zone: Rect2 in Threshold.zones(g, 0):
		var relocated := Threshold.clear_point(g, 0, zone.get_center(), Balance.DOOR_THRESHOLD_OFFER_RADIUS)
		if Threshold.intersects(Threshold.zones(g, 0), Rect2(relocated - Vector2.ONE * Balance.DOOR_THRESHOLD_OFFER_RADIUS,
				Vector2.ONE * Balance.DOOR_THRESHOLD_OFFER_RADIUS * 2.0)):
			return "door-triggered offer did not move beyond apron"
	# Plant south of the west lane: the centre clears ROAD_PROP_CLEAR but its
	# crown covers the mouth. Outgoing point-only _lane_blocked accepts it.
	var tree_pos := Vector2(pr.position.x + 90, g.room_center(0).y + 230)
	if not g._lane_blocked(road, tree_pos - pr.position, Threshold.scatter_footprint(g, "tree_autumn", tree_pos)):
		return "point-only road clearance accepted a canopy over the west door"
	var rooms_checked := 0
	for tid in Terrains.DATA:
		for zi in [0, 7, SMALL_ROOMS[0]]:
			g.terrain_by_zone[zi] = tid
			if not zi in SMALL_ROOMS:
				g.zones[zi]["room_scale"] = 1.0 if zi == 0 else 0.72
			var previous: Array = []
			for rebuild in 2:
				_clear(g)
				g._decide_river(zi)
				g._spawn_patches(zi)
				g._spawn_scenery(zi)
				var error := room(g, zi)
				if error != "": return "%s seed %d: %s" % [tid, zi, error]
				var signature := _signature(g, zi)
				if rebuild == 0:
					previous = signature
				elif previous != signature:
					return "%s seed %d rerolled placement on rebuild" % [tid, zi]
				# A threshold is local, not a blanket density reduction. Production
				# targets still fill in ordinary open full-sized rooms.
				if zi == 0 and tid in ["darkwood", "bog", "spore", "void", "magma"]:
					# Only the obstacle loop's own placements: accents and solid
					# decor also carry "prop" and would hide a lost obstacle.
					var props := 0
					for node in g.zone_scenery[zi]:
						if node.has_meta("scatter_obstacle"): props += 1
					var rng := RandomNumberGenerator.new()
					rng.seed = zi * 77 + String(tid).hash() % 1000
					var density := rng.randf_range(Balance.SCENERY_DENSITY_JITTER.x, Balance.SCENERY_DENSITY_JITTER.y)
					var target := ceili(float(Terrains.DATA[tid].get("count", 10)) * Balance.SCENERY_OBSTACLE_MULT
						* g.play_rect(zi).get_area() / float(g.ROOM_W * g.ROOM_H) * density)
					if props < target:
						return "%s lost scatter density (%d of %d obstacles)" % [tid, props, target]
					# Displaced pools re-roll rather than vanish in an open room.
					var pools := 0
					for spec in Terrains.DATA[tid].get("patches", []):
						pools += int(ceil(float(spec["count"]) * 2.0))
					if g.hazards.size() != pools:
						return "%s lost hazard pools (%d of %d)" % [tid, g.hazards.size(), pools]
			rooms_checked += 1
	print("threshold seeded production rooms checked: %d (each rebuilt twice, a short small room included)" % rooms_checked)
	return ""


## A short small room: its N (or S) wall is close to the centre. The apron stops
## short of the centre, so centre-pinned pieces and an offer's fallback spot
## are clear, and an offer at any door mouth still moves out of the apron.
static func _small_rooms(g: Game) -> String:
	var r := Balance.DOOR_THRESHOLD_OFFER_RADIUS
	for zi in SMALL_ROOMS:
		var pr := g.play_rect(zi)
		var center := g.room_center(zi)
		var near := minf(center.y - pr.position.y, pr.end.y - center.y)
		if near >= Balance.DOOR_THRESHOLD_APRON + g.TILE + Balance.DOOR_THRESHOLD_CENTRE_CLEAR:
			return "fixture room %d is not a short small room (%.0f px wall to centre)" % [zi, near]
		var thresholds := Threshold.zones(g, zi)
		if Threshold.intersects(thresholds, Rect2(center - Vector2.ONE * r, Vector2.ONE * r * 2.0)):
			return "small room %d: the room centre sits inside a door threshold" % zi
		for dir in ["N", "S", "W", "E"]:
			var at := Vector2(center.x, pr.position.y + 40.0)
			match dir:
				"S": at = Vector2(center.x, pr.end.y - 40.0)
				"W": at = Vector2(pr.position.x + 40.0, center.y)
				"E": at = Vector2(pr.end.x - 40.0, center.y)
			var moved := Threshold.clear_point(g, zi, at, r)
			if Threshold.intersects(thresholds, Rect2(moved - Vector2.ONE * r, Vector2.ONE * r * 2.0)):
				return "small room %d: an offer at the %s door stayed in a threshold (%s)" % [zi, dir, moved]
	return ""


## The fishing nook on a near-wall river: the old bank spot is in the west
## apron (negative control); the nook moves along the same bank until its
## painted body is clear, and the shoal stays on the water, off the planks.
static func _fishing(g: Game) -> String:
	for zi in [0, SMALL_ROOMS[0]]:
		var pr := g.play_rect(zi)
		var lane := g.lane_local(zi)
		var wpx := 144.0
		var river := Rect2(pr.position.x + pr.size.x * 0.18 - wpx / 2.0, pr.position.y, wpx, pr.size.y)
		var bridge := Rect2(river.position.x - 14.0, pr.position.y + lane.y - 84.0, wpx + 28.0, 168.0)
		var thresholds := Threshold.zones(g, zi)
		var old_spot := Vector2(bridge.position.x + 26, bridge.end.y - 26)
		if not Threshold.intersects(thresholds, FishingSpot.footprint(old_spot)):
			return "fishing fixture room %d did not put the old nook in the west apron" % zi
		g.zone_scenery[zi] = []
		var spot: Node2D = FishingSpot.install(g, zi, bridge)
		var error := ""
		var water: Vector2 = spot.position + spot.water_pos
		if Threshold.body_blocked(thresholds, spot):
			error = "fishing nook in room %d still stands in a door threshold at %s" % [zi, spot.position]
		elif not is_equal_approx(spot.position.x, old_spot.x):
			error = "fishing nook in room %d left its bank (%s)" % [zi, spot.position]
		elif not river.has_point(water) or bridge.has_point(water):
			error = "fishing nook in room %d aims its shoal off the water (%s)" % [zi, water]
		_clear(g)
		if error != "": return error
	return ""


## Audit explicit content on real seeded graphs. Overrides remain authored:
## report every overlap (including arches designed to span a road), and fail
## the known accidental mill placement. No silent procedural movement of lore.
static func _authored(g: Game) -> String:
	var chapters: Array = Story.CHAPTER_LIST.keys() + Story.STANDALONE_WORLDS.keys() + ["capital"]
	var checked := 0
	var overlaps := 0
	for chapter in chapters:
		g.chapter_id = chapter
		g.zones = Story.chapter(chapter).zones.duplicate(true)
		g.zone_count = g.zones.size()
		g.terrain_by_zone = []
		for zone in g.zones: g.terrain_by_zone.append(zone.get("terrain", "village"))
		for run_seed in [42017, 53029]:
			g.wander_seed = run_seed
			g._prepare_rooms()
			g._install_shortcut()
			for zi in g.zone_count:
				var zone: Dictionary = g.zones[zi]
				var thresholds := Threshold.zones(g, zi)
				# Backdrops deliberately span the road with a cut arch. Log their
				# visual overlap as authored; capgap separately walks the collider gap.
				for spec in zone.get("backdrops", []):
					var body := g._add_backdrop(spec.name, g.room_pos(zi, spec.get("x", g.ROOM_CENTER.x), spec.get("y", g.ROOM_CENTER.y)),
						float(spec.get("w", Balance.CAPITAL_BACKDROP_WIDTH_FALLBACK)) * float(zone.get("room_scale", 1.0)))
					checked += 1
					if Threshold.body_blocked(thresholds, body):
						print("THRESHOLD AUTHORED ARCH: %s / %s / %s seed=%d" % [chapter, zone.name, spec.name, run_seed])
						overlaps += 1
					body.free()
				var specs: Array = zone.get("landmarks", []) + zone.get("furnishings", [])
				for spec in specs:
					var body := g._add_structure(spec.name, g.room_pos(zi, spec.get("x", g.ROOM_CENTER.x), spec.get("y", g.ROOM_CENTER.y)))
					checked += 1
					if Threshold.body_blocked(thresholds, body):
						print("THRESHOLD AUTHORED OVERRIDE: %s / %s / %s seed=%d" % [chapter, zone.name, spec.name, run_seed])
						overlaps += 1
					body.free()
				for spec in zone.get("npcs", []):
					if not Terrains.is_prop_sprite(spec.sprite) or spec.get("hidden", false): continue
					var body := g._make_npc(spec.sprite, g.room_pos(zi, spec.x, spec.y), "", Callable())
					checked += 1
					var blocked := Threshold.body_blocked(thresholds, body)
					body.free()
					g.interactables = []
					if blocked:
						print("THRESHOLD AUTHORED OVERRIDE: %s / %s / %s seed=%d" % [chapter, zone.name, spec.sprite, run_seed])
						overlaps += 1
						if spec.sprite == "mill": return "authored Greyrun mill still blocks an entrance"
				var error := _dry_props(g, zi)
				if error != "": return "%s seed=%d: %s" % [chapter, run_seed, error]
	print("THRESHOLD AUTHORED AUDIT: %d pieces checked; %d explicit overlaps (override rights retained); authored prop bases dry" % [checked, overlaps])
	return ""


## Seeded pools roll before authored props are built. Every prop body's base
## stays dry: moving the Greyrun mill off the north lane first put its door in
## that room's poison field, because nothing reserved it from the pools.
static func _dry_props(g: Game, zi: int) -> String:
	var props: Array = []
	for spec in g.zones[zi].get("npcs", []):
		if Terrains.is_prop_sprite(String(spec.get("sprite", ""))): props.append(spec)
	if props.is_empty() or Terrains.get_terrain(g.terrain_by_zone[zi]).get("patches", []).is_empty():
		return ""
	g._decide_river(zi)
	g._spawn_patches(zi)
	var error := ""
	for spec in props:
		var at := g.room_pos(zi, float(spec.get("x", g.ROOM_CENTER.x)), float(spec.get("y", g.ROOM_CENTER.y)))
		for h in g.hazards:
			if int(h.zone) == zi and (h.pos as Vector2).distance_to(at) - float(h.radius) < Balance.AUTHORED_PROP_POOL_CLEAR:
				error = "%s: a seeded %s pool at %s reaches the authored %s at %s" % [
					g.zones[zi].name, h.type, h.pos, spec.sprite, at]
	_clear(g)
	return error


static func _signature(g: Game, zi: int) -> Array:
	var out: Array = []
	for node in g.zone_scenery[zi]:
		if node is Sprite2D or node is AnimatedSprite2D or node is StaticBody2D:
			out.append([node.position, node.get_meta("prop", ""), node.get_meta("structure", ""), node.get_meta("building", "")])
	for h in g.hazards: out.append([h.type, h.pos, h.radius])
	return out


## Actual painted bounds and collision shapes, independent of scatter estimates.
static func room(g: Game, zi: int) -> String:
	var thresholds := Threshold.zones(g, zi)
	for node in g.zone_scenery.get(zi, []):
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node.has_meta("floor_wear"): continue  # flat floor shading, not a prop
		if not (node is Sprite2D or node is AnimatedSprite2D or node is StaticBody2D
				or node.is_in_group("fishing_spots")): continue
		if g.rivers.has(zi) and node is Sprite2D and not node.centered: continue  # water + traversable bridge
		# Exact authored positions retain override rights; the capture audit logs
		# them separately. Procedural structures carry terrain_landmark metadata.
		if node.has_meta("structure") and not node.has_meta("terrain_landmark"): continue
		if Threshold.body_blocked(thresholds, node):
			return "scenery overlaps threshold: %s at %s" % [node.get_meta("prop", node.get_meta("structure", node.get_meta("building", node.get_class()))), node.position]
	for h in g.hazards:
		if int(h.zone) != zi: continue
		for zone: Rect2 in thresholds:
			var nearest: Vector2 = (h.pos as Vector2).clamp(zone.position, zone.end)
			if nearest.distance_to(h.pos) <= float(h.radius): return "damaging pool footprint intersects threshold"
		if Threshold.body_blocked(thresholds, h.sprite): return "painted hazard footprint intersects threshold"
	return ""
