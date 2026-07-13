## (P2) Promises kept, second pass — the last two hollow Vale promises.
## Audit (2026-07-07): a sweep of the remaining resonance-shifting
## PROMISES that no flag/quest/beat ever verified. Chapters 2/4/5/6/7 and
## most of 1/3 were already closed by the Q-modules and promises_kept.gd
## (Fenna, Petra, the mute widow, Ansa's criers, Kesh's answer, Sorrel's
## lines, Haim's stone, the deserter's road, etc.). Two Vale loops were
## still open, and both hinge on the SAME deed the world already records —
## Vess the Unburied dead ("vess_dead"), the liturgy silenced, the sixty-
## year burial ban lifted:
##
##   Brother Osk (ch3_wander_defector) — you told him the unburied count
##     "is going to need a number when the burying starts." It never went
##     down. Now, once the aisle goes quiet, the count MOVES — he can show
##     you the struck figure in ink. The larger resonance moved to that
##     delivery; the words keep a small nudge (3.0 -> 2.0), promises_kept
##     philosophy.
##
##   The Kneeling Field (chose_told_congregation) — you told a field of
##     the faithful you weren't robbing their saint, you were RETURNING
##     him to himself. The flag was set and read by nothing. Now the ch3
##     epilogue keeps that word: the congregation climbs the hill and sees
##     the returning for itself (beat variant epilogue_ch3@flag:...).
##
## No zone edits: both deed-flags already exist (vess_dead is the Silent
## Aisle's clear_flag; epilogue_ch3 is the chapter's own finale beat).
## Registered AFTER promises_kept.gd; overrides only ch3_wander_defector,
## which promises_kept does NOT own — no override fight.

# --------------------------------------------------------------- beats ---
const BEATS := {
	# The kneeling field's claim, kept at the saint's grave. Base
	# epilogue_ch3 is copied verbatim; one Narrator beat and one reworked
	# Ilse line pay off the promise, then the plain Slagfields hook closes.
	"epilogue_ch3@flag:chose_told_congregation": [
		["Narrator", "Saint Varo does not get up. The rot takes him gently, at last, like a door unlocking from the inside — and his face, at the end, is nothing but grateful."],
		["Narrator", "The kneeling field below the cathedral does not scatter. They came to watch their saint stolen — they told you so, on their knees — and you told them back it was a RETURNING, not a taking. Now they climb the hill to check the arithmetic of it, and find a man given, finally, to himself. The young voice that once admitted 'he does scream at night, we sing over it' is the first to kneel at the grave instead of the shrine. Nobody sings. For once the Vale lets a silence stand where a hymn used to be."],
		["Cantor Ilse", "You promised a field of the faithful you weren't here to rob them — and then you went up and made it TRUE. That's rarer than the mercy. They'll raise no shrine to this one; there's nothing left to venerate but a filled grave. But they'll tell it exactly as it happened, bearer: returned, not taken. The Choir loses its shame and its shrine in a single blow, and every soul on that hill knows whose hand freed him."],
		["Narrator", "South of the Vale, the horizon glows the wrong color for sunset. The foundries of the Slagfields are running day and night now — and something under them has started answering the hammers."],
	],
}

