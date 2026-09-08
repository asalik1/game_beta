extends RefCounted
## A co-op road can gain supplies while another player reads a merchant.
## Replace stale quotes before a purchase; monitor only the current shop shell.

class QuoteWatch extends Node:
	var menus: Menus
	var shell: Control
	var zone := -1
	var quote := 1.0
	var world_id := 0
	func _process(_delta: float) -> void:
		if menus.root != shell or not (menus.current == "shop" or (menus.current == "detail" and menus.detail_return == "shop")):
			set_process(false)
			return
		if not is_instance_valid(menus.game.world) or menus.game.world.get_instance_id() != world_id:
			menus.close()
		elif not is_equal_approx(quote, menus.game.band_price_mult() * menus.game.shop_markup(zone)):
			menus.open_shop(zone)


static func watch(m: Menus, zone: int) -> void:
	var guard := QuoteWatch.new()
	guard.menus = m
	guard.shell = m.root
	guard.zone = zone
	guard.quote = m.game.band_price_mult() * m.game.shop_markup(zone)
	guard.world_id = m.game.world.get_instance_id()
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	m.root.add_child(guard)


static func unchanged(m: Menus, zone: int, quote: float) -> bool:
	if is_equal_approx(quote, m.game.band_price_mult() * m.game.shop_markup(zone)):
		return true
	m.open_shop(zone)
	return false
