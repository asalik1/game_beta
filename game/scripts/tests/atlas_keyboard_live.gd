extends RefCounted
## Candidate only: normal atlas construction, native Tab/Enter and mouse.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const FOOTER_PREFIX := "Select a room · drag to pan · scroll to zoom · "
const TOUCH_FOOTER := "Select a room · drag to pan · use + / − to zoom"
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const GAME_FIELDS := ["cur_room", "visited", "door_seen", "cleared", "boss_done", "flags", "chapter_id", "wander_seed"]
const HERO_FIELDS := ["hp", "mp", "gold", "xp", "level", "resonance", "global_position", "tracked_quest", "equipment", "backpack", "consumables"]
const EXPECTED := ["next/entry", "next/focus", "next/repeat", "previous/entry", "previous/focus", "previous/repeat"]
var r: Node
var g: Game
var m: Menus
var native := Native.new()
var rows: Array[Dictionary] = []
var findings: Array[String] = []
var views: Array[String] = []
var failures := 0
var footer_saved := {}


# Diagnostic only: observes delivered Tab events without consuming them.
class TabObserver extends Node:
	var events: Array[Dictionary] = []
	func _input(event: InputEvent) -> void:
		_record(event, "input")
	func _unhandled_key_input(event: InputEvent) -> void:
		_record(event, "unhandled_key")
	func _record(event: InputEvent, phase: String) -> void:
		if event is InputEventKey and event.keycode == KEY_TAB:
			events.append({"phase": phase, "pressed": event.pressed, "echo": event.echo,
				"keycode": event.keycode, "physical_keycode": event.physical_keycode,
				"matches_focus_next": event.is_action("ui_focus_next"),
				"key_down": Input.is_key_pressed(KEY_TAB), "frame": Engine.get_process_frames()})

var tab_observer: TabObserver
var tab_trace: Array[Dictionary] = []
var focus_trace: Array[Dictionary] = []
var tab_controls: Array[Dictionary] = []
var diagnostic_images: Array[String] = []
var delivered_tab_events: Array[Dictionary] = []

func _start_tab_trace() -> void:
	tab_observer = TabObserver.new()
	tab_observer.process_mode = Node.PROCESS_MODE_ALWAYS
	r.add_child(tab_observer)
	m.get_viewport().gui_focus_changed.connect(_trace_focus)

func _stop_tab_trace() -> void:
	if m.get_viewport().gui_focus_changed.is_connected(_trace_focus):
		m.get_viewport().gui_focus_changed.disconnect(_trace_focus)
	if is_instance_valid(tab_observer):
		tab_observer.set_process_input(false)
		tab_observer.set_process_unhandled_key_input(false)
		delivered_tab_events = tab_observer.events.duplicate(true)
		tab_observer.queue_free()

func _trace_focus(control: Control) -> void:
	focus_trace.append({"frame": Engine.get_process_frames(), "control": _control_trace(control)})

func _control_trace(control: Control) -> Dictionary:
	if not is_instance_valid(control): return {}
	return {"name": String(control.name), "path": String(control.get_path()),
		"instance": control.get_instance_id(), "text": control.text if control is Button else "",
		"visible": control.is_visible_in_tree(), "focus_mode": control.focus_mode,
		"disabled": control.disabled if control is BaseButton else false,
		"can_process": control.can_process(), "process_mode": control.process_mode,
		"rect": str(control.get_global_rect())}

func _focus_controls(node: Node, found: Array[Dictionary]) -> void:
	if node is Control and (node.focus_mode != Control.FOCUS_NONE or node is BaseButton):
		found.append(_control_trace(node))
	for child in node.get_children(): _focus_controls(child, found)

