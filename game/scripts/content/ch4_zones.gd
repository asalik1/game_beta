## Chapter 4 zones — The Slagfields (magma, L22-28, BOSSES.md).
## Content module: 21 rooms — 13 spine (authored FIRST; spine = [0..12])
## + 8 side rooms. Mono-family-not-mono-look: the chapter opens on ash
## flats (terrain "desert" — the burnt approach) and descends into the
## foundries (terrain "magma").
##
## THE CHAPTER: the Waking arc opens. Cinderborn foundries sit directly
## over the Molten Judge's seal, smelting Crown-grade steel with heat
## they don't understand — and the heat has started answering back.
## Natural Cinderborn recruitment ground; the Accord counters. Your
## guide is Overseer Brann, who lost four crews to Cinderhide and
## half-believes the whispers that cost them.
##
## XP BUDGET (30+22·lvl; enter ~L22.8 off Varo's overshoot):
##   -> Calda L23 (~110 remaining): trash pre-boss ~360 (buffer: the
##      curve absorbs entry variance here by design)
##   -> Cinderhide L25 (1094, Calda pays 300): trash ~790
##   -> Ordo L28 (1806, Cinderhide pays 330): trash ~1480
## Full-clear trash below ≈ 2570 + bosses 1090. Needs a playtest pass.

