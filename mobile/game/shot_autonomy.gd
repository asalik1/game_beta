extends ShotRig
## Real input, live damage, recovery, comfort and equipment decisions.


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.player.char_name = "The Uncrowned"
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	var error: String = await preload("res://scripts/tests/test_autonomy.gd").run(self)
	if error != "":
		push_error(error)
		finish(1)
		return
	step("comfort settings")
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await sim_wait(0.35)
	shot("01_comfort")
	game.menus.close()
	game.talked_to_elder = true
	game.set_flag("met_elder")
	game.quest_key = "fangmaw"
	game.player.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	await sim_wait(3.0)
	var attacker: Enemy
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
		if e.zone_idx == 2:
			attacker = e
	if attacker == null:
		finish(1)
		return
	var p: Player = game.player
	p.hp = p.max_hp
	p.hurt_cd = 0.0
	p.eva = 0.0
	p.shield = 0.0
	game.settings["impact_flashes"] = 0.25
	attacker.global_position = p.global_position + Vector2(190, 80)
	p.take_damage(p.max_hp * 0.18, "true", attacker, true)
	await sim_wait(0.12)
	shot("02_damage_bearing")
	p.mp = 0.0
	p.queue_ability("a3")
	await sim_wait(0.14)
	shot("03_cast_feedback")
	p.mp = p.max_mp
	step("real fall and recovery")
	p.hurt_cd = 0.0
	p.take_damage(p.max_hp * 2.0, "true", attacker, true)
	await sim_wait(Balance.DEATH_BEAT_SECS + 0.7)
	if p.dead or p.damage_memory.last_defeat.is_empty():
		push_error("The real fall did not recover with its report intact")
		finish(1)
		return
	preload("res://scripts/ui/combat_report.gd").open(game.menus)
	await sim_wait(0.35)
	shot("04_last_fall")
	game.menus.close()
	step("equipment decisions")
	var rng := RandomNumberGenerator.new()
	rng.seed = 84120
	var worn: Dictionary = Items.roll_item_of("weapon", "D", rng, p.cls)
	p.add_item(worn)
	p.equip(worn)
	var candidate: Dictionary = Items.roll_item_of("weapon", "B", rng, p.cls)
	p.add_item(candidate)
	for grade in ["F", "E", "D", "C", "B"]:
		p.add_item(Items.roll_gear_of_grade(grade, rng, p.cls, 1))
	game.menus.open_inventory()
	preload("res://scripts/ui/gear_inspect.gd").open(game.menus, candidate)
	await sim_wait(0.35)
	shot("05_comparison")
	var keep := game.menus.root.find_child("KeepInspectedGear", true, false) as Button
	keep.pressed.emit()
	await sim_wait(0.35)
	shot("06_kept_gear")
	game.menus._close_detail_popover()
	game.menus.inventory_order = "kept"
	game.menus.open_inventory()
	await sim_wait(0.35)
	shot("07_ordered_inventory")
	game.menus.open_shop(0, "sell")
	await sim_wait(0.35)
	shot("08_protected_sales")
	var shelf: Dictionary = game.shop_stock[0][0]
	p.gold = preload("res://scripts/ui/gear_inspect.gd").price(game.menus, shelf, 0) + 100
	game.menus.open_shop(0, "buy")
	preload("res://scripts/ui/gear_inspect.gd").open(game.menus, shelf, "all", 0)
	await sim_wait(0.35)
	shot("08b_shop_comparison")
	var buy := game.menus.root.find_child("BuyGear", true, false) as Button
	var bag_before := p.backpack.size()
	var gold_before := p.gold
	var cost: int = preload("res://scripts/ui/gear_inspect.gd").price(game.menus, shelf, 0)
	buy.pressed.emit()
	buy.pressed.emit()  # same-frame stale event must not charge or copy twice
	if p.backpack.size() != bag_before + 1 or p.gold != gold_before - cost:
		push_error("A stale shop purchase charged or copied an item twice")
		finish(1)
		return
	game.ensure_stash_loaded()
	var stored := {"kind": "item", "item": candidate}
	if not game.stash_deposit_from_bag(stored):
		push_error("The kept gear could not move into the stash")
		finish(1)
		return
	UIStash.open(game.menus, "Stored " + Items.title(candidate) + ".")
	await sim_wait(0.3)
	shot("08c_kept_in_stash")
	if not game.stash_withdraw(stored) or not candidate.get("kept", false):
		push_error("The stash did not return the kept piece intact")
		finish(1)
		return
	step("touch layouts")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.menus.open_inventory()
	preload("res://scripts/ui/gear_inspect.gd").open(game.menus, candidate)
	await sim_wait(0.35)
	shot("09_touch_comparison")
	game.menus.open_pause()
	await sim_wait(0.35)
	shot("10_touch_pause")
	preload("res://scripts/ui/comfort.gd").open(game.menus)
	await sim_wait(0.35)
	shot("11_touch_comfort")
	game.menus.close()
	await sim_wait(0.2)
	step("touch tap and long hold")
	p.action_buffer.clear()
	p.cds["a2"] = 0.0
	p.mp = p.max_mp
	_touch(7, "a2", true)
	_touch(7, "a2", false)
	if not p.action_buffer.pending.has("a2"):
		push_error("Touch release failed to buffer the ability")
		finish(1)
		return
	await get_tree().physics_frame
	await frames(1)
	if p.action_buffer.pending.has("a2"):
		push_error("Touch ability failed to fire on the next physics tick")
		finish(1)
		return
	p.action_buffer.clear()
	_touch(8, "a3", true)
	await sim_wait(0.6)
	_touch(8, "a3", false)
	if not p.action_buffer.pending.is_empty() or not game._touch_hud._info.visible:
		push_error("A long touch cast instead of explaining the ability")
		finish(1)
		return
	shot("12_touch_explanation")
	step("live enemy cue")
	game._touch_hud._release_everything()
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	for kind in Story.ALL_ENEMIES:
		if "reflect" in Story.ALL_ENEMIES[kind].get("traits", []):
			var guard := Enemy.make(game, kind, p.global_position + Vector2(160, 30), p.level)
			game.add_enemy(guard)
			guard.set_physics_process(false)
			guard._raise_reflect()
			p.locked_target = guard
			await sim_wait(0.3)
			shot("13_reflect_warning")
			guard.reflect_t = 0.0
			guard.vuln_time = 2.0
			guard.sprite.modulate = guard.base_mod
			await sim_wait(0.3)
			shot("14_exposed_window")
			break
	var plated := Boss.make_boss(game, "cinderhide", p.global_position + Vector2(190, 0), p.level)
	plated.zone_idx = game.cur_room
	game.add_enemy(plated)
	plated.set_physics_process(false)
	plated.plate_dr = Boss.PLATE_DR
	p.locked_target = plated
	game.current_boss = plated
	game.bosses.append(plated)
	await sim_wait(2.5)
	shot("14b_boss_plating_cue")
	game.menus.open_codex("notes_combat")
	await sim_wait(0.3)
	shot("15_combat_field_notes")
	finish()


func _frames(n: int) -> void:
	await frames(n)


func _press_key(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _touch(index: int, slot: String, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game._touch_hud._btns[slot]["center"]
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
