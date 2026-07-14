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

# ------------------------------------------------- character render scale ---
# Heroes and regular mobs are authored at ~200px but render small on screen, so
# the downscale decimates thin detail (a hero's sword blade in the E/W idle/walk
# poses dropped out and read as "cut off"). This multiplier enlarges the hero
# body target + its attachments (shadow, held weapon, aura) AND every enemy's
# visual (sprite, shadow, HP-bar height) — mobs AND bosses — by the SAME factor,
# so the whole cast keeps its relative proportion. Purely visual: collision
# radii, aggro/attack ranges and speeds are unchanged. Tune to taste; 1.0 = old size.
const CHAR_RENDER_SCALE := 1.7

# Hero name (chosen at creation, shown in the co-op lobby/party). Capped so a
# long name never overruns a roster row; empty falls back to the OS account
# name. Matches os_name()'s substr(0, 16) so the fallback and the typed name
# share a ceiling.
const CHAR_NAME_MAX := 16

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
const MAX_BAGS := 10
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
# Global BOSS damage factor (+20% skill tilt), constant at every level; trash
# keeps its own ENEMY_DMG_MULT/MOB_DMG_MULT. A blunt global halving (2026-07-09)
# was reverted — it fixed the over-tuned finale but made already-gentle EARLY
# bosses trivial. Over-tuned bosses are trimmed per-kind in their base_dmg
# instead, preserving the intro->finale difficulty ramp.
const BOSS_DMG_MULT := 1.2
# Boss GROWTH per level above native (2026-07-09 endgame-scaling pass). These
# only bite when a boss is fought ABOVE its authored level (endgame/scaling
# mode); at native level d=0 so nothing changes and normal play is untouched.
# The old rates (dmg 0.055, hp 0.15*GROWTH_SCALE) compounded exponentially over
# big level gaps — a L100 boss hit for 32x and had 184x HP, one-shotting even
# tanks and making 30-min fights. Recalibrated to the PLAYER's real curves over
# the same range (DPS ~x2.9, EHP ~x2.4 from L40->L100 incl. gear): HP growth
# tracks player DPS (TTK stays flat), DMG growth tracks player EHP (a hit stays
# the same % of HP — tanks survive, squishies dodge, exactly as at native L40).
const BOSS_HP_GROWTH := 0.018    # bosses only; tracks player DPS growth -> level-invariant TTK
const BOSS_DMG_GROWTH := 0.015   # tracks player EHP growth -> level-invariant hit danger
const GOLD_MULT := 0.6          # global gold scarcity (merchants must matter)
const REWARD_PER_LEVEL := 0.12  # xp/gold grow LINEARLY per level (no farm spiral)
# Death tithe (player-approved 2026-07-09): death must cost SOMETHING or every
# boss is brute-forceable by pure attrition (respawn was a free full restore).
# Fraction of CARRIED gold lost on death; respawn location / boss reset /
# HP-MP restore stay free.
const DEATH_GOLD_TITHE := 0.10

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
# Health potions are an INVESTMENT (2026-07-09 potion round): stock is
# BOUGHT, never granted (the only freebie is the expiring ch1-3 teaching
# potion — FREE_POTION_CHAPTERS below). Heals are %-based, so a potion is
# worth the same to a hero of any level — the price must follow the HERO,
# not the shop's chapter (2026-07-09: chapter-keyed pricing let a L40
# backtrack to ch1 for 25g potions — a free crutch via the road home).
# POTION_PRICE is the L1 base; the per-level rate lands ~L40 at the same
# ~5x endpoint the old chapter ladder measured (farm-minutes per potion
# stay roughly flat vs CHAPTER_ECON g/min). SELL stays on the flat base
# (menus.gd) so potions can never be hauled anywhere for profit.
const POTION_PRICE := 60                 # L1 base buy price (2026-07-09: 25 was ~1% of ch1-clear wealth — dirt cheap; a heal must cost real coin)
const POTION_PRICE_PER_LEVEL := 0.10     # +10% of base per level above 1

static func potion_price(level: int) -> int:
	return int(round(POTION_PRICE * (1.0 + POTION_PRICE_PER_LEVEL * float(maxi(level, 1) - 1))))

# Teaching exception, anti-farm (2026-07-09): ENTERING one of these chapters
# grants ONE free health potion (player.potions_free) — it EXPIRES the moment
# you leave the chapter (absolute set in switch_chapter), so revisiting early
# chapters can never farm freebies, and it is never sellable.
const FREE_POTION_CHAPTERS := ["ch1", "ch2", "ch3"]
const BAG_SELL_GOLD := 1             # bags ALWAYS cash out for exactly 1g (never the 0.45 formula — anti-exploit)
const SHOP_STOCK_BY_TIER := {"wood": 3, "silver": 4, "gold": 5}  # rolled-gear count
const GAMBLE_DISCOUNT := 0.8         # gamble costs this x the EXPECTED farm price of a chapter boss-band roll (sight-unseen risk; see game_base.gamble_cost)
# A loose gem's INTRINSIC value (gold), tripling per level like the 3-into-1
# combine. Drives the SELL price (x MERCHANT_SELL_FRACTION); BUY is farm-cost.
const GEM_GOLD_BASE := 30.0
const GEM_GOLD_PER_LEVEL := 3.0

