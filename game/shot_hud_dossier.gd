extends ShotRig
## Candidate: publish beside the other game/shot_*.gd scenes before running.
## Synthetic UI states in an actual safe room; real mouse/ScreenTouch access.
## --baseline records known layout/access findings without declaring them fixed.
## --online-menu runs only focused solo/host/victory menu copy + real-input evidence.
## --cosmetic-ui inspects the actual Wardrobe/Records UI without buying or equipping.
## --alignment checks shaped stat baselines and quest/vital/target clearance.
## --reward-plaques controls authored boss readouts and real reward UI clocks, without rewards.
const NetMgr := preload("res://scripts/net/net_manager.gd")

const GAME_FIELDS := ["settings", "touch_mode", "dev_god", "player_title", "mailbox", "daily_last_day", "daily_streak",
	"clock_anchor", "achievements", "contracts", "contract_day", "contract_claims_day",
	"bounties", "bounty_day", "bounty_week", "vault_week", "vault_progress",
	"vault_claimed_week", "party_stats", "party_stats_net", "_meta", "_meta_loaded"]
const PLAYER_FIELDS := ["char_name", "gold", "resonance", "skill_points", "atk", "hp", "mp"]
const UTILITIES := ["mail_btn", "quest_btn", "inv_btn", "codex_btn", "daily_btn", "skills_btn", "settings_btn", "party_btn"]
const POPUP_FIELDS := ["cr_label", "res_label"]
var checks: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var views: Array[Dictionary] = []
var failures := 0
var successful_utility_inputs := 0
var touch_run := false
var baseline := false
var complete := false
var kept := {}
var disk := {}
var net: Node
var session: Node
var owned_host := false
var peer_before: MultiplayerPeer
var ally_ids: Array[int] = []
var utility_reference: Dictionary = {}


func _ready() -> void:
	touch_run = flag("touch")
	baseline = flag("baseline")
	shot_dir = shot_dir.path_join("touch" if touch_run else "desktop")
	if flag("online-menu"):
		shot_dir = shot_dir.path_join("online_menu")
	elif flag("cosmetic-ui"):
		shot_dir = shot_dir.path_join("cosmetic_ui")
	elif flag("alignment"):
		shot_dir = shot_dir.path_join("alignment")
	elif flag("reward-plaques"):
		shot_dir = shot_dir.path_join("reward_plaques")
	_snapshot_disk()
	await boot("warrior", "ch3", false)
	var error := await _run()
	await _cleanup()
	if error != "":
		_check("fixture", false, {"error": error})
	complete = error == ""
	_write_report()
	print("HUD DOSSIER: %d checks, %d failures, %d observations; %s; full native frames" % [checks.size(), failures, findings.size(), "BASELINE ONLY" if baseline else "regression"])
	finish(1 if failures > 0 else 0)


