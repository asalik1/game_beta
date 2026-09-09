extends ShotRig
## Audio startup diagnostic; production source/API stays unchanged.
## Run in isolated APPDATA: shot.bat audio_startup --timeout=300
## --mode=all (default): REAL boot first, then cache-warm microbenchmarks.
## --mode=boot: real boot + menu audio only; no synthetic microbenchmarks.
## --mode=phases: microbenchmarks only in a fresh process, before game boot.
## --compare=<previous observations.json>: compare stable boot/menu signatures.
## All modes inherit Master mute; shot.bat also injects the Dummy driver.
## No save writes; title/roster probes read isolated QA metadata only.
##
## LIMIT: external boot_game timing includes scene load/instantiate, synchronous
## Game._ready (audio/player/world), deferred startup and ten process frames.
## Without production hooks it cannot separate those INTERNAL boot phases.
## First post-draw is an engine render boundary, not OS window presentation.
## Independent synthesis/load timings must NOT be added/subtracted to apportion
## overall boot. Godot ticks do not replace an external process-launch timer.
## No cache flushing, altered imports, forced GC or benchmark speedup claims.
## Current Sfx/Music noise uses explicitly seeded LOCAL RNGs, so PCM hashes
## are useful same-engine diagnostics. They are not a promise for future
## generators using global randomness; preserve musical definitions/specs.

var initialized_us := Time.get_ticks_usec()
var marks: Array[Dictionary] = []
var timings: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var stable_boot: Dictionary = {}
var menu_contracts: Dictionary = {}
var menu_settling: Dictionary = {}
var benchmark: Dictionary = {}
var source_hashes: Dictionary = {}
var failure_count := 0
var first_draw_us := -1
var mode := "all"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mode = arg("mode", "all")
	_stamp("rig_ready")
	if not _check("mode", mode in ["all", "boot", "phases"], mode):
		_write_report(true)
		finish(1)
		return
	if mode != "phases":
		RenderingServer.frame_post_draw.connect(_first_game_draw, CONNECT_ONE_SHOT)
		var start := Time.get_ticks_usec()
		_stamp("before_real_boot_game")
		await boot_game()  # shared path verbatim; NO prior audio microbenchmark
		_timing("real_boot_game_to_return", start, "scene + Game._ready + deferred flow + 10 frames")
		_stamp("real_boot_game_return")
		if first_draw_us >= 0:
			timings.append({"name": "real_boot_game_to_first_post_draw", "start_us": start,
				"end_us": first_draw_us, "elapsed_us": first_draw_us - start,
				"scope": "first render boundary after boot invocation; not OS presentation"})
		_check("first_game_draw_observed", first_draw_us >= start, first_draw_us)
		_check("boot.no_saves", game.no_saves, game.no_saves)
		_check("boot.chapter_select", game.menus.current == "chapter_select", game.menus.current)
		# Hashing and inspection begin AFTER both boot timing boundaries.
		stable_boot = _boot_signature()
		_write_report(false)
	if mode != "boot":
		_microbenchmarks()
		_write_report(false)
	if game != null:
		await _menu_probes()
		_variant_probe()
		_compare_previous()
	_check("master_still_muted", AudioServer.is_bus_mute(0), AudioServer.is_bus_mute(0))
	_stamp("diagnostic_complete")
	_write_report(true)
	print("AUDIO STARTUP: mode=%s checks=%d failed=%d; independent timings, no boot attribution" % [mode, checks.size(), failure_count])
	finish(1 if failure_count > 0 else 0)


func _first_game_draw() -> void:
	first_draw_us = Time.get_ticks_usec()
	_stamp("first_game_post_draw")


func _stamp(label: String) -> void:
	var now := Time.get_ticks_usec()
	var row := {"name": label, "engine_ticks_us": now, "since_rig_init_us": now - initialized_us,
		"process_frame": Engine.get_process_frames()}
	if game != null and game.menus != null:
		row["menu"] = game.menus.current
	marks.append(row)
	print("AUDIO MARK: %s ticks_us=%d since_rig_init_us=%d" % [label, now, now - initialized_us])


