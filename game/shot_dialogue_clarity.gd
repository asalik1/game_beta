extends ShotRig
## Candidate-only: actual Fenna E delivery, then isolated guarded GUI probes.
## --baseline permits known layout/input findings; setup and cleanup stay strict.
const NetMgr := preload("res://scripts/net/net_manager.gd")
const GAME_FIELDS := ["settings", "touch_mode", "dev_god", "terrain_event_t", "hazard_tick", "npc_emote_t",
	"convo_log", "convo_log_order", "flags", "quest_key", "quest_kills", "talk_cd", "beat_broadcasting"]
const HUD_FIELDS := ["_dialogue_history", "_auto_on", "_auto_t", "_auto_dwell"]
const PLAYER_FIELDS := ["hp", "mp", "xp", "level", "skill_points", "gold", "resonance", "faction_standing"]
var checks: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var views: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var failures := 0
var saved: Dictionary = {}
var disk: Dictionary = {}
var held: Dictionary = {}
var net: Node
var session: Node
var owned_peer: ENetMultiplayerPeer
var previous_peer: MultiplayerPeer
var fenna: Dictionary = {}
var captured_fenna: Dictionary = {}
var probe_calls: Array[int] = []
var followup_line := false
var pointer_down := false
var pointer_at := Vector2.ZERO
var baseline := false
var touch_run := false
var caption: Label
var setup_complete := false
var current_scope := "setup"


func _ready() -> void:
	baseline = flag("baseline")
	touch_run = flag("touch")
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _check("isolated_qa_directory", user_path.to_lower().contains("/build/qa/"), {"path": user_path}):
		finish(1)
		return
	_snapshot_disk()
	get_window().size = Vector2i(1280, 720)
	await boot("warrior", "ch3", false)
	var error := await _run()
	_cleanup()
	if error != "":
		_check("fixture_complete", false, {"reason": error})
	_write_report()
	print("DIALOGUE CLARITY: %d checks, %d strict failures, %d findings, %d views; %s" % [checks.size(), failures, findings.size(), views.size(), "BASELINE" if baseline else "regression"])
	finish(1 if failures > 0 else 0)


func _run() -> String:
	if game == null or not game.has_local_player():
		return "Missing local player"
	net = get_node_or_null("/root/NetworkManager")
	session = get_node_or_null("/root/NetworkManager/Session")
	if net == null or session == null or net.is_online():
		return "Requires an offline isolated NetworkManager/Session"
	game.play_started = true
	game.state = Game.ST_PLAYING
	game.menus.close()
	game.request_pause(false)
	if not await _settle_world():
		return "Boot reveal did not settle"
	if not _check("ordinary_isolated_boot", game.no_saves and not game.dev_god and AudioServer.is_bus_mute(0)
		and String(game.zones[game.cur_room].get("type", "")) == "safe" and not game.hud._auto_on):
		return "Unexpected boot state"
	if not _check("native_viewport", get_viewport().get_visible_rect().size == Vector2(1280, 720)):
		return "Unexpected viewport"
	saved.game = _stash(game, GAME_FIELDS)
	saved.hud = _stash(game.hud, HUD_FIELDS)
	saved.player = _stash(game.local_player, PLAYER_FIELDS)
	saved.net = _stash_script(net)
	saved.session = _stash_script(session)
	saved.hero_position = game.local_player.global_position
	saved.paused = get_tree().paused
	previous_peer = net.multiplayer.multiplayer_peer
	game.settings["touch_controls"] = touch_run
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.terrain_event_t = 1.0e9
	game.hazard_tick = 1.0e9
	game.npc_emote_t = 1.0e9
	if not _check("input_mode", game.touch_mode == touch_run):
		return "Touch-mode setup failed"
	if touch_run and not _check("production_touch_mouse_emulation", bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))):
		return "Production touch-to-mouse GUI emulation is disabled"
	for entry in game.interactables:
		var node: Node2D = entry.get("node") as Node2D
		if is_instance_valid(node) and game.room_at_pos(node.global_position) == game.cur_room \
			and String(entry.get("sprite_name", "")) == "old_fenna" and String(node.get_meta("quest_convo", "")) == "ch3_refugee":
			fenna = entry
			break
	if not _check("actual_fenna", not fenna.is_empty()):
		return "Actual spawned Fenna not found"
	var overlay := CanvasLayer.new()
	overlay.layer = 180
	add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(50, 678)
	caption.size = Vector2(1180, 40)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 3)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(caption)
	setup_complete = true
	for online in [false, true]:
		current_scope = "online" if online else "solo"
		step(current_scope + " dialogue")
		if online:
			var error := _start_online()
			if error != "":
				return error
		var before := _story_receipt()
		if not await _actual_fenna():
			return current_scope + " actual Fenna delivery failed"
		# Capture used the untouched real callback. Intercept before ANY negative
		# click/key so a baseline defect cannot execute a story outcome.
		game.hud.choice_cb = _probe_choice
		probe_calls.clear()
		await _tap(game.hud.dlg_log_btn.get_global_rect().get_center())
		var log_open: bool = game.hud.log_panel.visible and game.hud.choices_active and probe_calls.is_empty()
		_probe(current_scope + "/actual_choice_log_access", log_open, {"probe_callbacks": probe_calls.duplicate(), "input": _pointer_name()})
		if not log_open:
			await _capture(current_scope + "_log_access_result", "Actual LOG target with intercepted callback; any wrong selection is QA-only")
		_cancel()
		if not await _plain_reader_controls():
			return current_scope + " plain reader positive controls failed"
		for mechanism in ["keyboard", "pointer"]:
			if not await _hidden_choice_probe(String(mechanism)):
				return current_scope + " modal probe setup failed"
		if not await _positive_choices():
			return current_scope + " choice input positive controls failed"
		if not await _long_choice_case():
			return current_scope + " long layout fixture failed"
		_check(current_scope + "/story_outcomes_unchanged", before == _story_receipt())
		_cancel()
		if online:
			_stop_online()
	return ""


