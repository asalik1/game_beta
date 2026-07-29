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
## Facing only flips on DECISIVE horizontal input; below this the last orientation
## holds. Kills the analog-joystick jitter where a near-vertical push wobbled dir.x's
## sign every frame and vibrated the sprite (keyboard input is discrete, never hit it).
const FACE_DEADZONE := 0.35

# ------------------------------------------------- character render scale ---
# Heroes and regular mobs are authored at ~200px but render small on screen, so
# the downscale decimates thin detail (a hero's sword blade in the E/W idle/walk
# poses dropped out and read as "cut off"). This multiplier enlarges the hero
# body target + its attachments (shadow, held weapon, aura) AND every enemy's
# visual (sprite, shadow, HP-bar height) — mobs AND bosses — by the SAME factor,
# so the whole cast keeps its relative proportion. Purely visual: collision
# radii, aggro/attack ranges and speeds are unchanged. Tune to taste; 1.0 = old size.
const CHAR_RENDER_SCALE := 1.7
# Structures y-sort over a hero who walks north of their base. Keep only a
# thin cool edge — clipped to the covering structure's own pixels, so just the
# HIDDEN part of the body reads back (owner 2026-07-28: full-body outline over
# a tombstone looked wrong, and 3.25 read too thick).
const PLAYER_OCCLUDED_OUTLINE_COLOR := Color(0.78, 0.94, 1.0, 0.60)
const PLAYER_OCCLUDED_OUTLINE_WIDTH := 1.75
const PLAYER_OCCLUSION_ALPHA_THRESHOLD := 0.16
const PLAYER_OCCLUSION_PROBES := [
	Vector2(-14, -20), Vector2(0, -20), Vector2(14, -20),
	Vector2(-12, -48), Vector2(0, -48), Vector2(12, -48),
	Vector2(0, -76)]

# SIZE VARIANCE (2026-07-17) — living-world scale spread so a pack isn't
# cardboard-cutout clones. BOSSES are exempt (fixed scale = their privilege).
# Mobs: DYNAMIC per-spawn bell-curve (avg common, extremes rare) — ±MOB, and
#   it couples to stats: HP full (x size), damage/speed at COUPLE of the size
#   deviation, speed INVERSE (a big mob is tankier + hits harder + slower; a
#   runt is frailer + softer + nimbler). Aggregate difficulty is unchanged —
#   the curve is centered on 1.0. Kept < ELITE_SPRITE_MULT so elites stay the
#   distinct "grew big enough to matter" tier.
const MOB_SIZE_VAR := 0.20            # ±20% (0.8–1.2x)
const MOB_SIZE_DMG_COUPLE := 0.5      # +20% size -> +10% dmg
const MOB_SIZE_SPEED_COUPLE := 0.5    # +20% size -> -10% speed (inverse)
# Heroes: FIXED per class (set once) — all human/elf, so a tight band; reads
#   as class identity (broad warrior, lean assassin). No stat coupling.
const HERO_CLASS_SIZE := {
	# Owner's height ladder (warlock = the ~average anchor at 1.0):
	# warrior > paladin > assassin > warlock > mage > archer. Tight human/elf
	# band; "lean" assassin is thin from the ART, this only sets HEIGHT.
	"warrior": 1.08, "paladin": 1.05, "assassin": 1.02,
	"warlock": 1.0, "mage": 0.98, "archer": 0.95,
}
# NPC height is authored for the live humanoid roster below. The retained
# generic variance applies only to non-person interactables and dev previews.
const NPC_SIZE_VAR := 0.12            # legacy non-person / placeholder fallback
# The warlock (1.0) is the adult-man baseline; the archer (0.95) is the
# adult-woman baseline. Conversation overrides cover every live named person
# whose shared temporary sprite would otherwise erase that distinction. Only
# a few lore-led outliers depart from the tight 0.92–1.04 adult band; no adult
# exceeds the warrior's 1.08 ceiling. Dev-only `npc_*` gallery art falls back
# to the hashed spread below and is deliberately not part of this roster.
const NPC_HEIGHT_BY_SPRITE := {
	"elder": 0.96, "merchant": 1.00, "sentry": 1.00, "archer": 0.98,
	"villager": 0.96, "warden": 0.98, "envoy": 0.97, "choirmother": 0.95,
	"beastkin": 0.98, "cultist": 0.98, "aldric": 0.99, "onna": 0.97,
	"piet": 1.00, "sera": 0.95, "callis": 0.95, "vessa": 0.98,
	"choir_pilgrim": 0.95, "caged_beastkin": 0.98, "suli": 0.96,
	"old_hunter": 0.98,
	"tinker_osla": 0.90, "ragged_soldier": 0.99, "flame_pilgrim": 0.96,
	"roadside_peddler": 1.00, "millers_boy": 0.88,
	"cantor_ilse": 0.94, "warden_corin": 1.00, "factor_imre": 0.97,
	"old_fenna": 0.92, "digger_haim": 0.95, "mute_mourner": 0.95,
	"brother_osk": 0.99, "archivist_lene": 0.95, "grave_goods_peddler": 0.96,
	"overseer_brann": 1.04, "envoy_cassia": 0.97, "warden_edda": 0.98,
	"smith_petra": 0.95, "smith_harl": 0.98, "clerk_voss": 0.99,
	"preacher_immo": 0.98, "peddler_nix": 0.96, "sapper_ruel": 0.97,
	"tracker_yri": 0.95, "warden_sighne": 0.95, "ansa_shore": 0.95,
	"mother_halla": 0.95, "skald_ottar": 1.00, "driver_pell": 0.99,
	"cartographer_bree": 0.95, "ridge_deserter": 0.99,
	"deacon_vela": 0.96, "herbalist_kesh": 0.99, "warden_palla": 0.95,
	"fisher_dov": 0.98, "blooming_convert": 0.98, "sister_ottilie": 0.94,
	"scout_renn": 0.98, "reed_cutter_ama": 0.94, "botanist_ferro": 0.99,
	"commander_ashe": 1.00, "consul_verane": 0.97, "apprentice_sorrel": 0.90,
	"keeper_vasse": 0.94, "storm_chaser_ilya": 0.98, "quartermaster_bel": 0.99,
	"bellringer_tam": 0.93, "undertaker_prue": 0.96,
}
const NPC_HEIGHT_BY_CONVO := {
	# Chapter 1 road people.
	"wander_tinker": 0.90, "wander_deserter": 0.99, "wander_pilgrim": 0.96,
	"wander_hunter": 0.98, "wander_peddler": 1.00, "wander_orphan": 0.88,
	# Maren's Camp.
	"maren": 0.96, "ch2_maren_hub": 0.96, "ch2_sentry": 1.00,
	"ch2_refugee": 0.95, "ch2_accord_recruit": 0.95,
	"ch2_cinder_recruit": 0.98, "ch2_beastkin_cage": 0.98,
	"ch2_choir_pilgrim": 0.95, "ch2_aldric": 0.99,
	# Vale.
	"ch3_briefing": 0.94, "ch3_accord": 1.00, "ch3_cinder": 0.97,
	"ch3_refugee": 0.92, "ch3_wander_digger": 0.95,
	"ch3_wander_mute": 0.95, "ch3_wander_defector": 0.99,
	"ch3_wander_archivist": 0.95, "ch3_wander_peddler": 0.96,
	# Foundry.
	"ch4_briefing": 1.04, "ch4_cinder": 0.97, "ch4_accord": 0.98,
	"ch4_survivor": 0.95, "ch4_shrine_court": 0.95, "ch4_wander_smith": 0.98,
	"ch4_wander_clerk": 0.99, "ch4_wander_preacher": 0.98,
	"ch4_wander_charms": 0.96, "ch4_wander_sapper": 0.97,
	# Frozen shore.
	"ch5_briefing": 0.95, "ch5_accord": 0.95, "ch5_cult": 0.96,
	"ch5_mother": 0.95, "ch5_wander_skald": 1.00,
	"ch5_wander_driver": 0.99, "ch5_wander_mapper": 0.95,
	"ch5_wander_memories": 0.97, "ch5_wander_deserter": 0.99,
	# The Deep.
	"ch6_briefing": 0.96, "ch6_wildfang": 0.99, "ch6_accord": 0.95,
	"ch6_fisher": 0.98, "ch6_wander_fisher": 0.94, "ch6_wander_convert": 0.98,
	"ch6_wander_doubter": 0.94, "ch6_wander_scout": 0.98,
	"ch6_wander_botanist": 0.99,
	# Last relay.
	"ch7_briefing": 0.96, "ch7_accord": 1.00, "ch7_cinder": 0.97,
	"ch7_apprentice": 0.90, "ch7_wander_keeper": 0.94, "ch7_wander_chaser": 0.98,
	"ch7_wander_quarter": 0.99, "ch7_wander_bellringer": 0.93,
	"ch7_wander_undertaker": 0.96,
}
# NPC on-screen size for legacy non-human interaction targets. The humanoid
# roster below is alpha-body normalized to the hero height ladder instead.
const NPC_RENDER_SCALE := 3.0
# Authored humanoid NPCs use their painted alpha body rather than their full
# transparent export canvas for sizing. Values are the pre-CHAR_RENDER_SCALE
# body height. The warlock (1.0 class-size anchor) is the baseline for an
# Emberfall citizen; the named profile tables above supply individual variation.
# This prevents a generous 256px export canvas from shrinking the person.
const NPC_BODY_TARGETS := {
	"elder": 52.0, "villager": 52.0, "sentry": 52.0, "merchant": 52.0,
	"archer": 52.0, "warden": 52.0, "envoy": 52.0, "choirmother": 52.0,
	"beastkin": 52.0, "cultist": 52.0, "aldric": 52.0, "onna": 52.0,
	"pilgrims_schism": 58.0, # static two-pilgrim + bread-table interaction tableau
	"capital_vault_chest": 42.0, # premium Artisans' Court storage coffer
	"piet": 52.0, "sera": 52.0, "callis": 52.0, "vessa": 52.0,
	"choir_pilgrim": 52.0, "caged_beastkin": 52.0, "suli": 52.0,
	"old_hunter": 52.0,
	"tinker_osla": 52.0, "ragged_soldier": 52.0, "flame_pilgrim": 52.0,
	"roadside_peddler": 52.0, "millers_boy": 52.0,
	"cantor_ilse": 52.0, "warden_corin": 52.0, "factor_imre": 52.0,
	"old_fenna": 52.0, "digger_haim": 52.0, "mute_mourner": 52.0,
	"brother_osk": 52.0, "archivist_lene": 52.0, "grave_goods_peddler": 52.0,
	"overseer_brann": 52.0, "envoy_cassia": 52.0, "warden_edda": 52.0,
	"smith_petra": 52.0, "smith_harl": 52.0, "clerk_voss": 52.0,
	"preacher_immo": 52.0, "peddler_nix": 52.0, "sapper_ruel": 52.0,
	"tracker_yri": 52.0, "warden_sighne": 52.0, "ansa_shore": 52.0,
	"mother_halla": 52.0, "skald_ottar": 52.0, "driver_pell": 52.0,
	"cartographer_bree": 52.0, "ridge_deserter": 52.0,
	"deacon_vela": 52.0, "herbalist_kesh": 52.0, "warden_palla": 52.0,
	"fisher_dov": 52.0, "blooming_convert": 52.0, "sister_ottilie": 52.0,
	"scout_renn": 52.0, "reed_cutter_ama": 52.0, "botanist_ferro": 52.0,
	"commander_ashe": 52.0, "consul_verane": 52.0, "apprentice_sorrel": 52.0,
	"keeper_vasse": 52.0, "storm_chaser_ilya": 52.0, "quartermaster_bel": 52.0,
	"bellringer_tam": 52.0, "undertaker_prue": 52.0,
}

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
# Two-regime mob growth (2026-07-21, Depths audit): the authored per-kind
# curve is a kind's NATIVE band — this many levels above its anchor, where
# the level-gap walls (+10 ≈ 2x dmg, +20 Nightmare ≈ 3x) and kind identity
# live, exactly as tuned. BEYOND the band, growth continues on the flat
# player-tracking BOSS dials instead: per-kind rates (0.044-0.0825 effective)
# straddle the player curve, so compounding them 60+ levels above anchor sent
# high-g trash to 100x-1900x pools — an order of magnitude past upscaled
# bosses (pinned at 1.8%/lvl) — walling high-level Depths rooms while the
# boss next door melted. Far-field, every kind now tracks the player curve
# like bosses do, so boss > trash holds at EVERY level. (story.enemy_stats_at)
const MOB_NATIVE_GROWTH_BAND := 20
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
# Death beat pacing (2026-07-17): the fall must READ. The dim now RAMPS in
# over the first half of the beat instead of flash_title's instant
# black-flash-and-fade, and the beat is long enough for the death clip
# (~0.8s) plus a held corpse frame before the respawn pulls the camera.
const DEATH_BEAT_SECS := 2.8    # death -> respawn (was 2.0)
const DEATH_DIM := 0.55         # overlay darkness held through the beat
const DEATH_DIM_RAMP := 1.4     # seconds the dim takes to ramp in (half the beat)

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
# Named-unique drop split (2026-07-27, PROPOSALS/GEAR_UNIQUE_PASSIVES.md §9):
# generic gear is the baseline; when a WEAPON roll passes these gates it lands as
# a NAMED piece instead. Named A opens in Act 2, named S in Act 3 (rarest); the
# class LEGENDARY (S_GEAR, awakening-quest passive) is Act 2+ and now a rare S
# roll rather than every S weapon. Chances are un-benchmarked placeholders.
const UNIQUE_A_CHANCE := 0.10        # an Act-2+ A-grade roll lands as a named A unique (slot-generic)
const UNIQUE_S_CHANCE := 0.10        # an Act-3+ S-grade roll lands as a named S unique (slot-generic)
# (LEGEND_S_CHANCE deleted 2026-07-27: the legendary tier is retired — its six
# flagship passives live on fitting named-S uniques; see Items.roll_item_of.)
const UNIQUE_A_ACT := 2              # act floors for the named channels
const UNIQUE_S_ACT := 3
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

