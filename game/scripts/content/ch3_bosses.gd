## Chapter 3 bosses content module — The Unburied Vale (BOSSES.md).
## Registered via one preload line in Story.CONTENT_MODULES; ENEMIES
## merges into Story.ALL_ENEMIES at boot; move logic lives in boss.gd
## (Chapter 3 block). Anchored at STORY levels 17/19/22 per the boss
## bible — listed level is the MINIMUM (no downscaling), tiers scale UP.
##
## PLACEHOLDER ASSETS (deliberate, per 2026-07-04 session): sprites
## reuse existing art and "music"/"roar_<kind>" keys are the FINAL
## names — when boss_sexton.wav etc. land in assets/music|sounds they
## auto-load by filename and take over. Until then spawn() falls back
## to "music_fallback" and Boss.roar() falls back to the generic roar.

const ENEMIES := {
	# A gravedigger who dug for a congregation that never buries. His
	# fight is arithmetic: endless zero-reward shamblers, and corpses
	# that chain-detonate when they fall near each other.
	"sexton": {
		"name": "The Sexton, Gravedigger of the Vale", "sprite": "zombie",
		"hp": 2700.0, "dmg": 58.0, "speed": 120.0, "xp": 260, "gold": 200,
		"ranged": false, "scale": 5.2,
		"physres": 30.0, "magres": 15.0, "eva": 0.0, "critres": 5.0, "crit": 0.05, "dmg_type": "phys",
		"level": 17, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "VIT": 1.5},
		"music": "boss_sexton", "music_fallback": "boss_vargoth",
		"lore": "Every grave he ever dug stands open. He remembers who he meant each one for.",
	},
	# The first person the Choir refused to bury. Her scream became the
	# liturgy; the SILENCE (inverse telegraph) debuts here.
	"vess": {
		"name": "Vess the Unburied, First Widow", "sprite": "witch",
		"hp": 3300.0, "dmg": 66.0, "speed": 100.0, "xp": 300, "gold": 235,
		"ranged": true, "scale": 5.4,
		"physres": 12.0, "magres": 50.0, "eva": 0.10, "critres": 5.0, "crit": 0.05, "dmg_type": "magic",
		"level": 19, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "AGI": 1.0},
		"music": "boss_vess", "music_fallback": "boss_morwen",
		"lore": "The Choir's first hymn was a widow told 'no.' She is still singing her half of it.",
	},
	# The chapter finale: the saint the rot refuses. Censers heal him
	# (kill priority), the bell tolls shrink the shelter, and at 25%
	# he stands up for the first time in sixty years.
	"saint_varo": {
		"name": "Saint Varo the Unrotting", "sprite": "king",
		"hp": 5800.0, "dmg": 88.0, "speed": 70.0, "xp": 400, "gold": 310,
		"ranged": false, "scale": 6.4,
		"physres": 60.0, "magres": 40.0, "eva": 0.0, "critres": 9.0, "crit": 0.05, "dmg_type": "phys",
		"level": 22, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"VIT": 2.0, "STR": 1.5},
		"music": "boss_varo", "music_fallback": "boss_nullwarden",
		"lore": "The Choir's holiest relic is the one thing in Vaelscar the rot refuses. He prays daily that this is not what it means.",
	},
	# Varo's censer-bearers: scenery that bleeds. Zero rewards, zero
	# attacks — while one burns, the saint mends. (Add-channel-heal
	# primitive; Kaethra's roots and Veyx's rods reuse this shape.)
	"choir_censer": {
		"name": "Blighted Censer", "sprite": "pillar",
		"hp": 220.0, "dmg": 0.0, "speed": 0.0, "xp": 0, "gold": 0,
		"ranged": false, "scale": 2.6,
		"physres": 10.0, "magres": 30.0, "eva": 0.0, "critres": 0.0, "crit": 0.0, "dmg_type": "phys",
		"level": 16, "hp_g": 0.10, "dmg_g": 0.0,
		"attrs": {"VIT": 1.0},
	},
}


## Dev/story spawn helper: boss + bar + theme in one call. Music uses
## the final key when the track exists, else the placeholder fallback.
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


## Kill-flow selftest (autotest hook calls this in one line). Per boss:
## spawn, stats resolve, signature fires, its OWN phase mechanic trips
## (sexton: burrow round-trips; vess: keening; varo: censers heal him
## and he stands at 25%), and death rides the story-neutral rogue flow.
## Waits on WALL-CLOCK timers (headless frames race ahead of physics).
static func selftest(game: Node2D) -> String:
	for kind in ["sexton", "vess", "saint_varo"]:
		if not Story.ALL_ENEMIES.has(kind):
			return "ch3 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var music_ok: bool = game.music_tracks.has(ENEMIES[kind]["music"]) \
			or game.music_tracks.has(ENEMIES[kind].get("music_fallback", ""))
		if not music_ok:
			return "ch3 boss %s: neither music nor fallback track exists" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(320, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch3 boss %s: stats did not resolve" % kind

		if kind == "saint_varo":
			# Censers place themselves on the first think...
			var waited := 0.0
			while b.censers.size() < 3 and waited < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				waited += 0.1
			if b.censers.size() < 3:
				return "ch3 boss saint_varo: censers did not spawn"
			# ...and their incense must mend him while they burn.
			b.take_damage(b.max_hp * 0.2, Vector2.ZERO, false, true)
			var hurt: float = b.hp
			await game.get_tree().create_timer(0.6).timeout
			if b.hp <= hurt:
				return "ch3 boss saint_varo: censers lit but no incense heal"

		# The signature move: forcing the cd to zero must re-arm it.
		b.special_cd = 0.0
		var re := 0.0
		while b.special_cd <= 0.0 and re < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			re += 0.1
		if b.special_cd <= 0.0:
			return "ch3 boss %s: signature move did not fire" % kind

		if kind == "sexton":
			# Shovelwork must round-trip: under the dirt, then back up
			# (untargetable underground — the killshot below needs him out).
			var t := 0.0
			while not b.burrowed and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if not b.burrowed:
				return "ch3 boss sexton: shovelwork never burrowed"
			t = 0.0
			while b.burrowed and t < 3.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if b.burrowed:
				return "ch3 boss sexton: never surfaced from shovelwork"
		else:
			# Vess keens at 30%; Varo stands at 25%. Overshoot the
			# threshold hard enough that his incense can't out-heal it.
			b.take_damage(maxf(0.0, b.hp - b.max_hp * 0.1), Vector2.ZERO, false, true)
			var t := 0.0
			while not b.enraged and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if not b.enraged:
				return "ch3 boss %s: phase threshold did not trip" % kind

		# Death goes through the story-neutral rogue kill-flow.
		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		var died := 0.0
		while is_instance_valid(b) and not b.dying and died < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			died += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch3 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch3 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch3 boss %s: dev kill marked story state (boss_done)" % kind
		# Clear summoned adds (shamblers / censers spawn at dummy-zone -1).
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		await game.get_tree().create_timer(0.2).timeout
	return ""
