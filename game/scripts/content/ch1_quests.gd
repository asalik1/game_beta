## (Q1) Chapter 1 side quests — three flag-chain quests on the Darkwood's
## existing wanderers and lore props (QUESTS_TASKS.md):
##   oslas_debt      — Osla's coin pouch, left in the Hollow Oak's hollow.
##   hunters_rounds  — the Old Hunter's sign cut at three landmarks.
##   flame_at_window — the pilgrim's pine stick, lit at the Drowned Chapel.
## Wanderer givers roll in ~half of runs (run-conditional, like the hat
## pilot); the props are fixed. All flags/keepsakes are run-scoped.

const SIDE_QUESTS := {
	"oslas_debt": {
		"name": "Osla's Debt",
		"chapter": "ch1",
		"desc": "Tinker Osla owes a dead smith for an axle, and means to settle. Debts left with the old wood find their owners — her words. The Hollow Oak keeps the wood's accounts.",
		"steps": [
			{"flag": "osla_pouch_taken", "text": "Carry Osla's coin pouch"},
			{"flag": "osla_debt_paid", "text": "Leave it in the Hollow Oak's offering hollow"},
		],
		"reward": {"gold": 120},
	},
	"hunters_rounds": {
		"name": "The Hunter's Rounds",
		"chapter": "ch1",
		"desc": "The Old Hunter's legs no longer make the full rounds, and a wood where nobody walks the landmarks starts believing nobody is watching it. Cut his sign at Ravine Edge, the Drowned Chapel, and the Collapsed Tower.",
		"steps": [
			{"flag": "hunter_mark_ravine", "text": "Mark the hunter's sign at Ravine Edge"},
			{"flag": "hunter_mark_chapel", "text": "Mark the hunter's sign at the Drowned Chapel"},
			{"flag": "hunter_mark_tower", "text": "Mark the hunter's sign at the Collapsed Tower"},
		],
		"reward": {"gold": 180},
	},
	"flame_at_window": {
		"name": "Flame at the Window",
		"chapter": "ch1",
		"desc": "The pilgrim lights a stick of pine at every hearth the blight has touched. It does nothing, the scholars say. Carry one to the Drowned Chapel's altar and see what nothing looks like from inside.",
		"steps": [
			{"flag": "pine_taken", "text": "Carry the pilgrim's stick of pine"},
			{"flag": "pine_lit", "text": "Light it at the Drowned Chapel's altar"},
		],
		"reward": {"gold": 100},
	},
}

const QUEST_ITEMS := {
	"osla_pouch": {"name": "Osla's Coin Pouch",
		"desc": "What a tinker owes a dead smith, counted twice and tied with waxed cord. Bound for the Hollow Oak's offering hollow — the old wood keeps the accounts now.",
		"grade": "C"},
	"pine_stick": {"name": "Stick of Pine",
		"desc": "Cut for burning at hearths the blight has touched. It does nothing, the scholars say. The pilgrim gave you the good one.",
		"grade": "C"},
}

