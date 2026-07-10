## (Q7) Chapter 7 side quests — The Breaking Sky. Content module (see
## README.md): three flag-chain side quests on the side-quest engine,
## registered via one line in Story.CONTENT_MODULES.
##
##   ch7_relay_stands — Retired Keeper Vasse's rounds: stand a keeper's
##                      breath at the relay's three dead stations
##                      (wanderer giver — run-conditional, like the
##                      ch1 pilot).
##   ch7_void_letter  — the void shelf's sealed letter, carried UNOPENED
##                      to Elder Maren, who has outlived enough of
##                      Vaelscar to qualify as its address.
##   ch7_korrags_due  — the order's shift-token, left at last on the
##                      Stormwarden's cairn (wildfang standing).
##
## All hooks are convo OVERRIDES of ch7_zones.gd surfaces — no zones,
## no NPCs added. Quest choices are appended at the END of choice lists
## and gated on sq_on_*/step flags; revisit variants that used to end
## with next "" are extended into new nodes so the hooks stay reachable
## after first contact (the walker only talks to the gate NPC pre-brief,
## and the briefing's choice order is untouched).

const SIDE_QUESTS := {
	"ch7_relay_stands": {
		"name": "The Relay Stands",
		"chapter": "ch7",
		"desc": "Thirty years of relay shifts before her voice went, and Retired Keeper Vasse still mouths her old hour nightly. She can't climb to the line's dead stations anymore. Stand a breath at each — so somebody has.",
		"steps": [
			{"flag": "sq7_relay_vowstone", "text": "Stand a keeper's moment at the Vow-Stone"},
			{"flag": "sq7_relay_cairn", "text": "Stand a keeper's moment at Korrag's Cairn"},
			{"flag": "sq7_relay_shelf", "text": "Stand a keeper's moment at the shelf on the void's edge"},
		],
		"reward": {"gold": 220},
	},
	"ch7_void_letter": {
		"name": "For Someone Who Will Remember",
		"chapter": "ch7",
		"desc": "On the void shelf, among the kept things: a sealed letter, addressed in a hand that makes the shard flinch — TO SOMEONE WHO WILL REMEMBER. Elder Maren qualifies. The seal stays unbroken. That is the entire job.",
		"steps": [
			{"flag": "sq7_letter_taken", "text": "Take the sealed letter from the void shelf"},
			{"flag": "sq7_letter_given", "text": "Bring it, seal unbroken, to Elder Maren at the Summit Camp"},
		],
		"reward": {"gold": 200},
	},
	"ch7_korrags_due": {
		"name": "Korrag's Due",
		"chapter": "ch7",
		"desc": "The beast-clans buried the Stormwarden under plains stone and six hundred offerings. His own order never left one. Apprentice Sorrel means to fix that — carry the relay's shift-token up the downs and leave it with the wolf teeth.",
		"steps": [
			{"flag": "sq7_token_taken", "text": "Take the order's shift-token from Apprentice Sorrel"},
			{"flag": "sq7_token_left", "text": "Leave it among the offerings on Korrag's Cairn"},
		],
		"reward": {"gold": 150, "standing": {"wildfang": 4}},
	},
}

const QUEST_ITEMS := {
	"ch7_void_letter": {"name": "A Sealed Letter", "grade": "C",
		"desc": "Addressed in a hand that makes the shard flinch: TO SOMEONE WHO WILL REMEMBER. The seal is unbroken. Keep it that way — that is the entire job."},
	"ch7_korrag_token": {"name": "Speaker's Shift-Token", "grade": "C",
		"desc": "Storm-iron, thumb-polished, passed warm at every relay change for six hundred years. The order's last. Owed, long since, to a cairn on the downs."},
}

