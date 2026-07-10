extends Node
## NET SESSION TEST — the MP-07/MP-09 gameplay-bridge harness. Two REAL
## game instances (host + guest) share one world over localhost ENet.
##
## STAGE 2 (default — MP-07 exit criteria):
##   (a) the guest completes the seed/flags handshake and rebuilds the
##       SAME world locally (wander_seed + room-layout signature match
##       across processes);
##   (b) both instances report players.size() == 2 with matching
##       peer_ids (host 1 + the guest's session id);
##   (c) the guest drives its own player via real input intents and the
##       HOST sees that player displaced through the 20 Hz movement sync;
##   (d) a clean guest leave shrinks the host's roster back to 1.
##
## STAGE 3 (`--net-stage=3` — MP-09 exit criteria, combat over the wire):
##   the host spawns wolves + a boss through the real paths and the guest
##   must SEE them — mirror census matches the host registry (all gated,
##   collisionless), a host-side position change is tracked by the mirror,
##   hp sync moves the overhead bar, a play_action broadcast lights the
##   mirror's ability strip, the boss bar shows with the right name, a
##   telegraph event renders, and a host-side kill frees the mirror.
##
## STAGE 4 (`--net-stage=4` — MP-10 exit criteria, the guest FIGHTS):
##   (a) the guest drives a REAL ability through intents at a mirror —
##       the host's enemy hp drops by exactly the RPC'd amount and the
##       mirror re-converges on the authoritative fraction;
##   (b) a guest-applied burn rider burns the HOST's enemy (src = the
##       guest's shell; dps ticks host-side);
##   (c) a host-side hit on the guest's shell forwards to the owner — the
##       guest's REAL hp drops, and the shell's bar follows via vitals;
##   (d) the guest's own projectiles (fan of knives) kill a slivered mob
##       through the physics layer — the death event frees the mirror and
##       the kill XP reaches the guest; the host saw the visual copies;
##   (e) a host-side HOSTILE projectile spawn event renders guest-side;
##   (f) a boss untargetable phase flag reaches the mirror (state bit 2).
##
## STAGE 5 (`--net-stage=5` — MP-11 exit criteria, loot instancing):
##   (s) SOLO regression before any guest exists: one paying kill pays
##       the host EXACTLY the drop_gold coin math — no double-apply
##       through the new party seams;
##   (a) party kill: the guest gets its OWN pile (spawned guest-side
##       only — the host holds exactly its own coins), both wallets grow
##       independently, and the guest's shell standing on the host's
##       coins never eats them (pickup ownership gate);
##   (b) boss kill: both sides get their OWN golden chest; the guest
##       opening ITS copy leaves the host's UNOPENED (chest trigger
##       gate, no chest.gd edits), then each side collects its own
##       contents roll (items logged from both machines);
##   (c) a crafted award package (gem + stone + bag) lands in the
##       guest's own bags through the personal-event machinery;
##   (d) a guest-side ground drop flushes into the GUEST's mailbox —
##       and never the host's.
##
## Same discipline as net_test.gd (MP-05): one script, roles picked by
## `--net-role=`; the host orchestrates and SPAWNS the guest process
## itself (pids tracked, OS.kill on every failure path); every wait is a
## WALL-CLOCK bounded poll; localhost only. Run via net_test.bat (the
## compile gate runs first — a parse error would hang headless forever).
##
## GATE TRAP (MP-05): reference the autoload via get_node — the bare
## `NetworkManager` identifier does not compile under check_compile.

# Off the dev default (9999) AND net_test.gd's 48211.
const PORT := 48213
const PORT_STAGE3 := 48215   # stage 3 binds its own port (no TIME_WAIT races)
const PORT_STAGE4 := 48217   # stage 4 likewise (it runs right after stage 3)
const PORT_STAGE5 := 48219   # stage 5 likewise (it runs right after stage 4)
const STEP_TIMEOUT := 30.0   # s per observable step (boots include a world build)
const EXIT_TIMEOUT := 15.0   # s for the guest process to exit after its work
const MOVE_THRESHOLD := 120.0  # px the host must see the guest player travel

var game: Game = null
var _net: Node = null
var _stage := 2
var _pids: Array[int] = []
var _left: Array[int] = []          # peer_left ids (host side)
var _report := {}                   # the guest's cross-process report (host side)
var _drive := false                 # guest: host said GO (movement step)
var _seen_move := 0.0               # host: farthest displacement observed
var _watch_replies := {}            # host: probe name -> the guest's result
var _finish := false                # guest: the host says we're done
var _saw_visual_proj := false       # host4: a guest knife flew here as a copy
var _xp_before := 0                 # guest4: level*1e6+xp before the snipe
var _gold_before := 0               # guest5: wallet baseline for collect probes
var _bp_before := 0                 # guest5: backpack baseline (chest contents)
var _award_before := {}             # guest5: gem/consumable/capacity baselines


func _ready() -> void:
	_net = get_node("/root/NetworkManager")
	var role := "host"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--net-role="):
			role = str(arg).get_slice("=", 1)
		elif str(arg).begins_with("--net-stage="):
			_stage = int(str(arg).get_slice("=", 1))
	_net.peer_left.connect(func(id: int) -> void: _left.append(id))
	match role:
		"host":
			if _stage == 5:
				_run_host5()
			elif _stage == 4:
				_run_host4()
			elif _stage == 3:
				_run_host3()
			else:
				_run_host()
		"guest":
			if _stage == 5:
				_run_guest5()
			elif _stage == 4:
				_run_guest4()
			elif _stage == 3:
				_run_guest3()
			else:
				_run_guest()
		_:
			_fail("unknown --net-role=%s" % role)


func _port() -> int:
	if _stage == 5:
		return PORT_STAGE5
	if _stage == 4:
		return PORT_STAGE4
	return PORT_STAGE3 if _stage == 3 else PORT


# ------------------------------------------------------------- the host ---

