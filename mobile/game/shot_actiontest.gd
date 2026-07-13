extends Node
## DIRECTIONAL ONE-SHOT ACTION TEST (dev, temporary): a ring of 8 wolves
## aggroed inward, each fires play_action("bite") — a synthetic 3-frame
## directional set. Each should play ITS inward direction's strip (facing
## locked at fire), animating. Proves directional ability strips + facing
## lock + multi-frame directional actions.
## Run:  godot --path game res://shot_actiontest.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/actiontest"))
	img.save_png(ProjectSettings.globalize_path("user://shots/actiontest/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/actiontest/%s.png" % nm))


func _ready() -> void:
	print("dir_set(wolf_bite) empty? ", Art.dir_set("wolf_bite").is_empty(), " (expect false)")
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
		if game.hud.choices_active: game.hud._choose(0)
		else: game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0
	await get_tree().create_timer(3.2).timeout
	game.hud.visible = false
	game.camera.zoom = Vector2(0.95, 0.95)

	var pc: Vector2 = game.player.global_position
	var ring := [Vector2(0,-1), Vector2(1,-1), Vector2(1,0), Vector2(1,1),
		Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(-1,-1)]
	var R := 210.0
	var mobs: Array = []
	var pins: Array = []
	for d in ring:
		var wp: Vector2 = pc + (d as Vector2) * R
		var w := Enemy.make(game, "wolf", wp)
		game.add_enemy(w)
		w.force_aggro = true
		w.alerted = true
		mobs.append(w)
		pins.append(wp)
		var l := Label.new()
		l.text = "bite " + Art.dir8_suffix(pc - wp).to_upper()
		l.position = wp + Vector2(-34, 34)
		l.add_theme_color_override("font_color", Color(1, 1, 0.5))
		l.z_index = 500
		game.add_child(l)
	# settle facing, then fire the directional action on all of them
	for i in 6:
		for j in mobs.size():
			if is_instance_valid(mobs[j]):
				mobs[j].global_position = pins[j]
		await _frames(1)
	for w in mobs:
		if is_instance_valid(w):
			w.play_action("bite")
	# hold at mid-animation (3 frames @ ~6fps -> grab ~frame 1)
	for i in 8:
		for j in mobs.size():
			if is_instance_valid(mobs[j]):
				mobs[j].global_position = pins[j]
		await _frames(1)
	_shot("wolves_bite_8dir")
	print("ACTIONTEST DONE")
	get_tree().quit(0)
