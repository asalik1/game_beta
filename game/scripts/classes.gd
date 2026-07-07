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
			"fx": {"dot": 0.30, "slow": 0.30, "toxin": 1}},
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
			"desc": "Single-target control: slows, freezes, and cold that cracks armor.",
			"fx": {"slow": 0.50, "stun_chance": 0.20, "brittle": 1}},
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
			"fx": {"echo": 0.45, "splash": 0.30}},
		{"id": "venom", "name": "Venom", "color": Color(0.45, 0.95, 0.30),
			"desc": "Toxin-tipped arrows: stacking DoT and slows.",
			"fx": {"dot": 0.38, "slow": 0.30, "toxin": 1}},
		{"id": "hunt", "name": "Hunt", "color": Color(1.00, 0.60, 0.25),
			"desc": "Precision: crits and marks that expose the prey.",
			"fx": {"crit_bonus": 0.15, "vuln": 0.20}},
	],
	"paladin": [
		{"id": "holy", "name": "Holy", "color": Color(1.00, 0.92, 0.55),
			"desc": "Consecrated light: your blows mend you and sear the wicked.",
			"fx": {"heal": 0.02, "dot": 0.25}},
		{"id": "aegis", "name": "Aegis", "color": Color(0.60, 0.78, 1.00),
			"desc": "The shield answers: casting hardens you, blows stagger.",
			"fx": {"guard_buff": 80.0, "stun_chance": 0.15}},
		{"id": "wrath", "name": "Wrath", "color": Color(1.00, 0.45, 0.22),
			"desc": "Zeal and vengeance: crits and echoing judgment.",
			"fx": {"crit_bonus": 0.12, "echo": 0.30}},
	],
	"warlock": [
		{"id": "curse", "name": "Curse", "color": Color(0.75, 0.40, 1.00),
			"desc": "Hexes and rot: wither, expose, detonate.",
			"fx": {"dot": 0.30, "vuln": 0.20}},
		{"id": "pact", "name": "Pact", "color": Color(1.00, 0.30, 0.45),
			"desc": "Blood for power: pay in HP, feast on the return.",
			"fx": {"heal": 0.025, "crit_bonus": 0.10}},
		{"id": "void", "name": "Void", "color": Color(0.50, 0.55, 1.00),
			"desc": "Gravity and hunger: pulls, slows, and hits that CRUSH whatever is still tumbling.",
			"fx": {"slow": 0.35, "splash": 0.30, "crush": 1}},
	],
}

# ------------------------------------------------------------------ classes ---
# "primary": the attribute this class scales on (adds ATK + a little crit).