## Boot a REAL hosting game through the roster flow (stages 2 and 3
## share it): chapter -> class -> opening beats -> play_started, with
## the session listening from boot (--mp-host seam, set directly the
## way the CLI parse would). Returns false after _fail on any miss.
func _host_boot() -> bool:
	game = load("res://scenes/main.tscn").instantiate()
	game.no_saves = true
	game.mp_host = true
	game.mp_host_code = "127.0.0.1:%d" % _port()
	add_child(game)
	await _frames(10)

	# The roster path the suites use: chapter -> class -> opening beats.
	if not (game.menus.is_open() and game.menus.current == "chapter_select"):
		_fail("chapter select did not open")
		return false
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_story()
	if not await _wait_for(func() -> bool: return game.play_started, STEP_TIMEOUT, "host play_started"):
		return false
	if not await _wait_for(func() -> bool: return _net.is_online() and _net.is_host(), STEP_TIMEOUT, "host session listening"):
		return false
	print("[net_session] host: playing (seed %d) and listening on %s" % [game.wander_seed, _net.session_code])
	return true


func _run_host() -> void:
	if not await _host_boot():
		return

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

## Boot a REAL joining game (the --mp-join seam) and assert the shared
## entry criteria: snapshot applied, own player local, host's player
## fanned out. Stages 2-4 share it (stage 4 joins as an assassin — a
## melee arc AND real projectiles in one kit). False after _fail.
func _guest_boot(cls := "archer") -> bool:
	game = load("res://scenes/main.tscn").instantiate()
	game.no_saves = true
	game.mp_join_code = "127.0.0.1:%d" % _port()
	game.mp_cls = cls  # a non-warrior class proves the char block travels
	add_child(game)

	var sess: Node = get_node("/root/NetworkManager/Session")
	if not await _wait_for(func() -> bool: return bool(sess.world_ready), STEP_TIMEOUT, "world snapshot + rebuild"):
		return false
	var snap: Dictionary = sess.last_snapshot
	if game.wander_seed != int(snap.get("wander_seed", -1)):
		_fail("applied seed %d != snapshot seed %s" % [game.wander_seed, str(snap.get("wander_seed"))])
		return false
	if not game.play_started or game.player.cls != cls:
		_fail("guest entry incomplete (play_started %s, cls %s)" % [str(game.play_started), game.player.cls])
		return false
	if not game.player.is_locally_controlled():
		_fail("the guest's own player must stay locally controlled")
		return false

	# The host's player must appear HERE too (spawn fan-out).
	if not await _wait_for(func() -> bool: return game.players.size() == 2, STEP_TIMEOUT, "guest roster of 2"):
		return false
	var host_copy := _player_of(1)
	if host_copy == null or host_copy.is_locally_controlled():
		_fail("the host's player must exist here and NOT be locally controlled")
		return false
	print("[net_session] guest: world rebuilt (seed %d), roster %s" % [game.wander_seed, str(_peer_ids())])
	return true


func _run_guest() -> void:
	if not await _guest_boot():
		return

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


# --------------------------------------------------- stage 3 (MP-09) ---
# Combat over the wire: the host runs the sim, the guest must SEE it.
# The host directs; the guest serves WATCH probes (each polls a local
# condition, bounded, and reports back) so every assert reads the
# guest's real scene state, not an echo of the host's.

