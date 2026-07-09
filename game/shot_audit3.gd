extends Node
## ART-AUDIT RIG, pass 3: dialogue box + choice UI, driven via the HUD API
## directly (the intro's own dialogue renders with the HUD still hidden
## under the no_saves fast-boot, so passes 1-2 shot bare world).
## Run:  godot --path game res://shot_audit3.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/audit2"))
	img.save_png(ProjectSettings.globalize_path("user://shots/audit2/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/audit2/%s.png" % nm))


func _noop(_i: int) -> void:
	pass


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
	await get_tree().create_timer(3.5).timeout

	game.hud.dialogue([
		["Maren", "The Ember does not choose the worthy. It chooses the willing — and then it asks what you are willing to lose."],
		["You", "..."],
	])
	await _frames(6)
	_shot("hud_dialogue")
	game.hud._advance_dialogue()
	game.hud._advance_dialogue()
	await _frames(4)

	game.hud.dialogue_choice("Maren",
		"The verdict is yours to deliver. What do you say?",
		["He is guilty. The law stands.",
		"Mercy — this once.",
		"I will not judge him."],
		Callable(self, "_noop"))
	await _frames(6)
	_shot("hud_choices")

	print("AUDIT3 DONE")
	get_tree().quit(0)