const CLASSES := {
	"warrior": {
		"name": "Warrior", "sprite": "warrior", "primary": "STR", "dmg_type": "phys",
		"desc": "Frontline bruiser. Simple, tanky, hits hard up close.",
		"passive": {"text": "Plated — your armor turns aside 15% of EVERY blow on top of resistances, your swings knock enemies back, and your wounds knit themselves (1.5% max HP/s). GRIT: every blow you TAKE stokes recovery — +0.6% max HP/s per hit, up to 6 stacks. The grind feeds you; kiting starves you.", "physres": 80.0, "magres": 45.0, "regen_pct": 0.015, "flat_dr": 0.15, "grit_regen": 0.006, "grit_cap": 6.0},
		"hp": 130.0, "hp_lvl": 19.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 15.5, "atk_lvl": 4.3, "speed": 250.0,
		"abilities": {
			"a1": {"name": "Cleave",      "cd": 0.74, "mp": 0,  "desc": "Swing your blade at the nearest enemy. The measured pace of a plated arm — BERSERK swings it at full speed."},
			"a2": {"name": "Shield Bash", "cd": 4.5,  "mp": 10, "desc": "Charge forward, ramming everything in your path: damage, knockback and a 1.3s STUN."},
			"a3": {"name": "Whirlwind",   "cd": 8.0,  "mp": 15, "desc": "Damage everything around you."},
			"ult": {"name": "Berserk",    "cd": 40.0, "mp": 0,  "desc": "8s: +40% damage, +25% speed, 15% lifesteal — and the rage swings Cleave at its unchained speed."},
		},
	},
	"archer": {
		"name": "Archer", "sprite": "archer", "primary": "AGI", "dmg_type": "phys",
		"desc": "Ranged skirmisher. Safe damage from a distance, with a dodge roll.",
		"passive": {"text": "Hawk Eye — +10% crit chance, +12 DEX. Second Wind: untouched for 3s, you recover a strong 6% max HP/s — spacing IS your sustain.", "crit": 0.10, "dex": 12.0, "sw_delay": 3.0, "sw_regen": 0.06},
		"hp": 100.0, "hp_lvl": 14.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 11.66, "atk_lvl": 3.06, "speed": 265.0,   # round 47: −7.5%; round 49 (dps bench): +5% back — archer trailed the field
		"abilities": {
			"a1": {"name": "Quick Shot",  "cd": 0.36, "mp": 0,  "desc": "Fire an arrow at the nearest enemy."},
			"a2": {"name": "Multishot",   "cd": 5.0,  "mp": 12, "desc": "Fan of 5 arrows."},
			"a3": {"name": "Tumble",      "cd": 6.0,  "mp": 0,  "desc": "Dodge-roll in your move direction: a split-second perfect-dodge window, then you stay nimble (+20% evasion) for 1.25s. Time it into a hit to negate it outright; otherwise the evasion covers your reposition."},
			"ult": {"name": "Arrow Storm", "cd": 40.0, "mp": 20, "desc": "3s: arrows rain on every enemy near you."},
		},
	},
	"mage": {
		"name": "Mage", "sprite": "mage", "primary": "INT", "dmg_type": "magic",
		"desc": "Glass cannon. Huge burst, big mana pool, blink to survive.",
		"passive": {"text": "Attuned — 50% faster mana regeneration, +10 magic penetration. Arcane Ward: Blink wraps you in magic — 50% damage reduction for 0.8s.", "magpen": 10.0, "blink_dr": 0.50, "blink_dr_dur": 0.8},
		"hp": 90.0, "hp_lvl": 12.0, "mp": 70.0, "mp_lvl": 8.0,
		"atk": 13.5, "atk_lvl": 3.7, "speed": 255.0,
		"abilities": {
			"a1": {"name": "Firebolt",   "cd": 0.45, "mp": 4,  "desc": "Hurl a bolt at the nearest enemy."},
			"a2": {"name": "Frost Nova", "cd": 7.0,  "mp": 15, "desc": "Blast around you: knocks enemies away, SLOWS them 50%, and restores 20% of your MISSING health and mana."},
			"a3": {"name": "Blink",      "cd": 4.5,  "mp": 10, "desc": "Dash in your move direction, shocking everything in your path."},
			"ult": {"name": "Meteor",    "cd": 44.0, "mp": 40, "desc": "Call a meteor onto the nearest enemy. Massive damage."},
		},
	},
	"assassin": {
		"name": "Assassin", "sprite": "assassin", "primary": "AGI", "dmg_type": "phys",
		"desc": "Fast melee striker. Dashes through enemies. Nothing personal.",
		"manaless": true,  # class-level flag: HUD hides MP, abilities cost nothing
		"passive": {"text": "Elusive — MANALESS: abilities cost nothing. 15% evasion, and blood you spill feeds you (1.2% max HP/s regen).", "eva": 0.15, "regen_pct": 0.012},
		"hp": 95.0, "hp_lvl": 13.0, "mp": 40.0, "mp_lvl": 3.0,
		"atk": 14.5, "atk_lvl": 4.5, "speed": 275.0,
		"abilities": {
			"a1": {"name": "Stab",          "cd": 0.3,  "mp": 0,  "desc": "Quick-draw the long blade — a lightning strike with real reach. A CONNECTING cut surges your lifesteal for 4s; the lower your health, the bigger the surge."},
			"a2": {"name": "Shadow Dash",   "cd": 3.75, "mp": 0,  "desc": "Dash in your move direction, slashing everything in your path — the blade reaches wide (a close pass cuts at FULL stab strength, the farthest graze lands lighter), and the blood surge is full at any depth. Its base cooldown MATCHES your Blood Surge: a CONNECTING cut refunds it so you keep dancing and keep the surge alive — but WHIFF and the full cooldown outlasts the surge, your Fan drops to normal, and you're exposed. Landing the blade is the whole game."},
			"a3": {"name": "Fan of Knives", "cd": 0.3,  "mp": 0,  "desc": "Spammable dagger fan — thin chip on its own, but while your blood surge runs the blades bite TWICE as hard. The range damage is EARNED in close. Shares its cadence with Stab: spam either, never both."},
			"ult": {"name": "Death Mark",   "cd": 30.0, "mp": 0,  "desc": "Mark your prey with the X: two shadows converge THROUGH it, then you appear behind it for the killing stab. TRUE damage; the marked target takes +50% damage for 5s. FIXED 30s cooldown — no haste can hurry the execution."},
		},
	},
	"paladin": {
		"name": "Paladin", "sprite": "paladin", "primary": "STR", "dmg_type": "phys",
		"desc": "Stance knight. In HOLY his blows mend him; in RETRIBUTION he trades the mending for wrath. Reading when to swap IS the class.",
		"passive": {"text": "Sanctified — blessed plate turns aside 12% of every blow; every strike returns as healing (4%), and the light mends you (1% max HP/s). CONVICTION: you fight in a stance — HOLY (blows mend you, -20% damage) or RETRIBUTION (+25% damage, no stance mending — your lifesteal and regen still hold).", "physres": 60.0, "magres": 60.0, "lifesteal": 0.04, "regen_pct": 0.010, "flat_dr": 0.12},
		"hp": 125.0, "hp_lvl": 17.0, "mp": 55.0, "mp_lvl": 5.0,
		"atk": 15.0, "atk_lvl": 4.3, "speed": 248.0,
		"abilities": {
			"a1": {"name": "Judgment",       "cd": 0.8,  "mp": 0,  "desc": "Bring the warhammer down on the nearest enemy — LEAPING to them if they stand beyond arm's reach (the leap arms every 5s; its brief landing guard rides the leap, not the swing)."},
			"a2": {"name": "Consecration",   "cd": 8.0,  "mp": 15, "desc": "Sanctify the ground around you: two waves of holy fire, and every enemy struck MENDS you."},
			"a3": {"name": "Aegis",          "cd": 9.0,  "mp": 12, "desc": "Raise the shield for 2.5s: massive resistances, and attackers are SMITTEN in return."},
			"ult": {"name": "Conviction",    "cd": 8.0,  "mp": 0,  "desc": "Swap stances. Entering RETRIBUTION drags nearby enemies to your hammer in chains; returning to HOLY releases a mending blessing (10% max HP + brief guard). Sustain and damage are never yours at once — choose when to be which."},
		},
	},
	"warlock": {
		"name": "Warlock", "sprite": "warlock", "primary": "INT", "dmg_type": "magic",
		"desc": "Ranged hexer. Curses that detonate on death, blood paid for power, rifts that bite late.",
		"passive": {"text": "Soulthirst — 5% of all damage returns as life; +8 magic penetration.", "lifesteal": 0.05, "magpen": 8.0},
		"hp": 95.0, "hp_lvl": 13.0, "mp": 65.0, "mp_lvl": 7.0,
		"atk": 11.5, "atk_lvl": 3.0, "speed": 258.0,
		"abilities": {
			"a1": {"name": "Shadowbolt", "cd": 0.5,  "mp": 1,  "desc": "Hurl a bolt of hungry darkness at the nearest enemy."},
			"a2": {"name": "Hex",        "cd": 7.0,  "mp": 16, "desc": "Curse enemies around your target: withered and EXPOSED — cursed enemies EXPLODE on death. A MAINTAINED curse deepens: the longer it holds, the harder your every hit bites."},
			"a3": {"name": "Dark Pact",  "cd": 9.0,  "mp": 0,  "desc": "Sacrifice 12% max HP for a soul-drain blast; for 5s your lifesteal surges."},
			"ult": {"name": "Void Rift", "cd": 50.0, "mp": 35, "desc": "Tear a rift under the nearest enemy: it drags everything inward, then BURSTS."},
		},
	},
}


