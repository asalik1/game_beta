extends RefCounted
const GREEN := Color(0.78, 0.92, 0.68)


static func open(m: Menus, traveler: Node2D) -> void:
	var box := m._open("One More Mile", 700, 475, true)
	m.current = "wayfarer"
	for copy in ["Tovin can see the village lamps. Walk him to the campfire.",
		"Stay near him to move. He will wait if you get too far ahead.",
		"Two groups of pursuers will approach. Watch their arrival marks, keep close, and keep creatures outside his circle.",
		"If his resolve breaks, he falls back safely. You can always try again."]:
		var label := m._lbl(box, copy, 16, Color(0.86, 0.87, 0.88))
		label.custom_minimum_size.x = 620
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.rule(box)
	if traveler.active():
		_action(m, box, traveler, "Walk with me" if traveler.waiting else "Wait here", "follow" if traveler.waiting else "wait")
		_action(m, box, traveler, "Fall back · Stop the escort", "stop")
	else:
		m._lbl(box, "Earn the Road Companion title · A traveler finds a home", 16, GREEN)
		var busy := preload("res://scripts/encounter_context.gd").blocking_name(m.game, traveler.zone, traveler)
		if busy != "":
			m._lbl(box, "Finish %s first." % busy, 16, UITheme.GOLD_BRIGHT)
		_action(m, box, traveler, "Let's walk · Begin escort", "start", busy == "")
	m._btn(box, "Back", func() -> void: m.close(), Color(0.75, 0.8, 0.85)).custom_minimum_size.y = 44


static func _action(m: Menus, box: Control, traveler: Node2D, title: String, action: String, enabled := true) -> void:
	var button := m._btn(box, title, func() -> void:
		m.close()
		if is_instance_valid(traveler):
			traveler.request(m.game.local_player, action), GREEN, enabled)
	button.custom_minimum_size.y = 48
	button.name = "Escort_" + action


static func status(hud: CanvasLayer) -> Control:
	return preload("res://scripts/ui/encounter_status.gd").make(hud, "EscortStatus", GREEN, true)
