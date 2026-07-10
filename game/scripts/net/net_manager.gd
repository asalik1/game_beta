## NETWORK MANAGER — the transport seam (MULTIPLAYER.md §3.3), autoload.
## Owns everything transport-shaped: creating/joining sessions, the lobby
## code, the version gate, and peer lifecycle signals. Gameplay code speaks
## only 32-bit peer ids and talks to THIS node — never to ENet, noray or
## (later) Steam directly. That one discipline is what makes the Steam swap,
## the headless dedicated server and the mobile port deployment changes
## instead of rewrites (§10).
##
## This wave (MP-05) establishes SESSIONS only: host/join, the NET_VERSION
## auth handshake, peer tracking. No player spawning, no gameplay wiring —
## that's wave 4. host()/join() are coroutines: always `await` them.
##
## REFERENCING THIS AUTOLOAD: never by the bare `NetworkManager` identifier —
## check_compile.gd runs in --script mode where autoload named globals don't
## exist, so that identifier is a COMPILE ERROR under the gate. Instead:
##   var net: Node = get_node("/root/NetworkManager")       # the instance
##   const NetManager := preload("res://scripts/net/net_manager.gd")  # consts
extends Node

## A remote peer passed the version gate and joined the session. char_info
## is the guest's character block — EMPTY until wave 4's character handoff.
signal peer_joined(id: int, char_info: Dictionary)
## An admitted peer left (any reason). Fired on every remaining machine.
signal peer_left(id: int)
## This machine's session is over (we left, the host closed, the connection
## failed, or the host refused us). reason is player-readable — surface it.
signal session_ended(reason: String)
## HOST-side: a joiner was refused pre-admission (version gate). The lobby
## UI can toast it ("a friend is on the wrong build") — the joiner never
## half-joins (§3.4).
signal peer_rejected(id: int, reason: String)

enum Mode {
	OFFLINE,      ## no session
	ENET_DIRECT,  ## dev loopback / LAN: code is an "ip:port" string
	NORAY,        ## noray NAT punchthrough + relay fallback: code is an OID
}

## Bump on ANY netcode or content change that breaks cross-build play
## (§3.4). Printed on the title screen later so "you're on 0.1.0, I'm on
## 0.1.1" is readable without debugging. The auth handshake compares this
## EXACTLY — mismatch means a clean refusal, never a half-join.
const NET_VERSION := "0.1.0"

# --------------------------------------------------- network constants ---
# Transport plumbing, not gameplay tuning — so they live here, not in
# balance.gd (party scalars etc. stay there).
const MAX_GUESTS := 3                 # host + 3 = 4-player parties (§0)
const DEFAULT_ADDRESS := "127.0.0.1"  # ENET_DIRECT dev default
const DEFAULT_PORT := 9999
const AUTH_TIMEOUT := 5.0             # s a joiner may dawdle pre-admission
const REJECT_LINGER := 0.4            # s to let the refusal packet flush
                                      # before dropping the peer
# ENet keepalive tuning (MP-16, widened MP-17). The transport's default drops
# a silently dead peer only after up to 30 s — too long a hang for "the
# connection died" (a killed host, a yanked cable). But the MP-17 soak proved
# the first 5-8 s band FALSE-DROPS a healthy guest under sustained load (a
# 3-process full-party soak lost a guest ~50 s in — the same signature a
# genuinely laggy internet link will show at real 2-4p). 8-15 s rides out
# hitches and real-latency spikes while still surfacing a dead host ~2-4x
# faster than the engine default. If friends report mid-fight drops, raise
# MAX further before suspecting anything else.
const PEER_TIMEOUT_LIMIT := 32        # round-trip factor (engine default)
const PEER_TIMEOUT_MIN := 8000        # ms — the floor (localhost lands here)
const PEER_TIMEOUT_MAX := 15000       # ms — the ceiling (was 30000 default, 8000 in MP-16)
const NORAY_ADDRESS := "tomfol.io"    # free public instance (§3.2) — fine
const NORAY_PORT := 8890              # for the friends phase; self-host later
const NORAY_TIMEOUT := 10.0           # s for each noray registration step

const NorayClient := preload("res://addons/netfox.noray/noray.gd")
const NorayHandshake := preload("res://addons/netfox.noray/packet-handshake.gd")
const NetSession := preload("res://scripts/net/net_session.gd")

