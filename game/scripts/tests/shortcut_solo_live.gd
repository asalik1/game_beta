extends RefCounted
## Local continuation after actual Fable4 and Opus account-limit responses.
## Controlled native capability/save fixture, NEVER an earned journey.
const Domain := preload("res://scripts/tests/shortcut_domain_live.gd")
const Party := preload("res://scripts/tests/shortcut_party_live.gd")
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const Painted := preload("res://scripts/tests/npc_prompt_live.gd")
const Latch := preload("res://scripts/shortcut_latch.gd")
const SLOT := 97
const DIRS := {"N": Vector2.UP, "E": Vector2.RIGHT, "S": Vector2.DOWN, "W": Vector2.LEFT}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}


static func run(r) -> String:
	var receipt := {"rig": "shortcuts --solo-controls", "posed_fixture": true,
		"scope": "host-rendered native controller/touch, two build orders, solo save/reload; no earned-route or physical-device claim",
		"checks": [], "originals": [], "loans": [], "cleanup": {}, "native_inputs": [], "error": "", "complete": false}
	var state := {"files": {}, "keys": [], "touch_down": false, "touch_pos": Vector2.ZERO,
		"pad_down": false, "saved": false, "settings_files": {}}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		state.files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		var settings_path: String = "user://settings.json" + suffix
		state.settings_files[settings_path] = FileAccess.get_file_as_bytes(settings_path) if FileAccess.file_exists(settings_path) else null
	var error: String = await _run(r, receipt, state)
	var cleanup_error: String = _cleanup(r, receipt, state)
	if cleanup_error != "":
		error += ("; " if error != "" else "") + cleanup_error
	receipt.error = error
	receipt.complete = error == ""
	var path: String = r.shot_dir + "/solo_receipt.json"
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	if mkdir_error != OK:
		return error + "; could not create solo receipt directory"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error + "; could not open solo receipt"
	file.store_string(JSON.stringify(receipt, "  "))
	file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok:
		return error + "; could not finish solo receipt"
	print("SHORTCUT SOLO RECEIPT: " + ProjectSettings.globalize_path(path))
	return error


