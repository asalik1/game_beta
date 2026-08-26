class_name FangmootData
extends RefCounted
## Fangmoot's static data tables. PROPOSALS/FANGMOOT.md §7, §8, §17.
##
## Every token/Named id is a real Story.ALL_ENEMIES key or Menus.BOSS_KINDS id,
## so Art.tex(kind) and the codex icon path resolve unchanged. Ability rows are
## pure data in FangmootSim's op vocabulary (see fangmoot_sim.gd header).
##
## Tribes are tags only (no count bonuses); abilities reference them by id.
## Stat sums per tier: T1 4-5, T2 6-8, T3 9-11, T4 12-14, T5 15-17, Named 18-22.

# ------------------------------------------------------------------- tribes
const TRIBES := {
	"wild":   {"name": "Wild",   "material": "bone and antler",   "blurb": "pack buffs, first strikes, hunt the hurt"},
	"hollow": {"name": "Hollow", "material": "coffin-nail iron",  "blurb": "gains from allies falling; things come back"},
	"choir":  {"name": "Choir",  "material": "blackened wax",     "blurb": "rot, martyrdom, cheap bodies that feed the rest"},
	"molten": {"name": "Molten", "material": "slag-glass",        "blurb": "burn, thorns, verdicts on the biggest enemy"},
	"still":  {"name": "Still",  "material": "ice-glass",         "blurb": "frost, preserved, walls that will not die"},
	"root":   {"name": "Root",   "material": "living root",       "blurb": "summons, permanent growth, compost on death"},
	"storm":  {"name": "Storm",  "material": "fulgurite",         "blurb": "chain damage, silence, retaliation"},
}
const TRIBE_ORDER := ["wild", "hollow", "choir", "molten", "still", "root", "storm"]

