class_name Skills
## Row-based skill tree (like classic MMO talent pages):
##  - a new ROW unlocks every few levels (ROW_LEVELS)
##  - you may spend up to 5 points TOTAL per row, spread freely
##    across its 3 columns, max 5 in any single cell
##  - each point buffs that cell's effect by one increment
##  - the 3 columns line up with the class's 3 themes / playstyles
##
## Cell fields (all per-point):
##   bonus {stat: value}          character stats
##   amod  {slot: {dmg/cd: v}}    ability modifiers

const ROW_LEVELS := [1, 4, 8, 12]
const MAX_PER_CELL := 5
const MAX_PER_ROW := 5

const TREES := {
	"warrior": [  # columns: Fury / Bulwark / Earth
		[
			{"id": "w00", "name": "Heavy Cleave",  "desc": "Cleave +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "w01", "name": "Thick Hide",    "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "w02", "name": "Wide Storm",    "desc": "Whirlwind +5% damage", "amod": {"a3": {"dmg": 0.05}}},
		],
		[
			{"id": "w10", "name": "Killer Instinct", "desc": "+1.5% crit chance", "bonus": {"crit": 0.015}},
			{"id": "w11", "name": "Iron Wall",       "desc": "+10 physical resistance", "bonus": {"physres": 10.0}},
			{"id": "w12", "name": "Heavy Bash",      "desc": "Shield Bash +8% damage", "amod": {"a2": {"dmg": 0.08}}},
		],
		[
			{"id": "w20", "name": "Battle Rhythm", "desc": "+1% combo chance", "bonus": {"combo": 0.01}},
			{"id": "w21", "name": "Spell Ward",    "desc": "+10 magic resistance", "bonus": {"magres": 10.0}},
			{"id": "w22", "name": "Momentum",      "desc": "Whirlwind cooldown -4%", "amod": {"a3": {"cd": -0.04}}},
		],
		[
			{"id": "w30", "name": "Warlord",   "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "w31", "name": "Colossus",  "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "w32", "name": "Sunderer",  "desc": "+4 physical penetration", "bonus": {"physpen": 4.0}},
		],
	],
	"archer": [  # columns: Storm / Venom / Hunt
		[
			{"id": "a00", "name": "Swift Shot",       "desc": "Quick Shot +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "a01", "name": "Serpent's Due",    "desc": "+8% damage to poisoned enemies", "bonus": {"poison_dmg": 0.08}},
			{"id": "a02", "name": "Steady Aim",       "desc": "+1.5% crit chance", "bonus": {"crit": 0.015}},
		],
		[
			{"id": "a10", "name": "Chain Reflex",     "desc": "+2% combo chance", "bonus": {"combo": 0.02}},
			{"id": "a11", "name": "Second Breath",    "desc": "Second Wind regen +1% max HP/s", "bonus": {"sw_regen": 0.01}},
			{"id": "a12", "name": "Falcon's Patience", "desc": "Arrow Storm cooldown -10%", "amod": {"ult": {"cd": -0.10}}},
		],
		[
			{"id": "a20", "name": "Rapid Quiver",     "desc": "Multishot cooldown -5% and +4% damage", "amod": {"a2": {"cd": -0.05, "dmg": 0.04}}},
			{"id": "a21", "name": "Evasive",          "desc": "+1.5% evasion", "bonus": {"eva": 0.015}},
			{"id": "a22", "name": "Piercer",          "desc": "+4 physical penetration", "bonus": {"physpen": 4.0}},
		],
		[
			{"id": "a30", "name": "Stormcaller", "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "a31", "name": "Windrunner",  "desc": "Tumble cooldown -3%", "amod": {"a3": {"cd": -0.03}}},
			{"id": "a32", "name": "Executioner", "desc": "+6% crit damage", "bonus": {"crit_dmg": 0.06}},
		],
	],
	"mage": [  # columns: Fire / Ice / Wind
		[
			{"id": "m00", "name": "Kindled Bolt",  "desc": "Firebolt +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "m01", "name": "Killing Frost", "desc": "+8% damage to slowed or frozen enemies", "bonus": {"chill_dmg": 0.08}},
			{"id": "m02", "name": "Seeker Winds",  "desc": "Firebolt homes toward its target; +3% Firebolt damage", "bonus": {"bolt_homing": 1.0}, "amod": {"a1": {"dmg": 0.03}}},
		],
		[
			{"id": "m10", "name": "Rimeheart",    "desc": "Frost Nova also heals 1.5% max HP/s for 6s (recast renews, never stacks)", "bonus": {"nova_regen": 0.015}},
			{"id": "m11", "name": "Frost Armor",  "desc": "+5 phys & magic res, +2 crit res", "bonus": {"physres": 5.0, "magres": 5.0, "critres": 2.0}},
			{"id": "m12", "name": "Slipstream",   "desc": "Blink cooldown -5%", "amod": {"a3": {"cd": -0.05}}},
		],
		[
			{"id": "m20", "name": "Arcane Echo",  "desc": "+2% combo chance", "bonus": {"combo": 0.02}},
			{"id": "m21", "name": "Piercing Cold", "desc": "+4 magic penetration", "bonus": {"magpen": 4.0}},
			{"id": "m22", "name": "Warding Veil", "desc": "+5% Blink damage reduction (the 0.8s ward)", "bonus": {"blink_dr": 0.05}},
		],
		[
			{"id": "m30", "name": "Archmage",   "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "m31", "name": "Permafrost", "desc": "Frost Nova & Blink cooldown -2%", "amod": {"a2": {"cd": -0.02}, "a3": {"cd": -0.02}}},
			{"id": "m32", "name": "Windborne",  "desc": "+6% crit damage", "bonus": {"crit_dmg": 0.06}},
		],
	],
	"assassin": [  # columns: Poison / Shadow / Blood
		[
			{"id": "s00", "name": "Coated Blades", "desc": "Stab +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "s01", "name": "Night Edge",    "desc": "+1.5% crit chance", "bonus": {"crit": 0.015}},
			{"id": "s02", "name": "Quick Hands",   "desc": "+1% combo chance", "bonus": {"combo": 0.01}},
		],
		[
			{"id": "s10", "name": "Lingering Toxin", "desc": "Fan of Knives +6% damage", "amod": {"a3": {"dmg": 0.06}}},
			{"id": "s11", "name": "Ghost Step",      "desc": "+1.5% evasion", "bonus": {"eva": 0.015}},
			{"id": "s12", "name": "Opportunist",     "desc": "Shadow Dash +8% damage", "amod": {"a2": {"dmg": 0.08}}},
		],
		[
			{"id": "s20", "name": "Wasting Venom", "desc": "+4 physical penetration", "bonus": {"physpen": 4.0}},
			{"id": "s21", "name": "Blur",          "desc": "+1% move speed", "bonus": {"speed_pct": 0.01}},
			{"id": "s22", "name": "Bloodletter",   "desc": "+1% lifesteal", "bonus": {"lifesteal": 0.01}},
		],
		[
			{"id": "s30", "name": "Plaguebearer", "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "s31", "name": "Phantom",      "desc": "+6% crit damage", "bonus": {"crit_dmg": 0.06}},
			{"id": "s32", "name": "Exsanguinate", "desc": "Shadow Dash cooldown -5%", "amod": {"a2": {"cd": -0.05}}},
		],
	],
	"paladin": [  # columns: Holy / Aegis / Wrath
		[
			{"id": "p00", "name": "Righteous Blows", "desc": "Judgment +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "p01", "name": "Devotion",        "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "p02", "name": "Zeal",            "desc": "+1.5% crit chance", "bonus": {"crit": 0.015}},
		],
		[
			{"id": "p10", "name": "Hallowed Ground", "desc": "Consecration +6% damage", "amod": {"a2": {"dmg": 0.06}}},
			{"id": "p11", "name": "Shieldwall",      "desc": "+10 physical resistance", "bonus": {"physres": 10.0}},
			{"id": "p12", "name": "Fervor",          "desc": "+1% combo chance", "bonus": {"combo": 0.01}},
		],
		[
			{"id": "p20", "name": "Lightmender", "desc": "+1% lifesteal", "bonus": {"lifesteal": 0.01}},
			{"id": "p21", "name": "Sanctuary",   "desc": "Aegis cooldown -5%", "amod": {"a3": {"cd": -0.05}}},
			{"id": "p22", "name": "Crusader",    "desc": "+4 physical penetration", "bonus": {"physpen": 4.0}},
		],
		[
			{"id": "p30", "name": "Beacon of Dawn", "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "p31", "name": "Unbreakable",    "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "p32", "name": "Executioner of the Faith", "desc": "+6% crit damage", "bonus": {"crit_dmg": 0.06}},
		],
	],
	"warlock": [  # columns: Curse / Pact / Void
		[
			{"id": "k00", "name": "Wither",         "desc": "Shadowbolt +5% damage", "amod": {"a1": {"dmg": 0.05}}},
			{"id": "k01", "name": "Blood Tithe",    "desc": "+1% lifesteal", "bonus": {"lifesteal": 0.01}},
			{"id": "k02", "name": "Deep Reservoir", "desc": "+8 max mana", "bonus": {"mp_flat": 8.0}},
		],
		[
			{"id": "k10", "name": "Creeping Doom",  "desc": "Hex +6% damage", "amod": {"a2": {"dmg": 0.06}}},
			{"id": "k11", "name": "Crimson Vigor",  "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "k12", "name": "Warp Step",      "desc": "+1% move speed", "bonus": {"speed_pct": 0.01}},
		],
		[
			{"id": "k20", "name": "Unraveling", "desc": "+4 magic penetration", "bonus": {"magpen": 4.0}},
			{"id": "k21", "name": "Bargainer",  "desc": "Dark Pact +8% damage", "amod": {"a3": {"dmg": 0.08}}},
			{"id": "k22", "name": "Slipspace",  "desc": "+1.5% evasion", "bonus": {"eva": 0.015}},
		],
		[
			{"id": "k30", "name": "Archfiend's Favor", "desc": "+2% total damage", "bonus": {"atk_pct": 0.02}},
			{"id": "k31", "name": "Soulfeast",         "desc": "+3% max HP", "bonus": {"hp_pct": 0.03}},
			{"id": "k32", "name": "Annihilation",      "desc": "+6% crit damage", "bonus": {"crit_dmg": 0.06}},
		],
	],
}


static func find_cell(cls: String, id: String) -> Dictionary:
	for row in TREES[cls]:
		for cell in row:
			if cell["id"] == id:
				return cell
	return {}


static func row_of(cls: String, id: String) -> int:
	for r in TREES[cls].size():
		for cell in TREES[cls][r]:
			if cell["id"] == id:
				return r
	return -1


static func points_in_row(cls: String, row: int, points: Dictionary) -> int:
	var total := 0
	for cell in TREES[cls][row]:
		total += points.get(cell["id"], 0)
	return total


## Can one more point go into this cell?
static func can_add(cls: String, id: String, points: Dictionary, level: int) -> bool:
	var row := row_of(cls, id)
	if row < 0 or level < ROW_LEVELS[row]:
		return false
	if points.get(id, 0) >= MAX_PER_CELL:
		return false
	return points_in_row(cls, row, points) < MAX_PER_ROW
