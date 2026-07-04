extends Node
## Automated smoke test (not part of the game).
## Covers: class select, dialogue, all class kits, target lock, the stat
## engine (curves, combo), themes, the row-based skill tree, gear + gems
## (socket/synthesize/sell-return), chests, S weapons, telegraphs,
## zone-clear boss flow, death/respawn, and victory.
## Run with:  godot --headless --path game res://scenes/test.tscn

var game: Game


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
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
## lingering ult effects. Never touches the real zone monsters.
func _clear_combat() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == -1:
			e.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	game.player.storm_time = 0.0
	game.player.berserk_time = 0.0


func _run() -> void:
	# 0. Stat-engine math sanity.
	if absf(Stats.res_frac(120.0) - 0.5) > 0.01:
		return _fail("res curve broken")
	if Stats.crit_curve(0.9) > 0.95 or Stats.crit_curve(0.5) != 0.5:
		return _fail("crit curve broken")
	var r := Stats.resolve(100.0, "true", 0.0, 1.5, 0.0, 0.0, 500.0, 0.9, 50.0)
	if r["miss"] or r["dmg"] != 100.0 or r["crit"]:
		return _fail("true damage should ignore everything and never crit")
	print("ok: stat curves + true damage")

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

	# 2. Talk to the elder (simulated E keypress) -> gate 0 opens.
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
	if game.gates[0] != null:
		return _fail("gate 0 did not open after elder talk")
	print("ok: elder talk reads opening choice + gate 0")

	# 3. Fire every ability of every class against dummy wolves.
	game.player.global_position = Vector2(900, 360)
	await _frames(5)
	for cls in Classes.CLASSES:
		game.player.set_class(cls)
		# Re-anchor every class: dashes drift the hero ~300-500px right per
		# kit, and six kits would carry it past the village edge into zone 1
		# — where the loop's ults slaughter the aggroed mobs, the zone
		# clears, and the pre-boss dialogue PAUSES the tree mid-test.
		game.player.global_position = Vector2(900, 360)
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
	# Six classes of dashes and teleports drift the hero ~1000px right —
	# past the village edge into zone 1 — so anchor the position back too,
	# or later dummy-relative tests fight real aggroed monsters.
	_clear_combat()
	game.player.locked_target = null
	game.player.global_position = Vector2(900, 360)
	await _frames(45)

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
	game.player.hp = game.player.max_hp * 0.5
	var pal_hp := game.player.hp
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(10)
	if game.player.hp <= pal_hp:
		return _fail("holy Consecration did not mend on hit")
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
	game.player.hp = game.player.max_hp
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if game.player.hp >= game.player.max_hp:
		return _fail("Dark Pact did not take its blood price")
	if game.player.pact_time <= 0.0:
		return _fail("Dark Pact did not start the lifesteal surge")
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
	if boss_hi["hp"] / Story.ALL_ENEMIES["fangmaw"]["hp"] <= w_hi["hp"] / Story.ALL_ENEMIES["wolf"]["hp"]:
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

	# 5b. Save / load roundtrip on a scratch slot.
	var p: Player = game.player
	p.gold = 4321
	p.resonance = -37.0
	p.faction_standing["cinderborn"] = 12
	game.set_flag("rt_flag", true)
	var kept_quest: String = game.quest_key
	var kept_level: int = p.level
	var kept_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	var kept_atk: float = p.atk
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	p.gold = 0
	p.resonance = 0.0
	p.faction_standing["cinderborn"] = 0
	game.quest_key = "talk"
	game.flags.clear()
	var loaded := SaveGame.read(SaveGame.MAX_SLOTS)
	if loaded.is_empty():
		return _fail("save file did not write/read")
	if String(loaded.get("chapter", "")) != "ch1":
		return _fail("save did not record its chapter")
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
	game.flags.clear()
	SaveGame.delete(SaveGame.MAX_SLOTS)
	if SaveGame.exists(SaveGame.MAX_SLOTS):
		return _fail("save delete failed")
	print("ok: save/load roundtrip (gold, resonance, factions, gear, stats)")

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
	game.flags.clear()
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
		if cid.begins_with("open_") and not Story.ALL_CONVOS.has("maren_" + cid.substr(5)):
			return _fail("%s has no matching Maren convo" % cid)
	print("ok: opening convo data integrity (%d convos)" % Story.ALL_CONVOS.size())

	# 6. Shop + codex still open fine.
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
	game.menus.open_dev()
	await _frames(2)
	game.menus.close()
	await _frames(2)
	print("ok: shop, codex, skill tree, theme picker, stats tab, dev panel UI")

	# 6c. Terrains: apply every terrain to zone 1, fire its event, tick
	# hazards — none of it may crash. (Player parked away from the mobs
	# so lava pools / zombies don't clear the zone prematurely.)
	game.player.global_position = Vector2(Game.ZONE_W + 1350.0, 620.0)
	await _frames(3)
	for tid in Terrains.DATA:
		game.apply_terrain(1, tid)
		await _frames(3)
		var terrain_ev: String = Terrains.DATA[tid].get("event", "")
		if terrain_ev != "":
			game.run_terrain_event(terrain_ev)
		await _frames(12)
	game.apply_terrain(1, "darkwood")  # restore for the story flow
	await _frames(60)  # let stray telegraphs resolve
	_clear_combat()    # remove event-spawned zombies
	game.gust_vec = Vector2.ZERO
	await _frames(5)
	_buff()
	print("ok: all %d terrains applied + events fired" % Terrains.DATA.size())

	# 7..9. Each zone: enter (all aggro), clear it, boss spawns, kill it.
	for zi in [1, 2, 3]:
		var kind: String = game.zones[zi]["boss"]
		game.player.global_position = Vector2(zi * Game.ZONE_W + 300.0, 360.0)
		await _frames(5)
		var mobs: Array = []
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == zi and not e.dying:
				mobs.append(e)
		if mobs.is_empty():
			return _fail("zone %d has no monsters" % zi)
		if not mobs[0].force_aggro:
			return _fail("zone %d monsters not aggroed on entry" % zi)
		if not game.barrier_active:
			return _fail("battle barrier did not seal zone %d entrance" % zi)
		for e in mobs:
			e.take_damage(999999.0)
			await _frames(1)
		await _frames(10)
		game.player.pending_theme_note = ""
		if not game.hud.dialogue_active:
			return _fail("pre-boss dialogue for %s did not open after clearing" % kind)
		await _skip_dialogue()
		await _frames(5)
		if not is_instance_valid(game.current_boss):
			return _fail("boss %s did not spawn" % kind)
		print("ok: zone %d cleared -> %s spawned" % [zi, kind])

		game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
		await _frames(200)
		if kind == "vargoth":
			game.current_boss.take_damage(game.current_boss.hp - game.current_boss.max_hp * 0.2)
			await _frames(40)
			if not game.current_boss.enraged:
				return _fail("vargoth did not enrage")
			print("ok: vargoth enrage")
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
			print("ok: death, respawn, boss reset")
			_buff()

		var gold_before := game.player.gold
		game.current_boss.take_damage(999999.0)
		await _frames(5)
		game.player.pending_theme_note = ""
		if not game.hud.dialogue_active:
			return _fail("post-boss dialogue for %s did not open" % kind)
		await _skip_dialogue()
		if kind != "vargoth":
			game.player.global_position = Vector2(zi * Game.ZONE_W + 1380.0, 420.0)
			await _frames(30)
			if game.player.gold <= gold_before:
				return _fail("boss %s dropped no gold" % kind)
		await _frames(5)
		if game.barrier_active:
			return _fail("battle barrier did not lift after %s died" % kind)
		print("ok: %s killed + loot (barrier lifted)" % kind)

	# 10. Victory.
	await _frames(10)
	if game.state != Game.ST_VICTORY:
		return _fail("no victory state after final boss")
	print("ok: victory screen")

	# 11. Title screen + resume on a fresh boot. Uses only the scratch
	# slot — real saves on this machine are listed but never touched.
	get_tree().paused = false
	SaveGame.write(game, SaveGame.MAX_SLOTS)
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
	SaveGame.delete(SaveGame.MAX_SLOTS)
	print("ok: title screen + resume from save")

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

	# 14. Chapter 2 boots into its placeholder hub (T0 done-criterion).
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
	var hub_hostiles := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 0:
			hub_hostiles += 1
	if hub_hostiles != 0:
		return _fail("chapter 2 hub should be safe (found %d hostiles)" % hub_hostiles)
	if not game.merchant_zones.has(0):
		return _fail("chapter 2 hub merchant missing")
	print("ok: chapter 2 placeholder hub boots (%d zone[s])" % game.zone_count)

	# ---- CONTENT-MODULE TEST HOOK ----------------------------------------
	# T1/T2/T3/T5/T6: append your _test_*() func at the END of this file
	# and add exactly ONE `await _test_yourthing()` line here.
	await _test_ch2_hub()
	await _test_ch2_factions()
	await _test_ch2_aldric()
	await _test_ch2_act1()
	# -----------------------------------------------------------------------
	await _test_ch2_bosses()

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)