func _run_host3() -> void:
	if not await _host_boot():
		return
	if _spawn_peer("guest") < 0:
		return _fail("could not spawn the guest process")
	if not await _wait_for(func() -> bool: return not _net.peers.is_empty(), STEP_TIMEOUT, "guest admission"):
		return
	var gid: int = _net.peers[0]
	if not await _wait_for(func() -> bool: return bool(_report.get("ready", false)), STEP_TIMEOUT, "guest ready report"):
		return
	print("[net_session] host3: guest %d standing in the world" % gid)

	# The cast: three calm wolves out of aggro range + one boss with its
	# fangs pulled (dmg 0 — the fight is a sync probe; the unattended
	# host hero must survive it). Everything spawns through the REAL
	# paths (add_enemy / the dev-panel boss idiom), so announcement rides
	# Enemy._ready exactly like production spawns.
	var sess: Node = get_node("/root/NetworkManager/Session")
	var base: int = sess.net_enemies.size()
	var origin: Vector2 = game.local_player.global_position
	var wolves: Array = []
	for k in 3:
		var e := Enemy.make(game, "wolf", origin + Vector2(520.0 + 40.0 * k, 90.0 * k - 60.0), 3)
		game.add_enemy(e)
		wolves.append(e)
	var boss: Boss = Boss.make_boss(game, "vargoth", origin + Vector2(640.0, -140.0))
	boss.dmg = 0.0
	game.bosses.append(boss)
	game.add_child(boss)
	if not await _wait_for(func() -> bool: return sess.net_enemies.size() == base + 4, 5.0, "host registry of %d" % (base + 4)):
		return
	for w in wolves:
		if int(w.net_id) <= 0:
			return _fail("a wolf entered the tree unannounced (net_id 0)")
	if int(boss.net_id) <= 0:
		return _fail("the boss entered the tree unannounced (net_id 0)")
	var want: int = sess.net_enemies.size()
	print("[net_session] host3: %d enemies live + announced (3 wolves, 1 boss)" % want)

	# (a) mirror census: count matches the registry, every mirror is
	# sim-gated (net_mirror) and collisionless, the boss came through.
	var r: Dictionary = await _watch(gid, "mirrors", {"count": want})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)) or int(r.get("bosses", 0)) != 1:
		return _fail("mirror census failed: %s" % str(r))
	print("[net_session] host3: guest mirrors %d/%d — all sim-gated, boss present" % [int(r.get("count", 0)), want])

	# (b) a host-side position change is tracked. Teleport a calm wolf
	# (home rides along so it doesn't walk back) — the 20 Hz stream +
	# mirror smoothing must carry the hop to the guest.
	var w0: Enemy = wolves[0]
	w0.global_position += Vector2(260.0, 40.0)
	w0.home = w0.global_position
	r = await _watch(gid, "track", {"id": w0.net_id,
		"x": w0.global_position.x, "y": w0.global_position.y, "tol": 64.0})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest mirror never tracked the moved wolf: %s" % str(r))
	print("[net_session] host3: mirror tracked a 263 px hop to within %.1f px" % float(r.get("dist", -1.0)))

	# (c) hp sync: halve the second wolf — the mirror's overhead bar
	# must appear and its fraction must follow the stream.
	var w1: Enemy = wolves[1]
	w1.take_damage(w1.max_hp * 0.5, Vector2.ZERO, false, true)
	r = await _watch(gid, "hp", {"id": w1.net_id, "max_frac": 0.8})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest mirror hp never followed the hit: %s" % str(r))
	print("[net_session] host3: mirror hp tracked the wound (%.2f of max)" % float(r.get("frac", -1.0)))

	# (d) play_action event: the guest starts watching, THEN the host
	# fires the strip (the _watch helper sequences that), so the one-shot
	# can't slip between polls. vargoth ships _anim + _slam strips.
	r = await _watch(gid, "action", {"id": boss.net_id},
		func() -> void: boss.play_action("slam"))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the play_action broadcast never lit the mirror's strip: %s" % str(r))
	print("[net_session] host3: play_action(slam) reached the boss mirror's strip")

	# (e) boss bar: the guest's HUD shows the mirror's bar, right name.
	r = await _watch(gid, "bossbar", {"name": "King Vargoth the Hollow"})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest boss bar wrong/hidden: %s" % str(r))
	print("[net_session] host3: guest boss bar up — %s" % str(r.get("name", "")))

	# (f) telegraph event: watch first, then paint a tell host-side. The
	# 2.5 s fuse holds the zone alive across the probe window.
	r = await _watch(gid, "telegraph", {},
		func() -> void: game.telegraph(origin + Vector2(300.0, 0.0), 90.0, 2.5, 0.0))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the telegraph event never rendered guest-side: %s" % str(r))
	print("[net_session] host3: telegraph rendered on the guest")

	# (g) kill: a real host-side death must free the guest mirror and
	# shrink the host registry.
	var w2: Enemy = wolves[2]
	var dead_id: int = w2.net_id
	w2.take_damage(9.9e9)
	r = await _watch(gid, "gone", {"id": dead_id})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest mirror outlived the kill: %s" % str(r))
	if sess.net_enemies.has(dead_id):
		return _fail("host registry kept the dead wolf")
	print("[net_session] host3: kill fanned out — mirror freed, registry %d" % sess.net_enemies.size())

	# Quit hygiene: silence the fight and let every telegraph fuse/tween
	# drain on BOTH sides before anyone exits — a timer mid-air at quit
	# reads as a leaked instance in the teardown report.
	boss.untargetable = false  # dev-kill pierces any phase
	boss.take_damage(9.9e9)
	for w in wolves:
		if is_instance_valid(w) and not w.dying:
			w.take_damage(9.9e9)
	await get_tree().create_timer(2.5).timeout

	# Done: release the guest, confirm the clean leave.
	_rpc_finish.rpc_id(gid)
	if not await _wait_for(func() -> bool: return _left.has(gid), STEP_TIMEOUT, "guest peer_left"):
		return
	if not await _wait_exit("guest"):
		return
	print("NET TEST PASS")
	get_tree().quit(0)


func _run_guest3() -> void:
	if not await _guest_boot():
		return
	# Announce readiness, then serve the host's watch probes (RPC-driven)
	# until the finish flag; leave cleanly so the host sees peer_left.
	_rpc_report.rpc_id(1, {"ready": true})
	if not await _wait_for(func() -> bool: return _finish, 120.0, "host finish signal"):
		return
	_net.leave()
	await get_tree().create_timer(0.5).timeout
	print("[net_session] guest3: served all probes, left cleanly")
	get_tree().quit(0)


# --------------------------------------------------- stage 4 (MP-10) ---
# The guest FIGHTS: its abilities hurt the host's real enemies, enemies
# hurt it back, and every screen agrees. Same director/probe shape as
# stage 3; the guest-side probes now ACT (teleport + real key intents)
# before they poll.

