extends "res://scripts/tests/guest_blink_enet_live.gd"
## Optional Death Mark episode. Inherits paired boot, ENet admission, production
## actor/mirror setup, geometry queries, capture controls and cleanup unchanged.
var watch_mark := false
var cast_edge: Dictionary = {}
var fixture_props: Array[StaticBody2D] = []
var first_damage: Array = []


func run() -> int:
	shot_dir = shot_dir.path_join("deathmark")
	return await super.run()


func _reader(cls: String, label: String) -> void:
	await super._reader("assassin" if label == "Guest" else cls, label)


func _episode() -> String:
	report["mode"] = "deathmark"
	report["fixture"] = "Two inherited ch1 readers, manually admitted/ready over real ENet; actual join-ready, enemy spawn/status/hit/state and movement RPCs. Base Assassin native ult input, full 1|4 body mask. Stationary ordinary level-8 wolf observer; existing tree-wide enemies excluded from strike scans. Guest physics held immediately after native cast edge while delayed execution continues; no moving-combat claim. Host local input/physics disabled. Target health/status, guest mana/cooldown reset between two cases. Factory boulder placed identically in both worlds for occupied endpoint; this is posed matching geometry, not scenery/world-snapshot replication proof. No latency/loss, rewards, persistence, balance or physical-device claim."
	for reader in readers:
		reader.settings["hit_stop"] = false
	return await super._episode()


