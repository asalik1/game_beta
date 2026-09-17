extends RefCounted
## Disposable existing-room probe: input walks; camera/hero physics stay live.
const Clearance := preload("res://scripts/ui/hud_clearance.gd")
var r: Node
var g: Game
var p: Player
var baseline := false
var room := -1
var bounds := Rect2()
var rows: Array[Dictionary] = []
var views: Array[Dictionary] = []
var walks: Array[Dictionary] = []
var held := 0
var extra_evidence := {}


static func run(rig: Node) -> String:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	probe.baseline = rig.flag("baseline")
	return await probe._run()


func _check(id: String, ok: bool, detail: Variant, anticipated := false) -> void:
	var status := "pass" if ok else "baseline_finding" if baseline and anticipated else "fail"
	rows.append({"id": id, "status": status, "detail": detail})
	print("NORTH EDGE ", id, ": ", status)


func _run() -> String:
	r.shot_dir = String(r.shot_dir).path_join("north_edge")
	_check("fresh", g.no_saves and not g.net_online() and not g.dev_god and not p.dead,
		"fresh offline Mage; no god mode or HP/resource grants")
	for i in g.zones.size():
		if String(g.zones[i].name) == "Village Outskirts": room = i
	_check("room_found", room >= 0, room)
	if room >= 0:
		await _exercise()
	_release()
	var findings: Array[String] = []
	for row in rows:
		if row.status == "baseline_finding": findings.append(String(row.id))
	var expected: Array[String] = []
	if baseline: expected.append("north.tracker_clear")
	_check("baseline_exact", findings == expected, {"actual": findings, "expected": expected})
	var failures := 0
	for row in rows: failures += int(row.status == "fail")
	var report := {"baseline": baseline, "touch_requested": r.flag("touch"), "rows": rows, "views": views, "walks": walks, "extra": extra_evidence,
		"failures": failures, "findings": findings.size(), "complete": failures == 0,
		"scope": "Disposable Village Outskirts with enemies removed and ambient hazards delayed; static world/props/walls retained. Initial corridor placement is controlled, subsequent north/south/return travel uses held W/S with live local physics and production camera limits/smoothing. HUD body bounds are the production class-height proxy, not measured painted-alpha pixels; original screenshots require manual review. Base mode makes no earned route, combat, target framing, long wrapped objective, network or physical-device claim; optional extra evidence declares its own presentation controls. Touch mode enables host touch presentation; travel still uses keyboard input."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(r.shot_dir)))
	var file := FileAccess.open(String(r.shot_dir).path_join("acceptance.json"), FileAccess.WRITE)
	if file == null: return "Cannot write north-edge receipt"
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("NORTH EDGE: checks=%d failures=%d findings=%d complete=%s" % [rows.size(), failures, findings.size(), failures == 0])
	return "" if failures == 0 else "North-edge probe failed: %d" % failures


func _exercise() -> void:
	r.step("quiet existing road; retain walls, props and ordinary camera")
	g.settings["touch_controls"] = r.flag("touch")
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	p.global_position = g.room_center(room)
	g._enter_room(room)
	await r.skip_dialogue()
	g.terrain_event_t = 10000.0 # _enter_room resets this clock.
	g.hazard_tick = 10000.0
	for e in r.get_tree().get_nodes_in_group("enemies"):
		if g.world.is_ancestor_of(e): e.queue_free()
	g.current_boss = null
	g.bosses.clear()
	g.zone_alive[room] = 0
	g.cleared[room] = true
	g.boss_spawned[room] = true
	g.refresh_quest()
	await r.frames(3)
	bounds = g.play_rect(room)
	var north_y := bounds.position.y + 100.0
	var south_y := bounds.end.y - 180.0
	var corridor := Vector2.INF
	# Read-only collision sweeps choose a static-prop-clear vertical corridor.
	# This does not disable collision, move a prop, or waive actual input reach.
	for dx in [-120.0, 120.0, -180.0, 180.0, -240.0, 240.0, 0.0]:
		var start := Vector2(bounds.get_center().x + dx, bounds.get_center().y)
		var transform := p.global_transform
		transform.origin = start
		if not p.test_move(transform, Vector2(0, north_y - start.y)) \
				and not p.test_move(transform, Vector2(0, south_y - start.y)):
			corridor = start
			break
	_check("corridor_found", corridor.is_finite(), {"play_rect": _rect(bounds), "corridor": _vec(corridor) if corridor.is_finite() else []})
	if not corridor.is_finite(): return
	p.global_position = corridor
	p.clear_local_intents()
	await r.sim_wait(1.2)
	await _capture("middle", false)
	await _walk("north", north_y)
	await r.sim_wait(1.2)
	await _capture("north", true)
	if r.flag("camera-lead"):
		var camera_report: Dictionary = await preload("res://scripts/tests/camera_lead_live.gd").run(self)
		_check("camera_probe_complete", bool(camera_report.complete), camera_report)
	if r.flag("extra"):
		_check("extra.strict_only", not baseline, "extended presentation controls require strict mode")
		if not baseline:
			extra_evidence = await preload("res://scripts/tests/north_edge_extra.gd").run(self)
	await _walk("south", south_y)
	await r.sim_wait(1.2)
	await _capture("south", false)
	await _walk("middle_return", corridor.y)
	await r.sim_wait(1.2)
	await _capture("middle_return", false)


