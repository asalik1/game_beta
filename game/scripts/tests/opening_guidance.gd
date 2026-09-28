extends RefCounted
## Quick-tier opening contracts. Each entry point snapshots what it borrows,
## runs its asserts in a helper and restores in the entry itself: a runtime
## error inside the asserts aborts only the helper, so no held key, lent HUD
## state or story flag can leak into the next autotest section.


static func run(g: Game) -> String:
	var binds_before: Dictionary = g.binds.duplicate(true)
	var touch_before: bool = g.touch_mode
	var pad_before: bool = g.gamepad.active
	var flags_before: Dictionary = g.flags.duplicate(true)
	var talked_before: bool = g.talked_to_elder
	var quest_before: String = g.quest_key
	var chapter_before: String = g.chapter_id
	var convo_before: Dictionary = g.convo_log.duplicate(true)
	var convo_order_before: Array = g.convo_log_order.duplicate()
	var history_before: Array = g.hud._dialogue_history.duplicate(true)
	var speaker_before: String = g.hud.speaker_label.text
	var text_before: String = g.hud.text_label.text
	var auto_t_before: float = g.hud._auto_t
	var auto_dwell_before: float = g.hud._auto_dwell
	var dialogue_before: bool = g.hud.dialogue_active
	var paused_before: bool = g.get_tree().paused
	var failures: Array[String] = []
	var finished: Variant = _run_asserts(g, failures)
	if finished != true:
		failures.append("opening guidance checks stopped early")
	if not dialogue_before and g.hud.dialogue_active:
		g.hud.cancel_conversation()
	g.hud._finish_reveal()
	g.hud._dialogue_history = history_before
	g.hud.speaker_label.text = speaker_before
	g.hud.text_label.text = text_before
	g.hud._auto_t = auto_t_before
	g.hud._auto_dwell = auto_dwell_before
	g.get_tree().paused = paused_before
	g.convo_log = convo_before
	g.convo_log_order = convo_order_before
	g.binds = binds_before
	g.touch_mode = touch_before
	g.gamepad.active = pad_before
	g.flags = flags_before
	g.talked_to_elder = talked_before
	g.quest_key = quest_before
	g.chapter_id = chapter_before
	g.refresh_quest_marks()
	return "; ".join(failures)


static func _run_asserts(g: Game, failures: Array[String]) -> bool:
	g.touch_mode = false
	g.gamepad.active = false
	g.binds["potion"] = KEY_Z
	g.binds["interact"] = KEY_F
	g.binds["skills"] = KEY_Q
	if g.touchify("Press Q when your wounds are grave.") != "Press Z when your wounds are grave.":
		failures.append("dialogue potion key ignores remap")
	if g.touchify("walk up to her and press E") != "walk up to her and press F":
		failures.append("dialogue interact key ignores remap")
	if g.touchify("Hold T, hold Q, press ESC, press Space") != "Hold Q, hold Z, press ESC, press Space":
		failures.append("key tokens cascade or rewrite fixed keys")
	if g.touchify("E — Talk to Tovin") != "F — Talk to Tovin":
		failures.append("keyboard prop prompt ignores the Interact remap")
	g.binds["interact"] = KEY_Q
	g.binds["potion"] = KEY_E
	if g.touchify("Press E, then press Q") != "Press Q, then press E":
		failures.append("swapped bindings rewrite each other's replacement")
	# The Journal transcript rewrites archived lines for the current controls.
	# With Potion on E and Interact on F, archiving the displayed "Press E"
	# would make that second rewrite name Interact instead of Potion.
	g.binds["interact"] = KEY_F
	if g.hud.dialogue_active or g.hud.choices_active:
		failures.append("transcript check started over an open conversation")
	else:
		g.convo_log = {}
		g.convo_log_order = []
		g.hud.dialogue([["Narrator", "Press Q when your wounds are grave."]])
		var shown: String = g.hud.text_label.text
		g.hud.cancel_conversation()
		g.request_pause(false)
		var archived: Array = []
		for bucket in g.convo_log.values():
			archived.append_array(bucket["lines"])
		if shown != "Press E when your wounds are grave." or archived.size() != 1 \
				or g.touchify(String(archived[0][1])) != shown:
			failures.append("story transcript names a different key than the dialogue")
	g.binds["interact"] = KEY_DOLLAR
	if g.touchify("Press E") != "Press " + OS.get_keycode_string(KEY_DOLLAR).to_upper():
		failures.append("literal remapped key is treated as a regex replacement")
	g.touch_mode = true
	if g.touchify("walk up to her and press E") != "walk up to her and tap Act" \
			or g.touchify("Press Q") != "Tap the potion button":
		failures.append("touch instructions regressed")
	g.touch_mode = false
	g.gamepad.active = true
	if g.touchify("Press Q") != "Press " + g.gamepad.label("potion"):
		failures.append("controller instruction regressed")
	g.gamepad.active = false
	g.talked_to_elder = false
	g.flags.erase("met_elder")
	g.quest_key = "talk"
	g.refresh_quest_marks()
	var mark: Label = null
	for child in g.elder.get_children():
		if child is Label and child.text == "❢":
			mark = child
	if mark == null or not mark.visible:
		failures.append("fresh Maren has no visible objective marker")
	if mark != null:
		g.talked_to_elder = true
		g.refresh_quest_marks()
		if mark.visible: failures.append("Maren marker survives conversation")
		g.talked_to_elder = false
		g.flags["met_elder"] = true
		g.refresh_quest_marks()
		if mark.visible: failures.append("Maren marker ignores shared story flag")
		g.flags.erase("met_elder")
		g.quest_key = "fangmaw"
		g.refresh_quest_marks()
		if mark.visible: failures.append("Maren marker survives a later objective")
		g.quest_key = "talk"
		g.chapter_id = "ch2"
		g.refresh_quest_marks()
		if mark.visible: failures.append("Maren marker leaks into later chapters")
	return true


