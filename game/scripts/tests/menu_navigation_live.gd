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
	var economy: Dictionary = _confirm_economy()
	await _confirm_actual_callers()
	await _confirm_first_draw()
	await _confirm_long_stress()
	await _confirm_native_routes()
	await _confirm_stale_callable()
	await _callback_lifetime()
	_check("confirm_layout.economy_unchanged", _confirm_economy() == economy, _confirm_economy())
	return ""


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
		_confirm_geometry("mail", "Delete this letter AND its unclaimed loot?", true)
		await _capture("10_confirm_mail_delete")
		await _button("Cancel")
		_check("confirm_layout.mail.return", m.current == "mail_letter" and _has_label(m.root, "Confirm-layout parcel"), _state())
		_check("confirm_layout.mail.intact", g.mailbox == [expected], g.mailbox)
	g.mailbox = before
	m.open_pause()
	await r.frames(3)
	if await _button("Exit to title"):
		_confirm_geometry("pause", "Exit to the title screen? Your progress is saved.", true)
		await _capture("11_confirm_pause_exit")
		await _key(KEY_ESCAPE)
		_check("confirm_layout.pause.return", m.current == "pause" and g.get_tree().paused, _state())
	for mode in ["crucible", "depths"]:
		var title: String = "The Crucible" if mode == "crucible" else "The Waking Depths"
		var rules: String = "Ten bosses back to back, each with an elite affix — HP and MP carry over between them. Bonus spoils at 3 / 6 / 10 kills." if mode == "crucible" else "An endless descent where DEPTH IS THE MONSTERS' LEVEL — the ladder starts at 40, or at your deepest cleared checkpoint. A boss guards every 5th depth, a checkpoint boss every 10th; past 100 the dark only deepens. Rewards pay when you fall or cash out."
		var pb: Dictionary = g.endgame_pb(mode, g.local_player.cls)
		var best := ""
		if not pb.is_empty():
			best = "\n\nYour best: %d bosses." % int(pb.get("kills", 0)) if mode == "crucible" else "\n\nYour deepest: depth %d." % int(pb.get("depth", 0))
		var message := "Enter %s?\n\n%s%s\n\nYour campaign is saved — you'll return to the title when the run ends." % [title, rules, best]
		m.confirm_endgame(mode)
		await r.frames(4)
		_confirm_geometry("endgame_" + mode, message, false)
		await _capture("12_confirm_endgame_" + mode)
		await _button("Cancel")
		_check("confirm_layout.endgame." + mode + ".return", not m.is_open() and not g.endgame_active and not g.get_tree().paused, _state())


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


func _confirm_geometry(id: String, message: String, compact: bool, scrolling := false) -> Dictionary:
	var label: Label = _confirm_label(message)
	var yes: Button = _find_button(m.root, "Yes — do it", true)
	var cancel: Button = _find_button(m.root, "Cancel", true)
	var panel: Rect2 = _confirm_panel_rect()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	var result := {"panel": str(panel), "viewport": str(viewport)}
	if not _check("confirm_layout." + id + ".nodes", m.current == "confirm" and label != null and yes != null and cancel != null and panel.has_area(), "exact message and action labels; actual Panel"):
		return result
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
