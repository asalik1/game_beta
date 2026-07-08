class_name Balance
## Every cross-cutting TUNING KNOB in one place: curves, rates, chances
## and multipliers a designer reaches for. Structured DATA tables stay
## with their domain (classes.gd kits, items.gd gear tables, story.gd
## monsters/zones) — this file is for the numbers you tweak, not the
## content you author.

# ------------------------------------------------------------ facing / aim ---
# Aiming is ORIENTATION-based: the hero faces LEFT or RIGHT (set by A/D and
# the Tab lock), and AIMED attacks (slashes, bolts, arrows) fire toward a
# valid target on the facing side — else straight ahead. EXCEPTION: a target
# nearly straight up or down counts regardless of facing. This cone is how
# "overhead": a target with |dx| <= |dy| * AIM_VERTICAL_CONE is fair game
# from either orientation (0.6 ~= a 31-degree cone off vertical).
const AIM_VERTICAL_CONE := 0.6

# STICKY SOFT TARGET. With no Tab-lock the hero still commits to one enemy —
# your orientation tracks it, and aimed attacks favour it — so you can kite it
# onto your blind side without turning around. It's acquired within
# SOFT_TARGET_ACQUIRE and kept (with hysteresis) out to SOFT_TARGET_KEEP; past
# that, or on death, it drops and the nearest is re-acquired. Tab-lock keeps
# its own job: refusing to auto-switch. KEEP > ACQUIRE so an edge target doesn't
# flicker on/off at the boundary.
const SOFT_TARGET_ACQUIRE := 560.0
const SOFT_TARGET_KEEP := 680.0

# ------------------------------------------------------ hero progression ---
# XP to go from `level` to the next: XP_BASE + level * XP_PER_LEVEL.
# The curve assumes side rooms are cleared (DESIGN.md); chapter kill-XP
# totals are authored against it — retune both together.
const XP_BASE := 30
const XP_PER_LEVEL := 22
const SKILL_POINTS_PER_LEVEL := 1
const ATTR_POINTS_PER_LEVEL := 1   # attributes AND substats spend from this pool
const STARTER_BAG_GRADE := "F"     # legacy single-bag default (save migration fallback)
# Stacking bags (round 52): the hero equips UP TO MAX_BAGS bags and their
# slots SUM. Start with two F pouches — one F (5 slots) is too tight once
# gems + consumables share the pool.
const MAX_BAGS := 5
const STARTER_BAGS := ["F", "F"]

# ------------------------------------------------------ monster scaling ---
const LEVEL_CAP := 100
const TTK_HP_MULT := 2.0        # mobs only: time-to-kill retune (round 4)
const ENEMY_DMG_MULT := 1.3     # ALL monster damage (round 10: "bosses don't hit hard enough")
# Growth-rate rescale (round 11: a L38 nullwarden one-shot a L38
# full-S-gear player). Authored hp_g/dmg_g rates (~0.08-0.15) were
# tuned for LEVEL-GAP walls, but they also run along the at-level
# axis, where the PLAYER only grows ~5-6%/level - so at-level parity
# collapsed 20+ levels above a monster's anchor. Scaling every growth
# rate by this factor matches monster growth to the player curve:
# parity holds at ANY level, and gaps still bite (+10 = ~2x dmg = ~2
# mistakes; +20 Nightmare = ~3x = brutal).
const GROWTH_SCALE := 0.55
# Bosses hit above their tables — the skill tilt (round 12/13). The
# flat mult stacks with ENEMY_DMG_MULT and is CONSTANT at every level:
# a boss always hits ~20% above parity, so out-playing the telegraphs
# is always worth a gear grade. Boss damage GROWTH tracks the player
# curve EXACTLY (round 13: at L42 a full-A-gear player found the old
# compounding edge "a bit overtuned" — A-tier must beat at-level
# bosses; S-tier is comfort + tier headroom, matching when S drops,
# L40-70). Damage only: boss HP growth stays per-kind ("in tune").
const BOSS_DMG_MULT := 1.2
const BOSS_DMG_GROWTH := 0.055   # = the player's ~per-level power growth
const GOLD_MULT := 0.6          # global gold scarcity (merchants must matter)
const REWARD_PER_LEVEL := 0.12  # xp/gold grow LINEARLY per level (no farm spiral)

# ------------------------------------------------------ merchant economy ---
# Round 51 — FARM-COST pricing (supersedes round 50's flat level ladder).
# Buy price of gear ~= the gold you'd earn farming one yourself + a small
# convenience tax, so buying is a pity/convenience option that NEVER beats
# farming. price = (first_run_gold + (N_runs-1)*replay_gold) * FARM_TAX, with
# N_runs = ceil( (1/drop_chance) / BOSSES_PER_RUN ). Because gold/run already
# scales with level, the shop scales automatically — round 50's separate
# SHOP_PRICE_PER_LEVEL ladder is retired. Measured run gold: CHAPTER_ECON.
const FARM_TAX := 1.05
const BOSSES_PER_RUN := 3            # every Act-1 chapter has exactly 3 bosses (verified via econ_audit)
const S_WEAPON_DROP_WEIGHT := 0.5    # S-TIER weapons only drop at HALF rate (they carry the endgame passives) -> rarest, ~2x farm N; sub-S weapon rolls stay uniform
const SHOP_BUY_MARKUP := 2.0         # commodity (below the act's rare tier) grades: cheap flat price = intrinsic x this
const MERCHANT_SELL_FRACTION := 0.45 # SELL = this x INTRINSIC value (Items.price / gem_gold_value), NOT farm-cost — no sell-spiral
const POTION_PRICE := 25             # health-potion buy price (flat staple)
const BAG_SELL_GOLD := 1             # bags ALWAYS cash out for exactly 1g (never the 0.45 formula — anti-exploit)
const SHOP_STOCK_BY_TIER := {"wood": 3, "silver": 4, "gold": 5}  # rolled-gear count
const GAMBLE_DISCOUNT := 0.8         # gamble costs this x the farm price of the chapter's cap grade (sight-unseen risk)
# A loose gem's INTRINSIC value (gold), tripling per level like the 3-into-1
# combine. Drives the SELL price (x MERCHANT_SELL_FRACTION); BUY is farm-cost.
const GEM_GOLD_BASE := 30.0
const GEM_GOLD_PER_LEVEL := 3.0