func _actual_fenna() -> bool:
	_cancel()
	var node: Node2D = fenna["node"]
	# Explicit setup pose, not a traversal claim. E is ordinary input.
	game.local_player.global_position = node.global_position + Vector2(0, 60)
	var deadline := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		if game.talk_cd <= 0.0 and (fenna["prompt"] as Label).is_visible_in_tree():
			break
	if not _check(current_scope + "/fenna_prompt_before_E", (fenna["prompt"] as Label).is_visible_in_tree()
		and game.local_player.global_position.distance_to(node.global_position) < float(fenna.get("reach", Balance.INTERACT_RANGE))):
		return false
	_key(int(game.binds.get("interact", KEY_E)), true)
	deadline = Time.get_ticks_msec() + 2500
	while not game.hud.choices_active and Time.get_ticks_msec() < deadline:
		await frames(1)
	_release()
	if not _check(current_scope + "/real_E_choices", game.hud.choices_active and game.hud.speaker_label.text == "Old Fenna" and game.hud.choice_cb.is_valid()):
		return false
	if not await _settle_dialogue():
		return false
	var options: Array[String] = []
	for i in game.hud.choice_count:
		var value: String = game.hud.choice_option_labels[i].text
		options.append(value.substr(String("%d.  " % (i + 1)).length()))
	captured_fenna = {"speaker": game.hud.speaker_label.text, "text": game.hud.text_label.text, "options": options}
	if not _check(current_scope + "/two_real_options", options.size() == 2):
		return false
	_check(current_scope + "/pause_semantics", get_tree().paused == (not game.net_online()), {"online": game.net_online(), "tree_paused": get_tree().paused})
	_layout_probe(current_scope + "/actual_fenna")
	await _capture(current_scope + "_actual_fenna", "Actual E opens Fenna; callback untouched in this capture; setup positioning")
	return true


