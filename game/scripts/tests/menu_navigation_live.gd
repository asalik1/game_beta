extends RefCounted
## Bounded real-viewport regression checks. Menu opens/hero selection are fixtures;
## buttons, text entry, back/cancel and outside taps use actual input dispatch.
var r: Node
var g: Game
var m: Menus
var rows: Array[Dictionary] = []
var mouse_clicks := 0
var touch_taps := 0
var key_taps := 0
var wheel_taps := 0
var gamepad_taps := 0
var cancel_calls := 0
var yes_calls := 0


static func run(rig: Node) -> Dictionary:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.m = rig.game.menus
	var settings: Dictionary = probe.g.settings.duplicate(true)
	var binds: Dictionary = probe.g.binds.duplicate(true)
	var language: String = Loc.lang
	var touch_emulation: bool = Input.emulate_mouse_from_touch
	var touch_capability: bool = Input.emulate_touch_from_mouse
	# Match the shipped touch GUI path while keeping the owner's preferences intact.
	Input.emulate_mouse_from_touch = true
	probe.g.settings["touch_controls"] = false
	probe.g.refresh_touch_mode()
	probe.g._apply_touch_mode()
	Loc.lang = "en"
	var error: String = await probe._run()
	probe._check("runtime.completed", error == "", error)
	probe._check("settings.preserved", probe.g.settings == settings or probe._settings_except_touch(probe.g.settings) == probe._settings_except_touch(settings), probe.g.settings)
	probe.g.binds = binds
	probe.g.settings = settings
	Loc.lang = language
	Input.emulate_mouse_from_touch = touch_emulation
	Input.emulate_touch_from_mouse = touch_capability
	probe.g.refresh_touch_mode()
	probe.g._apply_touch_mode()
	if probe.m.is_open():
		probe.m.close()
	probe.g.hud.cancel_conversation()
	probe.g.request_pause(false)
	await rig.frames(3)
	probe._check("input.released", not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "all synthetic presses released")
	return probe._report()


func _run() -> String:
	if not _check("fixture.isolated", g.no_saves and not g.net_online(), "no_saves solo Game"):
		return "requires isolated solo Game"
	if r.flag("pause-layout"):
		return await _pause_layout()
	if r.flag("confirm-layout"):
		return await _confirm_layout()
	if r.flag("potion-slots"):
		return await _potion_slots()
	r.step("title cover and roster settings exits")
	m.open_title()
	await r.frames(3)
	await _key(KEY_SPACE)
	if not _check("title.cover_to_roster", m.current == "title" and m.title_stage == "slots", _state()):
		return "title input did not reach the roster"
	await _roster_delete()
	for method in ["back", "escape", "x", "outside", "touch_outside"]:
		m.open_slots()
		await r.frames(3)
		if not await _button("Settings"):
			return "roster Settings button unavailable"
		_check("roster.settings_open." + method, m.current == "settings" and m.settings_return == "title", _state())
		await _exit(method)
		_probe("roster.settings_return." + method, m.current == "title" and m.title_stage == "slots" and m.is_open() and g.get_tree().paused and not g.hud.visible, _state())
		if method == "x":
			await _capture("01_roster_settings_exit")
	# The name field has an existing exemption; retain it as a strict regression.
	m.open_name_entry("warrior")
	await r.frames(3)
	await _text_regression("name_entry", "tcimej", false)
	await _key(KEY_ESCAPE)
	_check("name_entry.escape", m.current == "class_select", _state())
	r.step("isolated warrior and ordinary inventory bookend")
	m.pick_chapter("ch1")
	await r.frames(3)
	m.pick_class("warrior")
	await r.frames(5)
	await r.skip_dialogue()
	g.play_started = true
	g.dev_god = true
	g.hud.visible = true
	await r.frames(3)
	m.open_inventory()
	await r.frames(3)
	await _key(KEY_ESCAPE)
	_check("inventory.escape_closes", not m.is_open() and not g.get_tree().paused, _state())
	r.step("pause settings and real child-panel back routes")
	m.open_settings("pause")
	await r.frames(3)
	_settings_layout("desktop")
	await _capture("02a_settings_desktop")
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	m.open_settings("pause")
	await r.frames(3)
	_settings_layout("touch")
	await _capture("02b_settings_touch")
	g.settings["touch_controls"] = false
	g.refresh_touch_mode()
	g._apply_touch_mode()
	for method in ["back", "escape", "x", "outside", "touch_outside"]:
		m.open_pause()
		await r.frames(3)
		if not await _button("Settings"):
			return "pause Settings button unavailable"
		await _exit(method)
		_probe("pause.settings_return." + method, m.current == "pause" and m.is_open() and g.get_tree().paused and not g.hud.visible, _state())
		if method == "x":
			await _capture("02_pause_settings_exit")
	for panel in ["comfort", "controller", "keybinds"]:
		for method in ["back", "escape", "x", "outside", "touch_outside"]:
			m.open_settings("pause")
			await r.frames(3)
			var label: String = {"comfort": "Combat & comfort", "controller": "Controller", "keybinds": "Keybinds"}[panel]
			if not await _button(label):
				return "settings child button unavailable: " + panel
			if not _check("child.opens." + panel + "." + method, m.current == panel, _state()):
				return "settings child did not open: " + panel
			await _exit(method)
			_probe("child.returns." + panel + "." + method, m.current == "settings" and m.settings_return == "pause" and g.get_tree().paused, _state())
			if panel == "keybinds" and method == "escape":
				await _capture("03_keybinds_escape")
	await _binding_cancel()
	await _input_edges()
	await _talent_typing()
	m.open_codex("monsters")
	await r.frames(4)
	await _text_regression("codex", "ctimje", false)
	await _key(KEY_ESCAPE)
	_check("codex.escape_closes", not m.is_open(), _state())
	await _mail_cancellation()
	await _grouped_gold()
	await _callback_lifetime()
	m.open_inventory()
	await r.frames(3)
	await _exit("x")
	_check("inventory.x_closes", not m.is_open() and not g.get_tree().paused and g.hud.visible, _state())
	return ""


## Optional positional-plan proof. The ordinary navigation episode stays intact.
func _potion_slots() -> String:
	if not _check("potion.fixture.launch", not r.flag("settings-touch") and not r.flag("touch")
			and not OS.has_feature("mobile"), "combined mouse/touch fixture: desktop host, no forced --touch"):
		return "potion-slots must run alone on the desktop host (mobile project is supported)"
	r.step("controlled chapter-three warrior boot; no saves, collection or rewards claim")
	m.pick_chapter("ch3")
	await r.frames(3)
	m.pick_class("warrior")
	await r.frames(5)
	await r.skip_dialogue()
	# Illustrated opening callbacks can outlive ShotRig's dialogue skip. Observe
	# natural completion before freezing the solo menu; do not set play_started.
	var deadline := Time.get_ticks_msec() + 8000
	var ready := false
	while Time.get_ticks_msec() < deadline:
		var illustrated := false
		for child in g.hud.get_children():
			if child is Cutscene:
				illustrated = true
		ready = g.play_started and g.state == Game.ST_PLAYING and g.has_local_player() \
			and not g.hud.dialogue_active and not g.hud.choices_active \
			and not g.hud._cinematic_mode and not is_instance_valid(g.cutscene) \
			and not illustrated and not m.is_open() and not g.get_tree().paused
		if ready:
			break
		await g.get_tree().create_timer(0.05, true, false, true).timeout
	if not _check("potion.fixture.boot_ready", ready, {"chapter": g.chapter_id,
			"play_started": g.play_started, "state": g.state, "dialogue": g.hud.dialogue_active,
			"choices": g.hud.choices_active, "cinematic": g.hud._cinematic_mode}):
		return "chapter-three boot did not settle naturally"
	var p: Player = g.local_player
	m.open_inventory("potions")
	await r.frames(3)
	if not _check("potion.fixture.paused", g.no_saves and not g.net_online() and not g.dev_god
			and g.chapter_id == "ch3" and p.potion_slot_cap() == 2 and g.get_tree().paused
			and m.current == "inventory" and p.can_process() == false, _state()):
		return "requires the paused two-slot no-save fixture"
	var original: Dictionary = _potion_ledger(p)
	var message_before: String = m._potion_msg
	var mana: Dictionary = Items.make_potion("mana", "instant", "F", "accord")
	var might: Dictionary = Items.make_potion("might", "buff", "F", "accord")
	# Temporary display stock and a partly spent room/cooldown fixture. No
	# inventory award, purchase, drink, room refill, or save API is called.
	p.consumables = [Items.make_potion("health", "instant", "F", "accord"),
		mana, mana.duplicate(true), might]
	p.potion_rotation = []
	p.active_potion = "health"
	p.room_potions = {"health": 1}
	p.potion_cd = 1.75
	m._potion_msg = ""
	var unchanged: Dictionary = _potion_ledger(p)
	unchanged.erase("rotation")
	var error: String = await _potion_slot_cases(p, String(mana.id), String(might.id), unchanged)
	# All returned failures restore through this one path while the menu still
	# pauses the hero. The outer run() owns settings/emulation and final close.
	p.consumables = original.consumables.duplicate(true)
	p.potion_rotation = original.rotation.duplicate(true)
	p.active_potion = String(original.active)
	p.room_potions = original.room_potions.duplicate(true)
	p.potion_cd = float(original.potion_cd)
	m._potion_msg = message_before
	_check("potion.fixture.restored", _potion_ledger(p) == original and m._potion_msg == message_before,
		{"hero_restored": _potion_ledger(p) == original, "message_restored": m._potion_msg == message_before})
	return error


