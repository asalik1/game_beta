extends RefCounted
const GOLD := Color(1.0, 0.8, 0.45)


static func open(m: Menus, ward: Node2D) -> void:
	var box := m._open("Stand the tower's watch", 680, 475, true)
	m.current = "ward_vigil"
	for text in ["An old flame. Three waves. A road worth keeping.",
		"Stay inside the broad amber ring. The ward fades when nobody guards it.",
		"Keep creatures out of the small red circle. Defeat each wave; the ward mends between waves.",
		"Interact with the brazier again to snuff it and stop. You can always return and try again."]:
		var line := m._lbl(box, text, 16, Color(0.85, 0.86, 0.88))
		line.custom_minimum_size.x = 600
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.rule(box)
	m._lbl(box, "Earn the Lamplighter title · Leave a light on the north road", 16, GOLD)
	var busy := preload("res://scripts/encounter_context.gd").blocking_name(m.game, ward.zone, ward)
	if busy != "":
		m._lbl(box, "Finish %s first." % busy, 16, UITheme.GOLD_BRIGHT)
	var start := m._btn(box, "Light the ward · Begin defense", func() -> void:
		m.close()
		if is_instance_valid(ward):
			ward.request(m.game.local_player, "start"), GOLD, busy == "")
	start.custom_minimum_size.y = 48
	start.name = "BeginVigil"
	var leave := m._btn(box, "Another evening", func() -> void: m.close(), Color(0.75, 0.8, 0.85))
	leave.custom_minimum_size.y = 44


static func status(hud: CanvasLayer) -> Control:
	return preload("res://scripts/ui/encounter_status.gd").make(hud, "WardStatus", GOLD, true)
