## (P1) Promises kept — dialogue promises become checkable things.
## Audit (2026-07-07): several resonance-shifting lines had the player
## PROMISE something the world never checked. This module makes the two
## worst offenders real side quests (Fenna's son in the Misted Fields,
## Petra's blank plaque) and closes the cheap loops with beat variants
## (the criers to the frozen shore, Kaethra's answer carried to Kesh,
## Sorrel's four lines heard on the stair, the blank fifth plaque named
## at the vents) plus two convo payoffs (the mute widow's thanks now
## waits for Vess to actually die; Skald Ottar collects his fee).
##
## Where a promise now has a delivery, the resonance moved WITH it: a
## small nudge for saying the words, the larger shift for keeping them
## (or a sting for keeping them badly — ch3_fenna_son_dropped).
##
## Convo overrides are FULL copies of the current winner (chN_quests
## where one exists, chN_zones otherwise), extended per the board rules:
## quest choices append at the END of choice lists behind req flags, and
## revisit variants redirect into new hub nodes. This module must stay
## registered LAST in Story.CONTENT_MODULES so its overrides win.
##
## Paired minimal in-place zone edits (flag/prop hooks only):
##   ch3_zones.gd — The Misted Fields gains the Alder Row prop (1 npcs
##                  line); The Silent Aisle gains clear_flag "vess_dead".
##   ch4_zones.gd — The Deep Vents gains clear_flag "ch4_vents_capped".

const SIDE_QUESTS := {
	"ch3_facing_home": {
		"name": "Facing Home",
		"chapter": "ch3",
		"desc": "Old Fenna's son walks the Misted Fields — fourth from the alder, grey coat. You gave her your word: if it's your hand that fells him, he falls facing home.",
		"steps": [
			{"flag": "ch3_fenna_son_rested", "text": "Find the fourth grave from the alder in the Misted Fields"},
			{"flag": "ch3_fenna_told", "text": "Bring Old Fenna the truth of it"},
		],
		"reward": {"gold": 140},
	},
	"ch4_nine_names": {
		"name": "Nine Names",
		"chapter": "ch4",
		"desc": "Crew five went into the vents and came back a blank plaque. You gave Smith Petra your word: when the beast is dead, all nine names go on it — carved proper, not 'CREW FIVE, WITH REGRET'.",
		"steps": [
			{"flag": "ch4_vents_capped", "text": "Bring down Cinderhide in the Deep Vents"},
			{"flag": "ch4_names_carved", "text": "Return to Smith Petra — nine names, carved proper"},
		],
		"reward": {"gold": 160},
	},
}

