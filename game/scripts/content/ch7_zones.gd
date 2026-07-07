## Chapter 7 zones — The Breaking Sky (storm + void, L37-41, BOSSES.md).
## ACT 1 FINALE. Content module: 21 rooms — 13 spine (spine = [0..12])
## + 8 side. Second blended chapter: storm rooms with VOID bleeding
## through as the spine runs deeper (the sky tearing is the look AND
## the plot).
##
## THE CHAPTER: the Storm Tongue's seal — the one Korrag's old order
## was founded to tend by RECITING it, an unbroken 600-year relay of
## vow-keepers speaking the binding aloud. Cyrraeth, the last Speaker,
## stopped mid-sentence to LISTEN. Maren herself holds the summit camp;
## both joinable factions converge for the act's political climax. Kill
## Cyrraeth and no one alive knows the recitation — the seal CRACKS as
## he dies. The victory is the crisis: Act 2's inciting incident, by
## the player's own hand.
##
## XP BUDGET (30+22·lvl; enter ~L37.9 off Kaethra):
##   -> Veyx L38 (~130): opener trash ~265
##   -> Echo L39 (866, Veyx pays 600): trash ~350
##   -> Cyrraeth L41 (1798, Echo pays 640): trash ~1010
## Full-clear trash below ≈ 1620 + bosses 2040; Cyrraeth pays ~86% of
## L41->42 — Act 1 closes at ~L41.9. Needs a playtest pass.

