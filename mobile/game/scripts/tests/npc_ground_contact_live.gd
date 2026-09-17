extends RefCounted
## Five diagnostic originals, three sequential factory NPCs. No input/art changes.
var r: Node
var g: Game
var saved: Dictionary = {}
var visibility: Dictionary = {}
var entries: Array = []
var loot_modes: Dictionary = {}
var setup_drain: Dictionary = {}
var npc: Node2D
var samples: Array[Dictionary] = []
var geometry_samples: Array[Dictionary] = []


static func run(rig: Node) -> void:
	var q := new()
	q.r = rig
	rig.shot_dir = "user://shots/prop_shadows/npc_contact"
	var profile := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	q._check("isolated_profile_path", profile.contains("/build/qa/"))
	if rig.failures > 0:
		rig.finish(1)
		return
	await rig.boot("warrior", "ch3", false)
	q.g = rig.game
	var okay: bool = await q._stage()
	if okay:
		q._spawn("ragged_soldier", "wander_deserter")
		await q._capture("ragged_1x", 1.0)
		await q._capture("ragged_close", 1.75)
		await rig.sim_wait(1.7) # Same actor, normal tween; not prescribed breath extrema.
		await q._capture("ragged_breath_later", 1.75)
		await q._retire()
		q._spawn("old_hunter", "wander_hunter")
		await q._capture("old_hunter_close", 1.75)
		await q._retire()
		q._spawn("flame_pilgrim", "wander_pilgrim")
		await q._capture("flame_pilgrim_close", 1.75)
	q._check("five_measured_originals", q.samples.size() == 5)
	await q._retire()
	if okay and rig.flag("npc-grounding-strict"):
		await q._geometry_controls()
	q._restore()
	q._write()
	print("NPC CONTACT: %d checks, %d failures; diagnostic only, manual review required" % [rig.checks.size(), rig.failures])
	rig.finish(1 if rig.failures > 0 else 0)


func _stage() -> bool:
	g.play_started = true
	g.menus.close()
	g.state = Game.ST_PLAYING
	g.request_pause(false)
	await r.skip_dialogue()
	_check("isolated_safe_native", g.no_saves and not g.net_online() and not g.dev_god
		and not g.dev_mode and g.room_type(g.cur_room) == "safe" and DisplayServer.get_name() != "headless")
	if r.failures > 0: return false
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and not _revealed(): await r.frames(1)
	_check("real_reveal_finished", _revealed())
	if r.failures > 0: return false
	var p: Player = g.player
	saved = {"settings": g.settings.duplicate(true), "hud": g.hud.visible,
		"terrain_event_t": g.terrain_event_t, "npc_emote_t": g.npc_emote_t,
		"player_position": p.global_position, "player_visible": p.visible,
		"player_physics": p.is_physics_processing(), "velocity": p.velocity,
		"zoom": g.camera.zoom, "position": g.camera.position, "offset": g.camera.offset,
		"smoothing": g.camera.position_smoothing_enabled, "look": g._cam_look,
		"zoom_mult": g._cam_zoom_mult}
	entries = g.interactables.duplicate()
	for node in g.zone_scenery.get(g.cur_room, []): _hide(node)
	for entry in entries: _hide(entry.get("node"))
	g.interactables.clear()
	g.hud.visible = false
	g.terrain_event_t = 1.0e9
	g.npc_emote_t = 1.0e9
	g.settings["combat_framing"] = false
	g.settings["camera_lead"] = 0.0
	g.settings["camera_shake"] = 0.0
	g.camera.position_smoothing_enabled = false
	g._cam_look = Vector2.ZERO
	g._cam_zoom_mult = 1.0
	g.camera.position = Vector2.ZERO
	g.camera.offset = Vector2.ZERO
	# Preserve the original pose during the drain. Disabling only physics
	# does not cover deferred Area2D body_entered delivery.
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	setup_drain = {"before": {"gold": p.gold, "xp": p.xp}}
	for _pass_index in 2:
		_freeze_loot()
		await r.get_tree().physics_frame
		await r.frames(2)
	var quiet := true
	for node in g.get_children():
		if node is Chest or node is Pickup:
			quiet = quiet and node.process_mode == Node.PROCESS_MODE_DISABLED and loot_modes.has(node)
	_check("loot_modes_cover_drained_actors", quiet)
	setup_drain["after"] = {"gold": p.gold, "xp": p.xp}
	setup_drain["policy"] = "Pre-fixture queued boot callbacks drain before economy baseline and hero pose; no resource restoration."
	saved["gold"] = p.gold
	saved["xp"] = p.xp
	if not quiet: return false
	p.global_position = g.room_center(g.cur_room)
	p.visible = false
	g.camera.reset_smoothing()
	await r._settle()
	return true


