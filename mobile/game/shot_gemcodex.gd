extends Node
## GEM-SOCKET + CODEX SHOT RIG (dev tool, not part of the game): boots the real
## game, equips an S-grade weapon with all three sockets FILLED (2 regular +
## 1 special) so the inventory's equipped-gear socket row shows real gem art,
## then walks EVERY codex tab and screenshots each one for a density audit.
## Run:  godot --path game --audio-driver Dummy res://shot_gemcodex.tscn
##       (windowed rigs run MUTED — CLAUDE.md; the owner shares the machine)
## Output: user://shots/gemcodex/*.png (absolute paths printed)

var game: Game
var shot_count := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/gemcodex"))
	img.save_png(ProjectSettings.globalize_path("user://shots/gemcodex/%s.png" % nm))
	shot_count += 1
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/gemcodex/%s.png" % nm))


func _menu_shot(nm: String) -> void:
	await _frames(6)
	_shot(nm)


## Count the leaf content controls under the codex content scroll(s) so
## density is a number, not an impression: cards, labels, buttons, textures,
## plus (rail + ledger layout, 2026-08-15) the ledger's row count and how
## many of those rows fit without scrolling.
func _codex_stats() -> Dictionary:
	var out := {"cards": 0, "labels": 0, "buttons": 0, "textures": 0, "list_h": 0.0, "rows": 0, "rows_fit": 0}
	var root: Node = game.menus.root
	if root == null:
		return out
	var detail := root.find_child("CodexDetail", true, false) as ScrollContainer
	var sc: ScrollContainer = detail
	if sc == null:
		var scrolls := root.find_children("*", "ScrollContainer", true, false)
		if scrolls.is_empty():
			return out
		sc = scrolls[scrolls.size() - 1]
	if sc.get_child_count() == 0:
		return out
	var list: Control = sc.get_child(0)
	out["list_h"] = list.size.y
	for c in list.find_children("*", "", true, false):
		if c is PanelContainer:
			out["cards"] += 1
		elif c is Label or c is RichTextLabel:
			out["labels"] += 1
		elif c is Button:
			out["buttons"] += 1
		elif c is TextureRect:
			out["textures"] += 1
	var ledger := root.find_child("CodexLedger", true, false) as ScrollContainer
	if ledger != null and ledger.get_child_count() > 0:
		var rows := 0
		for c in ledger.get_child(0).get_children():
			if c is Button:
				rows += 1
		out["rows"] = rows
		out["rows_fit"] = int(ledger.size.y / 44.0)
	return out


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)

	game.menus.open_title()
	await _frames(4)
	game.menus.open_slots()
	await _frames(3)
	game.menus.open_chapter_select()
	await _frames(3)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class("warrior")
	await _frames(5)
	game.hud.visible = true
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.play_started = true
	game.hud.visible = true
	await get_tree().create_timer(1.0).timeout

	# --- the reported view: equipped gear with every socket filled ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260815
	var itm := Items.roll_item_of("weapon", "S", rng, "warrior")
	itm["gem_slots"] = 3
	itm["gems"] = [Items.make_gem("crit", 5), Items.make_gem("hp_flat", 9), Items.make_gem("dmg_pct", 10)]
	game.player.equip(itm)
	var arm := Items.roll_item_of("armor", "A", rng, "warrior")
	arm["gem_slots"] = 2
	arm["gems"] = [Items.make_gem("eva", 10), Items.make_gem("cdr", 5)]
	game.player.equip(arm)
	var helm := Items.roll_item_of("helmet", "B", rng, "warrior")
	helm["gem_slots"] = 1
	helm["gems"] = [Items.make_gem("physpen", 8)]
	game.player.equip(helm)
	# A bag full of one of every family so the gem grid renders too.
	for stat_key in Items.GEM_STATS:
		game.player.gain_gem(Items.make_gem(String(stat_key), 1))
		game.player.gain_gem(Items.make_gem(String(stat_key), 6))
	game.menus.open_inventory("gear")
	await _menu_shot("inventory_gear_sockets")
	# Potions tab: a couple of bottles, one assigned.
	var mana := Items.make_potion("mana", "instant", "C", "accord")
	game.player.add_consumable(mana)
	game.player.add_consumable(Items.make_potion("mana", "instant", "C", "accord"))
	game.player.add_consumable(Items.make_potion("might", "buff", "B", "accord"))
	game.player.loadout_add(String(mana["id"]))
	game.menus.open_inventory("potions")
	await _menu_shot("inventory_potions")
	game.menus.open_inventory("gear", "gems")
	await _menu_shot("inventory_gems_bag")
	game.menus.open_item_panel(itm, Vector2(-1, -1), "gems")
	await _menu_shot("item_panel_gems")
	game.menus.close()
	await _frames(2)
	# The Lapidary paths (Crownfall only): a bag gem's card offers "Socket
	# into <piece>", and the item card's Gems tab shows the bag as tiles.
	var keep_ch := game.chapter_id
	game.chapter_id = "capital"
	game.menus.open_inventory("gear", "gems")
	await _frames(6)
	var grid_btn: Button = null
	for c in game.menus.root.find_children("*", "Button", true, false):
		if (c as Button).icon != null and (c as Button).custom_minimum_size == Vector2(48, 48):
			grid_btn = c
			break
	if grid_btn != null:
		grid_btn.pressed.emit()
		await _menu_shot("inventory_gem_card_capital")
	game.menus.open_item_panel(itm, Vector2(-1, -1), "gems")
	await _menu_shot("item_panel_gems_capital")
	game.menus.close()
	game.chapter_id = keep_ch
	await _frames(2)
	game.menus.open_codex("story")
	await _menu_shot("codex_story")
	game.menus.close()

	# --- every codex tab, with a content census ---
	var tabs := ["monsters", "bosses", "npcs",
		"gear_shapes", "gear_shapes_helmet", "gear_uniques", "gear_gems", "gear_bags", "gear_rules",
		"terrains", "curios", "status", "records", "gallery_heroes", "gallery_bosses", "gallery_npcs", "coop",
		"notes_elites", "notes_gems"]
	for t in tabs:
		game.menus.open_codex(String(t))
		# Streamed shelves land a few cards per frame; give them time to fill.
		await _frames(40)
		var st := _codex_stats()
		print("CODEX %-20s cards=%3d labels=%4d buttons=%3d textures=%3d list_h=%d rows=%d fit=%d" % [
			t, st["cards"], st["labels"], st["buttons"], st["textures"], int(st["list_h"]), st["rows"], st["rows_fit"]])
		_shot("codex_" + String(t))
		game.menus.close()
		await _frames(2)
	# The boss route (room banner / records → a boss's card): selects the row
	# and opens the Mechanics & Tells fold in place.
	game.menus.open_codex("bosses", "fangmaw")
	await _frames(20)
	_shot("codex_boss_route_fangmaw")
	game.menus.close()
	await _frames(2)

	# --- interactions the suites don't drive: chips, search, row select, rail ---
	game.menus.open_codex("monsters")
	await _frames(10)
	var chip := _find_button("CodexChips", "Ch 2")
	print("INTERACT chip Ch2 found=", chip != null)
	if chip != null:
		chip.pressed.emit()
		await _frames(4)
		print("INTERACT after Ch2 chip rows=", _codex_stats()["rows"], " (expect 12)")
	var search := game.menus.root.find_child("CodexSearch", true, false) as LineEdit
	print("INTERACT search found=", search != null)
	if search != null:
		search.text = "wolf"
		search.text_changed.emit("wolf")
		await _frames(4)
		print("INTERACT after search 'wolf' rows=", _codex_stats()["rows"], " (expect 1: Waking Wolf in Ch2)")
		search.text = ""
		search.text_changed.emit("")
		await _frames(4)
	var all_chip := _find_button("CodexChips", "All")
	if all_chip != null:
		all_chip.pressed.emit()
		await _frames(4)
	var ledger := game.menus.root.find_child("CodexLedger", true, false) as ScrollContainer
	if ledger != null and ledger.get_child(0).get_child_count() > 2:
		var second: Button = ledger.get_child(0).get_child(1)
		second.pressed.emit()
		await _frames(3)
		var det := game.menus.root.find_child("CodexDetail", true, false) as ScrollContainer
		var det_txt := ""
		for l in det.find_children("*", "Label", true, false):
			det_txt += (l as Label).text + " | "
			if det_txt.length() > 80:
				break
		print("INTERACT selected row 2 (", String(second.get_meta("key")), ") detail: ", det_txt.substr(0, 80))
	_shot("codex_interact_monsters")
	# Rail → Gallery → Bosses shelf chip.
	var rail_btn := game.menus.root.find_child("CodexRail_gallery", true, false) as Button
	print("INTERACT rail Gallery found=", rail_btn != null)
	if rail_btn != null:
		rail_btn.pressed.emit()
		await _frames(6)
		var shelf_chip := _find_button("CodexChips", "Bosses")
		if shelf_chip != null:
			shelf_chip.pressed.emit()
			await _frames(6)
		print("INTERACT gallery shelf title: ", (game.menus.root.find_child("CodexBar", true, false).get_child(0) as Label).text)
		_shot("codex_interact_gallery_bosses")
	# Bare reopen lands where the reader left off.
	game.menus.close()
	await _frames(2)
	game.menus.open_codex()
	await _frames(6)
	print("INTERACT bare reopen title: ", (game.menus.root.find_child("CodexBar", true, false).get_child(0) as Label).text, " (expect Gallery · Bosses)")
	game.menus.close()
	await _frames(2)

	# --- Daily Reward: unclaimed (Day 1 stands lit), then the claim receipt ---
	game.menus.open_daily()
	await _menu_shot("daily_unclaimed")
	game.menus.close()
	await _frames(2)
	game.daily_streak = 4
	game.daily_last_day = game.daily_day_index() - 1  # yesterday claimed → today lands on Day 5
	game.menus.open_daily()
	await _menu_shot("daily_day5_unclaimed")
	var lines: Array = game.claim_daily()
	UIDaily.open(game.menus, lines)
	await _menu_shot("daily_claimed")
	game.menus.close()


func _find_button(container_name: String, text: String) -> Button:
	var box := game.menus.root.find_child(container_name, true, false)
	if box == null:
		return null
	for c in box.get_children():
		if c is Button and (c as Button).text.strip_edges() == text:
			return c
	return null

	print("GEMCODEX SHOTS DONE: %d -> %s" % [shot_count,
		ProjectSettings.globalize_path("user://shots/gemcodex")])
	get_tree().quit(0)
