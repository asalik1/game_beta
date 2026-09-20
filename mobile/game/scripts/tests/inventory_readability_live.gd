extends RefCounted
## Controlled factory loans, real GUI actions, and strict observations.
## DeepSeek proposed the scenarios; Codex replaced rejected non-executable drafts.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const Geo := preload("res://scripts/tests/hud_alignment_geometry.gd")
const MaterialProbe := preload("res://scripts/tests/material_ui_live.gd")
const POCKETS := ["gold", "equipment", "backpack", "gem_bag", "materials", "consumables", "bags", "loose_bags", "potion_rotation"]
const FILTERS := ["All", "Weapons", "Helmets", "Armor", "Gloves", "Pants", "Boots", "Charms", "Gems", "Consumables", "Materials", "Bags"]
const VIEWS := ["00_empty_slots", "01_occupied_top", "02_occupied_bottom", "03_dense_grid_bottom", "04_filters_and_actions", "05_material_cancel", "06_material_remaining", "07_material_removed"]
var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native = Native.new()
var art = MaterialProbe.new()
var rows: Array = []
var views: Array = []
var gestures: Array = []
var reach_runs: Array = []
var owned_pickups: Array = []

static func run(rig: ShotRig) -> Dictionary:
	var q := new()
	q.r = rig; q.g = rig.game; q.m = rig.game.menus; q.p = rig.game.local_player
	q.native.r = rig; q.native.g = q.g; q.native.m = q.m
	if not q._check("setup.isolated", q.g.no_saves and not q.g.net_online() and q.g.chapter_id == "capital"
			and not q.m.is_open() and not rig.get_tree().paused, "fresh solo capital, closed menus"):
		return q._report()
	# No ambient pickup callbacks can pay during the loans. A nonempty scene fails setup.
	var ambient: Array = []
	for n in q.g.get_children():
		if n is Pickup or n is Chest: ambient.append(n.get_instance_id())
	if not q._check("setup.no_ambient_rewards", ambient.is_empty(), ambient): return q._report()
	var saved: Dictionary = q._ledger()
	var drops: Array = q.g.dropped_loot.duplicate(true)
	var settings: Dictionary = q.g.settings.duplicate(true)
	var lang: String = Loc.lang
	var proc: bool = q.g.is_processing()
	var physics: bool = q.p.is_physics_processing()
	var emulate: bool = Input.emulate_mouse_from_touch
	var touch_from_mouse: bool = Input.emulate_touch_from_mouse
	var ui: Array = [q.m.inv_cat, q.m.inventory_order, q.m.inventory_notice]
	q.g.set_process(false); q.p.set_physics_process(false)
	Loc.lang = "en"; Input.emulate_mouse_from_touch = true
	# Desktop ScrollContainer panning needs host touch capability, as in equip_touch_live.
	# Raw ScreenTouch/ScreenDrag remain the asserted input; this is not a wheel fallback.
	if rig.flag("touch"): Input.emulate_touch_from_mouse = true
	q.g.settings["touch_controls"] = rig.flag("touch")
	q.g.refresh_touch_mode(); q.g._apply_touch_mode()
	q.m.inventory_order = "found"; q.m.inventory_notice = ""
	var error: String = await q._exercise()
	q._check("runtime.completed", error == "", error)
	# Inspect all produced rewards before removing only this run's witnessed nodes.
	var remaining: Array = q._pickups()
	q._check("cleanup.only_owned_pickups", remaining == q.owned_pickups, {"actual": remaining, "owned": q.owned_pickups})
	for id in q.owned_pickups:
		var node: Node = instance_from_id(int(id)) as Node
		if is_instance_valid(node): node.queue_free()
	await rig.frames(2)
	q._check("cleanup.pickups_removed", q._pickups().is_empty(), q._pickups())
	q.g.dropped_loot = drops
	for key in POCKETS: q.p.set(key, saved[key])
	q.g.mailbox = saved.mailbox; q.g.loot_rng.seed = int(saved.rng[0]); q.g.loot_rng.state = int(saved.rng[1])
	q._check("cleanup.ledger_restored", q._ledger() == saved, q._ledger())
	q.m.close()
	q.m.inv_cat = ui[0]; q.m.inventory_order = ui[1]; q.m.inventory_notice = ui[2]
	q.g.settings = settings; Loc.lang = lang; Input.emulate_mouse_from_touch = emulate
	Input.emulate_touch_from_mouse = touch_from_mouse
	q.g.refresh_touch_mode(); q.g._apply_touch_mode()
	q.g.set_process(proc); q.p.set_physics_process(physics)
	q._check("cleanup.modes", q.g.settings == settings and Loc.lang == lang
		and q.g.is_processing() == proc and q.p.is_physics_processing() == physics
		and Input.emulate_mouse_from_touch == emulate and Input.emulate_touch_from_mouse == touch_from_mouse
		and not q.m.is_open() and not rig.get_tree().paused)
	q._check("captures.exact", q.views == VIEWS, q.views)
	return q._report()

