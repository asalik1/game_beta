extends RefCounted
## Isolated ENet branches: no suite player, equipment, flags or roster borrowed.
## Every wire assertion waits for proof of delivery under a wall-clock deadline
## (a same-channel fence, or a freshly spawned shell), never a fixed sleep, so a
## stalled frame cannot fake a stale sync or let a rejected packet land late.
const Session := preload("res://scripts/net/net_session.gd")
const DELIVERY_MS := 3000

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
	var fence_seen := 0
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func host_quest_progress(_pid := 0, _rebrief := false, _counts_only := false) -> void: pass
	func host_sweep_unregistered() -> void: pass
	## Test-only marker on the same reliable channel as the session RPCs: once
	## it lands, everything its sender queued before it has been handled.
	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_test_fence(n: int) -> void:
		fence_seen = n

class WireGame extends Game:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func room_arrival_pos(_i: int) -> Vector2: return Vector2.ZERO
	func register_remote_player(p: Player) -> void:
		for q in players.duplicate():
			if q.peer_id == p.peer_id:
				players.erase(q)
				q.free()
		players.append(p)
		add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
	func net_host() -> bool: return false  # omit presentation broadcasts only
	func net_guest() -> bool: return false


static func suite(g: Game) -> String:
	var roots: Array[Node] = []
	var apis: Array[MultiplayerAPI] = []
	var wires: Array[Node] = []
	var transports: Array[ENetMultiplayerPeer] = []
	var error := ""
	Story.load_content()  # no-op after boot; WireGame skips Game._ready's load
	for i in range(3):
		var root := WireRoot.new()
		root.name = "DotWire%d" % i
		g.add_child(root)
		roots.append(root)
		var api := MultiplayerAPI.create_default_interface()
		g.get_tree().set_multiplayer(api, root.get_path())
		apis.append(api)
		var world := WireGame.new()
		root.add_child(world)
		var wire := WireSession.new()
		wire.name = "Session"
		wire.game = world
		root.add_child(wire)
		wires.append(wire)
		var peer := ENetMultiplayerPeer.new()
		transports.append(peer)
		var result: int = peer.create_server(0, 3) if i == 0 else peer.create_client("127.0.0.1", transports[0].host.get_local_port())
		if result != OK:
			error = "DoT ENet setup failed"
			break
		api.multiplayer_peer = peer
	if error == "":
		var deadline := Time.get_ticks_msec() + DELIVERY_MS
		while apis[0].get_peers().size() < 2 and Time.get_ticks_msec() < deadline:
			await g.get_tree().create_timer(0.02).timeout
		if apis[0].get_peers().size() != 2:
			error = "DoT ENet handshake timed out"
		else:
			for i in [1, 2]:
				roots[0].peers[apis[i].get_unique_id()] = {}
			error = await _checks(g, wires, apis)
	# Failures also release every private transport, game, player and enemy.
	for i in roots.size():
		apis[i].multiplayer_peer = null
		transports[i].close()
		g.get_tree().set_multiplayer(null, roots[i].get_path())
		roots[i].free()
	randomize()  # the seeded tick replay must not pin the RNG for later sections
	if error == "":
		print("ok: DoT stats ENet (equip/respec, both directions, hosted/dedicated, seeded burn/bleed, late join, changed-only, legacy and hostile payloads)")
	return error


static func _owner(wire: Node, pid: int) -> Player:
	var p := Player.new()
	p.game = wire.game
	p.peer_id = pid
	wire.game.register_remote_player(p)
	wire.game.local_player = p
	wire.game.player = p
	p.set_class("mage")
	p.equipment = {}
	p.attr_points["INT"] = 100
	p.recalc()
	return p


## Queue a fence behind whatever `sender` already sent to peer `to`, then wait
## (wall clock) until `receiver` has handled it. False = it never arrived.
static func _fence(g: Game, sender: Node, receiver: Node, to: int) -> bool:
	var n: int = receiver.fence_seen + 1
	sender.rpc_id(to, "_rpc_test_fence", n)
	var deadline := Time.get_ticks_msec() + DELIVERY_MS
	while receiver.fence_seen != n and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.02).timeout
	return receiver.fence_seen == n


