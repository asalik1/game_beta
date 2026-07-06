extends Node
## LOOT-FX CAMERA RIG (dev tool, not part of the game): boots the real
## game windowed, fires the loot fanfare at every beam grade plus the
## chapter results card, and saves viewport PNGs — FX ship only after
## being SEEN (doctrine, round 31).
## Run:  godot --path game res://shot_loot.tscn
## Output: user://shots/*.png (absolute path printed per shot)

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % shot_name))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/%s.png" % shot_name))


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
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
	game.player.max_hp = 99999.0
	game.player.hp = 99999.0
	game.camera.zoom = Vector2(1.6, 1.6)
	await _frames(8)

	# Loot beams B / A / S side by side — height and heat must ladder up,
	# and the S flash must read as the jackpot.
	var base: Vector2 = game.player.global_position
	game.loot_fanfare("B", base + Vector2(-160, -40))
	game.loot_fanfare("A", base + Vector2(0, -40))
	game.loot_fanfare("S", base + Vector2(160, -40))
	await _frames(8)
	_shot("loot_beams_bas")
	await _frames(30)
	_shot("loot_beams_hold")
	await _frames(60)

	# Low grades: chime-only, no beam — the frame should show nothing new.
	game.loot_fanfare("C", base + Vector2(0, -40))
	await _frames(6)
	_shot("loot_c_nobeam")
	await _frames(30)

	# The chapter results card, with a NEW BEST time and a fresh grade.
	game.run_time = 754.0
	game.run_deaths = 1
	game.run_elites = 3
	game.run_secrets = 2
	game.hud.show_end_screen("VICTORY",
		"The Ember Crown is reclaimed. But the shards are still out there.\n\nENTER — journey on        ·        R — start over",
		Color(1.0, 0.85, 0.35))
	game.hud.show_results(game.run_results(),
		{"new_time": true, "new_grade": true, "prev_time": 812.0, "first_run": false})
	await _frames(25)
	_shot("results_card")

	print("DONE — inspect user://shots")
	get_tree().quit()
