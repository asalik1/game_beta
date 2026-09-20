extends RefCounted
## Corrected live co-op QA for earned shortcut gates inside shot_shortcuts's
## rig (`shot.bat shortcuts --party --timeout=360`, branch BEFORE the
## hunt setup): two complete games in ONE engine over a real ENet transport,
## using the rig's readers/apis/wires/roots/transports/screens, _shell/_until/
## _show/_capture and its SLOT-96 save snapshot+restore (both live in the
## rig's _ready; this helper only returns an error string).
##
## Supersedes qa-fable2-candidate's raw helper. Corrections implemented here:
##  - every request waits for the EXACT host-received wire record (the rig's
##    WireSession observation taps around super._rpc_shortcut_open /
##    super._rpc_flag_to_host), never a fixed frame count;
##  - no invalid case may be omitted: an unsatisfiable pose or a vitals/state
##    replication timeout is a FAILURE with its partial receipt retained;
##  - the positive open is NATIVE ONLY (a real remapped guest interact key
##    through Input.parse_input_event and the ordinary intent/interaction
##    poll); there is NO direct-RPC fallback and no cooldown zeroing;
##  - closed/open boundary movement uses the fixed WASD keys and ordinary
##    Player physics (briefly re-enabled, then restored);
##  - both endpoint build orders are DISTINCT world rebuilds witnessed by
##    world instance ids, not re-reads of already built nodes;
##  - the post-open snapshot is a RESNAPSHOT: the guest world instance id
##    must change before any graph/flag/latch assertion is read;
##  - a structured receipt is written on EVERY return path, and all injected
##    keys / bind / physics / hp / down-state loans are released even when a
##    step fails early. No automatic retry anywhere.
##
## POSED FIXTURE, DISCLOSED: the seed comes from scanning unattached graph
## fixtures (the domain helper's own _fixture, the actual generator — no
## frequency or ordinary-journey claim is made from a favorable posed seed);
## endpoint rooms are pacified by direct cleared/zone_alive writes; hero
## poses are teleports. The fixture Games are rig-local disposables, so pose
## and clearance loans are DISCLOSED in the receipt rather than restored;
## input/bind/physics/vitals loans ARE restored because they touch the
## shared Input singleton and the owner-state stream.
##
## Owner state drives every remote assertion: the GUEST'S OWN player is
## posed/hp-zeroed/downed/ghosted and the test WAITS for the host's shell
## (r._shell(0, pid)) to reflect it through the ordinary vitals /
## send_down_state wire. The remote shell is never written directly.

const DomainQA := preload("res://scripts/tests/shortcut_domain_live.gd")
const GATE_PATH := "res://scripts/shortcut_gate.gd"
const LATCH_PATH := "res://scripts/shortcut_latch.gd"
const CHAPTER := "ch1"
const SCAN_SEEDS := 80
## Remap candidates for the guest interact key: none is a default bind and
## none is an engine-fixed gameplay key; both live bind tables are checked
## again at runtime before the loan.
const KEY_POOL := [KEY_O, KEY_P, KEY_B, KEY_N, KEY_G]
## Fixed keys the poll reads outside `binds`: movement (player_core
## _poll_local_intents) and the dev/system keys game.gd touches.
const FIXED_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT,
	KEY_RIGHT, KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_TAB,
	KEY_BACKSLASH, KEY_EQUAL, KEY_MINUS]
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}
const MOVE_KEY := {"N": KEY_W, "S": KEY_S, "E": KEY_D, "W": KEY_A}
const DIRV := {"N": Vector2(0, -1), "S": Vector2(0, 1),
	"E": Vector2(1, 0), "W": Vector2(-1, 0)}
const APPROACH := 240.0          # clear approach inside the playable doorway
const MIN_PROGRESS := 60.0       # a closed approach must actually walk this far


static func run(r) -> String:
	var receipt: Dictionary = {
		"rig": "shortcuts --party", "chapter": CHAPTER,
		"posed_fixture": true,
		"policy": "no omitted case counts as a pass; setup/replication failure is a failure; no retry-until-pass; no direct-RPC fallback for the positive open",
		"checks": [], "loans": [], "originals": [], "error": "",
		"scope": "controlled keyboard/ENet fixture; not complete feature acceptance",
	}
	var state: Dictionary = {"keys": [], "bind": null, "hp": null, "down": false}
	var err: String = await _run(r, receipt, state)
	_release_loans(r, receipt, state)
	receipt["complete"] = err == ""
	receipt["error"] = err
	var werr: String = _write_receipt(r, receipt)
	if err == "" and werr != "":
		err = werr  # an unwritable receipt is itself a failure
	return err


# ------------------------------------------------------------------ main ----

