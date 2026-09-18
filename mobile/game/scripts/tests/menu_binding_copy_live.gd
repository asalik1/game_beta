extends RefCounted
## Strict optional capital-arrival continuation; no baseline waiver.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const Keys := preload("res://scripts/tests/menu_shortcuts_live.gd")
const ACTIONS := ["inventory", "skills", "codex", "map"]
const NAMES := ["Inventory", "Skill tree", "Codex", "Map"]
const DEFAULTS := [KEY_I, KEY_T, KEY_C, KEY_M]
const REMAPPED := [KEY_F2, KEY_F3, KEY_F4, KEY_F5]
const TALENT_SUFFIX := " — first row is always open. Later rows open at their level or when the row above is full."
var q
var g: Game
var m: Menus
var keys
var failures := 0
var views: Array[Dictionary] = []
var saved := {}


static func run(parent: RefCounted) -> Dictionary:
	var probe := new()
	probe.q = parent; probe.g = parent.g; probe.m = parent.g.menus
	probe.keys = Keys.new()
	probe.keys.q = parent; probe.keys.g = probe.g; probe.keys.m = probe.m
	probe.saved = {"binds": probe.g.binds.duplicate(true), "settings": probe.g.settings.duplicate(true),
		"economy": parent._fountain_economy(), "preview_slot": probe.m._ability_preview_slot,
		"preview_theme": probe.m._ability_preview_theme, "focused": probe.g.gamepad.focused,
		"ability_theme": probe.g.local_player.ability_theme.duplicate(true),
		"loadouts": probe.g.local_player.talent_loadouts.duplicate(true),
		"active_loadout": probe.g.local_player.active_talent_loadout,
		"emulation": Input.emulate_mouse_from_touch}
	var error: String = await probe._exercise()
	await probe._cleanup()
	var native_failed := 0
	for row: Dictionary in parent.ui.rows:
		if not row.passed: native_failed += 1
	probe._check("native_helpers", native_failed == 0, parent.ui.rows)
	return {"error": error if error != "" else "footer checks failed" if probe.failures + probe.keys.failures else "",
		"failures": probe.failures + probe.keys.failures, "views": probe.views,
		"inputs": probe.keys.observations, "native_rows": parent.ui.rows,
		"scope": "Actual capital arrival followed by native key opens/closes, tab clicks and Controls capture. Keybinds/Settings entry is direct setup; Native button helper can ensure_control_visible. Touch setting uses real callback with character/settings saves disabled; actual ScreenTouch outside closes. Pad event has explicit foreground-focus loan. No actor/physics/quest/resource loans. Isolated keybind JSON is written and restored; no whole-profile restoration or physical-device/ENet/campaign-Atlas proof.",
		"sources": {"helper": FileAccess.get_sha256("res://scripts/tests/menu_binding_copy_live.gd"),
			"menus": FileAccess.get_sha256("res://scripts/menus.gd"), "codex": FileAccess.get_sha256("res://scripts/ui/codex.gd")}}


func _check(id: String, okay: bool, actual: Variant) -> bool:
	if not okay: failures += 1
	return q._check("footer." + id, okay, actual)


