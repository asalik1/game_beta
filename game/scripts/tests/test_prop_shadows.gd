extends RefCounted
## Shadow geometry contracts use disposable nodes and images only. The live
## hero, world, RNG, saves and Art animation phase remain untouched.


static func run(_r: Node) -> String:
	var g := Game.new()
	var holder := Node2D.new()
	var result := _authored(g, holder)
	if result == "":
		result = _geometry(g, holder)
	if result == "":
		result = _cells(g, holder)
	if result == "":
		result = _animated(g, holder)
	if result == "":
		result = run_sampling()
	if result == "":
		result = run_trees()
	# Every returned failure uses this same cleanup. No fixture enters the live
	# scene tree; manual frame changes still emit AnimatedSprite2D.frame_changed.
	holder.free()
	g.free()
	if result == "":
		print("ok: prop shadow footprints, opaque-foot transforms, selected strip/atlas cells and animation lifetime")
	return result


## Exercise the factories, not just detached sprites: broad-rooted tree art
## used to hide the ellipse, and composite parts never received a cast.
static func run_trees() -> String:
	var cache := Art._cache.duplicate()
	var anim_cache := Art._anim_cache.duplicate()
	var frames_cache := Art._prop_frames_cache.duplicate()
	var wind := Art._wind_mat
	var shadows := preload("res://scripts/prop_shadow.gd")
	var shape_cache: Dictionary = shadows._shape_cache.duplicate()
	var g := Game.new()
	var pads: Dictionary = g._pad_cache.duplicate()
	var holder := Node2D.new()
	g.world = holder
	var result := _trees(g)
	holder.free()
	g._pad_cache = pads
	g.free()
	Art._cache = cache
	Art._anim_cache = anim_cache
	Art._prop_frames_cache = frames_cache
	Art._wind_mat = wind
	shadows._shape_cache = shape_cache
	if result == "":
		print("TREE SHADOW CONTRACT PASS: factory trees on their root band and trunk, canopy-capped size, every composite part grounded under sunken parts, fringe-proof trunk span, frames and unchanged rock/stump")
	return result


static func _trees(g: Game) -> String:
	for name in ["tree_green", "tree_autumn", "tree_gnarled", "tree_teal", "tree_spore",
			"tree_snow", "tree_winter", "deadtree", "grave_deadtree"]:
		for variation in [0.85, 1.15]:
			var body := g._add_obstacle(name, Vector2(100, 100), variation)
			var cast := _cast(body) as Sprite2D
			var error := tree_contact_error(cast)
			if error != "": return name + ": " + error
			var source: Node2D = null
			for child in body.get_children():
				if child is Node2D and child.is_in_group("combat_foliage"):
					source = child
				if child.has_meta("prop_contact_shadow") and child.visible:
					return name + ": duplicate legacy ellipse still visible"
			if source == null or cast.z_index >= source.z_index:
				return name + ": trunk shadow is not below its canopy"
			error = trunk_placement_error(cast, source)
			if error != "": return name + ": " + error
			if source is AnimatedSprite2D:
				for frame in source.sprite_frames.get_frame_count(source.animation):
					source.frame = frame
					error = tree_contact_error(cast)
					if error == "": error = trunk_placement_error(cast, source)
					if error != "": return name + ": animated " + error
			body.free()
	# Every rooted part casts (trees the trunk contact, statues/pillars/cacti
	# their copy), and every shadow stays under the composite's sunken parts.
	for name in ["village_grove", "darkwood_hollow", "marsh_islet", "ice_waymarker", "grave_memorial",
			"spore_cathedral", "keep_courtyard", "desert_hoodoo"]:
		var body := g._add_structure(name, Vector2.ZERO)
		var def: Dictionary = Terrains.STRUCTURES[name]
		var parts: Array = def.get("parts", [])
		var expected := int(g._canopy_tree(Terrains.prop_base(String(def.sprite))))
		var lowest := 0
		for part in parts:
			expected += int(g._canopy_tree(Terrains.prop_base(String(part.sprite))))
			lowest = mini(lowest, int(part.get("z", 0)))
		var found := 0
		var casts := 0
		for child in body.get_children():
			if not child.has_meta("cast_shadow"):
				continue
			casts += 1
			if child.z_index >= lowest:
				return name + ": a part shadow can sort over a sunken part"
			if child.get_meta("cast_shadow_mode", "") == "trunk":
				found += 1
				var error := tree_contact_error(child as Sprite2D)
				if error != "": return name + ": " + error
		if found != expected: return name + ": missing composite trunk contacts"
		if casts != 1 + parts.size(): return name + ": a rooted composite part has no ground shadow"
		body.free()
	var fringe_error := _fringe(g)
	if fringe_error != "": return fringe_error
	for name in ["rock", "tree_stump"]:
		var body := g._add_obstacle(name, Vector2.ZERO)
		if _cast(body).get_meta("cast_shadow_mode", "") != "hug":
			return name + ": non-canopy prop lost its existing hugging shadow"
		body.free()
	return ""


