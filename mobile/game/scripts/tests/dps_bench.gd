extends Node
## DPS BENCH (dps_bench.bat) — measured, theoretical-max sustained DPS
## per class, CONSTRAINED to each class's real boss-fight playstyle.
## Not part of the game and not part of the test suites.
##
## Frame: level 40 hero, full A gear (seeded rolls), Lv6 gems (the A
## socket cap), optimal-DPS talents, mono-themed kit (every slot on one
## theme) — run for every class x theme = 18 cases. The target is an
## immortal BOSS dummy: a real `Boss` subclass carrying the AVERAGE
## defensive sheet of every Menus.BOSS_KINDS entry at level 40, so CC
## immunity, concussion conversion, boss shove rules and boss-sized
## hitboxes all behave exactly like a real boss door.
##
## Rotations (player-specified, 2026-07-07):
##   warrior  — stand still; Cleave + Whirlwind + Berserk (no Shield Bash)
##   archer   — Quick Shot + Multishot + Arrow Storm (no Tumble)
##   mage     — Firebolt spam + Meteor; no Blink, and Frost Nova ONLY as
##              an emergency refill when nearly dry (round 49 telemetry:
##              pure bolt spam hits 0 MP ~2min in and the cadence
##              collapses — the missing-mana refund is the max-dps play
##              on long fights, never the on-cooldown weave)
##   assassin — dash through the target right before the blood surge
##              lapses, surged Fan of Knives otherwise; Death Mark on
##              cooldown, then Stab-spam through its 5s vuln window
##   paladin  — swap to RETRIBUTION once, never back; Judgment +
##              Consecration (no Aegis: pure defense vs a passive target)
##   warlock  — Shadowbolt + Hex upkeep + Void Rift (no Dark Pact: you
##              never stand point-blank on a boss)
##
## AOE MODE (--aoe): the target becomes a PACK — three boss-stat pillars
## standing shoulder to shoulder, plus five low-health adds every 10s
## that are SUPPOSED to die (kill-triggered effects — hex detonations,
## Starfall cascades, Phantom refunds — all live). DPS pools EFFECTIVE
## damage across everything (overkill on a dying add doesn't count).
## Two rotation changes vs boss mode, both positioning-derived: the
## warlock takes Dark Pact back (in a pack you ARE point-blank), and
## the mage casts Frost Nova on cooldown (real AoE damage in a crowd).
##
## DOWNTIME MODE (--downtime): hands off the keys for DOWNTIME_DUR out
## of every DOWNTIME_EVERY seconds — the telegraph-dodge simulation.
## Casts stop; DoTs, storms, mists and burns keep working. This is the
## instrument that tests the DoT-tax doctrine with numbers: if the DoT
## specs close the gap here, their lower stand-still numbers are priced
## correctly.
##
## Run:  dps_bench.bat [--aoe] [--downtime] [--secs=N] [--cls=X] [--theme=Y]
## The .bat runs the compile gate first and passes --fixed-fps 60, so
## simulated seconds decouple from the wall clock (CPU-bound speed).

const SIM_SECS_DEFAULT := 180.0   # long window: dilutes ult-cycle edge bias
const PLAYER_LEVEL := 40
const DUMMY_LEVEL := 40
const GEAR_GRADE := "A"
const GEM_LVL := 6                # what A-grade sockets can bear
const CLS_ORDER := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]

# Skill-tree + gem presets, the gear seed, godroll and equip logic all live in
# BenchBuild now (scripts/bench_build.gd) — the SINGLE source shared with the dev
# panel's "Generate benchmark roster" tool, so a build here and a generated hero
# are byte-identical. See BenchBuild.TREE_PRESETS / GEM_PRESETS / equip_dict.

# Priority list attempted every physics frame (= holding the keys down;
# use_ability's own cd/mana gates decide what actually fires). The
# assassin runs a custom driver instead; the paladin adds a one-time
# Conviction swap into Retribution.
const ROTATIONS := {
	"warrior": ["ult", "a3", "a1"],
	"archer": ["ult", "a2", "a1"],
	"mage": ["ult", "a1"],
	"paladin": ["a2", "a1"],
	"warlock": ["ult", "a2", "a1"],
}