func _tab_state() -> Dictionary:
	var atlas: Control = m.root.find_child("FieldAtlas", true, false) as Control if is_instance_valid(m.root) else null
	return {"frame": Engine.get_process_frames(), "focus": _control_trace(m.get_viewport().gui_get_focus_owner()),
		"menu": m.current, "paused": r.get_tree().paused, "game_mode": g.process_mode,
		"game_can_process": g.can_process(), "menus_mode": m.process_mode, "menus_can_process": m.can_process(),
		"atlas_can_process": atlas.can_process() if is_instance_valid(atlas) else false,
		"atlas_instance": atlas.get_instance_id() if is_instance_valid(atlas) else 0,
		"detail_revision": atlas._detail_revision if is_instance_valid(atlas) else -1,
		"signature": atlas._signature if is_instance_valid(atlas) else 0,
		"pad_active": g.gamepad.active, "pad_focused": g.gamepad.focused,
		"keys": native.key_taps, "tab_down": Input.is_key_pressed(KEY_TAB)}

static func run(rig: Node) -> void:
	var q := new()
	q.r = rig
	rig.shot_dir = "user://shots/wayfinder/atlas_return_hints" if rig.flag("atlas-return-hints") else "user://shots/wayfinder/atlas_keyboard"
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().contains("/build/qa/"):
		q._finish("fresh isolated build/qa profile required")
		return
	await rig.boot("warrior", "ch3", false)
	q.g = rig.game
	q.m = q.g.menus
	q.native.r = rig
	q.native.g = q.g
	q.native.m = q.m
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and not q._revealed(): await rig.frames(1)
	if not q._check("setup/live", q._revealed() and q.g.no_saves and not q.g.net_online()
			and not q.g.dev_god and DisplayServer.get_name() != "headless"):
		q._finish("normal isolated reveal did not finish")
		return
	var mode := q.g.process_mode
	q.g.process_mode = Node.PROCESS_MODE_DISABLED
	await rig.frames(2) # Drain queued boot work before the strict snapshot.
	var world := q._snapshot(q.g, GAME_FIELDS)
	var hero := q._snapshot(q.g.player, HERO_FIELDS)
	var pin: int = q.g.hud.wayfinder.pinned_room
	var error: String
	if rig.flag("atlas-return-hints"):
		error = await q._footer_exercise()
	else:
		q._start_tab_trace()
		error = await q._exercise()
		q._stop_tab_trace()
	if rig.flag("atlas-return-hints"): await q._footer_cleanup()
	if q.m.is_open(): q.m.close()
	q.g.request_pause(false)
	await rig.frames(2) # Let removed readers finish guarded deferred work.
	q._check("cleanup/world", q._snapshot(q.g, GAME_FIELDS) == world)
	q._check("cleanup/hero", q._snapshot(q.g.player, HERO_FIELDS) == hero)
	q._check("cleanup/route", q.g.hud.wayfinder.pinned_room == pin)
	q._check("cleanup/menu", not q.m.is_open() and not rig.get_tree().paused)
	q._check("input/released", not Input.is_key_pressed(KEY_TAB) and not Input.is_key_pressed(KEY_ENTER)
		and not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	q.g.process_mode = mode
	q._check("cleanup/process_mode", q.g.process_mode == mode)
	q._finish(error)

func _revealed() -> bool:
	return g.play_started and g.state == Game.ST_PLAYING and g.has_local_player() and g.cutscene == null \
		and not g.input_overlay_up() and not g.get_tree().paused and not g.hud._cinematic_mode \
		and g.hud.overlay.color.a <= 0.001 and g.hud.title_label.modulate.a <= 0.01 \
		and g.hud.subtitle_label.modulate.a <= 0.01

func _snapshot(object: Object, fields: Array) -> Dictionary:
	var out := {}
	for field in fields:
		var value: Variant = object.get(field)
		out[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out

func _open() -> Control:
	m.open_map() # Normal construction is fixture setup; selection is input only.
	await r.frames(4)
	if m.current != "map" or not is_instance_valid(m.root): return null
	return m.root.find_child("FieldAtlas", true, false) as Control

func _focus_name() -> String:
	var focused: Control = m.get_viewport().gui_get_focus_owner()
	return String(focused.name) if is_instance_valid(focused) else ""

func _tab_to(name: String, capture_failure := true) -> bool:
	var controls: Array[Dictionary] = []
	_focus_controls(m.root, controls)
	tab_controls.append({"target": name, "phase": "before", "controls": controls})
	for i in 24:
		if _focus_name() == name: return true
		var before := _tab_state()
		await native._key(KEY_TAB) # Unchanged delivery and waits; never repair focus.
		tab_trace.append({"target": name, "tap": i + 1, "before": before, "after": _tab_state()})
	var reached := _focus_name() == name
	if not reached:
		controls = []
		_focus_controls(m.root, controls)
		tab_controls.append({"target": name, "phase": "failed", "controls": controls})
		if capture_failure:
			await RenderingServer.frame_post_draw
			diagnostic_images.append(r.shot("diagnostic_tab_unreachable", "rejected setup; passive trace only, no focus repair"))
	return reached

func _exercise() -> String:
	for spec in [["next", "AtlasNext", 1], ["previous", "AtlasPrevious", -1]]:
		var id: String = spec[0]
		var button: String = spec[1]
		var direction: int = spec[2]
		var atlas: Control = await _open()
		if not _check(id + "/setup", is_instance_valid(atlas)):
			return "atlas unavailable"
		var rooms: Array = atlas._rooms.duplicate()
		if not _check(id + "/known_rooms", rooms.size() >= 2 and rooms.has(atlas.selected)):
			return "need at least two naturally known rooms"
		var start: int = atlas.selected
		var index: int = rooms.find(start)
		var first: int = rooms[posmod(index + direction, rooms.size())]
		var second: int = rooms[posmod(index + direction * 2, rooms.size())]
		var mouse_before: int = native.mouse_clicks
		var reached := await _tab_to(button, false)
		_probe(id + "/entry", reached, not reached and _focus_name() == "",
			{"focus": _focus_name(), "expected": button, "mouse_before": mouse_before, "mouse_after": native.mouse_clicks})
		if id == "next": await _capture("00_keyboard_entry")
		if not reached:
			if not r.flag("baseline") or _focus_name() != "": return "pure keyboard entry failed"
			# Disclosed baseline-only native seed AFTER the entry finding; no grab_focus.
			var seed := native._find_button(m.root, "Recenter", true)
			if not is_instance_valid(seed): return "baseline Recenter seed unavailable"
			await native._mouse(seed.get_global_rect().get_center())
			await r.frames(3)
			if not _check(id + "/entry_seed", _current(atlas) and atlas.selected == start
				and m.get_viewport().gui_get_focus_owner() == seed and native.mouse_clicks == mouse_before + 1,
				{"used": true, "focus": _focus_name(), "selected": atlas.selected}): return "native seed did not establish focus"
			reached = await _tab_to(button)
		else:
			_check(id + "/entry_seed", not r.flag("baseline") and native.mouse_clicks == mouse_before,
				{"used": false, "focus": _focus_name(), "mouse": native.mouse_clicks})
		if not _check(id + "/tab_input", reached):
			return "native Tab failed to reach " + button
		if id == "next": await _capture("01_initial")
		await native._key(KEY_ENTER)
		if not _check(id + "/reader_first", _current(atlas)): return "reader changed after first Enter"
		if not _check(id + "/first", atlas.selected == first,
				{"start": start, "expected": first, "actual": atlas.selected}):
			return "first native Enter did not select adjacent room"
		var focus := _focus_name()
		_probe(id + "/focus", focus == button, focus == "", {"focus": focus, "expected": button})
		await native._key(KEY_ENTER) # No focus repair or Tab between activations.
		if not _check(id + "/reader_repeat", _current(atlas)): return "reader changed after repeated Enter"
		_probe(id + "/repeat", atlas.selected == second, atlas.selected == first,
			{"start": start, "first": first, "expected": second, "actual": atlas.selected, "focus": _focus_name()})
		_check(id + "/fog", atlas._rooms == rooms and rooms.has(atlas.selected))
		await _capture("02_next_afterrepeat" if id == "next" else "03_previous_afterrepeat")
		await native._key(KEY_ESCAPE)
		if not _check(id + "/escape", not m.is_open()): return "Escape failed"
	var atlas: Control = await _open()
	if not _check("mouse/setup", is_instance_valid(atlas)): return "mouse atlas unavailable"
	var rooms: Array = atlas._rooms.duplicate()
	var index: int = rooms.find(atlas.selected)
	if not _check("mouse/known_rooms", index >= 0 and rooms.size() >= 2): return "mouse rooms unavailable"
	for i in 2:
		var button := atlas.find_child("AtlasNext", true, false) as Button
		if not _check("mouse/button_%d" % i, is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled):
			return "mouse Next unavailable"
		await native._mouse(button.get_global_rect().get_center())
		await r.frames(3)
		if not _check("mouse/reader_%d" % i, _current(atlas)): return "reader changed after mouse click"
		_check("mouse/step_%d" % i, atlas.selected == int(rooms[posmod(index + i + 1, rooms.size())]),
			{"actual": atlas.selected, "expected": rooms[posmod(index + i + 1, rooms.size())]})
	await _capture("04_mouse_afterrepeat")
	await native._key(KEY_ESCAPE)
	_check("mouse/escape", not m.is_open())
	# Normal replacement in the same turn, before a new atlas deferred entry runs.
	m.open_map()
	var old_atlas := m.root.find_child("FieldAtlas", true, false)
	m.open_inventory()
	var replacement := m.root
	await r.frames(4)
	var focused := m.get_viewport().gui_get_focus_owner()
	_check("entry/stale_reader", m.current == "inventory" and m.root == replacement
		and (not is_instance_valid(focused) or replacement.is_ancestor_of(focused))
		and (not is_instance_valid(old_atlas) or old_atlas.is_queued_for_deletion()),
		"same-turn normal map-to-inventory replacement; no direct focus assignment")
	await native._key(KEY_ESCAPE)
	_check("entry/stale_escape", not m.is_open())
	return ""

func _current(atlas: Control) -> bool:
	return is_instance_valid(atlas) and not atlas.is_queued_for_deletion() and m.current == "map" \
		and is_instance_valid(m.root) and m.root.is_ancestor_of(atlas)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = r.shot(label, "controlled native Atlas GUI; baseline-only Recenter mouse seeds explicitly follow recorded entry failures; no travel or fog reveal")
	views.append(path)
	_check(label + "/original", FileAccess.file_exists(path))

func _check(id: String, ok: bool, detail: Variant = "") -> bool:
	rows.append({"id": id, "ok": ok, "finding": false, "detail": detail})
	if not ok: failures += 1
	return ok

func _probe(id: String, ok: bool, old: bool, detail: Dictionary) -> void:
	var finding: bool = r.flag("baseline") and not ok and old and EXPECTED.has(id)
	rows.append({"id": id, "ok": ok, "finding": finding, "detail": detail})
	if finding: findings.append(id)
	elif not ok: failures += 1

func _finish(error: String) -> void:
	_check("runtime/completed", error == "", error)
	var actual := findings.duplicate()
	actual.sort()
	var expected: Array = EXPECTED.duplicate() if r.flag("baseline") else []
	expected.sort()
	_check("findings/exact", actual == expected, {"actual": actual, "expected": expected})
	_check("seven_footer_originals" if r.flag("atlas-return-hints") else "five_originals", views.size() == (7 if r.flag("atlas-return-hints") else 5))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("receipt.json"), FileAccess.WRITE)
	_check("report/open", file != null)
	if file != null:
		file.store_string(JSON.stringify({"complete": failures == 0, "error": error, "failures": failures,
			"checks": rows, "findings": findings, "views": views, "baseline": r.flag("baseline"),
			"atlas_sha256": FileAccess.get_sha256("res://scripts/ui/field_atlas.gd"),
			"helper_sha256": FileAccess.get_sha256("res://scripts/tests/atlas_keyboard_live.gd"),
			"input": {"keys": native.key_taps, "mouse": native.mouse_clicks},
			"tab_diagnostic": {"steps": tab_trace, "focus_changes": focus_trace, "controls": tab_controls,
				"events": delivered_tab_events, "images": diagnostic_images},
			"footer_scope": "Optional isolated strict footer episode: binding/scheme/touch preferences and pad host focus/device are explicit temporary setup loans; fresh construction per case, native keyboard close, actual D-pad map open/navigation and B close. No setting persistence or live open-footer handoff claim; synthetic device27 auto labels require an empty device name. Touch copy/layout only, no physical touch claim." if r.flag("atlas-return-hints") else "not run",
			"scope": "Disposable no-save solo native GUI fixture. Normal ch3 reveal then inherited Game disabled; boot callbacks drain before snapshots. No manual focus/selection. Baseline-only real mouse Recenter seeds follow each observed entry finding; fixed keyboard entry cannot seed. Same-turn map replacement is a lifecycle control. No fog loans, world movement, travel, rewards, network or physical-device proof. No state or economy reset; original process mode restored after equality checks."}, "  "))
		file.close()
	print("ATLAS KEYBOARD: %d checks, %d failures, %d findings" % [rows.size(), failures, findings.size()])
	r.finish(1 if failures > 0 else 0)


func _footer_exercise() -> String:
	if not _check("footer/setup", not g.touch_mode and not g.gamepad.active and not r.flag("baseline"), "strict diagnostic, keyboard start; no expected footer findings"):
		return "footer mode requires default keyboard and no baseline waiver"
	footer_saved = {"binds": g.binds.duplicate(true), "settings": g.settings.duplicate(true),
		"device": g.gamepad.device, "focused": g.gamepad.focused}
	for spec in [["default", int(g.binds.get("map", KEY_M))], ["remapped", KEY_F6], ["long", KEY_KEYBOARD]]:
		var id: String = spec[0]
		var code: int = spec[1]
		g.binds["map"] = code # disclosed current-binding presentation/dispatch loan; no save
		var atlas: Control = await _open()
		if not _check("footer/" + id + "/reader", _current(atlas)): return "keyboard footer reader unavailable"
		await _footer_view(id, FOOTER_PREFIX + "[%s] to return" % OS.get_keycode_string(code))
		await native._key(code)
		if not _check("footer/" + id + "/key_closes", not m.is_open(), {"code": code}): return "current map key did not close"
	g.binds = footer_saved.binds.duplicate(true)
	for scheme in ["auto", "xbox", "playstation"]:
		g.settings["pad_labels"] = scheme # disclosed scheme loan, fresh atlas construction
		_footer_joy(JOY_BUTTON_DPAD_UP, true)
		_footer_joy(JOY_BUTTON_DPAD_UP, false)
		await r.frames(4)
		var atlas: Control
		if is_instance_valid(m.root): atlas = m.root.find_child("FieldAtlas", true, false) as Control
		if not _check("footer/" + scheme + "/pad_open", _current(atlas) and g.gamepad.active
			and g.gamepad.device == 27, "actual native D-pad Up from gameplay context"):
			return "native pad map open failed"
		if scheme == "auto":
			if not _check("footer/auto/unnamed_device", Input.get_joy_name(27).is_empty(), Input.get_joy_name(27)):
				return "synthetic auto label assumption not valid on this host"
		var cancel := "○" if scheme == "playstation" else "B"
		await _footer_view(scheme, FOOTER_PREFIX + "[%s] to return" % cancel)
		var original := atlas.get_instance_id()
		var selected_room: int = atlas.selected
		_footer_joy(JOY_BUTTON_DPAD_UP, true)
		_check("footer/" + scheme + "/dpad_down", bool(g.gamepad.buttons.get(JOY_BUTTON_DPAD_UP, false)), "adapter observed actual press")
		_footer_joy(JOY_BUTTON_DPAD_UP, false)
		await r.frames(3)
		if not _check("footer/" + scheme + "/dpad_stays", _current(atlas) and atlas.get_instance_id() == original
			and atlas.selected == selected_room and not bool(g.gamepad.buttons.get(JOY_BUTTON_DPAD_UP, true)), "same map remains; D-pad is menu navigation, not return"):
			return "D-pad changed/closed reader unexpectedly"
		_footer_joy(JOY_BUTTON_B, true)
		_check("footer/" + scheme + "/back_down", bool(g.gamepad.buttons.get(JOY_BUTTON_B, false)), "adapter observed actual Back press")
		_footer_joy(JOY_BUTTON_B, false)
		await r.frames(3)
		if not _check("footer/" + scheme + "/back_closes", not m.is_open() and g.gamepad.active
			and not bool(g.gamepad.buttons.get(JOY_BUTTON_B, true)), "actual B/circle routes controller_back"):
			return "native Back failed to close atlas"
	await native._key(KEY_F8) # actual keyboard handoff before touch layout loan
	g.settings["touch_controls"] = true
	g.refresh_touch_mode(); g._apply_touch_mode()
	var atlas: Control = await _open()
	if not _check("footer/touch/reader", _current(atlas) and g.touch_mode and not g.gamepad.active): return "touch footer construction failed"
	await _footer_view("touch", TOUCH_FOOTER)
	await native._key(KEY_ESCAPE)
	_check("footer/touch/escape", not m.is_open(), "keyboard cleanup of touch layout; no touch-close claim")
	return ""


func _footer_view(id: String, expected: String) -> void:
	await RenderingServer.frame_post_draw
	var label: Label = _footer_label(m.root)
	if not _check("footer/" + id + "/label", is_instance_valid(label), "actual visible bottom instruction label"):
		return
	_check("footer/" + id + "/copy", label.text == expected, {"expected": expected, "actual": label.text})
	var shape: Dictionary = Geometry.shaped(label)
	var cells: Rect2 = Geometry.to_rect(shape.cells)
	_check("footer/" + id + "/full_text", shape.count > 0 and shape.missing.is_empty() and not label.clip_text
		and label.visible_ratio >= 1.0 and label.max_lines_visible == -1 and label.get_visible_line_count() == label.get_line_count()
		and label.get_global_rect().grow(0.5).encloses(cells) and g.get_viewport().get_visible_rect().encloses(cells), shape)
	await _capture("footer_" + id)


func _footer_label(node: Node) -> Label:
	if not is_instance_valid(node): return null
	if node is Label and node.is_visible_in_tree() and node.text.begins_with("Select a room · drag to pan"):
		return node as Label
	for child in node.get_children():
		var result: Label = _footer_label(child)
		if result != null: return result
	return null


func _footer_joy(button: JoyButton, down: bool) -> void:
	g.gamepad.focused = true # host focus loan; no physical controller claim
	var event := InputEventJoypadButton.new()
	event.device = 27; event.button_index = button; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()


func _footer_cleanup() -> void:
	if footer_saved.is_empty(): return
	if m.is_open(): m.close()
	await native._key(KEY_F8)
	g.gamepad.cancel_held()
	g.gamepad.device = int(footer_saved.device)
	g.gamepad.focused = bool(footer_saved.focused)
	g.binds = footer_saved.binds.duplicate(true)
	g.settings = footer_saved.settings.duplicate(true)
	g.refresh_touch_mode(); g._apply_touch_mode()
	await r.frames(2)
	_check("footer/cleanup", g.binds == footer_saved.binds and g.settings == footer_saved.settings
		and not g.gamepad.active and g.gamepad.device == footer_saved.device and g.gamepad.focused == footer_saved.focused
		and not g.touch_mode and not true in g.gamepad.buttons.values()
		and not Input.is_key_pressed(KEY_F6) and not Input.is_key_pressed(KEY_KEYBOARD), "owned preferences/input setup restored; no files were saved")
