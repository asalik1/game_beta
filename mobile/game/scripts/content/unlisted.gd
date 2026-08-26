class_name Unlisted
## The Unlisted (Q15, DYNAMIC_WORLD §5) — rare HIDDEN bosses, seeded per RUN off
## wander_seed, never on the map until you walk into their room, never a
## story_boss (they die down the rogue path — no story writes, no gates), and
## each banks ONCE per run. Cost is data: `_unlisted_inject` appends a zone
## {type:"boss", boss:<kind>, unlisted:<id>} and the arena / door / music /
## boss-bar all come free from `_try_spawn_boss`. Each reuses an EXISTING boss
## kit + elite affixes + a bespoke display_name — zero kit code, no new art
## required for the fight (a splash/keepsake can follow).
##
## This is a static DATA table (like RoadDeck / Terrains), consumed by the Game
## chain — NOT a Story content module, so it is not in Story.CONTENT_MODULES.
## New class_name → run `--import` before any headless run.
##
## Owner rulings 2026-08-24: frequencies are a first guess FLAGGED FOR REVIEW
## (they live in Balance.UNLISTED_CHANCE); the Unlisted never appear in ch1.

const ROSTER := {
	# The Tithe-Collector — a bandit-king framing over the sentinel kit: an
	# implacable toll-warden who has decided your debts are his. Bulwark makes
	# him a wall you have to grind, not burst.
	"tithe_collector": {
		"name": "The Tithe-Collector",
		"kind": "nullwarden",             # reuse the ch2 sentinel kit
		"affixes": ["bulwark"],
		"chapters": ["ch3", "ch4", "ch5"],  # not ch2 (its home) — no sprite double
	},
	# Old Greymantle — the wolf that got away from Fangmaw's warband, grown huge
	# and mean in the years since. The beast kit at two affixes.
	"greymantle": {
		"name": "Old Greymantle",
		"kind": "fangmaw",                # reuse the ch1 beast kit
		"affixes": ["savage", "swift"],
		"chapters": ["ch3", "ch4", "ch5", "ch6"],  # not ch1 (its home; also Unlisted skip ch1)
	},
}

static func ids() -> Array:
	return ROSTER.keys()

static func entry(id: String) -> Dictionary:
	return ROSTER.get(id, {})

## The Unlisted eligible for a chapter, in roster order.
static func for_chapter(chid: String) -> Array:
	var out: Array = []
	for id in ROSTER:
		if chid in ROSTER[id].get("chapters", []):
			out.append(String(id))
	return out
