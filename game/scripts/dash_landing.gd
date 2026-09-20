extends RefCounted
## Resolve only a limited teleport's landing. An open endpoint keeps the exact
## requested distance, including Blink across scenery. The caller room-clamps
## the request first; an occupied landing retreats on that same segment only.
## Only closed shortcut barriers forbid crossing the segment. Ordinary scenery
## retains endpoint-only semantics; this is not recovery from a bad start.

# Query resolution, not an ability-distance/balance knob. Each rejected sample
# moves at most one world pixel toward the start; no sideways or forward search.
const SAMPLE_PX := 1.0
const SHORTCUT_GROUP := "shortcut_barrier"


static func resolve(body: CharacterBody2D, wanted: Vector2) -> Vector2:
	var start := body.global_position
	if not body.is_inside_tree() or not start.is_finite() or not wanted.is_finite():
		return start
	var space := body.get_world_2d().direct_space_state
	if space == null:
		return start
	var queries := _queries(body)
	wanted = _limit_shortcuts(body, queries, start, wanted)
	# Offset each actual global shape transform, retaining its basis and owner
	# offset. Empty active shapes/mask zero follow the body's disabled collision.
	if _clear(space, queries, wanted - start):
		return wanted
	var distance := start.distance_to(wanted)
	if distance <= 0.0:
		return start
	var steps := int(ceil(distance / SAMPLE_PX))
	for index in range(1, steps + 1):
		var candidate := wanted.lerp(start, minf(float(index) * SAMPLE_PX / distance, 1.0))
		if _clear(space, queries, candidate - start):
			return candidate
	# No tested open position exists on this sampled segment. Keep the old origin
	# rather than adding a new displacement into a body or outside the room.
	return start


static func _clear(space: PhysicsDirectSpaceState2D,
		queries: Array[PhysicsShapeQueryParameters2D], offset: Vector2) -> bool:
	for query in queries:
		var original := query.transform
		var shifted := original
		shifted.origin += offset
		query.transform = shifted
		var occupied := not space.intersect_shape(query, 1).is_empty()
		query.transform = original
		if occupied:
			return false
	return true


static func _queries(body: CharacterBody2D) -> Array[PhysicsShapeQueryParameters2D]:
	var excluded: Array[RID] = [body.get_rid()]
	for other in body.get_collision_exceptions():
		if is_instance_valid(other):
			excluded.append(other.get_rid())
	var queries: Array[PhysicsShapeQueryParameters2D] = []
	for owner in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner):
			continue
		var local_shape := body.shape_owner_get_transform(owner)
		for index in body.shape_owner_get_shape_count(owner):
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = body.shape_owner_get_shape(owner, index)
			query.transform = body.global_transform * local_shape
			query.collision_mask = body.collision_mask
			query.exclude = excluded
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.margin = body.safe_margin
			queries.append(query)
	return queries


## Shortcut-only segment limit. Explicit start also supports a trusted arrival
## anchor without temporarily moving the actor. Ordinary obstacles are ignored.
static func limit_shortcuts(body: CharacterBody2D, start: Vector2, wanted: Vector2) -> Vector2:
	if not body.is_inside_tree() or not start.is_finite() or not wanted.is_finite():
		return start
	var queries := _queries(body)
	for query in queries:
		var transform := query.transform
		transform.origin += start - body.global_position
		query.transform = transform
	return _limit_shortcuts(body, queries, start, wanted)


static func _limit_shortcuts(body: CharacterBody2D,
		queries: Array[PhysicsShapeQueryParameters2D], start: Vector2, wanted: Vector2) -> Vector2:
	if queries.is_empty() or start == wanted:
		return wanted
	var barriers: Array[Dictionary] = []
	for node in body.get_tree().get_nodes_in_group(SHORTCUT_GROUP):
		if not node is StaticBody2D or node.is_queued_for_deletion():
			continue
		var gate: StaticBody2D = node
		if gate.get_world_2d() != body.get_world_2d() \
				or (gate.collision_layer & body.collision_mask) == 0 \
				or queries[0].exclude.has(gate.get_rid()):
			continue # An opened gate has layer zero immediately, before its fade.
		for owner in gate.get_shape_owners():
			if gate.is_shape_owner_disabled(owner):
				continue
			var transform: Transform2D = gate.global_transform * gate.shape_owner_get_transform(owner)
			for index in gate.shape_owner_get_shape_count(owner):
				barriers.append({"shape": gate.shape_owner_get_shape(owner, index), "transform": transform})
	var motion := wanted - start
	if barriers.is_empty() or not _shortcut_hits(queries, motion, barriers):
		return wanted
	# Swept collision is monotonic along this fixed segment. Keep the last
	# safe prefix, bounded to one pixel; endpoint resolution still runs next.
	var distance := motion.length()
	var low := 0.0
	var high := 1.0
	for _step in 32:
		if (high - low) * distance <= SAMPLE_PX:
			break
		var middle := (low + high) * 0.5
		if _shortcut_hits(queries, motion * middle, barriers):
			high = middle
		else:
			low = middle
	return start + motion * maxf(0.0, low - body.safe_margin / distance)


static func _shortcut_hits(queries: Array[PhysicsShapeQueryParameters2D],
		motion: Vector2, barriers: Array[Dictionary]) -> bool:
	for query in queries:
		for barrier in barriers:
			var shape: Shape2D = barrier["shape"]
			var transform: Transform2D = barrier["transform"]
			if query.shape.collide_with_motion(query.transform, motion, shape, transform, Vector2.ZERO):
				return true
	return false
