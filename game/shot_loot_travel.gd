extends ShotRig
const SLOT := 92
const Recovery := preload("res://scripts/loot_recovery.gd")

class LossSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass


func _ready() -> void:
	await boot("warrior", "ch1", false)
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = SaveGame.path(SLOT) + suffix
		files[file] = FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else null
	var error := await _checks()
	game.no_saves = true
	game.save_slot = -1
	game.guest_world = false
	for file in files:
		if files[file] == null:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		else:
			var output := FileAccess.open(file, FileAccess.WRITE)
			if output == null:
				error = "could not restore live travel fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error != "":
		push_error(error)
		shot("failed")
		return finish(1)
	print("ok: live loot travel: production host-loss callback, unchanged home geography, immediate old-world join mail, physical local resume, full/complete claims, repeated saves and reloads, touch")
	finish()


func _checks() -> String:
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	var p := game.player
	p.set_physics_process(false)
	Recovery.retire_live(game)
	game.flush_dropped_loot()
	await frames(3)
	game.mailbox = []
	p.bags = [Items.make_bag("F")]
	p.backpack = []
	p.consumables = []
	p.gem_bag = []
	p.materials = []
	p.loose_bags = []
	for i in p.bag_capacity():
		p.consumables.append(Items.make_reset_stone())
	SaveGame.write(game, SLOT)
	var home := SaveGame.read(SLOT)
	game.switch_chapter("ch4", true)
	p.set_physics_process(false)
	await frames(4)
	var overflow := {"kind": "potion", "potion": Items.make_potion("health", "instant", "B", "accord")}
	game.give_loot(overflow.duplicate(true), p.global_position + Vector2(-100, 90))
	game.give_loot(overflow.duplicate(true), p.global_position + Vector2(100, 90))
	if game.dropped_loot.size() != 2:
		return "live full-pack fixture failed to leave two equal bottle drops"
	await sim_wait(1.0)
	shot("overflow_in_host_world")
	var live_before := game.dropped_loot.duplicate(true)
	game.guest_world = true
	game.save_slot = SLOT
	var session := LossSession.new()
	session.game = game
	add_child(session)
	session._on_session_ended("qa_host_loss")  # exact production save-before-teardown path
	await frames(3)
	session.queue_free()
	game.guest_world = false
	game.save_slot = -1
	var disk := SaveGame.read(SLOT)
	var c := SaveGame.character_of(disk)
	if disk.chapter != home.chapter or SaveGame.world_of(disk) != SaveGame.world_of(home):
		return "host-loss callback overwrote the home world"
	if not c.dropped_loot.is_empty() or c.mailbox.size() != 1 or c.mailbox[0].items.size() != 2:
		return "host-loss callback saved foreign ground coordinates or lost equal items"
	if game.dropped_loot != live_before or not game.mailbox.is_empty():
		return "host-loss autosave consumed the still-live overflow"
	game.load_save(SLOT)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if game.chapter_id != home.chapter or game.mailbox.size() != 1 or not game.dropped_loot.is_empty():
		return "home resume stranded host overflow or added a duplicate recovery letter"
	var letter: Dictionary = game.mailbox[0]
	UIMailbox.open_letter(game.menus, letter)
	await frames(3)
	shot("host_loss_items_arrive_home")
	_claim()
	await frames(3)
	if letter.items.size() != 2:
		return "a full pack consumed an unclaimable travel attachment"
	shot("full_pack_preserves_travel_mail")
	p.consumables = []
	_claim()
	await frames(3)
	if not letter.items.is_empty() or p.consumables.size() != 2:
		return "identical travel rewards did not both collect"
	shot("both_identical_bottles_claimed")
	game.menus.close()
	SaveGame.write(game, SLOT)
	game.load_save(SLOT)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if p.consumables.size() != 2 or game.mailbox.size() != 1 or not game.mailbox[0].items.is_empty():
		return "saving and reloading claimed travel rewards duplicated them"
	# Legacy local drops become mail immediately when that character joins elsewhere.
	var legacy := SaveGame._character_section(game).duplicate(true)
	legacy.dropped_loot = live_before
	var before := legacy.duplicate(true)
	SaveGame.apply_character(game, legacy, false)
	if legacy != before or game.mailbox.size() != 2 or not game.dropped_loot.is_empty():
		return "cross-world apply delayed old-world loot or mutated the saved character"
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	UIMailbox.open_letter(game.menus, game.mailbox[-1])
	await frames(4)
	shot("touch_immediate_join_mail")
	game.menus.close()
	# Same-world restore keeps local physical drops available beside the hero.
	legacy.dropped_loot[0].pos = [p.global_position.x - 100, p.global_position.y + 90]
	legacy.dropped_loot[1].pos = [p.global_position.x + 100, p.global_position.y + 90]
	SaveGame.apply_character(game, legacy, true)
	await frames(3)
	if game.dropped_loot.size() != 2 or game.mailbox.size() != 1:
		return "same-world character restore no longer keeps physical drops"
	shot("local_resume_keeps_ground_loot")
	return ""


func _claim() -> void:
	var button := game.menus.root.find_child("MailClaimAll", true, false) as Button
	if button != null:
		button.pressed.emit()
