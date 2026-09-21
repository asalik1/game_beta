extends RefCounted
## Existing real arrival/input first; optional borrowed presentation controls last.
var q
var g: Game
var p: Player
var entry: Dictionary
var prompt: Label
var sprite: Sprite2D
var anchor := Vector2.ZERO
var views: Array[Dictionary] = []
var input_observations: Array[Dictionary] = []
var failures := 0
var borrowed := {}
var alternative_min_width := Vector2.ZERO
var alternative_min_width_loaned := false
var alternative_size := Vector2.ZERO
var alternative_contract: Dictionary = {}


static func run(parent: RefCounted) -> Dictionary:
	var probe := new()
	probe.q = parent
	probe.g = parent.g
	probe.p = parent.p
	var error := await probe._exercise()
	await probe._restore()
	return {"error": error if error != "" else "NPC prompt checks failed" if probe.failures > 0 else "",
		"views": probe.views, "input_observations": probe.input_observations, "failures": probe.failures, "controlled": parent.r.flag("npc-prompt-controls"),
		"alternatives": parent.r.flag("npc-prompt-alternatives"),
		"scope": "Existing real travel/A movement, selected Voss, native Inventory/Escape/E/Leave. Optional display-only controls freeze Game/Player physics and borrow vitals position/camera offset; no actor pose/resource reset. Alpha >=0.15 bounds include carried art. Optional alternatives mode borrows the same display state plus a label minimum-width loan; its impossible-fit frame is a supplemental unreadable control, never visual acceptance. No physical-device/network/crowd claim; originals require review.",
		"sources": {"game": FileAccess.get_sha256("res://scripts/game.gd"),
			"factory": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"tracker": FileAccess.get_sha256("res://scripts/ui/tracker_clearance.gd"),
			"balance": FileAccess.get_sha256("res://scripts/balance.gd"),
			"helper": FileAccess.get_sha256("res://scripts/tests/npc_prompt_live.gd")}}


func _check(id: String, okay: bool, detail: Variant) -> bool:
	if not okay: failures += 1
	return q._check("npc_prompt." + id, okay, detail) # strict diagnostic; no invented baseline whitelist


