extends RefCounted
## Direct effect fixtures with independently queried arrival/recovery geometry,
## production colliders and damage; not ordinary input/campaign validation.
const Endpoints := preload("res://scripts/tests/dash_endpoint_live.gd")

class RecordingWolf extends Enemy:
	var receipts: Array[Dictionary] = []
	func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
		var before: float = hp
		var source: Player = hit_src
		super(amount, from_dir, is_crit, silent)
		receipts.append({"amount": amount, "hp_removed": before - hp, "crit": is_crit,
			"silent": silent, "local_source": is_instance_valid(source) and source == game.local_player})

class Harness extends Node:
	var r: Node
	var g: Game
	var p: Player
	var geometry: Node
	var actor: CharacterBody2D
	var obstacle: StaticBody2D
	var masked: Array[Dictionary] = []
	var error := ""
	var original_crit := 0.0
	var original_gust := Vector2.ZERO
	var ledger := {"cases": [], "ordinary_gameplay": false,
		"scope": "Posed local base Assassin, AI frozen, direct Death Mark execution with no execute rider. Wolf size pinned to 1 and Vargoth production geometry. HP raised to 10000 to prevent defeat/reward callbacks; crit and evasion zero. Original bodies temporarily unscanned. Real target damage dispatch and manual zero-input movement recovery."}

	func need(ok: bool, label: String) -> bool:
		r._check(ok, "deathmark / " + label)
		if not ok: error = label
		return ok

	func barrier() -> void:
		await get_tree().physics_frame
		await get_tree().physics_frame

	func execute(room: int) -> String:
		g = r.game
		p = g.player
		original_crit = p.crit
		original_gust = g.gust_vec
		r.report["deathmark"] = ledger
		r.report["limits"] = ledger.scope
		if not need(g.no_saves and not g.net_online() and not g.input_overlay_up() and not get_tree().paused,
				"offline unpaused no-save fixture"): return error
		r._prepare_class("assassin")
		p.crit = 0.0
		g.gust_vec = Vector2.ZERO
		geometry = Endpoints.Harness.new()
		geometry.p = p
		geometry.g = g
		geometry.r = r
		add_child(geometry)
		for node in g.world.find_children("*", "PhysicsBody2D", true, false):
			var body := node as PhysicsBody2D
			if body == p or (body.collision_layer & p.collision_mask) == 0: continue
			masked.append({"body": body, "layer": body.collision_layer})
			body.collision_layer &= ~p.collision_mask
		ledger["masked_existing_bodies"] = masked.size()
		ledger["character_before"] = [p.gold, p.xp, p.level]
		var center: Vector2 = g.play_rect(room).get_center()
		g.camera.global_position = center
		g.camera.zoom = Vector2.ONE
		g.camera.reset_smoothing()
		await r.sim_wait(3.0) # allow the room arrival title to finish before contact captures
		var expected: Array = []
		for i in r.DIRECTIONS.size():
			var direction: Vector2 = r.DIRECTIONS[i]
			var clear: Dictionary = await cast_case("open_%d" % i, "wolf", 4, center, direction, false, false)
			if error != "": return error
			var occupied: Dictionary = await cast_case("scenery_%d" % i, "wolf", 4, center, direction, true, false)
			if error != "": return error
			need(geometry.same_damage(clear.damage, occupied.damage), "scenery_%d preserves all three hit amounts and HP removal" % i)
			expected.append("deathmark / scenery_%d clear full-footprint landing" % i)
			expected.append("deathmark / scenery_%d no new recovery drift" % i)
		var control: Dictionary = await cast_case("boss_unscanned", "vargoth", 8, center, Vector2.RIGHT, false, false)
		if error != "": return error
		var boss: Dictionary = await cast_case("boss_scanned", "vargoth", 4, center, Vector2.RIGHT, false, false)
		if error != "": return error
		need(geometry.same_damage(control.damage, boss.damage), "boss collision control preserves all three hit amounts and HP removal")
		expected.append("deathmark / boss_scanned clear full-footprint landing")
		expected.append("deathmark / boss_scanned no new recovery drift")
		await cast_case("preexisting_overlap", "vargoth", 4, center, Vector2.ZERO, false, true)
		if error != "": return error
		ledger["character_after"] = [p.gold, p.xp, p.level]
		need(ledger.character_before == ledger.character_after, "no character rewards")
		# Baseline must expose this
		# exact set, never treat all known-defect assertions as arbitrary passes.
		var actual: Array = r.report.findings.duplicate()
		actual.sort()
		expected.sort()
		ledger["baseline_expected_findings"] = expected
		if r.flag("baseline"):
			need(actual == expected, "baseline has exactly the expected geometry/recovery findings")
		else:
			need(actual.is_empty(), "strict mode has no baseline findings")
		return error

	func cast_case(label: String, kind: String, layer: int, center: Vector2,
			direction: Vector2, scenery: bool, degenerate: bool) -> Dictionary:
		r.step("deathmark " + label)
		p.next_crit = false
		p.velocity = Vector2.ZERO
		p.locked_target = null
		p.soft_target = null
		p.global_position = center - direction * 120.0
		if kind == "vargoth":
			actor = Endpoints.RecordingBoss.new()
		else:
			actor = RecordingWolf.new()
		actor._setup(g, kind, center, -1, 1.0)
		actor.collision_layer = layer
		actor.eva = 0.0
		actor.max_hp = 10000.0
		actor.hp = actor.max_hp
		g.world.add_child(actor)
		actor.set_physics_process(false)
		p.locked_target = actor
		var start: Vector2 = p.global_position
		var nominal: Vector2 = g.clamp_to_zone(center + direction * 46.0, center)
		if scenery:
			obstacle = g._add_obstacle("boulder", nominal - Vector2(0, 10))
		await barrier()
		var initial: Array = geometry.hits(start, p.collision_mask)
		var nominal_hits: Array = geometry.hits(nominal, p.collision_mask)
		var expected_occupied: bool = scenery or (kind == "vargoth" and layer == 4)
		var record := {"label": label, "kind": kind, "layer": layer, "mask": p.collision_mask,
			"start": geometry.v(start), "nominal": geometry.v(nominal), "initial_hits": initial,
			"nominal_hits": nominal_hits, "actor_radius": 0.0, "shape_owners": p.get_shape_owners().size()}
		for node in actor.get_children():
			if node is CollisionShape2D and not node.disabled and node.shape is CircleShape2D:
				record.actor_radius = node.shape.radius
		ledger.cases.append(record)
		if not need(p.collision_mask == (1 | 4) and p.get_shape_owners().size() > 0,
				label + " actual player collider and full collision mask"): return record
		var server: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(p.get_rid())
		if not need(server != null and server.transform.origin.distance_to(start) < 0.01,
				label + " fixed pose barrier aligns server and node origin"): return record
		if not need(nominal.distance_to(center + direction * 46.0) < 0.001,
				label + " unclipped fixture nominal endpoint"): return record
		if not need(initial.has(actor.get_instance_id()) if degenerate else initial.is_empty(),
				label + " declared initial geometry"): return record
		if not need((not nominal_hits.is_empty()) == expected_occupied, label + " declared nominal geometry"): return record
		if scenery and not need(nominal_hits.has(obstacle.get_instance_id()), label + " factory scenery occupies nominal footprint"): return record
		if kind == "vargoth" and not need(is_equal_approx(float(record.actor_radius), 54.6), label + " production large boss radius"): return record
		if not need(geometry.hits(start, p.collision_mask | p.collision_layer, false).has(p.get_instance_id())
				and not initial.has(p.get_instance_id()), label + " query self-RID positive and negative control"): return record
		var faults_before: int = p.motion_faults
		await p._death_mark_execution(actor, 0.0)
		var landing: Vector2 = p.global_position
		var hits: Array = geometry.hits(landing, p.collision_mask)
		record["landing"] = geometry.v(landing)
		record["landing_hits"] = hits
		record["damage"] = actor.receipts.duplicate(true)
		need(landing.is_finite() and not actor.dying, label + " finite result and living target")
		if not degenerate:
			need(record.damage.size() == 3, label + " two crossing hits and final stab land")
			for receipt in record.damage:
				need(bool(receipt.local_source) and float(receipt.hp_removed) > 0.0, label + " real player-sourced HP removal")
		if degenerate:
			need(landing == start, label + " preexisting overlap is finite and unchanged; no clearance promise")
		else:
			r._check(hits.is_empty(), "deathmark / " + label + " clear full-footprint landing", expected_occupied)
			if not expected_occupied: need(landing == nominal, label + " open endpoint remains exact")
			if label in ["open_0", "scenery_0", "boss_scanned"]:
				await r._capture("deathmark_" + label, "Direct effect fixture; hero physics held at initial arrival before recovery. " + label)
				await r.sim_wait(0.6)
				await r._capture("deathmark_" + label + "_settled", "Direct effect fixture; hero physics still held, contact FX allowed to fade before recovery. " + label)
			var max_drift := 0.0
			for _tick in 12:
				await get_tree().physics_frame
				p.velocity = Vector2.ZERO
				p._move_body()
				max_drift = maxf(max_drift, landing.distance_to(p.global_position))
			record["recovery_drift"] = max_drift
			r._check(max_drift < 0.1, "deathmark / " + label + " no new recovery drift", expected_occupied)
		need(p.motion_faults == faults_before, label + " no numeric motion recovery")
		actor.queue_free()
		actor = null
		if is_instance_valid(obstacle): obstacle.queue_free()
		obstacle = null
		await barrier()
		return record

	func cleanup() -> void:
		r._release()
		if is_instance_valid(actor): actor.queue_free()
		if is_instance_valid(obstacle): obstacle.queue_free()
		for row in masked:
			if is_instance_valid(row.body): row.body.collision_layer = int(row.layer)
		p.crit = original_crit
		g.gust_vec = original_gust
		p.locked_target = null
		p.soft_target = null
		ledger["cleanup"] = "Original collider layers, crit and gust restored; fixture actors/prop released. ShotRig exits without saves."

static func run(rig: Node, room: int) -> String:
	var harness := Harness.new()
	harness.r = rig
	rig.add_child(harness)
	var error: String = await harness.execute(room)
	harness.cleanup()
	harness.queue_free()
	await rig.frames(2)
	return error
