## (T4) Chapter 2 bosses content module — registered via one preload
## line in Story.CONTENT_MODULES. The ENEMIES table merges into
## Story.ALL_ENEMIES at boot; move logic lives in boss.gd (Chapter 2
## block at the end), which preloads this script for the helpers.
##
## Remaining registration wishes (for T0, when convenient):
##   menus.gd BOSS_KINDS + dev-panel spawn list → data-driven, so
##   content bosses show in the codex BOSSES section and the F1 list.

# Same schema as Story.ENEMIES, plus "music" (track key) and "lore"
# (codex blurb). Anchored at the STORY spawn levels (8 / 10 / 16 —
# playtest round 6): a monster's listed level is its MINIMUM and its
# listed stats are the fight you actually play; difficulty tiers and
# endless mode scale UP from here. (They were briefly anchored at
# 14/22/32 "for the tiers", which down-scaled the story fights into
# paper — Warden Null hit for 12, softer than his own trash.)
const ENEMIES := {
	# Fangmaw's successor: a Stormwarden beastmaster the blight turned on
	# his own packs. Skirmishes at whip range, calls wolves, and when the
	# storm breaks the sky starts swinging with him.
	"stormwarden": {
		"name": "Korrag, Stormwarden Broken", "sprite": "korrag",
		"hp": 2000.0, "dmg": 30.0, "speed": 170.0, "xp": 90, "gold": 66,
		"ranged": false, "scale": 6.5,
		"physres": 25.0, "magres": 20.0, "eva": 0.06, "critres": 3.0, "crit": 0.05, "dmg_type": "phys",
		"level": 8, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 1.5, "AGI": 1.0, "VIT": 0.5},
		"music": "boss_stormwarden",
		"lore": "He once kept the warbands' beasts calm through thunder. Now the thunder keeps HIM.",
		"mechanics": [
			{"name": "Lightning Lash",
			 "tell": "He winds up and whips a line of lightning strikes straight out through you, each one landing a beat after the last.",
			 "counter": "Step sideways off the line — the strikes walk outward in sequence, so clearing the lane once takes you out of all of them."},
			{"name": "Whistle the Pack",
			 "tell": "At 66% and again at 33% he whistles and two wolves lope in beside him.",
			 "counter": "The wolves drop zero loot — don't stop to farm them. Peel them off or just keep kiting the warden; they thin out as the fight moves."},
			{"name": "Whip Snap",
			 "tell": "At mid range he flicks a single quick telegraph onto your feet to keep you honest.",
			 "counter": "A short cast — sidestep it and close or back off; don't sit parked at whip distance."},
			{"name": "The Storm Breaks (30%)",
			 "tell": "At 30% he glows blue-white, screams THE STORM BREAKS, moves a third faster, and stray bolts start hammering the ground around you.",
			 "counter": "He's faster and the sky is now a second threat — keep moving so the random bolts land where you were, not where you are."},
		],
	},
	# Morwen's echo: the Hollow Choir's matron. Fights like a hymn —
	# rippling rings of blight, verses of bolts, and she FEEDS on what
	# the choir marks.
	"choirmother": {
		"name": "The Choir Mother", "sprite": "choirmother",
		"hp": 3200.0, "dmg": 36.0, "speed": 120.0, "xp": 144, "gold": 114,
		"ranged": true, "scale": 6.5,
		"physres": 15.0, "magres": 45.0, "eva": 0.10, "critres": 4.0, "crit": 0.05, "dmg_type": "magic",
		"level": 10, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "AGI": 0.5, "VIT": 0.5},
		"music": "boss_choirmother",
		"lore": "Where Morwen cursed, the Mother sings. Her congregation never buries its dead.",
		"mechanics": [
			{"name": "Requiem",
			 "tell": "She raises the hymn and three rings of blight ripple outward from her, one after another, each wider than the last.",
			 "counter": "The rings expand away from her — move INWARD toward the Mother between waves, or thread the gaps as each ring passes."},
			{"name": "Hymn of Hunger",
			 "tell": "She marks the ground under you and, on the strike, the choir feeds her — she heals a slice of her health.",
			 "counter": "Leave the marked circle before it lands. Getting clipped feeds her; deny the strike and you deny the heal."},
			{"name": "The Choir Answers (60%)",
			 "tell": "At 60% she calls and two cultists rise from the congregation to flank you.",
			 "counter": "The adds pay nothing — don't chase loot. Keep the Mother as your focus; clear the cultists only if they're boxing you in."},
			{"name": "The Choir Crescendos (25%)",
			 "tell": "At 25% she flares magenta, screams THE CHOIR CRESCENDOS, speeds up, and her verse volleys thicken from three bolts to four.",
			 "counter": "Everything comes faster now — tighten your strafing and give the denser fans more room. Burn her down before the liturgy overwhelms you."},
		],
	},
	# The ruins' warden: a construct that predates Accord and Cinderborn
	# alike and recognizes neither. Slow, precise, and it sheds its own
	# armor when the fight demands speed.
	"nullwarden": {
		"name": "Warden Null, the Last Sentinel", "sprite": "nullwarden",
		"hp": 8000.0, "dmg": 55.0, "speed": 100.0, "xp": 225, "gold": 180,
		"ranged": false, "scale": 9.0,
		"physres": 55.0, "magres": 35.0, "eva": 0.0, "critres": 8.0, "crit": 0.05, "dmg_type": "phys",
		"level": 16, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"STR": 1.5, "VIT": 2.0},
		"music": "boss_nullwarden",
		"lore": "It asked the first shard-bearers for a passphrase no living tongue remembers.",
		"mechanics": [
			{"name": "Piston Protocol",
			 "tell": "It stamps a four-column grid of slams across the ground under you, the columns firing left to right in sequence.",
			 "counter": "The columns come in order, not all at once — move along the sweep or against it so you're always in a column that hasn't stamped yet."},
			{"name": "Beam Spoke",
			 "tell": "It rakes one long line of strikes straight down your lane, from itself out toward you.",
			 "counter": "Sidestep out of the lane — the whole beam is one straight line, so a step perpendicular clears all of it."},
			{"name": "Armor Shed (50%)",
			 "tell": "At 50% it sheds its plating, glows gold, warns ARMOR SHED — THE CORE IS EXPOSED, and moves faster.",
			 "counter": "Its physical armor drops hard — this is your damage window, commit your burst. But it's quicker now, so respect its melee and the faster beams."},
			{"name": "Overdrive (25%)",
			 "tell": "At 25% it flares red and engages OVERDRIVE — every attack cycles noticeably faster.",
			 "counter": "The slam ring doubles its bolts and the pistons come sooner. Keep moving and finish it — there's no safe idle time left."},
		],
	},
}


