extends RefCounted
const Types := preload("res://scripts/tests/test_road_hunt.gd")

class ContractGame extends Types.Fixture:
	var today := 12345
	var saves := 0
	func daily_day_index() -> int: return today
	func autosave() -> void: saves += 1

static func run(t: Node) -> String:
	var g := ContractGame.new()
	g.play_started = true
	g.no_saves = false
	t.add_child(g)
	var p := Player.new()
	p.game = g
	p.level = 20
	p.gold = 500
	g.player = p
	g.players = [p]
	var error := _checks(g)
	g.player = null
	g.players = []
	p.free()
	g.free()
	if error == "":
		print("ok: activity current-day/current-entry claims, detached-copy rejection, expired-day credit, local/authority ownership, exact gold and bounded ready allowance")
	return error

static func _checks(g: ContractGame) -> String:
	g.refresh_contracts()
	var first: Dictionary = g.contracts[0]
	first.done = true
	first.progress = first.target
	var gold := g.player.gold
	var claims := g.contract_claims_day
	var standing := g.player.faction_standing.duplicate(true)
	var favor := g.player.npc_favor.duplicate(true)
	var copy := first.duplicate(true)
	if g.claim_contract(copy) == "" or g.player.gold != gold or g.contract_claims_day != claims 		or first.claimed or g.player.faction_standing != standing or g.player.npc_favor != favor:
		return "detached contract copy paid or marked the owner's current entry"
	var exact := g.activity_gold(int(first.gold))
	if g.claim_contract(first) != "" or g.player.gold != gold + exact or not first.claimed:
		return "the current board entry did not pay its quoted gold"
	if g.claim_contract(first) == "" or g.player.gold != gold + exact:
		return "an already-claimed ward contract paid again"
	var old: Dictionary = g.contracts[1]
	old.done = true
	old.progress = old.target
	gold = g.player.gold
	g.today += 1
	if g.contracts_claimable() != 0:
		return "yesterday's board advertised a reward claim"
	if g.claim_contract(old) == "" or g.player.gold != gold or g.contract_claims_day != 0 		or g.contract_day != g.today or old.claimed:
		return "a day rollover allowed an old claim or failed to refresh the allowance"
	# Prepare a known next-day row, then restore an expired board. The event
	# must refresh and advance the actual deterministic board, never that row.
	g.today += 1
	g.refresh_contracts()
	var credit_type := String(g.contracts[0].type)
	var expired := {"ward": "choir", "type": credit_type, "target": 100,
		"progress": 0, "done": false, "claimed": false, "gold": 80, "desc": "Old board"}
	g.contracts = [expired]
	g.contract_day = g.today - 1
	g.contract_progress(credit_type)
	if g.contract_day != g.today or int(expired.progress) != 0:
		return "post-midnight credit advanced yesterday's contract"
	var matching := 0
	for entry in g.contracts:
		if String(entry.type) == credit_type:
			matching += 1
			if int(entry.progress) != 1:
				return "fresh daily board lost the event that refreshed it"
	if matching == 0:
		return "deterministic daily board changed between refreshes"
	# A guest's ordinary local path cannot invent credit; authority can advance
	# that same personal board. The current RPC is verified by the live rig.
	g.guest = true
	var c: Dictionary = g.contracts[0]
	c.type = "rooms_cleared"
	c.target = 2
	c.progress = 0
	c.done = false
	g.contract_progress("rooms_cleared")
	if int(c.progress) != 0:
		return "a guest's local activity call bypassed authority"
	g.contract_progress("rooms_cleared", 1, true)
	if int(c.progress) != 1:
		return "host-authorized credit failed to advance the guest's own board"
	g.contract_progress("rooms_cleared", -1, true)
	if int(c.progress) != 1:
		return "negative activity credit removed progress"
	g.guest = false
	for entry in g.contracts:
		entry.done = true
		entry.claimed = false
	g.contract_claims_day = Balance.WARD_CONTRACT_DAILY_CAP - 1
	if g.contracts_claimable() != 1:
		return "ready badge exceeds the remaining ward choices"
	g.claim_contract(g.contracts[0])
	if g.contracts_claimable() != 0:
		return "used-up daily allowance still advertised ward claims"
	return ""
