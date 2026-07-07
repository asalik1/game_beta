## Chapter 3 zones — The Unburied Vale (graveyard, L16-22, BOSSES.md).
## Content module (see README.md): 21 rooms — 13 spine (authored FIRST,
## story order; Story.CHAPTERS.ch3.spine = [0..12]) + 8 side rooms that
## attach to same-terrain hosts at layout time. The Vale drifts
## mono-family-not-mono-look: misted fields -> barrows -> crypt stone
## (terrain "keep") -> Varo's cathedral.
##
## THE CHAPTER: the Hollow Choir's heartland after the Choir Mother's
## death. The Choir does not bury its dead — the Vale is a funeral that
## never ends, and the factions sharpen their pitches over its ashes
## (the mid-act pivot where alignment starts to matter). Your guide is
## Cantor Ilse, a Choir defector who wants her congregation's saint
## released — which the Choir calls murdering him.
##
## XP BUDGET (DESIGN r5: sum authored pack XP on 30+22·lvl; land boss
## rooms AT boss level; boss adds/elites/events pay zero):
##   enter ~L16 -> Sexton L17 (382): trash ~370
##   -> Vess L19 (830, Sexton pays 260): trash ~570
##   -> Varo L22 (1410, Vess pays 300): trash ~1090
## Full-clear trash below ≈ 2005 + bosses 960 vs 2622 for 16->22 (the
## curve assumes side rooms; spine-only runs land ~1 under, by design).
## Needs a playtest pass at story level.

