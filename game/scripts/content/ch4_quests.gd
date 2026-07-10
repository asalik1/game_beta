## Chapter 4 side quests — The Slagfields (QUESTS_TASKS.md Q4).
## Three flag-chain quests on the side-quest engine, hooked into
## EXISTING ch4 rooms/NPCs (no zones appended):
##   out_of_tolerance — Brann wants proof the foundries can still cool;
##                      the only slag that qualifies sits in the Cold Forge.
##   nix_receipts     — Nix refunds crew five's charm money to the one
##                      crew member still walking: Smith Petra.
##   quench_prayer    — Old Smith Harl's water-quenched token, left at
##                      the Ember Font as a comparison, not an offering.
## Overridden convos are copied VERBATIM from ch4_zones.gd and extended
## (Story.load_content merges module CONVOS over the base).

const QUEST_ITEMS := {
	"slag_core": {"name": "Cold Slag Core", "grade": "C",
		"desc": "A fist-sized core of foundry slag, cold all the way through — sixty years in the one room the mountain won't listen through. Overseer Brann wants it for his ledger table."},
	"nix_refund": {"name": "Nix's Refund Pouch", "grade": "C",
		"desc": "Twelve verdict charms' worth of crew five's wages, returned with the receipts. Nix was very clear: don't dress it up. It's a refund. For Smith Petra at the Cinder Gate."},
	"harl_token": {"name": "Water-Quenched Token", "grade": "C",
		"desc": "A small iron token, quenched in river water the old way. Harl wants it left on the Ember Font's lip — one piece of iron that owes the deep nothing."},
}

const SIDE_QUESTS := {
	"out_of_tolerance": {
		"name": "Out of Tolerance",
		"chapter": "ch4",
		"desc": "Overseer Brann can prove the heats climb; he wants one number that goes the other way. Slag left in the Cold Forge goes honestly, completely cold — chip him a core of it.",
		"steps": [
			{"flag": "ch4_core_taken", "text": "Chip a cold core from the slag heap in the Cold Forge"},
			{"flag": "ch4_core_returned", "text": "Bring it back to Overseer Brann at the Cinder Gate"},
		],
		"reward": {"gold": 180},
	},
	"nix_receipts": {
		"name": "Nix's Receipts",
		"chapter": "ch4",
		"desc": "Crew five bought twelve verdict charms the week before the vents took them. Nix keeps receipts, and one of the crew is still walking. The refund matters more than the coin.",
		"steps": [
			{"flag": "ch4_refund_taken", "text": "Take crew five's wages back from Nix's stall"},
			{"flag": "ch4_refund_given", "text": "Bring the pouch to Smith Petra at the Cinder Gate"},
		],
		"reward": {"gold": 150},
	},
	"quench_prayer": {
		"name": "The Quench Prayer",
		"chapter": "ch4",
		"desc": "Old Smith Harl hammered a token and quenched it in river water, the old ceremony, the whole hiss. He wants it left at the font the maps say not to dig toward — so the Judge can weigh a blade that owes it nothing.",
		"steps": [
			{"flag": "ch4_token_taken", "text": "Carry Harl's water-quenched token into the deep"},
			{"flag": "ch4_token_left", "text": "Set it on the lip of the Ember Font"},
		],
		"reward": {"gold": 120},
	},
}

