extends ShotRig
## Optional-guardian discovery/completion baseline and regression rig.
## shot.bat optional_discovery --timeout=420 [--baseline] [--touch]
## Uses real generated rooms, portal buttons and Boss.take_damage/death.
## Overkill and QA positioning prove state/UI contracts, NOT normal combat.
## No save-slot writes: ShotRig's no_saves remains enabled throughout.
## Behavioral failures accumulate; observations.json is updated per case.

const Trial := preload("res://scripts/pocket_trial.gd")
const SEED_LIMIT := 240
const SETTLE_SECONDS := 4.2

var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var current_case: Dictionary = {}
var failure_count := 0


func _ready() -> void:
	await boot("warrior", "ch4", false)
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.settings["combat_framing"] = false
	game.settings["touch_controls"] = flag("touch")
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.camera.position_smoothing_enabled = false
	game.player.set_physics_process(false)
	zoom(1.0)
	for campaign_done in [false, true]:
		await _pocket_case(bool(campaign_done))
		_write_report(false)
	for campaign_done in [false, true]:
		await _unlisted_case(bool(campaign_done))
		_write_report(false)
	_check("rig.no_saves", game.no_saves, true, game.no_saves)
	_write_report(true)
	print("OPTIONAL DISCOVERY: cases=%d checks=%d failed=%d; overkill state/UI probe, not normal combat" % [cases.size(), checks.size(), failure_count])
	finish(1 if failure_count > 0 else 0)


func _begin_case(family: String, id: String, chapter: String, campaign_done: bool) -> void:
	current_case = {"id": "%s_%s_campaign_%s" % [family, id, "done" if campaign_done else "open"],
		"family": family, "encounter": id, "chapter": chapter,
		"campaign_done_fixture": campaign_done, "captures": [], "observations": []}
	cases.append(current_case)
	step(String(current_case.id))
	if game.menus.is_open():
		game.menus.close()
	await skip_dialogue()
	game.request_pause(false)
	game.state = Game.ST_PLAYING
	game._wipe_chapter_flags()
	game.reset_run_stats()
	game.weekly_active = false
	game.player.tracked_quest = ""
	game.player.set_physics_process(false)
	await frames(3)


func _pocket_case(campaign_done: bool) -> void:
	var wanted := "molten_court"
	var entry: Dictionary = Pockets.entry(wanted)
	var kind := String(entry.kind)
	var expected_name := String(entry.name)
	await _begin_case("pocket", wanted, "ch4", campaign_done)
	if not _check(_id("seed_chapter"), game.chapter_id == "ch4", "ch4 social-roll context", game.chapter_id):
		return
	var seed_value := _pocket_seed(wanted, "ch4")
	if not _check(_id("seed"), seed_value >= 0, "a real generated pocket seed", seed_value):
		return
	current_case["seed"] = seed_value
	game.wander_seed = seed_value
	game.switch_chapter("ch4", true)
	var origin := Trial.source_room(game)
	var arena := game.pocket_room
	current_case["arena"] = arena
	current_case["origin"] = origin
	if not _check(_id("generated_rooms"), origin >= 0 and arena >= 0, "source and arena", [origin, arena]):
		return
	await _position_in_room(origin)
	# Portal admission legitimately rejects a hot source. The seed sweep picks
	# a naturally calm social room; never kill its residents to force entry.
	if not _check(_id("source_calm"), not game._room_hot(origin), "naturally calm portal source", game._room_hot(origin)):
		return
	await _journal_unknown()
	# Apply the campaign mark only after the unknown-room capture, so that
	# its synthetic completion cannot itself justify revealing that name.
	game.boss_done[kind] = campaign_done
	# Pure visibility fixture: a known campaign guardian and the pocket reuse
	# Cinderhide. Neither completion value is changed by revealing that row.
	var campaign_room := _campaign_room(kind)
	current_case["campaign_collision_room"] = campaign_room
	if _check(_id("collision_fixture"), campaign_room >= 0, "campaign Cinderhide room", campaign_room):
		game.visited[campaign_room] = true
	if not await _portal_button(origin, "Pocket_Enter"):
		return
	if not _check(_id("entry"), game.cur_room == arena, arena, game.cur_room):
		return
	var boss := _boss_in_room(arena)
	if not _check(_id("spawn"), boss != null, "named guardian despite either campaign mark", boss != null):
		return
	_check(_id("spawn_name"), boss.display_name == expected_name, expected_name, boss.display_name)
	boss.set_physics_process(false)
	_freeze_trial(arena)
	await _settle()
	await _inspect_state("active", arena, expected_name, kind, false, campaign_done, true)
	await _kill_guardian(boss, arena)
	await _inspect_state("defeated", arena, expected_name, kind, true, campaign_done, true)
	if not await _portal_button(arena, "Pocket_Return"):
		return
	_check(_id("return_room"), game.cur_room == origin, origin, game.cur_room)
	if not flag("baseline"):
		await _returned_pocket_map(arena)
	if not await _portal_button(origin, "Pocket_Enter"):
		return
	_freeze_trial(arena)
	await _settle()
	await _inspect_reentry(arena, expected_name, kind, campaign_done)