# --------------------------------------------------------------- v1 tokens
# kind -> {name, tribe, tier, bite, hide, home, ability}
const TOKENS := {
	# --- Tier 1: the Carver's stock ---
	"wolf": {"name": "Blighted Wolf", "tribe": "wild", "tier": 1, "bite": 2, "hide": 2, "home": "darkwood",
		"ability": {"id": "pack", "name": "Pack", "trig": "muster",
			"ops": [{"fx": "buff", "stat": "bite", "tgt": "self", "per": "wild", "val": [1, 2, 3]}]}},
	"spider": {"name": "Marsh Spider", "tribe": "wild", "tier": 1, "bite": 1, "hide": 3, "home": "marsh",
		"ability": {"id": "web", "name": "Web", "trig": "muster",
			"ops": [{"fx": "status", "st": "frost", "tgt": "enemy_front_n", "cnt": [1, 2, 3]}]}},
	"zombie": {"name": "Risen Corpse", "tribe": "hollow", "tier": 1, "bite": 1, "hide": 4, "home": "graveyard",
		"ability": {"id": "refuse", "name": "Refuses the Ending", "trig": "turn_end",
			"ops": [{"fx": "buff", "stat": "hide", "perm": true, "tgt": "self", "val": [1, 2, 3]}]}},
	"cultist": {"name": "Blight Cultist", "tribe": "choir", "tier": 1, "bite": 1, "hide": 2, "home": "marsh",
		"ability": {"id": "tend", "name": "Tend", "trig": "muster",
			"ops": [{"fx": "buff", "stat": "hide", "tgt": "ally_ahead", "val": [2, 4, 6]}]}},
	"cinder_whelp": {"name": "Cinder Whelp", "tribe": "molten", "tier": 1, "bite": 2, "hide": 2, "home": "magma",
		"ability": {"id": "whelpfire", "name": "Whelp-Fire", "trig": "muster",
			"ops": [{"fx": "status", "st": "burn", "tgt": "enemy_front_n", "cnt": [1, 2, 3]}]}},
	"cold_pilgrim": {"name": "Cold Pilgrim", "tribe": "still", "tier": 1, "bite": 1, "hide": 3, "home": "ice",
		"ability": {"id": "numb", "name": "Numb", "trig": "hurt", "uses": [1, 2, 3],
			"ops": [{"fx": "status", "st": "frost", "tgt": "striker"}]}},
	"sporeshambler": {"name": "Spore Shambler", "tribe": "root", "tier": 1, "bite": 1, "hide": 3, "home": "spore",
		"ability": {"id": "compost", "name": "Compost", "trig": "fall",
			"ops": [{"fx": "buff", "stat": "both", "tgt": "ally_behind", "val": [1, 2, 3]}]}},

	# --- Tier 2: the Carver's stock ---
	"blightwolf": {"name": "Waking Wolf", "tribe": "wild", "tier": 2, "bite": 3, "hide": 2, "home": "darkwood",
		"ability": {"id": "pounce", "name": "Pounce", "trig": "muster",
			"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": [2, 4, 6]}]}},
	"bogspider": {"name": "Greyrun Lurker", "tribe": "wild", "tier": 2, "bite": 2, "hide": 4, "home": "marsh",
		"ability": {"id": "lurk", "name": "Lurk", "trig": "ally_ahead_bites",
			"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": [1, 2, 3]}]}},
	"skeleton": {"name": "Hollow Soldier", "tribe": "hollow", "tier": 2, "bite": 3, "hide": 3, "home": "keep",
		"ability": {"id": "frenzy", "name": "Frenzy", "trig": "hurt",
			"ops": [{"fx": "buff", "stat": "bite", "tgt": "self", "val": [1, 2, 3]}]}},
	"gravewalker": {"name": "Unburied Walker", "tribe": "hollow", "tier": 2, "bite": 2, "hide": 4, "home": "graveyard",
		"ability": {"id": "funeral", "name": "Walks Its Own Funeral", "trig": "fall",
			"ops": [{"fx": "summon", "unit": "zombie", "name": "Risen Corpse", "tribe": "hollow", "num": 1,
				"stats": [[1, 1], [2, 2], [3, 3]]}]}},
	"casket_creeper": {"name": "Casket Creeper", "tribe": "choir", "tier": 2, "bite": 2, "hide": 4, "home": "marsh",
		"ability": {"id": "bloat", "name": "Bloat", "trig": "fall",
			"ops": [{"fx": "status", "st": "rot", "tgt": "enemy_front", "amt": [2, 4, 6]}]}},
	"vent_skitter": {"name": "Vent Skitter", "tribe": "molten", "tier": 2, "bite": 2, "hide": 3, "home": "magma",
		"ability": {"id": "eats", "name": "Eats What Falls", "trig": "slay",
			"ops": [{"fx": "buff", "stat": "both", "perm": true, "tgt": "self", "val": [1, 2, 3]}]}},
	"winterfang": {"name": "Winterfang", "tribe": "still", "tier": 2, "bite": 3, "hide": 3, "home": "ice",
		"ability": {"id": "coldtrail", "name": "Cold Trail", "trig": "slay",
			"ops": [{"fx": "status", "st": "frost", "tgt": "stepped_enemy"},
				{"fx": "dmg", "tgt": "stepped_enemy", "val": [0, 2, 4]}]}},
	"bog_lurker": {"name": "Bog Lurker", "tribe": "root", "tier": 2, "bite": 2, "hide": 4, "home": "bog",
		"ability": {"id": "snareroots", "name": "Snare-Roots", "trig": "muster",
			"ops": [{"fx": "status", "st": "thorns", "tgt": "self", "amt": [1, 2, 3]}]}},
	"void_shade": {"name": "Void Shade", "tribe": "storm", "tier": 2, "bite": 3, "hide": 2, "home": "void",
		"ability": {"id": "blink", "name": "Blink", "trig": "muster",
			"ops": [{"fx": "status", "st": "ward", "tgt": "self", "amt": 1},
				{"fx": "status", "st": "thorns", "tgt": "self", "amt": [0, 1, 3], "uses": 1}]}},
	"null_acolyte": {"name": "Null Acolyte", "tribe": "storm", "tier": 2, "bite": 1, "hide": 4, "home": "void",
		"ability": {"id": "null", "name": "Null", "trig": "muster",
			"ops": [{"fx": "status", "st": "silence", "tgt": "enemy_front_n", "cnt": [1, 2, 3]}]}},

	# --- Tier 3: catalogue required from here ---
	"duneprowler": {"name": "Dune Prowler", "tribe": "wild", "tier": 3, "bite": 4, "hide": 3, "home": "desert",
		"ability": {"id": "hunt", "name": "Hunt", "trig": "bite",
			"ops": [{"fx": "strike_bonus", "cond": "target_hurt", "val": [2, 4, 6]}]}},
	"beastkin_raider": {"name": "Wildfang Raider", "tribe": "wild", "tier": 3, "bite": 4, "hide": 4, "home": "darkwood",
		"ability": {"id": "raid", "name": "Raid", "trig": "slay",
			"ops": [{"fx": "buff", "stat": "both", "tgt": "ally_behind", "val": [1, 2, 3]}]}},
	"stormcult": {"name": "Choir Cantor", "tribe": "choir", "tier": 3, "bite": 2, "hide": 5, "home": "marsh",
		"ability": {"id": "cant", "name": "Cant", "trig": "turn_end",
			"ops": [{"fx": "buff", "stat": "both", "perm": true, "tgt": "rand_ally_tribe:choir", "val": [1, 2, 3]}]}},
	"plague_chanter": {"name": "Plague Chanter", "tribe": "choir", "tier": 3, "bite": 2, "hide": 4, "home": "bog",
		"ability": {"id": "threewords", "name": "Three Words", "trig": "muster",
			"ops": [{"fx": "status", "st": "rot", "tgt": "all_enemies", "amt": [1, 2, 3]}]}},
	"barrow_wight": {"name": "Barrow Wight", "tribe": "hollow", "tier": 3, "bite": 4, "hide": 3, "home": "keep",
		"ability": {"id": "oldbones", "name": "Old Bones", "trig": "ally_falls",
			"ops": [{"fx": "buff", "stat": "bite", "tgt": "self", "val": [2, 3, 4]}]}},
	"forge_acolyte": {"name": "Forge Acolyte", "tribe": "molten", "tier": 3, "bite": 2, "hide": 5, "home": "magma",
		"ability": {"id": "reflect", "name": "Reflect", "trig": "muster",
			"ops": [{"fx": "status", "st": "thorns", "tgt": "self", "amt": [2, 3, 4]}]}},
	"deep_stalker": {"name": "Crystal Stalker", "tribe": "still", "tier": 3, "bite": 4, "hide": 3, "home": "crystal",
		"ability": {"id": "crystalweb", "name": "Crystal Web", "trig": "bite", "uses": [1, 2, 3],
			"ops": [{"fx": "status", "st": "frost", "tgt": "target"}]}},
	"root_shambler": {"name": "Root Shambler", "tribe": "root", "tier": 3, "bite": 3, "hide": 5, "home": "spore",
		"ability": {"id": "tether", "name": "Tether", "trig": "fall",
			"ops": [{"fx": "heal", "amt": "full", "tgt": "ally_behind"},
				{"fx": "buff", "stat": "both", "tgt": "ally_behind", "val": [0, 1, 2]}]}},
	"storm_harrier": {"name": "Storm Harrier", "tribe": "storm", "tier": 3, "bite": 4, "hide": 3, "home": "storm",
		"ability": {"id": "chain", "name": "Chain", "trig": "bite",
			"ops": [{"fx": "dmg", "tgt": "behind_target", "val": [1, 2, 3]}]}},
	"void_husk": {"name": "Voidbound Husk", "tribe": "storm", "tier": 3, "bite": 2, "hide": 6, "home": "void",
		"ability": {"id": "voidburst", "name": "Void Burst", "trig": "fall",
			"ops": [{"fx": "dmg", "tgt": "enemy_front_n", "cnt": 2, "val": [2, 3, 4]}]}},

	# --- Tier 4 ---
	"beastkin_howler": {"name": "Wildfang Howler", "tribe": "wild", "tier": 4, "bite": 4, "hide": 6, "home": "darkwood",
		"ability": {"id": "howl", "name": "Howl", "trig": "muster",
			"ops": [{"fx": "buff", "stat": "bite", "tgt": "ally_tribe:wild", "val": [2, 3, 4]}]}},
	"sun_bleached": {"name": "Sun-Bleached Husk", "tribe": "hollow", "tier": 4, "bite": 3, "hide": 8, "home": "desert",
		"ability": {"id": "bleached", "name": "Bleached", "trig": "muster",
			"ops": [{"fx": "status", "st": "ward", "tgt": "self", "amt": [1, 2, 3]}]}},
	"vale_mourner": {"name": "Vale Mourner", "tribe": "choir", "tier": 4, "bite": 2, "hide": 6, "home": "graveyard",
		"ability": {"id": "martyr", "name": "Martyr", "trig": "fall",
			"ops": [{"fx": "buff", "stat": "both", "tgt": "ally_tribe:choir", "val": [2, 3, 4]}]}},
	"slag_brute": {"name": "Slagbound Brute", "tribe": "molten", "tier": 4, "bite": 6, "hide": 5, "home": "magma",
		"ability": {"id": "sower", "name": "Sower", "trig": "bite",
			"ops": [{"fx": "status", "st": "burn", "tgt": ["target", "target_and_behind", "all_enemies"]}]}},
	"frost_husk": {"name": "Frost-Bound Soldier", "tribe": "still", "tier": 4, "bite": 5, "hide": 6, "home": "ice",
		"ability": {"id": "preserved", "name": "Preserved", "trig": "muster",
			"ops": [{"fx": "status", "st": "preserved", "tgt": "self", "amt": [1, 1, 2],
				"grants_ward": true, "grants_ward_lvl": 2}]}},
	"hushcaller": {"name": "Hushcaller", "tribe": "still", "tier": 4, "bite": 3, "hide": 6, "home": "ice",
		"ability": {"id": "lullaby", "name": "Lullaby", "trig": "muster",
			"ops": [{"fx": "status", "st": "frost", "tgt": "top_bite_enemy", "cnt": [2, 3, 4]}]}},
	"static_caller": {"name": "Static Caller", "tribe": "storm", "tier": 4, "bite": 3, "hide": 6, "home": "storm",
		"ability": {"id": "static", "name": "Static", "trig": "ally_hurt",
			"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": [1, 2, 3]}]}},

	# --- Tier 5 ---
	"wildkin_ranger": {"name": "Wildkin Ranger", "tribe": "wild", "tier": 5, "bite": 6, "hide": 6, "home": "darkwood",
		"ability": {"id": "volley", "name": "Volley", "trig": "ally_ahead_bites",
			"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": [2, 4, 6]}]}},
	"frozen_guard": {"name": "Frozen Guard", "tribe": "still", "tier": 5, "bite": 5, "hide": 9, "home": "ice",
		"ability": {"id": "frostaura", "name": "Frost Aura", "trig": "bite",
			"ops": [{"fx": "status", "st": "frost", "tgt": ["target", "target_and_behind", "all_enemies"]}]}},
	"grove_horror": {"name": "Grove Horror", "tribe": "root", "tier": 5, "bite": 7, "hide": 7, "home": "spore",
		"ability": {"id": "overgrow", "name": "Overgrow", "trig": "turn_end",
			"ops": [{"fx": "buff", "stat": "both", "perm": true, "tgt": "self", "val": [2, 3, 4]}]}},
	"bloom_acolyte": {"name": "Bloom Acolyte", "tribe": "root", "tier": 5, "bite": 3, "hide": 7, "home": "spore",
		"ability": {"id": "bloom", "name": "Bloom", "trig": "ally_falls",
			"ops": [{"fx": "summon", "unit": "root_spiderling", "name": "Rootling", "tribe": "root", "num": 1,
				"cap": 3, "stats": [[2, 2], [3, 3], [4, 4]]}]}},
	"vow_sentinel": {"name": "Vow Sentinel", "tribe": "storm", "tier": 5, "bite": 5, "hide": 8, "home": "storm",
		"ability": {"id": "counter", "name": "Counter", "trig": "hurt",
			"ops": [{"fx": "dmg", "tgt": "striker", "val": [3, 5, 7]}]}},
}