const CHAPTER_ZONES := {
	"ch4": [
		# ---------------------------------------------------- spine ---
		{
			"name": "The Cinder Gate", "terrain": "desert", "type": "safe",
			"lock_next": "flag:ch4_briefed",
			"merchant": [1050, 480], "shop_tier": "silver",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "villager", "x": 620, "y": 500, "prompt": "E — Overseer Brann", "convo": "ch4_briefing"},
				{"sprite": "envoy", "x": 1400, "y": 400, "prompt": "E — Cinderborn", "convo": "ch4_cinder"},
				{"sprite": "warden", "x": 1500, "y": 760, "prompt": "E — Accord", "convo": "ch4_accord"},
				{"sprite": "villager", "x": 800, "y": 800, "prompt": "E — Talk", "convo": "ch4_survivor"},
			],
		},
		{
			"name": "The Ash Flats", "terrain": "desert", "type": "combat",
			"enemies": [
				["cinder_whelp", 480, 300, 0], ["cinder_whelp", 600, 240, 0], ["cinder_whelp", 540, 420, 0],
				["cinder_whelp", 1300, 900, 1], ["cinder_whelp", 1420, 830, 1], ["cinder_whelp", 1350, 1000, 1],
				["cinder_whelp", 1700, 400, 2], ["cinder_whelp", 1820, 500, 2],
				["cinder_whelp", 950, 620, 3], ["cinder_whelp", 1080, 550, 3],
			],
			"boss": "",
		},
		{
			"name": "The Clinker Road", "terrain": "desert", "type": "combat",
			"enemies": [
				["cinder_whelp", 450, 320, 0], ["cinder_whelp", 570, 250, 0], ["cinder_whelp", 510, 440, 0],
				["slag_brute", 1350, 850, 1], ["slag_brute", 1470, 780, 1],
				["cinder_whelp", 1700, 450, 2], ["forge_acolyte", 1820, 560, 2],
				["cultist", 1000, 950, 3, 22, 14], ["plague_chanter", 1130, 880, 3, 23, 14],
			],
			"boss": "",
		},
		{
			"name": "The Quenching Yard", "terrain": "magma", "type": "boss",
			"lock_next": "boss",
			"enemies": [["cinder_whelp", 700, 400, 0, 23], ["cinder_whelp", 850, 330, 0, 23], ["cinder_whelp", 780, 520, 0, 23]],
			"boss": "forgemistress", "boss_level": 23,
		},
		{
			"name": "The Slag Terraces", "terrain": "magma", "type": "combat",
			"enemies": [
				["slag_brute", 480, 300, 0, 24], ["slag_brute", 600, 240, 0, 24], ["slag_brute", 540, 430, 0, 24],
				["forge_acolyte", 1350, 880, 1], ["forge_acolyte", 1470, 800, 1],
				["slag_brute", 1700, 420, 2, 24], ["slag_brute", 1820, 530, 2, 24],
				["forge_acolyte", 1000, 620, 3], ["forge_acolyte", 1130, 550, 3],
				["cinder_whelp", 950, 750, 3, 24], ["cinder_whelp", 1060, 820, 3, 24],
			],
			"boss": "",
		},
		{
			"name": "The Cooling Sheds", "terrain": "magma", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Vent Fields", "terrain": "magma", "type": "combat",
			"enemies": [
				["vent_skitter", 450, 320, 0], ["vent_skitter", 570, 250, 0], ["vent_skitter", 510, 440, 0],
				["vent_skitter", 640, 350, 0], ["vent_skitter", 700, 260, 0],
				["forge_acolyte", 1350, 850, 1, 25], ["forge_acolyte", 1470, 780, 1, 25],
				["forge_acolyte", 1420, 950, 1, 25], ["forge_acolyte", 1540, 880, 1, 25],
				["slag_brute", 1750, 420, 2, 25], ["slag_brute", 1850, 520, 2, 25], ["slag_brute", 1800, 320, 2, 25],
			],
			"boss": "",
		},
		{
			"name": "The Deep Vents", "terrain": "magma", "type": "boss",
			"lock_next": "boss", "clear_flag": "ch4_vents_capped",
			"enemies": [["vent_skitter", 700, 420, 0], ["vent_skitter", 830, 350, 0]],
			"boss": "cinderhide", "boss_level": 25,
		},
		{
			"name": "The Foundry Concourse", "terrain": "magma", "type": "combat",
			"enemies": [
				["forge_acolyte", 480, 300, 0, 26], ["forge_acolyte", 600, 240, 0, 26], ["forge_acolyte", 540, 430, 0, 26],
				["forge_acolyte", 660, 340, 0, 26],
				["slag_brute", 1350, 880, 1, 26], ["plague_chanter", 1470, 800, 1, 26, 20],
				["slag_brute", 1410, 980, 1, 26], ["slag_brute", 1530, 900, 1, 26],
				["vent_skitter", 1750, 420, 2, 26], ["null_acolyte", 1850, 530, 2, 26, 17],
				["forge_acolyte", 1000, 620, 3, 26], ["forge_acolyte", 1130, 550, 3, 26],
				["forge_acolyte", 950, 760, 3, 26], ["slag_brute", 1080, 830, 3, 26],
			],
			"boss": "",
		},
		{
			"name": "The Tapline Camp", "terrain": "magma", "type": "merchant",
			"merchant": [1050, 620], "shop_tier": "gold",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Sermon Road", "terrain": "magma", "type": "combat",
			"enemies": [
				["forge_acolyte", 480, 300, 0, 27], ["forge_acolyte", 600, 240, 0, 27], ["forge_acolyte", 540, 430, 0, 27],
				["forge_acolyte", 1350, 880, 1, 27], ["forge_acolyte", 1470, 800, 1, 27], ["forge_acolyte", 1410, 980, 1, 27],
				["vent_skitter", 1700, 420, 2, 27], ["vent_skitter", 1820, 530, 2, 27],
				["vent_skitter", 1760, 320, 2, 27], ["vent_skitter", 1880, 420, 2, 27],
				["slag_brute", 1000, 620, 3, 27], ["slag_brute", 1130, 550, 3, 27],
				["forge_acolyte", 950, 760, 3, 27], ["forge_acolyte", 1080, 830, 3, 27],
			],
			"boss": "",
		},
		{
			"name": "The Judgment Stair", "terrain": "magma", "type": "combat",
			"enemies": [
				["slag_brute", 480, 300, 0, 27], ["slag_brute", 600, 240, 0, 27], ["slag_brute", 540, 430, 0, 27],
				["slag_brute", 660, 340, 0, 27], ["slag_brute", 720, 250, 0, 27],
				["forge_acolyte", 1350, 880, 1, 27], ["forge_acolyte", 1470, 800, 1, 27],
				["forge_acolyte", 1410, 980, 1, 27], ["forge_acolyte", 1530, 900, 1, 27],
				["vent_skitter", 1750, 420, 2, 27], ["vent_skitter", 1850, 530, 2, 27], ["vent_skitter", 1800, 320, 2, 27],
			],
			"boss": "",
		},
		{
			"name": "The Verdict Hall", "terrain": "magma", "type": "boss",
			"enemies": [["forge_acolyte", 700, 420, 0, 27], ["forge_acolyte", 830, 350, 0, 27]],
			"boss": "ashpriest", "boss_level": 28,
		},
		# ----------------------------------------------- side rooms ---
		{
			"name": "The Glass Garden", "terrain": "desert", "type": "dead_end", "cache": "wood",
			"enemies": [["cinder_whelp", 1000, 500, 0, 23], ["cinder_whelp", 1150, 560, 0, 23]],
			"boss": "",
			"npcs": [{"sprite": "rock", "x": 950, "y": 320, "prompt": "E — Look", "convo": "ch4_lore_glass"}],
		},
		{
			"name": "The Ember Font", "terrain": "magma", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "crystal", "x": 1056, "y": 500, "prompt": "E — The Ember Font", "convo": "ch4_shrine_font"}],
		},
		{
			"name": "The Overseer's Ruin", "terrain": "magma", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Scoria Quarry", "terrain": "desert", "type": "combat",
			"enemies": [
				["cinder_whelp", 500, 320, 0, 23], ["cinder_whelp", 620, 250, 0, 23], ["cinder_whelp", 560, 440, 0, 23],
				["cinder_whelp", 680, 350, 0, 23], ["cinder_whelp", 740, 260, 0, 23],
				["slag_brute", 1350, 850, 1], ["slag_brute", 1470, 780, 1], ["slag_brute", 1420, 950, 1],
			],
			"boss": "",
		},
		{
			"name": "The Broken Crucible", "terrain": "magma", "type": "combat",
			"enemies": [
				["forge_acolyte", 500, 320, 0, 25], ["forge_acolyte", 620, 250, 0, 25],
				["forge_acolyte", 560, 440, 0, 25], ["forge_acolyte", 680, 350, 0, 25],
				["vent_skitter", 1350, 850, 1], ["vent_skitter", 1470, 780, 1], ["vent_skitter", 1420, 950, 1],
				["slag_brute", 1750, 420, 2, 25], ["slag_brute", 1850, 530, 2, 25], ["slag_brute", 1800, 320, 2, 25],
			],
			"boss": "",
		},
		{
			"name": "The Slagworks Annex", "terrain": "magma", "type": "combat",
			"enemies": [
				["vent_skitter", 500, 320, 0, 27], ["vent_skitter", 620, 250, 0, 27], ["vent_skitter", 560, 440, 0, 27],
				["vent_skitter", 680, 350, 0, 27], ["vent_skitter", 740, 260, 0, 27],
				["forge_acolyte", 1350, 850, 1, 27], ["forge_acolyte", 1470, 780, 1, 27],
				["forge_acolyte", 1420, 950, 1, 27], ["forge_acolyte", 1540, 870, 1, 27],
				["slag_brute", 1750, 420, 2, 27], ["slag_brute", 1850, 530, 2, 27], ["slag_brute", 1800, 320, 2, 27],
			],
			"boss": "",
		},
		{
			"name": "The Foreman's Court", "terrain": "magma", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "villager", "x": 1056, "y": 500, "prompt": "E — The Crew", "convo": "ch4_shrine_court"}],
		},
		{
			"name": "The Cold Forge", "terrain": "magma", "type": "dead_end", "cache": "silver",
			"enemies": [],
			"boss": "",
			"npcs": [{"sprite": "pillar", "x": 950, "y": 330, "prompt": "E — Look", "convo": "ch4_lore_coldforge"}],
		},
	],
}

