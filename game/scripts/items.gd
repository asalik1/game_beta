class_name Items
## Gear, grades, chests and shop stock.
## An item is a plain Dictionary:
##   {"slot": "weapon", "grade": "B", "name": "...", "main": {"atk_flat": 14.0},
##    "subs": {"crit": 0.04}, "plus": 0}   (plus = upgrade level from the smith)

const GRADES := ["F", "E", "D", "C", "B", "A", "S"]
const GRADE_MULT := {"F": 0.5, "E": 0.75, "D": 1.0, "C": 1.35, "B": 1.8, "A": 2.4, "S": 3.2}
const GRADE_COLOR := {
	"F": Color(0.62, 0.62, 0.62), "E": Color(0.92, 0.92, 0.92),
	"D": Color(0.45, 0.85, 0.45), "C": Color(0.40, 0.65, 1.00),
	"B": Color(0.75, 0.45, 0.95), "A": Color(1.00, 0.60, 0.20),
	"S": Color(1.00, 0.30, 0.30),
}

# Per-grade pickup chime (loot fanfare — the rarity is audible before
# it's readable). Keys are Sfx bank entries.
const LOOT_SOUND := {
	"F": "loot_low", "E": "loot_low", "D": "loot_mid", "C": "loot_mid",
	"B": "loot_b", "A": "loot_a", "S": "loot_s",
}

static func loot_sound(grade: String) -> String:
	return String(LOOT_SOUND.get(grade, "loot_low"))

const SLOTS := ["weapon", "armor", "boots", "charm"]
const SLOT_ICON := {"weapon": "⚔", "armor": "🛡", "boots": "👢", "charm": "❖"}

# Every piece's MAIN is the wearer-class's PRIMARY attribute (player
# rule, 2026-07-06, WoW-style): guaranteed, class-matched, slot-budgeted
# points that convert through Classes.ATTR_SCALE exactly like allocated
# talent points — a dagger literally cannot carry INT. (Old slot mains —
# weapon ATK / armor HP / boots Speed / charm Haste — are retired; legacy
# ATK/HP mains on old saves still count, banned ones are stripped on load.)
# Budgets sized (2026-07-06) so the L42 full-B benchmark loadout lands
# within ~1-2% of the pre-attribute-mains power envelope: attributes
# convert SUB-1 to ATK (0.9 — player rule: 100 STR = 90 ATK + 120 HP),
# and the total slot budget stays small enough that gear attributes
# never outrun the ~5.5%/level player curve every boss is pinned to.
const SLOT_MAIN_BUDGET := {"weapon": 5.0, "armor": 3.0, "boots": 2.0, "charm": 2.5}
# Mirror of Classes.CLASSES[cls]["primary"] — items.gd must not preload
# classes.gd (same rule as CLASSES_DMG_TYPE below).
const CLASS_PRIMARY := {
	"warrior": "STR", "paladin": "STR",
	"archer": "AGI", "assassin": "AGI",
	"mage": "INT", "warlock": "INT",
}

# Weapon shapes a class can actually be DEALT (round 15: an archer was
# looting Tomes). Since 2026-07-06 gear is also class-LOCKED at equip
# (item["cls"]) — a mage cannot wear an assassin's boots.
const CLASS_WEAPONS := {
	"warrior": ["Blade", "Edge", "Claymore"],
	"archer": ["Bow", "Crossbow"],
	"assassin": ["Fang", "Shuriken"],
	"mage": ["Staff", "Wand"],
	"paladin": ["Hammer", "Blade"],
	"warlock": ["Tome", "Wand"],
}

const SLOT_NAMES := {
	"weapon": ["Blade", "Edge", "Fang", "Shuriken", "Claymore", "Bow", "Crossbow", "Staff", "Wand", "Hammer", "Tome"],
	"armor":  ["Plate", "Mail", "Guard"],
	"boots":  ["Boots", "Striders", "Treads"],
	"charm":  ["Charm", "Talisman", "Sigil"],
}

# One representative prefix per grade (used in the codex).
const GRADE_PREFIX := {
	"F": "Rusty", "E": "Worn", "D": "Tempered", "C": "Fine",
	"B": "Runed", "A": "Dragonforged", "S": "Emberforged",
}

# Rolled items pick a random prefix from their grade's pool,
# so drops read like "Fine Shuriken" or "Masterwork Claymore". Prefixes are
# CLASS-NEUTRAL quality adjectives (2026-07-08): the old martial words
# (Knight's/Soldier's/Militia/Veteran's/Warlord's) read wrong on an
# assassin's dagger or a mage's wand ("Knight's Fang"). Keep any new prefix
# fitting for every class's gear.
const PREFIXES := {
	"F": ["Rusty", "Cracked", "Chipped", "Bent"],
	"E": ["Worn", "Plain", "Sturdy", "Simple"],
	"D": ["Tempered", "Honed", "Polished", "Keen"],
	"C": ["Fine", "Gilded", "Wrought", "Refined"],
	"B": ["Runed", "Masterwork", "Enchanted", "Pristine"],
	"A": ["Dragonforged"],
	"S": ["Emberforged"],
}

# A-grade items get a unique epic name instead of "prefix + noun".
const A_NAMES := {
	"weapon": ["The Ruined King's Sword", "Oathbreaker", "Dawnsplitter", "Widow's Bite", "The Shadow God's Dagger", "Lightbringer", "The Pactkeeper's Grimoire"],
	"armor":  ["Bulwark of the Last Watch", "Heartguard", "The Unyielding", "Wyrmscale Cuirass", "Faithwall"],
	"boots":  ["Windrunner Greaves", "Shadowdancer Treads", "Gravewalkers", "Stormchaser Boots", "Pilgrim's Resolve"],
	"charm":  ["Eye of the Storm", "The Widow's Locket", "Emberheart", "Tear of the Old God", "Sigil of the Broken Pact"],
}

