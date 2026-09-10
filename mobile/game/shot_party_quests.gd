extends ShotRig
## One engine, real ENet, controlled quest state. No ordinary combat claim.
const Pair := preload("res://scripts/tests/party_quest_pair.gd")
const Probe := preload("res://scripts/tests/party_quests_live.gd")


func _ready() -> void:
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/party-quest-refresh-candidate/"):
		push_error("Party quest rig requires isolated APPDATA under party-quest-refresh-candidate")
		return finish(1)
	var files := {}
	for base in [SaveGame.path(97), SaveGame.path(98), SaveGame.path(99), "user://meta.json"]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = String(base) + String(suffix)
			files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var language := Loc.lang
	Loc.lang = "en"
	var pair := Pair.new()
	pair.owner_rig = self
	pair.shot_dir = shot_dir
	add_child(pair)
	var error := await pair.boot_pair()
	game = pair.game
	if error == "":
		error = await Probe.run(pair)
	else:
		await pair._capture("fixture_setup_failed")
	pair.stop_pair()
	get_tree().paused = false
	var restored := true
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				restored = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and restored
		else:
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				restored = false
			else:
				output.store_buffer(files[path])
				output.close()
		var actual: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		restored = actual == files[path] and restored
	Loc.lang = language
	if not restored: error += " outer fixture save/meta bytes did not restore"
	print("PARTY QUEST ENTRY: ", JSON.stringify({"error": error, "outer_files_restored": restored,
		"baseline": flag("baseline"), "ordinary_input_gameplay": false, "real_enet": true}))
	if error != "":
		push_error(error)
		return finish(1)
	finish()
