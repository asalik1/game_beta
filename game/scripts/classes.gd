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


# ---------------------------------------------------------- attributes ---
# Each level grants 5 attribute points. What a point gives depends on
# the CLASS (scaling ratios): an assassin converts AGI into power at
# triple the rate of STR; a warrior is the reverse.
# Balance sketch (per point, primary attr): +1.2 ATK ≈ +8% of a level's
# natural growth, so a full level of points (5) into the primary roughly
# equals +1.5 levels of raw attack — meaningful but not explosive.
const ATTR_NAMES := ["STR", "AGI", "INT", "VIT"]

const ATTR_SCALE := {
	"warrior": {
		"STR": {"atk_flat": 1.2, "hp_flat": 2.0},
		"AGI": {"atk_flat": 0.4, "eva": 0.0006},
		"INT": {"mp_flat": 1.5, "magres": 0.5},
		"VIT": {"hp_flat": 7.0, "physres": 0.4},
	},
	"archer": {
		"STR": {"atk_flat": 0.4, "hp_flat": 2.0},
		"AGI": {"atk_flat": 1.2, "crit": 0.0008},
		"INT": {"mp_flat": 1.5, "magres": 0.4},
		"VIT": {"hp_flat": 5.0, "physres": 0.3},
	},
	"mage": {
		"STR": {"atk_flat": 0.2, "hp_flat": 2.0},
		"AGI": {"atk_flat": 0.3, "eva": 0.0005},
		"INT": {"atk_flat": 1.2, "mp_flat": 3.0},
		"VIT": {"hp_flat": 5.0, "physres": 0.3},
	},
	"assassin": {
		"STR": {"atk_flat": 0.4, "hp_flat": 2.0},
		"AGI": {"atk_flat": 1.2, "crit": 0.0007, "eva": 0.0004},
		"INT": {"mp_flat": 1.5, "magres": 0.4},
		"VIT": {"hp_flat": 5.0, "physres": 0.3},
	},
}


