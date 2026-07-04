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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "owned_the_harm", "text": "Aldric. Bren showed me the arm — and told me you KNELT. Those who carry what you carry rarely kneel. Keep that, whatever else you lose."},
				{"flag": "excused_the_harm", "text": "Aldric. 'The wolf isn't — that's what matters.' Bren repeated it, still shaking. I have heard those words before... from the man you have come to kill. Mind yourself."},
				{"flag": "walked_away", "text": "Aldric. You walked past Bren's wreckage without a word. It follows you anyway. Better to face a thing than be trailed by it."},
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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "gave_back", "text": "Aldric. The carter came through at first light — telling anyone who'd listen about the stranger who took his fire, then sat in the snow all night giving it back. Your bloodline usually only takes. Interesting."},
				{"flag": "kept_taking", "text": "Aldric. A carter stumbled in this morning, grey to the elbows, saying the road stole his fire. You look... well-rested. We won't speak of it again. But I will remember it."},
				{"flag": "fled_theft", "text": "Aldric. You came the long way, and cold. Running from what your hands did doesn't starve it — it only teaches it patience."},
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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "told_truth", "text": "Aldric. The ferrier's wife says you promised to UNDO what your magic did — to her face, with the mark still spreading. Mórwyn never once said 'I don't know how.' Hold on to those words."},
				{"flag": "hid_truth", "text": "Aldric. The boy is cool, and his mother sings your praises... and yet the mark on his ribs tells a different spell than the one you described. Careful. That is precisely how it started with HER."},
				{"flag": "left_silent", "text": "Aldric. Coin on the table and a closed door. Half the row thinks you modest; the other half found the mark. Questions do not rot away, spellwright — they ferment."},
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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "said_farewell", "text": "Aldric. A farmer named Ren sent a letter ahead of you. Four words: 'The gate stays unlatched.' Severed bloodlines rarely leave anything standing behind them — you left a DOOR. Keep leaving them."},
				{"flag": "cut_clean", "text": "Aldric. You came in light, drifter — no letters, no ties, nothing to carry. Fangmaw's kin walked that same weightless road all the way to its end. Have a care how light you get."},
				{"flag": "walked_silent", "text": "Aldric. You didn't look back, they say. It follows anyway. The ones who walk from a thing always pack it by accident."},
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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "delivered_verdict", "text": "Aldric. An arbiter who guts a raid, then walks back inside and convicts the man he saved? The chain you carry was FORGED to bind — and you just showed it who holds it. I have waited a long time to meet one of you."},
				{"flag": "spared_guilty", "text": "Aldric. Osric the miller — alive, pardoned, and already hoarding again, they say. The chain told you 'mercy' and you called it your own idea. Learn the difference quickly."},
				{"flag": "recused", "text": "Aldric. You stepped away from the bench rather than test the chain. Prudent. But the chain is patient, arbiter — one day there will be no other judge in the room."},
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
			"text": "Aldric! Thank the flame you came.",
			"variants": [
				{"flag": "closed_tome", "text": "Aldric. I can smell the loan on you from the gate. And yet — it's QUIET. You told it no, didn't you? Keep telling it no. I'll help where I can, and I'll be watching where I can't."},
				{"flag": "borrowed_more", "text": "Aldric. The thing about candles of knowing: they light the room and burn the house. You borrowed again on the road here — don't trouble to deny it, your shadow leans wrong. I'll take your help, warlock. I won't take my eyes off you."},
				{"flag": "burned_pages", "text": "Aldric. Burnt pages, fresh ink. You cannot fire a debt, only the record of it — and the creditor keeps better books than you do. Stay where I can see you."},
			],
			"next": "m2"},
		"m2": {"who": "Elder Maren", "text": "The wolves of the Darkwood grow bold — something twists them from within. A beast they call FANGMAW leads the pack. Slay it, and the road east is safe again.", "next": "m3"},
		"m3": {"who": "Elder Maren", "text": "Take these potions — press Q when your wounds are grave. And keep moving: still things are what the creditor collects first."},
	}},
}

# ---------------------------------------------------------------- enemies ---