func _run() -> String:
	if int(flag("online-menu")) + int(flag("cosmetic-ui")) + int(flag("alignment")) + int(flag("reward-plaques")) > 1:
		return "Choose one focused mode: online-menu, cosmetic-ui, alignment or reward-plaques"
	if game == null or not game.has_local_player():
		return "No local hero after boot"
	net = get_node_or_null("/root/NetworkManager")
	session = get_node_or_null("/root/NetworkManager/Session")
	if net == null or session == null or net.is_online():
		return "Expected an isolated offline process"
	if flag("online-menu") or flag("cosmetic-ui") or flag("alignment") or flag("reward-plaques"):
		kept.menu_game = _stash(game, ["state", "play_started", "talk_cd"])
		kept.menu_paused = get_tree().paused
		kept.menu_hud_visible = game.hud.visible
		kept.menu_fields = _stash(game.menus, ["current", "_closable_now", "_shell_rect", "settings_return", "listening_action"])
	kept.game = _stash(game, GAME_FIELDS)
	kept.player = _stash(game.local_player, PLAYER_FIELDS)
	kept.net = _stash_script(net)
	kept.session = _stash_script(session)
	kept.loot_rng = game.loot_rng.state
	peer_before = net.multiplayer.multiplayer_peer
	game.play_started = true
	game.menus.close()
	game.state = Game.ST_PLAYING
	game.request_pause(false)
	game.hud.visible = true
	game.settings["touch_controls"] = touch_run
	game.settings["touch_layout"] = {}
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.dev_god = false
	await skip_dialogue()
	if not await _settled():
		return "Chapter reveal did not settle naturally"
	_check("isolated_safe_room", game.no_saves and String(game.zones[game.cur_room].get("type", "")) == "safe")
	_check("control_mode", game.touch_mode == touch_run)
	if flag("online-menu"):
		return await _online_menu_run()
	if flag("cosmetic-ui"):
		return await preload("res://scripts/tests/cosmetic_ui_live.gd").run(self)
	if flag("alignment"):
		return await preload("res://scripts/tests/hud_alignment_live.gd").run(self)
	if flag("reward-plaques"):
		return await preload("res://scripts/tests/reward_plaque_live.gd").run(self)
	await _capture("01_ordinary", "Unmodified character values after ordinary safe-room boot")
	var p: Player = game.local_player
	p.char_name = "Alexandria Ember" # the current 16-character name-entry limit
	game.player_title = "road_companion"
	await _capture("02_long_identity", "Synthetic long name plus an existing earned-title identifier; no title award")
	p.gold = 987654321
	p.atk = 321000.0 # stresses computed combat_rating(), not a replaced HUD label
	await _capture("03_high_values", "Synthetic wallet/attack values; computed high CR, not an attainable build claim")
	p.resonance = -100.0
	p.skill_points = 40
	await _capture("04_negative_many_points", "Negative resonance and 40 unspent skill points")
	var hero_detail: Array[String] = [p.char_name, String(Classes.CLASSES[p.cls]["name"]),
		String(Achievements.TITLES[game.player_title]["name"]), "Level %d" % p.level,
		"%d skill points" % p.skill_points, "%d gold" % p.gold,
		"Combat Rating: %d" % p.combat_rating(), "Resonance: %+d" % int(p.resonance)]
	for field in ["avatar_root", "stats_label"]:
		await _popover(String(field), "high_", hero_detail)
	await _popover("gold_label", "high_", ["%d gold" % p.gold])
	_quiet()
	await _capture("05_zero_points_quiet", "No skill points, unread mail, activity claims or daily reward")
	_badges()
	await _capture("06_all_solo_badges", "12 unread letters, ready contract, daily available and 12 skill points")
	var host_error := _start_party()
	if host_error != "":
		return host_error
	await _capture("07_party_all_badges", "Loopback host with three synthetic remote shells/roster rows and damage meter; not ENet replication proof")
	for row in [["mail_btn", "mailbox"], ["quest_btn", "journal"], ["inv_btn", "inventory"],
			["codex_btn", "codex"], ["daily_btn", "daily"], ["skills_btn", "skills"],
			["settings_btn", "pause"], ["party_btn", "lobby"]]:
		await _access(String(row[0]), String(row[1]))
	_check("utility_input_positive_control", successful_utility_inputs > 0,
		{"opened": successful_utility_inputs, "attempted": UTILITIES.size(), "input": "ScreenTouch" if touch_run else "mouse"})
	for field in POPUP_FIELDS:
		await _popover(String(field))
	game.daily_last_day = game.daily_day_index()
	await _capture("08_party_daily_hidden", "Party persists after Daily disappears; compare positions with 07")
	_stop_party()
	await frames(4)
	await _capture("09_solo_after_party", "Transport closed and synthetic remotes removed; compare fixed utilities")
	return ""


func _quiet() -> void:
	var p: Player = game.local_player
	p.char_name = "asali"
	p.gold = 47
	p.atk = float(kept.player.atk)
	p.skill_points = 0
	p.resonance = 0
	game.player_title = ""
	game.mailbox = []
	game.daily_last_day = game.daily_day_index()
	game.contracts = []
	game.bounties = []
	game.vault_claimed_week = game._week_index()