func _timing(label: String, start: int, scope: String) -> void:
	var end := Time.get_ticks_usec()
	timings.append({"name": label, "start_us": start, "end_us": end,
		"elapsed_us": end - start, "scope": scope})
	print("AUDIO TIMING: %s %.3f ms (%s)" % [label, (end - start) / 1000.0, scope])


func _microbenchmarks() -> void:
	step("audio phase microbenchmarks")
	_stamp("microbenchmarks_begin")
	# A detached Game is only the existing export-aware enumerator/group builder.
	# It never enters the tree, invokes _ready, plays audio or accesses a save.
	var probe := Game.new()
	probe.no_saves = true
	var start := Time.get_ticks_usec()
	var fallback_sounds: Dictionary = Sfx.build_all()
	_timing("micro_sfx_build_all", start, "independent full fallback synthesis; signature work excluded")
	start = Time.get_ticks_usec()
	var sound_load: Dictionary = _load_recorded(probe, "sounds")
	_timing("micro_recorded_sounds", start, "enumeration + existence/type validation + ResourceLoader + diagnostic rows")
	start = Time.get_ticks_usec()
	var fallback_music: Dictionary = Music.build_all()
	_timing("micro_music_build_all", start, "independent full fallback synthesis; signature work excluded")
	start = Time.get_ticks_usec()
	var music_load: Dictionary = _load_recorded(probe, "music")
	_timing("micro_recorded_music", start, "enumeration + validation + ResourceLoader + legacy loop setup + diagnostic rows")
	# These observers count real factory/_synth calls in the selective builders.
	# Timed independently, after the legacy work; no overall-boot attribution.
	var sound_calls: Array[String] = []
	var music_calls: Array[String] = []
	start = Time.get_ticks_usec()
	var selective_sounds := _observed_build(Sfx.build_all, sound_load.bank, sound_calls)
	_timing("micro_sfx_missing_only", start, "independent selective build + QA call observer; recordings already loaded")
	start = Time.get_ticks_usec()
	var selective_music := _observed_build(Music.build_all, music_load.bank, music_calls)
	_timing("micro_music_missing_only", start, "independent selective build + QA call observer; recordings already loaded")
	_stamp("microbenchmarks_timed_work_complete")
	# Retain both fallback dictionaries for inspection, without regenerating them.
	var expected_sounds := fallback_sounds.duplicate()
	var expected_music := fallback_music.duplicate()
	expected_sounds.merge(sound_load.bank, true)
	expected_music.merge(music_load.bank, true)
	probe.sounds = expected_sounds
	probe._build_sound_groups()
	benchmark = {
		"cache_context": "after real boot; all successful boot overrides remain referenced" if game != null else "before any game boot; per-resource cache_before recorded; OS/import caches uncontrolled",
		"synthesis_scope": "full no-argument reference and selective build, independently of Game._ready; observer reports actual synth calls",
		"loader_scope": "unchanged rig-local legacy override loops; not instrumentation inside production boot",
		"hashing_scope": "source/PCM hashing, bank signatures and invalid-override fixtures occur after all timed microbenchmarks",
		"sounds_files": sound_load.rows, "music_files": music_load.rows,
		"sounds_enumerated_files": sound_load.enumerated_files,
		"music_enumerated_files": music_load.enumerated_files,
		"fallback_sounds": _bank_signature(fallback_sounds),
		"fallback_music": _bank_signature(fallback_music),
		"reference_sounds": _bank_signature(expected_sounds),
		"reference_music": _bank_signature(expected_music),
		"reference_sound_groups": probe.sound_groups.duplicate(true),
		"sounds_coverage": _coverage(fallback_sounds, sound_load.bank),
		"music_coverage": _coverage(fallback_music, music_load.bank),
		"selective_sound_calls": sound_calls, "selective_music_calls": music_calls,
		"reference_sound_key_order": expected_sounds.keys(), "reference_music_key_order": expected_music.keys()}
	_selective_contract("sounds", selective_sounds, expected_sounds, sound_calls, benchmark.sounds_coverage)
	_selective_contract("music", selective_music, expected_music, music_calls, benchmark.music_coverage)
	_builder_fixture("sounds", Sfx.build_all, fallback_sounds, "sword", "potion", "talk")
	_builder_fixture("music", Music.build_all, fallback_music, "village", "boss_fangmaw", "roster")
	if game != null:
		_compare_banks("boot.sounds_vs_legacy_reference", benchmark.reference_sounds, stable_boot.sounds)
		_compare_banks("boot.music_vs_legacy_reference", benchmark.reference_music, stable_boot.music)
		_check("boot.variant_groups_vs_reference", _canonical(stable_boot.sound_groups) == _canonical(probe.sound_groups), stable_boot.sound_groups)
		_check("boot.sound_key_order", game.sounds.keys() == expected_sounds.keys(), game.sounds.keys())
		_check("boot.music_key_order", game.music_tracks.keys() == expected_music.keys(), game.music_tracks.keys())
		_presence_contract("sounds", fallback_sounds, sound_load.bank, game.sounds)
		_presence_contract("music", fallback_music, music_load.bank, game.music_tracks)
	probe.free()


