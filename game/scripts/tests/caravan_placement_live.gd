extends RefCounted
const Caravan := preload("res://scripts/road_caravan.gd")

static func run(r: Node) -> String:
	var g: Game = r.game
	var observations := []
	var failures: Array[int] = []
	var count := clampi(int(r.arg("seeds", "32")), 1, 64)
	for seed_value in count:
		g.menus.close()
		g.wander_seed = seed_value
		g.switch_chapter("ch1", true)
		g.terrain_event_t = 10000.0
		g.player.set_physics_process(false)
		var room := -1
		for i in g.zones.size():
			if String(g.zones[i].name) == "Village Outskirts":
				room = i
		if room < 0:
			return "placement sweep lost its Village Outskirts room"
		g.player.global_position = g.room_center(room)
		g._enter_room(room)
		await r.skip_dialogue()
		await r.frames(4)
		for entry in g.interactables.duplicate():
			var actor: Variant = entry.get("node")
			if is_instance_valid(actor) and actor.has_meta("road_context"):
				g._remove_interactable(actor)
		await r.frames(2)
		g._road_card_node(room, "caravan")
		var offer: Node2D
		for entry in g.interactables:
			if is_instance_valid(entry.node) and entry.node.has_meta("road_context"):
				offer = entry.node
		if offer == null:
			return "placement sweep failed to create the trader offer"
		g.player.global_position = offer.global_position + Vector2(20, 30)
		await r.frames(2)
		var point := Caravan.placement(g, room)
		g._road_caravan(room, offer)
		var accept: Button
		for candidate in g.menus.root.find_children("*", "Button", true, false):
			if candidate.text == "Help free the cart":
				accept = candidate
		if accept == null:
			return "placement sweep found no help option"
		var enabled := not accept.disabled
		if enabled:
			accept.pressed.emit()
		var cart := Caravan.find(g, room)
		observations.append({"seed": seed_value, "room": room,
			"bounds": str(g.play_rect(room)), "point": str(point),
			"offered": enabled, "started": cart != null})
		if enabled and cart == null:
			failures.append(seed_value)
			r._record_placement(room, "placement_%02d" % seed_value)
			if failures.size() <= 3:
				await r._capture("placement_failure_%02d" % seed_value)
		if cart != null:
			cart.cancel()
		await r.frames(3)
		print("CARAVAN SEED CHECK: ", JSON.stringify(observations[-1]))
	if not r._write_report("placement_sweep", {"samples": observations, "failures": failures}):
		return "could not write the caravan placement sweep"
	if not failures.is_empty():
		return "enabled caravan offers had no usable placement in seeds " + str(failures)
	var blocked_error := await _blocked_offer(r)
	if blocked_error != "":
		return blocked_error
	print("ok: %d seeded trader offers either started a reachable cart or accurately withheld the help action" % count)
	return ""


static func _help(g: Game) -> Button:
	if not is_instance_valid(g.menus.root):
		return null
	for candidate in g.menus.root.find_children("*", "Button", true, false):
		if candidate.text == "Help free the cart":
			return candidate
	return null


static func _blocked_offer(r: Node) -> String:
	var g: Game = r.game
	var room := g.cur_room
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = g.play_rect(room).get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = g.play_rect(room).size * 2.0
	collider.shape = shape
	body.add_child(collider)
	g.world.add_child(body)
	var error := await _blocked_checks(r, room, body)
	g.menus.close()
	if is_instance_valid(body):
		body.queue_free()
	return error


static func _blocked_checks(r: Node, room: int, body: StaticBody2D) -> String:
	var g: Game = r.game
	await r.frames(4)
	if Caravan.placement(g, room).is_finite():
		return "blocked-offer fixture did not actually block the room"
	g._road_card_node(room, "caravan")
	var offer: Node2D
	for entry in g.interactables:
		if is_instance_valid(entry.node) and entry.node.has_meta("road_context"):
			offer = entry.node
	if offer == null:
		return "blocked-offer fixture lost its trader"
	g.player.global_position = offer.global_position + Vector2(20, 30)
	g._road_caravan(room, offer)
	var help := _help(g)
	if help == null or not help.disabled:
		return "a fully blocked room advertised usable caravan help"
	var explanation := false
	for label in g.menus.root.find_children("*", "Label", true, false):
		explanation = explanation or "no clear space" in String(label.text)
	if not explanation:
		return "disabled caravan help did not explain its blocked placement"
	await r._capture("placement_33_blocked_offer")
	g.menus.close()
	body.queue_free()
	await r.frames(4)
	g._road_caravan(room, offer)
	help = _help(g)
	if help == null or help.disabled:
		return "restoring clear ground did not restore the caravan help option"
	await r._capture("placement_34_space_restored")
	help.pressed.emit()
	var cart := Caravan.find(g, room)
	if cart == null:
		return "the recovered help option still failed to start its cart"
	cart.cancel()
	return ""