# ---------------------------------------------------------- attributes ---
# Each level grants 1 attribute point — same cadence as skill points
# (playtest round 5: 5/level buried the player in unspent points and
# quietly stacked ~1.5 extra levels of ATK per level on top of natural
# growth). What a point gives depends on the CLASS (scaling ratios): an
# assassin converts AGI into power at triple the rate of STR; a warrior
# is the reverse.
# Balance sketch (per point, primary attr): +1.2 ATK ≈ a third of a
# level's natural attack growth — a nudge, not a second growth curve.
const ATTR_NAMES := ["STR", "AGI", "INT", "VIT"]

# Substat allocation (playtest round 6): talent points can also go
# STRAIGHT into a combat substat — same conversion for every class,
# no ratios. Combo is deliberately absent (a purchasable cooldown-skip
# chance every level would snowball).
const SUBSTAT_NAMES := ["PhysRes", "MagRes", "CritRes", "DEX", "PhysPen", "MagPen"]
const SUBSTAT_SCALE := {
	"PhysRes": {"physres": 2.0},
	"MagRes": {"magres": 2.0},
	"CritRes": {"critres": 1.0},
	"DEX": {"dex": 2.0},
	"PhysPen": {"physpen": 1.5},
	"MagPen": {"magpen": 1.5},
}
const SUBSTAT_DESC := {
	"PhysRes": "hardens you against physical damage",
	"MagRes": "hardens you against magic",
	"CritRes": "enemy crits land less often",
	"DEX": "shreds enemy evasion so your hits stop missing",
	"PhysPen": "physical hits punch through armor (excess becomes bonus damage)",
	"MagPen": "spells punch through wards (excess becomes bonus damage)",
}