func _plain_reader_controls() -> bool:
	_cancel()
	game.hud.dialogue([["Old Fenna", "QA reader control fixture. No story outcome."]])
	if not await _settle_dialogue():
		return false
	await _capture(current_scope + "_plain_reader", "Synthetic plain line; actual reader input positive controls")
	await _tap(game.hud.dlg_auto_btn.get_global_rect().get_center())
	if not _check(current_scope + "/auto_click_on", game.hud._auto_on):
		return false
	await _tap(game.hud.dlg_auto_btn.get_global_rect().get_center())
	if not _check(current_scope + "/auto_click_off", not game.hud._auto_on):
		return false
	await _tap(game.hud.dlg_log_btn.get_global_rect().get_center())
	if not _check(current_scope + "/plain_LOG_positive_control", game.hud.log_panel.visible):
		return false
	var close := _log_close()
	if not _check(current_scope + "/actual_log_close_control", close != null):
		return false
	await _tap(close.get_global_rect().get_center())
	if not _check(current_scope + "/LOG_close_input", not game.hud.log_panel.visible and game.hud.dialogue_active):
		return false
	await _tap(game.hud.dlg_skip_btn.get_global_rect().get_center())
	return _check(current_scope + "/SKIP_plain_positive_control", not game.hud.dialogue_active and not game.hud.choices_active)


func _open_modal_probe() -> bool:
	_cancel()
	probe_calls.clear()
	_replay_fenna()
	await frames(3)
	await _tap(game.hud.dlg_log_btn.get_global_rect().get_center())
	var normal_access: bool = game.hud.log_panel.visible and game.hud.choices_active and probe_calls.is_empty()
	if not normal_access:
		# Baseline overlap can make LOG unreachable. Open actual LOG on a plain
		# line with input, then use the public choice API underneath it. No z,
		# control position or visibility property is forced by the fixture.
		_cancel()
		game.hud.dialogue([["Old Fenna", "QA backlog positive control."]])
		if not await _settle_dialogue():
			return false
		await _tap(game.hud.dlg_log_btn.get_global_rect().get_center())
		if not _check(current_scope + "/modal_actual_LOG_setup", game.hud.log_panel.visible):
			return false
		probe_calls.clear()
		_replay_fenna()
		await frames(3)
	if not _check(current_scope + "/modal_probe_ready", game.hud.log_panel.visible and game.hud.choices_active and probe_calls.is_empty()):
		return false
	inputs.append({"scope": current_scope, "operation": "open_modal", "normal_choice_LOG_access": normal_access,
		"setup_fallback": "none" if normal_access else "actual plain-line LOG input, then public dialogue_choice underneath"})
	return true


func _hidden_choice_probe(mechanism: String) -> bool:
	if not await _open_modal_probe():
		return false
	var h := game.hud
	var above: bool = h.log_panel.z_index > h.choice_panel.z_index or \
		(h.log_panel.z_index == h.choice_panel.z_index and h.log_panel.get_index() > h.choice_panel.get_index())
	if not _check(current_scope + "/sibling_layer_contract", h.log_panel.get_parent() == h.choice_panel.get_parent()):
		return false
	_probe(current_scope + "/backlog_layers_above_choices/" + mechanism, above,
		{"log_index": h.log_panel.get_index(), "choice_index": h.choice_panel.get_index(), "log_z": h.log_panel.z_index, "choice_z": h.choice_panel.z_index})
	if mechanism == "keyboard":
		await _capture(current_scope + "_actual_backlog", "Input-opened backlog; captured Fenna options replayed with QA-only callback")
	var before := _story_receipt()
	var hero_at: Vector2 = game.local_player.global_position
	if game.net_online():
		_key(KEY_W, true)
		await frames(8)
		_release()
		_check(current_scope + "/online_overlay_blocks_movement/" + mechanism,
			game.local_player.global_position.distance_to(hero_at) < 0.1 and not get_tree().paused and game.local_player.is_physics_processing())
	if mechanism == "keyboard":
		await _press_once(KEY_1)
	else:
		var opt: Label = h.choice_option_labels[0]
		var point := opt.get_global_rect().get_center()
		var log_frame: ColorRect = h.log_panel.get_child(1) as ColorRect
		if not _check(current_scope + "/pointer_negative_geometry", log_frame != null and log_frame.get_global_rect().has_point(point)):
			return false
		await _tap(point)
	var blocked: bool = probe_calls.is_empty() and h.choices_active and h.log_panel.visible
	_probe(current_scope + "/no_hidden_choice/" + mechanism, blocked,
		{"callbacks": probe_calls.duplicate(), "choices_active": h.choices_active, "log_visible": h.log_panel.visible, "input": "keyboard 1" if mechanism == "keyboard" else _pointer_name()})
	_check(current_scope + "/negative_probe_no_story_outcome/" + mechanism, before == _story_receipt())
	if not blocked:
		await _capture(current_scope + "_hidden_" + mechanism + "_result", "Negative-control result; intercepted callback prevents story outcome")
	_cancel()
	return true


