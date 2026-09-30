extends RefCounted
## Concrete authored geometry, no native camera/physics/render acceptance.
const Corridor := preload("res://scripts/camera_corridor.gd")
const Surface := preload("res://scripts/wall_surface.gd")

class Fixture extends Game:
	var rectangles: Array[Rect2] = []
	func _ready() -> void: pass
	func play_rect(i: int) -> Rect2: return rectangles[i]

class Actor extends Player:
	func _ready() -> void: pass

static func run(t: Node) -> String:
	var g := Fixture.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.no_saves = true
	t.add_child(g)
	var p := Actor.new()
	g.add_child(p)
	p.game = g
	g.local_player = p
	g.camera = Camera2D.new()
	g.camera.enabled = false
	g.add_child(g.camera)
	var errors: Array[String] = []
	var completed: Array = []
	for horizontal in [false, true]:
		_cases(g, p, horizontal, errors, completed)
	_handoff(g, p, errors)
	_eased(g, p, errors)
	_overlap(g, p, errors)
	g.free() # includes actor and disabled camera, on success and failure.
	if completed != ["NS", "EW"]:
		errors.append("case execution incomplete: %s" % str(completed))
	if not errors.is_empty(): return "corridor geometry: " + "; ".join(errors)
	print("ok: reciprocal camera corridors, locks, asymmetric lanes, touching rooms, read-only bounds, eased limits and overlapping doorways")
	return ""

static func _handoff(g: Fixture, p: Player, errors: Array[String]) -> void:
	_configure(g, true)
	g.settings["combat_framing"] = false
	p.global_position = Vector2(2113, 624)
	g.cur_room = 1
	var framing: RefCounted = g.camera_framing
	framing.hero_id = p.get_instance_id()
	framing.previous = Vector2(2111, 624)
	framing.room = 0
	g._cam_look = Vector2(Balance.CAMERA_LOOKAHEAD_PX, 0)
	g._cam_zoom_mult = Balance.CAMERA_FRAME_MIN_ZOOM
	g.camera.zoom = Vector2.ONE * g._cam_zoom_mult
	# Limits part way through their ease when the walk crosses the boundary.
	var eased := Rect2(240, 96, 2000, 960)
	framing.limits = eased
	framing.enter_room(g, true)
	framing.tick(g, 0.0)
	if g._cam_look != Vector2(Balance.CAMERA_LOOKAHEAD_PX, 0) or g._cam_zoom_mult != Balance.CAMERA_FRAME_MIN_ZOOM:
		errors.append("walk handoff reset lead or combat zoom")
	if framing.limits != eased:
		errors.append("walk handoff snapped its eased doorway limits: %s" % framing.limits)
	if g.camera.limit_smoothed:
		errors.append("camera stopped hard-clamping its view to the drawn area")
	framing.enter_room(g, false)
	if g._cam_look != Vector2.ZERO or g._cam_zoom_mult != 1.0:
		errors.append("explicit arrival retained walking composition")
	var arrival: Rect2 = Surface.view_bounds(g, 1, Corridor.effective_bounds(g, p, g.play_rect(1)))
	if framing.limits != arrival:
		errors.append("explicit arrival eased its limits instead of snapping: %s vs %s" % [framing.limits, arrival])