func _unlisted_case(campaign_done: bool) -> void:
	var wanted := "greymantle"
	var entry: Dictionary = Unlisted.entry(wanted)
	var kind := String(entry.kind)
	var expected_name := String(entry.name)
	await _begin_case("unlisted", wanted, "ch3", campaign_done)
	var seed_value := _unlisted_seed(wanted, "ch3")
	if not _check(_id("seed"), seed_value >= 0, "a real generated Unlisted seed", seed_value):
		return
	current_case["seed"] = seed_value
	game.wander_seed = seed_value
	game.switch_chapter("ch3", true)
	var arena := -1
	for zi in game.zones.size():
		if String(game.zones[zi].get("unlisted", "")) == wanted:
			arena = zi
			break
	current_case["arena"] = arena
	if not _check(_id("generated_room"), arena >= 0, "actual seeded Greymantle room", arena):
		return
	await _settle()
	await _journal_unknown()
	game.boss_done[kind] = campaign_done
	await _position_in_room(arena)
	var boss := _boss_in_room(arena)
	if not _check(_id("spawn"), boss != null, "named guardian despite either campaign mark", boss != null):
		return
	_check(_id("spawn_name"), boss.display_name == expected_name, expected_name, boss.display_name)
	boss.set_physics_process(false)
	await _settle()
	await _inspect_state("active", arena, expected_name, kind, false, campaign_done, false)
	await _kill_guardian(boss, arena)
	# The adjacent observed doorway is a legal route destination. The actual
	# HUD drawing remains in charge; this rig only selects the existing pin.
	var neighbor := _first_neighbor(arena)
	if neighbor >= 0:
		_check(_id("postkill_route_selected"), game.hud.wayfinder.pin(neighbor), true, neighbor)
	await _inspect_state("defeated", arena, expected_name, kind, true, campaign_done, false)
	# Use the existing room-entry lifecycle twice, with QA positioning. This
	# is a reentry/state check, not a claim that we walked the connecting path.
	await _position_in_room(0)
	await _position_in_room(arena)
	await _settle()
	await _inspect_reentry(arena, expected_name, kind, campaign_done)


func _pocket_seed(wanted: String, chapter: String) -> int:
	# The existing social predictor reads the current chapter. Both pocket
	# cases run in ch4; reject a mismatched context instead of copying its RNG.
	if game.chapter_id != chapter:
		return -1
	var source := Trial.source_room(game)
	if source < 0:
		return -1
	for candidate in SEED_LIMIT:
		game.wander_seed = candidate
		game._pocket_inject(Story.chapter(chapter)["zones"], chapter)
		if game.pocket_id == wanted and not game.social_holds_elite(source):
			return candidate
	return -1