static func _run(r, receipt: Dictionary, state: Dictionary) -> String:
	await r.boot("warrior", "ch1", false)
	var g: Game = r.game
	if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
		return "boot never reached normal playable state"
	if g.net_online() or g.guest_world or g.player.dead or g.player.hp <= 0.0:
		return "solo fixture started online or without a standing hero"
	state.saved = true
	state.settings = g.settings.duplicate(true)
	state.no_saves = g.no_saves
	state.slot = g.save_slot
	state.physics = g.player.is_physics_processing()
	state.focused = g.gamepad.focused
	state.active = g.gamepad.active
	state.device = g.gamepad.device
	state.terrain_event_t = g.terrain_event_t
	g.player.set_physics_process(false)
	g.gamepad.focused = true
	receipt.loans = ["Disposable seeded worlds reset through _wipe_chapter_flags; both endpoint rooms marked cleared before construction.",
		"Player poses before each action/crossing; physics disabled except asserted WASD crossings.",
		"Host gamepad focus=true, temporary control scheme; synthetic input is not a physical device.",
		"Dedicated slot97 main/bak/tmp restored byte-exact on normal return; save/reload uses real APIs.",
		"No god mode, combat completion, earned route, geometry-art acceptance, or arbitrary abort cleanup claim."]
	var seed_value := -1
	var edge: Dictionary = {}
	for seed_probe in range(1000, 1080):
		var probe: Game = Domain._fixture(seed_probe, true)
		var found: Dictionary = probe.shortcut_edge.duplicate(true)
		probe.free()
		if not found.is_empty() and int(found.a) != 0 and int(found.b) != 0:
			seed_value = seed_probe
			edge = found
			break
	if seed_value < 0:
		return "no candidate with both endpoints initially unbuilt in disclosed seed scan"
	receipt.seed = seed_value
	receipt.fixture_edge = edge
	var a := int(edge.a)
	var b := int(edge.b)
	var far := int(edge.far)
	var near: int = b if far == a else a
	var world_ids: Array = []
	for case_data in [[a, b, "controller"], [b, a, "touch"]]:
		var order: Array = case_data
		var mode := String(order[2])
		r.step("solo " + mode + " rebuild")
		g.no_saves = true
		g._wipe_chapter_flags()
		g.wander_seed = seed_value
		var previous_id: int = g.world.get_instance_id()
		g.switch_chapter("ch1", true)
		await r.skip_dialogue()
		if not await r._until(func() -> bool: return g.play_started and not g.input_overlay_up(), 8.0):
			return mode + ": rebuild did not become playable"
		g.player.set_physics_process(false)
		g.terrain_event_t = 10000.0
		if g.world.get_instance_id() == previous_id or world_ids.has(g.world.get_instance_id()) or g.shortcut_edge != edge:
			return mode + ": live rebuild does not match new-world seed/edge contract"
		world_ids.append(g.world.get_instance_id())
		if bool(g.built.get(a, false)) or bool(g.built.get(b, false)) or g.gates.has(g._edge_key(a, b)):
			return mode + ": endpoint/gate prebuilt before witnessed build order"
		if g._edge_unlocked(a, b) or bool(g.get_flag(String(edge.flag), false)):
			return mode + ": fresh shortcut is already open"
		for zi in [a, b]:
			g.cleared[zi] = true
			g.zone_alive[zi] = 0
		g._build_room(int(order[0]))
		if not g.gates.has(g._edge_key(a, b)):
			return mode + ": first endpoint did not build a gate"
		var first_gate_id: int = (g.gates[g._edge_key(a, b)] as Node).get_instance_id()
		g._build_room(int(order[1]))
		if not g.gates.has(g._edge_key(a, b)) or (g.gates[g._edge_key(a, b)] as Node).get_instance_id() != first_gate_id:
			return mode + ": second endpoint replaced the registered gate"
		var latch: Node2D = Latch.find(g)
		if not is_instance_valid(latch):
			return mode + ": no current far latch"
		var direction := ""
		for d in DIRS:
			if g.neighbor(far, String(d)) == near:
				direction = String(d)
		if direction == "":
			return mode + ": no cardinal neighboring endpoint"
		# Offset inward from the CURRENT latch, not the superseded old art offsets.
		var inward: Vector2 = -(DIRS[direction] as Vector2)
		var pose: Vector2 = latch.global_position + inward * 40.0 - inward.orthogonal() * 48.0
		if g.room_at_pos(pose) != far or not g.play_rect(far).has_point(pose):
			return mode + ": disclosed offset pose is outside the far playable room"
		g.player.global_position = pose
		g.player.velocity = Vector2.ZERO
		g._enter_room(far)
		await r.get_tree().physics_frame
		var pose_proof: Dictionary = _pose(g)
		_note(receipt, mode + "/pose", pose_proof)
		if not bool(pose_proof.clear):
			return mode + ": actual player shape or foot point intersects solid geometry"
		_note(receipt, mode + "/build_order", {"order": [order[0], order[1]],
			"world_id": g.world.get_instance_id(), "gate_id": first_gate_id,
			"latch_pos": _v(latch.global_position), "player_pos": _v(pose),
			"distance": pose.distance_to(latch.global_position)})
		var mode_error: String = await _mode(r, g, mode)
		if mode_error != "":
			return mode_error
		if not await r._until(func() -> bool: return g.interact_in_range and g.selected_landmark_prompt == latch.prompt and g.talk_cd <= 0.0, 6.0):
			return mode + ": ordinary nearest/cooldown readiness never reached"
		var prompt: Label = latch.prompt
		var settled: Dictionary = await _settle(r, g, prompt)
		receipt[mode + "_camera_settle"] = settled
		if not bool(settled.complete):
			return mode + ": normal camera/prompt did not passively settle"
		var prompt_proof: Dictionary = _prompt(g, prompt)
		if not bool(prompt_proof.complete):
			return mode + ": full device prompt not visible/contained at offset pose"
		_note(receipt, mode + "/prompt", prompt_proof)
		var presentation: Dictionary = _presentation(g, latch)
		_note(receipt, mode + "/presentation", presentation)
		if not bool(presentation.complete):
			return mode + ": body/winch painted bounds are absent, hidden or outside viewport"
		await _shot(r, receipt, mode + "_01_prompt")
		await RenderingServer.frame_post_draw
		var final_prompt: Dictionary = _prompt(g, prompt)
		var final_presentation: Dictionary = _presentation(g, latch)
		var final_pose: Dictionary = _pose(g)
		receipt[mode + "_postdraw"] = {"prompt": final_prompt, "presentation": final_presentation, "pose": final_pose}
		if not bool(final_prompt.complete) or not bool(final_presentation.complete) or not bool(final_pose.clear):
			return mode + ": final postdraw geometry/presentation/pose disagrees with readiness"
		if g.input_overlay_up() or g.talk_cd > 0.0 or not is_instance_valid(latch) or not prompt.visible:
			return mode + ": readiness changed during screenshot"
		# Prepare a genuine closed solo save. No direct SaveGame.write or fake apply.
		g.save_slot = SLOT
		g.no_saves = false
		# Synchronous witness: no scheduled autosave can interleave these reads.
		var before_closed: Dictionary = SaveGame.read(SLOT)
		g.autosave()
		var closed: Dictionary = SaveGame.read(SLOT)
		if closed.is_empty() or bool(SaveGame.flags_of(closed).get(String(edge.flag), false)) \
				or int(SaveGame.world_of(closed).get("wander_seed", -1)) != seed_value \
				or (not before_closed.is_empty() and float(closed.get("saved_at", 0.0)) <= float(before_closed.get("saved_at", 0.0))):
			return mode + ": ordinary closed autosave failed"
		_note(receipt, mode + "/closed_save", {"before_empty": before_closed.is_empty(),
			"before_saved_at": before_closed.get("saved_at"), "after_saved_at": closed.get("saved_at")})
		var gate_before_open: StaticBody2D = g.gates[g._edge_key(a, b)]
		var gate_before_open_id: int = gate_before_open.get_instance_id()
		var native_error: String = await _activate(r, g, mode, state, receipt, String(edge.flag))
		if native_error != "":
			return native_error
		# The successful latch's ordinary autosave must already contain this flag.
		var opened: Dictionary = SaveGame.read(SLOT)
		if opened.is_empty() or not bool(SaveGame.flags_of(opened).get(String(edge.flag), false)) \
				or int(SaveGame.world_of(opened).get("wander_seed", -1)) != seed_value \
				or float(opened.get("saved_at", 0.0)) <= float(closed.get("saved_at", 0.0)):
			return mode + ": native opening did not produce a newer opened solo save"
		_note(receipt, mode + "/native_open_saved", {"closed_saved_at": closed.get("saved_at"),
			"opened_saved_at": opened.get("saved_at"), "saved_world": SaveGame.world_of(opened),
			"input": mode, "direct_action_fallback": false})
		g.no_saves = true
		if not await r._until(func() -> bool: return Latch.find(g) == null and not g.gates.has(g._edge_key(a, b)), 5.0) or not g._edge_unlocked(a, b):
			return mode + ": opened edge kept its latch/gate or remained graph-locked"
		var opened_prop: Dictionary = _inactive_prop(g, String(edge.flag), seed_value)
		_note(receipt, mode + "/inactive_opened", opened_prop)
		if not bool(opened_prop.complete):
			return mode + ": opening did not retain exactly one inactive current-world winch"
		if is_instance_valid(gate_before_open) and gate_before_open.collision_layer != 0:
			return mode + ": opening retained live gate collision during its fade"
		# Capture the identity, not a node whose expected retirement would make
		# Godot report a freed lambda capture before evaluating the predicate.
		if not await r._until(func() -> bool: return not is_instance_id_valid(gate_before_open_id), 3.0):
			return mode + ": opened gate never finished its ordinary fade"
		await _shot(r, receipt, mode + "_02_open")
		for crossing in [[far, near, direction], [near, far, String(OPP[direction])]]:
			var crossing_error: String = await _cross(r, g, receipt, state, mode,
				int(crossing[0]), int(crossing[1]), String(crossing[2]))
			if crossing_error != "":
				return crossing_error
		var graph: Array = _graph(g)
		var reload_from: int = g.world.get_instance_id()
		g.load_save(SLOT)
		g.player.set_physics_process(false)
		await r.frames(3)
		if g.world.get_instance_id() == reload_from or g.wander_seed != seed_value or g.shortcut_edge != edge \
				or not bool(g.get_flag(String(edge.flag), false)) or not g._edge_unlocked(a, b) or _graph(g) != graph:
			return mode + ": ordinary load_save failed new-world/seed/flag/graph persistence"
		g._build_room(a)
		g._build_room(b)
		await r.frames(2)
		if Latch.find(g) != null or g.gates.has(g._edge_key(a, b)):
			return mode + ": reload rebuilt an earned latch or locked gate"
		var restored_prop: Dictionary = _inactive_prop(g, String(edge.flag), seed_value)
		_note(receipt, mode + "/inactive_reloaded", restored_prop)
		if not bool(restored_prop.complete):
			return mode + ": reload did not retain exactly one inactive current-world winch"
		_note(receipt, mode + "/reload", {"before_world_id": reload_from,
			"after_world_id": g.world.get_instance_id(), "flag": String(edge.flag), "graph": graph})
		await _shot(r, receipt, mode + "_05_reloaded")
	return ""