func _positive_choices() -> bool:
	for mechanism in ["keyboard", "pointer"]:
		_cancel()
		probe_calls.clear()
		_replay_fenna()
		await frames(3)
		if mechanism == "keyboard":
			await _press_once(KEY_1)
		else:
			await _tap(game.hud.choice_option_labels[0].get_global_rect().get_center())
		if not _check(current_scope + "/visible_choice_positive/" + String(mechanism), probe_calls == [0] and not game.hud.choices_active):
			return false
	_cancel()
	return true


func _long_choice_case() -> bool:
	probe_calls.clear()
	var body := "This is a synthetic layout fixture, not a new line of Crownless story. It exercises a grown dialogue box while four wrapped options retain readable text and stable reader controls. ".repeat(5)
	var options: Array[String] = []
	for i in 4:
		options.append("QA option %d: preserve the measured row height, the complete readable sentence and the full input target while the dialogue reader remains accessible above these choices. This option has no story callback." % (i + 1))
	game.hud.dialogue_choice("Old Fenna", body, options, _probe_choice)
	await frames(3)
	var measured: float = game.hud.text_label.get_minimum_size().y
	if not _check(current_scope + "/long_fixture_grows_box", measured > game.hud.DIALOG_TEXT_MIN_H):
		return false
	for i in 4:
		if not _check(current_scope + "/wrapped_option_%d" % i, game.hud.choice_option_labels[i].get_line_count() >= 2):
			return false
	_layout_probe(current_scope + "/long_four_options")
	await _capture(current_scope + "_long_four_options", "Synthetic grown text and four wrapped choices; production layout, QA-only callback")
	followup_line = true
	await _press_once(KEY_1)
	followup_line = false
	if not _check(current_scope + "/long_choice_to_plain_input", probe_calls == [0] and game.hud.dialogue_active and not game.hud.choices_active):
		return false
	if not await _settle_dialogue():
		return false
	_layout_probe(current_scope + "/plain_after_long")
	await _capture(current_scope + "_plain_after_long", "Actual key selects QA-only long option; callback opens a normal line")
	_cancel()
	return true


func _layout_probe(id: String) -> void:
	var h := game.hud
	var viewport := get_viewport().get_visible_rect()
	var panel: Rect2 = h.choice_frame.get_global_rect() if h.choices_active else h.dialogue_frame.get_global_rect()
	for button in [h.dlg_log_btn, h.dlg_skip_btn, h.dlg_auto_btn]:
		var rect: Rect2 = button.get_global_rect()
		_probe(id + "/reader_clear/" + String(button.text), not rect.intersects(panel) and viewport.encloses(rect), {"button": _rect(rect), "panel": _rect(panel)})
	_probe(id + "/dialogue_in_viewport", viewport.encloses(h.dialogue_frame.get_global_rect()))
	_text_layout_probe(id)
	if h.choices_active:
		_probe(id + "/choices_in_viewport", viewport.encloses(h.choice_frame.get_global_rect()))


## Independent shaped-character bounds include the real inter-line placement.
## These are font layout cells, not a screenshot-derived pixel-ink mask. Native
## captures remain the final check for ink/outline appearance.
func _glyph_bounds(label: Label) -> Dictionary:
	var bounds := Rect2()
	var count := 0
	var missing: Array[int] = []
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty():
			continue
		var cell := label.get_character_bounds(index)
		if not cell.has_area():
			missing.append(index)
			continue
		bounds = cell if count == 0 else bounds.merge(cell)
		count += 1
	return {"bounds": label.get_global_transform() * bounds, "count": count, "missing": missing}