func _run_host4() -> void:
	if not await _host_boot():
		return
	if _spawn_peer("guest") < 0:
		return _fail("could not spawn the guest process")
	if not await _wait_for(func() -> bool: return not _net.peers.is_empty(), STEP_TIMEOUT, "guest admission"):
		return
	var gid: int = _net.peers[0]
	if not await _wait_for(func() -> bool: return bool(_report.get("ready", false)), STEP_TIMEOUT, "guest ready report"):
		return
	var shell := _player_of(gid)
	if shell == null:
		return _fail("no host-side shell for the guest")
	print("[net_session] host4: guest %d (assassin) standing in the world" % gid)

	# The cast: three wolves with their fangs pulled (dmg 0 — the guest
	# stands in bite range during probes) + a zero-fang boss for the
	# phase-flag check. Real spawn paths, so announcement rides _ready.
	var sess: Node = get_node("/root/NetworkManager/Session")
	var base: int = sess.net_enemies.size()
	var origin: Vector2 = game.local_player.global_position
	var wolves: Array = []
	for k in 3:
		var e := Enemy.make(game, "wolf", origin + Vector2(520.0 + 230.0 * k, -60.0), 3)
		e.dmg = 0.0
		game.add_enemy(e)
		wolves.append(e)
	var boss: Boss = Boss.make_boss(game, "vargoth", origin + Vector2(760.0, -380.0))
	boss.dmg = 0.0
	boss.stun_time = 9.9e9  # planted (dev idiom): it must not wander onto the
	                        # guest and steal the soft-target aim mid-probe
	game.bosses.append(boss)
	game.add_child(boss)
	if not await _wait_for(func() -> bool: return sess.net_enemies.size() == base + 4, 5.0, "host registry of %d" % (base + 4)):
		return
	var r: Dictionary = await _watch(gid, "mirrors", {"count": sess.net_enemies.size()})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)) or int(r.get("bosses", 0)) != 1:
		return _fail("mirror census failed: %s" % str(r))
	print("[net_session] host4: cast up — %d mirrors, boss present" % int(r.get("count", 0)))

	# (a) guest ability via REAL intents: one landed stab on wolf 0. The
	# host's hp must drop by exactly the RPC'd amount (the guest rolls
	# crit/miss ONCE, locally — the wire carries the result).
	var w0: Enemy = wolves[0]
	var hp0: float = w0.hp
	sess.last_hit = {}
	r = await _watch(gid, "strike", {"id": w0.net_id,
		"x": w0.global_position.x - 70.0, "y": w0.global_position.y})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest never saw its own strike land on the mirror: %s" % str(r))
	if not await _wait_for(func() -> bool: return w0.hp < hp0 - 0.01, 8.0, "host wolf hp drop"):
		return
	var drop: float = hp0 - w0.hp
	var rpcd: float = float(sess.last_hit.get("amount", -1.0))
	if int(sess.last_hit.get("id", -1)) != w0.net_id or int(sess.last_hit.get("peer", -1)) != gid:
		return _fail("last_hit attribution wrong: %s" % str(sess.last_hit))
	if absf(drop - rpcd) > 0.5:
		return _fail("hp drop %.2f != RPC'd amount %.2f" % [drop, rpcd])
	print("[net_session] host4: guest stab landed — hp -%.1f == RPC'd %.1f (crit %s)"
		% [drop, rpcd, str(sess.last_hit.get("crit"))])
	# ...and the mirror re-converges on the authoritative fraction.
	r = await _watch(gid, "converge", {"id": w0.net_id,
		"frac": w0.hp / w0.max_hp, "tol": 0.03})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("mirror hp never converged after the strike: %s" % str(r))
	print("[net_session] host4: mirror converged to %.3f of max" % float(r.get("frac", -1.0)))

	# (b) rider: a guest-applied burn must burn the HOST's wolf, sourced
	# to the guest's shell, and tick its hp down host-side.
	var w1: Enemy = wolves[1]
	r = await _watch(gid, "burnit", {"id": w1.net_id})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest burn probe failed: %s" % str(r))
	if not await _wait_for(func() -> bool: return w1.burn_time > 0.0, 5.0, "host wolf burning"):
		return
	if w1.burn_src == null or not is_instance_valid(w1.burn_src) or w1.burn_src.peer_id != gid:
		return _fail("burn src is not the guest's shell")
	var burn_hp: float = w1.hp
	if not await _wait_for(func() -> bool: return w1.hp < burn_hp - 0.01, 5.0, "burn dps ticking host-side"):
		return
	print("[net_session] host4: guest burn ticks host-side (src peer %d)" % w1.burn_src.peer_id)

	# (c) enemy -> guest: host-side hits on the shell forward to the
	# owner. Heavy pierces chip-armed gates; a rare dodge just retries.
	var shell_hp0: float = shell.max_hp
	r = await _watch(gid, "hurt", {}, _pummel_shell.bind(shell, wolves[0]))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest's REAL hp never dropped: %s" % str(r))
	if not await _wait_for(func() -> bool:
			return is_instance_valid(shell) and shell.hp < shell_hp0 - 0.5,
			8.0, "shell hp following via vitals"):
		return
	print("[net_session] host4: shell hp followed the owner down (%.1f/%.1f)"
		% [shell.hp, shell.max_hp])

	# Clear the field for the snipe: the stabbed wolf has hunted the guest
	# since (a) — the aggro-turn working as designed — and standing on the
	# shell it would photobomb the soft-target aim. Kill both spent wolves
	# XP-FREE (the cleanup must not pollute (d)'s kill-XP assert); their
	# death events also free the guest's mirrors.
	for i in 2:
		var wl: Enemy = wolves[i]
		if is_instance_valid(wl) and not wl.dying:
			wl.xp_value = 0
			wl.take_damage(9.9e9)
	await get_tree().create_timer(0.6).timeout

	# (d) guest projectiles kill: sliver wolf 2, the guest fans knives at
	# it — physics-layer mirror hits, death event, kill XP to the guest.
	# The host must also have seen the knives' visual copies fly here.
	var w2: Enemy = wolves[2]
	w2.take_damage(w2.hp - 1.0, Vector2.ZERO, false, true)
	var dead_id: int = w2.net_id
	_saw_visual_proj = false
	_proj_monitor(10.0)
	r = await _watch(gid, "snipe", {"id": dead_id,
		"x": w2.global_position.x - 90.0, "y": w2.global_position.y})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("guest snipe failed (kill or XP missing): %s" % str(r))
	if sess.net_enemies.has(dead_id):
		return _fail("host registry kept the sniped wolf")
	if not _saw_visual_proj:
		return _fail("the guest's knives never flew here as visual copies")
	print("[net_session] host4: guest projectile kill — mirror freed, +%d XP guest-side, copies seen"
		% int(r.get("xp", -1)))

	# (e) a hostile projectile spawn event renders guest-side.
	r = await _watch(gid, "hostileproj", {}, func() -> void:
		var hb := Projectile.spawn(game, boss.global_position, Vector2(0.0, 140.0), 5.0, false, "bolt")
		hb.source_enemy = boss)
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("hostile projectile event never rendered guest-side: %s" % str(r))
	print("[net_session] host4: hostile bolt spawn event rendered on the guest")

	# (f) untargetable phase flag rides state bit 2 to the mirror.
	boss.untargetable = true
	r = await _watch(gid, "phase", {"id": boss.net_id, "want": true})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("mirror never read untargetable=true: %s" % str(r))
	boss.untargetable = false
	r = await _watch(gid, "phase", {"id": boss.net_id, "want": false})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("mirror never read untargetable=false: %s" % str(r))
	print("[net_session] host4: boss phase flag round-tripped (bit 2)")

	# Quit hygiene (stage-3 pattern): silence the fight, drain tweens.
	boss.take_damage(9.9e9)
	for w in wolves:
		if is_instance_valid(w) and not w.dying:
			w.take_damage(9.9e9)
	await get_tree().create_timer(2.5).timeout
	_rpc_finish.rpc_id(gid)
	if not await _wait_for(func() -> bool: return _left.has(gid), STEP_TIMEOUT, "guest peer_left"):
		return
	if not await _wait_exit("guest"):
		return
	print("NET TEST PASS")
	get_tree().quit(0)


