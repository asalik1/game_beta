extends RefCounted
## Posed real-factory visuals; two native-input pickup controls, no earned-loot claim.
const Geometry := preload("res://scripts/prop_shadow.gd")
const SPECS := [{"id": "F", "opts": {"grade": "F", "gem_ok": false}},
	{"id": "B", "opts": {"grade": "B", "gem_ok": false}},
	{"id": "bronze", "opts": {"kind": "supply", "supply_tier": "bronze", "boss_lv": 1}}]
var r: Node
var g: Game
var findings: Array[String] = []
var rows: Array[Dictionary] = []
var shots: Array[String] = []
var owned: Array[Chest] = []


static func run(rig: Node) -> void:
	var q := new()
	q.r = rig
	rig.shot_dir = "user://shots/prop_shadows/chests"
	await rig.boot("warrior", "ch1", false)
	q.g = rig.game
	q._check("isolated_normal_hero", q.g.no_saves and not q.g.net_online()
		and not q.g.dev_god and not q.g.dev_mode and q.g.player.level == 1)
	for chapter in ["ch1", "ch3"]:
		await q._floor(chapter)
	q._key(false)
	await q._retire()
	var expected: Array[String] = ["ch1/F/closed_contact", "ch1/bronze/closed_contact",
		"ch3/F/closed_contact", "ch3/bronze/closed_contact"]
	if rig.flag("baseline"):
		q._check("baseline_exact_measured_findings", q.findings == expected)
	else:
		q._check("strict_no_findings", q.findings.is_empty())
	q._write()
	print("CHEST GROUNDING: %d checks, %d failures, %d findings" % [rig.checks.size(), rig.failures, q.findings.size()])
	rig.finish(1 if rig.failures > 0 else 0)


func _floor(chapter: String) -> void:
	await _retire()
	if g.chapter_id != chapter:
		g.switch_chapter(chapter, true)
	# boot() already calls skip_dialogue; repeat after either floor seam to
	# drain any newly queued conversation before declaring this posed fixture.
	await r.skip_dialogue()
	g.menus.close()
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.request_pause(false)
	g.hud.visible = true
	g.settings["combat_framing"] = false
	g.settings["camera_lead"] = 0.0
	g.settings["camera_shake"] = 0.0
	g.camera.position_smoothing_enabled = false
	g.terrain_event_t = 1.0e9 # quiet visual fixture, not ordinary exploration
	g.npc_emote_t = 1.0e9
	g.player.set_physics_process(false)
	_check(chapter + "/safe_floor", g.room_type(g.cur_room) == "safe" and not g.dev_god)
	# Production boot rewards are not fixture rewards. Retire their visuals only.
	for node in g.get_children():
		if node is Chest or node is Pickup: node.queue_free()
	for node in g.zone_scenery.get(g.cur_room, []):
		if is_instance_valid(node) and node is CanvasItem: node.visible = false
	var origin: Vector2 = g.room_center(g.cur_room)
	g.player.global_position = origin + Vector2(0, 140)
	g.camera.position = Vector2.ZERO
	g.camera.offset = Vector2.ZERO
	g.camera.zoom = Vector2(1.25, 1.25)
	g.camera.reset_smoothing()
	await r._settle()
	# Let the real reveal/title finish; do not cancel or hide its overlay.
	var reveal_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < reveal_deadline and not _reveal_clear():
		await r.frames(1)
	_check(chapter + "/reveal_finished", _reveal_clear())
	_check(chapter + "/playing_fixture", g.play_started and g.state == Game.ST_PLAYING
		and g.hud.visible and not g.input_overlay_up() and not r.get_tree().paused)
	for i in SPECS.size():
		var c: Chest = Chest.drop(g, "wood", origin + Vector2((i - 1) * 165, -50), SPECS[i].opts)
		owned.append(c)
	# Record the real scale pop; the current design has no continuous bob.
	await _sample_window(chapter + "/pop", 0.4)
	for i in owned.size():
		var label: String = chapter + "/" + String(SPECS[i].id)
		var row := _record(label + "/closed", owned[i])
		var meets: bool = float(row.shadow_bottom) >= float(row.painted_bottom) - 0.25
		_contact(label + "/closed_contact", meets, SPECS[i].id != "B")
	await _shot(chapter + "_01_closed")
	var rest: Array[Transform2D] = []
	var ground: Array[float] = []
	for c in owned:
		rest.append(c.body_sprite.transform)
		ground.append((c.body_sprite.transform * Geometry.foot(c.body_sprite, Geometry.shape(c.body_sprite))).y)
	await _sample_window(chapter + "/idle", 0.35)
	for i in owned.size():
		_check(chapter + "/" + String(SPECS[i].id) + "/no_idle_bob", owned[i].body_sprite.transform == rest[i])
		# Direct visual helper preview ONLY; does not claim opening, payment or decay.
		owned[i]._open_moment()
	await _sample_window(chapter + "/lid", 0.8)
	for i in owned.size():
		var c: Chest = owned[i]
		var opened_row := _record(chapter + "/" + String(SPECS[i].id) + "/open_preview", c)
		_check(chapter + "/" + String(SPECS[i].id) + "/painted_base_preserved",
			is_equal_approx(float(opened_row.painted_bottom), ground[i]))
		_check(chapter + "/" + String(SPECS[i].id) + "/preview_final_frame",
			c.body_sprite.hframes == 5 and c.body_sprite.frame == 4 and not c.opened)
	await _shot(chapter + "_02_open_preview")
	await _retire()
	await _pickup(chapter, origin)


