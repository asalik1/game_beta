extends RefCounted
const Wildlife := preload("res://scripts/wildlife.gd")
const SLOT := 93

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
	g.player = Player.new()
	g.player.game = g
	g.add_child(g.player)
	t.get_tree().root.add_child(g)
	var error := _checks(g)
	g.free()
	for file in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		else:
			var output := FileAccess.open(file, FileAccess.WRITE)
			if output == null:
				error = "could not restore rescue history fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error == "":
		print("ok: personal rescue history survives guest home saves, excludes host/account discoveries, lifts legacy home flags without mutation, honors explicit empty history and validates ids")
	return error


static func _checks(g: Game) -> String:
	var character := SaveGame._character_section(g).duplicate(true)
	character.erase("rescued_pets")
	var legacy := {"version": 3, "chapter": "ch1", "character": character,
		"world": {"flags": {"sq_kept_rescue_spore_pup": true, "home_sentinel": true}, "wander_seed": 444}}
	var untouched := legacy.duplicate(true)
	var home_character := SaveGame.character_of(legacy)
	if home_character.rescued_pets != ["spore_pup"] or legacy != untouched:
		return "legacy home rescue history did not lift without mutating the input"
	if not SaveGame.atomic_store(SaveGame.path(SLOT), JSON.stringify(legacy)):
		return "could not create legacy rescue save fixture"
	var original_world := SaveGame.world_of(SaveGame.read(SLOT)).duplicate(true)
	# A co-op world snapshot has already supplied someone ELSE's rescue flags.
	g.flags = {"sq_kept_rescue_ash_crow": true, "host_sentinel": true}
	g._meta = {"own_pet_all_pale_flutter": true}
	SaveGame.apply_character(g, home_character, false)
	if Wildlife.count(g) != 1 or not Wildlife.rescued(g, "spore_pup") \
		or Wildlife.rescued(g, "ash_crow") or Wildlife.rescued(g, "pale_flutter"):
		return "host or account cosmetics masqueraded as this hero's rescues"
	if g.flags.has("sq_kept_rescue_ash_crow") or not g.get_flag("sq_kept_rescue_spore_pup") \
		or not g.get_flag("host_sentinel"):
		return "personal flag reconciliation erased world state or retained a host rescue"
	if not Wildlife.claim(g, "ash_crow") or Wildlife.claim(g, "ash_crow") \
		or not g.owns_cosmetic("pet", "all", "ash_crow"):
		return "new guest rescue failed to claim/unlock exactly once"
	if Wildlife.claim(g, "unknown") or Wildlife.count(g) != 2:
		return "invalid creature entered personal history"
	g.chapter_id = "ch2"
	SaveGame.write_character_home(g, SLOT)
	var home := SaveGame.read(SLOT)
	var saved := SaveGame.character_of(home)
	if home.chapter != "ch1" or SaveGame.world_of(home) != original_world:
		print("RESCUE HOME BEFORE: ", original_world, " AFTER: ", SaveGame.world_of(home))
		return "guest rescue changed the home world or chapter"
	if saved.rescued_pets != ["spore_pup", "ash_crow"]:
		return "guest rescue was not included in the character-only home save"
	# A second hero on the same account has no inherited rescue story.
	SaveGame.apply_character(g, {}, false)
	if Wildlife.count(g) != 0 or not g.owns_cosmetic("pet", "all", "ash_crow"):
		return "resetting the hero lost account ownership or fabricated rescue history"
	SaveGame.apply_character(g, saved, false)
	if Wildlife.count(g) != 2 or Wildlife.claim(g, "ash_crow"):
		return "returning home lost a guest rescue or allowed a duplicate claim"
	# Full solo apply assigns world flags after the character: reconcile the
	# same way, keeping the explicit newer history authoritative over old flags.
	g.flags = legacy.world.flags.duplicate(true)
	Wildlife.sync_flags(g)
	if not g.get_flag("sq_kept_rescue_ash_crow") or not g.get_flag("home_sentinel"):
		return "old home flags overrode the newer guest rescue history"
	var empty := legacy.duplicate(true)
	empty.character.rescued_pets = []
	if not SaveGame.character_of(empty).rescued_pets.is_empty():
		return "explicit empty history was filled from legacy world flags"
	SaveGame.apply_character(g, SaveGame.character_of(empty), false)
	if Wildlife.count(g) != 0:
		return "explicit empty character inherited live or account rescues"
	for raw in [null, 7, "spore_pup", {}, [null, 5, {}, "unknown"]]:
		if not Wildlife.clean_rescues(raw).is_empty():
			return "malformed rescue history was accepted"
	if Wildlife.clean_rescues(["ash_crow", "spore_pup", "ash_crow"]) != ["spore_pup", "ash_crow"]:
		return "rescue ids failed stable ordering or duplicate removal"
	for raw in [null, [], "bad", {"sq_kept_rescue_spore_pup": false}]:
		if not Wildlife.legacy_rescues(raw).is_empty():
			return "malformed legacy flags fabricated a rescue"
	return ""