static func _run(r, receipt: Dictionary, state: Dictionary) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	# --- production lane + observation taps: fail fast, never pretend -------
	if not ResourceLoader.exists(GATE_PATH) or not ResourceLoader.exists(LATCH_PATH):
		return "shortcut production lane absent (gate/latch scripts missing) — integrate reviewed-local-v4 first"
	if not ("shortcut_edge" in host) or not host.has_method("_install_shortcut"):
		return "shortcut production lane absent (Game.shortcut_edge/_install_shortcut missing)"
	for wire in [r.wires[0], r.wires[1]]:
		if not wire.has_method("request_shortcut_open") or not wire.has_method("_rpc_shortcut_open"):
			return "shortcut production lane absent (net_session request/_rpc_shortcut_open missing)"
		if not ("qa_shortcut_rx" in wire) or not ("qa_flag_rx" in wire):
			return "wire observation taps absent — apply this candidate's shot_shortcuts.gd WireSession patch"
	for reader in [host, guest]:
		var g: Game = reader
		if not g.play_started or g.state != g.ST_PLAYING or g.input_overlay_up():
			return "paired reader did not reach the ordinary playable state"
	var latch_script: GDScript = load(LATCH_PATH)
	var wire0: Node = r.wires[0]
	# --- seed: scan unattached fixtures through the domain helper's own -----
	# _fixture (the ACTUAL generator+installer), then hold the WHOLE edge so
	# the live rebuild can be checked against it, not merely against non-empty.
	r.step("shortcut seed scan")
	var seed_v: int = -1
	var probe_edge: Dictionary = {}
	var base_seed: int = DomainQA.SEED_BASE
	var requested_axis: String = r.arg("shortcut-axis", "")
	if requested_axis != "" and requested_axis != "horizontal":
		return "shortcut-axis must be horizontal or omitted"
	var selected_delta := Vector2i.ZERO
	var scanned: Array = []
	for k in SCAN_SEEDS:
		var probe: Game = DomainQA._fixture(base_seed + k, true)
		var found: Dictionary = (probe.shortcut_edge as Dictionary).duplicate(true)
		var delta := Vector2i.ZERO
		if not found.is_empty():
			delta = Vector2i(probe.rooms[int(found["b"])]["coord"]) - Vector2i(probe.rooms[int(found["a"])]["coord"])
		scanned.append({"seed": base_seed + k, "edge": found.duplicate(true),
			"delta_a_to_b": [delta.x, delta.y]})
		probe.free()
		# Exclude start-room endpoints only in this posed build-order fixture:
		# switch_chapter necessarily builds room 0 before our explicit order.
		if not found.is_empty() and int(found["a"]) != 0 and int(found["b"]) != 0:
			if requested_axis == "horizontal" and (abs(delta.x) != 1 or delta.y != 0):
				continue
			seed_v = base_seed + k
			probe_edge = found
			selected_delta = delta
			break
	receipt["orientation_selection"] = {"requested_axis": requested_axis,
		"selected_delta_a_to_b": [selected_delta.x, selected_delta.y], "scanned": scanned,
		"limit": "posed orientation filter over the existing80 fixture seeds; no graph edits or frequency inference"}
	if seed_v < 0:
		return "no scanned ch1 seed rolled a shortcut candidate (window %d..%d) — a posed-scan gap, not a frequency finding" % [base_seed, base_seed + SCAN_SEEDS - 1]
	receipt["seed"] = seed_v
	receipt["scan_window"] = [base_seed, base_seed + SCAN_SEEDS - 1]
	receipt["seed_selection_limit"] = "first candidate with neither endpoint 0, so both explicit build orders begin unbuilt; not a frequency sample"
	if requested_axis == "horizontal":
		receipt["seed_selection_limit"] = "first horizontal candidate with neither endpoint0 in existing80-seed window; posed fixture, not frequency evidence"
	receipt["fixture_edge"] = probe_edge.duplicate(true)
	var a := int(probe_edge["a"])
	var b := int(probe_edge["b"])
	var far := int(probe_edge["far"])
	var near: int = a if far == b else b
	var flag_name := String(probe_edge["flag"])
	var dir_far_to_near := ""
	# --- endpoint build orders: TWO distinct controlled world rebuilds ------
	# (a-first then b-first), each witnessed by a fresh world instance id.
	var world_ids: Array = []
	for build_case in [[a, b, "a_first"], [b, a, "b_first"]]:
		var order: Array = build_case
		r.step("shortcut world rebuild " + String(order[2]))
		var before_id: int = host.world.get_instance_id() if is_instance_valid(host.world) else 0
		host.wander_seed = seed_v
		host.switch_chapter(CHAPTER, true)  # frees the old world immediately
		r._show(0)
		await r.skip_dialogue()
		host.player.set_physics_process(false)
		host.terrain_event_t = 10000.0
		if not is_instance_valid(host.world) or host.world.get_instance_id() == before_id:
			return "%s: switch_chapter did not stand up a NEW world instance" % String(order[2])
		world_ids.append(host.world.get_instance_id())
		if host.wander_seed != seed_v:
			return "%s: live world lost the assigned seed (%d != %d)" % [String(order[2]), host.wander_seed, seed_v]
		var live_edge: Dictionary = (host.shortcut_edge as Dictionary).duplicate(true)
		if live_edge != probe_edge:
			return "%s: live rebuild of seed %d disagrees with the fixture scan (%s vs %s) — fixture/live zone-injection divergence" % [String(order[2]), seed_v, str(live_edge), str(probe_edge)]
		if host._edge_unlocked(a, b):
			return "%s: the shortcut edge starts unlocked" % String(order[2])
		if requested_axis == "horizontal":
			var live_delta: Vector2i = Vector2i(host.rooms[b]["coord"]) - Vector2i(host.rooms[a]["coord"])
			if live_delta != selected_delta or abs(live_delta.x) != 1 or live_delta.y != 0:
				return "live rebuild did not preserve the selected horizontal fixture orientation"
		if dir_far_to_near == "":
			for d in ["N", "E", "S", "W"]:
				if host.neighbor(far, String(d)) == near:
					dir_far_to_near = String(d)
					break
			if dir_far_to_near == "":
				return "endpoints are not grid neighbors on the live graph"
		# door_pos uses the FULL room_rect: the two endpoint door positions
		# must coincide at the shared cell boundary (the corrected fact).
		var bp_far: Vector2 = host.door_pos(far, dir_far_to_near)
		var bp_near: Vector2 = host.door_pos(near, OPP[dir_far_to_near])
		if bp_far.distance_to(bp_near) > 0.5:
			return "%s: opposite door positions do not coincide (%s vs %s)" % [String(order[2]), str(bp_far), str(bp_near)]
		var berr: String = _witness_build_order(host, latch_script, int(order[0]), int(order[1]),
			a, b, far, bp_far, String(order[2]), receipt)
		if berr != "":
			return berr
		# Both closed directions in each genuine endpoint build order.
		for crossing in [[far, dir_far_to_near], [near, String(OPP[dir_far_to_near])]]:
			var closed_error: String = await _closed_boundary_blocked(r, host, int(crossing[0]),
				String(crossing[1]), bp_far, state, receipt, String(order[2]))
			if closed_error != "":
				return closed_error
			var lateral_error: String = await _lateral_mouth_attempts(r, host, int(crossing[0]),
				String(crossing[1]), bp_far, state, receipt, String(order[2]))
			if lateral_error != "":
				return lateral_error
	_loan(receipt, "host rooms %d/%d pacified by direct cleared/zone_alive writes (both rebuilds); not restored — the fixture Game is rig-disposed" % [a, b])
	if world_ids.size() != 2 or int(world_ids[0]) == int(world_ids[1]):
		return "the two build-order cases did not run on distinct world instances"
	var bp: Vector2 = host.door_pos(far, dir_far_to_near)
	var host_latch: Node2D = latch_script.find(host)
	if host_latch == null:
		return "no latch stands in the host's built far room"
	# Keep the host away from the guest's doorway proof, through its own actor.
	host.player.global_position = host.room_center(far)
	host.player.velocity = Vector2.ZERO
	host._enter_room(far)
	_loan(receipt, "host actor parked at far-room center before guest doorway checks")
	# --- admit the guest over real ENet (the rig's own join pattern) --------
	r.step("shortcut guest join")
	SaveGame.write(guest, r.SLOT)
	if SaveGame.read(r.SLOT).is_empty():
		return "initial guest home write failed"
	r.wires[1].local_char["slot"] = r.SLOT
	guest.no_saves = false
	guest.save_slot = r.SLOT
	if r.transports[0].create_server(0, 2) != OK:
		return "shortcut ENet bind failed"
	r.apis[0].multiplayer_peer = r.transports[0]
	if r.transports[1].create_client("127.0.0.1", r.transports[0].host.get_local_port()) != OK:
		return "shortcut ENet guest connect failed"
	r.apis[1].multiplayer_peer = r.transports[1]
	if not await r._until(func() -> bool: return not r.apis[0].get_peers().is_empty()):
		return "shortcut ENet handshake timed out"
	var pid: int = r.apis[1].get_unique_id()
	r.roots[0].peers[pid] = {}
	r.roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = pid
	for i in 2:
		r.readers[i].qa_online = true
	r.wires[0].world_ready = true
	# Freeze the guest's home file at the ACTUAL admission boundary (after
	# transport admission, before the snapshot) — the hunt rig's own policy.
	var home: Dictionary = SaveGame.read(r.SLOT)
	if home.is_empty() or SaveGame.world_of(home).is_empty():
		return "guest admission home save is missing its world"
	receipt["home_frozen_at"] = "post-admission, pre-snapshot"
	r.wires[0]._send_snapshot(pid)
	if not await r._until(func() -> bool: return bool(r.wires[1].world_ready) \
			and guest.wander_seed == seed_v and r._shell(0, pid) != null, 15.0):
		return "guest never received the shortcut world snapshot"
	r._show(1)
	await r.skip_dialogue()
	guest.player.set_physics_process(false)
	guest.terrain_event_t = 10000.0
	if guest.shortcut_edge != host.shortcut_edge:
		return "guest snapshot rebuilt a different shortcut edge (%s vs %s)" % [str(guest.shortcut_edge), str(host.shortcut_edge)]
	# Guest-side endpoint fixture: pacify both endpoint rooms (disclosed),
	# stand in the far room HONESTLY via _enter_room, never cur_room writes.
	for zi in [a, b]:
		guest.cleared[zi] = true
		guest.zone_alive[zi] = 0
	_loan(receipt, "guest rooms %d/%d pacified by direct cleared/zone_alive writes; not restored — the fixture Game is rig-disposed" % [a, b])
	guest.player.global_position = guest_latch_anchor(bp, dir_far_to_near)
	guest._enter_room(far)
	var guest_latch: Node2D = latch_script.find(guest)
	if guest_latch == null:
		return "no latch stands in the guest's built far room"
	if not guest.play_rect(far).has_point(guest_latch.position):
		return "the guest latch stands outside the far room's play rect (%s)" % str(guest_latch.position)
	# --- CLOSED movement: ordinary physics walks into the gate and stops ----
	for crossing in [[far, dir_far_to_near], [near, String(OPP[dir_far_to_near])]]:
		var merr: String = await _closed_boundary_blocked(r, guest, int(crossing[0]),
			String(crossing[1]), bp, state, receipt, "guest")
		if merr != "":
			return merr
	# --- strict invalid-request battery --------------------------------------
	r.step("shortcut invalid battery")
	# Keep the supported prop visible and stand outside its stone footing.
	var inward: Vector2 = -(DIRV[dir_far_to_near] as Vector2)
	var beside_latch: Vector2 = inward * 40.0 - inward.orthogonal() * 48.0
	guest.player.global_position = guest_latch.global_position + beside_latch
	guest._enter_room(far)
	if not await r._until(func() -> bool: return r._shell(0, pid) != null \
			and host.room_at_pos(r._shell(0, pid).global_position) == far \
			and r._shell(0, pid).global_position.distance_to(host_latch.global_position) < Balance.INTERACT_RANGE, 8.0):
		return "guest latch-side pose never replicated to the host shell"
	# Wrong seed / wrong chapter / unknown flag: the pose is VALID, so the
	# tested identity field is the only invalid input in each request.
	var rec: Dictionary = await _direct_open(r, "ch2", seed_v, flag_name)
	var ierr: String = _expect_refusal(host, a, b, flag_name, rec, "wrong_chapter", receipt)
	if ierr != "":
		return ierr
	rec = await _direct_open(r, CHAPTER, seed_v + 1, flag_name)
	ierr = _expect_refusal(host, a, b, flag_name, rec, "wrong_seed", receipt)
	if ierr != "":
		return ierr
	var bogus_flag := "shortcut_%s_98_99" % CHAPTER
	rec = await _direct_open(r, CHAPTER, seed_v, bogus_flag)
	if rec.is_empty():
		return "unknown-flag request receipt never observed on the host"
	if not _standing_latch_actor(rec):
		return "unknown-flag case did not reach the host with an otherwise eligible actor"
	if bool(rec.get("genuine_before", true)) or bool(rec.get("genuine_after", true)):
		return "unknown-flag receipt changed the genuine shortcut flag"
	if bool(host.get_flag(bogus_flag, false)) or bool(rec.get("flag_after", true)):
		return "host honored a nonexistent shortcut flag"
	if bool(host.get_flag(flag_name, false)) or host._edge_unlocked(a, b):
		return "an unknown-flag request disturbed the GENUINE shortcut flag"
	_note(receipt, "unknown_flag", {"rx": rec, "genuine_flag_still_false": true})
	# Generic flag spoof: _rpc_flag_to_host must refuse the shortcut_ namespace.
	var f0: int = (wire0.qa_flag_rx as Array).size()
	r.wires[1]._rpc_flag_to_host.rpc_id(1, flag_name, true)
	var flag_args: Dictionary = {"flag": flag_name, "value": true}
	var flag_world: int = host.world.get_instance_id()
	if not await r._until(func() -> bool: return not _matching_rx(wire0.qa_flag_rx, f0, pid, flag_args, flag_world).is_empty(), 8.0):
		return "generic flag spoof exact sender/args/world receipt never observed on the host"
	var frec: Dictionary = _matching_rx(wire0.qa_flag_rx, f0, pid, flag_args, flag_world)
	if not _standing_latch_actor(frec):
		return "generic-spoof case did not reach the host with an otherwise eligible actor"
	if bool(host.get_flag(flag_name, false)) or bool(guest.get_flag(flag_name, false)) \
			or bool(frec.get("flag_after", true)):
		return "generic _rpc_flag_to_host accepted the shortcut_ namespace"
	_note(receipt, "generic_flag_spoof", {"rx": frec})
	# Near side: a live guest at the WRONG endpoint.
	guest.player.global_position = guest.room_center(near)
	guest._enter_room(near)
	if not await r._until(func() -> bool: return host.room_at_pos(r._shell(0, pid).global_position) == near, 8.0):
		return "near-side pose never replicated"
	rec = await _client_open(r, flag_name)
	ierr = _expect_refusal(host, a, b, flag_name, rec, "near_side", receipt)
	if ierr != "":
		return ierr
	# Far room but beyond interact range. REQUIRED: an unsatisfiable pose is
	# a failure, never a silent omission.
	var pr: Rect2 = guest.play_rect(far)
	var lp: Vector2 = guest_latch.global_position
	var far_pos: Vector2 = pr.position + Vector2(48, 48)
	for c in [Vector2(pr.end.x - 48, pr.position.y + 48),
			Vector2(pr.position.x + 48, pr.end.y - 48), pr.end - Vector2(48, 48)]:
		var cv: Vector2 = c
		if cv.distance_to(lp) > far_pos.distance_to(lp):
			far_pos = cv
	if far_pos.distance_to(lp) <= Balance.INTERACT_RANGE * 1.25:
		return "far room offers no stand beyond interact range — distance case unsatisfiable (FAILURE, not omission)"
	guest.player.global_position = far_pos
	guest._enter_room(far)
	if not await r._until(func() -> bool: return host.room_at_pos(r._shell(0, pid).global_position) == far \
			and r._shell(0, pid).global_position.distance_to(host_latch.global_position) > Balance.INTERACT_RANGE, 8.0):
		return "far-distance pose never replicated"
	rec = await _client_open(r, flag_name)
	ierr = _expect_refusal(host, a, b, flag_name, rec, "out_of_range", receipt)
	if ierr != "":
		return ierr
	# Back beside the latch for the vitals/state cases.
	guest.player.global_position = guest_latch.global_position + beside_latch
	guest._enter_room(far)
	if not await r._until(func() -> bool: return r._shell(0, pid).global_position.distance_to(host_latch.global_position) < Balance.INTERACT_RANGE, 8.0):
		return "latch-side pose never re-replicated"
	# Dead (hp 0): owner-local hp loan, wait for the ordinary vitals stream.
	state["hp"] = guest.player.hp
	guest.player.hp = 0.0
	_loan(receipt, "guest owner hp loaned to 0 for the dead case (restored + shell-confirmed)")
	if not await r._until(func() -> bool: return r._shell(0, pid).hp <= 0.0 and r._shell(0, pid).dead, 8.0):
		return "owner hp=0 never reached the host shell — the dead case is REQUIRED"
	rec = await _client_open(r, flag_name)
	ierr = _expect_refusal(host, a, b, flag_name, rec, "dead_hp0", receipt)
	if ierr != "":
		return ierr
	guest.player.hp = float(state["hp"])
	state["hp"] = null
	if not await r._until(func() -> bool: return r._shell(0, pid).hp > 0.0 and not r._shell(0, pid).dead, 8.0):
		return "restored hp never reached the host shell"
	# Downed, then ghost: owner-local state loan + the existing
	# send_down_state wire; the host player stays standing, so _check_wipe
	# has a live standing head and cannot wipe the party.
	for down_case in [[1, "downed"], [2, "ghost"]]:
		if host.player.dead or host.player.downed or host.player.ghost or host.player.hp <= 0.0:
			return "host must remain standing throughout the controlled down-state cases"
		var st := int(down_case[0])
		var label := String(down_case[1])
		guest.player.downed = st == 1
		guest.player.ghost = st == 2
		state["down"] = true
		_loan(receipt, "guest owner %s state loaned via send_down_state(%d) (restored + shell-confirmed)" % [label, st])
		r.wires[1].send_down_state(st)
		if not await r._until(func() -> bool: return (r._shell(0, pid).downed if st == 1 else r._shell(0, pid).ghost), 8.0):
			return "owner %s state never reached the host shell — the case is REQUIRED" % label
		rec = await _client_open(r, flag_name)
		ierr = _expect_refusal(host, a, b, flag_name, rec, label, receipt)
		if ierr != "":
			return ierr
		guest.player.downed = false
		guest.player.ghost = false
		r.wires[1].send_down_state(0)
		state["down"] = false
		if not await r._until(func() -> bool: return not r._shell(0, pid).downed and not r._shell(0, pid).ghost, 8.0):
			return "restored standing state never reached the host shell"
	# Uncleared far room: HOST authority state, loaned and restored exactly.
	var alive_keep := int(host.zone_alive.get(far, 0))
	host.cleared.erase(far)
	host.zone_alive[far] = 1
	rec = await _client_open(r, flag_name)
	host.cleared[far] = true
	host.zone_alive[far] = alive_keep
	ierr = _expect_refusal(host, a, b, flag_name, rec, "uncleared_far_room", receipt)
	if ierr != "":
		return ierr
	if rec.get("far", {}).get("pacified", true):
		return "uncleared-room witness disagrees: the host record saw a pacified far room"
	# --- the valid open: NATIVE guest input through a real remapped key -----
	r.step("shortcut native open")
	if not await r._until(func() -> bool: return r._shell(0, pid).global_position.distance_to(host_latch.global_position) < Balance.INTERACT_RANGE, 8.0):
		return "latch-side pose never replicated before the native press"
	var native_key: int = -1
	for cand in KEY_POOL:
		var kc := int(cand)
		if host.binds.values().has(kc) or guest.binds.values().has(kc) or FIXED_KEYS.has(kc):
			continue
		native_key = kc
		break
	if native_key < 0:
		return "no free keycode for the guest interact remap — the REQUIRED native path cannot run"
	if host.binds.values().has(native_key):
		return "chosen native key collides with a host binding"  # unreachable belt
	state["bind"] = int(guest.binds["interact"])
	guest.binds["interact"] = native_key
	_loan(receipt, "guest binds['interact'] remapped %s -> %s (temporary, restored)" % [
		OS.get_keycode_string(int(state["bind"])), OS.get_keycode_string(native_key)])
	guest.refresh_interaction_copy()
	if not guest.player.is_locally_controlled():
		return "guest player is not locally controlled"
	if guest.input_overlay_up():
		return "a guest overlay is up before the native press"
	if not await r._until(func() -> bool: return guest.interact_in_range \
			and guest.selected_landmark_prompt == guest_latch.prompt, 5.0):
		return "the ordinary interaction poll never selected the latch as nearest"
	if not guest_latch.prompt.visible:
		return "the latch prompt is not visible under the ordinary poll"
	var expected_copy: String = guest.interaction_copy("E — Open shortcut")
	if guest_latch.prompt.text != expected_copy:
		return "latch prompt copy '%s' != expected '%s' after the remap" % [guest_latch.prompt.text, expected_copy]
	if not await r._until(func() -> bool: return guest.talk_cd <= 0.0, 5.0):
		return "guest talk_cd never decayed ordinarily (no cooldown writes were made)"
	receipt["native"] = {"key": OS.get_keycode_string(native_key),
		"prompt_copy": expected_copy, "guest_talk_cd": guest.talk_cd,
		"host_key_conflict": host.binds.values().has(native_key)}
	await _capture(r, receipt, "shortcut_01_native_prompt")
	var prompt_bounds: Rect2 = guest_latch.prompt.get_global_transform_with_canvas() * guest.interaction_prompt_bounds(guest_latch.prompt)
	var hud_panels: Array = [guest.hud.vitals_panel, guest.hud.info_panel, guest.hud.quest_panel, guest.hud.minimap_root]
	for slot in guest.hud.party_slots:
		hud_panels.append(slot.root)
	for panel in hud_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree() \
				and prompt_bounds.intersects(panel.get_global_rect()):
			return "native shortcut prompt overlaps visible HUD panel " + String(panel.name)
	receipt["native_prompt_screen"] = {"position": _v(prompt_bounds.position), "size": _v(prompt_bounds.size), "checked_visible_hud_panels": hud_panels.size()}
	if guest.input_overlay_up() or guest.talk_cd > 0.0 or not guest_latch.prompt.visible:
		return "native readiness changed during the original capture"
	var n0: int = (wire0.qa_shortcut_rx as Array).size()
	var closing_bodies: Array = [host.gates[host._edge_key(a, b)], guest.gates[guest._edge_key(a, b)]]
	_key_event(state, native_key, true)
	# One held press: the guest's normal Game._process polls the intent even
	# with fixture player physics disabled. Wait on the host record only.
	var native_args: Dictionary = {"chapter": CHAPTER, "seed": seed_v, "flag": flag_name}
	var native_world: int = host.world.get_instance_id()
	var got: bool = await r._until(func() -> bool: return not _matching_rx(wire0.qa_shortcut_rx, n0, pid, native_args, native_world).is_empty(), 8.0)
	_key_event(state, native_key, false)
	if not got:
		return "the native press produced no host-received shortcut request (there is NO fallback path)"
	rec = _matching_rx(wire0.qa_shortcut_rx, n0, pid, native_args, native_world)
	if int(rec.get("sender", -1)) != pid:
		return "the successful request is attributed to peer %s, not the guest %d" % [str(rec.get("sender")), pid]
	if not _standing_latch_actor(rec) or bool(rec.get("genuine_before", true)):
		return "native request did not arrive with an eligible actor and closed genuine flag"
	if not bool(rec.get("flag_after", false)) or not bool(rec.get("genuine_after", false)):
		return "the host received the native request but refused it: " + str(rec)
	if not await r._until(func() -> bool: return bool(host.get_flag(flag_name, false)) \
			and bool(guest.get_flag(flag_name, false)), 6.0):
		return "the opened flag never landed on both machines"
	if not await r._until(func() -> bool: return latch_script.find(host) == null \
			and latch_script.find(guest) == null, 5.0):
		return "an opened shortcut kept its latch active"
	for body in closing_bodies:
		if is_instance_valid(body) and body.collision_layer != 0:
			return "an opened shortcut retained an active collision layer"
	if not await r._until(func() -> bool: return not is_instance_valid(closing_bodies[0]) \
			and not is_instance_valid(closing_bodies[1]), 3.0):
		return "the opened barriers did not finish their ordinary fade/removal"
	for g in [host, guest]:
		var gm: Game = g
		if not gm._edge_unlocked(a, b):
			return "the opened shortcut edge is still locked on " + String(gm.name)
		if gm.gates.has(gm._edge_key(a, b)):
			return "an opened shortcut gate still stands on " + String(gm.name)
	_note(receipt, "native_open", {"rx": rec})
	await _capture(r, receipt, "shortcut_02_opened_native")
	# Duplicate after open (deliberate direct client call): observed, inert.
	rec = await _client_open(r, flag_name)
	if rec.is_empty():
		return "duplicate-open receipt never observed"
	if not bool(host.get_flag(flag_name, false)) or not host._edge_unlocked(a, b):
		return "a duplicate open corrupted the shortcut state"
	if not bool(rec.get("flag_before", false)) or not bool(rec.get("flag_after", false)):
		return "duplicate-open witness disagrees with the open flag"
	_note(receipt, "duplicate_after_open", {"rx": rec})
	# --- OPEN movement: ordinary physics crosses both directions ------------
	r.step("shortcut open crossings")
	var cerr: String = await _cross(r, guest, dir_far_to_near, bp, far, near, state, receipt)
	if cerr != "":
		return cerr
	cerr = await _cross(r, guest, OPP[dir_far_to_near], bp, near, far, state, receipt)
	if cerr != "":
		return cerr
	# --- RESNAPSHOT: the SAME guest re-receives the world; a NEW world ------
	# instance is required before any state is read (old equality never
	# satisfies). This is not a third player's late join.
	r.step("shortcut resnapshot")
	var old_world: int = guest.world.get_instance_id()
	r.wires[0]._send_snapshot(pid)
	if not await r._until(func() -> bool: return is_instance_valid(guest.world) \
			and guest.world.get_instance_id() != old_world \
			and bool(r.wires[1].world_ready) and guest.wander_seed == seed_v, 15.0):
		return "resnapshot never stood up a NEW guest world instance"
	r._show(1)
	await r.skip_dialogue()
	guest.player.set_physics_process(false)
	receipt["resnapshot"] = {"old_world_id": old_world, "new_world_id": guest.world.get_instance_id()}
	if guest.shortcut_edge != probe_edge:
		return "resnapshot rebuilt a different shortcut edge"
	if not bool(guest.get_flag(flag_name, false)) or not guest._edge_unlocked(a, b):
		return "resnapshot lost or relocked the opened shortcut"
	for zi in [a, b]:
		guest.cleared[zi] = true
		guest.zone_alive[zi] = 0
	guest._build_room(far)
	if latch_script.find(guest) != null:
		return "an opened shortcut respawned its latch after the resnapshot"
	if guest.gates.has(guest._edge_key(a, b)):
		return "an opened shortcut rebuilt its gate after the resnapshot"
	# --- guest home-world isolation through the ordinary save API -----------
	r.step("shortcut guest save isolation")
	if (guest.no_saves or guest.restoring_save or guest.pvp_active or guest.dedicated
			or not guest.guest_world or guest.save_slot != r.SLOT or not guest.play_started
			or guest.state != guest.ST_PLAYING or guest.player.dead or guest.player.downed or guest.player.ghost):
		return "ordinary guest autosave prerequisites are not satisfied"
	var before_save: Dictionary = SaveGame.read(r.SLOT)
	if before_save.is_empty():
		return "guest save disappeared before explicit autosave"
	# No await between this read, the synchronous autosave and its readback:
	# an unrelated ordinary autosave cannot supply our timestamp witness.
	guest.autosave()  # ordinary character-home route, not the full SaveGame.write
	var saved: Dictionary = SaveGame.read(r.SLOT)
	if saved.is_empty() or float(saved.get("saved_at", 0.0)) <= float(before_save.get("saved_at", 0.0)):
		return "explicit guest autosave did not produce a newly timestamped successful readback"
	if String(saved.get("chapter", "")) != String(home.get("chapter", "")):
		return "guest autosave changed its home chapter"
	if SaveGame.world_of(saved) != SaveGame.world_of(home):
		var changed: Array = []
		for key in SaveGame.world_of(home):
			if SaveGame.world_of(home)[key] != SaveGame.world_of(saved).get(key):
				changed.append(key)
		receipt["save_diagnostic"] = {"world_changed": changed,
			"home_seed": SaveGame.world_of(home).get("wander_seed"),
			"saved_seed": SaveGame.world_of(saved).get("wander_seed")}
		return "shortcut session leaked into the guest's home world save"
	_note(receipt, "guest_home_save_isolated", {"slot": r.SLOT,
		"saved_at_before": before_save.get("saved_at"), "saved_at_after": saved.get("saved_at"),
		"home_chapter": home.get("chapter"), "world_equal": true})
	receipt["remaining_coverage"] = ["opened passage under the first endpoint build order", "solo save/load", "fresh third peer join", "ordinary earned journey", "controller/touch", "physical device"]
	print("ok: shortcut co-op (posed fixture) — fixture/live seed agreement, two witnessed endpoint build orders, one gate body at the shared boundary, closed-edge movement block, full invalid battery with host-received witnesses (wrong chapter/seed/flag, generic spoof, near side, out of range, dead, downed, ghost, uncleared room), NATIVE remapped-key open attributed to the guest peer, inert duplicate, both open crossings, resnapshot onto a new world instance without a latch or gate, guest home save isolated")
	return ""


