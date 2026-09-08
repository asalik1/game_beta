extends RefCounted
const Care := preload("res://scripts/gear_care.gd")


static func open(m: Menus, item: Dictionary, category := "all", shop_zone := -1) -> void:
	var p: Player = m.game.local_player
	var box := m._popover_frame(Items.GRADE_COLOR[item["grade"]])
	var pop: PanelContainer = m._popover_box
	box.custom_minimum_size.x = 520
	m._popover_header(box, Art.icon_for(item), Items.title(item), Items.GRADE_COLOR[item["grade"]])
	var worn: Dictionary = p.equipment.get(String(item["slot"]), {})
	var against := "Empty %s slot" % String(item["slot"]) if worn.is_empty() else "Wearing: " + Items.title(worn)
	var caption := m._lbl(box, against, 14, UITheme.TEXT_MUTED)
	caption.custom_minimum_size.x = 500
	var flavor := m._lbl(box, GearFlavor.of(item), 13, Color(0.75, 0.70, 0.56))
	flavor.custom_minimum_size.x = 500
	var refusal := p.equip_error(item)
	var note := "Item stats include upgrades and socketed gems."
	if refusal != "":
		note = refusal
	elif Care.kept(item):
		note = "Kept gear is protected from selling, dropping and auto-equip."
	m._lbl(box, note, 14, Color(0.96, 0.70, 0.50) if refusal != "" else UITheme.TEXT_MUTED)
	UITheme.rule(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(520, 0)
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 6)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(table)
	_row(m, table, "STAT", "WORN", "THIS", "CHANGE", UITheme.TEXT_MUTED)
	for rec in Care.comparison(item, worn):
		var stat := String(rec["stat"])
		var delta := float(rec["delta"])
		var color := Color(0.57, 0.93, 0.73) if delta > 0.001 else (Color(1, 0.58, 0.49) if delta < -0.001 else UITheme.TEXT_MUTED)
		_row(m, table, String(Items.STAT_LABEL.get(stat, stat)), Care.stat_text(stat, rec["before"]),
			Care.stat_text(stat, rec["after"]), Care.stat_text(stat, delta, true) if absf(delta) > 0.001 else "—", color)
	if item.has("passive") or worn.has("passive"):
		UITheme.rule(table)
		m._lbl(table, "This: " + (Items.passive_label(item) if item.has("passive") else "No signature passive"), 14, UITheme.GOLD_BRIGHT)
		if worn.has("passive"):
			m._lbl(table, "Worn: " + Items.passive_label(worn), 14, UITheme.TEXT_MUTED)
	var feedback := m._lbl(box, "", 14, Color(1.0, 0.70, 0.47))
	feedback.custom_minimum_size.x = 500
	feedback.visible = shop_zone >= 0
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	if shop_zone >= 0:
		var cost := price(m, item, shop_zone)
		var why := purchase_error(m, item, shop_zone)
		feedback.text = why if why != "" else "%d gold · %d free bag slots" % [cost, maxi(0, p.bag_capacity() - p.bag_used())]
		var buy := m._btn(actions, "Buy · %d gold" % cost, func() -> void:
			if price(m, item, shop_zone) != cost:
				m.open_shop(shop_zone, "buy")
				return
			var current_error := purchase_error(m, item, shop_zone)
			if current_error != "":
				feedback.text = current_error
				return
			var live_cost := price(m, item, shop_zone)
			if p.add_item(item):
				p.gold -= live_cost
				m.game.shop_stock[shop_zone].remove_at(Care.index_of(m.game.shop_stock[shop_zone], item))
				m.game.sfx("potion")
				m._smith_msg = "Bought " + Items.title(item) + "."
				m._smith_msg_color = Color(0.6, 0.95, 0.7)
				m.open_shop(shop_zone, "buy"), UITheme.GOLD_BRIGHT, why == "")
		buy.name = "BuyGear"
	else:
		var equip := m._btn(actions, "Equip", func() -> void:
			var current_error := p.equip_error(item)
			if current_error != "" or Care.index_of(p.backpack, item) < 0:
				feedback.show()
				feedback.text = current_error if current_error != "" else "This item is no longer in your bag."
				return
			p.equip(item)
			m.inventory_notice = "Equipped " + Items.title(item) + "."
			m.open_inventory("gear", category), Color(0.6, 0.95, 0.7), refusal == "")
		equip.name = "EquipInspectedGear"
		var keep := m._btn(actions, "Unkeep" if Care.kept(item) else "Keep", func() -> void:
			p.set_gear_kept(item, not Care.kept(item))
			m.open_inventory("gear", category)
			open(m, item, category), UITheme.GOLD_BRIGHT)
		keep.name = "KeepInspectedGear"
		var drop := m._btn(actions, "Drop", func() -> void:
			if p.discard_gear(item):
				m.inventory_notice = "Dropped " + Items.title(item) + "."
				m.open_inventory("gear", category)
			else:
				feedback.show()
				feedback.text = "Unkeep this item before dropping it.", Color(1, 0.6, 0.5), not Care.kept(item))
		drop.name = "DropInspectedGear"
	for button in actions.get_children():
		button.custom_minimum_size = Vector2(150, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	await m.get_tree().process_frame
	if not is_instance_valid(pop):
		return
	scroll.custom_minimum_size.y = minf(margin.get_combined_minimum_size().y, 260.0)
	await m._popover_settle(pop, Vector2(-1, -1))


static func _row(m: Menus, parent: Control, stat: String, before: String, after: String, delta: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for i in 4:
		var label := m._lbl(row, [stat, before, after, delta][i], 14, color if i == 3 else Color(0.85, 0.86, 0.91))
		label.custom_minimum_size.x = 185 if i == 0 else 86
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT


static func price(m: Menus, item: Dictionary, zone: int) -> int:
	return int(ceil(Items.shop_buy_price(item, m.game.shop_chapter()) * m.game.band_price_mult() * m.game.shop_markup(zone)))


static func purchase_error(m: Menus, item: Dictionary, zone: int) -> String:
	var p: Player = m.game.local_player
	if Care.index_of(m.game.shop_stock.get(zone, []), item) < 0:
		return "This item is no longer on the shelf."
	if p.bag_used() >= p.bag_capacity():
		return "Bag full. Free a slot before buying this item."
	var cost := price(m, item, zone)
	if p.gold < cost:
		return "%d more gold needed." % (cost - p.gold)
	return ""
