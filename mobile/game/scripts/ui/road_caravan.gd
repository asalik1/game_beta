extends RefCounted
const GOLD := Color(0.96, 0.81, 0.48)


static func status(hud: CanvasLayer) -> Control:
	return preload("res://scripts/ui/encounter_status.gd").make(hud, "RoadCaravanStatus", GOLD, true)


static func refresh(panel: Control, cart: Node2D) -> void:
	panel.visible = cart.game.cur_room == cart.zone and cart.game.state == Game.ST_PLAYING \
		and not cart.game.input_overlay_up() and cart.phase < cart.CLOSED
	(panel.get_node("Title") as Label).text = "A WHEEL IN THE MUD"
	var detail := ""
	var hint := ""
	match cart.phase:
		cart.PREPARING:
			detail = "Attack %d / 2 · Arriving in %.1fs" % [cart.wave, cart.remaining]
			hint = "Keep attackers away from the load"
		cart.WORKING:
			detail = "Wheel %d%% free · Load %d%%" % [roundi(100.0 * cart.tugs / Balance.CARAVAN_TUGS), ceili(cart.integrity)]
			var foes: int = cart.mirror_foes if cart.net_mirror else cart.pending_deaths.size()
			if cart.pressure > 0:
				hint = "Load under attack · Drive them away"
			elif cart.tugs >= cart.wave * Balance.CARAVAN_TUGS / Balance.CARAVAN_WAVES.size() and foes > 0:
				hint = "Finish the attackers · %d remain" % foes
			else:
				hint = cart.game.touchify("At the shafts · Hold E to pull")
		cart.COMPLETE:
			detail = "Caravan saved · The road is supplied"
			hint = "Road gear & supplies cost 20% less"
	(panel.get_node("Detail") as Label).text = detail
	(panel.get_node("Hint") as Label).text = hint
	(panel.get_node("Integrity") as ColorRect).size.x = 280.0 * cart.integrity / Balance.CARAVAN_INTEGRITY
	(panel.get_node("Integrity") as ColorRect).color = Color(1.0, 0.45, 0.3) if cart.pressure > 0 else GOLD
