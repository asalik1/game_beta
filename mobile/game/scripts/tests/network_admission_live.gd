extends RefCounted
## The production manager is instantiated unchanged in three multiplayer scopes.
## Only unused gameplay Session children are removed before any connection.
## No direct auth calls, auth callback overrides, fake manager or child process.
const NetManager := preload("res://scripts/net/net_manager.gd")
const STEP_TIMEOUT := 12.0

var r: ShotRig
var scopes: Array[Node] = []
var apis: Array[SceneMultiplayer] = []
var managers: Array[Node] = []
var observer_connections: Array[Dictionary] = []
var events: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var phase := "setup"
var prior := ""
var global_before := {}
var panel: PanelContainer
var status: Label


static func run(rig: ShotRig) -> Dictionary:
	var proof := new()
	proof.r = rig
	proof.prior = rig.arg("prior", proof._previous_version(NetManager.NET_VERSION))
	proof._build_board()
	var error: String = await proof._run()
	proof._check("runtime.completed", error == "", error)
	proof.phase = "cleanup"
	proof._cleanup()
	await rig.frames(2)
	var retired_apis: Array[WeakRef] = proof._release_scopes()
	var apis_released := true
	for reference in retired_apis:
		apis_released = apis_released and reference.get_ref() == null
	proof._check("cleanup.apis_released", apis_released,
		"scoped SceneMultiplayer instances have no remaining strong references")
	proof._check("cleanup.root_autoload_unchanged", proof._global_state() == proof.global_before,
		"root NetworkManager is never hosted, joined, left or rebound")
	var failed := false
	for row in proof.rows:
		failed = failed or not bool(row.passed)
	proof._show_status("Failed" if failed else "Completed", error)
	await proof._capture("03_result")
	return proof._report()


func _previous_version(current: String) -> String:
	var parts := current.split(".")
	if parts.size() != 3 or not String(parts[2]).is_valid_int() or int(parts[2]) <= 0:
		return ""
	return "%s.%s.%d" % [parts[0], parts[1], int(parts[2]) - 1]