# S-grade gear is CLASS-EXCLUSIVE: unique name + synergy stats,
# and S weapons carry a passive ability (implemented in player.gd).
const S_GEAR := {
	"warrior": {
		"weapon": {"name": "Kingsbane, Edge of the Fallen Crown", "passive": "kingsblade", "noun": "Blade"},
		"armor":  {"name": "Aegis of the Mountain",   "subs": {"hp_pct": 0.15, "physres": 20.0}},
		"boots":  {"name": "Earthshaker Sabatons",    "subs": {"hp_pct": 0.10, "physres": 10.0}},
		"charm":  {"name": "Warlord's Iron Oath",     "subs": {"atk_pct": 0.10, "physpen": 10.0}},
	},
	"archer": {
		"weapon": {"name": "Stormcaller, Bow of the Tempest", "passive": "windward", "noun": "Bow"},
		"armor":  {"name": "Cloak of a Thousand Leaves", "subs": {"hp_pct": 0.10, "eva": 0.05}},
		"boots":  {"name": "Zephyr's Grace",             "subs": {"dex": 8.0, "crit": 0.06}},
		"charm":  {"name": "The Hawk God's Eye",         "subs": {"crit": 0.10, "atk_pct": 0.12}},
	},
	"mage": {
		"weapon": {"name": "Heart of the Phoenix", "passive": "wellspring", "noun": "Staff"},
		"armor":  {"name": "Robes of the Infinite", "subs": {"hp_pct": 0.10, "magres": 18.0}},
		"boots":  {"name": "Steps of the Void",     "subs": {"eva": 0.04, "magres": 12.0}},
		"charm":  {"name": "The Archmage's Folly",  "subs": {"crit": 0.08, "magpen": 10.0}},
	},
	"assassin": {
		"weapon": {"name": "Nightfang, Kiss of the Abyss", "passive": "mirrorstep", "noun": "Fang"},
		"armor":  {"name": "Shroud of Silence", "subs": {"hp_pct": 0.08, "eva": 0.04}},
		"boots":  {"name": "Whisperwind",       "subs": {"dex": 8.0, "crit": 0.05}},
		"charm":  {"name": "The Bloodpact",     "subs": {"crit": 0.08, "atk_pct": 0.10}},
	},
	"paladin": {
		"weapon": {"name": "Dawnbreaker, Hammer of the Highfather", "passive": "dawnbreaker", "noun": "Hammer"},
		"armor":  {"name": "Bulwark of the Dawn",  "subs": {"hp_pct": 0.12, "physres": 14.0, "magres": 14.0}},
		"boots":  {"name": "Greaves of the Vigil", "subs": {"hp_pct": 0.08, "magres": 10.0}},
		"charm":  {"name": "The Highfather's Oath", "subs": {"atk_pct": 0.10, "physres": 8.0}},
	},
	"warlock": {
		"weapon": {"name": "Grimoire of the Hollow Choir", "passive": "voidmaw", "noun": "Tome"},
		"armor":  {"name": "Vestments of the Long Bargain", "subs": {"hp_pct": 0.10, "magres": 16.0}},
		"boots":  {"name": "Voidwalkers",                   "subs": {"magpen": 8.0, "hp_pct": 0.06}},
		"charm":  {"name": "The First Debt",                "subs": {"atk_pct": 0.10, "magpen": 6.0}},
	},
}

const PASSIVES := {
	"kingsblade":  "Cleave hurls a sword wave",
	"windward":    "Second Wind kicks in after just 1.5s untouched (from 3s)",
	"wellspring":  "+50% mana regen; Frost Nova and Blink cool down 8% faster",
	"mirrorstep":  "Dashing reflects nearby projectiles and softens AoE damage",
	"dawnbreaker": "Judgment calls down a pillar of light (splash + holy burn)",
	"voidmaw":     "Void Rift ends with a curse-wave: shoves enemies off you and curses the room",
}

# ------------------------------------------------------------------- gems ---
# A gem grants exactly ONE stat. Equipment B+ has sockets (B:1, A:2, S:3).
# Synthesis: 3 gems of the same stat & level -> 1 gem of the next level.

const GEM_SLOTS := {"F": 0, "E": 0, "D": 0, "C": 0, "B": 1, "A": 2, "S": 3}
# A+ gear unlocks ONE dedicated SPECIAL slot that ONLY takes special gems
# (Balance.SPECIAL_GEM_STATS); every other socket is REGULAR and takes only
# regular gems (2026-07-08). So B = 1 regular; A = 1 regular + 1 special;
# S = 2 regular + 1 special. You can't stack specials (one slot, and one gem
# per stat across gear), and you can't skip them (a regular gem can't go in
# the special slot). Reforge-added sockets are always regular (this stays 1).
const GEM_SPECIAL_SLOTS := {"F": 0, "E": 0, "D": 0, "C": 0, "B": 0, "A": 1, "S": 1}


## How many SPECIAL-only slots this grade's gear carries (A+ = 1, else 0).
static func special_slots(grade: String) -> int:
	return int(GEM_SPECIAL_SLOTS.get(grade, 0))


## How many REGULAR-only slots (total sockets minus the special one).
static func regular_slots(grade: String) -> int:
	return int(GEM_SLOTS.get(grade, 0)) - int(GEM_SPECIAL_SLOTS.get(grade, 0))
