extends "res://scripts/tests/alchemy_live.gd"
## Real paired ENet + actual GUI input. Resources/award trigger are fixtures.
## Reuses the existing input/selection helpers, not its offline acceptance run.
var pair: Node


static func run_enet(fixture: Node) -> String:
	var proof := new()
	proof.pair = fixture
	proof.r = fixture
	proof.g = fixture.readers[1]
	proof.m = proof.g.menus
	proof.native = NativeInput.new()
	proof.native.r = fixture
	proof.native.g = proof.g
	proof.native.m = proof.m
	var language := Loc.lang
	var emulation := Input.emulate_mouse_from_touch
	Loc.lang = "en"
	Input.emulate_mouse_from_touch = true
	var error: String = await proof._network_ui()
	proof._key_held(KEY_D, false)
	proof._key_held(int(proof.g.binds.a1), false)
	proof._pointer(false, Vector2(12, 12))
	proof._finger(false, Vector2(180, 560))
	proof._touch_mode(false)
	Input.emulate_mouse_from_touch = emulation
	Loc.lang = language
	proof._check("enet_ui.completed", error == "", error)
	var failures := 0
	for row in proof.rows:
		failures += int(not bool(row.passed))
	fixture.report["ui"] = {"checks": proof.rows.size(), "failures": failures,
		"rows": proof.rows, "mouse_clicks": proof.native.mouse_clicks,
		"touch_taps": proof.native.touch_taps, "key_taps": proof.native.key_taps,
		"qualification": "Controlled materials/mastery/gold, godmode capital, real ENet award/travel transport and native GUI. No ordinary collection, combat, persistence-roundtrip or real-scene disconnect-reload claim."}
	return error if error != "" else ("Alchemy ENet UI strict checks failed" if failures > 0 else "")


func _network_ui() -> String:
	r.step("ENet UI fixture: two capital readers; loaned character; production snapshot")
	for index in 2:
		pair.readers[index].switch_chapter("capital", true)
		await pair._quiet(index)
		pair._loan(pair.readers[index])
		pair.readers[index].settings["touch_controls"] = false
		pair.readers[index].refresh_touch_mode()
		pair.readers[index]._apply_touch_mode()
	g.player.materials = []
	g.player.blueprints = []
	g.save_slot = pair.SLOT
	g.no_saves = false
	SaveGame.write(g, pair.SLOT)
	if pair.transports[0].create_server(0, 2) != OK:
		return "UI ENet server bind failed"
	pair.apis[0].multiplayer_peer = pair.transports[0]
	if not await pair._connect_guest():
		return "UI ENet guest snapshot timed out"
	await pair._quiet(1)
	p = g.local_player
	p.set_physics_process(true)
	_check("enet_ui.real_guest", g.net_guest() and g.guest_world and pair.wires[1].world_ready
		and not pair.apis[0].get_peers().is_empty(), {"chapter": g.chapter_id, "pid": p.peer_id})
	# Positive native-input control; physics must actually run before measuring
	# overlay immobility. No assigned intent vector or manual body translation.
	var before_pos := p.global_position
	_key_held(KEY_D, true)
	await pair._settle(0.25)
	_key_held(KEY_D, false)
	await pair._settle(0.15)
	_check("enet_ui.input_positive_control", p.global_position.distance_to(before_pos) > 4.0,
		{"distance": p.global_position.distance_to(before_pos), "physics": p.is_physics_processing()})
	await _confirmation_overlay()
	# Parent opening is a named fixture seam; entering/selecting is actual GUI.
	g._hub_action("professions")
	await r.frames(3)
	if not await _named("ProfessionsAlchemy") or not await _named("AlchemyShape_health_tonic") \
			or not await _named("AlchemyGrade_B"):
		return "actual guest Alchemy entry/selection unavailable"
	_check("enet_ui.initial_blocked", _disabled("AlchemyBrew")
		and _text("AlchemyRequirements").contains("Blueprint not learned")
		and _text("AlchemyIngredient_herb").contains("Have 0"), _text("AlchemyResult"))
	await _capture_online("ui_01_guest_unlearned")
	before_pos = p.global_position
	var anim_before := p.anim_t
	# The paired reader normally enables godmode, which caps cooldowns at 0.2.
	# Let the real safe-capital clock run normally for this bounded observation.
	var previous_god := g.dev_god
	g.dev_god = false
	p.cds.a1 = 2.5 # clock sentinel, explicitly controlled; no ability award
	_key_held(KEY_D, true)
	_key_held(int(g.binds.a1), true)
	await pair._settle(0.45)
	_key_held(KEY_D, false)
	_key_held(int(g.binds.a1), false)
	_check("enet_ui.live_physics_gated_input", not r.get_tree().paused and p.is_physics_processing()
		and p.anim_t > anim_before + 0.1 and p.cds.a1 < 2.4 and p.cds.a1 > 0.0
		and p.global_position.distance_to(before_pos) <= 0.5 and p.intent_move == Vector2.ZERO,
		{"distance": p.global_position.distance_to(before_pos), "animation_delta": p.anim_t - anim_before, "cooldown": p.cds.a1})
	g.dev_god = previous_god
	var shell_id := m.root.get_instance_id()
	var host_before: Dictionary = pair._personal(pair.readers[0])
	var recipe: Dictionary = Alchemy.recipe("health_tonic", "B")
	var packet := [{"k": "material", "family": "herb", "grade": "B", "count": int(recipe.herbs) + 5},
		{"k": "material", "family": "reagent", "grade": "B", "count": int(recipe.reagents) + 5},
		{"k": "blueprint", "bp": Items.make_blueprint(String(recipe.blueprint_slot), "B")}]
	pair.report["posed_ui_award_packet"] = packet
	pair.wires[0].host_award_all(packet)
	var refreshed: bool = await pair._until(func() -> bool:
		return m.current == "alchemy" and m.root.get_instance_id() != shell_id \
			and not _disabled("AlchemyBrew"), 5.0)
	_check("enet_ui.authority_award_refresh", refreshed and p.has_blueprint(String(recipe.blueprint_slot), "B")
		and _text("AlchemyRequirements").contains("Blueprint known")
		and _text("AlchemyIngredient_herb").contains("Have %d / Need %d" % [int(recipe.herbs) + 5, int(recipe.herbs)])
		and _view().shape == "health_tonic" and _view().grade == "B", _text("AlchemyIngredient_herb"))
	_check("enet_ui.award_not_host_inventory", pair._personal(pair.readers[0]) == host_before, "posed guest fanout")
	if not refreshed:
		return "open Alchemy did not refresh from reliable guest award"
	await _capture_online("ui_02_guest_known_and_funded")
	# A changed character term while holding the ACTUAL Brew target must reject
	# that old quote on release. No direct Order.commit or signal invocation.
	var brew := _node("AlchemyBrew") as Button
	var at := brew.get_global_rect().get_center()
	shell_id = m.root.get_instance_id()
	_pointer(true, at)
	await r.frames(1)
	p.mastery["alchemist"] = Professions.points(p, "alchemist") + 1
	var economy := _economy()
	await pair._settle(Balance.ACTIVITY_BOARD_REFRESH + 0.2)
	_check("enet_ui.held_terms_target_stable", m.root.get_instance_id() == shell_id, m.current)
	_pointer(false, at)
	native.mouse_clicks += 1
	await r.frames(4)
	_check("enet_ui.held_terms_no_spend", _economy() == economy
		and _text("AlchemyResult").contains("quote changed"), _text("AlchemyResult"))
	# Back retires the old watcher; a later local term change must not resurrect it.
	if not await _named("AlchemyReturn"):
		return "real Back to Professions unavailable"
	shell_id = m.root.get_instance_id()
	p.mastery["alchemist"] = Professions.points(p, "alchemist") + 1
	await pair._settle(Balance.ACTIVITY_BOARD_REFRESH + 0.2)
	_check("enet_ui.back_lifetime", m.current == "professions" and m.root.get_instance_id() == shell_id
		and not r.get_tree().paused, m.current)
	await native._key(KEY_ESCAPE)
	await _touch_gate()
	if not await _named("ProfessionsAlchemy", true):
		return "touch Alchemy entry unavailable"
	var rail := _node("AlchemyRecipeScroll") as ScrollContainer
	if rail == null:
		return "actual Alchemy touch rail missing"
	var finger_at := rail.get_global_rect().get_center()
	before_pos = p.global_position
	_finger(true, finger_at)
	_drag(finger_at + Vector2(50, -30), Vector2(50, -30))
	await pair._settle(0.35)
	var mi: Node = g.get_node("/root/MobileInput")
	_check("enet_ui.touch_alchemy_gated", m.current == "alchemy" and not g._touch_hud._enabled
		and mi.move == Vector2.ZERO and g._touch_hud._move_touch == -1
		and p.global_position.distance_to(before_pos) <= 0.5,
		{"distance": p.global_position.distance_to(before_pos), "move": str(mi.move)})
	_finger(false, finger_at + Vector2(50, -30))
	await r.frames(3)
	await native._joy_back()
	_check("enet_ui.controller_back", m.current == "professions" and not r.get_tree().paused, m.current)
	if not await _named("ProfessionsAlchemy"):
		return "entry after real controller Back unavailable"
	# Host-initiated reliable world travel during a held Brew. Scene rebuild and
	# release are real; only the travel trigger is posed by the paired fixture.
	brew = _node("AlchemyBrew") as Button
	if brew == null or brew.disabled:
		return "travel hold needs the still-funded guest recipe"
	at = brew.get_global_rect().get_center()
	_pointer(true, at)
	await r.frames(1)
	economy = _economy()
	var old_world := g.world.get_instance_id()
	# ch1-3 legitimately reconcile a teaching potion on arrival. Use a real
	# non-teaching chapter so the complete no-spend ledger remains meaningful.
	if not _check("enet_ui.travel_no_teaching_grant", not Balance.FREE_POTION_CHAPTERS.has("ch4"), Balance.FREE_POTION_CHAPTERS):
		_pointer(false, at)
		return "travel control must avoid teaching-potion reconciliation"
	pair.readers[0].switch_chapter("ch4", true)
	pair.wires[0].host_advance_party()
	var traveled: bool = await pair._until(func() -> bool:
		return g.chapter_id == "ch4" and g.world.get_instance_id() != old_world, 15.0)
	_pointer(false, at)
	await r.frames(4)
	_check("enet_ui.travel_hold_no_spend", traveled and _economy() == economy,
		{"chapter": g.chapter_id, "menu": m.current, "result": _text("AlchemyResult")})
	await _capture_online("ui_03_travel_rejects_held_order")
	await _disconnect_diagnostic()
	return ""


func _notice_contract(id: String) -> void:
	var start: int = native.rows.size()
	native._notice_geometry("enet_" + id, "Solo trials",
		"These trials are played solo.\n\nLeave your co-op session before entering a trial. You can keep playing with your party for now.")
	for index in range(start, native.rows.size()):
		var row: Dictionary = native.rows[index]
		_check("enet_ui." + String(row.id), bool(row.passed), row.actual)


