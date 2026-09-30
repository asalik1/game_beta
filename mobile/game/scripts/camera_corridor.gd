extends RefCounted
## Presentation-only doorway accommodation. No world build/visit/lock mutations.
## Stateless: the caller owns the eased limits it hands back each frame, and
## every room/hero/world replacement passes none, so no previous edge survives.
const Surface := preload("res://scripts/wall_surface.gd")
const Preview := preload("res://scripts/camera_corridor_preview.gd")

## Writes the camera limits and returns them unrounded. An empty `previous`
## snaps (explicit arrivals). Otherwise each limit moves toward the doorway
## target at CAMERA_LIMIT_EASE_SPEED, so the engine's hard clamp (which keeps
## the view inside the drawn area) never jumps the view.
static func apply(g: Game, p: Player, previous := Rect2(), delta := 0.0) -> Rect2:
	if not is_instance_valid(g.camera) or g.cur_room < 0 or g.cur_room >= g.rooms.size():
		return previous
	var ordinary: Rect2 = g.play_rect(g.cur_room)
	var preview := {}
	var limits: Rect2 = Surface.view_bounds(g, g.cur_room, effective_bounds(g, p, ordinary, preview))
	if previous.has_area():
		limits = _ease(g, previous, limits, delta)
		# Approach scenery outlasts eased limits that still reach past the
		# room's own drawn cell and headroom.
		var old: Node2D = g.world.get_node_or_null("CorridorPreview") if is_instance_valid(g.world) else null
		if preview.is_empty() and old != null \
				and not Surface.mass_rect(g, g.cur_room).grow(1.0).encloses(limits):
			preview = {"room": old.get("room"), "entry": old.get("entry")}
	Preview.update(g, preview)
	g.camera.limit_left = int(limits.position.x)
	# Round up: a fractional inset must not expose a row above the wall mass.
	g.camera.limit_top = ceili(limits.position.y)
	g.camera.limit_right = int(limits.end.x)
	g.camera.limit_bottom = int(limits.end.y)
	return limits


static func _ease(g: Game, from: Rect2, to: Rect2, delta: float) -> Rect2:
	var step: float = Balance.CAMERA_LIMIT_EASE_SPEED * maxf(0.0, delta)
	# Without a live view, narrowing uses only the capped rate.
	var seen := from
	if g.camera.is_inside_tree() and g.camera.is_current():
		var half: Vector2 = g.get_viewport_rect().size * 0.5 / g.camera.zoom
		seen = Rect2(g.camera.get_screen_center_position() - half, half * 2.0)
	var left := _edge(from.position.x, to.position.x, step, seen.position.x, false)
	var top := _edge(from.position.y, to.position.y, step, seen.position.y, false)
	var right := _edge(from.end.x, to.end.x, step, seen.end.x, true)
	var bottom := _edge(from.end.y, to.end.y, step, seen.end.y, true)
	return Rect2(left, top, right - left, bottom - top)


## One limit toward its target. Widening is capped. Narrowing may first drop
## to just outside the visible edge (nothing on screen moves), then continues
## at the capped rate, pushing the view no faster than a widening would.
static func _edge(current: float, target: float, step: float, visible: float, high: bool) -> float:
	if high:
		if target >= current:
			return minf(target, current + step)
		return maxf(target, minf(current - step, visible + step))
	if target <= current:
		return maxf(target, current - step)
	return minf(target, maxf(current + step, visible - step))


