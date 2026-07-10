extends Node
## ONE-OFF VERIFY RIG (combat-readability fixes 2026-07-10): keep-terrain
## road band (was: dashed debug rectangles) + void_shade on voidstone
## (was: invisible). Run:  godot --path game res://shot_readability.tscn
## Output: user://shots/audit2/fix_terrain_keep.png, fix_void_shade.png

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
	await get_tree().create_timer(3.5).timeout

	# Keep terrain: the road band should read as a worn walkway, not a
	# dashed debug rectangle (same framing as the audit's terrain tour).
	game.camera.zoom = Vector2(0.7, 0.7)
	game.apply_terrain(0, "keep")
	game.ambient.color = Terrains.get_terrain("keep")["tint"]
	await _frames(8)
	_shot("fix_terrain_keep")

	# Voidstone + the shade next to a static_caller for a darkness ladder.
	game.apply_terrain(0, "void")
	game.ambient.color = Terrains.get_terrain("void")["tint"]
	await _frames(6)
	var base: Vector2 = game.camera.get_screen_center_position()
	var shade := Enemy.make(game, "void_shade", base + Vector2(-80, 0))
	game.add_enemy(shade)
	var caller := Enemy.make(game, "static_caller", base + Vector2(120, 0))
	game.add_enemy(caller)
	shade.set_physics_process(false)
	caller.set_physics_process(false)
	await _frames(4)
	shade.global_position = base + Vector2(-80, 0)
	caller.global_position = base + Vector2(120, 0)
	await _frames(2)
	_shot("fix_void_shade")

	# And a hit flash on the shade: the tint must SURVIVE the tween back.
	shade.take_damage(10.0, Vector2.ZERO, false, true)
	await get_tree().create_timer(0.35).timeout
	shade.global_position = base + Vector2(-80, 0)
	await _frames(2)
	_shot("fix_void_shade_postflash")
	get_tree().quit(0)
