## Chapter 3 side quests — The Unburied Vale (Q3, QUESTS_TASKS.md).
## Content module (see README.md): three flag-chain side quests hooked
## onto EXISTING ch3 rooms/NPCs — no new zones.
##   - The Unfilled Row: Cantor Ilse wants the Vale's old markers copied
##     (Hollow Chapel headstone -> reliquary placards -> report back).
##   - Bread for the Kneeling: Old Fenna's loaf carried from the Vigil
##     Gate to the congregation at the Kneeling Field (framing choice
##     shifts choir standing either direction).
##   - A Stone for the Sexton: Old Digger Haim's blank-cut headstone,
##     set beside Bram Tallow's plot — the last proper grave.
## Overridden convos below are FULL copies of ch3_zones.gd's current
## dicts, extended per the board rules: quest choices append at the END
## of existing choice lists, gated by req_flag/req_not_flag; "we already
## talked" variants redirect from "" to new hub nodes (the pilot's
## wander_orphan pattern) so the asks stay reachable after first contact.

const SIDE_QUESTS := {
	"ch3_unfilled_row": {
		"name": "The Unfilled Row",
		"chapter": "ch3",
		"desc": "Cantor Ilse wants the Vale's old markers copied word for word — what the stones said when graves still closed, and what the Choir's empty relic cases still promise. Evidence, for when the burying starts.",
		"steps": [
			{"flag": "row_copied_chapel", "text": "Copy Bram Tallow's headstone at the Hollow Chapel"},
			{"flag": "row_copied_reliquary", "text": "Copy the empty placards in the Reliquary of Rot"},
			{"flag": "row_reported", "text": "Bring the copies back to Cantor Ilse at the Vigil Gate"},
		],
		"reward": {"gold": 180},
	},
	"ch3_bread_kneeling": {
		"name": "Bread for the Kneeling",
		"chapter": "ch3",
		"desc": "Old Fenna baked a loaf for the congregation kneeling below the cathedral. The Choir sings at them and calls it feeding; she'd rather send actual bread.",
		"steps": [
			{"flag": "vale_bread_left", "text": "Carry Fenna's loaf to the congregation at the Kneeling Field"},
		],
		"reward": {"gold": 120},
	},
	"ch3_sexton_stone": {
		"name": "A Stone for the Sexton",
		"chapter": "ch3",
		"desc": "Old Digger Haim cut a headstone — blank, edges true — for the first grave the Vale closes in sixty years. The Sexton's, most like. It should wait where graves still mean something: beside Bram Tallow's plot.",
		"steps": [
			{"flag": "sexton_stone_left", "text": "Set Haim's stone beside the last proper grave, in the Hollow Chapel"},
		],
		"reward": {"gold": 150},
	},
}

const QUEST_ITEMS := {
	"vale_bread": {"name": "Fenna's Loaf", "grade": "C",
		"desc": "Dense, dark, still warm at the middle. Baked by a woman the Choir sang 'no' at, for the people still kneeling to the singing."},
	"sexton_stone": {"name": "The Digger's Stone", "grade": "C",
		"desc": "A headstone no bigger than a loaf, blank, edges cut true. Forty years of craft and no name yet — Haim says the Vale will provide one."},
}