var mode: int = Mode.OFFLINE
## What the host shows on screen: "ip:port" (ENET_DIRECT) or the noray OID.
var session_code := ""
## Admitted peers (post-auth), by id. Solo/offline: empty.
var peers: Array[int] = []
## Client-side: why the host refused us (kept so the disconnect that follows
## a rejection can surface the real reason, not just "connection lost").
var last_reject_reason := ""
## MP-16: a player-readable notice to surface on the NEXT title screen. Set
## when a guest's session ends mid-run (host loss) and the scene reloads to
## the title — this autoload SURVIVES reload_current_scene, so the message
## outlives the world it belonged to. menus.open_title reads and clears it.
var last_session_notice := ""
## TESTS ONLY: what this machine CLAIMS as its version when joining. Lets
## net_test.gd drive the mismatch path through production code. Empty = truth.
var version_override := ""
## HOST-side lobby gate (MP-08, MULTIPLAYER.md §5.1): joins are accepted
## only while the lobby is open. The lobby UI closes it at chapter start
## (no mid-run joins in v1); a late knock gets a clean, readable refusal
## through the same pre-admission machinery as the version gate. Default
## OPEN so the dev CLI (--mp-host) and the net_test harnesses keep their
## join-anytime behavior; _end_session resets it for the next session.
var lobby_open := true

## The gameplay bridge (MP-07): a stable-path child ("Session") every
## peer shares, so its RPCs (join snapshot, spawn fan-out, movement
## sync) resolve identically everywhere. See net_session.gd.
var session: Node = null

var _session_active := false
var _noray: Node = null       # noray.gd instance (lazy child)
var _handshake: Node = null   # packet-handshake.gd instance (lazy child)
var _noray_role := 0          # 0 none / 1 host / 2 joiner
var _noray_join_oid := ""


