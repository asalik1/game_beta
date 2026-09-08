extends ShotRig
## Two complete playable worlds plus a lightweight late-reader roster, ONE engine.
const Appearance := preload("res://scripts/net/net_appearance.gd")
const SLOT := 97
var roots: Array[Node] = []
var apis: Array[MultiplayerAPI] = []
var wires: Array[Node] = []
var readers: Array[Game] = []
var screens: Array[SubViewportContainer] = []
var transports: Array[ENetMultiplayerPeer] = []
var report := {}

class PartyGame extends Game:
	var qa_online := false
	var qa_bridge: Node
	func net_online() -> bool: return qa_online
	func net_session() -> Node: return qa_bridge

class ObserverGame extends Game:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func register_remote_player(p: Player) -> void:
		super(p)
		p.set_physics_process(false)

class WireRoot extends Node:
	var peers := {}
	var online := true
	func is_online() -> bool: return online

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	# Normal production cadence/movement. Only ghost auto-recovery is disabled
	# so the explicit ghost assertion can observe it in an otherwise safe room.
	func _host_down_sweep() -> void: pass


func _ready() -> void:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	var error := await _checks()
	if error == "" and report.is_empty():
		error = "appearance checks did not reach their completion record"
	if error != "":
		shot("diagnostic_before_cleanup")
	_key(false)
	get_tree().paused = false
	for i in readers.size():
		readers[i].qa_online = false
		readers[i].no_saves = true
		readers[i].save_slot = -1
		readers[i].guest_world = false
		wires[i].set_physics_process(false)
		roots[i].online = false
	for transport in transports:
		transport.close()
	for i in apis.size():
		apis[i].multiplayer_peer = null
		get_tree().set_multiplayer(null, roots[i].get_path())
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				error = "could not restore appearance save fixture"
			else:
				output.store_buffer(files[path])
				output.close()
	print("PARTY APPEARANCE LIVE: ", JSON.stringify(report))
	if error != "":
		push_error(error)
		return finish(1)
	print("ok: party appearance live ENet join/change/late roster, owner movement/stride, menu clocks, ghost/revive, travel/rebuild, replacement/reconnect/disconnect, local identity/account/home preservation")
	finish()


func _reader(cls: String, label: String) -> void:
	step("boot " + label)
	var screen := SubViewportContainer.new()
	screen.size = Vector2(1280, 720)
	add_child(screen)
	screens.append(screen)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	viewport.use_hdr_2d = get_viewport().use_hdr_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	var root := WireRoot.new()
	root.name = label
	viewport.add_child(root)
	roots.append(root)
	var reader := PartyGame.new()
	reader.name = "Game"
	reader.y_sort_enabled = true
	reader.no_saves = true
	root.add_child(reader)
	readers.append(reader)
	game = reader
	await frames(10)
	reader.menus.shell_motion = false
	reader.menus.pick_chapter("ch1")
	await frames(3)
	reader.menus.pick_class(cls)
	await frames(5)
	await skip_dialogue()
	reader.dev_god = true
	reader.settings["camera_shake"] = 0.0
	reader.settings["combat_framing"] = false
	reader.player.pending_theme_note = ""
	reader.camera.position_smoothing_enabled = false
	reader.terrain_event_t = 10000.0
	reader.player.set_physics_process(false)
	var api := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(api, root.get_path())
	apis.append(api)
	var wire := WireSession.new()
	wire.name = "Session"
	wire.game = reader
	wire.local_char = {"name": label}
	reader.qa_bridge = wire
	root.add_child(wire)
	wires.append(wire)
	reader.player._net_mgr = root
	api.peer_disconnected.connect(func(pid: int) -> void:
		root.peers.erase(pid)
		wire._on_peer_left(pid))
	var peer := ENetMultiplayerPeer.new()
	transports.append(peer)


func _show(index: int) -> void:
	game = readers[index]
	for i in screens.size():
		screens[i].visible = i == index


