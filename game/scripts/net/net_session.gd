extends Node
## NET SESSION — the gameplay bridge (MP-07, wave 4). A child of the
## NetworkManager autoload named "Session", so every peer shares the
## stable node path /root/NetworkManager/Session — the one requirement
## for the @rpc calls below to resolve identically everywhere.
##
## Owns three things, in the order a session needs them:
##   1. JOIN FLOW (MULTIPLAYER.md §4.1 row 1): on admission the host
##      sends {chapter, wander_seed, flags, spawn_room} — the world is a
##      pure function of the seed, so the guest REBUILDS it locally via
##      the same switch_chapter path a save-load uses. No node state
##      ships. The guest confirms readiness with its character block;
##      only then does spawning proceed (both directions).
##   2. SPAWN FAN-OUT: every instance spawns a presentation Player for
##      every other peer ({cls, level} dev block — MP-08 hands over the
##      full character). peer_left frees it everywhere.
##   3. MOVEMENT SYNC (§3.1): each peer broadcasts its OWN player's
##      {pos, velocity, look} at MOVE_HZ over an unreliable RPC; remotes
##      buffer snapshots and render ~NET_LERP_MS in the past
##      (player.gd _remote_present).
##
## game.gd hands this node its Game instance at boot. Everything here
## no-ops offline — solo never enters this file.
##
## GATE TRAP (MP-05): never reference the `NetworkManager` global by
## name — the autoload doesn't exist under check_compile's --script
## mode. The parent node IS the autoload; use get_parent().

## The lobby roster changed (someone announced, joined or left) — the
## lobby UI redraws its party list off lobby_roster() (MP-08).
signal lobby_changed
## GUEST-side: the host's snapshot landed, the world is rebuilt and play
## has begun — any pre-session UI (the lobby wait screen) should close.
signal session_started

const MOVE_HZ := 20.0    # owner movement broadcast rate (§3.1)

var game: Node = null    # the Game instance (set by game.gd _ready)
## The LOCAL identity this machine announces (MP-08). The lobby UI sets
## {slot, cls, level, name}: slot is the joiner's OWN roster save — its
## character section loads when the host's snapshot arrives (§5.7). The
## dev CLI (--mp-join) still sets the minimal {cls, level} block; empty
## falls back to the live player.
var local_char := {}
## peer id -> character block, for every REMOTE player this instance
## has spawned. The host also uses it to brief newcomers.
var peer_chars := {}
## LOBBY-phase roster: peer id -> {name, cls, level}, announced on
## admission (before any world exists). Host-authoritative; mirrored to
## every guest so both lobby screens draw the same party (MP-08 §5.1).
var lobby_chars := {}
## Guest: the host's snapshot has been applied and the world rebuilt.
var world_ready := false
## Guest: the last snapshot received (tests assert against it).
var last_snapshot := {}

var _move_accum := 0.0


func _net() -> Node:
	return get_parent()  # the NetworkManager autoload (see header)


func _ready() -> void:
	var net := _net()
	net.peer_joined.connect(_on_peer_joined)
	net.peer_left.connect(_on_peer_left)
	net.session_ended.connect(_on_session_ended)


# ------------------------------------------------------------ join flow ---

func _on_peer_joined(id: int, _char_info: Dictionary) -> void:
	if multiplayer.is_server():
		lobby_changed.emit()  # the party list shows the knock immediately
		_send_snapshot(id)  # a guest was admitted: brief it (async)
	elif id == 1:
		if game != null and game.local_player != null:
			# WE were admitted: our own player is ours under our session id
			# from this moment (before the snapshot lands and re-stamps it).
			game.local_player.peer_id = multiplayer.get_unique_id()
		# Announce who's knocking (MP-08): name/class/level for the host's
		# lobby list, long before any world snapshot flows.
		_rpc_lobby_hello.rpc_id(1, _lobby_block())


# ------------------------------------------------- lobby roster (MP-08) ---

## GUEST -> HOST: a freshly admitted joiner announces its lobby identity.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_lobby_hello(block: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	lobby_chars[pid] = {"name": String(block.get("name", "Hero")),
		"cls": String(block.get("cls", "warrior")),
		"level": maxi(1, int(block.get("level", 1)))}
	_rpc_lobby_roster.rpc(lobby_roster())  # everyone sees the party assemble
	lobby_changed.emit()


## HOST -> GUESTS: the full lobby roster (host entry included).
@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_roster(roster: Dictionary) -> void:
	if multiplayer.is_server():
		return
	lobby_chars = roster
	lobby_changed.emit()


