extends ShotRig
## Live keyboard walking at ordinary character speed/stats. One setup teleport.
## Candidate only: publish with its scene, then use the normal muted shot runner.
## --expect-gathering checks the four proposed existing furnishings; omit for baseline.

const WORLD_SEED := 903126
const ARRIVAL_RADIUS := 10.0
const AXIS_DEADZONE := 5.0
const STUCK_MS := 2500
const EXPECTED_FURNITURE := [
	["capital_city_bench", Vector2(460, 420)], ["garden_urns", Vector2(565, 430)],
	["capital_city_bench", Vector2(655, 870)], ["amphora", Vector2(745, 865)],
]

var held: Dictionary = {}
var checks: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var views: Array[Dictionary] = []
var reads: Array[Dictionary] = []
var setup: Dictionary = {}
var failures := 0
var room := -1
var initial_speed := 0.0
var initial_vitals: Dictionary = {}
var ilse: Dictionary = {}
var fenna: Dictionary = {}
var gate_direction := ""
var gate_neighbor := -1


func _ready() -> void:
	# Before main.tscn can load any user state: this fixture belongs in the
	# runner's isolated QA APPDATA, never the owner's normal save directory.
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _check("isolated_qa_user_directory", user_path.to_lower().contains("/build/qa/"), {"path": user_path}):
		_write_report()
		finish(1)
		return
	get_window().size = Vector2i(1280, 720)
	seed(WORLD_SEED)
	await boot("warrior", "ch3", false)
	var error := await _run()
	_release()
	if game != null:
		game.hud.cancel_conversation()
		game.request_pause(false)
	if error != "":
		_check("live_route_complete", false, {"reason": error})
		await frames(2)
		shot("diagnostic_failure", error)
	_write_report()
	print("VIGIL WALK: %d checks, %d failures, %d live legs, %d captures; one setup teleport, normal keyboard walking" % [checks.size(), failures, legs.size(), views.size()])
	finish(1 if failures > 0 else 0)


func _on_watchdog() -> void:
	_release()
	super._on_watchdog()