static func _checks(g: Game, wires: Array[Node], apis: Array[MultiplayerAPI]) -> String:
	var host: Node = wires[0]
	var guest: Node = wires[1]
	var late: Node = wires[2]
	var pid := apis[1].get_unique_id()
	var hp := _owner(host, 1)
	var gp := _owner(guest, pid)
	# Real ready/spawn RPCs populate the initial character cache and shells.
	guest.rpc_id(1, "_rpc_join_ready", guest._char_block())
	var deadline := Time.get_ticks_msec() + DELIVERY_MS
	while (host._player_of(pid) == null or guest._player_of(1) == null) and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.02).timeout
	if host._player_of(pid) == null or guest._player_of(1) == null:
		return "DoT initial spawn failed"
	for dedicated in [false, true]:
		host.game.local_player = null if dedicated else hp
		if dedicated:
			host.game.players.erase(hp)
			host.game.player = null
		for direction in ([1] if dedicated else [0, 1]):
			var sender: Node = wires[direction]
			var receiver: Node = guest if direction == 0 else host
			var to: int = pid if direction == 0 else 1
			var p: Player = hp if direction == 0 else gp
			var shell: Player = receiver._player_of(p.peer_id)
			# Independent baseline for each direction/server mode.
			p.equipment = {}
			p.attr_points["INT"] = 100
			p.recalc()
			sender._vitals_sent = {}
			sender._tick_vitals(Session.VITALS_EVERY, p)
			if not await _fence(g, sender, receiver, to):
				return "DoT baseline vitals never arrived (direction %d)" % direction
			for action in ["equip", "respec"]:
				var old_crit := p.crit
				var old_damage := p.crit_dmg
				if action == "equip":
					p.equip({"slot": "charm", "plus": 0, "main": {"crit": 0.6}, "subs": {"crit_dmg": 0.75}})
				else:
					var stone := {"id": "reset_stone"}
					p.consumables.append(stone)
					if p.use_consumable(stone) != "":
						return "DoT respec fixture could not consume reset stone"
				if p.crit == old_crit and p.crit_dmg == old_damage:
					return "DoT %s fixture did not change stats" % action
				# Keep vitals byte-identical: combat alone must open the send gate.
				p.hp = sender._vitals_sent.hp
				p.max_hp = sender._vitals_sent.max_hp
				p.mp = sender._vitals_sent.mp
				sender._tick_vitals(Session.VITALS_EVERY, p)
				if not await _fence(g, sender, receiver, to):
					return "DoT %s vitals never arrived (direction %d)" % [action, direction]
				if shell.crit != p.crit or shell.crit_dmg != p.crit_dmg:
					return "DoT stale %s source (direction %d, dedicated %s)" % [action, direction, dedicated]
				var cached: Dictionary = receiver.peer_chars[p.peer_id]
				if cached.crit != p.crit or cached.crit_dmg != p.crit_dmg:
					return "DoT stale cached character after " + action
				var error := ""
				if direction == 0:
					# The host's own sheet is its DoT source; what host-to-guest sync
					# can break is the guest-side shell, so tick off that.
					error = _tick_damage(receiver.game, shell, p)
				else:
					error = await _ticks(g, host, guest, p)
				if error != "": return action + ": " + error
				# No change must leave the cadence accumulator untouched.
				sender._tick_vitals(Session.VITALS_EVERY, p)
				if sender._vitals_accum < Session.VITALS_EVERY:
					return "DoT unchanged stats emitted another packet"
		# Late-join uses the real host roster briefing, not a hand-built block.
		# A rejoin replaces the earlier shell, so wait for a FRESH one: the old
		# shell may already hold matching stats and prove nothing.
		var stale: Player = late._player_of(pid)
		var stale_id: int = stale.get_instance_id() if stale != null else 0
		late.rpc_id(1, "_rpc_join_ready", {"cls": "warrior", "level": 1})
		var late_shell: Player = null
		deadline = Time.get_ticks_msec() + DELIVERY_MS
		while Time.get_ticks_msec() < deadline:
			late_shell = late._player_of(pid)
			if late_shell != null and late_shell.get_instance_id() != stale_id:
				break
			late_shell = null
			await g.get_tree().create_timer(0.02).timeout
		if late_shell == null:
			return "DoT late join never spawned a fresh guest shell"
		if late_shell.crit != gp.crit or late_shell.crit_dmg != gp.crit_dmg:
			return "DoT late join received stale guest stats"
		var error := _tick_damage(late.game, late_shell, gp)
		if error != "": return "late join: " + error
		if not dedicated:
			# The host briefing is sent before the roster loop on the same channel.
			late_shell = late._player_of(1)
			if late_shell == null or late_shell.crit != hp.crit or late_shell.crit_dmg != hp.crit_dmg:
				return "DoT late join received stale host stats"
	# Default argument compatibility and hostile values use the real receiver.
	# Each probe is followed by a fence so a late packet cannot pass or poison it.
	var shell: Player = host._player_of(pid)
	var before := Vector2(shell.crit, shell.crit_dmg)
	host.get_parent().peers.erase(pid)
	guest.rpc_id(1, "_rpc_vitals", gp.hp, gp.max_hp, gp.mp, gp.critres, {"crit": 999.0, "crit_dmg": 999.0})
	var landed: bool = await _fence(g, guest, host, 1)
	host.get_parent().peers[pid] = {}
	if not landed:
		return "DoT unadmitted probe never reached the host"
	if Vector2(shell.crit, shell.crit_dmg) != before:
		return "DoT host accepted an unadmitted sender"
	for payload in [{}, {"crit": NAN, "crit_dmg": INF}, {"crit": "bad", "crit_dmg": []}]:
		if payload.is_empty():
			guest.rpc_id(1, "_rpc_vitals", gp.hp, gp.max_hp, gp.mp)
		else:
			guest.rpc_id(1, "_rpc_vitals", gp.hp, gp.max_hp, gp.mp, gp.critres, payload)
		if not await _fence(g, guest, host, 1):
			return "DoT legacy/hostile probe never reached the host"
		if Vector2(shell.crit, shell.crit_dmg) != before:
			return "DoT missing/nonfinite/wrong-typed stats overwrote valid sheet"
	for value in [-1.0e12, 1.0e12]:
		guest.rpc_id(1, "_rpc_vitals", gp.hp, gp.max_hp, gp.mp, gp.critres, {"crit": value, "crit_dmg": value, "magpen": 999.0})
		if not await _fence(g, guest, host, 1):
			return "DoT out-of-range probe never reached the host"
		if shell.crit != clampf(value, 0.0, Balance.NET_MAX_DOT_STAT) or shell.crit_dmg != clampf(value, 1.0, Balance.NET_MAX_DOT_STAT):
			return "DoT update escaped join validation envelope"
		if host.peer_chars[pid].crit != shell.crit or host.peer_chars[pid].crit_dmg != shell.crit_dmg or host.peer_chars[pid].has("magpen"):
			return "DoT cache stored unvalidated combat fields"
	return ""