# ------------------------------------------------------------- beats ---
# Boss-door / epilogue variants (Story.beat_for: "key@flag:x"). Each one
# is a promise the words made and the world now keeps.
const BEATS := {
	# Petra's promise, remembered at the kill (the blank fifth plaque).
	"post_cinderhide@flag:ch4_petra_told": [
		["Narrator", "The plating cracks along seams the lava taught you, and what pours out is heat with nothing left to burn. Cinderhide settles into the vent it was born from, and cools for the last time."],
		["Narrator", "On the gallery wall above the vent, the fifth plaque hangs blank on its bolts — waiting, the way it has waited two years. Not anymore. At the gate a smith keeps a sharpened chisel and nine names, and you promised her this was the day."],
		["Narrator", "From up the concourse, carried on the vent draft, a voice: measured, warm, ending every sentence the same way. The sermon has been running for days."],
	],
	# Ansa's 'when': the criers ride for the shore first, as promised.
	"epilogue_ch5@flag:chose_criers_promised": [
		["Narrator", "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the arena, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks."],
		["Tracker Yri", "The clans will carry the sleepers to fires and see who rises. Some won't. Hear me, bearer: the ones who do rise, rise because of you — let that argue with the ridge, on the nights it needs arguing with."],
		["Narrator", "The first riders leave before the fires are banked — criers, sent at your word, beating every rumor to the frozen shore: the lullaby is ended, the sleepers are coming to fires, watch the road. In one shore-house a lamp goes up in the window and stays lit, because a boy who fears the dark is going to wake somewhere strange, and the first thing he sees is going to be kind. You said WHEN. It wasn't a lie."],
		["Narrator", "The Queen dreams on beneath the ice, her lock one voice weaker, her lullaby unsung. And out of the east, carried over the frozen shore, comes a smell with no business in winter: green. Growing things. A spring that nobody planted, in a bog where nothing should bloom."],
	],
	# Kaethra's answer, carried back to Kesh — in her own words, per ending.
	"epilogue_ch6@flag:chose_kaethra_sheathed": [
		["Narrator", "Word runs ahead of you back through the Deep: it's done. At the cure-camp the drums beat the mourning rhythm, and at the pilgrims' rest the Choir faithful sing something old and unsure — a liturgy with the certainty gone out of it, which is almost a prayer."],
		["Narrator", "At the Pilgrim Gate you keep your word before the mud of the Deep is off your boots: her answer, to both camps, in her own words. Not cure. Not acceptance. WITNESS — and the last thing the Root ever heard in there was Kaethra, laughing at it, in her own voice."],
		["Herbalist Kesh", "\"Laughing at it. In her OWN voice.\" Kesh holds the words the way her people hold a med-kit — something between hands that will be needed again. \"Both camps will carry her home together — first thing we've done together in a generation — and what you carried back walks ahead of the bier. She always said the argument would end with evidence. It ended with a WITNESS. We can build on that.\""],
		["Narrator", "The Blooming stalls with no one left to want it. And north, over the Thunder Plains, the horizon flickers — not lightning. The sky itself, tearing at the edges, void showing through the storm. The last seal is straining, and the last chapter of the early roads begins."],
	],
	"epilogue_ch6@flag:chose_kaethra_struck": [
		["Narrator", "Word runs ahead of you back through the Deep: it's done. At the cure-camp the drums beat the mourning rhythm, and at the pilgrims' rest the Choir faithful sing something old and unsure — a liturgy with the certainty gone out of it, which is almost a prayer."],
		["Narrator", "At the Pilgrim Gate you keep your word, both truths undressed, the way she asked: the cure was real. The price was real. The beast was gone at the end — and so was the Root — and what was left CHOSE."],
		["Herbalist Kesh", "\"The cure was real. The price was real.\" Kesh repeats it until the weight sits level. \"Both camps will carry her home together — first thing we've done together in a generation — and her answer goes ahead of the bier in her own words. 'What was left chose.' That's cure enough, bearer. She said so, and you carried it straight.\""],
		["Narrator", "The Blooming stalls with no one left to want it. And north, over the Thunder Plains, the horizon flickers — not lightning. The sky itself, tearing at the edges, void showing through the storm. The last seal is straining, and the last chapter of the early roads begins."],
	],
	# Sorrel's four lines, noticed at the top of the stair.
	"pre_stormmouth@flag:chose_carried_lines": [
		["Cyrraeth", "— and the word was not SILENCE, bearer, that's the mistranslation, six centuries of it — the word was WAIT. We were never keeping it in. We were keeping it WAI— ...stop. Stand very still. The storm hears it too: there are LINES on you. Four of them, warm from a young voice, carried up my stair like a lamp."],
		["Cyrraeth", "Sorrel. Four years I fed him one line a season and called it tradition — and he has already done the one thing six hundred years of keepers were FOR: he passed them on. Then hear me, relief-bearer. Kill the Mouth, mourn the Speaker; the sentence still has heirs. Come — one of us ends the recitation tonight, and for the first time since I stopped speaking... I am not afraid of which."],
	],
}

