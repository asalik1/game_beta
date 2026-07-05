extends Node
## FX CAMERA RIG (dev tool, not part of the game): boots the real game
## windowed, plays a class through its abilities, and saves viewport
## PNGs at animation peaks — so ability FX can be judged by LOOKING.
## Run:  godot --path game res://shot_kit.tscn
## Output: user://shots/*.png  (printed absolute path at the end)

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
	game.menus.pick_class("assassin")
	await _frames(5)
	# Fast-forward the opening.
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
	game.player.themes_known = 3
	var dummy := Enemy.make(game, "wolf", game.player.global_position + Vector2(110, 0))
	dummy.max_hp = 9999999.0
	dummy.hp = 9999999.0
	game.add_enemy(dummy)
	# Close-up lens: FX are unjudgeable at full zoom-out.
	game.camera.zoom = Vector2(2.4, 2.4)
	await _frames(8)

	# STAB mid-lunge (swing anim is 0.16s ~= 10 frames).
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(2)
	_shot("stab_early")
	await _frames(3)
	_shot("stab_mid")
	await _frames(40)

	# FAN OF KNIVES: darts mid-flight — push the dummy out to real
	# chip range so the flight is actually visible before impact.
	dummy.global_position = game.player.global_position + Vector2(300, 0)
	await _frames(3)
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	await _frames(3)
	_shot("knives_early")
	await _frames(4)
	_shot("knives_flight")
	await _frames(40)
	dummy.global_position = game.player.global_position + Vector2(110, 0)
	await _frames(3)

	# SHADOW DASH straight through the dummy: full pass-through should
	# cross two cut strokes into an X on the victim (round 36).
	game.player.facing = Vector2.RIGHT
	game.player.cds["a2"] = 0.0
	game.player.use_ability("a2")
	await _frames(2)
	_shot("dash_x")
	await _frames(30)
	dummy.global_position = game.player.global_position + Vector2(110, 0)
	await _frames(3)

	# ULT: Death Mark — blink-in, then rapid shots through the flurry
	# (frame rate varies between runs; bracket the rip window).
	game.player.cds["ult"] = 0.0
	game.player.use_ability("ult")
	await _frames(2)
	_shot("ult_blink")
	await _frames(4)
	_shot("ult_flurry")
	await _frames(5)
	_shot("ult_flurry2")
	await _frames(8)
	_shot("ult_stab")  # behind-teleport killing stab + floating X mark
	await _frames(30)
	print("RIG DONE")
	get_tree().quit(0)
