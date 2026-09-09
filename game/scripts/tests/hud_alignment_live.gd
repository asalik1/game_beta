extends RefCounted
## Six native frames: live HUD, four controlled text states, frozen boss cast.
## Frames are posed layout evidence, not combat/input or attainable-build claims.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")


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