static func gate_checks(g: Game) -> String:
	var key: String = g._edge_key(0, 2)
	var dir: String = preload("res://scripts/ui/navigation.gd").direction(g, 0, 2)
	if dir == "" or not g.edge_locks.has(key) or not g.gates.has(key):
		return "fresh village is missing its barred road edge"
	var p: Player = g.local_player
	var pos_before := p.global_position
	var intents_before := {}
	for field in ["intent_move", "intent_a1", "intent_a2", "intent_a3", "intent_ult", "intent_potion", "intent_potion_next", "intent_interact"]:
		intents_before[field] = p.get(field)
	var keys_before := {}
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: keys_before[code] = Input.is_key_pressed(code)
	var dead_before := p.dead
	var cd_before := g.gate_bump_cd
	var binds_before: Dictionary = g.binds.duplicate(true)
	var flags_before: Dictionary = g.flags.duplicate(true)
	var locks_before: Dictionary = g.edge_locks.duplicate(true)
	var quest_before := g.quest_key
	var chapter_before := g.chapter_id
	var touch_before := g.touch_mode
	var pad_before: bool = g.gamepad.active
	var chat_before := g.hud.chat_active
	var started_before := g.play_started
	var boss_bar_before: bool = g.hud.boss_box.visible
	var rows_before: Array = g.hud._log_lines.duplicate()
	var queue_before: Array[Dictionary] = g.hud._ann_queue.duplicate(true)
	var plaque_before: Panel = g.hud._ann_active
	var tween_before: Tween = g.hud._ann_tween
	# Synchronous fixture: hold announcements in their normal queue and lend
	# an empty log so no existing row can be evicted. No frame/tween advances.
	var sentinel := Panel.new()
	g.hud._ann_active = sentinel
	g.hud._ann_tween = null
	g.hud._log_lines = []
	var failures: Array[String] = []
	var finished: Variant = _gate_asserts(g, key, dir, failures)
	if finished != true:
		failures.append("gate guidance checks stopped early")
	for code in keys_before:
		_key(int(code), false)
	_drain_log(g)
	g.hud._log_lines = rows_before
	g.hud._layout_log()
	g.hud._ann_queue = queue_before
	g.hud._ann_active = plaque_before
	g.hud._ann_tween = tween_before
	sentinel.free()
	g.hud.boss_box.visible = boss_bar_before
	g.hud.chat_active = chat_before
	g.play_started = started_before
	g.binds = binds_before
	g.flags = flags_before
	g.edge_locks = locks_before
	g.quest_key = quest_before
	g.chapter_id = chapter_before
	g.touch_mode = touch_before
	g.gamepad.active = pad_before
	g.gate_bump_cd = cd_before
	p.global_position = pos_before
	for code in keys_before:
		_key(int(code), bool(keys_before[code]))
	for field in intents_before:
		p.set(field, intents_before[field])
	p.dead = dead_before
	return "; ".join(failures)