func _run() -> String:
	game.play_started = true
	game.state = Game.ST_PLAYING
	game.menus.close()
	game.request_pause(false)
	game.hud.visible = true
	game.dev_god = false
	game.settings["touch_controls"] = false # this rig proves the keyboard path
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.settings["combat_framing"] = false
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	await skip_dialogue()
	if not await _settle():
		return "Boot reveal did not settle"
	seed(WORLD_SEED)
	game.wander_seed = WORLD_SEED
	game.switch_chapter("ch3", true)
	for i in game.zones.size():
		if String(game.zones[i].get("name", "")) == "The Vigil Gate":
			room = i
	if room < 0:
		return "Actual Vigil room missing"
	game.terrain_event_t = 1.0e9
	game.npc_emote_t = 1.0e9
	await skip_dialogue()
	if not await _settle():
		return "Fixed-world reveal did not settle"
	ilse = _npc("cantor_ilse", "ch3_briefing")
	fenna = _npc("old_fenna", "ch3_refugee")
	if ilse.is_empty() or fenna.is_empty():
		return "Actual Ilse/Fenna identity missing"
	for dir in game.rooms[room]["exits"]:
		var other: int = game.neighbor(room, String(dir))
		var lock: Dictionary = game.edge_locks.get(game._edge_key(room, other), {})
		if String(lock.get("lock", "")) == "flag:ch3_briefed":
			gate_direction = String(dir)
			gate_neighbor = other
	if gate_neighbor < 0 or bool(game.get_flag("ch3_briefed", false)) or game._edge_unlocked(room, gate_neighbor):
		return "Fresh Ilse-briefing locked road precondition absent; no flags are forced"
	if game.net_online() or not game.no_saves or game.hud._auto_on:
		return "Requires offline no_saves and ordinary manual dialogue mode"
	var start := _world(Vector2(280, 624))
	if game._pos_in_wall(start):
		return "The one initial setup position is not open"
	# The ONLY explicit hero transform assignment in the walking fixture.
	game.player.global_position = start
	_release()
	await frames(5)
	initial_speed = game.player.speed
	initial_vitals = _vitals()
	setup = {"seed": WORLD_SEED, "initial_position": _xy(start), "speed": initial_speed,
		"vitals": initial_vitals, "god": game.dev_god, "no_saves": game.no_saves,
		"source_revision": arg("revision", "working-tree"), "label": arg("label", "baseline"),
		"user_directory": ProjectSettings.globalize_path("user://"),
		"fixture": "One setup teleport to open entry lane. All later travel is InputEventKey -> normal player physics/collision. No movement/stat inflation, actor freeze or prop injection. Random grave-spawn events and NPC emotes disabled for this safe-room walking inspection.",
		"expected_gathering": flag("expect-gathering"), "initial_furniture": _furniture(),
		"normal_zoom": _xy(game.camera.zoom), "camera_smoothing": game.camera.position_smoothing_enabled,
		"renderer": RenderingServer.get_current_rendering_method(), "viewport": _xy(get_viewport().get_visible_rect().size),
		"gate_direction": gate_direction, "gate_neighbor": gate_neighbor}
	_check("normal_live_player", game.player.is_processing() and game.player.is_physics_processing() and initial_speed > 0.0
		and not game.dev_god and not get_tree().paused and (game.player.collision_mask & 1) != 0)
	_check("normal_zoom_viewport", game.camera.zoom.is_equal_approx(Vector2.ONE * 1.12)
		and get_viewport().get_visible_rect().size == Vector2(1280, 720))
	_check("fixed_npc_positions", (ilse["node"] as Node2D).global_position.is_equal_approx(_world(Vector2(620, 500)))
		and (fenna["node"] as Node2D).global_position.is_equal_approx(_world(Vector2(800, 800))))
	if flag("expect-gathering"):
		_check("four_actual_authored_furnishings", _furniture().size() == EXPECTED_FURNITURE.size())
	if failures > 0:
		return "Initial live-world checks failed"
	if not await _route("ilse_south", [Vector2(620, 624), Vector2(620, 560)]):
		return "Ilse south route blocked"
	if not await _approach("01_ilse_south", ilse):
		return "Ilse south prompt failed"
	if not await _read_first("02_ilse_actual_E", ilse, "Cantor Ilse", false):
		return "Ilse first-line delivery/cancel failed"
	if not await _route("ilse_east", [Vector2(700, 560), Vector2(700, 500), Vector2(680, 500)]):
		return "Ilse east route blocked"
	if not await _approach("03_ilse_east", ilse):
		return "Ilse east prompt failed"
	if not await _route("ilse_bench_south", [Vector2(700, 560), Vector2(460, 560), Vector2(460, 485)]):
		return "Ilse bench south route blocked"
	if not await _capture("04_ilse_bench_south"):
		return "Ilse bench south view unsettled"
	if not await _route("ilse_bench_north", [Vector2(350, 485), Vector2(350, 360), Vector2(460, 360)]):
		return "Ilse bench north route blocked"
	if not await _capture("05_ilse_bench_north"):
		return "Ilse bench north view unsettled"
	if not await _route("fenna_south", [Vector2(350, 360), Vector2(350, 624), Vector2(1056, 624),
			Vector2(1056, 900), Vector2(800, 900), Vector2(800, 860)]):
		return "Fenna south route blocked"
	if not await _approach("06_fenna_south", fenna):
		return "Fenna south prompt failed"
	if not await _read_first("07_fenna_actual_E", fenna, "Old Fenna", true):
		return "Fenna choice delivery/cancel failed"
	if not await _route("fenna_east", [Vector2(900, 860), Vector2(900, 800), Vector2(860, 800)]):
		return "Fenna east route blocked"
	if not await _approach("08_fenna_east", fenna):
		return "Fenna east prompt failed"
	if not await _route("fenna_bench_north", [Vector2(1056, 800), Vector2(1056, 624), Vector2(655, 624), Vector2(655, 810)]):
		return "Fenna bench north route blocked"
	if not await _capture("09_fenna_bench_north"):
		return "Fenna bench north view unsettled"
	if not await _route("fenna_bench_south", [Vector2(540, 810), Vector2(540, 935), Vector2(655, 935)]):
		return "Fenna bench south route blocked"
	if not await _capture("10_fenna_bench_south"):
		return "Fenna bench south view unsettled"
	if not await _route("center", [Vector2(800, 935), Vector2(1056, 935), Vector2(1056, 624)]):
		return "Return to center blocked"
	if not await _capture("11_open_center"):
		return "Center view unsettled"
	if not await _locked_door():
		return "Actual locked doorway walk/push failed"
	_check("normal_vitals_retained", initial_vitals == _vitals(), {"before": initial_vitals, "after": _vitals()})
	_check("input_released", _released())
	return ""