func _badges() -> void:
	game.local_player.skill_points = 12
	game.local_player.resonance = 100
	game.daily_last_day = game.daily_day_index() - 1
	game.daily_streak = 3
	game.mailbox = []
	for i in 12:
		game.mailbox.append({"subject": "Dossier fixture letter %d" % (i + 1), "body": "Read-only access fixture", "items": [], "sent_at": game.trusted_now(), "read": false})
	game.contracts = []
	game._roll_contracts("wildfang", 1, 92026)
	for contract in game.contracts:
		contract.done = true
		contract.claimed = false
		contract.progress = contract.target
	game.contract_day = game.daily_day_index()
	game.contract_claims_day = 0


func _start_party(with_allies := true) -> String:
	# Bind only loopback. No external service, guests, messages or join traffic.
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")
	var port := int(arg("port", "0" if flag("online-menu") else str(44000 + OS.get_process_id() % 10000)))
	var err := peer.create_server(port, 3)
	if err != OK:
		return "Loopback host unavailable: %s" % error_string(err)
	if flag("online-menu"):
		var bound_host: ENetConnection = peer.get_host()
		port = bound_host.get_local_port() if bound_host != null else 0
		_check("online_menu/bound_loopback_port", port > 0, {"port": port})
	net.multiplayer.multiplayer_peer = peer
	net.mode = NetMgr.Mode.ENET_DIRECT
	net.session_code = "127.0.0.1:%d" % port
	net.lobby_open = false
	net._session_active = true
	owned_host = true
	for i in (3 if with_allies else 0):
		var pid := 710 + i
		var block := {"name": "Dossier ally %d" % (i + 1), "cls": "warrior", "level": 1, "hp": 80.0 + i * 10, "max_hp": 130.0}
		session._spawn_remote(pid, block)
		session.lobby_chars[pid] = block.duplicate(true)
		ally_ids.append(pid)
	if with_allies:
		game.party_stats = {1: {"name": "asali", "cls": "warrior", "dmg": 2500.0, "heal": 0.0, "taken": 0.0}}
	session.lobby_changed.emit()
	_check("loopback_host", game.net_host() and net.multiplayer.get_peers().is_empty())
	return ""


func _stop_party() -> void:
	if not owned_host:
		return
	for pid in ally_ids:
		game.unregister_player(pid)
	ally_ids.clear()
	net.leave()
	owned_host = false


## Focused opt-in reuse. No chapter data, story completion, remote shells or
## pause implementation is replaced. Victory is setup only, not an earned win.
func _online_menu_run() -> String:
	var error := await _online_menu_case("01_solo", false, false)
	if error != "":
		return error
	error = _start_party(false)
	if error != "":
		return error
	error = await _online_menu_case("02_host", true, false)
	if error != "":
		return error
	# Independently exercise ESC return as well as the primary GUI callback.
	await _menu_escape()
	_check("online_menu/escape_reentry", game.menus.is_open() and game.menus.current == "pause")
	await _menu_escape()
	_check("online_menu/escape_return", not game.menus.is_open() and not get_tree().paused)
	error = await _online_menu_case("03_paused_victory", true, true)
	if error != "":
		return error
	game.state = Game.ST_PLAYING
	_stop_party()
	await frames(4)
	_check("online_menu/host_retired", not game.net_online() and not get_tree().paused)
	return ""