func _exercise() -> String:
	if q.r.flag("npc-prompt-alternatives") and q.r.flag("npc-prompt-controls"):
		_check("alt.exclusive", false, "Old fallback and new alternative contracts are separate episodes")
		return "Do not combine old controls and alternatives"
	if not _check("exclusive", not q.r.flag("baseline") and not q.r.flag("arrival-consumers")
			and not q.r.flag("fountain-prompt") and not q.r.flag("no-capture"), "isolated strict NPC continuation"):
		return "NPC mode cannot be combined with baseline/other episodes/no-capture"
	for candidate in g.interactables:
		var label := candidate.get("prompt") as Label
		if is_instance_valid(label) and label.is_visible_in_tree():
			entry = candidate
			break
	if not _check("actual_voss", not entry.is_empty() and String(entry.get("sprite_name", "")) == "clerk_voss"
			and String(entry.node.get_meta("quest_convo", "")) == "cap_voss", "naturally selected after real A"):
		return "ordinary A route did not select original Clerk Voss"
	prompt = entry.prompt
	sprite = entry.sprite
	anchor = prompt.get_meta("npc_prompt_anchor", prompt.position)
	if not _check("paintable", _painted(sprite).has_area() and _painted(p.sprite).has_area(), "current simple Sprite2D frames readable"):
		return "unsupported/empty source texture for independent alpha oracle"
	await q.r.sim_wait(0.5)
	var economy: Dictionary = q._fountain_economy()
	var before := _pose()
	var initial := await _view("03_npc_live", true)
	_check("authored_overlap_witness", bool(initial.authored_overlap), initial)
	if not await _polled_key(int(g.binds.inventory), "inventory"):
		return "Inventory press did not meet native hold prerequisites"
	await q.r.frames(3)
	_check("menu_hides", g.menus.current == "inventory" and g.menus.is_open()
		and not prompt.is_visible_in_tree(), "actual Inventory input, existing hide policy")
	await RenderingServer.frame_post_draw
	q.r.shot("04_npc_inventory", "native inventory opens; selected world prompt must hide")
	await q.ui._key(KEY_ESCAPE)
	await q.r.sim_wait(0.65) # let the ordinary interaction/menu cooldown expire
	if not _check("menu_closed", not g.input_overlay_up() and not g.get_tree().paused, "actual Escape returns to play"):
		return "Inventory did not close"
	await _view("05_npc_menu_returned", true)
	var before_dialogue: Vector2 = prompt.position
	if not await _polled_key(int(g.binds.interact), "interact"):
		return "Interact press did not meet native hold prerequisites"
	await q.r.frames(3)
	var conversation: bool = g.hud.choices_active and g.hud.speaker_label.text == "Clerk Voss"
	_check("real_interact", conversation, "native E -> actual Voss choice, not direct action call")
	_check("dialogue_holds_placement", prompt.position.distance_to(before_dialogue) <= 0.01,
		{"before": q._vec(before_dialogue), "during": q._vec(prompt.position)})
	# Dialogue has no menu-style prompt-hide contract. Preserve the visible
	# upper placement instead of resetting it into the two heads on entry.
	views.append({"id": "dialogue_prompt", "visible": prompt.is_visible_in_tree(),
		"before_local_position": q._vec(before_dialogue),
		"local_position": q._vec(prompt.position), "overlay": g.input_overlay_up()})
	await _view("06_npc_conversation", true)
	var leave: Label
	for option in g.hud.choice_option_labels:
		if option.is_visible_in_tree() and option.text.ends_with("(Leave)"): leave = option
	if not _check("leave_available", conversation and is_instance_valid(leave), "actual Leave option"):
		return "actual Voss Leave choice unavailable"
	await q.ui._mouse(leave.get_global_rect().get_center())
	await q.r.frames(4)
	_check("returned", not g.input_overlay_up() and not g.get_tree().paused and prompt.is_visible_in_tree(), "native Leave and ordinary selector")
	_check("rest_pose", _pose() == before, {"before": before, "after": _pose()})
	_check("no_reward", q._fountain_economy() == economy, "Leave: economy/flags/settings/binds unchanged; dialogue history records naturally")
	await _view("07_npc_returned", true)
	_check("keys_released", not Input.is_key_pressed(int(g.binds.interact))
		and not Input.is_key_pressed(int(g.binds.inventory)) and not Input.is_key_pressed(KEY_ESCAPE)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "all native presses released")
	if q.r.flag("npc-prompt-controls"):
		if failures > 0: return "controls require a passing actual upper-lane witness"
		await _controls()
	if q.r.flag("npc-prompt-alternatives"):
		if failures > 0: return "alternatives require a passing actual upper-lane journey witness"
		var alternative_error: String = await _alternatives()
		if alternative_error != "": return alternative_error
	return ""


func _polled_key(code: int, label: String) -> bool:
	# Called after post-draw: one process_frame await resumes BEFORE Game's
	# next _process. Hold one native edge across a complete process and physics
	# iteration, never manually invoke either consumer or retry the action.
	var row := {"id": label, "code": code, "before": q._input_state(),
		"process_start": Engine.get_process_frames(), "physics_start": Engine.get_physics_frames()}
	if not _check("input." + label + ".ready", not Input.is_key_pressed(code)
			and g.can_process() and not g.input_overlay_up() and not g.get_tree().paused
			and g.talk_cd <= 0.0 and p.is_physics_processing(), row):
		input_observations.append(row)
		return false
	var started := Time.get_ticks_msec()
	q.held_key = code # outer rig cleanup can release this same single hold
	q._key(code, true)
	row["after_press"] = q._input_state()
	await q.r.frames(2)
	row["after_process"] = {"state": q._input_state(), "down": Input.is_key_pressed(code)}
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	await RenderingServer.frame_post_draw
	row["before_release"] = {"state": q._input_state(), "down": Input.is_key_pressed(code)}
	row["elapsed_ms"] = Time.get_ticks_msec() - started
	q._key(code, false)
	q.held_key = 0
	q.ui.key_taps += 1
	await q.r.frames(2)
	row["after_release"] = q._input_state()
	input_observations.append(row)
	return _check("input." + label + ".complete_hold", bool(row.after_process.down)
		and bool(row.before_release.down) and not Input.is_key_pressed(code)
		and int(row.before_release.state.process_frame) - int(row.process_start) >= 2
		and int(row.before_release.state.physics_frame) - int(row.physics_start) >= 2
		and int(row.elapsed_ms) < 1000, row)