func _observed_build(builder: Callable, overrides: Dictionary, calls: Array[String]) -> Dictionary:
	var observer := func(key: String) -> void: calls.append(key)
	return builder.call(overrides, observer)


func _selective_contract(label: String, actual: Dictionary, expected: Dictionary,
		calls: Array[String], coverage: Dictionary) -> void:
	var sorted_calls := calls.duplicate()
	sorted_calls.sort()
	_check(label + ".actual_synth_call_set", sorted_calls == coverage.missing_override_fallback_keys,
		{"synthesized": calls, "synth_calls": calls.size(), "expected_missing": coverage.missing_override_fallback_keys,
		"skipped_valid_recordings": coverage.replaced_fallback_keys})
	_check(label + ".selective_key_order", actual.keys() == expected.keys(), actual.keys())
	_compare_banks(label + ".selective_vs_legacy_pcm", _bank_signature(expected), _bank_signature(actual))


func _builder_fixture(label: String, builder: Callable, fallback: Dictionary,
		missing_key: String, null_key: String, invalid_key: String) -> void:
	# Valid streams for every base key must cause ZERO factory calls. Extra keys
	# intentionally arrive v2 then v1, testing order independently of sorting.
	var overrides := fallback.duplicate()
	var sentinel: AudioStream = fallback[missing_key]
	overrides["qa_recorded_only_v2"] = sentinel
	overrides["qa_recorded_only_v1"] = sentinel
	var expected := overrides.duplicate()
	overrides["qa_null_only"] = null
	overrides["qa_invalid_only"] = "not an AudioStream"
	if label == "music":
		overrides["qa_unsupported_music_only"] = AudioStreamRandomizer.new()
	var original := overrides.duplicate()
	var calls: Array[String] = []
	var actual := _observed_build(builder, overrides, calls)
	var wrong_identity: Array[String] = []
	for key in expected:
		if actual.get(key) != expected[key]:
			wrong_identity.append(String(key))
	_check(label + ".all_valid_overrides_skip_every_factory", calls.is_empty(), calls)
	_check(label + ".valid_override_identity_and_order", actual.keys() == expected.keys() and wrong_identity.is_empty(),
		{"keys": actual.keys(), "wrong_identity": wrong_identity})
	_check(label + ".override_input_unchanged", overrides == original, overrides.keys())
	# Leave just these actual synth recipes uncovered. Missing, null and wrong
	# types must each regenerate their exact legacy stream, without invalid extras.
	overrides.erase(missing_key)
	overrides[null_key] = null
	overrides[invalid_key] = "not an AudioStream"
	var expected_calls: Array[String] = [missing_key, null_key, invalid_key]
	if label == "music":
		overrides["keep"] = AudioStreamRandomizer.new() # AudioStream, but unsupported by the recorded music loader
		expected_calls.append("keep")
	original = overrides.duplicate()
	calls = []
	actual = _observed_build(builder, overrides, calls)
	var sorted_calls := calls.duplicate()
	sorted_calls.sort()
	expected_calls.sort()
	_check(label + ".missing_null_invalid_actual_fallback_calls", sorted_calls == expected_calls,
		{"observed": calls, "expected": expected_calls})
	_check(label + ".invalid_entries_removed_key_order", actual.keys() == expected.keys(), actual.keys())
	_check(label + ".invalid_override_input_unchanged", overrides == original, overrides.keys())
	_compare_banks(label + ".invalid_override_legacy_pcm", _bank_signature(expected), _bank_signature(actual))
	benchmark[label + "_invalid_override_fixture"] = {"synth_calls": calls,
		"synth_call_count": calls.size(), "expected_calls": expected_calls, "output_key_order": actual.keys()}


