extends RefCounted
## Eight real healing entrypoints in the existing isolated boss-cast rig.
const CASES := ["vamp_partial", "vamp_full", "hunger", "incense", "son", "drowse", "compost", "roots", "reset"]
var r: Node
var g: Game
var p: Player
var rows: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var saved := {}
var adds: Array[Enemy] = []
var baseline := false


static func run(rig: Node) -> String:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	probe.baseline = rig.flag("baseline")
	return await probe._run()


func _check(id: String, ok: bool, detail: Variant, expected_old := false) -> void:
	var status := "pass" if ok else "baseline_finding" if baseline and expected_old else "fail"
	rows.append({"id": id, "status": status, "detail": detail})
	print("HOST HEAL ", id, ": ", status)


func _bar(e: Enemy) -> Dictionary:
	return {"kind": e.kind, "hp": e.hp, "max_hp": e.max_hp, "fraction": e.hp / e.max_hp,
		"fill": e.hp_bar_fg.size.x, "cap_x": e.hp_bar_cap.position.x,
		"bg": e.hp_bar_bg.visible, "fg": e.hp_bar_fg.visible, "cap": e.hp_bar_cap.visible,
		"dying": e.dying, "position": [e.global_position.x, e.global_position.y]}


func _hidden(state: Dictionary) -> bool:
	return not state.bg and not state.fg and not state.cap


func _geometry(id: String, e: Enemy, expected_old := false) -> void:
	var state := _bar(e)
	var width := Enemy.HP_BAR_W * clampf(e.hp / e.max_hp, 0.0, 1.0)
	_check(id + ".visible", state.bg and state.fg and state.cap and not e.dying, state)
	_check(id + ".fill", is_equal_approx(float(state.fill), width), state, expected_old)
	_check(id + ".cap", is_equal_approx(float(state.cap_x), -Enemy.HP_BAR_W * 0.5 + width - 1.0), state, expected_old)


func _healed(id: String, e: Enemy, before: Dictionary, amount: float, cause: String) -> void:
	var expected := minf(e.max_hp, float(before.hp) + amount)
	var after := _bar(e)
	observations.append({"id": id, "cause": cause, "before": before, "after": after, "expected_hp": expected})
	_check(id + ".actual_heal", e.hp > float(before.hp) and is_equal_approx(e.hp, expected), observations.back())
	_geometry(id, e, true)


func _wound(e: Enemy, amount: float, id: String) -> void:
	var before := e.hp
	e.hit_src = p
	e.take_damage(amount, Vector2.ZERO, false, true)
	_check(id + ".actual_wound", is_equal_approx(e.hp, before - amount) and not e.dying, _bar(e))
	_geometry(id, e)