func _online_menu_case(id: String, online: bool, victory: bool) -> String:
	await _close_overlay() # setup only; every measured entry/return uses events
	game.state = Game.ST_VICTORY if victory else Game.ST_PLAYING
	if victory:
		game.request_pause(true)
	_check(id + "/starting_state", game.net_online() == online and get_tree().paused == victory)
	var before := _personal_receipt()
	if touch_run or victory:
		var menu_button: Control = game.hud.settings_btn
		if not menu_button.is_visible_in_tree():
			return id + ": HUD Menu button is not visible"
		await _tap(menu_button.get_global_rect().get_center())
	else:
		await _menu_escape()
	var opened: bool = game.menus.is_open() and game.menus.current == "pause"
	_check(id + "/actual_entry", opened, {"input": "ScreenTouch" if touch_run else ("mouse" if victory else "Escape")})
	if not opened:
		return id + ": actual menu entry failed"
	_check(id + "/state_survives_entry", game.state == (Game.ST_VICTORY if victory else Game.ST_PLAYING))
	_check(id + "/pause_rule", get_tree().paused == (not online or victory))
	var labels: Array[Label] = []
	var buttons: Array[Button] = []
	_menu_controls(game.menus.root, labels, buttons)
	var title: Label
	var footer: Label
	var primary: Button
	var chapter_name := String(Story.chapter(game.chapter_id)["name"])
	for label in labels:
		if label.text.contains(chapter_name):
			title = label
		if label.text.contains("outside"):
			footer = label
	for button in buttons:
		if button.text in ["Resume game", "Return to game"]:
			primary = button
	if title == null or footer == null or primary == null:
		return id + ": expected menu controls not found"
	_probe(id + "/truthful_title", title.text == ("Online — " if online else "Paused — ") + chapter_name,
		{"text": title.text, "online": online})
	_probe(id + "/primary_copy", primary.text == ("Return to game" if online else "Resume game"), {"text": primary.text})
	var expected_hint := "Game paused" if victory else "World keeps running"
	_probe(id + "/truthful_footer", footer.text.contains(expected_hint) if online else
		(not footer.text.contains("World keeps running") and not footer.text.contains("Game paused")),
		{"text": footer.text, "paused": get_tree().paused})
	var geometry := {"title": _menu_label_geometry(id + "/title", title),
		"footer": _menu_label_geometry(id + "/footer", footer), "primary": _rect(primary.get_global_rect()),
		"shell": _rect(game.menus._shell_rect), "viewport": _rect(get_viewport().get_visible_rect())}
	_probe(id + "/primary_visible", primary.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(primary.get_global_rect()))
	_probe(id + "/title_primary_separate", not title.get_global_rect().intersects(primary.get_global_rect()))
	_probe(id + "/footer_primary_separate", not footer.get_global_rect().intersects(primary.get_global_rect()))
	await _capture(id + "_open", "Actual GUI menu; synthetic already-paused victory" if victory else "Actual GUI menu; empty loopback host" if online else "Actual GUI menu; solo", false)
	views[-1]["online_menu"] = {"online": online, "host": game.net_host(), "paused": get_tree().paused,
		"state": game.state, "peer_count": net.multiplayer.get_peers().size(), "geometry": geometry,
		"title": title.text, "footer": footer.text, "primary": primary.text}
	_write_report()
	await _tap(primary.get_global_rect().get_center())
	_check(id + "/actual_primary_return", not game.menus.is_open() and not get_tree().paused,
		{"input": "ScreenTouch" if touch_run else "mouse", "state": game.state})
	_check(id + "/state_survives_return", game.state == (Game.ST_VICTORY if victory else Game.ST_PLAYING))
	_check(id + "/no_reward_mutation", before == _personal_receipt())
	await _capture(id + "_returned", "Actual primary-button return; victory remains a synthetic state, with no results card or story completion", false)
	return ""


func _menu_escape() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)
	await frames(4)


func _menu_controls(node: Node, labels: Array[Label], buttons: Array[Button]) -> void:
	if node is Label and node.is_visible_in_tree():
		labels.append(node)
	if node is Button and node.is_visible_in_tree():
		buttons.append(node)
	for child in node.get_children():
		_menu_controls(child, labels, buttons)


func _menu_label_geometry(id: String, label: Label) -> Dictionary:
	var ink := Rect2()
	var count := 0
	var missing: Array[int] = []
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty():
			continue
		var cell := label.get_character_bounds(index)
		if not cell.has_area():
			missing.append(index)
			continue
		ink = cell if count == 0 else ink.merge(cell)
		count += 1
	ink = label.get_global_transform() * ink
	var detail := {"text": label.text, "target": _rect(label.get_global_rect()), "ink": _rect(ink),
		"minimum_height": label.get_minimum_size().y, "line_count": label.get_line_count(), "missing": missing}
	_probe(id + "/full_text", count > 0 and missing.is_empty() and not label.clip_text
		and label.visible_ratio >= 1.0 and label.max_lines_visible == -1, detail)
	_probe(id + "/height_fits", label.size.y + 0.5 >= label.get_minimum_size().y, detail)
	_probe(id + "/ink_fits", label.get_global_rect().grow(0.5).encloses(ink)
		and game.menus._shell_rect.grow(0.5).encloses(ink) and get_viewport().get_visible_rect().encloses(ink), detail)
	return detail