# ------------------------------------------------------- build witnesses ----

## One rebuild case: build `first` then `second`; the gate must appear with
## the FIRST endpoint build, stay ONE StaticBody2D at the shared boundary,
## and the far-room latch must stand inside the far play rect.
static func _witness_build_order(host: Game, latch_script: GDScript, first: int, second: int,
		a: int, b: int, far: int, bp: Vector2, label: String, receipt: Dictionary) -> String:
	if bool(host.built.get(first, false)) or bool(host.built.get(second, false)):
		return label + ": an endpoint was already built before the explicit order"
	if host.gates.has(host._edge_key(a, b)):
		return label + ": shortcut gate existed before either endpoint was built"
	for zi in [a, b]:
		host.cleared[zi] = true
		host.zone_alive[zi] = 0
	host._build_room(first)
	var key: String = host._edge_key(a, b)
	if not host.gates.has(key):
		return "%s: building room %d did not stand the edge gate" % [label, first]
	var gate: Node2D = host.gates[key]
	if gate == null or not is_instance_valid(gate) or gate.get_parent() != host.world:
		return "%s: the edge gate is not a live child of the current world" % label
	var gate_id: int = gate.get_instance_id()
	host._build_room(second)
	if not host.gates.has(key) or (host.gates[key] as Node2D).get_instance_id() != gate_id:
		return "%s: building the second endpoint replaced the shared gate" % label
	var bodies := 0
	for child in host.world.get_children():
		if child is StaticBody2D and (child as Node2D).position.distance_to(bp) < 1.0:
			bodies += 1
	if bodies != 1:
		return "%s: expected exactly one StaticBody2D at the shared boundary, found %d" % [label, bodies]
	if not gate is StaticBody2D:
		return label + ": gate is not a StaticBody2D"
	var geometry_error: String = _mouth_geometry(host, gate as StaticBody2D, a, b, bp, label, receipt)
	if geometry_error != "":
		return geometry_error
	var latch: Node2D = latch_script.find(host)
	if far in [first, second]:
		if latch == null:
			return "%s: no latch stood after building the far room" % label
		if not host.play_rect(far).has_point(latch.position):
			return "%s: latch %s stands outside the far play rect" % [label, str(latch.position)]
	_note(receipt, "build_order_" + label, {
		"world_id": host.world.get_instance_id(), "order": [first, second],
		"gate_id": gate_id, "gate_pos": _v(gate.position), "boundary": _v(bp),
		"latch_pos": _v(latch.position) if latch != null else null})
	return ""


