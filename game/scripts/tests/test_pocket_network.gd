extends RefCounted
const Trial := preload("res://scripts/pocket_trial.gd")

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class WireGame extends Game:
	var awards := 0
	func _ready() -> void: set_process(false)
	func net_guest() -> bool: return true
	func net_host() -> bool: return false
	func autosave() -> void: pass
	func _pocket_reward(_at: Vector2) -> void: awards += 1


static func run(rig: Node, trial: Node2D) -> String:
	var g: Game = rig.game
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "PocketHost"
	gr.name = "PocketGuest"
	rig.add_child(hr)
	rig.add_child(gr)
	var ha := MultiplayerAPI.create_default_interface()
	var ga := MultiplayerAPI.create_default_interface()
	rig.get_tree().set_multiplayer(ha, hr.get_path())
	rig.get_tree().set_multiplayer(ga, gr.get_path())
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var error := ""
	if server.create_server(0, 2) != OK:
		error = "pocket ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "pocket ENet connect failed"
		else:
			ga.multiplayer_peer = client
	var host := WireSession.new()
	var guest := WireSession.new()
	host.name = "Session"
	guest.name = "Session"
	host.game = g
	var mirror_game := WireGame.new()
	mirror_game.chapter_id = g.chapter_id
	mirror_game.zones = g.zones.duplicate(true)
	mirror_game.rooms = g.rooms.duplicate(true)
	mirror_game.zone_count = g.zone_count
	mirror_game.zone_scenery = {trial.zone: []}
	mirror_game.cur_room = trial.zone
	mirror_game.pocket_room = g.pocket_room
	mirror_game.pocket_id = g.pocket_id
	mirror_game.world = Node2D.new()
	gr.add_child(mirror_game)
	mirror_game.add_child(mirror_game.world)
	mirror_game.world.visible = false
	guest.game = mirror_game
	guest.world_ready = true
	hr.add_child(host)
	gr.add_child(guest)
	var saved_peer := g.player.peer_id
	var saved_pos := g.player.global_position
	var saved_clock := [trial.phase, trial.side, trial.remaining]
	var processing := trial.is_physics_processing()
	trial.set_physics_process(false)
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await rig.get_tree().create_timer(0.02).timeout
		if ha.get_peers().is_empty():
			error = "pocket ENet handshake timed out"
		else:
			hr.peers[ga.get_unique_id()] = {}
			host.peer_chars[ga.get_unique_id()] = {}
			g.player.peer_id = ga.get_unique_id()
			error = await _roundtrip(rig, host, guest, trial, mirror_game)
	g.player.peer_id = saved_peer
	g.player.global_position = saved_pos
	trial.apply_state(int(saved_clock[0]), int(saved_clock[1]), float(saved_clock[2]))
	trial.set_physics_process(processing)
	client.close()
	server.close()
	ha.multiplayer_peer = null
	ga.multiplayer_peer = null
	rig.get_tree().set_multiplayer(null, hr.get_path())
	rig.get_tree().set_multiplayer(null, gr.get_path())
	hr.queue_free()
	gr.queue_free()
	if error == "":
		print("ok: real ENet pocket clock before lazy build, guest presentation only, malformed/stale state rejection, participant reward once and absent-party exclusion")
	return error


static func _roundtrip(rig: Node, host: Node, guest: Node, trial: Node2D, g: WireGame) -> String:
	var pid: int = guest.multiplayer.get_unique_id()
	trial.apply_state(1, 1, 2.5)
	host.host_pocket_state(trial, pid)
	await rig.sim_wait(0.15)
	if g.pocket_clock.is_empty():
		return "clock vanished before guest built the arena"
	var mirror := Trial.install(g, g.pocket_room)
	if mirror.phase != 1 or mirror.side != 1 or mirror.remaining < 2.0:
		return "late arena build missed cached phase"
	trial.apply_state(2, 0, 0.05)
	host.host_pocket_state(trial, pid)
	await rig.sim_wait(0.15)
	if mirror.phase != 2 or mirror.side != 0 or mirror.remaining > 0.01:
		return "guest clock did not present the host or advanced phase itself"
	for bad in [NAN, INF, -2.0, 9999.0]:
		host._rpc_pocket_clock.rpc_id(pid, g.chapter_id, g.pocket_id, 1, 1, bad)
	host._rpc_pocket_clock.rpc_id(pid, "wrong_chapter", g.pocket_id, 1, 1, 2.0)
	host._rpc_pocket_clock.rpc_id(pid, g.chapter_id, "wrong_pocket", 1, 1, 2.0)
	await rig.sim_wait(0.15)
	if mirror.phase != 2 or mirror.side != 0:
		return "malformed or stale pocket clock accepted"
	host._rpc_pocket_settled.rpc_id(pid, g.chapter_id, g.pocket_id, Vector2(INF, 0), true)
	await rig.sim_wait(0.1)
	if g.pocket_done:
		return "invalid settlement position accepted"
	rig.game.player.global_position = rig.game.room_center(trial.zone)
	host.host_pocket_complete(rig.game.room_center(trial.zone))
	await rig.sim_wait(0.15)
	if not g.pocket_done or g.awards != 1:
		return "present guest did not receive exactly one pocket reward"
	host.host_pocket_complete(rig.game.room_center(trial.zone))
	await rig.sim_wait(0.15)
	if g.awards != 1:
		return "duplicate settlement paid twice"
	g.pocket_done = false
	g.awards = 0
	rig.game.player.global_position = rig.game.room_center(Trial.source_room(rig.game))
	host.host_pocket_complete(rig.game.room_center(trial.zone))
	await rig.sim_wait(0.15)
	if not g.pocket_done or g.awards != 0:
		return "absent guest earned a reward or missed world completion"
	return ""