func _unlisted_seed(wanted: String, chapter: String) -> int:
	for candidate in SEED_LIMIT:
		game.wander_seed = candidate
		var generated: Array = game._unlisted_inject(Story.chapter(chapter)["zones"], chapter)
		for zone in generated:
			if String(zone.get("unlisted", "")) == wanted:
				return candidate
	return -1


func _campaign_room(kind: String) -> int:
	for zi in game.zones.size():
		var zone: Dictionary = game.zones[zi]
		if String(zone.get("boss", "")) == kind and String(zone.get("pocket", "")) == "" \
				and String(zone.get("unlisted", "")) == "" and String(zone.get("waking", "")) == "":
			return zi
	return -1


func _first_neighbor(room: int) -> int:
	for direction in game.rooms[room]["exits"]:
		var neighbor := game.neighbor(room, String(direction))
		if neighbor >= 0:
			return neighbor
	return -1


func _boss_in_room(room: int) -> Boss:
	for boss: Boss in game._live_bosses():
		if boss.zone_idx == room:
			return boss
	return null


func _position_in_room(room: int) -> void:
	if game.menus.is_open():
		game.menus.close()
	game.request_pause(false)
	game.player.global_position = game.room_center(room)
	game._enter_room(room)
	game.terrain_event_t = 10000.0
	await skip_dialogue()
	game.player.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.game == game:
			enemy.set_physics_process(false)
	await frames(5)


func _freeze_trial(room: int) -> void:
	var trial := Trial.find(game, room)
	if trial != null:
		trial.set_physics_process(false)
		current_case["trial_clock_fixture"] = "frozen for deterministic state/UI captures; display refreshed explicitly"
		trial.call("_refresh")
	game.terrain_event_t = 10000.0


func _portal_button(room: int, button_name: String) -> bool:
	if game.menus.is_open():
		game.menus.close()
	await frames(3)
	var portal := Trial.find(game, room)
	if not _check(_id(button_name + "_portal"), portal != null, "existing painted portal", portal != null):
		return false
	game.player.global_position = portal.global_position + Vector2(0, 55)
	portal.interact()
	await frames(3)
	var button: Button = game.menus.root.find_child(button_name, true, false) as Button if game.menus.root != null else null
	if not _check(_id(button_name + "_button"), button != null, "actual portal action", button != null):
		return false
	button.pressed.emit()
	await frames(8)
	game.terrain_event_t = 10000.0
	game.player.set_physics_process(false)
	return true


func _kill_guardian(boss: Boss, room: int) -> void:
	step(_id("synthetic_overkill_death"))
	# Damage passes through armor and the normal death/award dispatch. Never
	# call the bank/completion writer or assign the named completion fixture.
	boss.take_damage(boss.max_hp * 100.0, Vector2.RIGHT, false, true)
	await sim_wait(3.5)
	_check(_id("real_death"), _boss_in_room(room) == null, "no living named guardian", _boss_in_room(room) != null)
	# Freezing the floor also stops its normal display refresh. Repaint from
	# the actual completion state so the fixture cannot manufacture a stale
	# Floor quiet panel after victory; this does not advance its clock or bank.
	var trial := Trial.find(game, room)
	if trial != null and not trial.is_physics_processing():
		trial.call("_refresh")
	await _settle()


func _settle() -> void:
	if game.menus.is_open():
		game.menus.close()
	await skip_dialogue()
	game.request_pause(false)
	game.terrain_event_t = 10000.0
	await sim_wait(SETTLE_SECONDS)
	var deadline := Time.get_ticks_msec() + 8000
	while (is_instance_valid(game.hud._ann_active) or not game.hud._ann_queue.is_empty()) and Time.get_ticks_msec() < deadline:
		await sim_wait(0.1)
	await frames(3)