# AoE-mode rotations: identical except the two positioning-derived
# re-inclusions — mage Nova on cooldown, warlock Dark Pact back in.
const ROTATIONS_AOE := {
	"warrior": ["ult", "a3", "a1"],
	"archer": ["ult", "a2", "a1"],
	"mage": ["ult", "a2", "a1"],
	"paladin": ["a2", "a1"],
	"warlock": ["ult", "a3", "a2", "a1"],
}

# --- AoE-mode pack shape ---
const PILLARS := 3               # immortal boss-stat targets, in a row
const PILLAR_SPACING := 65.0     # shoulder to shoulder (inside splash range)
const ADD_WAVE_SECS := 10.0      # a fresh wave this often
const ADD_WAVE_COUNT := 5
const ADD_HP := 1200.0           # low: adds are SUPPOSED to die
const ADD_RING := 85.0           # adds pop around the pack's heart

# How far the hero stands from the dummy (melee in arm's reach — no
# Judgment leap below 95px; ranged at a realistic boss-range 200px
# where spread fans land like they do on a boss hitbox).
const STAND_OFF := {
	"warrior": 70.0, "paladin": 70.0, "assassin": 130.0,
	"archer": 200.0, "mage": 200.0, "warlock": 200.0,
}

const SURGE_REFRESH_AT := 0.35    # dash when the blood surge has this long left
const DEATH_MARK_WINDOW := 5.0    # Death Mark vuln duration: stab-spam window

# --- downtime mode: simulated telegraph-dodge pressure ---
const DOWNTIME_EVERY := 5.0       # a dodge window this often...
const DOWNTIME_DUR := 1.0         # ...costs this long of casting (20% uptime tax)

var game: Game
var sim_secs := SIM_SECS_DEFAULT
var only_cls := ""
var only_theme := ""
var aoe := false
var downtime := false
var rep := -1           # --rep=N: independent RNG stream (parallel-mean fan)
var standoff_override := -1.0  # --standoff=N: override STAND_OFF (fidelity probe)
var knife_probe := false       # --knifeprobe: count avg knives/fan connecting
var defense := false           # --defense: print EHP / damage-taken vs the boss, no DPS sim
var grade := GEAR_GRADE        # --grade=X: gear tier on every slot (realistic-kit runs)
var gemlvl := GEM_LVL          # --gemlvl=N: gem level in every socket
var plus_lvl := 0              # --plus=N: smith upgrade level on every piece
var gear_seed := BenchBuild.GEAR_SEED   # --gearseed=N: alternate sub-roll sequence (roll-variance probe)
var godroll := false           # --godroll: reforge-chased ceiling (max main + max offense affixes)
var plevel := PLAYER_LEVEL     # --level=N: hero level (also sets attr points = N-1)
var dlevel := DUMMY_LEVEL      # --level=N sets this too; the target's level
var boss_kind := ""            # --boss=X: dummy carries THIS boss's sheet, not the averaged one
# --depth=D (2026-07-21, Depths restructure): simulate a Depths room at depth D.
# Depth == content level: the dummy carries the depth's (overcap-allowed) boss
# sheet, the hero is capped at LEVEL_CAP, and the live pressure-band debuff
# formula (endgame._apply_player_debuffs — keep in sync) is applied to the
# hero, so measured DPS already includes −damage-dealt and the defense
# readout includes +damage-taken. Answers "can an optimized build clear
# depth D" with numbers instead of vibes.
var depth_sim := 0             # 0 = off
var results: Array = []

# --- rotation driver state (one case at a time) ---
var running := false
var dummy: BenchDummy = null
var rot_cls := ""
var sim_t := 0.0
var ult_until := -1.0
var pala_swapped := false
var ult_casts := 0
# --knifeprobe: how many of the fan's blades geometrically connect on the
# single boss (perp dist of each knife ray to the boss center <= body+dart r).
var knife_fans := 0
var knife_connects := 0
# mana telemetry (round 49: "is the warlock running dry?")
var mp_min := 0.0
var mp_sum := 0.0
var mp_frames := 0
var starved := {}   # slot -> frames it sat OFF cooldown but unaffordable
# --- AoE-mode state ---
var pool := {}          # shared tally every pack target credits into
var aoe_win_t := 0.0    # measured window (starts at first blood anywhere)
var wave_t := 0.0
var wave_idx := 0
var adds_spawned := 0
var pillars: Array = []
var adds: Array = []
var pack_center := Vector2.ZERO


