extends ShotRig
## Native menu input and cancellation regression proof.
## shot.bat menu_navigation --timeout=300 [--baseline] [--no-capture] [--potion-slots] [--confirm-layout]
## Baseline records known navigation defects; input/fixture failures stay fatal.


func _ready() -> void:
	if flag("confirm-layout"):
		var confirm_user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
		if not confirm_user_root.contains("/build/qa/") or flag("baseline") or flag("no-capture") \
				or flag("potion-slots") or flag("comfort-retention") or flag("quest-guardian") or flag("settings-touch"):
			print("CONFIRM LAYOUT FAILED: isolated build/qa APPDATA and exclusive strict capture mode required")
			finish(1)
			return
	if flag("comfort-retention"):
		var comfort_user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
		if not comfort_user_root.contains("/build/qa/"):
			print("COMFORT RETENTION FAILED: fresh isolated build/qa APPDATA required")
			finish(1)
			return
		await boot_game()
		shot_dir += "/comfort_retention"
		var comfort_result: Dictionary = await preload("res://scripts/tests/comfort_retention_live.gd").run(self)
		print("COMFORT RETENTION: ", JSON.stringify(comfort_result))
		finish(1 if int(comfort_result.failures) > 0 else 0)
		return
	if flag("quest-guardian"):
		var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
		if not user_root.contains("/build/qa/"):
			print("QUEST GUARDIAN FAILED: isolated build/qa APPDATA required")
			finish(1)
			return
		await boot("warrior", "ch1", false)
		game.play_started = true
		game.state = Game.ST_PLAYING
		game.menus.close()
		game.request_pause(false)
		game.hud.visible = true
		game.settings["touch_controls"] = flag("touch")
		game.refresh_touch_mode()
		game._apply_touch_mode()
		shot_dir += "/quest_guardian"
		var guardian_result: Dictionary = await preload("res://scripts/tests/quest_guardian_live.gd").run(self)
		print("QUEST GUARDIAN: ", JSON.stringify(guardian_result))
		finish(1 if int(guardian_result.failures) > 0 else 0)
		return
	await boot_game()
	shot_dir += "/" + ("before" if flag("baseline") else "after")
	if flag("potion-slots"):
		shot_dir += "/potion_slots"
	if flag("confirm-layout"):
		shot_dir += "/confirm_layout"
	var result: Dictionary
	if flag("settings-touch") and not flag("potion-slots"):
		shot_dir += "/settings_touch"
		result = await preload("res://scripts/tests/settings_touch_live.gd").run(self)
	else:
		result = await preload("res://scripts/tests/menu_navigation_live.gd").run(self)
	print("MENU NAVIGATION: checks=%d passed=%d findings=%d failures=%d mouse=%d touch=%d keys=%d wheel=%d gamepad=%d" % [
		result.checks, result.passed, result.findings, result.failures,
		result.mouse_clicks, result.touch_taps, result.key_taps, result.wheel_taps, result.gamepad_taps])
	finish(1 if int(result.failures) > 0 else 0)