func _run_guest4() -> void:
	if not await _guest_boot("assassin"):
		return
	_rpc_report.rpc_id(1, {"ready": true})
	if not await _wait_for(func() -> bool: return _finish, 180.0, "host finish signal"):
		return
	_net.leave()
	await get_tree().create_timer(0.5).timeout
	print("[net_session] guest4: served all probes, left cleanly")
	get_tree().quit(0)


# --------------------------------------------------- stage 5 (MP-11) ---
# Loot instancing: the host's kills pay EVERY head its own personal
# stream. Director/probe shape as stages 3-4; wallet/bag deltas are
# asserted on the machine that OWNS them.

func _run_host5() -> void:
	if not await _host_boot():
		return

	# (s) SOLO regression FIRST — no session traffic yet. A paying kill
	# in magnet range must pay exactly the drop_gold coin math, once: a
	# doubled seam would pay 2x, a leak would pay less.
	var origin: Vector2 = game.local_player.global_position
	var g0: int = game.player.gold
	var sw := Enemy.make(game, "wolf", origin + Vector2(60.0, 0.0), 3)
	sw.dmg = 0.0
	game.add_enemy(sw)
	await _frames(2)
	var pay: int = sw.gold_value
	if pay <= 0:
		return _fail("test wolf pays no gold (gold_value %d)" % pay)
	sw.take_damage(9.9e9)
	var want: int = _pile_total(pay)
	if not await _wait_for(func() -> bool: return game.player.gold >= g0 + want, STEP_TIMEOUT, "solo pile collected"):
		return
	await get_tree().create_timer(1.0).timeout  # any straggler coin lands
	var got: int = game.player.gold - g0
	if got != want:
		return _fail("solo kill paid %d, expected exactly %d (double-apply through the party seam?)" % [got, want])
	print("[net_session] host5: solo kill paid exactly once (+%d gold, wolf base %d)" % [got, pay])

	# Bring in the guest.
	if _spawn_peer("guest") < 0:
		return _fail("could not spawn the guest process")
	if not await _wait_for(func() -> bool: return not _net.peers.is_empty(), STEP_TIMEOUT, "guest admission"):
		return
	var gid: int = _net.peers[0]
	if not await _wait_for(func() -> bool: return bool(_report.get("ready", false)), STEP_TIMEOUT, "guest ready report"):
		return
	var sess: Node = get_node("/root/NetworkManager/Session")
	print("[net_session] host5: guest %d standing in the world" % gid)

	# (a) party kill, far from both players (nobody magnets it away).
	var kp: Vector2 = game.clamp_to_zone(origin + Vector2(520.0, -40.0), origin)
	if kp.distance_to(origin) < 200.0:
		return _fail("kill spot clamped too close to the host (%.0f px)" % kp.distance_to(origin))
	var pw := Enemy.make(game, "wolf", kp, 3)
	pw.dmg = 0.0
	game.add_enemy(pw)
	await _frames(2)
	var pay2: int = pw.gold_value
	var host_g1: int = game.player.gold
	var r: Dictionary = await _watch(gid, "coins", {"x": kp.x, "y": kp.y},
		func() -> void: pw.take_damage(9.9e9))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)) or int(r.get("sum", 0)) <= 0:
		return _fail("the guest never saw its own pile: %s" % str(r))
	var guest_sum: int = int(r.get("sum", 0))
	# The host holds exactly ITS OWN pile — one pile per head, never one
	# per player on one screen.
	if not await _wait_for(func() -> bool: return not _coins_near(kp).is_empty(), 8.0, "host pile spawn"):
		return
	var host_coins: Array = _coins_near(kp)
	var host_sum := 0
	for c in host_coins:
		host_sum += int(c.value)
	if host_coins.size() != clampi(int(float(pay2) / 3.0), 1, 5) or host_sum != _pile_total(pay2):
		return _fail("host-side pile wrong (%d coins, %d gold — expected %d gold): guests' piles must not spawn here"
			% [host_coins.size(), host_sum, _pile_total(pay2)])
	# The guest collects ITS pile into ITS wallet...
	r = await _watch(gid, "collect", {"x": kp.x, "y": kp.y, "min": guest_sum})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest's wallet never grew from its own pile: %s" % str(r))
	# ...and while its shell stood on OUR coins, the ownership gate held.
	if _coins_near(kp).size() != host_coins.size():
		return _fail("the guest's shell ate host-side coins (ownership gate)")
	game.player.global_position = kp
	if not await _wait_for(func() -> bool: return game.player.gold >= host_g1 + host_sum, 8.0, "host pile collected"):
		return
	print("[net_session] host5: same kill, two wallets — host +%d, guest +%d (independent piles)"
		% [game.player.gold - host_g1, int(r.get("delta", -1))])

	# (b) boss kill: both sides get their OWN golden chest + pile.
	var bpos: Vector2 = game.clamp_to_zone(origin + Vector2(560.0, -280.0), origin)
	var chest_at: Vector2 = game.clamp_to_zone(bpos + Vector2(0, 60), bpos)
	var boss: Boss = Boss.make_boss(game, "vargoth", bpos)
	boss.dmg = 0.0
	game.bosses.append(boss)
	game.add_child(boss)
	await _frames(2)
	var host_bp0: int = game.player.backpack.size()
	boss.take_damage(9.9e9)
	if not await _wait_for(func() -> bool: return _chest_near(chest_at) != null, 8.0, "host boss chest"):
		return
	var hchest: Chest = _chest_near(chest_at)
	r = await _watch(gid, "chest", {"x": chest_at.x, "y": chest_at.y})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest never got its own boss chest: %s" % str(r))
	# The guest opens ITS copy — ours must not so much as creak while the
	# shell stands on it (the trigger gate, applied without chest.gd).
	r = await _watch(gid, "openchest", {"x": chest_at.x, "y": chest_at.y})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest's own chest never paid it: %s" % str(r))
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(hchest) or hchest.opened:
		return _fail("the guest's shell opened the HOST's chest (trigger gate)")
	game.player.global_position = hchest.global_position
	if not await _wait_for(func() -> bool: return (not is_instance_valid(hchest)) or hchest.opened, 8.0, "host chest open"):
		return
	await get_tree().create_timer(0.5).timeout
	if game.player.backpack.size() <= host_bp0:
		return _fail("the host's own chest paid no gear")
	print("[net_session] host5: two chests, two rolls — host got %s, guest got %s"
		% [Items.title(game.player.backpack[-1]), str(r.get("item", "?"))])

	# (c) a crafted award package lands in the guest's OWN bags through
	# the personal-event machinery (the boss/elite payload kinds, made
	# deterministic).
	var pack: Array = [
		{"k": "gem", "gem": game.drop_gem(1), "at": kp},
		{"k": "stone", "stone": Items.make_reset_stone(), "at": kp},
		{"k": "bag", "grade": "C"},
		{"k": "toast", "text": "MP-11 award pack", "color": Color(1, 1, 1), "dur": 1.0},
	]
	r = await _watch(gid, "award", {}, func() -> void: sess.host_award_all(pack))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the award package never landed in the guest's bags: %s" % str(r))
	print("[net_session] host5: award pack applied guest-side (gems %d, consumables %d, capacity %d)"
		% [int(r.get("gems", -1)), int(r.get("cons", -1)), int(r.get("cap", -1))])

	# (d) a guest-side ground drop flushes into the GUEST's mailbox — and
	# never ours.
	var host_mail0: int = game.mailbox.size()
	r = await _watch(gid, "seed_drop", {})
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest never seeded a ground drop: %s" % str(r))
	r = await _watch(gid, "flushed", {}, func() -> void: sess.host_chapter_end(false, 1))
	if r.is_empty():
		return
	if not bool(r.get("ok", false)):
		return _fail("the guest's stray never reached the guest's mailbox: %s" % str(r))
	if game.mailbox.size() != host_mail0:
		return _fail("the flush event touched the HOST's mailbox")
	print("[net_session] host5: guest stray flushed to the GUEST's mailbox (%d letters guest-side, host untouched)"
		% int(r.get("mail", -1)))

	# Quit hygiene (stage-3 pattern): drain tweens/timers on both sides.
	await get_tree().create_timer(2.0).timeout
	_rpc_finish.rpc_id(gid)
	if not await _wait_for(func() -> bool: return _left.has(gid), STEP_TIMEOUT, "guest peer_left"):
		return
	if not await _wait_exit("guest"):
		return
	print("NET TEST PASS")
	get_tree().quit(0)


