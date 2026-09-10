extends RefCounted
## A local, fog-respecting bridge from authored objectives to the world.
## Flag setters are indexed once; no quest-specific parallel location table.
const Nav := preload("res://scripts/ui/navigation.gd")
static var _setters: Dictionary = {}
static var _indexed := false


static func _index(value, convo: String) -> void:
	if value is Dictionary:
		for flag_name in value.get("flags", {}):
			if value["flags"][flag_name] == true:
				if not _setters.has(flag_name):
					_setters[flag_name] = []
				if not _setters[flag_name].has(convo):
					_setters[flag_name].append(convo)
		for child in value.values():
			if child is Dictionary or child is Array:
				_index(child, convo)
	elif value is Array:
		for child in value:
			_index(child, convo)


static func active(g: Game, id: String) -> bool:
	var q: Dictionary = Story.ALL_SIDE_QUESTS.get(id, {})
	return not q.is_empty() and g.get_flag("sq_on_" + id, false) \
		and not g.get_flag("sq_paid_" + id, false) \
		and (not Story.quest_scoped(q) or String(q.get("chapter", "")) == g.chapter_id)


static func step(g: Game, id: String) -> Dictionary:
	if not active(g, id):
		return {}
	for objective in Story.ALL_SIDE_QUESTS[id].get("steps", []):
		if not g.get_flag(String(objective["flag"]), false):
			return objective
	return {}


static func describe(g: Game, objective: Dictionary) -> String:
	var copy := String(objective.get("text", "Promise kept"))
	if String(objective.get("kind", "")) == "kill":
		copy += " (%d/%d)" % [int(g.quest_kills.get(objective["flag"], 0)), int(objective.get("count", 1))]
	return copy


static func destination(g: Game, objective: Dictionary) -> Dictionary:
	if objective.is_empty():
		return {}
	if not _indexed:
		Story.load_content()
		for cid in Story.ALL_CONVOS:
			_index(Story.ALL_CONVOS[cid], String(cid))
		_indexed = true
	var convos: Array = _setters.get(String(objective.get("flag", "")), [])
	var candidates: Array[Dictionary] = []
	# Live NPCs include seeded wanderers and conditional props. Their profile
	# metadata also locates the precise interaction point in the current room.
	for entry in g.interactables:
		var node = entry.get("node")
		if is_instance_valid(node) and node is Node2D and node.is_visible_in_tree() \
				and (convos.has(String(node.get_meta("quest_convo", ""))) \
					or String(node.get_meta("quest_flag", "")) == String(objective.get("flag", "_none"))):
			_add(g, candidates, g.room_at_pos(node.global_position), node.global_position)
	if String(objective.get("flag", "")) == preload("res://scripts/ward_vigil.gd").DONE:
		for zi in g.zones.size():
			if g.charted(zi) and preload("res://scripts/ward_vigil.gd").eligible(g, zi):
				_add(g, candidates, zi, preload("res://scripts/ward_vigil.gd").point(g, zi))
	if String(objective.get("flag", "")) == preload("res://scripts/wayfarer.gd").DONE:
		for zi in g.zones.size():
			if g.charted(zi) and preload("res://scripts/wayfarer.gd").eligible(g, zi):
				_add(g, candidates, zi, preload("res://scripts/wayfarer.gd").route(g, zi)[0])
	for zi in g.zones.size():
		if not g.charted(zi):
			continue
		for npc in g.zones[zi].get("npcs", []):
			if not convos.has(String(npc.get("convo", ""))) or npc.get("placeholder", false):
				continue
			if npc.has("req_flag") and not g.get_flag(String(npc.req_flag), false):
				continue
			if npc.has("req_not_flag") and g.get_flag(String(npc.req_not_flag), false):
				continue
			if npc.has("req_wanderer") and not g._wanderer_rolled(String(npc.req_wanderer)):
				continue
			_add(g, candidates, zi, g.room_pos(zi, float(npc.x), float(npc.y)))
	if String(objective.get("kind", "")) in ["kill", "hunt"]:
		for node in g.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e == null or e.dying or e.is_queued_for_deletion():
				continue
			if e.kind == String(objective.get("target", "")) \
					and (String(objective.get("kind", "")) == "kill" or e.hunt_flag == String(objective.flag)):
				_add(g, candidates, e.zone_idx, e.global_position)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.sealed) != bool(b.sealed):
			return not bool(a.sealed)
		if int(a.hops) != int(b.hops):
			return int(a.hops) < int(b.hops)
		return float(a.distance) < float(b.distance))
	return candidates[0]


static func _add(g: Game, candidates: Array[Dictionary], zi: int, point: Vector2) -> void:
	if zi < 0 or zi >= g.rooms.size() or not g.charted(zi):
		return
	var path: Array[int] = Nav.route(g, g.cur_room, zi)
	var sealed := path.is_empty()
	if sealed:
		path = Nav.route(g, g.cur_room, zi, true)
	if path.is_empty():
		return
	var distance: float = g.local_player.global_position.distance_to(point) if g.has_local_player() else 0.0
	candidates.append({"room": zi, "point": point, "path": path,
		"sealed": sealed, "hops": path.size(), "distance": distance})
