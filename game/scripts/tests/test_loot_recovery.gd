extends RefCounted
const Recovery := preload("res://scripts/loot_recovery.gd")

class RewardWorld extends Game:
	func _ready() -> void:
		pass  # isolated real chest/coin children; no second campaign boot


# Exercise real switch_chapter teardown/layout with a quiet arrival: no mobs,
# UI, or campaign boot. This fixture owns all mutable player/world state.
class RestartWorld extends RewardWorld:
	func _install_shortcut() -> void: pass
	func _build_door_seals() -> void: pass
	func _enter_room(i: int, _live := false) -> void: cur_room = i
	func refresh_quest() -> void: pass

class RewardPlayer extends Player:
	func _ready() -> void: pass

# A failed chest guard can pay the suite player's bag. Restore membership but
# keep the original item dictionaries so their identity survives the restore.
const ITEM_POCKETS := ["backpack", "gem_bag"]


static func run(t: Node) -> String:
	var p: Player = t.game.player
	var kept := {}
	for key in ["gold", "greed", "goldrush_time", "dead", "downed", "ghost", "materials", "consumables"] + ITEM_POCKETS:
		var value = p.get(key)
		kept[key] = value.duplicate(not ITEM_POCKETS.has(key)) if value is Array else value
	var g := RewardWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.player = p
	g.chapter_id = "ch4"
	g.no_saves = true
	t.get_tree().root.add_child(g)
	var error := _checks(g, t.game)
	if error == "":
		error = _stash_checks(g)
	g.player = null
	g.free()
	if error == "":
		error = await _gift_drop_ui(t.game)
	for key in kept:
		p.set(key, kept[key])
	if error == "":
		error = _mail_claim_checks(t)
	if error == "":
		error = await _restart_checks(t)
	if error == "":
		print("ok: earned spoils freeze without opening/rerolling, exact per-coin gold, cache/owner/claim exclusion, recovery once, malformed records and typed mail attachments, chapter reward retirement, gift stash exclusion and gift-only Drop")
	return error


static func _coin(g: Game, amount: int, charged := false) -> Pickup:
	var c := Pickup.new()
	c.game = g
	c.value = amount
	c.goldrush = charged
	g.add_child(c)
	return c


