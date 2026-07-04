extends Node
## Automated smoke test (not part of the game).
## Covers: class select, dialogue, all class kits, target lock, the stat
## engine (curves, combo), themes, the row-based skill tree, gear + gems
## (socket/synthesize/sell-return), chests, S weapons, telegraphs,
## THE ZONE GRAPH (rooms, doors, gates, per-pack aggro, door seals,
## lazy building, fog-of-war map, fast travel, death-to-safe-room),
## room-clear boss flow, and victory.
## Run with:  godot --headless --path game res://scenes/test.tscn

var game: Game


# --quick: core-systems tier (~20s) for iterating on small fixes.
# It runs boot → one class kit → every systems test → UI smoke → pause
# menu, then exits BEFORE the content playthroughs (terrains, both
# chapters, opening E2Es, boss selftests). Full suite before staging.
var quick := false


func _ready() -> void:
	quick = "--quick" in OS.get_cmdline_user_args()
	_run()


var _failed := false


func _fail(msg: String) -> void:
	_failed = true
	push_error("AUTOTEST FAIL: " + msg)
	print("AUTOTEST FAIL: ", msg)
	get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _skip_dialogue() -> void:
	await _frames(3)
	var guard := 0
	while game.hud.dialogue_active and guard < 50:
		game.hud._advance_dialogue()
		await _frames(1)
		guard += 1


func _buff() -> void:
	game.player.max_hp = 50000.0
	game.player.hp = 50000.0


func _dummy(offset := Vector2(100, 0)) -> Enemy:
	var e := Enemy.make(game, "wolf", game.player.global_position + offset)
	game.add_enemy(e)
	return e


## Remove only the test DUMMIES (zone_idx -1), plus projectiles and
## lingering ult effects. Never touches the real room monsters.
func _clear_combat() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == -1:
			e.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	game.player.storm_time = 0.0
	game.player.berserk_time = 0.0


## Teleport into a room the way the game would enter it (builds it
## lazily, moves the camera clamp, marks it visited).
func _goto_room(i: int) -> void:
	game.player.global_position = game.room_center(i)
	game._enter_room(i)
	await _frames(3)


## Kill every living non-boss monster that belongs to room i.
func _kill_room(i: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss) and not e.dying:
			e.take_damage(9999999.0)
			await _frames(1)
	await _frames(10)


## All living non-boss monsters of room i.
func _room_mobs(i: int) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss) and not e.dying:
			out.append(e)
	return out


## Fingerprint of the current layout (room coords in index order).
func _layout_sig() -> String:
	var bits: Array = []
	for i in game.zone_count:
		bits.append(str(game.rooms[i]["coord"]))
	return ",".join(bits)


## The direction of the door in room a that leads to room b ("" = no
## such door). Layouts are SEEDED now — tests must never assume one.
func _dir_between(a: int, b: int) -> String:
	for d in game.rooms[a]["exits"].keys():
		if game.neighbor(a, String(d)) == b:
			return String(d)
	return ""


## The first interactable whose prompt matches, searched by prompt text.
func _find_action(prompt: String) -> Callable:
	for entry in game.interactables:
		if entry["prompt"].text == prompt:
			return entry["action"]
	return Callable()


