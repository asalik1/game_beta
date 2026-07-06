## Chapter 6 zones — The Blooming Deep (bog + spore, L33-37, BOSSES.md).
## Content module: 21 rooms — 13 spine (spine = [0..12]) + 8 side. The
## FIRST BLENDED chapter: bog and spore rooms interleave — the blight
## kills things, and in the deep bog its GREEN twin has started making
## things grow. Wrong, huge, and permanently. The blend is the story.
##
## THE CHAPTER: the Pale Root's seal. Hollow Choir pilgrims arrive
## expecting holy rot and find its opposite — their crisis of faith is
## the social content. Wildfang's cure-seeker camp is here too, because
## pure growth looks like a cure from a distance. Their leader Kaethra
## tested it the only ethical way: on herself. It worked. Read that
## sentence again. The chapter ends with her, and the fight ends with
## a CHOICE (ch6_kaethra_end — wired into boss.gd's 10% finale).
##
## XP BUDGET (30+22·lvl; enter ~L33.8 off Halla):
##   -> Auroch L34 (~140): opener trash ~260
##   -> Rotmaw L35 (800, Auroch pays 520): trash ~370
##   -> Kaethra L37 (1666, Rotmaw pays 560): trash ~920
## Full-clear trash below ≈ 1545 + bosses 1800. Needs a playtest pass.

