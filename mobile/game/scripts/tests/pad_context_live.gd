extends RefCounted
## Director-authored native follow-up to Claude's source candidate.
## Disposable ShotRig world, lent 120 ms cooldown; no manual context sync or
## physics calls. Same-frame event sequencing is controlled, not an encounter.
var r: ShotRig
var g: Game
var p: Player
var pad: Node
var baseline := false
var rows: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var views: Array[String] = []


static func run(rig: ShotRig) -> String:
	var t := new()
	t.r = rig; t.g = rig.game; t.p = rig.game.local_player
	t.pad = rig.game.gamepad; t.baseline = rig.flag("baseline")
	return await t._run()


func _check(id: String, good: bool, detail: Variant, anticipated := false) -> void:
	rows.append({"id": id, "status": "pass" if good else "baseline_finding" if baseline and anticipated else "fail", "detail": detail})
	print("PAD CONTEXT ", id, ": ", rows.back().status)


func _key(code: int, down: bool) -> void:
	pad.focused = true
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(code: int) -> void:
	_key(code, true); _key(code, false)


func _button(code: JoyButton, down: bool) -> void:
	pad.focused = true
	var e := InputEventJoypadButton.new()
	e.device = 27; e.button_index = code; e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _snap(name: String) -> void:
	views.append(r.shot(name))


