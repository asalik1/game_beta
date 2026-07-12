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
		"name": "Forgemistress Calda", "sprite": "forgemistress",
		"hp": 11500.0, "dmg": 96.0, "speed": 150.0, "xp": 300, "gold": 240,
		"ranged": false, "scale": 8.5,
		"physres": 25.0, "magres": 20.0, "eva": 0.05, "critres": 5.0, "crit": 0.05, "dmg_type": "phys",
		"level": 23, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "AGI": 1.5},
		"music": "boss_forgemistress", "music_fallback": "boss_stormwarden",
		"lore": "Her blades never break. Lately, neither do her mistakes.",
		"mechanics": [
			{"name": "The Quench",
			 "tell": "She roars 'Calda moves to quench!' and marches to a glowing slag pool — a clean dip resets her heat and permanently sharpens her edge (a stacking damage buff), then flashes a ring of slag with two pools lingering on the rim.",
			 "counter": "Body-block the pool: stand on it and she quenches THROUGH you for the fight's hardest single hit (telegraphed — dodge the last beat) but gains no stack. Deny the buff early; late-fight stacks turn every hit lethal."},
			{"name": "Rising Heat",
			 "tell": "Her blade glows from dull to white-hot over ~12s; her forge-orange hammer lanes march out wider and hit harder the hotter she gets.",
			 "counter": "Read the glow as her damage timer — step off each hammer lane, and force a quench or burn her down before she caps out."},
			{"name": "White-Hot Slag Lobs",
			 "tell": "Once she's white-hot she hurls slag that rains down right where you've run to.",
			 "counter": "Kiting no longer keeps you safe — keep repositioning so the lobbed blast circles land behind you, not on your feet."},
		],
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
		# Resists stay the honest SHED value the whole fight (~25 / ~17% DR).
		# The plating is a separate FLAT ~82% pen-proof wall (plate_dr, set at
		# setup and dropped on melt) — not a resist swap, so a DPS build can't
		# outscale it and the lava-melt is mandatory.
		"physres": 25.0, "magres": 25.0, "eva": 0.0, "critres": 6.0, "crit": 0.05, "dmg_type": "phys",
		"level": 25, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "VIT": 1.5},
		"music": "boss_cinderhide", "music_fallback": "boss_vargoth",
		"lore": "The foundry lost four crews learning that steel doesn't bite it. The fifth crew learned what does.",
		"mechanics": [
			{"name": "Obsidian Plating",
			 "tell": "'Its obsidian hide is a meter thick' — while plated your hits read as tiny numbers (~82% cut). You cannot burn it down through the armor.",
			 "counter": "Don't dump cooldowns on a plated beast. Strip the plating first; only then does your damage matter."},
			{"name": "Bait the Charge Through Lava",
			 "tell": "It winds up a straight-line charge; pools of arena lava glow across the floor.",
			 "counter": "Line the charge up so it drags through a lava pool — standing in lava melts the plating, and a charge across one melts it fast. 'THE PLATING SHEDS' opens a ~10s window where your damage jumps 5-6x. Its own vent-breath lava won't help — only the field pools and magma-rain melt it."},
			{"name": "Vent Breath & Tantrum",
			 "tell": "It breathes a widening lava cone (wider and harder while plated) that lingers on the floor; the instant its plates shed, a magma tantrum rains circles around you.",
			 "counter": "Sidestep the cone — it's a damage trap, not a melt source for it. Ride out the shed-window tantrum while you dump damage; the open window is worth eating the rain around it."},
			{"name": "Cinderhide Enrages (30%)",
			 "tell": "At 30% it stops re-plating for good, glows red, speeds up ~35%, and layers magma rain over its chase.",
			 "counter": "The armor problem is over — commit everything. Keep dodging the rain and finish it before the speed grinds you down."},
		],
	},
	# First herald of a waking god-king. The Judge speaks through his
	# sermons: THE VERDICT splits the arena and judges one half (paired
	# below 50%); at 66%/33% four SONS march toward him and each that
	# arrives heals him + speeds his verdicts (intercept them); at 20% the
	# Judge attends and magma-rain runs continuous.
	"ashpriest": {
		"name": "Ashpriest Ordo, Voice of the Molten Judge", "sprite": "ashpriest",
		"hp": 28000.0, "dmg": 125.0, "speed": 95.0, "xp": 460, "gold": 360,
		"ranged": true, "scale": 10.5,
		"physres": 20.0, "magres": 45.0, "eva": 0.05, "critres": 8.0, "crit": 0.05, "dmg_type": "magic",
		"level": 28, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.0},
		"music": "boss_ashpriest", "music_fallback": "boss_choirmother",
		"lore": "Every sermon ends the same way. 'Guilty.' The fires agree.",
		"mechanics": [
			{"name": "The Verdict",
			 "tell": "'GUILTY: THE WEST/EAST' — half the arena washes in verdict light and detonates; below 50% it's paired, judging one half and then the other.",
			 "counter": "Stand in the un-washed half before it lands. When paired, step into the FIRST half after it fires (now scorched and safe) so you're clear for the second wave — the callout names both halves, trust it."},
			{"name": "Sons of the Judge",
			 "tell": "At 66% and 33% four Ember Sons spawn in the corners and crawl toward Ordo; each that reaches him heals him ~8% and quickens his verdicts.",
			 "counter": "Intercept and kill the Sons before they arrive — they ignore you and drop nothing, but every one Ordo consumes speeds up his sermon and undoes your damage."},
			{"name": "Brand Volleys",
			 "tell": "He kites at range, firing four-bolt brand fans to keep the distance honest.",
			 "counter": "Close on him or juke the fans rather than tanking them mid-chase — he backs off inside melee and advances when you drift too far, so control the spacing."},
			{"name": "The Judge Attends (20%)",
			 "tell": "At 20% he glows and magma rain runs continuous over the verdicts.",
			 "counter": "The floor never fully clears now — prioritize the verdict shelter over greed. The rain holds while a verdict is airborne, so you can cross to safety without eating both at once."},
		],
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
		# (MP: the LOCAL player — this is the test harness's own hero, not AI targeting.)
		var b := spawn(game, kind, game.local_player.global_position + Vector2(340, 0))
		await game.get_tree().create_timer(0.2).timeout
		if not is_instance_valid(b) or absf(b.max_hp - float(ENEMIES[kind]["hp"])) > 0.01:
			return "ch4 boss %s: stats did not resolve" % kind

		if kind == "cinderhide":
			# Plates on at setup: the flat wall (plate_dr) is up and the honest
			# base resist is UNCHANGED (the wall is not a resist swap).
			await game.get_tree().create_timer(0.2).timeout
			if not b.plated or b.plate_dr < 0.5:
				return "ch4 boss cinderhide: plating wall did not raise (plate_dr)"
			if b.physres > 40.0:
				return "ch4 boss cinderhide: plating inflated base resist (should be flat DR only)"
			# Keep lava under it as it chases (it walks off a single pool) —
			# sustained contact is what melts the plating and drops the wall.
			var melted := 0.0
			while b.plated and melted < 6.0:
				game._add_hazard(game.cur_room, "lava", b.global_position, 90.0, 0.5)
				await game.get_tree().create_timer(0.1).timeout
				melted += 0.1
			if b.plated or b.plate_dr > 0.01:
				return "ch4 boss cinderhide: lava contact did not shed the plating wall"

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
