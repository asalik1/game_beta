extends ShotRig
const Wildlife := preload("res://scripts/wildlife.gd")
const Guide := preload("res://scripts/quest_guide.gd")


func _ready() -> void:
	await boot("warrior", "ch1")
	game.play_started = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.terrain_event_t = 10000.0
	game.camera.position_smoothing_enabled = false
	game.player.set_physics_process(false)
	await _visit("The Hollow Oak")
	var rescue := _spot()
	if rescue == null:
		return _fail("no rescue at the Hollow Oak")
	game.player.global_position = rescue.global_position + Vector2(-55, 12)
	zoom(1.6)
	await sim_wait(0.6)
	shot("stranded_creature")
	rescue.interact()
	await sim_wait(0.6)
	game.player.global_position += Vector2(-160, 0)
	await frames(3)
	if rescue.rescuing or Wildlife.rescued(game, "spore_pup"):
		return _fail("walking away did not cancel the rescue")
	game.player.global_position = rescue.global_position + Vector2(-55, 12)
	rescue.interact()
	await sim_wait(0.5)
	game.menus.open_journal("activities")
	await frames(4)
	if rescue.rescuing:
		return _fail("opening a paused menu did not cancel the rescue")
	game.menus.close()
	rescue.interact()
	await sim_wait(1.0)
	shot("rescue_in_progress")
	if is_instance_valid(game.hud._ann_active):
		var plaque: Control = game.hud._ann_active
		for label_name in ["AnnouncementTitle", "AnnouncementDetail"]:
			var label: Label = plaque.get_node_or_null(label_name)
			if label != null and label.position.y + label.get_minimum_size().y > plaque.size.y:
				return _fail("wrapped announcement escaped the panel")
	var injured_hp: float = game.player.hp
	game.player.hp -= 1.0
	await frames(3)
	if rescue.rescuing:
		return _fail("injury did not cancel the rescue")
	game.player.hp = injured_hp
	rescue.interact()
	await sim_wait(Balance.WILDLIFE_RESCUE_SECONDS + 0.3)
	if not Wildlife.rescued(game, "spore_pup") or not game.owns_cosmetic("pet", "all", "spore_pup"):
		return _fail("live rescue did not grant its keepsake")
	shot("rescue_complete")
	# Every discovery exists at its actual authored location, in both chapters.
	for entry in Wildlife.SITES:
		if String(entry.chapter) != "ch1":
			continue
		await _visit(String(entry.room))
		if _spot() == null:
			return _fail("missing rescue: " + String(entry.id))
		Wildlife.claim(game, String(entry.id))
	# Two concurrent quest landmarks and a tracked objective in the chapel.
	await _visit("The Drowned Chapel")
	game.flags["sq_on_flame_at_window"] = true
	game.flags["pine_taken"] = true
	game.flags.erase("pine_lit")
	game.flags.erase("sq_paid_flame_at_window")
	game.hud.wayfinder.track("flame_at_window")
	var destination := Guide.destination(game, Guide.step(game, "flame_at_window"))
	if destination.is_empty():
		return _fail("authored chapel objective could not be found")
	game.player.global_position = destination.point + Vector2(-100, 30)
	zoom(1.2)
	await sim_wait(0.5)
	shot("quest_in_world")
	game.menus.open_journal("quests")
	await frames(4)
	shot("quest_journal")
	game.menus.close()
	game.flags["pine_lit"] = true
	game.flags["hunter_mark_chapel"] = true
	await sim_wait(0.5)
	shot("chapel_kept_promise")
	# Discovery collection and original shelter, in the normal world render.
	await _visit("Stillwater Reach")
	var home := _spot()
	if home == null:
		return _fail("Stillwater has no sanctuary")
	game.player.global_position = home.global_position + Vector2(-58, 25)
	zoom(1.15)
	await sim_wait(5.0)
	shot("sanctuary_three_rescues")
	for entry in Wildlife.SITES:
		Wildlife.claim(game, String(entry.id))
	await sim_wait(0.5)
	for animal in home.animals:
		if String(animal.get_meta("pet_id", "")) == game.player.equipped_pet:
			return _fail("the active companion appeared twice at home")
	shot("sanctuary_all_companions")
	home.interact()
	await frames(4)
	shot("sanctuary_collection")
	for sc in game.menus.root.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 10000
	await frames(3)
	shot("sanctuary_collection_lower")
	game.menus.close()
	# The follower must snap across teleports, not fly through multiple rooms.
	game.player.set_pet("cinder_bat")
	game._update_pet_follower(0.016)
	game.player.global_position += Vector2(900, 0)
	game._update_pet_follower(0.016)
	if game.pet_follower.global_position.distance_to(game.player.global_position) > 100:
		return _fail("companion lagged across a teleport")
	game.player.global_position = home.global_position + Vector2(-58, 25)
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await sim_wait(0.5)
	shot("touch_sanctuary")
	if not game.interact_in_range or home.prompt.text.begins_with("E"):
		return _fail("touch sanctuary action or prompt did not adapt")
	home.interact()
	await frames(3)
	shot("touch_collection")
	game.menus.close()
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.switch_chapter("ch2", true)
	await frames(3)
	await skip_dialogue()
	for entry in Wildlife.SITES:
		if String(entry.chapter) != "ch2":
			continue
		await _visit(String(entry.room))
		if _spot() == null:
			return _fail("missing ch2 rescue: " + String(entry.id))
	game.switch_chapter("capital", true)
	await frames(3)
	await skip_dialogue()
	await _visit("Accord Commons")
	var city_home := _spot()
	if city_home == null:
		return _fail("Crownfall has no sanctuary")
	game.player.global_position = city_home.global_position + Vector2(-58, 25)
	zoom(1.1)
	await sim_wait(0.5)
	shot("crownfall_sanctuary")
	print("ok: six live sites, rescue distance/menu/injury cancellation, earned ownership, sanctuary persistence, quest NPC routing, journal, touch and teleport follow")
	finish()


func _visit(room_name: String) -> void:
	for zi in game.zones.size():
		if String(game.zones[zi].name) == room_name:
			game.player.global_position = game.room_center(zi)
			game._enter_room(zi)
			await skip_dialogue()
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
			game.zone_alive[zi] = 0
			game.cleared[zi] = true
			game.barrier_active = false
			await frames(3)
			await sim_wait(3.4)
			return


func _spot() -> Node2D:
	for node in get_tree().get_nodes_in_group("wildlife_spots"):
		if node.zone == game.cur_room:
			return node
	return null


func _fail(message: String) -> void:
	push_error(message)
	finish(1)