const CONVOS := {
	# OVERRIDES ch4_zones.gd's "ch4_briefing" — the briefed variant now
	# leads to a post-briefing hub (b_rounds) carrying the Out of
	# Tolerance ask + turn-in. Briefing flow (b1..b3, autotest walks
	# choice 0) is untouched.
	"ch4_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Overseer Brann",
			"text": "You're the one who opened the Vale road. Good — freight's moving, which means my problems are now arriving FASTER. Brann, overseer of what's left of the southern foundry line.",
			"variants": [
				{"flag": "ch4_briefed", "text": "The yard first, bearer — Calda holds the quench line, and nothing gets past a smith who's stopped making mistakes.", "next": "b_rounds"},
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
		# --- Out of Tolerance: post-briefing hub. All choices are gated,
		# so off-quest the node reads as a plain sign-off line.
		"b_rounds": {"who": "Overseer Brann", "text": "The ledger stays open, bearer. Something else?",
			"choices": [
				{"text": "\"What would help topside, Overseer? Besides the obvious three.\"",
					"req_not_flag": "sq_on_out_of_tolerance", "next": "b_ask"},
				{"text": "Set the cold core on his ledger table. \"From the forge the heat won't enter. Sixty years, and it stayed slag.\"",
					"req_flag": "ch4_core_taken", "req_not_flag": "ch4_core_returned",
					"lose_item": "slag_core", "flags": {"ch4_core_returned": true}, "next": "b_core_done"},
				{"text": "\"Just passing, Brann.\"", "req_flag": "sq_on_out_of_tolerance", "next": ""},
			]},
		"b_ask": {"who": "Overseer Brann", "text": "Honestly? Proof of the OTHER direction. Every instrument down here can prove the heats climb — the Accord's sapper will recite you the slope. I want one number that goes the other way. There's a forge in the works that never lit; the crews eat lunch in it. Slag left in that room goes honestly, completely cold. Chip me a core of it. When the Compact asks whether the foundries can still cool, I want to hand them something with WEIGHT.",
			"choices": [
				{"text": "\"One cold core, then. The mountain owes you that much arithmetic.\"",
					"side_quest": "out_of_tolerance", "next": "b_ask_yes"},
				{"text": "\"Not my errand, Overseer. The deep's waiting.\"", "next": "b_ask_no"},
			]},
		"b_ask_yes": {"who": "Overseer Brann", "text": "The old crews call it the Cold Forge — off the deep line, past the tapline camp. You'll know it: the one room down there that sounds like a room. Touch the anvil on the way out. Everyone does.", "next": ""},
		"b_ask_no": {"who": "Overseer Brann", "text": "No. Well. The ledger holds an open line, if the deep leaves you a spare hour.", "next": ""},
		"b_core_done": {"who": "Overseer Brann", "text": "He weighs it in one hand for a long moment — a lump of slag, cold through, ordinary as a loaf of bread. \"Sixty years in the one room the mountain won't listen through, and it forgot how to burn. That's not nothing, bearer. That's a PRECEDENT.\" He sets it on the ledger, dead center, where the Compact's auditors will have to move it themselves.", "next": ""},
	}},

	# OVERRIDES ch4_zones.gd's "ch4_lore_coldforge" — gains the quest-gated
	# core-chipping choice. Off-quest both choices gate away and the prop
	# reads linear, exactly as before.
	"ch4_lore_coldforge": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "One forge in the works has never lit — the firebrick is virgin, the flue unstained. The founding crew's log, chained to the anvil, explains in a careful hand: THE HEAT WOULD NOT ENTER THIS ONE. WE BUILT IT ANYWAY, TO HAVE SOMEWHERE TO STAND. Sixty years of foundrymen have eaten lunch here, in the one room the mountain won't listen through. The anvil is worn bright from people touching it on the way out.",
			"choices": [
				{"text": "Chip a core from the slag heap by the virgin hearth — Brann's proof that COLD still happens here.",
					"req_flag": "sq_on_out_of_tolerance", "req_not_flag": "ch4_core_taken",
					"gain_item": "slag_core", "flags": {"ch4_core_taken": true}, "next": "l_core"},
				{"text": "Not now. Some rooms you don't take from on the first visit.",
					"req_flag": "sq_on_out_of_tolerance", "req_not_flag": "ch4_core_taken", "next": ""},
			],
			"next": ""},
		"l_core": {"who": "Narrator", "text": "The heap by the hearth gives up a fist-sized core, cold as a riverbed stone. No hiss, no whisper, no opinion — just weight, which is what proof is made of. On the way out, without deciding to, you touch the anvil.", "next": ""},
	}},

	# OVERRIDES ch4_zones.gd's "ch4_wander_charms" — Nix's restocked
	# variant now leads to the refund ask (w_refund). First-talk sales
	# pitch and both original choices are untouched.
	"ch4_wander_charms": {"start": "w1", "nodes": {
		"w1": {"who": "Charm Peddler Nix",
			"text": "Verdict charms! Genuine acquittal wax, pressed with a little scale — wear it and the fires weigh you KINDLY. Two silver. The foundry crews buy them by the dozen, so either they work or the crews die too fast to complain, and commercially speaking both keep my margins healthy.",
			"variants": [{"flag": "ch4_nix_met", "text": "Restocked! New line: appeal charms, for the already-judged. They're the same charm with a second ribbon, and before you say anything, hope with two ribbons on it is still HOPE.", "next": "w_refund"}],
			"choices": [
				{"text": "\"Do they work, Nix? Straight answer.\"", "flags": {"ch4_nix_met": true}, "next": "w_work"},
				{"text": "\"Selling acquittals from a court that's never acquitted. There's the empire's whole soul in one stall.\"", "resonance": -2.0, "flags": {"ch4_nix_met": true}, "next": "w_soul"},
			]},
		"w_work": {"who": "Charm Peddler Nix", "text": "Straight answer: the charm does nothing and the WEARING does something. A man who believes he's weighted kindly walks past the vents instead of leaning over them to listen. I sell two silver of not-leaning. Cheapest life insurance in the Slagfields, and I sleep fine.", "next": ""},
		"w_soul": {"who": "Charm Peddler Nix", "text": "Ooh, that's GOOD, can I use that? 'The empire's soul, two silver.' ...Look, bearer, the Compact sells the crews to the mountain and I sell them hope on the way down. One of us is the villain and it isn't the one with the wax press.", "next": ""},
		# --- Nix's Receipts.
		"w_refund": {"who": "Charm Peddler Nix",
			"text": "...One thing, before you go. You know the blank plaque downstairs? Crew five bought twelve verdict charms off this stall the week before the vents took them. Paid in wages. I still have the entry — I keep RECEIPTS. And there's one of them left walking, up at the gate. Take her the coin back, will you? Don't dress it up. It's not a gift, it's not condolences. It's a refund.",
			"variants": [
				{"flag": "ch4_refund_given", "text": "You gave it to her? And she TOOK it? ...Huh. Two silver a charm, and the first thing this stall ever sold that worked cost me money. Don't spread that around — it'd ruin the margins.", "next": ""},
				{"flag": "ch4_refund_taken", "text": "The pouch, bearer — the smith at the gate, crew five's leftover. Wages go back to whoever's left to spend them. That's the whole contract.", "next": ""},
			],
			"choices": [
				{"text": "Take the pouch. \"A refund from Nix. She'll hear it exactly that way.\"",
					"side_quest": "nix_receipts", "gain_item": "nix_refund", "resonance": 2.0,
					"flags": {"ch4_refund_taken": true}, "next": "w_r_yes"},
				{"text": "\"Why now, Nix? The margins were healthy last week.\"", "next": "w_r_why"},
				{"text": "\"Deliver your own conscience.\"", "resonance": -1.0, "next": "w_r_no"},
			]},
		"w_r_yes": {"who": "Charm Peddler Nix", "text": "Exactly that way, good. ...Twelve charms, none of them worked, and the one crewmate they'd have wanted weighted kindly wasn't even downstairs that shift. There's no wax for that. There's just the coin, and the receipts.", "next": ""},
		"w_r_why": {"who": "Charm Peddler Nix", "text": "A preacher came past my stall — white as new wax, asking whether I'd ever once sold a charm to somebody the court found INNOCENT. So I checked the receipts. Court's never found anyone innocent. Which means either every charm I've sold has failed... or nobody down here has been TRIED yet, and I'm selling tickets to a docket. The refund's cheaper than the answer.", "next": "w_refund"},
		"w_r_no": {"who": "Charm Peddler Nix", "text": "Ha. Fair. I'd carry it myself, but the stall doesn't walk and neither does my nerve. It'll keep. Receipts always keep.", "next": ""},
	}},

	# OVERRIDES ch4_zones.gd's "ch4_survivor" — Petra gains two gated
	# refund-delivery framings (appended at the END of s1's choices), and
	# her names-told variant now continues to s_after so the delivery
	# stays reachable after the plaque conversation.
	"ch4_survivor": {"start": "s1", "nodes": {
		"s1": {"who": "Smith Petra (Crew Five)",
			"text": "Crew five, that's me. The plaque downstairs is blank because I keep NOT dying and the engraver keeps waiting. Everyone else went in the vents. I was topside with a broken wrist — clumsiest day of my life, and the only reason I have a rest of my life.",
			"variants": [
				{"flag": "ch4_petra_told", "text": "You'll really carve them? All nine names, not 'CREW FIVE, WITH REGRET'? ...I sharpened my good chisel. When the beast's dead, I'll cut the letters myself.", "next": "s_after"},
				{"band": "tempted", "text": "...You stand like the heat stands, you know that? Leaning in. The ones who leaned in are all on plaques now. Free advice from crew five's leftover."},
			],
			"choices": [
				{"text": "\"Give me their names. When the beast is dead, they go on the plaque — all nine, carved proper.\"",
					"resonance": 5.0, "flags": {"ch4_petra_told": true}, "next": "s_names"},
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
		# --- Nix's Receipts: delivery, both framings.
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
			],
			"next": ""},
	}},

	# OVERRIDES ch4_zones.gd's "ch4_wander_smith" — Harl's met variant now
	# leads to the token ask (w_token). First-talk flow untouched.
	"ch4_wander_smith": {"start": "w1", "nodes": {
		"w1": {"who": "Old Smith Harl",
			"text": "Fifty years at the anvil, and I'll tell you what changed: we used to quench in WATER. River water, rain water — the blade hissed and that was the whole ceremony. Now it's slag baths and whisper-tempering and edges that never dull. Everyone's thrilled. Nobody asks what the blades are FOR, ever since the blades started being for something.",
			"variants": [{"flag": "ch4_harl_met", "text": "Still here. Still quenching in water, the old way. My blades dull, and I have never once loved them more.", "next": "w_token"}],
			"choices": [
				{"text": "\"What are the blades for, Harl?\"", "flags": {"ch4_harl_met": true}, "next": "w_for"},
				{"text": "\"Edges that never dull win wars, Harl. Point me at the whisper-tempered stall.\"",
					"resonance": -1.0, "flags": {"ch4_harl_met": true}, "next": "w_edge"},
			]},
		"w_for": {"who": "Old Smith Harl", "text": "The heir. Nobody SAYS it, but every order the Compact places is armory-shaped, crown-shaped, procession-shaped. They're forging for a coronation, bearer. And the mountain under us keeps offering better steel, and nobody upstairs finds that combination interesting. I find it interesting enough to quench in water.", "next": ""},
		"w_edge": {"who": "Old Smith Harl", "text": "Third stall past the tapline — you'll hear it before you see it; the grindstones hum a note grindstones don't have. Go on, then. Fifty years at the anvil says you'll be back to ask what the edge costs, and I'll still be here, and the water will still be free.", "next": ""},
		# --- The Quench Prayer.
		"w_token": {"who": "Old Smith Harl",
			"text": "Since you're bound for the deep anyway — I hammered something last night. A little iron token, quenched in river water, the old ceremony, the whole hiss. I want it left at that font the maps say not to dig toward. Not as an offering — as a COMPARISON. Let the Judge weigh one piece of iron that owes it nothing.",
			"variants": [
				{"flag": "ch4_token_left", "text": "You left it on the lip, and the font said nothing, and took nothing, and you walked out whole. Bearer, I've gotten more theology out of that one fact than fifty years of sermons.", "next": ""},
				{"flag": "ch4_token_taken", "text": "The token rides with you? Good. Set it on the font's lip and walk out. Don't listen, don't bargain. The water already said everything worth saying — that's what the hiss IS.", "next": ""},
			],
			"choices": [
				{"text": "Take the token. \"One blade that owes the deep nothing. The Judge could use a reference reading.\"",
					"side_quest": "quench_prayer", "gain_item": "harl_token", "resonance": 1.0,
					"flags": {"ch4_token_taken": true}, "next": "w_t_yes"},
				{"text": "\"Carry your own prayers, smith.\"", "next": "w_t_no"},
			]},
		"w_t_yes": {"who": "Old Smith Harl", "text": "Reference reading — HA. Fifty years and I finally meet somebody who talks tolerances back at the mountain. It's just iron, bearer. That's the entire message. Just iron, and it cooled anyway, and nobody had to whisper to it.", "next": ""},
		"w_t_no": {"who": "Old Smith Harl", "text": "Aye, fair. It'll sit on my bench, then. It's patient. That's the other thing water teaches.", "next": ""},
	}},

	# OVERRIDES ch4_zones.gd's "ch4_shrine_font" — gains the gated
	# token-deposit choice (appended at the END, does NOT set
	# ember_font_touched: the shrine's own three-way choice survives a
	# deposit visit). The touched variant continues to f_more so the
	# deposit stays reachable after the shrine choice is spent.
	"ch4_shrine_font": {"start": "f1", "nodes": {
		"f1": {"who": "Narrator",
			"text": "A font of living slag, perfectly round, bubbling at blood-heat in a chamber the foundry maps mark DO NOT DIG. The Ember in you leans toward it like iron toward a lodestone. In the slag, faintly, a voice keeps time — measuring, weighing, finding wanting. It would teach you TOLERANCES, if you put your hand in. Calda did.",
			"variants": [{"flag": "ember_font_touched", "text": "The font bubbles on, patient as case law. Whatever passed between you is on the record now — the deep keeps better minutes than the Compact.", "next": "f_more"}],
			"choices": [
				{"text": "Quench your blade-hand in the slag for one breath — pay the pain honestly, take nothing, and let the Judge weigh THAT.",
					"resonance": 8.0, "flags": {"ember_font_touched": true}, "next": "f_pay"},
				{"text": "Lean close and LISTEN. Perfect tolerances, offered free — only a fool leaves knowledge on the table.",
					"resonance": -8.0, "flags": {"ember_font_touched": true, "chose_heard_judge": true}, "next": "f_listen"},
				{"text": "Back out of the chamber. The maps said DO NOT DIG; the miners knew something.",
					"resonance": 0.0, "flags": {"ember_font_touched": true}, "next": "f_leave"},
				{"text": "Set Harl's water-quenched token on the font's lip — iron that owes the deep nothing — and let the Judge weigh a comparison.",
					"req_flag": "ch4_token_taken", "req_not_flag": "ch4_token_left",
					"lose_item": "harl_token", "resonance": 3.0,
					"flags": {"ch4_token_left": true}, "next": "f_token"},
			]},
		"f_pay": {"who": "Narrator", "text": "One breath. The pain is total and clarifying, and the voice in the slag goes SILENT — genuinely surprised. You take your hand back whole; the slag doesn't burn what doesn't bargain. Somewhere below, a verdict is quietly vacated. The Ember in you sits straighter for days.", "next": ""},
		"f_listen": {"who": "Narrator", "text": "The tolerances arrive: how hard to swing, exactly. Where the flaw in any guard lives, exactly. It is TRUE, all of it, and your hands feel surer already — and underneath the knowing, faint as a stamp on hot metal, the sense of a docket somewhere gaining one more name. The knowledge was free. The listening wasn't.", "next": ""},
		"f_leave": {"who": "Narrator", "text": "You back out the way the miners backed out. The voice in the slag does not call after you — courts don't chase. But as the chamber door closes you hear, distinctly, the sound of a case file being set aside for later.", "next": ""},
		# --- The Quench Prayer: deposit, and the post-touch revisit hub.
		"f_more": {"who": "Narrator", "text": "The slag turns over, slow as case law reconsidering itself.",
			# Kept-token revisits route past the temptation (one -2, not a
			# lever): the deposit alone stays on the table at f_more2. The
			# left-state variant outranks it (kept-then-deposited reads true).
			"variants": [
				{"flag": "ch4_token_left", "text": "The slag turns over, slow as case law reconsidering itself. Harl's iron sits on the lip where you left it — read, weighed, inadmissible, filed.", "next": ""},
				{"flag": "ch4_token_kept", "text": "The slag turns over and finds you again — the pocket where the token rides, precisely. Courts, it seems, remember what's been withheld from evidence.", "next": "f_more2"},
			],
			"choices": [
				{"text": "Set Harl's water-quenched token on the font's lip — iron that owes the deep nothing — and let the Judge weigh a comparison.",
					"req_flag": "ch4_token_taken", "req_not_flag": "ch4_token_left",
					"lose_item": "harl_token", "resonance": 3.0,
					"flags": {"ch4_token_left": true}, "next": "f_token"},
				{"text": "Keep Harl's token in your pocket a while longer. Iron that owes the deep nothing — down here, better it owes YOU.",
					"req_flag": "ch4_token_taken", "req_not_flag": "ch4_token_left",
					"resonance": -2.0, "flags": {"ch4_token_kept": true}, "next": "f_keep"},
			],
			"next": ""},
		"f_more2": {"who": "Narrator", "text": "The font bubbles at blood-heat, keeping its docket. The comparison is still admissible — whenever the iron stops owing you.",
			"choices": [
				{"text": "Set Harl's water-quenched token on the font's lip — iron that owes the deep nothing — and let the Judge weigh a comparison.",
					"req_flag": "ch4_token_taken", "req_not_flag": "ch4_token_left",
					"lose_item": "harl_token", "resonance": 3.0,
					"flags": {"ch4_token_left": true}, "next": "f_token"},
			],
			"next": ""},
		"f_keep": {"who": "Narrator", "text": "Your thumb finds the token's worn face without asking you first — the same spot Harl's thumb wore into it, probably, in that room the mountain can't hear. Nix would price this correctly: two silver of not-leaning, kept for yourself. The font bubbles on. Comparisons, it seems to agree, can wait; the deep has never once run short of patience, and now neither has your pocket.", "next": ""},
		"f_token": {"who": "Narrator", "text": "You set the little token on the lip. For one full breath, nothing — then the bubbling STOPS. The voice in the slag reads the iron the way a judge reads a document from a jurisdiction it does not recognize: river water, patience, a maker who asked for nothing back and got exactly that. The bubbling resumes, a shade slower. Case noted. Precedent — inadmissible, and filed anyway.", "next": ""},
	}},
}