static func _gate_asserts(g: Game, key: String, dir: String, failures: Array[String]) -> bool:
	var outward := Vector2(g.DIRS[dir])
	var forward_key: int = {"N": KEY_W, "S": KEY_S, "E": KEY_D, "W": KEY_A}[dir]
	var away_key: int = {"N": KEY_S, "S": KEY_W, "E": KEY_A, "W": KEY_D}[dir]
	var p: Player = g.local_player
	g.touch_mode = false
	g.gamepad.active = false
	g.binds["interact"] = KEY_F
	g.flags.erase("met_elder")
	g.quest_key = "talk"
	g.gate_bump_cd = 0.0
	g.play_started = true
	g.hud.boss_box.visible = false
	p.dead = false
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _key(code, false)
	var at_gate: Vector2 = g.door_pos(0, dir) - outward * 72.0
	p.global_position = at_gate
	g._tick_gate_guidance(0.0)
	if not g.hud._log_lines.is_empty(): failures.append("idle player triggers gate guidance")
	_key(away_key, true)
	g._tick_gate_guidance(0.0)
	_key(away_key, false)
	if not g.hud._log_lines.is_empty(): failures.append("walking away triggers gate guidance")
	_key(forward_key, true)
	p.global_position = at_gate - outward * 300.0
	g._tick_gate_guidance(0.0)
	if not g.hud._log_lines.is_empty(): failures.append("distant gate triggers guidance")
	p.global_position = at_gate
	g.hud.chat_active = true
	g._tick_gate_guidance(0.0)
	g.hud.chat_active = false
	p.dead = true
	g._tick_gate_guidance(0.0)
	p.dead = false
	g.play_started = false
	g._tick_gate_guidance(0.0)
	g.play_started = true
	if not g.hud._log_lines.is_empty(): failures.append("overlay/dead/unstarted player triggers guidance")
	g._tick_gate_guidance(0.0)
	if g.hud._log_lines.size() != 1:
		failures.append("walking into gate did not produce exactly one notice")
	elif not _last_line(g).contains("Maren") or not _last_line(g).contains("press F"):
		failures.append("gate notice lost the objective or live binding")
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN * 0.5)
	if g.hud._log_lines.size() != 1: failures.append("gate guidance repeats during cooldown")
	g.touch_mode = true
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 2 or not _last_line(g).contains("tap Act"):
		failures.append("gate guidance does not resume with touch copy after cooldown")
	g.touch_mode = false
	g.gamepad.active = true
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 3 or not _last_line(g).contains("press " + g.gamepad.label("interact")):
		failures.append("gate guidance lost controller copy")
	g.gamepad.active = false
	# Second phase from an empty log and queue: the log keeps only five rows.
	_drain_log(g)
	g.hud._ann_queue.clear()
	var own: int = g.room_at_pos(at_gate)
	var other: int = 2 if own == 0 else 0
	# A PvP gatehouse opens on the duel countdown; story copy would mislead.
	g.edge_locks[key] = {"lock": "flag:pvp_gates", "own": own}
	g.flags.erase("pvp_gates")
	var chapter := g.chapter_id
	g.chapter_id = "pvp_arena"
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	g.chapter_id = chapter
	if not g.hud._log_lines.is_empty(): failures.append("PvP gatehouse tells duelists to continue the story")
	g.edge_locks[key] = {"lock": "flag:opening_guidance_test", "own": own}
	g.flags.erase("opening_guidance_test")
	# The plaque waits out a boss bar, so a notice would play after the kill.
	g.hud.boss_box.visible = true
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	g.hud.boss_box.visible = false
	if not g.hud._log_lines.is_empty(): failures.append("gate guidance queues behind a boss bar")
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 1 or not _last_line(g).contains("Continue the story"):
		failures.append("generic gate lost navigation lock reason")
	elif g.hud._ann_queue.size() != 1 or String(g.hud._ann_queue[0]["kind"]) != "note":
		failures.append("barred-gate notice is not announced as a neutral note")
	# Paired shortcut: the latch stands in its own room, beside that mouth.
	g.edge_locks[key] = {"lock": "flag:shortcut_opening_guidance_test", "own": own}
	g.flags.erase("shortcut_opening_guidance_test")
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 2 or not _last_line(g).contains("winch beside this gate"):
		failures.append("latch-side shortcut notice sends the player to find the latch")
	g.edge_locks[key] = {"lock": "flag:shortcut_opening_guidance_test", "own": other}
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 3 or not _last_line(g).contains("far-side latch"):
		failures.append("near-side shortcut notice lost the far-side latch reason")
	g.edge_locks[key] = {"lock": "flag:met_elder", "own": own}
	g.flags["met_elder"] = true
	g._tick_gate_guidance(Balance.GATE_BUMP_COOLDOWN)
	if g.hud._log_lines.size() != 3: failures.append("unlocked gate still gives guidance")
	_key(forward_key, false)
	return true


## Free the fixture's own log rows (the lent array, never the player's rows).
static func _drain_log(g: Game) -> void:
	for row in g.hud._log_lines:
		if not is_instance_valid(row): continue
		var motion: Tween = row.get_meta("tween", null)
		if motion != null and motion.is_valid(): motion.kill()
		(row as Node).free()
	g.hud._log_lines = []


static func _last_line(g: Game) -> String:
	if g.hud._log_lines.is_empty(): return ""
	return (g.hud._log_lines.back().get_meta("label") as Label).text


static func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
