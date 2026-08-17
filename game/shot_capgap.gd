extends ShotRig
## Capital passability probe (2026-08-17, owner report: "went behind the large
## walls in Crown Plaza, can't walk back through the gap"). For every capital
## room with a NORTH exit, place the hero on the north door lane and walk the
## real route through the REAL input path (Input.parse_input_event →
## _poll_local_intents → move_and_slide): south down the lane, and — where a
## solid hall stands on the road — west along its back and south past its
## side to the room's centre line; then the same route in reverse. A hero who
## cannot complete either route is stuck behind an invisible wall. Ray-casts
## name the first blocker on the lane. One screenshot per room where the
## south route ended, plus the owner's exact plaza scenario (hero in the arch
## behind the spire gate, walking back south). exit 1 = a route failed.
##   shot.bat capgap [--timeout=170]

const LEG_MAX_SEC := 3.0     # per leg; long enough to cross half a room
const STALL_EPS := 4.0       # px of progress below which we call it stuck
const SIDE_STEP := 220.0     # west offset that clears every hall's body (max half-width 175 + hero)


func _ready() -> void:
	await boot("mage", "ch1")
	hide_hud()
	step("enter_capital")
	game.enter_capital()
	await frames(6)
	await skip_dialogue()
	zoom(0.55)
	var blocked := 0
	for zi in game.zone_count:
		var zone: Dictionary = game.zones[zi]
		if not (zone.get("exits", []) as Array).has("N"):
			continue
		var zname := String(zone.get("name", "?"))
		var door: Vector2 = game.door_pos(zi, "N")
		var r: Rect2 = game.play_rect(zi)
		var lane_y := r.position.y + 48.0 + 40.0   # just inside the north wall
		var goal_y := r.position.y + r.size.y * 0.5
		var start := Vector2(door.x, lane_y)
		var side_x := door.x - SIDE_STEP
		var p := game.player
		# ---- south route: lane → (around the hall) → centre line ------------
		await _place(zi, start)
		await _leg(KEY_S, func() -> bool: return p.global_position.y >= goal_y)
		var straight_y: float = p.global_position.y
		if p.global_position.y < goal_y - STALL_EPS:
			await _leg(KEY_A, func() -> bool: return p.global_position.x <= side_x)
			await _leg(KEY_S, func() -> bool: return p.global_position.y >= goal_y)
		var south_end: Vector2 = p.global_position
		var south_ok := south_end.y >= goal_y - STALL_EPS
		# ---- north route: centre line → (around the hall) → lane -----------
		await _place(zi, Vector2(door.x, goal_y))
		await _leg(KEY_W, func() -> bool: return p.global_position.y <= lane_y)
		if p.global_position.y > lane_y + STALL_EPS:
			await _leg(KEY_A, func() -> bool: return p.global_position.x <= side_x)
			await _leg(KEY_W, func() -> bool: return p.global_position.y <= lane_y + 60.0)
			await _leg(KEY_D, func() -> bool: return p.global_position.x >= door.x)
			await _leg(KEY_W, func() -> bool: return p.global_position.y <= lane_y)
		var north_end: Vector2 = p.global_position
		var north_ok := north_end.y <= lane_y + STALL_EPS
		var verdict := "OK" if south_ok and north_ok else "BLOCKED"
		if verdict == "BLOCKED":
			blocked += 1
		_dump_bodies(zi)
		print("LANE %s: %s  straight-south stop y=%.0f  south route end (%.0f,%.0f) goal y=%.0f  north route end (%.0f,%.0f) lane y=%.0f  lane ray: %s" % [
			zname, verdict, straight_y - r.position.y,
			south_end.x - r.position.x, south_end.y - r.position.y, goal_y - r.position.y,
			north_end.x - r.position.x, north_end.y - r.position.y, lane_y - r.position.y,
			_ray(start, Vector2(door.x, goal_y))])
		# screenshot the hero where the straight south walk ended (the arch /
		# the hall's back) — the spot the owner would be standing on.
		await _place(zi, Vector2(door.x, straight_y))
		game.camera.global_position = p.global_position
		await frames(3)
		shot("%02d_%s" % [zi, zname.to_lower().replace(" ", "_").replace("-", "_")],
			"lane=%s" % verdict)
	# ---- the owner's exact report: Crown Plaza, hero BEHIND the spire gate ----
	# (north of its piers, in the arch), walk back SOUTH through the gap.
	step("plaza_behind_gate")
	var plaza := 0
	for zi in game.zone_count:
		if String(game.zones[zi].get("name", "")) == "Crown Plaza":
			plaza = zi
	var pr: Rect2 = game.play_rect(plaza)
	var behind := pr.position + Vector2(1056.0, 330.0)   # in the arch, north of the piers
	var want_y := pr.position.y + 620.0
	var pl := game.player
	await _place(plaza, behind)
	await _leg(KEY_S, func() -> bool: return pl.global_position.y >= want_y)
	var back_ok := pl.global_position.y >= want_y - STALL_EPS
	print("PLAZA BEHIND-GATE WALK: %s  stopped at y=%.0f (wanted >= 620)  ray: %s" % [
		"OK" if back_ok else "BLOCKED", pl.global_position.y - pr.position.y,
		_ray(behind, Vector2(behind.x, want_y))])
	if not back_ok:
		blocked += 1
	await _place(plaza, behind + Vector2(0, 40))
	game.camera.global_position = pl.global_position
	zoom(1.0)
	await frames(3)
	shot("plaza_behind_gate", "back_ok=%s" % back_ok)
	print("CAPGAP SUMMARY: %d blocked route(s)" % blocked)
	finish(1 if blocked > 0 else 0)


