extends Node
## PVP BENCH — a MEASURED PvP tier instrument (throwaway, NOT a test tier). The
## duel analog of dps_bench: it derives a class matchup matrix + tier ranking
## from god-roll L100 builds under a candidate set of PvP knobs, then flags the
## degenerate interactions a tier letter hides.
##
## Two layers, kept honestly separate (the dps_bench SCOPE-BOUNDARY rule):
##   MEASURED (hard) — effective HP, rotation-ceiling DPS, opening burst, and
##     sustain-per-second, all computed from the real built stats + kit data at
##     0 defender resistance (god-roll subs carry ~none).
##   JUDGMENT (red-pen) — four hand-scored axes a headless bot can't fake:
##     RANGE (kite control), MOBILITY (gap-close/escape), CC (offensive lockout),
##     DEFWIN (damage-negation uptime). These are the tuning surface; every score
##     cites its kit basis below.
##
## The matchup resolver is transparent: A beats B if A kills B faster than B kills
## A, where realized DPS is shaved by the target's DEFWIN and sustain, and a melee
## attacker into a ranged kiter loses uptime by the MOBILITY gap. No black-box sim
## and no pretense of modelling raw dodging — that stays phase 2 (a duel sim).
##
## LIMITATIONS (first pass, documented): DPS is a mana-blind rotation ceiling and
## UNDER-models buff/stance/DoT-ramp kits (warrior Berserk, paladin stance, warlock
## Hex ramp / Void always-crit spread) — flagged per class. Tiers are meaningless
## in the CURRENT one-shot meta; run this against the PROPOSED durability knobs.
##
## Run:  godot --headless --path game res://scenes/pvp_bench.tscn -- [args]
##   --tough=N   effective-HP multiplier   (default 35, PROPOSALS/PVP_BALANCE.md)
##   --heal=F    PvP healing scalar        (default 0.5)
##   --dmg=F     PvP outgoing damage scalar (default 1.0)

const CLS_ORDER := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]

# ---- JUDGMENT AXES (red-pen surface) — 0..1, cited to the kit --------------
# RANGE: 1.0 = ranged kiter who controls spacing; 0.0 = pure melee.
const RANGE := {
	"warrior": 0.0,   # melee Cleave
	"paladin": 0.0,   # melee Judgment (leaps to reach)
	"assassin": 0.15, # melee Stab, but blink/dash closes gaps
	"archer": 1.0, "mage": 1.0, "warlock": 1.0,   # projectile primaries
}
# MOBILITY: gap-close + escape tools.
const MOBILITY := {
	"assassin": 1.0,  # surge dash (x2 rider) + Mirrorstep, fastest base speed
	"mage": 0.8,      # Blink: iframe + 50% DR cloak
	"archer": 0.6,    # Tumble: iframe + evasion window
	"warrior": 0.5,   # Shield Bash charge (stun + landing iframe)
	"paladin": 0.45,  # Judgment leap (arms every 5s)
	"warlock": 0.15,  # least mobile in the roster
}
# CC: offensive lockout weight (stun/slow now cross the wire, _hit_rival).
const CC := {
	"warrior": 0.70,  # Shield Bash 1.3s stun + knock
	"mage": 0.60,     # Frost Nova slow 50% + knock, Blink shock
	"paladin": 0.50,  # Conviction/Retri chain pull
	"warlock": 0.35,  # Hex expose + curse slow (soft)
	"assassin": 0.30, # Death Mark vuln (no hard stun)
	"archer": 0.20,   # little hard CC
}
# DEFWIN: fraction of incoming damage the class shaves via defensive windows.
const DEFWIN := {
	"paladin": 0.35,  # Aegis guard + plate flat_dr + Conviction-Holy guard
	"warrior": 0.30,  # plate flat_dr + Stonehide grit-res + Berserk
	"mage": 0.30,     # Blink 50% DR ~0.8s / 4.5s + iframe
	"assassin": 0.25, # Elusive eva 15% + Mirrorstep dash-reflect + dash iframes
	"archer": 0.15,   # Tumble evasion window
	"warlock": 0.10,  # Doomward curse_dr only while hexing
}
# KIT_HEAL: discrete/steady kit sustain as a per-second fraction of max HP
# (pre heal-scalar), for heals NOT captured by lifesteal/regen stat fields.
# Paladin's Holy mend is computed from constants instead (see below).
const KIT_HEAL := {
	"mage": 0.014,    # Frost Nova restore (situational, avg missing)
	"archer": 0.012,  # Second Wind (windward 1.5s)
	"warrior": 0.015, # Grit regen
	"assassin": 0.10, # blood-surge lifesteal (surges big when low; not in base ls)
	"warlock": 0.05,  # Dark Pact 25% + drain
	"paladin": 0.0,   # computed from PALADIN_HOLY_MEND below
}

