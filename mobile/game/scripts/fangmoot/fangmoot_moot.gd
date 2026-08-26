class_name FangmootMoot
extends RefCounted
## The moot state machine: shop turns, tray, board, bonds, crests/scars.
## PROPOSALS/FANGMOOT.md §4-§6. Fully serialisable for save/resume.
##
## A board slot is a Dictionary:
##   { kind, copies, charm, bite, hide, brew_bite, brew_ward }
##   bite/hide are the CURRENT warband stats (base + bonds + brews + permanent
##   in-fight gains). brew_bite/brew_ward are one-fight buffs for the next fight.
## A tray card:
##   { ctype:"token"|"named"|"charm"|"brew", id, frozen }

var host: FangmootHost
var table := "copper"
var seed := 0
var ground := ""
var turn := 1
var fangs := 0
var crests := 0
var scars := 0
var done := false
var outcome := ""          # "", "win", "loss", "timeout"
var rewarded := false      # the UI grants the end-of-moot reward exactly once
var board: Array = []       # size 5, null or slot
var tray: Array = []
var last_result := ""       # "a"|"b"|"draw" from the most recent fight
var last_log: Array = []
var last_band: Array = []   # the exact bands fought (for the arena renderer)
var last_opp: Array = []
var want_log := true        # the bench turns this off for speed
var rng := RandomNumberGenerator.new()

# precomputed fieldable pools (constant for a moot)
var _pool_by_tier := {}     # tier:int -> Array[kind]
var _named_pool: Array = []


func _init(p_table := "copper", p_seed := 0, p_host: FangmootHost = null) -> void:
	table = p_table
	seed = p_seed
	host = p_host if p_host != null else FangmootHost.new()
	rng.seed = seed
	board.resize(_board_size())
	_precompute_pools()
	_pick_ground()


# ------------------------------------------------------------------ config
func _board_size() -> int:
	return int(Balance.FANGMOOT_BOARD)

func income() -> int:
	return int(Balance.FANGMOOT_FANGS)

func level_of(slot) -> int:
	if slot == null:
		return 1
	var c := int(slot.get("copies", 1))
	if c >= 6:
		return 3
	if c >= 3:
		return 2
	return 1


# --------------------------------------------------------------- pools
func _precompute_pools() -> void:
	for t in range(1, 6):
		_pool_by_tier[t] = []
	for kind in FangmootData.TOKENS:
		var tier := int(FangmootData.TOKENS[kind]["tier"])
		if tier <= 2 or host.fieldable(kind):
			_pool_by_tier[tier].append(kind)
	for kind in FangmootData.NAMED:
		if host.fieldable(kind):
			_named_pool.append(kind)

func _pick_ground() -> void:
	if table == "copper":
		ground = "village"   # the tutorial ground
		return
	var ids: Array = FangmootData.GROUND_ORDER
	ground = String(ids[rng.randi() % ids.size()])


# --------------------------------------------------------------- shop turn
func begin_turn() -> void:
	fangs = income()
	_roll_tray(true)

func _roll_tray(keep_frozen: bool) -> void:
	var kept: Array = []
	if keep_frozen:
		for c in tray:
			if bool(c.get("frozen", false)):
				kept.append(c)
	tray = kept
	var have_tokens := 0
	var have_supply := 0
	var have_named := 0
	for c in kept:
		match String(c["ctype"]):
			"token": have_tokens += 1
			"named": have_named += 1
			_: have_supply += 1
	for i in maxi(0, _tray_tokens() - have_tokens):
		var k := _pick_token()
		if k != "":
			tray.append({"ctype": "named" if FangmootData.is_named(k) else "token", "id": k, "frozen": false})
	for i in maxi(0, _tray_supply() - have_supply):
		tray.append(_pick_supply())
	if _named_slot() and have_named == 0:
		var n := _pick_named()
		if n != "":
			tray.append({"ctype": "named", "id": n, "frozen": false})

func _tray_tokens() -> int:
	if turn <= 2:
		return int(Balance.FANGMOOT_TRAY_TOKENS_EARLY)
	if turn <= 6:
		return int(Balance.FANGMOOT_TRAY_TOKENS_MID)
	return int(Balance.FANGMOOT_TRAY_TOKENS_LATE)

