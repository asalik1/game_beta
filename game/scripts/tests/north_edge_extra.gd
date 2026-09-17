extends RefCounted
## Optional strict-only extension called at the base probe's settled north view.
## Reuses its receipt, input walk, capture, and checks. No production fix API.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const Clearance := preload("res://scripts/ui/hud_clearance.gd")
var q: RefCounted
var g: Game
var p: Player
var h: Hud
var motions: Array[Dictionary] = []
var stability: Array[Dictionary] = []
var transitions := {}
var panel_brackets := {}


static func run(probe: RefCounted) -> Dictionary:
	var helper := new()
	helper.q = probe
	helper.g = probe.g
	helper.p = probe.p
	helper.h = probe.g.hud
	await helper._exercise()
	return {"motion": helper.motions, "stability": helper.stability, "cast_transitions": helper.transitions, "panel_brackets": helper.panel_brackets,
		"scope": "Optional strict presentation controls. Existing long quest copy is lent directly to production HUD layout, not campaign progression. One existing registered NPC is temporarily posed nearby; normal selection shows its real Talk prompt without action. Real factory wolf/Morwen and direct cast model start are frozen lateral target fixtures with the real zero-camera-lead comfort preference; hero, game camera and ordinary target/reticle updates stay live. Default lead is restored before menu/room return. No default-lead target composition, damaging cast, earned fight, latency or physical-device claim. Menu and room changes use production methods directly."}