## Preserve current enumeration order and successful last-file-wins precedence.
## These loops are the BEFORE reference, not a proposed new production API.
func _load_recorded(probe: Game, folder: String) -> Dictionary:
	var bank: Dictionary = {}
	var rows: Array[Dictionary] = []
	var files := probe._override_files(folder)
	for file in files:
		if not (file.ends_with(".wav") or file.ends_with(".ogg") or file.ends_with(".mp3")):
			continue
		var path := "res://assets/%s/%s" % [folder, file]
		var row := {"file": file, "key": file.get_basename(), "path": path,
			"cache_before": ResourceLoader.has_cached(path), "accepted": false}
		rows.append(row)
		var start := Time.get_ticks_usec()
		if not ResourceLoader.exists(path):
			row["status"] = "missing_resource"
			row["load_and_setup_us"] = Time.get_ticks_usec() - start
			continue
		var resource := load(path)
		var key := file.get_basename()
		var accepted := false
		if folder == "sounds":
			accepted = resource is AudioStream
		elif resource is AudioStreamOggVorbis:
			var ogg := resource as AudioStreamOggVorbis
			ogg.loop = true
			ogg.loop_offset = float(Game.MUSIC_TUNE.get(key, {}).get("start", 0.0))
			accepted = true
		elif resource is AudioStreamMP3:
			var mp3 := resource as AudioStreamMP3
			mp3.loop = true
			mp3.loop_offset = float(Game.MUSIC_TUNE.get(key, {}).get("start", 0.0))
			accepted = true
		elif resource is AudioStreamWAV:
			var wav := resource as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
			accepted = true
		row["load_and_setup_us"] = Time.get_ticks_usec() - start
		row["accepted"] = accepted
		row["status"] = "loaded" if accepted else "invalid_audio_type_or_null"
		row["type"] = resource.get_class() if resource != null else "null"
		row["replaces_earlier_recorded_file"] = bank.has(key) and accepted
		if accepted:
			bank[key] = resource
	return {"bank": bank, "rows": rows, "enumerated_files": Array(files)}


func _coverage(fallback: Dictionary, recorded: Dictionary) -> Dictionary:
	var replaced: Array[String] = []
	var missing: Array[String] = []
	var recorded_only: Array[String] = []
	for key in _keys(fallback):
		if recorded.has(key):
			replaced.append(key)
		else:
			missing.append(key)
	for key in _keys(recorded):
		if not fallback.has(key):
			recorded_only.append(key)
	return {"replaced_fallback_keys": replaced, "missing_override_fallback_keys": missing,
		"recorded_only_keys": recorded_only}