## Applied limits move at most CAMERA_LIMIT_EASE_SPEED per second however far
## the doorway target jumps: a sideways pass by the lane, entering the gap,
## dying in the doorway. They still land exactly on the target, and an empty
## previous rect (every explicit arrival) snaps.
static func _eased(g: Fixture, p: Player, errors: Array[String]) -> void:
	_configure(g, true)
	g.camera.zoom = Vector2.ONE * 1.12
	g.cur_room = 0
	var dt := 1.0 / 60.0
	var stride: float = 250.0 * dt
	var cap: float = Balance.CAMERA_LIMIT_EASE_SPEED * dt + 0.001
	var path: Array[Vector2] = []
	for i in ceili(600.0 / stride): path.append(Vector2(1580, 250 + i * stride))
	for i in ceili(226.0 / stride): path.append(Vector2(1580, maxf(624.0, 850 - i * stride)))
	for i in ceili(364.0 / stride): path.append(Vector2(minf(1944.0, 1580 + i * stride), 624))
	p.global_position = path[0]
	var limits: Rect2 = Corridor.apply(g, p)
	var target := limits
	var target_step := 0.0
	var worst := 0.0
	for i in path.size() + 360:
		p.global_position = path[mini(i, path.size() - 1)]
		g.cur_room = g.room_at_pos(p.global_position)
		p.dead = i >= path.size() # the envelope collapses in the doorway at once
		var next_target: Rect2 = Surface.view_bounds(g, g.cur_room,
			Corridor.effective_bounds(g, p, g.play_rect(g.cur_room)))
		target_step = maxf(target_step, _step(target, next_target))
		target = next_target
		var next: Rect2 = Corridor.apply(g, p, limits, dt)
		worst = maxf(worst, _step(limits, next))
		limits = next
	p.dead = false
	if worst > cap:
		errors.append("doorway limits moved %.2f px in one 60 Hz frame (cap %.2f)" % [worst, cap])
	if target_step < cap * 3.0:
		errors.append("eased-limit fixture never produced a fast doorway change (%.2f px)" % target_step)
	if limits != target:
		errors.append("eased limits did not settle on the doorway target: %s vs %s" % [limits, target])
	var snapped: Rect2 = Corridor.apply(g, p, Rect2(), dt)
	if snapped != Surface.view_bounds(g, g.cur_room, Corridor.effective_bounds(g, p, g.play_rect(g.cur_room))):
		errors.append("an empty previous rect did not snap to the doorway target")
	# The doorway starts opening once it is inside half a walking view (the
	# canvas-scaled reach), not only within the short body/HUD allowance.
	p.global_position = Vector2(1680.0 - g.get_viewport_rect().size.x * 0.5 / 1.12, 624)
	g.cur_room = 0
	if Corridor.effective_bounds(g, p, g.play_rect(0)).end.x <= 1680.5:
		errors.append("doorway approach did not open from the edge of the view")
	g.camera.zoom = Vector2.ONE

static func _step(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(absf(a.position.x - b.position.x), absf(a.position.y - b.position.y)),
		maxf(absf(a.end.x - b.end.x), absf(a.end.y - b.end.y)))

## Small rooms on a phone (1560x720) or tablet (1280x960) canvas: approaches
## to perpendicular or opposing doorways overlap. Walking across the overlap
## in 1 px steps must not flip the bounds from one envelope to the other.
static func _overlap(g: Fixture, p: Player, errors: Array[String]) -> void:
	var canvas: Vector2 = g.get_viewport_rect().size
	var cell := Vector2(g.ROOM_W, g.ROOM_H)
	var inset: Vector2 = Balance.SMALL_ROOM_INSET
	var small := Rect2(inset, cell - inset * 2.0)
	for view in [Vector2(1560, 720), Vector2(1280, 960)]:
		for layout in [["E", "S"], ["W", "E"], ["N", "S"]]:
			g.rooms = [{"coord": Vector2i.ZERO, "origin": Vector2.ZERO, "exits": {}}]
			g.coord_to_room = {Vector2i.ZERO: 0}
			g.rectangles = [small]
			for direction in layout:
				var coord: Vector2i = g.DIRS[direction]
				var back: String = {"N": "S", "S": "N", "E": "W", "W": "E"}[direction]
				g.rooms[0]["exits"][direction] = true
				g.coord_to_room[coord] = g.rooms.size()
				g.rooms.append({"coord": coord, "origin": Vector2(coord) * cell, "exits": {back: true}})
				g.rectangles.append(Rect2(Vector2(coord) * cell, cell))
			g.zone_count = g.rooms.size()
			g.zones = []
			for i in g.zone_count: g.zones.append({"type": "safe"})
			g.edge_locks.clear()
			g.flags.clear()
			g.built = {0: true}
			g.cur_room = 0
			# The live canvas stands in for `view` through an equivalent zoom.
			g.camera.zoom = canvas / view * 1.12
			var from := _inside(small, g.door_pos(0, layout[0]))
			var to := _inside(small, g.door_pos(0, layout[1]))
			var previous := Rect2()
			var worst := 0.0
			var at := from
			for i in ceili(from.distance_to(to)) + 1:
				p.global_position = from.move_toward(to, float(i))
				var bounds := Corridor.effective_bounds(g, p, small)
				if previous.has_area() and _step(previous, bounds) > worst:
					worst = _step(previous, bounds)
					at = p.global_position
				previous = bounds
			if worst > 20.0:
				errors.append("%s/%s doorways at %s flip bounds %.1f px in a 1 px step at %s" % [
					layout[0], layout[1], view, worst, at])
	g.camera.zoom = Vector2.ONE

## A point on the doorway's lane, 60 px inside the small room's wall.
static func _inside(room: Rect2, door: Vector2) -> Vector2:
	return Vector2(clampf(door.x, room.position.x + 60.0, room.end.x - 60.0),
		clampf(door.y, room.position.y + 60.0, room.end.y - 60.0))

