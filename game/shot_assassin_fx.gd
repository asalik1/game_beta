extends Node
## ASSASSIN in-engine verification (dev, temporary): boots the real game as
## the redesigned assassin, spawns a target, and screenshots idle + two walk
## facings + Fan of Knives (kunai + variant glow) + Death Mark (cast-shadow /
## reappear FX). Confirms in-engine scale on the 166px cell + the code layers.
## Run windowed:  godot --path game res://shot_assassin_fx.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("user://shots/assassin")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s.png" % [dir, nm])
	print("SHOT: %s/%s.png" % [dir, nm])


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
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active: game.hud._choose(0)
		else: game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	var p := game.player
	p.max_hp = 999999.0; p.hp = 999999.0
	p.mp = 9999.0
	await get_tree().create_timer(1.0).timeout
	game.hud.visible = false
	game.camera.zoom = Vector2(1.25, 1.25)

	# two walk facings (drive the clip machine directly)
	p.set_physics_process(false)
	for nm in [["s", Vector2(0, 1)], ["e", Vector2(1, 0)]]:
		p.velocity = (nm[1] as Vector2) * 120.0
		for i in 4:
			p._advance_clip(0.07)
			await _frames(1)
		_shot("walk_%s" % nm[0])
	p.velocity = Vector2.ZERO
	p._advance_clip(0.1)
	p.set_physics_process(true)
	await _frames(2)
	_shot("idle")

	# a target to aim abilities at
	var dummy := Enemy.make(game, "wolf", p.global_position + Vector2(0, -160))
	game.add_enemy(dummy)
	dummy.max_hp = 999999.0; dummy.hp = 999999.0
	await _frames(6)

	# Fan of Knives -> kunai + glow
	p.cds["a3"] = 0.0
	p.use_ability("a3")
	await _frames(4)
	_shot("fan_knives")
	await _frames(10)

	# Death Mark -> cast-shadow + execution FX
	p.cds["ult"] = 0.0
	p.use_ability("ult")
	await _frames(5)
	_shot("ult_cast")
	await get_tree().create_timer(0.5).timeout
	_shot("ult_execute")

	print("ASSASSIN FX DONE")
	get_tree().quit(0)
