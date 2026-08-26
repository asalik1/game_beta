class_name FangmootBench
extends RefCounted
## Fangmoot balance bench. PROPOSALS/FANGMOOT.md §14/§15. Not a test tier — a
## balance instrument (the dps_bench pattern). Runs N bot-driven moots, each
## turn facing a pre-built opponent warband, and reports per-token fielded win
## rate, per-tribe win rate, moot/fight length distributions, draw rate, and
## Named presence in winning bands. Run before every tuning change.
##
## Self-contained on FangmootData + sim + moot + bot with the stub host
## (everything fieldable), so it needs no booted game.

const POOL_K := 24   # opponent warbands pre-built per turn

static func run(n := 2000, seed := 12345, table := "silver") -> String:
	var host := FangmootHost.new()
	var personas: Array = FangmootData.CALLERS.values()
	# pre-build opponent pool: turn -> [band]
	var pool := {}
	var max_turn := int(Balance.FANGMOOT_MAX_TURNS)
	for turn in range(1, max_turn + 1):
		var bands: Array = []
		for k in POOL_K:
			var persona: Dictionary = personas[(turn * 7 + k * 13) % personas.size()]
			bands.append(FangmootBot.build_warband(persona, turn, seed + turn * 101 + k * 991, host))
		pool[turn] = bands

	# tallies (win rate is measured over DECISIVE fights — draws excluded — so
	# it centres on 50%; a token in a drawn fight counts as an appearance only)
	var appear := {}          # kind -> fights fielded
	var wins := {}            # kind -> fights its side won
	var decisive := {}        # kind -> fights that were not draws
	var tribe_appear := {}
	var tribe_wins := {}
	var tribe_dec := {}
	var moot_len := {}        # turns-to-finish histogram
	var fight_len: Array = []  # strike counts
	var draws := 0
	var fights := 0
	var over60 := 0
	var named_win := 0
	var named_total := 0
	var outcomes := {"win": 0, "loss": 0, "timeout": 0}

	var brng := RandomNumberGenerator.new()
	for i in n:
		var m := FangmootMoot.new(table, seed + i * 7919, host)
		m.want_log = false  # bench doesn't render the fight; skip log allocation
		m.ground = FangmootData.GROUND_ORDER[i % FangmootData.GROUND_ORDER.size()]  # cover all 14
		var player: Dictionary = personas[i % personas.size()]
		brng.seed = (seed + i * 7919) ^ 0x2545F491
		while not m.done:
			m.begin_turn()
			FangmootBot.take_turn(m, player, brng)
			var opp: Array = pool[clampi(m.turn, 1, max_turn)][(i + m.turn) % POOL_K]
			var my_band := m.fight_band()
			var res := m.call_moot(opp)
			fights += 1
			var strikes := int(res["strikes"])
			fight_len.append(strikes)
			if strikes > 60:
				over60 += 1
			var r := String(res["result"])
			if r == "draw":
				draws += 1
			_tally(my_band, r, "a", appear, wins, decisive, tribe_appear, tribe_wins, tribe_dec)
			_tally(opp, r, "b", appear, wins, decisive, tribe_appear, tribe_wins, tribe_dec)
			# Named presence in winning bands
			var win_band = my_band if r == "a" else (opp if r == "b" else [])
			if r != "draw":
				var has_named := false
				for spec in win_band:
					if spec != null and FangmootData.is_named(String(spec.get("kind", ""))):
						has_named = true
				if has_named:
					named_win += 1
		moot_len[m.turn] = int(moot_len.get(m.turn, 0)) + 1
		outcomes[m.outcome] = int(outcomes.get(m.outcome, 0)) + 1

	return _report(n, table, appear, wins, decisive, tribe_appear, tribe_wins, tribe_dec,
		moot_len, fight_len, draws, fights, over60, named_win, outcomes)


static func _tally(band: Array, result: String, my_side: String, appear: Dictionary,
		wins: Dictionary, decisive: Dictionary, tribe_appear: Dictionary,
		tribe_wins: Dictionary, tribe_dec: Dictionary) -> void:
	var won := result == my_side
	var draw := result == "draw"
	for spec in band:
		if spec == null:
			continue
		var kind := String(spec.get("kind", ""))
		if kind == "":
			continue
		appear[kind] = int(appear.get(kind, 0)) + 1
		var tribe := String(spec.get("tribe", ""))
		tribe_appear[tribe] = int(tribe_appear.get(tribe, 0)) + 1
		if not draw:
			decisive[kind] = int(decisive.get(kind, 0)) + 1
			tribe_dec[tribe] = int(tribe_dec.get(tribe, 0)) + 1
			if won:
				wins[kind] = int(wins.get(kind, 0)) + 1
				tribe_wins[tribe] = int(tribe_wins.get(tribe, 0)) + 1


