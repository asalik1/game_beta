extends RefCounted
## The player can inspect a fall after recovering, without a mandatory modal.


static func open(m: Menus, last_fall := true) -> void:
	var p: Player = m.game.local_player
	var memory: RefCounted = p.damage_memory
	var fall: Dictionary = memory.last_defeat
	var entries: Array = fall.get("hits", []) if last_fall else memory.recent(Time.get_ticks_msec() * 0.001)
	var box := m._open("Combat report", 960, clampf(330.0 + entries.size() * 70.0, 360.0, 620.0), true)
	m.current = "combat_report"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	box.add_child(tabs)
	m._tab(tabs, "Last fall", func() -> void: open(m, true), last_fall)
	m._tab(tabs, "Recent damage", func() -> void: open(m, false), not last_fall)
	if entries.is_empty():
		UITheme.header(m._lbl(box, "The flame still stands" if last_fall else "No recent wounds", 24, UITheme.GOLD_BRIGHT))
		m._lbl(box, "Your next fall will leave a record here: the final blows, who dealt them, and the health each one took." if last_fall else "Damage from the last %d seconds appears here. Dodged hits and blows fully absorbed by a shield do not count as lost health." % int(Balance.COMBAT_MEMORY_SECONDS), 17)
		m._btn(box, "Return to game", func() -> void: m.close(), UITheme.GOLD_BRIGHT)
		return
	var end: float = float(fall.get("time", 0.0)) if last_fall else Time.get_ticks_msec() * 0.001
	var total := 0.0
	var heavy_n := 0
	for entry in entries:
		total += float(entry["amount"])
		heavy_n += int(entry["heavy"])
	var final_hit: Dictionary = entries.back()
	UITheme.header(m._lbl(box, String(fall.get("place", "Last stand")) if last_fall else "The last %d seconds" % int(Balance.COMBAT_MEMORY_SECONDS), 23, UITheme.GOLD_BRIGHT))
	m._lbl(box, "%s · %s health lost across %d hit%s" % [
		"Final blow: " + String(final_hit["source"]) if last_fall else "Live record",
		Game.fmt_meter(total), entries.size(), "" if entries.size() == 1 else "s"], 16, Color(0.92, 0.79, 0.68))
	m._lbl(box, "Heavy attacks landed %d time%s. Leave the marked area before the attack resolves." % [heavy_n, "" if heavy_n == 1 else "s"] if heavy_n > 0 else "Each row records health actually lost after mitigation and shields. Healing between hits can make the total exceed your maximum health.", 14, UITheme.TEXT_MUTED)
	UITheme.rule(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var card := PanelContainer.new()
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.13, 0.17, 0.20)
		frame.border_color = Color(0.63, 0.32, 0.23, 0.6) if entry["heavy"] else Color(0.35, 0.4, 0.46, 0.5)
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(6)
		frame.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", frame)
		rows.add_child(card)
		var body := VBoxContainer.new()
		card.add_child(body)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var ago := m._lbl(row, "−%.1fs" % maxf(0, end - float(entry["time"])), 15, UITheme.TEXT_MUTED)
		ago.custom_minimum_size.x = 72
		var who := m._lbl(row, String(entry["source"]), 16)
		who.custom_minimum_size.x = 320
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind := m._lbl(row, ("Heavy · " if entry["heavy"] else "") + _type_name(String(entry["type"])), 14, Color(0.87, 0.67, 0.51))
		kind.custom_minimum_size.x = 150
		var value := m._lbl(row, "−%s HP" % Game.fmt_meter(float(entry["amount"])), 17, Color(1.0, 0.6, 0.5))
		value.custom_minimum_size.x = 105
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for label in [ago, who, kind, value]:
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var remaining := m._lbl(body, "%s / %s HP remaining" % [Game.fmt_meter(entry["hp"]), Game.fmt_meter(entry["max_hp"])], 12, UITheme.TEXT_MUTED)
		remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m._btn(box, "Return to game", func() -> void: m.close(), UITheme.GOLD_BRIGHT)
	m._hint(box, "ESC to return to the pause menu")


static func _type_name(kind: String) -> String:
	return String({"phys": "Physical", "magic": "Magic", "true": "True damage"}.get(kind, kind.capitalize()))
