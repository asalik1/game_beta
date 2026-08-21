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
# Placeholder curio quest-items removed 2026-08-20 (owner: not up to par, and
# only ever surfaced in the dev Future>Items shelf — the player Curios tab
# already skipped placeholder-flagged items). The RELICS gallery below stays.
const QUEST_ITEMS := {}

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
	# ---- SHIPPED SIGNATURE PROPS & LANDMARKS (2026-08-16): the one-per-room
	# landmark tier (terrains.gd UNIQUE_PROP_NAMES) and the standout accents
	# placed live in real chapter terrains. Each keys on a single installed
	# sprite; every biome's signature silhouette is represented once, no dup
	# icons. Un-flagged so the codex Relics & landmarks shelf teaches them.
	# -- Vargoth's Keep --
	"castle_statue": {"name": "The Sentinel King", "sprite": "castle_statue",
		"lore": "A crowned figure keeping watch over Vargoth's empty courtyard, its sword reversed and point-down. The keep fell; the vigil did not."},
	"keep_brazier": {"name": "Vargoth's Watchfire", "sprite": "keep_brazier",
		"lore": "Lit by the last watch and never doused. Something still trims the wicks on the nights nobody climbs the stair."},
	"keep_arch": {"name": "The Ruined Arch", "sprite": "keep_arch",
		"lore": "A gate that outlived its wall and both its doors. Every road in the Vale seems to bend to pass under it once."},
	# -- Scorched Wastes --
	"forge_statue": {"name": "The Iron Judge", "sprite": "forge_statue",
		"lore": "Cast facing the Wastes with one hand raised as if mid-sentence. The verdict came long before the fires, and the fires were the verdict."},
	"magma_furnace": {"name": "The Everburning Furnace", "sprite": "magma_furnace",
		"lore": "Not fed in living memory, and never gone cold. Smiths who camp too close dream of work they never learned."},
	"magma_chainrig": {"name": "The Gibbet Rig", "sprite": "magma_chainrig",
		"lore": "Chain and a swinging arm above the slag, for lowering things in and, rarely, hauling them out. The Wastes do not keep graves."},
	"forge_cauldron": {"name": "The Slag Cauldron", "sprite": "forge_cauldron",
		"lore": "Metal kept molten past all reason, skinned grey and glowing beneath. The Wastes count wealth by what it has swallowed."},
	# -- Frozen Expanse --
	"ice_cairn": {"name": "The Waymarker", "sprite": "ice_cairn",
		"lore": "Flat stones stacked by hands the cold eventually took. Follow the ones still standing; the fallen point nowhere good."},
	"ice_sled": {"name": "The Abandoned Sled", "sprite": "ice_sled",
		"lore": "Runners frozen fast to the Expanse, its load long since carried off. The tracks that reach it come from every direction at once."},
	# -- Thunder Plains --
	"storm_conductor": {"name": "The Lightning Tree", "sprite": "storm_conductor",
		"lore": "An iron lattice the Plains strike again and again, because it asks them to. Shelter under it in a storm only if you are finished."},
	"storm_standing_stone": {"name": "The Standing Stone", "sprite": "storm_standing_stone",
		"lore": "Older than the Concord, older than the maps. Lightning splits around it, and the grass beneath stays dry."},
	# -- The Void --
	"void_obelisk": {"name": "The Black Needle", "sprite": "void_obelisk",
		"lore": "A finger of obsidian the Void pushed up through the ground. It reads warm to the touch, which is the wrong answer."},
	# -- Spore Glade & bog --
	"spore_shrine": {"name": "The Fungal Shrine", "sprite": "spore_shrine",
		"lore": "The glade raised it the way a reef is built, slow and without hands. Kneel if you like; the spores take the gesture as consent."},
	"spore_vent": {"name": "The Breathing Vent", "sprite": "spore_vent",
		"lore": "A soft hole in the bog that exhales warm spores in a slow, even rhythm. It is not breathing. It is not not breathing."},
	# -- Crystal Caverns --
	"crystal_spire": {"name": "The Crystal Spire", "sprite": "crystal_spire",
		"lore": "A single shard grown taller than a mast, ringing at a pitch just under hearing. Miners chart their tunnels never to quite reach it."},
	"geode": {"name": "The Split Geode", "sprite": "geode",
		"lore": "Cracked open by no pick anyone admits to, the lining still bright. Reach in and the Caverns take a finger's warmth as toll."},
	# -- Restless Graveyard --
	"coffin": {"name": "The Unclaimed Coffin", "sprite": "coffin",
		"lore": "Left above ground with the lid unpinned, waiting on a name the sexton never got. It is the right length for whoever studies it too long."},
	"grave_mound": {"name": "The Fresh Mound", "sprite": "grave_mound",
		"lore": "Turned earth with no stone and no record of a burial. The yard makes room before it is asked."},
	"crypt": {"name": "The Mausoleum", "sprite": "crypt",
		"lore": "A house for the dead with its door ajar and its residents mostly accounted for. The graveyard grew up around it like a town around a well."},
	# -- Village greens & Sanctified Ruins --
	"topiary": {"name": "The Kept Hedge", "sprite": "topiary",
		"lore": "Clipped into a shape no gardener wrote down, and holding it. Something tends it on the nights the greens stand empty."},
	"garden_fountain": {"name": "The Laughing Water", "sprite": "garden_fountain",
		"lore": "Dry a century, the basin still carries the sound of falling water on still evenings. The Sanctified Ruins keep it at their heart, and the Choir will not say why."},
	"garden_statue": {"name": "The Pouring Maid", "sprite": "garden_statue",
		"lore": "A handmaid of stone tipping an ewer that never empties into a pool that never fills. The village greens grew up around her, and no one recalls whom she served."},
	"castle_bust": {"name": "Kings Remembered", "sprite": "castle_bust", "placeholder": true,
		"lore": "Stone faces of men whose names outlived their kingdoms. Placeholder — awaiting a royal gallery."},
	"camp_bonfire": {"name": "A Traveler's Rest", "sprite": "camp_bonfire", "placeholder": true,
		"lore": "A ring of stones, swept clean, wood stacked for the next stranger. Placeholder — awaiting the wayfarer's camp."},
	"station_anvil_t3": {"name": "The Masterwork Anvil", "sprite": "station_anvil_t3", "placeholder": true,
		"lore": "Three generations of smiths wore the horn to a shine. Placeholder — awaiting the guild forge."},
	"library_cabinet": {"name": "The Locked Reliquary", "sprite": "library_cabinet", "placeholder": true,
		"lore": "Teal lacquer and gold filigree, and no keyhole anywhere. Placeholder — awaiting the great library."},
	# PLACEHOLDER GALLERY (armory / tools-materials / provisions) removed
	# 2026-08-20 (owner: not up to par). These 33 gallery relics only ever
	# rendered in the dev Future>Armory/Supplies/Provisions shelves and were
	# never placed live. The four landmark placeholders above (castle_bust,
	# camp_bonfire, station_anvil_t3, library_cabinet) stay — their sprites
	# ARE placed in live rooms; they await promotion to shipped codex relics.
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
