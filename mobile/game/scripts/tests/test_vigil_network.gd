extends RefCounted
const Vigil := preload("res://scripts/ward_vigil.gd")

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


static func run(rig: Node, ward: Node2D) -> String:
	var g: Game = rig.game
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "VigilHost"
	gr.name = "VigilGuest"
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
		error = "vigil ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "vigil ENet connect failed"
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
	mirror_game.zone_scenery = {ward.zone: []}
	mirror_game.cur_room = ward.zone
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
	ward.set_physics_process(false)
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await rig.get_tree().create_timer(0.02).timeout
		if ha.get_peers().is_empty():
			error = "vigil ENet handshake timed out"
		else:
			hr.peers[ga.get_unique_id()] = {}
			g.player.peer_id = ga.get_unique_id()
			error = await _roundtrip(rig, host, guest, ward, mirror_game)
	ward.cancel("")
	ward.set_physics_process(true)
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


static func _roundtrip(rig: Node, host: Node, guest: Node, ward: Node2D, g: Game) -> String:
	var mirror := Vigil.install(g, ward.zone)
	mirror.set_physics_process(false)
	guest.request_vigil("start")
	await rig.sim_wait(0.2)
	if ward.phase != 1:
		return "guest could not start the host ward"
	host.host_vigil_state(ward)
	await rig.sim_wait(0.2)
	if mirror.phase != 1 or mirror.arrival_points.size() != 2:
		return "host ward warning did not arrive on guest"
	mirror._physics_process(10.0)
	if mirror.phase != 1 or not mirror.enemies.is_empty():
		return "guest simulated its own wave"
	ward.apply_state(2, 2, 62.0, 0.0, true, 1, [])
	host._send_vigil_state(ward, guest.multiplayer.get_unique_id())
	await rig.sim_wait(0.2)
	if mirror.phase != 2 or mirror.wave != 2 or mirror.integrity != 62.0:
		return "mid-wave join refresh lost ward state"
	guest.rpc_id(1, "_rpc_flag_to_host", Vigil.DONE, true)
	await rig.sim_wait(0.2)
	if rig.game.get_flag(Vigil.DONE, false):
		return "guest forged ward completion"
	guest.request_vigil("stop")
	await rig.sim_wait(0.2)
	if ward.phase != 0:
		return "guest could not snuff the host ward"
	var p: Player = rig.game.player
	var old_pos := p.global_position
	p.global_position = ward.global_position + Vector2(400, 0)
	guest.request_vigil("start")
	await rig.sim_wait(0.2)
	p.global_position = old_pos
	if ward.phase != 0:
		return "a distant guest started the vigil"
	print("ok: real ENet vigil request/state, arrival points, late-join refresh, mirror authority, completion forgery and reach checks")
	return ""
