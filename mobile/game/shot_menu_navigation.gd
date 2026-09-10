extends ShotRig
## Native menu input and cancellation regression proof.
## shot.bat menu_navigation --timeout=300 [--baseline] [--no-capture]
## Baseline records known navigation defects; input/fixture failures stay fatal.


func _ready() -> void:
	await boot_game()
	shot_dir += "/" + ("before" if flag("baseline") else "after")
	var result: Dictionary
	if flag("settings-touch"):
		shot_dir += "/settings_touch"
		result = await preload("res://scripts/tests/settings_touch_live.gd").run(self)
	else:
		result = await preload("res://scripts/tests/menu_navigation_live.gd").run(self)
	print("MENU NAVIGATION: checks=%d passed=%d findings=%d failures=%d mouse=%d touch=%d keys=%d wheel=%d gamepad=%d" % [
		result.checks, result.passed, result.findings, result.failures,
		result.mouse_clicks, result.touch_taps, result.key_taps, result.wheel_taps, result.gamepad_taps])
	finish(1 if int(result.failures) > 0 else 0)
