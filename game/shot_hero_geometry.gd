extends ShotRig
## Candidate: publish beside its scene in game/ only after the source freeze.
## shot.bat hero_geometry --timeout=420 [--compare=<observations.json>] [--work-counters]
## One real Game; shared no_saves/mute/watchdog. Six BASE classes only.
## Class timings are real local Player.set_class calls, not whole boot.
## Image reference scans, detached call probes and captures are outside them.

const CLASSES := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]
const CAPTURE_CLASSES := ["warrior", "mage", "assassin"]
const Work := preload("res://scripts/dev/hero_measure_probe.gd")

# Counts actual virtual method entries in unchanged production code. This is
# a detached apply-class probe, NOT instrumentation of the live Player or of
# Texture2D.get_image. Future caching may retain these entries but skip reads.
class CountingPlayer extends Player:
	var measurement_calls := 0

	func _measure_hero_frame(info: Dictionary, size_mult := 1.0) -> Dictionary:
		measurement_calls += 1
		return super._measure_hero_frame(info, size_mult)

var checks: Array[Dictionary] = []
var timings: Array[Dictionary] = []
var class_rows: Array[Dictionary] = []
var preview_rows: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var stable: Dictionary = {"classes": {}, "previews": {}}
var failure_count := 0
var reference_reads := 0
var reference_scans := 0
var reference_geometry: Dictionary = {}
var origin := Vector2.ZERO
var work_counters := false
var work_phases: Array[Dictionary] = []


func _ready() -> void:
	# Refuse an ordinary profile before Game can initialize persistent state.
	var profile: String = OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not profile.contains("/build/qa/"):
		push_error("HERO GEOMETRY requires a fresh isolated profile under build/qa")
		finish(1)
		return
	work_counters = flag("work-counters")
	seed(903126)
	await boot("warrior", "ch1", false)
	game.play_started = true
	game.menus.close()
	game.wander_seed = 903126
	seed(903126)
	game.switch_chapter("ch1", true)
	await skip_dialogue()
	game.request_pause(false)
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	game.camera.position_smoothing_enabled = false
	origin = game.room_center(game.cur_room)
	game.player.global_position = origin
	game.camera.global_position = origin
	await frames(6)
	_check("isolated_muted_boot", game.no_saves and AudioServer.is_bus_mute(0))
	if not await _settle_reveal():
		_write_report(false)
		finish(1)
		return
	await RenderingServer.frame_post_draw
	shot("00_actual_warrior_world", "real boot before controlled poses; warrior cache already warm")
	# Freeze only the local simulation for inspection. This is a synthetic
	# render fixture, not ordinary combat input or a movement playtest.
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.request_pause(true)
	hide_hud()
	game.camera.zoom = Vector2(1.5, 1.5)
	for id in CLASSES:
		await _class_case(String(id))
	await _preview_cases()
	_paper_doll_cases()
	_synthetic_geometry_cases()
	preload("res://scripts/dev/hero_geometry_contracts.gd").run(self)
	if work_counters:
		for site in ["player.measure", "menu.preview", "art.override"]:
			_check("instrumentation_site_present/" + site, Work.sites.has(site))
	else:
		_check("uninstrumented_timing_source", Work.sites.is_empty(), Work.sites)
	_compare_previous()
	_check("master_still_muted", AudioServer.is_bus_mute(0))
	_write_report(true)
	print("HERO GEOMETRY: %d checks, %d failures; independent phases, no boot attribution" % [checks.size(), failure_count])
	finish(1 if failure_count > 0 else 0)