func _state(room: int) -> Dictionary:
	return {"room": game.cur_room, "charted": game.charted(room),
		"resolved": game._boss_room_resolved(room), "pacified": game.room_pacified(room),
		"boss_pending": game.hud.wayfinder._boss_pending,
		"hud_status": game.hud.wayfinder.status_label.text,
		"hud_detail": game.hud.wayfinder.detail_label.text,
		"hot": game.hud.wayfinder._hot,
		"pinned_path": game.hud.wayfinder.pinned_path.duplicate(),
		"live_guardian": _boss_in_room(room) != null,
		"pocket_done": game.pocket_done, "unlisted_banked": game.unlisted_banked.duplicate(),
		"campaign_boss_done": game.boss_done.duplicate()}


func _inspect_state(phase: String, room: int, expected_name: String, kind: String,
		resolved: bool, campaign_done: bool, collision: bool) -> void:
	await sim_wait(Balance.WAYFINDER_SAMPLE_SECONDS * 2.0)
	var actual := _state(room)
	_observe(phase + "_state", actual)
	_check(_id(phase + ".resolved"), bool(actual.resolved) == resolved, resolved, actual.resolved)
	_check(_id(phase + ".pacified"), bool(actual.pacified) == resolved, resolved, actual.pacified)
	_check(_id(phase + ".pending"), bool(actual.boss_pending) == (not resolved), not resolved, actual.boss_pending)
	_check(_id(phase + ".campaign_unchanged"), bool(game.boss_done.get(kind, false)) == campaign_done, campaign_done, game.boss_done.get(kind, false))
	if resolved:
		_check(_id(phase + ".hud_no_stale_guardian"), not String(actual.hud_status).contains("Guardian awaits"), "no Guardian awaits after victory", actual.hud_status)
		if String(current_case.family) == "unlisted":
			var bearing_ready: bool = game.hud.wayfinder.pinned_path.size() > 1 and not bool(actual.hot) and not bool(actual.boss_pending)
			_check(_id(phase + ".bearing_available"), bearing_ready, true, actual)
	await _capture(phase + "_hud")
	await _atlas(room, phase, expected_name, resolved)
	await _journal_known(phase, expected_name, kind, resolved, collision)


func _inspect_reentry(room: int, expected_name: String, kind: String, campaign_done: bool) -> void:
	var actual := _state(room)
	_observe("reentry_state", actual)
	_check(_id("reentry.room"), game.cur_room == room, room, game.cur_room)
	_check(_id("reentry.no_respawn"), _boss_in_room(room) == null, true, _boss_in_room(room) == null)
	_check(_id("reentry.resolved"), bool(actual.resolved), true, actual.resolved)
	_check(_id("reentry.pacified"), bool(actual.pacified), true, actual.pacified)
	_check(_id("reentry.pending"), not bool(actual.boss_pending), false, actual.boss_pending)
	_check(_id("reentry.campaign_unchanged"), bool(game.boss_done.get(kind, false)) == campaign_done, campaign_done, game.boss_done.get(kind, false))
	await _capture("reentry_hud")
	await _atlas(room, "reentry", expected_name, true, false)


func _atlas(room: int, phase: String, expected_name: String, resolved: bool, capture := true) -> void:
	game.menus.open_map()
	await frames(5)
	var atlas: Control = game.menus.root.find_child("FieldAtlas", true, false) as Control
	if not _check(_id(phase + ".atlas_exists"), atlas != null, "real field atlas", atlas != null):
		game.menus.close()
		return
	atlas.call("select_room", room)
	await frames(3)
	var details: Node = atlas.get("details")
	var labels := _texts(details)
	var prefix := "Defeated" if resolved else "Guardian"
	var matching: Array[String] = []
	for text in labels:
		if text.contains(prefix) and text.contains(expected_name):
			matching.append(text)
	_observe(phase + "_atlas", {"labels": labels, "selected": atlas.get("selected"), "expected_name": expected_name})
	_check(_id(phase + ".atlas_identity_state"), matching.size() == 1, prefix + " · " + expected_name, labels)
	if capture:
		await _capture(phase + "_atlas")
	game.menus.close()
	await frames(3)