func _potion_slot_cases(p: Player, mana_id: String, might_id: String, unchanged: Dictionary) -> String:
	for touch in [false, true]:
		var mode: String = "touch" if touch else "mouse"
		g.settings["touch_controls"] = touch
		g.refresh_touch_mode()
		g._apply_touch_mode()
		m.open_inventory("potions")
		await r.frames(3)
		if not _check("potion." + mode + ".mode", g.touch_mode == touch
				and Input.emulate_mouse_from_touch, {"touch_mode": g.touch_mode,
				"mouse_from_touch": Input.emulate_mouse_from_touch}):
			return "requested potion pointer mode unavailable"
		_potion_plan(p, "potion." + mode + ".initial", ["health", "health"], unchanged)
		# Every assignment and transition below is a real visible Button press.
		var actions: Array[Dictionary] = [
			{"id": "add_mana_first", "kind": "owned", "value": mana_id, "plan": [mana_id, "health"]},
			{"id": "add_mana_second", "kind": "owned", "value": mana_id, "plan": [mana_id, mana_id]},
			{"id": "clear_duplicate_second", "kind": "slot", "value": "2", "plan": [mana_id, "health"]},
			{"id": "reset", "kind": "reset", "value": "", "plan": ["health", "health"]},
			{"id": "add_unique_mana", "kind": "owned", "value": mana_id, "plan": [mana_id, "health"]},
			{"id": "add_unique_might", "kind": "owned", "value": might_id, "plan": [mana_id, might_id]},
			{"id": "clear_unique_second", "kind": "slot", "value": "2", "plan": [mana_id, "health"]},
			{"id": "clear_unique_first", "kind": "slot", "value": "1", "plan": ["health", "health"]},
			{"id": "empty_first", "kind": "slot", "value": "1", "plan": [Player.LOADOUT_EMPTY, "health"]},
			{"id": "default_first", "kind": "slot", "value": "1", "plan": ["health", "health"]},
		]
		for action: Dictionary in actions:
			var id := "potion." + mode + "." + String(action.id)
			r.step(id)
			if not await _potion_press(p, id, String(action.kind), String(action.value), touch):
				return "native potion control unavailable: " + id
			_potion_plan(p, id, action.plan, unchanged, action.id == "clear_duplicate_second")
			if action.id in ["add_mana_second", "clear_duplicate_second"]:
				await _capture(mode + ("_01_duplicate_plan" if action.id == "add_mana_second" else "_02_selected_second_cleared"))
	return ""


func _potion_press(p: Player, id: String, kind: String, value: String, touch: bool) -> bool:
	var found: Array[Button] = []
	for node in m.root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			continue
		var matches := false
		if kind == "slot":
			matches = button.tooltip_text.begins_with("Slot " + value + " — ")
		elif kind == "owned":
			matches = button.tooltip_text.begins_with(p.potion_display_name(value) + "\n") \
				and button.tooltip_text.contains("Select: assign to the next free slot")
		else:
			matches = button.text.contains("Reset every slot to the default")
		if matches:
			found.append(button)
	var rect := Rect2()
	var visible := Rect2()
	if found.size() == 1:
		rect = found[0].get_global_rect()
		visible = rect
		var ancestor: Node = found[0].get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is Control and ancestor.clip_contents:
				visible = visible.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	# Existing Reset is a desktop-sized stock _btn (28px); it is a setup
	# control, not a touch-target acceptance claim. Slot/owned tiles must be44px.
	var minimum: float = 1.0 if kind == "reset" else 44.0
	if not _check(id + ".target", found.size() == 1 and rect.size.x >= minimum and rect.size.y >= minimum
			and visible.grow(0.5).encloses(rect) and m._shell_rect.grow(0.5).encloses(rect)
			and viewport.grow(0.5).encloses(rect), {"matches": found.size(), "rect": str(rect),
			"visible": str(visible), "kind": kind, "fixture_reset_only": kind == "reset"}):
		return false
	if touch:
		await _touch(rect.get_center())
	else:
		await _mouse(rect.get_center())
	await r.frames(3)
	return _check(id + ".input_gate", m.current == "inventory" and m.is_open() and g.get_tree().paused
		and not p.can_process() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), _state())


func _potion_plan(p: Player, id: String, expected: Array, unchanged: Dictionary, known := false) -> void:
	var expected_rotation: Array = []
	for entry in expected:
		expected_rotation.append("" if entry == "health" else entry)
	while not expected_rotation.is_empty() and expected_rotation.back() == "":
		expected_rotation.pop_back()
	var exact: bool = p.potion_loadout() == expected and p.potion_rotation == expected_rotation
	var actual := {"plan": p.potion_loadout(), "rotation": p.potion_rotation.duplicate(),
		"expected": expected, "expected_rotation": expected_rotation}
	if known:
		_probe(id + ".plan", exact, actual)
	else:
		_check(id + ".plan", exact, actual)
	var economy: Dictionary = _potion_ledger(p)
	economy.erase("rotation")
	_check(id + ".unchanged", economy == unchanged, {"unchanged": economy == unchanged,
		"stock": p.consumables.size(), "room_potions": p.room_potions.duplicate(),
		"potion_cd": p.potion_cd, "active": p.active_potion})


func _potion_ledger(p: Player) -> Dictionary:
	return {"rotation": p.potion_rotation.duplicate(true), "active": p.active_potion,
		"consumables": p.consumables.duplicate(true), "materials": p.materials.duplicate(true),
		"gold": p.gold, "mastery": p.mastery.duplicate(true), "blueprints": p.blueprints.duplicate(true),
		"profession": p.profession, "favor": p.npc_favor.duplicate(true),
		"backpack": p.backpack.duplicate(true), "equipment": p.equipment.duplicate(true),
		"gems": p.gem_bag.duplicate(true), "bags": p.bags.duplicate(true), "loose_bags": p.loose_bags.duplicate(true),
		"mailbox": g.mailbox.duplicate(true), "dropped_loot": g.dropped_loot.duplicate(true),
		"room_potions": p.room_potions.duplicate(true), "potion_cd": p.potion_cd,
		"potion_swap_cd": p.potion_swap_cd, "ability_cds": p.cds.duplicate(true),
		"hp": p.hp, "mp": p.mp, "level": p.level, "xp": p.xp,
		"skill_points": p.skill_points, "tree_points": p.tree_points.duplicate(true), "unspent_attr": p.unspent_attr,
		"flags": g.flags.duplicate(true), "chapter": g.chapter_id, "no_saves": g.no_saves}


func _binding_cancel() -> void:
	r.step("Escape cancels actual keybind capture without changing binds")
	m.open_settings("pause")
	await r.frames(3)
	if not await _button("Keybinds"):
		return
	var before: Dictionary = g.binds.duplicate(true)
	if not await _button("Ability 1"):
		return
	_check("keybind.capture_started", m.listening_action == "a1", m.listening_action)
	await _key(KEY_ESCAPE)
	_check("keybind.escape_cancels_capture", m.current == "keybinds" and m.listening_action == "" and g.binds == before, _state())
	await _key(KEY_ESCAPE)
	_probe("keybind.second_escape_returns", m.current == "settings", _state())
	# Leaving by the visible Back button must end capture before any later key
	# can change a binding. Do NOT type while probing a leaked capture: save_binds
	# writes directly to user:// even when Game.no_saves is true.
	m.open_settings("pause")
	await r.frames(3)
	if not await _button("Keybinds"):
		return
	if not await _button("Ability 1"):
		return
	_check("keybind.back_capture_started", m.listening_action == "a1", m.listening_action)
	await _button("Back to settings")
	_probe("keybind.visible_back_ends_capture", m.current == "settings" and m.listening_action == "" and g.binds == before, {"menu": m.current, "listening": m.listening_action, "binds_preserved": g.binds == before})
	m.listening_action = "" # fixture cleanup, especially before baseline printable input
	_check("keybind.no_bind_changes", g.binds == before, g.binds)


func _input_edges() -> void:
	r.step("outside wheel input, raw touch and gamepad back")
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		m.open_settings("pause")
		await r.frames(3)
		var shell: Control = m.root
		await _wheel(button, Vector2(12, 12))
		_probe("settings.outside_wheel.%d" % button, m.current == "settings" and is_instance_valid(shell) and m.root == shell, _state())
	var emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	m.open_settings("pause")
	await r.frames(3)
	await _touch(Vector2(12, 12))
	await r.frames(3)
	_probe("settings.raw_touch_once", m.current == "pause" and m.is_open(), _state())
	cancel_calls = 0
	yes_calls = 0
	m.open_confirm("QA: raw touch cancellation", func() -> void: yes_calls += 1, func() -> void:
		cancel_calls += 1
		m.open_inventory())
	await r.frames(3)
	await _touch(Vector2(12, 12))
	await r.frames(3)
	_probe("confirm.raw_touch_once", cancel_calls == 1 and yes_calls == 0 and m.current == "inventory", {"cancel": cancel_calls, "yes": yes_calls, "menu": m.current})
	Input.emulate_mouse_from_touch = emulation
	m.open_settings("pause")
	await r.frames(3)
	await _joy_back()
	_check("settings.gamepad_back", m.current == "pause", _state())
	cancel_calls = 0
	yes_calls = 0
	m.open_confirm("QA: controller cancellation", func() -> void: yes_calls += 1, func() -> void:
		cancel_calls += 1
		m.open_inventory())
	await r.frames(3)
	await _joy_back()
	_probe("confirm.gamepad_back_once", cancel_calls == 1 and yes_calls == 0 and m.current == "inventory", {"cancel": cancel_calls, "yes": yes_calls, "menu": m.current})