static func _configure(g: Fixture, horizontal: bool) -> void:
	var coord := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var forward := "E" if horizontal else "S"
	var back := "W" if horizontal else "N"
	g.rooms = [{"coord": Vector2i.ZERO, "origin": Vector2.ZERO, "exits": {forward: true}},
		{"coord": coord, "origin": Vector2(coord) * Vector2(2112, 1248), "exits": {back: true}}]
	g.coord_to_room = {Vector2i.ZERO: 0, coord: 1}
	g.zone_count = 2
	g.zones = [{"type": "safe"}, {"type": "safe"}]
	g.rectangles = [Rect2(240, 144, 1440, 720),
		Rect2(2208, 96, 1632, 960) if horizontal else Rect2(96, 1344, 1680, 912)]
	g.edge_locks.clear()
	g.flags.clear()
	g.built = {0: true}
	g.visited = {0: true}
	g.cleared = {0: true}
	g.zone_alive = {0: 0, 1: 3}
	g.camera.zoom = Vector2.ONE

static func _at(g: Fixture, p: Player, point: Vector2) -> Rect2:
	p.global_position = point
	g.cur_room = g.room_at_pos(point)
	return Corridor.effective_bounds(g, p, g.play_rect(g.cur_room))

static func _expect(errors: Array[String], name: String, actual: Rect2, expected: Rect2) -> void:
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		errors.append("%s got%s expected%s" % [name, actual, expected])

static func _snapshot(g: Fixture) -> Array:
	return [g.rooms.duplicate(true), g.coord_to_room.duplicate(true), g.rectangles.duplicate(),
		g.edge_locks.duplicate(true), g.flags.duplicate(true), g.built.duplicate(true),
		g.visited.duplicate(true), g.cleared.duplicate(true), g.zone_alive.duplicate(true)]