const CHAPTER_ZONES := {
	"ch3": [
		# ---------------------------------------------------- spine ---
		{
			"name": "The Vigil Gate", "terrain": "graveyard", "type": "safe",
			"lock_next": "flag:ch3_briefed",
			"merchant": [1050, 480], "shop_tier": "silver",
			"enemies": [], "boss": "",
			"npcs": [
				{"sprite": "choirmother", "x": 620, "y": 500, "prompt": "E — Cantor Ilse", "convo": "ch3_briefing"},
				{"sprite": "warden", "x": 1400, "y": 400, "prompt": "E — Accord", "convo": "ch3_accord"},
				{"sprite": "envoy", "x": 1500, "y": 760, "prompt": "E — Cinderborn", "convo": "ch3_cinder"},
				{"sprite": "villager", "x": 800, "y": 800, "prompt": "E — Talk", "convo": "ch3_refugee"},
			],
		},
		{
			"name": "The Misted Fields", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["gravewalker", 480, 300, 0], ["gravewalker", 600, 240, 0], ["gravewalker", 540, 420, 0],
				["gravewalker", 1300, 900, 1], ["gravewalker", 1420, 830, 1], ["gravewalker", 1350, 1000, 1],
				["gravewalker", 1700, 400, 2], ["gravewalker", 1820, 500, 2],
				["gravewalker", 950, 620, 3], ["gravewalker", 1080, 550, 3],
			],
			"boss": "",
		},
		{
			"name": "Casket Row", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["gravewalker", 450, 320, 0], ["gravewalker", 570, 250, 0], ["gravewalker", 510, 440, 0],
				["barrow_wight", 1350, 850, 1], ["barrow_wight", 1470, 780, 1],
				["gravewalker", 1700, 450, 2], ["gravewalker", 1820, 560, 2], ["gravewalker", 1760, 340, 2],
				["barrow_wight", 1000, 950, 3], ["barrow_wight", 1130, 880, 3],
			],
			"boss": "",
		},
		{
			"name": "The Sexton's Yard", "terrain": "graveyard", "type": "boss",
			"lock_next": "boss",
			"enemies": [["gravewalker", 700, 400, 0, 17], ["gravewalker", 850, 330, 0, 17], ["gravewalker", 780, 520, 0, 17]],
			"boss": "sexton", "boss_level": 17,
		},
		{
			"name": "Potter's Field", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["barrow_wight", 480, 300, 0], ["barrow_wight", 600, 240, 0], ["barrow_wight", 540, 430, 0],
				["vale_mourner", 1350, 880, 1], ["vale_mourner", 1470, 800, 1],
				["barrow_wight", 1700, 420, 2], ["barrow_wight", 1820, 530, 2], ["barrow_wight", 1760, 310, 2],
				["vale_mourner", 1000, 620, 3], ["vale_mourner", 1130, 550, 3],
				["gravewalker", 950, 750, 3, 17], ["gravewalker", 1060, 820, 3, 17],
			],
			"boss": "",
		},
		{
			"name": "Mourners' Walk", "terrain": "graveyard", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Weeping Barrows", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["gravewalker", 450, 320, 0, 18], ["gravewalker", 570, 250, 0, 18], ["gravewalker", 510, 440, 0, 18],
				["gravewalker", 640, 350, 0, 18], ["gravewalker", 700, 260, 0, 18],
				["barrow_wight", 1350, 850, 1, 18], ["barrow_wight", 1470, 780, 1, 18],
				["barrow_wight", 1420, 950, 1, 18], ["barrow_wight", 1540, 880, 1, 18],
				["vale_mourner", 1750, 420, 2], ["vale_mourner", 1850, 520, 2], ["vale_mourner", 1800, 320, 2],
			],
			"boss": "",
		},
		{
			"name": "The Silent Aisle", "terrain": "graveyard", "type": "boss",
			"lock_next": "boss",
			"enemies": [["vale_mourner", 700, 420, 0, 19], ["vale_mourner", 830, 350, 0, 19]],
			"boss": "vess", "boss_level": 19,
		},
		{
			"name": "Liturgy Road", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["casket_creeper", 480, 300, 0], ["casket_creeper", 600, 230, 0], ["casket_creeper", 540, 420, 0],
				["casket_creeper", 660, 340, 0], ["casket_creeper", 720, 250, 0],
				["vale_mourner", 1350, 880, 1, 19], ["vale_mourner", 1470, 800, 1, 19],
				["vale_mourner", 1400, 980, 1, 19], ["vale_mourner", 1520, 900, 1, 19],
				["barrow_wight", 1750, 420, 2, 19], ["barrow_wight", 1850, 530, 2, 19], ["barrow_wight", 1800, 320, 2, 19],
			],
			"boss": "",
		},
		{
			"name": "Pilgrims' Rest", "terrain": "graveyard", "type": "merchant",
			"merchant": [1050, 620], "shop_tier": "gold",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Endless Procession", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["vale_mourner", 480, 300, 0, 20], ["vale_mourner", 600, 240, 0, 20], ["vale_mourner", 540, 430, 0, 20],
				["vale_mourner", 1350, 880, 1, 20], ["vale_mourner", 1470, 800, 1, 20], ["vale_mourner", 1410, 980, 1, 20],
				["casket_creeper", 1700, 420, 2, 20], ["casket_creeper", 1820, 530, 2, 20],
				["casket_creeper", 1760, 320, 2, 20], ["casket_creeper", 1880, 420, 2, 20],
				["casket_creeper", 1000, 620, 3, 20], ["casket_creeper", 1130, 550, 3, 20],
				["barrow_wight", 950, 760, 3, 20], ["barrow_wight", 1080, 830, 3, 20],
			],
			"boss": "",
		},
		{
			"name": "The Cathedral Approach", "terrain": "keep", "type": "combat",
			"enemies": [
				["barrow_wight", 480, 300, 0, 21], ["barrow_wight", 600, 240, 0, 21], ["barrow_wight", 540, 430, 0, 21],
				["barrow_wight", 660, 340, 0, 21],
				["vale_mourner", 1350, 880, 1, 21], ["vale_mourner", 1470, 800, 1, 21],
				["vale_mourner", 1410, 980, 1, 21], ["vale_mourner", 1530, 900, 1, 21],
				["barrow_wight", 1750, 420, 2, 21], ["barrow_wight", 1850, 530, 2, 21],
				["casket_creeper", 1000, 620, 3, 21], ["casket_creeper", 1130, 550, 3, 21],
			],
			"boss": "",
		},
		{
			"name": "The Unrotting Cathedral", "terrain": "keep", "type": "boss",
			"enemies": [["barrow_wight", 700, 420, 0, 21], ["barrow_wight", 830, 350, 0, 21]],
			"boss": "saint_varo", "boss_level": 22,
		},
		# ----------------------------------------------- side rooms ---
		{
			"name": "The Hollow Chapel", "terrain": "graveyard", "type": "dead_end", "cache": "wood",
			"enemies": [["barrow_wight", 1000, 500, 0, 18], ["barrow_wight", 1150, 560, 0, 18]],
			"boss": "",
			"npcs": [{"sprite": "tombstone", "x": 950, "y": 320, "prompt": "E — Read", "convo": "ch3_lore_chapel"}],
		},
		{
			"name": "The First Grave", "terrain": "graveyard", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "tombstone", "x": 1056, "y": 500, "prompt": "E — The Open Grave", "convo": "ch3_shrine_grave"}],
		},
		{
			"name": "The Gravedigger's Hut", "terrain": "graveyard", "type": "social",
			"enemies": [], "boss": "",
		},
		{
			"name": "The Bone Orchard", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["gravewalker", 500, 320, 0, 17], ["gravewalker", 620, 250, 0, 17], ["gravewalker", 560, 440, 0, 17],
				["gravewalker", 680, 350, 0, 17], ["gravewalker", 740, 260, 0, 17],
				["barrow_wight", 1350, 850, 1], ["barrow_wight", 1470, 780, 1], ["barrow_wight", 1420, 950, 1],
			],
			"boss": "",
		},
		{
			"name": "Widow's Row", "terrain": "graveyard", "type": "combat",
			"enemies": [
				["vale_mourner", 500, 320, 0, 19], ["vale_mourner", 620, 250, 0, 19],
				["vale_mourner", 560, 440, 0, 19], ["vale_mourner", 680, 350, 0, 19],
				["barrow_wight", 1350, 850, 1, 19], ["barrow_wight", 1470, 780, 1, 19],
				["barrow_wight", 1420, 950, 1, 19], ["barrow_wight", 1540, 870, 1, 19],
			],
			"boss": "",
		},
		{
			"name": "The Ossuary Stair", "terrain": "keep", "type": "combat",
			"enemies": [
				["barrow_wight", 500, 320, 0, 21], ["barrow_wight", 620, 250, 0, 21], ["barrow_wight", 560, 440, 0, 21],
				["vale_mourner", 1350, 850, 1, 21], ["vale_mourner", 1470, 780, 1, 21],
				["vale_mourner", 1420, 950, 1, 21], ["vale_mourner", 1540, 870, 1, 21],
				["casket_creeper", 1750, 420, 2, 21], ["casket_creeper", 1850, 530, 2, 21], ["casket_creeper", 1800, 320, 2, 21],
			],
			"boss": "",
		},
		{
			"name": "The Kneeling Field", "terrain": "keep", "type": "resonance",
			"enemies": [], "boss": "",
			"npcs": [{"sprite": "villager", "x": 1056, "y": 500, "prompt": "E — The Congregation", "convo": "ch3_shrine_kneeling"}],
		},
		{
			"name": "The Reliquary of Rot", "terrain": "keep", "type": "dead_end", "cache": "silver",
			"enemies": [],
			"boss": "",
			"npcs": [{"sprite": "pillar", "x": 950, "y": 330, "prompt": "E — Look", "convo": "ch3_lore_reliquary"}],
		},
	],
}