func _wheel(button: int, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
	wheel_taps += 1
	await r.frames(3)


func _joy_back() -> void:
	# Match shot_controller: dispatch through the real adapter while independent
	# of whether the owner's foreground app currently holds native window focus.
	g.gamepad.focused = true
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 27
		event.button_index = JOY_BUTTON_B
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
	gamepad_taps += 1
	await r.frames(3)


func _talent_typing() -> void:
	r.step("focused talent-loadout rename through real printable key events")
	var before: Array = g.local_player.talent_loadouts.duplicate(true)
	var old_skills: int = int(g.binds["skills"])
	for close_key in [KEY_T, KEY_J]:
		g.binds["skills"] = close_key
		m._talent_renaming = false
		m.open_skills()
		await r.frames(3)
		if not await _button("RENAME"):
			break
		var field: LineEdit = _field(m.root)
		if not _check("talent.field_exists.%d" % close_key, field != null, "actual loadout rename field"):
			break
		await _mouse(field.get_global_rect().get_center())
		field.select_all()
		var typed := ""
		# The bound menu key is LAST so baseline retains evidence of ordinary typing.
		var sample := "imecjt" if close_key == KEY_T else "timecj"
		for ch in sample:
			typed += ch
			await _key(ch.to_upper().unicode_at(0), ch.unicode_at(0))
			var actual: String = field.text if is_instance_valid(field) else "<field destroyed>"
			_probe("talent.printable.%d.%s" % [close_key, ch], is_instance_valid(field) and m.current == "skills" and actual == typed, {"text": actual, "expected": typed, "menu": m.current})
			if not is_instance_valid(field) or m.current != "skills":
				break
		if close_key == KEY_T:
			await _capture("04_talent_rename_typing")
		if is_instance_valid(field) and m.current == "skills":
			await _key(KEY_ENTER)
			_check("talent.enter_saves.%d" % close_key, m.current == "skills" and String(g.local_player.talent_loadouts[g.local_player.active_talent_loadout].name) == typed, typed)
			await _key(KEY_ESCAPE)
			_check("talent.escape_closes.%d" % close_key, not m.is_open(), _state())
	g.binds["skills"] = old_skills
	g.local_player.talent_loadouts = before
	m._talent_renaming = false


func _text_regression(id: String, sample: String, known_defect: bool) -> void:
	var field: LineEdit = _field(m.root)
	if not _check(id + ".field_exists", field != null, "actual LineEdit"):
		return
	await _mouse(field.get_global_rect().get_center())
	field.select_all()
	for ch in sample:
		await _key(ch.to_upper().unicode_at(0), ch.unicode_at(0))
	var actual: String = field.text if is_instance_valid(field) else "<field destroyed>"
	var passed := is_instance_valid(field) and m.current == id and actual == sample
	if known_defect:
		_probe(id + ".typing", passed, actual)
	else:
		_check(id + ".typing", passed, actual)


func _mail_cancellation() -> void:
	r.step("cancel unclaimed mail deletion through every native back path")
	var before: Array = g.mailbox.duplicate(true)
	var letter := {"subject": "Navigation QA parcel", "body": "This unclaimed parcel must survive every cancellation.", "items": [{"kind": "material", "family": "metal", "grade": "F", "count": 3}], "sent_at": g.trusted_now(), "read": true}
	var expected_letter: Dictionary = letter.duplicate(true)
	g.mailbox = [letter]
	for method in ["cancel", "escape", "x", "outside", "touch_outside"]:
		UIMailbox.open_letter(m, letter)
		await r.frames(3)
		if not await _button("Delete letter"):
			break
		_check("mail.confirm_opens." + method, m.current == "confirm", _state())
		await _exit(method)
		_probe("mail.cancel_returns." + method, m.current == "mail_letter" and _has_label(m.root, "Navigation QA parcel"), _state())
		_check("mail.contents_survive." + method, g.mailbox.size() == 1 and g.mailbox[0] == expected_letter, g.mailbox)
		if method == "escape":
			await _capture("05_mail_cancel")
	g.mailbox = before


func _callback_lifetime() -> void:
	r.step("confirmation cancellation runs once and does not leak into later panels")
	cancel_calls = 0
	yes_calls = 0
	m.open_confirm("QA: cancellation callback lifetime", func() -> void: yes_calls += 1, func() -> void:
		cancel_calls += 1
		m.open_inventory())
	await r.frames(3)
	await _exit("touch_outside")
	_probe("confirm.callback_once", cancel_calls == 1 and yes_calls == 0 and m.current == "inventory", {"cancel": cancel_calls, "yes": yes_calls, "menu": m.current})
	var count_after := cancel_calls
	m.open_settings("pause")
	await r.frames(3)
	await _exit("x")
	_check("confirm.no_stale_callback", cancel_calls == count_after and yes_calls == 0, {"cancel": cancel_calls, "yes": yes_calls})
	await _capture("06_cancel_then_settings")


func _exit(method: String) -> void:
	match method:
		"escape": await _key(KEY_ESCAPE)
		"back": await _button("Back")
		"cancel": await _button("Cancel")
		"x":
			var button: Button = _find_button(m.root, "✕", true)
			if _check("input.x_present.%d" % rows.size(), button != null, _state()):
				await _mouse(button.get_global_rect().get_center())
		"outside": await _mouse(Vector2(12, 12))
		"touch_outside": await _touch(Vector2(12, 12))
	await r.frames(3)


func _roster_delete() -> void:
	# Preserve all slot files, even on a failed assertion in the helper.
	var files := {}
	var path := SaveGame.path(SaveGame.MAX_SLOTS)
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = path + suffix
		files[file] = FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else null
	var fixture := {"version": SaveGame.VERSION, "saved_at": 0,
		"character": {"name": "Roster Safety", "cls": "warrior", "level": 7},
		"world": {"quest_key": "talk"}}
	for suffix in ["", ".bak", ".tmp"]:
		var f := FileAccess.open(path + suffix, FileAccess.WRITE)
		f.store_string(JSON.stringify(fixture))
		f.close()
	await _roster_delete_checks(path)
	for file: String in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(file)
		else:
			var f := FileAccess.open(file, FileAccess.WRITE)
			f.store_buffer(files[file])
			f.close()
	m.open_slots()
	await r.frames(3)


func _roster_delete_checks(path: String) -> void:
	for action in ["escape", "cancel", "accept"]:
		m.open_slots()
		await r.frames(3)
		var hero: Button = _find_button(m.root, "Roster Safety")
		if not _check("roster.delete.hero." + action, hero != null, _state()):
			return
		var erase: Button = _find_button(hero.get_parent(), "✕", true)
		if not _check("roster.delete.button." + action, erase != null, _state()):
			return
		# Native click on this hero's row, never the shell's similarly named X.
		var ancestor: Node = hero.get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(erase)
				await r.frames(2)
			ancestor = ancestor.get_parent()
		await _mouse(erase.get_global_rect().get_center())
		await r.frames(3)
		if not _check("roster.delete.confirm." + action, m.current == "confirm" and SaveGame.exists(SaveGame.MAX_SLOTS), _state()):
			return
		_confirm_geometry("roster_delete_" + action,
			"Delete Roster Safety (Warrior Lv 7)? This cannot be undone.", true, false, "Delete hero?", "Delete hero")
		_check("roster.delete.safe_focus." + action,
			m.get_viewport().gui_get_focus_owner() == _find_button(m.root, "Cancel", true), "Cancel owns initial focus")
		_check("roster.delete.boot_pause." + action, g.get_tree().paused and not g.hud.visible, _state())
		if action == "escape":
			await _capture("01a_roster_delete_confirm")
			await _key(KEY_ESCAPE)
		elif action == "cancel":
			await _button("Cancel")
		else:
			await _button("Delete hero")
		_check("roster.delete.return." + action,
			m.current == "title" and m.title_stage == "slots" and g.get_tree().paused and not g.hud.visible, _state())
		for suffix in ["", ".bak", ".tmp"]:
			_check("roster.delete.file." + action + suffix,
				FileAccess.file_exists(path + suffix) == (action != "accept"), path + suffix)


func _button(label: String) -> bool:
	var button: Button = _find_button(m.root, label)
	if not _check("input.button.%d" % rows.size(), button != null, label):
		return false
	var ancestor: Node = button.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await r.frames(2)
		ancestor = ancestor.get_parent()
	await _mouse(button.get_global_rect().get_center())
	await r.frames(3)
	return true


func _mouse(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
	mouse_clicks += 1


func _touch(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
	touch_taps += 1


func _key(code: int, unicode_value := 0) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
	key_taps += 1
	await r.frames(2)


func _find_button(node: Node, text_value: String, exact := false) -> Button:
	if not is_instance_valid(node):
		return null
	if node is Button and node.is_visible_in_tree() and not node.disabled:
		var matches: bool = node.text.strip_edges() == text_value if exact else node.text.contains(text_value)
		if matches:
			return node
	for child in node.get_children():
		var found: Button = _find_button(child, text_value, exact)
		if found != null:
			return found
	return null


func _field(node: Node) -> LineEdit:
	if not is_instance_valid(node):
		return null
	if node is LineEdit and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found: LineEdit = _field(child)
		if found != null:
			return found
	return null


func _has_label(node: Node, value: String) -> bool:
	if not is_instance_valid(node):
		return false
	if node is Label and node.text == value:
		return true
	for child in node.get_children():
		if _has_label(child, value):
			return true
	return false


func _state() -> Dictionary:
	return {"menu": m.current, "stage": m.title_stage, "root": m.is_open(), "paused": g.get_tree().paused, "hud": g.hud.visible, "settings_return": m.settings_return}


func _settings_except_touch(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(true)
	copy.erase("touch_controls")
	return copy


func _settings_layout(id: String) -> void:
	var escaped: Array[Dictionary] = []
	var nodes: Array[Node] = [m.root]
	var screen := Rect2(Vector2.ZERO, m.get_viewport().get_visible_rect().size)
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children():
			nodes.append(child)
		if not (node is Button or node is Label or node is Slider) or not node.is_visible_in_tree():
			continue
		var rect: Rect2 = node.get_global_rect()
		var ancestor: Node = node.get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is Control and ancestor.clip_contents:
				rect = rect.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if rect.has_area() and (not m._shell_rect.grow(2).encloses(rect) or not screen.encloses(rect)):
			escaped.append({"text": String(node.text) if node is Button or node is Label else node.name, "rect": str(rect)})
	_probe("settings.layout." + id, escaped.is_empty(), escaped)


func _check(id: String, passed: bool, actual: Variant) -> bool:
	rows.append({"id": id, "passed": passed, "known_defect": false, "actual": actual})
	print("MENU CHECK %s: %s %s" % [id, "PASS" if passed else "FAIL", str(actual) if not passed else ""])
	return passed


func _probe(id: String, passed: bool, actual: Variant) -> void:
	rows.append({"id": id, "passed": passed, "known_defect": true, "actual": actual})
	print("MENU PROBE %s: %s %s" % [id, "PASS" if passed else ("FINDING" if r.flag("baseline") else "FAIL"), str(actual) if not passed else ""])


func _capture(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "native pointer/key/touch input; fixture menu open; no_saves")


func _report() -> Dictionary:
	var result := {"checks": rows.size(), "passed": 0, "findings": 0, "failures": 0, "mouse_clicks": mouse_clicks, "touch_taps": touch_taps, "key_taps": key_taps, "wheel_taps": wheel_taps, "gamepad_taps": gamepad_taps, "baseline": r.flag("baseline"), "rows": rows}
	for row in rows:
		if row.passed:
			result.passed += 1
		elif row.known_defect and r.flag("baseline"):
			result.findings += 1
		else:
			result.failures += 1
	var directory: String = ProjectSettings.globalize_path(r.shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
	else:
		result.failures += 1
		print("MENU CHECK report.write: FAIL")
	return result

## Controlled native confirmation proof. Actual caller copy and callbacks are
## exercised against a loaned solo character; this is not ordinary progression.
func _confirm_layout() -> String:
	if not _check("confirm_layout.fixture", g.no_saves and not g.net_online()
			and not r.flag("baseline") and not r.flag("no-capture"), "strict isolated solo; original captures required"):
		return "confirmation proof requires strict solo capture"
	m.pick_chapter("ch1")
	await r.frames(3)
	m.pick_class("warrior")
	await r.frames(5)
	await r.skip_dialogue()
	g.play_started = true
	g.dev_god = true
	g.hud.visible = true
	await r.frames(3)
	# The opener's resonance choice pays its reward as world coins that magnet
	# in over the next moments. Take the ledger baseline only once they land,
	# or the invariant below races the collection (gold 15 before, 47 after).
	var coin_deadline := Time.get_ticks_msec() + 5000
	while _loose_coins() > 0 and Time.get_ticks_msec() < coin_deadline:
		await r.frames(2)
	_check("confirm_layout.opening_coins_collected", _loose_coins() == 0,
		{"loose_coins": _loose_coins(), "paused": g.get_tree().paused})
	var economy: Dictionary = _confirm_economy()
	await _confirm_actual_callers()
	await _confirm_trial_preview()
	await _confirm_first_draw()
	await _confirm_long_stress()
	await _confirm_native_routes()
	await _confirm_stale_callable()
	await _callback_lifetime()
	await _notice_suite()
	_check("confirm_layout.economy_unchanged", _confirm_economy() == economy, {"before": economy, "after": _confirm_economy()})
	return ""


## Controlled callback fixtures; actual online admission is in alchemy_enet_ui.
func _notice_suite() -> void:
	r.step("controlled notice: single safe action and native cancellation routes")
	for route in ["mouse", "escape", "controller", "raw_touch"]:
		yes_calls = 0
		cancel_calls = 0
		m.open_notice("Controlled notice", "Controlled notice body. No affirmative action is exposed.",
			func() -> void:
				cancel_calls += 1
				m.open_inventory())
		await RenderingServer.frame_post_draw
		var initial: Rect2 = _confirm_panel_rect()
		_notice_geometry("controlled_" + route, "Controlled notice", "Controlled notice body. No affirmative action is exposed.")
		await r.frames(3)
		_check("notice.first_frame_stable." + route, _confirm_panel_rect() == initial, str(initial))
		await _capture("21_notice_" + route)
		match route:
			"mouse": await _button("Back to game")
			"escape": await _key(KEY_ESCAPE)
			"controller": await _joy_back()
			"raw_touch":
				var emulation: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await _touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulation
		await r.frames(3)
		_check("notice.close_once." + route, cancel_calls == 1 and yes_calls == 0 and m.current == "inventory", _state())
		m.open_settings("pause")
		await r.frames(3)
		await _key(KEY_ESCAPE)
		_check("notice.no_extra_lifetime." + route, cancel_calls == 1 and yes_calls == 0 and m.current == "pause", _state())
	m.open_notice("Controlled notice", "Default close returns to gameplay.")
	await r.frames(3)
	await _key(KEY_ESCAPE)
	_check("notice.default_close_no_pause", not m.is_open() and not g.get_tree().paused, _state())
	cancel_calls = 0
	m.open_notice("Controlled notice", "Retained close callback probe.", func() -> void: cancel_calls += 1)
	await r.frames(3)
	var button: Button = _find_button(m.root, "Back to game", true)
	if not _check("notice.retained.button", button != null, "Back to game"): return
	var links: Array[Dictionary] = button.get_signal_connection_list("pressed")
	if not _check("notice.retained.connections", links.size() == 2, links.size()): return
	var old_callable: Callable = links[1].callable
	if not _check("notice.retained.callable_valid", old_callable.is_valid(), "sfx then action"): return
	m.open_inventory()
	var destination: Control = m.root
	# Invoke before queue_free drains, as in the existing confirmation lifetime test.
	old_callable.call()
	await r.frames(4)
	_check("notice.retained.no_effect", cancel_calls == 0 and m.root == destination and m.current == "inventory", _state())
	var successor_rect: Rect2 = m._shell_rect
	await r.frames(3)
	_check("notice.retained.successor_stable", m.root == destination and m._shell_rect == successor_rect, str(successor_rect))
	await _capture("22_notice_successor")
	cancel_calls = 0
	m.open_notice("Controlled notice", "Enter without a selection must not invoke an action.", func() -> void: cancel_calls += 1)
	await r.frames(3)
	_notice_geometry("enter", "Controlled notice", "Enter without a selection must not invoke an action.")
	_check("notice.safe_initial_focus", _find_button(m.root, "Back to game", true) != m.get_viewport().gui_get_focus_owner(), "no action initially focused")
	await _key(KEY_ENTER)
	_check("notice.enter_safe", m.current == "confirm" and cancel_calls == 0 and yes_calls == 0, _state())
	await _key(KEY_ESCAPE)
	_check("notice.enter_then_escape_once", not m.is_open() and cancel_calls == 1 and yes_calls == 0, _state())


## Exact visible single-action contract, independent of production sizing helpers.
func _notice_geometry(id: String, title: String, message: String) -> Dictionary:
	var heading: Label = _confirm_label(title)
	var body: Label = _confirm_label(message)
	var panel: Rect2 = _confirm_panel_rect()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	var result := {"panel": str(panel), "viewport": str(viewport)}
	var contents: Array[Button] = []
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if node is Button and node.is_visible_in_tree() and node.text.strip_edges() != "✕": contents.append(node)
	if not _check("notice." + id + ".nodes", m.current == "confirm" and heading != null and body != null
			and panel.has_area() and contents.size() == 1, {"title": title, "body": message, "content_buttons": contents.size()}): return result
	var back: Button = contents[0]
	_check("notice." + id + ".single_safe_action", back.text.strip_edges() == "Back to game" and not back.disabled, back.text)
	var heading_rect: Rect2 = heading.get_global_rect()
	var body_rect: Rect2 = body.get_global_rect()
	var back_rect: Rect2 = back.get_global_rect()
	_check("notice." + id + ".full_text", _confirm_glyphs_complete(heading) and _confirm_glyphs_complete(body)
		and heading.get_theme_font_size("font_size") >= 18 and body.get_theme_font_size("font_size") >= 18, message)
	_check("notice." + id + ".bounds", viewport.grow(0.5).encloses(panel)
		and panel.grow(0.5).encloses(heading_rect) and panel.grow(0.5).encloses(body_rect)
		and panel.grow(0.5).encloses(back_rect), result)
	var font: Font = back.get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1, back.get_theme_font_size("font_size"))
	var style: StyleBox = back.get_theme_stylebox("normal")
	_check("notice." + id + ".target44", back_rect.size.x >= 44.0 and back_rect.size.y >= 44.0
		and back_rect.size.x + 0.5 >= text_size.x + style.get_minimum_size().x
		and back_rect.size.y + 0.5 >= text_size.y + style.get_minimum_size().y, str(back_rect))
	_check("notice." + id + ".no_overlap", not heading_rect.intersects(body_rect)
		and not heading_rect.intersects(back_rect) and not body_rect.intersects(back_rect), result)
	var scroll: ScrollContainer = _confirm_body_scroll(body)
	if scroll != null:
		_check("notice." + id + ".body_visible_actions_outside", scroll.get_global_rect().grow(0.5).encloses(body_rect)
			and not scroll.is_ancestor_of(back) and not scroll.get_global_rect().intersects(back_rect), result)
	var text_issues: Array[String] = []
	nodes = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if node is Label and node != heading and node != body and node.is_visible_in_tree() and not node.text.is_empty():
			var rect: Rect2 = node.get_global_rect()
			if not _confirm_glyphs_complete(node) or not panel.grow(0.5).encloses(rect) or rect.intersects(heading_rect) or rect.intersects(body_rect) or rect.intersects(back_rect):
				text_issues.append(node.text)
	_check("notice." + id + ".other_text_clear", text_issues.is_empty(), text_issues)
	return result


func _confirm_actual_callers() -> void:
	r.step("actual mail deletion, pause exit and both endgame rules; controlled character and parcel")
	var before: Array = g.mailbox.duplicate(true)
	var letter := {"subject": "Confirm-layout parcel", "body": "Unclaimed loot must survive cancellation.",
		"items": [{"kind": "material", "family": "metal", "grade": "F", "count": 2}],
		"sent_at": g.trusted_now(), "read": true}
	var expected: Dictionary = letter.duplicate(true)
	g.mailbox = [letter]
	UIMailbox.open_letter(m, letter)
	await r.frames(3)
	if await _button("Delete letter"):
		_confirm_geometry("mail", "Delete this letter AND its unclaimed loot?", true, false, "Delete this letter?", "Delete letter")
		await _capture("10_confirm_mail_delete")
		await _button("Cancel")
		_check("confirm_layout.mail.return", m.current == "mail_letter" and _has_label(m.root, "Confirm-layout parcel"), _state())
		_check("confirm_layout.mail.intact", g.mailbox == [expected], g.mailbox)
	g.mailbox = before
	m.open_pause()
	await r.frames(3)
	if await _button("Exit to title"):
		_confirm_geometry("pause", "Exit to the title screen? Your progress is saved.", true, false, "Return to title?", "Return to title")
		await _capture("11_confirm_pause_exit")
		await _key(KEY_ESCAPE)
		_check("confirm_layout.pause.return", m.current == "pause" and g.get_tree().paused, _state())
	# Availability is controlled; these are actual pause callers, cancellation only.
	var endgame_before: bool = g.endgame_active
	var world_before: int = g.world.get_instance_id()
	var economy_before: Dictionary = _confirm_economy()
	for action in ["restart", "cashout", "abandon"]:
		g.endgame_active = action != "restart"
		m.open_pause()
		await r.frames(3)
		var target: String = "Restart chapter" if action == "restart" else ("Cash out & bank rewards" if action == "cashout" else "Exit to title")
		if await _button(target):
			var title: String = "Restart chapter?" if action == "restart" else ("Bank your rewards?" if action == "cashout" else "Abandon this run?")
			var accept: String = "Restart chapter" if action == "restart" else ("Cash out" if action == "cashout" else "Abandon run")
			var message: String = "Restart '%s' from the beginning? Story progress in this chapter resets — your character, gear and Resonance stay." % Story.chapter(g.chapter_id)["name"]
			if action == "cashout": message = "Collect this trial's rewards and end the run?\n\nGold is added to your character; any gems and gear are sent to your mailbox. You'll review the results before choosing Return to Crownfall."
			if action == "abandon": message = "Abandon this trial and return to the title?\n\nUnclaimed gold, gems and gear from this trial will be lost.\n\nTo collect them, cancel and choose Cash out & bank rewards from the pause menu."
			_confirm_geometry("pause_" + action, message, false, false, title, accept)
			await _capture("20_contextual_" + action)
			await _button("Cancel")
			_check("confirm_layout." + action + ".cancel", m.current == "pause" and g.get_tree().paused
				and g.world.get_instance_id() == world_before and _confirm_economy() == economy_before, _state())
	g.endgame_active = endgame_before
	for mode in ["crucible", "depths"]:
		var title: String = "The Crucible" if mode == "crucible" else "The Waking Depths"
		var rules: String = "Ten bosses back to back, each with an elite affix. HP and MP carry over between them. Bonus spoils at 3 / 6 / 10 kills." if mode == "crucible" else "An endless descent where depth is the monsters' level. The ladder starts at 40, or at your deepest cleared checkpoint. A boss guards every 5th depth, a checkpoint boss every 10th; past 100 the dark only deepens."
		var pb: Dictionary = g.endgame_pb(mode, g.local_player.cls)
		var best := ""
		if not pb.is_empty():
			best = "\n\nYour best: %d bosses." % int(pb.get("kills", 0)) if mode == "crucible" else "\n\nYour deepest: depth %d." % int(pb.get("depth", 0))
		var ending: String = "When you cash out, fall, or clear all ten bosses, a results screen offers a return to Crownfall." if mode == "crucible" else "When you cash out or fall, your rewards pay out and a results screen offers a return to Crownfall."
		var message := "Enter %s?\n\n%s%s\n\n%s" % [title, rules, best, ending]
		m.confirm_endgame(mode)
		await r.frames(4)
		_confirm_geometry("endgame_" + mode, message, false, false, "Enter %s?" % title, "Enter trial")
		await _capture("12_confirm_endgame_" + mode)
		await _button("Cancel")
		_check("confirm_layout.endgame." + mode + ".return", not m.is_open() and not g.endgame_active and not g.get_tree().paused, _state())


func _confirm_trial_preview() -> void:
	# Controlled pending balances on an actual paused Endgame, never earned rewards.
	r.step("actual trial reward preview; controlled balances, native callers and cancellation")
	var original_endgame: Endgame = g.endgame
	var original_active: bool = g.endgame_active
	var was_paused: bool = g.get_tree().paused
	m.open_pause()
	await r.frames(3)
	_check("confirm_layout.trial_preview.paused_setup", g.get_tree().paused, _state())
	var trial := Endgame.new()
	trial.game = g
	trial.mode = "crucible"
	g.add_child(trial)
	g.endgame = trial
	g.endgame_active = true
	var cases := [
		{"id": "populated", "gold": 1234567, "gems": [1, 2], "gear": ["F"], "active": true,
			"token": "1,234,567 gold, 2 gems and 1 gear piece."},
		{"id": "zero", "gold": 0, "gems": [], "gear": [], "active": true,
			"token": "0 gold, 0 gems and 0 gear pieces."},
		{"id": "inactive", "gold": 999, "gems": [1], "gear": ["F"], "active": false,
			"token": ""}]
	for sample: Dictionary in cases:
		trial.pending_gold = int(sample.gold)
		trial.pending_gems = sample.gems.duplicate()
		trial.pending_gear = sample.gear.duplicate()
		trial.active = bool(sample.active)
		for action in ["cashout", "abandon"]:
			var id: String = "trial_preview." + String(sample.id) + "." + action
			var cash: bool = action == "cashout"
			var question: String = "Collect this trial's rewards and end the run?" if cash else "Abandon this trial and return to the title?"
			var lead: String = "To bank:" if cash else "Lost if you abandon:"
			m.open_pause()
			await r.frames(3)
			var before: Dictionary = _trial_preview_state(trial)
			if await _button("Cash out & bank rewards" if cash else "Exit to title"):
				var body: Label = _trial_find_body(question)
				if _check("confirm_layout." + id + ".rendered_body", body != null, question):
					if bool(sample.active):
						_check("confirm_layout." + id + ".tally", body.text.count(lead + " " + String(sample.token)) == 1, body.text)
					else:
						_check("confirm_layout." + id + ".tally_absent", not body.text.contains("To bank:")
							and not body.text.contains("Lost if you abandon:"), body.text)
					_confirm_geometry(id, body.text, false, false,
						"Bank your rewards?" if cash else "Abandon this run?", "Cash out" if cash else "Abandon run")
					if sample.id == "populated" or (sample.id == "zero" and cash):
						await _capture("23_trial_preview_" + String(sample.id) + "_" + action)
				_check("confirm_layout." + id + ".open_read_only", _trial_preview_state(trial) == before, _trial_preview_state(trial))
				await _button("Cancel")
				_check("confirm_layout." + id + ".cancel_returns_pause", m.current == "pause" and g.get_tree().paused, _state())
			_check("confirm_layout." + id + ".cancel_read_only", _trial_preview_state(trial) == before, _trial_preview_state(trial))
	# No early return: restore the original controller before any unpaused frame.
	m.close()
	g.endgame = original_endgame
	g.endgame_active = original_active
	trial.active = false
	trial.queue_free()
	g.request_pause(was_paused)
	_check("confirm_layout.trial_preview.controller_restored", g.endgame == original_endgame
		and g.endgame_active == original_active and g.get_tree().paused == was_paused, _state())
	_check("confirm_layout.trial_preview.original_survives", original_endgame == null
		or (is_instance_valid(original_endgame) and not original_endgame.is_queued_for_deletion()), "original controller retained")
	await r.frames(3)


func _trial_preview_state(trial: Endgame) -> Dictionary:
	return {"economy": _confirm_economy(), "mailbox": g.mailbox.duplicate(true),
		"meta": g._meta.duplicate(true), "loot_rng": g.loot_rng.state, "trial_rng": trial._rng.state,
		"gold": trial.pending_gold, "gems": trial.pending_gems.duplicate(true),
		"gear": trial.pending_gear.duplicate(true), "active": trial.active,
		"controller": g.endgame.get_instance_id(), "available": g.endgame_active,
		"world": g.world.get_instance_id(), "paused": g.get_tree().paused}


func _trial_find_body(question: String) -> Label:
	var nodes: Array[Node] = [m.root]
	var hits: Array[Label] = []
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if not is_instance_valid(node): continue
		if node is Label and node.is_visible_in_tree() and node.text.begins_with(question):
			hits.append(node)
		for child in node.get_children(): nodes.append(child)
	return hits[0] if hits.size() == 1 else null



func _confirm_first_draw() -> void:
	r.step("first drawn short shell and immediate replacement before deferred layout")
	# An already open parent removes the unrelated gameplay shell-entry tween.
	m.open_inventory()
	await r.frames(3)
	var message := "QA: short confirmation copy."
	m.open_confirm(message, func() -> void: yes_calls += 1)
	await RenderingServer.frame_post_draw
	var first: Dictionary = _confirm_geometry("short_first_draw", message, true)
	_check("confirm_layout.short.safe_initial_focus", m.get_viewport().gui_get_focus_owner() != _find_button(m.root, "Yes — do it", true), "destructive action never auto-focused")
	r.shot("13_confirm_short_first_draw", "controlled confirmation; first frame_post_draw after open; no size metadata trusted")
	await r.frames(5)
	await RenderingServer.frame_post_draw
	var settled: Dictionary = _confirm_geometry("short_settled", message, true)
	_check("confirm_layout.short.no_layout_jump", first == settled, {"first": first, "settled": settled})
	r.shot("14_confirm_short_settled", "controlled short confirmation; settled original")
	await _button("Cancel")
	m.open_inventory()
	await r.frames(4)
	var reference: Rect2 = _confirm_panel_rect()
	m.open_confirm("QA: replaced before its deferred layout runs.", func() -> void: yes_calls += 1)
	m.open_inventory()
	var destination: Control = m.root
	await RenderingServer.frame_post_draw
	var first_successor: Rect2 = _confirm_panel_rect()
	await r.frames(6)
	_check("confirm_layout.deferred_successor_untouched", m.root == destination and m.current == "inventory"
		and reference == first_successor and reference == _confirm_panel_rect(),
		{"reference": str(reference), "first": str(first_successor), "later": str(_confirm_panel_rect()), "menu": m.current})


func _confirm_long_stress() -> void:
	r.step("controlled long copy: all glyphs shaped, native wheel and touch reach, fixed visible actions")
	# Match the existing settings_touch_live desktop capability fixture: Godot
	# enables ScrollContainer touch dragging through both emulation flags.
	var capability_before: bool = Input.emulate_touch_from_mouse
	var mode_before: bool = g.settings.get("touch_controls", false)
	Input.emulate_touch_from_mouse = true
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	_check("confirm_layout.long.touch_capability", DisplayServer.is_touchscreen_available()
		and Input.emulate_mouse_from_touch and g.touch_mode, "host touch-capability emulation, not physical hardware")
	var body := ""
	for index in range(22):
		body += "Paragraph %d: Read the complete terms before choosing. Cancelling keeps your character and rewards unchanged.\n\n" % index
	body += "FINAL TERMS: This is the end of the controlled scroll test."
	m.open_confirm(body, func() -> void: yes_calls += 1)
	await RenderingServer.frame_post_draw
	_confirm_geometry("long_first_draw", body, false, true)
	r.shot("15_confirm_long_first_draw", "controlled synthetic stress copy; first drawn frame")
	await r.frames(4)
	var label: Label = _confirm_label(body)
	var scroll: ScrollContainer = _confirm_body_scroll(label)
	if not _check("confirm_layout.long.scroller", scroll != null and label != null, "native ancestor ScrollContainer required"):
		Input.emulate_touch_from_mouse = capability_before
		g.settings["touch_controls"] = mode_before
		g.refresh_touch_mode()
		g._apply_touch_mode()
		return
	var actions: Rect2 = _confirm_actions_rect()
	_check("confirm_layout.long.overflow", scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page
		and not _confirm_tail_visible(label, scroll), {"max": scroll.get_v_scroll_bar().max_value, "page": scroll.get_v_scroll_bar().page})
	var wheel_count := 0
	while wheel_count < 180 and not _confirm_tail_visible(label, scroll):
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN, scroll.get_global_rect().get_center())
		wheel_count += 1
	_check("confirm_layout.long.wheel_reaches_tail", _confirm_tail_visible(label, scroll), {"wheel_events": wheel_count, "scroll": scroll.scroll_vertical})
	_confirm_geometry("long_wheel_end", body, false, true)
	_check("confirm_layout.long.actions_fixed_wheel", actions == _confirm_actions_rect(), str(_confirm_actions_rect()))
	await _capture("16_confirm_long_wheel_end")
	var up_count := 0
	while up_count < 180 and scroll.scroll_vertical > 0:
		await _wheel(MOUSE_BUTTON_WHEEL_UP, scroll.get_global_rect().get_center())
		up_count += 1
	_check("confirm_layout.long.native_reset_top", scroll.scroll_vertical == 0 and not _confirm_tail_visible(label, scroll), scroll.scroll_vertical)
	var drag_count := 0
	while drag_count < 32 and not _confirm_tail_visible(label, scroll):
		var rect: Rect2 = scroll.get_global_rect()
		await _confirm_touch_drag(Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.85),
			Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.15))
		drag_count += 1
	_check("confirm_layout.long.touch_reaches_tail", _confirm_tail_visible(label, scroll), {"drag_gestures": drag_count, "scroll": scroll.scroll_vertical})
	_confirm_geometry("long_touch_end", body, false, true)
	_check("confirm_layout.long.actions_fixed_touch", actions == _confirm_actions_rect(), str(_confirm_actions_rect()))
	await _capture("17_confirm_long_touch_end")
	await _button("Cancel")
	_check("confirm_layout.long.cancel_return", m.current == "pause", _state())
	Input.emulate_touch_from_mouse = capability_before
	g.settings["touch_controls"] = mode_before
	g.refresh_touch_mode()
	g._apply_touch_mode()


func _confirm_native_routes() -> void:
	r.step("real mouse, Escape, controller and raw-touch cancellation; harmless native Yes")
	var accidental_yes := [0]
	m.open_confirm("QA: Enter before choosing must never accept.", func() -> void: accidental_yes[0] += 1)
	await r.frames(3)
	await _key(KEY_ENTER)
	_check("confirm_layout.unselected_enter_safe", accidental_yes[0] == 0, accidental_yes[0])
	m.open_inventory()
	await r.frames(3)
	for route in ["mouse", "escape", "controller", "raw_touch"]:
		cancel_calls = 0
		yes_calls = 0
		m.open_confirm("QA: once-only " + route, func() -> void: yes_calls += 1, func() -> void:
			cancel_calls += 1
			m.open_inventory())
		await r.frames(4)
		match route:
			"mouse": await _button("Cancel")
			"escape": await _key(KEY_ESCAPE)
			"controller": await _joy_back()
			"raw_touch":
				var emulation: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await _touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulation
		await r.frames(3)
		_check("confirm_layout.cancel_once." + route, cancel_calls == 1 and yes_calls == 0 and m.current == "inventory", {"cancel": cancel_calls, "yes": yes_calls, "menu": m.current})
		m.open_settings("pause")
		await r.frames(3)
		await _key(KEY_ESCAPE)
		_check("confirm_layout.cancel_detached." + route, cancel_calls == 1 and yes_calls == 0 and m.current == "pause", _state())
	cancel_calls = 0
	yes_calls = 0
	m.open_confirm("QA: harmless positive callback.", func() -> void:
		yes_calls += 1
		m.open_inventory(), func() -> void: cancel_calls += 1)
	await r.frames(3)
	await _button("Yes — do it")
	_check("confirm_layout.yes_once", yes_calls == 1 and cancel_calls == 0 and m.current == "inventory", {"yes": yes_calls, "cancel": cancel_calls, "menu": m.current})
	await _key(KEY_ESCAPE)
	_check("confirm_layout.yes_cancel_detached", yes_calls == 1 and cancel_calls == 0 and not m.is_open(), _state())


func _confirm_stale_callable() -> void:
	r.step("retained actual action Callables cannot change a successor shell")
	cancel_calls = 0
	yes_calls = 0
	m.open_confirm("QA: stale callable probe", func() -> void: yes_calls += 1, func() -> void: cancel_calls += 1)
	await r.frames(3)
	var callbacks: Array[Callable] = []
	for caption in ["Yes — do it", "Cancel"]:
		var button: Button = _find_button(m.root, caption)
		if not _check("confirm_layout.stale.button." + caption, button != null, caption): return
		var links: Array[Dictionary] = button.get_signal_connection_list("pressed")
		if not _check("confirm_layout.stale.connections." + caption, links.size() == 2, links.size()): return
		var callback: Callable = links[1].callable
		if not _check("confirm_layout.stale.callable." + caption, callback.is_valid(), caption): return
		callbacks.append(callback)
	m.open_inventory()
	var destination: Control = m.root
	# Same-frame callbacks reproduce the queued-old-action hazard while captured
	# nodes still exist. Only Callables are invoked; no freed-button signal emit.
	for callback in callbacks: callback.call()
	await r.frames(5)
	_check("confirm_layout.stale.no_effect", yes_calls == 0 and cancel_calls == 0 and m.root == destination and m.current == "inventory", {"yes": yes_calls, "cancel": cancel_calls, "menu": m.current})


func _confirm_geometry(id: String, message: String, compact: bool, scrolling := false,
		expected_title := "Are you sure?", accept_label := "Yes — do it") -> Dictionary:
	var label: Label = _confirm_label(message)
	var yes: Button = _find_button(m.root, accept_label, true)
	var cancel: Button = _find_button(m.root, "Cancel", true)
	var panel: Rect2 = _confirm_panel_rect()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	var result := {"panel": str(panel), "viewport": str(viewport)}
	if not _check("confirm_layout." + id + ".nodes", m.current == "confirm" and label != null and yes != null and cancel != null and panel.has_area(), "exact message and action labels; actual Panel"):
		return result
	var title: Label = _confirm_label(expected_title)
	_check("confirm_layout." + id + ".title", title != null and _confirm_glyphs_complete(title), expected_title)
	var body: Rect2 = label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
	var yes_rect: Rect2 = yes.get_global_rect()
	var cancel_rect: Rect2 = cancel.get_global_rect()
	var scroll: ScrollContainer = _confirm_body_scroll(label)
	var visible_body: Rect2 = body.intersection(scroll.get_global_rect()) if scroll != null else body
	result.merge({"body": str(body), "visible_body": str(visible_body), "yes": str(yes_rect), "cancel": str(cancel_rect)})
	_check("confirm_layout." + id + ".shell_in_viewport", viewport.grow(0.5).encloses(panel), result)
	_check("confirm_layout." + id + ".readable_body", label.get_theme_font_size("font_size") >= 18, label.get_theme_font_size("font_size"))
	_check("confirm_layout." + id + ".full_shaped_copy", _confirm_glyphs_complete(label), {"message": message, "size": str(label.size), "lines": label.get_line_count()})
	_check("confirm_layout." + id + ".body_in_shell", panel.grow(0.5).encloses(visible_body) and (scrolling or body == visible_body), result)
	for button in [yes, cancel]:
		var rect: Rect2 = button.get_global_rect()
		var font: Font = button.get_theme_font("font")
		var text_size: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
		var style: StyleBox = button.get_theme_stylebox("normal")
		_check("confirm_layout." + id + ".target." + button.text.strip_edges(), rect.size.x >= 44.0 and rect.size.y >= 44.0
			and viewport.grow(0.5).encloses(rect) and panel.grow(0.5).encloses(rect)
			and rect.size.x + 0.5 >= text_size.x + style.get_minimum_size().x
			and rect.size.y + 0.5 >= text_size.y + style.get_minimum_size().y, {"rect": str(rect), "text": str(text_size)})
	_check("confirm_layout." + id + ".no_overlap", not yes_rect.intersects(cancel_rect)
		and not yes_rect.intersects(visible_body) and not cancel_rect.intersects(visible_body), result)
	var text_issues: Array[String] = []
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if node is Label and node != label and node.is_visible_in_tree() and not node.text.is_empty():
			var rect: Rect2 = node.get_global_rect()
			if not _confirm_glyphs_complete(node) or not panel.grow(0.5).encloses(rect) \
					or rect.intersects(visible_body) or rect.intersects(yes_rect) or rect.intersects(cancel_rect):
				text_issues.append(node.text)
	_check("confirm_layout." + id + ".other_text_clear", text_issues.is_empty(), text_issues)
	if scroll != null:
		_check("confirm_layout." + id + ".actions_outside_scroll", not scroll.is_ancestor_of(yes) and not scroll.is_ancestor_of(cancel)
			and not scroll.get_global_rect().intersects(yes_rect) and not scroll.get_global_rect().intersects(cancel_rect), result)
	if compact:
		var gap: float = minf(yes_rect.position.y, cancel_rect.position.y) - body.end.y
		_check("confirm_layout." + id + ".compact", panel.size.y <= 360.0 and gap >= 0.0 and gap <= 48.0, {"height": panel.size.y, "body_to_actions": gap})
	return result


func _confirm_label(message: String) -> Label:
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if not is_instance_valid(node): continue
		if node is Label and node.is_visible_in_tree() and node.text == message: return node
		for child in node.get_children(): nodes.append(child)
	return null


func _confirm_panel_rect() -> Rect2:
	var result := Rect2()
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if not is_instance_valid(node): continue
		if node is Panel and node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			if rect.get_area() > result.get_area(): result = rect
		for child in node.get_children(): nodes.append(child)
	return result


func _confirm_glyphs_complete(label: Label) -> bool:
	if label.clip_text or label.visible_ratio < 1.0 or label.max_lines_visible != -1 or label.get_visible_line_count() != label.get_line_count(): return false
	var local := Rect2(Vector2.ZERO, label.size).grow(0.5)
	var count := 0
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty(): continue
		var glyph: Rect2 = label.get_character_bounds(index)
		if not glyph.has_area() or not local.encloses(glyph): return false
		count += 1
	return count > 0


func _confirm_body_scroll(label: Label) -> ScrollContainer:
	if label == null: return null
	var node: Node = label.get_parent()
	while node != null and node != m.root:
		if node is ScrollContainer: return node
		node = node.get_parent()
	return null


func _confirm_tail_visible(label: Label, scroll: ScrollContainer) -> bool:
	var local: Rect2 = label.get_character_bounds(label.text.length() - 1)
	var glyph: Rect2 = label.get_global_transform_with_canvas() * local
	return local.has_area() and scroll.get_global_rect().grow(0.5).encloses(glyph)


func _confirm_actions_rect() -> Rect2:
	var yes: Button = _find_button(m.root, "Yes — do it", true)
	var cancel: Button = _find_button(m.root, "Cancel", true)
	return yes.get_global_rect().merge(cancel.get_global_rect()) if yes != null and cancel != null else Rect2()


## Unclaimed gold coins lying in the world (Pickup.drop_gold parents them to Game).
func _loose_coins() -> int:
	var count := 0
	for child in g.get_children():
		var coin := child as Pickup
		if coin != null and not coin.claimed and coin.loot.is_empty() and not coin.goldrush:
			count += 1
	return count


func _confirm_economy() -> Dictionary:
	return {"gold": g.local_player.gold, "backpack": g.local_player.backpack.duplicate(true),
		"materials": g.local_player.materials.duplicate(true), "consumables": g.local_player.consumables.duplicate(true)}


func _confirm_touch_drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = from
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await r.frames(1)
	for index in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = from.lerp(to, float(index) / 8.0)
		drag.relative = (to - from) / 8.0
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		await r.frames(1)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = to
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	touch_taps += 1
	await r.frames(3)


func _pause_layout() -> String:
	if not _check("pause_layout.fixture", g.no_saves and not g.net_online() and not r.flag("baseline") and not r.flag("no-capture"), "strict isolated solo, controlled availability"):
		return "strict solo capture required"
	m.pick_chapter("ch1")
	await r.frames(3)
	m.pick_class("warrior")
	await r.frames(5)
	await r.skip_dialogue()
	g.play_started = true
	g.dev_god = true
	g.hud.visible = true
	for place in ["campaign", "capital", "trial_availability"]:
		if place == "capital":
			var travel_before: Dictionary = _confirm_economy()
			m.close()
			g.enter_capital()
			await r.frames(5)
			await r.skip_dialogue()
			_check("pause_layout.capital_arrived", g.chapter_id == "capital", {"before": travel_before, "after": _confirm_economy(), "scope": "observed real travel recovery; no conservation assertion across worlds"})
		g.endgame_active = place == "trial_availability"
		for touch in [false, true]:
			# Host native drag capability; run() restores the original global value.
			Input.emulate_touch_from_mouse = touch
			g.settings["touch_controls"] = touch
			g.refresh_touch_mode()
			g._apply_touch_mode()
			# Parent replacement isolates content fit from the normal entry tween.
			m.open_inventory()
			await r.frames(3)
			# Snapshot after real travel and inventory settling, while already paused.
			var case_economy: Dictionary = _confirm_economy()
			m.open_pause()
			var id: String = place + ("_touch" if touch else "_desktop")
			_check("pause_layout." + id + ".touch_capability", not touch or DisplayServer.is_touchscreen_available(), {"touch_fixture": touch, "host_capability": DisplayServer.is_touchscreen_available()})
			await _pause_geometry(id)
			var expected: Array[String] = ["Resume game", "Combat report — recent damage & last fall", "🔊  " + Loc.t("settings"), "◈  Wardrobe  (skins & pets, bought with Renown)", "⇦  Exit to title  (switch character)", "✕  Save and quit game"]
			if place == "trial_availability":
				expected.append("💰  Cash out & bank rewards")
			else:
				expected.append("↺  Restart chapter  (keeps your character)")
				expected.append("⚑  Chapter select  (replay any chapter)")
				if place == "campaign": expected.append("⌂  Travel to Crownfall  (the Capital)")
			var actual: Array[String] = []
			var nodes: Array[Node] = [m.root]
			while not nodes.is_empty():
				var node: Node = nodes.pop_back()
				for child in node.get_children(): nodes.append(child)
				if node is Button and node.is_visible_in_tree() and node.text != "✕": actual.append(node.text.strip_edges())
			expected.sort()
			actual.sort()
			_check("pause_layout." + id + ".actions_exact", expected == actual, {"expected": expected, "actual": actual, "controlled_trial_availability": g.endgame_active})
			if await _button("Settings"):
				await _key(KEY_ESCAPE)
				_check("pause_layout." + id + ".settings_return", m.current == "pause" and g.get_tree().paused, _state())
			_check("pause_layout." + id + ".no_spend", _confirm_economy() == case_economy, {"before": case_economy, "after": _confirm_economy(), "scope": "pause layout and Settings roundtrip; after world-transition settling"})
			await _key(KEY_ESCAPE)
	g.endgame_active = false
	for route in ["mouse", "escape", "controller", "raw_touch"]:
		m.open_pause()
		await r.frames(3)
		var close_economy: Dictionary = _confirm_economy()
		match route:
			"mouse": await _button("Resume game")
			"escape": await _key(KEY_ESCAPE)
			"controller": await _joy_back()
			"raw_touch":
				var emulated: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await _touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulated
		_check("pause_layout.close." + route, not m.is_open() and not g.get_tree().paused and g.hud.visible, _state())
		_check("pause_layout.close." + route + ".no_spend", _confirm_economy() == close_economy, {"before": close_economy, "after": _confirm_economy()})
	return ""


## Native observations; overflow is measured, never assumed from a fixture name.
func _pause_geometry(id: String) -> void:
	await RenderingServer.frame_post_draw
	var resume: Button = _find_button(m.root, "Resume game", true)
	if not _check("pause_layout." + id + ".resume", resume != null, "actual fixed action"): return
	var focus: Control = m.get_viewport().gui_get_focus_owner()
	var keyboard_entry: bool = not g.touch_mode and (g.gamepad == null or not g.gamepad.active)
	_check("pause_layout." + id + ".safe_entry_focus", focus == resume if keyboard_entry else focus == null,
		{"keyboard": keyboard_entry, "focused": str(focus), "safe_action": resume.text})
	var first: Dictionary = {"panel": str(_confirm_panel_rect()), "resume": str(resume.get_global_rect())}
	var first_actions: Dictionary = _pause_action_snapshot(id + "_first")
	r.shot("pause_" + id + "_first", "first draw after parent replacement; controlled availability")
	await r.frames(4)
	await RenderingServer.frame_post_draw
	var settled_actions: Dictionary = _pause_action_snapshot(id + "_settled")
	_check("pause_layout." + id + ".all_actions_first_stable", first_actions == settled_actions, {"first": first_actions, "settled": settled_actions})
	var panel: Rect2 = _confirm_panel_rect()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	_check("pause_layout." + id + ".first_stable", first == {"panel": str(panel), "resume": str(resume.get_global_rect())}, first)
	_check("pause_layout." + id + ".shell", panel.has_area() and viewport.grow(0.5).encloses(panel), str(panel))
	var scroll: ScrollContainer = null
	var buttons: Array[Button] = []
	var labels: Array[Label] = []
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if node is ScrollContainer: scroll = node
		if node is Button and node.is_visible_in_tree() and node.text != "✕": buttons.append(node)
		if node is Label and node.is_visible_in_tree() and not node.text.is_empty(): labels.append(node)
	if not _check("pause_layout." + id + ".scroll", scroll != null, "all-platform action scroll"): return
	var last: Button = null
	for button in buttons:
		var rect: Rect2 = button.get_global_rect()
		var fit: Dictionary = _pause_text_fit(button)
		_check("pause_layout." + id + ".target." + button.text.strip_edges(), bool(fit.passed), fit)
		if scroll.is_ancestor_of(button):
			if last == null or rect.end.y > last.get_global_rect().end.y: last = button
			_check("pause_layout." + id + ".horizontal." + button.text.strip_edges(), rect.position.x >= scroll.get_global_rect().position.x - 0.5 and rect.end.x <= scroll.get_global_rect().end.x + 0.5, str(rect))
		else:
			_check("pause_layout." + id + ".fixed." + button.text.strip_edges(), panel.grow(0.5).encloses(rect) and viewport.grow(0.5).encloses(rect), str(rect))
	for label in labels:
		if label.text.contains("ESC") or label.text.begins_with("Tap"):
			_check("pause_layout." + id + ".footer_fixed", not scroll.is_ancestor_of(label), label.text)
		var rect: Rect2 = label.get_global_rect()
		var clipped: Rect2 = rect
		var ancestor: Node = label.get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is Control and ancestor.clip_contents: clipped = clipped.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		_check("pause_layout." + id + ".text." + label.text, _confirm_glyphs_complete(label) and (scroll.is_ancestor_of(label) or (clipped.grow(0.5).encloses(rect) and panel.grow(0.5).encloses(rect))), {"rect": str(rect), "clip": str(clipped)})
	_check("pause_layout." + id + ".resume_fixed", not scroll.is_ancestor_of(resume), str(resume.get_global_rect()))
	var fixed: Rect2 = resume.get_global_rect()
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var overflow: bool = bar.max_value - bar.page > 1.0
	scroll.scroll_vertical = 0
	await r.frames(2)
	if overflow:
		for index in 24: await _wheel(MOUSE_BUTTON_WHEEL_DOWN, scroll.get_global_rect().get_center())
		_check("pause_layout." + id + ".wheel_moves", scroll.scroll_vertical > 0, scroll.scroll_vertical)
	_check("pause_layout." + id + ".tail_reached", last != null and scroll.get_global_rect().grow(0.5).encloses(last.get_global_rect()), {"overflow": overflow, "scroll_proof": overflow and scroll.scroll_vertical > 0, "tail": str(last.get_global_rect()) if last else "missing"})
	await _capture("pause_" + id + "_tail")
	if overflow and g.touch_mode:
		scroll.scroll_vertical = 0
		await r.frames(2)
		var area: Rect2 = scroll.get_global_rect()
		await _confirm_touch_drag(area.get_center() + Vector2(0, area.size.y * 0.35), area.get_center() - Vector2(0, area.size.y * 0.35))
		_check("pause_layout." + id + ".touch_moves", scroll.scroll_vertical > 0, scroll.scroll_vertical)
	_check("pause_layout." + id + ".fixed_after_scroll", resume.get_global_rect() == fixed, str(resume.get_global_rect()))


## TextParagraph is an independent native shaper, not access to Button's pixels.
## Button minimum height additionally observes its own already-drawn text buffer.
func _pause_text_fit(button: Button) -> Dictionary:
	var rect: Rect2 = button.get_global_rect()
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var padding := Vector2.ZERO
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		if button.has_theme_stylebox(state):
			var style: StyleBox = button.get_theme_stylebox(state)
			padding.x = maxf(padding.x, style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT))
			padding.y = maxf(padding.y, style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))
	var available: float = rect.size.x - padding.x
	var wrapped: bool = button.autowrap_mode != TextServer.AUTOWRAP_OFF
	var supported: bool = (not wrapped or button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART) \
		and button.icon == null and not button.is_layout_rtl() \
		and button.text_direction in [Control.TEXT_DIRECTION_INHERITED, Control.TEXT_DIRECTION_LTR, Control.TEXT_DIRECTION_AUTO] \
		and (button.language.is_empty() or button.language.begins_with("en"))
	var paragraph := TextParagraph.new()
	paragraph.direction = TextServer.DIRECTION_AUTO if button.text_direction == Control.TEXT_DIRECTION_AUTO else TextServer.DIRECTION_LTR
	paragraph.alignment = button.alignment
	paragraph.width = maxf(1.0, available) if wrapped else -1.0
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_TRIM_EDGE_SPACES
	if wrapped: paragraph.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.line_spacing = button.get_theme_constant("line_spacing")
	paragraph.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var shaped: bool = paragraph.add_string(button.text, font, font_size, button.language)
	var widest := 0.0
	for index in paragraph.get_line_count(): widest = maxf(widest, paragraph.get_line_size(index).x)
	var text_size: Vector2 = paragraph.get_size()
	var inferred_direction: int = TextServerManager.get_primary_interface().shaped_text_get_inferred_direction(paragraph.get_rid())
	var effective_ltr: bool = inferred_direction == TextServer.DIRECTION_LTR
	var native_min: Vector2 = button.get_minimum_size()
	var untrimmed: bool = not button.clip_text and button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
	var single_line_ok: bool = true
	if not wrapped:
		var plain_size: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		single_line_ok = rect.size.x + 0.5 >= plain_size.x + padding.x and rect.size.y + 0.5 >= plain_size.y + padding.y
	var passed: bool = supported and shaped and effective_ltr and untrimmed and available > 0 and paragraph.get_line_count() > 0 \
		and rect.size.x >= 44 and rect.size.y >= 44 and font_size >= 18 \
		and widest <= available + 0.5 and text_size.y + padding.y <= rect.size.y + 0.5 \
		and native_min.y <= rect.size.y + 0.5 and single_line_ok
	return {"passed": passed, "rect": str(rect), "text": button.text, "font_size": font_size,
		"supported": supported, "untrimmed": untrimmed, "wrapped": wrapped,
		"requested_direction": button.text_direction, "paragraph_direction": paragraph.direction,
		"inferred_direction": inferred_direction, "effective_ltr": effective_ltr, "layout_rtl": button.is_layout_rtl(),
		"lines": paragraph.get_line_count(), "widest_line": widest, "available_width": available,
		"shaped_height": text_size.y, "padding": str(padding), "native_min": str(native_min),
		"proof": "native font shaping and actual Button minimum; pixel review still required"}


