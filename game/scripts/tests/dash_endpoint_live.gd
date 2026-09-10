extends RefCounted
## Optional native full-mask geometry/damage contract. Posed actors and declared
## deterministic combat controls; real local Player input, no direct damage calls.

class RecordingBoss extends Boss:
	var receipts: Array[Dictionary] = []
	func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
		var before: float = hp
		var source: Player = hit_src
		super(amount, from_dir, is_crit, silent)
		receipts.append({"amount": amount, "hp_removed": before - hp, "crit": is_crit,
			"silent": silent, "from_dir": [from_dir.x, from_dir.y],
			"local_source": is_instance_valid(source) and source == game.local_player})

class Harness extends Node:
	var r: Node
	var g: Game
	var p: Player
	var actor: RecordingBoss
	var pending := ""
	var sample: Dictionary = {}
	var active: Dictionary = {}
	var error := ""
	var saved_masks: Array[Dictionary] = []
	var camera_before: Dictionary = {}
	var original_crit := 0.0
	var original_gust := Vector2.ZERO
	var terms_saved := false
	var ledger := {"ordinary_combat": false, "cases": [], "pairs": [],
		"setup": "Same real local Player and native keys. Recording Boss subclass uses production _setup for Vargoth body/art/stats; AI disabled. Existing world bodies temporarily unscanned. Base L1 classes, no themes; crit0 and actor evasion0 prevent random comparison differences. No direct damage, kill, loot, XP, currency or RNG-seed calls."}

	func _ready() -> void:
		process_physics_priority = 1001 # after the real Player and parent rig

	func v(point: Vector2) -> Array:
		return [point.x, point.y]

	func vec(value: Array) -> Vector2:
		return Vector2(float(value[0]), float(value[1]))

	func hits(point: Vector2, mask: int, exclude_self := true) -> Array:
		var result: Array = []
		for owner in p.get_shape_owners():
			if p.is_shape_owner_disabled(owner):
				continue
			for index in p.shape_owner_get_shape_count(owner):
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = p.shape_owner_get_shape(owner, index)
				var transform: Transform2D = p.global_transform * p.shape_owner_get_transform(owner)
				transform.origin += point - p.global_position
				query.transform = transform
				query.collision_mask = mask
				query.collide_with_areas = false
				query.collide_with_bodies = true
				query.margin = 0.0 # observe actual penetration independently of resolver margin
				if exclude_self:
					query.exclude = [p.get_rid()]
				for hit in p.get_world_2d().direct_space_state.intersect_shape(query, 32):
					var body: Node = hit.collider
					var id: int = body.get_instance_id()
					if not result.has(id):
						result.append(id)
		return result

	func _physics_process(delta: float) -> void:
		if pending == "" or not sample.is_empty():
			return
		# A posed existing kinematic body queues its server transform until
		# integration. Wait a fixed physics barrier, never retry until a query passes.
		if pending == "setup" and Engine.get_physics_frames() < int(active.setup_not_before_frame):
			return
		if pending == "cast" and float(p.cds[String(active.slot)]) <= 0.0:
			return
		var point: Vector2 = p.global_position
		sample = {"in_physics": Engine.is_in_physics_frame(), "frame": Engine.get_physics_frames(),
			"physics_delta": delta, "position": v(point), "hits": hits(point, p.collision_mask),
			"mp": p.mp, "motion_faults": p.motion_faults, "actor_position": v(actor.global_position)}
		if pending == "setup":
			var player_state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(p.get_rid())
			sample["server_player_position"] = v(player_state.transform.origin) if player_state != null else []
			sample["nominal_hits"] = hits(vec(active.posed_nominal), p.collision_mask)
			sample["self_included"] = hits(point, p.collision_mask | p.collision_layer, false)
			sample["self_excluded"] = hits(point, p.collision_mask | p.collision_layer, true)
		else:
			# get_position_delta recomputes from the post-dash origin. The stored
			# last motion survives instant relocation; require a single clear slide below.
			var walk: Vector2 = p.get_last_motion()
			sample["position_delta_after_teleport"] = v(p.get_position_delta())
			sample["cached_real_velocity"] = v(p.get_real_velocity())
			sample["slide_collision_count"] = p.get_slide_collision_count()
			var dash_start: Vector2 = vec(active.start) + walk
			var nominal: Vector2 = g.clamp_to_zone(dash_start + Vector2.RIGHT * float(active.distance), dash_start)
			sample["last_slide_delta"] = v(walk)
			sample["reconstructed_dash_start"] = v(dash_start)
			sample["reconstructed_nominal"] = v(nominal)
			sample["nominal_lane"] = actor.global_position.distance_to(Geometry2D.get_closest_point_to_segment(actor.global_position, dash_start, nominal))
			sample["cooldown"] = p.cds[String(active.slot)]
			sample["damage"] = actor.receipts.duplicate(true)
			sample["actor_hp"] = actor.hp
			p.set_physics_process(false)
			r._release()
		pending = ""

	func need(ok: bool, label: String) -> bool:
		r._check(ok, "endpoint contracts / " + label)
		if not ok:
			error = "endpoint contracts setup: " + label
			pending = ""
			r._release()
			p.set_physics_process(false)
		return ok

	func wait_sample(mode: String) -> Dictionary:
		sample = {}
		pending = mode
		var deadline: int = Time.get_ticks_msec() + 4000
		while sample.is_empty() and Time.get_ticks_msec() < deadline:
			await r.frames(1)
		pending = ""
		return sample.duplicate(true)

	func execute(room: int) -> String:
		g = r.game
		p = g.player
		r.report["endpoint_contracts"] = ledger
		r.report["limits"] = "Base interaction/terrain phase: " + String(r.report.limits) \
			+ " Optional endpoint_contracts uses actual native damage against posed AI-disabled Boss bodies, with declared deterministic controls; it is not ordinary campaign combat."
		original_crit = p.crit
		original_gust = g.gust_vec
		camera_before = {"position": g.camera.position, "offset": g.camera.offset, "zoom": g.camera.zoom}
		terms_saved = true
		if not need(g.no_saves and not g.net_online() and not g.input_overlay_up() and not get_tree().paused,
				"offline no-save unobstructed fixture"):
			return error
		ledger["character_before"] = [p.gold, p.xp, p.level]
		for node in g.world.find_children("*", "PhysicsBody2D", true, false):
			var body := node as PhysicsBody2D
			if body == p or (body.collision_layer & p.collision_mask) == 0:
				continue
			saved_masks.append({"body": body, "layer": body.collision_layer})
			body.collision_layer = body.collision_layer & ~p.collision_mask
		ledger["masked_existing_body_count"] = saved_masks.size()
		var center: Vector2 = g.play_rect(room).get_center()
		# Boss-immune CC has its own actual damage call BEFORE each primary:
		# Bash stun -> concussion + hit; Shadow Dash stagger -> concussion +
		# blade, then rider stagger -> concussion + rider. Blink has no CC.
		var selected := [["warrior", "a2", 170.0, 2], ["assassin", "a2", 210.0, 4], ["mage", "a3", 190.0, 1]]
		if r.flag("tumble"):
			selected.append(["archer", "a3", 130.0, 0]) # base Tumble has no damage or arrows
		for spec in selected:
			var first: Dictionary = await cast_case(String(spec[0]), String(spec[1]), float(spec[2]), int(spec[3]), 8, center, false)
			if error != "": return error
			var second: Dictionary = await cast_case(String(spec[0]), String(spec[1]), float(spec[2]), int(spec[3]), 4, center, false)
			if error != "": return error
			var same: bool = same_damage(first.landing.damage, second.landing.damage)
			if int(spec[3]) == 0:
				same = first.landing.damage.is_empty() and second.landing.damage.is_empty()
			var same_cost: bool = absf(float(first.landing.mp) - float(second.landing.mp)) < 0.001 \
				and absf(float(first.landing.cooldown) - float(second.landing.cooldown)) < 0.001
			ledger.pairs.append({"class": spec[0], "unscanned": first.label, "scanned": second.label,
				"same_actual_damage_dispatch": same, "same_mp_and_cooldown": same_cost})
			r._check(same, "endpoint contracts / " + String(spec[0]) + " preserves exact intended damage dispatch across collision-mask control")
			r._check(same_cost, "endpoint contracts / " + String(spec[0]) + " preserves exact paired mana and cooldown ownership")
		await cast_case("mage", "a3", 190.0, 1, 4, center, true)
		ledger["character_after"] = [p.gold, p.xp, p.level]
		r._check(ledger.character_after == ledger.character_before, "endpoint contracts / no character XP, level or currency reward")
		ledger["complete"] = error == ""
		return error

	func cast_case(cls: String, slot: String, distance: float, count: int,
			layer: int, center: Vector2, beyond: bool) -> Dictionary:
		r._prepare_class(cls)
		p.crit = 0.0 # declared deterministic comparison, not a production rule
		p.next_crit = false
		p.velocity = Vector2.ZERO
		p.frozen_time = 0.0
		p.rooted_time = 0.0
		p.dead = false
		p.downed = false
		p.ghost = false
		p.hp = p.max_hp
		p.mp = p.max_mp
		p.cds[slot] = 0.0
		g.gust_vec = Vector2.ZERO
		var start: Vector2 = center - Vector2.RIGHT * (distance * 0.5 if beyond else distance)
		p.global_position = start
		actor = RecordingBoss.new()
		actor._setup(g, "vargoth", center)
		actor.collision_layer = layer
		actor.eva = 0.0
		g.world.add_child(actor)
		actor.set_physics_process(false)
		var radius := 0.0
		for node in actor.get_children():
			if node is CollisionShape2D and node.shape is CircleShape2D and not node.disabled:
				radius = node.shape.radius
		var hero_circle: CircleShape2D = r._shape() as CircleShape2D
		var hero_radius: float = hero_circle.radius if hero_circle != null else 0.0
		var label: String = cls + ("_beyond_actor" if beyond else "_actor_layer" + str(layer))
		r.step("endpoint contracts " + label)
		active = {"label": label, "class": cls, "slot": slot, "distance": distance, "direction": v(Vector2.RIGHT),
			"ability_name": String(Classes.ability(cls, slot)["name"]),
			"start": v(start), "posed_nominal": v(g.clamp_to_zone(start + Vector2.RIGHT * distance, start)),
			"actor_id": actor.get_instance_id(), "actor_kind": actor.kind, "actor_layer": layer,
			"actor_radius": radius, "player_radius": hero_radius, "player_mask": p.collision_mask, "player_layer": p.collision_layer,
			"start_mp": p.mp, "cost": p.ability_cost(slot), "expected_damage_calls": count,
			"actor_hp_before": actor.hp, "crit_override": p.crit, "evasion_override": actor.eva,
			"equipment": p.equipment.duplicate(true), "tree_points": p.tree_points.duplicate(true),
			"base_atk": p.current_atk(), "ability_coeff": p.ability_coeff(slot),
			"movement_terms": {"speed": p.speed, "berserk": p.berserk_time, "theme_speed": p.theme_speed_time,
				"damp": p.damp_time, "hazard_speed": p.hazard_speed, "chill": p.chill_time,
				"laced_move": p.laced_move_time, "dev_morph": p.dev_morph != null, "gust": v(g.gust_vec)},
			"clear_endpoint_beyond_actor": beyond}
		active["pose_frame"] = Engine.get_physics_frames()
		active["setup_not_before_frame"] = int(active.pose_frame) + 2
		ledger.cases.append(active)
		await r.frames(2)
		active["setup"] = await wait_sample("setup")
		if not need(not active.setup.is_empty() and bool(active.setup.in_physics), label + " actual physics setup observation"): return active
		if not need(int(active.setup.frame) >= int(active.setup_not_before_frame)
				and active.setup.server_player_position.size() == 2
				and vec(active.setup.server_player_position).distance_to(start) < 0.01,
				label + " fixed physics pose barrier aligns server and node origin"): return active
		if not need(not g.input_overlay_up() and not get_tree().paused and active.setup.hits.is_empty(), label + " clear playable start"): return active
		if not need(is_equal_approx(radius, 54.6) and is_equal_approx(hero_radius, 13.0) and p.collision_mask == (1 | 4), label + " authored large body and actual local mask"): return active
		var expected_occupied: bool = layer == 4 and not beyond
		if not need(active.setup.nominal_hits.has(actor.get_instance_id()) == expected_occupied, label + " endpoint mask control"): return active
		if not need(active.setup.self_included.has(p.get_instance_id()) and not active.setup.self_excluded.has(p.get_instance_id()), label + " actual self-RID positive and negative query control"): return active
		if not need(p.berserk_time <= 0.0 and p.theme_speed_time <= 0.0 and p.hazard_speed <= 1.0 and p.dev_morph == null,
				label + " no movement accelerator exceeds recorded base-speed reconstruction bound"): return active
		r._move(Vector2.RIGHT)
		p._poll_local_intents()
		if not need(p.intent_move == Vector2.RIGHT, label + " real held move key"): return active
		active["armed_frame"] = Engine.get_physics_frames()
		r._key(int(g.binds[slot]), true)
		p.set_physics_process(true)
		active["landing"] = await wait_sample("cast")
		r._release()
		p.set_physics_process(false)
		if not need(not active.landing.is_empty(), label + " real ability fired"): return active
		var landing: Dictionary = active.landing
		if not need(int(landing.frame) == int(active.armed_frame) + 1 and bool(landing.in_physics), label + " first enabled Player physics tick observed"): return active
		if not need(int(landing.slide_collision_count) == 0 and vec(landing.last_slide_delta).distance_to(
				vec(landing.cached_real_velocity) * float(landing.physics_delta)) < 0.01,
				label + " cached single clear walking motion agrees with stored total velocity"): return active
		if not need(vec(landing.last_slide_delta).length() <= p.speed * float(landing.physics_delta) + 0.1,
				label + " one ordinary pre-cast walking step supports corridor reconstruction"): return active
		if not need(vec(landing.actor_position).distance_to(center) < 0.01, label + " frozen actor stayed at its endpoint"): return active
		r._check(landing.hits.is_empty(), "endpoint contracts / " + label + " first landing outside full-mask bodies", cls == "archer" and expected_occupied)
		r._check(float(landing.nominal_lane) <= 55.0, "endpoint contracts / " + label + " actor remains inside intended base hit corridor")
		r._check(absf(float(active.start_mp) - float(landing.mp) - float(active.cost)) < 0.5 and float(landing.cooldown) > 0.0,
			"endpoint contracts / " + label + " ordinary mana/cooldown ownership")
		r._check(landing.damage.size() == count, "endpoint contracts / " + label + " exact intended damage call count")
		var actual: float = 0.0
		for receipt in landing.damage:
			actual += float(receipt.hp_removed)
			r._check(bool(receipt.local_source) and not bool(receipt.crit) and not bool(receipt.silent) and float(receipt.hp_removed) > 0.0,
				"endpoint contracts / " + label + " actual local Player damage reached Boss super")
		var intended_amount: bool = is_zero_approx(actual) if count == 0 else actual > 0.0
		r._check(intended_amount and absf(float(active.actor_hp_before) - float(landing.actor_hp) - actual) < 0.001 and not actor.dying,
			"endpoint contracts / " + label + " exact HP debit without a kill")
		var nominal: Vector2 = vec(landing.reconstructed_nominal)
		var dash_start: Vector2 = vec(landing.reconstructed_dash_start)
		r._check(p.global_position.x > dash_start.x and p.global_position.x <= nominal.x + 0.01
			and absf(p.global_position.y - dash_start.y) < 0.01,
			"endpoint contracts / " + label + " advances along the intended segment without sidestep")
		if layer == 8 or beyond:
			r._check(p.global_position.distance_to(nominal) < 0.25, "endpoint contracts / " + label + " preserves exact open endpoint traversal")
		else:
			# Independent axial circle contact bound: no lost dash or excessive
			# shortening can pass just because the starting point was clear.
			var contact_distance: float = radius + hero_radius
			var actual_gap: float = center.x - p.global_position.x
			r._check(actual_gap >= contact_distance - 0.01
				and actual_gap <= contact_distance + 1.0 + p.safe_margin + 0.01,
				"endpoint contracts / " + label + " stops within one sampling step of first circle contact", cls == "archer")
			r._check(p.global_position.distance_to(center) > 55.0, "endpoint contracts / " + label + " feet remain outside actor center corridor", cls == "archer")
		g.camera.global_position = center
		g.camera.force_update_scroll()
		await r._capture("endpoint_" + label, "Posed Vargoth body/AI off; actual native ability and recorded damage; not campaign combat")
		actor.queue_free()
		actor = null
		await r.frames(2)
		return active

	func same_damage(a: Array, b: Array) -> bool:
		if a.size() != b.size() or a.is_empty(): return false
		for index in a.size():
			if absf(float(a[index].amount) - float(b[index].amount)) > 0.001 \
					or absf(float(a[index].hp_removed) - float(b[index].hp_removed)) > 0.001:
				return false
		return true

	func cleanup() -> void:
		pending = ""
		r._release()
		if is_instance_valid(p):
			p.set_physics_process(false)
			if terms_saved: p.crit = original_crit
		if terms_saved: g.gust_vec = original_gust
		if is_instance_valid(actor): actor.queue_free()
		for item in saved_masks:
			if is_instance_valid(item.body): item.body.collision_layer = int(item.layer)
		if not camera_before.is_empty():
			g.camera.position = camera_before.position
			g.camera.offset = camera_before.offset
			g.camera.zoom = camera_before.zoom
			g.camera.force_update_scroll()
		ledger["cleanup"] = "held input released; original body masks/camera/crit/gust restored; posed target queued for deletion"


static func run(r: Node, room: int) -> String:
	var harness := Harness.new()
	harness.r = r
	r.add_child(harness)
	var error: String = await harness.execute(room)
	harness.cleanup()
	harness.queue_free()
	await r.frames(2)
	return error
