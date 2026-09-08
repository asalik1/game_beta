extends RefCounted
## Optional fights can share a campaign, but not the same room at once.
## Separate from door seals: a road hunt must remain freely escapable.


static func blocking_name(g: Game, room: int, except: Node = null) -> String:
	for event in g.get_tree().get_nodes_in_group("optional_encounters"):
		if event != except and event.game == g and event.zone == room \
			and not event.is_queued_for_deletion() and is_instance_valid(g.world) \
			and g.world.is_ancestor_of(event) and event.active():
			return String(event.get_meta("encounter_title", "the current encounter"))
	return ""


static func may_start(g: Game, room: int, source: Player, except: Node = null) -> bool:
	var name := blocking_name(g, room, except)
	if name == "":
		return true
	if source == g.local_player and is_instance_valid(g.hud):
		g.hud.announce("Finish %s first — This road already has a fight to settle." % name, UITheme.GOLD_BRIGHT)
	return false
