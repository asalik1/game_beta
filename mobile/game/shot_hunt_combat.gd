extends ShotRig
## Ordinary keyboard intents, starting gear/stats, real movement and damage.
## Setup places the hero at each sign; combat never calls use_ability/damage.
const Hunt := preload("res://scripts/road_hunt.gd")
var held := {}


func _ready() -> void:
	await boot(arg("class", "warrior"), "ch1", false)
	var error := await _checks()
	_release()
	if error != "":
		await _capture("diagnostic")
		push_error(error)
		return finish(1)
	finish()


func _press(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _move(direction: Vector2) -> void:
	_press(KEY_A, direction.x < -0.3)
	_press(KEY_D, direction.x > 0.3)
	_press(KEY_W, direction.y < -0.3)
	_press(KEY_S, direction.y > 0.3)


func _release() -> void:
	for key in held.keys():
		_press(int(key), false)
	if game != null and game.has_local_player():
		game.player.clear_local_intents()


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label)


func _checks() -> String:
	var ready_by := Time.get_ticks_msec() + 6000
	while not game.play_started and Time.get_ticks_msec() < ready_by:
		await get_tree().create_timer(0.05, true).timeout
	if not game.play_started:
		return "combat fixture never reached gameplay"
	game.dev_god = false
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	var room := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		return "combat fixture has no starting road"
	var p := game.player
	p.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await frames(3)
	var trail := Hunt.begin(game, room, p.global_position)
	if trail == null:
		return "combat fixture could not accept a village hunt"
	for i in 3:
		p.global_position = trail.points[i]
		if not trail.request(p, i):
			return "combat setup could not inspect its next sign"
		if i < 2:
			await sim_wait(4.0)  # normal reading time; let the discovery be seen
	p.global_position = game.free_spawn_pos(trail.quarry_point + Vector2(-260, 90), trail.quarry_point)
	await _capture("01_time_to_step_clear")
	while trail.phase == Hunt.WARNING:
		await get_tree().create_timer(0.05, true).timeout
	if trail.phase != Hunt.FIGHTING:
		return "ordinary hunt did not reach combat"
	var quarry: Enemy = trail.quarry
	var hp_start := p.hp
	var hp_min := p.hp
	var enemy_hp := quarry.max_hp
	var money := p.gold
	var origin := p.global_position
	var traveled := 0.0
	var begun := Time.get_ticks_msec()
	var crouch_seen := false
	var fight_shown := false
	var max_seconds := 70.0
	var sample_at := 0.0
	var samples: Array[Dictionary] = []
	var observe := float(arg("observe", "0"))
	var hurt_shown := false
	print("HUNT COMBAT START: ", JSON.stringify({"kind": quarry.kind, "traits": quarry.traits,
		"damage": quarry.dmg, "speed": quarry.speed, "hero_speed": p.speed,
		"hero_position": str(p.global_position), "quarry_position": str(quarry.global_position)}))
	while is_instance_valid(trail) and trail.phase == Hunt.FIGHTING and not p.dead \
		and Time.get_ticks_msec() - begun < int(max_seconds * 1000.0):
		var elapsed := (Time.get_ticks_msec() - begun) / 1000.0
		var offset := quarry.global_position - p.global_position
		var distance := offset.length()
		var toward := offset.normalized()
		var side := Vector2(-toward.y, toward.x)
		var melee: bool = p.cls in ["warrior", "paladin", "assassin"]
		var preferred := 240.0 if elapsed < observe or not melee else 55.0
		var walk := toward if distance > preferred + 15.0 else -toward if distance < preferred - 20.0 else Vector2.ZERO
		if quarry.pounce_windup > 0.0 or quarry.pounce_time > 0.0:
			walk = side
		var safe := game.play_rect(room).grow(-80.0)
		if not safe.has_point(p.global_position + walk * 90.0):
			walk = (game.room_center(room) - p.global_position).normalized()
		_move(walk)
		_press(int(game.binds.a1), elapsed >= observe)
		_press(int(game.binds.a2), elapsed >= observe and distance < 190.0)
		_press(int(game.binds.a3), elapsed >= observe and distance < 180.0)
		_press(int(game.binds.ult), elapsed >= 10.0 and distance < 220.0)
		_press(int(game.binds.potion), p.hp < p.max_hp * 0.4)
		if elapsed >= sample_at:
			sample_at += 1.0
			var sample := {"seconds": elapsed, "hp": p.hp,
				"distance": distance, "quarry_hp": quarry.hp, "pounce": quarry.pounce_windup,
				"bite": quarry.windup, "hero": str(p.global_position), "quarry": str(quarry.global_position)}
			samples.append(sample)
			if flag("trace"):
				print("HUNT COMBAT SAMPLE: ", JSON.stringify(sample))
		if p.hp < hp_start and not hurt_shown:
			hurt_shown = true
			await _capture("first_incoming_hit")
		if quarry.pounce_windup > 0.0 and not crouch_seen:
			crouch_seen = true
			await _capture("02_read_the_pounce")
		if elapsed >= 8.0 and not fight_shown:
			fight_shown = true
			game.hud.wayfinder._sample()
			if game.hud.wayfinder._hot or game.hud.wayfinder.status_label.text.contains("Sanctuary"):
				return "the live quarry sealed its escape or was marked as a sanctuary"
			await _capture("03_starting_kit_in_combat")
		await get_tree().create_timer(0.05, true).timeout
		hp_min = minf(hp_min, p.hp)
		traveled += p.global_position.distance_to(origin)
		origin = p.global_position
	_release()
	var won: bool = is_instance_valid(trail) and trail.phase == Hunt.COMPLETE
	var report := {"class": p.cls, "hero_level": p.level, "god_mode": game.dev_god,
		"quarry_hp": enemy_hp, "seconds": (Time.get_ticks_msec() - begun) / 1000.0,
		"hp_start": hp_start, "hp_min": hp_min, "hp_end": p.hp,
		"distance_walked": traveled, "pounce_seen": crouch_seen, "won": won,
		"gold_earned": p.gold - money, "dead": p.dead,
		"quarry_hp_left": quarry.hp if is_instance_valid(quarry) else 0.0}
	await _capture("04_combat_outcome")
	var file := FileAccess.open(shot_dir.path_join("combat.json"), FileAccess.WRITE)
	if file != null:
		var detailed := report.duplicate(true)
		detailed["samples"] = samples
		file.store_string(JSON.stringify(detailed, "\t"))
		file.close()
	print("HUNT COMBAT: ", JSON.stringify(report))
	if not won:
		return "ordinary combat probe did not win; inspect its report before changing balance"
	if game.dev_god or hp_start > 1000.0 or traveled < 100.0 or p.gold <= money:
		return "combat probe used inflated health, did not walk, or received no reward"
	print("ok: ordinary hunt combat won through keyboard movement and class-kit inputs with starting equipment, normal health and no injected combat damage")
	return ""
