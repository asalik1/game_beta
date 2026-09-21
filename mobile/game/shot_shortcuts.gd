extends ShotRig
## Owned shortcut QA entry. The preserved Road Hunt files are read-only sources
## for the paired support pattern; this scene neither extends nor modifies them.
const SLOT := 96
var roots: Array[Node] = []
var apis: Array[MultiplayerAPI] = []
var wires: Array[Node] = []
var readers: Array[Game] = []
var screens: Array[SubViewportContainer] = []
var transports: Array[ENetMultiplayerPeer] = []

class PartyGame extends Game:
	var qa_online := false
	var qa_bridge: Node
	func net_online() -> bool: return qa_online
	func net_session() -> Node: return qa_bridge

class WireRoot extends Node:
	var peers := {}
	var online := true
	func is_online() -> bool: return online
	func drop_peer(pid: int) -> void: peers.erase(pid)

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _host_down_sweep() -> void: pass
	# --- QA observation taps (shortcut candidate; PASSIVE ONLY) -------------
	# Identical @rpc annotations and signatures around super calls: nothing
	# about the request or the production result changes. Each host-side
	# receipt records the sender, the args, the current world instance, the
	# sender's replicated body, the far-room clearance and the REAL flag
	# before/after — the packet truth shortcut_party_live.gd awaits instead
	# of counting frames. Both peers run this same class, so the RPC config
	# stays symmetric; root must still validate the checksum under Godot.
	var qa_shortcut_rx: Array = []
	var qa_flag_rx: Array = []
	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_shortcut_open(chapter: String, seed_value: int, flag_name: String) -> void:
		var rec: Dictionary = _qa_observe(flag_name)
		rec["args"] = {"chapter": chapter, "seed": seed_value, "flag": flag_name}
		super._rpc_shortcut_open(chapter, seed_value, flag_name)
		rec["flag_after"] = _qa_flag(flag_name)
		rec["genuine_after"] = _qa_flag(String(rec.get("genuine_key", "")))
		qa_shortcut_rx.append(rec)
	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_flag_to_host(flag_name: String, value) -> void:
		var rec: Dictionary = _qa_observe(flag_name)
		rec["args"] = {"flag": flag_name, "value": value}
		super._rpc_flag_to_host(flag_name, value)
		rec["flag_after"] = _qa_flag(flag_name)
		rec["genuine_after"] = _qa_flag(String(rec.get("genuine_key", "")))
		qa_flag_rx.append(rec)
	func _qa_flag(flag_name: String) -> Variant:
		return game.get_flag(flag_name, false) if game != null else null
	func _qa_observe(flag_name: String) -> Dictionary:
		var rec: Dictionary = {"sender": multiplayer.get_remote_sender_id(),
			"flag_before": _qa_flag(flag_name), "world_id": 0, "actor": {}, "far": {}}
		if game == null:
			return rec
		if is_instance_valid(game.world):
			rec["world_id"] = game.world.get_instance_id()
		var q: Player = _player_of(int(rec["sender"]))
		if q != null and is_instance_valid(q):
			rec["actor"] = {"pos": [q.global_position.x, q.global_position.y],
				"room": game.room_at_pos(q.global_position), "hp": q.hp,
				"dead": q.dead, "downed": q.downed, "ghost": q.ghost}
		var edge: Dictionary = game.shortcut_edge
		rec["latch_distance"] = -1.0
		var latch: Node2D = preload("res://scripts/shortcut_latch.gd").find(game)
		if is_instance_valid(q) and is_instance_valid(latch):
			rec["latch_distance"] = q.global_position.distance_to(latch.global_position)
		if not edge.is_empty():
			rec["genuine_key"] = String(edge["flag"])
			rec["genuine_before"] = _qa_flag(String(edge["flag"]))
			var far := int(edge["far"])
			rec["far"] = {"zone": far, "zone_alive": int(game.zone_alive.get(far, 0)),
				"cleared": bool(game.cleared.get(far, false)),
				"pacified": game.room_pacified(far)}
		return rec