# ------------------------------------------------------------ movement ------

static func guest_latch_anchor(bp: Vector2, dir: String) -> Vector2:
	return bp + -(DIRV[dir] as Vector2) * APPROACH


static func _playable_mouth(g: Game, room: int, dir: String, boundary: Vector2) -> Vector2:
	var mouth := boundary
	var rect: Rect2 = g.play_rect(room)
	if dir in ["E", "W"]:
		mouth.x = rect.end.x if dir == "E" else rect.position.x
	else:
		mouth.y = rect.end.y if dir == "S" else rect.position.y
	return mouth


## Closed edge: pose ~APPROACH px inside the far endpoint on the door lane,
## hold the FIXED movement key under ordinary Player physics, and require
## real progress toward the gate followed by a stop short of the boundary.
static func _closed_boundary_blocked(r, guest: Game, far: int, dir: String,
		bp: Vector2, state: Dictionary, receipt: Dictionary, scope: String) -> String:
	r.step("shortcut closed boundary " + scope + " " + dir)
	if guest.input_overlay_up() or not guest.play_started or guest.state != guest.ST_PLAYING:
		return scope + ": ordinary movement is not ready"
	var edge: Dictionary = guest.shortcut_edge
	var edge_key: String = guest._edge_key(int(edge["a"]), int(edge["b"]))
	if not guest.gates.has(edge_key):
		return scope + ": closed gate missing before movement"
	var expected_gate: Node2D = guest.gates[edge_key]
	var expected_gate_id: int = expected_gate.get_instance_id()
	var collided_gate := false
	var collided_mouth_bar := false
	var mouth_bar: Rect2 = _mouth_rects(guest, far, dir, bp)[0].rect
	var axis: Vector2 = DIRV[dir]
	var start: Vector2 = _playable_mouth(guest, far, dir, bp) - axis * APPROACH
	if not guest.play_rect(far).has_point(start):
		return "closed approach starts outside the room's playable area"
	guest.player.global_position = start
	guest.player.velocity = Vector2.ZERO
	guest._enter_room(far)
	guest.player.set_physics_process(true)
	var key := int(MOVE_KEY[dir])
	_key_event(state, key, true)
	var samples: Array = []
	var movement_states: Array = []
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await r.get_tree().physics_frame
		samples.append(_v(guest.player.global_position))
		if samples.size() % 12 == 1:
			movement_states.append({"key_held": Input.is_key_pressed(key),
				"locally_controlled": guest.player.is_locally_controlled(),
				"physics": guest.player.is_physics_processing(), "overlay": guest.input_overlay_up(),
				"frozen": guest.player.frozen_time, "rooted": guest.player.rooted_time,
				"velocity": _v(guest.player.velocity), "intent": _v(guest.player.intent_move)})
		for collision_index in guest.player.get_slide_collision_count():
			var collision: KinematicCollision2D = guest.player.get_slide_collision(collision_index)
			if collision.get_collider_id() == expected_gate_id:
				collided_gate = true
				if expected_gate is StaticBody2D and _hit_rect(collision, expected_gate as StaticBody2D, mouth_bar):
					collided_mouth_bar = true
	_key_event(state, key, false)
	var blocked_probe: bool = guest.player.test_move(guest.player.global_transform, axis * 8.0)
	guest.player.set_physics_process(false)
	guest.player.velocity = Vector2.ZERO
	if samples.size() < 40:
		return "closed-boundary sampling collected too few physics frames"
	var goal: float = (bp - start).dot(axis)   # original shared boundary stays forbidden
	var max_prog := 0.0
	for s in samples:
		var sp: Array = s
		var prog: float = (Vector2(float(sp[0]), float(sp[1])) - start).dot(axis)
		if prog > max_prog:
			max_prog = prog
	var last: Array = samples[samples.size() - 1]
	var prior: Array = samples[samples.size() - 31]
	var settled: float = Vector2(float(last[0]), float(last[1])).distance_to(
		Vector2(float(prior[0]), float(prior[1])))
	var final_prog: float = (Vector2(float(last[0]), float(last[1])) - start).dot(axis)
	var thin: Array = []
	for i in range(0, samples.size(), 6):
		thin.append(samples[i])
	_note(receipt, "closed_boundary_observation_" + scope + "_" + dir, {"dir": dir, "start": _v(start),
		"scope": scope, "actual_gate_collision": collided_gate, "gate_id": expected_gate_id,
		"movement_states": movement_states,
		"actual_endpoint_bar_collision": collided_mouth_bar,
		"boundary": _v(bp), "goal_dist": goal, "max_progress": max_prog,
		"final_progress": final_prog, "settled_last_half_second": settled,
		"test_move_blocked": blocked_probe, "samples": thin})
	if max_prog < MIN_PROGRESS:
		return "closed approach never progressed toward the gate (%.1fpx of %.1f required)" % [max_prog, MIN_PROGRESS]
	if max_prog >= goal:
		return "the player's center crossed the closed shared boundary (%.1f >= %.1f)" % [max_prog, goal]
	if not collided_gate:
		return "closed approach did not collide with the actual shortcut gate body"
	if not collided_mouth_bar:
		return "closed approach did not collide with the actual endpoint mouth bar"
	if settled > 2.0:
		return "the closed approach never settled against the gate (%.1fpx drift over the last half second)" % settled
	await _capture(r, receipt, "shortcut_closed_" + scope + "_" + dir)
	return ""