static func tree_contact_error(cast: Sprite2D) -> String:
	if cast == null or cast.get_meta("cast_shadow_mode", "") != "trunk" or not cast.visible:
		return "tree needs a visible soft trunk contact shadow"
	var size := cast.texture.get_size() * cast.scale
	if cast.texture != Art.tex("shadow") or cast.material != null:
		return "tree shadow copied the canopy or its sway material"
	if size.x < Balance.TREE_SHADOW_WIDTH_MIN - 0.01 or size.x > Balance.TREE_SHADOW_WIDTH_MAX + 0.01 \
			or not is_equal_approx(size.y, size.x * Balance.TREE_SHADOW_DEPTH):
		return "tree shadow escaped its trunk size class"
	if cast.z_index <= -8 or cast.z_index >= 0:
		return "tree shadow escaped the floor/prop layer interval"
	return ""


## Where the contact lands and how big it is: inside the painted root band
## (not the sprite centre or canopy), within the trunk's opaque span, and
## never wider than the canopy cap allows.
static func trunk_placement_error(cast: Sprite2D, source: Node2D) -> String:
	var shadows := preload("res://scripts/prop_shadow.gd")
	var shape: Dictionary = shadows.shape(source, true)
	var used: Rect2i = shape["used"]
	var base: Rect2i = shape.get("base", used)
	var size: Vector2 = shape["size"]
	var roots: Vector2 = source.transform * shadows.foot(source, shape)
	var band_h := used.size.y * Balance.TREE_SHADOW_FOOT_BAND * source.transform.y.length()
	if absf(cast.position.y - roots.y) > band_h:
		return "tree shadow left the painted root band"
	var left: Vector2 = source.transform * shadows.foot(source,
		{"size": size, "used": Rect2i(base.position, Vector2i(0, base.size.y))})
	var right: Vector2 = source.transform * shadows.foot(source,
		{"size": size, "used": Rect2i(Vector2i(base.end.x, base.position.y), Vector2i(0, base.size.y))})
	if cast.position.x < minf(left.x, right.x) - 0.5 or cast.position.x > maxf(left.x, right.x) + 0.5:
		return "tree shadow slid off its trunk"
	var width := cast.texture.get_size().x * cast.scale.x
	var canopy := used.size.x * source.transform.x.length()
	if width > maxf(Balance.TREE_SHADOW_WIDTH_MIN, canopy * Balance.TREE_SHADOW_CANOPY_FRACTION) + 0.01:
		return "tree shadow grew past its canopy cap"
	return ""


