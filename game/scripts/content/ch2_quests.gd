## (Q2 + Q10) Chapter 2 side quests on the side-quest engine (QUESTS_TASKS.md),
## hooked onto existing NPCs by convo override (never edit the owning module):
##   still_blue          — Sera's mill arc (existing flags) as a visible quest
##   bread_for_the_road  — Sera's loaf, carried to Scholar Ivo in the Deeps
##   ash_for_aldric      — Ivo's sealed jar of Bastion ash, back to Aldric
##   second_bell   (Q10) — Piet's cracked watch-bell, out on the Howling Fields
##   salt_reliquary(Q10) — a Choir pilgrim's salt token, laid at the reliquary
##   straight_answer(Q10)— the Null Bastion's warden logs, and Ivo's fork
##   widows_arithmetic(Q10)— the mill's grain ledger, and Sera's own name in it
##   what_cage_holds(Q10)— the caged beastkin's question about the spore hollows
##   ferryman_due  (Q10) — the fare the drowned ferryman couldn't collect
## Plus faction ARC STEP 2 (Q10): recruiter overrides route the arc-1-done desk
## to a second commission — Accord walk-the-blight-line (ch2_accord2), Cinderborn
## assay-the-seal (ch2_cinder2) — each a waypoint prop (ZONE_PROPS) + a desk report.
## Q10 adds no zones and no new spawns: the two props ride ZONE_PROPS (Q9) onto
## existing rooms by name, gated by req_flag; the quest givers are fixed camp
## NPCs (Piet, the pilgrim) or the already-overridden Ivo. All three Q10 turn-ins
## are illustrated (opener-style plates via the "scene"/cinematic hook): A
## Straight Answer (Ivo, q_straight_answer), The Second Bell (Piet, q_second_bell)
## and The Salt Reliquary (the pilgrim's hymn stops, q_salt_reliquary), plus
## Widow's Arithmetic (Sera at her ledger, q_widows_arithmetic), What the Cage
## Holds (the scout hears the hollows sing, q_what_cage_holds) and The Ferryman's
## Due (the coin on the tally, q_ferryman_due) — each Codex-generated off the
## giver's canon splash (the ferryman is an atmospheric object plate). Two custom
## sprites back the slate: the salt_token item icon and the fallen_bell prop
## (which replaced the watch_brazier stand-in on the Howling Fields bell hook).

const SIDE_QUESTS := {
	"still_blue": {
		"name": "Still Blue",
		"chapter": "ch2",
		"desc": "Widow Sera's mill stood on the Greyrun. Grey walls, and a door she repainted blue every spring for twenty years. She wants to know if the door held.",
		"steps": [
			{"kind": "kill", "target": "blightwolf", "count": 2, "flag": "mill_road_cleared",
				"text": "Cut through the blightwolves on the Greyrun road to the mill"},
			{"flag": "mill_seen", "text": "Find the mill on the Greyrun and see whether the blue door stands"},
			{"flag": "mill_told", "text": "Bring Sera the truth"},
		],
		"reward": {"gold": 150, "gem": true, "kept": "sq_kept_mill_truth"},
	},
	"bread_for_the_road": {
		"name": "Bread for the Road",
		"chapter": "ch2",
		"desc": "Sera bakes for whoever mans the far crossings. This week that means a chronicler alone among the crystals, two wastes east of anywhere.",
		"steps": [
			{"flag": "loaf_taken", "text": "Take Sera's loaf from Maren's camp"},
			{"flag": "loaf_given", "text": "Deliver it to Scholar Ivo in the Crystal Deeps"},
		],
		"reward": {"gold": 150, "gem": true, "standing": {"accord": 2}},
	},
	"ash_for_aldric": {
		"name": "Ash for the Old Knight",
		"chapter": "ch2",
		"desc": "Ser Aldric wrote one letter in thirty years: a commission for a pinch of ash off the Null Bastion's road. 'I want to know what it burns like now.'",
		"steps": [
			{"flag": "ash_taken", "text": "Take the sealed jar from Scholar Ivo in the Crystal Deeps"},
			{"flag": "ash_given", "text": "Set it by Ser Aldric's fire at Maren's camp"},
		],
		"reward": {"gold": 200, "gem": true, "kept": "sq_kept_aldric_ash"},
	},

	# ---- Q10 slate (2026-08-21) — three quests hooking ch2's camp cast and
	# the retrofit side rooms, on the Q9 seams (ZONE_PROPS props into an
	# owner's room, req_flag-gated props, add_standing forks).
	"second_bell": {
		"name": "The Second Bell",
		"chapter": "ch2",
		"desc": "Sentry Piet's watch-bell cracked in the storm that broke Korrag's pack. He can't leave his post to look for where it fell, but the wolves out on the Howling Fields still answer a bell that isn't rung anymore.",
		"steps": [
			{"flag": "bell_heard", "text": "Find Piet's fallen watch-bell out on the Howling Fields"},
			{"flag": "bell_told", "text": "Tell Piet what the storm left of it"},
		],
		"reward": {"gold": 150, "gem": true, "kept": "sq_kept_bell"},
	},
	"salt_reliquary": {
		"name": "The Salt Reliquary",
		"chapter": "ch2",
		"desc": "A Choir pilgrim can't make the walk to the old boundary stone at the Salt Reliquary. She asks you to carry her salt token there. Not as worship, she insists. As a debt.",
		"steps": [
			{"flag": "salt_taken", "text": "Take the pilgrim's salt token at Maren's camp"},
			{"flag": "salt_laid", "text": "Lay it at the boundary stone in the Salt Reliquary"},
		],
		"reward": {"gold": 160, "gem": true, "standing": {"choir": 2}},
	},
	"straight_answer": {
		"name": "A Straight Answer",
		"chapter": "ch2",
		"desc": "Scholar Ivo suspects the Null Bastion's warden logs contradict the Accord's tidy account of how the sealing went. He wants the transcription, and then he wants to decide, with you, what to do with it.",
		"steps": [
			{"flag": "logs_read", "text": "Read the warden logs inside the Null Bastion"},
			{"flag": "ivo_told", "text": "Bring Ivo what the logs actually say"},
		],
		"reward": {"gold": 200, "gem": true},
	},

	# ---- Q10 slate, second batch ------------------------------------------
	"widows_arithmetic": {
		"name": "Widow's Arithmetic",
		"chapter": "ch2",
		"desc": "The mill's blue door held, but Widow Sera wants the season's grain ledger back. She means to settle, in her own hand, exactly who the blight starved and who only claimed it did.",
		"steps": [
			{"flag": "ledger_taken", "text": "Recover the mill's grain ledger from the Greyrun mill"},
			{"flag": "sera_ledger_told", "text": "Bring the ledger to Sera at Maren's camp"},
		],
		"reward": {"gold": 150, "gem": true},
	},
	"what_cage_holds": {
		"name": "What the Cage Holds",
		"chapter": "ch2",
		"desc": "The camp's caged beastkin doesn't ask for freedom. It asks whether the spore hollows of the Sporewood still sing, and it'll know if you lie.",
		"steps": [
			{"flag": "hollow_listened", "text": "Listen at a spore hollow in the Sporewood"},
			{"flag": "cage_told", "text": "Bring the beastkin word, true or kind"},
		],
		"reward": {"gold": 180, "gem": true},
		# Strand-safe: freeing or leaving the cage before you report simply
		# forfeits the quest — no abandonment penalty for an errand you can't
		# finish because the one who asked is gone.
		"abandon": {"resonance": 0.0},
	},
	"ferryman_due": {
		"name": "The Ferryman's Due",
		"chapter": "ch2",
		"desc": "The Greyrun's ferryman poled souls out of the blight for eleven days, then tied himself to his own post and stayed. Someone should pay the fare he never could collect.",
		"steps": [
			{"flag": "due_drowned", "text": "Leave a coin at the drowned marker in the Drowned Race"},
			{"flag": "ferryman_paid", "text": "Lay the last coin on the ferryman's own tally"},
		],
		"reward": {"gold": 150, "gem": true},
	},
}

const QUEST_ITEMS := {
	"sera_loaf": {"name": "Sera's Road Loaf", "icon": "sera_loaf",
		"desc": "Dark bread in waxed cloth, oven-warm when she tied it. Baked for whoever mans the far crossings.", "grade": "C"},
	"bastion_ash": {"name": "Jar of Bastion Ash", "icon": "bastion_ash",
		"desc": "Grey ash off the Null Bastion's road, sealed and labeled in Ivo's exact hand: 'ALDRIC, AS COMMISSIONED.'", "grade": "C"},
	"salt_token": {"name": "Pilgrim's Salt Token", "icon": "salt_token",
		"desc": "A disc of grey salt, pressed by hand and worn smooth from carrying. The pilgrim wouldn't tell you whose debt it settles.", "grade": "C"},
	# No "icon": the mill ledger has no sprite asset, so omit it (the Curios
	# codex shows a graceful blank; the bag uses a glyph).
	"mill_ledger": {"name": "The Mill's Grain Ledger",
		"desc": "A water-stained account book. Twenty years of the Greyrun's harvests in a careful hand, the last season's page counted twice and once crossed out.", "grade": "C"},
}

