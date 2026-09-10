extends ShotRig
## Candidate only: native input reproductions, no production changes or saves.
## See README for fixture limits and --baseline versus strict interpretation.
const Hunt := preload("res://scripts/road_hunt.gd")
const Competition := preload("res://scripts/tests/interaction_competition.gd")
const H := 0.7071067811865476
const DIRECTIONS := [Vector2.RIGHT, Vector2(H, H), Vector2.DOWN,
	Vector2(-H, H), Vector2.LEFT, Vector2(-H, -H), Vector2.UP, Vector2(H, -H)]
const KITS := [["warrior", "a2", 170.0], ["assassin", "a2", 210.0], ["mage", "a3", 190.0]]
var held := {}
var observer_slot := ""
var setup_error := ""
var observation: Dictionary = {}
var report := {"checks": 0, "failures": [], "findings": [], "interaction": [],
	"dash": [], "skips": [], "ordinary_input_gameplay": false,
	"limits": "One native engine. Posed no-save hero and reset cooldowns/mana. Synthetic key/pad/touch events use production input. No actual device, combat damage, rewards, or co-op. Authored scenery is identified separately from a production-factory prop with other terrain colliders temporarily disabled."}
var saved_solids: Array[Dictionary] = []


func _ready() -> void:
	# Observe after Player's ordinary physics callback, before the next movement
	# step can depenetrate a bad landing. This is measurement, not a hero override.
	process_physics_priority = 1000
	report["baseline"] = flag("baseline")
	await boot("warrior", "ch1", false)
	# Same explicit adapter-focus fixture as menu_navigation_live._joy_back:
	# foreground application changes must not become interaction findings.
	report["input_setup"] = {"native_pad_focus_at_boot": game.gamepad.focused,
		"forced_adapter_focus": true, "language": "en", "pad_labels": "xbox",
		"touch_taps": "same-frame press/release; real TouchHud pulse afterward"}
	game.gamepad.focused = true
	Loc.lang = "en"
	game.settings["pad_labels"] = "xbox"
	game.hud.visible = true
	_check(game.gamepad.focused and game.gamepad.label("interact") == "A", "synthetic pad focus and labels established after boot")
	var error := await _execute()
	_release()
	_restore_solids()
	if error != "" and not report.failures.has(error):
		report.failures.append(error)
	if is_instance_valid(game):
		game.set_process(false)
		game.player.set_physics_process(false)
	report["complete"] = error == ""
	report["shots"] = shots_taken
	var path: String = ProjectSettings.globalize_path(shot_dir.path_join("friction.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write native friction report")
		finish(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FRICTION QA: checks=%d failures=%d findings=%d complete=%s report=%s" % [report.checks,
		report.failures.size(), report.findings.size(), report.complete, path])
	finish(0 if report.failures.is_empty() else 1)


func _physics_process(_delta: float) -> void:
	if observer_slot == "" or not observation.is_empty() or not is_instance_valid(game):
		return
	var p: Player = game.player
	if float(p.cds.get(observer_slot, 0.0)) <= 0.0:
		return
	observation = {"position": _v(p.global_position), "hits": _overlaps(p.global_position),
		"cooldown": p.cds[observer_slot], "mp": p.mp, "physics_frame": Engine.get_physics_frames(),
		"velocity": _v(p.velocity), "motion_faults": p.motion_faults}
	p.set_physics_process(false)
	_release()


func _check(ok: bool, label: String, known_defect := false) -> void:
	report.checks += 1
	if ok:
		return
	if known_defect and flag("baseline"):
		report.findings.append(label)
		print("FRICTION BASELINE FINDING: " + label)
	else:
		report.failures.append(label)
		print("FRICTION FAILURE: " + label)


func _v(value: Vector2) -> Array:
	return [value.x, value.y]


