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

const DATA := {
	# ------------------------------------------------ story terrains ---
	"village": {"name": "Emberfall Village", "ground": "grass", "path": "dirt",
		"tint": Color(1.0, 0.98, 0.9), "ambient": "leaves_green", "music": "village",
		"obstacles": ["tree_green", "tree_green", "rock"], "decor": ["flower", "flower", "pebble"], "count": 9,
		# Two roof colorways per cottage (a2/b2 = PNG override variants) +
		# seeded mirroring in _add_building keep the village from repeating.
		"buildings": ["cottage_a", "cottage_b", "stall", "cottage_a2", "cottage_b2"],
		"patches": [], "event": ""},
	"darkwood": {"name": "The Darkwood", "ground": "forest", "path": "dirt",
		"tint": Color(0.82, 0.9, 0.86), "ambient": "leaves_autumn", "music": "darkwood",
		"obstacles": ["tree_autumn", "tree_autumn", "rock"], "decor": ["mushroom", "pebble", "flower"], "count": 16,
		"patches": [], "event": ""},
	"marsh": {"name": "The Blightmarsh", "ground": "marsh", "path": "dirt",
		"tint": Color(0.85, 0.9, 0.78), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "deadtree", "rock"], "decor": ["mushroom", "bones", "pebble"], "count": 14,
		"patches": [], "event": "",
		"river": {"chance": 0.45, "color": Color(0.10, 0.20, 0.19, 0.82)}},
	"keep": {"name": "Vargoth's Keep", "ground": "stone", "path": "stone",
		"tint": Color(0.8, 0.78, 0.88), "ambient": "embers", "music": "keep",
		"obstacles": ["pillar"], "decor": ["bones", "crack", "bones"], "count": 10,
		"patches": [], "event": ""},
	# ------------------------------------------------- new terrains ---
	"magma": {"name": "Scorched Wastes", "ground": "basalt", "path": "basalt",
		"tint": Color(1.0, 0.8, 0.7), "ambient": "embers", "music": "magma",
		"obstacles": ["rock", "rock", "pillar"], "decor": ["crack", "crack", "pebble"], "count": 12,
		"patches": [{"type": "lava", "count": 4, "radius": [55, 85]}],
		"event": "magma_rain", "event_t": [3.5, 6.5]},
	"ice": {"name": "Frozen Expanse", "ground": "snow", "path": "snow",
		"tint": Color(0.88, 0.93, 1.05), "ambient": "snow", "music": "icefield",
		"obstacles": ["tree_snow", "tree_snow", "rock"], "decor": ["pebble"], "count": 12,
		"patches": [{"type": "ice", "count": 10, "radius": [60, 110]}],
		"event": ""},
	"graveyard": {"name": "Restless Graveyard", "ground": "gravedirt", "path": "gravedirt",
		"tint": Color(0.78, 0.82, 0.85), "ambient": "mist", "music": "graveyard",
		"obstacles": ["tombstone", "tombstone", "tombstone", "grave_cross", "grave_cross", "grave_deadtree", "coffin", "crypt"], "decor": ["grave_bones", "grave_bones", "grave_crack"], "count": 16,
		"patches": [], "event": "grave_spawn", "event_t": [5.0, 9.0]},
	"desert": {"name": "Scorching Dunes", "ground": "sand", "path": "sand",
		"tint": Color(1.05, 0.98, 0.85), "ambient": "sand", "music": "desert",
		"obstacles": ["rock", "deadtree"], "decor": ["bones", "pebble"], "count": 9,
		"patches": [], "event": "gust", "event_t": [7.0, 11.0]},
	"bog": {"name": "Poison Bog", "ground": "bogsoil", "path": "bogsoil",
		"tint": Color(0.82, 0.9, 0.75), "ambient": "fireflies", "music": "marsh",
		"obstacles": ["tree_teal", "deadtree"], "decor": ["mushroom", "mushroom", "bones"], "count": 13,
		"patches": [{"type": "poison", "count": 8, "radius": [55, 95]}],
		"event": "",
		# The Greyrun runs BLACK through the blightlands (ch2 mill canon).
		"river": {"chance": 0.5, "color": Color(0.07, 0.08, 0.08, 0.88)}},
	"crystal": {"name": "Crystal Caverns", "ground": "crystalfloor", "path": "crystalfloor",
		"tint": Color(0.85, 0.88, 1.05), "ambient": "twinkle", "music": "crystalline",
		"obstacles": ["crystal", "crystal", "pillar"], "decor": ["pebble", "crack"], "count": 14,
		"patches": [], "event": "shard", "event_t": [4.0, 7.0], "mp_boost": true},
	"storm": {"name": "Thunder Plains", "ground": "stormgrass", "path": "dirt",
		"tint": Color(0.72, 0.78, 0.85), "ambient": "rain", "music": "rainstorm",
		"obstacles": ["tree_green", "rock"], "decor": ["flower", "pebble"], "count": 8,
		"patches": [], "event": "lightning", "event_t": [4.0, 7.5]},
	"void": {"name": "The Void", "ground": "voidstone", "path": "voidstone",
		"tint": Color(0.55, 0.5, 0.7), "ambient": "motes", "music": "void",
		"obstacles": ["pillar", "crystal"], "decor": ["crack", "crack"], "count": 10,
		"patches": [{"type": "slow", "count": 7, "radius": [60, 100]}],
		"event": ""},
	"holy": {"name": "Sanctified Ruins", "ground": "holystone", "path": "holystone",
		"tint": Color(1.05, 1.0, 0.88), "ambient": "sparkle", "music": "holy",
		"obstacles": ["pillar", "pillar", "rock"], "decor": ["flower", "crack"], "count": 11,
		"patches": [{"type": "heal", "count": 4, "radius": [55, 75]}],
		"event": ""},
	"spore": {"name": "Spore Glade", "ground": "sporesoil", "path": "sporesoil",
		"tint": Color(0.95, 0.85, 1.0), "ambient": "spores", "music": "spore",
		"obstacles": ["tree_spore", "tree_spore", "rock"], "decor": ["mushroom", "mushroom", "mushroom"], "count": 13,
		"patches": [{"type": "poison", "count": 5, "radius": [60, 90], "drift": true}],
		"event": ""},
	# ---- placeholder terrains (2026-07-08 environment-pack sweep) ----
	# Authored from the owned Pixel Crawler environment packs, dev-only:
	# the codex hides them outside the dev launcher and tags them
	# [placeholder]; the dev panel can still paint any room with them to
	# preview the vibe. No zone references them, so normal play never uses
	# them. All reuse existing ground types / props / hazards.
	"ph_sewer": {"name": "Undercroft Sewer", "ground": "stone", "path": "stone",
		"tint": Color(0.72, 0.82, 0.78), "ambient": "mist", "music": "marsh",
		"obstacles": ["pillar", "rock", "deadtree"], "decor": ["bones", "crack", "pebble"], "count": 12,
		"patches": [{"type": "poison", "count": 5, "radius": [60, 95]}], "event": "",
		"placeholder": true},
	"ph_hall": {"name": "Castle Hall", "ground": "holystone", "path": "holystone",
		"tint": Color(0.9, 0.86, 0.95), "ambient": "embers", "music": "keep",
		"obstacles": ["pillar", "pillar", "rock"], "decor": ["crack", "pebble"], "count": 10,
		"patches": [], "event": "",
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
