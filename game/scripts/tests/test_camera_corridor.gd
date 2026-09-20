extends RefCounted
## Concrete authored geometry, no native camera/physics/render acceptance.
const Corridor := preload("res://scripts/camera_corridor.gd")

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
	g.free() # includes actor and disabled camera, on success and failure.
	if completed != ["NS", "EW"]:
		errors.append("case execution incomplete: %s" % str(completed))
	if not errors.is_empty(): return "corridor geometry: " + "; ".join(errors)
	print("ok: reciprocal camera corridors, locks, asymmetric lanes, touching rooms and read-only bounds")
	return ""

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
	_expect(errors, axis_name + " interior", _at(g, p, Vector2(900, 500)), source)
	_expect(errors, axis_name + " target interior", _at(g, p, Vector2(2800, 500) if horizontal else Vector2(900, 1900)), target)
	var middle: Vector2 = points[1]
	var off_lane := Vector2(1944, 504) if horizontal else Vector2(960, 1104)
	_expect(errors, axis_name + " play-center is not CELL lane", _at(g, p, off_lane), source)
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
	if Rect2(g.camera.limit_left, g.camera.limit_top, g.camera.limit_right - g.camera.limit_left, g.camera.limit_bottom - g.camera.limit_top) != expected:
		errors.append(axis_name + " apply limits differ")
	if camera_before != [g.camera.zoom, g.camera.offset, g.camera.position_smoothing_enabled, g.settings]:
		errors.append(axis_name + " apply changed camera preferences")
	completed.append(axis_name) # Only after every case reached its terminal statement.