func _text_layout_probe(id: String) -> void:
	var h := game.hud
	var text: Label = h.text_label
	var body := _glyph_bounds(text)
	var body_rect: Rect2 = body["bounds"]
	var hint: Rect2 = h.dialogue_hint.get_global_rect()
	var inner: Rect2 = h.dialogue_inner.get_global_rect()
	var minimum_h := text.get_minimum_size().y
	var detail := {"text_target": _rect(text.get_global_rect()), "shaped_character_bounds": _rect(body_rect),
		"minimum_height": minimum_h, "line_count": text.get_line_count(), "line_height": text.get_line_height(),
		"line_spacing": text.get_theme_constant("line_spacing"), "paragraph_spacing": text.get_theme_constant("paragraph_spacing"),
		"missing_character_indices": body["missing"], "hint": _rect(hint), "inner": _rect(inner),
		"hint_clearance": hint.position.y - body_rect.end.y}
	_probe(id + "/body_complete_unclipped", body["count"] > 0 and body["missing"].is_empty()
		and not text.clip_text and text.max_lines_visible == -1 and text.visible_ratio >= 1.0, detail)
	_probe(id + "/body_minimum_height", text.size.y + 0.5 >= minimum_h, detail)
	_probe(id + "/body_inside_frame", inner.grow(0.5).encloses(body_rect), detail)
	_probe(id + "/body_inside_label", text.get_global_rect().grow(0.5).encloses(body_rect), detail)
	_probe(id + "/hint_below_complete_text", body_rect.end.y + 6.0 <= hint.position.y + 0.5, detail)
	_probe(id + "/hint_inside_frame", inner.grow(0.5).encloses(hint), detail)
	_probe(id + "/hint_in_viewport", get_viewport().get_visible_rect().encloses(hint), detail)
	# Short content still fits above the original y618 hint with 6px clearance.
	# Assert both the ordinary Fenna layout and the reset after the long choice.
	if minimum_h <= 120.0:
		_probe(id + "/short_layout_preserved", is_equal_approx(text.position.y, 492.0)
			and is_equal_approx(text.size.x, 820.0) and is_equal_approx(h.dialogue_frame.position.y, 448.0)
			and is_equal_approx(h.dialogue_frame.size.y, 200.0) and is_equal_approx(h.dialogue_hint.position.y, 618.0), detail)
	if not h.choices_active:
		return
	var previous := Rect2()
	for i in h.choice_count:
		var option: Label = h.choice_option_labels[i]
		var glyphs := _glyph_bounds(option)
		var glyph_rect: Rect2 = glyphs["bounds"]
		var target := option.get_global_rect()
		var hover: Rect2 = h.choice_hover_rects[i].get_global_rect()
		var option_detail := {"target": _rect(target), "shaped_character_bounds": _rect(glyph_rect), "hover": _rect(hover),
			"minimum_height": option.get_minimum_size().y, "line_count": option.get_line_count(),
			"line_spacing": option.get_theme_constant("line_spacing"), "missing_character_indices": glyphs["missing"]}
		_probe(id + "/choice_complete_target_%d" % i, glyphs["count"] > 0 and glyphs["missing"].is_empty()
			and target.grow(0.5).encloses(glyph_rect) and target.size.y + 0.5 >= option.get_minimum_size().y
			and option.mouse_filter == Control.MOUSE_FILTER_STOP and not option.clip_text, option_detail)
		_probe(id + "/choice_ink_inside_frame_%d" % i, h.choice_inner.get_global_rect().grow(0.5).encloses(glyph_rect), option_detail)
		_probe(id + "/choice_hover_covers_target_%d" % i, hover.grow(0.5).encloses(target), option_detail)
		if i > 0:
			option_detail["previous_target"] = _rect(previous)
			_probe(id + "/choice_six_pixel_gap_%d" % i, target.position.y + 0.5 >= previous.end.y + 6.0, option_detail)
		previous = target


func _replay_fenna() -> void:
	game.hud.dialogue_choice(String(captured_fenna.speaker), String(captured_fenna.text), captured_fenna.options, _probe_choice)


func _probe_choice(index: int) -> void:
	probe_calls.append(index) # Never calls the original story callback.
	if followup_line:
		game.hud.dialogue([["Old Fenna", "QA plain line after four choices."]])


func _cancel() -> void:
	_release()
	game.hud.cancel_conversation()
	game.request_pause(false)


func _log_close() -> Button:
	for child in game.hud.log_panel.get_children():
		if child is Button and (child as Button).text == "CLOSE":
			return child as Button
	return null


