extends RefCounted
## Local Codex focused QA; reuses accepted native/geometry utilities.
## Pose and owned factory-hotspot loans, not an ordinary village playthrough.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const Pill := preload("res://scripts/tests/capital_arrival_live.gd")
const Painted := preload("res://scripts/tests/npc_prompt_live.gd")
const Controller := preload("res://scripts/ui/controller_settings.gd")
const PROP_COPY := "E — Inspect the ledger"
var r: ShotRig
var g: Game
var n: Native
var pill = Pill.new()
var painted = Painted.new()
var npc: Dictionary = {}
var prop: Dictionary = {}
var owned: Node2D
var rows: Array[Dictionary] = []
var images: Array[String] = []
var observations: Array[Dictionary] = []
var saved := {}
var held := 0
var default_quest_shape: Dictionary = {}


static func run(rig: ShotRig) -> String:
	var q := new()
	q.r = rig; q.g = rig.game
	q.n = Native.new(); q.n.r = rig; q.n.g = q.g; q.n.m = q.g.menus
	return await q._run()


func _check(id: String, good: bool, detail: Variant) -> bool:
	rows.append({"id": id, "passed": good, "detail": detail})
	print("INTERACTION COPY ", id, ": ", "PASS" if good else "FAIL")
	return good


func _run() -> String:
	var directory := r.shot_dir
	r.shot_dir = directory.path_join("interaction_copy")
	saved = {"binds": g.binds.duplicate(true), "settings": g.settings.duplicate(true),
		"paused": g.get_tree().paused, "talked": g.talked_to_elder, "quest": g.quest_key,
		"flags": g.flags.duplicate(true)}
	var error := await _exercise()
	await _cleanup()
	_check("runtime.completed", error == "", error)
	for i in n.rows.size(): _check("native.%d" % i, bool(n.rows[i].passed), n.rows[i])
	var failures := 0
	for row: Dictionary in rows: failures += int(not row.passed)
	var report := {"complete": true, "accepted": failures == 0, "failures": failures,
		"rows": rows, "images": images, "observations": observations, "native_rows": n.rows,
		"baseline_classification": "Observed stale rendered copy is the player defect. Missing authored metadata and absent width growth/shrink are dependent structural contract failures, not additional player-facing bugs. Strict diagnostic has no whitelist; classify actual receipt.",
		"scope": "Fresh no-character-save solo village. Original Maren pose borrowed near unchanged live hero, then restored. One owned production factory book hotspot and explicit landmark anchor are controlled geometry loans, not authored world placement. Real Keybinds capture/persistence, Settings Controls callback (synchronous no_saves=false loan permits settings writes, negative save_slot blocks character saves), synthetic native pad and pad-cursor label-scheme clicks, Journal HUD entry/Quests tab. Final remapped key starts actual Maren conversation; cleanup cancels presentation without completion and restores owned talked_to_elder field, not a story playthrough or whole-history rollback. Programmatic menu entry/scroll reveal, pad cursor position and gamepad.focused=true are disclosed setup loans; only tested actions use actual callbacks/events. No borrowed HP/XP/gear/quest text, AI disable, physical device or network claim. Full native originals require review. No baseline whitelist."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "cannot write interaction-copy receipt"
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	r.shot_dir = directory
	return error if error != "" else "" if failures == 0 else "interaction-copy strict findings: %d" % failures


func _exercise() -> String:
	if not _check("setup.fresh", g.no_saves and not g.net_online() and not g.dev_god
		and g.play_started and g.quest_key == "talk" and not g.talked_to_elder
		and not g.input_overlay_up() and not g.touch_mode and not g.gamepad.active
		and int(g.binds.interact) == KEY_E and String(g.settings.pad_labels) == "auto" and g.save_slot == -1,
		"Fresh default village without --touch; host mobile rendering is allowed"):
		return "requires fresh keyboard village"
	for entry: Dictionary in g.interactables:
		if is_instance_valid(entry.get("node")) and entry.node == g.elder: npc = entry
	if not _check("setup.original_maren", not npc.is_empty(), "original factory Elder Maren"):
		return "Maren missing"
	saved["npc_position"] = npc.node.position
	saved["npc_pose"] = _rest_pose(npc)
	npc.node.global_position = g.local_player.global_position + Vector2(45, -45)
	owned = g._make_npc("book", g.local_player.global_position + Vector2(230, 120), PROP_COPY, Callable(), "", Balance.PROP_HOTSPOT_REACH)
	for entry: Dictionary in g.interactables:
		if entry.get("node") == owned: prop = entry
	if not _check("setup.factory_prop", not prop.is_empty(), "production _make_npc book; no action invoked"):
		return "factory hotspot missing"
	# Explicit controlled landmark-height contract, not an authored village prop.
	prop.prompt.position.y = -130.0
	prop.prompt.set_meta("landmark_prompt_anchor", prop.prompt.position)
	await r.sim_wait(0.5)
	await _view("01_default", "E", "E — Talk", PROP_COPY)
	await _bind(KEY_F3, "f3")
	await _close()
	await _view("02_remapped", "F3", "F3 — Talk", "F3 — Inspect the ledger")
	await _journal("03_journal", "F3")
	await _bind(KEY_KEYBOARD, "long")
	await _close()
	await _view("04_long", "ON-SCREEN KEYBOARD", "ON-SCREEN KEYBOARD — Talk", "ON-SCREEN KEYBOARD — Inspect the ledger")
	_check("long.actual_name", OS.get_keycode_string(KEY_KEYBOARD).to_upper() == "ON-SCREEN KEYBOARD", OS.get_keycode_string(KEY_KEYBOARD))
	await _touch_toggle(true)
	await _close()
	await _view("05_touch", "touch", "Talk", "Inspect the ledger")
	await _touch_toggle(false)
	await _close()
	var before := _positions()
	_joy(JOY_BUTTON_B, true); _joy(JOY_BUTTON_B, false)
	_transition("pad.activate", before)
	_check("pad.active", g.gamepad.active and not g.touch_mode, "native pad device27 B")
	await r.frames(3)
	await _view("06_pad", "A", "A — Talk", "A — Inspect the ledger")
	Controller.open(g.menus) # disclosed entry; scheme actions below are actual pad GUI clicks
	await r.frames(3)
	await _scheme("auto", "xbox")
	await _scheme("xbox", "playstation")
	_joy(JOY_BUTTON_B, true); _joy(JOY_BUTTON_B, false)
	await r.frames(3)
	# Controller Back can navigate to Settings; close by B, never keyboard/mouse.
	for i in 4:
		if not g.menus.is_open(): break
		_joy(JOY_BUTTON_B, true); _joy(JOY_BUTTON_B, false)
		await r.frames(2)
	_check("pad.closed", not g.menus.is_open() and g.gamepad.active, g.menus.current)
	await _view("07_playstation", "×", "× — Talk", "× — Inspect the ledger")
	before = _positions()
	_key(KEY_F8, true); _key(KEY_F8, false)
	_transition("keyboard.return", before)
	await r.frames(3)
	_check("keyboard.active", not g.gamepad.active, "actual keyboard F8 handoff")
	await _view("08_keyboard_return", "ON-SCREEN KEYBOARD", "ON-SCREEN KEYBOARD — Talk", "ON-SCREEN KEYBOARD — Inspect the ledger")
	await _bind(KEY_E, "short_restore")
	await _close()
	await _view("09_short_restored", "E", "E — Talk", PROP_COPY)
	# Select the borrowed prop through the ordinary proximity selector. No label
	# visibility/action writes; the borrowed landmark frame is explicitly posed.
	npc.node.position = saved.npc_position
	owned.global_position = g.local_player.global_position + Vector2(0, 25)
	await r.frames(4)
	_check("prop.selected", prop.prompt.is_visible_in_tree() and g.interact_in_range, "ordinary selector on posed owned hotspot")
	await _capture_prop("10_factory_prop")
	owned.global_position = g.local_player.global_position + Vector2(230, 120)
	npc.node.global_position = g.local_player.global_position + Vector2(45, -45)
	await _bind(KEY_F3, "interaction")
	await _close()
	await r.sim_wait(0.6)
	if r.flag("interaction-copy-guards"): _guard_controls()
	if not await _interact(): return "native remapped interaction failed"
	await r.frames(3)
	_check("interaction.maren", g.talked_to_elder and g.hud.dialogue_active
		and g.hud.speaker_label.text == "Elder Maren", "actual F3 dispatch starts original Maren; no direct NPC action")
	var first_index: int = g.hud.dialogue_index
	var first_text: String = g.hud.text_label.text
	var reveal_deadline := Time.get_ticks_msec() + 8000
	while g.hud.dialogue_active and not g.hud._reveal_complete() and Time.get_ticks_msec() < reveal_deadline:
		await r.frames(1)
	var spoken: Dictionary = Geometry.shaped(g.hud.text_label)
	_check("interaction.first_line_readable", g.hud.dialogue_active and g.hud._reveal_complete()
		and g.hud.dialogue_index == first_index and g.hud.text_label.text == first_text
		and g.quest_key == saved.quest and _full_label(g.hud.text_label, spoken), spoken)
	images.append(r.shot("11_actual_maren"))
	return ""


func _positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in [npc, prop]:
		if entry.is_empty(): continue
		var label: Label = entry.prompt
		var row := {"position": [label.position.x, label.position.y], "size": [label.size.x, label.size.y], "center_x": label.position.x + label.size.x * 0.5, "anchors": {}}
		for key in ["npc_prompt_anchor", "landmark_prompt_anchor"]:
			if label.has_meta(key):
				var value: Vector2 = label.get_meta(key)
				row.anchors[key] = {"center_x": value.x + label.size.x * 0.5, "y": value.y}
		result.append(row)
	return result


func _transition(id: String, before: Array[Dictionary]) -> void:
	var after := _positions()
	for i in before.size():
		_check(id + ".current.%d" % i, absf(float(before[i].center_x) - float(after[i].center_x)) <= 0.01
			and absf(float(before[i].position[1]) - float(after[i].position[1])) <= 0.01,
			{"before": before[i], "after": after[i], "timing": "synchronous input dispatch, before next process/draw"})
		_check(id + ".anchors.%d" % i, _same_anchors(before[i].anchors, after[i].anchors), {"before": before[i].anchors, "after": after[i].anchors})
	if id == "bind.long": _check("long.width_grew", float(after[0].size[0]) > float(before[0].size[0]) and float(after[1].size[0]) > float(before[1].size[0]), {"before": before, "after": after})
	if id == "bind.short_restore": _check("short.width_shrank", float(after[0].size[0]) < float(before[0].size[0]) and float(after[1].size[0]) < float(before[1].size[0]), {"before": before, "after": after})
	observations.append({"id": id, "before": before, "after": after})


func _bind(code: int, id: String) -> void:
	g.menus.open_keybinds() # setup entry; actual Button + key capture/persistence below
	await r.frames(3)
	var pressed: bool = await n._button("Talk / interact")
	_check("bind." + id + ".listening", pressed and g.menus.listening_action == "interact", g.menus.listening_action)
	if not pressed or g.menus.listening_action != "interact": return
	var before := _positions()
	_key(code, true)
	_transition("bind." + id, before)
	_key(code, false)
	await r.frames(3)
	_check("bind." + id + ".captured", int(g.binds.interact) == code and g.menus.listening_action == "", g.binds.interact)
	_check("bind." + id + ".saved", _stored_binds(g.binds), "primary keybinds JSON exact key/count/numeric values")


func _touch_toggle(on: bool) -> void:
	g.menus.open_settings("pause") # setup entry; actual Controls callback below
	await r.frames(3)
	var button: Button = n._find_button(g.menus.root, "Controls:")
	if not _check("touch.%s.button" % on, is_instance_valid(button), "desktop-hosted control-scheme preference"):
		return
	await _reveal(button)
	var before := _positions()
	# save_settings honors no_saves; a synchronous settings-only loan permits
	# this real callback write. Negative save_slot still forbids character saves.
	g.no_saves = false
	_click(button.get_global_rect().get_center())
	g.no_saves = true
	_transition("touch.%s" % on, before)
	await r.frames(3)
	_check("touch.%s.applied" % on, g.touch_mode == on and bool(g.settings.touch_controls) == on, g.touch_mode)
	_check("touch.%s.saved" % on, _stored_settings(), "primary settings JSON equals current settings")


func _scheme(was: String, wanted: String) -> void:
	var button: Button = n._find_button(g.menus.root, "Button labels:")
	if not _check("scheme." + wanted + ".ready", is_instance_valid(button) and g.gamepad.active and String(g.settings.pad_labels) == was, was): return
	await _reveal(button)
	g.gamepad.ui.move_cursor(button.get_global_rect().get_center()) # disclosed pointer setup, no callback
	var before := _positions()
	g.no_saves = false
	_joy(JOY_BUTTON_A, true); _joy(JOY_BUTTON_A, false)
	g.no_saves = true
	_transition("scheme." + wanted, before)
	await r.frames(3)
	_check("scheme." + wanted + ".callback", g.gamepad.active and String(g.settings.pad_labels) == wanted, g.settings.pad_labels)
	_check("scheme." + wanted + ".saved", _stored_settings(), "primary settings JSON equals current settings")


func _journal(name: String, key_name: String) -> void:
	await n._mouse(g.hud.quest_btn.get_global_rect().get_center())
	await r.frames(3)
	if not _check("journal.open", g.menus.current == "journal", g.menus.current): return
	await n._button("QUESTS")
	var expected := Story.quest_text("talk").replace("press E", "press " + key_name)
	var found: Label = _label(g.menus.root, expected)
	_check("journal.current_copy", is_instance_valid(found), expected)
	if is_instance_valid(found):
		var shape: Dictionary = Geometry.shaped(found)
		_check("journal.full_text", _full_label(found, shape)
			and g.get_viewport().get_visible_rect().encloses(Geometry.to_rect(shape.cells)), shape)
	images.append(r.shot(name))
	await _close()


func _view(name: String, key_name: String, npc_copy: String, prop_copy: String) -> void:
	await r.frames(3)
	await RenderingServer.frame_post_draw
	var expected := Story.quest_text("talk").replace("press E", "press " + key_name)
	if key_name == "touch": expected = Story.quest_text("talk").replace("press E", "tap Act")
	var quest: Label = g.hud.quest_label
	var shape: Dictionary = Geometry.shaped(quest)
	_check(name + ".quest_copy", quest.text == "◆  " + expected, quest.text)
	_check(name + ".quest_complete", _full_label(quest, shape)
		and g.hud.quest_panel.get_global_rect().grow(0.5).encloses(Geometry.to_rect(shape.cells))
		and g.get_viewport().get_visible_rect().encloses(Geometry.to_rect(shape.cells)), shape)
	if name == "01_default": default_quest_shape = shape.duplicate(true)
	if name == "04_long":
		_check("long.quest_width_grew", not default_quest_shape.is_empty()
			and int(default_quest_shape.get("count", 0)) > 0 and int(shape.count) > 0
			and int(default_quest_shape.get("font_size", -1)) == int(shape.font_size)
			and Geometry.to_rect(default_quest_shape.get("cells", [0, 0, 0, 0])).size.x > 0.0
			and Geometry.to_rect(shape.cells).size.x > Geometry.to_rect(default_quest_shape.get("cells", [0, 0, 0, 0])).size.x,
			{"default": default_quest_shape, "long": shape})
	_check(name + ".npc_selected", npc.prompt.is_visible_in_tree() and g.interact_in_range, "ordinary proximity selector; original Maren pose loan")
	for i in 2:
		var entry: Dictionary = npc if i == 0 else prop
		var label: Label = entry.prompt
		var full: Dictionary = pill._fountain_text(label)
		_check(name + ".copy.%d" % i, label.text == (npc_copy if i == 0 else prop_copy), label.text)
		_check(name + ".authored.%d" % i, String(label.get_meta("interaction_authored_copy", "")) == ("E — Talk" if i == 0 else PROP_COPY), "immutable authored copy")
		_check(name + ".full_pill.%d" % i, full.complete, full)
		if i == 0:
			var outer: Rect2 = _rect(full.outer)
			_check(name + ".visible_clearance", g.get_viewport().get_visible_rect().encloses(outer)
				and not outer.intersects(painted._painted(g.local_player.sprite))
				and not outer.intersects(painted._painted(npc.sprite))
				and not outer.intersects(g.hud.quest_panel.get_global_rect()), full)
	observations.append({"id": name, "positions": _positions(), "quest_shape": shape})
	images.append(r.shot(name))


func _capture_prop(name: String) -> void:
	await RenderingServer.frame_post_draw
	var full: Dictionary = pill._fountain_text(prop.prompt)
	_check("prop.visible_full", full.complete and g.get_viewport().get_visible_rect().encloses(_rect(full.outer)), full)
	images.append(r.shot(name))


func _interact() -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while g.talk_cd > 0.0 and Time.get_ticks_msec() < deadline: await r.frames(1)
	if not _check("interaction.ready", not g.input_overlay_up() and g.talk_cd <= 0.0 and npc.prompt.is_visible_in_tree()
		and g.local_player.is_physics_processing(), "live original NPC, ordinary cooldown expired"): return false
	var frame := Engine.get_process_frames()
	var before := Time.get_ticks_msec()
	held = KEY_F3
	_key(held, true)
	await r.frames(2)
	_check("interaction.held", Input.is_key_pressed(held) and Engine.get_process_frames() - frame >= 2
		and Time.get_ticks_msec() - before < 1000, {"frames": Engine.get_process_frames() - frame, "ms": Time.get_ticks_msec() - before})
	_key(held, false); held = 0
	return true


func _cleanup() -> void:
	if held != 0: _key(held, false); held = 0
	g.menus.listening_action = ""
	g.hud.cancel_conversation() # discard unfinished callback; do not complete Maren quest
	g.request_pause(false)
	await _close()
	await n._key(KEY_F8)
	if not npc.is_empty() and is_instance_valid(npc.get("node")):
		npc.node.position = saved.npc_position
	g.talked_to_elder = bool(saved.talked)
	g.binds = saved.binds.duplicate(true); g.save_binds()
	g.settings = saved.settings.duplicate(true)
	g.no_saves = false; g.save_settings(); g.no_saves = true
	g.refresh_touch_mode(); g._apply_touch_mode()
	var owned_ref: WeakRef = weakref(owned) if is_instance_valid(owned) else null
	if is_instance_valid(owned):
		g.interactables.erase(prop)
		owned.queue_free()
	await r.frames(3)
	g.request_pause(bool(saved.paused))
	_check("cleanup.profile_guard", g.no_saves and g.save_slot == -1, "settings-write loan ended; no character slot acquired")
	_check("cleanup.settings", g.binds == saved.binds and g.settings == saved.settings and _stored_binds(saved.binds) and _stored_settings(), "original live settings/binds and primary settings/keybind JSON")
	_check("cleanup.quest_not_completed", g.quest_key == saved.quest and g.flags == saved.flags and g.talked_to_elder == saved.talked, "conversation canceled without after callback; dialogue history not claimed restored")
	if not npc.is_empty():
		_check("cleanup.npc_pose", npc.node.position == saved.npc_position and _rest_pose(npc) == saved.npc_pose
			and npc.sprite.texture == npc.rest_tex and npc.sprite.scale == npc.rest_scale
			and npc.sprite.hframes == npc.rest_frames and npc.sprite.flip_h == npc.rest_flip_h
			and absf(npc.sprite.position.x - npc.rest_pos.x) <= 0.01
			and npc.sprite.position.y >= npc.rest_pos.y - Balance.NPC_BREATH_PX - 0.01
			and npc.sprite.position.y <= npc.rest_pos.y + 0.01,
			"original node/rest configuration and restored facing; live one-pixel breath phase is not frozen")
	_check("cleanup.owned", owned_ref == null or owned_ref.get_ref() == null, "only owned factory book removed")
	_check("cleanup.input", not Input.is_key_pressed(KEY_F3) and not Input.is_key_pressed(KEY_E)
		and not Input.is_key_pressed(KEY_KEYBOARD) and not Input.is_key_pressed(KEY_ESCAPE)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not g.menus.is_open(), "synthetic input released")


func _close() -> void:
	for i in 5:
		if not g.menus.is_open(): break
		await n._key(KEY_ESCAPE)
	await r.frames(3)
	_check("close.%d" % rows.size(), not g.menus.is_open(), g.menus.current)


func _reveal(button: Control) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null and ancestor != g.menus.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await r.frames(2)
		ancestor = ancestor.get_parent()


func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()


func _joy(button: JoyButton, down: bool) -> void:
	g.gamepad.focused = true
	var event := InputEventJoypadButton.new()
	event.device = 27; event.button_index = button; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at
	Input.parse_input_event(move); Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at; event.global_position = at; event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()


func _stored_binds(expected: Dictionary) -> bool:
	if not FileAccess.file_exists("user://keybinds.json"): return false
	var actual: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://keybinds.json"))
	if not actual is Dictionary or actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key) or not (actual[key] is int or actual[key] is float) or float(actual[key]) != float(expected[key]): return false
	return true


