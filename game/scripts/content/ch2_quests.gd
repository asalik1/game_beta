## (Q2 + Q10) Chapter 2 side quests on the side-quest engine (QUESTS_TASKS.md),
## hooked onto existing NPCs by convo override (never edit the owning module):
##   still_blue          — Sera's mill arc (existing flags) as a visible quest
##   bread_for_the_road  — Sera's loaf, carried to Scholar Ivo in the Deeps
##   ash_for_aldric      — Ivo's sealed jar of Bastion ash, back to Aldric
##   second_bell   (Q10) — Piet's cracked watch-bell, out on the Howling Fields
##   salt_reliquary(Q10) — a Choir pilgrim's salt token, laid at the reliquary
##   straight_answer(Q10)— the Null Bastion's warden logs, and Ivo's fork
## Q10 adds no zones and no new spawns: the two props ride ZONE_PROPS (Q9) onto
## existing rooms by name, gated by req_flag; the quest givers are fixed camp
## NPCs (Piet, the pilgrim) or the already-overridden Ivo. All three Q10 turn-ins
## are illustrated (opener-style plates via the "scene"/cinematic hook): A
## Straight Answer (Ivo, q_straight_answer), The Second Bell (Piet, q_second_bell)
## and The Salt Reliquary (the pilgrim's hymn stops, q_salt_reliquary) — each
## Codex-generated off the giver's canon splash. Two custom sprites back the
## slate: the salt_token item icon and the fallen_bell prop (which replaced the
## watch_brazier stand-in on the Howling Fields bell hook).

const SIDE_QUESTS := {
	"still_blue": {
		"name": "Still Blue",
		"chapter": "ch2",
		"desc": "Widow Sera's mill stood on the Greyrun — grey walls, and a door she repainted blue every spring for twenty years. She wants to know if the door held.",
		"steps": [
			{"kind": "kill", "target": "blightwolf", "count": 2, "flag": "mill_road_cleared",
				"text": "Cut through the blightwolves on the Greyrun road to the mill"},
			{"flag": "mill_seen", "text": "Find the mill on the Greyrun — see whether the blue door stands"},
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
		"desc": "Sentry Piet's watch-bell cracked in the storm that broke Korrag's pack. He can't leave his post to look for where it fell — but the wolves out on the Howling Fields still answer a bell that isn't rung anymore.",
		"steps": [
			{"flag": "bell_heard", "text": "Find Piet's fallen watch-bell out on the Howling Fields"},
			{"flag": "bell_told", "text": "Tell Piet what the storm left of it"},
		],
		"reward": {"gold": 150, "gem": true, "kept": "sq_kept_bell"},
	},
	"salt_reliquary": {
		"name": "The Salt Reliquary",
		"chapter": "ch2",
		"desc": "A Choir pilgrim can't make the walk to the old boundary stone at the Salt Reliquary. She asks you to carry her salt token there — not as worship, she insists. As a debt.",
		"steps": [
			{"flag": "salt_taken", "text": "Take the pilgrim's salt token at Maren's camp"},
			{"flag": "salt_laid", "text": "Lay it at the boundary stone in the Salt Reliquary"},
		],
		"reward": {"gold": 160, "gem": true, "standing": {"choir": 2}},
	},
	"straight_answer": {
		"name": "A Straight Answer",
		"chapter": "ch2",
		"desc": "Scholar Ivo suspects the Null Bastion's warden logs contradict the Accord's tidy account of how the sealing went. He wants the transcription — and then he wants to decide, with you, what to do with it.",
		"steps": [
			{"flag": "logs_read", "text": "Read the warden logs inside the Null Bastion"},
			{"flag": "ivo_told", "text": "Bring Ivo what the logs actually say"},
		],
		"reward": {"gold": 200, "gem": true},
	},
}

const QUEST_ITEMS := {
	"sera_loaf": {"name": "Sera's Road Loaf", "icon": "sera_loaf",
		"desc": "Dark bread in waxed cloth, oven-warm when she tied it. Baked for whoever mans the far crossings.", "grade": "C"},
	"bastion_ash": {"name": "Jar of Bastion Ash", "icon": "bastion_ash",
		"desc": "Grey ash off the Null Bastion's road, sealed and labeled in Ivo's exact hand: 'ALDRIC — AS COMMISSIONED.'", "grade": "C"},
	"salt_token": {"name": "Pilgrim's Salt Token", "icon": "salt_token",
		"desc": "A disc of grey salt, pressed by hand and worn smooth from carrying. The pilgrim would not tell you whose debt it settles.", "grade": "C"},
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
	},
}

