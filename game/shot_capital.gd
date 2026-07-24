extends Node
## CROWNFALL VISUAL-QA RIG: boots the real game, enters the capital, captures
## every authored room plus the capital map at desktop and compact-window sizes.
## Run: tools\Godot_v4.4.1-stable_win64_console.exe --path game res://shot_capital.tscn
## Output: user://shots/capital/*.png (absolute paths printed)

var game: Game
var shot_count := 0


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var path := ProjectSettings.globalize_path("user://shots/capital/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	get_viewport().get_texture().get_image().save_png(path)
	shot_count += 1
	print("SHOT: ", path)


func _dismiss_opening() -> void:
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 100:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class("warrior")
	await _frames(6)
	await _dismiss_opening()

	game.enter_capital()
	await _frames(12)
	game.camera.zoom = Vector2(0.72, 0.72)
	for room_index in game.zone_count:
		game.fast_travel(room_index)
		# Room titles and travel vignette are wall-clock tweens; a handful of
		# frames races them and captures a darkened transition instead of the
		# settled room. Wait long enough to review the actual composition.
		await get_tree().create_timer(1.6).timeout
		var slug := String(game.zones[room_index]["name"]).to_snake_case()
		_shot("room_%02d_%s" % [room_index, slug])

	# Regression frame: interact with the Plaza Citizen while standing on his
	# screen-right. The Citizen must select factor_imre_anim_e, facing the hero.
	game.fast_travel(0)
	await get_tree().create_timer(1.6).timeout
	for entry in game.interactables:
		if String((entry as Dictionary).get("sprite_name", "")) == "factor_imre":
			var citizen := (entry as Dictionary)["node"] as Node2D
			game.player.global_position = citizen.global_position + Vector2(70, 0)
			game._face_interactable_to_player(entry)
			(entry as Dictionary)["action"].call()
			await _frames(4)
			_shot("npc_citizen_right")
			await _dismiss_opening()
			break

	game.camera.zoom = Vector2.ONE
	game.menus.open_map()
	await _frames(6)
	_shot("map_desktop")
	game.menus.close()

	get_window().size = Vector2i(960, 540)
	await _frames(6)
	game.menus.open_map()
	await _frames(6)
	_shot("map_compact")

	print("CAPITAL AUDIT DONE: %d shots -> %s" % [shot_count,
		ProjectSettings.globalize_path("user://shots/capital")])
	get_tree().quit(0)