# ---------------------------------------------------------- Named (bosses)
# kind -> {name, tribe, bite, hide, home, ability}; cost 5, one per warband.
const NAMED := {
	# Wild
	"fangmaw": {"name": "Fangmaw the Ravener", "tribe": "wild", "bite": 8, "hide": 10, "home": "darkwood",
		"ability": {"id": "callpack", "name": "Call the Pack", "trig": "muster",
			"ops": [{"fx": "summon", "unit": "wolf", "name": "Blighted Wolf", "tribe": "wild", "num": 2,
				"stats": [[2, 2], [3, 3], [4, 4]]}]}},
	"whitepelt": {"name": "Hrolgar Whitepelt", "tribe": "wild", "bite": 9, "hide": 11, "home": "ice",
		"ability": {"id": "peltdrums", "name": "Pelt Drums", "trig": "muster",
			"ops": [{"fx": "buff", "stat": "both", "tgt": "ally_tribe:wild", "val": [3, 4, 5]}]}},
	"curetwisted": {"name": "Kaethra Cure-Twisted", "tribe": "wild", "bite": 10, "hide": 9, "home": "darkwood",
		"ability": {"id": "curetwisted", "name": "Cure-Twisted", "trig": "slay",
			"ops": [{"fx": "heal", "tgt": "all_allies", "amt": [3, 5, 7]}]}},
	# Hollow
	"vargoth": {"name": "King Vargoth the Hollow", "tribe": "hollow", "bite": 10, "hide": 12, "home": "keep",
		"ability": {"id": "bladestorm", "name": "Blade Storm", "trig": "bite",
			"ops": [{"fx": "dmg", "tgt": "all_enemies", "val": [3, 4, 5]}]}},
	"sexton": {"name": "The Sexton", "tribe": "hollow", "bite": 7, "hide": 12, "home": "graveyard",
		"ability": {"id": "chaincorpse", "name": "Chain-Detonating Corpses", "trig": "ally_falls",
			"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": [3, 5, 7]}]}},
	"vess": {"name": "Vess the Unburied", "tribe": "hollow", "bite": 6, "hide": 12, "home": "graveyard",
		"ability": {"id": "wail", "name": "The Wail", "trig": "fall",
			"ops": [{"fx": "dmg", "tgt": "all_enemies", "val": [4, 6, 8]}]}},
	# Choir
	"morwen": {"name": "Morwen the Blightcaller", "tribe": "choir", "bite": 8, "hide": 10, "home": "marsh",
		"ability": {"id": "blightrain", "name": "Blight Rain", "trig": "muster",
			"ops": [{"fx": "status", "st": "rot", "tgt": "all_enemies", "amt": [2, 3, 4]}]}},
	"choirmother": {"name": "The Choir Mother", "tribe": "choir", "bite": 6, "hide": 13, "home": "marsh",
		"ability": {"id": "requiem", "name": "Requiem", "trig": "ally_falls",
			"ops": [{"fx": "buff", "stat": "both", "tgt": "ally_tribe:choir", "val": [2, 3, 4]}]}},
	"saint_varo": {"name": "Saint Varo the Unrotting", "tribe": "choir", "bite": 5, "hide": 16, "home": "holy",
		"ability": {"id": "toll", "name": "The Toll", "trig": "hurt",
			"ops": [{"fx": "status", "st": "rot", "tgt": "striker", "amt": [2, 3, 4]}]}},
	# Molten
	"forgemistress": {"name": "Forgemistress Calda", "tribe": "molten", "bite": 8, "hide": 10, "home": "magma",
		"ability": {"id": "whitehot", "name": "White-Hot Slag", "trig": "muster",
			"ops": [{"fx": "status", "st": "burn", "tgt": "all_enemies"},
				{"fx": "dmg", "tgt": "all_enemies", "val": [0, 2, 4]}]}},
	"cinderhide": {"name": "Cinderhide the Unquenched", "tribe": "molten", "bite": 7, "hide": 13, "home": "magma",
		"ability": {"id": "obsidian", "name": "Obsidian Plating", "trig": "muster",
			"ops": [{"fx": "status", "st": "ward", "tgt": "self", "amt": 1},
				{"fx": "status", "st": "thorns", "tgt": "self", "amt": [3, 4, 5]}]}},
	"ashpriest": {"name": "Ashpriest Ordo", "tribe": "molten", "bite": 9, "hide": 9, "home": "magma",
		"ability": {"id": "verdict", "name": "The Verdict", "trig": "muster",
			"ops": [{"fx": "dmg", "tgt": "top_bite_enemy", "cnt": 1, "val": [6, 9, 12]}]}},
	# Still
	"icebound": {"name": "Serane the Icebound", "tribe": "still", "bite": 7, "hide": 12, "home": "ice",
		"ability": {"id": "flashfreeze", "name": "Flash Freeze", "trig": "muster",
			"ops": [{"fx": "status", "st": "frost", "tgt": "all_enemies"},
				{"fx": "dmg", "tgt": "all_enemies", "val": [0, 2, 4]}]}},
	"sleepkeeper": {"name": "Mother Halla", "tribe": "still", "bite": 5, "hide": 14, "home": "ice",
		"ability": {"id": "longsleep", "name": "The Long Sleep", "trig": "ally_falls",
			"ops": [{"fx": "preserve_ally", "uses": [1, 2, 3]}]}},
	# Root
	"gardener": {"name": "Rotmaw the Gardener", "tribe": "root", "bite": 6, "hide": 14, "home": "spore",
		"ability": {"id": "carnivore", "name": "Carnivorous Bloom", "trig": "slay",
			"ops": [{"fx": "summon", "unit": "root_spiderling", "name": "Rootling", "tribe": "root", "num": 1,
				"stats": [[2, 2], [3, 3], [4, 4]]}]}},
	"auroch": {"name": "The Drowned Auroch", "tribe": "root", "bite": 11, "hide": 9, "home": "bog",
		"ability": {"id": "gorerush", "name": "Gore Rush", "trig": "bite",
			"ops": [{"fx": "dmg", "tgt": "behind_target", "val": [3, 5, 7]}]}},
	# Storm
	"stormwarden": {"name": "Korrag, Stormwarden Broken", "tribe": "storm", "bite": 9, "hide": 10, "home": "storm",
		"ability": {"id": "stormbreaks", "name": "The Storm Breaks", "trig": "hurt", "cond": "self_half", "uses": 1,
			"ops": [{"fx": "buff", "stat": "bite", "tgt": "self", "val": [4, 6, 8]}]}},
	"nullwarden": {"name": "Warden Null", "tribe": "storm", "bite": 6, "hide": 15, "home": "void",
		"ability": {"id": "nullfield", "name": "Null Field", "trig": "muster",
			"ops": [{"fx": "status", "st": "silence", "tgt": "all_enemies"},
				{"fx": "status", "st": "ward", "tgt": "self", "amt": [0, 1, 1]},
				{"fx": "buff", "stat": "both", "tgt": "self", "val": [0, 0, 2]}]}},
	"stormdrake_veyx": {"name": "Veyx, the Unchained Current", "tribe": "storm", "bite": 10, "hide": 9, "home": "storm",
		"ability": {"id": "arc", "name": "Arc", "trig": "bite",
			"ops": [{"fx": "dmg", "tgt": "behind_target", "val": [3, 5, 7]},
				{"fx": "dmg", "tgt": "behind_target_2", "val": [2, 3, 4]}]}},
	"unnamed_echo": {"name": "The Echo of the Unnamed", "tribe": "storm", "bite": 8, "hide": 8, "home": "void",
		"ability": {"id": "splinter", "name": "Splintering Void", "trig": "muster",
			"ops": [{"fx": "summon", "unit": "echo", "name": "Mirror", "tribe": "storm", "num": 2,
				"stats": [[3, 3], [4, 4], [5, 5]]}]}},
	"stormmouth": {"name": "Cyrraeth, Mouth of the Storm", "tribe": "storm", "bite": 8, "hide": 12, "home": "storm",
		"ability": {"id": "rotation", "name": "Storm Rotation", "trig": "bite",
			"ops": [{"fx": "status", "st": "frost", "tgt": "target"},
				{"fx": "dmg", "tgt": "all_enemies_but_target", "val": [2, 3, 4]}]}},
}