func _key(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _move(direction: Vector2) -> void:
	_key(KEY_A, direction.x < -0.3)
	_key(KEY_D, direction.x > 0.3)
	_key(KEY_W, direction.y < -0.3)
	_key(KEY_S, direction.y > 0.3)


func _joy(down: bool) -> void:
	game.gamepad.focused = true
	var event := InputEventJoypadButton.new()
	event.device = 27
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release() -> void:
	for key in held.keys():
		_key(int(key), false)
	if is_instance_valid(game) and is_instance_valid(game.player):
		if is_instance_valid(game.gamepad) and bool(game.gamepad.buttons.get(JOY_BUTTON_A, false)):
			_joy(false)
		if is_instance_valid(game._touch_hud):
			game._touch_hud._release_everything() # no previous Act pulse can inspect the next reset sign
		game.player.clear_local_intents()


func _touch_at(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	# A frame readback can exceed the real 0.45s long-press timer. Dispatch a
	# short actual touch pair without yielding; TouchHud supplies its normal
	# 0.12s interact pulse, which the following process frames must consume.
	await frames(3)


func _capture(label: String, explanation: String) -> void:
	# The dash fixture pauses Game updates; render the actual current kit/stats.
	if not game.is_processing():
		game.hud.update_stats(game.player)
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label, explanation)


func _require_setup(ok: bool, label: String, row: Dictionary = {}, phase := "") -> bool:
	_check(ok, label)
	if ok:
		return true
	setup_error = label
	observer_slot = ""
	if phase != "" and not row.is_empty():
		row["setup_error"] = label
		report[phase].append(row.duplicate(true))
	_release()
	return false


func _hud_hits(point: Vector2) -> Array:
	var hits: Array = []
	# Match actual live Control input geometry, including ordinary HUD Buttons,
	# clickable portrait/stat/ability/buff popovers and any visible GUI catcher.
	# Decorative IGNORE controls cannot consume this world tap. Keep HUD visible.
	for node in game.hud.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
		if not Rect2(Vector2.ZERO, control.size).has_point(local):
			continue
		var exposed := true
		var parent: Node = control.get_parent()
		while parent != null and parent != game.hud:
			if parent is Control and parent.clip_contents:
				var clipped: Vector2 = parent.get_global_transform_with_canvas().affine_inverse() * point
				if not Rect2(Vector2.ZERO, parent.size).has_point(clipped):
					exposed = false
					break
			parent = parent.get_parent()
		if exposed:
			var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
			hits.append({"path": str(control.get_path()), "class": control.get_class(),
				"mouse_filter": control.mouse_filter, "rect": [_v(rect.position), _v(rect.size)]})
	return hits


func _pose_interaction_camera(point: Vector2) -> Dictionary:
	# Explicit screenshot-fixture framing at normal zoom. Expand only camera
	# limits enough to frame this point; _interaction restores every saved term
	# before dash cases. World geometry, sign position and HUD remain untouched.
	# Keep the sign32 logical pixels right of the joystick's half-screen edge;
	# exact centering can round just inside that strict manual-input boundary.
	var screen_bias := Vector2(32.0, 0.0)
	var center: Vector2 = point - screen_bias / game.camera.zoom
	var half_view: Vector2 = get_viewport().get_visible_rect().size / game.camera.zoom * 0.5
	game.camera.limit_left = mini(game.camera.limit_left, floori(center.x - half_view.x) - 1)
	game.camera.limit_top = mini(game.camera.limit_top, floori(center.y - half_view.y) - 1)
	game.camera.limit_right = maxi(game.camera.limit_right, ceili(center.x + half_view.x) + 1)
	game.camera.limit_bottom = maxi(game.camera.limit_bottom, ceili(center.y + half_view.y) + 1)
	game.camera.global_position = center
	game.camera.offset = Vector2.ZERO
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await frames(3)
	game.camera.force_update_scroll()
	var first: Vector2 = get_viewport().get_canvas_transform() * point
	await frames(2)
	game.camera.force_update_scroll()
	var settled: Vector2 = get_viewport().get_canvas_transform() * point
	return {"posed": true, "temporary_camera_limits": true, "requested_world_center": _v(center),
		"sign_world": _v(point), "logical_screen_bias": _v(screen_bias),
		"camera_world": _v(game.camera.global_position), "camera_offset": _v(game.camera.offset),
		"zoom": _v(game.camera.zoom), "limits": [game.camera.limit_left, game.camera.limit_top,
			game.camera.limit_right, game.camera.limit_bottom], "first_screen": _v(first),
		"settled_screen": _v(settled), "screen_drift": first.distance_to(settled),
		"viewport": _v(get_viewport().get_visible_rect().size)}
func _shape() -> Shape2D:
	for child in game.player.get_children():
		if child is CollisionShape2D and not child.disabled:
			return child.shape
	return null


func _overlaps(point: Vector2) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape()
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result: Array = []
	for hit in game.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: Node = hit.collider
		result.append({"id": body.get_instance_id(), "path": str(body.get_path()),
			"prop": str(body.get_meta("prop", "")), "structure": str(body.get_meta("structure", ""))})
	return result


func _execute() -> String:
	var deadline := Time.get_ticks_msec() + 8000
	while not game.play_started and Time.get_ticks_msec() < deadline:
		await frames(1)
	if not game.play_started or _shape() == null:
		return "Fixture did not reach play with a real player collider"
	_check(game.no_saves, "ShotRig disabled saves")
	Engine.time_scale = 1.0
	game.dev_god = false
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	game.npc_emote_t = 10000.0
	var room := -1
	for i in game.zones.size():
		if str(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		return "Missing authored Village Outskirts fixture room"
	game.player.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await frames(6)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.remove_from_group("enemies") # landing-only probe cannot strike/kill or trigger hit-stop
	game.player.set_physics_process(false)
	report["chapter"] = game.chapter_id
	report["wander_seed"] = game.wander_seed
	report["room"] = room
	report["room_name"] = str(game.zones[room].name)
	report["hero_shape"] = _shape().get_class()
	var settings_point: Vector2 = game.hud.settings_btn.get_global_transform_with_canvas() * (game.hud.settings_btn.size * 0.5)
	var settings_hits: Array = _hud_hits(settings_point)
	var found_settings := false
	for hit in settings_hits:
		if str(hit.path) == str(game.hud.settings_btn.get_path()):
			found_settings = true
	report["hud_hit_control"] = {"point": _v(settings_point), "hits": settings_hits, "settings_detected": found_settings}
	if not _require_setup(found_settings, "HUD exclusion detects actual visible settings Button"):
		return setup_error
	var error := await _interaction(room)
	if error != "":
		return error
	game.set_process(false)
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.gamepad._set_active(false)
	game.gamepad.cancel_held()
	# This phase leaves every authored terrain collider intact.
	await _authored_dash_cases(room)
	if setup_error != "":
		return setup_error
	# Controlled direction matrix: real factory collider/art, explicit fixture
	# placement. Original solid bodies are restored even when assertions fail.
	for node in game.world.find_children("*", "StaticBody2D", true, false):
		if node.collision_layer & 1:
			saved_solids.append({"body": node, "layer": node.collision_layer})
			node.collision_layer = node.collision_layer & ~1
	var center: Vector2 = game.play_rect(room).get_center()
	var obstacle: StaticBody2D = game._add_obstacle("boulder", center - Vector2(0, 10))
	await get_tree().physics_frame
	await frames(2)
	game.camera.global_position = center
	game.camera.reset_smoothing()
	game.camera.zoom = Vector2.ONE
	for kit in KITS:
		_prepare_class(str(kit[0]))
		for i in DIRECTIONS.size():
			var direction: Vector2 = DIRECTIONS[i]
			await _dash_case("factory_" + str(kit[0]) + "_" + str(i), "factory boulder; other terrain masked",
				str(kit[1]), float(kit[2]), center - direction * float(kit[2]), direction, true, i == 0)
			if setup_error != "":
				obstacle.queue_free()
				return setup_error
	# A deliberately obstructed PATH with a clear ENDPOINT must remain valid for
	# Blink. This is the negative control against a blanket wall-traversal nerf.
	_prepare_class("mage")
	for i in DIRECTIONS.size():
		await _dash_case("blink_clear_endpoint_" + str(i), "factory boulder between open endpoints",
			"a3", 190.0, center - DIRECTIONS[i] * 95.0, DIRECTIONS[i], false, i == 0)
		if setup_error != "":
			obstacle.queue_free()
			return setup_error
	obstacle.queue_free()
	_restore_solids()
	await frames(2)
	if flag("endpoint-contracts") and setup_error == "":
		var endpoint_error: String = await preload("res://scripts/tests/dash_endpoint_live.gd").run(self, room)
		if endpoint_error != "":
			return endpoint_error
	if flag("field-notes") and setup_error == "":
		var reading_error: String = await preload("res://scripts/tests/exploration_field_notes.gd").run(self)
		if reading_error != "":
			return reading_error
	return ""


func _interaction(room: int) -> String:
	step("actual hunt sign, isolated production interaction selector")
	var trail: Variant = Hunt.begin(game, room, game.room_center(room))
	if trail == null:
		return "Normal Hunt.begin could not create a trail; inspect seed/encounter blockers, do not count as reach evidence"
	trail.set_physics_process(false)
	var entries: Array = game.interactables.duplicate()
	var camera_before := {"position": game.camera.position, "offset": game.camera.offset,
		"zoom": game.camera.zoom, "limits": [game.camera.limit_left, game.camera.limit_top, game.camera.limit_right, game.camera.limit_bottom]}
	report["interaction_camera_before"] = {"position": _v(game.camera.position), "offset": _v(game.camera.offset),
		"zoom": _v(game.camera.zoom), "limits": camera_before.limits.duplicate()}
	# Keep the real sign/action/reach; remove unrelated NPC competition only.
	game.interactables = [trail.entries[0]]
	for mode in ["keyboard", "pad", "act", "tap"]:
		game.gamepad.focused = true
		game.gamepad._set_active(mode == "pad")
		game.settings["touch_controls"] = mode in ["act", "tap"]
		game.refresh_touch_mode()
		game._apply_touch_mode()
		await frames(3)
		for distance in [79.0, 81.0, 120.0, 159.0, 161.0]:
			await _interaction_case(trail, mode, distance, 160.0)
			if setup_error != "":
				break
		if setup_error != "":
			break
	# Entry-specific short/default/disabled gates must continue to work.
	for spec in [[49.0, 50.0], [51.0, 50.0], [79.0, 80.0], [81.0, 80.0], [1.0, 0.0]]:
		if setup_error != "":
			break
		game.settings["touch_controls"] = false
		game.refresh_touch_mode()
		game._apply_touch_mode()
		await _interaction_case(trail, "keyboard", float(spec[0]), float(spec[1]))
	if flag("competition") and setup_error == "":
		var competition_error: String = await Competition.run(self, trail)
		if competition_error != "":
			_require_setup(false, competition_error)
	_joy(false)
	game.interactables = entries
	trail.cancel()
	game.camera.position = camera_before.position
	game.camera.offset = camera_before.offset
	game.camera.zoom = camera_before.zoom
	game.camera.limit_left = int(camera_before.limits[0])
	game.camera.limit_top = int(camera_before.limits[1])
	game.camera.limit_right = int(camera_before.limits[2])
	game.camera.limit_bottom = int(camera_before.limits[3])
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	report["interaction_camera_restored"] = {"position": _v(game.camera.position), "offset": _v(game.camera.offset),
		"zoom": _v(game.camera.zoom), "limits": [game.camera.limit_left, game.camera.limit_top, game.camera.limit_right, game.camera.limit_bottom]}
	if report.interaction_camera_restored != report.interaction_camera_before:
		_require_setup(false, "Interaction camera terms restored before dash phase")
	else:
		_check(true, "Interaction camera terms restored before dash phase")
	await frames(3)
	return setup_error


func _interaction_case(trail: Variant, mode: String, distance: float, reach: float) -> void:
	_release()
	_joy(false)
	if not _require_setup(not game.input_overlay_up() and not get_tree().paused,
			"interaction %s %.0f/%.0f begins without overlay" % [mode, distance, reach],
			{"mode": mode, "distance": distance, "reach": reach}, "interaction"):
		return
	trail.sign_index = 0
	trail._refresh()
	trail.entries[0]["reach"] = reach
	var sign_point: Vector2 = trail.points[0]
	var chosen := Vector2(INF, INF)
	# Select only a physically valid posed hero start. Camera framing is explicit
	# below and does not depend on a disabled hero's follow-camera update.
	for direction in DIRECTIONS:
		var candidate: Vector2 = sign_point + direction * distance
		if game.room_at_pos(candidate) == trail.zone and _overlaps(candidate).is_empty():
			chosen = candidate
			break
	if not _require_setup(chosen.is_finite(), "Safe posed interaction start %s %.0f/%.0f" % [mode, distance, reach],
			{"mode": mode, "distance": distance, "reach": reach}, "interaction"):
		return
	game.player.global_position = chosen
	game.player.velocity = Vector2.ZERO
	game.talk_cd = 0.0
	var framing: Dictionary = await _pose_interaction_camera(sign_point)
	var expected := distance < reach
	var before := {"mode": mode, "distance": distance, "reach": reach, "expected": expected,
		"position": _v(chosen), "sign": _v(sign_point), "prompt": trail.prompts[0].visible,
		"prompt_text": trail.prompts[0].text, "interact_in_range": game.interact_in_range,
		"input_overlay_up": game.input_overlay_up(), "sign_before_input": trail.sign_index,
		"actual_distance": game.player.global_position.distance_to(sign_point), "talk_cd": game.talk_cd,
		"camera_fixture": framing}
	var input_ready := not bool(before.input_overlay_up) and not get_tree().paused \
		and int(before.sign_before_input) == 0 and float(before.talk_cd) <= 0.0 \
		and absf(float(before.actual_distance) - distance) < 0.1 and float(framing.screen_drift) < 0.25
	if not _require_setup(input_ready, "interaction %s %.0f/%.0f has untouched exact-distance input setup and settled camera" % [mode, distance, reach], before, "interaction"):
		return
	if distance == 120.0 and reach == 160.0:
		await _capture("reach120_" + mode + "_before", "Posed actual hunt sign and camera; before synthetic " + mode + " input")
	var now_screen: Vector2 = get_viewport().get_canvas_transform() * sign_point
	before["pre_input_screen"] = _v(now_screen)
	before["pre_input_screen_drift"] = now_screen.distance_to(Vector2(float(framing.settled_screen[0]), float(framing.settled_screen[1])))
	if not _require_setup(not game.input_overlay_up() and not get_tree().paused,
			"interaction %s %.0f/%.0f is still ready immediately before input" % [mode, distance, reach], before, "interaction"):
		return
	if not _require_setup(float(before.pre_input_screen_drift) < 0.25,
			"interaction %s %.0f/%.0f retains its settled transform before input" % [mode, distance, reach], before, "interaction"):
		return
	if mode == "act":
		var panel: Panel = game._touch_hud._btns["interact"]["panel"]
		before["act_visible"] = panel.is_visible_in_tree()
		before["touch_adapter_enabled"] = game._touch_hud._enabled
		if not _require_setup(bool(before.touch_adapter_enabled), "Act touch adapter is enabled", before, "interaction"):
			return
		if panel.is_visible_in_tree():
			var act_route := game._touch_hud._button_at(panel.get_global_rect().get_center()) == "interact"
			if not _require_setup(act_route, "Act press targets the actual Act control", before, "interaction"):
				return
			await _touch_at(panel.get_global_rect().get_center())
	elif mode == "tap":
		var screen_point: Vector2 = get_viewport().get_canvas_transform() * sign_point
		before["tap_screen"] = _v(screen_point)
		before["tap_hud_hits"] = _hud_hits(screen_point)
		var clear_route: bool = game._touch_hud._enabled and get_viewport().get_visible_rect().has_point(screen_point) \
			and game._touch_hud._button_at(screen_point) == "" and not game._touch_hud._in_joystick_zone(screen_point) \
			and before.tap_hud_hits.is_empty()
		before["tap_route_clear"] = clear_route
		if not _require_setup(clear_route, "direct sign tap clears actual HUD controls, touch buttons and joystick", before, "interaction"):
			return
		await _touch_at(screen_point)
	elif mode == "pad":
		_joy(true)
		before["pad_focused"] = game.gamepad.focused
		before["pad_held"] = game.gamepad.held("interact")
		if not _require_setup(bool(before.pad_focused) and bool(before.pad_held), "synthetic pad A reaches the production held-input adapter", before, "interaction"):
			return
		await frames(3)
		before["pad_focus_after_hold"] = game.gamepad.focused
		if not _require_setup(bool(before.pad_focus_after_hold), "native focus did not invalidate the synthetic pad hold", before, "interaction"):
			return
		_joy(false)
	else:
		_key(int(game.binds.interact), true)
		await frames(3)
		_key(int(game.binds.interact), false)
	await frames(2)
	before["sign_after"] = trail.sign_index
	before["overlay_after"] = game.input_overlay_up()
	before["menu_after"] = game.menus.current
	if not _require_setup(not bool(before.overlay_after) and not get_tree().paused,
			"interaction %s %.0f/%.0f did not open an unrelated overlay" % [mode, distance, reach], before, "interaction"):
		return
	report.interaction.append(before)
	var label := "interaction %s %.0fpx reach%.0f" % [mode, distance, reach]
	var known := input_ready and reach == 160.0 and distance > 80.0 and distance < 160.0 and mode != "tap"
	_check((int(trail.sign_index) == 1) == expected, label + " activation matches eligibility", known)
	_check(int(trail.sign_index) <= 1, label + " advances only one sign")
	if distance == 120.0 and reach == 160.0:
		await _capture("reach120_" + mode, "Posed actual hunt sign and camera; synthetic " + mode + " input; see JSON pre-input prompt")
	_release()

func _prepare_class(cls: String) -> void:
	_release()
	game.player.set_physics_process(false)
	game.player.set_class(cls)
	game.player.level = 1
	game.player.ability_theme = {"a1": "", "a2": "", "a3": "", "ult": ""}
	game.player.recalc()
	game.player.locked_target = null
	game.player.soft_target = null


func _authored_dash_cases(room: int) -> void:
	step("unaltered authored scenery landing examples")
	for kit in KITS:
		_prepare_class(str(kit[0]))
		var found := false
		for body in game.world.find_children("*", "StaticBody2D", true, false):
			if found:
				break
			if not body.has_meta("prop") or (int(body.collision_layer) & 1) == 0 or game.room_at_pos(body.global_position) != room:
				continue
			for shape in body.get_children():
				if found:
					break
				if not shape is CollisionShape2D or shape.disabled:
					continue
				var center: Vector2 = shape.global_position
				if game.clamp_to_zone(center, center).distance_to(center) > 0.01:
					continue # boundary clamping would no longer aim into this collider
				for direction in DIRECTIONS:
					var start: Vector2 = center - direction * float(kit[2])
					if game.clamp_to_zone(start, center).distance_to(start) > 0.01 or not _overlaps(start).is_empty():
						continue
					game.camera.global_position = center
					game.camera.reset_smoothing()
					await _dash_case("authored_" + str(kit[0]), "authored prop " + str(body.get_meta("prop")) + " path=" + str(body.get_path()),
						str(kit[1]), float(kit[2]), start, direction, true, true)
					if setup_error != "":
						return
					found = true
					break
		if not found:
			report.skips.append("No eligible authored prop/start for " + str(kit[0]))
	_check(report.skips.is_empty(), "All three classes have an authored-prop example; otherwise the report is incomplete")


func _dash_case(label: String, geometry: String, slot: String, nominal_distance: float,
		start: Vector2, direction: Vector2, occupied_target: bool, capture: bool) -> void:
	step(label)
	var p: Player = game.player
	_release()
	p.set_physics_process(false)
	p.global_position = start
	p.velocity = Vector2.ZERO
	p.cds[slot] = 0.0
	p.mp = p.max_mp
	p.hp = p.max_hp
	p.frozen_time = 0.0
	p.rooted_time = 0.0
	p.dead = false
	p.downed = false
	p.ghost = false
	game.gust_vec = Vector2.ZERO
	var target := game.clamp_to_zone(start + direction * nominal_distance, start)
	await get_tree().physics_frame
	var entry := {"label": label, "geometry": geometry, "class": p.cls, "slot": slot,
		"direction": _v(direction), "start": _v(start), "nominal_target": _v(target),
		"nominal_distance": nominal_distance, "start_hits": _overlaps(start),
		"target_hits": _overlaps(target), "start_mp": p.mp, "cost": p.ability_cost(slot),
		"expected_occupied_target": occupied_target, "god": game.dev_god}
	if not _require_setup(entry.start_hits.is_empty(), label + " starts outside terrain", entry, "dash"):
		return
	if not _require_setup((not entry.target_hits.is_empty()) == occupied_target, label + " geometry precondition", entry, "dash"):
		return
	if not _require_setup(not game.input_overlay_up() and not get_tree().paused, label + " input overlay clear", entry, "dash"):
		return
	observation.clear()
	observer_slot = slot
	_move(direction)
	p._poll_local_intents()
	entry["polled_move"] = _v(p.intent_move)
	if not _require_setup(p.intent_move.distance_to(direction) < 0.01, label + " native move keys establish the intended dash direction", entry, "dash"):
		return
	_key(int(game.binds[slot]), true)
	p.set_physics_process(true)
	var deadline := Time.get_ticks_msec() + 2000
	while observation.is_empty() and Time.get_ticks_msec() < deadline:
		await frames(1)
	observer_slot = ""
	_release()
	p.set_physics_process(false)
	entry["landing"] = observation.duplicate(true)
	if not _require_setup(not observation.is_empty(), label + " synthetic input fired the actual ability", entry, "dash"):
		return
	var landed: Vector2 = p.global_position
	_check(landed.distance_to(start) > nominal_distance * 0.5, label + " real class ability displaced hero")
	_check(absf(float(entry.start_mp) - p.mp - float(entry.cost)) < 0.5, label + " charged ordinary ability mana")
	_check(observation.hits.is_empty(), label + " landing is outside solid terrain", occupied_target)
	if not occupied_target:
		_check(landed.distance_to(target) < 25.0, label + " clear endpoint survives intervening scenery")
	if capture:
		await _capture(label + "_landing", geometry + "; first landing frozen before next movement step")
	# Observe real engine depenetration with zero requested velocity. This does
	# not claim a stuck player when physics actually ejects them next frame.
	var samples: Array = []
	for i in 12:
		await get_tree().physics_frame
		p.velocity = Vector2.ZERO
		p._move_body()
		if i in [0, 2, 11]:
			samples.append({"step": i + 1, "position": _v(p.global_position), "hits": _overlaps(p.global_position), "velocity": _v(p.velocity)})
	entry["zero_input_recovery"] = samples
	entry["recovery_displacement"] = landed.distance_to(p.global_position)
	_check(p.global_position.is_finite() and p.velocity.is_finite(), label + " physics recovery remains finite")
	if capture:
		await _capture(label + "_recovered", geometry + "; after 12 zero-input physics movement steps")
	report.dash.append(entry)


func _restore_solids() -> void:
	for saved in saved_solids:
		if is_instance_valid(saved.body):
			saved.body.collision_layer = int(saved.layer)
	saved_solids.clear()
