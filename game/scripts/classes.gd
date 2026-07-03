class_name Classes
## Playable classes, ability kits, and the THEME system.
##
## Themes replace the old binary evolution: each class has 3 elemental
## playstyles, unlocked at THEME_LEVELS. Every ability can be assigned
## any unlocked theme independently (mix & match builds) — a theme
## changes the ability's BEHAVIOR via its "fx" modifiers:
##   dot          apply damage-over-time (fraction of ATK per second)
##   slow         slow enemies hit (fraction)
##   stun_chance  chance to stun 0.5s
##   echo         chance the hit strikes a second time at 50%
##   heal         heal self this fraction of max HP per hit
##   vuln         chance to mark target (+50% damage taken, 3s)
##   crit_bonus   bonus crit chance on themed hits
##   splash       AoE splash around the target (fraction)
##   speed_buff   move-speed buff for 2.5s after casting
##   guard_buff   +physres/magres for 2.5s after casting

# Levels at which a new theme unlocks (raise these for a bigger world).
const THEME_LEVELS := [4, 8, 12]

const THEMES := {
	"assassin": [
		{"id": "poison", "name": "Poison", "color": Color(0.45, 0.95, 0.30),
			"desc": "Stacking DoT and utility: everything drips venom and slows.",
			"fx": {"dot": 0.30, "slow": 0.30}},
		{"id": "shadow", "name": "Shadow", "color": Color(0.60, 0.45, 1.00),
			"desc": "Burst, crits and mobility: strike hard, be gone.",
			"fx": {"crit_bonus": 0.15, "speed_buff": 0.25}},
		{"id": "blood", "name": "Blood", "color": Color(1.00, 0.30, 0.30),
			"desc": "Combo hits, stuns, and healing through violence.",
			"fx": {"echo": 0.45, "heal": 0.02, "stun_chance": 0.15}},
	],
	"mage": [
		{"id": "fire", "name": "Fire", "color": Color(1.00, 0.55, 0.15),
			"desc": "Burst AoE and burning: everything explodes.",
			"fx": {"dot": 0.35, "splash": 0.40}},
		{"id": "ice", "name": "Ice", "color": Color(0.45, 0.90, 1.00),
			"desc": "Single-target control: slows, roots and freezes.",
			"fx": {"slow": 0.50, "stun_chance": 0.20}},
		{"id": "wind", "name": "Wind", "color": Color(0.70, 1.00, 0.75),
			"desc": "Speed and flurries: extra hits and swift movement.",
			"fx": {"echo": 0.35, "speed_buff": 0.30}},
	],
	"warrior": [
		{"id": "fury", "name": "Fury", "color": Color(1.00, 0.40, 0.20),
			"desc": "Relentless offense: crits and follow-up strikes.",
			"fx": {"crit_bonus": 0.10, "echo": 0.30}},
		{"id": "bulwark", "name": "Bulwark", "color": Color(0.55, 0.70, 1.00),
			"desc": "Defense through aggression: casting hardens you, hits mend you.",
			"fx": {"guard_buff": 80.0, "heal": 0.02}},
		{"id": "earth", "name": "Earth", "color": Color(0.80, 0.60, 0.30),
			"desc": "Crushing control: staggers and slows.",
			"fx": {"stun_chance": 0.25, "slow": 0.30}},
	],
	"archer": [
		{"id": "storm", "name": "Storm", "color": Color(1.00, 0.95, 0.40),
			"desc": "Chain lightning arrows: extra hits crackle between foes.",
			"fx": {"echo": 0.40, "splash": 0.25}},
		{"id": "venom", "name": "Venom", "color": Color(0.45, 0.95, 0.30),
			"desc": "Toxin-tipped arrows: DoT and slows.",
			"fx": {"dot": 0.30, "slow": 0.25}},
		{"id": "hunt", "name": "Hunt", "color": Color(1.00, 0.60, 0.25),
			"desc": "Precision: crits and marks that expose the prey.",
			"fx": {"crit_bonus": 0.15, "vuln": 0.20}},
	],
}

# ------------------------------------------------------------------ classes ---
# "primary": the attribute this class scales on (adds ATK + a little crit).

