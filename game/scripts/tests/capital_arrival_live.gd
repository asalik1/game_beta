extends RefCounted
## Single Game owns spawning, camera, physics and outline. Reuse native menu
## input helpers. Queries run inside the outer physics observer and see the
## previous completed body step, rather than assuming process frames move it.

var r: ShotRig
var g: Game
var p: Player
var ui
var fountain: StaticBody2D
var visual: Node2D
var rows: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var motion: Array[Dictionary] = []
var clock := 0.0
var pending := ""
var observed := {}
var collecting := false
var held_key := 0
var boot_readiness := {}
var escape_input := {}

var menu_shortcuts_episode := {}
var npc_prompt_episode := {}
var fountain_episode := {"movement": [], "states": []}
var fountain_move_active := false
var fountain_move_target_y := 0.0
var fountain_move_sign_y := 0.0
var fountain_move_release := {}
var fountain_draw_prompt: Label
var fountain_draw_anchor := Vector2.ZERO
var fountain_draw_has_anchor := false
var fountain_draw_leg := ""
var fountain_draw_previous_world := Vector2.ZERO
var fountain_draw_previous_screen := Vector2.ZERO
var fountain_draw_samples: Array[Dictionary] = []
var fountain_anchor_settled: Array[Dictionary] = []


func run(rig: ShotRig) -> Dictionary:
	r = rig
	g = r.game
	p = g.local_player
	ui = preload("res://scripts/tests/menu_navigation_live.gd").new()
	ui.r = r
	ui.g = g
	ui.m = g.menus
	var error := await _run()
	_fountain_stop_draw()
	if held_key != 0:
		_key(held_key, false)
		held_key = 0
	fountain_move_active = false
	collecting = false
	pending = ""
	await r.frames(2)
	_check("runtime.completed", error == "", error)
	_check("fixture.no_save_or_network", g.no_saves and not g.net_online(), {"no_saves": g.no_saves, "online": g.net_online()})
	_check("input.released", not Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_ESCAPE)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "all held presses released")
	if r.flag("fountain-prompt"):
		_check("fountain.input.released", not Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_W),
			"all S/W holds released, including error exits")
	if r.flag("fountain-after"):
		for proof in fountain_anchor_settled:
			_check("fountain." + String(proof.id) + ".anchor_adjustment", bool(proof.passed), proof)
		var draw_verdict: Dictionary = _fountain_draw_verdict()
		_check("fountain.motion_anchor_clearance", bool(draw_verdict.passed), draw_verdict)
		fountain_episode["after_draw"] = {"settled": fountain_anchor_settled,
			"samples": fountain_draw_samples, "aggregate": draw_verdict}
	var report := {"baseline": r.flag("baseline"), "checks": rows.size(), "passed": 0,
		"findings": 0, "failures": 0, "rows": rows, "samples": samples, "motion": motion,
		"boot_readiness": boot_readiness, "escape_input": escape_input,
		"qualification": "Single normal main.tscn Game; standard QA mage/ch1 boot and opening choice, no saves, no god mode, no body/camera position or physics override. Real Pause Travel to Crownfall click, real welcome key input, live one-second idle and one-second A escape. No save/load or ENet proof.",
		"mouse_clicks": ui.mouse_clicks, "key_taps": ui.key_taps,
		"settings": g.settings.duplicate(true)}
	if not menu_shortcuts_episode.is_empty():
		report["menu_shortcuts"] = menu_shortcuts_episode
		report["qualification"] = menu_shortcuts_episode.scope
	if not npc_prompt_episode.is_empty():
		report["npc_prompt"] = npc_prompt_episode
		report["qualification"] = "Single normal Game and original Voss reached through real capital travel/welcome/A movement. Native Inventory/Escape/E/Leave; no rewards or assigned actor positions. Optional npc-prompt-controls borrows camera offset/vitals position and freezes Game processing/Player physics, then restores display/processing state after unchanged-resource checks. NPC breathing and world children remain live. Disposable no-save solo fixture; no physical-device, controller, network or crowd coverage."
	if r.flag("fountain-prompt"):
		report["fountain_prompt"] = fountain_episode
		report["qualification"] = "Single normal Game and unchanged capital HUD; shared ordinary Pause/Travel/welcome boot, then three real S/S/W holds and four settled native frames. No assigned position, camera, quest, target, prompt visibility, resources or saves. Geometry includes the entire label pill and shaped text cells plus authored outline. Source-derived expected overlap is not native acceptance; no physical touch/controller or ENet claim."
	if r.flag("arrival-consumers"):
		report["arrival_consumer_qualification"] = "After the ordinary fresh-arrival leg: direct map opening then real destination clicks, real A nudges then direct Recall and _death_respawn landing calls. No recall-scroll ownership/consumption, lethal damage, death tithe or respawn delay is claimed. The existing live physics sampler observes each landing."
	for row in rows:
		if row.passed: report.passed += 1
		elif row.known_defect and r.flag("baseline"): report.findings += 1
		else: report.failures += 1
	return report


