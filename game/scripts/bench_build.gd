class_name BenchBuild
extends RefCounted
## SINGLE SOURCE OF TRUTH for the DPS-bench character builds, shared by the balance
## bench (tests/dps_bench.gd) and the dev-panel "Generate benchmark roster" tool so
## the two can never drift. A build = a level (primary attr = level-1), a mono theme,
## the DPS-optimal talent tree, and gear rolled off a FIXED seed at a grade with every
## socket filled, a plus level, optionally reforge-chased to its godroll ceiling.

const GEAR_SEED := 48815   # same gear roll sequence for every case (was in dps_bench)

## The presets the dev roster exposes. avg40 / perfect100 are exactly the two configs
## the bench has been run at all along; avg100 is the realistic-endgame middle ground.
const PRESETS := {
	"avg40":      {"name": "Average L40",  "level": 40,  "grade": "A", "gemlvl": 6,  "plus": 0,  "godroll": false},
	"avg100":     {"name": "Average L100", "level": 100, "grade": "S", "gemlvl": 8,  "plus": 10, "godroll": false},
	"perfect100": {"name": "Perfect L100", "level": 100, "grade": "S", "gemlvl": 10, "plus": 20, "godroll": true},
}
const PRESET_ORDER := ["avg40", "avg100", "perfect100"]

## Best-DPS theme per class — the one variant the roster generates (one char/class).
const DEFAULT_THEME := {
	"warrior": "fury", "archer": "hunt", "mage": "wind",
	"assassin": "shadow", "paladin": "wrath", "warlock": "curse",
}

## DPS-OPTIMAL talent presets per class/variant (best damage cell per row, 10/10/10/9;
## the 9 dumped in the weakest/defensive row). "*" = every variant of the class.
const TREE_PRESETS := {
	"warrior": {"*": {"w00": 10, "w10": 9, "w20": 10, "w30": 10}},
	"archer": {
		"storm": {"a00": 10, "a10": 9, "a20": 10, "a30": 10},
		"venom": {"a01": 10, "a10": 9, "a22": 10, "a30": 10},
		"hunt":  {"a00": 10, "a10": 9, "a20": 10, "a32": 10},
	},
	"mage": {
		"ice": {"m01": 10, "m12": 9, "m21": 10, "m30": 10},
		"*":   {"m00": 10, "m12": 9, "m20": 10, "m30": 10},   # fire / wind
	},
	"assassin": {
		"shadow": {"s00": 10, "s10": 9, "s20": 10, "s31": 10},
		"*":      {"s00": 10, "s10": 9, "s20": 10, "s30": 10},  # poison / blood
	},
	"paladin": {
		"wrath": {"p00": 10, "p12": 9, "p22": 10, "p32": 10},
		"*":     {"p00": 10, "p12": 9, "p22": 10, "p30": 10},   # holy / aegis
	},
	"warlock": {
		"void": {"k00": 10, "k12": 9, "k22": 10, "k32": 10},
		"*":    {"k00": 10, "k11": 9, "k20": 10, "k30": 10},    # curse / pact
	},
}