const GEM_MAX_LEVEL := 10
# A vessel holds what it can bear (player rule, 2026-07-06): each grade
# caps the gem LEVEL it can socket — deep gems need endgame gear.
const GEM_LEVEL_LIMIT := {"F": 0, "E": 0, "D": 0, "C": 0, "B": 3, "A": 6, "S": 10}

# stat -> [display name, base value per level-ish, color]
const GEM_STATS := {
	"atk_flat": {"name": "Ruby",      "base": 1.0,   "color": Color(1.0, 0.3, 0.3)},  # FLAT atk (+1/lvl-ish), NOT a % — a regular gem that doesn't scale, so stacking it can't runaway
	"hp_pct":   {"name": "Garnet",    "base": 0.025, "color": Color(0.9, 0.45, 0.45)},
	"crit":     {"name": "Topaz",     "base": 0.012, "color": Color(1.0, 0.8, 0.3)},
	"dmg_pct":  {"name": "Sunstone",  "base": 0.02,  "color": Color(1.0, 0.6, 0.2)},  # universal DAMAGE increase (special slot); replaced the crit-only crit_dmg gem
	"cdr":      {"name": "Sapphire",  "base": 0.01,  "color": Color(0.35, 0.55, 1.0)},
	"combo":    {"name": "Opal",      "base": 0.01,  "color": Color(0.85, 0.9, 1.0)},
	"physres":  {"name": "Onyx",      "base": 4.0,   "color": Color(0.5, 0.5, 0.6)},
	"magres":   {"name": "Lapis",     "base": 4.0,   "color": Color(0.4, 0.5, 0.9)},
	"physpen":  {"name": "Bloodstone", "base": 2.5,  "color": Color(0.7, 0.2, 0.3)},
	"magpen":   {"name": "Amethyst",  "base": 2.5,   "color": Color(0.7, 0.4, 0.95)},
	"eva":      {"name": "Jade",      "base": 0.008, "color": Color(0.4, 0.85, 0.5)},
	"dex":      {"name": "Amber",     "base": 2.0,   "color": Color(0.95, 0.7, 0.3)},
	"greed":    {"name": "Goldstone", "base": 0.03,  "color": Color(1.0, 0.85, 0.3)},
	"lifesteal": {"name": "Vampire Eye", "base": 0.006, "color": Color(0.8, 0.2, 0.5)},
}


static func make_gem(stat: String, lvl := 1) -> Dictionary:
	return {"gem": true, "stat": stat, "lvl": lvl}


static func random_gem(rng: RandomNumberGenerator, lvl := 1, allow_special := true) -> Dictionary:
	var keys := GEM_STATS.keys()
	if not allow_special:
		# Early chapters roll REGULAR stats only (Balance.special_gems_drop).
		keys = keys.filter(func(k: String) -> bool: return not (k in Balance.SPECIAL_GEM_STATS))
	return make_gem(keys[rng.randi_range(0, keys.size() - 1)], lvl)


# ------------------------------------------------------------------ bags ---
# The bag is carried capacity for everything NOT equipped: gear, GEM
# STACKS (one slot per stat+level, round 7) and consumables share its
# slots. Round 52: the hero equips UP TO Balance.MAX_BAGS bags and their
# slots SUM. Bags drop from bosses/elites (act-tiered) and stock cheap at
# merchants. Round 52b: capacity counts UNITS not kinds — every gem and
# consumable UNIT takes a slot (stacking is DISPLAY-only), so the curve is
# bumped one step (F 10 .. S 40, +5/tier) to compensate. Capacity spans
# 1 bag (10) to 5xS (200). Stacking bags is the growth axis, not one bag.
const BAG_SLOTS := {"F": 10, "E": 15, "D": 20, "C": 25, "B": 30, "A": 35, "S": 40}
const BAG_NAMES := {
	"F": "Frayed Pouch", "E": "Patched Satchel", "D": "Soldier's Knapsack",
	"C": "Knight's Rucksack", "B": "Runed Haversack", "A": "Dragonhide Duffel",
	"S": "Emberforged Hold",
}


static func make_bag(grade: String) -> Dictionary:
	return {"kind": "bag", "grade": grade, "name": BAG_NAMES[grade],
		"slots": int(BAG_SLOTS[grade])}


static func bag_price(grade: String) -> int:
	return int(40.0 * GRADE_MULT[grade])


## The two Frayed Pouches every new hero starts with (Balance.STARTER_BAGS).
static func starter_bags() -> Array:
	var out: Array = []
	for g in Balance.STARTER_BAGS:
		out.append(make_bag(String(g)))
	return out


## Merchant buy price for a bag — QoL-cheap, flat per tier (Balance table).
static func bag_buy_price(grade: String) -> int:
	return int(Balance.BAG_BUY_PRICE.get(grade, 30))


# ----------------------------------------------------------- consumables ---
# Non-gear bag items ({"kind": "stone", ...}). The talent reset stone is
# the first; elites are the primary source (playtest round 6).

# Potions eligible for the room LOADOUT (2026-07-07 v2): slotted from
# the inventory, cycled with the potion_next bind, budgeted per room
# (Balance.POTION_SLOTS_BY_ACT; unassigned slots drink as health).
# Scrolls and stones stay inventory-clicked utilities.
const ROTATION_POTIONS := ["mana_potion", "elixir_might"]
static func make_reset_stone() -> Dictionary:
	return {"kind": "stone", "id": "reset_stone", "grade": "B",
		"name": "Stone of Unlearning",
		"desc": "Crush it to refund EVERY allocated talent point (attributes and substats) for reallocation."}


