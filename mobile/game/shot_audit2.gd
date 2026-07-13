extends Node
## ART-AUDIT RIG, pass 2: the four frames pass 1 missed — dialogue box,
## choice UI, combat with damage numbers + enemy HP bars, boss HP bar.
## Run:  godot --path game res://shot_audit2.tscn
## Output: user://shots/audit2/*.png

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/audit2"))
	img.save_png(ProjectSettings.globalize_path("user://shots/audit2/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/audit2/%s.png" % nm))


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

	# Dialogue + choices: let the box actually RENDER before shooting
	# (pass 1 shot the same frame the state flipped — got bare world).
	var guard := 0
	var shot_dialogue := false
	var shot_choices := false
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			if not shot_choices:
				await _frames(4)
				_shot("hud_choices")
				shot_choices = true
			game.hud._choose(0)
		else:
			if not shot_dialogue and game.hud.portrait_box.visible:
				await _frames(4)
				_shot("hud_dialogue")
				shot_dialogue = true
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1

	game.player.max_hp = 999999.0
	game.player.hp = 999999.0
	# Let the chapter title card fade fully so combat frames aren't veiled.
	await get_tree().create_timer(3.5).timeout

	# Combat: damage numbers + enemy HP bars actually on screen.
	var base: Vector2 = game.player.global_position
	var wolves: Array = []
	for k in 3:
		var w := Enemy.make(game, "wolf", base + Vector2(110 + k * 70, (k - 1) * 60))
		game.add_enemy(w)
		wolves.append(w)
	await _frames(4)
	for w in wolves:
		if is_instance_valid(w):
			var e: Enemy = w
			e.take_damage(23.0, Vector2.ZERO, false, true)
	await _frames(3)
	var w0: Enemy = wolves[0]
	if is_instance_valid(w0):
		w0.take_damage(41.0, Vector2.ZERO, true, true)
	await _frames(4)
	_shot("hud_combat_numbers")

	# Boss bar: drive the HUD API directly + a live boss in frame.
	var b := Boss.make_boss(game, "ashpriest", base + Vector2(300, -40))
	game.add_enemy(b)
	game.hud.show_boss_bar("Ashpriest, Voice of the Pyre")
	game.hud.update_boss_bar(0.72)
	await _frames(12)
	_shot("hud_boss_bar")

	print("AUDIT2 DONE -> %s" % ProjectSettings.globalize_path("user://shots/audit2"))
	get_tree().quit(0)
