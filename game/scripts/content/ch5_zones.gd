## Chapter 5 zones — The Long Sleep (ice, L28-33, BOSSES.md).
## Content module: 21 rooms — 13 spine (spine = [0..12]) + 8 side.
## Mono-family-not-mono-look: ice throughout, with the seal's keystone
## chambers in terrain "crystal" (Serane's gallery and its wing).
##
## THE CHAPTER: the Still Queen's seal. Whole villages sleep and do not
## die — preserved, dreaming, cold — and a cult of the bereaved carries
## its sleeping kin TOWARD the deep ice, because the Queen's whisper
## promises they wake when she does. Wildfang's winter clans are caught
## in the middle: Whitepelt guards the valley because the cult feeds
## his people through a famine winter. Killing him is policy, not
## triumph — the camp lets you say which it was (Wildfang shifts).
## Serane's death is the arc's quiet tragedy: every herald you stop is
## also a lock you strip.
##
## XP BUDGET (30+22·lvl; enter ~L28.7 off Ordo):
##   -> Whitepelt L29 (~190): opener trash ~250
##   -> Serane L31 (1358, Whitepelt pays 520): trash ~840
##   -> Halla L33 (1446, Serane pays 560): trash ~890
## Full-clear trash below ≈ 1990 + bosses 1720. Needs a playtest pass.

