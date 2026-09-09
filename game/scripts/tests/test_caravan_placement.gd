extends RefCounted
const Types := preload("res://scripts/tests/test_road_hunt.gd")
const Caravan := preload("res://scripts/road_caravan.gd")

class LaneGame extends Types.Fixture:
	var block_all := false
	func _pos_in_wall(pos: Vector2) -> bool:
		return block_all or pos.x > 430.0

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
		print("ok: caravan finds an outer clear lane, preserves handle/footprint clearance and rejects a fully blocked room")
	return error
