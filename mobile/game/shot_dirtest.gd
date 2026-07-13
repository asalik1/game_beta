extends Node
## DIRECTION-RENDER TEST RIG (dev, temporary): spawns 8 wolves, aggroes each
## toward a target placed in a different compass direction, and screenshots.
## With the synthetic 8-dir wolf tiles installed, each wolf should show the
## COLOR/ARROW of the direction it faces — proving Art.dir_set selection.
## Run:  godot --path game res://shot_dirtest.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/dirtest"))
	img.save_png(ProjectSettings.globalize_path("user://shots/dirtest/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/dirtest/%s.png" % nm))


func _ready() -> void:
	# Loader unit check first (pure logic).
	var checks := {
		Vector2(0, 1): "s", Vector2(1, 1): "se", Vector2(1, 0): "e",
		Vector2(1, -1): "ne", Vector2(0, -1): "n", Vector2(-1, -1): "nw",
		Vector2(-1, 0): "w", Vector2(-1, 1): "sw",
	}
	var fails := 0
	for v in checks:
		var got := Art.dir8_suffix(v)
		if got != checks[v]:
			print("FAIL dir8_suffix(%s) = %s expected %s" % [v, got, checks[v]])
			fails += 1
	print("dir8_suffix: %d/%d correct" % [checks.size() - fails, checks.size()])
	print("dir_set(wolf_anim) empty? ", Art.dir_set("wolf_anim").is_empty(),
		" (expect false)  dir_set(rat_anim) empty? ", Art.dir_set("rat_anim").is_empty(),
		" (expect true)")

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

	# A RING of 8 wolves around the player. Each is aggroed, so its
	# _facing_vec points INWARD (toward the player) — giving 8 distinct
	# compass facings through the real gameplay path. A wolf placed north
	# faces south, one placed east faces west, etc.
	var pc: Vector2 = game.player.global_position
	var ring := [Vector2(0,-1), Vector2(1,-1), Vector2(1,0), Vector2(1,1),
		Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(-1,-1)]
	var R := 200.0
	var wolves: Array = []
	var pins: Array = []
	for d in ring:
		var wp: Vector2 = pc + (d as Vector2) * R
		var w := Enemy.make(game, "wolf", wp)
		game.add_enemy(w)
		w.force_aggro = true
		w.alerted = true
		wolves.append(w)
		pins.append(wp)
		var l := Label.new()
		l.text = "faces " + Art.dir8_suffix(pc - wp).to_upper()  # inward
		l.position = wp + Vector2(-34, 30)
		l.add_theme_color_override("font_color", Color(1, 1, 0.5))
		l.z_index = 500
		game.add_child(l)
	# Hold the ring in place while the per-frame directional swap settles.
	for i in 24:
		for j in wolves.size():
			if is_instance_valid(wolves[j]):
				wolves[j].global_position = pins[j]
		await _frames(1)
	_shot("wolves_8dir")
	print("DIRTEST DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