## Opened edge: ordinary movement must actually cross from `from_room` into
## `to_room` (called once per direction).
static func _cross(r, guest: Game, dir: String, bp: Vector2,
		from_room: int, to_room: int, state: Dictionary, receipt: Dictionary) -> String:
	var axis: Vector2 = DIRV[dir]
	guest.player.global_position = guest_latch_anchor(bp, dir)
	guest.player.velocity = Vector2.ZERO
	guest._enter_room(from_room)
	guest.player.set_physics_process(true)
	var key := int(MOVE_KEY[dir])
	_key_event(state, key, true)
	var crossed: bool = await r._until(func() -> bool: return guest.room_at_pos(guest.player.global_position) == to_room \
		and guest.cur_room == to_room and (guest.player.global_position - bp).dot(axis) > 40.0, 8.0)
	_key_event(state, key, false)
	guest.player.set_physics_process(false)
	guest.player.velocity = Vector2.ZERO
	if not crossed:
		return "ordinary movement never crossed the opened edge %d -> %d" % [from_room, to_room]
	_note(receipt, "open_crossing_%d_to_%d" % [from_room, to_room],
		{"dir": dir, "end_pos": _v(guest.player.global_position), "cur_room": guest.cur_room})
	await _capture(r, receipt, "shortcut_open_crossing_" + dir)
	return ""