const CONVOS := {
	# OVERRIDES ch3_zones.gd's "ch3_wander_defector" (Brother Osk — the
	# defector who left the Choir over its refusal to COUNT). Verbatim copy,
	# extended: the promise nudge drops 3.0 -> 2.0, and a vess_dead delivery
	# variant (listed before the flavor variants — first match wins) routes
	# to f_down, where the promise the words made becomes a struck figure in
	# the ledger. The larger resonance (3.0) lands on acknowledging it. Once
	# acknowledged, ch3_osk_counted holds the ongoing "still falling" state.
	"ch3_wander_defector": {"start": "f1", "nodes": {
		"f1": {"who": "Brother Osk (formerly)",
			"text": "I keep the count. Fourteen thousand, two hundred and six unburied, gate to cathedral. The Choir never counted — counting implies you might one day FINISH. I left over the counting. It seemed a small thing to leave a faith over, until I understood it was the whole faith.",
			"variants": [
				# Scorned state first (first match wins): the count was called
				# ink to his face — he keeps it anyway, quieter.
				{"flag": "ch3_osk_scorned", "text": "Fourteen thousand, one hundred and seventy-nine — down twenty-seven since the aisle went quiet. I write the falling number and say nothing to the man who called it ink. Ledgers, bearer, outlast opinions of them.", "next": ""},
				# Ongoing state, after the count's been witnessed together.
				{"flag": "ch3_osk_counted", "text": "Fourteen thousand, one hundred and seventy-nine — down twenty-seven since the aisle went quiet, and every figure of it a grave dug and filled the same day, the old way. I keep the ledger open to the falling page some mornings just to look at a number that MOVES the right direction. Nineteen years I couldn't. You gave me a smaller one to write, bearer.", "next": ""},
				# Delivery: the singing stopped, and the impossible number moves.
				{"flag": "vess_dead", "text": "You're back — and you'll want to SEE this, of all people. The aisle's gone quiet up the hill; word of whose hand did it reached even a counter's corner. And down here the thing that couldn't happen is happening: the count is moving. Come read the ledger, bearer. The one you told me to keep.", "next": "f_down"},
				{"band": "tempted", "text": "Fourteen thousand two hundred six. ...You carry something that likes big numbers, bearer. I can hear it liking mine. Walk on, please — and don't let it do the counting for you."},
				{"flag": "ch3_osk_met", "text": "The count stands. It will go DOWN soon, for the first time — I find I don't know how to write a number getting smaller. Good problem. Sixty years since the Vale had a good problem.", "next": ""}],
			"choices": [
				{"text": "\"Keep counting, brother. Every one of them is going to need a number when the burying starts.\"",
					"resonance": 2.0, "flags": {"ch3_osk_met": true}, "next": "f_keep"},
				{"text": "\"Keep your ledger, brother. The Vale needs a blade this week, not a bookkeeper.\"",
					"resonance": -3.0, "flags": {"ch3_osk_met": true}, "next": "f_blade"},
			]},
		"f_keep": {"who": "Brother Osk (formerly)", "text": "When the burying starts. You say it like weather — like it's simply COMING. ...I believe I'll keep the ledger open at today's page. It deserves to see this.", "next": ""},
		"f_blade": {"who": "Brother Osk (formerly)", "text": "The Choir said nearly the same thing, bearer — 'the faith needs voices, not sums.' Everything out here that went mad went mad the day it stopped counting what it cost. ...Go swing your blade. I'll write down what it comes to. Somebody always has to.", "next": ""},
		# ---- The count, going down: the promise kept, in ink. Reachable off
		# the vess_dead variant whether or not you ever made the words — the
		# DEED (the aisle silenced) is what the world checks, and it did.
		"f_down": {"who": "Brother Osk (formerly)",
			"text": "He turns the ledger so you can read it. The last standing line is FOURTEEN THOUSAND TWO HUNDRED AND SIX — struck through, twice, and under it in a hand that shook: FOURTEEN THOUSAND ONE HUNDRED AND NINETY-ONE. \"Fifteen,\" he says. \"Fifteen closed since the singing stopped, dug and filled the same day, the way I did before it all went mad. Nineteen years I have ADDED to this count. I have never once had cause to subtract. ...You said it like weather, bearer — like the burying was simply coming. It wasn't coming. It was WAITING. On somebody to make the aisle go quiet.\"",
			"choices": [
				{"text": "\"Then keep subtracting, brother. It's the only honest direction a grief-count ever ran.\"",
					"req_not_flag": "ch3_osk_counted", "resonance": 3.0,
					"flags": {"ch3_osk_counted": true}, "next": "f_thanks"},
				{"text": "\"It's ink, brother. The dead don't read. Spend the thanks on a spade.\"",
					"req_not_flag": "ch3_osk_counted", "resonance": -4.0,
					"flags": {"ch3_osk_counted": true, "ch3_osk_scorned": true}, "next": "f_ink"},
			]},
		"f_ink": {"who": "Brother Osk (formerly)", "text": "\"Ink.\" He looks at the struck figure a long moment, then closes the ledger with both hands, gently, the way the Vale never got to close anything. \"The dead don't read. No. But the living count, bearer — it's the one thing grief and empire agree on. You turned this number with your own hand, and you'd rather it were nothing.\" He tucks the book away. \"I'll subtract quietly, then. It goes down either way.\"", "next": ""},
		"f_thanks": {"who": "Brother Osk (formerly)", "text": "\"The only honest direction.\" He writes it in the ledger's margin — real words, beside the falling number. \"Sixty years the Vale kept this count going one way, and called that faith. You turned it, and left me holding the pen. When the histories ask who ended the funeral, there'll be a figure under the answer, getting smaller by the day. I'll see to that. It's the one thing I was ever any good at.\"", "next": ""},
	}},
}