func _class_case(id: String) -> void:
	step("class applications " + id)
	var p: Player = game.player
	var before := _cache_snapshot()
	var shared_before := _shared_headers()
	_begin_work(id + "/set_class_first")
	var start := Time.get_ticks_usec()
	p.set_class(id)
	_timing(id + "/set_class_first", start, "real local Player; shared caches retain earlier classes and boot")
	var first := _render_snapshot(p)
	var identities := _descriptor_identities(p)
	var after_first := _cache_snapshot()
	_begin_work(id + "/set_class_repeat")
	start = Time.get_ticks_usec()
	p.set_class(id)
	_timing(id + "/set_class_repeat", start, "immediate same-class call; before reference scans or detached probe")
	var repeated := _render_snapshot(p)
	var after_repeat := _cache_snapshot()
	_check(id + "/repeated_exact_render_metadata", first == repeated)
	_check(id + "/repeated_texture_identity", identities == _descriptor_identities(p))
	_check(id + "/repeat_no_new_art_descriptors", after_first == after_repeat)
	_check(id + "/existing_shared_headers_unchanged", _headers_retained(shared_before))
	var rows := _entries(p)
	var mismatches: Array[String] = []
	var geometry: Dictionary = {}
	for label in rows:
		var entry: Dictionary = rows[label]
		var info: Dictionary = entry.info
		var tex := info.tex as Texture2D
		var fw := int(tex.get_width() / maxi(1, int(info.frames)))
		var raw := _raw_frame(tex, Rect2i(0, 0, fw, tex.get_height()))
		var body_h := maxi(1, int(raw.used_size[1]) - 1)
		var bot := int(raw.used_end[1]) - 1
		# Preserve current operation order and the gameplay "-1" convention.
		var scale_value: float = Player.HERO_TARGET_BODY * float(Balance.HERO_CLASS_SIZE.get(id, 1.0)) * Balance.CHAR_RENDER_SCALE / float(body_h)
		var offset_value: float = Player.HERO_FEET_ANCHOR / scale_value - float(bot) + float(tex.get_height()) / 2.0
		var actual: Dictionary = repeated.clips[label]
		if float(actual.render_scale) != scale_value or float(actual.render_offset) != offset_value:
			mismatches.append(String(label))
		geometry[label] = {"raw_frame_zero": raw, "legacy_body_height": body_h, "legacy_bottom_row": bot,
			"legacy_scale": scale_value, "legacy_offset": offset_value,
			"computed_foot_y": (float(bot) + offset_value - float(tex.get_height()) / 2.0) * scale_value}
	_check(id + "/exact_legacy_geometry", mismatches.is_empty(), mismatches)
	_check(id + "/has_flat_and_directional_clips", not p._clips.is_empty() and not p._dir_loco.is_empty())
	var probe := CountingPlayer.new()
	probe.game = game
	probe.cls = id
	probe.skin = ""
	probe.sprite = Sprite2D.new()
	probe.add_child(probe.sprite)
	probe._apply_class_sprite()
	var probe_first := probe.measurement_calls
	probe.measurement_calls = 0
	probe._apply_class_sprite()
	var probe_repeat := probe.measurement_calls
	_check(id + "/detached_probe_matches_live", _render_snapshot(probe) == repeated)
	_check(id + "/detached_measurement_entry_count", probe_first == rows.size() and probe_repeat == rows.size(),
		{"first": probe_first, "repeat": probe_repeat, "descriptors": rows.size()})
	probe.free()  # detached ownership includes its Sprite2D; never enters tree
	class_rows.append({"class": id, "cache_before": before, "cache_after_first": after_first,
		"cache_after_repeat": after_repeat, "descriptor_count": rows.size(),
		"texture_instances_within_run": identities, "detached_measurement_entries_first": probe_first,
		"detached_measurement_entries_repeat": probe_repeat, "geometry": geometry})
	stable.classes[id] = {"render": repeated, "geometry": geometry}
	_write_report(false)
	if id in CAPTURE_CLASSES:
		await _world_pose(id, "idle", 0)
		await _world_pose(id, "attack", 3)


