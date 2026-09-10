extends Node
## Optional selector controls. The hunt sign/action is real; the second entry
## is a labeled, harmless recorder, not an NPC or completed encounter.
const CASES := [
	{"id": "eligible_default", "distance": 40.0, "has_reach": false, "reach": 80.0, "winner": "competitor"},
	{"id": "outside_tight", "distance": 60.0, "has_reach": true, "reach": 50.0, "winner": "sign"},
	{"id": "disabled_near", "distance": 1.0, "has_reach": true, "reach": 0.0, "winner": "sign"},
]
const PLAYER_LEDGER := ["gold", "xp", "level", "skill_points", "tree_points", "attr_points", "unspent_attr",
	"equipment", "backpack", "gem_bag", "bags", "loose_bags", "materials", "consumables",
	"profession", "mastery", "blueprints", "resonance", "faction_standing", "npc_favor"]
const GAME_LEDGER := ["flags", "quest_kills", "quest_key", "mailbox", "achievements", "boss_records",
	"kill_counts", "convo_log", "convo_log_order"]
const SCOPE := "posed frozen hero; actual first hunt sign and held E selector; second entry is a harmless QA recorder; no NPC conversation, quarry or reward"

var r: Variant
var g: Game
var trail: Variant
var sign_action: Callable
var competitor: Node2D
var prompt: Label
var sign_calls := 0
var competitor_calls := 0
var pending_query := false
var query_at := Vector2.ZERO
var query_result := {}


static func run(rig: Variant, actual_trail: Variant) -> String:
	var test := new()
	test.r = rig
	test.g = rig.game
	test.trail = actual_trail
	test.process_mode = Node.PROCESS_MODE_ALWAYS
	test.process_physics_priority = 1001
	rig.add_child(test)
	var entries: Array = test.g.interactables.duplicate()
	var previous_action: Callable = actual_trail.entries[0].action
	var previous_talk_cd: float = test.g.talk_cd
	var previous_position: Vector2 = test.g.player.global_position
	var previous_velocity: Vector2 = test.g.player.velocity
	var previous_sign: int = actual_trail.sign_index
	var previous_phase: int = actual_trail.phase
	var previous_reach: float = actual_trail.entries[0].reach
	var touch_enabled: bool = test.g.settings.get("touch_controls", false)
	var pad_active: bool = test.g.gamepad.active
	test.sign_action = previous_action
	actual_trail.entries[0].action = test._record_sign
	var ledger := test._ledger()
	var error: String = await test._run()
	rig._release()
	test.g.interactables = entries
	actual_trail.entries[0].action = previous_action
	actual_trail.sign_index = previous_sign
	actual_trail.phase = previous_phase
	actual_trail._refresh()
	actual_trail.entries[0].reach = previous_reach
	test.g.player.global_position = previous_position
	test.g.player.velocity = previous_velocity
	test.g.talk_cd = previous_talk_cd
	test.g.settings["touch_controls"] = touch_enabled
	test.g.refresh_touch_mode()
	test.g._apply_touch_mode()
	test.g.gamepad._set_active(pad_active)
	test.r._check(test._ledger() == ledger, "competition restores without rewards, quest changes or NPC conversation")
	if is_instance_valid(test.competitor):
		test.competitor.queue_free()
	test.queue_free()
	return error


func _physics_process(_delta: float) -> void:
	if not pending_query:
		return
	# Reuse the rig's actual player-shape query, only inside a physics callback.
	query_result = {"hits": r._overlaps(query_at), "physics_frame": Engine.get_physics_frames()}
	pending_query = false


func _body_query(point: Vector2) -> Dictionary:
	query_result = {}
	query_at = point
	pending_query = true
	var deadline := Time.get_ticks_msec() + 2000
	while pending_query and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	return query_result


