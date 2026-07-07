## (T3) Chapter 2, Act 2 — the map opens as the Waking spreads: five
## zones across the wild terrains, ~Lv 9-16, ending at the Null Bastion
## where Warden Null (T4's construct, act-scaled) closes the chapter.

const CHAPTER_ZONES := {
	"ch2": [
		{
			"name": "The Scorching Dunes", "terrain": "desert", "ground": "sand", "path": "sand",
			"obstacles": ["rock", "deadtree"], "obstacle_count": 9,
			"decor": ["bones", "pebble"],
			"merchant": [820, 300],
			"enemies": [
				["duneprowler", 300, 200], ["duneprowler", 460, 540], ["duneprowler", 620, 300],
				["sun_bleached", 540, 610], ["sun_bleached", 720, 160],
				["sun_bleached", 860, 470], ["duneprowler", 960, 550],
			],
			"boss": "",
			"clear_flag": "dunes_crossed", "gate_flag": "dunes_crossed",
		},
		{
			"name": "The Frozen Expanse", "terrain": "ice", "ground": "snow", "path": "snow",
			"obstacles": ["tree_snow", "tree_snow", "rock"], "obstacle_count": 12,
			"decor": ["pebble"],
			"merchant": [660, 560],
			"enemies": [
				["frost_husk", 320, 220], ["frost_husk", 470, 530], ["frost_husk", 640, 180],
				["duneprowler", 560, 600], ["sun_bleached", 760, 340],
				["frost_husk", 880, 520], ["null_acolyte", 980, 220],
			],
			"boss": "",
			"clear_flag": "expanse_crossed", "gate_flag": "expanse_crossed",
		},
		{
			"name": "The Crystal Deeps", "terrain": "crystal", "ground": "crystalfloor", "path": "crystalfloor",
			"obstacles": ["crystal", "crystal", "pillar"], "obstacle_count": 13,
			"decor": ["pebble", "crack"],
			"merchant": [540, 170],
			"enemies": [
				["deep_stalker", 300, 250], ["deep_stalker", 450, 520], ["deep_stalker", 620, 200],
				["frost_husk", 560, 600], ["null_acolyte", 760, 350],
				["deep_stalker", 850, 550], ["null_acolyte", 950, 200],
			],
			"boss": "",
			"clear_flag": "deeps_mapped", "gate_flag": "deeps_mapped",
			"npcs": [
				{"sprite": "villager", "x": 1240, "y": 240, "prompt": "E — A Scholar", "convo": "ch2_scholar"},
			],
		},
		{
			"name": "The Sanctified Ruins", "terrain": "holy", "ground": "holystone", "path": "holystone",
			"obstacles": ["pillar", "pillar", "rock"], "obstacle_count": 11,
			"decor": ["flower", "crack"],
			"merchant": [700, 540],
			"enemies": [
				["null_acolyte", 320, 220], ["null_acolyte", 480, 540], ["void_husk", 640, 300],
				["frost_husk", 580, 610], ["null_acolyte", 780, 170],
				["void_husk", 900, 480],
			],
			"boss": "",
			"clear_flag": "ruins_reclaimed", "gate_flag": "ruins_reclaimed",
		},
		{
			"name": "The Null Bastion", "terrain": "void", "ground": "voidstone", "path": "voidstone",
			"obstacles": ["pillar", "crystal"], "obstacle_count": 10,
			"decor": ["crack", "crack"],
			"merchant": [820, 300],
			"enemies": [
				["void_husk", 300, 240], ["void_husk", 450, 530], ["void_husk", 620, 190],
				["null_acolyte", 560, 600], ["null_acolyte", 740, 340],
				["deep_stalker", 860, 520], ["void_husk", 960, 240],
			],
			"boss": "nullwarden",
			"boss_level": 16,
			"clear_flag": "act2_complete",
		},
	],
}

