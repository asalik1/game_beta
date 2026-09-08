extends RefCounted
## Starting-kit play with real keyboard movement, abilities and Interact.
const Caravan := preload("res://scripts/road_caravan.gd")


static func run(r: Node, cart: Node2D) -> String:
	var g: Game = r.game
	var p: Player = g.player
	p.set_physics_process(true)
	g.settings["combat_framing"] = true
	var begun := Time.get_ticks_msec()
	var hp_start := p.hp
	var hp_min := p.hp
	var load_min: float = cart.integrity
	var traveled := 0.0
	var previous := p.global_position
	var sample_at := 0.0
	var samples: Array[Dictionary] = []
	var shown := {}
	while is_instance_valid(cart) and cart.phase < Caravan.COMPLETE and not p.dead \
		and Time.get_ticks_msec() - begun < 110000:
		var elapsed := (Time.get_ticks_msec() - begun) / 1000.0
		var enemy: Enemy
		var near := INF
		for actor in cart.enemies:
			if is_instance_valid(actor) and not actor.dying and not actor.is_queued_for_deletion():
				var distance := p.global_position.distance_to(actor.global_position)
				if distance < near:
					near = distance
					enemy = actor
		var walk := Vector2.ZERO
		if enemy != null:
			var toward := (enemy.global_position - p.global_position).normalized()
			var melee: bool = p.cls in ["warrior", "paladin", "assassin"]
			var preferred := 55.0 if melee else 230.0
			walk = toward if near > preferred + 15.0 else -toward if near < preferred - 20.0 else Vector2.ZERO
			if enemy.pounce_windup > 0.0 or enemy.pounce_time > 0.0:
				walk = Vector2(-toward.y, toward.x)
		else:
			var to_handle: Vector2 = cart.handle.global_position - p.global_position
			if to_handle.length() > Balance.CARAVAN_INTERACT_RANGE * 0.5:
				walk = to_handle.normalized()
		var bounds := g.play_rect(cart.zone).grow(-80.0)
		if not bounds.has_point(p.global_position + walk * 90.0):
			walk = (g.room_center(cart.zone) - p.global_position).normalized()
		r._press(KEY_A, walk.x < -0.3)
		r._press(KEY_D, walk.x > 0.3)
		r._press(KEY_W, walk.y < -0.3)
		r._press(KEY_S, walk.y > 0.3)
		r._press(int(g.binds.a1), enemy != null)
		r._press(int(g.binds.a2), enemy != null and near < 190.0)
		r._press(int(g.binds.a3), enemy != null and near < 180.0)
		r._press(int(g.binds.ult), enemy != null and elapsed > 10.0 and near < 220.0)
		r._press(int(g.binds.potion), p.hp < p.max_hp * 0.4)
		r._press(int(g.binds.interact), enemy == null and cart.phase == Caravan.WORKING \
			and p.global_position.distance_to(cart.handle.global_position) < Balance.CARAVAN_INTERACT_RANGE)
		if elapsed >= sample_at:
			sample_at += 1.0
			samples.append({"seconds": elapsed, "hp": p.hp, "load": cart.integrity,
				"wave": cart.wave, "tugs": cart.tugs, "foes": cart.pending_deaths.size(),
				"hero": str(p.global_position), "distance": near if enemy != null else 0.0})
		var tag := ""
		if p.hp < hp_start and not shown.has("first_hit"):
			tag = "first_hit"
		elif cart.wave == 2 and cart.phase == Caravan.PREPARING and not shown.has("second_warning"):
			tag = "second_warning"
		elif cart.tugs > 0 and not shown.has("pulling_the_wheel"):
			tag = "pulling_the_wheel"
		elif elapsed > 6.0 and enemy != null and not shown.has("ordinary_combat"):
			tag = "ordinary_combat"
		if tag != "":
			shown[tag] = true
			await r._capture("combat_" + tag)
			var fit := preload("res://scripts/tests/encounter_company_live.gd")._fit(g, cart.status)
			if fit != "":
				r._release()
				return fit
		await r.get_tree().create_timer(0.05, true).timeout
		hp_min = minf(hp_min, p.hp)
		if is_instance_valid(cart):
			load_min = minf(load_min, cart.integrity)
		traveled += p.global_position.distance_to(previous)
		previous = p.global_position
	r._release()
	var won: bool = Caravan.supplied(g)
	var report := {"class": p.cls, "hero_level": p.level, "god_mode": g.dev_god, "won": won,
		"hp_start": hp_start, "hp_min": hp_min, "hp_end": p.hp, "dead": p.dead,
		"load_min": load_min, "distance_walked": traveled, "seconds": (Time.get_ticks_msec() - begun) / 1000.0}
	await r._capture("combat_outcome")
	var file := FileAccess.open(r.shot_dir.path_join("combat.json"), FileAccess.WRITE)
	if file != null:
		var detailed := report.duplicate(true)
		detailed["samples"] = samples
		file.store_string(JSON.stringify(detailed, "\t"))
		file.close()
	print("CARAVAN COMBAT: ", JSON.stringify(report))
	if not won:
		return "ordinary caravan combat did not win; inspect the report before tuning"
	if g.dev_god or hp_start > 1000.0 or traveled < 100.0:
		return "caravan combat used a debug advantage or never walked"
	print("ok: caravan won with starting equipment, normal health, camera framing and keyboard combat/pulling; no injected combat damage")
	return ""