func _run() -> void:
	# 0. Stat-engine math sanity.
	if absf(Stats.res_frac(120.0) - 0.5) > 0.01:
		return _fail("res curve broken")
	if Stats.crit_curve(0.9) > 0.95 or Stats.crit_curve(0.5) != 0.5:
		return _fail("crit curve broken")
	var r := Stats.resolve(100.0, "true", 0.0, 1.5, 0.0, 0.0, 500.0, 0.9, 50.0)
	if r["miss"] or r["dmg"] != 100.0 or r["crit"]:
		return _fail("true damage should ignore everything and never crit")
	# Pacing retrofit: mobs live ~2x longer at level parity; bosses don't.
	var wolf_now := Story.enemy_stats_at("wolf", 2)
	if absf(wolf_now["hp"] / Story.ALL_ENEMIES["wolf"]["hp"] - Story.TTK_HP_MULT) > 0.01:
		return _fail("mob TTK multiplier not applied")
	var fang_now := Story.enemy_stats_at("fangmaw", 4)
	if absf(fang_now["hp"] - Story.ALL_ENEMIES["fangmaw"]["hp"]) > 0.01:
		return _fail("boss HP should not get the mob TTK multiplier")
	# Level-gap rules: parity fights untouched, punching up collapses.
	if absf(Stats.gap_dealt_mult(10, 12) - 1.0) > 0.001 or absf(Stats.gap_taken_mult(12, 10) - 1.0) > 0.001:
		return _fail("level-gap grace window broken (±2 should be a fair fight)")
	if Stats.gap_dealt_mult(4, 14) > 0.11 or Stats.gap_taken_mult(14, 4) < 5.0:
		return _fail("level-gap cliffs too soft (a Lv4 must not solo a Lv14 boss)")
	print("ok: stat curves + true damage + TTK retune")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	game.no_saves = true  # never touch (or list) the player's real save files
	add_child(game)
	await _frames(10)

	# 1. Chapter select -> class select -> opening.
	if not (game.menus.is_open() and game.menus.current == "chapter_select"):
		return _fail("chapter select did not open")
	game.menus.pick_chapter("ch1")
	await _frames(2)
	if not (game.menus.is_open() and game.menus.current == "class_select"):
		return _fail("class select did not open")
	game.menus.pick_class("warrior")
	await _frames(5)
	if not game.hud.dialogue_active:
		return _fail("warrior opening scene did not start after class select")
	await _skip_dialogue()  # narration up to Bren's question
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("warrior opening offered no decision")
	var res_before := game.player.resonance
	game.hud._choose(0)  # kneel: own the harm
	await _frames(2)
	if game.player.resonance <= res_before or not game.get_flag("owned_the_harm", false):
		return _fail("opening choice did not move resonance / set its flag")
	await _skip_dialogue()  # Bren's reply + closing narration
	print("ok: class select + warrior opening (owned the harm)")
	if game.merchant_zones != [0]:
		return _fail("only the village should start with a merchant (got %s)" % str(game.merchant_zones))
	_buff()

	# 1b. The room graph itself: shape, reciprocity, reachability, and
	# the DESIGN.md structure rules for Chapter 1.
	await _test_room_graph()

	# 2. Talk to the elder (simulated E keypress) -> the village gate.
	# (Room 2 is the spine's second stop wherever the seeded walk put it.)
	var village_exit := 2
	if _dir_between(0, village_exit) == "":
		return _fail("village is not linked to the road")
	if game._edge_unlocked(0, village_exit):
		return _fail("village east gate should be barred before the elder talk")
	if not game.gates.has(game._edge_key(0, village_exit)):
		return _fail("village east gate body was not built")
	game.player.global_position = game.elder.position + Vector2(40, 0)
	await _frames(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	var held := 0
	while not game.hud.dialogue_active and held < 60:
		await _frames(1)
		held += 1
	var ev_up := InputEventKey.new()
	ev_up.keycode = KEY_E
	ev_up.physical_keycode = KEY_E
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	if not game.hud.dialogue_active:
		return _fail("elder dialogue did not open")
	# Maren's greeting must READ the road choice (flag-gated variant).
	if not ("KNELT" in game.hud.text_label.text):
		return _fail("Maren did not react to the opening choice (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()
	await _frames(2)
	if not game.get_flag("met_elder", false):
		return _fail("elder talk did not set met_elder")
	if not game._edge_unlocked(0, village_exit) or game.gates.has(game._edge_key(0, village_exit)):
		return _fail("village east gate did not open after elder talk")
	print("ok: elder talk reads opening choice + village gate opens")

	# 3. Fire every ability of every class against dummy wolves.
	var anchor := game.room_center(0)
	game.player.global_position = anchor
	await _frames(5)
	var kit_classes: Array = ["warrior"] if quick else Classes.CLASSES.keys()
	for cls in kit_classes:
		game.player.set_class(cls)
		# Re-anchor every class: dashes drift the hero ~300-500px per kit
		# — six kits would carry it through the village doorway into the
		# Darkwood, where the loop's ults would slaughter calm packs.
		game.player.global_position = anchor
		game.player.locked_target = null
		_buff()
		for i in 3:
			_dummy(Vector2(90 + i * 50, i * 40 - 40))
		await _frames(3)
		for slot in ["a1", "a2", "a3", "ult"]:
			game.player.cds[slot] = 0.0
			game.player.mp = game.player.max_mp
			game.player.use_ability(slot)
			await _frames(10)
		await _frames(30)
		print("ok: %s abilities" % cls)
	game.player.set_class("warrior")
	_buff()
	# Hard reset: clear leftover dummies, projectiles and lingering ult
	# effects (arrow storm, delayed meteor) so later steps are clean.
	_clear_combat()
	game.player.locked_target = null
	game.player.global_position = anchor
	await _frames(45)

	# 3a2. Melee risk compensation: the plated classes regenerate.
	if game.player.regen_pct <= 0.0:
		return _fail("warrior passive regen missing")
	game.player.recalc()
	game.player.hp = game.player.max_hp * 0.5
	var regen_from := game.player.hp
	await get_tree().create_timer(0.5).timeout
	if game.player.hp <= regen_from:
		return _fail("passive regen did not tick")
	_buff()
	print("ok: melee passive regen")

	# 3b. Target lock cycling.
	var d1 := _dummy(Vector2(120, 0))
	var d2 := _dummy(Vector2(-160, 30))
	await _frames(3)
	game.player.cycle_target()
	var first := game.player.locked_target
	if first == null:
		return _fail("cycle_target did not lock anything")
	game.player.cycle_target()
	if game.player.locked_target == first:
		return _fail("cycle_target did not switch targets")
	d1.take_damage(999999.0)
	d2.take_damage(999999.0)
	await _frames(5)
	print("ok: target lock cycling")

	# 3c. Themes: level up until one unlocks, assign it, verify the DoT.
	while game.player.themes_known < 1 and game.player.level < 10:
		game.player.gain_xp(game.player.xp_needed())
		await _frames(2)
	if game.player.themes_known < 1:
		return _fail("no theme unlocked by level %d" % game.player.level)
	game.player.pending_theme_note = ""
	if game.player.ability_theme["a1"] == "":
		return _fail("first theme was not auto-assigned")
	# Warrior theme column 1 = Fury; switch a1 to Earth (index 2) for a testable stun/slow.
	game.player.set_ability_theme("a1", "fury")
	var probe := _dummy(Vector2(70, 0))
	await _frames(3)
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(8)
	if is_instance_valid(probe) and not probe.dying:
		probe.take_damage(999999.0)
	print("ok: themes unlock + assignment (%s on Cleave)" % game.player.ability_theme["a1"])

	# 3c2. Per-ability variants: one theme, different behavior per skill.
	game.player.themes_known = 3  # test cheat: open all three columns
	# Earth Cleave launches a stone shockwave (a piercing projectile).
	game.player.set_ability_theme("a1", "earth")
	var proj_before := get_tree().get_nodes_in_group("projectiles").size()
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(2)
	if get_tree().get_nodes_in_group("projectiles").size() <= proj_before:
		return _fail("earth Cleave did not launch a quake wave")
	# Fury Berserk: deeper rage tuning (+55% for 10s).
	game.player.set_ability_theme("ult", "fury")
	game.player.cds["ult"] = 0.0
	game.player.use_ability("ult")
	if absf(game.player.berserk_bonus - 0.55) > 0.001 or game.player.berserk_time < 9.5:
		return _fail("fury Berserk tuning not applied (bonus %.2f, dur %.1f)" %
			[game.player.berserk_bonus, game.player.berserk_time])
	game.player.berserk_time = 0.0

	# Poison Fan of Knives: ONE blade that blooms into a poison mist.
	game.player.set_class("assassin")
	game.player.themes_known = 3
	game.player.set_ability_theme("a3", "poison")
	var vic := _dummy(Vector2(130, 0))
	vic.max_hp = 100000.0
	vic.hp = vic.max_hp
	vic.speed = 0.0  # pin it: a chasing wolf can slip inside the knife's spawn offset
	await _frames(3)
	game.player.cds["a3"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a3")
	# Poll in REAL time, not frames: headless frames run uncapped while
	# the mist ticks on wall-clock timers (0.4s), so frame counts race
	# far ahead of the poison. One retry in case the throw whiffed.
	var bloom_waited := 0.0
	while is_instance_valid(vic) and not vic.dying and vic.burn_time <= 0.0 and bloom_waited < 4.0:
		await get_tree().create_timer(0.2).timeout
		bloom_waited += 0.2
		if absf(bloom_waited - 2.0) < 0.01:
			game.player.cds["a3"] = 0.0
			game.player.mp = game.player.max_mp
			game.player.use_ability("a3")
	if not is_instance_valid(vic) or vic.burn_time <= 0.0:
		return _fail("venom bloom mist did not poison the target")
	_clear_combat()

	# Hunt Tumble: lines up a guaranteed crit on the next hit.
	game.player.set_class("archer")
	game.player.themes_known = 3
	game.player.set_ability_theme("a3", "hunt")
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if not game.player.next_crit:
		return _fail("hunt Tumble did not line up a guaranteed crit")
	game.player.next_crit = false
	game.player.set_class("warrior")  # restore for the combo test
	game.player.pending_theme_note = ""
	await _frames(3)
	print("ok: per-ability theme variants (quake / berserk tune / venom bloom / lined shot)")

	# 3c3. Paladin kit: Aegis guard + redirect smite, Consecration
	# heal-on-hit, Chains of Wrath drag.
	game.player.set_class("paladin")
	game.player.themes_known = 3
	_buff()
	game.player.eva = 0.0
	game.player.cds["a3"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a3")
	if game.player.aegis_time <= 0.0:
		return _fail("Aegis did not raise the shield")
	var smite_probe := _dummy(Vector2(60, 0))
	smite_probe.max_hp = 100000.0
	smite_probe.hp = smite_probe.max_hp
	smite_probe.speed = 0.0
	await _frames(3)
	game.player.hurt_cd = 0.0
	game.player.take_damage(10.0, "phys")
	await _frames(3)
	if smite_probe.hp >= smite_probe.max_hp:
		return _fail("Aegis did not smite the attacker")
	# Holy Consecration: every enemy struck mends you.
	game.player.set_ability_theme("a2", "holy")
	game.player.regen_pct = 0.0  # isolate the on-hit mend from passive regen
	game.player.hp = game.player.max_hp * 0.5
	var pal_hp := game.player.hp
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(10)
	if game.player.hp <= pal_hp:
		return _fail("holy Consecration did not mend on hit")
	game.player.recalc()  # restore the passive regen
	# Chains of Wrath: the pack is dragged to the hammer. The drag tween
	# (0.28s) and the verdict timer (0.34s) run on WALL clock, so poll in
	# real time — headless frames race far ahead of timers.
	var dragged := _dummy(Vector2(240, 0))
	dragged.max_hp = 100000.0
	dragged.hp = dragged.max_hp
	dragged.speed = 0.0
	await _frames(3)
	game.player.cds["ult"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("ult")
	var chains_waited := 0.0
	while is_instance_valid(dragged) and not dragged.dying \
			and dragged.hp >= dragged.max_hp and chains_waited < 3.0:
		await get_tree().create_timer(0.2).timeout
		chains_waited += 0.2
	if is_instance_valid(dragged) and not dragged.dying:
		if dragged.hp >= dragged.max_hp:
			return _fail("Chains of Wrath dealt no damage")
		if dragged.global_position.distance_to(game.player.global_position) > 200.0:
			return _fail("Chains of Wrath did not drag the enemy in")
	_clear_combat()
	game.player.aegis_time = 0.0
	await _frames(3)
	print("ok: paladin kit (aegis smite, holy mend, chains drag)")

	# 3c4. Warlock kit: hex death-detonation, Dark Pact blood price,
	# Void Rift delayed burst.
	game.player.set_class("warlock")
	game.player.themes_known = 3
	_buff()
	var hexed_a := _dummy(Vector2(90, 0))
	hexed_a.max_hp = 100000.0
	hexed_a.hp = hexed_a.max_hp
	hexed_a.speed = 0.0
	var hexed_b := _dummy(Vector2(150, 0))
	hexed_b.max_hp = 100000.0
	hexed_b.hp = hexed_b.max_hp
	hexed_b.speed = 0.0
	await _frames(3)
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(3)
	if game.player.hexed.size() < 2:
		return _fail("Hex did not curse the pack (%d cursed)" % game.player.hexed.size())
	# Zero the hex's own DoT first so the only damage left to observe is
	# the death-detonation itself.
	hexed_b.burn_time = 0.0
	hexed_b.burn_dps = 0.0
	var b_hp: float = hexed_b.hp
	hexed_a.take_damage(999999.0)
	var boom_wait := 0.0
	while is_instance_valid(hexed_b) and hexed_b.hp >= b_hp and boom_wait < 2.0:
		await get_tree().create_timer(0.1).timeout
		boom_wait += 0.1
	if not is_instance_valid(hexed_b) or hexed_b.hp >= b_hp:
		return _fail("hex death-detonation did not hit the neighbor")
	# Dark Pact: HP is the cost, a lifesteal surge is the recovery.
	game.player.regen_pct = 0.0  # the blood price must stay visible
	game.player.hp = game.player.max_hp
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if game.player.hp >= game.player.max_hp:
		return _fail("Dark Pact did not take its blood price")
	if game.player.pact_time <= 0.0:
		return _fail("Dark Pact did not start the lifesteal surge")
	game.player.recalc()
	# Void Rift: pulls for ~0.9s of WALL time, then bursts — poll.
	hexed_b.burn_time = 0.0
	hexed_b.burn_dps = 0.0
	var rift_hp: float = hexed_b.hp
	game.player.cds["ult"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("ult")
	var rift_wait := 0.0
	while is_instance_valid(hexed_b) and not hexed_b.dying \
			and hexed_b.hp >= rift_hp and rift_wait < 4.0:
		await get_tree().create_timer(0.2).timeout
		rift_wait += 0.2
	if is_instance_valid(hexed_b) and not hexed_b.dying and hexed_b.hp >= rift_hp:
		return _fail("Void Rift burst dealt no damage")
	_clear_combat()
	game.player.hexed.clear()
	game.player.pact_time = 0.0
	game.player.set_class("warrior")  # restore for the combo test
	game.player.pending_theme_note = ""
	_buff()
	await _frames(3)
	print("ok: warlock kit (hex detonation, dark pact, void rift)")

	# 3d. COMBO stat: at the 60% cap, ~60% of casts skip the cooldown
	# (cds left at 0 by a proc, or set to the full cooldown otherwise).
	var resets := 0
	for i in 200:
		game.player.combo = 1.0  # re-assert: recalc() from a stray level-up would reset it
		game.player.cds["a2"] = 0.0
		game.player.mp = game.player.max_mp
		game.player.use_ability("a2")
		if game.player.cds["a2"] <= 0.0:
			resets += 1
	if resets < 60 or resets > 180:
		return _fail("combo reset rate out of range: %d/200 (expected ~120)" % resets)
	game.player.recalc()  # restore real combo value
	print("ok: combo stat (%d/200 resets)" % resets)

	# 3d2. Attributes: +5/level, class-scaled conversion, CR responds.
	if game.player.unspent_attr < 5:
		return _fail("no attribute points after leveling (has %d)" % game.player.unspent_attr)
	var cr_before := game.player.combat_rating()
	var atk_b := game.player.atk
	var primary_attr: String = Classes.CLASSES[game.player.cls]["primary"]
	if not game.player.add_attr_points(primary_attr, 5):
		return _fail("could not spend attribute points")
	if game.player.atk <= atk_b:
		return _fail("primary attribute points did not raise ATK")
	if game.player.combat_rating() <= cr_before:
		return _fail("combat rating did not rise with attributes")
	print("ok: attributes + combat rating (CR %d -> %d)" % [cr_before, game.player.combat_rating()])

	# 3d3. Monster levels: a Lv 30 wolf out-stats a story-level wolf.
	var w_lo := Story.enemy_stats_at("wolf", 2)
	var w_hi := Story.enemy_stats_at("wolf", 30)
	var boss_hi := Story.enemy_stats_at("fangmaw", 30)
	if w_hi["hp"] <= w_lo["hp"] or w_hi["dmg"] <= w_lo["dmg"]:
		return _fail("wolf did not scale with level")
	if boss_hi["hp"] / Story.ALL_ENEMIES["fangmaw"]["hp"] <= w_hi["hp"] / (Story.ALL_ENEMIES["wolf"]["hp"] * Story.TTK_HP_MULT):
		return _fail("boss growth should outpace trash growth")
	var lv_wolf := _dummy(Vector2(120, 40))
	var lv_wolf30 := Enemy.make(game, "wolf", game.player.global_position + Vector2(-140, 40), 30)
	game.add_enemy(lv_wolf30)
	await _frames(3)
	if lv_wolf30.max_hp <= lv_wolf.max_hp or lv_wolf30.level != 30:
		return _fail("spawned enemy did not honor its level")
	lv_wolf.take_damage(9999999.0)
	lv_wolf30.take_damage(9999999.0)
	await _frames(3)
	print("ok: monster levels + growth scaling")

	# 3e. Kill XP.
	var xp_probe := _dummy(Vector2(80, 0))
	await _frames(3)
	var xp_before := game.player.xp + game.player.level * 100000
	xp_probe.take_damage(999999.0)
	await _frames(5)
	if game.player.xp + game.player.level * 100000 <= xp_before:
		return _fail("kill gave no xp")
	print("ok: kill xp")

	# 4. Chest -> loot -> equip.
	var bag_before := game.player.backpack.size()
	Chest.drop(game, "gold", game.player.global_position)
	await _frames(10)
	if game.player.backpack.size() <= bag_before:
		return _fail("chest gave no item")
	var got: Dictionary = game.player.backpack[-1]
	game.player.equip(got)
	if not game.player.equipment.has(got["slot"]):
		return _fail("equip failed")
	print("ok: chest loot + equip (%s)" % Items.title(got))

	# 4a. Weapon shape identities.
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 3
	var clay := Items.roll_item_of("weapon", "C", wrng, "", "Claymore")
	var fang := Items.roll_item_of("weapon", "C", wrng, "", "Fang")
	if clay["main"]["atk_flat"] <= fang["main"]["atk_flat"]:
		return _fail("Claymore does not out-damage Fang")
	if not fang["subs"].has("crit"):
		return _fail("Fang has no guaranteed crit substat")
	print("ok: weapon shape identities")

	# 4b. S weapon: class shape, 3 gem slots, passive.
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	var s_wpn := Items.roll_item_of("weapon", "S", srng, "warrior")
	if s_wpn.get("passive", "") != "kingsblade" or s_wpn.get("cls", "") != "warrior":
		return _fail("S warrior weapon wrong passive/class")
	if s_wpn.get("gem_slots", 0) != 3:
		return _fail("S gear should have 3 gem slots")
	game.player.add_item(s_wpn)
	game.player.equip(s_wpn)
	if game.player.s_passive() != "kingsblade":
		return _fail("s_passive not active after equipping")
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(15)
	print("ok: S weapon + passive (%s)" % s_wpn["name"])

	# 4c. Gems: targeted socket, removal, stat change, synthesize, sell-return.
	var cg := Items.make_gem("crit", 1)
	game.player.gem_bag.append(cg)
	var crit_before := game.player.crit
	if not game.player.embed_gem_into(s_wpn, cg):
		return _fail("gem did not socket into chosen S weapon")
	if game.player.crit <= crit_before:
		return _fail("socketed crit gem did not raise crit")
	# Remove it and re-socket (player-controlled swap).
	game.player.remove_gem(s_wpn, 0)
	if s_wpn["gems"].size() != 0 or absf(game.player.crit - crit_before) > 0.001:
		return _fail("remove_gem did not restore stats")
	game.player.embed_gem_into(s_wpn, cg)
	game.menus.open_item_panel(s_wpn)
	await _frames(2)
	if game.menus.current != "item_panel":
		return _fail("item panel did not open")
	game.menus.close()
	await _frames(2)
	for i in 3:
		game.player.gem_bag.append(Items.make_gem("crit", 1))
	if not game.player.synthesize("crit", 1):
		return _fail("synthesize failed with 3 same gems")
	var has_lv2 := false
	for gem in game.player.gem_bag:
		if gem["stat"] == "crit" and gem["lvl"] == 2:
			has_lv2 = true
	if not has_lv2:
		return _fail("synthesis did not produce a Lv2 gem")
	# Selling returns embedded gems.
	var bag_gems := game.player.gem_bag.size()
	game.player.strip_gems(s_wpn)
	if game.player.gem_bag.size() != bag_gems + 1:
		return _fail("strip_gems did not return the socketed gem")
	game.player.recalc()
	print("ok: gems (socket, synthesize, sell-return)")

	# 4d. Telegraph resolves.
	game.telegraph(game.player.global_position + Vector2(40, 0), 60.0, 0.3, 5.0, {"sword": true})
	await _frames(45)
	print("ok: telegraph + falling sword")

	# 5. Skill tree: row caps and gating.
	game.player.skill_points = 12
	if game.player.level < Skills.ROW_LEVELS[1]:
		return _fail("test expects level >= row 2 by now")
	var added := 0
	for i in 6:  # try to overfill row 0
		if game.player.add_tree_point("w00"):
			added += 1
	if added != 5:
		return _fail("cell cap should stop at 5 (got %d)" % added)
	if game.player.add_tree_point("w01"):
		return _fail("row cap should block a 6th point in row 0")
	if game.player.dm("a1") < 1.24:
		return _fail("5 points in Heavy Cleave should give +25%")
	var high_row := Skills.TREES["warrior"][3][0]["id"]
	if game.player.level < Skills.ROW_LEVELS[3] and game.player.add_tree_point(high_row):
		return _fail("locked row accepted a point")
	print("ok: skill tree rows (caps + gating)")

	# 5a2. Auto-synthesize: socketed gems level first, then the bag rolls up.
	var socketed_item: Dictionary = game.player.equipment["weapon"]
	socketed_item["gems"].clear()
	game.player.gem_bag.clear()
	game.player.gem_bag.append(Items.make_gem("atk_pct", 1))
	if not game.player.embed_gem_into(socketed_item, game.player.gem_bag[0]):
		return _fail("could not socket the auto-synth test gem")
	for i in 11:
		game.player.gem_bag.append(Items.make_gem("atk_pct", 1))
	# 1 socketed L1 + 11 bag L1: socketed eats 2 (->L2), bag 9 -> 3xL2,
	# socketed eats 2 L2 (->L3), 1 L2 remains. 5 upgrades total.
	var ups: int = game.player.auto_synthesize()
	var socketed_lvl: int = socketed_item["gems"][0]["lvl"]
	if ups != 5 or socketed_lvl != 3:
		return _fail("auto-synthesize wrong result: %d upgrades, socketed L%d (want 5, L3)" % [ups, socketed_lvl])
	if game.player.gem_bag.size() != 1 or game.player.gem_bag[0]["lvl"] != 2:
		return _fail("auto-synthesize bag remainder wrong (%d gems)" % game.player.gem_bag.size())
	game.player.gem_bag.clear()
	socketed_item["gems"].clear()
	game.player.recalc()
	print("ok: auto-synthesize (equipped-first, %d upgrades)" % ups)

	# 5b. Save / load roundtrip on a scratch slot (now with room state).
	var p: Player = game.player
	p.gold = 4321
	p.resonance = -37.0
	p.faction_standing["cinderborn"] = 12
	var flags_keep: Dictionary = game.flags.duplicate(true)  # restore after — later tests need the opening flags
	game.set_flag("rt_flag", true)
	var kept_quest: String = game.quest_key
	var kept_level: int = p.level
	var kept_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	var kept_atk: float = p.atk
	var kept_seed: int = game.wander_seed
	var kept_visited: int = game.visited.size()
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	p.gold = 0
	p.resonance = 0.0
	p.faction_standing["cinderborn"] = 0
	game.quest_key = "talk"
	game.flags.clear()
	game.wander_seed = 0
	var loaded := SaveGame.read(SaveGame.MAX_SLOTS)
	if loaded.is_empty():
		return _fail("save file did not write/read")
	if String(loaded.get("chapter", "")) != "ch1":
		return _fail("save did not record its chapter")
	if int(loaded.get("version", 0)) != SaveGame.VERSION:
		return _fail("save version wrong")
	SaveGame.apply(game, loaded)
	await _frames(2)
	if p.gold != 4321 or p.resonance != -37.0 or p.faction_standing["cinderborn"] != 12:
		return _fail("save did not restore gold/resonance/faction")
	if game.quest_key != kept_quest or p.level != kept_level:
		return _fail("save did not restore quest/level")
	var got_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	if got_weapon != kept_weapon:
		return _fail("save did not restore equipment")
	if absf(p.atk - kept_atk) > 0.01:
		return _fail("stats after load differ from before save (atk %.2f vs %.2f)" % [p.atk, kept_atk])
	if not game.get_flag("rt_flag", false):
		return _fail("story flags did not survive the save roundtrip")
	if game.wander_seed != kept_seed:
		return _fail("wander seed did not survive the roundtrip")
	if game.visited.size() != kept_visited or not game.visited.get(0, false):
		return _fail("visited rooms did not survive the roundtrip")
	if game.cur_room != 0:
		return _fail("cur_room did not survive the roundtrip (got %d)" % game.cur_room)
	game.flags = flags_keep  # never strand the run without its opening flags
	game.flags["met_elder"] = true
	SaveGame.delete(SaveGame.MAX_SLOTS)
	if SaveGame.exists(SaveGame.MAX_SLOTS):
		return _fail("save delete failed")
	print("ok: save/load roundtrip (gold, resonance, factions, gear, room state)")

	# 5c. Choice dialogue + flag engine: choices apply resonance/flags,
	# and both flag- and band-gated text variants resolve.
	var convo := {
		"start": "n1",
		"nodes": {
			"n1": {"who": "Tester", "text": "Neutral opener.",
				"variants": [{"band": "tempted", "text": "Tempted opener."}],
				"choices": [
					{"text": "Dark path", "resonance": -40.0,
						"flags": {"chose_dark": true}, "faction": {"choir": 3}, "next": "n2"},
					{"text": "Light path", "resonance": 10.0, "next": "n2"},
				]},
			"n2": {"who": "Tester", "text": "Default reply.",
				"variants": [{"flag": "chose_dark", "text": "Flagged reply."}]},
		},
	}
	var convo_state := {"done": false}
	game.player.resonance = 0.0
	game.run_convo(convo, func() -> void: convo_state["done"] = true)
	await _frames(2)
	if not game.hud.choices_active or game.hud.choice_count != 2:
		return _fail("choice dialogue did not present 2 options")
	if game.hud.text_label.text != "Neutral opener.":
		return _fail("neutral variant not chosen at resonance 0")
	game.hud._choose(0)
	await _frames(2)
	if game.player.resonance != -40.0 or not game.get_flag("chose_dark", false):
		return _fail("choice did not apply resonance/flag")
	if game.player.faction_standing["choir"] != 3:
		return _fail("choice did not shift faction standing")
	if game.hud.text_label.text != "Flagged reply.":
		return _fail("flag-gated variant not shown (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()
	if not convo_state["done"]:
		return _fail("convo completion callback did not fire")
	# Resonance is now -40 = "tempted" band: the opener must change.
	game.run_convo(convo, Callable())
	await _frames(2)
	if game.hud.text_label.text != "Tempted opener.":
		return _fail("band-gated variant not shown for tempted resonance")
	game.hud._choose(1)
	await _frames(2)
	await _skip_dialogue()
	game.player.resonance = 0.0
	game.player.faction_standing["choir"] = 0
	game.flags.erase("chose_dark")  # cleanup — but keep the opening flags
	print("ok: choice dialogue engine (choices, flags, factions, resonance bands)")

	# 5d. Opening-convo data integrity: every node resolves, every cue
	# has a staged scene, every opening has a Maren counterpart.
	for cid in Story.ALL_CONVOS:
		var convo2: Dictionary = Story.ALL_CONVOS[cid]
		var nodes2: Dictionary = convo2["nodes"]
		if not nodes2.has(convo2["start"]):
			return _fail("%s: start node missing" % cid)
		for nid in nodes2:
			var node2: Dictionary = nodes2[nid]
			var nxt: String = String(node2.get("next", ""))
			if nxt != "" and not nodes2.has(nxt):
				return _fail("%s/%s: next '%s' missing" % [cid, nid, nxt])
			if node2.has("cue") and not (String(node2["cue"]) in Cutscene.KNOWN_CUES):
				return _fail("%s/%s: unknown cue '%s'" % [cid, nid, node2["cue"]])
			for c2 in node2.get("choices", []):
				var cnxt: String = String(c2.get("next", ""))
				if cnxt != "" and not nodes2.has(cnxt):
					return _fail("%s/%s: choice next '%s' missing" % [cid, nid, cnxt])
			for v2 in node2.get("variants", []):
				var vnxt: String = String(v2.get("next", ""))
				if vnxt != "" and not nodes2.has(vnxt):
					return _fail("%s/%s: variant next '%s' missing" % [cid, nid, vnxt])
		if cid.begins_with("open_") and not Story.ALL_CONVOS.has("maren_" + cid.substr(5)):
			return _fail("%s has no matching Maren convo" % cid)
	# The wanderer pool's convos must all exist.
	for w in Story.WANDERERS:
		if not Story.ALL_CONVOS.has(String(w["convo"])):
			return _fail("wanderer convo '%s' missing" % w["convo"])
	print("ok: opening convo data integrity (%d convos)" % Story.ALL_CONVOS.size())

	# 6. Shop + codex + map still open fine.
	game.player.gold = 500
	# Inventory must survive a gem hoard (compact grid + capped scroll).
	for i in 40:
		game.player.gem_bag.append(Items.random_gem(game.loot_rng, 1 + (i % 5)))
	game.menus.open_inventory()
	await _frames(2)
	if not game.menus.is_open():
		return _fail("inventory did not open with a 40-gem bag")
	game.menus.close()
	game.player.gem_bag.clear()
	await _frames(1)
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[0].size() != 3:
		return _fail("shop did not open with stock")
	game.menus.open_codex("gear")
	await _frames(2)
	game.menus.open_codex("terrains")
	await _frames(2)
	game.menus.open_skills()
	await _frames(2)
	game.menus.open_theme_picker("a1")
	await _frames(2)
	if game.menus.current != "theme_pick":
		return _fail("theme picker did not open")
	game.menus.open_inventory("stats")
	await _frames(2)
	game.menus.open_skills("attributes")
	await _frames(2)
	game.menus.open_map()
	await _frames(2)
	if game.menus.current != "map":
		return _fail("map screen did not open")
	game.menus.open_dev()
	await _frames(2)
	game.menus.close()
	await _frames(2)
	print("ok: shop, codex, skill tree, theme picker, stats tab, map, dev panel UI")

	# --quick tier ends here, after one last check that the system menu
	# behaves (it works from ch1 state: replay lands in ch2 and exits).
	if quick:
		await _test_pause_menu()
		if _failed:
			return  # quit(1) is already queued — do not print PASS over it
		print("AUTOTEST QUICK PASS  (core systems only — run the FULL suite before staging)")
		get_tree().paused = false
		get_tree().quit(0)
		return

	# 6c. Terrains: apply every terrain to the (safe) outskirts room,
	# fire its event, tick hazards — none of it may crash.
	await _goto_room(1)
	game.player.global_position = game.rooms[1]["origin"] + Vector2(1900.0, 1100.0)
	await _frames(3)
	for tid in Terrains.DATA:
		game.apply_terrain(1, tid)
		await _frames(3)
		var terrain_ev: String = Terrains.DATA[tid].get("event", "")
		if terrain_ev != "":
			game.run_terrain_event(terrain_ev)
		await _frames(12)
	# The grave_spawn zombie path needs a "live" room: fake one monster.
	game.apply_terrain(1, "graveyard")
	game.zone_alive[1] = 1  # snapshot: outskirts are empty, restore below
	game.run_terrain_event("grave_spawn")
	await _frames(10)
	game.zone_alive[1] = 0
	game.apply_terrain(1, "village")  # restore for the story flow
	await _frames(60)  # let stray telegraphs resolve
	_clear_combat()    # remove event-spawned zombies
	game.gust_vec = Vector2.ZERO
	await _frames(5)
	_buff()
	print("ok: all %d terrains applied + events fired" % Terrains.DATA.size())

	# 7. The zone graph in play: lazy building, per-pack aggro, door
	# seals, room clears, and the fog-of-war map state.
	await _test_graph_walk_darkwood()
	if _failed:
		return

	# 7b. Fangmaw's Hollow: adds, pre-boss beat, act-scaled boss, the
	# locked east door, loot.
	await _test_fangmaw()
	if _failed:
		return

	# 7c. Marsh: merchant camp, fast travel, death -> last safe room +
	# death-room reset.
	await _test_marsh_death_and_travel()
	if _failed:
		return

	# 8. Morwen.
	await _test_morwen()
	if _failed:
		return

	# 9-10. Vargoth: enrage, death/boss-reset, victory.
	await _test_vargoth_victory()
	if _failed:
		return

	# 11. Title screen + resume on a fresh boot. Uses only the scratch
	# slot — real saves on this machine are listed but never touched.
	get_tree().paused = false
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	var visited_at_save := game.visited.size()
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	add_child(game)
	await _frames(10)
	if not (game.menus.is_open() and game.menus.current == "title"):
		return _fail("title screen did not open when saves exist")
	game.menus.close()
	game.load_save(SaveGame.MAX_SLOTS)
	await _frames(5)
	if game.player.cls != "warrior" or game.quest_key != "done":
		return _fail("resume did not restore the finished character")
	if not game.boss_done.get("vargoth", false):
		return _fail("resume lost boss progress")
	if not game.merchant_zones.has(0):
		return _fail("village merchant missing after resume")
	if game.visited.size() != visited_at_save:
		return _fail("resume lost the charted map (%d vs %d rooms)" % [game.visited.size(), visited_at_save])
	if not game.cleared.get(2, false):
		return _fail("resume lost cleared-room state")
	if game.room_at_pos(game.player.global_position) != game.cur_room:
		return _fail("resume put the hero outside the saved room")
	SaveGame.delete(SaveGame.MAX_SLOTS)
	print("ok: title screen + resume from save (map + clears intact)")

	# 12. A second class opening end-to-end: assassin, temptation path.
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("assassin")
	await _frames(5)
	await _skip_dialogue()  # narration up to the carter's question
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("assassin opening offered no decision")
	game.hud._choose(1)  # keep what you took
	await _frames(2)
	if game.player.resonance != -12.0 or not game.get_flag("kept_taking", false):
		return _fail("assassin choice did not apply (res %.0f)" % game.player.resonance)
	await _skip_dialogue()
	print("ok: assassin opening (temptation path)")

	# 13. The Paladin and Warlock openings — live now that the classes are.
	for spec in [["paladin", "delivered_verdict"], ["warlock", "closed_tome"]]:
		game.queue_free()
		await _frames(3)
		game = main_scene.instantiate()
		game.no_saves = true
		add_child(game)
		await _frames(10)
		game.menus.pick_chapter("ch1")
		await _frames(2)
		game.menus.pick_class(spec[0])
		await _frames(5)
		await _skip_dialogue()
		await _frames(2)
		if not game.hud.choices_active:
			return _fail("%s opening offered no decision" % spec[0])
		game.hud._choose(0)  # the virtue path
		await _frames(2)
		if not game.get_flag(spec[1], false):
			return _fail("%s opening flag '%s' not set" % [spec[0], spec[1]])
		await _skip_dialogue()
		print("ok: %s opening (virtue path)" % spec[0])

	# 14. Chapter 2 boots into its hub — as a legacy chapter it converts
	# to a west→east chain of rooms.
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch2")
	await _frames(3)
	if game.chapter_id != "ch2" or game.zone_count < 1:
		return _fail("chapter 2 did not build (chapter=%s zones=%d)" % [game.chapter_id, game.zone_count])
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if game.zones[0]["name"] != "Maren's Camp":
		return _fail("chapter 2 hub zone missing")
	# Legacy conversion: a one-row chain with east/west doors.
	if Vector2i(game.rooms[0]["coord"]) != Vector2i(0, 0) or game.neighbor(0, "E") != 1:
		return _fail("legacy chapter did not convert to a chain")
	var hub_hostiles := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 0:
			hub_hostiles += 1
	if hub_hostiles != 0:
		return _fail("chapter 2 hub should be safe (found %d hostiles)" % hub_hostiles)
	if not game.merchant_zones.has(0):
		return _fail("chapter 2 hub merchant missing")
	print("ok: chapter 2 hub boots as a legacy chain (%d room[s])" % game.zone_count)

	# ---- CONTENT-MODULE TEST HOOK ----------------------------------------
	# T1/T2/T3/T5/T6: append your _test_*() func at the END of this file
	# and add exactly ONE `await _test_yourthing()` line here.
	await _test_ch2_hub()
	await _test_ch2_factions()
	await _test_ch2_aldric()
	await _test_ch2_act1()
	await _test_ch2_act2()
	await _test_ch2_resonance()
	await _test_pause_menu()
	# -----------------------------------------------------------------------
	await _test_ch2_bosses()
	await _test_chapter_progression()

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)


## (1b) The Chapter 1 room graph: structural rules from DESIGN.md.
func _test_room_graph() -> void:
	var n := game.zone_count
	if n < 20 or n > 30:
		return _fail("chapter size out of bounds: %d rooms (want 20-30)" % n)
	if game.coord_to_room.size() != n:
		return _fail("room grid coords are not unique")
	# Reciprocity + valid neighbors (also enforced at load; verify).
	for i in n:
		for dir in game.rooms[i]["exits"].keys():
			var nb: int = game.neighbor(i, String(dir))
			if nb < 0:
				return _fail("room %d exit %s leads nowhere" % [i, dir])
			if not game.rooms[nb]["exits"].has(Game.OPP[dir]):
				return _fail("room %d exit %s not reciprocated by %d" % [i, dir, nb])
	# Reachability (locks ignored — they open in play).
	var seen := {0: true}
	var queue := [0]
	while not queue.is_empty():
		var cur: int = queue.pop_back()
		for dir in game.rooms[cur]["exits"].keys():
			var nb: int = game.neighbor(cur, String(dir))
			if nb >= 0 and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	if seen.size() != n:
		return _fail("unreachable rooms: %d of %d reached" % [seen.size(), n])
	# The critical path (village -> final boss) leaves 40-50% of rooms
	# as optional wings; assert at least a third are off it.
	var final_room := -1
	var final_kind := String(Story.chapter("ch1").get("final_boss", ""))
	for i in n:
		if String(game.zones[i].get("boss", "")) == final_kind:
			final_room = i
	if final_room < 0:
		return _fail("final boss room missing")
	var prev := {0: -1}
	var q2 := [0]
	while not q2.is_empty():
		var cur2: int = q2.pop_front()
		for dir in game.rooms[cur2]["exits"].keys():
			var nb2: int = game.neighbor(cur2, String(dir))
			if nb2 >= 0 and not prev.has(nb2):
				prev[nb2] = cur2
				q2.append(nb2)
	var path_len := 0
	var walk := final_room
	while walk != -1:
		path_len += 1
		walk = prev[walk]
	if n - path_len < int(n * 0.33):
		return _fail("too few side rooms: path %d of %d rooms" % [path_len, n])
	# The palette is present: every declared type appears.
	var have_types := {}
	for i in n:
		have_types[game.room_type(i)] = true
	for want in ["safe", "combat", "boss", "social", "resonance", "dead_end", "merchant"]:
		if not have_types.has(want):
			return _fail("room palette missing a '%s' room" % want)
	# Only the starting room is built at boot (rooms build lazily).
	if game.built.size() != 1 or not game.built.get(0, false):
		return _fail("rooms did not build lazily (%d built at boot)" % game.built.size())
	# Spine rooms stay adjacent in story order (the seeded walk is unbroken).
	var spine: Array = Story.chapter("ch1").get("spine", [])
	for k in range(1, spine.size()):
		if _dir_between(int(spine[k - 1]), int(spine[k])) == "":
			return _fail("spine break between rooms %d and %d" % [spine[k - 1], spine[k]])
	# Layouts are SEEDED: another seed lays another map, and the same
	# seed always lays the same one (saves must reload their world).
	var sig_a := _layout_sig()
	var seed_keep := game.wander_seed
	var differs := false
	for bump in [1, 2]:
		game.wander_seed = seed_keep + bump
		game.switch_chapter("ch1", true)
		if _layout_sig() != sig_a:
			differs = true
			break
	game.wander_seed = seed_keep
	game.switch_chapter("ch1", true)
	if not differs:
		return _fail("layout ignored the seed (every run identical)")
	if _layout_sig() != sig_a:
		return _fail("layout not deterministic for a seed")
	print("ok: room graph (%d rooms, %d on the boss path, seeded layout, lazy build)" % [n, path_len])


## (7) Darkwood: lazy build on entry, calm packs, per-pack aggro, door
## seals while hot, clears; then the side rooms (cache, social, shrine).
func _test_graph_walk_darkwood() -> void:
	_buff()
	# Entering the Darkwood Road builds it and wakes NOBODY.
	if game.built.get(2, false):
		return _fail("room 2 built before anyone entered it")
	await _goto_room(2)
	if not game.built.get(2, false):
		return _fail("room 2 did not build on entry")
	var mobs := _room_mobs(2)
	if mobs.size() != 10:
		return _fail("Darkwood Road pack count wrong (%d)" % mobs.size())
	for e in mobs:
		if e.force_aggro or e.alerted:
			return _fail("entering a room should wake nobody (per-pack aggro)")
	# Purge rule: an uncleared room seals its doors the moment you step
	# in — living packs bar the way even before anything aggroes.
	if not game.barrier_active:
		return _fail("uncleared room did not seal its doors (purge rule)")
	# Wound one member of pack 0: its whole pack answers, pack 1 sleeps.
	var pack0_member: Enemy = null
	for e in mobs:
		if e.pack_id == 0:
			pack0_member = e
	pack0_member.take_damage(1.0)
	await _frames(3)
	for e in _room_mobs(2):
		if e.pack_id == 0 and not e.force_aggro:
			return _fail("pack 0 did not wake together")
		if e.pack_id == 1 and e.force_aggro:
			return _fail("pack 1 woke from across the room")
	if not game.barrier_active:
		return _fail("door seals did not close on an aggroed pack")
	# Clear the room: seals lift, the room stays cleared.
	await _kill_room(2)
	await _frames(5)
	if game.barrier_active:
		return _fail("door seals did not lift after the clear")
	if not game.cleared.get(2, false):
		return _fail("room 2 not marked cleared")
	print("ok: darkwood road (lazy build, per-pack aggro, door seals, clear)")

	# Doorway transit is REAL: physically WALK through a doorway (no
	# teleport) — proves the wall gap, the ground-art opening and the
	# room transition all line up, whatever direction the seeded layout
	# chose (playtest round 3 regression: N/S doors were painted shut).
	var walk_dir := ""
	var walk_target := -1
	for d in game.rooms[2]["exits"].keys():
		var cand := game.neighbor(2, String(d))
		if cand > 0 and not game.gates.has(game._edge_key(2, cand)):
			walk_dir = String(d)
			walk_target = cand
			break
	if walk_dir == "":
		return _fail("darkwood road has no open onward door")
	game.player.global_position = game.door_pos(2, walk_dir) \
		- Vector2(Game.DIRS[walk_dir]) * 70.0
	var walk_key: int = {"N": KEY_W, "S": KEY_S, "E": KEY_D, "W": KEY_A}[walk_dir]
	var w_down := InputEventKey.new()
	w_down.keycode = walk_key
	w_down.physical_keycode = walk_key
	w_down.pressed = true
	Input.parse_input_event(w_down)
	var walked := 0
	while game.cur_room != walk_target and walked < 240:
		await _frames(1)
		walked += 1
	var w_up := InputEventKey.new()
	w_up.keycode = walk_key
	w_up.physical_keycode = walk_key
	w_up.pressed = false
	Input.parse_input_event(w_up)
	if game.cur_room != walk_target:
		return _fail("could not WALK through the %s doorway (gap blocked?)" % walk_dir)
	print("ok: doorway walk-through (%s door is passable, not painted shut)" % walk_dir)

	# Side room: the Hollow Oak — a guarded cache, once per character.
	await _goto_room(3)
	await _kill_room(3)
	var bag_before := game.player.backpack.size()
	var gold_before := game.player.gold
	game.player.global_position = game.room_center(3) + Vector2(0, -140)
	await _frames(10)
	if game.player.backpack.size() <= bag_before and game.player.gold <= gold_before:
		return _fail("dead-end cache gave nothing")
	if not game.get_flag(game._cache_flag(3), false):
		return _fail("cache flag not set (would refarm on reload)")
	print("ok: dead-end cache (guarded, once per character)")

	# Side room: the social clearing rolls a wanderer from the pool.
	var before_npcs := game.interactables.size()
	await _goto_room(5)
	if game.interactables.size() <= before_npcs:
		return _fail("social room rolled no wanderer")
	var w_entry: Dictionary = game.interactables[-1]
	w_entry["action"].call()
	await _frames(2)
	# A wanderer convo may OPEN on a choice node (tinker, orphan...) —
	# that's choices_active, not dialogue_active.
	if not game.hud.dialogue_active and not game.hud.choices_active:
		return _fail("wanderer had nothing to say")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	print("ok: social room (pool wanderer talks)")

	# Side room: the Moonwell shrine moves Resonance between story beats.
	await _goto_room(8)
	var shrine := _find_action("E — The Moonwell")
	if not shrine.is_valid():
		return _fail("the Moonwell is missing")
	var res_b := game.player.resonance
	shrine.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("the shrine offered no choice")
	game.hud._choose(0)  # give freely: +8
	await _frames(2)
	await _skip_dialogue()
	if game.player.resonance <= res_b or not game.get_flag("moonwell_touched", false):
		return _fail("shrine choice did not move resonance")
	shrine.call()  # revisit: the pool is quiet now (variant short-circuit)
	await _frames(2)
	if game.hud.choices_active:
		return _fail("shrine re-offered its choice")
	await _skip_dialogue()
	print("ok: resonance shrine (+8, once)")

	# Fog of war: walked rooms are charted, the rest are not.
	for i in [0, 2, 3, 5, 8]:
		if not game.visited.get(i, false):
			return _fail("room %d missing from the map" % i)
	if game.visited.get(16, false) or game.built.get(16, false):
		return _fail("unexplored rooms leaked onto the map / got built")
	print("ok: fog of war (visited-only map state)")


## (7b) Fangmaw's Hollow: adds first, then the pre-boss beat, an
## act-scaled boss, the barred east door, and boss loot.
func _test_fangmaw() -> void:
	_buff()
	await _goto_room(7)  # Deep Darkwood first: SEE the boss door
	if not game.door_seen.get(9, false):
		return _fail("boss door not marked seen from the room next door")
	await _goto_room(9)
	if game._edge_unlocked(9, 10):
		return _fail("the road past Fangmaw should be barred")
	await _kill_room(9)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for fangmaw did not open after clearing")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss):
		return _fail("fangmaw did not spawn")
	if game.current_boss.level != 5:
		return _fail("fangmaw not act-scaled (level %d)" % game.current_boss.level)
	print("ok: room cleared -> fangmaw spawned (Lv %d)" % game.current_boss.level)

	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	var gold_before := game.player.gold
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("post-boss dialogue for fangmaw did not open")
	await _skip_dialogue()
	await _frames(5)
	if not game._edge_unlocked(9, 10):
		return _fail("fangmaw's death did not unbar the way onward")
	if game.barrier_active:
		return _fail("door seals did not lift after fangmaw died")
	# Walk onto the drop pile: the gold coins magnet in.
	game.player.global_position = game.room_center(9) + Vector2(ROOM_HALF_X, 0)
	await _frames(30)
	if game.player.gold <= gold_before:
		return _fail("fangmaw dropped no gold")
	print("ok: fangmaw killed + loot (gate opened)")


const ROOM_HALF_X := 620.0  # boss arena drop pile sits east of center


## (7c) Marsh: the merchant camp, fast travel from the map, and death →
## last safe room with the death room resetting.
func _test_marsh_death_and_travel() -> void:
	_buff()
	# Stilt Camp: a merchant-typed safe pocket with silver stock.
	await _goto_room(11)
	var shop := _find_action("E — Shop")
	if not shop.is_valid():
		return _fail("stilt camp merchant missing")
	game.menus.open_shop(11)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[11].size() != 3:
		return _fail("stilt camp shop did not stock")
	game.menus.close()
	await _frames(2)
	if game.last_safe_room != 11:
		return _fail("safe room tracking missed the stilt camp (got %d)" % game.last_safe_room)

	# Fast travel: merchant camp -> village and back (visited safe rooms).
	if not game.travel_target(0):
		return _fail("village should be a travel target")
	if game.travel_target(2):
		return _fail("combat rooms must never be travel targets")
	game.fast_travel(0)
	await _frames(3)
	if game.cur_room != 0:
		return _fail("fast travel to the village failed")
	game.fast_travel(11)
	await _frames(3)
	if game.cur_room != 11:
		return _fail("fast travel back to the stilt camp failed")
	print("ok: fast travel (village <-> stilt camp; combat rooms excluded)")

	# Death: wound a pack in the Marsh Gate, die, wake up at the camp,
	# and the marsh room resets behind you.
	await _goto_room(10)
	var marsh_mobs := _room_mobs(10)
	if marsh_mobs.size() != 10:
		return _fail("marsh gate pack count wrong (%d)" % marsh_mobs.size())
	marsh_mobs[0].take_damage(1.0)
	await _frames(3)
	if not game.barrier_active:
		return _fail("marsh fight did not seal the doors")
	game.player.hurt_cd = 0.0
	game.player.max_hp = 100.0
	game.player.hp = 1.0
	game.player.eva = 0.0
	game.player.take_damage(999999.0, "true")
	if not game.player.dead:
		return _fail("player did not die")
	var guard := 0
	while game.player.dead and guard < 400:
		await _frames(5)
		guard += 1
	if game.player.dead:
		return _fail("player did not respawn")
	if game.cur_room != 11:
		return _fail("death did not return to the last safe room (got %d)" % game.cur_room)
	# The death room reset: full pack, everyone calm again.
	var reset_mobs := _room_mobs(10)
	if reset_mobs.size() != 10:
		return _fail("death room did not respawn its packs (%d)" % reset_mobs.size())
	for e in reset_mobs:
		if e.force_aggro or e.alerted:
			return _fail("respawned packs should wake calm")
	_buff()
	print("ok: death -> last safe room + death room reset")


## (8) Morwen's Bower.
func _test_morwen() -> void:
	_buff()
	await _goto_room(16)
	await _kill_room(16)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for morwen did not open")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "morwen":
		return _fail("morwen did not spawn")
	if game.current_boss.level != 8:
		return _fail("morwen not act-scaled (level %d)" % game.current_boss.level)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("post-boss dialogue for morwen did not open")
	await _skip_dialogue()
	await _frames(5)
	if not game._edge_unlocked(16, 17):
		return _fail("morwen's death did not unbar the way onward")
	print("ok: morwen killed (Lv 8, gate opened)")


## (9-10) The Hollow Throne: enrage, death/boss-reset, victory.
func _test_vargoth_victory() -> void:
	_buff()
	await _goto_room(24)
	await _kill_room(24)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for vargoth did not open")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "vargoth":
		return _fail("vargoth did not spawn")
	if game.current_boss.level != 12:
		return _fail("vargoth not act-scaled (level %d)" % game.current_boss.level)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	game.current_boss.take_damage(game.current_boss.hp - game.current_boss.max_hp * 0.2)
	await _frames(40)
	if not game.current_boss.enraged:
		return _fail("vargoth did not enrage")
	print("ok: vargoth enrage")
	# Die to him: the fight resets, the hero wakes at the last safe camp.
	game.player.hurt_cd = 0.0
	game.player.max_hp = 100.0
	game.player.hp = 1.0
	game.player.eva = 0.0
	game.player.take_damage(999999.0, "true")
	if not game.player.dead:
		return _fail("player did not die")
	await _frames(20)
	var guard := 0
	while game.player.dead and guard < 400:
		await _frames(5)
		guard += 1
	if game.player.dead:
		return _fail("player did not respawn")
	if game.current_boss.hp < game.current_boss.max_hp:
		return _fail("boss did not reset after player death")
	if not game.room_safe(game.cur_room):
		return _fail("death respawn landed somewhere unsafe (room %d)" % game.cur_room)
	print("ok: death, respawn at safe room, boss reset")
	_buff()
	await _goto_room(24)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(10)
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("epilogue did not open after vargoth")
	await _skip_dialogue()
	await _frames(10)
	if game.state != Game.ST_VICTORY:
		return _fail("no victory state after final boss")
	print("ok: vargoth killed + victory screen")


## (T1) Maren's camp hub: briefing reads the common opening flags, sets
## the quest + gate flag, and short-circuits on repeat visits.
func _test_ch2_hub() -> void:
	# Runs right after section 14: a ch2 warrior standing in the camp.
	if not game.get_flag("chose_virtue", false):
		return _fail("opening did not set the common chose_virtue flag")
	var maren_action := _find_action("E — Maren")
	if not maren_action.is_valid():
		return _fail("Maren NPC missing from the camp")
	maren_action.call()
	await _frames(2)
	if not game.hud.dialogue_active:
		return _fail("Maren briefing did not open")
	if not ("chose BACK" in game.hud.text_label.text):
		return _fail("Maren did not read the opening choice (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()  # m1 + m2 -> m3 presents the choices
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Maren briefing offered no choices")
	game.hud._choose(0)  # "point me east"
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("ch2_briefed", false) or game.quest_key != "ch2_act1":
		return _fail("briefing did not set flag/quest (quest=%s)" % game.quest_key)
	if not game._edge_unlocked(0, 1):
		return _fail("the briefing flag did not unbar the camp's east road")
	# Repeat visit: the variant-next short-circuit, no choices re-offered.
	maren_action.call()
	await _frames(2)
	if not game.hud.dialogue_active or not ("East, shard-bearer" in game.hud.text_label.text):
		return _fail("repeat Maren visit did not short-circuit")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		return _fail("repeat Maren visit re-offered the briefing choices")
	print("ok: T1 hub (Maren briefing reads flags, quest set, short-circuit)")


## (T5) Faction arcs: joining is exclusive, standings shift, the ambient
## factions keep score without recruiting.
func _test_ch2_factions() -> void:
	var acts := {}
	for entry in game.interactables:
		acts[entry["prompt"].text] = entry["action"]
	for needed in ["E — Accord", "E — Cinderborn", "E — The Cage", "E — Pilgrim"]:
		if not acts.has(needed):
			return _fail("faction NPC '%s' missing from the camp" % needed)

	# Join the Accord.
	var accord_before: int = game.player.faction_standing["accord"]
	acts["E — Accord"].call()
	await _frames(2)
	await _skip_dialogue()  # the pitch
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Accord recruiter offered no choices")
	game.hud._choose(0)  # join
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("joined_accord", false) or not game.get_flag("faction_chosen", false):
		return _fail("joining the Accord did not set its flags")
	if game.player.faction_standing["accord"] != accord_before + 20:
		return _fail("Accord standing wrong (%d)" % game.player.faction_standing["accord"])
	if game.player.faction_standing["cinderborn"] != -10:
		return _fail("joining Accord should cost Cinderborn standing")
	if game.quest_key != "ch2_accord1":
		return _fail("Accord arc quest not set (got %s)" % game.quest_key)

	# The rival now brushes you off — and offers NO join.
	acts["E — Cinderborn"].call()
	await _frames(2)
	if not ("got to you first" in game.hud.text_label.text):
		return _fail("Cinderborn did not react to the Accord join")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		return _fail("Cinderborn still offered choices after exclusivity")

	# Wildfang: free the caged scout.
	var wf_before: int = game.player.faction_standing["wildfang"]
	acts["E — The Cage"].call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("cage encounter offered no choices")
	game.hud._choose(0)  # open the cage
	await _frames(2)
	await _skip_dialogue()
	if game.player.faction_standing["wildfang"] != wf_before + 10:
		return _fail("freeing the scout did not raise Wildfang standing")
	acts["E — The Cage"].call()
	await _frames(2)
	if not ("empty" in game.hud.text_label.text):
		return _fail("cage encounter did not resolve permanently")
	await _skip_dialogue()

	# Choir: hear the litany.
	var ch_before: int = game.player.faction_standing["choir"]
	acts["E — Pilgrim"].call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("pilgrim offered no choices")
	game.hud._choose(0)  # listen
	await _frames(2)
	await _skip_dialogue()
	if game.player.faction_standing["choir"] != ch_before + 6:
		return _fail("the litany did not raise Choir standing")
	print("ok: T5 factions (exclusive join, standings, ambient Wildfang/Choir)")


## (T6) Aldric: hub-and-spokes lore, act-progress gate, the buried truth.
func _test_ch2_aldric() -> void:
	var aldric := _find_action("E — Ser Aldric")
	if not aldric.is_valid():
		return _fail("Aldric missing from the camp")
	aldric.call()
	await _frames(2)
	await _skip_dialogue()  # greeting -> the question hub
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Aldric offered no questions")
	# ch2_briefed is set, blight_scouted is NOT: expect 3 options
	# (cost question, crown question, leave) — the secret stays hidden.
	if game.hud.choice_count != 3:
		return _fail("Aldric question count wrong pre-act (%d)" % game.hud.choice_count)
	game.hud._choose(0)  # what did it cost
	await _frames(2)
	await _skip_dialogue()  # part 1 -> back at the hub
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Aldric hub did not loop back after an answer")
	game.hud._choose(2)  # leave
	await _frames(2)
	await _skip_dialogue()
	# Act progress (T2 will set this in play): the secret unlocks.
	game.set_flag("blight_scouted")
	aldric.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choice_count != 4:
		return _fail("Aldric secret did not unlock with act progress (%d)" % game.hud.choice_count)
	game.hud._choose(2)  # what he never told Maren
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.get_flag("aldric_truth", false):
		return _fail("hearing the secret did not set aldric_truth")
	if game.hud.choices_active:
		game.hud._choose(game.hud.choice_count - 1)  # leave
		await _frames(2)
		await _skip_dialogue()
	game.flags.erase("blight_scouted")  # leave T2's flag pristine
	print("ok: T6 Aldric (question hub, act gate, the truth)")


## (T2) Act 1: four rooms east of the camp, arc flags, act-scaled
## bosses, quest chain — now walked through the graph.
func _test_ch2_act1() -> void:
	if game.zone_count < 5:
		return _fail("act 1 zones did not append (zones=%d)" % game.zone_count)
	_buff()
	if not game._edge_unlocked(0, 1):
		return _fail("camp gate should already be open (briefing flag)")
	await _goto_room(1)

	# Sera's blue door + the fallen courier.
	var mill := _find_action("E — The Mill")
	var courier := _find_action("E — A Fallen Courier")
	if not mill.is_valid() or not courier.is_valid():
		return _fail("Greyrun landmarks missing")
	mill.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if not game.get_flag("mill_seen", false):
		return _fail("the blue door went unrecorded")
	courier.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("courier offered no choices")
	game.hud._choose(0)  # accord member: 'pocket the seal' (Vessa option hidden)
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("relic_recovered", false):
		return _fail("courier seal not recovered")

	# Clear the Mills: bossless clear sets blight_scouted + opens the way.
	await _kill_room(1)
	if not game.get_flag("blight_scouted", false):
		return _fail("clearing the Mills did not set blight_scouted")
	if not game._edge_unlocked(1, 2):
		return _fail("Mills gate did not open on clear")

	# The Howling Fields: warband falls, the Stormwarden comes act-scaled.
	await _goto_room(2)
	await _kill_room(2)
	var guard := 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "stormwarden":
		return _fail("Stormwarden did not spawn after the Fields cleared")
	if game.current_boss.level != 8:
		return _fail("Stormwarden not act-scaled (level %d)" % game.current_boss.level)
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	if game.hud.dialogue_active:
		await _skip_dialogue()
	await _frames(5)
	if game.quest_key != "choirmother":
		return _fail("quest did not advance past the Stormwarden (got %s)" % game.quest_key)
	if not game._edge_unlocked(2, 3):
		return _fail("Fields gate did not open")

	# Sporewood clear, then Choir's Hollow and its Mother end the act.
	await _goto_room(3)
	await _kill_room(3)
	if not game.get_flag("sporewood_cleared", false) or not game._edge_unlocked(3, 4):
		return _fail("Sporewood clear did not open the way")
	await _goto_room(4)
	await _kill_room(4)
	guard = 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "choirmother":
		return _fail("Choir Mother did not spawn")
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	if game.hud.dialogue_active:
		await _skip_dialogue()
	await _frames(5)
	if not game.get_flag("act1_complete", false):
		return _fail("act 1 completion flag not set")
	if game.quest_key != "nullwarden":
		return _fail("quest did not point into Act 2 (got %s)" % game.quest_key)
	print("ok: T2 act 1 (Mills/Fields/Sporewood/Hollow, scaled bosses, arc flags)")


## (T3) Act 2: four crossings, the scholar, and the chapter's end.
func _test_ch2_act2() -> void:
	if game.zone_count != 10:
		return _fail("act 2 zones did not append (zones=%d)" % game.zone_count)
	_buff()
	# The four bossless crossings: clear each, its way east must open.
	for zi in [5, 6, 7, 8]:
		await _goto_room(zi)
		await _kill_room(zi)
		if not game._edge_unlocked(zi, zi + 1):
			return _fail("room %d gate did not open on clear" % zi)
	# The scholar in the Deeps.
	var scholar := _find_action("E — A Scholar")
	if not scholar.is_valid():
		return _fail("the scholar is missing from the Deeps")
	scholar.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("the scholar offered no question")
	game.hud._choose(0)
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("scholar_met", false):
		return _fail("scholar_met flag not set")
	# The Null Bastion: clear it, the Warden comes act-scaled, chapter ends.
	await _goto_room(9)
	await _kill_room(9)
	var guard := 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "nullwarden":
		return _fail("Warden Null did not spawn")
	if game.current_boss.level != 16:
		return _fail("Warden Null not act-scaled (level %d)" % game.current_boss.level)
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	var vguard := 0
	while game.state != Game.ST_VICTORY and vguard < 200:
		if game.hud.dialogue_active:
			await _skip_dialogue()
		await _frames(5)
		vguard += 5
	if game.state != Game.ST_VICTORY:
		return _fail("chapter 2 did not reach victory")
	if game.quest_key != "done_ch2":
		return _fail("chapter done quest wrong (got %s)" % game.quest_key)
	# Restore a playable state for the tests that follow this hook.
	get_tree().paused = false
	game.state = Game.ST_PLAYING
	await _goto_room(0)
	await _frames(5)
	print("ok: T3 act 2 (crossings, scholar, Warden Null ends the chapter)")


## (T7) Resonance surfaces: merchants haggle by band, NPCs read you.
func _test_ch2_resonance() -> void:
	var res_keep := game.player.resonance
	game.player.resonance = -40.0
	if absf(game.band_price_mult() - 1.1) > 0.001:
		return _fail("tempted haggle mult wrong")
	game.player.resonance = 40.0
	if absf(game.band_price_mult() - 0.9) > 0.001:
		return _fail("steady haggle mult wrong")
	game.player.resonance = 0.0
	if absf(game.band_price_mult() - 1.0) > 0.001:
		return _fail("neutral haggle mult wrong")
	# The tempted shop greeting builds without breaking anything.
	game.player.resonance = -40.0
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open():
		return _fail("shop did not open for a tempted bearer")
	game.menus.close()
	await _frames(1)
	# NPCs read the band: the sentry steps back from the tempted...
	var sentry := _find_action("E — Talk")
	if not sentry.is_valid():
		return _fail("sentry missing for the band test")
	sentry.call()
	await _frames(2)
	if not ("further off" in game.hud.text_label.text):
		return _fail("sentry did not react to the tempted band")
	await _skip_dialogue()
	# ...and Aldric hears the shard leaning in.
	var aldric := _find_action("E — Ser Aldric")
	if aldric.is_valid():
		aldric.call()
	await _frames(2)
	if not ("almost hear it" in game.hud.text_label.text):
		return _fail("Aldric did not react to the tempted band")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(game.hud.choice_count - 1)  # leave
		await _frames(2)
		await _skip_dialogue()
	game.player.resonance = res_keep
	print("ok: T7 resonance surfacing (haggle bands, NPCs read the shard)")


## System menu: pause opens/resumes, audio settings apply, and a chapter
## replay wipes the story while keeping the character.
func _test_pause_menu() -> void:
	# A single real ESC press must open the system menu (regression: a
	# legacy HUD overlay used to eat the first press).
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	var esc_up := InputEventKey.new()
	esc_up.keycode = KEY_ESCAPE
	esc_up.physical_keycode = KEY_ESCAPE
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	if not (game.menus.is_open() and game.menus.current == "pause"):
		return _fail("one ESC press did not open the pause menu (got '%s')" % game.menus.current)
	if not get_tree().paused:
		return _fail("pause menu did not pause the game")
	game.menus.close()
	await _frames(1)
	if get_tree().paused:
		return _fail("closing the pause menu did not resume")
	# Audio settings apply to the live players.
	var music_keep: float = game.settings["music"]
	var sfx_keep: float = game.settings["sfx"]
	game.settings["music"] = 0.5
	game.settings["sfx"] = 0.0
	game.apply_audio_settings()
	if absf(game.music_player.volume_db - (game.music_gain_db + linear_to_db(0.5))) > 0.5:
		return _fail("music volume not applied (%.1f dB)" % game.music_player.volume_db)
	if game.sound_pool[0].volume_db > -80.0:
		return _fail("sfx mute not applied")
	game.settings["music"] = music_keep
	game.settings["sfx"] = sfx_keep
	game.apply_audio_settings()
	# Chapter replay: story state resets, the character does not.
	var lvl: int = game.player.level
	var res: float = game.player.resonance
	var seed_before: int = game.wander_seed
	game.set_flag("blight_scouted")
	game.replay_chapter("ch2")
	await _frames(5)
	if game.get_flag("blight_scouted", false):
		return _fail("chapter replay kept story flags")
	if not game.get_flag("chose_virtue", false):
		return _fail("chapter replay wiped the character's opening history")
	if game.player.level != lvl or game.player.resonance != res:
		return _fail("chapter replay touched the character build")
	if game.quest_key != "ch2_start" or game.zone_count != 10:
		return _fail("chapter replay world wrong (quest=%s zones=%d)" % [game.quest_key, game.zone_count])
	if game.player.faction_standing["accord"] != 0 or game.get_flag("joined_accord", false):
		return _fail("chapter replay should reset faction commitments")
	if not quick and game.wander_seed == seed_before:
		return _fail("chapter replay did not re-roll the seeded rooms")
	if game.visited.size() != 1 or not game.visited.get(0, false):
		return _fail("chapter replay did not reset the charted map")
	print("ok: pause menu (pause/resume, audio settings, chapter replay)")


## (T4) Chapter 2 bosses: spawn, signature move, enrage threshold, and a
## story-neutral death for each content boss (the module's own kill-flow
## selftest — runs in the ch2 hub the previous section booted into).
func _test_ch2_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch2_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		# quit(1) lands at frame end; never resume, or _run would print
		# AUTOTEST PASS and quit(0) over the failure.
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch2 bosses (spawn / signature / enrage / story-neutral death) — stormwarden, choirmother, nullwarden")


## Chapter PROGRESSION: a ch1 victory carries the character into ch2
## (build/gold intact, world rebuilt, unpaused), the completion flag
## survives, and the finished chapter stays available for farming.
func _test_chapter_progression() -> void:
	game.replay_chapter("ch1")
	await _frames(10)
	if game.chapter_id != "ch1":
		return _fail("could not return to ch1 for the progression test")
	var lvl: int = game.player.level
	var gold: int = game.player.gold
	# Simulate the ch1 victory card, then press on.
	game.state = Game.ST_VICTORY
	get_tree().paused = true
	game.set_flag("completed_ch1", true)
	game.advance_chapter()
	await _frames(10)
	if game.chapter_id != "ch2":
		return _fail("advance_chapter did not carry on to ch2")
	if game.state != Game.ST_PLAYING or get_tree().paused:
		return _fail("advance_chapter left the game frozen")
	if game.player.level != lvl or game.player.gold != gold:
		return _fail("progression did not keep the character (Lv %d -> %d)" % [lvl, game.player.level])
	if not game.get_flag("completed_ch1", false):
		return _fail("chapter completion flag was wiped by the advance")
	if not game.chapter_available("ch2", true):
		return _fail("finished chapter did not unlock ch2 for this character")
	if game.quest_key != "ch2_start":
		return _fail("ch2 did not start its quest chain (got %s)" % game.quest_key)
	print("ok: chapter progression (victory carries the hero into ch2; ch1 stays farmable)")
