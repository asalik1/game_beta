extends RefCounted
## Controlled transition timing; real trial start and native pause/resume.
## Cancellation probes schedule counters, not earned rewards or settlement.
var r: Node
var g: Game
var counts: Dictionary = {}


static func run(rig: Node) -> void:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	await probe._run()


func _check(id: String, ok: bool, detail: Variant) -> void:
	r._check("trial." + id, ok, detail)


func _wall(seconds: float) -> void:
	await g.get_tree().create_timer(seconds, true, false, true).timeout


func _world_wait(seconds: float) -> void:
	await g.get_tree().create_timer(seconds, false).timeout


func _bump(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _bosses() -> Array:
	var found: Array = []
	for b in g.bosses:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and b.endgame_boss:
			found.append(b)
	return found


func _ledger(trial: Endgame) -> Dictionary:
	return {"gold": g.player.gold, "mail": g.mailbox.duplicate(true),
		"pending_gold": trial.pending_gold, "pending_gems": trial.pending_gems.duplicate(true),
		"pending_gear": trial.pending_gear.duplicate(true)}


func _run() -> void:
	var ready: bool = g.no_saves and not g.net_online() and g.endgame == null \
		and not r.flag("baseline") and not r.flag("effects") and not r.flag("lifetime") and not r.flag("payload")
	_check("preconditions", ready, "fresh no-save solo fixture; no combined mode or baseline waiver")
	if not ready:
		return
	g.settings["hit_stop"] = false
	g.camera.position_smoothing_enabled = false
	g.player.set_physics_process(false)
	r.step("actual Crucible first beat behind native pause")
	g.enter_endgame("crucible")
	var trial: Endgame = g.endgame
	if not is_instance_valid(trial):
		_check("controller_created", false, "enter_endgame did not create controller")
		return
	await r.native._key(KEY_ESCAPE)
	_check("native_pause", g.menus.current == "pause" and g.get_tree().paused, g.menus.current)
	_check("pending_first_spawn", trial.index == 0 and _bosses().is_empty(), {"index": trial.index, "bosses": _bosses().size()})
	var before := _ledger(trial)
	await _wall(1.6)
	_check("spawn_held", trial.index == 0 and _bosses().is_empty(), {"index": trial.index, "bosses": _bosses().size()})
	_check("held_no_reward_change", _ledger(trial) == before, _ledger(trial))
	r.shot("trial_01_crucible_paused", "actual initial trial beat held beyond0.8s; controlled no-save start")
	_check("resume_click", await r._button("Resume game"), "native pause action")
	_check("resumed", not g.get_tree().paused and not g.menus.is_open(), g.menus.current)
	await _world_wait(1.4)
	_check("one_boss_after_resume", trial.index == 1 and _bosses().size() == 1, {"index": trial.index, "bosses": _bosses().size()})
	for boss in _bosses():
		boss.set_physics_process(false)
	# The actual boss can announce with a full-screen painting; inspect play after it.
	var intro_deadline: int = Time.get_ticks_msec() + 8000
	while is_instance_valid(g.hud._boss_splash_layer) and Time.get_ticks_msec() < intro_deadline:
		await _wall(0.1)
	_check("first_boss_intro_finished", not is_instance_valid(g.hud._boss_splash_layer), "bounded wait; no splash suppression")
	r.shot("trial_02_crucible_resumed", "production first boss after native resume; AI frozen for later control probes")
	await _world_wait(1.0)
	_check("no_duplicate_spawn", trial.index == 1 and _bosses().size() == 1, {"index": trial.index, "bosses": _bosses().size()})
	r.step("controlled pending callback cancelled without settlement")
	before = _ledger(trial)
	trial._advance_after(0.4, func() -> void: _bump("inactive"))
	trial.active = false
	await _world_wait(0.8)
	_check("inactive_cancelled", int(counts.get("inactive", 0)) == 0, counts.duplicate())
	_check("inactive_no_settlement", _ledger(trial) == before, _ledger(trial))
	r.step("same controller reused through real start")
	trial.active = true
	trial._advance_after(0.5, func() -> void: _bump("old_run"))
	var old_world: int = g.world.get_instance_id()
	trial.start("depths")
	_check("reuse_real_world", g.endgame == trial and g.world.get_instance_id() != old_world and trial.mode == "depths", "actual start replaces arena")
	await _world_wait(0.9)
	_check("old_run_cancelled", int(counts.get("old_run", 0)) == 0, counts.duplicate())
	r.step("current controller ownership replacement")
	trial._advance_after(0.5, func() -> void: _bump("old_owner"))
	var other := Endgame.new()
	other.game = g
	g.add_child(other)
	g.endgame = other
	await _world_wait(0.9)
	_check("old_owner_cancelled", int(counts.get("old_owner", 0)) == 0, counts.duplicate())
	g.endgame = trial
	other.queue_free()
	r.step("real world replacement without restarting controller")
	trial._advance_after(0.5, func() -> void: _bump("old_world"))
	old_world = g.world.get_instance_id()
	g.switch_chapter("depths", true)
	_check("world_rebuilt", g.world.get_instance_id() != old_world and g.endgame == trial, "actual switch_chapter; no fake Node world")
	await _world_wait(0.9)
	_check("old_world_cancelled", int(counts.get("old_world", 0)) == 0, counts.duplicate())
	r.step("fresh current run positive after stale probes")
	trial.start("depths")
	trial._advance_after(0.4, func() -> void: _bump("fresh"))
	await _world_wait(0.8)
	_check("fresh_fired", int(counts.get("fresh", 0)) == 1, counts.duplicate())
	await _world_wait(0.6)
	_check("fresh_once", int(counts.get("fresh", 0)) == 1, counts.duplicate())
	r.shot("trial_03_fresh_positive", "real Depths camp after controlled stale/fresh callback probes; no rewards earned")
	r.step("controlled Depths room-clear beat behind native pause")
	# This timing probe is not a level1-versus-depth42 combat/survival test.
	var saved_hurt_cd: float = g.player.hurt_cd
	var saved_hurt_heavy: bool = g.player.hurt_was_heavy
	g.player.hurt_cd = 100.0
	g.player.hurt_was_heavy = true
	# Loan a cleared trash depth in the real camp; no monster kills or earned rewards.
	# Invoke the actual room-clear scheduler rather than scheduling descend ourselves.
	trial.depth = Balance.DEPTHS_ENTRY_FLOOR + 1
	trial.wave_active = false
	var cleared_depth: int = trial.depth
	var depths_world: int = g.world.get_instance_id()
	_check("depths_controlled_trash_depth", cleared_depth % Balance.DEPTHS_BOSS_EVERY != 0, cleared_depth)
	trial._on_room_cleared(false)
	before = _ledger(trial) # The controlled clear has already accrued its pending award.
	await r.native._key(KEY_ESCAPE)
	_check("depths_native_pause", g.menus.current == "pause" and g.get_tree().paused, g.menus.current)
	await _wall(1.8)
	_check("depths_advance_held", trial.depth == cleared_depth and not trial.wave_active, {"depth": trial.depth, "wave": trial.wave_active})
	_check("depths_held_ledger", _ledger(trial) == before, _ledger(trial))
	r.shot("trial_04_depths_paused", "controlled cleared-depth loan; actual1.3s room-clear timer held behind native pause")
	_check("depths_resume_click", await r._button("Resume game"), "native pause action")
	await _world_wait(1.8)
	_check("depths_descended_once", trial.depth == cleared_depth + 1 and trial.wave_active
		and g.zone_alive.get(trial.arena_room, 0) == Balance.DEPTHS_WAVE_SIZE
		and g.world.get_instance_id() == depths_world, {"depth": trial.depth, "wave": trial.wave_active, "alive": g.zone_alive.get(trial.arena_room, 0)})
	# Deterministic old-code rejection; a randomly clean wave is not proof.
	var live_pool: Array = trial._mob_pool()
	var leaked_placeholders: Array[String] = []
	for pool_kind in live_pool:
		var pool_def: Dictionary = Story.ALL_ENEMIES.get(pool_kind, {})
		if pool_def.get("placeholder", false): leaked_placeholders.append(String(pool_kind))
	_check("depths_pool_no_placeholders", leaked_placeholders.is_empty(), {"pool_count": live_pool.size(), "placeholder_kinds": leaked_placeholders})
	_check("depths_pool_wolf_retained", "wolf" in live_pool, {"pool_count": live_pool.size()})
	var actual_kind_ids: Array[String] = []
	var invalid_kinds: Array[String] = []
	for enemy in g.get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and enemy.hp > 0.0 and not enemy.is_queued_for_deletion() \
				and enemy.game == g and enemy.zone_idx == trial.arena_room and g.world.is_ancestor_of(enemy):
			var ekind: String = enemy.kind
			actual_kind_ids.append(ekind)
			var edef: Dictionary = Story.ALL_ENEMIES.get(ekind, {})
			if edef.is_empty() or edef.get("boss", false) or edef.get("placeholder", false):
				invalid_kinds.append(ekind)
	_check("depths_wave_size_unchanged", actual_kind_ids.size() == Balance.DEPTHS_WAVE_SIZE, {"actual": actual_kind_ids.size(), "expected": Balance.DEPTHS_WAVE_SIZE, "kinds": actual_kind_ids})
	_check("depths_wave_kinds_eligible", not actual_kind_ids.is_empty() and invalid_kinds.is_empty(), {"kinds": actual_kind_ids, "invalid": invalid_kinds})
	for enemy in g.get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	r.shot("trial_05_depths_resumed", "actual descend spawned next wave after native resume; controlled prior clear, AI now frozen")
	await _world_wait(1.6)
	_check("depths_no_duplicate_advance", trial.depth == cleared_depth + 1 and trial.wave_active, {"depth": trial.depth, "wave": trial.wave_active})
	_check("depths_no_extra_award", _ledger(trial) == before, _ledger(trial))
	g.player.hurt_cd = saved_hurt_cd
	g.player.hurt_was_heavy = saved_hurt_heavy

	trial.active = false
	g.endgame_active = false
	g.player.set_physics_process(true)
	g.menus.close()
	g.enter_capital()
	await r.skip_dialogue()
	g.request_pause(false)
	_check("cleanup", g.no_saves and not g.endgame_active and not g.get_tree().paused and g.chapter_id == "capital", "coherent capital; no old-world restoration claim")