func _revealed() -> bool:
	return (g.cutscene == null and not g.hud._cinematic_mode and not g.input_overlay_up()
		and g.hud.overlay.color.a <= 0.001 and g.hud.title_label.modulate.a <= 0.01
		and g.hud.subtitle_label.modulate.a <= 0.01)


func _hide(node: Node) -> void:
	if is_instance_valid(node) and node is CanvasItem:
		if not visibility.has(node): visibility[node] = node.visible
		node.visible = false


func _freeze_loot() -> void:
	# These are Game children, not world descendants. Keep NPC/CastShadow
	# processing unchanged; a queued callback can create another pickup, so
	# the second bounded pass catches any new direct loot actor before setup.
	for node in g.get_children():
		if node is Chest or node is Pickup:
			_hide(node)
			if not loot_modes.has(node): loot_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED


func _spawn(sprite_name: String, profile: String) -> void:
	npc = g._make_npc(sprite_name, g.room_center(g.cur_room) + Vector2(0, -25),
		"E - Talk", Callable(), profile, 1.0)


func _retire() -> void:
	if saved.is_empty(): return
	g.interactables.clear()
	if is_instance_valid(npc): npc.queue_free()
	npc = null
	await r.frames(2)


func _capture(label: String, zoom: float) -> void:
	g.camera.zoom = Vector2.ONE * zoom
	await r._settle()
	await RenderingServer.frame_post_draw
	_check(label + "/one_factory_entry", g.interactables.size() == 1 and is_instance_valid(npc))
	if g.interactables.size() != 1 or not is_instance_valid(npc): return
	var entry: Dictionary = g.interactables[0]
	var body: Sprite2D = entry.get("sprite")
	var casts: Array[Sprite2D] = []
	var contacts: Array[Sprite2D] = []
	for child in npc.get_children():
		if child is Sprite2D and child.has_meta("cast_shadow"): casts.append(child)
		if child is Sprite2D and child.has_meta("prop_contact_shadow"): contacts.append(child)
	_check(label + "/factory_parts", body != null and casts.size() == 1 and contacts.size() == 1)
	if body == null or casts.size() != 1 or contacts.size() != 1: return
	var cast: Sprite2D = casts[0]
	var contact: Sprite2D = contacts[0]
	_check(label + "/drawn_parts", body.is_visible_in_tree() and cast.is_visible_in_tree() and contact.is_visible_in_tree())
	_check(label + "/copy_contract", cast.texture == body.texture and cast.frame == body.frame
		and cast.hframes == body.hframes and cast.vframes == body.vframes and cast.offset == body.offset
		and cast.centered == body.centered and cast.flip_h == body.flip_h and cast.flip_v == body.flip_v
		and cast.z_index < body.z_index and cast.scale.y < 0.0)
	# Flat factory rest poses only; no approximate flipped coordinate conversion.
	_check(label + "/unflipped_rest_pose", not body.flip_h and not body.flip_v)
	var img: Image = body.texture.get_image()
	if img != null and img.is_compressed(): img.decompress()
	_check(label + "/readable_image", img != null and not img.is_empty())
	if img == null or img.is_empty(): return
	var cw: int = img.get_width() / maxi(1, body.hframes)
	var ch: int = img.get_height() / maxi(1, body.vframes)
	var cy: int = body.frame / maxi(1, body.hframes)
	var cell := img.get_region(Rect2i((body.frame % body.hframes) * cw, cy * ch, cw, ch))
	var last := -1
	var left := -1
	var right := -1
	for y in ch:
		var row_left := cw
		var row_right := -1
		for x in cw:
			if cell.get_pixel(x, y).a > 0.15:
				row_left = mini(row_left, x)
				row_right = maxi(row_right, x)
		if row_right >= 0:
			last = y
			left = row_left
			right = row_right
	_check(label + "/painted_row", last >= 0)
	if last < 0: return
	# Pixel CENTERS in current cell; lowest painted row is not anatomical feet.
	var foot := body.get_rect().position + Vector2((left + right) * 0.5 + 0.5, last + 0.5)
	var first_used: Rect2i = img.get_region(Rect2i(0, 0, cw, ch)).get_used_rect()
	var world_foot: Vector2 = body.global_transform * foot
	var world_cast_foot: Vector2 = cast.global_transform * foot
	var screen_foot: Vector2 = body.get_global_transform_with_canvas() * foot
	var screen_cast_foot: Vector2 = cast.get_global_transform_with_canvas() * foot
	_check(label + "/finite_foot", world_foot.is_finite() and world_cast_foot.is_finite() and screen_foot.is_finite())
	var bounds: Rect2 = body.get_global_transform_with_canvas() * body.get_rect()
	_check(label + "/body_in_view", g.get_viewport_rect().encloses(bounds))
	var gap := world_cast_foot - world_foot
	if r.flag("npc-grounding-strict"):
		# Sine breath: maximum speed = 1 px * PI / (2 * 0.62 s).
		# A <=0.12 s sample permits <=0.305 px phase lag; 0.35 includes rounding.
		_check(label + "/bounded_breath_sample", g.get_process_delta_time() > 0.0
			and g.get_process_delta_time() <= 0.12 and Balance.NPC_BREATH_PX == 1.0)
		_check(label + "/painted_anchor_active", bool(cast.get_meta("npc_painted_contact", false)))
		_check(label + "/grounded_projection", absf(gap.x) <= 0.35 and absf(gap.y) <= 0.35)
	var path: String = r.shot(label, "posed NPC contact diagnostic; no ground-contact verdict")
	_check(label + "/original_written", FileAccess.file_exists(path))
	samples.append({"label": label, "npc_id": npc.get_instance_id(), "sprite_name": entry.sprite_name,
		"profile": npc.get_meta("quest_convo"), "source": _sprite(body), "cast": _sprite(cast),
		"process_delta_seconds": g.get_process_delta_time(),
		"contact": _sprite(contact), "zoom": _v(g.camera.zoom), "frame_id": Engine.get_process_frames(),
		"first_cell_any_alpha_end_y": first_used.end.y, "current_cell_painted_row": last,
		"painted_row_x_range": [left, right], "painted_foot_local": _v(foot),
		"source_world_foot": _v(world_foot), "cast_world_foot": _v(world_cast_foot),
		"source_screen_foot": _v(screen_foot), "cast_screen_foot": _v(screen_cast_foot),
		"contact_world_center": _v(contact.global_position),
		"contact_screen_center": _v(contact.get_global_transform_with_canvas().origin),
		"contact_center_minus_source_world_foot": _v(contact.global_position - world_foot),
		"world_gap_cast_minus_source": _v(world_cast_foot - world_foot),
		"screen_gap_cast_minus_source": _v(screen_cast_foot - screen_foot), "original": path})


