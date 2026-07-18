class_name Story
## All story text, zone layouts and enemy stats live here.
## Want to change the game's content or balance? This is the file.

# ------------------------------------------------- resonance & convos ---
# Resonance (-100..+100) tracks how the character relates to their Ember:
# Temptation vs. Virtue. Dialogue is authored against three BANDS, never
# raw values (see DESIGN.md) — the world reacts before any UI shows a number.
const RES_BAND_AT := 25.0

static func res_band(res: float) -> String:
	if res <= -RES_BAND_AT:
		return "tempted"
	if res >= RES_BAND_AT:
		return "steady"
	return "neutral"


# Branching conversations, run by Game.run_convo(). Format:
#   "convo_id": {"start": "node_id", "nodes": {
#     "node_id": {
#       "who": "Maren",
#       "text": "default line",
#       "variants": [                      # optional; FIRST match wins
#         {"band": "tempted", "text": "..."},   # by resonance band
#         {"flag": "told_truth", "text": "..."} # by story flag
#         # a variant may carry its own "next": the node then plays
#         # LINEAR (choices skipped) — the "we already talked" greeting
#       ],
#       "next": "other_node",              # linear node ("" / absent = end)
#       "quest": "quest_key",              # optional: sets the quest line
#       "choices": [                       # OR a decision (2-4 options)
#         {"text": "shown option",
#          "resonance": -8.0,              # optional resonance shift
#          "faction": {"accord": 2},       # optional standing shifts
#          "flags": {"told_truth": true},  # optional (set_flag: gate_flags react)
#          "quest": "quest_key",           # optional: sets the quest line
#          "req_flag": "x",                # optional gate: flag must be set
#          "req_not_flag": "x",            # optional gate: flag must be UNSET
#          "req_band": "steady",           # optional gate: resonance band
#          "next": "reply_node"},
#       ]}}}
# Flags persist in the save file (game.flags).
const CONVOS := {
	# ---- Warrior opening (Priority 3 pilot): the blackout on the road.
	# The fight already happened — the SCENE is the aftermath, and the
	# first real choice moves Resonance before Maren ever appears.
	"open_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "road", "text": "On the road to Emberfall Village: a scream. A blight-mad wolf, lunging at a miller. You remember drawing your sword. You do not remember the rest.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "aftermath", "text": "You wake on your feet. The wolf is dead — so is the fence, the cart, and half the well. Your knuckles are split. Bren the miller cradles a bleeding arm, staring at your hands.", "next": "n4"},
		"n4": {"who": "Bren", "text": "You didn't stop, ser. After it died... you kept swinging. What ARE you?",
			"choices": [
				{"text": "Kneel. \"I'm sorry, Bren. Show me the arm — I did this, and it's mine to mend.\"",
					"resonance": 12.0, "flags": {"owned_the_harm": true, "chose_virtue": true}, "next": "b_owned"},
				{"text": "\"You're alive. The wolf isn't. That is what matters.\"",
					"resonance": -12.0, "flags": {"excused_the_harm": true, "chose_temptation": true}, "next": "b_excused"},
				{"text": "Say nothing. Sheathe the sword and walk on.",
					"resonance": -4.0, "flags": {"walked_away": true, "chose_away": true}, "next": "b_walked"},
			]},
		"b_owned": {"who": "Bren", "text": "...It's not deep, ser. Just — whatever that was? Point it at the dead king. Not at us.", "next": "n_end"},
		"b_excused": {"who": "Bren", "text": "Aye. Alive. ...The old king used to talk like that too, my gran said. Near those exact words.", "next": "n_end"},
		"b_walked": {"who": "Narrator", "text": "You leave him with the wreckage. Behind you, quiet as a prayer: \"Flame keep whoever meets you next.\"", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "Emberfall Village lies ahead. Word of the road travels faster than you walk — the elder is already waiting."},
	}},
	# ---- Maren's recruitment: her greeting reads what you did on the road.
	"maren_warrior": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "owned_the_harm", "text": "Bearer. Bren showed me the arm — and told me you KNELT. Those who carry what you carry rarely kneel. Keep that, whatever else you lose."},
				{"flag": "excused_the_harm", "text": "Bearer. 'The wolf isn't — that's what matters.' Bren repeated it, still shaking. I have heard those words before... from the man you have come to kill. Mind yourself."},
				{"flag": "walked_away", "text": "Bearer. You walked past Bren's wreckage without a word. It follows you anyway. Better to face a thing than be trailed by it."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: a still knight is a dead knight."},
	}},

	# ---- Assassin opening: the theft that kept you alive.
	"open_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "camp", "text": "Winter on the Pilgrim's Road. You are three days poisoned — blight in a scratch — and dying quietly. A carter sleeps warm beside his fire, a flask of physick at his belt.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "camp_cold", "text": "You remember deciding NOT to take it. Then the Ember decided otherwise. You wake with the flask empty in your hand — the fire is dead, and the carter's lips are grey. It did not only take the medicine.", "next": "n4"},
		"n4": {"who": "Carter", "text": "S-so cold... traveler. What... what did you do to my fire?",
			"choices": [
				{"text": "Kneel. Wrap him in your cloak. \"Take my warmth back. I'll stay until dawn.\"",
					"resonance": 12.0, "flags": {"gave_back": true, "chose_virtue": true}, "next": "b_gave"},
				{"text": "\"Your fire fed something greater than either of us. You'll live.\"",
					"resonance": -12.0, "flags": {"kept_taking": true, "chose_temptation": true}, "next": "b_kept"},
				{"text": "Drop the flask and back away from him — before it takes more.",
					"resonance": -4.0, "flags": {"fled_theft": true, "chose_away": true}, "next": "b_fled"},
			]},
		"b_gave": {"who": "Carter", "text": "...Your hands are like coals, stranger. Whatever is in you — it gives as fierce as it takes.", "next": "n_end"},
		"b_kept": {"who": "Narrator", "text": "He watches you leave with the flask still in your hand. His warmth sits in your blood, and it feels EARNED. That is the frightening part.", "next": "n_end"},
		"b_fled": {"who": "Narrator", "text": "The flask lands in the snow between you. Behind you: flint striking, again and again, against wood that will not catch.", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "By dawn you can walk. By dusk you reach Emberfall Village — and the elder is already watching you count what you owe."},
	}},
	"maren_assassin": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "gave_back", "text": "Bearer. The carter came through at first light — telling anyone who'd listen about the stranger who took his fire, then sat in the snow all night giving it back. Your bloodline usually only takes. Interesting."},
				{"flag": "kept_taking", "text": "Bearer. A carter stumbled in this morning, grey to the elbows, saying the road stole his fire. You look... well-rested. We won't speak of it again. But I will remember it."},
				{"flag": "fled_theft", "text": "Bearer. You came the long way, and cold. Running from what your hands did doesn't starve it — it only teaches it patience."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: a still blade is a caught blade."},
	}},

	# ---- Mage opening: the heal that went wrong.
	"open_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "sickbed", "text": "Mill row, past midnight. The ferrier's boy is burning with marsh-fever, and his mother knows what you are. \"Please,\" she says. You lay your hands on him. You have done this before.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "sickbed_wrong", "text": "The light comes GREEN. The fever breaks — and where it broke, a mark spreads: a bloom of grey, cold to the touch. It is not fever. It is not anything you have a name for. It does not wash off.", "next": "n4"},
		"n4": {"who": "The Mother", "text": "He's cool... thank the flame, he's cool. But — what is THAT? What did you DO?",
			"choices": [
				{"text": "\"My spell did this. I don't know how. But I will find how, and I will undo it — that is a promise.\"",
					"resonance": 12.0, "flags": {"told_truth": true, "chose_virtue": true}, "next": "b_truth"},
				{"text": "\"The sickness ran deeper than it looked. I did everything that could be done.\"",
					"resonance": -12.0, "flags": {"hid_truth": true, "chose_temptation": true}, "next": "b_hid"},
				{"text": "Leave your coin purse on the table for a real healer, and go before she asks again.",
					"resonance": -4.0, "flags": {"left_silent": true, "chose_away": true}, "next": "b_left"},
			]},
		"b_truth": {"who": "The Mother", "text": "...You could have lied. I would have believed you. Find how, wizard. I'll hold the promise.", "next": "n_end"},
		"b_hid": {"who": "Narrator", "text": "She thanks you. She THANKS you. The lie fits so well it frightens you — Mórwyn's spells were perfect too, at first.", "next": "n_end"},
		"b_left": {"who": "Narrator", "text": "The door closes on her question. The coin will not answer it either.", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "By morning the whole row knows a spellwright is in the village. The elder sends for you first."},
	}},
	"maren_mage": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "told_truth", "text": "Bearer. The ferrier's wife says you promised to UNDO what your magic did — to her face, with the mark still spreading. Mórwyn never once said 'I don't know how.' Hold on to those words."},
				{"flag": "hid_truth", "text": "Bearer. The boy is cool, and his mother sings your praises... and yet the mark on his ribs tells a different spell than the one you described. Careful. That is precisely how it started with HER."},
				{"flag": "left_silent", "text": "Bearer. Coin on the table and a closed door. Half the row thinks you modest; the other half found the mark. Questions do not rot away, spellwright — they ferment."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: a still spellwright is a spent one."},
	}},

	# ---- Archer opening: the severed bond.
	"open_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "homestead", "text": "The night before the road: your brother Ren waits at the boundary fence of the farm that raised you both. Twenty years of unspoken thread run between you and this place. Tonight, for the first time, you can SEE it — thin, bright, humming.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "severed", "text": "The Ember wakes. And chooses. The thread snaps like a bowstring — and Ren flinches as if he felt it too. When he looks at you again, it is the way you look at a stranger on the road: measuring the distance.", "next": "n4"},
		"n4": {"who": "Ren", "text": "You're just going, then. Whatever that was — you're just... going?",
			"choices": [
				{"text": "Turn back one last time. \"The thread broke, not the memory. Keep the farm. I'll keep the aim it taught me.\"",
					"resonance": 12.0, "flags": {"said_farewell": true, "chose_virtue": true}, "next": "b_fare"},
				{"text": "\"Ties are weight, Ren. The Ember only cut what I never dared to.\" Walk.",
					"resonance": -12.0, "flags": {"cut_clean": true, "chose_temptation": true}, "next": "b_cut"},
				{"text": "Raise a hand without turning around. Some goodbyes only bleed if you look at them.",
					"resonance": -4.0, "flags": {"walked_silent": true, "chose_away": true}, "next": "b_silent"},
			]},
		"b_fare": {"who": "Ren", "text": "...Then shoot straight, little hawk. The gate stays unlatched. That's MY choice — whatever your ember says.", "next": "n_end"},
		"b_cut": {"who": "Narrator", "text": "The road is lighter with every step. That lightness should worry you more than it does.", "next": "n_end"},
		"b_silent": {"who": "Narrator", "text": "You hear the gate latch click behind you. A small sound. It follows you further than the howling will.", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "Three days east: Emberfall Village. Word of a hawk-eyed drifter travels ahead of you."},
	}},
	"maren_archer": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "said_farewell", "text": "Bearer. A farmer named Ren sent a letter ahead of you. Four words: 'The gate stays unlatched.' Severed bloodlines rarely leave anything standing behind them — you left a DOOR. Keep leaving them."},
				{"flag": "cut_clean", "text": "Bearer. You came in light, drifter — no letters, no ties, nothing to carry. Fangmaw's kin walked that same weightless road all the way to its end. Have a care how light you get."},
				{"flag": "walked_silent", "text": "Bearer. You didn't look back, they say. It follows anyway. The ones who walk from a thing always pack it by accident."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: a still hawk is just a target."},
	}},

	# ---- Paladin opening: the verdict (fight first, then the harder part).
	"open_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "hearing", "text": "You are three hours into a grain-hoarding hearing — miller Osric, guilty as the ledgers are long — when blight-raiders hit the granary. A guard falls at your feet. His hammer is in your hand before you decide anything. The Ember inside it IGNITES.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "verdict", "text": "The raiders flee from what you became in that doorway. Osric is alive because you stood over him. And now you are back at the bench, and the chain around your heart pulls one way: HE IS YOURS. YOU SHIELDED HIM. SHIELD HIM. The ledgers have not changed.", "next": "n4"},
		"n4": {"who": "Osric", "text": "You saved my life, arbiter. Surely... surely that counts for the sentence?",
			"choices": [
				{"text": "\"Guilty. Restitution in full.\" The chain does not get to choose your justice for you.",
					"resonance": 12.0, "flags": {"delivered_verdict": true, "chose_virtue": true}, "next": "b_verdict"},
				{"text": "Spare him. A shield does not put down what it carried.",
					"resonance": -12.0, "flags": {"spared_guilty": true, "chose_temptation": true}, "next": "b_spared"},
				{"text": "Adjourn. An arbiter who fought for the accused can no longer judge him.",
					"resonance": -4.0, "flags": {"recused": true, "chose_away": true}, "next": "b_recused"},
			]},
		"b_verdict": {"who": "Narrator", "text": "The word lands like the hammer did. Somewhere inside, the chain goes QUIET — not defeated. Respectful.", "next": "n_end"},
		"b_spared": {"who": "Narrator", "text": "Osric weeps his thanks. The chain purrs its approval. It is already deciding what ELSE you know better than the law does.", "next": "n_end"},
		"b_recused": {"who": "Narrator", "text": "Clean hands, empty bench. The next arbiter will not know the ledgers like you do — and the chain counts that as a win too.", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "Word of the arbiter with the burning hammer reaches Emberfall Village before you do."},
	}},
	"maren_paladin": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "delivered_verdict", "text": "Bearer. An arbiter who guts a raid, then walks back inside and convicts the man he saved? The chain you carry was FORGED to bind — and you just showed it who holds it. I have waited a long time to meet one of you."},
				{"flag": "spared_guilty", "text": "Bearer. Osric the miller — alive, pardoned, and already hoarding again, they say. The chain told you 'mercy' and you called it your own idea. Learn the difference quickly."},
				{"flag": "recused", "text": "Bearer. You stepped away from the bench rather than test the chain. Prudent. But the chain is patient, arbiter — one day there will be no other judge in the room."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: a still shield shelters no one."},
	}},

	# ---- Warlock opening: the pact you don't remember making.
	"open_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "crown", "text": "The kingdom of Emberfall has fallen quiet. The Ember Crown has been stolen, and Vargoth — the hollow king — walks again.", "next": "n2"},
		"n2": {"who": "Narrator", "cue": "tome", "text": "You wake at a cold desk in a room you rent by the week. There is a tome under your hand that was not there when you slept — and your own handwriting in a journal you do not remember keeping: 'IT SAID YES. I HADN'T FINISHED ASKING.'", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "tome_open", "text": "The pages agree on three things. You made a pact. You traded something you have not lost YET. And the tome will tell you what — for one more small borrowing. The interest, it promises, is negligible.", "next": "n4"},
		"n4": {"who": "The Tome", "text": "ONE PAGE'S WORTH. A CANDLE OF KNOWING. YOU OWE SO MUCH ALREADY — WHAT IS A CANDLE?",
			"choices": [
				{"text": "Close it. \"I'll pay what I owe as myself — and not a candle more.\"",
					"resonance": 12.0, "flags": {"closed_tome": true, "chose_virtue": true}, "next": "b_closed"},
				{"text": "Ask. Knowing the price is only sensible — borrow the candle.",
					"resonance": -12.0, "flags": {"borrowed_more": true, "chose_temptation": true}, "next": "b_borrowed"},
				{"text": "Burn the journal. If a stranger made this deal, let a stranger owe it.",
					"resonance": -4.0, "flags": {"burned_pages": true, "chose_away": true}, "next": "b_burned"},
			]},
		"b_closed": {"who": "Narrator", "text": "The tome shuts with the sound of a ledger balancing. Somewhere beyond the edge of things, something makes a small, patient note.", "next": "n_end"},
		"b_borrowed": {"who": "Narrator", "text": "The knowledge arrives, and it is TRUE, and it is useful, and the debt is a little deeper — exactly as sensible as the last time you told yourself this.", "next": "n_end"},
		"b_burned": {"who": "Narrator", "text": "The pages burn green. The debt does not. Under the ash, the first line of the ledger rewrites itself — in your own fresh hand.", "next": "n_end"},
		"n_end": {"who": "Narrator", "cue": "fade", "text": "The tome rides in your pack to Emberfall Village like it has always known the way."},
	}},
	"maren_warlock": {"start": "m1", "nodes": {
		"m1": {"who": "Elder Maren",
			"text": "Bearer! Thank the flame you came.",
			"variants": [
				{"flag": "closed_tome", "text": "Bearer. I can smell the loan on you from the gate. And yet — it's QUIET. You told it no, didn't you? Keep telling it no. I'll help where I can, and I'll be watching where I can't."},
				{"flag": "borrowed_more", "text": "Bearer. The thing about candles of knowing: they light the room and burn the house. You borrowed again on the road here — don't trouble to deny it, your shadow leans wrong. I'll take your help, warlock. I won't take my eyes off you."},
				{"flag": "burned_pages", "text": "Bearer. Burnt pages, fresh ink. You cannot fire a debt, only the record of it — and the creditor keeps better books than you do. Stay where I can see you."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: still things are what the creditor collects first."},
	}},

	# ================================================= Chapter 1 room content
	# Social wanderers (rolled per character into social rooms).
	"wander_tinker": {"start": "t1", "nodes": {
		"t1": {"who": "Tinker Osla",
			"text": "Axle's cracked. Third one this season — the roads got worse when the wolves got bold. You wouldn't hold the cart steady a moment?",
			"variants": [{"flag": "helped_tinker", "text": "The cart rolls straight now, thanks to you. If you pass a smith, tell them Osla still owes for the axle.", "next": ""}],
			"choices": [
				{"text": "Set your shoulder against the cart. \"Take your time.\"",
					"resonance": 3.0, "flags": {"helped_tinker": true}, "next": "t_help"},
				{"text": "\"Roads are dangerous. Pay someone to guard you next time.\"",
					"resonance": -2.0, "next": "t_no"},
			]},
		"t_help": {"who": "Tinker Osla", "text": "There — seated. You've an honest shoulder for someone armed to the teeth. Flame keep you down the road.", "next": ""},
		"t_no": {"who": "Tinker Osla", "text": "Aye, and eat what, while I pay them? ...Safe travels anyway, stranger.", "next": ""},
	}},
	"wander_deserter": {"start": "d1", "nodes": {
		"d1": {"who": "Ragged Soldier",
			"text": "Before you say it: yes, that's a keep tabard under the mud. I walked. You stand a night watch hearing THAT thing sing through the stones and see how long your oath holds.",
			"variants": [{"flag": "heard_deserter", "text": "Still here. Still walking nowhere in particular. It's quieter out here, at least.", "next": ""}],
			"choices": [
				{"text": "\"Sit. Tell me what you heard in there — all of it.\"",
					"resonance": 3.0, "flags": {"heard_deserter": true}, "next": "d_hear"},
				{"text": "\"You left your post. Whatever sang to you, others still hear it.\"",
					"resonance": -3.0, "flags": {"heard_deserter": true}, "next": "d_shame"},
			]},
		"d_hear": {"who": "Ragged Soldier", "text": "It hums through the floor at night. Old words. And the worst part — some mornings you wake up HUMMING ALONG. Kill it at the source, if that's where you're headed. Don't listen long.", "next": ""},
		"d_shame": {"who": "Ragged Soldier", "text": "...Aye. They do. And I'll carry that longer than I carried the spear. Go on, then — be braver than me. Someone has to be.", "next": ""},
	}},
	"wander_pilgrim": {"start": "p1", "nodes": {
		"p1": {"who": "Pilgrim of the Flame",
			"text": "I walk to every hearth the blight has touched and light a stick of pine. It does nothing, the scholars say. The scholars have never sat in a dark house.",
			"variants": [
				{"band": "tempted", "text": "...The flame leans when you stand near it, friend. I won't ask. But I'll burn a stick of pine for you especially."},
				{"band": "steady", "text": "The flame sits easy near you. That's rarer than you know, out here. Walk with it."},
			],
			"next": ""},
	}},
	"wander_hunter": {"start": "h1", "nodes": {
		"h1": {"who": "Old Hunter",
			"text": "Word of advice, since you're kitted for trouble: the packs out here move TOGETHER now. Wound one and its whole family answers. Pick your ground before you pick a fight.",
			"variants": [{"flag": "met_hunter", "text": "Still breathing? Good. Told you the ground matters more than the blade.", "next": ""}],
			"next": "h2"},
		"h2": {"who": "Old Hunter", "text": "And if you find a still pool deep in the wood — the one that holds the moon wrong — don't drink before you've decided who you are. That's free too.",
			"choices": [
				{"text": "\"Thanks for the warning, hunter.\"", "flags": {"met_hunter": true}, "next": ""},
				{"text": "\"Save the ghost stories. Wolves die like anything else.\"",
					"resonance": -2.0, "flags": {"met_hunter": true}, "next": "h_scoff"},
			]},
		"h_scoff": {"who": "Old Hunter", "text": "Aye, they do. So do hunters who knew everything. The wood buries both kinds the same depth — but suit yourself. The advice keeps better than you will.", "next": ""},
	}},
	"wander_peddler": {"start": "w1", "nodes": {
		"w1": {"who": "Roadside Peddler",
			"text": "No stock left worth your coin — the camps bought me clean. But gossip's free: the marsh witch pays her spiders in something, and the stilt-camp merchant swears it's TEETH. Make of that what you will.",
			"variants": [{"flag": "met_peddler", "text": "Still no stock. Still full of gossip. The teeth thing? I stand by it.", "next": ""}],
			"choices": [
				{"text": "\"...Teeth.\"", "flags": {"met_peddler": true}, "next": "w2"},
				{"text": "\"Your gossip's worth what your stock is — nothing. Move along, peddler.\"",
					"resonance": -3.0, "flags": {"met_peddler": true}, "next": "w_scorn"},
			]},
		"w2": {"who": "Roadside Peddler", "text": "TEETH. Ask her yourself if you don't believe me. Actually — don't.", "next": ""},
		"w_scorn": {"who": "Roadside Peddler", "text": "Free and worthless are different words, friend — a peddler learns that before the first cart breaks. When the spiders find you, do remember I mentioned the teeth for nothing.", "next": ""},
	}},
	"wander_orphan": {"start": "o1", "nodes": {
		"o1": {"who": "Miller's Boy",
			"text": "You're going TOWARD the howling? On purpose? ...My da went toward the howling. If you see a wide-brim hat out there — brown, with a heron feather — it's his.",
			"variants": [
				{"flag": "hat_given", "text": "The hat rides low over the boy's ears — he's pinned the brim up with a wolf tooth. Nobody at the mill teases him about the size. Nobody would dare.", "next": ""},
				{"flag": "hat_taken", "text": "You're— that's. Behind your back. That's a HAT.", "next": "o_hat"},
				{"flag": "boy_answered", "text": "You'll watch for the hat? Brown, heron feather. I'll be here.", "next": ""},
			],
			"choices": [
				{"text": "Crouch to his height. \"I'll watch for the hat. I promise nothing else.\"",
					"resonance": 3.0, "flags": {"boy_answered": true},
					"side_quest": "heron_feather", "next": "o_kind"},
				{"text": "\"The wood keeps what it takes, boy. Go home.\"",
					"resonance": -3.0, "flags": {"boy_answered": true}, "next": "o_cold"},
			]},
		"o_kind": {"who": "Miller's Boy", "text": "That's more than anyone else promised. The feather's blue at the tip. You'll know it.", "next": ""},
		"o_cold": {"who": "Narrator", "text": "He doesn't cry. He just looks at you the way you look at weather — and heads home. It was probably the truth. It didn't need to be yours to say.", "next": ""},
		"o_hat": {"who": "Miller's Boy", "text": "Show me. Please. Is the feather blue at the tip?",
			"choices": [
				{"text": "Hold it out. \"Brown, wide-brim, heron feather — blue at the tip. I watched for it, like I said.\"",
					"req_flag": "boy_answered", "resonance": 3.0,
					"flags": {"hat_given": true}, "lose_item": "millers_hat", "next": "o_hat2"},
				{"text": "Hold it out. \"Found it by the ravine, in the thorns. I think... I think it's his.\"",
					"req_not_flag": "boy_answered", "resonance": 3.0,
					"flags": {"hat_given": true, "boy_answered": true}, "lose_item": "millers_hat", "next": "o_hat2"},
				{"text": "\"...Another time.\" Keep the pack shut.", "next": ""},
			]},
		"o_hat2": {"who": "Narrator", "text": "He doesn't cry this time either. He puts it on — it swallows him to the eyebrows — and stands straighter under it than the size should allow. \"He got far?\" \"The ravine. He saw the whole wood.\" The boy nods, slow, like a man watching a debt settle. \"That's a good place to stop walking,\" he decides. So do you.", "next": ""},
	}},

	# Resonance shrines: a genuine band-shifting choice between story beats.
	"shrine_moonwell": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "A still pool in a ring of silver birches. The moon sits in the water — full, though the sky above holds only a sliver. The Ember in you leans toward it like a plant toward light. The water would give. It always gives. The question is what it takes.",
			"variants": [{"flag": "moonwell_touched", "text": "The pool is only a pool now — the moon in it matches the sky. Whatever it wanted to know about you, it knows.", "next": ""}],
			"choices": [
				{"text": "Kneel and give the water a memory freely — let it take, and take nothing back.",
					"resonance": 8.0, "flags": {"moonwell_touched": true, "chose_moonwell_gave": true}, "next": "s_give"},
				{"text": "Drink. Power is there for the taking, and you have a king to kill.",
					"resonance": -8.0, "flags": {"moonwell_touched": true, "chose_moonwell_drank": true}, "next": "s_drink"},
				{"text": "Step back from the edge. Not every offered thing must be answered.",
					"resonance": 0.0, "flags": {"moonwell_touched": true}, "next": "s_leave"},
			]},
		"s_give": {"who": "Narrator", "text": "You give it a small warm morning from years ago. The water goes dark, satisfied — and the Ember in you sits QUIETER, like a debt paid down. You will not miss the morning. That is the strange part.", "next": ""},
		"s_drink": {"who": "Narrator", "text": "Cold light down the throat. Strength floods in — and underneath it, faint as a hook in a fish, something now runs the other way. The Ember purrs. You choose not to wonder what swims up a line like that.", "next": ""},
		"s_leave": {"who": "Narrator", "text": "The moon in the water watches you go. Neither of you owes the other anything. It is the rarest way an encounter with power ends.", "next": ""},
	}},
	"shrine_reliquary": {"start": "r1", "nodes": {
		"r1": {"who": "Narrator",
			"text": "A vault the looters somehow missed: the Ember Guard's reliquary. On a dusty plinth, the padded stand where the CROWN once rested — empty sixty years. Around it, the small honest relics of four founders. The Ember in you knows this room. It was BUILT here.",
			"variants": [{"flag": "reliquary_touched", "text": "The reliquary keeps its dust and its dead. The empty stand no longer pulls at you — or you no longer answer.", "next": ""}],
			"choices": [
				{"text": "Kneel to the founders and renew their oath in your own words.",
					"resonance": 8.0, "flags": {"reliquary_touched": true, "chose_reliquary_oath": true}, "next": "r_oath"},
				{"text": "Rest your hand on the crown-stand. Just to know how it would feel.",
					"resonance": -8.0, "flags": {"reliquary_touched": true, "chose_reliquary_hand": true}, "next": "r_hand"},
				{"text": "Touch nothing. Some rooms are graves; act like it.",
					"resonance": 0.0, "flags": {"reliquary_touched": true}, "next": "r_leave"},
			]},
		"r_oath": {"who": "Narrator", "text": "The words come out plain and unheroic, which is how the true ones sound. The Ember steadies — not tamed, but ENLISTED. Somewhere in its long memory, four dead founders note the signature.", "next": ""},
		"r_hand": {"who": "Narrator", "text": "It would feel like THIS: right. Fitted. Overdue. You take your hand back — you can still do that, this time — and the Ember spends the rest of the hour showing you the room from a throne's height.", "next": ""},
		"r_leave": {"who": "Narrator", "text": "You leave the dust its shapes. On the way out, the Ember tests the lock on you, once, quietly — and finds it holds.", "next": ""},
	}},

	# Dead-end lore props.
	"lore_hollow_oak": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A grandfather oak, split open and hollow. Inside, wax stubs and a child's carved wolf — someone hid offerings here for the wood's old spirits, long before the blight gave the wood new ones. The candle wax is recent.", "next": ""},
	}},
	"lore_ravine": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The ravine has nothing for you. No monsters, no treasure, no secret door. The view, though — the whole Darkwood rolling east under the mist, and the keep's towers far off, patient as tombstones. You allow yourself one long minute of it.", "next": ""},
	}},
	"lore_drowned_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A flooded chapel of the Flame, sunk to its windows. The altar stone stands just above the waterline, and someone has kept ONE candle burning on it — the wax runs down in years, not hours. Morwen's blight circles this place and does not enter. Interesting, that it can't. Or won't.",
			"variants": [
				{"flag": "chapel_cupped", "text": "The candle burns on the altar stone, steady over the black water. The flame leans toward you when you enter now — barely. But it does.", "next": ""},
				{"flag": "chapel_snuffed", "text": "The candle burns — relit, grudging, a shade smaller than it was. The blight circles a half-step closer than you remember. Neither of you mentions it.", "next": ""},
				{"flag": "chapel_faced", "text": "The candle burns on, sixty years and one more night. The watch was never yours. It minds the door all the same.", "next": ""},
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
			]},
		"c_cup": {"who": "Narrator", "text": "The gust breaks on your knuckles and the flame steadies, and for one held breath the chapel is exactly what it was built to be: a lit room in the dark, with someone minding the door. Out on the water, the blight's slow circling falters — a half-step, no more. It is enough to have been seen doing it.", "next": ""},
		"c_snuff": {"who": "Narrator", "text": "Dark comes down like a lid — and the marsh LEANS: reeds, water, the far unseen singing, all of it, toward the altar, the way a crowd leans at a scaffold. You relight it. You TRY. The wick takes on the third strike, grudging, smaller. Some watches you do not get to end on someone else's behalf. The Ember, you notice, enjoyed the dark just fine.", "next": ""},
		"c_leave": {"who": "Narrator", "text": "It has burned sixty years of nights exactly like this one. You leave it to the work, and the flame stands a little taller in the still air behind you — or you tell yourself it does. Either way, the door was minded tonight.", "next": ""},
	}},
	"lore_collapsed_tower": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The watchtower fell the night Vargoth rose — the masonry still shows the burn-shadow of the guard who stood here when it came down. Under the rubble: a rusted signal-horn, mouthpiece worn bright from use. He was CALLING someone, at the end. The record does not say if anyone came.",
			"variants": [
				{"flag": "horn_blown", "text": "The signal-horn rests on the rubble where you set it. The horizon has kept its answer to itself since — but you know what you heard, and the storm knows you heard it.", "next": ""},
				{"flag": "horn_rested", "text": "The horn stands on the rubble, mouthpiece up, aimed at the horizon. Still ready. Still his.", "next": ""},
			],
			"next": "t_horn"},
		"t_horn": {"who": "Narrator", "text": "The horn has waited under the rubble for sixty years, mouthpiece worn bright, call unfinished.",
			"choices": [
				{"text": "Raise it and sound the call — finish what the guard started.",
					"resonance": 3.0, "flags": {"horn_blown": true}, "next": "t_blow"},
				{"text": "Set it upright on the rubble, mouthpiece up, the way a signalman stands his post. Leave the silence his.",
					"resonance": 0.0, "flags": {"horn_rested": true}, "next": "t_rest"},
			]},
		"t_blow": {"who": "Narrator", "text": "The note comes out cracked, then enormous — it rolls east over the marsh and the wastes and takes sixty years of waiting with it. Silence. Then, from far past the keep, where the storm never quite leaves the horizon: one long note back. The same call. An answer six decades late — or an acknowledgment. Somewhere, a watch that never ended has changed hands.", "next": ""},
		"t_rest": {"who": "Narrator", "text": "You set it ready, pointed at the horizon. Some calls are not yours to finish. The burn-shadow on the masonry keeps its silence, and you leave the tower feeling watched — not unkindly.", "next": ""},
	}},
	# The miller's hat (payoff for the boy's ask — see wander_orphan).
	# The prop spawns only in worlds that rolled the boy (req_wanderer);
	# taking it puts a quest keepsake in the bag ("gain_item") which the
	# boy collects ("lose_item") — and which does not outlive the run.
	"lore_millers_hat": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator",
			"text": "Snagged in the thorns at the ravine's lip: a wide-brim hat, brown once, rain-stiffened to the color of bark. A heron feather still rides the band — blue at the tip. Whoever walked this far came for the view, or was past wanting anything. The wood keeps its own accounts.",
			"variants": [
				{"flag": "hat_taken", "text": "The thornbush keeps the hat's shape, empty. You check it every pass anyway. Habit, now.", "next": ""},
				{"flag": "boy_answered", "text": "Snagged in the thorns at the ravine's lip: a wide-brim hat. Brown. Heron feather. You know before you turn it over — blue at the tip. The miller made it exactly this far, and the view from here is the whole Darkwood.", "next": "h_know"},
			],
			"next": "h_found"},
		# You made the boy a promise — the hat is the other half of it.
		"h_know": {"who": "Narrator", "text": "A boy at the village edge is waiting on a promise. The hat weighs nothing, and will weigh more every mile back.",
			"choices": [
				{"text": "Work it free of the thorns, gently. A promise is a promise.",
					"resonance": 3.0, "flags": {"hat_taken": true}, "gain_item": "millers_hat",
					"side_quest": "heron_feather", "next": "h_take"},
				{"text": "Leave it where the wind put it. For now, or for good.", "next": ""},
			]},
		# Found cold, before (or without) ever meeting the boy.
		"h_found": {"who": "Narrator", "text": "Somebody's da wore this toward the howling and did not come back for it. It would cost nothing to carry.",
			"choices": [
				{"text": "Take it. Somebody, somewhere, is short one hat and one answer.",
					"resonance": 1.0, "flags": {"hat_taken": true}, "gain_item": "millers_hat",
					"side_quest": "heron_feather", "next": "h_take"},
				{"text": "Leave it where the wind put it.", "next": ""},
			]},
		"h_take": {"who": "Narrator", "text": "The thorns give it up one at a time, grudging as this wood ever gets. Up close, the brim shows years of a thumb finding the same worn spot. You find the spot without meaning to. It rides in your pack, light as a promise.", "next": ""},
	}},
}