# --------------------------------------------------------- capital rework ---
# (2026-07-25, PROPOSALS/CAPITAL_REWORK.md) The capital is THE shop; the road
# charges for convenience. Campaign chapters no longer open with a start-room
# merchant — mid-run camps and wandering merchants stay, but quote ROAD PRICES:
# a seeded bell-curve markup per merchant per run (a curve, not a uniform
# roll), clamped so it never reads as either a rounding error or a scam.
const ROAD_MARKUP_MEAN := 0.15
const ROAD_MARKUP_SD := 0.025
const ROAD_MARKUP_MIN := 0.10
const ROAD_MARKUP_MAX := 0.20
# The plaza bazaar restocks at dawn (trusted-clock day index) instead of
# holding stock until bought out — fresh daily, fair-priced, never marked up.
const CAPITAL_SHOP_TIER := "gold"       # 5 rolled pieces (SHOP_STOCK_BY_TIER)
# NPC favorability v1 (Petra the smith / the Master Lapidary): earned by
# spending gold at that artisan's bench (1 point per FAVOR_GOLD_PER_POINT)
# and by intro-quest turn-ins. Gains read the shard the way the merchant's
# haggle does — a steady band is trusted, a tempted one watched.
const FAVOR_GOLD_PER_POINT := 25
const FAVOR_TIERS := [0, 25, 75, 150]   # Stranger / Regular / Friend / Confidant
const FAVOR_TIER_NAMES := ["Stranger", "Regular", "Friend", "Confidant"]
const FAVOR_DISCOUNT_PER_TIER := 0.02   # bench costs: -2%/-4%/-6% by tier — shown, never silent
const FAVOR_RES_STEADY_MULT := 1.25
const FAVOR_RES_TEMPTED_MULT := 0.75
const FAVOR_QUEST_POINTS := 15          # favor chunk an intro-quest turn-in pays
const CAPITAL_INTRO_GOLD := 120         # gold reward per capital intro quest (flat teaching beat)
# Prop hotspots (landmark stations, way-gates) demand ADJACENCY — tighter than
# the person-to-person INTERACT_RANGE so a prompt never fires tiles away from
# the art it belongs to (owner report 2026-07-25: fountain text at a distance).
const PROP_HOTSPOT_REACH := 70.0
const PROP_PROMPT_HEIGHT := 0.55        # prompt anchors this fraction up the landmark art
# A prop hotspot STANDS this far south of its landmark's collider edge — the
# trigger band then always covers a hero hugging the art (owner 2026-07-25
# round 3: hand-authored offsets were tuned against the old oversized
# colliders, so hugging the FIXED art left you outside reach).
const PROP_HOTSPOT_STAND := 34.0
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
# Regular gems drop ch4+, special gems ch6+ (see *_gems_drop below). ch12 is
# the S-band table (S ch12-∞ per the window) — authored 2026-07-24 because the
# NG+ tier shift (tier_chapter below) makes it reachable from Torment ch4+.
# ch13+ tables are set later (unbuilt) — gear_weights/boss_weights fall back
# to the richest authored table so nothing rolls empty.
const GEAR_TIER_ORDER := ["F", "E", "D", "C", "B", "A", "S"]
const RICHEST_CH := "ch12"   # fallback table for unbuilt ch13+
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
	"ch12": {"B": 90, "A": 9, "S": 1},
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
	"ch12": {"B": 50, "A": 45, "S": 5},
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

# ---------------------------------------------------- difficulty tiers ---
# NG+ (DESIGN "Difficulty tiers / NG+", built 2026-07-24): a per-CHARACTER
# run setting picked in the replay chapter select. A tier adds a flat
# CONTENT-LEVEL offset to every authored campaign spawn — mobs and bosses
# run through the same enemy_stats_at growth as always, no hidden
# multipliers, so the codex stays honest (+20 ≈ 3x damage on the
# GROWTH_SCALE curve; derived spawns like boss adds inherit their parent's
# lifted level, see game_base.tiered_level) — and shifts every
# chapter-keyed LOOT lookup by whole chapters (~5 levels per Act-1
# chapter), so the grade floor rises with the danger: F/E phase out, B/A/S
# phase in, and the gem gates + act floors ride the same shift. Tier runs
# pay ZERO XP at any completion state (player_core.gain_xp — XP stays
# story currency, paid once at parity); a tier pays in gold RATE (linear
# per level), gem QUALITY, and the shifted band's gear. Unlocks are
# ACCOUNT-wide (meta.json): clearing the Act-1 finale at tier T opens
# T+1. The endgame modes own their own ladders and the weekly races a
# shared seed at parity — game_base.run_tier() returns 0 in both. In
# co-op the HOST's tier briefs the party (net_session world/advance
# snaps; NET_VERSION-gated): every head fights, earns and records at the
# world's actual tier. Names deliberately share the Depths block
# vocabulary (DEPTHS_BLOCK_NAMES) — one difficulty language everywhere.
const TIER_NAMES := ["Normal", "Nightmare", "Torment"]
const TIER_LEVEL_OFFSET := [0, 20, 40]   # content-level add on every authored campaign spawn
const TIER_BAND_SHIFT := [0, 4, 8]       # chapter-table shift: tracks the level offset at ~5 lvl/ch
const TIER_COLORS := [Color(0.75, 0.85, 0.8), Color(0.72, 0.45, 1.0), Color(1.0, 0.4, 0.35)]
const TIER_FINALE_CH := "ch7"            # the clear that opens the next tier (Act-1 finale)

static func tier_name(t: int) -> String:
	return String(TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)])
static func tier_color(t: int) -> Color:
	return Color(TIER_COLORS[clampi(t, 0, TIER_COLORS.size() - 1)])
static func tier_level_offset(t: int) -> int:
	return int(TIER_LEVEL_OFFSET[clampi(t, 0, TIER_LEVEL_OFFSET.size() - 1)])

## The chapter whose LOOT tables a tier-t run of `chid` pays from. Shifted
## ids resolve through the authored ch8-12 tables (ch12 = the S band), then
## the RICHEST_CH fallback; non-"chN" ids (endgame arenas) pass through.
static func tier_chapter(chid: String, t: int) -> String:
	var shift: int = int(TIER_BAND_SHIFT[clampi(t, 0, TIER_BAND_SHIFT.size() - 1)])
	var n := chapter_num(chid)
	if shift == 0 or n <= 0:
		return chid
	return "ch%d" % (n + shift)

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