func _run() -> String:
	global_before = _global_state()
	if not _check("fixture.root_autoload_idle", not bool(global_before.get("online", true))
			and Array(global_before.get("peers", [])).is_empty(), global_before):
		return "root autoload must be idle before scoped test"
	if not _check("fixture.real_prior_version", prior != "" and prior != NetManager.NET_VERSION,
			{"current": NetManager.NET_VERSION, "prior": prior}):
		return "supply --prior=<previous shipped version> for a nonnumeric current version"
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--noray"):
			return "Noray smoke flags are forbidden for this local transport fixture"
	for label in ["Host", "CurrentClient", "PriorClient"]:
		_scope(String(label))
	_check("fixture.distinct_multiplayer_scopes", apis[0] != apis[1] and apis[0] != apis[2]
		and apis[1] != apis[2] and apis[0].get_instance_id() != int(global_before.api)
		and apis[1].get_instance_id() != int(global_before.api)
		and apis[2].get_instance_id() != int(global_before.api),
		"three independent SceneMultiplayer instances under one SceneTree")
	for index in 3:
		var manager: Node = managers[index]
		var api: SceneMultiplayer = apis[index]
		_check("ready.scoped_auth_callback.%d" % index,
			api.auth_callback.get_object() == manager
			and api.auth_callback.get_method() == "_on_auth_received"
			and is_equal_approx(api.auth_timeout, NetManager.AUTH_TIMEOUT)
			and manager.get_multiplayer() == api,
			{"scope": str(scopes[index].get_path()), "callback": String(api.auth_callback.get_method())})
		_check("ready.unmodified_manager.%d" % index,
			manager.get_script() == NetManager and manager.session == null
			and manager.get_node_or_null("Session") == null,
			"production _ready ran; unused gameplay bridge removed before any host/join")
	var host: Node = managers[0]
	var matched: Node = managers[1]
	var old: Node = managers[2]
	phase = "host"
	r.step("production host() binds an ephemeral local ENet port")
	var error: Error = await host.host(NetManager.Mode.ENET_DIRECT, "127.0.0.1:0")
	if not _check("host.started", error == OK and host.is_host(), error_string(error)):
		return "production host failed"
	var transport := apis[0].multiplayer_peer as ENetMultiplayerPeer
	if not _check("host.actual_enet", transport != null and transport.host != null, "actual ENet host"):
		return "host did not create an ENet transport"
	var port: int = transport.host.get_local_port()
	if not _check("host.ephemeral_bound_port", port > 0, port):
		return "production ENet did not bind a real port"
	var code := "127.0.0.1:%d" % port
	# Production stores the requested ':0' in its display code. Read the actual
	# ENet port solely to address this fixture; do not rewrite session_code.
	_check("host.empty_pre_admission", host.peers.is_empty() and apis[0].get_peers().is_empty()
		and apis[0].get_authenticating_peers().is_empty(), "no manually admitted peers")
	phase = "matched_first"
	r.step("matching production version admitted through real authentication")
	error = await matched.join(code)
	if not _check("matched.join_attempt", error == OK, error_string(error)):
		return "matching join did not start"
	if not await _until(func() -> bool:
			return _count(0, "joined") == 1 and _count(1, "joined") == 1):
		return "matching production manager did not admit both ends"
	var first_pid := apis[1].get_unique_id()
	_check("matched.rosters", first_pid > 1 and _only_peer(host.peers, first_pid) and _only_peer(matched.peers, 1)
		and _only_peer(apis[0].get_peers(), first_pid)
		and _only_peer(apis[1].get_peers(), 1), {"host": host.peers.duplicate(), "client": matched.peers.duplicate()})
	_check("matched.auth_finished", apis[0].get_authenticating_peers().is_empty()
		and apis[1].get_authenticating_peers().is_empty()
		and _count(0, "authenticating") >= 1 and _count(1, "authenticating") >= 1,
		"transport entered authentication and left it by production callbacks")
	_check("matched.no_refusal", _count(0, "rejected") == 0 and _count(1, "ended") == 0
		and String(matched.version_override) == "", "default actual NET_VERSION")
	_show_status("Current version admitted", "Host and client both received peer_joined after authentication.")
	await _capture("01_current_admitted")
	phase = "matched_leave"
	matched.leave()
	if not await _until(func() -> bool: return _count(0, "left") == 1 and host.peers.is_empty()):
		return "host did not observe matching client's clean leave"
	_check("leave.same_peer", int(_last(0, "left").id) == first_pid
		and not matched.is_online() and matched.peers.is_empty()
		and apis[1].multiplayer_peer is OfflineMultiplayerPeer,
		"same admitted peer left; client restored its offline transport")
	var ended_before := _count(1, "ended")
	matched.leave()
	await r.frames(2)
	_check("leave.idempotent", ended_before == 1 and _count(1, "ended") == ended_before, "second leave emits no new session end")
	phase = "prior_rejected"
	r.step("previous version refused before admission with exact surfaced reason")
	old.version_override = prior  # existing production TESTS ONLY claim seam
	error = await old.join(code)
	if not _check("prior.join_attempt", error == OK, error_string(error)):
		return "prior-version join did not start"
	if not await _until(func() -> bool: return _count(0, "rejected") == 1 and _count(2, "ended") == 1):
		return "prior-version rejection/reason did not reach both ends"
	var rejection := _last(0, "rejected")
	var reason := String(rejection.reason)
	_check("prior.exact_reason_survives_disconnect", reason.contains("version mismatch")
		and reason.contains(NetManager.NET_VERSION) and reason.contains(prior)
		and String(_last(2, "ended").reason) == reason and String(old.last_reject_reason) == reason, reason)
	_check("prior.never_admitted", _count(0, "joined") == 1 and _count(2, "joined") == 0
		and host.peers.is_empty() and old.peers.is_empty()
		and not old.is_online() and int(old.mode) == NetManager.Mode.OFFLINE
		and apis[0].get_peers().is_empty() and apis[0].get_authenticating_peers().is_empty(),
		{"rejected_id": rejection.id, "host_join_events": _count(0, "joined"), "client_join_events": _count(2, "joined")})
	_check("prior.no_ghost_leave", _count(0, "left") == 1, "a rejected peer was never an admitted roster member")
	_show_status("Previous version refused", reason)
	await _capture("02_prior_rejected")
	phase = "matched_rejoin"
	r.step("same admitted manager can cleanly rejoin after leave and another peer's refusal")
	error = await matched.join(code)
	if not _check("rejoin.attempt", error == OK, error_string(error)):
		return "matching rejoin did not start"
	if not await _until(func() -> bool: return _count(0, "joined") == 2 and _count(1, "joined") == 2):
		return "matching manager could not rejoin"
	var second_pid := apis[1].get_unique_id()
	_check("rejoin.clean_roster", _only_peer(host.peers, second_pid) and _only_peer(matched.peers, 1)
		and String(matched.last_reject_reason) == "" and apis[0].get_authenticating_peers().is_empty(),
		{"host": host.peers.duplicate(), "client": matched.peers.duplicate()})
	matched.leave()
	if not await _until(func() -> bool: return _count(0, "left") == 2 and host.peers.is_empty()):
		return "rejoined client's clean leave did not propagate"
	_check("rejoin.same_leave_id", int(_last(0, "left").id) == second_pid, second_pid)
	phase = "refused_manager_recovers"
	r.step("previously refused manager joins truthfully, then observes production host close")
	old.version_override = ""
	error = await old.join(code)
	if not _check("recovered.attempt", error == OK, error_string(error)):
		return "previously refused manager could not retry"
	if not await _until(func() -> bool: return _count(0, "joined") == 3 and _count(2, "joined") == 1):
		return "previously refused manager did not recover with the current version"
	_check("recovered.reject_state_cleared", String(old.last_reject_reason) == ""
		and _count(0, "rejected") == 1 and _only_peer(old.peers, 1), "old mismatch text does not poison a truthful join")
	host.leave()
	if not await _until(func() -> bool: return _count(2, "ended") == 2 and not old.is_online()):
		return "production host close did not end admitted guest session"
	_check("host_close.truthful_reason", String(_last(2, "ended").reason).contains("host closed")
		and not String(_last(2, "ended").reason).contains("version"), _last(2, "ended"))
	_check("host_close.all_offline", not host.is_online() and not matched.is_online() and not old.is_online()
		and host.peers.is_empty() and matched.peers.is_empty() and old.peers.is_empty(), "all scoped managers returned offline")
	return ""


