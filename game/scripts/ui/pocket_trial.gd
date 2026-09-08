extends RefCounted
const BLUE := Color(0.68, 0.85, 1.0)


static func open(m: Menus, portal: Node2D) -> void:
	var entry := Pockets.entry(m.game.pocket_id)
	var box := m._open(String(entry.name), 720, 460, true)
	m.current = "pocket_trial"
	var copy: Array = []
	if m.game.pocket_done:
		copy = ["The guardian has fallen. The stone will wait while you collect what remains.",
			"You can return through this portal for uncollected spoils. The guardian and its reward do not return this run."]
	else:
		copy = [String(entry.get("rule", "")),
			"Defeat the guardian for a gold chest, a gem and the crown's regard.",
			"The exit stone stays open. Leaving before victory costs nothing; an empty arena resets its guardian."]
	for text in copy:
		var label := m._lbl(box, String(text), 17, Color(0.85, 0.87, 0.91))
		label.custom_minimum_size.x = 650
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.rule(box)
	var action := "Return to the road" if portal.arena else "Step through the stone"
	var button := m._btn(box, action, func() -> void:
		m.close()
		if is_instance_valid(portal):
			if portal.arena:
				m.game._pocket_return()
			else:
				m.game._enter_pocket(portal.zone), BLUE)
	button.name = "Pocket_Return" if portal.arena else "Pocket_Enter"
	button.custom_minimum_size.y = 48
	m._btn(box, "Stay here", func() -> void: m.close(), Color(0.75, 0.8, 0.85)).custom_minimum_size.y = 44


static func status(hud: CanvasLayer) -> Control:
	var panel := preload("res://scripts/ui/ward_vigil.gd").status(hud)
	panel.name = "PocketStatus"
	panel.get_node("Integrity").visible = false
	return panel
