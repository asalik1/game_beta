extends RefCounted
## One engine, one machine lock: fresh menu captures, then the quick tier's
## systems/UI smoke/pause sections. That second half is NOT the quick tier
## (windowed, after the captures); test_quick.bat stays the only quick evidence.
class QuickSuite extends "res://scripts/autotest.gd":
	func _ready() -> void: pass


static func run(rig: Node) -> String:
	await rig.boot("warrior", "ch1", false)
	var g: Game = rig.game
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.menus.close()
	g.request_pause(false)
	g.hud.visible = true
	await rig.skip_dialogue()
	if not await rig._settled(): return "fresh capture boot did not settle"
	var window: Window = rig.get_window()
	var saved_window := [window.size, window.content_scale_size, window.content_scale_aspect]
	var saved_settings := g.settings.duplicate(true)
	var saved_player := {}
	for key in ["equipment", "backpack", "gem_bag", "consumables", "bags", "gold"]:
		var value: Variant = g.local_player.get(key)
		saved_player[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	var saved_chapter := g.chapter_id
	var saved_daily := [g.daily_last_day, g.daily_streak]
	var error := await _captures(rig)
	g.menus.close()
	for key in saved_player: g.local_player.set(key, saved_player[key])
	g.chapter_id = saved_chapter
	g.daily_last_day = saved_daily[0]
	g.daily_streak = saved_daily[1]
	g.settings = saved_settings
	g.refresh_touch_mode()
	g._apply_touch_mode()
	window.content_scale_aspect = saved_window[2]
	window.content_scale_size = saved_window[1]
	window.size = saved_window[0]
	if error == "": print("FORGED FRAME CAPTURES COMPLETE: desktop, touch, 4:3 letterbox, tall 1280x960 canvas; bag/stats/codex/pause/settings/shop/daily/forge/alchemy/activity/HUD")
	# Release the capture world before the suite boots its controlled campaign.
	rig.game.free()
	rig.game = null
	rig.get_tree().paused = false
	await rig.frames(3)
	if error != "": return error
	var suite := QuickSuite.new()
	suite.quick = true
	suite.process_mode = Node.PROCESS_MODE_ALWAYS
	rig.add_child(suite)
	await suite._run_systems()
	if suite._failed: return "quick systems/UI smoke failed"
	await suite._test_pause_menu()
	if suite._failed: return "quick pause menu failed"
	# Not the quick tier (windowed, after the captures): never its pass marker.
	print("FORGED FRAME BUNDLE PASS (systems, UI smoke and pause after the captures)")
	suite.free()
	rig.get_tree().paused = false
	await rig.frames(3)
	return ""


static func _captures(rig: Node) -> String:
	var g: Game = rig.game
	var m := g.menus
	var p := g.local_player
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	p.backpack = []
	p.gem_bag = []
	p.consumables = []
	p.equipment = {}
	p.bags = [Items.make_bag("S"), Items.make_bag("S")]
	p.gold = 5000
	for i in Items.GRADES.size():
		var grade: String = Items.GRADES[i]
		var item := Items.roll_item_of(Items.SLOTS[i], grade, rng, "warrior")
		p.equipment[Items.SLOTS[i]] = item
		p.backpack.append(Items.roll_item_of("weapon", grade, rng, "warrior"))
	g.daily_last_day = g.daily_day_index() - 1
	g.daily_streak = 2
	m.shell_motion = false
	var window: Window = rig.get_window()
	# [name, window, logical canvas, touch]. Canvases the game really produces:
	# a 4:3 window letterboxes the 1280x720 canvas (stretch aspect KEEP), and a
	# taller 1280-wide canvas is what mobile's aspect expand gives on 4:3 tablets
	# (the reward_plaque_live convention). Never a logical width under 1280.
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for view in [["desktop", Vector2i(1280, 720), Vector2i(1280, 720), false],
			["touch", Vector2i(1280, 720), Vector2i(1280, 720), true],
			["four_three", Vector2i(1024, 768), Vector2i(1280, 720), false],
			["tall_touch", Vector2i(1280, 960), Vector2i(1280, 960), true]]:
		m.close()
		window.content_scale_size = view[2]
		window.size = view[1]
		g.settings["touch_controls"] = view[3]
		g.settings["touch_layout"] = {}
		g.refresh_touch_mode()
		g._apply_touch_mode()
		await rig.frames(5)
		# Pin the tracked-quest copy so every view contains the same HUD fixture.
		g.hud.wayfinder.set_process(false)
		g.hud.wayfinder.quest_root.show()
		g.hud.wayfinder.quest_title.text = "Tracked quest"
		g.hud.wayfinder.quest_objective.text = "Follow the road to the next refuge."
		g.hud.wayfinder.quest_location.text = "Frame capture fixture"
		await _capture(rig, String(view[0]) + "_hud")
		var chapter := g.chapter_id
		for screen in ["bag", "stats", "codex", "pause", "settings", "shop", "daily", "forge", "alchemy", "activity"]:
			match screen:
				"bag": m.open_inventory()
				"stats": m.open_inventory("stats")
				"codex": m.open_codex("gear")
				"pause": m.open_pause()
				"settings": m.open_settings("pause")  # slider fill and scroll thumb
				"shop": m.open_shop(0)
				"daily": m.open_daily()
				"forge":
					m.open_inventory()
					# Synthetic bench context; no travel or forge transaction.
					g.chapter_id = "capital"
					m.open_item_panel(p.equipment.weapon, Vector2(-1, -1), "reforge")
				"alchemy": m.open_alchemy()
				"activity": m.open_journal("activities")
			await rig.frames(4)
			if not m.is_open(): return screen + " did not open for " + String(view[0])
			await _capture(rig, String(view[0]) + "_" + screen)
			m.close()
			g.chapter_id = chapter
			await rig.frames(2)
	return ""


static func _capture(rig: Node, label: String) -> void:
	await rig.frames(3)
	await RenderingServer.frame_post_draw
	rig.shot(label)