## tree_green4 ships alpha-1 specks right of its roots. They must not pull the
## contact off the trunk: compare it with an independent opaque-pixel scan.
static func _fringe(g: Game) -> String:
	if not Art.has_sprite("tree_green4"):
		return ""
	var src := Sprite2D.new()
	src.texture = Art.tex("tree_green4")
	var render := float(g._scenery_render_scale(src, "tree_green", 1.0))
	src.scale = Vector2(render, render)
	var body := Node2D.new()
	g.world.add_child(body)
	body.add_child(src)
	g._prop_cast_shadow(body, src, NAN, true)
	var cast := _cast(body) as Sprite2D
	var img := src.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var rows := maxi(1, int(used.size.y * Balance.TREE_SHADOW_FOOT_BAND))
	var left := -1
	var right := -1
	for x in range(used.position.x, used.end.x):
		for y in range(used.end.y - rows, used.end.y):
			if img.get_pixel(x, y).a > Balance.TREE_SHADOW_ALPHA_MIN:
				if left < 0:
					left = x
				right = x
				break
	if cast == null or left < 0:
		return "tree_green4 fringe fixture has no trunk contact"
	var trunk: Vector2 = src.transform * (Vector2((left + right + 1) * 0.5, 0.0) - src.texture.get_size() * 0.5)
	if absf(cast.position.x - trunk.x) > 3.0:
		return "tree_green4 contact follows its invisible fringe (%.1f px off the trunk)" % (cast.position.x - trunk.x)
	return ""


## Fresh production visuals, independent of earlier suite/world state.
static func run_sampling() -> String:
	var cache := Art._cache.duplicate()
	var anim_cache := Art._anim_cache.duplicate()
	var frames_cache := Art._prop_frames_cache.duplicate()
	var shadows := preload("res://scripts/prop_shadow.gd")
	var shape_cache: Dictionary = shadows._shape_cache.duplicate()
	var g := Game.new()
	var holder := Node2D.new()
	var result := _sampling(g, holder)
	holder.free()
	g.free()
	Art._cache = cache
	Art._anim_cache = anim_cache
	Art._prop_frames_cache = frames_cache
	shadows._shape_cache = shape_cache
	if result == "":
		print("ok: scenery sampling: static/animated painterly LINEAR, pixel/fallback NEAREST, direct animation and shadow copies")
	return result


static func _sampling(g: Game, holder: Node2D) -> String:
	for name in ["camp_workbench", "hideout_table", "pebble", "tree_green", "camp_bonfire", "book", "bone", "wall_grave"]:
		var src := g._prop_visual(name)
		var body := _body(holder, src)
		var pixel: bool = name in ["book", "bone", "wall_grave"]
		var expected := CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
		if src.texture_filter != expected:
			return "fresh scenery has wrong sampling: " + name
		if name in ["tree_green", "camp_bonfire"] and not src is AnimatedSprite2D:
			return "sampling fixture lost its animated source: " + name
		if name == "camp_workbench" and not src is Sprite2D:
			return "sampling fixture lost its static source"
		g._prop_cast_shadow(body, src)
		var cast := _cast(body)
		if cast == null or cast.texture_filter != expected:
			return "shadow did not inherit scenery sampling: " + name
		body.free()
	# Real production fallback: "glow" ships no PNG and is built procedurally.
	var glow := g._prop_visual("glow")
	holder.add_child(glow)
	if glow.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		return "procedural fallback decal lost NEAREST"
	var direct := Art.anim_prop("camp_bonfire")
	holder.add_child(direct)
	if direct.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR:
		return "direct animated-prop consumer still inherits project NEAREST"
	# Strip frames must not bleed into their neighbours under LINEAR.
	var frame0: AtlasTexture = direct.sprite_frames.get_frame_texture("default", 0)
	if not frame0.filter_clip:
		return "animated strip frames lack filter_clip (LINEAR would bleed across frames)"
	# A pixel-authored strip must use the same exception as its static source.
	# Lend one frame locally; never depend on another section's cache contents.
	Art._anim_cache["bone_anim"] = {"tex": Art.tex("bone"), "frames": 1, "fps": 6.0,
		"frame_size": Vector2i(9, 12)}
	Art._prop_frames_cache.erase("bone")
	var pixel_anim := Art.anim_prop("bone")
	holder.add_child(pixel_anim)
	if pixel_anim.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		return "pixel-authored animation lost NEAREST exception"
	return ""


