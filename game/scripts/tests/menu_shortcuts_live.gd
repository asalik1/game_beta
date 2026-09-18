extends RefCounted
## Optional continuation of the real capital arrival; no actor/physics loans.
var q
var g: Game
var m: Menus
var held: Array[int] = []
var seen: Array[int] = []
var observations: Array[Dictionary] = []
var failures := 0


static func run(parent: RefCounted) -> Dictionary:
	var probe := new()
	probe.q = parent
	probe.g = parent.g
	probe.m = parent.g.menus
	var binds: Dictionary = probe.g.binds.duplicate(true)
	var economy: Dictionary = parent._fountain_economy()
	var error: String = await probe._exercise(binds)
	for code: int in probe.held.duplicate(): probe._edge(code, false)
	parent.held_key = 0
	# Setup-only editors and any failed-case overlay are disposable. No action,
	# purchase, actor pose, health or resource value is restored over an error.
	probe.g.hud.cancel_conversation()
	if probe.m.is_open(): probe.m.close()
	probe.g.request_pause(false)
	probe.g.binds = binds
	# Keybind capture writes isolated settings even while character saves are off.
	probe.g.save_binds()
	probe._check("persisted_binds", probe._stored_binds_match(binds), "restored primary user://keybinds.json; isolated backups retained")
	await parent.r.frames(3)
	probe._check("resources", parent._fountain_economy() == economy, "bind loan restored; resources unchanged")
	var released := probe.held.is_empty()
	for code: int in probe.seen: released = released and not Input.is_key_pressed(code)
	probe._check("released", released, "every recorded key is actually up")
	return {"error": error if error != "" else "shortcut checks failed" if probe.failures else "",
		"failures": probe.failures, "observations": probe.observations,
		"scope": "Real capital arrival and selected Voss. Native synchronous menu taps, held/echo controls, real keybind capture and actual editable field. Remap/editor setup is controlled; no actor pose, physics or resources changed; character saves disabled, isolated keybind settings written and primary bindings restored. Ambiguous bindings retain held-state policy; no short-tap guarantee for them. Solo native renderer only; no physical-device/ENet/menu-motion claim.",
		"sources": {"game": FileAccess.get_sha256("res://scripts/game.gd"),
			"helper": FileAccess.get_sha256("res://scripts/tests/menu_shortcuts_live.gd"),
			"menus": FileAccess.get_sha256("res://scripts/menus.gd")}}


func _stored_binds_match(expected: Dictionary) -> bool:
	if not FileAccess.file_exists("user://keybinds.json"): return false
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://keybinds.json"))
	if not stored is Dictionary or stored.size() != expected.size(): return false
	for action in expected:
		if not stored.has(action) or not (stored[action] is int or stored[action] is float): return false
		if float(stored[action]) != float(expected[action]): return false
	return true


func _check(id: String, okay: bool, detail: Variant) -> bool:
	if not okay: failures += 1
	return q._check("shortcuts." + id, okay, detail)


func _ready_for_open(id: String) -> bool:
	var end := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < end:
		if g.play_started and g.state == Game.ST_PLAYING and g.has_local_player() \
				and not g.input_overlay_up() and not g.get_tree().paused and g.talk_cd <= 0.0:
			return _check(id + ".ready", true, q._input_state())
		await q.r.frames(1)
	return _check(id + ".ready", false, q._input_state())


func _edge(code: int, down: bool, echo := false, character := 0) -> void:
	if not seen.has(code): seen.append(code)
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = character
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if down and not held.has(code): held.append(code)
	if not down: held.erase(code)


func _tap(code: int, character := 0) -> Dictionary:
	var record := {"code": code, "process": Engine.get_process_frames(), "physics": Engine.get_physics_frames()}
	_edge(code, true, false, character)
	record["down_seen"] = Input.is_key_pressed(code)
	_edge(code, false, false, character)
	record["released"] = not Input.is_key_pressed(code)
	record["process_after"] = Engine.get_process_frames()
	record["physics_after"] = Engine.get_physics_frames()
	q.ui.key_taps += 1
	return record


func _short_open(code: int, menu: String, id: String) -> bool:
	if not await _ready_for_open(id): return false
	await RenderingServer.frame_post_draw
	var record := _tap(code)
	record["id"] = id
	record["immediate_menu"] = m.current
	observations.append(record)
	_check(id + ".same_frame", record.down_seen and record.released
		and record.process == record.process_after and record.physics == record.physics_after, record)
	_check(id + ".open", m.is_open() and m.current == menu, record)
	await q.r.frames(3)
	_check(id + ".settled", m.is_open() and m.current == menu, m.current)
	return true # A product failure remains strict but does not skip other cases.


func _back_to_play(id: String) -> bool:
	for attempt in range(4):
		if not m.is_open(): break
		await q.ui._key(KEY_ESCAPE)
	return await _ready_for_open(id)


func _shot(name: String) -> void:
	await q.r.frames(2)
	await RenderingServer.frame_post_draw
	q.r.shot(name, "native menu shortcut input; controlled bind/editor setup; no character saves; isolated keybind settings writes")