# ------------------------------------------------------------- requests -----

## Deliberate direct RPC with arbitrary identity fields (invalid battery
## only — the positive path never routes through here). Waits for the exact
## host-received record; {} on timeout.
static func _matching_rx(records: Array, start: int, sender: int, args: Dictionary, world_id: int) -> Dictionary:
	for i in range(start, records.size()):
		var rec: Dictionary = records[i]
		if (int(rec.get("sender", 0)) == sender and sender > 1
				and rec.get("args", {}) == args and int(rec.get("world_id", 0)) == world_id):
			return rec
	return {}


static func _direct_open(r, chapter: String, seed_v: int, flag_arg: String) -> Dictionary:
	var wire0: Node = r.wires[0]
	var start: int = (wire0.qa_shortcut_rx as Array).size()
	var sender: int = r.apis[1].get_unique_id()
	var world_id: int = r.readers[0].world.get_instance_id()
	var args: Dictionary = {"chapter": chapter, "seed": seed_v, "flag": flag_arg}
	r.wires[1]._rpc_shortcut_open.rpc_id(1, chapter, seed_v, flag_arg)
	if not await r._until(func() -> bool: return not _matching_rx(wire0.qa_shortcut_rx, start, sender, args, world_id).is_empty(), 8.0):
		return {}
	return _matching_rx(wire0.qa_shortcut_rx, start, sender, args, world_id)


static func _client_open(r, flag_arg: String) -> Dictionary:
	var wire0: Node = r.wires[0]
	var guest: Game = r.readers[1]
	var start: int = (wire0.qa_shortcut_rx as Array).size()
	var sender: int = r.apis[1].get_unique_id()
	var world_id: int = r.readers[0].world.get_instance_id()
	var args: Dictionary = {"chapter": guest.chapter_id, "seed": guest.wander_seed, "flag": flag_arg}
	r.wires[1].request_shortcut_open(flag_arg)
	if not await r._until(func() -> bool: return not _matching_rx(wire0.qa_shortcut_rx, start, sender, args, world_id).is_empty(), 8.0):
		return {}
	return _matching_rx(wire0.qa_shortcut_rx, start, sender, args, world_id)