# Vale monsters — the congregation that never got buried. Anchored at
# their spawn levels; hp calibrated to the gear-inclusive player dps
# curve (~224 x 1.12^(lvl-17)) for ~1s single-target TTK, dmg on the
# ~5.5%/lvl parity curve (in-game = base x 1.3 ENEMY_DMG_MULT).
const ENEMIES := {
	"gravewalker": {"name": "Unburied Walker", "sprite": "zombie", "hp": 120.0, "dmg": 24.0, "speed": 118.0, "xp": 11, "gold": 12, "ranged": false, "scale": 3.1,
		"physres": 15.0, "magres": 8.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 16, "hp_g": 0.10, "dmg_g": 0.09,
		"lore": "The Choir sings that the dead should walk their own funerals. In the Vale, they do."},
	"barrow_wight": {"name": "Barrow Wight", "sprite": "skeleton_rogue", "hp": 155.0, "dmg": 27.0, "speed": 140.0, "xp": 13, "gold": 14, "ranged": false, "scale": 3.2,
		"physres": 32.0, "magres": 8.0, "eva": 0.0, "critres": 2.0, "dmg_type": "phys",
		"level": 17, "hp_g": 0.11, "dmg_g": 0.09,
		"lore": "Old bones from before the Choir, woken by sixty years of singing overhead. They resent the noise."},
	"vale_mourner": {"name": "Vale Mourner", "sprite": "cultist", "hp": 125.0, "dmg": 30.0, "speed": 100.0, "xp": 15, "gold": 16, "ranged": true, "scale": 3.2,
		"physres": 8.0, "magres": 32.0, "eva": 0.0, "critres": 2.0, "dmg_type": "magic",
		"level": 18, "hp_g": 0.11, "dmg_g": 0.10,
		"lore": "Choir faithful who wept until the blight took the weeping over. The grief is real. The aim is too."},
	"casket_creeper": {"name": "Casket Creeper", "sprite": "casket_creeper", "hp": 140.0, "dmg": 33.0, "speed": 210.0, "xp": 15, "gold": 16, "ranged": false, "scale": 3.1,
		"physres": 5.0, "magres": 12.0, "eva": 0.14, "critres": 0.0, "dmg_type": "phys",
		"level": 19, "hp_g": 0.10, "dmg_g": 0.09,
		"lore": "It nests in what the Choir refuses to close. Every open grave in the Vale has a tenant."},
}