func _route(label: String, authored_points: Array) -> bool:
	for i in authored_points.size():
		var point: Vector2 = authored_points[i]
		if not await _walk_to("%s/%d" % [label, i], _world(point)):
			return false
	return true


func _walk_to(label: String, target: Vector2) -> bool:
	step(label)
	var p: Player = game.player
	var start := p.global_position
	var began := Time.get_ticks_msec()
	var deadline := began + int(clampf(start.distance_to(target) / maxf(initial_speed, 1.0) * 4000.0 + 3000.0, 5000.0, 18000.0))
	var progress_at := began
	var best := start.distance_to(target)
	var traveled := 0.0
	var previous := start
	var samples: Array[Dictionary] = []
	var sample_at := began
	var input_frames := 0
	while Time.get_ticks_msec() < deadline and p.global_position.distance_to(target) > ARRIVAL_RADIUS:
		if p.dead or game.cur_room != room or game.input_overlay_up() or get_tree().paused:
			break
		var delta := target - p.global_position
		_move(Vector2(signf(delta.x) if absf(delta.x) > AXIS_DEADZONE else 0.0,
			signf(delta.y) if absf(delta.y) > AXIS_DEADZONE else 0.0))
		input_frames += 1
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		traveled += previous.distance_to(p.global_position)
		previous = p.global_position
		var remaining := p.global_position.distance_to(target)
		if remaining < best - 2.0:
			best = remaining
			progress_at = now
		if now >= sample_at:
			samples.append({"ms": now - began, "position": _xy(p.global_position), "remaining": remaining})
			sample_at = now + 125
		if now - progress_at > STUCK_MS:
			break
	_release()
	await frames(3)
	var arrived := p.global_position.distance_to(target) <= ARRIVAL_RADIUS + 3.0
	var movement_proven := start.distance_to(target) <= ARRIVAL_RADIUS or (input_frames > 0
		and traveled >= start.distance_to(target) - ARRIVAL_RADIUS - 3.0)
	var record := {"leg": label, "start": _xy(start), "target": _xy(target), "end": _xy(p.global_position),
		"actual_distance_traveled": traveled, "net_displacement": start.distance_to(p.global_position),
		"duration_ms": Time.get_ticks_msec() - began, "arrived": arrived, "samples": samples, "input_frames": input_frames,
		"speed": p.speed, "physics_active": p.is_physics_processing(), "input_released": _released()}
	legs.append(record)
	return _check(label + "/actual_arrival", arrived and movement_proven and _released() and is_equal_approx(p.speed, initial_speed)
		and game.cur_room == room and not game.input_overlay_up() and not get_tree().paused
		and p.is_physics_processing() and not game._pos_in_wall(p.global_position), record)


func _approach(label: String, entry: Dictionary) -> bool:
	await frames(4)
	var npc: Node2D = entry["node"]
	var prompt: Label = entry["prompt"]
	var distance := game.player.global_position.distance_to(npc.global_position)
	if not _check(label + "/real_prompt", distance < float(entry["reach"]) and prompt.is_visible_in_tree()
		and game.interact_in_range, {"sprite": entry["sprite_name"], "convo": npc.get_meta("quest_convo", ""),
		"distance": distance, "reach": entry["reach"], "prompt": prompt.text}):
		return false
	return await _capture(label)