const CHAPTER_ZONES := {
	"ch7": [
		# ---------------------------------------------------- spine ---
		{
			"name": "The Summit Camp", "terrain": "storm", "type": "safe",
			"lock_next": "flag:ch7_briefed",
			"merchant": [1050, 480], "shop_tier": "gold",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "elder", "x": 620, "y": 500, "prompt": "E — Elder Maren", "convo": "ch7_briefing"},
				{"sprite": "warden", "x": 1400, "y": 400, "prompt": "E — Accord", "convo": "ch7_accord"},
				{"sprite": "envoy", "x": 1500, "y": 760, "prompt": "E — Cinderborn", "convo": "ch7_cinder"},
				{"sprite": "sentry", "x": 800, "y": 800, "prompt": "E — The Last Apprentice", "convo": "ch7_apprentice"},
			],
		},
		{
			"name": "The Thunder Steppe", "terrain": "storm", "type": "combat",
			"enemies": [
				["storm_harrier", 480, 300, 0], ["storm_harrier", 600, 240, 0], ["storm_harrier", 540, 420, 0],
				["storm_harrier", 1300, 900, 1], ["storm_harrier", 1420, 830, 1], ["storm_harrier", 1350, 1000, 1],
				["storm_harrier", 1700, 400, 2], ["storm_harrier", 1820, 500, 2],
				["storm_harrier", 950, 620, 3], ["storm_harrier", 1080, 550, 3],
			],
			"boss": "",
		},
		{
			"name": "The Broken Weald", "terrain": "storm", "type": "combat",
			"enemies": [
				["storm_harrier", 450, 320, 0, 38], ["storm_harrier", 570, 250, 0, 38],
				["vow_sentinel", 1350, 850, 1], ["vow_sentinel", 1470, 780, 1], ["vow_sentinel", 1420, 950, 1],
				["storm_harrier", 1700, 450, 2, 38], ["storm_harrier", 1820, 560, 2, 38],
				["vow_sentinel", 1000, 950, 3], ["vow_sentinel", 1130, 880, 3],
			],
			"boss": "",
		},
		{
			"name": "The Conductor Fields", "terrain": "storm", "type": "boss",
			"lock_next": "boss",
			"enemies": [["static_caller", 700, 400, 0], ["static_caller", 830, 330, 0]],
			"boss": "stormdrake_veyx", "boss_level": 38,
		},
		{
			"name": "The Torn Downs", "terrain": "storm", "type": "combat",
			"enemies": [
				["static_caller", 480, 300, 0], ["static_caller", 600, 240, 0], ["static_caller", 540, 430, 0],
				["vow_sentinel", 1350, 880, 1], ["vow_sentinel", 1470, 800, 1],
				["static_caller", 1700, 420, 2], ["static_caller", 1820, 530, 2],
				["vow_sentinel", 1000, 620, 3], ["vow_sentinel", 1130, 550, 3],
				["storm_harrier", 950, 750, 3, 38], ["storm_harrier", 1060, 820, 3, 38],
			],
			"boss": "",
		},
		{
			"name": "The Wayhouse", "terrain": "storm", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The First Tear", "terrain": "void", "type": "combat",
			"enemies": [
				["void_shade", 450, 320, 0], ["void_shade", 570, 250, 0], ["void_shade", 510, 440, 0],
				["void_shade", 640, 350, 0], ["void_shade", 700, 260, 0],
				["static_caller", 1350, 850, 1, 39], ["static_caller", 1470, 780, 1, 39],
				["static_caller", 1420, 950, 1, 39], ["static_caller", 1540, 880, 1, 39],
				["vow_sentinel", 1750, 420, 2, 39], ["vow_sentinel", 1850, 520, 2, 39],
			],
			"boss": "",
		},
		{
			"name": "The Unnamed Aisle", "terrain": "void", "type": "boss",
			"lock_next": "boss",
			"enemies": [["void_shade", 700, 420, 0, 39], ["void_shade", 830, 350, 0, 39]],
			"boss": "unnamed_echo", "boss_level": 39,
		},
		{
			"name": "The Vowkeepers' Road", "terrain": "storm", "type": "combat",
			"enemies": [
				["vow_sentinel", 480, 300, 0, 40], ["vow_sentinel", 600, 240, 0, 40], ["vow_sentinel", 540, 430, 0, 40],
				["vow_sentinel", 660, 340, 0, 40], ["vow_sentinel", 720, 250, 0, 40],
				["static_caller", 1350, 880, 1, 40], ["static_caller", 1470, 800, 1, 40],
				["static_caller", 1410, 980, 1, 40], ["static_caller", 1530, 900, 1, 40],
				["void_shade", 1750, 420, 2, 40], ["void_shade", 1850, 530, 2, 40],
			],
			"boss": "",
		},
		{
			"name": "The Last Relay", "terrain": "storm", "type": "merchant",
			"merchant": [1050, 620], "shop_tier": "gold",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Screaming Heights", "terrain": "void", "type": "combat",
			"enemies": [
				["void_shade", 480, 300, 0, 40], ["void_shade", 600, 240, 0, 40], ["void_shade", 540, 430, 0, 40],
				["void_shade", 660, 340, 0, 40], ["void_shade", 720, 250, 0, 40],
				["static_caller", 1350, 880, 1, 40], ["static_caller", 1470, 800, 1, 40],
				["static_caller", 1410, 980, 1, 40], ["static_caller", 1530, 900, 1, 40], ["static_caller", 1590, 810, 1, 40],
				["vow_sentinel", 1000, 620, 3, 40], ["vow_sentinel", 1130, 550, 3, 40],
			],
			"boss": "",
		},
		{
			"name": "The Recitation Stair", "terrain": "storm", "type": "combat",
			"enemies": [
				["static_caller", 480, 300, 0, 40], ["static_caller", 600, 240, 0, 40], ["static_caller", 540, 430, 0, 40],
				["static_caller", 660, 340, 0, 40], ["static_caller", 720, 250, 0, 40],
				["vow_sentinel", 1350, 880, 1, 40], ["vow_sentinel", 1470, 800, 1, 40],
				["vow_sentinel", 1410, 980, 1, 40], ["vow_sentinel", 1530, 900, 1, 40],
				["void_shade", 1750, 420, 2, 40], ["void_shade", 1850, 530, 2, 40], ["void_shade", 1800, 320, 2, 40],
			],
			"boss": "",
		},
		{
			"name": "The Mouth of the Storm", "terrain": "void", "type": "boss",
			"enemies": [["vow_sentinel", 700, 420, 0, 40], ["vow_sentinel", 830, 350, 0, 40]],
			"boss": "stormmouth", "boss_level": 41,
		},
		# ----------------------------------------------- side rooms ---
		{
			"name": "Korrag's Cairn", "terrain": "storm", "type": "dead_end", "cache": "wood",
			"enemies": [["storm_harrier", 1000, 500, 0, 38], ["storm_harrier", 1150, 560, 0, 38]],
			"boss": "",
			"npcs": [{"sprite": "rock", "x": 950, "y": 320, "prompt": "E — The Cairn", "convo": "ch7_lore_cairn"}],
		},
		{
			"name": "The Vow-Stone", "terrain": "storm", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "pillar", "x": 1056, "y": 500, "prompt": "E — The Vow-Stone", "convo": "ch7_shrine_vowstone"}],
		},
		{
			"name": "The Storm-Watchers' Rest", "terrain": "storm", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Harrier Downs", "terrain": "storm", "type": "combat",
			"enemies": [
				["storm_harrier", 500, 320, 0, 38], ["storm_harrier", 620, 250, 0, 38], ["storm_harrier", 560, 440, 0, 38],
				["storm_harrier", 680, 350, 0, 38], ["storm_harrier", 740, 260, 0, 38],
				["vow_sentinel", 1350, 850, 1, 38], ["vow_sentinel", 1470, 780, 1, 38],
				["vow_sentinel", 1420, 950, 1, 38], ["vow_sentinel", 1540, 870, 1, 38],
			],
			"boss": "",
		},
		{
			"name": "The Hollow Relay", "terrain": "storm", "type": "combat",
			"enemies": [
				["static_caller", 500, 320, 0, 39], ["static_caller", 620, 250, 0, 39],
				["static_caller", 560, 440, 0, 39], ["static_caller", 680, 350, 0, 39], ["static_caller", 740, 260, 0, 39],
				["vow_sentinel", 1350, 850, 1, 39], ["vow_sentinel", 1470, 780, 1, 39],
				["vow_sentinel", 1420, 950, 1, 39], ["vow_sentinel", 1540, 870, 1, 39],
			],
			"boss": "",
		},
		{
			"name": "The Void Shelf", "terrain": "void", "type": "dead_end", "cache": "silver",
			"enemies": [],
			"boss": "",
			"npcs": [{"sprite": "crystal", "x": 950, "y": 330, "prompt": "E — Look", "convo": "ch7_lore_shelf"}],
		},
		{
			"name": "The Summit Table", "terrain": "storm", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "villager", "x": 1056, "y": 500, "prompt": "E — The Summit", "convo": "ch7_shrine_summit"}],
		},
		{
			"name": "The Erased Archive", "terrain": "void", "type": "combat",
			"enemies": [
				["void_shade", 500, 320, 0, 40], ["void_shade", 620, 250, 0, 40],
				["void_shade", 560, 440, 0, 40], ["void_shade", 680, 350, 0, 40], ["void_shade", 740, 260, 0, 40],
				["static_caller", 1350, 850, 1, 40], ["static_caller", 1470, 780, 1, 40],
				["static_caller", 1420, 950, 1, 40], ["static_caller", 1540, 870, 1, 40],
			],
			"boss": "",
		},
	],
}

