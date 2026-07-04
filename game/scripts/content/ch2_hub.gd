## (T1) Chapter 2 hub: Maren's Camp — the safe zone the Waking-era
## campaign starts in. Content module (see README.md): zone + NPCs +
## conversations, registered via one line in Story.CONTENT_MODULES.
##
## The camp sits where refugee roads cross. Maren — older now, the last
## of the old guard's keepers — finds newly-woken shard-bearers before
## the factions do. Her briefing reads the player's OPENING choice via
## the common flags (chose_virtue / chose_temptation / chose_away).

const CHAPTER_ZONES := {
	"ch2": [{
		"name": "Maren's Camp", "terrain": "village", "ground": "grass", "path": "dirt",
		"obstacles": ["tree_autumn", "tree_green", "rock"], "obstacle_count": 8,
		"decor": ["flower", "pebble", "mushroom"],
		"merchant": [820, 300],
		"enemies": [], "boss": "",
		"gate_flag": "ch2_briefed",  # the road east opens after the briefing
		"npcs": [
			{"sprite": "elder", "x": 520, "y": 330, "prompt": "E — Maren", "convo": "ch2_maren_hub"},
			{"sprite": "sentry", "x": 1150, "y": 380, "prompt": "E — Talk", "convo": "ch2_sentry"},
			{"sprite": "villager", "x": 340, "y": 500, "prompt": "E — Talk", "convo": "ch2_refugee"},
			# Faction presences (convos live in ch2_factions.gd — T5):
			{"sprite": "warden", "x": 660, "y": 200, "prompt": "E — Accord", "convo": "ch2_accord_recruit"},
			{"sprite": "envoy", "x": 950, "y": 500, "prompt": "E — Cinderborn", "convo": "ch2_cinder_recruit"},
			{"sprite": "beastkin", "x": 1290, "y": 560, "prompt": "E — The Cage", "convo": "ch2_beastkin_cage"},
			{"sprite": "villager", "x": 140, "y": 250, "prompt": "E — Pilgrim", "convo": "ch2_choir_pilgrim"},
			# The man who killed Vargoth, by his own small fire (T6):
			{"sprite": "aldric", "x": 700, "y": 600, "prompt": "E — Ser Aldric", "convo": "ch2_aldric"},
		],
	}],
}

const QUESTS := {
	"ch2_start": "Report to Elder Maren by the camp fire  (walk up to her and press E)",
	"ch2_act1":  "Take the east road — scout what the Waking has made of the land",
}

const CONVOS := {
	# ---- Maren's briefing: she already knows what you did when your
	# shard woke. Repeat visits short-circuit to a one-line send-off.
	"ch2_maren_hub": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "So. Another one the shards chose. Sit; the fire doesn't bite. Unlike most of what's left out there.",
			"variants": [
				{"flag": "ch2_briefed", "text": "East, shard-bearer. The blight will not scout itself — and the factions' recruiters move faster than you do.", "next": ""},
				{"flag": "chose_virtue", "text": "So. Another one the shards chose — and this one, they tell me, chose BACK. Good. Sit; you and I may actually get along."},
				{"flag": "chose_temptation", "text": "So. Another one the shards chose. I heard what the waking cost — and what you told yourself about it. Sit anyway. Better here than out there alone with that voice."},
				{"flag": "chose_away", "text": "So. Another one the shards chose — the kind that walks away from things. You walked HERE, at least. Sit."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "Years since Vargoth fell, and the world is not healed — it is WAKING. The crown's shards rooted in people like you. The blight never stopped crawling, the beastkin never stopped raiding, and now every power in Vaelscar wants shard-bearers on a leash.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "I find the newly-woken before the factions do. What I ask is small: eyes and honesty. What THEY will ask is everything. Any questions, or do I point you east?",
			"choices": [
				{"text": "\"Point me east. Whatever's out there, I'd rather meet it than wait for it.\"",
					"flags": {"ch2_briefed": true}, "quest": "ch2_act1", "next": "m_go"},
				{"text": "\"First — what happens to shard-bearers who lose themselves?\"",
					"resonance": 4.0, "next": "m_warn"},
				{"text": "\"Careful how you say 'leash', old woman. The shard listens.\"",
					"req_band": "tempted", "resonance": -4.0, "next": "m_dark"},
			]},
		"m_warn": {"who": "Elder Maren", "text": "They stop asking that question. That is the first sign. Keep asking it, and you will likely die yourself — which, for a shard-bearer, is the good ending. Now: east.",
			"quest": "ch2_act1",
			"next": "m_warn2"},
		"m_warn2": {"who": "Elder Maren", "text": "The road past the palisade. Walk it, note what the Waking has made of the land, and come back breathing. That is the whole of the job.",
			"next": ""},
		"m_dark": {"who": "Elder Maren", "text": "...It does listen. And it heard an old woman refuse to flinch. Remember how that's done — you will need the trick more than I will. The road east, shard-bearer.",
			"quest": "ch2_act1",
			"next": "m_dark2"},
		"m_dark2": {"who": "Elder Maren", "text": "And eat something before you go. Whatever it whispers, you are still a body that marches on bread.",
			"next": ""},
		"m_go": {"who": "Elder Maren", "text": "East it is. Past the palisade, note what the Waking has made of the land, and come back breathing. That is the whole of the job.",
			"next": ""},
	}},

	# ---- Camp sentry: the palisade watch. Reacts to your Resonance band.
	"ch2_sentry": {"start": "s1", "nodes": {
		"s1": {"who": "Sentry Piet",
			"text": "Quiet shift, thank the flame. The wolves out there sing most nights — real wolves, mind. You learn to tell the difference by the second week.",
			"variants": [
				{"band": "tempted", "text": "...You mind standing a bit further off? No offense. We had one of yours through last month with that same look, and I still dream about the fence."},
				{"band": "steady", "text": "Shard-bearer. Good — with you standing there the night feels half as long. Maren picks the decent ones, whatever the villages say."},
			],
			"next": ""},
	}},

	# ---- Refugee by the cookfire: what the blight took.
	"ch2_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Widow Sera",
			"text": "We had a mill on the Greyrun. Then the water came up black one morning, and that was that. Maren says the land can be cleaned. I say she believes it because someone has to.",
			"variants": [
				{"band": "tempted", "text": "My gran used to say the blight gets in through what you want most. ...Why are you looking at me like that, shard-bearer?"},
				{"band": "steady", "text": "You have kind eyes for someone carrying a dead king's splinter. If you get as far as the Greyrun... the mill had a blue door. I'd like to know if it's standing."},
			],
			"next": ""},
	}},
}