## A refusal needs: an observed receipt, flag false in the receipt's after
## state, and the REAL flag/edge untouched on the host. The record carries
## the host-side actor snapshot for the receipt.
static func _expect_refusal(host: Game, a: int, b: int, flag_name: String,
		rec: Dictionary, label: String, receipt: Dictionary) -> String:
	if rec.is_empty():
		return label + ": request receipt never observed on the host"
	var actor: Dictionary = rec.get("actor", {})
	var far: Dictionary = rec.get("far", {})
	if actor.is_empty() or far.is_empty():
		return label + ": receipt had no actual resolved sender body/far room"
	var far_room: int = int(host.shortcut_edge["far"])
	var near_room: int = a if far_room == b else b
	var distance: float = float(rec.get("latch_distance", -1.0))
	var at_latch: bool = int(actor.get("room", -1)) == far_room and distance >= 0.0 and distance < Balance.INTERACT_RANGE
	var alive: bool = float(actor.get("hp", 0.0)) > 0.0 and not bool(actor.get("dead", true))
	var standing: bool = alive and not bool(actor.get("downed", true)) and not bool(actor.get("ghost", true))
	var pacified: bool = bool(far.get("pacified", false))
	var intended := false
	match label:
		"wrong_chapter", "wrong_seed": intended = standing and at_latch and pacified
		"near_side": intended = standing and int(actor.get("room", -1)) == near_room and pacified
		"out_of_range": intended = standing and int(actor.get("room", -1)) == far_room and distance >= Balance.INTERACT_RANGE and pacified
		"dead_hp0": intended = float(actor.get("hp", 1.0)) <= 0.0 and bool(actor.get("dead", false)) and at_latch and pacified
		"downed": intended = alive and bool(actor.get("downed", false)) and not bool(actor.get("ghost", true)) and at_latch and pacified
		"ghost": intended = alive and bool(actor.get("ghost", false)) and not bool(actor.get("downed", true)) and at_latch and pacified
		"uncleared_far_room": intended = standing and at_latch and not pacified
	if not intended:
		return label + ": host receipt did not witness the intended isolated invalid condition: " + str(rec)
	if bool(rec.get("genuine_before", true)) or bool(rec.get("genuine_after", true)):
		return label + ": actual genuine flag changed at receipt"

	if bool(rec.get("flag_after", true)):
		return label + ": host honored an invalid shortcut request: " + str(rec)
	if bool(host.get_flag(flag_name, false)) or host._edge_unlocked(a, b):
		return label + ": the real shortcut flag/edge changed under an invalid request"
	_note(receipt, "refused_" + label, {"rx": rec})
	return ""


# ------------------------------------------------------------ loans/io ------