static func _checks(g: Game, other: Game) -> String:
	var p := g.player
	p.gold = 100
	p.greed = 37.0
	p.goldrush_time = 0.0
	var chest := Chest.drop(g, "gold", Vector2(800, 500), {"grade": "B"})
	var supply := Chest.drop(g, "gold", Vector2(900, 500), {"kind": "supply", "supply_tier": "gold", "supply_gem": true, "first_clear": true, "boss_lv": 40})
	var hooks := [0]
	var cache := Chest.drop(g, "wood", Vector2(1000, 500), {"grade": "F"})
	cache.on_open = func() -> void: hooks[0] += 1
	var hidden := Chest.drop(g, "wood", Vector2(1100, 500), {"grade": "F"})
	hidden.bury()  # no hook: recovery must skip it for being buried alone
	var buried_cache := Chest.drop(g, "wood", Vector2(1200, 500), {"grade": "F"})
	buried_cache.bury()
	buried_cache.on_open = func() -> void: hooks[0] += 1
	_coin(g, 5)
	_coin(g, 7)
	var charged := _coin(g, 900, true)
	var foreign_charged := _coin(g, 900, true)
	foreign_charged.game = other
	_coin(g, 900).claimed = true
	_coin(g, 900).game = other
	_coin(g, 900).loot = {"kind": "bag", "grade": "F"}
	_coin(g, 900).queue_free()
	var remote := Player.new()
	chest._on_body_entered(remote)
	remote.free()
	for state in ["dead", "downed", "ghost"]:
		p.set(state, true)
		chest._on_body_entered(p)
		p.set(state, false)
	if chest.opened or p.gold != 100:
		return "a remote or fallen body opened an earned chest"
	var expected_gold := p.gold_yield(int(chest.sealed_contents().gold)) + p.gold_yield(5) + p.gold_yield(7)
	var saved := Recovery.snapshot(g)
	if int(saved.chests) != 2 or int(saved.gold) != expected_gold \
		or saved.items.size() != chest.sealed_contents().items.size() + supply.sealed_contents().items.size():
		return "snapshot counted an authored/hidden/opened/foreign/charged reward or lost a real one"
	if chest.opened or supply.opened or hooks[0] != 0 or p.gold != 100 or not g.mailbox.is_empty():
		return "saving paid/opened a chest or invoked a discovery hook"
	if Recovery.snapshot(g) != saved:
		return "a second save rerolled unopened contents"
	var corrupted := saved.duplicate(true)
	corrupted.items[0].item.name = "MUTATED COPY"
	if Recovery.snapshot(g).items[0].item.name == "MUTATED COPY":
		return "saved chest contents alias the live roll"
	var decoded = JSON.parse_string(JSON.stringify(saved))
	var cleaned := Recovery.clean(decoded)
	if cleaned.items.size() != saved.items.size() or cleaned.gold != saved.gold:
		return "real gear/supply payloads did not survive JSON"
	var paid := Recovery.recover_live(g)
	if p.gold != 100 + expected_gold or g.mailbox.size() != 1 \
		or g.mailbox[0].items.size() != saved.items.size() or paid.gold != expected_gold:
		return "recovery lost contents or applied the owner's gold bonus twice"
	if not chest.opened or not supply.opened or cache.opened or hidden.opened or buried_cache.opened or hooks[0] != 0:
		return "recovery consumed a cache or left earned chests claimable"
	Recovery.recover_live(g)
	if p.gold != 100 + expected_gold or g.mailbox.size() != 1:
		return "a repeated teardown paid the same chest/coin twice"
	Recovery.retire_world_bound(g)
	for node in [chest, supply, cache, hidden, buried_cache]:
		if not node.opened or not node.is_queued_for_deletion():
			return "chapter teardown left an old chest live"
	if not charged.claimed or not charged.is_queued_for_deletion() \
		or foreign_charged.claimed or foreign_charged.is_queued_for_deletion():
		return "chapter teardown retained Gold Rush or retired another owner's coin"
	# Late contacts: buried chests count as already glinted awake, so only
	# the retired `opened`/`claimed` state can refuse them.
	hidden.buried = false
	buried_cache.buried = false
	for node in [cache, hidden, buried_cache, charged]:
		node._on_body_entered(p)
	Recovery.retire_world_bound(g)
	if hooks[0] != 0 or p.gold != 100 + expected_gold or g.mailbox.size() != 1 or p.goldrush_time != 0.0:
		return "retiring caches invoked discovery or paid unearned loot"
	for raw in [null, [], "broken", {"gold": NAN}, {"gold": INF}, {"gold": -1}, {"gold": "200"}, {"items": {"bad": true}}]:
		var bad := Recovery.clean(raw)
		if not bad.items.is_empty() or bad.gold != 0:
			return "invalid reward record accepted"
	var malformed := Recovery.clean({"items": [null, 7, [], {"kind": "gem", "gem": {"stat": "missing", "lvl": 1}}, {"kind": "potion", "potion": []}, {"kind": "item", "item": {"slot": "weapon", "grade": "B", "main": []}}, {"kind": "material", "family": "metal", "grade": "F", "count": NAN}]})
	if not malformed.items.is_empty():
		return "malformed attachment survived validation"
	var material := UIMailbox.attachment_view({"kind": "material", "family": "metal", "grade": "F", "count": 4})
	var pot := Items.make_potion("health", "instant", "F", "accord")
	var potion := UIMailbox.attachment_view({"kind": "potion", "potion": pot})
	if material.icon == null or material.icon != Art.material_ui_icon("metal", "F") \
		or material.count != 4 or material.title != Items.MATERIALS.metal.F:
		return "material mail attachment lost its painted icon/name/count"
	if potion.icon == null or potion.icon != Art.consumable_icon(pot) or potion.title != pot.name:
		return "potion mail attachment fell through to the stone preview"
	p.materials = [Items.make_material("metal", "F", Items.MATERIAL_STACK_MAX - 1)]
	if p.add_material("metal", "F", 2) or p.material_count("metal", "F") != Items.MATERIAL_STACK_MAX - 1:
		return "a nearly full material stack silently consumed excess units"
	if not p.add_material("metal", "F", 1) or p.material_count("metal", "F") != Items.MATERIAL_STACK_MAX:
		return "an exact-fit material stack was refused"
	if p.add_material("metal", "E", Items.MATERIAL_STACK_MAX + 1) or p.material_count("metal", "E") != 0:
		return "an oversized new material payload was silently truncated"
	return ""