func _run() -> String:
	r.step("optional competition: real long-reach sign versus harmless selector entries")
	r.report["competition"] = []
	r.report["competition_scope"] = SCOPE
	if not _setup(g.no_saves and g.is_processing() and not g.player.is_physics_processing()
		and not g.input_overlay_up() and not g.get_tree().paused and g.pending_tutorial == ""
		and g.state == Game.ST_PLAYING and g.player.is_locally_controlled()
		and trail.valid_world() and trail.phase == 0 and not is_instance_valid(trail.quarry),
		"competition enters the existing isolated, live-selector / frozen-body fixture"):
		return "competition preconditions unavailable"
	g.settings["touch_controls"] = false
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.gamepad.cancel_held()
	g.gamepad._set_active(false)
	competitor = Node2D.new()
	competitor.name = "QAHarmlessSelectorCompetitor"
	competitor.set_meta("qa_only", "harmless recorder; no NPC or reward action")
	g.world.add_child(competitor)
	prompt = Label.new()
	prompt.text = "QA ONLY — harmless competitor"
	prompt.position = Vector2(-170, -62)
	prompt.size = Vector2(340, 28)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.z_index = 100
	UITheme.world(prompt, 15, 4)
	competitor.add_child(prompt)
	for spec in CASES:
		for sign_first in [true, false]:
			var error := await _case(spec, sign_first)
			if error != "":
				return error
	return ""