# Transmuting a gear MAIN to another attribute (2026-07-17) — the bench op that
# makes an off-meta build gearable. Mains always ROLL as the class primary, so
# this is never a REPAIR cost, only a commitment: pay once per piece to point its
# budget at the attribute the build actually wants. Priced well over an affix
# reroll (it decides the build, not a slot) but under a socket (it redirects
# capacity rather than adding it) — converting a full set is a real decision.
const TRANSMUTE_MAIN_COST := {"F": 200, "E": 350, "D": 600, "C": 1200, "B": 3000, "A": 8000, "S": 15000}
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
	# Re-measured 2026-07-24 (econ_audit.gd, post-loot-band tables): the
	# prior 07-06 table drifted only 1-3% — farm-cost pricing was sound.
	"ch1": {"act": 1, "first": 1558, "replay": 1241, "gems": 0.0},
	"ch2": {"act": 1, "first": 1595, "replay": 1169, "gems": 0.0},
	"ch3": {"act": 1, "first": 2797, "replay": 2262, "gems": 0.0},
	"ch4": {"act": 1, "first": 3393, "replay": 2746, "gems": 19.4},
	"ch5": {"act": 1, "first": 4105, "replay": 3367, "gems": 19.4},
	"ch6": {"act": 1, "first": 4952, "replay": 4141, "gems": 19.6},
	"ch7": {"act": 1, "first": 6685, "replay": 5802, "gems": 19.9},
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
	if not CHAPTER_ECON.has(chid):
		# Tier-shifted / unbuilt ids carry no measured econ row: derive the
		# act from the chapter number (~7 chapters per act, Story.act_of's
		# rule) so a Nightmare/Torment band pays its act's gem floor.
		var derived: int = clampi(1 + (chapter_num(chid) - 1) / 7, 1, 3)
		return int(GEM_ACT_LEVEL.get(derived, 1))
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
# Frostfall Ranger ult weather density. These are visual actors only: the
# gameplay storm still strikes once per locked 0.15s tick and applies one hit.
const FROSTFALL_ULT_PREFALL_FLAKES := 36
const FROSTFALL_ULT_FLAKES_PER_TICK := 10
const FROSTFALL_ULT_DECORATIVE_LANCES_PER_TICK := 5
const WARLOCK_CAST_DELAY := 0.16  # delay Shadowbolt / Hex to the arm-snap/sigil-projection frame (~frame 4 of the re-rolled upright cast; Dark Pact = self-buff stays instant; Void Rift self-sequences via its telegraph)
const PROJ_MUZZLE_RISE := 26.0    # friendly shots (arrow/bolt/knife) DRAW this many px above the node origin — hand/chest height of the feet-anchored hero body, so the arrow leaves the bow, not the hip. Visual only: the flight line and collision stay on the origin plane (Y is a ground axis)
const MOB_MUZZLE_RISE := 4.0      # hostile bolts DRAW this ×(mob scale × CHAR_RENDER_SCALE) px above the caster's origin. Mob/boss sprites are CENTER-anchored (unlike the feet-anchored hero), so origin is mid-body — this lifts the bolt to chest/mouth height, scaling with the body (~quarter height). Same visual-only rise mechanism as PROJ_MUZZLE_RISE
const PHANTOM_ULT_SPLASH_OPACITY := 0.10        # Phantom ult: the splash-art screen wash opacity
const PHANTOM_ULT_SPLASH_OPACITY_BRIGHT := 0.15 # +5% on "bright" maps (light backdrops wash the wash out)
# Bosses got v3 ability strips (a real swing/cast windup) — same rule as the
# classes. BOSS_ABILITY_FPS plays the ~7-frame one-shot snappily (~0.5s, not the
# 6fps 1.2s sluggard); BOSS_STRIKE_DELAY defers an IMMEDIATE bolt/ring/beam to
# the contact frame via Boss._strike(). Telegraphed abilities (game.telegraph)
# already carry their own windup — they stay instant, the telegraph IS the wind-up.
const BOSS_ABILITY_FPS := 14.0
const BOSS_STRIKE_DELAY := 0.16
# Falling-object presentation (telegraphed sky attacks). Boss signature
# weapons use a detailed 96px sprite at near-native scale; the larger legacy
# scales remain only for old 16px procedural callers.
const FALLING_FIREBALL_SCALE := 1.25
const FALLING_FIREBALL_TRAIL_AMOUNT := 42
const FALLING_FIREBALL_TRAIL_LIFETIME := 0.44
const FALLING_FIREBALL_TRAIL_SPEED := Vector2(26.0, 72.0)
const FALLING_FIREBALL_TRAIL_SCALE := Vector2(2.0, 4.5)
const FALLING_LEGACY_SWORD_SCALE := 4.5
const BOSS_FALLING_WEAPON_SCALE := 1.15
const FALLING_OBJECT_DEFAULT_END_Y := -20.0
const BOSS_FALLING_WEAPON_END_Y := -43.0
const FALLING_OBJECT_Z_INDEX := 30
const FALLING_OBJECT_FADE := 0.35
# Authored regular-mob projectiles also use 64px source cells, but their combat
# footprint stays smaller than a boss shot so the silhouette reads without
# overstating the collision or threat.
const MOB_PROJECTILE_ART_SCALE := 0.70
# Authored boss projectiles are 64px source cells (versus the old 8/16px
# procedural cores enlarged 3x). 0.75 restores the ~48px combat footprint
# the old cores actually occupied — 0.95 "near-native" measured 56-61px of
# content and boss shots read mob-sized in flight (owner 2026-07-28).
const BOSS_PROJECTILE_ART_SCALE := 0.75
# Boss pursuit profiles: melee gets a small universal closing-speed edge;
# casters circle inside their authored firing band and flip before grinding
# against arena walls.
const BOSS_MELEE_SPEED_MULT := 1.10
const BOSS_CASTER_STRAFE_WEIGHT := 0.55
const BOSS_CASTER_WALL_PROBE := 96.0
const BOSS_CASTER_WALL_EPSILON := 2.0
# Boss speed audit (2026-07-22): boss bolts were the SLOWEST projectiles in
# the game — aimed volleys 270-340 px/s, rings 210-280, against a 248-275
# player walk and a 420 trash bolt. Fired from the 240-380 caster band, an
# aimed bolt took ~1s to arrive (a strafing player exits the whole fan), and
# over the 2.5s projectile life a bolt chasing a back-pedaling archer closed
# ~87px TOTAL — past ~90px of head start it could mathematically never land.
# AIMED fire (volleys/fans at a target, Boss._aimed_speed) now starts at
# trash-bolt speed and ladders with boss level, so the dodge exam hardens as
# the player's own read does. RING bolts stay deliberately slow-and-readable
# (opt-in walls, dodged through the gaps — player ruling: a fast radial wall
# is unplayable chip) but are floored AT walk speed so radial flight is no
# longer auto-dodge (Varo's 210 ring was slower than every class).
const BOSS_BOLT_AIMED_BASE := 420.0     # aimed-volley speed at the anchor level
const BOSS_BOLT_AIMED_ANCHOR := 10.0    # boss level where the ladder starts
const BOSS_BOLT_AIMED_PER_LVL := 2.0    # + per boss level above the anchor...
const BOSS_BOLT_AIMED_CAP := 480.0      # ...capped at the finale tier (~L40)
const BOSS_BOLT_RING := 300.0         # radial ring/burst bolts, every boss
# Same audit: boss STANDING melee contact damage was frame-instant (the swing
# strip played after the hit), while every trash mob telegraphs its bite.
# Standing swings now ride _strike to the contact frame and RE-CHECK reach
# there plus this grace — stepping out during the visible wind-up IS the
# dodge (the Cinderhide contact pattern, promoted to the boss-wide grammar).
# Charge/pounce CONTACT hits stay instant: the charge telegraph was their
# wind-up, and a mid-overshoot re-check would let committed dashes whiff free.
const BOSS_MELEE_CONTACT_GRACE := 18.0
# The Echo's blink-strike used to land 90px out — INSIDE his ~112px contact
# reach, so arrival WAS the hit (one AI tick, ~half a squishy's bar, re-armed
# every 4s by correct kiting). It now lands OUTSIDE reach (the Varo rule:
# "repositions rather than ambushes") — a readable beat of approach + swing.
const ECHO_BLINK_LAND := 150.0
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
const PALADIN_RETRI_DMG := 1.40     # Retribution stance: damage dealt multiplier (1.25->1.35 bench 2026-07-28; ->1.40 ordering retune 2026-07-29: wrath's rep-mean read ~46k on the current tree, ~17% under mage vs the called ~8% — the stance carries part of the gap, the new D6 retri_amp set clause carries the endgame-only rest; Holy untouched)
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
# Last Rites (warlock capstone talent): revive HP per point invested —
# point 1 unlocks the cheat-death, 10 points = 30% max HP (2026-07-28,
# was a binary 1-point cell at a flat 5%).
const LAST_RITES_HP_PER_PT := 0.03
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
# Elites read BIG (2026-07-17): on promotion, bias the mob's size variance to
# the TOP of the band so an elite is the biggest thing short of a boss — size
# itself is the "uh-oh" tell. Fixed (not random) so co-op host+guest agree with
# no extra sync; never shrinks a mob that already rolled bigger. Stacks with
# ELITE_SPRITE_MULT -> ~1.18 x 1.3 ≈ 1.5x on screen. Kept < boss scale.
const ELITE_SIZE_BIAS := 1.18
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
# ------------------------------------- named-unique signature passives (2026-07-27) ---
# One knob home for all 60 named weapon uniques (PROPOSALS/GEAR_UNIQUE_PASSIVES.md).
# EVERY number here is a FIRST-PASS PLACEHOLDER — un-benchmarked; the dedicated
# dps-bench phase owns the real magnitudes. Keys are the passive ids in
# Items.PASSIVES; sub-keys are that passive's own magnitudes. Framework: S = full
# signature; A = LESSER (reduced/narrower) or BARGAIN (S-power with a printed
# drawback that taxes the META build harder than the shape's own build).
const UNIQ := {
	# --- shared infrastructure ---
	"evade_icd": 1.5,          # ONE shared internal cd for every on-evade trigger (owner call §10.4)
	# --- the six flagship passives (ex-S_GEAR, transplanted onto named-S
	# uniques 2026-07-27). Their magnitudes predate this table and live in
	# their original homes (kit code + the S_CASTER_BOLT_CDR family below);
	# these entries satisfy the every-passive-is-knobbed data contract.
	"kingsblade": {}, "windward": {}, "wellspring": {},
	"mirrorstep": {}, "dawnbreaker": {}, "voidmaw": {},
	"struck_icd": 2.0,         # the on-hit-taken PROC family's shared cd (GEAR_ARMOR_UNIQUE_PASSIVES.md §1.3):
	                           # weapon procs fire as shipped and STAMP it; armor struck-clauses require it clear
	                           # (weapon-first by construction — no doubled counters on one blow)
	"expose_mult": 1.25,       # armor-sourced EXPOSE marks LIGHTER than Death Mark's 1.5x (fix round
	                           # 2026-07-28: the evade/beat vuln shipped the ult's full amp and, worn with
	                           # the Warded Mantle loop, sustained Death-Mark-grade uptime vs melee bosses)
	# --- warrior ---
	"pennon":     {"shred": 20.0, "shred_dur": 4.0},                # Bash SUNDERS: flat physres shred
	"decree":     {"every": 3, "mult": 1.15, "stagger": 0.35},      # every 3rd Cleave: armor-ignoring thrust
	"warpath":    {"echo": 0.6},                                    # Berserk-only: crits echo a ghost arc
	"lasthost":   {"echo": 0.6, "icd": 0.3},                        # crits always echo (icd vs multi-crit loops)
	"outrider":   {"window": 2.0},                                  # evade arms a double Cleave; BARGAIN: Grit off
	"horizon":    {"bash_refund": 1.5, "window": 4.0},              # evade: next Cleave forced crit + Bash refund
	"reprisal":   {"chance": 0.30, "counter": 0.6},                 # chance to counter-cut a melee attacker
	"thegate":    {"guard": 80.0, "dur": 2.5, "counter": 0.8, "stagger": 0.5, "icd": 0.25},  # Bash raises the Gate (counter throttled)
	"dirge":      {"dmg": 0.20, "cd_tax": 0.15},                    # heavier Cleave/Whirlwind; BARGAIN: slower Cleave
	"aftershock": {"echo": 0.6, "delay": 0.5, "radius": 150.0, "stagger": 0.3},  # Whirlwind detonates twice
	# --- archer ---
	"siegebolt":  {},                                               # Multishot arrows pierce
	"gale":       {"every": 5, "arrows": 3, "mult": 0.55},          # every 5th Quick Shot: free fan
	"farsight":   {"range": 380.0, "pen_ignore": 0.35},             # truly long shots shear armor (fix 2026-07-28:
	                                                                # 240px was the archer's default kiting band — a
	                                                                # near-permanent 0.5 pen_ignore out-damaged the S)
	"herald":     {"vuln": 1.0, "rearm": 3.0, "boss_rearm": 12.0},  # first hit on unwounded prey: forced crit + mark;
	                                                                # kills re-arm it — vs a BOSS the dawn re-arms on a
	                                                                # cadence instead (a boss offers no second kill)
	"foxfire":    {"window": 2.0, "mult": 0.85},                    # evade: next Quick Shot fires twin arrows
	"hartsbreath": {"crits": 3, "crits_roll": 2},                   # any Tumble: 2 forced crits; perfect dodge: 3 + Multishot reset
	"briar":      {"dot": 0.2, "slow": 0.30, "dur": 3.0, "sw_tax": 0.5},  # thorns; BARGAIN: Second Wind halved
	"bramble":    {"dot": 0.25, "slow": 0.20, "hurt_window": 3.0, "root": 0.5, "root_radius": 140.0, "icd": 6.0},
	"warhorn":    {"extra": 2, "cd_tax": 1.5},                      # 7-arrow Multishot; BARGAIN: +1.5s cd
	"moonturn":   {"echo_delay": 2.0, "echo_dur": 1.5, "echo_mult": 0.5},  # Arrow Storm returns at half
	# --- assassin ---
	"gapfinder":  {"pen_ignore": 0.5},                              # Stab half-ignores CC'd armor
	"quietus":    {"threshold": 0.20, "ult_refund": 2.0},           # low-HP Stabs are TRUE; kills hasten Death Mark
	"compass":    {},                                               # Fan converges (BARGAIN: no spread)
	"midnight":   {"ricochet": 0.7, "range": 200.0},                # Fan crits ricochet to a second enemy
	"mothdust":   {"slow": 0.30, "dur": 2.0, "radius": 90.0},       # evade: slowing dust
	"heartbeat":  {"refund": 0.5, "dash_bonus": 0.30, "icd": 2.0},  # evade: dash refund + heavier next dash
	"parry":      {"chance": 0.30, "riposte": 0.8, "eva_tax": 0.075},  # parry melee; BARGAIN: passive eva halved
	"refusal":    {"icd": 90.0},                                    # cheat death @1 HP + surge + Death Mark reset
	"arithmetic": {"every": 4, "bonus": 0.6, "stagger": 0.3},       # every 4th Stab lands cleaver-heavy
	"headsman":   {"threshold": 0.12, "surge_ext": 1.5, "boss_icd": 3.0},  # Stab/Dash behead low mobs; feeds the surge
	                                                                # — a boss refuses the blade, but Stab/Dash CRITS
	                                                                # against it feed the surge on the icd (2026-07-28)
	# --- mage ---
	"wardcrack":  {"shred": 8.0, "cap": 24.0, "dur": 3.0},          # Firebolt cracks wards, stacking
	"axiom":      {"true_frac": 0.15},                              # 15% of ability damage is TRUE
	"cometfall":  {"splash": 0.30},                                 # Firebolt crits splash
	"ninthstar":  {"every": 9, "splash": 0.40},                     # 9th Firebolt: forced crit + burst + shred
	"squall":     {"window": 2.0},                                  # post-Blink Firebolt strikes twice
	"breathless": {"blink_bonus": 1.0, "icd": 2.0, "window": 4.0},  # evade resets Blink; next shock doubled
	"springwake": {"restore_mult": 1.5, "heal_per": 0.015},         # Nova restores more + mends per enemy
	"worldroot":  {"hp_per_atk": 12.0, "root": 1.0},                # bonus max HP -> atk; Nova roots
	"atlas":      {"true_frac": 0.40},                              # truer Meteor (fix 2026-07-28: the +6s cd
	                                                                # BARGAIN out-taxed the gain at every res level
	                                                                # — a strictly losing equip; now a plain LESSER)
	"skyfall":    {"second": 0.5, "range": 400.0},                  # a second half-weight meteor falls
	# --- paladin ---
	"vow":        {"int_scale": 0.9, "str_scale": 0.6},             # BARGAIN: INT promoted, STR demoted
	"noonday":    {"int_scale": 0.9, "every": 4, "beam": 0.8, "reach": 260.0},  # twin primaries + lance-through
	"censure":    {"splash": 0.30, "stagger": 0.3, "icd": 0.5},     # crits toll: chime splash
	"absolution": {"kills": 3, "mult": 0.9, "boss_icd": 4.0},       # every 3rd kill: free Consecration — vs a
	                                                                # BOSS, crits count as tolls on the icd (2026-07-28)
	"measure":    {"bonus": 0.40, "heal": 0.02, "window": 2.0},     # evade arms a heavier, mending Judgment
	"vigil":      {"window": 4.0},                                  # evade: leap rearmed + next Judgment forced crit
	"knell":      {"heal": 0.01},                                   # Aegis smites mend
	"answer":     {"bank": 0.30},                                   # damage taken banks holy charge
	"burden":     {"dmg": 0.25, "cd_tax": 0.15},                    # heavier, slower Judgment (BARGAIN; 0.15/0.15
	                                                                # was an exact wash — repriced 2026-07-28)
	"dawnfall":   {"mult": 1.3, "burn": 0.3, "slow": 0.30, "dur": 3.0},  # Conviction slam burns + slows
	# --- warlock ---
	"inkteeth":   {"dot": 0.15},                                    # Shadowbolt gnaws
	"remembrance": {"enemy_icd": 3.0},                              # whoever wounds you is HEXED
	"collection": {"bonus": 0.30, "mp": 2.0},                       # crits vs hexed collect
	"clause":     {"scale": 0.5, "icd": 1.0},                       # crits vs hexed detonate the hex early
	"hush":       {"window": 2.0},                                  # evade: next Shadowbolt strikes twice
	"truename":   {"lash": 0.8},                                    # evade: attacker hexed + lashed
	"witness":    {"dot": 0.2, "slow": 0.40, "dur": 3.0, "icd": 1.0},  # attackers bound: withered + slowed
	"thecover":   {"threshold": 0.30, "dr": 0.5, "dr_dur": 2.0, "icd": 25.0},  # panic cover + repulse
	"veinroot":   {"hp_dmg": 0.04, "surge_ext": 2.0},               # Pact draws on max HP; surge lingers
	"lastpulse":  {"hp_per_atk": 15.0, "double_dur": 5.0},          # bonus max HP -> atk; doubled after Pact
	# ===== ARMOR-FAMILY TEMPLATES (helmet/gloves/pants uniques — 2026-07-27) =====
	# GEAR_ARMOR_UNIQUE_PASSIVES.md: 30 shared templates (5 profiles x 3 slots x
	# A/S lanes), instantiated per class through the ART pass's 180 named items.
	# The bare id is the S lane; `<id>_a` is the A lane (LESSER or BARGAIN, its
	# drawback in the knob). All placeholders, un-benchmarked. The ENGINE is
	# wired now; the items that carry these ids arrive with the slot go-live
	# (SLOT wiring + art, per GEAR_SHAPE_MATRIX.md §5b).
	# --- profile A: WARD ---
	"helm_ward":     {"dr": 0.30, "dur": 2.0, "icd": 8.0},          # magic hit taken arms a magic-DR ward
	"helm_ward_a":   {"dr": 0.15, "dur": 2.0, "icd": 8.0},
	"glove_ward":    {"shred": 12.0, "cap": 24.0, "dur": 3.0},      # your hits unweave: flat res shred, stacking to cap (S)
	"glove_ward_a":  {"shred": 7.0, "dur": 3.0},                    # A: one application (cap defaults to shred)
	"pants_ward":    {"cc_mult": 0.7},                              # slows/roots/freezes on YOU run shorter
	"pants_ward_a":  {"cc_mult": 0.5, "heal_tax": 0.10},            # BARGAIN: deeper, but -10% healing received
	# --- profile B: GUARD ---
	"helm_guard":    {"blunt": 1.0, "icd": 10.0},                   # first enemy crit per icd lands BLUNTED
	"helm_guard_a":  {"blunt": 0.5, "icd": 10.0},
	"glove_guard":   {"chance": 0.25, "counter": 0.5},              # melee attacker counter-struck (struck family)
	"glove_guard_a": {"chance": 0.15, "counter": 0.5},
	"pants_guard":   {"dr_stack": 0.02, "stacks": 3, "knock": 0.5}, # hit taken -> flat-DR stack; knock DORMANT (no player-knock source today)
	"pants_guard_a": {"dr_stack": 0.015, "stacks": 2, "knock": 0.5},
	# --- profile C: FINESSE ---
	"helm_finesse":   {"vuln_dur": 3.0},                            # evade marks the attacker EXPOSED (evade family, weapon-first)
	"helm_finesse_a": {"vuln_dur": 1.5},
	"glove_finesse":   {"every": 5},                                # every Nth basic cannot miss or graze (true-aim)
	"glove_finesse_a": {"every": 8},
	"pants_finesse":   {"eva": 0.10, "dur": 2.0},                   # being hit leaves you slippery (struck family)
	"pants_finesse_a": {"eva": 0.15, "dur": 2.0, "sw_delay_tax": 0.5},  # BARGAIN: Second Wind waits longer
	# --- profile D: AGGRESSOR ---
	"helm_aggr":    {"opener": 0.25},                               # first hit on unwounded prey strikes harder
	"helm_aggr_a":  {"opener": 0.15},
	"glove_aggr":   {"dot": 0.15, "dur": 3.0},                      # your crits add a class-typed tear
	"glove_aggr_a": {"dot": 0.10, "dur": 3.0},
	"pants_aggr":   {"bonus": 0.20, "window": 3.0},                 # COMMIT ability arms the next damaging cast
	"pants_aggr_a": {"bonus": 0.12, "window": 3.0},
	# --- profile E: BULWARK ---
	"helm_bulwark":   {"cap": 0.08},                                # overheal pools into a shield (Transfusion rail)
	"helm_bulwark_a": {"cap": 0.04},
	"glove_bulwark":   {"hp_per": 40.0},                            # hits carry flat bonus from max HP
	"glove_bulwark_a": {"hp_per": 70.0},
	"pants_bulwark":   {"dr": 0.15, "threshold": 0.30},             # below the threshold: a standing DR floor
	"pants_bulwark_a": {"dr": 0.25, "threshold": 0.30, "sw_off": 1},  # BARGAIN: deeper floor, Second Wind never triggers
	# ===== the 360 named gear uniques (verb + beat data, 2026-07-27) =====
	# "verb" = the engine family (helm_/glove_/pants_* stand-in keys);
	# "beat" = the S-lane class clause fired by the beat executor;
	# "amp"/"when" = conditional doubling. Placeholders, un-benchmarked.
	"warrior_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_helmet_As": {"beat": "grit", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"warrior_helmet_Bs": {"beat": "grit", "blunt": 1.0, "icd": 10.0, "verb": "helm_guard"},
	"warrior_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warrior_helmet_Cs": {"beat": "cdr", "s": 1.5, "slot": "a3", "verb": "helm_finesse", "vuln_dur": 3.0},
	"warrior_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"warrior_helmet_Ds": {"beat": "stagger", "opener": 0.25, "s": 0.3, "verb": "helm_aggr"},
	"warrior_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"warrior_helmet_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "berserk"},
	"warrior_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"warrior_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"warrior_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"warrior_gloves_Bs": {"beat": "stagger", "chance": 0.25, "counter": 0.5, "s": 0.3, "verb": "glove_guard"},
	"warrior_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"warrior_gloves_Cs": {"beat": "knock", "every": 5, "n": 320.0, "verb": "glove_finesse"},
	"warrior_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"warrior_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "berserk"},
	"warrior_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"warrior_gloves_Es": {"beat": "amp", "hp_per": 40.0, "verb": "glove_bulwark", "when": "berserk"},
	"warrior_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"warrior_pants_As": {"beat": "grit", "cc_mult": 0.7, "verb": "pants_ward"},
	"warrior_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warrior_pants_Bs": {"beat": "stagger", "dr_stack": 0.02, "s": 0.3, "stacks": 3, "verb": "pants_guard"},
	"warrior_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"warrior_pants_Cs": {"amp": 0.2, "amp_icd": 8.0, "beat": "slipamp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"warrior_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"warrior_pants_Ds": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"warrior_pants_Ea": {"dr": 0.25, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_pants_Es": {"beat": "grit", "dr": 0.15, "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_helmet_As": {"beat": "swkeep", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"archer_helmet_Bs": {"beat": "vuln", "blunt": 1.0, "dur": 3.0, "icd": 10.0, "verb": "helm_guard"},
	"archer_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"archer_helmet_Cs": {"beat": "huntp", "verb": "helm_finesse", "vuln_dur": 3.0},
	"archer_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"archer_helmet_Ds": {"beat": "huntp", "opener": 0.25, "verb": "helm_aggr"},
	"archer_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"archer_helmet_Es": {"cap": 0.08, "verb": "helm_bulwark"},
	"archer_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"archer_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"archer_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"archer_gloves_Bs": {"beat": "knock", "chance": 0.25, "counter": 0.5, "n": 320.0, "verb": "glove_guard"},
	"archer_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"archer_gloves_Cs": {"every": 5, "verb": "glove_finesse"},
	"archer_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"archer_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "marked"},
	"archer_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"archer_gloves_Es": {"hp_per": 40.0, "verb": "glove_bulwark"},
	"archer_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"archer_pants_As": {"beat": "cdr", "cc_mult": 0.7, "s": 1.0, "slot": "a3", "verb": "pants_ward"},
	"archer_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"archer_pants_Bs": {"dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"archer_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"archer_pants_Cs": {"beat": "tumblearm", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"archer_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"archer_pants_Ds": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"archer_pants_Ea": {"dr": 0.25, "sw_off": 1, "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_pants_Es": {"beat": "cdr", "dr": 0.15, "s": 1.0, "slot": "a3", "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"assassin_helmet_As": {"beat": "surge", "dr": 0.3, "dur": 2.0, "icd": 8.0, "s": 0.5, "verb": "helm_ward"},
	"assassin_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"assassin_helmet_Bs": {"beat": "wither", "blunt": 1.0, "dot": 0.2, "icd": 10.0, "verb": "helm_guard"},
	"assassin_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"assassin_helmet_Cs": {"beat": "dmark", "s": 0.5, "verb": "helm_finesse", "vuln_dur": 3.0},
	"assassin_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"assassin_helmet_Ds": {"beat": "surge", "opener": 0.25, "s": 2.0, "verb": "helm_aggr"},
	"assassin_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"assassin_helmet_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "surge"},
	"assassin_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"assassin_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"assassin_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"assassin_gloves_Bs": {"beat": "surge", "chance": 0.25, "counter": 0.5, "s": 1.0, "verb": "glove_guard"},
	"assassin_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"assassin_gloves_Cs": {"beat": "surge", "every": 5, "s": 1.0, "verb": "glove_finesse"},
	"assassin_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"assassin_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "marked"},
	"assassin_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"assassin_gloves_Es": {"beat": "amp", "hp_per": 40.0, "verb": "glove_bulwark", "when": "surge"},
	"assassin_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"assassin_pants_As": {"beat": "cdr", "cc_mult": 0.7, "s": 1.0, "slot": "a2", "verb": "pants_ward"},
	"assassin_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"assassin_pants_Bs": {"dr_stack": 0.02, "stacks": 3, "full_eva": 0.05, "verb": "pants_guard"},
	"assassin_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"assassin_pants_Cs": {"amp": 0.2, "amp_icd": 8.0, "beat": "slipamp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"assassin_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"assassin_pants_Ds": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"assassin_pants_Ea": {"dr": 0.25, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_pants_Es": {"beat": "surge", "dr": 0.15, "s": 1.0, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"mage_helmet_As": {"beat": "mana", "dr": 0.3, "dur": 2.0, "icd": 8.0, "n": 5.0, "verb": "helm_ward"},
	"mage_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"mage_helmet_Bs": {"beat": "cdr", "blunt": 1.0, "icd": 10.0, "s": 1.0, "slot": "a3", "verb": "helm_guard"},
	"mage_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"mage_helmet_Cs": {"beat": "mana", "n": 10.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"mage_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"mage_helmet_Ds": {"beat": "shredx", "opener": 0.25, "verb": "helm_aggr"},
	"mage_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"mage_helmet_Es": {"cap": 0.08, "nova_pool": 0.04, "verb": "helm_bulwark"},
	"mage_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"mage_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"mage_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"mage_gloves_Bs": {"beat": "slow", "chance": 0.25, "counter": 0.5, "dur": 2.0, "pct": 0.3, "verb": "glove_guard"},
	"mage_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"mage_gloves_Cs": {"every": 5, "verb": "glove_finesse"},
	"mage_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"mage_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "shredded"},
	"mage_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"mage_gloves_Es": {"hp_per": 40.0, "verb": "glove_bulwark"},
	"mage_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"mage_pants_As": {"beat": "mana", "cc_mult": 0.7, "n": 8.0, "verb": "pants_ward"},
	"mage_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"mage_pants_Bs": {"dr_stack": 0.02, "stacks": 3, "full_blink_dr": 0.10, "verb": "pants_guard"},
	"mage_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"mage_pants_Cs": {"amp": 0.2, "amp_icd": 8.0, "beat": "slipamp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"mage_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"mage_pants_Ds": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"mage_pants_Ea": {"dr": 0.25, "nova_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_pants_Es": {"beat": "mana", "dr": 0.15, "n": 5.0, "threshold": 0.3, "verb": "pants_bulwark"},
	"paladin_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"paladin_helmet_As": {"beat": "holy", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"paladin_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"paladin_helmet_Bs": {"beat": "holy", "blunt": 1.0, "icd": 10.0, "verb": "helm_guard"},
	"paladin_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"paladin_helmet_Cs": {"beat": "heal", "pct": 0.02, "verb": "helm_finesse", "vuln_dur": 3.0},
	"paladin_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"paladin_helmet_Ds": {"beat": "amp", "opener": 0.25, "verb": "helm_aggr", "when": "retri"},
	"paladin_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"paladin_helmet_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "holy"},
	"paladin_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"paladin_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"paladin_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"paladin_gloves_Bs": {"beat": "heal", "chance": 0.25, "counter": 0.5, "pct": 0.01, "verb": "glove_guard"},
	"paladin_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"paladin_gloves_Cs": {"beat": "heal", "every": 5, "pct": 0.01, "verb": "glove_finesse"},
	"paladin_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"paladin_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "retri"},
	"paladin_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"paladin_gloves_Es": {"beat": "amp", "hp_per": 40.0, "verb": "glove_bulwark", "when": "aegis"},
	"paladin_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"paladin_pants_As": {"beat": "holy", "cc_mult": 0.7, "verb": "pants_ward"},
	"paladin_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"paladin_pants_Bs": {"dr_stack": 0.02, "stacks": 3, "full_aegis": 10.0, "verb": "pants_guard"},
	"paladin_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"paladin_pants_Cs": {"amp": 0.2, "amp_icd": 8.0, "beat": "slipamp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"paladin_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"paladin_pants_Ds": {"beat": "cdr", "bonus": 0.2, "s": 1.0, "slot": "leap", "verb": "pants_aggr", "window": 3.0},
	"paladin_pants_Ea": {"dr": 0.25, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"paladin_pants_Es": {"beat": "amp", "dr": 0.15, "threshold": 0.3, "verb": "pants_bulwark", "when": "lowhp"},
	"warlock_helmet_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warlock_helmet_As": {"beat": "hpq", "dr": 0.3, "dur": 2.0, "icd": 8.0, "pct": 0.01, "verb": "helm_ward"},
	"warlock_helmet_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"warlock_helmet_Bs": {"beat": "wither", "blunt": 1.0, "dot": 0.2, "icd": 10.0, "verb": "helm_guard"},
	"warlock_helmet_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warlock_helmet_Cs": {"beat": "hexext", "s": 1.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"warlock_helmet_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"warlock_helmet_Ds": {"beat": "wither", "dot": 0.2, "opener": 0.25, "verb": "helm_aggr"},
	"warlock_helmet_Ea": {"cap": 0.04, "verb": "helm_bulwark"},
	"warlock_helmet_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "pact"},
	"warlock_gloves_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"warlock_gloves_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"warlock_gloves_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"warlock_gloves_Bs": {"beat": "slow", "chance": 0.25, "counter": 0.5, "dur": 3.0, "pct": 0.4, "verb": "glove_guard"},
	"warlock_gloves_Ca": {"every": 8, "verb": "glove_finesse"},
	"warlock_gloves_Cs": {"beat": "hpq", "every": 5, "pct": 0.02, "verb": "glove_finesse"},
	"warlock_gloves_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"warlock_gloves_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "hexed"},
	"warlock_gloves_Ea": {"hp_per": 70.0, "verb": "glove_bulwark"},
	"warlock_gloves_Es": {"beat": "amp", "hp_per": 40.0, "verb": "glove_bulwark", "when": "pact"},
	"warlock_pants_Aa": {"cc_mult": 0.5, "heal_tax": 0.1, "verb": "pants_ward"},
	"warlock_pants_As": {"beat": "hpq", "cc_mult": 0.7, "pct": 0.03, "verb": "pants_ward"},
	"warlock_pants_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warlock_pants_Bs": {"dr_stack": 0.02, "stacks": 3, "pact_cut": 0.25, "verb": "pants_guard"},
	"warlock_pants_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"warlock_pants_Cs": {"amp": 0.2, "amp_icd": 8.0, "beat": "slipamp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"warlock_pants_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"warlock_pants_Ds": {"beat": "hexext", "bonus": 0.2, "s": 1.0, "verb": "pants_aggr", "window": 3.0},
	"warlock_pants_Ea": {"dr": 0.25, "ls_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warlock_pants_Es": {"beat": "hpq", "dr": 0.15, "pct": 0.01, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_armor_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_armor_As": {"beat": "grit", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_armor_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warrior_armor_Bs": {"beat": "stagger", "dr_stack": 0.02, "s": 0.3, "stacks": 3, "verb": "pants_guard"},
	"warrior_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"warrior_armor_Cs": {"beat": "cdr", "dur": 2.0, "eva": 0.1, "s": 1.0, "slot": "a2", "verb": "pants_finesse"},
	"warrior_armor_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"warrior_armor_Ds": {"beat": "stagger", "dot": 0.15, "dur": 3.0, "s": 0.3, "verb": "glove_aggr"},
	"warrior_armor_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_armor_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_boots_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_boots_As": {"beat": "grit", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_boots_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warrior_boots_Bs": {"beat": "stagger", "dr_stack": 0.02, "s": 0.3, "stacks": 3, "verb": "pants_guard"},
	"warrior_boots_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warrior_boots_Cs": {"beat": "cdr", "s": 1.0, "slot": "a2", "verb": "helm_finesse", "vuln_dur": 3.0},
	"warrior_boots_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"warrior_boots_Ds": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"warrior_boots_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_boots_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"warrior_charm_Aa": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warrior_charm_As": {"beat": "stagger", "dr_stack": 0.02, "s": 0.3, "stacks": 3, "verb": "pants_guard"},
	"warrior_charm_Ba": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_charm_Bs": {"beat": "grit", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warrior_charm_Ca": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"warrior_charm_Cs": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "berserk"},
	"warrior_charm_Da": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warrior_charm_Ds": {"beat": "cdr", "s": 1.0, "slot": "a3", "verb": "helm_finesse", "vuln_dur": 3.0},
	"warrior_charm_Ea": {"cap": 0.04, "regen_tax": 0.5, "verb": "helm_bulwark"},
	"warrior_charm_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "berserk"},
	"archer_armor_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_armor_As": {"beat": "swkeep", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_armor_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"archer_armor_Bs": {"dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"archer_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"archer_armor_Cs": {"beat": "huntp", "dur": 2.0, "eva": 0.1, "verb": "pants_finesse"},
	"archer_armor_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"archer_armor_Ds": {"beat": "knock", "n": 320.0, "opener": 0.25, "verb": "helm_aggr"},
	"archer_armor_Ea": {"dr": 0.1, "sw_off": 1, "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_armor_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_boots_Aa": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"archer_boots_As": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"archer_boots_Ba": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"archer_boots_Bs": {"beat": "huntp", "verb": "helm_finesse", "vuln_dur": 3.0},
	"archer_boots_Ca": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"archer_boots_Cs": {"beat": "huntp", "dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"archer_boots_Da": {"cc_mult": 0.8, "verb": "pants_ward"},
	"archer_boots_Ds": {"beat": "cdr", "cc_mult": 0.7, "s": 1.0, "slot": "a3", "verb": "pants_ward"},
	"archer_boots_Ea": {"dr": 0.1, "sw_off": 1, "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_boots_Es": {"beat": "cdr", "dr": 0.15, "s": 1.0, "slot": "a3", "threshold": 0.3, "verb": "pants_bulwark"},
	"archer_charm_Aa": {"every": 8, "verb": "glove_finesse"},
	"archer_charm_As": {"beat": "huntp", "every": 5, "verb": "glove_finesse"},
	"archer_charm_Ba": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"archer_charm_Bs": {"beat": "vuln", "blunt": 1.0, "dur": 3.0, "icd": 10.0, "verb": "helm_guard"},
	"archer_charm_Ca": {"opener": 0.15, "verb": "helm_aggr"},
	"archer_charm_Cs": {"beat": "amp", "opener": 0.25, "verb": "helm_aggr", "when": "marked"},
	"archer_charm_Da": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_charm_Ds": {"beat": "swkeep", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"archer_charm_Ea": {"cap": 0.04, "sw_tax": 0.5, "verb": "helm_bulwark"},
	"archer_charm_Es": {"cap": 0.08, "verb": "helm_bulwark"},
	"assassin_armor_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"assassin_armor_As": {"beat": "surge", "dr": 0.3, "dur": 2.0, "icd": 8.0, "s": 0.5, "verb": "helm_ward"},
	"assassin_armor_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"assassin_armor_Bs": {"beat": "vuln", "dr_stack": 0.02, "dur": 2.0, "stacks": 3, "verb": "pants_guard"},
	"assassin_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"assassin_armor_Cs": {"beat": "surge", "dur": 2.0, "eva": 0.1, "s": 0.5, "verb": "pants_finesse"},
	"assassin_armor_Da": {"opener": 0.15, "verb": "helm_aggr"},
	"assassin_armor_Ds": {"beat": "surge", "opener": 0.25, "s": 1.0, "verb": "helm_aggr"},
	"assassin_armor_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_armor_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_boots_Aa": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"assassin_boots_As": {"beat": "surge", "dur": 2.0, "eva": 0.1, "s": 0.5, "verb": "pants_finesse"},
	"assassin_boots_Ba": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"assassin_boots_Bs": {"beat": "surge", "chance": 0.25, "counter": 0.5, "s": 1.0, "verb": "glove_guard"},
	"assassin_boots_Ca": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"assassin_boots_Cs": {"beat": "cdr", "bonus": 0.2, "s": 0.5, "slot": "commit", "verb": "pants_aggr", "window": 3.0},
	"assassin_boots_Da": {"cc_mult": 0.8, "verb": "pants_ward"},
	"assassin_boots_Ds": {"beat": "cdr", "cc_mult": 0.7, "s": 1.0, "slot": "a2", "verb": "pants_ward"},
	"assassin_boots_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_boots_Es": {"beat": "surge", "dr": 0.15, "s": 1.0, "threshold": 0.3, "verb": "pants_bulwark"},
	"assassin_charm_Aa": {"opener": 0.15, "verb": "helm_aggr"},
	"assassin_charm_As": {"beat": "surge", "opener": 0.25, "s": 1.0, "verb": "helm_aggr"},
	"assassin_charm_Ba": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"assassin_charm_Bs": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"assassin_charm_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"assassin_charm_Cs": {"beat": "dmark", "s": 0.5, "verb": "helm_finesse", "vuln_dur": 3.0},
	"assassin_charm_Da": {"chance": 0.15, "counter": 0.5, "verb": "glove_guard"},
	"assassin_charm_Ds": {"beat": "surge", "chance": 0.25, "counter": 0.5, "s": 1.0, "verb": "glove_guard"},
	"assassin_charm_Ea": {"cap": 0.04, "regen_tax": 0.5, "verb": "helm_bulwark"},
	"assassin_charm_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "surge"},
	"mage_armor_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"mage_armor_As": {"beat": "mana", "dr": 0.3, "dur": 2.0, "icd": 8.0, "n": 5.0, "verb": "helm_ward"},
	"mage_armor_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"mage_armor_Bs": {"beat": "cdr", "dr_stack": 0.02, "s": 1.0, "slot": "a3", "stacks": 3, "verb": "pants_guard"},
	"mage_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"mage_armor_Cs": {"beat": "mana", "dur": 2.0, "eva": 0.1, "n": 5.0, "verb": "pants_finesse"},
	"mage_armor_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"mage_armor_Ds": {"beat": "slow", "bonus": 0.2, "dur": 2.0, "pct": 0.3, "verb": "pants_aggr", "window": 3.0},
	"mage_armor_Ea": {"dr": 0.1, "nova_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_armor_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_boots_Aa": {"opener": 0.15, "verb": "helm_aggr"},
	"mage_boots_As": {"beat": "shredx", "opener": 0.25, "verb": "helm_aggr"},
	"mage_boots_Ba": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"mage_boots_Bs": {"beat": "mana", "n": 8.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"mage_boots_Ca": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"mage_boots_Cs": {"beat": "cdr", "dr_stack": 0.02, "s": 0.5, "slot": "commit", "stacks": 3, "verb": "pants_guard"},
	"mage_boots_Da": {"cc_mult": 0.8, "verb": "pants_ward"},
	"mage_boots_Ds": {"beat": "mana", "cc_mult": 0.7, "n": 8.0, "verb": "pants_ward"},
	"mage_boots_Ea": {"dr": 0.1, "nova_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_boots_Es": {"beat": "mana", "dr": 0.15, "n": 5.0, "threshold": 0.3, "verb": "pants_bulwark"},
	"mage_charm_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"mage_charm_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"mage_charm_Ba": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"mage_charm_Bs": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "shredded"},
	"mage_charm_Ca": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"mage_charm_Cs": {"beat": "mana", "blunt": 1.0, "icd": 10.0, "n": 5.0, "verb": "helm_guard"},
	"mage_charm_Da": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"mage_charm_Ds": {"beat": "mana", "n": 8.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"mage_charm_Ea": {"cap": 0.04, "nova_tax": 0.5, "verb": "helm_bulwark"},
	"mage_charm_Es": {"cap": 0.08, "verb": "helm_bulwark"},
	"paladin_armor_Aa": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"paladin_armor_As": {"beat": "holy", "dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"paladin_armor_Ba": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"paladin_armor_Bs": {"beat": "holy", "dr": 0.3, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"paladin_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"paladin_armor_Cs": {"beat": "heal", "dur": 2.0, "eva": 0.1, "pct": 0.01, "verb": "pants_finesse"},
	"paladin_armor_Da": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"paladin_armor_Ds": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "retri"},
	"paladin_armor_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"paladin_armor_Es": {"beat": "amp", "dr": 0.15, "threshold": 0.3, "verb": "pants_bulwark", "when": "lowhp"},
	"paladin_boots_Aa": {"opener": 0.15, "verb": "helm_aggr"},
	"paladin_boots_As": {"beat": "stagger", "opener": 0.25, "s": 0.3, "verb": "helm_aggr"},
	"paladin_boots_Ba": {"cc_mult": 0.8, "verb": "pants_ward"},
	"paladin_boots_Bs": {"beat": "holy", "cc_mult": 0.7, "verb": "pants_ward"},
	"paladin_boots_Ca": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"paladin_boots_Cs": {"beat": "heal", "pct": 0.01, "verb": "helm_finesse", "vuln_dur": 3.0},
	"paladin_boots_Da": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"paladin_boots_Ds": {"beat": "cdr", "dr_stack": 0.02, "s": 1.0, "slot": "leap", "stacks": 3, "verb": "pants_guard"},
	"paladin_boots_Ea": {"dr": 0.1, "regen_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"paladin_boots_Es": {"beat": "heal", "dr": 0.15, "pct": 0.02, "threshold": 0.3, "verb": "pants_bulwark"},
	"paladin_charm_Aa": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"paladin_charm_As": {"beat": "holy", "blunt": 1.0, "icd": 10.0, "verb": "helm_guard"},
	"paladin_charm_Ba": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"paladin_charm_Bs": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "retri"},
	"paladin_charm_Ca": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"paladin_charm_Cs": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"paladin_charm_Da": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"paladin_charm_Ds": {"beat": "cdr", "s": 1.0, "slot": "a3", "verb": "helm_finesse", "vuln_dur": 3.0},
	"paladin_charm_Ea": {"cap": 0.04, "regen_tax": 0.5, "verb": "helm_bulwark"},
	"paladin_charm_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "holy"},
	"warlock_armor_Aa": {"dr": 0.15, "dur": 2.0, "icd": 8.0, "verb": "helm_ward"},
	"warlock_armor_As": {"beat": "hpq", "dr": 0.3, "dur": 2.0, "icd": 8.0, "pct": 0.01, "verb": "helm_ward"},
	"warlock_armor_Ba": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warlock_armor_Bs": {"beat": "wither", "dot": 0.2, "dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"warlock_armor_Ca": {"dur": 2.0, "eva": 0.07, "verb": "pants_finesse"},
	"warlock_armor_Cs": {"beat": "hexext", "dur": 2.0, "eva": 0.1, "s": 1.0, "verb": "pants_finesse"},
	"warlock_armor_Da": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"warlock_armor_Ds": {"beat": "wither", "bonus": 0.2, "dot": 0.2, "verb": "pants_aggr", "window": 3.0},
	"warlock_armor_Ea": {"dr": 0.1, "ls_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warlock_armor_Es": {"beat": "hpq", "dr": 0.15, "pct": 0.01, "threshold": 0.3, "verb": "pants_bulwark"},
	"warlock_boots_Aa": {"dr_stack": 0.015, "stacks": 2, "verb": "pants_guard"},
	"warlock_boots_As": {"beat": "wither", "dot": 0.2, "dr_stack": 0.02, "stacks": 3, "verb": "pants_guard"},
	"warlock_boots_Ba": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warlock_boots_Bs": {"beat": "hexext", "s": 1.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"warlock_boots_Ca": {"bonus": 0.12, "verb": "pants_aggr", "window": 3.0},
	"warlock_boots_Cs": {"beat": "hexext", "bonus": 0.2, "s": 1.0, "verb": "pants_aggr", "window": 3.0},
	"warlock_boots_Da": {"cc_mult": 0.8, "verb": "pants_ward"},
	"warlock_boots_Ds": {"beat": "hpq", "cc_mult": 0.7, "pct": 0.03, "verb": "pants_ward"},
	"warlock_boots_Ea": {"dr": 0.1, "ls_tax": 0.5, "threshold": 0.3, "verb": "pants_bulwark"},
	"warlock_boots_Es": {"beat": "hpq", "dr": 0.15, "pct": 0.01, "threshold": 0.3, "verb": "pants_bulwark"},
	"warlock_charm_Aa": {"dur": 3.0, "shred": 7.0, "verb": "glove_ward"},
	"warlock_charm_As": {"cap": 24.0, "dur": 3.0, "shred": 12.0, "verb": "glove_ward"},
	"warlock_charm_Ba": {"dot": 0.1, "dur": 3.0, "verb": "glove_aggr"},
	"warlock_charm_Bs": {"beat": "amp", "dot": 0.15, "dur": 3.0, "verb": "glove_aggr", "when": "hexed"},
	"warlock_charm_Ca": {"blunt": 0.5, "icd": 10.0, "verb": "helm_guard"},
	"warlock_charm_Cs": {"beat": "hpq", "blunt": 1.0, "icd": 10.0, "pct": 0.01, "verb": "helm_guard"},
	"warlock_charm_Da": {"verb": "helm_finesse", "vuln_dur": 1.5},
	"warlock_charm_Ds": {"beat": "hexext", "s": 1.0, "verb": "helm_finesse", "vuln_dur": 3.0},
	"warlock_charm_Ea": {"cap": 0.04, "ls_tax": 0.5, "verb": "helm_bulwark"},
	"warlock_charm_Es": {"beat": "amp", "cap": 0.08, "verb": "helm_bulwark", "when": "pact"},
}


## One passive's knob dictionary ({} for ids without numbers).
static func uniq(passive: String) -> Dictionary:
	var v = UNIQ.get(passive, {})
	return v if v is Dictionary else {}


# --------------------------- unique gear SETS (2026-07-28) -------------------
# GEAR_UNIQUE_SETS.md: a set is a PROFILE worn across the six gear slots —
# own-class NAMED uniques counted by the profile letter in their structural
# passive id (A ward / B guard / C finesse / D aggressor / E bulwark); both
# lanes count. Replaces the legacy one-set-per-class S bonus. Tier records:
# s2/s4/s6 — keys that exist in recalc's stat bucket fold in as flat stats;
# everything else is a CLAUSE knob read at its seam (player/kits). The 4pc is
# each set's LENS (identity / weakness / off-meta — the doc tags them).
# ALL PLACEHOLDERS, un-benchmarked.
# A guard set ANCHORS on its own at 4pc: with no pants_guard carrier worn,
# struck-accrual still builds anchor stacks to this cap (the S-lane carrier's
# own 3) — the set's stack-gated clauses fire off any four guard pieces.
const SET_ANCHOR_STACKS := 3
# Same principle for the ward set: at 4pc with no helm_ward carrier, magic
# hits arm a baseline ward at the A-lane knobs (a carrier's own dr/dur win).
const SET_WARD := {"dr": 0.15, "dur": 2.0}
# Ward-set 6pc ward_amp pays for THIS long from the ward ARMING (2026-07-28:
# the old "while the ward holds" was 2s-in-8 — the exact uptime shape the
# Tempest Crown fix condemned; the amp now outlives the ward window).
const SET_WARD_AMP_DUR := 6.0
# The aggressor 6pc opener clauses RE-ARM on this cadence mid-fight (a boss
# never offers a second unwounded moment); the true opener always fires.
const SET_OPENER_REARM := 12.0
const UNIQ_SETS := {
	"warrior": {
		"A": {"s2": {"magres": 8.0}, "s4": {"grit_on_magic": 1.0}, "s6": {"ward_amp": 0.10}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"grit_cap": 2.0}, "s6": {"full_grit_answer": 0.3}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"grit_on_evade": 1.0}, "s6": {"slippery_amp": 0.10}},
		# Warrior aggressor 2pc/4pc are the fury ordering dial (bench 2026-07-28;
		# trimmed in the 2026-07-29 ordering retune: the item-opener re-arm and
		# tree drift pushed fury to ~54.4k rep-mean, ~-1.5% under mage vs the
		# called ~-8% — 2pc back near standard, Berserk's extension eased 4->3s;
		# berserk_dmg 0.70 itself untouched, it is the at-level fury identity).
		# Completion still escalates: warrior BiS forms D4 on its own.
		# 6pc: the stagger opens a CRUSH window (player_combat opener seam) and
		# "crush_amp" folds into recalc's stat bucket — warrior knockbacks and
		# the crush talent read the same window, so trash pays it constantly.
		"D": {"s2": {"atk_pct": 0.025, "crit": 0.02}, "s4": {"berserk_ext": 3.0}, "s6": {"opener_stagger": 0.3, "crush_amp": 0.12}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"hp_pct": 0.08}, "s6": {"bastion_add": 0.10}},
	},
	"archer": {
		"A": {"s2": {"magres": 8.0}, "s4": {"sw_magic_keep": 1.0}, "s6": {"sw_regen": 0.02}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"huntp_struck": 1.0}, "s6": {"anchor_thorns": 0.15}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"tumble_cd": 1.0}, "s6": {"perfect_crit": 1.0}},
		# 6pc (fix 2026-07-28): the re-armed EXPOSE alone measured ~0 on the hunt
		# build (redundant under hunt's own permanent marks — the saturated-capstone
		# shape that got the assassin extension deleted). Three-part capstone:
		# rhythm_cut quickens the rhythm one beat (measured +0.6% alone — real but
		# small), amp_marked6 deepens the 4pc amp vs marked prey (the premier
		# payload; hunt marks run near-permanent, the warlock amp_hexed shape),
		# and the EXPOSE stays for OFF-hunt themes, whose prey is otherwise bare.
		"D": {"s2": {"atk_pct": 0.03, "crit": 0.02}, "s4": {"amp_marked": 0.08}, "s6": {"opener_expose": 1.0, "rhythm_cut": 1.0, "amp_marked6": 0.05}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"hp_pct": 0.08, "sw_delay": -0.5}, "s6": {"lowhp_slow": 0.2}},
	},
	"assassin": {
		"A": {"s2": {"magres": 8.0}, "s4": {"surge_ward": 1.5}, "s6": {"magres_x": 10.0, "mward_add": 0.10}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"parry_add": 0.10}, "s6": {"surge_answer": 0.3}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"eva": 0.03}, "s6": {"dmark_evade": 0.3}},
		# Assassin aggressor tiers ESCALATE (owner rule 2026-07-28: completion
		# must out-pay partial sets — the earlier hot-2pc crown inverted that).
		# The 4pc amp is priced for the ~1/6 Death-Mark uptime (0.25 in the
		# window ≈ +4% sustained), so committing the 4th slot beats the BiS
		# piece it displaces; the 6pc carries the crown's top end.
		# 6pc redesigned (bench 2026-07-28): the kill/crit surge EXTENSION was
		# saturated — stab cadence already maintains the surge, so the full six
		# measured under the 4pc kit. The capstone now deepens the surge
		# itself (a standing amp while it runs): completion escalates.
		# amp_deathmarked (fix 2026-07-28): keys on the ULT window + the mark,
		# not bare vuln_time — armor EXPOSE pieces (evade proc / Warded Mantle)
		# were lighting the Death-Mark-priced amp at near-100% uptime vs melee.
		"D": {"s2": {"atk_pct": 0.03, "crit": 0.02}, "s4": {"amp_deathmarked": 0.25}, "s6": {"surge_amp": 0.15}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"hp_pct": 0.08}, "s6": {"surge_hold": 1.0}},
	},
	"mage": {
		"A": {"s2": {"magres": 8.0}, "s4": {"mana_ward": 15.0}, "s6": {"magres_x": 10.0, "blink_dr": 0.10}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"blunt_icd_cut": 3.0}, "s6": {"cloak_stacks": 0.05}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"mana_evade": 10.0}, "s6": {"blink_cd": 0.5}},
		# 4pc (fix 2026-07-28): at exactly four pieces the only shred source was
		# the once-per-fight opener beat (~8s uptime per boss) — the amp now
		# carries its own applicator (every 8th bolt); the 6pc quickens it to 4.
		"D": {"s2": {"atk_pct": 0.03, "crit": 0.02}, "s4": {"amp_shredded": 0.08, "bolt_shred_every4": 8.0}, "s6": {"bolt_shred_every": 4.0}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"hp_pct": 0.08, "nova_restore_add": 0.05}, "s6": {"nova_root": 0.5}},
	},
	"paladin": {
		"A": {"s2": {"magres": 8.0}, "s4": {"holy_ward": 0.8}, "s6": {"magres_x": 10.0, "ward_amp": 0.10}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"holy_blunt": 1.0}, "s6": {"aegis_ext": 0.5}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"mend_evade": 0.02}, "s6": {"leap_cut": 1.0}},
		# opener_holy re-arms on the SET_OPENER_REARM cadence like the 6pc
		# openers (fix 2026-07-28: fresh-only fired exactly once per boss);
		# the knob is the atk multiple banked per opening.
		# retri_amp (ordering retune 2026-07-29): the capstone's premier payload
		# — a standing amp in the stance wrath lives in (the surge_amp/crush_amp
		# seam family). Endgame-only by construction (sets), it carries the part
		# of paladin's called gap the stance knob shouldn't tax at-level; it also
		# ends the accepted D6=D4 tie (swap_amp stays for the off-meta swapper).
		"D": {"s2": {"atk_pct": 0.03, "crit": 0.02}, "s4": {"magpen": 4.0, "opener_holy": 0.6}, "s6": {"swap_amp": 0.15, "retri_amp": 0.10}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"holy_mend_add": 0.01}, "s6": {"holy_mend_lowhp": 1.0}},
	},
	"warlock": {
		"A": {"s2": {"magres": 8.0}, "s4": {"life_ward": 0.03}, "s6": {"magres_x": 10.0, "hexext_ward": 1.0}},
		"B": {"s2": {"physres": 8.0, "critres": 4.0}, "s4": {"pact_cut_stacks": 0.33}, "s6": {"wither_struck": 0.2}},
		"C": {"s2": {"dex": 6.0, "eva": 0.03}, "s4": {"hexext_evade": 1.0}, "s6": {"rift_pull": 0.25}},
		# amp_hexed 0.04 (ordering retune 2026-07-29, from 0.16): on the current
		# tree the class's no-amp baseline alone measures ~52k (mage -5.6%) and
		# the amp reads at face value (hex is near-permanent on the focus
		# target) — 0.16 ran the class ABOVE mage (~60.4k rep-mean, breaking the
		# owner's mage >= warlock). 0.04 lands best-kit ~54k = the called -4%,
		# and prices the 4pc exactly at the displaced-passive band.
		# 6pc stays parked (detonate_amp measured flat vs D4 single-target AND
		# --aoe): warlock's ladder cannot escalate past -4%-under-mage while the
		# baseline sits this high — capstone redesign waits on that adjudication.
		"D": {"s2": {"atk_pct": 0.03, "crit": 0.02}, "s4": {"amp_hexed": 0.04}, "s6": {"detonate_amp": 0.15}},
		"E": {"s2": {"VIT": 8.0}, "s4": {"hp_pct": 0.08, "pact_surge_ext": 1.0}, "s6": {"pact_free_lowhp": 1.0}},
	},
}
# ("magres_x" is the 6pc's EXTRA magres on ward sets — a distinct key so the
# recalc stat-fold doesn't double-apply the 2pc line's plain "magres".)


