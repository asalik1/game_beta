## (Q5) Chapter 5 side quests — The Long Sleep (QUESTS_TASKS.md).
## Three flag-chain quests on the side-quest engine, hooked into ch5's
## existing rooms and convos (no new zones):
##   - Forty Mouths: after the ridge, deliver the cult's toll-grain to
##     Tracker Yri honestly (Sleeper's Wagon cache -> the Last Fire).
##   - The Spring Song: skald Ottar's one non-winter song, written down
##     and read to Ansa of the Shore (wanderer giver: run-conditional,
##     like the hat pilot).
##   - Count the Sleepers: a true census for Yri — the Buried Chapel's
##     congregation, then the oldest sleeper in the Vein of the Queen.
## Post-flag hooks ride on redirected variant "next"s (a matched variant
## with "next" skips a node's choices), so re-talking to a quest NPC
## lands on a choice hub instead of dead-ending on the greeting.

const SIDE_QUESTS := {
	"ch5_forty_mouths": {
		"name": "Forty Mouths",
		"chapter": "ch5",
		"desc": "Hrolgar's toll died with him, but the toll-grain still sits cached on the white road. Yri will see it dealt by need, not by watch-rota — if someone carries it back honest.",
		"steps": [
			{"flag": "ch5_grain_taken", "text": "Recover the ridge-toll grain cached at the Sleeper's Wagon"},
			{"flag": "ch5_grain_given", "text": "Set the grain down at Tracker Yri's fire"},
		],
		"reward": {"gold": 200, "standing": {"wildfang": 4}},
	},
	"ch5_spring_song": {
		"name": "The Spring Song",
		"chapter": "ch5",
		"desc": "Skald Ottar has a hundred songs of winter and one of spring, written now in his own hand. The Last Fire has heard nothing but the Queen's hymn all season.",
		"steps": [
			{"flag": "ch5_verse_taken", "text": "Have Ottar set the spring song down in writing"},
			{"flag": "ch5_verse_given", "text": "Read the verse to Ansa of the Shore at the Last Fire"},
		],
		"reward": {"gold": 120},
	},
	"ch5_count_sleepers": {
		"name": "Count the Sleepers",
		"chapter": "ch5",
		"desc": "Nobody in the valley can say how many sleep. Tracker Yri wants a true count: the buried chapel's congregation — and the one sleeper every census leaves off.",
		"steps": [
			{"flag": "ch5_census_chapel", "text": "Count the congregation in the Buried Chapel"},
			{"flag": "ch5_census_vein", "text": "Count the oldest sleeper, in the Vein of the Queen"},
			{"flag": "ch5_census_told", "text": "Bring the census back to Tracker Yri"},
		],
		"reward": {"gold": 180},
	},
}

const QUEST_ITEMS := {
	"ch5_grain_bundle": {
		"name": "Ridge-Toll Grain",
		"desc": "The cult's toll-grain, cord-bound and weighed to the ounce — Hrolgar always checked. Heavy the way owed things are heavy.",
		"grade": "C"},
	"ch5_spring_verse": {
		"name": "Ottar's Spring Song",
		"desc": "The spring song in the skald's own small sure hand — a thaw, a river, boots by a door. It wants a low voice and a fire going.",
		"grade": "C"},
}