func _run() -> String:
	if r.flag("fountain-after") and (not r.flag("fountain-prompt") or r.flag("baseline")):
		return "fountain-after requires fountain-prompt without baseline"
	if not _check("fixture.normal_solo", g.no_saves and not g.net_online() and not g.dev_god
			and p.is_physics_processing() and g.players.size() == 1 and g.get_viewport() == r.get_viewport(),
			{"physics": p.is_physics_processing(), "god": g.dev_god, "players": g.players.size(),
			"same_viewport": g.get_viewport() == r.get_viewport()}):
		return "requires one normal live player in the main viewport"
	r.step("observe completion of the ordinary boot cinematic")
	if not await _wait_boot_ready():
		return "Boot did not reach ordinary Escape readiness; see boot_readiness gates"
	r.step("ordinary Pause menu travel to Crownfall")
	await _observe_escape()
	if not _check("input.pause", g.menus.is_open() and g.menus.current == "pause"
			and not Input.is_key_pressed(KEY_ESCAPE), escape_input):
		return "Escape did not open Pause"
	var button: Button = ui._find_button(g.menus.root, "Travel to Crownfall")
	if not _check("input.travel_button", button != null, "ordinary solo capital entry"):
		return "Travel to Crownfall is unavailable"
	await ui._mouse(button.get_global_rect().get_center())
	await r.frames(3)
	var deadline := Time.get_ticks_msec() + 8000
	while g.hud.dialogue_active and Time.get_ticks_msec() < deadline:
		if g.hud.choices_active: return "unexpected choice in the capital welcome"
		await ui._key(KEY_SPACE)
	if not _check("travel.capital_play", g.chapter_id == "capital" and g.cur_room == 0
			and not g.input_overlay_up() and not g.get_tree().paused and p.is_physics_processing(),
			{"chapter": g.chapter_id, "room": g.cur_room, "overlay": g.input_overlay_up(), "paused": g.get_tree().paused}):
		return "normal capital arrival did not reach unpaused play"
	for node in g.world.find_children("*", "StaticBody2D", true, false):
		if String(node.get_meta("structure", "")) == "capital_crown_fountain":
			fountain = node as StaticBody2D
			break
	if fountain != null:
		for node in fountain.get_children():
			if node is Node2D and node.is_in_group("structure_occluders"):
				visual = node
				break
	if not _check("geometry.actual_fountain", is_instance_valid(visual), "rendered production structure/occluder"):
		return "actual capital fountain visual is missing"
	if r.flag("fountain-prompt"):
		return await _fountain_prompt()
	var initial := await _sample("arrival")
	if initial.is_empty(): return "arrival physics observation timed out"
	_check("spawn.authored", p.global_position.distance_to(g._start_pos()) <= 0.5,
		{"actual": _vec(p.global_position), "authored": _vec(g._start_pos())})
	_assert_sample(initial, true)
	await _capture("00_normal_arrival")
	r.step("one second of normal idle with live physics")
	var idle_start: Vector2 = p.global_position
	var idle_clock := clock
	if not await _wait_physics(0.5): return "idle physics clock did not advance"
	var midway := await _sample("idle_half_second")
	if midway.is_empty(): return "mid-idle physics observation timed out"
	_assert_sample(midway, true)
	if not await _wait_physics(0.5): return "idle physics clock did not finish"
	var idle := await _sample("idle_one_second")
	if idle.is_empty(): return "idle physics observation timed out"
	_assert_sample(idle, true)
	_check("idle.live_and_stationary", clock - idle_clock >= 1.0 and p.global_position.distance_to(idle_start) <= 0.5,
		{"physics_seconds": clock - idle_clock, "distance": p.global_position.distance_to(idle_start)})
	await _capture("01_idle_one_second")
	r.step("one second of actual A input escapes the fountain silhouette")
	var start: Vector2 = p.global_position
	var start_clock := clock
	collecting = true
	held_key = KEY_A
	_key(KEY_A, true)
	var moved := await _wait_physics(1.0)
	_key(KEY_A, false)
	held_key = 0
	collecting = false
	if not moved: return "movement physics clock did not advance"
	# Two further physics observations ensure release has reached the body.
	var released := await _sample("escape_release")
	if released.is_empty(): return "release physics observation timed out"
	var escaped := await _sample("escape_settled")
	if escaped.is_empty(): return "escape physics observation timed out"
	_assert_sample(escaped, false)
	_check("movement.real_lateral_escape", start.x - p.global_position.x > 160.0
			and absf(p.global_position.y - start.y) < 12.0 and clock - start_clock >= 1.0,
			{"start": _vec(start), "end": _vec(p.global_position), "physics_seconds": clock - start_clock, "observations": motion.size()})
	_check("movement.fountain_cleared", not bool(escaped.fountain_covering), escaped)
	_check("movement.stopped", p.velocity.length() <= 1.0, _vec(p.velocity))
	await _capture("02_keyboard_escape")
	if r.flag("menu-shortcuts"):
		menu_shortcuts_episode = await preload("res://scripts/tests/menu_shortcuts_live.gd").run(self)
		return String(menu_shortcuts_episode.error)
	if r.flag("npc-prompt"):
		npc_prompt_episode = await preload("res://scripts/tests/npc_prompt_live.gd").run(self)
		return String(npc_prompt_episode.error)
	if r.flag("arrival-consumers"):
		return await _arrival_consumers()
	return ""


## ShotRig skips dialogue flags, but the illustrated opener's natural fade
## still owns the begin callback that sets play_started. Observe readiness;
## never set it, clear a cooldown, finish a tween or retry Escape through it.
func _wait_boot_ready() -> bool:
	var started := Time.get_ticks_msec()
	boot_readiness = {"started_ms": started, "initial": _input_state(), "transitions": []}
	var previous: Array = []
	var ready := false
	while Time.get_ticks_msec() < started + 8000:
		var state := _input_state()
		var signature := [state.play_started, state.state, state.dialogue, state.choices,
			state.chapter_finale, state.cinematic_mode, state.cutscene_reference,
			state.illustrated_layers.size(), state.paused, state.menu_open, state.hud_can_process]
		if signature != previous:
			boot_readiness.transitions.append(state)
			previous = signature
		if _escape_ready(state):
			# Also allow deferred Cutscene queue_free/_exit_tree to settle normally.
			await r.frames(2)
			ready = _escape_ready(_input_state())
			if ready:
				break
		await g.get_tree().create_timer(0.05, true, false, true).timeout
	boot_readiness["final"] = _input_state()
	boot_readiness["elapsed_ms"] = Time.get_ticks_msec() - started
	return _check("fixture.boot_ready_for_escape", ready, boot_readiness)