func _pose() -> Dictionary:
	return {"texture": sprite.texture.get_instance_id(), "hframes": sprite.hframes,
		"vframes": sprite.vframes, "scale": sprite.scale, "offset": sprite.offset,
		"flip_h": sprite.flip_h, "flip_v": sprite.flip_v}


func _rect(value: Dictionary) -> Rect2:
	return Rect2(Vector2(value.position[0], value.position[1]), Vector2(value.size[0], value.size[1]))


func _painted(spr: Sprite2D) -> Rect2:
	# Independent selected-frame alpha oracle; no production placement/body call.
	if spr.texture == null or spr.region_enabled or spr.texture is AtlasTexture: return Rect2()
	var image: Image = spr.texture.get_image()
	if image == null: return Rect2()
	var size := Vector2i(image.get_width() / spr.hframes, image.get_height() / spr.vframes)
	var origin: Vector2i = spr.frame_coords * size
	var lo := size
	var hi := Vector2i(-1, -1)
	for y in size.y:
		for x in size.x:
			if image.get_pixel(origin.x + x, origin.y + y).a >= 0.15:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0: return Rect2()
	var used := Rect2(Vector2(lo), Vector2(hi - lo + Vector2i.ONE))
	if spr.flip_h: used.position.x = float(size.x) - used.end.x
	if spr.flip_v: used.position.y = float(size.y) - used.end.y
	used.position += spr.offset - (Vector2(size) * 0.5 if spr.centered else Vector2.ZERO)
	return spr.get_global_transform_with_canvas() * used


func _geometry() -> Dictionary:
	var full: Dictionary = q._fountain_geometry(prompt, entry)
	var bounds := _rect(full.prompt.outer)
	var hero := _painted(p.sprite)
	var npc := _painted(sprite)
	var authored := bounds
	var owner := prompt.get_parent() as CanvasItem
	authored.position += owner.get_global_transform_with_canvas().basis_xform(anchor - prompt.position)
	return {"full": full, "bounds": q._fountain_rect(bounds), "hero": q._fountain_rect(hero),
		"npc": q._fountain_rect(npc), "authored": q._fountain_rect(authored),
		"authored_overlap": authored.intersects(hero) or authored.intersects(npc),
		"hero_clear": not bounds.intersects(hero), "npc_clear": not bounds.intersects(npc),
		"local_position": q._vec(prompt.position), "z": prompt.z_index,
		"hero_world": q._vec(p.global_position), "npc_world": q._vec(entry.node.global_position),
		"tracker": q._fountain_rect(g.hud.quest_panel.get_global_rect())}


