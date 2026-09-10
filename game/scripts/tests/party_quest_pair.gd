extends "res://shot_party_appearance.gd"
## Reuse only the paired readers/transport containers. Appearance checks never run.
var owner_rig: ShotRig
const Recovery := preload("res://scripts/loot_recovery.gd")
var opening_recovery: Array[Dictionary] = []


func _init() -> void:
	super()
	# The outer ShotRig owns the only watchdog and screenshot namespace.
	if _watchdog != null:
		remove_child(_watchdog)
		_watchdog.free()
		_watchdog = null


func _ready() -> void:
	pass


func step(label: String) -> void:
	super(label)
	if owner_rig != null:
		owner_rig.last_step = label


func boot_pair() -> String:
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	for g in readers:
		g.set_process(false)
		g.player.set_physics_process(false)
		g.settings["touch_controls"] = false
		g.refresh_touch_mode()
		g._apply_touch_mode()
		g.play_started = true
		g.state = Game.ST_PLAYING
		g.menus.close()
		g.request_pause(false)
		# These fresh readers completed real opening choices. Settle their
		# uncollected rewards before the retained home/world fixture begins.
		var recovered := Recovery.recover_live(g)
		opening_recovery.append({"reader": g.name, "chests": recovered.chests,
			"gold": recovered.gold, "items": recovered.items.size()})
		for node in g.get_children():
			if Recovery.earned_chest(g, node) or Recovery.earned_coin(g, node):
				return "opening reward recovery left an eligible live source"
	print("PARTY QUEST OPENING RECOVERY: ", JSON.stringify(opening_recovery))
	var host: Game = readers[0]
	var guest: Game = readers[1]
	# A real distinct home-world control, before the initial host snapshot.
	guest.quest_key = "vargoth"
	guest.quest_kills = {"hunter_pack_thinned": 1}
	guest.flags["qa_party_quest_home"] = true
	SaveGame.write(guest, SLOT)
	if SaveGame.read(SLOT).is_empty(): return "could not create isolated guest home"
	if transports[0].create_server(0, 3) != OK: return "party quest host bind failed"
	apis[0].multiplayer_peer = transports[0]
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "party quest guest connection failed"
	apis[1].multiplayer_peer = transports[1]
	if not await _until(func() -> bool: return apis[1].get_unique_id() > 1 and not apis[0].get_peers().is_empty()):
		return "party quest ENet connection timed out"
	var pid := apis[1].get_unique_id()
	roots[0].peers[pid] = {}
	roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = pid
	for i in 2:
		readers[i].qa_online = true
		wires[i].set_physics_process(false)
	wires[1].local_char = {"slot": SLOT, "name": "Quest guest", "cls": "mage"}
	guest.save_slot = SLOT
	guest.no_saves = false
	wires[0]._send_snapshot(pid)
	if not await _until(func() -> bool: return wires[1].world_ready and wires[0].peer_chars.has(pid) and _shell(0, pid) != null):
		return "party quest initial snapshot/readiness timed out"
	_show(1)
	await _capture("quest_00_paired_setup")
	return ""


func _until(predicate: Callable, seconds := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await get_tree().create_timer(0.03, true).timeout
	return bool(predicate.call())


func _capture(label: String) -> void:
	owner_rig.game = game
	await frames(3)
	await RenderingServer.frame_post_draw
	owner_rig.shot(label, "controlled party quest fixture; real ENet, no ordinary combat/input claim")


func stop_pair() -> void:
	for i in readers.size():
		readers[i].qa_online = false
		readers[i].no_saves = true
		readers[i].save_slot = -1
		readers[i].guest_world = false
		wires[i].set_physics_process(false)
		roots[i].online = false
	for transport in transports: transport.close()
	for i in apis.size():
		apis[i].multiplayer_peer = null
		get_tree().set_multiplayer(null, roots[i].get_path())
