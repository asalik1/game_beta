class_name Pockets
## Portal-stone POCKETS (Q15, DYNAMIC_WORLD §6) — an opt-in mini-arena reached by
## a portal stone in a safe room: a floating, in-graph boss arena you TELEPORT
## into and return from (owner ruling 2026-08-24 #6: IN-GRAPH, returns to the
## exact origin room, co-op-safe — never the standalone-chapter world swap the
## endgame/interludes use). Rolled per RUN off wander_seed, never ch1, banked
## once. Each reuses an EXISTING boss kit + affix + a bespoke name (zero kit
## code, no new art required for the fight — a `ph_*` look can follow).
##
## Static DATA table (like RoadDeck/Unlisted), consumed by the Game chain — NOT
## a Story content module. New class_name → run `--import` before headless.
##
## Each pocket now enforces its rule through pocket_trial.gd. Painted entry
## and exit stones persist; victory leaves time to collect spoils.

const ROSTER := {
	"molten_court": {
		"name": "The Molten Court",
		"kind": "cinderhide",             # reuse the ch4 magma bruiser
		"affixes": ["savage"],
		"terrain": "magma",
		"twist": "the floor tithes",
		"rule": "The Molten Court heats one half of the floor at a time. Gold borders warn for three seconds before the stone burns. The opposite half and the center seam stay cold. Lure the guardian onto hot stone to melt its obsidian plates.",
		"chapters": ["ch3", "ch4", "ch5", "ch6"],
	},
	"still_larder": {
		"name": "The Still Larder",
		"kind": "icebound",               # reuse the ch5 ice captain
		"affixes": ["bulwark"],
		"terrain": "ice",
		"twist": "no potions",
		"rule": "The Still Larder seals your bottles until its guardian falls. Drinking from the belt or bag spends nothing while the seal holds. Your class healing still works.",
		"chapters": ["ch4", "ch5", "ch6", "ch7"],
	},
}

static func ids() -> Array:
	return ROSTER.keys()

static func entry(id: String) -> Dictionary:
	return ROSTER.get(id, {})

## The pockets eligible for a chapter, in roster order.
static func for_chapter(chid: String) -> Array:
	var out: Array = []
	for id in ROSTER:
		if chid in ROSTER[id].get("chapters", []):
			out.append(String(id))
	return out