# ---------------------------------------------------------------- enemies ---

# Defensive stats: physres/magres (log-curve reduction), eva (dodge
# chance, countered by DEX), critres (shaves attacker crit chance).
#
# LEVELS & GROWTH: the listed hp/dmg are the monster's stats AT its
# listed "level" — which is also its MINIMUM level (no downscaling;
# see enemy_stats_at). Above it they scale by the per-monster GROWTH
# rates — a wolf gains little per level while a boss gains a lot, so
# a high-level wolf is dangerous but a same-level boss dwarfs it.
# "attrs" is the monster's per-level attribute build (see
# MONSTER_ATTR_SCALE); kinds without one get an archetype default.
# Cap: level 100.
#
# XP (playtest round 5): trash xp is anchored so a FULL clear of ch1
# tracks the room mob levels within ±1 and lands at each boss's level
# (L5 Fangmaw / L8 Morwen / L11-12 Vargoth on the 30+22·lvl curve) —
# the old values overshot by ~3 levels ("I'm L10 farming L6 mobs").
# Retune trash + bosses TOGETHER against that budget, never one alone.
# (Tuning knobs — level cap, TTK/gold multipliers, reward growth —
# live in balance.gd.)

const ENEMIES := {
	# Playtest retune (2026-07, round 2): mobs hit ~50% harder and melee
	# kinds run faster — a naked, talentless run should NOT clear the
	# chapter. Getting caught by a pack is supposed to sting.
	"wolf":     {"name": "Blighted Wolf",   "sprite": "wolf",     "hp": 34.0,  "dmg": 12.0, "speed": 175.0, "xp": 7,  "gold": 4,  "ranged": false, "scale": 3.0,
		"physres": 5.0,  "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.10, "dmg_g": 0.08, "traits": ["pounce"]},
	"spider":   {"name": "Marsh Spider",    "sprite": "spider",   "hp": 28.0,  "dmg": 9.0,  "speed": 215.0, "xp": 8,  "gold": 5,  "ranged": false, "scale": 3.0,
		"physres": 0.0,  "magres": 5.0,  "eva": 0.12, "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.09, "dmg_g": 0.08, "traits": ["web"]},
	"cultist":  {"name": "Blight Cultist",  "sprite": "cultist",  "hp": 40.0,  "dmg": 14.0, "speed": 90.0,  "xp": 11, "gold": 8,  "ranged": true,  "scale": 3.0,
		"physres": 5.0,  "magres": 15.0, "eva": 0.0,  "critres": 0.0, "dmg_type": "magic",
		"level": 4, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["channel_heal"]},
	"skeleton": {"name": "Hollow Soldier",  "sprite": "skeleton", "hp": 62.0,  "dmg": 20.0, "speed": 140.0, "xp": 13, "gold": 10, "ranged": false, "scale": 3.0,
		"physres": 25.0, "magres": 5.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 7, "hp_g": 0.12, "dmg_g": 0.10, "traits": ["frenzy", "swift"]},
	"zombie":   {"name": "Risen Corpse",    "sprite": "zombie",   "hp": 45.0,  "dmg": 14.0, "speed": 115.0, "xp": 8,  "gold": 6,  "ranged": false, "scale": 3.0,
		"physres": 12.0, "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["mend"]},
	# TODO(bats): the "evasive aerial flyer" special mechanics were REMOVED
	# per owner (2026-07-08) — the POUNCE trait and the flat EVASION are gone,
	# so bats no longer dodge/leap; they behave as plain melee mobs. The lone
	# "swift" tag is kept ONLY because the mob-tag invariant (autotest) needs
	# >=1 real trait, and "swift" is the mildest (just quicker on its feet, no
	# special behavior). Revisit later: re-add the evasive flit / a real
	# flight AI once the aerial-swarm design is finalized. Roster + codex only.
	"bat":      {"name": "Cave Bat",   "sprite": "bat",     "hp": 24.0, "dmg": 10.0, "speed": 230.0, "xp": 6,  "gold": 3,  "ranged": false, "scale": 2.8,
		"physres": 0.0, "magres": 0.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 3, "hp_g": 0.09, "dmg_g": 0.08, "traits": ["swift"]},
	"direbat":  {"name": "Blightbat",  "sprite": "direbat", "hp": 70.0, "dmg": 18.0, "speed": 205.0, "xp": 14, "gold": 11, "ranged": false, "scale": 3.6,
		"physres": 8.0, "magres": 8.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 8, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["swift"]},
	# Bosses: strong base AND strong growth ("dragon-grade" scaling).
# HP pools follow the TTK BUDGET (playtest round 9: "Fangmaw died in
# <10s to C-gear, zero talents"): at level with modest gear a boss
# should survive ~25s (chapter opener) / ~30s (mid) / ~40s (finale)
# of realistic player DPS. Retune pools when player power moves.
	# "boss": true exempts them from the mob TTK retune (enemy_stats_at).
	# Boss damage retune (round 4): bosses were authored gentle — a
	# contact hit should cost a squishy ~20-25% of their at-level HP.
	# With compounding growth, a boss 5 above you leaves ~2 mistakes,
	# 10 above ~1. Dodge-everything god runs stay possible.
	# Boss scale ordinance (2026-07-09, supersedes the 2026-07-07 doctrine):
	# every boss reads >=2.5x the player's ON-SCREEN body height, and a
	# chapter's finale is clearly the biggest thing in its chapter. Compute
	# from MEASURED art, not the raw scale number: on-screen body px =
	# scale * 16 * (alpha-bbox height / cell width) of the idle strip, and
	# the player's body is 52px (player_core HERO_TARGET_BODY) — coverage
	# varies per sheet (vargoth ~0.74, skeleton ~0.48), so identical scales
	# render wildly different sizes. Contact bites stay fair at any size
	# via Boss._reach (body-edge, not center, distance); note the physics
	# circle (enemy.gd: radius 6*scale*0.7) grows with the same knob.
	"fangmaw":  {"name": "Fangmaw the Ravener",     "sprite": "fangmaw", "hp": 1200.0,  "dmg": 30.0, "speed": 160.0, "xp": 80,  "gold": 60,  "ranged": false, "scale": 8.5,
		"physres": 15.0, "magres": 10.0, "eva": 0.08, "critres": 2.0, "crit": 0.05, "dmg_type": "phys",
		"level": 4, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "AGI": 1.5},
		"mechanics": [
			{"name": "Pounce",
			 "tell": "He crouches and a danger circle paints the ground under you, then he leaps and crashes down on it.",
			 "counter": "The circle marks where he lands, not where you stand now — step clear of it before he hits."},
			{"name": "Telegraphed Charge",
			 "tell": "He freezes and flashes bright red for a beat, locking onto your position, then bolts in a straight line and bites at the end.",
			 "counter": "The red flash is your cue — sidestep once he commits; he charges a fixed line and can't correct mid-run."},
			{"name": "Calls the Pack (50%)",
			 "tell": "At half health he howls and two wolves spawn at his flanks.",
			 "counter": "The wolves drop zero XP and gold — don't farm them. Keep damage on Fangmaw and kite the pack rather than chasing it."}]},
	"morwen":   {"name": "Morwen the Blightcaller", "sprite": "morwen",   "hp": 2200.0,  "dmg": 26.0, "speed": 120.0, "xp": 110, "gold": 90,  "ranged": true,  "scale": 9.0,
		"physres": 10.0, "magres": 35.0, "eva": 0.10, "critres": 3.0, "crit": 0.05, "dmg_type": "magic",
		"level": 7, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.0},
		"mechanics": [
			{"name": "Blight Rain",
			 "tell": "She raises her staff and four green poison pools bloom in sequence — one right under you, the rest scattered around.",
			 "counter": "The pools land staggered, not all at once. Walk out of the first as the next telegraphs and keep drifting through the gaps."},
			{"name": "Blink Away",
			 "tell": "Close inside melee range and she vanishes, reappearing a long way off.",
			 "counter": "Expect her to teleport the moment you get near — save gap-closers and dashes for right after she blinks, not before."},
			{"name": "Bolt Volleys & Ring",
			 "tell": "She fires a three-bolt fan at you on a fast cadence, and periodically rings out a full circle of twelve bolts.",
			 "counter": "Strafe across the fan rather than backing straight up. For the ring, slip out through a gap between bolts instead of tanking it."}]},
	"vargoth":  {"name": "King Vargoth the Hollow", "sprite": "vargoth",  "hp": 4200.0, "dmg": 50.0, "speed": 132.0, "xp": 200, "gold": 150, "ranged": false, "scale": 13.0,
		"physres": 40.0, "magres": 25.0, "eva": 0.0,  "critres": 5.0, "crit": 0.05, "dmg_type": "phys",
		"level": 10, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"STR": 2.0, "VIT": 1.5},
		"mechanics": [
			{"name": "Blade Storm",
			 "tell": "He calls down a run of greatswords from the sky, each marking your current position a beat before it falls.",
			 "counter": "The blades chase where you are, so never stand still — keep moving and each one lands on ground you've already left."},
			{"name": "Shockwave Slam",
			 "tell": "He slams the ground with a screen shake and a wide ring of slow bolts rolls outward in every direction.",
			 "counter": "The bolts are slow and evenly spaced — don't fight from point-blank; give yourself room and weave out between them."},
			{"name": "The Hollow King Enrages (30%)",
			 "tell": "Below 30% he flares red, roars, and moves half again as fast.",
			 "counter": "His blade storm and slam come far more often now — burn him down fast and expect a tighter dodge cadence on everything."}]},
}