func _view(label: String, require_clear: bool) -> Dictionary:
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var row := _geometry()
	row["id"] = label
	views.append(row)
	var full: Dictionary = row.full
	_check(label + ".selected", full.prompt_visible and full.visible_prompts == 1
		and full.distance < full.reach and g.interact_in_range, full)
	_check(label + ".copy", full.full_text and full.prompt.text == g.touchify("E — Clerk Voss")
		and prompt.z_index == 2 and full.prompt.alpha >= 0.99, full.prompt)
	_check(label + ".viewport", full.on_screen, full.prompt)
	_check(label + ".hud", full.tracker_clear and full.header_complete and full.other_hud_hits.is_empty(), full)
	if require_clear:
		_check(label + ".hero_clear", row.hero_clear, row)
		_check(label + ".npc_clear", row.npc_clear, row)
	q.r.shot(label, "NPC prompt: independent alpha bounds and complete glyphs; episode scope in receipt")
	return row


func _controls() -> void:
	# No actor placement/resource restoration. Drain at the unchanged location.
	await q.r.frames(2)
	borrowed = {"game_process": g.is_processing(), "physics": p.is_physics_processing(),
		"camera_offset": g.camera.offset, "vitals_position": g.hud.vitals_panel.position,
		"economy": q._fountain_economy(), "hero_world": p.global_position, "npc_world": entry.node.global_position}
	g.set_process(false)
	p.set_physics_process(false)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var clear := _geometry()
	var panel: Control = g.hud.vitals_panel
	var moved_prompt := _rect(clear.bounds)
	var authored := _rect(clear.authored)
	# Block the previously OBSERVED passing upper lane, not a copied solver result.
	panel.position = Vector2(moved_prompt.get_center().x - panel.size.x * 0.5,
		minf(moved_prompt.end.y + 1.0, authored.position.y - 2.0) - panel.size.y)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	_check("hud_control.setup", panel.get_global_rect().intersects(moved_prompt)
		and not panel.get_global_rect().intersects(authored), "real vitals blocks observed upper lane only")
	await _view("08_npc_hud_fallback", false)
	_check("hud_control.fallback", prompt.position.distance_to(anchor) <= 0.01, "complete original anchor retained")
	panel.position = borrowed.vitals_position
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var current := _geometry()
	var top := minf(_rect(current.hero).position.y, _rect(current.npc).position.y)
	var height := _rect(current.bounds).size.y
	# Top-right space above minimap: painted heads remain on-screen, with less
	# than one pill-height above them. No world actor coordinates are assigned.
	var screen_shift := Vector2(g.hud.minimap_root.get_global_rect().get_center().x
		- _rect(current.bounds).get_center().x, height * 0.5 - top)
	g.camera.offset -= g.get_viewport().get_canvas_transform().affine_inverse().basis_xform(screen_shift)
	await q.r.frames(4)
	await RenderingServer.frame_post_draw
	var edge := _geometry()
	var edge_top := minf(_rect(edge.hero).position.y, _rect(edge.npc).position.y)
	_check("viewport_control.setup", edge_top > 0.0 and edge_top < _rect(edge.bounds).size.y,
		"independent painted head bound leaves less than one pill above; normal HUD remains visible")
	await _view("09_npc_viewport_fallback", false)
	_check("viewport_control.fallback", prompt.position.distance_to(anchor) <= 0.01, "readable authored fallback")
	await _restore()
	await _view("10_npc_restored", true)


## Optional alternatives mode: an upper-lane obstruction must yield a readable
## side/below placement, judged only by independent measurement. It borrows the
## same display state as _controls plus a label minimum-width loan; it never
## invokes or reimplements the production candidate solver.
func _alternatives() -> String:
	alternative_contract = _alternative_contract()
	var error: String = await _alternatives_body()
	await _alternatives_cleanup()
	if error != "": return error
	await _view("14_npc_alternatives_restored", true)
	return ""