# ------------------------------------------------- charms (gems; §7.5)
# id must match FangmootSim._apply_charm. cost 3, one per token.
const CHARMS := {
	"ruby":       {"name": "Ruby",        "gem": "atk_flat", "desc": "+2 Bite."},
	"garnet":     {"name": "Garnet",      "gem": "hp_flat",  "desc": "+3 Hide."},
	"topaz":      {"name": "Topaz",       "gem": "crit",     "desc": "Its first strike each fight deals double."},
	"opal":       {"name": "Opal",        "gem": "combo",    "desc": "Ally Ahead Bites: +1 Bite this fight."},
	"onyx":       {"name": "Onyx",        "gem": "physres",  "desc": "Takes 1 less from strikes (min 1)."},
	"lapis":      {"name": "Lapis",       "gem": "magres",   "desc": "Immune to Rot, Burn and Frost."},
	"bloodstone": {"name": "Bloodstone",  "gem": "physpen",  "desc": "Its strikes ignore Ward."},
	"amber":      {"name": "Amber",       "gem": "dex",      "desc": "Strikes first; a target that Falls does not strike back."},
	"tenacity":   {"name": "Tenacity",    "gem": "flat_dr",  "desc": "Preserved (once per fight)."},
	"vampire":    {"name": "Vampire Eye", "gem": "lifesteal", "desc": "Heals half its Bite when it strikes."},
}
const CHARM_ORDER := ["ruby", "garnet", "topaz", "opal", "onyx", "lapis", "bloodstone", "amber", "tenacity", "vampire"]

