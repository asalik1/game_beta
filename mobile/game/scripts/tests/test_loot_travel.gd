extends RefCounted
## Disk fixtures always restore the main file and both atomic-write sidecars.
const SLOT := 91

class TravelWorld extends Game:
	func _ready() -> void: pass
	func resolve_drop_pos(pos: Vector2) -> Vector2: return pos

static func run(t: Node) -> String:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = SaveGame.path(SLOT) + suffix
		files[file] = FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else null
	var g := TravelWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.player = Player.new()
	g.player.game = g
	g.add_child(g.player)
	t.get_tree().root.add_child(g)
	var error := _checks(g, t.game)
	g.free()
	for file in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		else:
			var output := FileAccess.open(file, FileAccess.WRITE)
			if output == null:
				error = "could not restore the travel test save fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error == "":
		print("ok: loot travels home without foreign coordinates, live mutation or duplicate autosaves; immediate join mail, identical rewards, retired claim callbacks, detached restore and local drops")
	return error


static func _checks(g: Game, other: Game) -> String:
	var p := g.player
	p.bags = [Items.make_bag("S"), Items.make_bag("S")]
	p.recalc()
	g.chapter_id = "ch1"
	g.flags = {"home_sentinel": true}
	g.wander_seed = 12345
	SaveGame.write(g, SLOT)
	var home := SaveGame.read(SLOT)
	var home_world := SaveGame.world_of(home).duplicate(true)
	g.chapter_id = "ch4"
	g.flags = {"host_sentinel": true}
	g.wander_seed = 67890
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var drops: Array = [
		{"kind": "item", "item": Items.roll_item_of("weapon", "B", rng, "warrior")},
		{"kind": "gem", "gem": Items.make_gem("crit", 3)},
		{"kind": "stone", "stone": Items.make_reset_stone()},
		{"kind": "material", "family": "metal", "grade": "F", "count": 7},
		{"kind": "bag", "grade": "E"},
		{"kind": "potion", "potion": Items.make_potion("health", "instant", "F", "accord")},
	]
	drops.append(drops[-1].duplicate(true))  # two equal bottles are two rewards
	var pickups: Array[Pickup] = []
	for i in drops.size():
		var pl: Dictionary = drops[i]
		var pk := Pickup.drop_loot(g, pl, Vector2(100000 + i * 80, -70000))
		pickups.append(pk)
	g.dropped_loot = drops
	g.send_mail("Existing letter", "Keep this letter.", [{"kind": "bag", "grade": "F"}])
	var before_drops := drops.duplicate(true)
	var before_mail := g.mailbox.duplicate(true)
	SaveGame.write_character_home(g, SLOT)
	var written := SaveGame.read(SLOT)
	var saved := SaveGame.character_of(written)
	if written.chapter != home.chapter or SaveGame.world_of(written) != home_world:
		return "guest autosave wrote host geography or flags into the home world"
	if not saved.dropped_loot.is_empty() or saved.mailbox.size() != 2:
		return "guest autosave retained foreign coordinates or missed the overflow letter"
	var letter: Dictionary = saved.mailbox[-1]
	var portable := before_drops.duplicate(true)
	for pl in portable:
		pl.erase("pos")
	if letter.subject != "Dropped Loot" or not _same(letter.items, portable):
		return "portable letter lost exact payloads/counts or deduplicated equal bottles"
	if g.dropped_loot != before_drops or g.mailbox != before_mail:
		return "guest autosave mutated live mail or drop dictionaries"
	for pk in pickups:
		if pk.claimed or pk.is_queued_for_deletion():
			return "guest autosave consumed a live pickup"
	SaveGame.write_character_home(g, SLOT)
	if SaveGame.character_of(SaveGame.read(SLOT)).mailbox.size() != 2:
		return "repeated guest autosave stacked the same recovery letter"
	# A real collection removes exactly one of two equal payloads from the next save.
	pickups[-1]._try_claim(p)
	if not pickups[-1].claimed or p.consumables.size() != 1 or g.dropped_loot.size() != 6:
		return "one of two identical bottles did not claim independently"
	SaveGame.write_character_home(g, SLOT)
	var remaining: Array = SaveGame.character_of(SaveGame.read(SLOT)).mailbox[-1].items
	if remaining.size() != 6 or remaining[-1].kind != "potion":
		return "post-claim autosave retained the collected bottle or lost its equal sibling"
	# Queue-free is deferred: old contact callbacks must already be inert after mail.
	var borrowed := g.dropped_loot.duplicate()
	var borrowed_before := borrowed.duplicate(true)
	g.flush_dropped_loot()
	if borrowed != borrowed_before:
		return "flushing mail stripped positions from borrowed payload dictionaries"
	var count := p.consumables.size()
	pickups[-2]._try_claim(p)
	if p.consumables.size() != count or not pickups[-2].claimed:
		return "a deferred pickup callback collected an already-mailed bottle"
	SaveGame.write_character_home(g, SLOT)
	var flushed := SaveGame.character_of(SaveGame.read(SLOT))
	if flushed.mailbox.size() != 2 or flushed.mailbox[-1].items.size() != 6:
		return "graceful mail flush plus home save duplicated the pending letter"
	# A legacy home save joined into another world should expose its loot NOW.
	var legacy := saved.duplicate(true)
	legacy.mailbox = before_mail.duplicate(true)
	legacy.dropped_loot = before_drops.duplicate(true)
	var untouched := legacy.duplicate(true)
	var stale := Pickup.drop_loot(g, before_drops[-1].duplicate(true), Vector2(90, 90))
	var foreign := Pickup.drop_loot(g, before_drops[-1].duplicate(true), Vector2(100, 100))
	foreign.game = other
	SaveGame.apply_character(g, legacy, false)
	if legacy != untouched:
		return "character restore mutated the caller's saved snapshot"
	if not g.dropped_loot.is_empty() or g.mailbox.size() != 2 or g.mailbox[-1].items.size() != 7:
		return "joining another world did not immediately recover home overflow"
	if not stale.claimed or not stale.is_queued_for_deletion() or foreign.claimed or foreign.is_queued_for_deletion():
		return "in-place restore kept old local pickups or retired another world's loot"
	count = p.consumables.size()
	stale._try_claim(p)
	if p.consumables.size() != count:
		return "in-place restore left an old pickup callback claimable"
	SaveGame.apply_character(g, legacy, false)
	if g.mailbox.size() != 2:
		return "reapplying the same join snapshot appended duplicate mail"
	# Same-world saves still restore physical loot; their input remains detached.
	SaveGame.apply_character(g, legacy, true)
	if g.dropped_loot.size() != 7 or g.mailbox.size() != 1 or legacy != untouched:
		return "same-world restore mailed local loot or mutated saved positions"
	var live := 0
	for node in g.get_children():
		if node is Pickup and node.game == g and not node.claimed and not node.is_queued_for_deletion():
			live += 1
	if live != 7:
		return "same-world restore lost or doubled physical loot"
	SaveGame.write(g, SLOT)
	var local := SaveGame.character_of(SaveGame.read(SLOT))
	if local.dropped_loot.size() != 7 or local.mailbox.size() != 1:
		return "ordinary save converted same-world drops into mail"
	return ""


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
