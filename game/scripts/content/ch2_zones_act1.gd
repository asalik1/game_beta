## (T2) Chapter 2, Act 1 — four zones east of Maren's camp, the leading
## edge of the Waking. Fresh shard-bearers arrive at ~Lv 1; the act
## carries them to ~Lv 8-10 (T3's Act 2 continues from there).
##
## Honors the T5 arc contract: clearing the Greyrun Mills sets
## "blight_scouted" (Accord arc / Aldric's gate); the fallen courier in
## the Mills yields "relic_recovered" (Cinderborn arc). Widow Sera's
## blue-door mill (T1's hook) stands in zone 1.
##
## T4's bosses appear scaled for act pacing via "boss_level":
## Stormwarden ends the beastkin push (zone 2), the Choir Mother ends
## the act (zone 4).

const CHAPTER_ZONES := {
	"ch2": [
		{
			"name": "The Greyrun Mills", "terrain": "bog", "ground": "bogsoil", "path": "dirt",
			"obstacles": ["tree_teal", "deadtree", "rock"], "obstacle_count": 13,
			"decor": ["mushroom", "bones", "pebble"],
			"merchant": [660, 560],
			"enemies": [
				["blightwolf", 300, 180], ["blightwolf", 420, 540], ["blightwolf", 560, 320],
				["bogspider", 520, 600], ["bogspider", 700, 160], ["bogspider", 830, 470],
				["beastkin_raider", 900, 300], ["blightwolf", 980, 550],
			],
			"boss": "",
			"clear_flag": "blight_scouted",
			"gate_flag": "blight_scouted",  # clearing opens the road on
			"npcs": [
				{"sprite": "villager", "x": 1240, "y": 200, "prompt": "E — The Mill", "convo": "ch2_mill"},
				{"sprite": "bones", "x": 1150, "y": 560, "prompt": "E — A Fallen Courier", "convo": "ch2_courier"},
			],
		},
		{
			"name": "The Howling Fields", "terrain": "storm", "ground": "stormgrass", "path": "dirt",
			"obstacles": ["tree_green", "rock", "rock"], "obstacle_count": 10,
			"decor": ["flower", "pebble", "bones"],
			"merchant": [540, 170],
			"enemies": [
				["beastkin_raider", 320, 200], ["beastkin_raider", 450, 520], ["beastkin_raider", 600, 340],
				["beastkin_howler", 700, 150], ["beastkin_howler", 860, 480],
				["blightwolf", 540, 610], ["blightwolf", 780, 300], ["beastkin_raider", 950, 560],
			],
			"boss": "stormwarden",
			"boss_level": 8,
		},
		{
			"name": "The Sporewood", "terrain": "spore", "ground": "sporesoil", "path": "dirt",
			"obstacles": ["tree_spore", "tree_spore", "rock"], "obstacle_count": 14,
			"decor": ["mushroom", "mushroom", "bones"],
			"merchant": [700, 540],
			"enemies": [
				["sporeshambler", 300, 250], ["sporeshambler", 460, 520], ["sporeshambler", 640, 180],
				["bogspider", 560, 600], ["bogspider", 760, 350],
				["stormcult", 820, 550], ["stormcult", 920, 200], ["sporeshambler", 990, 420],
			],
			"boss": "",
			"clear_flag": "sporewood_cleared",
			"gate_flag": "sporewood_cleared",
		},
		{
			"name": "Choir's Hollow", "terrain": "graveyard", "ground": "gravedirt", "path": "gravedirt",
			"obstacles": ["tombstone", "tombstone", "deadtree"], "obstacle_count": 15,
			"decor": ["bones", "bones", "crack"],
			"merchant": [820, 300],
			"enemies": [
				["zombie", 300, 220], ["zombie", 430, 540], ["zombie", 580, 330],
				["stormcult", 660, 600], ["stormcult", 780, 170],
				["sporeshambler", 850, 460], ["zombie", 940, 250], ["stormcult", 1000, 560],
			],
			"boss": "choirmother",
			"boss_level": 10,
			"clear_flag": "act1_complete",
		},
	],
}

