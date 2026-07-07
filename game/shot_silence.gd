extends Node
## SILENCE READABILITY RIG (dev tool): boots the real game, spawns Vess,
## and screenshots her Silence — early ramp, deep ramp, and the enraged
## decoy pair — so the readability pass is judged by LOOKING (doctrine,
## round 31). Run:  godot --path game res://shot_silence.tscn

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
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0
	await _frames(8)

	# Vess appears; hold her still so only the Silence is on stage.
	var b := Boss.make_boss(game, "vess", game.player.global_position + Vector2(420, 0))
	game.bosses.append(b)
	game.add_child(b)
	b.speed = 0.0
	b.ability_cd = 999.0  # no grief fans in the shots
	b.ring_cd = 999.0
	b.special_cd = 0.05   # cast the Silence immediately
	await get_tree().create_timer(0.5).timeout
	_shot("silence_early")   # callout + circle + beacon + ramp beginning
	await get_tree().create_timer(1.2).timeout
	_shot("silence_deep")    # dread wash near full, beacon steady
	await get_tree().create_timer(1.5).timeout

	# Enrage her: the decoy pair (steady truth vs flickering lie).
	b.hp = b.max_hp * 0.2
	b.ability_cd = 999.0
	b.ring_cd = 999.0
	b.special_cd = 0.05
	await get_tree().create_timer(0.9).timeout
	_shot("silence_decoys")
	await get_tree().create_timer(2.0).timeout

	print("DONE — inspect user://shots")
	get_tree().quit()