const CONVOS := {
	# OVERRIDES story.gd's wander_tinker (Q1 — Osla's Debt). Helping with
	# the axle now flows into the pouch ask, and the repeat-visit variant
	# leads there too until the pouch is taken.
	"wander_tinker": {"start": "t1", "nodes": {
		"t1": {"who": "Tinker Osla",
			"text": "Axle's cracked. Third one this season — the roads got worse when the wolves got bold. You wouldn't hold the cart steady a moment?",
			"variants": [
				{"flag": "osla_debt_paid", "text": "The cart rolls light these days — or I do. The debt's with the old wood now, and the old wood doesn't charge interest. Flame keep you, friend.", "next": ""},
				{"flag": "osla_pouch_taken", "text": "Pouch riding safe? The Hollow Oak, mind — the split grandfather oak with the offerings in its belly. Debts left with the old wood find their owners.", "next": ""},
				{"flag": "helped_tinker", "text": "The cart rolls straight now, thanks to you. If you pass a smith, tell them Osla still owes for the axle.", "next": "t_debt"},
			],
			"choices": [
				{"text": "Set your shoulder against the cart. \"Take your time.\"",
					"resonance": 3.0, "flags": {"helped_tinker": true}, "next": "t_help"},
				{"text": "\"Roads are dangerous. Pay someone to guard you next time.\"",
					"resonance": -2.0, "next": "t_no"},
			]},
		# t_help keeps its original linear end (the suite's social-room walk
		# picks choice 0 and handles ONE choice round) — the pouch ask waits
		# for the second talk, via the helped_tinker variant above.
		"t_help": {"who": "Tinker Osla", "text": "There — seated. You've an honest shoulder for someone armed to the teeth. Flame keep you down the road.", "next": ""},
		"t_no": {"who": "Tinker Osla", "text": "Aye, and eat what, while I pay them? ...Safe travels anyway, stranger.", "next": ""},
		"t_debt": {"who": "Tinker Osla",
			"text": "...Actually. You look bound for the deep wood anyway. This pouch is what I owe the smith who cut me the last axle — he went toward the howling in spring, and his forge went quiet. Folk say debts left with the old wood find their owners. Would you leave it in the Hollow Oak's offering hollow? The split grandfather oak. You'll know it when it's looking at you.",
			"choices": [
				{"text": "Take the pouch. \"The old wood and I are getting acquainted anyway.\"",
					"resonance": 1.0, "flags": {"osla_pouch_taken": true},
					"gain_item": "osla_pouch", "side_quest": "oslas_debt", "next": "t_trust"},
				{"text": "\"Keep your coin, Osla. Dead smiths don't collect.\"",
					"resonance": -2.0, "next": "t_keep"},
			]},
		"t_trust": {"who": "Tinker Osla", "text": "There. Lighter already — the cart AND me. Don't spend it, mind. The wood would know. The wood always knows.", "next": ""},
		"t_keep": {"who": "Tinker Osla", "text": "Maybe not. But I borrowed off a living man and I'll settle with whatever's left of him. ...The offer keeps, if you change your mind. Debts are patient like that.", "next": ""},
	}},

	# OVERRIDES story.gd's wander_hunter (Q1 — The Hunter's Rounds). The
	# repeat-visit variant now walks into the rounds ask; on-quest and
	# quest-done greetings short-circuit ahead of it (first match wins).
	"wander_hunter": {"start": "h1", "nodes": {
		"h1": {"who": "Old Hunter",
			"text": "Word of advice, since you're kitted for trouble: the packs out here move TOGETHER now. Wound one and its whole family answers. Pick your ground before you pick a fight.",
			"variants": [
				{"flag": "sq_paid_hunters_rounds", "text": "Saw your marks. Clean cuts, good height. The wood reads different when it knows someone's walking it — you'd have made a fair hunter, if the sword hadn't got to you first.", "next": ""},
				{"flag": "sq_on_hunters_rounds", "text": "Three places: the ravine's edge, the drowned chapel, the fallen tower. Cut the sign where the next pair of eyes will look for it. High and plain.", "next": ""},
				{"flag": "met_hunter", "text": "Still breathing? Good. Told you the ground matters more than the blade.", "next": "h_rounds"},
			],
			"next": "h2"},
		"h2": {"who": "Old Hunter", "text": "And if you find a still pool deep in the wood — the one that holds the moon wrong — don't drink before you've decided who you are. That's free too.",
			"choices": [
				{"text": "\"Thanks for the warning, hunter.\"", "flags": {"met_hunter": true}, "next": ""},
			]},
		"h_rounds": {"who": "Old Hunter",
			"text": "Since you keep not dying — a job, if you'll take it. My legs don't make the full rounds anymore, and a wood where nobody walks the landmarks starts believing nobody's watching it. Ravine Edge. The drowned chapel. The old collapsed tower. Cut my sign at each — crossed slash, high and plain — so the wood knows the rounds still happen.",
			"choices": [
				{"text": "\"Three landmarks, three marks. I'll walk your rounds, hunter.\"",
					"resonance": 1.0, "side_quest": "hunters_rounds", "next": "h_deal"},
				{"text": "\"I've enough work keeping myself walking.\"", "next": "h_no"},
			]},
		"h_deal": {"who": "Old Hunter", "text": "Ha! Then the wood's got a warden again, whether it likes the look of you or not. Cut them plain. I'll know.", "next": ""},
		"h_no": {"who": "Old Hunter", "text": "Fair. It's not your wood yet. Ask me again when it starts feeling like it is.", "next": ""},
	}},

	# OVERRIDES story.gd's wander_pilgrim (Q1 — Flame at the Window). Both
	# appended choices are gated off once the stick is taken, so repeat
	# visits fall back to the original linear greeting.
	"wander_pilgrim": {"start": "p1", "nodes": {
		"p1": {"who": "Pilgrim of the Flame",
			"text": "I walk to every hearth the blight has touched and light a stick of pine. It does nothing, the scholars say. The scholars have never sat in a dark house.",
			"variants": [
				{"band": "tempted", "text": "...The flame leans when you stand near it, friend. I won't ask. But I'll burn a stick of pine for you especially."},
				{"band": "steady", "text": "The flame sits easy near you. That's rarer than you know, out here. Walk with it."},
			],
			"choices": [
				{"text": "\"Cut me a stick, pilgrim. There's a drowned chapel east of here still keeping its candle — I'll set a flame at its window.\"",
					"req_not_flag": "pine_taken", "resonance": 1.0,
					"flags": {"pine_taken": true}, "gain_item": "pine_stick",
					"side_quest": "flame_at_window", "next": "p_give"},
				{"text": "\"Walk safe, pilgrim.\"", "req_not_flag": "pine_taken", "next": ""},
			],
			"next": ""},
		"p_give": {"who": "Pilgrim of the Flame", "text": "You know the chapel? And the candle still — sixty years, and it still. Then take the good one. Pine catches quick and burns honest, and the scholars can explain to a dark house what NOTHING looks like from inside.", "next": ""},
	}},

	# OVERRIDES story.gd's lore_hollow_oak (Q1 — Osla's Debt, the deposit).
	# Without the quest no choice is visible and the prop reads exactly as
	# before (linear, ends).
	"lore_hollow_oak": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A grandfather oak, split open and hollow. Inside, wax stubs and a child's carved wolf — someone hid offerings here for the wood's old spirits, long before the blight gave the wood new ones. The candle wax is recent.",
			"choices": [
				{"text": "Leave Osla's pouch among the offerings. Debts left with the old wood find their owners.",
					"req_flag": "sq_on_oslas_debt", "req_not_flag": "osla_debt_paid",
					"resonance": 1.0, "flags": {"osla_debt_paid": true},
					"lose_item": "osla_pouch", "next": "l_debt"},
			],
			"next": ""},
		"l_debt": {"who": "Narrator", "text": "The pouch settles among the wax stubs and the carved wolf like it was expected. No wind moves, but somewhere above you the old branches shift their grip — the sound a ledger makes, closing. If the smith walks anywhere still, the wood knows the road better than you do.", "next": ""},
	}},

	# OVERRIDES story.gd's lore_ravine (Q1 — The Hunter's Rounds, mark 1 of
	# 3, any order). Choice invisible off-quest; prop otherwise unchanged.
	"lore_ravine": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The ravine has nothing for you. No monsters, no treasure, no secret door. The view, though — the whole Darkwood rolling east under the mist, and the keep's towers far off, patient as tombstones. You allow yourself one long minute of it.",
			"choices": [
				{"text": "Cut the hunter's sign into the overlook stone — crossed slash, high and plain.",
					"req_flag": "sq_on_hunters_rounds", "req_not_flag": "hunter_mark_ravine",
					"flags": {"hunter_mark_ravine": true}, "next": "l_mark"},
			],
			"next": ""},
		"l_mark": {"who": "Narrator", "text": "The stone gives grudgingly, the way everything in this wood gives — but the crossed slash comes out clean, plain to anyone who climbs this far. The rounds still happen. Now the ravine knows it too.", "next": ""},
	}},

	# OVERRIDES story.gd's lore_drowned_chapel — carries BOTH Q1 chapel
	# hooks (hunter's mark + pilgrim's pine stick), per the board. Changes:
	# the three faced-candle variants now continue to c_sign (a short coda
	# holding the gated quest choices — otherwise a player who already
	# settled the candle could never reach them), and the same two choices
	# are APPENDED at the end of c_watch for first-visit questers. Original
	# candle flow is untouched.
	"lore_drowned_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A flooded chapel of the Flame, sunk to its windows. The altar stone stands just above the waterline, and someone has kept ONE candle burning on it — the wax runs down in years, not hours. Morwen's blight circles this place and does not enter. Interesting, that it can't. Or won't.",
			"variants": [
				{"flag": "chapel_cupped", "text": "The candle burns on the altar stone, steady over the black water. The flame leans toward you when you enter now — barely. But it does.", "next": "c_sign"},
				{"flag": "chapel_snuffed", "text": "The candle burns — relit, grudging, a shade smaller than it was. The blight circles a half-step closer than you remember. Neither of you mentions it.", "next": "c_sign"},
				{"flag": "chapel_faced", "text": "The candle burns on, sixty years and one more night. The watch was never yours. It minds the door all the same.", "next": "c_sign"},
			],
			"next": "c_watch"},
		"c_watch": {"who": "Narrator", "text": "The wind comes off the water and the flame bends, recovers, bends. Whoever keeps this candle is not here. Right now, the watch is anyone's.",
			"choices": [
				{"text": "Cup your hand around the flame until the gust passes. Stand a stranger's watch.",
					"resonance": 3.0, "flags": {"chapel_faced": true, "chapel_cupped": true}, "next": "c_cup"},
				{"text": "Pinch it out. Sixty years is long enough for anything to burn.",
					"resonance": -5.0, "flags": {"chapel_faced": true, "chapel_snuffed": true}, "next": "c_snuff"},
				{"text": "Leave it to its work. It has managed this long without your opinion.",
					"resonance": 0.0, "flags": {"chapel_faced": true}, "next": "c_leave"},
				{"text": "Cut the hunter's sign above the waterline, where the next walker will look.",
					"req_flag": "sq_on_hunters_rounds", "req_not_flag": "hunter_mark_chapel",
					"flags": {"hunter_mark_chapel": true}, "next": "c_mark"},
				{"text": "Set the pilgrim's stick of pine to the candle and stand it at the window.",
					"req_flag": "sq_on_flame_at_window", "req_not_flag": "pine_lit",
					"resonance": 2.0, "flags": {"pine_lit": true},
					"lose_item": "pine_stick", "next": "c_pine"},
			]},
		"c_cup": {"who": "Narrator", "text": "The gust breaks on your knuckles and the flame steadies, and for one held breath the chapel is exactly what it was built to be: a lit room in the dark, with someone minding the door. Out on the water, the blight's slow circling falters — a half-step, no more. It is enough to have been seen doing it.", "next": ""},
		"c_snuff": {"who": "Narrator", "text": "Dark comes down like a lid — and the marsh LEANS: reeds, water, the far unseen singing, all of it, toward the altar, the way a crowd leans at a scaffold. You relight it. You TRY. The wick takes on the third strike, grudging, smaller. Some watches you do not get to end on someone else's behalf. The Ember, you notice, enjoyed the dark just fine.", "next": ""},
		"c_leave": {"who": "Narrator", "text": "It has burned sixty years of nights exactly like this one. You leave it to the work, and the flame stands a little taller in the still air behind you — or you tell yourself it does. Either way, the door was minded tonight.", "next": ""},
		"c_sign": {"who": "Narrator", "text": "The wind works the water, and the flame keeps up its old argument with it — sixty years practiced, not losing yet.",
			"choices": [
				{"text": "Cut the hunter's sign above the waterline, where the next walker will look.",
					"req_flag": "sq_on_hunters_rounds", "req_not_flag": "hunter_mark_chapel",
					"flags": {"hunter_mark_chapel": true}, "next": "c_mark"},
				{"text": "Set the pilgrim's stick of pine to the candle and stand it at the window.",
					"req_flag": "sq_on_flame_at_window", "req_not_flag": "pine_lit",
					"resonance": 2.0, "flags": {"pine_lit": true},
					"lose_item": "pine_stick", "next": "c_pine"},
			],
			"next": ""},
		"c_mark": {"who": "Narrator", "text": "The crossed slash goes into the stone a hand above the waterline, plain as a signature. The candle throws it a long shadow, and the chapel files it with everything else it has watched arrive and stay. The rounds still happen. Now the marsh knows it too.", "next": ""},
		"c_pine": {"who": "Narrator", "text": "The pine takes the candle's flame like it was owed it, and you stand the burning stick upright at the drowned window — one light where the wax has run for sixty years, and now, for a night, TWO. Out on the black water the blight's circling goes wide, unhurried, unmistakable. It does nothing, the scholars say. The scholars have never watched nothing back away.", "next": ""},
	}},

	# OVERRIDES story.gd's lore_collapsed_tower (Q1 — The Hunter's Rounds).
	# The horn variants now continue to t_sign (coda holding the gated mark
	# choice — a player who already settled the horn could otherwise never
	# mark here), and the mark choice is APPENDED at the end of t_horn.
	# Original horn flow is untouched.
	"lore_collapsed_tower": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The watchtower fell the night Vargoth rose — the masonry still shows the burn-shadow of the guard who stood here when it came down. Under the rubble: a rusted signal-horn, mouthpiece worn bright from use. He was CALLING someone, at the end. The record does not say if anyone came.",
			"variants": [
				{"flag": "horn_blown", "text": "The signal-horn rests on the rubble where you set it. The horizon has kept its answer to itself since — but you know what you heard, and the storm knows you heard it.", "next": "t_sign"},
				{"flag": "horn_rested", "text": "The horn stands on the rubble, mouthpiece up, aimed at the horizon. Still ready. Still his.", "next": "t_sign"},
			],
			"next": "t_horn"},
		"t_horn": {"who": "Narrator", "text": "The horn has waited under the rubble for sixty years, mouthpiece worn bright, call unfinished.",
			"choices": [
				{"text": "Raise it and sound the call — finish what the guard started.",
					"resonance": 3.0, "flags": {"horn_blown": true}, "next": "t_blow"},
				{"text": "Set it upright on the rubble, mouthpiece up, the way a signalman stands his post. Leave the silence his.",
					"resonance": 0.0, "flags": {"horn_rested": true}, "next": "t_rest"},
				{"text": "Cut the hunter's sign into the fallen masonry, clear of the burn-shadow.",
					"req_flag": "sq_on_hunters_rounds", "req_not_flag": "hunter_mark_tower",
					"flags": {"hunter_mark_tower": true}, "next": "t_mark"},
			]},
		"t_blow": {"who": "Narrator", "text": "The note comes out cracked, then enormous — it rolls east over the marsh and the wastes and takes sixty years of waiting with it. Silence. Then, from far past the keep, where the storm never quite leaves the horizon: one long note back. The same call. An answer six decades late — or an acknowledgment. Somewhere, a watch that never ended has changed hands.", "next": ""},
		"t_rest": {"who": "Narrator", "text": "You set it ready, pointed at the horizon. Some calls are not yours to finish. The burn-shadow on the masonry keeps its silence, and you leave the tower feeling watched — not unkindly.", "next": ""},
		"t_sign": {"who": "Narrator", "text": "The wind takes its slow inventory of the broken stones and leaves the count unchanged. The burn-shadow keeps its post.",
			"choices": [
				{"text": "Cut the hunter's sign into the fallen masonry, clear of the burn-shadow.",
					"req_flag": "sq_on_hunters_rounds", "req_not_flag": "hunter_mark_tower",
					"flags": {"hunter_mark_tower": true}, "next": "t_mark"},
			],
			"next": ""},
		"t_mark": {"who": "Narrator", "text": "You cut the crossed slash into a fallen block, a respectful arm's length from the burn-shadow — one watchman's mark beside another's. He held this post until the sky came down on it. The least the living can do is sign the visitors' book. The rounds still happen. Now the tower knows it too.", "next": ""},
	}},
}