func _run() -> String:
	r.shot_dir = String(r.shot_dir).path_join("healing")
	_check("fresh", g.no_saves and not g.net_online() and not g.dev_god and not p.dead
		and not p.downed and not p.ghost and p.equipment.is_empty(), "offline fresh no-save local-owner fixture")
	for key in ["hp", "mp", "shield", "eva", "hurt_cd", "hurt_was_heavy", "velocity", "global_position",
			"locked_target", "soft_target", "frozen_time", "slow_time", "since_hurt", "grit_stacks", "grit_time"]:
		saved[key] = p.get(key)
	saved["settings"] = g.settings.duplicate(true)
	saved["party_stats"] = g.party_stats.duplicate(true)
	saved["fight_stats"] = g.fight_stats.duplicate(true)
	g.settings["touch_controls"] = r.flag("touch")
	g.refresh_touch_mode()
	g._apply_touch_mode()
	p.hp = p.max_hp  # Player setup only; no enemy heal is assigned by this helper.
	p.eva = 0.0
	p.velocity = Vector2.ZERO
	p.frozen_time = 0.0
	await _vamp()
	await _boss_cases()
	var actual: Array[String] = []
	var expected: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": actual.append(String(row.id))
	if baseline:
		for id in CASES:
			expected.append(id + ".fill")
			expected.append(id + ".cap")
	actual.sort()
	expected.sort()
	_check("baseline_exact", actual == expected, {"actual": actual, "expected": expected})
	for key in saved:
		if key not in ["settings", "party_stats", "fight_stats"]: p.set(key, saved[key])
	g.settings = saved.settings
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.party_stats = saved.party_stats
	g.fight_stats = saved.fight_stats
	_check("player_restored", p.hp == saved.hp and p.shield == saved.shield and p.eva == saved.eva,
		"borrowed scalar fields/settings restored; disposable world and feedback history are not resumed")
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var receipt := {"baseline": baseline, "rows": rows, "cases": observations,
		"failures": failures, "findings": actual.size(), "complete": failures == 0,
		"scope": "Static scenery retained; wolf posed clear of the keep chest, transient text allowed to expire. Isolated keep scene, frozen actors, controlled real wounds and direct production healing methods. Six boss heals plus reset and local-owner Vampiric attacker; no HP assignment heals enemies. Adds spawned through real factories, then posed/frozen. Seeded Drowse and borrowed generic reset windup are disclosed controls. No ordinary AI/earned encounter, guest-victim authority, replication, rewards or physical-device claim."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(r.shot_dir)))
	var file := FileAccess.open(String(r.shot_dir).path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "Cannot write host healing receipt"
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("HOST HEALING: checks=%d failures=%d findings=%d complete=%s" % [rows.size(), failures, actual.size(), failures == 0])
	return "" if failures == 0 else "Host healing controls failed: %d" % failures


func _vamp() -> void:
	r.step("local-owner Vampiric actual damage and healing")
	var e := Enemy.make(g, "wolf", p.global_position + Vector2(180, -100), 1, 1.0)
	Endgame.apply_affix(e, "vampiric")
	g.add_enemy(e)
	e.set_physics_process(false)
	e.crit = 0.0
	p.locked_target = e
	p.soft_target = e
	_check("vamp.pristine", e.traits.has("lifesteal") and _hidden(_bar(e)), _bar(e))
	_wound(e, 9.0, "vamp.wound")
	await _shot("vamp_wounded", e)
	for id in ["vamp_partial", "vamp_full"]:
		p.hurt_cd = 0.0
		p.hurt_was_heavy = false
		p.shield = 0.0
		var before := _bar(e)
		var player_hp := p.hp
		p.take_damage(20.0, "true", e)
		var debit := player_hp - p.hp
		_check(id + ".real_player_damage", debit > 0.0 and not p.dead, {"debit": debit, "player_hp": p.hp})
		_healed(id, e, before, debit * Balance.AFFIX_LIFESTEAL_FRAC, "Player.take_damage actual post-mitigation/shield debit")
		_check(id + ".expected_stage", e.hp < e.max_hp if id == "vamp_partial" else is_equal_approx(e.hp, e.max_hp), _bar(e))
		await _shot(id, e)
	_wound(e, 4.0, "vamp.wounded_again")
	p.hurt_cd = 0.0
	p.shield = 100.0
	var before_absorb := _bar(e)
	var hero_hp := p.hp
	p.take_damage(20.0, "true", e)
	_check("vamp.shield_no_heal", p.hp == hero_hp and p.shield < 100.0 and _bar(e) == before_absorb,
		{"before": before_absorb, "after": _bar(e), "player_hp": p.hp, "shield": p.shield})
	e.hit_src = p
	e.take_damage(e.hp + 1.0, Vector2.ZERO, false, true)
	_check("vamp.death_hidden", e.dying and _hidden(_bar(e)), _bar(e))
	p.locked_target = null
	p.soft_target = null
	# Let the real deferred death accounting consume its still-live actor first.
	await r.frames(2)
	if is_instance_valid(e): e.queue_free()
	await r.frames(2)
	p.shield = 0.0


func _new_boss(kind: String) -> Boss:
	var b: Boss = r._boss(kind)
	b.attack_cd = 1000.0
	_check(kind + ".pristine_hidden", _hidden(_bar(b)), _bar(b))
	_wound(b, b.max_hp * 0.20, kind + ".wound")
	return b


func _own_adds(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.set_physics_process(false)
			if not adds.has(node): adds.append(node)


func _remove(b: Boss) -> void:
	# Compost checks run synchronously; drain death callbacks before add cleanup.
	await r.frames(2)
	for e in adds:
		if is_instance_valid(e): e.queue_free()
	adds.clear()
	r._remove_boss(b)
	await r.frames(2)
	await g.get_tree().create_timer(1.0, false).timeout


func _boss_cases() -> void:
	r.step("six boss healing methods and reset")
	var b := _new_boss("choirmother")
	var before := _bar(b)
	b._hymn_of_hunger()
	_healed("hunger", b, before, b.max_hp * Balance.BOSS_HUNGER_HEAL, "_hymn_of_hunger; unrelated telegraph dmg0 and cancelled")
	g.cancel_ground_attacks()
	await _remove(b)
	b = _new_boss("saint_varo")
	b._spawn_censers()
	_own_adds(b.censers)
	b.varo_setup = true
	_check("incense.live_censer", not b.censers.is_empty() and not b.censers[0].dying, b.censers.size())
	before = _bar(b)
	b._saint_varo(p, p.global_position - b.global_position, 240.0, 1.0)
	_healed("incense", b, before, b.max_hp * 0.015, "_saint_varo delta1 with real living censer")
	b.censers.clear()
	var held := _bar(b)
	b._saint_varo(p, p.global_position - b.global_position, 240.0, 1.0)
	_check("incense.absent_no_change", _bar(b) == held, {"before": held, "after": _bar(b)})
	await _remove(b)
	b = _new_boss("ashpriest")
	b._spawn_sons()
	_own_adds(b.sons)
	_check("son.real_spawn", b.sons.size() == 4, b.sons.size())
	var son: Enemy = b.sons[0]
	for i in range(1, b.sons.size()): b.sons[i].queue_free()
	b.sons = [son]
	son.global_position = b.global_position + Vector2(60, 0)
	await _shot("ordo_wounded", b)
	before = _bar(b)
	var old_speed := b.verdict_speed
	b._march_sons(0.0)
	_healed("son", b, before, b.max_hp * 0.08, "_march_sons consumes actual spawned Son posed within90px")
	_check("son.consumed", son.is_queued_for_deletion() and b.sons.is_empty()
		and is_equal_approx(b.verdict_speed, minf(2.5, old_speed + 0.15)), b.verdict_speed)
	await _shot("ordo_consumed_son", b)
	b.global_position += Vector2(35, 0)
	var old_serial := b._fight_serial
	# Ordo has no breakable signature. Seed the existing generic cast state to
	# test reset cancellation, explicitly not an authored Ordo ability.
	_check("reset.borrowed_windup", b.cast_window.start("morwen", b.max_hp), "generic reset cancellation prerequisite")
	before = _bar(b)
	b.reset_fight()
	_healed("reset", b, before, b.max_hp, "reset_fight actual full refill, relocation and generic cast cancellation")
	_check("reset.lifecycle", b.global_position == b.home and b._fight_serial == old_serial + 1
		and b.cast_window.phase == "", {"serial": b._fight_serial, "position": str(b.global_position), "home": str(b.home)})
	await _shot("ordo_reset_full", b)
	await _remove(b)
	b = _new_boss("sleepkeeper")
	b.ch5_setup = true
	b.dreamer_t = 1000.0
	b.still_map[p.get_instance_id()] = 1.5
	p.velocity = Vector2.ZERO
	p.frozen_time = 0.0
	before = _bar(b)
	b._sleepkeeper(p, p.global_position - b.global_position, 240.0, 1.0 / 60.0)
	_check("drowse.seeded_one", b.drowse == 1, "one Drowse accumulator seeded; no natural stillness timing claim")
	_healed("drowse", b, before, b.max_hp * 0.008 / 60.0, "_sleepkeeper oneDrowse delta1/60")
	await _remove(b)
	b = _new_boss("gardener")
	b._sprout_blooms()
	_own_adds(b.blooms)
	_check("compost.real_blooms", not b.blooms.is_empty(), b.blooms.size())
	var bloom: Enemy = b.blooms[0]
	for i in range(1, b.blooms.size()): b.blooms[i].queue_free()
	b.blooms = [bloom]
	bloom.global_position = b.global_position + Vector2(60, 0)
	bloom.hit_src = p
	bloom.take_damage(bloom.hp + 1.0, Vector2.ZERO, false, true)
	_check("compost.actual_death", bloom.dying, "real spawned bloom killed through take_damage")
	before = _bar(b)
	b._tend_blooms()
	_healed("compost", b, before, b.max_hp * 0.04, "_tend_blooms actual nearby dying bloom")
	_check("compost.consumed", b.blooms.is_empty(), b.blooms.size())
	await _remove(b)
	b = _new_boss("curetwisted")
	b.form = 1
	b._spawn_roots()
	_own_adds(b.roots)
	_check("roots.actual_spawn", b.roots.size() == 2 and not b.roots[0].dying, b.roots.size())
	before = _bar(b)
	b._kaethra_bloom(p, p.global_position - b.global_position, 240.0, 1.0)
	_healed("roots", b, before, b.max_hp * 0.02, "_kaethra_bloom delta1 with real roots")
	b.roots.clear()
	held = _bar(b)
	b._kaethra_bloom(p, p.global_position - b.global_position, 240.0, 1.0)
	_check("roots.absent_no_change", _bar(b) == held, {"before": held, "after": _bar(b)})
	await _remove(b)
	b = r._boss("ashpriest")
	b.reset_fight()
	_check("reset.pristine_hidden", _hidden(_bar(b)) and b.hp == b.max_hp, _bar(b))
	await _remove(b)


func _shot(label: String, e: Enemy) -> void:
	await r.sim_wait(1.2)
	await RenderingServer.frame_post_draw
	var screen: Rect2 = g.get_viewport().get_visible_rect()
	var bounds: Array = []
	var complete := true
	for sprite in [p.sprite, e.sprite]:
		var rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		complete = complete and sprite.is_visible_in_tree() and rect.has_area() and screen.grow(0.75).encloses(rect)
		bounds.append(str(rect))
	var bar_rect: Rect2 = e.hp_bar_bg.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, e.hp_bar_bg.size)
	complete = complete and e.hp_bar_bg.is_visible_in_tree() and bar_rect.has_area() and screen.encloses(bar_rect)
	_check(label + ".native_bounds", complete, {"bodies": bounds, "bar": str(bar_rect), "viewport": str(screen),
		"limit": "onscreen geometry only; actual HUD overlap/readability requires native image review"})
	r.shot(label, "controlled real healing, frozen actors, no earned encounter or guest-victim authority claim")
