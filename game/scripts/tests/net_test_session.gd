extends Node
## NET SESSION TEST — the MP-07 gameplay-bridge harness. Two REAL game
## instances (host + guest) share one world over localhost ENet and the
## test asserts the wave-4 exit criteria end to end:
##   (a) the guest completes the seed/flags handshake and rebuilds the
##       SAME world locally (wander_seed + room-layout signature match
##       across processes);
##   (b) both instances report players.size() == 2 with matching
##       peer_ids (host 1 + the guest's session id);
##   (c) the guest drives its own player via real input intents and the
##       HOST sees that player displaced through the 20 Hz movement sync;
##   (d) a clean guest leave shrinks the host's roster back to 1.
##
## Same discipline as net_test.gd (MP-05): one script, two roles picked
## by `--net-role=`; the host orchestrates and SPAWNS the guest process
## itself (pids tracked, OS.kill on every failure path); every wait is a
## WALL-CLOCK bounded poll; localhost only. Run via net_test.bat (the
## compile gate runs first — a parse error would hang headless forever).
##
## GATE TRAP (MP-05): reference the autoload via get_node — the bare
## `NetworkManager` identifier does not compile under check_compile.

# Off the dev default (9999) AND net_test.gd's 48211.
const PORT := 48213
const STEP_TIMEOUT := 30.0   # s per observable step (boots include a world build)
const EXIT_TIMEOUT := 15.0   # s for the guest process to exit after its work
const MOVE_THRESHOLD := 120.0  # px the host must see the guest player travel

var game: Game = null
var _net: Node = null
var _pids: Array[int] = []
var _left: Array[int] = []          # peer_left ids (host side)
var _report := {}                   # the guest's cross-process report (host side)
var _drive := false                 # guest: host said GO (movement step)
var _seen_move := 0.0               # host: farthest displacement observed


func _ready() -> void:
	_net = get_node("/root/NetworkManager")
	var role := "host"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--net-role="):
			role = str(arg).get_slice("=", 1)
	_net.peer_left.connect(func(id: int) -> void: _left.append(id))
	match role:
		"host":
			_run_host()
		"guest":
			_run_guest()
		_:
			_fail("unknown --net-role=%s" % role)


# ------------------------------------------------------------- the host ---

