extends RefCounted
const Prism := preload("res://scripts/prism_crystal.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var crystal := StaticBody2D.new()
	crystal.position = g.room_center(g.cur_room)
	crystal.collision_layer = 0
	g.world.add_child(crystal)
	var prism := Prism.install(g, crystal)
	prism.set_process(false)
	var p := Projectile.spawn(g, crystal.global_position, Vector2.RIGHT * 320.0, 17.0, true, "arrow_base")
	p.set_physics_process(false)
	var error := _checks(g, p, prism)
	p.free()
	crystal.free()
	if error == "":
		print("ok: crystal fallback angles, finite guards, deferred contact reservation, payload/owner/hit-history preservation, bank budget and original range")
	return error


static func _checks(g: Game, p: Projectile, prism: Node2D) -> String:
	if Prism.eligible(g, -1) or Prism.eligible(g, g.zones.size()):
		return "a prism accepted a missing room"
	for zi in g.zones.size():
		if String(g.zones[zi].get("boss", "")) != "" and Prism.eligible(g, zi):
			return "prism banks changed a boss arena"
	# A zero reach exercises the facet without relying on campaign enemies.
	p.life = 0.0
	for degrees in 360:
		var direction := Vector2.from_angle(deg_to_rad(degrees))
		p.vel = direction * 320.0
		var reflected: Vector2 = prism.direction_for(p)
		if not reflected.is_finite() or not is_equal_approx(reflected.length(), 1.0):
			return "crystal facet changed speed or produced a nonfinite direction"
		p.vel = reflected * 320.0
		if prism.direction_for(p).distance_to(direction) > 0.0001:
			return "crystal facet did not reflect symmetrically"
	if p._try_bank(prism):
		return "an expired shot gained new flight from a crystal"
	p.life = 2.0
	for invalid in [Vector2.ZERO, Vector2(INF, 0), Vector2(NAN, 1)]:
		p.vel = invalid
		if p._try_bank(prism):
			return "a nonfinite or stationary shot entered a crystal bank"
	p.vel = Vector2.RIGHT * 320.0
	p.source_player = g.player
	p.fx = {"slow": 0.5, "pierce_cap": 3, "bloom_mist": 1}
	p.pierce = true
	p.homing = true
	p._already_hit[g.player] = true
	var payload := p.fx.duplicate(true)
	var child := Node2D.new()
	p.add_child(child)
	var id := p.get_instance_id()
	var impacts := [0]
	p.visual_impact.connect(func() -> void: impacts[0] += 1)
	if not p._try_bank(prism) or p._try_bank(prism):
		return "same-frame crystal contacts were not reserved exactly once"
	# Invoke the deferred body now; the queued call becomes an idempotent no-op.
	p._finish_bank(prism)
	if p.get_instance_id() != id or child.get_parent() != p or p.fx != payload \
			or p.source_player != g.player or p.dmg != 17.0 or not p.pierce or not p.homing \
			or not p._already_hit.has(g.player) or impacts[0] != 0:
		return "banking replaced a projectile or lost its payload/history/impact listener"
	if not is_equal_approx(p.vel.length(), 320.0) or p.life >= 2.0 or p.life <= 0.0:
		return "banking changed speed or refreshed the original flight budget"
	if p._try_bank(prism):
		return "a shot banked from the same crystal twice"
	p._banked_crystals.clear()
	for i in Balance.PRISM_MAX_BANKS:
		p._banked_crystals[i] = true
	if p._try_bank(prism):
		return "a shot exceeded its crystal bank budget"
	return ""