func _case(occupied: bool) -> String:
	var g: Game = readers[1]
	var p: Player = g.player
	var label := "deathmark_occupied_prop" if occupied else "deathmark_clear"
	step(label)
	_release()
	p.set_physics_process(false)
	p.clear_local_intents()
	p.global_position = actor_point - Vector2(120, 0)
	p.velocity = Vector2.ZERO
	p.facing = Vector2.RIGHT
	p.locked_target = mirror
	p.soft_target = mirror
	p.mp = p.max_mp
	p.cds.ult = 0.0
	actor.hp = actor.max_hp
	actor.vuln_time = 0.0
	mirror.vuln_time = 0.0
	var start: Vector2 = p.global_position
	var intended: Vector2 = g.clamp_to_zone(actor_point + Vector2.RIGHT * Balance.DEATH_MARK_FAR_SIDE_OFFSET, actor_point)
	if occupied:
		for reader in readers:
			fixture_props.append(reader._add_obstacle("boulder", intended - Vector2(0, 10)))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not await _until(func() -> bool: return absf(mirror.hp / mirror.max_hp - 1.0) < 0.00001, 3.0):
		return label + ": reset target HP did not replicate"
	var before: Dictionary = await _probe(func() -> Dictionary: return {
		"start_hits": _overlaps(p, start), "endpoint_hits": _overlaps(p, intended),
		"start": _v(start), "intended": _v(intended)})
	if before.is_empty(): return label + ": bounded setup query timed out"
	var host_before: Dictionary = _hero_state(readers[0].player)
	var economy_before := [_economy(readers[0]), _economy(g)]
	var raw_expected := [p.current_atk() * 0.7 + p.ability_base_flat("ult"),
		p.current_atk() * 0.7 + p.ability_base_flat("ult"),
		p.current_atk() * p.ability_coeff("ult") + p.ability_base_flat("ult")]
	var amplification: float = 1.0 + p.rider("ult", "amp")
	before.merge({"label": label, "occupied": occupied, "hp": actor.hp,
		"mana": p.mp, "cost": p.ability_cost("ult"), "normal_cd": p.ability_cd("ult"),
		"expected_raw_hit_order": raw_expected, "expected_vulnerability": amplification,
		"class": p.cls, "skin": p.skin, "themes": p.ability_theme.duplicate(true),
		"mask": p.collision_mask, "mirror_layer": mirror.collision_layer,
		"host_observer": host_before, "keycode": int(g.binds.ult)}, true)
	var row := {"before": before}
	report.cases.append(row)
	if not before.start_hits.is_empty(): return label + ": starting footprint not clear"
	if intended.distance_to(actor_point + Vector2.RIGHT * Balance.DEATH_MARK_FAR_SIDE_OFFSET) > 0.01:
		return label + ": room clamp changed the fixture nominal endpoint"
	if before.endpoint_hits.size() != (1 if occupied else 0): return label + ": nominal occupancy control failed"
	if occupied and not _contains(before.endpoint_hits, fixture_props[1]): return label + ": guest factory prop is not the endpoint blocker"
	if g.input_overlay_up() or get_tree().paused or p.dead or p.downed or p.ghost or p.frozen_time > 0 or p.rooted_time > 0:
		return label + ": input gates not clear"
	if p.cls != "assassin" or p.skin != "" or p.combo != 0.0 or p.s_passive() != "" \
			or p.mp < p.ability_cost("ult") or not p._theme_fx("ult").is_empty():
		return label + ": fresh unthemed base Assassin fixture changed"
	if actor.hp <= (float(raw_expected[0]) + float(raw_expected[1]) + float(raw_expected[2])) * amplification:
		return label + ": ordinary target cannot survive the three expected hits"
	actor.received.clear()
	wires[0].last_hit = {}
	cast_edge = {}
	await _capture(label + "_before")
	if not report.failures.is_empty(): return label + ": initial native framing controls failed"
	watch_mark = true
	_press(int(g.binds.ult))
	p.set_physics_process(true)
	if not await _until(func() -> bool: return not cast_edge.is_empty(), 2.0):
		return label + ": native ult did not fire"
	row["cast_edge"] = cast_edge.duplicate(true)
	_check(bool(cast_edge.raw_key_down) and bool(cast_edge.intent_ult) and cast_edge.intent_move == [0.0, 0.0], label + ": native held ult and actual zero-movement intent")
	_check(absf(float(before.mana) - float(cast_edge.mp) - float(before.cost)) < 0.01 \
		and absf(float(cast_edge.cd) - float(before.normal_cd)) < 0.01, label + ": one ordinary mana debit/cooldown edge")
	_check(Vector2(float(cast_edge.position[0]), float(cast_edge.position[1])).distance_to(start) < 0.01,
		label + ": cast edge precedes the delayed final teleport")
	if not await _until(func() -> bool: return actor.received.size() >= 3 and p.global_position.distance_to(start) > 0.1, 4.0):
		return label + ": delayed teleport or three host hits did not complete"
	var sample: Dictionary = await _probe(func() -> Dictionary: return {
		"position": _v(p.global_position), "hits": _overlaps(p, p.global_position),
		"motion_faults": p.motion_faults, "mp": p.mp, "physics_held": not p.is_physics_processing()})
	if sample.is_empty(): return label + ": bounded landing query timed out"
	row["landing"] = sample
	var end: Vector2 = p.global_position
	_check(sample.hits.is_empty() and p.collision_mask == 5 and bool(sample.physics_held), label + ": full-footprint landing clear before recovery")
	_check(end.is_finite() and p.velocity == Vector2.ZERO and p.motion_faults == int(report.motion_faults_before), label + ": finite landing without motion recovery")
	if occupied:
		_check(end.x > start.x and end.x < intended.x and absf(end.y - intended.y) < 0.01, label + ": occupied endpoint retreats on the approach segment")
	else:
		_check(end.distance_to(intended) < 0.01, label + ": clear far-side endpoint remains exact")
	return await _finish_case(row, label, end, raw_expected, amplification, host_before, economy_before)


