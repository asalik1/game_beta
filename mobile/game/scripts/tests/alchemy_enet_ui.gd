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