func _alternatives_body() -> String:
	await q.r.frames(2)
	borrowed = {"game_process": g.is_processing(), "physics": p.is_physics_processing(),
		"camera_offset": g.camera.offset, "vitals_position": g.hud.vitals_panel.position,
		"economy": q._fountain_economy(), "hero_world": p.global_position, "npc_world": entry.node.global_position}
	g.set_process(false)
	p.set_physics_process(false)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var clear: Dictionary = _geometry()
	var panel: Control = g.hud.vitals_panel
	var moved_prompt: Rect2 = _rect(clear.bounds)
	var authored: Rect2 = _rect(clear.authored)
	# Same real-vitals obstruction idiom as _controls: cover the previously
	# OBSERVED upper lane only; the authored anchor rectangle stays untouched.
	panel.position = Vector2(moved_prompt.get_center().x - panel.size.x * 0.5,
		minf(moved_prompt.end.y + 1.0, authored.position.y - 2.0) - panel.size.y)
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	if not _check("alt.setup", panel.get_global_rect().intersects(moved_prompt)
			and not panel.get_global_rect().intersects(authored), "real vitals blocks the observed upper lane only"):
		return "alternative-lane obstruction setup failed"
	await _alternative_view("11_npc_alternative")
	panel.position = borrowed.vitals_position
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	# Independent second setup: less than a pill above the actual painted heads.
	# It may select a different side/below lane; it is not an impossible-fit loan.
	var current: Dictionary = _geometry()
	var top: float = minf(_rect(current.hero).position.y, _rect(current.npc).position.y)
	var height: float = _rect(current.bounds).size.y
	var screen_shift := Vector2(g.hud.minimap_root.get_global_rect().get_center().x
		- _rect(current.bounds).get_center().x, height * 0.5 - top)
	g.camera.offset -= g.get_viewport().get_canvas_transform().affine_inverse().basis_xform(screen_shift)
	await q.r.frames(4)
	await RenderingServer.frame_post_draw
	var edge: Dictionary = _geometry()
	var edge_top: float = minf(_rect(edge.hero).position.y, _rect(edge.npc).position.y)
	if not _check("alt.viewport_setup", edge_top > 0.0 and edge_top < _rect(edge.bounds).size.y,
			"Actual heads are on-screen with less than one pill of top space"):
		return "alternative viewport setup failed"
	await _alternative_view("12_npc_viewport_alternative")
	g.camera.offset = borrowed.camera_offset
	await q.r.frames(4)
	return await _impossible_fit()


func _alternative_view(label: String) -> Dictionary:
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	var row: Dictionary = _geometry()
	row["id"] = label
	var full: Dictionary = row.full
	var bounds: Rect2 = _rect(full.prompt.outer)
	var hero: Rect2 = _rect(row.hero)
	var npc_body: Rect2 = _rect(row.npc)
	var authored: Rect2 = _rect(row.authored)
	var bottom_hud: Array[Dictionary] = _declared_extra_hud()
	var bottom_hits: Array[Dictionary] = []
	for extra: Dictionary in bottom_hud:
		if bounds.intersects(_rect(extra.rect).grow(-0.5)): bottom_hits.append(extra)
	var displaced_x: bool = absf(bounds.get_center().x - authored.get_center().x) > 0.5
	var below_both: bool = bounds.position.y >= maxf(hero.end.y, npc_body.end.y) - 0.01
	row["bottom_hud"] = bottom_hud
	row["bottom_hud_hits"] = bottom_hits
	row["displaced_x"] = displaced_x
	row["below_both_bodies"] = below_both
	views.append(row)
	_check(label + ".selected", full.prompt_visible and full.visible_prompts == 1
		and full.distance < full.reach and g.interact_in_range, full)
	_check(label + ".copy", full.full_text and full.prompt.text == g.touchify("E — Clerk Voss")
		and prompt.z_index == 2 and full.prompt.alpha >= 0.99, full.prompt)
	_check(label + ".viewport", full.on_screen, full.prompt)
	_check(label + ".hud", full.tracker_clear and full.header_complete and full.other_hud_hits.is_empty()
		and bottom_hits.is_empty(), row)
	_check(label + ".hero_clear", row.hero_clear, row)
	_check(label + ".npc_clear", row.npc_clear, row)
	# Either side is acceptable; no single direction is claimed proven. An
	# unchanged overlapping authored placement cannot satisfy this contract.
	_check(label + ".contract", _alternative_contract() == alternative_contract,
		"Actual action/reach/art/font/pill contract is unchanged during this placement")
	_check(label + ".alternate_lane", displaced_x or below_both,
		{"displaced_x": displaced_x, "below_both_bodies": below_both,
		"bounds": q._fountain_rect(bounds), "authored": row.authored})
	q.r.shot(label, "NPC prompt alternative lane: obstructed upper lane; independent side/below acceptance")
	return row


