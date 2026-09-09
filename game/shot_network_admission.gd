extends ShotRig
## Actual NetworkManager admission in one engine; no Game, Noray or subprocess.
const Probe := preload("res://scripts/tests/network_admission_live.gd")


func _ready() -> void:
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/network-admission-candidate/"):
		push_error("Use isolated APPDATA underneath network-admission-candidate")
		return finish(1)
	var result: Dictionary = await Probe.run(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var output := FileAccess.open(shot_dir.path_join("report.json"), FileAccess.WRITE)
	if output == null:
		push_error("Could not write network admission report")
		return finish(1)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("NETWORK ADMISSION: status=%s current=%s prior=%s checks=%d passed=%d failures=%d engine_pid=%d" % [
		result.status, result.current_version, result.prior_version, result.checks,
		result.passed, result.failures, result.engine_pid])
	finish(1 if int(result.failures) > 0 else 0)