const CHAPTER_ZONES := {
	"ch5": [
		# ---------------------------------------------------- spine ---
		{
			"name": "The Last Fire", "terrain": "ice", "type": "safe",
			"lock_next": "flag:ch5_briefed",
			"merchant": [1050, 480], "shop_tier": "silver",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "beastkin", "x": 620, "y": 500, "prompt": "E — Tracker Yri", "convo": "ch5_briefing"},
				{"sprite": "warden", "x": 1400, "y": 400, "prompt": "E — Accord", "convo": "ch5_accord"},
				{"sprite": "cultist", "x": 1500, "y": 760, "prompt": "E — Gentle Suli", "convo": "ch5_cult"},
				{"sprite": "villager", "x": 800, "y": 800, "prompt": "E — Talk", "convo": "ch5_mother"},
			],
		},
		{
			"name": "The White Road", "terrain": "ice", "type": "combat",
			"enemies": [
				["cold_pilgrim", 480, 300, 0], ["cold_pilgrim", 600, 240, 0], ["cold_pilgrim", 540, 420, 0],
				["cold_pilgrim", 1300, 900, 1], ["cold_pilgrim", 1420, 830, 1], ["cold_pilgrim", 1350, 1000, 1],
				["cold_pilgrim", 1700, 400, 2], ["cold_pilgrim", 1820, 500, 2], ["cold_pilgrim", 1760, 300, 2],
			],
			"boss": "",
		},
		{
			"name": "The Sleeping Village", "terrain": "ice", "type": "combat",
			"enemies": [
				["cold_pilgrim", 450, 320, 0, 29], ["cold_pilgrim", 570, 250, 0, 29],
				["winterfang", 1350, 850, 1], ["winterfang", 1470, 780, 1], ["winterfang", 1420, 950, 1],
				["cold_pilgrim", 1700, 450, 2, 29], ["cold_pilgrim", 1820, 560, 2, 29],
				["winterfang", 1000, 950, 3], ["winterfang", 1130, 880, 3],
			],
			"boss": "",
		},
		{
			"name": "The Watch Ridge", "terrain": "ice", "type": "boss",
			"lock_next": "boss", "clear_flag": "whitepelt_dead",
			"enemies": [["winterfang", 700, 400, 0], ["winterfang", 850, 330, 0], ["winterfang", 780, 520, 0]],
			"boss": "whitepelt", "boss_level": 29,
		},
		{
			"name": "The Drifted Fields", "terrain": "ice", "type": "combat",
			"enemies": [
				["winterfang", 480, 300, 0, 30], ["winterfang", 600, 240, 0, 30], ["winterfang", 540, 430, 0, 30],
				["hushcaller", 1350, 880, 1], ["hushcaller", 1470, 800, 1],
				["winterfang", 1700, 420, 2, 30], ["winterfang", 1820, 530, 2, 30],
				["hushcaller", 1000, 620, 3], ["hushcaller", 1130, 550, 3],
				["cold_pilgrim", 950, 750, 3, 30], ["cold_pilgrim", 1060, 820, 3, 30],
			],
			"boss": "",
		},
		{
			"name": "The Waystation", "terrain": "ice", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Frozen Shore", "terrain": "ice", "type": "combat",
			"enemies": [
				["hushcaller", 450, 320, 0, 31], ["hushcaller", 570, 250, 0, 31], ["hushcaller", 510, 440, 0, 31],
				["hushcaller", 640, 350, 0, 31], ["hushcaller", 700, 260, 0, 31],
				["frozen_guard", 1350, 850, 1], ["frozen_guard", 1470, 780, 1],
				["frozen_guard", 1420, 950, 1], ["frozen_guard", 1540, 880, 1],
				["winterfang", 1750, 420, 2, 31], ["winterfang", 1850, 520, 2, 31], ["winterfang", 1800, 320, 2, 31],
			],
			"boss": "",
		},
		{
			"name": "The Keystone Gallery", "terrain": "crystal", "type": "boss",
			"lock_next": "boss",
			"enemies": [["hushcaller", 700, 420, 0, 31], ["hushcaller", 830, 350, 0, 31]],
			"boss": "icebound", "boss_level": 31,
		},
		{
			"name": "The Processional Ice", "terrain": "ice", "type": "combat",
			"enemies": [
				["hushcaller", 480, 300, 0, 32], ["hushcaller", 600, 240, 0, 32], ["hushcaller", 540, 430, 0, 32],
				["hushcaller", 660, 340, 0, 32],
				["frozen_guard", 1350, 880, 1, 32], ["frozen_guard", 1470, 800, 1, 32],
				["frozen_guard", 1410, 980, 1, 32], ["frozen_guard", 1530, 900, 1, 32],
				["winterfang", 1750, 420, 2, 32], ["winterfang", 1850, 530, 2, 32],
				["hushcaller", 1000, 620, 3, 32], ["hushcaller", 1130, 550, 3, 32],
			],
			"boss": "",
		},
		{
			"name": "The Sledgeway Camp", "terrain": "ice", "type": "merchant",
			"merchant": [1050, 620], "shop_tier": "gold",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Cradle Vale", "terrain": "ice", "type": "combat",
			"enemies": [
				["frozen_guard", 480, 300, 0, 32], ["frozen_guard", 600, 240, 0, 32], ["frozen_guard", 540, 430, 0, 32],
				["frozen_guard", 660, 340, 0, 32], ["frozen_guard", 720, 250, 0, 32],
				["hushcaller", 1350, 880, 1, 32], ["hushcaller", 1470, 800, 1, 32],
				["hushcaller", 1410, 980, 1, 32], ["hushcaller", 1530, 900, 1, 32], ["hushcaller", 1590, 810, 1, 32],
				["cold_pilgrim", 1000, 620, 3, 32], ["cold_pilgrim", 1130, 550, 3, 32],
			],
			"boss": "",
		},
		{
			"name": "The Hymn Road", "terrain": "ice", "type": "combat",
			"enemies": [
				["hushcaller", 480, 300, 0, 32], ["hushcaller", 600, 240, 0, 32], ["hushcaller", 540, 430, 0, 32],
				["hushcaller", 660, 340, 0, 32], ["hushcaller", 720, 250, 0, 32],
				["frozen_guard", 1350, 880, 1, 32], ["frozen_guard", 1470, 800, 1, 32],
				["frozen_guard", 1410, 980, 1, 32], ["frozen_guard", 1530, 900, 1, 32],
				["winterfang", 1750, 420, 2, 32], ["winterfang", 1850, 530, 2, 32], ["winterfang", 1800, 320, 2, 32],
			],
			"boss": "",
		},
		{
			"name": "The Long Sleep", "terrain": "ice", "type": "boss",
			"enemies": [["cold_pilgrim", 700, 420, 0, 32], ["cold_pilgrim", 830, 350, 0, 32]],
			"boss": "sleepkeeper", "boss_level": 33,
		},
		# ----------------------------------------------- side rooms ---
		{
			"name": "The Buried Chapel", "terrain": "ice", "type": "dead_end", "cache": "wood",
			"enemies": [["frozen_guard", 1000, 500, 0], ["frozen_guard", 1150, 560, 0]],
			"boss": "",
			"npcs": [{"sprite": "tombstone", "x": 950, "y": 320, "prompt": "E — Dig", "convo": "ch5_lore_chapel"}],
		},
		{
			"name": "The Sleeper's Wagon", "terrain": "ice", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "deadtree", "x": 1056, "y": 500, "prompt": "E — The Wagon", "convo": "ch5_shrine_wagon"}],
		},
		{
			"name": "The Hunter's Blind", "terrain": "ice", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Wolf Runs", "terrain": "ice", "type": "combat",
			"enemies": [
				["winterfang", 500, 320, 0, 30], ["winterfang", 620, 250, 0, 30], ["winterfang", 560, 440, 0, 30],
				["winterfang", 680, 350, 0, 30], ["winterfang", 740, 260, 0, 30],
				["cold_pilgrim", 1350, 850, 1, 30], ["cold_pilgrim", 1470, 780, 1, 30],
				["cold_pilgrim", 1420, 950, 1, 30], ["cold_pilgrim", 1540, 870, 1, 30],
			],
			"boss": "",
		},
		{
			"name": "The Silent Orchard", "terrain": "ice", "type": "combat",
			"enemies": [
				["hushcaller", 500, 320, 0, 31], ["hushcaller", 620, 250, 0, 31],
				["hushcaller", 560, 440, 0, 31], ["hushcaller", 680, 350, 0, 31],
				["winterfang", 1350, 850, 1, 31], ["winterfang", 1470, 780, 1, 31],
				["winterfang", 1420, 950, 1, 31], ["winterfang", 1540, 870, 1, 31],
				["frozen_guard", 1750, 420, 2], ["frozen_guard", 1850, 530, 2],
			],
			"boss": "",
		},
		{
			"name": "The Vein of the Queen", "terrain": "crystal", "type": "dead_end", "cache": "silver",
			"enemies": [],
			"boss": "",
			"npcs": [{"sprite": "crystal", "x": 950, "y": 330, "prompt": "E — Look", "convo": "ch5_lore_vein"}],
		},
		{
			"name": "The Icebound Vigil", "terrain": "crystal", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "pillar", "x": 1056, "y": 500, "prompt": "E — The Keeper's Ledger", "convo": "ch5_shrine_vigil"}],
		},
		{
			"name": "The Toll Meadow", "terrain": "ice", "type": "combat",
			"enemies": [
				["frozen_guard", 500, 320, 0, 32], ["frozen_guard", 620, 250, 0, 32], ["frozen_guard", 560, 440, 0, 32],
				["frozen_guard", 680, 350, 0, 32], ["frozen_guard", 740, 260, 0, 32],
				["hushcaller", 1350, 850, 1, 32], ["hushcaller", 1470, 780, 1, 32],
				["hushcaller", 1420, 950, 1, 32], ["hushcaller", 1540, 870, 1, 32],
			],
			"boss": "",
		},
	],
}

