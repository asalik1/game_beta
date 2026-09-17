extends RefCounted
## QA-only first-render observer; call after the parent's live cast settles.
## Caller stores returned dictionary in its extra receipt. Nested baseline
## findings are separate from parent north-edge findings: report both totals.
## ShotRig.shot is synchronous; native captures complement the source proxy.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const Readout := preload("res://scripts/ui/boss_cast.gd")
var q: RefCounted
var g: Game
var boss: Boss
var readout: Control
var draw_item: CanvasItem
var separate := false
var baseline := false
var sample := {}
var rows: Array[Dictionary] = []
var captures: Array[Dictionary] = []


static func run(probe: RefCounted, casting_boss: Boss) -> Dictionary:
	var helper := new()
	helper.q = probe
	helper.g = probe.g
	helper.boss = casting_boss
	return await helper._run()


func _check(id: String, ok: bool, detail: Variant, anticipated := false) -> void:
	var status := "pass" if ok else "baseline_finding" if baseline and anticipated else "fail"
	rows.append({"id": id, "status": status, "detail": detail})
	print("CAST TRANSITION ", id, ": ", status)


func _run() -> Dictionary:
	baseline = q.r.flag("bracket-baseline")
	readout = g.hud.boss_cast_readout
	draw_item = readout.get_node_or_null("CastWorldBrackets") as CanvasItem
	separate = is_instance_valid(draw_item)
	if not separate: draw_item = readout
	_check("cast_transition.route", not separate if baseline else separate and draw_item.is_set_as_top_level(),
		{"baseline": baseline, "separate_canvas_item": separate})
	var ready: bool = is_instance_valid(boss) and readout.is_visible_in_tree() \
		and readout.get("boss") == boss and boss.cast_window.phase == "windup" \
		and not boss.is_physics_processing()
	_check("cast_transition.precondition", ready,
		"borrowed settled, posed, frozen factory boss; no damaging combat claim")
	if not ready:
		q._check("cast_transition.receipt", false, {"rows": rows, "complete": false})
		return {"rows": rows, "failures": 1, "findings": 0, "complete": false}
	var saved_quest := g.hud.quest_label.text.trim_prefix("◆  ")
	var saved_setting: bool = bool(g.settings.get("hud_clearance", true))
	var saved_cast := boss.cast_window.snapshot()
	# Begin short so long_quest is an actual text change. Production methods only.
	g.settings["hud_clearance"] = true
	g.hud.set_quest(String(Geometry.CASES[2].quest))
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var lane_ready: bool = float(g.hud.tracker_clearance.get("offset_y")) > 1.0 \
		and not bool(g.hud.tracker_clearance.get("no_fit")) \
		and readout.is_visible_in_tree() and readout.get("boss") == boss
	_check("cast_transition.initial_lane", lane_ready,
		{"offset_y": g.hud.tracker_clearance.get("offset_y"), "no_fit": g.hud.tracker_clearance.get("no_fit"),
		"readout_position": _v(readout.position), "boss_world": _v(boss.global_position)})
	if not lane_ready:
		g.settings["hud_clearance"] = saved_setting
		g.hud.set_quest(saved_quest)
		q._check("cast_transition.receipt", false, {"rows": rows, "complete": false})
		return {"rows": rows, "failures": 1, "findings": 0, "complete": false}
	draw_item.draw.connect(_observe_draw)
	await _transition("disabled", func() -> void: g.settings["hud_clearance"] = false, true)
	await _transition("enabled", func() -> void: g.settings["hud_clearance"] = true, true)
	await _transition("long_quest", func() -> void: g.hud.set_quest(String(Geometry.CASES[1].quest)), true)
	_check("cast_transition.long_wrapped", g.hud.quest_label.get_line_count() > 1,
		{"lines": g.hud.quest_label.get_line_count(), "text": g.hud.quest_label.text})
	# Real cast model, direct fixture hit; no attack, HP debit or earned interrupt.
	_check("cast_transition.break_model", boss.cast_window.hit(boss.cast_window.goal, false, false), boss.cast_window.snapshot())
	await _transition("broken", func() -> void: pass, false)
	_check("cast_transition.broken_tint", boss.cast_window.phase == "broken"
		and readout.get("title").get_theme_color("font_color").is_equal_approx(Readout.MINT),
		{"phase": boss.cast_window.phase, "title": readout.get("title").text,
		"scope": "label color/shared-state source proxy; native PNG establishes bracket tint"})
	boss.cast_window.cancel()
	await RenderingServer.frame_post_draw
	var hidden_frame := Engine.get_process_frames()
	var hidden_path: String = q.r.shot("cast_transition_hidden", "first post-draw after cast cancellation")
	_check("cast_transition.hidden", not readout.is_visible_in_tree() and not draw_item.is_visible_in_tree(),
		{"frame": hidden_frame, "path": hidden_path, "readout_visible": readout.is_visible_in_tree(),
		"draw_item_visible": draw_item.is_visible_in_tree()})
	draw_item.draw.disconnect(_observe_draw)
	g.settings["hud_clearance"] = saved_setting
	g.hud.set_quest(saved_quest)
	_check("cast_transition.cast_restored", boss.cast_window.apply_snapshot(saved_cast), saved_cast)
	await q.r.frames(2)
	_check("cast_transition.controls_restored", bool(g.settings.get("hud_clearance", true)) == saved_setting
		and g.hud.quest_label.text.trim_prefix("◆  ") == saved_quest
		and boss.cast_window.snapshot() == saved_cast, "borrowed setting, quest copy and cast model restored")
	var expected: Array[String] = []
	if baseline:
		for id in ["disabled", "enabled", "long_quest"]: expected.append(id + ".bracket_invariant")
	var findings: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": findings.append(String(row.id))
	_check("cast_transition.baseline_exact", findings == expected, {"actual": findings, "expected": expected})
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var result := {"baseline": baseline, "rows": rows, "captures": captures,
		"findings": findings.size(), "failures": failures, "complete": failures == 0,
		"scope": "First-render geometry/source proxy; native PNGs need manual review, no pixel-bracket assertion. Same frozen factory boss as parent; direct cast-model interrupt/cancel are presentation controls. Real HUD quest method and comfort setting, no process order, draw order, camera or timer changes."}
	q._check("cast_transition.receipt", failures == 0, result)
	return result


