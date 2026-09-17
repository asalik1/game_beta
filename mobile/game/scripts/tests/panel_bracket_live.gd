extends RefCounted
## QA-only posed overlap; preserves the borrowed boss and readout state.
## Uses the actual rendered PNGs, not a production-color mock or copied layout.
static func run(q: RefCounted, boss: Boss) -> Dictionary:
	var g: Game = q.g
	var readout: Control = g.hud.boss_cast_readout
	var brackets := readout.get_node_or_null("CastWorldBrackets") as Node2D
	var ready: bool = is_instance_valid(brackets) and readout.is_visible_in_tree() \
		and readout.get("boss") == boss and boss.cast_window.phase == "windup" \
		and not boss.is_physics_processing() and is_zero_approx(float(g.settings.get("camera_lead", 1.0)))
	q._check("panel_brackets.precondition", ready, "visible frozen windup; existing zero-lead comfort fixture")
	if not ready: return {"complete": false, "failures": 1}
	var saved_position := boss.global_position
	var saved_setting: bool = bool(g.settings.get("hud_clearance", true))
	var saved_visible := brackets.visible
	g.settings["hud_clearance"] = false # ordinary layout remains stationary
	brackets.show()
	for pass_index in 2:
		await q.r.sim_wait(0.8)
		await RenderingServer.frame_post_draw
		var text_rect: Rect2 = readout.get("instruction").get_global_rect()
		var center := text_rect.get_center() - Vector2(0, 36)
		boss.global_position = g.get_viewport().get_canvas_transform().affine_inverse() * center + Vector2(0, 50)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var instruction: Rect2 = readout.get("instruction").get_global_rect()
	var center := g.get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -50))
	# Two lower horizontal corner strokes, including their 2px amber width.
	var left := Rect2(center + Vector2(-36, 35), Vector2(13, 2))
	var right := Rect2(center + Vector2(23, 35), Vector2(13, 2))
	var intersects := instruction.intersects(left) and instruction.intersects(right)
	var shown_path: String = q.r.shot("cast_panel_brackets_visible", "posed corners crossing instruction glyph row")
	var shown := Image.load_from_file(shown_path)
	brackets.hide() # negative control changes only the world-indicator child
	await RenderingServer.frame_post_draw
	var reference_rect: Rect2 = readout.get("instruction").get_global_rect()
	var reference_path: String = q.r.shot("cast_panel_brackets_reference", "same pose; only bracket child hidden")
	var reference := Image.load_from_file(reference_path)
	var equal_size := shown.get_size() == reference.get_size()
	var clipped := instruction.intersection(Rect2(Vector2.ZERO, Vector2(reference.get_size())))
	var cores := 0
	var gold_over_core := 0
	if equal_size:
		for y in range(int(ceil(clipped.position.y)), int(floor(clipped.end.y))):
			for x in range(int(ceil(clipped.position.x)), int(floor(clipped.end.x))):
				var clean := reference.get_pixel(x, y)
				if minf(clean.r, minf(clean.g, clean.b)) < 0.78 \
						or maxf(clean.r, maxf(clean.g, clean.b)) - minf(clean.r, minf(clean.g, clean.b)) > 0.10: continue
				cores += 1
				var marked := shown.get_pixel(x, y)
				if marked.r > 0.70 and marked.g > 0.55 and marked.b < 0.80 \
						and marked.r - marked.b > 0.12 and marked.g - marked.b > 0.08:
					gold_over_core += 1
	var baseline: bool = q.r.flag("overlap-baseline")
	var stable: bool = equal_size and instruction.is_equal_approx(reference_rect) \
		and readout.is_visible_in_tree() and readout.get("boss") == boss and boss.cast_window.phase == "windup"
	var valid: bool = intersects and stable and cores >= 40
	var expected: bool = gold_over_core > 0 if baseline else gold_over_core == 0
	var result := {"baseline": baseline, "complete": valid and expected, "failures": int(not (valid and expected)),
		"findings": int(baseline and gold_over_core > 0), "opaque_white_core_pixels": cores, "gold_over_core_pixels": gold_over_core,
		"instruction": [instruction.position.x, instruction.position.y, instruction.size.x, instruction.size.y],
		"bracket_center": [center.x, center.y], "stroke_rects_intersect": intersects, "stable_reference": stable,
		"bracket_z": brackets.z_index, "readout_z": readout.z_index, "hud_layer": g.hud.layer,
		"visible_png": shown_path, "reference_png": reference_path,
		"scope": "Borrowed frozen boss pose; direct comfort setting and child visibility. White glyph-core/gold mask on native sRGB PNGs, not OCR or whole-image equality. No ordinary fight claim; native visual review required."}
	q._check("panel_brackets.reference_valid", valid, result)
	q._check("panel_brackets.exact_contract", expected, result)
	brackets.visible = saved_visible
	boss.global_position = saved_position
	g.settings["hud_clearance"] = saved_setting
	await q.r.frames(2)
	q._check("panel_brackets.restored", boss.global_position == saved_position and brackets.visible == saved_visible
		and bool(g.settings.get("hud_clearance", true)) == saved_setting, "borrowed pose, preference and child visibility restored")
	return result
