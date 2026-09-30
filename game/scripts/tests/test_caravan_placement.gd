extends RefCounted
const Types := preload("res://scripts/tests/test_road_hunt.gd")
const Caravan := preload("res://scripts/road_caravan.gd")
const Threshold := preload("res://scripts/door_threshold.gd")

class LaneGame extends Types.Fixture:
	var block_all := false
	func _pos_in_wall(pos: Vector2) -> bool:
		return block_all or pos.x > 430.0

## Open floor only in a pocket beside the west door lane: every centre ring is
## walled, so the fallback grid decides, and its first footprint-clear point
## has the painted cart over the west entrance.
class DoorLaneGame extends Types.Fixture:
	func _pos_in_wall(pos: Vector2) -> bool:
		return pos.x > 600.0 or absf(pos.y - 800.0) > 200.0

static func run(t: Node) -> String:
	var g := LaneGame.new()
	t.add_child(g)
	var point := Caravan.placement(g, 0)
	var error := ""
	if not point.is_finite() or not g.play_rect(0).grow(-Balance.CARAVAN_INSET).has_point(point):
		error = "caravan missed the clear lane outside its central placement circle"
	elif point.distance_to(g.room_center(0)) <= 3.0 * Balance.CARAVAN_PLACEMENT_STEP:
		error = "placement fixture did not exercise its outer clear lane"
	else:
		for offset in [Vector2.ZERO, Balance.CARAVAN_HANDLE_OFFSET, Vector2(-100, -50), Vector2(80, 70)]:
			if g._pos_in_wall(point + offset):
				error = "fallback cart footprint or handle crossed the wall"
	g.block_all = true
	if Caravan.placement(g, 0).is_finite():
		error = "a fully blocked room still offered a cart placement"
	g.free()
	if error == "":
		error = _door_lane(t)
	if error == "":
		print("ok: caravan finds an outer clear lane, preserves handle/footprint clearance, keeps its painted body off the west door threshold and rejects a fully blocked room")
	return error


static func _door_lane(t: Node) -> String:
	var g := DoorLaneGame.new()
	t.add_child(g)
	g.rooms = [{"origin": Vector2.ZERO, "scale": Vector2.ONE, "coord": Vector2i.ZERO, "exits": {"W": 1}}]
	var thresholds := Threshold.zones(g, 0)
	var error := ""
	var point := Caravan.placement(g, 0)
	if not point.is_finite():
		error = "caravan found no spot beside the west door lane"
	elif Threshold.intersects(thresholds, Caravan.art_rect(point)):
		error = "caravan cart painted over the west door threshold at %s" % point
	else:
		# Negative control: without the door the same grid's first clear point
		# is on that apron, so the check above really exercised the guard.
		g.rooms[0]["exits"] = {}
		var unguarded := Caravan.placement(g, 0)
		if not unguarded.is_finite() or not Threshold.intersects(thresholds, Caravan.art_rect(unguarded)):
			error = "door-lane caravan fixture never tempted placement onto the threshold"
	g.free()
	return error