# Slagfields monsters. HP calibrated to gear-inclusive player dps
# (~224 x 1.12^(lvl-17), ~1s single-target TTK), dmg on the ~5.5%/lvl
# parity curve (in-game = base x 1.3).
const ENEMIES := {
	"cinder_whelp": {"name": "Cinder Whelp", "sprite": "stone_base", "hp": 230.0, "dmg": 38.0, "speed": 180.0, "xp": 12, "gold": 14, "ranged": false, "scale": 3.0,
		"physres": 12.0, "magres": 15.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 22, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["pounce"],
		"lore": "Vent-born fire in a wolf's habit of running in packs. The foundry crews stopped naming them after the first winter."},
	"slag_brute": {"name": "Slagbound Brute", "sprite": "stone_broken", "hp": 320.0, "dmg": 43.0, "speed": 130.0, "xp": 14, "gold": 16, "ranged": false, "scale": 3.5,
		"physres": 38.0, "magres": 12.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 23, "hp_g": 0.11, "dmg_g": 0.09, "traits": ["sower", "swift"],
		"lore": "Foundry laborers who worked the deep lines too long. The slag doesn't burn them anymore, which tells you what they're made of now."},
	"forge_acolyte": {"name": "Forge Acolyte", "sprite": "mummy_mage", "hp": 250.0, "dmg": 46.0, "speed": 100.0, "xp": 15, "gold": 18, "ranged": true, "scale": 3.2,
		"physres": 10.0, "magres": 38.0, "eva": 0.0, "critres": 2.0, "dmg_type": "magic",
		"level": 24, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["reflect"],
		"lore": "They attended one of Ordo's sermons out of curiosity. The Judge's court does not have a public gallery — everyone present is staff."},
	"vent_skitter": {"name": "Vent Skitter", "sprite": "vent_skitter", "hp": 260.0, "dmg": 48.0, "speed": 215.0, "xp": 15, "gold": 18, "ranged": false, "scale": 3.1,
		"physres": 8.0, "magres": 20.0, "eva": 0.15, "critres": 0.0, "dmg_type": "phys",
		"level": 25, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["web"],
		"lore": "It lives in the vent shafts and eats what falls in. The foundries feed it better than the mountain ever did."},
}

const QUESTS := {
	"ch4_start": "Report to Overseer Brann at the Cinder Gate  (walk up to him and press E)",
	"forgemistress": "Cross the ash flats — stop FORGEMISTRESS CALDA at her quenching yard",
	"cinderhide": "Descend the vent fields and crack CINDERHIDE's plating",
	"ashpriest": "Climb the Judgment Stair — end ASHPRIEST ORDO's sermon",
	"done_ch4": "The foundries cool. North, whole villages have stopped waking...",
}

