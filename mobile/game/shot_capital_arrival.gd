extends ShotRig
## One normal solo arrival: real Pause travel, live idle and keyboard escape.
## shot.bat capital_arrival --timeout=120 --baseline

var arrival_probe


func _ready() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_path.contains("/capital-arrival-native-candidate/"):
		print("CAPITAL ARRIVAL REFUSAL: isolated capital-arrival-native-candidate APPDATA required")
		finish(1)
		return
	if flag("menu-binding-copy") and (flag("menu-shortcuts") or flag("baseline") or flag("npc-prompt") or flag("npc-prompt-controls") or flag("fountain-prompt") or flag("fountain-after") or flag("arrival-consumers") or flag("no-capture") or flag("touch") or OS.has_feature("mobile")):
		print("Menu binding copy requires isolated host mode without forced touch; actual Controls toggle is exercised later")
		finish(1)
		return
	if flag("menu-shortcuts") and (flag("baseline") or flag("npc-prompt") or flag("fountain-prompt") or flag("arrival-consumers") or flag("no-capture")):
		print("Menu shortcuts requires its isolated strict mode")
		finish(1)
		return
	if flag("npc-prompt-controls") and not flag("npc-prompt"):
		print("NPC prompt controls require npc-prompt")
		finish(1)
		return
	if flag("npc-prompt") and (flag("baseline") or flag("fountain-prompt") or flag("arrival-consumers") or flag("no-capture")):
		print("NPC prompt requires its isolated strict diagnostic mode")
		finish(1)
		return
	shot_dir += "/" + ("before" if flag("baseline") else "after")
	if flag("menu-binding-copy"):
		shot_dir += "/menu_binding_copy"
	if flag("menu-shortcuts"):
		shot_dir += "/menu_shortcuts"
	if flag("npc-prompt"):
		shot_dir += "/npc_prompt"
	if flag("fountain-prompt"):
		shot_dir += "/fountain_prompt"
	await boot("mage", "ch1", false)
	arrival_probe = preload("res://scripts/tests/capital_arrival_live.gd").new()
	var result: Dictionary = await arrival_probe.run(self)
	var path := ProjectSettings.globalize_path(shot_dir.path_join("report.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("CAPITAL ARRIVAL: report could not be written")
		finish(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("CAPITAL ARRIVAL: checks=%d passed=%d findings=%d failures=%d samples=%d captures=%d report=%s" % [
		result.checks, result.passed, result.findings, result.failures,
		result.samples.size(), shots_taken, path])
	finish(1 if int(result.failures) > 0 else 0)


func _physics_process(delta: float) -> void:
	if arrival_probe != null:
		arrival_probe.physics_tick(delta)