# --- act-keyed loot framework (Act 2/3 latent until those chapters exist) ---
# BOSS GEAR drop: a NEW channel on every boss, ON TOP of gems/gold/spoils.
# {grade: per-boss drop chance}. Act 1: ch1-6 -> B only; ONLY ch7 bosses add A.
const BOSS_GEAR_DROP := {
	1: {"B": 1.0 / 3.0},                        # ch1-6 bosses
	2: {"A": 1.0 / 8.0, "S": 1.0 / 25.0},
	3: {"A": 1.0, "S": 1.0 / 15.0},             # A guaranteed per Act-3 boss
}
const BOSS_GEAR_DROP_ACT1_FINAL := {"B": 1.0 / 3.0, "A": 1.0 / 10.0}  # ch7 bosses only
const ACT1_FINAL_CHAPTER := "ch7"
# Bags are inventory expansion, not needed every run: a SEPARATE, rarer roll
# than gear (round 51b — the per-gear-grade bag roll felt spammy). Round 52:
# a per-ACT table — chance per boss + a tier weight spread gated to the act,
# so players aren't flooded with obsolete low-tier dupes. dupes still cash at
# BAG_SELL_GOLD (a 6th bag keeps the best MAX_BAGS, the worst is sold).
const BOSS_BAG_DROP := {
	1: {"chance": 0.10, "weights": {"F": 50, "E": 35, "D": 15}},
	2: {"chance": 0.09, "weights": {"D": 40, "C": 40, "B": 20}},
	3: {"chance": 0.08, "weights": {"B": 35, "A": 45, "S": 20}},
}
# Merchants stock bags too (round 52; repriced up ~5x): capacity is QoL, not
# power — but a bag is a RARE drop, so buying one is a real gold DECISION, a
# meaningful chunk of a chapter's income yet still well under same-grade gear
# farm-cost (rarity is the reason to buy, so price — not drop rate — is the
# lever; never a paywall). Flat per-tier (act-gating encodes progression); buy
# dwarfs the 1g sell. Curve anchored to econ_audit income + gear/reforge sinks.
const BAG_BUY_PRICE := {"F": 150, "E": 250, "D": 400, "C": 650, "B": 1000, "A": 1600, "S": 2600}
const SHOP_BAG_COUNT := {1: [1, 1], 2: [1, 2], 3: [1, 2]}

## Per-boss bag drop chance for an act (round 52).
static func bag_drop_chance(act: int) -> float:
	return float(BOSS_BAG_DROP.get(clampi(act, 1, 3), {}).get("chance", 0.0))