# --- Chapter loot BANDS (2026-07-09; replaces the act-keyed loot framework) ---
# Every gear/bag drop is a WEIGHTED roll from the chapter's table (no more
# roll-high-then-clamp). Two profiles per chapter:
#   GENERAL — mobs, chests, shop stock, spoils, gamble (skews low/mid)
#   BOSS    — the boss gear channel + ALL bag sources (reaches the ceiling)
# Tiers phase in/out on a sliding window (intent; the tables are the truth):
#   F ch1-3 | E ch2-4 | D ch3-7 | C ch4-11 | B ch5-.. | A ch6-.. | S ch12-..
# Regular gems drop ch4+, special gems ch6+ (see *_gems_drop below). ch12+
# tables are set later (unbuilt) — gear_weights/boss_weights fall back to the
# richest authored table so nothing rolls empty.
const GEAR_TIER_ORDER := ["F", "E", "D", "C", "B", "A", "S"]
const RICHEST_CH := "ch11"   # fallback table for unbuilt ch12+
const CHAPTER_GEAR_WEIGHTS := {
	"ch1":  {"F": 100},
	"ch2":  {"F": 40, "E": 60},
	"ch3":  {"F": 25, "E": 50, "D": 25},
	"ch4":  {"E": 15, "D": 50, "C": 35},
	"ch5":  {"D": 40, "C": 60},
	"ch6":  {"D": 10, "C": 90},
	"ch7":  {"D": 5, "C": 94, "B": 1},
	"ch8":  {"C": 15, "B": 84, "A": 1},
	"ch9":  {"C": 10, "B": 89, "A": 1},
	"ch10": {"C": 6, "B": 92, "A": 2},
	"ch11": {"C": 2, "B": 96, "A": 2},
}
const CHAPTER_BOSS_WEIGHTS := {
	"ch1":  {"F": 100},
	"ch2":  {"E": 100},
	"ch3":  {"D": 100},
	"ch4":  {"C": 100},
	"ch5":  {"C": 75, "B": 25},
	"ch6":  {"B": 80, "A": 20},
	"ch7":  {"B": 70, "A": 30},
	"ch8":  {"B": 65, "A": 35},
	"ch9":  {"B": 65, "A": 35},
	"ch10": {"B": 65, "A": 35},
	"ch11": {"B": 65, "A": 35},
}
# Per-boss chance to drop a gear item AT ALL (grade then rolled from the boss
# table) — preserved from the old B@1/3 channel so gear FREQUENCY is unchanged,
# only the tier ladder moved. Set to 1.0 to make every boss drop gear.
const BOSS_GEAR_CHANCE := 1.0 / 3.0

static func gear_weights(chid: String) -> Dictionary:
	return CHAPTER_GEAR_WEIGHTS.get(chid, CHAPTER_GEAR_WEIGHTS[RICHEST_CH])
static func boss_weights(chid: String) -> Dictionary:
	return CHAPTER_BOSS_WEIGHTS.get(chid, CHAPTER_BOSS_WEIGHTS[RICHEST_CH])

