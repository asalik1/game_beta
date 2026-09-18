extends RefCounted
## Local Codex QA for DeepSeek-inspired keyboard reminder follow-up.
## Fresh disposable profile; actual keybind Button presses and native key events.
## Direct entry to Keybinds and ensure_control_visible are disclosed setup only.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const ACTIONS := ["target", "interact", "map", "inventory", "skills", "codex"]
const ACTION_LABELS := ["Switch target lock", "Talk / interact", "Map", "Inventory", "Skill tree", "Codex"]
const SHORT_KEYS := [KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7]
const LONG_KEYS := [KEY_KEYBOARD, KEY_MEDIAPREVIOUS, KEY_LAUNCHMEDIA, KEY_SCROLLLOCK, KEY_BACKSPACE, KEY_CAPSLOCK]
const DEFAULT_COPY := ["WASD move · TAB lock · SPACE unlock · E talk · M map", "I inventory · T skills · C codex · ESC menu"]
const SHORT_COPY := ["WASD move · F2 lock · SPACE unlock · F3 talk · F4 map", "F5 inventory · F6 skills · F7 codex · ESC menu"]
var r: ShotRig
var g: Game
var h: Hud
var n: Native
var rows: Array[Dictionary] = []
var images: Array[String] = []
var observations: Array[Dictionary] = []


static func run(rig: ShotRig) -> String:
	var q := new()
	q.r = rig; q.g = rig.game; q.h = rig.game.hud
	q.n = Native.new(); q.n.r = rig; q.n.g = q.g; q.n.m = q.g.menus
	return await q._run()


func _check(id: String, good: bool, detail: Variant) -> void:
	rows.append({"id": id, "status": "pass" if good else "fail", "detail": detail})
	print("KEYBOARD HINTS ", id, ": ", rows.back().status)


