extends RefCounted
const GOLD := Color(0.96, 0.81, 0.48)


static func status(hud: CanvasLayer) -> Control:
	return preload("res://scripts/ui/encounter_status.gd").make(hud, "RoadHuntStatus", GOLD)


static func refresh(panel: Control, trail: Node2D) -> void:
	panel.visible = trail.game.cur_room == trail.zone and trail.game.state == Game.ST_PLAYING \
		and not trail.game.input_overlay_up() and trail.phase < trail.CLOSED
	(panel.get_node("Title") as Label).text = "THE CROOKED TRAIL"
	var detail := ""
	var hint := "Party leaves the room → hunt ends"
	match trail.phase:
		trail.TRACKING:
			var distance := 0
			if trail.game.has_local_player():
				distance = roundi(trail.game.player.global_position.distance_to(trail.points[trail.sign_index]) / 10.0)
			detail = "Sign %d / 3 · %d paces" % [trail.sign_index + 1, distance]
			hint = "Follow the pawprints · Read the sign" if trail.sign_index < 2 else "Last sign · Interact when ready to fight"
			if trail.game.has_local_player() and trail.game.player.global_position.distance_to(trail.points[trail.sign_index]) <= Balance.ROAD_HUNT_INTERACT_RANGE:
				hint = trail.game.touchify("E — Read the tracks" if trail.sign_index < 2 else "E — Flush the quarry")
		trail.WARNING:
			detail = "The cover stirs · %.1fs" % trail.remaining
			hint = "Step away from the red warning"
		trail.FIGHTING:
			detail = "Bring down the elite quarry"
		trail.COMPLETE:
			detail = "Quarry felled · The road is clear"
			hint = "Purses paid to participating heroes"
	(panel.get_node("Detail") as Label).text = detail
	(panel.get_node("Hint") as Label).text = hint