func _run_guest5() -> void:
	if not await _guest_boot():
		return
	_rpc_report.rpc_id(1, {"ready": true})
	if not await _wait_for(func() -> bool: return _finish, 240.0, "host finish signal"):
		return
	_net.leave()
	await get_tree().create_timer(0.5).timeout
	print("[net_session] guest5: served all probes, left cleanly")
	get_tree().quit(0)


## HOST: batter the guest's shell through the REAL seam — repeated
## take_damage calls on the shell (spaced past the owner's hurt_cd; a
## rare owner-side dodge just makes the next swing count). Runs as a
## fire-and-forget coroutine from _watch's act slot.
func _pummel_shell(shell: Player, wolf: Enemy) -> void:
	for i in 6:
		if not is_instance_valid(shell):
			return
		var attacker: Enemy = wolf if is_instance_valid(wolf) and not wolf.dying else null
		shell.take_damage(12.0, "phys", attacker, true)
		await get_tree().create_timer(0.8).timeout


## HOST: watch (bounded) for any of the guest's projectiles arriving here
## as friendly visual copies. Fire-and-forget beside the snipe probe.
func _proj_monitor(timeout: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline and not _saw_visual_proj:
		for node in get_tree().get_nodes_in_group("projectiles"):
			var p := node as Projectile
			if p != null and p.net_visual and p.friendly:
				_saw_visual_proj = true
				break
		await get_tree().create_timer(0.05).timeout


## HOST: ask the guest to WATCH for a condition (it polls locally,
## bounded, and reports back). `act` runs a beat AFTER the watch starts
## — one-shot events (play_action, telegraph) must not fire before the
## guest is looking. Empty dict = _fail already ran.
func _watch(gid: int, what: String, args: Dictionary, act: Callable = Callable()) -> Dictionary:
	_watch_replies.erase(what)
	_rpc_watch.rpc_id(gid, what, args)
	if act.is_valid():
		await get_tree().create_timer(0.4).timeout
		act.call()
	if not await _wait_for(func() -> bool: return _watch_replies.has(what), STEP_TIMEOUT, "guest watch '%s' reply" % what):
		return {}
	return _watch_replies[what]


## GUEST: act if the probe calls for it (stage 4), then poll until it
## reads ok or ~8 s pass, and report.
func _serve_watch(what: String, args: Dictionary) -> void:
	var sess: Node = get_node("/root/NetworkManager/Session")
	await _watch_setup(sess, what, args)
	var out := {"ok": false}
	var deadline: int = Time.get_ticks_msec() + 8000
	while true:
		out = _probe(sess, what, args)
		if bool(out.get("ok", false)) or Time.get_ticks_msec() >= deadline:
			break
		await get_tree().create_timer(0.1).timeout
	_rpc_watch_reply.rpc_id(1, what, out)


## GUEST, stage 4: the ACT half of the acting probes — teleport beside
## the mirror (the sticky soft target then commits aim/orientation to it,
## proving mirrors are valid targets) and drive the REAL ability through
## key intents. "strike" re-taps on a miss so one landed hit is certain.
func _watch_setup(sess: Node, what: String, args: Dictionary) -> void:
	match what:
		"strike":
			game.player.global_position = Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
			await _frames(6)  # a beat: soft target acquires the mirror
			for i in 5:
				_press(KEY_J, true)   # a1 — the assassin stab (melee arc)
				await get_tree().create_timer(0.15).timeout
				_press(KEY_J, false)
				await get_tree().create_timer(0.45).timeout
				var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
				if e == null or not is_instance_valid(e) or e.hp < e.max_hp:
					break  # landed (or the mirror is gone) — stop tapping
		"snipe":
			_xp_before = game.player.level * 1000000 + game.player.xp
			game.player.global_position = Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
			await _frames(6)
			for i in 4:
				_press(KEY_L, true)   # a3 — fan of knives (real projectiles)
				await get_tree().create_timer(0.15).timeout
				_press(KEY_L, false)
				await get_tree().create_timer(0.6).timeout
				var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
				if e == null or not is_instance_valid(e) or e.dying:
					break  # the kill event landed — stop throwing
		"burnit":
			# The rider probe drives hit_enemy directly with an ability-
			# shaped payload — the funnel underneath is what's under test.
			# Three swings: a single one can MISS (real evasion roll) and
			# the rider only lands on a connecting hit.
			for i in 3:
				var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
				if e != null and is_instance_valid(e) and not e.dying:
					game.player.hit_enemy(e, 0.3, {"burn": 10.0})
				await get_tree().create_timer(0.1).timeout
		# ---- stage 5 (MP-11) ----
		"collect":
			# Stand on OUR OWN pile; the magnet does the rest.
			_gold_before = game.player.gold
			game.player.global_position = Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
		"openchest":
			# Stand on OUR OWN chest copy; its (gated) trigger opens it.
			_gold_before = game.player.gold
			_bp_before = game.player.backpack.size()
			var c: Chest = _chest_near(Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0))))
			if c != null:
				game.player.global_position = c.global_position
		"award":
			_award_before = {"gems": game.player.gem_bag.size(),
				"cons": game.player.consumables.size(), "cap": game.player.bag_capacity()}
		"seed_drop":
			# A registered ground drop through the real API (discard idiom);
			# deferred — Area2D spawns must not ride an RPC frame's flush.
			game.discard_to_ground.call_deferred(
				{"kind": "stone", "stone": Items.make_reset_stone()})
			await _frames(3)
		_:
			pass