func _settle(seconds := 0.7) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.02, true).timeout


func _shell(index: int, pid: int) -> Player:
	for p in readers[index].players:
		if is_instance_valid(p) and p != readers[index].local_player and p.peer_id == pid:
			return p
	return null


func _pet(index: int, owner: Player) -> Sprite2D:
	var visual: Variant = readers[index].remote_pet_followers.get(owner.get_instance_id(), {}).get("visual")
	return visual if is_instance_valid(visual) else null


func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = pressed
	Input.parse_input_event(event)


func _checks() -> String:
	var host: Game = readers[0]
	var guest: Game = readers[1]
	host.player.set_skin("emberbound_heir")
	host.player.set_pet("spore_pup")
	guest.player.set_skin("blighted_healer")
	guest.player.set_pet("hearth_hopper")
	var account_before: Dictionary = guest._meta.duplicate(true)
	SaveGame.write(guest, SLOT)
	var home := SaveGame.read(SLOT)
	if transports[0].create_server(0, 3) != OK:
		return "appearance ENet host bind failed"
	apis[0].multiplayer_peer = transports[0]
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "appearance ENet guest connect failed"
	apis[1].multiplayer_peer = transports[1]
	await _settle()
	if apis[0].get_peers().is_empty():
		return "appearance ENet handshake timed out"
	var pid := apis[1].get_unique_id()
	roots[0].peers[pid] = {}
	roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = pid
	# No appearance publishes until the guest has applied its world snapshot.
	wires[1]._tick_appearance(1.0, guest.player)
	if not wires[1]._appearance_sent.is_empty():
		return "guest sent cosmetics before world readiness"
	for i in 2:
		readers[i].qa_online = true
		wires[i].world_ready = true
	wires[1]._rpc_join_ready.rpc_id(1, wires[1]._char_block())
	await _settle(1.0)
	var remote := _shell(0, pid)
	var host_copy := _shell(1, 1)
	if remote == null or host_copy == null or remote.is_locally_controlled() or host_copy.is_locally_controlled():
		return "join failed to create remotely controlled shells"
	if Appearance.from_player(remote) != Appearance.from_player(guest.player) \
			or Appearance.from_player(host_copy) != Appearance.from_player(host.player):
		return "join lost equipped skin or pet"
	if remote._clips.idle.tex != guest.player._clips.idle.tex or host_copy._clips.idle.tex != host.player._clips.idle.tex:
		return "join retained skin identity without installing its actual sprite clips"
	if not is_instance_valid(_pet(0, remote)) or not is_instance_valid(_pet(1, host_copy)):
		return "join did not create both friends' companions"
	_show(0)
	guest.player.global_position = host.player.global_position + Vector2(145, 65)
	await _settle(1.2)
	shot("01_join_skin_and_companions")
	var vitals := [remote.hp, remote.max_hp, remote.atk, remote.level, remote.gold]
	var local_pet := host.pet_follower
	# Direct assignments (save/dev callers) and setters both take the same sampler.
	guest.player.equipped_pet = "ash_crow"
	guest.player.skin = ""
	guest.player.refresh_skin_sprite()
	await _settle()
	if remote.skin != "" or remote.equipped_pet != "ash_crow" or host.pet_follower != local_pet:
		return "live direct equip lost removal or rebuilt someone else's pet"
	if remote._clips.idle.tex != Art.hero_clips(String(Classes.CLASSES.mage.sprite)).idle.tex:
		return "removing a remote skin left its old body art"
	guest.player.set_skin("blighted_healer")
	guest.player.set_pet("hearth_hopper")
	host.player.set_pet("cinder_bat")
	await _settle()
	if remote.skin != "blighted_healer" or host_copy.equipped_pet != "cinder_bat":
		return "live setter changes did not travel both ways"
	if remote._clips.idle.tex != guest.player._clips.idle.tex:
		return "live skin change did not replace the rendered clip set"
	if [remote.hp, remote.max_hp, remote.atk, remote.level, remote.gold] != vitals:
		return "cosmetic changes altered remote combat stats"
	shot("02_live_appearance_changes")
	# A malformed peer cannot choose another owner or write account/combat data.
	wires[1]._rpc_request_appearance.rpc_id(1, {"skin": [], "pet": {}, "pid": 1, "gold": 999999})
	await _settle(0.2)
	if remote.skin != "" or remote.equipped_pet != "" or host.player.skin != "emberbound_heir":
		return "malformed appearance was not limited to the sending guest"
	wires[1]._appearance_sent = {}
	await _settle()
	# An authority relay aimed at our id must never change our selected appearance.
	wires[0]._rpc_appearance.rpc_id(pid, pid, {"skin": "", "pet": "pale_flutter"})
	await _settle(0.2)
	if guest.player.equipped_pet != "hearth_hopper" or guest.player.skin != "blighted_healer":
		return "relay overwrote the local character"
	var late_error := await _late_join(pid)
	if late_error != "":
		return late_error
	_show(0)
	# Move the real guest using input; production movement packets drive the shell.
	var start := remote.global_position
	var pet_start: Vector2 = _pet(0, remote).global_position
	guest.player.set_physics_process(true)
	_key(true)
	await _settle(0.7)
	_key(false)
	await _settle(0.18)
	guest.player.set_physics_process(false)
	if remote.global_position.distance_to(start) < 40.0 or _pet(0, remote).global_position.distance_to(pet_start) < 20.0:
		return "real owner movement did not move its remote companion"
	shot("03_remote_pet_walk")
	await _settle(1.8)
	if _pet(0, remote).frame != 0:
		return "remote grounded companion walked after its owner stopped"
	# Local menus gate our companion only. A remote still travels and animates.
	host.menus.open_inventory()
	await _settle(0.15)
	var own_age: float = host.pet_follower.age
	var remote_age: float = _pet(0, remote).age
	guest.player.global_position += Vector2(-130, 0)
	await _settle(0.6)
	if host.pet_follower.age != own_age or _pet(0, remote).age <= remote_age:
		return "online local menu stopped remote animation or advanced the local pet"
	shot("04_remote_motion_beneath_local_menu")
	host.menus.close()
	# Stay within the actual room: an out-of-bounds warp invokes the game's
	# corrective clamp and emits a second destination. Allow the real 120ms
	# interpolation buffer and follower frame to settle before measuring.
	var warp_to := guest.play_rect(guest.cur_room).grow(-160).end
	guest.player.global_position = warp_to
	await _settle(1.2)
	if remote.global_position.distance_to(warp_to) > 8.0 \
			or _pet(0, remote).global_position.distance_to(remote.global_position + Balance.PET_FOLLOW_OFFSET) > 24.0:
		return "remote companion trailed across a long warp"
	guest.player.global_position = host.player.global_position + Vector2(150, 65)
	wires[1].send_down_state(1)
	await _settle(0.15)
	if not _pet(0, remote).visible:
		return "living downed owner's companion vanished"
	wires[1].send_down_state(2)
	await _settle(0.15)
	if _pet(0, remote).visible:
		return "ghost owner's companion remained visible"
	wires[1].send_down_state(0)
	await _settle(0.2)
	if not _pet(0, remote).visible:
		return "revived owner's companion failed to return"
	shot("05_companion_returns_after_ghost")
	guest.player.set_pet("")
	await _settle()
	if is_instance_valid(_pet(0, remote)):
		return "unequipping left a remote follower"
	guest.player.set_pet("pale_flutter")
	await _settle()
	# Same-id replacement exercises reconnect-safe owner-instance cleanup.
	var old_visual := _pet(0, remote)
	var old_owner_id := remote.get_instance_id()
	wires[1]._rpc_join_ready.rpc_id(1, wires[1]._char_block())
	await _settle()
	remote = _shell(0, pid)
	print("REPLACEMENT: owner_changed=", remote.get_instance_id() != old_owner_id,
		" old_visual_alive=", is_instance_valid(old_visual),
		" new_visual_alive=", is_instance_valid(_pet(0, remote)),
		" followers=", host.remote_pet_followers.size(), " pet=", remote.equipped_pet)
	# Skin clip installation can occupy a frame on Compatibility. Wait for the
	# observable result, including the following process pass and queued frees.
	var replacement_deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < replacement_deadline:
		remote = _shell(0, pid)
		if remote.get_instance_id() != old_owner_id and not is_instance_valid(old_visual) \
				and is_instance_valid(_pet(0, remote)) and host.remote_pet_followers.size() == 1:
			break
		await get_tree().process_frame
	if is_instance_valid(old_visual) or not is_instance_valid(_pet(0, remote)) or host.remote_pet_followers.size() != 1:
		return "same-id replacement leaked or lost a companion"
	# Compare before travel: reading a NEW chapter can legitimately add gallery
	# entries, while receiving remote cosmetics must leave the account untouched.
	if guest._meta != account_before or SaveGame.read(SLOT) != home:
		return "receiving appearance changed account collection or home save"
	# Actual production host advance -> reliable guest world rebuild.
	var old_world: Node = guest.world
	var old_guest_pet := _pet(1, _shell(1, 1))
	host.switch_chapter("ch2", true)
	wires[0].host_advance_party()
	await _settle(1.0)
	for i in 2:
		_show(i)
		await skip_dialogue()
		readers[i].player.set_physics_process(false)
	await _settle()
	if guest.chapter_id != "ch2" or guest.world == old_world or is_instance_valid(old_guest_pet):
		return "party travel did not replace the guest world/follower"
	if guest.player.equipped_pet != "pale_flutter" or guest.player.skin != "blighted_healer" \
			or not is_instance_valid(_pet(1, _shell(1, 1))):
		return "party travel lost equipped appearance or remote companion"
	# Space the arriving owners so the screenshot can inspect both silhouettes.
	host.player.global_position = host.room_center(host.cur_room) + Vector2(-130, 90)
	guest.player.global_position = guest.room_center(guest.cur_room) + Vector2(100, 90)
	await _settle(1.2)
	_show(1)
	shot("06_guest_travel_keeps_appearance")
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	guest.menus.open_inventory()
	await _settle(0.2)
	if guest._touch_hud == null or guest._touch_hud._enabled:
		return "touch menu did not gate gameplay input"
	var touch_remote: Sprite2D = _pet(1, _shell(1, 1))
	var touch_remote_age: float = touch_remote.age
	var touch_local_age: float = guest.pet_follower.age
	host.player.global_position += Vector2(90, 0)
	await _settle(0.5)
	if touch_remote.age <= touch_remote_age or guest.pet_follower.age != touch_local_age:
		return "touch co-op menu mixed local and remote companion clocks"
	shot("07_touch_menu_and_party")
	guest.menus.close()
	guest.save_slot = SLOT
	guest.no_saves = false
	SaveGame.write_character_home(guest, SLOT)
	var saved := SaveGame.read(SLOT)
	if SaveGame.world_of(saved) != SaveGame.world_of(home) \
			or SaveGame.character_of(saved).get("skin") != "blighted_healer" \
			or SaveGame.character_of(saved).get("equipped_pet") != "pale_flutter":
		return "home save inherited remote appearance or foreign geography"
	# Actual transport disconnect drives the production peer-left callback.
	var leaving := _pet(0, _shell(0, pid))
	wires[1].set_physics_process(false)
	roots[1].online = false
	guest.qa_online = false
	transports[1].close()
	apis[1].multiplayer_peer = null
	await _settle(1.0)
	if _shell(0, pid) != null or is_instance_valid(leaving) or not host.remote_pet_followers.is_empty():
		return "transport disconnect left an owner or companion behind"
	# Production end callback clears the guest roster/cache while preserving home.
	roots[1].online = false
	guest.qa_online = false
	wires[1]._on_session_ended("QA connection closed")
	await frames(3)
	if not wires[1]._appearance_sent.is_empty() or not guest.remote_pet_followers.is_empty():
		return "session teardown retained appearance state"
	_show(0)
	shot("08_disconnect_keeps_local_companion")
	if SaveGame.world_of(SaveGame.read(SLOT)) != SaveGame.world_of(home):
		return "lost-session autosave changed home geography"
	# A fresh transport ID rejoins with the same live character and a clean cache.
	guest.no_saves = true
	guest.save_slot = -1
	guest.guest_world = false
	guest.play_started = true
	guest.state = Game.ST_PLAYING
	guest.menus.close()
	apis[1].multiplayer_peer = null
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "appearance reconnect could not create a fresh client"
	apis[1].multiplayer_peer = transports[1]
	await _settle()
	var returned_pid := apis[1].get_unique_id()
	roots[0].peers[returned_pid] = {}
	roots[1].peers[1] = {}
	roots[1].online = true
	guest.qa_online = true
	guest.player.peer_id = returned_pid
	wires[1].world_ready = true
	wires[1].set_physics_process(true)
	wires[1]._rpc_join_ready.rpc_id(1, wires[1]._char_block())
	await _settle(1.0)
	var returned := _shell(0, returned_pid)
	if returned == null or not is_instance_valid(_pet(0, returned)) \
			or returned.skin != "blighted_healer" or returned.equipped_pet != "pale_flutter" \
			or host.remote_pet_followers.size() != 1:
		return "reconnect lost appearance or retained the previous owner's pet"
	shot("09_reconnected_companion")
	report = {"join": true, "live_changes": true, "late_roster": true, "movement": true,
		"menu_clocks": true, "warp": true, "ghost_revive": true, "replacement": true,
		"travel": true, "touch": true, "home_and_account": true, "disconnect": true, "reconnect": true}
	return ""