# Monster attribute conversion — one table for all monsters (the
# player's equivalent is Classes.ATTR_SCALE, per class). A kind's
# "attrs" build is points invested PER LEVEL above its anchor, so
# every substat climbs with level, not just hp/dmg.
const MONSTER_ATTR_SCALE := {
	"STR": {"physpen": 0.8, "critres": 0.2},
	"AGI": {"dex": 1.0, "crit": 0.004, "eva": 0.0015},
	"INT": {"magpen": 0.8, "magres": 0.5},
	"VIT": {"physres": 0.8, "magres": 0.4, "critres": 0.3},
}

# Every substat enemy_stats_at scales and Enemy._setup consumes.
const SCALED_SUBSTATS := ["physres", "magres", "eva", "critres", "crit",
	"dex", "physpen", "magpen"]


## The per-level attribute spread for kinds that don't author "attrs":
## brutes push STR, skirmishers AGI, casters INT, everyone a bit of
## VIT — and bosses invest at double the trash rate (they ARE the wall).
static func monster_build(base: Dictionary) -> Dictionary:
	if base.has("attrs"):
		return base["attrs"]
	var primary := "STR"
	if str(base.get("dmg_type", "phys")) == "magic":
		primary = "INT"
	elif bool(base.get("ranged", false)):
		primary = "AGI"
	if bool(base.get("boss", false)):
		return {primary: 2.0, "VIT": 1.0}
	return {primary: 1.0, "VIT": 0.5}