static func _pose(g: Game) -> Dictionary:
	var shapes := 0
	var collisions: Array = []
	for child in g.player.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null:
			continue
		shapes += 1
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.collision_mask = 1
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [g.player.get_rid()]
		for hit in g.player.get_world_2d().direct_space_state.intersect_shape(query, 16):
			var collider: Node = hit.get("collider") as Node
			collisions.append({"path": str(collider.get_path()) if is_instance_valid(collider) else "missing",
				"shape": int(hit.get("shape", -1))})
	var point_blocked: bool = g._pos_in_wall(g.player.global_position)
	return {"clear": shapes > 0 and collisions.is_empty() and not point_blocked,
		"shape_count": shapes, "point_blocked": point_blocked, "collisions": collisions,
		"world_pos": _v(g.player.global_position), "scope": "actual layer1 body shapes and foot point; not foliage occlusion"}


static func _settle(r, g: Game, prompt: Label) -> Dictionary:
	# Let the ordinary arrival card finish; do not hide it or change its clock.
	if not await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0):
		return {"complete": false, "reason": "ordinary arrival card did not finish"}
	var deadline: int = Time.get_ticks_msec() + 8000
	var previous: Vector2 = g.camera.get_screen_center_position()
	var previous_prompt: Vector2 = prompt.get_global_transform_with_canvas().origin
	var stable := 0
	var samples := 0
	var tail: Array = []
	while stable < 3 and Time.get_ticks_msec() < deadline:
		await r.get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(prompt):
			return {"complete": false, "reason": "prompt retired while passively settling"}
		var center: Vector2 = g.camera.get_screen_center_position()
		var prompt_origin: Vector2 = prompt.get_global_transform_with_canvas().origin
		var camera_delta: float = center.distance_to(previous)
		var prompt_delta: float = prompt_origin.distance_to(previous_prompt)
		stable = stable + 1 if camera_delta <= 0.25 and prompt_delta <= 0.25 else 0
		samples += 1
		tail.append({"frame": Engine.get_process_frames(), "center": _v(center),
			"camera_delta": camera_delta, "prompt_delta": prompt_delta, "stable": stable})
		if tail.size() > 6:
			tail.pop_front()
		previous = center
		previous_prompt = prompt_origin
	return {"complete": stable >= 3, "sample_count": samples, "last_samples": tail,
		"policy": "three consecutive ordinary postdraw samples <=0.25px; no camera/tween writes"}