const CONVOS := {
	# OVERRIDES ch3_quests.gd's "ch3_refugee" (which overrode ch3_zones) —
	# verbatim copy, extended: the promise choice now ACCEPTS Facing Home
	# (nudge at the word, +2; the old +4 moved to the delivery), and two
	# new variants route the report (r_tell) and the closed loop (which
	# keeps Fenna's bread ask reachable, exactly like ch3_fenna_promised).
	"ch3_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Old Fenna",
			"text": "My son walks the Misted Fields. Fourth from the alder, grey coat. The Choir says that's him honored. I say I sewed that coat for a living boy and I want it BACK on a dead one, in the ground, where coats and sons go.",
			"variants": [
				{"flag": "ch3_fenna_told", "text": "The fourth plot from the alder stays closed now. \"Facing home,\" she says, once, like a woman checking a knot that held. There is thread on her sleeve — she has taken up sewing again. Not coats yet. But sewing.", "next": "r_bread"},
				{"flag": "ch3_fenna_son_rested", "text": "She is on her feet before you clear the gate, reading your face the way she once read weather for the mill. \"The fields. You've been in the fields. Fourth from the alder — say it, bearer. Whichever way it is, say it.\"", "next": "r_tell"},
				{"band": "tempted", "text": "You've got the look the Choir cantors get before they start explaining why my grief is holy. Don't. Just — if you pass the fourth grave from the alder, grey coat... let him fall facing home."},
				{"flag": "ch3_fenna_promised", "text": "Fourth from the alder. Grey coat. Facing home. You remembered. That's more than the flame's given me in sixty years.", "next": "r_bread"},
			],
			"choices": [
				{"text": "\"Fourth from the alder, grey coat. If it's my hand that fells him, he falls facing home.\"",
					"req_not_flag": "ch3_fenna_promised", "resonance": 2.0,
					"flags": {"ch3_fenna_promised": true},
					"side_quest": "ch3_facing_home", "next": "r_kind"},
				{"text": "\"The things out there aren't sons anymore. The sooner you learn that, the lighter you'll walk.\"",
					"resonance": -4.0, "next": "r_cold"},
			]},
		"r_kind": {"who": "Old Fenna", "text": "Facing home. Yes. ...The Choir sang at me for sixty years and never once said anything that useful.", "next": ""},
		"r_cold": {"who": "Old Fenna", "text": "Lighter. Aye. You sound like the shard's already teaching you to travel light. Keep the lesson — I'll keep the coat.", "next": ""},
		# ---- Facing Home (side quest): the report. The larger resonance
		# lands HERE — when the promise was kept, and how well.
		"r_tell": {"who": "Old Fenna", "text": "Her hands are still. Everything else about her is listening.",
			"choices": [
				{"text": "\"Fourth from the alder, grey coat. He fell facing home — I turned him at the last, like I said I would.\"",
					"req_not_flag": "ch3_fenna_son_dropped", "resonance": 4.0,
					"flags": {"ch3_fenna_told": true}, "next": "r_home"},
				{"text": "\"He's down, Fenna. It was quick. ...He fell where he stood.\"",
					"req_flag": "ch3_fenna_son_dropped", "resonance": -2.0,
					"flags": {"ch3_fenna_told": true}, "next": "r_stood"},
				{"text": "\"...Not yet. Let me find the words first.\"", "next": ""},
			]},
		"r_home": {"who": "Old Fenna", "text": "Facing home. — She doesn't weep; she is sixty years past the easy kind. She just breathes out, all the way down, maybe for the first time since the mill. \"Then he's done walking, and I'm done waiting, and the coat's where coats and sons go. You kept a promise the Choir spent sixty years singing over, bearer. Flame keep your roads short and your word this heavy always.\"", "next": ""},
		"r_stood": {"who": "Old Fenna", "text": "Where he stood. — The words land and she takes them standing, the way she has taken everything else. \"I asked you for one direction, bearer. One. ...No. You put him down, and that's more than sixty years of hymns managed. But you'll forgive me if I don't thank you in the words I'd saved.\" She turns back to her fire — pointedly, deliberately facing home, for both of them.", "next": ""},
		# ---- Bread for the Kneeling (side quest): the offer (Q3, verbatim).
		"r_bread": {"who": "Old Fenna",
			"text": "There's a field of them below the cathedral, you know. Kneeling. The Choir sings over their heads and calls it feeding them. I've buried nothing in sixty years but I've baked every day of it — take them a loaf, if your road goes up. Grief is grief. Even theirs.",
			"variants": [{"flag": "vale_bread_left", "text": "You gave them the loaf? Good. Kneeling fools, the lot of them — but nobody kneels well hungry, and the Choir was never going to feed anything but the singing.", "next": ""}],
			"choices": [
				{"text": "\"Another time, Fenna.\"", "next": ""},
				{"text": "\"I'll carry it up. No sermon with it.\"",
					"req_not_flag": "sq_on_ch3_bread_kneeling", "resonance": 2.0,
					"side_quest": "ch3_bread_kneeling", "gain_item": "vale_bread", "next": "r_loaf"},
			]},
		"r_loaf": {"who": "Old Fenna", "text": "No sermon. Ha — you're learning the Vale faster than most. It's the dark loaf, keeps a week. Mind the middle: still warm. Some things I can't send my son. Doesn't mean the oven goes cold.", "next": ""},
	}},

	# The Alder Row (new prop in the Misted Fields — see the paired
	# ch3_zones edit): the other half of Fenna's promise. Without the
	# promise the prop reads as plain lore; with it, the choice is real,
	# and keeping it BADLY is its own recorded outcome.
	"ch3_lore_alder": {"start": "a1", "nodes": {
		"a1": {"who": "Narrator",
			"text": "An old alder leans over a row of open graves, and the row's tenants walk their slow circuits in the mist. Fourth from the alder: a grey coat, patched at both elbows by somebody's needle, the stitches small and sure. He walks with his face turned east, toward the deep Vale, the way the Choir aimed all of them. West, behind him, past the gate: the mill road. Home.",
			"variants": [
				{"flag": "ch3_fenna_son_rested", "text": "The fourth plot from the alder lies closed — the one filled grave in a row of open ones, mounded by your own hands. The mist walks around it now, and the alder, for whatever an old tree's opinion is worth, has stopped leaning quite so hard.", "next": ""},
			],
			"choices": [
				{"text": "Wait out his circuit, take him at the turn — and turn him at the last, so he falls facing home.",
					"req_flag": "ch3_fenna_promised", "req_not_flag": "ch3_fenna_son_rested",
					"resonance": 3.0, "flags": {"ch3_fenna_son_rested": true}, "next": "a_home"},
				{"text": "Put the walker down where it stands. Quick is its own kindness.",
					"req_flag": "ch3_fenna_promised", "req_not_flag": "ch3_fenna_son_rested",
					"flags": {"ch3_fenna_son_rested": true, "ch3_fenna_son_dropped": true}, "next": "a_stood"},
				{"text": "Leave the row to its walking.", "req_flag": "ch3_fenna_promised", "next": ""},
			],
			"next": ""},
		"a_home": {"who": "Narrator", "text": "It takes patience, and footwork, and one ugly moment when the grey coat's arms find your shoulders like a man being helped down from a cart — and then it is done, and he is down, and his face is west. Toward the mill road. You fill the grave yourself, with the Sexton's own abandoned spade, because a promise kept halfway is a promise broken politely. The mist stands off the whole time, respectful as a hired mourner. Somebody should tell his mother. Somebody promised to.", "next": ""},
		"a_stood": {"who": "Narrator", "text": "Quick, clean, where it stood — facing east, the way the Choir aimed him, because turning a falling man takes a promise's worth of extra care and you spent yours on the quick part. You fill the grave anyway. The coat goes under with its patched elbows and its small sure stitches, aimed the wrong way for eternity by the margin of one held breath. The mist doesn't judge you. That's what mothers are for.", "next": ""},
	}},

	# OVERRIDES ch3_zones.gd's "ch3_wander_mute" — verbatim copy; the
	# thanks variant now waits on the deed (Vess actually dead — the
	# Silent Aisle's new clear_flag) instead of firing on any re-talk.
	"ch3_wander_mute": {"start": "m1", "nodes": {
		"m1": {"who": "Narrator",
			"text": "A woman sits on a fallen headstone, hands folded. The locals say she asked the Choir to bury her daughter, was sung 'no', and has not spoken since — nineteen years. She looks up at you. She looks at your sword hand. Very slowly, very clearly, she nods toward the east road.",
			"variants": [
				{"flag": "vess_dead", "text": "She is there, hands folded — but the folded hands are different now: loose, done. The Silent Aisle has gone quiet, and word of whose hand ended the liturgy reached her before you did. When she sees you she touches two fingers to her lips, holds them out, and bows her head — nineteen years of vigil, discharged. It is the loudest thank-you you have ever been paid.", "next": ""},
				# Walked-past state (before ch3_mute_met — the two never mix):
				# she asked once, with a nod, and was answered. Final.
				{"flag": "ch3_mute_passed", "text": "She is there, hands folded, eyes on the east road. She does not look up as you pass — nineteen years have taught her which footsteps to spend hope on, and yours, she has decided, are not among them.", "next": ""},
				{"flag": "ch3_mute_met", "text": "She is there again, hands folded, eyes on the east road. The singing has not stopped yet. The contract holds — she checked your sword hand once, and went back to waiting.", "next": ""},
			],
			"choices": [
				{"text": "Nod back. Once. A contract needs no words.",
					"resonance": 3.0, "flags": {"ch3_mute_met": true}, "next": "m_nod"},
				{"text": "Look away and walk on. Every silence in this Vale wants a sword, and yours is already spoken for.",
					"resonance": -4.0, "flags": {"ch3_mute_passed": true}, "next": "m_pass"},
			]},
		"m_nod": {"who": "Narrator", "text": "Something in her shoulders lets go — a knot nineteen years old, loosening one turn. She resumes her vigil. You resume your road. Between you, wordless and binding as anything ever signed: someone is finally going to MAKE the singing stop.", "next": ""},
		"m_pass": {"who": "Narrator", "text": "You give the east road your eyes and keep them there until she is behind you. She does not gesture again — nineteen years have taught her exactly how much asking is worth — and the not-looking costs more effort than a nod would have. The Ember finds that funny. You walk faster than you need to.", "next": ""},
	}},

	# OVERRIDES ch4_quests.gd's "ch4_survivor" (which overrode ch4_zones) —
	# verbatim copy, extended: the names promise now ACCEPTS Nine Names
	# (+2 at the word; the old +5 moved to the carving), and the carving
	# itself is a real scene once Cinderhide is dead (ch4_vents_capped,
	# the Deep Vents' new clear_flag). Refund hooks (Q4) stay reachable
	# from every state.
	"ch4_survivor": {"start": "s1", "nodes": {
		"s1": {"who": "Smith Petra (Crew Five)",
			"text": "Crew five, that's me. The plaque downstairs is blank because I keep NOT dying and the engraver keeps waiting. Everyone else went in the vents. I was topside with a broken wrist — clumsiest day of my life, and the only reason I have a rest of my life.",
			"variants": [
				{"flag": "ch4_names_carved", "text": "The plaque downstairs reads nine names now, in my own letters — crews one through five, all accounted, nobody 'regretted'. I still say crew five when they ask me. It means something with a roster again.", "next": "s_done_hub"},
				{"flag": "ch4_petra_told", "text": "You'll really carve them? All nine names, not 'CREW FIVE, WITH REGRET'? ...I sharpened my good chisel. When the beast's dead, I'll cut the letters myself.", "next": "s_after"},
				{"band": "tempted", "text": "...You stand like the heat stands, you know that? Leaning in. The ones who leaned in are all on plaques now. Free advice from crew five's leftover."},
			],
			"choices": [
				{"text": "\"Give me their names. When the beast is dead, they go on the plaque — all nine, carved proper.\"",
					"resonance": 2.0, "flags": {"ch4_petra_told": true},
					"side_quest": "ch4_nine_names", "next": "s_names"},
				{"text": "\"Broken wrists save more smiths than helmets do. Stay clumsy.\"",
					"resonance": -2.0, "next": "s_joke"},
				{"text": "Hold out a worn pouch. \"From Nix. A refund — the verdict charms crew five bought. None of them worked, and she checked.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": 2.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_truth"},
				{"text": "Hold out the pouch. \"Crew five had credit at the charm stall. It's yours now — that's all the arithmetic there is.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": -1.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_soft"},
			]},
		"s_names": {"who": "Smith Petra (Crew Five)", "text": "Aldan. Merit. Bosk. Hale. The twins. Ruta, Sef, and the boy we all just called Ember because he was NEW, flame, he was so new. ...Nine names. You asked. Two years and the Compact never once asked.", "next": ""},
		"s_joke": {"who": "Smith Petra (Crew Five)", "text": "Ha! Aye. I'll break the other one if the vents start singing again. Cheap at the price.", "next": ""},
		# --- Nix's Receipts: delivery, both framings (Q4, verbatim).
		"s_refund_truth": {"who": "Smith Petra (Crew Five)", "text": "She takes the pouch and doesn't open it. \"None of them worked.\" A long breath. \"...They knew, bearer. Bosk used to kiss his charm and WINK. It was never about the wax — it was two silver of walking in anyway, together.\" She pockets it. \"Tell Nix the refund's accepted and the charms are paid for. Both things. She'll understand or she won't.\"", "next": ""},
		"s_refund_soft": {"who": "Smith Petra (Crew Five)", "text": "\"Credit.\" She turns the pouch over once, and her mouth does something that isn't a smile. \"I've settled crew accounts before. This isn't what settled feels like.\" She takes it anyway — coin is coin, down here — but she looks at you a moment too long, the way you look at a scale you suspect of kindness.", "next": ""},
		"s_after": {"who": "Smith Petra (Crew Five)", "text": "Nine names, one chisel. I keep rehearsing the spacing.",
			"choices": [
				{"text": "Hold out a worn pouch. \"From Nix. A refund — the verdict charms crew five bought. None of them worked, and she checked.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": 2.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_truth"},
				{"text": "Hold out the pouch. \"Crew five had credit at the charm stall. It's yours now — that's all the arithmetic there is.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": -1.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_soft"},
				{"text": "\"Bring the chisel, Petra. Cinderhide is dead — nine names go up today, carved proper.\"",
					"req_flag": "ch4_vents_capped", "req_not_flag": "ch4_names_carved",
					"resonance": 5.0, "flags": {"ch4_names_carved": true}, "next": "s_carve"},
			],
			"next": ""},
		# --- Nine Names: the carving (the promise, kept in stone).
		"s_carve": {"who": "Narrator", "text": "She has the chisel out of its cloth before you finish the sentence, and you walk down to the vent gallery together — past the four crews' plaques, to the blank fifth. She cuts; you hold the lamp. ALDAN. MERIT. BOSK. HALE. THE TWINS — RUTA AND SEF, she gives them their full letters after all. And at the bottom, larger, the way he'd have grinned about: EMBER. NEW.", "next": "s_carve2"},
		"s_carve2": {"who": "Smith Petra (Crew Five)", "text": "Two years the Compact offered me 'CREW FIVE, WITH REGRET' and called the engraving budgeted. You asked for the names — and then you went down there and made the plaque true to finish. ...I'm the leftover, bearer. Tonight's the first night the word doesn't fit. Leftover of WHAT? It's carved now. Crew five has a roster again.", "next": ""},
		"s_done_hub": {"who": "Smith Petra (Crew Five)", "text": "I go down and read it some mornings, before shift. Aldan first, Ember last. It reads like a crew again.",
			"choices": [
				{"text": "Hold out a worn pouch. \"From Nix. A refund — the verdict charms crew five bought. None of them worked, and she checked.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": 2.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_truth"},
				{"text": "Hold out the pouch. \"Crew five had credit at the charm stall. It's yours now — that's all the arithmetic there is.\"",
					"req_flag": "ch4_refund_taken", "req_not_flag": "ch4_refund_given",
					"lose_item": "nix_refund", "resonance": -1.0,
					"flags": {"ch4_refund_given": true}, "next": "s_refund_soft"},
			],
			"next": ""},
	}},

	# OVERRIDES ch5_quests.gd's "ch5_mother" (which overrode ch5_zones) —
	# verbatim copy; ONE change: the criers promise now also sets
	# chose_criers_promised, which the ch5 epilogue variant reads (the
	# criers actually ride for the shore when the lullaby ends).
	"ch5_mother": {"start": "m1", "nodes": {
		"m1": {"who": "Ansa of the Shore",
			"text": "My husband and both boys sleep in the valley. I didn't consent — I was at market, one day, ONE day, and Halla's people came through our village singing, and when I got home the beds were empty and the neighbor said they walked out SMILING. Smiling. My youngest is afraid of the dark, bearer. Nobody who knows him would believe he walked toward that ice glad.",
			"variants": [{"flag": "ch5_ansa_heard", "text": "You remember — Toma fears the dark. If the sleep breaks and he wakes far from home... someone kind should be the first thing he sees. Let it be soon.", "next": "m_more"}],
			"choices": [
				{"text": "\"Toma, was it? If the sleepers wake when this ends, I'll see the criers carry word to the shore first.\"",
					"resonance": 4.0, "flags": {"ch5_ansa_heard": true, "chose_criers_promised": true}, "next": "m_kind"},
				{"text": "\"Hold to this: the singing needs a singer. Singers can be stopped.\"",
					"resonance": 0.0, "flags": {"ch5_ansa_heard": true}, "next": "m_flint"},
				{"text": "Unfold Ottar's paper and read her the spring song — the thaw, the river, the boots by the door.",
					"req_flag": "ch5_verse_taken", "req_not_flag": "ch5_verse_given",
					"resonance": 2.0, "lose_item": "ch5_spring_verse",
					"flags": {"ch5_verse_given": true}, "next": "m_song"},
			]},
		"m_kind": {"who": "Ansa of the Shore", "text": "Toma. Yes. ...You said WHEN, not if. I've had a winter of 'if' from every warden and clerk on this shore. I'm going to keep your 'when', bearer — don't make it a lie.", "next": ""},
		"m_flint": {"who": "Ansa of the Shore", "text": "Stopped. ...There's a word everyone's been walking around all winter. Aye. Stop her, bearer — and if my boys can hear anything down there, they'll hear the quiet where the lullaby was, and know to swim for it.", "next": ""},
		"m_more": {"who": "Ansa of the Shore", "text": "Go on, bearer. The valley doesn't wait, and neither do I — I count wagons. Somebody should.",
			# Withheld-verse revisits route past the temptation (one -4, not
			# a lever): reading it to her stays reachable at m_hold2. The
			# given-state variant outranks it (withheld-then-read reads true).
			"variants": [
				{"flag": "ch5_verse_given", "text": "She counts wagons, south-facing now. Somewhere down the shore an old song is waiting for a boy to wake and ask for the river part twice.", "next": ""},
				{"flag": "ch5_verse_withheld", "text": "She counts wagons. The paper rides your ribs where you left it, folded twice — one thaw, one river, unspent.", "next": "m_hold2"},
			],
			"choices": [
				{"text": "Unfold Ottar's paper and read her the spring song — the thaw, the river, the boots by the door.",
					"req_flag": "ch5_verse_taken", "req_not_flag": "ch5_verse_given",
					"resonance": 2.0, "lose_item": "ch5_spring_verse",
					"flags": {"ch5_verse_given": true}, "next": "m_song"},
				{"text": "Leave the skald's paper folded in your pack. Spring is scarce currency this winter — and the only warm thing you own rides better unspent.",
					"req_flag": "ch5_verse_taken", "req_not_flag": "ch5_verse_given",
					"resonance": -4.0, "flags": {"ch5_verse_withheld": true}, "next": "m_hold"},
			]},
		"m_hold2": {"who": "Ansa of the Shore", "text": "Still here, bearer? The wagons don't count themselves.",
			"choices": [
				{"text": "Unfold Ottar's paper and read her the spring song — the thaw, the river, the boots by the door.",
					"req_flag": "ch5_verse_taken", "req_not_flag": "ch5_verse_given",
					"resonance": 2.0, "lose_item": "ch5_spring_verse",
					"flags": {"ch5_verse_given": true}, "next": "m_song"},
			],
			"next": ""},
		"m_hold": {"who": "Narrator", "text": "The paper stays where it is, against your ribs, one thaw and one river folded twice. Ansa goes back to counting wagons; she never knew there was a spring in the room, so she loses nothing — that's the arithmetic you do on the walk out, and it balances, and the Ember admires how neatly. You are still carrying somebody's boots-by-the-door through a valley of open beds. It rides warm. It would have LANDED warmer.", "next": ""},
		"m_song": {"who": "Narrator", "text": "You read it low, like the skald said. A thaw. A river loosening. Somebody's boots drying by a door, because the somebody came HOME. Ansa listens the whole way through with her eyes shut, and when she opens them she is looking SOUTH — the first time you've seen her face that way. \"Toma will ask for the river part twice,\" she says. \"When he wakes, I'll have it ready. Thank the skald. Tell him it landed.\"", "next": ""},
	}},

	# OVERRIDES ch5_quests.gd's "ch5_wander_skald" (which overrode
	# ch5_zones) — verbatim copy, extended: Ottar named his fee ("bring me
	# back the LOOK on the first face that hears it") and now collects it.
	"ch5_wander_skald": {"start": "k1", "nodes": {
		"k1": {"who": "Skald Ottar",
			"text": "A song for the road, southerner? I've a hundred of winter and one of spring, and nobody ever asks for the spring one. Winter-clan taste. We like our songs the way we like our news: bad, but survivable.",
			"variants": [
				{"flag": "ch5_fee_paid", "text": "The skald is retuning for something new — a verse about a window, he says, and a look turning south. You've been paid up since you delivered it.", "next": ""},
				{"flag": "ch5_verse_given", "text": "It reached her? Then you're standing there OWING me, southerner — the fee, we agreed: the look on the first face that heard it. Out with it. I don't discount.", "next": "k_fee"},
				{"flag": "ch5_ottar_met", "text": "Back for the spring song after all? Everyone comes back for it eventually. Usually the same week they start checking the ice for cracks.", "next": "k_again"},
			],
			"choices": [
				{"text": "\"Sing the spring one, skald.\"", "resonance": 2.0, "flags": {"ch5_ottar_met": true}, "next": "k_spring"},
				{"text": "\"What's the newest winter song about?\"", "flags": {"ch5_ottar_met": true}, "next": "k_winter"},
			]},
		"k_spring": {"who": "Skald Ottar", "text": "He sings it — short, unadorned, a thaw and a river and someone's boots by a door. Halfway through, three strangers at the fire go quiet and stare into their cups, and by the end a wagon-driver is weeping without noise. \"That's why nobody asks for it,\" Ottar says, retuning. \"Winter songs let you stay hard. The spring one reminds you what you're staying hard FOR.\"",
			"choices": [
				{"text": "\"Set it down in writing, skald. The Last Fire's had a winter of the Queen's hymn — let it hear yours.\"",
					"req_not_flag": "ch5_verse_taken", "resonance": 2.0,
					"side_quest": "ch5_spring_song", "gain_item": "ch5_spring_verse",
					"flags": {"ch5_verse_taken": true}, "next": "k_write"},
				{"text": "Leave the song where songs live — in the singer.",
					"req_not_flag": "ch5_verse_taken", "next": ""},
			],
			"next": ""},
		"k_winter": {"who": "Skald Ottar", "text": "The newest? 'The Ridge-Toll.' A chieftain who fed his clan on a bad bargain and died standing on it. ...Aye, THAT ridge. Songs travel faster than wagons, southerner. The clans are already deciding what the verse about YOU sounds like — I'd give them a good final line if I were you.", "next": ""},
		"k_again": {"who": "Skald Ottar", "text": "\"Once more, then. It's short — spring usually is, up here.\" A thaw, a river loosening, somebody's boots drying by a door because the somebody came home. He gives it to you whole, quieter the second time.",
			"choices": [
				{"text": "\"Set it down in writing, skald. The Last Fire's had a winter of the Queen's hymn — let it hear yours.\"",
					"req_not_flag": "ch5_verse_taken", "resonance": 2.0,
					"side_quest": "ch5_spring_song", "gain_item": "ch5_spring_verse",
					"flags": {"ch5_verse_taken": true}, "next": "k_write"},
				{"text": "Leave the song where songs live — in the singer.",
					"req_not_flag": "ch5_verse_taken", "next": ""},
			],
			"next": ""},
		"k_write": {"who": "Skald Ottar", "text": "He writes small and sure — skalds ration paper like meat — and folds it twice before it leaves his hand. \"Tell whoever hears it that it wants a low voice and a fire going. And southerner — bring me back the LOOK on the first face that hears it. That's my fee, and I don't discount.\"", "next": ""},
		# --- The fee, collected: the promise the verse rode out on.
		"k_fee": {"who": "Skald Ottar", "text": "He sets the lute flat across his knees. Collections, clearly, are serious business.",
			"choices": [
				{"text": "\"She shut her eyes the whole way through, skald. When she opened them she was looking SOUTH — first time all winter. And she says her boy will ask for the river part twice.\"",
					"resonance": 2.0, "flags": {"ch5_fee_paid": true}, "next": "k_paid"},
				{"text": "\"The look's still settling. You'll have it whole, another night.\"", "next": ""},
			]},
		"k_paid": {"who": "Skald Ottar", "text": "\"Looking south.\" He says it twice, tasting the meter. \"And twice for the river part. ...There's my next verse, southerner, delivered in full — the spring song's first review in a hundred winters, and it's a WINDOW turning. Paid in full. Better than coin. Coin never once looked south.\"", "next": ""},
	}},
}