func _access(field: String, expected: String) -> void:
	await _close_overlay()
	var button: Control = game.hud.get(field)
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		_probe("access/" + field, false, {"reason": "control not visible"})
		return
	var before := _personal_receipt()
	await _tap(button.get_global_rect().get_center())
	var opened: bool = game.menus.current == expected and game.menus.is_open()
	_probe("access/" + field, opened, {"expected": expected, "actual": game.menus.current, "input": "ScreenTouch" if touch_run else "mouse"})
	if opened:
		successful_utility_inputs += 1
		if field == "party_btn":
			var footer := "Tap Close this panel — your party session stays active" if touch_run \
				else "Close this panel or press ESC — your party session stays active"
			var copy := _popover_text(game.menus.root)
			_check("party_footer_whole_key", copy.contains(footer) and not copy.contains("tapSC"),
				{"expected": footer, "visible_copy": copy, "scope": "actual live host panel; synthetic peers"})
		await _capture("access_" + field, "Actual utility input opens " + expected, false)
	_check("access_no_reward/" + field, before == _personal_receipt())
	await _close_overlay()


func _popover(field: String, prefix := "", required: Array[String] = []) -> void:
	await _close_overlay()
	var control: Control = game.hud.get(field)
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		_probe("popover/" + prefix + field, false, {"reason": "control not visible"})
		return
	var before := _personal_receipt()
	var target := _ink_rect(control as Label) if control is Label else control.get_global_rect()
	await _tap(target.get_center())
	var opened := is_instance_valid(game.hud.hud_popover)
	_probe("popover/" + prefix + field, opened, {"input": "ScreenTouch" if touch_run else "mouse", "mouse_emulation": ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true), "target": _rect(target)})
	if opened:
		var text := _popover_text(game.hud.hud_popover)
		for expected in required:
			_probe("popover_content/" + prefix + field + "/" + expected, text.contains(expected), {"expected": expected, "visible_text": text})
		var panel: Control = null
		if game.hud.hud_popover.get_child_count() > 0:
			panel = game.hud.hud_popover.get_child(0) as Control
		_probe("popover_bounds/" + prefix + field, is_instance_valid(panel)
			and get_viewport().get_visible_rect().encloses(panel.get_global_rect()),
			{"rect": _rect(panel.get_global_rect()) if is_instance_valid(panel) else [], "visible_text": text})
		await _capture("access_" + prefix + field, "Actual input opens hero/statistic explanation; content read from visible labels", false)
	_check("popover_no_reward/" + prefix + field, before == _personal_receipt())
	await _close_overlay()


func _popover_text(root: Control) -> String:
	var lines: Array[String] = []
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if is_instance_valid(label) and label.is_visible_in_tree():
			lines.append(label.text)
	return "\n".join(lines)


func _tap(at: Vector2) -> void:
	if not touch_run:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
	for down in [true, false]:
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


func _close_overlay() -> void:
	game.hud._close_hud_popover()
	game.menus.close() # setup/reset only; opening always uses an actual event
	game.request_pause(false)
	await frames(4)


func _settled() -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	var clear_frames := 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var busy: bool = game.cutscene != null or game.hud._cinematic_mode or game.hud.dialogue_active or game.hud.choices_active
		for child in game.hud.get_children():
			busy = busy or child is Cutscene
		busy = busy or game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 or game.hud.subtitle_label.modulate.a > 0.01
		busy = busy or (is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible)
		clear_frames = 0 if busy else clear_frames + 1
		if clear_frames >= 4:
			return true
	return false