func _scope(label: String) -> void:
	var index := scopes.size()
	var scope := Node.new()
	scope.name = "Admission" + label
	r.add_child(scope)
	scopes.append(scope)
	var api := SceneMultiplayer.new()
	r.get_tree().set_multiplayer(api, scope.get_path())
	apis.append(api)
	var manager: Node = NetManager.new()
	manager.name = "NetworkManager"
	scope.add_child(manager)  # actual production _ready binds this scope's auth
	managers.append(manager)
	var bridge: Node = manager.session
	if bridge != null:
		manager.remove_child(bridge)
		bridge.free()  # removes only Game/lobby signal listeners, no auth callbacks
		manager.session = null
	_observe(manager.peer_joined, func(id: int, _info: Dictionary) -> void: _event(index, "joined", id))
	_observe(manager.peer_left, func(id: int) -> void: _event(index, "left", id))
	_observe(manager.peer_rejected, func(id: int, reason: String) -> void: _event(index, "rejected", id, reason))
	_observe(manager.session_ended, func(reason: String) -> void: _event(index, "ended", 0, reason))
	_observe(api.peer_authenticating, func(id: int) -> void: _event(index, "authenticating", id))
	_observe(api.peer_authentication_failed, func(id: int) -> void: _event(index, "authentication_failed", id))


