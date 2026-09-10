extends RefCounted
## Resolve only a limited teleport's landing. An open endpoint keeps the exact
## requested distance, including Blink across scenery. The caller room-clamps
## the request first; an occupied landing retreats on that same segment only.
## This is not pathfinding, swept movement, or recovery from an already bad start.

# Query resolution, not an ability-distance/balance knob. Each rejected sample
# moves at most one world pixel toward the start; no sideways or forward search.
const SAMPLE_PX := 1.0


static func resolve(body: CharacterBody2D, wanted: Vector2) -> Vector2:
	var start := body.global_position
	if not body.is_inside_tree() or not start.is_finite() or not wanted.is_finite():
		return start
	var space := body.get_world_2d().direct_space_state
	if space == null:
		return start
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