func _escape_ready(state: Dictionary) -> bool:
	return bool(state.play_started) and int(state.state) == Game.ST_PLAYING \
		and not state.dialogue and not state.choices and not state.chapter_finale \
		and not state.menu_open and not state.paused and not state.overlay \
		and not state.cinematic_mode and not state.cutscene_reference \
		and state.illustrated_layers.is_empty() and state.hud_can_process \
		and state.hud_unhandled_input and state.hero_physics and not state.hero_dead and not state.escape_down


## Escape is an event-driven Hud._unhandled_input route. Keep the shared
## helper's one-frame tap duration; add observations around this single edge.
func _observe_escape() -> void:
	escape_input = {"before": _input_state(), "route": "one Input.parse_input_event press/release; no retry"}
	held_key = KEY_ESCAPE
	_key(KEY_ESCAPE, true)
	escape_input["after_press_dispatch"] = _input_state()
	await r.frames(1)
	escape_input["before_release"] = _input_state()
	_key(KEY_ESCAPE, false)
	held_key = 0
	ui.key_taps += 1
	escape_input["after_release_dispatch"] = _input_state()
	await r.frames(3)
	escape_input["settled"] = _input_state()


func _input_state() -> Dictionary:
	var art: Array[Dictionary] = []
	for child in g.hud.get_children():
		if child is Cutscene:
			art.append({"path": str(child.get_path()), "queued_for_deletion": child.is_queued_for_deletion(),
				"finish_started": child._finish_started, "alpha": child.modulate.a})
	var focus := g.get_viewport().gui_get_focus_owner()
	return {"at_ms": Time.get_ticks_msec(), "process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(), "play_started": g.play_started, "state": g.state,
		"dialogue": g.hud.dialogue_active, "dialogue_index": g.hud.dialogue_index,
		"dialogue_lines": g.hud.dialogue_lines.size(), "choices": g.hud.choices_active,
		"chapter_finale": g.chapter_finale.active, "cinematic_mode": g.hud._cinematic_mode,
		"cutscene_reference": is_instance_valid(g.cutscene), "illustrated_layers": art,
		"menu_open": g.menus.is_open(), "menu": g.menus.current,
		"menu_root_valid": is_instance_valid(g.menus.root), "overlay": g.input_overlay_up(),
		"paused": g.get_tree().paused, "hud_visible": g.hud.visible,
		"hud_can_process": g.hud.can_process(), "hud_unhandled_input": g.hud.is_processing_unhandled_input(),
		"focus_owner": str(focus.get_path()) if focus != null else "",
		"talk_cd": g.talk_cd, "escape_down": Input.is_key_pressed(KEY_ESCAPE),
		"viewport_handled": g.get_viewport().is_input_handled(), "chapter": g.chapter_id,
		"hero_physics": p.is_physics_processing(), "hero_dead": p.dead,
		"hero_position": _vec(p.global_position), "hero_velocity": _vec(p.velocity)}


func physics_tick(delta: float) -> void:
	if not is_instance_valid(p): return
	clock += delta
	# Stop a fountain key hold between body steps, including render catch-up.
	# The player's next physics step still consumes ordinary released input.
	if fountain_move_active and fountain_move_sign_y * (p.global_position.y - fountain_move_target_y) >= 0.0:
		var released_key: int = held_key
		_key(released_key, false)
		fountain_move_release = {"position": _vec(p.global_position), "physics_frame": Engine.get_physics_frames(),
			"in_physics": Engine.is_in_physics_frame(), "key": "S" if released_key == KEY_S else "W",
			"key_up": not Input.is_key_pressed(released_key)}
		held_key = 0
		fountain_move_active = false
	if collecting:
		motion.append({"frame": Engine.get_physics_frames(), "at": _vec(p.global_position), "velocity": _vec(p.velocity)})
	if pending != "":
		observed = _snapshot(pending)
		pending = ""


func _sample(label: String) -> Dictionary:
	observed = {}
	pending = label
	var deadline := Time.get_ticks_msec() + 8000
	while pending != "" and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	pending = ""
	if not observed.is_empty(): samples.append(observed)
	return observed


func _wait_physics(seconds: float) -> bool:
	var end := clock + seconds
	var deadline := Time.get_ticks_msec() + 8000
	while clock < end and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	return clock >= end