func _ready() -> void:
	if flag("world-prompt-probe") and not flag("corridor-camera"):
		push_error("world-prompt-probe requires corridor-camera")
		finish(1)
		return
	var modes := int(flag("party")) + int(flag("solo-controls")) + int(flag("blink-mouth")) + int(flag("paladin-mouth")) + int(flag("corridor-camera"))
	if modes != 1:
		push_error("Choose exactly one shortcut mode: --party, --solo-controls, --blink-mouth, --paladin-mouth or --corridor-camera")
		return finish(1)
	if not flag("party"):
		var path := "res://scripts/tests/shortcut_solo_live.gd"
		if flag("blink-mouth"):
			path = "res://scripts/tests/shortcut_blink_live.gd"
		if flag("paladin-mouth"):
			path = "res://scripts/tests/shortcut_paladin_live.gd"
		if flag("corridor-camera"):
			path = "res://scripts/tests/shortcut_corridor_live.gd"
		if not ResourceLoader.exists(path):
			push_error("Selected shortcut helper is not installed: " + path)
			return finish(1)
		var helper: GDScript = load(path)
		var solo_error: String = await helper.run(self)
		if solo_error != "":
			push_error(solo_error)
		return finish(0 if solo_error == "" else 1)
	var saved_files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		saved_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	var error: String = await preload("res://scripts/tests/shortcut_party_live.gd").run(self)
	if error != "":
		await _capture("diagnostic")
	get_tree().paused = false
	for i in readers.size():
		readers[i].qa_online = false
		readers[i].no_saves = true
		readers[i].save_slot = -1
		readers[i].guest_world = false
		wires[i].set_physics_process(false)
		roots[i].online = false
	for peer in transports:
		peer.close()
	for i in apis.size():
		apis[i].multiplayer_peer = null
		get_tree().set_multiplayer(null, roots[i].get_path())
	var cleanup := {"complete": true, "slot": SLOT, "files": [], "errors": []}
	for path in saved_files:
		if saved_files[path] == null:
			if FileAccess.file_exists(path):
				var removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				if removed != OK:
					cleanup.errors.append("could not remove owned save fixture: " + String(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				cleanup.errors.append("could not restore owned save fixture: " + String(path))
			else:
				file.store_buffer(saved_files[path])
				file.flush()
				if file.get_error() != OK:
					cleanup.errors.append("save fixture restore write failed: " + String(path))
				file.close()
		var exists: bool = FileAccess.file_exists(path)
		var exact: bool = not exists if saved_files[path] == null else exists and FileAccess.get_file_as_bytes(path) == saved_files[path]
		cleanup.files.append({"path": path, "originally_present": saved_files[path] != null, "restored_exact": exact})
		if not exact:
			cleanup.errors.append("save fixture bytes not restored: " + String(path))
	cleanup.complete = cleanup.errors.is_empty()
	if not bool(cleanup.complete):
		error += ("; " if error != "" else "") + str(cleanup.errors)
	var cleanup_path: String = shot_dir + "/wrapper_cleanup.json"
	var result_file := FileAccess.open(cleanup_path, FileAccess.WRITE)
	if result_file == null:
		error += "; unable to write wrapper cleanup receipt"
	else:
		result_file.store_string(JSON.stringify(cleanup, "  "))
		result_file.flush()
		if result_file.get_error() != OK:
			error += "; unable to finish wrapper cleanup receipt"
		result_file.close()
	if error != "":
		push_error(error)
	return finish(0 if error == "" else 1)


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
	var deadline := Time.get_ticks_msec() + 6000
	while not reader.play_started and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05, true).timeout
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
	wire.local_char = {"name": label, "cls": cls, "level": 1}
	reader.qa_bridge = wire
	root.add_child(wire)
	wires.append(wire)
	reader.player._net_mgr = root
	api.peer_disconnected.connect(func(pid: int) -> void:
		root.peers.erase(pid)
		wire._on_peer_left(pid))
	transports.append(ENetMultiplayerPeer.new())


func _show(index: int) -> void:
	game = readers[index]
	for i in screens.size():
		screens[i].visible = i == index


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label)


func _until(check: Callable, seconds := 6.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not check.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.03, true).timeout
	return check.call()


func _shell(index: int, pid: int) -> Player:
	for player in readers[index].players:
		if is_instance_valid(player) and player != readers[index].local_player and player.peer_id == pid:
			return player
	return null