static func _prompt(g: Game, prompt: Label) -> Dictionary:
	var shape: Dictionary = Geometry.shaped(prompt)
	var cells: Rect2 = prompt.get_viewport().get_canvas_transform() * Geometry.to_rect(shape.cells)
	var box: Rect2 = prompt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, prompt.size)
	var complete: bool = prompt.is_visible_in_tree() and prompt.text == g.interaction_copy("E — Open shortcut") \
		and (shape.missing as Array).is_empty() and int(shape.count) > 0 and prompt.visible_ratio >= 1.0 \
		and not prompt.clip_text and box.grow(0.5).encloses(cells) and prompt.get_viewport_rect().encloses(box)
	return {"complete": complete, "text": prompt.text, "shape": shape,
		"screen_box": Geometry.rect(box), "screen_cells": Geometry.rect(cells),
		"pad_active": g.gamepad.active, "touch_mode": g.touch_mode, "talk_cd": g.talk_cd}


static func _presentation(g: Game, latch: Node2D) -> Dictionary:
	var sprite: Sprite2D = null
	for child in latch.get_children():
		if child is Sprite2D and child.texture == Art.tex("shortcut_winch"):
			sprite = child
			break
	if sprite == null:
		return {"complete": false, "reason": "current painted winch sprite missing"}
	var oracle := Painted.new()
	var hero: Rect2 = oracle._painted(g.player.sprite)
	var prop: Rect2 = oracle._painted(sprite)
	var viewport: Rect2 = sprite.get_viewport_rect()
	var visible: bool = sprite.is_visible_in_tree() and g.player.sprite.is_visible_in_tree() \
		and sprite.modulate.a > 0.2 and g.player.sprite.modulate.a > 0.2 \
		and sprite.self_modulate.a > 0.2 and g.player.sprite.self_modulate.a > 0.2
	return {"complete": visible and hero.has_area() and prop.has_area() and viewport.encloses(hero) and viewport.encloses(prop),
		"hero": Geometry.rect(hero), "winch": Geometry.rect(prop), "viewport": Geometry.rect(viewport),
		"nodes_visible": visible, "hero_winch_bounds_overlap": hero.intersects(prop),
		"scope": "current alpha>=0.15 frame bounds and node visibility; no canopy/occlusion or art-quality proof"}