func _observe_draw() -> void:
	var point := g.get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -50))
	# Reviewed production routes: old readout inverse-compensates its transform;
	# the proposed identity top-level child records viewport coordinates directly.
	var local_point: Vector2 = point if separate else draw_item.get_global_transform().affine_inverse() * point
	sample = {"frame": Engine.get_process_frames(), "point": point, "local": local_point,
		"draw_transform": draw_item.get_global_transform_with_canvas(), "readout_position": readout.position,
		"phase": boss.cast_window.phase}


func _transition(id: String, mutation: Callable, must_shift: bool) -> void:
	var before_frame := Engine.get_process_frames()
	var before_position := readout.position
	sample = {}
	mutation.call()
	await RenderingServer.frame_post_draw
	var frame := Engine.get_process_frames()
	# Synchronous readback of this rendered frame; no wait before capture.
	var path: String = q.r.shot("cast_transition_" + id, "first rendered frame after production change")
	var current_transform := draw_item.get_global_transform_with_canvas()
	var detail := {"frame": frame, "before_frame": before_frame, "path": path,
		"before_readout": _v(before_position), "after_readout": _v(readout.position),
		"present_transform": _t(current_transform), "separate_canvas_item": separate}
	_check(id + ".first_frame", frame == before_frame + 1 and Engine.get_process_frames() == frame
		and not sample.is_empty() and int(sample.get("frame", -1)) == frame, detail)
	_check(id + ".active", readout.is_visible_in_tree() and readout.get("boss") == boss, detail)
	if sample.is_empty():
		captures.append(detail)
		return
	var inferred: Vector2 = current_transform * Vector2(sample.local)
	var expected: Vector2 = sample.point
	var live_point := g.get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -50))
	detail["draw_transform"] = _t(sample.draw_transform)
	detail["draw_readout"] = _v(sample.readout_position)
	detail["sampled_world_canvas"] = _v(expected)
	detail["live_world_canvas"] = _v(live_point)
	detail["inferred_recorded_bracket_center"] = _v(inferred)
	detail["error_pixels"] = inferred.distance_to(expected)
	detail["readout_delta_after_draw"] = _v(readout.position - Vector2(sample.readout_position))
	_check(id + ".stable_world_sample", live_point.distance_to(expected) <= 0.5, detail)
	if must_shift:
		_check(id + ".actual_predraw_shift", readout.position.distance_to(Vector2(sample.readout_position)) > 1.0, detail)
	_check(id + ".bracket_invariant", inferred.distance_to(expected) <= 0.5, detail, must_shift)
	captures.append(detail)


func _v(value: Vector2) -> Array:
	return [value.x, value.y]


func _t(value: Transform2D) -> Array:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]
