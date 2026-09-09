extends ShotRig
## Real generated capital hotspots, ordinary Interact input and ward boards.
## Run through shot.bat ward_desks; --baseline records the pre-fix failures.

var findings: Array[String] = []

func _ready() -> void:
	await boot("warrior", "ch1", false)
	var error := await _checks()
	if error != "":
		findings.append(error)
	var path := ProjectSettings.globalize_path(shot_dir + "/verdict.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline": flag("baseline"), "findings": findings}, "\t"))
	file.close()
	for finding in findings:
		print("WARD DESK FINDING: " + finding)
	finish(0 if findings.is_empty() else 1)


func _key(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label)


func _interact() -> void:
	if flag("touch"):
		var panel: Panel = game._touch_hud._btns["interact"]["panel"]
		if not panel.visible:
			findings.append("the touch Act button did not appear at a capital desk")
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = panel.get_global_rect().get_center()
		event.pressed = true
		Input.parse_input_event(event)
		await frames(3)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	else:
		_key(KEY_E, true)
		await frames(3)
		_key(KEY_E, false)
	await frames(3)


func _click(button: Button) -> void:
	var pos := button.get_global_rect().get_center()
	if flag("touch"):
		for down in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = pos
			touch.pressed = down
			Input.parse_input_event(touch)
			await frames(3)
		await frames(3)
		return
	var move := InputEventMouseMotion.new()
	move.position = pos
	Input.parse_input_event(move)
	await frames(2)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)
	await frames(3)


func _check_cards(ward: String) -> String:
	var cards := game.menus.root.find_children("ContractCard_*", "VBoxContainer", true, false)
	if cards.size() != Balance.WARD_CONTRACT_PER_WARD:
		return "selected %s board showed %d cards" % [ward, cards.size()]
	for card in cards:
		if not String(card.name).begins_with("ContractCard_" + ward + "_"):
			return "selected %s board showed another ward's card" % ward
	var selectors := game.menus.root.find_children("JournalWard_*", "Button", true, false)
	if selectors.size() != 5:
		return "selected board did not offer all four wards and all activities"
	for button in selectors:
		if button.size.y < 44.0 or not game.menus._shell_rect.grow(1).encloses(button.get_global_rect()):
			return "ward selector escaped its shell or lost its touch-sized target"
	return ""


func _checks() -> String:
	var ready_by := Time.get_ticks_msec() + 6000
	while not game.play_started and Time.get_ticks_msec() < ready_by:
		await get_tree().create_timer(0.05, true).timeout
	if not game.play_started:
		return "fixture did not reach play"
	game.camera.position_smoothing_enabled = false
	game.settings["camera_shake"] = 0.0
	game.terrain_event_t = 10000.0
	game.enter_capital()
	await frames(8)
	await skip_dialogue()
	if flag("touch"):
		game.settings["touch_controls"] = true
		game.refresh_touch_mode()
		game._apply_touch_mode()
		await frames(4)
	# Normal deterministic board, with one completed choice in each ward.
	game.contracts = []
	game.contract_day = game.daily_day_index()
	game.contract_claims_day = 0
	for wi in Balance.WARD_CONTRACT_WARDS.size():
		game._roll_contracts(String(Balance.WARD_CONTRACT_WARDS[wi]), Balance.WARD_CONTRACT_PER_WARD, 706 + wi)
	for ward in Balance.WARD_CONTRACT_WARDS:
		for contract in game.contracts:
			if String(contract.ward) == String(ward):
				contract.done = true
				contract.progress = contract.target
				break
	for spec in [
		["Fangmoot Circle", "Review Wildfang contracts", "wildfang"],
		["The Rot-Chapel", "Review Choir contracts", "choir"],
		["Accord Commons", "Review Accord contracts", "accord"],
		["The Sable Court", "Review Cinderborn contracts", "cinderborn"],
		["The Grand Archive", "Read your journal", ""],
	]:
		game.menus.close()
		var room := -1
		for i in game.zones.size():
			if String(game.zones[i].name) == String(spec[0]):
				room = i
		if room < 0:
			return "missing capital room " + String(spec[0])
		game.fast_travel(room)
		await get_tree().create_timer(3.6, true).timeout
		var entry: Dictionary = {}
		for candidate in game.interactables:
			if (candidate.prompt as Label).text.contains(String(spec[1])):
				entry = candidate
				break
		if entry.is_empty():
			return "missing generated interaction " + String(spec[1])
		game.player.global_position = (entry.node as Node2D).global_position
		await frames(6)
		var ward := String(spec[2])
		if ward == "wildfang":
			await _capture("01_wildfang_desk_prompt")
		await _interact()
		await _capture("desk_" + (ward if ward != "" else "archive"))
		if game.menus.current != "journal":
			findings.append("%s did not open a journal board (current=%s)" % [spec[1], game.menus.current])
		elif ward == "":
			if String(game.menus.get_meta("journal_tab", "")) != "quests":
				findings.append("archive no longer opens Quests")
		elif String(game.menus.get_meta("journal_tab", "")) != "activities" \
				or String(game.menus.get_meta("journal_ward", "")) != ward:
			findings.append("%s opened tab=%s ward=%s" % [spec[1], game.menus.get_meta("journal_tab", ""), game.menus.get_meta("journal_ward", "")])
		elif not flag("baseline"):
			var card_error := _check_cards(ward)
			if card_error != "":
				findings.append(card_error)
	if not flag("baseline") and findings.is_empty():
		return await _board_actions()
	return ""