## Human-readable "what one point gives" for a substat row.
static func substat_text(attr: String) -> String:
	var scale: Dictionary = SUBSTAT_SCALE[attr]
	var stat: String = scale.keys()[0]
	return "+%.1f %s per point — %s" % [scale[stat], attr, SUBSTAT_DESC[attr]]

const ATTR_SCALE := {
	"warrior": {
		"STR": {"atk_flat": 0.9, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.4, "crit": 0.0004},
		"INT": {"atk_flat": 0.2, "crit": 0.0002, "dex": 0.06},
		"VIT": {"hp_flat": 7.0, "physres": 0.4, "magres": 0.3, "critres": 0.2},
	},
	"archer": {
		"STR": {"atk_flat": 0.4, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.9, "crit": 0.0008},
		"INT": {"atk_flat": 0.2, "crit": 0.0002, "dex": 0.06},
		"VIT": {"hp_flat": 5.0, "physres": 0.3, "magres": 0.25, "critres": 0.15},
	},
	"mage": {
		"STR": {"atk_flat": 0.2, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.3, "crit": 0.0004},
		"INT": {"atk_flat": 0.9, "crit": 0.0006, "dex": 0.15},
		"VIT": {"hp_flat": 5.0, "physres": 0.3, "magres": 0.25, "critres": 0.15},
	},
	"assassin": {
		"STR": {"atk_flat": 0.4, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.9, "crit": 0.0008},
		"INT": {"atk_flat": 0.2, "crit": 0.0002, "dex": 0.06},
		"VIT": {"hp_flat": 5.0, "physres": 0.3, "magres": 0.25, "critres": 0.15},
	},
	# STR/INT hybrid: STR is still the primary, but INT converts to real
	# power too (faith fuels the hammer) — unique among the melee classes.
	"paladin": {
		"STR": {"atk_flat": 0.9, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.3, "crit": 0.0004},
		"INT": {"atk_flat": 0.6, "crit": 0.0004, "dex": 0.1},
		"VIT": {"hp_flat": 6.0, "physres": 0.4, "magres": 0.3, "critres": 0.2},
	},
	# VIT is worth more to a warlock than to other casters — HP is a
	# spendable resource (Dark Pact).
	"warlock": {
		"STR": {"atk_flat": 0.2, "hp_flat": 1.2},
		"AGI": {"atk_flat": 0.3, "crit": 0.0004},
		"INT": {"atk_flat": 0.9, "crit": 0.0006, "dex": 0.15},
		"VIT": {"hp_flat": 6.0, "physres": 0.3, "magres": 0.3, "critres": 0.2},
	},
}


## Plain-language description of what an attribute does for this class
## (for stat hover tooltips — teaches players what to invest in).
static func attr_help(cls: String, attr: String) -> String:
	var scale: Dictionary = ATTR_SCALE[cls].get(attr, {})
	var bits: Array = []
	var atk_v: float = scale.get("atk_flat", 0.0)
	if atk_v >= 0.8:  # primaries convert at 0.9 (2026-07-06: sub-1 by design)
		bits.append("greatly increases your ATK")
	elif atk_v >= 0.3:
		bits.append("slightly increases your ATK")
	elif atk_v > 0.0:
		bits.append("barely increases your ATK")
	if scale.has("crit"):
		bits.append("adds a little crit chance")
	if scale.has("eva"):
		bits.append("adds a little evasion")
	var hp_v: float = scale.get("hp_flat", 0.0)
	if hp_v >= 5.0:
		bits.append("adds solid health")
	elif hp_v > 0.0:
		bits.append("adds a little health")
	if scale.has("dex"):
		bits.append("adds a little DEX (accuracy)")
	if scale.has("mp_flat"):
		bits.append("expands your mana pool")
	if scale.has("magres"):
		bits.append("hardens you against magic")
	if scale.has("physres"):
		bits.append("hardens you against physical damage")
	if scale.has("critres"):
		bits.append("blunts enemy crits")
	var out := "For a %s this " % CLASSES[cls]["name"]
	out += "; ".join(bits) + "."
	if CLASSES[cls]["primary"] == attr:
		out += "\n★ This is your MAIN attribute — it also grows naturally each level."
	return out


## Human-readable "what one point gives YOUR class".
static func attr_text(cls: String, attr: String) -> String:
	var bits: Array = []
	var scale: Dictionary = ATTR_SCALE[cls].get(attr, {})
	for stat in scale:
		var v: float = scale[stat]
		match stat:
			"atk_flat": bits.append("+%.1f ATK" % v)
			"hp_flat": bits.append("+%.0f HP" % v)
			"mp_flat": bits.append("+%.1f MP" % v)
			"crit": bits.append("+%.2f%% crit" % (v * 100))
			"eva": bits.append("+%.2f%% evasion" % (v * 100))
			"physres": bits.append("+%.1f PhysRes" % v)
			"magres": bits.append("+%.1f MagRes" % v)
	return ", ".join(bits) + " per point"