func _start_online() -> String:
	if net.is_online():
		return "Refusing to replace an existing online session"
	owned_peer = ENetMultiplayerPeer.new()
	owned_peer.set_bind_ip("127.0.0.1")
	# Port 0 asks the OS for an available UDP port; explicit --port remains useful.
	var requested_port: int = int(arg("port", "0"))
	var err := owned_peer.create_server(requested_port, 1)
	if err != OK:
		owned_peer = null
		return "Loopback create_server(%d) failed: %s" % [requested_port, error_string(err)]
	var bound_host: ENetConnection = owned_peer.get_host()
	var port: int = bound_host.get_local_port() if bound_host != null else 0
	var port_receipt := {"bind_ip": "127.0.0.1", "requested_port": requested_port,
		"bound_port": port, "os_selected": requested_port == 0}
	print("DIALOGUE LOOPBACK: ", JSON.stringify(port_receipt))
	if not _check("loopback_bound_port", port > 0 and port <= 65535
		and (requested_port == 0 or port == requested_port), port_receipt):
		owned_peer.close()
		owned_peer = null
		return "Loopback bound-port receipt failed"
	net.multiplayer.multiplayer_peer = owned_peer
	net.mode = NetMgr.Mode.ENET_DIRECT
	net.session_code = "127.0.0.1:%d" % port
	net.lobby_open = false
	net._session_active = true
	game.request_pause(false)
	game.request_pause(true)
	if not _check("loopback_no_pause", game.net_online() and game.net_host() and net.multiplayer.get_peers().is_empty()
		and not get_tree().paused and game.state == Game.ST_PLAYING):
		return "Loopback/no-pause contract failed"
	return ""


func _stop_online() -> void:
	if owned_peer == null:
		return
	# No guests were registered. Avoid broad net.leave()/session-ended effects.
	net.multiplayer.multiplayer_peer = previous_peer
	owned_peer.close()
	owned_peer = null
	_restore(session, saved.session)
	_restore(net, saved.net)
	_check("loopback_closed_restored", not net.is_online() and net.multiplayer.multiplayer_peer == previous_peer)


func _settle_world() -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		var pending: bool = game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active
		for child in game.hud.get_children():
			pending = pending or child is Cutscene
		pending = pending or game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01
		pending = pending or is_instance_valid(game.hud._ann_active)
		if not pending:
			return true
	return _check("world_settled", false)


func _settle_dialogue() -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		if game.hud.text_label.visible_ratio >= 1.0 and game.hud.dialogue_box.modulate.a >= 0.999 and game.hud.dialogue_box.position.length() < 0.1:
			return true
	return _check(current_scope + "/dialogue_settled", false)


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


func _press_once(key: int) -> void:
	inputs.append({"scope": current_scope, "input": "keyboard", "key": key})
	_key(key, true)
	await frames(2)
	_key(key, false)
	await frames(3)


func _release() -> void:
	if pointer_down:
		if touch_run:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = pointer_at
			event.pressed = false
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = pointer_at
			event.global_position = pointer_at
			event.pressed = false
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		pointer_down = false
	for key in held.keys():
		_key(int(key), false)
	if game != null and game.has_local_player():
		game.local_player.clear_local_intents()


func _capture(id: String, scope: String) -> void:
	caption.text = "DIALOGUE QA - %s - %s\n%s" % [current_scope, _pointer_name(), scope]
	await frames(3)
	await RenderingServer.frame_post_draw
	var h := game.hud
	var controls: Dictionary = {}
	var options: Array[String] = []
	for i in h.choice_count:
		options.append(h.choice_option_labels[i].text)
	for button in [h.dlg_log_btn, h.dlg_skip_btn, h.dlg_auto_btn]:
		controls[button.text] = _rect(button.get_global_rect())
	views.append({"id": id, "capture": shot(id, scope), "scope": scope, "online": game.net_online(), "tree_paused": get_tree().paused,
		"speaker": h.speaker_label.text, "text": h.text_label.text, "choices_active": h.choices_active, "choice_count": h.choice_count, "visible_option_copy": options,
		"log_visible": h.log_panel.visible, "reader_rects": controls, "dialogue_rect": _rect(h.dialogue_frame.get_global_rect()),
		"choice_rect": _rect(h.choice_frame.get_global_rect()), "probe_callbacks": probe_calls.duplicate()})