func _geometry_controls() -> void:
	# Known test masks, not game art or a simulated conversation. Expected local
	# points below come from these authored rectangles, never the production scan.
	var holder := Node2D.new()
	g.world.add_child(holder)
	var body := Sprite2D.new()
	var mask := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	mask.fill_rect(Rect2i(3, 2, 8, 9), Color.WHITE)
	mask.fill_rect(Rect2i(21, 1, 6, 13), Color.WHITE)
	mask.set_pixel(8, 15, Color(1, 1, 1, 0.04)) # Faint legacy fringe.
	body.texture = ImageTexture.create_from_image(mask)
	body.hframes = 2
	holder.add_child(body)
	var cast: Sprite2D = g.call("cast_shadow_for", holder, body, 1.0, true) as Sprite2D
	var legacy: Sprite2D = g.cast_shadow_for(holder, body) as Sprite2D
	await _geometry_case("frame0", body, cast, Vector2(-1, 2.5))
	_check("geometry/default_not_opted_in", not bool(legacy.get_meta("npc_painted_contact", false)))
	_check("geometry/default_faint_fringe_preserved", (legacy.global_transform * Vector2(-1, 2.5)
		- body.global_transform * Vector2(-1, 2.5)).length() > 1.0)
	body.frame = 1
	await _geometry_case("frame1", body, cast, Vector2(0, 5.5))
	body.frame = 0
	await _geometry_case("frame0_revisit", body, cast, Vector2(-1, 2.5))
	body.flip_h = true
	await _geometry_case("flip_h", body, cast, Vector2(1, 2.5))
	body.flip_h = false
	body.flip_v = true
	await _geometry_case("flip_v", body, cast, Vector2(-1, 5.5))
	body.flip_v = false
	body.centered = false
	body.offset = Vector2(3, -4)
	await _geometry_case("noncentered_offset", body, cast, Vector2(10, 6.5))
	body.position = Vector2(19, -13)
	body.rotation = 0.31
	body.skew = -0.17
	body.scale = Vector2(0.7, 1.3)
	await _geometry_case("rotated_skewed_scaled", body, cast, Vector2(10, 6.5))
	var replacement := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	replacement.fill(Color.TRANSPARENT)
	replacement.fill_rect(Rect2i(2, 3, 4, 4), Color.WHITE)
	body.texture = ImageTexture.create_from_image(replacement)
	await _geometry_case("texture_replaced", body, cast, Vector2(7, 2.5))
	var holder_ref: WeakRef = weakref(holder)
	var cast_ref: WeakRef = weakref(cast)
	var legacy_ref: WeakRef = weakref(legacy)
	holder.queue_free()
	await r.frames(2)
	_check("geometry/owned_nodes_freed", holder_ref.get_ref() == null
		and cast_ref.get_ref() == null and legacy_ref.get_ref() == null)