static func _stash_checks(g: Game) -> String:
	var gift := Items.make_gift_health_potion()
	var normal := Items.make_potion("health", "instant", "F", "accord")
	g.player.consumables = [gift, normal]
	var before := g.stash.duplicate(true)
	if g.stash_deposit_from_bag({"kind": "stone", "stone": gift}) \
		or g.player.consumables.size() != 2 or not g.player.consumables.has(gift) or g.stash != before:
		return "chapter gift escaped into the account stash"
	var entries: Array = UIStash._bag_entries(g.player)
	for entry in entries:
		if entry.get("kind", "") == "stone" and entry.stone.get("gift", false):
			return "stash UI offered a chapter gift for deposit"
	if not entries.has({"kind": "stone", "stone": normal}) \
		or not g.stash_deposit_from_bag({"kind": "stone", "stone": normal}) \
		or g.player.consumables != [gift] or g.stash.size() != before.size() + 1:
		return "blocking gifts also blocked an ordinary potion"
	return ""


static func _restart_checks(t: Node) -> String:
	var g := RestartWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.no_saves = true
	g.player = RewardPlayer.new()
	g.player.gold = 0
	g.player.game = g
	g.add_child(g.player)
	g.ambient = CanvasModulate.new()
	g.add_child(g.ambient)
	t.get_tree().root.add_child(g)
	var error: String = await _restart_asserts(g, t.get_tree())
	g.free()
	if error == "":
		print("ok: real chapter restart retires old caches, buried chests and Gold Rush after mailing earned loot")
	return error


static func _restart_asserts(g: Game, tree: SceneTree) -> String:
	g.chapter_id = "ch2"  # authored coordinates; restart rebuilds the same map
	g.world = Node2D.new()
	g.add_child(g.world)
	var cache := Chest.drop(g, "wood", Vector2.ZERO, {"grade": "F"})
	cache.on_open = func() -> void:
		g.set_flag(g._cache_flag(0))
		g.run_secrets += 1
	var hidden := Chest.drop(g, "wood", Vector2.ZERO, {"grade": "F"})
	hidden.on_open = func() -> void: g.set_flag(g._hidden_flag(0))
	hidden.bury()
	var earned := Chest.drop(g, "wood", Vector2.ZERO, {"grade": "F"})
	var expected := earned.sealed_contents().duplicate(true)
	var charged := _coin(g, 900, true)
	var flags_before := g.flags.duplicate(true)
	g.switch_chapter(g.chapter_id, true)
	if g.mailbox.size() != 1 or g.mailbox[0].items != expected.items \
		or g.player.gold != int(expected.gold):
		return "restart lost earned chest contents or paid world-bound rewards"
	var old: Array = [cache, hidden, earned, charged]
	for node in old:
		if not is_instance_valid(node) or not node.is_queued_for_deletion():
			return "restart left an old-world reward live"
	# Contacts in the rebuilt chapter before the frame ends (the buried cache
	# already glinted awake) must not discover its caches or pay a coin.
	hidden.buried = false
	for node in old:
		node._on_body_entered(g.player)
	if g.flags != flags_before or g.run_secrets != 0 or g.mailbox.size() != 1 \
		or g.player.gold != int(expected.gold) or g.player.goldrush_time != 0.0:
		return "restart let a stale cache or Gold Rush coin pay out in the rebuilt chapter"
	# The first flush can run after this frame's process signal.
	await tree.process_frame
	await tree.process_frame
	for node in old:
		if is_instance_valid(node):
			return "restart retained a reward from the old world"
	return ""