func _presence_contract(label: String, fallback: Dictionary, recorded: Dictionary, actual: Dictionary) -> void:
	var missing := _coverage(fallback, recorded)
	var failures: Array[String] = []
	for raw_key in missing.missing_override_fallback_keys:
		var key := String(raw_key)
		if not actual.has(key) or not actual[key] is AudioStreamWAV:
			failures.append(key)
	_check(label + ".existing_missing_overrides_retain_fallback", failures.is_empty(),
		{"tested_keys": missing.missing_override_fallback_keys, "failures": failures})
	failures.clear()
	for key in _keys(recorded):
		if actual.get(key) != recorded[key]:
			failures.append(key)
	_check(label + ".valid_recorded_overrides_win", failures.is_empty(),
		{"tested_keys": _keys(recorded), "wrong_stream_identity": failures})


func _boot_signature() -> Dictionary:
	var pool: Array[Dictionary] = []
	for raw_player in game.sound_pool:
		var player := raw_player as AudioStreamPlayer
		pool.append({"bus": String(player.bus), "process_mode": player.process_mode})
	return {"sounds": _bank_signature(game.sounds), "music": _bank_signature(game.music_tracks),
		"sound_groups": game.sound_groups.duplicate(true), "music_tune": Game.MUSIC_TUNE.duplicate(true),
		"settings": {"music": game.settings.music, "sfx": game.settings.sfx},
		"sound_pool": pool, "music_player_bus": String(game.music_player.bus),
		"music_player_process_mode": game.music_player.process_mode,
		"ambient_player_bus": String(game.amb_player.bus),
		"ambient_player_process_mode": game.amb_player.process_mode,
		"music_base_db": Game.MUSIC_DB, "ambient_base_db": Game.AMB_DB,
		"sfx_base_db": Balance.SFX_BASE_DB,
		"sfx_cutoff_fade": Balance.SFX_CUTOFF_FADE,
		"sfx_cutoff_duck_db": Balance.SFX_CUTOFF_DUCK_DB}


