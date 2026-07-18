## pc_curios — Pixel Crawler full-pack mining sweep (2026-07-18): item-scale
## art cut from the packs (Esoteric / Sewer / Hideout sheets), registered as
## PLACEHOLDER quest items, plus a RELICS gallery of notable world props.
## Both feed the codex Curios tab. Everything placeholder-flagged is
## dev-launcher-only until a quest/profession promotes it (drop the flag and
## give it a real story home). Format: scripts/content/README.md.
class_name PcCurios

# {id: {name, desc, icon, grade?, placeholder?}} — merged into
# Story.ALL_QUEST_ITEMS by load_content; Items.make_quest_item(id) turns one
# into a bag rider (kind "quest") whenever a convo grants it.
const QUEST_ITEMS := {
	"curio_specimen": {"name": "Sealed Specimen", "icon": "curio_specimen", "grade": "B", "placeholder": true,
		"desc": "Something small floats in the brine, and it is facing you. The label is older than the Choir."},
	"curio_tome": {"name": "Green-Bound Tome", "icon": "curio_tome", "grade": "C", "placeholder": true,
		"desc": "The clasp has been forced and re-locked many times. Whoever owns it keeps deciding not to read it again."},
	"curio_scroll": {"name": "Sealed Dispatch", "icon": "curio_scroll", "grade": "C", "placeholder": true,
		"desc": "Military wax, no insignia. Carried far and never opened."},
	"curio_letter": {"name": "Unsent Letter", "icon": "curio_letter", "grade": "D", "placeholder": true,
		"desc": "Folded so carefully it must have mattered. The address is a village that burned."},
	"curio_quill": {"name": "Clerk's Quill", "icon": "curio_quill", "grade": "D", "placeholder": true,
		"desc": "Ink dried mid-word, still in the well. Some ledgers are better left unfinished."},
	"curio_key": {"name": "Tarnished Key", "icon": "curio_key", "grade": "C", "placeholder": true,
		"desc": "Heavy, gilded once, and cut for a lock nobody has found yet."},
	"curio_flask_blue": {"name": "Pale Blue Flask", "icon": "curio_flask_blue", "grade": "D", "placeholder": true,
		"desc": "Whatever it held evaporated years ago. The glass still smells faintly of winter."},
	"curio_flask_green": {"name": "Bile-Green Flask", "icon": "curio_flask_green", "grade": "D", "placeholder": true,
		"desc": "The stopper is fused shut. That is probably for the best."},
	"curio_tube_rack": {"name": "Alchemist's Rack", "icon": "curio_tube_rack", "grade": "C", "placeholder": true,
		"desc": "Five vials, four empty. The fifth is not empty."},
	"curio_potion_amber": {"name": "Amber Draught", "icon": "curio_potion_amber", "grade": "C", "placeholder": true,
		"desc": "Sewer-brewed and honey-bright. The brewers drank it daily and lived down there — take that as you will."},
	"curio_potion_blue": {"name": "Coldwater Draught", "icon": "curio_potion_blue", "grade": "C", "placeholder": true,
		"desc": "Chills the bottle from the inside. Sweats in warm rooms, like it wants out."},
	"curio_mug": {"name": "The Deserter's Mug", "icon": "curio_mug", "grade": "D", "placeholder": true,
		"desc": "Cheap tin, deep dents, one initial scratched out and another scratched in."},
}

# Notable world props the codex can teach — statues, monuments, landmarks.
# {id: {name, sprite, lore, placeholder?}}: shipped accents are visible to
# every player; placeholder ones (only placed in ph_* terrains) are dev-only.
const RELICS := {
	"grave_statue": {"name": "The Mourner", "sprite": "grave_statue",
		"lore": "A hooded figure that grieves over no particular grave. Sextons swear it faces a different row each dawn."},
	"grave_angel": {"name": "The Vigil", "sprite": "grave_angel",
		"lore": "Wings spread over the yard's oldest dead. The Choir did not carve it, and does not like being asked who did."},
	"crystal_cluster": {"name": "Singing Cluster", "sprite": "crystal_cluster",
		"lore": "Hum near it and it hums back, a half-tone off. Miners leave it alone; the off-note gets into your teeth."},
	"void_monolith": {"name": "The Silent Slab", "sprite": "void_monolith",
		"lore": "Obsidian that swallows lamplight whole. The crack down its face glows faintly when nobody watches it."},
	"void_rift": {"name": "A Held Breath", "sprite": "void_rift",
		"lore": "A tear the width of a hand, hanging where the sky forgot to close. The Waking left these behind like footprints."},
	"tree_gnarled": {"name": "The Strangler", "sprite": "tree_gnarled",
		"lore": "Vines thick as hawsers around a trunk that refuses to die. The wood inside is said to still be green."},
	"garden_fountain": {"name": "The Laughing Water", "sprite": "garden_fountain", "placeholder": true,
		"lore": "Dry for a century, the basin still sounds of falling water on quiet evenings. Placeholder — awaiting the palace gardens."},
	"garden_statue": {"name": "The Pouring Maid", "sprite": "garden_statue", "placeholder": true,
		"lore": "Her ewer never empties and never fills the pool. Placeholder — awaiting the palace gardens."},
	"castle_bust": {"name": "Kings Remembered", "sprite": "castle_bust", "placeholder": true,
		"lore": "Stone faces of men whose names outlived their kingdoms. Placeholder — awaiting a royal gallery."},
	"camp_bonfire": {"name": "A Traveler's Rest", "sprite": "camp_bonfire", "placeholder": true,
		"lore": "A ring of stones, swept clean, wood stacked for the next stranger. Placeholder — awaiting the wayfarer's camp."},
	"station_anvil_t3": {"name": "The Masterwork Anvil", "sprite": "station_anvil_t3", "placeholder": true,
		"lore": "Three generations of smiths wore the horn to a shine. Placeholder — awaiting the guild forge."},
	"library_cabinet": {"name": "The Locked Reliquary", "sprite": "library_cabinet", "placeholder": true,
		"lore": "Teal lacquer and gold filigree, and no keyhole anywhere. Placeholder — awaiting the great library."},
}


## Merge + resolution check: every curio is grantable via Items.make_quest_item
## and every icon/sprite resolves to installed art. Wall-clock-free.
static func selftest(_game: Node2D) -> String:
	for id in QUEST_ITEMS:
		if not Story.ALL_QUEST_ITEMS.has(id):
			return "pc_curios: quest item %s not merged into Story.ALL_QUEST_ITEMS" % id
		var item := Items.make_quest_item(String(id))
		if item.is_empty() or item.get("kind", "") != "quest":
			return "pc_curios: make_quest_item(%s) did not build a bag rider" % id
		if Art.tex(String(QUEST_ITEMS[id]["icon"])) == null:
			return "pc_curios: icon %s missing" % QUEST_ITEMS[id]["icon"]
	for id in RELICS:
		if not Story.ALL_RELICS.has(id):
			return "pc_curios: relic %s not merged into Story.ALL_RELICS" % id
		if Art.tex(String(RELICS[id]["sprite"])) == null:
			return "pc_curios: relic sprite %s missing" % RELICS[id]["sprite"]
	return ""