const CHAPTER_ZONES := {
	"ch6": [
		# ---------------------------------------------------- spine ---
		{
			"name": "The Pilgrim Gate", "terrain": "bog", "type": "safe",
			"lock_next": "flag:ch6_briefed",
			"merchant": [1050, 480], "shop_tier": "silver",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "choirmother", "x": 620, "y": 500, "prompt": "E — Deacon Vela", "convo": "ch6_briefing"},
				{"sprite": "beastkin", "x": 1400, "y": 400, "prompt": "E — Herbalist Kesh", "convo": "ch6_wildfang"},
				{"sprite": "warden", "x": 1500, "y": 760, "prompt": "E — Accord", "convo": "ch6_accord"},
				{"sprite": "villager", "x": 800, "y": 800, "prompt": "E — Talk", "convo": "ch6_fisher"},
			],
		},
		{
			"name": "The Green Fringe", "terrain": "bog", "type": "combat",
			"enemies": [
				["bog_lurker", 480, 300, 0], ["bog_lurker", 600, 240, 0], ["bog_lurker", 540, 420, 0],
				["bog_lurker", 1300, 900, 1], ["bog_lurker", 1420, 830, 1], ["bog_lurker", 1350, 1000, 1],
				["bog_lurker", 1700, 400, 2], ["bog_lurker", 1820, 500, 2],
				["bog_lurker", 950, 620, 3], ["bog_lurker", 1080, 550, 3],
			],
			"boss": "",
		},
		{
			"name": "The Drowned Meadow", "terrain": "spore", "type": "combat",
			"enemies": [
				["bog_lurker", 450, 320, 0, 34], ["bog_lurker", 570, 250, 0, 34], ["bog_lurker", 510, 440, 0, 34],
				["root_shambler", 1350, 850, 1], ["root_shambler", 1470, 780, 1],
				["bog_lurker", 1700, 450, 2, 34], ["bog_lurker", 1820, 560, 2, 34],
				["root_shambler", 1000, 950, 3], ["root_shambler", 1130, 880, 3],
			],
			"boss": "",
		},
		{
			"name": "The Wallow", "terrain": "bog", "type": "boss",
			"lock_next": "boss",
			"enemies": [["bog_lurker", 700, 400, 0, 34], ["bog_lurker", 850, 330, 0, 34]],
			"boss": "auroch", "boss_level": 34,
		},
		{
			"name": "The Spore Terraces", "terrain": "spore", "type": "combat",
			"enemies": [
				["bloom_acolyte", 480, 300, 0], ["bloom_acolyte", 600, 240, 0], ["bloom_acolyte", 540, 430, 0],
				["root_shambler", 1350, 880, 1, 35], ["root_shambler", 1470, 800, 1, 35],
				["bloom_acolyte", 1700, 420, 2], ["bloom_acolyte", 1820, 530, 2],
				["root_shambler", 1000, 620, 3, 35], ["root_shambler", 1130, 550, 3, 35],
				["bog_lurker", 950, 750, 3, 35], ["bog_lurker", 1060, 820, 3, 35],
			],
			"boss": "",
		},
		{
			"name": "The Pilgrims' Rest", "terrain": "spore", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Choked Canal", "terrain": "bog", "type": "combat",
			"enemies": [
				["root_shambler", 450, 320, 0, 35], ["root_shambler", 570, 250, 0, 35], ["root_shambler", 510, 440, 0, 35],
				["root_shambler", 640, 350, 0, 35], ["root_shambler", 700, 260, 0, 35],
				["bloom_acolyte", 1350, 850, 1, 35], ["bloom_acolyte", 1470, 780, 1, 35],
				["bloom_acolyte", 1420, 950, 1, 35], ["bloom_acolyte", 1540, 880, 1, 35],
				["bog_lurker", 1750, 420, 2, 35], ["bog_lurker", 1850, 520, 2, 35], ["bog_lurker", 1800, 320, 2, 35],
			],
			"boss": "",
		},
		{
			"name": "The Garden", "terrain": "spore", "type": "boss",
			"lock_next": "boss",
			"enemies": [["bloom_acolyte", 700, 420, 0, 35], ["bloom_acolyte", 830, 350, 0, 35]],
			"boss": "gardener", "boss_level": 35,
		},
		{
			"name": "The Blooming Road", "terrain": "spore", "type": "combat",
			"enemies": [
				["bloom_acolyte", 480, 300, 0, 36], ["bloom_acolyte", 600, 240, 0, 36], ["bloom_acolyte", 540, 430, 0, 36],
				["bloom_acolyte", 660, 340, 0, 36], ["bloom_acolyte", 720, 250, 0, 36],
				["grove_horror", 1350, 880, 1], ["grove_horror", 1470, 800, 1],
				["grove_horror", 1410, 980, 1], ["grove_horror", 1530, 900, 1],
				["root_shambler", 1750, 420, 2, 36], ["root_shambler", 1850, 530, 2, 36],
			],
			"boss": "",
		},
		{
			"name": "The Cure-Seekers' Camp", "terrain": "bog", "type": "merchant",
			"merchant": [1050, 620], "shop_tier": "gold",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Overgrowth", "terrain": "spore", "type": "combat",
			"enemies": [
				["grove_horror", 480, 300, 0, 36], ["grove_horror", 600, 240, 0, 36], ["grove_horror", 540, 430, 0, 36],
				["grove_horror", 660, 340, 0, 36], ["grove_horror", 720, 250, 0, 36], ["grove_horror", 780, 340, 0, 36],
				["bloom_acolyte", 1350, 880, 1, 36], ["bloom_acolyte", 1470, 800, 1, 36],
				["bloom_acolyte", 1410, 980, 1, 36], ["bloom_acolyte", 1530, 900, 1, 36],
				["bog_lurker", 1000, 620, 3, 36], ["bog_lurker", 1130, 550, 3, 36],
			],
			"boss": "",
		},
		{
			"name": "The Root Vault", "terrain": "bog", "type": "combat",
			"enemies": [
				["root_shambler", 480, 300, 0, 36], ["root_shambler", 600, 240, 0, 36], ["root_shambler", 540, 430, 0, 36],
				["root_shambler", 660, 340, 0, 36], ["root_shambler", 720, 250, 0, 36],
				["bloom_acolyte", 1350, 880, 1, 36], ["bloom_acolyte", 1470, 800, 1, 36],
				["bloom_acolyte", 1410, 980, 1, 36], ["bloom_acolyte", 1530, 900, 1, 36], ["bloom_acolyte", 1590, 810, 1, 36],
				["grove_horror", 1750, 420, 2, 36], ["grove_horror", 1850, 530, 2, 36],
			],
			"boss": "",
		},
		{
			"name": "The Heart of the Bloom", "terrain": "spore", "type": "boss",
			"enemies": [["grove_horror", 700, 420, 0, 36], ["grove_horror", 830, 350, 0, 36]],
			"boss": "curetwisted", "boss_level": 37,
		},
		# ----------------------------------------------- side rooms ---
		{
			"name": "The Sunken Shrine", "terrain": "bog", "type": "dead_end", "cache": "wood",
			"enemies": [["root_shambler", 1000, 500, 0, 35], ["root_shambler", 1150, 560, 0, 35]],
			"boss": "",
			"npcs": [{"sprite": "tombstone", "x": 950, "y": 320, "prompt": "E — Read", "convo": "ch6_lore_shrine"}],
		},
		{
			"name": "The Cure Pool", "terrain": "spore", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "crystal", "x": 1056, "y": 500, "prompt": "E — The Cure Pool", "convo": "ch6_shrine_pool"}],
		},
		{
			"name": "The Listing Watchtower", "terrain": "bog", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Fen of Lights", "terrain": "bog", "type": "combat",
			"enemies": [
				["bog_lurker", 500, 320, 0, 34], ["bog_lurker", 620, 250, 0, 34], ["bog_lurker", 560, 440, 0, 34],
				["bog_lurker", 680, 350, 0, 34], ["bog_lurker", 740, 260, 0, 34],
				["root_shambler", 1350, 850, 1, 34], ["root_shambler", 1470, 780, 1, 34],
				["root_shambler", 1420, 950, 1, 34], ["root_shambler", 1540, 870, 1, 34],
			],
			"boss": "",
		},
		{
			"name": "The Nursery", "terrain": "spore", "type": "combat",
			"enemies": [
				["bloom_acolyte", 500, 320, 0, 36], ["bloom_acolyte", 620, 250, 0, 36],
				["bloom_acolyte", 560, 440, 0, 36], ["bloom_acolyte", 680, 350, 0, 36], ["bloom_acolyte", 740, 260, 0, 36],
				["grove_horror", 1350, 850, 1, 36], ["grove_horror", 1470, 780, 1, 36],
				["grove_horror", 1420, 950, 1, 36], ["grove_horror", 1540, 870, 1, 36],
			],
			"boss": "",
		},
		{
			"name": "The Pale Gallery", "terrain": "spore", "type": "dead_end", "cache": "silver",
			"enemies": [],
			"boss": "",
			"npcs": [{"sprite": "deadtree", "x": 950, "y": 330, "prompt": "E — Look", "convo": "ch6_lore_gallery"}],
		},
		{
			"name": "The Pilgrims' Schism", "terrain": "bog", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "cultist", "x": 1056, "y": 500, "prompt": "E — The Schism", "convo": "ch6_shrine_schism"}],
		},
		{
			"name": "The Strangled Grove", "terrain": "bog", "type": "combat",
			"enemies": [
				["grove_horror", 500, 320, 0, 36], ["grove_horror", 620, 250, 0, 36],
				["grove_horror", 560, 440, 0, 36], ["grove_horror", 680, 350, 0, 36],
				["root_shambler", 1350, 850, 1, 36], ["root_shambler", 1470, 780, 1, 36],
				["root_shambler", 1420, 950, 1, 36], ["root_shambler", 1540, 870, 1, 36],
			],
			"boss": "",
		},
	],
}