static func effective_bounds(g: Game, p: Player, ordinary: Rect2, preview: Dictionary = {}) -> Rect2:
	preview.clear()
	if not is_instance_valid(p) or p.dead or p.downed or p.ghost \
			or not p.global_position.is_finite() or g.room_at_pos(p.global_position) != g.cur_room:
		return ordinary
	var position: Vector2 = p.global_position
	# In a doorway gap only that doorway applies; approaches need the room.
	var inside: bool = position.x >= ordinary.position.x and position.x <= ordinary.end.x \
		and position.y >= ordinary.position.y and position.y <= ordinary.end.y
	var canvas: Vector2 = g.get_viewport_rect().size
	var allowance: Vector2 = Balance.CAMERA_FRAME_MARGIN + Balance.CAMERA_FRAME_BODY
	var half_lane: float = float(g.DOOR_TILES * g.TILE) * 0.5
	var exits: Dictionary = g.rooms[g.cur_room]["exits"]
	var best := {}
	var best_weight := 0.0
	var runner_up := 0.0
	for value in exits.keys():
		var direction := String(value)
		if not direction in ["N", "S", "E", "W"]:
			continue
		var opposite: String = {"N": "S", "S": "N", "E": "W", "W": "E"}[direction]
		var neighbor: int = g.neighbor(g.cur_room, direction)
		if neighbor < 0 or neighbor >= g.rooms.size():
			continue
		var other_exits: Dictionary = g.rooms[neighbor]["exits"]
		# neighbor() means coordinate adjacency, not an authored connection.
		if not other_exits.has(opposite) or g.neighbor(neighbor, opposite) != g.cur_room \
				or not g._edge_unlocked(g.cur_room, neighbor):
			continue
		var other: Rect2 = g.play_rect(neighbor)
		var vertical: bool = direction in ["N", "S"]
		var lane: Vector2 = g.door_pos(g.cur_room, direction)
		var transverse: float = absf(position.x - lane.x) if vertical else absf(position.y - lane.y)
		var low: float
		var high: float
		if vertical:
			low = ordinary.end.y if direction == "S" else other.end.y
			high = other.position.y if direction == "S" else ordinary.position.y
		else:
			low = ordinary.end.x if direction == "E" else other.end.x
			high = other.position.x if direction == "E" else ordinary.position.x
		if high < low:
			continue
		var axial: float = position.y if vertical else position.x
		var zoom: float = g.camera.zoom.y if vertical else g.camera.zoom.x
		var side_zoom: float = g.camera.zoom.x if vertical else g.camera.zoom.y
		if not is_finite(zoom) or zoom <= 0.0 or not is_finite(side_zoom) or side_zoom <= 0.0:
			continue
		# Half the view plus the walking lead: the doorway starts to open just
		# before the room edge could hold a walking view, and opens its side
		# only that far, so the limit keeps pace with the view.
		var reach: float = maxf(allowance.y if vertical else allowance.x,
			(canvas.y if vertical else canvas.x) * 0.5) / zoom + Balance.CAMERA_LOOKAHEAD_PX
		var distance_inside: float = maxf(low - axial, axial - high)
		var weight := 1.0
		if distance_inside > 0.0:
			if not inside:
				continue
			weight = clampf(1.0 - distance_inside / reach, 0.0, 1.0)
			# Walking sideways off a door lane releases its envelope gradually
			# too. In the gap, retain the exact walkable lane at full weight.
			var side_apron: float = (allowance.x if vertical else allowance.y) / side_zoom
			weight *= 1.0 - smoothstep(half_lane, half_lane + side_apron, transverse)
		elif transverse > half_lane:
			continue
		if weight <= 0.0:
			continue
		if weight <= best_weight:
			runner_up = maxf(runner_up, weight)
			continue
		runner_up = best_weight
		best_weight = weight
		best = {"direction": direction, "other": other, "neighbor": neighbor, "entry": opposite,
			"reach": reach if distance_inside > 0.0 else INF}
	# Doorways whose approaches overlap (small rooms, wide or tall canvases)
	# hand over through the room's own rect: the leader keeps only its margin
	# over the runner-up instead of flipping between two envelopes.
	var weight := best_weight - runner_up
	if weight <= 0.0:
		return ordinary
	# Same pair envelope from either side of the CELL transition. Blend only
	# on approaches inside rooms; the entire corridor uses weight 1.
	var envelope: Rect2 = ordinary.merge(best["other"])
	var start: Vector2 = ordinary.position.lerp(envelope.position, weight)
	var end: Vector2 = ordinary.end.lerp(envelope.end, weight)
	# An approach opens the doorway side only as far as a walking view can
	# use, so a sideways step moves the limit about as far as the view needs.
	var reach: float = float(best["reach"]) * weight
	match String(best["direction"]):
		"E": end.x = minf(end.x, ordinary.end.x + reach)
		"W": start.x = maxf(start.x, ordinary.position.x - reach)
		"S": end.y = minf(end.y, ordinary.end.y + reach)
		"N": start.y = maxf(start.y, ordinary.position.y - reach)
	var bounds := Rect2(start, end - start)
	# The room draws its own cell and headroom; only limits reaching past
	# them can show the unvisited neighbor's approach scenery.
	if not g.built.get(best["neighbor"], false) \
			and not Surface.mass_rect(g, g.cur_room).grow(1.0).encloses(Surface.view_bounds(g, g.cur_room, bounds)):
		preview["room"] = best["neighbor"]
		preview["entry"] = best["entry"]
	return bounds
