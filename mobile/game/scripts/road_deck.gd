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
		"codex": "A toll-collector offers a moment's rest for gold and Accord standing. He accepts what you can spare. Push past and his companions lift a smaller sum from your purse, costing standing. You can also leave without paying or taking a penalty.",
	},
	"courier": {
		"title": "The Wounded Courier",
		"sprite": "villager",
		"prompt": "E — A wounded rider slumps by the road",
		"weight": 3,
		"room_types": ["social", "dead_end"],
		"codex": "A king's rider lies against a milestone, an arrow in his side. Spend gold on treatment and he repays you with coin and Accord goodwill; rob his satchel for a larger purse at a standing cost. Your own potions are never consumed. Leaving costs nothing.",
	},
	"wager": {
		"title": "The Stranger's Wager",
		"sprite": "roadside_peddler",
		"prompt": "E — A hooded gambler at a fire",
		"weight": 2,
		"room_types": ["social", "dead_end"],
		"codex": "A hooded figure offers three walnut shells and a fair 1-in-3 wager. Pick a shell: win a matching stake, sometimes with a gem, or lose the stake. No money changes hands until you pick. Leaving costs nothing.",
	},
	"hunt": {
		"title": "The Crooked Trail",
		"sprite": "npc_hunter",
		"prompt": "E — A hunter studies a torn trail",
		"weight": 3,
		"room_types": ["social", "dead_end"],
		"codex": "Follow three signs through the room and choose when to flush an elite quarry. Its level follows nearby creatures and is shown before accepting. Your party shares the tracks and the fight. Heroes present when it falls receive their own purse; the quarry pays no XP or ordinary kill loot. Leaving the room as a party abandons the hunt without an extra penalty. An unfinished hunt can be offered again.",
	},
	"caravan": {
		"title": "A Wheel in the Mud",
		"sprite": "roadside_peddler",
		"prompt": "E — A trader calls for help",
		"weight": 3,
		"room_types": ["social", "dead_end"],
		"codex": "A loaded cart is stuck. Accept two warned attacks and hold Interact at the shafts to pull it free. Creatures near the load stop the work and damage it; draw them away or defeat them. A partner can cover the puller. Free the wheel and defeat every attacker to make equipment and supplies 20% cheaper at road merchants for this chapter's run. The benefit does not stack or affect upgrades, gambling, the Crown Bazaar or endgame shops. No XP or ordinary kill loot; leaving or losing adds no penalty.",
	},
}

## Draw order / eligibility list. Weights inside CARDS bias which one is picked
## once a draw succeeds; adding a card is one row here + one row in CARDS + one
## dispatch arm in game_world._road_card_node.
const DECK := ["toll", "courier", "wager", "hunt", "caravan"]

static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})

static func ids() -> Array:
	return DECK.duplicate()


static func field_notes() -> Array[String]:
	var lines: Array[String] = ["In some quiet campaign rooms a stranger waits by the road. Offers withdraw after %d seconds if passed by; reading their decision holds the offer. A diminishing chance keeps these meetings occasional." % int(Balance.ROAD_CARD_WINDOW)]
	for id in DECK:
		lines.append(String(CARDS[id].title).to_upper() + " — " + String(CARDS[id].codex))
	lines.append("Only one optional fight runs in a room at a time. Invitations explain which encounter needs finishing first.")
	lines.append("A saved caravan supplies the shared road. Visiting friends, including late arrivals, receive that run's prices while keeping their own home progress.")
	lines.append("Road encounters pay no XP. Each run has its own deck. In a party, the leader accepts road offers; the Crooked Trail then belongs to the party, with personal purses for heroes present at victory.")
	return lines