static func _inactive_prop(g: Game, key: String, seed_value: int) -> Dictionary:
	var props: Array = []
	for child in g.world.get_children():
		if child.get_script() == Latch and not child.is_queued_for_deletion():
			props.append(child)
	var prop: Node2D = Latch.find(g, true)
	var entries := 0
	for entry in g.interactables:
		if entry.get("node") == prop:
			entries += 1
	var valid: bool = is_instance_valid(prop) and props.size() == 1 and props[0] == prop \
		and prop.get_parent() == g.world and prop.world_owner == g.world and prop.world_seed == seed_value \
		and prop.flag_name == key and prop.opened and not prop.prompt.visible \
		and Latch.find(g) == null and entries == 0
	return {"complete": valid, "count": props.size(), "interactable_entries": entries,
		"world_id": g.world.get_instance_id(), "prop_id": prop.get_instance_id() if is_instance_valid(prop) else 0,
		"seed": seed_value, "flag": key, "active_find_null": Latch.find(g) == null}


static func _mode(r, g: Game, mode: String) -> String:
	if mode == "controller":
		g.set_touch_controls(false)
		# Meaningful stick wake while physics is frozen, then ordinary neutral.
		for value in [0.5, 0.0]:
			var event := InputEventJoypadMotion.new()
			event.device = 0
			event.axis = JOY_AXIS_LEFT_X
			event.axis_value = value
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await r.frames(2)
		if not await r._until(func() -> bool: return g.gamepad.active and not g.gamepad.rearm and g.gamepad.focused, 4.0):
			return "controller: ordinary wake/neutral failed"
	else:
		# Real mouse motion hands device ownership back; no gameplay action.
		var wake := InputEventMouseMotion.new()
		wake.relative = Vector2(64, 0)
		wake.position = Vector2(640, 360)
		Input.parse_input_event(wake)
		Input.flush_buffered_events()
		g.set_touch_controls(true)
		if not await r._until(func() -> bool: return not g.gamepad.active and is_instance_valid(g._touch_hud) and g._touch_hud._enabled, 4.0):
			return "touch: normal device handoff/HUD enable failed"
	return ""