# ------------------------------------------------- brews (one-shot; §7.6)
# effect applied by the moot layer on purchase. cost 2.
const BREWS := {
	"brawlers_red":    {"name": "Brawler's Red",     "desc": "+2 Hide permanently to one token.",
		"effect": {"stat": "hide", "val": 2, "perm": true, "scope": "one"}},
	"pit_fury":        {"name": "Pit Fury",           "desc": "+2 Bite permanently to one token.",
		"effect": {"stat": "bite", "val": 2, "perm": true, "scope": "one"}},
	"accordmark_tonic": {"name": "Accordmark Tonic",  "desc": "+1/+1 permanently to one token.",
		"effect": {"stat": "both", "val": 1, "perm": true, "scope": "one"}},
	"warding":         {"name": "Elixir of Warding",  "desc": "Ward next fight for one token.",
		"effect": {"stat": "ward", "val": 1, "perm": false, "scope": "one"}},
	"might":           {"name": "Elixir of Might",    "desc": "+3 Bite next fight for one token.",
		"effect": {"stat": "bite", "val": 3, "perm": false, "scope": "one"}},
	"carvers_meal":    {"name": "The Carver's Meal",  "desc": "+1 Hide permanently to every token.",
		"effect": {"stat": "hide", "val": 1, "perm": true, "scope": "all"}},
}
const BREW_ORDER := ["brawlers_red", "pit_fury", "accordmark_tonic", "warding", "might", "carvers_meal"]