## Global Input injection with its own ledger, so every return path can
## release exactly what is still held.
static func _key_event(state: Dictionary, keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.physical_keycode = keycode as Key
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var held: Array = state["keys"]
	if pressed:
		held.append(keycode)
	else:
		held.erase(keycode)


static func _release_loans(r, receipt: Dictionary, state: Dictionary) -> void:
	for kc in (state["keys"] as Array).duplicate():
		_key_event(state, int(kc), false)
	var guest: Game = r.readers[1]
	if state["bind"] != null:
		guest.binds["interact"] = int(state["bind"])
		state["bind"] = null
		guest.refresh_interaction_copy()
	if is_instance_valid(guest.player):
		if state["hp"] != null:
			guest.player.hp = float(state["hp"])
			state["hp"] = null
		if bool(state["down"]):
			guest.player.downed = false
			guest.player.ghost = false
			if bool(r.readers[1].qa_online):
				r.wires[1].send_down_state(0)
			state["down"] = false
		guest.player.set_physics_process(false)
		guest.player.velocity = Vector2.ZERO
	var host: Game = r.readers[0]
	if is_instance_valid(host.player):
		host.player.set_physics_process(false)
	_loan(receipt, "released: injected keys cleared, guest interact bind restored, hp/down state restored owner-side, hero physics re-disabled (fixture baseline)")


static func _write_receipt(r, receipt: Dictionary) -> String:
	var wire0: Node = r.wires[0]
	if "qa_shortcut_rx" in wire0:
		receipt["wire_witnesses"] = {"shortcut_rx": wire0.qa_shortcut_rx,
			"flag_rx": wire0.qa_flag_rx}
	var dir: String = String(r.shot_dir) + "/shortcuts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(dir + "/receipt.json", FileAccess.WRITE)
	if file == null:
		return "could not write the shortcut receipt under " + dir
	file.store_string(JSON.stringify(receipt, "  "))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "failed writing shortcut receipt: " + error_string(write_error)
	print("SHORTCUT PARTY RECEIPT: " + ProjectSettings.globalize_path(dir + "/receipt.json"))
	return ""


static func _note(receipt: Dictionary, name: String, data: Dictionary) -> void:
	data["name"] = name
	(receipt["checks"] as Array).append(data)


static func _loan(receipt: Dictionary, what: String) -> void:
	(receipt["loans"] as Array).append(what)


static func _v(p: Vector2) -> Array:
	return [p.x, p.y]


static func _capture(r, receipt: Dictionary, label: String) -> void:
	await r._capture(label)
	(receipt["originals"] as Array).append(String(r.shot_dir) + "/" + label + ".png")


static func _standing_latch_actor(rec: Dictionary) -> bool:
	var actor: Dictionary = rec.get("actor", {})
	var far: Dictionary = rec.get("far", {})
	var distance: float = float(rec.get("latch_distance", -1.0))
	return (not actor.is_empty() and not far.is_empty()
		and float(actor.get("hp", 0.0)) > 0.0 and not bool(actor.get("dead", true))
		and not bool(actor.get("downed", true)) and not bool(actor.get("ghost", true))
		and int(actor.get("room", -1)) == int(far.get("zone", -2))
		and distance >= 0.0 and distance < Balance.INTERACT_RANGE and bool(far.get("pacified", false)))


## Independent contract: cell-centered doorway, main apron inward [2*TILE,3*TILE],
## returns inward [TILE/2,5*TILE/2], immediately outside the doorway span.
## Does not call the production barrier's geometry or trust its child names.
static func _mouth_rects(g: Game, room: int, dir: String, bp: Vector2) -> Array:
	var mouth: Vector2 = _playable_mouth(g, room, dir, bp)
	var inward: Vector2 = -(DIRV[dir] as Vector2)
	var tangent: Vector2 = inward.orthogonal()
	var tile: float = float(g.TILE)
	var half_span: float = float(g.DOOR_TILES) * tile * 0.5
	var result: Array = []
	for band in [[tile * 2.0, tile * 3.0, -half_span, half_span, "bar"],
			[tile * 0.5, tile * 2.5, -half_span - tile, -half_span, "left"],
			[tile * 0.5, tile * 2.5, half_span, half_span + tile, "right"]]:
		var p0: Vector2 = mouth + inward * float(band[0]) + tangent * float(band[2])
		var p1: Vector2 = mouth + inward * float(band[1]) + tangent * float(band[3])
		result.append({"room": room, "role": band[4],
			"rect": Rect2(p0.min(p1), (p1 - p0).abs())})
	return result


static func _shape_rect(cs: CollisionShape2D) -> Rect2:
	var shape := cs.shape as RectangleShape2D
	var half: Vector2 = shape.size * 0.5
	var xf: Transform2D = cs.global_transform
	# An AABB alone could hide a rotated diamond or a sheared shape.
	# Both transformed rectangle axes must stay cardinal and perpendicular.
	if absf(xf.x.x * xf.x.y) > 0.001 or absf(xf.y.x * xf.y.y) > 0.001 or absf(xf.x.dot(xf.y)) > 0.001:
		return Rect2()
	var first: Vector2 = xf * -half
	var bounds := Rect2(first, Vector2.ZERO)
	for point in [Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		bounds = bounds.expand(xf * point)
	return bounds


static func _same_rect(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 0.01 and a.size.distance_to(b.size) < 0.01


static func _mouth_geometry(g: Game, gate: StaticBody2D, a: int, b: int,
		bp: Vector2, label: String, receipt: Dictionary) -> String:
	var expected: Array = []
	for room in [a, b]:
		var other: int = b if room == a else a
		for dir in ["N", "E", "S", "W"]:
			if g.neighbor(room, dir) == other:
				expected.append_array(_mouth_rects(g, room, dir, bp))
	if expected.size() != 6 or gate.collision_layer != 1:
		return label + ": six-mouth setup/layer contract failed"
	var actual: Array = []
	var registered := 0
	for owner in gate.get_shape_owners():
		registered += gate.shape_owner_get_shape_count(owner)
	for child in gate.get_children():
		if child is CollisionShape2D:
			if child.disabled or not child.shape is RectangleShape2D:
				return label + ": disabled or non-rectangle mouth collider"
			actual.append(_shape_rect(child))
	if registered != 6 or actual.size() != 6:
		return label + ": expected exactly six registered direct rectangle shapes, no residual boundary collider"
	var records: Array = []
	for spec in expected:
		var target: Rect2 = spec.rect
		if not g.play_rect(int(spec.room)).encloses(target):
			return label + ": mouth rectangle extends beyond endpoint play_rect"
		var found := -1
		for i in actual.size():
			if _same_rect(actual[i], target):
				found = i
				break
		if found < 0:
			return label + ": actual transformed rectangle differs from mouth contract: " + str(spec)
		var measured: Rect2 = actual[found]
		actual.remove_at(found)
		records.append({"room": spec.room, "role": spec.role,
			"corners": [_v(measured.position), _v(Vector2(measured.end.x, measured.position.y)),
				_v(measured.end), _v(Vector2(measured.position.x, measured.end.y))]})
	if receipt.has("mouth_geometry_reference") and receipt.mouth_geometry_reference != records:
		return label + ": endpoint build orders produced different world collision rectangles"
	receipt["mouth_geometry_reference"] = records.duplicate(true)
	_note(receipt, "six_mouth_rectangles_" + label, {"registered_shapes": registered, "rectangles": records})
	return ""


static func _hit_rect(collision: KinematicCollision2D, gate: StaticBody2D, rect: Rect2) -> bool:
	if collision.get_collider_id() != gate.get_instance_id():
		return false
	var owner_id: int = gate.shape_find_owner(collision.get_collider_shape_index())
	var owner: Object = gate.shape_owner_get_owner(owner_id)
	var collider := owner as CollisionShape2D
	return collider != null and collider.shape is RectangleShape2D and _same_rect(_shape_rect(collider), rect)


## Walk outside each return, outward past the winch, then back toward the
## opening. Only contact with the actual return counts, never the winch.
## This is a posed local attempt, not an exhaustive pathfinding proof.
static func _lateral_mouth_attempts(r, g: Game, room: int, dir: String, bp: Vector2,
		state: Dictionary, receipt: Dictionary, label: String) -> String:
	var axis: Vector2 = DIRV[dir]
	var tangent: Vector2 = (-axis).orthogonal()
	var tile: float = float(g.TILE)
	var mouth: Vector2 = _playable_mouth(g, room, dir, bp)
	var targets: Array = _mouth_rects(g, room, dir, bp)
	var gate: StaticBody2D = g.gates[g._edge_key(int(g.shortcut_edge.a), int(g.shortcut_edge.b))]
	for side in [-1, 1]:
		var role: String = "left" if side < 0 else "right"
		r.step("shortcut lateral " + label + " " + dir + " " + role)
		if g.input_overlay_up() or not g.play_started or g.state != g.ST_PLAYING:
			return label + ": lateral movement not ready"
		var start: Vector2 = mouth - axis * tile * 4.0
		var lateral: Vector2 = tangent * side
		var distance: float = float(g.DOOR_TILES) * tile * 0.5 + tile * 2.0
		if not g.play_rect(room).has_point(start) or g._pos_in_wall(start):
			return label + ": lateral staging point is not clear playable space"
		g.player.global_position = start
		g.player.velocity = Vector2.ZERO
		g._enter_room(room)
		g.player.set_physics_process(true)
		var side_key := KEY_D if lateral.x > 0.5 else (KEY_A if lateral.x < -0.5 else (KEY_S if lateral.y > 0.5 else KEY_W))
		_key_event(state, side_key, true)
		var begin: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - begin < 2000 and (g.player.global_position - start).dot(lateral) < distance:
			await r.get_tree().physics_frame
		_key_event(state, side_key, false)
		g.player.velocity = Vector2.ZERO
		var moved: float = (g.player.global_position - start).dot(lateral)
		if moved < distance or moved > distance + tile * 0.25:
			return label + ": lateral native input failed to reach the return lane: " + str(moved)
		var outside: Vector2 = g.player.global_position
		_key_event(state, int(MOVE_KEY[dir]), true)
		begin = Time.get_ticks_msec()
		while Time.get_ticks_msec() - begin < 2000 and (g.player.global_position - outside).dot(axis) < tile * 2.0:
			await r.get_tree().physics_frame
		_key_event(state, int(MOVE_KEY[dir]), false)
		g.player.velocity = Vector2.ZERO
		var outward: float = (g.player.global_position - outside).dot(axis)
		if outward < tile * 2.0 or outward > tile * 2.25:
			return label + ": native outer approach failed to clear the winch: " + str(outward)
		var turn: Vector2 = g.player.global_position
		var return_axis: Vector2 = -lateral
		var return_key := KEY_D if return_axis.x > 0.5 else (KEY_A if return_axis.x < -0.5 else (KEY_S if return_axis.y > 0.5 else KEY_W))
		var wanted: Rect2 = targets[1 if side < 0 else 2].rect
		var hit_return := false
		var points: Array[Vector2] = []
		_key_event(state, return_key, true)
		begin = Time.get_ticks_msec()
		while Time.get_ticks_msec() - begin < 2000:
			await r.get_tree().physics_frame
			points.append(g.player.global_position)
			for i in g.player.get_slide_collision_count():
				if _hit_rect(g.player.get_slide_collision(i), gate, wanted):
					hit_return = true
		_key_event(state, return_key, false)
		g.player.set_physics_process(false)
		g.player.velocity = Vector2.ZERO
		if points.size() < 40:
			return label + ": insufficient lateral-attempt physics observations"
		var max_progress := 0.0
		var crossed := false
		var thin: Array = []
		for i in points.size():
			max_progress = maxf(max_progress, (points[i] - turn).dot(return_axis))
			crossed = crossed or (points[i] - mouth).dot(axis) >= 0.0
			if i % 6 == 0:
				thin.append(_v(points[i]))
		var settled: float = points[-1].distance_to(points[-31])
		_note(receipt, "lateral_return_" + label + "_" + dir + "_" + role,
			{"start": _v(start), "outside": _v(outside), "turn": _v(turn), "side_progress": moved, "outward_progress": outward, "return_progress": max_progress,
			"actual_return_collision": hit_return, "crossed_mouth": crossed, "settled": settled, "samples": thin})
		if max_progress < tile * 0.5 or not hit_return or crossed or settled > 2.0:
			return label + ": lateral return did not physically block the attempted bypass: " + role
		await _capture(r, receipt, "shortcut_lateral_" + label + "_" + dir + "_" + role)
	return ""
