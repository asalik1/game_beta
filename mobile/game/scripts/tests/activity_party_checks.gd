extends RefCounted


static func _fit(g: Game) -> String:
	var tabs := g.menus.root.find_child("JournalTabs", true, false) as Control
	if tabs == null or not g.menus._shell_rect.grow(1).encloses(tabs.get_global_rect()):
		return "activity tabs escaped the journal shell"
	for button in g.menus.root.find_children("ContractClaim_*", "Button", true, false):
		if button.custom_minimum_size.y < 44.0:
			return "ward claim control is too small for touch"
	return ""


static func run(r: Node) -> String:
	var host: Game = r.readers[0]
	var g: Game = r.readers[1]
	var home := SaveGame.world_of(SaveGame.read(r.SLOT)).duplicate(true)
	g.menus.close()
	g.contracts = []
	for ward in Balance.WARD_CONTRACT_WARDS:
		g._roll_contracts(String(ward), Balance.WARD_CONTRACT_PER_WARD, 84)
	for c in g.contracts:
		c.done = true
		c.progress = c.target
	g.contract_day = g.daily_day_index()
	g.contract_claims_day = Balance.WARD_CONTRACT_DAILY_CAP - 2
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	r._show(1)
	await r.get_tree().create_timer(0.4, true).timeout
	if not g.hud.quest_reward_badge.visible or g.hud.quest_reward_count.text != "2":
		return "ready badge does not show the remaining two ward choices"
	await r._capture("activities_03_touch_ready_badge")
	g.menus.set_meta("journal_tab", "story")
	g.hud.quest_btn.pressed.emit()
	await r.frames(4)
	if String(g.menus.get_meta("journal_tab")) != "activities":
		return "the reward badge opened an unrelated remembered journal tab"
	var error := _fit(g)
	if error != "":
		return error
	await r._capture("activities_04_touch_ward_choices")
	var chosen: Dictionary
	for c in g.contracts:
		if String(c.ward) == "accord":
			chosen = c
			break
	var button := g.menus.root.find_child("ContractClaim_accord_" + String(chosen.type), true, false) as Button
	if button == null or button.disabled:
		return "ready Accord choice has no usable claim control"
	var host_gold := host.player.gold
	var host_standing := host.player.faction_standing.duplicate(true)
	var host_favor := host.player.npc_favor.duplicate(true)
	var gold := g.player.gold
	var standing: int = g.player.faction_standing.get("accord", 0)
	var expected := g.activity_gold(int(chosen.gold))
	button.pressed.emit()
	await r.frames(4)
	var claimed := 0
	for c in g.contracts:
		claimed += int(c.claimed)
	if not chosen.claimed or claimed != 1 or g.contract_claims_day != Balance.WARD_CONTRACT_DAILY_CAP - 1 \
		or g.player.gold != gold + expected or int(g.player.faction_standing.get("accord", 0)) != standing + Balance.WARD_CONTRACT_STANDING:
		return "claiming one ward paid incorrectly or consumed another ward choice"
	if host.player.gold != host_gold or host.player.faction_standing != host_standing or host.player.npc_favor != host_favor:
		return "a guest's ward choice changed the host's rewards"
	var saved := SaveGame.read(r.SLOT)
	var character := SaveGame.character_of(saved)
	# JSON numbers read as floats; compare the same wire representation while
	# retaining every field, row and order in this exact-save assertion.
	var saved_board: Variant = JSON.parse_string(JSON.stringify(g.contracts))
	if SaveGame.world_of(saved) != home or int(character.get("gold", -1)) != g.player.gold \
		or character.get("contracts", []) != saved_board or int(character.get("contract_claims_day", -1)) != g.contract_claims_day:
		var changed: Array = []
		for key in home:
			if home[key] != SaveGame.world_of(saved).get(key):
				changed.append(key)
		print("ACTIVITY SAVE DIAGNOSTIC: ", JSON.stringify({"world_changed": changed,
			"gold_saved": character.get("gold"), "gold_live": g.player.gold,
			"board_saved": character.get("contracts"), "board_live": g.contracts,
			"claims_saved": character.get("contract_claims_day"), "claims_live": g.contract_claims_day,
			"guest_world": g.guest_world, "restoring_save": g.restoring_save,
			"state": g.state, "no_saves": g.no_saves}))
		return "claim did not save the guest's exact board and purse to its own home"
	await r._capture("activities_05_personal_claim_saved")
	# The board is live in unpaused co-op. Its quote follows level changes,
	# and refresh keeps a reader's scroll position after controls relayout.
	var scroll := g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 160
	await r.frames(2)
	var offset := scroll.scroll_vertical
	var old_shell := g.menus.root.get_instance_id()
	g.player.level += 1
	g.player.recalc()
	await r.get_tree().create_timer(0.7, true).timeout
	scroll = g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	if g.menus.root.get_instance_id() == old_shell or scroll.scroll_vertical != offset:
		return "live reward quote refresh did not rebuild or preserve journal scrolling"
	var quote_seen := false
	for label in g.menus.root.find_children("*", "Label", true, false):
		if String(label.text).begins_with("Reward  ·  %d gold" % g.activity_gold(int(chosen.gold))):
			quote_seen = true
	if not quote_seen:
		return "open journal kept a stale level-scaled reward quote"
	await r._capture("activities_06_live_quote_preserves_scroll")
	# Progress while the guest reads: the ordinary local call is ignored,
	# then the real authority message advances that same personal entry.
	var tracking: Dictionary = g.contracts[-1]
	tracking.type = "rooms_cleared"
	tracking.target = 2
	tracking.progress = 0
	tracking.done = false
	g.menus.open_journal("activities")
	g.contract_progress("rooms_cleared")
	if int(tracking.progress) != 0:
		return "guest local code invented activity progress"
	r.wires[0].host_party_credit("room")
	await r.get_tree().create_timer(0.7, true).timeout
	if int(tracking.progress) != 1 or tracking.done:
		return "room credit did not advance the open personal board once"
	r.wires[0].host_party_credit("room")
	await r.get_tree().create_timer(0.7, true).timeout
	if not tracking.done or int(tracking.progress) != 2:
		return "second real room credit did not complete the guest's contract"
	await r._capture("activities_07_shared_progress_while_reading")
	# A genuine next-day trusted clock must replace the visible board without
	# allowing yesterday's finished choices to survive in the badge or UI.
	var next_day := g.daily_day_index() + 1
	old_shell = g.menus.root.get_instance_id()
	g.clock_anchor = next_day * 86400
	await r.get_tree().create_timer(0.7, true).timeout
	if g.contract_day != next_day or g.contract_claims_day != 0 or g.contracts_claimable() != 0 \
		or g.menus.root.get_instance_id() == old_shell:
		return "daily rollover left a stale open board or claim allowance"
	for c in g.contracts:
		if c.done or c.claimed:
			return "daily rollover retained yesterday's finished choices"
	await r._capture("activities_08_next_day_board")
	g.menus.close()
	g.menus.set_meta("journal_tab", "story")
	g.hud.quest_btn.pressed.emit()
	await r.frames(3)
	if String(g.menus.get_meta("journal_tab")) != "story":
		return "an empty reward badge discarded the player's remembered journal section"
	g.menus.open_codex("notes_activities")
	await r.frames(4)
	await r._capture("activities_08b_rewards_field_notes")
	var activities: Button
	for candidate in g.menus.root.find_children("*", "Button", true, false):
		if candidate.text == "Open Activities":
			activities = candidate
			break
	if activities == null or activities.custom_minimum_size.y < 44:
		return "activity field notes are missing their touch-sized journal link"
	activities.pressed.emit()
	await r.frames(3)
	if g.menus.current != "journal" or String(g.menus.get_meta("journal_tab")) != "activities":
		return "activity field notes failed to open the actual journal"
	# Preserve unfinished personal progress over party travel and teardown.
	g.contracts[0].progress = 1
	g.autosave()
	var own_board := g.contracts.duplicate(true)
	var own_day := g.contract_day
	var own_claims := g.contract_claims_day
	gold = g.player.gold
	host.switch_chapter("ch2", true)
	r.wires[0].host_advance_party()
	if not await r._until(func() -> bool: return g.chapter_id == "ch2", 15.0):
		return "activity party travel failed"
	for i in 2:
		r._show(i)
		await r.skip_dialogue()
		r.readers[i].player.set_physics_process(false)
	if g.contracts != own_board or g.contract_day != own_day or g.contract_claims_day != own_claims or g.player.gold != gold:
		return "party travel replaced the guest's board or purse"
	if SaveGame.world_of(SaveGame.read(r.SLOT)) != home:
		return "activity progress overwrote the guest's home world during travel"
	g.menus.open_journal("activities")
	await r.frames(3)
	await r._capture("activities_09_board_travels_with_hero")
	g.menus.close()
	r.transports[1].close()
	g.qa_online = false
	r.roots[1].online = false
	r.wires[1].set_physics_process(false)
	r.wires[1]._on_session_ended("activity ownership QA")
	await r.frames(4)
	if g.contracts != own_board or g.contract_day != own_day or g.contract_claims_day != own_claims or g.player.gold != gold:
		return "session teardown lost personal activity progress"
	if SaveGame.world_of(SaveGame.read(r.SLOT)) != home:
		return "session teardown changed the activity owner's home world"
	await r._capture("activities_10_disconnect_preserves_deeds")
	print("ok: ready badge and touch choices, one chosen ward, exact personal home save, live quote/scroll, authority room credit, daily rollover, party travel and disconnect ownership")
	return ""