# Long Sleep monsters. HP on the gear-inclusive dps curve, dmg on the
# parity curve (in-game = base x 1.3).
const ENEMIES := {
	"cold_pilgrim": {"name": "Cold Pilgrim", "sprite": "cultist", "hp": 330.0, "dmg": 58.0, "speed": 95.0, "xp": 13, "gold": 20, "ranged": false, "scale": 3.2,
		"physres": 20.0, "magres": 30.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 28, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["mend"],
		"lore": "Cult porters who walked the white road one too many times. They still walk it. They no longer bring wagons, or come back."},
	"winterfang": {"name": "Winterfang", "sprite": "winterfang", "hp": 340.0, "dmg": 62.0, "speed": 190.0, "xp": 14, "gold": 20, "ranged": false, "scale": 3.1,
		"physres": 15.0, "magres": 20.0, "eva": 0.05, "critres": 0.0, "dmg_type": "phys",
		"level": 29, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["pounce"],
		"lore": "The winter clans' wolves, gone strange around the sleeping valley — they circle the dreamers like shepherds, and eat anyone who isn't one."},
	"hushcaller": {"name": "Hushcaller", "sprite": "banshee", "hp": 350.0, "dmg": 66.0, "speed": 100.0, "xp": 16, "gold": 22, "ranged": true, "scale": 3.3,
		"physres": 10.0, "magres": 42.0, "eva": 0.05, "critres": 2.0, "dmg_type": "magic",
		"level": 30, "hp_g": 0.11, "dmg_g": 0.10, "traits": ["snare"],
		"lore": "The cult's cantors, who sing the Queen's lullaby at anything awake. They are not angry with you. They think you look tired."},
	"frozen_guard": {"name": "Frozen Guard", "sprite": "royal_knight", "hp": 460.0, "dmg": 70.0, "speed": 130.0, "xp": 16, "gold": 22, "ranged": false, "scale": 3.3,
		"physres": 42.0, "magres": 20.0, "eva": 0.0, "critres": 3.0, "dmg_type": "phys",
		"level": 31, "hp_g": 0.11, "dmg_g": 0.09, "traits": ["frost_aura", "swift"],
		"lore": "Sentries of the old keystone garrison, six hundred years at their posts. The Queen's whisper never asked them to sleep — someone has to hold the door."},
}

const QUESTS := {
	"ch5_start": "Report to Tracker Yri at the Last Fire  (walk up to her and press E)",
	"whitepelt": "Take the white road — move HROLGAR WHITEPELT off the Watch Ridge",
	"icebound": "Descend to the keystone and face SERANE THE ICEBOUND",
	"sleepkeeper": "Follow the hymn north — end MOTHER HALLA's long sleep",
	"done_ch5": "The lullaby ends. East, in the deep bog, something is growing...",
}

