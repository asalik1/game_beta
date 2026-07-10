extends Node
## UI-THEME SHOT RIG (dev tool, not part of the game): trimmed copy of
## shot_audit.gd — boot flow + HUD + every menu screen only (no terrain
## tour, no roster lineups), for fast theme-pass iteration.
## Run:  godot --path game res://shot_ui.tscn
## Output: user://shots/ui/*.png (absolute paths printed)

var game: Game
var shot_count := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/ui"))
	img.save_png(ProjectSettings.globalize_path("user://shots/ui/%s.png" % nm))
	shot_count += 1
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/ui/%s.png" % nm))


func _menu_shot(nm: String) -> void:
	await _frames(4)
	_shot("menu_%s" % nm)


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)

	# --- boot flow ---
	game.menus.open_title()
	await _frames(6)
	_shot("boot_cover")
	game.menus.open_slots()
	await _frames(4)
	_shot("boot_roster")
	game.menus.open_chapter_select()
	await _frames(4)
	_shot("boot_chapter_select")
	game.menus.pick_chapter("ch1")
	await _frames(3)
	_shot("boot_class_select")
	game.menus.pick_class("warrior")
	await _frames(5)

	# --- skip opening dialogue, keep one frame of it ---
	# A scripted skip outruns the cutscene's wall-clock finish fade — force
	# the play state the way it would have been left before shooting HUD frames.
	game.hud.visible = true
	var guard := 0
	var took_speaker := false
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if not took_speaker and game.hud.portrait_box.visible:
			took_speaker = true
			await _frames(4)
			_shot("hud_dialogue")
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.play_started = true
	game.hud.visible = true

	# --- live HUD (village = the bright state) ---
	await get_tree().create_timer(2.5).timeout  # let the title card fade
	await _frames(4)
	_shot("hud_village")
	game.hud.show_boss_bar("Ashpriest, Voice of the Pyre")
	game.hud.update_boss_bar(0.72)
	await _frames(2)
	_shot("hud_boss_bar")
	game.hud.hide_boss_bar()
	# Half-spent resources so the in-bar numbers show real fractions.
	game.player.hp = game.player.max_hp * 0.55
	game.player.mp = game.player.max_mp * 0.4
	await _frames(3)
	_shot("hud_bars_half")
	game.player.hp = game.player.max_hp
	game.player.mp = game.player.max_mp

	# --- menu screens ---
	game.menus.open_pause()
	await _menu_shot("pause")
	game.menus.open_settings("pause")
	await _menu_shot("settings")
	game.menus.close()
	# Equip a rolled piece so the inventory left column + item panel
	# (popover chrome, gem sockets) have something real to show.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260709
	var itm := Items.roll_item_of("weapon", "B", rng, "warrior")
	itm["gem_slots"] = 2
	game.player.equip(itm)
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
	game.menus.open_codex("bosses")
	await _menu_shot("codex_bosses")
	game.menus.close()
	# Straggler screens (2026-07-10 audit): npcs, records, map, mailbox, stash.
	game.menus.open_codex("npcs")
	await _menu_shot("codex_npcs")
	game.menus.close()
	game.menus.open_codex("records")
	await _menu_shot("codex_records")
	game.menus.close()
	game.menus.open_map()
	await _menu_shot("map")
	game.menus.close()
	game.menus.open_mailbox()
	await _menu_shot("mailbox")
	game.menus.close()
	game.menus.open_stash()
	await _menu_shot("stash")
	game.menus.close()
	game.menus.open_keybinds()
	await _menu_shot("keybinds")
	game.menus.close()
	game.menus.open_journal()
	await _menu_shot("journal")
	game.menus.close()

	print("UI SHOTS DONE: %d -> %s" % [shot_count,
		ProjectSettings.globalize_path("user://shots/ui")])
	get_tree().quit(0)