func _ready() -> void:
	# Sessions must survive whatever the local pause state is (§5.4).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var smp := _scene_mp()
	smp.auth_callback = _on_auth_received
	smp.auth_timeout = AUTH_TIMEOUT
	smp.peer_authenticating.connect(_on_peer_authenticating)
	smp.peer_authentication_failed.connect(_on_auth_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	session = NetSession.new()
	session.name = "Session"  # /root/NetworkManager/Session on every peer
	add_child(session)
	_check_smoke_args()


# ------------------------------------------------------------ sessions ---

## Start hosting. ENET_DIRECT: `code` is an optional "ip:port" to listen on
## (default 127.0.0.1:9999 — the ip half is only what's shown in
## session_code; the server listens on all interfaces). NORAY: `code` is an
## optional noray server override ("host[:port]", default the public
## instance). Coroutine — await it. OK = listening; session_code is set.
func host(p_mode: int = Mode.ENET_DIRECT, code: String = "") -> Error:
	if _session_active:
		return ERR_ALREADY_IN_USE
	match p_mode:
		Mode.ENET_DIRECT:
			return _host_enet(code)
		Mode.NORAY:
			var err: Error = await _host_noray(code if code != "" else NORAY_ADDRESS)
			return err
	return ERR_INVALID_PARAMETER

## Join a session by code. A code containing ":" (or empty) is an
## ENET_DIRECT "ip:port"; anything else is a noray OID lobby code.
## Coroutine — await it. OK only means the ATTEMPT started: admission is
## signaled by peer_joined(1, ...), refusal/failure by session_ended(reason).
func join(code: String) -> Error:
	if _session_active:
		return ERR_ALREADY_IN_USE
	if code == "" or code.contains(":"):
		return _join_enet(code)
	var err: Error = await _join_noray(code)
	return err

## Leave/close the current session (host: drops every guest). Safe to call
## when offline (no-op). Emits session_ended locally.
func leave() -> void:
	_end_session("session closed")

func is_online() -> bool:
	return _session_active

func is_host() -> bool:
	return _session_active and multiplayer.is_server()


# --------------------------------------------------------- ENet direct ---

func _host_enet(listen: String) -> Error:
	var address := DEFAULT_ADDRESS
	var port := DEFAULT_PORT
	if listen.contains(":"):
		var parts := listen.split(":")
		if parts[0] != "":
			address = parts[0]
		port = int(parts[1])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_GUESTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.ENET_DIRECT
	session_code = "%s:%d" % [address, port]
	last_reject_reason = ""
	_session_active = true
	return OK

func _join_enet(code: String) -> Error:
	var address := DEFAULT_ADDRESS
	var port := DEFAULT_PORT
	if code.contains(":"):
		var parts := code.split(":")
		if parts[0] != "":
			address = parts[0]
		if parts[1] != "":
			port = int(parts[1])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.ENET_DIRECT
	session_code = "%s:%d" % [address, port]
	last_reject_reason = ""
	_session_active = true
	return OK


# ------------------------------------------------- version gate (§3.4) ---
# SceneMultiplayer's authentication phase holds a joiner in pre-admission:
#   joiner  --{version}-->  host          (on peer_authenticating)
#   host: match    --{ok:true}--> joiner, complete_auth  -> peer_connected
#   host: mismatch --{ok:false, reason}--> joiner, then disconnect_peer
#         -> joiner stores the reason, surfaces it via session_ended
# Silence on either side is covered by auth_timeout (~5 s).

func _client_version() -> String:
	return version_override if version_override != "" else NET_VERSION

func _on_peer_authenticating(id: int) -> void:
	if multiplayer.is_server():
		return  # host waits for the joiner's hello; auth_timeout covers silence
	if id != 1:
		return
	var hello := {"version": _client_version()}
	_scene_mp().send_auth(1, JSON.stringify(hello).to_utf8_buffer())

func _on_auth_received(id: int, data: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	var msg: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if multiplayer.is_server():
		if msg.is_empty():
			_reject(id, "malformed hello — not an Emberfall client?")
			return
		var theirs: String = str(msg.get("version", "<none>"))
		if theirs != NET_VERSION:
			_reject(id, "version mismatch — host runs %s, you run %s" % [NET_VERSION, theirs])
			return
		if not lobby_open:
			# MP-08 (§5.1): the lobby locked at chapter start — no mid-run
			# joins in v1. The reason reads plainly on the joiner's screen.
			_reject(id, "the party has already set out — this session stopped taking joiners when the chapter began")
			return
		_scene_mp().send_auth(id, JSON.stringify({"ok": true, "version": NET_VERSION}).to_utf8_buffer())
		_scene_mp().complete_auth(id)
	else:
		if bool(msg.get("ok", false)):
			_scene_mp().complete_auth(1)
		else:
			# Keep the reason: the drop that follows surfaces it (session_ended).
			last_reject_reason = str(msg.get("reason", "the host refused the connection"))

## HOST: refuse a joiner with a reason it can show its player, then drop it.
func _reject(id: int, reason: String) -> void:
	_scene_mp().send_auth(id, JSON.stringify({"ok": false, "reason": reason}).to_utf8_buffer())
	peer_rejected.emit(id, reason)
	await get_tree().create_timer(REJECT_LINGER).timeout  # let the packet flush
	if _scene_mp().get_authenticating_peers().has(id):
		_scene_mp().disconnect_peer(id)

func _on_auth_failed(id: int) -> void:
	if multiplayer.is_server():
		return  # a pending joiner timed out / was refused — it never joined
	if id != 1:
		return
	var reason := last_reject_reason
	if reason == "":
		reason = "authentication failed (timed out)"
	_end_session(reason)


# ------------------------------------------------------- peer lifecycle ---

func _on_peer_connected(id: int) -> void:
	peers.append(id)
	_tune_peer_timeout(id)  # MP-16: cap silent-death detection to ~5-8 s
	peer_joined.emit(id, {})  # char_info: wave 4 (character handoff)

func _on_peer_disconnected(id: int) -> void:
	if id in peers:
		peers.erase(id)
		peer_left.emit(id)

func _on_connected_to_server() -> void:
	_tune_peer_timeout(1)  # MP-16: the guest tightens ITS view of the host too


## MP-16: tighten a freshly-connected peer's ENet keepalive so a silent
## death is noticed in the 5-8 s band, not the 30 s default. Best-effort —
## only ENet transports expose per-peer timeouts (noray hands back an ENet
## peer too; the offline peer does not).
func _tune_peer_timeout(id: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(id)
		if pp != null:
			pp.set_timeout(PEER_TIMEOUT_LIMIT, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)


## MP-16, HOST: drop an ADMITTED peer that never finished joining — a ghost
## holding a lobby seat (killed mid-world-build, or wedged). Disconnects it
## at the transport and reaps our roster IMMEDIATELY: a dead ghost never ACKs
## the graceful close, so we don't wait on the transport's own event (a later
## peer_disconnected, if it ever comes, no-ops on the already-erased id).
func drop_peer(id: int) -> void:
	if not _session_active or not multiplayer.is_server():
		return
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		(mp as ENetMultiplayerPeer).disconnect_peer(id, false)
	if id in peers:
		peers.erase(id)
		peer_left.emit(id)

func _on_connection_failed() -> void:
	_end_session("could not connect to the host")

func _on_server_disconnected() -> void:
	var reason := last_reject_reason
	if reason == "":
		reason = "the host closed the session"
	_end_session(reason)

func _end_session(reason: String) -> void:
	if not _session_active:
		return
	_session_active = false
	mode = Mode.OFFLINE
	session_code = ""
	peers.clear()
	lobby_open = true  # the next session starts with an open lobby (MP-08)
	if _noray != null:
		_noray.disconnect_from_host()
	_noray_role = 0
	var old := multiplayer.multiplayer_peer
	if old != null and not (old is OfflineMultiplayerPeer):
		old.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_ended.emit(reason)


# ------------------------------------------------------- noray (§3.2) ---
# Structured after the upstream noray-bootstrapper example; UNTESTED against
# live noray servers as of MP-05 (no test depends on one). Manual smoke:
#   game.exe -- --noray-smoke-host          (prints the lobby code)
#   game.exe -- --noray-smoke-join=<OID>

func _ensure_noray() -> void:
	if _noray != null:
		return
	_noray = NorayClient.new()
	_noray.name = "Noray"
	add_child(_noray)
	_handshake = NorayHandshake.new()
	_handshake.name = "PacketHandshake"
	add_child(_handshake)
	_noray.on_connect_nat.connect(_on_noray_connect_nat)
	_noray.on_connect_relay.connect(_on_noray_connect_relay)

## Connect to the noray server + register: after OK, _noray has oid/pid and
## a punched local_port (the port we must both listen on and connect from).
func _noray_register(server: String) -> Error:
	_ensure_noray()
	var address := server
	var port := NORAY_PORT
	if server.contains(":"):
		var parts := server.split(":")
		address = parts[0]
		port = int(parts[1])
	var err: Error = await _noray.connect_to_host(address, port)
	if err != OK:
		return err
	_noray.register_host()
	var got_pid: bool = await _wait_for(func() -> bool: return str(_noray.pid) != "", NORAY_TIMEOUT)
	if not got_pid:
		return ERR_TIMEOUT
	var remote_err: Error = await _noray.register_remote()
	return remote_err

func _host_noray(server: String) -> Error:
	var err: Error = await _noray_register(server)
	if err != OK:
		return err
	_noray_role = 1
	var listen_port: int = _noray.local_port
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_server(listen_port, MAX_GUESTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.NORAY
	session_code = str(_noray.oid)  # the OID *is* the lobby code (§3.2)
	last_reject_reason = ""
	_session_active = true
	return OK

func _join_noray(oid: String) -> Error:
	var err: Error = await _noray_register(NORAY_ADDRESS)
	if err != OK:
		return err
	_noray_role = 2
	_noray_join_oid = oid
	mode = Mode.NORAY
	session_code = oid
	last_reject_reason = ""
	_session_active = true
	var nat_err: Error = _noray.connect_nat(oid)
	return nat_err

func _on_noray_connect_nat(address: String, port: int) -> void:
	var err: Error = await _noray_handle_connect(address, port)
	if err != OK and _noray_role == 2:
		# NAT punch failed — fall back to the relay automatically (§3.2).
		_noray.connect_relay(_noray_join_oid)

func _on_noray_connect_relay(address: String, port: int) -> void:
	var err: Error = await _noray_handle_connect(address, port)
	if err != OK and _noray_role == 2:
		_end_session("could not reach the host (relay failed: %s)" % error_string(err))

func _noray_handle_connect(address: String, port: int) -> Error:
	var local_port: int = _noray.local_port
	if local_port <= 0:
		return ERR_UNCONFIGURED
	if _noray_role == 1:
		# HOST: blast a handshake back so the joiner's packets punch through.
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer == null:
			return ERR_UNCONFIGURED
		var host_err: Error = await _handshake.over_enet_peer(peer, address, port)
		return host_err
	if _noray_role != 2:
		return ERR_UNAVAILABLE
	# JOINER: punch over UDP, then ENet-connect FROM the registered port.
	var udp := PacketPeerUDP.new()
	udp.bind(local_port)
	udp.set_dest_address(address, port)
	var err: Error = await _handshake.over_packet_peer(udp)
	udp.close()
	if err != OK and err != ERR_BUSY:  # ERR_BUSY = partial handshake, try anyway
		return err
	var client_peer := ENetMultiplayerPeer.new()
	err = client_peer.create_client(address, port, 0, 0, 0, local_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = client_peer
	return OK


# ------------------------------------------------------------- helpers ---

func _scene_mp() -> SceneMultiplayer:
	return multiplayer as SceneMultiplayer

## Wall-clock bounded poll — NEVER an unbounded await (a hung headless
## engine looks like a slow run; house rule).
func _wait_for(pred: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if pred.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return pred.call()

## Manual noray smoke hooks (dev-only; nothing in the test suites uses the
## public noray instance — MP-05 rule).
func _check_smoke_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var s := str(arg)
		if s == "--noray-smoke-host" or s.begins_with("--noray-smoke-host="):
			_smoke_host(s.get_slice("=", 1) if s.contains("=") else "")
		elif s.begins_with("--noray-smoke-join="):
			_smoke_join(s.get_slice("=", 1))

func _smoke_host(server: String) -> void:
	var err: Error = await host(Mode.NORAY, server)
	print("[net] noray smoke host: %s — lobby code: %s" % [error_string(err), session_code])

func _smoke_join(oid: String) -> void:
	var err: Error = await join(oid)
	print("[net] noray smoke join(%s): %s" % [oid, error_string(err)])
