class_name Skills
## Per-class skill trees. Each class has 3 branches — one per basic
## ability — and 4 tiers, unlocked top to bottom (1 point each).
##   tier 1: numeric boost      tier 2: BEHAVIOR change
##   tier 3: bigger boost       tier 4: capstone whose effect depends
##                                       on your chosen EVOLUTION
##
## Node fields:
##   amod      {slot: {dmg/cd/mp: +-fraction}}  ability modifiers
##   bonus     {stat: value}                     flat character stats
##   evo_bonus {evolution: {stat: value}}        stats only for that evolution
##   evo_amod  {evolution: {slot: {field: v}}}   ability mods per evolution
## Behavior nodes are checked by id in player.gd (has_mod).

const TREES := {
	"warrior": {
		"a1": [
			{"id": "wA0", "name": "Heavy Blade",   "desc": "Cleave deals +25% damage.", "amod": {"a1": {"dmg": 0.25}}},
			{"id": "wA1", "name": "Sweeping Arc",  "desc": "Cleave reaches 40% farther and knocks back much harder."},
			{"id": "wA2", "name": "Butcher",       "desc": "Cleave +25% damage, cooldown -15%.", "amod": {"a1": {"dmg": 0.25, "cd": -0.15}}},
			{"id": "wA3", "name": "Avatar of Steel", "desc": "Cleave +30%.  WARLORD: +10% total damage.  GUARDIAN: +8% damage reduction.",
				"amod": {"a1": {"dmg": 0.30}}, "evo_bonus": {"warlord": {"atk_pct": 0.10}, "guardian": {"dr": 0.08}}},
		],
		"a2": [
			{"id": "wB0", "name": "Concussion",   "desc": "Shield Bash deals +40% damage.", "amod": {"a2": {"dmg": 0.40}}},
			{"id": "wB1", "name": "Aftershock",   "desc": "Shield Bash also damages every enemy near the impact."},
			{"id": "wB2", "name": "Relentless",   "desc": "Shield Bash cooldown -30%.", "amod": {"a2": {"cd": -0.30}}},
			{"id": "wB3", "name": "Kingsbreaker", "desc": "Bash +50%.  WARLORD: another +50% Bash damage.  GUARDIAN: +10% health.",
				"amod": {"a2": {"dmg": 0.50}}, "evo_amod": {"warlord": {"a2": {"dmg": 0.50}}}, "evo_bonus": {"guardian": {"hp_pct": 0.10}}},
		],
		"a3": [
			{"id": "wC0", "name": "Momentum",  "desc": "Whirlwind cooldown -25%.", "amod": {"a3": {"cd": -0.25}}},
			{"id": "wC1", "name": "Cyclone",   "desc": "Whirlwind PULLS enemies into you instead of knocking them away."},
			{"id": "wC2", "name": "Tempest",   "desc": "Whirlwind +35% damage, cooldown -10%.", "amod": {"a3": {"dmg": 0.35, "cd": -0.10}}},
			{"id": "wC3", "name": "Eye of the Storm", "desc": "Whirlwind +30%.  WARLORD: Berserk lasts 12s.  GUARDIAN: +5% health and damage reduction.",
				"amod": {"a3": {"dmg": 0.30}}, "evo_bonus": {"guardian": {"dr": 0.05, "hp_pct": 0.05}}},
		],
	},
	"archer": {
		"a1": [
			{"id": "aA0", "name": "Sharpened Tips", "desc": "Quick Shot deals +25% damage.", "amod": {"a1": {"dmg": 0.25}}},
			{"id": "aA1", "name": "Split Shot",     "desc": "Quick Shot fires a SECOND arrow at 50% damage."},
			{"id": "aA2", "name": "Rapid Nock",     "desc": "Quick Shot cooldown -25%.", "amod": {"a1": {"cd": -0.25}}},
			{"id": "aA3", "name": "Deadeye",        "desc": "Quick Shot +30%.  RANGER: +8% total damage.  SNIPER: +30% crit damage.",
				"amod": {"a1": {"dmg": 0.30}}, "evo_bonus": {"ranger": {"atk_pct": 0.08}, "sniper": {"crit_dmg": 0.30}}},
		],
		"a2": [
			{"id": "aB0", "name": "Wide Volley",   "desc": "Multishot deals +30% damage.", "amod": {"a2": {"dmg": 0.30}}},
			{"id": "aB1", "name": "Barbed Arrows", "desc": "Multishot arrows SLOW enemies by 35% for 2s."},
			{"id": "aB2", "name": "Quick Quiver",  "desc": "Multishot cooldown -30%.", "amod": {"a2": {"cd": -0.30}}},
			{"id": "aB3", "name": "Rain of Barbs", "desc": "Multishot +40% and +1 arrow.  RANGER: +2 arrows instead.  SNIPER: +8% crit chance.",
				"amod": {"a2": {"dmg": 0.40}}, "evo_bonus": {"sniper": {"crit": 0.08}}},
		],
		"a3": [
			{"id": "aC0", "name": "Light Step",  "desc": "Tumble cooldown -30%.", "amod": {"a3": {"cd": -0.30}}},
			{"id": "aC1", "name": "Quiver Roll", "desc": "Tumble RESETS Multishot's cooldown."},
			{"id": "aC2", "name": "Adrenaline",  "desc": "Tumble grants +20% move speed for 3s."},
			{"id": "aC3", "name": "Windrunner",  "desc": "+8% move speed.  RANGER: Tumble fires a free Multishot.  SNIPER: +5% crit chance.",
				"bonus": {"speed_pct": 0.08}, "evo_bonus": {"sniper": {"crit": 0.05}}},
		],
	},
	"mage": {
		"a1": [
			{"id": "mA0", "name": "Kindling",     "desc": "Firebolt deals +25% damage.", "amod": {"a1": {"dmg": 0.25}}},
			{"id": "mA1", "name": "Fireburst",    "desc": "Firebolt EXPLODES on hit, splashing 50% damage around the target."},
			{"id": "mA2", "name": "Cheap Sparks", "desc": "Firebolt costs no mana and deals +10% damage.", "amod": {"a1": {"mp": -1.0, "dmg": 0.10}}},
			{"id": "mA3", "name": "Conflagration", "desc": "Firebolt +30%.  ARCHMAGE: Firebolt cd -20%.  PYROMANCER: your burns are 50% stronger.",
				"amod": {"a1": {"dmg": 0.30}}, "evo_amod": {"archmage": {"a1": {"cd": -0.20}}}},
		],
		"a2": [
			{"id": "mB0", "name": "Biting Frost",  "desc": "Frost Nova deals +30% damage.", "amod": {"a2": {"dmg": 0.30}}},
			{"id": "mB1", "name": "Deep Freeze",   "desc": "Frost Nova ROOTS enemies in place for 1.2s instead of slowing."},
			{"id": "mB2", "name": "Widening Gyre", "desc": "Frost Nova radius +40%, cooldown -10%.", "amod": {"a2": {"cd": -0.10}}},
			{"id": "mB3", "name": "Absolute Zero", "desc": "Nova +40%.  ARCHMAGE: refunds 8 mana per enemy hit.  PYROMANCER: Nova's slow/root lasts twice as long.",
				"amod": {"a2": {"dmg": 0.40}}},
		],
		"a3": [
			{"id": "mC0", "name": "Slipstream",  "desc": "Blink cooldown -30%.", "amod": {"a3": {"cd": -0.30}}},
			{"id": "mC1", "name": "Static Step", "desc": "Blink SHOCKS enemies at your departure and arrival points."},
			{"id": "mC2", "name": "Long Stride", "desc": "Blink travels 60% farther."},
			{"id": "mC3", "name": "Phase Shift", "desc": "Blink grants 1s of +50% dodge.  ARCHMAGE: Blink cd -35%.  PYROMANCER: your Blink shocks also ignite.",
				"evo_amod": {"archmage": {"a3": {"cd": -0.35}}}},
		],
	},
	"assassin": {
		"a1": [
			{"id": "sA0", "name": "Razor Edge",  "desc": "Stab deals +25% damage.", "amod": {"a1": {"dmg": 0.25}}},
			{"id": "sA1", "name": "Twin Blades", "desc": "Stab strikes TWICE (second hit at 50%)."},
			{"id": "sA2", "name": "Flurry",      "desc": "Stab cooldown -25%.", "amod": {"a1": {"cd": -0.25}}},
			{"id": "sA3", "name": "Exsanguinate", "desc": "Stab +30%.  SHADOW: +8% move speed.  BLOOD: +5% lifesteal.",
				"amod": {"a1": {"dmg": 0.30}}, "evo_bonus": {"shadow": {"speed_pct": 0.08}, "blood": {"lifesteal": 0.05}}},
		],
		"a2": [
			{"id": "sB0", "name": "Ambush",            "desc": "Shadowstep deals +40% damage.", "amod": {"a2": {"dmg": 0.40}}},
			{"id": "sB1", "name": "Stunning Entrance", "desc": "Shadowstep STUNS the target for 1s."},
			{"id": "sB2", "name": "Phantom",           "desc": "Shadowstep cooldown -30%.", "amod": {"a2": {"cd": -0.30}}},
			{"id": "sB3", "name": "Executioner", "desc": "Shadowstep deals +60% to enemies below 35% health.  SHADOW: cd -20%.  BLOOD: +40% crit damage.",
				"evo_amod": {"shadow": {"a2": {"cd": -0.20}}}, "evo_bonus": {"blood": {"crit_dmg": 0.40}}},
		],
		"a3": [
			{"id": "sC0", "name": "Balanced Throw", "desc": "Fan of Knives deals +30% damage.", "amod": {"a3": {"dmg": 0.30}}},
			{"id": "sC1", "name": "Serrated",       "desc": "Your knives PIERCE through enemies."},
			{"id": "sC2", "name": "Deft Hands",     "desc": "Fan of Knives cooldown -30%.", "amod": {"a3": {"cd": -0.30}}},
			{"id": "sC3", "name": "Thousand Cuts",  "desc": "Knives +40% and you throw 5 knives.  SHADOW: +5% move speed.  BLOOD: +4% lifesteal.",
				"amod": {"a3": {"dmg": 0.40}}, "evo_bonus": {"shadow": {"speed_pct": 0.05}, "blood": {"lifesteal": 0.04}}},
		],
	},
}


static func branches(cls: String) -> Dictionary:
	return TREES[cls]


## Find a node by id anywhere in this class's tree ({} if not found).
static func get_node_data(cls: String, id: String) -> Dictionary:
	for branch in TREES[cls]:
		for node in TREES[cls][branch]:
			if node["id"] == id:
				return node
	return {}


## A node can be learned if it's the next unlearned tier in its branch.
static func can_learn(cls: String, id: String, learned: Dictionary) -> bool:
	if learned.has(id):
		return false
	for branch in TREES[cls]:
		var nodes: Array = TREES[cls][branch]
		for i in nodes.size():
			if nodes[i]["id"] == id:
				return i == 0 or learned.has(nodes[i - 1]["id"])
	return false
