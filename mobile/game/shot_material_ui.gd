extends ShotRig
## Three-material pilot comparison, against the same 32px world baseline.
## shot.bat material_ui --timeout=180 [--baseline] [--no-capture] [--grade-pairs]
## Optional grade pairs add four E/D sibling checks and three native captures.


func _ready() -> void:
	await boot("warrior", "ch1")
	game.enter_capital()
	await frames(12)
	await skip_dialogue()
	shot_dir += "/" + ("before" if flag("baseline") else "after")
	var result: Dictionary = await preload("res://scripts/tests/material_ui_live.gd").run(self)
	print("MATERIAL UI: checks=%d passed=%d findings=%d failures=%d" % [result.checks, result.passed, result.findings, result.failures])
	finish(1 if int(result.failures) > 0 else 0)