# Breaking Sky monsters. HP on the gear-inclusive dps curve, dmg on the
# parity curve (in-game = base x 1.3).
const ENEMIES := {
	"storm_harrier": {"name": "Storm Harrier", "sprite": "wolf", "hp": 950.0, "dmg": 88.0, "speed": 195.0, "xp": 13, "gold": 32, "ranged": false, "scale": 3.1,
		"physres": 15.0, "magres": 25.0, "eva": 0.08, "critres": 0.0, "dmg_type": "phys",
		"level": 37, "hp_g": 0.10, "dmg_g": 0.09,
		"lore": "Plains hounds that learned to run ahead of the thunder. Lately the thunder runs ahead of THEM, and it has made them mean."},
	"vow_sentinel": {"name": "Vow Sentinel", "sprite": "royal_soldier", "hp": 1250.0, "dmg": 92.0, "speed": 130.0, "xp": 15, "gold": 34, "ranged": false, "scale": 3.4,
		"physres": 42.0, "magres": 25.0, "eva": 0.0, "critres": 3.0, "dmg_type": "phys",
		"level": 38, "hp_g": 0.11, "dmg_g": 0.09,
		"lore": "Dead keepers of the recitation relay, still walking their circuits. The vow outlived the vowing — that is either loyalty or its skeleton."},
	"static_caller": {"name": "Static Caller", "sprite": "bandit_sorcerer", "hp": 1000.0, "dmg": 96.0, "speed": 100.0, "xp": 15, "gold": 34, "ranged": true, "scale": 3.2,
		"physres": 12.0, "magres": 45.0, "eva": 0.0, "critres": 3.0, "dmg_type": "magic",
		"level": 38, "hp_g": 0.11, "dmg_g": 0.10,
		"lore": "Order zealots who followed Cyrraeth into listening. They speak in half-sentences now — the storm finishes the other half, and its grammar hurts."},
	"void_shade": {"name": "Void Shade", "sprite": "bandit_scout", "hp": 1050.0, "dmg": 100.0, "speed": 185.0, "xp": 16, "gold": 36, "ranged": false, "scale": 3.2,
		"physres": 15.0, "magres": 30.0, "eva": 0.18, "critres": 2.0, "dmg_type": "phys",
		"level": 39, "hp_g": 0.10, "dmg_g": 0.10,
		"lore": "Silhouettes out of the tear — shapes the world threw away, returned with the packaging removed. The void keeps everything. That was never a comfort."},
}

const QUESTS := {
	"ch7_start": "Report to Elder Maren at the Summit Camp  (walk up to her and press E)",
	"stormdrake_veyx": "Cross the steppe — ground VEYX, THE UNCHAINED CURRENT",
	"unnamed_echo": "Enter the tear and cut down THE ECHO OF THE UNNAMED",
	"stormmouth": "Climb the Recitation Stair — silence CYRRAETH, MOUTH OF THE STORM",
	"done_ch7": "ACT 1 COMPLETE — the seal is cracked, and the mid game begins.",
}

const BEATS := {
	"pre_stormdrake_veyx": [
		["Narrator", "The rods of the old conductor field hum like struck glass. Between them the air bunches, gathers — and stands up. It has no face and does not need one; delight, it turns out, is a shape."],
		["Veyx", "OH. Oh, a BEARER — a little jar of old king! The seal never lets anything through and then it let ME through and now there's WEATHER, and there's YOU. Six hundred years of one sentence, bearer. Let's make some noise that isn't it."],
	],
	"post_stormdrake_veyx": [
		["Narrator", "Veyx comes apart the way weather does — no death, just a dissipating, almost cheerful to the last arc. The final bolt of it grounds through a conductor rod and spells, briefly, something in the old order's script. The apprentice will tell you later what it said: 'MORE SOON.'"],
		["Narrator", "Ahead, the plains dip toward the first tear. The rain stops at its edge like a courtier at a door."],
	],
	"pre_unnamed_echo": [
		["The Echo of the Unnamed", "You walk past four hundred graves of vow-keepers and flinch at none of them — but you flinch at ME. Good. I am the one thing on these plains with no stone, no name, no line in any book. The Guard saw to that."],
		["The Echo of the Unnamed", "The void kept a copy. The void keeps EVERYTHING — that is what they sealed it for. Look at me, bearer. Someone has to be looking, this time."],
	],
	"post_unnamed_echo": [
		["Narrator", "The Echo does not scatter like the shades do. It folds, slowly, watching you the whole way down — and at the end it says a NAME. One word, in a voice suddenly human, and the void takes the sound before it reaches you. You will spend longer than you'd like wondering whose it was. That, you suspect, was the point."],
		["Narrator", "Beyond the aisle, up the last stair, a single voice recites against the thunder. It has been reciting for six hundred years, in relay. It is down to one speaker, and he has stopped saying the words in ORDER."],
	],
	"pre_stormmouth": [
		["Cyrraeth", "— and the word was not SILENCE, bearer, that's the mistranslation, six centuries of it — the word was WAIT. We were never keeping it in. We were keeping it WAITING. I stopped mid-sentence one night to hear what waited, and it has such things half-said—"],
		["Cyrraeth", "You've come to finish my sentence for me. I know. The last Speaker greets you as the relay greeted every storm: standing. Come — one of us ends the recitation tonight, and the sky is listening either way."],
	],
	"epilogue_ch7": [
		["Narrator", "Cyrraeth falls silent mid-word — and for one whole breath, nothing in the world makes any sound at all."],
		["Narrator", "Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once. Somewhere below, eleven camps and two factions look up from what they were doing, and do not look away."],
		["Elder Maren", "So. Six hundred years of the Concord's grace, spent to the last syllable — and no one alive knows the recitation now. Hear me, bearer, because I will only say this once and never as a reproach: every road that led here, you walked RIGHT. And it led here anyway. That is what the mid game of a war looks like. Rest tonight. Tomorrow we learn what a cracked seal costs."],
	],
}

