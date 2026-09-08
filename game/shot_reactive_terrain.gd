extends ShotRig
const Terrain := preload("res://scripts/reactive_terrain.gd")
var sequence := 100

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool:
		return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass

# A presentation world for the second ENet subtree. No second game boot or
# enemy simulation: production props and production receivers remain real.
class WireGame extends Game:
	func _ready() -> void:
		set_process(false)
	func net_guest() -> bool:
		return true
	func net_host() -> bool:
		return false
	func net_apply_flag(flag_name: String, value) -> void:
		flags[flag_name] = value
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void:
		pass
	func burst(_pos: Vector2, _color: Color, _count := 10) -> void:
		pass


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.play_started = true
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	var p: Player = game.local_player
	p.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	await sim_wait(1.0)
	shot("darkwood_natural_placement")
	var count := 0
	for prop in get_tree().get_nodes_in_group("reactive_terrain"):
		if prop.zone == 2:
			count += 1
	print("TERRAIN PLACEMENT: darkwood objects=%d" % count)
	if count != Balance.REACTIVE_PER_ROOM:
		push_error("terrain weapons did not populate the first combat room")
		finish(1)
		return
	await _clear()
	apply_terrain("keep", 2)
	await sim_wait(3.0)
	await _clear()
	p.global_position = game.room_center(2)
	p.set_physics_process(false)
	var error := await _live_checks()
	if error == "":
		error = await _wire_checks()
	if error != "":
		push_error(error)
		finish(1)
		return
	await sim_wait(1.0)
	print("ok: live melee/projectile terrain, damage and chill, chain fuses, pause, spent rebuild, touch and production ENet requests/states")
	finish()


