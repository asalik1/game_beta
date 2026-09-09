extends RefCounted
## Optional-discovery's presentation-only mode. One isolated real Game.
## Frozen actors/phase snapshots/overkill are fixtures; portal input is real.
const Trial := preload("res://scripts/pocket_trial.gd")
const VICTORY := "The guardian falls — Collect your spoils. The exit stone will wait."
var r: Node
var g: Game
var held_key := 0
var touch_down := false
var touch_at := Vector2.ZERO
var findings: Array[Dictionary] = []
var return_inputs := 0
var caption_layer: CanvasLayer


static func run(rig: Node) -> void:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe._caption()
	var error: String = await probe._run()
	probe._release()
	if probe.g.menus.is_open():
		probe.g.menus.close()
	probe.g.hud.cancel_conversation()
	probe.g.request_pause(false)
	await rig.frames(3)
	probe.g.player._poll_local_intents()
	rig._check("pocket_ui.runtime", error == "", "all fixture steps completed", error)
	rig._check("pocket_ui.actual_returns", probe.return_inputs == 3, 3, probe.return_inputs)
	rig._check("pocket_ui.inputs_released", not Input.is_key_pressed(int(probe.g.binds["interact"]))
		and not probe.touch_down and not probe.g.player.intent_interact, true, probe.g.player.intent_interact)
	rig.ui_findings = probe.findings
	if is_instance_valid(probe.caption_layer):
		probe.caption_layer.queue_free()


func _run() -> String:
	if not g.no_saves or g.net_online():
		return "requires the isolated no_saves solo Game"
	for spec in [{"id": "molten_court", "campaign": false}, {"id": "molten_court", "campaign": true},
			{"id": "still_larder", "campaign": false}]:
		var error := await _case(String(spec.id), bool(spec.campaign))
		r._write_report(false)
		if error != "":
			return error
	return ""


