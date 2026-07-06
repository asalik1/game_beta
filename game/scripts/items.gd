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

const SLOTS := ["weapon", "armor", "boots", "charm"]
const SLOT_ICON := {"weapon": "⚔", "armor": "🛡", "boots": "👢", "charm": "❖"}

# Main stat per slot (base value, scaled by grade multiplier).
const SLOT_MAIN := {
	"weapon": {"atk_flat": 6.0},
	"armor":  {"hp_flat": 40.0},
	"boots":  {"speed_pct": 0.06},
	"charm":  {"cdr": 0.06},
}

# Weapon shapes a class can actually be DEALT (round 15: an archer was
# looting Tomes). Any class may still equip anything from the bag —
# drops just stop wasting rolls on the wrong arsenal.
const CLASS_WEAPONS := {
	"warrior": ["Blade", "Edge", "Claymore"],
	"archer": ["Bow", "Crossbow"],
	"assassin": ["Fang", "Kunai"],
	"mage": ["Staff", "Wand"],
	"paladin": ["Hammer", "Blade"],
	"warlock": ["Tome", "Wand"],
}

const SLOT_NAMES := {
	"weapon": ["Blade", "Edge", "Fang", "Kunai", "Claymore", "Bow", "Crossbow", "Staff", "Wand", "Hammer", "Tome"],
	"armor":  ["Plate", "Mail", "Guard"],
	"boots":  ["Boots", "Striders", "Treads"],
	"charm":  ["Charm", "Talisman", "Sigil"],
}

# One representative prefix per grade (used in the codex).
const GRADE_PREFIX := {
	"F": "Rusty", "E": "Worn", "D": "Soldier's", "C": "Knight's",
	"B": "Runed", "A": "Dragonforged", "S": "Emberforged",
}

