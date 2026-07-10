extends Node
## CHEST RIG (dev tool): stages the F..S grade chests in-world at real
## scale/lighting, then drops a live chest and walks the player into it so
## the telegraph -> open -> loot flow is confirmed by LOOKING.
## Run:  godot --path game res://shot_chests.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/chests"))
	img.save_png(ProjectSettings.globalize_path("user://shots/chests/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/chests/%s.png" % nm))


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
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0

	# --- the ladder, staged at real scale on the road ---
	var base: Vector2 = game.camera.get_screen_center_position()
	var grades := ["f", "e", "d", "c", "b", "a", "s"]
	for i in grades.size():
		var s := Sprite2D.new()
		s.texture = Art.tex("chest_" + grades[i])
		s.scale = Art.scale_for(s.texture, Balance.CHEST_SCALE_16PX)
		s.modulate = Color(1, 1, 1).lerp(
			Items.GRADE_COLOR[grades[i].to_upper()], Balance.CHEST_GRADE_TINT)
		s.global_position = base + Vector2((i - 3) * 110.0, -40.0)
		game.add_child(s)
		var l := Label.new()
		l.text = grades[i].to_upper()
		l.position = s.global_position + Vector2(-6, 40)
		l.z_index = 500
		l.add_theme_color_override("font_color", Color(1, 1, 0.6))
		game.add_child(l)
	await _frames(8)
	_shot("chest_ladder_ingame")

	# --- live chests in a RICH band (ch10: C/B/A) so the B+ halo shows ---
	var real_ch: String = game.chapter_id
	game.chapter_id = "ch10"
	for i in 5:
		Chest.drop(game, "gold", base + Vector2((i - 2) * 130.0, 120.0))
	await _frames(20)
	_shot("chest_halos_rich_band")
	game.chapter_id = real_ch

	# --- a live chest: grade rolled at drop, sprite must match the loot ---
	var c := Chest.drop(game, "gold", game.player.global_position + Vector2(90, 0))
	await _frames(6)
	print("LIVE CHEST grade=", c.grade, " tier=", c.tier)
	_shot("chest_live_drop")
	# Walk the player in to open it.
	var target: Vector2 = c.global_position
	for i in 40:
		game.player.global_position = game.player.global_position.move_toward(target, 6.0)
		await _frames(1)
	await _frames(12)
	_shot("chest_opened")
	print("CHEST RIG DONE")
	get_tree().quit(0)
