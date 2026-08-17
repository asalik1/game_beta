## Chapter closers — per-class animated closing cutscenes (CHAPTER_CLOSERS.md).
## Content module (see README.md): one linear storybook convo per class,
## played on the Cutscene layer when a chapter's final boss dies. Grammar
## (mirror of the openers, minus choices):
##   finish (per class) -> boss's dying lines (shared) -> the fall (shared)
##   -> reflection (per class) -> fade + forward hook (shared).
## Cue ids resolve in cutscene.gd (CLOSER_CHAPTERS): ch1_finish_<class> /
## ch1_reflect_<class> -> one class plate; ch1_fall -> the shared fall plate.
## No branching choices — a closer is a passive cinematic (owner call).
## Wired from game_flow.on_boss_died (solo only for v1; co-op keeps the
## flat epilogue beat). This doc's creative + art-prompt SoT: CHAPTER_CLOSERS.md.

const CONVOS := {
	# ---- ch1: The Hollow King. Vargoth's dying lines land on the campaign's
	# spine — the shard in your chest is a piece of the crown you just broke.
	"ch1_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_warrior", "text": "Your blade finds the hollow of the crown-king, and this time you feel every inch of it — no gap, no blackout, no stranger waking in your boots after. You are awake for all of it.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_warrior", "text": "I remember this one. Every swing. Maybe that's all that stands between him and me — he stopped counting his blows, and woke up a crown. I'll keep counting mine.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},
	"ch1_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_assassin", "text": "You are behind him before the crown can gutter a warning. The Ember takes, the way it always takes — and for once you let it take a king.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_assassin", "text": "It fed on him and left me standing. Grey lips, a cold throne. Sixty years he called that a crown — I've called it a curse since the carter's fire. Same hunger. Only the name changes.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},
	"ch1_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_mage", "text": "The green light leaves your hands one last time — not to mend, but to end. It answers as eagerly as it did the night it scarred a ferrier's boy.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_mage", "text": "The same green that harms, that heals, that ends a king — and I still cannot tell it which it will choose. I promised a mother I would learn what my magic is. A dead king is not the answer. But it's a question I can no longer set down.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},
	"ch1_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_archer", "text": "One arrow, one line drawn taut between you and the throne. You have cut ties before. This is the first you ever cut on purpose — and felt nothing but the release.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_archer", "text": "Every thread I ever cut, I cut running. This one held a whole kingdom to a dead man's fist, and letting it go didn't lighten me. It just left a gate somewhere — still unlatched, still waiting.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},
	"ch1_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_paladin", "text": "The hammer falls, and for once the chain at your heart does not argue the verdict — it only watches a false king answer for sixty stolen years.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_paladin", "text": "GUILTY, the chain said — and this time it was right. That is what frightens me. A false king is easy to judge. What do I do the day it says GUILTY and I agree... of someone who only knelt?", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},
	"ch1_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch1_finish_warlock", "text": "The tome falls open of its own accord, and the debt you never remember signing comes due — all at once, spent on a king who signed his own centuries ago.", "next": "n2"},
		"n2": {"who": "King Vargoth", "text": "A piece of me... walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch1_fall", "text": "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch1_reflect_warlock", "text": "He wore his crown sixty years and called the interest a reign. My tome keeps its books in my own hand, more like me every year. I closed his account today. I still don't know the balance of mine.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."},
	}},

	# ---- ch2: The Waking. The Nullwarden is an ancient iron war-machine at
	# the Bastion's heart, driving the shard-Waking; it does not speak (n2 =
	# Narrator). The shard in your chest woke with the rest — you beat back
	# the thing you are part of. Reflections pay off the openers' "quiet years".
	"ch2_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_warrior", "text": "You set your shoulder behind the last blow and feel the iron heart give — no gap in you this time, no stranger in your boots after. Only the weight of the swing, and the knowing of it.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_warrior", "text": "The Waking stops at the world's edge — and doesn't, quite, in me. The same rousing that woke that machine woke the thing I count my nights against. I beat it back tonight. I finally heard the word for what it is: tonight.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},
	"ch2_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_assassin", "text": "You find the one seam in a mountain of plating, and the Ember drinks the machine's last heat before its grid even registers the theft.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_assassin", "text": "The Waking sulks off; the warmth under my ribs does not. All the quiet years I learned exactly what it takes. Tonight I aimed it at a machine instead of a man — and slept, after. That is the whole of my progress. I will take it.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},
	"ch2_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_mage", "text": "You pour the green light into the iron heart, and the pistons choke on it. A machine cannot be healed — so tonight the light does the other thing it has always known how to do.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_mage", "text": "The blight pulls back a field's width, and somewhere a ferrier's boy is a field's width safer. It is not the cure. It is never the cure. But the promise moved a whole field tonight, and I will walk to the next one tomorrow.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},
	"ch2_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_archer", "text": "One shaft through the one gap in a wall of iron. The thread you cut here runs a hundred miles and ends at the burning edge of the Waking itself.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_archer", "text": "I cut the thread that fed the Waking and felt the old lightness rise — and this time I did not run from it. Maybe that is the ridge road finally ending. Or maybe I just have not reached the next open gate yet.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},
	"ch2_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_paladin", "text": "The hammer rings off the iron once, twice, and on the third the heart splits. The chain at your wrist stays quiet — even it has no verdict to argue against a thing that never chose.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_paladin", "text": "The chain had no sentence for the machine, and that silence unsettled me more than its certainty ever has. It does not judge iron. It is saving itself for people. I will be watching its mouth the day it opens on one.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},
	"ch2_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch2_finish_warlock", "text": "You read the machine's oldest ledger aloud from the tome, and something in the iron that had been servicing a six-hundred-year debt simply stops paying.", "next": "n2"},
		"n2": {"who": "Narrator", "text": "The iron heart seizes mid-turn. For one long breath the whole Bastion holds still — a machine deciding whether the grudge is worth another revolution.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch2_fall", "text": "It is not. The Warden's grid goes dark floor by floor, the pistons falling silent under you — and far off at the world's edge, the Waking stops advancing. The blight sulks. The storms wander off. The hymn at the rim loses a verse.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch2_reflect_warlock", "text": "That engine was still settling accounts older than the kingdom. I closed them. My own ledger feels a page lighter tonight and I cannot say which page — which is exactly the entry the tome would prefer I never go looking for.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Somewhere east, past the maps, four old fires consider their next bearer. The shards are still choosing — and the piece in your chest woke with the rest of them. The road bends to the Unburied Vale."},
	}},

	# ---- ch3: The Unburied Vale. Saint Varo, the man the rot refuses, has
	# begged for death sixty years; his death is a grateful mercy. Reflections
	# pay off each class's opener wound about endings/harm/ties.
	"ch3_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_warrior", "text": "You give the saint the one thing sixty years of clergy would not — a clean, finished ending. You are awake for every second of it, and it is the gentlest blow you have ever struck.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_warrior", "text": "He thanked me. I have swung at a hundred things that screamed; this one thanked me. Maybe an ending isn't the same as the wreckage I wake up in. Maybe some of what I finish is a mercy. I will hold that one carefully.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},
	"ch3_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_assassin", "text": "The refused man does not resist. You give him the clean stranger's death he has begged for, and for once the Ember takes nothing it was not freely handed.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_assassin", "text": "Everything my curse ever took, it stole. He gave. He stood there and gave me the taking, glad of it. I did not know the Ember could be a mercy instead of a theft. I will not forget that it can.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},
	"ch3_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_mage", "text": "The grey mark on every corpse in the Vale is the same grey you gave a boy years ago. Here, at last, the green light meets it and lets it finish. You end the saint the way you have never been able to end the mark.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_mage", "text": "Acres of the grey I carry the guilt of, and I could not cure one inch of it — only let one man past it. Kept is not cured. Ended is not cured. But he is at rest, and the boy is still waiting, and I am still walking.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},
	"ch3_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_archer", "text": "A hundred mourners' threads held the saint to the road, held from the far end. You loose one arrow and cut them all at once, and every hand up the hill lets go a little.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_archer", "text": "I have cut ties my whole life and called it mercy to myself. This is the first time it was mercy to someone else. The Vale can let go now. I still can't, quite. But I watched how it's done.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},
	"ch3_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_paladin", "text": "Sixty years, one petitioner, no verdict — until now. You climb the hill, hear the case from the man himself, and deliver the sentence the Choir refused. The hammer falls, and the chain, for once, does not argue it.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_paladin", "text": "The chain was UNSURE at the top of that hill. I ruled anyway — myself, not it. A false king was easy. A begging saint was not. I judged, and I think I judged right, and I am learning I can tell the difference from the chain's.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},
	"ch3_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch3_finish_warlock", "text": "The Vale's books had been open sixty years, grief compounding, the principal never touched. You close the saint's account with the tome, paid in full, and the whole ledger of the dead can finally rule off.", "next": "n2"},
		"n2": {"who": "Saint Varo", "text": "Sixty years I asked, and you are the only pilgrim who answered. Do you feel it? The rot, coming in at last, like a door unlocking from the inside. Thank you. Oh — thank you.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch3_fall", "text": "Saint Varo does not get up. The rot takes him gently, the way it should have sixty years ago, and his face at the end is nothing but grateful. The endless procession, for the first time, has somewhere to arrive.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch3_reflect_warlock", "text": "A debt sixty years past due, settled in one stroke. The tome purred the whole way up that hill — it thought the Vale was home. I closed the account and walked out. It is very quiet now, my creditor. I trust its quiet even less than its purring.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Choir loses its shame and its shrine in a single grave, and will not forgive it. South, the foundries never bank their fires. The road bends to the Slagfields."},
	}},

	# ---- ch4: The Slagfields. Ashpriest Ordo speaks the Molten Judge's
	# verdict (GUILTY); the fires answer HIM, not the other way. Reflections
	# pay off each class's opener wound about certainty / the Judge / the fire.
	"ch4_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_warrior", "text": "The improved never blink at the fire; you make the chaplain blink at the hammer. One blow, deliberate, certain — the certainty you have wanted your whole life, spent on the man who was selling it.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_warrior", "text": "He was CERTAIN, right to the end. No gaps, no doubts, the fire annealed shut in him. I killed the thing I have envied since I first woke in wreckage. Turns out I would rather keep my gaps than pay his price for closing them.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},
	"ch4_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_assassin", "text": "The furnace takes and hands back receipts; you take and leave grey lips. You put your blade in the man who dressed the same theft in better paperwork, and take back nothing but the quiet.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_assassin", "text": "He robbed a whole city and had them thanking him for the invoice. I know that trade — I run it on myself every night. The difference is I still know it's a robbery. He had forgotten. That is the day I am afraid of: the day I forget too.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},
	"ch4_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_mage", "text": "The blades here stopped failing years ago; your one heal is still failing. You end the priest with the light that never works right — and there is a bitter honesty in it, imperfect work finishing perfect work's prophet.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_mage", "text": "Somewhere below is a technique that does not fail, and I killed the man who would have taught it to me. Morwyn would have wept. I chose the failing green over the flawless fire. I hope the boy would call that the right cowardice.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},
	"ch4_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_archer", "text": "Every rope in the city ran downhill, furnace-ward. You cut the one at the top — the priest himself — and for a breath, nothing in the Slagfields is being pulled anywhere at all.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_archer", "text": "Everything here led one way, down, and I cut the knot at the top of the pull. The freight will find a new hand by morning; threads always do. But the crews walking out tonight are choosing their own direction, and I gave them that. First thread I ever cut that freed somebody.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},
	"ch4_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_paladin", "text": "Three rooms in, the chain went quiet — a junior arbiter before the high judge. You bring the hammer down anyway, on the clerk and not the court, and drag him off the fire's docket by force.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_paladin", "text": "My chain went SILENT before that fire, the way it never does. It knew a bigger judge when it heard one, and it wanted to clerk. I killed the clerk, and the Judge under the rock only turned in its sleep. Two verdicts under one roof was always one too many. I am not sure I removed the wrong one.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},
	"ch4_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch4_finish_warlock", "text": "The tome had not said a word since the Cinder Gate — a small creditor in a great bank's lobby. You open it at the priest, and it finds its voice at last, and calls the man's contract void.", "next": "n2"},
		"n2": {"who": "Ashpriest Ordo", "text": "GUILTY... of course. It was always going to say guilty. I only read what the fire wrote. You think you have silenced the verdict, bearer? You have silenced the CLERK. The Judge under the rock does not need me to go on saying it.", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch4_fall", "text": "Ordo falls mid-sentence, and the fires in the hall lean toward his body like a congregation over a casket — then straighten, go ordinary, and are only fires again. For now. The verdicts were never his.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch4_reflect_warlock", "text": "My tome was AFRAID of that fire. I have never felt my creditor afraid before. I voided one contract, and the lender beneath the foundries did not so much as look up. There is paper down there my book would sell me to sign. I closed the branch office. I did not touch the bank.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The Compact will call it a mad chaplain's end, the foundries safe. You counted what the fires did. North, the ice keeps what the living cannot. The road bends to the Long Sleep."},
	}},

	# ---- ch5: The Long Sleep. Mother Halla gathers the grieving into a
	# frozen sleep and calls it mercy; her death wakes the dreamers to shiver.
	# Reflections pay off each class's opener wound about sleep / the guarantee.
	"ch5_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_warrior", "text": "She never raises a hand — the ice does the holding. You end her with a single clean stroke, awake and grieving every inch of it, and refuse the one guarantee you have ever been offered.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_warrior", "text": "Under that shelf, nobody's hands ever move again — the only leash that never slips. I have wanted that guarantee since the first blackout. I put it down tonight and chose the waking, and the shivering, and the risk. A held sword. Not a buried one.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},
	"ch5_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_assassin", "text": "The vault is the one room where your Ember has nothing to take — everyone kept, nobody spending. You do the taking yourself, once, cleanly, and leave the empty bed empty.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_assassin", "text": "Three days poisoned on a winter road, I would have crawled into that bed and called it mercy. She offered it to me by name. I woke them instead. The tiredest thing I have ever done was walk past a bed that would finally let the Ember rest.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},
	"ch5_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_mage", "text": "The ice keeps fevers paused mid-burn — stopped, never healed. You bring the green light down on the keeper, and it is the whole difference between you: your light, at least, is trying to finish something.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_mage", "text": "She stopped a thousand fevers and cured not one. Cold enough, still enough, and my mark would stop spreading too — I felt how badly I wanted that. Stopping is not undoing. I KNOW that. I woke a hospital of unfinished sentences tonight, so they could go on being written.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},
	"ch5_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_archer", "text": "Every sleeper cut all their threads at once and called it peace; you cut one — the keeper's — and call it the road. The arrow flies true, and the vault begins, thread by thread, to stir.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_archer", "text": "They did all at once what I did one thread at a time — and called it the same word, peace. The difference is smaller than I would like. But there is a road on the far side of my cuts, and there was none on the far side of hers. I woke them into their own winters. Now they get to walk.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},
	"ch5_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_paladin", "text": "The ledgers were lawful, freely signed, and the chain found no fault in them. You overrule the law with the hammer — coercion under famine is coercion still — and void the winter's terms in one blow.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_paladin", "text": "Immaculate paperwork, and my chain wanted to enforce it as written. I ruled that a signature under a starving winter is not consent, and I broke it. My mercy outranked the law tonight. The chain hated that. Good. Let it learn there are courts above its ledger.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},
	"ch5_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch5_finish_warlock", "text": "Sleep now, morning later — the whole faith was a deferral scheme, and the tome respected the craft of it. You call the loan early, at the keeper herself, and the frozen account comes suddenly, terribly, due.", "next": "n2"},
		"n2": {"who": "Mother Halla", "text": "Sshh. Sshh, now. There — it's only the cold, child, it doesn't hurt, I promise you it doesn't. I only ever wanted to stop the waking. Nobody wakes hurting, in the morning I... in the morning...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch5_fall", "text": "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the vault, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch5_reflect_warlock", "text": "A creditor patient enough to freeze centuries — the tome wanted an introduction. I foreclosed on her instead. Somewhere the interest I never see went on compounding while I did it. My book keeps beautiful books. That is the part that keeps me awake, in a world this eager to help me sleep.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "The clans will carry the sleepers to fires and see who rises. Some won't. The ones who do, rise because of you. East now, to the Blooming Deep, where nothing dies at all."},
	}},

	# ---- ch6: The Blooming Deep. Kaethra Cure-Twisted — the cure worked, but
	# the Root filled the empty place the beast left; she frees you as she
	# dies, naming the false choice. Reflections pay off each class's opener
	# wound about growth-without-death / the green / regrowth.
	"ch6_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_warrior", "text": "You broke a sapling at the gate and watched it heal — a place where nothing you break stays broken. You break the one thing that will: the twisted woman at the heart. Awake, deliberate, grieving that it has to stay broken.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_warrior", "text": "Absolution, the counterfeit, and it was very good — a whole country where the blackout could feast and nothing would die. I broke the one thing there that stays broken and refused all the rest. I don't want my gaps grown over. I want them counted. She counted hers, to the very end.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},
	"ch6_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_assassin", "text": "It gives — fruit, shade, mending — and never once reaches into a pocket. You have circled that impossible generosity since the gate. In the end you take the giver, cleanly, and learn what the green charges only as it collects her.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_assassin", "text": "Nothing gives like that without a reason. She found the reason with her own body — the cure was real, and the bill came due behind it, in the empty place where the beast had been. My Ember takes and I always know the price. Hers gave, and she never saw the invoice until it was her name on it. I will keep knowing my price. It is the only thing that has kept me honest.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},
	"ch6_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_mage", "text": "The green light on the waterline is the exact color of your heal. You raise the same green against the woman it also answered — and this time you make it end something, instead of grow it.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_mage", "text": "It was THE green. Not similar — the color my light comes out. It said yes to her and yes to me, and it finished neither of our sentences. She died telling me it was a false choice. I came for the boy's cure and I am leaving with a dead woman's last three words. I don't yet know if they are the answer or only a better question.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},
	"ch6_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_archer", "text": "Nothing here stays cut — vines close behind you, threads regrow by dusk. So you cut the one thing the Deep cannot regrow: the woman holding its door. The arrow lands, and for the first time the green does not mend the wound.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_archer", "text": "Everything I severed in there grew back by morning — everything but her. I have carried one cut thread my whole life, and the Deep quietly offered to regrow it. I said no. What grows back here isn't what was lost; it's what the green remembers of it. Some cuts you keep, so they stay yours.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},
	"ch6_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_paladin", "text": "The Deep acquits everyone — no case, no sentence, the guilty walking out green and glad. You bring the one verdict it never hears to the woman at its heart, and the hammer falls where the green refused to judge.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_paladin", "text": "A mercy that skips the bench entirely — half the flock knelt to it, and my chain went OUTNUMBERED-quiet. She heard the true case where the green would not: cure or acceptance, and she paid full price to prove it a false choice. I ruled tonight. I am no longer certain a verdict is the highest thing a person can offer. She offered more.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},
	"ch6_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch6_finish_warlock", "text": "Growth that only adds, credit that never calls — the Deep ran the tome's own scheme at landscape scale and undercut it. You close the branch by closing its keeper, and your jealous creditor goes quiet with something almost like respect.", "next": "n2"},
		"n2": {"who": "Kaethra Cure-Twisted", "text": "There — you feel it let go? The Root, loosening its grip on the door. The cure WORKED, bearer; the beast is gone; I only couldn't hold what came through the empty place after. Tell them both. Tell them it was a false... a false choice...", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch6_fall", "text": "Kaethra folds into the green, and it takes her the way it takes everything — gently, completely, without letting go. Word runs ahead through the Deep: it's done. At the cure-camp the drums beat mourning; at the pilgrims' rest the Choir sings something old with the certainty gone out of it, which is almost a prayer.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch6_reflect_warlock", "text": "The tome went RIGID with envy at that gate — a rival lender undercutting its rates. She was the one honest signature in the whole green ledger: she read the fine print in her own blood and told me the terms aloud as she died. Two predatory creditors, and the only truth came from the one human being brave enough to audit them. I closed one account today. I have two still open.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Both camps will carry her home together — the first thing they have done as one in a generation. Upward now: the Summit Camp, the relay, and a sky coming apart. The road bends to the Breaking Sky."},
	}},

	# ---- ch7: The Breaking Sky (Act 1 finale). Cyrraeth, the last Speaker,
	# held the storm's sentence — the word was WAIT, not SILENCE. He falls
	# mid-word; the sky CRACKS. Reflections pay off each class's opener wound
	# about the sentence / speech / listening; heavier, act-ending.
	"ch7_closing_warrior": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_warrior", "text": "You know his stillness — it is the stillness before your own gaps, the body quiet and the tenant leaning in. You end it before the door in him opens all the way. One clean stroke, awake where he had stopped being.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_warrior", "text": "Nobody ever warned Cyrraeth about bedposts. He stood at the same door I chain shut every night, and he opened it to listen. I closed it for him — and heard, for one breath, what waits on the far side of the quiet. I have latched my own door tighter than ever. It is not silence in there. It is WAITING.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
	"ch7_closing_assassin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_assassin", "text": "Every seal you ever met was a lock; this one was held by what the speakers GAVE it, freely, forever. You take the last giver the only way the Ember knows, and six centuries of paid-in warmth come loose all at once.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_assassin", "text": "A power sustained by giving — I didn't know that was allowed. Six hundred years of breath and years and lives, paid in gladly, and I ended it with a thing that only ever takes. Everything they gave came loose when he fell. I felt it go past me, and I did not reach for it. That is the closest I have come to giving something back.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
	"ch7_closing_mage": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_mage", "text": "One working, three hundred casters, six hundred years, no error — and your one heal failed inside a breath. You raise the imperfect green against the flawless sentence, and end the most perfect work you have ever seen.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_mage", "text": "It held without error for six centuries. I killed it. Every long spell teaches more in its falling than its standing, Morwyn used to say — so I will read this failure closely, because it is the largest one I have ever caused. Perfect work, finished by hand at last. I am not sure I finished it. I think I only let it fall.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
	"ch7_closing_archer": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_archer", "text": "The relay is the longest thread you have ever seen — six hundred years of voices tied breath to breath, taut as a bowstring, fraying at the near end. You put your arrow through the fraying, and the whole line lets go with a small sound that carries further than the howl after it.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_archer", "text": "I cut the longest thread in the world tonight, and it made the small sound threads make — the one that carries further than any scream. It wasn't holding the god in. It was holding everyone else UP. Now we find out who was leaning on whom. I have never been so unsure a cut was mercy. I made it anyway. That is new, too.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
	"ch7_closing_paladin": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_paladin", "text": "A sentence served not on the guilty but BY the innocent — six centuries of speakers doing time for a god's crime. You strike the writ down with the hammer, and for once the chain does not tell you the verdict; it asks.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_paladin", "text": "Six hundred years of gag-order is not a verdict — it is a filibuster, and I struck it down to hear the case at last. Now the sky is cracked, and the case is enormous, and there is no bench wide enough. The chain asked me what it meant tonight, instead of telling me. I think that means the easy verdicts are over. Good. Those were never the ones that mattered.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
	"ch7_closing_warlock": {"start": "n1", "nodes": {
		"n1": {"who": "Narrator", "cue": "ch7_finish_warlock", "text": "The greatest contract ever executed — no parchment, no seal, six hundred years of enforceable breath — and the counterparty found the flaw: outlive the signatories. You call the performance due on the last mouth still saying it, and the sentence lapses in your favor and everyone's ruin.", "next": "n2"},
		"n2": {"who": "Cyrraeth", "text": "—not silence, you see, that was always the mistranslation... the word was WAIT, and I finally stopped to hear what it was waiting to SAY, and it says — can you hear it now? Behind me? I have held the corner so long. You have the other three. Hold—", "next": "n3"},
		"n3": {"who": "Narrator", "cue": "ch7_fall", "text": "Cyrraeth falls silent mid-word, and for one whole breath nothing in the world makes any sound at all. Then the sky answers. The crack runs horizon to horizon, soundless and absolute, void showing through the storm like bone through a wound — not open. CRACKED. Every hound on the plains sits down at once.", "next": "n4"},
		"n4": {"who": "You", "cue": "ch7_reflect_warlock", "text": "A god bound by the unbroken saying of a sentence. I let it lapse. An unowed god is a god that might deal fresh, I told myself — and now it owes nobody, the sky is open the width of a hair, and the tome has never been so INTERESTED. I broke the finest contract in history tonight. I am beginning to suspect I am being written into a worse one.", "next": "n5"},
		"n5": {"who": "Narrator", "cue": "fade", "text": "Below, eleven camps and two factions look up from what they were doing, and do not look away. This is where Act One ends and the long war for the Waking begins. TO BE CONTINUED."},
	}},
}
