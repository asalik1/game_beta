extends RefCounted
const Vigil := preload("res://scripts/ward_vigil.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var flags := g.flags.duplicate(true)
	var kills := g.quest_kills.duplicate(true)
	var counters := g.zone_alive.duplicate(true)
	var cleared := g.cleared.duplicate(true)
	var materials := g.player.materials.duplicate(true)
	var drops := g.dropped_loot.duplicate(true)
	var rng_state := g.loot_rng.state
	var v := Vigil.new()
	v.game = g
	v.zone = g.cur_room
	v.position = g.room_center(g.cur_room)
	g.world.add_child(v)
	v.set_physics_process(false)
	var error := _checks(g, v)
	v.free()
	g.flags = flags
	g.quest_kills = kills
	g.zone_alive = counters
	g.cleared = cleared
	g.player.materials = materials
	g.dropped_loot = drops
	g.loot_rng.state = rng_state
	if error == "":
		print("ok: vigil content, fog target, hostile snapshot rejection, caller reach, reward-free wave deaths and purge isolation")
	return error


static func _checks(g: Game, v: Node2D) -> String:
	if not Story.ALL_SIDE_QUESTS.has("tower_light") or not Achievements.TITLES.has("lamplighter"):
		return "vigil lacks its quest or title"
	g.flags = {}
	if g.chapter_id == "ch1":
		if not g.side_quest_available("tower_light"):
			return "Mara's unfinished quest was hidden from discovery"
		g.flags["sq_kept_tower_light"] = true
		if g.side_quest_available("tower_light"):
			return "Mara's finished personal story was advertised again on replay"
		g.flags = {}
	for invalid in [NAN, INF, -1.0, 101.0]:
		v.apply_state(2, 1, invalid, 0.0, true, 0, [])
		if v.phase != 0:
			return "invalid ward integrity was accepted"
	v.apply_state(2, 1, 80.0, 0.0, true, 0, [Vector2(INF, 0)])
	if v.phase != 0:
		return "invalid arrival position was accepted"
	if v.request(null, "start") or v.request(g.player, "invented"):
		return "invalid vigil interactor/action was accepted"
	v.apply_state(2, 2, 65.0, 0.0, true, 2, [])
	if not v.active() or v.wave != 2 or v.integrity != 65.0:
		return "a valid ward snapshot was lost"
	v.cancel("")
	var e := Enemy.make(g, "skeleton", v.position, Balance.VIGIL_ENEMY_LEVEL)
	e.zone_idx = g.cur_room
	e.set_meta("ward_spawn", true)
	var rng_before := g.loot_rng.state
	var clear_before := g.zone_alive.duplicate(true)
	g.on_enemy_died(e)
	e.free()
	if g.loot_rng.state != rng_before or g.zone_alive != clear_before:
		return "a ward spawn rolled loot or changed the chapter purge"
	# Exercise the existing loose-quarry death handler, not just the new ward.
	g.flags = {}  # this fixture must not finish an unrelated accepted quest
	var quarry := Enemy.make(g, "wolf", v.position, Balance.VIGIL_ENEMY_LEVEL)
	quarry.from_quest = true
	quarry.xp_value = 0
	quarry.gold_value = 0
	quarry.zone_idx = g.cur_room
	var before_nodes := g.world.get_children()
	rng_before = g.loot_rng.state
	g.on_enemy_died(quarry)
	quarry.free()
	var changed := g.loot_rng.state != rng_before or g.zone_alive != clear_before
	for node in g.world.get_children():
		if not before_nodes.has(node):
			node.free()
	if changed:
		return "zero-reward quest quarry rolled loot or changed the chapter purge"
	return ""