const BEATS := {
	"pre_forgemistress": [
		["Forgemistress Calda", "Stand in the light, bearer — let me see the temper of you. Mm. Forged fast, quenched early. Whoever made you was RUSHING."],
		["Forgemistress Calda", "The Judge whispers tolerances no mortal forge can hold, and my blades hold them anyway. Come — let's find out what YOU hold."],
	],
	"post_forgemistress": [
		["Narrator", "Calda looks at her own blade, at the crack running its length — the first of her edges ever to fail. \"...Out of tolerance,\" she says, wonderingly, and lets it go."],
		["Narrator", "Below the yard, down the vent shafts, something enormous shifts its weight against the rock. The foundry bells ring the cave-in code — for the fifth time this season."],
	],
	"pre_cinderhide": [
		["Narrator", "The vent floor is scored with drag-marks a cart wide. Four memorial plaques bolt to the wall — crews one through four — and a fifth plaque hangs blank, waiting."],
		["Narrator", "CINDERHIDE rises from the deep vent, a meter of cooled obsidian wearing a furnace inside. Steel doesn't bite it. The floor might."],
	],
	"post_cinderhide": [
		["Narrator", "The plating cracks along seams the lava taught you, and what pours out is heat with nothing left to burn. Cinderhide settles into the vent it was born from, and cools for the last time."],
		["Narrator", "From up the concourse, carried on the vent draft, a voice: measured, warm, ending every sentence the same way. The sermon has been running for days."],
	],
	"pre_ashpriest": [
		["Ashpriest Ordo", "Ah. The court was expecting you — you're on the docket, bearer. You have been on it since the Vale."],
		["Ashpriest Ordo", "I listened to the forge-deep for one night, and the Judge gave me the only sermon that never lies: GUILTY. The land, guilty. The empire, guilty. You — well. We needn't spoil the verdict."],
	],
	"epilogue_ch4": [
		["Narrator", "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation leaning over a casket — then straighten, and go ordinary, and are only fires again."],
		["Overseer Brann", "The Compact will say a mad chaplain died and the foundries are safe. I counted what the fires did just now, bearer. They ANSWERED him. The verdicts were never his."],
		["Narrator", "The Slagfields cool behind you. Ahead, the road bends north into weather that doesn't change — and travelers' tales of villages where nobody wakes up, and nobody dies, and wagons roll north full of sleepers."],
	],
}

const WANDERERS := {
	"ch4": [
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch4_wander_smith"},
		{"sprite": "envoy", "prompt": "E — Talk", "convo": "ch4_wander_clerk"},
		{"sprite": "cultist", "prompt": "E — Talk", "convo": "ch4_wander_preacher"},
		{"sprite": "merchant", "prompt": "E — Talk", "convo": "ch4_wander_charms"},
		{"sprite": "warden", "prompt": "E — Talk", "convo": "ch4_wander_sapper"},
	],
}

