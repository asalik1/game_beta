## (T4) Chapter 2 bosses content module — registered via one preload
## line in Story.CONTENT_MODULES. The ENEMIES table merges into
## Story.ALL_ENEMIES at boot; move logic lives in boss.gd (Chapter 2
## block at the end), which preloads this script for the helpers.
##
## Remaining registration wishes (for T0, when convenient):
##   menus.gd BOSS_KINDS + dev-panel spawn list → data-driven, so
##   content bosses show in the codex BOSSES section and the F1 list.

# Same schema as Story.ENEMIES, plus "music" (track key) and "lore"
# (codex blurb). Levels ride the Ch2 acts: ~14 / 22 / 32.
const ENEMIES := {
	# Fangmaw's successor: a Stormwarden beastmaster the blight turned on
	# his own packs. Skirmishes at whip range, calls wolves, and when the
	# storm breaks the sky starts swinging with him.
	"stormwarden": {
		"name": "Korrag, Stormwarden Broken", "sprite": "stormwarden",
		"hp": 1500.0, "dmg": 26.0, "speed": 150.0, "xp": 300, "gold": 220,
		"ranged": false, "scale": 5.0,
		"physres": 25.0, "magres": 20.0, "eva": 0.06, "critres": 3.0, "dmg_type": "phys",
		"level": 14, "hp_g": 0.14, "dmg_g": 0.11,
		"music": "boss_stormwarden",
		"lore": "He once kept the warbands' beasts calm through thunder. Now the thunder keeps HIM.",
	},
	# Morwen's echo: the Hollow Choir's matron. Fights like a hymn —
	# rippling rings of blight, verses of bolts, and she FEEDS on what
	# the choir marks.
	"choirmother": {
		"name": "The Choir Mother", "sprite": "choirmother",
		"hp": 2600.0, "dmg": 30.0, "speed": 105.0, "xp": 480, "gold": 380,
		"ranged": true, "scale": 5.6,
		"physres": 15.0, "magres": 45.0, "eva": 0.10, "critres": 4.0, "dmg_type": "magic",
		"level": 22, "hp_g": 0.14, "dmg_g": 0.11,
		"music": "boss_choirmother",
		"lore": "Where Morwen cursed, the Mother sings. Her congregation never buries its dead.",
	},
	# The ruins' warden: a construct that predates Accord and Cinderborn
	# alike and recognizes neither. Slow, precise, and it sheds its own
	# armor when the fight demands speed.
	"nullwarden": {
		"name": "Warden Null, the Last Sentinel", "sprite": "nullwarden",
		"hp": 5200.0, "dmg": 40.0, "speed": 85.0, "xp": 750, "gold": 600,
		"ranged": false, "scale": 6.2,
		"physres": 55.0, "magres": 35.0, "eva": 0.0, "critres": 8.0, "dmg_type": "phys",
		"level": 32, "hp_g": 0.15, "dmg_g": 0.12,
		"music": "boss_nullwarden",
		"lore": "It asked the first shard-bearers for a passphrase no living tongue remembers.",
	},
}


## Kill-flow for content bosses. game.on_boss_died drives CHAPTER
## progression (quests, gates, epilogue) — a content boss killed outside
## its chapter (dev panel, tests) must grant rewards WITHOUT touching
## the story, so Boss.die() routes these kinds here instead.
static func on_died(game: Node2D, boss: Node2D) -> void:
	var kind: String = boss.kind
	game.boss_done[kind] = true
	if game.current_boss == boss:
		game.current_boss = null
	game.hud.hide_boss_bar()
	game.set_music(Terrains.get_terrain(
		game.terrain_by_zone[clampi(game.last_zone, 0, game.zone_count - 1)]).get("music", "village"))
	game.player.hp = game.player.max_hp
	game.player.mp = game.player.max_mp
	Chest.drop(game, "gold", game.clamp_to_zone(
		boss.global_position + Vector2(0, 60), boss.global_position))
	Pickup.drop_gold(game, int(ENEMIES[kind]["gold"]), boss.global_position)


## Dev/story spawn helper: boss + bar + theme in one call.
static func spawn(game: Node2D, kind: String, pos: Vector2) -> Boss:
	var b := Boss.make_boss(game, kind, pos)
	game.current_boss = b
	game.add_child(b)
	game.hud.show_boss_bar(ENEMIES[kind]["name"])
	game.set_music(ENEMIES[kind]["music"])
	return b


## Kill-flow test (the autotest hook calls this in one line). Spawns
## each boss, proves its signature fires, its enrage trips, and its
## death registers. Returns "" on success, otherwise the failure text.
## Waits on WALL-CLOCK timers (headless frames race ahead of physics).
static func selftest(game: Node2D) -> String:
	for kind in ENEMIES:
		if not game.sounds.has("roar_" + kind):
			return "ch2 boss %s: missing voice roar_%s" % [kind, kind]
		if not game.music_tracks.has(ENEMIES[kind]["music"]):
			return "ch2 boss %s: missing music %s" % [kind, ENEMIES[kind]["music"]]
		if not Story.ALL_ENEMIES.has(kind):
			return "ch2 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(320, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch2 boss %s: stats did not resolve" % kind
		# The signature move: forcing the cd to zero must re-arm it.
		b.special_cd = 0.0
		var waited := 0.0
		while b.special_cd <= 0.0 and waited < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			waited += 0.1
		if b.special_cd <= 0.0:
			return "ch2 boss %s: signature move did not fire" % kind
		# Enrage threshold.
		b.take_damage(b.max_hp * 0.78, Vector2.ZERO, false, true)
		waited = 0.0
		while not b.enraged and waited < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			waited += 0.1
		if not b.enraged:
			return "ch2 boss %s: did not enrage" % kind
		# Death registers through the content kill-flow (and must NOT
		# advance the chapter quest — that belongs to real zone bosses).
		var quest_before: String = game.quest_key
		b.take_damage(9999999.0)
		waited = 0.0
		while not game.boss_done.get(kind, false) and waited < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			waited += 0.1
		if not game.boss_done.get(kind, false):
			return "ch2 boss %s: death did not register" % kind
		if game.quest_key != quest_before:
			return "ch2 boss %s: dev kill mutated the chapter quest" % kind
		# Clear summoned adds (wolves / cultists spawn at dummy-zone -1).
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		await game.get_tree().create_timer(0.2).timeout
	return ""
