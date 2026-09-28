extends ShotRig
## Focused synthetic reward/HP/gear fixtures in the real HUD, with mobs visible.
## Run through shot.bat reward_feedback --timeout=240 (muted, isolated no-saves).


func _ready() -> void:
	await boot("warrior", "ch1")
	game.play_started = true
	game.menus.close()
	game.request_pause(false)
	await skip_dialogue()
	await sim_wait(5.0)
	var error: String = preload("res://scripts/tests/test_reward_feedback.gd").run(self)
	if error != "":
		print("REWARD FEEDBACK FAILED: ", error)
		finish(1)
		return
	var p: Player = game.local_player
	# Own-process loans only: normal XP and HUD paths, no simulated chest reward.
	game.dev_mode = true
	p.level = 1
	p.xp = 0
	p.recalc()
	p.consumables = [Items.make_gift_health_potion()]
	p.active_potion = "health"
	p.room_potions = {"health": 1}
	p.potion_cd = 0.0
	p.hp = p.max_hp * 0.2
	for offset in [Vector2(-120, -70), Vector2(130, 25)]:
		var enemy := Enemy.make(game, "wolf", p.global_position + offset, game.cur_room, 1.0)
		game.world.add_child(enemy)
		enemy.set_physics_process(false)
	# Boot and arrival notices may still hold the plaque; this view is the level-up.
	var h := game.hud
	if h._ann_tween != null and h._ann_tween.is_valid():
		h._ann_tween.kill()
	if is_instance_valid(h._ann_active):
		h._ann_active.free()
	h._ann_active = null
	h._ann_tween = null
	h._ann_queue = []
	p.gain_xp(p.xp_needed())
	await sim_wait(0.5)
	if not is_instance_valid(game.hud._ann_active) or not String(game.hud._ann_active.get_meta("message", "")).begins_with("LEVEL 2"):
		print("REWARD FEEDBACK FAILED: level plaque not visible")
		finish(1)
		return
	shot("level_and_low_health")
	await sim_wait(0.4)
	shot("potion_pulse_later")
	game.settings["impact_flashes"] = 0.0
	await frames(3)
	shot("comfort_steady_warning")
	await sim_wait(Balance.LEVEL_UP_HOLD)
	p.equipment = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var item := Items.roll_item_of("weapon", "B", rng, p.cls)
	p.backpack = [item]
	game.hud.loot_banner(item, 0)
	await frames(3)
	shot("empty_slot_loot")
	game.menus.open_inventory("gear")
	await frames(20)
	shot("bag_upgrade_badge")
	print("REWARD FEEDBACK PASS: regressions and five native HUD views")
	finish()
