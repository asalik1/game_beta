## Chapter 2 SIDE rooms — the reward-hole retrofit (CH2_RETROFIT_TASKS,
## DESIGN.md open item #1). Content module (see README.md): appends the
## ten rooms that turn ch2 from a bare 10-room spine into the ch3 shape.
##
## WHY THIS FILE EXISTS. ch2 measured the worst chapter in the game —
## 36.5 replay g/min, under even ch1's 38.8, against ch3's 70.7 — and the
## cause was structural, not numeric: the premium path is seeded by room
## TYPE (elites ~60% of a run's gems, hidden caches ~25% of dead ends,
## gamble shrines ~22% of quiet rooms, cursed chests ~15% of combat
## rooms) and ch2 had ZERO social / dead-end / resonance rooms for any of
## it to attach to. So the fix is rooms, not knobs — add the types back
## and the economy heals through seeding that already exists.
##
## THESE ARE SIDE ROOMS. They are appended AFTER the ten spine rooms, so
## the spine keeps indices 0-9 (camp, Mills, Fields, Sporewood, Hollow,
## Dunes, Expanse, Deeps, Ruins, Bastion) exactly as the suite's
## `_edge_unlocked(n, n+1)` / `_goto_room(9)` assertions expect. Never
## insert a room ahead of index 10 — author new ones at the END.
##
## TERRAIN IS THE ATTACH KEY. `_generate_layout` hangs each side room off
## a seeded PLACED room of the SAME terrain, so a room's terrain decides
## which stretch of the chapter it appears in. ch2 runs one terrain per
## spine room, which makes the mapping exact and deliberate:
##   bog -> Greyrun Mills   storm -> Howling Fields   spore -> Sporewood
##   graveyard -> Choir's Hollow   desert -> Dunes   ice -> Expanse
##   crystal -> Deeps   holy -> Ruins   void -> Bastion
## (village is left hostless on purpose — Maren's camp stays a clean hub.)
##
## XP BUDGET. Chapter XP is FIXED (CH2_RETROFIT constraint): the full
## clear must stay within +/-3% of the measured 2926. These rooms
## therefore carry AUTHORED XP OVERRIDES (the spawn tuple's 6th param) —
## they pay real gold, chests and elites, but only a shaved share of the
## level curve, so exploring cannot outrun the chapter's pacing. The
## ch3 doctrine applies: the curve assumes side rooms, and a spine-only
## run lands about one level under, by design.