func _case(wanted: String, campaign_done: bool) -> String:
	await r._begin_case("pocket_ui", wanted, "ch4", campaign_done)
	var seed_value: int = r._pocket_seed(wanted, "ch4")
	if not _check("seed", seed_value >= 0, "real generated calm-source seed", seed_value):
		return "no valid pocket seed"
	g.wander_seed = seed_value
	g.switch_chapter("ch4", true)
	var origin := Trial.source_room(g)
	var arena := g.pocket_room
	r.current_case["seed"] = seed_value
	r.current_case["origin"] = origin
	r.current_case["arena"] = arena
	r.current_case["fixture"] = "posed/frozen actors; apply_state phase snapshots; real Boss overkill; actual portal input"
	if not _check("rooms", origin >= 0 and arena >= 0 and g.pocket_id == wanted,
			wanted, {"origin": origin, "arena": arena, "id": g.pocket_id}):
		return "invalid generated rooms"
	await r._position_in_room(origin)
	await r._settle()
	if not _check("source_calm", not g._room_hot(origin), false, g._room_hot(origin)):
		return "source admission is not naturally calm"
	var quest := _campaign_key()
	if not _check("campaign_copy", quest != "" and Story.quest_text(quest).contains("Brann"),
			"existing Brann campaign objective", Story.quest_text(quest)):
		return "missing real campaign-copy fixture"
	if wanted == "molten_court" and not campaign_done:
		await _ordinary_tracker(quest)
	g.quest_key = quest
	var kind: String = Pockets.entry(wanted).kind
	g.boss_done[kind] = campaign_done
	g.refresh_quest()
	var story := _story()
	if not await r._portal_button(origin, "Pocket_Enter"):
		return "existing admission fixture failed"
	if not _check("entered", g.cur_room == arena, arena, g.cur_room):
		return "admission did not enter the arena"
	var boss: Boss = r._boss_in_room(arena)
	var portal: Node2D = Trial.find(g, arena)
	if not _check("real_guardian", boss != null and boss.pocket_boss and portal != null,
			"real spawned pocket Boss and portal", boss != null):
		return "missing guardian or portal"
	boss.set_physics_process(false)
	r._freeze_trial(arena)
	await r._settle()
	if not await _readable(true):
		return "arrival UI did not settle"
	_check("entry_story", _story() == story, story, _story())
	_check("no_entry_reward", not g.pocket_done, false, g.pocket_done)
	var phases: Array[int] = [0]
	if wanted == "molten_court":
		phases.assign([0, 1, 2])
	for phase in phases:
		var changed: bool = portal.call("apply_state", phase, 0, 1.25)
		if not _check("phase_setup_%d" % phase, changed, true, changed):
			return "phase fixture rejected"
		portal.call("_refresh")
		g.refresh_quest()
		await r.frames(3)
		_card("active_phase_%d" % phase, portal, false)
		await r._capture("active_phase_%d" % phase)
	_check("phase_story", _story() == story, story, _story())
	_check("potion_rule", Trial.potions_locked(g, g.local_player) == (wanted == "still_larder"),
		wanted == "still_larder", Trial.potions_locked(g, g.local_player))
	# Move beside the real exit before death, so the first victory beat includes
	# its selected prompt. The second Molten case samples a lateral/clamped pose.
	var pose := Vector2(55, 0) if campaign_done else Vector2(0, 55)
	g.player.global_position = portal.global_position + pose
	await r.frames(8)
	if not await _readable(true):
		return "pre-death scene did not settle"
	var prompt: Label = portal.get("prompt")
	if not _check("selected_exit_before_death", prompt.is_visible_in_tree() and g.interact_in_range,
			"actual selected return prompt", {"visible": prompt.is_visible_in_tree(), "in_range": g.interact_in_range}):
		return "exit pose did not select the real portal"
	var visited_before: Dictionary = g.visited.duplicate(true)
	var doors_before: Dictionary = g.door_seen.duplicate(true)
	var reward_before := _reward()
	var renown_before := g.renown()
	# Observe reward delivery and announcement ordering without forcing presentation.
	r._observe("victory_before_damage", _victory_state(portal, arena, renown_before))
	if not _check("death_pose_actual_room", g.cur_room == arena and g.room_at_pos(g.player.global_position) == arena,
			arena, {"current": g.cur_room, "actual": g.room_at_pos(g.player.global_position)}):
		return "death pose is outside the actual pocket room"
	r.step("pocket_ui real Boss.take_damage overkill")
	boss.take_damage(boss.max_hp * 100.0, Vector2.RIGHT, false, true)
	r._observe("victory_after_damage_sync", _victory_state(portal, arena, renown_before))
	var deadline := Time.get_ticks_msec() + 8000
	while (not g.pocket_done or r._boss_in_room(arena) != null) and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	if not _check("real_death", g.pocket_done and r._boss_in_room(arena) == null,
			"deferred real Boss death completion", g.pocket_done):
		return "real death did not complete"
	portal.call("_refresh") # frozen phase fixture does not refresh its own card
	# Keep the tracker exactly as the real death path left it; no extra refresh.
	r._observe("victory_after_deferred_death", _victory_state(portal, arena, renown_before))
	if not await _victory_ready(portal, arena, renown_before):
		return "victory feed did not become readable before timeout"
	var reward_after := _reward()
	_check("one_renown_award", g.renown() == renown_before + Balance.RENOWN_POCKET,
		renown_before + Balance.RENOWN_POCKET, g.renown())
	_check("death_story", _story() == story, story, _story())
	_check("death_fog_unchanged", g.visited == visited_before and g.door_seen == doors_before,
		{"visited": visited_before, "door_seen": doors_before}, {"visited": g.visited, "door_seen": g.door_seen})
	_check("completion", g.room_pacified(arena) and g._boss_room_resolved(arena),
		true, {"pacified": g.room_pacified(arena), "resolved": g._boss_room_resolved(arena)})
	_check("seal_released", not Trial.potions_locked(g, g.local_player), false, Trial.potions_locked(g, g.local_player))
	r._observe("reward_before_after", {"before": reward_before, "after": reward_after,
		"note": "normal death dispatch; random item rolls are receipts, not byte-parity assertions"})
	_card("victory_transient", portal, true)
	var feedback := _feedback(portal)
	r._observe("first_victory_feedback", feedback)
	_probe("victory_no_redundant_plaque", not bool(feedback.victory_plaque_pending), feedback)
	_probe("victory_return_labels_clear", not bool(feedback.return_label_overlap), feedback)
	if not _check("victory_event_retained", bool(feedback.victory_in_feed), true, feedback):
		return "the victory message was lost instead of retained in the feed"
	await r._capture("victory_transient")
	# No _settle here: open and return while this actual feedback still exists.
	if not _in_feed(true):
		return "capture missed the finite victory feedback window"
	var input_error := await _actual_return(portal, origin)
	if input_error != "":
		return input_error
	_check("return_story", _story() == story, story, _story())
	_check("return_no_extra_reward", _reward() == reward_after, reward_after, _reward())
	var restored := _ordinary_copy(Story.quest_text(quest), int(g.zone_alive.get(origin, 0)))
	_check("campaign_restored", g.hud.quest_label.visible and g.hud.quest_label.text == "◆  " + g.touchify(restored),
		"◆  " + g.touchify(restored), g.hud.quest_label.text)
	await r._capture("returned_campaign")
	if not await r._portal_button(origin, "Pocket_Enter"):
		return "completed pocket reentry failed"
	r._freeze_trial(arena)
	await r._settle()
	var returned_portal: Node2D = Trial.find(g, arena)
	if returned_portal == null:
		return "missing reentry portal"
	_check("reentry_no_respawn", r._boss_in_room(arena) == null and g.pocket_done, true, g.pocket_done)
	_check("reentry_no_extra_reward", _reward() == reward_after, reward_after, _reward())
	_check("reentry_story", _story() == story, story, _story())
	g.refresh_quest()
	_card("settled_reentry", returned_portal, true)
	await r._capture("settled_reentry")
	return ""