static func _body(holder: Node2D, src: Node2D) -> Node2D:
	var body := Node2D.new()
	holder.add_child(body)
	body.add_child(src)
	return body


static func _cast(body: Node2D) -> Node2D:
	for child in body.get_children():
		if child.has_meta("cast_shadow"):
			return child as Node2D
	return null


static func _authored(g: Game, holder: Node2D) -> String:
	# These are actual sibling assets, including the reported diagonal cluster.
	# A 150px width matches the cluster's production scale and exercises the
	# capped hugging offset on taller sculpture/building silhouettes too.
	for name in ["tombstone3", "grave_statue", "rock", "cottage_a", "tree_green", "signpost"]:
		var src := Sprite2D.new()
		src.texture = Art.tex(name)
		src.scale = Vector2.ONE * (150.0 / src.texture.get_width())
		var body := _body(holder, src)
		var narrow: bool = name in ["tree_green", "signpost"]
		if (g._shadow_bottom_ratio(src) < Balance.CAST_SHADOW_STAND_RATIO) != narrow:
			return "prop footprint classified %s incorrectly (narrow=%s)" % [name, narrow]
		g._prop_cast_shadow(body, src)
		var cast := _cast(body)
		if cast == null or (cast.scale.y < 0.0) != narrow:
			return "prop shadow projected a broad base or flattened a narrow trunk: " + name
		if not narrow:
			var delta := cast.position - src.position
			if delta.x <= 0.0 or delta.y <= 0.0 or delta.x > 8.001 or delta.length() > 10.001:
				return "broad prop shadow escaped its bounded southeast contact rim: " + name
			if not cast.transform.x.is_equal_approx(src.transform.x) or not cast.transform.y.is_equal_approx(src.transform.y):
				return "hugging shadow distorted its source silhouette: " + name
		body.free()
	return ""