const CHAPTER_ZONES := {
	"ch2": [
		# ---------------------------------------------- bog (the Mills) ---
		{
			"name": "The Drowned Race", "terrain": "bog", "ground": "bogsoil", "path": "dirt",
			"type": "combat",
			# Melee-heavy, per the room-banding constraint: ch2 needed a
			# third teaching room and the Mills' own wolves are the lesson.
			"enemies": [
				["blightwolf", 420, 300, 0, 3, 7], ["blightwolf", 560, 230, 0, 3, 7],
				["blightwolf", 500, 430, 0, 3, 7],
				["bogspider", 1420, 860, 1, 4, 8], ["bogspider", 1550, 790, 1, 4, 8],
				["bogspider", 1480, 960, 1, 4, 8],
				["beastkin_raider", 1740, 380, 2, 5, 11], ["blightwolf", 1860, 470, 2, 3, 7],
			],
			"boss": "",
		},
		{
			"name": "The Ferryman's Landing", "terrain": "bog", "ground": "bogsoil", "path": "dirt",
			"type": "dead_end", "cache": "wood",
			"enemies": [
				["bogspider", 1180, 520, 0, 4, 8], ["blightwolf", 1320, 600, 0, 3, 7],
			],
			"boss": "",
			"npcs": [
				{"sprite": "bones", "x": 900, "y": 360, "prompt": "E — The Landing", "convo": "ch2_lore_ferry"},
			],
		},
		# ------------------------------------------ storm (the Fields) ---
		{
			"name": "The Lee of the Stones", "terrain": "storm", "ground": "stormgrass", "path": "dirt",
			"type": "social",
			"enemies": [], "boss": "",
		},
		# --------------------------------------- spore (the Sporewood) ---
		{
			"name": "The Sporefall", "terrain": "spore", "ground": "sporesoil", "path": "dirt",
			"type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "fungus_long", "x": 1056, "y": 500, "prompt": "E — The Breathing Tree", "convo": "ch2_shrine_sporefall"},
			],
		},
		# ------------------------------------ graveyard (the Hollow) ---
		{
			"name": "The Sung-Over Ground", "terrain": "graveyard", "ground": "gravedirt", "path": "gravedirt",
			"type": "combat",
			# Mixed band (~37% ranged), the Hollow's own casting.
			"enemies": [
				["zombie", 460, 300, 0, 4, 5], ["zombie", 590, 240, 0, 4, 5],
				["zombie", 520, 430, 0, 4, 5],
				["stormcult", 1380, 880, 1, 7, 13], ["stormcult", 1500, 800, 1, 7, 13],
				["sporeshambler", 1430, 970, 1, 6, 11],
				["zombie", 1720, 420, 2, 4, 5], ["stormcult", 1840, 520, 2, 7, 13],
			],
			"boss": "",
		},
		# ---------------------------------------- desert (the Dunes) ---
		{
			"name": "The Salt Reliquary", "terrain": "desert", "ground": "sand", "path": "sand",
			"type": "dead_end", "cache": "silver",
			"enemies": [
				["sun_bleached", 1200, 560, 0, 10, 20], ["duneprowler", 1340, 640, 0, 9, 16],
			],
			"boss": "",
			"npcs": [
				{"sprite": "pillar", "x": 880, "y": 380, "prompt": "E — Read the Stone", "convo": "ch2_lore_reliquary"},
			],
		},
		# ----------------------------------------- ice (the Expanse) ---
		{
			"name": "The Cold Waystation", "terrain": "ice", "ground": "snow", "path": "snow",
			"type": "merchant",
			"merchant": [1056, 620], "shop_tier": "silver",
			"enemies": [], "boss": "",
		},
		# ------------------------------------- crystal (the Deeps) ---
		{
			"name": "The Echoing Gallery", "terrain": "crystal", "ground": "crystalfloor", "path": "crystalfloor",
			"type": "social",
			"enemies": [], "boss": "",
		},
		# --------------------------------------- holy (the Ruins) ---
		{
			"name": "The Unbroken Font", "terrain": "holy", "ground": "holystone", "path": "holystone",
			"type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "garden_fountain", "x": 1056, "y": 500, "prompt": "E — The Font", "convo": "ch2_shrine_font"},
			],
		},
		# -------------------------------------- void (the Bastion) ---
		{
			"name": "The Maintenance Yard", "terrain": "void", "ground": "voidstone", "path": "voidstone",
			"type": "combat",
			# Ranged-heavy artillery room (~62%): the Bastion's grid
			# already sorts the region, and this is where it shoots back.
			"enemies": [
				["null_acolyte", 460, 320, 0, 13, 22], ["null_acolyte", 600, 250, 0, 13, 22],
				["void_husk", 530, 450, 0, 15, 28],
				["null_acolyte", 1400, 870, 1, 13, 22], ["null_acolyte", 1530, 790, 1, 13, 22],
				["deep_stalker", 1450, 960, 1, 12, 20],
				["null_acolyte", 1760, 400, 2, 13, 22], ["void_husk", 1880, 500, 2, 15, 28],
			],
			"boss": "",
		},
	],
}

