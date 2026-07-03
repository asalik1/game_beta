class_name Classes
## Playable classes, their ability kits, and their evolutions.
## Balance and flavor all live here.

# When a class evolves. Set low so it's reachable in Chapter 1;
# raise this (e.g. to 40) once the world is bigger.
const EVOLVE_LEVEL := 8

const CLASSES := {
	"warrior": {
		"name": "Warrior", "sprite": "warrior",
		"desc": "Frontline bruiser. Simple, tanky, hits hard up close.",
		"passive": {"text": "Plated — you take 25% less damage; your swings knock enemies back and stagger them.", "dr": 0.25},
		"hp": 130.0, "hp_lvl": 18.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 12.0, "atk_lvl": 3.0, "speed": 250.0,
		"abilities": {
			"a1": {"name": "Cleave",      "cd": 0.45, "mp": 0,  "desc": "Swing your blade at the nearest enemy."},
			"a2": {"name": "Shield Bash", "cd": 6.0,  "mp": 10, "desc": "Lunge and STUN the target for 1.2s."},
			"a3": {"name": "Whirlwind",   "cd": 8.0,  "mp": 15, "desc": "Damage everything around you."},
			"ult": {"name": "Berserk",    "cd": 50.0, "mp": 0,  "desc": "8s: +40% damage, +25% speed, 15% lifesteal."},
		},
		"evolutions": {
			"warlord":  {"name": "Warlord",  "desc": "+15% damage. Berserk grants +65% damage instead.", "bonus": {"atk_pct": 0.15}},
			"guardian": {"name": "Guardian", "desc": "+25% health, +10% damage reduction. Bash stuns 2s.", "bonus": {"hp_pct": 0.25, "dr": 0.10}},
		},
	},
	"archer": {
		"name": "Archer", "sprite": "archer",
		"desc": "Ranged skirmisher. Safe damage from a distance, with a dodge roll.",
		"passive": {"text": "Hawk Eye — +10% crit chance.", "crit": 0.10},
		"hp": 100.0, "hp_lvl": 14.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 13.0, "atk_lvl": 3.2, "speed": 265.0,
		"abilities": {
			"a1": {"name": "Quick Shot",  "cd": 0.4,  "mp": 0,  "desc": "Fire an arrow at the nearest enemy."},
			"a2": {"name": "Multishot",   "cd": 5.0,  "mp": 12, "desc": "Fan of 5 arrows."},
			"a3": {"name": "Tumble",      "cd": 6.0,  "mp": 0,  "desc": "Dodge-roll in your move direction (brief immunity)."},
			"ult": {"name": "Arrow Storm", "cd": 50.0, "mp": 20, "desc": "3s: arrows rain on every enemy near you."},
		},
		"evolutions": {
			"ranger": {"name": "Ranger", "desc": "Multishot fires 7 arrows. Quick Shot 25% faster.", "bonus": {"atk_pct": 0.08}},
			"sniper": {"name": "Sniper", "desc": "+25% crit chance. Your arrows pierce through enemies.", "bonus": {"crit": 0.25}},
		},
	},
	"mage": {
		"name": "Mage", "sprite": "mage",
		"desc": "Glass cannon. Huge burst, big mana pool, blink to survive.",
		"passive": {"text": "Attuned — 50% faster mana regeneration."},
		"hp": 90.0, "hp_lvl": 12.0, "mp": 70.0, "mp_lvl": 8.0,
		"atk": 14.0, "atk_lvl": 3.5, "speed": 255.0,
		"abilities": {
			"a1": {"name": "Firebolt",   "cd": 0.5,  "mp": 4,  "desc": "Hurl fire at the nearest enemy."},
			"a2": {"name": "Frost Nova", "cd": 7.0,  "mp": 20, "desc": "Blast around you, SLOWING enemies 50% for 2.5s."},
			"a3": {"name": "Blink",      "cd": 6.0,  "mp": 10, "desc": "Teleport in your move direction."},
			"ult": {"name": "Meteor",    "cd": 55.0, "mp": 40, "desc": "Call a meteor onto the nearest enemy. Massive damage."},
		},
		"evolutions": {
			"archmage":  {"name": "Archmage",  "desc": "+20% cooldown reduction, +40 mana.", "bonus": {"cdr": 0.20, "mp_flat": 40.0}},
			"pyromancer": {"name": "Pyromancer", "desc": "All your damage sets enemies on FIRE (burn over 3s).", "bonus": {"atk_pct": 0.05}},
		},
	},
	"assassin": {
		"name": "Assassin", "sprite": "assassin",
		"desc": "Fast melee striker. Teleports behind targets. Nothing personal.",
		"passive": {"text": "Elusive — 20% chance to dodge any hit; your strikes stagger enemies.", "dodge": 0.20},
		"hp": 95.0, "hp_lvl": 13.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 12.0, "atk_lvl": 3.4, "speed": 275.0,
		"abilities": {
			"a1": {"name": "Stab",          "cd": 0.3,  "mp": 0,  "desc": "Lightning-fast strike."},
			"a2": {"name": "Shadowstep",    "cd": 7.0,  "mp": 12, "desc": "Teleport behind the nearest enemy and strike."},
			"a3": {"name": "Fan of Knives", "cd": 4.5,  "mp": 10, "desc": "Hurl 3 knives in a tight spread."},
			"ult": {"name": "Death Mark",   "cd": 45.0, "mp": 0,  "desc": "Burst the nearest enemy; it takes +50% damage for 5s."},
		},
		"evolutions": {
			"shadow": {"name": "Shadow Assassin", "desc": "Shadowstep cooldown 3s. +15% move speed.", "bonus": {"speed_pct": 0.15}},
			"blood":  {"name": "Blood Assassin",  "desc": "12% lifesteal, +50% crit damage.", "bonus": {"lifesteal": 0.12, "crit_dmg": 0.5}},
		},
	},
}


static func ability(cls: String, slot: String) -> Dictionary:
	return CLASSES[cls]["abilities"][slot]