## A monster's FULL combat sheet at an arbitrary level.
## NO DOWNSCALING (playtest round 6): the listed level is a MINIMUM —
## spawn an endgame boss in chapter 1 and it arrives with its stats
## as-is; spawn an early boss at endgame and it scales UP, staying a
## (lesser) threat forever. hp/dmg growth COMPOUNDS per level (round
## 4, matching the player's own compounding curve); every offensive/
## defensive substat climbs linearly via the monster's attribute
## build. At the listed level nothing changes, codex numbers stay
## honest, and rewards stay LINEAR (no farm spiral).
static func enemy_stats_at(kind: String, level: int) -> Dictionary:
	load_content()
	var base: Dictionary = ALL_ENEMIES[kind]
	var lvl := clampi(level, int(base["level"]), Balance.LEVEL_CAP)
	var d := lvl - int(base["level"])
	var is_boss := bool(base.get("boss", false))
	# Bosses grow HP on the global BOSS_HP_GROWTH (tracks the player DPS curve so
	# TTK stays flat when scaled above native); mobs keep their per-kind hp_g.
	var hp_growth: float = Balance.BOSS_HP_GROWTH if is_boss else float(base["hp_g"]) * Balance.GROWTH_SCALE
	var hp_m := pow(1.0 + hp_growth, d)
	if not is_boss:
		# Mobs only (boss pools are budgeted directly): the TTK retune plus
		# the 2026-07-07 presence pass — fatter pools so trash needs real
		# hits, not a tap. Codex reads this, so the numbers stay honest.
		hp_m *= Balance.TTK_HP_MULT * Balance.MOB_HP_MULT
	var dmg_growth := float(base["dmg_g"]) * Balance.GROWTH_SCALE
	var dmg_flat := Balance.ENEMY_DMG_MULT
	if not is_boss:
		dmg_flat *= Balance.MOB_DMG_MULT  # +20% mob contact/bolt (presence pass)
	if is_boss:
		# Bosses hit a constant ~20% above parity (the skill tilt), and
		# their damage GROWTH tracks the player curve exactly — the gap
		# must not widen with level (round 13: L42 A-gear playtest).
		dmg_growth = Balance.BOSS_DMG_GROWTH
		dmg_flat *= Balance.BOSS_DMG_MULT
	var dmg_m := pow(1.0 + dmg_growth, d) * dmg_flat
	# Gem-expectation ramp (2026-07-06): the TIERLIST benchmark was
	# gemless, but real players arrive socketed — UPSCALED bosses gain a
	# small premium per level above where gems come online (round 45's
	# "budget what the player actually has", extended). Anchor stats stay
	# exactly as authored: high-anchor bosses get their gem allowance at
	# authoring time, not from a hidden multiplier.
	if is_boss:
		var gl := float(lvl - maxi(Balance.BOSS_GEM_RAMP_START, int(base["level"])))
		if gl > 0.0:
			hp_m *= 1.0 + Balance.BOSS_GEM_HP_RAMP * gl
			dmg_m *= 1.0 + Balance.BOSS_GEM_DMG_RAMP * gl
	var reward_m := 1.0 + d * Balance.REWARD_PER_LEVEL
	var out := {"level": lvl, "hp": base["hp"] * hp_m, "dmg": base["dmg"] * dmg_m,
		"xp": int(ceil(base["xp"] * reward_m)),
		"gold": maxi(1, int(ceil(base["gold"] * reward_m * Balance.GOLD_MULT)))}
	for stat in SCALED_SUBSTATS:
		out[stat] = float(base.get(stat, 0.0))
	var build := monster_build(base)
	for attr in build:
		var pts: float = float(build[attr]) * d
		for stat in MONSTER_ATTR_SCALE[attr]:
			out[stat] += MONSTER_ATTR_SCALE[attr][stat] * pts
	return out