# ------------------------------------------------------ summon token specs
# resolved by the summon op; kept here for the collection shelf and codex.
const SUMMONS := {
	"wolf":            {"name": "Blighted Wolf", "tribe": "wild"},
	"zombie":          {"name": "Risen Corpse",  "tribe": "hollow"},
	"root_spiderling": {"name": "Rootling",      "tribe": "root"},
	"echo":            {"name": "Mirror",        "tribe": "storm"},
}

# ------------------------------------------------------------- callers (§8)
# persona = {tribe_bias, greed, front_rule, bond_love, noise}; §8 bot reads them.
# front_rule: high_hide | martyrs | walls | growers_rear | balanced
const CALLERS := {
	"fisher_dov":   {"name": "Fisher Dov",     "table": "copper", "home": "bog",
		"bias": ["wild", "root"], "greed": 0.3, "front_rule": "high_hide", "bond_love": 0.4, "noise": 0.5,
		"voice": "gentle; the river gives what it gives."},
	"digger_haim":  {"name": "Digger Haim",    "table": "copper", "home": "marsh",
		"bias": ["hollow"], "greed": 0.35, "front_rule": "walls", "bond_love": 0.5, "noise": 0.5,
		"voice": "I dig them up; I ought to know them."},
	"skald_ottar":  {"name": "Skald Ottar",    "table": "silver", "home": "darkwood",
		"bias": ["wild"], "greed": 0.45, "front_rule": "high_hide", "bond_love": 0.6, "noise": 0.2,
		"voice": "boastful; the announcer."},
	"cantor_ilse":  {"name": "Cantor Ilse",    "table": "silver", "home": "graveyard",
		"bias": ["choir"], "greed": 0.4, "front_rule": "martyrs", "bond_love": 0.6, "noise": 0.2,
		"voice": "solemn; the Choir is never a joke."},
	"smith_petra":  {"name": "Smith Petra",    "table": "silver", "home": "magma",
		"bias": ["molten"], "greed": 0.4, "front_rule": "high_hide", "bond_love": 0.5, "noise": 0.2,
		"voice": "taciturn; one-line quips."},
	"herbalist_kesh": {"name": "Herbalist Kesh", "table": "silver", "home": "spore",
		"bias": ["root"], "greed": 0.65, "front_rule": "growers_rear", "bond_love": 0.7, "noise": 0.2,
		"voice": "patient; a greedy roller."},
	"storm_chaser_ilya": {"name": "Storm Chaser Ilya", "table": "gold", "home": "storm",
		"bias": ["storm"], "greed": 0.5, "front_rule": "balanced", "bond_love": 0.6, "noise": 0.05,
		"voice": "quick; chain-happy."},
	"warden_callis": {"name": "Warden Callis",  "table": "gold", "home": "keep",
		"bias": ["still", "hollow"], "greed": 0.35, "front_rule": "walls", "bond_love": 0.6, "noise": 0.05,
		"voice": "disciplined walls."},
	"old_fenna":    {"name": "Old Fenna",       "table": "gold", "home": "holy",
		"bias": ["hollow"], "greed": 0.45, "front_rule": "martyrs", "bond_love": 0.7, "noise": 0.05,
		"voice": "names every piece after someone she is forgetting."},
	"carver_tove":  {"name": "Carver Tove",     "table": "gold", "home": "",
		"bias": ["wild", "hollow", "choir", "molten", "still", "root", "storm"], "greed": 0.5,
		"front_rule": "balanced", "bond_love": 0.65, "noise": 0.05,
		"voice": "she carved every one of these."},
}
const CALLER_ORDER := ["fisher_dov", "digger_haim", "skald_ottar", "cantor_ilse", "smith_petra",
	"herbalist_kesh", "storm_chaser_ilya", "warden_callis", "old_fenna", "carver_tove"]