func _run_host() -> void:
	# A real game, hosting from boot (--mp-host seam, set directly the way
	# the CLI parse would): the session listens while the character flow
	# runs — exactly the dev-host entry.
	game = load("res://scenes/main.tscn").instantiate()
	game.no_saves = true
	game.mp_host = true
	game.mp_host_code = "127.0.0.1:%d" % PORT
	add_child(game)
	await _frames(10)

	# The roster path the suites use: chapter -> class -> opening beats.
	if not (game.menus.is_open() and game.menus.current == "chapter_select"):
		return _fail("chapter select did not open")
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_story()
	if not await _wait_for(func() -> bool: return game.play_started, STEP_TIMEOUT, "host play_started"):
		return
	if not await _wait_for(func() -> bool: return _net.is_online() and _net.is_host(), STEP_TIMEOUT, "host session listening"):
		return
	print("[net_session] host: playing (seed %d) and listening on %s" % [game.wander_seed, _net.session_code])

	# Bring in the guest — a second REAL game instance.
	if _spawn_peer("guest") < 0:
		return _fail("could not spawn the guest process")

	# (a) seed handshake: the guest reports what it built.
	if not await _wait_for(func() -> bool: return not _report.is_empty(), STEP_TIMEOUT, "guest world report"):
		return
	if int(_report.get("seed", -1)) != game.wander_seed:
		return _fail("guest built seed %s, host has %d" % [str(_report.get("seed")), game.wander_seed])
	if String(_report.get("sig", "")) != _layout_sig():
		return _fail("guest layout differs: %s vs %s" % [str(_report.get("sig")), _layout_sig()])
	if String(_report.get("chapter", "")) != game.chapter_id:
		return _fail("guest chapter %s != host %s" % [str(_report.get("chapter")), game.chapter_id])
	print("[net_session] host: guest rebuilt the world — seed %d + layout signature match (%d rooms)"
		% [game.wander_seed, game.zone_count])

	# (b) both rosters hold two players with matching peer ids.
	var guest_id: int = _net.peers[0] if not _net.peers.is_empty() else -1
	if guest_id <= 1:
		return _fail("no admitted guest peer id")
	if not await _wait_for(func() -> bool: return game.players.size() == 2, STEP_TIMEOUT, "host roster of 2"):
		return
	var host_ids := _peer_ids()
	if not (host_ids.has(1) and host_ids.has(guest_id)):
		return _fail("host roster peer_ids %s lack [1, %d]" % [str(host_ids), guest_id])
	var guest_ids: Array = _report.get("peers", [])
	if not (guest_ids.has(1) and guest_ids.has(guest_id)):
		return _fail("guest roster peer_ids %s lack [1, %d]" % [str(guest_ids), guest_id])
	var remote := _player_of(guest_id)
	if remote == null or remote.is_locally_controlled():
		return _fail("the guest's player must exist here and NOT be locally controlled")
	if remote.cls != String(_report.get("cls", "")):
		return _fail("guest spawned as %s here, reports %s" % [remote.cls, str(_report.get("cls"))])
	print("[net_session] host: players.size()==2 both sides — peer_ids [1, %d], guest is a remote %s"
		% [guest_id, remote.cls])

	# (c) movement over the wire. Let the first snapshots settle the
	# remote onto the owner's true position, take a baseline, THEN tell
	# the guest to move — so displacement measures the drive, not the
	# spawn-to-sync correction.
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(remote):
		return _fail("remote player vanished before the movement step")
	var baseline: Vector2 = remote.global_position
	_seen_move = 0.0
	_rpc_drive.rpc_id(guest_id)
	var moved := func() -> bool:
		if is_instance_valid(remote):
			_seen_move = maxf(_seen_move, baseline.distance_to(remote.global_position))
		return _seen_move > MOVE_THRESHOLD
	if not await _wait_for(moved, STEP_TIMEOUT, "guest movement seen host-side (>%.0f px)" % MOVE_THRESHOLD):
		return
	print("[net_session] host: saw the guest player travel %.1f px (threshold %.0f)"
		% [_seen_move, MOVE_THRESHOLD])

	# (d) clean leave: the roster shrinks back to just us.
	if not await _wait_for(func() -> bool: return _left.has(guest_id), STEP_TIMEOUT, "guest peer_left"):
		return
	if not await _wait_for(func() -> bool: return game.players.size() == 1, 5.0, "host roster back to 1"):
		return
	if game.local_player == null or not is_instance_valid(game.local_player):
		return _fail("host lost its own player on the guest leave")
	print("[net_session] host: guest left cleanly — players.size()==1 again")
	if not await _wait_exit("guest"):
		return

	print("NET TEST PASS")
	get_tree().quit(0)


# ------------------------------------------------------------ the guest ---