const CONVOS := {
	# ---- Overseer Brann: a company man whose ledger stopped balancing
	# four crews ago. Reads your ch3 record (chose_ flags survive).
	"ch4_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Overseer Brann",
			"text": "You're the one who opened the Vale road. Good — freight's moving, which means my problems are now arriving FASTER. Brann, overseer of what's left of the southern foundry line.",
			"variants": [
				{"flag": "ch4_briefed", "text": "The yard first, bearer — Calda holds the quench line, and nothing gets past a smith who's stopped making mistakes.", "next": ""},
				{"flag": "chose_varo_mercy", "text": "You're the one from the Vale — the one who put their saint down GENTLY, the story goes. Good. I've got people down there I'd want handled the same way, if it comes to it. Brann. Overseer. Sit."},
				{"flag": "chose_varo_spoils", "text": "You're the one from the Vale. The story that arrived with the freight says you asked what the saint would DROP. Ha! Honest mercenary — I can work with honest. Brann, overseer. Sit."},
			],
			"next": "b2"},
		"b2": {"who": "Overseer Brann", "text": "Here's the honest ledger. The Compact reopened these foundries two years ago — best ore vein in Vaelscar, and the heats run HIGH down here, higher than the coal explains. We told ourselves it was a gift. Then Calda's blades stopped breaking, and Cinderhide ate four crews, and our chaplain started ending his sermons with verdicts.", "next": "b3"},
		"b3": {"who": "Overseer Brann", "text": "Three problems, in order of depth: Calda at the quenching yard — my finest smith, and lately her mistakes don't break either. The beast in the deep vents. And at the bottom, Ordo — who I signed the requisitions for, flame help me, when he asked to hold services closer to the heat.",
			"choices": [
				{"text": "\"Your people got in over something old, Brann. I'll cap it — Calda first.\"",
					"resonance": 6.0, "flags": {"ch4_briefed": true}, "quest": "forgemistress", "next": "b_cap"},
				{"text": "\"Foundries over a god's seal. Someone's empire priced your crews at four and falling.\"",
					"resonance": -4.0, "flags": {"ch4_briefed": true, "chose_blamed_compact": true}, "quest": "forgemistress", "next": "b_blame"},
				{"text": "\"Point me at the yard. The 'why' can wait for whoever survives it.\"",
					"resonance": 0.0, "flags": {"ch4_briefed": true}, "quest": "forgemistress", "next": "b_work"},
			]},
		"b_cap": {"who": "Overseer Brann", "text": "Cap it. Aye. ...You know you're the first person through that gate who's talked about the heat like it's a WELL and not a windfall? Go on — the yard's past the ash flats. And bearer: Calda was good people. Is. Was. You'll see the problem.", "next": ""},
		"b_blame": {"who": "Overseer Brann", "text": "...Four and falling. Yes. And I signed three of the four dockets, so mind who you're aiming that at. The Compact prices everything, bearer — it's the only outfit in Vaelscar honest enough to write the number DOWN. Yard's past the flats. Go earn your line in the ledger.", "next": ""},
		"b_work": {"who": "Overseer Brann", "text": "A professional. Flame knows we've had enough philosophers down here — Ordo was one. The yard's past the ash flats; the vents below it; the sermon below everything. Work top to bottom and you'll always have a floor.", "next": ""},
	}},

	# ---- The factions, pitching over the Waking's first open seal.
	"ch4_cinder": {"start": "c1", "nodes": {
		"c1": {"who": "Envoy Cassia",
			"text": "Envoy Cassia, Cinderborn Compact. Let me say the quiet part first, since everyone thinks it anyway: yes, the Compact drilled here. Yes, something under the rock woke up. And no, we are not sorry — because the ore from this line will arm every wall in Vaelscar when the Waking comes for the REST of you.",
			"variants": [
				{"flag": "ch4_cinder_heard", "text": "The offer stands, bearer: the Compact pays for a working foundry, not a sealed tomb. Save the line, name your price.", "next": ""},
				{"flag": "joined_accord", "text": "Maren's bearer. Save the glare — your Accord wants the fires OUT, and mine wants them under control, and only one of those plans includes anyone holding a sword made after last spring. We can hate each other after the armory's full."},
			],
			"next": "c2"},
		"c2": {"who": "Envoy Cassia", "text": "The empire built on exactly this arithmetic: dangerous heat, disciplined hands, and someone with the stomach to keep the fires lit through the screaming. Vargoth's ghost isn't in the crown, bearer. It's in the FURNACES, and it works three shifts. Keep the line alive and the Compact will remember you at the re-crowning.",
			"choices": [
				{"text": "\"I'll save your foundries — the walls will want that steel.\"",
					"faction": {"cinderborn": 4}, "flags": {"ch4_cinder_heard": true}, "next": "c_yes"},
				{"text": "\"You drilled into a sleeping god and called it a windfall. I'm capping it, not saving it.\"",
					"faction": {"cinderborn": -3, "accord": 2}, "flags": {"ch4_cinder_heard": true}, "next": "c_no"},
			]},
		"c_yes": {"who": "Envoy Cassia", "text": "Pragmatism! It's rarer than ore down here. Deal with the chaplain first if you can — a court that finds EVERYONE guilty is terrible for labor relations.", "next": ""},
		"c_no": {"who": "Envoy Cassia", "text": "Cap it, save it — bearer, once the monsters are dead those are the same act, and the Compact will pay out on results while your principles are still drafting the invoice. Do try to leave the smelters standing.", "next": ""},
	}},
	"ch4_accord": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Edda",
			"text": "Warden Edda, Accord. I'll be plainer than the envoy: this mountain is a SEAL, one of the four, and the Compact has been running a two-year drilling operation into its lid. What's under it judged an empire once. It has had six hundred years to review the case.",
			"variants": [
				{"flag": "ch4_accord_heard", "text": "Kill the heralds, starve the whispers, and for the flame's sake don't LISTEN when the deep talks tolerances. The Accord counts on you.", "next": ""},
				{"flag": "joined_cinderborn", "text": "Compact colors. Fine — I don't need your heart, bearer, just your arithmetic: dead crews don't smelt. Every herald you drop down there protects your employer's investment too. Funny how starving a god pencils out for everyone."},
			],
			"next": "a2"},
		"a2": {"who": "Warden Edda", "text": "Maren's read on the pattern: the seals don't break from outside — they break from ATTENTION. Every sermon Ordo preaches, every whisper Calda obeys, is a hand on the lid. The Accord's ask is simple and ugly: take the hands off.",
			"choices": [
				{"text": "\"Consider them taken. The Accord reads the pattern right.\"",
					"faction": {"accord": 4}, "flags": {"ch4_accord_heard": true}, "next": "a_yes"},
				{"text": "\"I'll do it for the crews still breathing, not for your pattern.\"",
					"flags": {"ch4_accord_heard": true}, "next": "a_own"},
			]},
		"a_yes": {"who": "Warden Edda", "text": "Then a warning, from the last bearer who worked a seal: the deep will offer you EXACTLY the thing you came here needing. That's how it recruits. Know what you need before it tells you.", "next": ""},
		"a_own": {"who": "Warden Edda", "text": "The crews will take it. So will the pattern — it doesn't check motives. Flame keep you below, bearer.", "next": ""},
	}},
	"ch4_survivor": {"start": "s1", "nodes": {
		"s1": {"who": "Smith Petra (Crew Five)",
			"text": "Crew five, that's me. The plaque downstairs is blank because I keep NOT dying and the engraver keeps waiting. Everyone else went in the vents. I was topside with a broken wrist — clumsiest day of my life, and the only reason I have a rest of my life.",
			"variants": [
				{"flag": "ch4_petra_told", "text": "You'll really carve them? All nine names, not 'CREW FIVE, WITH REGRET'? ...I sharpened my good chisel. When the beast's dead, I'll cut the letters myself.", "next": ""},
				{"band": "tempted", "text": "...You stand like the heat stands, you know that? Leaning in. The ones who leaned in are all on plaques now. Free advice from crew five's leftover."},
			],
			"choices": [
				{"text": "\"Give me their names. When the beast is dead, they go on the plaque — all nine, carved proper.\"",
					"resonance": 5.0, "flags": {"ch4_petra_told": true}, "next": "s_names"},
				{"text": "\"Broken wrists save more smiths than helmets do. Stay clumsy.\"",
					"resonance": -2.0, "next": "s_joke"},
			]},
		"s_names": {"who": "Smith Petra (Crew Five)", "text": "Aldan. Merit. Bosk. Hale. The twins. Ruta, Sef, and the boy we all just called Ember because he was NEW, flame, he was so new. ...Nine names. You asked. Two years and the Compact never once asked.", "next": ""},
		"s_joke": {"who": "Smith Petra (Crew Five)", "text": "Ha! Aye. I'll break the other one if the vents start singing again. Cheap at the price.", "next": ""},
	}},

	# ---- Resonance rooms.
	"ch4_shrine_font": {"start": "f1", "nodes": {
		"f1": {"who": "Narrator",
			"text": "A font of living slag, perfectly round, bubbling at blood-heat in a chamber the foundry maps mark DO NOT DIG. The Ember in you leans toward it like iron toward a lodestone. In the slag, faintly, a voice keeps time — measuring, weighing, finding wanting. It would teach you TOLERANCES, if you put your hand in. Calda did.",
			"variants": [{"flag": "ember_font_touched", "text": "The font bubbles on, patient as case law. Whatever passed between you is on the record now — the deep keeps better minutes than the Compact.", "next": ""}],
			"choices": [
				{"text": "Quench your blade-hand in the slag for one breath — pay the pain honestly, take nothing, and let the Judge weigh THAT.",
					"resonance": 8.0, "flags": {"ember_font_touched": true}, "next": "f_pay"},
				{"text": "Lean close and LISTEN. Perfect tolerances, offered free — only a fool leaves knowledge on the table.",
					"resonance": -8.0, "flags": {"ember_font_touched": true, "chose_heard_judge": true}, "next": "f_listen"},
				{"text": "Back out of the chamber. The maps said DO NOT DIG; the miners knew something.",
					"resonance": 0.0, "flags": {"ember_font_touched": true}, "next": "f_leave"},
			]},
		"f_pay": {"who": "Narrator", "text": "One breath. The pain is total and clarifying, and the voice in the slag goes SILENT — genuinely surprised. You take your hand back whole; the slag doesn't burn what doesn't bargain. Somewhere below, a verdict is quietly vacated. The Ember in you sits straighter for days.", "next": ""},
		"f_listen": {"who": "Narrator", "text": "The tolerances arrive: how hard to swing, exactly. Where the flaw in any guard lives, exactly. It is TRUE, all of it, and your hands feel surer already — and underneath the knowing, faint as a stamp on hot metal, the sense of a docket somewhere gaining one more name. The knowledge was free. The listening wasn't.", "next": ""},
		"f_leave": {"who": "Narrator", "text": "You back out the way the miners backed out. The voice in the slag does not call after you — courts don't chase. But as the chamber door closes you hear, distinctly, the sound of a case file being set aside for later.", "next": ""},
	}},
	"ch4_shrine_court": {"start": "c1", "nodes": {
		"c1": {"who": "Narrator",
			"text": "Nine foundry workers ring a kneeling man — Foreman Dask, who sealed the vent door with crew five still inside. \"Procedure,\" he keeps saying, to the floor. The crew hasn't touched him. They are waiting, and when they see you every face turns: an armed stranger, shard-lit, arriving out of the heat like something SENT. \"You judge,\" one says. \"Whatever you say, we'll do.\" The Judge's whisper agrees, warmly. This is, it murmurs, precisely what verdicts are FOR.",
			"variants": [{"flag": "foreman_judged", "text": "The court is adjourned; only the scorch-ring on the floor remembers it. Whatever you decided here walked out on nine pairs of feet — and one more, or not.", "next": ""}],
			"choices": [
				{"text": "\"No. He goes topside for a real trial. You are grieving, I am armed, and neither of us gets to be a court.\"",
					"resonance": 8.0, "flags": {"foreman_judged": true, "chose_foreman_court": true}, "next": "c_refuse"},
				{"text": "Weigh the case. Pass the verdict yourself: guilty. The relief on nine faces feels like worship — the whisper was right.",
					"resonance": -8.0, "flags": {"foreman_judged": true, "chose_foreman_judged": true}, "next": "c_judge"},
				{"text": "Walk on. Nine to one is a verdict already; your absence is just cleaner hands.",
					"resonance": -3.0, "flags": {"foreman_judged": true}, "next": "c_walk"},
			]},
		"c_refuse": {"who": "Narrator", "text": "For a moment nothing moves — nine grieving people and one whisper, all weighing you back. Then the oldest of them lets out a breath sixty hours old. \"...Topside. Aye.\" They bind Dask's hands gently, like people handling the last fragile thing they own. The whisper says nothing. Refusing a offered gavel, it turns out, is a verdict it has no appeal for.", "next": ""},
		"c_judge": {"who": "Narrator", "text": "GUILTY. The word comes out in your voice and lands with someone else's weight. Nine faces flood with relief — carried, absolved, LED — and the whisper under the floor purrs like a signed docket. It is only later, replaying it, that you notice the detail: you never asked Dask a single question. The verdict felt too right to need one. That is how the Judge's verdicts feel. All of them.", "next": ""},
		"c_walk": {"who": "Narrator", "text": "You walk. Behind you the circle closes on its own arithmetic. You don't look back, and so you carry the question instead of the answer: nine to one, and what did they do? Clean hands, the whisper observes mildly, are just hands that made someone else swing. It sounds pleased with the phrasing.", "next": ""},
	}},

	# ---- Dead-end lore.
	"ch4_lore_glass": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A field of sand fused to black glass, a half-mile round, older than any map of the foundries. In the glass, if you kneel: bubbles of shadow that were once things, mid-stride, all fleeing the same center. The Concord's histories say the War of Cinders ended AT the signing table. The glass says one last verdict landed here about an hour before the ink did.", "next": ""},
	}},
	"ch4_lore_coldforge": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "One forge in the works has never lit — the firebrick is virgin, the flue unstained. The founding crew's log, chained to the anvil, explains in a careful hand: THE HEAT WOULD NOT ENTER THIS ONE. WE BUILT IT ANYWAY, TO HAVE SOMEWHERE TO STAND. Sixty years of foundrymen have eaten lunch here, in the one room the mountain won't listen through. The anvil is worn bright from people touching it on the way out.", "next": ""},
	}},

	# ---- Social wanderers.
	"ch4_wander_smith": {"start": "w1", "nodes": {
		"w1": {"who": "Old Smith Harl",
			"text": "Fifty years at the anvil, and I'll tell you what changed: we used to quench in WATER. River water, rain water — the blade hissed and that was the whole ceremony. Now it's slag baths and whisper-tempering and edges that never dull. Everyone's thrilled. Nobody asks what the blades are FOR, ever since the blades started being for something.",
			"variants": [{"flag": "ch4_harl_met", "text": "Still here. Still quenching in water, the old way. My blades dull, and I have never once loved them more.", "next": ""}],
			"choices": [
				{"text": "\"What are the blades for, Harl?\"", "flags": {"ch4_harl_met": true}, "next": "w_for"},
			]},
		"w_for": {"who": "Old Smith Harl", "text": "The heir. Nobody SAYS it, but every order the Compact places is armory-shaped, crown-shaped, procession-shaped. They're forging for a coronation, bearer. And the mountain under us keeps offering better steel, and nobody upstairs finds that combination interesting. I find it interesting enough to quench in water.", "next": ""},
	}},
	"ch4_wander_clerk": {"start": "w1", "nodes": {
		"w1": {"who": "Compact Clerk Voss",
			"text": "Mortality clerk, southern line. I log the deaths — cause, shift, compensation tier. Want the strange part? Column three. Cave-in, cave-in, burn, burn, cave-in — then two years ago the causes change: 'JUDGED.' First time I saw it I sent it back as a clerical error. It came back countersigned.",
			"variants": [{"flag": "ch4_voss_met", "text": "Column three's gotten worse, since you ask. The latest entries aren't even words anymore. Just a small stamped scale, perfectly balanced. We don't own that stamp.", "next": ""}],
			"choices": [
				{"text": "\"Who countersigned it, Voss?\"", "flags": {"ch4_voss_met": true}, "next": "w_who"},
			]},
		"w_who": {"who": "Compact Clerk Voss", "text": "Chaplain Ordo. Back when he still filed paperwork. The signature's changed since — same name, but the hand gets HEAVIER every quarter, like something's leaning on the pen. I keep the ledgers now mostly so someone, someday, can prove this happened on purpose.", "next": ""},
	}},
	"ch4_wander_preacher": {"start": "w1", "nodes": {
		"w1": {"who": "Lay Preacher Immo",
			"text": "Brother! Have you HEARD? The fires judge fairly! No coin sways them, no rank, no pleading — the first honest court in Vaelscar sits under this very rock! I attend the sermons weekly. I have never felt so SEEN.",
			"variants": [
				{"band": "tempted", "text": "Brother! You carry a spark of the docket yourself — I can feel it wanting things! Come to a sermon, bring the spark, the Judge LOVES an appellant with standing!"},
				{"flag": "ch4_immo_met", "text": "You again! Still unindicted? Marvelous. The Judge is patient — the Judge is MOSTLY patience, structurally speaking.", "next": ""}],
			"choices": [
				{"text": "\"Immo — courts that can't acquit aren't courts. Name one soul the fires found innocent.\"",
					"resonance": 3.0, "flags": {"ch4_immo_met": true}, "next": "w_name"},
				{"text": "\"Enjoy the sermons. Sit near the exit.\"", "flags": {"ch4_immo_met": true}, "next": "w_exit"},
			]},
		"w_name": {"who": "Lay Preacher Immo", "text": "...Name one... — he's quiet a long moment, and something behind his eyes tries the question on like a shoe that doesn't fit. \"The sermons never — there hasn't been an acquittal YET, but that only proves how guilty—\" He stops. He looks at his hands. \"...Sit near the exit,\" he repeats, slowly, as if hearing it properly for the first time.", "next": ""},
		"w_exit": {"who": "Lay Preacher Immo", "text": "The exit! Ha! Brother, when the verdict comes there IS no exit — that's the beauty of a fair court! ...Why are you looking at me like that?", "next": ""},
	}},
	"ch4_wander_charms": {"start": "w1", "nodes": {
		"w1": {"who": "Charm Peddler Nix",
			"text": "Verdict charms! Genuine acquittal wax, pressed with a little scale — wear it and the fires weigh you KINDLY. Two silver. The foundry crews buy them by the dozen, so either they work or the crews die too fast to complain, and commercially speaking both keep my margins healthy.",
			"variants": [{"flag": "ch4_nix_met", "text": "Restocked! New line: appeal charms, for the already-judged. They're the same charm with a second ribbon, and before you say anything, hope with two ribbons on it is still HOPE.", "next": ""}],
			"choices": [
				{"text": "\"Do they work, Nix? Straight answer.\"", "flags": {"ch4_nix_met": true}, "next": "w_work"},
				{"text": "\"Selling acquittals from a court that's never acquitted. There's the empire's whole soul in one stall.\"", "resonance": -2.0, "flags": {"ch4_nix_met": true}, "next": "w_soul"},
			]},
		"w_work": {"who": "Charm Peddler Nix", "text": "Straight answer: the charm does nothing and the WEARING does something. A man who believes he's weighted kindly walks past the vents instead of leaning over them to listen. I sell two silver of not-leaning. Cheapest life insurance in the Slagfields, and I sleep fine.", "next": ""},
		"w_soul": {"who": "Charm Peddler Nix", "text": "Ooh, that's GOOD, can I use that? 'The empire's soul, two silver.' ...Look, bearer, the Compact sells the crews to the mountain and I sell them hope on the way down. One of us is the villain and it isn't the one with the wax press.", "next": ""},
	}},
	"ch4_wander_sapper": {"start": "w1", "nodes": {
		"w1": {"who": "Accord Sapper Ruel",
			"text": "Don't mind the instruments — floor temperature, every hundred paces, three times daily. The Accord likes numbers. Here's mine: the deep lines run four degrees hotter every month, and it's not the season, because the SHALLOW lines run four degrees hotter too. The whole mountain is coming up to temperature. Like something's breathing on the far side of the rock.",
			"variants": [{"flag": "ch4_ruel_met", "text": "Today's reading? Don't ask. Actually — ask. Someone besides me and Maren should be losing sleep with correct numbers.", "next": ""}],
			"choices": [
				{"text": "\"How long until it matters, sapper?\"", "flags": {"ch4_ruel_met": true}, "next": "w_long"},
			]},
		"w_long": {"who": "Accord Sapper Ruel", "text": "At the current slope? Years. But slopes don't hold near a wake-up — ask anyone who's watched a kettle. The heralds are the rattle before the whistle, bearer. Every one you put down buys the slope back a little. That's the entire Accord strategy, if anyone asks: fight the RATTLE.", "next": ""},
	}},
}
