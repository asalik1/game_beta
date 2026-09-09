extends RefCounted
## Scenery shadows use the painted footprint, including frame padding and pose.
## Wide bases keep a close contact rim; only narrow trunks project a figure.
static var _shape_cache: Dictionary = {}


static func shape(spr: Node2D) -> Dictionary:
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
	var key := "%s/%s/%d/%d/%d/%s/%s/%s" % [tex.get_instance_id(),
		tex.get_rid().get_id(), hf, vf, frame, region, atlas_view, flipped]
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
	var ratio := 1.0
	if used.size.x > 0 and used.size.y > 2:
		# A perspective base occupies several rows: the very lowest edge alone
		# mistakes a rock corner or the last stone in a group for a tree trunk.
		var band_h := maxi(2, int(used.size.y * Balance.CAST_SHADOW_FOOT_BAND))
		var band_y: int = used.position.y if flipped else used.end.y - band_h
		var band := Rect2i(used.position.x, band_y, used.size.x, band_h)
		var width: int = img.get_region(band).get_used_rect().size.x
		ratio = float(width) / float(used.size.x)
	var result := {"size": Vector2(cell_size), "used": used, "ratio": ratio}
	_shape_cache[key] = result
	return result


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


static func attach(body: Node2D, spr: Node2D, base_y_override := NAN) -> void:
	if Balance.CAST_SHADOW_A <= 0.0 or not (spr is Sprite2D or spr is AnimatedSprite2D):
		return
	var cast: Node2D = AnimatedSprite2D.new() if spr is AnimatedSprite2D else Sprite2D.new()
	cast.set_meta("cast_shadow", true)
	cast.z_index = -1
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