# (Kill-flow note: the old per-module on_died was superseded by
# game.on_rogue_boss_died — Boss.die() now routes EVERY non-story boss
# there, ch1 and ch2 alike, with multiboss-aware bar/music handling.)


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
		# Death goes through the rogue kill-flow: the boss dies, and the
		# story must NOT move — no quest change, no boss_done mark
		# (that belongs to real zone bosses).
		var quest_before: String = game.quest_key
		var done_before: bool = game.boss_done.get(kind, false)
		b.take_damage(9999999.0)
		waited = 0.0
		while is_instance_valid(b) and not b.dying and waited < 2.0:
			await game.get_tree().create_timer(0.1).timeout
			waited += 0.1
		if is_instance_valid(b) and not b.dying:
			return "ch2 boss %s: death did not register" % kind
		await game.get_tree().create_timer(0.2).timeout
		if game.quest_key != quest_before:
			return "ch2 boss %s: dev kill mutated the chapter quest" % kind
		if game.boss_done.get(kind, false) != done_before:
			return "ch2 boss %s: dev kill marked story state (boss_done)" % kind
		# Clear summoned adds (wolves / cultists spawn at dummy-zone -1).
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == -1:
				e.queue_free()
		await game.get_tree().create_timer(0.2).timeout
	return ""