func _clear() -> void:
	for group in ["enemies", "projectiles", "reactive_terrain"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	game.cancel_ground_attacks()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	game.bosses.clear()
	game.current_boss = null
	await frames(2)


func _prop(kind: String, offset: Vector2) -> StaticBody2D:
	sequence += 1
	return Terrain.install(game, 2, sequence, kind, game.room_center(2) + offset)


func _mob(offset: Vector2) -> Enemy:
	var e := Enemy.make(game, "wolf", game.room_center(2) + offset, 3)
	game.world.add_child(e)
	e.set_physics_process(false)
	e.hp = 1000.0
	e.max_hp = 1000.0
	e.dmg = 0.0
	e.zone_idx = 2
	return e


func _live_checks() -> String:
	var p: Player = game.local_player
	var origin := game.room_center(2)
	var cask := _prop("ember", Vector2(65, 0))
	var chain := _prop("ember", Vector2(250, -30))
	var victim := _mob(Vector2(160, -150))
	p.facing = Vector2.RIGHT
	p.locked_target = null
	p.soft_target = null
	await sim_wait(0.2)
	shot("ember_cask_inspect")
	p._melee_arc(0.0, 200.0, "slash")
	if cask.phase != 1 or chain.phase != 0:
		return "melee contact failed to prime only the reached cask"
	p.global_position = origin + Vector2(-190, 65)
	await sim_wait(0.35)
	shot("ember_fuse")
	game.request_pause(true)
	var frozen: float = cask.remaining
	await get_tree().create_timer(0.25, true).timeout
	if cask.remaining != frozen:
		game.request_pause(false)
		return "pause advanced a terrain fuse"
	game.request_pause(false)
	await sim_wait(cask.remaining + 0.05)
	if cask.phase != 2 or chain.phase != 1 or victim.hp >= 1000.0:
		return "cask blast did not damage the pack and start a fresh chain fuse"
	if chain.remaining < Balance.REACTIVE_FUSE - 0.2:
		return "chain reaction skipped the second object's warning"
	shot("chain_reaction")
	var after_first := victim.hp
	cask.detonate()
	if victim.hp != after_first:
		return "terrain applied its explosion twice"
	await sim_wait(1.6)
	shot("spent_casks")
	await _clear()
	p.global_position = origin + Vector2(-200, 70)
	var ice := _prop("rime", Vector2(90, 0))
	var chilled := _mob(Vector2(150, -100))
	var outside := _mob(Vector2(380, -100))
	var shot_from := origin + Vector2(-100, 0)
	var proj := Projectile.spawn(game, shot_from, Vector2(350, 0), 0.0, true, "arrow")
	proj.source_player = p
	proj.hit_player_mult = 0.0
	await sim_wait(0.7)
	if ice.phase != 1:
		return "real projectile collision failed to prime the crystal"
	shot("rimeheart_fuse")
	await sim_wait(ice.remaining + 0.06)
	if chilled.hp >= 1000.0 or chilled.slow_time <= 0.0 or outside.hp != 1000.0:
		return "frost damage, chill or blast radius was incorrect"
	shot("frost_burst")
	await _clear()
	var touch := _prop("rime", Vector2(65, 0))
	p.global_position = origin
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await sim_wait(0.2)
	shot("touch_terrain_action")
	if not game.interact_in_range or not touch.prompt.visible or touch.prompt.text.begins_with("E"):
		return "touch terrain action or device-appropriate prompt did not appear"
	game.menus.open_pause()
	touch.interact()
	if touch.phase != 0:
		return "terrain activated under an input overlay"
	game.menus.close()
	touch.interact()
	if touch.phase != 1:
		return "normal terrain interaction failed"
	# Check the player path with controlled evasion/shields, including chill.
	p.eva = 0.0
	p.shield = 0.0
	p.hurt_cd = 0.0
	p.hp = p.max_hp
	await sim_wait(1.6)
	if p.hp >= p.max_hp or p.chill_time <= 0.0:
		return "terrain blast could not hurt/chill the standing player"
	p.hp = p.max_hp
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await _clear()
	return ""


func _wire_checks() -> String:
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "TerrainHost"
	gr.name = "TerrainGuest"
	add_child(hr)
	add_child(gr)
	var ha := MultiplayerAPI.create_default_interface()
	var ga := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(ha, hr.get_path())
	get_tree().set_multiplayer(ga, gr.get_path())
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	if server.create_server(0, 2) != OK:
		return "terrain ENet bind failed"
	ha.multiplayer_peer = server
	if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
		return "terrain ENet connect failed"
	ga.multiplayer_peer = client
	var host := WireSession.new()
	var guest := WireSession.new()
	host.name = "Session"
	guest.name = "Session"
	host.game = game
	var mirror_game := WireGame.new()
	mirror_game.chapter_id = game.chapter_id
	mirror_game.zone_scenery = {2: []}
	mirror_game.world = Node2D.new()
	gr.add_child(mirror_game)
	mirror_game.add_child(mirror_game.world)
	mirror_game.world.visible = false
	guest.game = mirror_game
	guest.world_ready = true
	hr.add_child(host)
	gr.add_child(guest)
	var deadline := Time.get_ticks_msec() + 3000
	while (client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or ha.get_peers().is_empty()) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	var error := ""
	if ha.get_peers().is_empty():
		error = "terrain ENet handshake timed out"
	else:
		hr.peers[ga.get_unique_id()] = {}
		error = await _wire_roundtrip(host, guest, mirror_game)
	client.close()
	server.close()
	ha.multiplayer_peer = null
	ga.multiplayer_peer = null
	get_tree().set_multiplayer(null, hr.get_path())
	get_tree().set_multiplayer(null, gr.get_path())
	hr.queue_free()
	gr.queue_free()
	await _clear()
	return error


func _wire_roundtrip(host: Node, guest: Node, mirror_game: Game) -> String:
	var p: Player = game.local_player
	var saved_peer := p.peer_id
	p.peer_id = guest.multiplayer.get_unique_id()
	var prop := _prop("ember", Vector2(65, 0))
	prop.set_physics_process(false)
	var mirror := Terrain.install(mirror_game, 2, prop.slot, "ember", Vector2.ZERO)
	mirror.set_physics_process(false)
	guest.request_terrain_prime(prop.key, "interact")
	await sim_wait(0.25)
	var error := ""
	if prop.phase != 1:
		error = "guest interaction failed to prime host terrain"
	host.host_terrain_state(prop)
	await sim_wait(0.25)
	if mirror.phase != 1 or not mirror_game.get_flag(prop.key, false):
		error = "host fuse did not reach the real guest prop"
	# Mirrors cannot decide the blast when their interpolated clock reaches zero.
	mirror._physics_process(5.0)
	if mirror.phase != 1 or mirror.prime():
		error = "guest terrain authored its own blast"
	prop.apply_state(2, 0.0)
	host.host_terrain_state(prop)
	await sim_wait(0.25)
	if mirror.phase != 2:
		error = "host detonation did not reach the guest"
	# Late join: saved reservation first, authoritative live fuse second.
	var late_key := "reactive_%s_2_998" % game.chapter_id
	mirror_game.flags[late_key] = true
	var late := Terrain.install(mirror_game, 2, 998, "rime", Vector2.ZERO)
	late.set_physics_process(false)
	host.rpc("_rpc_terrain_state", game.chapter_id, late_key, 1, 0.8)
	await sim_wait(0.25)
	if late.phase != 1 or not is_equal_approx(late.remaining, 0.8):
		error = "late join failed to restore the reserved prop's active fuse"
	host.rpc("_rpc_terrain_state", game.chapter_id, late_key, 2, 0.0, true)
	await sim_wait(0.2)
	if late.phase != 2 or late.pop_age < Balance.REACTIVE_POP_TIME:
		error = "settled join snapshot replayed an old explosion"
	var rejected := _prop("ember", Vector2(500, 0))
	rejected.set_physics_process(false)
	guest.request_terrain_prime(rejected.key, "interact")
	await sim_wait(0.2)
	if rejected.phase != 0:
		error = "guest interaction reached a distant prop"
	p.peer_id = saved_peer
	return error
