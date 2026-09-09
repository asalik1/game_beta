extends RefCounted
const Recovery := preload("res://scripts/loot_recovery.gd")

class RewardWorld extends Game:
	func _ready() -> void:
		pass  # isolated real chest/coin children; no second campaign boot


static func run(t: Node) -> String:
	var p: Player = t.game.player
	var kept := {}
	for key in ["gold", "greed", "goldrush_time", "dead", "downed", "ghost", "materials"]:
		var value = p.get(key)
		kept[key] = value.duplicate(true) if value is Array else value
	var g := RewardWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.player = p
	g.chapter_id = "ch4"
	t.get_tree().root.add_child(g)
	var error := _checks(g, t.game)
	g.player = null
	g.free()
	for key in kept:
		p.set(key, kept[key])
	if error == "":
		print("ok: earned spoils freeze without opening/rerolling, exact per-coin gold, cache/owner/claim exclusion, recovery once, malformed records and typed mail attachments")
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
	hidden.bury()
	_coin(g, 5)
	_coin(g, 7)
	_coin(g, 900, true)
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
	if not chest.opened or not supply.opened or cache.opened or hidden.opened or hooks[0] != 0:
		return "recovery consumed a cache or left earned chests claimable"
	Recovery.recover_live(g)
	if p.gold != 100 + expected_gold or g.mailbox.size() != 1:
		return "a repeated teardown paid the same chest/coin twice"
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