## The skill-tree twin of the reset stone: a manuscript scraped clean
## and rewritten — the tree forgets, you choose again. Elite drop,
## rarer than the stone (Balance.ELITE_TOME_CHANCE).
static func make_respec_tome() -> Dictionary:
	return {"kind": "stone", "id": "tree_tome", "grade": "B",
		"name": "Palimpsest of the Path",
		"desc": "Crush it to refund EVERY spent skill point — the tree forgets, you choose a new path."}


## Utility consumables (round 47) — bought from merchants, used from the
## bag. Distinct from the health-potion counter (that lives on the player).
static func make_mana_potion() -> Dictionary:
	return {"kind": "stone", "id": "mana_potion", "grade": "D",
		"name": "Mana Draught",
		"desc": "Restore %d%% of your maximum mana." % int(Balance.MANA_POTION_FRAC * 100)}


static func make_elixir_might() -> Dictionary:
	return {"kind": "stone", "id": "elixir_might", "grade": "C",
		"name": "Elixir of Might",
		"desc": "+%d%% damage for %ds." % [int(Balance.ELIXIR_MIGHT_AMT * 100), int(Balance.ELIXIR_MIGHT_DUR)]}


static func make_recall_scroll() -> Dictionary:
	return {"kind": "stone", "id": "recall_scroll", "grade": "D",
		"name": "Scroll of Recall",
		"desc": "Whisk yourself back to the last safe room you rested in."}


static func make_elixir_ward() -> Dictionary:
	return {"kind": "stone", "id": "elixir_ward", "grade": "C",
		"name": "Elixir of Warding",
		"desc": "Cut incoming damage by %d%% for %ds. Quaff it before a heavy blow lands." % [int(Balance.ELIXIR_WARD_AMT * 100), int(Balance.ELIXIR_WARD_DUR)]}


static func make_renewal_draught() -> Dictionary:
	return {"kind": "stone", "id": "renewal_draught", "grade": "C",
		"name": "Draught of Renewal",
		"desc": "Instantly restore %d%% of your maximum health." % int(Balance.RENEWAL_HEAL_FRAC * 100)}


# ------------------------------------------------------------ quest items ---
# Bag riders with no use-click: they exist to be GIVEN (convo choices
# grant/collect them via "gain_item"/"lose_item"). Run-scoped — the
# purge in game_flow._wipe_chapter_flags deletes kind "quest" from the
# bag when the run ends, alongside the flags that earned them.
# Content modules author theirs in a QUEST_ITEMS const ({id: {name,
# desc, grade?}} — merged into Story.ALL_QUEST_ITEMS); base-game ones
# live in the match below.
static func make_quest_item(id: String) -> Dictionary:
	match id:
		"millers_hat":
			return {"kind": "quest", "id": "millers_hat", "grade": "C",
				"name": "The Miller's Hat",
				"desc": "Wide-brim, brown, heron feather — blue at the tip. A boy at the village edge is waiting on it."}
	var q: Dictionary = Story.ALL_QUEST_ITEMS.get(id, {})
	if q.is_empty():
		return {}
	var out := q.duplicate(true)
	out["kind"] = "quest"
	out["id"] = id
	if not out.has("grade"):
		out["grade"] = "C"
	return out


## The stat value a gem grants at its level (superlinear growth).
static func gem_value(gem: Dictionary) -> float:
	var base: float = GEM_STATS[gem["stat"]]["base"]
	var lvl: int = gem["lvl"]
	return base * lvl * (1.0 + 0.18 * (lvl - 1))


static func gem_title(gem: Dictionary) -> String:
	var info: Dictionary = GEM_STATS[gem["stat"]]
	var v := gem_value(gem)
	var val_txt := "+%d" % int(v) if gem["stat"] in FLAT_STATS else "+%d%%" % int(round(v * 100))
	return "%s Lv%d  (%s %s)" % [info["name"], gem["lvl"], STAT_LABEL[gem["stat"]], val_txt]


static func gem_color(gem: Dictionary) -> Color:
	return GEM_STATS[gem["stat"]]["color"]

# Every shape has a stat personality: a main-stat multiplier plus
# guaranteed bonus stats. A Claymore hits like a truck, a Shuriken crits.
const SHAPE_STYLE := {
	"Blade":    {"main": 1.0,  "subs": {"atk_pct": 0.05}, "tag": "balanced"},
	"Edge":     {"main": 1.2,  "subs": {}, "tag": "heavy hits"},
	"Fang":     {"main": 0.85, "subs": {"crit": 0.05}, "tag": "crit"},
	"Shuriken": {"main": 0.8,  "subs": {"crit": 0.04, "dex": 3.0}, "tag": "crit + aim"},
	"Kunai":    {"main": 0.8,  "subs": {"crit": 0.04, "dex": 3.0}, "tag": "crit + aim"},  # back-compat: pre-2026-07-08 saves stored the "Kunai" noun
	"Claymore": {"main": 1.4,  "subs": {}, "tag": "massive damage"},
	"Bow":      {"main": 0.9,  "subs": {"dex": 5.0}, "tag": "true aim"},
	"Crossbow": {"main": 1.05, "subs": {"physpen": 5.0}, "tag": "penetration"},
	"Staff":    {"main": 0.95, "subs": {"mp_flat": 15.0, "atk_pct": 0.04}, "tag": "mana + power"},
	"Wand":     {"main": 0.85, "subs": {"crit": 0.03, "magpen": 3.0}, "tag": "crit + magic pen"},
	"Hammer":   {"main": 1.25, "subs": {"hp_flat": 20.0}, "tag": "crushing + sturdy"},
	"Tome":     {"main": 0.9,  "subs": {"magpen": 4.0, "mp_flat": 12.0}, "tag": "dark power"},
	"Plate":    {"main": 1.15, "subs": {}, "tag": "bulk"},
	"Mail":     {"main": 0.9,  "subs": {"eva": 0.015}, "tag": "elusive"},
	"Guard":    {"main": 0.95, "subs": {"physres": 10.0}, "tag": "physical resistance"},
	"Boots":    {"main": 1.0,  "subs": {}, "tag": "balanced"},
	"Striders": {"main": 0.9,  "subs": {"eva": 0.02}, "tag": "elusive"},
	"Treads":   {"main": 0.85, "subs": {"hp_flat": 25.0}, "tag": "sturdy"},
	"Charm":    {"main": 1.0,  "subs": {}, "tag": "balanced"},
	"Talisman": {"main": 0.85, "subs": {"atk_pct": 0.05}, "tag": "power"},
	"Sigil":    {"main": 0.85, "subs": {"crit": 0.05}, "tag": "crit"},
}