const CONVOS := {
	# OVERRIDES ch7_zones.gd's ch7_wander_keeper — first-meeting flow
	# unchanged; the ch7_vasse_met revisit now leads to Vasse's ask
	# (accept), and quest-state variants handle reminder / completion.
	"ch7_wander_keeper": {"start": "k1", "nodes": {
		"k1": {"who": "Retired Keeper Vasse",
			"text": "Thirty years I stood relay-shifts before my voice went — you never miss a shift, bearer, that was the whole vow. You could hate the man beside you, hate the RAIN, hate the words; you spoke your hour and passed the line on warm. Six hundred years of nobody missing a shift. And then Cyrraeth, flame keep his brilliant ruined mind, didn't miss his shift either. He ATTENDED it. He just spent it listening instead. The vow never thought to forbid that. Vows never forbid the thing that kills them.",
			"variants": [
				{"flag": "sq_paid_ch7_relay_stands", "text": "The line still holds, keeper. — You say it plainly, the way a relief reports in, and she takes it exactly that way: no tears, one nod, and thirty years come down off her shoulders an inch. \"Then tonight I mouth my hour for the STATIONS, not the dead. Flame keep you, bearer. Shift's yours now.\"", "next": ""},
				{"flag": "sq_on_ch7_relay_stands", "text": "Three posts, bearer: the Vow-Stone on its hilltop, the cairn the clans raised for Korrag, and what the tear left of the third station — that shelf at the void's edge. A breath at each. That's all a shift ever was, at bottom: somebody THERE.", "next": ""},
				{"flag": "ch7_vasse_met", "text": "Still here. Still mouthing my old hour every night at the right time — voice or no voice. The line's cut, the storm knows it, and an old keeper's lips moving in a tent change nothing. I do it anyway. Shifts are shifts.", "next": "k_offer"},
			],
			"choices": [
				{"text": "\"Shifts are shifts. Keep speaking yours, keeper — the sky remembers manners even cracked.\"",
					"resonance": 3.0, "flags": {"ch7_vasse_met": true}, "next": "k_keep"},
				{"text": "\"The line's cut, keeper. Mouthed hours warm nobody — save the breath for winter.\"",
					"resonance": -4.0, "flags": {"ch7_vasse_met": true}, "next": "k_cut"},
			]},
		"k_cut": {"who": "Retired Keeper Vasse", "text": "Warm nobody. — She takes it standing, the way she stood thirty years of rain. \"You know what else warms nobody, bearer? A watch. A count. A candle in a drowned window. Half of what holds this world together warms nobody, and the vow knew it, which is why the vow never once mentioned WARM.\" She turns back toward her tent, and her lips are already moving. \"My hour's at moonrise. It will be spoken. You're welcome at it or you're not.\"", "next": ""},
		"k_keep": {"who": "Retired Keeper Vasse", "text": "...The sky remembers manners. Ha. You talk like the third-century keepers wrote, bearer — they'd have liked you. Go on up. And when you meet him — when you meet what's LEFT of him — remember he kept every shift for forty years before the listening. Kill the Mouth. Mourn the Speaker. The order always could hold two things at once; it's the storm that only holds one.", "next": ""},
		# Vasse's ask — reachable on any revisit after her story.
		"k_offer": {"who": "Retired Keeper Vasse",
			"text": "...There is a thing you could do. Not for me — for the LINE. Three of the old stations still stand within a day's walk of this camp, and no keeper has stood at any of them since my knees went. Stand a breath at each. That's the whole ask. A line is only cut if nobody walks it.",
			"choices": [
				{"text": "\"Name your stations, keeper. I'll stand your rounds.\"",
					"resonance": 2.0, "side_quest": "ch7_relay_stands", "next": "k_accept"},
				{"text": "\"Another night, keeper. The storm has me spoken for.\"", "next": ""},
			]},
		"k_accept": {"who": "Retired Keeper Vasse", "text": "The Vow-Stone, where the sentence started. The cairn the clans raised for Korrag — the only station the order never built, for the only keeper who'd have laughed at that. And the third post... the tear took the third post, bearer. What the void kept of it is a shelf now, at the edge. Stand there too. ESPECIALLY there. The line doesn't stop where the map does.", "next": ""},
	}},

	# OVERRIDES ch7_zones.gd's ch7_shrine_vowstone — the shrine's three
	# choices and their scenes are untouched; a gated station choice is
	# APPENDED, and the touched-revisit variant now leads to a node that
	# keeps the station reachable after the shrine has been answered.
	"ch7_shrine_vowstone": {"start": "v1", "nodes": {
		"v1": {"who": "Narrator",
			"text": "The Vow-Stone — the relay's first waypost, where the recitation began six hundred years ago. The binding's LAST line is carved here in the old script, worn shallow by six centuries of thumbs: every speaker touched it before their shift. The storm overhead bends around this hilltop; even now, even cracked, the vow has manners. The carved line waits. You could SPEAK it — one line, spoken true, joins you to the relay for whatever a night of it is worth. Or you could do what Cyrraeth did, and put your ear to the stone instead.",
			"variants": [{"flag": "vowstone_touched", "text": "The Vow-Stone stands in its bent weather, one thumb-worn line older than every banner at the summit. Whatever you gave it or took from it, the stone keeps the receipt.", "next": "v_relay"}],
			"choices": [
				{"text": "Speak the last line aloud, thumb on the carving — one night's shift in a six-hundred-year relay, honestly stood.",
					"resonance": 8.0, "flags": {"vowstone_touched": true, "chose_spoke_vow": true}, "next": "v_speak"},
				{"text": "Put your ear to the stone, as HE did. Half a sentence, six hundred years interrupted — you could just hear what it's been trying to say.",
					"resonance": -10.0, "flags": {"vowstone_touched": true, "chose_listened_storm": true}, "next": "v_listen"},
				{"text": "Rest your hand flat over the carving — cover it from the rain a moment — and climb on without a word.",
					"resonance": 0.0, "flags": {"vowstone_touched": true}, "next": "v_cover"},
				{"text": "Stand a keeper's shift-breath at the relay's first post — one moment of somebody THERE, for Vasse, whose knees won't make the hill.",
					"resonance": 2.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_vowstone",
					"flags": {"sq7_relay_vowstone": true}, "next": "v_mark"},
				{"text": "Slap the stone in passing and call the station stood. A rock is a rock — and Vasse's knees will never carry her up to check.",
					"resonance": -6.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_vowstone",
					"flags": {"sq7_relay_vowstone": true, "sq7_relay_slighted": true}, "next": "v_slap"},
			]},
		"v_speak": {"who": "Narrator", "text": "The old words come out of you rough and unpracticed — and the storm, horizon to horizon, MISSES A BEAT. One breath of the sky standing to attention for the first time in months. Your shift, the stone seems to acknowledge, has been logged; six hundred years of speakers make room on the roster without comment. The line will be finished tonight one way or another. Whatever else is true on that stair, YOU will have spoken it as a keeper, not only as a blade.", "next": ""},
		"v_listen": {"who": "Narrator", "text": "You listen. Under the stone: half a sentence, patient beyond geology — and it is not raging, that's the vertigo of it. It is REASONABLE. It has been mid-word for six hundred years, and it just wants to finish the thought, and every part of you that has ever been interrupted leans in with terrible sympathy. You pull away before the second clause lands. Mostly before. The shard hums the fragment for hours after, like a tune it means to learn — and now you understand Cyrraeth completely, which was the price of listening, and possibly the purpose.", "next": ""},
		"v_cover": {"who": "Narrator", "text": "You shelter the carving from the rain with your palm — pointless; it has weathered six hundred years of storms — and stand a moment in the bent weather doing the vow's work without the vow's words. The stone neither thanks you nor tests you. But when you take your hand away, the carved line is dry, and stays dry, all the time you can see it going down the hill. Small courtesies between keepers. Even unofficial ones.", "next": ""},
		# Post-shrine revisits land here so Vasse's station stays standable.
		"v_relay": {"who": "Narrator", "text": "The rain works at the thumb-worn carving, and loses, as it has lost for six hundred years. The hilltop keeps its bent, mannered weather. The line waits.",
			# The slap fooled Vasse (it was built to); the stone is older
			# than the vow and keeps the receipt.
			"variants": [{"flag": "sq7_relay_slighted", "text": "The rain works at the thumb-worn carving, and loses. Your palm-print dried off this stone in under a minute; it keeps the receipt anyway — six hundred years of shifts on the ledger, and one signature.", "next": ""}],
			"choices": [
				{"text": "Stand a keeper's shift-breath at the relay's first post — one moment of somebody THERE, for Vasse, whose knees won't make the hill.",
					"resonance": 2.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_vowstone",
					"flags": {"sq7_relay_vowstone": true}, "next": "v_mark"},
				{"text": "Slap the stone in passing and call the station stood. A rock is a rock — and Vasse's knees will never carry her up to check.",
					"resonance": -6.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_vowstone",
					"flags": {"sq7_relay_vowstone": true, "sq7_relay_slighted": true}, "next": "v_slap"},
			]},
		"v_slap": {"who": "Narrator", "text": "Palm to stone, one beat, done — attendance taken in the only ledger on this hill that can't read hearts. The storm does not miss a beat for you; storms know the difference, it turns out, between a shift and a signature. Down at the camp an old keeper will hear the station was stood and mouth her hour a little easier tonight, and what she paid thirty years of knees for, you paid a slap. The rounds still happen. The word 'still' is doing new work in that sentence now.", "next": ""},
		"v_mark": {"who": "Narrator", "text": "You stand it the way she taught it without teaching it: feet planted, one breath, THERE. The storm overhead keeps its manners; the carved line sits a shade darker under the wet, as if inked anew. First post, stood. Somewhere downhill, an old keeper's nightly hour has company again.", "next": ""},
	}},

	# OVERRIDES ch7_zones.gd's ch7_lore_cairn — the cairn's lore text is
	# unchanged; a gated station choice (relay rounds) and a gated
	# deposit choice (Korrag's due) are appended. Both cairn hooks live
	# HERE — one override carrying both quest-gated choices.
	"ch7_lore_cairn": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A cairn of plains stone, raised by the beast-clans for KORRAG, STORMWARDEN — the man you know as a Chapter 2 boss and the plains knew, longer, as the best keeper his order ever fielded. The offerings on it are all beast-things: a wolf tooth, a hawk feather, a cracked storm-whistle. The order's records, you've since learned, say his warding-storm 'broke' the season the seal began to strain — he wasn't failed by his vows, he was the first casualty of a sentence fraying six hundred miles away. Someone has scratched a late line into the base stone, unsigned, in vow-script: 'THE STORM BROKE FIRST. HE JUST CAUGHT IT.'",
			"variants": [{"flag": "sq7_token_left", "text": "The cairn keeps its beast-things — wolf tooth, hawk feather, cracked storm-whistle — and, among them now, one shift-token of thumb-polished storm-iron, exactly where the order's contribution always belonged. Six hundred years late counts, out here, as arriving."}],
			"choices": [
				{"text": "Stand a keeper's shift-breath at the cairn — the one station the order never built, held down by the best keeper it ever fielded.",
					"resonance": 2.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_cairn",
					"flags": {"sq7_relay_cairn": true}, "next": "c_mark"},
				{"text": "Set the shift-token down among the offerings — storm-iron with the wolf teeth. The order pays its due.",
					"resonance": 2.0, "req_flag": "sq7_token_taken", "req_not_flag": "sq7_token_left",
					"flags": {"sq7_token_left": true}, "lose_item": "ch7_korrag_token", "next": "c_due"},
				{"text": "Leave the cairn its quiet.", "next": ""},
			]},
		"c_mark": {"who": "Narrator", "text": "You plant your feet by the plains stone and give it the breath. The wind off the downs drops, half a beat — the way it must have dropped for HIM, out of respect or fellowship or both. The clans' offerings rattle softly, approving of the strange new custom. Station stood. Korrag, keeper: your relief has reported.", "next": ""},
		"c_due": {"who": "Narrator", "text": "The token goes down among the teeth and feathers — the smallest thing on the cairn, and the heaviest. Six hundred years of the order looking east while the clans did the remembering, settled with one piece of thumb-worn storm-iron. The scratched line at the base keeps its verdict: THE STORM BROKE FIRST. HE JUST CAUGHT IT. But under your hand, for a moment, the stones feel less like a debt and more like a grave.", "next": ""},
	}},

	# OVERRIDES ch7_zones.gd's ch7_lore_shelf — the shelf's lore text is
	# unchanged; the sealed letter becomes takeable (quest accept, like
	# the ch1 hat pilot) and a gated relay-station choice is appended.
	# Both shelf hooks live HERE — one override carrying both choices.
	"ch7_lore_shelf": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A shelf of not-quite-stone at the tear's edge, and arranged along it — arranged, unmistakably — the things the void has caught as they fell out of the world: a child's shoe with a buckle no smith alive could name. A coin from a kingdom absent from every atlas. A letter, sealed, addressed in a hand that makes your shard flinch, to SOMEONE WHO WILL REMEMBER. The void keeps everything, the old warnings say. Standing here, you finally hear the warning's second half, the part the Concord never carved: it keeps everything CAREFULLY.",
			"variants": [{"flag": "sq7_letter_taken", "text": "The shelf keeps its careful arrangement — shoe, coin, the letter's slot holding its shape in the dust. The void does not seem to mind the borrowing. It seems, if anything, to have been waiting for a courier."}],
			"choices": [
				{"text": "Take the letter, seal unbroken. Somebody at the summit has outlived enough of Vaelscar to qualify as its address.",
					"resonance": 1.0, "req_not_flag": "sq7_letter_taken",
					"flags": {"sq7_letter_taken": true}, "gain_item": "ch7_void_letter",
					"side_quest": "ch7_void_letter", "next": "l_take"},
				{"text": "Stand a keeper's shift-breath at the void's edge — the third post, or what the tear kept of it, for Vasse.",
					"resonance": 2.0, "req_flag": "sq_on_ch7_relay_stands", "req_not_flag": "sq7_relay_shelf",
					"flags": {"sq7_relay_shelf": true}, "next": "l_stand"},
				{"text": "Leave the shelf to its keeping.", "next": ""},
			]},
		"l_take": {"who": "Narrator", "text": "The letter comes off the shelf light as ash and rides your pack like it weighs a verdict. The hand on the front makes the shard flinch every time you check it — and you check it more than you need to. TO SOMEONE WHO WILL REMEMBER. Not you, then. But you know the address.", "next": ""},
		"l_stand": {"who": "Narrator", "text": "You stand the breath at the world's worst posting: the third station, half in the tear, its old flagstones arranged on the shelf like museum pieces of themselves. THERE, at the edge of everything the void kept. Nothing reaches for you. Something, possibly, takes attendance. The line, for one held moment, runs unbroken from a hilltop stone to the lip of the dark — and it holds.", "next": ""},
	}},

	# OVERRIDES ch7_zones.gd's ch7_briefing — the briefing path (m1..m3,
	# choice order) is UNTOUCHED (the suite walks choice 0). Two letter
	# variants are added ahead of the ch7_briefed revisit so the sealed
	# letter can be delivered after the briefing.
	"ch7_briefing": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer. Sit — the fire's real, the summit is theater, and you and I are past theater. I've read every report out of the Vale, the Slagfields, the ice, the Deep. You've been busy being exactly what I hoped you'd be, and I've been busy being afraid of what it's adding up to.",
			"variants": [
				{"flag": "sq7_letter_given", "text": "The letter rides inside her coat, against the sternum — you catch the shape of it when she leans to the fire. 'Answered, bearer. Some of it in ink, after the stair. The steppe still wants you more than my correspondence does.'", "next": ""},
				{"flag": "sq7_letter_taken", "text": "Bearer. The steppe — no. No, you've the look of a courier about you tonight, and I have known that look longer than you've been alive. Out with it, then.", "next": "m_letter"},
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
		# The letter's delivery — reached only via the sq7_letter_taken variant.
		"m_letter": {"who": "Narrator", "text": "She holds out one hand, palm up — the summit's whole authority in five patient fingers.",
			"choices": [
				{"text": "Give her the letter, seal unbroken. \"From the void shelf. Addressed to someone who will remember. I did the arithmetic, Maren.\"",
					"resonance": 3.0, "flags": {"sq7_letter_given": true}, "lose_item": "ch7_void_letter", "next": "m_letter2"},
				{"text": "\"...Not yet. It's still deciding whether it's for you.\" Keep the pack shut.", "next": ""},
			]},
		"m_letter2": {"who": "Narrator", "text": "She takes it like something that might go off — then turns it over, reads the address, and stops. All of her. For three full seconds the summit's one fixed point is an old woman not breathing. 'I know this hand,' she says at last, and does not say from where, and you understand that you have just watched sixty years arrive in one envelope. She sets it inside her coat, against the sternum. 'It will be read, bearer. After the stair. Some things you do not open with a storm watching — and your arithmetic was right. I remember EVERYTHING.'", "next": ""},
	}},

	# OVERRIDES ch7_zones.gd's ch7_apprentice — Sorrel's one-shot first
	# scene (four lines / the Echo / stay off the stair) is untouched;
	# the ch7_sorrel_heard revisit now leads to the token hook, and
	# quest-state variants handle reminder / completion.
	"ch7_apprentice": {"start": "p1", "nodes": {
		"p1": {"who": "Apprentice Sorrel",
			"text": "You're climbing to him, aren't you. To the Speaker. I'm — I WAS — his apprentice; four years of learning the recitation, one line a season, that's the tradition. I know four lines, bearer. Four lines of a six-hundred-year sentence, and when he dies I'm the closest thing left to a keeper of it. Everyone at this summit keeps carefully not saying that to me.",
			"variants": [
				{"flag": "sq_paid_ch7_korrags_due", "text": "You left it with him? At the cairn, with the teeth and the feathers? ...Good. GOOD. Master never spoke of Korrag without standing straighter — I thought that was reverence. I think now it was debt. Four lines and a paid-up cairn, bearer. The order's estate is small, but it is finally HONEST.", "next": ""},
				{"flag": "sq7_token_taken", "text": "The token rides with you? Then walk it up the downs soon, bearer — storm-iron gets heavier the longer it's owed. Ask any keeper. Ask ME; I weighed it forty times before you took it.", "next": ""},
				{"flag": "ch7_sorrel_heard", "text": "Four lines. I've written them down forty times and hidden the copies — paper in a boot, wax under a hearthstone. It's not the relay. But it's not NOTHING. Climb well, bearer.", "next": "p_more"},
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
		# The token hook — reachable on any revisit after his first scene.
		"p_more": {"who": "Narrator", "text": "He falls quiet a moment, thumbing something in his coat pocket — small, metal, worried smooth.",
			"choices": [
				{"text": "\"The cairn on the downs, Sorrel. Wolf teeth, hawk feathers — six hundred offerings, and not one from his own order. Give me something of the relay's to leave him.\"",
					"resonance": 2.0, "req_not_flag": "sq7_token_taken",
					"flags": {"sq7_token_taken": true}, "gain_item": "ch7_korrag_token",
					"side_quest": "ch7_korrags_due", "next": "p_token"},
				{"text": "\"Guard the four lines, Sorrel. That's the whole job now.\"", "next": ""},
			]},
		"p_token": {"who": "Apprentice Sorrel", "text": "He has it out of his pocket before you finish — the shift-token, storm-iron, polished by six centuries of thumbs at every relay change. \"Master carried it. His master carried it. It should have gone up that hill the season the clans raised the stones, and the order was too busy being ASHAMED of losing him to say thank you. Take it. Tell him—\" He stops. Squares up, sixteen years old and the last of six hundred. \"Don't tell him anything. Put it with the teeth. He'll know what we meant.\"", "next": ""},
	}},
}