## The chapter gift stacks apart from bought twins, so hiding its Drop never
## hides Drop on potions the player paid for, whichever arrived first.
static func _gift_drop_ui(g: Game) -> String:
	var m: Menus = g.menus
	if m.is_open() or g.local_player != g.player:
		return "gift Drop check needs closed menus and the solo suite player"
	var cat: String = m.inv_cat
	var error: String = await _gift_drop_checks(g, m)
	m.close()
	m.inv_cat = cat
	return error


static func _gift_drop_checks(g: Game, m: Menus) -> String:
	var gift := Items.make_gift_health_potion()
	var bought := Items.make_potion("health", "instant", "F", "accord")
	var bought_title := "%s  x2" % bought.name
	for order in [[gift, bought, bought], [bought, gift, bought]]:
		g.player.consumables = order.duplicate(true)
		m.open_inventory("gear", "consumables")
		# Let this shell's deferred touch-scroll setup run before it is replaced.
		await g.get_tree().process_frame
		var cells: Array = []
		for grid in m.root.find_children("*", "GridContainer", true, false):
			if (grid as GridContainer).columns == 11:
				cells = grid.get_children()
		if cells.size() != 2:
			return "the bag merged the chapter gift into a bought potion stack"
		var drops := {}
		for cell in cells:
			(cell as Button).pressed.emit()
			var title := ""
			var explained := false
			for label in m.detail_popover.find_children("*", "Label", true, false):
				if (label as Label).text in [str(gift.name), bought_title]:
					title = (label as Label).text
				explained = explained or (label as Label).text.contains("you can't drop, sell or store it")
			if explained != (title == str(gift.name)):
				return "only the chapter gift's card should explain why it has no Drop"
			drops[title] = false
			for button in m.detail_popover.find_children("*", "Button", true, false):
				if (button as Button).text.contains("Drop one"):
					drops[title] = true
		if drops != {str(gift.name): false, bought_title: true}:
			return "Drop showed on the chapter gift or vanished from bought potions: %s" % drops
	return ""


## Disposable world/player and unique non-slot file: no campaign state or saves borrowed.
static func _mail_claim_checks(t: Node) -> String:
	var g := RewardWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.no_saves = true
	g.player = RewardPlayer.new()
	g.player.game = g
	# Character load reapplies the skin even with campaign boot disabled.
	g.player.sprite = Sprite2D.new()
	g.player.add_child(g.player.sprite)
	g.add_child(g.player)
	t.get_tree().root.add_child(g)
	var path := "user://mail_claim_qa_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var error := _mail_claim_asserts(g, path)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	g.free()
	if error == "":
		print("ok: mail zero/exact/partial fit, full bag existing/new stacks, repeated claims, mixed attachments, short grouped notices and disposable save/reload conserve every unit")
	return error


static func _mail_units(mail: Dictionary) -> int:
	var count := 0
	for pl in mail.items:
		if pl.get("kind", "") == "material":
			count += int(pl.get("count", 1))
	return count