func _run() -> String:
	var previous_dir := r.shot_dir
	r.shot_dir = previous_dir.path_join("keyboard_hints")
	var binds_before: Dictionary = g.binds.duplicate(true)
	var settings_before: Dictionary = g.settings.duplicate(true)
	var touch_before: bool = g.touch_mode
	var saved_cinematic: bool = h._cinematic_mode
	_check("setup/fresh", g.no_saves and not g.net_online() and g.play_started
		and not g.input_overlay_up() and h.hint_labels.size() == 2,
		"Fresh ShotRig village, no encounter/remote/device claims")
	await n._key(KEY_F8)
	_check("setup/keyboard", not g.touch_mode and not g.gamepad.active and not h._cinematic_mode,
		"Run host mobile source without --touch; actual touch handoff follows separately")
	await _inspect("01_default", DEFAULT_COPY, false)
	await _remap(SHORT_KEYS, "short")
	await _close()
	await _inspect("02_remapped", SHORT_COPY, false)
	await _dispatch(KEY_F5, "inventory")
	_check("dispatch/inventory", g.menus.current == "inventory", g.menus.current)
	await _close()
	await _dispatch(KEY_F4, "map")
	_check("dispatch/map", g.menus.root != null and g.menus.root.find_child("FieldAtlas", true, false) != null, g.menus.current)
	await _close()
	# Borrow one real production reward row before remapping: the existing
	# row must reflow too. No player gold changes or old row/tween removal.
	var log_room: bool = h._log_lines.size() < Hud.LOG_MAX
	_check("log/room", log_room, h._log_lines.size())
	var owned_log: Control = null
	var log_before := Vector2.ZERO
	if log_room:
		h.log_event("Readability check: +12 gold", Color(1.0, 0.85, 0.35), "gold")
		owned_log = h._log_lines.back() as Control
		await r.sim_wait(0.35)
		log_before = owned_log.position
		_check("log/default_anchor", is_equal_approx(log_before.y, Hud.LOG_BOTTOM - Hud.LOG_LINE_H), log_before)
	var alphas: Array[float] = []
	for label: Label in h.hint_labels:
		alphas.append(label.modulate.a)
		label.modulate.a = 0.42 # controlled partially faded presentation loan
	await _remap(LONG_KEYS, "long")
	await _close()
	for i in h.hint_labels.size():
		var label: Label = h.hint_labels[i]
		_check("refresh/alpha/%d" % i, is_equal_approx(label.modulate.a, 0.42), label.modulate.a)
		label.modulate.a = alphas[i]
	var names: Array[String] = []
	for key: int in LONG_KEYS: names.append(OS.get_keycode_string(key).to_upper())
	var long_copy: Array[String] = ["WASD move · %s lock · SPACE unlock · %s talk · %s map" % [names[0], names[1], names[2]],
		"%s inventory · %s skills · %s codex · ESC menu" % [names[3], names[4], names[5]]]
	# Actual production chat widgets loaned locally to inspect HUD clearance.
	# No session or packet is fabricated, and no message is sent externally.
	var owned_chat: bool = h.chat_root == null
	_check("chat/fresh", owned_chat, "Solo normally has no allocated chat subtree")
	if owned_chat:
		h._ensure_chat()
		h._on_chat_line("Companion", "party", "The northern road is clear. Meet at the old watchtower.")
		h.chat_input.visible = true
		await r.frames(3)
		var viewport: Rect2 = h.get_viewport().get_visible_rect()
		_check("chat/visible_control", h.chat_input.is_visible_in_tree() and h.chat_lines_box.is_visible_in_tree()
			and h.chat_input.get_global_rect().has_area() and h.chat_lines_box.get_global_rect().has_area()
			and viewport.encloses(h.chat_input.get_global_rect()) and viewport.encloses(h.chat_lines_box.get_global_rect()),
			{"input": Geometry.rect(h.chat_input.get_global_rect()), "lines": Geometry.rect(h.chat_lines_box.get_global_rect())})
	await r.sim_wait(0.35)
	_check("log/retained", is_instance_valid(owned_log) and h._log_lines.has(owned_log), "Borrowed row survives normal paused settings reading")
	if is_instance_valid(owned_log):
		var log_label: Label = owned_log.get_meta("label") as Label
		var shape: Dictionary = Geometry.shaped(log_label)
		_check("log/visible_control", owned_log.is_visible_in_tree() and owned_log.modulate.a > 0.9
			and shape.missing.is_empty() and shape.count > 0 and log_label.text == "Readability check: +12 gold"
			and h.get_viewport().get_visible_rect().encloses(owned_log.get_global_rect())
			and owned_log.get_global_rect().grow(0.5).encloses(Geometry.to_rect(shape.cells)), shape)
		_check("log/existing_reflow", owned_log.position.y < log_before.y, {"before": log_before, "after": owned_log.position})
	await _inspect("03_long_names", long_copy, true)
	if is_instance_valid(owned_log):
		var log_ref: WeakRef = weakref(owned_log)
		var motion: Tween = owned_log.get_meta("tween", null)
		if motion != null and motion.is_valid(): motion.kill()
		h._log_lines.erase(owned_log)
		owned_log.queue_free()
		h._layout_log()
		await r.frames(3)
		_check("log/owned_cleanup", log_ref.get_ref() == null, "Only the borrowed row and its tween removed")
	if owned_chat:
		var chat_ref: WeakRef = weakref(h.chat_root)
		h.chat_root.queue_free()
		h.chat_root = null; h.chat_lines_box = null; h.chat_input = null
		await r.frames(3)
		_check("chat/owned_cleanup", chat_ref.get_ref() == null and not h.chat_active, "Only loaned chat subtree freed")
	# Display-mode loans exercise the unchanged hide paths; synthetic controller
	# event proves normal device handoff, not a physical controller.
	g.set_touch_controls(true)
	await r.frames(3)
	_check("mode/touch_hidden", _all_hidden() and g.touch_mode, "Touch preference, desktop-hosted source")
	images.append(r.shot("04_touch_hidden"))
	g.set_touch_controls(false)
	for down in [true, false]:
		g.gamepad.focused = true
		var event := InputEventJoypadButton.new()
		event.device = 27; event.button_index = JOY_BUTTON_B; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(3)
	_check("mode/controller_hidden", g.gamepad.active and _all_hidden(), "Synthetic controller B handoff")
	images.append(r.shot("05_controller_hidden"))
	await n._key(KEY_F8)
	h.set_cinematic(true)
	await r.frames(2)
	_check("mode/cinematic_hidden", _all_hidden(), "Direct display-mode control; not story playback")
	h.set_cinematic(false)
	await r.frames(2)
	_check("mode/keyboard_returns", not g.gamepad.active and not g.touch_mode and _all_visible(), "Normal keyboard handoff, cinematic display restored")
	# Restore actual original settings/binds, including persisted profile copy.
	g.menus.listening_action = ""
	await _close()
	g.binds = binds_before.duplicate(true)
	g.save_binds()
	g.settings = settings_before.duplicate(true)
	g.save_settings()
	g.refresh_touch_mode(); g._apply_touch_mode()
	h.set_cinematic(saved_cinematic)
	await r.frames(3)
	_check("cleanup/settings", g.binds == binds_before and g.settings == settings_before
		and g.touch_mode == touch_before and h._cinematic_mode == saved_cinematic, "Original profile controls restored; only disposable keybinds/settings files were written")
	_check("cleanup/input", not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not Input.is_key_pressed(KEY_ESCAPE) and not g.menus.is_open(), "Native controls released and menus closed")
	await _inspect("06_restored", DEFAULT_COPY, false)
	var failures := 0
	for row: Dictionary in rows: failures += int(row.status == "fail")
	var report := {"complete": true, "accepted": failures == 0, "failures": failures,
		"rows": rows, "images": images, "observations": observations,
		"input_rows": n.rows, "scope": "Controlled fresh solo village; real Button/native key binding capture, actual F5 inventory/F4 map dispatch. Other remapped actions have text/source coverage only. Native key names from OS; Label character bounds independent of production width calculation. Direct Keybinds entry/reveal, display-mode loans, local chat and reward-feed presentation widgets disclosed; no external message or session simulation. Partially faded alpha0.42 loan tests refresh ownership; no75-second fade wait. No remap collision-policy, save reload, fade lifetime, physical device or ordinary encounter claim. Diagnostic mode has no failure whitelist."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "cannot write keyboard-hints receipt"
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	r.shot_dir = previous_dir
	return "" if failures == 0 else "keyboard-hints strict findings: %d" % failures


## Gameplay menu hotkeys are polled, unlike the GUI capture/ESC event path.
## Wait out normal close debounce, then hold one press across real frames.
func _dispatch(code: int, id: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while g.talk_cd > 0.0 and Time.get_ticks_msec() < deadline:
		await r.get_tree().process_frame
	var ready: bool = g.talk_cd <= 0.0 and not g.input_overlay_up() and not Input.is_key_pressed(code)
	_check("dispatch/ready/" + id, ready, {"talk_cd": g.talk_cd, "overlay": g.input_overlay_up()})
	if not ready: return
	var start_frame: int = Engine.get_process_frames()
	var started: int = Time.get_ticks_msec()
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	_check("dispatch/held/" + id, Engine.get_process_frames() - start_frame >= 2 and Input.is_key_pressed(code),
		{"process_frames": Engine.get_process_frames() - start_frame, "held_ms": Time.get_ticks_msec() - started})
	event = InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(3)


func _remap(keys: Array, id: String) -> void:
	g.menus.open_keybinds()
	await r.frames(3)
	for i in ACTIONS.size():
		var pressed: bool = await n._button(ACTION_LABELS[i])
		_check(id + "/capture/" + ACTIONS[i], pressed and g.menus.listening_action == ACTIONS[i], g.menus.listening_action)
		if pressed:
			await n._key(int(keys[i]))
		_check(id + "/binding/" + ACTIONS[i], int(g.binds[ACTIONS[i]]) == int(keys[i])
			and g.menus.listening_action == "", g.binds[ACTIONS[i]])


func _close() -> void:
	for i in 5:
		if not g.menus.is_open(): break
		await n._key(KEY_ESCAPE)
	await r.frames(3)
	_check("close/%d" % rows.size(), not g.menus.is_open(), g.menus.current)


func _inspect(name: String, expected: Array, wraps: bool) -> void:
	await r.frames(3)
	var shapes: Array[Dictionary] = []
	var total_lines := 0
	for i in h.hint_labels.size():
		var label: Label = h.hint_labels[i]
		var shape: Dictionary = Geometry.shaped(label)
		var cells: Rect2 = Geometry.to_rect(shape.cells)
		shapes.append(shape)
		total_lines += label.get_line_count()
		_check(name + "/copy/%d" % i, label.text == expected[i], {"expected": expected[i], "actual": label.text})
		_check(name + "/full_text/%d" % i, shape.missing.is_empty() and shape.count > 0
			and label.visible_ratio >= 1 and label.max_lines_visible == -1
			and label.get_visible_line_count() == label.get_line_count() and not label.clip_text,
			shape)
		_check(name + "/bounds/%d" % i, label.get_global_rect().grow(0.5).encloses(cells)
			and Rect2(14, 0, 400, 720).grow(0.5).encloses(cells), shape)
		var obstacles: Array[Control] = [h.info_panel, h.vitals_panel, h.quest_panel,
			h.mail_btn, h.quest_btn, h.inv_btn, h.codex_btn, h.skills_btn, h.settings_btn]
		if is_instance_valid(h.chat_input): obstacles.append(h.chat_input)
		if is_instance_valid(h.chat_lines_box): obstacles.append(h.chat_lines_box)
		for log_row: Control in h._log_lines:
			if is_instance_valid(log_row): obstacles.append(log_row)
		for box: Dictionary in h.slot_boxes:
			for value: Variant in box.values():
				if value is Control: obstacles.append(value as Control)
		var overlaps: Array[String] = []
		for obstacle: Control in obstacles:
			if is_instance_valid(obstacle) and obstacle.is_visible_in_tree() and obstacle.get_global_rect().has_area() and cells.intersects(obstacle.get_global_rect()):
				overlaps.append(str(obstacle.get_path()))
		_check(name + "/hud_clearance/%d" % i, overlaps.is_empty(), {"overlaps": overlaps, "cells": shape.cells})
		_check(name + "/readable/%d" % i, label.is_visible_in_tree() and label.modulate.a > 0.9
			and label.get_theme_font_size("font_size") == 11, {"alpha": label.modulate.a, "visible": label.is_visible_in_tree()})
	if not wraps:
		_check(name + "/default_layout", (h.hint_labels[0] as Label).position == Vector2(14, 682)
			and (h.hint_labels[1] as Label).position == Vector2(14, 698)
			and is_equal_approx((h.hint_labels[0] as Label).size.x, 400)
			and is_equal_approx((h.hint_labels[1] as Label).size.x, 400), "Default geometry including long-to-short restore")
	_check(name + "/rows_clear", shapes.size() == 2 and not Geometry.to_rect(shapes[0].cells).intersects(Geometry.to_rect(shapes[1].cells)), shapes)
	_check(name + "/wrapped_control", total_lines > 2 if wraps else total_lines == 2, total_lines)
	observations.append({"name": name, "shapes": shapes, "lines": total_lines})
	images.append(r.shot(name))


func _all_hidden() -> bool:
	for label: Label in h.hint_labels:
		if label.is_visible_in_tree(): return false
	return true


func _all_visible() -> bool:
	for label: Label in h.hint_labels:
		if not label.is_visible_in_tree(): return false
	return true
