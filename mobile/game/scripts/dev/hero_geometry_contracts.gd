extends RefCounted
## After-only diagnostic module; temporary textures/cache entries are removed.
const Work := preload("res://scripts/dev/hero_measure_probe.gd")


static func run(rig) -> void:
	var image: Image = Image.create(40, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(3, 4, 9, 15), Color.WHITE)
	image.fill_rect(Rect2i(24, 7, 10, 8), Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(image)
	var key: int = tex.get_instance_id()
	var base: String = "__qa_hero_geometry_%d" % key
	var info: Dictionary = {"tex": tex, "frames": 2, "frame_size": Vector2i(20, 24), "fps": 6.0}
	var rect := Rect2i(0, 0, 20, 24)
	var expected: Rect2i = image.get_region(rect).get_used_rect()
	rig._check("cache/external_descriptor_direct_fallback", Art.hero_frame_bounds(info, rect).is_empty())
	# This descriptor enters through the real previously-loaded strip branch,
	# with no asset writes and no clearing of existing Art caches.
	Art._anim_cache[base] = info
	Art._strip_info(base)
	rig._check("cache/nonhero_request_does_not_scan", Art.hero_frame_bounds(info, rect).is_empty())
	_begin(rig, "cache_contract/lazy_first_hero")
	Art._strip_info(base, true)
	var lazy: Dictionary = _end(rig)
	rig._check("cache/lazy_exact_bounds", Art.hero_frame_bounds(info, rect).get("used") == expected)
	_begin(rig, "cache_contract/repeated_hero_and_copied_descriptor")
	Art._strip_info(base, true)
	var copy: Dictionary = info.duplicate()
	copy["fps"] = 22.0
	copy["render_scale"] = 9.0
	var returned: Dictionary = Art.hero_frame_bounds(copy, rect)
	var repeated: Dictionary = _end(rig)
	rig._check("cache/caller_fields_do_not_change_raw", returned.get("used") == expected
		and info["fps"] == 6.0 and not info.has("render_scale"))
	returned["used"] = Rect2i()
	rig._check("cache/returned_dictionary_cannot_mutate_cache", Art.hero_frame_bounds(info, rect).get("used") == expected)
	var other_rect := Rect2i(20, 0, 20, 24)
	_begin(rig, "cache_contract/new_exact_rect")
	var other: Dictionary = Art.hero_frame_bounds(info, other_rect)
	var miss: Dictionary = _end(rig)
	rig._check("cache/exact_rect_not_aliased", other.get("used") == image.get_region(other_rect).get_used_rect()
		and other.get("used") != expected)
	var mutable_rect := rect
	mutable_rect.position.x = 20
	var mutable_used: Rect2i = Art.hero_frame_bounds(info, rect)["used"]
	mutable_used.position.x += 100
	rig._check("cache/rect_values_do_not_mutate_stored_keys", rect == Rect2i(0, 0, 20, 24)
		and Art.hero_frame_bounds(info, rect).get("used") == expected
		and Art.hero_frame_bounds(info, mutable_rect) == other)
	var left := AtlasTexture.new()
	left.atlas = tex
	left.region = Rect2(0, 0, 20, 24)
	var right := AtlasTexture.new()
	right.atlas = tex
	right.region = Rect2(20, 0, 20, 24)
	for atlas in [left, right]:
		var external: Dictionary = {"tex": atlas, "frames": 1, "frame_size": Vector2i(20, 24)}
		rig._check("cache/atlas_identity_fallback_%d" % atlas.get_instance_id(), Art.hero_frame_bounds(external, rect).is_empty())
	left.region = right.region
	rig._check("cache/atlas_region_mutation_stays_direct", Art.hero_frame_bounds({"tex": left}, rect).is_empty())
	var replacement: ImageTexture = ImageTexture.create_from_image(image)
	rig._check("cache/equal_size_replacement_stays_direct", Art.hero_frame_bounds({"tex": replacement}, rect).is_empty())
	var duplicated: Texture2D = tex.duplicate() as Texture2D
	rig._check("cache/resource_duplicate_does_not_inherit_source_identity", duplicated != null
		and Art.hero_frame_bounds({"tex": duplicated}, rect).is_empty())
	var record: Dictionary = tex.get_meta(Art.HERO_GEOMETRY_META)
	var retains_image: bool = false
	for value in record.values():
		if value is Image:
			retains_image = true
	rig._check("cache/raw_record_has_no_image_or_caller_fields", not retains_image
		and not record.has("fps") and not record.has("render_scale") and not record.has("render_offset"))
	if rig.work_counters:
		rig._check("cache/lazy_native_work_once", _count(lazy, "art.hero_lazy", "readbacks") == 1
			and _count(lazy, "art.hero_seed", "scans") == 1)
		rig._check("cache/repeat_no_native_geometry_work", repeated.get("by_site", {}).is_empty())
		rig._check("cache/new_rect_native_work_once", _count(miss, "art.hero_rect", "readbacks") == 1
			and _count(miss, "art.hero_rect", "scans") == 1)
	var edited: Image = image.duplicate()
	edited.fill_rect(rect, Color.TRANSPARENT)
	edited.fill_rect(Rect2i(7, 2, 3, 8), Color.WHITE)
	for method in ["update", "set_image"]:
		var next_image: Image = edited if method == "update" else image
		tex.call(method, next_image)
		rig._check("cache/" + method + "_invalidates_same_size_pixels", Art.hero_frame_bounds(info, rect).is_empty())
		_begin(rig, "cache_contract/" + method + "_refresh")
		Art._strip_info(base, true)
		var refreshed: Dictionary = _end(rig)
		rig._check("cache/" + method + "_fresh_bounds", Art.hero_frame_bounds(info, rect).get("used")
			== next_image.get_region(rect).get_used_rect())
		if rig.work_counters:
			rig._check("cache/" + method + "_one_refresh", _count(refreshed, "art.hero_lazy", "readbacks") == 1
				and _count(refreshed, "art.hero_seed", "scans") == 1)
	# Drop every real source owner; metadata and its signal must not retain it.
	var released: WeakRef = weakref(tex)
	Art._anim_cache.erase(base)
	left.atlas = null
	right.atlas = null
	info.clear()
	copy.clear()
	tex = null
	rig._check("cache/metadata_does_not_retain_retired_texture", released.get_ref() == null)
	rig._check("cache/fixture_entries_removed", not Art._anim_cache.has(base))


static func _begin(rig, label: String) -> void:
	if rig.work_counters:
		rig._check(label + "/phase_available", Work.begin_phase(label))


static func _end(rig) -> Dictionary:
	if not rig.work_counters:
		return {}
	var result: Dictionary = Work.finish_phase()
	rig.work_phases.append(result)
	return result


static func _count(phase: Dictionary, site: String, field: String) -> int:
	var rows: Dictionary = phase.get("by_site", {})
	var values: Dictionary = rows.get(site, {})
	return int(values.get(field, 0))
