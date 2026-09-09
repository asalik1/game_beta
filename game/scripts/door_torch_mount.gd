extends RefCounted
## Door-side pillars stand on the floor; their painted plinth determines clearance.
## No collision or admission rules live here. Source art and light budgets stay intact.
static var _geometry_cache: Dictionary = {}


static func build(g, zi: int, doorway: Vector2, vertical: bool) -> void:
	var info: Dictionary = Art.anim_info("torch_pillar")
	var span: float = Game.DOOR_TILES * Game.TILE * 0.5 + Balance.DOOR_TORCH_PAIR_OFFSET
	for side in [-1, 1]:
		var source := Sprite2D.new()
		if not info.is_empty():
			source.texture = info["tex"]
			source.hframes = int(info["frames"])
			var scale_by: float = Balance.DOOR_TORCH_HEIGHT / float(source.texture.get_height())
			source.scale = Vector2.ONE * scale_by
			source.modulate = Art.hdr(Color.WHITE, Game.EMISSIVE_BLOOM_LIFT)
		else:
			source.texture = Art.tex("torch")
			source.scale = Vector2(3, 3)
		var measured := geometry(source)
		var footprint: Rect2 = measured["footprint"]
		var size: Vector2 = measured["size"]
		var foot := Vector2(footprint.get_center().x, footprint.end.y) - size * 0.5
		var extent := footprint.size * source.scale.abs()
		var anchor := doorway + (Vector2(0, side * span) if vertical else Vector2(side * span, 0))
		var direction := ""
		if zi >= 0:
			var pr: Rect2 = g.play_rect(zi)
			var center: Vector2 = g.room_center(zi)
			if vertical:
				var west: bool = doorway.x < center.x
				direction = "W" if west else "E"
				anchor.x = pr.position.x + Game.TILE + Balance.DOOR_TORCH_GROUND_CLEARANCE + extent.x * 0.5 \
					if west else pr.end.x - Game.TILE - Balance.DOOR_TORCH_GROUND_CLEARANCE - extent.x * 0.5
				# Keep the paired ground footprints centered equally above/below the lane.
				anchor.y += extent.y * 0.5
			else:
				var north: bool = doorway.y < center.y
				direction = "N" if north else "S"
				anchor.y = pr.position.y + Game.TILE + Game.WALL_FACE_H \
					+ Balance.DOOR_TORCH_GROUND_CLEARANCE + extent.y \
					if north else pr.end.y - Game.TILE - Balance.DOOR_TORCH_GROUND_CLEARANCE
		else:
			# Preserve the legacy non-room caller's ground line; it has no wall to clear.
			anchor.y += 24.0
		var root := Node2D.new()
		root.name = "DoorTorch_%d_%s_%d" % [zi, direction, side]
		var feet_offset := Vector2(0, Player.HERO_FEET_ANCHOR)
		root.position = anchor - feet_offset
		root.set_meta("door_torch", true)
		root.set_meta("door_torch_room", zi)
		root.set_meta("door_torch_direction", direction)
		root.set_meta("door_torch_side", side)
		# Share the hero/scatter-prop sort convention: painted feet are +22
		# below the origin. Compensate in the child to preserve every art pixel.
		root.z_index = 0
		root.y_sort_enabled = false
		g.world.add_child(root)
		source.name = "Pillar"
		source.position = feet_offset - source.transform.basis_xform(foot)
		root.add_child(source)
		source.set_meta("occlusion_sort_y", root.global_position.y)
		source.set_meta("occlusion_radius", (Vector2(measured["used"].size) * source.scale.abs()).length() * 0.5)
		source.add_to_group("structure_occluders")
		g._prop_cast_shadow(root, source)
		if not info.is_empty():
			var per: float = 1.0 / maxf(1.0, float(info.get("fps", 6.0)))
			var anim := source.create_tween().set_loops()
			var source_ref: WeakRef = weakref(source)
			for frame in int(info["frames"]):
				anim.tween_interval(per)
				anim.tween_callback(func() -> void:
					var live := source_ref.get_ref() as Sprite2D
					if live != null:
						live.frame = (live.frame + 1) % live.hframes)
		# Keep the original world-space light topology and RNG consumption. Both
		# glow layers translate with the actual flame sprite; budgets do not change.
		var source_at: Vector2 = g.world.to_local(source.global_position)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.6, 0.2, 0.5)
		glow.position = source_at + Vector2(0, -12)
		glow.scale = Vector2(2.5, 2.5)
		glow.z_index = 1
		g.world.add_child(glow)
		# The world owns both independent light layers; retire them with this mount.
		var glow_ref: WeakRef = weakref(glow)
		root.tree_exiting.connect(func() -> void:
			var live := glow_ref.get_ref() as Node
			if live != null:
				live.queue_free())
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "scale", Vector2(3.1, 3.1), 0.5 + randf() * 0.3)
		tween.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.5 + randf() * 0.3)
		if zi >= 0:
			var floor_glow: Node2D = g._floor_glow(g.world, source_at + Game.TORCH_GLOW_DROP,
				Game.TORCH_GLOW_COLOR, Game.TORCH_GLOW_RADIUS, Game.TORCH_GLOW_STRENGTH, zi)
			if floor_glow != null:
				var floor_ref: WeakRef = weakref(floor_glow)
				root.tree_exiting.connect(func() -> void:
					var live := floor_ref.get_ref() as Node
					if live != null:
						live.queue_free())


## Union the actual painted lower plinth across the animation, once per strip.
## Stable bounds avoid a flickering fire changing the pillar's base or position.
static func geometry(source: Sprite2D) -> Dictionary:
	var tex: Texture2D = source.texture
	var key := "%d:%d:%d" % [tex.get_instance_id(), source.hframes, source.vframes]
	if _geometry_cache.has(key):
		return _geometry_cache[key]
	var img := tex.get_image()
	var cell := Vector2i(tex.get_width() / source.hframes, tex.get_height() / source.vframes)
	var used := Rect2i()
	var base := Rect2i()
	if img != null and not img.is_empty():
		for f in source.hframes * source.vframes:
			var one := img.get_region(Rect2i(Vector2i(f % source.hframes, f / source.hframes) * cell, cell))
			var ink := one.get_used_rect()
			if ink.size.x <= 0 or ink.size.y <= 0:
				continue
			used = ink if used.size == Vector2i.ZERO else used.merge(ink)
			var depth := maxi(1, ceili(ink.size.y * Balance.DOOR_TORCH_FOOT_BAND))
			var band := Rect2i(ink.position.x, ink.end.y - depth, ink.size.x, depth)
			var paint := one.get_region(band).get_used_rect()
			paint.position += band.position
			base = paint if base.size == Vector2i.ZERO else base.merge(paint)
	if base.size == Vector2i.ZERO:
		base = Rect2i(Vector2i.ZERO, cell)
	if used.size == Vector2i.ZERO:
		used = base
	var result := {"size": Vector2(cell), "used": Rect2(used), "footprint": Rect2(base)}
	_geometry_cache[key] = result
	return result
