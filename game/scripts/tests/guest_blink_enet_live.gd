extends "res://shot_party_appearance.gd"
## Controlled two-reader episode; no persistence or campaign completion proof.
var owner_rig: ShotRig
var guest_id := 0
var held_key := 0
var pending_probe := Callable()
var probe_result: Dictionary = {}
var watch_cast := false
var landing: Dictionary = {}
var excluded_groups: Array[Node] = []
var actor: HitActor
var mirror: Enemy
var actor_point := Vector2.ZERO

class HitActor extends Enemy:
	var received: Array[Dictionary] = []
	func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
		var before := hp
		var source := hit_src.peer_id if is_instance_valid(hit_src) else 0
		var sender := multiplayer.get_remote_sender_id()
		super.take_damage(amount, from_dir, is_crit, silent)
		received.append({"sender": sender, "source": source, "raw": amount,
			"hp_before": before, "hp_after": hp, "applied": before - hp,
			"crit": is_crit, "silent": silent, "physics_frame": Engine.get_physics_frames()})

func _init() -> void:
	super()
	if _watchdog != null:
		remove_child(_watchdog)
		_watchdog.free()
		_watchdog = null

func _ready() -> void:
	process_physics_priority = 1000

func _process(_delta: float) -> void:
	if owner_rig != null: owner_rig.game = game

func step(label: String) -> void:
	super(label)
	if owner_rig != null:
		owner_rig.game = game
		owner_rig.last_step = label

func _show(index: int) -> void:
	super(index)
	owner_rig.game = game

func shot(label: String, extra: String = "") -> String:
	owner_rig.game = game
	owner_rig.shot_dir = shot_dir
	var path := owner_rig.shot(label, extra)
	shots_taken = owner_rig.shots_taken
	return path

