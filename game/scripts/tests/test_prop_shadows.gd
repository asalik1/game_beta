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
	# Every returned failure uses this same cleanup. No fixture enters the live
	# scene tree; manual frame changes still emit AnimatedSprite2D.frame_changed.
	holder.free()
	g.free()
	if result == "":
		print("ok: prop shadow footprints, opaque-foot transforms, selected strip/atlas cells and animation lifetime")
	return result


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
