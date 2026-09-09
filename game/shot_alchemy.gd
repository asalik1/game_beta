extends ShotRig
## Native Alchemy review with controlled fixture resources; never ordinary loot.
## shot.bat alchemy --timeout=240 [--no-capture]


func _ready() -> void:
	await boot("warrior", "ch1")
	step("real Crownfall world")
	game.enter_capital()
	await frames(12)
	await skip_dialogue()
	var result: Dictionary = await preload("res://scripts/tests/alchemy_live.gd").run(self)
	print("ALCHEMY NATIVE: checks=%d passed=%d failures=%d mouse=%d touch=%d keys=%d wheel=%d gamepad=%d" % [
		result.checks, result.passed, result.failures, result.mouse_clicks,
		result.touch_taps, result.key_taps, result.wheel_taps, result.gamepad_taps])
	finish(1 if int(result.failures) > 0 else 0)