func _entries(p: Player) -> Dictionary:
	var result: Dictionary = {}
	for name in p._clips:
		result["flat/" + String(name)] = {"info": p._clips[name], "meta": p._clips[name]}
	for name in p._dir_loco:
		for direction in p._dir_loco[name]:
			result["direction/" + String(name) + "/" + String(direction)] = {
				"info": p._dir_loco[name][direction], "meta": p._dir_loco[name][direction]}
	for name in p._dir_clips:
		result["pose/" + String(name)] = {"info": p._dir_clips[name],
			"meta": {"render_scale": p._dir_meta[name].scale, "render_offset": p._dir_meta[name].offset}}
	return result


func _render_snapshot(p: Player) -> Dictionary:
	var clips: Dictionary = {}
	var entries := _entries(p)
	var source_names: Dictionary = {}
	for base in Art._anim_cache:
		var cached: Dictionary = Art._anim_cache[base]
		if cached.is_empty():
			continue
		var texture_id: int = (cached.tex as Texture2D).get_instance_id()
		if not source_names.has(texture_id):
			source_names[texture_id] = []
		source_names[texture_id].append(String(base))
	for label in entries:
		var entry: Dictionary = entries[label]
		var info: Dictionary = entry.info
		var tex := info.tex as Texture2D
		var bases: Array = source_names.get(tex.get_instance_id(), []).duplicate()
		bases.sort()
		clips[label] = {"frames": int(info.frames), "fps": float(info.fps),
			"source_strip_bases": bases,
			"texture_size": [tex.get_width(), tex.get_height()],
			"frame_size": _v2(Vector2(info.get("frame_size", Vector2i(tex.get_height(), tex.get_height())))),
			"render_scale": float(entry.meta.render_scale), "render_offset": float(entry.meta.render_offset)}
	return {"class": p.cls, "skin": p.skin, "hero_scale": p._hero_scale,
		"hero_offset_y": p._hero_offset_y, "face_left": p.face_left, "clips": clips}


func _descriptor_identities(p: Player) -> Dictionary:
	var result: Dictionary = {}
	var entries := _entries(p)
	for label in entries:
		var info: Dictionary = entries[label].info
		result[label] = (info.tex as Texture2D).get_instance_id()
	return result


func _cache_snapshot() -> Dictionary:
	var textures: Dictionary = {}
	var loaded := 0
	var misses := 0
	for base in Art._anim_cache:
		var info: Dictionary = Art._anim_cache[base]
		if info.is_empty():
			misses += 1
		else:
			loaded += 1
			textures[(info.tex as Texture2D).get_instance_id()] = true
	return {"strip_cache_entries": Art._anim_cache.size(), "loaded_strip_descriptors": loaded,
		"cached_misses": misses, "unique_strip_texture_instances": textures.size(),
		"direction_set_cache_entries": Art._dir_cache.size()}


func _shared_headers() -> Dictionary:
	var result: Dictionary = {}
	for base in Art._anim_cache:
		var info: Dictionary = Art._anim_cache[base]
		if not info.is_empty():
			result[base] = {"tex": (info.tex as Texture2D).get_instance_id(),
				"frames": info.frames, "fps": info.fps, "frame_size": info.get("frame_size"),
				"has_render_scale": info.has("render_scale"), "has_render_offset": info.has("render_offset")}
	return result


func _headers_retained(before: Dictionary) -> bool:
	var after := _shared_headers()
	for base in before:
		if not after.has(base) or before[base] != after[base]:
			return false
	return true