func _capture(label: String, scope: String, measure := true) -> void:
	step(label)
	await frames(6)
	if measure:
		await sim_wait(0.8) # let real stat pulses and delayed appearance updates settle
		_check(label + "/settled", await _settled())
	await RenderingServer.frame_post_draw
	var geometry := _geometry(label) if measure else {}
	views.append({"view": label, "path": shot(label), "scope": scope, "geometry": geometry,
		"state": _personal_receipt(), "frame": Engine.get_process_frames(), "menu": game.menus.current})
	_write_report()


func _geometry(view: String) -> Dictionary:
	var h: Hud = game.hud
	var fields := {}
	for field in ["info_panel", "stats_label", "gold_label", "cr_label", "res_label", "cr_chip", "res_chip",
			"avatar_root", "avatar_level_badge", "avatar_level_label", "mail_badge", "mail_badge_num", "quest_reward_badge",
			"quest_reward_count", "skills_badge", "skills_badge_num", "hp_fill", "hp_text", "mp_fill", "mp_text", "xp_fill"] + UTILITIES:
		var control: Control = _hud_field(String(field))
		if not is_instance_valid(control):
			continue
		var row := {"rect": _rect(control.get_global_rect()), "visible": control.is_visible_in_tree()}
		if control is Label:
			var label := control as Label
			row.text = label.text
			row.ink = _rect(_ink_rect(label))
			row.font = label.get_theme_font_size("font_size")
			if field in ["stats_label", "gold_label", "cr_label", "res_label"]:
				_probe(view + "/contained_text/" + field, h.info_panel.get_global_rect().grow(1).encloses(_ink_rect(label)), row)
		fields[field] = row
	var visible_buttons: Array[Control] = []
	for field in UTILITIES:
		var button: Control = h.get(field)
		if is_instance_valid(button):
			var bounds := button.get_global_rect()
			if not utility_reference.has(field):
				utility_reference[field] = bounds
			else:
				_probe(view + "/fixed_utility/" + field, bounds.is_equal_approx(utility_reference[field]),
					{"initial": _rect(utility_reference[field]), "current": _rect(bounds), "visible": button.is_visible_in_tree()})
		if is_instance_valid(button) and button.is_visible_in_tree():
			_probe(view + "/touch_target/" + field, button.size.x >= 44 and button.size.y >= 44, {"rect": _rect(button.get_global_rect())})
			for other in visible_buttons:
				_probe(view + "/utility_overlap/" + field + "/" + other.name, not button.get_global_rect().intersection(other.get_global_rect()).has_area())
			visible_buttons.append(button)
	var party_bounds := h.party_btn.get_global_rect()
	var menu_bounds := h.settings_btn.get_global_rect()
	_probe(view + "/party_menu_column", absf(party_bounds.get_center().x - menu_bounds.get_center().x) <= 0.5,
		{"party": _rect(party_bounds), "menu": _rect(menu_bounds),
			"center_offset": party_bounds.get_center().x - menu_bounds.get_center().x})
	_probe(view + "/party_menu_vertical_gap", is_equal_approx(menu_bounds.position.y - party_bounds.end.y, 4.0),
		{"gap": menu_bounds.position.y - party_bounds.end.y})
	for field in ["stats_label", "gold_label", "cr_label", "res_label"]:
		var label: Label = h.get(field)
		_probe(view + "/party_text_clear/" + String(field), not party_bounds.intersects(label.get_global_rect()),
			{"party": _rect(party_bounds), "text_target": _rect(label.get_global_rect()), "text": label.text})
	_skills_badge(view)
	if view in ["03_high_values", "04_negative_many_points"]:
		_visible_exact_stat(view, "gold_label", str(game.local_player.gold))
		_visible_exact_stat(view, "cr_label", str(game.local_player.combat_rating()))
		_visible_exact_stat(view, "res_label", "%+d" % int(game.local_player.resonance))
	var party := []
	for slot in h.party_slots:
		var root: Control = slot.root
		if root.is_visible_in_tree():
			var bounds := Rect2(root.get_global_rect().position, Vector2(h.PARTY_FRAME_W, h.PARTY_FRAME_H))
			party.append(_rect(bounds))
			_probe(view + "/party_clear", not h.info_panel.get_global_rect().intersection(bounds).has_area())
	var meter := {}
	if is_instance_valid(h.meter_root) and h.meter_root.is_visible_in_tree():
		var backdrop: Control = h.meter_root.get_child(0)
		meter = {"rect": _rect(backdrop.get_global_rect())}
	var decoration := {}
	for field in ["res_orb_glow", "res_orb_core", "res_particles", "daily_glow", "quest_glow"]:
		var item: Node2D = h.get(field)
		if is_instance_valid(item):
			decoration[field] = {"position": [item.global_position.x, item.global_position.y], "scale": [item.scale.x, item.scale.y], "visible": item.is_visible_in_tree()}
	return {"fields": fields, "party": party, "meter": meter, "decoration": decoration,
		"hero_body": _rect(preload("res://scripts/ui/hud_clearance.gd").body_rect(game.local_player)),
		"info_covered": h.clearance.covered(), "viewport": _rect(get_viewport().get_visible_rect())}