func _case(spec: Dictionary, sign_first: bool) -> String:
	r._release()
	sign_calls = 0
	competitor_calls = 0
	trail.sign_index = 0
	# Production _refresh restores the first tracking sign's ordinary160px
	# reach even though the preceding matrix deliberately ended at reach0.
	trail._refresh()
	var sign_entry: Dictionary = trail.entries[0]
	var sign_point: Vector2 = trail.points[0]
	var chosen := Vector2(INF, INF)
	var sampled := {}
	for direction in r.DIRECTIONS:
		var point: Vector2 = sign_point + direction * 120.0
		if g.room_at_pos(point) != trail.zone:
			continue
		var body: Dictionary = await _body_query(point)
		if body.is_empty():
			return "competition physics body query timed out"
		if body.hits.is_empty():
			chosen = point
			sampled = body
			break
	if not _setup(chosen.is_finite(), "competition has a physics-observed clear posed 120px start"):
		return "competition has no clear exact-distance fixture position"
	g.player.global_position = chosen
	g.player.velocity = Vector2.ZERO
	# Deliberately closer along the same ray; unlike the sign this node has no
	# collider, sprite, dialogue, reward or story callback.
	competitor.global_position = chosen + chosen.direction_to(sign_point) * float(spec.distance)
	var entry := {"node": competitor, "prompt": prompt, "action": _record_competitor}
	if bool(spec.has_reach):
		entry.reach = float(spec.reach)
	g.interactables = [sign_entry, entry] if sign_first else [entry, sign_entry]
	g.talk_cd = 0.0
	# This framing helper belongs to the preceding route supplement. It does
	# not select an entry or change the position/range/action of either one.
	var framing: Dictionary = await r._pose_interaction_camera(sign_point)
	var label := "competition %s/%s" % [spec.id, "sign_first" if sign_first else "competitor_first"]
	var ready: bool = not g.input_overlay_up() and not g.get_tree().paused and g.is_processing() \
		and g.state == Game.ST_PLAYING and g.player.is_locally_controlled() \
		and not g.player.is_physics_processing() and not Input.is_key_pressed(int(g.binds.interact)) \
		and not g.player.dead and not g.player.downed and not g.player.ghost \
		and is_zero_approx(g.talk_cd) and trail.sign_index == 0 and trail.phase == 0 \
		and absf(g.player.global_position.distance_to(sign_point) - 120.0) < 0.1 \
		and absf(g.player.global_position.distance_to(competitor.global_position) - float(spec.distance)) < 0.1 \
		and float(sign_entry.reach) == 160.0 and sign_calls == 0 and competitor_calls == 0 \
		and float(framing.screen_drift) < 0.25
	if not _setup(ready, label + " exact distances, own ranges, clear overlay and released input"):
		return label + " did not retain setup"
	if not _setup(g.interactables == ([sign_entry, entry] if sign_first else [entry, sign_entry]),
		label + " contains exactly the two requested entries in the declared order"):
		return label + " registry changed during setup"
	var winner := String(spec.winner)
	var prompt_sign: bool = trail.prompts[0].is_visible_in_tree()
	var prompt_competitor := prompt.is_visible_in_tree()
	var prompt_ok := (prompt_sign and not prompt_competitor) if winner == "sign" else (prompt_competitor and not prompt_sign)
	var missing_long := winner == "sign" and not prompt_sign and not prompt_competitor and not g.interact_in_range
	r._check(prompt_ok and g.interact_in_range, label + " nearest eligible prompt wins independently of order", missing_long)
	var ledger := _ledger()
	if sign_first and not r.flag("no-capture"):
		await r._capture("competition_" + String(spec.id), SCOPE + "; before actual E input")
	var screen: Vector2 = r.get_viewport().get_canvas_transform() * sign_point
	var settled := Vector2(float(framing.settled_screen[0]), float(framing.settled_screen[1]))
	if not _setup(not g.input_overlay_up() and not g.get_tree().paused
		and screen.distance_to(settled) < 0.25 and r.get_viewport().get_visible_rect().has_point(screen),
		label + " capture retains settled visible framing and clear input gate"):
		return label + " capture invalidated setup"
	var began_ms := Time.get_ticks_msec()
	var began_frame := Engine.get_process_frames()
	r._key(int(g.binds.interact), true)
	var saw_held := Input.is_key_pressed(int(g.binds.interact))
	var saw_intent := false
	# This is the polled held-key route, not action/signal invocation. Stop at
	# the first observed action so an engine stall cannot turn a short read into
	# a legitimate repeat after the normal 0.6s talk debounce.
	while sign_calls + competitor_calls == 0 and Time.get_ticks_msec() - began_ms < 400:
		await r.frames(1)
		saw_held = saw_held and Input.is_key_pressed(int(g.binds.interact))
		saw_intent = saw_intent or g.player.intent_interact
	r._key(int(g.binds.interact), false)
	var ended_ms := Time.get_ticks_msec()
	var ended_frame := Engine.get_process_frames()
	await r.frames(2)
	var no_action: bool = sign_calls == 0 and competitor_calls == 0 and trail.sign_index == 0
	var known: bool = winner == "sign" and missing_long and no_action
	var sign_expected := 1 if winner == "sign" else 0
	var competitor_expected := 1 if winner == "competitor" else 0
	r._check(sign_calls == sign_expected and competitor_calls == competitor_expected,
		label + " exact action ledger chooses only expected winner", known)
	r._check(int(trail.sign_index) == sign_expected, label + " exact production sign advance", known)
	r._check(sign_calls <= 1 and competitor_calls <= 1 and sign_calls + competitor_calls <= 1,
		label + " one poll never fires both entries or repeats")
	r._check(competitor_calls == 0 if winner == "sign" else competitor_calls == 1,
		label + " competitor activation obeys its own eligibility")
	r._check(saw_held and saw_intent and not Input.is_key_pressed(int(g.binds.interact)) and not g.player.intent_interact
		and not g.input_overlay_up() and not g.get_tree().paused
		and g.player.global_position.distance_to(chosen) < 0.1 and trail.phase == 0
		and not is_instance_valid(trail.quarry), label + " key-up, overlay, frozen position and noncombat gates retained")
	r._check(_ledger() == ledger, label + " no reward, quest or NPC conversation side effects")
	r.report.competition.append({"id": spec.id, "sign_first": sign_first, "winner": winner,
		"sign_distance": g.player.global_position.distance_to(sign_point), "sign_reach": 160.0,
		"competitor_distance": float(spec.distance), "competitor_explicit_reach": bool(spec.has_reach),
		"competitor_effective_reach": float(entry.get("reach", Balance.INTERACT_RANGE)),
		"prompt_sign": prompt_sign, "prompt_competitor": prompt_competitor,
		"sign_action_calls": sign_calls, "competitor_action_calls": competitor_calls,
		"sign_after": trail.sign_index, "position": r._v(chosen), "body_query": sampled,
		"camera_fixture": framing, "pre_input_screen": r._v(screen),
		"held_seen": saw_held, "polled_intent_seen": saw_intent, "held_process_frames": ended_frame - began_frame,
		"held_wall_ms": ended_ms - began_ms, "baseline_missing_long_selection": known})
	return ""


func _record_sign() -> void:
	sign_calls += 1
	sign_action.call()


func _record_competitor() -> void:
	competitor_calls += 1


func _setup(ok: bool, label: String) -> bool:
	r._check(ok, label)
	return ok


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


func _ledger() -> Dictionary:
	var result := {"player": {}, "game": {}}
	for field in PLAYER_LEDGER:
		result.player[field] = _copy(g.player.get(field))
	for field in GAME_LEDGER:
		result.game[field] = _copy(g.get(field))
	result.loot_rng = g.loot_rng.state
	result.meta_bytes = FileAccess.get_file_as_bytes("user://meta.json") if FileAccess.file_exists("user://meta.json") else null
	result.dialogue = g.hud.dialogue_active
	result.choices = g.hud.choices_active
	return result
