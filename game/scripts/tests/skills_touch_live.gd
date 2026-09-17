extends RefCounted
## Borrowed allocator pool, real input. No XP, level or earned-progression claim.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const ATTRS := ["STR", "AGI", "INT", "VIT", "PhysRes", "MagRes", "CritRes", "DEX", "PhysPen", "MagPen"]
var r: Node
var g: Game
var p: Player
var expected: Array[String] = []
var observations: Array[Dictionary] = []


static func run(rig: Node) -> String:
	var q := new()
	q.r = rig
	q.g = rig.game
	q.p = rig.game.local_player
	var saved: Dictionary = rig._stash(q.p, ["unspent_attr", "attr_points", "hp", "mp"])
	var unchanged: Dictionary = rig._stash(q.p, ["level", "xp", "skill_points", "tree_points", "talent_loadouts", "gold", "ability_theme", "themes_known", "active_talent_loadout"])
	var derived: Dictionary = rig._stash(q.p, ["max_hp", "max_mp", "atk", "speed"])
	var hud: Dictionary = rig._stash(q.g.hud, ["_dossier_detail_state"])
	var menu: Dictionary = rig._stash(q.g.menus, ["_stat_flash", "_ability_preview_slot", "_ability_preview_theme"])
	var flags: Dictionary = q.g.flags.duplicate(true)
	var emulation := [Input.emulate_mouse_from_touch, Input.emulate_touch_from_mouse]
	var findings_before: int = rig.findings.size()
	var failures_before: int = rig.failures
	var error: String = await q._exercise()
	q._check("unrelated_progression", q._same_fields(unchanged) and q.g.flags == flags)
	await rig._close_overlay()
	rig._restore(q.p, unchanged)
	rig._restore(q.p, saved)
	q.p.recalc()
	q.p.hp = float(saved.hp)
	q.p.mp = float(saved.mp)
	rig._restore(q.g.menus, menu)
	q.g.hud._dossier_detail_state = []
	q.g.hud.update_stats(q.p)
	rig._restore(q.g.hud, hud)
	Input.emulate_mouse_from_touch = bool(emulation[0])
	Input.emulate_touch_from_mouse = bool(emulation[1])
	await rig.frames(3)
	await RenderingServer.frame_post_draw
	q._check("restored_pools", q.p.unspent_attr == int(saved.unspent_attr) and q.p.attr_points == saved.attr_points)
	q._check("restored_derived", q._same_fields(derived))
	q._check("restored_caches", q.g.hud._dossier_detail_state == hud._dossier_detail_state and q.g.menus._stat_flash == menu._stat_flash)
	q._check("restored_ability_preview", q.g.menus._ability_preview_slot == menu._ability_preview_slot and q.g.menus._ability_preview_theme == menu._ability_preview_theme)
	var actual: Array[String] = []
	for i in range(findings_before, rig.findings.size()): actual.append(String(rig.findings[i].finding))
	q._check("expected_findings", actual == q.expected, {"expected": q.expected, "actual": actual})
	if not rig.views.is_empty(): rig.views[-1]["skills_touch_observations"] = q.observations
	return error if error != "" else ("Skills touch strict checks failed" if rig.failures > failures_before else "")


