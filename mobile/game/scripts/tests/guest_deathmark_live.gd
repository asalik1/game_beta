extends "res://scripts/tests/guest_blink_enet_live.gd"
## Optional Death Mark episode. Inherits paired boot, ENet admission, production
## actor/mirror setup, geometry queries, capture controls and cleanup unchanged.
var watch_mark := false
var cast_edge: Dictionary = {}
var fixture_props: Array[StaticBody2D] = []
var first_damage: Array = []
var payload_mode := false
var watch_poison := false
var watch_poison_contact := false
var poison_edge: Dictionary = {}
var poison_contact: Dictionary = {}
var lent_build: Dictionary = {}
var poison_mana_before := 0.0


func run() -> int:
	payload_mode = flag("payload")
	shot_dir = shot_dir.path_join("deathmark")
	if payload_mode: shot_dir = shot_dir.path_join("payload")
	return await super.run()


func _reader(cls: String, label: String) -> void:
	await super._reader("assassin" if label == "Guest" else cls, label)
	if payload_mode and label == "Guest":
		var p: Player = readers[1].player
		var economy := _economy(readers[1])
		var level_delta := 5 - p.level
		p.level = 5
		p.themes_known = Classes.themes_unlocked(p.level)
		p.skill_points += level_delta * Balance.SKILL_POINTS_PER_LEVEL
		p.unspent_attr += level_delta * Balance.ATTR_POINTS_PER_LEVEL
		p.set_ability_theme("a1", "poison")
		p.set_ability_theme("ult", "")
		p.recalc()
		p.hp = p.max_hp
		p.mp = p.max_mp
		lent_build = _payload_sheet(p)
		_check(p.unlocked_theme_ids().has("poison") and p.ability_theme.a1 == "poison"
			and p.ability_theme.ult == "" and p.equipment.is_empty() and p.tree_points.is_empty()
			and _economy(readers[1]) == economy, "payload: legal lent level-5 theme before admission; economy unchanged")


func _episode() -> String:
	report["mode"] = "deathmark"
	report["fixture"] = "Two inherited ch1 readers, manually admitted/ready over real ENet; actual join-ready, enemy spawn/status/hit/state and movement RPCs. Base Assassin native ult input, full 1|4 body mask. Stationary ordinary level-8 wolf observer; existing tree-wide enemies excluded from strike scans. Guest physics held immediately after native cast edge while delayed execution continues; no moving-combat claim. Host local input/physics disabled. Target health/status, guest mana/cooldown reset between two cases. Factory boulder placed identically in both worlds for occupied endpoint; this is posed matching geometry, not scenery/world-snapshot replication proof. No latency/loss, rewards, persistence, balance or physical-device claim."
	if payload_mode:
		report["mode"] = "deathmark_payload"
		report["lent_build"] = lent_build.duplicate(true)
		report["fixture"] += " PAYLOAD VARIANT: guest lent level5 and legal Poison Stab theme with recalculated ordinary stats before admission; points remain unspent. Native missed Poison Stab overlaps each base ultimate from 180px away; its actual melee contact is observed before teleport. Three ultimate contacts must remain unpoisoned and unslowed, and the newer four-field payload must remain installed. Separate close native Poison Stab positive control after both cases verifies real status RPC/source. Frozen host status timers make zero statuses persistent evidence; no status tick-DPS or exact RPC message-count claim."
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
	p.global_position = actor_point - Vector2(180 if payload_mode else 120, 0)
	p.velocity = Vector2.ZERO
	p.facing = Vector2.RIGHT
	p.locked_target = mirror
	p.soft_target = mirror
	p.mp = p.max_mp
	p.cds.ult = 0.0
	actor.hp = actor.max_hp
	actor.vuln_time = 0.0
	mirror.vuln_time = 0.0
	if payload_mode:
		_reset_payload_status()
		p.cds.a1 = 0.0
		p.cds.a3 = 0.0
		p.melee_swing = 0.0
		p.next_crit = false
		_check(_payload_sheet(p) == lent_build and _shell(0, guest_id).level == p.level,
			label + ": lent sheet unchanged and level admitted to host shell")
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
	if payload_mode:
		var poison_error := await _native_poison(row, label, true)
		if poison_error != "": return poison_error
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
	var result := await _finish_case(row, label, end, raw_expected, amplification, host_before, economy_before)
	if payload_mode and not occupied and result == "":
		return await _positive_poison()
	return result


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
	if payload_mode:
		row["payload_end"] = {"host_status": _payload_status(actor), "guest_status": _payload_status(mirror),
			"ambient": _payload_of(p), "expected": poison_edge.payload.duplicate(true)}
		_check(_status_clear(actor) and _status_clear(mirror), label + ": no Poison Stab toxin/burn/slow on ultimate contacts")
		_check(_payload_of(p) == poison_edge.payload, label + ": all four newer Poison Stab payload fields retained")
		_check(_payload_sheet(p) == lent_build, label + ": raw stats and build remain unchanged")
	await _capture(label + "_converged")
	_clear_props()
	await frames(2)
	return "" if report.failures.is_empty() else label + ": strict checks failed"