func _exercise() -> String:
	if not _check("setup.touch_capability", not g.touch_mode or DisplayServer.is_touchscreen_available(),
			{"touch_mode": g.touch_mode, "touchscreen": DisplayServer.is_touchscreen_available(),
			"touch_from_mouse": Input.emulate_touch_from_mouse, "mouse_from_touch": Input.emulate_mouse_from_touch}):
		return "Touch fixture requires host touchscreen capability"
	var rng := RandomNumberGenerator.new(); rng.seed = 20260920
	p.equipment = {}; p.backpack = []; p.gem_bag = []; p.consumables = []; p.materials = []; p.loose_bags = []
	p.bags = []; p.potion_rotation = []
	for i in Balance.MAX_BAGS: p.bags.append(Items.make_bag("S"))
	await _open("all")
	var previous_y := -INF
	for slot in Items.SLOTS:
		var label: Label = _label(m.root, String(slot).capitalize() + " — empty")
		if not _check("empty." + slot + ".present", label != null): return "missing empty equipment row"
		var card: Control = _panel(label)
		_check("empty." + slot + ".size_order", card != null and card.size.y >= (44.0 if g.touch_mode else 36.0)
			and card.global_position.y > previous_y, Geo.rect(card.get_global_rect()) if card != null else [])
		previous_y = card.global_position.y if card != null else previous_y
		if not await _reach(card): return "empty slot cannot be reached: " + slot
	await _open("all")
	await _capture(VIEWS[0])
	for i in Items.SLOTS.size():
		var slot: String = Items.SLOTS[i]
		p.equipment[slot] = Items.roll_item_of(slot, "F" if i % 2 == 0 else "S", rng, "warrior")
	await _open("all")
	await _capture(VIEWS[1])
	var primary: Color = Color.TRANSPARENT
	for slot in Items.SLOTS:
		var label: Label = _label(m.root, Items.title(p.equipment[slot]))
		if not _check("occupied." + slot + ".present", label != null): return "missing occupied row"
		var card: Control = _panel(label)
		if not _check("occupied." + slot + ".target", card != null and card.size.y >= (44.0 if g.touch_mode else 36.0)):
			return "occupied equipment row too short"
		if not await _reach(card): return "occupied slot cannot be reached: " + slot
		var color: Color = label.get_theme_color("font_color")
		if primary == Color.TRANSPARENT: primary = color
		_check("occupied." + slot + ".primary", color.is_equal_approx(primary) and _contrast(color) >= 4.5
			and label.get_theme_font_size("font_size") >= 14, {"color": str(color), "grade": p.equipment[slot].grade,
			"contrast": _contrast(color), "rect": Geo.rect(label.get_global_rect()), "text": label.text,
			"ellipsis_allowed": label.clip_text})
	await _capture(VIEWS[2])
	# Legal dense bag, with a real last cell that must become reachable by input.
	p.materials = [Items.make_material("bone", "F", 2)]
	p.gem_bag = [Items.make_gem("atk_flat", 1)]
	p.consumables = [Items.make_gift_health_potion()]
	while p.bag_used() < p.bag_capacity():
		var index: int = p.backpack.size()
		p.backpack.append(Items.roll_item_of(Items.SLOTS[index % 7], "F" if index % 2 == 0 else "S", rng, "warrior"))
	_check("setup.legal_capacity", p.bag_used() == p.bag_capacity(), {"used": p.bag_used(), "capacity": p.bag_capacity()})
	var dense: Dictionary = _ledger()
	await _open("all")
	var material: Button = _material()
	if not _check("grid.material_cell", material != null): return "material missing in dense grid"
	var grid: Node = material.get_parent()
	var last: Control = grid.get_child(grid.get_child_count() - 1) as Control
	var scroll: ScrollContainer = _scroll(last)
	if not _check("grid.requires_scroll", scroll != null and not _visible(last), Geo.rect(last.get_global_rect())):
		return "dense fixture does not require scrolling"
	if not await _reach(last): return "last grid cell unreachable"
	_check("grid.scroll_moved", scroll.scroll_vertical > 0 and _visible(last), {"offset": scroll.scroll_vertical, "last": Geo.rect(last.get_global_rect())})
	await _capture(VIEWS[3])
	await _open("all")
	var first: Dictionary = p.backpack[0]
	var second: Dictionary = p.backpack[1]
	for item in [first, second]:
		var cell: Control = art._texture_control(m.root, Art.icon_for(item), true)
		if not _check("accent." + item.grade + ".cell", cell != null): return "grade cell missing"
		var style: StyleBoxFlat = cell.get_theme_stylebox("normal") as StyleBoxFlat
		_check("accent." + item.grade + ".preserved", style != null and style.border_color.is_equal_approx(Color(Items.GRADE_COLOR[item.grade], 0.9)))
	if not await _click(native._find_button(m.root, "Materials", true), "filter.materials"): return "Materials unavailable"
	_check("filter.materials_hides_gear", art._texture_control(m.root, Art.icon_for(first), true) == null and _material() != null)
	_check("filter.materials_no_spend", _ledger() == dense)
	if not await _click(native._find_button(m.root, "All", true), "filter.all"): return "All unavailable"
	_check("filter.all_restores_gear", art._texture_control(m.root, Art.icon_for(first), true) != null)
	_check("filter.all_no_spend", _ledger() == dense)
	var filter_band := Rect2()
	for text in FILTERS:
		var button: Button = native._find_button(m.root, text, true)
		if not _check("filter." + text + ".present", button != null): return "filter missing"
		var rect: Rect2 = button.get_global_rect()
		_check("filter." + text + ".target", _visible(button) and m._shell_rect.grow(0.5).encloses(rect) and rect.size.y >= (44.0 if g.touch_mode else 28.0)
			and (not g.touch_mode or rect.size.x >= 44), Geo.rect(rect))
		filter_band = rect if not filter_band.has_area() else filter_band.merge(rect)
	for text in ["Auto-synthesize", "Order:", "Auto-equip"]:
		var button: Button = native._find_button(m.root, text)
		if not _check("action." + text + ".present", button != null): return "toolbar action missing"
		_check("action." + text + ".separate", _visible(button) and m._shell_rect.grow(0.5).encloses(button.get_global_rect()) and not filter_band.intersects(button.get_global_rect())
			and button.global_position.y >= filter_band.end.y, {"filter_band": Geo.rect(filter_band), "button": Geo.rect(button.get_global_rect())})
		_check("action." + text + ".target", button.size.y >= (44.0 if g.touch_mode else 28.0) and (not g.touch_mode or button.size.x >= 44))
	await _capture(VIEWS[4])
	if not await _click(native._find_button(m.root, "Materials", true), "cancel.filter"): return "cancel filter failed"
	if not await _click(_material(), "cancel.material"): return "material open failed"
	if not _popover(2, "cancel"): return "material popover unavailable"
	await _capture(VIEWS[5])
	var cancel_before: Dictionary = _ledger()
	var cancel_drops: Array = g.dropped_loot.duplicate(true)
	# Overlay input, inside Inventory shell but outside the actual popover.
	var outside: Vector2 = m._shell_rect.position + Vector2(5, 5)
	if not _check("cancel.outside_point", not m._popover_box.get_global_rect().has_point(outside)): return "outside point covered"
	await _tap(outside)
	_check("cancel.dismissed", m.current == "inventory" and not is_instance_valid(m.detail_popover))
	_check("cancel.no_spend", _ledger() == cancel_before and g.dropped_loot == cancel_drops and _pickups().is_empty())
	for count in [2, 1]:
		if not await _click(_material(), "drop%d.material" % count): return "Drop material unreachable"
		if not _popover(count, "drop%d" % count): return "Drop detail missing"
		var before: Dictionary = _ledger()
		var expected: Dictionary = before.duplicate(true)
		expected.materials = [Items.make_material("bone", "F", 1)] if count == 2 else []
		var used: int = p.bag_used()
		var drops_before: Array = g.dropped_loot.duplicate(true)
		var nodes_before: Array = _pickups()
		if not await _click(native._find_button(m.detail_popover, "Drop one"), "drop%d.action" % count): return "Drop action unreachable"
		var now: Array = _pickups()
		var added: Array = []
		for id in now:
			if not nodes_before.has(id): added.append(id); owned_pickups.append(id)
		var payload_ok: bool = added.size() == 1 and g.dropped_loot.size() == drops_before.size() + 1
		if payload_ok:
			var node: Pickup = instance_from_id(int(added[0])) as Pickup
			var payload: Dictionary = g.dropped_loot.back()
			payload_ok = node != null and node.loot == payload and not node.claimed and payload.get("kind") == "material" \
				and payload.get("family") == "bone" and payload.get("grade") == "F" and int(payload.get("count", 0)) == 1
			for i in drops_before.size(): payload_ok = payload_ok and g.dropped_loot[i] == drops_before[i]
		_check("drop%d.exact_ledger" % count, _ledger() == expected, {"expected": expected, "actual": _ledger()})
		_check("drop%d.capacity" % count, p.bag_used() == used - (1 if count == 1 else 0), {"before": used, "after": p.bag_used()})
		_check("drop%d.actual_pickup" % count, payload_ok, {"ids": added, "dropped_loot": g.dropped_loot})
		_check("drop%d.menu_paused" % count, m.current == "inventory" and r.get_tree().paused)
		if count == 2:
			if not await _click(_material(), "remaining.detail"): return "remaining detail unavailable"
			_popover(1, "remaining")
			await _capture(VIEWS[6])
			await _tap(m._shell_rect.position + Vector2(5, 5))
		else: await _capture(VIEWS[7])
	return ""