func _exercise() -> String:
	if not g.no_saves or g.net_online() or g.get_flag("cap_q_talent_on", false): return "Needs isolated no-save solo without allocation quest"
	if r.flag("desktop-sizes") == r.touch_run: return "Use --touch, or separate --desktop-sizes without --touch"
	if r.flag("skills-extra") and (r.baseline or not r.touch_run): return "--skills-extra is a strict touch acceptance extension"
	# Seven is an ordinary attainable pool (e.g. unspent level2–8 awards).
	# Only the allocator budget is borrowed; the fixture does not simulate L8.
	p.unspent_attr = 7
	if r.touch_run:
		Input.emulate_mouse_from_touch = true
		Input.emulate_touch_from_mouse = true
		_check("touch_capability", DisplayServer.is_touchscreen_available())
	await r._tap(g.hud.skills_btn.get_global_rect().get_center())
	if not g.menus.is_open() or g.menus.current != "skills": return "Skills shortcut input failed"
	var tabs: Array[Button] = []
	for text in ["TALENTS", "ABILITY ASSIGNMENTS", "ATTRIBUTES"]:
		var button := _tab(text)
		if button == null: return "Missing Skills tab " + text
		tabs.append(button)
		_measure("tab/" + text, button, true)
	for i in tabs.size() - 1:
		_check("tab_gap/" + str(i), not tabs[i].get_global_rect().intersects(tabs[i + 1].get_global_rect()))
	await r._tap(tabs[2].get_global_rect().get_center())
	if _allocation("STR", "+1") == null: return "Attributes tab input failed"
	for attr in ATTRS:
		for amount in ["+1", "+5"]:
			var b := _allocation(attr, amount)
			if b == null: return "Missing allocator " + attr + amount
			await _show(b) # geometry inventory only; later navigation uses drag
			_measure(attr + "/" + amount, b, false)
			var sibling := _allocation(attr, "+5" if amount == "+1" else "+1")
			_check(attr + amount + "/separate", not b.get_global_rect().intersects(sibling.get_global_rect()))
			var labels: Array[Label] = []
			for raw in b.get_parent().find_children("*", "Label", true, false): labels.append(raw as Label)
			for i in labels.size(): _copy(attr + amount + "/" + str(i), labels[i])
	var scroll := _scroll()
	scroll.scroll_vertical = 0 # explicit reset after geometry-only inventory
	await r.frames(4)
	if r.flag("skills-extra"):
		var sheet := _sheet_scroll()
		if sheet == null: return "Missing named character-sheet scroll"
		sheet.scroll_vertical = 32 # explicit geometry setup, not gesture evidence
		await r.frames(3)
		_check("right_scroll_nonzero_setup", sheet.scroll_vertical == 32, {"actual": sheet.scroll_vertical})
	await _capture("01_allocator_top")
	if not r.touch_run: return "" # unchanged desktop geometry control only
	if not await _spend("STR", "+1", 1, true): return "Top-edge +1 failed"
	if not await _spend("STR", "+5", 5, false): return "Bottom-edge +5 failed"
	await _capture("02_one_point_left")
	var before_drag := _points()
	var gestures := 0
	for attempt in 4:
		if _visible(_allocation("MagPen", "+5").get_parent() as Control): break
		await _drag()
		gestures += 1
	_check("drag_no_spend", _points() == before_drag)
	var last := _allocation("MagPen", "+5")
	_check("last_row_reached_by_drag", gestures > 0 and _visible(last) and _scroll().scroll_vertical > 0,
		{"gestures": gestures, "scroll": _scroll().scroll_vertical})
	if not _visible(last): return "Actual drag could not reach final MagPen"
	var scroll_before: int = _scroll().scroll_vertical
	await _capture("03_last_row_before_spend")
	if not await _spend("MagPen", "+5", 1, false): return "Final-row clamped +5 failed"
	var scroll_after: int = _scroll().scroll_vertical
	var retained := _visible(_allocation("MagPen", "+5")) and absi(scroll_after - scroll_before) <= 2
	var detail := {"before": scroll_before, "after": scroll_after, "row_visible": _visible(_allocation("MagPen", "+5")), "retained": retained}
	observations.append({"scroll_after_lower_spend": detail})
	if r.flag("scroll-retention"):
		if r.baseline: expected.append("skills_touch/lower_row_scroll_retained")
		r._probe("skills_touch/lower_row_scroll_retained", retained, detail)
	await _capture("04_after_lower_spend")
	# Geometry-only reposition to access the disabled control. Not drag proof.
	var disabled := _allocation("MagPen", "+5")
	await _show(disabled)
	_check("all_spent_disabled", disabled.disabled and p.unspent_attr == 0)
	var exhausted := _points()
	await r._tap(disabled.get_global_rect().get_center())
	_check("disabled_no_repeat", _points() == exhausted)
	if r.flag("skills-extra"): return await _extra_views_and_lifecycle()
	return ""


func _measure(id: String, button: Button, tab: bool) -> void:
	var rect := button.get_global_rect()
	var details := {"text": button.text, "rect": r._rect(rect)}
	if r.touch_run:
		if r.baseline: expected.append("skills_touch/" + id + "/target44")
		r._probe("skills_touch/" + id + "/target44", rect.size.x >= 44 and rect.size.y >= 44, details)
	else:
		_check(id + "/desktop_compact", is_equal_approx(rect.size.y, 27.0) and (tab or is_equal_approx(rect.size.x, 42.0 if button.text.strip_edges() == "+1" else 43.0)), details)
	_check(id + "/contained", _visible(button) and g.menus._shell_rect.encloses(rect), details)
	var room := button.size - button.get_theme_stylebox("normal").get_minimum_size()
	var ink := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
	_check(id + "/caption", ink.x <= room.x + 1 and ink.y <= room.y + 1, details)


