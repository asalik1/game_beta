extends RefCounted
## Deterministic graph contracts plus the real map's actionable UI.
const Nav := preload("res://scripts/ui/navigation.gd")


static func run(t: Node) -> String:
	var fixture := Game.new()
	var graph_error := _graph_contracts(fixture)
	fixture.free()
	if graph_error != "":
		return graph_error
	var g: Game = t.game
	var guide: Control = g.hud.wayfinder
	var old_pin: int = guide.pinned_room
	var old_context: String = guide._context
	var old_path: Array[int] = guide.pinned_path.duplicate()
	var old_block: String = guide._route_block
	var ui_error: String = await _ui_contracts(t)
	g.menus.close()
	guide.pinned_room = old_pin
	guide._context = old_context
	guide.pinned_path = old_path
	guide._route_block = old_block
	if ui_error == "":
		print("ok: wayfinder fog, locked routes, pocket isolation, live loot and atlas selection")
	return ui_error


static func _graph_contracts(g: Game) -> String:
	g.chapter_id = "ch1"
	g.zones = []
	g.rooms = []
	g.coord_to_room = {}
	# 0—1—2—3, with a branch 1—4. Room 5 is a detached pocket arena.
	var coords := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(9000, 9000)]
	var exits := [{"E": ""}, {"W": "", "E": "", "S": ""}, {"W": "", "E": ""}, {"W": ""}, {"N": ""}, {}]
	for i in coords.size():
		g.rooms.append({"coord": coords[i], "origin": Vector2(coords[i]) * Vector2(Game.ROOM_W, Game.ROOM_H), "scale": Vector2.ONE, "exits": exits[i]})
		g.zones.append({"name": "Secret room %d" % i, "type": "combat", "enemies": [], "boss": ""})
		g.coord_to_room[coords[i]] = i
	g.zone_count = g.rooms.size()
	g.cur_room = 0
	g.visited = {0: true, 1: true, 5: true}
	g.door_seen = {1: true, 2: true, 4: true}
	if Nav.route(g, 0, 2) != [0, 1, 2]:
		return "route failed to reach an observed frontier through explored rooms"
	if not Nav.route(g, 0, 3).is_empty() or Nav.known(g, 3):
		return "route revealed an unseen room beyond a frontier"
	if Nav.room_name(g, 2).contains("Secret"):
		return "atlas leaked an unexplored room name"
	if Nav.chart_rooms(g).has(5) or not Nav.route(g, 0, 5).is_empty():
		return "detached pocket polluted the mainland chart or route"
	g.edge_locks[g._edge_key(1, 2)] = {"lock": "flag:wayfinder_fixture", "own": 1}
	if not Nav.route(g, 0, 2).is_empty():
		return "route crossed a sealed story gate"
	var locked: Array[int] = Nav.route(g, 0, 2, true)
	if locked != [0, 1, 2] or Nav.first_lock(g, locked) == "":
		return "atlas cannot explain a sealed route"
	g.flags["wayfinder_fixture"] = true
	if Nav.route(g, 0, 2) != [0, 1, 2]:
		return "route failed to refresh after a story gate opened"
	g.visited[2] = true
	g.door_seen[3] = true
	if Nav.route(g, 4, 3).size() > 0:
		return "route traversed an unvisited starting room"
	if Nav.route(g, 0, 3) != [0, 1, 2, 3]:
		return "new exploration failed to extend the route"
	if Nav.route(g, 0, 0) != [0] or not Nav.route(g, -1, 0).is_empty():
		return "route mishandled an empty or same-room destination"
	g.cur_room = 5
	if Nav.chart_rooms(g) != [5]:
		return "a pocket chart should show its own isolated arena"
	return ""


static func _ui_contracts(t: Node) -> String:
	var g: Game = t.game
	g.menus.open_map()
	await t._frames(3)
	var atlas: Control = g.menus.root.find_child("FieldAtlas", true, false)
	if atlas == null:
		return "field atlas did not open from the map action"
	if atlas.selected != g.cur_room:
		return "field atlas did not select the current room"
	var pin: Button = atlas.find_child("PinRoute", true, false)
	if pin == null or not pin.disabled:
		return "atlas should not pin the room the player already occupies"
	# World cleanup can retire an NPC before its interaction entry is removed.
	# Sampling that entry must be harmless, including while a co-op menu is up.
	var keep_interactables: Array = g.interactables.duplicate()
	var retired := Node2D.new()
	g.interactables.append({"node": retired})
	retired.free()
	g.hud.wayfinder._sample()
	g.interactables = keep_interactables
	g.hud.wayfinder.sync()
	if g.hud.wayfinder.visible:
		return "wayfinder remained active under an input overlay"
	var choices: Array[int] = Nav.chart_rooms(g)
	for room in choices:
		if room == g.cur_room:
			continue
		atlas.select_room(room)
		await t._frames(2)
		pin = atlas.find_child("PinRoute", true, false)
		if pin == null or pin.disabled:
			return "observed connected passage was not selectable for a route"
		pin.pressed.emit()
		if g.hud.wayfinder.pinned_room != room:
			return "Set route button did not create the route pin"
		g.hud.wayfinder._context = "retired chapter"
		g.hud.wayfinder._process(0.0)
		if g.hud.wayfinder.pinned_room != -1:
			return "a route pin survived into a different chapter context"
		break
	g.hud.wayfinder.pinned_room = g.cur_room
	g.hud.wayfinder._sample()
	if g.hud.wayfinder.pinned_room != -1 or g.hud.wayfinder._arrival_t <= 0.0:
		return "arrival failed to retire the route pin and acknowledge the destination"
	# Use the actual drop factory so registration and hidden-loot filtering are
	# exercised together. The chest is distant and has no frame to auto-open.
	var pos := g.local_player.global_position + Vector2(400, 0)
	var room: int = g.room_at_pos(pos)
	var chest := Chest.drop(g, "wood", pos, {"grade": "F"})
	var registered := Nav.room_chests(g, room).has(chest)
	chest.buried = true
	var hidden := not Nav.room_chests(g, room).has(chest)
	chest.buried = false
	chest.opened = true
	var opened := not Nav.room_chests(g, room).has(chest)
	chest.free()
	if not registered or not hidden or not opened:
		return "live map chest registration or hidden/opened filtering failed"
	return ""