const WANDERERS := {
	"ch7": [
		{"sprite": "sentry", "prompt": "E — Talk", "convo": "ch7_wander_keeper"},
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch7_wander_chaser"},
		{"sprite": "envoy", "prompt": "E — Talk", "convo": "ch7_wander_quarter"},
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch7_wander_bellringer"},
		{"sprite": "merchant", "prompt": "E — Talk", "convo": "ch7_wander_undertaker"},
	],
}

const CONVOS := {
	# ---- Maren's summit briefing: the act's political climax, and the
	# closing of the circle she opened at your recruitment. Reads the
	# act's chose_ flags — your decisions arrive here ahead of you.
	"ch7_briefing": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer. Sit — the fire's real, the summit is theater, and you and I are past theater. I've read every report out of the Vale, the Slagfields, the ice, the Deep. You've been busy being exactly what I hoped you'd be, and I've been busy being afraid of what it's adding up to.",
			"variants": [
				{"flag": "ch7_briefed", "text": "The steppe first, bearer — Veyx is loose in the conductor fields, and nothing on these plains gets quieter until it's grounded.", "next": ""},
				{"flag": "chose_kaethra_sheathed", "text": "Bearer. Sit. ...Kesh's runner reached me before you did. You put the blade AWAY, at the end. Forty years I've sent people into impossible rooms, and the reports that keep me going are the ones where somebody found a third way to hold a sword. All right. To work."},
				{"flag": "chose_kaethra_struck", "text": "Bearer. Sit. ...Kesh's runner reached me before you did. A clean stroke, carried honestly — her camps are grieving without feuding, which in Wildfang terms is a miracle with your name under it. To work, then."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The arithmetic, plainly. Four seals strained this year; you put down every herald the Waking sent — and Serane taught us the bill: each herald is also a hinge. The Storm Tongue's seal is last and worst, because its lock was never stone. It was a SENTENCE — an unbroken relay of speakers, six hundred years long. Korrag's own order. And the last speaker has stopped speaking it and started listening.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Cyrraeth will not be talked back — three of mine tried; the storm answered for him. So it comes to you, and I will not dress it: kill him and the recitation dies with him, and the seal cracks. Spare him and the seal cracks SLOWER, with a god-king's mouth attached. There is no road out of this chapter where the sky holds, bearer. There is only who is standing under it after.",
			"choices": [
				{"text": "\"Then I'll finish the sentence for him. And after — we hold what the crack lets through, together.\"",
					"resonance": 8.0, "flags": {"ch7_briefed": true, "chose_summit_together": true}, "quest": "stormdrake_veyx", "next": "m_together"},
				{"text": "\"A cracked seal means power loose for the taking. Someone will hold it — better me than the factions.\"",
					"resonance": -8.0, "flags": {"ch7_briefed": true, "chose_summit_power": true}, "quest": "stormdrake_veyx", "next": "m_power"},
				{"text": "\"Point me at the storm, Maren. The philosophy can shelter with the baggage.\"",
					"resonance": 0.0, "flags": {"ch7_briefed": true}, "quest": "stormdrake_veyx", "next": "m_work"},
			]},
		"m_together": {"who": "Elder Maren", "text": "Together. ...You know, I recruited you with potions and a warning, and I remember wondering which of the old Guard you'd echo when the weight came. None of them, it turns out. You echo forward. Go — Veyx first, the piece of the god that got out early. Learn what its smallest syllable fights like, before you meet the mouth.", "next": ""},
		"m_power": {"who": "Elder Maren", "text": "Better you than the factions. Bearer — the last person to reason precisely that way about loose power is the reason there's an Ember in your chest and a crack coming in my sky. I'll not stop you; I never could stop any of you. But I'll be watching, and unlike the storm, I don't warn twice. The steppe. Go.", "next": ""},
		"m_work": {"who": "Elder Maren", "text": "The storm it is. Veyx holds the conductor fields — a loose syllable of the god, delighted with itself. Past it, in the first tear, something that remembers being erased. And at the top of the stair, the last Speaker. Work your way up, bearer. The sky will keep score.", "next": ""},
	}},

	# ---- The factions' last pitches of the act.
	"ch7_accord": {"start": "a1", "nodes": {
		"a1": {"who": "Warden-Commander Ashe",
			"text": "Warden-Commander Ashe — yes, the whole Accord command is here; that's what the end of an act of the world looks like, everyone important standing in the same rain pretending they planned it. You're the reason the map got this far. So here's the Accord's last pitch of the age, bearer, unvarnished.",
			"variants": [
				{"flag": "ch7_accord_heard", "text": "The pitch stands until the sky answers it: shards gathered, throne broken, nobody crowned. Hold the line up there.", "next": ""},
				{"flag": "joined_accord", "text": "Commander Ashe, bearer — and among your own, so I'll skip the pitch and say the true thing: whatever cracks tomorrow, the Accord's plan is unchanged. Gather the shards. Break the throne. Nobody wears it. You are the plan, and it's my job to say that to your face before you climb."},
			],
			"next": "a2"},
		"a2": {"who": "Warden-Commander Ashe", "text": "When that seal cracks — and it will, whoever's standing — every power in Vaelscar starts auditioning gods for the throne. The Compact wants a worthy heir. The Choir wants the rot's kingdom. The Accord wants the one ending nobody profits from: shards gathered, throne BROKEN, and everyone who touched that power voluntarily smaller for it. Including you. Especially you. It's a terrible pitch, bearer. It's also the only one where your grandchildren aren't someone's subjects.",
			"choices": [
				{"text": "\"Still the only pitch I'd take a wound for. Count me with the Accord when the sky opens.\"",
					"faction": {"accord": 5}, "flags": {"ch7_accord_heard": true}, "next": "a_with"},
				{"text": "\"'Voluntarily smaller.' You keep asking bearers to amputate, Ashe, and calling it a plan.\"",
					"flags": {"ch7_accord_heard": true}, "next": "a_push"},
			]},
		"a_with": {"who": "Warden-Commander Ashe", "text": "Then that's the whole summit sorted, as far as I'm concerned — the rest is tents and protocol. Flame keep you on the stair, bearer. Bring the sky down gently.", "next": ""},
		"a_push": {"who": "Warden-Commander Ashe", "text": "Aye. That's exactly what we ask, and I've stopped flinching from the word. Every other faction on this hill plans around what bearers can DO. We're the only ones planning around what the power costs — and you, of all people, have now met four seals' worth of what it costs. Climb the stair. Then tell me I'm wrong.", "next": ""},
	}},
	"ch7_cinder": {"start": "c1", "nodes": {
		"c1": {"who": "Consul Verane",
			"text": "Consul Verane, Cinderborn — the actual leadership this time; my envoys have been embarrassing me up and down your road all year, judging by the standings. The Compact watched you cross four provinces, bearer. We'd like to stop auditioning you and simply say it: when the sky cracks, order will not assemble itself.",
			"variants": [
				{"flag": "ch7_cinder_heard", "text": "The offer keeps, bearer — order needs hands, and yours are proven. The Compact doesn't rescind; it renegotiates.", "next": ""},
				{"flag": "joined_cinderborn", "text": "Consul Verane, bearer — and to one of our own I'll say what the envoys can't: the heir question is being SETTLED, this season, in rooms you've earned a chair in. Survive the stair. The Compact does not spend proven assets; it promotes them."},
			],
			"next": "c2"},
		"c2": {"who": "Consul Verane", "text": "Tomorrow there is a hole in the sky and a continent full of terrified people, and terrified people do not want shards gathered or thrones broken — they want WALLS, bread on schedule, and someone visibly in charge. The empire delivered all three for two hundred years. We will again. The only open question is whether the person in charge is worthy this time, and bearer — the Compact's shortlist has gotten very short and very interesting since the Deep.",
			"choices": [
				{"text": "\"Bread on schedule matters. When the sky opens, the Compact can count on my sword for the walls — not the throne.\"",
					"faction": {"cinderborn": 5}, "flags": {"ch7_cinder_heard": true}, "next": "c_walls"},
				{"text": "\"Your shortlist crowned Vargoth once. I've spent an act cleaning up what your 'order' seeded.\"",
					"faction": {"cinderborn": -3, "accord": 2}, "flags": {"ch7_cinder_heard": true}, "next": "c_never"},
			]},
		"c_walls": {"who": "Consul Verane", "text": "Walls, not the throne — noted, minuted, and frankly refreshing; everyone else on the shortlist heard 'throne' and started practicing their profile. The Compact will hold you to the walls, bearer. Walls are ninety percent of empire anyway. The throne is mostly upholstery.", "next": ""},
		"c_never": {"who": "Consul Verane", "text": "We crowned a good king who curdled, yes — and the Accord's answer is to make sure there's never anything worth curdling again. Ash instead of fire, forever, on purpose. When you've stood in the crack's cold tomorrow, bearer, ask yourself honestly which failure frightens you more. The Compact will still be taking applications.", "next": ""},
	}},
	# The last apprentice of Cyrraeth's order — and the Echo's keeper of
	# context. An assassin bearer gets the recognition scene (the erased
	# founder is the assassin ember's own history — endgame seed).
	"ch7_apprentice": {"start": "p1", "nodes": {
		"p1": {"who": "Apprentice Sorrel",
			"text": "You're climbing to him, aren't you. To the Speaker. I'm — I WAS — his apprentice; four years of learning the recitation, one line a season, that's the tradition. I know four lines, bearer. Four lines of a six-hundred-year sentence, and when he dies I'm the closest thing left to a keeper of it. Everyone at this summit keeps carefully not saying that to me.",
			"variants": [
				{"flag": "ch7_sorrel_heard", "text": "Four lines. I've written them down forty times and hidden the copies — paper in a boot, wax under a hearthstone. It's not the relay. But it's not NOTHING. Climb well, bearer.", "next": ""},
			],
			"choices": [
				{"text": "\"Say your four lines for me, Sorrel. Someone besides you should carry them up that stair.\"",
					"resonance": 5.0, "flags": {"ch7_sorrel_heard": true, "chose_carried_lines": true}, "next": "p_lines"},
				{"text": "\"The thing in the tear — the Echo. Your order's records must say what it was.\"",
					"req_flag": "opened_assassin", "flags": {"ch7_sorrel_heard": true, "ch7_echo_named": true}, "next": "p_echo"},
				{"text": "\"Keep your lines and stay off the stair. Whatever happens up there, the world needs its four lines intact.\"",
					"flags": {"ch7_sorrel_heard": true}, "next": "p_keep"},
			]},
		"p_lines": {"who": "Apprentice Sorrel", "text": "He recites them — young voice, old words, and even four lines of it change the AIR, the rain hesitating around the sounds. \"...That's all of it. All of mine.\" He looks at you differently now; a relay passes by exactly this, one keeper to the next. \"There. Whatever the storm takes tonight, it doesn't take all four. Climb, bearer. You're carrying more than steel now.\"", "next": ""},
		"p_echo": {"who": "Apprentice Sorrel", "text": "The order's records go back six hundred years, and there's a HOLE in the oldest ones, bearer — pages razored out, one name inked over in every marginal list. Master said the Guard did it themselves: one of their own FOUNDERS, unwritten as punishment for a betrayal the punishment also erased. ...Why is your shard doing that. Bearer. Why is your shard leaning toward the tear like it HEARD me.", "next": "p_echo2"},
		"p_echo2": {"who": "Apprentice Sorrel", "text": "...Oh. Oh, flame. It's YOURS, isn't it — the erased one. Your ember's own first bearer, thrown away by the Guard, kept by the void. Then hear the only other thing the records didn't lose, and carry it in with you: whatever the name was, the razored pages were TALL. Founder-tall. They erased someone who MATTERED, and the mattering is still down there, wanting its receipt.", "next": ""},
		"p_keep": {"who": "Apprentice Sorrel", "text": "Off the stair. Aye. ...You know that's the first order anyone's given me since he stopped speaking? Everyone else treats me like a relic. You treat me like a RELAY. I'll be at the fire, bearer — four lines, guarded, breathing. Come back and hear them when the sky's done deciding.", "next": ""},
	}},

	# ---- Resonance rooms.
	"ch7_shrine_vowstone": {"start": "v1", "nodes": {
		"v1": {"who": "Narrator",
			"text": "The Vow-Stone — the relay's first waypost, where the recitation began six hundred years ago. The binding's LAST line is carved here in the old script, worn shallow by six centuries of thumbs: every speaker touched it before their shift. The storm overhead bends around this hilltop; even now, even cracked, the vow has manners. The carved line waits. You could SPEAK it — one line, spoken true, joins you to the relay for whatever a night of it is worth. Or you could do what Cyrraeth did, and put your ear to the stone instead.",
			"variants": [{"flag": "vowstone_touched", "text": "The Vow-Stone stands in its bent weather, one thumb-worn line older than every banner at the summit. Whatever you gave it or took from it, the stone keeps the receipt.", "next": ""}],
			"choices": [
				{"text": "Speak the last line aloud, thumb on the carving — one night's shift in a six-hundred-year relay, honestly stood.",
					"resonance": 8.0, "flags": {"vowstone_touched": true, "chose_spoke_vow": true}, "next": "v_speak"},
				{"text": "Put your ear to the stone, as HE did. Half a sentence, six hundred years interrupted — you could just hear what it's been trying to say.",
					"resonance": -10.0, "flags": {"vowstone_touched": true, "chose_listened_storm": true}, "next": "v_listen"},
				{"text": "Rest your hand flat over the carving — cover it from the rain a moment — and climb on without a word.",
					"resonance": 0.0, "flags": {"vowstone_touched": true}, "next": "v_cover"},
			]},
		"v_speak": {"who": "Narrator", "text": "The old words come out of you rough and unpracticed — and the storm, horizon to horizon, MISSES A BEAT. One breath of the sky standing to attention for the first time in months. Your shift, the stone seems to acknowledge, has been logged; six hundred years of speakers make room on the roster without comment. The line will be finished tonight one way or another. Whatever else is true on that stair, YOU will have spoken it as a keeper, not only as a blade.", "next": ""},
		"v_listen": {"who": "Narrator", "text": "You listen. Under the stone: half a sentence, patient beyond geology — and it is not raging, that's the vertigo of it. It is REASONABLE. It has been mid-word for six hundred years, and it just wants to finish the thought, and every part of you that has ever been interrupted leans in with terrible sympathy. You pull away before the second clause lands. Mostly before. The shard hums the fragment for hours after, like a tune it means to learn — and now you understand Cyrraeth completely, which was the price of listening, and possibly the purpose.", "next": ""},
		"v_cover": {"who": "Narrator", "text": "You shelter the carving from the rain with your palm — pointless; it has weathered six hundred years of storms — and stand a moment in the bent weather doing the vow's work without the vow's words. The stone neither thanks you nor tests you. But when you take your hand away, the carved line is dry, and stays dry, all the time you can see it going down the hill. Small courtesies between keepers. Even unofficial ones.", "next": ""},
	}},
	"ch7_shrine_summit": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "The summit table — one plank of storm-felled oak, two banners, no chairs; Maren's design, so no one could settle in. On the table lies the act's whole argument in objects: the Accord's iron shard-casket, open and EMPTY, waiting for what bearers will one day surrender. The Compact's charter of restoration, signed by every noble house that survived Vargoth, one signature-line left blank at the bottom — sized, you notice, for a bearer's hand. Both delegations have withdrawn to their tents. The table, just now, is yours alone, and the sky is running out of patience for the undecided.",
			"variants": [{"flag": "summit_faced", "text": "The table stands in the rain, casket and charter weighting its ends like a scale. Word of what you did here has already made both camps — camps talk. That was the table's whole purpose.", "next": ""}],
			"choices": [
				{"text": "Set your bared shard-hand in the Accord's empty casket, one breath — let the iron take its measure. A promise of the ending where everyone is smaller and free.",
					"resonance": 6.0, "faction": {"accord": 6}, "flags": {"summit_faced": true, "chose_summit_casket": true}, "next": "s_casket"},
				{"text": "Take up the pen and sign the Compact's charter — the blank line fits your hand because they MEANT it to. Order needs a spine, and you have been one all act.",
					"resonance": -6.0, "faction": {"cinderborn": 6}, "flags": {"summit_faced": true, "chose_summit_charter": true}, "next": "s_charter"},
				{"text": "Move both objects to the SAME end of the table, side by side, and leave the length of bare oak facing the storm. Let both camps find it so.",
					"resonance": 3.0, "flags": {"summit_faced": true, "chose_summit_apart": true}, "next": "s_apart"},
			]},
		"s_casket": {"who": "Narrator", "text": "The iron is cold and the gesture is colder: your hand, in the box built to one day hold what your hand holds. The shard SCREAMS — quietly, politely, the whole time — and you keep it there for the full breath anyway. From the Accord tents, no cheering; wardens don't cheer. But by morning every warden on the hill somehow knows, and they have stopped guarding their eyes around you, and that is the Accord's entire vocabulary for love.", "next": ""},
		"s_charter": {"who": "Narrator", "text": "The pen is good, the ink is imperial black, and your name dries on a line that half the dead houses of Vaelscar signed above. The shard settles as you write — pleased, and unbothered by being pleased, which is the sensation you'll remember. By morning the Compact camp bows at precisely calibrated depths as you pass, and somewhere in a consul's dispatch case, a shortlist has been amended. You have not promised them the throne. You have promised them the CONVERSATION, and to the Compact those have always been the same negotiation.", "next": ""},
		"s_apart": {"who": "Narrator", "text": "Casket and charter, side by side at one end — allies, equals, luggage — and the long bare oak aimed at the crack in the sky like a drawn line. It takes both camps until noon to decode it, and Maren four seconds: 'The bearer thinks the table's real argument is with the STORM, and the rest of us are seating arrangements.' She has the plank preserved, afterward. It sits in the Accord archive today, catalogued, in her own hand: EXHIBIT: THE THIRD POSITION.", "next": ""},
	}},

	# ---- Dead-end lore.
	"ch7_lore_cairn": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A cairn of plains stone, raised by the beast-clans for KORRAG, STORMWARDEN — the man you know as a Chapter 2 boss and the plains knew, longer, as the best keeper his order ever fielded. The offerings on it are all beast-things: a wolf tooth, a hawk feather, a cracked storm-whistle. The order's records, you've since learned, say his warding-storm 'broke' the season the seal began to strain — he wasn't failed by his vows, he was the first casualty of a sentence fraying six hundred miles away. Someone has scratched a late line into the base stone, unsigned, in vow-script: 'THE STORM BROKE FIRST. HE JUST CAUGHT IT.'", "next": ""},
	}},
	"ch7_lore_shelf": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A shelf of not-quite-stone at the tear's edge, and arranged along it — arranged, unmistakably — the things the void has caught as they fell out of the world: a child's shoe with a buckle no smith alive could name. A coin from a kingdom absent from every atlas. A letter, sealed, addressed in a hand that makes your shard flinch, to SOMEONE WHO WILL REMEMBER. The void keeps everything, the old warnings say. Standing here, you finally hear the warning's second half, the part the Concord never carved: it keeps everything CAREFULLY.", "next": ""},
	}},

	# ---- Social wanderers.
	"ch7_wander_keeper": {"start": "k1", "nodes": {
		"k1": {"who": "Retired Keeper Vasse",
			"text": "Thirty years I stood relay-shifts before my voice went — you never miss a shift, bearer, that was the whole vow. You could hate the man beside you, hate the RAIN, hate the words; you spoke your hour and passed the line on warm. Six hundred years of nobody missing a shift. And then Cyrraeth, flame keep his brilliant ruined mind, didn't miss his shift either. He ATTENDED it. He just spent it listening instead. The vow never thought to forbid that. Vows never forbid the thing that kills them.",
			"variants": [{"flag": "ch7_vasse_met", "text": "Still here. Still mouthing my old hour every night at the right time — voice or no voice. The line's cut, the storm knows it, and an old keeper's lips moving in a tent change nothing. I do it anyway. Shifts are shifts.", "next": ""}],
			"choices": [
				{"text": "\"Shifts are shifts. Keep speaking yours, keeper — the sky remembers manners even cracked.\"",
					"resonance": 3.0, "flags": {"ch7_vasse_met": true}, "next": "k_keep"},
			]},
		"k_keep": {"who": "Retired Keeper Vasse", "text": "...The sky remembers manners. Ha. You talk like the third-century keepers wrote, bearer — they'd have liked you. Go on up. And when you meet him — when you meet what's LEFT of him — remember he kept every shift for forty years before the listening. Kill the Mouth. Mourn the Speaker. The order always could hold two things at once; it's the storm that only holds one.", "next": ""},
	}},
	"ch7_wander_chaser": {"start": "c1", "nodes": {
		"c1": {"who": "Storm-Chaser Ilya",
			"text": "Data! Sorry — greetings, THEN data. I've chased weather up this steppe for nine years, and the storm's gone WRONG in a way my instruments love and my spine hates: the lightning repeats. Same bolt, same fork, same half-second, night after night. Weather doesn't repeat, bearer. SPEECH repeats. The sky up there isn't storming — it's rehearsing.",
			"variants": [{"flag": "ch7_ilya_met", "text": "New reading: the repeats are getting LONGER. Whatever it's rehearsing, it's up to full phrases now. My professional recommendation is that you climb faster than I can write.", "next": ""}],
			"choices": [
				{"text": "\"Rehearsing for what, Ilya?\"", "flags": {"ch7_ilya_met": true}, "next": "c_what"},
			]},
		"c_what": {"who": "Storm-Chaser Ilya", "text": "For being HEARD, obviously — everything that rehearses is rehearsing for an audience. Six hundred years of one sentence holding it to 'wait,' and now the sentence is down to one exhausted throat. When the recitation stops, bearer, the first thing through that crack won't be a monster. It'll be a WORD, delivered perfectly, after six centuries of practice. My instruments and I would rather not be reviewing it.", "next": ""},
	}},
	"ch7_wander_quarter": {"start": "q1", "nodes": {
		"q1": {"who": "Compact Quartermaster Bel",
			"text": "Requisitions, requisitions — you'd think the end of an age ran on courage; it runs on TARPS, bearer. Two factions, eleven camps, one summit, and every noble tent leaks. You want the empire's real secret? It was never the legions. It was that somebody, somewhere, always knew where the dry blankets were.",
			"variants": [{"flag": "ch7_bel_met", "text": "Update from the tarp front: I've started provisioning for AFTER. Nobody ordered me to. But whatever comes through that crack, people will still need blankets on the far side of it, and I intend to be embarrassingly ready.", "next": ""}],
			"choices": [
				{"text": "\"Provisioning for after. That might be the most hopeful thing anyone's said at this summit.\"",
					"resonance": 3.0, "flags": {"ch7_bel_met": true}, "next": "q_hope"},
			]},
		"q_hope": {"who": "Compact Quartermaster Bel", "text": "Hopeful! Bearer, I've inventoried three collapses of civilization — regional ones, mind — and the pattern holds: the sky does what the sky does, and then somebody hands out soup. Empires, Accords, god-kings — all of them are just arguments about who holds the ladle. Go crack the sky gently. The soup is HANDLED.", "next": ""},
	}},
	"ch7_wander_bellringer": {"start": "b1", "nodes": {
		"b1": {"who": "Old Bellringer Tam",
			"text": "He signs rather than speaks — deaf since a lightning strike took the relay-tower bell out from under him — and his hands are fluent and unhurried: I RANG THE STORM-WARNINGS FORTY YEARS. CAN'T HEAR THUNDER NOW. FEEL IT INSTEAD. He flattens a palm against the ground, then holds it up to you, fingers wide: THE THUNDER HAS STOPPED KEEPING TIME. IT USED TO KEEP TIME. NOBODY ELSE NOTICED.",
			"variants": [{"flag": "ch7_tam_met", "text": "Tam catches your eye and signs, economical as weather: STILL OFF-BEAT. WORSE. Then, after a pause, with the ghost of a smile: RING SOMETHING LOUD UP THERE. I'LL FEEL IT.", "next": ""}],
			"choices": [
				{"text": "Sign back, clumsily: WHAT TIME DID IT KEEP?",
					"flags": {"ch7_tam_met": true}, "next": "b_time"},
			]},
		"b_time": {"who": "Narrator", "text": "Tam's face opens — nine years at this summit and someone finally asked the right question with their hands. He beats it out slowly on his knee: DUM. DUM-DUM. DUM. Rest. Again. The same figure, over and over, and your shard goes cold as you recognize the shape of it: not rhythm. METER. The thunder has been scanning like verse as long as he's felt it — and lately, he signs, tapping your wrist once for emphasis, IT LOST ITS PLACE IN THE POEM. IT IS ANGRY ABOUT IT. GO GIVE IT ITS ENDING.", "next": ""},
	}},
	"ch7_wander_undertaker": {"start": "u1", "nodes": {
		"u1": {"who": "Summit Undertaker Prue",
			"text": "Undertaker to the summit — every gathering this size retains one, we just dress it up as 'provisioner of last dignities.' Slow week, thank the flame; mostly I've been taking PRE-orders. Oh, don't make the face. Two consuls, five wardens, and one very sweet apprentice have all quietly filed instructions-in-the-event, and there's nothing morbid about it — it's the most honest paperwork on this hill. Everyone up here knows what tomorrow might cost. Only my clients have written it DOWN.",
			"variants": [{"flag": "ch7_prue_met", "text": "Still a slow week, still taking pre-orders. Yours remains the only file I'd genuinely hate to open, bearer — professional affection. Do keep it theoretical.", "next": ""}],
			"choices": [
				{"text": "\"What did the apprentice ask for?\"", "flags": {"ch7_prue_met": true}, "next": "u_sorrel"},
				{"text": "\"File one for me: burn the body, scatter it somewhere with weather. The shard goes to Maren.\"",
					"resonance": 4.0, "flags": {"ch7_prue_met": true, "chose_filed_will": true}, "next": "u_file"},
			]},
		"u_sorrel": {"who": "Summit Undertaker Prue", "text": "Client confidentiality — but he's sixteen and he made me swear an ACTUAL oath, so I'll honor the spirit and betray one detail: it isn't instructions for his body. It's instructions for four LINES of verse — where they're hidden, who may learn them, in what order. That boy filed a will for a poem, bearer. If the storm takes him, the recitation still has heirs on paper. I've buried kings with smaller estates.", "next": ""},
		"u_file": {"who": "Summit Undertaker Prue", "text": "Weather to scatter in, and the shard to Maren. She writes it in a small strong hand, reads it back, seals it. 'For what it's worth from a professional: clients who file are the ones who come back. It's the unfinished business that trips people on stairs.' She pats the file-box. 'You are now the most finished business on this hill. Climb accordingly.'", "next": ""},
	}},
}
