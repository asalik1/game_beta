extends ShotRig
const Recovery := preload("res://scripts/loot_recovery.gd")


func _ready() -> void:
	await boot("warrior", "ch4", false)
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	var error := await _checks()
	SaveGame.delete(SaveGame.MAX_SLOTS)
	if error != "":
		push_error(error)
		shot("failed")
		return finish(1)
	print("ok: live earned spoils: disk reload, exact rolls, full/partial/complete claims, no duplicate reload, painted opening, chapter teardown, guest character-only home save, large letters and touch")
	finish()


func _checks() -> String:
	var p := game.player
	p.set_physics_process(false)
	p.global_position = game.room_center(game.cur_room)
	Recovery.retire_live(game)
	await frames(3)
	game.mailbox = []
	game.dropped_loot = []
	p.backpack = []
	p.gem_bag = []
	p.materials = []
	p.loose_bags = []
	p.bags = [Items.make_bag("F")]
	p.consumables = []
	for i in p.bag_capacity():
		p.consumables.append(Items.make_reset_stone())
	p.gold = 321
	p.greed = 0.0
	p.goldrush_time = 0.0
	var gear := Chest.drop(game, "gold", p.global_position + Vector2(-130, -90), {"grade": "B"})
	var supply := Chest.drop(game, "gold", p.global_position + Vector2(130, -90), {"kind": "supply", "supply_tier": "gold", "supply_gem": true, "first_clear": true, "boss_lv": 40})
	Pickup.drop_gold(game, 39, p.global_position + Vector2(0, -230))
	await sim_wait(0.7)
	var saved_rewards := Recovery.snapshot(game)
	if int(saved_rewards.chests) != 2 or saved_rewards.items.size() < 5:
		return "live gear/supply reward fixture was not preserved"
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	var saved := SaveGame.read(SaveGame.MAX_SLOTS)
	var snapshot := Recovery.clean(SaveGame.character_of(saved).get("unclaimed_rewards", {}))
	if not _same_json(snapshot, Recovery.clean(saved_rewards)) or gear.opened or supply.opened or p.gold != 321:
		print("SPOILS BEFORE: ", JSON.stringify(saved_rewards))
		print("SPOILS AFTER: ", JSON.stringify(snapshot), " opened=", gear.opened, "/", supply.opened, " gold=", p.gold)
		return "disk save altered or lost unopened spoils"
	await sim_wait(2.0)
	shot("unopened_earned_spoils")
	var disk_before := FileAccess.get_file_as_string(SaveGame.path(SaveGame.MAX_SLOTS))
	game.no_saves = false  # exercise the production autosave guard, not the rig mute
	game.load_save(SaveGame.MAX_SLOTS)
	game.no_saves = true
	game.save_slot = -1
	if game.restoring_save or FileAccess.get_file_as_string(SaveGame.path(SaveGame.MAX_SLOTS)) != disk_before:
		return "resume wrote incomplete state during restore or left its save guard latched"
	p.set_physics_process(false)
	await frames(5)
	if p.gold != 321 + int(snapshot.gold) or game.mailbox.size() != 1:
		return "resume lost or doubled recovered coins/letter"
	if not Recovery.snapshot(game).items.is_empty() or Recovery.snapshot(game).gold != 0:
		return "resume left claimable original chests/coins beside recovery"
	var letter: Dictionary = game.mailbox[0]
	if not _same_json(letter.items, snapshot.items):
		return "resume rerolled or lost exact chest contents"
	UIMailbox.open_letter(game.menus, letter)
	await frames(3)
	shot("recovered_after_resume")
	var count: int = letter.items.size()
	_claim()
	await frames(3)
	if letter.items.size() != count or not p.backpack.is_empty():
		return "full pack lost or swallowed recovered attachments"
	if game.menus.root.find_child("MailClaimNotice", true, false) == null:
		return "failed mail claim provided no visible explanation"
	shot("full_pack_keeps_spoils")
	p.consumables.resize(p.consumables.size() - 2)
	_claim()
	await frames(3)
	if letter.items.is_empty() or letter.items.size() >= count:
		return "partial claim did not preserve its remainder"
	shot("partial_claim_keeps_remainder")
	p.consumables = []
	p.bags = [Items.make_bag("S"), Items.make_bag("S")]
	_claim()
	await frames(3)
	if not letter.items.is_empty() or p.gold != 321 + int(snapshot.gold):
		return "complete claim failed or paid already-credited gold again"
	shot("claimed_spoils")
	game.menus.close()
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	var banked := SaveGame.read(SaveGame.MAX_SLOTS)
	var wallet := p.gold
	var mail_count := game.mailbox.size()
	game.load_save(SaveGame.MAX_SLOTS)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if p.gold != wallet or game.mailbox.size() != mail_count:
		return "reloading claimed rewards paid them a second time"
	var restored_pack: Array = SaveGame._character_section(game).backpack
	if not _same_json(restored_pack, SaveGame.character_of(banked).backpack):
		print("PACK BEFORE: ", JSON.stringify(SaveGame.character_of(banked).backpack))
		print("PACK AFTER: ", JSON.stringify(restored_pack))
		return "claimed gear did not survive the second reload"
	await sim_wait(4.5)  # let resume/arrival notices finish before framing the lid
	# A real physics contact still plays the original lid/fanfare and pays once.
	var chest := Chest.drop(game, "gold", p.global_position + Vector2(130, 80), {"grade": "B"})
	var frozen := chest.sealed_contents().duplicate(true)
	var bp_before := p.backpack.size()
	p.global_position = chest.global_position
	await sim_wait(0.25)
	if not chest.opened or p.backpack.size() != bp_before + 1:
		return "real chest contact failed after content freezing"
	if p.backpack[-1] != frozen.items[0].item:
		return "opening rerolled the frozen item"
	shot("painted_chest_opening")
	chest._on_body_entered(p)
	if p.backpack.size() != bp_before + 1:
		return "repeated chest contact paid twice"
	# Travel recovers live earned chests, while ordinary victory does not tear down.
	Chest.drop(game, "silver", p.global_position + Vector2(300, 0), {"grade": "C"})
	Pickup.drop_gold(game, 23, p.global_position + Vector2(300, -120))
	var travel := Recovery.snapshot(game)
	wallet = p.gold
	mail_count = game.mailbox.size()
	game.switch_chapter("capital", true)
	await frames(4)
	if p.gold != wallet + int(travel.gold) or game.mailbox.size() != mail_count + 1:
		return "chapter teardown lost live uncollected spoils"
	UIMailbox.open_letter(game.menus, game.mailbox[-1])
	await frames(3)
	shot("recovered_on_departure")
	game.menus.close()
	# Guest/endgame character-only saves keep their HOME geometry unchanged.
	Chest.drop(game, "gold", p.global_position + Vector2(300, 0), {"grade": "B"})
	var guest_rewards := Recovery.snapshot(game)
	wallet = p.gold
	mail_count = game.mailbox.size()
	SaveGame.write_character_home(game, SaveGame.MAX_SLOTS)
	var home := SaveGame.read(SaveGame.MAX_SLOTS)
	if SaveGame.world_of(home) != SaveGame.world_of(banked) or home.chapter != banked.chapter:
		return "personal reward save overwrote the guest's home world"
	var foreign_chapter := game.chapter_id
	SaveGame.apply_character(game, SaveGame.character_of(home), false)
	await frames(3)
	if game.chapter_id != foreign_chapter or p.gold != wallet + int(guest_rewards.gold) \
		or game.mailbox.size() != mail_count + 1 or not Recovery.snapshot(game).items.is_empty():
		return "character-only recovery lost spoils, changed the world or kept duplicate sources"
	UIMailbox.open_letter(game.menus, game.mailbox[-1])
	await frames(3)
	shot("guest_spoils_travel_home")
	# Big reward letters keep fixed, reachable actions and use the real typed art.
	var bundle: Array = []
	for i in 110:
		if i % 2 == 0:
			bundle.append({"kind": "material", "family": Items.MATERIAL_FAMILIES[i % 5], "grade": Items.GRADES[i % 7], "count": 4})
		else:
			bundle.append({"kind": "potion", "potion": Items.make_potion("health", "instant", "F", "accord")})
	game.send_mail("A well-stocked return", "Materials and remedies from the road.", bundle)
	UIMailbox.open_letter(game.menus, game.mailbox[-1])
	await frames(4)
	var scroll := game.menus.root.find_child("MailAttachments", true, false) as ScrollContainer
	var claim := game.menus.root.find_child("MailClaimAll", true, false) as Button
	if scroll == null or claim == null or scroll.get_v_scroll_bar().max_value <= scroll.size.y:
		return "large reward letter has no scrolling attachments"
	if not get_viewport().get_visible_rect().encloses(claim.get_global_rect()):
		return "large reward letter pushed its claim control off-screen"
	shot("large_letter_scrolling")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	UIMailbox.open_letter(game.menus, game.mailbox[-1])
	await frames(3)
	shot("touch_reward_letter")
	return ""


func _claim() -> void:
	var button := game.menus.root.find_child("MailClaimAll", true, false)
	if button != null:
		button.pressed.emit()


func _same_json(a: Variant, b: Variant) -> bool:
	# JSON rounds substat binary floats and reads integers as floats. Compare
	# the saved representation on both sides, not their in-memory type/bits.
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
