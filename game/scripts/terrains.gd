class_name Terrains
## The terrain library: every terrain is a look (ground, tint, weather
## particles) + a MECHANIC (hazard patches on the floor and/or a timed
## event). Zones reference a terrain by name; dev mode can repaint any
## zone with any terrain live.
##
## patches: static floor zones rolled at terrain apply
##   lava   damages everyone standing in it
##   ice    slippery: +35% move speed for you AND enemies
##   poison damages the player over time
##   heal   regenerates the player
##   slow   -30% move speed
## event: a timed happening (interval rolled from event_t)
##   magma_rain   telegraphed magma falls from the sky; floors collapse
##   grave_spawn  a zombie claws out of the ground near you
##   gust         a sandstorm gust shoves everyone sideways
##   lightning    fast telegraphed strikes near the player
##   shard        crystal bursts erupt at random spots

# TINT VALUE-FLOOR RULE (art audit 2026-07-09): the CanvasModulate tint
# does MOOD with hue, never with value crush. Keep every channel >= ~0.6
# and the average >= ~0.75 — the Forward+ tonemap already sinks midtones,
# and below that floor a biome's own signature props (tombstones, void
# pillars) merge into their ground. Darkness identity comes from the
# GROUND palette in art.gd + macro floor features, NOT from the modulate.
# (Graveyard at 0.78 avg deleted its own tombstones; void at 0.55/0.5/0.7
# was the worst offender.)
## Real silhouette families for repeated ecology. A terrain can keep weighting
## the canonical key while every placement deterministically selects one of
## these authored variants. This prevents a grove from stamping one tree PNG.
const PROP_VARIANT_GROUPS := [
	["tree_green", "tree_green2", "tree_green3", "tree_green4"],
	["tree_autumn", "tree_autumn2", "tree_autumn3"],
	["tree_teal", "tree_teal2", "tree_teal3"],
	["tree_snow", "tree_snow2", "tree_snow3"],
	["tree_winter", "tree_winter2", "tree_winter3"],
	["tree_spore", "tree_spore2", "tree_spore3"],
	["tree_gnarled", "tree_gnarled2", "tree_gnarled3"],
	["deadtree", "deadtree2", "deadtree3"],
	["bush", "bush2", "bush3"],
	["grass", "grass2", "grass3"],
	["cattail", "cattail2", "cattail3"],
	["mushroom", "mushroom2", "mushroom3"],
	["rock", "rock2", "rock3"],
	["boulder", "boulder2"],
	["tombstone", "tombstone2"],
]

# Signature silhouettes are landmarks, not environmental filler. They may
# appear once as a standalone accent OR once inside an authored structure,
# but random obstacle rolls must never stamp a second copy into the room.
const UNIQUE_PROP_NAMES := {
	"castle_statue": true,
	"forge_statue": true,
	"garden_fountain": true,
	"garden_statue": true,
	"grave_angel": true,
	"grave_statue": true,
	"ice_cairn": true,
	"magma_furnace": true,
	"spore_shrine": true,
	"storm_conductor": true,
	"storm_standing_stone": true,
	"void_monolith": true,
	"void_obelisk": true,
	"void_rift": true,
}


static func prop_family(name: String) -> Array:
	for family in PROP_VARIANT_GROUPS:
		if name in family:
			return family
	return [name]


static func prop_base(name: String) -> String:
	return String(prop_family(name)[0])


static func prop_variant(name: String, placement_seed: int) -> String:
	var family := prop_family(name)
	return String(family[absi(placement_seed) % family.size()])