const BEATS := {
	"pre_whitepelt": [
		["Hrolgar Whitepelt", "Stop there, bearer. I know why you've come, and I want you to hear it from me plain: I know what's in the wagons. I've known all winter."],
		["Hrolgar Whitepelt", "The cult feeds my clan — forty mouths, famine snow — and the price is this ridge. You'd have done the same. You're about to prove you'd do WORSE."],
	],
	"post_whitepelt": [
		["Narrator", "The pack does not scatter. They come down off the rocks, quiet as snowfall, take up their chieftain's body, and drag him home through the drifts. Not one of them looks at you."],
		["Narrator", "The ridge stands open. It doesn't feel like a victory, because it wasn't one — it was policy. The white road runs on, downhill, toward something singing."],
	],
	"pre_icebound": [
		["Serane the Icebound", "Six hundred years, four heralds, and eleven thieves have reached this gallery. I am going to tell you what I told each of them: the keystone holds while I hold. TURN BACK."],
		["Serane the Icebound", "...You won't. None of them did either. Very well, bearer — I have been the lock on this door since before your bloodline had a name. Show me it was worth waking up for."],
	],
	"post_icebound": [
		["Serane the Icebound", "So. Strong enough after all. Then hear the accounting, bearer, while I still owe it: I was the LOCK. My ember, the bolt on her door. You have not freed this valley..."],
		["Serane the Icebound", "...you have unbarred it. She will test the door within the year. Be... be better than eleven thieves, when she does. Someone must be."],
		["Narrator", "The frost on her face melts last from around a smile six centuries old — relieved, at the very end, that the watch is at least OVER. The keystone hums on, one voice short."],
	],
	"pre_sleepkeeper": [
		["Mother Halla", "Oh, child. Look how far you've walked, and how heavy. Whitepelt, Serane — you've been carrying them for miles, haven't you. Sit. SIT. No one here will hurt you."],
		["Mother Halla", "I lost three to the famine before the Queen taught me: the cold isn't the enemy, the WAKING is. Everyone I gather sleeps safe until the morning she brings. I would so like you to stop fighting mornings. Ssshh, now."],
	],
	"epilogue_ch5": [
		["Narrator", "Halla folds down into the snow with no violence at all, like a candle relieved of its flame. Around the arena, one by one, the dreamers stop drifting — and some of them, some, begin to shiver. Shivering is what waking cold feels like. It is the best sound you have heard in weeks."],
		["Tracker Yri", "The clans will carry the sleepers to fires and see who rises. Some won't. Hear me, bearer: the ones who do rise, rise because of you — let that argue with the ridge, on the nights it needs arguing with."],
		["Narrator", "The Queen dreams on beneath the ice, her lock one voice weaker, her lullaby unsung. And out of the east, carried over the frozen shore, comes a smell with no business in winter: green. Growing things. A spring that nobody planted, in a bog where nothing should bloom."],
	],
}

const WANDERERS := {
	"ch5": [
		{"sprite": "beastkin", "prompt": "E — Talk", "convo": "ch5_wander_skald"},
		{"sprite": "cultist", "prompt": "E — Talk", "convo": "ch5_wander_driver"},
		{"sprite": "warden", "prompt": "E — Talk", "convo": "ch5_wander_mapper"},
		{"sprite": "merchant", "prompt": "E — Talk", "convo": "ch5_wander_memories"},
		{"sprite": "sentry", "prompt": "E — Talk", "convo": "ch5_wander_deserter"},
	],
}

