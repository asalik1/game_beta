class_name FangmootBot
extends RefCounted
## The persona shopper. PROPOSALS/FANGMOOT.md §8. Drives a FangmootMoot's shop
## ops for an AI caller, and builds an opponent warband to a given turn.
##
## A persona (from FangmootData.CALLERS): {bias:[tribe], greed, front_rule,
## bond_love, noise}. noise is the table knob (Copper 0.5 random / no rolls,
## Silver 0.2, Gold 0.05). Bots never peek at the player's board.

# Play one shop turn: buy, bond, maybe roll, then arrange by the front rule.
static func take_turn(m: FangmootMoot, persona: Dictionary, brng: RandomNumberGenerator) -> void:
	var noise := float(persona.get("noise", 0.3))
	var greed := float(persona.get("greed", 0.4))
	var can_roll := noise <= 0.25
	var guard := 40
	while guard > 0:
		guard -= 1
		# noise: sometimes take a random affordable card
		if brng.randf() < noise:
			if _buy_random(m, brng):
				continue
		var best := _best_token(m, persona)
		if best >= 0 and m.can_buy(best):
			if _buy_into_best_slot(m, best, persona, brng):
				continue
		# spare fangs on a charm for the strongest token
		if _maybe_buy_charm(m, brng):
			continue
		# roll when the tray is weak and greed permits
		if can_roll and m.fangs > int(Balance.FANGMOOT_COST_ROLL) and best < 0 and brng.randf() < greed:
			if m.roll():
				continue
		break
	_arrange(m, persona)


# ---- opponent warband built to a given turn (for per-turn matchmaking) ----
static func build_warband(persona: Dictionary, turns: int, seed: int, host: FangmootHost) -> Array:
	var m := FangmootMoot.new("silver", seed, host)
	var brng := RandomNumberGenerator.new()
	brng.seed = seed ^ 0x9E3779B9
	for t in range(1, maxi(1, turns) + 1):
		m.begin_turn()
		take_turn(m, persona, brng)
		m.advance_no_fight()
	return m.fight_band()


# --------------------------------------------------------------- scoring
static func _score(m: FangmootMoot, kind: String, persona: Dictionary) -> float:
	var s := float(FangmootData.tier_of(kind))
	var tribe := FangmootData.tribe_of(kind)
	if tribe in persona.get("bias", []):
		s *= 1.6
	# tribe synergy: abilities reference tribe tags, so more same-tribe = better
	var same := 0
	var owns_copy := false
	for slot in m.board:
		if slot == null:
			continue
		if FangmootData.tribe_of(String(slot["kind"])) == tribe:
			same += 1
		if String(slot["kind"]) == kind:
			owns_copy = true
	s *= 1.0 + 0.12 * same
	if owns_copy:
		s *= 1.0 + float(persona.get("bond_love", 0.5))
	return s

static func _best_token(m: FangmootMoot, persona: Dictionary) -> int:
	var best := -1
	var best_s := 0.0
	for i in m.tray.size():
		var card := m.tray[i] as Dictionary
		var ct := String(card["ctype"])
		if ct != "token" and ct != "named":
			continue
		if not m.can_buy(i):
			continue
		var kind := String(card["id"])
		if FangmootData.is_named(kind) and m._has_named() and not _owns(m, kind):
			continue
		var sc := _score(m, kind, persona)
		if sc > best_s:
			best_s = sc
			best = i
	return best


# --------------------------------------------------------------- buying
static func _buy_into_best_slot(m: FangmootMoot, tray_idx: int, persona: Dictionary, brng: RandomNumberGenerator) -> bool:
	var kind := String(m.tray[tray_idx]["id"])
	# bond onto an existing copy if we have one
	var copy_slot := _slot_of(m, kind)
	if copy_slot >= 0:
		return m.buy_token(tray_idx, copy_slot)
	# else an empty slot
	var empty := _empty_slot(m)
	if empty >= 0:
		return m.buy_token(tray_idx, empty)
	# board full: replace our weakest if this is clearly better
	var weak := _weakest_slot(m)
	if weak >= 0 and _score(m, kind, persona) > _slot_strength(m, weak) * 1.15:
		m.sell(weak)
		return m.buy_token(tray_idx, weak)
	return false