# ------------------------------------------------------------------ rooms ---
# Chapter 1 as a ZONE GRAPH (the vertical slice; see DESIGN.md).
# Each room dict is one entry in the chapter's "zones" array (the array
# index is the room id — enemies still carry it as zone_idx).
#
# Graph keys (graph-authored chapters; legacy chapters without "coord"
# are auto-converted to a west→east chain by Game._prepare_rooms):
#   "coord": [gx, gy]      grid cell (unique per chapter)
#   "exits": ["N","E"]     open sides; the neighbor room must exist.
#                          Declared one-sided: the reciprocal is implied.
#   "locks": {"E": lock}   gate on that exit. Lock forms:
#                          "boss"     opens when this room's boss dies
#                          "clear"    opens when this room's packs die
#                          "flag:x"   opens when story flag x is set
#   "type": "safe" | "combat" | "boss" | "social" | "resonance"
#           | "dead_end" | "merchant"   (defaults: boss/combat/safe)
#   "cache": "wood"|"silver"|"gold"    dead-end chest (once per character)
#   "shop_tier": chest-tier string for the room's merchant stock
#
# Enemy spawns: [kind, x, y, pack, level] — pack (default 0) is the
# per-pack aggro group; level (optional) overrides the kind's base level.
# Positions are LOCAL to the room: playable space is roughly
# x 100..2010, y 100..1150; the road band is y ~552..696.