func _run_guest() -> void:
	# A real game joining by code — the --mp-join seam, set directly the
	# way the CLI parse would. No title flow; the handshake does the rest.
	game = load("res://scenes/main.tscn").instantiate()
	game.no_saves = true
	game.mp_join_code = "127.0.0.1:%d" % PORT
	game.mp_cls = "archer"  # a different class proves the char block travels
	add_child(game)

	var sess: Node = get_node("/root/NetworkManager/Session")
	if not await _wait_for(func() -> bool: return bool(sess.world_ready), STEP_TIMEOUT, "world snapshot + rebuild"):
		return
	var snap: Dictionary = sess.last_snapshot
	if game.wander_seed != int(snap.get("wander_seed", -1)):
		return _fail("applied seed %d != snapshot seed %s" % [game.wander_seed, str(snap.get("wander_seed"))])
	if not game.play_started or game.player.cls != "archer":
		return _fail("guest entry incomplete (play_started %s, cls %s)" % [str(game.play_started), game.player.cls])
	if not game.player.is_locally_controlled():
		return _fail("the guest's own player must stay locally controlled")

	# The host's player must appear HERE too (spawn fan-out).
	if not await _wait_for(func() -> bool: return game.players.size() == 2, STEP_TIMEOUT, "guest roster of 2"):
		return
	var host_copy := _player_of(1)
	if host_copy == null or host_copy.is_locally_controlled():
		return _fail("the host's player must exist here and NOT be locally controlled")
	print("[net_session] guest: world rebuilt (seed %d), roster %s" % [game.wander_seed, str(_peer_ids())])

	# Report the build to the orchestrator, then await the GO.
	_rpc_report.rpc_id(1, {"seed": game.wander_seed, "sig": _layout_sig(),
		"chapter": game.chapter_id, "peers": _peer_ids(), "cls": game.player.cls})
	if not await _wait_for(func() -> bool: return _drive, STEP_TIMEOUT, "drive command from the host"):
		return

	# Drive our OWN player through the real intents path: a synthesized
	# held key fills intent_move exactly like a hand on the keyboard
	# (the autotest idiom). Cycle directions in case scenery blocks one.
	var start: Vector2 = game.player.global_position
	for key in [KEY_D, KEY_S, KEY_A, KEY_W]:
		_press(key, true)
		var deadline: int = Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.1).timeout
			if start.distance_to(game.player.global_position) > MOVE_THRESHOLD + 60.0:
				break
		_press(key, false)
		if start.distance_to(game.player.global_position) > MOVE_THRESHOLD + 60.0:
			break
	var dist := start.distance_to(game.player.global_position)
	if dist <= MOVE_THRESHOLD:
		return _fail("guest player barely moved (%.1f px)" % dist)
	print("[net_session] guest: drove own player %.1f px via intents" % dist)

	# Linger a few ticks so the host's interpolation sees the travel,
	# then leave CLEANLY — the host asserts the roster shrink.
	await get_tree().create_timer(1.0).timeout
	_net.leave()
	await get_tree().create_timer(0.5).timeout
	print("[net_session] guest: left cleanly")
	get_tree().quit(0)


# ------------------------------------------------------- cross-process ---

## Guest -> host: what the guest actually built (assert material).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_report(data: Dictionary) -> void:
	if multiplayer.is_server():
		_report = data


## Host -> guest: start the movement step NOW (the host has its baseline).
@rpc("authority", "call_remote", "reliable")
func _rpc_drive() -> void:
	_drive = true


# ------------------------------------------------------------- helpers ---

## Advance the boot story beats the way autotest does: linear lines
## advance, a choice takes option 0. Bounded — never an unbounded await.
func _skip_story() -> void:
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 200:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(1)
		guard += 1


func _press(key: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key as Key
	ev.physical_keycode = key as Key
	ev.pressed = down
	Input.parse_input_event(ev)


func _player_of(pid: int) -> Player:
	for p in game.players:
		if p != null and is_instance_valid(p) and p.peer_id == pid:
			return p
	return null


func _peer_ids() -> Array:
	var out: Array = []
	for p in game.players:
		if p != null and is_instance_valid(p):
			out.append(p.peer_id)
	out.sort()
	return out


## Fingerprint of the generated layout (room coords in index order —
## the test_base._layout_sig idiom): equal iff both processes derived
## the same world from the seed.
func _layout_sig() -> String:
	var bits: Array = []
	for i in game.zone_count:
		bits.append(str(game.rooms[i]["coord"]))
	return ",".join(bits)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Spawn a sibling headless instance of THIS scene in the given role.
func _spawn_peer(role: String) -> int:
	var args := [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/net_test_session.tscn",
		"--", "--net-role=%s" % role,
	]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid > 0:
		_pids.append(pid)
	return pid


## Wait for the most recently spawned peer to exit with code 0 (its own
## in-process assertions all passed).
func _wait_exit(label: String) -> bool:
	var pid: int = _pids[-1]
	if not await _wait_for(func() -> bool: return not OS.is_process_running(pid), EXIT_TIMEOUT, "%s process exit" % label):
		return false
	var code := OS.get_process_exit_code(pid)
	if code != 0:
		_fail("%s exited %d — its own assertions failed" % [label, code])
		return false
	return true


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
