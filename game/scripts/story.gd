class_name Story
## All story text, zone layouts and enemy stats live here.
## Want to change the game's content or balance? This is the file.

# ---------------------------------------------------------------- enemies ---

const ENEMIES := {
	"wolf":     {"name": "Blighted Wolf",   "sprite": "wolf",     "hp": 34.0,  "dmg": 8.0,  "speed": 155.0, "xp": 12, "gold": 4,  "ranged": false, "scale": 3.0},
	"spider":   {"name": "Marsh Spider",    "sprite": "spider",   "hp": 28.0,  "dmg": 6.0,  "speed": 195.0, "xp": 14, "gold": 5,  "ranged": false, "scale": 3.0},
	"cultist":  {"name": "Blight Cultist",  "sprite": "cultist",  "hp": 40.0,  "dmg": 10.0, "speed": 90.0,  "xp": 20, "gold": 8,  "ranged": true,  "scale": 3.0},
	"skeleton": {"name": "Hollow Soldier",  "sprite": "skeleton", "hp": 62.0,  "dmg": 14.0, "speed": 120.0, "xp": 24, "gold": 10, "ranged": false, "scale": 3.0},
	# Bosses (buffed vs v1 since heroes now have gear + skill trees)
	"fangmaw":  {"name": "Fangmaw the Ravener",     "sprite": "wolf",     "hp": 460.0,  "dmg": 15.0, "speed": 130.0, "xp": 80,  "gold": 60,  "ranged": false, "scale": 6.5},
	"morwen":   {"name": "Morwen the Blightcaller", "sprite": "witch",    "hp": 620.0,  "dmg": 12.0, "speed": 105.0, "xp": 110, "gold": 90,  "ranged": true,  "scale": 5.5},
	"vargoth":  {"name": "King Vargoth the Hollow", "sprite": "king",     "hp": 1000.0, "dmg": 18.0, "speed": 115.0, "xp": 200, "gold": 150, "ranged": false, "scale": 6.5},
}

# ------------------------------------------------------------------ zones ---
# Positions are relative to the left edge of each zone.
# The playable area is roughly x 60..1570, y 70..650 (middle rows are the road).

const ZONES := [
	{
		"name": "Emberfall Village", "ground": "grass", "path": "dirt",
		"obstacles": ["tree", "rock"], "obstacle_count": 8,
		"decor": ["flower", "flower", "pebble"],
		"merchant": [820, 300],
		"enemies": [], "boss": "",
	},
	{
		"name": "The Darkwood", "ground": "forest", "path": "dirt",
		"obstacles": ["tree", "tree", "rock"], "obstacle_count": 16,
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
		"name": "The Blightmarsh", "ground": "marsh", "path": "dirt",
		"obstacles": ["deadtree", "rock"], "obstacle_count": 14,
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
		"name": "Vargoth's Keep", "ground": "stone", "path": "stone",
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
	"fangmaw":  "Slay FANGMAW in the Darkwood  (head east)",
	"morwen":   "Destroy MORWEN in the Blightmarsh  (head east)",
	"vargoth":  "Defeat KING VARGOTH in his keep  (head east)",
	"done":     "Chapter 1 complete!",
}