func _exercise() -> String:
	if not _check("isolated", g.no_saves and not g.net_online() and not g.gamepad.active
		and Loc.lang == "en" and not q.r.flag("baseline") and not q.r.flag("no-capture"),
		"fresh isolated English solo fixture; strict failures retained"): return "fixture prerequisites unavailable"
	for index in ACTIONS.size():
		if not _check("default_binding." + ACTIONS[index], int(g.binds[ACTIONS[index]]) == DEFAULTS[index], g.binds.duplicate(true)):
			return "fresh default bindings required"
	if not await _touch_mode(false, "initial_keyboard"): return "keyboard layout unavailable"
	for index in ACTIONS.size():
		if not await _action_views(ACTIONS[index], "default", ""): return "default view unavailable"
	for index in ACTIONS.size():
		if not await _capture_binding(index, REMAPPED[index], "remap"): return "actual remap failed"
	for index in ACTIONS.size():
		var shot: String = {"inventory": "03_remapped_inventory", "skills": "04_remapped_talents",
			"codex": "05_remapped_codex", "map": "06_remapped_capital_map"}[ACTIONS[index]]
		if not await _action_views(ACTIONS[index], "remapped", shot): return "remapped view unavailable"
	# One long binding at a time preserves distinct opening keys and avoids the
	# intentionally legacy duplicate-binding route. Every changed footer is read.
	_check("long.actual_name", OS.get_keycode_string(KEY_KEYBOARD).to_upper() == "ON-SCREEN KEYBOARD", OS.get_keycode_string(KEY_KEYBOARD))
	for index in ACTIONS.size():
		if not await _capture_binding(index, KEY_KEYBOARD, "long"): return "long key capture failed"
		if not await _action_views(ACTIONS[index], "long", "07_long_talents" if ACTIONS[index] == "skills" else ""):
			return "long key view unavailable"
		if not await _capture_binding(index, REMAPPED[index], "short_again"): return "short key restoration failed"
		if not await _action_views(ACTIONS[index], "short_again", ""): return "short reopen unavailable"
	if not await _touch_mode(true, "touch"): return "touch callback unavailable"
	if not await _action_views("inventory", "touch", "08_touch_inventory"): return "touch Inventory unavailable"
	if not await _action_views("skills", "touch", ""): return "touch Skills unavailable"
	if not await keys._short_open(int(g.binds.inventory), "inventory", "footer.touch_outside"): return "touch exit not ready"
	Input.emulate_mouse_from_touch = true
	await q.ui._touch(Vector2(12, 12))
	await q.r.frames(3)
	_check("touch.actual_outside", not m.is_open(), "native ScreenTouch closes actual Inventory")
	if not await _touch_mode(false, "pad_keyboard_layout"): return "keyboard layout restoration failed"
	if not await keys._ready_for_open("footer.pad"): return "controller open not ready"
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_check("pad.open", g.gamepad.active and m.current == "inventory" and m.is_open(), m.current)
	await _view("pad.inventory", "inventory", "gear")
	var hint: Label = g.gamepad.ui.hints
	_check("pad.back_legend", hint.is_visible_in_tree() and hint.text.contains("%s: back" % g.gamepad.label("cancel")), hint.text)
	await keys._shot("09_controller_back_legend")
	await q.ui._joy_back()
	_check("pad.actual_back", not m.is_open(), m.current)
	keys._tap(KEY_F8) # ordinary keyboard handoff; no player command bound here
	_check("pad.keyboard_handoff", not g.gamepad.active, g.gamepad.active)
	return ""


func _capture_binding(index: int, code: int, phase: String) -> bool:
	m.open_keybinds() # editor entry is setup; actual capture is the tested path
	await q.r.frames(3)
	if not await q.ui._button(NAMES[index]): return false
	var receipt: Dictionary = keys._tap(code)
	_check(phase + ".capture." + ACTIONS[index], m.current == "keybinds" and m.listening_action == ""
		and int(g.binds[ACTIONS[index]]) == code and receipt.down_seen and receipt.released
		and keys._stored_binds_match(g.binds), {"input": receipt, "binds": g.binds.duplicate(true)})
	return await keys._back_to_play("footer." + phase + ".capture_return." + ACTIONS[index])


func _action_views(action: String, phase: String, shot: String) -> bool:
	var tabs: Array = ["gear", "stats", "potions"] if action == "inventory" else ["talents", "attributes", "abilities"] if action == "skills" else [""]
	for tab: String in tabs:
		var id := phase + "." + action + "." + (tab if tab != "" else "main")
		if not await keys._short_open(int(g.binds[action]), action, "footer." + id): return false
		if not m.is_open() or m.current != action: return false
		if tab in ["stats", "potions", "attributes", "abilities"]:
			var caption: String = {"stats": "Stats", "potions": "Potions", "attributes": "ATTRIBUTES", "abilities": "ABILITY ASSIGNMENTS"}[tab]
			if not await q.ui._button(caption): return false
		await _view(id, action, tab)
		if shot != "" and tab in ["gear", "talents", ""]: await keys._shot(shot)
		# Opening/tab Buttons may own focus, but a text editor must not silently
		# swallow this close control. No focus release or direct close is used.
		var focus: Control = g.get_viewport().gui_get_focus_owner()
		_check(id + ".not_typing", not (focus is LineEdit or focus is TextEdit), str(focus))
		keys._tap(int(g.binds[action]))
		_check(id + ".matching_key_closed", not m.is_open(), m.current)
		if not await keys._back_to_play("footer." + id + ".return"): return false
	return true


func _expected(action: String, tab: String) -> String:
	if g.touch_mode: return "Tap ✕ or outside to close" + (TALENT_SUFFIX if tab == "talents" else "")
	if tab == "abilities": return "Select a card to inspect it, then ASSIGN"
	var key := OS.get_keycode_string(int(g.binds[action])).to_upper()
	if action in ["inventory", "codex"]: return "ESC, ✕, click outside, or %s to close" % key
	return "ESC / %s to close" % key + (TALENT_SUFFIX if tab == "talents" else "")


func _footer() -> Label:
	if not is_instance_valid(m.root): return null
	# _open owns a direct-child VBox; _hint appends its last Label. This
	# structural lookup does not require the new helper or expected copy.
	for child in m.root.get_children():
		if child is VBoxContainer and child.get_child_count() > 0:
			var last: Node = child.get_child(child.get_child_count() - 1)
			if last is Label and last.size_flags_vertical == Control.SIZE_SHRINK_END: return last
	return null


