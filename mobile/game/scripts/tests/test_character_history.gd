extends RefCounted
const History := preload("res://scripts/character_history.gd")
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
	for file in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		else:
			var output := FileAccess.open(file, FileAccess.WRITE)
			if output == null:
				error = "could not restore character-history fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error == "":
		print("ok: personal history excludes host flags, preserves home world and legacy achievements, honors explicit empty records, pairs durable quest payments, and reserves first-clear spoils exactly once")
	return error


static func _checks(g: Game) -> String:
	var own := {"owned_the_harm": true, "cap_voss_reported": true,
		"sq_kept_oak_debt": true, "cache_0": true, "home_world": true}
	var c := SaveGame._character_section(g).duplicate(true)
	c.erase("history_flags")
	c["achievements"] = ["clear_ch2", "clear_unknown", "first_boss"]
	var old := {"version": 3, "chapter": "ch1", "character": c,
		"world": {"flags": own, "wander_seed": 888, "quest_key": "vargoth"}}
	var untouched := old.duplicate(true)
	var lifted := SaveGame.character_of(old)
	if old != untouched or not lifted.history_flags.get("completed_ch2", false) \
		or lifted.history_flags.has("completed_unknown") or lifted.history_flags.has("cache_0") \
		or lifted.history_flags.has("home_world") or not lifted.history_flags.get("cap_voss_reported", false):
		return "legacy history lost own evidence, inherited world marks or mutated input"
	if not SaveGame.atomic_store(SaveGame.path(SLOT), JSON.stringify(old)):
		return "could not write legacy history fixture"
	var home_world := SaveGame.world_of(SaveGame.read(SLOT)).duplicate(true)
	g.flags = {"completed_ch7": true, "cap_voss_covered": true, "host_world": true}
	SaveGame.apply_character(g, lifted, false)
	if g.get_flag("completed_ch7") or g.get_flag("cap_voss_covered") \
		or not g.get_flag("completed_ch2") or not g.get_flag("cap_voss_reported") \
		or not g.get_flag("host_world"):
		return "guest character did not replace host personal history selectively"
	g.flags["sq_kept_flame_lit"] = true
	g.chapter_id = "ch2"
	SaveGame.write_character_home(g, SLOT)
	var returned := SaveGame.read(SLOT)
	if returned.chapter != "ch1" or SaveGame.world_of(returned) != home_world:
		return "personal progress changed the guest's home world"
	var restored := SaveGame.flags_of(returned)
	if not restored.get("sq_kept_flame_lit", false) or not restored.get("completed_ch2", false) \
		or not restored.get("home_world", false) or not restored.get("cache_0", false) \
		or restored.has("host_world"):
		return "home resume lost new personal history or imported guest-world state"
	var empty := old.duplicate(true)
	empty.character["history_flags"] = {}
	var empty_flags := SaveGame.flags_of(empty)
	if empty_flags.has("cap_voss_reported") or empty_flags.has("completed_ch2") \
		or not empty_flags.get("home_world", false):
		return "explicit empty history lifted legacy world or achievement state"
	for raw in [null, 3, [], "bad", {"completed_ch1": [], "cap_bad": NAN, "home_world": true}]:
		if not History.clean(raw).is_empty():
			return "malformed personal history entered the character record"
	var fl := {"completed_ch1": true, "owned_the_harm": true, "cap_voss_reported": true,
		"sq_kept_rescue_ash_crow": true, "cache_0": true, "hidden_0": true, "shrined_0": true,
		"cursed_0": true, "sq_on_tower_light": true, "met_elder": true}
	var wire := History.world_only(fl)
	if wire != {"cursed_0": true, "sq_on_tower_light": true, "met_elder": true}:
		return "host snapshot leaked personal/cache claims or removed shared quest state"
	# Future unscoped content must keep payment markers with its durable steps.
	# Preserve any authored entry even when this assertion fails.
	var test_id := "qa_history_persistent"
	var previous = Story.ALL_SIDE_QUESTS.get(test_id)
	Story.ALL_SIDE_QUESTS[test_id] = {"scope": "world", "steps": [{"flag": "cap_qa_done"}]}
	var persistent := {"cap_qa_done": true, "sq_on_" + test_id: true,
		"sq_paid_" + test_id: true, "sq_pledge_" + test_id: 2}
	var kept := History.clean(persistent)
	if previous == null:
		Story.ALL_SIDE_QUESTS.erase(test_id)
	else:
		Story.ALL_SIDE_QUESTS[test_id] = previous
	if kept != persistent:
		return "durable quest steps were separated from acceptance/payment/pledge"
	# Actual reward contents and amounts, with an atomic pre-victory claim.
	g.flags = {}
	g.achievements = {}
	g.mailbox = []
	g.player.gold = 0
	g.chapter_id = "ch4"
	g._first_clear_reward(12)
	var gold := g.player.gold
	if gold != int(Balance.FIRST_CLEAR_GOLD * Balance.daily_gold_mult(12)) \
		or g.mailbox.size() != 1 or g.mailbox[0].items.size() != 2:
		return "first clear did not pay the original gold/gear/gem package"
	g._first_clear_reward(12)
	if g.player.gold != gold or g.mailbox.size() != 1:
		return "duplicate first-clear callback paid twice before victory"
	SaveGame.write_character_home(g, SLOT)
	SaveGame.apply_character(g, SaveGame.character_of(SaveGame.read(SLOT)), false)
	g._first_clear_reward(12)
	if g.player.gold != gold or g.mailbox.size() != 1:
		return "pre-victory home save lost its first-clear claim reservation"
	g.chapter_id = "ch1"
	g._first_clear_reward(12)
	if g.mailbox.size() != 2 or g.mailbox[-1].items.size() != 1:
		return "early chapter first-clear package should contain gear without a gem"
	g.chapter_id = "ch7"
	g.flags["completed_ch7"] = true
	g._first_clear_reward(12)
	if g.mailbox.size() != 2:
		return "already completed legacy chapter paid first-clear spoils again"
	return ""
