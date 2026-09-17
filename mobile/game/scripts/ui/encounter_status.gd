extends RefCounted
## Shared objective slot: above status chips and abilities, between touch clusters.

class EncounterPanel extends Panel:
	const Bodies := preload("res://scripts/ui/hud_clearance.gd")
	var hud: Hud
	func _process(delta: float) -> void:
		if not is_instance_valid(hud) or not is_instance_valid(hud.game):
			return
		# A solo dialogue pauses the encounter before its physics refresh can
		# hide this panel. This HUD-owned process keeps overlay gating live.
		if hud.game.input_overlay_up():
			hide()
			return
		if not visible:
			return
		var actors: Array = [hud.game.local_player, hud.target_bar_unit]
		var covered := false
		for actor in actors:
			if not is_instance_valid(actor) or not (actor is Player or actor is Enemy):
				continue
			if actor.game != hud.game or not is_instance_valid(hud.game.world):
				continue
			if actor is Enemy and not hud.game.world.is_ancestor_of(actor):
				continue
			# Reuse camera-transformed body bounds, including fallen local heroes.
			# The party may still be fighting; keep yielding without hiding its status.
			var body := Bodies.body_rect(actor, true)
			if body.has_area() and get_global_rect().intersects(body):
				covered = true
				break
		var alpha: float = Balance.ENCOUNTER_COVER_ALPHA if covered else 1.0
		modulate.a = move_toward(modulate.a, alpha, delta * Balance.ENCOUNTER_COVER_FADE_SPEED)


static func make(hud: CanvasLayer, title: String, color: Color, meter := false) -> Control:
	var panel := EncounterPanel.new()
	panel.hud = hud
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.name = title
	panel.position = Vector2(488, 428)  # feedback starts at y534, then buffs at y578
	panel.size = Vector2(304, 100)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.04, 0.94)
	style.border_color = Color(color, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	for row in [["Title", 8, 16], ["Detail", 34, 14], ["Hint", 72, 12]]:
		var label := Label.new()
		label.name = row[0]
		label.position = Vector2(12, row[1])
		label.size = Vector2(280, 22)
		label.add_theme_font_size_override("font_size", row[2])
		label.add_theme_color_override("font_color", color if row[0] == "Title" else Color(0.86, 0.89, 0.88))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
	if meter:
		for item in [["IntegrityTrack", Color(0.15, 0.17, 0.2)], ["Integrity", color]]:
			var bar := ColorRect.new()
			bar.name = item[0]
			bar.position = Vector2(12, 60)
			bar.size = Vector2(280, 6)
			bar.color = item[1]
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(bar)
	return panel
