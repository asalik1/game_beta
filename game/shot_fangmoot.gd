extends ShotRig
## Fangmoot UI shot rig: boot the game, open the Carver's Circle, play a moot,
## and screenshot the hub / shop / animated arena. Run: shot.bat fangmoot
## Windowed + muted (shot.bat injects --audio-driver Dummy).

func _ready() -> void:
	if flag("grass-material"):
		await _grass_material()
		return
	await boot("warrior", "ch1")
	# Shoot the STANDALONE experience (§18): the self-contained host, full roster,
	# Quit button, no campaign underneath.
	game.menus.fm_standalone = true
	game.menus.fm_host = FangmootHostStandalone.new()

	step("open hub")
	game.menus.open_fangmoot()
	await frames(5)
	shot("1_hub")

	step("start moot")
	UIFangmoot._start(game.menus, "silver")
	await frames(5)
	shot("2_shop_empty")

	step("buy tokens")
	var mo: FangmootMoot = game.menus.fm_moot
	_buy_some(mo)
	UIFangmoot.open(game.menus)
	await frames(5)
	shot("3_shop_filled")

	step("call moot")
	UIFangmoot._call(game.menus)
	await frames(6)
	shot("4_arena_start")
	await sim_wait(1.4)
	shot("5_arena_mid")
	await sim_wait(7.0)
	shot("6_arena_end")

	finish()


func _buy_some(mo: FangmootMoot) -> void:
	# exercise the real click-to-buy path (rebuilds the UI each time)
	var guard := 20
	while guard > 0 and mo.board_count() < 2:
		guard -= 1
		var idx := -1
		for i in mo.tray.size():
			var ct := String(mo.tray[i]["ctype"])
			if (ct == "token" or ct == "named") and mo.can_buy(i) and _empty(mo):
				idx = i
				break
		if idx < 0:
			break
		UIFangmoot._quick_buy(game.menus, idx)


func _empty(mo: FangmootMoot) -> bool:
	for s in mo.board.size():
		if mo.board[s] == null:
			return true
	return false


# Installed grass consumer only: normal seeded Copper rules, real shop/arena
# construction, existing non-persisting host. No replay or input claim.
const GRASS_SEED := 903134
var grass_checks: Array[Dictionary] = []
var grass_failures := 0
var grass_receipt: Dictionary = {}
var grass_saved: Dictionary = {}

func _grass_material() -> void:
	var user_path: String = ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _grass_check("isolated_profile", user_path.to_lower().contains("/build/qa/"), user_path):
		finish(1)
		return
	get_window().size = Vector2i(1280, 720)
	await boot("warrior", "ch1", false)
	var reason: String = await _grass_run()
	_grass_cleanup()
	await frames(2)
	if reason != "":
		_grass_check("fixture_complete", false, reason)
	_grass_write_report()
	print("GRASS CONSUMER: %d checks, %d failures, %d fullframes (+ native crop); seeded Copper preview, no replay/input claim" % [grass_checks.size(), grass_failures, shots_taken])
	finish(1 if grass_failures > 0 else 0)

