extends RefCounted
## Controlled presentation only: production HUD builders, authored controls and
## one explicitly synthetic long-title/detail stress case; no earned reward.
## No achievement is awarded and no normal encounter or input is simulated.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const CastReadout := preload("res://scripts/ui/boss_cast.gd")
const SCOPE := "controlled reward plaque / authored boss readout; paused world, real UI clocks; no earned achievement or combat"
const GAME_LEDGER := ["flags", "achievements", "kill_counts", "boss_records", "mailbox", "dropped_loot", "chapter_id", "no_saves"]
const PLAYER_LEDGER := ["gold", "xp", "level", "hp", "mp", "skill_points", "tree_points", "unspent_attr", "consumables", "materials", "mastery", "blueprints", "backpack", "equipment", "gem_bag", "bags", "loose_bags", "npc_favor", "profession", "potion_rotation", "active_potion", "room_potions", "cds", "potion_cd", "potion_swap_cd"]
var r: ShotRig
var g: Game
var h: Hud
var keep := {}
var mock: Boss


static func run(rig: ShotRig) -> String:
	var t := new()
	t.r = rig
	t.g = rig.game
	t.h = rig.game.hud
	if t.h.boss_box.visible or t.h.boss_cast_readout.visible or t.g.input_overlay_up() or t.h.target_bar_unit != null:
		return "reward display setup requires an unobstructed safe-room HUD"
	t.keep.paused = rig.get_tree().paused
	rig.get_tree().paused = true # world frozen; Hud's existing ALWAYS mode still runs UI clocks
	if not await t._drain(12.0):
		rig.get_tree().paused = bool(t.keep.paused)
		return "startup reward feed did not drain naturally"
	t.keep.geometry = Geometry.snapshot(t.h)
	t.keep.world_children = t.g.world.get_children()
	t.keep.ledger = t._ledger()
	t.keep.title_color = t.h.title_label.modulate
	t.keep.subtitle_color = t.h.subtitle_label.modulate
	t.keep.process_mode = t.h.process_mode
	t.keep.target = t.h.target_bar_unit
	t.keep.cast_boss = t.h.boss_cast_readout.get("boss")
	t.keep.cast_process = t.h.boss_cast_readout.is_processing()
	t.keep.badge_key = t.h._boss_badge_key
	t.keep.badge_texture = t.h.boss_badge.texture
	t.keep.badge_crop = (t.h.boss_badge.material as ShaderMaterial).get_shader_parameter("crop_uv")
	t.keep.colors = []
	for field: String in ["title", "instruction", "clock"]:
		var label: Label = t.h.boss_cast_readout.get(field)
		t.keep.colors.append({"node": label, "override": label.has_theme_color_override("font_color"), "color": label.get_theme_color("font_color")})
	t.h.boss_cast_readout.set_process(false)
	var error: String = await t._run()
	t._cleanup()
	rig._check("reward/ledger_unchanged", t._ledger() == t.keep.ledger)
	rig._check("reward/hud_restored", Geometry.snapshot(t.h) == t.keep.geometry)
	rig._check("reward/posed_body_retired", t.g.world.get_children() == t.keep.world_children)
	rig._check("reward/feedback_cleanup", not is_instance_valid(t.h._ann_active) and t.h._ann_queue.is_empty() and t.h._log_lines.is_empty())
	rig.get_tree().paused = bool(t.keep.paused)
	rig._check("reward/pause_restored", rig.get_tree().paused == t.keep.paused)
	return error


func _fields(owner: Object, fields: Array) -> Dictionary:
	var result := {}
	var declared: Array = []
	for property in owner.get_property_list():
		declared.append(String(property.name))
	for field in fields:
		if not String(field) in declared:
			r._check("reward/ledger_property/" + String(field), false)
			continue
		var value: Variant = owner.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _ledger() -> Dictionary:
	return {"game": _fields(g, GAME_LEDGER), "player": _fields(g.local_player, PLAYER_LEDGER), "loot_rng": g.loot_rng.state}


