extends Node
## NET TEST — NetworkManager session harness (MP-05). NOT an autotest
## section: it needs multiple PROCESSES (real sockets, real auth packets),
## so it gets its own scene + net_test.bat instead of a hook in the suite.
##
## One script, three roles (picked by `--net-role=` after `--`):
##   host (default) — the orchestrator. Hosts on localhost ENet, SPAWNS the
##       two client processes itself (OS.create_process, pids tracked so
##       every failure path can OS.kill leftovers), and asserts the
##       host-side view. Prints NET TEST PASS / NET TEST FAIL <why>;
##       exit code 0 / 1.
##   client_ok  — joins with the real NET_VERSION: must be ADMITTED
##       (peer_joined(1)), then leaves cleanly (host must see peer_left).
##   client_bad — claims a bogus version via NetworkManager.version_override:
##       must be REJECTED pre-admission and must be able to SURFACE the
##       host's reason (session_ended mentions "version").
##
## House rules honored: every wait is a WALL-CLOCK bounded poll (an
## unbounded await on a hung headless engine looks like a slow run), and
## nothing here touches the public noray instance — localhost ENet only.
##
## GATE TRAP (new with MP-05): the bare `NetworkManager` autoload identifier
## does NOT compile under check_compile.gd (--script mode never instantiates
## autoloads, so GDScript's named globals are empty). Reference the autoload
## via get_node("/root/NetworkManager") and take enums/consts from a
## preload of its script instead.

# The autoload's script, for parse-time constants (Mode, NET_VERSION).
const NetManager := preload("res://scripts/net/net_manager.gd")

# High two-instance port: off the dev default (9999) and the ephemeral
# ranges the suites use; nothing else in the project binds it.
const PORT := 48211
const STEP_TIMEOUT := 15.0   # s per observable step (join/leave/reject)
const EXIT_TIMEOUT := 10.0   # s for a client process to exit after its work
const BAD_VERSION := "0.0.0-mismatch"

var _joined: Array[int] = []      # peer_joined ids, in order
var _left: Array[int] = []        # peer_left ids, in order
var _rejected: Array = []         # [id, reason] pairs (host side)
var _ended := false               # session_ended fired (client side)
var _ended_reason := ""
var _pids: Array[int] = []        # child Godot processes we spawned
var _net: Node = null             # the NetworkManager autoload


func _ready() -> void:
	_net = get_node("/root/NetworkManager")
	var role := "host"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--net-role="):
			role = str(arg).get_slice("=", 1)
	_net.peer_joined.connect(_on_joined)
	_net.peer_left.connect(_on_left)
	_net.peer_rejected.connect(_on_rejected)
	_net.session_ended.connect(_on_ended)
	match role:
		"host":
			_run_host()
		"client_ok":
			_run_client_ok()
		"client_bad":
			_run_client_bad()
		_:
			_fail("unknown --net-role=%s" % role)


func _on_joined(id: int, _char_info: Dictionary) -> void:
	_joined.append(id)

func _on_left(id: int) -> void:
	_left.append(id)

func _on_rejected(id: int, reason: String) -> void:
	_rejected.append([id, reason])

func _on_ended(reason: String) -> void:
	_ended = true
	_ended_reason = reason


# -------------------------------------------------------- orchestrator ---

