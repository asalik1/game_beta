class_name Skills
## Row-based skill tree (like classic MMO talent pages):
##  - a new ROW unlocks every 10 levels (ROW_LEVELS) — the tree fills out
##    across all of Act 1, capping exactly at level 40 (points == level)
##  - you may spend up to 10 points TOTAL per row, spread freely
##    across its 3 columns, max 10 in any single cell
##  - a cell may override its own ceiling with a "max" field (binary
##    talents like Last Rites cap at 1)
##  - each point buffs that cell's effect by one increment (values are
##    HALF the old 5-point tuning, so a maxed cell lands the same total)
##  - the 3 columns line up with the class's 3 themes / playstyles
##
## Cell fields (all per-point):
##   bonus {stat: value}          character stats
##   amod  {slot: {dmg/cd: v}}    ability modifiers
##   max   int                    optional per-cell ceiling (default MAX_PER_CELL)

const ROW_LEVELS := [10, 20, 30, 40]
const MAX_PER_CELL := 10
const MAX_PER_ROW := 10

const TREES := {
	"warrior": [  # columns: Fury / Bulwark / Earth
		[
			{"id": "w00", "name": "Heavy Cleave",  "desc": "Cleave +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "w01", "name": "Thick Hide",    "desc": "+2% max HP", "bonus": {"hp_pct": 0.02}},
			{"id": "w02", "name": "Wide Storm",    "desc": "Whirlwind +2.5% damage", "amod": {"a3": {"dmg": 0.025}}},
		],
		[
			{"id": "w10", "name": "Killer Instinct", "desc": "+0.75% crit chance", "bonus": {"crit": 0.0075}},
			{"id": "w11", "name": "Iron Wall",       "desc": "+5 physical resistance", "bonus": {"physres": 5.0}},
			{"id": "w12", "name": "Stonehide",       "desc": "+0.5 phys & magic res per Grit stack (the beating hardens you)", "bonus": {"grit_res": 0.5}},
		],
		[
			{"id": "w20", "name": "Battle Rhythm", "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
			{"id": "w21", "name": "Spell Ward",    "desc": "+5 magic resistance", "bonus": {"magres": 5.0}},
			{"id": "w22", "name": "Momentum",      "desc": "Whirlwind cooldown -2%", "amod": {"a3": {"cd": -0.02}}},
		],
		[
			{"id": "w30", "name": "Warlord",   "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "w31", "name": "Deep Grit", "desc": "+0.05% max HP/s per Grit stack (the beating mends you deeper)", "bonus": {"grit_regen": 0.0005}},
			{"id": "w32", "name": "Sunderer",  "desc": "+2 physical penetration", "bonus": {"physpen": 2.0}},
		],
	],
	"archer": [  # columns: Storm / Venom / Hunt
		[
			{"id": "a00", "name": "Swift Shot",       "desc": "Quick Shot +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "a01", "name": "Serpent's Due",    "desc": "+4% damage to poisoned enemies", "bonus": {"poison_dmg": 0.04}},
			{"id": "a02", "name": "Steady Aim",       "desc": "+0.75% crit chance", "bonus": {"crit": 0.0075}},
		],
		[
			{"id": "a10", "name": "Chain Reflex",     "desc": "+2 DEX (accuracy)", "bonus": {"dex": 2.0}},
			{"id": "a11", "name": "Second Breath",    "desc": "Second Wind regen +0.5% max HP/s", "bonus": {"sw_regen": 0.005}},
			{"id": "a12", "name": "Falcon's Patience", "desc": "Arrow Storm cooldown -5%", "amod": {"ult": {"cd": -0.05}}},
		],
		[
			{"id": "a20", "name": "Rapid Quiver",     "desc": "Multishot cooldown -2.5% and +2% damage", "amod": {"a2": {"cd": -0.025, "dmg": 0.02}}},
			{"id": "a21", "name": "Evasive",          "desc": "+0.75% evasion", "bonus": {"eva": 0.0075}},
			{"id": "a22", "name": "Piercer",          "desc": "+2 physical penetration", "bonus": {"physpen": 2.0}},
		],
		[
			{"id": "a30", "name": "Stormcaller", "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "a31", "name": "Windrunner",  "desc": "Tumble cooldown -1.5%", "amod": {"a3": {"cd": -0.015}}},
			{"id": "a32", "name": "Executioner", "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
		],
	],
	"mage": [  # columns: Fire / Ice / Wind
		[
			{"id": "m00", "name": "Kindled Bolt",  "desc": "Firebolt +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "m01", "name": "Killing Frost", "desc": "+4% damage to slowed or frozen enemies", "bonus": {"chill_dmg": 0.04}},
			{"id": "m02", "name": "Wind Cuts",     "desc": "Wind firebolt cuts — each bolt opens a 3s bleed, up to +13% (splits onto two targets)", "bonus": {"bolt_bleed": 0.013}},
		],
		[
			{"id": "m10", "name": "Rimeheart",    "desc": "Frost Nova also heals 0.75% max HP/s for 6s", "bonus": {"nova_regen": 0.0075}},
			{"id": "m11", "name": "Frost Armor",  "desc": "+2.5 phys & magic res, +1 crit res", "bonus": {"physres": 2.5, "magres": 2.5, "critres": 1.0}},
			{"id": "m12", "name": "Slipstream",   "desc": "Blink cooldown -2.5%", "amod": {"a3": {"cd": -0.025}}},
		],
		[
			{"id": "m20", "name": "Arcane Echo",  "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
			{"id": "m21", "name": "Piercing Cold", "desc": "+2 magic penetration", "bonus": {"magpen": 2.0}},
			{"id": "m22", "name": "Warding Veil", "desc": "+2.5% Blink damage reduction (the 0.8s ward)", "bonus": {"blink_dr": 0.025}},
		],
		[
			{"id": "m30", "name": "Archmage",   "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "m31", "name": "Permafrost", "desc": "Frost Nova & Blink cooldown -1%", "amod": {"a2": {"cd": -0.01}, "a3": {"cd": -0.01}}},
			{"id": "m32", "name": "Windborne",  "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
		],
	],
	"assassin": [  # columns: Poison / Shadow / Blood
		[
			{"id": "s00", "name": "Coated Blades", "desc": "Stab +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "s01", "name": "Night Edge",    "desc": "+0.75% crit chance", "bonus": {"crit": 0.0075}},
			{"id": "s02", "name": "Quick Hands",   "desc": "+2 DEX (accuracy)", "bonus": {"dex": 2.0}},
		],
		[
			{"id": "s10", "name": "Lingering Toxin", "desc": "Fan of Knives +3% damage", "amod": {"a3": {"dmg": 0.03}}},
			{"id": "s11", "name": "Ghost Step",      "desc": "+1% evasion", "bonus": {"eva": 0.01}},
			{"id": "s12", "name": "Opportunist",     "desc": "Shadow Dash +4% damage", "amod": {"a2": {"dmg": 0.04}}},
		],
		[
			{"id": "s20", "name": "Wasting Venom", "desc": "+2 physical penetration", "bonus": {"physpen": 2.0}},
			{"id": "s21", "name": "Coup de Grâce", "desc": "+4% damage to enemies below 40% HP", "bonus": {"execute_dmg": 0.04}},
			{"id": "s22", "name": "Iron Veins",    "desc": "+2% max HP", "bonus": {"hp_pct": 0.02}},
		],
		[
			{"id": "s30", "name": "Plaguebearer", "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "s31", "name": "Phantom",      "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
			{"id": "s32", "name": "Exsanguinate", "desc": "Shadow Dash connect-refund +2.5% (toward the 1s floor)", "bonus": {"dash_refund": 0.025}},
		],
	],
	"paladin": [  # columns: Holy / Aegis / Wrath
		[
			{"id": "p00", "name": "Righteous Blows", "desc": "Judgment +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "p01", "name": "Devotion",        "desc": "+2% max HP", "bonus": {"hp_pct": 0.02}},
			{"id": "p02", "name": "Zeal",            "desc": "+0.75% crit chance", "bonus": {"crit": 0.0075}},
		],
		[
			{"id": "p10", "name": "Hallowed Ground", "desc": "Consecration blesses the ground: +0.5% max HP/s for 6s (recast renews, never stacks)", "bonus": {"nova_regen": 0.005}},
			{"id": "p11", "name": "Shieldwall",      "desc": "+5 physical resistance", "bonus": {"physres": 5.0}},
			{"id": "p12", "name": "Fervor",          "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
		],
		[
			{"id": "p20", "name": "Lightmender", "desc": "+2% max HP", "bonus": {"hp_pct": 0.02}},
			{"id": "p21", "name": "Sanctuary",   "desc": "Aegis cooldown -2.5%", "amod": {"a3": {"cd": -0.025}}},
			{"id": "p22", "name": "Crusader",    "desc": "+2 physical penetration", "bonus": {"physpen": 2.0}},
		],
		[
			{"id": "p30", "name": "Beacon of Dawn", "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "p31", "name": "Unwavering Conviction", "desc": "Conviction (stance swap) cooldown -2.5%", "amod": {"ult": {"cd": -0.025}}},
			{"id": "p32", "name": "Executioner of the Faith", "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
		],
	],
	"warlock": [  # columns: Curse / Pact / Void
		[
			{"id": "k00", "name": "Wither",       "desc": "Shadowbolt +2.5% damage", "amod": {"a1": {"dmg": 0.025}}},
			{"id": "k01", "name": "Blood Tithe",  "desc": "+2% max HP", "bonus": {"hp_pct": 0.02}},
			{"id": "k02", "name": "Doomward",     "desc": "+1.5% damage reduction while any enemy is cursed", "bonus": {"curse_dr": 0.015}},
		],
		[
			{"id": "k10", "name": "Contagion",    "desc": "Cursed deaths spread the curse to a nearby foe (10% chance/pt)", "bonus": {"curse_spread": 0.10}},
			{"id": "k11", "name": "Transfusion",  "desc": "Lifesteal overheal becomes a temporary shield (caps at 2.5% max HP per point)", "bonus": {"transfusion": 0.025}},
			{"id": "k12", "name": "Rupture",      "desc": "Enemies you've shoved or pulled take +2% damage from your hits", "bonus": {"crush_amp": 0.02}},
		],
		[
			{"id": "k20", "name": "Unraveling", "desc": "+2 magic penetration", "bonus": {"magpen": 2.0}},
			{"id": "k21", "name": "Sacrificial Might", "desc": "+1.5% total damage while below 50% max HP", "bonus": {"lowhp_dmg": 0.015}},
			{"id": "k22", "name": "Nightfall",  "desc": "+2.5% crit to your crushing (Void) abilities", "bonus": {"void_crit": 0.025}},
		],
		[
			{"id": "k30", "name": "Archfiend's Favor", "desc": "+1% total damage", "bonus": {"atk_pct": 0.01}},
			{"id": "k31", "name": "Last Rites",        "desc": "Survive a lethal blow at 5% max HP (once per min)", "bonus": {"last_rites": 1.0}, "max": 1},
			{"id": "k32", "name": "Annihilation",      "desc": "+3% crit damage", "bonus": {"crit_dmg": 0.03}},
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


## This cell's own ceiling — a binary talent (Last Rites) overrides MAX_PER_CELL.
static func cell_max(cell: Dictionary) -> int:
	return int(cell.get("max", MAX_PER_CELL))


## Can one more point go into this cell?
static func can_add(cls: String, id: String, points: Dictionary, level: int) -> bool:
	var row := row_of(cls, id)
	if row < 0 or level < ROW_LEVELS[row]:
		return false
	var cell := find_cell(cls, id)
	if points.get(id, 0) >= cell_max(cell):
		return false
	return points_in_row(cls, row, points) < MAX_PER_ROW