# Blooming Deep monsters. HP on the gear-inclusive dps curve, dmg on
# the parity curve (in-game = base x 1.3).
const ENEMIES := {
	"bog_lurker": {"name": "Bog Lurker", "sprite": "spider", "hp": 620.0, "dmg": 72.0, "speed": 200.0, "xp": 13, "gold": 26, "ranged": false, "scale": 3.2,
		"physres": 12.0, "magres": 22.0, "eva": 0.12, "critres": 0.0, "dmg_type": "phys",
		"level": 33, "hp_g": 0.10, "dmg_g": 0.09,
		"lore": "The bog's old ambush hunters, grown a size past their name. The Root feeds everything, including the things that feed on you."},
	"root_shambler": {"name": "Root Shambler", "sprite": "zombie", "hp": 750.0, "dmg": 76.0, "speed": 105.0, "xp": 14, "gold": 26, "ranged": false, "scale": 3.4,
		"physres": 30.0, "magres": 30.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 34, "hp_g": 0.11, "dmg_g": 0.09,
		"lore": "The bog's drowned dead, re-rooted and walking. The blight would have let them rot. The Root had other plans, and worse taste."},
	"bloom_acolyte": {"name": "Bloom Acolyte", "sprite": "cultist", "hp": 680.0, "dmg": 80.0, "speed": 100.0, "xp": 16, "gold": 28, "ranged": true, "scale": 3.2,
		"physres": 12.0, "magres": 45.0, "eva": 0.0, "critres": 2.0, "dmg_type": "magic",
		"level": 35, "hp_g": 0.11, "dmg_g": 0.10,
		"lore": "Choir pilgrims who came for holy rot, saw the Blooming, and converted on the spot. Faith that flips once flips easy — Rotmaw taught them where to aim it."},
	"grove_horror": {"name": "Grove Horror", "sprite": "beastkin", "hp": 880.0, "dmg": 84.0, "speed": 140.0, "xp": 17, "gold": 30, "ranged": false, "scale": 3.6,
		"physres": 40.0, "magres": 25.0, "eva": 0.0, "critres": 3.0, "dmg_type": "phys",
		"level": 36, "hp_g": 0.11, "dmg_g": 0.09,
		"lore": "Something that walked into the deep grove on two legs. The Root never subtracts — it only adds, and adds, and adds."},
}

const QUESTS := {
	"ch6_start": "Report to Deacon Vela at the Pilgrim Gate  (walk up to her and press E)",
	"auroch": "Cross the green fringe — put THE DROWNED AUROCH back under",
	"gardener": "Cut through the canal and weed ROTMAW's garden",
	"curetwisted": "Reach the heart of the Bloom — face KAETHRA CURE-TWISTED",
	"done_ch6": "The Deep goes still. Over the Thunder Plains, the sky is tearing...",
}

const BEATS := {
	"pre_auroch": [
		["Narrator", "The wallow stinks of pond-rot and, impossibly, of clover. Something the size of a granary shifts beneath the water — the bog-bull that drowned a century ago and took it as advice."],
		["Narrator", "It is not angry. It has not been anything in a hundred years. It is a weather system with horns, and you are standing in its season."],
	],
	"post_auroch": [
		["Narrator", "The Auroch settles into the wallow one last time, and the bog accepts it the way it accepts everything — patiently. For a moment the water goes mirror-still, and in it you see the wrongness plainly: every reed at the waterline is BLOOMING, out of season, out of sense."],
		["Narrator", "Deeper in, someone has planted the poison in rows. Rows mean a gardener."],
	],
	"pre_gardener": [
		["Rotmaw the Gardener", "Sandal-steps on my beds — a VISITOR. Mind the seedlings, they're at a delicate age. Do you garden, bearer? No? You clear. I can tell by the shoulders. Everyone who comes here clears."],
		["Rotmaw the Gardener", "I preached rot for thirty years — the land's one honest truth. Then I saw the Blooming, and understood: rot is only the truth SLEEPING. This garden is what it dreams. Kneel and I'll show you the roots. One way or another."],
	],
	"post_gardener": [
		["Narrator", "Rotmaw folds into his own beds, and the garden — deprived of its deacon — begins, very slowly, to eat itself. Even his converts stand baffled: the blooms they worshipped this morning are compost by dusk. Faith that flips once flips easy. Faith that flips twice just breaks."],
		["Narrator", "From the deep grove, drumbeats: the Wildfang cure-camp's summons rhythm — three beats, then silence — the pattern that means COME AND SEE, and also means WE ARE SO SORRY."],
	],
	"pre_curetwisted": [
		["Kaethra Cure-Twisted", "Stop. Before anything happens, you will hear it from ME, plainly, while the words are still mine to choose: the cure works. The beast in my blood is gone. Gone, bearer. I checked for a month before I let myself believe it."],
		["Kaethra Cure-Twisted", "Then I checked what was holding the door where the beast had been. ...Both camps sent for you, didn't they. First thing they've agreed on in a generation. Come, then — the Root is very interested in meeting you, and I can't hold its arm much longer."],
	],
	"epilogue_ch6": [
		["Narrator", "Word runs ahead of you back through the Deep: it's done. At the cure-camp the drums beat the mourning rhythm, and at the pilgrims' rest the Choir faithful sing something old and unsure — a liturgy with the certainty gone out of it, which is almost a prayer."],
		["Herbalist Kesh", "Both camps will carry her home together — first thing we've done together in a generation, and it took THIS. 'Cure or acceptance.' We built a whole people on that question, bearer. She's the answer: it was a false choice, and she paid full price for asking honestly."],
		["Narrator", "The Blooming stalls with no one left to want it. And north, over the Thunder Plains, the horizon flickers — not lightning. The sky itself, tearing at the edges, void showing through the storm. The last seal is straining, and the last chapter of the early roads begins."],
	],
}