func _read_first(label: String, entry: Dictionary, who: String, choice: bool) -> bool:
	var prompt: Label = entry["prompt"]
	if not prompt.is_visible_in_tree() or game.player.global_position.distance_to((entry["node"] as Node2D).global_position) >= float(entry["reach"]):
		return _check(label + "/actual_target_before_E", false)
	var before := _story_receipt()
	var log_before: Dictionary = game.convo_log.duplicate(true)
	var order_before: Array = game.convo_log_order.duplicate(true)
	var history_before: Array = game.hud._dialogue_history.duplicate(true)
	var ready_by := Time.get_ticks_msec() + 1500
	while game.talk_cd > 0.0 and Time.get_ticks_msec() < ready_by:
		await get_tree().process_frame
	_press(int(game.binds.get("interact", KEY_E)), true)
	var deadline := Time.get_ticks_msec() + 1800
	while not game.hud.dialogue_active and not game.hud.choices_active and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_release()
	# The visible prompt before E identifies the actual nearest spawned entry.
	# Do not require active_facing_interactable: flat NPC art approached exactly
	# north/south deliberately leaves that temporary facing owner unset.
	var delivered: bool = game.hud.speaker_label.text == who and game.hud.choices_active == choice \
		and (game.hud.dialogue_active or game.hud.choices_active)
	_check(label + "/actual_E_delivery", delivered)
	# Let the real typewriter/chrome finish. Never advance a line or select a choice.
	deadline = Time.get_ticks_msec() + 9000
	while delivered and (game.hud.text_label.visible_ratio < 1.0 or game.hud.dialogue_box.modulate.a < 0.999) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var chrome_settled := delivered and game.hud.text_label.visible_ratio >= 1.0 and game.hud.dialogue_box.modulate.a >= 0.999
	_check(label + "/dialogue_reveal_settled", chrome_settled)
	if chrome_settled:
		await RenderingServer.frame_post_draw
		views.append({"id": label, "capture": shot(label), "scope": "Actual E first screen; no line advance or choice", "hero": _xy(game.player.global_position)})
	var delivered_text := game.hud.text_label.text
	# Explicit fixture cleanup via the existing transition-safe cancellation
	# method: it discards completion callbacks instead of granting the briefing.
	game.hud.cancel_conversation()
	game.request_pause(false)
	game.convo_log = log_before
	game.convo_log_order = order_before
	game.hud._dialogue_history = history_before
	await frames(4)
	var unchanged := before == _story_receipt()
	reads.append({"id": label, "speaker": who, "text": delivered_text, "choice_screen": choice,
		"delivered": delivered, "story_unchanged": unchanged, "cleanup": "Hud.cancel_conversation; restore read-only log/history snapshots only. No flags, rewards or gate state set."})
	_check(label + "/no_story_consequences", unchanged and not game._edge_unlocked(room, gate_neighbor))
	_write_report()
	if not delivered or not chrome_settled or not unchanged:
		return false
	return await _settle()


func _locked_door() -> bool:
	var inward: Vector2 = {"E": Vector2.LEFT, "W": Vector2.RIGHT, "N": Vector2.DOWN, "S": Vector2.UP}[gate_direction]
	var door := game.door_pos(room, gate_direction)
	if not await _walk_to("actual_locked_door_approach", door + inward * 150.0):
		return false
	var before := game.player.global_position
	var samples: Array[Vector2] = []
	var until := Time.get_ticks_msec() + 1400
	_move(-inward)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		samples.append(game.player.global_position)
		if game.cur_room != room or game.input_overlay_up():
			break
	_release()
	await frames(3)
	var end := game.player.global_position
	var tail_stable := samples.size() >= 8 and samples[-1].distance_to(samples[-8]) < 3.0
	var passed := game.cur_room == room and not game._edge_unlocked(room, gate_neighbor) \
		and not bool(game.get_flag("ch3_briefed", false)) and before.distance_to(end) > 20.0 \
		and end.distance_to(door) < 110.0 and tail_stable and _released()
	_check("actual_gate_blocks_held_movement", passed, {"door": _xy(door), "before": _xy(before), "after": _xy(end),
		"moved": before.distance_to(end), "door_distance": end.distance_to(door), "tail_stable": tail_stable, "frames": samples.size()})
	if not passed:
		return false
	return await _capture("12_actual_locked_door")