static func _report(n: int, table: String, appear: Dictionary, wins: Dictionary,
		decisive: Dictionary, tribe_appear: Dictionary, tribe_wins: Dictionary,
		tribe_dec: Dictionary, moot_len: Dictionary,
		fight_len: Array, draws: int, fights: int, over60: int, named_win: int,
		outcomes: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("=== FANGMOOT BENCH  n=%d  table=%s  fights=%d ===" % [n, table, fights])
	var draw_pct := 100.0 * draws / maxi(1, fights)
	out.append("draws: %.1f%%   fights>60 strikes: %d (%.2f%%)" % [draw_pct, over60, 100.0 * over60 / maxi(1, fights)])
	# fight length
	var fl := fight_len.duplicate()
	fl.sort()
	if not fl.is_empty():
		out.append("fight strikes: min=%d  median=%d  p99=%d  max=%d" % [
			fl[0], fl[fl.size() / 2], fl[mini(fl.size() - 1, int(fl.size() * 0.99))], fl[fl.size() - 1]])
	# moot length + outcomes
	var lens := moot_len.keys()
	lens.sort()
	var ml_str := ""
	var total_turns := 0
	for t in lens:
		ml_str += "%d:%d " % [t, moot_len[t]]
		total_turns += int(t) * int(moot_len[t])
	out.append("moot length (turns:count): %s" % ml_str)
	out.append("mean moot length: %.1f turns   outcomes win/loss/timeout: %d/%d/%d" % [
		float(total_turns) / maxi(1, n), int(outcomes.get("win", 0)), int(outcomes.get("loss", 0)), int(outcomes.get("timeout", 0))])
	out.append("named presence in winning bands: %.1f%%" % [100.0 * named_win / maxi(1, fights - draws)])
	# per-tribe win rate (decisive fights; target ~50%, flag outside 46-54)
	out.append("--- tribe win rate, decisive (target ~50%, flag outside 46-54) ---")
	for tribe in FangmootData.TRIBE_ORDER:
		var dec := int(tribe_dec.get(tribe, 0))
		if dec == 0:
			continue
		var wr := 100.0 * int(tribe_wins.get(tribe, 0)) / dec
		var flag := "  <-- FLAG" if (wr < 46.0 or wr > 54.0) else ""
		out.append("  %-7s %5.1f%%  (n=%d)%s" % [tribe, wr, dec, flag])
	# per-token win rate, grouped by tier, flag outside 40-60
	out.append("--- token fielded win rate by tier (flag outside 40-60) ---")
	var by_tier := {}
	for kind in FangmootData.TOKENS:
		var tk := int(FangmootData.TOKENS[kind]["tier"])
		if not by_tier.has(tk):
			by_tier[tk] = []
		by_tier[tk].append(kind)
	for kind in FangmootData.NAMED:
		if not by_tier.has(6):
			by_tier[6] = []
		by_tier[6].append(kind)
	var tiers := by_tier.keys()
	tiers.sort()
	var flagged := 0
	for tier in tiers:
		out.append("  -- tier %s --" % ("Named" if tier == 6 else str(tier)))
		var kinds: Array = by_tier[tier]
		kinds.sort_custom(func(a, b): return FangmootBench._wr(a, decisive, wins) > FangmootBench._wr(b, decisive, wins))
		for kind in kinds:
			var dec := int(decisive.get(kind, 0))
			var wr := _wr(kind, decisive, wins)
			var flag := ""
			if dec >= 30 and (wr < 40.0 or wr > 60.0):
				flag = "  <-- FLAG"
				flagged += 1
			out.append("    %-18s %5.1f%%  (n=%d)%s" % [kind, wr, dec, flag])
	out.append("=== flagged tokens (decisive win rate outside 40-60): %d ===" % flagged)
	return "\n".join(out)


static func _wr(kind: String, decisive: Dictionary, wins: Dictionary) -> float:
	var dec := int(decisive.get(kind, 0))
	return 100.0 * int(wins.get(kind, 0)) / dec if dec > 0 else 0.0
