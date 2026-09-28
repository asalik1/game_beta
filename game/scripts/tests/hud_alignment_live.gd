extends RefCounted
## Six native frames: live HUD, four controlled text states, frozen boss cast.
## Frames are posed layout evidence, not combat/input or attainable-build claims.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")


## One focused native run covers both layouts. Values and target visibility
## are posed; chip timing uses a fresh production HealthTrail, not inherited
## combat state. No damage, reward, player stats or network state is changed.
static func run_bars(rig: Node) -> void:
	var g: Game = rig.game
	var h: Hud = g.hud
	rig._check("bars/offline_fixture", not g.net_online() and g.no_saves)
	if g.net_online(): return
	var settings := g.settings.duplicate(true)
	var saved := Geometry.snapshot(h)
	var was_paused: bool = rig.get_tree().paused
	var mode := h.process_mode
	var window: Window = rig.get_window()
	var window_size := window.size
	rig.get_tree().paused = true
	h.process_mode = Node.PROCESS_MODE_PAUSABLE
	window.size = Vector2i(1280, 720)
	for check in Geometry.bar_fractions(h).checks:
		rig._check("bars/" + String(check.id), bool(check.passed), check.details)
	for touch in [false, true]:
		g.settings["touch_controls"] = touch
		g.settings["touch_layout"] = {}
		g.refresh_touch_mode()
		g._apply_touch_mode()
		rig.touch_run = touch
		var prefix := "touch_" if touch else "desktop_"
		rig._check(prefix + "mode", g.touch_mode == touch)
		for row in [{"id": "empty", "value": 0.0, "target": "mob"},
				{"id": "low", "value": 0.1, "target": "boss"},
				{"id": "half", "value": 0.5, "target": "rival"},
				{"id": "full", "value": 1.0, "target": "mob"}]:
			var layout: Dictionary = Geometry.CASES[0].duplicate(true)
			layout.target = row.target
			Geometry.apply_case(h, layout)
			pose_bars(h, float(row.value), float(row.value))
			await capture_bars(rig, prefix + String(row.id))
		var layout: Dictionary = Geometry.CASES[0].duplicate(true)
		layout.target = "boss"
		Geometry.apply_case(h, layout)
		var trail := preload("res://scripts/health_trail.gd").new()
		trail.step(1, 1.0, 0.0)
		var held: float = trail.step(1, 0.25, 0.0)
		pose_bars(h, 0.25, held)
		rig._check(prefix + "chip_hold", held == 1.0)
		await capture_bars(rig, prefix + "chip_hold")
		var drained: float = trail.step(1, 0.25, Balance.TARGET_DAMAGE_HOLD + 0.25 / Balance.TARGET_DAMAGE_DRAIN)
		pose_bars(h, 0.25, drained)
		rig._check(prefix + "chip_draining", drained < held and drained > 0.25)
		await capture_bars(rig, prefix + "chip_draining")
		var settled: float = trail.step(1, 0.25, 1.0 / Balance.TARGET_DAMAGE_DRAIN)
		pose_bars(h, 0.25, settled)
		rig._check(prefix + "chip_settled", settled == 0.25)
		await capture_bars(rig, prefix + "chip_settled")
	g.settings = settings
	g.refresh_touch_mode()
	g._apply_touch_mode()
	window.size = window_size
	Geometry.restore(h, saved)
	rig._check("bars/geometry_restored", Geometry.snapshot(h) == saved)
	h.process_mode = mode
	rig.get_tree().paused = was_paused


static func pose_bars(h: Hud, fraction: float, trail: float) -> void:
	for field: String in Geometry.BAR_FIELDS:
		h._set_fill(h.get(field), fraction)
	h._set_fill(h.hp_chip, trail)
	for chip in h.target_chips.values():
		h._set_fill(chip, trail)
	h.hp_text.text = "%d / 100" % int(fraction * 100)
	h.mp_text.text = "%d / 100" % int(fraction * 100)
	h.boss_hp_num.text = "%d / 100" % int(fraction * 100)


static func capture_bars(rig: Node, id: String) -> void:
	await rig._capture(id, "Posed enamel bars at 1280x720; production target-chip clock, no combat", false)
	var h: Hud = rig.game.hud
	var result := {"checks": []}
	for field: String in Geometry.BAR_FIELDS:
		Geometry.inspect_bar(result, h.get(field), field)
	for check in result.checks:
		rig._check("bars/" + id + "/" + String(check.id), bool(check.passed), check.details)
	# The existing shaped-text and clearance geometry assertions stay active.
	for check in Geometry.inspect(h).checks:
		rig._check("bars/" + id + "/layout/" + String(check.id), bool(check.passed), check.details)
	for label in [h.hp_text, h.mp_text, h.boss_hp_num]:
		rig._check("bars/" + id + "/number_contrast/" + str(label.get_path()),
			label.get_theme_color("font_color").get_luminance() > 0.7
			and label.get_theme_color("font_outline_color").get_luminance() < 0.1
			and label.get_theme_constant("outline_size") > 0)
	rig._check("bars/" + id + "/720p", h.get_viewport().get_visible_rect().size == Vector2(1280, 720))


