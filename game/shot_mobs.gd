extends Node
## MOB-TRAIT RIG (dev tool): boots the game and lines up the trait mobs
## so the healer sigil, lunge crouch tell and pack density read by
## LOOKING. Run: godot --path game res://shot_mobs.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/%s.png" % nm))


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

	# A row of trait mobs beside the hero: healer (green sigil), a wolf
	# (lunge), spider (evasive), zombie (mend), skeleton (frenzy/swift).
	var base: Vector2 = game.player.global_position
	var kinds := ["cultist", "wolf", "spider", "zombie", "skeleton"]
	var mobs: Array = []
	for i in kinds.size():
		var e := Enemy.make(game, kinds[i], base + Vector2(180 + i * 90, -40))
		game.add_enemy(e)
		mobs.append(e)
	await _frames(6)
	_shot("mobs_lineup")   # healer wears the green sigil

	# Force the wolf into its pounce crouch (purple tell).
	var wolf: Enemy = mobs[1]
	wolf.lunge_cd = 0.0
	wolf.global_position = base + Vector2(320, 0)
	await get_tree().create_timer(0.25).timeout
	_shot("mobs_lunge_tell")
	await _frames(30)

	print("DONE — inspect user://shots")
	get_tree().quit()
