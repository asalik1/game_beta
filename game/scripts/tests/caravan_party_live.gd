extends RefCounted
## Two real worlds and ENet APIs supplied by shot_road_hunt; no extra engine.
const Caravan := preload("res://scripts/road_caravan.gd")
const Hunt := preload("res://scripts/road_hunt.gd")
const Company := preload("res://scripts/tests/encounter_company_live.gd")


static func _hold_wave(cart: Node2D) -> void:
	for i in cart.enemies.size():
		var enemy: Enemy = cart.enemies[i]
		enemy.set_physics_process(false)
		enemy.global_position = cart.global_position + Vector2(340, -120 + i * 100)


static func _help_to(r: Node, cart: Node2D, mirror: Node2D, target: int) -> bool:
	var deadline := Time.get_ticks_msec() + 9000
	while cart.tugs < target and Time.get_ticks_msec() < deadline:
		mirror.entry.action.call()
		await r.get_tree().create_timer(0.7, true).timeout
	return cart.tugs == target


static func _guest_kill(r: Node, cart: Node2D) -> bool:
	for enemy in cart.enemies.duplicate():
		var id: int = enemy.net_id
		if not await r._until(func() -> bool: return r.wires[1].net_enemies.has(id)):
			return false
		var mirror: Enemy = r.wires[1].net_enemies[id]
		mirror.take_damage(999999.0, Vector2.LEFT)
	return true


