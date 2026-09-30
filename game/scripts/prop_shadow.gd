extends RefCounted
## Scenery shadows use the painted footprint, including frame padding and pose.
## Trees use soft trunk contacts; other props hug or project their silhouette.
static var _shape_cache: Dictionary = {}


## `trunk` also measures the opaque root band that tree contacts sit on;
## other callers skip that scan and cache their geometry separately.
static func shape(spr: Node2D, trunk := false) -> Dictionary:
	var tex: Texture2D = null
	var hf := 1
	var vf := 1
	var frame := 0
	var region := Rect2()
	if spr is Sprite2D:
		var src := spr as Sprite2D
		tex = src.texture
		hf = maxi(1, src.hframes)
		vf = maxi(1, src.vframes)
		frame = src.frame
		if src.region_enabled:
			region = src.region_rect
	elif spr is AnimatedSprite2D:
		var src := spr as AnimatedSprite2D
		if src.sprite_frames != null and src.sprite_frames.has_animation(src.animation) \
				and src.sprite_frames.get_frame_count(src.animation) > src.frame:
			tex = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if tex == null:
		return {"size": Vector2.ZERO, "used": Rect2i(), "ratio": 1.0}
	# AtlasTexture regions share their backing texture's RID. Resource identity
	# distinguishes those cells; region/margin also cover a retargeted atlas view.
	var atlas_view := ""
	if tex is AtlasTexture:
		atlas_view = "%s/%s" % [(tex as AtlasTexture).region, (tex as AtlasTexture).margin]
	var flipped := bool(spr.get("flip_v"))
	var key := "%s/%s/%d/%d/%d/%s/%s/%s/%s" % [tex.get_instance_id(),
		tex.get_rid().get_id(), hf, vf, frame, region, atlas_view, flipped, trunk]
	if _shape_cache.has(key):
		return _shape_cache[key]
	var img: Image = tex.get_image()
	if img == null:
		return {"size": tex.get_size() / Vector2(hf, vf), "used": Rect2i(), "ratio": 1.0}
	if tex is AtlasTexture and (tex as AtlasTexture).margin != Rect2():
		# get_image returns the cropped atlas region; drawing also includes the
		# atlas margin. Measure in that same padded local coordinate system.
		var padded := Image.create(tex.get_width(), tex.get_height(), false, img.get_format())
		padded.fill(Color.TRANSPARENT)
		padded.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i((tex as AtlasTexture).margin.position))
		img = padded
	if region.size.x > 0.0 and region.size.y > 0.0:
		img = img.get_region(Rect2i(region))
	var cell_size := Vector2i(img.get_width() / hf, img.get_height() / vf)
	if hf > 1 or vf > 1:
		img = img.get_region(Rect2i(Vector2i(frame % hf, frame / hf) * cell_size, cell_size))
	var used: Rect2i = img.get_used_rect()
	var base := used
	var ratio := 1.0
	if used.size.x > 0 and used.size.y > 2:
		# A perspective base occupies several rows: the very lowest edge alone
		# mistakes a rock corner or the last stone in a group for a tree trunk.
		var band_h := maxi(2, int(used.size.y * Balance.CAST_SHADOW_FOOT_BAND))
		var band_y: int = used.position.y if flipped else used.end.y - band_h
		var band := Rect2i(used.position.x, band_y, used.size.x, band_h)
		var width: int = img.get_region(band).get_used_rect().size.x
		ratio = float(width) / float(used.size.x)
	if trunk and used.size.x > 0 and used.size.y > 2:
		var root_h := maxi(1, int(used.size.y * Balance.TREE_SHADOW_FOOT_BAND))
		var root_band := Rect2i(used.position.x,
			used.position.y if flipped else used.end.y - root_h, used.size.x, root_h)
		base = _opaque_rect(img, root_band)
	var result := {"size": Vector2(cell_size), "used": used, "ratio": ratio}
	if trunk:
		result["base"] = base
	_shape_cache[key] = result
	return result