func _snapshot(label: String) -> Dictionary:
	var colliders: Array[Dictionary] = []
	var body_found := false
	for child in p.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		body_found = true
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.collision_mask = p.collision_mask
		query.exclude = [p.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		for hit in p.get_world_2d().direct_space_state.intersect_shape(query, 32):
			var node := hit.get("collider") as Node
			colliders.append({"path": str(node.get_path()) if node != null else "unknown",
				"structure": String(node.get_meta("structure", "")) if node != null else ""})
	var alpha: Array[float] = []
	var painted_probe := false
	for offset in Balance.PLAYER_OCCLUSION_PROBES:
		var value: float = p._visual_alpha_at(visual, p.global_position + offset)
		alpha.append(value)
		painted_probe = painted_probe or value >= Balance.PLAYER_OCCLUSION_ALPHA_THRESHOLD
	var covering: Array = p._covering_structures()
	var clip = p._occlusion_clips.get(visual.get_instance_id())
	var names: Array[String] = []
	for node in covering: names.append(str(node.get_path()))
	return {"label": label, "physics_frame": Engine.get_physics_frames(), "physics_seconds": clock,
		"query_in_physics": Engine.is_in_physics_frame(), "physics_enabled": p.is_physics_processing(),
		"body_found": body_found, "body_collisions": colliders, "position": _vec(p.global_position),
		"velocity": _vec(p.velocity), "finite": p.global_position.is_finite() and p.velocity.is_finite(),
		"authored_start": _vec(g._start_pos()), "room_center": _vec(g.room_center(g.cur_room)),
		"screen_node_origin": _vec(p.get_global_transform_with_canvas().origin),
		"fountain_anchor": _vec(fountain.global_position), "fountain_sort_y": visual.get_meta("occlusion_sort_y", null),
		"fountain_canvas_world": _visual_bounds(), "fountain_colliders": _fountain_bodies(),
		"visual_class": visual.get_class(), "animation_frame": visual.frame if visual is AnimatedSprite2D else 0,
		"alpha_probes": alpha, "alpha_threshold": Balance.PLAYER_OCCLUSION_ALPHA_THRESHOLD,
		"alpha_predicts_cover": painted_probe and p.global_position.y < float(visual.get_meta("occlusion_sort_y", visual.global_position.y)),
		"fountain_covering": covering.has(visual), "covering_paths": names,
		"outline_valid": is_instance_valid(clip), "outline_visible": is_instance_valid(clip) and clip.is_visible_in_tree(),
		"same_world_owner": g.world.is_ancestor_of(visual), "camera_position": _vec(g.camera.global_position),
		"camera_zoom": _vec(g.camera.zoom), "camera_smoothing": g.camera.position_smoothing_enabled}


func _visual_bounds() -> Dictionary:
	var rect := Rect2()
	if visual is Sprite2D:
		rect = visual.get_rect()
	elif visual is AnimatedSprite2D:
		var tex: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
		rect = Rect2(visual.offset - tex.get_size() * 0.5 if visual.centered else visual.offset, tex.get_size())
	return _world_rect(visual, rect)


func _fountain_bodies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in fountain.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			result.append(_world_rect(child, Rect2(-child.shape.size * 0.5, child.shape.size)))
	return result


func _world_rect(node: Node2D, rect: Rect2) -> Dictionary:
	var bounds := Rect2(node.to_global(rect.position), Vector2.ZERO)
	for point in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		bounds = bounds.expand(node.to_global(point))
	return {"position": _vec(bounds.position), "size": _vec(bounds.size)}


func _assert_sample(sample: Dictionary, arrival: bool, legacy_center_route := false) -> void:
	var prefix := String(sample.label)
	_check(prefix + ".live_physics_body", sample.query_in_physics and sample.physics_enabled and sample.body_found and sample.finite, sample)
	# Only the known old-center fountain overlap is a baseline finding.
	# A mixed set containing a wall or any other prop must remain strict.
	var legacy_fountain_overlap: bool = legacy_center_route and not sample.body_collisions.is_empty()
	for hit in sample.body_collisions:
		if String(hit.get("structure", "")) != "capital_crown_fountain":
			legacy_fountain_overlap = false
			break
	_check(prefix + ".body_clear", sample.body_collisions.is_empty(), sample.body_collisions, legacy_fountain_overlap)
	_check(prefix + ".alpha_model_agrees", sample.fountain_covering == sample.alpha_predicts_cover, sample)
	_check(prefix + ".outline_ownership", sample.same_world_owner and (not sample.fountain_covering or (sample.outline_valid and sample.outline_visible)), sample)
	if arrival:
		_check(prefix + ".hero_visible", not sample.fountain_covering, sample, true)


func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _capture(label: String) -> void:
	await r.frames(2)
	await RenderingServer.frame_post_draw
	if not r.flag("no-capture"):
		r.shot(label, "single normal Game; ordinary capital entry; player physics and camera untouched")


func _check(id: String, passed: bool, actual: Variant, known_defect := false) -> bool:
	rows.append({"id": id, "passed": passed, "known_defect": known_defect, "actual": actual})
	print("CAPITAL ARRIVAL CHECK %s: %s" % [id, "PASS" if passed else ("FINDING" if known_defect and r.flag("baseline") else "FAIL")])
	return passed


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]


func _arrival_consumers() -> String:
	# The new helper must leave geometric centers and every other ward intact.
	_check("arrival.geometric_center_preserved", g.room_center(0) == g.rooms[0].origin + Vector2(1056,624), _vec(g.room_center(0)))
	if g.has_method("room_arrival_pos"):
		for zi in range(1,g.zone_count):
			_check("arrival.other_ward_" + str(zi), g.call("room_arrival_pos",zi) == g.room_center(zi), _vec(g.call("room_arrival_pos",zi)))
	r.step("capital map destination clicks, then Recall and respawn landing diagnostics")
	var other := -1
	for zi in g.zone_count:
		if String(g.zones[zi].name) == "The Ashen Tankard": other=zi
	if other<0: return "capital fixture has no Ashen Tankard map target"
	var error := await _map_destination(other)
	if error!="": return error
	_check("arrival.other_ward_map_center", p.global_position.distance_to(g.room_center(other))<=0.5, _vec(p.global_position))
	error=await _map_destination(0)
	if error!="": return error
	error=await _observe_arrival("map_return")
	if error!="": return error
	if not await _arrival_nudge(): return "Recall setup A input did not move the live body"
	if not g.recall_to_safe(): return "direct Recall landing was unexpectedly refused"
	error=await _observe_arrival("recall_return")
	if error!="": return error
	if not await _arrival_nudge(): return "respawn setup A input did not move the live body"
	# Intentionally exercise placement/revive only, without manufacturing a
	# death or claiming its combat/tithe/delay behavior was tested.
	g._death_respawn(p,g.cur_room,0)
	return await _observe_arrival("respawn_return")


func _map_destination(zi: int) -> String:
	# Opening is a declared fixture seam; destination activation is native input.
	g.menus.open_map()
	await r.frames(3)
	var target: Button
	for node in g.menus.root.find_children("*","Button",true,false):
		if not node.disabled and node.tooltip_text.begins_with(String(g.zones[zi].name)+"\n") and "Select to fast travel" in node.tooltip_text:
			target=node as Button
			break
	if target==null: return "capital map did not offer destination " + str(zi)
	await ui._mouse(target.get_global_rect().get_center())
	await r.frames(3)
	if g.cur_room!=zi or g.menus.is_open(): return "native map destination click did not travel"
	return ""