func _journal_unknown() -> void:
	game.menus.open_journal("progress")
	await frames(5)
	var content := game.menus.root.find_child("JournalContent", true, false)
	var labels := _texts(content)
	var leaked: Array[String] = []
	for zi in game.zones.size():
		var kind := String(game.zones[zi].get("boss", ""))
		if kind == "" or game.charted(zi):
			continue
		var base_name := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind))
		var zone_name := String(game.zones[zi].get("name", ""))
		for text in labels:
			if text.contains(base_name) or (zone_name != "" and text.contains(zone_name)):
				if not leaked.has(text):
					leaked.append(text)
	_observe("uncharted_journal", {"labels": labels, "leaked_guardians": leaked,
		"visited": game.visited.duplicate(), "campaign_marks": game.boss_done.duplicate()})
	_check(_id("journal_unknown.content"), content != null, "journal progress content", content != null)
	_check(_id("journal_unknown.fog"), leaked.is_empty(), "no uncharted guardian identities or reused kit names", leaked)
	await _capture("uncharted_journal")
	game.menus.close()
	await frames(3)


func _journal_known(phase: String, expected_name: String, kind: String, resolved: bool, collision: bool) -> void:
	game.menus.open_journal("progress")
	await frames(5)
	var content := game.menus.root.find_child("JournalContent", true, false)
	var labels := _texts(content)
	var named_rows := _containing(labels, expected_name)
	var base_name := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind))
	var campaign_rows := _containing(labels, base_name)
	_observe(phase + "_journal", {"labels": labels, "named_rows": named_rows,
		"campaign_rows": campaign_rows, "expected_name": expected_name, "collision_fixture": collision})
	_check(_id(phase + ".journal_named_row"), named_rows.size() == 1, "one independent " + expected_name + " row", named_rows)
	if named_rows.size() == 1:
		var marked_done := String(named_rows[0]).contains("✓")
		_check(_id(phase + ".journal_named_state"), marked_done == resolved, resolved, named_rows[0])
	if collision:
		_check(_id(phase + ".journal_collision"), campaign_rows.size() == 1 and named_rows.size() == 1,
			"separate campaign " + base_name + " and " + expected_name + " rows", {"campaign": campaign_rows, "named": named_rows})
		if campaign_rows.size() == 1:
			_check(_id(phase + ".journal_campaign_state"), String(campaign_rows[0]).contains("✓") == bool(current_case.campaign_done_fixture),
				current_case.campaign_done_fixture, campaign_rows[0])
	await _capture(phase + "_journal")
	if not flag("baseline"):
		await _journal_map_action(phase, int(current_case.arena))
	game.menus.close()
	await frames(3)


## Ordinary GUI input, including real ScreenTouch events in --touch mode.
func _click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	if game.touch_mode:
		for down in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = at
			touch.pressed = down
			Input.parse_input_event(touch)
			await frames(3)
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		Input.parse_input_event(motion)
		await frames(2)
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = at
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			Input.parse_input_event(click)
			await frames(3)
	await frames(4)


func _map_state() -> Dictionary:
	return {"room": game.cur_room, "visited": game.visited.duplicate(),
		"marks": game.boss_done.duplicate(), "pocket": game.pocket_done,
		"unlisted": game.unlisted_banked.duplicate(), "waking": game.waking_kills.duplicate(),
		"pin": game.hud.wayfinder.pinned_room}