## Bounds of the clearly painted pixels inside `area`, in image coordinates.
## get_used_rect counts any alpha above zero, so a near-invisible export
## fringe (tree_green4 carries alpha-1 specks right of its roots) would widen
## the trunk span and slide its contact off the trunk. The native used rect
## bounds the scan; only its faint edge columns and rows are walked inward.
static func _opaque_rect(img: Image, area: Rect2i) -> Rect2i:
	var band := img.get_region(area)
	var used := band.get_used_rect()
	if not used.has_area():
		return Rect2i(area.position, Vector2i.ZERO)
	if band.is_compressed():
		band.decompress()
	band.convert(Image.FORMAT_RGBA8)
	var data := band.get_data()
	var stride := band.get_width() * 4
	var cut := int(Balance.TREE_SHADOW_ALPHA_MIN * 255.0)
	var x0 := used.position.x
	var x1 := used.end.x - 1
	var y0 := used.position.y
	var y1 := used.end.y - 1
	while x0 <= x1 and not _opaque_column(data, stride, x0, y0, y1, cut):
		x0 += 1
	if x0 > x1:
		# Only faint pixels: keep the plain bounds rather than lose the contact.
		return Rect2i(area.position + used.position, used.size)
	while not _opaque_column(data, stride, x1, y0, y1, cut):
		x1 -= 1
	while not _opaque_row(data, stride, y0, x0, x1, cut):
		y0 += 1
	while not _opaque_row(data, stride, y1, x0, x1, cut):
		y1 -= 1
	return Rect2i(area.position + Vector2i(x0, y0), Vector2i(x1 - x0 + 1, y1 - y0 + 1))


static func _opaque_column(data: PackedByteArray, stride: int, x: int, y0: int, y1: int, cut: int) -> bool:
	for y in range(y0, y1 + 1):
		if data[y * stride + x * 4 + 3] > cut:
			return true
	return false


static func _opaque_row(data: PackedByteArray, stride: int, y: int, x0: int, x1: int, cut: int) -> bool:
	for x in range(x0, x1 + 1):
		if data[y * stride + x * 4 + 3] > cut:
			return true
	return false


static func foot(spr: Node2D, geometry: Dictionary) -> Vector2:
	var size: Vector2 = geometry["size"]
	var used: Rect2i = geometry["used"]
	var at := Vector2(used.position.x + used.size.x * 0.5, used.end.y)
	if bool(spr.get("flip_h")):
		at.x = size.x - at.x
	if bool(spr.get("flip_v")):
		at.y = size.y - used.position.y
	if bool(spr.get("centered")):
		at -= size * 0.5
	return at + Vector2(spr.get("offset"))


static func attach(body: Node2D, spr: Node2D, base_y_override := NAN, trunk := false) -> void:
	if Balance.CAST_SHADOW_A <= 0.0 or not (spr is Sprite2D or spr is AnimatedSprite2D):
		return
	var cast: Node2D = AnimatedSprite2D.new() if spr is AnimatedSprite2D and not trunk else Sprite2D.new()
	cast.set_meta("cast_shadow", true)
	if trunk:
		cast.set_meta("cast_shadow_mode", "trunk")
	# Always beneath its own source: a sunken composite part (z < 0) would
	# otherwise tie with its copy, and y-sort draws the lower copy on top.
	cast.z_index = mini(-1, spr.z_index - 1)
	body.add_child(cast)
	body.move_child(cast, 0)
	_sync(cast, spr, base_y_override)
	# Both sprite kinds can change frames. Shape caching is keyed by cell,
	# so a padded animation or a vertical strip cannot borrow another's feet.
	# Resolve weak node references inside the callback. A raw freed lambda
	# capture is rejected by Godot before an is_instance_valid guard can run.
	var cast_ref: WeakRef = weakref(cast)
	var source_ref: WeakRef = weakref(spr)
	# A fresh closure distinguishes this cast from an earlier retired cast's
	# connection; binding the static helper alone did not distinguish them.
	var sync: Callable = func() -> void:
		_sync_if_alive(cast_ref, source_ref, base_y_override)
	spr.connect("frame_changed", sync)
	if spr is AnimatedSprite2D:
		spr.connect("animation_changed", sync)


static func _sync_if_alive(cast_ref: WeakRef, source_ref: WeakRef, base_y_override: float) -> void:
	var cast := cast_ref.get_ref() as Node2D
	var source := source_ref.get_ref() as Node2D
	if cast != null and source != null:
		_sync(cast, source, base_y_override)