func _ink_rect(label: Label) -> Rect2:
	var font := label.get_theme_font("font")
	var extent := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
	if label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		extent.x = minf(extent.x, label.size.x)
	return Rect2(label.global_position, extent * label.scale)


## Allow --baseline to report an absent new badge without invalid-property
## accesses on the older HUD. Existing geometry fields retain their names.
func _hud_field(field: String) -> Variant:
	for property in game.hud.get_property_list():
		if String(property.name) == field:
			return game.hud.get(field)
	return null


func _visible_exact_stat(view: String, field: String, exact: String) -> void:
	var label: Label = game.hud.get(field)
	var font := label.get_theme_font("font")
	var full_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	_probe(view + "/exact_visible/" + field, label.text.contains(exact)
		and full_width <= label.size.x + 0.01 and game.hud.info_panel.get_global_rect().grow(1).encloses(_ink_rect(label)),
		{"expected": exact, "text": label.text, "full_text_width": full_width, "label_width": label.size.x,
		"font_size": label.get_theme_font_size("font_size"), "ink": _rect(_ink_rect(label))})


func _skills_badge(view: String) -> void:
	var badge: Control = _hud_field("skills_badge")
	var count: Label = _hud_field("skills_badge_num")
	var available: bool = is_instance_valid(badge) and is_instance_valid(count)
	_probe(view + "/skills_badge_available", available)
	if not available:
		return
	var expected: int = game.local_player.skill_points
	_probe(view + "/skills_badge_presence", badge.is_visible_in_tree() == (expected > 0),
		{"points": expected, "visible": badge.is_visible_in_tree()})
	if expected <= 0:
		return
	var ink := _ink_rect(count)
	var bounds := badge.get_global_rect()
	var button: Control = game.hud.skills_btn
	_probe(view + "/skills_badge_count", count.text == str(expected) and count.is_visible_in_tree()
		and count.modulate.a > 0.0 and badge.modulate.a > 0.0 and bounds.encloses(ink),
		{"expected": expected, "text": count.text, "badge": _rect(bounds), "ink": _rect(ink)})
	_probe(view + "/skills_badge_placement", button.get_global_rect().has_point(bounds.get_center())
		and game.hud.info_panel.get_global_rect().encloses(bounds), {"badge": _rect(bounds), "button": _rect(button.get_global_rect())})
	for field in UTILITIES:
		var other: Control = game.hud.get(field)
		if other != button and other.is_visible_in_tree():
			_probe(view + "/skills_badge_clear/" + String(field), not bounds.intersection(other.get_global_rect()).has_area())


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _personal_receipt() -> Dictionary:
	var p: Player = game.local_player
	return {"name": p.char_name, "title": game.player_title, "gold": p.gold, "cr": p.combat_rating(),
		"resonance": p.resonance, "skill_points": p.skill_points, "daily_last_day": game.daily_last_day,
		"claim_count": game.contract_claims_day, "contracts": game.contracts.duplicate(true),
		"health_stock": p.potion_count(), "online": game.net_online()}


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