func _tray_supply() -> int:
	return int(Balance.FANGMOOT_TRAY_SUPPLY_EARLY) if turn <= 2 else int(Balance.FANGMOOT_TRAY_SUPPLY_LATE)

func _named_slot() -> bool:
	if _named_pool.is_empty() or turn < int(Balance.FANGMOOT_NAMED_TURN):
		return false
	if turn >= int(Balance.FANGMOOT_NAMED_GUARANTEE_TURN):
		return true
	return rng.randf() < float(Balance.FANGMOOT_NAMED_ODDS)

func _available_tiers() -> Array:
	var out: Array = []
	for t in range(1, 6):
		if int(FangmootData.TIER_UNLOCK_TURN[t]) <= turn and not _pool_by_tier[t].is_empty():
			out.append(t)
	return out

func _pick_token() -> String:
	var tiers := _available_tiers()
	if tiers.is_empty():
		return ""
	var cur: int = tiers[tiers.size() - 1]
	var weighted: Array = []
	var total := 0
	for t in tiers:
		var w := int(Balance.FANGMOOT_TIER_W_OLD)
		if t == cur:
			w = int(Balance.FANGMOOT_TIER_W_NEW)
		elif t == cur - 1:
			w = int(Balance.FANGMOOT_TIER_W_BELOW)
		weighted.append([t, w])
		total += w
	var r := rng.randi() % total
	var tier: int = cur
	for pair in weighted:
		r -= int(pair[1])
		if r < 0:
			tier = int(pair[0])
			break
	var pool: Array = _pool_by_tier[tier]
	return String(pool[rng.randi() % pool.size()])

func _pick_named() -> String:
	if _named_pool.is_empty():
		return ""
	return String(_named_pool[rng.randi() % _named_pool.size()])

func _pick_supply() -> Dictionary:
	if rng.randf() < 0.6:
		var c: Array = FangmootData.CHARM_ORDER
		return {"ctype": "charm", "id": String(c[rng.randi() % c.size()]), "frozen": false}
	var b: Array = FangmootData.BREW_ORDER
	return {"ctype": "brew", "id": String(b[rng.randi() % b.size()]), "frozen": false}


# --------------------------------------------------------------- shop ops
func roll() -> bool:
	if fangs < int(Balance.FANGMOOT_COST_ROLL):
		return false
	fangs -= int(Balance.FANGMOOT_COST_ROLL)
	_roll_tray(true)
	return true

func toggle_freeze(tray_idx: int) -> void:
	if tray_idx >= 0 and tray_idx < tray.size():
		tray[tray_idx]["frozen"] = not bool(tray[tray_idx].get("frozen", false))

func _card_cost(card: Dictionary) -> int:
	match String(card["ctype"]):
		"named": return int(Balance.FANGMOOT_COST_NAMED)
		"token": return int(Balance.FANGMOOT_COST_TOKEN)
		"charm": return int(Balance.FANGMOOT_COST_CHARM)
		"brew": return int(Balance.FANGMOOT_COST_BREW)
	return 99

func can_buy(tray_idx: int) -> bool:
	if tray_idx < 0 or tray_idx >= tray.size():
		return false
	return fangs >= _card_cost(tray[tray_idx])

# Buy a token/named card into a board slot (bond if same kind, else place).
func buy_token(tray_idx: int, slot_idx: int) -> bool:
	if not can_buy(tray_idx):
		return false
	var card := tray[tray_idx] as Dictionary
	if String(card["ctype"]) != "token" and String(card["ctype"]) != "named":
		return false
	if slot_idx < 0 or slot_idx >= board.size():
		return false
	var kind := String(card["id"])
	# Named: only one per warband
	if FangmootData.is_named(kind) and _has_named() and not _is_same_named(slot_idx, kind):
		return false
	var target = board[slot_idx]
	if target == null:
		board[slot_idx] = _new_slot(kind)
	elif String(target["kind"]) == kind:
		_bond(target, _base_slot(kind))
	else:
		return false
	fangs -= _card_cost(card)
	tray.remove_at(tray_idx)
	return true