func _popover(count: int, prefix: String) -> bool:
	if not _check(prefix + ".open", is_instance_valid(m.detail_popover) and is_instance_valid(m._popover_box)): return false
	var title: String = "%s  x%d" % [Items.MATERIALS.bone.F, count]
	var label: Label = _label(m.detail_popover, title)
	if not _check(prefix + ".title", label != null): return false
	var shape: Dictionary = Geo.shaped(label)
	_check(prefix + ".full_text", shape.missing.is_empty() and int(shape.count) > 0
		and label.get_global_rect().grow(0.5).encloses(Geo.to_rect(shape.cells)) and _visible(label)
		and label.get_visible_line_count() == label.get_line_count(), shape)
	_check(prefix + ".primary", _contrast(label.get_theme_color("font_color")) >= 4.5,
		{"color": str(label.get_theme_color("font_color")), "contrast": _contrast(label.get_theme_color("font_color"))})
	var text: String = "Drop places one unit on the ground. The slot is freed only after the last unit leaves this stack."
	var prose: Label = null
	for node in m.detail_popover.find_children("*", "Label", true, false):
		if node.text.contains(text): prose = node
	_check(prefix + ".honest_copy", prose != null)
	if prose != null:
		var body: Dictionary = Geo.shaped(prose)
		_check(prefix + ".copy_contained", body.missing.is_empty() and int(body.count) > 0
			and _visible(prose) and prose.get_global_rect().grow(0.5).encloses(Geo.to_rect(body.cells)), body)
	_check(prefix + ".viewport", _visible(m._popover_box), Geo.rect(m._popover_box.get_global_rect()))
	return true

