extends Node
## PVP TIERS — the FAITHFUL, REAL-KIT PvP class-tier instrument (throwaway, NOT a
## test tier). Where pvp_bench derives its DPS/sustain from LEAN kit-math formulas
## (and so buries the DoT-ramp / stance / lifesteal kits it can't model), this
## drives each class's ACTUAL kit through the real `use_ability` rotations — the
## dps_bench driver — and MEASURES what lands. Real Firebolt spam, real Meteor,
## real Death-Mark stab window, real Hex/Void DoT ramp, real paladin stance dance.
##
## DECOMPOSED model (owner call 2026-08-07): the PvP damage pipeline is two-machine
## by design — riders (DoTs/CC/vuln) only park on a NON-locally-controlled shell
## (_rival_shell) and a shell's take_damage forwards over the wire, so no single
## process gets both real riders AND real damage-apply. So instead of a live duel
## we MEASURE the two halves separately and compose them:
##
##   OFFENSE (measured, real kit)  — each class's realized throttled DPS vs an
##     immortal 0-res dummy that carries the PLAYER 0.6s hurt_cd throttle. Riders
##     (burn/bleed/toxin/vuln) feed the dummy's take_damage and are tallied, and
##     the throttle caps hit-RATE exactly as a real defender does — so a fast-hit
##     kit and a big-hit kit are priced the way the 0.6s i-frame actually prices
##     them (player.gd:803/926 — the factor the 1D sim misses entirely).
##   DEFENCE (measured, real player) — each class under SIEGE: it runs its real
##     rotation (so lifesteal / holy-mend / grit / second-wind all fire) while a
##     dummy strikes it through its REAL take_damage on a cadence. We read its
##     realized sustain/second and its effective HP (pool x plate flat_dr).
##
## The matchup resolver composes them the pvp_bench way: A kills D iff A's TTK on D
## is shorter, where realized DPS is shaved by D's typed resistance (minus A's pen)
## and evasion (the real graze curve), netted against D's measured sustain, and
## melee-into-ranged loses uptime by the MOBILITY gap. TTK = eHP / (effDPS - heal).
##
## MEASURED (hard, real-kit): DPS (throttled, riders in), sustain, eHP, res, eva.
## JUDGMENT (red-pen, a headless bot can't pilot): RANGE/kite uptime + DR-window
## timing (DEFWIN). Kept honestly separate (the dps_bench SCOPE-BOUNDARY rule).
##
## KNOWN LIMITS (v1, documented): the offense dummy is IMMORTAL, so execute / low-HP
## amps (assassin Coup <40%, blood_amp) never open — burst-finish damage is
## under-counted. DoT ticks share the dummy throttle (matches a real player) but an
## enemy's DoT bookkeeping is not a player's, so the DoT<->throttle interaction is
## approximate. Sustain is measured vs one representative target (SIEGE_DUMMY_RES),
## not per-opponent. Kite is a judgment axis, not simulated. For the TRUE wire (all
## of the above live, interactively) the loopback 2-peer harness (net_test_session)
## is the spot-check path — slow/flaky, a few matchups, not an auto-matrix.
##
## Run:  godot --headless --path game res://scenes/pvp_tiers.tscn -- [args]
##   --secs=N     offense window per class      (default 40)
##   --siege=N    siege window per class        (default 30)
##   --cls=X      measure only class X (still prints its row/col)
##   --trace      per-cast / per-strike trace for the measured class

const CLS_ORDER := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]

const HURT_CD := 0.6              # the player damage i-frame the offense dummy mimics
const OFFENSE_SECS_DEFAULT := 40.0
const SIEGE_SECS_DEFAULT := 30.0
const SIEGE_SWING := 1.2          # one incoming strike per this many seconds
const SIEGE_INCOMING := 0.10      # ...at this fraction of the defender's max HP
const SIEGE_DUMMY_RES := 200.0    # the sustain target's resistance (a defended foe)