static func _stem_texture() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4, 5, 24, 8), Color.WHITE)
	img.fill_rect(Rect2i(13, 13, 6, 32), Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _narrow_ends_texture() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(13, 5, 6, 40), Color.WHITE)
	img.fill_rect(Rect2i(4, 20, 24, 10), Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _geometry(g: Game, holder: Node2D) -> String:
	var texture := _stem_texture()
	for centered in [true, false]:
		for mirrored in [false, true]:
			var src := Sprite2D.new()
			src.texture = texture
			src.centered = centered
			src.offset = Vector2(7, -9)
			src.position = Vector2(31, -27)
			src.rotation = 0.23
			src.scale = Vector2(-1.7 if mirrored else 1.7, 1.4)
			src.flip_h = mirrored
			src.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var body := _body(holder, src)
			var shape: Dictionary = g._shadow_shape(src)
			if shape.get("used") != Rect2i(4, 5, 24, 40) or shape.get("size") != Vector2(32, 48):
				return "opaque-foot fixture read the canvas bottom instead of visible pixels"
			var expected := Vector2(16, 45) + src.offset
			if centered:
				expected -= Vector2(16, 24)
			var foot: Vector2 = g._shadow_foot(src, shape)
			if not foot.is_equal_approx(expected):
				return "opaque foot lost padding, centering or source offset"
			g._prop_cast_shadow(body, src)
			var cast := _cast(body) as Sprite2D
			if cast == null:
				return "padded standing sprite did not cast a shadow"
			if (src.transform * expected).distance_to(cast.transform * expected) > 0.001:
				return "rotated/mirrored prop shadow detached from the visible source foot"
			if cast.centered != src.centered or cast.offset != src.offset or cast.flip_h != src.flip_h or cast.texture_filter != src.texture_filter:
				return "prop shadow lost source draw properties while copying its silhouette"
			body.free()
	# Vertical flipping moves the source's TOP edge to the displayed foot. Its
	# 5px upper padding is different from the 3px bottom padding on purpose.
	var flipped := Sprite2D.new()
	flipped.texture = texture
	var flipped_body := _body(holder, flipped)
	if g._shadow_bottom_ratio(flipped) >= Balance.CAST_SHADOW_STAND_RATIO:
		return "upright T fixture lost its narrow lower stem"
	flipped.flip_v = true
	if g._shadow_bottom_ratio(flipped) < Balance.CAST_SHADOW_STAND_RATIO:
		return "flipped footprint reused the original bottom instead of its broad displayed base"
	# The inverted T should hug. Use a shape narrow at BOTH ends for the
	# separate projected-contact check, keeping the asymmetric padding.
	flipped.texture = _narrow_ends_texture()
	flipped.offset = Vector2(3, -7)
	flipped.rotation = -0.19
	flipped.scale = Vector2(1.2, 1.3)
	var flipped_shape: Dictionary = g._shadow_shape(flipped)
	if float(flipped_shape["ratio"]) >= Balance.CAST_SHADOW_STAND_RATIO:
		return "narrow-ended flipped fixture lost its projected footprint"
	var flipped_foot: Vector2 = g._shadow_foot(flipped, flipped_shape)
	var flipped_expected := Vector2(3, 48 - 5 - 24 - 7)
	if not flipped_foot.is_equal_approx(flipped_expected):
		return "vertically flipped source used its former bottom as the ground contact"
	g._prop_cast_shadow(flipped_body, flipped)
	var flipped_cast := _cast(flipped_body) as Sprite2D
	if flipped_cast == null or not flipped_cast.flip_v:
		return "prop shadow failed to copy a vertically flipped silhouette"
	if (flipped.transform * flipped_expected).distance_to(flipped_cast.transform * flipped_expected) > 0.001:
		return "vertically flipped shadow did not retain its displayed ground contact"
	flipped_body.free()
	return ""


static func _cells(g: Game, holder: Node2D) -> String:
	var img := Image.create(48, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cells := [Rect2i(3, 4, 10, 25), Rect2i(6, 7, 12, 24), Rect2i(5, 2, 8, 34), Rect2i(2, 9, 18, 21)]
	for i in cells.size():
		var region: Rect2i = cells[i]
		region.position += Vector2i((i % 2) * 24, (i / 2) * 40)
		img.fill_rect(region, Color.WHITE)
	var texture := ImageTexture.create_from_image(img)
	var src := Sprite2D.new()
	src.texture = texture
	src.hframes = 2
	src.vframes = 2
	var body := _body(holder, src)
	for i in cells.size():
		src.frame = i
		var shape: Dictionary = g._shadow_shape(src)
		if shape.get("size") != Vector2(24, 40) or shape.get("used") != cells[i]:
			return "shadow shape cache reused another selected horizontal/vertical strip cell"
	# Same RID, new subdivision: the top row now includes both old cells.
	src.frame = 0
	src.hframes = 1
	var row_shape: Dictionary = g._shadow_shape(src)
	if row_shape.get("size") != Vector2(48, 40) or row_shape.get("used") != Rect2i(3, 4, 39, 27):
		return "shadow shape cache ignored changed frame dimensions for the same texture"
	src.hframes = 2
	src.frame = 3
	g._prop_cast_shadow(body, src)
	var cast := _cast(body) as Sprite2D
	if cast == null or cast.hframes != 2 or cast.vframes != 2 or cast.frame != 3:
		return "prop shadow copied the complete strip or the wrong current cell"
	body.free()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(24, 40, 24, 40)
	var atlas_src := Sprite2D.new()
	atlas_src.texture = atlas
	var atlas_body := _body(holder, atlas_src)
	var atlas_shape: Dictionary = g._shadow_shape(atlas_src)
	if atlas_shape.get("size") != Vector2(24, 40) or atlas_shape.get("used") != cells[3]:
		return "shadow alpha bounds escaped the AtlasTexture region"
	# Distinct AtlasTextures forward the SAME backing RID. Their equal-sized
	# regions must still retain different local opaque rectangles.
	var other_atlas := AtlasTexture.new()
	other_atlas.atlas = texture
	other_atlas.region = Rect2(0, 0, 24, 40)
	var other_src := Sprite2D.new()
	other_src.texture = other_atlas
	var other_body := _body(holder, other_src)
	var other_shape: Dictionary = g._shadow_shape(other_src)
	if other_shape.get("size") != Vector2(24, 40) or other_shape.get("used") != cells[0] \
			or g._shadow_shape(atlas_src).get("used") != cells[3]:
		return "different atlas regions sharing one texture RID aliased their opaque bounds"
	other_body.free()
	# The same atlas resource can gain a margin. get_image omits this padding,
	# but the drawn local size and opaque rectangle must include it.
	atlas.margin = Rect2(3, 5, 8, 10)
	var margin_shape: Dictionary = g._shadow_shape(atlas_src)
	if margin_shape.get("size") != Vector2(32, 50) or margin_shape.get("used") != Rect2i(5, 14, 18, 21):
		return "atlas margin did not expand the logical cell and translate its opaque bounds"
	atlas_body.free()
	return ""


static func _animated(g: Game, holder: Node2D) -> String:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4, 5, 24, 8), Color.WHITE)
	img.fill_rect(Rect2i(13, 13, 6, 32), Color.WHITE)
	img.fill_rect(Rect2i(38, 3, 20, 10), Color.WHITE)
	img.fill_rect(Rect2i(45, 13, 6, 28), Color.WHITE)
	var texture := ImageTexture.create_from_image(img)
	var frames := SpriteFrames.new()
	for i in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * 32, 0, 32, 48)
		frames.add_frame("default", atlas)
	var src := AnimatedSprite2D.new()
	src.sprite_frames = frames
	src.offset = Vector2(-4, 6)
	src.flip_h = true
	src.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var body := _body(holder, src)
	g._prop_cast_shadow(body, src)
	var cast := _cast(body) as AnimatedSprite2D
	if cast == null or cast.sprite_frames != frames or cast.offset != src.offset or cast.flip_h != src.flip_h or cast.texture_filter != src.texture_filter:
		return "animated prop shadow did not share the source silhouette and draw settings"
	if g._shadow_shape(src).get("used") != Rect2i(4, 5, 24, 40):
		return "animated atlas frame zero lost its own opaque rectangle"
	src.frame = 1
	if cast.frame != 1:
		return "animated shadow did not follow the live source frame"
	if g._shadow_shape(src).get("used") != Rect2i(6, 3, 20, 38):
		return "animated atlas frame reused its sibling's cached opaque rectangle"
	var expected_foot := Vector2(-4, 41 - 24 + 6)
	if (src.transform * expected_foot).distance_to(cast.transform * expected_foot) > 0.001:
		return "animated shadow frame advanced without moving its opaque-foot anchor"
	var cast_ref: WeakRef = weakref(cast)
	cast.free()
	src.frame = 0  # A retained source signal must tolerate its retired shadow.
	src.animation_changed.emit()  # Both retained signal paths must tolerate it.
	if cast_ref.get_ref() != null:
		return "retired animated shadow remained alive after its node was freed"
	g._prop_cast_shadow(body, src)
	var next_cast := _cast(body) as AnimatedSprite2D
	if next_cast == null:
		return "animated source could not receive a replacement shadow"
	src.frame = 1
	if next_cast.frame != 1:
		return "replacement animated shadow did not follow the retained source"
	var source_ref: WeakRef = weakref(src)
	var next_ref: WeakRef = weakref(next_cast)
	body.free()
	if source_ref.get_ref() != null or next_ref.get_ref() != null:
		return "freeing the prop body leaked its animation or shadow"
	return ""