## GUEST: one probe evaluation against the LOCAL scene state.
func _probe(sess: Node, what: String, args: Dictionary) -> Dictionary:
	match what:
		"mirrors":
			var count := 0
			var gated := true
			var boss_n := 0
			for id in sess.net_enemies:
				var e: Enemy = sess.net_enemies[id]
				if e == null or not is_instance_valid(e) or e.dying:
					continue
				count += 1
				# MP-10: mirrors keep the enemy LAYER (4) so guest shots and
				# body-blocking see them; the zero MASK keeps them inert.
				if not e.net_mirror or e.collision_layer != 4 or e.collision_mask != 0:
					gated = false
				if e is Boss:
					boss_n += 1
			return {"ok": gated and count == int(args.get("count", -1)),
				"count": count, "gated": gated, "bosses": boss_n}
		"track":
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			if e == null or not is_instance_valid(e):
				return {"ok": false, "why": "no mirror"}
			var d: float = e.global_position.distance_to(
				Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0))))
			return {"ok": d <= float(args.get("tol", 64.0)), "dist": d}
		"hp":
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			if e == null or not is_instance_valid(e) or e.max_hp <= 0.0:
				return {"ok": false, "why": "no mirror"}
			var frac: float = e.hp / e.max_hp
			return {"ok": frac <= float(args.get("max_frac", 0.8)) \
				and e.hp_bar_fg != null and e.hp_bar_fg.visible, "frac": frac}
		"action":
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			return {"ok": e != null and is_instance_valid(e) \
				and not e._strip_action.is_empty()}
		"bossbar":
			return {"ok": game.hud.boss_box.visible \
				and String(game.hud.boss_base_name) == String(args.get("name", "")),
				"name": String(game.hud.boss_base_name)}
		"telegraph":
			return {"ok": _telegraph_visible()}
		"gone":
			var id: int = int(args.get("id", 0))
			if not sess.net_enemies.has(id):
				return {"ok": true}
			var e: Enemy = sess.net_enemies.get(id)
			return {"ok": e == null or not is_instance_valid(e) or e.dying}
		# ---- stage 4 (MP-10) ----
		"strike":
			# The optimistic local hit landed on the mirror (juice + funnel).
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			if e == null or not is_instance_valid(e):
				return {"ok": false, "why": "no mirror"}
			return {"ok": e.hp < e.max_hp - 0.01, "frac": e.hp / maxf(e.max_hp, 0.001)}
		"converge":
			# The 20 Hz stream re-asserted the host's authoritative fraction.
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			if e == null or not is_instance_valid(e) or e.max_hp <= 0.0:
				return {"ok": false, "why": "no mirror"}
			var frac: float = e.hp / e.max_hp
			return {"ok": absf(frac - float(args.get("frac", -1.0))) <= float(args.get("tol", 0.03)),
				"frac": frac}
		"burnit":
			# The rider bookkeeping landed locally (the host asserts the real DoT).
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			return {"ok": e != null and is_instance_valid(e) and e.burn_time > 0.0}
		"hurt":
			# The forwarded hit ran our REAL take_damage.
			return {"ok": game.player.hp < game.player.max_hp - 0.5,
				"hp": game.player.hp, "max": game.player.max_hp}
		"snipe":
			# Kill confirmed (mirror freed by the death event) AND the kill
			# XP reached this guest's real progression (§5.5).
			var id: int = int(args.get("id", 0))
			var e: Enemy = sess.net_enemies.get(id)
			var gone: bool = (not sess.net_enemies.has(id)) or e == null \
				or not is_instance_valid(e) or e.dying
			var xp_now: int = game.player.level * 1000000 + game.player.xp
			return {"ok": gone and xp_now > _xp_before, "gone": gone,
				"xp": xp_now - _xp_before}
		"hostileproj":
			for node in get_tree().get_nodes_in_group("projectiles"):
				var p := node as Projectile
				if p != null and p.net_visual and not p.friendly:
					return {"ok": true}
			return {"ok": false}
		"phase":
			var e: Enemy = sess.net_enemies.get(int(args.get("id", 0)))
			if e == null or not is_instance_valid(e):
				return {"ok": false, "why": "no mirror"}
			return {"ok": e.untargetable == bool(args.get("want", true)),
				"untargetable": e.untargetable}
		# ---- stage 5 (MP-11) ----
		"coins":
			# Our OWN pile spawned locally from the personal kill event.
			var coins: Array = _coins_near(Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0))))
			var sum := 0
			for c in coins:
				sum += int(c.value)
			return {"ok": not coins.is_empty(), "count": coins.size(), "sum": sum}
		"collect":
			# Standing on the pile (setup) grew OUR wallet by at least it.
			var delta: int = game.player.gold - _gold_before
			return {"ok": delta >= int(args.get("min", 1)), "delta": delta}
		"chest":
			# Our OWN chest copy stands here, unopened.
			var c: Chest = _chest_near(Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0))))
			return {"ok": c != null and not c.opened,
				"tier": c.tier if c != null else ""}
		"openchest":
			# Standing on it (setup) paid OUR bag and OUR wallet.
			var got_item: bool = game.player.backpack.size() > _bp_before
			var got_gold: bool = game.player.gold > _gold_before
			var last := ""
			if got_item:
				last = Items.title(game.player.backpack[-1])
			return {"ok": got_item and got_gold, "item": last,
				"gold_delta": game.player.gold - _gold_before}
		"award":
			# The crafted package (gem + stone + bag) landed in OUR bags.
			var p: Player = game.player
			return {"ok": p.gem_bag.size() > int(_award_before.get("gems", 999999)) \
				and p.consumables.size() > int(_award_before.get("cons", 999999)) \
				and p.bag_capacity() > int(_award_before.get("cap", 999999)),
				"gems": p.gem_bag.size(), "cons": p.consumables.size(),
				"cap": p.bag_capacity()}
		"seed_drop":
			return {"ok": not game.dropped_loot.is_empty(),
				"drops": game.dropped_loot.size()}
		"flushed":
			# The flush event mailed OUR strays to OUR mailbox.
			var flushed_mail := false
			for m in game.mailbox:
				if String(m.get("subject", "")) == "Dropped Loot":
					flushed_mail = true
			return {"ok": flushed_mail and game.dropped_loot.is_empty(),
				"mail": game.mailbox.size(), "drops": game.dropped_loot.size()}
	return {"ok": false, "why": "unknown probe %s" % what}