# Rolled items pick a random prefix from their grade's pool,
# so drops read like "Trainee's Kunai" or "Masterwork Claymore".
const PREFIXES := {
	"F": ["Rusty", "Cracked", "Trainee's", "Bent"],
	"E": ["Worn", "Plain", "Sturdy", "Militia"],
	"D": ["Soldier's", "Tempered", "Honed", "Veteran's"],
	"C": ["Knight's", "Fine", "Gilded", "Journeyman's"],
	"B": ["Runed", "Masterwork", "Enchanted", "Warlord's"],
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
		"boots":  {"name": "Earthshaker Sabatons",    "subs": {"speed_pct": 0.06, "hp_pct": 0.08}},
		"charm":  {"name": "Warlord's Iron Oath",     "subs": {"atk_pct": 0.10, "physpen": 10.0}},
	},
	"archer": {
		"weapon": {"name": "Stormcaller, Bow of the Tempest", "passive": "windward", "noun": "Bow"},
		"armor":  {"name": "Cloak of a Thousand Leaves", "subs": {"hp_pct": 0.10, "eva": 0.05}},
		"boots":  {"name": "Zephyr's Grace",             "subs": {"speed_pct": 0.09, "crit": 0.06}},
		"charm":  {"name": "The Hawk God's Eye",         "subs": {"crit": 0.10, "crit_dmg": 0.30}},
	},
	"mage": {
		"weapon": {"name": "Heart of the Phoenix", "passive": "wellspring", "noun": "Staff"},
		"armor":  {"name": "Robes of the Infinite", "subs": {"hp_pct": 0.10, "magres": 18.0}},
		"boots":  {"name": "Steps of the Void",     "subs": {"speed_pct": 0.07, "cdr": 0.05}},
		"charm":  {"name": "The Archmage's Folly",  "subs": {"cdr": 0.10, "magpen": 10.0}},
	},
	"assassin": {
		"weapon": {"name": "Nightfang, Kiss of the Abyss", "passive": "mirrorstep", "noun": "Fang"},
		"armor":  {"name": "Shroud of Silence", "subs": {"hp_pct": 0.08, "lifesteal": 0.05}},
		"boots":  {"name": "Whisperwind",       "subs": {"speed_pct": 0.10, "crit": 0.05}},
		"charm":  {"name": "The Bloodpact",     "subs": {"crit": 0.08, "combo": 0.04}},
	},
	"paladin": {
		"weapon": {"name": "Dawnbreaker, Hammer of the Highfather", "passive": "dawnbreaker", "noun": "Hammer"},
		"armor":  {"name": "Bulwark of the Dawn",  "subs": {"hp_pct": 0.12, "physres": 14.0, "magres": 14.0}},
		"boots":  {"name": "Greaves of the Vigil", "subs": {"speed_pct": 0.06, "hp_pct": 0.08}},
		"charm":  {"name": "The Highfather's Oath", "subs": {"atk_pct": 0.08, "cdr": 0.06, "lifesteal": 0.02}},
	},
	"warlock": {
		"weapon": {"name": "Grimoire of the Hollow Choir", "passive": "voidmaw", "noun": "Tome"},
		"armor":  {"name": "Vestments of the Long Bargain", "subs": {"hp_pct": 0.10, "magres": 16.0}},
		"boots":  {"name": "Voidwalkers",                   "subs": {"speed_pct": 0.08, "magpen": 6.0}},
		"charm":  {"name": "The First Debt",                "subs": {"atk_pct": 0.08, "lifesteal": 0.04}},
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
const GEM_MAX_LEVEL := 10

# stat -> [display name, base value per level-ish, color]
const GEM_STATS := {
	"atk_pct":  {"name": "Ruby",      "base": 0.02,  "color": Color(1.0, 0.3, 0.3)},
	"hp_pct":   {"name": "Garnet",    "base": 0.025, "color": Color(0.9, 0.45, 0.45)},
	"crit":     {"name": "Topaz",     "base": 0.012, "color": Color(1.0, 0.8, 0.3)},
	"crit_dmg": {"name": "Sunstone",  "base": 0.04,  "color": Color(1.0, 0.6, 0.2)},
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


static func random_gem(rng: RandomNumberGenerator, lvl := 1) -> Dictionary:
	var keys := GEM_STATS.keys()
	return make_gem(keys[rng.randi_range(0, keys.size() - 1)], lvl)


# ------------------------------------------------------------------ bags ---
# The bag is carried capacity for everything NOT equipped: gear, GEM
# STACKS (one slot per stat+level, round 7) and consumables share its
# slots. One bag at a time — looting a bigger one upgrades in place,
# smaller/equal ones convert to gold. Elites are the bag source
# (playtest round 6; DESIGN.md).
const BAG_SLOTS := {"F": 15, "E": 20, "D": 25, "C": 35, "B": 50, "A": 70, "S": 100}
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


# ----------------------------------------------------------- consumables ---
# Non-gear bag items ({"kind": "stone", ...}). The talent reset stone is
# the first; elites are the primary source (playtest round 6).
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
# guaranteed bonus stats. A Claymore hits like a truck, a Kunai crits.
const SHAPE_STYLE := {
	"Blade":    {"main": 1.0,  "subs": {"atk_pct": 0.05}, "tag": "balanced"},
	"Edge":     {"main": 1.2,  "subs": {}, "tag": "heavy hits"},
	"Fang":     {"main": 0.85, "subs": {"crit": 0.05}, "tag": "crit"},
	"Kunai":    {"main": 0.8,  "subs": {"crit": 0.04, "speed_pct": 0.03}, "tag": "crit + speed"},
	"Claymore": {"main": 1.4,  "subs": {}, "tag": "massive damage"},
	"Bow":      {"main": 0.9,  "subs": {"cdr": 0.04}, "tag": "attack speed"},
	"Crossbow": {"main": 1.05, "subs": {"physpen": 5.0}, "tag": "penetration"},
	"Staff":    {"main": 0.95, "subs": {"mp_flat": 15.0, "atk_pct": 0.04}, "tag": "mana + power"},
	"Wand":     {"main": 0.85, "subs": {"combo": 0.02, "magpen": 3.0}, "tag": "combo + magic pen"},
	"Hammer":   {"main": 1.25, "subs": {"hp_flat": 20.0}, "tag": "crushing + sturdy"},
	"Tome":     {"main": 0.9,  "subs": {"magpen": 4.0, "lifesteal": 0.01}, "tag": "dark power"},
	"Plate":    {"main": 1.15, "subs": {}, "tag": "bulk"},
	"Mail":     {"main": 0.9,  "subs": {"speed_pct": 0.03}, "tag": "mobility"},
	"Guard":    {"main": 0.95, "subs": {"physres": 10.0}, "tag": "physical resistance"},
	"Boots":    {"main": 1.0,  "subs": {}, "tag": "balanced"},
	"Striders": {"main": 0.9,  "subs": {"cdr": 0.03}, "tag": "haste"},
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
	"paladin": "phys", "mage": "magic", "warlock": "magic",
}

const SUBSTATS := {
	"atk_pct": 0.05, "hp_pct": 0.06, "crit": 0.03, "cdr": 0.03,
	"speed_pct": 0.03, "lifesteal": 0.02, "greed": 0.08, "crit_dmg": 0.08,
	"physres": 9.0, "magres": 9.0, "critres": 6.0, "eva": 0.02, "dex": 4.0,
	"physpen": 5.0, "magpen": 5.0, "combo": 0.02, "mp_flat": 12.0,
}

const STAT_LABEL := {
	"atk_flat": "ATK", "hp_flat": "HP", "atk_pct": "ATK%", "hp_pct": "HP%",
	"crit": "Crit", "crit_dmg": "CritDmg", "cdr": "Haste", "speed_pct": "Speed",
	"lifesteal": "Lifesteal", "greed": "Greed", "mp_flat": "MP",
	"physres": "PhysRes", "magres": "MagRes", "critres": "CritRes",
	"eva": "EVA", "dex": "DEX", "physpen": "PhysPen", "magpen": "MagPen",
	"combo": "Combo",
}

# Stats measured in flat points rather than percent (for display).
const FLAT_STATS := ["atk_flat", "hp_flat", "mp_flat", "physres", "magres", "critres", "dex", "physpen", "magpen"]

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
	var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	return roll_item_of(slot, grade, rng, cls)


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

	var main := {}
	for stat in SLOT_MAIN[slot]:
		main[stat] = snappedf(SLOT_MAIN[slot][stat] * mult * style["main"] * rng.randf_range(0.9, 1.15), 0.01)
	var subs := roll_subs(grade, noun, cls, rng)

	var item := {
		"slot": slot, "grade": grade, "noun": noun,
		"main": main, "subs": subs, "plus": 0,
		"gem_slots": GEM_SLOTS[grade], "gems": [],
	}
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
	if cls != "" and CLASSES_DMG_TYPE.has(cls):
		pool.erase("physpen" if CLASSES_DMG_TYPE[cls] == "magic" else "magpen")
	# Endgame-only stats (round 43): lifesteal and combo never roll below B.
	var below_b := GRADES.find(grade) < GRADES.find("B")
	if below_b:
		pool.erase("lifesteal")
		pool.erase("combo")
	pool.shuffle()
	for i in mini(sub_count, pool.size()):
		var stat: String = pool[i]
		subs[stat] = snappedf(SUBSTATS[stat] * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	for stat in style["subs"]:
		if below_b and (stat == "lifesteal" or stat == "combo"):
			continue
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
const SET_BONUSES := {
	"warrior":  {"name": "Emberforged Warplate", "2": {"hp_pct": 0.10}, "4": {"atk_pct": 0.12, "physres": 20.0}},
	"archer":   {"name": "The Hawk God's Regalia", "2": {"crit": 0.06}, "4": {"crit_dmg": 0.25, "speed_pct": 0.06}},
	"mage":     {"name": "The Archmage's Array", "2": {"cdr": 0.08}, "4": {"atk_pct": 0.12, "magpen": 10.0}},
	"assassin": {"name": "The Shadow God's Vestige", "2": {"crit": 0.06}, "4": {"crit_dmg": 0.20, "lifesteal": 0.05}},
	"paladin":  {"name": "The Highfather's Aegis", "2": {"hp_pct": 0.10}, "4": {"physres": 18.0, "lifesteal": 0.04}},
	"warlock":  {"name": "The Long Bargain Raiment", "2": {"cdr": 0.06}, "4": {"magpen": 10.0, "lifesteal": 0.06}},
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
	return int(15.0 * GRADE_MULT[item["grade"]] * (1 + item["plus"]))


static func describe(item: Dictionary) -> String:
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
		out += "  ★ " + PASSIVES[item["passive"]]
	var slots: int = item.get("gem_slots", 0)
	if slots > 0:
		var used: int = item.get("gems", []).size()
		out += "  " + "◆".repeat(used) + "◇".repeat(slots - used)
	return out


## Stat-by-stat difference between a candidate item and what's equipped
## in that slot ("▲ ATK +5" / "▼ Crit -2%"). For hover tooltips.
static func diff_text(new_item: Dictionary, old_item) -> String:
	if old_item == null:
		return "Slot is empty — pure upgrade:\n" + describe(new_item)
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
		lines.append("★ " + PASSIVES[new_item["passive"]])
	return "\n".join(lines)


static func title(item: Dictionary) -> String:
	var plus: String = "" if item["plus"] == 0 else " +%d" % item["plus"]
	return "[%s] %s%s" % [item["grade"], item["name"], plus]
