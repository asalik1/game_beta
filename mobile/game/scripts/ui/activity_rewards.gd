class_name UIActivityRewards
extends RefCounted
## Keep an open journal's board and reward quotes current in unpaused co-op.

class BoardWatch extends Node:
	var menus: Menus
	var shell: Control
	var tab := "activities"
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
		var next := UIActivityRewards._signature(menus.game)
		if next != signature:
			var scroll := shell.find_child("JournalScroll", true, false) as ScrollContainer
			var offset := scroll.scroll_vertical if scroll != null else 0
			menus.open_journal(tab)
			UIActivityRewards._restore_scroll(menus, menus.root, offset)


static func _signature(g: Game) -> int:
	return hash([g.contract_day, g.contract_claims_day, g.contracts.hash(),
		g.bounties.hash(), g.vault_week, g.vault_progress, g.vault_claimed_week,
		g.player.level if g.has_local_player() else 0])


static func _restore_scroll(m: Menus, shell: Control, offset: int) -> void:
	await m.get_tree().process_frame
	if not is_instance_valid(shell) or m.root != shell:
		return
	var scroll := shell.find_child("JournalScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = offset


static func watch(m: Menus, tab: String) -> void:
	var guard := BoardWatch.new()
	guard.menus = m
	guard.shell = m.root
	guard.tab = tab
	guard.signature = _signature(m.game)
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	m.root.add_child(guard)


static func notes(m: Menus, list: VBoxContainer) -> void:
	for pair in [
		["Your ward board", "Each hero gets a daily board from the four wards. Defeating bosses and elites and clearing rooms advances the matching contracts. In co-op, eligible party members advance their own boards through the host's shared credit."],
		["Choose your rewards", "Completing a contract makes its reward available. Claim up to %d per day on that hero; pick the wards whose standing you want. Accord contracts also earn Kesh favor. Unclaimed choices expire when the daily board refreshes." % Balance.WARD_CONTRACT_DAILY_CAP],
		["Find a finished deed", "The journal icon counts rewards you can claim now and opens Activities when a reward waits. Ready contracts appear first. Gold quotes match the hero's current level. Claiming a ward reward never claims another ward on your behalf."],
		["Other activities", "Bounties pay automatically when completed. The weekly vault has a separate claim: a golden chest, a bright gem and Renown. Your activity board and earned rewards travel with your own character when you visit a friend's world."]]:
		m._lbl(list, String(pair[0]), 18, UITheme.GOLD_BRIGHT)
		m._lbl(list, String(pair[1]), 16)
	if m.game.has_local_player():
		var button := m._btn(list, "Open Activities", func() -> void: m.open_journal("activities"))
		button.custom_minimum_size.y = 44