# How far the attacker stands from the dummy (dps_bench STAND_OFF: melee in arm's
# reach, ranged at a realistic spacing where spreads/meteors land on the hitbox).
const STAND_OFF := {
	"warrior": 70.0, "paladin": 70.0, "assassin": 130.0,
	"archer": 200.0, "mage": 200.0, "warlock": 200.0,
}

# Priority list attempted every physics frame (= holding the keys down; use_ability's
# own cd/mana gates decide what fires). Verbatim from dps_bench — the assassin runs
# a custom driver, the paladin dances the stance, the mage emergency-refills mana.
const ROTATIONS := {
	"warrior": ["ult", "a3", "a1"],
	"archer": ["ult", "a2", "a1"],
	"mage": ["ult", "a1"],
	"paladin": ["a2", "a1"],
	"warlock": ["ult", "a2", "a1"],
}
const SURGE_REFRESH_AT := 0.35    # assassin: dash when the blood surge has this long left
const DEATH_MARK_WINDOW := 5.0    # Death Mark vuln duration: stab-spam window

# ---- JUDGMENT AXES (red-pen surface, a headless bot can't pilot) -----------
# RANGE: 1.0 = ranged kiter who controls spacing; 0.0 = pure melee.
const RANGE := {
	"warrior": 0.0, "paladin": 0.0, "assassin": 0.15,
	"archer": 1.0, "mage": 1.0, "warlock": 1.0,
}
# MOBILITY: gap-close + escape tools (kite uptime for melee-into-ranged).
const MOBILITY := {
	"assassin": 1.0, "mage": 0.8, "archer": 0.6,
	"warrior": 0.5, "paladin": 0.45, "warlock": 0.15,
}
# DEFWIN: fraction of incoming shaved by DR-WINDOWS (blink/aegis timing) that the
# steady-state siege can't credit — a judgment shave, labeled as such in the report.
const DEFWIN := {
	"paladin": 0.20, "warrior": 0.15, "mage": 0.25,
	"assassin": 0.15, "archer": 0.10, "warlock": 0.05,
}


## An immortal 0-res target that carries the PLAYER 0.6s hurt_cd throttle, so a
## real kit's realized damage is capped at the rate a real defender can be hit.
## Extends Boss (like dps_bench BenchDummy) so arcs/fans/meteors land on a real
## boss-scale hitbox and burn/toxin DoTs feed take_damage and are tallied.
class ThrottledDummy extends Boss:
	var m_total := 0.0
	var m_time := 0.0
	var m_active := false
	var m_hits := 0
	var throttled := true
	var _win_cd := 0.0     # time left in the current 0.6s i-frame window
	var _win_max := 0.0    # biggest hit attempted in the open window (skilled lead)
	var trace := false

	static func spawn(game_node: Node2D, pos: Vector2, lvl: int, resval: float,
			do_throttle: bool) -> ThrottledDummy:
		var d := ThrottledDummy.new()
		d._setup(game_node, "vargoth", pos, lvl)   # vargoth's boss-scale body (scale 6.5)
		d.display_name = "PvP Dummy"
		for stat in ["physres", "magres", "eva", "critres", "crit", "dex"]:
			d.set(stat, 0.0)
		d.physres = resval
		d.magres = resval
		d.throttled = do_throttle
		d.max_hp = 1.0e12
		d.hp = d.max_hp
		d.speed = 0.0
		d.sprite.modulate = Color(1.15, 1.0, 0.6)
		return d

	func _physics_process(delta: float) -> void:
		super(delta)              # base tick — burn/toxin DoTs feed take_damage
		global_position = home    # pinned: no knock, pull or chain drags it
		if m_active:
			m_time += delta
		if throttled and _win_cd > 0.0:
			_win_cd -= delta
			if _win_cd <= 0.0 and _win_max > 0.0:
				_close_window()   # the i-frame lapsed: bank the window's best hit

	func _close_window() -> void:
		m_total += _win_max
		m_hits += 1
		if trace:
			print("    landed %8.0f  (t=%.2f)" % [_win_max, m_time])
		_win_max = 0.0

	func _think(_delta: float) -> Vector2:
		return Vector2.ZERO       # pacifist: it measures, it never answers

	# The player 0.6s i-frame: no matter how many hits land in a window, the
	# defender takes ONE — modelled as the BIGGEST (a competent attacker leads
	# with their best hit, not whatever the blind rotation fired first). Without
	# a throttle this tallies every hit (raw output, like dps_bench).
	func take_damage(amount: float, _from_dir := Vector2.ZERO, is_crit := false, _silent := false) -> void:
		if vuln_time > 0.0:
			amount *= vuln_mult   # EXPOSED / Death Mark, like any live boss
		if hobble_t > 0.0:
			amount *= 1.0 + Balance.HOBBLE_MULT
		m_active = true
		knock = Vector2.ZERO
		hp = max_hp               # immortal: the pool never moves
		if not throttled:
			m_total += amount
			m_hits += 1
			return
		if _win_cd <= 0.0:
			_win_cd = HURT_CD     # open a fresh i-frame window
		_win_max = maxf(_win_max, amount)