# Substat pool: stat -> base roll (scaled a little by grade).
# Mirror of Classes.CLASSES[cls]["dmg_type"] — items.gd must not preload
# classes.gd (content modules preload items early).
const CLASSES_DMG_TYPE := {
	"warrior": "phys", "archer": "phys", "assassin": "phys",
	"paladin": "magic", "mage": "magic", "warlock": "magic",
}

# The SPECIAL stats (Haste/Lifesteal/Combo/Greed) are deliberately
# ABSENT: they are gem-only (Balance.SPECIAL_GEM_STATS) — gems are the
# gateway to off-build stats, and each item sockets at most one special
# gem. MOVEMENT SPEED is absent for a harder reason: it is sovereign —
# only terrain and abilities may touch it (dodging is life or death;
# player rule 2026-07-06). Supersedes round 43's B-gate.
const SUBSTATS := {
	"atk_pct": 0.05, "hp_pct": 0.06, "crit": 0.03,
	"VIT": 3.0,
	"physres": 9.0, "magres": 9.0, "critres": 6.0, "eva": 0.02, "dex": 4.0,
	"physpen": 5.0, "magpen": 5.0, "mp_flat": 12.0,
}

const STAT_LABEL := {
	"atk_flat": "ATK", "hp_flat": "HP", "atk_pct": "ATK%", "hp_pct": "HP%",
	"STR": "STR", "AGI": "AGI", "INT": "INT", "VIT": "VIT",
	"crit": "Crit", "crit_dmg": "CritDmg", "dmg_pct": "Damage", "cdr": "Haste", "speed_pct": "Speed",
	"lifesteal": "Lifesteal", "greed": "Greed", "mp_flat": "MP",
	"physres": "PhysRes", "magres": "MagRes", "critres": "CritRes",
	"eva": "EVA", "dex": "DEX", "physpen": "PhysPen", "magpen": "MagPen",
	"combo": "Combo",
}

# Stats measured in flat points rather than percent (for display).
const FLAT_STATS := ["atk_flat", "hp_flat", "mp_flat", "physres", "magres", "critres", "dex", "physpen", "magpen", "STR", "AGI", "INT", "VIT"]

# Chest tiers -> grade weights.
const CHEST_TIERS := {
	"wood":   {"sprite": "chest_wood",   "weights": {"F": 40, "E": 30, "D": 20, "C": 10}},
	"silver": {"sprite": "chest_silver", "weights": {"D": 30, "C": 35, "B": 25, "A": 10}},
	"gold":   {"sprite": "chest_gold",   "weights": {"B": 35, "A": 40, "S": 25}},
}


static func roll_grade(tier: String, rng: RandomNumberGenerator, cap := "S") -> String:
	var weights: Dictionary = CHEST_TIERS[tier]["weights"]
	var total := 0
	for w in weights.values():
		total += w
	var pick := rng.randi_range(1, total)
	for grade in weights:
		pick -= weights[grade]
		if pick <= 0:
			# Act loot ceiling (game.loot_cap): anything rolled above the
			# chapter's cap collapses TO the cap — a gold chest in Act 1
			# pays the act's best, never endgame gear.
			if GRADES.find(String(grade)) > GRADES.find(cap):
				return cap
			return grade
	return "F"


static func roll_item(tier: String, rng: RandomNumberGenerator, cls := "", cap := "S") -> Dictionary:
	var grade := roll_grade(tier, rng, cap)
	var slot := _roll_slot(grade, rng)
	return roll_item_of(slot, grade, rng, cls)


## Pick a gear slot. S-tier down-weights WEAPON (Balance.S_WEAPON_DROP_WEIGHT):
## the class legendary weapon carries the endgame passive, so it is the single
## rarest slot. Sub-S rolls stay uniform. All gear channels funnel through here.
static func _roll_slot(grade: String, rng: RandomNumberGenerator) -> String:
	if grade != "S":
		return SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var total := 0.0
	var cum: Array = []
	for s in SLOTS:
		total += Balance.S_WEAPON_DROP_WEIGHT if s == "weapon" else 1.0
		cum.append(total)
	var pick := rng.randf() * total
	for i in SLOTS.size():
		if pick <= float(cum[i]):
			return SLOTS[i]
	return SLOTS[SLOTS.size() - 1]


## One gear item of an exact grade (slot picked via _roll_slot). Used by the
## boss gear channel and the act-appearance shop roll.
static func roll_gear_of_grade(grade: String, rng: RandomNumberGenerator, cls := "") -> Dictionary:
	return roll_item_of(_roll_slot(grade, rng), grade, rng, cls)