## The measuring target: a real Boss (so `e is Boss` combat rules —
## concussion, CC immunity, boss shove factor — all apply) that never
## moves, never acts, never dies, and tallies every point of damage.
## DoT ticks route through take_damage via the inherited per-frame burn
## handling, so they count too.
class BenchDummy extends Boss:
	var m_active := false
	var m_total := 0.0
	var m_time := 0.0
	var m_hits := 0
	var m_crits := 0
	var m_peak := 0.0
	var pool := {}   # AoE mode: shared pack tally (empty in single mode)

	static func spawn_bench(game_node: Node2D, pos: Vector2, lvl: int, block: Dictionary) -> BenchDummy:
		var d := BenchDummy.new()
		# Borrow vargoth's body: a boss-scale hitbox (scale 6.5), so fans,
		# arcs and multishot spreads connect like they do on a real boss.
		d._setup(game_node, "vargoth", pos, lvl)
		d.display_name = "Bench Dummy"
		# The defensive sheet is the AVERAGE level-40 boss, not vargoth's.
		for stat in ["physres", "magres", "eva", "critres", "crit", "dex"]:
			d.set(stat, float(block[stat]))
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

	func _think(_delta: float) -> Vector2:
		return Vector2.ZERO       # pacifist: it measures, it never answers

	func take_damage(amount: float, _from_dir := Vector2.ZERO, is_crit := false, _silent := false) -> void:
		if vuln_time > 0.0:
			amount *= vuln_mult   # EXPOSED / Death Mark work like any live boss (per-theme amp)
		if hobble_t > 0.0:
			amount *= 1.0 + Balance.HOBBLE_MULT  # failed slows scuff footing (49d)
		m_active = true
		m_total += amount
		m_hits += 1
		if is_crit:
			m_crits += 1
		m_peak = maxf(m_peak, amount)
		if not pool.is_empty():
			pool["dmg"] = float(pool["dmg"]) + amount
			pool["hits"] = int(pool["hits"]) + 1
			if is_crit:
				pool["crits"] = int(pool["crits"]) + 1
			pool["peak"] = maxf(float(pool["peak"]), amount)
			pool["started"] = true
		knock = Vector2.ZERO
		hp = max_hp               # immortal: the pool never moves, no phases


## AoE-mode chaff: a pacifist, killable add. Credits EFFECTIVE damage
## (capped at remaining HP — overkill never inflates the number) into
## the shared pack tally, then dies like any real mob so kill-triggered
## effects (hex detonation, Phantom refund, Starfall cascade) all fire.
## No XP/gold: 90 dying adds must not level the bench hero.
class AddDummy extends Enemy:
	var pool := {}

	static func spawn_add(game_node: Node2D, pos: Vector2, lvl: int, hp_val: float, pool_ref: Dictionary) -> AddDummy:
		var a := AddDummy.new()
		a._setup(game_node, "wolf", pos, lvl)
		a.max_hp = hp_val
		a.hp = hp_val
		a.xp_value = 0
		a.gold_value = 0
		a.speed = 0.0
		a.pool = pool_ref
		return a

	func _think(_delta: float) -> Vector2:
		return Vector2.ZERO   # it exists to DIE, not to bite

	func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
		if dying or untargetable:
			return
		var credited: float = minf(amount * (vuln_mult if vuln_time > 0.0 else 1.0), hp)
		pool["dmg"] = float(pool["dmg"]) + credited
		pool["hits"] = int(pool["hits"]) + 1
		if is_crit:
			pool["crits"] = int(pool["crits"]) + 1
		pool["peak"] = maxf(float(pool["peak"]), credited)
		pool["started"] = true
		super(amount, from_dir, is_crit, silent)

	func die() -> void:
		pool["kills"] = int(pool["kills"]) + 1
		super()


