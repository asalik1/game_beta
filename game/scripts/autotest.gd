extends Node
## Automated smoke test (not part of the game).
## Plays through the whole game: picks a class, fires every ability of
## every class, opens chests, equips gear, spends skill points, checks
## the shop, kills all three bosses, evolves, dies once, and wins.
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


func _handle_evolution() -> void:
	if game.menus.current == "evolution":
		var evos: Dictionary = Classes.CLASSES[game.player.cls]["evolutions"]
		game.menus.pick_evolution(evos.keys()[0])
		await _frames(2)
		print("ok: evolution picked (%s)" % game.player.evolution)


func _skip_dialogue() -> void:
	await _frames(3)
	var guard := 0
	while game.hud.dialogue_active and guard < 50:
		game.hud._advance_dialogue()
		await _frames(1)
		guard += 1
	await _handle_evolution()


func _buff() -> void:
	game.player.max_hp = 50000.0
	game.player.hp = 50000.0


func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	add_child(game)
	await _frames(10)

	# 1. Class select must be open; choose warrior.
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

	# 3. Fire every ability of every class near the Darkwood wolves.
	game.player.global_position = Vector2(Game.ZONE_W + 500.0, 340.0)
	await _frames(5)
	for cls in Classes.CLASSES:
		game.player.set_class(cls)
		_buff()
		for slot in ["a1", "a2", "a3", "ult"]:
			game.player.cds[slot] = 0.0
			game.player.mp = game.player.max_mp
			game.player.use_ability(slot)
			await _frames(10)
		await _frames(30)
		await _handle_evolution()
		print("ok: %s abilities" % cls)
	game.player.set_class("warrior")
	game.player.evolution = ""
	game.player.pending_evolution = false
	_buff()

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

	# 5. Skill tree: numeric node, behavior node, and gating.
	if game.player.skill_points < 3:
		game.player.gain_xp(400)
		await _frames(3)
		await _handle_evolution()
	if game.player.learn_skill("wA2"):
		return _fail("skill gating broken: learned tier 3 before tier 1")
	if not game.player.learn_skill("wA0"):
		return _fail("could not learn wA0")
	if game.player._amod("a1", "dmg") < 0.24:
		return _fail("wA0 did not boost Cleave damage")
	if not game.player.learn_skill("wA1"):
		return _fail("could not learn wA1")
	if not game.player.has_mod("wA1"):
		return _fail("behavior mod wA1 not registered")
	game.player.use_ability("a1")  # exercise the modified Cleave
	await _frames(10)
	print("ok: skill tree (ability mods + gating)")

	# 6. Shop.
	game.player.gold = 500
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[0].size() != 3:
		return _fail("shop did not open with stock")
	game.menus.close()
	await _frames(2)
	print("ok: merchant shop")

	# 6b. Codex opens on both tabs.
	game.menus.open_codex("monsters")
	await _frames(2)
	if not game.menus.is_open():
		return _fail("codex did not open")
	game.menus.open_codex("gear")
	await _frames(2)
	game.menus.close()
	await _frames(2)
	print("ok: codex")

	# 7..9. Each boss: trigger, fight a while, kill.
	for zi in [1, 2, 3]:
		var kind: String = Story.ZONES[zi]["boss"]
		game.player.global_position = Vector2(zi * Game.ZONE_W + 1060.0, 360.0)
		await _frames(10)
		if not game.hud.dialogue_active:
			return _fail("pre-boss dialogue for %s did not open" % kind)
		await _skip_dialogue()
		await _frames(5)
		if not is_instance_valid(game.current_boss):
			return _fail("boss %s did not spawn" % kind)
		print("ok: %s spawned" % kind)

		game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
		await _frames(140)
		await _handle_evolution()
		if kind == "vargoth":
			game.current_boss.take_damage(game.current_boss.hp - game.current_boss.max_hp * 0.2)
			await _frames(40)
			if not game.current_boss.enraged:
				return _fail("vargoth did not enrage")
			print("ok: vargoth enrage")
			game.player.hurt_cd = 0.0
			game.player.dr = 0.0
			game.player.max_hp = 100.0
			game.player.hp = 1.0
			game.player.take_damage(999999.0)
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
		if not game.hud.dialogue_active:
			return _fail("post-boss dialogue for %s did not open" % kind)
		await _skip_dialogue()
		# Walk over the boss's golden chest and coins.
		if kind != "vargoth":
			game.player.global_position = Vector2(zi * Game.ZONE_W + 1380.0, 420.0)
			await _frames(30)
			if game.player.gold <= gold_before:
				return _fail("boss %s dropped no gold" % kind)
		await _frames(5)
		print("ok: %s killed + loot" % kind)

	# 10. Victory.
	await _frames(10)
	if game.state != Game.ST_VICTORY:
		return _fail("no victory state after final boss")
	print("ok: victory screen")

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)
