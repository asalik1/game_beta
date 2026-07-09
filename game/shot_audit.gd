extends Node
## ART-AUDIT RIG (dev tool, not part of the game): boots the real game
## windowed and captures the full visual surface for review by LOOKING —
## boot menus, HUD, every menu screen, every terrain, and the entire
## Story.ALL_ENEMIES roster in labeled lineup batches.
## Run:  godot --path game res://shot_audit.tscn
## Output: user://shots/audit/*.png (absolute paths printed)

var game: Game
var shot_count := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/audit"))
	img.save_png(ProjectSettings.globalize_path("user://shots/audit/%s.png" % nm))
	shot_count += 1
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/audit/%s.png" % nm))


func _menu_shot(nm: String) -> void:
	await _frames(4)
	_shot("menu_%s" % nm)


func _label(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 500
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
	game.add_child(l)
	return l


func _lineup(kinds: Array, tag: String, cols: int, spacing: Vector2, use_boss: bool) -> void:
	# Camera clamps to room bounds — center the grid on what's actually
	# on screen, not on the player.
	var base: Vector2 = game.camera.get_screen_center_position()
	var batch_size := cols * 2
	var bi := 0
	var i := 0
	while i < kinds.size():
		var batch: Array = kinds.slice(i, i + batch_size)
		var spawned: Array = []
		var pins: Array = []
		var labels: Array = []
		for j in batch.size():
			var col := j % cols
			var row := j / cols
			var p := base + Vector2(
				(col - (cols - 1) * 0.5) * spacing.x,
				(row - 0.5) * spacing.y)
			var kind: String = batch[j]
			var e: Enemy
			if use_boss:
				e = Boss.make_boss(game, kind, p)
			else:
				e = Enemy.make(game, kind, p)
			game.add_enemy(e)
			e.set_physics_process(false)
			e.set_process(false)
			spawned.append(e)
			pins.append(p)
			labels.append(_label(kind, p + Vector2(-44, spacing.y * 0.18)))
		await _frames(5)
		# AI is game-driven — re-pin everyone to their grid cell right
		# before the frame so sprites sit under their labels.
		for j in spawned.size():
			var se: Enemy = spawned[j]
			if is_instance_valid(se):
				se.global_position = pins[j]
		await _frames(1)
		bi += 1
		_shot("lineup_%s_%02d" % [tag, bi])
		for e in spawned:
			if is_instance_valid(e):
				e.queue_free()
		for l in labels:
			l.queue_free()
		await _frames(2)
		i += batch_size


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)

	# --- boot flow: chapter select boots first under no_saves ---
	_shot("boot_chapter_select")
	game.menus.open_title()
	await _frames(6)
	_shot("boot_cover")
	game.menus.open_slots()
	await _frames(4)
	_shot("boot_roster")
	game.menus.open_chapter_select()
	await _frames(3)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	_shot("boot_class_select")
	game.menus.pick_class("warrior")
	await _frames(5)

	# --- opening dialogue (portrait check on the way through) ---
	var guard := 0
	var took_speaker := false
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if not took_speaker and game.hud.portrait_box.visible:
			took_speaker = true
			_shot("hud_dialogue")
		if game.hud.choices_active:
			_shot("hud_choices")
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0

	# --- world + HUD ---
	await _frames(10)
	_shot("world_village_hud")
	game.camera.zoom = Vector2(0.7, 0.7)
	await _frames(6)
	_shot("world_village_wide")
	game.camera.zoom = Vector2(1.0, 1.0)

	# combat readability: wolves + damage numbers + hp bars
	var base: Vector2 = game.player.global_position
	var wolves: Array = []
	for k in 3:
		var w := Enemy.make(game, "wolf", base + Vector2(120 + k * 60, (k - 1) * 70))
		game.add_enemy(w)
		wolves.append(w)
	await _frames(3)
	var w0: Enemy = wolves[0]
	w0.take_damage(37.0, Vector2.ZERO, true, false)
	await _frames(4)
	_shot("world_combat")
	for w in wolves:
		w.queue_free()
	await _frames(2)

	# --- terrain tour (zone 0 repainted per biome) ---
	var terrains: Array = ["village", "darkwood", "marsh", "keep", "magma",
		"ice", "graveyard", "desert", "bog", "crystal", "storm", "void",
		"holy", "spore"]
	game.camera.zoom = Vector2(0.7, 0.7)
	for t in terrains:
		game.apply_terrain(0, t)
		game.ambient.color = Terrains.get_terrain(t)["tint"]
		await _frames(8)
		_shot("terrain_%s" % t)
	game.camera.zoom = Vector2(1.0, 1.0)

	# --- full roster lineups: daylight floor + NEUTRAL light so sprite
	# colors read true (tinted ambience crushed the first pass) ---
	game.apply_terrain(0, "village")
	game.ambient.color = Color(1, 1, 1)
	await _frames(6)
	game.hud.visible = false
	game.player.visible = false
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.camera.zoom = Vector2(0.9, 0.9)
	var mobs: Array = []
	var bosses: Array = []
	var all_kinds: Array = Story.ALL_ENEMIES.keys()
	all_kinds.sort()
	for kind in all_kinds:
		var def: Dictionary = Story.ALL_ENEMIES[kind]
		if bool(def.get("boss", false)):
			bosses.append(kind)
		else:
			mobs.append(kind)
	print("ROSTER: %d mobs, %d bosses" % [mobs.size(), bosses.size()])
	await _lineup(mobs, "mobs", 6, Vector2(150.0, 190.0), false)
	game.camera.zoom = Vector2(0.72, 0.72)
	await _lineup(bosses, "bosses", 4, Vector2(240.0, 280.0), true)
	game.camera.zoom = Vector2(1.0, 1.0)
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.visible = true
	game.hud.visible = true

	# --- live boss fight frame (boss bar + arena FX) ---
	game.apply_terrain(0, "village")
	game.ambient.color = Terrains.get_terrain("village")["tint"]
	await _frames(4)
	if bosses.size() > 0:
		var bk: String = bosses[0]
		var b := Boss.make_boss(game, bk, game.player.global_position + Vector2(260, 0))
		game.add_enemy(b)
		await _frames(30)
		_shot("world_boss_fight_%s" % bk)
		b.queue_free()
		await _frames(2)

	# --- menu screens, core first ---
	game.menus.open_pause()
	await _menu_shot("pause")
	game.menus.open_settings("pause")
	await _menu_shot("settings")
	game.menus.close()
	game.menus.open_inventory("gear")
	await _menu_shot("inventory_gear")
	var eq: Array = game.player.equipment.values()
	if eq.size() > 0:
		game.menus.open_item_panel(eq[0])
		await _menu_shot("item_panel")
	game.menus.close()
	game.menus.open_skills("talents")
	await _menu_shot("skills_talents")
	game.menus.close()
	game.menus.open_shop(0)
	await _menu_shot("shop")
	game.menus.close()
	game.menus.open_map()
	await _menu_shot("map")
	game.menus.close()
	for ct in ["monsters", "bosses", "npcs", "terrains", "gear", "status", "records"]:
		game.menus.open_codex(ct)
		await _menu_shot("codex_%s" % ct)
	game.menus.open_codex("bosses", "fangmaw")
	await _menu_shot("codex_boss_detail")
	game.menus.close()

	# --- riskier screens last (state-dependent) ---
	game.menus.open_stash()
	await _menu_shot("stash")
	game.menus.close()
	game.menus.open_journal()
	await _menu_shot("journal")
	game.menus.close()
	game.menus.open_daily()
	await _menu_shot("daily")
	game.menus.close()
	game.menus.open_mailbox()
	await _menu_shot("mailbox")
	game.menus.close()
	game.menus.open_keybinds()
	await _menu_shot("keybinds")
	game.menus.close()
	game.menus.open_dev()
	await _menu_shot("dev_panel")
	game.menus.close()

	print("AUDIT DONE: %d shots -> %s" % [shot_count,
		ProjectSettings.globalize_path("user://shots/audit")])
	get_tree().quit(0)