## The party as the lobby shows it: peer id -> {name, cls, level}. On the
## host this is authoritative (its own entry + every hello); on guests it
## is the mirrored broadcast.
func lobby_roster() -> Dictionary:
	if not multiplayer.is_server():
		return lobby_chars
	var out := {1: _lobby_block()}
	for pid in lobby_chars:
		out[int(pid)] = lobby_chars[pid]
	return out


## This machine's lobby identity: what the lobby UI picked, else the live
## player (dev CLI hosts), else a level-1 warrior.
func _lobby_block() -> Dictionary:
	var nm := String(local_char.get("name", os_name()))
	if local_char.has("cls"):
		return {"name": nm, "cls": String(local_char.get("cls", "warrior")),
			"level": maxi(1, int(local_char.get("level", 1)))}
	if game != null and game.local_player != null:
		return {"name": nm, "cls": String(game.local_player.cls),
			"level": int(game.local_player.level)}
	return {"name": nm, "cls": "warrior", "level": 1}


## Best available player-recognizable name until characters are named:
## the OS account name (what friends will recognize), else "Hero".
func os_name() -> String:
	for env in ["USERNAME", "USER"]:
		var n := OS.get_environment(env)
		if n != "":
			return n.substr(0, 16)
	return "Hero"


## HOST: ship the world snapshot to a freshly admitted guest. The host
## may still be in the title flow (--mp-host lets guests join the lobby
## before the roster pick) — wait for play_started; every lap re-checks
## that the session and the guest still exist, so this never outlives
## either.
func _send_snapshot(id: int) -> void:
	while game == null or not bool(game.play_started):
		await get_tree().create_timer(0.2).timeout
		if not _net().is_online() or not (id in _net().peers):
			return
	_rpc_world_snapshot.rpc_id(id, {
		"chapter": game.chapter_id,
		"wander_seed": game.wander_seed,
		"flags": game.flags,
		"spawn_room": game.cur_room,
	})


## GUEST: the host's world arrives. Seed purity (§2.1) makes this SMALL:
## set the seed, rebuild through the same path a save-load uses, apply
## the flags, stand in the host's room. Then confirm readiness.
@rpc("authority", "call_remote", "reliable")
func _rpc_world_snapshot(snap: Dictionary) -> void:
	if game == null or multiplayer.is_server():
		return
	last_snapshot = snap
	var g: Node = game
	var p: Node = g.local_player
	p.peer_id = multiplayer.get_unique_id()
	# The world: seed first, then the same rebuild a load performs.
	g.wander_seed = int(snap.get("wander_seed", 0))
	var fl: Dictionary = snap.get("flags", {})
	g.flags = fl.duplicate()
	g.switch_chapter(String(snap.get("chapter", "ch1")), true)
	g.guest_world = true  # from here on autosaves are character-only (§5.7)
	# The character (MP-08, §5.7): the lobby put the joiner's OWN roster
	# slot in local_char — load that save's CHARACTER section (identity,
	# gear, wallet, records) onto our player, after the rebuild exactly
	# like a solo load (so e.g. saved potions_free overwrites the teaching
	# grant). Its world half stays home: nothing of the guest's world ever
	# touches the host's, and ground-drop positions from another geometry
	# are never spawned here — they ride to the mailbox instead. The dev
	# CLI (--mp-join) still rides the minimal {cls, level} block below.
	var slot: int = int(local_char.get("slot", 0))
	var applied := false
	if slot > 0:
		var data: Dictionary = SaveGame.read(slot)
		if not data.is_empty():
			g.save_slot = slot  # autosaves write the character home (§5.7)
			SaveGame.apply_character(g, SaveGame.character_of(data), false)
			applied = true
	if not applied:
		var cls := String(local_char.get("cls", p.cls))
		if p.cls != cls:
			p.set_class(cls)
		p.level = maxi(1, int(local_char.get("level", p.level)))
		p.recalc()
		p.hp = p.max_hp
		p.mp = p.max_mp
	g._recheck_gates()  # flag-locked gates react to the host's story state
	var spawn: int = clampi(int(snap.get("spawn_room", 0)), 0, int(g.zone_count) - 1)
	p.global_position = g.room_center(spawn)
	g._enter_room(spawn)
	g.play_started = true
	g.request_pause(false)
	g.hud.visible = true
	world_ready = true
	# Readiness confirmed — only now does spawning proceed (§4.1).
	_rpc_join_ready.rpc_id(1, _char_block())
	session_started.emit()  # the lobby wait screen closes itself on this


## HOST: a guest finished its world build and announced its character.
## Spawn it here, brief IT about everyone already present, and brief
## everyone already present about IT.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_ready(block: Dictionary) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	# The newcomer learns the roster so far: the host's player...
	_rpc_spawn_player.rpc_id(pid, 1, _char_block())
	# ...and every guest that is already standing in the world.
	for q in peer_chars:
		if int(q) != pid:
			_rpc_spawn_player.rpc_id(pid, int(q), peer_chars[q])
			_rpc_spawn_player.rpc_id(int(q), pid, block)
	peer_chars[pid] = block
	_spawn_remote(pid, block)