func _arrival_nudge() -> bool:
	var before: Vector2=p.global_position
	held_key=KEY_A
	_key(KEY_A,true)
	var ticked := await _wait_physics(0.25)
	_key(KEY_A,false)
	held_key=0
	await _sample("consumer_nudge_release")
	await _sample("consumer_nudge_settled")
	return ticked and before.distance_to(p.global_position)>10.0


func _observe_arrival(label: String) -> String:
	# Two observations see completed body steps before judging legacy-center
	# penetration. The old center's body overlap is a baseline finding here,
	# never a waived strict-after check or a relaxed live-physics requirement.
	await _sample(label+"_first_step")
	var observed_landing := await _sample(label)
	if observed_landing.is_empty(): return label+" physics observation timed out"
	_check(label+".authored_arrival", p.global_position.distance_to(g._start_pos())<=0.5,
		{"actual":_vec(p.global_position),"expected":_vec(g._start_pos())},true)
	_assert_sample(observed_landing,true,true)
	await _capture("03_"+label)
	return ""


## Optional ordinary fountain case. No labels, entries, player position,
## camera, resources or presentation state are assigned by this episode.
func _fountain_prompt() -> String:
	if not _check("fountain.fixture.exclusive", not r.flag("arrival-consumers") and not r.flag("no-capture"),
			"isolated four-frame episode; neither arrival-consumers nor no-capture"):
		return "fountain-prompt requires its isolated capture episode"
	var entry: Dictionary = {}
	var authored: String = g.touchify("E — Inspect the Crown Fountain")
	for candidate in g.interactables:
		var label := candidate.get("prompt") as Label
		if is_instance_valid(label) and label.text == authored:
			entry = candidate
			break
	if not _check("fountain.fixture.real_prompt", not entry.is_empty()
			and is_instance_valid(entry.get("node")) and float(entry.get("reach", 0.0)) == Balance.PROP_HOTSPOT_REACH,
			{"text": authored, "entry_found": not entry.is_empty(), "reach": entry.get("reach", 0.0)}):
		return "ordinary fountain interaction entry missing"
	var prompt: Label = entry.prompt
	var start: Vector2 = p.global_position
	var before: Dictionary = {}
	for spec in [{"id": "00_arrival", "y": 0.0}, {"id": "01_south_near", "y": 8.0},
			{"id": "02_south_header", "y": 30.0}, {"id": "03_return", "y": 0.0}]:
		var id: String = "fountain." + String(spec.id)
		if spec.id != "00_arrival":
			if r.flag("fountain-after"):
				_fountain_draw_begin_leg(String(spec.id))
				# Drain the previous capture before ordinary input; no body/camera writes.
				await r.frames(2)
			var movement: Dictionary = await _fountain_move(start.y + float(spec.y))
			fountain_episode.movement.append(movement)
			if not _check(id + ".real_movement", movement.reached and movement.physics_steps > 0
					and movement.observations > 0 and movement.distance > 2.0 and movement.lateral_drift <= 1.0
					and movement.release_in_physics, movement):
				return id + " actual key movement did not reach its bounded target"
			if not _check(id + ".key_released", not Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_W), movement):
				return id + " held movement input was not released"
		var settle: Dictionary = await _fountain_settle(prompt)
		if not _check(id + ".camera_settled", settle.ready, settle):
			return id + " camera/body/ordinary presentation did not settle"
		if before.is_empty():
			before = _fountain_economy()
			if r.flag("fountain-after"):
				_fountain_start_draw(prompt)
		# Existing observer is the only place that queries physics; two samples
		# include a complete body step after key release before judging overlap.
		await _sample(id + ".release")
		var body: Dictionary = await _sample(id + ".settled")
		if not _check(id + ".live_physics", not body.is_empty() and body.query_in_physics
				and body.physics_enabled and body.body_found and body.finite and p.velocity.length() <= 1.0, body):
			return id + " live physics observation failed"
		_check(id + ".body_clear", body.body_collisions.is_empty(), body.body_collisions)
		# Settle the exact frame to be exported before measuring the screen.
		await r.frames(2)
		await RenderingServer.frame_post_draw
		var geometry: Dictionary = _fountain_geometry(prompt, entry)
		geometry["id"] = spec.id
		geometry["settle"] = settle
		geometry["body"] = body
		fountain_episode.states.append(geometry)
		if r.flag("fountain-after"):
			var anchor_proof: Dictionary = _fountain_anchor_proof(prompt)
			anchor_proof["id"] = String(spec.id)
			fountain_anchor_settled.append(anchor_proof)
		_check(id + ".normal_hud", geometry.normal_hud, geometry.hud_state)
		_check(id + ".prompt_selected_visible", geometry.prompt_visible and geometry.visible_prompts == 1
			and geometry.distance < geometry.reach and g.interact_in_range, geometry)
		_check(id + ".complete_text", geometry.full_text, geometry.prompt)
		_check(id + ".on_screen", geometry.on_screen, geometry.prompt)
		_check(id + ".header_complete", geometry.header_complete, geometry.header)
		_check(id + ".tracker_clear", geometry.tracker_clear, geometry, spec.id == "02_south_header")
		_check(id + ".other_hud_clear", geometry.other_hud_hits.is_empty(), geometry.other_hud_hits)
		_check(id + ".capture_settled", prompt.get_global_transform_with_canvas().origin.distance_to(
			Vector2(settle.origin[0], settle.origin[1])) <= 0.5 and p.velocity.length() <= 1.0, geometry)
		r.shot(String(spec.id), "normal Crown Plaza header; actual fountain prompt; real S/W movement; no posed HUD or camera")
	_check("fountain.return_near_start", p.global_position.distance_to(start) <= 12.0,
		{"start": _vec(start), "end": _vec(p.global_position)})
	_check("fountain.no_economy_or_view_changes", _fountain_economy() == before,
		{"before": before, "after": _fountain_economy()})
	return ""