func _geometry_case(label: String, body: Sprite2D, cast: Sprite2D, painted: Vector2) -> void:
	await r.frames(3) # Actual CastShadow processing; no direct _sync or anchor call.
	await RenderingServer.frame_post_draw
	var key := "geometry/" + label
	# Sprite2D's engine opacity lookup independently validates frame/flip/offset.
	_check(key + "/known_mask_point", body.is_pixel_opaque(painted)
		and not body.is_pixel_opaque(painted + Vector2(0, 1)))
	_check(key + "/copy_contract", cast.texture == body.texture and cast.frame == body.frame
		and cast.hframes == body.hframes and cast.vframes == body.vframes
		and cast.centered == body.centered and cast.offset == body.offset
		and cast.flip_h == body.flip_h and cast.flip_v == body.flip_v)
	var gap: Vector2 = cast.global_transform * painted - body.global_transform * painted
	_check(key + "/painted_join", bool(cast.get_meta("npc_painted_contact", false))
		and gap.is_finite() and gap.length() <= 0.002)
	_check(key + "/projected_basis", cast.transform.x.is_equal_approx(body.transform.x)
		and cast.transform.determinant() * body.transform.determinant() < 0.0)
	geometry_samples.append({"label": label, "known_painted_point": _v(painted),
		"source": _sprite(body), "cast": _sprite(cast), "world_gap": _v(gap),
		"scope": "authored two-cell mask; actual Sprite2D/CastShadow processing; no NPC interaction claim"})