func _pickup(chapter: String, origin: Vector2) -> void:
	var p: Player = g.player
	var point := origin + Vector2(0, 65)
	var before_gold: int = p.gold
	var before_bag: int = p.backpack.size()
	var before_gear: Dictionary = p.equipment.duplicate(true)
	var c: Chest = Chest.drop(g, "wood", point, {"grade": "F", "gem_ok": false})
	owned.append(c)
	var contents: Dictionary = c.sealed_contents().duplicate(true) # read normal pre-roll, never replace it
	var item: Dictionary = contents.items[0].item
	var expected_gold: int = p.gold_yield(int(contents.gold))
	_check(chapter + "/pickup_capacity", p.bag_used() < p.bag_capacity())
	var clear := not p.test_move(p.global_transform, point - p.global_position)
	_check(chapter + "/pickup_corridor", clear)
	if not clear: return
	await r.sim_wait(0.4)
	var shadow: Sprite2D = _shadow(c)
	var chest_ref: WeakRef = weakref(c)
	var shadow_ref: WeakRef = weakref(shadow)
	p.set_physics_process(true)
	var input_ready: bool = g.play_started and g.state == Game.ST_PLAYING and g.hud.visible \
		and not g.input_overlay_up() and not g.menus.is_open() and not g.hud.dialogue_active \
		and not g.hud.choices_active and not r.get_tree().paused and p.is_physics_processing() \
		and p.is_locally_controlled() and not p.dead and not p.downed and not p.ghost and _reveal_clear()
	_check(chapter + "/pickup_input_ready", input_ready)
	if not input_ready:
		p.set_physics_process(false)
		return
	var start: Vector2 = p.global_position
	_key(true)
	var elapsed := 0.0
	while is_instance_valid(c) and not c.opened and elapsed < 2.0:
		await r.get_tree().process_frame
		elapsed += r.get_process_delta_time()
	_key(false)
	p.set_physics_process(false)
	_check(chapter + "/ordinary_movement", start.distance_to(p.global_position) > 20.0 and g.play_started)
	_check(chapter + "/input_pickup_opened", is_instance_valid(c) and c.opened)
	_check(chapter + "/exact_payout", p.gold == before_gold + expected_gold
		and p.backpack.size() == before_bag + 1 and p.backpack.has(item) and p.equipment == before_gear)
	await r.sim_wait(0.8)
	if is_instance_valid(c):
		_record(chapter + "/pickup_open", c)
		await _shot(chapter + "_03_input_pickup")
	await r.sim_wait(Balance.CHEST_OPEN_HOLD + 0.7)
	_check(chapter + "/parent_shadow_freed", chest_ref.get_ref() == null and shadow_ref.get_ref() == null)
	_check(chapter + "/payout_once", p.gold == before_gold + expected_gold and p.backpack.size() == before_bag + 1)
	owned.clear()


func _sample_window(label: String, seconds: float) -> void:
	var elapsed := 0.0
	var identities: Dictionary = {}
	var footprints: Dictionary = {}
	var stable := true
	var stationary := true
	while elapsed < seconds:
		await r.get_tree().process_frame
		elapsed += r.get_process_delta_time()
		for i in owned.size():
			if not is_instance_valid(owned[i]):
				stable = false
				continue
			var row: Dictionary = _record(label + "/" + String(SPECS[i].id), owned[i], false)
			if not identities.has(i): identities[i] = [row.body_id, row.shadow_id]
			if not footprints.has(i): footprints[i] = [row.shadow_transform, row.shadow_rect]
			stable = stable and int(row.shadow_count) == 1 and int(row.shadow_id) != 0 \
				and identities[i] == [row.body_id, row.shadow_id]
			stationary = stationary and footprints[i] == [row.shadow_transform, row.shadow_rect]
	_check(label + "/persistent_single_shadow", stable and identities.size() == owned.size())
	_check(label + "/stationary_ground_footprint", stationary and footprints.size() == owned.size())