func _grass_run() -> String:
	if not _grass_check("isolated_muted_offline", game.no_saves and not game.net_online() and AudioServer.is_bus_mute(0)):
		return "Unexpected boot state"
	if not _grass_check("native_viewport", get_viewport().get_visible_rect().size == Vector2(1280, 720)):
		return "Unexpected viewport"
	if not _grass_check("closed_boot_menu", not game.menus.is_open()):
		return "An unrelated menu is already open"
	var deadline: int = Time.get_ticks_msec() + 15000
	var stable: int = 0
	while Time.get_ticks_msec() < deadline and stable < 3:
		await frames(1)
		if Time.get_ticks_msec() >= deadline:
			break
		var h: Hud = game.hud
		var pending: bool = game.cutscene != null or h._cinematic_mode or h.dialogue_active or h.choices_active
		pending = pending or (is_instance_valid(h._ann_active) and h._ann_active.visible)
		pending = pending or h.overlay.color.a > 0.001 or h.title_label.modulate.a > 0.01 or h.subtitle_label.modulate.a > 0.01
		for child in h.get_children():
			pending = pending or child is Cutscene
		stable = 0 if pending else stable + 1
	if not _grass_check("actual_world_reveal_settled", stable >= 3):
		return "Boot presentation did not settle"
	var m: Menus = game.menus
	for key in ["fm_moot", "fm_host", "fm_standalone", "fm_opp", "fm_opp_turn", "fm_speed", "_closable_now", "current"]:
		grass_saved[key] = m.get(key) # preserve original reference, lend fresh state
	grass_saved["paused"] = get_tree().paused
	grass_saved["hud_visible"] = game.hud.visible
	grass_saved["talk_cd"] = game.talk_cd
	# Same full-roster/art host behavior as standalone; the existing base host
	# suppresses storage/rewards. No user-file read or write is required.
	m.fm_host = FangmootHost.new()
	m.fm_standalone = true
	m.fm_moot = FangmootMoot.new("copper", GRASS_SEED, m.fm_host)
	m.fm_opp = []
	m.fm_opp_turn = -1
	m.fm_moot.begin_turn()
	UIFangmoot.open(m)
	_buy_some(m.fm_moot) # unchanged production quick-buy callback path
	await frames(5)
	var mo: FangmootMoot = m.fm_moot
	if not _grass_check("normal_copper_grass_selection", mo.table == "copper" and mo.seed == GRASS_SEED and mo.ground == "village"
		and String(Terrains.get_terrain(mo.ground).get("ground", "")) == "grass"):
		return "Normal Copper rules did not select grass"
	if not _grass_check("populated_preview", mo.board_count() > 0 and not m.fm_opp.is_empty() and mo.turn == 1 and mo.last_log.is_empty()):
		return "Normal seeded purchases did not produce a preview"
	var arenas: Array = []
	_grass_find_arenas(m.root, arenas)
	if not _grass_check("one_live_arena", arenas.size() == 1):
		return "Unexpected arena ownership"
	var arena: UIFangmootArena = arenas[0]
	var floor: Polygon2D = null
	var ambient: CanvasModulate = null
	for child in arena.get_children():
		if child is Polygon2D and child.z_index == -20:
			floor = child
		if child is CanvasModulate:
			ambient = child
	if not _grass_check("actual_grass_field", floor != null and floor.texture != null and floor.texture == Art.ground_field("grass") and ambient != null):
		return "Missing real floor/ambient"
	var vp: SubViewport = arena.get_viewport() as SubViewport
	if not _grass_check("native_ui_subviewport", vp != null and vp.size == Vector2i(1280, int(UIFangmoot.ARENA_H)) and arena._ground == "village"):
		return "Unexpected arena viewport"
	_grass_check("native_uv_nearest_repeat", floor.uv == floor.polygon and floor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and floor.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED and floor.texture_scale == Vector2.ONE and floor.texture_offset == Vector2.ZERO)
	var target: Color = (Terrains.get_terrain("village")["tint"] as Color).lightened(0.10)
	_grass_check("actual_arena_tint", ambient.color.is_equal_approx(target) and floor.self_modulate.is_equal_approx(Color(0.66, 0.66, 0.72)))
	var tex: Texture2D = floor.texture
	var source: String = tex.resource_path
	var img: Image = tex.get_image()
	if not _grass_check("installed_texture_source", source.ends_with("ground_field_grass_painterly.png") and FileAccess.file_exists(source)
		and img != null and not img.is_empty()):
		return "Missing installed grass image/source"
	var sha: String = FileAccess.get_sha256(source)
	var expected: String = arg("expected-grass-sha256", "").to_lower()
	_grass_check("source_hash", sha.length() == 64 and (expected == "" or expected == sha), {"actual": sha, "expected_if_supplied": expected})
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(img.get_data())
	var tokens: Array = []
	var sides: Array[int] = [0, 0]
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size))
	for rec in arena._toks:
		var spr: Sprite2D = rec["spr"]
		var bite: Label = rec["bite_chip"]
		var hide: Label = rec["hide_chip"]
		var kind: String = String(rec["kind"])
		var side: int = int(rec["side"])
		sides[side] += 1
		_grass_check("token_" + kind, spr.texture != null and spr.is_visible_in_tree() and spr.scale.x > 0.0 and spr.scale.y > 0.0)
		for chip: Label in [bite, hide]:
			_grass_check("chip_" + kind + "_" + chip.text, chip.is_visible_in_tree() and not chip.text.is_empty()
				and chip.size.x >= chip.get_minimum_size().x and chip.size.y >= chip.get_minimum_size().y
				and bounds.encloses(chip.get_global_rect()))
		tokens.append({"kind": kind, "side": side, "sprite_resource": spr.texture.resource_path if spr.texture != null else "",
			"sprite_scale": _grass_xy(spr.scale), "bite": bite.text, "hide": hide.text,
			"bite_rect": _grass_rect(bite.get_global_rect()), "hide_rect": _grass_rect(hide.get_global_rect())})
	_grass_check("both_bands_visible", sides[0] > 0 and sides[1] > 0)
	grass_receipt = {"fixture": "Seeded normal Copper shop/opponent preview; real ordinary UI construction and quick-buy callbacks, existing non-persisting host. No replay, pointer/controller, combat or physical-device claim.",
		"seed": GRASS_SEED, "table": mo.table, "ground": mo.ground, "moot_setup": mo.to_dict(), "opponent": m.fm_opp.duplicate(true),
		"source_resource": source, "source_file_sha256": sha,
		"texture_instance_id": tex.get_instance_id(), "texture_type": tex.get_class(), "texture_size": _grass_xy(tex.get_size()),
		"image_size": _grass_xy(img.get_size()), "image_format": img.get_format(), "image_mipmaps": img.has_mipmaps(),
		"image_data_sha256": hash_context.finish().hex_encode(), "image_hash_scope": "Returned decoded image data, including mip levels",
		"uv": _grass_points(floor.uv), "polygon": _grass_points(floor.polygon), "texture_filter": floor.texture_filter,
		"texture_repeat": floor.texture_repeat, "texture_scale": _grass_xy(floor.texture_scale), "texture_offset": _grass_xy(floor.texture_offset),
		"native_uv_period_pixels": _grass_xy(tex.get_size()), "world_configured_period_unused_here": Balance.GROUND_FIELD_PERIOD.get("grass", 512),
		"floor_self_modulate": _grass_rgba(floor.self_modulate), "floor_modulate": _grass_rgba(floor.modulate),
		"ambient_actual": _grass_rgba(ambient.color), "ambient_target": _grass_rgba(target),
		"viewport_size": _grass_xy(vp.size), "subviewport_hdr_2d": vp.use_hdr_2d, "tokens": tokens}
	if grass_failures > 0:
		return "Grass source/geometry contract failed"
	await RenderingServer.frame_post_draw
	var path: String = shot("grass_copper_preview", "SETUP: seeded Copper preview; real UI and no-save host; no replay/input claim")
	var captured: Image = Image.load_from_file(path)
	if not _grass_check("native_capture", captured != null and captured.get_size() == Vector2i(1280, 720)):
		return "Missing fullframe"
	var crop_path: String = "%s/grass_copper_arena_native.png" % shot_dir
	var crop: Image = captured.get_region(Rect2i(0, int(UIFangmoot.TOPBAR_H), 1280, int(UIFangmoot.ARENA_H)))
	if not _grass_check("native_crop_saved", crop.save_png(crop_path) == OK):
		return "Crop save failed"
	grass_receipt["fullframe"] = path
	grass_receipt["arena_crop"] = ProjectSettings.globalize_path(crop_path)
	grass_receipt["crop_note"] = "Unresized native rectangle from the saved fullframe; not a second gameplay moment"
	print("NATIVE CROP: ", ProjectSettings.globalize_path(crop_path))
	return ""

