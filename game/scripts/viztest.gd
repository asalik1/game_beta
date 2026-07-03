extends Node
## Temporary visual-check driver for the new menu screens.

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	add_child(game)
	await _frames(10)
	game.menus.pick_class("assassin")
	await _frames(3)
	while game.hud.dialogue_active:
		game.hud._advance_dialogue()
		await _frames(1)
	game.player.skill_points = 5
	game.player.gold = 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 4:
		game.player.add_item(Items.roll_item(["wood", "silver", "gold"][i % 3], rng))
	game.player.equip(game.player.backpack[0])

	game.menus.open_skills()
	await _frames(12)
	game.menus.close()
	await _frames(2)
	game.menus.open_shop(0)
	await _frames(12)
	game.menus.close()
	await _frames(2)
	game.menus.open_codex("monsters")
	await _frames(12)
	game.menus.open_inventory()
	await _frames(12)
	get_tree().quit(0)