func _open(category: String) -> void:
	m.open_inventory("gear", category)
	await r.frames(4)

func _material() -> Button:
	return art._texture_control(m.root, Art.material_ui_icon("bone", "F"), true) as Button

func _label(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node.text == text: return node as Label
	return null

func _panel(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node != null:
		if node is PanelContainer: return node as Control
		node = node.get_parent()
	return null

func _scroll(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: return node as ScrollContainer
		node = node.get_parent()
	return null

func _visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var rect: Rect2 = control.get_global_rect()
	var clip: Rect2 = r.get_viewport().get_visible_rect()
	var node: Node = control.get_parent()
	while node != null:
		if node is Control and node.clip_contents: clip = clip.intersection(node.get_global_rect())
		node = node.get_parent()
	return rect.has_area() and clip.grow(0.5).encloses(rect)

func _reach(control: Control) -> bool:
	if not is_instance_valid(control): return false
	if _visible(control): return true
	var scroll: ScrollContainer = _scroll(control)
	if not is_instance_valid(scroll) or scroll.size.y < 48: return false
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var page: float = bar.page
	var span: float = maxf(0.0, bar.max_value - bar.min_value - page)
	if page <= 0.0 or span <= 0.0: return false
	# Godot wheel input advances page/8. Derive a full-range budget instead of
	# assuming 36 events can reach the bottom of a 450-cell factory fixture.
	# Touch gets a conservative half-drag estimate; neither path writes scroll.
	var step_size: float = minf(192.0, scroll.size.y * 0.6) * 0.5 if g.touch_mode else page / 8.0
	var budget: int = clampi(ceili(span / maxf(1.0, step_size)) * 2 + 8, 8, 512)
	var started: int = Time.get_ticks_msec()
	var stalled: int = 0
	var observation: Dictionary = {"touch": g.touch_mode, "page": page, "span": span,
		"estimated_step": step_size, "budget": budget, "attempts": 0, "elapsed_ms": 0,
		"reason": "budget_exhausted", "visible": false}
	reach_runs.append(observation)
	for attempt in budget:
		observation.elapsed_ms = Time.get_ticks_msec() - started
		if not is_instance_valid(control) or not is_instance_valid(scroll):
			observation.reason = "control_replaced"
			return false
		if _visible(control):
			observation.reason = "visible"; observation.visible = true
			return true
		if int(observation.elapsed_ms) >= 30000:
			observation.reason = "time_limit"
			return false
		var before: int = scroll.scroll_vertical
		var box: Rect2 = scroll.get_global_rect()
		var up: bool = control.global_position.y < box.position.y
		if g.touch_mode:
			var distance: float = minf(192.0, box.size.y * 0.6)
			var at: Vector2 = Vector2(box.position.x + 8, box.position.y + box.size.y * (0.2 if up else 0.8))
			var event := InputEventScreenTouch.new()
			event.index = 0; event.position = at; event.pressed = true
			Input.parse_input_event(event); Input.flush_buffered_events()
			await r.frames(1)
			for step in 8:
				var drag := InputEventScreenDrag.new()
				drag.index = 0; drag.relative = Vector2(0, distance / 8.0 * (1 if up else -1)); drag.position = at + drag.relative
				Input.parse_input_event(drag); Input.flush_buffered_events(); at = drag.position
				await r.frames(1)
			event = InputEventScreenTouch.new(); event.index = 0; event.position = at; event.pressed = false
			Input.parse_input_event(event); Input.flush_buffered_events()
			await r.frames(4)
		else: await native._wheel(MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, box.get_center())
		observation.attempts = attempt + 1
		observation.elapsed_ms = Time.get_ticks_msec() - started
		if not is_instance_valid(control) or not is_instance_valid(scroll):
			observation.reason = "control_replaced"
			return false
		var progress: int = (before - scroll.scroll_vertical) if up else (scroll.scroll_vertical - before)
		stalled = stalled + 1 if progress <= 0 else 0
		gestures.append({"touch": g.touch_mode, "before": before, "after": scroll.scroll_vertical,
			"progress": progress, "target": Geo.rect(control.get_global_rect())})
		if _visible(control):
			observation.reason = "visible"; observation.visible = true
			return true
		if stalled >= 3:
			observation.reason = "three_nonprogress_events"
			return false
	return false

func _click(button: Button, id: String) -> bool:
	if not _check(id + ".enabled", is_instance_valid(button) and not button.disabled): return false
	if not _check(id + ".reachable", await _reach(button)): return false
	await _tap(button.get_global_rect().get_center())
	return true

func _tap(at: Vector2) -> void:
	if g.touch_mode: await native._touch(at)
	else: await native._mouse(at)
	await r.frames(4)

func _capture(id: String) -> void:
	await r.frames(2)
	await RenderingServer.frame_post_draw
	r.shot(id)
	views.append(id)

func _ledger() -> Dictionary:
	var result := {}
	for key in POCKETS:
		var value: Variant = p.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	result.mailbox = g.mailbox.duplicate(true); result.rng = [g.loot_rng.seed, g.loot_rng.state]
	return result

func _pickups() -> Array:
	var ids: Array = []
	for node in g.get_children():
		if node is Pickup and not node.is_queued_for_deletion(): ids.append(node.get_instance_id())
	return ids

func _contrast(color: Color) -> float:
	var light: Color = color.srgb_to_linear()
	var dark: Color = Color(0.10, 0.09, 0.13).srgb_to_linear()
	return (light.get_luminance() + 0.05) / (dark.get_luminance() + 0.05)

func _check(id: String, ok: bool, actual: Variant = null) -> bool:
	rows.append({"id": id, "passed": ok, "actual": actual})
	return ok

func _report() -> Dictionary:
	var failures := 0
	for row in rows:
		if not bool(row.passed): failures += 1
	var result := {"checks": rows.size(), "passed": rows.size() - failures, "findings": 0, "failures": failures,
		"rows": rows, "shots": views, "gestures": gestures, "reach_runs": reach_runs, "mouse_clicks": native.mouse_clicks, "touch_taps": native.touch_taps,
		"scope": "Isolated factory loans; native GUI and scroll events; two real single-unit material discards. Host touch capability is explicitly enabled for --touch and restored; raw touch gestures, no physical device, controller, socket drag/drop, crafting, sale, save, or merchant acceptance. Equipped names may retain authored ellipsis; selected material detail full text checked. Geometry supports original-image review, never replaces it."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir + "/report.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	else: result.failures += 1; push_error("Inventory readability report could not be written")
	return result
