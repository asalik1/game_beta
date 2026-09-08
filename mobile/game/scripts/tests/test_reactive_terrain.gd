extends RefCounted
const Terrain := preload("res://scripts/reactive_terrain.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var flags: Dictionary = g.flags.duplicate(true)
	var zi: int = g.cur_room
	var scenery: Array = g.zone_scenery.get(zi, []).duplicate()
	var prop := Terrain.install(g, zi, 999, "ember", g.room_center(zi))
	prop.set_physics_process(false)
	var error := _contracts(g, prop)
	prop.free()
	g.zone_scenery[zi] = scenery
	g.flags = flags
	if error == "":
		print("ok: reactive terrain single-use reservation, ordered states, invalid snapshots, rebuilds and room eligibility")
	return error


static func _contracts(g: Game, prop: StaticBody2D) -> String:
	if Terrain.eligible(g, -1) or Terrain.eligible(g, g.zones.size()):
		return "terrain accepted an invalid room"
	for zi in g.zones.size():
		if String(g.zones[zi].get("boss", "")) != "" and Terrain.eligible(g, zi):
			return "terrain weapons were allowed in a boss arena"
	for invalid in [NAN, INF, -1.0, 100.0]:
		prop.apply_state(1, invalid)
		if prop.phase != 0:
			return "invalid terrain fuse changed the prop"
	if prop.request_prime(null, "interact"):
		return "missing terrain interactor was accepted"
	if not prop.prime() or prop.prime() or not g.get_flag(prop.key, false):
		return "terrain reservation was not atomic/single-use"
	prop.apply_state(1, 0.6)
	prop.apply_state(1, 1.4)
	if not is_equal_approx(prop.remaining, 0.6):
		return "repeated terrain snapshot extended its fuse"
	prop.apply_state(2, 0.0)
	prop.apply_state(1, 1.0)
	if prop.phase != 2 or prop.prime():
		return "spent terrain accepted a stale activation"
	var rebuilt := Terrain.install(g, prop.zone, prop.slot, "ember", prop.global_position)
	var spent: bool = rebuilt.phase == 2 and rebuilt.collision_layer == 0 and not rebuilt.sprite.visible
	rebuilt.free()
	if not spent:
		return "a scenery rebuild restored a consumed prop"
	return ""
