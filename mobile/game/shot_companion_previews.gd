extends ShotRig
const Preview := preload("res://scripts/ui/companion_preview.gd")
const Sanctuary := preload("res://scripts/ui/sanctuary.gd")
const Wildlife := preload("res://scripts/wildlife.gd")
const Pet := preload("res://scripts/pet_visual.gd")


func _ready() -> void:
	await boot("mage", "ch1", false)
	var error := await _checks()
	game.menus.close()
	await frames(3)
	if error == "" and not get_tree().get_nodes_in_group("companion_previews").is_empty():
		error = "closing the final menu leaked companion previews"
	if error != "":
		push_error(error)
		shot("failed")
		return finish(1)
	print("ok: companion previews live: paused Sanctuary and Codex animate, world follower remains paused, hidden/clipped clocks stop, all six Wardrobe rows animate, purchase/equip/return work, touch menus and cleanup pass")
	finish()


func _checks() -> String:
	game.player.set_physics_process(false)
	game.terrain_event_t = 10000.0
	game.settings["camera_shake"] = 0.0
	game.camera.position_smoothing_enabled = false
	game._load_meta()
	game._meta["renown"] = Balance.RENOWN_PRICE_PET_RARE
	for id in Pet.ORDER:
		game._meta.erase("own_pet_all_" + id)
	game.player.rescued_pets = ["spore_pup", "hearth_hopper", "cinder_bat", "ash_crow"]
	Wildlife.sync_flags(game)
	for id in game.player.rescued_pets:
		game.grant_cosmetic("pet", "all", id)
	game.player.set_pet("cinder_bat")
	await sim_wait(0.2)
	Sanctuary.open(game.menus)
	await frames(3)
	if not get_tree().paused:
		return "solo Sanctuary did not pause the world fixture"
	var pup := _preview("spore_pup")
	var error := await _check_clock(pup, "sanctuary")
	if error != "":
		return error
	var age_before: float = pup.visual.age
	game.menus.root.hide()
	await sim_wait(0.2)
	game.menus.root.show()
	if pup.visual.age != age_before:
		return "a hidden Sanctuary kept animating"
	var return_button := _button(pup.get_parent(), "Ask this companion to follow")
	if return_button == null:
		return "Sanctuary companion equip button missing"
	return_button.pressed.emit()
	await frames(3)
	if game.player.equipped_pet != "spore_pup" or is_instance_valid(pup):
		return "Sanctuary equip did not replace its menu and follower"
	pup = _preview("spore_pup")
	return_button = _button(pup.get_parent(), "Return companion to the sanctuary")
	if return_button == null:
		return "Sanctuary return button missing"
	return_button.pressed.emit()
	await frames(3)
	if game.player.equipped_pet != "":
		return "Sanctuary return did not clear the follower"
	var flutter := _preview("pale_flutter")
	_reveal(flutter)
	await frames(3)
	shot("02_sanctuary_locked_wingbeats")
	if flutter.modulate == Color.WHITE:
		return "unrescued companion lost its dimmed presentation"
	game.menus.close()
	game.player.set_pet("cinder_bat")
	await sim_wait(0.2)
	game.menus.open_codex("sanctuary")
	await frames(3)
	var bat := _preview("cinder_bat")
	_reveal(bat)
	await frames(3)
	error = await _check_clock(bat, "codex")
	if error != "":
		return error
	UIWardrobe.open(game.menus)
	await frames(3)
	for id in Pet.ORDER:
		var preview := _preview(id)
		if preview == null:
			return id + " missing from Wardrobe"
		_reveal(preview)
		await frames(2)
		var age: float = preview.visual.age
		await sim_wait(0.15)
		if preview.visual.age <= age or preview.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return id + " Wardrobe preview is frozen or captures row input"
	shot("04_wardrobe_all_companions")
	var glimmer := _preview("glimmerwing")
	_reveal(glimmer)
	await frames(3)
	var buy := _button(glimmer.get_parent(), "Buy")
	if buy == null or buy.disabled:
		return "unowned Wardrobe companion has no usable purchase button"
	var price := Balance.renown_price("pet", String(Skins.find_pet("glimmerwing").tier))
	var wallet := game.renown()
	buy.pressed.emit()
	await frames(3)
	if not game.owns_cosmetic("pet", "all", "glimmerwing") or game.renown() != wallet - price:
		return "Wardrobe companion purchase charged or granted incorrectly"
	glimmer = _preview("glimmerwing")
	var wear := _button(glimmer.get_parent(), "Wear")
	if wear == null:
		return "purchased companion did not gain its Wear button"
	wear.pressed.emit()
	await frames(3)
	if game.player.equipped_pet != "glimmerwing":
		return "Wardrobe did not equip the purchased companion"
	_reveal(_preview("glimmerwing"))
	await frames(3)
	shot("05_purchased_companion_equipped")
	game.menus.close()
	await sim_wait(0.2)
	if not is_instance_valid(game.pet_follower) or game.pet_follower.get_meta("pet_id") != "glimmerwing":
		return "purchased companion did not appear after resuming the world"
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	Sanctuary.open(game.menus)
	await frames(3)
	shot("06_touch_sanctuary")
	_reveal(_preview("pale_flutter"))
	await frames(3)
	shot("07_touch_sanctuary_lower")
	UIWardrobe.open(game.menus)
	await frames(3)
	_reveal(_preview("pale_flutter"))
	await frames(3)
	shot("08_touch_wardrobe")
	return ""


func _check_clock(preview: Control, label: String) -> String:
	if preview == null:
		return label + " pet preview missing"
	var follower := game.pet_follower
	if not is_instance_valid(follower):
		return label + " world follower fixture missing"
	var follower_age: float = follower.age
	var seen := {}
	for sample in 12:
		await sim_wait(0.11)
		seen[preview.visual.frame] = true
		if sample in [0, 5, 11]:
			# Read after the complete canvas has drawn, including paused menus.
			await RenderingServer.frame_post_draw
			shot("01_%s_motion_%02d" % [label, sample])
	if seen.size() < 3 or follower.age != follower_age:
		return label + " menu animation or world pause is broken"
	return ""


func _preview(id: String) -> Control:
	for node in get_tree().get_nodes_in_group("companion_previews"):
		if node.pet_id == id and not node.is_queued_for_deletion() and game.menus.root.is_ancestor_of(node):
			return node
	return null


func _reveal(preview: Control) -> void:
	var ancestor := preview.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(preview)
		ancestor = ancestor.get_parent()


func _button(node: Node, text: String) -> Button:
	if node is Button and text in node.text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null