const QUESTS := {
	"ch3_start": "Report to Cantor Ilse at the Vigil Gate  (walk up to her and press E)",
	"sexton": "Cross the Misted Fields — put THE SEXTON back in the ground",
	"vess": "Follow the liturgy east and grant VESS THE UNBURIED her silence",
	"saint_varo": "Climb to the cathedral — release SAINT VARO",
	"done_ch3": "The Vale buries its dead. The road south smells of smoke...",
}

# Boss-door beats (pre_<kind> plays as the boss spawns; post_<kind> after
# a mid-boss dies; epilogue_ch3 before the victory card).
const BEATS := {
	"pre_sexton": [
		["The Sexton", "I dug YOURS the day you crossed the gate. Third row, by the alder. Dry ground — you'll keep."],
		["Narrator", "The earth between the graves begins to move."],
	],
	"post_sexton": [
		["Narrator", "The Sexton folds into the soil like a man getting into bed at the end of a very long day."],
		["Narrator", "Behind him, for the first time in sixty years, a grave in the Vale stands CLOSED. The road east sings about it — high, thin, furious."],
	],
	"pre_vess": [
		["Vess the Unburied", "They sang NO over my husband's grave. Sixty years I have sung it back at them. Do you know what it costs, to be a liturgy?"],
		["Vess the Unburied", "Stand still, little bearer. The silence in this aisle is MINE, and I decide who gets to rest in it."],
	],
	"post_vess": [
		["Narrator", "The scream ends. Not fades — ENDS, the way a debt ends. What settles over the aisle afterward is not silence; it is quiet, which the Vale has not heard in sixty years."],
		["Narrator", "Up the hill, the cathedral bells begin to toll. The congregation knows you are coming."],
	],
	"pre_saint_varo": [
		["Saint Varo", "Sixty years I have knelt here, asking the rot to take me, and it will not. My flesh REFUSES the one honest thing in Vaelscar."],
		["Saint Varo", "The Choir built a cathedral around my failure and calls it holiness. I am done asking politely. Come, bearer — be my answer."],
	],
	"epilogue_ch3": [
		["Narrator", "Saint Varo does not get up. The rot takes him gently, at last, like a door unlocking from the inside — and his face, at the end, is nothing but grateful."],
		["Cantor Ilse", "So the saint gets his grave, and the Choir loses its shame and its shrine in one blow. They will not forgive that. Neither will they forget who freed him."],
		["Narrator", "South of the Vale, the horizon glows the wrong color for sunset. The foundries of the Slagfields are running day and night now — and something under them has started answering the hammers."],
	],
}

# Per-chapter social wanderers (rolled seeded per character).
const WANDERERS := {
	"ch3": [
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch3_wander_digger"},
		{"sprite": "villager", "prompt": "E — Talk", "convo": "ch3_wander_mute"},
		{"sprite": "cultist", "prompt": "E — Talk", "convo": "ch3_wander_defector"},
		{"sprite": "warden", "prompt": "E — Talk", "convo": "ch3_wander_archivist"},
		{"sprite": "merchant", "prompt": "E — Talk", "convo": "ch3_wander_peddler"},
	],
}

