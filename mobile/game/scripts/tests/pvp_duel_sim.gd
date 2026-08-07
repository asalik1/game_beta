extends Node
## PVP DUEL SIM — phase-2 validator for the derived tiers (pvp_bench). Throwaway
## balance instrument, NOT a test tier.
##
## A 1D time-stepped duel: two god-roll L100 heroes on a bounded line (the real
## ~1300px arena width), REAL stats (current_atk / crit / cdr / lifesteal / speed
## / flat_dr, read off the built Player), a compact per-class kit model, and a
## scripted bot policy (kite / close / gap-close / escape-CD / rotation). Crits,
## dodges and terrain are rolled per tick; every ordered pairing runs R times and
## the win rate falls out. This REPLACES pvp_bench's hand-scored RANGE/MOBILITY
## uptime heuristics with emergent spacing — the bounded arena means kiting is
## finite, the one thing the analytic matrix could not see.
##
## HONEST ABSTRACTIONS (documented): 1D positioning (no real projectile geometry
## or AoE overlap), a LEAN kit (the 3-4 duel-decisive abilities per class, not
## every rider), a bot that dodges only via i-frame windows (not skill-reads), and
## the paladin locked to HOLY stance. It is a VALIDATOR of the matrix's structural
## reads (kite locks, sustain locks), not a substitute for real playtesting.
##
## Run: godot --headless --path game res://scenes/pvp_duel_sim.tscn -- [args]
##   --tough=N --heal=F --dmg=F   (defaults 35 / 0.5 / 1.0, PROPOSALS/PVP_BALANCE.md)
##   --reps=N (default 201)   --cls=X (only pairings touching X)

const CLS_ORDER := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]
const RANGED := {"archer": true, "mage": true, "warlock": true}

const SPEED := {"warrior": 250.0, "archer": 265.0, "mage": 255.0,
	"assassin": 275.0, "paladin": 248.0, "warlock": 258.0}

# PvP MELEE-RES GRANT (League melee/ranged comp): bonus physres+magres in duels,
# scaled by how much a class must eat poke to close. True damage still bypasses.
const MELEE_RES := {
	"warrior": 90.0, "paladin": 90.0, "assassin": 0.0,
	"archer": 0.0, "mage": 0.0, "warlock": 0.0,
}

# The "1 dex gem every player is expected to carry" floor (owner 2026-08-07):
# ~52 dex = one Amber. It's BELOW the graze threshold, so the baseline does NOT
# counter eva (eva stays viable) — countering takes a real, dedicated investment
# (graze ~2 gems, full cancel ~4). Attacker dex is max(built dex, this).
const BASELINE_DEX := 52.0

const ARENA_LEN := 1300.0   # ROOM_W 2112 x room_scale 0.62 playable width
const START_DIST := 720.0
const MELEE := 85.0          # melee reach
const DT := 0.05             # 20 Hz
const T_MAX := 45.0          # kite-stalemate cutoff -> higher HP% wins

# ---- LEAN kit model: the 3-4 duel-decisive abilities per class -------------
# kind: atk | gap | esc | buff.  coeff 0 = no damage.  rng = effect/attack reach
# (gap: max gap it closes; esc: dash distance).  Fields default 0/false.
const KIT := {
	"warrior": [
		{"n": "Cleave",     "k": "atk", "coeff": 1.0, "cd": 0.74, "mp": 0.5, "rng": MELEE},
		{"n": "Whirlwind",  "k": "atk", "coeff": 1.0, "cd": 8.0,  "mp": 15,  "rng": 95.0},
		{"n": "ShieldBash", "k": "gap", "coeff": 1.3, "cd": 4.5,  "mp": 10,  "rng": 320.0,
			"moveto": true, "stun": 1.3, "iframe": 0.45},
		{"n": "Berserk",    "k": "buff","cd": 40.0, "mp": 40, "buff_dmg": 0.40,
			"buff_spd": 0.25, "buff_ls": 0.15, "buff_dur": 8.0},
	],
	"archer": [
		{"n": "QuickShot", "k": "atk", "coeff": 0.85, "cd": 0.36, "mp": 0.5, "rng": 520.0},
		{"n": "Multishot", "k": "atk", "coeff": 0.55, "hits": 5, "cd": 5.0, "mp": 12, "rng": 480.0},
		{"n": "ArrowStorm","k": "atk", "coeff": 0.8, "hits": 10, "cd": 40.0, "mp": 20, "rng": 340.0},
		{"n": "Tumble",    "k": "esc", "cd": 6.0, "mp": 0, "moveaway": 260.0, "iframe": 0.4},
	],
	"mage": [
		{"n": "Firebolt", "k": "atk", "coeff": 1.5, "cd": 0.45, "mp": 3, "rng": 520.0},
		{"n": "FrostNova","k": "atk", "coeff": 1.4, "cd": 7.0, "mp": 15, "rng": 150.0,
			"slow": 0.5, "slow_dur": 2.0, "heal": 0.10, "knock": 230.0},
		{"n": "Meteor",   "k": "atk", "coeff": 10.0, "truef": 0.25, "cd": 44.0, "mp": 40, "rng": 520.0},
		{"n": "Blink",    "k": "esc", "coeff": 0.8, "cd": 4.5, "mp": 10, "rng": 200.0,
			"moveaway": 240.0, "iframe": 0.1, "dr": 0.5, "dr_dur": 0.8},
	],
	"assassin": [
		{"n": "Stab", "k": "atk", "coeff": 1.2, "cd": 0.3, "mp": 0, "rng": 95.0,
			"ls_bonus": 0.20, "ls_dur": 4.0},
		{"n": "Fan",  "k": "atk", "coeff": 0.16, "hits": 3, "cd": 0.3, "mp": 0, "rng": 220.0},
		{"n": "DeathMark", "k": "atk", "coeff": 1.3, "truef": 1.0, "cd": 30.0, "mp": 0, "rng": 360.0,
			"moveto": true, "iframe": 0.8, "amp": 0.5, "amp_dur": 5.0, "exec": true},
		{"n": "Dash", "k": "gap", "cd": 3.0, "mp": 0, "rng": 420.0, "moveto": true, "iframe": 0.2},
	],
	"paladin": [
		{"n": "Judgment", "k": "atk", "coeff": 1.0, "cd": 0.8, "mp": 1, "rng": 95.0, "mend": 0.01},
		{"n": "Consecration", "k": "atk", "coeff": 0.9, "hits": 2, "cd": 8.0, "mp": 15, "rng": 120.0, "heal": 0.03},
		{"n": "Conviction",   "k": "atk", "coeff": 2.2, "cd": 8.0, "mp": 30, "rng": 150.0,
			"heal": 0.10, "dr": 0.3, "dr_dur": 2.0},
		{"n": "Leap", "k": "gap", "cd": 5.0, "mp": 0, "rng": 380.0, "moveto": true, "iframe": 0.2},
	],
	"warlock": [
		{"n": "Shadowbolt", "k": "atk", "coeff": 0.5, "cd": 0.5, "mp": 1, "rng": 520.0},
		{"n": "Hex", "k": "atk", "coeff": 1.5, "cd": 7.0, "mp": 16, "rng": 420.0,
			"amp": 0.2, "amp_dur": 6.0, "dot": 0.35, "dot_dur": 6.0},
		{"n": "VoidRift", "k": "atk", "coeff": 6.5, "cd": 50.0, "mp": 35, "rng": 380.0, "always_crit": true},
		{"n": "DarkPact", "k": "buff", "cd": 8.0, "mp": 0, "buff_ls": 0.25, "buff_dur": 5.0},
	],
}