## Guest-applied burn and bleed ride the real status RPC; the host must resolve
## its own shell as the source and tick off the owner's current sheet.
static func _ticks(g: Game, host: Node, guest: Node, p: Player) -> String:
	var e := _enemy(host.game)
	host.net_enemies[47] = e
	guest.guest_enemy_status(47, "burn", {"dps": 20.0, "dur": 3.0})
	guest.guest_enemy_status(47, "bleed", {"dps": 30.0, "dur": 3.0})
	var landed: bool = await _fence(g, guest, host, 1)
	var source: Player = host._player_of(p.peer_id)
	var error := ""
	if not landed:
		error = "DoT status RPCs never reached the host"
	elif source == null or e.burn_src != source or e.bleed_src != source:
		error = "DoT RPC did not resolve server-side source"
	else:
		error = _damage(e, p)
	host.net_enemies.erase(47)
	e.free()
	return error


static func _enemy(g: Game) -> Enemy:
	var e := Enemy.make(g, "wolf", Vector2.ZERO, -1, 1.0)
	g.add_child(e)
	e.set_physics_process(false)
	e.set_process(false)
	e.hp = 100000.0
	e.max_hp = e.hp
	e.traits = {}
	e.critres = 0.0
	e.retarget_t = 100.0
	e.stun_time = 100.0
	return e


static func _tick_damage(g: Game, source: Player, expected: Player) -> String:
	var e := _enemy(g)
	e.apply_burn(20.0, 3.0, Color.WHITE, source)
	e.apply_bleed(30.0, 3.0, source)
	var error := _damage(e, expected)
	e.free()
	return error


static func _damage(e: Enemy, p: Player) -> String:
	# Separate each status so a matching sum cannot hide one incorrect tick.
	for kind in ["burn", "bleed"]:
		e.burn_time = 3.0 if kind == "burn" else 0.0
		e.bleed_time = 3.0 if kind == "bleed" else 0.0
		# Expiry cleanup clears the inactive source; re-establish both explicitly.
		if kind == "bleed":
			e.apply_bleed(30.0, 3.0, e.burn_src)
		for tick_seed in range(10):
			seed(tick_seed)
			var expected := (10.0 if kind == "burn" else 15.0) * (p.crit_dmg if randf() < Stats.crit_curve(p.crit) else 1.0)
			seed(tick_seed)
			e.burn_tick = 0.0
			e.bleed_tick = 0.0
			var before := e.hp
			e._physics_process(0.01)
			if not is_equal_approx(before - e.hp, expected):
				return "seeded %s tick used stale stats: got %s expected %s" % [kind, before - e.hp, expected]
	return ""