func _ready() -> void:
	_parse_args()
	_run()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("--secs="):
			sim_secs = maxf(10.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--cls="):
			only_cls = a.get_slice("=", 1)
		elif a.begins_with("--theme="):
			only_theme = a.get_slice("=", 1)
		elif a == "--aoe":
			aoe = true
		elif a == "--downtime":
			downtime = true
		elif a.begins_with("--rep="):
			rep = int(a.get_slice("=", 1))
		elif a.begins_with("--standoff="):
			standoff_override = float(a.get_slice("=", 1))
		elif a == "--knifeprobe":
			knife_probe = true
		elif a == "--defense":
			defense = true
		elif a.begins_with("--grade="):
			grade = a.get_slice("=", 1)
		elif a.begins_with("--gemlvl="):
			gemlvl = int(a.get_slice("=", 1))
		elif a.begins_with("--plus="):
			plus_lvl = int(a.get_slice("=", 1))
		elif a.begins_with("--gearseed="):
			gear_seed = int(a.get_slice("=", 1))
		elif a == "--godroll":
			godroll = true
		elif a.begins_with("--level="):
			plevel = int(a.get_slice("=", 1))
			dlevel = plevel
		elif a.begins_with("--boss="):
			boss_kind = a.get_slice("=", 1)
		elif a.begins_with("--depth="):
			depth_sim = int(a.get_slice("=", 1))
			dlevel = depth_sim
			plevel = mini(depth_sim, Balance.LEVEL_CAP)


func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	game.no_saves = true  # never touch (or list) real save files
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_opening()

	var block := _boss_stat_block(dlevel)
	if boss_kind == "":
		print("[bench] target: avg of %d bosses at L%d — physres %.0f  magres %.0f  eva %.1f%%  critres %.0f" % [
			Menus.BOSS_KINDS.size(), dlevel, block["physres"], block["magres"],
			block["eva"] * 100.0, block["critres"]])
	else:
		var kh: float = Story.enemy_stats_at(boss_kind, dlevel)["hp"]
		print("[bench] target: %s at L%d (HP %.0f) — physres %.0f  magres %.0f  eva %.1f%%  critres %.0f" % [
			boss_kind, dlevel, kh, block["physres"], block["magres"],
			block["eva"] * 100.0, block["critres"]])
	print("[bench] hero: L%d, full %s gear (seed %d%s%s), Lv%d gems, %.0fs window per case" % [
		plevel, grade, gear_seed,
		", GODROLL" if godroll else "",
		", +%d smith" % plus_lvl if plus_lvl > 0 else "",
		gemlvl, sim_secs])
	if aoe:
		print("[bench] AOE MODE: %d boss pillars in a row + %d adds (%.0f hp) every %.0fs — effective damage, pooled" % [
			PILLARS, ADD_WAVE_COUNT, ADD_HP, ADD_WAVE_SECS])
	if downtime:
		print("[bench] DOWNTIME MODE: no casting %.1fs of every %.1fs — the telegraph-dodge tax (DoTs keep ticking)" % [
			DOWNTIME_DUR, DOWNTIME_EVERY])

	for cls in CLS_ORDER:
		if only_cls != "" and cls != only_cls:
			continue
		for theme in Classes.THEMES[cls]:
			var tid: String = theme["id"]
			if only_theme != "" and tid != only_theme:
				continue
			await _run_case(cls, tid, block)

	_print_report()
	get_tree().quit(0)


## Average defensive sheet across every registered boss at `lvl` —
## "a level 40 boss", not any one boss's matchup skew.
func _boss_stat_block(lvl: int) -> Dictionary:
	var block := {"physres": 0.0, "magres": 0.0, "eva": 0.0, "critres": 0.0,
		"crit": 0.0, "dex": 0.0}
	# --boss=X: carry that ONE boss's actual defensive sheet, not the average.
	# overcap: a --depth past LEVEL_CAP keeps compounding (the Depths blocks).
	var over := lvl > Balance.LEVEL_CAP
	if boss_kind != "":
		var s := Story.enemy_stats_at(boss_kind, lvl, over)
		for stat in block:
			block[stat] = float(s.get(stat, 0.0))
		return block
	var kinds: Array = Menus.BOSS_KINDS
	for kind in kinds:
		var s := Story.enemy_stats_at(String(kind), lvl, over)
		for stat in block:
			block[stat] += float(s.get(stat, 0.0))
	for stat in block:
		block[stat] /= float(kinds.size())
	return block


# ================================================================== a case

func _run_case(cls: String, tid: String, block: Dictionary) -> void:
	# Deterministic per case; --rep=N perturbs it so parallel repeats each
	# draw an INDEPENDENT crit/combo stream (a real distribution to mean over).
	var seed_key := cls + "/" + tid + ("/" + str(rep) if rep >= 0 else "")
	seed(hash(seed_key) & 0x7FFFFFFF)
	var p: Player = game.player
	var anchor: Vector2 = game.room_center(0)

	# --- build the hero: level, mono theme, talents, attributes, gear
	p.level = plevel
	p.resonance = 0.0  # pin NEUTRAL: the band leans (Hunger execute) must never skew a bench
	p.set_class(cls)          # refunds all points, derives theme unlocks
	p.set_all_themes(tid)     # MONO spec: one identity across all four slots
	p.tree_points = BenchBuild.preset_lookup(BenchBuild.TREE_PRESETS, cls, tid).duplicate()
	p.skill_points = 0
	for attr in p.attr_points:
		p.attr_points[attr] = 0
	p.attr_points[String(Classes.CLASSES[cls]["primary"])] = plevel - 1
	p.unspent_attr = 0
	# S gear carries a dormant signature passive; a BiS run wants it LIVE.
	if grade == "S":
		game.set_flag("s_awakened_" + cls, true)
	_equip(p, cls, tid)
	p.recalc()
	_reset_player(p)

	# --depth: apply the live pressure-band debuffs for this depth (mirror of
	# endgame._apply_player_debuffs — keep the two in sync). debuff_dmg_out
	# multiplies at the hit calc (player_core), so the measured DPS below is
	# already the debuffed number; the defense readout folds debuff_dmg_in.
	if depth_sim > 0:
		var dmg_out := 1.0
		var dmg_in := 1.0
		var stacks := 0
		if depth_sim >= Balance.DEPTHS_TIER_PRESSURE:
			stacks = (depth_sim - Balance.DEPTHS_TIER_PRESSURE) / Balance.DEPTHS_DEBUFF_EVERY + 1
			for s in stacks:
				match s % 2:
					0: dmg_out -= Balance.DEPTHS_DEBUFF_STEP
					1: dmg_in += Balance.DEPTHS_DEBUFF_STEP
		p.debuff_heal_in = 1.0  # heal cut removed 2026-07-21 (sustain is class design)
		p.debuff_dmg_out = maxf(Balance.DEPTHS_DEBUFF_FLOOR, dmg_out)
		p.debuff_dmg_in = dmg_in
		# The boss pool is the BUDGET now (owner ruling: a true level-D boss),
		# so implied TTK = budget / measured dps, straight off this line.
		print("[depth] D=%d (hero L%d): %d stacks — dmg-out x%.2f  dmg-in x%.2f | boss budget: pool %.0f  dmg %.0f (x kind flavor 0.85-1.15)" % [
			depth_sim, plevel, stacks, p.debuff_dmg_out, p.debuff_dmg_in,
			Balance.depths_boss_pool(depth_sim), Balance.depths_boss_dmg(depth_sim)])

	if defense:
		_defense_readout(p, cls, tid)
		return

	# --- the target(s)
	pack_center = anchor + Vector2(240, 0)
	pillars = []
	adds = []
	pool = {"dmg": 0.0, "hits": 0, "crits": 0, "peak": 0.0, "kills": 0, "started": false}
	if aoe:
		# Three pillars shoulder to shoulder; the middle one anchors aim.
		for i in PILLARS:
			var d := BenchDummy.spawn_bench(game,
				pack_center + Vector2((float(i) - 1.0) * PILLAR_SPACING, 0), dlevel, block)
			d.pool = pool
			game.add_enemy(d)
			pillars.append(d)
		dummy = pillars[PILLARS / 2]
		# Melee stands under the row (arcs reach all three); the assassin
		# lines up WITH the row so every dash threads all three pillars;
		# ranged sits close enough that self-centered AoE catches the pack.
		if cls in ["warrior", "paladin"]:
			p.global_position = pack_center + Vector2(0, 70)
		elif cls == "assassin":
			p.global_position = pack_center + Vector2(-(PILLAR_SPACING + 65.0), 0)
		else:
			p.global_position = pack_center + Vector2(0, 120)
	else:
		dummy = BenchDummy.spawn_bench(game, pack_center, dlevel, block)
		game.add_enemy(dummy)
		var so: float = standoff_override if standoff_override >= 0.0 else float(STAND_OFF[cls])
		p.global_position = dummy.home + Vector2(-so, 0)
	p.facing = Vector2.RIGHT
	p.locked_target = dummy
	await _frames(3)

	# --- drive the rotation until the measured window fills
	rot_cls = cls
	sim_t = 0.0
	ult_until = -1.0
	pala_swapped = false
	ult_casts = 0
	knife_fans = 0
	knife_connects = 0
	mp_min = p.max_mp
	mp_sum = 0.0
	mp_frames = 0
	starved = {}
	aoe_win_t = 0.0
	wave_t = ADD_WAVE_SECS  # first wave lands immediately
	wave_idx = 0
	adds_spawned = 0
	running = true
	var guard := 0.0
	while (aoe_win_t if aoe else dummy.m_time) < sim_secs:
		await get_tree().physics_frame
		guard += 1.0 / 60.0
		if guard > sim_secs * 3.0 + 30.0:
			push_error("BENCH STALL: %s/%s never filled its window" % [cls, tid])
			break
	running = false

	var secs: float = maxf(aoe_win_t if aoe else dummy.m_time, 0.001)
	var r := {}
	if aoe:
		r = {
			"case": "%s/%s" % [cls, tid],
			"dps": float(pool["dmg"]) / secs,
			"total": float(pool["dmg"]), "secs": secs,
			"hps": float(pool["hits"]) / secs,
			"crit": 100.0 * float(pool["crits"]) / float(maxi(int(pool["hits"]), 1)),
			"peak": float(pool["peak"]), "ults": ult_casts,
			"atk": p.atk,
			"kills": "  adds %d/%d" % [int(pool["kills"]), adds_spawned],
		}
	else:
		r = {
			"case": "%s/%s" % [cls, tid],
			"dps": dummy.m_total / secs,
			"total": dummy.m_total, "secs": secs,
			"hps": float(dummy.m_hits) / secs,
			"crit": 100.0 * float(dummy.m_crits) / float(maxi(dummy.m_hits, 1)),
			"peak": dummy.m_peak, "ults": ult_casts,
			"atk": p.atk,
			"kills": "",
		}
	r["mana"] = ""
	if not bool(Classes.CLASSES[cls].get("manaless", false)) and mp_frames > 0:
		var starved_bits: Array = []
		for slot in starved:
			var s: float = float(starved[slot]) / 60.0
			if s >= 1.0:
				starved_bits.append("%s %.0fs" % [slot, s])
		r["mana"] = "  mp avg %d min %d%s" % [int(mp_sum / float(mp_frames)), int(mp_min),
			("  STARVED " + ", ".join(starved_bits)) if not starved_bits.is_empty() else ""]
	results.append(r)
	var probe := ""
	if knife_probe and knife_fans > 0:
		probe = "  knives/fan %.2f (of 5, n=%d)" % [float(knife_connects) / float(knife_fans), knife_fans]
	print("[dps] %-18s %7.0f dps   (%.0f over %.0fs)  hits/s %4.1f  crit %2.0f%%  peak %6.0f  ults %d  atk %d%s%s%s" % [
		r["case"], r["dps"], r["total"], r["secs"], r["hps"], r["crit"],
		r["peak"], r["ults"], int(r["atk"]), r["kills"], r["mana"], probe])

	# --- teardown: drop the targets, let in-flight effects (mists, rifts,
	# meteors, storm arrows) resolve into nothing before the next case.
	for node in pillars:
		if is_instance_valid(node):
			node.remove_from_group("enemies")
			node.queue_free()
	pillars = []
	for node in adds:
		if is_instance_valid(node):
			node.remove_from_group("enemies")
			node.queue_free()
	adds = []
	if is_instance_valid(dummy) and not aoe:
		dummy.remove_from_group("enemies")
		dummy.queue_free()
	dummy = null
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()
	_reset_player(p)
	await _frames(300)  # 5 sim-seconds: outlives every lingering async effect


## Full seeded A-grade set with the class's signature weapon shape, each
## piece socketed 1 special + 1 regular gem at the A-grade level cap.
func _equip(p: Player, cls: String, tid: String) -> void:
	# The build is single-sourced in BenchBuild (shared with the dev roster). Seed
	# the roll with THIS run's gear_seed (--gearseed lets it vary for a variance probe).
	var rng := RandomNumberGenerator.new()
	rng.seed = gear_seed
	var cfg := {"grade": grade, "gemlvl": gemlvl, "plus": plus_lvl, "godroll": godroll}
	p.equipment = BenchBuild.equip_dict(cls, tid, cfg, rng)
	p._update_weapon_visual()


## Clean combat slate between cases: cooldowns, buffs, windows, curses.
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


# ============================================================ the rotations

func _physics_process(_delta: float) -> void:
	if not running or dummy == null:
		return
	sim_t += 1.0 / 60.0
	if aoe:
		if bool(pool["started"]):
			aoe_win_t += 1.0 / 60.0
		_tick_waves()
		if rot_cls in ["warrior", "paladin"]:
			# Stand your ground: each add wave physically bulldozes a
			# stationary melee body out of reach (the paladin leaps back,
			# the assassin dashes — the warrior just drifted off and swung
			# at air). A real pilot side-steps back in; the bench pins.
			game.player.global_position = pack_center + Vector2(0, 70)
	if downtime and fmod(sim_t, DOWNTIME_EVERY) < DOWNTIME_DUR:
		# Dodge window: hands off the keys. DoTs, mists, storms and burns
		# keep working; casts (and ult presses) wait out the telegraph.
		return
	var p: Player = game.player
	if rot_cls == "assassin":
		_drive_assassin(p)
		return
	if rot_cls == "paladin" and p.cds.get("ult", 0.0) <= 0.0:
		# Stance-DANCE (2026-07-13 rework): swap on every Conviction cd (Holy<->Retri)
		# to keep Zeal up and bank/spend overheal — the intended paladin DPS play.
		p.use_ability("ult")
		return
	if rot_cls == "mage" and not aoe and p.mp <= 55.0 and p.cds["a2"] <= 0.0:
		# Emergency Frost Nova: 20% of MISSING mana for 15, triggered
		# BEFORE the pool drops under Meteor's 40 — the ult cadence never
		# starves, and nova shares no lockout with Firebolt so the refill
		# costs zero bolt casts. Never woven on cooldown. (AoE mode casts
		# Nova on cooldown via the rotation instead.)
		p.use_ability("a2")
	var rotation_list: Array = ROTATIONS_AOE[rot_cls] if aoe else ROTATIONS[rot_cls]
	for slot in rotation_list:
		var was_ready: bool = p.cds[slot] <= 0.0
		if was_ready and p.mp < p.ability_cost(slot):
			starved[slot] = int(starved.get(slot, 0)) + 1
		p.use_ability(slot)
		if slot == "ult" and was_ready and p.cds[slot] > 0.0:
			ult_casts += 1
	mp_min = minf(mp_min, p.mp)
	mp_sum += p.mp
	mp_frames += 1


## AoE mode: a fresh wave of low-health adds every ADD_WAVE_SECS, popped
## in a ring around the pack's heart (deterministic spots, rotated a
## little per wave so corpses don't stack on one pixel).
func _tick_waves() -> void:
	wave_t += 1.0 / 60.0
	if wave_t < ADD_WAVE_SECS:
		return
	wave_t = 0.0
	wave_idx += 1
	for i in ADD_WAVE_COUNT:
		var ang := TAU * float(i) / float(ADD_WAVE_COUNT) + float(wave_idx) * 0.37
		var a := AddDummy.spawn_add(game, pack_center + Vector2.from_angle(ang) * ADD_RING,
			dlevel, ADD_HP, pool)
		game.add_enemy(a)
		adds.append(a)
		adds_spawned += 1


## The assassin dance (player-specified): Death Mark the moment it's up, then
## plant the blade — Stab-spam through the 5s vuln window (an AWAKENED Nightfang
## weaves Fan in too, both blades at once). Outside the window: Shadow Dash
## straight through the boss right before the blood surge lapses (refreshing it at
## full strength, lane 0 = near-lane cut), surged Fan of Knives every other beat.
func _drive_assassin(p: Player) -> void:
	if p.cds["ult"] <= 0.0 and sim_t >= ult_until:
		p.use_ability("ult")
		if p.cds["ult"] > 0.0:
			ult_casts += 1
			ult_until = sim_t + DEATH_MARK_WINDOW
		return
	if sim_t < ult_until:
		p.use_ability("a1")
		if p.s_passive() == "mirrorstep":
			p.use_ability("a3")   # awakened Nightfang: Fan weaves into the mark window
		return
	if p.cds["a2"] <= 0.0 and p.stab_ls_time <= SURGE_REFRESH_AT:
		p.facing = (dummy.global_position - p.global_position).normalized()
		p.use_ability("a2")
		return
	var a3_ready: bool = p.cds["a3"] <= 0.0
	p.use_ability("a3")
	if knife_probe and a3_ready and p.cds["a3"] > 0.0:
		_count_fan_connects(p)


## Geometric count of how many of the shadow fan's 5 blades would connect on
## the single boss from where the assassin is actually standing this cast.
## Boss body r = 6*scale*0.7 (scale 6.5 -> 27.3) + dart r 9 = 36.3 threshold;
## a knife at angle t clears if dist*sin(|t|) <= that. Blades: 5 @ 0.15 step.
func _count_fan_connects(p: Player) -> void:
	var dist: float = p.global_position.distance_to(dummy.global_position)
	var hit_r := 6.0 * 6.5 * 0.7 + 9.0
	var connects := 0
	for i in 5:
		var ang: float = absf((float(i) - 2.0) * 0.15)
		if dist * sin(ang) <= hit_r:
			connects += 1
	knife_fans += 1
	knife_connects += connects


## --defense: how hard does the target boss hit THIS class? Prints EHP + damage
## taken per representative attack pattern (boss.gd mults), so you can see who
## gets one-shot and who has a margin. Mitigation = 1 - res_frac(res of the
## boss's damage type); boss pen is ~0 for most bosses so it's omitted (noted).
func _defense_readout(p: Player, cls: String, tid: String) -> void:
	var kind := boss_kind if boss_kind != "" else "stormmouth"
	var bs := Story.enemy_stats_at(kind, dlevel, dlevel > Balance.LEVEL_CAP)
	var bdmg: float = bs["dmg"] * p.debuff_dmg_in  # depth sim: +damage-taken folds in
	if depth_sim > 0:
		# Depth mode: the boss budget owns the hit size, not any one kind's sheet.
		bdmg = Balance.depths_boss_dmg(depth_sim) * p.debuff_dmg_in
	var dtype: String = String(Story.ALL_ENEMIES[kind].get("dmg_type", "phys"))
	var res: float = p.physres if dtype == "phys" else p.magres
	var mit: float = (1.0 - Stats.res_frac(res)) * (1.0 - p.flat_dr)
	var line := "[def] %-16s HP %6.0f  pres %3.0f(%2.0f%%) mres %3.0f(%2.0f%%) dr %2.0f%%  eHP %6.0f | %s %s d%.0f: " % [
		cls + "/" + tid, p.max_hp, p.physres, Stats.res_frac(p.physres) * 100.0,
		p.magres, Stats.res_frac(p.magres) * 100.0, p.flat_dr * 100.0,
		p.max_hp / maxf(0.01, mit), kind, dtype, bdmg]
	# Representative Cyrraeth patterns: bolt x1.0, storm sector x1.2, arc x1.3.
	for m in [1.0, 1.2, 1.3]:
		var taken: float = bdmg * m * mit
		var pct: float = 100.0 * taken / p.max_hp
		var tag := "!!" if taken >= p.max_hp else ""
		line += "x%.1f=%.0f(%.0f%%%s) " % [m, taken, pct, tag]
	print(line)


# ================================================================== plumbing



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


func _print_report() -> void:
	var ranked := results.duplicate()
	ranked.sort_custom(func(a, b): return a["dps"] > b["dps"])
	print("")
	print("== DPS BENCH — L%d hero, full %s + Lv%d gems, vs avg L%d boss, %.0fs windows ==" % [
		plevel, grade, gemlvl, dlevel, sim_secs])
	var rank := 1
	for r in ranked:
		print("%2d. %-18s %7.0f dps   hits/s %4.1f   crit %2.0f%%   peak %6.0f   ults %d" % [
			rank, r["case"], r["dps"], r["hps"], r["crit"], r["peak"], r["ults"]])
		rank += 1
	print("DPS BENCH DONE (%d cases)" % results.size())
