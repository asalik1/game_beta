extends ShotRig
const Wildlife := preload("res://scripts/wildlife.gd")
const SLOT := 94

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
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
				error = "could not restore rescue live fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	if error != "":
		push_error(error)
		shot("failed")
		return finish(1)
	print("ok: rescue history live: real ENet world-snapshot RPC excludes host rescues, guest rescue saves home, original geometry preserved, sanctuary residents and follower, repeated reload, touch and legacy migration")
	finish()


func _checks() -> String:
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	var p := game.player
	p.set_physics_process(false)
	p.rescued_pets = ["spore_pup"]
	Wildlife.sync_flags(game)
	game.grant_cosmetic("pet", "all", "spore_pup")
	p.set_pet("spore_pup")
	SaveGame.write(game, SLOT)
	var home := SaveGame.read(SLOT)
	var wire_error := await _foreign_world()
	if wire_error != "":
		return wire_error
	p.set_physics_process(false)
	await skip_dialogue()
	await sim_wait(1.0)
	if Wildlife.count(game) != 1 or not Wildlife.rescued(game, "spore_pup") \
		or Wildlife.rescued(game, "ash_crow") or game.flags.has("sq_kept_rescue_ash_crow"):
		return "real host snapshot inherited host rescues or lost the guest's history"
	if not is_instance_valid(game.pet_follower) or game.pet_follower.get_meta("pet_id") != "spore_pup":
		return "equipped animated companion disappeared after world snapshot"
	preload("res://scripts/ui/sanctuary.gd").open(game.menus)
	await frames(3)
	shot("guest_keeps_own_rescue_history")
	game.menus.close()
	if not Wildlife.claim(game, "ash_crow") or Wildlife.claim(game, "ash_crow"):
		return "guest's own new rescue did not claim exactly once"
	SaveGame.write_character_home(game, SLOT)
	var returned := SaveGame.read(SLOT)
	if returned.chapter != home.chapter or SaveGame.world_of(returned) != SaveGame.world_of(home):
		return "guest rescue changed home geography or story"
	if SaveGame.character_of(returned).rescued_pets != ["spore_pup", "ash_crow"]:
		return "guest rescue did not write home in the character record"
	game.load_save(SLOT)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if Wildlife.count(game) != 2 or not game.get_flag("sq_kept_rescue_ash_crow"):
		return "solo resume let old home flags erase the new guest rescue"
	var sanctuary := -1
	for i in game.zones.size():
		if String(game.zones[i].get("name", "")) == "Stillwater Reach":
			sanctuary = i
			break
	if sanctuary < 0:
		return "Stillwater sanctuary missing"
	p.global_position = game.room_center(sanctuary)
	game._enter_room(sanctuary)
	await skip_dialogue()
	await sim_wait(4.0)
	game.camera.global_position = p.global_position
	var spot: Node2D = null
	for node in get_tree().get_nodes_in_group("wildlife_spots"):
		if node.game == game and int(node.zone) == sanctuary:
			spot = node
			break
	if spot == null:
		return "home sanctuary node missing"
	spot._refresh()
	if spot.animals.size() != 1 or spot.animals[0].get_meta("pet_id") != "ash_crow":
		return "guest's rescued crow did not join the real sanctuary residents"
	p.global_position = spot.global_position + Vector2(-120, 60)
	game.camera.global_position = p.global_position
	await sim_wait(1.0)
	shot("guest_rescue_joins_home_sanctuary")
	preload("res://scripts/ui/sanctuary.gd").open(game.menus)
	await frames(3)
	shot("both_rescues_remembered_at_home")
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	preload("res://scripts/ui/sanctuary.gd").open(game.menus)
	await frames(3)
	shot("touch_personal_sanctuary")
	game.menus.close()
	SaveGame.write(game, SLOT)
	game.load_save(SLOT)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if Wildlife.count(game) != 2 or Wildlife.claim(game, "ash_crow"):
		return "second solo reload lost or repeated a rescue"
	# Old files have only home flags; the normal load path must preserve them.
	var legacy := home.duplicate(true)
	legacy.character.erase("rescued_pets")
	if not SaveGame.atomic_store(SaveGame.path(SLOT), JSON.stringify(legacy)):
		return "legacy home fixture write failed"
	game.load_save(SLOT)
	game.save_slot = -1
	p.set_physics_process(false)
	await frames(4)
	if Wildlife.count(game) != 1 or not Wildlife.rescued(game, "spore_pup") or Wildlife.rescued(game, "ash_crow"):
		return "legacy migration used account ownership or the previous live hero instead of home flags"
	preload("res://scripts/ui/sanctuary.gd").open(game.menus)
	await frames(3)
	shot("legacy_home_history_preserved")
	return ""


func _foreign_world() -> String:
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "RescueHost"
	gr.name = "RescueGuest"
	add_child(hr)
	add_child(gr)
	var ha := MultiplayerAPI.create_default_interface()
	var ga := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(ha, hr.get_path())
	get_tree().set_multiplayer(ga, gr.get_path())
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var error := ""
	if server.create_server(0, 2) != OK:
		error = "rescue ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "rescue ENet connect failed"
		else:
			ga.multiplayer_peer = client
	var host := WireSession.new()
	var guest := WireSession.new()
	host.name = "Session"
	guest.name = "Session"
	guest.game = game
	guest.local_char = {"slot": SLOT}
	hr.add_child(host)
	gr.add_child(guest)
	var peer_before := game.player.peer_id
	if error == "":
		var deadline := Time.get_ticks_msec() + 4000
		while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.02).timeout
		if ha.get_peers().is_empty():
			error = "rescue ENet handshake timed out"
		else:
			hr.peers[ga.get_unique_id()] = {}
			host._rpc_world_snapshot.rpc_id(ga.get_unique_id(), {"chapter": "ch2", "wander_seed": 555,
				"flags": {"sq_kept_rescue_ash_crow": true, "qa_host_story": true},
				"boss_done": {}, "merchant_zones": [], "spawn_room": 0})
			deadline = Time.get_ticks_msec() + 12000
			while not guest.world_ready and Time.get_ticks_msec() < deadline:
				await get_tree().create_timer(0.02).timeout
			if not guest.world_ready or game.chapter_id != "ch2" or not game.get_flag("qa_host_story"):
				error = "real world snapshot did not finish rebuilding the host's world"
	client.close()
	server.close()
	ha.multiplayer_peer = null
	ga.multiplayer_peer = null
	get_tree().set_multiplayer(null, hr.get_path())
	get_tree().set_multiplayer(null, gr.get_path())
	hr.queue_free()
	gr.queue_free()
	game.player.peer_id = peer_before
	game.guest_world = false
	game.save_slot = -1
	return error
