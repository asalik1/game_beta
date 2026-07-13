extends Node
## STORMFORGED isolation test (dev, temporary): hides the world and renders the
## player alone on a flat MAGENTA background at 4x for S/E/W idle. Zero ground/
## shadow blending — if the E/W sword is truncated HERE, it's a real render cut.
## Run windowed:  godot --path game res://shot_sf2.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("user://shots/sf2")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s.png" % [dir, nm])
	print("SHOT %s" % nm)


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
		if game.hud.choices_active: game.hud._choose(0)
		else: game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	var p := game.player
	p.max_hp = 999999.0; p.hp = 999999.0
	p.set_skin("stormforged")
	await get_tree().create_timer(1.0).timeout
	game.hud.visible = false
	game.camera.zoom = Vector2(4.0, 4.0)
	# isolate the player: flat magenta background, world hidden, shadow hidden
	RenderingServer.set_default_clear_color(Color(1, 0, 1))
	if game.world:
		game.world.visible = false
	# hide the player's own shadow child (first Sprite2D added) so nothing
	# overlaps the feet/blade
	for c in p.get_children():
		if c is Sprite2D and c != p.sprite:
			(c as Sprite2D).visible = false
	p.set_physics_process(false)

	var dir := ProjectSettings.globalize_path("user://shots/sf2")
	for nm in [["s", Vector2(0, 1)], ["e", Vector2(1, 0)], ["w", Vector2(-1, 0)]]:
		p.velocity = (nm[1] as Vector2) * 120.0
		for i in 3:
			p._advance_clip(0.06); await _frames(1)
		p.velocity = Vector2.ZERO
		p._advance_clip(0.1); await _frames(2)
		var s := p.sprite
		print("== %s ==" % nm[0])
		print("  tex=%s hframes=%d vframes=%d frame=%d frame_coords=%s" % [s.texture.get_size(), s.hframes, s.vframes, s.frame, s.frame_coords])
		print("  region_enabled=%s region_rect=%s centered=%s offset=%s scale=%s" % [s.region_enabled, s.region_rect, s.centered, s.offset, s.scale])
		print("  material=%s clip_children=%s modulate=%s self_modulate=%s visible=%s" % [s.material, s.clip_children, s.modulate, s.self_modulate, s.visible])
		# save the EXACT frame region the sprite is displaying, straight from its texture
		var img: Image = s.texture.get_image()
		var fw := int(img.get_width() / maxi(1, s.hframes))
		var fh := int(img.get_height() / maxi(1, s.vframes))
		var col := s.frame % s.hframes
		var rowi := s.frame / s.hframes
		var cell := img.get_region(Rect2i(col * fw, rowi * fh, fw, fh))
		cell.save_png("%s/CELL_%s.png" % [dir, nm[0]])
		var cb := -1
		for y in range(fh - 1, -1, -1):
			for x in fw:
				if cell.get_pixel(x, y).a > 0.15:
					cb = y; break
			if cb >= 0: break
		print("  CELL content bottom row=%d of %d (margin=%d)" % [cb, fh, fh - 1 - cb])
		_shot("iso_%s" % nm[0])

	print("DONE")
	get_tree().quit(0)
