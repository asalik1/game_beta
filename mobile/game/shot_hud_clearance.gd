extends ShotRig
## Audit normal camera framing at room edges before changing HUD presentation.
var held := {}
var samples: Array[Dictionary] = []
const Clearance := preload("res://scripts/ui/hud_clearance.gd")

func _ready() -> void:
	await boot("warrior", "ch1", false)
	var failure := await _checks()
	_release()
	if failure != "":
		push_error(failure)
		return finish(1)
	var file := FileAccess.open(shot_dir.path_join("clearance.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(samples, "\t"))
		file.close()
	print("ok: default camera room-edge audit captured; inspect images and measured overlap before deciding a HUD change")
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

func _release() -> void:
	for key in held:
		_press(int(key), false)
	if game != null and game.has_local_player():
		game.player.clear_local_intents()

func _capture(label: String, enemy: Enemy = null) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	var info := Rect2(8, 76, 344, 148)
	var feet := game.player.get_global_transform_with_canvas().origin
	var body := Clearance.body_rect(game.player)
	var row := {"view": label, "hero_feet": str(feet), "hero_covered": info.intersects(body),
		"info_alpha": game.hud.info_panel.self_modulate.a, "clearance": game.hud.clearance.covered(),
		"camera_zoom": str(game.camera.zoom), "camera_offset": str(game.camera.offset),
		"framing": game.settings.get("combat_framing", true), "smoothing": game.camera.position_smoothing_enabled}
	if is_instance_valid(enemy) and enemy.visible:
		var target_feet := enemy.get_global_transform_with_canvas().origin
		row["target_feet"] = str(target_feet)
		row["target_covered"] = info.intersects(Clearance.body_rect(enemy))
	samples.append(row)
	shot(label)

func _checks() -> String:
	var deadline := Time.get_ticks_msec() + 6000
	while not game.play_started and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05, true).timeout
	if not game.play_started:
		return "HUD fixture never reached ordinary gameplay"
	var room := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		return "HUD fixture has no starting road"
	game.terrain_event_t = 10000.0
	game.player.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await get_tree().create_timer(1.0, true).timeout
	var bounds := game.play_rect(room)
	var points := [
		["01_upper_left", bounds.position + Vector2(110, 195)],
		["02_left", Vector2(bounds.position.x + 110, bounds.get_center().y)],
		["03_upper_middle", Vector2(bounds.get_center().x, bounds.position.y + 195)],
		["04_center", bounds.get_center()]]
	for entry in points:
		game.player.global_position = game.free_spawn_pos(entry[1], bounds.get_center())
		await get_tree().create_timer(1.0, true).timeout
		await _capture(entry[0])
	var enemy := Enemy.make(game, "blightwolf", bounds.position + Vector2(230, 200), 2)
	enemy.zone_idx = -1
	enemy.xp_value = 0
	enemy.gold_value = 0
	game.add_enemy(enemy)
	enemy.set_physics_process(false)
	game.player.global_position = game.free_spawn_pos(bounds.position + Vector2(110, 265), bounds.get_center())
	enemy.global_position = game.free_spawn_pos(bounds.position + Vector2(230, 210), bounds.get_center())
	game.player.locked_target = enemy
	await get_tree().create_timer(1.0, true).timeout
	await _capture("05_upper_left_tracked_target", enemy)
	_press(KEY_D, true)
	await get_tree().create_timer(1.6, true).timeout
	_release()
	await get_tree().create_timer(1.0, true).timeout
	await _capture("06_walk_back_clear", enemy)
	if flag("verify"):
		var error := await preload("res://scripts/tests/hud_clearance_live.gd").run(self, enemy, room)
		if error != "":
			return error
	game.player.locked_target = null
	if is_instance_valid(enemy):
		enemy.queue_free()
	return ""
