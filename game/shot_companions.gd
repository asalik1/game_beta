extends ShotRig
const Pet := preload("res://scripts/pet_visual.gd")
var pets: Array[Sprite2D] = []
var labels: Array[Label] = []


func _ready() -> void:
	await boot("mage", "ch1", false)
	game.settings["camera_shake"] = 0.0
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	game.player.set_physics_process(false)
	game.player.global_position = game.room_center(1)
	game._enter_room(1)
	await skip_dialogue()
	for node in game.zone_scenery[1]:
		if is_instance_valid(node):
			node.queue_free()
	game.zone_scenery[1] = []
	for entry in game.interactables:
		if is_instance_valid(entry.get("node")) and entry.node is Node2D:
			entry.node.visible = false
	await frames(2)
	var origin := game.player.global_position
	hide_hud()
	game.player.visible = false
	for i in Pet.ORDER.size():
		var pet := Pet.new()
		pet.setup(Pet.ORDER[i])
		pet.global_position = origin + Vector2((i % 3 - 1) * 205, (i / 3) * 180 - 65)
		game.world.add_child(pet)
		pets.append(pet)
		var label := Label.new()
		label.text = String(Skins.find_pet(Pet.ORDER[i]).name)
		label.position = pet.position + Vector2(-90, 16)
		label.size = Vector2(180, 25)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.world(label, 13, 4)
		game.world.add_child(label)
		labels.append(label)
	zoom(1.6)
	await sim_wait(0.2)
	for i in 24:
		for pet in pets:
			pet.animate(1.0 / 12.0, true, Balance.PET_STRIDE_SPEED)
		await frames(2)
		shot("motion_%02d" % i)
	for pet in pets:
		pet.animate(0.1, false)
	shot("grounded_rest_flying_hover")
	for pet in pets:
		pet.visible = false
	for label in labels:
		label.visible = false
	game.player.visible = true
	game.hud.visible = true
	zoom(1.12)
	game.player.equipped_pet = "spore_pup"
	game.refresh_pet_follower()
	await sim_wait(0.1)
	var frames_seen := {}
	for i in 12:
		game.player.global_position.x += 18
		await sim_wait(0.08)
		if is_instance_valid(game.pet_follower):
			frames_seen[game.pet_follower.frame] = true
	if frames_seen.size() < 3 or game.pet_follower.hframes != 8:
		push_error("the real follower did not animate while following the moving hero")
		finish(1)
		return
	shot("real_follower_walking")
	await sim_wait(2.0)
	if game.pet_follower.frame != 0:
		push_error("grounded follower did not settle after stopping")
		finish(1)
		return
	shot("real_follower_resting")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.player.equipped_pet = "cinder_bat"
	game.refresh_pet_follower()
	await sim_wait(0.3)
	shot("touch_flying_companion")
	print("ok: 24 rendered six-pet animation samples, grounded rest, real follow/stop transition and touch flying companion")
	finish()