static func _mail_claim_asserts(g: Game, path: String) -> String:
	var p := g.player
	var cap := Items.MATERIAL_STACK_MAX
	# Each row resets ALL pockets; no reliance on loot or prior sections.
	for row in [[cap, 2, false, 0], [cap - 2, 2, false, 2],
			[cap - 1, 2, false, 1], [cap - 1, 2, true, 1],
			[0, 2, true, 0], [0, cap + 2, false, cap]]:
		p.backpack = []
		p.gem_bag = []
		p.loose_bags = []
		p.consumables = []
		p.bags = [Items.make_bag("F")]
		p.materials = [Items.make_material("metal", "F", row[0])] if row[0] > 0 else []
		if row[2]:
			while p.bag_used() < p.bag_capacity():
				p.gem_bag.append(Items.make_gem("crit", 1))
		var mail := {"subject": "Material QA", "body": "", "read": false,
			"sent_at": g.trusted_now(), "items": [{"kind": "material", "family": "metal", "grade": "F", "count": row[1]}]}
		g.mailbox = [mail]
		var original: Array = mail.items
		var total: int = row[0] + row[1]
		var notice := UIMailbox._claim_contents(g, mail)
		if p.material_count("metal", "F") != row[0] + row[3] or _mail_units(mail) != row[1] - row[3] \
				or p.material_count("metal", "F") + _mail_units(mail) != total:
			return "mail fit/conservation failed: %s" % [row]
		var expected := "Nothing fits yet. Free some pack space or use some materials, then claim again."
		if row[3] > 0:
			expected = "Took %d Rusted Scrap. " % row[3]
			var left: int = row[1] - row[3]
			expected += "Nothing left in this letter." if left == 0 else "%d %s still in this letter." % [left, "is" if left == 1 else "are"]
		if notice != expected:
			return "mail notice did not report units taken and left: " + notice
		if int(original[0].count) != row[1]:
			return "mail claim mutated a borrowed attachment"
		UIMailbox._claim_contents(g, mail)
		if p.material_count("metal", "F") != row[0] + row[3] or p.material_count("metal", "F") + _mail_units(mail) != total:
			return "repeated claim duplicated or lost material"
		# Use production character serialization, disk writer/reader and load fixups.
		if not SaveGame.atomic_store(path, JSON.stringify(SaveGame._character_section(g))):
			return "mail roundtrip could not write disposable save"
		p.materials = []
		g.mailbox = []
		SaveGame.apply_character(g, SaveGame.read_json(path), false)
		if g.mailbox.size() != 1:
			return "mail roundtrip lost the letter"
		mail = g.mailbox[0]
		if p.material_count("metal", "F") != row[0] + row[3] or p.material_count("metal", "F") + _mail_units(mail) != total:
			return "mail roundtrip lost/duplicated material"
		UIMailbox._claim_contents(g, mail)
		if p.material_count("metal", "F") + _mail_units(mail) != total:
			return "claim after reload lost/duplicated material"
		if row[0] > 0 and row[3] == 1:
			p.take_material("metal", "F", 1)
			UIMailbox._claim_contents(g, mail)
			if not mail.items.is_empty() or p.material_count("metal", "F") != total - 1:
				return "freeing one unit did not claim the exact remainder"
	# Multiple attachments for one stack compete for the same remaining space.
	p.gem_bag = []
	p.materials = [Items.make_material("metal", "F", cap - 3)]
	var mixed_gem := Items.make_gem("crit", 1)
	var mixed := {"items": [{"kind": "material", "family": "metal", "grade": "F", "count": 2},
		{"kind": "material", "family": "metal", "grade": "F", "count": 2},
		{"kind": "gem", "gem": mixed_gem}]}
	var mixed_notice := UIMailbox._claim_contents(g, mixed)
	if mixed_notice != "Took 3 Rusted Scrap, %s. 1 Rusted Scrap is still in this letter." % Items.gem_title(mixed_gem):
		return "mixed claim confused material units and attachments: " + mixed_notice
	if p.material_count("metal", "F") != cap or _mail_units(mixed) != 1 or p.gem_bag.size() != 1:
		return "mixed claim lost a remainder or changed non-material receiving"
	# A Dropped Loot letter carries one attachment per overflowed drop, so one
	# material can arrive as dozens: the notice groups by name and stays short.
	p.gem_bag = []
	p.materials = [Items.make_material("metal", "F", cap - 5)]
	while p.bag_used() < p.bag_capacity():
		p.gem_bag.append(Items.make_gem("crit", 1))
	var big_items: Array = []
	for _i in 40:
		big_items.append({"kind": "material", "family": "metal", "grade": "F", "count": 2})
	for lvl in [1, 1, 2, 3, 4, 5]:
		big_items.append({"kind": "gem", "gem": Items.make_gem("crit", lvl)})
	var big := {"items": big_items}
	var big_notice := UIMailbox._claim_contents(g, big)
	var big_expected := "Took 5 Rusted Scrap. Still in this letter: 75 Rusted Scrap, %s x2, %s and 3 more." % [
		Items.gem_title(Items.make_gem("crit", 1)), Items.gem_title(Items.make_gem("crit", 2))]
	if big_notice != big_expected or big_notice.length() > 160:
		return "large letter notice repeated names or ran long: " + big_notice
	if p.material_count("metal", "F") != cap or _mail_units(big) != 75 or big.items.size() != 44:
		return "large letter claim lost or duplicated a remainder"
	return ""