func _run_host() -> void:
	print("[net_test] host: NET_VERSION %s, listening on 127.0.0.1:%d" % [NetManager.NET_VERSION, PORT])
	var err: Error = await _net.host(NetManager.Mode.ENET_DIRECT, "127.0.0.1:%d" % PORT)
	if err != OK:
		return _fail("host() failed: %s (port %d taken?)" % [error_string(err), PORT])

	# (a) matching version: admitted, host sees peer_joined ...
	if _spawn_client("client_ok") < 0:
		return _fail("could not spawn client_ok process")
	if not await _wait_for(func() -> bool: return _joined.size() >= 1, STEP_TIMEOUT, "peer_joined (client_ok admission)"):
		return
	print("[net_test] host: peer %d admitted" % _joined[0])

	# (c) ... and its CLEAN disconnect fires peer_left with the same id.
	if not await _wait_for(func() -> bool: return _left.size() >= 1, STEP_TIMEOUT, "peer_left (client_ok clean disconnect)"):
		return
	if _left[0] != _joined[0]:
		return _fail("peer_left id %d != peer_joined id %d" % [_left[0], _joined[0]])
	print("[net_test] host: peer %d left cleanly" % _left[0])
	if not await _wait_exit("client_ok"):
		return

	# (b) mismatched version: refused pre-admission, with a readable reason.
	if _spawn_client("client_bad") < 0:
		return _fail("could not spawn client_bad process")
	if not await _wait_for(func() -> bool: return _rejected.size() >= 1, STEP_TIMEOUT, "peer_rejected (client_bad version gate)"):
		return
	var reason: String = _rejected[0][1]
	if not reason.contains("version"):
		return _fail("reject reason doesn't name the version problem: '%s'" % reason)
	print("[net_test] host: rejected mismatched joiner — %s" % reason)
	if not await _wait_exit("client_bad"):
		return
	if _joined.size() != 1:
		return _fail("mismatched client half-joined: %d peer_joined events" % _joined.size())

	print("NET TEST PASS")
	get_tree().quit(0)

## Spawn a sibling headless instance of THIS scene in the given role.
func _spawn_client(role: String) -> int:
	var args := [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/net_test.tscn",
		"--", "--net-role=%s" % role,
	]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid > 0:
		_pids.append(pid)
	return pid

## Wait for the most recently spawned client to exit AND to have passed its
## own in-process assertions (exit code 0).
func _wait_exit(label: String) -> bool:
	var pid: int = _pids[-1]
	if not await _wait_for(func() -> bool: return not OS.is_process_running(pid), EXIT_TIMEOUT, "%s process exit" % label):
		return false
	var code := OS.get_process_exit_code(pid)
	if code != 0:
		_fail("%s exited %d — its own assertions failed" % [label, code])
		return false
	return true


# -------------------------------------------------------------- clients ---

func _run_client_ok() -> void:
	var err: Error = await _net.join("127.0.0.1:%d" % PORT)
	if err != OK:
		return _fail("client_ok join() failed: %s" % error_string(err))
	# Admission = the host (peer 1) appears post-auth on OUR side too.
	if not await _wait_for(func() -> bool: return _joined.has(1), STEP_TIMEOUT, "client_ok admission (peer_joined 1)"):
		return
	if _ended:
		return _fail("client_ok session ended unexpectedly: %s" % _ended_reason)
	# Linger a beat, then leave CLEANLY — the host asserts the peer_left.
	await get_tree().create_timer(0.5).timeout
	_net.leave()
	await get_tree().create_timer(0.5).timeout  # let the disconnect flush
	print("[net_test] client_ok: admitted and left cleanly")
	get_tree().quit(0)

func _run_client_bad() -> void:
	_net.version_override = BAD_VERSION
	var err: Error = await _net.join("127.0.0.1:%d" % PORT)
	if err != OK:
		return _fail("client_bad join() failed: %s" % error_string(err))
	if not await _wait_for(func() -> bool: return _ended, STEP_TIMEOUT, "client_bad rejection (session_ended)"):
		return
	if _joined.has(1):
		return _fail("client_bad was ADMITTED despite claiming %s" % BAD_VERSION)
	if not _ended_reason.contains("version"):
		return _fail("host's reason didn't surface — session_ended('%s')" % _ended_reason)
	print("[net_test] client_bad: refused with surfaced reason — %s" % _ended_reason)
	get_tree().quit(0)


# -------------------------------------------------------------- helpers ---

## Wall-clock bounded poll (never an unbounded await — house rule).
func _wait_for(pred: Callable, timeout: float, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if pred.call():
			return true
		await get_tree().create_timer(0.1).timeout
	if pred.call():
		return true
	_fail("TIMEOUT (%.0fs) waiting for %s" % [timeout, what])
	return false

func _fail(why: String) -> void:
	print("NET TEST FAIL  %s" % why)
	for pid in _pids:  # kill discipline: never leave a child Godot behind
		if OS.is_process_running(pid):
			OS.kill(pid)
	get_tree().quit(1)