func _fountain_move(target_y: float) -> Dictionary:
	var start: Vector2 = p.global_position
	var sign_y: float = 1.0 if target_y > start.y else -1.0
	var key: int = KEY_S if sign_y > 0.0 else KEY_W
	var started: int = Time.get_ticks_msec()
	var first_step: int = Engine.get_physics_frames()
	var first_motion: int = motion.size()
	fountain_move_target_y = target_y
	fountain_move_sign_y = sign_y
	fountain_move_release = {}
	fountain_move_active = true
	held_key = key
	collecting = true
	_key(key, true)
	while fountain_move_active and Time.get_ticks_msec() < started + 3000:
		if g.input_overlay_up() or p.dead or g.get_tree().paused:
			break
		await r.frames(1)
	if held_key != 0:
		_key(held_key, false)
		held_key = 0
	fountain_move_active = false
	collecting = false
	return {"key": "S" if key == KEY_S else "W", "presses": 1, "releases": 1,
		"release_in_physics": not fountain_move_release.is_empty() and bool(fountain_move_release.get("in_physics", false))
			and bool(fountain_move_release.get("key_up", false)), "release_observation": fountain_move_release.duplicate(true),
		"start": _vec(start), "release": _vec(p.global_position), "target_y": target_y,
		"reached": sign_y * (p.global_position.y - target_y) >= 0.0,
		"distance": p.global_position.distance_to(start), "lateral_drift": absf(p.global_position.x - start.x),
		"physics_steps": Engine.get_physics_frames() - first_step, "observations": motion.size() - first_motion,
		"elapsed_ms": Time.get_ticks_msec() - started}


func _fountain_settle(prompt: Label) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var stable_since: int = started
	var previous: Vector2 = prompt.get_global_transform_with_canvas().origin
	var anchor: Vector2 = previous
	var ready := false
	var drift := 0.0
	while Time.get_ticks_msec() < started + 8000:
		await g.get_tree().create_timer(0.05, true, false, true).timeout
		var now: Vector2 = prompt.get_global_transform_with_canvas().origin
		drift = now.distance_to(previous)
		var quiet: bool = p.velocity.length() <= 1.0 and not g.input_overlay_up() and not g.get_tree().paused \
			and _fountain_alpha(g.hud.title_label) < 0.01 and _fountain_alpha(g.hud.subtitle_label) < 0.01 \
			and g.hud.overlay.color.a * _fountain_alpha(g.hud.overlay) < 0.01 and not is_instance_valid(g.hud._ann_active)
		if not quiet or drift > 0.1 or now.distance_to(anchor) > 0.25:
			stable_since = Time.get_ticks_msec()
			anchor = now
		previous = now
		if quiet and Time.get_ticks_msec() - stable_since >= 300:
			ready = true
			break
	return {"ready": ready, "elapsed_ms": Time.get_ticks_msec() - started,
		"stable_ms": Time.get_ticks_msec() - stable_since, "last_step_drift": drift,
		"origin": _vec(previous), "camera_offset": _vec(g.camera.offset), "hero": _vec(p.global_position)}


func _fountain_geometry(prompt: Label, entry: Dictionary) -> Dictionary:
	var anchor_value: Variant = prompt.get_meta("landmark_prompt_anchor") if prompt.has_meta("landmark_prompt_anchor") else null
	var has_authored_anchor: bool = typeof(anchor_value) == TYPE_VECTOR2
	var authored_anchor := Vector2.ZERO
	if has_authored_anchor: authored_anchor = anchor_value
	var shape: Dictionary = _fountain_text(prompt)
	var bounds := Rect2(Vector2(shape.outer.position[0], shape.outer.position[1]),
		Vector2(shape.outer.size[0], shape.outer.size[1]))
	var tracker: Rect2 = g.hud.quest_panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, g.hud.quest_panel.size)
	var header: Dictionary = _fountain_text(g.hud.zone_label)
	var visible_count := 0
	for candidate in g.interactables:
		var label := candidate.get("prompt") as Label
		if is_instance_valid(label) and label.is_visible_in_tree() and _fountain_alpha(label) >= 0.99:
			visible_count += 1
	var other_hits: Array[Dictionary] = []
	var other_bounds: Dictionary = {}
	for field: String in ["vitals_panel", "info_panel", "minimap_root"]:
		var control: Control = g.hud.get(field)
		var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		other_bounds[field] = _fountain_rect(rect)
		if control.is_visible_in_tree() and _fountain_alpha(control) > 0.01 and bounds.intersects(rect.grow(-0.5)):
			other_hits.append({"field": field, "rect": _fountain_rect(rect)})
	var hud_state: Dictionary = {"zone": g.hud.zone_label.text, "quest": g.hud.quest_label.text,
		"quest_visible": g.hud.quest_label.is_visible_in_tree(), "boss": g.hud.boss_box.is_visible_in_tree(),
		"mob": g.hud.mob_box.is_visible_in_tree(), "rival": g.hud.rival_box.is_visible_in_tree(),
		"overlay": g.input_overlay_up(), "chapter": g.chapter_id, "room": g.cur_room}
	return {"prompt": shape, "header": header, "tracker": _fountain_rect(tracker), "other_hud": other_bounds,
		"prompt_visible": prompt.is_visible_in_tree() and _fountain_alpha(prompt) >= 0.99,
		"visible_prompts": visible_count, "distance": p.global_position.distance_to(entry.node.global_position),
		"reach": float(entry.reach), "hotspot": _vec(entry.node.global_position),
		"authored_local_anchor": _vec(authored_anchor) if has_authored_anchor else [],
		"has_authored_anchor_metadata": has_authored_anchor,
		"actual_local_position": _vec(prompt.position), "full_text": shape.complete,
		"on_screen": g.get_viewport_rect().grow(0.5).encloses(bounds),
		"tracker_clear": not bounds.intersects(tracker.grow(-0.5)), "other_hud_hits": other_hits,
		"normal_hud": hud_state.zone == "Crown Plaza" and hud_state.quest.is_empty()
			and not hud_state.quest_visible and not hud_state.boss and not hud_state.mob and not hud_state.rival
			and not hud_state.overlay and g.chapter_id == "capital" and g.cur_room == 0,
		"header_complete": header.complete and g.hud.zone_label.is_visible_in_tree()
			and _fountain_alpha(g.hud.zone_label) >= 0.99 and tracker.grow(0.5).encloses(
			g.hud.zone_label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, g.hud.zone_label.size)),
		"hud_state": hud_state}


