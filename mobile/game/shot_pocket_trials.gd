extends ShotRig
const Trial := preload("res://scripts/pocket_trial.gd")


func _ready() -> void:
	await boot("warrior", "ch4", false)
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	for wanted in ["molten_court", "still_larder"]:
		var error := await _play_pocket(wanted)
		if error != "":
			return _fail(error)
	print("ok: live portal trials: real entry/exit buttons, both rules, cold/heat, pause, retreat/reset, exact return, save/reload, independent guardian, victory loot time, reentry, touch")
	finish()


func _play_pocket(wanted: String) -> String:
	var picked := -1
	for seed_value in 160:
		game.wander_seed = seed_value
		game._pocket_inject(Story.chapter("ch4")["zones"], "ch4")
		if game.pocket_id == wanted:
			picked = seed_value
			break
	if picked < 0:
		return "no seed for " + wanted
	game.wander_seed = picked
	game.switch_chapter("ch4", true)
	game.terrain_event_t = 10000.0
	game.dev_god = true
	var p := game.player
	p.set_physics_process(false)
	game.request_pause(false)
	game.state = Game.ST_PLAYING
	var origin := Trial.source_room(game)
	p.global_position = game.room_center(origin)
	game._enter_room(origin)
	await skip_dialogue()
	await frames(3)
	var stone := Trial.find(game, origin)
	if stone == null:
		return "stable source portal missing"
	p.global_position = stone.global_position + Vector2(0, 60)
	var return_at := p.global_position
	zoom(1.0)
	await _wait_notices()
	shot(wanted + "_door")
	stone.interact()
	await frames(2)
	shot(wanted + "_terms")
	var button := game.menus.root.find_child("Pocket_Enter", true, false)
	if button == null:
		return "entry action missing"
	# Beating the campaign's identical kit must not suppress this guardian.
	game.boss_done[String(Pockets.entry(wanted).kind)] = true
	button.pressed.emit()
	await frames(5)
	if game.cur_room != game.pocket_room or game.current_boss == null:
		return "pocket entry failed or campaign completion suppressed guardian"
	var v := Trial.find(game, game.pocket_room)
	if v == null:
		return "arena return stone missing"
	var boss := game.current_boss
	boss.set_physics_process(false)
	v.set_physics_process(false)
	p.global_position = game.room_center(game.pocket_room)
	await sim_wait(4.2)  # let the boss name/arrival title finish before framing
	await _wait_notices()
	if not game.hud.boss_badge_root.visible or game.hud.boss_badge.texture == null:
		return "named guardian lost its painted HUD portrait"
	if wanted == "molten_court":
		v.apply_state(0, 0, 0.06)
		v.set_physics_process(true)
		await sim_wait(0.16)
		if v.phase != 1:
			return "floor did not advance into a real warning"
		v._refresh()
		await frames(2)
		shot("molten_warning")
		game.request_pause(true)
		var timer: float = v.remaining
		await get_tree().create_timer(0.15, true).timeout
		if v.remaining != timer:
			return "solo pause advanced the floor clock"
		game.request_pause(false)
		v.set_physics_process(false)
		v.apply_state(2, 0, Balance.POCKET_PULSE_HEAT)
		v._refresh()
		var old_boss_at := boss.global_position
		boss.global_position = game.room_center(game.pocket_room)
		if boss._on_lava():
			return "cold seam melted the guardian"
		boss.global_position = v.hot_rect().get_center()
		for i in 40:
			boss._cinderhide(p, Vector2.ZERO, 9999.0, 0.075)
		if boss.plated or boss.plate_dr > 0.01:
			return "hot trial floor failed to melt obsidian plates"
		await frames(2)
		shot("molten_guardian_plates_shed")
		boss.global_position = old_boss_at
		game.dev_god = false
		p.hp = p.max_hp
		p.hurt_cd = 0.0
		var hp := p.hp
		v._heat_tick()
		if p.hp != hp:
			return "the cold seam dealt heat damage"
		p.global_position = v.hot_rect().get_center()
		v._heat_tick()
		if p.hp >= hp:
			return "the hot half did not deal damage"
		game.dev_god = true
		p.global_position = game.room_center(game.pocket_room)
		await sim_wait(0.8)  # damage flash clears; judge the floor's own color
		shot("molten_heat_and_cold_seam")
		v.apply_state(2, 0, 0.06)
		v.set_physics_process(true)
		await sim_wait(0.16)
		if v.phase != 0 or v.side != 1:
			return "floor did not cool and alternate sides"
		v.set_physics_process(false)
		v.apply_state(1, 1, Balance.POCKET_PULSE_WARNING)
		await frames(2)
		shot("molten_opposite_warning")
	else:
		var bottle := Items.make_potion("health", "instant", "F", "accord")
		p.consumables = [bottle]
		p.room_potions = {"health": 1, String(bottle.id): 1}
		p.active_potion = "health"
		p.hp = p.max_hp * 0.5
		p.potion_cd = 0.0
		p.drink_potion()
		p.potion_cd = 0.0
		p.use_consumable(bottle)
		if p.consumables.size() != 1 or p.room_potions.health != 1:
			return "live sealed bottle or room budget was spent"
		await frames(2)
		shot("larder_bottles_sealed")
	var network_error: String = await preload("res://scripts/tests/test_pocket_network.gd").run(self, v)
	if network_error != "":
		return network_error
	# A live save in the arena restores the source point and a valid guardian.
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	var saved := SaveGame.read(SaveGame.MAX_SLOTS)
	if saved.is_empty():
		return "live portal save failed"
	game.switch_chapter("ch4", true)
	SaveGame.apply(game, saved)
	SaveGame.delete(SaveGame.MAX_SLOTS)
	await frames(4)
	v = Trial.find(game, game.pocket_room)
	boss = game.current_boss
	if v == null or boss == null or game.pocket_done:
		return "active portal save lost its trial/guardian"
	boss.set_physics_process(false)
	boss.hp = boss.max_hp * 0.5
	p.set_physics_process(false)
	p.global_position = v.global_position + Vector2(0, 55)
	await frames(2)
	v.interact()
	await frames(2)
	var leave := game.menus.root.find_child("Pocket_Return", true, false)
	if leave == null:
		return "free retreat button missing"
	leave.pressed.emit()
	await frames(5)
	if game.cur_room != origin or p.global_position.distance_to(return_at) > 3.0:
		return "retreat failed to preserve exact return point"
	if boss.hp != boss.max_hp:
		return "empty arena did not reset guardian"
	stone = Trial.find(game, origin)
	if stone == null:
		return "source portal vanished after reload/retreat"
	game._enter_pocket(origin)
	await frames(4)
	v = Trial.find(game, game.pocket_room)
	p.global_position = game.room_center(game.pocket_room)
	if game.cur_room != game.pocket_room:
		return "retry entry failed"
	var renown := game.renown()
	var advancement := [p.level, p.xp]
	boss.take_damage(boss.max_hp * 10.0, Vector2.RIGHT, false, true)
	await sim_wait(3.5)
	if not game.pocket_done or game.cur_room != game.pocket_room or game.renown() != renown + Balance.RENOWN_POCKET:
		return "victory lost reward, failed completion or still auto-ejected"
	if [p.level, p.xp] != advancement:
		return "optional guardian inflated the fixed chapter XP budget"
	await _wait_notices()
	shot(wanted + "_take_your_time")
	if Trial.potions_locked(game, p):
		return "Larder seal survived victory"
	p.global_position = v.global_position + Vector2(0, 55)
	game._pocket_return()
	await frames(3)
	game._enter_pocket(origin)
	await frames(3)
	if not game._live_bosses().is_empty():
		return "completed guardian returned on reentry"
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(3)
	shot(wanted + "_touch_exit")
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	return ""


func _wait_notices() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	await frames(3)
	while (is_instance_valid(game.hud._ann_active) or not game.hud._ann_queue.is_empty()) and Time.get_ticks_msec() < deadline:
		await sim_wait(0.1)


func _fail(text: String) -> void:
	push_error(text)
	shot("failed")
	finish(1)