## Grade a SHOP stock slot rolls (act appearance weights), clamped to loot_cap.
static func roll_shop_grade(chid: String, rng: RandomNumberGenerator, cap: String) -> String:
	var act: int = int(Balance.CHAPTER_ECON.get(chid, {}).get("act", 1))
	var weights: Dictionary = Balance.SHOP_GEAR_WEIGHTS.get(act, {"C": 1})
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var pick := rng.randf() * total
	var cap_i := GRADES.find(cap)
	for grade in weights:
		pick -= float(weights[grade])
		if pick <= 0.0:
			return cap if GRADES.find(String(grade)) > cap_i else String(grade)
	return cap


## The BOSS gear/bag drop channel: highest act-table grade that hits, or "".
## Each listed grade rolls independently; a lucky S beats a simultaneous A.
static func roll_boss_gear_grade(chid: String, rng: RandomNumberGenerator) -> String:
	var odds: Dictionary = Balance.boss_gear_odds(chid)
	var best := ""
	for grade in GRADES:  # F..S ascending, so the last hit is the highest
		if odds.has(grade) and rng.randf() < float(odds[grade]):
			best = String(grade)
	return best


## The class's signature weapon shape (from its S legendary) — used by
## the dev gear sets and class swaps so a mage never holds a Claymore.
static func class_weapon_noun(cls: String) -> String:
	if S_GEAR.has(cls):
		return S_GEAR[cls]["weapon"].get("noun", "Blade")
	return "Blade"


static func roll_item_of(slot: String, grade: String, rng: RandomNumberGenerator, cls := "", force_noun := "") -> Dictionary:
	var mult: float = GRADE_MULT[grade]
	var noun_list: Array = SLOT_NAMES[slot]
	if slot == "weapon" and cls != "" and CLASS_WEAPONS.has(cls):
		noun_list = CLASS_WEAPONS[cls]
	var noun: String = force_noun if force_noun != "" else noun_list[rng.randi_range(0, noun_list.size() - 1)]
	if grade == "S" and cls != "" and S_GEAR.has(cls) and S_GEAR[cls][slot].has("noun"):
		noun = S_GEAR[cls][slot]["noun"]  # legendaries use their class shape
	var style: Dictionary = SHAPE_STYLE.get(noun, {"main": 1.0, "subs": {}})

	# The main is the class's primary attribute, guaranteed (2026-07-06).
	var primary := String(CLASS_PRIMARY.get(cls, "STR"))
	var main := {primary: snappedf(SLOT_MAIN_BUDGET[slot] * mult * style["main"]
		* rng.randf_range(0.9, 1.15), 0.01)}
	var subs := roll_subs(grade, noun, cls, rng)

	var item := {
		"slot": slot, "grade": grade, "noun": noun,
		"main": main, "subs": subs, "plus": 0,
		"gem_slots": GEM_SLOTS[grade], "gems": [],
	}
	if cls != "":
		item["cls"] = cls  # class-locked: only this class may EQUIP it
	var prefix_pool: Array = PREFIXES[grade]
	item["name"] = "%s %s" % [prefix_pool[rng.randi_range(0, prefix_pool.size() - 1)], item["noun"]]

	# A-grade: epic unique names.
	if grade == "A":
		var names: Array = A_NAMES[slot]
		item["name"] = names[rng.randi_range(0, names.size() - 1)]

	# S-grade: class-exclusive legendary with synergy stats / a passive.
	if grade == "S" and cls != "" and S_GEAR.has(cls):
		var special: Dictionary = S_GEAR[cls][slot]
		item["name"] = special["name"]
		item["cls"] = cls
		if special.has("noun"):
			item["noun"] = special["noun"]
		if special.has("passive"):
			item["passive"] = special["passive"]
			# Round 51b: a looted/bought legendary keeps its NAME and top stats
			# but its signature passive SLEEPS — it grants no effect until the
			# class's awakening quest sets s_awakened_<cls> (see Player.s_passive).
			item["passive_dormant"] = true
		if special.has("subs"):
			for stat in special["subs"]:
				subs[stat] = special["subs"][stat]
	return item