func _exercise(original: Dictionary) -> String:
	if not _check("isolated", g.no_saves and not g.net_online() and not q.r.flag("baseline")
		and not q.r.flag("no-capture"), "strict solo continuation; character saves disabled; isolated keybind settings allowed"):
		return "shortcut fixture prerequisites absent"
	for spec in [["inventory", "03_inventory"], ["skills", "04_skills"], ["codex", "05_codex"], ["map", "06_map"]]:
		var action: String = spec[0]
		var code := int(original.get(action, KEY_M))
		if not await _short_open(code, action, action): return "normal menu readiness failed"
		await _shot(spec[1])
		if m.is_open():
			_tap(code) # Existing matching-key close must own this same event.
			_check(action + ".toggle_closed", not m.is_open(), m.current)
			_tap(code) # A new press inside close's real cooldown must be discarded.
			_check(action + ".cooldown", not m.is_open() and g.talk_cd > 0.0, g.talk_cd)
		if not await _back_to_play(action + ".returned"): return "menu did not return to play"
		_check(action + ".no_late_open", not m.is_open(), m.current)
	# Independent long-press positive and hold-through-Escape control.
	var key := int(original.inventory)
	_edge(key, true)
	q.held_key = key
	await q.r.frames(3)
	_check("held.positive", m.current == "inventory" and m.is_open(), m.current)
	var instance := m.root.get_instance_id() if m.root != null else 0
	for repeat in range(3):
		_edge(key, true, true)
		await q.r.frames(1)
	_check("held.echo", m.root != null and m.root.get_instance_id() == instance, "echo leaves actual open screen intact")
	_tap(KEY_ESCAPE)
	await g.get_tree().create_timer(0.65, true, false, true).timeout
	_check("held.no_reopen", not m.is_open(), m.current)
	_edge(key, false)
	q.held_key = 0
	if not await _back_to_play("held.returned"): return "held control could not return"
	if not await _short_open(key, "inventory", "fresh"): return "fresh key not ready"
	if not await _back_to_play("fresh.returned"): return "fresh key did not return"
	# Setup opens the accepted Keybinds UI; the change itself is native capture.
	m.open_keybinds()
	await q.r.frames(3)
	if not await q.ui._button("Inventory"): return "actual Inventory binding button unavailable"
	_tap(KEY_B)
	_check("remap.capture", int(g.binds.inventory) == KEY_B and m.current == "keybinds", g.binds)
	if not await _back_to_play("remap.ready"): return "keybind screen did not close"
	_tap(key)
	await q.r.frames(3)
	_check("remap.old_key", not m.is_open(), m.current)
	if not await _short_open(KEY_B, "inventory", "remap"): return "remapped input not ready"
	await _shot("07_remapped")
	if not await _back_to_play("remap.returned"): return "remapped screen did not close"
	# Equal menu bindings retain the original Inventory-before-Skills ordering.
	g.binds.skills = KEY_B
	if not await _short_open(KEY_B, "inventory", "duplicate"): return "duplicate menu binding not ready"
	if not await _back_to_play("duplicate.returned"): return "duplicate menu screen did not close"
	g.binds = original.duplicate(true)
	# Fixed Space and dynamic target collisions retain their held-key route.
	# No target is assigned: these controls prove menu dispatch, not target cycling.
	for code: int in [KEY_SPACE, int(original.target)]:
		g.binds.inventory = code
		if not await _ready_for_open("conflict.%d" % code): return "conflict control not ready"
		await RenderingServer.frame_post_draw
		_tap(code)
		await q.r.frames(3)
		_check("conflict.%d.short_not_promised" % code, not m.is_open(), m.current)
		_edge(code, true)
		q.held_key = code
		await q.r.frames(3)
		_check("conflict.%d.held" % code, m.is_open() and m.current == "inventory", m.current)
		_edge(code, false)
		q.held_key = 0
		if not await _back_to_play("conflict.%d.returned" % code): return "conflicting held menu did not close"
	g.binds = original.duplicate(true)
	# The real original Voss is still selected after the unchanged capital route.
	var selected := false
	for entry: Dictionary in g.interactables:
		if is_instance_valid(entry.get("prompt")) and entry.prompt.is_visible_in_tree():
			selected = String(entry.node.get_meta("quest_convo", "")) == "cap_voss"
	if not _check("interact.voss", selected, "naturally selected Voss; no assigned actor pose"):
		return "Voss selection unavailable"
	g.binds.inventory = int(original.interact)
	if not await _ready_for_open("interact"): return "interact collision not ready"
	_edge(int(original.interact), true)
	q.held_key = int(original.interact)
	await q.r.frames(3)
	_edge(int(original.interact), false)
	q.held_key = 0
	var conversation := g.hud.choices_active and g.hud.speaker_label.text == "Clerk Voss"
	_check("interact.priority", conversation and not m.is_open(), "real E -> Voss, not Inventory")
	_tap(int(original.codex))
	_check("overlay.blocked", conversation and not m.is_open(), m.current)
	await _shot("08_interact_priority")
	var leave: Label
	for label in g.hud.choice_option_labels:
		if label.is_visible_in_tree() and label.text.ends_with("(Leave)"): leave = label
	if not _check("interact.leave", is_instance_valid(leave), "actual Leave option"):
		return "actual Voss Leave unavailable"
	await q.ui._mouse(leave.get_global_rect().get_center())
	g.binds = original.duplicate(true)
	if not await _ready_for_open("overlay.returned"): return "dialogue did not return"
	_check("overlay.no_late_open", not m.is_open(), m.current)
	# Disposable editor setup; native typing is the actual negative witness.
	m.open_rename(0, "")
	await q.r.frames(3)
	var field: LineEdit = q.ui._field(m.root)
	if not _check("editor.actual_field", field != null, "accepted editable rename LineEdit"):
		return "editable field unavailable"
	await q.ui._mouse(field.get_global_rect().get_center())
	field.select_all()
	for character in "itcm": _tap(character.to_upper().unicode_at(0), character.unicode_at(0))
	await q.r.frames(3)
	_check("editor.typing", is_instance_valid(field) and field.text == "itcm" and m.current == "rename", m.current)
	await _shot("09_editable")
	return ""