## Weighted grade pick from a {grade: weight} table.
static func roll_weighted_grade(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var pick := rng.randf() * total
	for grade in weights:
		pick -= float(weights[grade])
		if pick <= 0.0:
			return String(grade)
	return String(weights.keys()[0])

## Best grade a GENERAL roll can yield (chest/shop/gamble/spoils) — what
## game.loot_cap() returns for pricing probes.
static func chapter_gear_ceiling(chid: String) -> String:
	return _ceiling_of(gear_weights(chid))
static func _ceiling_of(weights: Dictionary) -> String:
	var best := "F"
	for g in weights:
		if GEAR_TIER_ORDER.find(String(g)) > GEAR_TIER_ORDER.find(best):
			best = String(g)
	return best
# Bags are inventory expansion, not needed every run: a SEPARATE, rarer roll
# than gear (round 51b — the per-gear-grade bag roll felt spammy). Chance stays
# a per-ACT knob; the GRADE now follows the chapter's BOSS table (2026-07-09) —
# a bag is boss-tier loot wherever it comes from (drop, elite, or shop shelf).
# dupes still cash at BAG_SELL_GOLD (a 6th bag keeps the best MAX_BAGS).
const BAG_DROP_CHANCE := {1: 0.10, 2: 0.09, 3: 0.08}
# Merchants stock bags too (round 52; repriced up ~5x): capacity is QoL, not
# power — but a bag is a RARE drop, so buying one is a real gold DECISION, a
# meaningful chunk of a chapter's income yet still well under same-grade gear
# farm-cost (rarity is the reason to buy, so price — not drop rate — is the
# lever; never a paywall). Flat per-tier (act-gating encodes progression); buy
# dwarfs the 1g sell. Curve anchored to econ_audit income + gear/reforge sinks.
const BAG_BUY_PRICE := {"F": 150, "E": 250, "D": 400, "C": 650, "B": 1000, "A": 1600, "S": 2600}
const SHOP_BAG_COUNT := {1: [1, 1], 2: [1, 2], 3: [1, 2]}

## Per-boss bag drop chance for an act (round 52; chance only — grade is chapter).
static func bag_drop_chance(act: int) -> float:
	return float(BAG_DROP_CHANCE.get(clampi(act, 1, 3), 0.0))

## Roll a bag GRADE from the chapter's BOSS table (2026-07-09): bags are the
## exception to the general/boss split — every bag source (drop, elite, shop)
## rolls the boss-tier grade for that chapter.
static func roll_bag_grade(chid: String, rng: RandomNumberGenerator) -> String:
	return roll_weighted_grade(boss_weights(chid), rng)

# DISCARD-throw (round 52): a bag item flung out to free a slot. It sails a
# short arc away, then ignores pickup for a beat so it doesn't re-collect the
# instant you're standing on it. Registered like any drop -> mails at chapter
# end (never silently lost).
const DISCARD_THROW_DIST := 96.0
const DISCARD_NO_PICKUP_TIME := 1.5
# SHOP gear now rolls the chapter's GENERAL band (Items.roll_shop_grade) — the
# old per-act appearance weights are folded into CHAPTER_GEAR_WEIGHTS above.
# GEM levels by act: elite/boss drop floor, and shop stock range [lo, hi].
const GEM_ACT_LEVEL := {1: 1, 2: 2, 3: 5}
const SHOP_GEM_RANGE := {1: [1, 1], 2: [2, 4], 3: [5, 7]}
const BOSS_FIRST_CLEAR_GEM_BONUS := 1                   # first-clear catch-up bundle rolls +1 level
# Gem gating by chapter (2026-07-09): REGULAR gems start at ch4 (ch1-3 teach the
# gear tiers first, undiluted); SPECIAL-stat gems (Haste/CDR/Combo/Lifesteal/
# Tenacity/Dmg%) start at ch6 — the same chapter A-grade gear (with its special
# slot) begins dropping, so a special gem is socketable the moment it appears.
const REGULAR_GEM_START_CH := 4
const SPECIAL_GEM_START_CH := 6
static func chapter_num(chid: String) -> int:
	return int(chid.trim_prefix("ch")) if chid.begins_with("ch") else 0
static func regular_gems_drop(chid: String) -> bool:
	return chapter_num(chid) >= REGULAR_GEM_START_CH
static func special_gems_drop(chid: String) -> bool:
	return chapter_num(chid) >= SPECIAL_GEM_START_CH

# Smith UPGRADE curve. Per-step cost = UPGRADE_BASE * UPGRADE_GRADE_FACTOR[grade]
# * (1+plus)^UPGRADE_COST_EXP — grade doubles per tier (an S step is 8x a C step
# at equal plus) and the ^1.5 exponent makes each successive plus bite harder.
# Base tuned so C/S +0->+1 = 24/192g. Reworked 2026-07-13 (upgrade-rework round):
# +plus grants +5% to every rolled stat (UPGRADE_PCT_PER_PLUS), is CAPPED per
# grade (MAX_PLUS), and past the guaranteed floor each attempt can FAIL
# (upgrade_success). A failed attempt costs the gold but the item KEEPS its
# current plus — no downgrade (2026-07-13: downgrade made S->max a ~1.2M grind).
const UPGRADE_BASE := 12.0
const UPGRADE_GRADE_FACTOR := {"F": 0.5, "E": 0.75, "D": 1.0, "C": 2.0, "B": 4.0, "A": 8.0, "S": 16.0}
const UPGRADE_COST_EXP := 1.5              # >1 => per-step cost climbs super-linearly with plus
const UPGRADE_PCT_PER_PLUS := 0.05         # per plus, applied to EVERY rolled stat on the gear (main + subs, not gems). Cap/cost/failure are the guardrails.

# Add-gem-socket is a ONE-TIME craft that PERMANENTLY grows a piece's power (a
# whole extra gem forever), so it is priced as a heavy endgame commitment — not
# something an early player can casually buy on their best gear. Tier-scaled hard:
# an S socket costs ~16 full ch1 clears. F/E/D never socket; S ships at the cap
# but can reforge a 4th (MAX_SOCKETS 4). 2026-07-13: 6k was far too cheap.
const ADD_SOCKET_COST := {"C": 2500, "B": 7000, "A": 18000, "S": 40000}

# Quenching: reroll ONE stat's band position, KEEPING the higher of old/new — a
# repeatable, never-regressing grind to perfect a roll. EXPENSIVE by design
# (2026-07-13): cheap to lift a bad roll off the floor, but the per-pull cost
# ESCALATES toward the band max — base x (1 + ESCALATION x band-fraction) — so
# squeezing out the last few % (true min-maxing) costs real gold. Tier-scaled.
const QUENCH_COST_BASE := {"F": 20, "E": 35, "D": 60, "C": 120, "B": 280, "A": 600, "S": 1100}
const QUENCH_COST_ESCALATION := 4.0        # per-pull cost at the band MAX = base x (1 + this)
const MAX_PLUS := {"F": 5, "E": 6, "D": 8, "C": 10, "B": 12, "A": 15, "S": 20}
# Random substats an S legendary rolls. The old formula `(find(S)-1)/2` truncated
# to 2, but the design intent was always 3 (an off-by-one) — restored here now that
# pinned synergy subs are gone, so S gets its documented stat weight, all random +
# rerollable. Other grades still use the formula (F/E/D:0, C/B:1, A:2).
const S_SUB_COUNT := 3
const UPGRADE_SAFE_PLUS := 4               # +1..+4 are guaranteed (attempts never fail at/below this)
const UPGRADE_FAIL_PER_PLUS := 0.04        # success drops this much per plus past the safe floor
const UPGRADE_MIN_SUCCESS := 0.40          # success never falls below this (reached at the S cap)

## Smith upgrade cap for a grade — plus may climb no higher than this.
static func max_plus(grade: String) -> int:
	return int(MAX_PLUS.get(grade, 10))

## Success chance of the attempt taking an item FROM `plus` to `plus+1`.
## Guaranteed through the safe floor, then slides to UPGRADE_MIN_SUCCESS at the cap.
static func upgrade_success(plus: int) -> float:
	if plus < UPGRADE_SAFE_PLUS:
		return 1.0
	return clampf(1.0 - UPGRADE_FAIL_PER_PLUS * float(plus - UPGRADE_SAFE_PLUS + 1), UPGRADE_MIN_SUCCESS, 1.0)

# Measured per-chapter run economy (from econ_audit.gd — RE-RUN and update
# these when reward numbers move; they drive every farm-cost price). "gems" is
# gems per REPLAY run (the gem-price denominator).
# 2026-07-09: remeasured under the per-chapter loot BANDS (gear sells for its
# rolled-tier value, not an act cap) — early chapters fell (F/E/D drop cheaper),
# ch7 is ~flat. Gems are GATED to ch4+ (regular_gems_drop), so ch1-3 = 0 (their
# gem-price denominator is unused — the shop stocks no gems there).
const CHAPTER_ECON := {
	"ch1": {"act": 1, "first": 1545, "replay": 1228, "gems": 0.0},
	"ch2": {"act": 1, "first": 1574, "replay": 1148, "gems": 0.0},
	"ch3": {"act": 1, "first": 2758, "replay": 2222, "gems": 0.0},
	"ch4": {"act": 1, "first": 3344, "replay": 2698, "gems": 19.4},
	"ch5": {"act": 1, "first": 3987, "replay": 3249, "gems": 19.4},
	"ch6": {"act": 1, "first": 4871, "replay": 4060, "gems": 19.6},
	"ch7": {"act": 1, "first": 6616, "replay": 5733, "gems": 19.9},
}

static func gem_gold_value(lvl: int) -> float:
	return GEM_GOLD_BASE * pow(GEM_GOLD_PER_LEVEL, float(maxi(lvl - 1, 0)))

## Per-boss GEAR drop odds ({grade: chance}) — derived from the chapter's BOSS
## weight table x BOSS_GEAR_CHANCE. Used for shop farm-cost pricing; the actual
## drop is rolled in Items.roll_boss_gear_grade.
static func boss_gear_odds(chid: String) -> Dictionary:
	var w := boss_weights(chid)
	var total := 0.0
	for v in w.values():
		total += float(v)
	var out := {}
	if total <= 0.0:
		return out
	for g in w:
		out[String(g)] = BOSS_GEAR_CHANCE * float(w[g]) / total
	return out

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
	# 1e-9 epsilon: derived odds (BOSS_GEAR_CHANCE x weight/total) can land a hair
	# under a clean fraction, and a bare ceil() would then bill an extra farm run.
	return int(ceil((1.0 / chance) / float(BOSSES_PER_RUN) - 1e-9))

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
const KNIFE_THROW_RELEASE := 0.15 # delay the knives to the THROW anim's release (arm-forward), so the blades leave the HAND, not the input frame
const STAB_STRIKE_DELAY := 0.10   # delay the stab's cut/slash to the lunge frame, so the hit lands WITH the thrust, not on the input frame
const PALADIN_SMITE_DELAY := 0.16 # delay Judgment/Consecration impact FX+damage to the warhammer's slam frame (the heavy overhead swing has a real windup — FX on the input frame reads ahead of the animation)
const WARRIOR_SWING_DELAY := 0.13 # delay Cleave's cut/quake to the sword swing's contact frame (same windup-vs-FX sync)
const MAGE_BOLT_DELAY := 0.12     # delay Firebolt to the staff-thrust release frame (same windup-vs-FX sync)
const ARCHER_LOOSE_DELAY := 0.25  # delay Quick Shot / Multishot / Arrow Storm to the bow's draw-release frame (~frame 7 of the re-rolled 9-frame draw@22fps — the string snaps forward at t≈0.25; 0.12 loosed mid-draw)
const WARLOCK_CAST_DELAY := 0.16  # delay Shadowbolt / Hex to the arm-snap/sigil-projection frame (~frame 4 of the re-rolled upright cast; Dark Pact = self-buff stays instant; Void Rift self-sequences via its telegraph)
const PHANTOM_ULT_SPLASH_OPACITY := 0.10        # Phantom ult: the splash-art screen wash opacity
const PHANTOM_ULT_SPLASH_OPACITY_BRIGHT := 0.15 # +5% on "bright" maps (light backdrops wash the wash out)
# Bosses got v3 ability strips (a real swing/cast windup) — same rule as the
# classes. BOSS_ABILITY_FPS plays the ~7-frame one-shot snappily (~0.5s, not the
# 6fps 1.2s sluggard); BOSS_STRIKE_DELAY defers an IMMEDIATE bolt/ring/beam to
# the contact frame via Boss._strike(). Telegraphed abilities (game.telegraph)
# already carry their own windup — they stay instant, the telegraph IS the wind-up.
const BOSS_ABILITY_FPS := 14.0
const BOSS_STRIKE_DELAY := 0.16
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
# One-shot action clips play at a FIXED wall-clock duration (frames/fps), so a
# fast recast — high CDR, or the warrior's Berserk cadence (Cleave at 0.45s,
# less under cdr) — chops the swing before its follow-through. fit_action_clip
# re-paces the clip to finish inside its own cooldown; this caps how far it may
# be sped up so an ultra-short cd can't blur the swing into a strobe.
const ACTION_CLIP_MAX_HASTE := 2.6
# Shadow phantom step (2026-07-08): the dash arms a refund window instead of
# only refunding on the dash's OWN kill — ANY kill within this many seconds
# (the Fan or ult-stab that actually does the killing) slashes the dash cd.
# Fixes the feast-or-famine dash whose kills came from other buttons.
const PHANTOM_REFUND_WINDOW := 2.0

# ------------------------------------------------- archer hunt rhythm ---
# 2026-07-09: hunt a1's free +25% CAP-EXEMPT crit made built crit gear
# redundant (~60% effective on a 0.36s spam). Replaced with an EARNED
# rhythm: every Nth hunt Quick Shot is a GUARANTEED crit (cap-exempt by
# nature — it's guaranteed); gear crit carries the other N-1 shots.
const HUNT_RHYTHM_SHOTS := 4

# ------------------------------------------------------- paladin stances ---
# Round 48: the paladin is a STANCE knight — no true ult. Conviction (the
# ult slot, 8s cd) swaps Holy <-> Retribution: sustain and damage become
# mutually exclusive IN TIME, so reading the fight (when to be which) is the
# skill. Braindead pilots camp Holy (safe, slow); good ones camp Retribution
# and flick out under pressure — the reward curve lives in stance uptime.
const PALADIN_HOLY_DMG := 0.90      # Holy stance: damage dealt multiplier (softened 0.80->0.90 in the 2026-07-13 rework — Holy now banks smite damage via overheal, so its stance penalty needn't double-punish the dance)
const PALADIN_HOLY_MEND := 0.01     # Holy stance: max-HP fraction mended per hit landed
const PALADIN_RETRI_DMG := 1.25     # Retribution stance: damage dealt multiplier
const PALADIN_SWAP_HEAL := 0.10     # entering Holy: blessing burst (max-HP fraction)
const PALADIN_SWAP_CHAINS := 0.5    # entering Retribution: chains cast at this scale
# Paladin rework (2026-07-13): make the class's IDENTITY deal damage, fixing its
# bottom-of-the-chart DPS without a boring coefficient bump.
# ZEAL — swapping INTO Retribution ignites a burst window; camping never
# re-triggers it, so damage rewards ACTIVE stance-dancing (a skill ceiling).
# ZEAL is the PRIMARY lift and rewards ACTIVE stance-dancing: it fires on every
# swap INTO Retribution and holds the whole Retri phase (cleared on the swap back
# to Holy), so camping Retri lets it expire — you must keep swapping to keep it.
# HP-independent, so the (never-hit) bench dummy measures it honestly.
const PALADIN_ZEAL_DMG := 0.80      # +damage while Zeal is up (a swap into Retribution)
const PALADIN_ZEAL_DUR := 8.0       # Zeal duration — covers a full Retri phase (~the ult cd)
# OVERHEAL -> SMITE is now a small FLAVOR bonus only (not the lift): healing
# wasted at full HP banks a little smite for the next Judgment. Deliberately
# minor — in real endgame you rarely overheal (heals go to survival), and the
# bench dummy never hits, so this must NOT carry the paladin's damage.
const PALADIN_OVERHEAL_DMG := 0.8   # overheal-HP x this = smite damage banked
const PALADIN_CHARGE_CAP := 2.0     # Holy Charge caps low (x ATK) — a topped-off bonus, not a backbone
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
# Cleave's cd FLOOR (2026-07-09): cdr/haste can pull Cleave's 0.74 base down to
# here and no further (Berserk bypasses it). ~ the L40 cdr'd value, so at-level
# play is untouched but stacked ENDGAME cdr can't spin the basic to a caster's
# tempo — the "plate hits hard, not fast" cap that keeps warrior off the top of
# the endgame charts without gutting its L40 slot.
const CLEAVE_FLOOR_CD := 0.66

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

# --- aggro: line-of-sight + leash (2026-07-09) ---
# Mobs can't pathfind (straight-line chase + move_and_slide), so aggro is
# gated on SIGHT: a mob only wakes when it can trace a clear line to you (no
# wall between), and a woken mob that loses sight for MOB_AGGRO_LEASH seconds
# gives up and returns home instead of grinding a wall forever. KEEP widens
# the hold range past aggro so an edge target doesn't flicker.
const MOB_AGGRO_LEASH := 1.6    # seconds blind before a woken mob deaggros
const MOB_AGGRO_KEEP := 1.5     # hold-aggro range = aggro_range * this
# Sticky targeting (MP phase 0, MULTIPLAYER.md §5.2): enemies/bosses
# re-resolve their prey via game.pick_target() on this cadence — never
# per-frame, so future packs don't oscillate between players. Solo:
# always the same one player, so the knob is inert until co-op exists.
const MOB_RETARGET_EVERY := 1.0 # seconds between sticky target re-picks
# Pack cascade: when a pack is wiped, the NEXT-nearest sleeping pack in the
# room gains awareness and comes to you (the room "hears" the fight) — no
# hunting stragglers across a large arena. First pack still wakes by sight.

# --- obstacle avoidance (2026-07-12) ---
# Chase is a straight line (no navmesh, see above); without help a mob/boss
# wedges into a tree/building/wall-corner between it and its prey and jitters
# as the steering oscillates. enemy._avoid_obstacles casts a feeler ray ahead
# and, when blocked, fans outward to the nearest CLEAR heading. LOOKAHEAD is
# added to the body half-width for the feeler length; FAN is the turn angles
# (radians, smallest first) it tries. MAX_SPEED gates it OFF for committed
# dashes (charge/pounce run far faster than any walk speed — those should
# connect, not curve around cover).
const MOB_AVOID_LOOKAHEAD := 24.0
const MOB_AVOID_FAN: Array[float] = [0.6, 1.2, 1.9]  # ~34°, 69°, 109°
const MOB_AVOID_MAX_SPEED := 1.5   # skip avoidance above walk_speed * this

# Reposition-to-fire (enemy._reacquire_shot): a ranged shooter (mob, or a
# ranged boss) whose LINE to the prey is blocked by terrain sidesteps to open
# a clean lane instead of looseing a bolt into a wall — a hostile bolt collides
# with layer 1. SPEED is the sidestep fraction of walk speed; PROBE is how far
# to each flank it tests a would-be-clear lane before committing that way.
const MOB_REPOSITION_SPEED := 0.7
const MOB_REPOSITION_PROBE := 40.0

# Charge lane-check (Boss._do_charge -> _clear_charge_dir): a melee charge
# picks a heading whose lane is clear this far ahead (capped at the distance to
# the prey) so it doesn't bash a wall/prop; FAN is the small cone (radians,
# both ways) it tries when the straight line is blocked before it aborts.
const BOSS_CHARGE_LANE := 300.0
const BOSS_CHARGE_FAN: Array[float] = [0.35, 0.7]  # ~20°, 40°

# --- co-op party scaling (MULTIPLAYER.md §5.2) ---
# Applied per spawn in add_enemy, riding beside weekly_fx. Indexed by party
# size; [0] unused, [1] = 1.0 so SOLO IS UNTOUCHED BY CONSTRUCTION. HP scales
# near-linearly but slightly under (+90%/head: 4 players bring ~4x DPS plus
# stacked-debuff synergy; co-op should feel a touch generous). Damage rises
# only mildly — aggro splits across the party, so per-player pressure already
# drops; the real 4-player threat is boss cadence (PARTY_BOSS_RATE, consumed
# in phase 2/3), never mob one-shots. Opening bids — measure-then-correct.
const PARTY_HP_MULT: Array[float] = [0.0, 1.0, 1.90, 2.80, 3.70]
const PARTY_DMG_MULT: Array[float] = [0.0, 1.0, 1.10, 1.20, 1.30]
const PARTY_BOSS_RATE: Array[float] = [0.0, 1.0, 1.10, 1.20, 1.30]  # boss cast cadence (consumed at Boss._think's shared cd tick, MP-09)

static func party_hp(n: int) -> float:
	return PARTY_HP_MULT[clampi(n, 1, 4)]

static func party_dmg(n: int) -> float:
	return PARTY_DMG_MULT[clampi(n, 1, 4)]

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
# Windrunner (archer capstone talent): DR window after a Tumble roll —
# defense EARNED by dodging (dominated-cell rework 2026-07-09).
const TUMBLE_DR_DUR := 3.0
# skirmish (2026-07-09 mob-distribution pass): a ranged mob that actually
# KITES — full-speed backpedal with a strafing arc inside KEEP, advances past
# FAR, holds and fires in the band between. Regular ranged mobs shuffle at
# 0.8x inside 200px, which a 250-speed player just walks down; a skirmisher
# needs chasing into a corner (cornering it is the counterplay).
const MOB_SKIRMISH_KEEP := 280.0
const MOB_SKIRMISH_FAR := 400.0
const MOB_SKIRMISH_STRAFE := 0.45   # orthogonal drift while backpedaling (arcs, not lines)
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
# Saint Varo (ch3): the enthroned relic does not walk — in his THRONE phase he
# RELOCATES by teleport every few seconds (sitting idle only). Faster once he
# has stood (enraged) but there he walks, so this only gates the throne blink.
const VARO_TELEPORT_CD := 4.5

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
# ROOM. The loadout holds this many slots; each slot is a potion type
# (duplicates fine — 3x health is a plan), unassigned slots default
# to health. Entering a room refills the budget; each drink spends a
# slot; an empty loadout locks Q until the next room. Pre-planning IS
# the skill: bag carrying is uncapped (stacks), the fight is not.
# CHAPTER-BANDED (2026-07-09; replaces the act table — act 1 spans seven
# chapters, one flat cap couldn't ramp): ch1-2 teach with 1, ch3-4 midgame
# 2, ch5-7 act-1 endgame 3. Acts 2/3 hold the latent 4/5 below.
const POTION_SLOTS := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 3}
const POTION_SLOTS_ACT2 := 4   # ch8-11 (latent until Act 2 is built)
const POTION_SLOTS_ACT3 := 5   # ch12+  (latent until Act 3 is built)