func buy_charm(tray_idx: int, slot_idx: int) -> bool:
	if not can_buy(tray_idx):
		return false
	var card := tray[tray_idx] as Dictionary
	if String(card["ctype"]) != "charm":
		return false
	if slot_idx < 0 or slot_idx >= board.size() or board[slot_idx] == null:
		return false
	board[slot_idx]["charm"] = String(card["id"])
	fangs -= _card_cost(card)
	tray.remove_at(tray_idx)
	return true

func buy_brew(tray_idx: int, slot_idx: int) -> bool:
	if not can_buy(tray_idx):
		return false
	var card := tray[tray_idx] as Dictionary
	if String(card["ctype"]) != "brew":
		return false
	var brew: Dictionary = FangmootData.BREWS.get(String(card["id"]), {})
	if brew.is_empty():
		return false
	var eff := brew["effect"] as Dictionary
	if String(eff.get("scope", "one")) == "all":
		for s in board:
			if s != null:
				_apply_brew(s, eff)
	else:
		if slot_idx < 0 or slot_idx >= board.size() or board[slot_idx] == null:
			return false
		_apply_brew(board[slot_idx], eff)
	fangs -= _card_cost(card)
	tray.remove_at(tray_idx)
	return true

func sell(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= board.size() or board[slot_idx] == null:
		return false
	fangs += level_of(board[slot_idx])
	board[slot_idx] = null
	return true

func move(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx or from_idx < 0 or to_idx < 0:
		return
	if from_idx >= board.size() or to_idx >= board.size():
		return
	var moving = board[from_idx]
	if moving == null:
		return
	var dest = board[to_idx]
	if dest != null and String(dest["kind"]) == String(moving["kind"]):
		_bond(dest, moving)   # board-to-board bond
		board[from_idx] = null
	else:
		board[from_idx] = dest
		board[to_idx] = moving


# --------------------------------------------------------------- slot maths
func _base_slot(kind: String) -> Dictionary:
	var st := FangmootData.base_stats(kind)
	return {"kind": kind, "copies": 1, "charm": "", "bite": st.x, "hide": st.y, "brew_bite": 0, "brew_ward": 0}

func _new_slot(kind: String) -> Dictionary:
	return _base_slot(kind)

func _bond(slot: Dictionary, incoming: Dictionary) -> void:
	slot["bite"] = maxi(int(slot["bite"]), int(incoming["bite"])) + 1
	slot["hide"] = maxi(int(slot["hide"]), int(incoming["hide"])) + 1
	slot["copies"] = int(slot["copies"]) + int(incoming.get("copies", 1))

func _apply_brew(slot: Dictionary, eff: Dictionary) -> void:
	var stat := String(eff["stat"])
	var val := int(eff["val"])
	var perm := bool(eff.get("perm", false))
	match stat:
		"bite":
			if perm:
				slot["bite"] = int(slot["bite"]) + val
			else:
				slot["brew_bite"] = int(slot.get("brew_bite", 0)) + val
		"hide":
			slot["hide"] = int(slot["hide"]) + val
		"both":
			slot["bite"] = int(slot["bite"]) + val
			slot["hide"] = int(slot["hide"]) + val
		"ward":
			slot["brew_ward"] = int(slot.get("brew_ward", 0)) + val

func _has_named() -> bool:
	for s in board:
		if s != null and FangmootData.is_named(String(s["kind"])):
			return true
	return false

func _is_same_named(slot_idx: int, kind: String) -> bool:
	var s = board[slot_idx]
	return s != null and String(s["kind"]) == kind


# ------------------------------------------------------------- call / fight
func _apply_turn_end() -> void:
	for s in board:
		if s == null:
			continue
		var ab: Dictionary = FangmootData.row(String(s["kind"])).get("ability", {})
		if String(ab.get("trig", "")) != "turn_end":
			continue
		var lvl := level_of(s)
		for op in ab.get("ops", []):
			if String(op.get("fx", "")) != "buff":
				continue
			var v := _lv(op.get("val", 0), lvl)
			if v == 0:
				continue
			var targets := _turn_end_targets(s, String(op.get("tgt", "self")))
			for g in targets:
				var st := String(op.get("stat", "bite"))
				if st == "bite" or st == "both":
					g["bite"] = int(g["bite"]) + v
				if st == "hide" or st == "both":
					g["hide"] = int(g["hide"]) + v

func _turn_end_targets(slot: Dictionary, sel: String) -> Array:
	if sel == "self":
		return [slot]
	if sel.begins_with("rand_ally_tribe:"):
		var tribe := sel.substr("rand_ally_tribe:".length())
		var pool: Array = []
		for s in board:
			if s != null and FangmootData.tribe_of(String(s["kind"])) == tribe:
				pool.append(s)
		if pool.is_empty():
			return []
		return [pool[rng.randi() % pool.size()]]
	return []

# Build the fight band (side spec array) from the current board.
func fight_band() -> Array:
	var band: Array = []
	for s in board:
		if s == null:
			band.append(null)
			continue
		band.append(_slot_to_spec(s))
	return band

func _slot_to_spec(s: Dictionary) -> Dictionary:
	var kind := String(s["kind"])
	var r := FangmootData.row(kind)
	return {
		"kind": kind,
		"name": String(r.get("name", kind)),
		"tribe": String(r.get("tribe", "")),
		"tier": FangmootData.tier_of(kind),
		"bite": int(s["bite"]) + int(s.get("brew_bite", 0)),
		"hide": int(s["hide"]),
		"level": level_of(s),
		"ability": r.get("ability", {}),
		"charm": String(s.get("charm", "")),
		"home_ground": String(r.get("home", "")),
		"start_ward": int(s.get("brew_ward", 0)),
	}

# Run a fight against an opponent band; update crests/scars; advance the turn.
func call_moot(opp_band: Array) -> Dictionary:
	_apply_turn_end()
	var band := fight_band()
	last_band = band
	last_opp = opp_band
	var res := FangmootSim.fight(band, opp_band, seed + turn, ground, want_log)
	last_result = String(res["result"])
	last_log = res["log"]
	_writeback_perm(res.get("perm", [{}, {}])[0])
	_clear_one_fight_brews()
	var sparring := turn <= int(Balance.FANGMOOT_SPARRING_TURNS)
	if last_result == "a":
		crests += 1
	elif last_result == "b" and not sparring:
		scars += 1
	turn += 1
	if crests >= int(Balance.FANGMOOT_CRESTS_WIN):
		done = true
		outcome = "win"
	elif scars >= int(Balance.FANGMOOT_SCARS_OUT):
		done = true
		outcome = "loss"
	elif turn > int(Balance.FANGMOOT_MAX_TURNS):
		done = true
		outcome = "timeout"
	return res

# Advance without a fight (used to build opponent warbands to a given turn).
func advance_no_fight() -> void:
	_apply_turn_end()
	_clear_one_fight_brews()
	turn += 1

func _writeback_perm(perm: Dictionary) -> void:
	for slot_idx in perm:
		var s = board[int(slot_idx)]
		if s == null:
			continue
		var d: Array = perm[slot_idx]
		s["bite"] = int(s["bite"]) + int(d[0])
		s["hide"] = int(s["hide"]) + int(d[1])

func _clear_one_fight_brews() -> void:
	for s in board:
		if s != null:
			s["brew_bite"] = 0
			s["brew_ward"] = 0


# --------------------------------------------------------------- helpers
func board_count() -> int:
	var n := 0
	for s in board:
		if s != null:
			n += 1
	return n

func _lv(v, level: int) -> int:
	if typeof(v) == TYPE_ARRAY:
		return int(v[clampi(level, 1, 3) - 1])
	return int(v)


# --------------------------------------------------------------- serialise
func to_dict() -> Dictionary:
	return {
		"table": table, "seed": seed, "ground": ground, "turn": turn,
		"fangs": fangs, "crests": crests, "scars": scars, "done": done,
		"outcome": outcome, "board": board.duplicate(true), "tray": tray.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	table = String(d.get("table", "copper"))
	seed = int(d.get("seed", 0))
	ground = String(d.get("ground", ""))
	turn = int(d.get("turn", 1))
	fangs = int(d.get("fangs", 0))
	crests = int(d.get("crests", 0))
	scars = int(d.get("scars", 0))
	done = bool(d.get("done", false))
	outcome = String(d.get("outcome", ""))
	board = (d.get("board", []) as Array).duplicate(true)
	if board.size() < _board_size():
		board.resize(_board_size())
	tray = (d.get("tray", []) as Array).duplicate(true)
