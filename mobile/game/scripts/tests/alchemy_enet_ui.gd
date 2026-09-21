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