static func run(rig: Node) -> String:
	var h: Hud = rig.game.hud
	var saved := Geometry.snapshot(h)
	var was_paused: bool = rig.get_tree().paused
	rig.get_tree().paused = true
	await capture(rig, "00_live_hud", "Actual ordinary HUD after boot, before synthetic text fixtures")
	for row in Geometry.CASES:
		Geometry.apply_case(h, row)
		await capture(rig, String(row.id), "Controlled HUD strings through production layout; real label shaping, no gameplay reward")
	await capture_cast(rig)
	Geometry.apply_case(h, Geometry.CASES[0])
	var negatives := Geometry.negative_controls(h)
	for key in negatives:
		rig._check("alignment/negative_control/" + String(key), bool(negatives[key]), negatives)
	Geometry.restore(h, saved)
	rig._check("alignment/fixture_restored", Geometry.snapshot(h) == saved)
	# Keep this posed fixture paused while the real render callback runs.
	# Timed unrelated labels need not be identical; the restored tracker
	# family and its unshifted cache must survive an actual subsequent draw.
	var tracker_state: Dictionary = saved.get("tracker_state", {})
	if not tracker_state.is_empty():
		await rig.frames(2)
		await RenderingServer.frame_post_draw
		var tracker: Node = tracker_state.node
		var changed: Array[String] = []
		for row in saved.controls:
			if row.node not in tracker.get("parts") and row.node != h.combat_feedback.target_cue: continue
			if row.node.position != row.position or row.node.size != row.size:
				changed.append(str(row.node.get_path()))
		rig._check("alignment/restored_tracker_after_draw", changed.is_empty()
			and tracker.get("base_positions") == tracker_state.base_positions,
			{"changed_controls": changed, "base_positions": str(tracker.get("base_positions")),
			"expected_base_positions": str(tracker_state.base_positions)})
	rig.get_tree().paused = was_paused
	rig._check("alignment/pause_restored", rig.get_tree().paused == was_paused)
	return ""


static func capture_cast(rig: Node) -> void:
	var h: Hud = rig.game.hud
	Geometry.apply_case(h, Geometry.CASES[1])
	var readout: Control = h.boss_cast_readout
	var saved_target: CharacterBody2D = h.target_bar_unit
	var saved_boss: Boss = readout.get("boss")
	var saved_processing := readout.is_processing()
	var saved_colors: Array[Dictionary] = []
	for field: String in ["title", "instruction", "clock"]:
		var label: Label = readout.get(field)
		saved_colors.append({"label": label, "overridden": label.has_theme_color_override("font_color"),
			"color": label.get_theme_color("font_color")})
	# A real production body and cast model are frozen before any physics step.
	# This is a posed windup, with no signature release, damage or reward.
	var boss := Boss.make_boss(rig.game, "morwen", rig.game.local_player.global_position + Vector2(140, 120))
	rig.game.world.add_child(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	h.boss_name.text = boss.display_name
	h.boss_level.text = "Lv %d" % boss.level
	h.boss_hp_num.text = "%d / %d" % [int(boss.hp), int(boss.max_hp)]
	rig._check("alignment/cast_fixture_started", boss.cast_window.start("morwen", boss.max_hp))
	h.target_bar_unit = boss
	readout.call("_process", 0.0)
	readout.set_process(false)
	rig._check("alignment/cast_fixture_visible", readout.visible and readout.get("boss") == boss)
	await capture(rig, "05_frozen_cast", "Real Morwen body and production cast readout, frozen windup; no combat or attack release")
	rig.views[-1]["cast_fixture"] = {"kind": boss.kind, "phase": boss.cast_window.phase,
		"remaining": boss.cast_window.remaining, "hud_transform": str(readout.get_global_transform()),
		"world_bracket_center": rig._rect(Rect2(rig.game.get_viewport().get_canvas_transform()
			* (boss.global_position + Vector2(0, -50)), Vector2.ZERO))}
	h.target_bar_unit = saved_target
	readout.set("boss", saved_boss)
	readout.set_process(saved_processing)
	for row in saved_colors:
		if row.overridden:
			row.label.add_theme_color_override("font_color", row.color)
		else:
			row.label.remove_theme_color_override("font_color")
	boss.cast_window.cancel()
	boss.free()
	rig._check("alignment/cast_fixture_restored", h.target_bar_unit == saved_target
		and readout.get("boss") == saved_boss and readout.is_processing() == saved_processing)
	rig._write_report()


static func capture(rig: Node, id: String, scope: String) -> void:
	await rig._capture(id, scope, false)
	var observed := Geometry.inspect(rig.game.hud)
	for check in observed.checks:
		# Baseline allows only presentation findings. Negative controls, setup,
		# restoration, outer save-byte checks and runner errors remain strict.
		rig._probe("alignment/" + id + "/" + String(check.id), bool(check.passed), check.details)
	rig.views[-1]["alignment"] = observed
	rig._write_report()
