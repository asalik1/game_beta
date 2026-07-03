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
	"weapon": ["Blade", "Edge", "Fang"],
	"armor":  ["Plate", "Mail", "Guard"],
	"boots":  ["Boots", "Striders", "Treads"],
	"charm":  ["Charm", "Talisman", "Sigil"],
}

const GRADE_PREFIX := {
	"F": "Rusty", "E": "Worn", "D": "Soldier's", "C": "Knight's",
	"B": "Runed", "A": "Dragonforged", "S": "Emberforged",
}

# Substat pool: stat -> base roll (scaled a little by grade).
const SUBSTATS := {
	"atk_pct": 0.05, "hp_pct": 0.06, "crit": 0.03, "cdr": 0.03,
	"speed_pct": 0.03, "lifesteal": 0.02, "dr": 0.03, "gold_pct": 0.10,
}

const STAT_LABEL := {
	"atk_flat": "ATK", "hp_flat": "HP", "atk_pct": "ATK%", "hp_pct": "HP%",
	"crit": "Crit", "crit_dmg": "CritDmg", "cdr": "Haste", "speed_pct": "Speed",
	"lifesteal": "Lifesteal", "dr": "Armor", "gold_pct": "Greed", "mp_flat": "MP",
}

# Chest tiers -> grade weights.
const CHEST_TIERS := {
	"wood":   {"sprite": "chest_wood",   "weights": {"F": 40, "E": 30, "D": 20, "C": 10}},
	"silver": {"sprite": "chest_silver", "weights": {"D": 30, "C": 35, "B": 25, "A": 10}},
	"gold":   {"sprite": "chest_gold",   "weights": {"B": 35, "A": 40, "S": 25}},
}


static func roll_grade(tier: String, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = CHEST_TIERS[tier]["weights"]
	var total := 0
	for w in weights.values():
		total += w
	var pick := rng.randi_range(1, total)
	for grade in weights:
		pick -= weights[grade]
		if pick <= 0:
			return grade
	return "F"


static func roll_item(tier: String, rng: RandomNumberGenerator) -> Dictionary:
	var grade := roll_grade(tier, rng)
	var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	return roll_item_of(slot, grade, rng)


static func roll_item_of(slot: String, grade: String, rng: RandomNumberGenerator) -> Dictionary:
	var mult: float = GRADE_MULT[grade]
	var main := {}
	for stat in SLOT_MAIN[slot]:
		main[stat] = snappedf(SLOT_MAIN[slot][stat] * mult * rng.randf_range(0.9, 1.15), 0.01)
	# Higher grades roll more substats (F/E: 0, D/C: 1, B/A: 2, S: 3).
	var sub_count := maxi(0, (GRADES.find(grade) - 1) / 2)
	var subs := {}
	var pool := SUBSTATS.keys()
	pool.shuffle()
	for i in mini(sub_count, pool.size()):
		var stat: String = pool[i]
		subs[stat] = snappedf(SUBSTATS[stat] * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	var noun_list: Array = SLOT_NAMES[slot]
	return {
		"slot": slot, "grade": grade,
		"name": "%s %s" % [GRADE_PREFIX[grade], noun_list[rng.randi_range(0, noun_list.size() - 1)]],
		"main": main, "subs": subs, "plus": 0,
	}


## All stats an item grants (main stat gets +15% per upgrade level).
static func stats_of(item: Dictionary) -> Dictionary:
	var out := {}
	var plus_mult: float = 1.0 + 0.15 * item["plus"]
	for stat in item["main"]:
		out[stat] = item["main"][stat] * plus_mult
	for stat in item["subs"]:
		out[stat] = out.get(stat, 0.0) + item["subs"][stat]
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
		if stat in ["atk_flat", "hp_flat", "mp_flat"]:
			bits.append("%s +%d" % [STAT_LABEL[stat], int(v)])
		else:
			bits.append("%s +%d%%" % [STAT_LABEL[stat], int(round(v * 100))])
	return ", ".join(bits)


static func title(item: Dictionary) -> String:
	var plus: String = "" if item["plus"] == 0 else " +%d" % item["plus"]
	return "[%s] %s%s" % [item["grade"], item["name"], plus]