var game: Game
var tough := 35.0
var heal_mult := 1.0   # PvP healing NOT nerfed (owner 2026-08-06); --heal overrides
var dmg_mult := 1.0
var reps := 201
var only_cls := ""
var meleeres := 1.0   # --meleeres: scales the MELEE_RES grant (0 = off)
# --gems: "dps" = the god-roll DPS sockets (default); "pvp" = role-aware — bruisers
# re-gem sustain+res (Vampire Eye / Onyx / Lapis), attackers all-in pen.
var gems_mode := "dps"
const GEM_ROLE := {
	"warrior": "bruiser", "paladin": "bruiser",
	"archer": "phys", "assassin": "phys",
	"mage": "mag", "warlock": "mag",
}
# --build / --sweep: BUILD ARCHETYPES layered on the fixed 2+2 gear. Each sets the
# attribute allocation + the REGULAR gem slots (specials keep the class preset).
# The sweep runs every class at every build vs the standard (dps) field and FLAGS
# gross outliers — a coarse guardrail against shipping a wildly-broken build, NOT
# a precise ranker (the kit is a lean model, not the real class code).
var build_mode := "dps"
var sweep := false
var evadiag := false
const BUILDS := {
	"dps":  {"attr": "primary", "reg": "atk_flat"},   # baseline: raw stat + Ruby
	"pen":  {"attr": "primary", "reg": "pen"},         # armor penetration
	"crit": {"attr": "primary", "reg": "crit"},        # crit stacking
	"eva":  {"attr": "AGI",     "reg": "eva"},          # dodge / AGI
	"tank": {"attr": "VIT",     "reg": "res"},          # bulk: VIT + res gems
}
# --trace: replay ONE duel (--a=X --b=Y) as a play-by-play + damage-by-source.
var trace := false
var trace_a := "assassin"
var trace_b := "paladin"
var _t := 0.0                 # live duel clock, for trace timestamps
var _log: Array = []          # trace event lines
var _dmg: Dictionary = {}     # "cls Ability" -> total damage dealt (trace)
var _heal: Dictionary = {}    # cls -> total HP healed (trace)
var _last_snap := 0.0


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

	if evadiag:
		_run_evadiag()
		get_tree().quit(0)
		return
	if sweep:
		_run_sweep()
		get_tree().quit(0)
		return
	var base := {}
	for cls in CLS_ORDER:
		base[cls] = _read_fighter(cls, build_mode)
	if trace:
		_run_trace(base)
	else:
		_run(base)
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
		elif a.begins_with("--reps="):
			reps = maxi(3, int(a.get_slice("=", 1)))
		elif a.begins_with("--cls="):
			only_cls = a.get_slice("=", 1)
		elif a.begins_with("--meleeres="):
			meleeres = maxf(0.0, float(a.get_slice("=", 1)))
		elif a == "--trace":
			trace = true
		elif a.begins_with("--a="):
			trace_a = a.get_slice("=", 1)
		elif a.begins_with("--b="):
			trace_b = a.get_slice("=", 1)
		elif a.begins_with("--gems="):
			gems_mode = a.get_slice("=", 1)
		elif a.begins_with("--build="):
			build_mode = a.get_slice("=", 1)
		elif a == "--sweep":
			sweep = true
		elif a == "--evadiag":
			evadiag = true