func _finish_case(row: Dictionary, label: String, end: Vector2, raw_expected: Array,
		amplification: float, host_before: Dictionary, economy_before: Array) -> String:
	var g: Game = readers[1]
	var p: Player = g.player
	await _settle(0.6)
	var remote: Player = _shell(0, guest_id)
	var converged := await _until(func() -> bool:
		return remote.global_position.distance_to(end) < 0.5 and not remote.net_snaps.is_empty() \
			and Vector2(remote.net_snaps.back().pos).distance_to(end) < 0.01 \
			and absf(mirror.hp / mirror.max_hp - actor.hp / actor.max_hp) <= 1.0 / 255.0 + 0.0001, 4.0)
	var hits: Array = actor.received.duplicate(true)
	row["convergence"] = {"converged": converged, "host_hits": hits, "last_hit": wires[0].last_hit.duplicate(true),
		"host_hp": actor.hp, "mirror_hp": mirror.hp, "remote_position": _v(remote.global_position),
		"remote_snapshots": remote.net_snaps.duplicate(true), "owner_position": _v(end),
		"host_vulnerability": actor.vuln_mult, "host_vulnerability_time": actor.vuln_time}
	_check(converged, label + ": normal movement snapshots and enemy HP converge")
	var wire_fraction := float(int(clampf(actor.hp / actor.max_hp, 0.0, 1.0) * 255.0)) / 255.0
	_check(absf(mirror.hp / mirror.max_hp - wire_fraction) < 0.00001, label + ": exact host HP fraction quantization")
	_check(hits.size() == 3, label + ": exactly two crossing hits and one final stab applied on host")
	var applied := 0.0
	for i in hits.size():
		var hit: Dictionary = hits[i]
		applied += float(hit.applied)
		_check(int(hit.sender) == guest_id and int(hit.source) == guest_id and not bool(hit.silent), label + ": hit %d belongs to guest sender and shell" % i)
		if i < raw_expected.size():
			_check(absf(float(hit.raw) - float(raw_expected[i])) < 0.01, label + ": ordered hit %d has its intended coefficient" % i)
		_check(float(hit.applied) > 0.0 and absf(float(hit.applied) - float(hit.raw) * amplification) < 0.01,
			label + ": host applies vulnerability once to hit %d" % i)
	_check(absf(float(row.before.hp) - actor.hp - applied) < 0.01, label + ": exact total host HP debit")
	_check(actor.vuln_time > 0.0 and is_equal_approx(actor.vuln_mult, amplification), label + ": real status RPC established authoritative mark")
	if hits.size() == 3:
		_check(int(wires[0].last_hit.get("id", 0)) == actor.net_id and int(wires[0].last_hit.get("peer", 0)) == guest_id
			and absf(float(wires[0].last_hit.get("amount", -1)) - float(hits[2].raw)) < 0.01,
			label + ": production hit ledger records final guest stab")
	if first_damage.is_empty():
		first_damage = hits.duplicate(true)
	else:
		var same: bool = hits.size() == first_damage.size() and hits.size() == 3
		for i in mini(hits.size(), first_damage.size()):
			same = same and absf(float(hits[i].raw) - float(first_damage[i].raw)) < 0.01 \
				and absf(float(hits[i].applied) - float(first_damage[i].applied)) < 0.01
		_check(same, "deathmark paired clear/occupied cases preserve all three ordered raw and applied hits")
		row["paired_damage_unchanged"] = same
	_check(_hero_state(readers[0].player) == host_before, label + ": host hero state unchanged")
	_check([_economy(readers[0]), _economy(g)] == economy_before and actor.hp > 0.0 and not actor.dying and not mirror.dying,
		label + ": no death, reward or economy change")
	_check(actor.global_position.distance_to(actor_point) < 0.01 and mirror.global_position.distance_to(actor_point) < 0.01,
		label + ": actor and mirror retain their declared stationary pose")
	_check(p.global_position == end and absf(p.mp - float(cast_edge.mp)) < 0.01 and not Input.is_key_pressed(int(g.binds.ult)),
		label + ": owner held at landing with input released")
	await _capture(label + "_converged")
	_clear_props()
	await frames(2)
	return "" if report.failures.is_empty() else label + ": strict checks failed"


func _physics_process(delta: float) -> void:
	# Parent handles bounded physics queries; its Blink cast watch stays disabled.
	super._physics_process(delta)
	if not watch_mark or not cast_edge.is_empty(): return
	var p: Player = readers[1].player
	if float(p.cds.ult) <= 0.0: return
	cast_edge = {"position": _v(p.global_position), "cd": p.cds.ult, "mp": p.mp,
		"raw_key_down": Input.is_key_pressed(held_key), "intent_ult": p.intent_ult,
		"intent_move": _v(p.intent_move), "physics_frame": Engine.get_physics_frames()}
	p.set_physics_process(false)
	watch_mark = false
	_release()


func _clear_props() -> void:
	for prop in fixture_props:
		if is_instance_valid(prop): prop.queue_free()
	fixture_props.clear()


func _cleanup() -> void:
	watch_mark = false
	_clear_props()
	await super._cleanup()
