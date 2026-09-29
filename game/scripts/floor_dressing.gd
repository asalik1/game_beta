extends RefCounted
## Cosmetic only. Private RNGs and pure layout plans leave encounter/scenery
## rolls untouched; the caller owns all nodes through zone_scenery.
const Floor := preload("res://scripts/room_floor.gd")
const WearShader := preload("res://shaders/floor_wear.gdshader")
# Generated wall drifts. Capital rooms stay authored-only (FLOOR_DRESSING).
const WALL_TERRAINS := ["keep", "darkwood", "village"]


static func _rng(g: Game, zi: int, pass_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s|%s|%s|%s|%s" % [g.wander_seed, g.chapter_id, zi, g.terrain_by_zone[zi], pass_name]).hash()
	return rng


static func inner(g: Game, zi: int) -> Rect2:
	var rect := Floor.inner_floor(g, zi)
	rect.position += g.room_rect(zi).position
	return rect


static func wear_plan(g: Game, zi: int) -> Array:
	var rng := _rng(g, zi, "wear")
	var rect := inner(g, zi)
	var area := rect.get_area() / float(g.ROOM_W * g.ROOM_H)
	var count := maxi(Balance.FLOOR_WEAR_MIN_COUNT, roundi(rng.randi_range(
		Balance.FLOOR_WEAR_COUNT.x, Balance.FLOOR_WEAR_COUNT.y) * area))
	var out: Array = []
	for i in count:
		var uv := Vector2(rng.randf(), rng.randf())
		# Every third patch lives beyond the vignette, even in a small room.
		# The other two thirds favour walls, alternating corner accumulation.
		if i % Balance.FLOOR_WEAR_INTERIOR_EVERY == 0:
			var margin := (rect.size * Balance.FLOOR_WEAR_INTERIOR_INSET).max(
				Vector2.ONE * Balance.ROOM_EDGE_WIDTH).min(rect.size * 0.5)
			uv = (margin + uv * (rect.size - margin * 2.0)) / rect.size
		else:
			var edge := rng.randf_range(Balance.FLOOR_WEAR_EDGE_BAND.x, Balance.FLOOR_WEAR_EDGE_BAND.y)
			if i % 2 == 0:
				uv.x = edge if uv.x < 0.5 else 1.0 - edge
			uv.y = edge if uv.y < 0.5 else 1.0 - edge
			if i % 2 != 0 and rng.randf() < 0.5:
				uv = Vector2(uv.y, uv.x)
		var diameter := rng.randf_range(Balance.FLOOR_WEAR_SIZE.x, Balance.FLOOR_WEAR_SIZE.y)
		out.append({"pos": rect.position + uv * rect.size,
			"size": Vector2(diameter, diameter * rng.randf_range(Balance.FLOOR_WEAR_SQUASH.x, Balance.FLOOR_WEAR_SQUASH.y)),
			"rotation": rng.randf_range(-Balance.FLOOR_WEAR_ROTATION, Balance.FLOOR_WEAR_ROTATION),
			"alpha": rng.randf_range(Balance.FLOOR_WEAR_DARK_A.x, Balance.FLOOR_WEAR_DARK_A.y)})
	return out


static func wear_material(g: Game, zi: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WearShader
	mat.set_shader_parameter("noise_scales", Balance.FLOOR_WEAR_NOISE_SCALES)
	mat.set_shader_parameter("noise_floor", Balance.FLOOR_WEAR_NOISE_FLOOR)
	mat.set_shader_parameter("soft_core", Balance.FLOOR_WEAR_SOFT_CORE)
	var rng := _rng(g, zi, "noise")
	mat.set_shader_parameter("noise_offset", Vector2(rng.randf(), rng.randf()) * Balance.FLOOR_WEAR_NOISE_OFFSET)
	var rect := inner(g, zi)
	mat.set_shader_parameter("floor_bounds", Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y))
	return mat


static func spawn_wear(g: Game, zi: int, terrain: Dictionary) -> void:
	if not Art.GROUND.has(String(terrain.get("ground", ""))): return
	var material := wear_material(g, zi)
	for patch in wear_plan(g, zi):
		var sprite := Sprite2D.new()
		sprite.texture = Art.tex("white")   # shader supplies a broad, soft mask
		sprite.position = patch.pos
		sprite.scale = patch.size / sprite.texture.get_size()
		sprite.rotation = patch.rotation
		sprite.modulate = Color(0, 0, 0, patch.alpha)
		sprite.material = material
		sprite.z_index = -9   # vignette sorts after this; all ground tells sort above
		sprite.set_meta("floor_wear", true)
		g.world.add_child(sprite)
		g.zone_scenery[zi].append(sprite)


## Check the whole small footprint, not just its centre, against curved lanes,
## reservations (hazards, water, notches, landmarks), and existing vegetation.
static func clear(g: Game, road: Dictionary, local: Vector2, half: Vector2,
		reserved: Array, placed: Array) -> bool:
	for off in [Vector2.ZERO, Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(-half.x, half.y), half]:
		if g._lane_blocked(road, local + off) or g._reserved_blocks(reserved, local + off): return false
	for anchor: Vector2 in placed:
		if local.distance_to(anchor) < Balance.WALL_DRESS_ANCHOR_CLEAR + half.length(): return false
	return true


static func wall_plan(g: Game, zi: int, reserved: Array, placed: Array) -> Array:
	if String(g.terrain_by_zone[zi]) not in WALL_TERRAINS: return []
	var rng := _rng(g, zi, "wall-base")
	var pr := g.play_rect(zi)
	var rect := inner(g, zi)
	var road := g.road_layout(zi)
	var out: Array = []
	var centres: Array[Vector2] = []
	for attempt in Balance.WALL_DRESS_TRIES:
		if centres.size() >= Balance.WALL_DRESS_CLUSTERS: break
		var side := attempt % 4
		var along := rng.randf_range(Balance.WALL_DRESS_ALONG_INSET, 1.0 - Balance.WALL_DRESS_ALONG_INSET)
		var depth := rng.randf_range(Balance.WALL_DRESS_DEPTH.x, Balance.WALL_DRESS_DEPTH.y)
		var centre := rect.position + Vector2(rect.size.x * along, depth)
		if side == 1: centre.y = rect.end.y - depth
		if side >= 2: centre = Vector2(rect.position.x + depth if side == 2 else rect.end.x - depth, rect.position.y + rect.size.y * along)
		var spaced := true
		for other in centres:
			if centre.distance_to(other) < Balance.WALL_DRESS_CLUSTER_SPACING: spaced = false
		if not spaced: continue
		var count := rng.randi_range(Balance.WALL_DRESS_MEMBERS.x, Balance.WALL_DRESS_MEMBERS.y)
		var group: Array = []
		for k in count:
			var offset := Vector2((k - (count - 1) * 0.5) * Balance.WALL_DRESS_MEMBER_SPACING,
				rng.randf_range(-Balance.WALL_DRESS_JITTER, Balance.WALL_DRESS_JITTER))
			if side >= 2: offset = Vector2(offset.y, offset.x)
			var pos := centre + offset
			var size := Balance.WALL_DRESS_SIZE
			if not rect.encloses(Rect2(pos - size * 0.5, size)) or not clear(g, road, pos - pr.position, size * 0.5, reserved, placed): break
			# Rubble/pebbles with moss and dust made from the existing soft mask.
			var key: String = ["rubble", "glow", "pebble"][k % 3]
			var spec := {"key": key, "pos": pos, "size": size, "cluster": centres.size()}
			if key == "glow":
				spec["tint"] = Balance.WALL_DRESS_MOSS if k % 2 else Balance.WALL_DRESS_DUST
			else:
				spec["tint"] = Balance.WALL_DRESS_TINT
				spec["scale"] = rng.randf_range(Balance.WALL_DRESS_STONE_SCALE.x, Balance.WALL_DRESS_STONE_SCALE.y)
				spec["flip"] = rng.randf() < 0.5
			group.append(spec)
		if group.size() != count: continue   # keep complete 3-6 member clusters
		centres.append(centre)
		out.append_array(group)
	return out


static func spawn_details(g: Game, zi: int, reserved: Array, placed: Array, authored: Array) -> void:
	var material := wear_material(g, zi)
	for spec in wall_plan(g, zi, reserved, placed):
		var node: Node2D
		if spec.key == "glow":
			node = _detail(g, zi, spec.key, spec.pos, spec.size, spec.tint)
			node.material = material
		else:
			node = _stone(g, zi, spec)
		node.set_meta("wall_base", spec.cluster)
	# The capital generator authors these in the same full-cell coordinate
	# space as its facade. Each authored point is the piece's y-sort anchor; a
	# banner hangs its style's lift up the arcade it sorts in front of. No
	# scatter and no colliders; test_world_read proves every piece lands visible.
	var road := g.road_layout(zi)
	var room_scale := float(g.zones[zi].get("room_scale", 1.0))
	var origin := g.play_rect(zi).position
	for spec in authored:
		var style: Dictionary = Balance.CIVIC_DRESS_STYLES[spec.kind]
		var pos := g.room_pos(zi, spec.x, spec.y)
		var size: Vector2 = style.size * room_scale
		var lift: float = float(style.get("lift", 0.0)) * room_scale
		var centre := pos if spec.kind == "puddle" else pos - Vector2(0, lift + size.y * 0.5)
		if not clear(g, road, centre - origin, size * 0.5, [], []): continue
		var sprite := _detail(g, zi, spec.key, pos, size, style.tint)
		sprite.set_meta("civic_dressing", spec.kind)
		if spec.kind != "puddle":   # a puddle stays a flat z -8 decal
			sprite.offset.y = -sprite.texture.get_height() * 0.5 - lift / sprite.scale.y
			sprite.z_index = 0


## The scatter's own stone (pebble resolves to the matte rock2 through
## _prop_visual) at its family width, uniformly scaled, so a wall drift
## matches the loose decor in the same frame.
static func _stone(g: Game, zi: int, spec: Dictionary) -> Node2D:
	var vis: Node2D = g._prop_visual(spec.key)
	var s: float = g._scenery_render_scale(vis, spec.key, float(spec.scale))
	vis.scale = Vector2(-s if spec.flip else s, s)
	vis.position = spec.pos
	vis.modulate = spec.tint
	vis.z_index = -8
	g.world.add_child(vis)
	g.zone_scenery[zi].append(vis)
	return vis


static func _detail(g: Game, zi: int, key: String, pos: Vector2, size: Vector2, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(key)
	sprite.position = pos
	sprite.scale = size / sprite.texture.get_size()
	sprite.modulate = tint
	sprite.z_index = -8
	g.world.add_child(sprite)
	g.zone_scenery[zi].append(sprite)
	return sprite
