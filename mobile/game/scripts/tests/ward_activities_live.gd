extends RefCounted
## Player-facing claims and host-to-owner activity credit through real ENet.

static func _board(ward: String, kind: String) -> Array:
	return [{"ward": ward, "type": kind, "target": 1, "progress": 0,
		"desc": "Defeat a boss", "gold": 80, "done": false, "claimed": false}]

static func _claim(m: Menus) -> Button:
	for button in m.root.find_children("*", "Button", true, false):
		if String(button.text).strip_edges() == "◆  CLAIM":
			return button
	return null

static func run(r: Node, _room: int) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var keep := []
	for g in [host, guest]:
		keep.append({"contracts": g.contracts.duplicate(true), "day": g.contract_day,
			"claims": g.contract_claims_day, "bounties": g.bounties.duplicate(true),
			"gold": g.player.gold, "level": g.player.level, "clock": g.clock_anchor,
			"standing": g.player.faction_standing.duplicate(true),
			"favor": g.player.npc_favor.duplicate(true), "no_saves": g.no_saves,
			"vault_week": g.vault_week, "vault_progress": g.vault_progress,
			"vault_claimed": g.vault_claimed_week, "settings": g.settings.duplicate(true)})
	var result := await _checks(r)
	if result == "":
		result = await preload("res://scripts/tests/activity_party_checks.gd").run(r)
	for i in 2:
		var g: Game = r.readers[i]
		g.menus.close()
		g.no_saves = true
		g.contracts = keep[i].contracts
		g.contract_day = keep[i].day
		g.contract_claims_day = keep[i].claims
		g.bounties = keep[i].bounties
		g.player.gold = keep[i].gold
		g.player.level = keep[i].level
		g.player.recalc()
		g.clock_anchor = keep[i].clock
		g.player.faction_standing = keep[i].standing
		g.player.npc_favor = keep[i].favor
		g.vault_week = keep[i].vault_week
		g.vault_progress = keep[i].vault_progress
		g.vault_claimed_week = keep[i].vault_claimed
		g.settings = keep[i].settings
		g.refresh_touch_mode()
		g._apply_touch_mode()
		g.no_saves = keep[i].no_saves
	return result

static func _checks(r: Node) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var failures: Array[String] = []
	for g in [host, guest]:
		g.contracts = _board("accord" if g == guest else "choir", "boss_kills")
		g.contract_day = g.daily_day_index()
		g.contract_claims_day = 0
		g.bounties = []
		g.vault_claimed_week = g._week_index()
	guest.player.level = 20
	guest.player.recalc()
	# Existing reliable authority event; each owner's board must progress once.
	host.contract_progress("boss_kills")
	r.wires[0].host_party_credit("boss")
	await r.get_tree().create_timer(0.6, true).timeout
	var credited: bool = guest.contracts[0].done
	if not credited:
		failures.append("eligible co-op guest received no ward-contract credit")
	# Lend a finished entry to inspect the real ready-claim presentation even
	# when the credit defect above prevented it from completing naturally.
	guest.contracts[0].done = true
	guest.contracts[0].progress = 1
	r._show(1)
	guest.menus.open_journal("activities")
	await r.frames(4)
	await r._capture("activities_01_ready_guest_contract")
	var shown_price := false
	var expected := int(80.0 * Balance.daily_gold_mult(guest.player.level))
	for label in guest.menus.root.find_children("*", "Label", true, false):
		if String(label.text).begins_with("Reward  ·  %d gold" % expected):
			shown_price = true
	if not shown_price:
		failures.append("contract card does not quote its actual level-scaled gold")
	var claim := _claim(guest.menus)
	if claim == null:
		return "ready contract has no claim button"
	var stale: Dictionary = guest.contracts[0]
	# Keep the displayed callback, then genuinely refresh the daily board.
	guest.contract_day -= 1
	guest.refresh_contracts()
	var gold_before := guest.player.gold
	var standing_before := guest.player.faction_standing.duplicate(true)
	var favor_before := guest.player.npc_favor.duplicate(true)
	claim.pressed.emit()
	await r.frames(4)
	var paid := guest.player.gold - gold_before
	var stale_paid: bool = paid != 0 or guest.contract_claims_day != 0 		or guest.player.faction_standing != standing_before or guest.player.npc_favor != favor_before
	if stale_paid:
		failures.append("an expired board callback paid or consumed today's claim allowance")
	await r._capture("activities_02_old_board_callback")
	var observation := {"guest_credit": credited, "price_matches": shown_price,
		"expected_gold": expected, "stale_gold_paid": paid,
		"claims_after_stale": guest.contract_claims_day, "old_entry_claimed": stale.claimed}
	print("ACTIVITY CLAIM AUDIT: ", JSON.stringify(observation))
	var file := FileAccess.open(r.shot_dir.path_join("activities.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(observation, "\t"))
		file.close()
	if not failures.is_empty():
		return "; ".join(failures)
	print("ok: co-op contract credit, exact visible reward and expired-board callback rejection")
	return ""