func _walk(id: String, target_y: float) -> void:
	r.step("held movement to " + id)
	var start := p.global_position
	var direction := signf(target_y - start.y)
	var key := KEY_S if direction > 0 else KEY_W
	var deadline := Time.get_ticks_msec() + 10000
	var samples: Array[Dictionary] = []
	_press(key, true)
	while Time.get_ticks_msec() < deadline:
		await r.get_tree().process_frame
		samples.append({"position": _vec(p.global_position), "room": g.cur_room,
			"physics_frame": Engine.get_physics_frames(), "physics_live": p.is_physics_processing()})
		if (target_y - p.global_position.y) * direction <= 8.0: break
		if g.cur_room != room or p.dead or g.input_overlay_up(): break
	_release()
	await r.frames(2)
	var finish := p.global_position
	var evidence := {"id": id, "start": _vec(start), "finish": _vec(finish), "target_y": target_y,
		"samples": samples, "held_key": int(key)}
	walks.append(evidence)
	_check(id + ".input_reached", absf(finish.y - target_y) <= 28.0 and absf(finish.x - start.x) <= 8.0
		and start.distance_to(finish) >= 100.0 and g.cur_room == room and samples.size() >= 3, evidence)
	_check(id + ".physics_live", p.is_physics_processing() and g.is_processing()
		and not r.get_tree().paused and not g.input_overlay_up() and not p.dead, "normal local movement/camera processing")


func _capture(id: String, anticipated: bool) -> void:
	await r.frames(2)
	await RenderingServer.frame_post_draw
	var body := Clearance.body_rect(p)
	var panel := g.hud.quest_panel.get_global_rect()
	var viewport := g.get_viewport_rect()
	var overlap := body.intersection(panel)
	var view := {"id": id, "body_proxy": _rect(body), "tracker": _rect(panel), "intersection": _rect(overlap),
		"hero_world": _vec(p.global_position), "hero_canvas_origin": _vec(p.get_global_transform_with_canvas().origin),
		"clearance_offset": g.hud.tracker_clearance.offset_y, "clearance_no_fit": g.hud.tracker_clearance.no_fit,
		"quest": g.hud.quest_label.text, "zone": g.hud.zone_label.text, "quest_key": g.quest_key,
		"camera_zoom": _vec(g.camera.zoom), "camera_offset": _vec(g.camera.offset),
		"camera_limits": [g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom],
		"camera_smoothing": g.camera.position_smoothing_enabled, "camera_lead": g.settings.get("camera_lead", 1.0)}
	views.append(view)
	_check(id + ".body_in_frame", body.has_area() and viewport.encloses(body), view)
	_check(id + ".tracker_readable", g.hud.quest_panel.is_visible_in_tree() and g.hud.quest_label.is_visible_in_tree()
		and not g.hud.quest_label.text.is_empty() and viewport.encloses(panel)
		and g.hud.quest_label.self_modulate.a == 1.0, view)
	_check(id + ".production_camera", g.camera.position_smoothing_enabled
		and g.camera.limit_left == int(bounds.position.x) and g.camera.limit_top == int(bounds.position.y)
		and g.camera.limit_right == int(bounds.end.x) and g.camera.limit_bottom == int(bounds.end.y), view)
	_check(id + ".tracker_clear", not body.intersects(panel), view, anticipated)
	r.shot(id, "live-input edge probe; body bounds are a proxy; manual original-frame review required")


func _press(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	held = key if down else 0


func _release() -> void:
	if held != 0: _press(held, false)
	p.clear_local_intents()


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