# Faction arc STEP 2 HUD objective strings (Q10). Merged over ch2_factions.gd's
# QUESTS (ALL_QUESTS.merge is additive) — arc-1's strings stay.
const QUESTS := {
	"ch2_accord2": "Accord: walk the blight-line and map where the Waking's edge sits now",
	"ch2_cinder2": "Cinderborn: assay the recovered seal and learn what it unlocks",
}

# ZONE_PROPS (Q9): drop a quest prop into an EXISTING ch2 room by NAME, without
# editing the owning zone module or appending a zone. Both are gated so they
# only stand once their quest is live — a normal first pass never sees them.
const ZONE_PROPS := {
	"ch2": {
		# Piet's cracked bell, out where the storm dropped it. req_flag keeps it
		# from cluttering the fields until you've taken the errand.
		"The Howling Fields": [
			{"sprite": "fallen_bell", "x": 980, "y": 470, "prompt": "E — The fallen bell",
				"convo": "ch2_bell", "req_flag": "sq_on_second_bell", "req_not_flag": "bell_heard"},
		],
		# The Bastion's warden logs — only worth reading once Ivo asks for them.
		"The Null Bastion": [
			{"sprite": "pillar", "x": 760, "y": 430, "prompt": "E — Warden logs",
				"convo": "ch2_bastion_logs", "req_flag": "sq_on_straight_answer", "req_not_flag": "logs_read"},
		],
		# A spore hollow to listen at (What the Cage Holds).
		"The Sporewood": [
			{"sprite": "fungus_long", "x": 720, "y": 440, "prompt": "E — Listen at the hollow",
				"convo": "ch2_cage_hollow", "req_flag": "sq_on_what_cage_holds", "req_not_flag": "hollow_listened"},
		],
		# A drowned-soul marker for the Ferryman's Due (bog room).
		"The Drowned Race": [
			{"sprite": "bones", "x": 620, "y": 520, "prompt": "E — A drowned marker",
				"convo": "ch2_ferry_mark_a", "req_flag": "sq_on_ferryman_due", "req_not_flag": "due_drowned"},
		],
		# Faction arc-2 waypoints — gated on having ACCEPTED the arc-2 assignment
		# at the recruiter desk (accord_arc2_on / cinder_arc2_on).
		"The Lee of the Stones": [
			{"sprite": "pillar", "x": 900, "y": 430, "prompt": "E — The blight-line",
				"convo": "ch2_blight_line", "req_flag": "accord_arc2_on", "req_not_flag": "blight_line_walked"},
		],
		"The Echoing Gallery": [
			{"sprite": "pillar", "x": 840, "y": 450, "prompt": "E — Assay the seal",
				"convo": "ch2_seal_assay", "req_flag": "cinder_arc2_on", "req_not_flag": "seal_assayed"},
		],
	},
}

