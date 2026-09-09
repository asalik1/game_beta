class_name UIActivityRewards
extends RefCounted
## Keep an open journal's board and reward quotes current in unpaused co-op.

class BoardWatch extends Node:
	var menus: Menus
	var shell: Control
	var tab := "activities"
	var ward := ""
	var signature := 0
	var remaining := 0.0
	func _process(delta: float) -> void:
		if not is_instance_valid(menus) or menus.root != shell or menus.current != "journal":
			set_process(false)
			return
		remaining -= delta
		if remaining > 0.0:
			return
		remaining = Balance.ACTIVITY_BOARD_REFRESH
		menus.game.refresh_bounties()
		menus.game.refresh_contracts()
		var next := UIActivityRewards._signature(menus.game, tab)
		if next != signature:
			UIActivityRewards.reopen(menus, tab, ward)


static func _signature(g: Game, tab := "activities") -> int:
	var state: Array = [g.contract_day, g.contract_claims_day, g.contracts.hash(),
		g.bounties.hash(), g.vault_week, g.vault_progress, g.vault_claimed_week,
		g.player.level if g.has_local_player() else 0,
		g.player.resonance if g.has_local_player() else 0,
		g.player.faction_standing.hash() if g.has_local_player() else 0,
		g.player.npc_favor.hash() if g.has_local_player() else 0]
	if tab == "progress":
		state.append_array([g.hud.wayfinder.context_key(), g.cur_room,
			g.zone_count, g.visited.hash(), g.boss_done.hash(), g.pocket_done,
			g.unlisted_banked.hash(), g.waking_kills.hash(), g.waking_kills_week,
			g._week_index()])
	return hash(state)


## A refresh is the same view with current data. Keep original card identities
## for claiming, but carry only control names across the old shell's lifetime.
static func reopen(m: Menus, tab: String, ward := "") -> void:
	var offset := 0
	var focus_name := ""
	if is_instance_valid(m.root):
		var scroll := m.root.find_child("JournalScroll", true, false) as ScrollContainer
		if scroll != null:
			offset = scroll.scroll_vertical
		var focused := m.get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and m.root.is_ancestor_of(focused):
			focus_name = String(focused.name)
	m.open_journal(tab, ward)
	_restore_view(m, m.root, offset, focus_name, tab, ward)


static func _restore_view(m: Menus, shell: Control, offset: int, focus_name: String,
		tab: String, ward: String) -> void:
	await m.get_tree().process_frame
	if not is_instance_valid(m) or not is_instance_valid(shell) or m.root != shell:
		return
	if focus_name != "":
		var focused := shell.find_child(focus_name, true, false) as Control
		if focused == null or (focused is BaseButton and (focused as BaseButton).disabled):
			# The focused claim can disappear after payout, or become disabled
			# when today's shared allowance runs out. Return to its view selector.
			var fallback := "JournalWard_" + ("all" if ward == "" else ward) if tab == "activities" else "JournalTab_" + tab
			focused = shell.find_child(fallback, true, false) as Control
		if focused != null and focused.is_visible_in_tree() and focused.focus_mode != Control.FOCUS_NONE:
			focused.grab_focus()
	var scroll := shell.find_child("JournalScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = offset


static func watch(m: Menus, tab: String, ward := "") -> void:
	var guard := BoardWatch.new()
	guard.menus = m
	guard.shell = m.root
	guard.tab = tab
	guard.ward = ward
	guard.signature = _signature(m.game, tab)
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	m.root.add_child(guard)


static func notes(m: Menus, list: VBoxContainer) -> void:
	for pair in [
		["Your ward board", "Each hero gets a daily board from the four wards. Defeating bosses and elites and clearing rooms advances the matching contracts. In co-op, eligible party members advance their own boards through the host's shared credit."],
		["Visit a ward desk", "The Wildfang, Choir, Accord and Cinderborn contract desks in Crownfall open that ward's own board. Browse the ward buttons to compare rewards, or choose All activities for the traveling journal. No acceptance is needed: every matching deed progresses as you play, and browsing spends no daily choice."],
		["Choose your rewards", "Completing a contract makes its reward available. Claim up to %d per day on that hero; pick the wards whose standing you want. Accord contracts also earn Kesh favor. Unclaimed choices expire when the daily board refreshes." % Balance.WARD_CONTRACT_DAILY_CAP],
		["Find a finished deed", "The journal icon counts rewards you can claim now and opens Activities when a reward waits. Ready contracts appear first. Gold quotes match the hero's current level; Kesh favor reflects your current shard resonance. All four wards share that hero's daily allowance. Claiming a ward reward never claims another ward on your behalf."],
		["Other activities", "Bounties pay automatically when completed. The weekly vault has a separate claim: a golden chest, a bright gem and Renown. Your activity board and earned rewards travel with your own character when you visit a friend's world."]]:
		m._lbl(list, String(pair[0]), 18, UITheme.GOLD_BRIGHT)
		m._lbl(list, String(pair[1]), 16)
	if m.game.has_local_player():
		var button := m._btn(list, "Open Activities", func() -> void: m.open_journal("activities"))
		button.custom_minimum_size.y = 44
