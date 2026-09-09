extends RefCounted
## Exercise the real journal and payout path without changing the test hero.

static func run(t: Node) -> String:
	var g: Game = t.get("game")
	var paused := t.get_tree().paused
	var keep := {"contracts": g.contracts.duplicate(true), "day": g.contract_day,
		"claims": g.contract_claims_day, "no_saves": g.no_saves,
		"gold": g.player.gold, "level": g.player.level, "resonance": g.player.resonance,
		"standing": g.player.faction_standing.duplicate(true),
		"favor": g.player.npc_favor.duplicate(true),
		"tab": g.menus.get_meta("journal_tab", "quests"),
		"ward": g.menus.get_meta("journal_ward", ""),
		"notice": g.menus.get_meta("journal_notice", "")}
	g.no_saves = true
	var result := await _checks(g)
	g.menus.close()
	g.contracts = keep.contracts
	g.contract_day = keep.day
	g.contract_claims_day = keep.claims
	g.player.gold = keep.gold
	g.player.level = keep.level
	g.player.resonance = keep.resonance
	g.player.faction_standing = keep.standing
	g.player.npc_favor = keep.favor
	g.menus.set_meta("journal_tab", keep.tab)
	g.menus.set_meta("journal_ward", keep.ward)
	g.menus.set_meta("journal_notice", keep.notice)
	g.no_saves = keep.no_saves
	t.get_tree().paused = paused
	if result == "":
		print("ok: ward desk destinations, shared board selection, exact resonance favor, current-entry claims, cap, live scope/scroll/focus and honest directory services")
	return result


static func _frames(g: Game) -> void:
	for _i in 3:
		await g.get_tree().process_frame


static func _seed(g: Game) -> void:
	g.contracts = []
	for ward in Balance.WARD_CONTRACT_WARDS:
		g._roll_contracts(String(ward), Balance.WARD_CONTRACT_PER_WARD, 84)
		var c: Dictionary = g.contracts[-2]
		c.done = true
		c.progress = c.target
	g.contract_day = g.daily_day_index()
	g.contract_claims_day = 0


static func _label(m: Menus, name: String) -> String:
	var label := m.root.find_child(name, true, false) as Label
	return label.text if label != null else ""


static func _quote(card: Node, fragment: String) -> bool:
	for label in card.find_children("*", "Label", true, false):
		if fragment in String(label.text):
			return true
	return false