var game: Game
var offense_secs := OFFENSE_SECS_DEFAULT
var siege_secs := SIEGE_SECS_DEFAULT
var only_cls := ""
var do_trace := false

# --- driver state (mirrors dps_bench; one hero measured at a time) ---
var running := false
var siege_mode := false
var rot_cls := ""
var sim_t := 0.0
var ult_until := -1.0
var dummy: ThrottledDummy = null
# siege sustain telemetry
var siege_t := 0.0
var sg_healed := 0.0
var sg_taken := 0.0
var sg_prev_hp := 0.0
var sg_downs := 0
var sg_frames := 0
var sg_hpfrac_sum := 0.0


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

	# PvP context: the god-roll recalc applies PVP_TOUGHNESS + per-class res caps
	# + the melee-res grant; keep game.state OUT of ST_PLAYING so a siege "down"
	# never trips the solo death flow (on_player_died no-ops off ST_PLAYING).
	game.pvp_active = true
	game.state = game.ST_DEAD

	print("")
	print("=====================================================================")
	print(" PVP TIERS — real-kit measured @ tough %.0f  heal %.2f  (offense %.0fs, siege %.0fs)" % [
		Balance.PVP_TOUGHNESS, Balance.PVP_HEAL_MULT, offense_secs, siege_secs])
	print("=====================================================================")

	var m := {}
	for cls in CLS_ORDER:
		if only_cls != "" and cls != only_cls:
			continue
		var off := await _measure_offense(cls)
		var dfn := await _measure_defense(cls)
		var row: Dictionary = {}
		row.merge(off)
		row.merge(dfn)
		row["cls"] = cls
		m[cls] = row
		print("[tiers] %-9s  DPS %8.0f (%s)  eHP %8.0f  heal/s %7.0f  res %3.0f/%3.0f  eva %2.0f%%  dex %4.0f" % [
			cls, row["dps"], row["dtype"], row["ehp"], row["heal_s"],
			row["res_p"], row["res_m"], row["eva_pct"], row["dex"]])

	if only_cls == "":
		_report(m)
	print("PVP TIERS DONE")
	get_tree().quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("--secs="):
			offense_secs = maxf(5.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--siege="):
			siege_secs = maxf(5.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--cls="):
			only_cls = a.get_slice("=", 1)
		elif a == "--trace":
			do_trace = true


# ============================================================ measurement

## Build the perfect100 god-roll hero for `cls` (the same build pvp_bench / the
## dev roster field), recalc'd under pvp_active so PvP toughness + res caps apply.
func _build_hero(cls: String) -> Player:
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
	_reset_player(p)
	return p


## OFFENSE: drive the real kit vs the immortal, throttled, 0-res dummy for the
## window; realized DPS = tallied damage / elapsed. Riders + throttle are live.
func _measure_offense(cls: String) -> Dictionary:
	seed(hash("off/" + cls) & 0x7FFFFFFF)
	var p := _build_hero(cls)
	var anchor: Vector2 = game.room_center(0)
	var target := ThrottledDummy.spawn(game, anchor + Vector2(240, 0), 100, 0.0, true)
	target.trace = do_trace
	game.add_enemy(target)
	dummy = target
	p.global_position = target.home + Vector2(-float(STAND_OFF[cls]), 0)
	p.facing = Vector2.RIGHT
	p.locked_target = target
	await _frames(3)

	rot_cls = cls
	sim_t = 0.0
	ult_until = -1.0
	siege_mode = false
	running = true
	if do_trace:
		print("[trace] OFFENSE %s vs throttled 0-res dummy:" % cls)
	var guard := 0.0
	while target.m_time < offense_secs:
		await get_tree().physics_frame
		guard += 1.0 / 60.0
		if guard > offense_secs * 3.0 + 30.0:
			push_error("PVP TIERS STALL: %s offense never filled its window" % cls)
			break
	running = false

	var secs: float = maxf(target.m_time, 0.001)
	var dtype: String = String(Classes.CLASSES[cls]["dmg_type"])
	var pen: float = p.physpen if dtype == "phys" else p.magpen
	var out := {
		"dps": target.m_total / secs,
		"dtype": dtype,
		"pen": pen,
		"dex": p.dex,
		"crit": Stats.crit_curve(p.crit),
	}
	target.queue_free()
	await _frames(2)
	return out


## DEFENCE: the class under SIEGE — it runs its real rotation on a defended dummy
## (so lifesteal / holy-mend / grit fire) while a strike lands on its REAL
## take_damage every SIEGE_SWING seconds. Realized sustain = net HP regained / s.
func _measure_defense(cls: String) -> Dictionary:
	seed(hash("def/" + cls) & 0x7FFFFFFF)
	var p := _build_hero(cls)
	var anchor: Vector2 = game.room_center(0)
	var target := ThrottledDummy.spawn(game, anchor + Vector2(240, 0), 100, SIEGE_DUMMY_RES, false)
	game.add_enemy(target)
	dummy = target
	p.global_position = target.home + Vector2(-float(STAND_OFF[cls]), 0)
	p.facing = Vector2.RIGHT
	p.locked_target = target
	await _frames(3)

	rot_cls = cls
	sim_t = 0.0
	ult_until = -1.0
	siege_t = 0.0
	sg_healed = 0.0
	sg_taken = 0.0
	sg_prev_hp = p.hp
	sg_downs = 0
	sg_frames = 0
	sg_hpfrac_sum = 0.0
	siege_mode = true
	running = true
	if do_trace:
		print("[trace] SIEGE %s (incoming %.0f%% max HP / %.1fs):" % [cls, SIEGE_INCOMING * 100.0, SIEGE_SWING])
	var guard := 0.0
	while target.m_time < siege_secs:
		await get_tree().physics_frame
		guard += 1.0 / 60.0
		if guard > siege_secs * 3.0 + 30.0:
			break
	running = false
	siege_mode = false

	var secs: float = maxf(target.m_time, 0.001)
	var heal_s: float = sg_healed / secs
	var res_p: float = p.physres
	var res_m: float = p.magres
	var ehp: float = p.max_hp / maxf(0.05, 1.0 - p.flat_dr)
	var out := {
		"ehp": ehp,
		"max_hp": p.max_hp,
		"heal_s": heal_s,
		"res_p": res_p,
		"res_m": res_m,
		"eva": p.eva,
		"eva_pct": Stats.eva_curve(p.eva) * 100.0,
		"flat_dr": p.flat_dr,
		"downs": sg_downs,
		"hpfrac": (sg_hpfrac_sum / float(maxi(1, sg_frames))),
	}
	target.queue_free()
	await _frames(2)
	return out


# ============================================================ the driver

func _physics_process(_delta: float) -> void:
	if not running or dummy == null:
		return
	sim_t += 1.0 / 60.0
	var p: Player = game.player
	if siege_mode:
		_siege_tick(p)
		if p.dead:
			return   # a real fall mid-siege: the refill next tick stands it back up
	if rot_cls == "assassin":
		_drive_assassin(p)
		return
	if rot_cls == "paladin" and p.cds.get("ult", 0.0) <= 0.0:
		p.use_ability("ult")   # stance dance: swap on every Conviction cd
		return
	if rot_cls == "mage" and p.mp <= 55.0 and p.cds["a2"] <= 0.0:
		p.use_ability("a2")    # emergency Frost Nova mana refill
	for slot in ROTATIONS[rot_cls]:
		p.use_ability(slot)


## Assassin custom driver (dps_bench): Death Mark on cd, stab-spam the 5s vuln
## window, else surge management — dash to refresh the blood surge, Fan otherwise.
func _drive_assassin(p: Player) -> void:
	if p.cds["ult"] <= 0.0 and sim_t >= ult_until:
		p.use_ability("ult")
		if p.cds["ult"] > 0.0:
			ult_until = sim_t + DEATH_MARK_WINDOW
		return
	if sim_t < ult_until:
		p.use_ability("a1")
		if p.s_passive() == "mirrorstep":
			p.use_ability("a3")
		return
	if p.cds["a2"] <= 0.0 and p.stab_ls_time <= SURGE_REFRESH_AT:
		p.facing = (dummy.global_position - p.global_position).normalized()
		p.use_ability("a2")
		return
	p.use_ability("a3")


## Siege: sample the defender's sustain each frame, then land the strike on the
## cadence through its REAL take_damage (evasion, graze, wards, plate, mend, grit,
## second-wind all fire). A would-die counts a DOWN and refills — never dies.
func _siege_tick(p: Player) -> void:
	var dh := p.hp - sg_prev_hp
	if dh > 0.0:
		sg_healed += dh
	elif dh < 0.0:
		sg_taken += -dh
	sg_prev_hp = p.hp
	sg_hpfrac_sum += p.hp / maxf(1.0, p.max_hp)
	sg_frames += 1
	siege_t += 1.0 / 60.0
	if siege_t < SIEGE_SWING:
		return
	siege_t = 0.0
	if p.hp <= p.max_hp * clampf(SIEGE_INCOMING * 1.6, 0.2, 0.6):
		sg_downs += 1
		p.hp = p.max_hp
		sg_prev_hp = p.max_hp
	# Every 4th strike is magic; drive it through the real player take_damage with
	# the dummy as attacker so enemy crit / graze / ward / plate / low-HP all fire.
	var dtype := "magic" if (sg_downs + int(sim_t)) % 4 == 0 else "phys"
	p.take_damage(p.max_hp * SIEGE_INCOMING, dtype, dummy, false)


# ============================================================ compose + report

## Melee attacker A's damage uptime into defender D (kite gap by MOBILITY).
func _uptime(a: Dictionary, d: Dictionary) -> float:
	if float(a["range"]) >= 0.8:
		return 1.0
	if float(d["range"]) < 0.8:
		return 1.0
	return clampf(0.40 + 0.5 * (float(a["mob"]) - float(d["mob"])), 0.25, 1.0)


## Time-to-kill A inflicts on D: measured DPS shaved by D's typed resistance (minus
## A's pen), the real graze/eva curve, the kite gap and the DR-window judgment,
## netted against D's measured sustain. INF if D out-sustains A.
func _ttk(a: Dictionary, d: Dictionary) -> float:
	var res_d: float = float(d["res_p"]) if String(a["dtype"]) == "phys" else float(d["res_m"])
	var res_mult := 1.0 - Stats.res_frac(maxf(0.0, res_d - float(a["pen"])))
	var eva: float = float(d["eva"])
	var eva_mult := 1.0 - Stats.eva_curve(eva) * (1.0 - Stats.graze_through(float(a["dex"]), eva))
	var eff := float(a["dps"]) * _uptime(a, d) * res_mult * eva_mult * (1.0 - float(d["defwin"]))
	var net := eff - float(d["heal_s"])
	if net <= 0.0:
		return INF
	return float(d["ehp"]) / net


func _report(m: Dictionary) -> void:
	for cls in CLS_ORDER:
		m[cls]["range"] = float(RANGE[cls])
		m[cls]["mob"] = float(MOBILITY[cls])
		m[cls]["defwin"] = float(DEFWIN[cls])

	print("")
	print("MEASURED metrics (real-kit driven):")
	print("%-9s %9s %5s %9s %9s   res(p/m)   eva   kite defwin" % [
		"class", "DPS", "type", "eHP", "heal/s"])
	for cls in CLS_ORDER:
		var r: Dictionary = m[cls]
		print("%-9s %9.0f %5s %9.0f %9.0f   %3.0f/%3.0f  %3.0f%%   %.2f  %.2f" % [
			cls, r["dps"], r["dtype"], r["ehp"], r["heal_s"],
			r["res_p"], r["res_m"], float(r["eva_pct"]), float(r["range"]), float(r["defwin"])])

	print("")
	print("MATCHUP MATRIX — time-to-kill (s) that ROW inflicts on COLUMN")
	print("  lower = row kills column faster;  INF = column out-sustains row")
	var header := "%-9s" % "atk\\def"
	for d in CLS_ORDER:
		header += "%9s" % d
	print(header)
	for a in CLS_ORDER:
		var line := "%-9s" % a
		for d in CLS_ORDER:
			if a == d:
				line += "%9s" % "-"
				continue
			var t := _ttk(m[a], m[d])
			line += "%9s" % ("INF" if t == INF else "%.1f" % t)
		print(line)

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
				var margin: float = 1.0 if td == INF else clampf((td - ta) / maxf(0.1, td), 0.0, 1.0)
				score[a] = float(score[a]) + 1.0 + margin
	var ranked: Array = CLS_ORDER.duplicate()
	ranked.sort_custom(func(x, y): return float(score[x]) > float(score[y]))
	var rank := 1
	for cls in ranked:
		var letter := "S" if rank <= 1 else ("A" if rank <= 3 else ("B" if rank <= 5 else "C"))
		print("  %s  %-9s  score %.2f" % [letter, cls, score[cls]])
		rank += 1

	print("")
	print("DEGENERATE FLAGS (what the letters hide):")
	var flags: Array = []
	for a in CLS_ORDER:
		for d in CLS_ORDER:
			if a == d:
				continue
			var t_ad := _ttk(m[a], m[d])
			if t_ad == INF:
				flags.append("  SUSTAIN LOCK: %s cannot kill %s (out-sustained)" % [a, d])
				continue
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
	print("MEASURED = real-kit DPS (throttled, riders live) + siege sustain + eHP + res/eva.")
	print("JUDGMENT (red-pen) = kite uptime (RANGE/MOBILITY) + DR-window DEFWIN.")
	print("UNDER-COUNTED: execute/low-HP amps (immortal dummy). Validate marquee cells")
	print("on the true wire (loopback net_test_session) before trusting a surprise.")


# ============================================================ plumbing

func _reset_player(p: Player) -> void:
	for key in p.cds:
		p.cds[key] = 0.0
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.berserk_time = 0.0
	p.storm_time = 0.0
	p.stab_ls_time = 0.0
	p.pact_time = 0.0
	p.theme_guard_time = 0.0
	p.theme_speed_time = 0.0
	p.aegis_time = 0.0
	p.dr_time = 0.0
	p.cast_haste_time = 0.0
	p.nova_regen_time = 0.0
	p.next_crit = false
	p.hunt_rhythm = 0
	p.paladin_mode = "holy"
	p.grit_stacks = 0
	p.grit_time = 0.0
	p.judgment_leap_cd = 0.0
	p.hexed.clear()
	p.wither.clear()
	p.locked_target = null
	p.since_hurt = 999.0
	p.dead = false


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