func _confirmation_overlay() -> void:
	# Actual solo-trial admission caller on a real ENet guest. Its confirmation
	# must block hero input while the shared world clock continues to advance.
	var before_pos := p.global_position
	var before_world := g.world.get_instance_id()
	var before_economy := _economy()
	var previous_god := g.dev_god
	var previous_cd: float = p.cds.a1
	g.dev_god = false
	p.cds.a1 = 2.5
	_key_held(int(g.binds.a1), true)
	await pair._settle(0.12)
	_check("enet_ui.confirm_ability_input_positive_control", p.intent_a1 and p.cds.a1 > 0.0,
		{"held_ability_intent": p.intent_a1, "cooldown": p.cds.a1})
	m.confirm_endgame("crucible")
	await r.frames(3)
	_notice_contract("controller")
	var anim_before := p.anim_t
	_key_held(KEY_D, true)
	_key_held(int(g.binds.a1), true)
	await pair._settle(0.35)
	var ability_intent_during_hold: bool = p.intent_a1
	_key_held(KEY_D, false)
	_key_held(int(g.binds.a1), false)
	_check("enet_ui.confirm_live_world_blocks_keyboard", m.current == "confirm"
		and not r.get_tree().paused and p.is_physics_processing()
		and not ability_intent_during_hold and p.anim_t > anim_before and p.cds.a1 > 0.0 and p.cds.a1 < 2.5
		and p.global_position.distance_to(before_pos) <= 0.5 and p.intent_move == Vector2.ZERO,
		{"menu": m.current, "distance": p.global_position.distance_to(before_pos),
		"animation_delta": p.anim_t - anim_before, "cooldown": p.cds.a1, "held_ability_intent": ability_intent_during_hold})
	_touch_mode(true)
	await r.frames(3)
	# Drag inside the dialog, away from either action and the outside dimmer.
	var at: Vector2 = m._shell_rect.get_center()
	_finger(true, at)
	_drag(at + Vector2(36, -18), Vector2(36, -18))
	await pair._settle(0.15)
	var mi: Node = g.get_node("/root/MobileInput")
	_check("enet_ui.confirm_blocks_touch", m.current == "confirm"
		and not g._touch_hud._enabled and g._touch_hud._move_touch == -1
		and mi.move == Vector2.ZERO and p.global_position.distance_to(before_pos) <= 0.5,
		{"menu": m.current, "distance": p.global_position.distance_to(before_pos), "move": str(mi.move)})
	_finger(false, at + Vector2(36, -18))
	await _capture_online("ui_00_guest_confirmation")
	await native._joy_back()
	_check("enet_ui.confirm_cancel_keeps_session", not m.is_open() and not r.get_tree().paused
		and g.net_guest() and pair.wires[1].world_ready and g.world.get_instance_id() == before_world
		and _economy() == before_economy, {"menu": m.current, "chapter": g.chapter_id})
	_touch_mode(false)
	g.dev_god = previous_god
	p.cds.a1 = previous_cd
	for route in ["mouse", "escape", "raw_touch"]:
		before_world = g.world.get_instance_id()
		before_economy = _economy()
		m.confirm_endgame("depths")
		await r.frames(3)
		_notice_contract(route)
		await _capture_online("ui_00_notice_" + route)
		match route:
			"mouse": await _text_button("Back to game")
			"escape": await native._key(KEY_ESCAPE)
			"raw_touch":
				var emulation: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await native._touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulation
		await r.frames(3)
		_check("enet_ui.notice_cancel_keeps_session." + route, not m.is_open() and not r.get_tree().paused
			and g.net_guest() and pair.wires[1].world_ready and g.world.get_instance_id() == before_world
			and _economy() == before_economy, {"menu": m.current, "chapter": g.chapter_id})


func _touch_gate() -> void:
	_touch_mode(true)
	await r.frames(4)
	var mi: Node = g.get_node("/root/MobileInput")
	var start := Vector2(180, 560)
	_finger(true, start)
	_drag(start + Vector2(80, 0), Vector2(80, 0))
	await pair._settle(0.12)
	_check("enet_ui.touch_positive_control", mi.move.length() > 0.2
		and g._touch_hud._move_touch == 0, {"move": str(mi.move), "touch": g._touch_hud._move_touch})
	# Open the fixture parent while the actual joystick finger remains held.
	g._hub_action("professions")
	await r.frames(3)
	var before_pos := p.global_position
	_drag(start + Vector2(100, 0), Vector2(20, 0))
	await pair._settle(0.35)
	_check("enet_ui.touch_parent_gated", not g._touch_hud._enabled and mi.move == Vector2.ZERO
		and g._touch_hud._move_touch == -1 and p.global_position.distance_to(before_pos) <= 0.5,
		{"distance": p.global_position.distance_to(before_pos), "move": str(mi.move)})
	_finger(false, start + Vector2(100, 0))
	await r.frames(2)


func _disconnect_diagnostic() -> void:
	# Return via reliable travel, then release a held Brew after actual transport
	# teardown. Child Game intentionally suppresses real title-scene reload.
	pair.readers[0].switch_chapter("capital", true)
	pair.wires[0].host_advance_party()
	if not await pair._until(func() -> bool: return g.chapter_id == "capital", 15.0):
		_check("enet_ui.disconnect_return", false, g.chapter_id)
		return
	await pair._quiet(1)
	p = g.local_player
	p.set_physics_process(true)
	g._hub_action("professions")
	await r.frames(3)
	if not await _named("ProfessionsAlchemy"):
		return
	var brew := _node("AlchemyBrew") as Button
	if brew == null or brew.disabled:
		_check("enet_ui.disconnect_hold_available", false, _text("AlchemyResult"))
		return
	var at := brew.get_global_rect().get_center()
	_pointer(true, at)
	await r.frames(1)
	var economy := _economy()
	pair.transports[1].close()
	pair.apis[1].multiplayer_peer = null
	pair.roots[1].online = false
	g.qa_online = false
	pair.wires[1].set_physics_process(false)
	pair.wires[1]._on_session_ended("Alchemy UI held pointer diagnostic")
	_pointer(false, at)
	await r.frames(4)
	_check("enet_ui.disconnect_production_teardown", not g.net_online() and not pair.wires[1].world_ready
		and g._host_lost_handled, "real transport closed; production teardown invoked as existing paired fixture")
	pair.report["disconnect_child_scene_diagnostic"] = {"no_spend_on_release": _economy() == economy,
		"menu": m.current, "result": _text("AlchemyResult"), "before": economy, "after": _economy(),
		"strict_acceptance": false, "qualification": "Game.net_host_lost suppresses reload for child Game. A surviving shell is a harness lifetime observation, not real current-scene exit proof. Separate scene-reload coverage remains required."}