const CLASSES := {
	"warrior": {
		"name": "Warrior", "sprite": "warrior", "primary": "STR", "dmg_type": "phys",
		"desc": "Frontline bruiser. Simple, tanky, hits hard up close.",
		"passive": {"text": "Plated — you take much less damage; your swings knock enemies back and stagger them.", "physres": 60.0, "magres": 30.0},
		"hp": 130.0, "hp_lvl": 18.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 14.5, "atk_lvl": 3.7, "speed": 250.0,
		"abilities": {
			"a1": {"name": "Cleave",      "cd": 0.45, "mp": 0,  "desc": "Swing your blade at the nearest enemy."},
			"a2": {"name": "Shield Bash", "cd": 6.0,  "mp": 10, "desc": "Charge forward, ramming everything in your path: damage, knockback and a 1.3s STUN."},
			"a3": {"name": "Whirlwind",   "cd": 8.0,  "mp": 15, "desc": "Damage everything around you."},
			"ult": {"name": "Berserk",    "cd": 50.0, "mp": 0,  "desc": "8s: +40% damage, +25% speed, 15% lifesteal."},
		},
	},
	"archer": {
		"name": "Archer", "sprite": "archer", "primary": "AGI", "dmg_type": "phys",
		"desc": "Ranged skirmisher. Safe damage from a distance, with a dodge roll.",
		"passive": {"text": "Hawk Eye — +10% crit chance, +12 DEX.", "crit": 0.10, "dex": 12.0},
		"hp": 100.0, "hp_lvl": 14.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 10.0, "atk_lvl": 2.5, "speed": 265.0,
		"abilities": {
			"a1": {"name": "Quick Shot",  "cd": 0.4,  "mp": 0,  "desc": "Fire an arrow at the nearest enemy."},
			"a2": {"name": "Multishot",   "cd": 5.0,  "mp": 12, "desc": "Fan of 5 arrows."},
			"a3": {"name": "Tumble",      "cd": 6.0,  "mp": 0,  "desc": "Dodge-roll in your move direction (brief immunity)."},
			"ult": {"name": "Arrow Storm", "cd": 50.0, "mp": 20, "desc": "3s: arrows rain on every enemy near you."},
		},
	},
	"mage": {
		"name": "Mage", "sprite": "mage", "primary": "INT", "dmg_type": "magic",
		"desc": "Glass cannon. Huge burst, big mana pool, blink to survive.",
		"passive": {"text": "Attuned — 50% faster mana regeneration, +10 magic penetration.", "magpen": 10.0},
		"hp": 90.0, "hp_lvl": 12.0, "mp": 70.0, "mp_lvl": 8.0,
		"atk": 12.5, "atk_lvl": 3.1, "speed": 255.0,
		"abilities": {
			"a1": {"name": "Firebolt",   "cd": 0.5,  "mp": 4,  "desc": "Hurl a bolt at the nearest enemy."},
			"a2": {"name": "Frost Nova", "cd": 7.0,  "mp": 20, "desc": "Heavy blast around you: knocks enemies away and SLOWS them 50%."},
			"a3": {"name": "Blink",      "cd": 6.0,  "mp": 10, "desc": "Dash in your move direction, shocking everything in your path."},
			"ult": {"name": "Meteor",    "cd": 55.0, "mp": 40, "desc": "Call a meteor onto the nearest enemy. Massive damage."},
		},
	},
	"assassin": {
		"name": "Assassin", "sprite": "assassin", "primary": "AGI", "dmg_type": "phys",
		"desc": "Fast melee striker. Dashes through enemies. Nothing personal.",
		"passive": {"text": "Elusive — 20% evasion; your strikes stagger enemies.", "eva": 0.20},
		"hp": 95.0, "hp_lvl": 13.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 13.5, "atk_lvl": 3.8, "speed": 275.0,
		"abilities": {
			"a1": {"name": "Stab",          "cd": 0.3,  "mp": 0,  "desc": "Lightning-fast strike."},
			"a2": {"name": "Shadow Dash",   "cd": 7.0,  "mp": 12, "desc": "Dash in your move direction, slashing everything in your path."},
			"a3": {"name": "Fan of Knives", "cd": 4.5,  "mp": 10, "desc": "Hurl 3 knives in a tight spread."},
			"ult": {"name": "Death Mark",   "cd": 45.0, "mp": 0,  "desc": "TRUE-damage burst; target takes +50% damage for 5s."},
		},
	},
}


static func ability(cls: String, slot: String) -> Dictionary:
	return CLASSES[cls]["abilities"][slot]


static func theme_by_id(cls: String, id: String) -> Dictionary:
	for theme in THEMES[cls]:
		if theme["id"] == id:
			return theme
	return {}


## Human-readable summary of what a theme's fx modifiers do.
static func fx_text(fx: Dictionary) -> String:
	var bits: Array = []
	if fx.has("dot"):
		bits.append("applies a DoT: %d%% ATK/s for 3s" % int(fx["dot"] * 100))
	if fx.has("slow"):
		bits.append("slows enemies %d%% for 2s" % int(fx["slow"] * 100))
	if fx.has("stun_chance"):
		bits.append("%d%% chance to STUN 0.5s" % int(fx["stun_chance"] * 100))
	if fx.has("echo"):
		bits.append("%d%% chance to strike AGAIN at 50%% damage" % int(fx["echo"] * 100))
	if fx.has("heal"):
		bits.append("heals %d%% max HP per hit" % int(fx["heal"] * 100))
	if fx.has("vuln"):
		bits.append("%d%% chance to EXPOSE (+50%% damage taken, 3s)" % int(fx["vuln"] * 100))
	if fx.has("crit_bonus"):
		bits.append("+%d%% crit chance on this ability" % int(fx["crit_bonus"] * 100))
	if fx.has("splash"):
		bits.append("splashes %d%% damage around the target" % int(fx["splash"] * 100))
	if fx.has("speed_buff"):
		bits.append("+%d%% move speed for 2.5s after casting" % int(fx["speed_buff"] * 100))
	if fx.has("guard_buff"):
		bits.append("+%d resistances for 2.5s after casting" % int(fx["guard_buff"]))
	return "\n".join(bits)


## How many themes a character of this level has unlocked.
static func themes_unlocked(level: int) -> int:
	var n := 0
	for lv in THEME_LEVELS:
		if level >= lv:
			n += 1
	return n