## Roll a bag GRADE from an act's tier weights (used by boss/elite/merchant
## bag sources so tier stays gated to the act everywhere).
static func roll_bag_grade(act: int, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = BOSS_BAG_DROP.get(clampi(act, 1, 3), {}).get("weights", {"F": 1})
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var pick := rng.randf() * total
	for grade in weights:
		pick -= float(weights[grade])
		if pick <= 0.0:
			return String(grade)
	return String(weights.keys()[0])

# DISCARD-throw (round 52): a bag item flung out to free a slot. It sails a
# short arc away, then ignores pickup for a beat so it doesn't re-collect the
# instant you're standing on it. Registered like any drop -> mails at chapter
# end (never silently lost).
const DISCARD_THROW_DIST := 96.0
const DISCARD_NO_PICKUP_TIME := 1.5
# SHOP gear appearance weights per act — the grade a stock slot rolls, then
# clamped to the chapter's loot_cap. Act1 floor below B; Act2 floor B; Act3 floor A.
const SHOP_GEAR_WEIGHTS := {
	1: {"F": 12, "E": 18, "D": 22, "C": 15, "B": 33},   # B ~1/3
	2: {"B": 70, "A": 20, "S": 10},                     # A 1/5, S 1/10
	3: {"A": 80, "S": 20},                              # A guaranteed floor, S 1/5
}
# GEM levels by act: elite/boss drop floor, and shop stock range [lo, hi].
const GEM_ACT_LEVEL := {1: 1, 2: 2, 3: 5}
const SHOP_GEM_RANGE := {1: [1, 1], 2: [2, 4], 3: [5, 7]}
const BOSS_FIRST_CLEAR_GEM_BONUS := 1                   # first-clear catch-up bundle rolls +1 level

# Smith UPGRADE curve (round 51): S must cost WAY more than C. Per-step cost =
# UPGRADE_BASE * UPGRADE_GRADE_FACTOR[grade] * (1+plus) — doubling per tier, so
# an S step is 8x a C step at equal plus. base tuned so C +0->+1 = 24g.
const UPGRADE_BASE := 12.0
const UPGRADE_GRADE_FACTOR := {"F": 0.5, "E": 0.75, "D": 1.0, "C": 2.0, "B": 4.0, "A": 8.0, "S": 16.0}

# Measured per-chapter run economy (from econ_audit.gd — RE-RUN and update
# these when reward numbers move; they drive every farm-cost price). "gems" is
# gems per REPLAY run (the gem-price denominator).
const CHAPTER_ECON := {
	"ch1": {"act": 1, "first": 1796, "replay": 1470, "gems": 16.8},
	"ch2": {"act": 1, "first": 1734, "replay": 1296, "gems": 10.1},
	"ch3": {"act": 1, "first": 2944, "replay": 2398, "gems": 16.7},
	"ch4": {"act": 1, "first": 3414, "replay": 2760, "gems": 17.5},
	"ch5": {"act": 1, "first": 4018, "replay": 3274, "gems": 17.5},
	"ch6": {"act": 1, "first": 4866, "replay": 4050, "gems": 17.7},
	"ch7": {"act": 1, "first": 6603, "replay": 5716, "gems": 18.0},
}

static func gem_gold_value(lvl: int) -> float:
	return GEM_GOLD_BASE * pow(GEM_GOLD_PER_LEVEL, float(maxi(lvl - 1, 0)))

## Per-boss GEAR/BAG drop odds ({grade: chance}) for the chapter's act.
static func boss_gear_odds(chid: String) -> Dictionary:
	var e: Dictionary = CHAPTER_ECON.get(chid, {})
	var act: int = int(e.get("act", 1))
	if act == 1 and chid == ACT1_FINAL_CHAPTER:
		return BOSS_GEAR_DROP_ACT1_FINAL
	return BOSS_GEAR_DROP.get(act, {})

## Elite/boss gem drop LEVEL for a chapter's act (round 51: replaces the
## gem_lv2_chance ramp for the act floor). Act1 L1, Act2 L2, Act3 L5.
static func gem_drop_level(chid: String) -> int:
	var act: int = int(CHAPTER_ECON.get(chid, {}).get("act", 1))
	return int(GEM_ACT_LEVEL.get(act, 1))

## Whole RUNS to farm one drop at `chance` (3 bosses/run). S-tier weapons pass
## a halved chance (S_WEAPON_DROP_WEIGHT) so their N — and price — ~doubles.
static func farm_runs(chance: float) -> int:
	if chance <= 0.0:
		return 1
	return int(ceil((1.0 / chance) / float(BOSSES_PER_RUN)))

# ------------------------------------------------------ boss gem drops ---
# Round 44: bosses join the gem economy (was elite-only). The FIRST
# clear of a chapter guarantees a 3-gem bundle per boss (the catch-up
# shower); replays roll a per-kill chance that scales with the boss's
# LEVEL — 1/25 early game, guaranteed at L40+ — so farming MIDGAME
# bosses is the socket progression path.
const BOSS_GEMS_FIRST_CLEAR := 3
const BOSS_GEM_CHANCE_MIN := 0.04    # 1/25 replay floor (early-game bosses)
const BOSS_GEM_FLOOR_LEVEL := 5.0    # chance starts climbing above this level
const BOSS_GEM_CAP_LEVEL := 40.0     # guaranteed from here up


static func boss_gem_chance(lvl: float) -> float:
	return clampf((lvl - BOSS_GEM_FLOOR_LEVEL) / (BOSS_GEM_CAP_LEVEL - BOSS_GEM_FLOOR_LEVEL),
		BOSS_GEM_CHANCE_MIN, 1.0)


# ---------------------------------------------- assassin blade economy ---
# Round 37 ("he doesn't play like an assassin"): knife chip alone paid
# ~87% of stab dps on boss hitboxes, so the rational loop was stand-and-
# chip. Now the blade EARNS the range damage: baseline knives are thin,
# but while the stab surge runs (landed a stab or dash-stab in close)
# they bite DOUBLE — and a CONNECTING dash-stab refunds a chunk of the
# dash cooldown, so the in-out dance is the engine, not the exception.
const KNIFE_MULT := 0.16          # per knife, unsurged (was 0.26)
const KNIFE_BLOOM_MULT := 0.22    # poison's single heavy blade (0.21 -> 0.22 net, round 49: lifted, then re-trimmed when 49d's HOBBLED lifted every slow kit — keeps Fire > Poison)
const KNIFE_SURGE_MULT := 2.0     # surge window: the fan bites double
const DASH_REFUND := 0.35         # dash cd refunded when the rider connects
# Rounds 39/40: planting your feet at blade range is the riskiest act
# in the kit — the STANDING stab pays for it. The dash's proc'd stab
# pays by DEPTH: a cut inside the old 105px corridor (no bonus range
# needed) lands near-full; only the far bonus-reach graze is discounted.
const STAB_MULT := 1.2            # standing stab (was 0.9, then 1.1)
const DASH_STAB_NEAR_MULT := 1.0  # rider cut within DASH_STAB_NEAR_LANE
const DASH_STAB_MULT := 0.65      # far graze (the 105-150px bonus reach)
const DASH_STAB_NEAR_LANE := 105.0
# Rounds 41-43: the refund made the dash semi-spammable — the safety
# riding on it shrank (i-frame 0.5→0.35s), then was REMOVED outright
# (round 43): the dodge is the movement itself; only the ult's all-in
# commit grants immunity.
const SURGE_LS_FLOOR := 0.12      # surge lifesteal at full health (round 42: 14→12)
const SURGE_LS_SCALE := 0.14      # + this x missing-hp (cap = floor+scale = 26%)
# Round 46: Shadow Dash cd is FLOORED so it never becomes sub-second spam
# (flashy but bad design). A connecting refund claws it toward the connect
# floor; a whiff can't drop below the whiff floor no matter the gear cdr.
# Excess cdr past the floor isn't wasted — it converts to bonus damage on the
# dash-through HIT (never the surge slash) and a slightly snappier animation.
const DASH_WHIFF_FLOOR := 1.5
const DASH_CONNECT_FLOOR := 1.0
# Round 49 AoE pass: the dash-stab rider lands on at most this many
# victims per pass ("the blade finds two throats, not the whole
# room") — one dash through a pack was paying full stab damage on
# every body in the 150px corridor, making every assassin variant a
# structural pack monster. Boss fights (one victim) never notice.
const DASH_RIDER_CAP := 2
const DASH_CDR_TO_DMG := 0.75    # per second of floor-eaten cd -> +dash-HIT dmg
const DASH_CDR_TO_ANIM := 0.25   # per second eaten -> anim speedup (capped at 10%)

# ------------------------------------------------------- paladin stances ---
# Round 48: the paladin is a STANCE knight — no true ult. Conviction (the
# ult slot, 8s cd) swaps Holy <-> Retribution: sustain and damage become
# mutually exclusive IN TIME, so reading the fight (when to be which) is the
# skill. Braindead pilots camp Holy (safe, slow); good ones camp Retribution
# and flick out under pressure — the reward curve lives in stance uptime.
const PALADIN_HOLY_DMG := 0.80      # Holy stance: damage dealt multiplier
const PALADIN_HOLY_MEND := 0.01     # Holy stance: max-HP fraction mended per hit landed
const PALADIN_RETRI_DMG := 1.25     # Retribution stance: damage dealt multiplier
const PALADIN_SWAP_HEAL := 0.10     # entering Holy: blessing burst (max-HP fraction)
const PALADIN_SWAP_CHAINS := 0.5    # entering Retribution: chains cast at this scale
# Judgment's leap is a RIDER with its own cooldown (round 48): the hammer
# swings at 0.5s but the leap (and its landing i-frame) only arms this often —
# kills the perma-iframe exploit (dash out, leap back, repeat) at the root.
const JUDGMENT_LEAP_CD := 5.0

# ------------------------------------------- plate-class basic cadence ---
# Round 49 (first dps_bench round): warrior and paladin topped the chart at
# ~15 hits/s — plate hits HARD, not fast. Cleave's authored cd carries +65%
# (0.45 -> 0.74) and Judgment +60% (0.5 -> 0.8). BERSERK hands Cleave its
# old 0.45s cadence back for the window — the ult is a tempo steroid now,
# not just a damage one.
const BERSERK_CLEAVE_CD := 0.45

# ------------------------------------------------ warrior bulwark charge ---
# Round 44: the bulwark's sustain is its heal-on-hit, but Charge's dead-
# center ram (55px lane) whiffed the mend on a near pass. Like the
# assassin's safe-range graze, a charge THROUGH the danger band now
# clips the enemy — a lighter ram that still triggers the heal — so the
# gap-closer reliably feeds the shield.
const CHARGE_GRAZE_LANE := 120.0  # graze band outer edge (past the 55px direct ram)
const CHARGE_GRAZE_MULT := 0.6    # clip damage on a graze (vs the full ram)
# Round 44: a melee gap-closer PARKS you in the boss's swing range — the
# assassin dash passes through and leaves, but Shield Bash rams and stays,
# and Judgment leaps in and stays. Without a landing i-frame they eat the
# boss's next telegraphed swing just for closing the distance their kit
# requires. This brief window covers the landing beat (the boss attack
# cadence is ~0.7-0.9s), NOT sustained melee — Judgment only grants it on
# the actual LEAP, so its 0.5s-cd spam can't chain into perma-immunity.
const MELEE_DASH_IFRAME := 0.45

# ------------------------------------------------- warlock wither ramp ---
# "The warlock's damage doesn't keep up with boss HP pools": a MAINTAINED
# Hex deepens — every WITHER_STACK_EVERY seconds of hex uptime on a
# target adds a stack of +WITHER_PER_STACK damage taken from the
# warlock, capping at WITHER_MAX_STACKS (+64%; round 49 deepened it from
# +48% — the bench had all three variants 25%+ behind). Trash never lives long
# enough to stack, so pack farming is untouched; long boss fights
# converge the class's weakest axis upward. Stacks die with the hex —
# letting the curse lapse resets the ramp, so upkeep IS the rotation.
const WITHER_STACK_EVERY := 6.0
const WITHER_PER_STACK := 0.08
const WITHER_MAX_STACKS := 8

# ------------------------------------------- CC-immune boss conversions ---
# Bosses are outright CC-immune (enemy.gd), which would leave every
# stun/slow-themed variant paying full damage budget for dead riders at
# boss doors. These conversions give each CONTROL identity a boss-mode
# payoff without re-opening boss CC — tuned small: the floor lifts, the
# ceiling stays put.
# CONCUSSION (systemic): a stun that fails on a CC-immune target lands
# as bonus damage instead — failed duration x this x ATK.
const CONCUSSION_MULT := 0.15
# HOBBLED (systemic, round 49d): the same conversion for SLOWS — a slow
# that fails on a CC-immune boss scuffs its footing instead: the boss
# takes +HOBBLE_MULT damage from the player while the mark holds
# (refreshed per failed slow; DoT ticks benefit too, like EXPOSED).
# Before this, the slow half of every control theme's budget (venom/
# poison/ice/void/earth) was a DEAD rider at boss doors — venom paid it
# on all four slots. Tuned small: the floor lifts, the ceiling stays put.
const HOBBLE_MULT := 0.04
const HOBBLE_DUR := 2.5
# TOXIN (poison/venom themes): green DoTs are the exception to the
# no-stack burn rule — each application adds a stack that deepens the
# TICK (never the hit), so fast cadences finally get paid. Round 49
# (dps bench): 0.08 -> 0.12 — poison assassin and venom archer were the
# two weakest melee/ranged variants; the stack is their whole payoff.
const TOXIN_PER_STACK := 0.12
const TOXIN_MAX_STACKS := 5
# ENFEEBLE (round 49e; split 49f): maintaining YOUR toxin on a foe turns
# its own rot into your survival — the DoT specs' end-game answer to
# bullet-hell, the axis that offsets their lower raw dps. Class-flavored,
# scaled by live toxin stacks (upkeep pays, like wither): the ASSASSIN
# slips the blow — up to +EVA evasion ON TOP of base Elusive, so a dive
# to keep the surge can dodge the bullets it dives into; the ARCHER
# shrugs it — up to DR% less damage, the cushion that survives the error
# margin when a hit drops Second Wind. Gated on an attacker carrying
# toxin (melee bites, bolts with a shooter); attacker-less telegraphs and
# hazards are untouched — the poison blunts the body, never the
# spellstorm. Toxin is poison/venom-exclusive; the role can't be borrowed.
const ENFEEBLE_ASSASSIN_EVA := 0.10  # assassin/poison: dodge chance vs the venomed foe (at max stacks)
const ENFEEBLE_ARCHER_DR := 0.16     # archer/venom: damage cushion from the venomed foe (at max stacks)
# BRITTLE (ice theme): cold cracks what it strikes — ice hits bite
# harder per stack, and ONLY ice hits (theme-internal: one poached ice
# slot amps nothing else).
const BRITTLE_PER_STACK := 0.04
const BRITTLE_MAX_STACKS := 5
const BRITTLE_DUR := 6.0
# CRUSH (void theme): void hits bite displaced targets — anything
# recently shoved/pulled hard (above ordinary hit-flinch, which peaks
# at 220) is "in motion against its will" for a short grace window.
const CRUSH_MULT := 0.22   # round 49: 0.25 -> 0.28 -> 0.22 — re-settled when 49d's HOBBLED
                           # handed Void a free lift (its slow rides every bolt)
const CRUSH_MIN_KNOCK := 240.0
# Round 47: crush window widened (0.7→1.5) so ONE displacement keeps Void's
# crush-crit combo live for ~3 bolts, not one — the Void warlock's damage
# rides crush uptime, and a 0.7s window on a 9s-cd shove was ~8% uptime.
const CRUSH_WINDOW := 1.5
# A "shove" (light-displacement fx) moves a boss only this fraction as far as
# a mob — Void keeps constant crush uptime without flinging the boss around.
const BOSS_SHOVE_FACTOR := 0.4
# AEGIS ANSWERS ARROWS (paladin a3): a blocked PROJECTILE smites its
# shooter at this fraction of the melee reflect, capped per cast.
const AEGIS_PROJ_REFLECT := 0.5
const AEGIS_PROJ_CAP := 4

# ------------------------------------------------------- mob presence ---
# Playtest 2026-07-07 ("one/two-tapping ch3 mobs; at least 4 hits should
# be needed; mobs feel weak"): a global pass making trash a real threat,
# on TOP of the per-kind level scaling. HP/dmg mults ride inside
# enemy_stats_at (non-boss only, so the codex stays honest); density
# adds seeded extra spawns per pack. Elites inherit the fatter HP (they
# multiply the already-scaled pool) — intended.
const MOB_HP_MULT := 2.0        # ~1-2 taps -> ~4 hits (the player's ask)
const MOB_DMG_MULT := 1.2       # +20% contact/bolt damage
const MOB_DENSITY_EXTRA := 0.15 # +15% pack size (seeded duplicate chance)

# -------------------------------------------------------- mob traits ---
# The mob-mechanic vocabulary (2026-07-07 REDESIGN — each is a decision,
# not a stat check; most reuse an existing system). Data in each kind's
# ENEMIES "traits"; behavior in enemy.gd; per-chapter escalation in the
# content files. pounce/web/channel_heal (ch1) / warded (ch2) /
# bloat/martyr (ch3) / reflect/sower (ch4) / frost_aura/snare (ch5) /
# spawner/tether (ch6) / blinker/counter (ch7); mend/frenzy/swift baseline.
# pounce (OVERSHOOT gap-closer)
const MOB_LUNGE_CD := 4.5
const MOB_LUNGE_RANGE := 340.0
const MOB_LUNGE_SPEED := 640.0      # fast enough to overshoot a sidestep
const MOB_LUNGE_TIME := 0.30
const MOB_LUNGE_WINDUP := 0.34      # crouch telegraph
const MOB_POUNCE_WHIFF := 1.1       # exposed/dazed window after an overshoot
const MOB_POUNCE_PUNISH := 0.6      # +damage taken while whiff-dazed
# baseline modifiers
const MOB_MEND_RATE := 0.03
const MOB_HEAL_RADIUS := 220.0
const MOB_HEAL_FRAC := 0.10         # channel-heal per pulse
const MOB_FRENZY_HP := 0.40
const MOB_FRENZY_SPEED := 1.35
const MOB_FRENZY_DMG := 1.30
const MOB_SWIFT_SPEED := 1.18
# web (root shot)
const MOB_WEB_CD := 6.0
const MOB_WEB_ROOT := 0.7
# channel_heal (interruptible support)
const MOB_CHANNEL_CD := 5.0
const MOB_CHANNEL_TIME := 1.6
# warded (a GUARD you must SHATTER, not nibble through). A real blow
# breaks it for good — a crit, a heavy single hit (>= this frac of its
# max HP), OR any status (control builds keep their shortcut). Small
# chip hits pay the DR until then. No build is walled: everyone crits
# or lands a heavy hit eventually; status is just the fast lane.
const MOB_WARD_DR := 0.65           # chip damage cut while the guard holds
const MOB_WARD_BREAK_HIT := 0.12    # a single hit >= this frac of max HP shatters it
# bloat / martyr (death triggers)
const MOB_BLOAT_LIFE := 5.0
const MOB_MARTYR_HEAL := 0.25
const MOB_MARTYR_RAGE := 1.25
# reflect / sower
const MOB_REFLECT_CD := 6.5
const MOB_REFLECT_TIME := 1.8
const MOB_REFLECT_FRAC := 0.5
const MOB_SOW_EVERY := 0.45
const MOB_SOW_LIFE := 3.5
# frost_aura / snare (denial)
const MOB_AURA_RADIUS := 170.0
const MOB_FROST_SLOW := 0.6
const MOB_SNARE_CD := 7.0
const MOB_SNARE_FREEZE := 1.1
# spawner / tether
const MOB_SPAWN_CD := 6.0
const MOB_SPAWN_CAP := 3
# blinker / counter (ch7)
const MOB_BLINK_CD := 5.0
const MOB_COUNTER_CD := 4.0
const MOB_COUNTER_TIME := 1.4
const MOB_COUNTER_STAGGER := 0.6

# --------------------------------------------------------------- elites ---
# The miniboss variant (Enemy.promote_elite). Multipliers apply on top
# of the monster's level-scaled stats.
const ELITE_HP_MULT := 4.0
const ELITE_DMG_MULT := 1.5
const ELITE_RES_BONUS := 10.0      # flat phys+mag res
const ELITE_CRITRES_BONUS := 3.0
const ELITE_GOLD_MULT := 3
const ELITE_AGGRO_MULT := 1.5   # elite-ROOM guardians only (pack elites keep pack aggro)
const ELITE_SPRITE_MULT := 1.3
# Seeded spawn odds (per character, like the wanderer rolls).
const ELITE_SOCIAL_ROOM_CHANCE := 0.30   # social room holds an elite, not a wanderer
const ELITE_ROOM_LEVEL_BONUS := 1        # above the host area's toughest spawn
const ELITE_COMBAT_AMBUSH_CHANCE := 0.18 # combat room promotes one pack member
# Death loot (on top of a guaranteed gem + guaranteed chest).
const ELITE_GOLD_CHEST_CHANCE := 0.45    # else the chest is silver
const ELITE_GEM_LV2_CHANCE := 0.35       # the guaranteed gem rolls Lv2 (floor; see gem_lv2_chance)
# Early gem faucet trim (playtest 2026-07-07: "bag full of gems I don't
# use yet in chapter 1") — the per-elite gem GUARANTEE starts at this
# elite level; below it the gem drops this often instead. Gem QUALITY
# ramps (gem_lv2_chance) are untouched: fewer early gems, same chase.
const ELITE_GEM_SURE_LEVEL := 12
const ELITE_GEM_EARLY_CHANCE := 0.45
# Potion LOADOUT (playtest 2026-07-07, v2): potions are budgeted PER
# ROOM. The loadout holds this many slots by act; each slot is a potion
# type (duplicates fine — 3x health is a plan), unassigned slots default
# to health. Entering a room refills the budget; each drink spends a
# slot; an empty loadout locks Q until the next room. Pre-planning IS
# the skill: bag carrying is uncapped (stacks), the fight is not.
const POTION_SLOTS_BY_ACT := {1: 1, 2: 3, 3: 5}

# River wading (terrain mechanic, Graphics & Ambience track): speed
# multiplier in the water for player AND enemies; the bridge is dry.
# Gentle on purpose — a routing choice, not a punishment.
const RIVER_WADE_MULT := 0.72

# DAMP (status effect, 2026-07-08): walking in a river leaves the PLAYER
# "Damp" — a timed move-speed debuff that lingers after stepping out. It
# replaces the player's continuous wade slow above (enemies still use it);
# refreshed every frame you wade, the bridge keeps you dry.
const DAMP_DURATION := 3.0     # seconds Damp holds / refreshes to while wading
const DAMP_SLOW_MULT := 0.80   # move-speed multiplier while Damp (-20%)

# Gem QUALITY chases the frontier (reward calibration, 2026-07-06): the
# guaranteed-gem Lv2 chance climbs with the CONTENT's level. Gem count
# per run stays flat; quality is why you farm at your level instead of
# clubbing Chapter 1 — the no-downscaling rule makes old content safe,
# so the premium has to live in the payout.
const GEM_LV2_CAP := 0.65
const GEM_LV2_RAMP_START := 10           # at/below this level: the flat floor

static func gem_lv2_chance(level: int) -> float:
	return clampf(ELITE_GEM_LV2_CHANCE + 0.01 * float(level - GEM_LV2_RAMP_START),
		ELITE_GEM_LV2_CHANCE, GEM_LV2_CAP)

# Act loot ceilings (reward calibration, 2026-07-06): Act 1 covers F->B
# (ch1's authored C cap stays lower), Act 2 introduces A, Act 3 owns S.
# Applied centrally in game.loot_cap() as a clamp over the chapter's
# authored cap — content modules never need to know the act rule.
const ACT_LOOT_CAP := {1: "B", 2: "A", 3: "S"}

# Anti-degeneracy stat caps (player-designed, 2026-07-06): the four
# SPECIAL stats — Haste, Lifesteal, Combo, Greed — are GEM-ONLY (never
# on gear; gems are the deliberate gateway to off-build stats) and each
# item sockets at most ONE special gem.
#
# EVERY cap in the game is a SOFT KNEE, never a dead stop (player rule):
# below the cap a point is a point; beyond it every point converts at
# SOFT_CAP_RATE (~1/10) — "greatly diminishing", not useless. Applied in
# recalc (cdr/lifesteal/combo), at consumption (current_lifesteal covers
# temp surges) and inside the Stats curves (crit/eva/res/greed).
# Late game may lift the caps a notch by level (~L80) — NOT built yet.
const SOFT_CAP_RATE := 0.1
# Crit alone diminishes gentler (1/5): it's a payoff stat, not a system-
# breaker. Combo stays at 1/10 hard — past the cap you'd start spamming
# every ability with barely any issue (player rule, 2026-07-06).
const CRIT_SOFT_RATE := 0.2

static func soft_cap(v: float, cap: float, rate := SOFT_CAP_RATE) -> float:
	return v if v <= cap else cap + (v - cap) * rate

const CAP_CDR := 0.40        # ults ignore haste ENTIRELY (they're ults)
const CAP_LIFESTEAL := 0.35  # knee on the TOTAL incl. surges/berserk/pact
const CAP_COMBO := 0.30
const CAP_CRIT := 0.35       # the old 70%-curve was far too generous
const CAP_EVA := 0.50        # nothing approaches unhittable
const CAP_GREED := 0.40
const CAP_RES_FRAC := 0.80   # damage REDUCTION knee: >80% pays 1/10
const SPECIAL_GEM_STATS := ["cdr", "lifesteal", "combo", "greed"]

# Boss gem-expectation ramp (player-approved, 2026-07-06): the TIERLIST
# benchmark was gemless, but real players arrive with sockets filled —
# boss hp/dmg gain a small compounding premium per level above the ramp
# start (where B-gear sockets + Lv3 gems realistically come online), the
# same "budget for what the player actually has" move as round 45's
# gear-inclusive dps. Applied inside enemy_stats_at: codex stays honest.
const BOSS_GEM_RAMP_START := 32
const BOSS_GEM_HP_RAMP := 0.012    # +9.6% at L40, grows through Act 2
const BOSS_GEM_DMG_RAMP := 0.006   # half-size: skill still wins parity

# First-clear premium (reward calibration, 2026-07-06): conquering a
# chapter the FIRST time pays a legible beat on top of XP + boss gems —
# gold in hand plus a mailed spoils package (one act-cap gear roll + a
# Lv2 gem). Roughly 15-25% of the run's own gold: felt, never economy-
# breaking, and never worth chasing over the farm loop itself.
const FIRST_CLEAR_GOLD := 150            # x daily_gold_mult(final boss level)
const ELITE_STONE_CHANCE := 0.30         # Stone of Unlearning
const ELITE_TOME_CHANCE := 0.15          # Palimpsest of the Path (skill tree reset)
const ELITE_BAG_CHANCE := 0.18           # rolled only when neither reset dropped

# -------------------------------------------------------------- mob loot ---
# Chance-based chest drops from trash (Greed above 30% nudges these up).
const MOB_SILVER_CHEST_CHANCE := 0.04
const MOB_WOOD_CHEST_CHANCE := 0.18

# ------------------------------------------------------ hero resources ---
const POTION_MAX := 5
const BOSS_KILL_POTION_FLOOR := 2   # boss kills top potions up to this

# ------------------------------------------------- resonance rewards ---
# A shard choice in a quiet room pays either way (conviction, not
# virtue): gold scaled by |delta|, a chest at bigger shifts.
const RES_REWARD_GOLD_BASE := 8
const RES_REWARD_GOLD_PER_POINT := 2
const RES_REWARD_CHEST_AT := 5.0     # |delta| >= this -> wood chest
const RES_REWARD_SILVER_AT := 8.0    # |delta| >= this -> silver chest

# --------------------------------------------------------------- mailbox ---
# Unclaimed mail (dropped-loot letters, event gifts) expires after this
# many days on the TRUSTED clock (game.trusted_now — monotonic, cheat-
# resistant). Claimed letters stay until the player deletes them.
const MAIL_EXPIRY_DAYS := 30

# ---------------------------------------------------- daily login reward ---
# One claim per calendar day on the TRUSTED clock. Consecutive days build
# a streak; a missed day resets it to 1. The reward cycles through this
# 7-day table by streak position (day 7 = the jackpot), then loops. Gold
# scales with level (daily_gold_mult) so it stays relevant; gems/potions
# are flat. Gear is deliberately omitted — dailies must not short-circuit
# the act-gated loot curve.
const DAILY_REWARDS := [
	{"gold": 120},
	{"gold": 180, "potions": 1},
	{"gems": 1, "gem_lvl": 1},
	{"gold": 300},
	{"gems": 1, "gem_lvl": 1, "potions": 1},
	{"gold": 500, "potions": 2},
	{"gold": 400, "gems": 1, "gem_lvl": 2},   # day 7 jackpot
]

## Gold rewards scale with level so a daily stays meaningful late (a flat
## 120g is nothing at L40). ~+12% per level over the base.
static func daily_gold_mult(level: int) -> float:
	return 1.0 + 0.12 * float(maxi(level - 1, 0))

# --------------------------------------------------------------- bounties ---
# Rotating objectives: 2 daily + 1 weekly, rolled DETERMINISTICALLY from
# these pools by trusted-clock day/week index (so relogging can't reroll).
# Progress is driven by kill/clear events (bounty_progress). Gold scales
# with level like the daily; gems are flat. Types: boss_kills /
# rooms_cleared / elite_kills.
const BOUNTY_DAILY_COUNT := 2
const BOUNTY_WEEKLY_COUNT := 1
const BOUNTY_POOL := {
	"daily": [
		{"type": "boss_kills",    "target": 1, "desc": "Slay a boss",        "gold": 220},
		{"type": "rooms_cleared", "target": 4, "desc": "Clear 4 rooms",      "gold": 150},
		{"type": "elite_kills",   "target": 2, "desc": "Slay 2 elites",      "gold": 180},
	],
	"weekly": [
		{"type": "boss_kills",    "target": 5,  "desc": "Slay 5 bosses",    "gold": 800, "gems": 1, "gem_lvl": 2},
		{"type": "rooms_cleared", "target": 25, "desc": "Clear 25 rooms",   "gold": 700, "gems": 1, "gem_lvl": 2},
		{"type": "elite_kills",   "target": 10, "desc": "Slay 10 elites",   "gold": 750, "gems": 1, "gem_lvl": 2},
	],
}

# Weekly vault: kill this many bosses in a trusted-clock week to unlock one
# guaranteed golden-chest reward, claimable once per week (great-vault style).
const VAULT_BOSS_GOAL := 5

# Account-wide stash: cross-character long-term storage (survives any one
# character; lives in user://stash.json, not the per-character save). Kept
# deliberately TIGHT — the stash is a curated keep-safe, not a warehouse.
const STASH_SLOTS := 20

# ------------------------------------------------------------ consumables ---
# Utility consumables beyond the health potion (bag items, used from the
# inventory). Prices are the merchant's base (before haggle); effects tuned
# to be handy, not build-warping.
const MANA_POTION_FRAC := 0.5    # restores this fraction of MAX mana
const ELIXIR_MIGHT_AMT := 0.20   # +20% damage while the elixir holds
const ELIXIR_MIGHT_DUR := 30.0   # seconds
# Round 50 additions — a defensive elixir (mirrors Might on the dr_ system)
# and a burst bag-heal (distinct from the 5-cap health-potion counter, and
# not budgeted by it — a real reason to spend at the alchemist's shelf).
const ELIXIR_WARD_AMT := 0.25    # incoming non-true damage cut while it holds
const ELIXIR_WARD_DUR := 20.0    # seconds
const RENEWAL_HEAL_FRAC := 0.5   # instant heal, fraction of MAX hp
const CONSUMABLE_PRICES := {"mana_potion": 35, "elixir_might": 130, "recall_scroll": 55,
	"elixir_ward": 110, "renewal_draught": 90}

# Gambling vendor (Diablo-style): spend gold for a random item of the
# merchant's tier, sight unseen. A cheap gold sink + loot thrill; deeper
# merchants gamble richer tiers. Cost is per merchant tier (before haggle).
const GAMBLE_COST := {"wood": 60, "silver": 150, "gold": 400}

# ----------------------------------------------------------------- rooms ---
# Quiet room types shrink their walled playable area within the fixed
# grid cell (corridors connect the doors to the cell edges).
const SMALL_ROOM_TYPES := ["social", "dead_end", "resonance", "merchant"]
const SMALL_ROOM_INSET := Vector2(420.0, 246.0)

# -------------------------------------------------------- chapter results ---
# The results card on every chapter clear (retention roadmap #1): run time,
# deaths, elites, secrets, exploration -> one letter. TIME is deliberately
# NOT graded — it is the personal-best race instead; grading speed would
# punish the exploration the zone graph exists to reward.
# Score: deaths (clean play) + exploration + thoroughness (elites+secrets
# vs the seeded expectation), 0..100 -> letter by these floors.
const GRADE_FLOORS := {"S": 90, "A": 72, "B": 50, "C": 30}   # below C = "D"
const GRADE_DEATH_PTS := [40, 25, 10]  # 0 / 1 / 2 deaths (3+ = 0 of 40)
const GRADE_EXPLORE_PTS := 30.0        # x visited/zone_count
const GRADE_HUNT_PTS := 30.0           # x (elites+secrets)/expected, capped
const GRADE_HUNT_EXPECT := 0.2         # expected finds ≈ 20% of room count

const GRADE_ORDER := ["D", "C", "B", "A", "S"]

## Higher = better; unknown/empty = -1 (any real grade beats it).
static func grade_rank(g: String) -> int:
	return GRADE_ORDER.find(g)


## The chapter grade letter from a run's stats (see the section note).
static func chapter_grade(deaths: int, explored: float, hunt: float) -> String:
	var pts := 0.0
	if deaths < GRADE_DEATH_PTS.size():
		pts += float(GRADE_DEATH_PTS[deaths])
	pts += GRADE_EXPLORE_PTS * clampf(explored, 0.0, 1.0)
	pts += GRADE_HUNT_PTS * clampf(hunt, 0.0, 1.0)
	for g in ["S", "A", "B", "C"]:
		if pts >= float(GRADE_FLOORS[g]):
			return g
	return "D"

# --------------------------------------------------------- weekly challenge ---
# One fixed seed + one modifier per trusted-clock week, the same for every
# player (retention roadmap #2 — becomes a leaderboard when multiplayer
# lands). The run is a chapter replay on the week's seed; finishing it once
# a week pays gold (level-scaled) + gems. Modifier fx keys are consulted at
# spawn/drop sites via game.weekly_fx().
const WEEKLY_MODS := [
	{"id": "iron",   "name": "Ironhide",     "desc": "Monsters have +30% health.",                    "hp": 1.3},
	{"id": "cruel",  "name": "Cruelty",      "desc": "Monsters hit +20% harder.",                     "dmg": 1.2},
	{"id": "swift",  "name": "Swiftfoot",    "desc": "Monsters move +15% faster.",                    "speed": 1.15},
	{"id": "gilded", "name": "Gilded Blood", "desc": "Monsters drop +50% gold, but hit +10% harder.", "gold": 1.5, "dmg": 1.1},
	{"id": "legion", "name": "Elite Legion", "desc": "Elite ambushes are twice as common.",           "elite": 2.0},
]
const WEEKLY_REWARD_GOLD := 400   # scaled by daily_gold_mult(level)
const WEEKLY_REWARD_GEMS := 2
const WEEKLY_REWARD_GEM_LVL := 2

# ------------------------------------------------------------- risk events ---
# Elective risk (retention roadmap #4): temptations the player can walk
# past. Seeded per character like elites — a replay meets different offers.
const CURSED_ROOM_CHANCE := 0.15   # combat rooms that hold a cursed chest
const CURSE_DMG_MULT := 1.3        # cursed pack hits harder...
const CURSE_SPEED_MULT := 1.15     # ...and moves faster, until the purge
# The bargain is offered at the DOOR now (playtest 2026-07-07: a chest
# that waits in the room gets claimed after the pack dies — free hoard,
# or a payout that never fires). This is its decision window, seconds.
const CURSE_OFFER_WINDOW := 10.0
const SHRINE_ROOM_CHANCE := 0.22   # quiet rooms that hold a gamble shrine
const SHRINE_COST_BASE := 45       # gold, scaled by daily_gold_mult(level)
const SHRINE_BLESS_CHANCE := 0.6   # else the shrine drinks deeper

# Hidden caches (exploration premium, 2026-07-06): some dead ends bury a
# chest that only glints awake when the player wanders NEAR — walking
# the room nobody made you walk is what finds it. Seeded per character;
# counts as a secret on the results card.
const HIDDEN_CACHE_CHANCE := 0.25
const HIDDEN_CACHE_GOLD_TIER := 0.3   # else silver

# ------------------------------------------------------------ loot fanfare ---
# Rarity is audio-visual (retention roadmap #3): every gear drop plays a
# per-grade chime; B and above also raise a grade-colored light beam that
# grows with rarity. S adds a screen flash — the jackpot reads across the room.
const LOOT_BEAM_MIN_GRADE := "B"   # beams start here; below is chime-only
const LOOT_BEAM_TIME := 1.6        # seconds the beam holds before fading

# ---------------------------------------------------------- gear tier icons ---
# Every gear icon reads its GRADE at a glance (codex gallery + bag slots),
# not just from a letter. Hand-colored override PNGs get a gentle shift
# toward the grade color; the procedural fallback takes the full tint. On
# top, A and S wear a faint MISTY AURA (light orange / light red) hugging
# the silhouette — subtle, never a glare. Knobs kept low on purpose.
const ICON_OVERRIDE_TINT := 0.35   # hand-colored icons: fraction blended toward the grade color
const ICON_PROC_TINT := 0.65       # procedural fallback icons: full grade tint (matches held-weapon look)
const TIER_AURA_PAD := 5           # transparent margin (px/side) padding every tier icon to one size
const TIER_AURA_RINGS := 5         # A/S aura depth: pixel rings dilated out from the silhouette
const TIER_AURA_ALPHA := 0.20      # A/S aura PEAK opacity — deliberately faint/misty (rings fade past it)

# -------------------------------------------------------- codex completion ---
# Kill-count lore (retention roadmap #5): slaying enough of a monster kind
# unearths its codex lore entry; unearthed entries feed the Lorekeeper title.
const LORE_KILLS_MOB := 25         # kills to unearth a regular monster's lore
const LORE_KILLS_BOSS := 3         # bosses die once a run — 3 clears is devotion
