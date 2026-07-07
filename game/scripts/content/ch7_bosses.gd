## Chapter 7 bosses content module — The Breaking Sky (storm + void, the
## ACT 1 FINALE, BOSSES.md). Registered via one preload line in
## Story.CONTENT_MODULES; ENEMIES merges into Story.ALL_ENEMIES; move logic
## lives in boss.gd (Chapter 7 block). Levels 38/39/41 — MINIMUM (no
## downscaling); Cyrraeth L41 closes early game.
##
## HP anchors follow the round-45 methodology; damage/speed ride the bible
## curve. New primitives: conductor-rod arc redirection (Veyx), mirrored-
## telegraph clones (Echo), and rotating sector zones (Cyrraeth, extending
## Ordo's rect tech). Needs a playtest pass at story level.
##
## PLACEHOLDER ASSETS: sprites reuse existing art; music/roar keys are the
## FINAL names, else _boss_track() falls back to a shipped theme.

const ENEMIES := {
	# A piece of the Storm Tongue's own voice, loose and delighted. ARC
	# (signature) chains to the player UNLESS a conductor rod is nearer —
	# stand by a rod to feed it the arc, but each redirect charges it and
	# 3 charges EXPLODE. Rotate rods, manage charges. At 30% rods respawn
	# and arcs come in pairs.
	"stormdrake_veyx": {
		"name": "Veyx, the Unchained Current", "sprite": "stormwarden",
		# XP re-anchored (chapter-budget audit): 1250/1300/2400 paid 1.4-2.5
		# LEVELS each — Cyrraeth alone was two and a half. Mids ~70%, act
		# finale ~86% of a level; Act 1 closes at ~L41-42 as designed.
		# The finale's fanfare stays in its gold (gold has no XP budget).
		"hp": 62000.0, "dmg": 350.0, "speed": 115.0, "xp": 600, "gold": 980,
		# A drake the size of a weather front — the 4x+ tier is reserved
		# for exactly this kind of thing (boss scale doctrine, story.gd).
		"ranged": true, "scale": 13.0,
		"physres": 20.0, "magres": 45.0, "eva": 0.05, "critres": 9.0, "crit": 0.05, "dmg_type": "magic",
		"level": 38, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "AGI": 1.0},
		"music": "boss_veyx", "music_fallback": "boss_stormwarden",
		"lore": "It isn't angry. It's a syllable of something that hasn't finished speaking for six hundred years, and it's HAPPY.",
	},
	# The erased Guard founder, kept by the void. UNNAMING (signature):
	# vanishes and spawns 3 mirror copies; all four telegraph the same
	# dagger-fan but the REAL one's is MIRRORED — read the tell, hit the
	# real one. Void zones shrink the arena; blink-strike punishes lingering.
	"unnamed_echo": {
		"name": "The Echo of the Unnamed", "sprite": "assassin",
		"hp": 48000.0, "dmg": 375.0, "speed": 170.0, "xp": 640, "gold": 1020,
		# 2x floor, no higher: he mirrors the HERO — a person, not a titan.
		"ranged": false, "scale": 6.0,
		"physres": 25.0, "magres": 25.0, "eva": 0.15, "critres": 6.0, "crit": 0.15, "dmg_type": "phys",
		"level": 39, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"AGI": 2.0, "STR": 1.0},
		"music": "boss_echo", "music_fallback": "boss_vargoth",
		"lore": "The Guard erased one name from every record. The void returns everything we throw away.",
	},
	# The last Speaker of the Storm Tongue's seal, reciting a 600-year vow —
	# now listening instead. THREE PHASES (the act's mechanics exam):
	# P1 Korrag matured (lash lines), P2 the Mouth (a rotating quiet
	# quadrant + vow-keeper adds that PAUSE the rotation), P3 the Word
	# Unfinished (faster, quiet OCTANT). Kill him and the seal cracks —
	# the mid-game begins. ACT 1 FINALE.
	"stormmouth": {
		"name": "Cyrraeth, Mouth of the Storm", "sprite": "nullwarden",
		"hp": 130000.0, "dmg": 460.0, "speed": 105.0, "xp": 800, "gold": 1900,
		# The Act 1 finale titan: ~4.5x the hero, the largest thing alive.
		"ranged": true, "scale": 13.5,
		"physres": 30.0, "magres": 45.0, "eva": 0.0, "critres": 10.0, "crit": 0.05, "dmg_type": "magic",
		"level": 41, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.5},
		"music": "boss_cyrraeth", "music_fallback": "boss_nullwarden",
		"lore": "Six hundred years of speakers kept the vow. He is the first to hear what it was silencing — and agree with it.",
	},
	# Echo's mirror copies: void-purple ghosts wearing his face. 1 HP,
	# zero rewards, stationary decoys that fan alongside the real him;
	# cutting one detonates a void zone underfoot.
	"echo_clone": {
		"name": "Mirror of the Unnamed", "sprite": "assassin",
		"hp": 1.0, "dmg": 0.0, "speed": 0.0, "xp": 0, "gold": 0,
		# Must MATCH unnamed_echo's scale — the decoys only work same-size.
		"ranged": true, "scale": 6.0,
		"physres": 0.0, "magres": 0.0, "eva": 0.0, "critres": 0.0, "crit": 0.0, "dmg_type": "magic",
		"level": 39, "hp_g": 0.10, "dmg_g": 0.0,
		"attrs": {"AGI": 1.0},
	},
}