const ZONES := [
	# ---------------------------------------------------- village (start) ---
	{
		"name": "Emberfall Village", "terrain": "village", "type": "safe",
		"coord": [0, 1], "exits": ["E", "S"], "locks": {"E": "flag:met_elder"},
		"lock_next": "flag:met_elder",
		"merchant": [1050, 480], "shop_tier": "wood",
		"enemies": [], "boss": "",
	},
	{
		"name": "Village Outskirts", "terrain": "village", "type": "social",
		"coord": [0, 2], "exits": ["N"],
		"enemies": [], "boss": "",
	},
	# ------------------------------------------------------- the darkwood ---
	{
		"name": "The Darkwood Road", "terrain": "darkwood", "type": "combat",
		"coord": [1, 1], "exits": ["W", "E", "N"],
		"enemies": [
			["wolf", 500, 300, 0], ["wolf", 620, 380, 0], ["wolf", 560, 480, 0],
			["wolf", 1400, 900, 1], ["wolf", 1520, 820, 1], ["wolf", 1350, 1000, 1],
			["spider", 1480, 950, 1],
			["wolf", 900, 170, 2], ["wolf", 1030, 140, 2], ["spider", 960, 260, 2],
		],
		"boss": "",
	},
	{
		"name": "The Hollow Oak", "terrain": "darkwood", "type": "dead_end",
		"coord": [1, 0], "exits": ["S"], "cache": "wood",
		"enemies": [["wolf", 1050, 500, 0, 3], ["wolf", 1180, 600, 0, 3]],
		"boss": "",
		"npcs": [{"sprite": "deadtree", "x": 1000, "y": 300, "prompt": "E — Look", "convo": "lore_hollow_oak"}],
	},
	# The spine BENDS here: north through the deep wood, not straight east.
	{
		"name": "Wolfpaths", "terrain": "darkwood", "type": "combat",
		"coord": [2, 1], "exits": ["W", "S", "N"],
		"enemies": [
			["wolf", 400, 250, 0, 3], ["wolf", 520, 180, 0, 3], ["wolf", 460, 360, 0, 3], ["wolf", 600, 280, 0, 3],
			["spider", 1250, 950, 1, 3], ["spider", 1380, 880, 1, 3],
			["wolf", 1700, 450, 2, 3], ["wolf", 1820, 560, 2, 3],
			["wolf", 950, 1000, 3, 3], ["spider", 1080, 930, 3, 3], ["spider", 1010, 1080, 3, 3],
		],
		"boss": "",
	},
	{
		"name": "Woodsman's Clearing", "terrain": "darkwood", "type": "social",
		"coord": [2, 2], "exits": ["N", "E"],
		"enemies": [], "boss": "",
	},
	{
		"name": "Ravine Edge", "terrain": "darkwood", "type": "dead_end",
		"coord": [3, 2], "exits": ["W"],
		"enemies": [], "boss": "",
		"npcs": [{"sprite": "rock", "x": 1700, "y": 620, "prompt": "E — Look", "convo": "lore_ravine"},
			# Only in worlds that rolled the boy who's missing it.
			{"sprite": "deadtree", "x": 1440, "y": 880, "prompt": "E — Something in the thorns",
				"convo": "lore_millers_hat", "req_wanderer": "wander_orphan"}],
	},
	{
		"name": "The Deep Darkwood", "terrain": "darkwood", "type": "combat",
		"coord": [2, 0], "exits": ["S", "E", "N"],
		"enemies": [
			["wolf", 450, 350, 0, 3], ["wolf", 580, 420, 0, 3], ["wolf", 500, 550, 0, 3], ["wolf", 650, 300, 0, 3],
			["spider", 1300, 850, 1, 4], ["spider", 1450, 780, 1, 4], ["cultist", 1380, 950, 1, 4, 10],
			["wolf", 1750, 400, 2, 4], ["wolf", 1850, 520, 2, 4],
			["cultist", 900, 1050, 3, 4, 10], ["cultist", 1030, 980, 3, 4, 10], ["cultist", 960, 1120, 3, 4, 10],
		],
		"boss": "",
	},
	{
		"name": "The Moonwell", "terrain": "darkwood", "type": "resonance",
		"coord": [2, -1], "exits": ["S"],
		"enemies": [], "boss": "",
		"npcs": [{"sprite": "crystal", "x": 1056, "y": 500, "prompt": "E — The Moonwell", "convo": "shrine_moonwell"}],
	},
	{
		"name": "Fangmaw's Hollow", "terrain": "darkwood", "type": "boss",
		"coord": [3, 0], "exits": ["W", "E"], "locks": {"E": "boss"},
		"lock_next": "boss",
		"enemies": [["wolf", 700, 400, 0, 4], ["wolf", 850, 330, 0, 4], ["wolf", 780, 520, 0, 4]],
		"boss": "fangmaw", "boss_level": 5,
	},
	# ---------------------------------------------------- the blightmarsh ---
	# The road into the marsh DIPS south through the stilt camp — the
	# merchant sits on the critical path, then it climbs north again.
	{
		"name": "The Marsh Gate", "terrain": "marsh", "type": "combat",
		"coord": [4, 0], "exits": ["W", "S"],
		"enemies": [
			["spider", 480, 300, 0, 4], ["spider", 600, 240, 0, 4], ["spider", 540, 420, 0, 4],
			["cultist", 1300, 900, 1, 4], ["cultist", 1450, 830, 1, 4],
			["wolf", 1750, 500, 2, 4], ["wolf", 1850, 620, 2, 4],
			["spider", 1100, 600, 3, 5], ["spider", 1230, 530, 3, 5], ["spider", 1170, 700, 3, 5],
		],
		"boss": "",
	},
	{
		"name": "Stilt Camp", "terrain": "marsh", "type": "merchant",
		"coord": [4, 1], "exits": ["N", "E"],
		"merchant": [1050, 620], "shop_tier": "silver",
		"enemies": [], "boss": "",
	},
	{
		"name": "The Sunken Path", "terrain": "marsh", "type": "combat",
		"coord": [5, 1], "exits": ["W", "N"],
		"enemies": [
			["spider", 500, 800, 0, 5], ["spider", 640, 880, 0, 5], ["spider", 560, 980, 0, 5],
			["cultist", 1500, 400, 1, 5], ["cultist", 1620, 480, 1, 5],
			["zombie", 1000, 250, 2, 5], ["zombie", 1130, 320, 2, 5], ["zombie", 1060, 180, 2, 5],
		],
		"boss": "",
	},
	{
		"name": "Blightheart Bog", "terrain": "marsh", "type": "combat",
		"coord": [5, 0], "exits": ["E", "S", "N"],
		"enemies": [
			["spider", 450, 300, 0, 5], ["spider", 570, 380, 0, 5], ["spider", 500, 480, 0, 5], ["spider", 640, 300, 0, 5],
			["cultist", 1350, 850, 1, 5], ["cultist", 1500, 900, 1, 5],
			["zombie", 1000, 700, 2, 5],
			["spider", 1700, 350, 3, 6], ["spider", 1820, 280, 3, 6], ["zombie", 1760, 460, 3, 6],
		],
		"boss": "",
	},
	{
		"name": "The Drowned Chapel", "terrain": "marsh", "type": "dead_end",
		"coord": [5, -1], "exits": ["S"], "cache": "silver",
		"enemies": [["zombie", 1000, 500, 0, 5], ["zombie", 1150, 560, 0, 5]],
		"boss": "",
		"npcs": [{"sprite": "tombstone", "x": 950, "y": 320, "prompt": "E — Read", "convo": "lore_drowned_chapel"}],
	},
	{
		"name": "Witchlight Fen", "terrain": "marsh", "type": "combat",
		"coord": [6, 0], "exits": ["W", "E"],
		"enemies": [
			["cultist", 500, 350, 0, 6], ["cultist", 620, 280, 0, 6], ["cultist", 560, 450, 0, 6],
			["cultist", 1300, 880, 1, 6, 12], ["cultist", 1420, 800, 1, 6, 12], ["stormcult", 1350, 980, 1, 7, 12],
			["zombie", 1750, 550, 2, 6], ["zombie", 1850, 650, 2, 6],
			["cultist", 1000, 620, 3, 6], ["zombie", 1130, 550, 3, 6], ["zombie", 1070, 720, 3, 6],
		],
		"boss": "",
	},
	{
		"name": "Morwen's Bower", "terrain": "marsh", "type": "boss",
		"coord": [7, 0], "exits": ["W", "E"], "locks": {"E": "boss"},
		"lock_next": "boss",
		"enemies": [["spider", 700, 450, 0, 6], ["spider", 820, 380, 0, 6]],
		"boss": "morwen", "boss_level": 8,
	},
	# ------------------------------------------------------ vargoth's keep ---
	# The keep climbs: bailey east, then the ward turns NORTH up to the
	# throne approach — the reliquary and throne sit at the map's top.
	{
		"name": "The Outer Bailey", "terrain": "keep", "type": "combat",
		"coord": [8, 0], "exits": ["W", "E", "N", "S"],
		"enemies": [
			["skeleton", 500, 300, 0], ["skeleton", 620, 380, 0], ["skeleton", 540, 480, 0],
			["cultist", 1400, 900, 1, 7], ["cultist", 1520, 820, 1, 7],
			["zombie", 1750, 450, 2, 7], ["zombie", 1850, 570, 2, 7],
			["skeleton", 1050, 950, 3, 7], ["skeleton", 1180, 880, 3, 7], ["skeleton", 1110, 1050, 3, 7],
		],
		"boss": "",
	},
	{
		"name": "The Collapsed Tower", "terrain": "keep", "type": "dead_end",
		"coord": [8, -1], "exits": ["S"], "cache": "silver",
		"enemies": [["skeleton", 1000, 520, 0], ["skeleton", 1150, 580, 0]],
		"boss": "",
		"npcs": [{"sprite": "pillar", "x": 950, "y": 330, "prompt": "E — Search", "convo": "lore_collapsed_tower"}],
	},
	{
		"name": "The Refugee Cellar", "terrain": "keep", "type": "social",
		"coord": [8, 1], "exits": ["N"],
		"enemies": [], "boss": "",
	},
	{
		"name": "The Inner Ward", "terrain": "keep", "type": "combat",
		"coord": [9, 0], "exits": ["W", "S", "N"],
		"enemies": [
			["skeleton", 450, 320, 0, 8], ["skeleton", 570, 250, 0, 8], ["stormcult", 500, 430, 0, 8, 15], ["cultist", 640, 350, 0, 8, 15],
			["cultist", 1400, 850, 1, 8], ["cultist", 1520, 780, 1, 8], ["cultist", 1450, 950, 1, 8],
			["skeleton", 1700, 400, 2, 8], ["skeleton", 1820, 330, 2, 8], ["cultist", 1760, 500, 2, 8],
		],
		"boss": "",
	},
	{
		"name": "The Smugglers' Postern", "terrain": "keep", "type": "merchant",
		"coord": [9, 1], "exits": ["N"],
		"merchant": [1050, 620], "shop_tier": "gold",
		"enemies": [], "boss": "",
	},
	{
		"name": "The Throne Approach", "terrain": "keep", "type": "combat",
		"coord": [9, -1], "exits": ["S", "E", "N"],
		"enemies": [
			["skeleton", 500, 350, 0, 9], ["skeleton", 620, 280, 0, 9], ["skeleton", 560, 460, 0, 9],
			["cultist", 1350, 880, 1, 9], ["cultist", 1470, 800, 1, 9], ["cultist", 1400, 980, 1, 9],
			["zombie", 1750, 500, 2, 9], ["zombie", 1850, 620, 2, 9],
			["skeleton", 1050, 620, 3, 9], ["skeleton", 1180, 550, 3, 9], ["cultist", 1110, 720, 3, 9],
		],
		"boss": "",
	},
	{
		"name": "The Crown Reliquary", "terrain": "keep", "type": "resonance",
		"coord": [9, -2], "exits": ["S"],
		"enemies": [], "boss": "",
		"npcs": [{"sprite": "pillar", "x": 1056, "y": 480, "prompt": "E — The Reliquary", "convo": "shrine_reliquary"}],
	},
	{
		"name": "The Hollow Throne", "terrain": "keep", "type": "boss",
		"coord": [10, -1], "exits": ["W"],
		"enemies": [["skeleton", 700, 420, 0, 9], ["skeleton", 830, 350, 0, 9]],
		"boss": "vargoth", "boss_level": 12,
	},
]

# ------------------------------------------------- social wanderer pool ---
# Social rooms roll ONE wanderer from this pool, seeded per character —
# replays meet different people. Convos live in CONVOS ("wander_*").
const WANDERERS := [
	{"sprite": "villager", "prompt": "E — Talk", "convo": "wander_tinker"},
	{"sprite": "sentry", "prompt": "E — Talk", "convo": "wander_deserter"},
	{"sprite": "villager", "prompt": "E — Talk", "convo": "wander_pilgrim"},
	{"sprite": "archer", "prompt": "E — Talk", "convo": "wander_hunter"},
	{"sprite": "merchant", "prompt": "E — Talk", "convo": "wander_peddler"},
	{"sprite": "villager", "prompt": "E — Talk", "convo": "wander_orphan"},
]

# --------------------------------------------------------------- chapters ---
# The world is built from a CHAPTER: its zone list, starting quest, and
# final boss. Chapter 2 ships as a placeholder hub here — its real
# content arrives through CONTENT_MODULES (see below).

# Chapter 2 zones come entirely from content modules (ch2_hub.gd
# supplies the camp; T2/T3 append the acts). Base list stays empty.
const CH2_ZONES := []

# ---- Endgame arenas (ACT2_DESIGN.md §II) — deliberately kept OUT of
# CHAPTER_LIST so the campaign machinery (chapter select, weekly rotation,
# next_chapter, act gating) never sees them; chapter() below resolves them by
# id. Each is a single-room world the endgame controller (endgame.gd) spawns
# bosses/mobs into. `endgame` marks the world so flows can branch on it; the
# room is `safe` (no authored packs) — the controller owns every spawn.
const ENDGAME_ARENAS := {
	"crucible": {
		"name": "The Crucible",
		"sub": "Ten bosses, back to back. No healing between them. How far can you push?",
		"endgame": true,
		"zones": [{"name": "The Crucible", "terrain": "magma", "type": "safe"}],
		"start_quest": "",
		"final_boss": "",
		"start_pos": [520, 620],
	},
	"depths": {
		"name": "The Waking Depths",
		"sub": "An endless dark that deepens as you go. Descend as far as you dare.",
		"endgame": true,
		"zones": [{"name": "The Waking Depths", "terrain": "graveyard", "type": "safe"}],
		"start_quest": "",
		"final_boss": "",
		"start_pos": [520, 620],
	},
}