## One set-tier record ({} when absent). cls -> profile letter -> s2|s4|s6.
static func uniq_set(cls: String, profile: String, tier: String) -> Dictionary:
	return UNIQ_SETS.get(cls, {}).get(profile, {}).get(tier, {})
# ------------------------------------------------- DEX vs evasion (gradient) ---
# DEX answers evasion as a GRADIENT of three tiers, not a flat subtraction
# (2026-07-17). Old rule: eva_curve(e_eva - dex*0.004) then one dodge roll —
# so DEX quietly shaved a dodge CHANCE, and a whiff was a dice roll that
# told the player nothing. New rule: the defender still rolls at its OWN
# evasion, and the attacker's DEX decides what a successful evade DOES:
#   under DEX_GRAZE_RATIO of what the evasion asks -> full MISS (0 damage)
#   at or past it, but short of parity          -> GRAZE (GRAZE_DAMAGE)
#   at or past parity                           -> evasion CANCELLED (no roll)
# The tier is deterministic and legible, so an evasive fight reads as a
# BUILD state you can see and answer, not as bad luck. Deliberately near
# EV-neutral vs the old curve (at half the DEX needed: old = 5% total
# dodges, new = 10% half-damage grazes — same damage through), so this
# re-shapes feel without moving tuning.
#
# WHY NOT a flat tax: a universal "buy 1 DEX gem" is the WoW hit cap — one
# right answer, always, which is an entry fee, not a decision. DEX is meant
# to be a COUNTER-BUILD: only a minority of enemies (the quick lineage) and
# the endgame evasion affix ask for it, so the skill is reading WHEN to slot
# it. Sockets are scarce (A/S gear ~9 total), so paying 2 of them is a real
# trade. Keep evasive enemies a minority or this decays into the hit cap.
#
# NOTE the tiers cut BOTH ways — Stats.resolve is symmetric (player hitting
# an enemy, and enemies hitting a player whose eva came from archer Tumble /
# assassin Enfeeble). An enemy's DEX (scaled off its AGI) reads the player's
# evasion through this same ladder.
const DEX_PER_EVA := 0.004     # DEX -> evasion answered. Parity DEX = e_eva / this (0.30 eva asks 75 DEX)
const DEX_GRAZE_RATIO := 0.5   # fraction of parity DEX where a full miss softens into a graze
const GRAZE_DAMAGE := 0.5      # what a grazed hit pays through

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

