extends RefCounted
## Production casts with frozen actors and explicitly lent theme access.
const EXPECTED_BASELINE := ["payload.cross.no_added_toxin", "payload.cross.no_added_slow",
	"payload.cross.own_payload_on_hits"]

class RecordingWolf extends Enemy:
	var receipts: Array[Dictionary] = []
	func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
		var source: Player = hit_src
		var before := hp
		var payload := {}
		if is_instance_valid(source):
			payload = {"fx": source._tfx.duplicate(true), "color": source._tcolor,
				"themed": source._themed, "base": source._cast_base}
		super(amount, from_dir, is_crit, silent)
		receipts.append({"amount": amount, "hp_removed": before - hp,
			"source_local": is_instance_valid(source) and source == game.local_player,
			"payload": payload, "toxin": toxin, "slow_time": slow_time,
			"frame": Engine.get_process_frames()})

var r: Node
var g: Game
var p: Player
var origin := Vector2.ZERO
var saved := {}
var enemies: Array[Dictionary] = []
var ledger := {"cases": [], "scope": "Frozen base Assassin and wolf, production use_ability calls. Level5/theme access lent without recalculating starting combat stats; no equipment. Target HP10000 and zero crit/evasion/resistance isolate payloads. No ordinary progression, device-input or replication claim."}


static func run(rig: Node) -> void:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	await probe._run()


func _check(id: String, ok: bool, detail: Variant, expected_old := false) -> void:
	r._check("payload." + id, ok, detail, expected_old)


func _payload() -> Dictionary:
	return {"fx": p._tfx.duplicate(true), "color": p._tcolor,
		"themed": p._themed, "base": p._cast_base}