func _ordinary_tracker(quest: String) -> void:
	var saved_key := g.quest_key
	var saved_counts: Dictionary = g.zone_alive
	g.zone_alive = saved_counts.duplicate(true)
	var saved_story := _story()
	for spec in [{"id": "ordinary_campaign", "key": quest, "left": 0},
			{"id": "ordinary_empty", "key": "", "left": 0},
			{"id": "synthetic_count_only", "key": "", "left": 1},
			{"id": "synthetic_campaign_count", "key": quest, "left": 2}]:
		g.quest_key = String(spec.key)
		g.zone_alive[g.cur_room] = int(spec.left)
		var before := _story()
		g.refresh_quest()
		var expected := _ordinary_copy(Story.quest_text(g.quest_key), int(spec.left))
		var label := g.hud.quest_label
		var wanted := "" if expected == "" else "◆  " + g.touchify(expected)
		_probe(String(spec.id), label.text == wanted and label.visible == (expected != ""),
			{"text": label.text, "visible": label.visible, "expected": wanted,
			"zone_alive_fixture": spec.left, "quest_key_fixture": spec.key})
		_check(String(spec.id) + "_no_story_write", before == _story(), before, _story())
		await r._capture(String(spec.id))
	g.quest_key = saved_key
	g.zone_alive = saved_counts
	g.refresh_quest()
	_check("ordinary_fixture_restored", saved_story == _story(), saved_story, _story())


func _campaign_key() -> String:
	for key in Story.ALL_QUESTS:
		if String(key).begins_with("ch4") and Story.quest_text(String(key)).contains("Brann"):
			return String(key)
	return ""


func _ordinary_copy(text: String, left: int) -> String:
	var result := text.strip_edges()
	if left > 0:
		if result != "":
			result += "   —   "
		result += "%d monster%s left" % [left, "" if left == 1 else "s"]
	return result