func _physics_process(delta: float) -> void:
	# Parent handles bounded physics queries; its Blink cast watch stays disabled.
	super._physics_process(delta)
	if payload_mode: _observe_poison()
	if not watch_mark or not cast_edge.is_empty(): return
	var p: Player = readers[1].player
	if float(p.cds.ult) <= 0.0: return
	cast_edge = {"position": _v(p.global_position), "cd": p.cds.ult, "mp": p.mp,
		"raw_key_down": Input.is_key_pressed(held_key), "intent_ult": p.intent_ult,
		"intent_move": _v(p.intent_move), "physics_frame": Engine.get_physics_frames()}
	p.set_physics_process(false)
	watch_mark = false
	_release()
	if payload_mode:
		# Queue the next native input at the actual cast edge. Waiting for the
		# idle _until poll can spend most of the short execution interval.
		_arm_native_poison()


func _clear_props() -> void:
	for prop in fixture_props:
		if is_instance_valid(prop): prop.queue_free()
	fixture_props.clear()


func _cleanup() -> void:
	watch_mark = false
	watch_poison = false
	watch_poison_contact = false
	_clear_props()
	await super._cleanup()


## Payload mode borrows the established native-input observer and real ENet
## actor. A melee-swing rise sampled BEFORE teleport confirms the missed Stab
## contact. A sample after teleport is ambiguous and remains a fixture failure.
func _native_poison(row: Dictionary, label: String, must_miss: bool) -> String:
	var p: Player = readers[1].player
	if not must_miss:
		_arm_native_poison()
	var mana_before := poison_mana_before
	if not await _until(func() -> bool: return not poison_edge.is_empty(), 2.0):
		return label + ": native Poison Stab cast edge absent"
	row["poison_edge"] = poison_edge.duplicate(true)
	if must_miss:
		var gap := int(poison_edge.frame) - int(cast_edge.physics_frame)
		_check(gap > 0 and gap <= 2, label + ": native follow-up edge chained within two physics ticks")
	_check(bool(poison_edge.raw_key_down) and bool(poison_edge.intent_a1)
		and poison_edge.intent_move == [0.0, 0.0], label + ": actual native Poison Stab input")
	_check(absf(float(poison_edge.mp) - (mana_before - p.ability_cost("a1"))) < 0.01
		and absf(float(poison_edge.cd) - p.ability_cd("a1")) < 0.01,
		label + ": one ordinary Poison Stab cost/cooldown edge")
	_check(poison_edge.payload.fx == Classes.ability_fx("assassin", "a1", "poison")
		and bool(poison_edge.payload.themed) and poison_edge.payload.color == p._theme_color("a1")
		and is_equal_approx(float(poison_edge.payload.base), p.ability_base_flat("a1")),
		label + ": real cast installs all four legal Poison Stab payload fields")
	if not await _until(func() -> bool: return not poison_contact.is_empty(), 2.0):
		return label + ": native Poison Stab never reached its melee contact"
	row["poison_contact"] = poison_contact.duplicate(true)
	_check(int(poison_contact.frame) > int(poison_edge.frame) and bool(poison_contact.physics_held)
		and poison_contact.payload == poison_edge.payload, label + ": delayed Poison Stab resumes its own payload")
	if must_miss:
		var start: Array = row.before.start
		if poison_contact.position != start or int(poison_contact.targets_in_arc) != 0:
			return label + ": native Stab contact missed the pre-teleport out-of-range fixture window"
		_check(float(poison_contact.distance) > 170.0 and int(poison_contact.host_hits) <= 2,
			label + ": real Poison Stab contact is out of range before final teleport")
	else:
		_check(int(poison_contact.targets_in_arc) == 1, label + ": close positive-control stab reaches the sole mirror")
	return ""


func _arm_native_poison() -> void:
	var p: Player = readers[1].player
	p.cds.a1 = 0.0
	p.melee_swing = 0.0
	poison_edge = {}
	poison_contact = {}
	poison_mana_before = p.mp
	watch_poison = true
	var original_faults := int(report.motion_faults_before)
	_press(int(readers[1].binds.a1))
	report["motion_faults_before"] = original_faults
	p.set_physics_process(true)


func _observe_poison() -> void:
	if not watch_poison and not watch_poison_contact: return
	var p: Player = readers[1].player
	if watch_poison and p.cds.a1 > 0.0:
		poison_edge = {"frame": Engine.get_physics_frames(), "position": _v(p.global_position),
			"process_frame": Engine.get_process_frames(), "ticks_usec": Time.get_ticks_usec(),
			"strike_clip": p._strike_clip, "contact_delay": p.swing_delay(Balance.STAB_STRIKE_DELAY),
			"raw_key_down": Input.is_key_pressed(held_key), "intent_a1": p.intent_a1,
			"intent_move": _v(p.intent_move), "cd": p.cds.a1, "mp": p.mp, "payload": _payload_of(p)}
		p.set_physics_process(false)
		watch_poison = false
		watch_poison_contact = true
		_release()
	if watch_poison_contact and p.melee_swing > 0.0:
		poison_contact = {"frame": Engine.get_physics_frames(), "position": _v(p.global_position),
			"process_frame": Engine.get_process_frames(), "ticks_usec": Time.get_ticks_usec(),
			"sample_kind": "first post-contact physics observation; rejected if already teleported",
			"distance": p.global_position.distance_to(mirror.global_position),
			"physics_held": not p.is_physics_processing(), "payload": _payload_of(p),
			"host_hits": actor.received.size(), "targets_in_arc": p._enemies_within(
				p.global_position + p.melee_dir * 118.0 * 0.55, 118.0 * 0.55).size()}
		watch_poison_contact = false