func _pointer_name() -> String:
	return "ScreenTouch" if touch_run else "mouse"


func _story_receipt() -> Dictionary:
	var p: Player = game.local_player
	return {"flags": game.flags.duplicate(true), "quest": game.quest_key, "kills": game.quest_kills.duplicate(true),
		"xp": p.xp, "level": p.level, "points": p.skill_points, "gold": p.gold, "resonance": p.resonance, "standing": p.faction_standing.duplicate(true)}


func _cleanup() -> void:
	_release()
	if not saved.is_empty() and game != null:
		_cancel()
		_stop_online()
		_restore(session, saved.session)
		_restore(net, saved.net)
		net.multiplayer.multiplayer_peer = previous_peer
		_restore(game.local_player, saved.player)
		_restore(game, saved.game)
		_restore(game.hud, saved.hud)
		game.local_player.global_position = saved.hero_position
		game._apply_touch_mode()
		get_tree().paused = bool(saved.paused)
		_check("memory_restored", game.flags == saved.game.flags and game.quest_key == saved.game.quest_key
			and game.convo_log == saved.game.convo_log and game.convo_log_order == saved.game.convo_log_order
			and game.hud._dialogue_history == saved.hud._dialogue_history and game.settings == saved.game.settings
			and not game.hud.choices_active and not game.hud.dialogue_active and not game.net_online())
	_restore_disk()


func _probe(label: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"label": label, "pass": passed, "expected_defect_probe": true, "detail": detail})
	if not passed:
		findings.append({"label": label, "detail": detail})
		if not baseline:
			failures += 1


func _check(label: String, passed: bool, detail: Dictionary = {}) -> bool:
	checks.append({"label": label, "pass": passed, "expected_defect_probe": false, "detail": detail})
	if not passed:
		failures += 1
		print("DIALOGUE CHECK FAILED: ", label, " ", detail)
	return passed


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string(JSON.stringify({"checks": checks, "findings": findings, "failures": failures, "views": views, "inputs": inputs,
		"baseline": baseline, "touch_mode": touch_run, "setup_complete": setup_complete, "captured_fenna": captured_fenna,
		"fixture": "Actual Fenna E; guarded/replayed callbacks and synthetic long text; loopback without guests; no story/traversal/replication claim",
		"script_sha256": FileAccess.get_sha256(get_script().resource_path), "hud_source_sha256": FileAccess.get_sha256("res://scripts/hud.gd"),
		"renderer": RenderingServer.get_current_rendering_method()}, "\t"))
	file.close()


func _on_watchdog() -> void:
	_cleanup()
	super._on_watchdog()


func _tap(at: Vector2) -> void:
	inputs.append({"scope": current_scope, "input": _pointer_name(), "position": [at.x, at.y]})
	if not touch_run:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
	for down in [true, false]:
		pointer_down = down
		pointer_at = at
		if touch_run:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = at
			event.pressed = down
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = at
			event.global_position = at
			event.pressed = down
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)
	await frames(4)


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _stash(node: Object, keys: Array) -> Dictionary:
	var saved := {}
	for key in keys:
		var value: Variant = node.get(key)
		saved[key] = value
		if value is Array or value is Dictionary:
			node.set(key, value.duplicate(true))
	return saved


func _stash_script(node: Object) -> Dictionary:
	var keys: Array = []
	for property in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			keys.append(property.name)
	return _stash(node, keys)


func _restore(node: Object, saved: Dictionary) -> void:
	for key in saved:
		node.set(key, saved[key])


func _snapshot_disk() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for filename in dir.get_files():
		if filename.contains(".json"):
			disk[filename] = FileAccess.get_file_as_bytes("user://" + filename)


func _restore_disk() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var changed: Array[String] = []
	for filename in dir.get_files():
		if filename.contains(".json") and not disk.has(filename):
			changed.append(filename)
			dir.remove(filename)
	for filename in disk:
		var path := "user://" + String(filename)
		if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == disk[filename]:
			continue
		changed.append(String(filename))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(disk[filename])
			file.close()
	_check("no_persistent_writes", changed.is_empty(), {"restored_files": changed})
	for filename in disk:
		_check("disk_bytes/" + String(filename), FileAccess.get_file_as_bytes("user://" + String(filename)) == disk[filename])
