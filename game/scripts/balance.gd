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
const ELITE_GEM_LV2_CHANCE := 0.35       # the guaranteed gem rolls Lv2
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

# ----------------------------------------------------------------- rooms ---
# Quiet room types shrink their walled playable area within the fixed
# grid cell (corridors connect the doors to the cell edges).
const SMALL_ROOM_TYPES := ["social", "dead_end", "resonance", "merchant"]
const SMALL_ROOM_INSET := Vector2(420.0, 246.0)