func _card(tag: String, portal: Node2D, done: bool) -> void:
	var panel: Control = portal.get("panel")
	var title: Label = panel.get_node("Title")
	var detail: Label = panel.get_node("Detail")
	var hint: Label = panel.get_node("Hint")
	var phase := int(portal.get("phase"))
	var seconds := float(portal.get("remaining"))
	var larder := g.pocket_id == "still_larder"
	var expected_title := "POCKET SPOILS" if done else "TRIAL RULE" if larder else "FLOOR HAZARD"
	var expected_detail := "Victory · Collect your spoils" if done else \
		"Bottles sealed · Class healing works" if larder else \
		"Hot stone · %.1fs" % seconds if phase == 2 else \
		"Floor heating · %.1fs" % seconds if phase == 1 else "Floor quiet · %.1fs" % seconds
	var expected_hint := "Use the exit stone when ready" if done else \
		"Exit stone offers a free retreat" if larder else \
		"Lure the guardian across hot stone" if phase == 2 else "Keep to the cold half or center seam"
	var row := {"title": title.text, "detail": detail.text, "hint": hint.text,
		"quest_text": g.hud.quest_label.text, "quest_visible": g.hud.quest_label.visible,
		"location": g.hud.zone_label.text, "boss_name": g.hud.boss_name.text,
		"phase_fixture": phase, "seconds_fixture": seconds, "pocket_done": g.pocket_done}
	r._observe(tag + "_copy", row)
	_probe(tag + "_local_instructions", g.hud.quest_label.text == "" and not g.hud.quest_label.visible, row)
	_probe(tag + "_distinct_card_heading", title.text == expected_title, row)
	_check(tag + "_rule_unchanged", detail.text == expected_detail and hint.text == expected_hint,
		{"detail": expected_detail, "hint": expected_hint}, row)
	_check(tag + "_card_visible", panel.is_visible_in_tree() and title.is_visible_in_tree()
		and detail.is_visible_in_tree() and hint.is_visible_in_tree(), true, row)
	var name: String = Pockets.entry(g.pocket_id).name
	_check(tag + "_location_retained", g.hud.zone_label.text.to_lower().contains(name.to_lower()), name, row.location)
	if not done:
		_check(tag + "_boss_name_retained", g.hud.boss_base_name == name and g.hud.boss_name.text.begins_with(name),
			name + " with existing HP suffix", g.hud.boss_name.text)


func _actual_return(portal: Node2D, origin: int) -> String:
	var deadline := Time.get_ticks_msec() + 1800
	while g.talk_cd > 0.0 and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	if g.talk_cd > 0.0:
		return "portal input cooldown never cleared"
	var feedback_before := _feedback(portal)
	if not _check("feedback_live_before_input", _in_feed(true), true, feedback_before):
		return "victory feed expired before actual input"
	if g.touch_mode:
		if g._touch_hud == null:
			return "touch HUD did not mount"
		var panel: Panel = g._touch_hud._btns["interact"]["panel"]
		if not panel.is_visible_in_tree():
			return "real touch Act target is hidden"
		touch_at = panel.get_global_rect().get_center()
		_touch(true)
		await r.frames(2)
		_touch(false) # Act is a tap pulse on release; holding opens its explanation.
	else:
		held_key = int(g.binds["interact"])
		_key(true)
	deadline = Time.get_ticks_msec() + 2000
	while not g.menus.is_open() and Time.get_ticks_msec() < deadline:
		await r.frames(1)
	_release()
	if not _check("actual_portal_open", g.menus.is_open() and g.menus.current == "pocket_trial",
			"actual Act/E opens existing pocket menu", g.menus.current):
		return "ordinary interact input did not open the portal"
	var button: Button = g.menus.root.find_child("Pocket_Return", true, false) as Button
	if not _check("actual_return_target", button != null and not button.disabled
			and button.is_visible_in_tree() and button.size.y >= 44.0, "visible return target", button != null):
		return "missing real return action"
	r._observe("return_input", {"open_input": "ScreenTouch Act" if g.touch_mode else "bound keyboard E",
		"return_input": "ScreenTouch" if g.touch_mode else "mouse",
		"feedback_before_open": feedback_before, "button_rect": _rect(button.get_global_rect())})
	await r._capture("actual_return_menu")
	await r._click(button)
	if not _check("actual_return_destination", g.cur_room == origin, origin, g.cur_room):
		return "actual return button input did not leave the arena"
	return_inputs += 1
	return ""


