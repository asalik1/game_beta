extends RefCounted
## Optional real Codex reading probe after the controlled landing matrix.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const TITLE := "Land on clear ground"
const COPY := "Shield Bash, Shadow Dash, Blink and Tumble follow your movement input. With no movement input, they go where you face. An occupied destination shortens the movement to clear ground along that approach. Shield Bash, Shadow Dash and Blink keep their intended strike reach; base Tumble has no damage strike. A clear destination still lets these abilities cross intervening scenery."

var r: Variant
var g: Game
var m: Menus
var nav: RefCounted
var data := {"scope": "real HUD Codex click, Field notes/Combat clicks, pointer wheel and Escape; frozen gameplay fixture", "rows": [], "wheel_samples": [], "complete": false}


static func run(rig: Variant) -> String:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.m = rig.game.menus
	probe.nav = NativeInput.new()
	probe.nav.r = rig
	probe.nav.g = probe.g
	probe.nav.m = probe.m
	rig._release()
	var position_before: Vector2 = probe.g.player.global_position
	probe._stage("entry; prior matrices preserved")
	var error: String = await probe._run()
	probe._stage("reading returned", {"error": error})
	# The normal escape path is also used after a missing copy/layout finding.
	if probe.m.is_open():
		probe._stage("before ordinary Escape cleanup")
		await probe.nav._key(KEY_ESCAPE)
	await rig.frames(2)
	probe._check(not probe.m.is_open() and not probe.g.get_tree().paused
		and probe.g.hud.visible and probe.g.player.global_position == position_before
		and not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"returns to unchanged frozen world with input released")
	for row in probe.nav.rows:
		probe._check(bool(row.passed), "native " + String(row.id))
	probe.data["mouse_clicks"] = probe.nav.mouse_clicks
	probe.data["wheel_taps"] = probe.nav.wheel_taps
	probe.data["key_taps"] = probe.nav.key_taps
	var checks_good := true
	for row in probe.data.rows:
		checks_good = checks_good and bool(row.passed)
	probe.data["complete"] = error == "" and checks_good
	probe._stage("cleanup complete", {"error": error})
	return error


