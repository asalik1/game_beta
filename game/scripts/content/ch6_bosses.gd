## Chapter 6 bosses content module — The Blooming Deep (bog + spore, the
## first BLENDED chapter, BOSSES.md). Registered via one preload line in
## Story.CONTENT_MODULES; ENEMIES merges into Story.ALL_ENEMIES; move logic
## lives in boss.gd (Chapter 6 block). Levels 34/35/37 — MINIMUM (no
## downscaling); tiers scale UP.
##
## HP anchors follow the round-45 methodology; damage/speed ride the bible
## curve. The one new primitive is FORM SWAP (Kaethra). Auroch (burrow) and
## Rotmaw (censer-blooms + root + compost) are deliberately CHEAP — the
## chapter's engine budget goes to Kaethra. Needs a playtest pass.
##
## PLACEHOLDER ASSETS: sprites reuse existing art; music/roar keys are the
## FINAL names, else _boss_track() falls back to a shipped theme.

const ENEMIES := {
	# A bog-bull that drowned a century ago and never stopped growing —
	# a weather system with horns. SUBMERGE cycle (Sexton's burrow at
	# scale): it sinks untargetable, chases with eruption lines + surfaces
	# under you. Slowed in bog water (fight it near water when up, on land
	# when down). No enrage; the cycles just shorten.
	"auroch": {
		"name": "The Drowned Auroch", "sprite": "spider",
		# XP re-anchored (chapter-budget audit): the first-pass 780/820/1150
		# paid 100-136% of a level each — the chapter's fixed XP budget
		# (30+22·lvl, DESIGN r5) had no room left for trash. Mids ~67-70%,
		# finale ~85%, like ch1-4. Gold untouched (gold has no budget).
		"hp": 34000.0, "dmg": 250.0, "speed": 130.0, "xp": 520, "gold": 600,
		"ranged": false, "scale": 9.0,
		"physres": 35.0, "magres": 25.0, "eva": 0.0, "critres": 7.0, "crit": 0.05, "dmg_type": "phys",
		"level": 34, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 2.0, "VIT": 1.0},
		"music": "boss_auroch", "music_fallback": "boss_vargoth",
		"lore": "The bog keeps what it drowns. Lately it keeps things growing.",
	},
	# A Choir deacon who converted to the Blooming: if rot is the truth,
	# growth-without-death is the LIE, and lies this beautiful must be
	# tended. BLOOMS (censer-kin) sprout and spread drifting poison; VINE
	# LASH roots you inside a closing ring; COMPOST — a bloom killed near
	# him HEALS him, so weed the far garden and kite him off the near one.
	"gardener": {
		"name": "Rotmaw the Gardener", "sprite": "skeleton",
		"hp": 44000.0, "dmg": 270.0, "speed": 80.0, "xp": 560, "gold": 640,
		"ranged": true, "scale": 7.0,
		"physres": 25.0, "magres": 45.0, "eva": 0.05, "critres": 8.0, "crit": 0.05, "dmg_type": "magic",
		"level": 35, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.0},
		"music": "boss_gardener", "music_fallback": "boss_morwen",
		"lore": "He still keeps Choir vows. He just tends a different congregation, and waters it with pilgrims.",
	},
	# Wildfang's best shaman, who tested the Pale Root's cure on herself —
	# it worked, and replaced the beast with the Root. TWO FORMS, hard-swap
	# at 80/60/40/20%: HUNTRESS (melee charges, no adds) and BLOOM (rooted,
	# heals via two root-adds, spore volleys — kill the roots to force her
	# back). At 10% the Root abandons her and the fight ENDS: strike or
	# sheathe, through the convo system (no mid-combat branching).
	"curetwisted": {
		"name": "Kaethra Cure-Twisted", "sprite": "beastkin",
		"hp": 69000.0, "dmg": 330.0, "speed": 145.0, "xp": 720, "gold": 900,
		"ranged": false, "scale": 7.5,
		"physres": 30.0, "magres": 35.0, "eva": 0.05, "critres": 9.0, "crit": 0.05, "dmg_type": "phys",
		"level": 37, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"AGI": 1.5, "INT": 1.5},
		"music": "boss_kaethra", "music_fallback": "boss_nullwarden",
		"lore": "She cured the beast. Read that sentence again, carefully, and ask what's left.",
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
	for kind in ["auroch", "gardener", "curetwisted"]:
		if not Story.ALL_ENEMIES.has(kind):
			return "ch6 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var music_ok: bool = game.music_tracks.has(ENEMIES[kind]["music"]) \
			or game.music_tracks.has(ENEMIES[kind].get("music_fallback", ""))
		if not music_ok:
			return "ch6 boss %s: neither music nor fallback track exists" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(340, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch6 boss %s: stats did not resolve" % kind

		if kind == "auroch":
			# Submerge must round-trip: untargetable under, then back up.
			b.special_cd = 0.0
			var t := 0.0
			while not b.burrowed and t < 3.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if not b.burrowed:
				return "ch6 boss auroch: submerge never went under"
			t = 0.0
			while b.burrowed and t < 4.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if b.burrowed:
				return "ch6 boss auroch: never surfaced from submerge"
		else:
			# The signature move: forcing the cd to zero must re-arm it.
			b.special_cd = 0.0
			var re := 0.0
			while b.special_cd <= 0.0 and re < 2.5:
				await game.get_tree().create_timer(0.1).timeout
				re += 0.1
			if b.special_cd <= 0.0:
				return "ch6 boss %s: signature move did not fire" % kind

		if kind == "curetwisted":
			# Form swap: drop below the first threshold (80%) and confirm she
			# leaves the opening Huntress form.
			var form0: int = b.form
			b.take_damage(b.max_hp * 0.25, Vector2.ZERO, false, true)
			var t := 0.0
			while b.form == form0 and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if b.form == form0:
				return "ch6 boss curetwisted: did not swap forms at the threshold"

		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		var died := 0.0
		while is_instance_valid(b) and not b.dying and died < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			died += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch6 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch6 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch6 boss %s: dev kill marked story state (boss_done)" % kind
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		for h in game.hazards.duplicate():
			if is_instance_valid(h.get("sprite")):
				h["sprite"].queue_free()
		game.hazards.clear()
		game.player.rooted_time = 0.0
		await game.get_tree().create_timer(0.2).timeout
	return ""
