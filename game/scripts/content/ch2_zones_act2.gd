## (T3) Chapter 2, Act 2 — the map opens as the Waking spreads: five
## zones across the wild terrains, ~Lv 9-16, ending at the Null Bastion
## where Warden Null (T4's construct, act-scaled) closes the chapter.

## GRAPH RETROFIT (CH2_RETROFIT_TASKS): spine indices 5-9. Same three
## changes as act 1 — explicit `type`, `lock_next` replacing the legacy
## `gate_flag`, and full-cell pack coordinates in the ch3 idiom. The
## Bastion is the final room and needs no `lock_next`.
const CHAPTER_ZONES := {
	"ch2": [
		{
			"name": "The Scorching Dunes", "terrain": "desert", "ground": "sand", "path": "sand",
			"type": "combat",
			# Melee-only by design (room banding): the crossing that teaches
			# the act-2 power step before the ranged kinds arrive.
			"enemies": [
				["duneprowler", 460, 310, 0], ["duneprowler", 600, 240, 0], ["duneprowler", 530, 440, 0],
				["sun_bleached", 1380, 870, 1], ["sun_bleached", 1500, 790, 1],
				["sun_bleached", 1760, 410, 2], ["duneprowler", 1870, 520, 2],
			],
			"boss": "",
			"clear_flag": "dunes_crossed", "lock_next": "flag:dunes_crossed",
		},
		{
			"name": "The Frozen Expanse", "terrain": "ice", "ground": "snow", "path": "snow",
			"type": "combat",
			"enemies": [
				["frost_husk", 460, 300, 0], ["frost_husk", 600, 240, 0], ["frost_husk", 530, 440, 0],
				["duneprowler", 1380, 870, 1], ["frost_husk", 1500, 800, 1],
				# Both acolytes now carry the SAME authored XP: the pair was
				# split 48 / native-70 for no stated reason, and the audit
				# was reading 70 for both (econ_audit ignored the override).
				["null_acolyte", 1760, 410, 2, 13, 48], ["null_acolyte", 1870, 520, 2, 13, 48],
			],
			"boss": "",
			"clear_flag": "expanse_crossed", "lock_next": "flag:expanse_crossed",
		},
		{
			"name": "The Crystal Deeps", "terrain": "crystal", "ground": "crystalfloor", "path": "crystalfloor",
			"type": "combat",
			"enemies": [
				["deep_stalker", 460, 310, 0, 12, 48], ["deep_stalker", 600, 240, 0, 12, 48],
				["deep_stalker", 530, 440, 0, 12, 48],
				["frost_husk", 1380, 870, 1], ["deep_stalker", 1500, 800, 1, 12, 48],
				["null_acolyte", 1760, 410, 2, 13, 48], ["null_acolyte", 1870, 520, 2, 13, 48],
			],
			"boss": "",
			"clear_flag": "deeps_mapped", "lock_next": "flag:deeps_mapped",
			"npcs": [
				{"sprite": "villager", "x": 1030, "y": 250, "prompt": "E — A Scholar", "convo": "ch2_scholar"},
			],
		},
		{
			"name": "The Sanctified Ruins", "terrain": "holy", "ground": "holystone", "path": "holystone",
			"type": "combat",
			# Ranged-heavy artillery room (room banding): the Choir's
			# successors hold the nave and shoot down the aisle.
			"enemies": [
				["null_acolyte", 460, 300, 0, 13, 55], ["null_acolyte", 600, 240, 0, 13, 55],
				["void_husk", 530, 440, 0, 15, 60],
				["null_acolyte", 1380, 870, 1, 13, 55], ["null_acolyte", 1500, 790, 1, 13, 55],
				["void_husk", 1760, 420, 2, 15, 60],
			],
			"boss": "",
			"clear_flag": "ruins_reclaimed", "lock_next": "flag:ruins_reclaimed",
		},
		{
			"name": "The Null Bastion", "terrain": "void", "ground": "voidstone", "path": "voidstone",
			"type": "boss",
			"enemies": [
				["void_husk", 460, 300, 0, 15, 60], ["void_husk", 600, 240, 0, 15, 60],
				["void_husk", 530, 440, 0, 15, 60],
				["null_acolyte", 1380, 870, 1, 13, 50], ["null_acolyte", 1500, 790, 1, 13, 50],
				["deep_stalker", 1760, 420, 2, 12, 45], ["void_husk", 1870, 520, 2, 15, 60],
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
		"level": 9, "hp_g": 0.10, "dmg_g": 0.08, "traits": ["pounce"]},
	"sun_bleached": {"name": "Sun-Bleached Husk", "sprite": "mummy", "hp": 165.0, "dmg": 22.0, "speed": 110.0, "xp": 48, "gold": 17, "ranged": false, "scale": 3.5,
		"physres": 18.0, "magres": 12.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 10, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["warded"]},
	"frost_husk": {"name": "Frost-Bound Soldier", "sprite": "skeleton_warrior", "hp": 185.0, "dmg": 24.0, "speed": 125.0, "xp": 55, "gold": 20, "ranged": false, "scale": 3.4,
		"physres": 30.0, "magres": 10.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 11, "hp_g": 0.11, "dmg_g": 0.09, "traits": ["warded", "swift"]},
	"deep_stalker": {"name": "Crystal Stalker", "sprite": "deep_stalker", "hp": 150.0, "dmg": 23.0, "speed": 215.0, "xp": 60, "gold": 22, "ranged": false, "scale": 3.4,
		"physres": 8.0, "magres": 20.0, "eva": 0.18, "critres": 0.0, "dmg_type": "phys",
		"level": 12, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["web"]},
	# Hostile-human rule (2026-07-09): null_acolyte_* = scholar_director
	# darkened/desaturated + void face (mobs never wear a friendly NPC body).
	"null_acolyte": {"name": "Null Acolyte", "sprite": "null_acolyte", "hp": 160.0, "dmg": 27.0, "speed": 110.0, "xp": 70, "gold": 26, "ranged": true, "scale": 3.3,
		"physres": 10.0, "magres": 28.0, "eva": 0.0, "critres": 3.0, "dmg_type": "magic",
		"level": 13, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["channel_heal"]},
	"void_husk": {"name": "Voidbound Husk", "sprite": "skeleton_mage", "hp": 260.0, "dmg": 30.0, "speed": 115.0, "xp": 85, "gold": 30, "ranged": false, "scale": 3.6,
		"physres": 25.0, "magres": 25.0, "eva": 0.0, "critres": 4.0, "dmg_type": "phys",
		"level": 15, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["warded", "mend"]},
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
