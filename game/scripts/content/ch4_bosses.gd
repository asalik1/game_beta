## Chapter 4 bosses content module — The Slagfields (magma, BOSSES.md).
## Registered via one preload line in Story.CONTENT_MODULES; ENEMIES
## merges into Story.ALL_ENEMIES at boot; move logic lives in boss.gd
## (Chapter 4 block). Anchored at STORY levels 23/25/28 per the boss
## bible — listed level is the MINIMUM (no downscaling), tiers scale UP.
##
## HP anchors follow the round-45 methodology (see ch3_bosses.gd / DESIGN.md):
## the BOSSES.md first-pass table (5900/7600/11500) is ~2x under the gear-
## inclusive TTK budget, exactly as ch3's first pass was. Re-anchored to
## player dps ~224 x 1.12^(lvl-17): Calda 26s mid, Cinderhide raw-lean
## (plating IS its EHP), Ordo 36s finale. Damage/speed ride the BOSSES.md
## curve untouched. Needs a playtest pass at story level to confirm.
##
## PLACEHOLDER ASSETS (deliberate): sprites reuse existing art and the
## music/roar keys are the FINAL names — real boss_forgemistress.wav etc.
## auto-load by filename when they land; until then _boss_track() falls
## back to a shipped chapter-appropriate theme (game_base).

const ENEMIES := {
	# Cinderborn's finest smith, quenching blades in living slag. Her
	# fight is the HEAT CLOCK: her weapon heats over ~12s (hits burn,
	# telegraphs widen); she marches to a slag pool to QUENCH (reset heat
	# + stacking damage buff). Body-block the pool and she quenches THROUGH
	# you — the fight's hardest hit — and gains no buff.
	"forgemistress": {
		"name": "Forgemistress Calda", "sprite": "cultist",
		"hp": 11500.0, "dmg": 96.0, "speed": 150.0, "xp": 300, "gold": 240,
		"ranged": false, "scale": 6.0,
		"physres": 25.0, "magres": 20.0, "eva": 0.05, "critres": 5.0, "crit": 0.05, "dmg_type": "phys",
		"level": 23, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "AGI": 1.5},
		"music": "boss_forgemistress", "music_fallback": "boss_stormwarden",
		"lore": "Her blades never break. Lately, neither do her mistakes.",
	},
	# A slag-beast in a meter of cooled obsidian: near-immune while plated
	# (physres/magres ~85). The arena's LAVA is the answer — lure the
	# Fangmaw-style charge across a pool; standing in lava melts its plating
	# (at full melt the plates shed ~10s and the damage window opens, but a
	# magma-rain tantrum rides the window). At 30% the plates stop regrowing.
	"cinderhide": {
		"name": "Cinderhide the Unquenched", "sprite": "direwolf",
		"hp": 9500.0, "dmg": 110.0, "speed": 135.0, "xp": 330, "gold": 260,
		"ranged": false, "scale": 8.5,
		# Base resists are the SHED value; the plate mechanic adds +60 at
		# setup (plated 85) and drops it back on melt — so a fight reset
		# restores the honest 25, not a mid-melt number.
		"physres": 25.0, "magres": 25.0, "eva": 0.0, "critres": 6.0, "crit": 0.05, "dmg_type": "phys",
		"level": 25, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "VIT": 1.5},
		"music": "boss_cinderhide", "music_fallback": "boss_vargoth",
		"lore": "The foundry lost four crews learning that steel doesn't bite it. The fifth crew learned what does.",
	},
	# First herald of a waking god-king. The Judge speaks through his
	# sermons: THE VERDICT splits the arena and judges one half (paired
	# below 50%); at 66%/33% four SONS march toward him and each that
	# arrives heals him + speeds his verdicts (intercept them); at 20% the
	# Judge attends and magma-rain runs continuous.
	"ashpriest": {
		"name": "Ashpriest Ordo, Voice of the Molten Judge", "sprite": "choirmother",
		"hp": 28000.0, "dmg": 150.0, "speed": 95.0, "xp": 460, "gold": 360,
		"ranged": true, "scale": 6.0,
		"physres": 20.0, "magres": 45.0, "eva": 0.05, "critres": 8.0, "crit": 0.05, "dmg_type": "magic",
		"level": 28, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.0},
		"music": "boss_ashpriest", "music_fallback": "boss_choirmother",
		"lore": "Every sermon ends the same way. 'Guilty.' The fires agree.",
	},
}


## Dev/story spawn helper: boss + bar + theme in one call. Music uses the
## final key when the track exists, else the shipped fallback theme.
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
## spawn, stats resolve, its signature (special_cd) re-arms, its OWN phase
## mechanic trips (calda quenches; cinderhide plates then sheds on lava;
## ordo enrages + marches sons), and death rides the story-neutral rogue
## flow without touching chapter state. Waits on WALL-CLOCK timers.
static func selftest(game: Node2D) -> String:
	for kind in ["forgemistress", "cinderhide", "ashpriest"]:
		if not Story.ALL_ENEMIES.has(kind):
			return "ch4 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var music_ok: bool = game.music_tracks.has(ENEMIES[kind]["music"]) \
			or game.music_tracks.has(ENEMIES[kind].get("music_fallback", ""))
		if not music_ok:
			return "ch4 boss %s: neither music nor fallback track exists" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(340, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch4 boss %s: stats did not resolve" % kind

		if kind == "cinderhide":
			# Plates on at setup: physres must be well above the honest base.
			await game.get_tree().create_timer(0.2).timeout
			if b.physres < 70.0:
				return "ch4 boss cinderhide: plating did not raise resists"
			# Keep lava under it as it chases (it walks off a single pool) —
			# sustained contact is what melts the plating.
			var melted := 0.0
			while b.physres > 40.0 and melted < 6.0:
				game._add_hazard(game.cur_room, "lava", b.global_position, 90.0, 0.5)
				await game.get_tree().create_timer(0.1).timeout
				melted += 0.1
			if b.physres > 40.0:
				return "ch4 boss cinderhide: lava contact did not melt the plating"

		# The signature move: forcing the cd to zero must re-arm it.
		b.special_cd = 0.0
		var re := 0.0
		while b.special_cd <= 0.0 and re < 2.5:
			await game.get_tree().create_timer(0.1).timeout
			re += 0.1
		if b.special_cd <= 0.0:
			return "ch4 boss %s: signature move did not fire" % kind

		if kind == "ashpriest":
			# The Sons march at 66% — overshoot it and confirm adds spawn.
			b.take_damage(b.max_hp * 0.4, Vector2.ZERO, false, true)
			var waited := 0.0
			while game.get_tree().get_nodes_in_group("enemies").size() < 2 and waited < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				waited += 0.1
			if game.get_tree().get_nodes_in_group("enemies").size() < 2:
				return "ch4 boss ashpriest: the Sons did not march"

		# Death goes through the story-neutral rogue kill-flow.
		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		var died := 0.0
		while is_instance_valid(b) and not b.dying and died < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			died += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch4 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch4 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch4 boss %s: dev kill marked story state (boss_done)" % kind
		# Clear summoned adds (sons/embers spawn at the dummy zone -1).
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		# Clear any lava the fight (or the cinderhide test) left behind.
		for h in game.hazards.duplicate():
			if is_instance_valid(h.get("sprite")):
				h["sprite"].queue_free()
		game.hazards.clear()
		await game.get_tree().create_timer(0.2).timeout
	return ""
