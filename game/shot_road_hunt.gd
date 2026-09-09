extends ShotRig
## Two complete games, one engine: production ENet world/track/enemy/reward RPCs.
const Hunt := preload("res://scripts/road_hunt.gd")
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
	var road_offer_requests := {}
	func net_online() -> bool: return qa_online
	func net_session() -> Node: return qa_bridge
	func _offer_road_card(room: int) -> void:
		road_offer_requests[room] = int(road_offer_requests.get(room, 0)) + 1
		super._offer_road_card(room)

class WireRoot extends Node:
	var peers := {}
	var online := true
	func is_online() -> bool: return online
	func drop_peer(pid: int) -> void: peers.erase(pid)

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _host_down_sweep() -> void: pass


func _ready() -> void:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	var error := await _checks()
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
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				error = "could not restore hunt save fixture"
			else:
				file.store_buffer(files[path])
				file.close()
	if error != "":
		push_error(error)
		return finish(1)
	if not flag("company") and not flag("caravan") and not flag("activities"):
		print("ok: road hunt live offer, ordered tracks, late join world snapshot, guest inspection/flush, telegraphed elite, real guest damage, personal payment/save, absent participant, abandoned quarry, travel and disconnect cleanup")
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


func _button(text: String) -> Button:
	for node in game.menus.root.find_children("*", "Button", true, false):
		if text in node.text:
			return node
	return null


func _new_hunt(g: Game, room: int) -> Node2D:
	var old := Hunt.find(g, room)
	if old != null:
		old.cancel()
	g.flags.erase(g._road_flag(room))
	return Hunt.begin(g, room, g.room_center(room))