# ------------------------------------------------- per-ability variants ---
# A theme is an identity; what it DOES is unique to each ability.
# Every (ability, theme) pair has its own entry: a hand-tuned fx package
# and often a "behavior" key the ability code branches on. Rider keys
# (dot/slow/echo/heal/...) are applied generically by Player.hit_enemy;
# behavior keys (bloom/knives/quake/meteors/...) are read by the ability
# implementations in player.gd.
const ABILITY_THEMES := {
	"warrior": {
		"a1": {
			"fury": {"desc": "Cleave twice — a second backhand swing follows at 60% damage.",
				"fx": {"wave2": 1, "crit_bonus": 0.10}},
			"bulwark": {"desc": "Fight behind the shield: every enemy struck mends you and hardens your guard.",
				"fx": {"heal": 0.025, "guard_buff": 70.0}},
			"earth": {"desc": "Slam the ground: a stone shockwave rolls down the lane, staggering everything it runs through.",
				"fx": {"quake": 1, "slow": 0.30, "stun_chance": 0.25}},
		},
		"a2": {
			"fury": {"desc": "Reckless charge: 40% further and 30% harder — momentum is the weapon.",
				"fx": {"dash_mult": 1.4, "dmg_mult": 1.3, "crit_bonus": 0.10}},
			"bulwark": {"desc": "Shield high: charge THROUGH the danger — even a near pass clips them, and every enemy rammed heals you and fortifies your guard.",
				"fx": {"heal": 0.03, "guard_buff": 90.0, "graze_heal": 1}},
			"earth": {"desc": "The charge ends in a ground-shattering slam that stuns everything around the impact.",
				"fx": {"end_slam": 1, "slow": 0.30}},
		},
		"a3": {
			"fury": {"desc": "A wider, bloodier cyclone whose hits strike again and again.",
				"fx": {"radius_mult": 1.5, "echo": 0.55}},
			"bulwark": {"desc": "Spin behind the shield: every hit mends you, every cast hardens you.",
				"fx": {"heal": 0.02, "guard_buff": 80.0}},
			"earth": {"desc": "The spin drags enemies INTO you and staggers them — set up the kill.",
				"fx": {"pull": 1, "stun_chance": 0.30, "slow": 0.30}},
		},
		"ult": {
			"fury": {"desc": "Deeper rage: +55% damage, and it burns for 10 seconds.",
				"fx": {"berserk_dmg": 0.55, "berserk_dur": 10.0}},
			"bulwark": {"desc": "Juggernaut: the rage heals 25% HP on cast and armors you while it lasts.",
				"fx": {"berserk_heal": 0.25, "berserk_guard": 100.0}},
			"earth": {"desc": "Your roar is seismic: enemies around you are STUNNED 2s when you awaken.",
				"fx": {"awaken_slam": 1}},
		},
	},
	"archer": {
		"a1": {
			"storm": {"desc": "The arrow forks with lightning, leaping to a second enemy and splashing wide — on lone prey the charge arcs BACK for a second strike.",
				"fx": {"ric": 1, "splash": 0.45, "ric_back": 0.50}},
			"venom": {"desc": "Dipped arrowheads bite 15% deeper, and drip a heavy venom DoT that STACKS with every hit, plus a lingering slow.",
				"fx": {"dmg_mult": 1.15, "dot": 0.65, "slow": 0.30, "toxin": 1}},
			"hunt": {"desc": "Aim for the gaps: shots bite 20% deeper, +25% crit, and can EXPOSE the prey.",
				"fx": {"dmg_mult": 1.2, "crit_bonus": 0.25, "vuln": 0.25}},
		},
		"a2": {
			"storm": {"desc": "Five charged arrows that PIERCE everything, splashing lightning on each hit.",
				"fx": {"pierce": 1, "splash": 0.55}},
			"venom": {"desc": "THREE heavy toxin arrows in a tight fan, punching through up to three bodies each — every wound drips a brutal, STACKING DoT.",
				"fx": {"knives": 3, "spread": 0.10, "dmg_mult": 1.7, "pierce": 1, "pierce_cap": 3, "dot": 0.50, "slow": 0.25, "toxin": 1}},
			"hunt": {"desc": "The whole volley converges on a single point, 20% heavier — one target eats all five.",
				"fx": {"narrow": 1, "dmg_mult": 1.2, "crit_bonus": 0.15, "vuln": 0.30}},
		},
		"a3": {
			"storm": {"desc": "Discharge a lightning burst where you leave — punish anything chasing you.",
				"fx": {"burst_origin": 0.9}},
			"venom": {"desc": "Drop a toxin cloud behind you that poisons everything inside.",
				"fx": {"mist_origin": 1}},
			"hunt": {"desc": "Reposition and line it up: your NEXT hit is a guaranteed crit.",
				"fx": {"next_crit": 1}},
		},
		"ult": {
			"storm": {"desc": "The rain crackles: every arrow splashes lightning wide around its mark.",
				"fx": {"splash": 0.75, "echo": 0.30}},
			"venom": {"desc": "A plague rain: everything struck rots and slows, arrow after arrow deepening the toxin.",
				"fx": {"dot": 0.65, "slow": 0.30, "toxin": 1}},
			"hunt": {"desc": "Every arrow hunts YOUR target — one prey, total focus, exposed to the bone.",
				"fx": {"focus": 1, "vuln": 0.40, "crit_bonus": 0.15}},
		},
	},
	"mage": {
		"a1": {
			"fire": {"desc": "Explosive bolt: splashes on impact and leaves a DEEP burn on what survives.",
				"fx": {"splash": 0.45, "dot": 0.60}},
			"ice": {"desc": "An ice lance that PIERCES the whole line, freezing everything it runs through — repeated cold turns armor BRITTLE.",
				"fx": {"pierce": 1, "slow": 0.55, "stun_chance": 0.15, "proj_speed": 0.75, "brittle": 1}},
			"wind": {"desc": "Split the bolt: TWO smaller bolts that flurry with echoing hits and burst in cutting gusts.",
				"fx": {"twin": 1, "echo": 0.20, "splash": 0.05}},
		},
		"a2": {
			"fire": {"desc": "Flame ring: a wider, burning detonation — it ignites instead of shoving.",
				"fx": {"radius_mult": 1.4, "dot": 0.45, "no_knock": 1}},
			"ice": {"desc": "Deep freeze: the blast can freeze solid what it doesn't kill, and leaves everything BRITTLE.",
				"fx": {"stun_chance": 0.35, "slow": 0.60, "brittle": 1}},
			"wind": {"desc": "Gale burst: BLAST everything away and ride the updraft out (+move speed). Bosses hold their ground — space with your feet, not by shoving.",
				"fx": {"speed_buff": 0.35}},
		},
		"a3": {
			"fire": {"desc": "Burn the path: everything you pass through is left on fire.",
				"fx": {"dot": 0.50}},
			"ice": {"desc": "Frostwalk: everything you pass through is frozen mid-step and turned BRITTLE.",
				"fx": {"freeze_path": 0.7, "slow": 0.50, "brittle": 1}},
			"wind": {"desc": "Slipstream: blink 40% further and leave with a burst of speed.",
				"fx": {"dash_mult": 1.4, "speed_buff": 0.35}},
		},
		"ult": {
			"fire": {"desc": "A dying sun: a wider crater and a far heavier, longer burn.",
				"fx": {"radius_mult": 1.4, "burn_mult": 2.0}},
			"ice": {"desc": "Glacial comet: the impact FREEZES the whole field solid for 1.2s and cracks it BRITTLE.",
				"fx": {"freeze": 1.2, "slow": 0.50, "brittle": 1}},
			"wind": {"desc": "Starfall: THREE comets fall in sequence on your lowest-health target — each successive hit on the same target lands weaker, but if it DIES the next comet snaps to a fresh priority at FULL power (execute and cascade). A TAILWIND follows for 5s: Blink and Frost Nova cool down 25% quicker. Bursts less than the Meteor and won't burn a pack — it focuses the kill.",
				"fx": {"meteors": 3, "dmg_mult": 0.6, "stack_falloff": 0.40, "haste_cdr": 0.25, "haste_dur": 5.0}},
		},
	},
	"assassin": {
		"a1": {
			"poison": {"desc": "Coated steel: every stab drips venom and slows the prey — fast cuts STACK the toxin deep.",
				"fx": {"dot": 0.35, "slow": 0.30, "toxin": 1}},
			"shadow": {"desc": "Strike from the dark: +20% crit, and stunned or slowed prey ALWAYS crits.",
				"fx": {"crit_bonus": 0.20, "opportunist": 1}},
			"blood": {"desc": "Rend: cuts strike again, and bite harder the deeper YOU bleed.",
				"fx": {"echo": 0.35, "blood_amp": 0.4}},
		},
		"a2": {
			"poison": {"desc": "A toxic wake: the dash line blooms into a poison mist behind you.",
				"fx": {"trail_mist": 1, "slow": 0.30}},
			"shadow": {"desc": "Phantom step: dash further — and a kill refunds most of the cooldown.",
				"fx": {"dash_mult": 1.35, "kill_refund": 0.7, "crit_bonus": 0.10}},
			"blood": {"desc": "Exsanguinate: cuts strike twice, and bite harder the deeper you bleed.",
				"fx": {"echo": 0.35, "blood_amp": 0.4}},
		},
		"a3": {
			"poison": {"desc": "ONE heavy venom blade that detonates into an expanding toxin cloud.",
				"fx": {"bloom": 1, "dmg_mult": 1.4, "bloom_dps": 0.32}},
			"shadow": {"desc": "FIVE blades in a tight converging arc, all hungry for weak points.",
				"fx": {"knives": 5, "spread": 0.15, "crit_bonus": 0.15}},
			"blood": {"desc": "Scarlet rend: the fan strikes again, and bites harder the deeper you bleed.",
				"fx": {"echo": 0.22, "blood_amp": 0.4}},
		},
		"ult": {
			"poison": {"desc": "The mark rots: injects a massive 5s venom that eats the target alive.",
				"fx": {"mark_dot": 0.6}},
			"shadow": {"desc": "Executioner: if the execution leaves them under 30% HP, a TRUE-damage finisher lands.",
				"fx": {"execute": 2.0}},
			"blood": {"desc": "Crimson rite: the execution bites up to 80% harder the deeper you bleed.",
				"fx": {"blood_amp": 0.8}},
		},
	},
	"paladin": {
		"a1": {
			"holy": {"desc": "Every righteous blow mends you and sears the target with radiance.",
				"fx": {"heal": 0.02, "dot": 0.30}},
			"aegis": {"desc": "Strike with the shield edge: blows stagger and harden your guard.",
				"fx": {"stun_chance": 0.20, "guard_buff": 60.0}},
			"wrath": {"desc": "Judgment falls TWICE — a burning backswing follows at 60% damage, and both hunt the gaps (+20% crit).",
				"fx": {"wave2": 1, "crit_bonus": 0.20}},
		},
		"a2": {
			"holy": {"desc": "Hallowed ground that trades fire for mending: every foe inside heals you deeply.",
				"fx": {"radius_mult": 1.1, "dmg_mult": 0.7, "heal": 0.035}},
			"aegis": {"desc": "The sanctified ring is a bastion: casting grants a heavy guard and the fire staggers.",
				"fx": {"guard_buff": 100.0, "stun_chance": 0.25}},
			"wrath": {"desc": "The ground ERUPTS: the consecration burns deep, and drags enemies toward its heart.",
				"fx": {"pull": 1, "dot": 0.55}},
		},
		"a3": {
			"holy": {"desc": "Lowering the shield releases a blessing: mend 12% of your max HP.",
				"fx": {"aegis_heal": 0.12}},
			"aegis": {"desc": "An unbreakable wall: a stronger, longer guard that SHOVES attackers away.",
				"fx": {"aegis_amt": 150.0, "aegis_dur": 3.5, "aegis_knock": 1}},
			"wrath": {"desc": "Retribution: the smite on attackers strikes twice as hard and can stun.",
				"fx": {"aegis_reflect": 2.0, "stun_chance": 0.30}},
		},
		"ult": {
			"holy": {"desc": "Merciful Conviction: the Retribution swap's chains mend 6% max HP per enemy dragged in.",
				"fx": {"chain_heal": 0.06}},
			"aegis": {"desc": "Anchored Conviction: the Retribution swap's chains grant a massive guard while the verdict lands.",
				"fx": {"chain_guard": 120.0}},
			"wrath": {"desc": "Wrathful Conviction: the Retribution swap drags wider and its verdict hits +40% harder.",
				"fx": {"radius_mult": 1.4, "dmg_mult": 1.4}},
		},
	},
	"warlock": {
		"a1": {
			"curse": {"desc": "The bolt hexes: a deep withering DoT, and it can EXPOSE the target.",
				"fx": {"dot": 0.65, "vuln": 0.25}},
			"pact": {"desc": "Blood-tipped: the bolt cuts 8% deeper and feeds you.",
				"fx": {"dmg_mult": 1.08, "heal": 0.025}},
			"void": {"desc": "The bolt tears space and CRUSHES whatever is still tumbling from a shove or pull — no lingering rot, all BURST. The crush-crit spike is the payoff for choreographing displacement.",
				"fx": {"slow": 0.40, "crush": 1}},
		},
		"a2": {
			"curse": {"desc": "Deeper rot: death-detonations, and the curse withers its PRIME victim hardest.",
				"fx": {"dot": 0.25, "hex_boom": 0.3}},
			"pact": {"desc": "Leeching curse: every cursed enemy's death mends 8% of your max HP.",
				"fx": {"hex_heal": 0.08}},
			"void": {"desc": "The curse bends space: cursed enemies are wrenched off-balance and SLOWED to a crawl — your bolts CRUSH them mid-stumble.",
				"fx": {"slow": 0.50, "slow_dur": 3.0, "shove": 260.0}},
		},
		"a3": {
			"curse": {"desc": "The blood is poisoned: the blast withers and EXPOSES everything it touches.",
				"fx": {"dot": 0.50, "vuln": 0.20}},
			"pact": {"desc": "A deeper cut: sacrifice 18% instead — hit FAR harder, drink far deeper.",
				"fx": {"pact_cost": 0.18, "dmg_mult": 3.5, "pact_ls": 0.25}},
			"void": {"desc": "The pact collapses space OUTWARD: enemies are hurled away and slowed — and your next spells CRUSH them mid-tumble.",
				"fx": {"knock": 340.0, "slow": 0.35, "crush": 1}},
		},
		"ult": {
			"curse": {"desc": "The rift leaves everything it touches EXPOSED and rotting.",
				"fx": {"vuln": 0.35, "dot": 0.25}},
			"pact": {"desc": "The rift feeds its master: every enemy caught in the burst mends 8% max HP.",
				"fx": {"rift_heal": 0.08}},
			"void": {"desc": "A greedy singularity, dragging far harder — and the burst CRUSHES everything still caught in the pull.",
				"fx": {"hard_pull": 1, "crush": 1}},
		},
	},
}