const CONVOS := {
	# ---- Cantor Ilse's briefing: a defector asking for a mercy her old
	# faith calls murder. Reads your Ch2 history; sets the road open.
	"ch3_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Cantor Ilse",
			"text": "You're the bearer Maren wrote ahead about. Good. I left the Choir the day they voted to keep a dying man alive as furniture — I'll explain on the way to that sentence making sense.",
			"variants": [
				{"flag": "ch3_briefed", "text": "The Vale is east, bearer. The Sexton first — no one reaches Vess or the saint while he still has holes to put them in.", "next": ""},
				{"flag": "joined_accord", "text": "You wear the Accord's trust — Maren's letter said as much. Good. What I'm going to ask for is exactly the kind of mercy her people understand and mine call murder."},
				{"flag": "joined_cinderborn", "text": "Cinderborn colors. Hm. Your factor will tell you the Vale is 'unproductive land under hostile administration.' Listen to me first, then decide what it actually is."},
			],
			"next": "b2"},
		"b2": {"who": "Cantor Ilse", "text": "The Choir does not bury its dead — rot is the land's honest truth, so the dead WALK their own funerals, forever. Sixty years of forever, now. The Vale is one open grave from gate to cathedral, and at the top of it kneels Saint Varo — the one man in Vaelscar the rot refuses. My congregation worships his misery and calls it proof.", "next": "b3"},
		"b3": {"who": "Cantor Ilse", "text": "Three stand between you and him. The Sexton, who digs and digs and never fills. Vess, the first widow they told 'no' — her scream became our liturgy, and I sang it for thirty years before I heard the words. And Varo himself, who has been BEGGING to die longer than you've been alive.",
			"choices": [
				{"text": "\"Then I'll give him what he's asking for. Gently, if the fight allows it.\"",
					"resonance": 8.0, "flags": {"ch3_briefed": true, "chose_varo_mercy": true}, "quest": "sexton", "next": "b_mercy"},
				{"text": "\"A saint, a widow, a gravedigger. Fine. Point me at whichever drops the best loot.\"",
					"resonance": -8.0, "flags": {"ch3_briefed": true, "chose_varo_spoils": true}, "quest": "sexton", "next": "b_spoils"},
				{"text": "\"I'll clear the Vale. What the Choir does about its faith afterward is not my war.\"",
					"resonance": 0.0, "flags": {"ch3_briefed": true}, "quest": "sexton", "next": "b_neutral"},
			]},
		"b_mercy": {"who": "Cantor Ilse", "text": "...Gently. Thirty years in the Choir and I never once heard that word aimed at Varo. Go east, bearer. The Sexton holds the fields — no one reaches the cathedral while he still has holes to offer.", "next": ""},
		"b_spoils": {"who": "Cantor Ilse", "text": "The shard talking, or you? ...Don't answer. Take the east road; the Sexton's fields first. And bearer — the saint's misery has outlived four looters that I know of. Their gear is still up there, if inventory is what moves you.", "next": ""},
		"b_neutral": {"who": "Cantor Ilse", "text": "Not your war. Mm. The Vale has heard that from every passer-through for sixty years — it's how the grave count got this high. East, then. The Sexton first.", "next": ""},
	}},

	# ---- Faction presences at the gate: the mid-act pivot. Their pitches
	# sharpen HERE, over the Vale's ashes.
	"ch3_accord": {"start": "a1", "nodes": {
		"a1": {"who": "Warden Corin",
			"text": "Warden Corin, Ember Accord. Maren has me shadowing the Vale because of what's under it — every unburied corpse out there is a straw drawing blight up from Mórwyn's table. This isn't a graveyard, bearer. It's a WICK.",
			"variants": [
				{"flag": "ch3_accord_heard", "text": "The offer stands: end the saint, starve the wick. The Accord counts deeds, not banners.", "next": ""},
				{"flag": "joined_cinderborn", "text": "Warden Corin, Accord. I know whose colors you wear, so I'll be brief: whatever your factor is pricing the Vale at, the thing under it doesn't take coin. When your employers notice that, we'll still be here."},
			],
			"next": "a2"},
		"a2": {"who": "Warden Corin", "text": "The Choir calls the rot honest. Fine — grief IS honest. But the thing their honesty feeds is waking up, and it is not grieving. Break the funeral: the Sexton, the widow, the saint. Do that and the Accord will remember it was you.",
			"choices": [
				{"text": "\"The Accord can count on me for this one.\"",
					"faction": {"accord": 4}, "flags": {"ch3_accord_heard": true}, "next": "a_yes"},
				{"text": "\"I'll break the funeral for my own reasons. Keep your ledger.\"",
					"flags": {"ch3_accord_heard": true}, "next": "a_own"},
			]},
		"a_yes": {"who": "Warden Corin", "text": "Then flame keep you east of here. And bearer — when the congregation begs you to spare their saint, and they will: remember what he's a wick FOR.", "next": ""},
		"a_own": {"who": "Warden Corin", "text": "Your reasons, our outcome. The Accord has made worse bargains. Flame keep you anyway.", "next": ""},
	}},
	"ch3_cinder": {"start": "c1", "nodes": {
		"c1": {"who": "Factor Imre",
			"text": "Factor Imre, Cinderborn Compact. Before you wrinkle your nose: yes, I'm here to make money off a graveyard. The Vale sits on the best road south to the Slagfields, and sixty years of 'eternal funeral' has it closed to freight. Empires are built from exactly this kind of unglamorous arithmetic.",
			"variants": [
				{"flag": "ch3_cinder_heard", "text": "The arithmetic hasn't changed: open road, grateful Compact, standing invoice. Kill things in that order.", "next": ""},
				{"flag": "joined_accord", "text": "Ah — Maren's newest. Relax, warden-friend, I'm not recruiting today. I'm just the man who'll be selling your Accord its grain when the Vale road opens. Which you are about to do for free. Marvelous system, isn't it?"},
			],
			"next": "c2"},
		"c2": {"who": "Factor Imre", "text": "Under Vargoth — spare me the face, I said it — this road ran two hundred wagons a week and the Vale buried its dead like civilized people. Order is not a dirty word, bearer. Clear the road and the Compact pays its debts. Sentiment optional.",
			"choices": [
				{"text": "\"Two hundred wagons a week. Fine — I'll open your road.\"",
					"faction": {"cinderborn": 4}, "flags": {"ch3_cinder_heard": true}, "next": "c_yes"},
				{"text": "\"People are grieving out there and you brought an invoice.\"",
					"resonance": 3.0, "faction": {"cinderborn": -2}, "flags": {"ch3_cinder_heard": true}, "next": "c_no"},
			]},
		"c_yes": {"who": "Factor Imre", "text": "Excellent. The Compact remembers its friends — it's the whole reason we HAVE a ledger. Mind the widow on your way up; grief with sixty years of interest is the one debt I won't broker.", "next": ""},
		"c_no": {"who": "Factor Imre", "text": "They've been grieving for sixty YEARS, bearer — the invoice is the only thing here with an end date. ...Go on. You'll open the road anyway, and I'll thank you anyway. That's the marvelous part.", "next": ""},
	}},
	"ch3_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Old Fenna",
			"text": "My son walks the Misted Fields. Fourth from the alder, grey coat. The Choir says that's him honored. I say I sewed that coat for a living boy and I want it BACK on a dead one, in the ground, where coats and sons go.",
			"variants": [
				{"band": "tempted", "text": "You've got the look the Choir cantors get before they start explaining why my grief is holy. Don't. Just — if you pass the fourth grave from the alder, grey coat... let him fall facing home."},
				{"flag": "ch3_fenna_promised", "text": "Fourth from the alder. Grey coat. Facing home. You remembered. That's more than the flame's given me in sixty years.", "next": ""},
			],
			"choices": [
				{"text": "\"Fourth from the alder, grey coat. If it's my hand that fells him, he falls facing home.\"",
					"resonance": 4.0, "flags": {"ch3_fenna_promised": true}, "next": "r_kind"},
				{"text": "\"The things out there aren't sons anymore. The sooner you learn that, the lighter you'll walk.\"",
					"resonance": -4.0, "next": "r_cold"},
			]},
		"r_kind": {"who": "Old Fenna", "text": "Facing home. Yes. ...The Choir sang at me for sixty years and never once said anything that useful.", "next": ""},
		"r_cold": {"who": "Old Fenna", "text": "Lighter. Aye. You sound like the shard's already teaching you to travel light. Keep the lesson — I'll keep the coat.", "next": ""},
	}},

	# ---- Resonance shrines: the chapter's two genuine choices.
	"ch3_shrine_grave": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "The First Grave — the one the Choir dug and then refused to fill, sixty years ago, the day their faith was born. It has been open so long the sides have gone smooth as a font. The Ember in you leans over the edge, curious. The grave is empty. The grave has never once been empty of OFFERS.",
			"variants": [{"flag": "first_grave_touched", "text": "The First Grave keeps its smooth sides and its long patience. Whatever passed between you is finished — one of the few finished things in the Vale.", "next": ""}],
			"choices": [
				{"text": "Give it a grief of your own — name someone you lost, aloud, and let the grave hold the name.",
					"resonance": 8.0, "flags": {"first_grave_touched": true}, "next": "s_give"},
				{"text": "Reach down. Sixty years of grave-offerings gleam in the soil, and the dead clearly aren't using them.",
					"resonance": -8.0, "flags": {"first_grave_touched": true}, "next": "s_take"},
				{"text": "Leave the first grave its emptiness. It has waited sixty years; it can wait out you too.",
					"resonance": 0.0, "flags": {"first_grave_touched": true}, "next": "s_leave"},
			]},
		"s_give": {"who": "Narrator", "text": "You say the name once, quietly. The grave takes it the way dry ground takes rain — and the Ember in you goes still, the way it only does when something is PAID rather than taken. You walk away lighter by exactly one name's weight. You can still remember them. You checked.", "next": ""},
		"s_take": {"who": "Narrator", "text": "Rings, clasps, a child's silver whistle. They come up easily — sixty years of grief, pocketed in under a minute. The Ember purrs its approval, and somewhere behind your ribs a small voice notes how EASY that was, and files the note where you keep things you'd rather not have learned about yourself.", "next": ""},
		"s_leave": {"who": "Narrator", "text": "You step back from the edge. The grave neither thanks you nor curses you — but the wind through it changes note, briefly, like a jar someone stopped blowing across. Some invitations expire simply by being declined.", "next": ""},
	}},
	"ch3_shrine_kneeling": {"start": "k1", "nodes": {
		"k1": {"who": "Narrator",
			"text": "A field of kneeling Choir faithful, unarmed, between you and the cathedral doors. They do not attack. They do not move. An old cantor rises from the front row, hands open: \"You've come to take our saint. We know. We heard the bells count you up the hill. Please — he is all the proof we have that the rot CHOOSES. Without him, our sixty years of grief were just... grief.\"",
			"variants": [{"flag": "kneeling_answered", "text": "The congregation still kneels, but a lane stands open through them now — they made it themselves, after your answer. Whatever you told them, they are still deciding what it meant.", "next": ""}],
			"choices": [
				{"text": "\"Your saint has begged sixty years to die. I'm not taking him from you — I'm returning him to himself.\"",
					"resonance": 8.0, "flags": {"kneeling_answered": true, "chose_told_congregation": true}, "faction": {"choir": 2}, "next": "k_truth"},
				{"text": "\"Proof? He's a wick feeding the thing that will eat you all. Kneel to THAT if you need something holy.\"",
					"resonance": -6.0, "flags": {"kneeling_answered": true}, "faction": {"choir": -4, "accord": 2}, "next": "k_scorn"},
				{"text": "Walk through them without a word. Their faith is not yours to argue with, and the saint is waiting.",
					"resonance": -2.0, "flags": {"kneeling_answered": true}, "next": "k_silent"},
			]},
		"k_truth": {"who": "Narrator", "text": "The old cantor's mouth works. \"Returning him—\" He stops. Somewhere in the rows behind him, one voice — young, cracked — says: \"...he does scream at night. We all hear it. We SING over it.\" The kneeling field is very quiet as it opens you a lane. Grief, you understand suddenly, has been waiting sixty years for permission to just be grief.", "next": ""},
		"k_scorn": {"who": "Narrator", "text": "The word WICK moves through the kneeling rows like cold water. Some flinch. Some harden — you have just handed the Choir's next generation its favorite story about the day the unbeliever spat on their proof. The lane they open you is wide, and no one in it will meet your eyes.", "next": ""},
		"k_silent": {"who": "Narrator", "text": "You walk, and they lean out of your path like grass. No argument, no absolution — just a bearer with a job, wading through sixty years of other people's meaning. The Ember approves of the efficiency. That is precisely what bothers you about it.", "next": ""},
	}},

	# ---- Dead-end lore props.
	"ch3_lore_chapel": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A chapel from before the Choir, roof long gone. The headstone by the door reads: HERE LIES BRAM TALLOW, BURIED PROPER, 61 YEARS AGO — the last person in the Vale anyone put in the ground. Someone still weeds the plot. Someone has ALWAYS still weeded the plot, sixty-one years running, and the Choir has never caught them at it.", "next": ""},
	}},
	"ch3_lore_reliquary": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "The cathedral's reliquary — every case stands empty. Placards remain: A SAINT'S FINGERBONE. A SAINT'S TOOTH. A SAINT'S TEAR, PRESERVED IN WAX. The Choir venerates decay, but its saint cannot rot, so there were never relics to fill the cases with. They built the room anyway, and dusted it daily, and hoped. Sixty years of dusted hope, and upstairs a man on his knees begging to become what these cases wanted.", "next": ""},
	}},

	# ---- Social wanderers.
	"ch3_wander_digger": {"start": "d1", "nodes": {
		"d1": {"who": "Old Digger Haim",
			"text": "Forty years I dug for the villages — honest holes, filled the same day. Then the Choir came and digging became LITURGY and filling became sin. I kept the spade. A man should keep the tools of the thing he was before everyone went mad.",
			"variants": [{"flag": "ch3_haim_met", "text": "Still got the spade. Still oiled. The day this chapter of madness ends, the Vale will want a man who remembers how the OTHER half of the job goes.", "next": ""}],
			"choices": [
				{"text": "\"Keep it oiled, digger. The Vale's going to need you by week's end.\"",
					"resonance": 3.0, "flags": {"ch3_haim_met": true}, "next": "d_hope"},
				{"text": "\"Forty years of holes and you never once asked what they were FOR?\"",
					"resonance": -3.0, "flags": {"ch3_haim_met": true}, "next": "d_barb"},
			]},
		"d_hope": {"who": "Old Digger Haim", "text": "Week's end. Ha. You know, that's the first deadline anyone's given the Vale in sixty years? I'll sharpen the edge tonight. Deadlines deserve a sharp spade.", "next": ""},
		"d_barb": {"who": "Old Digger Haim", "text": "...They were for GRIEF, stranger. A hole is where you put grief so it doesn't follow you home. The Choir's whole madness is just sixty years of nobody being allowed to put it down. Ask your shard where IT puts yours.", "next": ""},
	}},
	"ch3_wander_mute": {"start": "m1", "nodes": {
		"m1": {"who": "Narrator",
			"text": "A woman sits on a fallen headstone, hands folded. The locals say she asked the Choir to bury her daughter, was sung 'no', and has not spoken since — nineteen years. She looks up at you. She looks at your sword hand. Very slowly, very clearly, she nods toward the east road.",
			"variants": [{"flag": "ch3_mute_met", "text": "She is there again, hands folded. When she sees you she touches two fingers to her lips — whatever you did out east, word of it reached her, and this is what her thanks looks like.", "next": ""}],
			"choices": [
				{"text": "Nod back. Once. A contract needs no words.",
					"resonance": 3.0, "flags": {"ch3_mute_met": true}, "next": "m_nod"},
			]},
		"m_nod": {"who": "Narrator", "text": "Something in her shoulders lets go — a knot nineteen years old, loosening one turn. She resumes her vigil. You resume your road. Between you, wordless and binding as anything ever signed: someone is finally going to MAKE the singing stop.", "next": ""},
	}},
	"ch3_wander_defector": {"start": "f1", "nodes": {
		"f1": {"who": "Brother Osk (formerly)",
			"text": "I keep the count. Fourteen thousand, two hundred and six unburied, gate to cathedral. The Choir never counted — counting implies you might one day FINISH. I left over the counting. It seemed a small thing to leave a faith over, until I understood it was the whole faith.",
			"variants": [{"band": "tempted", "text": "Fourteen thousand two hundred six. ...You carry something that likes big numbers, bearer. I can hear it liking mine. Walk on, please — and don't let it do the counting for you."},
				{"flag": "ch3_osk_met", "text": "The count stands. It will go DOWN soon, for the first time — I find I don't know how to write a number getting smaller. Good problem. Sixty years since the Vale had a good problem.", "next": ""}],
			"choices": [
				{"text": "\"Keep counting, brother. Every one of them is going to need a number when the burying starts.\"",
					"resonance": 3.0, "flags": {"ch3_osk_met": true}, "next": "f_keep"},
			]},
		"f_keep": {"who": "Brother Osk (formerly)", "text": "When the burying starts. You say it like weather — like it's simply COMING. ...I believe I'll keep the ledger open at today's page. It deserves to see this.", "next": ""},
	}},
	"ch3_wander_archivist": {"start": "a1", "nodes": {
		"a1": {"who": "Archivist Lene (Accord)",
			"text": "Don't mind me — I'm cataloguing headstones for the Accord. Sixty-one years ago the inscriptions change: before, 'REST WELL'. After, 'WALK WELL'. One stonecutter's hand, same chisel, both eras. He cut the old faith and the new one at the same bench and history came down to which order the wagons arrived in.",
			"variants": [{"flag": "ch3_lene_met", "text": "Found the stonecutter's own grave this morning, by the way. Blank stone. He couldn't decide. Sixty years of everyone else's certainty, and the one man who carved it all hedged.", "next": ""}],
			"choices": [
				{"text": "\"And which does the Accord believe — rest or walk?\"", "flags": {"ch3_lene_met": true}, "next": "a_ans"},
			]},
		"a_ans": {"who": "Archivist Lene (Accord)", "text": "The Accord believes in whichever one starves the thing underneath. That's the difference between us and everyone else in the Vale, bearer — we're the only ones here reading the stones for TACTICS.", "next": ""},
	}},
	"ch3_wander_peddler": {"start": "p1", "nodes": {
		"p1": {"who": "Grave-Goods Peddler",
			"text": "Lanterns, spade-heads, mourning veils — and before you ask, NO, none of it's dug up. I sell TO the graves, not from them. Sixty years of funerals that never end is, commercially speaking, the best market in Vaelscar. I'm not proud of the thought. I'm just the only one who says it out loud.",
			"variants": [{"flag": "ch3_peddler_met", "text": "Back again! Business is... troubled, actually. Word's spreading the funerals might END. Ruinous. Wonderful. I haven't decided which, and my ledger's no help.", "next": ""}],
			"choices": [
				{"text": "\"What happens to you when the funerals end, peddler?\"", "flags": {"ch3_peddler_met": true}, "next": "p_end"},
				{"text": "\"'Best market in Vaelscar.' The rot's in more than the ground here.\"", "resonance": -2.0, "flags": {"ch3_peddler_met": true}, "next": "p_barb"},
			]},
		"p_end": {"who": "Grave-Goods Peddler", "text": "Weddings, I suppose. People who stop mourning eventually start marrying — it's the same veil business with better catering. ...Flame's honest truth, bearer? I'd retrain tomorrow. Nobody builds a life on grief because they WANT to.", "next": ""},
		"p_barb": {"who": "Grave-Goods Peddler", "text": "Aye, maybe. But I never sang 'no' over anyone's husband, and my prices are honest. In the Vale, that makes me clergy.", "next": ""},
	}},
}
