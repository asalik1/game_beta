extends Node
## INSTALL-PIPELINE PROOF (dev, temporary): a ring of 8 Serane bosses around
## the player, each aggroed so it faces INWARD — with the real PixelLab
## 8-rotation set assembled by tools/art/install_dirset.py, each should show
## the correct facing. Proves generate -> install -> in-engine end to end.
## Run:  godot --path game res://shot_dirinstall.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/dirinstall"))
	img.save_png(ProjectSettings.globalize_path("user://shots/dirinstall/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/dirinstall/%s.png" % nm))


func _ready() -> void:
	print("dir_set(serane_anim) empty? ", Art.dir_set("serane_anim").is_empty(), " (expect false)")
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
	game.camera.zoom = Vector2(0.72, 0.72)

	var pc: Vector2 = game.player.global_position
	var ring := [Vector2(0,-1), Vector2(1,-1), Vector2(1,0), Vector2(1,1),
		Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(-1,-1)]
	var R := 300.0
	var mobs: Array = []
	var pins: Array = []
	for d in ring:
		var wp: Vector2 = pc + (d as Vector2) * R
		var b := Boss.make_boss(game, "icebound", wp)  # icebound def -> sprite "serane"
		game.add_enemy(b)
		b.force_aggro = true
		b.alerted = true
		mobs.append(b)
		pins.append(wp)
		var l := Label.new()
		l.text = "faces " + Art.dir8_suffix(pc - wp).to_upper()
		l.position = wp + Vector2(-40, 60)
		l.add_theme_color_override("font_color", Color(1, 1, 0.5))
		l.z_index = 500
		game.add_child(l)
	for i in 24:
		for j in mobs.size():
			if is_instance_valid(mobs[j]):
				mobs[j].global_position = pins[j]
		await _frames(1)
	_shot("serane_ring_8dir")
	print("DIRINSTALL DONE")
	get_tree().quit(0)