# Per-chapter social wanderers (rolled seeded per character). ch2 was the
# only campaign chapter without a pool. That is not a crash — `wanderers_for`
# falls back to the Chapter 1 pool, which is deliberately road-generic — but
# ch1's wanderers speak from the Hollow King's war, and ch2's new social
# rooms sit on a REFUGEE road years later. A chapter that now owns two
# social rooms should own the voices standing in them.
#
# CASTING NOTE (owner review, CR-5): these five bodies are the Pixel
# Crawler humans already installed and hung along Maren's camp as the
# dev-only placeholder gallery — `ch2_hub.gd` carries a standing TODO to
# "reposition into real roles or delete this whole block", and this is
# the repositioning. They are hidden from normal play today
# (`game_world.gd` skips `placeholder` NPCs outside dev mode), so this is
# the first time a player sees them. The gallery entries are left exactly
# where they are; nothing was deleted. Recast or revert is one line each.
const WANDERERS := {
	"ch2": [
		{"sprite": "npc_wanderer", "prompt": "E — Talk", "convo": "ch2_wander_road"},
		{"sprite": "npc_hunter", "prompt": "E — Talk", "convo": "ch2_wander_snares"},
		{"sprite": "npc_villager_f", "prompt": "E — Talk", "convo": "ch2_wander_mother"},
		{"sprite": "npc_bandit_tracker", "prompt": "E — Talk", "convo": "ch2_wander_tracker"},
		{"sprite": "npc_elder2", "prompt": "E — Talk", "convo": "ch2_wander_holdout"},
	],
}

