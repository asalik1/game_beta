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
		"hp": 34000.0, "dmg": 178.0, "speed": 130.0, "xp": 520, "gold": 600,
		"ranged": false, "scale": 9.0,
		"physres": 35.0, "magres": 25.0, "eva": 0.0, "critres": 7.0, "crit": 0.05, "dmg_type": "phys",
		"level": 34, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"STR": 2.0, "VIT": 1.0},
		"music": "boss_auroch", "music_fallback": "boss_vargoth",
		"lore": "The bog keeps what it drowns. Lately it keeps things growing.",
		"mechanics": [
			{"name": "Submerge",
			 "tell": "It bellows IT SINKS and drops below the bog untargetable, tearing a line of eruption circles that walk toward you while two bog-spawn adds claw up — then it surfaces in a slam right under your feet.",
			 "counter": "You can't hit it while it's under, so save your burst for when it surfaces. Sidestep the marching eruption line and don't be standing still where it comes up — the dive cadence tightens as it bleeds."},
			{"name": "Gore Rush",
			 "tell": "Between dives it lowers its horns and charges in a straight line at your position.",
			 "counter": "It commits to the line once it starts — dodge perpendicular, never straight backward."},
			{"name": "Wallow",
			 "tell": "Up close it wallows, throwing a full ring of twelve shockwave bolts and splashing patches of poison across the ground.",
			 "counter": "Give it room when it's surfaced; leave yourself a gap to slip through the bolt ring and don't linger in the poison splashes."},
		],
	},
	# A Choir deacon who converted to the Blooming: if rot is the truth,
	# growth-without-death is the LIE, and lies this beautiful must be
	# tended. BLOOMS (censer-kin) sprout and spread drifting poison; VINE
	# LASH roots you inside a closing ring; COMPOST — a bloom killed near
	# him HEALS him, so weed the far garden and kite him off the near one.
	"gardener": {
		"name": "Rotmaw the Gardener", "sprite": "rotmaw",
		# rotmaw.png: PixelLab redesign body (2026-07-10), ember-red glow
		# pass baked in, ~95% cell coverage. Scale sits under the ch6
		# finale (kaethra 10.5) per the ordinance.
		"hp": 44000.0, "dmg": 185.0, "speed": 80.0, "xp": 560, "gold": 640,
		"ranged": true, "scale": 10.2,
		"physres": 25.0, "magres": 45.0, "eva": 0.05, "critres": 8.0, "crit": 0.05, "dmg_type": "magic",
		"level": 35, "hp_g": 0.14, "dmg_g": 0.13, "boss": true,
		"attrs": {"INT": 2.0, "VIT": 1.0},
		"music": "boss_gardener", "music_fallback": "boss_morwen",
		"lore": "He still keeps Choir vows. He just tends a different congregation, and waters it with pilgrims.",
		"mechanics": [
			{"name": "Carnivorous Blooms",
			 "tell": "Bloom-pods sprout across the garden and keep respawning; each living one drifts spreading clouds of poison outward.",
			 "counter": "Weed them or the poison stacks out of control — but only pop the ones far from Rotmaw, and mind where they die (see Compost)."},
			{"name": "Compost",
			 "tell": "A bloom that dies within a body's length of Rotmaw is composted — he visibly mends a chunk of health ('he composts the bloom').",
			 "counter": "Never kill a bloom next to him. Drag him off to open ground, then clear the FAR garden where the corpses can't feed him."},
			{"name": "Vine Lash",
			 "tell": "He lashes out a vine that ROOTS you in place, then closes a ring of eight growth-telegraphs around exactly where you stand.",
			 "counter": "The root is short — the instant it releases, dash clear of the closing ring before it detonates."},
			{"name": "Full Bloom (30%)",
			 "tell": "At 30% he glows and roars FULL BLOOM; blooms sprout faster and thicker and the vine lash comes more often.",
			 "counter": "The garden now outgrows your weeding — stop chasing blooms and burn Rotmaw down before the poison and lashes pile up."},
		],
	},
	# Wildfang's best shaman, who tested the Pale Root's cure on herself —
	# it worked, and replaced the beast with the Root. TWO FORMS, hard-swap
	# at 80/60/40/20%: HUNTRESS (melee charges, no adds) and BLOOM (rooted,
	# heals via two root-adds, spore volleys — kill the roots to force her
	# back). At 10% the Root abandons her and the fight ENDS: strike or
	# sheathe, through the convo system (no mid-combat branching).
	"curetwisted": {
		"name": "Kaethra Cure-Twisted", "sprite": "kaethra",
		"hp": 69000.0, "dmg": 205.0, "speed": 145.0, "xp": 720, "gold": 900,
		"ranged": false, "scale": 10.5,
		"physres": 30.0, "magres": 35.0, "eva": 0.05, "critres": 9.0, "crit": 0.05, "dmg_type": "phys",
		"level": 37, "hp_g": 0.15, "dmg_g": 0.14, "boss": true,
		"attrs": {"AGI": 1.5, "INT": 1.5},
		"music": "boss_kaethra", "music_fallback": "boss_nullwarden",
		"lore": "She cured the beast. Read that sentence again, carefully, and ask what's left.",
		"mechanics": [
			{"name": "Huntress Charge & Spear",
			 "tell": "In her opening Huntress form she charges you in a straight line every few seconds, and between charges hurls a thrown spear that marks a circle at your feet.",
			 "counter": "Dodge the charge sideways and keep moving so the spear's circle lands empty. Kiting no longer buys free time — the thrown spear reaches you at range."},
			{"name": "Form Swap",
			 "tell": "At 80/60/40/20% HP she hard-swaps forms with a roar — rooting in place as the BLOOM ('The Root wants to STAY'), then snapping back to the mobile Huntress ('...still me').",
			 "counter": "Read which form she's in and fight it: chase and dodge the Huntress, then unload on the rooted Bloom while she can't move. The rhythm flips at every breakpoint."},
			{"name": "Bloom Roots",
			 "tell": "In Bloom form she's rooted but two root-adds sprout beside her; while either lives she steadily heals, and she rains spiral and fan volleys of spores.",
			 "counter": "Kill BOTH roots first — damage into her while a root lives is wasted on the heal. Then dodge the spore spirals and dump damage while she's stuck in place."},
			{"name": "The Root Lets Go (10%)",
			 "tell": "At 10% the Root abandons her — she stops, drops her guard, and looks at you ('The Root lets go').",
			 "counter": "The fight ends on your terms here: a strike-or-sheathe choice, not a damage race. She dies either way — pick how."},
		],
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
		# (MP: the LOCAL player — this is the test harness's own hero, not AI targeting.)
		var b := spawn(game, kind, game.local_player.global_position + Vector2(340, 0))
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
		game.local_player.rooted_time = 0.0
		await game.get_tree().create_timer(0.2).timeout
	return ""