const CONVOS := {
	# "Ash for the Old Knight" — illustrated coda (2026-08-17). Turn-in chains
	# here via "scene"; plate quests/quest_ash_aldric.png uses Ser Aldric's
	# canon splash as the design ref (the burned-out legend at his fire).
	"ash_aldric_scene": {"cinematic": true, "start": "aa1", "nodes": {
		"aa1": {"who": "Narrator", "cue": "q_ash_aldric",
			"text": "Ser Aldric takes the sealed jar of Bastion ash in two scarred hands and holds it a long moment at his fire — the last knight of the Guard, who spent his ember on a killing blow that did not take, keeping a commission sixty years late. He does not open it either. He only nods, once, soldier to soldier.",
			"next": "aa_fade"},
		"aa_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"Tell Ivo it's paid,\" he says. It is the only thing he says.", "next": ""},
	}},

	# ---- Q10 illustrated turn-in beats (opener-style plates) ---------------
	# Both plates were Codex-generated with the giver's CANON splash as the
	# design ref (splash_scholar_ivo / splash_sentry_piet) + an opener plate as
	# the style ref; installed at opening/quests/quest_<base>.png. The turn-in
	# choices chain here via "scene"; each node's "cue" stages its plate.
	"straight_answer_scene": {"cinematic": true, "start": "sa1", "nodes": {
		"sa1": {"who": "Narrator", "cue": "q_straight_answer",
			"text": "Deep in the crystal dark, Scholar Ivo reads the dead warden's words a third time — nine names struck through, three attempts, a last line by a man who knew the seal would not hold the first time. He does not reach for his instruments. Some readings do not want a second measure.", "next": "sa_fade"},
		"sa_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"The Accord printed the dress and buried the wound,\" he says, to the crystals as much as to you. \"Whatever we do with this now, bearer — we do it knowing.\"", "next": ""},
	}},
	"second_bell_scene": {"cinematic": true, "start": "sb1", "nodes": {
		"sb1": {"who": "Narrator", "cue": "q_second_bell",
			"text": "At the fence's edge Sentry Piet turns the split curl of bronze in the watch-fire's light — the bell that called Korrag's pack, snapped clean by the storm that broke them. Not neglect. The weather. His shoulders come down an inch they have not come down in years.", "next": "sb_fade"},
		"sb_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"Twenty years I rang it on time,\" he says. \"A man wants to know the quiet wasn't his own doing.\" He pockets the shard, and stands his watch a little lighter.", "next": ""},
	}},
	"salt_reliquary_scene": {"cinematic": true, "start": "sr1", "nodes": {
		"sr1": {"who": "Narrator", "cue": "q_salt_reliquary",
			"text": "For the first time the pilgrim's hymn stops. Her clasped hands come apart, her bowed head lifts, and for a breath she is only a woman at a camp gate — the salt laid on the old imperial line, the debt at the far stone gone quiet at last.", "next": "sr_fade"},
		"sr_fade": {"who": "Narrator", "cue": "fade",
			"text": "\"The garden noticed,\" she says. \"It notices the small doors too.\" Then the hymn returns, softer than before, and she is a psalm again.", "next": ""},
	}},

	# ---- Q10: The Second Bell (Sentry Piet) --------------------------------
	# OVERRIDES ch2_hub.gd's "ch2_sentry" — verbatim copy, extended: s1 now
	# flows to a hub (it used to end), which offers the bell errand and takes
	# the report. All new choices are req-gated, so the index-0 convo walk is
	# unchanged.
	"ch2_sentry": {"start": "s1", "nodes": {
		"s1": {"who": "Sentry Piet",
			"text": "Quiet shift, thank the flame. The wolves out there sing most nights — real wolves, mind. You learn to tell the difference by the second week.",
			"variants": [
				{"band": "tempted", "text": "...You mind standing a bit further off? No offense. We had one of yours through last month with that same look, and I still dream about the fence."},
				{"band": "steady", "text": "Shard-bearer. Good — with you standing there the night feels half as long. Maren picks the decent ones, whatever the villages say."},
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
		"sp_bell": {"who": "Sentry Piet", "text": "\"Cracked in the storm that broke Korrag's lot — you'll have heard, if you've been east. Thing is, the wolves still come to where it hung. To the SOUND of it, and there's no sound. I can't leave the fence to go looking. But if you're out on the Fields anyway — I'd want to know where it landed. And what shape it's in.\"", "next": ""},
		"sp_told": {"who": "Sentry Piet", "text": "He turns the split shard over twice, and something in his shoulders comes down an inch. \"Snapped, not rusted. So it wasn't neglect — it was the storm leaning on the note till the iron let go.\" He pockets it. \"Twenty years I rang that bell on time. A man wants to know the quiet wasn't his own doing. Thank you, bearer.\"", "next": ""},
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
		"h2": {"who": "Choir Pilgrim", "text": "She notices you — or notices the shard. \"It hums our hymn too, bearer. Will you hear one verse? Nothing is asked. The Choir does not recruit. It WAITS.\"",
			"choices": [
				{"text": "Listen to the verse. (It costs nothing. Probably.)",
					"flags": {"heard_litany": true}, "faction": {"choir": 6},
					"resonance": -2.0, "next": "h_listen"},
				{"text": "\"Take your rot-psalms away from these people.\"",
					"flags": {"heard_litany": true}, "faction": {"choir": -6},
					"resonance": 2.0, "next": "h_rebuke"},
			]},
		"h_listen": {"who": "Narrator", "text": "The verse is about a garden that stopped pretending. It is beautiful the way a flooded quarry is beautiful, and it stays in your head three days longer than you'd like.", "next": "hp_hub"},
		"h_rebuke": {"who": "Choir Pilgrim", "text": "\"The garden doesn't mind,\" she says mildly, and keeps humming. Somehow that is worse than an argument.", "next": "hp_hub"},
		"hp_hub": {"who": "Choir Pilgrim", "text": "\"One thing, since you walk where I cannot. There is a boundary stone out in the salt — the old reliquary. A debt of mine is owed there. Salt for salt.\" A worn grey disc waits in her open hand, not quite offered yet.",
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
		"hp_take": {"who": "Choir Pilgrim", "text": "\"Salt keeps. It won't spoil on the road, and neither will the debt.\" She folds your fingers over the disc with both hands. \"Lay it flat on the imperial face. It will know the face.\"", "next": ""},
		"hp_why": {"who": "Choir Pilgrim", "text": "\"Mine,\" she says, which is not an answer, and hums until you stop asking.", "next": "hp_hub"},
		"hp_done": {"who": "Choir Pilgrim", "text": "For the first time the hymn stops. \"Then it is paid.\" For a moment she looks like a woman and not a psalm. \"Thank you, bearer. The garden noticed. It notices the small doors too.\"", "next": ""},
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
		"l_laid": {"who": "Narrator", "text": "The salt disc sits on the old imperial line like a coin on a closed eye. It does not glow, or hum, or do anything a shard would do. It just sits there, being held in common, right to the end. Somewhere back at the camp, a pilgrim's debt goes quiet.", "next": ""},
	}},

	# ---- Q10 props: the bell on the Fields, the logs in the Bastion --------
	# (placed by ZONE_PROPS above; both set a step flag through a single choice.)
	"ch2_bell": {"start": "b1", "nodes": {
		"b1": {"who": "Narrator", "text": "The bell lies half in a wind-scour, its lip split clean through — not corroded, SNAPPED, the way iron goes when something too large leans on the note. Wolf tracks ring it, old and new. They come to where the sound used to be, and mill, and leave, and come back.",
			"next": "",
			"choices": [
				{"text": "Pry loose a shard of the broken lip for Piet.",
					"flags": {"bell_heard": true}, "next": "b2"},
			]},
		"b2": {"who": "Narrator", "text": "The curl of split iron is lighter than it should be, as if the storm took something out of it that wasn't only shape.", "next": ""},
	}},
	"ch2_bastion_logs": {"start": "b1", "nodes": {
		"b1": {"who": "Narrator", "text": "A warden's log, still legible where the void-frost kept it. The Accord's histories call the sealing clean — six wardens, one rite, no losses. The log disagrees: it counts NINE names struck through, and a last entry in a shaking hand that says the seal did not hold the first time. Or the second.",
			"next": "",
			"choices": [
				{"text": "Transcribe it, word for word, for Ivo.",
					"flags": {"logs_read": true}, "next": "b2"},
			]},
		"b2": {"who": "Narrator", "text": "You copy it out exact — the struck names, the shaking last line, all of it. Ivo said 'exact' four times. You believe he meant it four times.", "next": ""},
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
				{"flag": "mill_told", "text": "Sera nods as you pass, the way people nod at good weather. \"Still blue,\" she says, to herself as much as you. She has stopped saying 'we HAD a mill.'", "next": "r_after"},
				{"flag": "mill_seen", "text": "\"You went.\" She reads it off your face before you speak. \"...And it stands? The door held?\" She sits down slowly on the cook-bench. \"Twenty years of spring paint. You tell Maren she's right — the land can be cleaned. Some of it is clean ALREADY.\"", "next": "r_told"},
				{"band": "tempted", "text": "My gran used to say the blight gets in through what you want most. ...Why are you looking at me like that, shard-bearer?"},
				{"band": "steady", "text": "You have kind eyes for someone carrying a dead king's splinter. If you get as far as the Greyrun... the mill had a blue door. I'd like to know if it's standing."},
			],
			"next": "",
			"choices": [
				{"text": "\"The Greyrun is on my road east. I'll look for your mill — and the door.\"",
					"req_not_flag": "sq_on_still_blue", "resonance": 2.0,
					"side_quest": "still_blue", "next": "r_accept"},
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
		"r_told": {"who": "Widow Sera", "text": "\"Twenty years I painted that door. Tell me true, once more — it stands?\"",
			"next": "",
			"choices": [
				# side_quest here is the RETROACTIVE accept: a player who found
				# the mill before ever hearing Sera's ask still gets the quest
				# (and its payout) the moment they carry the truth back.
				{"text": "\"It stands, Sera. The paint is winning.\"",
					"side_quest": "still_blue",
					"flags": {"mill_told": true}, "resonance": 2.0, "next": "r_told2"},
				{"text": "\"It stands. The paint is winning. — News rode a hard road, Sera; call it a courier's fee.\" Hold out your hand.",
					"side_quest": "still_blue",
					"flags": {"mill_told": true}, "resonance": -6.0, "gold": 25, "next": "r_fee"},
			]},
		"r_told2": {"who": "Narrator", "text": "Small honest cargo, delivered. It weighed nothing, and it was worth the trip.", "next": ""},
		"r_fee": {"who": "Widow Sera", "text": "She counts it out of the hem of her sleeve without a word — the mill's last rent, paid to the weather that spared it. \"It stands.\" She says it to herself, not to you, and it lands the same either way. \"Worth every copper. I'd have paid ten times over for the truth — mind that's not a thing to let people learn about you, bearer.\"", "next": ""},
		"r_accept": {"who": "Widow Sera", "text": "\"Blue. There won't be two of them out there. I sanded and repainted it every spring for twenty years — the rot hates being argued with.\" She looks at her hands. \"Don't dress it up for me, whatever you find. I've had enough weather turned kind by liars.\"", "next": ""},
		"r_loaf": {"who": "Widow Sera", "text": "She wraps a dark loaf in waxed cloth, knots it like it's going somewhere important, and weighs it once in her hand before letting it go. \"For whoever mans the far crossings — the chronicler in the crystal deep, if the crystals haven't talked him deaf. Tell him it's from Sera. Not 'the camp'. Sera.\"", "next": ""},
		"r_after": {"who": "Widow Sera", "text": "\"The ovens don't stop just because the door held. Camp still eats — and the far crossings stand their watch hungry.\"",
			"next": "",
			"choices": [
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
	}},

	# OVERRIDES ch2_zones_act2.gd's "ch2_scholar" — verbatim copy, extended:
	# the scholar_met revisit variant now lands on s_desk (it used to end
	# the scene, which would strand both courier hooks), s2 gains the two
	# gated quest choices at the END (autotest still picks choice 0), and
	# the new nodes carry Sera's loaf payoff and Aldric's ash commission.
	"ch2_scholar": {"start": "s1", "nodes": {
		"s1": {"who": "Scholar Ivo",
			"text": "Mind the resonance, shard-bearer — the crystals repeat what they hear, and some of what they heard down here predates manners. Ivo. Chronicler. Unaffiliated, whatever the envoy tells you.",
			"variants": [
				{"flag": "scholar_met", "text": "\"Still standing? Statistically remarkable. The Bastion is ahead — my notes, regrettably, end where they get interesting.\"", "next": "s_desk"},
				{"band": "tempted", "text": "The scholar looks up — then looks HARDER, the way one reads a difficult footnote. \"Fascinating. Yours is further along than most. Do sit AWAY from the crystals, if you please — they repeat things.\""},
				{"band": "steady", "text": "\"Ah — a quiet one. The crystals barely hum around you. That is the rarest reading I've taken all year, shard-bearer; I intend to write it down twice.\""},
			],
			"next": "s2"},
		"s2": {"who": "Scholar Ivo", "text": "Free knowledge, since you're heading east anyway: the Bastion ahead predates Vargoth — an ARMORY, from the war the Concord ended. What woke inside it is not blighted and not beastkin. It is MAINTENANCE, resumed after six hundred years, and it has decided the whole region is out of specification.",
			"choices": [
				{"text": "\"What do your notes say about killing it?\"",
					"flags": {"scholar_met": true}, "next": "s3"},
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk — the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
				# Q10: A Straight Answer — accept, then report the warden logs.
				{"text": "\"Your Bastion notes stop right where it gets interesting. What are you afraid they say?\"",
					"req_not_flag": "sq_on_straight_answer", "resonance": 2.0,
					"side_quest": "straight_answer", "next": "s_ask"},
				{"text": "\"I read the warden logs. The Accord's version is a lie of omission.\"",
					"req_flag": "logs_read", "req_not_flag": "ivo_told", "next": "s_fork"},
			]},
		"s3": {"who": "Scholar Ivo", "text": "\"Shed its armor before it sheds yours — it protects the frame, not the function. And when the grid stamps, DON'T be where you were standing. That sentence has cost four lives to write, so do me the courtesy of surviving it.\"", "next": ""},
		# -- A Straight Answer: the ask, then the fork over what to do with it.
		"s_ask": {"who": "Scholar Ivo", "text": "\"Afraid. Yes. Good word.\" He sets down his stylus. \"The Accord's account of the sealing is TOO clean — six wardens, one rite, done. Inside the Bastion there's a warden's own log. If it says what I think it says, then the tidy version is a kindness someone chose to tell. Read it for me. Word for word — the crystals taught me what 'roughly' costs.\"", "next": ""},
		"s_fork": {"who": "Scholar Ivo", "text": "He reads your transcription twice, the second time slower. \"Nine names. Three attempts. A last line by a man who knew.\" He is very still. \"So. I can publish this exactly — the sealing was a slaughter dressed as a rite, and the Accord has been printing the dress. Or I summarize kindly: it held, the cost was borne, spare the grandchildren the arithmetic. You carried it. You've earned the vote.\"",
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
		"s_desk": {"who": "Scholar Ivo", "text": "\"Back again. Good — the crystals repeat dull company.\" He waves at the sample desk without looking up.",
			"next": "",
			"choices": [
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk — the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
				{"text": "\"Your Bastion notes stop right where it gets interesting. What are you afraid they say?\"",
					"req_not_flag": "sq_on_straight_answer", "resonance": 2.0,
					"side_quest": "straight_answer", "next": "s_ask"},
				{"text": "\"I read the warden logs. The Accord's version is a lie of omission.\"",
					"req_flag": "logs_read", "req_not_flag": "ivo_told", "next": "s_fork"},
				{"text": "\"Mind the crystals, Ivo.\" (leave)", "next": ""},
			]},
		"s_loaf": {"who": "Scholar Ivo", "text": "\"...Bread. OVEN bread.\" He takes the bundle in both hands, the way one handles a first edition. \"I have catalogued four hundred resonance events this year, bearer, and this is the finest data among them. Tell Sera the crossing is manned — and that the crossing says thank you. From Ivo. Not 'the deeps'. Ivo.\"", "next": ""},
		"s_jar": {"who": "Scholar Ivo", "text": "\"Ah. A commission, technically — Ser Aldric wrote me exactly one letter in thirty years. 'A pinch of ash off the Bastion road. I want to know what it burns like now.' His words. I collected it in the spring; the couriers, you'll have noticed, stopped running.\" He taps the wax seal. \"The jar weighs nothing, and the debt isn't yours. But you ARE walking west.\"",
			"choices": [
				{"text": "Take the jar. \"An old knight's one letter shouldn't go unanswered.\"",
					"req_not_flag": "ash_taken", "resonance": 2.0,
					"gain_item": "bastion_ash", "flags": {"ash_taken": true},
					"side_quest": "ash_for_aldric", "next": "s_ash"},
				{"text": "\"Not my road today.\" Leave it on the desk.", "next": ""},
			]},
		"s_ash": {"who": "Scholar Ivo", "text": "\"Careful hands. It took the wind six centuries to grind the Bastion road that fine — a fact I will thank you not to test by dropping it.\" He returns to his instruments, then, without looking up: \"Tell the old man the chronicler keeps his ledgers. All of them.\"", "next": ""},
	}},

	# OVERRIDES ch2_aldric.gd's "ch2_aldric" — verbatim copy, extended with
	# one hub choice appended at the END, gated on actually carrying Ivo's
	# jar (req_flag ash_taken): invisible in every suite convo-walk state,
	# so the hub's asserted choice counts (3 pre-act, 4 post) still hold.
	"ch2_aldric": {"start": "g1", "nodes": {
		"g1": {"who": "Ser Aldric",
			"text": "Don't salute. The arm doesn't come up past the shoulder anymore, and returning it embarrasses us both. Sit, shard-bearer. The fire's the only thing here that still burns properly.",
			"variants": [
				{"band": "tempted", "text": "...Come closer where I can see you. Hm. Yours is loud, isn't it — I can almost hear it from here. Mine was loud too, near the end. Sit down anyway. It hates patience."},
				{"band": "steady", "text": "There's a way people stand when the shard serves THEM and not the other way round. You stand like that. It's rarer than Maren lets on. Sit — good company earns the good stump."},
			],
			"next": "hub"},
		"hub": {"who": "Ser Aldric", "text": "Ask, then. Old men and dead kings both like being asked.",
			"choices": [
				{"text": "\"What did it cost — killing him?\"", "next": "p1"},
				{"text": "\"What IS the Ember Crown, really?\"",
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
		"p1": {"who": "Ser Aldric", "text": "Everything I was carrying. You don't swing an ember at a god-king and keep the ember — I knew that walking in. What they don't tell you is the AFTER. Colors are dimmer. Bread is just bread. The fire in me went out and took the pilot light with it.", "next": "p1b"},
		"p1b": {"who": "Ser Aldric", "text": "And still: cheap. Cheapest thing I ever bought, that blow. Remember that when yours starts telling you what you can't afford to lose.", "next": "hub"},

		# -- Part 2: the Crown's true nature (needs Maren's briefing).
		"p2": {"who": "Ser Aldric", "text": "Maren gave you the recruiting-poster version, I expect. Here's the armory version: it was never ONE thing. Four embers, carried by the Guard's four founders, forced to burn as a single crown. Vargoth didn't steal a symbol — he chained four old fires together and wore the chain as jewelry.", "next": "p2b"},
		"p2b": {"who": "Ser Aldric", "text": "So when people say the Crown 'shattered' — no. Chains shatter. Fires SCATTER. That thing in your chest is one of the original four, or a splinter off one, and it remembers being free. Every shard-bearer in Vaelscar is carrying a piece of an argument that started six hundred years ago.", "next": "hub"},

		# -- Part 3: what he never told anyone (needs act progress).
		"p3": {"who": "Ser Aldric", "text": "...You've been east. Seen what the Waking does. All right. All right. Come closer — this one isn't for the sentries.", "next": "p3b"},
		"p3b": {"who": "Ser Aldric", "text": "When my blade went in, the Crown SPOKE. Not to Vargoth. To me. It said — and I have had thirty years to mishear this kindly, so believe me when I say I haven't — it said: 'WELL STRUCK. NOW WE CHOOSE OUR OWN.'", "next": "p3c"},
		"p3c": {"who": "Ser Aldric",
			"text": "It wasn't defeated, bearer. It DISMISSED itself. The scattering wasn't an accident of my blow — the shards went LOOKING. Which means every one of you was picked, by something with six hundred years of patience and a grudge against chains. I never told Maren because she'd have hunted every bearer down for caution's sake. And because... maybe being chosen is not the same as being owned. You lot get to decide that part. That's the whole of my hope, and I keep it right here next to the bad arm.",
			"variants": [
				{"band": "tempted", "text": "It wasn't defeated. It DISMISSED itself, and the shards went LOOKING for their bearers. Yours leaned in just now when I said it — don't pretend it didn't, I saw your face. So hear the rest: chosen is not the same as owned. The thing picked you for a reason. YOU pick what the reason means. That trick is the only sword I have left to give anyone."},
			],
			"next": "p3d"},
		"p3d": {"who": "Narrator", "text": "The old knight leans back, lighter by exactly one secret. Whatever you carry in your chest is very, very quiet — the way a listener is quiet.", "next": "hub"},

		# -- The ash commission, answered (Q2: ash_for_aldric payoff).
		"p_ash": {"who": "Narrator", "text": "He works the wax off one-handed, unhurried, like a man opening a letter he already knows the contents of. Then he takes a pinch and feeds it to his own small fire. It burns orange. Just orange. He watches it the way other men watch a grave filled in.", "next": "p_ash2"},
		"p_ash2": {"who": "Ser Aldric", "text": "It burned GREEN, the night we took that road. Sixty years the ash held the color of the wound — I know, I kept asking. And now it's just ash again. The land forgets faster than the men do, bearer. That is the kindest thing anyone has carried me in years, and it came in a JAR.", "next": "hub"},

		"g_bye": {"who": "Ser Aldric", "text": "Easy is for the dead, and they earned it. Go on, bearer. Mind the east road — and mind the voice more.", "next": ""},
	}},
}