static func run(r: Node, room: int) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var cart := Caravan.begin(host, room)
	if cart == null or not await r._until(func() -> bool: return cart.phase == Caravan.WORKING):
		return "caravan party fixture did not start its real first wave"
	_hold_wave(cart)
	host.player.global_position = cart.handle.global_position
	for i in 3:
		cart.clock += 1.0
		cart.request(host.player)
	cart.set_physics_process(false)
	# Freeze the guest's own home immediately before the full world snapshot.
	SaveGame.write(guest, r.SLOT)
	r.wires[1].local_char["slot"] = r.SLOT
	guest.no_saves = false
	guest.save_slot = r.SLOT
	if r.transports[0].create_server(0, 2) != OK:
		return "caravan ENet bind failed"
	r.apis[0].multiplayer_peer = r.transports[0]
	if r.transports[1].create_client("127.0.0.1", r.transports[0].host.get_local_port()) != OK:
		return "caravan ENet connect failed"
	r.apis[1].multiplayer_peer = r.transports[1]
	if not await r._until(func() -> bool: return not r.apis[0].get_peers().is_empty()):
		return "caravan ENet handshake timed out"
	var pid: int = r.apis[1].get_unique_id()
	r.roots[0].peers[pid] = {}
	r.roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = pid
	for reader in r.readers:
		reader.qa_online = true
	r.wires[0].world_ready = true
	var home := SaveGame.read(r.SLOT)
	r.wires[0]._send_snapshot(pid)
	if not await r._until(func() -> bool: return Caravan.find(guest, room) != null and r._shell(0, pid) != null, 15.0):
		return "late join never received the caravan"
	guest.player.set_physics_process(false)
	guest.terrain_event_t = 10000.0
	var mirror := Caravan.find(guest, room)
	if mirror.tugs != 3 or mirror.token != cart.token or mirror.global_position != cart.global_position or mirror.mirror_foes != 2:
		return "late join restarted or displaced caravan work"
	if SaveGame.world_of(SaveGame.read(r.SLOT)) != SaveGame.world_of(home):
		return "joining the caravan overwrote the guest's home world"
	for i in 2:
		r._show(i)
		await r.skip_dialogue()
	guest.player.global_position = mirror.handle.global_position
	if not await r._until(func() -> bool: return r._shell(0, pid).global_position.distance_to(mirror.handle.global_position) < 25.0):
		return "caravan helper position did not reach the host"
	await r._capture("caravan_party_01_late_join_shared_work")
	var fit := Company._fit(guest, mirror.status)
	if fit != "":
		return fit
	# Bad identity and direct world-flag requests cannot supply the road.
	r.wires[1].request_road_caravan(room, cart.token + 1)
	r.wires[1]._rpc_flag_to_host.rpc_id(1, Caravan.benefit_flag(host), true)
	await r.frames(5)
	if cart.tugs != 3 or Caravan.supplied(host):
		return "guest forged work identity or a caravan reward flag"
	cart.clock += 1.0
	guest.player.global_position = mirror.handle.global_position + Vector2(350, 0)
	if not await r._until(func() -> bool: return r._shell(0, pid).global_position.distance_to(mirror.handle.global_position) > 250.0):
		return "distant helper fixture did not reach the authority"
	r.wires[1].request_road_caravan(room, cart.token)
	await r.frames(5)
	if cart.tugs != 3:
		return "authority accepted an out-of-reach helper"
	guest.player.global_position = mirror.handle.global_position
	if not await r._until(func() -> bool: return r._shell(0, pid).global_position.distance_to(mirror.handle.global_position) < 25.0):
		return "helper could not return to the shafts"
	cart.set_physics_process(true)
	mirror.entry.action.call()
	mirror.entry.action.call()
	if not await r._until(func() -> bool: return mirror.tugs == 4):
		return "guest Interact did not advance authoritative work"
	await r.frames(3)
	if cart.tugs != 4:
		return "burst requests bypassed the global tug cooldown"
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	await r.frames(3)
	if not guest.interact_in_range:
		return "co-op touch Act unavailable at the shafts"
	fit = Company._fit(guest, mirror.status)
	if fit != "":
		return fit
	await r._capture("caravan_party_02_touch_helper")
	if not await _help_to(r, cart, mirror, 6) or not await _guest_kill(r, cart):
		return "guest could not finish first-stage work and combat"
	if not await r._until(func() -> bool: return cart.wave == 2 and mirror.wave == 2):
		return "second warning was not shared"
	await r._capture("caravan_party_03_second_warning")
	if not await r._until(func() -> bool: return cart.phase == Caravan.WORKING):
		return "second attack failed to spawn"
	_hold_wave(cart)
	if not await _help_to(r, cart, mirror, 12):
		return "guest could not free the wheel while covered"
	var host_gold := host.player.gold
	var guest_gold := guest.player.gold
	var guest_xp := guest.player.xp
	var kills := host.quest_kills.duplicate(true)
	var counters := host.zone_alive.duplicate(true)
	var roll := host.loot_rng.state
	var before_price: float = guest.shop_markup(room)
	guest.menus.open_shop(room, "buy")
	var old_shell_id := guest.menus.root.get_instance_id()
	await r._capture("caravan_party_04_prices_before_rescue")
	if not await _guest_kill(r, cart):
		return "guest could not settle the final wave"
	if not await r._until(func() -> bool: return Caravan.supplied(host) and Caravan.supplied(guest) and is_instance_valid(guest.menus.root) and guest.menus.root.get_instance_id() != old_shell_id):
		return "rescue did not refresh an open guest shop"
	if not is_equal_approx(guest.shop_markup(room), before_price * Balance.CARAVAN_PRICE_MULT):
		return "guest shop did not receive the chapter's new price"
	await r._capture("caravan_party_05_open_shop_receives_supplies")
	guest.menus.close()
	if [host.player.gold, guest.player.gold, guest.player.xp, host.quest_kills, host.zone_alive, host.loot_rng.state] \
		!= [host_gold, guest_gold, guest_xp, kills, counters, roll]:
		return "caravan leaked normal rewards or changed the loot budget"
	guest.autosave()
	if SaveGame.world_of(SaveGame.read(r.SLOT)) != SaveGame.world_of(home):
		return "caravan completion or shop view overwrote guest home progress"
	# Rebuild the visitor from the production snapshot after completion. The
	# shared benefit survives even once the short result/cart has gone away.
	cart.cancel()
	if not await r._until(func() -> bool: return Caravan.find(guest, room) == null):
		return "completed cart did not retire on the guest"
	var prior_world := guest.world.get_instance_id()
	r.wires[0]._send_snapshot(pid)
	if not await r._until(func() -> bool: return guest.world.get_instance_id() != prior_world and r.wires[1].world_ready and guest.guest_world, 15.0):
		return "completed-world refresh did not finish"
	await r.frames(8)
	guest.player.set_physics_process(false)
	if not Caravan.supplied(guest) or Caravan.find(guest, room) != null:
		return "late completed world lost prices or replayed the encounter"
	await r._capture("caravan_party_06_completed_world_has_trade_benefit")
	# Begin a fresh fixture attempt, then travel while it has real enemies.
	host.flags.erase(Caravan.benefit_flag(host))
	host.flags.erase(host._road_flag(room))
	host.player.global_position = host.room_center(room)
	cart = Caravan.begin(host, room)
	if cart == null or not await r._until(func() -> bool: return cart.phase == Caravan.WORKING):
		return "travel fixture failed to start"
	var old_ids: Array[int] = []
	for enemy in cart.enemies:
		old_ids.append(enemy.net_id)
	host.switch_chapter("ch2", true)
	r.wires[0].host_advance_party()
	if not await r._until(func() -> bool: return guest.chapter_id == "ch2", 15.0):
		return "caravan party travel failed"
	for i in 2:
		r._show(i)
		await r.skip_dialogue()
		r.readers[i].player.set_physics_process(false)
	if Caravan.active_in(host) or Caravan.active_in(guest) or Caravan.supplied(host) or Caravan.supplied(guest):
		return "caravan or discount leaked into another chapter"
	for id in old_ids:
		if r.wires[1].net_enemies.has(id):
			return "old caravan attacker survived party travel"
	await r._capture("caravan_party_07_travel_cleans_up")
	room = -1
	for i in host.zones.size():
		if Hunt.eligible(host, i):
			room = i
			break
	if room < 0:
		return "chapter two has no disconnect fixture road"
	for reader in [host, guest]:
		reader.player.global_position = reader.room_center(room)
		reader._enter_room(room)
	for enemy in r.get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and enemy.game == host and enemy.zone_idx == room and not enemy.dying:
			enemy.take_damage(999999.0, Vector2.LEFT)
	if not await r._until(func() -> bool: return not host._room_hot(room)):
		return "disconnect road pack did not clear"
	for i in 2:
		r._show(i)
		await r.skip_dialogue()
	cart = Caravan.begin(host, room)
	if cart == null or not await r._until(func() -> bool: return Caravan.find(guest, room) != null):
		return "disconnect fixture has no mirrored cart"
	r.transports[1].close()
	guest.qa_online = false
	r.roots[1].online = false
	r.wires[1].set_physics_process(false)
	r.wires[1]._on_session_ended("caravan disconnect QA")
	if not await r._until(func() -> bool: return Caravan.find(guest, room) == null):
		return "disconnected guest began simulating a stale caravan"
	if not r.wires[1].net_enemies.is_empty() or SaveGame.world_of(SaveGame.read(r.SLOT)) != SaveGame.world_of(home):
		return "session teardown retained enemy mirrors or changed the home world"
	await r._capture("caravan_party_08_disconnect_retires_cart")
	print("ok: caravan late joins, guest work/rate/reach, real guest kills, touch/party layout, live merchant prices, home save, completed-world snapshot, travel and disconnect cleanup")
	return ""