static func _cases(g: Fixture, p: Player, horizontal: bool, errors: Array[String], completed: Array) -> void:
	_configure(g, horizontal)
	var axis_name := "EW" if horizontal else "NS"
	var source: Rect2 = g.rectangles[0]
	var target: Rect2 = g.rectangles[1]
	# Literal expected outer extents: deliberately different from CELL lanes.
	var whole := Rect2(240, 96, 3600, 960) if horizontal else Rect2(96, 144, 1680, 2112)
	var points: Array = [Vector2(1680, 624), Vector2(1944, 624), Vector2(2111, 624), Vector2(2113, 624), Vector2(2208, 624)] if horizontal else [Vector2(1056, 864), Vector2(1056, 1104), Vector2(1056, 1247), Vector2(1056, 1249), Vector2(1056, 1344)]
	for point in points:
		_expect(errors, axis_name + " mouth/gap/CELL continuity", _at(g, p, point), whole)
	# Off every lane by more than its side fade: interior at any canvas size.
	_expect(errors, axis_name + " interior", _at(g, p, Vector2(500, 300)), source)
	_expect(errors, axis_name + " target interior", _at(g, p, Vector2(3500, 300) if horizontal else Vector2(400, 2100)), target)
	var middle: Vector2 = points[1]
	var off_lane := Vector2(1944, 504) if horizontal else Vector2(960, 1104)
	_expect(errors, axis_name + " play-center is not CELL lane", _at(g, p, off_lane), source)
	# A sideways walk within the room used to drop the whole door envelope
	# at the lane edge. The tall native rig caught a 15.91 px camera step.
	var half_lane: float = g.DOOR_TILES * g.TILE * 0.5
	var side_start := Vector2(1600, 624 + half_lane - 1) if horizontal else Vector2(1056 + half_lane - 1, 784)
	var side_step := Vector2(0, 2) if horizontal else Vector2(2, 0)
	var before_side := _at(g, p, side_start)
	var after_side := _at(g, p, side_start + side_step)
	if before_side.position.distance_to(after_side.position) > 1.0 or before_side.size.distance_to(after_side.size) > 1.0:
		errors.append(axis_name + " sideways approach abruptly discarded corridor bounds")
	# A real perpendicular neighbor must not turn this off-lane pose into
	# a diagonal union of three rooms.
	var perpendicular := "N" if horizontal else "W"
	var reciprocal := "S" if horizontal else "E"
	var third_coord := Vector2i(0, -1) if horizontal else Vector2i(-1, 0)
	g.rooms.append({"coord": third_coord, "origin": Vector2(third_coord) * Vector2(2112, 1248), "exits": {reciprocal: true}})
	g.rectangles.append(Rect2(240, -1104, 1440, 720) if horizontal else Rect2(-1872, 144, 1440, 720))
	g.coord_to_room[third_coord] = 2
	g.zones.append({"type": "safe"})
	g.zone_count = 3
	g.rooms[0]["exits"][perpendicular] = true
	_expect(errors, axis_name + " off-lane third neighbor", _at(g, p, off_lane), source)
	_expect(errors, axis_name + " selected pair excludes third", _at(g, p, middle), whole)
	_configure(g, horizontal)
	var forward := "E" if horizontal else "S"
	var back := "W" if horizontal else "N"
	g.rooms[1]["exits"].erase(back)
	_expect(errors, axis_name + " no reciprocal exit", _at(g, p, middle), source)
	g.rooms[1]["exits"][back] = true
	g.rooms[0]["exits"].erase(forward)
	_expect(errors, axis_name + " no source exit", _at(g, p, middle), source)
	g.rooms[0]["exits"][forward] = true
	for flag_name in ["shortcut_ch1_0_1", "story_door"]:
		g.edge_locks["0_1"] = {"lock": "flag:" + flag_name, "own": 0}
		_expect(errors, axis_name + " locked " + flag_name, _at(g, p, middle), source)
		g.flags[flag_name] = true
		_expect(errors, axis_name + " opened " + flag_name, _at(g, p, middle), whole)
	g.edge_locks.clear()
	# Identical world geometry with reversed numeric identities.
	g.rooms.reverse(); g.rectangles.reverse()
	g.coord_to_room[Vector2i.ZERO] = 1
	g.coord_to_room[Vector2i(1, 0) if horizontal else Vector2i(0, 1)] = 0
	_expect(errors, axis_name + " reversed identities", _at(g, p, middle), whole)
	_configure(g, horizontal)
	var before: Array = _snapshot(g)
	var first: Rect2 = _at(g, p, middle)
	for unused in 3:
		_expect(errors, axis_name + " repeat", _at(g, p, middle), first)
	if _snapshot(g) != before: errors.append(axis_name + " mutated graph or lifecycle")
	# Zoom changes approach accommodation; interior and full gap stay fixed.
	var approach := Vector2(1600, 624) if horizontal else Vector2(1056, 784)
	g.camera.zoom = Vector2.ONE
	var normal: Rect2 = _at(g, p, approach)
	g.camera.zoom = Vector2.ONE * 2.0
	var enlarged: Rect2 = _at(g, p, approach)
	if not whole.encloses(normal) or not normal.encloses(enlarged) or normal == enlarged:
		errors.append(axis_name + " zoom approach ordering")
	_expect(errors, axis_name + " zoom gap", _at(g, p, middle), whole)
	g.camera.zoom = Vector2.ONE
	for state in ["dead", "downed", "ghost"]:
		p.set(state, true)
		_expect(errors, axis_name + " " + state, _at(g, p, middle), source)
		p.set(state, false)
	g.cur_room = 1 # same finite pose belongs to source, not current room.
	_expect(errors, axis_name + " ownership mismatch", Corridor.effective_bounds(g, p, target), target)
	# Zero gap: touching full-size rooms must still ease their shared edge.
	g.rectangles = [Rect2(0, 0, 2112, 1248), Rect2(2112, 0, 2112, 1248) if horizontal else Rect2(0, 1248, 2112, 1248)]
	var touching := Vector2(2112, 624) if horizontal else Vector2(1056, 1248)
	var touching_whole := Rect2(0, 0, 4224, 1248) if horizontal else Rect2(0, 0, 2112, 2496)
	_expect(errors, axis_name + " touching rooms", _at(g, p, touching), touching_whole)
	# One mouth exactly on CELL edge and the other inset: still one passage.
	g.rectangles[1] = target
	_expect(errors, axis_name + " one zero inset", _at(g, p, touching), Rect2(0, 0, 3840, 1248) if horizontal else Rect2(0, 0, 2112, 2256))
	# apply writes only camera limits, leaving zoom/offset/smoothing/preferences.
	var camera_before: Array = [g.camera.zoom, g.camera.offset, g.camera.position_smoothing_enabled, g.settings.duplicate(true)]
	Corridor.apply(g, p)
	var expected: Rect2 = Corridor.effective_bounds(g, p, g.play_rect(g.cur_room))
	expected = preload("res://scripts/wall_surface.gd").view_bounds(g, g.cur_room, expected)
	if Rect2(g.camera.limit_left, g.camera.limit_top, g.camera.limit_right - g.camera.limit_left, g.camera.limit_bottom - g.camera.limit_top) != expected:
		errors.append(axis_name + " apply limits differ")
	if camera_before != [g.camera.zoom, g.camera.offset, g.camera.position_smoothing_enabled, g.settings]:
		errors.append(axis_name + " apply changed camera preferences")
	completed.append(axis_name) # Only after every case reached its terminal statement.