## GUEST: a telegraph zone lives as a Sprite2D child of game with the
## cached "telegraph" texture (game_base.telegraph) — nothing local
## paints one on a guest, so any hit here arrived over the wire.
func _telegraph_visible() -> bool:
	var tex: Texture2D = Art.tex("telegraph")
	for node in game.get_children():
		var s := node as Sprite2D
		if s != null and s.texture == tex:
			return true
	return false


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


## Host -> guest: begin serving a watch probe (stage 3).
@rpc("authority", "call_remote", "reliable")
func _rpc_watch(what: String, args: Dictionary) -> void:
	_serve_watch(what, args)


## Guest -> host: a watch probe's verdict (stage 3).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_watch_reply(what: String, result: Dictionary) -> void:
	if multiplayer.is_server():
		_watch_replies[what] = result


## Host -> guest: every probe served — leave and exit 0 (stage 3).
@rpc("authority", "call_remote", "reliable")
func _rpc_finish() -> void:
	_finish = true


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


## pickup.gd's drop_gold coin math (all multipliers are 1.0 in this
## harness: fresh hero, resonance 0, no weekly): what one pile pays.
func _pile_total(amount: int) -> int:
	var coins: int = clampi(int(float(amount) / 3.0), 1, 5)
	return coins * maxi(1, int(float(amount) / float(coins)))


## Coin pickups (loot-empty, non-goldrush) within 140 px of `at`, on
## THIS machine (piles are personal — each side counts its own).
func _coins_near(at: Vector2) -> Array:
	var out: Array = []
	for node in game.get_children():
		var pk := node as Pickup
		if pk != null and pk.loot.is_empty() and not pk.goldrush \
				and pk.global_position.distance_to(at) < 140.0:
			out.append(pk)
	return out


## The nearest Chest within 90 px of `at` on THIS machine, or null.
func _chest_near(at: Vector2) -> Chest:
	var best: Chest = null
	var best_d := 90.0
	for node in game.get_children():
		var c := node as Chest
		if c != null and c.global_position.distance_to(at) < best_d:
			best_d = c.global_position.distance_to(at)
			best = c
	return best


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


## Spawn a sibling headless instance of THIS scene in the given role
## (the stage rides along so both processes run the same flow).
func _spawn_peer(role: String) -> int:
	var args := [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/net_test_session.tscn",
		"--", "--net-role=%s" % role, "--net-stage=%d" % _stage,
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
