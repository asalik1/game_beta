extends RefCounted
const Escort := preload("res://scripts/wayfarer.gd")

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class WireGame extends Game:
	func _ready() -> void: set_process(false)
	func net_guest() -> bool: return true
	func net_host() -> bool: return false
	func net_apply_flag(key: String, value) -> void: flags[key] = value


static func run(rig: Node, escort: Node2D) -> String:
	var g: Game = rig.game
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "EscortHost"
	gr.name = "EscortGuest"
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
		error = "escort ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "escort ENet connect failed"
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
	mirror_game.zone_scenery = {escort.zone: []}
	mirror_game.cur_room = escort.zone
	mirror_game.world = Node2D.new()
	gr.add_child(mirror_game)
	mirror_game.add_child(mirror_game.world)
	mirror_game.world.visible = false
	guest.game = mirror_game
	guest.world_ready = true
	hr.add_child(host)
	gr.add_child(guest)
	var saved_peer := g.player.peer_id
	var saved_flags := g.flags.duplicate(true)
	escort.set_physics_process(false)
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await rig.get_tree().create_timer(0.02).timeout
		if ha.get_peers().is_empty():
			error = "escort ENet handshake timed out"
		else:
			hr.peers[ga.get_unique_id()] = {}
			g.player.peer_id = ga.get_unique_id()
			error = await _roundtrip(rig, host, guest, escort, mirror_game)
	escort.cancel("")
	escort.set_physics_process(true)
	g.player.peer_id = saved_peer
	g.flags = saved_flags
	client.close()
	server.close()
	ha.multiplayer_peer = null
	ga.multiplayer_peer = null
	rig.get_tree().set_multiplayer(null, hr.get_path())
	rig.get_tree().set_multiplayer(null, gr.get_path())
	hr.queue_free()
	gr.queue_free()
	return error


static func _roundtrip(rig: Node, host: Node, guest: Node, escort: Node2D, g: Game) -> String:
	var mirror := Escort.install(g, escort.zone)
	mirror.set_physics_process(false)
	guest.request_escort("start")
	await rig.sim_wait(0.2)
	if escort.phase != 1:
		return "guest could not begin the escort"
	host.host_escort_state(escort)
	await rig.sim_wait(0.2)
	if mirror.phase != 1:
		return "host escort start did not reach guest"
	guest.request_escort("wait")
	await rig.sim_wait(0.2)
	if not escort.waiting:
		return "guest wait order was lost"
	guest.request_escort("follow")
	await rig.sim_wait(0.2)
	if escort.waiting:
		return "guest follow order was lost"
	var at: Vector2 = escort.start.lerp(escort.goal, 0.4)
	escort.apply_state(2, 1, 68.0, 2.0, false, true, 0, at, false, [at + Vector2(0, -200)])
	host._send_escort_state(escort, guest.multiplayer.get_unique_id())
	await rig.sim_wait(0.2)
	if mirror.phase != 2 or mirror.stage != 1 or mirror.resolve != 68.0 or mirror.arrival_points.size() != 1:
		return "mid-escort join refresh lost position/warning/resolve"
	mirror._physics_process(10.0)
	if mirror.phase != 2 or not mirror.enemies.is_empty():
		return "guest simulated its own pursuers"
	if mirror.global_position.distance_to(at) > 1.0:
		return "guest did not interpolate to the host position"
	guest.rpc_id(1, "_rpc_flag_to_host", Escort.DONE, true)
	await rig.sim_wait(0.2)
	if rig.game.get_flag(Escort.DONE, false):
		return "guest forged escort completion"
	var p: Player = rig.game.player
	var saved_position := p.global_position
	p.global_position = escort.global_position + Vector2(0, 50)
	guest.request_escort("stop")
	await rig.sim_wait(0.2)
	if escort.phase != 0:
		p.global_position = saved_position
		return "guest could not stop escort"
	p.global_position = escort.global_position + Vector2(400, 0)
	guest.request_escort("start")
	await rig.sim_wait(0.2)
	p.global_position = saved_position
	if escort.phase != 0:
		return "distant guest started escort"
	print("ok: real ENet escort start/wait/follow/stop, position interpolation, warning/resolve join state, guest simulation isolation, forged completion and reach")
	return ""
