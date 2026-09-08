extends ShotRig
## Real ENet join/reward/victory, home persistence, city construction and legacy saves.
const SLOT := 95
var report := {}

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
				error = "could not restore personal-history diagnostic fixture"
			else:
				output.store_buffer(files[file])
				output.close()
	print("PERSONAL HISTORY LIVE: ", JSON.stringify(report))
	if error != "":
		push_error(error)
		shot("diagnostic_failure")
		return finish(1)
	print("ok: personal history live: actual ENet first-timer/veteran joins, duplicate and reconnect claims, victory autosave, home world, city NPC construction, touch and legacy recovery")
	finish()


func _checks() -> String:
	game.dev_god = true
	game.settings["camera_shake"] = 0.0
	game.camera.position_smoothing_enabled = false
	game.player.set_physics_process(false)
	game.flags = {"owned_the_harm": true, "cap_voss_reported": true,
		"sq_kept_oak_debt": true, "qa_home_world": true}
	game.achievements = {}
	SaveGame.write(game, SLOT)
	var home := SaveGame.read(SLOT)
	var error := await _visit(true, "first_timer")
	if error != "":
		return error
	if game.get_flag("completed_ch1") or report.first_timer_spoils != 1 \
		or report.first_timer_repeated_spoils != 0:
		return "first-timer inherited veteran completion or failed to receive exactly one package"
	if not game.get_flag("cap_voss_reported") or game.get_flag("cap_voss_covered") \
		or game.get_flag("cache_0") or game.get_flag("hidden_0") or game.get_flag("shrined_0"):
		return "host personal choices or per-head cache claims leaked into guest world"
	game.menus.open_mailbox()
	await frames(3)
	shot("01_first_timer_gets_own_spoils")
	game.menus.close()
	game.set_flag("sq_kept_flame_lit", true)
	SaveGame.write_character_home(game, SLOT)
	var returned := SaveGame.read(SLOT)
	if SaveGame.world_of(returned) != SaveGame.world_of(home):
		return "new guest history rewrote the home world"
	game.load_save(SLOT)
	game.save_slot = -1
	game.player.set_physics_process(false)
	await frames(3)
	if not game.get_flag("sq_kept_flame_lit") or not game.get_flag("first_clear_paid_ch1"):
		return "pre-victory solo resume lost personal promise or first-clear reservation"
	# Rejoin before completion: the paid flag, rather than completed_, must
	# suppress a second award. Then the real victory RPC must autosave credit.
	error = await _visit(true, "reconnect", "ch1", true)
	if error != "":
		return error
	if report.reconnect_spoils != 0 or not report.victory_saved_completion:
		return "reconnect duplicated spoils or real victory autosave lost personal credit"
	returned = SaveGame.read(SLOT)
	if SaveGame.world_of(returned) != SaveGame.world_of(home):
		return "victory autosave copied the host's world home"
	game.load_save(SLOT)
	game.save_slot = -1
	game.player.set_physics_process(false)
	await frames(3)
	if not game.get_flag("completed_ch1") or not game.get_flag("sq_kept_flame_lit"):
		return "solo resume erased co-op completion or kept promise"
	# Reverse the pair: the same veteran now joins a first-timer's host world.
	error = await _visit(false, "veteran")
	if error != "":
		return error
	if not game.get_flag("completed_ch1") or report.veteran_spoils != 0:
		return "veteran lost own completion or received duplicate first-clear spoils"
	game.menus.open_mailbox()
	await frames(3)
	shot("03_veteran_keeps_single_spoils_letter")
	game.menus.close()
	# Restore personal choices BEFORE constructing the host's city. This is
	# the actual authored Voss replacement, not merely a saved boolean check.
	error = await _visit(false, "capital", "capital")
	if error != "":
		return error
	var clerk: Node2D
	for entry in game.interactables:
		var node = entry.get("node")
		if is_instance_valid(node):
			if node.get_meta("quest_convo", "") == "cap_voss":
				return "city built the host's original Voss instead of the guest's replacement"
			if node.get_meta("quest_convo", "") == "cap_voss_cold":
				clerk = node
	if clerk == null:
		return "guest's personal city replacement was not built"
	game.player.global_position = clerk.global_position + Vector2(-65, 55)
	game.camera.global_position = game.player.global_position
	await sim_wait(0.3)
	shot("04_own_city_choice_built_on_join")
	game.run_convo_id("cap_voss_cold")
	await frames(3)
	shot("05_personal_alms_clerk")
	await skip_dialogue()
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.menus.open_codex("coop")
	await frames(3)
	shot("06_touch_coop_reference")
	game.menus.close()
	# An old guest file can have its OWN achievement, but no completed_ in
	# its home world. Legacy migration recovers that credit, not account meta.
	var legacy := home.duplicate(true)
	legacy.character.erase("history_flags")
	legacy.character.achievements = ["clear_ch1"]
	if not SaveGame.atomic_store(SaveGame.path(SLOT), JSON.stringify(legacy)):
		return "could not create legacy personal-history live fixture"
	game.load_save(SLOT)
	game.save_slot = -1
	game.player.set_physics_process(false)
	await frames(3)
	if not game.get_flag("completed_ch1") or not game.get_flag("cap_voss_reported") \
		or game.get_flag("cap_voss_covered") or game.get_flag("sq_kept_flame_lit"):
		return "legacy recovery inherited live state or lost own historical evidence"
	shot("07_legacy_own_history_recovers")
	return ""