# PvP MELEE-RES GRANT (the League melee/ranged comp) — bonus physres+magres in
# duels, scaled by how much a class must EAT poke to close: bruisers who walk in
# get the most, the gap-close+iframe assassin a token, ranged pokers none.
# Applied on top of any built res; res_frac(90)~0.43 -> ~43% less poke.
const MELEE_RES := {
	"warrior": 90.0, "paladin": 90.0, "assassin": 0.0,
	"archer": 0.0, "mage": 0.0, "warlock": 0.0,
}

# Kit-facing burst window for the opening-delete check (seconds).
const BURST_WINDOW := 2.0

var game: Game
var tough := 35.0
var heal_mult := 1.0   # PvP healing NOT nerfed (owner 2026-08-06); --heal overrides
var dmg_mult := 1.0
var meleeres := 1.0   # --meleeres: scales the MELEE_RES grant (0 = off)


func _ready() -> void:
	_parse_args()
	Story.load_content()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_opening()

	var m := {}
	for cls in CLS_ORDER:
		m[cls] = _metrics(cls)
	_report(m)
	get_tree().quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("--tough="):
			tough = maxf(1.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--heal="):
			heal_mult = maxf(0.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--dmg="):
			dmg_mult = maxf(0.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--meleeres="):
			meleeres = maxf(0.0, float(a.get_slice("=", 1)))


## Build the perfect100 god-roll for `cls`, then read the MEASURED PvP metrics.
func _metrics(cls: String) -> Dictionary:
	var p: Player = game.player
	var tid: String = String(BenchBuild.DEFAULT_THEME[cls])
	p.level = 100
	p.resonance = 0.0
	p.set_class(cls)
	p.set_all_themes(tid)
	p.tree_points = BenchBuild.preset_lookup(BenchBuild.TREE_PRESETS, cls, tid).duplicate()
	p.skill_points = 0
	for attr in p.attr_points:
		p.attr_points[attr] = 0
	p.attr_points[String(Classes.CLASSES[cls]["primary"])] = 99
	p.unspent_attr = 0
	var cfg := {"grade": "S", "gemlvl": 10, "plus": 20, "godroll": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = BenchBuild.GEAR_SEED
	p.equipment = BenchBuild.equip_dict(cls, tid, cfg, rng)
	p._update_weapon_visual()
	p.recalc()
	p.hp = p.max_hp
	p.mp = p.max_mp

	var catk := p.current_atk()
	var eff_crit: float = Stats.crit_curve(p.crit)
	var xmult := 1.0 + eff_crit * (p.crit_dmg - 1.0)   # expected crit factor
	var abilities: Dictionary = Classes.CLASSES[cls]["abilities"]

	# Effective HP: the inflated pool, plus plate flat_dr folded in (res ~0).
	var ehp := p.max_hp * tough / maxf(0.05, 1.0 - p.flat_dr)

	# Per-slot amortized DPS (rotation ceiling, mana-blind).
	var a1_dps := _slot_dps(abilities, "a1", catk, xmult, p.crit_dmg, p.cdr, p.combo, false)
	var dps := a1_dps
	for slot in ["a2", "a3", "ult"]:
		var always_crit: bool = cls == "warlock" and slot == "ult"  # Void always-crits cursed
		dps += _slot_dps(abilities, slot, catk, xmult, p.crit_dmg, p.cdr, p.combo, always_crit)
	# Warrior Berserk: no direct damage — an amortized +40% dmg / 15% ls buff.
	var berserk_ls := 0.0
	if cls == "warrior":
		var up: float = 8.0 / 40.0
		dps *= 1.0 + 0.40 * up
		berserk_ls = 0.15 * up
	dps *= dmg_mult

	# Opening burst (BURST_WINDOW s): the ult's direct hit + a1 spam in the window.
	# Channelled ults (Arrow Storm, "secs") land only their in-window fraction —
	# a 3s rain is sustained pressure, not an instant delete.
	var burst := a1_dps * BURST_WINDOW   # a1 contribution already amortized
	var ult: Dictionary = abilities.get("ult", {})
	if ult.get("dmg", {}).has("coeff"):
		var always_crit: bool = cls == "warlock"
		var ub: float = _cast_dmg(ult["dmg"], catk, xmult, p.crit_dmg, always_crit)
		var usecs := float(ult["dmg"].get("secs", 0.0))
		if usecs > 0.0:
			ub *= clampf(BURST_WINDOW / usecs, 0.0, 1.0)
		burst += ub
	burst *= dmg_mult

	# Sustain per second (post heal-scalar): lifesteal on realized dps + regen +
	# kit heals; paladin Holy mend computed from its per-hit constant.
	var ls: float = p.lifesteal + berserk_ls + (KIT_HEAL["assassin"] if cls == "assassin" else 0.0)
	var kit_heal: float = float(KIT_HEAL.get(cls, 0.0)) * p.max_hp
	if cls == "assassin":
		kit_heal = 0.0   # folded into ls above
	if cls == "paladin":
		var a1_cd: float = maxf(0.05, float(abilities["a1"]["cd"]) * (1.0 - p.cdr))
		kit_heal += Balance.PALADIN_HOLY_MEND * p.max_hp / a1_cd
	var heal_s: float = (ls * dps + p.regen_pct * p.max_hp + kit_heal) * heal_mult

	return {
		"cls": cls, "ehp": ehp, "dps": dps, "burst": burst, "heal_s": heal_s,
		"range": float(RANGE[cls]), "mob": float(MOBILITY[cls]),
		"cc": float(CC[cls]), "defwin": float(DEFWIN[cls]),
		"res_dr": Stats.res_frac(float(MELEE_RES[cls]) * meleeres),
		"max_hp": p.max_hp, "catk": catk, "crit": eff_crit,
	}


## Amortized DPS of one ability slot (dmg / effective cooldown).
func _slot_dps(ab: Dictionary, slot: String, catk: float, xmult: float,
		crit_dmg: float, cdr: float, combo: float, always_crit: bool) -> float:
	var d: Dictionary = ab.get(slot, {})
	if not d.get("dmg", {}).has("coeff"):
		return 0.0
	var dmg: float = _cast_dmg(d["dmg"], catk, xmult, crit_dmg, always_crit)
	var cd := float(d["cd"])
	if slot != "ult":
		cd *= 1.0 - cdr                       # ults ignore haste
	cd = maxf(0.05, cd)
	var rate := 1.0 / cd
	if slot == "a1":
		rate /= maxf(0.4, 1.0 - combo)        # combo refunds the basic (soft-floored)
	return dmg * rate


## Expected damage of one cast at 0 defender resistance.
func _cast_dmg(dd: Dictionary, catk: float, xmult: float, crit_dmg: float,
		always_crit: bool) -> float:
	var coeff := float(dd.get("coeff", 0.0))
	var hits := float(dd.get("hits", 1))
	var tf := float(dd.get("true_frac", 0.0))
	if String(dd.get("type", "")) == "true":
		tf = 1.0
	var base := catk * coeff * hits
	var mult: float = crit_dmg if always_crit else xmult
	return base * ((1.0 - tf) * mult + tf)   # true slice never crits


## Melee attacker A's damage uptime into defender B (kite gap by MOBILITY).
func _uptime(a: Dictionary, b: Dictionary) -> float:
	if float(a["range"]) >= 0.8:
		return 1.0                             # A controls spacing
	if float(b["range"]) < 0.8:
		return 1.0                             # both melee — neutral
	return clampf(0.40 + 0.5 * (float(a["mob"]) - float(b["mob"])), 0.25, 1.0)


## Net DPS A lands on B (uptime, B's defensive windows, B's sustain). Returns the
## time-to-kill (INF if B out-sustains A).
func _ttk(a: Dictionary, b: Dictionary) -> float:
	var eff := float(a["dps"]) * _uptime(a, b) * (1.0 - float(b["defwin"])) \
		* (1.0 - float(b["res_dr"]))
	var net := eff - float(b["heal_s"])
	if net <= 0.0:
		return INF
	return float(b["ehp"]) / net


func _report(m: Dictionary) -> void:
	print("")
	print("=====================================================================")
	print(" PVP BENCH — derived tiers @ tough %.0f  heal %.2f  dmg %.2f  meleeres %.2f" % [
		tough, heal_mult, dmg_mult, meleeres])
	print("=====================================================================")
	print("")
	print("MEASURED metrics (0-res target):")
	print("%-9s %8s %8s %8s %8s   range mob  cc  def  pokeDR" % [
		"class", "EHP", "DPS", "burst", "heal/s"])
	for cls in CLS_ORDER:
		var r: Dictionary = m[cls]
		print("%-9s %8.0f %8.0f %8.0f %8.0f    %.2f %.2f %.2f %.2f  %3.0f%%" % [
			cls, r["ehp"], r["dps"], r["burst"], r["heal_s"],
			r["range"], r["mob"], r["cc"], r["defwin"], float(r["res_dr"]) * 100.0])

	print("")
	print("MATCHUP MATRIX — time-to-kill (s) that ROW inflicts on COLUMN")
	print("  lower = row kills column faster;  INF = column out-sustains row")
	var header := "%-9s" % "atk\\def"
	for d in CLS_ORDER:
		header += "%9s" % d
	print(header)
	var wins := {}
	var flags := []
	for a in CLS_ORDER:
		wins[a] = 0.0
	for a in CLS_ORDER:
		var line := "%-9s" % a
		for d in CLS_ORDER:
			if a == d:
				line += "%9s" % "-"
				continue
			var t := _ttk(m[a], m[d])
			line += "%9s" % ("INF" if t == INF else "%.1f" % t)
		print(line)

	# Score: for each ordered pair, the faster killer banks a win weighted by margin.
	print("")
	print("DERIVED TIERS (win share across the 5 matchups, margin-weighted):")
	var score := {}
	for a in CLS_ORDER:
		score[a] = 0.0
	for a in CLS_ORDER:
		for d in CLS_ORDER:
			if a == d:
				continue
			var ta := _ttk(m[a], m[d])
			var td := _ttk(m[d], m[a])
			if ta == INF and td == INF:
				continue
			if td == INF or (ta != INF and ta < td):
				score[a] += 1.0 + clampf((td - ta) / maxf(0.1, td) if td != INF else 1.0, 0.0, 1.0)
	var ranked: Array = CLS_ORDER.duplicate()
	ranked.sort_custom(func(x, y): return float(score[x]) > float(score[y]))
	var rank := 1
	for cls in ranked:
		var letter := "S" if rank <= 1 else ("A" if rank <= 3 else ("B" if rank <= 5 else "C"))
		print("  %s  %-9s  score %.2f" % [letter, cls, score[cls]])
		rank += 1

	# Degenerate-interaction flags — what a tier letter hides.
	print("")
	print("DEGENERATE FLAGS (what the letters hide):")
	for a in CLS_ORDER:
		for d in CLS_ORDER:
			if a == d:
				continue
			var t_ad := _ttk(m[a], m[d])
			if t_ad == INF:
				flags.append("  SUSTAIN LOCK: %s cannot kill %s (out-sustained)" % [a, d])
				continue   # a sustain lock already tells the story; no kite double-report
			# kite lock: melee A into ranged B with heavy uptime loss AND slow kill
			if float(m[a]["range"]) < 0.8 and float(m[d]["range"]) >= 0.8:
				var up := _uptime(m[a], m[d])
				if up <= 0.5 and t_ad > 12.0:
					flags.append("  KITE LOCK: %s (melee) struggles to pin %s (uptime %.0f%%, TTK %.1fs)" % [
						a, d, up * 100.0, t_ad])
	if flags.is_empty():
		print("  (none)")
	else:
		for f in flags:
			print(f)
	print("")
	print("NOTE: DPS is a mana-blind rotation ceiling; warrior(Berserk buff),")
	print("paladin(Holy stance — retri is +56% dmg / no mend) and warlock(DoT ramp,")
	print("Void always-crit spread) are UNDER-modeled. Axis scores are the red-pen")
	print("surface. Validate marquee cells with a phase-2 duel sim before trusting.")
	print("PVP BENCH DONE")


func a_of(m: Dictionary, cls: String) -> Dictionary:
	return m[cls]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _skip_opening() -> void:
	await _frames(3)
	var guard := 0
	while guard < 200:
		if game.hud.choices_active:
			game.hud._choose(0)
		elif game.hud.dialogue_active:
			game.hud._advance_dialogue()
		else:
			break
		await _frames(1)
		guard += 1
	await _frames(5)