## Teleport the hero into room `zi` at `at` and let physics settle.
func _place(zi: int, at: Vector2) -> void:
	if game.cur_room != zi:
		game._enter_room(zi)
		await frames(2)
	game.player.global_position = at
	game.player.velocity = Vector2.ZERO
	game.camera.global_position = at
	await frames(2)


## Hold `key` until `done` reports true, the hero stalls, or LEG_MAX_SEC.
func _leg(key: Key, done: Callable) -> void:
	var p := game.player
	_key(key, true)
	var t := 0.0
	var last := p.global_position
	var still := 0.0
	while t < LEG_MAX_SEC:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if done.call():
			break
		if p.global_position.distance_to(last) < 0.5:
			still += dt
			if still > 0.35:
				break   # stalled against something
		else:
			still = 0.0
		last = p.global_position
	_key(key, false)
	await frames(1)


## Inventory: every StaticBody2D in room `zi`'s cell that is not a perimeter
## wall (walls carry a LightOccluder2D), with its art name and rect shapes in
## CELL-LOCAL coordinates — so a stray blocker can be named from the log.
func _dump_bodies(zi: int) -> void:
	var cell: Rect2 = game.room_rect(zi)
	var lines: Array = []
	for n in game.world.get_children():
		var bodies: Array = []
		if n is StaticBody2D:
			bodies.append(n)
		elif n is Node2D:
			for c in n.get_children():
				if c is StaticBody2D:
					bodies.append(c)
		for b in bodies:
			var body := b as StaticBody2D
			if not cell.has_point(body.global_position):
				continue
			var is_wall := false
			for c in body.get_children():
				if c is LightOccluder2D:
					is_wall = true
			if is_wall:
				continue
			var art := "?"
			for holder in [body, body.get_parent()]:
				if art != "?":
					break
				for c in (holder as Node).get_children():
					if c is Sprite2D and (c as Sprite2D).texture != null:
						art = (c as Sprite2D).texture.resource_path.get_file()
						break
					elif c is AnimatedSprite2D:
						var fr: SpriteFrames = (c as AnimatedSprite2D).sprite_frames
						if fr != null and fr.get_animation_names().size() > 0:
							var ft: Texture2D = fr.get_frame_texture(fr.get_animation_names()[0], 0)
							art = ft.resource_path.get_file() if ft != null else "anim"
						break
			var shapes := ""
			for c in body.get_children():
				if c is CollisionShape2D:
					var cs := c as CollisionShape2D
					var gp: Vector2 = cs.global_position - cell.position
					if cs.shape is RectangleShape2D:
						var sz: Vector2 = (cs.shape as RectangleShape2D).size
						shapes += " rect x[%d..%d] y[%d..%d]" % [gp.x - sz.x / 2, gp.x + sz.x / 2, gp.y - sz.y / 2, gp.y + sz.y / 2]
					elif cs.shape is CircleShape2D:
						shapes += " circ (%d,%d) r%d" % [gp.x, gp.y, (cs.shape as CircleShape2D).radius]
			lines.append("    %s @(%d,%d)%s" % [art, body.global_position.x - cell.position.x,
				body.global_position.y - cell.position.y, shapes])
	print("  BODIES %s (%d):\n%s" % [game.zones[zi].get("name", "?"), lines.size(), "\n".join(lines)])


func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


## Ray from a to b on the world layer; names the first blocker's art + shape.
func _ray(a: Vector2, b: Vector2) -> String:
	var space := game.player.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	q.exclude = [game.player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return "clear"
	var col: Object = hit.get("collider")
	var desc := "?"
	if col is Node:
		var n: Node = col
		# _add_structure: the body OWNS the art; _add_backdrop: the body's
		# PARENT layer owns it. Name whichever sprite we find first.
		for holder in [n, n.get_parent()]:
			if holder == null or desc != "?":
				continue
			for c in holder.get_children():
				if c is Sprite2D and (c as Sprite2D).texture != null:
					var tex: Texture2D = (c as Sprite2D).texture
					desc = tex.resource_path.get_file() if tex.resource_path != "" else "sprite"
					break
				elif c is AnimatedSprite2D:
					var frames: SpriteFrames = (c as AnimatedSprite2D).sprite_frames
					var ftex: Texture2D = frames.get_frame_texture(frames.get_animation_names()[0], 0) \
						if frames != null and frames.get_animation_names().size() > 0 else null
					desc = ftex.resource_path.get_file() if ftex != null and ftex.resource_path != "" \
						else "anim(%s)" % (holder as Node).name
					break
		var shape_idx := int(hit.get("shape", 0))
		var owner_id: int = (n as CollisionObject2D).shape_find_owner(shape_idx)
		var cs: Object = (n as CollisionObject2D).shape_owner_get_owner(owner_id)
		if cs is CollisionShape2D:
			var c2 := cs as CollisionShape2D
			var sz := Vector2.ZERO
			if c2.shape is RectangleShape2D:
				sz = (c2.shape as RectangleShape2D).size
			desc += " shape@(%.0f,%.0f) size %s" % [c2.global_position.x, c2.global_position.y, sz]
	return "%s at (%.0f,%.0f)" % [desc, (hit["position"] as Vector2).x, (hit["position"] as Vector2).y]