func _run() -> String:
	r.step("optional Codex Combat field notes: actual navigation and complete dash copy")
	if not _check(g.no_saves and g.play_started and not g.net_online() and not m.is_open()
		and not g.input_overlay_up() and not g.get_tree().paused and g.hud.visible
		and not g.is_processing() and not g.player.is_physics_processing(), "isolated frozen-world reading preconditions"):
		return "field notes preconditions unavailable"
	_stage("before HUD Codex click")
	await nav._mouse(g.hud.codex_btn.get_global_rect().get_center())
	await r.frames(3)
	if not _check(m.current == "codex" and m.is_open(), "HUD click opens actual Codex"):
		return "field notes Codex did not open"
	_stage("before Field notes section click")
	if not await nav._button("Field notes"):
		return "field notes navigation control unavailable"
	_stage("before Combat chip click")
	if not await nav._button("Combat"):
		return "field notes navigation control unavailable"
	_stage("Combat chip returned")
	var heading: Label
	for node in m.root.find_children("*", "Label", true, false):
		if node is Label and node.text == TITLE:
			heading = node
			break
	if not _check(heading != null, "new dash heading exists after Combat chip"):
		return "field notes dash heading missing"
	var parent := heading.get_parent()
	var body: Label = parent.get_child(heading.get_index() + 1) as Label if heading.get_index() + 1 < parent.get_child_count() else null
	if not _check(body != null and body.text == COPY, "exact complete player-facing dash paragraph"):
		return "field notes dash paragraph differs from reviewed copy"
	var scroll: ScrollContainer
	var ancestor: Node = heading.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			scroll = ancestor
			break
		ancestor = ancestor.get_parent()
	if not _check(scroll != null, "actual paragraph has a reading ScrollContainer"):
		return "field notes reading scroll unavailable"
	# Use actual wheel input; no direct scrollbar/label positioning to create
	# the screenshot. Wheel upward if an earlier reading position was retained.
	_stage("before bounded reading wheel", {"scroll": Geometry.rect(scroll.get_global_rect()),
		"content": Geometry.rect(heading.get_global_rect().merge(body.get_global_rect()))})
	for tick in 60:
		var content_rect := heading.get_global_rect().merge(body.get_global_rect())
		var clip_rect := scroll.get_global_rect()
		# The page has fill-width Labels flush with scroll.left. Wheel controls Y;
		# an inset two-axis Label enclosure can never succeed on that real layout.
		if content_rect.position.y >= clip_rect.position.y + 2.0 and content_rect.end.y <= clip_rect.end.y - 2.0:
			break
		var button := MOUSE_BUTTON_WHEEL_UP if content_rect.position.y < clip_rect.position.y + 2.0 else MOUSE_BUTTON_WHEEL_DOWN
		var sample := {"index": tick, "button": button, "before_offset": scroll.scroll_vertical,
			"before_content": Geometry.rect(content_rect), "clip": Geometry.rect(clip_rect)}
		data.wheel_samples.append(sample)
		_stage("before wheel %d" % tick)
		await nav._wheel(button, clip_rect.get_center())
		sample["after_offset"] = scroll.scroll_vertical
		sample["after_content"] = Geometry.rect(heading.get_global_rect().merge(body.get_global_rect()))
		_stage("after wheel %d" % tick)
	_stage("reading wheel complete; before geometry")
	# Match the established menu_navigation_live capture seam: bounded process
	# frames then viewport readback, not an unbounded redraw-only signal wait.
	await r.frames(3)
	data["scroll"] = Geometry.rect(scroll.get_global_rect())
	data["scroll_vertical"] = scroll.scroll_vertical
	var readable := true
	for label in [heading, body]:
		var shaped: Dictionary = Geometry.shaped(label)
		var cells: Rect2 = Geometry.to_rect(shaped.cells)
		var complete: bool = shaped.missing.is_empty() and int(shaped.count) > 0
		complete = complete and label.is_visible_in_tree() and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
		complete = complete and label.get_global_rect().grow(1.0).encloses(cells)
		complete = complete and scroll.get_global_rect().grow(Geometry.EPSILON).encloses(cells)
		complete = complete and r.get_viewport().get_visible_rect().encloses(cells)
		complete = complete and int(shaped.lines) >= 1 and int(shaped.lines) <= 10
		readable = _check(complete, "shaped caption readable: " + ("heading" if label == heading else "paragraph")) and readable
		data["heading" if label == heading else "paragraph"] = shaped
	_stage("geometry complete; before capture", {"readable": readable})
	if not r.flag("no-capture"):
		await r.frames(3)
		r.shot("field_notes_combat_dash", "actual Codex Combat reading via HUD, chips and wheel; reviewed dash paragraph; see strict geometry result")
	_stage("capture returned", {"readable": readable})
	return "" if readable else "field notes paragraph is clipped or unreadable"


func _check(ok: bool, label: String) -> bool:
	r._check(ok, "field notes " + label)
	data.rows.append({"check": label, "passed": ok})
	return ok


func _stage(label: String, detail: Dictionary = {}) -> void:
	data["phase"] = label
	data["diagnostics"] = {"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(), "frames_drawn": Engine.get_frames_drawn(),
		"paused": g.get_tree().paused, "low_processor_usage": OS.low_processor_usage_mode,
		"window_mode": DisplayServer.window_get_mode(), "render_loop_enabled": RenderingServer.is_render_loop_enabled(), "menu": m.current,
		"mouse_clicks": nav.mouse_clicks, "wheel_taps": nav.wheel_taps, "key_taps": nav.key_taps,
		"detail": detail}
	r.step("field notes: " + label)
	r.report["field_notes"] = data
	# Diagnostic checkpoint only. The parent must still write friction.json and
	# complete all cleanup to accept the run; timeout never becomes a pass.
	var partial: Dictionary = r.report.duplicate(true)
	partial["complete"] = false
	partial["partial"] = true
	partial["shots"] = r.shots_taken
	var path: String = ProjectSettings.globalize_path(r.shot_dir.path_join("friction-partial.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		r._check(false, "field notes diagnostic checkpoint can be written")
		return
	file.store_string(JSON.stringify(partial, "\t"))
	file.close()