# New Waking-era monsters. Stats are anchored at each listed level.
const ENEMIES := {
	"blightwolf": {"name": "Waking Wolf", "sprite": "wolf", "hp": 58.0, "dmg": 11.0, "speed": 165.0, "xp": 18, "gold": 6, "ranged": false, "scale": 3.2,
		"physres": 8.0, "magres": 5.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 3, "hp_g": 0.10, "dmg_g": 0.08},
	"bogspider": {"name": "Greyrun Lurker", "sprite": "spider", "hp": 50.0, "dmg": 9.0, "speed": 205.0, "xp": 20, "gold": 7, "ranged": false, "scale": 3.2,
		"physres": 0.0, "magres": 8.0, "eva": 0.14, "critres": 0.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.09, "dmg_g": 0.08},
	"beastkin_raider": {"name": "Wildfang Raider", "sprite": "beastkin", "hp": 82.0, "dmg": 13.0, "speed": 175.0, "xp": 26, "gold": 10, "ranged": false, "scale": 3.4,
		"physres": 14.0, "magres": 4.0, "eva": 0.05, "critres": 0.0, "dmg_type": "phys",
		"level": 5, "hp_g": 0.11, "dmg_g": 0.09},
	"sporeshambler": {"name": "Spore Shambler", "sprite": "zombie", "hp": 115.0, "dmg": 14.0, "speed": 115.0, "xp": 30, "gold": 11, "ranged": false, "scale": 3.5,
		"physres": 15.0, "magres": 18.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 6, "hp_g": 0.11, "dmg_g": 0.09},
	"stormcult": {"name": "Choir Cantor", "sprite": "cultist", "hp": 68.0, "dmg": 15.0, "speed": 105.0, "xp": 34, "gold": 13, "ranged": true, "scale": 3.2,
		"physres": 6.0, "magres": 22.0, "eva": 0.0, "critres": 2.0, "dmg_type": "magic",
		"level": 7, "hp_g": 0.11, "dmg_g": 0.10},
	"beastkin_howler": {"name": "Wildfang Howler", "sprite": "beastkin", "hp": 74.0, "dmg": 16.0, "speed": 150.0, "xp": 38, "gold": 14, "ranged": true, "scale": 3.3,
		"physres": 8.0, "magres": 10.0, "eva": 0.08, "critres": 0.0, "dmg_type": "magic",
		"level": 8, "hp_g": 0.11, "dmg_g": 0.10},
}

const QUESTS := {
	"stormwarden": "Break the beastkin push — bring down the STORMWARDEN",
	"choirmother": "Silence the hymn at its source — face the CHOIR MOTHER",
	"done_ch2": "Act 1 pacified. The Waking recedes east — for now. (Act 2 arrives with T3.)",
}

const CONVOS := {
	# ---- Widow Sera's mill: the blue door (hook planted in the hub).
	"ch2_mill": {"start": "d1", "nodes": {
		"d1": {"who": "Narrator",
			"text": "A mill hunches over the black water of the Greyrun. The wheel is furred with blight-moss and the walls have gone grey — but the door is blue. Still blue. Somebody sanded and repainted it every spring for twenty years, and the rot seems, for now, to be losing the argument with the paint.",
			"variants": [
				{"flag": "mill_seen", "text": "The blue door stands where it stood. You find you check on it now, the way Sera must have — one glance, every pass, to make sure the argument is still being lost.", "next": ""},
			],
			"next": "d2"},
		"d2": {"who": "Narrator", "text": "Sera asked one thing: to know whether it still stands. It does. That will matter to exactly one person in the world, which — you begin to suspect — is what mattering usually looks like.",
			"choices": [
				{"text": "Remember it for her. (The door is standing.)",
					"flags": {"mill_seen": true}, "resonance": 3.0, "next": "d3"},
			]},
		"d3": {"who": "Narrator", "text": "You fix the blue in your mind against the grey. Small honest cargo for the road back.", "next": ""},
	}},

	# ---- The fallen imperial courier: Vessa's seal (Cinderborn arc).
	"ch2_courier": {"start": "k1", "nodes": {
		"k1": {"who": "Narrator",
			"text": "Bones in a roadside ditch, picked clean and half-swallowed by bog grass. The satchel under them is imperial leather, and inside — untouched by twenty kinds of weather — a seal of office in cold white metal.",
			"variants": [
				{"flag": "courier_searched", "text": "The ditch again. The bones lie easier without their burden — or you imagine they do.", "next": ""},
			],
			"next": "k2"},
		"k2": {"who": "Narrator", "text": "History belongs to whoever holds the paperwork, someone told you.",
			"choices": [
				{"text": "Take the seal for Envoy Vessa. A commission is a commission.",
					"req_flag": "joined_cinderborn",
					"flags": {"relic_recovered": true, "courier_searched": true},
					"faction": {"cinderborn": 8}, "next": "k_take"},
				{"text": "Pocket the seal. SOMEONE will pay well for what this unlocks.",
					"req_not_flag": "joined_cinderborn", "resonance": -3.0,
					"flags": {"relic_recovered": true, "courier_searched": true}, "next": "k_take"},
				{"text": "Leave him his last duty. Pile a few stones over the bones instead.",
					"resonance": 4.0, "flags": {"courier_searched": true},
					"faction": {"cinderborn": -3}, "next": "k_bury"},
			]},
		"k_take": {"who": "Narrator", "text": "The seal is heavier than metal has any right to be. Paperwork usually is.", "next": ""},
		"k_bury": {"who": "Narrator", "text": "The cairn is small and crooked and will outlast the argument about crowns. Somewhere, an empire's ledger stays unbalanced, and the bog does not care.", "next": ""},
	}},
}