# ---------------- expected GEAR-POWER curve (2026-07-28) ---------------------
# Replaces the GEAR_RAMP_* exponent (one hand-tuned rate bolted on past L50 —
# owner: sloppy). The player grows on TWO curves: LEVELS, which the base
# enemy curves track, and GEAR — named uniques (A Act 2+, S Act 3+), profile
# SETS, Lv8-10 gems, deep smith plusses, reforge chases — which they don't.
# This table IS the gear curve, made explicit: at each anchor level, the
# dps-bench-MEASURED damage multiplier of the kit the game actually fields
# by then, relative to the at-level A-grade baseline the curves were tuned
# on (the L42/A finale re-measured ~on budget, so 1.0 at the first anchor —
# uniques haven't stacked yet; L50 also aligns with the NG+ unlock, so
# nothing below it upscales into gear territory). Upscaled monsters' POOLS
# (bosses AND far-field mobs, one call site: story.enemy_stats_at) scale by
# the interpolated ratio — geometric between anchors, FLAT past the last
# (gear stops growing at the cap; deeper-content bite belongs to the growth
# dials, not this curve) — and a monster's native-anchor stats are never
# touched (the ratio is taken from max(its anchor, the first gear anchor)).
# HP ONLY: damage stays on the flat player-tracking dial (L100 patterns
# already land 30-83% of max HP on perfect kits). Anchor provenance (bench
# kits + pins) lives in BALANCE_HISTORY.md; re-measure an anchor with
# dps_bench --ttk [--setprof] whenever a gear phase lands.
const GEAR_POWER_FIRST := 50
# Anchors measured 2026-07-28 (assassin, dps_bench, avg-boss resist sheet):
# 75 = the fielded-kit/A-baseline dps ratio SHAPE (27.9k/5.8k over the same
# frame at 100: 58.9k/6.4k → 0.524 of the 100 anchor); 100 = pinned by the
# owner's endgame proxy — perfect kit (BiS+godroll+set 2pc) ~60k dps kills
# the retuned upscaled Act-1 finale (285.9k authored x2.865 flat dial) in
# ~35s, the middle of the called 30-40s. Mid-endgame (60-85) rides the
# shape anchor until Act-2+ bosses give a real reference (owner caveat).
const GEAR_POWER_ANCHORS := {50: 1.0, 75: 1.38, 100: 2.75}