func _sprite(s: Sprite2D) -> Dictionary:
	var rect := s.get_rect()
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	var world: Array = []
	var screen: Array = []
	for corner: Vector2 in corners:
		world.append(_v(s.global_transform * corner))
		screen.append(_v(s.get_global_transform_with_canvas() * corner))
	return {"position": _v(s.position), "scale": _v(s.scale), "rotation": s.rotation,
		"skew": s.skew, "offset": _v(s.offset), "centered": s.centered, "flip_h": s.flip_h,
		"flip_v": s.flip_v, "frame": s.frame, "hframes": s.hframes, "vframes": s.vframes,
		"texture_size": _v(s.texture.get_size()), "texture_rid": s.texture.get_rid().get_id(),
		"texture_path": s.texture.resource_path, "z_index": s.z_index,
		"local_transform": _t(s.transform), "world_transform": _t(s.global_transform),
		"canvas_transform": _t(s.get_global_transform_with_canvas()),
		"world_rect_corners": world, "screen_rect_corners": screen}


func _v(v: Vector2) -> Array: return [v.x, v.y]
func _t(t: Transform2D) -> Array: return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]
func _check(label: String, okay: bool) -> void: r._check("npc_contact/" + label, okay)


func _restore() -> void:
	if saved.is_empty(): return
	_check("economy_unchanged", g.player.gold == saved.gold and g.player.xp == saved.xp)
	g.interactables.assign(entries)
	for node in visibility:
		if is_instance_valid(node): node.visible = visibility[node]
	g.settings = saved.settings
	g.hud.visible = saved.hud
	g.terrain_event_t = saved.terrain_event_t
	g.npc_emote_t = saved.npc_emote_t
	g.player.global_position = saved.player_position
	g.player.visible = saved.player_visible
	g.player.velocity = saved.velocity
	g.player.set_physics_process(saved.player_physics)
	g.camera.zoom = saved.zoom
	g.camera.position = saved.position
	g.camera.offset = saved.offset
	g.camera.position_smoothing_enabled = saved.smoothing
	g._cam_look = saved.look
	g._cam_zoom_mult = saved.zoom_mult
	# Resource equality was checked above while loot remained disabled.
	# Restore pose/settings first, then each surviving actor's original mode.
	for node in loot_modes:
		if is_instance_valid(node): node.process_mode = loot_modes[node]
	var modes_restored := true
	for node in loot_modes:
		if is_instance_valid(node): modes_restored = modes_restored and node.process_mode == loot_modes[node]
	_check("loot_modes_restored", modes_restored)
	_check("owned_removed_original_entries_restored", not is_instance_valid(npc) and g.interactables == entries)


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("observations.json"), FileAccess.WRITE)
	_check("report_open", file != null)
	if file == null: return
	file.store_string(JSON.stringify({"scope": "posed no-save safe-room NPC factory geometry; original floor, frozen hidden hero; no native input, combat, interaction, or earned progression claim",
		"requires_manual_visual_review": true, "ground_contact_accepted": false,
		"strict_grounding": r.flag("npc-grounding-strict"),
		"game_base_sha256": FileAccess.get_sha256("res://scripts/game_base.gd"),
		"game_world_sha256": FileAccess.get_sha256("res://scripts/game_world.gd"),
		"balance_sha256": FileAccess.get_sha256("res://scripts/balance.gd"),
		"helper_sha256": FileAccess.get_sha256("res://scripts/tests/npc_ground_contact_live.gd"),
		"renderer": RenderingServer.get_current_rendering_method(), "setup_drain": setup_drain, "samples": samples,
		"geometry_controls": geometry_samples, "checks": r.checks, "failures": r.failures}, "\t"))
	file.close()