func _readable(drain_announcements: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	var stable := 0
	while Time.get_ticks_msec() < deadline:
		await r.frames(1)
		var busy: bool = g.input_overlay_up() or g.cutscene != null or g.hud._cinematic_mode \
			or g.hud.overlay.color.a > 0.001 or g.hud.title_label.modulate.a > 0.01 \
			or g.hud.subtitle_label.modulate.a > 0.01
		for child in g.hud.get_children():
			busy = busy or child is Cutscene
		if drain_announcements:
			busy = busy or is_instance_valid(g.hud._ann_active) or not g.hud._ann_queue.is_empty()
		stable = 0 if busy else stable + 1
		if stable >= 3:
			return true
	return false


func _victory_ready(portal: Node2D, arena: int, renown_before: int) -> bool:
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + 8000
	var next_sample: int = started
	while Time.get_ticks_msec() < deadline:
		await r.frames(1)
		if Time.get_ticks_msec() >= next_sample:
			var sample: Dictionary = _victory_state(portal, arena, renown_before)
			sample["wait_msec"] = Time.get_ticks_msec() - started
			r._observe("victory_wait_sample", sample)
			next_sample = Time.get_ticks_msec() + 1000
		if Time.get_ticks_msec() >= deadline:
			break
		# The immediate event feed and the serialized plaque queue have distinct
		# lifetimes. Return input must occur during the real visible feed window.
		# Pending/active guardian plaques remain separate presentation receipts.
		if _in_feed(true):
			r._observe("victory_wait_ready", _victory_state(portal, arena, renown_before))
			return true
	r._observe("victory_wait_timeout", _victory_state(portal, arena, renown_before))
	return false


func _victory_state(portal: Node2D, arena: int, renown_before: int) -> Dictionary:
	var receipt: Dictionary = _feedback(portal)
	var lines: Array[Dictionary] = []
	for row: Control in g.hud._log_lines:
		if not is_instance_valid(row):
			continue
		var label: Label = row.get_meta("label", null) as Label
		var motion: Tween = row.get_meta("tween", null) as Tween
		lines.append({"text": label.text if is_instance_valid(label) else "<no label>",
			"visible": row.visible, "visible_in_tree": row.is_visible_in_tree(), "alpha": row.modulate.a,
			"label_visible": label.is_visible_in_tree() if is_instance_valid(label) else false,
			"label_alpha": label.modulate.a if is_instance_valid(label) else -1.0,
			"tween_valid": motion != null and motion.is_valid(),
			"tween_running": motion != null and motion.is_valid() and motion.is_running()})
	var active: Panel = g.hud._ann_active
	var cast: Control = g.hud.boss_cast_readout
	receipt["ticks_msec"] = Time.get_ticks_msec()
	receipt["feed_lines"] = lines
	receipt["announcement_queue"] = g.hud._ann_queue.duplicate(true)
	receipt["announcement_visible"] = active.is_visible_in_tree() if is_instance_valid(active) else false
	receipt["announcement_alpha"] = active.modulate.a if is_instance_valid(active) else -1.0
	receipt["announcement_tween_running"] = g.hud._ann_tween != null and g.hud._ann_tween.is_valid() and g.hud._ann_tween.is_running()
	receipt["boss_cast_visible"] = cast.visible if is_instance_valid(cast) else false
	receipt["boss_cast_in_tree"] = cast.is_visible_in_tree() if is_instance_valid(cast) else false
	receipt["game_state"] = g.state
	receipt["play_started"] = g.play_started
	receipt["paused"] = r.get_tree().paused
	receipt["time_scale"] = Engine.time_scale
	receipt["input_overlay_up"] = g.input_overlay_up()
	receipt["hud_visible"] = g.hud.visible
	receipt["cinematic_mode"] = g.hud._cinematic_mode
	receipt["overlay_alpha"] = g.hud.overlay.color.a
	receipt["title_alpha"] = g.hud.title_label.modulate.a
	receipt["subtitle_alpha"] = g.hud.subtitle_label.modulate.a
	receipt["expected_arena"] = arena
	receipt["current_room"] = g.cur_room
	receipt["actual_player_room"] = g.room_at_pos(g.player.global_position)
	receipt["arena_rect"] = _rect(g.room_rect(arena))
	receipt["arena_play_rect"] = _rect(g.play_rect(arena))
	receipt["pocket_done"] = g.pocket_done
	receipt["renown_before"] = renown_before
	receipt["renown_now"] = g.renown()
	receipt["renown_delta"] = g.renown() - renown_before
	return receipt


func _victory_pending() -> bool:
	if is_instance_valid(g.hud._ann_active) and String(g.hud._ann_active.get_meta("message", "")) == VICTORY:
		return true
	for entry in g.hud._ann_queue:
		if String(entry.text) == VICTORY:
			return true
	return false


func _in_feed(require_visible := false) -> bool:
	for row: Control in g.hud._log_lines:
		if is_instance_valid(row) and row.has_meta("label"):
			var label: Label = row.get_meta("label")
			if is_instance_valid(label) and label.text == VICTORY:
				return not require_visible or (row.is_visible_in_tree() and row.modulate.a >= 0.95
					and label.is_visible_in_tree() and label.modulate.a >= 0.95)
	return false


func _feedback(portal: Node2D) -> Dictionary:
	var prompt: Label = portal.get("prompt")
	var caption: Label = portal.get("caption")
	var prompt_rect: Rect2 = prompt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, prompt.size)
	var caption_rect: Rect2 = caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caption.size)
	var active := g.hud._ann_active
	var plaque_rect := Rect2()
	var overlap := false
	var active_message := ""
	if is_instance_valid(active):
		active_message = String(active.get_meta("message", ""))
		plaque_rect = active.get_global_rect()
		if active_message == VICTORY and active.visible:
			overlap = (prompt.is_visible_in_tree() and plaque_rect.intersects(prompt_rect)) \
				or (caption.is_visible_in_tree() and plaque_rect.intersects(caption_rect))
	var guardian_queued := false
	for entry in g.hud._ann_queue:
		guardian_queued = guardian_queued or String(entry.text) == VICTORY
	var guardian_active := is_instance_valid(active) and active_message == VICTORY
	var guardian_visible := guardian_active and active.is_visible_in_tree() and active.modulate.a >= 0.95
	return {"victory_plaque_pending": _victory_pending(), "active_message": active_message,
		"guardian_queued": guardian_queued, "guardian_active": guardian_active,
		"guardian_visible": guardian_visible,
		"overlap_scope": "active guardian plaque only; queued guardian is not displayed; unrelated Renown plaques excluded",
		"victory_in_feed": _in_feed(), "feed_visible": _in_feed(true), "return_label_overlap": overlap,
		"plaque_rect": _rect(plaque_rect), "prompt_rect": _rect(prompt_rect), "caption_rect": _rect(caption_rect),
		"prompt_visible": prompt.is_visible_in_tree(), "caption_visible": caption.is_visible_in_tree(),
		"hero_world": [g.player.global_position.x, g.player.global_position.y],
		"camera_screen_center": [g.camera.get_screen_center_position().x, g.camera.get_screen_center_position().y],
		"portal_screen": [portal.get_global_transform_with_canvas().origin.x, portal.get_global_transform_with_canvas().origin.y]}