# Act 2 monsters (Lv 9-15, anchored at listed level).
const ENEMIES := {
	"duneprowler": {"name": "Dune Prowler", "sprite": "duneprowler", "hp": 130.0, "dmg": 20.0, "speed": 185.0, "xp": 44, "gold": 16, "ranged": false, "scale": 3.3,
		"physres": 12.0, "magres": 8.0, "eva": 0.06, "critres": 0.0, "dmg_type": "phys",
		"level": 9, "hp_g": 0.10, "dmg_g": 0.08},
	"sun_bleached": {"name": "Sun-Bleached Husk", "sprite": "mummy", "hp": 165.0, "dmg": 22.0, "speed": 110.0, "xp": 48, "gold": 17, "ranged": false, "scale": 3.5,
		"physres": 18.0, "magres": 12.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 10, "hp_g": 0.10, "dmg_g": 0.09},
	"frost_husk": {"name": "Frost-Bound Soldier", "sprite": "skeleton_warrior", "hp": 185.0, "dmg": 24.0, "speed": 125.0, "xp": 55, "gold": 20, "ranged": false, "scale": 3.4,
		"physres": 30.0, "magres": 10.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 11, "hp_g": 0.11, "dmg_g": 0.09},
	"deep_stalker": {"name": "Crystal Stalker", "sprite": "deep_stalker", "hp": 150.0, "dmg": 23.0, "speed": 215.0, "xp": 60, "gold": 22, "ranged": false, "scale": 3.4,
		"physres": 8.0, "magres": 20.0, "eva": 0.18, "critres": 0.0, "dmg_type": "phys",
		"level": 12, "hp_g": 0.10, "dmg_g": 0.09},
	"null_acolyte": {"name": "Null Acolyte", "sprite": "scholar_director", "hp": 160.0, "dmg": 27.0, "speed": 110.0, "xp": 70, "gold": 26, "ranged": true, "scale": 3.3,
		"physres": 10.0, "magres": 28.0, "eva": 0.0, "critres": 3.0, "dmg_type": "magic",
		"level": 13, "hp_g": 0.11, "dmg_g": 0.10},
	"void_husk": {"name": "Voidbound Husk", "sprite": "skeleton_mage", "hp": 260.0, "dmg": 30.0, "speed": 115.0, "xp": 85, "gold": 30, "ranged": false, "scale": 3.6,
		"physres": 25.0, "magres": 25.0, "eva": 0.0, "critres": 4.0, "dmg_type": "phys",
		"level": 15, "hp_g": 0.11, "dmg_g": 0.10},
}

const QUESTS := {
	"nullwarden": "Cross the wastes and breach the Null Bastion — end WARDEN NULL",
	"done_ch2": "The Waking is beaten back. Vaelscar breathes — and the factions start counting. Chapter 2 complete!",
}

const BEATS := {
	"pre_nullwarden": [
		["Narrator", "The Bastion's pistons wake floor by floor, like a machine remembering a grudge. Something old and iron unfolds at its heart."],
	],
	"epilogue_ch2": [
		["Narrator", "The Warden's grid goes dark. In the silence after, the Waking's edge stops advancing — the blight sulks, the storms wander off, the hymn at the world's rim loses a verse."],
		["Elder Maren", "Beaten back. Not beaten — the difference matters, so remember it. But tonight the camp sleeps without sentries doubled, and that is YOUR doing, shard-bearer."],
		["Narrator", "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing."],
	],
}

const CONVOS := {
	# ---- A chronicler camped among the crystals, counting the Waking.
	"ch2_scholar": {"start": "s1", "nodes": {
		"s1": {"who": "Scholar Ivo",
			"text": "Mind the resonance, shard-bearer — the crystals repeat what they hear, and some of what they heard down here predates manners. Ivo. Chronicler. Unaffiliated, whatever the envoy tells you.",
			"variants": [
				{"flag": "scholar_met", "text": "\"Still standing? Statistically remarkable. The Bastion is ahead — my notes, regrettably, end where they get interesting.\"", "next": ""},
				{"band": "tempted", "text": "The scholar looks up — then looks HARDER, the way one reads a difficult footnote. \"Fascinating. Yours is further along than most. Do sit AWAY from the crystals, if you please — they repeat things.\""},
				{"band": "steady", "text": "\"Ah — a quiet one. The crystals barely hum around you. That is the rarest reading I've taken all year, shard-bearer; I intend to write it down twice.\""},
			],
			"next": "s2"},
		"s2": {"who": "Scholar Ivo", "text": "Free knowledge, since you're heading east anyway: the Bastion ahead predates Vargoth — an ARMORY, from the war the Concord ended. What woke inside it is not blighted and not beastkin. It is MAINTENANCE, resumed after six hundred years, and it has decided the whole region is out of specification.",
			"choices": [
				{"text": "\"What do your notes say about killing it?\"",
					"flags": {"scholar_met": true}, "next": "s3"},
			]},
		"s3": {"who": "Scholar Ivo", "text": "\"Shed its armor before it sheds yours — it protects the frame, not the function. And when the grid stamps, DON'T be where you were standing. That sentence has cost four lives to write, so do me the courtesy of surviving it.\"", "next": ""},
	}},
}