static func spawn(game: Node2D, kind: String, pos: Vector2) -> Boss:
	var b := Boss.make_boss(game, kind, pos)
	game.current_boss = b
	game.add_child(b)
	game.hud.show_boss_bar(ENEMIES[kind]["name"])
	var track := String(ENEMIES[kind]["music"])
	if not game.music_tracks.has(track):
		track = String(ENEMIES[kind].get("music_fallback", ""))
	if game.music_tracks.has(track):
		game.set_music(track)
	return b


## Kill-flow selftest (autotest hook). Per boss: spawn, stats resolve,
## signature (special_cd) re-arms, its phase mechanic trips, story-neutral
## rogue death. Waits on WALL-CLOCK timers.
static func selftest(game: Node2D) -> String:
	for kind in ["stormdrake_veyx", "unnamed_echo", "stormmouth"]:
		if not Story.ALL_ENEMIES.has(kind):
			return "ch7 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var music_ok: bool = game.music_tracks.has(ENEMIES[kind]["music"]) \
			or game.music_tracks.has(ENEMIES[kind].get("music_fallback", ""))
		if not music_ok:
			return "ch7 boss %s: neither music nor fallback track exists" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(340, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch7 boss %s: stats did not resolve" % kind

		# The signature move: forcing the cd to zero must re-arm it.
		b.special_cd = 0.0
		var re := 0.0
		while b.special_cd <= 0.0 and re < 2.5:
			await game.get_tree().create_timer(0.1).timeout
			re += 0.1
		if b.special_cd <= 0.0:
			return "ch7 boss %s: signature move did not fire" % kind

		if kind == "unnamed_echo":
			# Unnaming must conjure the mirror copies.
			var waited := 0.0
			while game.get_tree().get_nodes_in_group("enemies").size() < 2 and waited < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				waited += 0.1
			if game.get_tree().get_nodes_in_group("enemies").size() < 2:
				return "ch7 boss unnamed_echo: the mirror copies never appeared"
		elif kind == "stormmouth":
			# The 3-phase finale must advance past P1 (the Mouth at 60%).
			b.take_damage(b.max_hp * 0.45, Vector2.ZERO, false, true)
			var t := 0.0
			while b.phase < 2 and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if b.phase < 2:
				return "ch7 boss stormmouth: never entered the Mouth phase"
		else:
			# Veyx: rods respawn + arcs pair at 30% (enrage).
			b.take_damage(maxf(0.0, b.hp - b.max_hp * 0.25), Vector2.ZERO, false, true)
			var t := 0.0
			while not b.enraged and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if not b.enraged:
				return "ch7 boss stormdrake_veyx: phase threshold did not trip"

		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		var died := 0.0
		while is_instance_valid(b) and not b.dying and died < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			died += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch7 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch7 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch7 boss %s: dev kill marked story state (boss_done)" % kind
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		for h in game.hazards.duplicate():
			if is_instance_valid(h.get("sprite")):
				h["sprite"].queue_free()
		game.hazards.clear()
		await game.get_tree().create_timer(0.2).timeout
	return ""