# Defensive stats: physres/magres (log-curve reduction), eva (dodge
# chance, countered by DEX), critres (shaves attacker crit chance).
#
# LEVELS & GROWTH: the listed hp/dmg are the monster's stats AT its
# listed "level" (so Chapter 1 balance is unchanged). Away from that
# level they scale by the per-monster GROWTH rates — a wolf gains
# little per level while a boss gains a lot, so a high-level wolf
# is dangerous but a same-level boss dwarfs it. Cap: level 100.
const LEVEL_CAP := 100

const ENEMIES := {
	"wolf":     {"name": "Blighted Wolf",   "sprite": "wolf",     "hp": 34.0,  "dmg": 8.0,  "speed": 155.0, "xp": 12, "gold": 4,  "ranged": false, "scale": 3.0,
		"physres": 5.0,  "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.10, "dmg_g": 0.08},
	"spider":   {"name": "Marsh Spider",    "sprite": "spider",   "hp": 28.0,  "dmg": 6.0,  "speed": 195.0, "xp": 14, "gold": 5,  "ranged": false, "scale": 3.0,
		"physres": 0.0,  "magres": 5.0,  "eva": 0.12, "critres": 0.0, "dmg_type": "phys",
		"level": 2, "hp_g": 0.09, "dmg_g": 0.08},
	"cultist":  {"name": "Blight Cultist",  "sprite": "cultist",  "hp": 40.0,  "dmg": 10.0, "speed": 90.0,  "xp": 20, "gold": 8,  "ranged": true,  "scale": 3.0,
		"physres": 5.0,  "magres": 15.0, "eva": 0.0,  "critres": 0.0, "dmg_type": "magic",
		"level": 4, "hp_g": 0.11, "dmg_g": 0.10},
	"skeleton": {"name": "Hollow Soldier",  "sprite": "skeleton", "hp": 62.0,  "dmg": 14.0, "speed": 120.0, "xp": 24, "gold": 10, "ranged": false, "scale": 3.0,
		"physres": 25.0, "magres": 5.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 7, "hp_g": 0.12, "dmg_g": 0.10},
	"zombie":   {"name": "Risen Corpse",    "sprite": "zombie",   "hp": 45.0,  "dmg": 10.0, "speed": 95.0,  "xp": 15, "gold": 6,  "ranged": false, "scale": 3.0,
		"physres": 12.0, "magres": 0.0,  "eva": 0.0,  "critres": 0.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.10, "dmg_g": 0.09},
	# Bosses: strong base AND strong growth ("dragon-grade" scaling).
	"fangmaw":  {"name": "Fangmaw the Ravener",     "sprite": "direwolf", "hp": 460.0,  "dmg": 15.0, "speed": 130.0, "xp": 80,  "gold": 60,  "ranged": false, "scale": 4.8,
		"physres": 15.0, "magres": 10.0, "eva": 0.08, "critres": 2.0, "dmg_type": "phys",
		"level": 4, "hp_g": 0.14, "dmg_g": 0.11},
	"morwen":   {"name": "Morwen the Blightcaller", "sprite": "witch",    "hp": 620.0,  "dmg": 12.0, "speed": 105.0, "xp": 110, "gold": 90,  "ranged": true,  "scale": 5.5,
		"physres": 10.0, "magres": 35.0, "eva": 0.10, "critres": 3.0, "dmg_type": "magic",
		"level": 7, "hp_g": 0.14, "dmg_g": 0.11},
	"vargoth":  {"name": "King Vargoth the Hollow", "sprite": "king",     "hp": 1000.0, "dmg": 18.0, "speed": 115.0, "xp": 200, "gold": 150, "ranged": false, "scale": 6.5,
		"physres": 40.0, "magres": 25.0, "eva": 0.0,  "critres": 5.0, "dmg_type": "phys",
		"level": 10, "hp_g": 0.15, "dmg_g": 0.12},
}


## A monster's hp/dmg/xp/gold at an arbitrary level (clamped to the cap).
static func enemy_stats_at(kind: String, level: int) -> Dictionary:
	load_content()
	var base: Dictionary = ALL_ENEMIES[kind]
	var lvl := clampi(level, 1, LEVEL_CAP)
	var d := lvl - int(base["level"])
	var hp_m := maxf(0.25, 1.0 + d * float(base["hp_g"]))
	var dmg_m := maxf(0.3, 1.0 + d * float(base["dmg_g"]))
	var reward_m := maxf(0.3, 1.0 + d * 0.12)
	return {"level": lvl, "hp": base["hp"] * hp_m, "dmg": base["dmg"] * dmg_m,
		"xp": int(ceil(base["xp"] * reward_m)), "gold": int(ceil(base["gold"] * reward_m))}

# ------------------------------------------------------------------ zones ---
# Positions are relative to the left edge of each zone.
# The playable area is roughly x 60..1570, y 70..650 (middle rows are the road).

const ZONES := [
	{
		"name": "Emberfall Village", "terrain": "village", "ground": "grass", "path": "dirt",
		"obstacles": ["tree_green", "tree_green", "rock"], "obstacle_count": 9,
		"decor": ["flower", "flower", "pebble"],
		"merchant": [820, 300],
		"enemies": [], "boss": "",
	},
	{
		"name": "The Darkwood", "terrain": "darkwood", "ground": "forest", "path": "dirt",
		"obstacles": ["tree_autumn", "tree_autumn", "rock"], "obstacle_count": 16,
		"decor": ["mushroom", "pebble", "flower"],
		"merchant": [660, 560],
		"enemies": [
			["wolf", 320, 170], ["wolf", 430, 540], ["wolf", 560, 330],
			["wolf", 660, 130], ["wolf", 800, 480], ["wolf", 900, 300],
			["spider", 520, 600], ["spider", 740, 200],
		],
		"boss": "fangmaw",
	},
	{
		"name": "The Blightmarsh", "terrain": "marsh", "ground": "marsh", "path": "dirt",
		"obstacles": ["tree_teal", "deadtree", "rock"], "obstacle_count": 14,
		"decor": ["mushroom", "bones", "pebble"],
		"merchant": [540, 170],
		"enemies": [
			["spider", 300, 200], ["spider", 420, 520], ["spider", 610, 350],
			["spider", 760, 600], ["cultist", 500, 150], ["cultist", 700, 420],
			["cultist", 880, 250], ["wolf", 850, 520],
		],
		"boss": "morwen",
	},
	{
		"name": "Vargoth's Keep", "terrain": "keep", "ground": "stone", "path": "stone",
		"obstacles": ["pillar"], "obstacle_count": 10,
		"decor": ["bones", "crack", "bones"],
		"merchant": [700, 540],
		"enemies": [
			["skeleton", 300, 250], ["skeleton", 430, 500], ["skeleton", 570, 180],
			["skeleton", 700, 380], ["skeleton", 850, 550], ["cultist", 620, 600],
			["cultist", 800, 150],
		],
		"boss": "vargoth",
	},
]

# --------------------------------------------------------------- chapters ---
# The world is built from a CHAPTER: its zone list, starting quest, and
# final boss. Chapter 2 ships as a placeholder hub here — its real
# content arrives through CONTENT_MODULES (see below).

# Chapter 2 zones come entirely from content modules (ch2_hub.gd
# supplies the camp; T2/T3 append the acts). Base list stays empty.
const CH2_ZONES := []

const CHAPTERS := {
	"ch1": {
		"name": "Chapter 1: The Hollow King",
		"sub": "Aldric's story — the fall of Vargoth",
		"zones": ZONES,
		"start_quest": "talk",
		"final_boss": "vargoth",
		"start_pos": [180, 360],
	},
	"ch2": {
		"name": "Chapter 2: The Waking",
		"sub": "Years later — the scattered shards choose their bearers",
		"zones": CH2_ZONES,
		"start_quest": "ch2_start",
		"final_boss": "",
		"start_pos": [180, 360],
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
	preload("res://scripts/content/ch2_factions.gd"),   # (T5)
	preload("res://scripts/content/ch2_aldric.gd"),     # (T6)
	preload("res://scripts/content/ch2_bosses.gd"),     # (T4)
]

static var _content_loaded := false
static var ALL_CONVOS: Dictionary = {}
static var ALL_ENEMIES: Dictionary = {}
static var ALL_QUESTS: Dictionary = {}
static var CHAPTER_LIST: Dictionary = {}


## Merge base content + every registered module. Idempotent; call once
## at boot (Game._ready) before anything reads the ALL_* tables.
static func load_content() -> void:
	if _content_loaded:
		return
	_content_loaded = true
	ALL_CONVOS = CONVOS.duplicate(true)
	ALL_ENEMIES = ENEMIES.duplicate(true)
	ALL_QUESTS = QUESTS.duplicate(true)
	CHAPTER_LIST = CHAPTERS.duplicate(true)
	for m in CONTENT_MODULES:
		var consts: Dictionary = m.get_script_constant_map()
		ALL_CONVOS.merge(consts.get("CONVOS", {}), true)
		ALL_ENEMIES.merge(consts.get("ENEMIES", {}), true)
		ALL_QUESTS.merge(consts.get("QUESTS", {}), true)
		var extra_zones: Dictionary = consts.get("CHAPTER_ZONES", {})
		for chid in extra_zones:
			if CHAPTER_LIST.has(chid):
				CHAPTER_LIST[chid]["zones"] = CHAPTER_LIST[chid]["zones"] + extra_zones[chid]


static func chapter(id: String) -> Dictionary:
	load_content()
	return CHAPTER_LIST.get(id, CHAPTER_LIST.get("ch1", {}))


static func quest_text(key: String) -> String:
	load_content()
	return String(ALL_QUESTS.get(key, ""))


# --------------------------------------------------------------- dialogue ---
# Each beat is a list of [speaker, line].

const BEATS := {
	"intro": [
		["Narrator", "The kingdom of Emberfall has fallen quiet. The Ember Crown - the light that kept the dark at bay - has been stolen."],
		["Narrator", "Vargoth, once a just king, was buried with honor sixty years ago. Now he walks again, hollow-eyed, and a blight spreads from his keep."],
		["Ser Aldric", "I am Aldric, last knight of the Ember Guard. If no one else will go... then I will."],
	],
	"elder": [
		["Elder Maren", "Aldric! Thank the flame you came. The wolves of the Darkwood grow bold - something twists them from within."],
		["Elder Maren", "A beast they call FANGMAW leads the pack. Slay it, and the road east will be safe again."],
		["Elder Maren", "Take these potions - press Q when your wounds are grave. And remember: keep moving. A still knight is a dead knight."],
		["Ser Aldric", "I'll return with its pelt, Elder."],
	],
	"elder_repeat": [
		["Elder Maren", "The road east awaits, Ser Aldric. May the flame keep you."],
	],
	"pre_fangmaw": [
		["Narrator", "A monstrous howl shakes the trees. Fangmaw has caught your scent."],
	],
	"post_fangmaw": [
		["Narrator", "Fangmaw falls. The wolves scatter into the trees, their eyes clear for the first time in months."],
		["Ser Aldric", "This rot on its fangs... no natural beast carries that. The blight of the marsh did this."],
		["Narrator", "The gate to the Blightmarsh creaks open. Your health and potions have been restored."],
	],
	"pre_morwen": [
		["Morwen", "Another little candle, come to gutter out in my marsh? The spiders will pick your bones clean, knight."],
		["Ser Aldric", "Talk less, witch."],
	],
	"post_morwen": [
		["Morwen", "You... cannot stop... what has already begun. The Hollow King... rises..."],
		["Ser Aldric", "Then I'll put him back in the ground myself."],
		["Narrator", "The witch crumbles to ash. Beyond the marsh, the towers of Vargoth's Keep pierce the grey sky. You feel restored."],
	],
	"pre_vargoth": [
		["King Vargoth", "A knight of the Ember Guard... You come for the Crown, little flame?"],
		["King Vargoth", "I wore it for sixty years. It is MINE. Come - kneel before your king."],
		["Ser Aldric", "My king died sixty years ago. You're just what's left."],
	],
	"epilogue": [
		["Narrator", "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones - still warm to the touch."],
		["Ser Aldric", "It's over. The flame returns to Emberfall."],
		["Narrator", "...But deep beneath the keep, something older stirs in its sleep. TO BE CONTINUED IN CHAPTER 2."],
	],
}

const QUESTS := {
	"talk":     "Speak with Elder Maren  (walk up to her and press E)",
	"fangmaw":  "Clear the Darkwood, then slay FANGMAW",
	"morwen":   "Purge the Blightmarsh, then destroy MORWEN",
	"vargoth":  "Cleanse the keep, then face KING VARGOTH",
	"done":     "Chapter 1 complete!",
	"ch2_start": "The camp is quiet — for now. (Chapter 2 content is on its way.)",
}
