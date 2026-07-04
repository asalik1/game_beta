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
		"weapon": {"name": "Stormcaller, Bow of the Tempest", "passive": "ricochet", "noun": "Bow"},
		"armor":  {"name": "Cloak of a Thousand Leaves", "subs": {"hp_pct": 0.10, "eva": 0.05}},
		"boots":  {"name": "Zephyr's Grace",             "subs": {"speed_pct": 0.09, "crit": 0.06}},
		"charm":  {"name": "The Hawk God's Eye",         "subs": {"crit": 0.10, "crit_dmg": 0.30}},
	},
	"mage": {
		"weapon": {"name": "Heart of the Phoenix", "passive": "phoenix", "noun": "Staff"},
		"armor":  {"name": "Robes of the Infinite", "subs": {"hp_pct": 0.10, "magres": 18.0}},
		"boots":  {"name": "Steps of the Void",     "subs": {"speed_pct": 0.07, "cdr": 0.05}},
		"charm":  {"name": "The Archmage's Folly",  "subs": {"cdr": 0.10, "magpen": 10.0}},
	},
	"assassin": {
		"weapon": {"name": "Nightfang, Kiss of the Abyss", "passive": "nightfang", "noun": "Fang"},
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
		"weapon": {"name": "Grimoire of the Hollow Choir", "passive": "hollowchoir", "noun": "Tome"},
		"armor":  {"name": "Vestments of the Long Bargain", "subs": {"hp_pct": 0.10, "magres": 16.0}},
		"boots":  {"name": "Voidwalkers",                   "subs": {"speed_pct": 0.08, "magpen": 6.0}},
		"charm":  {"name": "The First Debt",                "subs": {"atk_pct": 0.08, "lifesteal": 0.04}},
	},
}

const PASSIVES := {
	"kingsblade":  "Cleave hurls a sword wave",
	"ricochet":    "Arrows ricochet to a second enemy",
	"phoenix":     "Firebolt always explodes and ignites",
	"nightfang":   "Strikes on stunned or slowed enemies always crit",
	"dawnbreaker": "Judgment calls down a pillar of light (splash + holy burn)",
	"hollowchoir": "Shadowbolt splits into a second bolt at a second enemy",
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
	var noun: String = force_noun if force_noun != "" else noun_list[rng.randi_range(0, noun_list.size() - 1)]
	if grade == "S" and cls != "" and S_GEAR.has(cls) and S_GEAR[cls][slot].has("noun"):
		noun = S_GEAR[cls][slot]["noun"]  # legendaries use their class shape
	var style: Dictionary = SHAPE_STYLE.get(noun, {"main": 1.0, "subs": {}})

	var main := {}
	for stat in SLOT_MAIN[slot]:
		main[stat] = snappedf(SLOT_MAIN[slot][stat] * mult * style["main"] * rng.randf_range(0.9, 1.15), 0.01)
	# Higher grades roll more substats (F/E: 0, D/C: 1, B/A: 2, S: 3).
	var sub_count := maxi(0, (GRADES.find(grade) - 1) / 2)
	var subs := {}
	var pool := SUBSTATS.keys()
	pool.shuffle()
	for i in mini(sub_count, pool.size()):
		var stat: String = pool[i]
		subs[stat] = snappedf(SUBSTATS[stat] * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	# The shape's guaranteed personality stats, scaled by grade.
	for stat in style["subs"]:
		subs[stat] = snappedf(subs.get(stat, 0.0) + style["subs"][stat] * (0.75 + 0.25 * mult), 0.01)

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