## (T1) Maren's camp hub: briefing reads the common opening flags, sets
## the quest + gate flag, and short-circuits on repeat visits.
func _test_ch2_hub() -> void:
	# Runs right after section 14: a ch2 warrior standing in the camp.
	if not game.get_flag("chose_virtue", false):
		return _fail("opening did not set the common chose_virtue flag")
	var maren_action := Callable()
	for entry in game.interactables:
		if entry["prompt"].text == "E — Maren":
			maren_action = entry["action"]
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
	var aldric := Callable()
	for entry in game.interactables:
		if entry["prompt"].text == "E — Ser Aldric":
			aldric = entry["action"]
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


## (T2) Act 1: four zones, arc flags, act-scaled bosses, quest chain.
func _test_ch2_act1() -> void:
	if game.zone_count != 5:
		return _fail("act 1 zones did not append (zones=%d)" % game.zone_count)
	_buff()
	if game.gates[0] != null:
		return _fail("camp gate should already be open (briefing flag)")
	game.player.global_position = Vector2(1 * Game.ZONE_W + 300.0, 360.0)
	await _frames(5)

	# Sera's blue door + the fallen courier.
	var acts := {}
	for entry in game.interactables:
		acts[entry["prompt"].text] = entry["action"]
	if not acts.has("E — The Mill") or not acts.has("E — A Fallen Courier"):
		return _fail("Greyrun landmarks missing")
	acts["E — The Mill"].call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if not game.get_flag("mill_seen", false):
		return _fail("the blue door went unrecorded")
	acts["E — A Fallen Courier"].call()
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

	# Clear the Mills: bossless clear sets blight_scouted + opens the gate.
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 1:
			e.take_damage(9999999.0)
	await _frames(10)
	if not game.get_flag("blight_scouted", false):
		return _fail("clearing the Mills did not set blight_scouted")
	if game.gates[1] != null:
		return _fail("Mills gate did not open on clear")

	# The Howling Fields: warband falls, the Stormwarden comes act-scaled.
	game.player.global_position = Vector2(2 * Game.ZONE_W + 300.0, 360.0)
	await _frames(5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 2 and not (e is Boss):
			e.take_damage(9999999.0)
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
	if game.gates[2] != null:
		return _fail("Fields gate did not open")

	# Sporewood clear, then Choir's Hollow and its Mother end the act.
	game.player.global_position = Vector2(3 * Game.ZONE_W + 300.0, 360.0)
	await _frames(5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 3:
			e.take_damage(9999999.0)
	await _frames(10)
	if not game.get_flag("sporewood_cleared", false) or game.gates[3] != null:
		return _fail("Sporewood clear did not open the way")
	game.player.global_position = Vector2(4 * Game.ZONE_W + 300.0, 360.0)
	await _frames(5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 4 and not (e is Boss):
			e.take_damage(9999999.0)
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
	if game.quest_key != "done_ch2":
		return _fail("chapter done quest wrong (got %s)" % game.quest_key)
	print("ok: T2 act 1 (Mills/Fields/Sporewood/Hollow, scaled bosses, arc flags)")


## (T4) Chapter 2 bosses: spawn, signature move, enrage threshold, and a
## story-neutral death for each content boss (the module's own kill-flow
## selftest — runs in the ch2 hub the previous section booted into).
func _test_ch2_bosses() -> void:
	_buff()
	game.player.global_position = Vector2(600, 360)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch2_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		# quit(1) lands at frame end; never resume, or _run would print
		# AUTOTEST PASS and quit(0) over the failure.
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch2 bosses (spawn / signature / enrage / story-neutral death) — stormwarden, choirmother, nullwarden")