## Gem loadout — DPS-optimal under the typed-slot rule: each special slot holds a
## DISTINCT damage special (dmg_pct/cdr/combo + lifesteal), every regular slot a Ruby.
const GEM_PRESETS := {
	"warrior":  {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
	"paladin":  {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
	"assassin": {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
	"archer":   {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
	"mage":     {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
	"warlock":  {"*": {"specials": ["dmg_pct", "cdr", "combo", "lifesteal"]}},
}


## A variant's entry from a preset table, with the "*" (all-variants) fallback.
static func preset_lookup(table: Dictionary, cls: String, tid: String) -> Dictionary:
	var per: Dictionary = table[cls]
	return per.get(tid, per.get("*", {}))


## Rebuild one rolled piece into its reforge-chased ceiling — max main roll (1.15)
## and the grade's affix count filled with MAX-magnitude offense (ATK% > Crit > pen >
## DEX), mirroring roll_subs' formulas; style personality subs land on top.
static func godroll_item(item: Dictionary, cls: String) -> void:
	var g := String(item["grade"])
	var mult: float = Items.GRADE_MULT[g]
	var style: Dictionary = Items.SHAPE_STYLE.get(String(item.get("noun", "")), {"main": 1.0, "subs": {}})
	var primary := String(Items.CLASS_PRIMARY.get(cls, "STR"))
	item["main"] = {primary: snappedf(
		float(Items.SLOT_MAIN_BUDGET[item["slot"]]) * mult * float(style["main"]) * 1.15, 0.01)}
	var pen := "magpen" if String(Items.CLASSES_DMG_TYPE.get(cls, "physical")) == "magic" else "physpen"
	var sub_count: int = Items.sub_count_for(g)
	var scale: float = 1.3 * (1.0 + mult * 0.25)
	var subs := {}
	var picked := 0
	for stat in ["atk_pct", "crit", pen, "dex"]:
		if picked >= sub_count:
			break
		subs[stat] = snappedf(float(Items.SUBSTATS[stat]) * scale, 0.01)
		picked += 1
	for stat in style["subs"]:
		subs[stat] = snappedf(subs.get(stat, 0.0) + float(style["subs"][stat]) * (0.75 + 0.25 * mult), 0.01)
	item["subs"] = subs


## The 4-slot equipment dict for a build: gear rolled off `rng` (seed it with
## GEAR_SEED for the canonical sequence), stamped with plus, optionally godroll'd,
## every socket filled from the class's gem preset at the config's gem level.
static func equip_dict(cls: String, tid: String, cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var grade := String(cfg["grade"])
	var gemlvl := int(cfg["gemlvl"])
	var plus_lvl := int(cfg["plus"])
	var godroll := bool(cfg["godroll"])
	var specials: Array = preset_lookup(GEM_PRESETS, cls, tid).get("specials", [])
	var spec_cap: int = Items.special_slots(grade)
	var spec_idx := 0
	var equipment := {}
	for slot in Items.SLOTS:
		var noun: String = Items.class_weapon_noun(cls) if slot == "weapon" else ""
		var item := Items.roll_item_of(slot, grade, rng, cls, noun)
		item["plus"] = plus_lvl
		if godroll:
			godroll_item(item, cls)
		var glist: Array = []
		var s_placed := 0
		for _s in int(item.get("gem_slots", 0)):
			if s_placed < spec_cap and spec_idx < specials.size():
				glist.append(Items.make_gem(String(specials[spec_idx]), gemlvl))
				spec_idx += 1
				s_placed += 1
			else:
				glist.append(Items.make_gem("atk_flat", gemlvl))  # Ruby regular
		item["gems"] = glist
		equipment[slot] = item
	return equipment


## The full save-file dict for a benchmark character of `cls` at `preset_key` — the
## exact bench build baked into the v3 save shape (see save.gd), ch1 start position.
static func save_dict(cls: String, preset_key: String) -> Dictionary:
	var cfg: Dictionary = PRESETS[preset_key]
	var lvl: int = int(cfg["level"])
	var tid: String = String(DEFAULT_THEME[cls])
	var rng := RandomNumberGenerator.new()
	rng.seed = GEAR_SEED
	var equipment := equip_dict(cls, tid, cfg, rng)
	var attr := {}
	attr[String(Classes.CLASSES[cls]["primary"])] = lvl - 1
	var themes := {}
	for slot in ["a1", "a2", "a3", "ult"]:
		themes[slot] = tid
	var flags := {}
	if String(cfg["grade"]) == "S":
		flags["s_awakened_" + cls] = true   # a BiS run wants the legendary passive LIVE
	return {
		"version": SaveGame.VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"chapter": "ch1",
		"character": {
			"cls": cls, "level": lvl, "xp": 0,
			"skill_points": 0,
			"tree_points": preset_lookup(TREE_PRESETS, cls, tid).duplicate(),
			"attr_points": attr, "unspent_attr": 0,
			"ability_theme": themes,
			"equipment": equipment,
			"gold": 2000, "potions": 3,
		},
		"world": {
			"quest_key": "talk",
			"flags": flags,
			"wander_seed": rng.randi(),
		},
	}
