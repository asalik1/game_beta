## Chapter 5 bosses content module — The Long Sleep (ice, BOSSES.md).
## Registered via one preload line in Story.CONTENT_MODULES; ENEMIES
## merges into Story.ALL_ENEMIES at boot; move logic lives in boss.gd
## (Chapter 5 block). Anchored at STORY levels 29/31/33 — listed level is
## the MINIMUM (no downscaling); tiers scale UP.
##
## HP anchors follow the round-45 methodology (see ch3/ch4): the BOSSES.md
## first-pass table is ~2x under the gear-inclusive TTK budget. Re-anchored
## to player dps ~224 x 1.12^(lvl-17). Damage/speed ride the bible curve.
## Two new primitives debut: the player FREEZE/ROOT status (Serane) and
## STILLNESS detection (Halla). Needs a playtest pass at story level.
##
## PLACEHOLDER ASSETS: sprites reuse existing art; music/roar keys are the
## FINAL names and auto-load when real files land, else _boss_track() falls
## back to a shipped chapter-appropriate theme.

const ENEMIES := {
	# Wildfang winter-clan chieftain guarding the sleeping valley — not
	# evil, just fed through a famine by the cult and not asking what the
	# wagons carry. On ICE his Fangmaw-lineage charge CANNOT STOP: bait it
	# across a patch and he overshoots into the wall (self-stun + vuln).
	# Pack calls at 66%/33%. On death the pack drags him away.
	"whitepelt": {
		"name": "Hrolgar Whitepelt", "sprite": "beastkin",
		"hp": 22500.0, "dmg": 160.0, "speed": 155.0, "xp": 520, "gold": 400,
		"ranged": false, "scale": 5.6,
		"physres": 30.0, "magres": 25.0, "eva": 0.05, "critres": 6.0, "crit": 0.05, "dmg_type": "phys",
		"level": 29, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "VIT": 1.5},
		"music": "boss_whitepelt", "music_fallback": "boss_fangmaw",
		"lore": "He knows exactly what he's guarding. That's the price of feeding a clan through winter: knowing, and guarding it anyway.",
	},
	# The Guard mage who volunteered to be the Still Queen's LOCK, frozen
	# alive at the keystone for 600 years. FLASH FREEZE is the safe-spot
	# exam graduated: an arena-wide freeze with 2-3 thawed vents to stand
	# in (caught outside = frozen solid + vulnerable). SHATTER LANCE roots
	# you for a piercing line. At 40% the keystone cracks: ice spreads
	# inward and the freezes quicken.
	"icebound": {
		"name": "Serane the Icebound", "sprite": "witch",
		"hp": 30000.0, "dmg": 190.0, "speed": 90.0, "xp": 560, "gold": 430,
		"ranged": true, "scale": 5.6,
		"physres": 20.0, "magres": 55.0, "eva": 0.08, "critres": 7.0, "crit": 0.05, "dmg_type": "magic",
		"level": 31, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "AGI": 1.0},
		"music": "boss_icebound", "music_fallback": "boss_morwen",
		"lore": "She has held one door for six hundred years. She is not going to take your word for it.",
	},
	# The cult's shepherd — gentle, sincere, the most dangerous thing in
	# the chapter. Her LULLABY AURA inverts every safe-spot fight so far:
	# standing still stacks Drowse (5 = Asleep), and while you're drowsy
	# she MENDS. DREAMERS drift toward her and thicken the aura; killing
	# them is free and feels terrible. At 25% the Queen stirs.
	"sleepkeeper": {
		"name": "Mother Halla, Keeper of the Long Sleep", "sprite": "cultist",
		"hp": 48000.0, "dmg": 230.0, "speed": 85.0, "xp": 720, "gold": 560,
		"ranged": true, "scale": 6.2,
		"physres": 25.0, "magres": 45.0, "eva": 0.0, "critres": 9.0, "crit": 0.05, "dmg_type": "magic",
		"level": 33, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.5},
		"music": "boss_sleepkeeper", "music_fallback": "boss_choirmother",
		"lore": "She has never raised her voice. Ask the villages she emptied.",
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
	for kind in ["whitepelt", "icebound", "sleepkeeper"]:
		if not Story.ALL_ENEMIES.has(kind):
			return "ch5 boss %s: not merged into Story.ALL_ENEMIES" % kind
		var music_ok: bool = game.music_tracks.has(ENEMIES[kind]["music"]) \
			or game.music_tracks.has(ENEMIES[kind].get("music_fallback", ""))
		if not music_ok:
			return "ch5 boss %s: neither music nor fallback track exists" % kind
		var b := spawn(game, kind, game.player.global_position + Vector2(340, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch5 boss %s: stats did not resolve" % kind

		# The signature move: forcing the cd to zero must re-arm it.
		b.special_cd = 0.0
		var re := 0.0
		while b.special_cd <= 0.0 and re < 2.5:
			await game.get_tree().create_timer(0.1).timeout
			re += 0.1
		if b.special_cd <= 0.0:
			return "ch5 boss %s: signature move did not fire" % kind

		if kind == "whitepelt":
			# Pack calls at 66% — overshoot it and confirm wolves answer.
			b.take_damage(b.max_hp * 0.4, Vector2.ZERO, false, true)
			var waited := 0.0
			while game.get_tree().get_nodes_in_group("enemies").size() < 2 and waited < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				waited += 0.1
			if game.get_tree().get_nodes_in_group("enemies").size() < 2:
				return "ch5 boss whitepelt: the pack did not answer"
		else:
			# Serane cracks the keystone at 40%; Halla stirs the Queen at 25%.
			var thresh: float = 0.35 if kind == "icebound" else 0.15
			b.take_damage(maxf(0.0, b.hp - b.max_hp * thresh), Vector2.ZERO, false, true)
			var t := 0.0
			while not b.enraged and t < 2.0:
				await game.get_tree().create_timer(0.1).timeout
				t += 0.1
			if not b.enraged:
				return "ch5 boss %s: phase threshold did not trip" % kind

		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		var died := 0.0
		while is_instance_valid(b) and not b.dying and died < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			died += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch5 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch5 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch5 boss %s: dev kill marked story state (boss_done)" % kind
		# Clear summoned adds (wolves / dreamers spawn at the dummy zone -1)
		# and any ice the fight left behind, and thaw the test player.
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		for h in game.hazards.duplicate():
			if is_instance_valid(h.get("sprite")):
				h["sprite"].queue_free()
		game.hazards.clear()
		game.player.frozen_time = 0.0
		game.player.rooted_time = 0.0
		await game.get_tree().create_timer(0.2).timeout
	return ""