## Expected gear-power multiplier at `lvl` — geometric interpolation over
## GEAR_POWER_ANCHORS, flat below the first anchor and above the last.
static func gear_power(lvl: int) -> float:
	var lvls: Array = GEAR_POWER_ANCHORS.keys()
	lvls.sort()
	if lvl <= int(lvls[0]):
		return float(GEAR_POWER_ANCHORS[lvls[0]])
	for i in range(1, lvls.size()):
		if lvl <= int(lvls[i]):
			var l0: int = int(lvls[i - 1])
			var l1: int = int(lvls[i])
			var f := float(lvl - l0) / float(l1 - l0)
			return float(GEAR_POWER_ANCHORS[l0]) \
				* pow(float(GEAR_POWER_ANCHORS[l1]) / float(GEAR_POWER_ANCHORS[l0]), f)
	return float(GEAR_POWER_ANCHORS[lvls[-1]])

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
# (No stock cap: health-potion count is limited only by BAG SPACE — each takes
# a slot. BOSS_KILL_POTION_FLOOR retired 2026-07-09: boss kills no longer restock
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

# ----------------------------------------------------- quest abandonment ---
# A side quest ACCEPTED and never finished is settled at the chapter's
# victory beat (game_base._expire_side_quests) — 2026-07-17.
#
# The SHAPE is deliberate, and it is not "a penalty for not finishing". A
# flat fine punishes EXPLORATION: players accept quests to read the content,
# so if saying yes is a trap, the correct play becomes never talking to
# anyone — the exact opposite of what side quests are for. So an abandoned
# quest is never fined. Two things happen instead, and both only take back
# something the player was already given:
#
#  1. The PLEDGE is revoked. Every quest's accept choice PAYS resonance for
#     saying yes (ch1's three all grant +1) — you are paid for a promise at
#     the moment you make it. Walk away and that payment goes back, plus
#     ABANDON_RESONANCE on top: keeping credit for an oath you didn't honour
#     is itself a lean toward Hunger, which is exactly what Resonance
#     measures. This is the hard half, and it is thematically load-bearing —
#     a game whose warlock identity is "the long bargain" cannot let you
#     stroll away from a bargain for free.
#  2. The WORLD reacts, softly. If the quest's reward named factions, the
#     people who asked notice you didn't deliver and lose
#     ABANDON_STANDING_FRAC of what they'd have gained. You lost a reward and
#     gained a story — consequence, not a fine. A quest with no standing
#     reward costs none: a stranger's errand has no faction to disappoint.
#
# Authors may override either half per quest with an "abandon" block on the
# SIDE_QUESTS entry: {"resonance": float, "standing": {fac: int}}.
#
# The deadline must be VISIBLE or this is a feel-bad every time — the journal
# prints it on every accepted quest, and the victory card names every promise
# broken. Expiry without a shown clock was never on the table.
const QUEST_ABANDON_RESONANCE := 3.0      # ON TOP of revoking the accept's pledge
const QUEST_ABANDON_STANDING_FRAC := 0.5  # of the quest's standing reward, LOST instead of gained

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
	{"gold": 120, "renown": 5},
	{"gold": 180, "potions": 1, "renown": 5},
	{"gems": 1, "gem_lvl": 1, "renown": 5},
	{"gold": 300, "renown": 5},
	{"gems": 1, "gem_lvl": 1, "potions": 1, "renown": 5},
	{"gold": 500, "potions": 2, "renown": 5},
	{"gold": 400, "gems": 1, "gem_lvl": 2, "renown": 15},   # day 7 jackpot
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
		{"type": "boss_kills",    "target": 1, "desc": "Slay a boss",        "gold": 220, "renown": 5},
		{"type": "rooms_cleared", "target": 4, "desc": "Clear 4 rooms",      "gold": 150, "renown": 5},
		{"type": "elite_kills",   "target": 2, "desc": "Slay 2 elites",      "gold": 180, "renown": 5},
	],
	"weekly": [
		{"type": "boss_kills",    "target": 5,  "desc": "Slay 5 bosses",    "gold": 800, "gems": 1, "gem_lvl": 2, "renown": 15},
		{"type": "rooms_cleared", "target": 25, "desc": "Clear 25 rooms",   "gold": 700, "gems": 1, "gem_lvl": 2, "renown": 15},
		{"type": "elite_kills",   "target": 10, "desc": "Slay 10 elites",   "gold": 750, "gems": 1, "gem_lvl": 2, "renown": 15},
	],
}

