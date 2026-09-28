extends RefCounted
## Controlled transition timing; real trial start and native pause/resume.
## Cancellation probes schedule counters, not earned rewards or settlement.
## Also the regression check for the Depths camp's unopened-shop warning.
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
	# Boot skips the opening lines, but their finishing fade still owns Escape.
	# Wait before starting the trial's timed beat, without bypassing that gate.
	var opening_deadline: int = Time.get_ticks_msec() + 8000
	while g.hud.cinematic_finishing() and Time.get_ticks_msec() < opening_deadline:
		await _wall(0.1)
	_check("opening_finished", not g.hud.cinematic_finishing(), "opening fade released native Escape")
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
	var dialogue_before: bool = g.hud.dialogue_active
	g.hud.dialogue_active = true # controlled readability gate across synchronous start
	g.endgame_active = false
	g.hud.announce("QA campaign tier unlocked", Color.WHITE)
	g.endgame_active = true
	g.hud.announce("QA Crucible queued notice", Color.WHITE)
	_check("notice_queued_precondition", _has_notice("QA Crucible queued notice") and _has_notice("QA campaign tier unlocked"), "controlled trial and token-less campaign entries")
	trial.start("depths")
	g.hud._tick_announcements()
	_check("restart_notice_expired", not _has_notice("QA Crucible queued notice"), "real Crucible-to-Depths start while unreadable")
	_check("campaign_notice_retained", _has_notice("QA campaign tier unlocked"), "campaign copy survives world switch")
	g.hud.discard_announcement("QA campaign tier unlocked")
	g.hud.dialogue_active = dialogue_before
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
	g.hud.announce("QA old arena notice", Color.WHITE)
	g.switch_chapter("depths", true)
	g.hud._tick_announcements()
	_check("world_notice_expired", not _has_notice("QA old arena notice"), "real arena replacement without controller restart")
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
	await _camp_shop_warning(trial)
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

	g.hud.announce("QA trial exit notice", Color.WHITE)
	_check("exit_notice_precondition", _has_notice("QA trial exit notice"), "trial copy exists before exit")
	trial.active = false
	g.endgame_active = false
	g.player.set_physics_process(true)
	g.menus.close()
	g.enter_capital()
	g.hud._tick_announcements()
	_check("capital_notice_expired", not _has_notice("QA trial exit notice"), "Return to Crownfall cannot resume trial copy")
	await r.skip_dialogue()
	g.request_pause(false)
	_check("cleanup", g.no_saves and not g.endgame_active and not g.get_tree().paused and g.chapter_id == "capital", "coherent capital; no old-world restoration claim")


## Real camp actions and native dialog buttons. Each case starts a fresh run;
## the borrowed trash entry avoids boss introductions/combat in this UI probe.
func _camp_shop_warning(trial: Endgame) -> void:
	var saved_checkpoint: int = g.player.depths_checkpoint
	var saved_hurt_cd: float = g.player.hurt_cd
	var saved_hurt_heavy: bool = g.player.hurt_was_heavy
	var saved_stock: Dictionary = g.shop_stock.duplicate(true)
	var saved_bags: Dictionary = g.shop_bags.duplicate(true)
	g.player.depths_checkpoint = Balance.DEPTHS_ENTRY_FLOOR + 1
	g.player.hurt_cd = 100.0
	g.player.hurt_was_heavy = true
	await _camp_shop_warning_cases(trial)
	g.menus.close()
	g.player.depths_checkpoint = saved_checkpoint
	trial.start("depths")
	g.player.hurt_cd = saved_hurt_cd
	g.player.hurt_was_heavy = saved_hurt_heavy
	g.shop_stock = saved_stock
	g.shop_bags = saved_bags


func _camp_action(node: Node2D) -> void:
	for interaction in g.interactables:
		if is_instance_valid(node) and interaction.node == node:
			interaction.action.call()
			return
	_check("camp_action_found", false, "missing real camp interaction")


func _camp_shop_warning_cases(trial: Endgame) -> void:
	r.step("camp warns before losing its unopened shop")
	trial.start("depths")
	var before := _ledger(trial)
	_camp_action(trial._camp_prompt)
	_check("camp_unvisited_confirm", g.menus.current == "confirm" and trial.depth == 0,
		{"menu": g.menus.current, "depth": trial.depth})
	if g.menus.current != "confirm":
		return # Old behavior fails above; never click unrelated UI or fight the wave.
	var cancel: Button = r.native._find_button(g.menus.root, "Cancel")
	_check("camp_cancel_focused", cancel != null and cancel.has_focus(), "safe initial choice")
	await r.frames(3)
	r.shot("trial_06_camp_shop_warning", "unopened shop warning with Cancel focused")
	_check("camp_cancel_click", await r._button("Cancel"), "native Cancel")
	_check("camp_cancel_stays_safe", trial.depth == 0 and not trial.wave_active
		and is_instance_valid(trial._camp_merchant) and is_instance_valid(trial._camp_prompt)
		and not g.menus.is_open() and not g.get_tree().paused, "camp and shop remain usable")
	_check("camp_cancel_ledger", _ledger(trial) == before, _ledger(trial))
	_camp_action(trial._camp_prompt)
	_check("camp_cancel_not_consent", g.menus.current == "confirm", "retry still needs consent")
	_check("camp_accept_click", await r._button("Descend anyway"), "native accept")
	_check("camp_accept_descends", trial.depth == g.player.depths_checkpoint and trial.wave_active
		and not is_instance_valid(trial._camp_merchant) and not is_instance_valid(trial._camp_prompt)
		and not g.menus.is_open(), "accepted first dive removes camp")

	r.step("browsing the camp shop skips the warning without a purchase")
	trial.start("depths")
	before = _ledger(trial)
	_camp_action(trial._camp_merchant)
	_check("camp_shop_opened", g.menus.current == "shop", g.menus.current)
	await r.native._key(KEY_ESCAPE)
	_camp_action(trial._camp_prompt)
	_check("camp_shopped_straight_down", trial.depth == g.player.depths_checkpoint
		and trial.wave_active and not g.menus.is_open(), {"menu": g.menus.current, "depth": trial.depth})
	_check("camp_browse_no_purchase", _ledger(trial) == before, _ledger(trial))

	r.step("a new run forgets the previous shop visit")
	trial.start("depths")
	_camp_action(trial._camp_prompt)
	_check("camp_new_run_warns", g.menus.current == "confirm" and trial.depth == 0, g.menus.current)
	await r.native._key(KEY_ESCAPE)
	_check("camp_escape_stays_safe", trial.depth == 0 and not g.menus.is_open()
		and not g.get_tree().paused, "Escape returns to camp")


func _has_notice(text: String) -> bool:
	if is_instance_valid(g.hud._ann_active) and g.hud._ann_active.get_meta("message", "") == text:
		return true
	for notice in g.hud._ann_queue:
		if notice.text == text: return true
	return false
