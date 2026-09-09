extends ShotRig
## Controlled retained-callback proof against the EXISTING Professions UI.
## No Alchemy dependency. --baseline records only enumerated known findings.


func _ready() -> void:
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/profession-lifetime-native-candidate/"):
		push_error("Use isolated APPDATA underneath profession-lifetime-native-candidate")
		return finish(1)
	var probe_script := preload("res://scripts/tests/profession_lifetime_live.gd")
	var files: Dictionary = probe_script.snapshot_files()
	await boot("warrior", "ch1")
	game.enter_capital()
	await frames(12)
	await skip_dialogue()
	game.menus.close()
	await frames(3)
	var result: Dictionary = await probe_script.run(self)
	var restored: bool = probe_script.restore_files(files)
	result.files_restored = restored
	if not restored:
		result.failures += 1
	result.status = "fixture_failed" if int(result.failures) > 0 else "baseline_findings" if bool(result.baseline) and int(result.findings) > 0 else "baseline_no_findings" if bool(result.baseline) else "passed"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var output := FileAccess.open(shot_dir.path_join("report.json"), FileAccess.WRITE)
	if output == null:
		push_error("Could not write Professions lifetime report")
		return finish(1)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("PROFESSIONS LIFETIME: status=%s checks=%d passed=%d findings=%d failures=%d positive_actions=%d retained_callbacks=%d files_restored=%s" % [
		result.status, result.checks, result.passed, result.findings, result.failures,
		result.positive_actions, result.retained_callbacks, str(result.files_restored)])
	if flag("baseline"):
		print("BASELINE ONLY: controlled retained callbacks; no regression pass or ordinary-click exploit claimed")
	finish(1 if int(result.failures) > 0 else 0)
