extends RefCounted
const Caravan := preload("res://scripts/road_caravan.gd")
const Inspect := preload("res://scripts/ui/gear_inspect.gd")


static func _card(m: Menus, title: String) -> Button:
	for label in m.root.find_children("*", "Label", true, false):
		if label.text == title:
			var node: Node = label
			while node != m.root:
				if node is Button:
					return node
				node = node.get_parent()
	return null


static func _price(button: Button) -> int:
	if button != null:
		for label in button.find_children("*", "Label", true, false):
			if String(label.text).ends_with(" g"):
				return String(label.text).trim_suffix(" g").to_int()
	return -1


static func run(r: Node, room: int) -> String:
	var g: Game = r.game
	var p: Player = g.player
	var saved := {"gold": p.gold, "bag": p.backpack.duplicate(true), "consumables": p.consumables.duplicate(true),
		"stock": g.shop_stock.duplicate(true), "flags": g.flags.duplicate(true)}
	p.gold = 100000
	var error := await _checks(r, room)
	g.menus.close()
	p.gold = saved.gold
	p.backpack = saved.bag
	p.consumables = saved.consumables
	g.shop_stock = saved.stock
	g.flags = saved.flags
	if error == "":
		print("ok: real shop gear/potion/recall purchases charge displayed discounted prices; stale callbacks charge nothing; open item inspection refreshes; borrowed fixture state restored")
	return error


static func _checks(r: Node, room: int) -> String:
	var g: Game = r.game
	var p: Player = g.player
	var benefit := Caravan.benefit_flag(g)
	var potion := Items.make_potion("health", "instant", "F", "accord")
	var recall := Items.make_recall_scroll()
	for item in [potion, recall]:
		g.flags.erase(benefit)
		g.menus.open_shop(room, "buy")
		var stale := _card(g.menus, String(item.name))
		var before := p.gold
		var held := p.consumables.size()
		if stale == null or stale.disabled:
			return "shop fixture cannot buy " + String(item.name)
		var full_price := _price(stale)
		g.set_flag(benefit)
		stale.pressed.emit()  # same frame: before the quote watcher can refresh
		if p.gold != before or p.consumables.size() != held:
			return "stale supply quote charged the old price"
		var fresh := _card(g.menus, String(item.name))
		var sale_price := _price(fresh)
		if fresh == null or fresh == stale or sale_price <= 0 or sale_price >= full_price:
			return "supply quote did not visibly become cheaper"
		fresh.pressed.emit()
		if p.gold != before - sale_price or p.consumables.size() != held + 1:
			return "supply purchase did not match its displayed price and item count"
	g.flags.erase(benefit)
	g.menus.open_shop(room, "buy")
	var gear: Dictionary = g.shop_stock[room][0]
	Inspect.open(g.menus, gear, "all", room)
	await r.frames(3)
	var old_shell_id := g.menus.root.get_instance_id()
	g.set_flag(benefit)
	if not await r._until(func() -> bool: return is_instance_valid(g.menus.root) and g.menus.root.get_instance_id() != old_shell_id and g.menus.current == "shop"):
		return "a shop item inspection stopped watching for new prices"
	var gear_card := _card(g.menus, Items.title(gear))
	if gear_card == null:
		return "revised shop lost its inspected gear"
	var quoted := _price(gear_card)
	gear_card.pressed.emit()
	await r.frames(3)
	var buy := g.menus.root.find_child("BuyGear", true, false) as Button
	if buy == null or buy.disabled or not buy.text.contains(str(quoted)):
		return "gear purchase confirmation did not match the shelf quote"
	await r._capture("prices_01_discounted_gear_confirmation")
	var money := p.gold
	var count := p.backpack.size()
	buy.pressed.emit()
	if p.gold != money - quoted or p.backpack.size() != count + 1:
		return "gear purchase did not charge its displayed discounted price"
	await r._capture("prices_02_purchases_charged_as_shown")
	return ""