const WANDERERS := {
	"ch6": [
		{"sprite": "cultist", "prompt": "E — Talk", "convo": "ch6_wander_convert"},
		{"sprite": "choirmother", "prompt": "E — Talk", "convo": "ch6_wander_doubter"},
		{"sprite": "beastkin", "prompt": "E — Talk", "convo": "ch6_wander_scout"},
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch6_wander_fisher"},
		{"sprite": "warden", "prompt": "E — Talk", "convo": "ch6_wander_botanist"},
	],
}

const CONVOS := {
	# ---- Deacon Vela: a Choir leader whose flock walked into the one
	# thing their faith can't digest. Reads ch5's chose_ flags.
	"ch6_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Deacon Vela",
			"text": "A shard-bearer, at OUR gate. The flame has a sense of humor after all. Vela — deacon of the pilgrimage, or of what the Deep has left of it. Before you size up my grey habit and decide I'm your enemy: out here, deacon mostly means the one who keeps the count when people don't come back.",
			"variants": [
				{"flag": "ch6_briefed", "text": "The fringe first, bearer — nothing moves in the Deep while the Auroch holds the wallow.", "next": ""},
				{"flag": "chose_wagon_south", "text": "You're the bearer from the ice — the one who hauled a wagon of sleepers back to the fires. My faithful argued about you for three nights. Half called it desecration of a vow. The other half quietly wished someone had hauled THEIR kin south. I was in the second half. Vela. Deacon. Welcome to a worse question."},
				{"flag": "chose_wagon_north", "text": "You're the bearer from the ice — the one who finished a dead porter's haul and delivered eleven sleepers to their vow. My faithful approved; vows are our trade. I keep wondering about YOUR nights since. Vela. Deacon. Welcome to a worse question."},
			],
			"next": "b2"},
		"b2": {"who": "Deacon Vela", "text": "We came on pilgrimage. The blight is the land telling the truth — rot comes for everything; the Choir simply stopped calling that bad news. Sixty years of that creed, bearer, and it HELD, through plague and Vale and worse. Then we walked into the Deep and found the opposite of rot: growth without death. Things that only add. And half my flock knelt to it on sight.", "next": "b3"},
		"b3": {"who": "Deacon Vela", "text": "The Auroch holds the wallow — the bog-bull that drowned a century back and never stopped growing. Past it, Rotmaw: MY deacon once, now gardener to the lie. And in the heart of the Bloom, the Wildfang shaman Kaethra, who drank the green looking for a cure. Both her camps agree she cannot leave the Deep. When Wildfang camps agree, bearer, the thing they agree on is always terrible.",
			"choices": [
				{"text": "\"I'll clear the way and hear Kaethra out before anything ends. She's owed that much.\"",
					"resonance": 6.0, "flags": {"ch6_briefed": true}, "quest": "auroch", "next": "b_owed"},
				{"text": "\"Growth without death sounds like a weapon somebody should bottle before it's destroyed.\"",
					"resonance": -8.0, "flags": {"ch6_briefed": true, "chose_covets_bloom": true}, "quest": "auroch", "next": "b_bottle"},
				{"text": "\"Auroch, gardener, shaman. I'll work inward. Keep your flock at the gate.\"",
					"resonance": 0.0, "flags": {"ch6_briefed": true}, "quest": "auroch", "next": "b_work"},
			]},
		"b_owed": {"who": "Deacon Vela", "text": "Owed. Yes. ...You know what the Deep has taught me, bearer? Every creed I own fits a funeral. NONE of them fit a woman who cured herself into something worse and stayed kind through it. Hear her out. And come tell an old deacon what you heard — my theology needs the bruise.", "next": ""},
		"b_bottle": {"who": "Deacon Vela", "text": "Bottle it. Flame preserve us — that's exactly what Kaethra thought, and she was wiser than you and twice as careful, and the bottle is currently WEARING her. Go look at what bottling costs before you price it. The Deep does theology by demonstration.", "next": ""},
		"b_work": {"who": "Deacon Vela", "text": "Inward it is. The flock stays gated — those that still listen to me. The ones that don't are past the canal, in Rotmaw's congregation now, and bearer... they were mine. Whatever you must do out there, know that someone at this gate is still praying for them by NAME.", "next": ""},
	}},

	# ---- Herbalist Kesh: the cure-camp's second, who sent for you.
	"ch6_wildfang": {"start": "k1", "nodes": {
		"k1": {"who": "Herbalist Kesh",
			"text": "You came. Good — I sent the runner, so whatever happens in the Deep, the weight of it starts with me. Kesh, cure-camp. Kaethra was my teacher, my chief, and the best of us by a margin I won't insult with modesty. I need you to understand what she is before you meet what she's become.",
			"variants": [
				{"flag": "ch6_kesh_heard", "text": "The Deep is that way, bearer. Whatever the Root left of her — she'd want it met with clear eyes. Both camps are behind you. Flame, that sentence still sounds wrong.", "next": ""},
			],
			"next": "k2"},
		"k2": {"who": "Herbalist Kesh", "text": "Our whole people is one argument: cure the beast-blood, or accept it. Kaethra led the cure camp — and she was HONEST, bearer, that's the wound of it. She wouldn't test the Root's green on a child or a volunteer or an enemy. Herself only. It worked. The beast in her blood is gone... and the Root moved into the empty room. Now the hunt-camp says 'we told you so' and weeps while saying it.",
			"choices": [
				{"text": "\"When it's done, I'll carry her answer back to both camps — whatever it turns out to be.\"",
					"resonance": 5.0, "faction": {"wildfang": 3}, "flags": {"ch6_kesh_heard": true}, "next": "k_carry"},
				{"text": "\"So the cure question is settled, then. That's worth knowing, whatever it cost.\"",
					"resonance": -3.0, "flags": {"ch6_kesh_heard": true}, "next": "k_cold"},
			]},
		"k_carry": {"who": "Herbalist Kesh", "text": "Her ANSWER. Yes — that's the first framing of this that hasn't made me want to break something. She always said the argument would end with evidence, not victory. She just never meant to BE it. Go, bearer. And if any part of her is still choosing words in there... let her finish them.", "next": ""},
		"k_cold": {"who": "Herbalist Kesh", "text": "...Settled. Aye, the way a fire settles a granary dispute. You're not wrong, bearer, and I'll thank you to never say it that way inside the camp. WORTH and COST are hunt-camp words this week. We're all hunt-camp this week.", "next": ""},
	}},
	"ch6_accord": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Palla",
			"text": "Warden Palla, Accord. The pattern-readers sent me with one sentence and I've been chewing it since: 'the Pale Root is the seal to fear.' Not the Judge, all verdicts and theater. Not the Queen, hoarding her sleepers. THIS one. Because fire and ice announce themselves, bearer — growth just quietly disagrees with every boundary it meets.",
			"variants": [
				{"flag": "ch6_accord_heard", "text": "Starve it of gardeners, bearer. It can't want things on its own yet — that's the whole window we have.", "next": ""},
			],
			"next": "a2"},
		"a2": {"who": "Warden Palla", "text": "Maren's read: the Root doesn't break its seal — it GROWS THROUGH it, hair-thin, patient, wherever something living invites it. Rotmaw invited it. Kaethra, flame keep her, invited it with the best reasons in Vaelscar. The Accord's ask is the ugly usual: uninvite it. Every gardener, every root, every kindness it's wearing.",
			"choices": [
				{"text": "\"Every invitation, withdrawn. The Accord reads it right again.\"",
					"faction": {"accord": 4}, "flags": {"ch6_accord_heard": true}, "next": "a_yes"},
				{"text": "\"One of those 'invitations' is a woman both her camps still love. Mind your words, warden.\"",
					"resonance": 3.0, "flags": {"ch6_accord_heard": true}, "next": "a_mind"},
			]},
		"a_yes": {"who": "Warden Palla", "text": "Then the standard seal-work warning, worse here than anywhere: the Root recruits through GIFTS. It will offer you exactly the healing, the growth, the undoing-of-harm you've been carrying a wish for. It read Kaethra's wish perfectly. Know yours before it does.", "next": ""},
		"a_mind": {"who": "Warden Palla", "text": "...Fair. Struck and noted. We name things 'assets' and 'invitations' so we can sleep after the arithmetic, and sometimes a bearer should catch us at it. She's a woman, and it's wearing her, and both facts go in my report. Flame keep you in the Deep.", "next": ""},
	}},
	"ch6_fisher": {"start": "f1", "nodes": {
		"f1": {"who": "Fisher Dov",
			"text": "Thirty years I've fished this bog — it takes, that's its NATURE, a net a season and a cousin a decade. I made my peace with a taking bog. Then last spring it started giving BACK. Fish I never stocked. Fruit on the drowned trees. My old dog, bearer — dead four winters — scratching at the door one morning, looking exactly right. That's when I moved to the gate. Exactly right is how you know.",
			"variants": [{"flag": "ch6_dov_heard", "text": "The dog still comes by, nights. Sits past the firelight, looking exactly right. I don't call him in. Hardest thing I do, most nights, not calling him in.", "next": ""}],
			"choices": [
				{"text": "\"You did right, Dov. The bog that takes is honest — the one that gives back wants something.\"",
					"resonance": 4.0, "flags": {"ch6_dov_heard": true}, "next": "f_right"},
				{"text": "\"...What happens if you call the dog in?\"",
					"resonance": -3.0, "flags": {"ch6_dov_heard": true}, "next": "f_ask"},
			]},
		"f_right": {"who": "Fisher Dov", "text": "Wants something. Aye. My gran said it plainer: 'free is the most expensive price.' Thirty years fishing and the spring the bog turned generous is the spring I lost my nerve. Tells you everything about what kind of generous it is.", "next": ""},
		"f_ask": {"who": "Fisher Dov", "text": "...Brekk from the far shore called his wife in. She'd been dead two years and she came back exactly right, and for a month the far shore was the happiest place in the bog. Nobody's seen the far shore since midsummer, bearer. The reeds there grow forty feet and they LEAN toward you when you row past. Don't ask me that again, and don't ask ME why I still leave the door unlatched.", "next": ""},
	}},

	# ---- Kaethra's ending: the fight stops at 10% (boss.gd) and THIS
	# runs. Strike or sheathe — binary, diegetic, no timer. She dies
	# either way; the divergence is the flag, the shift, and who does it.
	"ch6_kaethra_end": {"start": "e1", "nodes": {
		"e1": {"who": "Kaethra",
			"text": "...There. It let go. Do you feel it? It LET GO of me — the Root doesn't fight ruins, and that's what's left to fight over. So. These last words are mine, wholly mine, and I get to spend them: the cure was real, bearer. Tell them that. And the price was real. Tell them BOTH, or tell them nothing. Now — your blade or my own blood; the ruin finishes either way. Choose. I'm not afraid. I checked that too.",
			"choices": [
				{"text": "Sheathe the blade. Stay with her — she ends as Kaethra, by her own failing blood, with a witness.",
					"resonance": 6.0, "faction": {"wildfang": 4}, "flags": {"chose_kaethra_sheathed": true}, "next": "e_sheathe"},
				{"text": "Strike, clean and sure — take the weight so her last act isn't dying, but choosing how.",
					"resonance": -4.0, "flags": {"chose_kaethra_struck": true}, "next": "e_strike"},
			]},
		"e_sheathe": {"who": "Kaethra", "text": "...Sheathed. Ha. Both camps armed a stranger and sent you in, and you end it with an empty hand. That's the answer I'd have wanted carried back, bearer — not 'cure' or 'acceptance.' WITNESS. Tell Kesh the last thing the Root ever heard in here was me, laughing at it, in my own voice.", "next": ""},
		"e_strike": {"who": "Kaethra", "text": "...Good. Decisive — the camps will need that more than gentleness, the years coming. Carry it well, bearer; a clean weight carried honestly is no shame to either of us. And tell Kesh — tell Kesh the beast was gone at the end, and so was the Root, and what was left... chose. That's cure enough.", "next": ""},
	}},

	# ---- Resonance rooms.
	"ch6_shrine_pool": {"start": "p1", "nodes": {
		"p1": {"who": "Narrator",
			"text": "The Cure Pool — the spring Kaethra drank from. Green water, utterly clear, and under it white roots in slow motion. The camp fenced it with bone stakes and warnings in three scripts, and the fence is leaning inward now, pulled gently, month by month. The water knows what you carry. It is already offering: the Ember's whisper gone QUIET, the debt lifted, the temptation cured. Growth without death. All it has ever asked is room.",
			"variants": [{"flag": "cure_pool_faced", "text": "The pool lies clear and patient behind its leaning fence. Between you and it, whatever passed is finished — though the water, you notice, has not stopped being certain you'll be back.", "next": ""}],
			"choices": [
				{"text": "Kneel and speak your temptation ALOUD to the water — name the thing it's offering to cure, and keep it, owned, yours.",
					"resonance": 8.0, "flags": {"cure_pool_faced": true, "chose_owned_temptation": true}, "next": "p_own"},
				{"text": "Drink. One mouthful. Kaethra was reckless; you'll be careful. The difference feels enormous from this side of the fence.",
					"resonance": -10.0, "flags": {"cure_pool_faced": true, "chose_drank_cure": true}, "next": "p_drink"},
				{"text": "Drive the leaning fence-stakes back upright, and go. Some pools you fix the FENCE for, not the thirst.",
					"resonance": 3.0, "flags": {"cure_pool_faced": true}, "next": "p_fence"},
			]},
		"p_own": {"who": "Narrator", "text": "You say it plainly — the exact thing the Ember wants of you, the thing you have carried since your shard woke. Spoken to open water, it sounds smaller. Ownable. The pool's stillness flickers, once: an offer has never been declined by NAMING before, and somewhere down among the white roots something files you under DIFFICULT. The Ember's whisper is still there as you walk away. But it's yours. That was always the only cure on the table.", "next": ""},
		"p_drink": {"who": "Narrator", "text": "One mouthful. Cold, sweet, and the whisper STOPS — for the first time since your shard woke, perfect silence where the temptation lived. You could weep. Halfway back to the trail you notice your cut knuckle from the fringe has healed without a scar. By nightfall, the scar you got at TEN is gone too. The Root never subtracts, bearer. It is very much hoping you won't do the arithmetic on what it's adding.", "next": ""},
		"p_fence": {"who": "Narrator", "text": "You reset the stakes one by one, driving them deep, angling them out. Honest work; the kind hands remember. The water watches with what you'd swear is amusement — fences have never once held it, and you both know it. But that was never what the fence was for. The fence is a SENTENCE, written in bone, that says: somebody decided no. It reads a little clearer now. Travelers will see it. That's the whole victory, and you'll take it.", "next": ""},
	}},
	"ch6_shrine_schism": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "Two knots of Choir pilgrims, one shouting-match past mending, and between them a table with bread going stale — nobody will eat first. An old pilgrim grips a rot-blackened staff: \"Decay is the truth! This Blooming is the LIE that tests us!\" A younger one holds up a flowering reed: \"Or sixty years of funerals were the test, and THIS is the answer!\" They see you — shard-lit, blooded, fresh from the Deep itself — and both sides go quiet with the same terrible hope: an oracle has arrived. \"You've SEEN it,\" the young one breathes. \"Which is the land's truth, bearer? The rot or the bloom?\"",
			"variants": [{"flag": "schism_answered", "text": "The two camps share the gate again — not the table yet, but the gate. Your answer is still being turned over by both sides, which may be the most any answer ever achieves in a schism.", "next": ""}],
			"choices": [
				{"text": "\"Neither. Rot and bloom are both just APPETITES wearing the land. The truth is whoever keeps feeding the other pilgrims — pass the bread.\"",
					"resonance": 6.0, "faction": {"choir": 2}, "flags": {"schism_answered": true, "chose_schism_bread": true}, "next": "s_bread"},
				{"text": "\"The rot. I've seen the bloom up close — it's the same hunger with better manners. Your old creed holds.\"",
					"resonance": 0.0, "faction": {"choir": 4}, "flags": {"schism_answered": true}, "next": "s_rot"},
				{"text": "Say nothing. Take the stale bread from between them, break it, eat, and walk on — let them argue about THAT for a decade.",
					"resonance": -2.0, "flags": {"schism_answered": true}, "next": "s_eat"},
			]},
		"s_bread": {"who": "Narrator", "text": "Both camps stare — at you, at the bread, at each other. The old pilgrim laughs first: one harsh bark, sixty years of doctrine cracking to let it out. \"...Appetites wearing the land,\" he repeats. \"Flame help me, that's better theology than I've managed since the Vale.\" The bread moves. Somebody fetches the good knife. The schism isn't healed — schisms don't heal — but tonight it is FED, and fed arguments stay arguments instead of becoming wars.", "next": ""},
		"s_rot": {"who": "Narrator", "text": "The old guard erupts in grim vindication; the young reed-bearer looks at her flower like it lied to her, and lets it fall. You've handed one side victory and it fits them like a warm coat — and as they crowd around you for details, you catch the young one at the edge of the lamplight, slipping away toward the Deep. Toward the bloom. People don't stop believing when you rule against them, bearer. They just stop believing NEAR you.", "next": ""},
		"s_eat": {"who": "Narrator", "text": "You eat their argument. The silence is total and profoundly theological. As you walk on, the debate reignites behind you at double volume — WHAT DID IT MEAN — and you find you're smiling. The shard is smiling too, which sours it a little. It likes oracles. It especially likes oracles who answer in riddles and keep walking; that's how ITS old bearers ended up with kingdoms.", "next": ""},
	}},

	# ---- Dead-end lore.
	"ch6_lore_shrine": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A Choir wayshrine, sunk to its lintel — the pilgrims built it the week they arrived, to consecrate the Deep to holy rot. The bog swallowed it in a season, which the faithful took as acceptance. Then the Blooming found it: the shrine now stands in a collar of flowers that open every dawn, facing it, like a congregation. The Choir won't go near it. Nothing they own has a rite for being WORSHIPPED BACK.", "next": ""},
	}},
	"ch6_lore_gallery": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A gallery of white roots, thick as bridge-cables, running through the peat in one direction: down. Every root in the Deep, whatever it feeds above, bends eventually to this bearing. The cure-camp's survey stakes stop at the gallery's edge; the last stake carries Kaethra's own tag, in a steady hand: 'ALL ONE PLANT. STOP CALLING THEM ROOTS. THESE ARE FINGERS.'", "next": ""},
	}},

	# ---- Social wanderers.
	"ch6_wander_convert": {"start": "c1", "nodes": {
		"c1": {"who": "Blooming Convert",
			"text": "You should SEE it, friend — the far grove, where the growing never stops! I was Choir twenty years; I sang at funerals till my voice went. Now I sing at SPROUTINGS. Ask me if I've ever been happier. Ask me!",
			"variants": [{"flag": "ch6_convert_met", "text": "Still glad! Still growing! ...The garden's quieter since the deacon fell, but the ROOTS remember the songs. They hum back now, nights. Isn't that wonderful? ...Isn't it?", "next": ""}],
			"choices": [
				{"text": "\"Have you ever been happier?\"", "flags": {"ch6_convert_met": true}, "next": "c_happy"},
				{"text": "\"Twenty years of funerals, friend. Grief doesn't convert — it just changes gardens.\"",
					"resonance": 3.0, "flags": {"ch6_convert_met": true}, "next": "c_grief"},
			]},
		"c_happy": {"who": "Blooming Convert", "text": "NEVER happier! Not once! Not at my wedding, not at my daughter's naming, not— he stops. Something moves behind his eyes, slow as a root. \"...That's wrong, isn't it. That arithmetic. A man's happiest day shouldn't have SOIL in it.\" For one clear moment he looks terrified. Then the smile grows back — grows, that's the only word — and he waves you cheerfully on.", "next": ""},
		"c_grief": {"who": "Blooming Convert", "text": "...Changes gardens. The smile holds, but his hands go still. \"My daughter's in the Vale, you know. Unburied. I sang NO over her myself — doctrine, you understand. I think... I think I came here because the bloom never says no.\" He looks at his still hands. \"You'd best walk on, friend. Some weeding I have to do alone.\"", "next": ""},
	}},
	"ch6_wander_doubter": {"start": "d1", "nodes": {
		"d1": {"who": "Sister Ottilie",
			"text": "I count flowers. Officially I'm cataloguing the corruption for the deaconry; unofficially, bearer, I stopped believing anything three weeks ago and counting is what hands do when the soul's gone quiet. Four thousand and twelve blooms between here and the canal. All facing the deep grove. Flowers don't FACE, is the thing. I checked the old herbals twice.",
			"variants": [{"flag": "ch6_ottilie_met", "text": "Four thousand ninety, now. They're gaining. I've started counting out loud so the numbers feel like they belong to me and not to it. Small madnesses keep off the big one — old Choir wisdom, and the only bit still working.", "next": ""}],
			"choices": [
				{"text": "\"Keep counting, sister. A true count is a kind of faith — maybe the only kind the Deep can't grow through.\"",
					"resonance": 4.0, "flags": {"ch6_ottilie_met": true}, "next": "d_faith"},
			]},
		"d_faith": {"who": "Sister Ottilie", "text": "...A kind of faith. She writes that down, actually writes it, in the margin of her tally-book. \"Sixty years of liturgy and the first theology that's helped me in weeks comes off a sword-hand at a bog gate. When they end this — when YOU end this — I'm keeping the book. Someone should know exactly how many it was.\"", "next": ""},
	}},
	"ch6_wander_scout": {"start": "s1", "nodes": {
		"s1": {"who": "Cure-Camp Scout Renn",
			"text": "You're the blade both camps sent for. Good. I scouted the deep grove for Kaethra — last one of her scouts still... still on the roster. Ask what you need; I owe her answers being USED.",
			"variants": [{"flag": "ch6_renn_met", "text": "Roster's still one, bearer. It'll stay one till this is done — then I'm teaching the young ones everything she taught me, minus the last lesson. That one you're handling.", "next": ""}],
			"choices": [
				{"text": "\"Tell me the thing about her nobody's put in a report.\"", "flags": {"ch6_renn_met": true}, "next": "s_tell"},
			]},
		"s_tell": {"who": "Cure-Camp Scout Renn", "text": "She tested the cure on herself on a MARKET day. Picked it deliberately — camp full, everyone watching, no way to hide the result either way. 'Evidence belongs to everyone,' she said, 'especially the bad kind.' Whatever you meet in that grove, bearer, it grew up around a woman who thought like THAT. Root's got her strength. Remember it also got her stubbornness — and her stubbornness was always aimed at the truth coming OUT.", "next": ""},
	}},
	"ch6_wander_fisher": {"start": "f1", "nodes": {
		"f1": {"who": "Reed-Cutter Ama",
			"text": "Mind the tall reeds on the west paths — and I mean MIND them. I've cut reed here forty years. Reed bends from wind. The west stands bend from ATTENTION, and there's no polite way to say that, so I've stopped being polite: they watch, they lean, and last month one of my cutters swears a stand parted to let her through, like a courtesy. We don't cut the west anymore.",
			"variants": [{"flag": "ch6_ama_met", "text": "Still cutting the east stands only. The west ones have started leaning EAST, though. I've drawn the line at the canal. Lines matter, even to reeds — maybe especially to reeds.", "next": ""}],
			"choices": [
				{"text": "\"A courtesy from the reeds. What do you reckon it wants, Ama?\"", "flags": {"ch6_ama_met": true}, "next": "f_wants"},
			]},
		"f_wants": {"who": "Reed-Cutter Ama", "text": "Same as any young thing copying its elders — it wants to be LIKED. That's the part that keeps me up, bearer. The blight never cared what we felt about it. This green thing is learning manners, and manners are how you get invited inside. Forty years of reeds, and I never thought I'd miss honest rot.", "next": ""},
	}},
	"ch6_wander_botanist": {"start": "b1", "nodes": {
		"b1": {"who": "Botanist Ferro (Accord)",
			"text": "Careful where you step — sample plots. The Accord wants growth-rate curves and I am DELIGHTED to bore you with them: everything in the Deep grows at one-point-something the normal rate. Everything. Same multiplier, moss to bog-oak, which is absurd — growth doesn't standardize. Unless it isn't growth. Unless it's one thing, growing, wearing four thousand shapes to do it.",
			"variants": [{"flag": "ch6_ferro_met", "text": "New curves are in. The multiplier DIPPED this week — first dip on record. Whatever you've been doing in there, the one-thing-wearing-shapes noticed it. Congratulations and, professionally speaking, watch your back.", "next": ""}],
			"choices": [
				{"text": "\"One thing wearing four thousand shapes. Put that in the report exactly like that, Ferro.\"", "flags": {"ch6_ferro_met": true}, "next": "b_report"},
			]},
		"b_report": {"who": "Botanist Ferro (Accord)", "text": "I did, actually. Maren's marginal note came back in two days: 'KNOWN. The epithet is the Pale Root. Keep measuring — a thing that standardizes can be BUDGETED, and a thing that can be budgeted can be starved.' That woman frightens me more than the bog does, bearer, and I mean that as the highest compliment in the civil service.", "next": ""},
	}},
}
