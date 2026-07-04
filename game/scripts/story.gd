class_name Story
## All story text, zone layouts and enemy stats live here.
## Want to change the game's content or balance? This is the file.

# ---------------------------------------------------------------- enemies ---

# Defensive stats: physres/magres (log-curve reduction), eva (dodge
# chance, countered by DEX), critres (shaves attacker crit chance).
#
# LEVELS & GROWTH: the listed hp/dmg are the monster's stats AT its
# listed "level" (so Chapter 1 balance is unchanged). Away from that
# level they scale by the per-monster GROWTH rates — a wolf gains
# little per level while a boss gains a lot, so a high-level wolf
# is dangerous but a same-level boss dwarfs it. Cap: level 100.
const LEVEL_CAP := 100

const ENEMIES := {
	"wolf":     {"name": "Blighted Wolf",   "sprite": "wolf",     "hp": 34.0,  "dmg": 8.0,  "speed": 155.0, "xp": 12, "gold": 4,  "ranged": false, "scale": 3.0,
		"physres": 5.0,  "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.10, "dmg_g": 0.08},
	"spider":   {"name": "Marsh Spider",    "sprite": "spider",   "hp": 28.0,  "dmg": 6.0,  "speed": 195.0, "xp": 14, "gold": 5,  "ranged": false, "scale": 3.0,
		"physres": 0.0,  "magres": 5.0,  "eva": 0.12, "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.09, "dmg_g": 0.08},
	"cultist":  {"name": "Blight Cultist",  "sprite": "cultist",  "hp": 40.0,  "dmg": 10.0, "speed": 90.0,  "xp": 20, "gold": 8,  "ranged": true,  "scale": 3.0,
		"physres": 5.0,  "magres": 15.0, "eva": 0.0,  "critres": 0.0, "dmg_type": "magic",
		"level": 4, "hp_g": 0.11, "dmg_g": 0.10},
	"skeleton": {"name": "Hollow Soldier",  "sprite": "skeleton", "hp": 62.0,  "dmg": 14.0, "speed": 120.0, "xp": 24, "gold": 10, "ranged": false, "scale": 3.0,
		"physres": 25.0, "magres": 5.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 7, "hp_g": 0.12, "dmg_g": 0.10},
	"zombie":   {"name": "Risen Corpse",    "sprite": "zombie",   "hp": 45.0,  "dmg": 10.0, "speed": 95.0,  "xp": 15, "gold": 6,  "ranged": false, "scale": 3.0,
		"physres": 12.0, "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.10, "dmg_g": 0.09},
	# Bosses: strong base AND strong growth ("dragon-grade" scaling).
	"fangmaw":  {"name": "Fangmaw the Ravener",     "sprite": "direwolf", "hp": 460.0,  "dmg": 15.0, "speed": 130.0, "xp": 80,  "gold": 60,  "ranged": false, "scale": 4.8,
		"physres": 15.0, "magres": 10.0, "eva": 0.08, "critres": 2.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.14, "dmg_g": 0.11},
	"morwen":   {"name": "Morwen the Blightcaller", "sprite": "witch",    "hp": 620.0,  "dmg": 12.0, "speed": 105.0, "xp": 110, "gold": 90,  "ranged": true,  "scale": 5.5,
		"physres": 10.0, "magres": 35.0, "eva": 0.10, "critres": 3.0, "dmg_type": "magic",
		"level": 7, "hp_g": 0.14, "dmg_g": 0.11},
	"vargoth":  {"name": "King Vargoth the Hollow", "sprite": "king",     "hp": 1000.0, "dmg": 18.0, "speed": 115.0, "xp": 200, "gold": 150, "ranged": false, "scale": 6.5,
		"physres": 40.0, "magres": 25.0, "eva": 0.0,  "critres": 5.0, "dmg_type": "phys",
		"level": 10, "hp_g": 0.15, "dmg_g": 0.12},
}


## A monster's hp/dmg/xp/gold at an arbitrary level (clamped to the cap).
static func enemy_stats_at(kind: String, level: int) -> Dictionary:
	var base: Dictionary = ENEMIES[kind]
	var lvl := clampi(level, 1, LEVEL_CAP)
	var d := lvl - int(base["level"])
	var hp_m := maxf(0.25, 1.0 + d * float(base["hp_g"]))
	var dmg_m := maxf(0.3, 1.0 + d * float(base["dmg_g"]))
	var reward_m := maxf(0.3, 1.0 + d * 0.12)
	return {"level": lvl, "hp": base["hp"] * hp_m, "dmg": base["dmg"] * dmg_m,
		"xp": int(ceil(base["xp"] * reward_m)), "gold": int(ceil(base["gold"] * reward_m))}

# ------------------------------------------------------------------ zones ---
# Positions are relative to the left edge of each zone.
# The playable area is roughly x 60..1570, y 70..650 (middle rows are the road).

const ZONES := [
	{
		"name": "Emberfall Village", "terrain": "village", "ground": "grass", "path": "dirt",
		"obstacles": ["tree_green", "tree_green", "rock"], "obstacle_count": 9,
		"decor": ["flower", "flower", "pebble"],
		"merchant": [820, 300],
		"enemies": [], "boss": "",
	},
	{
		"name": "The Darkwood", "terrain": "darkwood", "ground": "forest", "path": "dirt",
		"obstacles": ["tree_autumn", "tree_autumn", "rock"], "obstacle_count": 16,
		"decor": ["mushroom", "pebble", "flower"],
		"merchant": [660, 560],
		"enemies": [
			["wolf", 320, 170], ["wolf", 430, 540], ["wolf", 560, 330],
			["wolf", 660, 130], ["wolf", 800, 480], ["wolf", 900, 300],
			["spider", 520, 600], ["spider", 740, 200],
		],
		"boss": "fangmaw",
	},
	{
		"name": "The Blightmarsh", "terrain": "marsh", "ground": "marsh", "path": "dirt",
		"obstacles": ["tree_teal", "deadtree", "rock"], "obstacle_count": 14,
		"decor": ["mushroom", "bones", "pebble"],
		"merchant": [540, 170],
		"enemies": [
			["spider", 300, 200], ["spider", 420, 520], ["spider", 610, 350],
			["spider", 760, 600], ["cultist", 500, 150], ["cultist", 700, 420],
			["cultist", 880, 250], ["wolf", 850, 520],
		],
		"boss": "morwen",
	},
	{
		"name": "Vargoth's Keep", "terrain": "keep", "ground": "stone", "path": "stone",
		"obstacles": ["pillar"], "obstacle_count": 10,
		"decor": ["bones", "crack", "bones"],
		"merchant": [700, 540],
		"enemies": [
			["skeleton", 300, 250], ["skeleton", 430, 500], ["skeleton", 570, 180],
			["skeleton", 700, 380], ["skeleton", 850, 550], ["cultist", 620, 600],
			["cultist", 800, 150],
		],
		"boss": "vargoth",
	},
]

# --------------------------------------------------------------- dialogue ---
# Each beat is a list of [speaker, line].

const BEATS := {
	"intro": [
		["Narrator", "The kingdom of Emberfall has fallen quiet. The Ember Crown - the light that kept the dark at bay - has been stolen."],
		["Narrator", "Vargoth, once a just king, was buried with honor sixty years ago. Now he walks again, hollow-eyed, and a blight spreads from his keep."],
		["Ser Aldric", "I am Aldric, last knight of the Ember Guard. If no one else will go... then I will."],
	],
	"elder": [
		["Elder Maren", "Aldric! Thank the flame you came. The wolves of the Darkwood grow bold - something twists them from within."],
		["Elder Maren", "A beast they call FANGMAW leads the pack. Slay it, and the road east will be safe again."],
		["Elder Maren", "Take these potions - press Q when your wounds are grave. And remember: keep moving. A still knight is a dead knight."],
		["Ser Aldric", "I'll return with its pelt, Elder."],
	],
	"elder_repeat": [
		["Elder Maren", "The road east awaits, Ser Aldric. May the flame keep you."],
	],
	"pre_fangmaw": [
		["Narrator", "A monstrous howl shakes the trees. Fangmaw has caught your scent."],
	],
	"post_fangmaw": [
		["Narrator", "Fangmaw falls. The wolves scatter into the trees, their eyes clear for the first time in months."],
		["Ser Aldric", "This rot on its fangs... no natural beast carries that. The blight of the marsh did this."],
		["Narrator", "The gate to the Blightmarsh creaks open. Your health and potions have been restored."],
	],
	"pre_morwen": [
		["Morwen", "Another little candle, come to gutter out in my marsh? The spiders will pick your bones clean, knight."],
		["Ser Aldric", "Talk less, witch."],
	],
	"post_morwen": [
		["Morwen", "You... cannot stop... what has already begun. The Hollow King... rises..."],
		["Ser Aldric", "Then I'll put him back in the ground myself."],
		["Narrator", "The witch crumbles to ash. Beyond the marsh, the towers of Vargoth's Keep pierce the grey sky. You feel restored."],
	],
	"pre_vargoth": [
		["King Vargoth", "A knight of the Ember Guard... You come for the Crown, little flame?"],
		["King Vargoth", "I wore it for sixty years. It is MINE. Come - kneel before your king."],
		["Ser Aldric", "My king died sixty years ago. You're just what's left."],
	],
	"epilogue": [
		["Narrator", "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones - still warm to the touch."],
		["Ser Aldric", "It's over. The flame returns to Emberfall."],
		["Narrator", "...But deep beneath the keep, something older stirs in its sleep. TO BE CONTINUED IN CHAPTER 2."],
	],
}

const QUESTS := {
	"talk":     "Speak with Elder Maren  (walk up to her and press E)",
	"fangmaw":  "Clear the Darkwood, then slay FANGMAW",
	"morwen":   "Purge the Blightmarsh, then destroy MORWEN",
	"vargoth":  "Cleanse the keep, then face KING VARGOTH",
	"done":     "Chapter 1 complete!",
}
