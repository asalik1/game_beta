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
		"hp": 62000.0, "dmg": 205.0, "speed": 115.0, "xp": 600, "gold": 980,
		# A drake the size of a weather front — the 4x+ tier is reserved
		# for exactly this kind of thing (boss scale doctrine, story.gd).
		"ranged": true, "scale": 13.0,
		"physres": 20.0, "magres": 45.0, "eva": 0.05, "critres": 9.0, "crit": 0.05, "dmg_type": "magic",
		"level": 38, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "AGI": 1.0},
		"music": "boss_veyx", "music_fallback": "boss_stormwarden",
		"lore": "It isn't angry. It's a syllable of something that hasn't finished speaking for six hundred years, and it's HAPPY.",
		"mechanics": [
			{"name": "Arc",
			 "tell": "Its signature current lances straight through you — unless you're standing near one of the conductor rods, which drinks the arc instead.",
			 "counter": "Shelter beside a rod to feed it the arc. But every redirect charges that rod, and the third overloads it into a big blast that destroys it — so rotate between rods rather than overloading one."},
			{"name": "Static Field",
			 "tell": "Static strikes scatter across the ground around you, and they come denser and faster whenever the rods are gone.",
			 "counter": "Keep rods alive to keep this thin — with no rods left it doubles up and fires almost twice as often. Keep moving between the strikes."},
			{"name": "Squall",
			 "tell": "It scatters a spinning ring of storm bolts outward in every direction.",
			 "counter": "The bolts fan with gaps between them — read the spacing and slip through, don't stand still trying to tank it."},
			{"name": "The Current Unbound (30%)",
			 "tell": "At 30% it glows and roars THE CURRENT UNBOUND — the rods respawn and every Arc now fires as a PAIR.",
			 "counter": "Two arcs at once means one rod may not be enough — keep two rods charged-but-safe, or accept eating one arc while you redirect the other. Watch the charge on both."},
		],
	},
	# The erased Guard founder, kept by the void. UNNAMING (signature):
	# vanishes and spawns 3 mirror copies; all four telegraph the same
	# dagger-fan but the REAL one's is MIRRORED — read the tell, hit the
	# real one. Void zones shrink the arena; blink-strike punishes lingering.
	"unnamed_echo": {
		"name": "The Echo of the Unnamed", "sprite": "assassin",
		"hp": 48000.0, "dmg": 260.0, "speed": 170.0, "xp": 640, "gold": 1020,
		# 2x floor, no higher: he mirrors the HERO — a person, not a titan.
		"ranged": false, "scale": 6.0,
		"physres": 25.0, "magres": 25.0, "eva": 0.15, "critres": 6.0, "crit": 0.15, "dmg_type": "phys",
		"level": 39, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"AGI": 2.0, "STR": 1.0},
		"music": "boss_echo", "music_fallback": "boss_vargoth",
		"lore": "The Guard erased one name from every record. The void returns everything we throw away.",
		"mechanics": [
			{"name": "Unnaming",
			 "tell": "It vanishes and four identical figures ring you at once — three are mirror copies wearing its face, and only one, in a random slot, is really it.",
			 "counter": "The copies just stand there; only the real Echo keeps attacking and fanning daggers. Read which figure acts and focus it — don't waste your rotation on the still ones."},
			{"name": "Splintering Void",
			 "tell": "Each mirror copy has a single hit point, but cutting one detonates a lingering void patch under it.",
			 "counter": "Don't cleave the copies down to find the real one — every one you pop leaves a damage zone on the floor. Ignore them and step clear of any patches they drop."},
			{"name": "Blink-Strike",
			 "tell": "Kite it too far and it blinks straight onto you in a burst of void, closing the gap instantly.",
			 "counter": "Don't over-kite — hold mid range. If it blinks in, expect the follow-up melee and dodge on landing rather than after."},
			{"name": "It Refuses to Be Forgotten (25%)",
			 "tell": "At 25% it flares void-purple, cries IT REFUSES TO BE FORGOTTEN, and speeds up.",
			 "counter": "Faster blinks and a tighter Unnaming cadence — commit your burst and finish it before the copies pile the arena with void."},
		],
	},
	# The last Speaker of the Storm Tongue's seal, reciting a 600-year vow —
	# now listening instead. THREE PHASES (the act's mechanics exam):
	# P1 Korrag matured (lash lines), P2 the Mouth (a rotating quiet
	# quadrant + vow-keeper adds that PAUSE the rotation), P3 the Word
	# Unfinished (faster, quiet OCTANT). Kill him and the seal cracks —
	# the mid-game begins. ACT 1 FINALE.
	"stormmouth": {
		"name": "Cyrraeth, Mouth of the Storm", "sprite": "nullwarden",
		"hp": 130000.0, "dmg": 275.0, "speed": 105.0, "xp": 800, "gold": 1900,
		# The Act 1 finale titan: ~4.5x the hero, the largest thing alive.
		"ranged": true, "scale": 13.5,
		"physres": 30.0, "magres": 45.0, "eva": 0.0, "critres": 10.0, "crit": 0.05, "dmg_type": "magic",
		"level": 41, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.5},
		"music": "boss_cyrraeth", "music_fallback": "boss_nullwarden",
		"lore": "Six hundred years of speakers kept the vow. He is the first to hear what it was silencing — and agree with it.",
		"mechanics": [
			{"name": "The Speaker (Phase 1)",
			 "tell": "He opens still reciting — whipping lines of lightning out through you and fanning four bolts at a time, like Korrag grown into a titan.",
			 "counter": "Step off the lash line and strafe the bolt fans. Standard footwork; this is the calm phase before the arena turns."},
			{"name": "Storm Rotation — Stay in the Quiet (60%)",
			 "tell": "At 60% THE MOUTH OPENS: every sector of the arena erupts except one quiet wedge, and that safe wedge rotates to a new angle each time he casts.",
			 "counter": "Stand in the quiet wedge, and move to the next one as it walks around — there's no safety at range anymore, only inside the wedge."},
			{"name": "Vow-Keepers",
			 "tell": "Two vow-keeper adds spawn at the arena edge and march slowly toward Cyrraeth; when one reaches him it speaks in his place and the storm rotation PAUSES.",
			 "counter": "Let them through — do NOT kill them. Every vow-keeper that reaches him buys you ~10s of stillness to catch up on damage."},
			{"name": "The Word Unfinished (25%)",
			 "tell": "At 25% THE WORD, UNFINISHED: he speeds up, the quiet wedge shrinks from a quarter of the arena to a narrow eighth, and lightning rains on you continuously.",
			 "counter": "Precision footwork now — find the narrow octant and never stop repositioning under the constant strikes. Race him down before the quiet closes entirely."},
		],
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
