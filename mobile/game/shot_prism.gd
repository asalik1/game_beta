extends ShotRig
const Prism := preload("res://scripts/prism_crystal.gd")
var origin := Vector2.ZERO


func _ready() -> void:
	await boot("mage", "ch1", false)
	game.play_started = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	origin = game.room_center(2)
	game.player.global_position = origin
	game._enter_room(2)
	await skip_dialogue()
	apply_terrain("crystal", 2)
	await sim_wait(3.0)
	shot("natural_crystal_room")
	var installed := 0
	for prism in get_tree().get_nodes_in_group("prism_crystals"):
		if game.room_at_pos(prism.global_position) == 2:
			installed += 1
	if installed == 0:
		push_error("natural crystal scenery did not gain refraction")
		finish(1)
		return
	await _clear()
	game.player.set_physics_process(false)
	var error := await _checks()
	if error != "":
		push_error(error)
		finish(1)
		return
	print("ok: natural prism installation, physical corner shot, cover filtering, hostile bank, cosmetic mirror, pause, ordinary wall and touch guide")
	finish()


func _clear() -> void:
	for group in ["enemies", "projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	for node in game.zone_scenery[2]:
		if is_instance_valid(node):
			node.queue_free()
	game.zone_scenery[2] = []
	game.cancel_ground_attacks()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	game.bosses.clear()
	game.current_boss = null
	await frames(2)


func _enemy(offset: Vector2) -> Enemy:
	var e := Enemy.make(game, "skeleton", origin + offset, 3)
	e.set_meta("ward_spawn", true)
	e.hp = 1000.0
	e.max_hp = 1000.0
	e.dmg = 0.0
	e.zone_idx = 2
	game.world.add_child(e)
	e.set_physics_process(false)
	return e


func _wall(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 24)
	shape.shape = rect
	body.add_child(shape)
	game.world.add_child(body)
	return body


func _checks() -> String:
	var hero: Player = game.player
	hero.global_position = origin + Vector2(-220, -50)
	hero.hp = hero.max_hp
	var body := game._add_obstacle("crystal_spire", origin)
	var prism := Prism.install(game, body)
	var target := _enemy(Vector2(30, 205))
	await sim_wait(0.2)
	shot("crystal_trajectory_guide")
	var projectile := Projectile.spawn(game, origin + Vector2(-220, 10), Vector2.RIGHT * 220.0, 0.0, true, "mage_firebolt")
	projectile.source_player = hero
	projectile.hit_player_mult = 0.5
	projectile.fx = {"slow": 0.4}
	projectile.life = 3.0
	var contacts := [0]
	projectile.visual_impact.connect(func() -> void: contacts[0] += 1)
	var until := Time.get_ticks_msec() + 3000
	while is_instance_valid(projectile) and projectile._banked_crystals.is_empty() and Time.get_ticks_msec() < until:
		await sim_wait(0.04)
	if not is_instance_valid(projectile) or projectile._banked_crystals.is_empty() or contacts[0] != 0:
		return "real crystal contact failed to bank without an impact callback"
	shot("corner_shot_banks")
	game.request_pause(true)
	var life: float = projectile.life
	var at: Vector2 = projectile.global_position
	await get_tree().create_timer(0.25, true).timeout
	game.request_pause(false)
	if projectile.life != life or projectile.global_position != at:
		return "a banked shot advanced while paused"
	await sim_wait(1.2)
	if target.hp >= 1000.0 or target.slow_time <= 0.0 or contacts[0] != 1:
		return "banked corner shot lost its damage, slow or one-hit callback"
	shot("corner_shot_connects")
	# Cover must exclude a closer target without blocking the farther one.
	var cover := _wall(origin + Vector2(0, 80))
	var far_target := _enemy(Vector2(220, -100))
	await frames(2)
	if prism.target_for(true, {}, Balance.PRISM_TARGET_RANGE) != far_target:
		cover.free()
		return "a prism selected the closer enemy through solid cover"
	cover.free()
	target.queue_free()
	far_target.queue_free()
	await frames(2)
	# The visual copy bends on the same prop but cannot apply hostile damage.
	hero.global_position = origin + Vector2(30, 190)
	hero.eva = 0.0
	hero.shield = 0.0
	hero.hurt_cd = 0.0
	var hp := hero.hp
	var copy := Projectile.spawn(game, origin + Vector2(220, 10), Vector2.LEFT * 240.0, 1000.0, false, "mob_blight_thorn")
	copy.net_visual = true
	copy.life = 3.0
	await sim_wait(1.8)
	if hero.hp != hp:
		return "a reflected visual-only shot hurt the player"
	var hostile := Projectile.spawn(game, origin + Vector2(220, 10), Vector2.LEFT * 240.0, 18.0, false, "mob_blight_thorn")
	hostile.life = 3.0
	await sim_wait(0.85)
	shot("hostile_shot_bends")
	await sim_wait(1.0)
	if hero.hp >= hp:
		return "a real hostile bank could not hurt its target"
	# A plain wall still consumes the projectile without becoming a relay.
	var wall := _wall(origin + Vector2(-140, 10))
	var ordinary := Projectile.spawn(game, origin + Vector2(-220, 10), Vector2.RIGHT * 240.0, 0.0, true, "arrow_base")
	await sim_wait(0.5)
	if is_instance_valid(ordinary):
		wall.free()
		return "ordinary cover stopped consuming projectiles"
	wall.free()
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	var touch_target := _enemy(Vector2(220, -100))
	await sim_wait(0.3)
	shot("touch_crystal_guide")
	if not prism.caption.visible:
		return "touch players did not receive the nearby prism guide"
	game.menus.open_pause()
	# Offline pause freezes the helper. The overlay gate must also work
	# with a moving world, which is how menus behave in a co-op session.
	game.request_pause(false)
	prism.tick = 0.0
	prism._process(0.1)
	if prism.caption.visible:
		game.menus.close()
		return "prism guidance covered an unpaused menu"
	game.menus.close()
	touch_target.queue_free()
	return ""
