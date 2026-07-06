class_name Balance
## Every cross-cutting TUNING KNOB in one place: curves, rates, chances
## and multipliers a designer reaches for. Structured DATA tables stay
## with their domain (classes.gd kits, items.gd gear tables, story.gd
## monsters/zones) — this file is for the numbers you tweak, not the
## content you author.

# ------------------------------------------------------ hero progression ---
# XP to go from `level` to the next: XP_BASE + level * XP_PER_LEVEL.
# The curve assumes side rooms are cleared (DESIGN.md); chapter kill-XP
# totals are authored against it — retune both together.
const XP_BASE := 30
const XP_PER_LEVEL := 22
const SKILL_POINTS_PER_LEVEL := 1
const ATTR_POINTS_PER_LEVEL := 1   # attributes AND substats spend from this pool
const STARTER_BAG_GRADE := "F"     # Items.BAG_SLOTS[F] = the old backpack cap

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
const KNIFE_BLOOM_MULT := 0.21    # poison's single heavy blade (was 0.34)
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
# warlock, capping at WITHER_MAX_STACKS (+48%). Trash never lives long
# enough to stack, so pack farming is untouched; long boss fights
# converge the class's weakest axis upward. Stacks die with the hex —
# letting the curse lapse resets the ramp, so upkeep IS the rotation.
const WITHER_STACK_EVERY := 6.0
const WITHER_PER_STACK := 0.06
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
# TOXIN (poison/venom themes): green DoTs are the exception to the
# no-stack burn rule — each application adds a stack that deepens the
# TICK (never the hit), so fast cadences finally get paid.
const TOXIN_PER_STACK := 0.08
const TOXIN_MAX_STACKS := 5
# BRITTLE (ice theme): cold cracks what it strikes — ice hits bite
# harder per stack, and ONLY ice hits (theme-internal: one poached ice
# slot amps nothing else).
const BRITTLE_PER_STACK := 0.04
const BRITTLE_MAX_STACKS := 5
const BRITTLE_DUR := 6.0
# CRUSH (void theme): void hits bite displaced targets — anything
# recently shoved/pulled hard (above ordinary hit-flinch, which peaks
# at 220) is "in motion against its will" for a short grace window.
const CRUSH_MULT := 0.25
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

# River wading (terrain mechanic, Graphics & Ambience track): speed
# multiplier in the water for player AND enemies; the bridge is dry.
# Gentle on purpose — a routing choice, not a punishment.
const RIVER_WADE_MULT := 0.72

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
# on gear; gems are the deliberate gateway to off-build stats), each
# item can socket at most ONE special gem, and the totals are hard-
# capped in recalc. Late game may lift the caps a notch by level
# (e.g. L80) — deliberately NOT built yet.
const CAP_CDR := 0.40        # was an implicit 0.45 (dash floor 1.49s -> 1.62s)
const CAP_LIFESTEAL := 0.35
const CAP_COMBO := 0.30
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
# character; lives in user://stash.json, not the per-character save).
const STASH_SLOTS := 200

# ------------------------------------------------------------ consumables ---
# Utility consumables beyond the health potion (bag items, used from the
# inventory). Prices are the merchant's base (before haggle); effects tuned
# to be handy, not build-warping.
const MANA_POTION_FRAC := 0.5    # restores this fraction of MAX mana
const ELIXIR_MIGHT_AMT := 0.20   # +20% damage while the elixir holds
const ELIXIR_MIGHT_DUR := 30.0   # seconds
const CONSUMABLE_PRICES := {"mana_potion": 35, "elixir_might": 130, "recall_scroll": 55}

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

# -------------------------------------------------------- codex completion ---
# Kill-count lore (retention roadmap #5): slaying enough of a monster kind
# unearths its codex lore entry; unearthed entries feed the Lorekeeper title.
const LORE_KILLS_MOB := 25         # kills to unearth a regular monster's lore
const LORE_KILLS_BOSS := 3         # bosses die once a run — 3 clears is devotion