func _declared_extra_hud() -> Array[Dictionary]:
	# Actual declared controls, independently read: no production blocker API.
	# Top vitals/info/minimap/tracker are already measured by _fountain_geometry.
	var rects: Array[Dictionary] = []
	for field: String in ["boss_box", "mob_box", "rival_box", "chat_input"]:
		_extra_hud_tree(rects, g.hud.get(field), field)
	_extra_hud_tree(rects, g.hud.wayfinder.quest_root, "wayfinder")
	_extra_hud_tree(rects, g.hud.combat_feedback.target_cue, "target_cue")
	for i in g.hud.party_slots.size():
		_extra_hud_tree(rects, g.hud.party_slots[i].root, "party_%d" % i)
	for i in g.hud.slot_boxes.size():
		for key: String in ["border", "name"]:
			_extra_hud_tree(rects, g.hud.slot_boxes[i][key], "ability_%d_%s" % [i, key])
	for i in g.hud._log_lines.size():
		_extra_hud_tree(rects, g.hud._log_lines[i], "reward_%d" % i)
	if is_instance_valid(g._touch_hud) and g._touch_hud.visible:
		_extra_hud_tree(rects, g._touch_hud, "touch")
	return rects


func _extra_hud_tree(out: Array[Dictionary], candidate: Variant, field: String) -> void:
	if not is_instance_valid(candidate) or not candidate is Node: return
	var node: Node = candidate
	if node is CanvasItem and (not node.is_visible_in_tree() or q._fountain_alpha(node) <= 0.01): return
	if node is Control and node.size.x > 0.0 and node.size.y > 0.0:
		var bounds: Rect2 = node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		if node is Label:
			if node.text.is_empty(): return
			bounds = _rect(q._fountain_text(node).outer)
		out.append({"field": field, "rect": q._fountain_rect(bounds)})
	for child in node.get_children(): _extra_hud_tree(out, child, field + "/" + String(child.name))


func _alternative_contract() -> Dictionary:
	var pill: StyleBox = prompt.get_theme_stylebox("normal")
	var fill: Dictionary = {}
	if pill is StyleBoxFlat:
		fill = {"background": pill.bg_color, "border": pill.border_color,
			"border_widths": [pill.border_width_left, pill.border_width_top, pill.border_width_right, pill.border_width_bottom],
			"corners": [pill.corner_radius_top_left, pill.corner_radius_top_right, pill.corner_radius_bottom_left, pill.corner_radius_bottom_right]}
	return {"node": entry.node.get_instance_id(), "sprite": sprite.get_instance_id(),
		"prompt": prompt.get_instance_id(), "action": entry.action, "reach": entry.reach,
		"pose": _pose(), "copy": prompt.text, "z": prompt.z_index,
		"font": prompt.get_theme_font("font").get_instance_id(), "font_size": prompt.get_theme_font_size("font_size"),
		"font_color": prompt.get_theme_color("font_color"), "outline_color": prompt.get_theme_color("font_outline_color"),
		"outline_size": prompt.get_theme_constant("outline_size"), "pill": pill.get_instance_id(),
		"fill": fill, "margins": [pill.get_content_margin(SIDE_LEFT), pill.get_content_margin(SIDE_TOP),
			pill.get_content_margin(SIDE_RIGHT), pill.get_content_margin(SIDE_BOTTOM)],
		"clip": prompt.clip_text, "ratio": prompt.visible_ratio, "max_lines": prompt.max_lines_visible,
		"wrap": prompt.autowrap_mode}