func _run() -> String:
	var old_dir := r.shot_dir
	r.shot_dir = old_dir.path_join("pad_context")
	var before := {"hp": p.hp, "xp": p.xp, "gold": p.gold}
	_check("fresh", g.no_saves and not g.net_online() and not g.dev_god and not p.dead
		and not p.downed and not p.ghost and p.is_physics_processing(), "No-save solo; normal local physics and ordinary stats")
	_tap(KEY_F8) # ordinary keyboard handoff; F8 has no normal gameplay action
	await r.frames(2)
	_check("initial_play", g.state == Game.ST_PLAYING and not g.input_overlay_up()
		and pad._context == "play" and not pad.active, {"context": pad._context, "active": pad.active})
	await _ready_control()
	await _entry_control()
	await _held_control()
	await _fresh_case("menu")
	await _fresh_case("dialogue")
	# Every success/failed observation is retained; do not stop at first finding.
	_key(int(g.binds.a1), false)
	_key(KEY_ESCAPE, false); _key(KEY_SPACE, false)
	if g.menus.is_open(): _tap(KEY_ESCAPE)
	_check("unchanged_rewards", p.hp == before.hp and p.xp == before.xp and p.gold == before.gold, before)
	_check("released", not Input.is_key_pressed(int(g.binds.a1)), "Basic key released")
	var findings: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": findings.append(String(row.id))
	var expected: Array[String] = []
	if baseline: expected.assign(["menu.fresh_tap_retained", "dialogue.fresh_tap_retained"])
	_check("exact_findings", findings == expected, {"expected": expected, "actual": findings})
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var receipt := {"complete": failures == 0, "baseline": baseline, "failures": failures,
		"findings": findings, "rows": rows, "observations": observations, "views": views,
		"scope": "Disposable fresh solo Archer in village; basic cooldown lent to 120 ms, a synthetic one-line dialogue and precise close/tap ordering. Normal local physics and normal adapter _process; actual key/pad events; no direct queue_ability, _sync_context, use_ability or damage calls. No ordinary encounter, earned reward, remote authority, physical controller or device claim. Timing prerequisites reject an already-fired or expired input. Raw Claude domain helper is not used."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "cannot write pad-context receipt"
	file.store_string(JSON.stringify(receipt, "\t") + "\n"); file.close()
	r.shot_dir = old_dir
	return "" if failures == 0 else "pad-context strict checks failed: %d" % failures


func _ready_control() -> void:
	_check("ready.affordable", p.mp >= p.ability_cost("a1") and p.frozen_time <= 0.0, {"mp": p.mp, "cost": p.ability_cost("a1")})
	p.cds.a1 = 0.0
	_tap(int(g.binds.a1))
	var fired := false
	var stop := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < stop:
		await r.get_tree().process_frame
		if p.cds.a1 > 0.12: fired = true
	_check("ready.actual_cast", fired and p.action_buffer.pending.is_empty(), "Real released key fires in settled gameplay on both baseline and fixed")
	await r.sim_wait(0.8)


func _entry_control() -> void:
	p.cds.a1 = 0.12 # disclosed timing prerequisite, not a stat grant
	_tap(int(g.binds.a1))
	_check("entry.prequeued", not p.action_buffer.pending.is_empty(), "Real released key before menu entry")
	_tap(KEY_ESCAPE)
	await r.frames(2)
	_check("entry.cancelled", g.menus.current == "pause" and p.action_buffer.pending.is_empty(), {"menu": g.menus.current, "pending": p.action_buffer.pending.duplicate()})
	_tap(int(g.binds.a1))
	_check("entry.rejects_overlay_input", p.action_buffer.pending.is_empty(), "Real tap under an open pause menu")
	_snap("01_entry_clear")
	_tap(KEY_ESCAPE)
	await r.frames(2)


func _held_control() -> void:
	_button(JOY_BUTTON_A, true)
	_check("held.positive", pad.active and pad.held("interact"), "A held in live play before any overlay")
	_button(JOY_BUTTON_START, true); _button(JOY_BUTTON_START, false)
	await r.frames(2)
	_check("held.menu", g.menus.current == "pause" and not pad.held("interact"), "Held controller action gated under menu")
	_button(JOY_BUTTON_B, true); _button(JOY_BUTTON_B, false)
	await r.frames(2)
	_check("held.return_gated", not g.input_overlay_up() and pad.rearm and not pad.held("interact"), "Held A remains gated after close")
	_button(JOY_BUTTON_A, false)
	_check("held.release_rearms", not pad.rearm, "Actual neutral release clears rearm")
	_button(JOY_BUTTON_A, true)
	_check("held.new_press", pad.held("interact"), "Fresh actual controller press works again")
	_button(JOY_BUTTON_A, false)
	_tap(KEY_F8)
	await r.frames(2)
	_check("held.keyboard_handoff", not pad.active and not pad.held("interact"), "Actual keyboard wake")


func _fresh_case(kind: String) -> void:
	if kind == "menu":
		_tap(KEY_ESCAPE)
	else:
		g.hud.dialogue([["", "A controlled return-to-play input check."]])
		g.hud._finish_reveal() # fixture setup; dismissal below remains actual input
	await r.frames(3)
	var old_context: String = pad._context
	_check(kind + ".overlay_observed", g.input_overlay_up() and (old_context.begins_with("menu:") if kind == "menu" else old_context == "dialogue"), old_context)
	_snap("02_" + kind + "_before") # never read back a frame inside the buffer window
	p.cds.a1 = 0.12
	var started := Time.get_ticks_msec()
	_tap(KEY_ESCAPE if kind == "menu" else KEY_SPACE)
	_check(kind + ".actual_close", not g.input_overlay_up() and not r.get_tree().paused, "Actual close event before basic tap")
	_tap(int(g.binds.a1))
	_check(kind + ".queued", p.action_buffer.has_press("a1", Time.get_ticks_msec() * 0.001), p.action_buffer.pending.duplicate())
	_check(kind + ".context_pending", pad._context == old_context and not pad.active, {"cached": pad._context, "old": old_context})
	await RenderingServer.frame_post_draw
	var elapsed := (Time.get_ticks_msec() - started) * 0.001
	var kept: bool = p.action_buffer.pending.has("a1")
	var remaining: float = p.cds.a1
	_check(kind + ".timing", elapsed < Balance.ABILITY_BUFFER_SECONDS and remaining > 0.0 and remaining <= 0.12, {"elapsed": elapsed, "remaining_cd": remaining})
	_check(kind + ".normal_context_poll", pad._context == "play", pad._context)
	_check(kind + ".fresh_tap_retained", kept, {"elapsed": elapsed, "pending": p.action_buffer.pending.duplicate()}, true)
	var cast := false
	var stop := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < stop:
		await r.get_tree().process_frame
		if p.cds.a1 > 0.12: cast = true
	_check(kind + ".cast_outcome", cast == (not baseline), {"cast_observed": cast, "expected": not baseline, "remaining_cd": p.cds.a1})
	_check(kind + ".released_outcome", p.action_buffer.pending.is_empty() and not Input.is_key_pressed(int(g.binds.a1)), "Released tap consumed or baseline loss; no held key")
	observations.append({"id": kind, "elapsed_to_draw": elapsed, "cooldown_at_draw": remaining, "retained": kept, "cast": cast})
	_snap("03_" + kind + "_after")
	await r.sim_wait(0.6)