# Weekly vault: kill this many bosses in a trusted-clock week to unlock one
# guaranteed golden-chest reward, claimable once per week (great-vault style).
const VAULT_BOSS_GOAL := 5

# Account-wide stash: cross-character long-term storage (survives any one
# character; lives in user://stash.json, not the per-character save). Kept
# deliberately TIGHT — the stash is a curated keep-safe, not a warehouse.
const STASH_SLOTS := 20

# ----------------------------------------------------------------- renown ---
# Renown — the SEGREGATED event currency (PROPOSALS/SOCIAL_LAYER.md §4,
# DESIGN "Renown & the Wardrobe"): account-wide (meta.json), earned ONLY
# from collected-not-farmed sources (dailies/bounties carry per-entry
# amounts in their tables above; the rest are the consts below), spent
# ONLY on zero-balance-impact goods (chromas, skins, one weekly supply
# cache). Story gold never converts to or from it, so no faucet here
# needs econ_audit calibration — that segregation is the design.
const RENOWN_WEEKLY := 30            # weekly challenge completion (once/week)
const RENOWN_VAULT := 20             # weekly vault claim (once/week)
# First ANY-class clear of a chapter at each NG+ tier (account, one-time
# per chapter x tier) — the tier ladder feeds the status track without
# per-alt farming (per-class would 6x the pool).
const RENOWN_TIER_FIRST_CLEAR := 25
# New-record pushes: paid per unit PAST the class's previous best, so the
# faucet is unfarmable by construction (you can't re-earn a PB).
const RENOWN_PB_CRUCIBLE := 3        # per boss past the previous Crucible PB
const RENOWN_PB_DEPTHS := 2          # per depth past the previous Depths best
# Wardrobe prices. Steady weekly income is ~180 (dailies 45 + bounties
# 85 + vault 20 + weekly 30): a chroma is pocket change, an elite ~1.5
# engaged weeks, a mythic a season goal. First guesses — cosmetic-only,
# so mispricing costs patience, never balance.
const RENOWN_PRICE_CHROMA := 60
const RENOWN_PRICE_ELITE := 240
const RENOWN_PRICE_MYTHIC := 600
# The weekly supply cache: once per trusted-clock week PER CHARACTER, a
# bundle of one of each utility consumable. Renown's only consumable
# faucet — capped so it stays collected-not-farmed and never undercuts
# the alchemist's level-scaled gold shelf.
const RENOWN_CACHE_PRICE := 25
const RENOWN_CACHE_ITEMS := ["mana_potion", "elixir_might", "elixir_ward", "renewal_draught"]
const RENOWN_COLOR := Color(0.78, 0.55, 1.0)   # the violet every Renown surface shares

# ----------------------------------------------------- waking incursions ---
# Weekly world event (ACT2_DESIGN "Waking Incursions", SOCIAL_LAYER step 3):
# the week's rotating chapter (the weekly challenge's own), once CLEARED,
# grows WAKING_ROOMS bonus breach rooms off the spine, each holding a boss
# from a DIFFERENT god-king's domain — the terrain mismatch IS the story.
# Solo worlds only for now (co-op sync is the flagged follow-up, same as
# tiers shipped). Kills bank once per trusted-clock week per character:
# a banked kill pays the gem + gold; banking all three pays the Waking
# Chest + Renown. Repeat visits in the week spawn nothing — collected,
# not farmed.
const WAKING_ROOMS := 3
const WAKING_LEVEL_BONUS := 5     # breaches fight at the chapter finale's level + 5
const WAKING_AFFIXES := 1         # each wears one week-seeded elite affix
const WAKING_GEM_LVL := 3         # banked kill: one bright gem (above the vault's Lv2)
const WAKING_GOLD := 350          # banked kill: bonus gold (level-scaled like the daily)
const RENOWN_WAKING := 25         # all three banked in a week -> the chest + this