func _key_held(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finger(down: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _capture_online(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "posed capital/material/award fixture; real paired ENet and native menu input")



## Opt-in --party-pause branch. Real host plus three real ENet guest worlds, the
## production host roster, and native pause input on the host reader. The default
## run_enet episode above is unchanged and still runs separately.
static func run_party_pause(fixture: Node) -> String:
	var proof := new()
	proof.pair = fixture
	proof.r = fixture
	proof.g = fixture.readers[0]
	proof.m = proof.g.menus
	proof.native = NativeInput.new()
	proof.native.r = fixture
	proof.native.g = proof.g
	proof.native.m = proof.m
	var language := Loc.lang
	var emulation := Input.emulate_mouse_from_touch
	Loc.lang = "en"
	Input.emulate_mouse_from_touch = true
	var viewport_inputs: Array[bool] = []
	for reader in fixture.readers:
		viewport_inputs.append(reader.get_viewport().gui_disable_input)
	var error: String = await proof._party_pause()
	proof._key_held(KEY_D, false)
	proof._key_held(int(proof.g.binds.a1), false)
	proof._pointer(false, Vector2(12, 12))
	proof._finger(false, Vector2(180, 560))
	proof._touch_mode(false)
	var inputs_restored := true
	for index in fixture.readers.size():
		var viewport: Viewport = fixture.readers[index].get_viewport()
		viewport.gui_disable_input = viewport_inputs[index]
		inputs_restored = inputs_restored and viewport.gui_disable_input == viewport_inputs[index]
	proof._check("party_pause.viewport_input_restored", inputs_restored, viewport_inputs)
	Input.emulate_mouse_from_touch = emulation
	Loc.lang = language
	proof._check("party_pause.completed", error == "", error)
	var failures := 0
	for row in proof.rows:
		failures += int(not bool(row.passed))
	fixture.report["party_pause"] = {"checks": proof.rows.size(), "failures": failures,
		"rows": proof.rows, "mouse_clicks": proof.native.mouse_clicks,
		"touch_taps": proof.native.touch_taps, "key_taps": proof.native.key_taps,
		"qualification": "Real host + three real ENet guests, production snapshots and host roster, native pause input and actual row geometry. Character names, slots and capital placement are controlled fixtures; no ordinary collection, combat or save-roundtrip claim."}
	return error if error != "" else ("Party pause strict checks failed" if failures > 0 else "")


## Three exact 64-character fixtures: one unbroken wide run, one spaced run, and
## one long-run/space mix. Lengths are asserted as strict rows, never assumed.
func _party_names() -> Array:
	return ["W".repeat(64), "Wm ".repeat(21) + "W", "M".repeat(31) + " " + "W".repeat(32)]


func _party_pause() -> String:
	r.step("party pause fixture: real host and three real ENet guest worlds in one capital")
	if pair.readers.size() != 4 or pair.transports.size() != 4:
		return "party pause requires the host plus three guest readers"
	if not _check("party_pause.shell_motion_disabled", not m.shell_motion, "inherited paired reader disables normal shell tween"):
		return "party reader must disable shell entry tween before first-draw observation"
	var names: Array = _party_names()
	for index in names.size():
		if not _check("party_pause.name_length.%d" % index, String(names[index]).length() == 64, String(names[index]).length()):
			return "party fixture names must be exactly 64 characters"
	for index in 4:
		pair.readers[index].switch_chapter("capital", true)
		await pair._quiet(index)
		pair.readers[index].settings["touch_controls"] = false
		pair.readers[index].refresh_touch_mode()
		pair.readers[index]._apply_touch_mode()
	if pair.transports[0].create_server(0, 3) != OK:
		return "party pause ENet server bind failed"
	pair.apis[0].multiplayer_peer = pair.transports[0]
	for slot_index in 3:
		var guest: Game = pair.readers[slot_index + 1]
		guest.player.char_name = String(names[slot_index])
		guest.save_slot = int(pair.PARTY_SLOTS[slot_index])
		guest.no_saves = false
		# Distinct per-guest slot; run() backed these up before any write.
		SaveGame.write(guest, guest.save_slot)
		if not await pair._connect_party_guest(slot_index + 1, String(names[slot_index])):
			return "guest %d real ENet join/snapshot timed out" % (slot_index + 1)
		await pair._quiet(slot_index + 1)
	pair._show(0)
	# Hidden SubViewportContainers still forward nonpositional input. Select the
	# one local input destination while every world/RPC/physics loop stays live.
	var input_routes: Array[Dictionary] = []
	var host_input_only := true
	for index in pair.readers.size():
		var viewport: Viewport = pair.readers[index].get_viewport()
		viewport.gui_disable_input = index != 0
		input_routes.append({"index": index, "viewport": str(viewport.get_path()),
			"disabled": viewport.gui_disable_input, "visible": pair.screens[index].visible})
		host_input_only = host_input_only and viewport.gui_disable_input == (index != 0)
	_check("party_pause.host_input_only", host_input_only and pair.screens[0].visible, input_routes)
	p = g.local_player
	p.set_physics_process(true)
	var pids: Array = []
	var roster_ok := true
	var roster_detail := {}
	for index in range(1, 4):
		var pid: int = pair.apis[index].get_unique_id()
		var guest: Game = pair.readers[index]
		var shell: Player = pair._shell(0, pid)
		var block: Dictionary = pair.wires[0].peer_chars.get(pid, {})
		var seen_host: bool = pair._shell(index, 1) != null
		var ok: bool = pid > 1 and not pids.has(pid) and pair.apis[0].get_peers().has(pid) \
			and shell != null and shell.peer_id == pid and String(block.get("name", "")) == String(names[index - 1]) \
			and guest.net_guest() and guest.guest_world and bool(pair.wires[index].world_ready) and seen_host
		roster_ok = roster_ok and ok
		roster_detail[str(pid)] = {"name": block.get("name", ""), "avatar": shell != null,
			"connected": pair.apis[0].get_peers().has(pid), "world_ready": bool(pair.wires[index].world_ready),
			"sees_host": seen_host}
		pids.append(pid)
	_check("party_pause.real_host_roster", roster_ok and pair.wires[0].peer_chars.size() == 3
		and pair.apis[0].get_peers().size() == 3, roster_detail)
	var cross := true
	for index in range(1, 4):
		for other in range(1, 4):
			if other == index: continue
			cross = cross and pair._shell(index, int(pids[other - 1])) != null
	_check("party_pause.guest_snapshots_cross_visible", cross, roster_detail)
	if not roster_ok:
		return "real host roster did not contain three connected 64-character guests"
	# Native positive movement control BEFORE the overlay; physics must really run.
	var before_pos := p.global_position
	_key_held(KEY_D, true)
	await pair._settle(0.25)
	_key_held(KEY_D, false)
	await pair._settle(0.15)
	_check("party_pause.input_positive_control_before", p.global_position.distance_to(before_pos) > 4.0,
		{"distance": p.global_position.distance_to(before_pos), "physics": p.is_physics_processing()})
	# Actual touch positive control, without an overlay, before testing blocking.
	_touch_mode(true)
	await r.frames(3)
	_finger(true, Vector2(180, 560))
	_drag(Vector2(240, 560), Vector2(60, 0))
	await pair._settle(0.12)
	var control_input: Node = g.get_node("/root/MobileInput")
	_check("party_pause.touch_positive_control", control_input.move.length() > 0.2 and g._touch_hud._move_touch == 0, str(control_input.move))
	_finger(false, Vector2(240, 560))
	_touch_mode(false)
	await r.frames(3)
	var economy := _economy()
	var roster_before := _roster_snapshot()
	var previous_god := g.dev_god
	g.dev_god = false
	p.cds.a1 = 2.5
	_key_held(int(g.binds.a1), true)
	await pair._settle(0.12)
	_check("party_pause.ability_positive_control", p.intent_a1 and p.cds.a1 > 0.0, p.intent_a1)
	_key_held(int(g.binds.a1), false)
	before_pos = p.global_position
	var anim_before := p.anim_t
	m.open_pause()
	var settled_labels: Array = await _party_observe_open("desktop", names)
	if settled_labels.size() != 3:
		m.close()
		g.dev_god = previous_god
		return "desktop pause did not retain three actual party rows"
	# Overflow is required: three 64-character rows must actually exceed the list.
	var scroll: ScrollContainer = _party_scroll(settled_labels)
	var overflows: bool = scroll != null and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 0.5
	_check("party_pause.roster_overflows", overflows, {"scroll": scroll != null,
		"max": scroll.get_v_scroll_bar().max_value if scroll != null else -1.0,
		"page": scroll.get_v_scroll_bar().page if scroll != null else -1.0})
	if not overflows:
		m.close()
		g.dev_god = previous_god
		return "party roster did not overflow its native scroller; strict scroll coverage is unavailable"
	var return_button: Button = native._find_button(m.root, "Return to game", true)
	_check("party_pause.fixed_return", return_button != null and not scroll.is_ancestor_of(return_button)
		and m._shell_rect.grow(0.5).encloses(return_button.get_global_rect())
		and m.get_viewport().get_visible_rect().encloses(return_button.get_global_rect()), "actual fixed Return action")
	var fixed_before: Dictionary = _party_fixed_rects(scroll)
	_check("party_pause.fixed_controls_present", not fixed_before.is_empty(), fixed_before)
	var tail: Button = native._find_button(m.root, "Save and quit game")
	if not _check("party_pause.actual_tail_present", tail != null, "Observe only; never activate Quit"):
		m.close()
		g.dev_god = previous_god
		return "actual final pause action missing"
	for index in settled_labels.size():
		var button: Button = settled_labels[index]
		var reached: bool = await _party_reach_button(button)
		_check("party_pause.actual_name_reached.%d" % index, reached and bool(native._pause_text_fit(button).passed), button.text)
		await _capture_online("party_name_%d_visible" % index)
	for attempt in range(60):
		if scroll.scroll_vertical == 0: break
		await native._wheel(MOUSE_BUTTON_WHEEL_UP, scroll.get_global_rect().get_center())
	_check("party_pause.wheel_start_top", scroll.scroll_vertical == 0, scroll.scroll_vertical)
	var wheel_before: int = scroll.scroll_vertical
	var wheel_taps := 0
	while wheel_taps < 60 and not _party_button_visible(tail, scroll):
		await native._wheel(MOUSE_BUTTON_WHEEL_DOWN, scroll.get_global_rect().get_center())
		wheel_taps += 1
	_check("party_pause.wheel_moves_and_reaches_tail", scroll.scroll_vertical > wheel_before
		and _party_button_visible(tail, scroll), {"before": wheel_before, "after": scroll.scroll_vertical, "taps": wheel_taps})
	_check("party_pause.wheel_fixed_controls", _party_fixed_rects(scroll) == fixed_before,
		{"before": fixed_before, "after": _party_fixed_rects(scroll)})
	await _capture_online("party_02_roster_wheel_tail")
	var up_taps := 0
	while up_taps < 60 and scroll.scroll_vertical > 0:
		await native._wheel(MOUSE_BUTTON_WHEEL_UP, scroll.get_global_rect().get_center())
		up_taps += 1
	_check("party_pause.wheel_returns_top", scroll.scroll_vertical == 0, scroll.scroll_vertical)
	# Keyboard focus traverses real controls; never activate the destructive tail.
	var focus_before: int = scroll.scroll_vertical
	var focus_steps := 0
	var focus_trace: Array[Dictionary] = [_party_focus_detail()]
	while focus_steps < 32 and m.get_viewport().gui_get_focus_owner() != tail:
		await native._key(KEY_TAB)
		focus_steps += 1
		focus_trace.append(_party_focus_detail())
	_check("party_pause.focus_follows_to_tail", m.get_viewport().gui_get_focus_owner() == tail
		and scroll.scroll_vertical > focus_before and _party_button_visible(tail, scroll),
		{"steps": focus_steps, "before": focus_before, "after": scroll.scroll_vertical, "tail": tail.text, "trace": focus_trace})
	_check("party_pause.focus_fixed_controls", _party_fixed_rects(scroll) == fixed_before, _party_fixed_rects(scroll))
	await _capture_online("party_02b_focus_tail")
	# Rebuild in genuine touch mode. The normal _open deferred hook must install
	# drag propagation; no direct private filter setup or stale-root references.
	_touch_mode(true)
	m.open_pause()
	var touch_rows: Array = await _party_observe_open("touch", names)
	if touch_rows.size() != 3:
		m.close()
		g.dev_god = previous_god
		return "touch pause did not retain three actual party rows"
	scroll = _party_scroll(touch_rows)
	tail = native._find_button(m.root, "Save and quit game")
	return_button = native._find_button(m.root, "Return to game", true)
	var touch_ready: bool = g.touch_mode and scroll != null and tail != null and return_button != null
	_check("party_pause.touch_controls_reacquired", touch_ready, {"touch_mode": g.touch_mode, "rows": touch_rows.size()})
	if not touch_ready:
		m.close()
		g.dev_god = previous_god
		return "new touch pause controls unavailable"
	_check("party_pause.touch_overflow", scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 0.5,
		{"max": scroll.get_v_scroll_bar().max_value, "page": scroll.get_v_scroll_bar().page})
	_check("party_pause.touch_starts_top", scroll.scroll_vertical == 0, scroll.scroll_vertical)
	_check("party_pause.touch_return_fixed", not scroll.is_ancestor_of(return_button)
		and m._shell_rect.grow(0.5).encloses(return_button.get_global_rect()), return_button.get_global_rect())
	fixed_before = _party_fixed_rects(scroll)
	_check("party_pause.touch_fixed_controls_present", not fixed_before.is_empty(), fixed_before)
	# Real screen-touch/drag injection through the shipped mouse-emulation path.
	# Native ScrollContainer consumes the resulting mouse events, not raw touch.
	var touch_capability: bool = Input.emulate_touch_from_mouse
	var touch_emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	_check("party_pause.touch_emulation_capability", g.touch_mode
		and Input.emulate_touch_from_mouse and Input.emulate_mouse_from_touch and DisplayServer.is_touchscreen_available(),
		{"native_touch_capability": DisplayServer.is_touchscreen_available(), "touch_mode": g.touch_mode, "emulate_touch_from_mouse": Input.emulate_touch_from_mouse,
			"emulate_mouse_from_touch": Input.emulate_mouse_from_touch,
			"method": "screen-touch and screen-drag events via shipped mouse emulation"})
	var touch_before: int = scroll.scroll_vertical
	var drags := 0
	while drags < 32 and not _party_button_visible(tail, scroll):
		var rect: Rect2 = scroll.get_global_rect()
		await native._confirm_touch_drag(Vector2(rect.get_center().x, rect.end.y - 8.0),
			Vector2(rect.get_center().x, rect.position.y + 8.0))
		drags += 1
	Input.emulate_mouse_from_touch = touch_emulation
	Input.emulate_touch_from_mouse = touch_capability
	_check("party_pause.touch_emulation_moves_and_reaches_tail", touch_before == 0 and scroll.scroll_vertical > touch_before
		and _party_button_visible(tail, scroll), {"before": touch_before, "after": scroll.scroll_vertical, "drags": drags})
	_check("party_pause.touch_fixed_controls", _party_fixed_rects(scroll) == fixed_before,
		{"before": fixed_before, "after": _party_fixed_rects(scroll)})
	await _capture_online("party_03_roster_touch_tail")
	# Reset the clock sentinel immediately before this bounded observation.
	p.cds.a1 = 2.5
	anim_before = p.anim_t
	before_pos = p.global_position
	# The shared online world clock keeps running while the hero stays blocked.
	_key_held(KEY_D, true)
	_key_held(int(g.binds.a1), true)
	await pair._settle(0.4)
	var ability_intent: bool = p.intent_a1
	_key_held(KEY_D, false)
	_key_held(int(g.binds.a1), false)
	_check("party_pause.live_world_blocks_hero", m.current == "pause" and not r.get_tree().paused
		and p.is_physics_processing() and not ability_intent and p.anim_t > anim_before
		and p.cds.a1 < 2.5 and p.cds.a1 > 0.0 and p.intent_move == Vector2.ZERO
		and p.global_position.distance_to(before_pos) <= 0.5,
		{"menu": m.current, "distance": p.global_position.distance_to(before_pos),
		"animation_delta": p.anim_t - anim_before, "cooldown": p.cds.a1, "held_ability_intent": ability_intent})
	_touch_mode(true)
	await r.frames(3)
	var joystick: Vector2 = scroll.get_global_rect().get_center()
	_finger(true, joystick)
	_drag(joystick + Vector2(80, 0), Vector2(80, 0))
	await pair._settle(0.3)
	var mi: Node = g.get_node("/root/MobileInput")
	_check("party_pause.blocks_touch_movement", m.current == "pause" and not g._touch_hud._enabled
		and mi.move == Vector2.ZERO and g._touch_hud._move_touch == -1
		and p.global_position.distance_to(before_pos) <= 0.5,
		{"menu": m.current, "distance": p.global_position.distance_to(before_pos), "move": str(mi.move)})
	_finger(false, joystick + Vector2(80, 0))
	_touch_mode(false)
	await r.frames(3)
	# World clock differences are NOT economy differences: this ledger has no clock.
	_check("party_pause.overlay_read_only", _economy() == economy and _roster_snapshot() == roster_before,
		{"economy_equal": _economy() == economy, "roster": _roster_snapshot()})
	await _host_removal_cancel()
	for route in ["escape", "controller", "raw_touch"]:
		if m.current != "pause":
			m.open_pause()
			await r.frames(4)
		var route_roster := _roster_snapshot()
		var route_economy := _economy()
		match route:
			"escape": await native._key(KEY_ESCAPE)
			"controller": await native._joy_back()
			"raw_touch":
				var emulation: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await native._touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulation
		await pair._settle(0.35)
		_check("party_pause.close_keeps_session." + route, not m.is_open() and not r.get_tree().paused
			and g.net_online() and _roster_snapshot() == route_roster and _economy() == route_economy,
			{"menu": m.current, "roster": _roster_snapshot()})
	g.dev_god = previous_god
	# Native positive movement control AFTER every overlay route.
	before_pos = p.global_position
	_key_held(KEY_D, true)
	await pair._settle(0.25)
	_key_held(KEY_D, false)
	await pair._settle(0.15)
	_check("party_pause.input_positive_control_after", p.global_position.distance_to(before_pos) > 4.0,
		{"distance": p.global_position.distance_to(before_pos), "physics": p.is_physics_processing()})
	_check("party_pause.party_intact_after", _roster_snapshot() == roster_before and _economy() == economy,
		_roster_snapshot())
	await _capture_online("party_04_party_intact")
	return ""


## Actual removal caller: Cancel and every safe close must never remove or kick.
func _host_removal_cancel() -> void:
	if m.current != "pause":
		m.open_pause()
		await r.frames(4)
	var remove: Button = native._find_button(m.root, "Remove")
	var before_roster := _roster_snapshot()
	var before_economy := _economy()
	if not _check("party_pause.removal_control_present", remove != null,
			"actual party removal control in the host pause roster"):
		return
	var removal_label: String = remove.text.strip_edges()
	for route in ["cancel", "escape", "controller", "raw_touch"]:
		if m.current != "pause":
			m.open_pause()
			await r.frames(4)
		remove = native._find_button(m.root, removal_label, true)
		if not _check("party_pause.removal_reentry." + route, remove != null, removal_label):
			return
		if not await _party_reach_button(remove):
			_check("party_pause.removal_reachable." + route, false, remove.text)
			return
		await native._mouse(remove.get_global_rect().get_center())
		await r.frames(4)
		if not _check("party_pause.removal_confirm_opens." + route, m.current == "confirm", m.current):
			return
		await _capture_online("party_remove_confirm_" + route)
		var affirmative: Button = native._find_button(m.root, "Remove player", true)
		_check("party_pause.removal_not_affirmative_focus." + route,
			affirmative != null and m.get_viewport().gui_get_focus_owner() != affirmative, "actual Remove player exists and is not auto-focused")
		match route:
			"cancel":
				var cancel: Button = native._find_button(m.root, "Cancel", true)
				if not _check("party_pause.removal_cancel_present", cancel != null, "Cancel"):
					return
				await native._mouse(cancel.get_global_rect().get_center())
			"escape": await native._key(KEY_ESCAPE)
			"controller": await native._joy_back()
			"raw_touch":
				var emulation: bool = Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				await native._touch(Vector2(12, 12))
				Input.emulate_mouse_from_touch = emulation
		await pair._settle(0.45)
		_check("party_pause.removal_cancel_keeps_party." + route, m.is_open() and m.current == "pause" and not r.get_tree().paused
			and _roster_snapshot() == before_roster and _economy() == before_economy
			and pair.wires[0].peer_chars.size() == 3 and pair.apis[0].get_peers().size() == 3,
			{"menu": m.current, "roster": _roster_snapshot()})
		if route == "cancel":
			await _capture_online("party_05_removal_cancelled")


func _roster_snapshot() -> Dictionary:
	var out := {"host_world": g.world.get_instance_id(), "host_session": g.net_session().get_instance_id()}
	for index in range(1, pair.readers.size()):
		var pid: int = pair.apis[index].get_unique_id()
		var shell: Player = pair._shell(0, pid)
		out[str(pid)] = {"name": String(pair.wires[0].peer_chars.get(pid, {}).get("name", "")),
			"char_name": String(pair.readers[index].player.char_name),
			"avatar": shell != null, "avatar_pid": shell.peer_id if shell != null else 0,
			"connected": pair.apis[0].get_peers().has(pid),
			"world_ready": bool(pair.wires[index].world_ready),
			"guest": pair.readers[index].net_guest(), "world": pair.readers[index].world.get_instance_id(),
			"session": pair.readers[index].net_session().get_instance_id(),
			"economy": pair._personal(pair.readers[index])}
	return out


## The production roster uses the actual Remove Button caption, not Labels.
func _party_labels(names: Array) -> Array:
	var out: Array = []
	for char_name in names:
		var caption: String = "✕  Remove %s from the party" % String(char_name)
		var button: Button = native._find_button(m.root, caption, true)
		if button != null: out.append(button)
	out.sort_custom(func(a: Button, b: Button) -> bool: return a.get_global_rect().position.y < b.get_global_rect().position.y)
	return out


func _party_row_geometry(button: Button) -> Dictionary:
	var rect: Rect2 = button.get_global_rect()
	# qa-v3 native observer is a required source dependency, not a fallback.
	var fit: Dictionary = native._pause_text_fit(button)
	var scroll: ScrollContainer = _party_scroll([button])
	return {"text": button.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"fit": fit, "horizontal": scroll != null and rect.position.x >= scroll.get_global_rect().position.x - 0.5
			and rect.end.x <= scroll.get_global_rect().end.x + 0.5,
		"currently_visible": scroll != null and _party_button_visible(button, scroll)}


func _party_row_checks(phase: String, geometry: Array) -> void:
	for index in geometry.size():
		var row: Dictionary = geometry[index]
		var exact_name := false
		for char_name in _party_names():
			if String(row.text).strip_edges() == "✕  Remove %s from the party" % String(char_name): exact_name = true
		var id: String = "party_pause.row." + phase + ".%d" % index
		_check(id + ".complete_name", exact_name and bool(row.fit.passed) and bool(row.horizontal), row)
		_check(id + ".target44_font18", bool(row.fit.passed), row.fit)
		_check(id + ".native_wrapping", bool(row.fit.wrapped) and int(row.fit.lines) > 1, row.fit)
		# Offscreen rows may be clipped by scrolling. Their full visibility is
		# proved separately after genuine input reaches each actual Button.


func _party_button_visible(button: Button, scroll: ScrollContainer) -> bool:
	var allowed: Rect2 = m.get_viewport().get_visible_rect().intersection(m._shell_rect)
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return button.is_visible_in_tree() and allowed.has_area() and allowed.grow(0.5).encloses(button.get_global_rect())


func _party_reach_button(button: Button) -> bool:
	var scroll: ScrollContainer = _party_scroll([button])
	if scroll == null: return false
	for attempt in range(60):
		if _party_button_visible(button, scroll): return true
		var direction: int = MOUSE_BUTTON_WHEEL_UP if button.get_global_rect().position.y < scroll.get_global_rect().position.y else MOUSE_BUTTON_WHEEL_DOWN
		await native._wheel(direction, scroll.get_global_rect().get_center())
	return _party_button_visible(button, scroll)


func _party_scroll(labels: Array) -> ScrollContainer:
	for label in labels:
		var node: Node = label.get_parent()
		while node != null and node != m.root:
			if node is ScrollContainer: return node
			node = node.get_parent()
	return null


## Every visible pause action/hint outside the scrolling roster must not move.
func _party_fixed_rects(scroll: ScrollContainer) -> Dictionary:
	var out := {}
	if not is_instance_valid(m.root): return out
	var nodes: Array[Node] = [m.root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		if not (node is Button or node is Label) or not node.is_visible_in_tree(): continue
		if scroll != null and scroll.is_ancestor_of(node): continue
		if String(node.text).strip_edges().is_empty(): continue
		var rect: Rect2 = node.get_global_rect()
		out[String(node.get_path()) + "|" + String(node.text)] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return out


func _party_native_actions(phase: String) -> Dictionary:
	var start: int = native.rows.size()
	var observed: Dictionary = native._pause_action_snapshot("party_" + phase)
	for index in range(start, native.rows.size()):
		var row: Dictionary = native.rows[index]
		_check("party_pause." + String(row.id), bool(row.passed), row.actual)
	return observed


## Must be called immediately after real open_pause, before any settling frames.
func _party_observe_open(id: String, names: Array) -> Array:
	await RenderingServer.frame_post_draw
	var initial: Control = m.get_viewport().gui_get_focus_owner()
	var safe: Button = native._find_button(m.root, "Return to game", true)
	var keyboard_entry: bool = not g.touch_mode and (g.gamepad == null or not g.gamepad.active)
	_check("party_pause." + id + ".safe_entry_focus", safe != null and (initial == safe if keyboard_entry else initial == null),
		{"keyboard": keyboard_entry, "focused": str(initial), "safe_action": safe.text if safe != null else "missing"})
	var first_actions: Dictionary = _party_native_actions(id + "_first")
	var first_rows: Array = _party_labels(names)
	var first_geometry: Array = []
	for button in first_rows: first_geometry.append(_party_row_geometry(button))
	if not r.flag("no-capture"):
		r.shot("party_" + id + "_first_draw", "actual first draw; four-reader real ENet; layout not yet accepted")
	_check("party_pause." + id + ".session_getter_precondition", first_rows.size() == 3 and g.net_session() == pair.wires[0],
		{"rows": first_rows.size(), "session": str(g.net_session()), "touch_mode": g.touch_mode, "requires": "actual host game.net_session roster"})
	if first_rows.size() != 3: return []
	_party_row_checks(id + "_first", first_geometry)
	await r.frames(4)
	await RenderingServer.frame_post_draw
	var settled_actions: Dictionary = _party_native_actions(id + "_settled")
	_check("party_pause." + id + ".all_actions_first_stable", first_actions == settled_actions,
		{"first": first_actions, "settled": settled_actions})
	var settled_rows: Array = _party_labels(names)
	var settled_geometry: Array = []
	for button in settled_rows: settled_geometry.append(_party_row_geometry(button))
	_check("party_pause." + id + ".rows_settled_present", settled_rows.size() == 3, settled_rows.size())
	if settled_rows.size() != 3: return []
	_party_row_checks(id + "_settled", settled_geometry)
	var delta := 0.0
	for index in range(first_geometry.size()):
		for component in range(4):
			delta = maxf(delta, absf(float(first_geometry[index].rect[component]) - float(settled_geometry[index].rect[component])))
	_check("party_pause." + id + ".row_rects_stable", delta <= 0.5,
		{"max_delta_px": delta, "first": first_geometry, "settled": settled_geometry})
	await _capture_online("party_" + id + "_settled")
	return settled_rows


## Diagnostic only: observe actual focus routing without assigning focus.
func _party_focus_detail() -> Dictionary:
	var local: Control = m.get_viewport().gui_get_focus_owner()
	var outer: Control = r.get_viewport().gui_get_focus_owner()
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.physical_keycode = KEY_TAB
	key.pressed = true
	return {"local": str(local.get_path()) if local != null else "none",
		"local_text": local.text if local is Button else "",
		"outer": str(outer.get_path()) if outer != null else "none",
		"next_matches_tab": InputMap.event_is_action(key, "ui_focus_next"),
		"focus_mode": local.focus_mode if local != null else -1}


## Exclusive party-name presentation probe; no existing episode is replaced.
static func run_party_names(fixture: Node) -> String:
	var proof := new()
	proof.pair = fixture
	proof.r = fixture
	proof.g = fixture.readers[0]
	proof.m = proof.g.menus
	proof.native = NativeInput.new()
	proof.native.r = fixture
	proof.native.g = proof.g
	proof.native.m = proof.m
	var language := Loc.lang
	Loc.lang = "en"
	var original_input: Array[bool] = []
	for reader in fixture.readers: original_input.append(reader.get_viewport().gui_disable_input)
	var error: String = await proof._party_name_checks()
	var restored := true
	for index in fixture.readers.size():
		fixture.readers[index].get_viewport().gui_disable_input = original_input[index]
		restored = restored and fixture.readers[index].get_viewport().gui_disable_input == original_input[index]
	proof._check("party_names.viewport_input_restored", restored, original_input)
	Loc.lang = language
	proof._check("party_names.completed", error == "", error)
	var failures := 0
	for row in proof.rows:
		failures += int(not bool(row.passed))
	fixture.report["party_names"] = {"checks": proof.rows.size(), "failures": failures,
		"rows": proof.rows,
		"qualification": "Host plus three real ENet guest worlds in one engine; production snapshots, host roster and native HUD geometry. Character names/slots are controlled fixtures; no ordinary collection, combat, persistence-roundtrip claim. Native host/guest full-name access uses the reviewed PartyIdentityHit/Body interface with mouse, raw touch and emulated touch; physical devices remain untested."}
	return error if error != "" else ("Party names strict checks failed" if failures > 0 else "")


func _party_name_checks() -> String:
	r.step("party names fixture: real host and three real ENet guest worlds in one capital")
	if pair.readers.size() != 4 or pair.transports.size() != 4:
		return "party names requires the host plus three guest readers"
	if not _check("party_names.shell_motion_disabled", not m.shell_motion, "inherited paired reader disables normal shell tween"):
		return "party reader must disable shell entry tween before first-draw observation"
	var names: Array = ["Ada", "W".repeat(16), "W".repeat(64)]
	for index in 4:
		pair.readers[index].switch_chapter("capital", true)
		await pair._quiet(index)
		pair.readers[index].settings["touch_controls"] = false
		pair.readers[index].refresh_touch_mode()
		pair.readers[index]._apply_touch_mode()
	if pair.transports[0].create_server(0, 3) != OK:
		return "party names ENet server bind failed"
	pair.apis[0].multiplayer_peer = pair.transports[0]
	for slot_index in 3:
		var guest: Game = pair.readers[slot_index + 1]
		guest.player.char_name = String(names[slot_index])
		guest.save_slot = int(pair.PARTY_SLOTS[slot_index])
		guest.no_saves = false
		SaveGame.write(guest, guest.save_slot)
		if not await pair._connect_party_guest(slot_index + 1, String(names[slot_index])):
			return "guest %d real ENet join/snapshot timed out" % (slot_index + 1)
		await pair._quiet(slot_index + 1)
	pair._show(0)
	var input_routes: Array[Dictionary] = []
	var host_input_only := true
	for index in pair.readers.size():
		var viewport: Viewport = pair.readers[index].get_viewport()
		viewport.gui_disable_input = index != 0
		input_routes.append({"index": index, "viewport": str(viewport.get_path()),
			"disabled": viewport.gui_disable_input, "visible": pair.screens[index].visible})
		host_input_only = host_input_only and viewport.gui_disable_input == (index != 0)
	_check("party_names.host_input_only", host_input_only and pair.screens[0].visible, input_routes)
	p = g.local_player
	var pids: Array = []
	var roster_ok := true
	var roster_detail := {}
	for index in range(1, 4):
		var pid: int = pair.apis[index].get_unique_id()
		var guest: Game = pair.readers[index]
		var shell: Player = pair._shell(0, pid)
		var block: Dictionary = pair.wires[0].peer_chars.get(pid, {})
		var seen_host: bool = pair._shell(index, 1) != null
		var ok: bool = pid > 1 and not pids.has(pid) and pair.apis[0].get_peers().has(pid) \
			and shell != null and shell.peer_id == pid and String(block.get("name", "")) == String(names[index - 1]) \
			and guest.net_guest() and guest.guest_world and bool(pair.wires[index].world_ready) and seen_host
		roster_ok = roster_ok and ok
		roster_detail[str(pid)] = {"name": block.get("name", ""), "avatar": shell != null,
			"connected": pair.apis[0].get_peers().has(pid), "world_ready": bool(pair.wires[index].world_ready),
			"sees_host": seen_host}
		pids.append(pid)
	_check("party_names.real_host_roster", roster_ok and pair.wires[0].peer_chars.size() == 3
		and pair.apis[0].get_peers().size() == 3, roster_detail)
	var cross := true
	for index in range(1, 4):
		for other in range(1, 4):
			if other == index: continue
			cross = cross and pair._shell(index, int(pids[other - 1])) != null
	_check("party_names.guest_snapshots_cross_visible", cross, roster_detail)
	if not roster_ok:
		return "real host roster did not contain three connected guests"
	var before_roster := _roster_snapshot()
	var before_host_economy: Dictionary = pair._personal(g)
	# Controlled owner positions travel over the existing live ENet state path.
	# Identity is never assigned to a remote shell or synthetic roster.
	var originals: Array[Vector2] = []
	var inverse: Transform2D = g.get_viewport().canvas_transform.affine_inverse()
	for index in range(1, 4):
		var owner: Player = pair.readers[index].local_player
		originals.append(owner.global_position)
		owner.global_position = inverse * Vector2(380 + index * 150, 370) + Vector2(0, 54)
	await pair._settle(1.2)
	await RenderingServer.frame_post_draw
	_party_name_observe("initial", names, pids)
	if not r.flag("no-capture"): r.shot("names_01_initial", "controlled owner positions; real transport; first observed HUD draw after snapshot settlement")
	await r.frames(4)
	await RenderingServer.frame_post_draw
	_party_name_observe("settled", names, pids)
	if not r.flag("no-capture"): r.shot("names_02_settled", "controlled owner positions; actual compact labels; visual review required")
	# Concrete reviewed HUD interface; every route uses native injected input.
	for reader_index in [0, 1]:
		await _party_identity_access(reader_index, String(names[2]), "reader_%d_mouse" % reader_index, false, false)
		await _party_identity_access(reader_index, String(names[2]), "reader_%d_raw_touch" % reader_index, true, false)
		await _party_identity_access(reader_index, String(names[2]), "reader_%d_emulated_touch" % reader_index, true, true)
	inverse = g.get_viewport().canvas_transform.affine_inverse()
	# Near-edge head projections exercise bounded name rectangles, not an
	# overlap solver. All three identities remain actual connected players.
	for index in range(1, 4):
		var owner: Player = pair.readers[index].local_player
		owner.global_position = inverse * Vector2([12.0, 640.0, 1268.0][index - 1], 380) + Vector2(0, 54)
	await pair._settle(1.2)
	await RenderingServer.frame_post_draw
	_party_name_observe("edges", names, pids)
	if not r.flag("no-capture"): r.shot("names_03_edges", "posed edge positions through ENet; not world traversal")
	# Real reliable state fanout, deliberately posed owner down state rather
	# than claiming combat. All temporary owner and host display state restores.
	var owner: Player = pair.readers[3].local_player
	var remote: Player = pair._shell(0, int(pids[2]))
	var saved := {"downed": owner.downed, "ghost": owner.ghost, "dead": owner.dead,
		"down_t": owner.down_t, "hp": owner.hp, "reviver": remote.being_revived_by}
	owner.downed = true
	owner.down_t = 9.0
	pair.wires[3].send_down_state(1)
	await pair._settle(0.2)
	remote.down_t = 9.0
	remote.being_revived_by = 1  # explicit display fixture; not a real revive channel
	await r.frames(2)
	await RenderingServer.frame_post_draw
	_party_name_observe("downed", names, pids)
	var down_slot: Dictionary = _party_name_slot(String(names[2]))
	if _check("party_names.downed.slot", not down_slot.is_empty(), "exact retained full-name Label.text"):
		var label: Label = down_slot.state
		var nm: Label = down_slot.name
		var glyph: Vector2 = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		var rect: Rect2 = label.get_global_rect()
		_check("party_names.downed.state_visible", remote.downed and label.is_visible_in_tree() and not nm.visible
			and label.text.begins_with("DOWNED ") and label.text.ends_with("reviving")
			and glyph.x <= rect.size.x + 0.5 and _party_name_card(down_slot).grow(0.5).encloses(rect),
			{"text": label.text, "glyph_size": glyph, "rect": rect})
	if not r.flag("no-capture"): r.shot("names_04_downed", "posed down/reviving display; not combat or revive acceptance")
	await _party_identity_access(0, String(names[2]), "downed_mouse", false, false)
	owner.downed = bool(saved.downed)
	owner.ghost = bool(saved.ghost)
	owner.dead = bool(saved.dead)
	owner.down_t = float(saved.down_t)
	owner.hp = float(saved.hp)
	pair.wires[3].send_down_state(0)
	remote.being_revived_by = int(saved.reviver)
	for index in range(1, 4): pair.readers[index].local_player.global_position = originals[index - 1]
	await pair._settle(0.3)
	_check("party_names.roster_and_economy_preserved", _roster_snapshot() == before_roster and pair._personal(g) == before_host_economy, _roster_snapshot())
	await _party_name_overlap_suite(pids)
	await _down_mark_edge_suite(pids)
	await _party_identity_lifecycle(String(names[2]), int(pids[2]))
	return ""


func _party_name_slot(full_name: String) -> Dictionary:
	for slot in g.hud.party_slots:
		var label: Label = slot.name
		if label.text == full_name and (slot.root as Control).is_visible_in_tree(): return slot
	return {}


func _party_name_card(slot: Dictionary) -> Rect2:
	# The existing root is size-zero. Its first ColorRect is the actual card
	# backdrop; the accent/fill are smaller later siblings, not card geometry.
	for child in (slot.root as Control).get_children():
		if child is ColorRect: return child.get_global_rect()
	return Rect2()


func _party_name_observe(phase: String, names: Array, pids: Array) -> void:
	var viewport: Rect2 = g.get_viewport().get_visible_rect()
	for index in names.size():
		var expected := String(names[index])
		var pid := int(pids[index])
		var remote: Player = pair._shell(0, pid)
		var slot := _party_name_slot(expected)
		var id := "party_names.%s.%d" % [phase, index]
		_check(id + ".identity", remote != null and String(remote.get_meta("net_name", "")) == expected
			and String(pair.wires[0].peer_chars.get(pid, {}).get("name", "")) == expected
			and String(pair.readers[index + 1].local_player.char_name) == expected,
			{"expected": expected, "peer": pid, "remote_name": remote.get_meta("net_name", "") if remote != null else "missing"})
		if not _check(id + ".slot", not slot.is_empty(), expected): continue
		if remote == null: continue  # strict identity failure already recorded; preserve report
		var label: Label = slot.name
		var card: Rect2 = _party_name_card(slot)
		var rect: Rect2 = label.get_global_rect()
		_check(id + ".compact_name", label.text == expected and card.has_area()
			and card.grow(0.5).encloses(rect) and viewport.grow(0.5).encloses(rect)
			and rect.size.x <= 164.5, {"name": label.text, "name_rect": rect, "card_rect": card, "visible": label.visible})
		var hp: Label = slot.hp_text
		var fill: ColorRect = slot.hp_fill
		var expected_hp := "%d/%d" % [int(remote.hp), int(remote.max_hp)]
		var expected_width: float = float(fill.get_meta("full_w")) * clampf(remote.hp / maxf(1.0, remote.max_hp), 0.0, 1.0)
		var hp_rect: Rect2 = hp.get_global_rect()
		# The existing centered 10px HP ink fits its bar even though the Label
		# retains a taller pre-font-override minimum. Do not turn unrelated old
		# Control bounds into a name-containment defect; preserve exact vitals.
		_check(id + ".vitals", hp.text == expected_hp and absf(fill.size.x - expected_width) <= 0.5
			and hp.is_visible_in_tree() and viewport.grow(0.5).encloses(hp_rect)
			and hp_rect.position.x >= card.position.x - 0.5 and hp_rect.end.x <= card.end.x + 0.5,
			{"text": hp.text, "expected": expected_hp, "fill": fill.size.x, "expected_fill": expected_width,
			"hp_control_rect": hp_rect, "card_rect": card, "font_px": hp.get_theme_font_size("font_size")})
		var found := false
		for tag in g.hud.party_names:
			if not tag.is_visible_in_tree() or tag.text != expected: continue
			found = true
			var world_rect: Rect2 = tag.get_global_rect()
			_check(id + ".world_containment", world_rect.size.x <= 160.5 and viewport.grow(0.5).encloses(world_rect)
				and tag.mouse_filter == Control.MOUSE_FILTER_IGNORE, {"name": tag.text, "rect": world_rect, "viewport": viewport})
		_check(id + ".world_visible", found, "visible exact full-name world Label required; posed on-screen head")
	_party_world_name_clear(phase, 3)


## Native pointer access on the concrete reviewed HUD interface. Guest access
## is required; host-only removal controls are not a full-name fallback.
func _party_identity_access(reader_index: int, full_name: String, phase: String, touch: bool, emulate: bool) -> void:
	var host_game: Game = g
	var host_menu: Menus = m
	var host_player: Player = p
	var before_roster := _roster_snapshot()
	var before_host_economy: Dictionary = pair._personal(g)
	var previous_emulation := Input.emulate_mouse_from_touch
	var previous_touch_emulation := Input.emulate_touch_from_mouse
	g = pair.readers[reader_index]
	m = g.menus
	p = g.local_player
	native.g = g
	native.m = m
	pair._show(reader_index)
	for index in pair.readers.size(): pair.readers[index].get_viewport().gui_disable_input = index != reader_index
	var prior_touch: bool = bool(g.settings.get("touch_controls", false))
	var prior_physics := p.is_physics_processing()
	var prior_god: bool = g.dev_god
	g.dev_god = false
	var prior_position := p.global_position
	var prior_velocity := p.velocity
	_touch_mode(touch)
	p.set_physics_process(true)
	Input.emulate_mouse_from_touch = emulate
	Input.emulate_touch_from_mouse = true
	await r.frames(3)
	var id := "party_names.access." + phase
	_check(id + ".capability", not touch or (g.touch_mode and (not emulate or (Input.emulate_mouse_from_touch and DisplayServer.is_touchscreen_available()))),
		{"touch": g.touch_mode, "emulated_mouse": Input.emulate_mouse_from_touch, "touch_from_mouse": Input.emulate_touch_from_mouse, "native_touch_capability": DisplayServer.is_touchscreen_available()})
	var slot: Dictionary = _party_name_slot(full_name)
	var card: Control = slot.get("hit") as Control
	if _check(id + ".card_present", card != null, "actual PartyIdentityHit in exact full-name ally slot"):
		var card_rect: Rect2 = card.get_global_rect()
		_check(id + ".target", card.is_visible_in_tree() and card_rect.size.y >= 44.0
			and g.get_viewport().get_visible_rect().encloses(card_rect), card_rect)
		var ally = g.hud._ally_by_peer(int(card.get_meta("peer", -1)))
		_check(id + ".identity_target", ally != null and String(ally.get_meta("net_name", "")) == full_name,
			{"reader": reader_index, "peer": card.get_meta("peer", -1), "name": full_name})
		# A positive touch joystick control precedes the protected card press.
		var mobile: Node = g.get_node("/root/MobileInput")
		if touch:
			_finger(true, Vector2(180, 560))
			_drag(Vector2(240, 560), Vector2(60, 0))
			await r.frames(2)
			_check(id + ".touch_positive", mobile.move.length() > 0.2 and g._touch_hud._move_touch == 0, str(mobile.move))
			_finger(false, Vector2(240, 560))
			await r.frames(2)
		var position_before := p.global_position
		var clock_before := p.anim_t
		var mana_before: float = p.mp
		var cooldowns_before: Dictionary = p.cds.duplicate()
		var dialogue_before: bool = g.hud.dialogue_active
		if touch: _finger(true, card_rect.get_center())
		else: _pointer(true, card_rect.get_center())
		await RenderingServer.frame_post_draw
		var expected_body: String = full_name + "\n" + (String(ally.cls).capitalize() if ally != null else "missing")
		var first_geometry := _party_identity_geometry(id + ".first", expected_body)
		if not r.flag("no-capture"): r.shot("names_access_" + phase + "_first", "first native popup draw after actual press; no prior settling frames")
		var leaked := false
		var sampled: Array[Dictionary] = []
		for sample in 3:
			await r.get_tree().physics_frame
			var cast := p.mp < mana_before - 0.01
			for ability in cooldowns_before: cast = cast or float(p.cds[ability]) > float(cooldowns_before[ability]) + 0.05
			var active: bool = mobile.move.length() > 0.01 or mobile.a1 or mobile.a2 or mobile.a3 or mobile.ult or mobile.interact
			leaked = leaked or cast or active or g.hud.dialogue_active != dialogue_before or p.intent_interact
			sampled.append({"sample": sample, "cast_witness": cast, "mobile_active": active, "mana": p.mp, "dialogue": g.hud.dialogue_active})
		_check(id + ".physics_samples_no_new_action", not leaked, sampled)
		_check(id + ".press_no_input_leak", p.global_position.distance_to(position_before) < 1.0
			and p.intent_move.length() < 0.01 and not p.intent_a1 and not p.intent_a2 and not p.intent_a3 and not p.intent_ult
			and mobile.move.length() < 0.01 and not mobile.a1 and not mobile.a2 and not mobile.a3 and not mobile.ult,
			{"distance": p.global_position.distance_to(position_before), "move": str(mobile.move), "touch": touch, "emulation": emulate})
		if touch: _finger(false, card_rect.get_center())
		else: _pointer(false, card_rect.get_center())
		await r.frames(3)
		await RenderingServer.frame_post_draw
		var settled_geometry := _party_identity_geometry(id + ".settled", expected_body)
		_check(id + ".first_settled_geometry", not first_geometry.is_empty() and first_geometry == settled_geometry, {"first": first_geometry, "settled": settled_geometry})
		var pop: Control = g.hud.hud_popover
		var body: Label = pop.find_child("PartyIdentityBody", true, false) as Label if is_instance_valid(pop) else null
		var one_popup := 0
		for child in g.hud.get_children():
			if child is Control and child.has_meta("party_peer") and child.is_visible_in_tree(): one_popup += 1
		_check(id + ".one_persistent_popup", one_popup == 1 and is_instance_valid(body), {"count": one_popup, "body": str(body)})
		if is_instance_valid(body) and ally != null:
			var expected: String = full_name + "\n" + String(ally.cls).capitalize()
			var allowed: Rect2 = g.get_viewport().get_visible_rect()
			var ancestor: Node = body.get_parent()
			while ancestor != null:
				if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			var rect: Rect2 = body.get_global_rect()
			var line_height: float = body.get_theme_font("font").get_height(body.get_theme_font_size("font_size"))
			_check(id + ".complete_identity", body.text == expected and body.is_visible_in_tree()
				and body.visible_characters == -1 and body.lines_skipped == 0 and body.max_lines_visible == -1
				and allowed.grow(0.5).encloses(rect) and rect.size.y + 0.5 >= line_height * body.get_line_count()
				and body.get_theme_font_size("font_size") >= 16,
				{"text": body.text, "expected": expected, "rect": rect, "clip": allowed, "lines": body.get_line_count(), "line_height": line_height})
			_check(id + ".same_peer", int(pop.get_meta("party_peer", -1)) == int(ally.peer_id), pop.get_meta("party_peer", -1))
			if ally.downed:
				_check(id + ".downed_still_visible", (slot.state as Label).is_visible_in_tree() and not (slot.name as Label).visible,
					(slot.state as Label).text)
		_check(id + ".world_running", not r.get_tree().paused and p.anim_t > clock_before,
			{"paused": r.get_tree().paused, "before": clock_before, "after": p.anim_t})
		if not r.flag("no-capture"): r.shot("names_access_" + phase, "actual native full-name read; real ENet reader; controlled name/capital fixture")
		# Popup reserves the whole screen for pointer dismissal. No keyboard
		# movement-block claim: this is an information reader in a running world.
		position_before = p.global_position
		if touch: await native._touch(Vector2(20, 600))
		else: await native._mouse(Vector2(20, 600))
		await r.frames(3)
		_check(id + ".dismissed_without_input_leak", not is_instance_valid(g.hud.hud_popover)
			and p.global_position.distance_to(position_before) < 1.0 and mobile.move.length() < 0.01,
			{"popup": str(g.hud.hud_popover), "distance": p.global_position.distance_to(position_before)})
	# No early-return path skips capability/reader restoration.
	_pointer(false, Vector2(20, 600))
	_finger(false, Vector2(20, 600))
	p.set_physics_process(prior_physics)
	g.dev_god = prior_god
	p.global_position = prior_position
	p.velocity = prior_velocity
	_touch_mode(prior_touch)
	Input.emulate_mouse_from_touch = previous_emulation
	Input.emulate_touch_from_mouse = previous_touch_emulation
	g = host_game
	m = host_menu
	p = host_player
	native.g = g
	native.m = m
	pair._show(0)
	for index in pair.readers.size(): pair.readers[index].get_viewport().gui_disable_input = index != 0
	await pair._settle(0.25)  # owner position and camera settle before next edge fixture
	_check(id + ".identity_world_economy_preserved", _roster_snapshot() == before_roster and pair._personal(g) == before_host_economy, _roster_snapshot())


func _party_identity_geometry(id: String, expected: String) -> Dictionary:
	var pop: Control = g.hud.hud_popover
	var body: Label = pop.find_child("PartyIdentityBody", true, false) as Label if is_instance_valid(pop) else null
	if not _check(id + ".body_present", body != null, "actual first/settled native party reader"): return {}
	var rect: Rect2 = body.get_global_rect()
	var allowed: Rect2 = g.get_viewport().get_visible_rect()
	var panel: Control = body.get_parent().get_parent()
	var ancestor: Node = body.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	var line_height: float = body.get_theme_font("font").get_height(body.get_theme_font_size("font_size"))
	_check(id + ".whole_body", body.text == expected and body.is_visible_in_tree()
		and body.visible_characters == -1 and body.lines_skipped == 0 and body.max_lines_visible == -1
		and allowed.grow(0.5).encloses(rect) and rect.size.y + 0.5 >= line_height * body.get_line_count(),
		{"text": body.text, "expected": expected, "rect": rect, "clip": allowed, "lines": body.get_line_count(), "line_height": line_height})
	return {"body": rect, "panel": panel.get_global_rect(), "text": body.text}


func _party_identity_native_open(full_name: String, id: String) -> bool:
	var slot := _party_name_slot(full_name)
	var card: Control = slot.get("hit") as Control
	if not _check(id + ".card", card != null, full_name): return false
	await native._mouse(card.get_global_rect().get_center())
	await r.frames(2)
	return _check(id + ".opened", is_instance_valid(g.hud.hud_popover)
		and g.hud.hud_popover.has_meta("party_peer"), str(g.hud.hud_popover))


## Controlled lifecycle calls supplement real pointer entry. Disconnect is last:
## it intentionally ends one isolated guest transport, never kicks a real user.
func _party_identity_lifecycle(full_name: String, departing_peer: int) -> void:
	var id := "party_names.lifecycle"
	var prior_touch: bool = bool(g.settings.get("touch_controls", false))
	var old_mouse := Input.emulate_mouse_from_touch
	var old_touch := Input.emulate_touch_from_mouse
	var prior_physics := p.is_physics_processing()
	var prior_god: bool = g.dev_god
	g.dev_god = false
	var prior_pos := p.global_position
	var prior_velocity := p.velocity
	var prior_cd: float = p.cds.a1
	_touch_mode(true)
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false  # separate mouse must not steal finger0
	p.set_physics_process(true)
	await r.frames(3)
	var mobile: Node = g.get_node("/root/MobileInput")
	_finger(true, Vector2(180, 560))
	_drag(Vector2(240, 560), Vector2(60, 0))
	await r.frames(2)
	_check(id + ".held_stick_positive", mobile.move.length() > 0.2 and g._touch_hud._move_touch == 0, str(mobile.move))
	if await _party_identity_native_open(full_name, id + ".stick"):
		_check(id + ".stick_not_stolen", g._touch_hud._move_touch == 0, g._touch_hud._move_touch)
	_finger(false, Vector2(240, 560))
	await r.frames(3)
	_check(id + ".stick_release_clean", mobile.move.length() < 0.01 and g._touch_hud._move_touch == -1, str(mobile.move))
	await native._mouse(Vector2(20, 600))
	var ability: Dictionary = g._touch_hud._btns.a1
	var center: Vector2 = (ability.panel as Control).get_global_rect().get_center()
	p.cds.a1 = 2.5  # explicit cooldown guard: this phase proves intent release, not a cast
	_finger(true, center)
	await r.frames(1)
	_check(id + ".held_button_positive", g._touch_hud._btn_touch.get(0, "") == "a1", g._touch_hud._btn_touch)
	await _party_identity_native_open(full_name, id + ".button")
	_check(id + ".button_not_stolen", g._touch_hud._btn_touch.get(0, "") == "a1", g._touch_hud._btn_touch)
	_check(id + ".release_cooldown_guard", not g.dev_god and p.cds.a1 > 0.5, {"god": g.dev_god, "cooldown": p.cds.a1})
	_finger(false, center)
	_check(id + ".legitimate_release_pulse", mobile.a1 and g._touch_hud._pulse.has("a1") and not g._touch_hud._btn_touch.has(0),
		{"ability": mobile.a1, "pulse": g._touch_hud._pulse.duplicate(), "touches": g._touch_hud._btn_touch.duplicate()})
	await pair._settle(0.35)
	_finger(false, center)  # redundant release cannot create a second tap pulse
	await r.frames(1)
	_check(id + ".button_release_clean", not mobile.a1 and not g._touch_hud._pulse.has("a1")
		and not g._touch_hud._btn_touch.has(0) and not g._touch_hud._press_start.has(0), "no stuck claim/pulse or duplicate release pulse")
	if not r.flag("no-capture"): r.shot("names_lifecycle_held_release", "actual held-touch release with read-only party popup; cooldown-guarded intent test, not ability cast")
	await native._mouse(Vector2(20, 600))
	p.set_physics_process(prior_physics)
	g.dev_god = prior_god
	p.global_position = prior_pos
	p.velocity = prior_velocity
	p.cds.a1 = prior_cd
	_touch_mode(prior_touch)
	Input.emulate_mouse_from_touch = old_mouse
	Input.emulate_touch_from_mouse = old_touch
	await pair._settle(0.2)
	for action in ["hide", "reset", "menu"]:
		if not await _party_identity_native_open(full_name, id + "." + action): continue
		if action == "hide": g.hud._hide_party_ui()
		elif action == "reset": g.hud.reset_party_ui()
		else: await native._key(KEY_ESCAPE)
		await r.frames(3)
		_check(id + ".owned_closed_" + action, not is_instance_valid(g.hud.hud_popover), str(g.hud.hud_popover))
		if action == "menu":
			_check(id + ".native_pause_open", m.is_open() and m.current == "pause", m.current)
			await native._key(KEY_ESCAPE)
	# Existing non-party popover is deliberately opened through its fixture API;
	# party-specific hide/reset must not broaden ownership to close this reader.
	for action in ["hide", "reset"]:
		g.hud._open_hud_popover("QA reader", "Unrelated HUD information", Vector2(300, 300))
		await r.frames(2)
		var untagged: Control = g.hud.hud_popover
		if action == "hide": g.hud._hide_party_ui()
		else: g.hud.reset_party_ui()
		await r.frames(3)
		_check(id + ".untagged_preserved_" + action, is_instance_valid(untagged) and g.hud.hud_popover == untagged
			and not untagged.has_meta("party_peer"), str(g.hud.hud_popover))
		await native._mouse(Vector2(20, 600))
	if await _party_identity_native_open(full_name, id + ".departing"):
		pair.transports[3].close()
		pair.apis[3].multiplayer_peer = null
		pair.roots[3].online = false
		pair.readers[3].qa_online = false
		pair.wires[3].set_physics_process(false)
		pair.wires[3]._on_session_ended("party identity fixture disconnect")
		var removed: bool = await pair._until(func() -> bool: return not pair.apis[0].get_peers().has(departing_peer) and pair._shell(0, departing_peer) == null)
		await r.frames(3)
		_check(id + ".real_peer_departure_closed", removed and not is_instance_valid(g.hud.hud_popover)
			and pair.apis[0].get_peers().size() == 2, {"removed": removed, "remaining": pair.apis[0].get_peers().size(), "popup": str(g.hud.hud_popover)})
		if not r.flag("no-capture"): r.shot("names_lifecycle_peer_departed", "intentional final isolated guest transport teardown; stale-party-popup lifecycle, not kick action")


## Controlled owner poses and reliable down-state fanout in the existing four
## real ENet worlds. Display channel/time are fixtures, not an earned revive.
func _down_mark_edge_suite(pids: Array) -> void:
	var snapshots: Array[Dictionary] = []
	var fields: Array[String] = ["downed", "ghost", "dead", "down_t", "hp", "being_revived_by", "revive_bar_ms", "global_position"]
	for reader in pair.readers:
		for actor in reader.players:
			var values := {}
			for field in fields: values[field] = actor.get(field)
			snapshots.append({"actor": actor, "values": values})
	var last_down_room: int = pair.wires[0]._last_down_room
	var roster := _roster_snapshot()
	var economy: Dictionary = pair._personal(g)
	var states: Array[int] = [1, 2, 1]
	for index in 3:
		var owner: Player = pair.readers[index + 1].local_player
		owner.downed = states[index] == 1
		owner.ghost = states[index] == 2
		owner.dead = false
		owner.down_t = 7.0
		pair.wires[index + 1].send_down_state(states[index])
	await pair._settle(0.3)
	var labels: Array[String] = ["DOWNED 7s", "GHOST", "REVIVING"]
	var prior_touch: bool = bool(g.settings.get("touch_controls", false))
	var prior_names_alpha: float = g.hud.party_names_alpha
	var phases: Array[String] = ["clear_center", "center", "left", "right", "top", "bottom", "outside_left", "outside_right", "outside_top", "outside_bottom", "touch_right"]
	for phase in phases:
		# Explicit unobstructed control; ordinary center retains visible identities.
		g.hud.party_names_alpha = 0.0 if phase == "clear_center" else prior_names_alpha
		if phase == "touch_right":
			_touch_mode(true)
			await r.frames(3)
			_check("party_names.down_marks.touch_right.mode", g.touch_mode and g._touch_hud.visible, "actual touch setting/controls enabled; host rendering only")
		var viewport: Rect2 = g.get_viewport().get_visible_rect()
		var targets := _down_mark_targets(phase, viewport)
		var inverse: Transform2D = g.get_viewport().canvas_transform.affine_inverse()
		for index in 3:
			pair.readers[index + 1].local_player.global_position = inverse * targets[index]
		await pair._settle(1.2)
		var present := true
		for index in 3:
			var remote: Player = pair._shell(0, int(pids[index]))
			present = present and remote != null
			if remote != null:
				remote.down_t = 7.0  # explicit countdown display fixture after real fanout
				remote.being_revived_by = int(pids[1]) if index == 2 else 0
				if index == 2: remote.revive_bar_ms = Time.get_ticks_msec() - 1200
		_check("party_names.down_marks." + phase + ".peers", present, pids)
		var countdown_before: float = pair._shell(0, int(pids[0])).down_t if present else -1.0
		var before_ms: int = Time.get_ticks_msec()
		await r.frames(2)
		await RenderingServer.frame_post_draw
		var after_ms: int = Time.get_ticks_msec()
		var outside: bool = phase.begins_with("outside_")
		var visible_marks: Array[Dictionary] = []
		for mark in g.hud.down_marks:
			if (mark.root as Control).is_visible_in_tree(): visible_marks.append(mark)
		_check("party_names.down_marks." + phase + ".count", visible_marks.size() == (0 if outside else 3),
			{"visible": visible_marks.size(), "outside": outside})
		for index in 3:
			var id := "party_names.down_marks.%s.%d" % [phase, index]
			var remote: Player = pair._shell(0, int(pids[index]))
			if remote == null: continue  # peers check already fails; preserve report/restore
			var xf: Transform2D = g.get_viewport().canvas_transform
			var feet: Vector2 = xf * remote.global_position
			_check(id + ".transport_pose", feet.distance_to(targets[index]) <= 2.0,
				{"actual_feet": feet, "planned_feet": targets[index], "transform": str(xf)})
			_check(id + ".state", remote.downed == (states[index] == 1) and remote.ghost == (states[index] == 2)
				and remote.being_revived_by == (int(pids[1]) if index == 2 else 0),
				{"downed": remote.downed, "ghost": remote.ghost, "reviver": remote.being_revived_by, "channel": remote.REVIVE_CHANNEL})
			if outside: continue
			var expected_texts: Array[String] = [labels[index]]
			if index == 0:
				expected_texts.clear()
				# The shell ticks independently; permit only exact countdown values
				# observed across this draw, never an unbounded prefix match.
				for second in range(int(ceil(remote.down_t)), int(ceil(countdown_before)) + 1):
					expected_texts.append("DOWNED %ds" % second)
			var found: Dictionary = {}
			for mark in visible_marks:
				if expected_texts.has((mark.label as Label).text): found = mark
			if not _check(id + ".text_present", not found.is_empty(), {"exact_allowed": expected_texts, "countdown_before": countdown_before, "countdown_after": remote.down_t}): continue
			_down_mark_geometry(id, found, viewport)
			var bg: ColorRect = found.bg
			var fill: ColorRect = found.fill
			var low: float = clampf(float(before_ms - remote.revive_bar_ms) / (remote.REVIVE_CHANNEL * 1000.0), 0.0, 1.0)
			var high: float = clampf(float(after_ms - remote.revive_bar_ms) / (remote.REVIVE_CHANNEL * 1000.0), 0.0, 1.0)
			_check(id + ".progress", bg.visible == (index == 2) and fill.visible == (index == 2)
				and (index != 2 or (fill.size.x >= 60.0 * low - 0.5 and fill.size.x <= 60.0 * high + 0.5)),
				{"fill_px": fill.size.x, "before_progress": low, "after_progress": high, "channel_seconds": remote.REVIVE_CHANNEL,
				"bg_visible": bg.visible, "fill_visible": fill.visible})
			if phase == "clear_center":
				_check(id + ".interior_anchor", (found.root as Control).position.distance_to(xf * (remote.global_position + Vector2(0, -74))) <= 0.5,
					{"actual": (found.root as Control).position, "authored_head": xf * (remote.global_position + Vector2(0, -74))})
		if outside:
			var arrows := 0
			for arrow in g.hud.party_arrows: arrows += int(arrow.is_visible_in_tree())
			_check("party_names.down_marks." + phase + ".arrows", arrows == 3, arrows)
		_down_mark_hud_clear(phase, visible_marks)
		var expected_world_names := 0 if phase in ["clear_center", "top", "outside_left", "outside_right", "outside_top"] else 3
		_party_world_name_clear("down_" + phase, expected_world_names)
		if not r.flag("no-capture"): r.shot("down_marks_" + phase, "controlled owner poses over real ENet; three reliable down states; channel/countdown display fixtures, not earned revive")
	g.hud.party_names_alpha = prior_names_alpha
	_check("party_names.down_marks.names_setting_restored", g.hud.party_names_alpha == prior_names_alpha, prior_names_alpha)
	_touch_mode(prior_touch)
	_check("party_names.down_marks.touch_setting_restored", bool(g.settings.get("touch_controls", false)) == prior_touch, prior_touch)
	# Restore every reader's existing actor state; reliable owner reset first,
	# exact saved presentation values afterward, including shell countdowns.
	for index in 3:
		var owner: Player = pair.readers[index + 1].local_player
		for snapshot in snapshots:
			if snapshot.actor == owner:
				for field in fields: owner.set(field, snapshot.values[field])
		pair.wires[index + 1].send_down_state(1 if owner.downed else (2 if owner.ghost else 0))
	await pair._settle(0.3)
	for snapshot in snapshots:
		if is_instance_valid(snapshot.actor):
			for field in fields: snapshot.actor.set(field, snapshot.values[field])
			snapshot.actor._refresh_down_visual()
	pair.wires[0]._last_down_room = last_down_room
	g.hud._hide_down_ui()
	var hidden := true
	for mark in g.hud.down_marks: hidden = hidden and not (mark.root as Control).visible
	_check("party_names.down_marks.hide", hidden, "controlled existing hide API; normal update resumes next frame")
	var restored_fields := true
	var restoration: Array[Dictionary] = []
	for snapshot in snapshots:
		if not is_instance_valid(snapshot.actor):
			restored_fields = false
			continue
		for field in fields:
			var same: bool = snapshot.actor.get(field) == snapshot.values[field]
			if field == "global_position": same = snapshot.actor.global_position == snapshot.values[field]
			restored_fields = restored_fields and same
			if not same: restoration.append({"peer": snapshot.actor.peer_id, "field": field, "actual": snapshot.actor.get(field), "saved": snapshot.values[field]})
	_check("party_names.down_marks.actor_fields_restored", restored_fields and pair.wires[0]._last_down_room == last_down_room, restoration)
	await r.frames(3)
	await RenderingServer.frame_post_draw
	var visible := 0
	for mark in g.hud.down_marks: visible += int((mark.root as Control).is_visible_in_tree())
	_check("party_names.down_marks.restored", visible == 0 and _roster_snapshot() == roster and pair._personal(g) == economy,
		{"visible_marks": visible, "roster": _roster_snapshot(), "economy_unchanged": pair._personal(g) == economy})


func _down_mark_targets(phase: String, viewport: Rect2) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for index in 3:
		var point := viewport.position + Vector2(viewport.size.x * (0.375 + index * 0.125), viewport.size.y * 0.58)
		if phase.ends_with("left") or phase.ends_with("right"):
			point.y = viewport.position.y + viewport.size.y * (0.375 + index * 0.18)
		if phase == "left": point.x = viewport.position.x + 2.0
		elif phase == "right" or phase == "touch_right": point.x = viewport.end.x - 2.0
		elif phase == "top": point.y = viewport.position.y + 2.0
		elif phase == "bottom": point.y = viewport.end.y - 2.0
		elif phase == "outside_left": point.x = viewport.position.x - 12.0
		elif phase == "outside_right": point.x = viewport.end.x + 12.0
		elif phase == "outside_top": point.y = viewport.position.y - 12.0
		elif phase == "outside_bottom": point.y = viewport.end.y + 12.0
		targets.append(point)
	return targets


func _down_mark_geometry(id: String, mark: Dictionary, viewport: Rect2) -> void:
	var label: Label = mark.label
	var rect: Rect2 = label.get_global_rect()
	var allowed := viewport
	var ancestor: Node = label
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	var outline: int = label.get_theme_constant("outline_size")
	var cells: Array[Rect2] = []
	var missing: Array[int] = []
	var contained := allowed.grow(0.5).encloses(rect.grow(outline))
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges() == "": continue
		var cell: Rect2 = label.get_character_bounds(index)
		if not cell.has_area(): missing.append(index)
		else:
			var global_cell := Rect2(rect.position + cell.position, cell.size)
			cells.append(global_cell)
			contained = contained and allowed.grow(0.5).encloses(global_cell.grow(outline))
	var bars: Array[Rect2] = []
	for control in [mark.bg, mark.fill]:
		if control.is_visible_in_tree():
			var bar: Rect2 = control.get_global_rect()
			bars.append(bar)
			contained = contained and viewport.grow(0.5).encloses(bar)
	_check(id + ".geometry", contained and missing.is_empty() and not cells.is_empty()
		and label.visible_characters == -1 and label.lines_skipped == 0 and label.max_lines_visible == -1,
		{"text": label.text, "label_rect": rect, "cells": cells, "missing": missing, "outline": outline,
		"bars": bars, "viewport": viewport, "allowed": allowed})


## Independent post-draw collision oracle: native painted HUD Controls, never
## the production placement candidate list or its clamp/slide algorithm.
func _down_mark_hud_clear(phase: String, visible_marks: Array[Dictionary]) -> void:
	if phase.begins_with("outside_"): return
	var overlay: Dictionary = _party_overlay_painted()
	var painted: Array[Dictionary] = overlay.painted
	var party_cards: int = int(overlay.party_cards)
	var action_panels: int = int(overlay.action_panels)
	var categories := {}
	for item in painted: categories[item.id] = int(categories.get(item.id, 0)) + 1
	var id := "party_names.down_marks." + phase + ".hud_clear"
	_check(id + ".blockers_present", categories.has("vitals") and categories.has("info")
		and categories.has("minimap") and categories.has("zone") and party_cards == 3 and action_panels >= 5,
		{"categories": categories, "party_cards": party_cards, "action_panels": action_panels, "touch": g.touch_mode})
	var expected_names := 0 if phase == "clear_center" or phase == "top" else 3
	_check(id + ".world_names_present", int(categories.get("world_name", 0)) == expected_names,
		{"actual": int(categories.get("world_name", 0)), "expected": expected_names, "names_alpha": g.hud.party_names_alpha})
	var envelopes: Array[Rect2] = []
	for index in visible_marks.size():
		var mark: Dictionary = visible_marks[index]
		var label: Label = mark.label
		var envelope: Rect2 = label.get_global_rect().grow(float(label.get_theme_constant("outline_size")))
		for control in [mark.bg, mark.fill]:
			if control.is_visible_in_tree(): envelope = envelope.merge(control.get_global_rect())
		var collisions: Array[Dictionary] = []
		for item in painted:
			if envelope.intersects(item.rect): collisions.append(item)
		_check(id + ".mark%d" % index, collisions.is_empty(),
			{"text": label.text, "mark_rect": envelope, "collisions": collisions, "painted_count": painted.size()})
		var peers: Array[Rect2] = []
		for earlier in envelopes:
			if envelope.intersects(earlier): peers.append(earlier)
		if index > 0:
			_check(id + ".pair%d" % index, peers.is_empty(), {"mark_rect": envelope, "earlier_overlaps": peers})
		envelopes.append(envelope)


func _down_mark_paint_walk(out: Array[Dictionary], tag: String, node: Node) -> void:
	if node is CanvasItem and (not node.is_visible_in_tree() or node.modulate.a <= 0.01): return
	# Size-zero grouping Controls may own painted children; never prune them.
	if node is Control and node.size.x > 0.0 and node.size.y > 0.0:
		var painted: bool = node.self_modulate.a > 0.01
		if node is Label: painted = painted and not node.text.is_empty()
		if painted:
			var rect: Rect2 = node.get_global_rect()
			if node is Label: rect = rect.grow(float(node.get_theme_constant("outline_size")))
			var ancestor: Node = node.get_parent()
			while ancestor != null:
				if ancestor is Control and ancestor.clip_contents: rect = rect.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			if rect.has_area(): out.append({"id": tag, "path": str(node.get_path()), "rect": rect})
	for child in node.get_children(): _down_mark_paint_walk(out, tag, child)


func _party_overlay_painted() -> Dictionary:
	var painted: Array[Dictionary] = []
	var roots := {"vitals": g.hud.vitals_panel, "info": g.hud.info_panel,
		"minimap": g.hud.minimap_root, "zone": g.hud.zone_label,
		"tracker_panel": g.hud.quest_panel, "quest": g.hud.quest_label,
		"wayfinder_quest": g.hud.wayfinder.quest_root,
		"boss": g.hud.boss_box, "mob": g.hud.mob_box, "rival": g.hud.rival_box}
	for key in roots:
		if is_instance_valid(roots[key]): _down_mark_paint_walk(painted, String(key), roots[key])
	for tag in g.hud.party_names:
		_down_mark_paint_walk(painted, "world_name", tag)
	var party_cards := 0
	for slot in g.hud.party_slots:
		if is_instance_valid(slot.root) and (slot.root as Control).is_visible_in_tree():
			var card: Rect2 = _party_name_card(slot)
			if card.has_area():
				party_cards += 1
				painted.append({"id": "party_card", "path": str(slot.root.get_path()), "rect": card})
	var action_panels := 0
	if g.touch_mode:
		for key in g._touch_hud._btns:
			var panel: Control = g._touch_hud._btns[key].panel
			if panel.is_visible_in_tree() and panel.size.x > 0.0 and panel.size.y > 0.0:
				action_panels += 1
				_down_mark_paint_walk(painted, "touch_" + String(key), panel)
	else:
		for slot in g.hud.slot_boxes:
			if (slot.bg as Control).is_visible_in_tree(): action_panels += 1
			for key in ["border", "bg", "icon", "key", "name", "cost"]:
				_down_mark_paint_walk(painted, "hotbar_" + String(key), slot[key])
	# Current selected world prompt is an actual Label in world canvas space.
	# Read its native screen transform, not the production prompt solver.
	for entry in g.interactables:
		var prompt: Variant = entry.get("prompt")
		if not is_instance_valid(prompt) or not prompt is Label or not prompt.is_visible_in_tree() or prompt.text.is_empty(): continue
		var box := Rect2(Vector2.ZERO, prompt.size).grow(float(prompt.get_theme_constant("outline_size")))
		painted.append({"id": "interaction", "path": str(prompt.get_path()), "rect": prompt.get_global_transform_with_canvas() * box})
	return {"painted": painted, "party_cards": party_cards, "action_panels": action_panels}


## Independent native world-label geometry; no production solver or metadata.
func _party_world_name_clear(phase: String, expected_count: int) -> void:
	var overlay: Dictionary = _party_overlay_painted()
	var painted: Array[Dictionary] = overlay.painted
	var categories := {}
	for item in painted: categories[item.id] = int(categories.get(item.id, 0)) + 1
	var id := "party_names.clearance." + phase
	_check(id + ".blockers_present", categories.has("vitals") and categories.has("info")
		and categories.has("minimap") and categories.has("zone") and int(overlay.party_cards) == 3 and int(overlay.action_panels) >= 5,
		{"categories": categories, "party_cards": overlay.party_cards, "action_panels": overlay.action_panels, "touch": g.touch_mode})
	var viewport: Rect2 = g.get_viewport().get_visible_rect()
	var xf: Transform2D = g.get_viewport().canvas_transform
	var expected: Array[Dictionary] = []
	for index in 3:
		var peer: int = pair.apis[index + 1].get_unique_id()
		var remote: Player = pair._shell(0, peer)
		if remote == null or remote.dead: continue
		var head: Vector2 = xf * (remote.global_position + Vector2(0, -54))
		if g.hud.party_names_alpha <= 0.01 or head.x < viewport.position.x or head.x > viewport.end.x or head.y < viewport.position.y or head.y > viewport.end.y: continue
		var full_name: String = String(pair.wires[0].peer_chars.get(peer, {}).get("name", ""))
		expected.append({"index": index, "peer": peer, "name": full_name, "head": head,
			"identity": full_name == String(remote.get_meta("net_name", "")) and full_name == String(pair.readers[index + 1].local_player.char_name)})
	_check(id + ".expected_count", expected.size() == expected_count, {"actual": expected.size(), "expected": expected_count, "names_alpha": g.hud.party_names_alpha})
	var tags: Array[Label] = []
	for tag in g.hud.party_names:
		if tag.is_visible_in_tree() and tag.modulate.a > 0.01: tags.append(tag)
	_check(id + ".visible_tags", tags.size() == expected_count, {"actual": tags.size(), "expected": expected_count})
	var used: Array[Label] = []
	for entry in expected:
		var found: Label = null
		for tag in tags:
			if tag.text == String(entry.name) and not used.has(tag): found = tag; break
		var key := id + ".%d" % int(entry.index)
		_check(key + ".identity", found != null and bool(entry.identity), {"full_name": entry.name, "peer": entry.peer, "found": found != null})
		if found == null: continue
		used.append(found)
		var rect: Rect2 = found.get_global_rect().grow(float(found.get_theme_constant("outline_size")))
		var allowed: Rect2 = viewport
		var ancestor: Node = found.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		var collisions: Array[Dictionary] = []
		for item in painted:
			if String(item.id) != "world_name" and rect.intersects(item.rect): collisions.append(item)
		_check(key + ".native_bounds", allowed.grow(0.5).encloses(rect) and found.size.x <= 160.5
			and found.clip_text and found.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
			and found.mouse_filter == Control.MOUSE_FILTER_IGNORE and found.visible_characters == -1,
			{"full_name": found.text, "rect_with_outline": rect, "allowed": allowed, "clip_text": found.clip_text, "overrun": found.text_overrun_behavior})
		_check(key + ".hud_clear", collisions.is_empty(), {"name": found.text, "rect": rect, "collisions": collisions})
		if phase == "separated":
			# Authored control position, not rendered font-cell height: native minimum
			# can exceed the requested16px. Require unchanged unobstructed placement.
			var head: Vector2 = entry.head
			var wanted := head - Vector2(80, 8)
			_check(key + ".unobstructed_anchor", found.position.distance_to(wanted) <= 0.5,
				{"position": found.position, "wanted": wanted, "head": head, "native_size": found.size})
	if expected_count > 1:
		var pairs: Array[Dictionary] = []
		for first in used.size():
			var a: Label = used[first]
			var ar: Rect2 = a.get_global_rect().grow(float(a.get_theme_constant("outline_size")))
			for second in range(first + 1, used.size()):
				var b: Label = used[second]
				var br: Rect2 = b.get_global_rect().grow(float(b.get_theme_constant("outline_size")))
				if ar.intersects(br): pairs.append({"a": a.text, "b": b.text, "a_rect": ar, "b_rect": br})
		_check(id + ".pairwise_clear", used.size() == expected_count and pairs.is_empty(), {"compared": used.size(), "overlaps": pairs})


## Two controlled real-owner poses; transport retains exact full identities.
func _party_name_overlap_suite(pids: Array) -> void:
	var snapshots: Array[Dictionary] = []
	var fields: Array[String] = ["global_position", "velocity"]
	for reader in pair.readers:
		for actor in reader.players:
			var values := {}
			for field in fields: values[field] = actor.get(field)
			snapshots.append({"actor": actor, "values": values})
	var roster := _roster_snapshot()
	var economy: Dictionary = pair._personal(g)
	var prior_touch: bool = bool(g.settings.get("touch_controls", false))
	var prior_alpha: float = g.hud.party_names_alpha
	for phase in ["separated", "colocated"]:
		var inverse: Transform2D = g.get_viewport().canvas_transform.affine_inverse()
		var planned: Array[Vector2] = []
		for index in 3:
			var head := Vector2(420.0 + 220.0 * index if phase == "separated" else 640.0, 430.0)
			planned.append(head)
			var owner: Player = pair.readers[index + 1].local_player
			owner.global_position = inverse * head + Vector2(0, 54)
		await pair._settle(1.2)
		await RenderingServer.frame_post_draw
		var xf: Transform2D = g.get_viewport().canvas_transform
		var ok := true
		var positions: Array[Dictionary] = []
		for index in 3:
			var remote: Player = pair._shell(0, int(pids[index]))
			if remote == null: ok = false; continue
			var head: Vector2 = xf * (remote.global_position + Vector2(0, -54))
			ok = ok and head.distance_to(planned[index]) <= 2.0
			positions.append({"peer": pids[index], "actual": head, "planned": planned[index]})
		_check("party_names.overlap." + phase + ".host_projection", ok and positions.size() == 3, positions)
		_party_world_name_clear(phase, 3)
		if not r.flag("no-capture"): r.shot("names_overlay_clear" if phase == "separated" else "names_overlay_overlap", "controlled owner positions through real ENet; independent native label and fixed HUD clearance")
	# Restore owners first and allow their real network state to propagate, then
	# restore saved presentation transforms on every reader exactly.
	for index in range(1, 4):
		var owner: Player = pair.readers[index].local_player
		for snapshot in snapshots:
			if snapshot.actor == owner:
				for field in fields: owner.set(field, snapshot.values[field])
	await pair._settle(1.2)
	for snapshot in snapshots:
		if is_instance_valid(snapshot.actor):
			for field in fields: snapshot.actor.set(field, snapshot.values[field])
	var restored := true
	for snapshot in snapshots:
		if not is_instance_valid(snapshot.actor): restored = false; continue
		for field in fields: restored = restored and snapshot.actor.get(field) == snapshot.values[field]
	_check("party_names.overlap.poses_restored", restored, "exact saved position and velocity on all four reader actor sets")
	_check("party_names.overlap.settings_preserved", bool(g.settings.get("touch_controls", false)) == prior_touch and g.hud.party_names_alpha == prior_alpha,
		{"touch": g.settings.get("touch_controls", false), "names_alpha": g.hud.party_names_alpha})
	_check("party_names.overlap.roster_economy_preserved", _roster_snapshot() == roster and pair._personal(g) == economy, _roster_snapshot())
