class_name RoadDeck
## Road Deck v1 (Q14) — the seeded "encounter card" registry. Each entry is
## DATA; the materialize + resolve behavior lives in game_world.gd
## (`_road_card_node` dispatches on the id), the same data/behavior split
## Terrains and Items use. A card is offered AT THE DOOR of a SAFE
## (social / dead_end) campaign room on first visit, at most ~1-2 per run with a
## diminishing chance (Balance.ROAD_CARD_*) — the same seeded, withdraw-after-a-
## window shape as the cursed chest (_offer_cursed_chest).
##
## Owner rulings 2026-08-24 (see quest-framework-owner-decisions memory):
##  - road encounters pay ZERO xp (the first-run xp budget stays fixed);
##  - losing the refuse-fight carries NO penalty beyond the fight itself;
##  - these first-guess FREQUENCIES are accepted but FLAGGED FOR OWNER REVIEW
##    (Balance.ROAD_CARD_CHANCE / _FALLOFF and the per-card weights below).

const CARDS := {
	"toll": {
		"title": "The Bridgeward's Toll",
		"sprite": "roadside_peddler",
		"prompt": "E — A toll-collector bars the road",
		"weight": 3,
		"room_types": ["social", "dead_end"],
		"codex": "A cowled toll-collector bars the road with a rusted halberd. Pay his due in gold and he waves you through with a grudging blessing; refuse, and the brigands he keeps in the ditch rise to collect it in blood.",
	},
	"courier": {
		"title": "The Wounded Courier",
		"sprite": "villager",
		"prompt": "E — A wounded rider slumps by the road",
		"weight": 3,
		"room_types": ["social", "dead_end"],
		"codex": "A king's rider lies against a milestone, an arrow in his side and a heavy satchel across his chest. Spend a draught to mend him and he presses coin and goodwill on you; cut the strap instead and the purse is yours, but word of a road-thief travels.",
	},
	"wager": {
		"title": "The Stranger's Wager",
		"sprite": "roadside_peddler",
		"prompt": "E — A hooded gambler at a fire",
		"weight": 2,
		"room_types": ["social", "dead_end"],
		"codex": "A hooded figure crouches at a low fire, turning three walnut shells over the dirt. A fair 1-in-3: follow the pea and double your stake (rarely a gem falls out too); lose it and the stake is his.",
	},
}

## Draw order / eligibility list. Weights inside CARDS bias which one is picked
## once a draw succeeds; adding a card is one row here + one row in CARDS + one
## dispatch arm in game_world._road_card_node.
const DECK := ["toll", "courier", "wager"]

static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})

static func ids() -> Array:
	return DECK.duplicate()
