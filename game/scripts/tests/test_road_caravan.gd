extends RefCounted
const Caravan := preload("res://scripts/road_caravan.gd")
const Hunt := preload("res://scripts/road_hunt.gd")
const FixtureTypes := preload("res://scripts/tests/test_road_hunt.gd")
const Nav := preload("res://scripts/ui/navigation.gd")
const History := preload("res://scripts/character_history.gd")


static func run(t: Node) -> String:
	var g := FixtureTypes.Fixture.new()
	g.no_saves = true
	g.play_started = true
	g.chapter_id = "ch1"
	g.wander_seed = 12345
	g.cur_room = 0
	g.zones = [{"type": "social"}]
	g.terrain_by_zone = ["village"]
	t.add_child(g)
	g.world = Node2D.new()
	g.add_child(g.world)
	g.hud = FixtureTypes.QuietHUD.new()
	g.hud.game = g
	g.add_child(g.hud)
	g.menus = Menus.new()
	g.menus.game = g
	g.add_child(g.menus)
	var p := Player.new()
	p.game = g
	p.hp = 100
	p.max_hp = 100
	g.player = p
	g.players = [p]
	var error := _checks(g)
	g.player = null
	g.players = []
	p.free()
	g.free()
	if error == "":
		print("ok: caravan reach/incapacity/rate/pressure, two-wave witnessed kills, run-scoped prices, bounded ordered snapshots, abandonment, missing-enemy cancellation and map world isolation")
	return error


static func _wave(g: Game, cart: Node2D) -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	cart.phase = Caravan.WORKING
	cart.remaining = 0.0
	cart.arrival_points.clear()
	for i in Balance.CARAVAN_WAVES[cart.wave - 1]:
		var enemy := FixtureTypes.QuietEnemy.new()
		enemy.game = g
		enemy.zone_idx = -1
		enemy.position = cart.global_position + Vector2(350 + i * 30, 0)
		enemy.set_meta("road_caravan_owner", cart)
		g.world.add_child(enemy)
		cart.enemies.append(enemy)
		cart.pending_deaths.append(enemy.get_instance_id())
		enemies.append(enemy)
	return enemies