## EVERYONE: peer pid's player exists — spawn its presentation body.
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(pid: int, block: Dictionary) -> void:
	if game == null:
		return
	peer_chars[pid] = block
	_spawn_remote(pid, block)


## Build the remote Player from the owner's character block (MP-08):
## class + level drive the sprite/kit, then the owner's REAL vitals
## overwrite the class-default recalc so its bars read true. Full
## combat-stat fidelity (gear, talents) is phase 2 — these are the
## visible parts. Owner gets peer_id + multiplayer authority;
## game.register_remote_player parents it and takes the roster slot.
func _spawn_remote(pid: int, block: Dictionary) -> void:
	if game == null or pid == multiplayer.get_unique_id():
		return
	var p := Player.new()
	p.game = game
	p.peer_id = pid
	p.name = "NetPlayer%d" % pid
	p.set_multiplayer_authority(pid)
	# Stand near the local room's heart until the first movement
	# snapshot (~1 tick) snaps it onto the owner's real position.
	p.global_position = game.room_center(game.cur_room) + Vector2(40.0 * (pid % 5), 30.0)
	game.register_remote_player(p)
	p.set_class(String(block.get("cls", "warrior")))
	p.level = maxi(1, int(block.get("level", 1)))
	p.recalc()
	p.max_hp = maxf(1.0, float(block.get("max_hp", p.max_hp)))
	p.max_mp = maxf(0.0, float(block.get("max_mp", p.max_mp)))
	p.hp = clampf(float(block.get("hp", p.max_hp)), 1.0, p.max_hp)
	p.mp = clampf(float(block.get("mp", p.max_mp)), 0.0, p.max_mp)
	# The owner's display name rides as metadata until name labels land
	# (§5.6, phase 3) — nothing renders it yet, everything can reach it.
	p.set_meta("net_name", String(block.get("name", "")))


## The character block this machine announces to the session (MP-08):
## the LIVE player — by _rpc_join_ready time a joiner has already applied
## its roster character, and a host is mid-play — so class, level and the
## real vitals travel. Falls back to the dev {cls, level} block pre-boot.
func _char_block() -> Dictionary:
	var nm := String(local_char.get("name", os_name()))
	if game != null and game.local_player != null \
			and is_instance_valid(game.local_player):
		var p: Node = game.local_player
		return {"cls": String(p.cls), "level": int(p.level), "name": nm,
			"hp": float(p.hp), "max_hp": float(p.max_hp),
			"mp": float(p.mp), "max_mp": float(p.max_mp)}
	return {"cls": String(local_char.get("cls", "warrior")),
		"level": int(local_char.get("level", 1)), "name": nm}


# -------------------------------------------------------- peer lifecycle ---

func _on_peer_left(id: int) -> void:
	peer_chars.erase(id)
	lobby_chars.erase(id)
	if multiplayer.is_server() and _net().is_online():
		_rpc_lobby_roster.rpc(lobby_roster())  # guests' lists shrink too
	lobby_changed.emit()
	if game != null:
		game.unregister_player(id)


func _on_session_ended(_reason: String) -> void:
	world_ready = false
	if game != null:
		for id in peer_chars:
			game.unregister_player(int(id))
		if game.local_player != null and is_instance_valid(game.local_player):
			game.local_player.peer_id = 1  # back to the solo default
	peer_chars.clear()
	lobby_chars.clear()
	last_snapshot = {}
	lobby_changed.emit()


# --------------------------------------------------------- movement sync ---

func _physics_process(delta: float) -> void:
	if game == null or not _net().is_online() or not bool(game.play_started):
		return
	if multiplayer.get_peers().is_empty():
		return
	var p: Node = game.local_player
	if p == null or not is_instance_valid(p):
		return
	_move_accum += delta
	var step := 1.0 / MOVE_HZ
	if _move_accum < step:
		return
	_move_accum = fmod(_move_accum, step)
	_rpc_move.rpc(p.global_position, p.velocity, float(p.look_sign))


## The owner's 20 Hz movement snapshot: ~24 payload bytes over an
## unreliable channel (a lost tick is replaced 50 ms later — §3.1).
## Remotes stamp arrival time and interpolate (player_core.net_push_snapshot).
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_move(pos: Vector2, vel: Vector2, look: float) -> void:
	if game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	for q in game.players:
		if q != null and is_instance_valid(q) and q != game.local_player \
				and q.peer_id == pid:
			q.net_push_snapshot(pos, vel, look)
			return
