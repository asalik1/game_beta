extends Node
## VERDICT READABILITY RIG (dev tool): boots the real game, spawns
## Ashpriest Ordo, and screenshots THE VERDICT — single wave, then the
## paired sub-50% verdict (bright first half + smoldering second) — so
## the pass is judged by LOOKING. Run: godot --path game res://shot_verdict.tscn

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

	# Ordo appears; hold him still so only the Verdict is on stage.
	var b := Boss.make_boss(game, "ashpriest", game.player.global_position + Vector2(420, 0))
	game.bosses.append(b)
	game.add_child(b)
	b.speed = 0.0
	b.ability_cd = 999.0  # no brand volleys in the shots
	b.special_cd = 0.05   # cast a single-wave Verdict immediately
	await get_tree().create_timer(1.0).timeout
	_shot("verdict_single")   # one half tiled + washed, callout on player
	await get_tree().create_timer(2.5).timeout

	# Below half: the PAIRED verdict — bright first half, smoldering second.
	b.hp = b.max_hp * 0.4
	b.ability_cd = 999.0
	b.special_cd = 0.05
	await get_tree().create_timer(1.0).timeout
	_shot("verdict_paired")   # both halves marked, visibly DIFFERENT
	await get_tree().create_timer(1.7).timeout
	_shot("verdict_handoff")  # first wave landed; second half flares
	await get_tree().create_timer(1.2).timeout

	print("DONE — inspect user://shots")
	get_tree().quit()