func _copy(id: String, label: Label) -> void:
	var shape: Dictionary = Geometry.shaped(label)
	var cell: Array = shape.cells
	var ink := Rect2(cell[0], cell[1], cell[2], cell[3])
	_check(id + "/full_copy", int(shape.count) > 0 and shape.missing.is_empty() and not label.clip_text
		and label.visible_ratio == 1 and label.max_lines_visible == -1 and label.get_global_rect().grow(0.5).encloses(ink)
		and label.size.y + 0.5 >= label.get_minimum_size().y and _visible(label), shape)


func _spend(attr: String, amount: String, count: int, top: bool) -> bool:
	var b := _allocation(attr, amount)
	if b == null or not _visible(b) or b.disabled: return false
	var before := _points()
	var sheet_before: int = _sheet_scroll().scroll_vertical if r.flag("skills-extra") else 0
	var point := b.get_global_rect().get_center()
	point.y = b.get_global_rect().position.y + 2 if top else b.get_global_rect().end.y - 2
	await r._tap(point)
	var allocation: Dictionary = before.allocations.duplicate(true)
	allocation[attr] = int(allocation[attr]) + count
	var exact := p.unspent_attr == int(before.pool) - count and p.attr_points == allocation
	_check(attr + amount + "/edge_spend_exact", exact, {"point": str(point), "before": before, "after": _points()})
	if r.flag("skills-extra"):
		var sheet := _sheet_scroll()
		var bar := sheet.get_v_scroll_bar()
		var wanted := clampi(sheet_before, 0, maxi(0, int(bar.max_value - bar.page)))
		_check(attr + amount + "/right_scroll_retained", sheet_before > 0 and absi(sheet.scroll_vertical - wanted) <= 1,
			{"before": sheet_before, "after": sheet.scroll_vertical, "clamped_expected": wanted})
	return exact


func _drag() -> void:
	# Same native gesture sequence as settings_touch_live._drag_body; this
	# focused variant keeps current offset so bounded repeated drags progress.
	var before: int = _scroll().scroll_vertical
	var rect := _scroll().get_global_rect()
	var at := Vector2(rect.position.x + 8, rect.position.y + rect.size.y * 0.8)
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(1)
	for i in 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = at - Vector2(0, 24); drag.relative = Vector2(0, -24)
		Input.parse_input_event(drag); Input.flush_buffered_events()
		at = drag.position
		await r.frames(1)
	event = InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(4)
	observations.append({"gesture": "ScreenTouch/8 ScreenDrag/release", "scroll_before": before,
		"scroll_after": _scroll().scroll_vertical, "touch_available": DisplayServer.is_touchscreen_available()})


func _allocation(attr: String, amount: String) -> Button:
	for raw in g.menus.root.find_children("*", "Button", true, false):
		if raw.text.strip_edges() != amount: continue
		for label in raw.get_parent().find_children("*", "Label", true, false):
			if label.text == attr or label.text == attr + "  ★": return raw as Button
	return null


func _tab(text: String) -> Button:
	for raw in g.menus.root.find_children("*", "Button", true, false):
		if raw.text.contains(text): return raw as Button
	return null


func _scroll() -> ScrollContainer:
	var node: Node = _allocation("STR", "+1")
	while node != null:
		if node is ScrollContainer: return node as ScrollContainer
		node = node.get_parent()
	return null


func _visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var rect := control.get_global_rect()
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer and not parent.get_global_rect().grow(0.5).encloses(rect): return false
		parent = parent.get_parent()
	return g.get_viewport_rect().encloses(rect)


func _show(control: Control) -> void:
	_scroll().ensure_control_visible(control.get_parent() as Control)
	await r.frames(3)


func _same_fields(fields: Dictionary) -> bool:
	for key in fields:
		if p.get(key) != fields[key]: return false
	return true


func _points() -> Dictionary:
	return {"pool": p.unspent_attr, "allocations": p.attr_points.duplicate(true)}


func _check(id: String, passed: bool, details := {}) -> void:
	r._check("skills_touch/" + id, passed, details)


func _capture(id: String) -> void:
	await r._capture(id, "Borrowed seven-point allocator pool; real edge taps and native drag; no XP/level award or earned progression", false)
	r.views[-1]["skills_touch"] = {"points": _points(), "scroll": _scroll().scroll_vertical}
	if r.flag("skills-extra"): r.views[-1]["skills_touch"]["right_scroll"] = _sheet_scroll().scroll_vertical