static func _checks(g: Game) -> String:
	_seed(g)
	var m := g.menus
	var board := g.contracts.duplicate(true)
	for value in Balance.WARD_CONTRACT_WARDS:
		var ward := String(value)
		g._hub_action("ward_contract_" + ward)
		await _frames(g)
		if m.current != "journal" or m.get_meta("journal_tab") != "activities" or m.get_meta("journal_ward") != ward:
			return "ward desk did not explicitly select " + ward
		var cards := m.root.find_children("ContractCard_*", "VBoxContainer", true, false)
		if cards.size() != Balance.WARD_CONTRACT_PER_WARD:
			return "selected ward did not show exactly its own daily deeds"
		for card in cards:
			if not String(card.name).begins_with("ContractCard_" + ward + "_"):
				return "selected ward showed another faction's deed"
		if _label(m, "JournalWardHeading") != ward.to_upper() + " CONTRACTS" or not _label(m, "JournalWardAllowance").begins_with("4 of 4"):
			return "ward heading or shared daily allowance was missing"
		var selector := m.root.find_child("JournalWard_" + ward, true, false) as Button
		if selector == null or not selector.button_pressed or selector.custom_minimum_size.y < 44.0:
			return "ward selector did not show the active ward with a touch-sized control"
	if g.contracts != board or g.contract_claims_day != 0:
		return "browsing ward desks changed the personal board or used a daily choice"
	m.open_journal("activities", "unknown_ward")
	await _frames(g)
	if m.get_meta("journal_ward") != "" or m.root.find_children("ContractCard_*", "VBoxContainer", true, false).size() != g.contracts.size():
		return "invalid ward did not safely fall back to all activities"
	m.open_journal("activities", "accord")
	(m.root.find_child("JournalWard_choir", true, false) as Button).pressed.emit()
	await _frames(g)
	if m.get_meta("journal_ward") != "choir":
		return "ward selector did not switch to its named board"
	(m.root.find_child("JournalWard_all", true, false) as Button).pressed.emit()
	await _frames(g)
	if m.get_meta("journal_ward") != "":
		return "All activities retained a ward filter"
	# Numeric favor must quote the same actual award in all three shard bands.
	for pair in [[-Story.RES_BAND_AT, 4], [0.0, 5], [Story.RES_BAND_AT, 6]]:
		_seed(g)
		g.player.resonance = pair[0]
		g.player.level = 20
		g.player.npc_favor["kesh"] = 0
		var chosen: Dictionary
		for entry in g.contracts:
			if String(entry.ward) == "accord" and bool(entry.done):
				chosen = entry
		var expected := int(pair[1])
		if g.favor_gain(Balance.WARD_CONTRACT_FAVOR) != expected:
			return "shared favor quote changed the established resonance award"
		m.open_journal("activities", "accord")
		await _frames(g)
		var id := "accord_" + String(chosen.type)
		var card := m.root.find_child("ContractCard_" + id, true, false)
		if card == null or not _quote(card, "+ %d Kesh favor" % expected) or not _quote(card, "%d gold" % g.activity_gold(int(chosen.gold))):
			return "Accord card did not quote exact gold and resonance-scaled favor"
		var claim := m.root.find_child("ContractClaim_" + id, true, false) as Button
		if claim == null or claim.disabled:
			return "ready original contract has no usable claim button"
		var gold := g.player.gold
		var standing: int = g.player.faction_standing.get("accord", 0)
		claim.grab_focus()
		claim.pressed.emit()
		await _frames(g)
		if not bool(chosen.claimed) or g.contract_claims_day != 1 or g.player.gold != gold + g.activity_gold(int(chosen.gold)) or g.favor_points("kesh") != expected or int(g.player.faction_standing.get("accord", 0)) != standing + Balance.WARD_CONTRACT_STANDING:
			return "ward claim lost original identity or paid a different reward from the quote"
		if m.get_meta("journal_ward") != "accord" or not _label(m, "JournalWardAllowance").begins_with("3 of 4"):
			return "claim discarded the selected ward or its remaining allowance"
		var focus := m.get_viewport().gui_get_focus_owner()
		if focus == null or String(focus.name) != "JournalWard_accord":
			return "consumed claim did not return focus to the selected ward"
	# A background quote/standing update retains both the view and reader focus.
	(m.root.find_child("JournalWard_choir", true, false) as Button).grab_focus()
	var scroll := m.root.find_child("JournalScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 40
	var offset := scroll.scroll_vertical
	var old_shell := m.root.get_instance_id()
	g.player.level += 1
	g.player.faction_standing["accord"] = 37
	await g.get_tree().create_timer(0.7, true).timeout
	scroll = m.root.find_child("JournalScroll", true, false) as ScrollContainer
	var focus := m.get_viewport().gui_get_focus_owner()
	if m.root.get_instance_id() == old_shell or m.get_meta("journal_ward") != "accord" or scroll.scroll_vertical != offset or focus == null or String(focus.name) != "JournalWard_choir":
		return "live ward refresh lost selected context, scroll or keyboard focus"
	if not _label(m, "JournalWardStanding").begins_with("Accord standing: 37"):
		return "open ward header kept a stale standing value"
	_seed(g)
	for entry in g.contracts:
		entry.done = true
	g.contract_claims_day = Balance.WARD_CONTRACT_DAILY_CAP
	m.open_journal("activities", "choir")
	await _frames(g)
	for button in m.root.find_children("ContractClaim_*", "Button", true, false):
		if not button.disabled:
			return "another ward bypassed the shared daily allowance"
	g._hub_action("journal")
	await _frames(g)
	if m.get_meta("journal_tab") != "quests" or m.get_meta("journal_ward") != "":
		return "Archive journal no longer opens Quests without a ward filter"
	m.open_journal("activities", "wildfang")
	m.open_journal("activities")
	if m.get_meta("journal_ward") != "":
		return "traveling Activities retained a previous desk's ward filter"
	var fake := {"mark": "●", "npcs": [], "landmarks": []}
	if "CONTRACT" in m._capital_zone_services(fake):
		return "directory advertised a contract desk from a decorative mark alone"
	fake.landmarks = [{"uses": [{"type": "action", "ref": "ward_contract_accord"}, {"type": "action", "ref": "ward_contract_accord"}, {"type": "inspect", "ref": "journal"}]}]
	if m._capital_zone_services(fake) != "WARD CONTRACTS":
		return "directory missed, duplicated or invented a landmark service"
	return ""