static func potion_slots(chid: String) -> int:
	var n := chapter_num(chid)
	if n >= 12:
		return POTION_SLOTS_ACT3
	if n >= 8:
		return POTION_SLOTS_ACT2
	return int(POTION_SLOTS.get(clampi(n, 1, 7), 1))

# Chest on-screen size (grade-telegraphed chests, 2026-07-10): the
# footprint the old 16px tier art had at scale 3. Art.scale_for keeps it
# constant however large the authored chest_<grade>.png happens to be.
const CHEST_SCALE_16PX := 3.0
# Halo alpha on B+ chests — the "rich chest across the room" tell.
const CHEST_HALO_ALPHA := 0.5
# How far a chest's art is washed toward its grade colour (0 = raw art).
const CHEST_GRADE_TINT := 0.3

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

# (Act loot ceilings retired 2026-07-09 — the per-chapter band tables above own
# the ceiling now; game.loot_cap() reads Balance.chapter_gear_ceiling.)

# Anti-degeneracy stat caps (player-designed, 2026-07-06): the
# SPECIAL stats — Haste, Lifesteal, Combo, Tenacity, Dmg% — are GEM-ONLY (never
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
# INT casters (mage/warlock) get MORE out of haste as they level — the endgame
# throughput fix. They lack the AGI classes' multiplicative crit/rate stacking, so
# their damage falls off at the gear ceiling (early top-of-pack -> late bottom). Haste
# (Sapphire gem + tree cdr) is their rate lever: for a caster it's worth up to this
# much MORE at LEVEL_CAP, scaling ~linearly from ~0 at L1 (so early game — where
# casters are already strong — is untouched). Lifts the cdr VALUE and its soft cap
# together, so a stacked endgame caster gets both more haste and a higher ceiling.
# Ults still ignore haste regardless. Applied in player_core recalc.
const CASTER_HASTE_BONUS := 0.25
# Mage/warlock S weapon (wellspring / voidmaw): their basic bolt (Firebolt /
# Shadowbolt) cools down this much faster — an endgame throughput reward on the
# awakened weapon, ON TOP of the weapon's other S-passive effect. Applied in
# ability_cd (stacks multiplicatively with cdr, before the flat-haste term).
const S_CASTER_BOLT_CDR := 0.08
const CAP_LIFESTEAL := 0.35  # knee on the TOTAL incl. surges/berserk/pact
const CAP_COMBO := 0.30
const CAP_CRIT := 0.35       # the old 70%-curve was far too generous
const CAP_EVA := 0.50        # nothing approaches unhittable
const CAP_GREED := 0.40
const CAP_RES_FRAC := 0.80   # damage REDUCTION knee: >80% pays 1/10
# SPECIAL gem stats (2026-07-08): gem-ONLY, and each lives in the dedicated
# A+ SPECIAL slot, ONE gem of each stat across your whole loadout (not a
# stack). `dmg_pct` (Sunstone) is the UNIVERSAL damage special — it replaced
# the crit-only crit_dmg gem so the forced special slot lifts every class,
# not just crit builds. crit_dmg is now gem-less (base + talents only) and
# stripped from gear.
const SPECIAL_GEM_STATS := ["cdr", "lifesteal", "combo", "flat_dr", "dmg_pct"]  # flat_dr = Tenacity gem (DR); greed retired from gems (2026-07-09)