func _fountain_text(label: Label) -> Dictionary:
	var cells := Rect2()
	var missing: Array[int] = []
	var count := 0
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty(): continue
		var cell: Rect2 = label.get_character_bounds(index)
		if not cell.has_area():
			missing.append(index)
			continue
		cells = cell if count == 0 else cells.merge(cell)
		count += 1
	var transform: Transform2D = label.get_global_transform_with_canvas()
	var outer: Rect2 = Rect2(Vector2.ZERO, label.size).merge(cells.grow(float(label.get_theme_constant("outline_size"))))
	var complete: bool = count > 0 and missing.is_empty() and not label.clip_text and label.visible_ratio >= 1.0 \
		and label.max_lines_visible == -1 and label.get_visible_line_count() == label.get_line_count() \
		and Rect2(Vector2.ZERO, label.size).grow(0.5).encloses(cells)
	return {"text": label.text, "complete": complete, "count": count, "missing": missing,
		"outer": _fountain_rect(transform * outer), "cells": _fountain_rect(transform * cells), "control": _fountain_rect(transform * Rect2(Vector2.ZERO, label.size)),
		"local_size": _vec(label.size), "font_size": label.get_theme_font_size("font_size"),
		"lines": label.get_line_count(), "visible_lines": label.get_visible_line_count(), "alpha": _fountain_alpha(label)}


func _fountain_alpha(item: CanvasItem) -> float:
	var alpha: float = item.self_modulate.a
	var node: Node = item
	while node != null:
		if node is CanvasItem: alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


func _fountain_rect(rect: Rect2) -> Dictionary:
	return {"position": _vec(rect.position), "size": _vec(rect.size)}


func _fountain_economy() -> Dictionary:
	return {"gold": p.gold, "level": p.level, "xp": p.xp, "skill_points": p.skill_points,
		"tree_points": p.tree_points.duplicate(true), "equipment": p.equipment.duplicate(true),
		"backpack": p.backpack.duplicate(true), "materials": p.materials.duplicate(true),
		"consumables": p.consumables.duplicate(true), "rotation": p.potion_rotation.duplicate(),
		"active_potion": p.active_potion, "mastery": p.mastery.duplicate(true),
		"blueprints": p.blueprints.duplicate(true), "flags": g.flags.duplicate(true),
		"mail": g.mailbox.duplicate(true), "settings": g.settings.duplicate(true), "binds": g.binds.duplicate(true)}


## Optional AFTER observer. It reads completed draw geometry and never writes
## a Control, camera, physics body or production presentation state.
func _fountain_start_draw(prompt: Label) -> void:
	fountain_draw_prompt = prompt
	var metadata: Variant = prompt.get_meta("landmark_prompt_anchor") if prompt.has_meta("landmark_prompt_anchor") else null
	fountain_draw_has_anchor = typeof(metadata) == TYPE_VECTOR2
	if fountain_draw_has_anchor: fountain_draw_anchor = metadata
	fountain_draw_leg = "00_arrival"
	_fountain_draw_begin_leg("00_arrival")
	RenderingServer.frame_post_draw.connect(_fountain_observe_draw)
	r.tree_exiting.connect(_fountain_stop_draw, CONNECT_ONE_SHOT)


func _fountain_stop_draw() -> void:
	if RenderingServer.frame_post_draw.is_connected(_fountain_observe_draw):
		RenderingServer.frame_post_draw.disconnect(_fountain_observe_draw)
	if is_instance_valid(r) and r.tree_exiting.is_connected(_fountain_stop_draw):
		r.tree_exiting.disconnect(_fountain_stop_draw)
	fountain_draw_prompt = null


func _fountain_draw_begin_leg(id: String) -> void:
	fountain_draw_leg = id
	fountain_draw_previous_world = p.global_position
	var proof: Dictionary = _fountain_anchor_proof(fountain_draw_prompt)
	fountain_draw_previous_screen = Vector2.ZERO
	if bool(proof.get("valid", false)):
		fountain_draw_previous_screen = Vector2(proof.authored_origin[0], proof.authored_origin[1])