func run() -> int:
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/guest-blink-enet-candidate/"):
		push_error("Guest Blink requires isolated APPDATA inside guest-blink-enet-candidate")
		return 1
	report = {"checks": 0, "failures": [], "cases": [], "real_enet_transport": true,
		"ordinary_campaign": false, "save_writes_requested": false,
		"fixture": "Two inherited ch1 readers, manually admitted/ready like appearance QA; real join-ready, enemy spawn/state, hit and movement RPCs. Stationary observer Enemy uses production _setup/_ready/add_enemy, native guest a3 input, full 1|4 body mask. Host local physics/input disabled; guest frozen immediately after cast. Other tree-wide enemy groups excluded. Evasion set to zero on actor/mirror; fresh ordinary Mage stats, mana/cooldown reset between two cases. No moving-AI, latency, world-snapshot, physical-device, damage balance or reward claim."}
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	var error := await _episode()
	_release()
	watch_cast = false
	pending_probe = Callable()
	if error != "":
		report.failures.append(error)
		_show(1)
		await _capture("diagnostic")
	await _cleanup()
	report["complete"] = error == "" and report.failures.is_empty()
	report["shots"] = shots_taken
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var output := FileAccess.open(shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	if output == null:
		push_error("Cannot write guest Blink acceptance report")
		return 1
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("GUEST BLINK ENET: checks=%d failures=%d cases=%d complete=%s report=%s" % [
		report.checks, report.failures.size(), report.cases.size(), report.complete,
		ProjectSettings.globalize_path(shot_dir.path_join("acceptance.json"))])
	return 0 if report.complete else 1

func _episode() -> String:
	var host: Game = readers[0]
	var guest: Game = readers[1]
	for index in 2:
		_show(index)
		await skip_dialogue()
		readers[index].dev_god = false
		readers[index].save_slot = -1
		readers[index].player.set_physics_process(false)
		readers[index].gust_vec = Vector2.ZERO
		readers[index].terrain_event_t = 10000.0
		if not await _until(func() -> bool: return readers[index].play_started and not readers[index].input_overlay_up() and not get_tree().paused, 5.0):
			return "reader never reached ordinary playing/overlay-clear boot gates"
	# A SceneTree group is shared even though these readers have separate physics
	# worlds. Only the guest mirror may enter this guest's strike scan.
	for node in get_tree().get_nodes_in_group("enemies"):
		node.set_physics_process(false)
		node.remove_from_group("enemies")
		excluded_groups.append(node)
	host.player.set_process_input(false)
	if transports[0].create_server(0, 2) != OK: return "ENet host bind failed"
	apis[0].multiplayer_peer = transports[0]
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK:
		return "ENet guest connect failed"
	apis[1].multiplayer_peer = transports[1]
	if not await _until(func() -> bool: return not apis[0].get_peers().is_empty(), 5.0):
		return "ENet handshake timed out"
	guest_id = apis[1].get_unique_id()
	roots[0].peers[guest_id] = {}
	roots[1].peers[1] = {}
	host.player.peer_id = 1
	guest.player.peer_id = guest_id
	for index in 2:
		readers[index].qa_online = true
		wires[index].world_ready = true
	wires[1]._rpc_join_ready.rpc_id(1, wires[1]._char_block())
	if not await _until(func() -> bool: return _shell(0, guest_id) != null and _shell(1, 1) != null, 5.0):
		return "real join-ready RPC did not create both remote shells"
	_check(guest.net_guest() and host.net_host(), "real scoped host/guest authority")
	_check(guest.player.is_locally_controlled() and not _shell(0, guest_id).is_locally_controlled(), "guest owns its body; host copy is remote")
	_show(1)
	var floor_sample := await _probe(_find_floor)
	if not bool(floor_sample.get("found", false)): return "no unchanged clear floor for both posed cases in both readers"
	actor_point = Vector2(float(floor_sample.point[0]), float(floor_sample.point[1]))
	report["floor"] = floor_sample
	# Same construction as Enemy.make: the observer only records one inherited
	# take_damage call, while _setup/_ready and the host factory remain normal.
	actor = HitActor.new()
	actor._setup(host, "wolf", actor_point, 8, 1.0)
	actor.zone_idx = -1
	actor.eva = 0.0
	actor.set_physics_process(false)
	host.add_enemy(actor)
	actor.set_physics_process(false)
	actor.remove_from_group("enemies")
	excluded_groups.append(actor)
	if not await _until(func() -> bool:
		var value: Variant = wires[1].net_enemies.get(actor.net_id)
		return is_instance_valid(value) and value.is_inside_tree(), 5.0):
		return "production host _ready spawn did not deliver a live guest mirror"
	mirror = wires[1].net_enemies[actor.net_id]
	mirror.eva = 0.0
	_check(actor.net_id > 0 and mirror.net_id == actor.net_id and mirror.net_mirror, "same registered actor arrived through real spawn RPC")
	_check(mirror.collision_layer == 4 and mirror.collision_mask == 0 and mirror.is_physics_processing(), "normal mirror layer/mask and presentation processing")
	_check(not actor.is_physics_processing() and not actor.dying and actor.hp > 0, "host observer is a stationary live ordinary actor")
	_check(guest.player.collision_mask == 5 and guest.player.collision_layer == 2, "guest retains ordinary full body mask")
	_check(process_physics_priority > guest.player.process_physics_priority, "landing observer runs after the ordinary Player physics callback")
	_check(get_tree().get_nodes_in_group("enemies") == [mirror], "guest mirror is the sole SceneTree strike target")
	if not report.failures.is_empty(): return "network/actor setup controls failed"
	for occupied in [true, false]:
		var error := await _case(occupied)
		if error != "": return error
	return ""

func _case(occupied: bool) -> String:
	var g: Game = readers[1]
	var p: Player = g.player
	var label := "occupied_actor_endpoint" if occupied else "clear_endpoint_across_actor"
	step(label)
	_release()
	p.set_physics_process(false)
	p.clear_local_intents()
	p.global_position = actor_point - Vector2(190.0 if occupied else 95.0, 0)
	p.velocity = Vector2.ZERO
	p.facing = Vector2.RIGHT
	p.mp = p.max_mp
	p.cds.a3 = 0.0
	var start := p.global_position
	var intended := g.clamp_to_zone(start + Vector2(190, 0), start)
	var host_before := _hero_state(readers[0].player)
	var economy_before := [_economy(readers[0]), _economy(g)]
	var before := await _probe(func() -> Dictionary: return {
		"start_hits": _overlaps(p, start), "endpoint_hits": _overlaps(p, intended),
		"midpoint_hits": _overlaps(p, actor_point), "start": _v(start), "intended": _v(intended)})
	if before.is_empty(): return label + ": bounded physics geometry observer timed out"
	before.merge({"label": label, "occupied": occupied, "hp": actor.hp, "mirror_hp": mirror.hp,
		"host_max_hp": actor.max_hp, "mirror_max_hp": mirror.max_hp,
		"mana": p.mp, "cost": p.ability_cost("a3"), "normal_cd": p.ability_cd("a3"),
		"mask": p.collision_mask, "mirror_layer": mirror.collision_layer,
		"keycode": int(g.binds.a3), "overlay": g.input_overlay_up(), "paused": get_tree().paused,
		"no_godmode": not g.dev_god, "actor_position": _v(actor.global_position),
		"mirror_position": _v(mirror.global_position), "host_observer": host_before}, true)
	var row := {"before": before}
	report.cases.append(row)
	if not before.start_hits.is_empty(): return label + ": starting floor not clear"
	if intended.distance_to(start + Vector2(190, 0)) > 0.01: return label + ": room clamp changed the intended fixture"
	if g.input_overlay_up() or get_tree().paused or p.dead or p.downed or p.ghost or p.frozen_time > 0 or p.rooted_time > 0:
		return label + ": input gates not clear"
	if p.combo != 0.0 or not p._tfx.is_empty() or p.cls != "mage" or p.mp < p.ability_cost("a3"):
		return label + ": expected fresh unthemed Mage/no combo fixture changed"
	if not _contains(before.midpoint_hits, mirror) or before.endpoint_hits.size() != (1 if occupied else 0):
		return label + ": replicated actor does not provide the exact occupied/clear endpoint control"
	if occupied and not _contains(before.endpoint_hits, mirror): return label + ": wrong endpoint blocker"
	if not occupied and not (start.x < actor_point.x and actor_point.x < intended.x):
		return label + ": actor is not between the clear endpoints"
	actor.received.clear()
	wires[0].last_hit = {}
	landing = {}
	await _capture(label + "_before")
	if not report.failures.is_empty(): return label + ": initial native framing controls failed"
	watch_cast = true
	_press(int(g.binds.a3))
	p.set_physics_process(true)
	if not await _until(func() -> bool: return not landing.is_empty(), 2.0):
		_release()
		p.set_physics_process(false)
		watch_cast = false
		return label + ": native a3 did not fire"
	row["landing"] = landing.duplicate(true)
	var end := p.global_position
	_check(bool(landing.raw_key_down) and bool(landing.intent_a3) and landing.intent_move == [0.0, 0.0], label + ": native held a3, zero movement and actual polled intent")
	_check(landing.hits.is_empty() and p.collision_mask == 5, label + ": first post-Player-physics landing clear under full mask")
	_check(absf(float(before.mana) - p.mp - float(before.cost)) < 0.01 and absf(float(landing.cd) - float(before.normal_cd)) < 0.01, label + ": one ordinary mana debit/cooldown edge")
	_check(end.is_finite() and p.velocity == Vector2.ZERO and p.motion_faults == int(landing.motion_faults_before), label + ": finite landing with no motion recovery")
	if occupied:
		_check(end.x > start.x + 100.0 and end.x < intended.x and absf(end.y - intended.y) < 0.01, label + ": feet stop on the intended segment before actor")
	else:
		_check(end.distance_to(intended) < 0.01, label + ": clear endpoint beyond the actor remains unchanged")
	if not await _until(func() -> bool: return actor.received.size() >= 1, 4.0):
		return label + ": host did not accept a guest hit"
	await _settle(0.6)
	var remote := _shell(0, guest_id)
	var converged := await _until(func() -> bool:
		return remote.global_position.distance_to(end) < 0.5 and not remote.net_snaps.is_empty() \
			and Vector2(remote.net_snaps.back().pos).distance_to(end) < 0.01 \
			and absf(mirror.hp / mirror.max_hp - actor.hp / actor.max_hp) <= 1.0 / 255.0 + 0.0001, 4.0)
	row["convergence"] = {"converged": converged, "host_hits": actor.received.duplicate(true),
		"last_hit": wires[0].last_hit.duplicate(true), "host_hp": actor.hp, "mirror_hp": mirror.hp,
		"host_fraction": actor.hp / actor.max_hp, "mirror_fraction": mirror.hp / mirror.max_hp,
		"remote_position": _v(remote.global_position), "remote_snapshots": remote.net_snaps.duplicate(true),
		"owner_position": _v(end), "host_after": _hero_state(readers[0].player),
		"observed_cast_edges": 1, "actual_host_take_damage_calls": actor.received.size()}
	_check(converged, label + ": ordinary movement snapshots and quantized enemy HP converge")
	var wire_fraction := float(int(clampf(actor.hp / actor.max_hp, 0.0, 1.0) * 255.0)) / 255.0
	_check(absf(mirror.hp / mirror.max_hp - wire_fraction) < 0.00001, label + ": mirror fraction matches the host stream's exact quantized value")
	row.convergence["expected_wire_fraction"] = wire_fraction
	_check(actor.received.size() == 1, label + ": exactly one actual host damage call for base Mage Blink")
	if actor.received.size() == 1:
		var hit: Dictionary = actor.received[0]
		_check(int(hit.sender) == guest_id and int(hit.source) == guest_id and not bool(hit.silent), label + ": accepted reliable hit is attributed to the guest shell")
		_check(float(hit.applied) > 0.0 and absf(float(hit.applied) - float(hit.raw)) < 0.01 \
			and absf(float(before.hp) - actor.hp - float(hit.applied)) < 0.01, label + ": exact host HP debit matches its accepted hit")
		_check(int(wires[0].last_hit.get("id", 0)) == actor.net_id and int(wires[0].last_hit.get("peer", 0)) == guest_id \
			and absf(float(wires[0].last_hit.get("amount", -1)) - float(hit.raw)) < 0.01, label + ": production hit ledger agrees with observed application")
	_check(_hero_state(readers[0].player) == host_before, label + ": host hero position, mana, cooldowns and resources unchanged")
	_check([_economy(readers[0]), _economy(g)] == economy_before and actor.hp > 0.0 and not actor.dying \
		and not mirror.dying, label + ": live target, no death or reward")
	_check(actor.global_position.distance_to(actor_point) < 0.01 and mirror.global_position.distance_to(actor_point) < 0.01, label + ": same stationary real actor/mirror")
	_check(p.global_position == end and absf(p.mp - float(landing.mp)) < 0.01 and not Input.is_key_pressed(int(g.binds.a3)), label + ": owner frozen at measured landing and input released")
	await _capture(label + "_converged")
	return "" if report.failures.is_empty() else label + ": strict checks failed"

func _physics_process(_delta: float) -> void:
	if pending_probe.is_valid():
		var work := pending_probe
		pending_probe = Callable()
		probe_result = work.call()
	if not watch_cast or not landing.is_empty(): return
	var p: Player = readers[1].player
	if float(p.cds.a3) <= 0.0: return
	landing = {"position": _v(p.global_position), "hits": _overlaps(p, p.global_position),
		"cd": p.cds.a3, "mp": p.mp, "physics_frame": Engine.get_physics_frames(),
		"raw_key_down": Input.is_key_pressed(held_key), "intent_a3": p.intent_a3,
		"intent_move": _v(p.intent_move), "mask": p.collision_mask,
		"optimistic_mirror_hp": mirror.hp, "optimistic_mirror_fraction": mirror.hp / mirror.max_hp,
		"motion_faults": p.motion_faults, "motion_faults_before": int(report.get("motion_faults_before", 0))}
	p.set_physics_process(false)
	watch_cast = false
	_release()

func _probe(work: Callable) -> Dictionary:
	probe_result = {}
	pending_probe = work
	if not await _until(func() -> bool: return not probe_result.is_empty(), 3.0):
		pending_probe = Callable()
	return probe_result.duplicate(true)

func _find_floor() -> Dictionary:
	var rect: Rect2 = readers[1].play_rect(0)
	var candidates: Array[Vector2] = []
	for y in range(int(rect.position.y + 170), int(rect.end.y - 170), 80):
		for x in range(int(rect.position.x + 280), int(rect.end.x - 200), 80):
			candidates.append(Vector2(x, y))
	# Same floor candidates and collision/clamp checks, ordered toward the room
	# heart so the normal bounded camera does not leave the cast under the HUD.
	var center := rect.get_center()
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	var checked := 0
	for point in candidates:
		checked += 1
		var clear := true
		for index in 2:
			for offset in [-190.0, -95.0, 0.0, 95.0]:
				var at := point + Vector2(offset, 0)
				clear = clear and _overlaps(readers[index].player, at).is_empty() \
					and readers[index].clamp_to_zone(at, point).distance_to(at) < 0.01
		if clear: return {"found": true, "point": _v(point), "unchanged_world_geometry": true,
			"order": "nearest room center first", "candidates_checked": checked,
			"room_center": _v(center), "distance_from_center": point.distance_to(center)}
	return {"found": false, "candidates_checked": checked}

func _overlaps(p: Player, point: Vector2) -> Array:
	var rows: Array = []
	var excluded: Array[RID] = [p.get_rid()]
	for exception in p.get_collision_exceptions():
		if is_instance_valid(exception): excluded.append(exception.get_rid())
	for owner in p.get_shape_owners():
		if p.is_shape_owner_disabled(owner): continue
		for index in p.shape_owner_get_shape_count(owner):
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = p.shape_owner_get_shape(owner, index)
			query.transform = p.global_transform * p.shape_owner_get_transform(owner)
			query.transform.origin += point - p.global_position
			query.collision_mask = p.collision_mask
			query.margin = p.safe_margin
			query.exclude = excluded
			query.collide_with_areas = false
			query.collide_with_bodies = true
			for hit in p.get_world_2d().direct_space_state.intersect_shape(query, 32):
				var body := hit.collider as CollisionObject2D
				rows.append({"id": body.get_instance_id(), "path": str(body.get_path()), "layer": body.collision_layer})
	return rows

func _contains(rows: Array, node: Node) -> bool:
	for row in rows:
		if int(row.id) == node.get_instance_id(): return true
	return false

func _hero_state(p: Player) -> Dictionary:
	return {"position": _v(p.global_position), "hp": p.hp, "mp": p.mp, "cds": p.cds.duplicate(true),
		"gold": p.gold, "xp": p.xp, "level": p.level, "dead": p.dead, "downed": p.downed,
		"ghost": p.ghost, "materials": p.materials.duplicate(true), "bag": p.backpack.duplicate(true)}

func _economy(g: Game) -> Dictionary:
	var p: Player = g.player
	return {"gold": p.gold, "xp": p.xp, "materials": p.materials.duplicate(true), "bag": p.backpack.duplicate(true),
		"consumables": p.consumables.duplicate(true), "mail": g.mailbox.duplicate(true),
		"flags": g.flags.duplicate(true), "boss_done": g.boss_done.duplicate(true), "cleared": g.cleared.duplicate(true),
		"kill_counts": g.kill_counts.duplicate(true), "loot_rng_state": g.loot_rng.state,
		"ground_drops": g.dropped_loot.duplicate(true)}

func _press(key: int) -> void:
	held_key = key
	report["motion_faults_before"] = readers[1].player.motion_faults
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _release() -> void:
	if held_key == 0: return
	var event := InputEventKey.new()
	event.keycode = held_key
	event.physical_keycode = held_key
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	held_key = 0

func _until(predicate: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if bool(predicate.call()): return true
		await get_tree().create_timer(0.02, true).timeout
	return bool(predicate.call())

func _check(ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label)
		print("GUEST BLINK FAIL: " + label)

func _v(value: Vector2) -> Array:
	return [value.x, value.y]

func _capture(label: String) -> void:
	# Let the actual arrival-title tween finish; never hide HUD or change alpha.
	if label != "diagnostic":
		var title_clear := await _until(func() -> bool:
			return game.hud.title_label.modulate.a < 0.05 and game.hud.subtitle_label.modulate.a < 0.05, 6.0)
		_check(title_clear, label + ": ordinary arrival title finished before capture")
	await frames(2)
	await RenderingServer.frame_post_draw
	if label != "diagnostic":
		var framing := _capture_bounds()
		framing["label"] = label
		if not report.has("capture_framing"): report["capture_framing"] = []
		report.capture_framing.append(framing)
		_check(bool(framing.complete), label + ": complete visible hero and actor sprite bounds clear actual HUD controls")
	shot(label, "controlled stationary actor/ENet fixture; no reward or ordinary combat claim")

func _capture_bounds() -> Dictionary:
	var subjects: Array = []
	var complete := true
	var screen: Rect2 = game.get_viewport().get_visible_rect()
	# Sprite2D.get_rect is the actual current-frame canvas, conservatively
	# including transparent pixels. It is not a cropped artistic silhouette.
	for sprite in [game.player.sprite, mirror.sprite]:
		var rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		var hits := _hud_visual_hits(rect)
		var visible: bool = sprite.is_visible_in_tree() and _canvas_alpha(sprite) >= 0.05
		complete = complete and visible and rect.has_area() and screen.grow(0.75).encloses(rect) and hits.is_empty()
		subjects.append({"path": str(sprite.get_path()), "rect": str(rect), "visible": visible, "hud_hits": hits})
	return {"complete": complete, "subjects": subjects, "viewport": str(screen),
		"camera_position": _v(game.camera.global_position), "zoom": _v(game.camera.zoom),
		"camera_limits": [game.camera.limit_left, game.camera.limit_top, game.camera.limit_right, game.camera.limit_bottom],
		"camera_override": false, "body_or_scenery_override": false}

func _hud_visual_hits(subject: Rect2) -> Array:
	var hits: Array = []
	for node in game.hud.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree() or _canvas_alpha(c) < 0.05: continue
		# Ignore decorative fullscreen washes; include visual IGNORE labels too.
		if c == game.hud.vignette or c == game.hud.overlay or c == game.hud.flash_rect: continue
		var visible_piece: bool = c is Label or c is Button or c is Panel or c is TextureRect or c is ColorRect \
			or c == game.hud.minimap_root or c == game.hud.wayfinder.get("quest_root")
		if not visible_piece: continue
		if c is Label and c.text.strip_edges().is_empty(): continue
		if c is TextureRect and c.texture == null: continue
		if c is ColorRect and c.color.a < 0.05: continue
		var rect: Rect2 = c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
		var parent := c.get_parent()
		while parent != null and parent != game.hud:
			if parent is Control and parent.clip_contents:
				rect = rect.intersection(parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size))
			parent = parent.get_parent()
		if rect.has_area() and rect.intersects(subject):
			hits.append({"path": str(c.get_path()), "class": c.get_class(), "rect": str(rect), "alpha": _canvas_alpha(c)})
	return hits

func _canvas_alpha(item: CanvasItem) -> float:
	var alpha := item.self_modulate.a
	var current: Node = item
	while current != null:
		if current is CanvasItem: alpha *= current.modulate.a
		current = current.get_parent()
	return alpha

func _cleanup() -> void:
	# Stop forwarding the reader before its scope is freed during frames().
	set_process(false)
	set_physics_process(false)
	game = null
	owner_rig.game = null
	get_tree().paused = false
	for index in readers.size():
		readers[index].player.set_physics_process(false)
		readers[index].no_saves = true
		readers[index].save_slot = -1
		readers[index].guest_world = false
		readers[index].qa_online = false
		wires[index].set_physics_process(false)
		roots[index].online = false
	for transport in transports: transport.close()
	for index in apis.size():
		apis[index].multiplayer_peer = null
		get_tree().set_multiplayer(null, roots[index].get_path())
	for node in excluded_groups:
		if is_instance_valid(node): node.add_to_group("enemies")
	excluded_groups.clear()
	for screen in screens: screen.queue_free()
	await frames(2)
	_check(not is_instance_valid(actor) and not is_instance_valid(mirror), "paired scopes and observed actors cleaned up")
	roots.clear()
	wires.clear()
	readers.clear()
	transports.clear()
	apis.clear()
	screens.clear()