func _bank_signature(bank: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in _keys(bank):
		result[key] = _stream_signature(bank[key] as AudioStream)
	return result


func _stream_signature(stream: AudioStream) -> Dictionary:
	if stream == null:
		return {"type": "null"}
	var result := {"type": stream.get_class(), "resource_path": stream.resource_path,
		"length_seconds": snappedf(stream.get_length(), 0.000001)}
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		result.merge({"format": wav.format, "mix_rate": wav.mix_rate, "stereo": wav.stereo,
			"loop_mode": wav.loop_mode, "loop_begin": wav.loop_begin, "loop_end": wav.loop_end,
			"data_bytes": wav.data.size(), "data_sha256": _hash_bytes(wav.data)})
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		result.merge({"loop": ogg.loop, "loop_offset": ogg.loop_offset})
	elif stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		result.merge({"loop": mp3.loop, "loop_offset": mp3.loop_offset,
			"data_bytes": mp3.data.size(), "data_sha256": _hash_bytes(mp3.data)})
	if stream.resource_path != "":
		# In PCKs source bytes may not be directly readable; say so explicitly.
		# The loaded resource path/type/length/loop signature remains available.
		var path := stream.resource_path
		if not source_hashes.has(path):
			source_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "source_not_directly_readable"
		result["source_sha256"] = source_hashes[path]
	return result


func _menu_probes() -> void:
	# This is the real cover -> roster -> class menu implementation, explicitly
	# opened after the no_saves boot. No character is committed or slot loaded.
	step("paused cover audio")
	game.menus.open_title()
	await _menu_contract("cover", "title")
	step("paused roster audio")
	game.menus.open_slots()
	await _menu_contract("roster", "roster")
	step("paused class audio")
	game.menus.new_character()
	await _menu_contract("class_select", "roster")
	_write_report(false)


func _menu_contract(label: String, expected_track: String) -> void:
	var player := game.music_player
	var expected_db: float = Game.MUSIC_DB + float(Game.MUSIC_TUNE.get(expected_track, {}).get("gain", 0.0)) + game._vol_db(float(game.settings.music))
	await _settle_menu_audio(label, expected_track, expected_db)
	var idx := AudioServer.get_bus_index("SFX")
	var row := {"menu": game.menus.current, "title_stage": game.menus.title_stage,
		"current_track": game.current_track, "stream": _stream_signature(player.stream),
		"playing": player.playing, "paused_tree": get_tree().paused,
		"process_mode": player.process_mode, "bus": String(player.bus),
		"volume_db": snappedf(player.volume_db, 0.001), "expected_volume_db": snappedf(expected_db, 0.001),
		"configured_start_seconds": float(Game.MUSIC_TUNE.get(expected_track, {}).get("start", 0.0)),
		"sfx_bus_db": snappedf(AudioServer.get_bus_volume_db(idx), 0.001) if idx >= 0 else null,
		"no_saves": game.no_saves}
	menu_contracts[label] = row
	_check(label + ".recorded_track_playing_while_paused", player.playing and get_tree().paused
		and game.current_track == expected_track and player.stream == game.music_tracks.get(expected_track)
		and player.process_mode == Node.PROCESS_MODE_ALWAYS, row)
	_check(label + ".gain_and_settings", absf(player.volume_db - expected_db) < 0.05, row)
	_check(label + ".sfx_bus_settings", idx >= 0 and absf(AudioServer.get_bus_volume_db(idx)
		- game._vol_db(float(game.settings.sfx))) < 0.05, row.sfx_bus_db)
	_check(label + ".no_saves", game.no_saves, game.no_saves)
	shot(label, "silent audio contract; playback position intentionally excluded from stable signature")


func _settle_menu_audio(label: String, expected_track: String, expected_db: float) -> void:
	# Baseline1 proved a long synchronous frame can expire one wall timer
	# while the sequential music tween has advanced only a single frame.
	# Pump actual frames, then observe the production result without changing
	# stream, volume, pause, time_scale, tween speed or any audio setting.
	var began := Time.get_ticks_msec()
	var deadline := began + 8000
	var first_frame := Engine.get_process_frames()
	var pump_frames := 0
	var stable_frames := 0
	var settled := false
	var samples: Array[Dictionary] = []
	var sample_due := began
	var player := game.music_player
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		pump_frames += 1
		var now := Time.get_ticks_msec()
		var matches: bool = game.current_track == expected_track and player.playing \
			and player.stream == game.music_tracks.get(expected_track) \
			and absf(player.volume_db - expected_db) < 0.0001
		stable_frames = stable_frames + 1 if matches else 0
		if now >= sample_due:
			sample_due = now + 200
			samples.append({"elapsed_ms": now - began, "frame": Engine.get_process_frames(),
				"track": game.current_track, "playing": player.playing,
				"stream_path": player.stream.resource_path if player.stream != null else "",
				"volume_db": player.volume_db, "matches": matches})
		# A full normal fade duration plus several matching frames avoids an
		# earlier boot tween's transient value being mistaken for completion.
		if now - began >= 1200 and pump_frames >= 4 and stable_frames >= 3:
			settled = true
			break
	var result := {"settled": settled, "elapsed_ms": Time.get_ticks_msec() - began,
		"first_frame": first_frame, "last_frame": Engine.get_process_frames(),
		"pumped_frames": pump_frames, "stable_frames": stable_frames,
		"deadline_ms": 8000, "expected_track": expected_track,
		"expected_volume_db": expected_db, "samples": samples}
	# Timing/position evidence stays OUT of the stable baseline comparison.
	menu_settling[label] = result
	_check(label + ".settled_before_deadline", settled, result)
	_stamp(label + "_audio_settled" if settled else label + "_audio_settle_timeout")


func _variant_probe() -> void:
	var previous_last := game.sound_group_last.duplicate(true)
	var previous_rng_state: int = game.sfx_rng.state
	game.sound_group_last.clear()
	game.sfx_rng.seed = 1717
	var failures: Array[String] = []
	for key in _keys(game.sound_groups):
		var group: Array = game.sound_groups[key]
		var previous := ""
		for i in 12:
			var chosen := game._sound_variant(key)  # selection only; never invokes sfx()
			if not group.has(chosen) or (group.size() > 1 and chosen == previous):
				failures.append(key)
			previous = chosen
	game.sound_group_last = previous_last
	game.sfx_rng.state = previous_rng_state
	_check("variant_membership_and_no_immediate_repeat", failures.is_empty(), failures)


func _compare_previous() -> void:
	var path := arg("compare", "")
	if path == "":
		return
	_report_comparison_sanity()
	if not _check("previous_report_exists", FileAccess.file_exists(path), path):
		return
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check("previous_report_complete", old is Dictionary and bool(old.get("complete", false)), path):
		return
	var old_boot: Dictionary = old.get("stable_boot", {})
	if not _check("previous_report_has_real_boot", not old_boot.is_empty(), path):
		return
	_compare_banks("previous.stable_boot", old_boot, stable_boot, true)
	_compare_banks("previous.menu_contracts", old.get("menu_contracts", {}), menu_contracts, true)
	# Protected overridden tracks still receive a complete no-argument PCM
	# comparison: a valid recording must not hide an accidentally edited recipe.
	var old_benchmark: Dictionary = old.get("benchmark", {})
	for key in ["fallback_sounds", "fallback_music"]:
		if benchmark.has(key) and old_benchmark.has(key):
			_compare_banks("previous." + key, old_benchmark[key], benchmark[key], true)


func _compare_banks(label: String, expected: Dictionary, actual: Dictionary, from_report := false) -> void:
	var changed: Array[String] = []
	for key in _keys(expected):
		if not actual.has(key):
			changed.append(key)
			continue
		var same := _report_equal(expected[key], actual[key]) if from_report else _canonical(expected[key]) == _canonical(actual[key])
		if not same:
			changed.append(key)
	for key in _keys(actual):
		if not expected.has(key):
			changed.append("unexpected:" + key)
	_check(label, changed.is_empty(), {"expected_keys": expected.size(), "actual_keys": actual.size(), "changed_keys": changed})


func _report_equal(expected: Variant, actual: Variant) -> bool:
	# Godot JSON parsing makes every number a float. Live enum/sample-count
	# fields are ints, so serialized 3.0 vs 3 was a false cross-report failure.
	# Only mixed int/float leaves gain exact numeric equivalence. Same-type
	# leaves keep the original serialization comparison, including the report's
	# existing precision for snapped decimal lengths/gains. No new tolerance.
	if expected is Dictionary and actual is Dictionary:
		if expected.size() != actual.size():
			return false
		for key in expected:
			if not actual.has(key) or not _report_equal(expected[key], actual[key]):
				return false
		return true
	if expected is Array and actual is Array:
		if expected.size() != actual.size():
			return false
		for i in expected.size():
			if not _report_equal(expected[i], actual[i]):
				return false
		return true
	if typeof(expected) != typeof(actual):
		return ((expected is int and actual is float) or (expected is float and actual is int)) and expected == actual
	return _canonical(expected) == _canonical(actual)


func _report_comparison_sanity() -> void:
	var live := {"format": 1, "gain_db": -16.25, "length": snappedf(0.2, 0.000001), "loop": {"end": 48000, "enabled": true},
		"variants": ["v1", "v2"], "pcm_sha256": "unchanged_pcm"}
	var parsed: Variant = JSON.parse_string(JSON.stringify(live))
	_check("report_compare.numeric_type_equivalence", _report_equal(parsed, live)
		and _report_equal(3.0, 3) and _report_equal(3, 3.0), {"parsed_format_type": typeof(parsed.format), "live_format_type": typeof(live.format)})
	var integer_change := live.duplicate(true)
	integer_change["loop"]["end"] = 48001
	var fraction_change := live.duplicate(true)
	fraction_change["gain_db"] = -16.250001
	_check("report_compare.numeric_changes_rejected", not _report_equal(parsed, integer_change)
		and not _report_equal(parsed, fraction_change) and not _report_equal(3.000001, 3),
		{"changed_sample_count": 48001, "changed_gain_db": -16.250001, "fractional_vs_integer": 3.000001})
	var hash_change := live.duplicate(true)
	hash_change["pcm_sha256"] = "different_pcm"
	var order_change := live.duplicate(true)
	order_change["variants"] = ["v2", "v1"]
	var missing := live.duplicate(true)
	missing.erase("format")
	_check("report_compare.hash_order_structure_types_rejected", not _report_equal(parsed, hash_change)
		and not _report_equal(parsed, order_change) and not _report_equal(parsed, missing)
		and not _report_equal(true, 1) and not _report_equal("3", 3), "hash, array order, missing field, bool/int and string/int")


func _keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in dictionary.keys():
		result.append(String(key))
	result.sort()
	return result


func _canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _hash_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _check(label: String, passed: bool, observed: Variant) -> bool:
	checks.append({"name": label, "passed": passed, "observed": observed})
	if not passed:
		failure_count += 1
	print("AUDIO CHECK: %s %s" % ["PASS" if passed else "FAIL", label])
	return passed


func _write_report(complete: bool) -> void:
	var generator_sources: Dictionary = {}
	for path in ["res://scripts/sfx.gd", "res://scripts/music.gd", "res://scripts/game.gd"]:
		generator_sources[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "source_not_directly_readable"
	var report := {"schema": 1, "mode": mode, "complete": complete,
		"engine_version": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(), "user_data_dir": OS.get_user_data_dir(),
		"export_template": OS.has_feature("template"), "engine_ticks_at_rig_init_us": initialized_us,
		"master_muted": AudioServer.is_bus_mute(0), "audio_output_latency": AudioServer.get_output_latency(),
		"audio_device_count": AudioServer.get_output_device_list().size(),
		"clock_scope": "Godot monotonic microseconds; initialization before rig construction is not instrumented",
		"boot_scope": "unchanged ShotRig.boot_game; first-post-draw and return only; no internal phase attribution",
		"comparison_limits": "same engine/imports/renderer/settings/assets; record APPDATA/cache/machine-load conditions externally; no OS cache eviction",
		"generator_source_sha256": generator_sources,
		"rng_contract": "Current sfx.gd/music.gd noise has explicitly seeded local RNGs and no bare global randf/randi calls. PCM hashes are same-engine diagnostics; do not generalize to unseeded/global-RNG generators. Game uses global randomness for wander_seed/events; constructor/global RNG side effects are not measured here. Preserve village/story/boss musical definitions and compare source changes as well as streams.",
		"planned_fixture_tests": [
			"Implemented: actual selective synth call sets, all-valid zero-call identity, missing/null/non-audio fallback PCM, invalid extras removed and base/extra key order.",
			"Implemented: unsupported AudioStream music types synthesize the base key or disappear when recording-only; caller input dictionaries remain unchanged.",
			"Installed recordings retain unchanged enumeration-order last valid file precedence; fixture does not mock resource loading.",
			"Future packaged build: manifest-backed enumeration must retain these loaded stream identities and loop settings.",
			"Missing/invalid fixtures are dictionary inputs to the optional build_all seam; no real audio files are created, hidden or edited."],
		"marks": marks, "timings": timings, "stable_boot": stable_boot,
		"stable_boot_sha256": _hash_bytes(_canonical(stable_boot).to_utf8_buffer()),
		"menu_contracts": menu_contracts, "menu_settling": menu_settling,
		"benchmark": benchmark, "checks": checks,
		"failure_count": failure_count, "shots": shots_taken}
	var directory := ProjectSettings.globalize_path(shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("observations.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failure_count += 1
		print("AUDIO CHECK: FAIL report_write " + path)
		return
	file.store_string(JSON.stringify(report, "\t", true))
	file.close()
	print("AUDIO REPORT: %s complete=%s" % [path, complete])