# PLATE res→damage (2026-07-08): warrior/paladin convert their (over-stacked,
# past-the-knee) resistance into a little DAMAGE — a scaling axis on a stat
# they already accumulate, the flat-class answer to crit's crit_dmg. Tuned
# SMALL and CAPPED so a tank never tops the dps charts (ranged/assassin still
# out-dps them on bosses) — it lifts their floor, it isn't 1M armor = 1M dmg.
# LOG curve (2026-07-09): bonus = LOG * ln(1 + res*K), min'd with CAP. Diminishing
# returns — rises fast off low res (the floor lift), then flattens hard so endgame
# res stacking can't snowball plate to the top of the charts. At res 100 ~ +5.5%,
# res 190 ~ +6.9%, res 350 ~ +8.4% (vs the old linear's +10 / +19 / +30%).
# Plate flat DR is EARNED by resistance (2026-07-09), not a flat handout: it
# ramps 0 -> PLATE_DR_MAX as the class's SIGNATURE res (warrior physres, paladin
# magres) climbs to PLATE_DR_FULL_RES. Bare-armored early plate blocks almost
# nothing (has to respect mechanics); a res wall blocks the full 15%. Fixes the
# early faceroll and puts tankiness on the gear/investment-gated res curve.
const PLATE_DR_MAX := 0.15
const PLATE_DR_FULL_RES := 130.0     # signature res that grants the full DR
const PLATE_RES_DMG_LOG := 0.025     # log coefficient
const PLATE_RES_DMG_K := 0.08        # res sensitivity inside the log
const PLATE_RES_DMG_CAP := 0.15      # hard ceiling (halved from the old 0.30)

