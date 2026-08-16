extends Node
## MOB CLIP QA RIG (dev tool): boots the real game, spawns a row of mobs and
## drives their idle / walk / attack strips FRAME BY FRAME through the very
## same enemy.gd _apply_strip path a live spawn uses (body-cell reference,
## feet-line re-anchor, oversized action cells), screenshotting each frame so
## the on-screen result can be assembled into per-mob filmstrips and checked
## for the defects the sheets can't show: a body that jumps up when the
## attack fires, a walk that vanishes, a clip that plays at the wrong size.
## Prints, per mob and strip, the sprite scale/offset and where the feet row
## lands on screen (should be identical across idle/walk/attack).
##
## Run (windowed; needs a real viewport for screenshots):
##   tools\Godot_v4.4.1-stable_win64_console.exe --path game res://shot_mobqa.tscn
##   [-- --kinds beastkin_raider,frost_husk,bog_lurker,vow_sentinel]
## Assemble the filmstrips: python tools/art/mobqa_filmstrip.py
## Shots land in user://shots/mobqa/<state>_f<N>.png (+ mobqa_index.txt).

var game: Game
const DEFAULT_KINDS := ["beastkin_raider", "frost_husk", "bog_lurker", "vow_sentinel"]
const ZOOM := 1.5
const SPACING := 210.0
const STATES := ["idle", "walk", "attack"]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot_dir() -> String:
	var d := ProjectSettings.globalize_path("user://shots/mobqa")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_shot_dir(), nm])


func _kinds() -> Array:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--kinds" and i + 1 < args.size():
			return Array(String(args[i + 1]).split(","))
	return DEFAULT_KINDS


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
	await get_tree().create_timer(2.5).timeout
	game.hud.visible = false
	game.camera.zoom = Vector2(ZOOM, ZOOM)
	# Clean plate: scenery (a tree canopy y-sorts over a mob standing behind
	# it) and the hero would occlude the clips we are here to look at.
	for zi in game.zone_scenery:
		for n in game.zone_scenery[zi]:
			if is_instance_valid(n):
				n.visible = false
	game.player.visible = false
	await _frames(5)

	var kinds := _kinds()
	# Row centred on what the CAMERA shows (it may be clamped at a map edge,
	# so the player is not necessarily mid-screen), a little below centre.
	var pc: Vector2 = game.camera.get_screen_center_position() + Vector2(0, 60)
	var mobs: Array = []
	var x0 := -SPACING * (kinds.size() - 1) / 2.0
	for i in kinds.size():
		var k: String = kinds[i]
		if not Story.ALL_ENEMIES.has(k):
			push_error("unknown enemy kind: " + k)
			continue
		var e := Enemy.make(game, k, pc + Vector2(x0 + SPACING * i, 0.0), -1, 1.0)
		game.add_enemy(e)
		# Frozen: an inactive zone index short-circuits _physics_process, so
		# nothing re-applies strips or advances frames behind our back.
		e.zone_idx = 9999
		e.z_index = 50  # draw over scenery (a tree over the mob hides the clip)
		mobs.append(e)
	await _frames(5)

	var index := ""
	for m in mobs:
		var scr: Vector2 = m.sprite.get_global_transform_with_canvas().origin
		index += "%s %s %.1f %.1f\n" % [m.kind, m._sprite_key, scr.x, scr.y]
	for state in STATES:
		for f in 4:
			for m in mobs:
				_drive(m, state, f)
			await _frames(3)
			_shot("%s_f%d" % [state, f])
			for m in mobs:
				print("QA %s %s f%d cell=%d hframes=%d frame=%d scale=%.4f offset=%.1f feet_screen_y=%.1f visible_px=%s" % [
					m._sprite_key, state, f, int(m.sprite.texture.get_height()), m.sprite.hframes,
					m.sprite.frame, m.sprite.scale.y, m.sprite.offset.y, _feet_screen_y(m),
					str(_frame_has_pixels(m))])
	var fa := FileAccess.open("%s/mobqa_index.txt" % _shot_dir(), FileAccess.WRITE)
	fa.store_string(index)
	fa.close()
	print("SHOTS: ", _shot_dir())
	get_tree().quit()


func _drive(m: Enemy, state: String, f: int) -> void:
	match state:
		"idle":
			m._apply_strip(m._strip_idle)
		"walk":
			if m._strip_walk.is_empty():
				m._apply_strip(m._strip_idle)  # idle-only locomotion glides on idle
			else:
				m._apply_strip(m._strip_walk)
		"attack":
			var info := Art.action_info(m._sprite_key, "attack")
			if info.is_empty():
				m._apply_strip(m._strip_idle)
			else:
				m._apply_strip(info, true)
	m.sprite.frame = mini(f, m.sprite.hframes - 1)
	m.sprite.flip_h = false


## Screen y of the strip's frame-0 feet row, through the sprite's live scale +
## offset — the number that must NOT change between idle, walk and attack.
func _feet_screen_y(m: Enemy) -> float:
	var cell := float(m.sprite.texture.get_height())
	var fy := Enemy._strip_feet_y(m.sprite.texture, cell)
	var local_y := (fy - cell / 2.0 + m.sprite.offset.y) * m.sprite.scale.y
	return m.sprite.get_global_transform_with_canvas().origin.y + local_y * ZOOM


func _frame_has_pixels(m: Enemy) -> bool:
	var img := m.sprite.texture.get_image()
	var cell := int(m.sprite.texture.get_height())
	var x0 := m.sprite.frame * cell
	for y in range(0, cell, 4):
		for x in range(x0, x0 + cell, 4):
			if img.get_pixel(x, y).a > 0.3:
				return true
	return false
