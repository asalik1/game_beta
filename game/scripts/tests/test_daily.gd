extends RefCounted
## Real claim/save/load paths on disposable characters. Capture durable files
## at delivery boundaries to replay a quit, including between character/meta
## writes. No campaign state or owner's account file is borrowed.
const SLOT := 95

class DailyWorld extends Game:
	var meta_path := ""
	var cuts: Array = []
	var capture := false
	var write_failed := false
	var floats: Array = []
	func _ready() -> void: pass
	func spawn_text(_pos: Vector2, text: String, _color: Color, _hold := 0.0) -> void:
		floats.append(text)
	func _meta_write() -> void:
		cut()
		if not SaveGame.atomic_store(meta_path, JSON.stringify(_meta)):
			write_failed = true
		cut()
	func _grant_daily_reward(streak: int) -> Array:
		var lines := super._grant_daily_reward(streak)
		cut()
		return lines
	func cut() -> void:
		if capture:
			cuts.append({"character": SaveGame.character_of(SaveGame.read(SLOT)).duplicate(true),
				"meta": SaveGame.read_json(meta_path).duplicate(true)})

class DailyPlayer extends Player:
	func _ready() -> void: pass
	func add_consumable(c: Dictionary) -> bool:
		var received := super.add_consumable(c)
		# A nested achievement/event save must not persist half a daily claim.
		if game.get("capture"):
			game.autosave()
			game.call("cut")
		return received


static func run(t: Node) -> String:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var meta_path := "user://daily_qa_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var error := ""
	# Two-potion day: none/one/both fit. Mixed day and achievement day also
	# exercise gems, gold and the formerly premature streak-achievement save.
	for row in [[6, 0, false], [6, 1, false], [6, 2, false], [5, 0, false],
			[7, 0, false], [7, 2, false], [6, 1, true]]:
		var g := DailyWorld.new()
		g.process_mode = Node.PROCESS_MODE_DISABLED
		g.meta_path = meta_path
		g._meta_loaded = true
		g._meta = {}
		g.guest_world = row[2]
		g.player = DailyPlayer.new()
		g.player.game = g
		g.player.sprite = Sprite2D.new()
		g.player.add_child(g.player.sprite)
		g.add_child(g.player)
		t.get_tree().root.add_child(g)
		error = _checks(g, row[0], row[1])
		g.free()
		if error != "":
			break
	# Restore on failure too; _fail only queues the suite's exit.
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				error = "could not restore daily fixture slot"
			else:
				f.store_buffer(files[path])
				f.close()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(meta_path + suffix):
			DirAccess.remove_absolute(meta_path + suffix)
	if error == "":
		print("ok: daily full/one-slot/two-slot potion delivery, mixed gem overflow, achievement save, quit/reload at delivery and account-write boundaries, mail recovery and exactly-once ledger/gold/Renown")
	return error


