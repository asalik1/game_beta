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


static func run(parent: RefCounted) -> Dictionary:
	var probe := new()
	probe.q = parent
	probe.g = parent.g
	probe.p = parent.p
	var error := await probe._exercise()
	await probe._restore()
	return {"error": error if error != "" else "NPC prompt checks failed" if probe.failures > 0 else "",
		"views": probe.views, "input_observations": probe.input_observations, "failures": probe.failures, "controlled": parent.r.flag("npc-prompt-controls"),
		"scope": "Existing real travel/A movement, selected Voss, native Inventory/Escape/E/Leave. Optional display-only controls freeze Game/Player physics and borrow vitals position/camera offset; no actor pose/resource reset. Alpha >=0.15 bounds include carried art. No physical-device/network/crowd claim; originals require review.",
		"sources": {"game": FileAccess.get_sha256("res://scripts/game.gd"),
			"factory": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"tracker": FileAccess.get_sha256("res://scripts/ui/tracker_clearance.gd"),
			"balance": FileAccess.get_sha256("res://scripts/balance.gd"),
			"helper": FileAccess.get_sha256("res://scripts/tests/npc_prompt_live.gd")}}


func _check(id: String, okay: bool, detail: Variant) -> bool:
	if not okay: failures += 1
	return q._check("npc_prompt." + id, okay, detail) # strict diagnostic; no invented baseline whitelist


func _exercise() -> String:
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
