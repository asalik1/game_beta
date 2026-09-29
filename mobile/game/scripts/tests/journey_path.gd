extends RefCounted
## QA-only bounded route search. Reads real body/terrain geometry; never moves it.
const CELL := 24.0
const MAX_EXPANDED := 4096
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func plan(r: Node, goal: Vector2, reach: float, deadline: int) -> Dictionary:
	var origin: Vector2 = r.p.global_position
	var bounds: Rect2 = r.game.room_rect(r.game.cur_room).grow(64.0)
	var out := {"status": "search_limit", "points": [], "expanded": 0,
		"queries": 0, "cell": CELL, "margin": 0.0, "reach": reach, "seconds": 0.0}
	var begun := Time.get_ticks_msec()
	if not bounds.has_point(goal):
		out.status = "goal_outside_current_room_search_bounds"
		return out
	if not r._sweep_clear(origin, origin, 0.0):
		out.status = "actual_start_shape_blocked"
		return out
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var cost := {Vector2i.ZERO: 0.0}
	var previous := {}
	var closed := {}
	var found := false
	var last := Vector2i.ZERO
	var terminal: Array[Vector2] = []
	var next_yield := begun + 12
	while not frontier.is_empty() and int(out.expanded) < MAX_EXPANDED:
		if Time.get_ticks_msec() >= deadline:
			out.status = "walk_deadline_during_search"
			break
		# This bounded room search needs no persistent navigation state.
		var best := 0
		var best_score := INF
		for i in frontier.size():
			var cell: Vector2i = frontier[i]
			var pos := origin + Vector2(cell) * CELL
			var score := float(cost[cell]) + pos.distance_to(goal)
			if score < best_score:
				best_score = score
				best = i
		var current: Vector2i = frontier[best]
		frontier.remove_at(best)
		if closed.has(current): continue
		closed[current] = true
		out.expanded = int(out.expanded) + 1
		var here := origin + Vector2(current) * CELL
		# Preserve the caller's normal approach reach. NPC centers can be solid;
		# the real interaction/pickup callback still decides whether arrival works.
		if here.distance_to(goal) <= CELL * 1.5 + reach:
			var destination := goal
			if reach > 1.0:
				destination += (here - goal).normalized() * minf(reach - 1.0, here.distance_to(goal))
			# _walk emits cardinal keys. Validate both legs and retain the elbow;
			# a clear diagonal is not evidence that its L-shaped approach is clear.
			for elbow in [Vector2(destination.x, here.y), Vector2(here.x, destination.y)]:
				out.queries = int(out.queries) + 1
				if not r._sweep_clear(here, elbow, 0.0): continue
				out.queries = int(out.queries) + 1
				if not r._sweep_clear(elbow, destination, 0.0): continue
				last = current
				if here.distance_squared_to(elbow) > 0.01:
					terminal.append(elbow)
				terminal.append(destination)
				found = true
				break
			if found: break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if closed.has(next): continue
			var point := origin + Vector2(next) * CELL
			if not bounds.has_point(point): continue
			var next_cost := float(cost[current]) + CELL
			if cost.has(next) and float(cost[next]) <= next_cost: continue
			out.queries = int(out.queries) + 1
			if not r._sweep_clear(here, point, 0.0): continue
			cost[next] = next_cost
			previous[next] = current
			frontier.append(next)
		if Time.get_ticks_msec() >= next_yield:
			await r.frames(1) # renderer, hazards and ordinary physics remain live
			next_yield = Time.get_ticks_msec() + 12
	if found:
		var path: Array[Vector2] = []
		path.append_array(terminal)
		while last != Vector2i.ZERO:
			path.push_front(origin + Vector2(last) * CELL)
			last = previous[last]
		out.points = path
		out.status = "planned"
	elif frontier.is_empty():
		out.status = "no_route_on_bounded_grid"
	out.seconds = (Time.get_ticks_msec() - begun) / 1000.0
	return out