# Boss gem-expectation ramp (player-approved, 2026-07-06): the TIERLIST
# benchmark was gemless, but real players arrive with sockets filled —
# boss hp/dmg gain a small compounding premium per level above the ramp
# start (where B-gear sockets + Lv3 gems realistically come online), the
# same "budget for what the player actually has" move as round 45's
# gear-inclusive dps. Applied inside enemy_stats_at: codex stays honest.
const BOSS_GEM_RAMP_START := 32
# FOLDED into BOSS_HP_GROWTH / BOSS_DMG_GROWTH (2026-07-09): the gem premium was
# a second per-level scaler that double-counted with a player-curve calibration
# (the L100 player already has Lv10 gems). Zeroed so scaling is one clean dial
# per axis; the growth rates were set to include the gemmed player curve.
const BOSS_GEM_HP_RAMP := 0.0
const BOSS_GEM_DMG_RAMP := 0.0

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
# Chance-based chest drops from trash (Greed nudges these up from its first point).
const MOB_SILVER_CHEST_CHANCE := 0.04
const MOB_WOOD_CHEST_CHANCE := 0.18

# GOLD RUSH (2026-07-09): the greed stat's ONLY source since the gem
# retired for Tenacity — greed is deliberately a FARM-EVENT stat, never a
# build stat (it was DPS-dead as a gem). A paying trash kill rarely spills
# a charged coin; touching it surges greed for a window (auto-triggers,
# never a bag item, refresh-don't-stack). Drop-only, never sold — buying
# gold% with gold is a dead loop; a surprise mid-farm window is the point.
# ~1 coin/replay run at 0.01 over ~110 paying kills; ~8% uptime x ~30%
# on gained gold ≈ +2-3% run income — a felt beat, not an economy dial.
# (Distinct from the WEEKLY "Gilded Blood" modifier, which scales kill
# gold at the drop; this one rides the greed stat at the gain.)
const GOLDRUSH_GREED := 0.30        # greed surge while the window holds
const GOLDRUSH_DUR := 150.0         # seconds
const GOLDRUSH_DROP_CHANCE := 0.01  # per paying trash kill

