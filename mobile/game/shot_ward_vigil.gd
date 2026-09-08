extends ShotRig
const Vigil := preload("res://scripts/ward_vigil.gd")
const Guide := preload("res://scripts/quest_guide.gd")


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.play_started = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.terrain_event_t = 10000.0
	game.camera.position_smoothing_enabled = false
	game.player.set_physics_process(false)
	game.player.level = 7
	game.player.recalc()
	game.player.hp = game.player.max_hp
	game.player.mp = game.player.max_mp
	game.player.hurt_cd = 9999.0
	var zi := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "The Collapsed Tower":
			zi = i
	if zi < 0:
		return _fail("no authored tower")
	game.player.global_position = game.room_center(zi)
	game._enter_room(zi)
	await skip_dialogue()
	await frames(4)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy:
			node.remove_from_group("enemies")
			node.queue_free()
	game.zone_alive[zi] = 0
	game.cleared[zi] = true
	var v := Vigil.find(game)
	if v == null:
		return _fail("no ward in the real tower")
	var p := game.player
	p.global_position = v.global_position + Vector2(0, 65)
	zoom(1.15)
	game.refresh_quest()
	await sim_wait(3.6)
	shot("old_tower_ward")
	v.interact()
	await frames(3)
	if game.menus.current != "ward_vigil":
		return _fail("ward had no clear opt-in")
	shot("vigil_invitation")
	game.menus.root.find_child("BeginVigil", true, false).pressed.emit()
	if not v.active() or not game._room_hot(zi):
		return _fail("ward failed to begin/mark its encounter")
	await sim_wait(1.0)
	shot("wave_arrival_warnings")
	game.menus.open_pause()
	var paused_timer: float = v.remaining
	await get_tree().create_timer(0.3, true).timeout
	if not is_equal_approx(v.remaining, paused_timer):
		return _fail("solo pause advanced the ward")
	game.menus.close()
	await sim_wait(Balance.VIGIL_PREPARE_SECONDS)
	if v._living().size() != 2:
		return _fail("first wave did not spawn")
	shot("defend_the_heart")
	if v.status.get_node("Integrity").size.y > 8 or v.status.get_node("Hint").position.y + v.status.get_node("Hint").size.y > v.status.size.y:
		return _fail("ward status clipped its hint")
	# Failure is retryable and cleans every living wave actor.
	v.integrity = 1.0
	p.global_position = v.global_position + Vector2(330, 0)
	await sim_wait(0.5)
	if v.phase != 0 or not v._living().is_empty() or game._room_hot(zi):
		return _fail("unattended ward did not fail and release the room")
	shot("ward_gutters")
	p.global_position = v.global_position + Vector2(0, 65)
	v.request(p, "start")
	await sim_wait(0.2)
	v.request(p, "stop")
	if v.phase != 0:
		return _fail("voluntary snuff did not stop the vigil")
	v.request(p, "start")
	game._death_world_reset(zi)
	if v.phase != 0:
		return _fail("death reset left a live ward")
	# A complete three-wave defense exercises real Enemy deaths and their loot path.
	game.flags["sq_on_tower_light"] = true
	game.hud.wayfinder.track("tower_light")
	var objective := Guide.destination(game, Guide.step(game, "tower_light"))
	if objective.is_empty() or objective.point.distance_to(v.global_position) > 1.0:
		return _fail("Journal could not guide to the ward")
	var purge_before: int = game.zone_alive[zi]
	v.request(p, "start")
	for wave_index in 3:
		await sim_wait(Balance.VIGIL_PREPARE_SECONDS + 0.15)
		if v.phase != 2 or v.wave != wave_index + 1:
			return _fail("wrong wave progression")
		for e in v._living():
			e.set_physics_process(false)
			e.global_position = v.global_position + Vector2(150 + 60 * v._living().find(e), 100)
		await frames(3)
		shot("wave_%d" % (wave_index + 1))
		var rng_before := game.loot_rng.state
		for e in v._living():
			e.take_damage(e.max_hp * 10, Vector2.RIGHT, false, true)
		await frames(4)
		if game.zone_alive[zi] != purge_before:
			return _fail("vigil kills changed room credit")
		# Random combat FX may roll their own RNG, but the loot stream stays sealed.
		if game.loot_rng.state != rng_before:
			return _fail("vigil kills consumed the reward stream")
	if v.phase != 3 or not game.get_flag(Vigil.DONE, false) or not game.title_available("lamplighter"):
		return _fail("completed defense lost its world flag/title")
	await sim_wait(1.0)
	shot("tower_restored")
	game.menus.open_journal("quests")
	await frames(4)
	shot("tell_mara")
	game.menus.close()
	# Touch uses the same world interactor and the same readable invitation.
	v.phase = 0
	game.flags.erase(Vigil.DONE)
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(4)
	shot("touch_ward")
	v.interact()
	await frames(4)
	shot("touch_invitation")
	game.menus.close()
	var wire_error: String = await preload("res://scripts/tests/test_vigil_network.gd").run(self, v)
	if wire_error != "":
		return _fail(wire_error)
	game.flags[Vigil.DONE] = true
	game.flags.erase("sq_on_tower_light")
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.player.global_position = game.room_center(0)
	game._enter_room(0)
	await skip_dialogue()
	await frames(4)
	var mara: Dictionary = {}
	for entry in game.interactables:
		if is_instance_valid(entry.get("node")) and entry.node.get_meta("quest_convo", "") == "lamplighter_mara":
			mara = entry
	if mara.is_empty():
		return _fail("Mara is missing from Emberfall")
	game.player.global_position = mara.node.global_position + Vector2(40, 20)
	mara.action.call()
	await frames(4)
	game.hud._advance_dialogue()  # reveal the line before the capture
	await frames(2)
	if is_instance_valid(game.hud._ann_active) and game.hud._ann_active.visible:
		return _fail("a reward notice covered Mara's dialogue")
	for row in game.hud._log_lines:
		if is_instance_valid(row) and row.visible:
			return _fail("event feed covered Mara's dialogue")
	shot("mara_recognition")
	await skip_dialogue()
	if not game.get_flag("sq_paid_tower_light", false) or not game.get_flag("sq_kept_tower_light", false):
		return _fail("object-first discovery did not complete Mara's recognition")
	game.flags.erase(Vigil.DONE)
	var restored := Vigil.install(game, zi)
	if restored.phase != 3 or not game.get_flag(Vigil.DONE, false):
		return _fail("the kept light did not survive a rebuilt chapter")
	restored.queue_free()
	print("ok: live ward opt-in, three waves, failure/retry, voluntary stop, pause, death reset, purge/reward isolation, quest target, title and touch")
	finish()


func _fail(message: String) -> void:
	push_error("WARD QA FAIL: " + message)
	get_tree().quit(1)