static func _buy_random(m: FangmootMoot, brng: RandomNumberGenerator) -> bool:
	var affordable: Array = []
	for i in m.tray.size():
		if m.can_buy(i):
			affordable.append(i)
	if affordable.is_empty():
		return false
	var idx := int(affordable[brng.randi() % affordable.size()])
	var ct := String(m.tray[idx]["ctype"])
	if ct == "token" or ct == "named":
		var kind := String(m.tray[idx]["id"])
		if FangmootData.is_named(kind) and m._has_named() and not _owns(m, kind):
			return false
		var slot := _slot_of(m, kind)
		if slot < 0:
			slot = _empty_slot(m)
		if slot < 0:
			return false
		return m.buy_token(idx, slot)
	elif ct == "charm":
		var s := _front_slot(m)
		return m.buy_charm(idx, s) if s >= 0 else false
	else:
		var s2 := _front_slot(m)
		return m.buy_brew(idx, s2) if s2 >= 0 else false

static func _maybe_buy_charm(m: FangmootMoot, brng: RandomNumberGenerator) -> bool:
	if m.fangs < int(Balance.FANGMOOT_COST_CHARM):
		return false
	for i in m.tray.size():
		if String(m.tray[i]["ctype"]) != "charm":
			continue
		if not m.can_buy(i):
			continue
		var s := _strongest_uncharmed(m)
		if s >= 0 and brng.randf() < 0.5:
			return m.buy_charm(i, s)
	return false


# --------------------------------------------------------------- arrange
static func _arrange(m: FangmootMoot, persona: Dictionary) -> void:
	var slots: Array = []
	for s in m.board:
		if s != null:
			slots.append(s)
	var rule := String(persona.get("front_rule", "high_hide"))
	slots.sort_custom(func(a, b): return FangmootBot._front_key(a, rule) > FangmootBot._front_key(b, rule))
	for i in m.board.size():
		m.board[i] = slots[i] if i < slots.size() else null

static func _front_key(slot: Dictionary, rule: String) -> float:
	var kind := String(slot["kind"])
	var hide := float(slot["hide"])
	var ab: Dictionary = FangmootData.row(kind).get("ability", {})
	var trig := String(ab.get("trig", ""))
	match rule:
		"martyrs":
			# fall/ally_falls tokens want the front so they trigger sooner
			if trig == "fall" or trig == "ally_falls":
				return 1000.0 + hide
			return hide
		"growers_rear":
			# growth (turn_end/perm) tokens want the rear (lowest key)
			if trig == "turn_end" or _is_grower(ab):
				return -1000.0 + hide
			return hide
		"walls", "high_hide", "balanced", _:
			return hide

static func _is_grower(ab: Dictionary) -> bool:
	for op in ab.get("ops", []):
		if bool(op.get("perm", false)):
			return true
	return false


# --------------------------------------------------------------- board query
static func _owns(m: FangmootMoot, kind: String) -> bool:
	return _slot_of(m, kind) >= 0

static func _slot_of(m: FangmootMoot, kind: String) -> int:
	for i in m.board.size():
		if m.board[i] != null and String(m.board[i]["kind"]) == kind:
			return i
	return -1

static func _empty_slot(m: FangmootMoot) -> int:
	for i in m.board.size():
		if m.board[i] == null:
			return i
	return -1

static func _front_slot(m: FangmootMoot) -> int:
	for i in m.board.size():
		if m.board[i] != null:
			return i
	return -1

static func _slot_strength(m: FangmootMoot, i: int) -> float:
	var s = m.board[i]
	return float(s["bite"]) + float(s["hide"]) if s != null else 0.0

static func _weakest_slot(m: FangmootMoot) -> int:
	var weak := -1
	var weak_s := 1e9
	for i in m.board.size():
		if m.board[i] == null:
			continue
		var st := _slot_strength(m, i)
		if st < weak_s:
			weak_s = st
			weak = i
	return weak

static func _strongest_uncharmed(m: FangmootMoot) -> int:
	var best := -1
	var best_s := -1.0
	for i in m.board.size():
		var s = m.board[i]
		if s == null or String(s.get("charm", "")) != "":
			continue
		var st := _slot_strength(m, i)
		if st > best_s:
			best_s = st
			best = i
	return best