static func _checks(g: DailyWorld, streak: int, free_slots: int) -> String:
	var p := g.player
	p.backpack = []
	p.gem_bag = []
	p.consumables = []
	p.materials = []
	p.loose_bags = []
	p.bags = [Items.make_bag("F")]
	p.gold = 0
	p.level = 1
	# Distinct filler pocket: counting earned potions/gems never counts filler.
	while p.bag_used() < p.bag_capacity() - free_slots:
		p.loose_bags.append(Items.make_bag("F"))
	g.save_slot = SLOT
	g.play_started = true
	g.state = g.ST_PLAYING
	g.daily_last_day = g.daily_day_index() - 1
	g.daily_streak = streak - 1
	if not g.daily_available() or g.daily_next_streak() != streak:
		return "consecutive day did not make the next reward available"
	# A downed co-op hero cannot autosave, so the claim must wait untouched.
	p.downed = true
	var waited := g.claim_daily()
	p.downed = false
	if not waited.is_empty() or not g.daily_available() or p.gold != 0 or not g.mailbox.is_empty():
		return "a downed hero claimed a daily reward that could not be saved"
	g._meta_write()
	g.autosave()
	if not SaveGame.exists(SLOT):
		return "daily fixture could not save initial character"
	g.capture = true
	g.cut()
	g.floats = []
	var lines := g.claim_daily()
	g.cut()
	g.capture = false
	if g.write_failed:
		return "daily fixture account write failed"
	# The panel receipt names any mailed overflow; a second world float from
	# the letter would stack on the streak line over the hero.
	if g.floats.size() != 1:
		return "daily claim stacked %d world floats over the hero: %s" % [g.floats.size(), g.floats]
	var reward := g.daily_reward_for(streak)
	var error := _assert_paid(g, reward, streak)
	if error != "":
		return error
	var promised := int(reward.get("potions", 0))
	if p.consumables.size() != mini(free_slots, promised):
		return "daily potions did not use the available pack slots"
	# Gems fill whatever slots the potions left before any gem is mailed.
	if p.gem_bag.size() != mini(free_slots - mini(free_slots, promised), int(reward.get("gems", 0))):
		return "daily gems did not use the available pack slots"
	if not g.mailbox.is_empty() and not " ".join(lines).contains("sent to Mailbox"):
		return "daily receipt omitted the overflow destination"
	if not g.dropped_loot.is_empty():
		return "daily overflow used world-bound ground loot"
	# Replay a quit from each actual durable boundary, then try claiming again.
	# Old snapshots must remain claimable; committed ones must refuse a repeat.
	for cut in g.cuts:
		g._meta = cut.meta.duplicate(true)
		g._meta_write()
		if not SaveGame.atomic_store(SaveGame.path(SLOT), JSON.stringify({
				"version": SaveGame.VERSION, "chapter": "ch1", "character": cut.character, "world": {}})):
			return "daily fixture could not restore interrupted save"
		SaveGame.apply_character(g, SaveGame.character_of(SaveGame.read(SLOT)), false)
		var was_claimed: bool = int(cut.character.daily_last_day) == g.daily_day_index()
		var retry := g.claim_daily()
		if retry.is_empty() != was_claimed:
			return "daily reload did not preserve the claim ledger"
		error = _assert_paid(g, reward, streak)
		if error != "":
			return "daily interrupted reload: " + error
		# Reload once more AFTER account credit; it must not pay again.
		g._meta = SaveGame.read_json(g.meta_path)
		SaveGame.apply_character(g, SaveGame.character_of(SaveGame.read(SLOT)), false)
		if not g.claim_daily().is_empty():
			return "daily reward claim repeated after reload"
		error = _assert_paid(g, reward, streak)
		if error != "":
			return "daily repeat reload: " + error
	# Free the filler, claim the recovery letter, save and reload that transfer.
	p.loose_bags = []
	for mail in g.mailbox:
		UIMailbox._claim_contents(g, mail)
	g.autosave()
	SaveGame.apply_character(g, SaveGame.character_of(SaveGame.read(SLOT)), false)
	for mail in g.mailbox:
		UIMailbox._claim_contents(g, mail)
	if p.consumables.size() != promised or p.gem_bag.size() != int(reward.get("gems", 0)):
		return "daily mailed rewards could not be recovered exactly once"
	error = _assert_paid(g, reward, streak)
	if error != "":
		return error
	# Preserve the original systems test's missed-day reset coverage, using
	# explicit fixture state rather than rewards accumulated above.
	g.daily_last_day = g.daily_day_index() - 3
	g.daily_streak = 9
	p.gold = 0
	if g.claim_daily().is_empty() or g.daily_streak != 1 \
			or p.gold != int(float(g.daily_reward_for(1).gold) * Balance.daily_gold_mult(p.level)):
		return "missed daily day did not reset and pay day one"
	return ""


static func _assert_paid(g: Game, reward: Dictionary, streak: int) -> String:
	var potions := g.player.consumables.size()
	var gems := g.player.gem_bag.size()
	for mail in g.mailbox:
		for payload in mail.items:
			if payload.kind == "potion":
				potions += 1
			elif payload.kind == "gem":
				gems += 1
	if potions != int(reward.get("potions", 0)) or gems != int(reward.get("gems", 0)):
		return "daily bag + mail lost/duplicated promised potions or gems (day %d: %d potions, %d gems)" % [streak, potions, gems]
	if g.daily_last_day != g.daily_day_index() or g.daily_streak != streak or g.daily_available():
		return "daily ledger did not advance exactly once"
	if g.player.gold != int(float(reward.get("gold", 0)) * Balance.daily_gold_mult(g.player.level)):
		return "daily gold lost/duplicated across delivery"
	if g.renown() != int(reward.get("renown", 0)):
		return "daily account Renown lost/duplicated across delivery"
	return ""