static func _checks(g: Game) -> String:
	var retired := Sprite2D.new()
	g.active_facing_interactable = {"sprite": retired}
	retired.free()
	g._restore_interactable_rest_pose()
	g._face_interactable_to_player({"node": retired, "sprite": retired})
	if not g.active_facing_interactable.is_empty():
		return "a withdrawn trader retained stale facing state"
	g.touch_mode = true
	var touch_prompt: String = g.touchify("Hold E — Pull the cart")
	g.touch_mode = false
	if touch_prompt != "Hold Act — Pull the cart":
		return "touch pulling prompt does not name the actual Act button"
	var before := [g.player.gold, g.player.xp, g.run_road_cards, g.quest_kills.duplicate(), g.zone_alive.duplicate(), g.loot_rng.state]
	var markup: float = g.shop_markup(0)
	var cart := Caravan.begin(g, 0)
	if cart == null:
		return "no cart in a clear eligible road"
	cart.set_physics_process(false)
	g.player.position = cart.handle.global_position
	if Caravan.begin(g, 0) != null or Hunt.begin(g, 0, g.room_center(0)) != null or cart.request(g.player):
		return "caravan allowed parallel encounters or work during the warning"
	var raw: Dictionary = cart.snapshot()
	if Caravan.clean_snapshot(g, raw).is_empty():
		return "caravan rejected its own warning snapshot"
	for field in raw:
		var malformed := raw.duplicate(true)
		malformed[field] = null
		if not Caravan.clean_snapshot(g, malformed).is_empty():
			return "caravan accepted mistyped " + str(field)
	for bad in [{"token": 0}, {"revision": -1}, {"phase": 99}, {"wave": 0}, {"tugs": 999},
		{"integrity": NAN}, {"integrity": -1.0}, {"remaining": INF}, {"foes": -1},
		{"at": Vector2(-999, 0)}, {"points": [Vector2(INF, 0), Vector2.ZERO]}, {"kind": "unknown"}]:
		var malformed := raw.duplicate(true)
		malformed.merge(bad, true)
		if not Caravan.clean_snapshot(g, malformed).is_empty():
			return "caravan accepted invalid snapshot: " + str(bad)
	var wave := _wave(g, cart)
	g.player.position += Vector2(500, 0)
	if cart.request(g.player) or cart.request(null):
		return "distant or missing helper pulled the wheel"
	g.player.position = cart.handle.global_position
	for state in ["dead", "downed", "ghost"]:
		g.player.set(state, true)
		var accepted: bool = cart.request(g.player)
		g.player.set(state, false)
		if accepted:
			return "incapacitated helper pulled: " + state
	wave[0].position = cart.global_position
	var hp: float = cart.integrity
	cart._physics_process(1.0)
	if cart.request(g.player) or cart.integrity >= hp or cart.tugs != 0:
		return "pressure failed to damage the load or block pulling"
	wave[0].position += Vector2(400, 0)
	if not cart.request(g.player) or cart.request(g.player) or cart.tugs != 1:
		return "pull cooldown allowed repeated work or rejected the first clear tug"
	for i in 5:
		cart.clock += Balance.CARAVAN_TUG_INTERVAL
		if not cart.request(g.player):
			return "a clear wheel stopped accepting work"
	if cart.wave != 1 or cart.tugs != 6:
		return "the second attack skipped live enemies from the first"
	for enemy in wave:
		g.on_enemy_died(enemy)
	if cart.pending_deaths.size() != 2:
		return "live enemies were counted as deaths"
	for enemy in wave:
		enemy.dying = true
		g.on_enemy_died(enemy)
	if cart.phase != Caravan.PREPARING or cart.wave != 2:
		return "confirmed first-wave deaths did not start the second warning"
	wave = _wave(g, cart)
	for i in 6:
		cart.clock += Balance.CARAVAN_TUG_INTERVAL
		cart.request(g.player)
	if cart.tugs != 12 or Caravan.supplied(g):
		return "unfinished attackers supplied the road or wheel did not become free"
	for enemy in wave:
		enemy.dying = true
		g.on_enemy_died(enemy)
		g.on_enemy_died(enemy)
	if cart.phase != Caravan.COMPLETE or not Caravan.supplied(g) or g.run_road_cards != before[2] + 1:
		return "victory did not settle exactly once"
	if [g.player.gold, g.player.xp, g.quest_kills, g.zone_alive, g.loot_rng.state] != [before[0], before[1], before[3], before[4], before[5]]:
		return "caravan added normal gold, XP, purge, kill quests or loot RNG consumption"
	if not is_equal_approx(g.shop_markup(0), markup * Balance.CARAVAN_PRICE_MULT) \
		or History.is_local(Caravan.benefit_flag(g)) or not History.world_only(g.flags).has(Caravan.benefit_flag(g)):
		return "trade benefit has the wrong price or character ownership"
	g.wander_seed += 1
	if Caravan.supplied(g):
		return "caravan benefit leaked into another seed"
	g.wander_seed -= 1
	g.chapter_id = "capital"
	if Caravan.supplied(g) or g.shop_markup(0) != 1.0:
		return "road discount reached the Crown Bazaar"
	g.chapter_id = "ch1"
	g.endgame_active = true
	if Caravan.supplied(g) or g.shop_markup(0) != 1.0:
		return "road discount reached the endgame economy"
	g.endgame_active = false
	cart.free()
	g.flags.clear()  # this test owns its isolated fixture
	g.guest = true
	var notes: int = g.hud.notes.size()
	var mirror := Caravan.receive(g, raw)
	if mirror == null or g.hud.notes.size() != notes or Caravan.supplied(g):
		return "late warning replayed feedback or granted prices"
	var newer := raw.duplicate(true)
	newer.revision += 1
	newer.integrity = 75.0
	Caravan.receive(g, newer)
	Caravan.receive(g, raw)
	if mirror.integrity != 75.0:
		return "an older snapshot rewound the load"
	mirror.free()
	g.guest = false
	var missing := Caravan.begin(g, 0)
	missing.set_physics_process(false)
	wave = _wave(g, missing)
	wave[0].free()
	missing._physics_process(0.1)
	if not missing.is_queued_for_deletion() or Caravan.supplied(g) or not wave[1].is_queued_for_deletion():
		return "a missing attacker paid or left a partial wave behind"
	missing.free()
	var abandoned := Caravan.begin(g, 0)
	abandoned.set_physics_process(false)
	wave = _wave(g, abandoned)
	g.cur_room = 1
	abandoned._physics_process(0.1)
	g.cur_room = 0
	if not abandoned.is_queued_for_deletion() or Caravan.supplied(g) or not wave[0].is_queued_for_deletion():
		return "abandonment failed to retire the wave without payment"
	abandoned.free()
	var lost := Caravan.begin(g, 0)
	lost.set_physics_process(false)
	wave = _wave(g, lost)
	wave[0].position = lost.global_position
	lost.integrity = 1.0
	lost._physics_process(1.0)
	if not lost.is_queued_for_deletion() or Caravan.supplied(g) or g.player.gold != before[0]:
		return "a lost load failed to retire cleanly without an extra charge"
	lost.free()
	g.blocked = true
	if Caravan.begin(g, 0) != null:
		return "cart was installed inside blocked terrain"
	g.blocked = false
	var neighbor := Node2D.new()
	g.world.add_child(neighbor)
	neighbor.global_position = g.room_center(0) + Balance.CARAVAN_HANDLE_OFFSET
	var interaction := {"node": neighbor}
	g.interactables.append(interaction)
	var clear_point := Caravan.placement(g, 0)
	g.interactables.erase(interaction)
	var separation := neighbor.global_position.distance_to(clear_point + Balance.CARAVAN_HANDLE_OFFSET)
	neighbor.free()
	if not clear_point.is_finite() or separation < Balance.CARAVAN_INTERACTION_CLEARANCE:
		return "cart handle overlaps a neighboring conversation or service"
	return _map_isolation(g)


static func _map_isolation(g: Game) -> String:
	var own := FixtureTypes.QuietEnemy.new()
	own.game = g
	own.zone_idx = 0
	g.world.add_child(own)
	own.add_to_group("enemies")
	var other := FixtureTypes.QuietEnemy.new()
	other.zone_idx = 0
	g.world.add_child(other)
	other.add_to_group("enemies")
	if not Nav.room_enemies(g, 0).has(own) or Nav.room_enemies(g, 0).has(other):
		return "map merged enemies from another game"
	var retired := Node2D.new()
	g.add_child(retired)
	g.world.remove_child(own)
	retired.add_child(own)
	if Nav.room_enemies(g, 0).has(own):
		return "map counted a retired world's enemy"
	var chest := Chest.new()
	chest.game = g
	g.add_child(chest)  # Chest.drop owns loot directly under Game, not world
	chest.add_to_group("wayfinder_chests")
	var foreign := Chest.new()
	g.add_child(foreign)
	foreign.add_to_group("wayfinder_chests")
	if not Nav.room_chests(g, 0).has(chest) or Nav.room_chests(g, 0).has(foreign):
		return "map lost direct-owned loot or merged another reader's chest"
	return ""