const CONVOS := {
	# OVERRIDES ch3_zones.gd's "ch3_briefing" — the ch3_briefed variant's
	# next redirects "" -> "q_hub" so Ilse stays talkable after the
	# briefing (the suite's chapter walk talks to her ONCE, pre-briefing,
	# and is untouched). q_hub's index-0 choice is a harmless exit.
	"ch3_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Cantor Ilse",
			"text": "You're the bearer Maren wrote ahead about. Good. I left the Choir the day they voted to keep a dying man alive as furniture — I'll explain on the way to that sentence making sense.",
			"variants": [
				{"flag": "ch3_briefed", "text": "The Vale is east, bearer. The Sexton first — no one reaches Vess or the saint while he still has holes to put them in.", "next": "q_hub"},
				{"flag": "joined_accord", "text": "You wear the Accord's trust — Maren's letter said as much. Good. What I'm going to ask for is exactly the kind of mercy her people understand and mine call murder."},
				{"flag": "joined_cinderborn", "text": "Cinderborn colors. Hm. Your factor will tell you the Vale is 'unproductive land under hostile administration.' Listen to me first, then decide what it actually is."},
			],
			"next": "b2"},
		"b2": {"who": "Cantor Ilse", "text": "The Choir does not bury its dead — rot is the land's honest truth, so the dead WALK their own funerals, forever. Sixty years of forever, now. The Vale is one open grave from gate to cathedral, and at the top of it kneels Saint Varo — the one man in Vaelscar the rot refuses. My congregation worships his misery and calls it proof.", "next": "b3"},
		"b3": {"who": "Cantor Ilse", "text": "Three stand between you and him. The Sexton, who digs and digs and never fills. Vess, the first widow they told 'no' — her scream became our liturgy, and I sang it for thirty years before I heard the words. And Varo himself, who has been BEGGING to die longer than you've been alive.",
			"choices": [
				{"text": "\"Then I'll give him what he's asking for. Gently, if the fight allows it.\"",
					"resonance": 8.0, "flags": {"ch3_briefed": true, "chose_varo_mercy": true}, "quest": "sexton", "next": "b_mercy"},
				{"text": "\"A saint, a widow, a gravedigger. Fine. Point me at whichever drops the best loot.\"",
					"resonance": -8.0, "flags": {"ch3_briefed": true, "chose_varo_spoils": true}, "quest": "sexton", "next": "b_spoils"},
				{"text": "\"I'll clear the Vale. What the Choir does about its faith afterward is not my war.\"",
					"resonance": 0.0, "flags": {"ch3_briefed": true}, "quest": "sexton", "next": "b_neutral"},
			]},
		"b_mercy": {"who": "Cantor Ilse", "text": "...Gently. Thirty years in the Choir and I never once heard that word aimed at Varo. Go east, bearer. The Sexton holds the fields — no one reaches the cathedral while he still has holes to offer.", "next": ""},
		"b_spoils": {"who": "Cantor Ilse", "text": "The shard talking, or you? ...Don't answer. Take the east road; the Sexton's fields first. And bearer — the saint's misery has outlived four looters that I know of. Their gear is still up there, if inventory is what moves you.", "next": ""},
		"b_neutral": {"who": "Cantor Ilse", "text": "Not your war. Mm. The Vale has heard that from every passer-through for sixty years — it's how the grave count got this high. East, then. The Sexton first.", "next": ""},
		# ---- The Unfilled Row (side quest): ask, accept, report.
		"q_hub": {"who": "Cantor Ilse", "text": "Something more, bearer? The road east won't clear itself, but I can spare the breath.",
			"choices": [
				{"text": "\"Nothing, Cantor. Just passing.\"", "next": ""},
				{"text": "\"You keep glancing at the old stones when you think no one's watching. Out with it.\"",
					"req_not_flag": "sq_on_ch3_unfilled_row", "next": "q_ask"},
				{"text": "Hand over the copies — Bram Tallow's stone, and the reliquary's empty placards, word for word.",
					"req_flag": "row_copied_reliquary", "req_not_flag": "row_reported",
					"resonance": 2.0, "flags": {"row_reported": true}, "next": "q_row_done"},
			]},
		"q_ask": {"who": "Cantor Ilse", "text": "The Choir teaches that the Vale was always theirs — sixty years old, and 'always' already. But the stones remember otherwise. Bram Tallow's marker at the Hollow Chapel, cut when graves still CLOSED. And the cathedral's reliquary — every case empty, every placard a promise they never once filled. Copy me both, word for word. When the burying starts again, someone will need proof of what this place was. And of what the Choir only claimed it was.",
			"choices": [
				{"text": "\"I'll copy your stones, Cantor. Word for word.\"",
					"resonance": 2.0, "side_quest": "ch3_unfilled_row", "next": "q_accept"},
				{"text": "\"I'm here to put three things in the ground, not to take dictation.\"", "next": "q_refuse"},
			]},
		"q_accept": {"who": "Cantor Ilse", "text": "The chapel first — it's the nearer walk, and Bram's stone is the oldest true thing left standing here. The reliquary after; it sits high, near the cathedral, so mind yourself. And bearer... thank you. The Choir burned its records the day it decided forever needed no ledger.", "next": ""},
		"q_refuse": {"who": "Cantor Ilse", "text": "Then put them in the ground well. The stones have waited sixty years; they'll outwait one more errand-shy bearer.", "next": ""},
		"q_row_done": {"who": "Cantor Ilse", "text": "'BRAM TALLOW, BURIED PROPER.' And placards for relics a rotless saint could never leave behind. ...There it is, on one page: the faith, and the fraud it kneels on. When Varo rests and the digging starts, this goes to whoever writes the Vale's next chapter. You have my thanks — and the Choir's, though they'd choke to hear it.", "next": ""},
	}},

	# OVERRIDES ch3_zones.gd's "ch3_refugee" — the ch3_fenna_promised
	# variant redirects "" -> "r_bread": Fenna bakes for the kneeling,
	# but only for the bearer who answered her kindly. Cold-path players
	# never see the offer; that is Fenna keeping her own accounts.
	"ch3_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Old Fenna",
			"text": "My son walks the Misted Fields. Fourth from the alder, grey coat. The Choir says that's him honored. I say I sewed that coat for a living boy and I want it BACK on a dead one, in the ground, where coats and sons go.",
			"variants": [
				{"band": "tempted", "text": "You've got the look the Choir cantors get before they start explaining why my grief is holy. Don't. Just — if you pass the fourth grave from the alder, grey coat... let him fall facing home."},
				{"flag": "ch3_fenna_promised", "text": "Fourth from the alder. Grey coat. Facing home. You remembered. That's more than the flame's given me in sixty years.", "next": "r_bread"},
			],
			"choices": [
				{"text": "\"Fourth from the alder, grey coat. If it's my hand that fells him, he falls facing home.\"",
					"resonance": 4.0, "flags": {"ch3_fenna_promised": true}, "next": "r_kind"},
				{"text": "\"The things out there aren't sons anymore. The sooner you learn that, the lighter you'll walk.\"",
					"resonance": -4.0, "next": "r_cold"},
			]},
		"r_kind": {"who": "Old Fenna", "text": "Facing home. Yes. ...The Choir sang at me for sixty years and never once said anything that useful.", "next": ""},
		"r_cold": {"who": "Old Fenna", "text": "Lighter. Aye. You sound like the shard's already teaching you to travel light. Keep the lesson — I'll keep the coat.", "next": ""},
		# ---- Bread for the Kneeling (side quest): the offer.
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

	# OVERRIDES ch3_zones.gd's "ch3_shrine_kneeling" — delivery choices
	# append at the END of k1's shrine choices (quest-gated, invisible
	# otherwise), and the kneeling_answered variant redirects "" ->
	# "k_after" so the loaf can still be delivered after the congregation
	# has been answered (k_after's index-0 choice is a harmless exit).
	"ch3_shrine_kneeling": {"start": "k1", "nodes": {
		"k1": {"who": "Narrator",
			"text": "A field of kneeling Choir faithful, unarmed, between you and the cathedral doors. They do not attack. They do not move. An old cantor rises from the front row, hands open: \"You've come to take our saint. We know. We heard the bells count you up the hill. Please — he is all the proof we have that the rot CHOOSES. Without him, our sixty years of grief were just... grief.\"",
			"variants": [{"flag": "kneeling_answered", "text": "The congregation still kneels, but a lane stands open through them now — they made it themselves, after your answer. Whatever you told them, they are still deciding what it meant.", "next": "k_after"}],
			"choices": [
				{"text": "\"Your saint has begged sixty years to die. I'm not taking him from you — I'm returning him to himself.\"",
					"resonance": 8.0, "flags": {"kneeling_answered": true, "chose_told_congregation": true}, "faction": {"choir": 2}, "next": "k_truth"},
				{"text": "\"Proof? He's a wick feeding the thing that will eat you all. Kneel to THAT if you need something holy.\"",
					"resonance": -6.0, "flags": {"kneeling_answered": true}, "faction": {"choir": -4, "accord": 2}, "next": "k_scorn"},
				{"text": "Walk through them without a word. Their faith is not yours to argue with, and the saint is waiting.",
					"resonance": -2.0, "flags": {"kneeling_answered": true}, "next": "k_silent"},
				{"text": "Set Fenna's loaf down before the front row. \"From one who grieves as you do. No sermon with it.\"",
					"req_flag": "sq_on_ch3_bread_kneeling", "req_not_flag": "vale_bread_left",
					"resonance": 2.0, "faction": {"choir": 2}, "lose_item": "vale_bread",
					"flags": {"vale_bread_left": true}, "next": "k_bread_kind"},
				{"text": "Drop Fenna's loaf where they kneel. \"Eat. Your saint can't, and the singing feeds nobody.\"",
					"req_flag": "sq_on_ch3_bread_kneeling", "req_not_flag": "vale_bread_left",
					"resonance": -2.0, "faction": {"choir": -2}, "lose_item": "vale_bread",
					"flags": {"vale_bread_left": true}, "next": "k_bread_cold"},
			]},
		"k_truth": {"who": "Narrator", "text": "The old cantor's mouth works. \"Returning him—\" He stops. Somewhere in the rows behind him, one voice — young, cracked — says: \"...he does scream at night. We all hear it. We SING over it.\" The kneeling field is very quiet as it opens you a lane. Grief, you understand suddenly, has been waiting sixty years for permission to just be grief.", "next": ""},
		"k_scorn": {"who": "Narrator", "text": "The word WICK moves through the kneeling rows like cold water. Some flinch. Some harden — you have just handed the Choir's next generation its favorite story about the day the unbeliever spat on their proof. The lane they open you is wide, and no one in it will meet your eyes.", "next": ""},
		"k_silent": {"who": "Narrator", "text": "You walk, and they lean out of your path like grass. No argument, no absolution — just a bearer with a job, wading through sixty years of other people's meaning. The Ember approves of the efficiency. That is precisely what bothers you about it.", "next": ""},
		# ---- Bread for the Kneeling (side quest): delivery + revisits.
		"k_after": {"who": "Narrator", "text": "The lane through the congregation holds. Heads stay bowed as you pass — but they know your step now, and the kneeling field breathes around it.",
			"choices": [
				{"text": "Pass on through the lane.", "next": ""},
				{"text": "Set Fenna's loaf down before the front row. \"From one who grieves as you do. No sermon with it.\"",
					"req_flag": "sq_on_ch3_bread_kneeling", "req_not_flag": "vale_bread_left",
					"resonance": 2.0, "faction": {"choir": 2}, "lose_item": "vale_bread",
					"flags": {"vale_bread_left": true}, "next": "k_bread_kind"},
				{"text": "Drop Fenna's loaf where they kneel. \"Eat. Your saint can't, and the singing feeds nobody.\"",
					"req_flag": "sq_on_ch3_bread_kneeling", "req_not_flag": "vale_bread_left",
					"resonance": -2.0, "faction": {"choir": -2}, "lose_item": "vale_bread",
					"flags": {"vale_bread_left": true}, "next": "k_bread_cold"},
			]},
		"k_bread_kind": {"who": "Narrator", "text": "The old cantor looks at the loaf a long moment — dark bread, still warm at the middle, from an oven the Choir sang 'no' at sixty years ago. \"...From WHOM?\" You tell him. Hands come up out of the rows, one by one, and the loaf goes back through the kneeling field the way rain goes into dry ground. Nobody sings over it. That, you suspect, is the part Fenna wanted.", "next": ""},
		"k_bread_cold": {"who": "Narrator", "text": "The loaf lands in the grass. For a long moment nobody moves — then a boy in the third row, too young to have buried anyone properly, takes it and tears it and passes it down, eyes on you the whole time like a dare. They eat. You said the singing feeds nobody, and they eat while the old cantor's mouth sets in a line. You were right, which is not the same as being welcome.", "next": ""},
	}},

	# OVERRIDES ch3_zones.gd's "ch3_lore_chapel" — quest choices append
	# to l1 (invisible without their quests; each carries a matching
	# gated exit so the prop never forces an action). Both ch3 hooks on
	# this prop live HERE, in one override — no conflict.
	"ch3_lore_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A chapel from before the Choir, roof long gone. The headstone by the door reads: HERE LIES BRAM TALLOW, BURIED PROPER, 61 YEARS AGO — the last person in the Vale anyone put in the ground. Someone still weeds the plot. Someone has ALWAYS still weeded the plot, sixty-one years running, and the Choir has never caught them at it.",
			"choices": [
				{"text": "Copy the stone for Cantor Ilse — name, date, BURIED PROPER, word for word.",
					"req_flag": "sq_on_ch3_unfilled_row", "req_not_flag": "row_copied_chapel",
					"flags": {"row_copied_chapel": true}, "next": "l_copy"},
				{"text": "Leave the stone to its weeder.",
					"req_flag": "sq_on_ch3_unfilled_row", "req_not_flag": "row_copied_chapel", "next": ""},
				{"text": "Set the digger's blank stone upright beside Bram Tallow's plot, edges square to his.",
					"req_flag": "sq_on_ch3_sexton_stone", "req_not_flag": "sexton_stone_left",
					"resonance": 3.0, "lose_item": "sexton_stone",
					"flags": {"sexton_stone_left": true}, "next": "l_stone"},
				{"text": "Not yet. The stone rides a while longer.",
					"req_flag": "sq_on_ch3_sexton_stone", "req_not_flag": "sexton_stone_left", "next": ""},
			],
			"next": ""},
		"l_copy": {"who": "Narrator", "text": "Name, date, BURIED PROPER — four words and sixty-one years of contradiction, copied in the time it takes the mist to cross the yard. The weeded plot watches you work. On the way out you find yourself stepping around it, careful of the edges, the way you would around something still owned.", "next": ""},
		"l_stone": {"who": "Narrator", "text": "It stands true on the first try — forty years of craft will do that. Blank stone beside a named one: the last grave the Vale closed, and the first one it's promised to. When the Sexton finally goes in the ground, the marker will already be waiting, the way Haim has been. Somewhere behind you the mist moves through the roofless chapel like a congregation finding its seats.", "next": ""},
	}},

	# OVERRIDES ch3_zones.gd's "ch3_lore_reliquary" — the Unfilled Row's
	# second copy, gated behind the chapel's (Ilse asked for them in
	# order; the sq_on flag alone can't express the AND).
	"ch3_lore_reliquary": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The cathedral's reliquary — every case stands empty. Placards remain: A SAINT'S FINGERBONE. A SAINT'S TOOTH. A SAINT'S TEAR, PRESERVED IN WAX. The Choir venerates decay, but its saint cannot rot, so there were never relics to fill the cases with. They built the room anyway, and dusted it daily, and hoped. Sixty years of dusted hope, and upstairs a man on his knees begging to become what these cases wanted.",
			"choices": [
				{"text": "Copy the placards for Cantor Ilse — every empty promise, word for word.",
					"req_flag": "row_copied_chapel", "req_not_flag": "row_copied_reliquary",
					"flags": {"row_copied_reliquary": true}, "next": "l_copy"},
				{"text": "Leave the cases to their dusting.",
					"req_flag": "row_copied_chapel", "req_not_flag": "row_copied_reliquary", "next": ""},
			],
			"next": ""},
		"l_copy": {"who": "Narrator", "text": "FINGERBONE. TOOTH. TEAR, PRESERVED IN WAX. You copy each placard exactly, empty case by empty case, and somewhere past the third one the list stops being an inventory and becomes an indictment. Ilse wanted it word for word. Reading your own page back, you understand why: nobody would believe a paraphrase.", "next": ""},
	}},

	# OVERRIDES ch3_zones.gd's "ch3_wander_digger" — the ch3_haim_met
	# variant redirects "" -> "d_more": Haim's stone, cut in advance for
	# the first grave the Vale closes. Wanderer giver = run-conditional,
	# same as the pilot (rolls in ~half of runs).
	"ch3_wander_digger": {"start": "d1", "nodes": {
		"d1": {"who": "Old Digger Haim",
			"text": "Forty years I dug for the villages — honest holes, filled the same day. Then the Choir came and digging became LITURGY and filling became sin. I kept the spade. A man should keep the tools of the thing he was before everyone went mad.",
			"variants": [{"flag": "ch3_haim_met", "text": "Still got the spade. Still oiled. The day this chapter of madness ends, the Vale will want a man who remembers how the OTHER half of the job goes.", "next": "d_more"}],
			"choices": [
				{"text": "\"Keep it oiled, digger. The Vale's going to need you by week's end.\"",
					"resonance": 3.0, "flags": {"ch3_haim_met": true}, "next": "d_hope"},
				{"text": "\"Forty years of holes and you never once asked what they were FOR?\"",
					"resonance": -3.0, "flags": {"ch3_haim_met": true}, "next": "d_barb"},
			]},
		"d_hope": {"who": "Old Digger Haim", "text": "Week's end. Ha. You know, that's the first deadline anyone's given the Vale in sixty years? I'll sharpen the edge tonight. Deadlines deserve a sharp spade.", "next": ""},
		"d_barb": {"who": "Old Digger Haim", "text": "...They were for GRIEF, stranger. A hole is where you put grief so it doesn't follow you home. The Choir's whole madness is just sixty years of nobody being allowed to put it down. Ask your shard where IT puts yours.", "next": ""},
		# ---- A Stone for the Sexton (side quest): the offer.
		"d_more": {"who": "Old Digger Haim",
			"text": "One more thing, since your road goes where mine can't. Forty years I cut stones to go with the holes — and I've cut one more. Blank. Edges true. For the FIRST grave this Vale closes, whenever that mercy lands — the Sexton's, most like, poor mad thing. It should wait somewhere graves still mean what they meant. Bram Tallow's plot, at the old chapel. Last man anyone buried proper. Set my stone beside his.",
			"variants": [{"flag": "sexton_stone_left", "text": "You set it by Bram's plot? Square to his? ...Then it's done right, and the first grave this Vale closes won't go unmarked. Forty years I waited to be back in the business. Turns out the business waited too.", "next": ""}],
			"choices": [
				{"text": "\"Keep your stone a while yet, digger.\"", "next": ""},
				{"text": "\"Give it here. It'll wait beside the last proper grave — and it won't wait long.\"",
					"req_not_flag": "sq_on_ch3_sexton_stone", "resonance": 2.0,
					"side_quest": "ch3_sexton_stone", "gain_item": "sexton_stone", "next": "d_stone"},
			]},
		"d_stone": {"who": "Old Digger Haim", "text": "Heavier than it looks. Good — a stone should cost something to carry, else the grave under it was a lie. Square it to Bram's, mind. He was particular, and dead men's opinions are the only ones in this Vale that kept their sense.", "next": ""},
	}},
}