func _cleanup() -> void:
	if not kept.is_empty() and is_instance_valid(game):
		await _close_overlay()
		_stop_party()
		await frames(3)
		_restore(game.local_player, kept.player)
		_restore(game, kept.game)
		_restore(session, kept.session)
		_restore(net, kept.net)
		net.multiplayer.multiplayer_peer = peer_before
		game._apply_touch_mode()
		game.loot_rng.state = int(kept.loot_rng)
		game.local_player.clear_local_intents()
		_check("restored_fixture_fields", game.local_player.char_name == kept.player.char_name
			and game.local_player.gold == kept.player.gold and game.local_player.atk == kept.player.atk
			and game.local_player.skill_points == kept.player.skill_points and game.settings == kept.game.settings
			and game.mailbox == kept.game.mailbox and game.contracts == kept.game.contracts and not net.is_online())
	_restore_disk()
	if kept.has("menu_game") and is_instance_valid(game):
		_restore(game, kept.menu_game)
		_restore(game.menus, kept.menu_fields)
		game.hud.visible = bool(kept.menu_hud_visible)
		get_tree().paused = bool(kept.menu_paused)
		_check("online_menu/restored_state", game.state == kept.menu_game.state
			and game.play_started == kept.menu_game.play_started and get_tree().paused == kept.menu_paused)


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


func _probe(label: String, passed: bool, details: Dictionary = {}) -> void:
	if not passed:
		findings.append({"finding": label, "details": details})
	if baseline:
		checks.append({"check": label, "passed": passed, "baseline_observation": true, "details": details})
	else:
		_check(label, passed, details)


func _check(label: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"check": label, "passed": passed, "details": details})
	if not passed:
		failures += 1
		print("HUD DOSSIER CHECK FAILED: ", label, " ", JSON.stringify(details))


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string(JSON.stringify({"rig": "hud_dossier", "baseline": baseline, "complete": complete,
		"touch": touch_run, "renderer": RenderingServer.get_current_rendering_method(), "no_saves": game.no_saves,
		"source_label": arg("label", "baseline" if baseline else "regression"),
		"online_menu": flag("online-menu"), "menus_sha256": FileAccess.get_sha256("res://scripts/menus.gd"),
		"reward_plaques": flag("reward-plaques"),
		"reward_plaque_helper_sha256": FileAccess.get_sha256("res://scripts/tests/reward_plaque_live.gd") if flag("reward-plaques") else "",
		"cosmetic_ui": flag("cosmetic-ui"), "alignment": flag("alignment"),
		"alignment_geometry_sha256": FileAccess.get_sha256("res://scripts/tests/hud_alignment_geometry.gd") if flag("alignment") else "",
		"alignment_live_sha256": FileAccess.get_sha256("res://scripts/tests/hud_alignment_live.gd") if flag("alignment") else "",
		"wardrobe_sha256": FileAccess.get_sha256("res://scripts/ui/wardrobe.gd") if flag("cosmetic-ui") else "",
		"codex_sha256": FileAccess.get_sha256("res://scripts/ui/codex.gd") if flag("cosmetic-ui") else "",
		"cosmetic_helper_sha256": FileAccess.get_sha256("res://scripts/tests/cosmetic_ui_live.gd") if flag("cosmetic-ui") else "",
		"hud_sha256": FileAccess.get_sha256("res://scripts/hud.gd"), "rig_sha256": FileAccess.get_sha256(get_script().resource_path),
		"scope": "controlled reward plaque / authored boss readout; paused world, real UI clocks; no earned achievement or combat" if flag("reward-plaques") else "posed HUD layout; shaped text cells and numeric baselines; controlled strings, not gameplay or raster ink" if flag("alignment") else "actual offline Wardrobe/Codex GUI opens; no purchase or equip; scroll placement is QA setup" if flag("cosmetic-ui") else "solo and empty loopback host; actual GUI inputs; synthetic paused victory state, no story completion or remote delivery" if flag("online-menu") else "synthetic UI state; normal safe room; actual GUI inputs; loopback host with synthetic allies, no remote network delivery",
		"checks": checks, "failures": failures, "findings": findings, "views": views}, "\t"))
	file.close()