const CONVOS := {
	# OVERRIDES ch5_zones.gd's ch5_briefing — Tracker Yri. Verbatim copy;
	# changes only: the ch5_debrief_done / ch5_briefed greeting variants
	# and the y_honor / y_cold accounting tails now continue to "sq_hub"
	# (the side-quest choice hub) instead of ending, plus the new sq_*
	# nodes. The first-briefing walk (b1->b2->b3->choice 0) is untouched.
	"ch5_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Tracker Yri",
			"text": "So the south sends a shard-bearer. Yri, Wildfang — winter clans. Before anything else, understand what you're walking into: nobody out there is evil. That's what makes this one hard.",
			"variants": [
				{"flag": "ch5_debrief_done", "text": "The road's yours, bearer. Walk it warm.", "next": "sq_hub"},
				{"flag": "whitepelt_dead", "next": "y_after", "text": "You came back. Sit by the fire — there's an accounting between us, and I'd have it now."},
				{"flag": "ch5_briefed", "text": "The ridge first, bearer. And remember what I said about Hrolgar — POLICY. Keep it policy.", "next": "sq_hub"},
				{"flag": "chose_foreman_court", "text": "The south sends a bearer — the one who stood in a foundry full of grief and refused the gavel, if the freight-tales run true. Good. This valley is going to offer you a gavel a day. Yri, Wildfang. Sit."},
				{"flag": "chose_foreman_judged", "text": "The south sends a bearer — the one who passed a foundry verdict with nine mourners for a jury, the freight-tales say. Mind yourself here: this valley LOVES a stranger who decides things for people. That's how the cult recruits. Yri, Wildfang. Sit."},
			],
			"next": "b2"},
		"b2": {"who": "Tracker Yri", "text": "The Long Sleep cult carries sleepers north — their own kin, freely given, to 'wait for the Queen's morning' in the deep ice. Madness, but GENTLE madness, and here's the knot: they pay the winter clans in grain for safe passage. Famine snow, bearer. That grain is the only reason my cousins' children have marrow in their bones this year.", "next": "b3"},
		"b3": {"who": "Tracker Yri", "text": "Hrolgar Whitepelt holds the Watch Ridge for them. He is not corrupted, not mad, not cruel — he is a chieftain who found one way to feed forty mouths and doesn't ask what the wagons carry. You will have to move him, and he will not move. I'm asking you to know all of that BEFORE the ridge, not after.",
			"choices": [
				{"text": "\"I'll give him every chance to stand aside — and carry it plainly if he won't.\"",
					"resonance": 6.0, "flags": {"ch5_briefed": true}, "quest": "whitepelt", "next": "b_plain"},
				{"text": "\"He guards wagons full of sleeping people, Yri. Whatever his reasons, that has a name.\"",
					"resonance": -4.0, "flags": {"ch5_briefed": true}, "quest": "whitepelt", "next": "b_hard"},
				{"text": "\"Understood. The ridge, the keystone, the shepherd — in that order.\"",
					"resonance": 0.0, "flags": {"ch5_briefed": true}, "quest": "whitepelt", "next": "b_work"},
			]},
		"b_plain": {"who": "Tracker Yri", "text": "Every chance. He won't take it — pride and forty mouths make a man immovable — but the offering matters. It'll matter to the clans, after. Walk warm, bearer.", "next": ""},
		"b_hard": {"who": "Tracker Yri", "text": "It has a name. So does famine. You'll notice neither name helps once you're standing on that ridge looking at a man doing wrong sums for right reasons. ...Go. And bearer — however it ends up there, the CLANS will be listening to how you tell it.", "next": ""},
		"b_work": {"who": "Tracker Yri", "text": "In that order. The ridge opens the road, the keystone gallery sits under the frozen shore, and the shepherd — Mother Halla — gathers at the valley's far end. Warm hands, bearer. Cold decisions.", "next": ""},
		# The accounting: how you SPEAK of the kill moves the clans.
		"y_after": {"who": "Tracker Yri", "text": "Hrolgar Whitepelt is dead, and his pack dragged him home, and forty mouths are asking what happens to the grain. So tell me straight, bearer, because the clans will hear it in YOUR words: what happened on my ridge?",
			"choices": [
				{"text": "\"A chieftain held the only line he had, and lost to a stronger hand. Your clans should sing him honest — I'll say so anywhere.\"",
					"resonance": 4.0, "faction": {"wildfang": 6}, "flags": {"ch5_debrief_done": true}, "next": "y_honor"},
				{"text": "\"A man sold a valley of sleepers for grain and called it feeding his clan. I ended the arrangement.\"",
					"resonance": -4.0, "faction": {"wildfang": -5, "accord": 2}, "flags": {"ch5_debrief_done": true}, "next": "y_cold"},
			]},
		"y_honor": {"who": "Tracker Yri", "text": "...Sing him honest. Aye. The clans will hear that a stranger spoke of Hrolgar like a chieftain and not a toll-gate — that buys more peace than the grain did, and I'll see the grain replaced somehow. Walk warm, bearer. You just did.", "next": "sq_hub"},
		"y_cold": {"who": "Tracker Yri", "text": "'The arrangement.' Forty children, bearer — that was the arrangement. ...No. You're not wrong, and I'll not pretend you are. But the clans will hear a southerner call our chieftain a toll-keeper over his own cairn, and winters are long, and we REMEMBER things in winter. Go do your keystone.", "next": "sq_hub"},
		# ---- Side-quest hub (Q5): every choice is flag-gated, so this
		# node reads as a plain sign-off whenever nothing is pending.
		"sq_hub": {"who": "Tracker Yri", "text": "Something else, bearer? The fire's warm and my ears work.",
			"choices": [
				{"text": "\"Who counts the sleepers, Yri? Not the wagons — the ones already out there, in the drifts and the pews.\"",
					"req_not_flag": "sq_on_ch5_count_sleepers",
					"side_quest": "ch5_count_sleepers", "next": "sq_census_go"},
				{"text": "Report the census: a chapel full — and one more, deep in the crystal, older than the rest.",
					"req_flag": "ch5_census_vein", "req_not_flag": "ch5_census_told",
					"resonance": 2.0, "flags": {"ch5_census_told": true}, "next": "sq_census_done"},
				{"text": "\"Hrolgar's arrangement died with him — but the toll-grain's still out on that road. The clans should have it. Honestly, this time.\"",
					"req_flag": "ch5_debrief_done", "req_not_flag": "sq_on_ch5_forty_mouths",
					"side_quest": "ch5_forty_mouths", "next": "sq_grain_go"},
				{"text": "Set the toll-grain down by her fire, cord and all.",
					"req_flag": "ch5_grain_taken", "req_not_flag": "ch5_grain_given",
					"lose_item": "ch5_grain_bundle", "flags": {"ch5_grain_given": true}, "next": "sq_grain_done"},
				{"text": "\"Nothing more. Walk warm, Yri.\"", "next": ""},
			]},
		"sq_census_go": {"who": "Tracker Yri", "text": "...Nobody. Nobody counts them — the cult calls it doubt and the Accord calls it despair, and between the two the valley's dearest number goes unkept. Count them TRUE, bearer. Start with the chapel buried off the white road — a whole congregation under the snow. And if the deep crystal ever lets you near the Queen's vein... count HER too. A census that leaves her off is the lie this valley's been telling for six hundred years.", "next": ""},
		"sq_census_done": {"who": "Tracker Yri", "text": "A chapel full, and the one they're all walking toward. ...Aye. I'll send the count south with the next rider — let the Accord put a NUMBER under the word 'valley' for once. Kept count is kept faith, bearer. The clans thank you for both.", "next": ""},
		"sq_grain_go": {"who": "Tracker Yri", "text": "...Honestly. Aye, there's the word this valley's been short of. The porters kept a toll-cache at the sleeper's wagon on the white road — grain weighed out for a chieftain who isn't coming to collect it. Bring it to my fire and I'll see it goes by NEED, not by watch-rota. Forty mouths, bearer. Walk warm.", "next": ""},
		"sq_grain_done": {"who": "Tracker Yri", "text": "Full weight, cord uncut — you didn't skim it, and I'll tell them so. This buys porridge, bearer, and something dearer than porridge: proof the grain didn't die with the arrangement. The clans will remember who carried it in.", "next": ""},
	}},

	# OVERRIDES ch5_zones.gd's ch5_mother — Ansa of the Shore. Verbatim
	# copy; changes: the ch5_ansa_heard greeting variant continues to
	# "m_more" (delivery hub) instead of ending, the spring-song delivery
	# choice is APPENDED to m1 (gated: invisible without the verse), and
	# the new m_more / m_song nodes.
	"ch5_mother": {"start": "m1", "nodes": {
		"m1": {"who": "Ansa of the Shore",
			"text": "My husband and both boys sleep in the valley. I didn't consent — I was at market, one day, ONE day, and Halla's people came through our village singing, and when I got home the beds were empty and the neighbor said they walked out SMILING. Smiling. My youngest is afraid of the dark, bearer. Nobody who knows him would believe he walked toward that ice glad.",
			"variants": [{"flag": "ch5_ansa_heard", "text": "You remember — Toma fears the dark. If the sleep breaks and he wakes far from home... someone kind should be the first thing he sees. Let it be soon.", "next": "m_more"}],
			"choices": [
				{"text": "\"Toma, was it? If the sleepers wake when this ends, I'll see the criers carry word to the shore first.\"",
					"resonance": 4.0, "flags": {"ch5_ansa_heard": true}, "next": "m_kind"},
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
			"choices": [
				{"text": "Unfold Ottar's paper and read her the spring song — the thaw, the river, the boots by the door.",
					"req_flag": "ch5_verse_taken", "req_not_flag": "ch5_verse_given",
					"resonance": 2.0, "lose_item": "ch5_spring_verse",
					"flags": {"ch5_verse_given": true}, "next": "m_song"},
			]},
		"m_song": {"who": "Narrator", "text": "You read it low, like the skald said. A thaw. A river loosening. Somebody's boots drying by a door, because the somebody came HOME. Ansa listens the whole way through with her eyes shut, and when she opens them she is looking SOUTH — the first time you've seen her face that way. \"Toma will ask for the river part twice,\" she says. \"When he wakes, I'll have it ready. Thank the skald. Tell him it landed.\"", "next": ""},
	}},

	# OVERRIDES ch5_zones.gd's ch5_shrine_wagon — the Sleeper's Wagon.
	# Verbatim copy; changes: the wagon_decided greeting variant continues
	# to "w_road" instead of ending (the shrine's own three choices stay
	# exactly as authored), the toll-grain choice is APPENDED to w1, and
	# the new w_road / w_grain nodes. The cache sits at the ROADSIDE, so
	# the grain is there whichever way the wagon itself went.
	"ch5_shrine_wagon": {"start": "w1", "nodes": {
		"w1": {"who": "Narrator",
			"text": "A cult wagon, stopped mid-road — the porter froze dead in the traces days ago, still leaning north. Under the frosted canvas: eleven sleepers, laid like cordwood, breathing once a minute. One is a child clutching a wooden horse. North lies the deep ice and the Queen's promised morning. South, the waystation, fires, and the slow lottery of waking cold. The wagon cannot stay here. The choice of WHERE it goes appears to be yours, and the shard in you is very quiet, the way it goes quiet at the real ones.",
			"variants": [{"flag": "wagon_decided", "text": "The wagon is gone from the road — moved by your hands, whichever way. The wheel-ruts point the way you chose, filling slowly with snow, and the shard keeps its opinion to itself.", "next": "w_road"}],
			"choices": [
				{"text": "Haul it SOUTH, to the waystation fires. Waking is a risk; the Queen's pantry is a promise. Choose the risk for them.",
					"resonance": 8.0, "flags": {"wagon_decided": true, "chose_wagon_south": true}, "next": "w_south"},
				{"text": "Haul it NORTH, as the porter promised the families. Their kin chose the sleep — finishing another's vow is not yours to unmake.",
					"resonance": -6.0, "flags": {"wagon_decided": true, "chose_wagon_north": true}, "next": "w_north"},
				{"text": "Unhitch the traces and leave the wagon on the road. Not every burden that finds you is yours.",
					"resonance": -3.0, "flags": {"wagon_decided": true}, "next": "w_leave"},
				{"text": "Dig out the porters' roadside cache — the ridge-toll grain, bound for a watch that no longer collects.",
					"req_flag": "sq_on_ch5_forty_mouths", "req_not_flag": "ch5_grain_taken",
					"gain_item": "ch5_grain_bundle", "flags": {"ch5_grain_taken": true}, "next": "w_grain"},
			]},
		"w_south": {"who": "Narrator", "text": "The traces bite your shoulders for two frozen miles. At the waystation they take the sleepers in by the fire, and by dusk three are shivering, and by night one — the child — opens her eyes and asks, furious, where her horse is. It's in her hand. Some of the others may never wake; you chose their risk without their leave, and you will carry that. She's holding the horse, though. She's HOLDING it.", "next": ""},
		"w_north": {"who": "Narrator", "text": "You lean where the porter leaned, and haul the vow to its keeping. At the ice-line the cult receives the wagon with tears of plain gratitude — eleven promises delivered, they say, eleven sleepers safe till morning. The shard says nothing all the long walk back. It is thinking, you suspect, about the difference between honoring a promise and FEEDING one, and it is glad, for once, that the thinking is yours to do.", "next": ""},
		"w_leave": {"who": "Narrator", "text": "You unhitch the dead porter and lay him decently by the road, and leave the wagon anchored where it stands. Someone will find it — the cult, the clans, the wardens; the road is walked. Someone with more right, you tell yourself, or at least more certainty. The snow starts an hour later. You do not go back to check. That, too, is a choice, and the shard files it with the others.", "next": ""},
		"w_road": {"who": "Narrator", "text": "The snow keeps its slow accounting of the wheel-ruts. By the road's shoulder a waymarker leans over the porters' cache-stone — whatever the road is still owed, it holds.",
			"choices": [
				{"text": "Dig out the porters' roadside cache — the ridge-toll grain, bound for a watch that no longer collects.",
					"req_flag": "sq_on_ch5_forty_mouths", "req_not_flag": "ch5_grain_taken",
					"gain_item": "ch5_grain_bundle", "flags": {"ch5_grain_taken": true}, "next": "w_grain"},
			]},
		"w_grain": {"who": "Narrator", "text": "The cache-stone gives up the sacks stiff as boards: toll-grain, cord-bound, weighed to the ounce — Hrolgar always checked. You shoulder the lot. It rides heavier than gear, the way owed things do, and every frozen mile of it is somebody's porridge.", "next": ""},
	}},

	# OVERRIDES ch5_zones.gd's ch5_lore_chapel — the Buried Chapel dig.
	# Verbatim copy + two APPENDED census choices (both gated on the
	# quest, so the prop stays a plain lore read otherwise) and l_count.
	"ch5_lore_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A village chapel drowned in snow to the bell-rope. Digging down, you find the door ajar and the pews full: the whole congregation, asleep in their coats, frost-lace on their folded hands. The altar candle burned down years ago. On the lectern, the priest's last sermon sits open, one line underlined twice: 'THE FLAME ALSO RESTS, BUT IT DOES NOT LET THE HEARTH GO COLD.' He is not among the sleepers. His footprints, they say, went north alone — to argue with the Queen in person, and no one has ever found the end of them.",
			"choices": [
				{"text": "Count them for Yri's census — pew by pew, every folded pair of hands.",
					"req_flag": "sq_on_ch5_count_sleepers", "req_not_flag": "ch5_census_chapel",
					"resonance": 2.0, "flags": {"ch5_census_chapel": true}, "next": "l_count"},
				{"text": "Draw the snow back over the door. Not today.",
					"req_flag": "sq_on_ch5_count_sleepers", "req_not_flag": "ch5_census_chapel", "next": ""},
			],
			"next": ""},
		"l_count": {"who": "Narrator", "text": "Thirty-one. You count twice, because a census of the sleeping deserves the same care as one of the living, and it comes to thirty-one twice. The priest's underlined line watches you work the whole time. On the way out you cut the clan tally-mark into the door-post, the way Yri showed you — so the next counter knows these thirty-one are already carried.", "next": ""},
	}},

	# OVERRIDES ch5_zones.gd's ch5_lore_vein — the Vein of the Queen.
	# Verbatim copy + two APPENDED census choices (gated on the chapel
	# count, which itself implies the quest) and l_one.
	"ch5_lore_vein": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The keystone's crystal vein runs through the gallery wall like frozen lightning, and deep inside it — a meter into solid crystal — hang flowers. Meadow flowers, summer-bright, mid-sway, six hundred years old. The Concord's binders sealed the Queen in high summer, and she took one armful of it down with her. Preservation, the scholars call her domain. Standing here, you'd call it homesickness with a jaw that never unclenches.",
			"choices": [
				{"text": "Add one to Yri's census. The oldest sleeper in the valley — count her too.",
					"req_flag": "ch5_census_chapel", "req_not_flag": "ch5_census_vein",
					"resonance": 2.0, "flags": {"ch5_census_vein": true}, "next": "l_one"},
				{"text": "Some counts want distance. Step back from the crystal.",
					"req_flag": "ch5_census_chapel", "req_not_flag": "ch5_census_vein", "next": ""},
			],
			"next": ""},
		"l_one": {"who": "Narrator", "text": "One. You set it down the way the ledgers would: name unknown, held six hundred years, condition — preserved. The flowers sway for a wind that died before your grandmother's grandmother was born. Somewhere under all that keeping sits a count of one, with a whole valley in orbit around it. You close the tally. It weighs more than the chapel's thirty-one together.", "next": ""},
	}},

	# OVERRIDES ch5_zones.gd's ch5_wander_skald — Skald Ottar (wanderer:
	# rolls in ~half of runs, so the quest is run-conditional like the
	# hat pilot). Verbatim copy; changes: the ch5_ottar_met greeting
	# variant continues to "k_again" instead of ending, k_spring gains
	# two APPENDED gated choices, and the new k_again / k_write nodes.
	"ch5_wander_skald": {"start": "k1", "nodes": {
		"k1": {"who": "Skald Ottar",
			"text": "A song for the road, southerner? I've a hundred of winter and one of spring, and nobody ever asks for the spring one. Winter-clan taste. We like our songs the way we like our news: bad, but survivable.",
			"variants": [{"flag": "ch5_ottar_met", "text": "Back for the spring song after all? Everyone comes back for it eventually. Usually the same week they start checking the ice for cracks.", "next": "k_again"}],
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
	}},
}