const CHAPTERS := {
	"ch1": {
		"name": "Chapter 1: The Hollow King",
		"sub": "A bearer's story — the second fall of Vargoth",
		"zones": ZONES,
		# Seeded procedural layout (playtest round 3: "every run is the
		# same map"). The SPINE lists the boss path in story order; each
		# run lays it out as a seeded east-going walk with N/S jogs, and
		# the side rooms attach to seeded same-terrain hosts. The coords
		# authored in ZONES become the no-spine fallback.
		"spine": [0, 2, 4, 7, 9, 10, 11, 12, 13, 15, 16, 17, 20, 22, 24],
		"loot_cap": "C",  # Act 1 gear ceiling: no S-tier in chapter 1
		"start_quest": "talk",
		"final_boss": "vargoth",
		"start_pos": [280, 624],
	},
	"ch2": {
		"name": "Chapter 2: The Waking",
		"sub": "Years later — the scattered shards choose their bearers",
		"zones": CH2_ZONES,
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch2_start",
		"final_boss": "nullwarden",
		# (The end-screen appends the "journey on" prompt now that ch3+ exist.)
		"victory_text": "The Null Bastion falls silent. The Waking is beaten back — but the shards are still choosing, and the factions are still counting.\nEast of the camps, the Choir's heartland has gone quiet in the wrong way.",
		"start_pos": [180, 360],
	},
	# ---- Act 1 back half (BOSSES.md): zones arrive via content modules
	# (chN_zones.gd appends them). Spines list the boss path in authoring
	# order — each module authors its 13 spine rooms FIRST, side rooms
	# after, so every spine is [0..12]. Loot stays capped at A: S-tier is
	# endgame (Act 2+) loot everywhere in Act 1.
	"ch3": {
		"name": "Chapter 3: The Unburied Vale",
		"sub": "The Choir's heartland — a funeral that never ends",
		"zones": [],
		"spine": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch3_start",
		"final_boss": "saint_varo",
		"victory_text": "Saint Varo lies still, and for the first time in sixty years the Vale is quiet enough to bury someone.\nThe Choir scatters — but far south, the foundry fires are answering something under the rock.",
		"start_pos": [340, 624],
	},
	"ch4": {
		"name": "Chapter 4: The Slagfields",
		"sub": "The Molten Judge stirs beneath the foundries",
		"zones": [],
		"spine": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch4_start",
		"final_boss": "ashpriest",
		"victory_text": "The sermon ends unfinished. The foundries cool — but the verdicts were never Ordo's, and the court beneath the rock is still in session.\nNorth, they say, whole villages have stopped waking up.",
		"start_pos": [340, 624],
	},
	"ch5": {
		"name": "Chapter 5: The Long Sleep",
		"sub": "The Still Queen whispers under the ice",
		"zones": [],
		"spine": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch5_start",
		"final_boss": "sleepkeeper",
		"victory_text": "Halla's hymn fades. The sleepers she gathered will wake or they won't — the ice keeps its own counsel, and the Queen has not stopped dreaming.\nEast, in the deep bog, something has started to GROW.",
		"start_pos": [340, 624],
	},
	"ch6": {
		"name": "Chapter 6: The Blooming Deep",
		"sub": "Where the blight learned to grow",
		"zones": [],
		"spine": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch6_start",
		"final_boss": "curetwisted",
		"victory_text": "The Deep goes still. Whatever the Pale Root wanted with Kaethra, it is looking for a new gardener now.\nOver the Thunder Plains, the sky has begun to tear at the edges.",
		"start_pos": [340, 624],
	},
	"ch7": {
		"name": "Chapter 7: The Breaking Sky",
		"sub": "The last vow-keeper stops mid-sentence — Act 1 finale",
		"zones": [],
		"spine": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
		"loot_cap": "B",  # round 51: Act-1 chest/bag/spoils cap B (A only from ch7 bosses)
		"start_quest": "ch7_start",
		"final_boss": "stormmouth",
		"victory_text": "The recitation ends, six hundred years late — and the sky answers with a sound like the world clearing its throat.\nThe seal is CRACKED. Not open. Cracked. Every power in Vaelscar heard it, and the age you grew up in is over.\n\nACT 1 COMPLETE — the mid game begins.",
		"start_pos": [340, 624],
	},
}

# ------------------------------------------------------ content registry ---
# Chapter 2 content lands as MODULES: scripts under scripts/content/
# (NO class_name — plain scripts) exposing any of these constants:
#   CONVOS         merged into Story.ALL_CONVOS
#   ENEMIES        merged into Story.ALL_ENEMIES
#   QUESTS         merged into Story.ALL_QUESTS
#   CHAPTER_ZONES  {"ch2": [zone dicts]} appended to that chapter's zones
# Register each module with ONE preload line here — that is the only
# shared-file edit a content task ever makes.
const CONTENT_MODULES: Array = [
	preload("res://scripts/content/ch2_hub.gd"),        # (T1) zone 0
	preload("res://scripts/content/ch2_zones_act1.gd"), # (T2) zones 1-4
	preload("res://scripts/content/ch2_zones_act2.gd"), # (T3) zones 5-9
	preload("res://scripts/content/ch2_factions.gd"),   # (T5)
	preload("res://scripts/content/ch2_aldric.gd"),     # (T6)
	preload("res://scripts/content/ch2_bosses.gd"),     # (T4)
	preload("res://scripts/content/ch2_quests.gd"),     # (Q2) Chapter 2 side quests (after the ch2 modules: overrides their convos)
	preload("res://scripts/content/ch3_zones.gd"),      # Unburied Vale chapter (zones/convos/quests)
	preload("res://scripts/content/ch3_bosses.gd"),     # Unburied Vale bosses (BOSSES.md)
	preload("res://scripts/content/ch3_quests.gd"),     # (Q3) Unburied Vale side quests
	preload("res://scripts/content/ch4_zones.gd"),      # Slagfields chapter (zones/convos/quests)
	preload("res://scripts/content/ch4_bosses.gd"),     # Slagfields bosses (BOSSES.md)
	preload("res://scripts/content/ch4_quests.gd"),     # (Q4) Slagfields side quests
	preload("res://scripts/content/ch5_zones.gd"),      # Long Sleep chapter (zones/convos/quests)
	preload("res://scripts/content/ch5_bosses.gd"),     # Long Sleep bosses (BOSSES.md)
	preload("res://scripts/content/ch5_quests.gd"),     # (Q5) Long Sleep side quests
	preload("res://scripts/content/ch6_zones.gd"),      # Blooming Deep chapter (zones/convos/quests)
	preload("res://scripts/content/ch6_bosses.gd"),     # Blooming Deep bosses (BOSSES.md)
	preload("res://scripts/content/ch7_zones.gd"),      # Breaking Sky chapter (zones/convos/quests)
	preload("res://scripts/content/ch7_bosses.gd"),     # Breaking Sky bosses — Act 1 finale (BOSSES.md)
	preload("res://scripts/content/ch1_quests.gd"),     # (Q1) Chapter 1 side quests
	preload("res://scripts/content/ch6_quests.gd"),     # (Q6) Blooming Deep side quests (after ch6_zones: overrides its convos)
	preload("res://scripts/content/ch7_quests.gd"),     # (Q7) Breaking Sky side quests (after ch7_zones: overrides its convos)
	preload("res://scripts/content/pc_extra_mobs.gd"),  # Pixel Crawler asset pass (2026-07-08): 8 extra mobs — roster/codex only, TODO placement
	preload("res://scripts/content/pc_npc_gallery.gd"), # Pixel Crawler asset pass: placeholder NPC convos (humans wired into ch2 hub for review)
	preload("res://scripts/content/pc_bosses.gd"),      # Ninja Adventure sweep (2026-07-08): 6 placeholder bosses — dev-only, TODO real fights
	preload("res://scripts/content/pc_curios.gd"),      # Pixel Crawler mining (2026-07-18): placeholder quest-item curios + codex relics gallery
	preload("res://scripts/content/promises_kept.gd"),  # (P1) promises kept — overrides chN_quests convos
	preload("res://scripts/content/promises_kept_2.gd"),# (P2) promises kept, 2nd pass — MUST stay LAST (after P1: no override fight)
]

static var _content_loaded := false
static var ALL_CONVOS: Dictionary = {}
static var ALL_ENEMIES: Dictionary = {}
static var ALL_QUESTS: Dictionary = {}
static var ALL_BEATS: Dictionary = {}
static var ALL_SIDE_QUESTS: Dictionary = {}
static var ALL_QUEST_ITEMS: Dictionary = {}  # module keepsakes (Items.make_quest_item)
static var ALL_RELICS: Dictionary = {}  # notable world props (codex Curios tab)
static var ALL_WANDERERS: Dictionary = {}  # chapter id -> wanderer pool
static var CHAPTER_LIST: Dictionary = {}
static var _quest_givers: Dictionary = {}   # side-quest id -> Array of convo ids that OFFER it
static var _quest_offers: Dictionary = {}   # convo id -> Array of side-quest ids it can hand out
static var _givers_built := false


## The reverse index of a choice's "side_quest" key, built lazily by scanning
## every convo's choices once — content modules register nothing, because
## authoring the offer IS the wiring. Drives the journal's AVAILABLE list and
## the NPC ❢ marks, both of which must know WHO to point at.
##
## A quest may have SEVERAL givers and both directions are kept: heron_feather
## is offered by the miller's boy AND by two different ways of finding the hat.
## Keeping only the first would leave the other givers unmarked and would test
## the wrong NPC for reachability.
static func _build_quest_givers() -> void:
	if _givers_built:
		return
	load_content()
	_givers_built = true
	for cid in ALL_CONVOS:
		var nodes: Dictionary = ALL_CONVOS[cid].get("nodes", {})
		for nid in nodes:
			var node: Dictionary = nodes[nid]
			for c in node.get("choices", []):
				var offer := String(c.get("side_quest", ""))
				if offer == "":
					continue
				if not _quest_givers.has(offer):
					_quest_givers[offer] = []
				if not _quest_givers[offer].has(String(cid)):
					_quest_givers[offer].append(String(cid))
				if not _quest_offers.has(String(cid)):
					_quest_offers[String(cid)] = []
				if not _quest_offers[String(cid)].has(offer):
					_quest_offers[String(cid)].append(offer)


## Every convo that can hand out this side quest (may be empty).
static func quest_givers(sqid: String) -> Array:
	_build_quest_givers()
	return _quest_givers.get(sqid, [])


## Every side quest this convo can hand out (may be empty).
static func quests_offered_by(convo_id: String) -> Array:
	_build_quest_givers()
	return _quest_offers.get(convo_id, [])