func _grass_cleanup() -> void:
	if grass_saved.is_empty():
		return
	game.menus.close() # no replay was started, so no pending arena coroutine
	for key in ["fm_moot", "fm_host", "fm_standalone", "fm_opp", "fm_opp_turn", "fm_speed", "_closable_now", "current"]:
		game.menus.set(key, grass_saved[key])
	game.hud.visible = bool(grass_saved["hud_visible"])
	game.talk_cd = float(grass_saved["talk_cd"])
	get_tree().paused = bool(grass_saved["paused"])
	_grass_check("restored_host_and_moot", game.menus.fm_host == grass_saved["fm_host"] and game.menus.fm_moot == grass_saved["fm_moot"]
		and is_same(game.menus.fm_opp, grass_saved["fm_opp"]) and not game.menus.is_open())

func _grass_find_arenas(node: Node, found: Array) -> void:
	if node is UIFangmootArena:
		found.append(node)
	for child in node.get_children():
		_grass_find_arenas(child, found)

func _grass_check(label: String, ok: bool, detail: Variant = null) -> bool:
	grass_checks.append({"check": label, "ok": ok, "detail": detail})
	if not ok:
		grass_failures += 1
	print("%s grass: %s" % ["ok" if ok else "FAIL", label])
	return ok

func _grass_write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var f: FileAccess = FileAccess.open(shot_dir + "/grass_observations.json", FileAccess.WRITE)
	if not _grass_check("report_open", f != null):
		return
	f.store_string(JSON.stringify({"checks": grass_checks, "failures": grass_failures, "receipt": grass_receipt}, "\t"))
	f.flush()
	var err: int = f.get_error()
	f.close()
	# Successful I/O is a status, not a check appended after serialization.
	# A failed/partial report cannot record its own write failure reliably;
	# retain the failing diagnostic and nonzero exit without rewriting it.
	if err != OK:
		_grass_check("report_write", false, {"error": err})
	else:
		print("GRASS REPORT: written and flushed")

func _grass_xy(v: Vector2) -> Array:
	return [v.x, v.y]

func _grass_rgba(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]

func _grass_rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _grass_points(points: PackedVector2Array) -> Array:
	var out: Array = []
	for p in points:
		out.append(_grass_xy(p))
	return out