## Build the god-roll and snapshot the PvP-relevant stats into a template dict.
## `build` (BUILDS key) sets the attribute allocation + regular-gem archetype.
func _read_fighter(cls: String, build := "dps") -> Dictionary:
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
	var ba: String = String(BUILDS[build]["attr"])
	var alloc: String = String(Classes.CLASSES[cls]["primary"]) if ba == "primary" else ba
	p.attr_points[alloc] = 99
	p.unspent_attr = 0
	var cfg := {"grade": "S", "gemlvl": 10, "plus": 20, "godroll": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = BenchBuild.GEAR_SEED
	p.equipment = BenchBuild.equip_dict(cls, tid, cfg, rng)
	if build == "dps":
		_regem(p.equipment, cls)   # honors --gems (dps/pvp)
	else:
		_regem_build(p.equipment, cls, build)
	p._update_weapon_visual()
	p.recalc()
	# The melee-res grant (recalc applies it only under pvp_active, which is off in
	# the bench) is folded in here on TOP of any gem res.
	var grant: float = float(MELEE_RES[cls]) * meleeres
	return {
		"cls": cls,
		"maxhp": p.max_hp * tough,
		"maxmp": p.max_mp,
		"atk": p.current_atk(),
		"crit": Stats.crit_curve(p.crit),
		"critdmg": p.crit_dmg,
		"cdr": p.cdr,
		"combo": p.combo,
		"lifesteal": p.lifesteal,
		"regen": p.regen_pct,
		"flat_dr": p.flat_dr,
		"physres": p.physres + grant,
		"magres": p.magres + grant,
		"physpen": p.physpen,
		"magpen": p.magpen,
		"dtype": String(Classes.CLASSES[cls]["dmg_type"]),
		"eva": Stats.eva_curve(p.eva),   # dodge CHANCE (curved)
		"eva_raw": p.eva,                # raw stat, for dex_tier
		"dex": p.dex,                    # attacker accuracy vs eva
		"speed": float(SPEED[cls]),
	}


## Re-socket every item for the chosen PvP loadout ("dps" keeps the god-roll gems).
func _regem(equipment: Dictionary, cls: String) -> void:
	if gems_mode == "dps":
		return
	var role: String = GEM_ROLE[cls]
	for slot in equipment:
		var item: Dictionary = equipment[slot]
		var n := int(item.get("gem_slots", 0))
		if n <= 0:
			continue
		var spec_cap := Items.special_slots(String(item["grade"]))
		var glist := []
		for i in n:
			glist.append(Items.make_gem(_gem_stat(role, i < spec_cap, i), 10))
		item["gems"] = glist


## Replace the REGULAR gems for a build archetype (specials keep the class preset).
func _regem_build(equipment: Dictionary, cls: String, build: String) -> void:
	var reg: String = String(BUILDS[build]["reg"])
	if reg == "atk_flat":
		return   # baseline Ruby regulars already placed
	var magic := String(Classes.CLASSES[cls]["dmg_type"]) == "magic"
	for slot in equipment:
		var gems: Array = equipment[slot].get("gems", [])
		for i in gems.size():
			if String((gems[i] as Dictionary).get("stat", "")) in Balance.SPECIAL_GEM_STATS:
				continue   # keep the % specials; only regular slots change
			var s := reg
			if reg == "pen":
				s = "magpen" if magic else "physpen"
			elif reg == "res":
				s = "physres" if i % 2 == 0 else "magres"
			gems[i] = Items.make_gem(s, 10)


## Gem stat per slot/role: bruiser = sustain special (Vampire Eye) + both-threat
## res (Onyx/Lapis); attacker = keep a damage special (Sunstone) + all-in pen.
func _gem_stat(role: String, special: bool, idx: int) -> String:
	if role == "bruiser":
		if special:
			return "lifesteal"
		return "physres" if idx % 2 == 0 else "magres"
	if special:
		return "dmg_pct"
	return "physpen" if role == "phys" else "magpen"


# ============================================================= the duel ===

## One duel; `left_start` puts A at the low wall. Returns +1 A wins, -1 B, 0 draw.
func _duel(ta: Dictionary, tb: Dictionary, left_start: bool) -> int:
	var a := _spawn(ta, 0.0 if left_start else START_DIST)
	var b := _spawn(tb, START_DIST if left_start else 0.0)
	var t := 0.0
	while t < T_MAX:
		# tick continuous effects first (dots, regen, timers)
		_tick(a, DT)
		_tick(b, DT)
		if a["dead"] or b["dead"]:
			break
		# randomize resolution order each tick to avoid first-mover bias
		if randf() < 0.5:
			_act(a, b); _act(b, a)
		else:
			_act(b, a); _act(a, b)
		if a["dead"] or b["dead"]:
			break
		_move(a, b); _move(b, a)
		t += DT
	var ah: float = a["hp"] / a["maxhp"]
	var bh: float = b["hp"] / b["maxhp"]
	if a["hp"] <= 0.0 and b["hp"] <= 0.0:
		return 0
	if a["hp"] <= 0.0:
		return -1
	if b["hp"] <= 0.0:
		return 1
	if absf(ah - bh) < 0.05:
		return 0
	return 1 if ah > bh else -1


func _spawn(t: Dictionary, pos: float) -> Dictionary:
	var f := t.duplicate(true)
	f["hp"] = t["maxhp"]
	f["mp"] = t["maxmp"]
	f["pos"] = pos
	f["cds"] = {}
	f["dmg_buff_t"] = 0.0; f["dmg_buff"] = 0.0
	f["spd_buff_t"] = 0.0; f["spd_buff"] = 0.0
	f["ls_t"] = 0.0; f["ls_amt"] = 0.0
	f["dr_t"] = 0.0; f["dr_amt"] = 0.0
	f["iframe_t"] = 0.0
	f["stun_t"] = 0.0
	f["slow_t"] = 0.0; f["slow_amt"] = 0.0
	f["amp_t"] = 0.0; f["amp_amt"] = 0.0
	f["dot_t"] = 0.0; f["dot_dps"] = 0.0
	f["dead"] = false
	return f


func _tick(f: Dictionary, dt: float) -> void:
	if f.get("dead", false):
		return   # no regen / dot / cd-tick on a corpse
	for k in ["dmg_buff_t", "spd_buff_t", "ls_t", "dr_t", "iframe_t", "stun_t",
			"slow_t", "amp_t"]:
		f[k] = maxf(0.0, float(f[k]) - dt)
	for name in f["cds"]:
		f["cds"][name] = maxf(0.0, float(f["cds"][name]) - dt)
	if float(f["dot_t"]) > 0.0:
		f["dot_t"] = maxf(0.0, float(f["dot_t"]) - dt)
		f["hp"] = maxf(0.0, float(f["hp"]) - float(f["dot_dps"]) * dt * dmg_mult)
	# passive regen
	f["hp"] = minf(float(f["maxhp"]),
		float(f["hp"]) + float(f["regen"]) * float(f["maxhp"]) * dt * heal_mult)


## Choose and use one ability (or none) this tick.
func _act(f: Dictionary, o: Dictionary) -> void:
	if f.get("dead", false) or float(f["stun_t"]) > 0.0:
		return
	var dist: float = absf(float(f["pos"]) - float(o["pos"]))
	var kit: Array = KIT[f["cls"]]
	# buff (Berserk / Dark Pact) — fire on cooldown, opener.
	for ab in kit:
		if ab["k"] == "buff" and _off_cd(f, ab):
			_use(f, o, ab, dist); return
	# escape: proactively when a melee closes into danger (kite the charge), or
	# reactively when low. A ranged kiter that only blinks at 35% is a strawman.
	var threatened: bool = float(f["hp"]) < 0.35 * float(f["maxhp"]) \
		or (RANGED.has(f["cls"]) and not RANGED.has(o["cls"]) and dist < 240.0)
	if threatened:
		for ab in kit:
			if ab["k"] == "esc" and _off_cd(f, ab):
				_use(f, o, ab, dist); return
	# offense: best usable damaging ability in range (ult/high-coeff first).
	var best: Dictionary = {}
	var best_val := -1.0
	for ab in kit:
		if float(ab.get("coeff", 0.0)) <= 0.0 or not _off_cd(f, ab):
			continue
		var reach := float(ab["rng"]) + (0.0 if ab.get("moveto", false) else 0.0)
		if dist > reach:
			continue
		var val := float(ab["coeff"]) * float(ab.get("hits", 1))
		if val > best_val:
			best_val = val; best = ab
	if not best.is_empty():
		_use(f, o, best, dist); return
	# nothing in range: melee closes the gap (gap ability, else walk handled in _move)
	if not RANGED.has(f["cls"]):
		for ab in kit:
			if ab["k"] == "gap" and _off_cd(f, ab) and dist <= float(ab["rng"]):
				_use(f, o, ab, dist); return


func _off_cd(f: Dictionary, ab: Dictionary) -> bool:
	return float(f["cds"].get(ab["n"], 0.0)) <= 0.0 and float(f["mp"]) >= float(ab.get("mp", 0))


func _use(f: Dictionary, o: Dictionary, ab: Dictionary, dist: float) -> void:
	f["mp"] = maxf(0.0, float(f["mp"]) - float(ab.get("mp", 0)))
	var cd := float(ab.get("cd", 0.0))
	if ab["n"] != "Meteor" and ab["n"] != "DeathMark" and ab["n"] != "VoidRift" \
			and ab["n"] != "ArrowStorm" and ab["n"] != "Berserk":
		cd *= 1.0 - float(f["cdr"])   # ults ignore haste
	if float(ab.get("coeff", 0.0)) > 0.0 and float(ab.get("cd", 0.0)) < 1.0 \
			and randf() < float(f["combo"]):
		cd = 0.0                       # combo refund on the spammable basics
	f["cds"][ab["n"]] = maxf(0.0, cd)
	# movement riders
	if ab.get("moveto", false):
		var side: float = signf(float(f["pos"]) - float(o["pos"]))
		if side == 0.0:
			side = 1.0
		f["pos"] = clampf(float(o["pos"]) + side * MELEE * 0.9, 0.0, ARENA_LEN)
		dist = absf(float(f["pos"]) - float(o["pos"]))
	if ab.has("moveaway"):
		var side2: float = signf(float(f["pos"]) - float(o["pos"]))
		if side2 == 0.0:
			side2 = 1.0
		var away: float = float(f["pos"]) + side2 * float(ab["moveaway"])
		# Cornered against a wall: juke PAST the opponent to open space (a 2D
		# reposition the 1D lane otherwise can't express — mobile ranged only).
		if away <= 5.0 or away >= ARENA_LEN - 5.0:
			away = float(o["pos"]) - side2 * float(ab["moveaway"])
		f["pos"] = clampf(away, 0.0, ARENA_LEN)
	# defensive / buff riders
	if ab.has("iframe"):
		f["iframe_t"] = maxf(float(f["iframe_t"]), float(ab["iframe"]))
	if ab.has("dr"):
		f["dr_t"] = float(ab["dr_dur"]); f["dr_amt"] = float(ab["dr"])
	if ab.has("heal"):
		f["hp"] = minf(float(f["maxhp"]), float(f["hp"]) + float(f["maxhp"]) * float(ab["heal"]) * heal_mult)
	if ab.has("buff_dmg"):
		f["dmg_buff_t"] = float(ab["buff_dur"]); f["dmg_buff"] = float(ab["buff_dmg"])
		f["spd_buff_t"] = float(ab["buff_dur"]); f["spd_buff"] = float(ab.get("buff_spd", 0.0))
	if ab.has("buff_ls"):
		f["ls_t"] = float(ab["buff_dur"]); f["ls_amt"] = float(ab["buff_ls"])
	if ab.has("ls_bonus"):
		f["ls_t"] = maxf(float(f["ls_t"]), float(ab["ls_dur"])); f["ls_amt"] = float(ab["ls_bonus"])
	# damage
	if float(ab.get("coeff", 0.0)) > 0.0 and dist <= float(ab["rng"]) + 1.0:
		_hit(f, o, ab)
	if ab.has("dot"):
		o["dot_dps"] = float(f["atk"]) * float(ab["dot"]); o["dot_t"] = float(ab["dot_dur"])
	if ab.has("amp"):
		o["amp_amt"] = float(ab["amp"]); o["amp_t"] = float(ab["amp_dur"])
	if ab.has("stun"):
		o["stun_t"] = maxf(float(o["stun_t"]), float(ab["stun"]))
	if ab.has("slow"):
		o["slow_t"] = float(ab["slow_dur"]); o["slow_amt"] = float(ab["slow"])
	if ab.has("knock"):
		# shove the target away from the caster (Frost Nova's peel).
		var ks: float = signf(float(o["pos"]) - float(f["pos"]))
		if ks == 0.0:
			ks = 1.0
		o["pos"] = clampf(float(o["pos"]) + ks * float(ab["knock"]), 0.0, ARENA_LEN)
	# trace: log the tactical beats (gap-close / escape / buff) — the positioning
	# story; auto-attacks stay in the snapshots + damage summary.
	if trace and String(ab["k"]) in ["gap", "esc", "buff"]:
		var tag := ""
		if ab.get("moveto", false):
			tag += " gap-close"
		if ab.has("moveaway"):
			tag += " juke/escape"
		if ab.has("iframe"):
			tag += " iframe%.1fs" % float(ab["iframe"])
		if ab.has("stun"):
			tag += " STUN%.1fs" % float(ab["stun"])
		if ab.get("k", "") == "buff":
			tag += " BUFF"
		_log.append("  %5.2fs  %-8s %-11s%s" % [_t, f["cls"], String(ab["n"]), tag])


func _hit(f: Dictionary, o: Dictionary, ab: Dictionary) -> void:
	# i-frame fully negates.
	if float(o["iframe_t"]) > 0.0:
		return
	# DEX vs EVA (Stats.dex_tier): the attacker's DEX answers the defender's eva —
	# enough cancels the dodge, half-parity downgrades a dodge to a GRAZE (half
	# damage), too little = full miss. Attacker carries at least BASELINE_DEX (the
	# "some dex every player has"), so eva isn't a free 50% dodge.
	var grazed := false
	var graze_frac := 1.0
	var e_eva := float(o["eva_raw"])
	if e_eva > 0.0:
		var f_dex: float = maxf(float(f["dex"]), BASELINE_DEX)
		var tier := Stats.dex_tier(f_dex, e_eva)
		if tier < 2 and randf() < float(o["eva"]):
			if tier == 0:
				return          # full miss
			grazed = true       # graze — leaks the curve's fraction through
			graze_frac = Stats.graze_through(f_dex, e_eva)
	var coeff := float(ab["coeff"]) * float(ab.get("hits", 1))
	var truef := float(ab.get("truef", 0.0))
	var base := float(f["atk"]) * coeff
	if float(f["dmg_buff_t"]) > 0.0:
		base *= 1.0 + float(f["dmg_buff"])
	var xmult := 1.0
	if ab.get("always_crit", false) or randf() < float(f["crit"]):
		xmult = float(f["critdmg"])
	var dmg := base * ((1.0 - truef) * xmult + truef)
	if ab.get("exec", false) and float(o["hp"]) < 0.40 * float(o["maxhp"]):
		dmg *= 1.5   # Coup de Grace / execute amp
	if float(o["amp_t"]) > 0.0:
		dmg *= 1.0 + float(o["amp_amt"])
	# mitigation: the attacker's pen (of its damage type) cuts the defender's
	# resistance of that type (melee-res grant + gem res), then plate flat_dr and
	# active DR window. All skip true damage (Death Mark still punches through).
	var dt: String = f["dtype"]
	var dres: float = float(o["magres"]) if dt == "magic" else float(o["physres"])
	var dpen: float = float(f["magpen"]) if dt == "magic" else float(f["physpen"])
	var mit := 1.0 - Stats.res_frac(maxf(0.0, dres - dpen))
	if float(o["flat_dr"]) > 0.0:
		mit *= 1.0 - float(o["flat_dr"])
	if float(o["dr_t"]) > 0.0:
		mit *= 1.0 - float(o["dr_amt"])
	dmg = dmg * ((1.0 - truef) * mit + truef) * dmg_mult
	if grazed:
		dmg *= graze_frac   # the graze curve: how much the dodge leaks through
	o["hp"] = maxf(0.0, float(o["hp"]) - dmg)
	if float(o["hp"]) <= 0.0:
		o["dead"] = true   # a corpse can't regen or heal off zero (death is prompt)
	# lifesteal to the attacker
	var ls := float(f["lifesteal"]) + (float(f["ls_amt"]) if float(f["ls_t"]) > 0.0 else 0.0)
	if ls > 0.0:
		var before := float(f["hp"])
		f["hp"] = minf(float(f["maxhp"]), before + dmg * ls * heal_mult)
		if trace:
			_heal[f["cls"]] = float(_heal.get(f["cls"], 0.0)) + (float(f["hp"]) - before)
	if ab.has("mend"):
		var mb := float(f["hp"])
		f["hp"] = minf(float(f["maxhp"]), mb + float(f["maxhp"]) * float(ab["mend"]) * heal_mult)
		if trace:
			_heal[f["cls"]] = float(_heal.get(f["cls"], 0.0)) + (float(f["hp"]) - mb)
	if trace:
		var key: String = f["cls"] + "  " + String(ab["n"])
		_dmg[key] = float(_dmg.get(key, 0.0)) + dmg
		var is_ult: bool = String(ab["n"]) in ["DeathMark", "Meteor", "VoidRift", "Conviction", "ArrowStorm"]
		if is_ult or xmult > 1.0:
			_log.append("  %5.2fs  %-8s %-11s %6.0f%s  ->  %-8s %3d%%" % [
				_t, f["cls"], String(ab["n"]), dmg, " CRIT" if xmult > 1.0 else "    ",
				o["cls"], int(float(o["hp"]) / float(o["maxhp"]) * 100.0)])


## Positional policy: ranged hold preferred range (kite), melee close.
func _move(f: Dictionary, o: Dictionary) -> void:
	if f.get("dead", false) or float(f["stun_t"]) > 0.0:
		return
	var spd := float(f["speed"])
	if float(f["spd_buff_t"]) > 0.0:
		spd *= 1.0 + float(f["spd_buff"])
	if float(f["slow_t"]) > 0.0:
		spd *= 1.0 - float(f["slow_amt"])
	var step := spd * DT
	var dist: float = absf(float(f["pos"]) - float(o["pos"]))
	var toward: float = signf(float(o["pos"]) - float(f["pos"]))
	if toward == 0.0:
		toward = 1.0
	var dir := 0.0
	if RANGED.has(f["cls"]):
		# Hold near max range; flee hard when a melee crowds inside charge range.
		var flee := 340.0
		var hold := 470.0
		if dist < flee:
			dir = -toward           # back off from the closing melee
		elif dist > hold:
			dir = toward            # close just enough to keep firing
	else:
		if dist > MELEE * 0.9:
			dir = toward            # melee: always close
	f["pos"] = clampf(float(f["pos"]) + dir * step, 0.0, ARENA_LEN)


# ============================================================= trace ===

## Replay ONE seeded duel as a play-by-play + damage-by-source breakdown.
func _run_trace(base: Dictionary) -> void:
	if not base.has(trace_a) or not base.has(trace_b):
		print("trace: unknown class (--a=%s --b=%s)" % [trace_a, trace_b])
		return
	_log = []
	_dmg = {}
	_heal = {trace_a: 0.0, trace_b: 0.0}
	_last_snap = -1.0
	seed(hash(trace_a + "/" + trace_b) & 0x7FFFFFFF)
	var outcome := _duel_trace(base[trace_a], base[trace_b])
	print("")
	print("=====================================================================")
	print(" DUEL TRACE — %s vs %s  @ tough %.0f  heal %.2f  meleeres %.2f" % [
		trace_a, trace_b, tough, heal_mult, meleeres])
	print(" 1D sim model. Snapshots every 1s [hp%% @pos]; ults + crits + tactical")
	print(" beats logged inline; basic attacks roll up into the damage summary.")
	print("=====================================================================")
	for line in _log:
		print(line)
	print("")
	print("---- DAMAGE DEALT (by source) — the root-cause view ----")
	for who in [trace_a, trace_b]:
		var total := 0.0
		var keys := []
		for key in _dmg:
			if String(key).begins_with(who + "  "):
				total += float(_dmg[key])
				keys.append(key)
		keys.sort_custom(func(x, y): return float(_dmg[x]) > float(_dmg[y]))
		print("  %s — %.0f total" % [who, total])
		for key in keys:
			var v: float = float(_dmg[key])
			print("      %-12s %9.0f   %2.0f%%" % [
				String(key).get_slice("  ", 1), v, v / maxf(1.0, total) * 100.0])
	print("---- HEALING (lifesteal + mend) ----")
	for who in [trace_a, trace_b]:
		print("      %-9s %9.0f" % [who, float(_heal.get(who, 0.0))])
	print("---- OUTCOME ----   %s" % outcome)
	print("DUEL TRACE DONE")


## One duel with the real mechanics, wrapped in logging (trace member is live).
func _duel_trace(ta: Dictionary, tb: Dictionary) -> String:
	var a := _spawn(ta, 0.0)
	var b := _spawn(tb, START_DIST)
	var t := 0.0
	_t = 0.0
	_snap(a, b)
	while t < T_MAX:
		_t = t
		_tick(a, DT)
		_tick(b, DT)
		if a["dead"] or b["dead"]:
			break
		if t - _last_snap >= 1.0:
			_last_snap = t
			_snap(a, b)
		if randf() < 0.5:
			_act(a, b); _act(b, a)
		else:
			_act(b, a); _act(a, b)
		if a["dead"] or b["dead"]:
			break
		_move(a, b); _move(b, a)
		t += DT
	_t = t
	_snap(a, b)
	var ah: float = float(a["hp"]) / float(a["maxhp"])
	var bh: float = float(b["hp"]) / float(b["maxhp"])
	if float(a["hp"]) <= 0.0 and float(b["hp"]) <= 0.0:
		return "double KO at %.1fs" % t
	if float(a["hp"]) <= 0.0:
		return "%s falls at %.1fs — %s wins with %d%% left" % [trace_a, t, trace_b, int(bh * 100.0)]
	if float(b["hp"]) <= 0.0:
		return "%s falls at %.1fs — %s wins with %d%% left" % [trace_b, t, trace_a, int(ah * 100.0)]
	var lead := trace_a if ah > bh else trace_b
	return "TIMEOUT at %.0fs — %s ahead (%s %d%% vs %s %d%%)" % [
		T_MAX, lead, trace_a, int(ah * 100.0), trace_b, int(bh * 100.0)]


func _snap(a: Dictionary, b: Dictionary) -> void:
	_log.append("  %5.2fs   [%-8s %3d%% @%4d]   [%-8s %3d%% @%4d]   dist %4d" % [
		_t,
		a["cls"], int(float(a["hp"]) / float(a["maxhp"]) * 100.0), int(a["pos"]),
		b["cls"], int(float(b["hp"]) / float(b["maxhp"]) * 100.0), int(b["pos"]),
		int(absf(float(a["pos"]) - float(b["pos"])))])


# ============================================================= eva diag ===

## Verify the eva/dex loop on REAL eva builds: for each class's full-eva build,
## the raw eva it reaches, the resulting dodge %, and the DEX (in dex gems, ~52
## each) that grazes / cancels it under the current dex_tier calibration.
func _run_evadiag() -> void:
	print("")
	print("EVA/DEX VERIFY — full-eva builds (dex gem ~= 52 dex; graze halves the dodge, cancel negates it)")
	print("%-9s %8s %8s   %-18s %-18s" % ["class", "raw eva", "dodge", "graze at", "cancel at"])
	for cls in CLS_ORDER:
		var f := _read_fighter(cls, "eva")
		var raw: float = float(f["eva_raw"])
		var dodge: float = Stats.eva_curve(raw)
		var graze: float = Balance.DEX_GRAZE_RATIO * dodge / Balance.DEX_PER_EVA
		var cancel: float = dodge / Balance.DEX_PER_EVA
		print("%-9s %8.2f %7.0f%%   %4.0f dex (%.1f gems)  %4.0f dex (%.1f gems)" % [
			cls, raw, dodge * 100.0, graze, graze / 52.0, cancel, cancel / 52.0])
	print("")
	print("GRAZE CURVE (dmg leaking through a dodge vs a full-eva build, exp %.1f):" % Balance.GRAZE_CURVE_EXP)
	var eva_ref := float(_read_fighter("warrior", "eva")["eva_raw"])
	for g in [2.7, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5]:
		var dx: float = float(g) * 52.0
		print("    %.1f dex gems -> %3.0f%% through" % [g, Stats.graze_through(dx, eva_ref) * 100.0])
	print("EVA DIAG DONE")


# ============================================================= sweep ===

## Guardrail: run every class at every BUILD archetype vs the standard (dps) field
## and flag builds that are wildly out of line. Coarse by design — the kit is a
## lean model, so this catches GROSS outliers to investigate, not fine tiers.
func _run_sweep() -> void:
	var sr := mini(reps, 81)   # a screen doesn't need 201-rep precision
	var field := {}
	for c in CLS_ORDER:
		field[c] = _read_fighter(c, "dps")
	var builds: Array = BUILDS.keys()
	var rows := {}
	for cls in CLS_ORDER:
		rows[cls] = {}
		for b in builds:
			var hero := _read_fighter(cls, String(b))
			var w := 0.0
			var n := 0.0
			for opp in CLS_ORDER:
				if opp == cls:
					continue
				seed(hash(cls + String(b) + opp) & 0x7FFFFFFF)
				for r in sr:
					var res := _duel(hero, field[opp], r % 2 == 0)
					if res > 0:
						w += 1.0
					elif res == 0:
						w += 0.5
					n += 1.0
			rows[cls][b] = w / maxf(1.0, n) * 100.0
	print("")
	print("=====================================================================")
	print(" PVP BUILD SWEEP — win %% vs the dps field  @ tough %.0f heal %.2f meleeres %.2f  (%d reps)" % [
		tough, heal_mult, meleeres, sr])
	print(" Coarse guardrail on a LEAN kit model — flags gross outliers, not fine tiers.")
	print("=====================================================================")
	var header := "%-9s" % "class\\build"
	for b in builds:
		header += "%8s" % b
	print(header)
	for cls in CLS_ORDER:
		var line := "%-9s" % cls
		for b in builds:
			line += "%7.0f%%" % float(rows[cls][b])
		print(line)
	print("")
	print("OUTLIER FLAGS — a non-dps build beating the class's OWN dps baseline by")
	print("  >=15 pts, or any build >=75%% overall (a build worth investigating):")
	var flagged := false
	for cls in CLS_ORDER:
		var dps_wr: float = float(rows[cls]["dps"])
		for b in builds:
			if String(b) == "dps":
				continue
			var wr: float = float(rows[cls][b])
			if wr >= dps_wr + 15.0 or wr >= 75.0:
				print("  %-9s + %-5s = %3.0f%%   (its dps baseline: %.0f%%)" % [
					cls, b, wr, dps_wr])
				flagged = true
	if not flagged:
		print("  (none — no build wildly out of line on this model)")
	print("PVP BUILD SWEEP DONE")


# ============================================================= run + report ===

func _run(base: Dictionary) -> void:
	print("")
	print("=====================================================================")
	print(" PVP DUEL SIM — win rates @ tough %.0f  heal %.2f  dmg %.2f  gems=%s  (%d reps/pair)" % [
		tough, heal_mult, dmg_mult, gems_mode, reps])
	print("=====================================================================")
	var win := {}      # [a][b] = a's win fraction vs b
	var draws := {}
	var wins_tot := {}
	var games_tot := {}
	var avglen := {}
	for c in CLS_ORDER:
		win[c] = {}; draws[c] = {}; wins_tot[c] = 0.0; games_tot[c] = 0.0
	for i in CLS_ORDER.size():
		for j in range(i + 1, CLS_ORDER.size()):
			var ca: String = CLS_ORDER[i]
			var cb: String = CLS_ORDER[j]
			if only_cls != "" and ca != only_cls and cb != only_cls:
				continue
			seed(hash(ca + "/" + cb) & 0x7FFFFFFF)
			var aw := 0.0; var bw := 0.0; var dr := 0.0
			for r in reps:
				var res := _duel(base[ca], base[cb], r % 2 == 0)
				if res > 0: aw += 1.0
				elif res < 0: bw += 1.0
				else: dr += 1.0
			var n := float(reps)
			win[ca][cb] = aw / n
			win[cb][ca] = bw / n
			draws[ca][cb] = dr / n
			wins_tot[ca] += aw + dr * 0.5; games_tot[ca] += n
			wins_tot[cb] += bw + dr * 0.5; games_tot[cb] += n

	print("")
	print("WIN-RATE MATRIX — ROW's win %% vs COLUMN (draws split):")
	var header := "%-9s" % "row\\col"
	for c in CLS_ORDER:
		header += "%9s" % c
	print(header)
	for a in CLS_ORDER:
		var line := "%-9s" % a
		for b in CLS_ORDER:
			if a == b:
				line += "%9s" % "-"
			elif win[a].has(b):
				line += "%8.0f%%" % (float(win[a][b]) * 100.0)
			else:
				line += "%9s" % "."
		print(line)

	print("")
	print("DERIVED TIERS (overall win %% across all pairings):")
	var ranked: Array = CLS_ORDER.duplicate()
	ranked = ranked.filter(func(c): return float(games_tot[c]) > 0.0)
	ranked.sort_custom(func(x, y):
		return float(wins_tot[x]) / float(games_tot[x]) > float(wins_tot[y]) / float(games_tot[y]))
	for cls in ranked:
		var wr := float(wins_tot[cls]) / maxf(1.0, float(games_tot[cls])) * 100.0
		var letter := "S" if wr >= 62.0 else ("A" if wr >= 52.0 else ("B" if wr >= 40.0 else "C"))
		print("  %s  %-9s  %.0f%% overall" % [letter, cls, wr])

	print("")
	print("HARD COUNTERS / STALEMATES (>=80%% or heavy draws):")
	var found := false
	for a in CLS_ORDER:
		for b in CLS_ORDER:
			if a == b or not win[a].has(b):
				continue
			if float(win[a][b]) >= 0.80:
				print("  %s beats %s  %.0f%%" % [a, b, float(win[a][b]) * 100.0])
				found = true
			if float(draws[a].get(b, 0.0)) >= 0.25:
				print("  STALEMATE %s vs %s  (%.0f%% draws — kite/sustain timeout)" % [
					a, b, float(draws[a][b]) * 100.0])
				found = true
	if not found:
		print("  (none — every matchup resolves inside %ds)" % int(T_MAX))
	print("")
	print("NOTE: 1D positioning, lean kit, i-frame-only dodging, paladin=HOLY.")
	print("Validates the matrix's structural reads; not a substitute for playtest.")
	print("PVP DUEL SIM DONE")


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