func _visit(host_completed: bool, label: String, chapter := "ch1", victory := false) -> String:
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "HistoryHost"
	gr.name = "HistoryGuest"
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
		error = "personal-history ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "personal-history ENet connect failed"
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
			error = "personal-history ENet handshake timed out"
		else:
			hr.peers[ga.get_unique_id()] = {}
			var flags := {"cap_voss_covered": true, "qa_host_world": true,
				"cache_0": true, "hidden_0": true, "shrined_0": true}
			if host_completed:
				flags["completed_" + chapter] = true
			host._rpc_world_snapshot.rpc_id(ga.get_unique_id(), {"chapter": chapter, "wander_seed": 555,
				"flags": flags, "boss_done": {}, "merchant_zones": [], "spawn_room": 0})
			deadline = Time.get_ticks_msec() + 12000
			while not guest.world_ready and Time.get_ticks_msec() < deadline:
				await get_tree().create_timer(0.02).timeout
			if not guest.world_ready or not game.get_flag("qa_host_world"):
				error = "personal-history snapshot did not finish rebuilding host world"
			else:
				await skip_dialogue()
				game.player.set_physics_process(false)
				if chapter != "capital":
					var mail_before := game.mailbox.size()
					host._rpc_first_clear.rpc_id(ga.get_unique_id(), 10)
					await get_tree().create_timer(0.2).timeout
					report[label + "_spoils"] = game.mailbox.size() - mail_before
					mail_before = game.mailbox.size()
					host._rpc_first_clear.rpc_id(ga.get_unique_id(), 10)
					host._rpc_first_clear.rpc_id(ga.get_unique_id(), 10)
					await get_tree().create_timer(0.2).timeout
					report[label + "_repeated_spoils"] = game.mailbox.size() - mail_before
					if int(report[label + "_repeated_spoils"]) != 0:
						error = "duplicate first-clear RPCs paid again"
				if victory and error == "":
					game.no_saves = false  # real autosave into this rig's isolated slot
					host._rpc_victory.rpc_id(ga.get_unique_id(), "The road remembers your company.", true)
					await get_tree().create_timer(0.2, true).timeout
					game.no_saves = true
					report["victory_saved_completion"] = SaveGame.character_of(SaveGame.read(SLOT)).get("history_flags", {}).get("completed_ch1", false)
					await frames(3)
					shot("02_real_victory_banks_personal_credit")
					await skip_dialogue()
					await sim_wait(0.6)
					if game.state != Game.ST_VICTORY:
						error = "personal illustrated ending did not finish at its results card"
					game.request_pause(false)
					game.state = Game.ST_PLAYING
					game.hud.hide_results()
					game.hud.overlay.color = Color(0, 0, 0, 0)

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
	await frames(2)
	return error