# ------------------------------------------------------ hero resources ---
const POTION_MAX := 5
# (BOSS_KILL_POTION_FLOOR retired 2026-07-09: boss kills no longer restock
# potions — stock is bought, an investment, never a handout.)

# ------------------------------------------------- resonance rewards ---
# A shard choice in a quiet room pays either way (conviction, not
# virtue): gold scaled by |delta|, a chest at bigger shifts.
const RES_REWARD_GOLD_BASE := 8
const RES_REWARD_GOLD_PER_POINT := 2
const RES_REWARD_CHEST_AT := 5.0     # |delta| >= this -> wood chest
const RES_REWARD_SILVER_AT := 8.0    # |delta| >= this -> silver chest

# --------------------------------------------- resonance band leans ---
# Conviction-scaled leans (2026-07-09): a small passive rider whose
# STRENGTH ramps with |resonance| — zero through the neutral band, waking
# at the band line and maxing at full conviction — and whose FLAVOR is
# the sign. No correct band ("conviction, not virtue"): Virtue mends
# (Constancy: potions heal deeper, on top of the steady haggle), while
# Temptation hunts (Hunger: execute damage vs wounded MOBS — never
# bosses, their execute windows stay design-owned — plus kill gold, the
# earn-side mirror of steady's spend-side 0.9 haggle). Undecided lends
# NOTHING — that emptiness is the pull. Autotest and dps_bench PIN
# resonance to 0 so the leans never skew a benchmark silently.
const RES_LEAN_START := 25.0   # keep in sync with Story.RES_BAND_AT
const RES_LEAN_FULL := 100.0
const RES_HUNGER_EXEC_MAX := 0.10     # dmg vs mobs below the wound line, at full lean
const RES_HUNGER_EXEC_AT := 0.25      # mob hp fraction that counts as "wounded"
const RES_HUNGER_GOLD_MAX := 0.15     # bonus KILL gold at full lean
const RES_CONSTANCY_HEAL_MAX := 0.25  # bonus potion healing at full lean
# Potion heals are MISSING-hp based (2026-07-09 rebalance): a 60%-of-max heal
# ERASED a mistake; a helping hand mends a fraction of what you've LOST — worth
# the most at death's door, worth nothing to a topped-off facetank.
const POTION_HEAL_FRAC := 0.15        # health potion: fraction of MISSING hp (a hand up, never a crutch)

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
const MANA_POTION_FRAC := 0.3    # restores this fraction of MISSING mana (mirrors the health potion)
const ELIXIR_MIGHT_AMT := 0.12   # +12% damage while the elixir holds
const ELIXIR_MIGHT_DUR := 5.0    # a BURST WINDOW, not a whole boss fight (2026-07-09: 20%/30s was a fight-long free multiplier)
# Round 50 additions — a defensive elixir (mirrors Might on the dr_ system)
# and a burst bag-heal (distinct from the 5-cap health-potion counter, and
# not budgeted by it — a real reason to spend at the alchemist's shelf).
const ELIXIR_WARD_AMT := 0.25    # incoming non-true damage cut while it holds
const ELIXIR_WARD_DUR := 20.0    # seconds
const RENEWAL_HEAL_FRAC := 0.3   # instant heal, fraction of MAX hp — the premium flask (shares the drink cd; level-priced ~2.5x a potion)
# BASE prices (L1). The whole shelf LEVEL-SCALES like the health potion
# (2026-07-09: flat prices went dirt-cheap against level-scaled income — a
# 90g renewal at L40 was stronger AND cheaper than a health potion). SELL
# stays on the flat base (menus.gd) so nothing hauls for profit.
const CONSUMABLE_PRICES := {"mana_potion": 60, "elixir_might": 130, "recall_scroll": 55,
	"elixir_ward": 110, "renewal_draught": 150}

static func consumable_price(id: String, level: int) -> int:
	return int(round(float(CONSUMABLE_PRICES[id]) * (1.0 + POTION_PRICE_PER_LEVEL * float(maxi(level, 1) - 1))))

