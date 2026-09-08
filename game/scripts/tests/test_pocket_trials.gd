extends RefCounted
const Trial := preload("res://scripts/pocket_trial.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.player
	var world := {}
	for key in ["pocket_id", "pocket_room", "pocket_done", "pocket_origin", "pocket_origin_offset", "zones", "boss_done", "unlisted_banked", "fight_stats"]:
		var value = g.get(key)
		world[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	var player := {}
	for key in ["hp", "mp", "consumables", "room_potions", "potion_cd", "active_potion"]:
		var value = p.get(key)
		player[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	var v := Trial.new()
	v.game = g
	v.zone = g.cur_room
	v.arena = true
	var error := _checks(g, p, v)
	v.free()
	for key in world:
		g.set(key, world[key])
	for key in player:
		p.set(key, player[key])
	if error == "":
		print("ok: portal rules (belt/bag preserve bottles, budgets and records; independent guardian completion; finite clocks/return offsets; legacy float migration)")
	return error


static func _checks(g: Game, p: Player, v: Node2D) -> String:
	g.pocket_room = g.cur_room
	g.pocket_id = "still_larder"
	g.pocket_done = false
	var bottle := Items.make_potion("health", "instant", "F", "accord")
	if bottle.is_empty():
		return "potion fixture missing"
	p.consumables = [bottle]
	p.room_potions = {"health": 1, String(bottle.id): 1}
	p.active_potion = "health"
	p.hp = p.max_hp * 0.5
	p.potion_cd = 0.0
	var before := p.hp
	var records := g.fight_stats.duplicate(true)
	p.drink_potion()
	p.potion_cd = 0.0
	p.use_consumable(bottle)
	if p.consumables.size() != 1 or p.room_potions.health != 1 \
		or p.room_potions[String(bottle.id)] != 1 or p.hp != before or g.fight_stats != records:
		return "the Larder's seal consumed a bottle/budget/record through belt or bag"
	g.pocket_done = true
	if Trial.potions_locked(g, p):
		return "bottles stayed sealed after victory"
	g.pocket_done = false
	g.pocket_id = "molten_court"
	if Trial.potions_locked(g, p):
		return "Molten Court sealed bottles"
	g.zones = g.zones.duplicate(true)
	g.zones[g.cur_room]["boss"] = "cinderhide"
	g.zones[g.cur_room]["pocket"] = "molten_court"
	g.boss_done["cinderhide"] = true
	if g._boss_room_resolved(g.cur_room):
		return "campaign Cinderhide suppressed the pocket's guardian"
	g.pocket_done = true
	if not g._boss_room_resolved(g.cur_room):
		return "completed pocket guardian would respawn"
	g.zones[g.cur_room].erase("pocket")
	g.zones[g.cur_room]["unlisted"] = "greymantle"
	g.unlisted_banked = []
	if g._boss_room_resolved(g.cur_room):
		return "campaign flag suppressed an unlisted guardian"
	g.zones[g.cur_room].erase("unlisted")
	if not g._boss_room_resolved(g.cur_room):
		return "ordinary campaign completion was lost"
	for value in [NAN, INF, -1.0, Balance.POCKET_PULSE_REST + 10.0]:
		if v.apply_state(1, 0, value):
			return "invalid pocket clock accepted"
	if v.apply_state(9, 0, 1.0) or v.apply_state(1, 4, 1.0):
		return "invalid pocket phase/side accepted"
	if not v.apply_state(1, 1, 2.0) or v.hot_rect().has_point(g.room_center(g.cur_room)):
		return "valid clock rejected or center seam heats"
	SaveGame.restore_pocket(g, {"pocket_origin": g.cur_room, "pocket_origin_offset": [NAN, INF]})
	if g.pocket_origin_offset != Vector2.ZERO:
		return "non-finite return offset accepted"
	SaveGame.restore_pocket(g, {"pocket_done": true, "pocket_origin": g.cur_room, "pocket_origin_offset": [120.0, -20.0]})
	if not g.pocket_done or g.pocket_origin_offset != Vector2(120, -20):
		return "valid return snapshot lost"
	var at := Vector2(9000.0 * Game.ROOM_W, 9000.0 * Game.ROOM_H) + Vector2(320, 280)
	var expected: Vector2 = g.rooms[g.pocket_room]["origin"] + Vector2(320, 280)
	if g.pocket_position_legacy(at) != expected:
		return "legacy distant pocket position was not migrated"
	return ""
