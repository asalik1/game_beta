extends RefCounted
## Shared geometry for room dressing and seeded hazards. Coordinates are
## world-space; use the inset wall mouth, not the outer grid-cell door in a
## compact room. Live combat hazards (boss and mob pools) are deliberately NOT
## filtered: they land where they were telegraphed.


static func zones(g: Game, zi: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Fixture games (and homeless callers) can ask before a room graph exists.
	if zi < 0 or zi >= g.rooms.size():
		return out
	var pr := g.play_rect(zi)
	var center := g.room_center(zi)
	var half := g.DOOR_TILES * g.TILE * 0.5 + Balance.DOOR_THRESHOLD_BODY_PAD
	var reach := Balance.DOOR_THRESHOLD_APRON + g.TILE
	var keep := Balance.DOOR_THRESHOLD_CENTRE_CLEAR
	for dir in g.rooms[zi]["exits"]:
		match String(dir):
			"N":
				var d := clampf(center.y - pr.position.y - keep, 0.0, reach)
				out.append(Rect2(center.x - half, pr.position.y - g.TILE, half * 2.0, d + g.TILE))
			"S":
				var d := clampf(pr.end.y - center.y - keep, 0.0, reach)
				out.append(Rect2(center.x - half, pr.end.y - d, half * 2.0, d + g.TILE))
			"W":
				var d := clampf(center.x - pr.position.x - keep, 0.0, reach)
				out.append(Rect2(pr.position.x - g.TILE, center.y - half, d + g.TILE, half * 2.0))
			"E":
				var d := clampf(pr.end.x - center.x - keep, 0.0, reach)
				out.append(Rect2(pr.end.x - d, center.y - half, d + g.TILE, half * 2.0))
	return out


static func intersects(thresholds: Array, footprint: Rect2) -> bool:
	for zone: Rect2 in thresholds:
		if zone.intersects(footprint, true): return true
	return false


static func pool_blocked(g: Game, zi: int, pos: Vector2, radius: float) -> bool:
	# Includes the painted strip's transparent margins/offset, so neither a
	# damaging circle nor a visible lip can intrude into the arrival apron.
	var reach := radius * Balance.DOOR_THRESHOLD_POOL_REACH
	return intersects(zones(g, zi), Rect2(pos - Vector2.ONE * reach, Vector2.ONE * reach * 2.0))


static func scatter_footprint(g: Game, name: String, pos: Vector2, decor := false) -> Rect2:
	var rect := g._prop_art_rect(name, pos).grow(Balance.DOOR_THRESHOLD_ART_PAD)
	var base := Terrains.prop_base(name)
	if decor and not Terrains.SOLID_DECOR.has(base):
		# Ground stickers root at +5; obstacles at +22 (trees at +38).
		return rect.merge(Rect2(rect.position - Vector2(0, 33), rect.size))
	var radius := float(Balance.SCENERY_COLLIDER_RADIUS.get(base, 13.0))
	var size: Vector2 = Balance.SCENERY_COLLIDER_RECT.get(base, Vector2.ONE * radius * 2.0)
	size *= Balance.SCENERY_SCALE_JITTER.y
	return rect.merge(Rect2(pos + Vector2(0, 10) - size * 0.5, size))


## Door-triggered offers keep their full count and move just beyond the apron,
## toward the room centre. The apron always stops DOOR_THRESHOLD_CENTRE_CLEAR
## short of the centre (see zones), so for a radius up to that the walk ends on
## a clear point at the latest when it reaches the centre.
static func clear_point(g: Game, zi: int, pos: Vector2, radius: float) -> Vector2:
	var thresholds := zones(g, zi)
	var target := g.room_center(zi)
	for attempt in Balance.DOOR_THRESHOLD_PLACE_TRIES:
		if not intersects(thresholds, Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
			return pos
		if pos == target:
			break
		pos = pos.move_toward(target, Balance.DOOR_THRESHOLD_RELOCATE_STEP)
	return target


## Actual factory footprints, including composite parts and collider offsets.
## Shadows, glows, prompts and particles are deliberately not solid scenery.
static func footprints(node: Node2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var parts: Array = [node]
	parts.append_array(node.get_children())
	for part in parts:
		if not part is Node2D or part.has_meta("cast_shadow") or part.has_meta("prop_contact_shadow"):
			continue
		var rect := Rect2()
		if part is Sprite2D:
			if part.texture == null or part.texture == Art.tex("glow"): continue
			rect = part.get_rect()
		elif part is AnimatedSprite2D:
			if part.sprite_frames == null: continue
			var tex: Texture2D = part.sprite_frames.get_frame_texture(part.animation, part.frame)
			if tex == null: continue
			var size := tex.get_size()
			rect = Rect2(part.offset - size * 0.5 if part.centered else part.offset, size)
		elif part is CollisionShape2D:
			if part.disabled or part.shape == null: continue
			rect = part.shape.get_rect()
		else:
			continue
		out.append(part.global_transform * rect)
	return out


static func body_blocked(thresholds: Array, node: Node2D) -> bool:
	for rect in footprints(node):
		if intersects(thresholds, rect): return true
	return false