# ------------------------------------------------------------- grounds (§17)
# id -> {name, home_caller}. Layer 1 = ring look + home-ground +1/+1.
# rule = the Layer-2 symmetric rule id (v1.5; not applied in v1).
const GROUNDS := {
	"village":   {"name": "Emberfall Village",  "rule": ""},
	"darkwood":  {"name": "The Darkwood",        "rule": "ambush"},
	"marsh":     {"name": "The Blightmarsh",     "rule": "fester"},
	"keep":      {"name": "Vargoth's Keep",      "rule": "hollow_ground"},
	"magma":     {"name": "Scorched Wastes",     "rule": "cinders"},
	"ice":       {"name": "Frozen Expanse",      "rule": "rime"},
	"graveyard": {"name": "Restless Graveyard",  "rule": "compost"},
	"desert":    {"name": "Scorching Dunes",     "rule": "glare"},
	"bog":       {"name": "Poison Bog",          "rule": "mire"},
	"crystal":   {"name": "Crystal Caverns",     "rule": "facets"},
	"storm":     {"name": "Thunder Plains",      "rule": "conduction"},
	"void":      {"name": "The Void",            "rule": "null"},
	"holy":      {"name": "Sanctified Ruins",    "rule": "sanctuary"},
	"spore":     {"name": "Spore Glade",         "rule": "bloom"},
}
const GROUND_ORDER := ["village", "darkwood", "marsh", "keep", "magma", "ice", "graveyard",
	"desert", "bog", "crystal", "storm", "void", "holy", "spore"]

# ------------------------------------------------------------- tuning tables
# tier -> tray unlock turn window. §5.
const TIER_UNLOCK_TURN := {1: 1, 2: 3, 3: 5, 4: 7, 5: 9}

# --------------------------------------------------------------- accessors
static func all_token_ids() -> Array:
	return TOKENS.keys()

static func all_named_ids() -> Array:
	return NAMED.keys()

static func row(kind: String) -> Dictionary:
	if TOKENS.has(kind):
		return TOKENS[kind]
	if NAMED.has(kind):
		return NAMED[kind]
	return {}

static func is_named(kind: String) -> bool:
	return NAMED.has(kind)

static func tier_of(kind: String) -> int:
	if NAMED.has(kind):
		return 6
	return int(TOKENS.get(kind, {}).get("tier", 1))

static func tribe_of(kind: String) -> String:
	return String(row(kind).get("tribe", ""))

static func base_stats(kind: String) -> Vector2i:
	var r := row(kind)
	return Vector2i(int(r.get("bite", 1)), int(r.get("hide", 1)))
