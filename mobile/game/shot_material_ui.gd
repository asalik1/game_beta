extends ShotRig
## Three-material pilot comparison, against the same 32px world baseline.
## shot.bat material_ui --timeout=180 [--baseline] [--no-capture] [--grade-pairs]
## Optional grade pairs add four E/D sibling checks and three native captures.
## --all-brewing retains those nine views, adds all13 inventory + C/B/A previews.
## Exact approval constants are prepared only from six reviewed upper records.


func _ready() -> void:
	if flag("gear-fidelity") and not flag("inventory-readability"):
		push_error("Gear fidelity requires the Inventory readability mode")
		finish(1)
		return
	if flag("inventory-readability"):
		var isolated: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
		if not isolated.contains("/build/qa/") or flag("no-capture") or flag("baseline") or flag("gear-pilots") or flag("grade-pairs") or flag("all-brewing") or flag("world-prompts"):
			push_error("Inventory readability requires an isolated build/qa profile, captures, and no other material mode")
			finish(1)
			return
	await boot("warrior", "ch1")
	game.enter_capital()
	await frames(12)
	await skip_dialogue()
	if flag("inventory-readability"):
		shot_dir += "/inventory_readability"
		var proof: Dictionary = await preload("res://scripts/tests/inventory_readability_live.gd").run(self)
		print("INVENTORY READABILITY: checks=%d passed=%d findings=%d failures=%d" % [proof.checks, proof.passed, proof.findings, proof.failures])
		finish(1 if int(proof.failures) > 0 else 0)
		return
	shot_dir += "/" + ("before" if flag("baseline") else "after")
	var result: Dictionary = await preload("res://scripts/tests/material_ui_live.gd").run(self)
	print("MATERIAL UI: checks=%d passed=%d findings=%d failures=%d" % [result.checks, result.passed, result.findings, result.failures])
	finish(1 if int(result.failures) > 0 else 0)