func _has_label(node: Node, prefix: String) -> bool:
	if node is Label and node.is_visible_in_tree() and node.text.begins_with(prefix): return true
	for child in node.get_children():
		if _has_label(child, prefix): return true
	return false


func _view(id: String, action: String, tab: String) -> void:
	await g.get_tree().create_timer(0.3, true, false, true).timeout
	await q.r.frames(3)
	await RenderingServer.frame_post_draw
	var label := _footer()
	if not _check(id + ".actual_footer", label != null and m.current == action, m.current): return
	var markers := {"gear": "EQUIPPED", "stats": "Select any stat to learn what it does. Points are spent in Skills",
		"potions": "ROOM SLOTS", "talents": "Each page remembers its own build.",
		"attributes": "Every level grants 1 attribute point.", "abilities": "Select an option to inspect it, then use ASSIGN."}
	if tab != "": _check(id + ".actual_tab", _has_label(m.root, String(markers[tab])), markers[tab])
	var shape := Geometry.shaped(label)
	var cells := Geometry.to_rect(shape.cells)
	var shell: Rect2 = m.root.get_global_transform() * m._shell_rect
	var view: Rect2 = g.get_viewport().get_visible_rect()
	var own: Rect2 = label.get_global_rect()
	var box: VBoxContainer = label.get_parent()
	var previous: Control = box.get_child(label.get_index() - 1)
	var data := {"id": id, "menu": m.current, "tab": tab, "text": label.text, "expected": _expected(action, tab),
		"shape": shape, "shell": Geometry.rect(shell), "viewport": Geometry.rect(view),
		"previous": Geometry.rect(previous.get_global_rect()), "touch": g.touch_mode, "pad": g.gamepad.active}
	views.append(data)
	_check(id + ".copy", label.text == _expected(action, tab), data)
	_check(id + ".complete", label.is_visible_in_tree() and label.modulate.a > 0.99 and m.root.modulate.a > 0.99
		and not label.clip_text and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
		and label.get_visible_line_count() == label.get_line_count() and shape.count > 0 and shape.missing.is_empty(), data)
	_check(id + ".contained", own.grow(0.5).encloses(cells) and shell.grow(0.5).encloses(own)
		and shell.grow(0.5).encloses(cells) and view.grow(0.5).encloses(shell) and view.grow(0.5).encloses(cells), data)
	_check(id + ".body_clear", not previous.get_global_rect().intersects(own), data)
	_check(id + ".font", label.get_theme_font_size("font_size") == 13, shape.font_size)


func _touch_mode(on: bool, id: String) -> bool:
	if bool(g.settings.get("touch_controls", false)) != on:
		m.open_settings() # controlled entry; use the production Controls callback
		await q.r.frames(3)
		if not await q.ui._button("Controls:"): return false
	_check(id + ".mode", bool(g.settings.get("touch_controls", false)) == on and g.touch_mode == on, g.touch_mode)
	return await keys._back_to_play("footer." + id + ".return")


func _joy(button: JoyButton) -> void:
	g.gamepad.focused = true # foreground focus loan, matching accepted native pad rigs
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 27; event.button_index = button; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
		await q.r.frames(1)
	await q.r.frames(3)


func _cleanup() -> void:
	for code: int in keys.held.duplicate(): keys._edge(code, false)
	q.held_key = 0
	m.listening_action = ""
	if m.is_open(): m.close()
	g.request_pause(false)
	keys._tap(KEY_F8)
	g.binds = saved.binds.duplicate(true); g.save_binds()
	g.settings = saved.settings.duplicate(true)
	g.refresh_touch_mode(); g._apply_touch_mode()
	Input.emulate_mouse_from_touch = bool(saved.emulation)
	g.gamepad.focused = bool(saved.focused)
	m._ability_preview_slot = String(saved.preview_slot); m._ability_preview_theme = String(saved.preview_theme)
	await q.r.frames(3)
	_check("cleanup.binds", keys._stored_binds_match(saved.binds) and g.binds == saved.binds, "exact primary keybind JSON and live dictionary; backups retained")
	_check("cleanup.resources", q._fountain_economy() == saved.economy and g.local_player.ability_theme == saved.ability_theme
		and g.local_player.talent_loadouts == saved.loadouts and g.local_player.active_talent_loadout == saved.active_loadout,
		"resources/story/settings/binds/loadouts unchanged; only owned preview fields restored")
	var released: bool = keys.held.is_empty()
	for code: int in keys.seen: released = released and not Input.is_key_pressed(code)
	_check("cleanup.input", released and not m.is_open() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not g.gamepad.active and g.no_saves, "keys/pointer released; keyboard device restored")