static func _activate(r, g: Game, mode: String, state: Dictionary, receipt: Dictionary, flag_name: String) -> String:
	if bool(g.get_flag(flag_name, false)) or Latch.find(g) == null or g.input_overlay_up():
		return mode + ": positive action lost its closed/live precondition"
	if mode == "controller":
		_pad(true)
		state.pad_down = true
		receipt.native_inputs.append({"mode": mode, "event": "A pressed", "frame": Engine.get_process_frames(),
			"adapter_held": bool(g.gamepad.buttons.get(JOY_BUTTON_A, false))})
		var opened: bool = await r._until(func() -> bool: return bool(g.get_flag(flag_name, false)), 5.0)
		_pad(false)
		state.pad_down = false
		receipt.native_inputs.append({"mode": mode, "event": "A released", "frame": Engine.get_process_frames()})
		if not opened:
			return "controller: one native A press did not open; no fallback"
	else:
		var panel: Control = g._touch_hud._btns["interact"]["panel"]
		if not panel.is_visible_in_tree() or not panel.get_viewport_rect().encloses(panel.get_global_rect()):
			return "touch: actual Act panel is not fully visible"
		state.touch_pos = panel.get_global_rect().get_center()
		_touch(state.touch_pos, true)
		state.touch_down = true
		receipt.native_inputs.append({"mode": mode, "event": "touch pressed", "index": 19,
			"pos": _v(state.touch_pos), "frame": Engine.get_process_frames()})
		if String(g._touch_hud._btn_touch.get(19, "")) != "interact":
			return "touch: native contact was not owned by the actual Act button"
		await r.frames(2)
		_touch(state.touch_pos, false)
		state.touch_down = false
		receipt.native_inputs.append({"mode": mode, "event": "touch released", "index": 19, "frame": Engine.get_process_frames()})
		if not await r._until(func() -> bool: return bool(g.get_flag(flag_name, false)), 5.0):
			return "touch: one native Act tap did not open; no fallback"
	return ""


static func _cross(r, g: Game, receipt: Dictionary, state: Dictionary, mode: String,
		from_room: int, to_room: int, direction: String) -> String:
	var axis: Vector2 = DIRS[direction]
	var boundary: Vector2 = g.door_pos(from_room, direction)
	var from_mouth: Vector2 = _mouth(g, from_room, direction)
	var to_mouth: Vector2 = _mouth(g, to_room, String(OPP[direction]))
	g.player.global_position = from_mouth - axis * 120.0
	g.player.velocity = Vector2.ZERO
	g._enter_room(from_room)
	g.player.set_physics_process(true)
	var key: int = Party.MOVE_KEY[direction]
	Party._key_event(state, key, true)
	var crossed: bool = await r._until(func() -> bool: return g.room_at_pos(g.player.global_position) == to_room \
		and g.cur_room == to_room and (g.player.global_position - to_mouth).dot(axis) > 80.0, 8.0)
	Party._key_event(state, key, false)
	g.player.set_physics_process(false)
	g.player.velocity = Vector2.ZERO
	if not crossed:
		return mode + ": ordinary WASD did not cross opened edge " + direction
	_note(receipt, mode + "/cross_" + direction, {"from": from_room, "to": to_room,
		"end": _v(g.player.global_position), "cur_room": g.cur_room, "boundary": _v(boundary),
		"from_mouth": _v(from_mouth), "to_mouth": _v(to_mouth)})
	await _shot(r, receipt, mode + "_cross_" + direction)
	return ""


