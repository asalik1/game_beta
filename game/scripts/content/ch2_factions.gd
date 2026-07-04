## (T5) Faction arcs: the Ember Accord and the Cinderborn both recruit
## at Maren's camp; joining one locks the other (flag "faction_chosen").
## Wildfang and the Hollow Choir are AMBIENT: standing shifts through
## encounters, no pledging (DESIGN.md Phase Plan).
##
## Arc contract for T2/T3: the first arc step of each faction completes
## when zone content sets these flags —
##   "blight_scouted"  (Accord arc 1: survey the Waking east of camp)
##   "relic_recovered" (Cinderborn arc 1: retrieve an imperial seal)
## Their recruiter convos already carry the follow-up variants.

const QUESTS := {
	"ch2_accord1": "Accord: survey the blighted road east and report what the Waking has taken",
	"ch2_cinder1": "Cinderborn: recover the imperial seal lost on the east road",
}

const CONVOS := {
	# ---- The Ember Accord: destroy the shards, ask people to be less.
	"ch2_accord_recruit": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Callis",
			"text": "Shard-bearer. I won't circle it: the Accord wants every shard gathered and the hollow throne broken for good — yours included, one day, with your consent. We ask people to become LESS so the world can be more. Maren trusts us. Mostly.",
			"variants": [
				{"flag": "joined_accord", "text": "Warden Callis salutes. \"The east road, colleague. The blight will not survey itself — and Vessa's coin-counters would love to beat us to it.\"", "next": ""},
				{"flag": "joined_cinderborn", "text": "\"You wear Vessa's colors now. Then we are done talking, bearer — the Accord does not bargain for what should never be owned.\" She turns back to the palisade.", "next": ""},
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
				{"text": "\"Become LESS? You first, warden.\"",
					"req_band": "tempted", "resonance": -3.0,
					"faction": {"accord": -5}, "next": "a_mock"},
			]},
		"a_join": {"who": "Warden Callis", "text": "Then welcome to the long defeat, colleague — that's Accord humor, you'll learn to survive it. East road. Eyes open. Report what the blight has taken.", "next": ""},
		"a_later": {"who": "Warden Callis", "text": "Sensible. The shards make joiners of some and hermits of others. The offer keeps — the Accord is patient the way stone is patient.", "next": ""},
		"a_mock": {"who": "Warden Callis", "text": "...There it is. The little voice that thinks power should never kneel. I've buried friends who listened to it, bearer. The offer stands anyway — that is the difference between us and it.", "next": ""},
	}},

	# ---- The Cinderborn: order requires a crown; find a worthy head.
	"ch2_cinder_recruit": {"start": "c1", "nodes": {
		"c1": {"who": "Envoy Vessa",
			"text": "Ah — the camp's newest miracle. Envoy Vessa, of the Cinderborn. Before Maren's people fill your ears: we do not miss the tyrant. We miss ROADS. Granaries. Law. A crown is a tool, and Vaelscar is bleeding for the lack of one.",
			"variants": [
				{"flag": "joined_cinderborn", "text": "\"Associate. The seal, when you have it — the east road ate an imperial courier and his satchel, and history is written by whoever holds the paperwork.\"", "next": ""},
				{"flag": "joined_accord", "text": "\"Maren's warden got to you first, I see. A pity — you'd have looked well in better tailoring. Do give the Accord my regards while you're being noble at each other.\"", "next": ""},
			],
			"next": "c2"},
		"c2": {"who": "Envoy Vessa", "text": "Work with us and be paid, protected, and REMEMBERED. First commission: an imperial courier vanished on the east road with a seal of office. Recover it. History belongs to whoever holds the paperwork.",
			"choices": [
				{"text": "\"Roads and granaries. Fine — I'll hear what order pays. I'm in.\"",
					"req_not_flag": "faction_chosen", "resonance": -6.0,
					"flags": {"joined_cinderborn": true, "faction_chosen": true},
					"faction": {"cinderborn": 20, "accord": -10},
					"quest": "ch2_cinder1", "next": "c_join"},
				{"text": "\"Not yet. Crowns and I are having a complicated moment.\"",
					"next": "c_later"},
				{"text": "\"The last crown you people polished got up and walked. No.\"",
					"resonance": 3.0, "faction": {"cinderborn": -5}, "next": "c_refuse"},
			]},
		"c_join": {"who": "Envoy Vessa", "text": "Splendid. A retainer will find you — we pay in coin, not sermons. The seal, associate. East road. Try not to die; the paperwork for that is dreadful.", "next": ""},
		"c_later": {"who": "Envoy Vessa", "text": "Complicated moments pass. Poverty and banditry, historically, do not. You know our colors when you tire of camping.", "next": ""},
		"c_refuse": {"who": "Envoy Vessa", "text": "The last crown was WORN BADLY — a fault of the head, not the hat. But yes, do go tell the Accord how principled you are. They give out so little else.", "next": ""},
	}},

	# ---- Wildfang (ambient): the caged scout the sentries brought in.
	"ch2_beastkin_cage": {"start": "w1", "nodes": {
		"w1": {"who": "Caged Beastkin",
			"text": "The cage holds a wiry beastkin scout — Fangmaw's blood, three generations on. It watches you with too-clever eyes and says nothing. The sentries argue about what to do with it.",
			"variants": [
				{"flag": "cage_resolved", "text": "The cage stands empty now. One of the sentries has planted herbs in it, out of spite or optimism.", "next": ""},
			],
			"next": "w2"},
		"w2": {"who": "Caged Beastkin", "text": "\"Shard-carrier,\" it rasps, finally. \"Your pack or mine — a cage is a cage. The Tribes remember who opens doors. And who watches.\"",
			"choices": [
				{"text": "Open the cage. \"Run before the sentries agree on anything.\"",
					"resonance": 4.0, "flags": {"freed_beastkin": true, "cage_resolved": true},
					"faction": {"wildfang": 10, "accord": -4}, "next": "w_free"},
				{"text": "Pass a waterskin through the bars and say nothing.",
					"flags": {"cage_resolved": true}, "faction": {"wildfang": 4}, "next": "w_water"},
				{"text": "\"The Tribes raid grain carts. Watch, then.\" Walk away.",
					"flags": {"cage_resolved": true}, "faction": {"wildfang": -5}, "next": "w_walk"},
			]},
		"w_free": {"who": "Narrator", "text": "It is over the palisade before the latch stops swinging. From the treeline, one short howl — a NOTE, not a threat. Something out there is keeping accounts.", "next": ""},
		"w_water": {"who": "Narrator", "text": "It drinks without taking its eyes off you, and sets the skin down with strange care. The Tribes remember small doors too.", "next": ""},
		"w_walk": {"who": "Narrator", "text": "The too-clever eyes follow you all the way across the camp. You have been entered into someone's ledger, and not on the generous page.", "next": ""},
	}},

	# ---- Hollow Choir (ambient): a pilgrim chanting outside the gate.
	"ch2_choir_pilgrim": {"start": "h1", "nodes": {
		"h1": {"who": "Choir Pilgrim",
			"text": "A grey-wrapped pilgrim sways by the gate, humming a hymn with no words you know. The sentries won't touch her. \"The rot is honest,\" she says, to no one. \"It only takes what was already leaving.\"",
			"variants": [
				{"flag": "heard_litany", "text": "The pilgrim inclines her head as you pass. \"The Choir keeps a place for those who listened once,\" she murmurs, and returns to the hymn.", "next": ""},
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
		"h_listen": {"who": "Narrator", "text": "The verse is about a garden that stopped pretending. It is beautiful the way a flooded quarry is beautiful, and it stays in your head three days longer than you'd like.", "next": ""},
		"h_rebuke": {"who": "Choir Pilgrim", "text": "\"The garden doesn't mind,\" she says mildly, and keeps humming. Somehow that is worse than an argument.", "next": ""},
	}},
}