func _journal_map_action(phase: String, room: int) -> Control:
	var button := game.menus.root.find_child("JournalGuardianMap_%d" % room, true, false) as Button
	if not _check(_id(phase + ".map_button"), button != null and not button.disabled,
			"usable Show on map control", button != null):
		return null
	var scroll := game.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(button)
		await frames(3)
	if not _check(_id(phase + ".map_button_visible"), button.is_visible_in_tree() and button.custom_minimum_size.y >= 44.0 \
			and scroll != null and scroll.get_global_rect().encloses(button.get_global_rect()),
			"fully visible 44px control before input", button.get_global_rect()):
		return null
	var before := _map_state()
	await _click(button)
	var atlas := game.menus.root.find_child("FieldAtlas", true, false) as Control if game.menus.root != null else null
	if not _check(_id(phase + ".map_input_destination"), atlas != null and int(atlas.get("selected")) == room,
			"real atlas selecting the recorded room", atlas.get("selected") if atlas != null else -1):
		return null
	_check(_id(phase + ".map_view_only"), before == _map_state(), "no movement, discovery, completion or route-pin mutation", _map_state())
	await _capture(phase + "_map_action")
	return atlas


func _returned_pocket_map(room: int) -> void:
	# We have used the real Return stone. The chart inspects the detached
	# recorded arena without taking the player back through its portal.
	game.menus.open_journal("progress")
	await frames(5)
	var origin := game.cur_room
	var atlas := await _journal_map_action("returned_pocket", room)
	if atlas != null:
		var pin := atlas.find_child("PinRoute", true, false) as Button
		var travel := atlas.find_child("Travel", true, false) as Button
		_check(_id("returned_pocket.detached_view"), atlas.get("_rooms") == [room] and pin != null and pin.disabled and travel != null and travel.disabled,
			"isolated pocket view without a route or travel grant", atlas.get("_rooms"))
		var home := atlas.find_child("AtlasYourPosition", true, false) as Button
		if _check(_id("returned_pocket.position_button"), home != null and home.custom_minimum_size.y >= 44.0,
				"Your position control", home != null):
			await _click(home)
			_check(_id("returned_pocket.current_area"), int(atlas.get("selected")) == origin and not (atlas.get("_rooms") as Array).has(room) and game.cur_room == origin,
				"current-area view without movement", {"selected": atlas.get("selected"), "room": game.cur_room, "chart": atlas.get("_rooms")})
			await _capture("returned_current_area")
	game.menus.close()
	await frames(3)


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node == null:
		return result
	if node is Label:
		result.append((node as Label).text)
	elif node is RichTextLabel:
		result.append((node as RichTextLabel).get_parsed_text())
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _containing(labels: Array[String], wanted: String) -> Array[String]:
	var result: Array[String] = []
	for text in labels:
		if text.contains(wanted):
			result.append(text)
	return result


func _capture(name: String) -> void:
	await frames(2)
	var path := shot(String(current_case.id) + "_" + name)
	var captures: Array = current_case.captures
	captures.append({"name": name, "path": path})


func _id(suffix: String) -> String:
	return String(current_case.get("id", "rig")) + "." + suffix


func _observe(name: String, value: Variant) -> void:
	var observations: Array = current_case.observations
	observations.append({"name": name, "value": value})


func _check(id: String, passed: bool, expected: Variant, actual: Variant) -> bool:
	checks.append({"id": id, "passed": passed, "expected": expected, "actual": actual})
	if not passed:
		failure_count += 1
	print("OPTIONAL CHECK: %s %s actual=%s" % ["PASS" if passed else "FAIL", id, JSON.stringify(actual)])
	return passed


func _write_report(complete: bool) -> void:
	var directory := ProjectSettings.globalize_path(shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("observations.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("OPTIONAL REPORT WRITE FAILED: " + path)
		failure_count += 1
		return
	file.store_string(JSON.stringify({"rig": rig_name, "mode": "baseline" if flag("baseline") else "regression",
		"complete": complete, "no_saves": game.no_saves, "touch": game.touch_mode,
		"renderer": RenderingServer.get_current_rendering_method(),
		"scope": "solo state and UI; QA positioning and synthetic overkill; no normal combat or network reward claim",
		"case_count": cases.size(), "check_count": checks.size(), "failed": failure_count,
		"cases": cases, "checks": checks}, "\t"))
	file.close()
	print("OPTIONAL REPORT: " + path)