func _observe(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	observer_connections.append({"source": source, "callback": callback})


func _event(index: int, kind: String, id: int, reason := "") -> void:
	events.append({"scope": index, "kind": kind, "id": id, "reason": reason,
		"phase": phase, "frame": Engine.get_process_frames(), "milliseconds": Time.get_ticks_msec(),
		"admitted": managers[index].peers.duplicate()})


func _count(index: int, kind: String) -> int:
	var total := 0
	for entry in events:
		if int(entry.scope) == index and String(entry.kind) == kind:
			total += 1
	return total


func _only_peer(values: Variant, id: int) -> bool:
	return values.size() == 1 and int(values[0]) == id


func _last(index: int, kind: String) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if int(events[i].scope) == index and String(events[i].kind) == kind:
			return events[i]
	return {}


func _until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + roundi(STEP_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await r.get_tree().create_timer(0.03, true).timeout
	return bool(predicate.call())


func _global_state() -> Dictionary:
	var manager: Node = r.get_node_or_null("/root/NetworkManager")
	if manager == null:
		return {"online": true, "error": "missing production autoload"}
	var api := manager.get_multiplayer() as SceneMultiplayer
	if api == null:
		return {"online": true, "error": "root autoload has no SceneMultiplayer"}
	var auth_owner := api.auth_callback.get_object()
	return {"id": manager.get_instance_id(), "api": api.get_instance_id(),
		"auth_owner": auth_owner.get_instance_id() if is_instance_valid(auth_owner) else 0,
		"auth_method": String(api.auth_callback.get_method()), "auth_timeout": api.auth_timeout,
		"transport": api.multiplayer_peer.get_instance_id() if api.multiplayer_peer != null else 0,
		"online": manager.is_online(), "mode": manager.mode, "peers": manager.peers.duplicate(),
		"session_code": manager.session_code, "reject": manager.last_reject_reason,
		"notice": manager.last_session_notice, "override": manager.version_override,
		"lobby_open": manager.lobby_open, "session": manager.session.get_instance_id() if is_instance_valid(manager.session) else 0}


func _cleanup() -> void:
	for manager in managers:
		if is_instance_valid(manager):
			manager.leave()
	# API signal lambdas capture this RefCounted proof, which owns the APIs.
	# Disconnect only our observers, then discard their capturing Callables.
	for observer in observer_connections:
		var source: Signal = observer.source
		var callback: Callable = observer.callback
		if is_instance_valid(source.get_object()) and source.is_connected(callback):
			source.disconnect(callback)
	observer_connections.clear()
	for i in scopes.size():
		apis[i].multiplayer_peer = OfflineMultiplayerPeer.new()
		r.get_tree().set_multiplayer(null, scopes[i].get_path())
		scopes[i].queue_free()


func _release_scopes() -> Array[WeakRef]:
	var scopes_released := true
	for scope in scopes:
		scopes_released = scopes_released and not is_instance_valid(scope)
	_check("cleanup.scopes_released", scopes_released,
		"queued scope Nodes and their production managers were freed before API release")
	var retired: Array[WeakRef] = []
	for api in apis:
		retired.append(weakref(api))
		# Managers are retired now; no production auth callback is changed in flight.
		api.auth_callback = Callable()
	apis.clear()
	managers.clear()
	scopes.clear()
	# This method's final loop reference expires before the caller probes WeakRefs.
	return retired


func _build_board() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(80, 120)
	panel.size = Vector2(1120, 450)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(panel)
	UITheme.apply(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Network admission — one-engine QA fixture"
	UITheme.title(title, 28)
	box.add_child(title)
	var context := Label.new()
	context.text = "Production NetworkManager · Local ENet · Current " + NetManager.NET_VERSION + " / Prior " + prior
	context.add_theme_font_size_override("font_size", 18)
	box.add_child(context)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 20)
	box.add_child(status)
	var note := Label.new()
	note.text = "Transport-only fixture. No gameplay snapshot, user save, Noray connection or second engine."
	note.add_theme_font_size_override("font_size", 16)
	box.add_child(note)
	_show_status("Starting", "")


func _show_status(headline: String, detail: String) -> void:
	var failures := 0
	for row in rows:
		failures += int(not bool(row.passed))
	status.text = headline + "\n\n" + detail + "\n\nChecks: %d · Failures: %d" % [rows.size(), failures]


func _capture(name: String) -> void:
	await r.frames(2)
	await RenderingServer.frame_post_draw
	if not r.flag("no-capture"):
		r.shot(name, "QA fixture display; assertions use actual production manager signals and transport peer lists")


func _check(id: String, passed: bool, detail: Variant) -> bool:
	rows.append({"id": id, "passed": passed, "detail": detail})
	return passed


func _report() -> Dictionary:
	var passed := 0
	for row in rows:
		passed += int(bool(row.passed))
	var failures := rows.size() - passed
	return {"status": "passed" if failures == 0 else "failed", "checks": rows.size(),
		"passed": passed, "failures": failures, "rows": rows, "events": events,
		"current_version": NetManager.NET_VERSION, "prior_version": prior, "engine_pid": OS.get_process_id(),
		"production_manager_script": "res://scripts/net/net_manager.gd",
		"qualification": "One SceneTree, three real SceneMultiplayer/NetworkManager scopes, real local ENet authentication and lifecycle signals. Production managers unmodified; unused gameplay Session children removed before connection. No direct auth invocation, Noray, child process, UI admission flow or gameplay compatibility claim."}