const CONVOS := {
	# ---- Tracker Yri: Wildfang winter clan. The Whitepelt problem is
	# HER problem — she frames it as policy before you go, and takes your
	# accounting after (the kill shifts Wildfang either way, by what you
	# SAY about it — BOSSES.md).
	"ch5_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Tracker Yri",
			"text": "So the south sends a shard-bearer. Yri, Wildfang — winter clans. Before anything else, understand what you're walking into: nobody out there is evil. That's what makes this one hard.",
			"variants": [
				{"flag": "ch5_debrief_done", "text": "The road's yours, bearer. Walk it warm.", "next": ""},
				{"flag": "whitepelt_dead", "next": "y_after", "text": "You came back. Sit by the fire — there's an accounting between us, and I'd have it now."},
				{"flag": "ch5_briefed", "text": "The ridge first, bearer. And remember what I said about Hrolgar — POLICY. Keep it policy.", "next": ""},
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
		"y_honor": {"who": "Tracker Yri", "text": "...Sing him honest. Aye. The clans will hear that a stranger spoke of Hrolgar like a chieftain and not a toll-gate — that buys more peace than the grain did, and I'll see the grain replaced somehow. Walk warm, bearer. You just did.", "next": ""},
		"y_cold": {"who": "Tracker Yri", "text": "'The arrangement.' Forty children, bearer — that was the arrangement. ...No. You're not wrong, and I'll not pretend you are. But the clans will hear a southerner call our chieftain a toll-keeper over his own cairn, and winters are long, and we REMEMBER things in winter. Go do your keystone.", "next": ""},
	}},

	# ---- The Accord's hardest ask in the act: they KNOW what killing
	# Serane costs, and ask anyway.
	"ch5_accord": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Sighne",
			"text": "Warden Sighne, Accord — and I'll not soften this one, bearer, because you've earned the unsoftened version. The keystone under the frozen shore is held by one of OURS. Serane, Ember Guard, volunteered six hundred years ago to freeze at the seal as its living lock. She is still there. She is still loyal. And the Waking is wearing her through like rot through a roofbeam.",
			"variants": [
				{"flag": "ch5_accord_heard", "text": "The arithmetic hasn't improved: she falls to you clean, or to the Queen slow. Flame forgive us both the sum.", "next": ""},
			],
			"next": "a2"},
		"a2": {"who": "Warden Sighne", "text": "Six centuries of strain have bent her one certainty into this: ANYONE who reaches the keystone has come to open it. She will kill you believing she's saving the world — and if you kill her, the seal weakens; the lock IS her. Maren ran the arithmetic a dozen ways. A failing lock that kills pilgrims buys less time than a clean death and a watched door. So we ask. Flame forgive us, we ask.",
			"choices": [
				{"text": "\"Then she gets what six hundred years earned: a witness who knows what she was, and a clean end.\"",
					"resonance": 6.0, "faction": {"accord": 4}, "flags": {"ch5_accord_heard": true}, "next": "a_witness"},
				{"text": "\"You're sending me to kill your own best soldier and calling it arithmetic.\"",
					"resonance": 0.0, "flags": {"ch5_accord_heard": true}, "next": "a_truth"},
			]},
		"a_witness": {"who": "Warden Sighne", "text": "A witness. Yes. Six hundred years and the last thing she'll see is someone who KNOWS. ...When it's done, there's a ledger in the gallery — the keepers' vigil-book. Read her line. It's four words long and it will break your heart, and she deserves both.", "next": ""},
		"a_truth": {"who": "Warden Sighne", "text": "Yes. That is exactly what we're doing, and I'll thank you not to let me forget it. The Accord's whole war is choosing which debts to default on, bearer. Serane taught us HOW — she just never planned on being one of them.", "next": ""},
	}},

	# ---- Gentle Suli: the cult, at its most honest and most chilling.
	"ch5_cult": {"start": "s1", "nodes": {
		"s1": {"who": "Gentle Suli",
			"text": "You've the look of someone about to do violence to my faith, so let's be civil first — Suli. I drive wagons for the Long Sleep. And before your face does the thing every southern face does: my daughter is on one of those wagons. I put her there. She was dying, bearer. Now she is DREAMING, and when the Queen's morning comes—",
			"variants": [
				{"band": "steady", "text": "You again — or still. You burn steady, don't you. Warm. My daughter used to... hm. Ask your questions, steady one. I find I don't mind them from you."},
				{"flag": "ch5_suli_asked", "text": "The wagons roll regardless, bearer. That's the thing about faith and about winter: neither waits on either of us.", "next": ""},
			],
			"next": "s2"},
		"s2": {"who": "Gentle Suli", "text": "—when the morning comes, she wakes healed. That's the promise. Sixty fevers, forty famines, one promise. You want to tell me it's a lie, and here is why you'll fail: nobody who sleeps has died. Not one, in nine years. Show me another faith in Vaelscar with THAT record.",
			"choices": [
				{"text": "\"Nobody's died because nobody's finished, Suli. A held breath isn't a record — ask Serane what the Queen keeps things FOR.\"",
					"resonance": 4.0, "flags": {"ch5_suli_asked": true}, "next": "s_press"},
				{"text": "\"...What was her name? Your daughter.\"",
					"resonance": 3.0, "flags": {"ch5_suli_asked": true}, "next": "s_name"},
			]},
		"s_press": {"who": "Gentle Suli", "text": "Kept things. KEPT things— no. No, you'll not hand me that cold arithmetic over my own child. ...Though I'll tell you what I've never told the shepherd: some nights, driving, I hear the ice under the wagons. And it doesn't sound like a nursery, bearer. It sounds like a PANTRY. There. Now we've both said the unsayable, and the wagons roll anyway.", "next": ""},
		"s_name": {"who": "Gentle Suli", "text": "...Wren. Nine years old, forever now, I suppose. You're the first southerner to ask the name instead of the doctrine. The doctrine I can defend all night — the name, the name I just miss. Go on, bearer. Do whatever you came to do to my faith. Gently, if there's a gentle way.", "next": ""},
	}},
	"ch5_mother": {"start": "m1", "nodes": {
		"m1": {"who": "Ansa of the Shore",
			"text": "My husband and both boys sleep in the valley. I didn't consent — I was at market, one day, ONE day, and Halla's people came through our village singing, and when I got home the beds were empty and the neighbor said they walked out SMILING. Smiling. My youngest is afraid of the dark, bearer. Nobody who knows him would believe he walked toward that ice glad.",
			"variants": [{"flag": "ch5_ansa_heard", "text": "You remember — Toma fears the dark. If the sleep breaks and he wakes far from home... someone kind should be the first thing he sees. Let it be soon.", "next": ""}],
			"choices": [
				{"text": "\"Toma, was it? If the sleepers wake when this ends, I'll see the criers carry word to the shore first.\"",
					"resonance": 4.0, "flags": {"ch5_ansa_heard": true}, "next": "m_kind"},
				{"text": "\"Hold to this: the singing needs a singer. Singers can be stopped.\"",
					"resonance": 0.0, "flags": {"ch5_ansa_heard": true}, "next": "m_flint"},
			]},
		"m_kind": {"who": "Ansa of the Shore", "text": "Toma. Yes. ...You said WHEN, not if. I've had a winter of 'if' from every warden and clerk on this shore. I'm going to keep your 'when', bearer — don't make it a lie.", "next": ""},
		"m_flint": {"who": "Ansa of the Shore", "text": "Stopped. ...There's a word everyone's been walking around all winter. Aye. Stop her, bearer — and if my boys can hear anything down there, they'll hear the quiet where the lullaby was, and know to swim for it.", "next": ""},
	}},

	# ---- Resonance rooms: the wagon (the chapter's centerpiece choice)
	# and the vigil ledger.
	"ch5_shrine_wagon": {"start": "w1", "nodes": {
		"w1": {"who": "Narrator",
			"text": "A cult wagon, stopped mid-road — the porter froze dead in the traces days ago, still leaning north. Under the frosted canvas: eleven sleepers, laid like cordwood, breathing once a minute. One is a child clutching a wooden horse. North lies the deep ice and the Queen's promised morning. South, the waystation, fires, and the slow lottery of waking cold. The wagon cannot stay here. The choice of WHERE it goes appears to be yours, and the shard in you is very quiet, the way it goes quiet at the real ones.",
			"variants": [{"flag": "wagon_decided", "text": "The wagon is gone from the road — moved by your hands, whichever way. The wheel-ruts point the way you chose, filling slowly with snow, and the shard keeps its opinion to itself.", "next": ""}],
			"choices": [
				{"text": "Haul it SOUTH, to the waystation fires. Waking is a risk; the Queen's pantry is a promise. Choose the risk for them.",
					"resonance": 8.0, "flags": {"wagon_decided": true, "chose_wagon_south": true}, "next": "w_south"},
				{"text": "Haul it NORTH, as the porter promised the families. Their kin chose the sleep — finishing another's vow is not yours to unmake.",
					"resonance": -6.0, "flags": {"wagon_decided": true, "chose_wagon_north": true}, "next": "w_north"},
				{"text": "Unhitch the traces and leave the wagon on the road. Not every burden that finds you is yours.",
					"resonance": -3.0, "flags": {"wagon_decided": true}, "next": "w_leave"},
			]},
		"w_south": {"who": "Narrator", "text": "The traces bite your shoulders for two frozen miles. At the waystation they take the sleepers in by the fire, and by dusk three are shivering, and by night one — the child — opens her eyes and asks, furious, where her horse is. It's in her hand. Some of the others may never wake; you chose their risk without their leave, and you will carry that. She's holding the horse, though. She's HOLDING it.", "next": ""},
		"w_north": {"who": "Narrator", "text": "You lean where the porter leaned, and haul the vow to its keeping. At the ice-line the cult receives the wagon with tears of plain gratitude — eleven promises delivered, they say, eleven sleepers safe till morning. The shard says nothing all the long walk back. It is thinking, you suspect, about the difference between honoring a promise and FEEDING one, and it is glad, for once, that the thinking is yours to do.", "next": ""},
		"w_leave": {"who": "Narrator", "text": "You unhitch the dead porter and lay him decently by the road, and leave the wagon anchored where it stands. Someone will find it — the cult, the clans, the wardens; the road is walked. Someone with more right, you tell yourself, or at least more certainty. The snow starts an hour later. You do not go back to check. That, too, is a choice, and the shard files it with the others.", "next": ""},
	}},
	"ch5_shrine_vigil": {"start": "v1", "nodes": {
		"v1": {"who": "Narrator",
			"text": "A reading stand of black ice, and chained to it the KEEPERS' LEDGER — six hundred years of vigil entries in a fading relay of hands. Most entries are a single line: WATCH HELD. NOTHING CAME. Page after page after century. The last entry in the book is Serane's, from the morning she volunteered to freeze: four words. 'SOMEONE MUST. I CAN.' Below it, half the page stands empty — room, the binding implies, for whoever comes next. The stand holds a pen of ice that has never once melted.",
			"variants": [{"flag": "vigil_signed", "text": "The ledger lies open where you left it. Your line — or the space where a line could be — has already outlasted three snowfalls. The pen waits, as pens do.", "next": ""}],
			"choices": [
				{"text": "Take the pen. Write your name under hers, and mean it: when the seals want keeping, count you among the keepers.",
					"resonance": 8.0, "flags": {"vigil_signed": true, "chose_kept_vigil": true}, "next": "v_sign"},
				{"text": "Snap a splinter from the keystone's vein while nothing guards it. Six hundred years of stored cold, in your palm.",
					"resonance": -8.0, "flags": {"vigil_signed": true}, "next": "v_take"},
				{"text": "Read every page. Sign nothing, take nothing — some books only want a witness.",
					"resonance": 0.0, "flags": {"vigil_signed": true}, "next": "v_read"},
			]},
		"v_sign": {"who": "Narrator", "text": "The ice pen writes in melt that refreezes glass-clear. Your name sits under SOMEONE MUST. I CAN., smaller than hers, which is correct. Nothing magical happens — no surge, no chorus. Just a ledger that is now, technically, expecting you. It is astonishing how much heavier the road feels, and how much straighter you walk it.", "next": ""},
		"v_take": {"who": "Narrator", "text": "The splinter comes free with a sound like a promise clearing its throat. Cold sits in your palm — dense, potent, six centuries deep — and the Ember drinks it and shivers with pleasure. From the ledger stand, no rebuke; the book merely stays open at Serane's page, four words facing you the whole time you work. SOMEONE MUST. I CAN. The splinter is worth it. You will need to keep telling yourself the splinter was worth it.", "next": ""},
		"v_read": {"who": "Narrator", "text": "Six hundred years takes two hours to read when most of it is WATCH HELD. NOTHING CAME. Somewhere in the third century a keeper adds, once: 'lonely.' Never again. You close the book and stand a while. Nothing came, page after page — because they were THERE, page after page. It's the quietest heroism in Vaelscar, and it fit on one line a night.", "next": ""},
	}},

	# ---- Dead-end lore.
	"ch5_lore_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A village chapel drowned in snow to the bell-rope. Digging down, you find the door ajar and the pews full: the whole congregation, asleep in their coats, frost-lace on their folded hands. The altar candle burned down years ago. On the lectern, the priest's last sermon sits open, one line underlined twice: 'THE FLAME ALSO RESTS, BUT IT DOES NOT LET THE HEARTH GO COLD.' He is not among the sleepers. His footprints, they say, went north alone — to argue with the Queen in person, and no one has ever found the end of them.", "next": ""},
	}},
	"ch5_lore_vein": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The keystone's crystal vein runs through the gallery wall like frozen lightning, and deep inside it — a meter into solid crystal — hang flowers. Meadow flowers, summer-bright, mid-sway, six hundred years old. The Concord's binders sealed the Queen in high summer, and she took one armful of it down with her. Preservation, the scholars call her domain. Standing here, you'd call it homesickness with a jaw that never unclenches.", "next": ""},
	}},

	# ---- Social wanderers.
	"ch5_wander_skald": {"start": "k1", "nodes": {
		"k1": {"who": "Skald Ottar",
			"text": "A song for the road, southerner? I've a hundred of winter and one of spring, and nobody ever asks for the spring one. Winter-clan taste. We like our songs the way we like our news: bad, but survivable.",
			"variants": [{"flag": "ch5_ottar_met", "text": "Back for the spring song after all? Everyone comes back for it eventually. Usually the same week they start checking the ice for cracks.", "next": ""}],
			"choices": [
				{"text": "\"Sing the spring one, skald.\"", "resonance": 2.0, "flags": {"ch5_ottar_met": true}, "next": "k_spring"},
				{"text": "\"What's the newest winter song about?\"", "flags": {"ch5_ottar_met": true}, "next": "k_winter"},
			]},
		"k_spring": {"who": "Skald Ottar", "text": "He sings it — short, unadorned, a thaw and a river and someone's boots by a door. Halfway through, three strangers at the fire go quiet and stare into their cups, and by the end a wagon-driver is weeping without noise. \"That's why nobody asks for it,\" Ottar says, retuning. \"Winter songs let you stay hard. The spring one reminds you what you're staying hard FOR.\"", "next": ""},
		"k_winter": {"who": "Skald Ottar", "text": "The newest? 'The Ridge-Toll.' A chieftain who fed his clan on a bad bargain and died standing on it. ...Aye, THAT ridge. Songs travel faster than wagons, southerner. The clans are already deciding what the verse about YOU sounds like — I'd give them a good final line if I were you.", "next": ""},
	}},
	"ch5_wander_driver": {"start": "d1", "nodes": {
		"d1": {"who": "Wagon-Driver Pell",
			"text": "Off shift. Don't preach at me — I know what I haul, I've made my peace, we're saving them, it's all in the catechism. ...You're not preaching. Huh. That's worse, somehow. The quiet ones always get me talking.",
			"variants": [{"flag": "ch5_pell_met", "text": "Still off shift. Longest off-shift of my career, if anyone asks. The wagons roll fine without me. That's the trouble — everything about this rolls fine without anyone.", "next": ""}],
			"choices": [
				{"text": "Stay quiet. Let him talk.", "flags": {"ch5_pell_met": true}, "next": "d_talk"},
			]},
		"d_talk": {"who": "Wagon-Driver Pell", "text": "Nine years hauling sleepers and I never once looked under the canvas — professional courtesy, I called it. Last month a strap broke and I HAD to. They're smiling, bearer. All of them, the same smile, the exact same smile, like something drew it on. My mother smiles her own way. Everyone does. ...I haven't taken a shift since. You can put THAT in whatever report you're not writing.", "next": ""},
	}},
	"ch5_wander_mapper": {"start": "m1", "nodes": {
		"m1": {"who": "Cartographer Bree (Accord)",
			"text": "Mind the ink, it freezes — I'm mapping the sleep-line. Every season I chart where the 'safe to sleep outdoors' boundary sits, and every season it's moved SOUTH. Eleven miles in four years. The Queen's reach grows like a tide that forgot how to go out.",
			"variants": [{"flag": "ch5_bree_met", "text": "Latest survey's done. The line held this season — first time in four years it didn't move. Somebody up-valley is doing something RIGHT, and my professional guess is standing in front of me.", "next": ""}],
			"choices": [
				{"text": "\"What happens when the line reaches the towns?\"", "flags": {"ch5_bree_met": true}, "next": "m_towns"},
			]},
		"m_towns": {"who": "Cartographer Bree (Accord)", "text": "Then people stop needing the cult, because the sleep comes to THEM. That's the map's real message, bearer — the wagons are a symptom. The tide is the disease. Eleven miles in four years, and the first town sits nineteen miles out. You can do that arithmetic as well as I can, and I do it every night.", "next": ""},
	}},
	"ch5_wander_memories": {"start": "w1", "nodes": {
		"w1": {"who": "Peddler Onna",
			"text": "Warm memories! Bottled proper — a hayloft in August, a kitchen with bread in it, somebody's grandmother humming. Two coppers a sniff. Fine, fine, it's spiced oil and suggestion, but out HERE suggestion is nine-tenths of warm, and my customers sleep better. ...Poor phrasing. They REST better.",
			"variants": [{"flag": "ch5_onna_met", "text": "Restocked the hayloft one — it sells out first, always. Whole valley freezing toward one enormous sleep and everyone's favorite dream is still August. There's a sermon in that, if anyone decent were around to give it.", "next": ""}],
			"choices": [
				{"text": "\"Two coppers, then. The kitchen one.\"", "flags": {"ch5_onna_met": true}, "next": "w_buy"},
			]},
		"w_buy": {"who": "Peddler Onna", "text": "The kitchen it is. — And there it is, see, right there in your shoulders: everyone drops an inch when the bread-smell hits. That inch is what I actually sell, bearer. The Queen promises forever-sleep and I move two-copper augusts, and between the two of us, I know whose customers wake up.", "next": ""},
	}},
	"ch5_wander_deserter": {"start": "s1", "nodes": {
		"s1": {"who": "Ridge Deserter",
			"text": "Aye, I ran from the Watch Ridge — say it. Hrolgar took the cult's grain and I ate my share all winter and one morning I watched a wagon go by with a foot showing under the canvas, a small one, and my share stopped going down right. So I walked. A man can be too poor for principles and still choke on the lack of them.",
			"variants": [{"flag": "ch5_deserter_met", "text": "Still here. Still fed — the waystation trades stew for firewood, no questions. Turns out that's all I ever wanted: a meal nobody slept for.", "next": ""}],
			"choices": [
				{"text": "\"You walked when walking cost you your place. That's not desertion — that's the first honest sum anyone's done up there.\"",
					"resonance": 3.0, "flags": {"ch5_deserter_met": true}, "next": "s_kind"},
				{"text": "\"You ate the grain all winter first.\"", "resonance": -3.0, "flags": {"ch5_deserter_met": true}, "next": "s_hard"},
			]},
		"s_kind": {"who": "Ridge Deserter", "text": "...First honest sum. Hrolgar would've laughed at that — he liked his sums the other way, all forty mouths on one side and the canvas never lifted. Flame keep him anyway. He fed us. Both those things, bearer. Winter makes you hold both.", "next": ""},
		"s_hard": {"who": "Ridge Deserter", "text": "Aye. I did. And you've eaten this winter too, bearer, and I'd wager you haven't audited every field your bread came from. The difference between us is one lifted canvas. I hope you never see yours — and I hope you DO.", "next": ""},
	}},
}