func _wait(seconds: float) -> void:
	await r.get_tree().create_timer(seconds, true).timeout


func _drain(seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if not is_instance_valid(h._ann_active) and h._ann_queue.is_empty() and h._log_lines.is_empty() and h._ann_stack == 0:
			await r.frames(2)
			return true
		await _wait(0.05)
	return false


func _pose(kind: String, shown: bool) -> void:
	h.set_zone("THE QUENCHING YARD" if kind == "forgemistress" else "FANGMAW'S HOLLOW" if kind == "fangmaw" else "MORWEN'S BOWER")
	h.set_quest(Story.quest_text(kind))
	h.mob_box.visible = false
	h.rival_box.visible = false
	h.boss_box.visible = shown
	h.boss_name.text = String(Story.ALL_ENEMIES[kind].name)
	# Authored base stats are display setup, not an encountered level or reward.
	h.boss_level.text = "Lv %d" % int(Story.ALL_ENEMIES[kind].level)
	var hp: float = float(Story.ALL_ENEMIES[kind].hp)
	h.boss_hp_num.text = "%s / %s" % [g.fmt_meter(hp), g.fmt_meter(hp)]
	h._dress_boss_badge(String(Story.ALL_ENEMIES[kind].name))
	h._tick_announcements()


func _message(id: String) -> String:
	var data: Dictionary = Achievements.DATA[id]
	return "Achievement unlocked · " + String(data.name) + "\n" + String(data.desc)


func _toast(id: String) -> void:
	var data: Dictionary = Achievements.DATA[id]
	h.achievement_toast(String(data.name), String(data.desc))


func _visible_message(text: String) -> bool:
	return is_instance_valid(h._ann_active) and h._ann_active.is_visible_in_tree() and String(h._ann_active.get_meta("message", "")) == text


func _queue() -> Array:
	var result: Array = []
	for row in h._ann_queue:
		result.append(String(row.text))
	return result


func _logs() -> Array:
	var result: Array = []
	for row in h._log_lines:
		if is_instance_valid(row):
			var label: Label = row.get_meta("label")
			result.append(label.text)
	return result


func _run() -> String:
	r._check("reward/clock_setup", h.process_mode == Node.PROCESS_MODE_ALWAYS and g.no_saves and not g.net_online())
	var first := _message("kills_1")
	var second := _message("lore_1")
	var first_log := first.replace("\n", " ")
	var second_log := second.replace("\n", " ")
	_pose("fangmaw", false)
	_toast("kills_1")
	r._check("reward/first_log_immediate", _logs() == [first_log])
	await _wait(0.9)
	if not _visible_message(first) or h._ann_tween == null or not h._ann_tween.is_valid():
		return "normal no-boss plaque did not become visible"
	var active_id: int = h._ann_active.get_instance_id()
	r._check("reward/no_boss_visible", _visible_message(first) and h._ann_tween.is_running())
	await _capture("01_no_boss_control")
	_pose("forgemistress", true)
	var clock_before: float = h._ann_tween.get_total_elapsed_time()
	var log_motion: Tween = h._log_lines[0].get_meta("tween")
	var log_clock_before: float = log_motion.get_total_elapsed_time()
	_toast("lore_1")
	await _wait(0.25)
	r._check("reward/active_identity", is_instance_valid(h._ann_active) and h._ann_active.get_instance_id() == active_id)
	r._probe("reward/active_boss_hidden", not _visible_message(first))
	r._probe("reward/active_boss_clock_paused", not h._ann_tween.is_running() and absf(h._ann_tween.get_total_elapsed_time() - clock_before) < 0.03,
		{"before": clock_before, "after": h._ann_tween.get_total_elapsed_time()})
	r._check("reward/boss_log_keeps_running", h._log_lines[0].is_visible_in_tree() and h._log_lines[1].is_visible_in_tree()
		and log_motion.is_running() and log_motion.get_total_elapsed_time() > log_clock_before)
	r._check("reward/queued_second_retained", _queue() == [second] and _logs() == [first_log, second_log])
	await _capture("02_active_long_boss")

	# Independent existing cast gate, with boss_box hidden to avoid confounding.
	_pose("morwen", false)
	clock_before = h._ann_tween.get_total_elapsed_time()
	await _wait(0.25)
	r._check("reward/boss_clear_resumes_active", _visible_message(first) and h._ann_active.get_instance_id() == active_id
		and h._ann_tween.is_running() and h._ann_tween.get_total_elapsed_time() > clock_before)
	mock = Boss.make_boss(g, "morwen", g.local_player.global_position + Vector2(140, 120))
	g.world.add_child(mock)
	mock.set_physics_process(false)
	mock.set_process(false)
	if not mock.cast_window.start("morwen", mock.max_hp):
		return "controlled production cast model did not start"
	h.target_bar_unit = mock
	h.boss_cast_readout.call("_process", 0.0)
	h._tick_announcements()
	clock_before = h._ann_tween.get_total_elapsed_time()
	await _wait(0.25)
	r._check("reward/cast_gate", h.boss_cast_readout.visible and not _visible_message(first) and not h._ann_tween.is_running()
		and absf(h._ann_tween.get_total_elapsed_time() - clock_before) < 0.03)
	await _capture("03_existing_cast_gate")
	_retire_mock()

	h.title_label.text = String(Story.ALL_ENEMIES.forgemistress.name)
	h.title_label.modulate.a = 1.0
	h.subtitle_label.modulate.a = 0.0
	h._tick_announcements()
	clock_before = h._ann_tween.get_total_elapsed_time()
	await _wait(0.25)
	r._check("reward/title_gate", not _visible_message(first) and not h._ann_tween.is_running()
		and absf(h._ann_tween.get_total_elapsed_time() - clock_before) < 0.03)
	r._check("reward/log_queue_retention", _queue() == [second] and _logs() == [first_log, second_log])
	await _capture("04_existing_title_gate")
	h.title_label.modulate.a = 0.0
	h._tick_announcements()
	await _wait(0.25)
	r._check("reward/active_resumed", _visible_message(first) and h._ann_active.get_instance_id() == active_id
		and h._ann_tween.is_running() and h._ann_tween.get_total_elapsed_time() > clock_before)
	r._check("reward/resume_did_not_relog", _logs() == [first_log, second_log] and _queue() == [second])
	await _capture("05_active_resumed")
	var until := Time.get_ticks_msec() + 6500
	while not _visible_message(second) and Time.get_ticks_msec() < until:
		await _wait(0.05)
	if not _visible_message(second):
		return "retained second plaque never followed the first"
	r._check("reward/queued_order", _queue().is_empty() and _visible_message(second))
	if not await _drain(12.0):
		return "first pair did not complete and age out naturally"

	# Enqueue before a boss appears, held by the existing title gate first.
	_pose("fangmaw", false)
	h.title_label.modulate.a = 1.0
	h._tick_announcements()
	_toast("bosses_1")
	var third := _message("bosses_1")
	var third_log := third.replace("\n", " ")
	r._check("reward/queued_before_boss", not is_instance_valid(h._ann_active) and _queue() == [third] and _logs() == [third_log])
	h.boss_box.visible = true
	h.title_label.modulate.a = 0.0
	h._tick_announcements()
	await _wait(0.85)
	r._probe("reward/queued_boss_deferred", not is_instance_valid(h._ann_active) and _queue() == [third])
	r._check("reward/queued_log_retained", _logs() == [third_log])
	await _capture("06_queued_short_boss")
	h.boss_box.visible = false
	h._tick_announcements()
	await _wait(0.85)
	r._check("reward/queued_resumed", _visible_message(third) and _queue().is_empty() and _logs() == [third_log])
	if not await _drain(12.0):
		return "final plaque and log did not age out naturally"
	r._check("reward/six_originals", r.views.size() == 6)
	r._check("reward/natural_completion", not is_instance_valid(h._ann_active) and h._ann_queue.is_empty() and h._log_lines.is_empty())
	return await _entrance_cases()


## Real entrance frames, not a settled-width reimplementation. Existing six
## captures above retain their original photography policy; these never freeze UI.
func _entrance_cases() -> String:
	for case: Dictionary in [
		{"id": "07_blight", "text": "THE BLIGHT BREAKS", "kind": "victory", "single": true},
		{"id": "08_short", "text": "VICTORY", "kind": "victory", "single": true},
		{"id": "09_long", "text": "CONTROLLED LONG ANNOUNCEMENT TITLE THAT MUST WRAP WITHIN ITS PLAQUE WITHOUT HIDING ANY OF THESE WORDS\nControlled detail remains fully visible below the wrapped title.", "kind": "achievement", "single": false},
	]:
		var error: String = await _entrance_case(case)
		if error != "":
			return error
		if not await _drain(12.0):
			return "entrance plaque and log did not retire naturally: " + String(case.id)
	r._check("reward/twelve_originals", r.views.size() == 12)
	var actual: Array[String] = []
	for finding in r.findings:
		actual.append(String(finding.finding))
	var expected: Array[String] = []
	if r.baseline:
		expected.append("reward/07_blight/entrance_text_contained")
	r._check("reward/entrance_exact_findings", actual == expected, {"actual": actual, "expected": expected})
	return ""


func _entrance_case(case: Dictionary) -> String:
	h.announce(String(case.text), Color(0.55, 0.95, 0.6), 2.2, String(case.kind))
	if not _visible_message(String(case.text)) or h._ann_tween == null:
		return "entrance plaque did not start: " + String(case.id)
	var plaque: Panel = h._ann_active
	var motion: Tween = h._ann_tween
	var samples: Array[Dictionary] = []
	var bad: Array[Dictionary] = []
	var early := false
	var early_clock := -1.0
	var settled := false
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and not settled:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(plaque) or not motion.is_valid():
			return "entrance plaque retired before settled capture: " + String(case.id)
		var sample := _entrance_shape(plaque)
		sample["clock"] = motion.get_total_elapsed_time()
		sample["process_frame"] = Engine.get_process_frames()
		samples.append(sample)
		if not bool(sample.contained) or (bool(case.single) and int(sample.title_lines) != 1):
			bad.append(sample)
		if not early and float(sample.clock) >= 0.18:
			_entrance_capture(String(case.id) + "_early", sample)
			early_clock = float(sample.clock)
			early = true
		elif early and float(sample.clock) >= 0.70:
			_entrance_capture(String(case.id) + "_settled", sample)
			settled = true
	var observed_entrance := false
	for sample in samples:
		if float(sample.clock) > 0.0 and float(sample.clock) < 0.55:
			observed_entrance = true
	r._check("reward/" + String(case.id) + "/live_window", early and settled and observed_entrance and early_clock >= 0.18 and early_clock < 0.55
		and samples.size() >= 4 and h.process_mode == Node.PROCESS_MODE_ALWAYS
		and h._ann_active == plaque and h._ann_tween == motion and motion.is_running(),
		{"samples": samples.size(), "early": early, "early_clock": early_clock, "settled": settled, "observed_entrance": observed_entrance})
	# The ordinary evidence was transient. A broken settled plaque is never
	# an allowed baseline defect, even when its entrance also fails.
	var settled_ok: bool = settled and not samples.is_empty() and bool(samples[-1].contained)
	if settled_ok and bool(case.single):
		settled_ok = int(samples[-1].title_lines) == 1
	r._check("reward/" + String(case.id) + "/settled_text_contained", settled_ok)
	var details := {"samples": samples, "violations": bad,
		"oracle": "actual Label character bounds and line count after every draw; no font-width estimate"}
	if String(case.id) == "07_blight":
		r._probe("reward/07_blight/entrance_text_contained", bad.is_empty(), details)
	else:
		# Controls stay strict even in baseline mode. Only the evidenced blight
		# clipping may become an anticipated finding, never any control failure.
		r._check("reward/" + String(case.id) + "/entrance_text_contained", bad.is_empty(), details)
	if String(case.id) == "09_long":
		var wrapped_detail := not samples.is_empty()
		for sample in samples:
			wrapped_detail = wrapped_detail and int(sample.title_lines) > 1 \
				and sample.labels.has("AnnouncementDetail") \
				and not String(sample.labels.get("AnnouncementDetail", {}).get("shape", {}).get("text", "")).is_empty()
		r._check("reward/09_long/wrapped_title_and_detail", wrapped_detail, details)
	if String(case.id) == "08_short" and samples.size() >= 2:
		r._check("reward/08_short/tracking_animates", float(samples[0].spacing) > float(samples[-1].spacing))
	r._write_report()
	return "" if early and settled else "entrance sampling timeout: " + String(case.id)


func _entrance_shape(plaque: Panel) -> Dictionary:
	var result := {"contained": true, "plaque": Geometry.rect(plaque.get_global_rect()),
		"alpha": plaque.modulate.a, "labels": {}, "title_lines": 0, "spacing": 0.0}
	for name: String in ["AnnouncementTitle", "AnnouncementDetail"]:
		var label := plaque.get_node_or_null(name) as Label
		if label == null:
			continue # Short production messages legitimately have no detail label.
		var shape := Geometry.shaped(label)
		var cells := Geometry.to_rect(shape.cells)
		var contained: bool = shape.count > 0 and shape.missing.is_empty() and label.visible_ratio >= 1.0 \
			and label.max_lines_visible == -1 and label.get_visible_line_count() == label.get_line_count() \
			and label.get_global_rect().grow(0.5).encloses(cells) and plaque.get_global_rect().grow(0.5).encloses(cells)
		result.labels[name] = {"shape": shape, "contained": contained}
		result.contained = bool(result.contained) and contained
		if name == "AnnouncementTitle":
			result.title_lines = label.get_line_count()
			result.spacing = (label.get_theme_font("font") as FontVariation).spacing_glyph
	result.contained = bool(result.contained) and result.labels.has("AnnouncementTitle")
	return result


func _entrance_capture(id: String, sample: Dictionary) -> void:
	# Called after frame_post_draw: image and observed geometry share one frame.
	# Synchronous readback/write may delay the NEXT frame; actual UI clock is
	# recorded above. Never pause, seek, speed up or replace the production tween.
	r.views.append({"view": id, "path": r.shot(id, SCOPE), "scope": SCOPE,
		"geometry": sample, "queue": _queue(), "log": _logs(), "photography_clock_frozen": false})


func _capture(id: String) -> void:
	r.step("controlled reward plaque " + id)
	# Freeze only for photography, after live clock observations. No draw-signal wait.
	var mode := h.process_mode
	h.process_mode = Node.PROCESS_MODE_PAUSABLE
	await r.frames(3)
	var geometry := {"quest": Geometry.shaped(h.quest_label), "zone": Geometry.shaped(h.zone_label), "boss_visible": h.boss_box.is_visible_in_tree(),
		"boss_hp": Geometry.shaped(h.boss_hp_num), "boss_level": Geometry.shaped(h.boss_level), "plaque_visible": false}
	for field: String in ["quest_label", "zone_label"]:
		_text_check(id + "/" + field, h.get(field), h.quest_panel.get_global_rect())
	if h.boss_box.is_visible_in_tree():
		for field: String in ["boss_name", "boss_level", "boss_hp_num"]:
			var label: Label = h.get(field)
			_text_check(id + "/" + field, label, label.get_global_rect())
	if h.boss_cast_readout.is_visible_in_tree():
		var cast_clip: Rect2 = h.boss_cast_readout.get_global_transform() * CastReadout.PANEL
		geometry.cast_panel = Geometry.rect(cast_clip)
		for field: String in ["title", "instruction", "clock"]:
			var label: Label = h.boss_cast_readout.get(field)
			_text_check(id + "/cast_" + field, label, cast_clip)
			geometry["cast_" + field] = Geometry.shaped(label)
	if h.title_label.modulate.a > 0.05:
		_text_check(id + "/arrival_title", h.title_label, h.get_viewport().get_visible_rect())
		geometry.arrival_title = Geometry.shaped(h.title_label)
	if is_instance_valid(h._ann_active):
		var plaque: Panel = h._ann_active
		geometry.plaque_visible = plaque.is_visible_in_tree()
		geometry.plaque = Geometry.rect(plaque.get_global_rect())
		geometry.plaque_message = String(plaque.get_meta("message", ""))
		geometry.plaque_alpha = plaque.modulate.a
		if plaque.is_visible_in_tree():
			r._check("reward/" + id + "/panel_on_screen", h.get_viewport().get_visible_rect().encloses(plaque.get_global_rect().grow(10.0)))
			for name in ["AnnouncementTitle", "AnnouncementDetail"]:
				var label: Label = plaque.get_node(name)
				_text_check(id + "/" + name, label, plaque.get_global_rect())
				geometry[name] = Geometry.shaped(label)
	var hits: Array = []
	if is_instance_valid(h._ann_active) and h._ann_active.is_visible_in_tree() and h.boss_box.is_visible_in_tree():
		for field: String in ["boss_name", "boss_level", "boss_hp_num", "boss_fill", "boss_badge_root"]:
			var control: Control = h.get(field)
			if control.is_visible_in_tree() and h._ann_active.get_global_rect().intersects(control.get_global_rect()):
				hits.append(field)
	geometry.plaque_target_hits = hits
	if id in ["02_active_long_boss", "06_queued_short_boss"]:
		r._probe("reward/" + id + "/plaque_target_clear", hits.is_empty(), geometry)
	r.views.append({"view": id, "path": r.shot(id, SCOPE), "scope": SCOPE, "geometry": geometry,
		"queue": _queue(), "log": _logs(), "photography_clock_frozen": true})
	h.process_mode = mode
	r._write_report()


func _text_check(id: String, label: Label, clip: Rect2) -> void:
	var shape := Geometry.shaped(label)
	r._check("reward/" + id + "/full_text", shape.count > 0 and shape.missing.is_empty() and label.visible_ratio >= 1.0
		and label.max_lines_visible == -1 and label.get_visible_line_count() == label.get_line_count()
		and label.get_global_rect().grow(0.5).encloses(Geometry.to_rect(shape.cells)) and clip.grow(0.5).encloses(Geometry.to_rect(shape.cells)), shape)


func _retire_mock() -> void:
	h.target_bar_unit = keep.target
	h.boss_cast_readout.set("boss", keep.cast_boss)
	h.boss_cast_readout.visible = false
	if is_instance_valid(mock):
		mock.cast_window.cancel()
		mock.free()
	mock = null


func _cleanup() -> void:
	_retire_mock()
	if h._ann_tween != null and h._ann_tween.is_valid():
		h._ann_tween.kill()
	if is_instance_valid(h._ann_active):
		h._ann_active.free()
	h._ann_active = null
	h._ann_tween = null
	h._ann_stack = 0
	h._ann_queue.clear()
	for row in h._log_lines:
		if is_instance_valid(row):
			var motion: Tween = row.get_meta("tween", null)
			if motion != null and motion.is_valid():
				motion.kill()
			row.free()
	h._log_lines.clear()
	for row in keep.colors:
		if row.override:
			row.node.add_theme_color_override("font_color", row.color)
		else:
			row.node.remove_theme_color_override("font_color")
	h.boss_badge.texture = keep.badge_texture
	h._boss_badge_key = String(keep.badge_key)
	(h.boss_badge.material as ShaderMaterial).set_shader_parameter("crop_uv", keep.badge_crop)
	h.title_label.modulate = keep.title_color
	h.subtitle_label.modulate = keep.subtitle_color
	h.boss_cast_readout.set_process(bool(keep.cast_process))
	h.process_mode = int(keep.process_mode)
	Geometry.restore(h, keep.geometry)
