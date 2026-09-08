extends RefCounted
const Guide := preload("res://scripts/quest_guide.gd")
const Wildlife := preload("res://scripts/wildlife.gd")
const Pet := preload("res://scripts/pet_visual.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var saved := {}
	for key in ["flags", "visited", "door_seen", "_meta", "quest_kills"]:
		saved[key] = g.get(key).duplicate(true)
	var meta_loaded: bool = g._meta_loaded
	var tracked: String = g.player.tracked_quest
	var pet: String = g.player.equipped_pet
	var rescues := g.player.rescued_pets.duplicate()
	var guide_index := Guide._setters.duplicate(true)
	var indexed := Guide._indexed
	var pin: int = g.hud.wayfinder.pinned_room
	var path: Array[int] = g.hud.wayfinder.pinned_path.duplicate()
	var error := _checks(g)
	for key in saved:
		g.set(key, saved[key])
	g._meta_loaded = meta_loaded
	g.player.tracked_quest = tracked
	g.player.rescued_pets = rescues
	g.player.set_pet(pet)
	g.hud.wayfinder.pinned_room = pin
	g.hud.wayfinder.pinned_path = path
	Guide._setters = guide_index
	Guide._indexed = indexed
	g.hud.wayfinder._sample_quest()
	g.hud.wayfinder.pinned_room = pin
	g.hud.wayfinder.pinned_path = path
	Story.ALL_SIDE_QUESTS.erase("_qa_guide")
	if error == "":
		print("ok: quest fog, objective advancement, manual route handoff, personal save selection, six rescue sites, claim-once ownership and companion frame scale")
	return error


static func _checks(g: Game) -> String:
	for site in Wildlife.SITES:
		var found := false
		for zone in Story.chapter(String(site.chapter)).zones:
			if String(zone.name) == String(site.room):
				found = true
		if not found or Skins.find_pet(String(site.id)).is_empty():
			return "unreachable rescue site: " + String(site.id)
	if not g._flag_is_local("sq_kept_rescue_hearth_hopper"):
		return "a personal rescue escaped onto the shared flag channel"
	g.flags.erase("sq_kept_rescue_hearth_hopper")
	g.player.rescued_pets.erase("hearth_hopper")
	if not Wildlife.claim(g, "hearth_hopper") or Wildlife.claim(g, "hearth_hopper"):
		return "rescue claim was not exactly once"
	if not g.owns_cosmetic("pet", "all", "hearth_hopper"):
		return "rescue failed to unlock the account companion"
	if Wildlife.claim(g, "invalid"):
		return "unknown creature could be rescued"
	for site in Wildlife.SITES:
		var v := Pet.new()
		v.setup(String(site.id))
		var good: bool = v.texture != null and v.hframes >= 1 and is_finite(v.scale.y)
		var expected: Vector2 = Art.scale_for_alpha_height(v.texture, Balance.PET_BODY_HEIGHT, v.hframes) if v.texture != null else Vector2.ZERO
		good = good and v.scale.is_equal_approx(expected)
		v.animate(1.0)
		good = good and v.frame >= 0 and v.frame < v.hframes
		v.free()
		if not good:
			return "companion atlas/scale failed: " + String(site.id)
	Story.ALL_SIDE_QUESTS["_qa_guide"] = {"name": "A guide fixture", "scope": "world", "steps": [
		{"flag": "qa_guide_one", "text": "Find the guide"}, {"flag": "qa_guide_two", "text": "Return"}]}
	g.flags["sq_on__qa_guide"] = true
	g.flags.erase("qa_guide_one")
	g.flags.erase("qa_guide_two")
	g.flags.erase("sq_paid__qa_guide")
	Guide._setters = {"qa_guide_one": ["qa_convo"]}
	Guide._indexed = true
	var npc := Node2D.new()
	npc.position = g.room_center(g.cur_room)
	npc.set_meta("quest_convo", "qa_convo")
	g.world.add_child(npc)
	var entry := {"node": npc}
	g.interactables.append(entry)
	var error := _guide_checks(g)
	g.interactables.erase(entry)
	npc.free()
	return error


static func _guide_checks(g: Game) -> String:
	var step := Guide.step(g, "_qa_guide")
	if String(step.get("flag", "")) != "qa_guide_one":
		return "guide did not choose the next incomplete objective"
	# Standalone worlds deliberately reveal their full maps; campaign worlds
	# must still keep even a live but unvisited target behind fog.
	if not Story.is_standalone(g.chapter_id):
		g.visited = {}
		g.door_seen = {}
		if not Guide.destination(g, step).is_empty():
			return "quest guidance leaked an uncharted objective"
	g.visited[g.cur_room] = true
	var target := Guide.destination(g, step)
	if target.is_empty() or int(target.room) != g.cur_room:
		return "a charted local quest NPC was not located"
	g.hud.wayfinder.track("_qa_guide")
	g.hud.wayfinder._sample_quest()
	if not g.hud.wayfinder.quest_root.visible:
		return "tracking did not display the objective card"
	var section := SaveGame._character_section(g)
	if String(section.get("tracked_quest", "")) != "_qa_guide":
		return "quest selection was not saved with the character"
	g.flags["qa_guide_one"] = true
	if String(Guide.step(g, "_qa_guide").get("flag", "")) != "qa_guide_two":
		return "guide did not advance after a completed objective"
	g.hud.wayfinder.track("")
	g.hud.wayfinder.pinned_room = g.cur_room
	g.hud.wayfinder._sample_quest()
	if g.hud.wayfinder.pinned_room != g.cur_room:
		return "retired quest tracking erased a later manual route"
	return ""