static func _cleanup(r, receipt: Dictionary, state: Dictionary) -> String:
	_pad(false)
	var zero := InputEventJoypadMotion.new()
	zero.device = 0
	zero.axis = JOY_AXIS_LEFT_X
	zero.axis_value = 0.0
	Input.parse_input_event(zero)
	if bool(state.touch_down):
		_touch(state.touch_pos, false)
	for key in (state.keys as Array).duplicate():
		Party._key_event(state, int(key), false)
	var errors: Array = []
	if bool(state.saved) and is_instance_valid(r.game):
		var g: Game = r.game
		g.no_saves = true
		g.settings = state.settings.duplicate(true)
		g.set_touch_controls(bool(g.settings.get("touch_controls", false)))
		g.gamepad.cancel_held()
		g.gamepad.device = int(state.device)
		g.gamepad._set_active(bool(state.active))
		g.gamepad.focused = bool(state.focused)
		g.player.set_physics_process(bool(state.physics))
		g.player.velocity = Vector2.ZERO
		g.terrain_event_t = float(state.terrain_event_t)
		g.save_slot = int(state.slot)
		g.no_saves = bool(state.no_saves)
	var file_results: Array = []
	for path in state.files:
		if state.files[path] == null:
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				errors.append("slot removal failed " + String(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				errors.append("slot restore open failed " + String(path))
			else:
				file.store_buffer(state.files[path])
				file.flush()
				if file.get_error() != OK:
					errors.append("slot restore write failed " + String(path))
				file.close()
		var exact: bool = not FileAccess.file_exists(path) if state.files[path] == null else FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == state.files[path]
		file_results.append({"path": path, "restored_exact": exact})
		if not exact:
			errors.append("slot bytes differ " + String(path))
	for path in state.settings_files:
		var exact: bool = not FileAccess.file_exists(path) if state.settings_files[path] == null else FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == state.settings_files[path]
		if not exact:
			errors.append("settings file unexpectedly changed " + String(path))
	receipt.cleanup = {"complete": errors.is_empty(), "files": file_results, "errors": errors,
		"limit": "normal-return cleanup only; arbitrary parse/runtime/watchdog abort is not claimed"}
	return "; ".join(PackedStringArray(errors))


static func _pad(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func _touch(pos: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 19
	event.position = pos
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func _graph(g: Game) -> Array:
	var rows: Array = []
	for zi in g.zone_count:
		var room: Dictionary = g.rooms[zi]
		var coord := Vector2i(room["coord"])
		rows.append({"coord": [coord.x, coord.y], "scale": _v(Vector2(room["scale"])),
			"origin": _v(Vector2(room["origin"])), "exits": (room["exits"] as Dictionary).duplicate(true)})
	return rows


static func _mouth(g: Game, zone: int, direction: String) -> Vector2:
	var point: Vector2 = g.door_pos(zone, direction)
	var rect: Rect2 = g.play_rect(zone)
	if direction in ["N", "S"]:
		point.y = rect.position.y if direction == "N" else rect.end.y
	else:
		point.x = rect.position.x if direction == "W" else rect.end.x
	return point


static func _note(receipt: Dictionary, id: String, data: Dictionary) -> void:
	receipt.checks.append({"id": id, "ok": bool(data.get("complete", data.get("clear", true))), "data": data})


static func _shot(r, receipt: Dictionary, name: String) -> void:
	var g: Game = r.game
	var ready: bool = await r._until(func() -> bool: return g.hud.title_label.modulate.a <= 0.01 and g.hud.subtitle_label.modulate.a <= 0.01 and g.hud.overlay.color.a <= 0.01, 8.0)
	_note(receipt, name + "/arrival_finished", {"complete": ready,
		"title_alpha": g.hud.title_label.modulate.a, "subtitle_alpha": g.hud.subtitle_label.modulate.a,
		"overlay_alpha": g.hud.overlay.color.a, "policy": "ordinary tween observed; no visibility or clock writes"})
	if not ready:
		push_error("Shortcut visual capture: ordinary arrival card did not finish: " + name)
	await r._capture("solo_" + name)
	receipt.originals.append(r.shot_dir + "/solo_" + name + ".png")


static func _v(point: Vector2) -> Array:
	return [point.x, point.y]
