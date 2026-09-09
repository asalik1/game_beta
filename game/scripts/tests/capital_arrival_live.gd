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


func run(rig: ShotRig) -> Dictionary:
	r = rig
	g = r.game
	p = g.local_player
	ui = preload("res://scripts/tests/menu_navigation_live.gd").new()
	ui.r = r
	ui.g = g
	ui.m = g.menus
	var error := await _run()
	if held_key != 0:
		_key(held_key, false)
		held_key = 0
	collecting = false
	pending = ""
	await r.frames(2)
	_check("runtime.completed", error == "", error)
	_check("fixture.no_save_or_network", g.no_saves and not g.net_online(), {"no_saves": g.no_saves, "online": g.net_online()})
	_check("input.released", not Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_ESCAPE)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "all held presses released")
	var report := {"baseline": r.flag("baseline"), "checks": rows.size(), "passed": 0,
		"findings": 0, "failures": 0, "rows": rows, "samples": samples, "motion": motion,
		"boot_readiness": boot_readiness, "escape_input": escape_input,
		"qualification": "Single normal main.tscn Game; standard QA mage/ch1 boot and opening choice, no saves, no god mode, no body/camera position or physics override. Real Pause Travel to Crownfall click, real welcome key input, live one-second idle and one-second A escape. No save/load or ENet proof.",
		"mouse_clicks": ui.mouse_clicks, "key_taps": ui.key_taps,
		"settings": g.settings.duplicate(true)}
	if r.flag("arrival-consumers"):
		report["arrival_consumer_qualification"] = "After the ordinary fresh-arrival leg: direct map opening then real destination clicks, real A nudges then direct Recall and _death_respawn landing calls. No recall-scroll ownership/consumption, lethal damage, death tithe or respawn delay is claimed. The existing live physics sampler observes each landing."
	for row in rows:
		if row.passed: report.passed += 1
		elif row.known_defect and r.flag("baseline"): report.findings += 1
		else: report.failures += 1
	return report


func _run() -> String:
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