func _run() -> void:
	var fresh: bool = g.no_saves and not g.net_online() and not g.get_tree().paused \
		and not g.input_overlay_up() and p.cls == "assassin" and p.skin == "" \
		and p.level == 1 and p.equipment.is_empty() and p.tree_points.is_empty() \
		and p.deathmark_time <= 0.0 and not g.dev_god
	_check("fresh_fixture", fresh, ledger.scope)
	if not fresh:
		return
	for key in ["level", "themes_known", "ability_theme", "cds", "_tfx", "_tcolor",
			"_themed", "_cast_base", "crit", "combo", "hp", "mp", "global_position",
			"velocity", "facing", "look_sign", "locked_target", "soft_target", "next_crit",
			"deathmark_time", "hurt_cd", "hurt_was_heavy", "stab_ls_time", "stab_ls_amt",
			"hunt_rhythm", "melee_swing", "melee_style", "melee_dir", "_strike_clip"]:
		var value: Variant = p.get(key)
		saved[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	saved["physics"] = p.is_physics_processing()
	saved["settings"] = g.settings.duplicate(true)
	saved["hazard_tick"] = g.hazard_tick
	saved["terrain_event_t"] = g.terrain_event_t
	saved["camera_smoothing"] = g.camera.position_smoothing_enabled
	saved["party_stats"] = g.party_stats.duplicate(true)
	saved["fight_stats"] = g.fight_stats.duplicate(true)
	for e in g.get_tree().get_nodes_in_group("enemies"):
		enemies.append({"node": e, "physics": e.is_physics_processing()})
		e.set_physics_process(false)
		e.remove_from_group("enemies")
	p.set_physics_process(false)
	p.level = 5
	p.themes_known = Classes.themes_unlocked(p.level)
	p.set_ability_theme("a1", "poison")
	p.set_ability_theme("ult", "")
	p.crit = 0.0
	p.combo = 0.0
	g.settings["hit_stop"] = false
	g.settings["camera_shake"] = 0.0
	g.settings["touch_controls"] = r.flag("touch")
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.hazard_tick = 10000.0
	g.terrain_event_t = 10000.0
	g.camera.position_smoothing_enabled = false
	origin = g.free_spawn_pos(g.room_center(g.cur_room), g.room_center(g.cur_room))
	p.global_position = origin
	_check("lent_theme_available", p.ability_theme.a1 == "poison" and p.ability_theme.ult == ""
		and p.unlocked_theme_ids().has("poison"), {"level": p.level, "atk": p.atk,
		"max_hp": p.max_hp, "themes": p.ability_theme.duplicate(true), "scope": ledger.scope})
	await r.sim_wait(3.0)
	var reference: Dictionary = await _case("ultimate_only", "ult", 200.0, false)
	await _case("ranged_stab", "a1", 200.0, false)
	await _case("close_poison", "a1", 60.0, false)
	var crossed: Dictionary = await _case("cross", "ult", 200.0, true)
	_check("cross.same_three_damage_hits", _same_damage(reference.hits, crossed.hits),
		{"reference": reference.hits, "crossed": crossed.hits})
	# Expanded acceptance is opt-in and strict only; do not widen the proven baseline oracle.
	if r.flag("payload-extra") and not r.flag("baseline"):
		p.level = 15
		p.themes_known = Classes.themes_unlocked(p.level)
		p.set_ability_theme("ult", "shadow")
		_check("execute.lent_theme_available", p.ability_theme.ult == "shadow"
			and p.unlocked_theme_ids().has("shadow"), {"level": p.level, "atk": p.atk,
			"max_hp": p.max_hp, "note": "L15 access lent; original combat stats; victim starts at 25% HP"})
		var execute_ref: Dictionary = await _case("execute_only", "ult", 200.0, false, true)
		var execute_cross: Dictionary = await _case("execute_cross", "ult", 200.0, true, true)
		_check("execute.same_four_damage_hits", _same_damage(execute_ref.hits, execute_cross.hits, 4),
			{"reference": execute_ref.hits, "crossed": execute_cross.hits})
		p.set_ability_theme("ult", "")
		await _cancel_case(false)
		await _cancel_case(true)
	var actual: Array[String] = []
	for row in r.rows:
		if String(row.id).begins_with("payload.") and row.status == "baseline_finding":
			actual.append(String(row.id))
	actual.sort()
	var expected: Array = EXPECTED_BASELINE.duplicate() if r.flag("baseline") else []
	expected.sort()
	_check("baseline_exact", actual == expected, {"actual": actual, "expected": expected})
	# Dedicated scene is discarded, not resumed as a saved game. Restore
	# borrowed gameplay fields; transient animation/FX belong to this fixture.
	for key in saved:
		if key not in ["physics", "settings", "hazard_tick", "terrain_event_t", "camera_smoothing", "party_stats", "fight_stats"]:
			p.set(key, saved[key])
	p.set_physics_process(bool(saved.physics))
	g.settings = saved.settings
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.hazard_tick = saved.hazard_tick
	g.terrain_event_t = saved.terrain_event_t
	g.camera.position_smoothing_enabled = saved.camera_smoothing
	g.party_stats = saved.party_stats
	g.fight_stats = saved.fight_stats
	for entry in enemies:
		if is_instance_valid(entry.node):
			entry.node.add_to_group("enemies")
			entry.node.set_physics_process(bool(entry.physics))
	_check("restored", p.level == saved.level and p.ability_theme == saved.ability_theme
		and p.is_physics_processing() == saved.physics, "borrowed fields and original enemy processing/groups restored")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(String(r.shot_dir).path_join("payload.json"), FileAccess.WRITE)
	_check("receipt_written", file != null, "per-hit payload, statuses and post-frame newer-state observations")
	if file != null:
		file.store_string(JSON.stringify(ledger, "\t"))
		file.close()


func _case(id: String, slot: String, distance: float, crossed: bool, execute := false) -> Dictionary:
	r.step("payload " + id)
	p.global_position = origin
	p.velocity = Vector2.ZERO
	p.facing = Vector2.RIGHT
	p.look_sign = 1.0
	p.cds = {"a1": 0.0, "a2": 0.0, "a3": 0.0, "ult": 0.0}
	p.deathmark_time = 0.0
	p.stab_ls_time = 0.0
	p.stab_ls_amt = 0.0
	p.next_crit = false
	var e := RecordingWolf.new()
	e._setup(g, "wolf", origin + Vector2(distance, 0), 1, 1.0)
	e.hp = 2500.0 if execute else 10000.0
	e.max_hp = 10000.0
	e.eva = 0.0
	e.critres = 0.0
	e.physres = 0.0
	e.magres = 0.0
	g.add_enemy(e)
	e.set_physics_process(false)
	p.locked_target = e
	p.soft_target = e
	await r.frames(3)
	var record := {"id": id, "distance": p.global_position.distance_to(e.global_position),
		"hero_hp": p.hp, "atk": p.atk, "level": p.level, "target_initial_hp": e.hp,
		"execute": execute, "newer_state": [], "hits": []}
	ledger.cases.append(record)
	p.use_ability(slot)
	_check(id + ".cast_accepted", float(p.cds[slot]) > 0.0, p.cds.duplicate())
	var original := _payload()
	var later := original.duplicate(true)
	if slot == "ult":
		# Trigger the later cast only after observing the real first hit.
		var limit := Time.get_ticks_msec() + 2500
		while e.receipts.is_empty() and Time.get_ticks_msec() < limit:
			await g.get_tree().process_frame
		_check(id + ".first_hit_before_cross", e.receipts.size() == 1 and e.toxin == 0,
			{"hits": e.receipts.duplicate(true), "toxin": e.toxin})
		if crossed:
			p.use_ability("a1")
			later = _payload()
			_check(id + ".later_poison_cast", float(p.cds.a1) > 0.0
				and later.fx == Classes.ability_fx("assassin", "a1", "poison"), later)
	var elapsed := 0.0
	var observed_counts: Array[int] = []
	while elapsed < 0.8:
		await g.get_tree().process_frame
		elapsed += g.get_process_delta_time()
		if crossed:
			var count := e.receipts.size()
			if count >= 2 and not observed_counts.has(count):
				observed_counts.append(count)
				var now := _payload()
				record.newer_state.append({"hits": count, "payload": now, "seconds": elapsed})
				_check(id + ".newer_state_after_%d_hits" % count, now == later, now)
	record.hits = e.receipts.duplicate(true)
	record["toxin"] = e.toxin
	record["slow_time"] = e.slow_time
	record["slow_mult"] = e.slow_mult
	record["final_payload"] = _payload()
	if slot == "ult":
		_check(id + (".four_hits" if execute else ".three_hits"), e.receipts.size() == (4 if execute else 3), record.hits)
		if execute:
			_check(id + ".execute_survivor", not e.dying and e.hp > 0.0 and e.hp < e.max_hp * 0.3, e.hp)
		_check(id + ".no_added_toxin", e.toxin == 0, e.toxin, crossed)
		_check(id + ".no_added_slow", e.slow_time == 0.0, {"time": e.slow_time, "mult": e.slow_mult}, crossed)
		var own := true
		for hit in e.receipts:
			own = own and hit.payload == original
		_check(id + ".own_payload_on_hits", own, record.hits, crossed)
		if crossed:
			_check(id + ".final_newer_state", _payload() == later, _payload())
			_check(id + ".sampled_final_resume", observed_counts.has(4 if execute else 3), observed_counts)
			if r.flag("baseline"):
				var signature: bool = e.receipts.size() == 3 and e.toxin == 2 \
					and is_equal_approx(e.slow_mult, 0.7) and e.slow_time > 0.0
				if signature:
					signature = e.receipts[0].payload == original and e.receipts[1].payload == later \
						and e.receipts[2].payload == later
				_check(id + ".exact_outgoing_signature", signature, record)
	elif distance > 118.0:
		_check(id + ".whiff", e.receipts.is_empty() and e.toxin == 0 and e.slow_time == 0.0, record)
	else:
		_check(id + ".poison_positive", e.receipts.size() == 1 and e.toxin == 1
			and e.slow_time > 0.0 and is_equal_approx(e.slow_mult, 0.7), record)
	for i in e.receipts.size():
		var hit: Dictionary = e.receipts[i]
		_check(id + ".real_damage_%d" % i, bool(hit.source_local) and float(hit.hp_removed) > 0.0, hit)
	if id in ["ultimate_only", "close_poison", "cross", "execute_cross"]:
		await RenderingServer.frame_post_draw
		r.shot("payload_" + id, "posed level%d theme access; frozen actors, production casts; inspect payload.json for exact status" % p.level)
	p.locked_target = null
	p.soft_target = null
	e.queue_free()
	await r.frames(2)
	await g.get_tree().create_timer(1.2, false).timeout
	return record


func _same_damage(a: Array, b: Array, expected_hits := 3) -> bool:
	if a.size() != expected_hits or b.size() != expected_hits:
		return false
	for i in expected_hits:
		if not is_equal_approx(float(a[i].amount), float(b[i].amount)) \
				or not is_equal_approx(float(a[i].hp_removed), float(b[i].hp_removed)):
			return false
	return true


func _cancel_target() -> RecordingWolf:
	var e := RecordingWolf.new()
	e._setup(g, "wolf", p.global_position + Vector2(200, 0), 1, 1.0)
	e.hp = 10000.0
	e.max_hp = 10000.0
	e.eva = 0.0
	e.critres = 0.0
	e.physres = 0.0
	e.magres = 0.0
	g.add_enemy(e)
	e.set_physics_process(false)
	p.locked_target = e
	p.soft_target = e
	return e


func _cancel_case(replace_world: bool) -> void:
	var id := "cancel_replay" if replace_world else "cancel_target"
	r.step("payload " + id)
	p.global_position = origin
	p.velocity = Vector2.ZERO
	p.facing = Vector2.RIGHT
	p.look_sign = 1.0
	p.cds = {"a1": 0.0, "a2": 0.0, "a3": 0.0, "ult": 0.0}
	p.deathmark_time = 0.0
	p.stab_ls_time = 0.0
	p.stab_ls_amt = 0.0
	var old_target := _cancel_target()
	var receipts: Array[Dictionary] = old_target.receipts
	var old_world := g.world.get_instance_id()
	var player_id := p.get_instance_id()
	p.use_ability("ult")
	_check(id + ".first_hit", receipts.size() == 1, receipts.duplicate(true))
	p.use_ability("a1")
	var later := _payload()
	_check(id + ".newer_poison_cast", later.fx == Classes.ability_fx("assassin", "a1", "poison")
		and float(p.cds.a1) > 0.0, later)
	# Install the newer payload before any await/replay so cancellation cannot
	# happen before the preservation oracle exists.
	# Pause synchronously after the first real hit, before either later beat.
	g.request_pause(true)
	if replace_world:
		g.replay_chapter("ch1")
		_check(id + ".world_replaced", g.world.get_instance_id() != old_world
			and g.local_player.get_instance_id() == player_id, "real replay; retained Player")
		for e in g.get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
			e.remove_from_group("enemies")
		p.set_physics_process(false)
		g.hazard_tick = 10000.0
		g.terrain_event_t = 10000.0
		origin = g.free_spawn_pos(g.room_center(g.cur_room), g.room_center(g.cur_room))
		p.global_position = origin
		await r.skip_dialogue()
	else:
		old_target.free()
	_check(id + ".target_gone", not is_instance_valid(old_target), "old victim removed before delayed contacts")
	g.request_pause(false)
	var fresh := _cancel_target()
	var held_position := p.global_position
	await g.get_tree().create_timer(0.8, false).timeout
	var record := {"id": id, "old_hits": receipts.duplicate(true), "fresh_hits": fresh.receipts.duplicate(true),
		"later": later, "after": _payload(), "position_held": p.global_position == held_position}
	ledger.cases.append(record)
	_check(id + ".no_later_contact_or_blink", receipts.size() == 1 and fresh.receipts.is_empty()
		and p.global_position == held_position, record)
	_check(id + ".newer_state_preserved", _payload() == later, record)
	# The same retained Player must still execute a genuinely new cast.
	p.cds.ult = 0.0
	p.use_ability("ult")
	await g.get_tree().create_timer(0.8, false).timeout
	_check(id + ".fresh_execution_works", fresh.receipts.size() == 3 and fresh.toxin == 0
		and fresh.slow_time == 0.0, fresh.receipts.duplicate(true))
	p.locked_target = null
	p.soft_target = null
	fresh.queue_free()
	await r.frames(2)
	await g.get_tree().create_timer(1.2, false).timeout
