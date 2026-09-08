extends RefCounted
const Fishing := preload("res://scripts/fishing.gd")


static func run(t: Node) -> String:
	var error := _loop()
	if error == "":
		error = _records(t.game)
	if error == "":
		error = _layout(t.game)
	if error == "":
		print("ok: fishing timing, 120 seeded fights, 128 village/weekly layouts, lure habitats, claim-once and persistent catch records")
	return error


static func _loop() -> String:
	var seen := {}
	for seed_value in 120:
		var model := Fishing.new()
		model.rng.seed = seed_value + 1907
		if not model.cast("clear" if seed_value % 2 == 0 else "dark", Fishing.LURES.keys()[seed_value % 3]):
			return "legal cast rejected"
		if model.cast("clear", "fly"):
			return "a second cast replaced a live bite"
		for i in 400:
			model.step(1.0 / 60.0, false)
			if model.state == "bite":
				break
		if model.state != "bite":
			return "a cast never offered its bite window"
		model.hook()
		if not model.clean_hook:
			return "prompt strike was not a clean hook"
		for i in 2400:
			model.step(1.0 / 60.0, not model.surge() and not model.warning() and model.tension < 0.70)
			if model.state != "reeling":
				break
		if model.state != "landed":
			return "responsive angler could not land seed %d (%s): %s" % [seed_value, model.species, model.result_text]
		seen[model.species] = true
		var bounds: Vector2 = Fishing.SPECIES[model.species].size
		if model.length_cm < bounds.x or model.length_cm > bounds.y:
			return "catch size escaped its species range"
	if seen.size() != Fishing.ORDER.size():
		return "seeded catches never visited every species"
	for scenario in ["early", "miss", "hold", "slack"]:
		var model := Fishing.new()
		model.rng.seed = 1907
		model.cast("dark", "feather")
		if scenario == "early":
			model.hook()
		else:
			while model.state == "waiting":
				model.step(0.1, false)
			if scenario != "miss":
				model.hook()
			for i in 500:
				model.step(0.1, scenario == "hold")
		if model.state != "escaped":
			return "fishing failure condition did not resolve: " + scenario
	var dark := Fishing.weights("dark", "feather")
	var clear := Fishing.weights("clear", "fly")
	if dark[2] <= clear[2] or clear[0] <= dark[0]:
		return "lures and habitats have no effect on catches"
	var idle := Fishing.new()
	idle.step(NAN, true)
	idle.step(-1, true)
	if not is_finite(idle.age) or idle.age != 0.0:
		return "invalid delta poisoned the fishing clock"
	return ""


static func _layout(g: Game) -> String:
	# Layout is synchronous: restore the live world's references before any
	# process/physics frame can observe the temporary graphs, including failure.
	var saved := {}
	for key in ["zones", "zone_count", "rooms", "coord_to_room", "edge_locks", "terrain_by_zone", "wander_seed", "chapter_id"]:
		saved[key] = g.get(key)
	var error := _layout_checks(g)
	for key in saved:
		g.set(key, saved[key])
	return error


static func _layout_checks(g: Game) -> String:
	g.chapter_id = "ch1"
	for week in [-1, 0, 1, 2]:
		var base: Array = Story.ZONES.duplicate(true)
		var expanded: Array = Story.chapter("ch1").zones.duplicate(true)
		if week >= 0:
			base = g._waking_inject(base, "ch1", week)
			expanded = g._waking_inject(expanded, "ch1", week)
		for seed_value in 32:
			var error := _one_layout(g, base, expanded, seed_value + 907)
			if error != "":
				return "%s (week %d, seed %d)" % [error, week, seed_value + 907]
	return ""


static func _one_layout(g: Game, base: Array, expanded: Array, seed_value: int) -> String:
	var bank := -1
	for i in expanded.size():
		if expanded[i].name == "Stillwater Reach":
			bank = i
	if bank < base.size():
		return "fishing branch shifted existing authored / breach room indices"
	var previous: Array = []
	for z in [base, expanded]:
		g.zones = z
		g.zone_count = z.size()
		g.rooms = []
		g.coord_to_room = {}
		g.edge_locks = {}
		g.terrain_by_zone = []
		for row in z:
			g.terrain_by_zone.append(row.terrain)
		g.wander_seed = seed_value
		g._generate_layout(Story.chapter("ch1").spine)
		if previous.is_empty():
			previous = g.rooms.duplicate(true)
	for i in base.size():
		if g.rooms[i].coord != previous[i].coord or base[i].name != expanded[i].name:
			return "fishing branch moved an existing seeded / breach room"
	if g.rooms[bank].exits.size() != 1:
		return "fishing bank is disconnected or blocks the story path"
	var dir: String = g.rooms[bank].exits.keys()[0]
	var host := g.neighbor(bank, dir)
	if host < 0 or g.terrain_by_zone[host] != "village":
		return "fishing bank wandered away from the village"
	return ""


static func _records(g: Game) -> String:
	var p: Player = g.local_player
	var saved: Dictionary = p.fishing_book.duplicate(true)
	var error := _record_checks(g)
	p.fishing_book = saved
	return error


static func _record_checks(g: Game) -> String:
	var p: Player = g.local_player
	p.fishing_book = {}
	var model := Fishing.new()
	if not model.claim(p).is_empty():
		return "unlanded fish paid a collection record"
	model.state = "landed"
	model.species = "koi"
	model.length_cm = 67.5
	var first := model.claim(p)
	if not first.get("first", false) or not first.get("record", false):
		return "first specimen failed to register a discovery and personal best"
	if not model.claim(p).is_empty() or int(p.fishing_book.koi.count) != 1:
		return "double claim duplicated a catch"
	model.claimed = false
	model.length_cm = 40
	var second := model.claim(p)
	if second.record or second.first or p.fishing_book.koi.best != 67.5 or p.fishing_book.koi.count != 2:
		return "smaller repeat catch erased the best specimen"
	var data: Dictionary = SaveGame._character_section(g)
	if not data.has("fishing_book"):
		return "catch book omitted from character save / guest take-home"
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(data.fishing_book))
	if Fishing.clean_book(round_trip) != p.fishing_book:
		return "catch records changed across JSON save round-trip"
	var malformed := {"retired": {"count": 1, "best": 55}, "dace": {"count": "bad", "best": []},
		"eel": {"count": -4, "best": NAN}, "koi": {"count": 3, "best": INF}}
	if not Fishing.clean_book(malformed).is_empty() or not Fishing.clean_book([]).is_empty():
		return "malformed catch save was trusted"
	if not Fishing.clean_book({}).is_empty():
		return "old save invented a catch collection"
	return ""
