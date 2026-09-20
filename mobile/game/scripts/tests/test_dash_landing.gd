extends RefCounted
## Actual physics-space contracts in a disposable World2D. These bodies are
## explicit geometry fixtures, not authored scenery or ordinary combat input.
const Landing := preload("res://scripts/dash_landing.gd")

class Probe extends Node2D:
	signal completed
	var error := ""
	var ticks := 0
	var cases: Array[Dictionary] = []

	func _ready() -> void:
		_case("open endpoint beyond intervening terrain", "clear", 1, Vector2(50, 0), 15.0)
		_case("terrain endpoint", "blocked", 1)
		_case("enemy-layer endpoint", "blocked", 4)
		_case("unscanned layer", "clear", 8)
		_case("areas do not block feet", "clear", 1, Vector2(100, 0), 29.0, "area")
		_case("actual offset shape", "blocked", 1, Vector2(122, 0), 10.0, "offset")
		_case("actual rotated offset", "blocked", 1, Vector2(100, 22), 10.0, "rotated")
		_case("all shape owners", "blocked", 1, Vector2(122, 0), 10.0, "compound")
		_case("disabled shape owner", "clear", 1, Vector2(122, 0), 10.0, "disabled")
		_case("own RID excluded", "clear", 0, Vector2(100, 0), 29.0, "self")
		_case("explicit collision exception", "clear", 1, Vector2(100, 0), 29.0, "exception")
		_case("zero collision mask", "clear", 1, Vector2(100, 0), 29.0, "mask_zero")
		_case("no active body shapes", "clear", 1, Vector2(100, 0), 29.0, "no_shape")
		_case("no safe segment keeps preexisting origin", "stay", 1, Vector2(50, 0), 250.0)
		_case("nonfinite request keeps origin", "stay", 0, Vector2(100, 0), 29.0, "nonfinite")
		_case("zero distance remains exact", "clear", 0, Vector2(100, 0), 29.0, "zero")
		for kind in ["closed", "actor_offset", "actor_rotated", "actor_compound", "actor_disabled",
				"gate_offset", "gate_rotated", "gate_compound", "gate_disabled", "exception",
				"other_world", "open_fade", "mask_zero", "no_shape", "ordinary", "arrival"]:
			_guard_case(kind)

	func _circle(parent: Node, radius: float, offset := Vector2.ZERO, disabled := false) -> void:
		var node := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		node.shape = shape
		node.position = offset
		node.disabled = disabled
		parent.add_child(node)

	func _case(label: String, expected: String, layer: int, at := Vector2(100, 0),
			radius := 29.0, kind := "normal") -> void:
		var start := Vector2(0, cases.size() * 600.0)
		var body := CharacterBody2D.new()
		body.position = start
		body.collision_layer = 2
		body.collision_mask = 1 | 4
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if kind in ["offset", "rotated"]:
			offsets = [Vector2(10, 0)]
		elif kind == "compound":
			offsets = [Vector2(-10, 0), Vector2(10, 0)]
		elif kind == "disabled":
			offsets = [Vector2(-10, 0)]
			_circle(body, 13.0, Vector2(10, 0), true)
		if kind == "no_shape":
			offsets.clear()
		for offset in offsets:
			_circle(body, 13.0, offset)
		if kind == "rotated":
			body.rotation = PI / 2.0
			offsets = [Vector2(0, 10)]
		if kind == "self":
			body.collision_mask = 2
		elif kind == "mask_zero":
			body.collision_mask = 0
		add_child(body)
		var obstacle: CollisionObject2D = Area2D.new() if kind == "area" else StaticBody2D.new()
		obstacle.collision_layer = layer
		obstacle.collision_mask = 0
		obstacle.position = start + at
		_circle(obstacle, radius)
		add_child(obstacle)
		if kind == "exception":
			body.add_collision_exception_with(obstacle)
		var wanted := start + Vector2(100, 0)
		if kind == "self":
			wanted = start + Vector2(10, 0) # query overlaps own starting RID unless excluded
		elif kind == "zero":
			wanted = start
		elif kind == "nonfinite":
			wanted = Vector2(NAN, 0)
		cases.append({"label": label, "expected": expected, "body": body, "start": start,
			"wanted": wanted, "at": start + at, "radius": radius, "offsets": offsets})

	func _physics_process(_delta: float) -> void:
		ticks += 1
		if ticks < 2:
			return # all fixture shapes have entered the isolated space
		set_physics_process(false)
		if not Engine.is_in_physics_frame():
			error = "fixture did not query inside a physics callback"
		else:
			for item in cases:
				error = _check_case(item)
				if error != "":
					break
		completed.emit()

	func _check_case(item: Dictionary) -> String:
		if item.has("guard_kind"):
			return _check_guard(item)
		var body: CharacterBody2D = item.body
		var before := body.global_transform
		var result: Vector2 = Landing.resolve(body, item.wanted)
		var ok := result.is_finite() and body.global_transform == before
		if item.expected == "clear":
			ok = ok and result == Vector2(item.wanted)
		elif item.expected == "stay":
			ok = ok and result == Vector2(item.start)
		else:
			var start: Vector2 = item.start
			var wanted: Vector2 = item.wanted
			# Independent circle geometry: all active painted fixture offsets are
			# actually physics-circle centers. No second call to Landing._clear.
			ok = ok and result.x > start.x and result.x < wanted.x and is_equal_approx(result.y, start.y)
			for offset in item.offsets:
				ok = ok and (result + Vector2(offset)).distance_to(item.at) >= 13.0 + float(item.radius)
		# An axial circle has an independent nearest-clear boundary. Reject a
		# safe but excessive retreat; allow only the declared sampling resolution
		# and the body's existing contact margin beyond geometric contact.
		if item.label == "terrain endpoint":
			var boundary: float = Vector2(item.at).x - 13.0 - float(item.radius)
			var tolerance: float = Landing.SAMPLE_PX + body.safe_margin
			ok = ok and result.x >= boundary - tolerance - 0.001
		if not ok:
			return "%s: %s -> %s (wanted %s)" % [item.label, item.start, result, item.wanted]
		print("ok: dash landing geometry / " + String(item.label))
		return ""


	## Independent circle-versus-rectangle axial boundaries, not a second call
	## to the production sweep or its private helpers. All old cases remain.
	func _guard_case(kind: String) -> void:
		var start := Vector2(0, cases.size() * 600.0)
		var body := CharacterBody2D.new()
		body.position = start
		body.collision_layer = 2
		body.collision_mask = 0 if kind == "mask_zero" else 5
		var offset := Vector2(10, 0) if kind in ["actor_offset", "actor_rotated"] else Vector2.ZERO
		if kind == "actor_rotated": body.rotation = PI * 0.5
		if kind != "no_shape": _circle(body, 13.0, offset)
		if kind == "actor_compound": _circle(body, 13.0, Vector2(10, 0))
		if kind == "actor_disabled": _circle(body, 13.0, Vector2(25, 0), true)
		add_child(body)
		var gate := StaticBody2D.new()
		gate.position = start + Vector2(60, 0)
		gate.collision_layer = 0 if kind == "open_fade" else 1
		gate.collision_mask = 0
		if kind != "ordinary": gate.add_to_group("shortcut_barrier")
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 80)
		shape.shape = rect
		shape.disabled = kind == "gate_disabled"
		if kind == "gate_offset": shape.position.x = 10.0
		if kind == "gate_rotated": shape.rotation = PI * 0.5
		gate.add_child(shape)
		if kind == "gate_compound":
			var near_shape := CollisionShape2D.new()
			near_shape.shape = rect
			near_shape.position.x = -15.0
			gate.add_child(near_shape)
		if kind == "other_world":
			var separate := SubViewport.new()
			separate.world_2d = World2D.new()
			separate.size = Vector2i(64, 64)
			separate.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(separate)
			separate.add_child(gate)
		else:
			add_child(gate)
		if kind == "exception": body.add_collision_exception_with(gate)
		var boundary := 42.0 # x60 - halfwidth5 - actor radius13
		if kind in ["actor_offset", "actor_compound"]: boundary = 32.0
		if kind == "gate_offset": boundary = 52.0
		if kind == "gate_rotated": boundary = 7.0
		if kind == "gate_compound": boundary = 27.0
		cases.append({"guard_kind": kind, "body": body, "gate": gate,
			"start": start, "wanted": start + Vector2(100, 0), "boundary": boundary})

	func _check_guard(item: Dictionary) -> String:
		var body: CharacterBody2D = item.body
		var gate: StaticBody2D = item.gate
		var before := body.global_transform
		var gate_before := gate.global_transform
		var start: Vector2 = item.start
		var wanted: Vector2 = item.wanted
		var kind := String(item.guard_kind)
		var result: Vector2
		if kind == "arrival":
			# Trusted-origin API must translate shape transforms without changing
			# the actor already standing elsewhere in this controlled fixture.
			body.global_position = start + Vector2(200, 0)
			before = body.global_transform
			result = Landing.limit_shortcuts(body, start, wanted)
		else:
			result = Landing.resolve(body, wanted)
		var exact := kind in ["gate_disabled", "exception", "other_world", "open_fade", "mask_zero", "no_shape", "ordinary"]
		var ok: bool = result.is_finite() and body.global_transform == before and gate.global_transform == gate_before
		if exact:
			ok = ok and result == wanted
		else:
			var progress: float = result.x - start.x
			var boundary: float = item.boundary
			ok = ok and is_equal_approx(result.y, start.y) and progress <= boundary \
				and progress >= boundary - Landing.SAMPLE_PX - body.safe_margin - 0.001
		if not ok: return "shortcut guard %s: result %s, independent boundary %s" % [kind, result - start, item.boundary]
		print("ok: shortcut swept landing / " + kind)
		return ""



static func run(t: Node) -> String:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	var probe := Probe.new()
	viewport.add_child(probe)
	t.add_child(viewport)
	await probe.completed
	var error := probe.error
	viewport.queue_free()
	await t.get_tree().process_frame
	return error