func _impossible_fit() -> String:
	# Supplemental unreadable control, never visual acceptance: a minimum-width
	# loan wider than the viewport must keep complete text at the authored
	# fallback anchor. _view() is intentionally not used here because it
	# unconditionally demands viewport enclosure.
	var viewport: Rect2 = g.get_viewport_rect()
	var screen_x_per_local_x: float = absf(prompt.get_global_transform_with_canvas().x.x)
	if not _check("impossible.axis", screen_x_per_local_x > 0.0, screen_x_per_local_x):
		return "Cannot make an X-width loan under this degenerate canvas transform"
	alternative_min_width = prompt.custom_minimum_size
	alternative_size = prompt.size
	alternative_min_width_loaned = true
	prompt.custom_minimum_size = Vector2((viewport.size.x + 64.0) / screen_x_per_local_x, prompt.custom_minimum_size.y)
	await q.r.frames(3)
	await RenderingServer.frame_post_draw
	var shape: Dictionary = q._fountain_text(prompt)
	var bounds: Rect2 = _rect(shape.outer)
	var row: Dictionary = {"id": "13_npc_impossible_fit", "shape": shape,
		"viewport": q._fountain_rect(viewport), "local_position": q._vec(prompt.position),
		"anchor": q._vec(anchor),
		"supplemental": "unreadable display-width loan; fallback/cleanup evidence only"}
	views.append(row)
	if not _check("impossible.loan_measured", bounds.size.x > viewport.size.x, row):
		return "impossible-fit loan did not exceed usable viewport width before evaluation"
	_check("impossible.style", _alternative_contract() == alternative_contract, "Only minimum/actual width is loaned")
	_check("impossible.complete_text", bool(shape.complete) and String(shape.text) == g.touchify("E — Clerk Voss")
		and float(shape.alpha) >= 0.99 and prompt.z_index == 2, shape)
	_check("impossible.fallback_anchor", prompt.position.distance_to(anchor) <= 0.01,
		{"local_position": q._vec(prompt.position), "anchor": q._vec(anchor)})
	_check("impossible.selected", prompt.is_visible_in_tree() and g.interact_in_range,
		"selection retained through the unreadable fixture")
	q.r.shot("13_npc_impossible_fit", "impossible-fit control: complete text at authored fallback; unreadable by design")
	return ""


func _alternatives_cleanup() -> void:
	if alternative_min_width_loaned and is_instance_valid(prompt):
		prompt.custom_minimum_size = alternative_min_width
		prompt.size = alternative_size
		alternative_min_width_loaned = false
		await q.r.frames(2)
		_check("alt.min_width_restored", prompt.custom_minimum_size == alternative_min_width and prompt.size == alternative_size,
			{"restored": q._vec(prompt.custom_minimum_size), "size": q._vec(prompt.size)})
	_check("alt.contract_unchanged", _alternative_contract() == alternative_contract,
		"Actual entry action/reach/identity, source art and full text/style remain unchanged")
	await _restore()


func _restore() -> void:
	if borrowed.is_empty(): return
	_check("controlled.resources", q._fountain_economy() == borrowed.economy
		and p.global_position == borrowed.hero_world and entry.node.global_position == borrowed.npc_world,
		"resources and world poses checked before restoring display state; never overwritten")
	g.hud.vitals_panel.position = borrowed.vitals_position
	g.camera.offset = borrowed.camera_offset
	p.set_physics_process(borrowed.physics)
	g.set_process(borrowed.game_process)
	_check("controlled.restore", g.hud.vitals_panel.position == borrowed.vitals_position
		and g.camera.offset == borrowed.camera_offset and p.is_physics_processing() == borrowed.physics
		and g.is_processing() == borrowed.game_process, "borrowed display state and processing restored")
	borrowed.clear()
	await q.r.frames(3)