func _story() -> Dictionary:
	return {"quest": g.quest_key, "flags": g.flags.duplicate(true), "campaign": g.boss_done.duplicate(true),
		"quest_kills": g.quest_kills.duplicate(true), "edge_locks": g.edge_locks.duplicate(true)}


func _reward() -> Dictionary:
	return {"renown": g.renown(), "gold": g.local_player.gold, "xp": g.local_player.xp,
		"backpack": g.local_player.backpack.duplicate(true), "gems": g.local_player.gem_bag.duplicate(true),
		"consumables": g.local_player.consumables.duplicate(true), "hp": g.local_player.hp, "mp": g.local_player.mp}


func _key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = held_key
	event.physical_keycode = held_key
	event.pressed = down
	Input.parse_input_event(event)


func _touch(down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 73
	event.position = touch_at
	event.pressed = down
	touch_down = down
	Input.parse_input_event(event)


func _release() -> void:
	if held_key != 0:
		_key(false)
		held_key = 0
	if touch_down:
		_touch(false)


func _caption() -> void:
	caption_layer = CanvasLayer.new()
	caption_layer.layer = 110
	r.add_child(caption_layer)
	var label := Label.new()
	label.text = "QA: posed/frozen actors + phase snapshots + overkill; actual Act/E and return input; not ordinary combat"
	label.position = Vector2(0, 700)
	label.size = Vector2(1280, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	caption_layer.add_child(label)


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _check(id: String, passed: bool, expected: Variant, actual: Variant) -> bool:
	return bool(r._check(r._id(id), passed, expected, actual))


func _probe(id: String, passed: bool, actual: Variant) -> void:
	var row := {"id": r._id(id), "passed": passed, "actual": actual}
	findings.append(row)
	r.ui_findings = findings
	r._observe("presentation_" + id, row)
	if not r.flag("baseline"):
		r._check(r._id(id), passed, "clear local presentation", actual)
	else:
		print("POCKET UI BASELINE: %s %s" % ["PASS" if passed else "FINDING", String(row.id)])