func _pause_action_snapshot(id: String) -> Dictionary:
	var result := {}
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if node is Button and node.is_visible_in_tree() and node.text != "✕":
			var fit: Dictionary = _pause_text_fit(node)
			_check("pause_layout." + id + ".full_text." + node.text.strip_edges(), bool(fit.passed), fit)
			result[String(node.get_path())] = {"rect": str(node.get_global_rect()), "text": node.text, "fit": fit}
	return result


func _grouped_gold() -> void:
	r.step("grouped trial settlement and merchant/forge gold; controlled wallet loan")
	var gold := g.player.gold
	var chapter := g.chapter_id
	var smith_message := m._smith_msg
	var reforge_message := m._reforge_msg
	m._smith_msg = ""
	m._reforge_msg = ""
	g.player.gold = 1234567
	m.open_endgame_result({"name": "The Crucible", "mode": "crucible", "gold": g.player.gold})
	await r.frames(3)
	_check("gold.trial_result", _has_label(m.root, "Gold banked:  " + m._fmt_gold(g.player.gold)), "1,234,567 banked")
	await _capture("06a_grouped_trial_gold")
	for source in ["fence", "smuggler"]:
		m.open_black_market(source)
		await r.frames(3)
		_check("gold.header." + source, _has_label(m.root, ("The Sable Court Fence" if source == "fence" else "A Road Smuggler") + " — you have 1,234,567 gold"), source)
		await _capture("06b_grouped_" + source)
	# The card parser must preserve grouping when moving a quote to its price column.
	var box := m._open("Merchant price QA", 720, 400)
	var grid := m._shop_grid(box)
	m._shop_card(grid, null, "Price display fixture", "1,234,567 gold", Color.WHITE, true, func() -> void: pass)
	_check("gold.merchant_card", _has_label(m.root, "1,234,567 g"), "grouped quote survives card extraction")
	await r.frames(3)
	await _capture("06c_grouped_merchant_price")
	g.chapter_id = "capital"
	box = m._open("Forge price QA", 900, 600)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var item := Items.roll_item_of("weapon", "A", rng, "warrior")
	item.subs = {"crit": 0.01}
	m._item_reforge_tab(box, item)
	var price_pattern := RegEx.new()
	price_pattern.compile("([0-9][0-9,]*) gold")
	var big_prices := 0
	var price_buttons := 0
	for button in m.root.find_children("*", "Button", true, false):
		var price := price_pattern.search(button.text)
		if price != null:
			var number := int(price.get_string(1).replace(",", ""))
			_check("gold.forge_price." + str(price_buttons), price.get_string(1) == m._fmt_gold(number), button.text)
			price_buttons += 1
			if number >= 1000:
				big_prices += 1
	_check("gold.forge_big_prices", big_prices >= 3, big_prices)
	await r.frames(3)
	_check("gold.forge_wallet", _has_label(m.root, "Your gold: 1,234,567"), "grouped forge wallet")
	await _capture("06d_grouped_forge_gold")
	m.close()
	g.player.gold = gold
	g.chapter_id = chapter
	m._smith_msg = smith_message
	m._reforge_msg = reforge_message
