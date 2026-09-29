extends RefCounted
## Real save/read/apply with a disposable hero, following test_character_history.
const SLOT := 96

class MemoryWorld extends Game:
	func _ready() -> void: pass


static func run(t: Node) -> String:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = SaveGame.path(SLOT) + suffix
		files[file] = FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else null
	var g := MemoryWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.no_saves = true
	g._meta_loaded = true
	g._meta = {}
	g.world = Node2D.new()
	g.add_child(g.world)
	g.player = Player.new()
	g.player.game = g
	g.add_child(g.player)
	t.get_tree().root.add_child(g)
	var error := _checks(g)
	g.free()
	# Restore the borrowed slot even when an assertion returns early.
	for file in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		else:
			var output := FileAccess.open(file, FileAccess.WRITE)
			if output == null:
				error = "could not restore potion save fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error == "":
		print("ok: potion save round-trip preserves every Grand/ordinary/laced/gift bottle, duplicate counts, identity, amount, duration, sting and sale/drop restrictions (existing v3 saves, solo/guest character load)")
	return error


static func _checks(g: Game) -> String:
	var expected: Array = []
	for fs in Balance.POT_GRAND_FAMILIES:
		var grand := Items.make_grand_potion(String(fs))
		if grand.is_empty():
			return "Grand save fixture missing family %s" % fs
		# The old loader used this factory and silently omitted every Grand.
		if not Items.make_potion(grand.family, grand.shape, grand.grade, grand.lane).is_empty():
			return "Grand save regression no longer exercises an unsupported ordinary grade"
		expected.append(grand)
		expected.append(grand.duplicate(true))
	for spec in Items.potion_specs():
		var potion := Items.make_potion(spec.family, spec.shape, spec.grade, spec.lane)
		if potion.is_empty():
			return "ordinary/laced save fixture missing %s" % str(spec)
		expected.append(potion)
	expected.append(Items.make_gift_health_potion())
	g.player.consumables = expected.duplicate(true)
	# The writer and v3 schema predate the fix: no migration/new marker is
	# needed to recover a Grand still present in an already-written save.
	SaveGame.write(g, SLOT)
	var saved := SaveGame.read(SLOT)
	if int(saved.get("version", 0)) != 3:
		return "potion compatibility fixture must use the existing v3 format"
	var character := SaveGame.character_of(saved)
	var error := _compare(character.get("consumables", []), expected, "serialized bag")
	if error != "":
		return error
	var untouched := character.duplicate(true)
	# Both solo and guest use apply_character; reloading must not duplicate
	# bottles or depend on anything the earlier systems tests accumulated.
	for spawn_ground_loot in [true, false]:
		g.player.consumables = []
		SaveGame.apply_character(g, character, spawn_ground_loot)
		error = _compare(g.player.consumables, expected, "loaded bag (ground=%s)" % spawn_ground_loot)
		if error != "":
			return error
		if character != untouched:
			return "potion load mutated the saved character snapshot"
	return ""


static func _compare(actual: Array, expected: Array, context: String) -> String:
	if actual.size() != expected.size():
		return "%s lost/duplicated potions: expected %d, got %d" % [context, expected.size(), actual.size()]
	for i in expected.size():
		# Compare the entire JSON payload, including id/family/shape/grade/lane,
		# amt/dur, laced sting, price/no_sell and gift (sale/drop protection).
		# Normalize number types exactly as the disk serializer does.
		var want: Dictionary = JSON.parse_string(JSON.stringify(expected[i]))
		var got = JSON.parse_string(JSON.stringify(actual[i]))
		if got != want:
			return "%s changed potion %d (%s): %s" % [context, i, expected[i].id, str(got)]
	return ""