const CONVOS := {
	# ---- Resonance shrines: ch2's two genuine choices. Both are
	# one-time, both are GROUNDED (what you get is coin or knowledge a
	# person could carry, never a stat buff), and both run the symmetric
	# +8 / -8 / 0 range the shrine round settled on.
	"ch2_shrine_sporefall": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "A spore-tree stands alone in the clearing, three times the height of the shamblers that grew from it. It BREATHES — a slow swell and settle, hours long, and you have caught it mid-inhale. The air here is thick and faintly sweet. Somewhere in the Sporewood a bearer before you carved a mark into the bark and then, by the look of the second mark, came back.",
			"variants": [{"flag": "sporefall_answered", "text": "The tree breathes on, indifferent to having been decided about. Your mark is the third on the bark, and already the wood is closing over it.", "next": ""}],
			"choices": [
				{"text": "Stand in the exhale and BREATHE it. The Sporewood has been trying to tell somebody something for years.",
					"resonance": 8.0, "flags": {"sporefall_answered": true, "sporefall_listened": true}, "next": "s_breathe"},
				{"text": "Cut it open. Whatever the blight has been storing in there, it has been storing it since before you were hungry.",
					"resonance": -8.0, "flags": {"sporefall_answered": true}, "gold": 45, "next": "s_cut"},
				{"text": "Leave it breathing. Not everything in the Waking is addressed to you.",
					"resonance": 0.0, "flags": {"sporefall_answered": true}, "next": "s_leave"},
			]},
		"s_breathe": {"who": "Narrator", "text": "You breathe, and for a moment you are very tall and very slow and rooted in one place for eleven years, and the thing you feel is not malice. It is PATIENCE. The blight is not angry at Vaelscar; it simply has more time than Vaelscar does. You come back to yourself coughing, on your knees, and better informed than any Accord survey.", "next": ""},
		"s_cut": {"who": "Narrator", "text": "The trunk parts around a hollow the size of a cart, and the hollow is full of what the Sporewood has been quietly digesting: buckles, coin, a signet, the small hard leavings of everyone who walked in and did not walk out. You take the coin. Behind you the tree finishes its exhale and does not begin another, and you tell yourself that trees do not do that.", "next": ""},
		"s_leave": {"who": "Narrator", "text": "You step back out of the clearing. The swell and settle goes on behind you at its own enormous pace — a thing that will still be doing this when the Waking is a chapter in somebody's ledger. You find the thought steadying, which surprises you.", "next": ""},
	}},
	"ch2_shrine_font": {"start": "f1", "nodes": {
		"f1": {"who": "Narrator",
			"text": "Everything in the Sanctified Ruins is broken except the font. The roof came down, the pillars went over, the Null Acolytes have been through twice — and the basin still stands, and the water in it is still CLEAN. Not blessed-clean. Just clean, in a chapter of the world where nothing is. There is a tin cup on the rim, worn bright by hands.",
			"variants": [{"flag": "font_answered", "text": "The font holds its impossible clear water. The cup is where you left it — where everyone leaves it.", "next": ""}],
			"choices": [
				{"text": "Drink, put the cup back on the rim, and leave the basin full for the next one through.",
					"resonance": 8.0, "flags": {"font_answered": true}, "next": "f_drink"},
				{"text": "Clean water is the rarest cargo in Vaelscar. Fill every skin you own and take the cup too.",
					"resonance": -8.0, "flags": {"font_answered": true}, "gold": 45, "next": "f_take"},
				{"text": "Leave it untouched. You are carrying enough, and the basin is not for you.",
					"resonance": 0.0, "flags": {"font_answered": true}, "next": "f_leave"},
			]},
		"f_drink": {"who": "Narrator", "text": "It tastes of nothing at all, which after weeks of bog and ash is very nearly a religious experience. You set the cup back on the rim, dented side out, the way you found it. Six hundred years of people have done exactly this, and that — not the water — is the miracle the Ruins actually kept.", "next": ""},
		"f_take": {"who": "Narrator", "text": "Four skins, a cup, and the basin drawn down to its stained ring. It will refill; it always has. But the cup was the part that made it a font instead of a puddle, and you have that in your pack now, and the next one through will find water and no way to reach it that doesn't involve kneeling in it.", "next": ""},
		"f_leave": {"who": "Narrator", "text": "You walk past the basin with your skins as empty as they were. It is not virtue exactly — you simply could not think of a way to take from it that felt like anything but taking. The cup sits on the rim, waiting for somebody less careful.", "next": ""},
	}},

	# ---- Dead-end lore props (exploration pays in fiction as well as
	# chests — the dead-end premium the chapter had no rooms to carry).
	"ch2_lore_ferry": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A landing stage on the black water, and the ferryman still tied to his own post — rope around the waist, the way a man secures himself for a long night's work he intends to survive. He took people out of the Greyrun for eleven days after the blight came up. The tally is cut into the post beside him, five and five and five, and the last group is a group of one, and the notch for it is deeper than the others, as though cut slowly, by somebody with the evening free.", "next": ""},
	}},
	"ch2_lore_reliquary": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A boundary stone, half-swallowed by dune. The imperial side reads: BY ORDER OF THE CROWN, ALL WELLS BETWEEN THIS MARK AND THE SALT ARE HELD IN COMMON. The other face has been cut more recently, with a worse chisel, by somebody who had to lie down in the sand to reach it: AND THE CROWN IS DEAD AND THE WELLS ARE DRY AND WE HELD THEM IN COMMON RIGHT TO THE END. Both hands were proud of their work. Only one of them was joking.", "next": ""},
	}},

	# ---- Social wanderers. ch2's road is a REFUGEE road — the Waking's
	# leading edge is where people are still deciding whether to run.
	"ch2_wander_road": {"start": "r1", "nodes": {
		"r1": {"who": "A Road-Worn Traveller",
			"text": "Don't stop on my account, I'm not stopping either. Third time I've moved this year. You learn the trick of it — you go when the birds do, not when the neighbours do. Neighbours argue. Birds just leave.",
			"variants": [
				{"band": "tempted", "text": "...I'll walk on the other side of the road, if it's all the same. No offence meant. I've got very good at reading which way a thing is about to go, and that's the whole reason I'm still walking."},
				{"flag": "ch2_road_met", "text": "Still moving. Still ahead of it. That's the entire strategy and I'll thank you not to improve on it.", "next": ""},
			],
			"choices": [
				{"text": "\"Where do you stop, when you've run out of west?\"",
					"resonance": 3.0, "flags": {"ch2_road_met": true}, "next": "r_west"},
				{"text": "\"Everyone behind you is dying because nobody stands. Including you.\"",
					"resonance": -3.0, "flags": {"ch2_road_met": true}, "next": "r_barb"},
			]},
		"r_west": {"who": "A Road-Worn Traveller", "text": "Hadn't planned that far. ...That's a real question, isn't it. That's the first real question anybody's asked me on this road. I suppose I stop when there's somebody worth stopping FOR, and I haven't met them, and I keep not meeting them because I keep moving. Hm. I'll be thinking about that for a week, thanks very much.", "next": ""},
		"r_barb": {"who": "A Road-Worn Traveller", "text": "I stood the first time. Had a house and everything. What standing got me was a shorter list of people to move with. ...You've got a shard, bearer — standing is a thing you can AFFORD. Don't mistake that for a virtue you invented.", "next": ""},
	}},
	"ch2_wander_snares": {"start": "s1", "nodes": {
		"s1": {"who": "Snarehand Ott",
			"text": "Twenty-two snares out. Nineteen sprung, nothing in them. Two gone entirely — wire and stake, pulled out of the ground. And one with a hare in it that had been dead three days and got up when I touched the line. So: business is BRISK, and I've stopped eating what I catch.",
			"variants": [{"flag": "ch2_ott_met", "text": "Still setting them. Not for meat — for the COUNT. Nineteen sprung means nineteen things came through, and somebody in this world ought to be keeping that number.", "next": ""}],
			"choices": [
				{"text": "\"Then why keep setting them?\"",
					"resonance": 3.0, "flags": {"ch2_ott_met": true}, "next": "s_why"},
				{"text": "\"Sell me the wire. You clearly aren't using it for hares.\"",
					"resonance": -3.0, "flags": {"ch2_ott_met": true}, "gold": 25, "next": "s_wire"},
			]},
		"s_why": {"who": "Snarehand Ott", "text": "Because a snare tells you which way things are MOVING, and everything out here has started moving the same way, and it isn't away from the camp. Elder Maren's people won't pay for that, they want reports with maps on. I'll keep the line anyway. A man should know which direction the country is walking.", "next": ""},
		"s_wire": {"who": "Snarehand Ott", "text": "He counts out the coil without a word, takes the coin, and re-ties the last snare with what's left — shorter, closer to the path, angled at something considerably larger than a hare. \"Aye. Well. You've bought me a reason to set the good one.\"", "next": ""},
	}},
	"ch2_wander_mother": {"start": "m1", "nodes": {
		"m1": {"who": "Mother Rell",
			"text": "I've been back four times. I know. Everyone at the camp gives me the face when I go, and the same face when I come back, and neither face has ever once carried the pot I went for. Fourth trip was the good crockery, and yes I hear it, and yes I'm going a fifth time.",
			"variants": [{"flag": "ch2_rell_met", "text": "Fifth trip done. Sixth pending. Don't look at me like that — I've buried the important things already. What's left is what makes a room a HOUSE, and I'll be having it.", "next": ""}],
			"choices": [
				{"text": "\"Tell me what's still in the house. If I pass it, I'll carry it out.\"",
					"resonance": 3.0, "flags": {"ch2_rell_met": true}, "next": "m_kind"},
				{"text": "\"Crockery. People are dying on this road and you're walking back INTO it for crockery.\"",
					"resonance": -3.0, "flags": {"ch2_rell_met": true}, "next": "m_barb"},
			]},
		"m_kind": {"who": "Mother Rell", "text": "...The blue jug on the shelf by the door. That's all. That's the whole list, I've been carrying it around for a month and nobody's asked to hear it. ...Bearer, if it's gone, don't come and tell me gently. Just don't mention it and I'll understand.", "next": ""},
		"m_barb": {"who": "Mother Rell", "text": "Aye. And when it's over and we go back — and we WILL go back, they always say we won't and we always do — I'll set a table with my mother's plates and you'll be welcome at it, and you'll understand then what the walking was for. Or you won't, and you'll eat off a board like the rest of the brave.", "next": ""},
	}},
	"ch2_wander_tracker": {"start": "t1", "nodes": {
		"t1": {"who": "The Tracker",
			"text": "I sell the EDGE. Where the blight stopped last week, where it is this morning, how fast. Accord buys it, Cinderborn buys it, and a Wildfang runner buys it with meat because they've no coin and better manners than either. Same map, three prices. I've no politics; I have a good pair of eyes and a bad opinion of everyone.",
			"variants": [
				{"band": "steady", "text": "You're the quiet one, then. My line of work, you learn to read what a person is carrying. Yours sits still. That's worth a discount and I'll not be explaining why."},
				{"flag": "ch2_tracker_met", "text": "Edge moved again. North, faster than a person walks. I've stopped selling that particular figure — nobody was buying it twice.", "next": ""},
			],
			"choices": [
				{"text": "\"What does the edge do that you haven't sold anyone yet?\"",
					"resonance": 3.0, "flags": {"ch2_tracker_met": true}, "next": "t_free"},
				{"text": "\"Three prices for one map. You'll sell our position to the beastkin next.\"",
					"resonance": -3.0, "flags": {"ch2_tracker_met": true}, "next": "t_barb"},
			]},
		"t_free": {"who": "The Tracker", "text": "...It goes AROUND things. Not around walls — around people who stayed. Two farms held out east of the Greyrun and the edge bent, and I've walked it twice to be sure. I've not sold that to anyone, because the Accord would garrison it and the Cinderborn would price it and I'd like, just once, to have found something out and not started a war with it. You have it for free. Do better than they would.", "next": ""},
		"t_barb": {"who": "The Tracker", "text": "I'd sell it to the beastkin at the same rate as anyone, and they'd not use it, because a Wildfang raid doesn't need a map to find a camp of hungry strangers — they need a REASON, and every side out here keeps handing them one. ...Go on. You paid nothing and got told the truth; that's the best transaction on this road.", "next": ""},
	}},
	"ch2_wander_holdout": {"start": "h1", "nodes": {
		"h1": {"who": "Old Bevin",
			"text": "No. Before you start — no. Maren's sent three, the Accord sent one with a form, and a lad in Cinderborn grey offered me MONEY for it, which was the funniest thing that's happened here since the blight. Ninety years my family's held this ground. I'm not the generation that stops.",
			"variants": [{"flag": "ch2_bevin_met", "text": "Still here. Still no. You're better company than the one with the form, mind — he read it out to me. Out LOUD. At my own gate.", "next": ""}],
			"choices": [
				{"text": "\"I'm not here to move you. What do you need to hold it another season?\"",
					"resonance": 3.0, "flags": {"ch2_bevin_met": true}, "next": "h_hold"},
				{"text": "\"Ninety years, and it ends with you starving alone in it. That's not holding. That's just being last.\"",
					"resonance": -3.0, "flags": {"ch2_bevin_met": true}, "next": "h_barb"},
			]},
		"h_hold": {"who": "Old Bevin", "text": "...Nothing. That's the answer and it's why nobody likes hearing it. I've water, I've the barn, and the blight comes up the low field and stops at the ditch my grandfather cut — he cut it for DRAINAGE, mind, he'd laugh himself sick. ...You're the first to ask what I need instead of what I'm afraid of. Come by if the road turns. There's a bed in the barn and it's dry.", "next": ""},
		"h_barb": {"who": "Old Bevin", "text": "Last is a job, bearer. Somebody's got to be the one still standing here when the rest come back, or there's nothing to come back TO — just a valley and a story about a valley. ...You'll understand it when there's something you're last for. Everyone gets one eventually.", "next": ""},
	}},
}
