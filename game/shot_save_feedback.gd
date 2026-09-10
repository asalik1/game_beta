extends ShotRig
## Real filesystem fault, isolated files, normal Alchemy input and autosave.
## --baseline permits missing feedback only; persistence/ownership stay strict.
const Probe := preload("res://scripts/tests/save_feedback_live.gd")


func _ready() -> void:
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/save-feedback-candidate/"):
		push_error("Use isolated APPDATA underneath save-feedback-candidate")
		return finish(1)
	var files: Dictionary = Probe.snapshot_files()
	if files.is_empty():
		push_error("Save feedback fixture refused an existing target directory")
		return finish(1)
	await boot("warrior", "ch1")
	game.enter_capital()
	await frames(12)
	await skip_dialogue()
	game.menus.close()
	await frames(3)
	var result: Dictionary = await Probe.run(self)
	game.no_saves = true
	var restored: bool = Probe.restore_files(files)
	result.files_restored = restored
	if not restored:
		result.failures += 1
	result.status = "fixture_failed" if int(result.failures) > 0 else "baseline_findings" if int(result.findings) > 0 else "passed"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var output := FileAccess.open(shot_dir.path_join("report.json"), FileAccess.WRITE)
	if output == null:
		push_error("Could not write save feedback report")
		return finish(1)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("SAVE FEEDBACK: status=%s checks=%d passed=%d findings=%d failures=%d files_restored=%s" % [
		result.status, result.checks, result.passed, result.findings, result.failures, str(restored)])
	finish(1 if int(result.failures) > 0 else 0)