func _label(node: Node, text: String) -> Label:
	if node is Label and node.text == text and node.is_visible_in_tree(): return node as Label
	for child in node.get_children():
		var found: Label = _label(child, text)
		if found != null: return found
	return null


func _rect(value: Dictionary) -> Rect2:
	return Rect2(Vector2(value.position[0], value.position[1]), Vector2(value.size[0], value.size[1]))


func _rest_pose(entry: Dictionary) -> Dictionary:
	var result := {}
	for key in ["rest_tex", "rest_frames", "rest_frame", "rest_scale", "rest_pos", "rest_flip_h"]:
		result[key] = entry.get(key)
	return result


func _stored_settings() -> bool:
	if not FileAccess.file_exists("user://settings.json"): return false
	var actual: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	return actual is Dictionary and actual == g.settings


func _guard_controls() -> void:
	# Fixed-only synchronous null-owner controls: no await, deletion or action.
	if not _check("guards.method", g.has_method("refresh_interaction_copy"), "fixed-only guard mode"):
		return
	var hud: Hud = g.hud
	var world: Node2D = g.world
	var quest: Label = hud.quest_label
	g.hud = null
	g.call("refresh_interaction_copy")
	g.hud = hud
	g.world = null
	g.call("refresh_interaction_copy")
	g.world = world
	hud.quest_label = null
	g.call("refresh_interaction_copy")
	hud.quest_label = quest
	_check("guards.restored", g.hud == hud and g.world == world and hud.quest_label == quest
		and world.is_inside_tree() and not world.is_queued_for_deletion(), "same live owners restored synchronously; no teardown claim")
	if not _check("guards.keyboard_mode", not g.touch_mode and not g.gamepad.active, "literal formatter controls require keyboard display"):
		return
	var original: int = int(g.binds.interact)
	var source := "press E | Press E | hold E | Hold E | press ESC | press ECHO | press E1 | depress E | prose E — keeps"
	for code in [KEY_DOLLAR, KEY_BACKSLASH]:
		g.binds.interact = code # pure formatting loan: no save/refresh/await
		var name := OS.get_keycode_string(code).to_upper()
		var expected := "press %s | Press %s | hold %s | Hold %s | press ESC | press ECHO | press E1 | depress E | prose E — keeps" % [name, name, name, name]
		var actual := String(g.call("interaction_copy", source))
		_check("guards.literal.%d" % code, actual == expected, {"key_name": name, "source": source, "expected": expected, "actual": actual})
		_check("guards.prefix.%d" % code, String(g.call("interaction_copy", "E — Talk")) == name + " — Talk"
			and String(g.call("interaction_copy", " E — prose")) == " E — prose", "leading instruction only; key names inserted literally")
	g.binds.interact = original
	_check("guards.binding_restored", int(g.binds.interact) == original and _stored_binds(g.binds), "loan restored before save/await; primary binding unchanged")


func _same_anchors(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size(): return false
	for key in before:
		if not after.has(key) or absf(float(before[key].center_x) - float(after[key].center_x)) > 0.01 \
				or absf(float(before[key].y) - float(after[key].y)) > 0.01: return false
	return true


func _full_label(label: Label, shape: Dictionary) -> bool:
	return shape.count > 0 and shape.missing.is_empty() and not label.clip_text \
		and label.visible_ratio >= 1.0 and label.max_lines_visible == -1 \
		and label.get_visible_line_count() == label.get_line_count() \
		and label.get_global_rect().grow(0.5).encloses(Geometry.to_rect(shape.cells))