func _late_join(first_pid: int) -> String:
	step("third ENet reader joins after live appearance changes")
	var root := WireRoot.new()
	root.name = "LateReader"
	add_child(root)
	roots.append(root)
	var api := MultiplayerAPI.create_default_interface()
	apis.append(api)
	get_tree().set_multiplayer(api, root.get_path())
	var observer := ObserverGame.new()
	# This roster reader shares the root canvas, not either playable viewport.
	# It verifies real clip installation without drawing duplicate test bodies.
	observer.visible = false
	observer.dedicated = true
	observer.no_saves = true
	observer.rooms = readers[0].rooms.duplicate(true)
	observer.coord_to_room = readers[0].coord_to_room.duplicate(true)
	observer.zone_count = readers[0].zone_count
	root.add_child(observer)
	var wire := WireSession.new()
	wire.name = "Session"
	wire.game = observer
	wire.local_char = {"cls": "archer", "level": 1, "name": "Late friend"}
	root.add_child(wire)
	wire.set_physics_process(false)
	var transport := ENetMultiplayerPeer.new()
	transports.append(transport)
	if transport.create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "late appearance reader could not connect"
	api.multiplayer_peer = transport
	await _settle()
	var pid := api.get_unique_id()
	roots[0].peers[pid] = {}
	root.peers[1] = {}
	wire._rpc_join_ready.rpc_id(1, wire._char_block())
	await _settle()
	var found := false
	for p in observer.players:
		if p.peer_id == first_pid:
			found = Appearance.from_player(p) == Appearance.from_player(readers[1].player) \
				and p._clips.idle.tex == readers[1].player._clips.idle.tex
	if not found or wire.peer_chars.get(first_pid, {}).get("appearance") != Appearance.from_player(readers[1].player):
		return "late join did not receive the first guest's updated appearance"
	_show(0)
	shot("02b_late_friend_joins_updated_roster")
	transport.close()
	api.multiplayer_peer = null
	root.online = false
	await _settle()
	return ""