func _positive_poison() -> String:
	var p: Player = readers[1].player
	var label := "payload_close_poison_control"
	step(label)
	_reset_payload_status()
	actor.hp = actor.max_hp
	actor.received.clear()
	wires[0].last_hit = {}
	if not await _until(func() -> bool: return absf(mirror.hp / mirror.max_hp - 1.0) < 0.00001, 3.0):
		return label + ": HP reset did not replicate"
	var economy := [_economy(readers[0]), _economy(readers[1])]
	var host_before := _hero_state(readers[0].player)
	var row := {"hp_before": actor.hp, "position": _v(p.global_position)}
	report["positive_control"] = row
	var error := await _native_poison(row, label, false)
	if error != "": return error
	if not await _until(func() -> bool: return actor.received.size() >= 1 and actor.toxin > 0, 3.0):
		return label + ": real hit/toxin RPC did not reach host"
	await _settle(0.2)
	row["hits"] = actor.received.duplicate(true)
	row["host_status"] = _payload_status(actor)
	row["guest_status"] = _payload_status(mirror)
	_check(actor.received.size() == 1 and actor.hp > 0.0 and not actor.dying,
		label + ": exactly one actual Poison Stab host contact without death")
	if actor.received.size() == 1:
		var hit: Dictionary = actor.received[0]
		_check(int(hit.sender) == guest_id and int(hit.source) == guest_id and not bool(hit.silent)
			and float(hit.raw) > 0.0 and is_equal_approx(float(hit.applied), float(hit.raw))
			and absf(float(row.hp_before) - actor.hp - float(hit.applied)) < 0.01,
			label + ": guest owns the physical hit and exact authoritative HP debit")
	_check(actor.toxin == 1 and actor.burn_time > 0.0 and actor.burn_dps > 0.0
		and actor.slow_time > 0.0 and is_equal_approx(actor.slow_mult, 0.7)
		and actor.burn_src == _shell(0, guest_id), label + ": one real toxin stack and slow with guest DoT source")
	var converged := await _until(func() -> bool:
		return absf(mirror.hp / mirror.max_hp - float(int(actor.hp / actor.max_hp * 255.0)) / 255.0) < 0.00001, 3.0)
	_check(converged and _payload_of(p) == poison_edge.payload and _payload_sheet(p) == lent_build,
		label + ": HP replication and Poison payload/raw sheet preserved")
	_check(_hero_state(readers[0].player) == host_before and [_economy(readers[0]), _economy(readers[1])] == economy,
		label + ": host hero and both economies unchanged")
	await _capture(label)
	return "" if report.failures.is_empty() else label + ": strict checks failed"


func _reset_payload_status() -> void:
	for e in [actor, mirror]:
		e.toxin = 0
		e.burn_time = 0.0
		e.burn_dps = 0.0
		e.burn_tick = 0.0
		e.burn_src = null
		e.slow_time = 0.0
		e.slow_mult = 1.0
		e.stun_time = 0.0
		e.vuln_time = 0.0
		e.vuln_mult = 1.5


func _payload_status(e: Enemy) -> Dictionary:
	return {"toxin": e.toxin, "burn_time": e.burn_time, "burn_dps": e.burn_dps,
		"slow_time": e.slow_time, "slow_mult": e.slow_mult,
		"source": e.burn_src.peer_id if is_instance_valid(e.burn_src) else 0}


func _status_clear(e: Enemy) -> bool:
	return e.toxin == 0 and e.burn_time == 0.0 and e.burn_dps == 0.0 \
		and e.slow_time == 0.0 and e.slow_mult == 1.0


func _payload_of(p: Player) -> Dictionary:
	return {"fx": p._tfx.duplicate(true), "color": p._tcolor, "themed": p._themed, "base": p._cast_base}


func _payload_sheet(p: Player) -> Dictionary:
	return {"level": p.level, "atk": p.atk, "crit": p.crit, "crit_dmg": p.crit_dmg,
		"combo": p.combo, "dex": p.dex, "physpen": p.physpen, "max_hp": p.max_hp, "max_mp": p.max_mp,
		"equipment": p.equipment.duplicate(true), "tree_points": p.tree_points.duplicate(true),
		"themes": p.ability_theme.duplicate(true), "skill_points": p.skill_points, "unspent_attr": p.unspent_attr}