## Roll an item's substat set: `sub_count` random affixes for the grade
## (class-appropriate, endgame stats gated below B) plus the shape's
## guaranteed personality stats. Shared by drops (roll_item_of) and the
## reforge bench (reforge_affixes).
static func roll_subs(grade: String, noun: String, cls: String, rng: RandomNumberGenerator) -> Dictionary:
	var mult: float = GRADE_MULT[grade]
	var style: Dictionary = SHAPE_STYLE.get(noun, {"main": 1.0, "subs": {}})
	# Higher grades roll more substats (F/E: 0, D/C: 1, B/A: 2, S: 3).
	var sub_count := maxi(0, (GRADES.find(grade) - 1) / 2)
	var subs := {}
	var pool := SUBSTATS.keys()
	# No dead stats (round 15): a class only rolls the penetration its own
	# damage type can use. Everything else stays class-neutral.
	# (Special stats — Haste/Lifesteal/Combo/Greed — aren't in the pool at
	# all since 2026-07-06: gem-only, superseding round 43's B-gate.)
	if cls != "" and CLASSES_DMG_TYPE.has(cls):
		pool.erase("physpen" if CLASSES_DMG_TYPE[cls] == "magic" else "magpen")
	pool.shuffle()
	for i in mini(sub_count, pool.size()):
		var stat: String = pool[i]
		subs[stat] = snappedf(SUBSTATS[stat] * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	for stat in style["subs"]:
		subs[stat] = snappedf(subs.get(stat, 0.0) + style["subs"][stat] * (0.75 + 0.25 * mult), 0.01)
	return subs


# ------------------------------------------------------------ reforge bench ---
# Deterministic-ish crafting on OWNED gear (gold sink). Three crafts:
# reroll one substat's magnitude, reroll the whole affix set, or add a gem
# socket (B+ only, capped). Costs scale with grade.
const REFORGE_COST := {"F": 40, "E": 60, "D": 90, "C": 140, "B": 220, "A": 340, "S": 500}
const MAX_SOCKETS := 3

## Gold cost of a reforge on this item. kind: "sub" | "affix" | "socket".
static func reforge_cost(item: Dictionary, kind: String) -> int:
	var base: int = REFORGE_COST.get(String(item["grade"]), 100)
	match kind:
		"affix": return base * 2
		"socket": return base * 3
		_: return base


## Reroll the MAGNITUDE of one existing substat (keeps which stat it is).
static func reforge_sub(item: Dictionary, stat: String, rng: RandomNumberGenerator) -> void:
	if not item.get("subs", {}).has(stat):
		return
	var mult: float = GRADE_MULT[item["grade"]]
	if SUBSTATS.has(stat):
		item["subs"][stat] = snappedf(SUBSTATS[stat] * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	else:
		item["subs"][stat] = snappedf(float(item["subs"][stat]) * rng.randf_range(0.8, 1.2), 0.01)


## Reroll WHICH substats the item carries (and their values) — the affix
## reroll loop. S-gear synergy subs are preserved (never rerolled away).
static func reforge_affixes(item: Dictionary, cls: String, rng: RandomNumberGenerator) -> void:
	var fresh := roll_subs(String(item["grade"]), String(item.get("noun", "Blade")), cls, rng)
	# Keep an S legendary's signature subs on top of the fresh roll.
	if String(item["grade"]) == "S" and item.has("cls") and S_GEAR.has(String(item["cls"])):
		var special: Dictionary = S_GEAR[String(item["cls"])][String(item["slot"])]
		for stat in special.get("subs", {}):
			fresh[stat] = special["subs"][stat]
	item["subs"] = fresh


## Can this item take another gem socket? B+ only, capped at MAX_SOCKETS.
static func can_add_socket(item: Dictionary) -> bool:
	return String(item["grade"]) in ["B", "A", "S"] \
		and int(item.get("gem_slots", 0)) < mini(GEM_SLOTS[item["grade"]] + 1, MAX_SOCKETS)


static func add_socket(item: Dictionary) -> void:
	item["gem_slots"] = int(item.get("gem_slots", 0)) + 1


# --------------------------------------------------------------- set bonuses ---
# Each class's four S legendaries form a SET. Wearing 2 / 4 pieces of your
# own class's S set grants escalating bonuses (applied in Player.recalc).
# S items carry item["cls"], so only your class's legendaries count.
# ROLE-WEAKNESS doctrine (2026-07-07, refined): a set shores up the class's
# WEAKNESS, not its strength. The plate tanks (warrior/paladin) already
# excel at survival, so their set is pure OFFENSE — their weak axis — to
# keep their dps from falling behind the squishies' damage scaling. The
# squishies (archer/assassin/mage/warlock) get DEFENSE from real mitigation
# — VITALITY (pool + a broad tiny-res sprinkle) plus direct resistances and
# critres — NO evasion (a soft-capping avoid-RNG cop-out). Modest numbers
# ride the STEEP low end of the res curve (res_frac saturates, so a little
# from a near-zero base buys a lot), closing the survival gap for endgame
# bullet hell WITHOUT making them tanks. All four squishy 4pc are broad
# phys + mag res + a little critres (bullet hell throws both damage types);
# the VIT 2pc adds the pool. No specials (gear rule holds).
const SET_BONUSES := {
	"warrior":  {"name": "Emberforged Warplate",    "2": {"atk_pct": 0.06}, "4": {"atk_pct": 0.10, "physpen": 8.0}},
	"paladin":  {"name": "The Highfather's Aegis",  "2": {"atk_pct": 0.06}, "4": {"atk_pct": 0.10, "magpen": 8.0}},
	"archer":   {"name": "The Hawk God's Regalia",  "2": {"VIT": 8.0},      "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
	"assassin": {"name": "The Shadow God's Vestige", "2": {"VIT": 8.0},     "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
	"mage":     {"name": "The Archmage's Array",    "2": {"VIT": 8.0},      "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
	"warlock":  {"name": "The Long Bargain Raiment", "2": {"VIT": 8.0},     "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
}


## How many pieces of `cls`'s S set are equipped (S grade + matching class).
static func count_set_pieces(equipment: Dictionary, cls: String) -> int:
	var n := 0
	for slot in equipment:
		var it: Dictionary = equipment[slot]
		if String(it.get("grade", "")) == "S" and String(it.get("cls", "")) == cls:
			n += 1
	return n


## All stats an item grants (main stat gets +15% per upgrade level,
## embedded gems contribute their stat too).
static func stats_of(item: Dictionary) -> Dictionary:
	var out := {}
	var plus_mult: float = 1.0 + 0.15 * item["plus"]
	for stat in item["main"]:
		out[stat] = item["main"][stat] * plus_mult
	for stat in item["subs"]:
		out[stat] = out.get(stat, 0.0) + item["subs"][stat]
	for gem in item.get("gems", []):
		out[gem["stat"]] = out.get(gem["stat"], 0.0) + gem_value(gem)
	return out


static func price(item: Dictionary) -> int:
	return int(22.0 * GRADE_MULT[item["grade"]] * (1.0 + 0.5 * item["plus"]))


static func upgrade_cost(item: Dictionary) -> int:
	# Round 51: steep per-tier curve (base * grade factor * (1+plus)) — an S
	# step costs 8x a C step. Data curve; knobs in balance.gd.
	var f: float = float(Balance.UPGRADE_GRADE_FACTOR.get(String(item["grade"]), 1.0))
	return int(Balance.UPGRADE_BASE * f * float(1 + int(item["plus"])))


## FARM-COST buy price of a gear item in a `chid` merchant (round 51): the gold
## you'd earn farming one yourself + FARM_TAX. Rare grades (in the act's boss
## table) use the farm-cost formula; commodity grades below them get a cheap
## flat intrinsic price so shop filler stays junk-cheap. S weapons pay ~2x
## (halved drop rate). SELL is separate — always MERCHANT_SELL_FRACTION x the
## small intrinsic price(), never this inflated number.
static func shop_buy_price(item: Dictionary, chid: String) -> int:
	var grade := String(item["grade"])
	var econ: Dictionary = Balance.CHAPTER_ECON.get(chid, {})
	var odds: Dictionary = Balance.boss_gear_odds(chid)
	var plus_mult: float = 1.0 + 0.5 * float(item.get("plus", 0))
	if odds.has(grade) and not econ.is_empty():
		var chance: float = float(odds[grade])
		if grade == "S" and String(item.get("slot", "")) == "weapon":
			chance *= Balance.S_WEAPON_DROP_WEIGHT
		var n: int = Balance.farm_runs(chance)
		var g: float = float(econ["first"]) + float(n - 1) * float(econ["replay"])
		return int(round(g * Balance.FARM_TAX * plus_mult))
	return int(ceil(price(item) * Balance.SHOP_BUY_MARKUP))


## FARM-COST buy price of a shop GEM at `lvl` (round 51). Gems drop many per
## run, so per-unit cost = (one run's gold / gems per run) scaled up the
## combine curve from the act's floor level, + FARM_TAX. A fraction of gear.
static func gem_buy_price(lvl: int, chid: String) -> int:
	var econ: Dictionary = Balance.CHAPTER_ECON.get(chid, {})
	if econ.is_empty():
		return int(ceil(Balance.gem_gold_value(lvl) * Balance.FARM_TAX))
	var act: int = int(econ.get("act", 1))
	var floor_lvl: int = int(Balance.GEM_ACT_LEVEL.get(act, 1))
	var gems_per_run: float = maxf(1.0, float(econ.get("gems", 15.0)))
	var per_gem: float = float(econ["replay"]) / gems_per_run
	var weight: float = pow(Balance.GEM_GOLD_PER_LEVEL, float(maxi(lvl - floor_lvl, 0)))
	return int(round(per_gem * weight * Balance.FARM_TAX))


## "★ <Passive>" — or "★ <Passive> — LOCKED (awakening)" for a dormant
## legendary whose class hasn't awakened (s_awakened_<cls>) yet.
static func passive_label(item: Dictionary, awakened := false) -> String:
	var txt: String = "★ " + PASSIVES[item["passive"]]
	if item.get("passive_dormant", false) and not awakened:
		txt += " — LOCKED (awakening)"
	return txt


## `awakened` (the item's class flag s_awakened_<cls>) governs how a dormant
## legendary's passive reads: pass game.get_flag(...) from player-facing UI.
static func describe(item: Dictionary, awakened := false) -> String:
	var bits: Array = []
	var stats := stats_of(item)
	for stat in stats:
		var v: float = stats[stat]
		if stat in FLAT_STATS:
			bits.append("%s +%d" % [STAT_LABEL.get(stat, stat), int(v)])
		else:
			bits.append("%s +%d%%" % [STAT_LABEL.get(stat, stat), int(round(v * 100))])
	var out := ", ".join(bits)
	if item.has("passive"):
		out += "  " + passive_label(item, awakened)
	var slots: int = item.get("gem_slots", 0)
	if slots > 0:
		var used: int = item.get("gems", []).size()
		out += "  " + "◆".repeat(used) + "◇".repeat(slots - used)
	return out


## Stat-by-stat difference between a candidate item and what's equipped
## in that slot ("▲ ATK +5" / "▼ Crit -2%"). For hover tooltips.
static func diff_text(new_item: Dictionary, old_item, awakened := false) -> String:
	if old_item == null:
		return "Slot is empty — pure upgrade:\n" + describe(new_item, awakened)
	var a := stats_of(new_item)
	var b := stats_of(old_item)
	var keys := {}
	for stat in a:
		keys[stat] = true
	for stat in b:
		keys[stat] = true
	var lines: Array = ["vs %s:" % title(old_item)]
	for stat in keys:
		var d: float = a.get(stat, 0.0) - b.get(stat, 0.0)
		if absf(d) < 0.001:
			continue
		var arrow := "▲" if d > 0.0 else "▼"
		var label: String = STAT_LABEL.get(stat, stat)
		if stat in FLAT_STATS:
			lines.append("%s %s %+d" % [arrow, label, int(round(d))])
		else:
			lines.append("%s %s %+d%%" % [arrow, label, int(round(d * 100))])
	if lines.size() == 1:
		lines.append("(identical stats)")
	if new_item.has("passive"):
		lines.append(passive_label(new_item, awakened))
	return "\n".join(lines)


static func title(item: Dictionary) -> String:
	var plus: String = "" if item["plus"] == 0 else " +%d" % item["plus"]
	return "[%s] %s%s" % [item["grade"], item["name"], plus]