func _shadow(c: Chest) -> Sprite2D:
	for child in c.get_children():
		if child is Sprite2D and child.texture == Art.tex("shadow"): return child
	return null


func _record(label: String, c: Chest, checked := true) -> Dictionary:
	var body: Sprite2D = c.body_sprite
	var shadow: Sprite2D = _shadow(c)
	var geometry: Dictionary = Geometry.shape(body)
	var local_foot: Vector2 = body.transform * Geometry.foot(body, geometry)
	var shadows := 0
	for child in c.get_children():
		if child is Sprite2D and (child.texture == Art.tex("shadow") or child.has_meta("cast_shadow")): shadows += 1
	var row := {"label": label, "body_id": body.get_instance_id(), "shadow_id": shadow.get_instance_id() if shadow != null else 0,
		"shadow_count": shadows, "frame": body.frame, "hframes": body.hframes,
		"opened": c.opened, "painted_bottom": local_foot.y, "body_scale": str(body.scale),
		"body_position": str(body.position), "shadow_bottom": (shadow.transform * shadow.get_rect().end).y if shadow != null else -9999.0,
		"shadow_position": str(shadow.position) if shadow != null else "missing",
		"shadow_transform": str(shadow.transform) if shadow != null else "missing",
		"shadow_rect": str(shadow.get_rect()) if shadow != null else "missing",
		"canvas_foot": str(body.get_global_transform_with_canvas() * Geometry.foot(body, geometry)),
		"parent_position": str(c.global_position), "frame_number": Engine.get_process_frames()}
	rows.append(row)
	if checked:
		_check(label + "/one_shadow", shadows == 1 and shadow != null)
		_check(label + "/behind_body", shadow != null and (shadow.z_index < body.z_index
			or (shadow.z_index == body.z_index and shadow.get_index() < body.get_index())))
		_check(label + "/visible", body.is_visible_in_tree() and shadow != null and shadow.is_visible_in_tree())
		if shadow != null:
			var footprint: Vector2 = shadow.get_rect().size * shadow.scale
			_check(label + "/retained_footprint", footprint.is_equal_approx(Vector2(44.0, 14.4)))
			if not r.flag("baseline"):
				var inset := local_foot.y - shadow.position.y
				_check(label + "/ground_contact", absf(local_foot.x - shadow.position.x) <= 0.5
					and inset >= 0.0 and inset <= footprint.y * 0.25)
		var bounds: Rect2 = r._body_bounds(c, true)
		_check(label + "/onscreen", Rect2(Vector2.ZERO, Vector2(r.get_viewport().get_visible_rect().size)).encloses(bounds))
	return row


func _contact(label: String, meets: bool, anticipated: bool) -> void:
	# A visible mismatch, not a general visual-quality score: fixed shadow ends
	# above the lowest painted closed foot. B's 0.05px rounding is tolerated.
	if not meets and anticipated and r.flag("baseline"):
		findings.append(label)
		return
	_check(label, meets)


func _check(label: String, passed: bool) -> void:
	r._check("chests/" + label, passed)


func _reveal_clear() -> bool:
	return g.cutscene == null and not g.hud._cinematic_mode and not g.input_overlay_up() \
		and g.hud.overlay.color.a <= 0.001 and g.hud.title_label.modulate.a <= 0.01 \
		and g.hud.subtitle_label.modulate.a <= 0.01


func _key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _retire() -> void:
	for c in owned:
		if is_instance_valid(c): c.queue_free()
	owned.clear()
	await r.frames(3)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	shots.append(r.shot(label, "posed real Chest.drop on real safe-room floor; direct opening previews; separate ordinary-key pickup"))
	_write()


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		_check("receipt_written", false)
		return
	file.store_string(JSON.stringify({"baseline": r.flag("baseline"), "findings": findings,
		"checks": r.checks, "failures": r.failures, "samples": rows, "shots": shots,
		"renderer": RenderingServer.get_current_rendering_method(),
		"scope": "Controlled real-factory chest views. Quiet terrain, hidden scenery, posed hero; normal input only for separate pickup. No earned loot or physical-device claim."}, "\t"))
	file.close()