## Plain-language description of what an attribute does for this class
## (for stat hover tooltips — teaches players what to invest in).
static func attr_help(cls: String, attr: String) -> String:
	var scale: Dictionary = ATTR_SCALE[cls].get(attr, {})
	var bits: Array = []
	var atk_v: float = scale.get("atk_flat", 0.0)
	if atk_v >= 1.0:
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
	if scale.has("mp_flat"):
		bits.append("expands your mana pool")
	if scale.has("magres"):
		bits.append("hardens you against magic")
	if scale.has("physres"):
		bits.append("hardens you against physical damage")
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
			"bulwark": {"desc": "Shield high: every enemy rammed heals you and fortifies your guard.",
				"fx": {"heal": 0.03, "guard_buff": 90.0}},
			"earth": {"desc": "The charge ends in a ground-shattering slam that stuns everything around the impact.",
				"fx": {"end_slam": 1, "slow": 0.30}},
		},
		"a3": {
			"fury": {"desc": "A wider, bloodier cyclone whose hits strike again.",
				"fx": {"radius_mult": 1.35, "echo": 0.40}},
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
			"storm": {"desc": "The arrow forks with lightning, leaping to a second enemy.",
				"fx": {"ric": 1, "splash": 0.20}},
			"venom": {"desc": "Dipped arrowheads: a heavy venom DoT and a lingering slow.",
				"fx": {"dot": 0.45, "slow": 0.30}},
			"hunt": {"desc": "Aim for the gaps: +20% crit, and shots can EXPOSE the prey.",
				"fx": {"crit_bonus": 0.20, "vuln": 0.25}},
		},
		"a2": {
			"storm": {"desc": "Five charged arrows that PIERCE everything, splashing lightning on each hit.",
				"fx": {"pierce": 1, "splash": 0.30}},
			"venom": {"desc": "THREE heavy toxin arrows in a tight fan — each drips a brutal DoT.",
				"fx": {"knives": 3, "spread": 0.10, "dmg_mult": 1.5, "dot": 0.50, "slow": 0.25}},
			"hunt": {"desc": "The whole volley converges on a single point — one target eats all five.",
				"fx": {"narrow": 1, "crit_bonus": 0.15, "vuln": 0.30}},
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
			"storm": {"desc": "The rain crackles: every arrow splashes lightning around its mark.",
				"fx": {"splash": 0.50, "echo": 0.30}},
			"venom": {"desc": "A plague rain: everything struck rots and slows.",
				"fx": {"dot": 0.50, "slow": 0.30}},
			"hunt": {"desc": "Every arrow hunts YOUR target — one prey, total focus, exposed to the bone.",
				"fx": {"focus": 1, "vuln": 0.40, "crit_bonus": 0.15}},
		},
	},
	"mage": {
		"a1": {
			"fire": {"desc": "Explosive bolt: splashes on impact and ignites what survives.",
				"fx": {"splash": 0.45, "dot": 0.35}},
			"ice": {"desc": "An ice lance that PIERCES the whole line, freezing everything it runs through.",
				"fx": {"pierce": 1, "slow": 0.55, "stun_chance": 0.15, "proj_speed": 0.75}},
			"wind": {"desc": "Split the bolt: TWO smaller bolts that flurry with echoing hits.",
				"fx": {"twin": 1, "echo": 0.35}},
		},
		"a2": {
			"fire": {"desc": "Flame ring: a wider, burning detonation — it ignites instead of shoving.",
				"fx": {"radius_mult": 1.4, "dot": 0.45, "no_knock": 1}},
			"ice": {"desc": "Deep freeze: the blast can freeze solid what it doesn't kill.",
				"fx": {"stun_chance": 0.35, "slow": 0.60}},
			"wind": {"desc": "Implosion: drag everything INTO you, then ride the updraft out (+move speed).",
				"fx": {"pull": 1, "speed_buff": 0.35}},
		},
		"a3": {
			"fire": {"desc": "Burn the path: everything you pass through is left on fire.",
				"fx": {"dot": 0.50}},
			"ice": {"desc": "Frostwalk: everything you pass through is frozen mid-step.",
				"fx": {"freeze_path": 0.7, "slow": 0.50}},
			"wind": {"desc": "Slipstream: blink 40% further and leave with a burst of speed.",
				"fx": {"dash_mult": 1.4, "speed_buff": 0.35}},
		},
		"ult": {
			"fire": {"desc": "A dying sun: a wider crater and a heavier, longer burn.",
				"fx": {"radius_mult": 1.4, "burn_mult": 1.6}},
			"ice": {"desc": "Glacial comet: the impact FREEZES the whole field solid for 1.2s.",
				"fx": {"freeze": 1.2, "slow": 0.50}},
			"wind": {"desc": "Starfall: THREE comets rain down across three different targets.",
				"fx": {"meteors": 3, "dmg_mult": 0.6}},
		},
	},
	"assassin": {
		"a1": {
			"poison": {"desc": "Coated steel: every stab drips venom and slows the prey.",
				"fx": {"dot": 0.35, "slow": 0.30}},
			"shadow": {"desc": "Strike from the dark: +15% crit, and stunned or slowed prey ALWAYS crits.",
				"fx": {"crit_bonus": 0.15, "opportunist": 1}},
			"blood": {"desc": "Rend: hits strike again and feed you.",
				"fx": {"echo": 0.45, "heal": 0.02}},
		},
		"a2": {
			"poison": {"desc": "A toxic wake: the dash line blooms into a poison mist behind you.",
				"fx": {"trail_mist": 1, "slow": 0.30}},
			"shadow": {"desc": "Phantom step: dash further — and a kill refunds most of the cooldown.",
				"fx": {"dash_mult": 1.35, "kill_refund": 0.7, "crit_bonus": 0.10}},
			"blood": {"desc": "Exsanguinate: every enemy cut feeds you, and cuts strike twice.",
				"fx": {"heal": 0.03, "echo": 0.35}},
		},
		"a3": {
			"poison": {"desc": "ONE heavy venom blade that detonates into an expanding toxin cloud.",
				"fx": {"bloom": 1, "dmg_mult": 1.4}},
			"shadow": {"desc": "FIVE blades in a wide arc, all hungry for weak points.",
				"fx": {"knives": 5, "spread": 0.22, "crit_bonus": 0.15}},
			"blood": {"desc": "Scarlet fan: the blades PIERCE, and every wound feeds you.",
				"fx": {"pierce": 1, "heal": 0.02, "echo": 0.30}},
		},
		"ult": {
			"poison": {"desc": "The mark rots: injects a massive 5s venom that eats the target alive.",
				"fx": {"mark_dot": 0.6}},
			"shadow": {"desc": "Executioner: if the flurry leaves them under 30% HP, a TRUE-damage finisher lands.",
				"fx": {"execute": 2.0}},
			"blood": {"desc": "The flurry feeds: every hit of the execution restores 6% max HP.",
				"fx": {"flurry_heal": 0.06}},
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