func _capture(label: String) -> bool:
	_release()
	if not await _settle():
		return false
	await sim_wait(0.6) # normal camera smoothing/idle pose, no camera teleport
	await RenderingServer.frame_post_draw
	views.append({"id": label, "capture": shot(label), "scope": "Reached on foot through normal collision/input",
		"hero": _xy(game.player.global_position), "hero_body": _rect(preload("res://scripts/ui/hud_clearance.gd").body_rect(game.player)),
		"camera_center": _xy(game.camera.get_screen_center_position()), "zoom": _xy(game.camera.zoom),
		"furniture": _furniture(), "vitals": _vitals()})
	_write_report()
	return true


func _npc(sprite: String, convo: String) -> Dictionary:
	for entry in game.interactables:
		var n: Node2D = entry.get("node") as Node2D
		if is_instance_valid(n) and game.room_at_pos(n.global_position) == room \
				and String(entry.get("sprite_name", "")) == sprite and String(n.get_meta("quest_convo", "")) == convo:
			return entry
	return {}


func _furniture() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in game.zone_scenery.get(room, []):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		for expected in EXPECTED_FURNITURE:
			if String(node.get_meta("structure", "")) != String(expected[0]) \
					or not node.global_position.is_equal_approx(_world(expected[1])):
				continue
			var base: Node2D = game._base_sprite_of(node)
			var casts: Array[Dictionary] = []
			for child in node.get_children():
				if child is Sprite2D and child.has_meta("cast_shadow"):
					casts.append({"mode": child.get_meta("cast_shadow_mode", ""), "visible": child.is_visible_in_tree(),
						"position": _xy(child.global_position), "scale": _xy(child.scale), "alpha": child.modulate.a})
			out.append({"structure": expected[0], "position": _xy(node.global_position),
				"hero_south_of_anchor": game.player.global_position.y > node.global_position.y,
				"base_alpha": base.modulate.a if is_instance_valid(base) else -1.0, "casts": casts})
	return out


func _settle() -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	var stable := 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var busy: bool = game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active
		for child in game.hud.get_children():
			busy = busy or child is Cutscene
		busy = busy or game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01
		busy = busy or (is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible)
		stable = 0 if busy else stable + 1
		if stable >= 3:
			return true
	return _check("world_reveal_settled", false)


func _story_receipt() -> Dictionary:
	return {"flags": game.flags.duplicate(true), "quest": game.quest_key, "resonance": game.player.resonance,
		"standing": game.player.faction_standing.duplicate(true), "gold": game.player.gold,
		"xp": game.player.xp, "level": game.player.level, "skill_points": game.player.skill_points}


func _vitals() -> Dictionary:
	return {"hp": game.player.hp, "max_hp": game.player.max_hp, "mp": game.player.mp,
		"max_mp": game.player.max_mp, "speed": game.player.speed, "level": game.player.level}


func _world(p: Vector2) -> Vector2:
	return game.room_pos(room, p.x, p.y)


func _xy(p: Vector2) -> Array:
	return [p.x, p.y]


func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _press(key: int, down: bool) -> void:
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
	_press(KEY_A, direction.x < 0.0)
	_press(KEY_D, direction.x > 0.0)
	_press(KEY_W, direction.y < 0.0)
	_press(KEY_S, direction.y > 0.0)


func _release() -> void:
	for key in held.keys():
		_press(int(key), false)
	if game != null and game.has_local_player():
		game.player.clear_local_intents()


func _released() -> bool:
	for key in held:
		if bool(held[key]) or Input.is_key_pressed(int(key)):
			return false
	return true


func _check(label: String, passed: bool, details: Dictionary = {}) -> bool:
	checks.append({"check": label, "passed": passed, "details": details})
	if not passed:
		failures += 1
		print("VIGIL WALK CHECK FAILED: ", label, " ", JSON.stringify(details))
	return passed


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		print("VIGIL WALK REPORT WRITE FAILED: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"setup": setup, "checks": checks, "failures": failures, "legs": legs, "reads": reads, "views": views}, "\t"))
	file.close()