static func renown_price(kind: String, tier := "") -> int:
	if kind == "chroma":
		return RENOWN_PRICE_CHROMA
	return RENOWN_PRICE_MYTHIC if tier == "mythic" else RENOWN_PRICE_ELITE

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
const ELIXIR_WARD_DUR := 6.0     # a BURST WINDOW to eat one telegraphed hit (2026-07-21: 25%/20s was a fight-long free mitigation layer — the exact trap the Might nerf closed at 20%/30s)
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
# Combat-arena size variance (2026-07-17): COMBAT rooms vary within a band so
# arenas aren't all identical — a bell curve (extremes rare, per the env-
# distributions-are-curves rule). Boss arenas + safe hubs are NEVER touched
# (boss size may become a per-boss mechanic later). The band tops out at the
# full grid cell, so rooms range (1-VAR)..1.0 of the cell, centred ~1-VAR/2.
const ROOM_SIZE_VAR := 0.15   # max shrink from the full cell (each dimension)
## Safety floor for authored hub-room scales. Content chooses the actual scale;
## this only prevents malformed data collapsing a playable room.
const AUTHORED_ROOM_SCALE_MIN := 0.5

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
# Per-room density JITTER (2026-07-17): rooms roll a fill multiplier in this
# band so density VARIES — some sparse, some dense — instead of a flat count
# everywhere. Scenery is cosmetic, so re-seeding room layouts is harmless.
const SCENERY_DENSITY_JITTER := Vector2(0.6, 1.3)
# ACCENT props are DISTINCTIVE (statues, whole skeletons, shovels, big
# mushrooms) and read as authored groups rather than scatter. CHANCE is the
# seeded odds that each distinct accent GROUP appears; its kind-specific size
# is sampled from a normal distribution in Terrains.ACCENT_PROFILES.
# Trees/rocks/grass remain the repeatable prop tier.
const SCENERY_ACCENT_CHANCE := 0.5
const SCENERY_ACCENT_CHANCE_CAP := 0.9
const SCENERY_ACCENT_GROUP_RADIUS := 72.0
const SCENERY_ACCENT_INTRA_SPACING := 46.0
const SCENERY_ACCENT_MEMBER_TRIES := 16
# Grouping (2026-07-17): some props grow in natural CLUMPS — a stand of trees,
# a patch of mushrooms — instead of always solo; rocks/pillars/landmarks stay
# single (see _groupable). A clump's members count toward the room budget, so
# total density is unchanged — just distributed as some clusters + some singles.
const SCENERY_CLUSTER_CHANCE := 0.25   # odds a groupable placement becomes a clump
# Clump SIZE decays (not a flat roll): a clump starts at 2 and each extra tree
# is only GROW as likely as the last. With GROW 0.5 / DECAY 0.2: 2 ~50%,
# 3 ~45%, 4 ~5%, 5+ impossible (capped at MAX). So pairs/triples are common, a
# dense stand of 4 is rare, and nothing bigger ever spawns.
const SCENERY_CLUSTER_MAX := 4         # hard cap on clump size (5+ impossible)
const SCENERY_CLUSTER_GROW := 0.5      # chance to add a 3rd member
const SCENERY_CLUSTER_GROW_DECAY := 0.2  # each further member that much less likely
const SCENERY_CLUSTER_RADIUS := 95.0   # px spread of a clump around its centre
# High-resolution environment overrides normalize to authored world widths
# instead of inheriting the legacy "native pixels x3" rule. This keeps a 320px
# generated oak and a 48px pack oak in the same combat-readable size band.
const SCENERY_SCALE_JITTER := Vector2(0.88, 1.12)
const SCENERY_RENDER_WIDTH := {
	"tree_green": 190.0, "tree_autumn": 190.0, "tree_gnarled": 230.0,
	"deadtree": 180.0, "log": 130.0, "bush": 112.0,
	"grave_statue": 92.0, "grave_angel": 100.0, "grave_deadtree": 175.0,
	"tombstone": 72.0, "tombstone2": 74.0, "tombstone3": 150.0,
	"tree_snow": 175.0, "tree_winter": 185.0, "ice_cairn": 104.0,
	"storm_conductor": 108.0, "storm_standing_stone": 106.0,
	"frost_reeds": 72.0,
	"tree_teal": 195.0, "tree_spore": 195.0, "spore_shrine": 122.0,
	"spore_vent": 104.0, "cattail": 62.0, "mushroom_purple": 76.0,
	"rock_volcanic": 124.0, "forge_statue": 108.0, "magma_furnace": 120.0,
	"magma_chainrig": 145.0, "cactus": 100.0, "sandstone": 112.0,
	"rock": 64.0, "boulder": 78.0,
	"grass": 52.0, "grass_autumn": 52.0, "grass_frost": 52.0,
	"bush3": 92.0, "flower": 42.0, "mushroom": 50.0,
	"castle_statue": 94.0, "garden_statue": 94.0, "ruin_pillar": 98.0,
	"garden_fountain": 165.0, "topiary": 104.0, "keep_brazier": 102.0,
	"crystal_cluster": 118.0, "crystal_spire": 110.0, "geode": 104.0,
	"void_monolith": 108.0, "void_rift": 94.0, "void_obelisk": 108.0,
}

# Ground-footprint radii for authored high-resolution scenery. The old fixed
# 11px circle belonged to the original 32px tiles and let a hero walk through
# most of a 100-145px boulder, shrine, furnace, or sculpture. Canopies keep
# trunk-sized footprints; broad solid props block their visible bases.
const SCENERY_COLLIDER_RADIUS := {
	"tree_green": 20.0, "tree_autumn": 20.0, "tree_gnarled": 25.0,
	"deadtree": 20.0, "log": 48.0, "bush": 34.0,
	"grave_statue": 26.0, "grave_angel": 30.0, "grave_deadtree": 20.0,
	"tombstone": 20.0, "tombstone2": 21.0, "tombstone3": 38.0,
	"tree_snow": 20.0, "tree_winter": 21.0, "ice_cairn": 32.0,
	"storm_conductor": 34.0, "storm_standing_stone": 31.0,
	"frost_reeds": 12.0,
	"tree_teal": 21.0, "tree_spore": 22.0, "spore_shrine": 38.0,
	"spore_vent": 35.0, "cattail": 10.0, "mushroom_purple": 18.0,
	"rock_volcanic": 42.0, "forge_statue": 32.0, "magma_furnace": 44.0,
	"magma_chainrig": 44.0, "cactus": 23.0, "sandstone": 37.0,
	"rock": 23.0, "boulder": 29.0,
	"bush3": 30.0, "mushroom": 13.0,
	"castle_statue": 27.0, "garden_statue": 27.0, "ruin_pillar": 29.0,
	"garden_fountain": 68.0, "topiary": 31.0, "keep_brazier": 32.0,
	"crystal_cluster": 36.0, "crystal_spire": 31.0, "geode": 34.0,
	"void_monolith": 31.0, "void_rift": 29.0, "void_obelisk": 31.0,
}

# Crownfall composition fallbacks. Authored zone data normally supplies the
# width/offset; these keep malformed or hand-written capital content legible.
const CAPITAL_BACKDROP_WIDTH_FALLBACK := 1200.0
const CAPITAL_LANDMARK_USE_Y_FALLBACK := 80.0
# The arcade is scenery, but it still participates in y-sort: south of its
# baseline the hero is in front; north of it the masonry is in front.
const CAPITAL_BACKDROP_Z := 0

# NPC / station interaction reach (E key, touch Act button, tap-to-talk).
# Capital stations park an attendant NPC beside their hotspot, so several
# interactables can share one reach — the NEAREST candidate wins (game.gd).
const INTERACT_RANGE := 80.0           # player must stand this close to interact
const TAP_TALK_RADIUS := 90.0          # tap-to-talk: max tap distance from the target

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
# RESTRUCTURED 2026-07-21 (owner call): DEPTH == CONTENT LEVEL, 1:1 — "depth
# 73 is level-73 content", one comparable ladder for everyone. The old
# player-relative baseline (player.level + depth) made the same depth a
# different fight per character and punished leveling between runs. The
# ladder starts at the Act-1 cap and never really ends: past each 100-block
# the virtual level keeps climbing (overcap spawns) while the player is
# capped, and the block wears the next difficulty's name — Nightmare's
# hundred, then Torment's. Checkpoints every 10 (a checkpoint boss guards
# each) persist per character; a run re-enters at the highest earned.
const DEPTHS_ENTRY_FLOOR := 40         # depth the first-ever descent starts at (the Act-1 cap)
const DEPTHS_BOSS_EVERY := 5           # a boss guards every 5th depth...
const DEPTHS_CHECKPOINT_EVERY := 10    # ...and every 10th is a CHECKPOINT boss: chest + earned re-entry
const DEPTHS_BLOCK := 100              # each 100-depth block wears the next tier's name
const DEPTHS_BLOCK_NAMES := ["", "THE NIGHTMARE DEPTHS", "THE TORMENT DEPTHS", "THE DEPTHS BEYOND NAMES"]
const DEPTHS_WAVE_SIZE := 4            # trash spawned per non-boss room
const DEPTHS_TERRAIN_ROTATE := 3       # re-theme the arena every N depths
const DEPTHS_GOLD_PER_DEPTH := 45      # linear gold per depth PAST THE FLOOR (keeps the audited curve, shifted)
# Escalation bands, re-keyed to the 10-ladder (spike every 10, owner call):
const DEPTHS_TIER_1AFFIX := 50         # from here, mobs carry 1 random affix
const DEPTHS_TIER_2AFFIX := 60         # mobs 2 affixes, bosses 1
const DEPTHS_TIER_PRESSURE := 70       # the player-debuff band opens here
const DEPTHS_TIER_MAX := 80            # mobs 3 affixes, bosses 2
const DEPTHS_S_MILESTONE_DEPTH := 70   # checkpoint spoils roll S from here (was MILESTONES[2])
# Player debuffs: from the pressure line, one stacking debuff per checkpoint
# band, alternating −damage dealt → +damage taken, forever. The HEALING cut
# was REMOVED (owner call 2026-07-21): it taxed sustain-identity classes
# (archer Second Wind, Grit, the potion economy) asymmetrically while burst-
# mitigation barely noticed — sustain is class design, not a depth tax.
const DEPTHS_DEBUFF_EVERY := 10        # a new debuff stack per this many depths past the line
const DEPTHS_DEBUFF_STEP := 0.10       # each stack is ±10%
const DEPTHS_DEBUFF_FLOOR := 0.20      # −damage-dealt can't drop below this

# Depths boss BUDGET (owner ruling 2026-07-21): a depth-D boss presents as a
# TRUE level-D boss, never an upscaled tourist. The flat boss dial was fit on
# the late-game segment and under-scales low anchors — fangmaw at depth 100
# was a half-second speedbump beside stormmouth's 30s war, a 56x draw
# lottery. The controller now BUDGETS every depth boss's pool/damage
# (endgame._spawn_boss); the roster supplies mechanics and tells, the depth
# supplies the difficulty. Anchored to the 2-MINUTE ruling: a true L100 boss
# holds a MAX-SPECCED player ~120s (pool ~1.3M vs the bench's ~11k ceiling
# DPS). Entry = finale-grade; growth to the cap prices the player's real
# S-gear/gem power curve, then the flat overcap rails carry the blocks.
# Kinds keep a weight-class flavor (later legends weigh more, ±15%);
# affixes multiply ON TOP, so Bulwark still means something.
const DEPTHS_BOSS_POOL_ENTRY := 130000.0   # finale-grade pool at the entry floor (D40)
const DEPTHS_BOSS_POOL_GROWTH := 0.039     # per-depth to the cap → ~1.3M at D100 (the 2-min ruling)
const DEPTHS_BOSS_DMG_ENTRY := 430.0       # finale-grade hit at the entry floor
const DEPTHS_BOSS_DMG_GROWTH := 0.02       # per-depth to the cap → ~73% of a squishy per x1.0 hit at D100

static func depths_boss_pool(depth: int) -> float:
	var to_cap := mini(depth, LEVEL_CAP) - DEPTHS_ENTRY_FLOOR
	var past := maxi(0, depth - LEVEL_CAP)
	return DEPTHS_BOSS_POOL_ENTRY * pow(1.0 + DEPTHS_BOSS_POOL_GROWTH, to_cap) \
		* pow(1.0 + BOSS_HP_GROWTH, past)

static func depths_boss_dmg(depth: int) -> float:
	var to_cap := mini(depth, LEVEL_CAP) - DEPTHS_ENTRY_FLOOR
	var past := maxi(0, depth - LEVEL_CAP)
	return DEPTHS_BOSS_DMG_ENTRY * pow(1.0 + DEPTHS_BOSS_DMG_GROWTH, to_cap) \
		* pow(1.0 + BOSS_DMG_GROWTH, past)

# --- Elite affixes (ACT2 §VI) — spawn-time stat mutations, no per-frame hooks.
# Each carries a display name (worn on the bar), stat scalars, and traits to
# grant. Applied once when the boss/mob spawns (endgame.gd _apply_affix).
const AFFIXES := {
	"frenzied": {"name": "Frenzied", "dmg": 1.30, "speed": 1.20, "traits": ["frenzy"]},
	"bulwark":  {"name": "Bulwark", "hp": 1.70},
	"swift":    {"name": "Swift", "speed": 1.35, "traits": ["swift"]},
	"savage":   {"name": "Savage", "dmg": 1.55},
	# Vampiric reworked 2026-07-21 (owner call): was 2%-max-HP/s regen — a
	# fraction of ITS OWN pool, so Bulwark/upscale inflation pushed the
	# break-even DPS past whole builds (Depths dmg-out debuff made it a
	# literal stalemate). Now LIFESTEAL: heals a fraction of the damage it
	# actually lands on a player — scales with its threat, not its bulk;
	# a vampire you don't feed starves.
	"vampiric": {"name": "Vampiric", "dmg": 1.15, "traits": ["lifesteal"]},
	# Slippery (2026-07-17) is the DEX counter-build's home. Evasion is ADDITIVE
	# ("eva_add"): every scalar above multiplies, and ~every enemy ships eva 0.0,
	# so a multiplier would be a no-op. This is deliberately the ONLY place the
	# game asks for DEX right now — endgame-only, telegraphed on the bar, and one
	# key in six, so slotting Amber is a read on the run rather than a standing
	# tax (see §DEX vs evasion). It is NOT retrofitted onto campaign mobs: DEX
	# gems don't drop until the C band, so an evasive ch1 spider would be a wall
	# with no answer in the bag.
	"slippery": {"name": "Slippery", "eva_add": 0.30, "speed": 1.10},
}
const AFFIX_KEYS := ["frenzied", "bulwark", "swift", "savage", "vampiric", "slippery"]
# Pair exclusion (2026-07-21): the two heavy damage scalars never co-roll.
# Savage x Frenzied multiplied to ~x2 damage, which turns the "+10 levels =
# 2 mistakes" budget into one-shots at the 3-affix depths. One damage
# identity per monster; endgame._pick_affixes enforces it.
const AFFIX_EXCLUSIVE := [["savage", "frenzied"]]
const AFFIX_REGEN_FRAC := 0.02         # the "regen" trait: heal this fraction of max HP/s (no affix uses it since the vampiric rework; kinds may)
const AFFIX_LIFESTEAL_FRAC := 0.30     # "lifesteal" (Vampiric): attacker heals this fraction of damage it lands on a player

## Gem level for endgame per-boss / milestone gems: the ch7 (Act-1 end) floor,
## climbing one level per 10 bosses/depths so a deep run sockets richer.
static func endgame_gem_level(progress: int) -> int:
	return gem_drop_level("ch7") + progress / 10
