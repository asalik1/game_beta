extends Node
## TEMP WALL-REVIEW RIG (dev tool): boots the real game, repaints room 0
## with each mossy biome, stands the player at the north + west walls and
## screenshots — owner review of the new wall_moss macro-tile in-game.
## Run:  godot --path game res://shot_wall.tscn
## Output: user://shots/wall/*.png (absolute paths printed)

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/wall"))
	img.save_png(ProjectSettings.globalize_path("user://shots/wall/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/wall/%s.png" % nm))


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.open_chapter_select()
	await _frames(3)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class("warrior")
	await _frames(5)
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0
	game.camera.position_smoothing_enabled = false
	# Wait out the chapter-title flash + overlay fade before shooting.
	await get_tree().create_timer(3.5).timeout
	await _frames(8)

	# Use a FULL-SIZE combat room — a small social room's play rect is
	# smaller than the viewport, so the camera pins to room centre and the
	# walls never enter the frame.
	var ri := 1
	for i in game.zone_count:
		if game.room_type(i) == "combat":
			ri = i
			break
	game.camera.zoom = Vector2(1.3, 1.3)
	for t in ["darkwood", "marsh", "bog", "spore"]:
		game.apply_terrain(ri, String(t))
		game.ambient.color = Terrains.get_terrain(String(t))["tint"]
		await _frames(6)
		var pr := game.play_rect(ri)
		game.player.global_position = Vector2(pr.position.x + pr.size.x / 2.0 - 350.0, pr.position.y + 150.0)
		game._enter_room(ri)
		# Let the room-title flash fade, then clear the pack for a clean shot.
		await get_tree().create_timer(2.4).timeout
		for node in get_tree().get_nodes_in_group("enemies"):
			node.queue_free()
		await _frames(4)
		# North wall: stand just below it, x offset off the centred door gap.
		game.player.global_position = Vector2(pr.position.x + pr.size.x / 2.0 - 350.0, pr.position.y + 150.0)
		await _frames(8)
		_shot("%s_north_wall" % t)
		# West wall: vertical run, y offset off the E/W door gap.
		game.player.global_position = Vector2(pr.position.x + 140.0, pr.position.y + pr.size.y / 2.0 + 280.0)
		await _frames(8)
		_shot("%s_west_wall" % t)

	print("WALL SHOTS DONE")
	get_tree().quit()