func _board_actions() -> String:
	step("ward switching and actual GUI claim")
	game.menus.open_journal("activities", "wildfang")
	await frames(3)
	var accord := game.menus.root.find_child("JournalWard_accord", true, false) as Button
	if accord == null:
		return "missing Accord selector"
	await _click(accord)
	if String(game.menus.get_meta("journal_ward", "")) != "accord":
		return "GUI click did not select Accord"
	var card_error := _check_cards("accord")
	if card_error != "":
		return card_error
	var chosen: Dictionary = {}
	for contract in game.contracts:
		if String(contract.ward) == "accord" and bool(contract.done):
			chosen = contract
	var button := game.menus.root.find_child("ContractClaim_accord_" + String(chosen.type), true, false) as Button
	if button == null or button.disabled:
		return "selected ready Accord deed has no usable claim button"
	var gold := game.player.gold
	var standing: int = game.player.faction_standing.get("accord", 0)
	var favor: int = game.player.npc_favor.get("kesh", 0)
	await _click(button)
	if not bool(chosen.claimed) or game.contract_claims_day != 1 \
			or game.player.gold != gold + game.activity_gold(int(chosen.gold)) \
			or int(game.player.faction_standing.get("accord", 0)) != standing + Balance.WARD_CONTRACT_STANDING \
			or int(game.player.npc_favor.get("kesh", 0)) != favor + game.favor_gain(Balance.WARD_CONTRACT_FAVOR):
		return "GUI claim did not pay exactly the intended deed"
	if String(game.menus.get_meta("journal_ward", "")) != "accord":
		return "claim lost the selected ward"
	await _capture("07_accord_claimed")
	var all := game.menus.root.find_child("JournalWard_all", true, false) as Button
	await _click(all)
	if String(game.menus.get_meta("journal_ward", "invalid")) != "":
		return "All Activities failed to clear the ward filter"
	if game.menus.root.find_children("ContractCard_*", "VBoxContainer", true, false).size() != game.contracts.size():
		return "combined Activities lost ward choices"
	await _capture("08_all_activities")
	game.menus.open_journal("activities", "choir")
	await frames(3)
	game.menus.open_journal("activities")
	await frames(3)
	if String(game.menus.get_meta("journal_ward", "invalid")) != "":
		return "ordinary Activities opener retained a stale desk filter"
	game.menus.open_journal("activities", "unknown_ward")
	await frames(3)
	if String(game.menus.get_meta("journal_ward", "invalid")) != "":
		return "invalid ward was accepted"
	return ""