const CONVOS := {
	# "Ash for the Old Knight" — illustrated coda (2026-08-17). Turn-in chains
	# here via "scene"; plate quests/quest_ash_aldric.png uses Ser Aldric's
	# canon splash as the design ref (the burned-out legend at his fire).
	"ash_aldric_scene": {"cinematic": true, "start": "aa1", "nodes": {
		"aa1": {"who": "Narrator", "cue": "q_ash_aldric",
			"text": "Ser Aldric takes the sealed jar of Bastion ash in two scarred hands and holds it a long moment at his fire. The last knight of the Guard, who spent his ember on a killing blow that didn't take, keeping a commission sixty years late. He doesn't open it either. He just nods, once, soldier to soldier.",
			"next": "aa_fade"},
		"aa_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"Tell Ivo it's paid,\" he says. It's the only thing he says.", "next": ""},
	}},

	# ---- Q10 illustrated turn-in beats (opener-style plates) ---------------
	# Both plates were Codex-generated with the giver's CANON splash as the
	# design ref (splash_scholar_ivo / splash_sentry_piet) + an opener plate as
	# the style ref; installed at opening/quests/quest_<base>.png. The turn-in
	# choices chain here via "scene"; each node's "cue" stages its plate.
	"straight_answer_scene": {"cinematic": true, "start": "sa1", "nodes": {
		"sa1": {"who": "Narrator", "cue": "q_straight_answer",
			"text": "Deep in the crystal dark, Scholar Ivo reads the dead warden's words a third time. Nine names struck through, three attempts, a last line by a man who knew the seal wouldn't hold the first time. He doesn't reach for his instruments. Some readings don't want a second measure.", "next": "sa_fade"},
		"sa_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"The Accord printed the dress and buried the wound,\" he says, to the crystals as much as to you. \"Whatever we do with this now, bearer, we do it knowing.\"", "next": ""},
	}},
	"second_bell_scene": {"cinematic": true, "start": "sb1", "nodes": {
		"sb1": {"who": "Narrator", "cue": "q_second_bell",
			"text": "At the fence's edge Sentry Piet turns the split curl of bronze in the watch-fire's light. It's the bell that called Korrag's pack, snapped clean by the storm that broke them. Not neglect. The weather. His shoulders come down an inch they haven't come down in years.", "next": "sb_fade"},
		"sb_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"Twenty years I rang it on time,\" he says. \"A man wants to know the quiet wasn't his own doing.\" He pockets the shard, and stands his watch a little lighter.", "next": ""},
	}},
	"salt_reliquary_scene": {"cinematic": true, "start": "sr1", "nodes": {
		"sr1": {"who": "Narrator", "cue": "q_salt_reliquary",
			"text": "For the first time the pilgrim's hymn stops. Her clasped hands come apart, her bowed head lifts, and for a breath she's just a woman at a camp gate, the salt laid on the old imperial line, the debt at the far stone gone quiet at last.", "next": "sr_fade"},
		"sr_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"The garden noticed,\" she says. \"It notices the small doors too.\" Then the hymn returns, softer than before, and she's a psalm again.", "next": ""},
	}},
	"widows_arithmetic_scene": {"cinematic": true, "start": "wa1", "nodes": {
		"wa1": {"who": "Narrator", "cue": "q_widows_arithmetic",
			"text": "By the cook-fire Widow Sera opens the grain ledger to the last season and runs a finger down the column, and stops on a name. Her own, laid by while the row cottages went hollow. Twenty years of honest weather-paint on a blue door, and here in her own hand the one sum she never meant to be read aloud.", "next": "wa_fade"},
		"wa_fade": {"who": "Narrator", "cue": "fade",
			"text": "She doesn't look away from the line. Whatever she does with it now, she does it having seen it.", "next": ""},
	}},
	"what_cage_holds_scene": {"cinematic": true, "start": "wc1", "nodes": {
		"wc1": {"who": "Narrator", "cue": "q_what_cage_holds",
			"text": "The caged scout presses to the bars for the answer, and hears it. Its ears go back, its eyes close, and something that's not quite grief and not quite homecoming crosses its face: the Sporewood remembers being a forest, and the hollows are singing it, and the one who would have listened is here, behind timber, in a stranger's camp.", "next": "wc_fade"},
		"wc_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"The Tribes remember,\" it says, very quietly, \"who tells them true.\" And that night, the caged thing sleeps.", "next": ""},
	}},
	"ferryman_due_scene": {"cinematic": true, "start": "fd1", "nodes": {
		"fd1": {"who": "Narrator", "cue": "q_ferryman_due",
			"text": "The last coin goes into the deepest notch of the tally, the group of one, cut slowly by a man with the evening free, because the fare it counted was his own. The drowned ferryman keeps his post over the black water, rope at his waist, and the accounting balances eleven days too late, which is to say: it balances.", "next": "fd_fade"},
		"fd_fade": {"who": "Narrator", "cue": "fade",
			"text": "The bog takes nothing more tonight. It has what it was owed, and so, at last, does he.", "next": ""},
	}},

	# ---- Q10: The Second Bell (Sentry Piet) --------------------------------
	# OVERRIDES ch2_hub.gd's "ch2_sentry" — verbatim copy, extended: s1 now
	# flows to a hub (it used to end), which offers the bell errand and takes
	# the report. All new choices are req-gated, so the index-0 convo walk is
	# unchanged.
	"ch2_sentry": {"start": "s1", "nodes": {
		"s1": {"who": "Sentry Piet",
			"text": "Quiet shift, thank the flame. The wolves out there sing most nights, real wolves, mind. You learn to tell the difference by the second week.",
			"variants": [
				{"band": "tempted", "text": "...You mind standing a bit further off? No offense. We had one of yours through last month with that same look, and I still dream about the fence."},
				{"band": "steady", "text": "Shard-bearer. Good. With you standing there the night feels half as long. Maren picks the decent ones, whatever the villages say."},
			],
			"next": "sp_hub"},
		"sp_hub": {"who": "Sentry Piet", "text": "Something on your mind, or just keeping the fence company?",
			"next": "",
			"choices": [
				{"text": "\"Your bell's gone quiet. Where did it fall?\"",
					"req_not_flag": "sq_on_second_bell", "resonance": 2.0,
					"side_quest": "second_bell", "next": "sp_bell"},
				{"text": "\"I found your bell. What's left of it isn't good.\"",
					"req_flag": "bell_heard", "req_not_flag": "bell_told",
					"side_quest": "second_bell", "flags": {"bell_told": true},
					"scene": "second_bell_scene", "next": "sp_told"},
				{"text": "\"Stay sharp, Piet.\" (leave)", "next": ""},
			]},
		"sp_bell": {"who": "Sentry Piet", "text": "\"Cracked in the storm that broke Korrag's lot. You'll have heard, if you've been east. Thing is, the wolves still come to where it hung. To the sound of it, and there's no sound. I can't leave the fence to go looking. But if you're out on the Fields anyway, I'd want to know where it landed. And what shape it's in.\"", "next": ""},
		"sp_told": {"who": "Sentry Piet", "text": "He turns the split shard over twice, and something in his shoulders comes down an inch. \"Snapped, not rusted. So it wasn't neglect, it was the storm leaning on the note till the iron let go.\" He pockets it. \"Twenty years I rang that bell on time. A man wants to know the quiet wasn't his own doing. Thank you, bearer.\"", "next": ""},
	}},

	# ---- Q10: The Salt Reliquary (Choir Pilgrim) ---------------------------
	# OVERRIDES ch2_factions.gd's "ch2_choir_pilgrim" — verbatim copy, extended:
	# the first-contact paths (listen / rebuke / revisit) now flow to a hub
	# that carries the salt errand, so she stays talkable after one meeting.
	"ch2_choir_pilgrim": {"start": "h1", "nodes": {
		"h1": {"who": "Choir Pilgrim",
			"text": "A grey-wrapped pilgrim sways by the gate, humming a hymn with no words you know. The sentries won't touch her. \"The rot is honest,\" she says, to no one. \"It only takes what was already leaving.\"",
			"variants": [
				{"flag": "heard_litany", "text": "The pilgrim inclines her head as you pass. \"The Choir keeps a place for those who listened once,\" she murmurs.", "next": "hp_hub"},
			],
			"next": "h2"},
		"h2": {"who": "Choir Pilgrim", "text": "She notices you, or notices the shard. \"It hums our hymn too, bearer. Will you hear one verse? Nothing is asked. The Choir doesn't recruit. It waits.\"",
			"choices": [
				{"text": "Listen to the verse. (It costs nothing. Probably.)",
					"flags": {"heard_litany": true}, "faction": {"choir": 6},
					"resonance": -2.0, "next": "h_listen"},
				{"text": "\"Take your rot-psalms away from these people.\"",
					"flags": {"heard_litany": true}, "faction": {"choir": -6},
					"resonance": 2.0, "next": "h_rebuke"},
			]},
		"h_listen": {"who": "Narrator", "text": "The verse is about a garden that stopped pretending. It's beautiful the way a flooded quarry is beautiful, and it stays in your head three days longer than you'd like.", "next": "hp_hub"},
		"h_rebuke": {"who": "Choir Pilgrim", "text": "\"The garden doesn't mind,\" she says mildly, and keeps humming. Somehow that's worse than an argument.", "next": "hp_hub"},
		"hp_hub": {"who": "Choir Pilgrim", "text": "\"One thing, since you walk where I cannot. There's a boundary stone out in the salt, the old reliquary. A debt of mine is owed there. Salt for salt.\" A worn grey disc waits in her open hand, not quite offered yet.",
			"next": "",
			"choices": [
				{"text": "Take the salt token. \"I'll lay it at the stone.\"",
					"req_not_flag": "salt_taken", "resonance": 2.0,
					"gain_item": "salt_token", "flags": {"salt_taken": true},
					"side_quest": "salt_reliquary", "next": "hp_take"},
				{"text": "\"Whose debt is it?\"", "req_not_flag": "salt_taken", "next": "hp_why"},
				{"text": "\"The stone's quiet now, pilgrim.\"", "req_flag": "salt_laid",
					"scene": "salt_reliquary_scene", "next": "hp_done"},
				{"text": "\"Not today.\" (leave)", "next": ""},
			]},
		"hp_take": {"who": "Choir Pilgrim", "text": "\"Salt keeps. It won't spoil on the road, and neither will the debt.\" She folds your fingers over the disc with both hands. \"Lay it flat on the imperial face. It'll know the face.\"", "next": ""},
		"hp_why": {"who": "Choir Pilgrim", "text": "\"Mine,\" she says, which isn't an answer, and hums until you stop asking.", "next": "hp_hub"},
		"hp_done": {"who": "Choir Pilgrim", "text": "For the first time the hymn stops. \"Then it's paid.\" For a moment she looks like a woman and not a psalm. \"Thank you, bearer. The garden noticed. It notices the small doors too.\"", "next": ""},
	}},

	# OVERRIDES ch2_zones_side.gd's "ch2_lore_reliquary" — verbatim copy, with
	# a gated deposit choice appended. Carrying the pilgrim's token unlocks
	# laying it; the ungated "read again" keeps the prop walkable for everyone.
	"ch2_lore_reliquary": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A boundary stone, half-swallowed by dune. The imperial side reads: BY ORDER OF THE CROWN, ALL WELLS BETWEEN THIS MARK AND THE SALT ARE HELD IN COMMON. The other face has been cut more recently, with a worse chisel, by somebody who had to lie down in the sand to reach it: AND THE CROWN IS DEAD AND THE WELLS ARE DRY AND WE HELD THEM IN COMMON RIGHT TO THE END. Both hands were proud of their work. Only one of them was joking.",
			"next": "",
			"choices": [
				{"text": "Lay the pilgrim's salt flat on the imperial face.",
					"req_flag": "salt_taken", "req_not_flag": "salt_laid",
					"lose_item": "salt_token", "flags": {"salt_laid": true},
					"resonance": 2.0, "next": "l_laid"},
				{"text": "Read it again, and step back.", "next": ""},
			]},
		"l_laid": {"who": "Narrator", "text": "The salt disc sits on the old imperial line like a coin on a closed eye. It doesn't glow, or hum, or do anything a shard would do. It just sits there, being held in common, right to the end. Somewhere back at the camp, a pilgrim's debt goes quiet.", "next": ""},
	}},

	# ---- Q10 props: the bell on the Fields, the logs in the Bastion --------
	# (placed by ZONE_PROPS above; both set a step flag through a single choice.)
	"ch2_bell": {"start": "b1", "nodes": {
		"b1": {"who": "Narrator", "text": "The bell lies half in a wind-scour, its lip split clean through. Not corroded, snapped, the way iron goes when something too large leans on the note. Wolf tracks ring it, old and new. They come to where the sound used to be, and mill around, and leave, and come back.",
			"next": "",
			"choices": [
				{"text": "Pry loose a shard of the broken lip for Piet.",
					"flags": {"bell_heard": true}, "next": "b2"},
			]},
		"b2": {"who": "Narrator", "text": "The curl of split iron is lighter than it should be, as if the storm took something out of it that wasn't only shape.", "next": ""},
	}},
	"ch2_bastion_logs": {"start": "b1", "nodes": {
		"b1": {"who": "Narrator", "text": "A warden's log, still legible where the void-frost kept it. The Accord's histories call the sealing clean: six wardens, one rite, no losses. The log disagrees. It counts nine names struck through, and a last entry in a shaking hand that says the seal didn't hold the first time. Or the second.",
			"next": "",
			"choices": [
				{"text": "Transcribe it, word for word, for Ivo.",
					"flags": {"logs_read": true}, "next": "b2"},
			]},
		"b2": {"who": "Narrator", "text": "You copy it out exact, the struck names, the shaking last line, all of it. Ivo said 'exact' four times. You believe he meant it four times.", "next": ""},
	}},

	# ---- Q10 props: the spore hollow (Cage) + two drowned markers (Ferryman)
	"ch2_cage_hollow": {"start": "c1", "nodes": {
		"c1": {"who": "Narrator", "text": "A spore hollow at the base of a fungal trunk, the size of a curled sleeper. You put your ear to it, the way the beastkin asked, and wait. It isn't silent. Deep in the wood something answers, a low chord, felt more than heard, older than the blight and patient as roots. The hollows still sing. The Sporewood remembers being a forest.",
			"next": "",
			"choices": [
				{"text": "Fix the chord in your memory for the caged scout.",
					"flags": {"hollow_listened": true}, "next": "c2"},
			]},
		"c2": {"who": "Narrator", "text": "You carry the sound out with you, or as much of it as a shard-bearer can carry. It won't translate cleanly. You'll have to choose what to tell.", "next": ""},
	}},
	"ch2_ferry_mark_a": {"start": "m1", "nodes": {
		"m1": {"who": "Narrator", "text": "Bones half-sunk in the black water of the Drowned Race, weighted the way the current weights the ones who never reached the ferry. A soul the ferryman couldn't pole across.",
			"next": "",
			"choices": [
				{"text": "Set a coin on the bank, the fare he couldn't collect.",
					"flags": {"due_drowned": true}, "next": "m2"},
			]},
		"m2": {"who": "Narrator", "text": "The coin sits bright against the mud a moment, then the bog takes it, quiet as it takes everything. One fare paid, late.", "next": ""},
	}},
	# ---- Q10 faction arc-2 waypoint props ---------------------------------
	"ch2_blight_line": {"start": "b1", "nodes": {
		"b1": {"who": "Narrator", "text": "The Waking's leading edge, marked the old way, a line of standing stones the storm has half-thrown down. Near side, grass. Far side, the grey. Callis wants to know where the line sits now, not where the maps say it should. You pace it, and note where the grey has crept since the last survey: further than anyone at the camp will want to hear.",
			"next": "",
			"choices": [
				{"text": "Map the true edge for Callis.", "flags": {"blight_line_walked": true}, "next": "b2"},
			]},
		"b2": {"who": "Narrator", "text": "You fix the line in your notes, honest yardage, the unglamorous kind that keeps the Accord from planting on ground that'll be grey by spring.", "next": ""},
	}},
	"ch2_seal_assay": {"start": "a1", "nodes": {
		"a1": {"who": "Narrator", "text": "The recovered imperial seal, held to the crystal's hum the way Vessa asked. The gallery answers, and old metal doesn't lie to crystal: the seal isn't a mark of office at all. It's a key, cut for a lock the Concord built, in a hand older than Vargoth's empire. Whatever it opens, the Cinderborn didn't know they were paying you to find it.",
			"next": "",
			"choices": [
				{"text": "Note what the seal really is, for Vessa.", "flags": {"seal_assayed": true}, "next": "a2"},
			]},
		"a2": {"who": "Narrator", "text": "You record the assay in the exact, deniable language Vessa prefers, enough that she'll understand, little enough that the note itself sells for nothing.", "next": ""},
	}},
	# ---- Q10: What the Cage Holds (Caged Beastkin) ------------------------
	# OVERRIDES ch2_factions.gd's "ch2_beastkin_cage" — verbatim copy, w2
	# gains the scout ask (accept) and the report fork at the END. The
	# free/water/walk fork is untouched; the quest is strand-safe (abandon: 0)
	# so freeing the cage before reporting costs nothing.
	"ch2_beastkin_cage": {"start": "w1", "nodes": {
		"w1": {"who": "Caged Beastkin",
			"text": "The cage holds a wiry beastkin scout, Fangmaw's blood, three generations on. It watches you with too-clever eyes and says nothing. The sentries argue about what to do with it.",
			"variants": [
				{"flag": "cage_resolved", "text": "The cage stands empty now. One of the sentries has planted herbs in it, out of spite or optimism.", "next": ""},
				{"band": "tempted", "text": "The caged scout presses itself against the far bars as you approach, the first fear it's shown anyone in this camp. \"Two hungry things,\" it rasps, \"and only one of us is caged.\""},
			],
			"next": "w2"},
		"w2": {"who": "Caged Beastkin", "text": "\"Shard-carrier,\" it rasps, finally. \"Your pack or mine, a cage is a cage. The Tribes remember who opens doors. And who watches.\"",
			"choices": [
				{"text": "Open the cage. \"Run before the sentries agree on anything.\"",
					"resonance": 4.0, "flags": {"freed_beastkin": true, "cage_resolved": true},
					"faction": {"wildfang": 10, "accord": -4}, "next": "w_free"},
				{"text": "Pass a waterskin through the bars and say nothing.",
					"flags": {"cage_resolved": true}, "faction": {"wildfang": 4}, "next": "w_water"},
				{"text": "\"The Tribes raid grain carts. Watch, then.\" Walk away.",
					"flags": {"cage_resolved": true}, "faction": {"wildfang": -5}, "next": "w_walk"},
				{"text": "\"You watch me like you want something. What is it?\"",
					"req_not_flag": "sq_on_what_cage_holds", "side_quest": "what_cage_holds",
					"next": "wq_ask"},
				{"text": "\"I listened at the hollows, like you asked.\"",
					"req_flag": "hollow_listened", "req_not_flag": "cage_told", "next": "wq_report"},
			]},
		"w_free": {"who": "Narrator", "text": "It's over the palisade before the latch stops swinging. From the treeline, one short howl, a note, not a threat. Something out there is keeping accounts.", "next": ""},
		"w_water": {"who": "Narrator", "text": "It drinks without taking its eyes off you, and sets the skin down with strange care. The Tribes remember small doors too.", "next": ""},
		"w_walk": {"who": "Narrator", "text": "The too-clever eyes follow you all the way across the camp. You've been entered into someone's ledger, and not on the generous page.", "next": ""},
		"wq_ask": {"who": "Caged Beastkin", "text": "\"...Not freedom. I know these bars. I want to know if the spore hollows still sing, the deep ones, in the Sporewood. My grandmother's grandmother could hear them from the ridge. If they've gone quiet, then the Tribes were right to stop listening, and I can stop too.\" The too-clever eyes are, for once, only tired. \"You'll go where I can't. Put your ear to a hollow. And tell me true. I'll know the other thing.\"", "next": ""},
		"wq_report": {"who": "Caged Beastkin", "text": "It goes very still against the bars. \"Well? Do they sing?\"",
			"next": "",
			"choices": [
				{"text": "\"They still sing. The Sporewood remembers being a forest. I won't pretend that's a kindness to you in here.\"",
					"flags": {"cage_told": true}, "faction": {"wildfang": 2}, "resonance": -4.0,
					"scene": "what_cage_holds_scene", "next": "wq_truth"},
				{"text": "\"They've gone quiet. It's just rot out there now. Nothing's aching for you.\"",
					"flags": {"cage_told": true}, "faction": {"wildfang": -2}, "resonance": 4.0,
					"scene": "what_cage_holds_scene", "next": "wq_lie"},
			]},
		"wq_truth": {"who": "Caged Beastkin", "text": "The breath goes out of it slowly. \"...They sing.\" It closes its eyes, and something that's not quite grief and not quite home moves across its face. \"Then I was wrong to stop listening. Thank you, shard-carrier. A cruel gift is still a gift. The Tribes remember the ones who don't soften the truth.\"", "next": ""},
		"wq_lie": {"who": "Caged Beastkin", "text": "It searches your face a long moment, then lets its shoulders down. \"...Quiet. Then there's nothing to ache for.\" It almost looks relieved, and you did that. Whether it believed you, you'll never know, but it sleeps that night, and the caged don't sleep easily.", "next": ""},
	}},

	# ---- Q10: The Ferryman's Due (object-first off the landing lore prop) --
	# OVERRIDES ch2_zones_side.gd's "ch2_lore_ferry" — verbatim l1 text, now a
	# hub: take up his tally (accept), and lay the last coin once the two
	# drowned markers are paid.
	"ch2_lore_ferry": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A landing stage on the black water, and the ferryman still tied to his own post, rope around the waist, the way a man secures himself for a long night's work he means to survive. He took people out of the Greyrun for eleven days after the blight came up. The tally is cut into the post beside him, five and five and five, and the last group is a group of one, and the notch for it is deeper than the others, like it was cut slowly, by somebody with the evening free.",
			"next": "l_hub"},
		"l_hub": {"who": "Narrator", "text": "The fare-box at his belt is empty. He collected nothing for the last eleven days; a ferryman who takes no coin isn't a ferryman, he's a drowning man with a boat.",
			"next": "",
			"choices": [
				{"text": "Take up his tally. Pay the fare he couldn't collect, at each place the drowned still lie.",
					"req_not_flag": "sq_on_ferryman_due", "resonance": 3.0,
					"side_quest": "ferryman_due", "next": "l_accept"},
				{"text": "Lay the last coin on his own tally. The debt is closed.",
					"req_flag": "due_drowned", "req_not_flag": "ferryman_paid",
					"flags": {"ferryman_paid": true}, "resonance": 2.0,
					"scene": "ferryman_due_scene", "next": "l_paid"},
				{"text": "Leave him to his long night. (step back)", "next": ""},
			]},
		"l_accept": {"who": "Narrator", "text": "You mark the place the Greyrun took the most, the Drowned Race, downstream, and set out with a coin for the fare it swallowed, and one more for the man at the post. The ferryman doesn't thank you. Ferrymen don't. But the rope around his waist seems, in the failing light, a little less like a knot and a little more like a mooring.", "next": ""},
		"l_paid": {"who": "Narrator", "text": "You set the last coin in the notch cut deepest, the group of one, the fare he cut slowly with the evening free, because the one it counted was himself. The post takes the coin like it was carved to hold it. Somewhere the accounting balances, eleven days late, and the black water goes on being black water.", "next": ""},
	}},

	# OVERRIDES ch2_hub.gd's "ch2_refugee" — verbatim copy, extended:
	# r1 gains choices (Still Blue accept / bread courier / leave), and the
	# mill_told variant now flows to r_after so the bread ask stays
	# reachable once the mill arc closes. The mill payoff flow itself
	# (mill_seen -> r_told -> r_told2) is untouched.
	"ch2_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Widow Sera",
			"text": "We had a mill on the Greyrun. Then the water came up black one morning, and that was that. Maren says the land can be cleaned. I say she believes it because someone has to.",
			"variants": [
				# Payoff first (playtest fix): she asked about the blue door —
				# if you went and looked, she must KNOW you did.
				{"flag": "mill_told", "text": "Sera nods as you pass, the way people nod at good weather. \"Still blue,\" she says, to herself as much as you. She's stopped saying 'we had a mill.'", "next": "r_after"},
				{"flag": "mill_seen", "text": "\"You went.\" She reads it off your face before you speak. \"...And it stands? The door held?\" She sits down slowly on the cook-bench. \"Twenty years of spring paint. You tell Maren she's right, the land can be cleaned. Some of it is clean already.\"", "next": "r_told"},
				{"band": "tempted", "text": "My gran used to say the blight gets in through what you want most. ...Why are you looking at me like that, shard-bearer?"},
				{"band": "steady", "text": "You've got kind eyes for someone carrying a dead king's splinter. If you get as far as the Greyrun... the mill had a blue door. I'd like to know if it's standing."},
			],
			"next": "",
			"choices": [
				{"text": "\"The Greyrun is on my road east. I'll look for your mill, and the door.\"",
					"req_not_flag": "sq_on_still_blue", "resonance": 2.0,
					"side_quest": "still_blue", "next": "r_accept"},
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
		"r_told": {"who": "Widow Sera", "text": "\"Twenty years I painted that door. Tell me true, once more. It stands?\"",
			"next": "",
			"choices": [
				# side_quest here is the RETROACTIVE accept: a player who found
				# the mill before ever hearing Sera's ask still gets the quest
				# (and its payout) the moment they carry the truth back.
				{"text": "\"It stands, Sera. The paint is winning.\"",
					"side_quest": "still_blue",
					"flags": {"mill_told": true}, "resonance": 2.0, "next": "r_told2"},
				{"text": "\"It stands. The paint is winning. News rode a hard road, Sera, call it a courier's fee.\" Hold out your hand.",
					"side_quest": "still_blue",
					"flags": {"mill_told": true}, "resonance": -6.0, "gold": 25, "next": "r_fee"},
			]},
		"r_told2": {"who": "Narrator", "text": "Small honest cargo, delivered. It weighed nothing, and it was worth the trip.", "next": ""},
		"r_fee": {"who": "Widow Sera", "text": "She counts it out of the hem of her sleeve without a word, the mill's last rent, paid to the weather that spared it. \"It stands.\" She says it to herself, not to you, and it lands the same either way. \"Worth every copper. I'd have paid ten times over for the truth. Mind, that's not a thing to let people learn about you, bearer.\"", "next": ""},
		"r_accept": {"who": "Widow Sera", "text": "\"Blue. There won't be two of them out there. I sanded and repainted it every spring for twenty years. The rot hates being argued with.\" She looks at her hands. \"Don't dress it up for me, whatever you find. I've had enough weather turned kind by liars.\"", "next": ""},
		"r_loaf": {"who": "Widow Sera", "text": "She wraps a dark loaf in waxed cloth, knots it like it's going somewhere important, and weighs it once in her hand before letting it go. \"For whoever mans the far crossings. The chronicler in the crystal deep, if the crystals haven't talked him deaf. Tell him it's from Sera. Not 'the camp'. Sera.\"", "next": ""},
		"r_after": {"who": "Widow Sera", "text": "\"The ovens don't stop just because the door held. Camp still eats, and the far crossings stand their watch hungry.\"",
			"next": "",
			"choices": [
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				# Q10: Widow's Arithmetic — the mill's ledger, and a quiet fork.
				{"text": "\"The door held. What else does the mill still owe you?\"",
					"req_not_flag": "sq_on_widows_arithmetic", "side_quest": "widows_arithmetic",
					"next": "r_ledger_ask"},
				{"text": "Set the mill's grain ledger on the cook-bench in front of her.",
					"req_flag": "ledger_taken", "req_not_flag": "sera_ledger_told",
					"next": "r_ledger_fork"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
		"r_ledger_ask": {"who": "Widow Sera", "text": "Her jaw sets. \"The grain book. Twenty years of the Greyrun's harvests, and the last season counted twice. The village says the blight starved us. I say the blight starved some of us, and the rest sold the shortfall and blamed the water. Bring me the book and I'll settle it in my own hand: who starved, and who only claimed to.\" A beat. \"It's in the mill office, under the third floorboard where I kept the coin. You'll have seen the shape of that.\"", "next": ""},
		"r_ledger_fork": {"who": "Widow Sera", "text": "She opens it to the last season and runs a finger down the column, and her mouth thins. \"There. Millwright's own tithe, laid by while the row cottages went hollow. My late husband's partner. My daughter's godfather.\" She looks up at you. \"You read it too, on the road. Do I settle this whole, every name, mine among them where I took my share, or...\"",
			"next": "",
			"choices": [
				{"text": "\"Whole. Every name, yours included. The truth doesn't get to pick who it spares.\"",
					"lose_item": "mill_ledger", "flags": {"sera_ledger_told": true},
					"resonance": 4.0, "scene": "widows_arithmetic_scene", "next": "r_ledger_whole"},
				{"text": "Tear out the page that names her own hoard first, then hand her the rest.",
					"lose_item": "mill_ledger", "flags": {"sera_ledger_told": true, "chose_sera_page": true},
					"resonance": -6.0, "scene": "widows_arithmetic_scene", "next": "r_ledger_page"},
			]},
		"r_ledger_whole": {"who": "Widow Sera", "text": "She takes it whole and doesn't flinch from her own line. \"Then it's honest. First honest thing on the Greyrun in a year.\" She'll post the reckoning at the mill door, the blue one, where twenty years of spring paint can watch the village read it. \"You didn't soften it for me. Nobody's done that since the water came up.\"", "next": ""},
		"r_ledger_page": {"who": "Widow Sera", "text": "The torn page goes into the cook-fire and is gone before she can change her mind, and something in her goes quiet with it. \"...The rest is true. Truer than most.\" She won't meet your eye, and she won't ask what you'll do with what you know. The reckoning she posts at the blue door names everyone but her, and every reader who was there will notice the one name missing, and say nothing, the way the Greyrun says nothing.", "next": ""},
	}},

	# OVERRIDES ch2_zones_act1.gd's "ch2_mill" — verbatim d1/d2/d3/d_loot, with
	# the mill_seen / mill_looted revisit variants (and the two outcome nodes)
	# rerouted to a revisit hub so the grain ledger (Widow's Arithmetic) is
	# takeable on a return trip once the quest is live. First-visit flow (see
	# the door, remember/loot) is byte-for-byte the same.
	"ch2_mill": {"start": "d1", "nodes": {
		"d1": {"who": "Narrator",
			"text": "A mill hunches over the black water of the Greyrun. The wheel is furred with blight-moss and the walls have gone grey, but the door is blue. Still blue. Somebody sanded and repainted it every spring for twenty years, and for now the rot seems to be losing its argument with the paint.",
			"variants": [
				{"flag": "mill_looted", "text": "The blue door stands where it stood. You know now what the paint was guarding, and how light a tin of coin rides, and you find you don't check on the door the way you meant to. It watches you pass instead.", "next": "d_revisit"},
				{"flag": "mill_seen", "text": "The blue door stands where it stood. You find you check on it now, the way Sera must have: one glance, every pass, to make sure the argument is still being lost.", "next": "d_revisit"},
			],
			"next": "d2"},
		"d2": {"who": "Narrator", "text": "Sera asked one thing: to know whether it still stands. It does. That'll matter to exactly one person in the world, which, you're starting to suspect, is what mattering usually looks like.",
			"choices": [
				{"text": "Remember it for her. (The door is standing.)",
					"flags": {"mill_seen": true}, "resonance": 3.0, "next": "d3"},
				{"text": "Remember it for her, then work the wheel-side shutter loose. Twenty years of paint guarded something worth carrying.",
					"flags": {"mill_seen": true, "mill_looted": true}, "resonance": -8.0,
					"gold": 30, "next": "d_loot"},
			]},
		"d3": {"who": "Narrator", "text": "You fix the blue in your mind against the grey. Small honest cargo for the road back.", "next": "d_revisit"},
		"d_loot": {"who": "Narrator", "text": "The shutter gives the way twenty-year hinges give: apologizing. Inside, the mill keeps house the way she must have kept it, jars labeled, tools oiled, and under the third floorboard a tin of coin set aside against a leaner spring than this one. You take the tin. The door stays blue behind you, and stands a little less for it, though only you would know, and you mean to be the only one who ever does.", "next": "d_revisit"},
		"d_revisit": {"who": "Narrator", "text": "The mill keeps its own counsel over the black water, the blue door holding its line.",
			"next": "",
			"choices": [
				{"text": "Into the mill office. Sera's grain ledger is under the third floorboard, where the coin was.",
					"req_flag": "sq_on_widows_arithmetic", "req_not_flag": "ledger_taken",
					"gain_item": "mill_ledger", "flags": {"ledger_taken": true}, "next": "d_ledger"},
				{"text": "Leave the mill to its water. (step back)", "next": ""},
			]},
		"d_ledger": {"who": "Narrator", "text": "The third floorboard gives the way it gave to whoever came before. The grain book is under it, dry in an oilcloth. Twenty years of harvests, the last season counted twice and once crossed out. Sera will know what the crossing-out means. You're beginning to.", "next": ""},
	}},

	# OVERRIDES ch2_zones_act2.gd's "ch2_scholar" — verbatim copy, extended:
	# the scholar_met revisit variant now lands on s_desk (it used to end
	# the scene, which would strand both courier hooks), s2 gains the two
	# gated quest choices at the END (autotest still picks choice 0), and
	# the new nodes carry Sera's loaf payoff and Aldric's ash commission.
	"ch2_scholar": {"start": "s1", "nodes": {
		"s1": {"who": "Scholar Ivo",
			"text": "Mind the resonance, shard-bearer. The crystals repeat what they hear, and some of what they heard down here predates manners. Ivo. Chronicler. Unaffiliated, whatever the envoy tells you.",
			"variants": [
				{"flag": "scholar_met", "text": "\"Still standing? Statistically remarkable. The Bastion's ahead. My notes, sadly, end right where they get interesting.\"", "next": "s_desk"},
				{"band": "tempted", "text": "The scholar looks up, then looks harder, the way you read a difficult footnote. \"Fascinating. Yours is further along than most. Do sit away from the crystals, if you please. They repeat things.\""},
				{"band": "steady", "text": "\"Ah, a quiet one. The crystals barely hum around you. That's the rarest reading I've taken all year, shard-bearer, and I intend to write it down twice.\""},
			],
			"next": "s2"},
		"s2": {"who": "Scholar Ivo", "text": "Free knowledge, since you're heading east anyway: the Bastion ahead predates Vargoth. It's an armory, from the war the Concord ended. What woke up inside it isn't blighted and isn't beastkin. It's maintenance, resumed after six hundred years, and it's decided the whole region is out of specification.",
			"choices": [
				{"text": "\"What do your notes say about killing it?\"",
					"flags": {"scholar_met": true}, "next": "s3"},
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk, the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
				# Q10: A Straight Answer — accept, then report the warden logs.
				{"text": "\"Your Bastion notes stop right where it gets interesting. What are you afraid they say?\"",
					"req_not_flag": "sq_on_straight_answer", "resonance": 2.0,
					"side_quest": "straight_answer", "next": "s_ask"},
				{"text": "\"I read the warden logs. The Accord's version is a lie of omission.\"",
					"req_flag": "logs_read", "req_not_flag": "ivo_told", "next": "s_fork"},
			]},
		"s3": {"who": "Scholar Ivo", "text": "\"Shed its armor before it sheds yours. It protects the frame, not the function. And when the grid stamps, don't be where you were standing. That sentence has cost four lives to write, so do me the courtesy of surviving it.\"", "next": ""},
		# -- A Straight Answer: the ask, then the fork over what to do with it.
		"s_ask": {"who": "Scholar Ivo", "text": "\"Afraid. Yes. Good word.\" He sets down his stylus. \"The Accord's account of the sealing is too clean. Six wardens, one rite, done. Inside the Bastion there's a warden's own log. If it says what I think it says, then the tidy version is a kindness someone chose to tell. Read it for me. Word for word. The crystals taught me what 'roughly' costs.\"", "next": ""},
		"s_fork": {"who": "Scholar Ivo", "text": "He reads your transcription twice, the second time slower. \"Nine names. Three attempts. A last line by a man who knew.\" He's very still. \"So. I can publish this exactly: the sealing was a slaughter dressed as a rite, and the Accord has been printing the dress. Or I summarize kindly: it held, the cost was borne, spare the grandchildren the arithmetic. You carried it. You've earned the vote.\"",
			"next": "",
			"choices": [
				{"text": "\"Publish it whole. People who bury the count get to do it twice.\"",
					"flags": {"ivo_told": true, "chose_ivo_truth": true},
					"faction": {"accord": -2}, "resonance": 2.0,
					"scene": "straight_answer_scene", "next": "s_publish"},
				{"text": "\"Summarize it kindly. The dead are past caring who knows the number.\"",
					"flags": {"ivo_told": true}, "faction": {"accord": 2},
					"scene": "straight_answer_scene", "next": "s_kind"},
			]},
		"s_publish": {"who": "Scholar Ivo", "text": "\"Then it's on the record, and so is my name under it.\" He copies it into a bound folio, unhurried. \"The Accord will call me unaffiliated a great deal louder now. Let them. A chronicle that flatters the chronicler's patrons is a receipt, bearer, not a history.\"", "next": ""},
		"s_kind": {"who": "Scholar Ivo", "text": "\"...Kind. Yes.\" He folds the transcription once and sets it under a heavier stone. \"It held. The cost was borne. Both true, and both a little less than the whole. I'll keep the whole here, where the crystals can't repeat it, for whoever comes asking after we're all past minding.\"", "next": ""},
		"s_desk": {"who": "Scholar Ivo", "text": "\"Back again. Good, the crystals repeat dull company.\" He waves at the sample desk without looking up.",
			"next": "",
			"choices": [
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk, the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
				{"text": "\"Your Bastion notes stop right where it gets interesting. What are you afraid they say?\"",
					"req_not_flag": "sq_on_straight_answer", "resonance": 2.0,
					"side_quest": "straight_answer", "next": "s_ask"},
				{"text": "\"I read the warden logs. The Accord's version is a lie of omission.\"",
					"req_flag": "logs_read", "req_not_flag": "ivo_told", "next": "s_fork"},
				{"text": "\"Mind the crystals, Ivo.\" (leave)", "next": ""},
			]},
		"s_loaf": {"who": "Scholar Ivo", "text": "\"...Bread. Oven bread.\" He takes the bundle in both hands, the way you'd handle a first edition. \"I've catalogued four hundred resonance events this year, bearer, and this is the finest data among them. Tell Sera the crossing is manned, and that the crossing says thank you. From Ivo. Not 'the deeps'. Ivo.\"", "next": ""},
		"s_jar": {"who": "Scholar Ivo", "text": "\"Ah. A commission, technically. Ser Aldric wrote me exactly one letter in thirty years. 'A pinch of ash off the Bastion road. I want to know what it burns like now.' His words. I collected it in the spring; the couriers, you'll have noticed, stopped running.\" He taps the wax seal. \"The jar weighs nothing, and the debt isn't yours. But you are walking west.\"",
			"choices": [
				{"text": "Take the jar. \"An old knight's one letter shouldn't go unanswered.\"",
					"req_not_flag": "ash_taken", "resonance": 2.0,
					"gain_item": "bastion_ash", "flags": {"ash_taken": true},
					"side_quest": "ash_for_aldric", "next": "s_ash"},
				{"text": "\"Not my road today.\" Leave it on the desk.", "next": ""},
			]},
		"s_ash": {"who": "Scholar Ivo", "text": "\"Careful hands. It took the wind six centuries to grind the Bastion road that fine, a fact I'll thank you not to test by dropping it.\" He returns to his instruments, then, without looking up: \"Tell the old man the chronicler keeps his ledgers. All of them.\"", "next": ""},
	}},

	# OVERRIDES ch2_aldric.gd's "ch2_aldric" — verbatim copy, extended with
	# one hub choice appended at the END, gated on actually carrying Ivo's
	# jar (req_flag ash_taken): invisible in every suite convo-walk state,
	# so the hub's asserted choice counts (3 pre-act, 4 post) still hold.
	"ch2_aldric": {"start": "g1", "nodes": {
		"g1": {"who": "Ser Aldric",
			"text": "Don't salute. The arm doesn't come up past the shoulder anymore, and returning it embarrasses us both. Sit, shard-bearer. The fire's the only thing here that still burns properly.",
			"variants": [
				{"band": "tempted", "text": "...Come closer where I can see you. Hm. Yours is loud, isn't it. I can almost hear it from here. Mine was loud too, near the end. Sit down anyway. It hates patience."},
				{"band": "steady", "text": "There's a way people stand when the shard serves them and not the other way round. You stand like that. It's rarer than Maren lets on. Sit down, good company earns the good stump."},
			],
			"next": "hub"},
		"hub": {"who": "Ser Aldric", "text": "Ask, then. Old men and dead kings both like being asked.",
			"choices": [
				{"text": "\"What did it cost, killing him?\"", "next": "p1"},
				{"text": "\"What is the Ember Crown, really?\"",
					"req_flag": "ch2_briefed", "next": "p2"},
				# One-time reveal: once told, the question retires (playtest
				# fix — "I never told anyone" rang false on the second ask).
				{"text": "\"Maren says you never told her everything. Tell me.\"",
					"req_flag": "blight_scouted", "req_not_flag": "aldric_truth",
					"flags": {"aldric_truth": true}, "next": "p3"},
				{"text": "\"Rest easy, ser.\" (leave)", "next": "g_bye"},
				{"text": "Set a sealed jar by the fire. \"Bastion ash, ser. Ivo kept your commission.\"",
					"req_flag": "ash_taken", "req_not_flag": "ash_given",
					"lose_item": "bastion_ash", "flags": {"ash_given": true},
					"resonance": 2.0, "scene": "ash_aldric_scene", "next": "p_ash"},
			]},

		# -- Part 1: the killing blow, and the hollow it left.
		"p1": {"who": "Ser Aldric", "text": "Everything I was carrying. You don't swing an ember at a god-king and keep the ember. I knew that walking in. What they don't tell you is the after. Colors are dimmer. Bread is just bread. The fire in me went out and took the pilot light with it.", "next": "p1b"},
		"p1b": {"who": "Ser Aldric", "text": "And still: cheap. Cheapest thing I ever bought, that blow. Remember that when yours starts telling you what you can't afford to lose.", "next": "hub"},

		# -- Part 2: the Crown's true nature (needs Maren's briefing).
		"p2": {"who": "Ser Aldric", "text": "Maren gave you the recruiting-poster version, I expect. Here's the armory version: it was never one thing. Four embers, carried by the Guard's four founders, forced to burn as a single crown. Vargoth didn't steal a symbol. He chained four old fires together and wore the chain as jewelry.", "next": "p2b"},
		"p2b": {"who": "Ser Aldric", "text": "So the Crown didn't just shatter. Chains shatter. Fires scatter. That thing in your chest is one of the original four, or a splinter off one, and it remembers being free. Every shard-bearer in Vaelscar is carrying a piece of an argument that started six hundred years ago.", "next": "hub"},

		# -- Part 3: what he never told anyone (needs act progress).
		"p3": {"who": "Ser Aldric", "text": "...You've been east. Seen what the Waking does. All right. All right. Come closer, this one isn't for the sentries.", "next": "p3b"},
		"p3b": {"who": "Ser Aldric", "text": "When my blade went in, the Crown spoke. Not to Vargoth. To me. It said, and I've had thirty years to mishear this kindly, so believe me when I say I haven't, it said: 'WELL STRUCK. NOW WE CHOOSE OUR OWN.'", "next": "p3c"},
		"p3c": {"who": "Ser Aldric",
			"text": "It wasn't defeated, bearer. It dismissed itself. The scattering wasn't an accident of my blow, the shards went looking. Which means every one of you was picked, by something with six hundred years of patience and a grudge against chains. I never told Maren because she'd have hunted every bearer down for caution's sake. And because... maybe being chosen isn't the same as being owned. You lot get to decide that part. That's the whole of my hope, and I keep it right here next to the bad arm.",
			"variants": [
				{"band": "tempted", "text": "It wasn't defeated. It dismissed itself, and the shards went looking for their bearers. Yours leaned in just now when I said it. Don't pretend it didn't, I saw your face. So hear the rest: chosen isn't the same as owned. The thing picked you for a reason. You pick what the reason means. That trick is the only sword I've got left to give anyone."},
			],
			"next": "p3d"},
		"p3d": {"who": "Narrator", "text": "The old knight leans back, lighter by exactly one secret. Whatever you carry in your chest is very, very quiet, the way a listener is quiet.", "next": "hub"},

		# -- The ash commission, answered (Q2: ash_for_aldric payoff).
		"p_ash": {"who": "Narrator", "text": "He works the wax off one-handed, unhurried, like a man opening a letter he already knows the contents of. Then he takes a pinch and feeds it to his own small fire. It burns orange. Just orange. He watches it the way other men watch a grave filled in.", "next": "p_ash2"},
		"p_ash2": {"who": "Ser Aldric", "text": "It burned green, the night we took that road. Sixty years the ash held the color of the wound. I know, I kept asking. And now it's just ash again. The land forgets faster than the men do, bearer. That's the kindest thing anyone has carried me in years, and it came in a jar.", "next": "hub"},

		"g_bye": {"who": "Ser Aldric", "text": "Easy is for the dead, and they earned it. Go on, bearer. Mind the east road, and mind the voice more.", "next": ""},
	}},

	# ---- Q10: faction arc STEP 2 (recruiter overrides) --------------------
	# OVERRIDES ch2_factions.gd's "ch2_accord_recruit" / "ch2_cinder_recruit" —
	# verbatim copies, with the arc-1-done status variant rerouted to an arc-2
	# hub (assign the second commission, take its report). The join flow (a1/a2,
	# c1/c2) is byte-for-byte the same, so the faction-join suite walk is
	# unchanged; arc-2 lives on nodes reachable only after joining + arc-1.
	"ch2_accord_recruit": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Callis",
			"text": "Shard-bearer. I won't circle it: the Accord wants every shard gathered and the hollow throne broken for good, yours included, one day, with your consent. We ask people to become less so the world can be more. Maren trusts us. Mostly.",
			"variants": [
				{"flag": "joined_accord", "text": "Warden Callis salutes. \"Colleague.\"", "next": "a_status"},
				{"flag": "joined_cinderborn", "text": "\"You wear Vessa's colors now. Then we're done talking, bearer. The Accord doesn't bargain for what should never be owned.\" She turns back to the palisade.", "next": ""},
				{"band": "tempted", "text": "The warden's hand settles on her hilt before she speaks, casual and precise. \"Shard-bearer. I'll make the Accord's case anyway. Consider it optimism under arms: we gather the shards, we break the throne, and we ask people like you to become less before that voice makes you more.\""},
				{"band": "steady", "text": "\"Shard-bearer.\" The warden looks you over once and, remarkably, relaxes. \"You hold it well. That's exactly who the Accord wants: we gather the shards, break the hollow throne, and ask the strong to become less so the world can be more. Few carry the asking better than you would.\""},
			],
			"next": "a2"},
		"a2": {"who": "Warden Callis", "text": "Join us, and your first task is honest work: survey what the Waking has made of the east road. No thrones, no leashes. Just the slow unglamorous mending of the world.",
			"choices": [
				{"text": "\"A world that asks me to be less... and asks itself first. I'm in.\"",
					"req_not_flag": "faction_chosen", "resonance": 6.0,
					"flags": {"joined_accord": true, "faction_chosen": true},
					"faction": {"accord": 20, "cinderborn": -10},
					"quest": "ch2_accord1", "next": "a_join"},
				{"text": "\"Not yet. I keep my own counsel a while longer.\"",
					"next": "a_later"},
				{"text": "\"Become less? You first, warden.\"",
					"req_band": "tempted", "resonance": -3.0,
					"faction": {"accord": -5}, "next": "a_mock"},
			]},
		"a_join": {"who": "Warden Callis", "text": "Then welcome to the long defeat, colleague. That's Accord humor, you'll learn to survive it. East road. Eyes open. Report what the blight has taken.", "next": ""},
		"a_status": {"who": "Warden Callis",
			"text": "\"The east road, colleague. The blight won't survey itself, and Vessa's coin-counters would love to beat us to it.\"",
			"variants": [
				{"flag": "accord_arc1_done", "text": "\"Your survey's already gone up the chain, colleague. First honest map of the Waking anyone's drawn. There'll be more work when the Accord digests it.\"", "next": "a_arc2"},
			],
			"next": "",
			"choices": [
				{"text": "\"The survey's done. The Greyrun is scouted. Here's what the blight has taken.\"",
					"req_flag": "blight_scouted", "req_not_flag": "accord_arc1_done",
					"flags": {"accord_arc1_done": true}, "faction": {"accord": 12},
					"resonance": 2.0, "next": "a_report"},
				{"text": "\"Still walking it, warden.\"", "next": ""},
			]},
		"a_report": {"who": "Warden Callis", "text": "She reads without a word, twice, then grips your shoulder with the strength of someone who buries fewer friends because of paper like this. \"Good work. Unglamorous work, the only kind that mends anything. The Accord remembers, colleague.\"", "next": ""},
		"a_later": {"who": "Warden Callis", "text": "Sensible. The shards make joiners of some and hermits of others. The offer keeps. The Accord is patient the way stone is patient.", "next": ""},
		"a_mock": {"who": "Warden Callis", "text": "...There it is. The little voice that thinks power should never kneel. I've buried friends who listened to it, bearer. The offer stands anyway. That's the difference between us and it.", "next": ""},
		# -- Arc step 2: the blight-line survey.
		"a_arc2": {"who": "Warden Callis", "text": "\"The Accord digested your survey and wants more, colleague. Of course it does. The blight-line. Walk the Waking's true edge and map where the grey sits now, not where last season's map pretends. Unglamorous. Necessary. Yours, if you'll take it.\"",
			"variants": [
				{"flag": "accord_arc2_done", "text": "\"Both surveys in, and both honest. You've drawn the Accord a truer map of the front than its own scouts. There'll always be more line to walk, but rest, colleague. You've earned the fire.\"", "next": ""},
			],
			"next": "",
			"choices": [
				{"text": "\"I'll walk the blight-line and map the true edge.\"",
					"req_not_flag": "accord_arc2_on", "flags": {"accord_arc2_on": true},
					"quest": "ch2_accord2", "resonance": 2.0, "next": "a_arc2_go"},
				{"text": "\"The blight-line's walked. Here's where the grey sits now.\"",
					"req_flag": "blight_line_walked", "req_not_flag": "accord_arc2_done",
					"flags": {"accord_arc2_done": true}, "faction": {"accord": 12},
					"resonance": 2.0, "next": "a_arc2_report"},
				{"text": "\"Later, warden.\"", "next": ""},
			]},
		"a_arc2_go": {"who": "Warden Callis", "text": "\"The stones out past the Lee, that's the old survey line. Pace it. Trust your own eyes over the map; the map is a year of wishful thinking.\"", "next": ""},
		"a_arc2_report": {"who": "Warden Callis", "text": "She lays your yardage beside the old survey and goes quiet at the difference. \"...That much, since spring.\" She rolls it up with the care you give bad news you intend to act on. \"The Accord plants where you say it's safe now, colleague, and nowhere else. That's what an honest map is for.\"", "next": ""},
	}},

	"ch2_cinder_recruit": {"start": "c1", "nodes": {
		"c1": {"who": "Envoy Vessa",
			"text": "Ah, the camp's newest miracle. Envoy Vessa, of the Cinderborn. Before Maren's people fill your ears: we don't miss the tyrant. We miss roads. Granaries. Law. A crown is a tool, and Vaelscar is bleeding for the lack of one.",
			"variants": [
				{"flag": "joined_cinderborn", "text": "\"Associate.\"", "next": "c_status"},
				{"flag": "joined_accord", "text": "\"Maren's warden got to you first, I see. A pity. You'd have looked well in better tailoring. Do give the Accord my regards while you're being noble at each other.\"", "next": ""},
				{"band": "tempted", "text": "Envoy Vessa's smile sharpens by a full karat. \"Now there's a bearer who understands wanting things. Vessa, of the Cinderborn. We don't miss the tyrant, darling, we miss roads. And we pay people who reach for what they want.\""},
				{"band": "steady", "text": "\"Hm. The disciplined sort.\" Vessa recalibrates her smile to something almost honest. \"Good. Discipline is half of what a crown is for. Envoy Vessa, of the Cinderborn. We miss roads, granaries, and law. Hear the offer before Maren's people talk you into camping forever.\""},
			],
			"next": "c2"},
		"c2": {"who": "Envoy Vessa", "text": "Work with us and be paid, protected, and remembered. First commission: an imperial courier vanished on the east road with a seal of office. Recover it. History belongs to whoever holds the paperwork.",
			"choices": [
				{"text": "\"Roads and granaries. Fine, I'll hear what order pays. I'm in.\"",
					"req_not_flag": "faction_chosen", "resonance": -6.0,
					"flags": {"joined_cinderborn": true, "faction_chosen": true},
					"faction": {"cinderborn": 20, "accord": -10},
					"quest": "ch2_cinder1", "next": "c_join"},
				{"text": "\"Not yet. Crowns and I are having a complicated moment.\"",
					"next": "c_later"},
				{"text": "\"The last crown you people polished got up and walked. No.\"",
					"resonance": 3.0, "faction": {"cinderborn": -5}, "next": "c_refuse"},
			]},
		"c_join": {"who": "Envoy Vessa", "text": "Splendid. A retainer will find you. We pay in coin, not sermons. The seal, associate. East road. Try not to die; the paperwork for that is dreadful.", "next": ""},
		"c_status": {"who": "Envoy Vessa",
			"text": "\"The seal, when you have it. The east road ate an imperial courier and his satchel, and history is written by whoever holds the paperwork.\"",
			"variants": [
				{"flag": "cinder_arc1_done", "text": "\"Ah, my favorite associate, the one whose paperwork arrives. The seal is already opening doors in three provinces.\"", "next": "c_arc2"},
			],
			"next": "",
			"choices": [
				{"text": "Hand over the courier's seal. \"One commission, delivered.\"",
					"req_flag": "relic_recovered", "req_not_flag": "cinder_arc1_done",
					"flags": {"cinder_arc1_done": true}, "faction": {"cinderborn": 12},
					"next": "c_reward"},
				{"text": "\"The road hasn't given it up yet.\"", "next": ""},
			]},
		"c_reward": {"who": "Envoy Vessa", "text": "She turns the cold white metal over once and smiles like a ledger balancing. \"Do you know what this unlocks? Neither do the people who'll pay to find out. Coin follows by courier, a living one, we've learned our lesson. The Cinderborn remember their associates.\"", "next": ""},
		"c_later": {"who": "Envoy Vessa", "text": "Complicated moments pass. Poverty and banditry, historically, don't. You know our colors when you tire of camping.", "next": ""},
		"c_refuse": {"who": "Envoy Vessa", "text": "The last crown was worn badly, a fault of the head, not the hat. But yes, do go tell the Accord how principled you are. They give out so little else.", "next": ""},
		# -- Arc step 2: assay the recovered seal.
		"c_arc2": {"who": "Envoy Vessa", "text": "\"Since you're the associate whose paperwork arrives, a second commission, more delicate. That seal you recovered. I want it assayed. Held to the crystal-hum in the Echoing Gallery, where old metal tells the truth. I want to know what it opens before the people paying me do.\"",
			"variants": [
				{"flag": "cinder_arc2_done", "text": "\"My associate who knows what the merchandise is before it's sold. Do you know how rare that is? The seal is worth a province now, and quietly, so are you. There's always more history to hold, but rest, darling. Even I let a good associate breathe.\"", "next": ""},
			],
			"next": "",
			"choices": [
				{"text": "\"I'll assay the seal. Let's see what history you've bought.\"",
					"req_not_flag": "cinder_arc2_on", "flags": {"cinder_arc2_on": true},
					"quest": "ch2_cinder2", "resonance": -2.0, "next": "c_arc2_go"},
				{"text": "\"I assayed the seal. It isn't a mark of office, it's a key.\"",
					"req_flag": "seal_assayed", "req_not_flag": "cinder_arc2_done",
					"flags": {"cinder_arc2_done": true}, "faction": {"cinderborn": 12},
					"resonance": 2.0, "next": "c_arc2_report"},
				{"text": "\"Later, envoy.\"", "next": ""},
			]},
		"c_arc2_go": {"who": "Envoy Vessa", "text": "\"The Echoing Gallery. The crystals there repeat what old metal remembers. Hold the seal to the hum and listen. And associate: whatever it tells you, it tells me first. That's the arrangement.\"", "next": ""},
		"c_arc2_report": {"who": "Envoy Vessa", "text": "For once the smile doesn't reach the ledger behind her eyes. \"...A key. Not a seal. A key.\" She recovers in half a breath, but you saw it, Vessa, briefly, out of her depth. \"Then it opens something the Concord wanted shut. We'll find out what, associate, and quietly. The Cinderborn remember who brought them the lock as well as the key.\"", "next": ""},
	}},
}