# Gambling vendor (reworked 2026-07-09): the PITY machine — a gamble rolls
# from the chapter's BOSS band (CHAPTER_BOSS_WEIGHTS), priced at the boss-
# table-weighted EXPECTED farm cost x GAMBLE_DISCOUNT. Formula + knob live
# in game_base.gamble_cost / GAMBLE_DISCOUNT above. (The old flat per-tier
# GAMBLE_COST table was dead code and is deleted.)

# ----------------------------------------------------------------- rooms ---
# Quiet room types shrink their walled playable area within the fixed
# grid cell (corridors connect the doors to the cell edges).
const SMALL_ROOM_TYPES := ["social", "dead_end", "resonance", "merchant"]
const SMALL_ROOM_INSET := Vector2(420.0, 246.0)

# Scenery density (anti-litter pass 2026-07-12): a room's props were reading
# as clutter — the graveyard's 8-kind roster and the forests' big canopies
# piled up. These are the four knobs _spawn_scenery multiplies against; tune
# here, never inline. Ground decor = DECOR_BASE x area_frac (non-colliding).
# Obstacles = terrain "count" x OBSTACLE_MULT x area_frac, each kept
# MIN_SPACING apart across PLACE_TRIES attempts. Trees/crypts render ~144px
# wide, so MIN_SPACING must exceed a trunk-to-trunk gap or canopies merge.
const SCENERY_DECOR_BASE := 42.0     # was 58 — thinned the ground litter
const SCENERY_OBSTACLE_MULT := 1.6   # was 2.2 — count 16 -> ~26, not ~36
const SCENERY_MIN_SPACING := 120.0   # was 85 — stops 144px canopies overlapping
const SCENERY_PLACE_TRIES := 48      # was 40 — tighter packing rejects more

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


# ============================================================= endgame modes ===
# The two post-Act-1 combat modes (ACT2_DESIGN.md §II), unlocked once the
# campaign's Act 1 (ch7) is cleared. Both run in ONE reused arena and drive
# their content in from Boss.make_boss / Enemy.make. Rewards ACCRUE through the
# run and pay at the end — a voluntary cash-out pays in full, a death pays at a
# penalty (the death gold tithe, extended). Neither mode pays XP (same rule as
# chapter replays). See endgame.gd for the controller.
const ENDGAME_UNLOCK_META := "unlocked_endgame"  # meta.json flag, set on first ch7 clear
const ENDGAME_DEATH_PENALTY := 0.75    # a death still cashes out, at 75% (ACT2 §II)
const ENDGAME_ARENA_TERRAINS := ["magma", "ice", "bog", "storm", "graveyard", "holy", "crystal", "void", "desert"]

# --- The Crucible (Boss Rush) ---
const CRUCIBLE_BOSSES := 10            # a full run is ten bosses back to back
const CRUCIBLE_MILESTONES := [3, 6, 10]  # milestone chests fall at these kill counts
# Per-boss gold climbs with how far you are: base × (1 + STEP × killsSoFar),
# then scaled by the arena level (daily_gold_mult).
const CRUCIBLE_GOLD_BASE := 120
const CRUCIBLE_GOLD_STEP := 0.35
const CRUCIBLE_CLEAR_GEAR_GRADE := "A"   # the 10-boss clear pays a boss-band piece

# --- The Waking Depths (Marathon) ---
const DEPTHS_BOSS_EVERY := 4           # every 4th room is a boss (checkpoint)
const DEPTHS_MOB_PER_ROOM := 1         # mobs scale +1 level per room descended
const DEPTHS_WAVE_SIZE := 4            # trash spawned per non-boss room
const DEPTHS_TERRAIN_ROTATE := 3       # re-theme the arena every N depths
const DEPTHS_GOLD_PER_DEPTH := 45      # linear-with-depth gold, scaled by level
const DEPTHS_MILESTONES := [12, 24, 36, 48]  # milestone chests at these depths
# Escalation tiers (ACT2 §II): the compound growth curve does most of the work;
# affix counts and the depth-37 pressure amp layer on top.
const DEPTHS_TIER_1AFFIX := 13         # from here, mobs carry 1 random affix
const DEPTHS_TIER_2AFFIX := 25         # mobs 2 affixes, bosses 1
const DEPTHS_TIER_PRESSURE := 37       # the player-debuff band opens here
const DEPTHS_TIER_MAX := 49            # mobs 3 affixes, bosses 2
# Player debuffs (ACT2 §II): from depth 37, one stacking debuff every 4 rooms,
# cycling −healing received → −damage dealt → +damage taken, forever.
const DEPTHS_DEBUFF_EVERY := 4         # a new debuff stack per this many depths past the line
const DEPTHS_DEBUFF_STEP := 0.10       # each stack is ±10%
const DEPTHS_DEBUFF_FLOOR := 0.20      # −healing/−damage can't drop a multiplier below this

# --- Elite affixes (ACT2 §VI) — spawn-time stat mutations, no per-frame hooks.
# Each carries a display name (worn on the bar), stat scalars, and traits to
# grant. Applied once when the boss/mob spawns (endgame.gd _apply_affix).
const AFFIXES := {
	"frenzied": {"name": "Frenzied", "dmg": 1.30, "speed": 1.20, "traits": ["frenzy"]},
	"bulwark":  {"name": "Bulwark", "hp": 1.70},
	"swift":    {"name": "Swift", "speed": 1.35, "traits": ["swift"]},
	"savage":   {"name": "Savage", "dmg": 1.55},
	"vampiric": {"name": "Vampiric", "dmg": 1.15, "traits": ["regen"]},
}
const AFFIX_KEYS := ["frenzied", "bulwark", "swift", "savage", "vampiric"]
const AFFIX_REGEN_FRAC := 0.02         # the "regen" trait (Vampiric): heal this fraction of max HP/s

## Gem level for endgame per-boss / milestone gems: the ch7 (Act-1 end) floor,
## climbing one level per 10 bosses/depths so a deep run sockets richer.
static func endgame_gem_level(progress: int) -> int:
	return gem_drop_level("ch7") + progress / 10