static func _sync(cast: Node2D, spr: Node2D, base_y_override: float) -> void:
	if cast.get_meta("cast_shadow_mode", "") == "trunk":
		_sync_trunk(cast as Sprite2D, spr, base_y_override)
		return
	if spr is Sprite2D:
		var source := spr as Sprite2D
		var target := cast as Sprite2D
		target.texture = source.texture
		target.hframes = source.hframes
		target.vframes = source.vframes
		target.frame = source.frame
		target.region_enabled = source.region_enabled
		target.region_rect = source.region_rect
		target.region_filter_clip_enabled = source.region_filter_clip_enabled
	else:
		var source := spr as AnimatedSprite2D
		var target := cast as AnimatedSprite2D
		target.sprite_frames = source.sprite_frames
		target.animation = source.animation
		target.frame = source.frame
	for property in ["centered", "offset", "flip_h", "flip_v", "texture_filter", "texture_repeat"]:
		cast.set(property, spr.get(property))
	cast.material = spr.material
	var geometry := shape(spr)
	var used: Rect2i = geometry["used"]
	var height: float = used.size.y * spr.transform.y.length()
	cast.visible = spr.visible and height >= Balance.CAST_SHADOW_HUG_MIN_H
	var projected: bool = height >= Balance.CAST_SHADOW_MIN_H \
		and float(geometry["ratio"]) < Balance.CAST_SHADOW_STAND_RATIO
	# The old single ellipse sits below the center of a diagonal group or log,
	# detached from its painted feet. A broad contact copy already grounds the
	# whole footprint; keep the ellipse for trunks and the no-cast fallback.
	for child in cast.get_parent().get_children():
		if child is CanvasItem and child.has_meta("prop_contact_shadow"):
			child.visible = spr.visible and (not cast.visible or projected)
	if not cast.visible:
		return
	var opacity: float = Balance.CAST_SHADOW_A * spr.modulate.a * spr.self_modulate.a
	if projected:
		# Keep the actual source basis, including negative scale and its seeded
		# lean. Position this transformed copy by a painted foot point, rather
		# than the bottom of the export canvas or an unrotated offset estimate.
		var ground := foot(spr, geometry)
		var anchor: Vector2 = spr.transform * ground
		if not is_nan(base_y_override):
			anchor.y = base_y_override
		var projection := Transform2D(spr.transform.x,
			-spr.transform.y.rotated(-Balance.CAST_SHADOW_SKEW) * Balance.CAST_SHADOW_SQUASH,
			Vector2.ZERO)
		projection.origin = anchor - projection.basis_xform(ground)
		cast.transform = projection
	else:
		var off := clampf(height * Balance.CAST_SHADOW_HUG_OFFSET_SCALE,
			Balance.CAST_SHADOW_HUG_OFFSET_MIN, Balance.CAST_SHADOW_HUG_OFFSET_MAX)
		cast.transform = spr.transform
		cast.position += Vector2(off, off * 0.75)
		opacity *= 0.9
	cast.modulate = Color(0, 0, 0, opacity)
	cast.set_meta("cast_shadow_mode", "projected" if projected else "hug")


static func _sync_trunk(cast: Sprite2D, spr: Node2D, base_y_override: float) -> void:
	var geometry := shape(spr, true)
	var used: Rect2i = geometry["used"]
	var base: Rect2i = geometry.get("base", used)
	var canopy_w := used.size.x * spr.transform.x.length()
	var width := clampf(minf(base.size.x * spr.transform.x.length() * Balance.TREE_SHADOW_WIDTH_SCALE,
		canopy_w * Balance.TREE_SHADOW_CANOPY_FRACTION),
		Balance.TREE_SHADOW_WIDTH_MIN, Balance.TREE_SHADOW_WIDTH_MAX)
	# Use the lower painted band's centre, including source offset/mirroring.
	# The soft ellipse stays on the ground while the authored canopy sways.
	var ground := foot(spr, {"size": geometry["size"], "used": base})
	cast.position = spr.transform * ground
	if not is_nan(base_y_override):
		cast.position.y = base_y_override
	cast.texture = Art.tex("shadow")
	cast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cast.scale = Vector2(width, width * Balance.TREE_SHADOW_DEPTH) / cast.texture.get_size()
	cast.visible = spr.visible and used.has_area()
	cast.modulate.a = spr.modulate.a * spr.self_modulate.a
	for child in cast.get_parent().get_children():
		if child is CanvasItem and child.has_meta("prop_contact_shadow"):
			child.visible = false