func _raw_frame(tex: Texture2D, rect: Rect2i) -> Dictionary:
	# Diagnostic-only reuse: never alters Art/Player caches. Key by object
	# identity and exact rect, not backing RID (atlas wrappers may share it).
	var key := "%d/%s" % [tex.get_instance_id(), rect]
	if reference_geometry.has(key):
		return reference_geometry[key]
	reference_reads += 1
	var image := tex.get_image()
	if image == null:
		_check("reference_image_available/" + key, false)
		return {"used_position": [0, 0], "used_size": [0, 0], "used_end": [0, 0],
			"frame_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	var used := image.get_region(rect).get_used_rect()
	reference_scans += 1
	var row := {"used_position": [used.position.x, used.position.y], "used_size": [used.size.x, used.size.y],
		"used_end": [used.end.x, used.end.y], "frame_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	reference_geometry[key] = row
	return row


func _world_pose(id: String, clip: String, requested_frame: int) -> void:
	step("controlled world pose " + id + "/" + clip)
	var p: Player = game.player
	p.global_position = origin
	p.sprite.position = Vector2.ZERO
	p.action_face_hint = Vector2.RIGHT
	p._play_clip(clip, clip == "idle")
	p.action_face_hint = Vector2.ZERO
	p.sprite.frame = mini(requested_frame, maxi(0, p.sprite.hframes - 1))
	# The paused world cannot tick its CastShadow follower. Synchronize via
	# its unchanged production method after this explicitly synthetic pose.
	for child in p.get_children():
		if child is Sprite2D and child.has_meta("cast_shadow") and child.has_method("_sync"):
			child.call("_sync")
			_check(id + "/" + clip + "/cast_follows_pose",
				(child as Sprite2D).texture == p.sprite.texture and (child as Sprite2D).frame == p.sprite.frame)
	game.camera.global_position = origin
	await frames(4)
	var label := "%s_world_%s_f%d" % [id, clip, p.sprite.frame]
	var row := {"class": id, "clip": clip, "frame": p.sprite.frame,
		"synthetic_setup": "real _play_clip, fixed frame and production cast _sync; Player process/physics disabled; no ability cast",
		"sprite_scale": _v2(p.sprite.scale), "sprite_offset": _v2(p.sprite.offset),
		"sprite_position": _v2(p.sprite.position), "hframes": p.sprite.hframes}
	await _capture(label, _canvas_rect(p.sprite), row)


func _preview_cases() -> void:
	step("real class model preview geometry")
	game.camera.zoom = Vector2.ONE
	game.hud.visible = true
	_begin_work("preview/open_class_select")
	var menu_start: int = Time.get_ticks_usec()
	game.menus.open_class_select()
	_timing("preview/open_class_select", menu_start, "menu construction plus automatic initial preview")
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(5, 5)
	pointer.global_position = pointer.position
	Input.parse_input_event(pointer)
	Input.flush_buffered_events()
	await frames(5)
	for id in CLASSES:
		_begin_work(String(id) + "/preview/select_class")
		menu_start = Time.get_ticks_usec()
		game.menus._cs_preview(String(id))
		game.menus._cs_set_mode("model")
		_timing(String(id) + "/preview/select_class", menu_start, "automatic initial model/idle work; before named clip timings")
		var clips: Dictionary = game.menus._cs_clips
		var rows: Dictionary = {}
		for name in clips:
			var info: Dictionary = clips[name]
			var tex := info.tex as Texture2D
			var size := Vector2(info.get("frame_size", Vector2i(tex.get_height(), tex.get_height())))
			var count_before: int = game.menus._cs_body_cache.size()
			_begin_work(String(id) + "/preview/" + String(name) + "/first")
			var start := Time.get_ticks_usec()
			game.menus._cs_play_clip(String(name), true)
			_timing(String(id) + "/preview/" + String(name) + "/first", start,
				"model setup including SpriteFrames/AtlasTexture; geometry cache may already contain this clip")
			var model: AnimatedSprite2D = game.menus._cs_model
			model.stop()
			var first := {"scale": _v2(model.scale), "position": _v2(model.position)}
			var count_after: int = game.menus._cs_body_cache.size()
			_begin_work(String(id) + "/preview/" + String(name) + "/repeat")
			start = Time.get_ticks_usec()
			game.menus._cs_play_clip(String(name), true)
			_timing(String(id) + "/preview/" + String(name) + "/repeat", start, "immediate repeat; same Menus instance")
			model.stop()
			var raw := _raw_frame(tex, Rect2i(0, 0, int(size.x), int(size.y)))
			var body_h := size.y
			var bot := size.y
			if int(raw.used_size[1]) > 0:
				body_h = float(raw.used_size[1])
				bot = float(raw.used_end[1])
			var expected_scale := minf(3.0, Menus.CS_MODEL_BODY_H / maxf(1.0, body_h))
			var expected_position := Vector2(Menus.CS_STAGE.size.x * 0.5,
				Menus.CS_STAGE.size.y - 60.0 - (bot - size.y * 0.5) * expected_scale)
			_check(String(id) + "/preview/" + String(name), model.scale == Vector2(expected_scale, expected_scale)
				and model.position == expected_position and first == {"scale": _v2(model.scale), "position": _v2(model.position)})
			rows[name] = {"raw_frame_zero": raw, "body_height_without_minus_one": body_h,
				"bottom_exclusive": bot, "scale": _v2(model.scale), "position": _v2(model.position),
				"frames": int(info.frames), "fps": float(info.fps)}
			preview_rows.append({"class": id, "clip": name, "body_cache_before": count_before,
				"body_cache_after": count_after, "body_cache_after_repeat": game.menus._cs_body_cache.size()})
			if id in CAPTURE_CLASSES and name in ["idle", "attack"]:
				model.frame = 0
				await frames(3)
				var frame_texture := model.sprite_frames.get_frame_texture(model.animation, model.frame) as AtlasTexture
				_check(String(id) + "/preview/" + String(name) + "/visible_model",
					model.visible and model.frame == 0 and not model.is_playing()
					and not game.menus._cs_video.visible and frame_texture != null
					and frame_texture.atlas == tex and frame_texture.region == Rect2(0, 0, size.x, size.y))
				await _capture(String(id) + "_preview_" + String(name), game.menus._cs_stage.get_global_rect(),
					{"class": id, "clip": name, "synthetic_setup": "real model path forced instead of recorded ability video; stopped at frame zero"})
		stable.previews[id] = rows
		_write_report(false)


func _canvas_rect(sprite: Sprite2D) -> Rect2:
	var rect := sprite.get_rect()
	var transform := sprite.get_global_transform_with_canvas()
	var result := Rect2(transform * rect.position, Vector2.ZERO)
	for point in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		result = result.expand(transform * point)
	return result.grow(48.0)  # native surrounding ground/shadow, no resampling


func _capture(label: String, bounds: Rect2, row: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	row["fullframe"] = shot(label, String(row.get("synthetic_setup", "")))
	var image := capture_image()
	var crop := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_check(label + "/native_crop", crop.has_area())
	if crop.has_area():
		var path := ProjectSettings.globalize_path(shot_dir.path_join(label + "_close.png"))
		image.get_region(crop).save_png(path)
		row["native_closeup"] = path
		row["crop_rect"] = [crop.position.x, crop.position.y, crop.size.x, crop.size.y]
	row["process_frame"] = Engine.get_process_frames()
	captures.append(row)


func _v2(value: Vector2) -> Array:
	return [value.x, value.y]


func _timing(label: String, start: int, scope: String) -> void:
	var elapsed := Time.get_ticks_usec() - start
	if work_counters:
		work_phases.append(Work.finish_phase())
	timings.append({"name": label, "elapsed_us": elapsed, "scope": scope,
		"instrumentation_perturbed": work_counters})
	print("HERO TIMING: %s %.3f ms (%s)" % [label, elapsed / 1000.0, scope])


func _begin_work(label: String) -> void:
	if work_counters:
		_check("work_phase_not_nested/" + label, Work.begin_phase(label))


func _settle_reveal() -> bool:
	var deadline: int = Time.get_ticks_msec() + 12000
	var settled: int = 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var pending: bool = game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active
		for child in game.hud.get_children():
			if child is Cutscene:
				pending = true
		pending = pending or (is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible)
		pending = pending or game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01
		settled = 0 if pending else settled + 1
		if settled >= 3:
			break
	_check("actual_boot_reveal_settled", settled >= 3)
	return settled >= 3


func _synthetic_geometry_cases() -> void:
	# Tiny diagnostic textures exercise empty/padded/rectangular/atlas keys.
	# No hero pixels are generated, changed, or written to disk.
	var image: Image = Image.create(40, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(3, 4, 9, 15), Color.WHITE)
	image.fill_rect(Rect2i(24, 7, 10, 8), Color.WHITE)
	var backing: ImageTexture = ImageTexture.create_from_image(image)
	var empty: Image = Image.create(20, 24, false, Image.FORMAT_RGBA8)
	empty.fill(Color.TRANSPARENT)
	var left: AtlasTexture = AtlasTexture.new()
	left.atlas = backing
	left.region = Rect2(0, 0, 20, 24)
	var right: AtlasTexture = AtlasTexture.new()
	right.atlas = backing
	right.region = Rect2(20, 0, 20, 24)
	var cases: Array[Dictionary] = [
		{"id": "rectangular_two_frame", "tex": backing, "frames": 2},
		{"id": "empty", "tex": ImageTexture.create_from_image(empty), "frames": 1},
		{"id": "atlas_left", "tex": left, "frames": 1},
		{"id": "atlas_right", "tex": right, "frames": 1}]
	var result: Dictionary = {}
	for descriptor in cases:
		var texture: Texture2D = descriptor.tex
		var rect: Rect2i = Rect2i(0, 0, texture.get_width() / int(descriptor.frames), texture.get_height())
		var raw: Dictionary = _raw_frame(texture, rect)
		var body_h: int = maxi(1, int(raw.used_size[1]) - 1)
		var bottom: int = int(raw.used_end[1]) - 1
		var expected_scale: float = Player.HERO_TARGET_BODY * 1.0 * Balance.CHAR_RENDER_SCALE / float(body_h)
		var expected: Dictionary = {"scale": expected_scale,
			"offset": Player.HERO_FEET_ANCHOR / expected_scale - float(bottom) + float(texture.get_height()) / 2.0}
		var actual: Dictionary = game.player._measure_hero_frame(descriptor, 1.0)
		_check("synthetic/" + String(descriptor.id), actual == expected)
		result[descriptor.id] = {"raw": raw, "render": actual}
	_check("synthetic/same_backing_distinct_atlas_geometry", left.atlas == right.atlas
		and result.atlas_left.raw != result.atlas_right.raw)
	stable["synthetic"] = result


func _check(label: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": label, "passed": passed, "detail": detail})
	if not passed:
		failure_count += 1
		print("HERO CHECK FAILED: ", label)


func _stable_hash() -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(JSON.stringify(stable, "", true).to_utf8_buffer())
	return hasher.finish().hex_encode()


func _compare_previous() -> void:
	var path := arg("compare")
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ)
	_check("previous_report_readable", file != null, path)
	if file == null:
		return
	var previous: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not previous is Dictionary:
		_check("previous_report_dictionary", false)
		return
	_check("previous_report_complete", bool(previous.get("complete", false)))
	_check("previous_report_passed", int(previous.get("failure_count", -1)) == 0)
	_check("previous_report_schema", int(previous.get("schema", -1)) == 2)
	# Compare independently produced canonical hashes, not reparsed int/float
	# representations. Timings, instance IDs and cache-call counts are excluded.
	_check("previous_exact_geometry_signature", String(previous.get("stable_sha256", "")) == _stable_hash())


func _write_report(complete: bool) -> void:
	var directory := ProjectSettings.globalize_path(shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		_check("report_write", false)
		return
	var sources: Dictionary = {}
	for path in ["res://shot_hero_geometry.gd", "res://scripts/dev/hero_measure_probe.gd", "res://scripts/player_core.gd",
		"res://scripts/menus.gd", "res://scripts/art.gd", "res://scripts/balance.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	file.store_string(JSON.stringify({"schema": 2, "complete": complete, "no_saves": game.no_saves,
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(),
		"user_data_dir": OS.get_user_data_dir(), "master_muted": AudioServer.is_bus_mute(0),
		"scope": "six base classes; one real Game; boot primes warrior; no cache clearing or whole-boot attribution",
		"timing_limits": "fixed class order and persistent Art caches; actual Player.set_class includes recalc/reset work; preview timings include model allocations; reference scans and detached probes excluded; instrumented runs are perturbed and are not performance comparisons",
		"count_limits": "opt-in wrappers count exact get_image/get_used_rect calls at recorded Player/menu/Art sites only; pixel counts describe source dimensions, not GPU transfer bytes or driver internals; detached method entries and reference reads/scans are separate",
		"work_counters_enabled": work_counters, "instrumented_sites": Work.sites, "work_phases": work_phases,
		"source_sha256": sources,
		"synthetic_captures": "controlled idle/action and forced class model, not ordinary combat inputs or recorded-video playback",
		"reference_texture_reads": reference_reads, "reference_alpha_scans": reference_scans,
		"class_order": CLASSES, "timings": timings,
		"classes": class_rows, "previews": preview_rows, "stable": stable, "stable_sha256": _stable_hash(),
		"captures": captures, "checks": checks, "failure_count": failure_count, "shots": shots_taken}, "\t", true))
	file.close()


func _paper_doll_cases() -> void:
	var rows: Dictionary = {}
	for id in CLASSES:
		var p: Player = game.player
		p.set_class(String(id))  # setup outside measured paper-doll creation
		var shell := VBoxContainer.new()
		add_child(shell)
		_begin_work(String(id) + "/paper_doll")
		var start: int = Time.get_ticks_usec()
		game.menus._paper_doll(shell, p)
		_timing(String(id) + "/paper_doll", start, "actual paper-doll UI construction; geometry reference excluded")
		var models: Array[Node] = shell.find_children("*", "AnimatedSprite2D", true, false)
		_check(String(id) + "/paper_doll/one_model", models.size() == 1)
		if models.size() == 1:
			var model := models[0] as AnimatedSprite2D
			model.stop()
			var art_name: String = Classes.CLASSES[id]["sprite"]
			var info: Dictionary = Art.hero_clips(art_name)["idle"]
			var tex: Texture2D = info["tex"]
			var size := Vector2(info.get("frame_size", Vector2i(tex.get_height(), tex.get_height())))
			# The original paper doll reads a frame-zero AtlasTexture. Retain
			# that independent reference, including the original midpoint math.
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, 0, size.x, size.y)
			var img: Image = atlas.get_image()
			reference_reads += 1
			var dx := 0.0
			var used := Rect2i()
			if img != null:
				used = img.get_used_rect()
				reference_scans += 1
				if used.size.x > 0:
					dx = (used.position.x + used.size.x * 0.5) - size.x * 0.5
			var s := minf(2.2, Menus.PD_MODEL_H / maxf(1.0, size.y))
			var x: float = (Menus.PD_WELL_LEFT_X + Menus.PD_WELL_W + Menus.PD_WELL_RIGHT_X) * 0.5
			var expected := Vector2(x - dx * s, Menus.PD_H - 30.0 - size.y * s * 0.5)
			_check(String(id) + "/paper_doll/exact_legacy_geometry", model.scale == Vector2(s, s) and model.position == expected)
			rows[id] = {"scale": _v2(model.scale), "position": _v2(model.position),
				"used": [used.position.x, used.position.y, used.size.x, used.size.y]}
		shell.free()
	stable["paper_doll"] = rows