func _fountain_anchor_proof(prompt: Label) -> Dictionary:
	if not is_instance_valid(prompt) or not prompt.is_inside_tree() or not is_instance_valid(g):
		return {"valid": false, "passed": false, "reason": "live prompt/Game required"}
	var metadata: Variant = prompt.get_meta("landmark_prompt_anchor") if prompt.has_meta("landmark_prompt_anchor") else null
	if typeof(metadata) != TYPE_VECTOR2 or not prompt.get_parent() is CanvasItem:
		return {"valid": false, "passed": false, "reason": "authored Vector2 metadata and CanvasItem parent required"}
	var anchor: Vector2 = metadata
	var immutable_anchor: bool = fountain_draw_has_anchor and anchor == fountain_draw_anchor
	var parent_canvas: Transform2D = (prompt.get_parent() as CanvasItem).get_global_transform_with_canvas()
	var actual_delta: Vector2 = parent_canvas.basis_xform(prompt.position - anchor)
	var actual_origin: Vector2 = prompt.get_global_transform_with_canvas().origin
	var shape: Dictionary = _fountain_text(prompt)
	var actual: Rect2 = Rect2(Vector2(shape.outer.position[0], shape.outer.position[1]),
		Vector2(shape.outer.size[0], shape.outer.size[1]))
	var authored: Rect2 = Rect2(actual.position - actual_delta, actual.size)
	var tracker: Rect2 = g.hud.quest_panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, g.hud.quest_panel.size)
	var would_overlap: bool = authored.intersects(tracker)
	var expected_y: float = maxf(0.0, tracker.end.y + Balance.PROP_PROMPT_HUD_GAP - authored.position.y) if would_overlap else 0.0
	var x_unchanged: bool = absf(actual_delta.x) <= 0.01
	var exact_anchor_when_clear: bool = would_overlap or prompt.position == anchor
	var minimal_delta: bool = absf(actual_delta.y - expected_y) <= 0.05 and actual_delta.y >= -0.01
	var selected: bool = g.get("selected_landmark_prompt") == prompt
	var visible: bool = prompt.is_visible_in_tree() and _fountain_alpha(prompt) >= 0.99
	var tracker_visible: bool = g.hud.quest_panel.is_visible_in_tree() and _fountain_alpha(g.hud.quest_panel) >= 0.99
	var clear: bool = not actual.intersects(tracker)
	return {"valid": true, "passed": selected and visible and tracker_visible and shape.complete
		and g.chapter_id == "capital" and not g.input_overlay_up() and clear and x_unchanged
		and immutable_anchor and exact_anchor_when_clear and minimal_delta,
		"immutable_anchor": immutable_anchor, "initial_authored_anchor": _vec(fountain_draw_anchor),
		"selected": selected, "visible": visible, "tracker_visible": tracker_visible, "complete": shape.complete,
		"actual": _fountain_rect(actual), "authored": _fountain_rect(authored), "tracker": _fountain_rect(tracker),
		"actual_local_position": _vec(prompt.position), "authored_local_anchor": _vec(anchor),
		"authored_origin": _vec(actual_origin - actual_delta), "actual_origin": _vec(actual_origin),
		"screen_delta": _vec(actual_delta), "expected_down_px": expected_y, "would_overlap": would_overlap,
		"adjusted": actual_delta.y > 0.01, "actual_clear": clear, "x_unchanged": x_unchanged,
		"exact_anchor_when_clear": exact_anchor_when_clear, "minimal_delta": minimal_delta}


func _fountain_observe_draw() -> void:
	var proof: Dictionary = _fountain_anchor_proof(fountain_draw_prompt)
	proof["leg"] = fountain_draw_leg
	proof["process_frame"] = Engine.get_process_frames()
	proof["physics_frame"] = Engine.get_physics_frames()
	proof["drawn_frame"] = Engine.get_frames_drawn()
	if not is_instance_valid(p):
		proof["passed"] = false
		proof["reason"] = "player was freed while observer remained connected"
		fountain_draw_samples.append(proof)
		return
	var world: Vector2 = p.global_position
	var body_delta: float = world.distance_to(fountain_draw_previous_world)
	var screen_delta := 0.0
	if bool(proof.get("valid", false)):
		var origin := Vector2(proof.authored_origin[0], proof.authored_origin[1])
		screen_delta = origin.distance_to(fountain_draw_previous_screen)
		fountain_draw_previous_screen = origin
	var released: bool = not fountain_move_active and not Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_W)
	proof["body_position"] = _vec(world)
	proof["body_velocity"] = _vec(p.velocity)
	proof["body_delta"] = body_delta
	proof["authored_screen_delta"] = screen_delta
	proof["movement"] = body_delta > 0.001
	proof["postrelease_easing"] = released and body_delta <= 0.001 and screen_delta > 0.001
	proof["released"] = released
	fountain_draw_previous_world = world
	fountain_draw_samples.append(proof)


func _fountain_draw_verdict() -> Dictionary:
	var legs: Dictionary = {}
	for id in ["01_south_near", "02_south_header", "03_return"]:
		legs[id] = {"movement": 0, "postrelease_easing": 0}
	var invalid := 0
	var would_overlap := 0
	var adjusted := 0
	var clear_authored := 0
	for sample in fountain_draw_samples:
		if not bool(sample.get("passed", false)): invalid += 1
		if bool(sample.get("would_overlap", false)): would_overlap += 1
		if bool(sample.get("adjusted", false)): adjusted += 1
		if sample.get("valid", false) and not sample.get("would_overlap", false): clear_authored += 1
		var leg: String = String(sample.leg)
		if legs.has(leg):
			if bool(sample.get("movement", false)): legs[leg].movement += 1
			if bool(sample.get("postrelease_easing", false)): legs[leg].postrelease_easing += 1
	var coverage := true
	for leg in legs.values():
		coverage = coverage and int(leg.movement) > 0 and int(leg.postrelease_easing) > 0
	var disconnected: bool = not RenderingServer.frame_post_draw.is_connected(_fountain_observe_draw)
	var exit_disconnected: bool = not is_instance_valid(r) or not r.tree_exiting.is_connected(_fountain_stop_draw)
	return {"passed": invalid == 0 and would_overlap > 0 and adjusted > 0 and clear_authored > 0
		and coverage and disconnected and exit_disconnected and fountain_draw_samples.size() > 0,
		"samples": fountain_draw_samples.size(), "invalid_samples": invalid, "legs": legs,
		"would_overlap_samples": would_overlap, "adjusted_samples": adjusted,
		"authored_clear_samples": clear_authored, "observer_disconnected": disconnected,
		"exit_observer_disconnected": exit_disconnected,
		"scope": "Each leg requires a positive body-position transition observed after drawing, then separate released stationary-body camera easing. A short leg may complete within one draw interval with zero final velocity; movement counts are rendered transitions, not continuously held frames. Every sample is strict; no fixed sample count or body/camera override."}
