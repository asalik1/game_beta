extends ShotRig
## Real-engine proof of the tactical map, field atlas, routes, loot and touch.
## shot.bat wayfinder --timeout=240


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.dev_god = true
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.camera.position_smoothing_enabled = false
	game.talked_to_elder = true
	game.set_flag("met_elder")
	game.quest_key = "fangmaw"
	game.refresh_quest()
	await sim_wait(2)
	shot("01_village", "live people, doors and player facing")
	game.menus.open_map()
	await frames(5)
	var atlas: Control = game.menus.root.find_child("FieldAtlas", true, false)
	atlas.select_room(2)
	await sim_wait(0.35)
	shot("02_frontier", "room 2 is an unnamed observed passage, with Set route")
	atlas._pin_selected()
	game.menus.close()
	await sim_wait(0.5)
	shot("03_bearing", "gold bearing to the next doorway")
	step("live encounter")
	game.player.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	await sim_wait(2)
	shot("04_encounter", "real room population, facing, sealed doors")
	step("loot")
	var loot := Chest.drop(game, "gold", game.player.global_position + Vector2(190, 100), {"grade": "A"})
	await sim_wait(0.4)
	shot("05_loot", "revealed loot on the local map")
	step("charted journey")
	var spine: Array = Story.chapter("ch1")["spine"]
	for room in spine.slice(0, 10):
		game.visited[int(room)] = true
		for dir in game.rooms[int(room)]["exits"]:
			var nb: int = game.neighbor(int(room), String(dir))
			if nb >= 0:
				game.door_seen[nb] = true
	game.menus.open_map()
	await frames(5)
	atlas = game.menus.root.find_child("FieldAtlas", true, false)
	atlas.select_room(9)
	await sim_wait(0.35)
	shot("06_atlas", "explored chapter with a sealed guardian route")
	atlas._zoom_at(1.5, atlas.chart.size * 0.5)
	await frames(3)
	shot("07_atlas_detail", "zoomed atlas and selected room details")
	game.menus.close()
	step("touch atlas")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.menus.open_map()
	await frames(5)
	atlas = game.menus.root.find_child("FieldAtlas", true, false)
	atlas.select_room(0)
	await sim_wait(0.35)
	shot("08_touch_atlas", "touch-friendly route and travel actions")
	game.menus.close()
	await sim_wait(1.0)
	shot("09_touch_encounter", "tactical map with the real touch HUD")
	step("secure the room")
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.zone_idx == game.cur_room and not e.dying:
			e.take_damage(9999999.0)
	await sim_wait(0.5)
	shot("10_secured", "green room-clear feedback, unsealed doors, remaining loot")
	if game.hud.wayfinder._hot or not game.hud.wayfinder.status_label.text.contains("SECURED"):
		push_error("Wayfinder failed to acknowledge a real room clear")
		finish(1)
		return
	game.hud.wayfinder.pin(0)
	await sim_wait(3.0)
	shot("11_return_route", "post-combat route back to a visited sanctuary")
	if is_instance_valid(loot):
		loot.queue_free()
	finish()