func _checks() -> String:
	var host: Game = readers[0]
	var guest: Game = readers[1]
	_show(0)
	var room := -1
	for i in host.zones.size():
		if Hunt.eligible(host, i):
			room = i
			break
	if room < 0:
		return "chapter has no safe road room"
	host.player.global_position = host.room_center(room)
	host._enter_room(room)
	await _until(func() -> bool: return host.hud.overlay.color.a < 0.01)
	for entry in host.interactables.duplicate():
		var actor: Variant = entry.get("node")
		if is_instance_valid(actor) and actor.has_meta("road_context"):
			host._remove_interactable(actor)
	host.flags.erase(host._road_flag(room))
	if flag("caravan"):
		return await preload("res://scripts/tests/caravan_party_live.gd").run(self, room)
	host._road_card_node(room, "hunt")
	var offer: Dictionary = host.interactables[-1]
	offer.action.call()
	await frames(4)
	if _button("Take the trail") == null:
		return "real hunter offered no start action"
	for node in host.menus.root.find_children("*", "Button", true, false):
		if not host.menus._shell_rect.grow(1).encloses(node.get_global_rect()):
			return "hunt decision escaped its panel"
	await _capture("01_hunter_offer")
	_button("Take the trail").pressed.emit()
	var trail: Variant = Hunt.find(host, room)
	if trail == null:
		return "real hunter could not place a trail"
	host.player.global_position = trail.points[0]
	await _until(func() -> bool: return host.hud.title_label.modulate.a < 0.01)
	await frames(3)
	await _capture("02_follow_the_tracks")
	trail.entries[0].action.call()
	if trail.sign_index != 1:
		return "real first sign did not advance"
	# Admit the guest AFTER a sign has been read. The full production snapshot
	# rebuilds its world, then join_ready briefs the current hunt and enemies.
	SaveGame.write(guest, SLOT)
	var home := SaveGame.read(SLOT)
	wires[1].local_char["slot"] = SLOT
	guest.no_saves = false
	guest.save_slot = SLOT
	if transports[0].create_server(0, 2) != OK:
		return "hunt ENet bind failed"
	apis[0].multiplayer_peer = transports[0]
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "hunt ENet guest connect failed"
	apis[1].multiplayer_peer = transports[1]
	if not await _until(func() -> bool: return not apis[0].get_peers().is_empty()):
		return "hunt ENet handshake timed out"
	var pid := apis[1].get_unique_id()
	roots[0].peers[pid] = {}
	roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = pid
	for i in 2:
		readers[i].qa_online = true
	wires[0].world_ready = true
	# The still-local hero may autosave while transport admission settles.
	# Freeze the home file at the actual world-join boundary, after admission.
	var admitted_home := SaveGame.read(SLOT)
	print("HUNT JOIN BOUNDARY: ", JSON.stringify({"original_time": SaveGame.world_of(home).get("run_time"),
		"admitted_time": SaveGame.world_of(admitted_home).get("run_time"),
		"original_seed": SaveGame.world_of(home).get("wander_seed"), "admitted_seed": SaveGame.world_of(admitted_home).get("wander_seed")}))
	home = admitted_home
	wires[0]._send_snapshot(pid)
	if not await _until(func() -> bool: return Hunt.find(guest, room) != null and _shell(0, pid) != null, 15.0):
		return "late join never received the active hunt"
	guest.player.set_physics_process(false)
	guest.terrain_event_t = 10000.0
	var mirror: Variant = Hunt.find(guest, room)
	if mirror.sign_index != 1 or mirror.points != trail.points or mirror.token != trail.token:
		return "late join restarted or displaced the trail"
	if flag("activities"):
		return await preload("res://scripts/tests/ward_activities_live.gd").run(self, room)
	if flag("company"):
		return await preload("res://scripts/tests/encounter_company_live.gd").run(self, room)
	_show(1)
	guest.player.global_position = mirror.points[1]
	if not await _until(func() -> bool: return _shell(0, pid).global_position.distance_to(mirror.points[1]) < 30.0):
		return "guest movement never reached the authority"
	await frames(3)
	await _capture("03_late_join_shared_sign")
	mirror.entries[1].action.call()
	if not await _until(func() -> bool: return trail.sign_index == 2 and mirror.sign_index == 2):
		return "guest sign inspection did not reach both worlds"
	wires[1].request_road_hunt(room, trail.token, 1)
	await frames(3)
	if trail.sign_index != 2 or trail.phase != Hunt.TRACKING:
		return "duplicate guest inspection rewound or flushed the hunt"
	guest.player.global_position = mirror.points[2]
	if not await _until(func() -> bool: return _shell(0, pid).global_position.distance_to(mirror.points[2]) < 30.0):
		return "guest could not reach the last sign"
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	mirror.entries[2].action.call()
	if not await _until(func() -> bool: return mirror.phase == Hunt.WARNING):
		return "guest flush never raised the warning"
	await _capture("04_touch_quarry_warning")
	if guest._touch_hud == null or not guest._touch_hud.visible:
		return "hunt touch fixture has no visible controls"
	for button in guest._touch_hud._btns.values():
		if mirror.status.get_global_rect().intersects(button.panel.get_global_rect()):
			return "hunt objective covers a touch action"
	if not await _until(func() -> bool: return trail.phase == Hunt.FIGHTING and not wires[1].net_enemies.is_empty()):
		return "warning never spawned the shared quarry"
	var enemy: Enemy = trail.quarry
	if enemy.level != 2:
		return "the village quarry does not match its nearby level-two road"
	var enemy_id := enemy.net_id
	if not await _until(func() -> bool: return wires[1].net_enemies.has(enemy_id)):
		return "quarry has no guest mirror"
	var quarry_copy: Enemy = wires[1].net_enemies[enemy_id]
	if enemy.xp_value != 0 or enemy.gold_value != 0 or enemy.zone_idx != -1 or not quarry_copy.elite:
		return "quarry entered the campaign reward budget or lost its elite presentation"
	var host_gold := host.player.gold
	var guest_gold := guest.player.gold
	var guest_xp := guest.player.xp
	var kills := host.quest_kills.duplicate(true)
	var counters := host.zone_alive.duplicate(true)
	var roll := host.loot_rng.state
	await frames(4)
	await _capture("05_guest_faces_the_quarry")
	# Real owner->host damage transport; the authoritative Enemy.die callback
	# must settle the encounter, rather than the rig invoking complete().
	quarry_copy.take_damage(999999.0, Vector2.LEFT)
	if not await _until(func() -> bool: return trail.phase == Hunt.COMPLETE and guest.player.gold > guest_gold):
		return "guest quarry kill did not settle both purses"
	var host_expected := host.player.gold_yield(int(ceil(Balance.ROAD_HUNT_GOLD * Balance.daily_gold_mult(host.player.level))))
	var guest_expected := guest.player.gold_yield(int(ceil(Balance.ROAD_HUNT_GOLD * Balance.daily_gold_mult(guest.player.level))))
	if host.player.gold != host_gold + host_expected or guest.player.gold != guest_gold + guest_expected \
		or guest.player.xp != guest_xp or host.quest_kills != kills or host.zone_alive != counters or host.loot_rng.state != roll:
		return "shared hunt paid incorrectly or polluted campaign rewards"
	wires[0].host_road_hunt_reward(trail)
	await frames(4)
	if guest.player.gold != guest_gold + guest_expected:
		return "a repeated settlement paid the guest twice"
	var saved := SaveGame.read(SLOT)
	if SaveGame.world_of(saved) != SaveGame.world_of(home) \
		or not SaveGame.character_of(saved).get("history_flags", {}).get(trail.receipt(), false) \
		or int(SaveGame.character_of(saved).get("gold", -1)) != guest.player.gold:
		var changed: Array = []
		for key in SaveGame.world_of(home):
			if SaveGame.world_of(home)[key] != SaveGame.world_of(saved).get(key):
				changed.append(key)
		print("HUNT SAVE DIAGNOSTIC: ", JSON.stringify({"world_changed": changed,
			"home_seed": SaveGame.world_of(home).get("wander_seed"), "host_seed": host.wander_seed,
			"saved_seed": SaveGame.world_of(saved).get("wander_seed"),
			"receipt_saved": SaveGame.character_of(saved).get("history_flags", {}).get(trail.receipt(), false),
			"gold_saved": SaveGame.character_of(saved).get("gold"), "gold_live": guest.player.gold}))
		return "hunt payout failed its character-home save isolation"
	await _capture("06_shared_hunt_paid_and_saved")
	# An abandoned fight must despawn its mirror, not count as a death.
	trail = _new_hunt(host, room)
	if trail == null:
		return "QA retry failed to place a new hunt"
	for i in 3:
		host.player.global_position = trail.points[i]
		trail.request(host.player, i)
	if not await _until(func() -> bool: return trail.phase == Hunt.FIGHTING):
		return "retry quarry failed to spawn"
	var abandoned: Enemy = trail.quarry
	var abandoned_id := abandoned.net_id
	var abandoned_instance: int = trail.get_instance_id()
	var elsewhere := 0 if room != 0 else 1
	host.player.global_position = host.room_center(elsewhere)
	guest.player.global_position = guest.room_center(elsewhere)
	var purse_after := guest.player.gold
	if not await _until(func() -> bool: return not is_instance_id_valid(abandoned_instance) and not wires[1].net_enemies.has(abandoned_id)):
		return "abandonment left a hunt or a guest quarry alive"
	if guest.player.gold != purse_after or host.get_flag(host._road_flag(room), false):
		return "abandonment paid or consumed the hunt"
	var attempts := int(host.road_offer_requests.get(room, 0))
	host.player.global_position = host.room_center(room)
	host._enter_room(room)
	if int(host.road_offer_requests.get(room, 0)) != attempts + 1:
		return "returning to an abandoned road never reconsidered its offer"
	# Reset only the fixture's earlier receipt, then prove a hero elsewhere
	# receives neither a purse nor a receipt, even on returning after victory.
	host.player.global_position = host.room_center(room)
	trail = _new_hunt(host, room)
	if trail == null:
		return "absent-recipient fixture could not start"
	host.flags.erase(trail.receipt())
	guest.flags.erase(trail.receipt())
	if not await _until(func() -> bool: return host.room_at_pos(_shell(0, pid).global_position) == elsewhere):
		return "absent hero's location never reached the host"
	for i in 3:
		host.player.global_position = trail.points[i]
		trail.request(host.player, i)
	if not await _until(func() -> bool: return trail.phase == Hunt.FIGHTING):
		return "absent-recipient quarry never appeared"
	var host_before := host.player.gold
	trail.quarry.take_damage(999999.0, Vector2.LEFT)
	if not await _until(func() -> bool: return trail.phase == Hunt.COMPLETE and Hunt.find(guest, room).phase == Hunt.COMPLETE):
		return "absent-recipient hunt did not settle"
	if guest.player.gold != purse_after or guest.get_flag(trail.receipt(), false) or host.player.gold <= host_before:
		return "settlement paid an absent hero or missed the present host"
	guest.player.global_position = guest.room_center(room)
	wires[0].host_road_hunt_state(trail)
	await frames(4)
	if guest.player.gold != purse_after or guest.get_flag(trail.receipt(), false):
		return "returning to a completed hunt paid a historical purse"
	# Mid-trail party travel removes both sets of signs and their HUD.
	host.player.global_position = host.room_center(room)
	guest.player.global_position = guest.room_center(room)
	trail = _new_hunt(host, room)
	if not await _until(func() -> bool: return Hunt.find(guest, room) != null):
		return "travel fixture has no mirrored hunt"
	host.switch_chapter("ch2", true)
	wires[0].host_advance_party()
	if not await _until(func() -> bool: return guest.chapter_id == "ch2", 15.0):
		return "party chapter travel failed"
	for i in 2:
		_show(i)
		await skip_dialogue()
		readers[i].player.set_physics_process(false)
	if Hunt.find(host, room) != null or Hunt.find(guest, room) != null:
		return "old hunt survived the world rebuild"
	await _capture("07_party_travel_clears_the_trail")
	# A live guest loses the host: its last tracking snapshot must disappear,
	# never promote itself into an offline encounter authority.
	room = -1
	for i in host.zones.size():
		if Hunt.eligible(host, i):
			room = i
			break
	if room < 0:
		return "chapter two has no hunt fixture room"
	host.player.global_position = host.room_center(room)
	host._enter_room(room)
	guest.player.global_position = guest.room_center(room)
	guest._enter_room(room)
	# Chapter-two side rooms can contain an ordinary pack. Clear that real
	# pack before offering a safe-room encounter; do not bypass its hot gate.
	for actor in get_tree().get_nodes_in_group("enemies"):
		if actor is Enemy and actor.game == host and actor.zone_idx == room and not actor.dying:
			actor.take_damage(999999.0, Vector2.LEFT)
	if not await _until(func() -> bool: return not host._room_hot(room)):
		return "disconnect fixture's ordinary room combat did not clear"
	for i in 2:
		_show(i)
		await skip_dialogue()
	await _until(func() -> bool: return not host.hud.dialogue_active and not guest.hud.dialogue_active)
	trail = _new_hunt(host, room)
	if trail == null:
		return "disconnect hunt placement failed in %s (hot=%s)" % [String(host.zones[room].name), host._room_hot(room)]
	if not await _until(func() -> bool: return Hunt.find(guest, room) != null):
		return "disconnect fixture has no guest trail"
	transports[1].close()
	guest.qa_online = false
	roots[1].online = false
	wires[1].set_physics_process(false)
	if not await _until(func() -> bool: return Hunt.find(guest, room) == null):
		return "disconnected guest retained or began simulating its old hunt"
	await _capture("08_disconnected_guest_has_no_phantom_hunt")
	return ""