func _exercise() -> void:
	var north_position := p.global_position
	var old_quest := h.quest_label.text.trim_prefix("◆  ")
	var old_lead: float = float(g.settings.get("camera_lead", 1.0))
	var old_splash := h._boss_splash_shown.duplicate(true)
	# Use only the existing fixture's quest copy. apply_case would also forge
	# labels/target visibility; real target cases below must retain live values.
	h.set_quest(String(Geometry.CASES[1].quest))
	await q.r.sim_wait(1.2)
	q._check("extra.wrapped_lines", h.quest_label.get_line_count() > 1,
		{"lines": h.quest_label.get_line_count(), "text": h.quest_label.text})
	await _capture("extra_wrapped")
	await _stable("wrapped_idle")
	await _walk_observed("extra_inward", north_position.y + 150.0)
	await q.r.sim_wait(1.2)
	await _stable("inward_idle")
	await _walk_observed("extra_outward", north_position.y)
	await q.r.sim_wait(1.2)
	await _stable("outward_idle")
	# Zero lead is a real comfort preference, not a frozen or moved camera.
	g.settings["camera_lead"] = 0.0
	await q.r.sim_wait(1.5)
	q._check("extra.zero_lead", g._cam_look.length() < 0.75,
		{"look": _v(g._cam_look), "camera_offset": _v(g.camera.offset)})
	await _capture("extra_zero_lead")
	# Keep this comfort setting for target-family isolation. Default focus
	# offset at this edge can move the hero beyond the viewport independently
	# of tracker placement; that is a separate composition investigation.
	await _npc_reservation()

	# Lateral positive controls leave a legal lane; crowded no-fit fallback
	# behavior is a separate control, not an exemption to north clearance.
	var wolf := Enemy.make(g, "wolf", g.free_spawn_pos(p.global_position + Vector2(480, 320), p.global_position), 1)
	wolf.zone_idx = q.room
	g.world.add_child(wolf)
	wolf.set_physics_process(false)
	p.locked_target = wolf
	await q.r.sim_wait(1.2)
	q._check("extra.mob_target", h.target_bar_unit == wolf and h.mob_box.is_visible_in_tree()
		and g.reticle.visible and g.reticle.global_position.distance_to(wolf.global_position) < 0.1,
		{"name": h.mob_name.text, "reticle": _v(g.reticle.global_position), "target": _v(wolf.global_position)})
	q._check("extra.mob_in_frame", g.get_viewport_rect().encloses(Clearance.body_rect(wolf)),
		{"body": Geometry.rect(Clearance.body_rect(wolf))})
	await _capture("extra_mob")
	wolf.vuln_time = 30.0
	await q.r.sim_wait(0.4)
	q._check("extra.cue_visible", h.combat_feedback.target_cue.is_visible_in_tree(), h.combat_feedback.target_cue.text)
	await _capture("extra_cue")
	var cue: Label = h.combat_feedback.target_cue
	var cue_shape := Geometry.shaped(cue)
	q._check("extra.cue_full_text", cue_shape.missing.is_empty() and cue_shape.count > 0
		and cue.get_global_rect().encloses(Geometry.to_rect(cue_shape.cells))
		and not cue.clip_text and cue.visible_ratio == 1.0, cue_shape)
	q._check("extra.cue_clear", not cue.get_global_rect().intersects(Clearance.body_rect(p))
		and not cue.get_global_rect().intersects(h.quest_panel.get_global_rect())
		and not cue.get_global_rect().intersects(h.mob_fill.get_global_rect()), cue_shape)
	p.locked_target = null
	p.soft_target = null
	wolf.queue_free()
	await q.r.frames(3)

	var boss := Boss.make_boss(g, "morwen", g.free_spawn_pos(p.global_position + Vector2(580, 320), p.global_position))
	boss.zone_idx = q.room
	g.world.add_child(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	h._boss_splash_shown[boss.display_name] = true
	g.bosses.append(boss)
	g.current_boss = boss
	p.locked_target = boss
	await q.r.sim_wait(1.2)
	q._check("extra.boss_target", h.target_bar_unit == boss and h.boss_box.is_visible_in_tree()
		and g.reticle.visible and g.reticle.global_position.distance_to(boss.global_position) < 0.1,
		{"name": h.boss_name.text, "hp": h.boss_hp_num.text, "reticle": _v(g.reticle.global_position)})
	q._check("extra.boss_in_frame", g.get_viewport_rect().encloses(Clearance.body_rect(boss)),
		{"body": Geometry.rect(Clearance.body_rect(boss))})
	await _capture("extra_boss")
	q._check("extra.cast_started", boss.cast_window.start("morwen", boss.max_hp), boss.cast_window.snapshot())
	await q.r.sim_wait(1.2)
	q._check("extra.cast_visible", h.boss_cast_readout.is_visible_in_tree()
		and h.boss_cast_readout.get("boss") == boss and boss.cast_window.phase == "windup",
		boss.cast_window.snapshot())
	await _capture("extra_cast")
	if q.r.flag("brackets"):
		transitions = await preload("res://scripts/tests/cast_transition_live.gd").run(q, boss)
	if q.r.flag("panel-brackets"):
		panel_brackets = await preload("res://scripts/tests/panel_bracket_live.gd").run(q, boss)
	boss.cast_window.cancel()
	p.locked_target = null
	p.soft_target = null
	g.current_boss = null
	g.bosses.erase(boss)
	boss.queue_free()
	h._boss_splash_shown = old_splash
	await q.r.frames(3)
	g.settings["camera_lead"] = old_lead
	await q.r.sim_wait(1.2)

	g.menus.open_pause()
	await q.r.frames(3)
	q._check("extra.menu_open", g.menus.is_open() and q.r.get_tree().paused,
		"production solo pause menu; no native-button claim")
	g.menus.close()
	await q.r.sim_wait(1.2)
	q._check("extra.menu_closed", not g.input_overlay_up() and not q.r.get_tree().paused
		and p.is_physics_processing(), "normal hero/camera processing restored")
	await _capture("extra_menu_return")

	# Direct room re-entry is a reset/lifetime control, not a walked doorway.
	var away := 0 if int(q.room) != 0 else 1
	p.global_position = g.room_center(away)
	g._enter_room(away)
	g.terrain_event_t = 10000.0
	await q.r.skip_dialogue()
	await q.r.sim_wait(0.5)
	q._check("extra.away_room", g.cur_room == away, {"wanted": away, "actual": g.cur_room})
	p.global_position = north_position
	g._enter_room(int(q.room))
	g.terrain_event_t = 10000.0
	await q.r.skip_dialogue()
	# Entry refreshes the real quest. Restore that exact pre-fixture copy.
	h.set_quest(old_quest)
	await q.r.sim_wait(1.5)
	q._check("extra.quest_restored", h.quest_label.text == "◆  " + old_quest,
		{"actual": h.quest_label.text, "expected": old_quest})
	q._check("extra.room_return", g.cur_room == int(q.room) and p.global_position.distance_to(north_position) < 1.0,
		{"position": _v(p.global_position), "expected": _v(north_position)})
	await _capture("extra_room_return")
	await _stable("room_return_idle")


func _npc_reservation() -> void:
	var entry := {}
	for candidate in g.interactables:
		var node := candidate.get("node") as Node2D
		var prompt := candidate.get("prompt") as Label
		var sprite := candidate.get("sprite") as Sprite2D
		if is_instance_valid(node) and is_instance_valid(prompt) and is_instance_valid(sprite) \
				and g.world.is_ancestor_of(node) and sprite.is_visible_in_tree() \
				and prompt.text.to_lower().contains("talk"):
			entry = candidate
			break
	q._check("extra.npc_registered", not entry.is_empty(), "existing factory registry entry with real Talk copy and visible sprite")
	if entry.is_empty(): return
	var npc: Node2D = entry.node
	var prompt: Label = entry.prompt
	var sprite: Sprite2D = entry.sprite
	var saved_position := npc.global_position
	var flags := g.flags.duplicate(true)
	var conversations := g.convo_log.duplicate(true)
	var gold := p.gold
	var xp := p.xp
	npc.global_position = p.global_position + Vector2(0, 70)
	await q.r.sim_wait(1.2)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var shaped := Geometry.shaped(prompt)
	# Geometry.shaped returns global (world) cells for a world Label; convert
	# through its own canvas, then include pill and outline for the reservation.
	var world_cells := Geometry.to_rect(shaped.cells)
	var local_cells := prompt.get_global_transform().affine_inverse() * world_cells
	var outer_local := Rect2(Vector2.ZERO, prompt.size).merge(
		local_cells.grow(float(prompt.get_theme_constant("outline_size"))))
	var outer := prompt.get_global_transform_with_canvas() * outer_local
	var npc_rect := sprite.get_global_transform_with_canvas() * sprite.get_rect()
	var tracker := h.quest_panel.get_global_rect()
	var visible_prompts := 0
	for candidate in g.interactables:
		var label := candidate.get("prompt") as Label
		if is_instance_valid(label) and label.is_visible_in_tree(): visible_prompts += 1
	var evidence := {"name": String(entry.get("sprite_name", "")), "distance": p.global_position.distance_to(npc.global_position),
		"reach": float(entry.get("reach", Balance.INTERACT_RANGE)), "prompt": shaped,
		"prompt_outer_canvas": Geometry.rect(outer), "npc_sprite_cell_canvas": Geometry.rect(npc_rect),
		"tracker": Geometry.rect(tracker), "visible_prompts": visible_prompts,
		"npc_position": _v(npc.global_position), "saved_position": _v(saved_position)}
	q._check("extra.npc_selected", g.interact_in_range and prompt.is_visible_in_tree() and visible_prompts == 1
		and float(evidence.distance) < float(evidence.reach), evidence)
	q._check("extra.npc_prompt_complete", shaped.missing.is_empty() and int(shaped.count) > 0
		and not prompt.clip_text and prompt.visible_ratio >= 1.0 and prompt.max_lines_visible == -1
		and prompt.get_line_count() == prompt.get_visible_line_count()
		and Rect2(Vector2.ZERO, prompt.size).grow(0.5).encloses(local_cells), evidence)
	q._check("extra.npc_on_screen", g.get_viewport_rect().encloses(outer)
		and g.get_viewport_rect().encloses(npc_rect), evidence)
	q._check("extra.npc_prompt_clear", not tracker.intersects(outer), evidence)
	q._check("extra.npc_sprite_clear", not tracker.intersects(npc_rect), evidence)
	await _capture("extra_npc_prompt")
	q.views[-1]["npc_reservation"] = evidence
	npc.global_position = saved_position
	await q.r.sim_wait(1.2)
	q._check("extra.npc_restored", npc.global_position == saved_position and g.flags == flags
		and g.convo_log == conversations and p.gold == gold and p.xp == xp and not g.input_overlay_up(),
		"borrowed factory NPC restored; no interact action, dialogue, flag or reward side effect")


func _capture(id: String) -> void:
	await q._capture(id, false)
	var observed := Geometry.inspect(h)
	for check in observed.checks:
		q._check(id + ".geometry/" + String(check.id), bool(check.passed), check.details)
	var body := Clearance.body_rect(p)
	# Geometry.inspect already measures shaped label cells and actual fills.
	# Check the occupied visible pieces, not full-rect container parents.
	for key in observed.rects:
		if key in ["vitals", "tracker", "viewport"]: continue
		var rect := Geometry.to_rect(observed.rects[key])
		q._check(id + ".hero_clear/" + String(key), not body.intersects(rect),
			{"body": Geometry.rect(body), "occupied": Geometry.rect(rect)})
	q.views[-1]["alignment"] = observed


func _frame() -> Dictionary:
	return {"physics_frame": Engine.get_physics_frames(), "hero": _v(p.global_position),
		"body": Geometry.rect(Clearance.body_rect(p)), "tracker": Geometry.rect(h.quest_panel.get_global_rect()),
		"camera_offset": _v(g.camera.offset), "camera_zoom": _v(g.camera.zoom),
		"target_boxes": [_v(h.mob_box.position), _v(h.boss_box.position), _v(h.boss_cast_readout.position)]}


func _walk_observed(id: String, target_y: float) -> void:
	var samples: Array[Dictionary] = []
	var sampler := func() -> void: samples.append(_frame())
	q.r.get_tree().process_frame.connect(sampler)
	await q._walk(id, target_y)
	q.r.get_tree().process_frame.disconnect(sampler)
	motions.append({"id": id, "samples": samples})
	var finite := true
	for row in samples:
		for field in ["hero", "body", "tracker", "camera_offset", "camera_zoom"]:
			for value in row[field]: finite = finite and is_finite(float(value))
	q._check(id + ".finite_frames", samples.size() > 2 and finite, {"samples": samples.size()})
	# Do not assert zero overlap on the first moving frame or a particular
	# easing curve. The motion trace exposes transitions for independent review.


func _stable(id: String) -> void:
	var samples: Array[Dictionary] = []
	var first := h.quest_panel.global_position
	var largest := 0.0
	var deadline := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < deadline:
		await q.r.get_tree().process_frame
		samples.append(_frame())
		largest = maxf(largest, h.quest_panel.global_position.distance_to(first))
	stability.append({"id": id, "samples": samples, "maximum_tracker_drift": largest})
	q._check(id + ".settled_tracker", samples.size() >= 3 and largest <= 0.75,
		{"samples": samples.size(), "max_drift": largest, "tolerance": 0.75})
	q._check(id + ".settled_clear", not Clearance.body_rect(p).intersects(h.quest_panel.get_global_rect()),
		_frame())


func _v(value: Vector2) -> Array:
	return [value.x, value.y]
