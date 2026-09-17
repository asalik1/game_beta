extends ShotRig
## Gem regen showcase (2026-08-21, owner fidelity ruling): the codex Gems page +
## a max-level gem detail popover now serve the 128px gem_codex_icon masters.
## Run:  shot.bat gems
func _ready() -> void:
	if flag("synthesis-caps"):
		var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
		if not user_path.to_lower().contains("/build/qa/"):
			print("GEM CAPS FAILED: isolated build/qa APPDATA required")
			finish(1)
			return
		await boot("warrior", "ch1", false)
		game.play_started = true
		game.state = Game.ST_PLAYING
		game.menus.close()
		game.request_pause(false)
		game.enter_capital()
		await frames(6)
		await skip_dialogue()
		var error: String = await preload("res://scripts/tests/gem_synthesis_caps_live.gd").run(self)
		if error != "": print("GEM CAPS FAILED: ", error)
		finish(0 if error == "" else 1)
		return
	if flag("equip-touch"):
		var qa_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
		if not qa_path.to_lower().contains("/build/qa/"):
			print("EQUIP TOUCH FAILED: isolated build/qa APPDATA required")
			finish(1)
			return
		await boot("warrior", "ch1", false)
		game.play_started = true
		game.state = Game.ST_PLAYING
		game.menus.close()
		game.request_pause(false)
		game.enter_capital()
		await frames(6)
		await skip_dialogue()
		var touch_error: String = await preload("res://scripts/tests/equip_touch_live.gd").run(self)
		if touch_error != "": print("EQUIP TOUCH FAILED: ", touch_error)
		finish(0 if touch_error == "" else 1)
		return
	await boot("warrior", "ch1")
	hide_hud()
	game.menus.open_codex("gems")
	await frames(6)
	shot("01_codex_gems")
	game.menus.open_inventory("gear", "gems")
	await frames(4)
	var g := Items.make_gem("magpen", 10)
	game.menus._open_detail_popover(Art.gem_codex_icon(Items.gem_color(g), 10),
		Items.gem_title(g), Items.gem_color(g),
		"A perfected regular gem. Requires S-grade gear with an available regular socket.",
		[], GearFlavor.of(g))
	await frames(6)
	shot("02_gem_popover")
	finish()