## The fx package an ability actually casts with under a theme:
## the hand-tuned per-ability variant, falling back to the theme's base.
static func ability_fx(cls_id: String, slot: String, theme_id: String) -> Dictionary:
	var per_cls: Dictionary = ABILITY_THEMES.get(cls_id, {})
	var per_slot: Dictionary = per_cls.get(slot, {})
	if per_slot.has(theme_id):
		return per_slot[theme_id].get("fx", {})
	return theme_by_id(cls_id, theme_id).get("fx", {})


## What this theme does to THIS ability, in words.
static func variant_desc(cls_id: String, slot: String, theme_id: String) -> String:
	var per_cls: Dictionary = ABILITY_THEMES.get(cls_id, {})
	var per_slot: Dictionary = per_cls.get(slot, {})
	if per_slot.has(theme_id):
		return per_slot[theme_id].get("desc", "")
	return theme_by_id(cls_id, theme_id).get("desc", "")


static func ability(cls: String, slot: String) -> Dictionary:
	return CLASSES[cls]["abilities"][slot]


static func theme_by_id(cls: String, id: String) -> Dictionary:
	for theme in THEMES[cls]:
		if theme["id"] == id:
			return theme
	return {}


## Human-readable summary of what a theme's fx modifiers do. `cls` flavors
## the toxin ENFEEBLE line (assassin evasion vs archer damage cushion).
static func fx_text(fx: Dictionary, cls := "") -> String:
	var bits: Array = []
	if fx.has("dot"):
		bits.append("applies a DoT: %d%% ATK/s for 3s (ticks can CRIT)" % int(fx["dot"] * 100))
	if fx.has("toxin"):
		var tox := "the DoT STACKS: +%d%% tick per application (up to %d stacks)" \
			% [int(Balance.TOXIN_PER_STACK * 100), Balance.TOXIN_MAX_STACKS]
		if cls == "assassin":
			tox += " — and while your toxin holds you SLIP the venomed foe's blows (up to +%d%% evasion)" % int(Balance.ENFEEBLE_ASSASSIN_EVA * 100)
		elif cls == "archer":
			tox += " — and while your toxin holds the venomed foe's blows land SOFTER (up to %d%% less damage)" % int(Balance.ENFEEBLE_ARCHER_DR * 100)
		bits.append(tox)
	if fx.has("brittle"):
		bits.append("turns targets BRITTLE: ice hits bite +%d%% per stack (up to %d)"
			% [int(Balance.BRITTLE_PER_STACK * 100), Balance.BRITTLE_MAX_STACKS])
	if fx.has("crush"):
		bits.append("CRUSHES: +%d%% damage to targets recently shoved or pulled"
			% int(Balance.CRUSH_MULT * 100))
	if fx.has("slow"):
		bits.append("slows enemies %d%% for 2s (CC-immune bosses are HOBBLED instead: +%d%% damage taken for %.1fs)"
			% [int(fx["slow"] * 100), int(Balance.HOBBLE_MULT * 100), Balance.HOBBLE_DUR])
	if fx.has("stun_chance"):
		bits.append("%d%% chance to STUN 0.5s (CC-immune bosses take CONCUSSION damage instead)" % int(fx["stun_chance"] * 100))
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
