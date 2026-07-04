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

	# 1. Class select -> intro.
	if not (game.menus.is_open() and game.menus.current == "class_select"):
		return _fail("class select did not open")
	game.menus.pick_class("warrior")
	await _frames(5)
	if not game.hud.dialogue_active:
		return _fail("intro dialogue did not open after class select")
	await _skip_dialogue()
	print("ok: class select + intro")
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
	await _skip_dialogue()
	await _frames(2)
	if game.gates[0] != null:
		return _fail("gate 0 did not open after elder talk")
	print("ok: elder talk + gate 0")

	# 3. Fire every ability of every class against dummy wolves.
	game.player.global_position = Vector2(900, 360)
	await _frames(5)
	for cls in Classes.CLASSES:
		game.player.set_class(cls)
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
	await _frames(90)  # knife flight + bloom + first mist ticks
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
	if boss_hi["hp"] / Story.ENEMIES["fangmaw"]["hp"] <= w_hi["hp"] / Story.ENEMIES["wolf"]["hp"]:
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
	var kept_quest: String = game.quest_key
	var kept_level: int = p.level
	var kept_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	var kept_atk: float = p.atk
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	p.gold = 0
	p.resonance = 0.0
	p.faction_standing["cinderborn"] = 0
	game.quest_key = "talk"
	var loaded := SaveGame.read(SaveGame.MAX_SLOTS)
	if loaded.is_empty():
		return _fail("save file did not write/read")
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
	SaveGame.delete(SaveGame.MAX_SLOTS)
	if SaveGame.exists(SaveGame.MAX_SLOTS):
		return _fail("save delete failed")
	print("ok: save/load roundtrip (gold, resonance, factions, gear, stats)")

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
		var kind: String = Story.ZONES[zi]["boss"]
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
	SaveGame.delete(SaveGame.MAX_SLOTS)
	print("ok: title screen + resume from save")

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)