const DATA := {
	# ------------------------------------------------ story terrains ---
	"village": {"name": "Emberfall Village", "ground": "grass", "path": "dirt",
		"tint": Color(1.0, 0.98, 0.9), "ambient": "leaves_green", "music": "village",
		"obstacles": ["tree_green", "tree_green", "tree_green", "rock", "rock2", "boulder", "tree_green2", "ruin_pillar"], "decor": ["flower", "flower", "pebble", "grass", "bush", "bush3", "mushroom", "toadstool", "signpost"], "accents": ["log", "garden_statue"], "count": 9,
		# Buildings are AUTHORED PER ZONE (_spawn_scenery), not terrain
		# scatter: this terrain paints the grass + props, and each village
		# ZONE opts into its own cottages/stall/camp kit. (Cottage roof
		# colorways a2/b2 = PNG override variants; _add_building mirrors.)
		"patches": [], "event": "", "ecology": ["village_grove"]},
	"darkwood": {"name": "The Darkwood", "ground": "forest", "path": "dirt",
		"tint": Color(0.87, 0.94, 0.88), "ambient": "leaves_autumn", "music": "darkwood",
		"obstacles": ["tree_autumn", "tree_autumn", "tree_autumn", "rock", "rock2", "boulder", "tree_gnarled"], "decor": ["mushroom", "pebble", "flower", "grass_autumn", "bush_autumn", "bush3", "toadstool", "tree_stump"], "accents": ["log", "tree_gnarled", "ruin_pillar"], "count": 14,
		"patches": [], "event": "", "ecology": ["darkwood_hollow"]},
	"marsh": {"name": "The Blightmarsh", "ground": "marsh", "path": "dirt",
		"tint": Color(0.9, 0.95, 0.8), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "tree_teal", "deadtree", "rock", "tree_teal2"], "decor": ["mushroom", "pebble", "grass", "bush", "cattail", "cattail"], "accents": ["dead_shrub", "log", "mushroom_purple", "spore_vent", "bones"], "count": 13,
		"patches": [], "event": "", "ecology": ["marsh_islet"],
		"river": {"chance": 0.45, "color": Color(0.10, 0.20, 0.19, 0.82)}},
	"keep": {"name": "Vargoth's Keep", "ground": "stone", "path": "stone",
		"tint": Color(0.8, 0.78, 0.88), "ambient": "embers", "music": "keep",
		"obstacles": ["ruin_pillar", "ruin_pillar", "rock", "rock2", "boulder", "rock3", "boulder2"], "decor": ["crack", "pebble", "rubble"], "accents": ["bones", "keep_brazier", "keep_arch", "castle_statue"], "count": 10,
		"patches": [], "event": "", "ecology": ["keep_courtyard"]},
	# ------------------------------------------------- new terrains ---
	"magma": {"name": "Scorched Wastes", "ground": "basalt", "path": "basalt",
		"tint": Color(1.0, 0.8, 0.7), "ambient": "embers", "music": "magma",
		"obstacles": ["rock_volcanic", "rock_volcanic", "rock_volcanic", "boulder", "rock3", "forge_cauldron"], "decor": ["crack", "crack", "pebble", "rubble", "forge_brazier"], "accents": ["bones", "forge_statue", "magma_furnace", "magma_chainrig", "keep_brazier"], "count": 11,
		"patches": [{"type": "lava", "count": 4, "radius": [55, 85]}],
		"ecology": ["magma_judgment"],
		"event": "magma_rain", "event_t": [3.5, 6.5]},
	"ice": {"name": "Frozen Expanse", "ground": "snow", "path": "snow",
		"tint": Color(0.88, 0.93, 1.05), "ambient": "snow", "music": "icefield",
		"obstacles": ["tree_snow", "tree_snow", "tree_winter", "rock_ice", "boulder"], "decor": ["pebble", "grass_frost", "frost_reeds", "stump_snow"], "accents": ["log", "crystal_spire", "ice_sled", "ice_cairn"], "count": 11,
		"patches": [{"type": "ice", "count": 10, "radius": [60, 110]}],
		"ecology": ["ice_waymarker"],
		"event": "", "bright": true},
	"graveyard": {"name": "Restless Graveyard", "ground": "gravedirt", "path": "gravedirt",
		# Pale cold mist, NOT darkness: the old 0.78-avg tint buried the
		# tombstones in their own ground (value-floor rule above).
		"tint": Color(0.88, 0.91, 0.96), "ambient": "mist", "music": "graveyard",
		# Anti-litter (2026-07-12): dropped coffin+crypt from the random
		# scatter — the 144px crypt sprayed ~4x/room read as clutter, not a
		# yard. Roster is now the tombstone family only; count 16 -> 11.
		# Diversity pass (2026-07-17): headstone/cross SHAPE variety so a
		# yard stops reading as one repeated stone (Pixel Crawler Cemetery
		# cuts). Big landmarks (cluster, mourner, angel statues) stay at 1
		# weight each = ~1/room per the anti-litter lesson; count 11 -> 10.
		"obstacles": ["tombstone", "tombstone", "tombstone2", "grave_cross", "grave_cross", "grave_cross2", "grave_deadtree"], "decor": ["grave_crack", "pebble"], "accents": ["tombstone3", "grave_statue", "grave_angel", "grave_bones", "grave_mound", "coffin"], "count": 10,
		"patches": [], "event": "grave_spawn", "event_t": [5.0, 9.0],
		"ecology": ["grave_memorial"]},
	"desert": {"name": "Scorching Dunes", "ground": "sand", "path": "sand",
		"tint": Color(1.05, 0.98, 0.85), "ambient": "sand", "music": "desert",
		"obstacles": ["rock", "deadtree", "sandstone", "sandstone", "boulder", "cactus", "cactus2"], "decor": ["pebble", "sand_drift", "sand_drift2", "grass_autumn"], "accents": ["dead_shrub", "bones", "magma_chainrig"], "count": 9,
		"patches": [], "event": "gust", "event_t": [7.0, 11.0], "bright": true,
		"ecology": ["desert_hoodoo"]},
	"bog": {"name": "Poison Bog", "ground": "bogsoil", "path": "bogsoil",
		"tint": Color(0.82, 0.9, 0.75), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "tree_teal", "deadtree", "tree_gnarled", "rock"], "decor": ["mushroom", "mushroom", "bush3", "cattail", "grass"], "accents": ["dead_shrub", "mushroom_purple", "spore_vent", "log", "bones"], "count": 12,
		"patches": [{"type": "poison", "count": 8, "radius": [55, 95]}],
		"event": "", "ecology": ["bog_rootwell"],
		# The Greyrun runs BLACK through the blightlands (ch2 mill canon).
		"river": {"chance": 0.5, "color": Color(0.07, 0.08, 0.08, 0.88)}},
	"crystal": {"name": "Crystal Caverns", "ground": "crystalfloor", "path": "crystalfloor",
		"tint": Color(0.85, 0.88, 1.05), "ambient": "twinkle", "music": "crystalline",
		"obstacles": ["crystal_cluster", "crystal_cluster", "crystal_spire", "rock2", "boulder", "boulder2", "stalagmite"], "decor": ["pebble", "crack", "rubble"], "accents": ["geode", "void_monolith"], "count": 12,
		"patches": [], "event": "shard", "event_t": [4.0, 7.0], "mp_boost": true,
		"ecology": ["crystal_garden"]},
	"storm": {"name": "Thunder Plains", "ground": "stormgrass", "path": "dirt",
		# Rain-grey does the mood; the grey-blue GROUND carries the biome.
		"tint": Color(0.8, 0.86, 0.95), "ambient": "rain", "music": "rainstorm",
		"obstacles": ["tree_green", "tree_green", "deadtree", "rock", "rock2", "boulder"], "decor": ["flower", "pebble", "grass", "bush", "bush3", "frost_reeds"], "accents": ["log", "storm_conductor", "storm_standing_stone", "ruin_pillar"], "count": 8,
		"patches": [], "event": "lightning", "event_t": [4.0, 7.5],
		"ecology": ["storm_array"]},
	"void": {"name": "The Void", "ground": "voidstone", "path": "voidstone",
		# Purple hue-skew keeps the menace; the near-black GROUND is the
		# darkness. The old 0.55/0.5/0.7 modulate ate the pillars too.
		"tint": Color(0.82, 0.74, 1.02), "ambient": "motes", "music": "void",
		"obstacles": ["rock_pale", "rock_pale", "boulder", "geode"], "decor": ["crack", "crack", "rubble"], "accents": ["void_rift", "void_monolith", "void_obelisk", "crystal_spire", "storm_standing_stone"], "count": 9,
		"patches": [{"type": "slow", "count": 7, "radius": [60, 100]}],
		"event": "", "ecology": ["void_breach"]},
	"holy": {"name": "Sanctified Ruins", "ground": "holystone", "path": "holystone",
		"tint": Color(1.05, 1.0, 0.88), "ambient": "sparkle", "music": "holy",
		"obstacles": ["ruin_pillar", "ruin_pillar", "rock", "rock2", "boulder"], "decor": ["flower", "flower", "crack", "pebble", "rubble"], "accents": ["grave_statue", "grave_angel", "garden_statue", "garden_fountain"], "count": 10,
		"patches": [{"type": "heal", "count": 4, "radius": [55, 75]}],
		"event": "", "bright": true, "ecology": ["holy_sanctum"]},
	"spore": {"name": "Spore Glade", "ground": "sporesoil", "path": "sporesoil",
		"tint": Color(0.95, 0.85, 1.0), "ambient": "spores", "music": "spore",
		"obstacles": ["tree_spore", "tree_spore", "tree_spore", "rock", "boulder"], "decor": ["mushroom", "mushroom", "mushroom_purple", "grass", "bush3"], "accents": ["spore_shrine", "spore_vent", "crystal_cluster", "tree_gnarled"], "count": 12,
		"patches": [{"type": "poison", "count": 5, "radius": [60, 90], "drift": true}],
		"event": "", "ecology": ["spore_cathedral"]},
	# ---------------------------------------- Crownfall capital districts ---
	# Safe civic palettes use the brighter procedural midtones rather than the
	# dark placeholder showcase floors. Capital zones author their own scenery,
	# so these profiles deliberately carry no random obstacle/decor scatter.
	"capital_civic": {"name": "Crownfall Civic Heart",
		"ground": "holystone", "path": "castletile",
		"tint": Color(1.0, 0.96, 0.90), "ambient": "sparkle", "music": "village",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": "", "bright": true},
	"capital_wayfinder": {"name": "Crownfall Wayfinder Ward",
		"ground": "stone", "path": "holystone",
		"tint": Color(0.90, 0.92, 1.0), "ambient": "embers", "music": "keep",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": ""},
	"capital_wildfang": {"name": "Crownfall Wildfang Enclave",
		"ground": "grass", "path": "dirt",
		"tint": Color(0.92, 0.98, 0.90), "ambient": "fireflies", "music": "darkwood",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": "", "bright": true},
	"capital_choir": {"name": "Crownfall Hollow Choir",
		"ground": "gravedirt", "path": "stone",
		"tint": Color(0.90, 0.90, 1.0), "ambient": "mist", "music": "graveyard",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": ""},
	"capital_accord": {"name": "Crownfall Accord Ward",
		"ground": "stormgrass", "path": "holystone",
		"tint": Color(0.96, 1.0, 0.94), "ambient": "leaves_green", "music": "village",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": "", "bright": true},
	"capital_cinderborn": {"name": "Crownfall Cinderborn Ward",
		"ground": "stone", "path": "holystone",
		"tint": Color(1.0, 0.90, 0.84), "ambient": "embers", "music": "keep",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": ""},
	"capital_approach": {"name": "Crownfall Emberward",
		"ground": "stone", "path": "holystone",
		"tint": Color(0.94, 0.95, 1.0), "ambient": "embers", "music": "keep",
		"obstacles": [], "decor": [], "accents": [], "count": 0,
		"patches": [], "event": "", "structures": ["keep_courtyard"]},
	# ---- future-biome gallery (2026-07-27 environment polish) ---------
	# Twenty owner-requested terrain TYPES, intentionally dev-preview-only.
	# Nothing in Story.CHAPTERS references these IDs: `placeholder` keeps them
	# on the dev panel / Future > Terrains shelf until a later content pass
	# assigns them. Each has a distinct floor material, prop ecology, weather,
	# wall family and (where appropriate) existing terrain mechanic.
	"ph_mossmeadow": {"name": "Mosslight Meadow", "ground": "mossmeadow", "path": "dirt",
		"tint": Color(0.96, 1.0, 0.91), "ambient": "leaves_green", "music": "village",
		"ecology": ["village_grove", "old_well", "town_fountain", "garden_statue", "ruined_gate"],
		"obstacles": ["tree_green", "tree_green", "tree_green2", "rock", "boulder", "ruin_pillar"],
		"decor": ["grass", "grass", "flower", "bush", "bush3", "pebble", "mushroom"],
		"accents": ["log", "garden_statue", "topiary"], "count": 11,
		"patches": [{"type": "heal", "count": 2, "radius": [48, 68]}], "event": "",
		"bright": true, "placeholder": true},
	"ph_amberwood": {"name": "Amberwood", "ground": "amberleaf", "path": "dirt",
		"tint": Color(1.0, 0.91, 0.78), "ambient": "leaves_autumn", "music": "darkwood",
		"ecology": ["darkwood_hollow", "old_well", "signal_fire", "ruined_gate", "tree_gnarled"],
		"obstacles": ["tree_autumn", "tree_autumn", "tree_autumn2", "tree_autumn3", "rock", "boulder"],
		"decor": ["grass_autumn", "grass_autumn", "bush_autumn", "mushroom", "pebble"],
		"accents": ["log", "tree_gnarled", "ruin_pillar"], "count": 14,
		"patches": [], "event": "", "placeholder": true},
	"ph_hollowgrove": {"name": "Hollow Grove", "ground": "hollowsoil", "path": "forest",
		"tint": Color(0.84, 0.91, 0.84), "ambient": "mist", "music": "darkwood",
		"ecology": ["bog_rootwell", "darkwood_hollow", "ruined_gate", "old_well", "mausoleum"],
		"obstacles": ["tree_gnarled", "tree_gnarled", "deadtree", "rock", "boulder", "ruin_pillar"],
		"decor": ["mushroom", "mushroom", "grass", "bush3", "pebble", "web"],
		"accents": ["log", "bones", "grave_statue"], "count": 10,
		"patches": [{"type": "slow", "count": 4, "radius": [45, 72]}], "event": "",
		"placeholder": true},
	"ph_moonfen": {"name": "Moonmirror Fen", "ground": "moonmire", "path": "dirt",
		"tint": Color(0.84, 0.96, 1.0), "ambient": "fireflies", "music": "marsh",
		"ecology": ["marsh_islet", "old_well", "sewer_outfall", "spore_shrine", "bog_rootwell"],
		"obstacles": ["tree_teal", "tree_teal", "deadtree", "rock"],
		"decor": ["cattail", "cattail", "grass", "mushroom", "pebble"],
		"accents": ["spore_shrine", "spore_vent", "log", "mushroom_purple"], "count": 11,
		"patches": [{"type": "poison", "count": 3, "radius": [45, 70]}], "event": "",
		"placeholder": true},
	"ph_mournfields": {"name": "Mourners' Fields", "ground": "mournearth", "path": "gravedirt",
		"tint": Color(0.92, 0.94, 1.0), "ambient": "mist", "music": "graveyard",
		"ecology": ["grave_memorial", "mausoleum", "crypt", "grave_angel", "grave_statue"],
		"obstacles": ["tombstone", "tombstone", "tombstone2", "grave_deadtree"],
		"decor": ["grave_crack", "grass_frost", "pebble"],
		"accents": ["tombstone3", "grave_statue", "grave_angel", "grave_mound", "grave_bones"], "count": 11,
		"patches": [], "event": "grave_spawn", "event_t": [6.0, 10.0],
		"placeholder": true},
	"ph_barrowmoor": {"name": "Weeping Barrowmoor", "ground": "barrowgrass", "path": "gravedirt",
		"tint": Color(0.86, 0.91, 0.88), "ambient": "mist", "music": "graveyard",
		"ecology": ["grave_memorial", "mausoleum", "crypt", "grave_mound", "grave_statue"],
		"obstacles": ["grave_mound", "grave_mound", "tombstone", "grave_deadtree", "tree_gnarled", "rock"],
		"decor": ["grass_frost", "grave_crack", "pebble", "grave_bones"],
		"accents": ["tombstone3", "grave_statue", "coffin"], "count": 12,
		"patches": [{"type": "slow", "count": 4, "radius": [50, 78]}], "event": "",
		"placeholder": true},
	"ph_ossuary": {"name": "The Open Ossuary", "ground": "bonefloor", "path": "stone",
		"tint": Color(0.94, 0.91, 0.84), "ambient": "embers", "music": "keep",
		"ecology": ["keep_courtyard", "mausoleum", "crypt", "grave_angel", "castle_statue"],
		"obstacles": ["ruin_pillar", "ruin_pillar", "tombstone3", "rock"],
		"decor": ["grave_bones", "bones", "grave_crack", "pebble"],
		"accents": ["grave_statue", "grave_angel", "keep_brazier", "coffin", "crypt"], "count": 9,
		"patches": [], "event": "", "structures": ["mausoleum", "torch_pillar"],
		"placeholder": true},
	"ph_ashflats": {"name": "Ashen Flats", "ground": "ashsoil", "path": "dirt",
		"tint": Color(1.0, 0.87, 0.78), "ambient": "sand", "music": "desert",
		"ecology": ["desert_hoodoo", "signal_fire", "ruined_gate", "old_well", "watch_brazier"],
		"obstacles": ["rock_volcanic", "rock_volcanic", "cactus", "sandstone", "boulder", "deadtree"],
		"decor": ["sand_drift", "pebble", "crack", "grass_autumn"],
		"accents": ["magma_chainrig", "bones", "dead_shrub"], "count": 9,
		"patches": [], "event": "gust", "event_t": [7.0, 11.0],
		"placeholder": true},
	"ph_slagworks": {"name": "The Slagworks", "ground": "slagstone", "path": "basalt",
		"tint": Color(1.0, 0.79, 0.68), "ambient": "embers", "music": "magma",
		"ecology": ["magma_judgment", "magma_furnace", "guild_forge", "great_hearth", "forge_statue"],
		"obstacles": ["rock_volcanic", "forge_cauldron", "boulder"],
		"decor": ["crack", "rubble", "pebble", "forge_brazier"],
		"accents": ["magma_furnace", "forge_statue", "magma_chainrig", "keep_brazier"], "count": 10,
		"patches": [{"type": "lava", "count": 5, "radius": [52, 82]}],
		"event": "magma_rain", "event_t": [4.0, 7.0],
		"structures": ["guild_forge", "watch_brazier"], "placeholder": true},
	"ph_obsidianreach": {"name": "Obsidian Reach", "ground": "obsidian", "path": "basalt",
		"tint": Color(0.82, 0.78, 0.94), "ambient": "motes", "music": "void",
		"ecology": ["void_breach", "void_monolith", "void_obelisk", "void_rift", "crystal_garden"],
		"obstacles": ["rock_volcanic", "rock_volcanic", "geode", "boulder"],
		"decor": ["crack", "rubble", "pebble"],
		"accents": ["void_rift", "void_monolith", "void_obelisk", "crystal_cluster"], "count": 9,
		"patches": [{"type": "slow", "count": 4, "radius": [54, 82]}], "event": "",
		"placeholder": true},
	"ph_cinderquarry": {"name": "Cinder Quarry", "ground": "cinderstone", "path": "basalt",
		"tint": Color(1.0, 0.84, 0.72), "ambient": "embers", "music": "magma",
		"ecology": ["magma_judgment", "guild_forge", "ruined_gate", "magma_furnace", "forge_statue"],
		"obstacles": ["rock_volcanic", "rock_volcanic", "sandstone", "boulder", "magma_chainrig"],
		"decor": ["rubble", "crack", "pebble", "sand_drift"],
		"accents": ["magma_furnace", "forge_statue"], "count": 12,
		"patches": [{"type": "lava", "count": 3, "radius": [45, 70]}], "event": "",
		"placeholder": true},
	"ph_rimewood": {"name": "Rimewood", "ground": "rimegrass", "path": "snow",
		"tint": Color(0.89, 0.95, 1.05), "ambient": "snow", "music": "icefield",
		"ecology": ["ice_waymarker", "old_well", "ruined_gate", "ice_cairn", "crystal_spire"],
		"obstacles": ["tree_snow", "tree_snow", "tree_winter", "rock_ice", "boulder"],
		"decor": ["grass_frost", "frost_reeds", "pebble", "stump_snow"],
		"accents": ["log", "ice_cairn", "storm_standing_stone"], "count": 13,
		"patches": [{"type": "ice", "count": 5, "radius": [48, 76]}], "event": "",
		"bright": true, "placeholder": true},
	"ph_frozenlake": {"name": "Frozen Mirror", "ground": "blueice", "path": "snow",
		"tint": Color(0.88, 0.96, 1.06), "ambient": "snow", "music": "icefield",
		"ecology": ["ice_waymarker", "crystal_garden", "ice_cairn", "crystal_spire", "geode"],
		"obstacles": ["rock_ice", "crystal_cluster", "tree_winter", "boulder"],
		"decor": ["frost_reeds", "grass_frost", "pebble"],
		"accents": ["ice_cairn", "crystal_spire", "geode", "ice_sled"], "count": 8,
		"patches": [{"type": "ice", "count": 12, "radius": [62, 112]}], "event": "",
		"bright": true, "placeholder": true},
	"ph_hoarfrostruins": {"name": "Hoarfrost Ruins", "ground": "hoarfrost", "path": "stone",
		"tint": Color(0.88, 0.92, 1.02), "ambient": "snow", "music": "icefield",
		"ecology": ["keep_courtyard", "ice_waymarker", "ruined_gate", "castle_statue", "mausoleum"],
		"obstacles": ["ruin_pillar", "ruin_pillar", "tree_winter", "rock_ice", "boulder"],
		"decor": ["grass_frost", "frost_reeds", "crack", "pebble"],
		"accents": ["ice_cairn", "castle_statue", "garden_statue", "keep_brazier"], "count": 10,
		"patches": [{"type": "ice", "count": 6, "radius": [52, 86]}], "event": "",
		"structures": ["ruined_gate"], "placeholder": true},
	"ph_crystalchasm": {"name": "Crystal Chasm", "ground": "deepcrystal", "path": "crystalfloor",
		"tint": Color(0.79, 0.88, 1.06), "ambient": "twinkle", "music": "crystalline",
		"ecology": ["crystal_garden", "void_breach", "geode", "crystal_spire", "void_monolith"],
		"obstacles": ["crystal_cluster", "crystal_cluster", "crystal_spire", "geode", "rock2", "boulder"],
		"decor": ["crack", "rubble", "pebble"],
		"accents": ["storm_standing_stone", "void_monolith"], "count": 14,
		"patches": [], "event": "shard", "event_t": [4.0, 7.0],
		"mp_boost": true, "placeholder": true},
	"ph_drownedfen": {"name": "Drowned Fen", "ground": "drownedsoil", "path": "bogsoil",
		"tint": Color(0.82, 0.94, 0.86), "ambient": "fireflies", "music": "marsh",
		"ecology": ["marsh_islet", "bog_rootwell", "sewer_outfall", "old_well", "spore_shrine"],
		"obstacles": ["tree_teal", "tree_teal", "deadtree", "spore_vent", "rock", "boulder"],
		"decor": ["cattail", "cattail", "grass", "mushroom", "pebble"],
		"accents": ["log", "spore_shrine", "mushroom_purple"], "count": 13,
		"patches": [{"type": "poison", "count": 6, "radius": [52, 84]}], "event": "",
		"placeholder": true},
	"ph_rootboundbog": {"name": "Rootbound Bog", "ground": "rootsoil", "path": "bogsoil",
		"tint": Color(0.88, 0.92, 0.75), "ambient": "fireflies", "music": "marsh",
		"ecology": ["bog_rootwell", "marsh_islet", "old_well", "spore_shrine", "darkwood_hollow"],
		"obstacles": ["tree_gnarled", "tree_teal", "tree_spore", "deadtree", "rock"],
		"decor": ["mushroom", "mushroom_purple", "cattail", "bush3", "pebble"],
		"accents": ["spore_shrine", "spore_vent", "log", "bones"], "count": 12,
		"patches": [{"type": "slow", "count": 5, "radius": [55, 90]},
			{"type": "poison", "count": 3, "radius": [48, 72]}],
		"event": "", "placeholder": true},
	"ph_fungalcathedral": {"name": "Fungal Cathedral", "ground": "fungalhumus", "path": "sporesoil",
		"tint": Color(0.92, 0.82, 1.02), "ambient": "spores", "music": "spore",
		"ecology": ["spore_cathedral", "spore_shrine", "bog_rootwell", "marsh_islet", "void_breach"],
		"obstacles": ["tree_spore", "tree_spore", "rock", "boulder"],
		"decor": ["mushroom", "mushroom", "mushroom_purple", "grass", "pebble"],
		"accents": ["spore_shrine", "spore_vent", "crystal_cluster", "tree_gnarled"], "count": 14,
		"patches": [{"type": "poison", "count": 7, "radius": [58, 92], "drift": true}],
		"event": "", "placeholder": true},
	"ph_stormspire": {"name": "Stormspire Plateau", "ground": "stormstone", "path": "stone",
		"tint": Color(0.79, 0.87, 0.98), "ambient": "rain", "music": "rainstorm",
		"ecology": ["storm_array", "storm_conductor", "storm_standing_stone", "ruined_gate", "signal_fire"],
		"obstacles": ["ruin_pillar", "rock", "rock2", "boulder"],
		"decor": ["grass_frost", "frost_reeds", "crack", "pebble"],
		"accents": ["storm_conductor", "storm_standing_stone", "crystal_spire", "keep_brazier"], "count": 9,
		"patches": [], "event": "lightning", "event_t": [3.5, 6.5],
		"structures": ["ruined_gate", "watch_brazier"], "placeholder": true},
	"ph_voidscar": {"name": "The Voidscar", "ground": "voidscar", "path": "voidstone",
		"tint": Color(0.74, 0.66, 0.94), "ambient": "motes", "music": "void",
		"ecology": ["void_breach", "void_monolith", "void_obelisk", "void_rift", "crystal_garden"],
		"obstacles": ["rock_volcanic", "geode", "boulder"],
		"decor": ["crack", "rubble", "pebble"],
		"accents": ["void_rift", "void_monolith", "void_obelisk", "crystal_spire", "storm_standing_stone"], "count": 10,
		"patches": [{"type": "slow", "count": 9, "radius": [58, 102]}], "event": "",
		"placeholder": true},
	# ---- placeholder terrains (2026-07-08 environment-pack sweep) ----
	# Authored from the owned Pixel Crawler environment packs, dev-only:
	# the codex hides them outside the dev launcher and tags them
	# [placeholder]; the dev panel can still paint any room with them to
	# preview the vibe. No zone references them, so normal play never uses
	# them. All reuse existing ground types / props / hazards.
	"ph_garden": {"name": "Palace Gardens", "ground": "grass", "path": "stone",
		"tint": Color(1.0, 0.98, 0.92), "ambient": "sparkle", "music": "holy",
		"obstacles": ["topiary", "topiary", "garden_bench", "garden_urns", "rock2"], "decor": ["flowerbed_pink", "flowerbed_red", "flowerbed_purple", "flowers_mixed", "flower", "grass", "window_box"], "accents": ["garden_statue", "garden_fountain", "clay_pot"], "count": 10,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	# ---- MMO-seed placeholder terrains (2026-07-18): guild/profession
	# previews for the multiplayer future (guild halls, crafting professions,
	# gathering). Station TIER LADDERS (t1->t3) + gathering nodes + crop
	# growth stages, all cut from the Free Pack station/Farm/Rocks sheets.
	"ph_guildhall": {"name": "Guild Hall", "ground": "holystone", "path": "holystone",
		"tint": Color(0.95, 0.9, 0.85), "ambient": "embers", "music": "village",
		"obstacles": ["station_anvil_t1", "station_anvil_t2", "station_anvil_t3", "station_furnace_t1", "station_furnace_t2", "station_furnace_t3", "station_alchemy_t1", "station_alchemy_t2", "station_alchemy_t3", "station_sawmill_t1", "station_sawmill_t2", "station_sawmill_t3", "library_shelf", "hideout_table", "amphora", "bench2"], "decor": ["library_rug", "candle", "castle_sconce", "pebble", "banner_red", "banner_blue", "banner_green"], "accents": ["castle_throne", "castle_banner", "camp_bonfire"], "count": 12,
		"structures": ["guild_forge", "brew_stand"],
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	"ph_fields": {"name": "Harvest Fields", "ground": "grass", "path": "dirt",
		"tint": Color(1.0, 0.97, 0.88), "ambient": "leaves_green", "music": "village",
		"obstacles": ["node_ore", "node_gold", "rock", "boulder", "tree_green", "fence"], "decor": ["crop_sprout", "crop_mid", "crop_carrot", "crop_cabbage", "crop_turnip", "node_herb", "grass", "flower", "sprout"], "accents": ["node_crystal", "camp_sawtable"], "count": 10,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	# ---- placeholder terrains (2026-07-18 full-pack mining sweep) ----
	# Prop kits cut from the Castle / Library / Hideout / Free Pack station
	# sheets; dev-panel-only until the owner assigns them a home. Same rules
	# as the 2026-07-08 batch: no zone references them, codex hides them.
	"ph_castle": {"name": "Royal Gallery", "ground": "stone", "path": "stone",
		"tint": Color(0.85, 0.82, 0.92), "ambient": "embers", "music": "keep",
		"obstacles": ["castle_bust", "castle_bust2", "pillar"], "decor": ["castle_sconce", "crack", "pebble", "carpet", "candelabra"], "accents": ["castle_statue", "castle_throne", "castle_banner"], "count": 10,
		"patches": [], "event": "",
		"placeholder": true},
	"ph_library": {"name": "The Great Library", "ground": "holystone", "path": "holystone",
		"tint": Color(0.98, 0.92, 0.82), "ambient": "sparkle", "music": "holy",
		"obstacles": ["library_shelf", "library_shelf2", "library_cabinet", "library_desk"], "decor": ["library_rug", "candle", "candelabra", "pebble"], "accents": ["library_planter"], "count": 9,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	"ph_hideout": {"name": "Bandit Hideout", "ground": "stone", "path": "dirt",
		"tint": Color(0.86, 0.82, 0.74), "ambient": "embers", "music": "darkwood",
		"obstacles": ["hideout_table", "hideout_cabinet", "hideout_locker", "hideout_kegs", "hideout_barrel", "chair"], "decor": ["web", "candle", "hideout_poster", "pebble", "water_bucket"], "accents": ["hideout_firepit"], "count": 11,
		"patches": [], "event": "",
		"placeholder": true},
	"ph_camp": {"name": "Wayfarer's Camp", "ground": "grass", "path": "dirt",
		"tint": Color(1.0, 0.96, 0.88), "ambient": "fireflies", "music": "village",
		"obstacles": ["camp_anvil", "camp_furnace", "camp_workbench", "camp_sawtable"], "decor": ["log2", "grass", "pebble"], "accents": ["camp_bonfire", "camp_tripod", "camp_meatrack"], "count": 9,
		"patches": [], "event": "",
		"placeholder": true},
	"ph_sewer": {"name": "Undercroft Sewer", "ground": "stone", "path": "stone",
		"tint": Color(0.72, 0.82, 0.78), "ambient": "mist", "music": "marsh",
		"obstacles": ["pillar", "rock", "sewer_pipe", "sewer_pipe2", "clay_pot", "clay_pot2"], "decor": ["bones", "crack", "pebble", "sewer_lantern", "web"], "count": 12,
		"patches": [{"type": "poison", "count": 5, "radius": [60, 95]}], "event": "",
		"placeholder": true},
	"ph_hall": {"name": "Castle Hall", "ground": "holystone", "path": "holystone",
		"tint": Color(0.9, 0.86, 0.95), "ambient": "embers", "music": "keep",
		"obstacles": ["pillar", "pillar", "rock"], "decor": ["crack", "pebble", "rubble"], "count": 10,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	"ph_fae": {"name": "Fae Grove", "ground": "forest", "path": "dirt",
		"tint": Color(0.85, 0.95, 0.92), "ambient": "fireflies", "music": "darkwood",
		"obstacles": ["tree_green", "tree_green", "rock"], "decor": ["flower", "flower", "mushroom", "bush"], "count": 15,
		"patches": [{"type": "heal", "count": 3, "radius": [55, 80]}], "event": "",
		"placeholder": true},
	# ---- composite-structure preview (2026-07-18, Lane 2) ----------------
	# Dev-only terrain that opts into the STRUCTURES catalog so the owner can
	# preview multi-part builds (a ruined gate, a lit brazier, a well, a
	# signal fire) in one room. No zone references it; normal play never sees
	# it. Structures place alongside the light scatter below.
	"ph_ruins": {"name": "Broken Bastion", "ground": "stone", "path": "stone",
		"tint": Color(0.84, 0.82, 0.86), "ambient": "embers", "music": "keep",
		"obstacles": ["pillar", "rock", "boulder", "rubble"], "decor": ["crack", "pebble", "rubble"], "accents": ["bones"], "count": 7,
		"structures": ["ruined_gate", "watch_brazier", "old_well", "signal_fire"],
		"patches": [], "event": "",
		"placeholder": true},
	# ---- SEAM-SHOWCASE terrains (2026-07-18) — each demonstrates all three
	# environment seams at once: an authored PNG FLOOR (ground_<kind>.png,
	# Lane 1), composite STRUCTURES (Lane 2), and ANIMATED props (Lane 3, any
	# obstacle/decor/decal whose sprite ships a _anim strip self-animates).
	# Dev-panel-only; no zone references them; normal play is untouched.
	# The Great Forge: an authored basalt floor with a molten-LAVA road (path
	# tileset), a working forge + brew stand + torch pillars, and standalone
	# pulsing furnaces. Ground + structures + animation, all lit.
	"ph_forge": {"name": "The Great Forge", "ground": "forgefloor", "path": "lavafield",
		"tint": Color(0.95, 0.82, 0.74), "ambient": "embers", "music": "keep",
		"obstacles": ["forge_hearth", "station_anvil_t3", "forge_cauldron", "boulder", "pillar"], "decor": ["flame", "crack", "pebble"], "accents": ["node_ore", "forge_statue"], "count": 9,
		"structures": ["guild_forge", "brew_stand", "torch_pillar"],
		"patches": [], "event": "",
		"placeholder": true},
	# The Kitchens: an authored WOOD floor with a stone walkway, a cooking
	# hearth + great hearth, standalone animated grills and a frying pan.
	"ph_kitchen": {"name": "The Kitchens", "ground": "hallwood", "path": "castletile",
		"tint": Color(1.0, 0.94, 0.84), "ambient": "embers", "music": "village",
		"obstacles": ["cook_grill", "camp_meatrack", "hideout_table", "amphora", "bench2"], "decor": ["cook_pan", "clay_pot", "water_bucket", "pebble"], "accents": ["camp_bonfire"], "count": 10,
		"structures": ["cook_hearth", "great_hearth"],
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	# Sunless Warren: an authored DUNGEON-STONE floor with a stone walkway,
	# torch pillars + a sludge outfall + a mausoleum, animated flame torches.
	"ph_dungeon": {"name": "Sunless Warren", "ground": "dungeonfloor", "path": "castletile",
		"tint": Color(0.78, 0.82, 0.88), "ambient": "mist", "music": "darkwood",
		"obstacles": ["pillar", "sewer_pipe", "sewer_pipe2", "clay_pot", "boulder"], "decor": ["flame", "bones", "crack", "web", "sewer_lantern"], "accents": ["node_crystal"], "count": 12,
		"structures": ["torch_pillar", "sewer_outfall", "mausoleum"],
		"patches": [{"type": "poison", "count": 4, "radius": [60, 90]}], "event": "",
		"placeholder": true},
	# Merchant Row: an authored TILE floor with a wood walkway, market stalls
	# with swaying awnings + a shimmering fountain + a notice board.
	"ph_market": {"name": "Merchant Row", "ground": "castletile", "path": "hallwood",
		"tint": Color(1.0, 0.96, 0.9), "ambient": "sparkle", "music": "village",
		"obstacles": ["hideout_table", "amphora", "clay_pot", "clay_pot2", "bench2"], "decor": ["banner_red", "carpet", "sprout", "pebble"], "accents": ["signpost"], "count": 11,
		"structures": ["market_stall", "market_stall", "town_fountain", "notice_board"],
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	# The Sunken Tombs: an authored dungeon floor, a mausoleum + torch pillars,
	# a full graveyard prop set with animated torch flames.
	"ph_crypt": {"name": "The Sunken Tombs", "ground": "dungeonfloor", "path": "dungeonfloor",
		"tint": Color(0.8, 0.82, 0.9), "ambient": "mist", "music": "keep",
		"obstacles": ["crypt", "tombstone", "tombstone2", "grave_cross", "coffin", "pillar"], "decor": ["flame", "grave_bones", "grave_crack", "bones", "web"], "accents": ["grave_statue", "grave_angel"], "count": 11,
		"structures": ["mausoleum", "torch_pillar"],
		"patches": [], "event": "",
		"placeholder": true},
}

# Procedural environment taxonomy (owner clarification 2026-07-28):
# - exactly one LANDMARK candidate is selected per room;
# - multiple ACCENT kinds may appear, each with its own bell-curve group size;
# - obstacles + decor are repeatable PROPS.
# Every non-capital terrain resolves to >=5 kinds in each tier. Terrain-local
# ecology/structures/accents lead the roster; these family pools fill gaps.
const LANDMARK_POOLS := {
	"village": ["village_grove", "old_well", "market_stall", "notice_board", "town_fountain"],
	"darkwood": ["darkwood_hollow", "ruined_gate", "old_well", "signal_fire", "mausoleum"],
	"marsh": ["marsh_islet", "bog_rootwell", "old_well", "sewer_outfall", "spore_shrine"],
	"keep": ["keep_courtyard", "ruined_gate", "castle_statue", "watch_brazier", "mausoleum"],
	"magma": ["magma_judgment", "forge_statue", "magma_furnace", "guild_forge", "great_hearth"],
	"ice": ["ice_waymarker", "ice_cairn", "crystal_spire", "old_well", "ruined_gate"],
	"graveyard": ["grave_memorial", "mausoleum", "crypt", "grave_angel", "grave_statue"],
	"desert": ["desert_hoodoo", "ruined_gate", "signal_fire", "old_well", "watch_brazier"],
	"bog": ["bog_rootwell", "marsh_islet", "old_well", "sewer_outfall", "spore_shrine"],
	"crystal": ["crystal_garden", "void_breach", "geode", "crystal_spire", "void_monolith"],
	"storm": ["storm_array", "storm_conductor", "storm_standing_stone", "ruined_gate", "signal_fire"],
	"void": ["void_breach", "void_monolith", "void_obelisk", "void_rift", "crystal_garden"],
	"holy": ["holy_sanctum", "garden_fountain", "garden_statue", "grave_angel", "town_fountain"],
	"spore": ["spore_cathedral", "spore_shrine", "bog_rootwell", "marsh_islet", "void_breach"],
}

const MUSIC_TERRAIN_FAMILY := {
	"village": "village", "darkwood": "darkwood", "marsh": "marsh",
	"keep": "keep", "magma": "magma", "icefield": "ice",
	"graveyard": "graveyard", "desert": "desert", "crystalline": "crystal",
	"rainstorm": "storm", "void": "void", "holy": "holy", "spore": "spore",
}

const ACCENT_FAMILY_POOLS := {
	"village": ["log", "tree_gnarled", "mushroom_purple", "topiary", "signpost"],
	"darkwood": ["log", "tree_gnarled", "mushroom_purple", "dead_shrub", "bones"],
	"marsh": ["spore_vent", "mushroom_purple", "dead_shrub", "log", "bones"],
	"keep": ["keep_brazier", "keep_arch", "bones", "coffin", "magma_chainrig"],
	"magma": ["magma_chainrig", "keep_brazier", "bones", "forge_cauldron", "rock_volcanic"],
	"ice": ["log", "crystal_spire", "ice_sled", "geode", "dead_shrub"],
	"graveyard": ["tombstone3", "grave_bones", "grave_mound", "coffin", "bones"],
	"desert": ["dead_shrub", "bones", "magma_chainrig", "sandstone", "cactus"],
	"bog": ["spore_vent", "mushroom_purple", "dead_shrub", "log", "bones"],
	"crystal": ["geode", "crystal_spire", "crystal_cluster", "stalagmite", "rubble"],
	"storm": ["log", "ruin_pillar", "crystal_spire", "dead_shrub", "frost_reeds"],
	"void": ["crystal_spire", "geode", "magma_chainrig", "bones", "rock_pale"],
	"holy": ["grave_bones", "keep_brazier", "topiary", "tombstone3", "ruin_pillar"],
	"spore": ["spore_vent", "crystal_cluster", "tree_gnarled", "mushroom_purple", "dead_shrub"],
}

# Count is sampled from N(peak, sigma), rounded and clamped to [1, max].
# Peaks are authored per accent kind: a lone sign/coffin is normal, while
# crystals, giant fungi and large-tree stands naturally center around three.
const ACCENT_PROFILES := {
	"bones": {"peak": 1.0, "sigma": 0.55, "max": 3, "radius": 52.0},
	"cactus": {"peak": 2.0, "sigma": 0.75, "max": 5, "radius": 82.0},
	"coffin": {"peak": 1.0, "sigma": 0.45, "max": 2, "radius": 48.0},
	"crystal_cluster": {"peak": 3.0, "sigma": 0.85, "max": 6, "radius": 88.0},
	"crystal_spire": {"peak": 3.0, "sigma": 0.8, "max": 6, "radius": 92.0},
	"dead_shrub": {"peak": 2.0, "sigma": 0.7, "max": 5, "radius": 72.0},
	"forge_cauldron": {"peak": 1.0, "sigma": 0.5, "max": 3, "radius": 60.0},
	"frost_reeds": {"peak": 3.0, "sigma": 0.9, "max": 6, "radius": 86.0},
	"geode": {"peak": 3.0, "sigma": 0.8, "max": 6, "radius": 88.0},
	"grave_bones": {"peak": 1.0, "sigma": 0.55, "max": 3, "radius": 52.0},
	"grave_mound": {"peak": 2.0, "sigma": 0.65, "max": 4, "radius": 70.0},
	"ice_sled": {"peak": 1.0, "sigma": 0.4, "max": 2, "radius": 48.0},
	"keep_arch": {"peak": 1.0, "sigma": 0.45, "max": 2, "radius": 54.0},
	"keep_brazier": {"peak": 2.0, "sigma": 0.7, "max": 4, "radius": 74.0},
	"log": {"peak": 2.0, "sigma": 0.7, "max": 4, "radius": 76.0},
	"magma_chainrig": {"peak": 1.0, "sigma": 0.5, "max": 3, "radius": 62.0},
	"mushroom_purple": {"peak": 3.0, "sigma": 0.85, "max": 6, "radius": 84.0},
	"rock_pale": {"peak": 3.0, "sigma": 0.9, "max": 6, "radius": 88.0},
	"rock_volcanic": {"peak": 3.0, "sigma": 0.9, "max": 6, "radius": 90.0},
	"rubble": {"peak": 3.0, "sigma": 0.95, "max": 7, "radius": 84.0},
	"ruin_pillar": {"peak": 2.0, "sigma": 0.65, "max": 4, "radius": 82.0},
	"sandstone": {"peak": 3.0, "sigma": 0.85, "max": 6, "radius": 92.0},
	"signpost": {"peak": 1.0, "sigma": 0.4, "max": 2, "radius": 44.0},
	"spore_vent": {"peak": 3.0, "sigma": 0.85, "max": 6, "radius": 82.0},
	"stalagmite": {"peak": 3.0, "sigma": 0.85, "max": 6, "radius": 86.0},
	"tombstone3": {"peak": 2.0, "sigma": 0.65, "max": 4, "radius": 74.0},
	"topiary": {"peak": 2.0, "sigma": 0.65, "max": 4, "radius": 78.0},
	"tree_gnarled": {"peak": 3.0, "sigma": 0.75, "max": 5, "radius": 112.0},
}


static func uses_procedural_taxonomy(id: String) -> bool:
	return not id.begins_with("capital_")


static func terrain_family(id: String) -> String:
	if LANDMARK_POOLS.has(id):
		return id
	var terrain: Dictionary = get_terrain(id)
	return String(MUSIC_TERRAIN_FAMILY.get(String(terrain.get("music", "village")), "village"))


static func landmark_candidates(id: String, zone_structures: Array = []) -> Array:
	var terrain: Dictionary = get_terrain(id)
	var out: Array = []
	for source in [terrain.get("ecology", []), terrain.get("structures", []), zone_structures]:
		for raw_name in source:
			var name := String(raw_name)
			if not name.is_empty() and name not in out:
				out.append(name)
	var family := terrain_family(id)
	for raw_name in LANDMARK_POOLS.get(family, LANDMARK_POOLS["village"]):
		var name := String(raw_name)
		if name not in out:
			out.append(name)
	return out


## Seeded draw without replacement across rooms of the same terrain. The first
## roster-length occurrences are all different; only then may the cycle repeat.
static func landmark_for_occurrence(id: String, candidates: Array, occurrence: int) -> String:
	if candidates.is_empty():
		return ""
	var shuffled := candidates.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash() * 7919 + 7282026
	for idx in range(shuffled.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, idx)
		var held = shuffled[idx]
		shuffled[idx] = shuffled[swap_idx]
		shuffled[swap_idx] = held
	return String(shuffled[posmod(occurrence, shuffled.size())])


static func accent_specs(id: String, raw_accents: Array = []) -> Array:
	var terrain: Dictionary = get_terrain(id)
	var source: Array = raw_accents if not raw_accents.is_empty() else terrain.get("accents", [])
	var family := terrain_family(id)
	var combined: Array = source.duplicate()
	combined.append_array(ACCENT_FAMILY_POOLS.get(family, ACCENT_FAMILY_POOLS["village"]))
	var out: Array = []
	var seen := {}
	for raw_accent in combined:
		var supplied: Dictionary = raw_accent if raw_accent is Dictionary else {}
		var name := String(supplied.get("name", supplied.get("sprite", raw_accent)))
		var base := prop_base(name)
		# Signature landmarks belong exclusively to the one-of-N landmark tier.
		if name.is_empty() or is_unique_prop(base) or seen.has(base):
			continue
		seen[base] = true
		var defaults: Dictionary = ACCENT_PROFILES.get(base, {
			"peak": 1.0, "sigma": 0.55, "max": 3, "radius": 58.0})
		var spec: Dictionary = {"name": name}
		for key in defaults:
			spec[key] = defaults[key]
		for key in supplied:
			if key != "name" and key != "sprite":
				spec[key] = supplied[key]
		out.append(spec)
	return out


static func sample_accent_count(spec: Dictionary, rng: RandomNumberGenerator) -> int:
	var peak := float(spec.get("peak", 1.0))
	var sigma := maxf(0.05, float(spec.get("sigma", 0.55)))
	return clampi(roundi(rng.randfn(peak, sigma)), 1,
		maxi(1, int(spec.get("max", 3))))


static func repeatable_prop_kinds(id: String) -> Array:
	var terrain: Dictionary = get_terrain(id)
	var out: Array = []
	for tier in ["obstacles", "decor"]:
		for raw_name in terrain.get(tier, []):
			var base := prop_base(String(raw_name))
			if not is_unique_prop(base) and base not in out:
				out.append(base)
	return out


# Ambient AUDIO bed per terrain (Sfx.make_ambient kinds; "" = silence).
# The visual weather lives in AMBIENTS below; this is its soundtrack.
const AMBIENT_LOOPS := {
	"village": "amb_birds", "darkwood": "amb_birds", "holy": "amb_birds",
	"storm": "amb_rain", "desert": "amb_wind",
	"ice": "amb_cold",
	"marsh": "amb_crickets", "bog": "amb_crickets", "spore": "amb_crickets",
	"keep": "amb_drone", "void": "amb_drone", "graveyard": "amb_drone",
	"magma": "amb_drone", "crystal": "amb_drone",
	# Future-biome gallery keeps its visual weather audible in the dev panel.
	"ph_mossmeadow": "amb_birds", "ph_amberwood": "amb_birds",
	"ph_hollowgrove": "amb_drone", "ph_moonfen": "amb_crickets",
	"ph_mournfields": "amb_drone", "ph_barrowmoor": "amb_drone",
	"ph_ossuary": "amb_drone", "ph_ashflats": "amb_wind",
	"ph_slagworks": "amb_drone", "ph_obsidianreach": "amb_drone",
	"ph_cinderquarry": "amb_wind", "ph_rimewood": "amb_cold",
	"ph_frozenlake": "amb_cold", "ph_hoarfrostruins": "amb_cold",
	"ph_crystalchasm": "amb_drone", "ph_drownedfen": "amb_crickets",
	"ph_rootboundbog": "amb_crickets", "ph_fungalcathedral": "amb_crickets",
	"ph_stormspire": "amb_rain", "ph_voidscar": "amb_drone",
}

# Weather / ambient particle presets.
# above=true spawns in a band above the camera (falling), else around it.
const AMBIENTS := {
	"leaves_green":  {"color": Color(0.7, 0.9, 0.4), "dir": Vector2(0.4, 1), "gravity": Vector2(6, 22), "vel": [12.0, 30.0], "scale": [2.0, 3.2], "amount": 14, "above": true},
	"leaves_autumn": {"color": Color(1.0, 0.55, 0.15), "dir": Vector2(0.4, 1), "gravity": Vector2(6, 22), "vel": [12.0, 30.0], "scale": [2.0, 3.2], "amount": 14, "above": true},
	"fireflies": {"color": Color(0.75, 1.0, 0.45, 0.85), "dir": Vector2.ZERO, "gravity": Vector2.ZERO, "vel": [6.0, 16.0], "scale": [1.4, 2.2], "amount": 10, "above": false},
	"embers": {"color": Color(1.0, 0.55, 0.2, 0.9), "dir": Vector2(0, -1), "gravity": Vector2(0, -18), "vel": [8.0, 20.0], "scale": [1.5, 2.4], "amount": 10, "above": false},
	"snow": {"color": Color(0.98, 0.98, 1.0, 0.95), "dir": Vector2(0.15, 1), "gravity": Vector2(4, 26), "vel": [16.0, 40.0], "scale": [1.6, 2.6], "amount": 28, "above": true},
	"rain": {"color": Color(0.6, 0.72, 1.0, 0.7), "dir": Vector2(0.12, 1), "gravity": Vector2(0, 480), "vel": [260.0, 380.0], "scale": [1.0, 1.6], "amount": 30, "above": true},
	"sand": {"color": Color(0.85, 0.72, 0.45, 0.8), "dir": Vector2(1, 0.08), "gravity": Vector2(26, 3), "vel": [60.0, 140.0], "scale": [1.4, 2.2], "amount": 16, "above": false},
	"mist": {"color": Color(0.8, 0.85, 0.85, 0.35), "dir": Vector2(1, 0), "gravity": Vector2(3, 0), "vel": [4.0, 10.0], "scale": [4.0, 7.0], "amount": 8, "above": false},
	"twinkle": {"color": Color(0.5, 0.9, 1.0, 0.9), "dir": Vector2.ZERO, "gravity": Vector2.ZERO, "vel": [2.0, 8.0], "scale": [1.2, 2.0], "amount": 12, "above": false},
	"motes": {"color": Color(0.55, 0.35, 0.8, 0.7), "dir": Vector2(0, -1), "gravity": Vector2(0, -6), "vel": [3.0, 9.0], "scale": [1.4, 2.4], "amount": 9, "above": false},
	"sparkle": {"color": Color(1.0, 0.92, 0.55, 0.9), "dir": Vector2(0, -1), "gravity": Vector2(0, -12), "vel": [6.0, 14.0], "scale": [1.2, 2.0], "amount": 10, "above": false},
	"spores": {"color": Color(0.8, 0.55, 0.95, 0.8), "dir": Vector2(0.2, -0.4), "gravity": Vector2(2, -4), "vel": [4.0, 10.0], "scale": [1.6, 2.8], "amount": 12, "above": false},
}

# Hazard patch visuals: glow tint per type.
const PATCH_COLOR := {
	"lava":   Color(1.0, 0.4, 0.1, 0.55),
	"ice":    Color(0.6, 0.85, 1.0, 0.4),
	"poison": Color(0.45, 0.9, 0.25, 0.45),
	"heal":   Color(1.0, 0.9, 0.45, 0.4),
	"slow":   Color(0.4, 0.2, 0.6, 0.5),
	"churned": Color(0.6, 0.45, 0.3, 0.55),  # Sexton's grave-earth (phys, boss-only)
}


static func get_terrain(id: String) -> Dictionary:
	return DATA.get(id, DATA["village"])


# Per-terrain WALL tile (2026-07-08): room perimeter walls used to be one
# global grey brick ("wallblock") in every biome. Each seamless 16px tile
# below is cut from the matching Pixel Crawler environment pack; terrains not
# listed fall back to the Castle stone (wallblock). Rendered by
# game_world._build_room_walls / _wall.
const WALL := {
	"village": "wall_wood",
	"darkwood": "wall_moss", "marsh": "wall_moss", "bog": "wall_moss",
	"spore": "wall_moss", "ph_fae": "wall_moss",
	# mining sweep 2026-07-18: placeholder terrains wear their OWN walls
	"ph_sewer": "wall_sewer", "ph_garden": "wall_hedge",
	"ph_castle": "wall_castle", "ph_guildhall": "wall_castle", "ph_library": "wall_castle",
	"ph_hideout": "wall_wood",
	# 2026-07-27 future-biome gallery.
	"ph_mossmeadow": "wall_hedge", "ph_amberwood": "wall_wood",
	"ph_hollowgrove": "wall_moss", "ph_moonfen": "wall_wood",
	"ph_drownedfen": "wall_sewer", "ph_rootboundbog": "wall_wood",
	"ph_fungalcathedral": "wall_moss",
	"ph_mournfields": "wall_grave", "ph_barrowmoor": "wall_grave",
	"ph_ossuary": "wall_castle",
	"ph_ashflats": "wall_sand", "ph_slagworks": "wall_volcanic",
	"ph_obsidianreach": "wall_volcanic", "ph_cinderquarry": "wall_volcanic",
	"ph_voidscar": "wall_volcanic",
	"ph_rimewood": "wall_wood", "ph_frozenlake": "wall_ice",
	"ph_hoarfrostruins": "wall_castle", "ph_crystalchasm": "wall_ice",
	"ph_stormspire": "wall_castle",
	# seam-showcase terrains
	"ph_forge": "wall_volcanic", "ph_kitchen": "wall_wood", "ph_dungeon": "wall_sewer",
	"ph_market": "wall_castle", "ph_crypt": "wall_grave",
	# Crownfall districts: civic masonry stays consistent while each enclave
	# gets one restrained edge material of its own.
	"capital_civic": "wall_castle", "capital_wayfinder": "wall_castle",
	"capital_wildfang": "wall_moss", "capital_choir": "wall_grave",
	"capital_accord": "wall_hedge", "capital_cinderborn": "wall_castle",
	"capital_approach": "wall_castle",
	"magma": "wall_volcanic", "void": "wall_volcanic",
	"ice": "wall_ice",
	"graveyard": "wall_grave",
	"desert": "wall_sand",
	# keep / crystal / storm / holy / ph_hall -> wallblock (stone) default
}

static func wall_for(id: String) -> String:
	return WALL.get(id, "wallblock")


# Reusing a construction family does not mean reusing its finish. These
# restrained per-biome material grades make the room boundary belong to the
# authored floor without turning the walls into neon color filters.
const WALL_TINT := {
	"ph_mossmeadow": Color("#a9bd86"),
	"ph_amberwood": Color("#bd8a62"),
	"ph_hollowgrove": Color("#71806b"),
	"ph_moonfen": Color("#788e92"),
	"ph_mournfields": Color("#aaa7a1"),
	"ph_barrowmoor": Color("#7f846f"),
	"ph_ossuary": Color("#b9af98"),
	"ph_ashflats": Color("#9b8c82"),
	"ph_slagworks": Color("#8f6c5e"),
	"ph_obsidianreach": Color("#71677e"),
	"ph_cinderquarry": Color("#a16e58"),
	"ph_rimewood": Color("#a4b6bc"),
	"ph_frozenlake": Color("#91b8ca"),
	"ph_hoarfrostruins": Color("#a6b4bd"),
	"ph_crystalchasm": Color("#838eb9"),
	"ph_drownedfen": Color("#657a70"),
	"ph_rootboundbog": Color("#82745c"),
	"ph_fungalcathedral": Color("#927487"),
	"ph_stormspire": Color("#8095a8"),
	"ph_voidscar": Color("#695274"),
}

static func wall_tint_for(id: String) -> Color:
	return WALL_TINT.get(id, Color.WHITE)


# Composite STRUCTURES (2026-07-18, Lane 2 unlock): multi-part builds placed
# by game_world._add_structure — several sprites y-sorted as ONE body, a
# MULTI-shape footprint collider, and non-colliding WALL DECALS (banners,
# torches) that can animate and carry a point light. Zones/terrains opt in via
# a "structures" list, exactly like "buildings". Every referenced sprite is
# EXISTING art, so these compose with no new assets; a drop-in <name>.png (or
# <name>_anim.png) override upgrades any part in place. An unlisted structure
# name still places — it degrades to a single base sprite + footprint rect.
# Schema per structure:
#   sprite      base art (defaults to the structure's own name)
#   w           base sprite target width (px); parts/decals scale off it
#   wind        base sways in the wind material (banners, foliage)
#   mirror      seeded horizontal flip for free left/right variety
#   parts[]     {sprite, off:Vector2, scale (x base w), z, wind}
#   colliders[] {shape:"rect"|"circle", size:Vector2 | radius:float, off:Vector2}
#               omitted -> one rect ~62% of the base width (building default)
#   decals[]    {sprite, off, scale, z, wind, light:Color, light_energy, light_scale}
#   fire        positional campfire/hearth crackle as you pass
#
# Local motion overlays keep a solid prop's authored body stable while the
# physically active part moves. Offsets and widths are normalized against the
# base texture, so the same profile works in scatter, accent, and structure
# paths at any render size.
const PROP_MOTION := {
	"spore_vent": {"sprite": "spore_puff", "width_ratio": 0.72,
		"off_ratio": Vector2(0.0, -0.17), "z": 2},
	"void_rift": {"sprite": "void_energy", "width_ratio": 1.24,
		"off_ratio": Vector2(0.0, 0.0), "z": 2},
	"capital_portal_depths": {"sprite": "void_energy", "width_ratio": 0.90,
		"off_ratio": Vector2(0.08, 0.03), "z": 2},
	"storm_conductor": {"sprite": "storm_arcs", "width_ratio": 1.02,
		"off_ratio": Vector2(0.0, -0.27), "z": 2},
	"magma_furnace": {"sprite": "flame", "width_ratio": 0.25,
		"off_ratio": Vector2(0.0, 0.21), "z": 2},
	"keep_brazier": {"sprite": "flame", "width_ratio": 0.22,
		"off_ratio": Vector2(0.0, -0.19), "z": 2},
	"forge_cauldron": {"sprite": "flame", "width_ratio": 0.52,
		"off_ratio": Vector2(0.0, -0.24), "z": 2},
	"forge_brazier": {"sprite": "flame", "width_ratio": 1.15,
		"off_ratio": Vector2(0.0, -0.24), "z": 2},
	"camp_furnace": {"sprite": "flame", "width_ratio": 0.50,
		"off_ratio": Vector2(0.0, 0.02), "z": 2},
	"station_furnace_t1": {"sprite": "flame", "width_ratio": 0.44,
		"off_ratio": Vector2(0.0, 0.06), "z": 2},
	"station_furnace_t2": {"sprite": "flame", "width_ratio": 0.42,
		"off_ratio": Vector2(0.0, 0.03), "z": 2},
	"station_furnace_t3": {"sprite": "flame", "width_ratio": 0.40,
		"off_ratio": Vector2(0.0, 0.0), "z": 2},
}

const STRUCTURES := {
	# ---- LIVE TERRAIN ECOLOGY LANDMARKS (2026-07-27) ----------------------
	# One authored composition per playable biome. These are deliberately more
	# than oversized props: a focal silhouette, supporting growth/ruin, a
	# multi-part footprint, and light or wind where the ecology calls for it.
	# The seeded room placer gives every live terrain a recognizable "place"
	# while preserving its road and door lanes.
	"village_grove": {"sprite": "tree_green", "w": 190.0, "wind": true, "mirror": true,
		"parts": [
			{"sprite": "garden_statue", "off": Vector2(-88, -25), "scale": 0.34, "z": 1},
			{"sprite": "bush", "off": Vector2(78, -20), "scale": 0.38, "z": 2, "wind": true},
			{"sprite": "grass", "off": Vector2(112, -12), "scale": 0.20, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 18.0, "off": Vector2(0, 4)},
			{"shape": "circle", "radius": 12.0, "off": Vector2(-88, 2)}]},
	"darkwood_hollow": {"sprite": "tree_gnarled", "w": 230.0, "wind": true, "mirror": true,
		"parts": [
			{"sprite": "tree_autumn", "off": Vector2(-112, -56), "scale": 0.55, "z": -1, "wind": true},
			{"sprite": "log", "off": Vector2(92, -11), "scale": 0.40, "z": 1},
			{"sprite": "mushroom_purple", "off": Vector2(68, -17), "scale": 0.24, "z": 2, "wind": true},
			{"sprite": "bush3", "off": Vector2(-73, -18), "scale": 0.30, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 21.0, "off": Vector2(0, 5)},
			{"shape": "circle", "radius": 15.0, "off": Vector2(-112, 5)},
			{"shape": "rect", "size": Vector2(66, 24), "off": Vector2(92, 3)}]},
	"marsh_islet": {"sprite": "tree_teal", "w": 205.0, "wind": true, "mirror": true,
		"parts": [
			{"sprite": "deadtree", "off": Vector2(104, -48), "scale": 0.48, "z": -1, "wind": true},
			{"sprite": "cattail", "off": Vector2(-83, -24), "scale": 0.28, "z": 2, "wind": true},
			{"sprite": "cattail", "off": Vector2(-111, -20), "scale": 0.23, "z": 2, "wind": true},
			{"sprite": "spore_vent", "off": Vector2(69, -17), "scale": 0.25, "z": 2}],
		"colliders": [
			{"shape": "circle", "radius": 20.0, "off": Vector2(0, 5)},
			{"shape": "circle", "radius": 15.0, "off": Vector2(104, 4)}]},
	"keep_courtyard": {"sprite": "castle_statue", "w": 145.0, "mirror": true,
		"parts": [
			{"sprite": "ruin_pillar", "off": Vector2(-94, -54), "scale": 0.53, "z": -1},
			{"sprite": "ruin_pillar", "off": Vector2(94, -54), "scale": 0.53, "z": -1},
			{"sprite": "keep_brazier", "off": Vector2(-58, -18), "scale": 0.28, "z": 2},
			{"sprite": "keep_brazier", "off": Vector2(58, -18), "scale": 0.28, "z": 2}],
		"colliders": [
			{"shape": "rect", "size": Vector2(42, 30), "off": Vector2(0, -2)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(-94, 0)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(94, 0)}],
		"decals": [
			{"sprite": "flame", "off": Vector2(-58, -57), "scale": 0.12, "z": 3,
				"light": Color(1.0, 0.58, 0.25, 0.9), "light_energy": 0.8, "light_scale": 0.65},
			{"sprite": "flame", "off": Vector2(58, -57), "scale": 0.12, "z": 3,
				"light": Color(1.0, 0.58, 0.25, 0.9), "light_energy": 0.8, "light_scale": 0.65}],
		"fire": true},
	"magma_judgment": {"sprite": "forge_statue", "w": 155.0,
		"parts": [
			{"sprite": "magma_furnace", "off": Vector2(-102, -34), "scale": 0.54, "z": -1},
			{"sprite": "rock_volcanic", "off": Vector2(96, -20), "scale": 0.38, "z": 1},
			{"sprite": "magma_chainrig", "off": Vector2(69, -40), "scale": 0.38, "z": 2}],
		"colliders": [
			{"shape": "circle", "radius": 19.0, "off": Vector2(0, 2)},
			{"shape": "rect", "size": Vector2(55, 34), "off": Vector2(-102, 0)},
			{"shape": "circle", "radius": 15.0, "off": Vector2(96, 3)}],
		"decals": [{"sprite": "flame", "off": Vector2(-102, -83), "scale": 0.20, "z": 3,
			"light": Color(1.0, 0.34, 0.12, 0.95), "light_energy": 1.25, "light_scale": 1.0}],
		"fire": true},
	"ice_waymarker": {"sprite": "ice_cairn", "w": 150.0,
		"parts": [
			{"sprite": "tree_snow", "off": Vector2(-106, -64), "scale": 0.66, "z": -1, "wind": true},
			{"sprite": "crystal_spire", "off": Vector2(91, -38), "scale": 0.39, "z": 1},
			{"sprite": "frost_reeds", "off": Vector2(119, -15), "scale": 0.25, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 20.0, "off": Vector2(0, 3)},
			{"shape": "circle", "radius": 17.0, "off": Vector2(-106, 4)},
			{"shape": "circle", "radius": 12.0, "off": Vector2(91, 2)}],
		"decals": [{"sprite": "glow", "off": Vector2(91, -72), "scale": 0.18, "z": 3,
			"light": Color(0.56, 0.83, 1.0, 0.75), "light_energy": 0.55, "light_scale": 0.7}]},
	"grave_memorial": {"sprite": "grave_angel", "w": 150.0, "mirror": true,
		"parts": [
			{"sprite": "grave_deadtree", "off": Vector2(-115, -70), "scale": 0.68, "z": -1, "wind": true},
			{"sprite": "grave_statue", "off": Vector2(100, -35), "scale": 0.44, "z": 1},
			{"sprite": "tombstone3", "off": Vector2(55, -18), "scale": 0.30, "z": 2},
			{"sprite": "grass_frost", "off": Vector2(-59, -13), "scale": 0.22, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 17.0, "off": Vector2(0, 3)},
			{"shape": "circle", "radius": 18.0, "off": Vector2(-115, 4)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(100, 2)}]},
	"desert_hoodoo": {"sprite": "sandstone", "w": 185.0, "mirror": true,
		"parts": [
			{"sprite": "cactus", "off": Vector2(-104, -45), "scale": 0.46, "z": 1},
			{"sprite": "sandstone", "off": Vector2(109, -35), "scale": 0.43, "z": -1},
			{"sprite": "grass_autumn", "off": Vector2(-65, -12), "scale": 0.20, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 24.0, "off": Vector2(0, 2)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(-104, 3)},
			{"shape": "circle", "radius": 18.0, "off": Vector2(109, 3)}]},
	"bog_rootwell": {"sprite": "tree_gnarled", "w": 210.0, "wind": true, "mirror": true,
		"parts": [
			{"sprite": "spore_shrine", "off": Vector2(103, -38), "scale": 0.43, "z": 1},
			{"sprite": "mushroom_purple", "off": Vector2(-72, -16), "scale": 0.24, "z": 2, "wind": true},
			{"sprite": "cattail", "off": Vector2(137, -18), "scale": 0.22, "z": 2, "wind": true},
			{"sprite": "spore_vent", "off": Vector2(67, -17), "scale": 0.23, "z": 2}],
		"colliders": [
			{"shape": "circle", "radius": 22.0, "off": Vector2(0, 4)},
			{"shape": "circle", "radius": 16.0, "off": Vector2(103, 3)}]},
	"crystal_garden": {"sprite": "crystal_spire", "w": 175.0,
		"parts": [
			{"sprite": "crystal_cluster", "off": Vector2(-104, -31), "scale": 0.54, "z": 1},
			{"sprite": "geode", "off": Vector2(101, -27), "scale": 0.43, "z": 1},
			{"sprite": "crystal_cluster", "off": Vector2(64, -18), "scale": 0.31, "z": 2}],
		"colliders": [
			{"shape": "circle", "radius": 20.0, "off": Vector2(0, 2)},
			{"shape": "circle", "radius": 18.0, "off": Vector2(-104, 3)},
			{"shape": "circle", "radius": 15.0, "off": Vector2(101, 3)}],
		"decals": [{"sprite": "glow", "off": Vector2(0, -102), "scale": 0.18, "z": 3,
			"light": Color(0.44, 0.68, 1.0, 0.9), "light_energy": 0.9, "light_scale": 0.9}]},
	"storm_array": {"sprite": "storm_conductor", "w": 170.0,
		"parts": [
			{"sprite": "storm_standing_stone", "off": Vector2(-106, -47), "scale": 0.52, "z": -1},
			{"sprite": "rock3", "off": Vector2(106, -25), "scale": 0.72, "z": -1},
			{"sprite": "frost_reeds", "off": Vector2(-62, -14), "scale": 0.22, "z": 2, "wind": true},
			{"sprite": "grass", "off": Vector2(65, -13), "scale": 0.20, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 18.0, "off": Vector2(0, 3)},
			{"shape": "circle", "radius": 16.0, "off": Vector2(-106, 3)},
			{"shape": "circle", "radius": 16.0, "off": Vector2(106, 3)}],
		"decals": [{"sprite": "glow", "off": Vector2(0, -104), "scale": 0.16, "z": 3,
			"light": Color(0.48, 0.72, 1.0, 0.9), "light_energy": 0.85, "light_scale": 0.8}]},
	"void_breach": {"sprite": "void_rift", "w": 180.0,
		"parts": [
			{"sprite": "void_monolith", "off": Vector2(-104, -58), "scale": 0.54, "z": -1},
			{"sprite": "void_obelisk", "off": Vector2(108, -60), "scale": 0.50, "z": -1},
			{"sprite": "crystal_spire", "off": Vector2(62, -25), "scale": 0.27, "z": 2}],
		"colliders": [
			{"shape": "circle", "radius": 22.0, "off": Vector2(0, 3)},
			{"shape": "circle", "radius": 16.0, "off": Vector2(-104, 2)},
			{"shape": "circle", "radius": 16.0, "off": Vector2(108, 2)}],
		"decals": [{"sprite": "glow", "off": Vector2(0, -72), "scale": 0.18, "z": 3,
			"light": Color(0.62, 0.27, 1.0, 0.9), "light_energy": 1.15, "light_scale": 1.0}]},
	"holy_sanctum": {"sprite": "garden_fountain", "w": 165.0,
		"parts": [
			{"sprite": "grave_angel", "off": Vector2(-105, -46), "scale": 0.47, "z": -1},
			{"sprite": "garden_statue", "off": Vector2(105, -40), "scale": 0.43, "z": -1},
			{"sprite": "ruin_pillar", "off": Vector2(0, -90), "scale": 0.38, "z": -2},
			{"sprite": "flower", "off": Vector2(67, -12), "scale": 0.18, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 46.0, "off": Vector2(-35, -25)},
			{"shape": "circle", "radius": 46.0, "off": Vector2(35, -25)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(-105, 2)},
			{"shape": "circle", "radius": 14.0, "off": Vector2(105, 2)}],
		"decals": [
			{"sprite": "fountain_flow", "off": Vector2(0, -46), "scale": 0.50, "z": 2},
			{"sprite": "glow", "off": Vector2(0, -100), "scale": 0.18, "z": 3,
				"light": Color(1.0, 0.87, 0.46, 0.8), "light_energy": 0.7, "light_scale": 0.8}]},
	"spore_cathedral": {"sprite": "spore_shrine", "w": 190.0,
		"parts": [
			{"sprite": "tree_spore", "off": Vector2(-115, -72), "scale": 0.67, "z": -1, "wind": true},
			{"sprite": "tree_spore", "off": Vector2(115, -72), "scale": 0.67, "z": -1, "wind": true},
			{"sprite": "spore_vent", "off": Vector2(-68, -17), "scale": 0.26, "z": 2},
			{"sprite": "mushroom_purple", "off": Vector2(70, -17), "scale": 0.25, "z": 2, "wind": true}],
		"colliders": [
			{"shape": "circle", "radius": 22.0, "off": Vector2(0, 3)},
			{"shape": "circle", "radius": 18.0, "off": Vector2(-115, 3)},
			{"shape": "circle", "radius": 18.0, "off": Vector2(115, 3)}],
		"decals": [{"sprite": "glow", "off": Vector2(0, -92), "scale": 0.18, "z": 3,
			"light": Color(0.68, 0.32, 0.96, 0.8), "light_energy": 0.7, "light_scale": 0.8}]},
	# A ruined gateway: an arch flanked by two pillars, EACH its own collider
	# (a composite footprint no single circle could describe), a banner slung
	# over the span as a wall decal.
	"ruined_gate": {"sprite": "keep_arch", "w": 200.0, "mirror": true,
		"parts": [
			{"sprite": "pillar", "off": Vector2(-92, -26), "scale": 0.30, "z": 1},
			{"sprite": "pillar", "off": Vector2(92, -26), "scale": 0.30, "z": 1}],
		"colliders": [
			{"shape": "circle", "radius": 15.0, "off": Vector2(-92, -4)},
			{"shape": "circle", "radius": 15.0, "off": Vector2(92, -4)}],
		"decals": [{"sprite": "banner_red", "off": Vector2(0, -74), "scale": 0.22, "z": 2, "wind": true}]},
	# A lit watch-brazier: a pillar topped by a brazier decal that GLOWS
	# (point light) and CRACKLES (positional fire audio).
	"watch_brazier": {"sprite": "pillar", "w": 120.0,
		"colliders": [{"shape": "circle", "radius": 13.0, "off": Vector2(0, -4)}],
		"decals": [{"sprite": "keep_brazier", "off": Vector2(0, -92), "scale": 0.34, "z": 2,
			"light": Color(1.0, 0.62, 0.28, 0.9), "light_energy": 1.1, "light_scale": 0.9}],
		"fire": true},
	# A real masonry well: dedicated high-resolution art replaces the old
	# 14px boulder enlarged to 150px with a bucket pasted on its rim.
	"old_well": {"sprite": "old_well", "w": 150.0, "mirror": true,
		"colliders": [{"shape": "circle", "radius": 49.0, "off": Vector2(0, -4)}]},
	# A signal fire: a stacked-log pyre that BURNS — an open flame decal with
	# light + audio, ringed by a small footprint.
	"signal_fire": {"sprite": "log", "w": 96.0,
		"colliders": [{"shape": "circle", "radius": 14.0, "off": Vector2(0, 2)}],
		"decals": [{"sprite": "camp_bonfire", "off": Vector2(0, -18), "scale": 0.5, "z": 2,
			"light": Color(1.0, 0.55, 0.22, 0.95), "light_energy": 1.3, "light_scale": 1.0}],
		"fire": true},
	# ---- ANIMATED composite structures (2026-07-18, Lane 2 x Lane 3) --------
	# These pair the composite-structure seam with the animated-prop seam: a
	# decal whose sprite ships a <name>_anim.png strip SELF-ANIMATES with no
	# code change. So a forge glows and pulses, a hearth's flame licks, a
	# fountain's water shimmers — all driven by the strips installed alongside.
	# A working forge: the anvil is the base, a pulsing furnace beside it
	# (forge_hearth ANIMATES), an open flame at the coals, and a rising smoke
	# column — plus the forge-glow light and crackle. The Guild Hall's centerpiece.
	"guild_forge": {"sprite": "station_anvil_t3", "w": 150.0, "mirror": true,
		"parts": [{"sprite": "forge_hearth", "off": Vector2(78, -20), "scale": 0.7, "z": 1}],
		"colliders": [
			{"shape": "rect", "size": Vector2(96.0, 34.0), "off": Vector2(0, -6)},
			{"shape": "circle", "radius": 22.0, "off": Vector2(78, -8)}],
		"decals": [
			{"sprite": "flame", "off": Vector2(-6, -30), "scale": 0.28, "z": 2,
				"light": Color(1.0, 0.58, 0.24, 0.95), "light_energy": 1.0, "light_scale": 0.8},
			{"sprite": "ember_smoke", "off": Vector2(78, -78), "scale": 0.4, "z": 3}],
		"fire": true},
	# A cooking hearth: a workbench with a lit grill (cook_grill ANIMATES) and
	# a smoke wisp, warm light, crackle.
	"cook_hearth": {"sprite": "camp_workbench", "w": 128.0,
		"colliders": [{"shape": "rect", "size": Vector2(88.0, 32.0), "off": Vector2(0, -6)}],
		"decals": [
			{"sprite": "cook_grill", "off": Vector2(2, -30), "scale": 0.5, "z": 2,
				"light": Color(1.0, 0.66, 0.34, 0.85), "light_energy": 0.8, "light_scale": 0.7},
			{"sprite": "ember_smoke", "off": Vector2(2, -74), "scale": 0.34, "z": 3}],
		"fire": true},
	# A brew stand: the top-tier alchemy table with a small burner flame
	# (flame ANIMATES) under the retort, a cool green glow.
	"brew_stand": {"sprite": "station_alchemy_t3", "w": 128.0, "mirror": true,
		"colliders": [{"shape": "rect", "size": Vector2(84.0, 30.0), "off": Vector2(0, -6)}],
		"decals": [{"sprite": "flame", "off": Vector2(-2, -26), "scale": 0.16, "z": 2,
			"light": Color(0.5, 0.9, 0.55, 0.8), "light_energy": 0.7, "light_scale": 0.6}]},
	# A town fountain: a stone basin with SHIMMERING water (fountain_flow
	# ANIMATES). No light, no fire — just a calm centerpiece with a broad
	# rim footprint.
	"town_fountain": {"sprite": "garden_fountain", "w": 150.0,
		"colliders": [
			{"shape": "circle", "radius": 42.0, "off": Vector2(-32, -24)},
			{"shape": "circle", "radius": 42.0, "off": Vector2(32, -24)}],
		"decals": [{"sprite": "fountain_flow", "off": Vector2(0, -44), "scale": 0.50, "z": 2}]},
	# The raw garden-fountain landmark uses the same living-water and broad
	# basin contract as the named town variant. Without its own definition it
	# fell through to a generic thin building strip whenever the holy/garden
	# landmark draw selected it.
	"garden_fountain": {"sprite": "garden_fountain", "w": 165.0,
		"colliders": [
			{"shape": "circle", "radius": 46.0, "off": Vector2(-35, -25)},
			{"shape": "circle", "radius": 46.0, "off": Vector2(35, -25)}],
		"decals": [{"sprite": "fountain_flow", "off": Vector2(0, -46), "scale": 0.50, "z": 2}]},
	# Kinetic landmarks own explicit full-base footprints. Their stable shell
	# is the structure base; PROP_MOTION supplies only the living element.
	"magma_furnace": {"sprite": "magma_furnace", "w": 120.0,
		"colliders": [{"shape": "rect", "size": Vector2(100, 44), "off": Vector2(0, -10)}],
		"decals": [{"sprite": "ember_smoke", "off": Vector2(0, -74), "scale": 0.32, "z": 2}],
		"fire": true},
	"storm_conductor": {"sprite": "storm_conductor", "w": 108.0,
		"colliders": [{"shape": "circle", "radius": 34.0, "off": Vector2(0, -5)}]},
	"void_rift": {"sprite": "void_rift", "w": 94.0,
		"colliders": [{"shape": "circle", "radius": 29.0, "off": Vector2(0, -3)}]},
	"spore_shrine": {"sprite": "spore_shrine", "w": 122.0,
		"colliders": [{"shape": "circle", "radius": 38.0, "off": Vector2(0, -3)}]},
	# A sewer outfall: a broad pipe spilling a pool of FLOWING sludge
	# (sewer_flow ANIMATES) across a wide flat footprint.
	"sewer_outfall": {"sprite": "sewer_pipe", "w": 140.0, "mirror": true,
		"colliders": [{"shape": "rect", "size": Vector2(96.0, 34.0), "off": Vector2(0, -6)}],
		"decals": [{"sprite": "sewer_flow", "off": Vector2(30, -8), "scale": 0.34, "z": 1}]},
	# A great hearth: a hall fireplace — a brazier base with a tall licking
	# flame (flame ANIMATES), a smoke column, firelight and crackle.
	"great_hearth": {"sprite": "capital_great_hearth", "w": 244.1602,
		"visual_x": -0.2637,
		"colliders": [{"shape": "rect", "size": Vector2(180, 42), "off": Vector2(0, -8)}],
		"fire": true},
	"capital_city_bench": {"sprite": "capital_city_bench", "w": 139.4531,
		"colliders": [{"shape": "rect", "size": Vector2(112, 34), "off": Vector2(0, -7)}]},
	"capital_city_directory": {"sprite": "capital_city_directory", "w": 176.6406,
		"colliders": [{"shape": "rect", "size": Vector2(138, 36), "off": Vector2(0, -7)}]},
	"capital_alembic_station": {"sprite": "capital_alembic_station", "w": 214.8047,
		"colliders": [{"shape": "rect", "size": Vector2(174, 40), "off": Vector2(0, -8)}]},
	# A market stall: a counter under an awning of two hung banners that SWAY
	# (wind material). No light; a simple wide footprint.
	"market_stall": {"sprite": "hideout_table", "w": 140.0, "mirror": true,
		"colliders": [{"shape": "rect", "size": Vector2(100.0, 30.0), "off": Vector2(0, -4)}],
		"decals": [
			{"sprite": "banner_blue", "off": Vector2(-38, -70), "scale": 0.2, "z": 2, "wind": true},
			{"sprite": "banner_green", "off": Vector2(38, -70), "scale": 0.2, "z": 2, "wind": true}]},
	# A notice board: a signpost hung with two posters — the town's job board.
	"notice_board": {"sprite": "signpost", "w": 84.0,
		"colliders": [{"shape": "circle", "radius": 12.0, "off": Vector2(0, -2)}],
		"decals": [
			{"sprite": "hideout_poster", "off": Vector2(-16, -40), "scale": 0.22, "z": 2},
			{"sprite": "hideout_poster", "off": Vector2(18, -46), "scale": 0.2, "z": 2}]},
	# A mausoleum: a crypt flanked by a mourner and an angel, a COMPOSITE
	# footprint (three shapes no single circle could describe). Static.
	"mausoleum": {"sprite": "crypt", "w": 168.0, "mirror": true,
		"parts": [
			{"sprite": "grave_statue", "off": Vector2(-84, -8), "scale": 0.26, "z": 1},
			{"sprite": "grave_angel", "off": Vector2(84, -8), "scale": 0.26, "z": 1}],
		"colliders": [
			{"shape": "rect", "size": Vector2(120.0, 40.0), "off": Vector2(0, -8)},
			{"shape": "circle", "radius": 12.0, "off": Vector2(-84, -2)},
			{"shape": "circle", "radius": 12.0, "off": Vector2(84, -2)}]},
	# A torch pillar: a stone column crowned with a live FLAME (flame ANIMATES)
	# — the animated cousin of watch_brazier, for lit halls and dungeons.
	"torch_pillar": {"sprite": "pillar", "w": 96.0,
		"colliders": [{"shape": "circle", "radius": 12.0, "off": Vector2(0, -4)}],
		"decals": [{"sprite": "flame", "off": Vector2(0, -80), "scale": 0.24, "z": 2,
			"light": Color(1.0, 0.64, 0.3, 0.9), "light_energy": 1.0, "light_scale": 0.8}],
		"fire": true},
	# ---- CROWNFALL authored landmark kit (2026-07-20) ----------------------
	# Large generated environment sprites, width-normalized here so their source
	# resolution never dictates world scale. Civic facades use a shallow base
	# footprint; open gates reserve only their side piers so the arch remains a
	# readable passage instead of an invisible wall.
	"capital_crown_spire_gate": {"sprite": "capital_crown_spire_gate", "w": 878.9062,
		"colliders": [
			{"shape": "rect", "size": Vector2(250, 50), "off": Vector2(-310, -24)},
			{"shape": "rect", "size": Vector2(250, 50), "off": Vector2(310, -24)}],
		"fire": true},
	# A single connected city-edge silhouette, spawned only through
	# _add_backdrop. Its base carries ONE thin full-width strip (owner report
	# 2026-07-25: the hero could stroll INTO the silhouette — the room walls
	# don't actually own this edge), so the city stays scenery you stand in
	# front of, never inside.
	"capital_city_arcade": {"sprite": "capital_city_arcade", "w": 1653.75,
		"colliders": [{"shape": "rect", "size": Vector2(1680, 26), "off": Vector2(0, -8)}]},
	# Collider-vs-art rule (owner 2026-07-25, the fangmoot "invisible wall"):
	# a capital collider's SOUTH edge must sit at the art's lowest opaque row
	# (base-anchor render: local +12 minus the rendered bottom padding) —
	# never hanging into the visually empty grass below. Enforced by the
	# autotest capital contract.
	"capital_crown_fountain": {"sprite": "capital_crown_fountain", "w": 271.6406,
		"colliders": [{"shape": "rect", "size": Vector2(300, 130), "off": Vector2(0, -65)}]},
	"capital_emberward_gate": {"sprite": "capital_emberward_gate", "w": 404.4141,
		"visual_x": 1.2305,
		"colliders": [
			{"shape": "rect", "size": Vector2(88, 46), "off": Vector2(-142, -34)},
			{"shape": "rect", "size": Vector2(88, 46), "off": Vector2(142, -34)}],
		"fire": true},
	"capital_market_stall": {"sprite": "capital_market_stall", "w": 243.3594,
		"visual_x": 0.2734,
		"colliders": [{"shape": "rect", "size": Vector2(178, 42), "off": Vector2(0, -18)}]},
	# Portal piers are PILLAR FOOTPRINTS, not dots (owner 2026-07-25: the r22
	# circles were narrower than the pillar art, so a hero slipped sideways
	# and stood inside the column). Rects span each pillar's base; the
	# center passage stays open so the arch still reads as a way through.
	"capital_portal_story": {"sprite": "capital_portal_story", "w": 226.4844,
		"colliders": [
			{"shape": "rect", "size": Vector2(54, 42), "off": Vector2(-78, -12)},
			{"shape": "rect", "size": Vector2(54, 42), "off": Vector2(78, -12)}]},
	"capital_portal_crucible": {"sprite": "capital_portal_crucible", "w": 254.8438,
		"visual_x": 0.5469,
		"colliders": [
			{"shape": "rect", "size": Vector2(58, 44), "off": Vector2(-88, -13)},
			{"shape": "rect", "size": Vector2(58, 44), "off": Vector2(88, -13)}],
		"fire": true},
	"capital_portal_depths": {"sprite": "capital_portal_depths", "w": 154.082,
		"visual_x": 1.123,
		"colliders": [{"shape": "rect", "size": Vector2(132, 42), "off": Vector2(0, -8)}]},
	# CLOSED capital buildings carry BODY colliders, not just the default
	# 34px base strip (owner report 2026-07-25: the strip let the hero wander
	# INSIDE the tavern art from the sides). Rects cover the visual body;
	# every authored NPC/hotspot stand-point stays south of them.
	"capital_chartered_hall": {"sprite": "capital_chartered_hall", "w": 309.375,
		"colliders": [{"shape": "rect", "size": Vector2(275, 170), "off": Vector2(0, -90)}]},
	"capital_ashfire_forge": {"sprite": "capital_ashfire_forge", "w": 335.3906,
		"visual_x": 1.0547,
		"colliders": [{"shape": "rect", "size": Vector2(300, 170), "off": Vector2(0, -76)}],
		"fire": true},
	"capital_grand_archive": {"sprite": "capital_grand_archive", "w": 306.7969,
		"visual_x": 1.3281,
		"colliders": [{"shape": "rect", "size": Vector2(285, 175), "off": Vector2(0, -93)}]},
	"capital_ashen_tankard": {"sprite": "capital_ashen_tankard", "w": 344.5312,
		"visual_x": 2.8125,
		"colliders": [{"shape": "rect", "size": Vector2(300, 190), "off": Vector2(0, -100)}],
		"fire": true},
	"capital_wildfang_fangmoot": {"sprite": "capital_wildfang_fangmoot", "w": 306.7969,
		"visual_x": 0.6445,
		"colliders": [{"shape": "rect", "size": Vector2(280, 150), "off": Vector2(0, -66)}],
		"fire": true},
	"capital_rot_chapel": {"sprite": "capital_rot_chapel", "w": 340.4297,
		"colliders": [{"shape": "rect", "size": Vector2(290, 185), "off": Vector2(0, -98)}]},
	"capital_accord_longhouse": {"sprite": "capital_accord_longhouse", "w": 413.4375,
		"visual_x": 1.6406,
		"colliders": [{"shape": "rect", "size": Vector2(350, 170), "off": Vector2(0, -76)}],
		"fire": true},
	"capital_sable_hall": {"sprite": "capital_sable_hall", "w": 401.1328,
		"visual_x": 0.4102,
		"colliders": [{"shape": "rect", "size": Vector2(350, 200), "off": Vector2(0, -105)}],
		"fire": true},
	"capital_wellspring": {"sprite": "capital_wellspring", "w": 284.8828,
		"visual_x": 1.9336,
		"colliders": [{"shape": "circle", "radius": 70.0, "off": Vector2(0, -10)}]},
	"capital_stables": {"sprite": "capital_stables", "w": 385.9766,
		"visual_x": 0.8008},
	"capital_watchtower": {"sprite": "capital_watchtower", "w": 187.9883,
		"visual_x": 2.6855,
		"fire": true},
	"capital_undercroft": {"sprite": "capital_undercroft", "w": 346.6406,
		"visual_x": 5.9766,
		"colliders": [
			{"shape": "rect", "size": Vector2(68, 40), "off": Vector2(-118, -8)},
			{"shape": "rect", "size": Vector2(68, 40), "off": Vector2(118, -8)}]},
	"capital_proving_gate": {"sprite": "capital_proving_gate", "w": 387.5,
		"visual_x": 1.5625,
		"colliders": [
			{"shape": "rect", "size": Vector2(82, 44), "off": Vector2(-132, -8)},
			{"shape": "rect", "size": Vector2(82, 44), "off": Vector2(132, -8)}],
		"fire": true},
}


static func is_unique_prop(name: String) -> bool:
	return UNIQUE_PROP_NAMES.has(prop_base(name))


## Returns only the signature sprites claimed by a composite. Natural support
## pieces (grass, trees, ordinary rocks) remain available to scatter nearby.
static func structure_unique_props(name: String) -> Array:
	var out: Array = []
	var def: Dictionary = STRUCTURES.get(name, {})
	# Unlisted landmark candidates degrade to a single-sprite structure.
	var root := String(def.get("sprite", name))
	if is_unique_prop(root):
		out.append(prop_base(root))
	for raw_part in def.get("parts", []):
		var part: Dictionary = raw_part
		var sprite := String(part.get("sprite", ""))
		var base := prop_base(sprite)
		if is_unique_prop(base) and base not in out:
			out.append(base)
	return out