# The additional cases run only with --skills-extra, after all real spends.
func _sheet_scroll() -> ScrollContainer:
	return g.menus.root.find_child("AttributeSheetScroll", true, false) as ScrollContainer


func _extra_views_and_lifecycle() -> String:
	var points := _points()
	var old_offsets := [_scroll().scroll_vertical, _sheet_scroll().scroll_vertical]
	_check("reopen_nonzero_prerequisite", int(old_offsets[0]) > 0 and int(old_offsets[1]) > 0, {"offsets": old_offsets})
	var close_button := _tab("✕")
	if close_button == null: return "Missing ordinary Skills close control"
	await r._tap(close_button.get_global_rect().get_center())
	_check("ordinary_close", not g.menus.is_open())
	await r._tap(g.hud.skills_btn.get_global_rect().get_center())
	var attr_tab := _tab("ATTRIBUTES")
	if attr_tab == null: return "Ordinary reopen failed"
	await r._tap(attr_tab.get_global_rect().get_center())
	_check("ordinary_reopen_offsets_reset", _scroll().scroll_vertical == 0 and _sheet_scroll().scroll_vertical == 0)
	await _capture("05_ordinary_reopen_reset")
	# Controlled lifecycle interleaving: directly rebuild, then replace its shell
	# before the pending process_frame restoration. This is not an input claim.
	_scroll().scroll_vertical = 64
	_sheet_scroll().scroll_vertical = 32
	await r.frames(3)
	_check("replacement_nonzero_prerequisite", _scroll().scroll_vertical > 0 and _sheet_scroll().scroll_vertical == 32)
	g.menus._refresh_attributes()
	var retired_shell: Control = g.menus.root
	g.menus.open_skills("attributes")
	var newer_shell: Control = g.menus.root
	_check("replacement_distinct_shells", retired_shell != newer_shell)
	await r.frames(4)
	await RenderingServer.frame_post_draw
	_check("replacement_untouched", g.menus.root == newer_shell and _scroll().scroll_vertical == 0 and _sheet_scroll().scroll_vertical == 0,
		{"mode": "controlled direct rebuild before pending restoration; no simulated tap", "left": _scroll().scroll_vertical, "right": _sheet_scroll().scroll_vertical})
	for spec in [["TALENTS", "06_talents"], ["ABILITY ASSIGNMENTS", "07_ability_assignments"]]:
		var tab := _tab(String(spec[0]))
		if tab == null: return "Missing real tab " + String(spec[0])
		await r._tap(tab.get_global_rect().get_center())
		_tab_geometry(String(spec[0]))
		# The attribute-only _capture dereferences its allocator; never use here.
		await r._capture(String(spec[1]), "Real Skills tab input; fresh borrowed allocation fixture; layout inspection only, not all controls 44px", false)
	_check("extra_views_no_spend_or_assignment", _points() == points)
	return ""


func _tab_geometry(id: String) -> void:
	var footer: Label = null
	var inspected := 0
	var correct_content := false
	for raw in g.menus.root.find_children("*", "Control", true, false):
		if not (raw is Button or raw is Label) or not raw.is_visible_in_tree(): continue
		var control := raw as Control
		var parent := control.get_parent()
		var scroll_child := false
		while parent != null:
			if parent is ScrollContainer: scroll_child = true
			parent = parent.get_parent()
		if scroll_child: continue # offscreen talent rows are legitimate scroll content
		inspected += 1
		_check(id + "/view/" + str(inspected), _visible(control) and g.menus._shell_rect.grow(0.5).encloses(control.get_global_rect()),
			{"text": control.get("text"), "rect": r._rect(control.get_global_rect())})
		if raw is Label and raw.text.begins_with("Tap ✕"):
			footer = raw as Label
			_copy(id + "/footer", footer)
		if raw is Label and raw.text == ("TALENT LOADOUTS" if id == "TALENTS" else "HOTBAR ABILITY"):
			correct_content = true
	_check(id + "/real_tab_content", correct_content and _allocation("STR", "+1") == null)
	_check(id + "/footer_present", footer != null and inspected > 0)
	if id == "ABILITY ASSIGNMENTS":
		var assign := _tab("ASSIGNED")
		_check(id + "/assignment_footer_clear", assign != null and footer != null and _visible(assign)
			and assign.get_global_rect().end.y <= footer.get_global_rect().position.y + 0.5)
