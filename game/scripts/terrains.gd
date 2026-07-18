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
const DATA := {
	# ------------------------------------------------ story terrains ---
	"village": {"name": "Emberfall Village", "ground": "grass", "path": "dirt",
		"tint": Color(1.0, 0.98, 0.9), "ambient": "leaves_green", "music": "village",
		"obstacles": ["tree_green", "tree_green", "rock", "rock2", "boulder", "tree_green2", "tree_green3", "tree_green4"], "decor": ["flower", "flower", "pebble", "grass", "bush", "bush3", "toadstool", "toadstool2", "signpost"], "accents": ["log"], "count": 9,
		# Buildings are AUTHORED PER ZONE (_spawn_scenery), not terrain
		# scatter: this terrain paints the grass + props, and each village
		# ZONE opts into its own cottages/stall/camp kit. (Cottage roof
		# colorways a2/b2 = PNG override variants; _add_building mirrors.)
		"patches": [], "event": ""},
	"darkwood": {"name": "The Darkwood", "ground": "forest", "path": "dirt",
		"tint": Color(0.87, 0.94, 0.88), "ambient": "leaves_autumn", "music": "darkwood",
		"obstacles": ["tree_autumn", "tree_autumn", "rock", "rock2", "boulder", "tree_autumn2", "tree_autumn3"], "decor": ["mushroom", "pebble", "flower", "grass_autumn", "bush_autumn", "toadstool", "toadstool2", "tree_stump"], "accents": ["log", "tree_gnarled", "tree_tall_red"], "count": 16,
		"patches": [], "event": ""},
	"marsh": {"name": "The Blightmarsh", "ground": "marsh", "path": "dirt",
		"tint": Color(0.9, 0.95, 0.8), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "deadtree", "rock", "tree_teal2", "tree_pine"], "decor": ["mushroom", "pebble", "grass", "bush", "cattail", "cattail2"], "accents": ["dead_shrub", "log", "mushroom_purple", "bones"], "count": 14,
		"patches": [], "event": "",
		"river": {"chance": 0.45, "color": Color(0.10, 0.20, 0.19, 0.82)}},
	"keep": {"name": "Vargoth's Keep", "ground": "stone", "path": "stone",
		"tint": Color(0.8, 0.78, 0.88), "ambient": "embers", "music": "keep",
		"obstacles": ["pillar", "pillar", "rock", "rock2", "boulder", "rock3", "boulder2"], "decor": ["crack", "pebble", "rubble"], "accents": ["bones"], "count": 10,
		"patches": [], "event": ""},
	# ------------------------------------------------- new terrains ---
	"magma": {"name": "Scorched Wastes", "ground": "basalt", "path": "basalt",
		"tint": Color(1.0, 0.8, 0.7), "ambient": "embers", "music": "magma",
		"obstacles": ["rock", "rock", "pillar", "rock_volcanic", "boulder", "rock3", "forge_cauldron"], "decor": ["crack", "crack", "pebble", "rubble", "forge_brazier"], "accents": ["bones", "forge_statue"], "count": 12,
		"patches": [{"type": "lava", "count": 4, "radius": [55, 85]}],
		"event": "magma_rain", "event_t": [3.5, 6.5]},
	"ice": {"name": "Frozen Expanse", "ground": "snow", "path": "snow",
		"tint": Color(0.88, 0.93, 1.05), "ambient": "snow", "music": "icefield",
		"obstacles": ["tree_snow", "tree_snow", "rock", "rock_ice", "boulder", "tree_snow2", "tree_winter"], "decor": ["pebble", "grass_frost", "stump_snow"], "accents": ["log"], "count": 12,
		"patches": [{"type": "ice", "count": 10, "radius": [60, 110]}],
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
		"patches": [], "event": "grave_spawn", "event_t": [5.0, 9.0]},
	"desert": {"name": "Scorching Dunes", "ground": "sand", "path": "sand",
		"tint": Color(1.05, 0.98, 0.85), "ambient": "sand", "music": "desert",
		"obstacles": ["rock", "deadtree", "sandstone", "sandstone2", "boulder", "cactus", "cactus2"], "decor": ["pebble", "sand_drift", "sand_drift2"], "accents": ["dead_shrub", "bones", "bone"], "count": 9,
		"patches": [], "event": "gust", "event_t": [7.0, 11.0], "bright": true},
	"bog": {"name": "Poison Bog", "ground": "bogsoil", "path": "bogsoil",
		"tint": Color(0.82, 0.9, 0.75), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "deadtree", "rock", "tree_teal2", "tree_pine"], "decor": ["mushroom", "mushroom", "toadstool", "bush", "cattail"], "accents": ["dead_shrub", "mushroom_purple", "log", "bones", "tree_gnarled"], "count": 13,
		"patches": [{"type": "poison", "count": 8, "radius": [55, 95]}],
		"event": "",
		# The Greyrun runs BLACK through the blightlands (ch2 mill canon).
		"river": {"chance": 0.5, "color": Color(0.07, 0.08, 0.08, 0.88)}},
	"crystal": {"name": "Crystal Caverns", "ground": "crystalfloor", "path": "crystalfloor",
		"tint": Color(0.85, 0.88, 1.05), "ambient": "twinkle", "music": "crystalline",
		"obstacles": ["crystal", "crystal", "pillar", "rock2", "boulder", "boulder2", "stalagmite"], "decor": ["pebble", "crack", "rubble"], "accents": ["crystal_cluster", "crystal_spire", "geode"], "count": 14,
		"patches": [], "event": "shard", "event_t": [4.0, 7.0], "mp_boost": true},
	"storm": {"name": "Thunder Plains", "ground": "stormgrass", "path": "dirt",
		# Rain-grey does the mood; the grey-blue GROUND carries the biome.
		"tint": Color(0.8, 0.86, 0.95), "ambient": "rain", "music": "rainstorm",
		"obstacles": ["tree_green", "rock", "rock2", "boulder", "tree_green2", "tree_green3", "deadtree2"], "decor": ["flower", "pebble", "grass", "bush", "bush3"], "accents": ["log"], "count": 8,
		"patches": [], "event": "lightning", "event_t": [4.0, 7.5]},
	"void": {"name": "The Void", "ground": "voidstone", "path": "voidstone",
		# Purple hue-skew keeps the menace; the near-black GROUND is the
		# darkness. The old 0.55/0.5/0.7 modulate ate the pillars too.
		"tint": Color(0.72, 0.64, 0.92), "ambient": "motes", "music": "void",
		"obstacles": ["pillar", "crystal", "rock_pale", "boulder"], "decor": ["crack", "crack", "rubble"], "accents": ["void_monolith", "void_rift", "void_obelisk"], "count": 10,
		"patches": [{"type": "slow", "count": 7, "radius": [60, 100]}],
		"event": ""},
	"holy": {"name": "Sanctified Ruins", "ground": "holystone", "path": "holystone",
		"tint": Color(1.05, 1.0, 0.88), "ambient": "sparkle", "music": "holy",
		"obstacles": ["pillar", "pillar", "rock", "rock2", "boulder"], "decor": ["flower", "flower_pink", "crack", "pebble", "rubble"], "accents": ["grave_statue", "grave_angel"], "count": 11,
		"patches": [{"type": "heal", "count": 4, "radius": [55, 75]}],
		"event": "", "bright": true},
	"spore": {"name": "Spore Glade", "ground": "sporesoil", "path": "sporesoil",
		"tint": Color(0.95, 0.85, 1.0), "ambient": "spores", "music": "spore",
		"obstacles": ["tree_spore", "tree_spore", "rock", "boulder", "tree_spore2"], "decor": ["mushroom", "mushroom", "toadstool", "toadstool2", "grass", "mushroom_blue"], "accents": ["mushroom_purple"], "count": 13,
		"patches": [{"type": "poison", "count": 5, "radius": [60, 90], "drift": true}],
		"event": ""},
	# ---- placeholder terrains (2026-07-08 environment-pack sweep) ----
	# Authored from the owned Pixel Crawler environment packs, dev-only:
	# the codex hides them outside the dev launcher and tags them
	# [placeholder]; the dev panel can still paint any room with them to
	# preview the vibe. No zone references them, so normal play never uses
	# them. All reuse existing ground types / props / hazards.
	"ph_garden": {"name": "Palace Gardens", "ground": "grass", "path": "stone",
		"tint": Color(1.0, 0.98, 0.92), "ambient": "sparkle", "music": "holy",
		"obstacles": ["topiary", "topiary", "garden_statue", "garden_bench", "garden_urns", "rock2"], "decor": ["flowerbed_pink", "flowerbed_red", "flowerbed_purple", "flowers_mixed", "flower", "grass", "window_box"], "accents": ["garden_fountain", "clay_pot"], "count": 10,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	# ---- MMO-seed placeholder terrains (2026-07-18): guild/profession
	# previews for the multiplayer future (guild halls, crafting professions,
	# gathering). Station TIER LADDERS (t1->t3) + gathering nodes + crop
	# growth stages, all cut from the Free Pack station/Farm/Rocks sheets.
	"ph_guildhall": {"name": "Guild Hall", "ground": "holystone", "path": "holystone",
		"tint": Color(0.95, 0.9, 0.85), "ambient": "embers", "music": "village",
		"obstacles": ["station_anvil_t1", "station_anvil_t2", "station_anvil_t3", "station_furnace_t1", "station_furnace_t2", "station_furnace_t3", "station_alchemy_t1", "station_alchemy_t2", "station_alchemy_t3", "station_sawmill_t1", "station_sawmill_t2", "station_sawmill_t3", "library_shelf", "hideout_table", "amphora", "bench2"], "decor": ["library_rug", "candle", "castle_sconce", "pebble", "banner_red", "banner_blue", "banner_green"], "accents": ["castle_throne", "castle_banner", "camp_bonfire"], "count": 12,
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
		"obstacles": ["castle_bust", "castle_bust2", "castle_statue", "pillar"], "decor": ["castle_sconce", "crack", "pebble", "carpet", "candelabra"], "accents": ["castle_throne", "castle_banner"], "count": 10,
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
		"obstacles": ["pillar", "pillar", "rock"], "decor": ["crack", "pebble"], "count": 10,
		"patches": [], "event": "", "bright": true,
		"placeholder": true},
	"ph_fae": {"name": "Fae Grove", "ground": "forest", "path": "dirt",
		"tint": Color(0.85, 0.95, 0.92), "ambient": "fireflies", "music": "darkwood",
		"obstacles": ["tree_green", "tree_green", "rock"], "decor": ["flower", "flower", "mushroom"], "count": 15,
		"patches": [{"type": "heal", "count": 3, "radius": [55, 80]}], "event": "",
		"placeholder": true},
}

# Ambient AUDIO bed per terrain (Sfx.make_ambient kinds; "" = silence).
# The visual weather lives in AMBIENTS below; this is its soundtrack.
const AMBIENT_LOOPS := {
	"village": "amb_birds", "darkwood": "amb_birds", "holy": "amb_birds",
	"storm": "amb_rain", "desert": "amb_wind",
	"ice": "amb_cold",
	"marsh": "amb_crickets", "bog": "amb_crickets", "spore": "amb_crickets",
	"keep": "amb_drone", "void": "amb_drone", "graveyard": "amb_drone",
	"magma": "amb_drone", "crystal": "amb_drone",
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
	"magma": "wall_volcanic", "void": "wall_volcanic",
	"ice": "wall_ice",
	"graveyard": "wall_grave",
	"desert": "wall_sand",
	# keep / crystal / storm / holy / ph_hall -> wallblock (stone) default
}

static func wall_for(id: String) -> String:
	return WALL.get(id, "wallblock")