## Merge base content + every registered module. Idempotent; call once
## at boot (Game._ready) before anything reads the ALL_* tables.
static func load_content() -> void:
	if _content_loaded:
		return
	_content_loaded = true
	ALL_CONVOS = CONVOS.duplicate(true)
	ALL_ENEMIES = ENEMIES.duplicate(true)
	ALL_QUESTS = QUESTS.duplicate(true)
	ALL_BEATS = BEATS.duplicate(true)
	ALL_SIDE_QUESTS = SIDE_QUESTS.duplicate(true)
	ALL_RELICS = {}
	ALL_WANDERERS = {}
	CHAPTER_LIST = CHAPTERS.duplicate(true)
	for m in CONTENT_MODULES:
		var consts: Dictionary = m.get_script_constant_map()
		ALL_CONVOS.merge(consts.get("CONVOS", {}), true)
		ALL_ENEMIES.merge(consts.get("ENEMIES", {}), true)
		ALL_QUESTS.merge(consts.get("QUESTS", {}), true)
		ALL_BEATS.merge(consts.get("BEATS", {}), true)
		ALL_SIDE_QUESTS.merge(consts.get("SIDE_QUESTS", {}), true)
		ALL_QUEST_ITEMS.merge(consts.get("QUEST_ITEMS", {}), true)
		ALL_RELICS.merge(consts.get("RELICS", {}), true)
		# Per-chapter social-wanderer pools ({"ch3": [...]}) — chapters
		# without one fall back to the Chapter 1 WANDERERS pool.
		ALL_WANDERERS.merge(consts.get("WANDERERS", {}), true)
		var extra_zones: Dictionary = consts.get("CHAPTER_ZONES", {})
		for chid in extra_zones:
			if CHAPTER_LIST.has(chid):
				CHAPTER_LIST[chid]["zones"] = CHAPTER_LIST[chid]["zones"] + extra_zones[chid]


## The social-wanderer pool for a chapter (module-supplied, else the
## Chapter 1 pool — those convos are road-generic enough to travel).
static func wanderers_for(chid: String) -> Array:
	load_content()
	return ALL_WANDERERS.get(chid, WANDERERS)


static func chapter(id: String) -> Dictionary:
	load_content()
	if ENDGAME_ARENAS.has(id):   # endgame arenas resolve here, never via CHAPTER_LIST
		return ENDGAME_ARENAS[id]
	return CHAPTER_LIST.get(id, CHAPTER_LIST.get("ch1", {}))


## Is this chapter id one of the endgame arenas (The Crucible / Waking Depths)?
static func is_endgame(id: String) -> bool:
	return ENDGAME_ARENAS.has(id)


static func quest_text(key: String) -> String:
	load_content()
	return String(ALL_QUESTS.get(key, ""))


## Boss-door beats read the bearer (2026-07-06): a beat key may author
## variants under "key@flag:x" (story flag set) or "key@band" (resonance
## band). Flag variants outrank band variants; authored order breaks
## flag ties. Keys without variants keep playing the plain beat, and a
## missing key stays [] — exactly the old ALL_BEATS.get contract.
static func beat_for(key: String, band: String, flags: Dictionary) -> Array:
	load_content()
	var prefix := key + "@flag:"
	for k in ALL_BEATS:
		var ks := String(k)
		if ks.begins_with(prefix) and bool(flags.get(ks.substr(prefix.length()), false)):
			var flagged: Array = ALL_BEATS[k]
			return flagged
	if ALL_BEATS.has(key + "@" + band):
		var banded: Array = ALL_BEATS[key + "@" + band]
		return banded
	var plain: Array = ALL_BEATS.get(key, [])
	return plain


## The chapter after this one in campaign order ("" = this is the last).
## Chapters form one PROGRESSION: winning a chapter carries the character
## into the next (game.advance_chapter), and finished chapters stay
## replayable for farming (game.replay_chapter).
static func next_chapter(id: String) -> String:
	load_content()
	var ids: Array = CHAPTER_LIST.keys()
	var i := ids.find(id)
	return String(ids[i + 1]) if i >= 0 and i + 1 < ids.size() else ""


## Which ACT a chapter belongs to (~7 chapters per act — the level
## thirds; DESIGN.md "Acts vs chapters"). Gates the act loot ceilings.
static func act_of(id: String) -> int:
	load_content()
	var i: int = CHAPTER_LIST.keys().find(id)
	return 1 + maxi(i, 0) / 7


# --------------------------------------------------------------- dialogue ---
# Each beat is a list of [speaker, line].

const BEATS := {
	# FALLBACK intro: only reached when a class has no "open_<cls>" convo
	# (game.gd). All six author one, so this is a safety net — but it still
	# has to speak current canon: the player is a SHARD-BEARER, not Aldric.
	"intro": [
		["Narrator", "The kingdom of Emberfall has fallen quiet. Vargoth, once a just king, was buried with honor sixty years ago — then walked again, hollow-eyed, and wore the Ember Crown for sixty more."],
		["Narrator", "Thirty years ago Ser Aldric put a blade through him, and the Crown shattered. It did not scatter into nothing. It scattered into PEOPLE."],
		["You", "And now the blight is climbing out of his keep a second time — and the thing in my chest has started listening."],
	],
	"elder": [
		["Elder Maren", "Bearer! Thank the flame you came. The wolves of the Darkwood grow bold - something twists them from within."],
		["Elder Maren", "A beast they call FANGMAW leads the pack. Slay it, and the road east will be safe again."],
		["Elder Maren", "Take these potions - press Q when your wounds are grave. And remember: keep moving. A still flame is a snuffed one."],
		["You", "I'll return with its pelt, Elder."],
	],
	"elder_repeat": [
		["Elder Maren", "The road east awaits, bearer. May the flame keep you."],
	],
	# Boss doors read the bearer (2026-07-06): "key@flag:x" / "key@band"
	# variants, resolved by Story.beat_for — flag variants outrank band
	# variants; chapters that author none keep playing the plain key.
	"pre_fangmaw": [
		["Narrator", "A monstrous howl shakes the trees. Fangmaw has caught your scent."],
	],
	"pre_fangmaw@tempted": [
		["Narrator", "A monstrous howl shakes the trees. Fangmaw has caught your scent — and the Ember in you rises to answer it, gleeful, like calling to like. You are hunting each other. It would be dishonest to say which of you is happier about it."],
	],
	"pre_fangmaw@steady": [
		["Narrator", "A monstrous howl shakes the trees. Fangmaw has caught your scent. The Ember in your chest holds low and even — a lantern, not a wildfire. The howl breaks off mid-note. It noticed."],
	],
	"post_fangmaw": [
		["Narrator", "Fangmaw falls. The wolves scatter into the trees, their eyes clear for the first time in months."],
		["You", "This rot on its fangs... no natural beast carries that. The blight of the marsh did this."],
		["Narrator", "The gate to the Blightmarsh creaks open. Your health and potions have been restored."],
	],
	"pre_morwen": [
		["Morwen", "Another little candle, come to gutter out in my marsh? The spiders will pick your bones clean, bearer."],
		["You", "Talk less, witch."],
	],
	"pre_morwen@tempted": [
		["Morwen", "Another little candle, come to gutter out in my marsh? ...No. Look at you. Not guttering — LEANING. I know that lean, candle. Mine began exactly so: just a little, toward the warm."],
		["You", "Talk less, witch."],
	],
	"pre_morwen@steady": [
		["Morwen", "A candle that keeps its flame in MY wind? How it must cost you, all that holding. Set it down, candle — the rot asks nothing of anyone. That is its whole mercy."],
		["You", "Talk less, witch."],
	],
	"post_morwen": [
		["Morwen", "You... cannot stop... what has already begun. The Hollow King... rises..."],
		["You", "Then I'll put him back in the ground myself. Again, if that's what it takes."],
		["Narrator", "The witch crumbles to ash. Beyond the marsh, the towers of Vargoth's Keep pierce the grey sky. You feel restored."],
	],
	"pre_vargoth": [
		["King Vargoth", "A piece of me, walking about in someone else's chest... You come for the Crown, little flame?"],
		["King Vargoth", "I wore it for sixty years. It is MINE. Come - kneel before your king."],
		["You", "My king died sixty years ago. You're just what's left."],
	],
	# He FELT the hand on the crown-stand (shrine_reliquary r_hand).
	"pre_vargoth@flag:chose_reliquary_hand": [
		["King Vargoth", "A piece of me, walking about in someone else's chest... You come for the Crown, little flame?"],
		["King Vargoth", "I felt your hand on the stand where it rested. One breath of wanting — but oh, the FIT of you. Sixty years I wore it; you wore it for a heartbeat, and you already know how to kneel. Spare us both the pretending."],
		["You", "My king died sixty years ago. You're just what's left."],
	],
	"pre_vargoth@tempted": [
		["King Vargoth", "A piece of me, walking about in someone else's chest... You come for the Crown, little flame?"],
		["King Vargoth", "I can hear yours whispering from HERE. It promised you small things first, didn't it? Mine did too. Kneel, little flame — and skip the wasted years of telling yourself you don't want the rest."],
		["You", "My king died sixty years ago. You're just what's left."],
	],
	"pre_vargoth@steady": [
		["King Vargoth", "A piece of me, walking about in someone else's chest... You come for the Crown, little flame?"],
		["King Vargoth", "You hold it the way the founders held it. Steady. They knelt in the end, bearer — to me, or to time; it hardly matters which. Everything steady breaks. Come and break."],
		["You", "My king died sixty years ago. You're just what's left."],
	],
	"epilogue": [
		["Narrator", "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones - still warm to the touch."],
		["You", "It's over. The flame returns to Emberfall."],
		["Narrator", "...But deep beneath the keep, something older stirs in its sleep. TO BE CONTINUED IN CHAPTER 2."],
	],
	# The deserter's loop closes (wander_deserter: "be braver than me").
	"epilogue@flag:heard_deserter": [
		["Narrator", "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones - still warm to the touch."],
		["You", "It's over. The flame returns to Emberfall."],
		["Narrator", "Miles west, on a road going nowhere in particular, a ragged soldier stops mid-stride. The stones have gone quiet. He stands a long moment — then turns, at last, toward home."],
		["Narrator", "...But deep beneath the keep, something older stirs in its sleep. TO BE CONTINUED IN CHAPTER 2."],
	],
}

# ------------------------------------------------------------ side quests ---
# Visible wrappers over flag chains (2026-07-06): a convo choice's
# "side_quest" key accepts one (flag sq_on_<id>), each step completes as
# its flag lands, and the reward pays once per run (sq_paid_<id>) the
# moment the last step's flag is set — game_base._check_side_quests.
# Gold rewards scale with level via Balance.daily_gold_mult (the bounty
# rule); "standing" shifts are flat. Run-scoped like all story flags.
# Content modules add their own via a SIDE_QUESTS const.
const SIDE_QUESTS := {
	"heron_feather": {
		"name": "The Heron Feather",
		"chapter": "ch1",
		"desc": "A miller's boy watches the road for a wide-brim hat — brown, heron feather, blue at the tip. His father wore it toward the howling.",
		"steps": [
			{"flag": "hat_taken", "text": "Find the miller's hat, somewhere in the Darkwood"},
			{"flag": "hat_given", "text": "Bring it to the boy at the village edge"},
		],
		"reward": {"gold": 150},
	},
}

const QUESTS := {
	"talk":     "Speak with Elder Maren in the village  (walk up to her and press E)",
	"fangmaw":  "Clear the Darkwood, then slay FANGMAW",
	"morwen":   "Purge the Blightmarsh, then destroy MORWEN",
	"vargoth":  "Cleanse the keep, then face KING VARGOTH",
	"done":     "Chapter 1 complete!",
	"ch2_start": "The camp is quiet — for now. (Chapter 2 content is on its way.)",
}
