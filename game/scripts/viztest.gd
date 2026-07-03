extends Node
## Temporary visual-check: facing direction with left-native Crawl sprites.

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
	game.player.max_hp = 50000.0
	game.player.hp = 50000.0
	# Enemy to the RIGHT: hero and wolf should face each other.
	var e := Enemy.make(game, "wolf", game.player.global_position + Vector2(160, 0))
	game.add_enemy(e)
	await _frames(30)
	get_tree().quit(0)
