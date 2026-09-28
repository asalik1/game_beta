extends RefCounted
## Shared quick-suite/native HUD geometry checks. These are shaped text cells,
## not raster glyph ink: native screenshots still require visual review.
## Nothing here asserts the production layout's chosen X/Y coordinates.
const STAT_FIELDS := ["gold_label", "cr_label", "res_label"]
const CastReadout := preload("res://scripts/ui/boss_cast.gd")
const CASES := [
	{"id": "01_reported", "gold": "◉ 57 gold", "cr": "CR 305", "res": "+12",
		"zone": "THE MISTED FIELDS", "quest": "Report to Cantor Ilse at the Vigil Gate (walk up to her and press E)   —   11 monsters left"},
	{"id": "02_long_values", "gold": "◉ 987654321 gold", "cr": "CR 9876543", "res": "-100",
		"zone": "THE MISTED FIELDS", "quest": "Report to Cantor Ilse at the Vigil Gate (walk up to her and press E), then return to the road beyond the old watchtower   —   999 monsters left", "target": "boss"},
	{"id": "03_positive", "gold": "◉ 0 gold", "cr": "CR 1", "res": "+100",
		"zone": "THE MISTED FIELDS", "quest": "1 monster left", "target": "rival"},
	{"id": "04_empty_quest", "gold": "◉ 57 gold", "cr": "CR 305", "res": "0",
		"zone": "THE MISTED FIELDS", "quest": ""},
]
const EPSILON := 0.5
const CLEARANCE := 4.0


static func inspect(h: Hud, resolved_panels: Dictionary = {}) -> Dictionary:
	var result := {"checks": [], "labels": {}, "rects": {}}
	var baselines: Array[float] = []
	var previous := Rect2()
	for field: String in STAT_FIELDS:
		var label: Label = h.get(field)
		var shape := shaped(label)
		result.labels[field] = shape
		var bounds := to_rect(shape.cells)
		add(result, "stat_full_text/" + field, shape.missing.is_empty() and shape.count > 0
			and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
			and label.get_global_rect().grow(EPSILON).encloses(bounds), shape)
		add(result, "stat_in_panel/" + field, h.info_panel.get_global_rect().grow(EPSILON).encloses(bounds), shape)
		if shape.digit_index >= 0 and bool(shape.numeric_metrics.get("added", false)) \
				and bool(shape.numeric_metrics.get("single_line", false)):
			baselines.append(float(shape.numeric_baseline))
		if previous.has_area():
			add(result, "stat_horizontal_clear/" + field, bounds.position.x - previous.end.x >= CLEARANCE,
				{"previous": rect(previous), "current": rect(bounds)})
		previous = bounds
		if field != "gold_label":
			var chip: Control = h.get("cr_chip" if field == "cr_label" else "res_chip")
			add(result, "stat_in_chip/" + field, chip.get_global_rect().grow(EPSILON).encloses(bounds),
				{"chip": rect(chip.get_global_rect()), "cells": shape.cells})
	add(result, "numeric_baselines", baselines.size() == 3
		and baselines.max() - baselines.min() <= EPSILON, {"baselines": baselines, "tolerance": EPSILON})
	var vitals: Control = resolved_panels.get("vitals")
	var tracker: Control = resolved_panels.get("tracker")
	if not is_instance_valid(vitals):
		vitals = panel(h, "vitals_panel", h.hp_text)
	if not is_instance_valid(tracker):
		tracker = panel(h, "quest_panel", h.zone_label)
	add(result, "panels_resolved", vitals != null and tracker != null and vitals != tracker)
	if vitals == null or tracker == null or vitals == tracker:
		return result
	var vital_rect := vitals.get_global_rect()
	var tracker_rect := tracker.get_global_rect()
	result.rects = {"vitals": rect(vital_rect), "tracker": rect(tracker_rect),
		"viewport": rect(h.get_viewport().get_visible_rect())}
	add(result, "tracker_vitals_clear", not tracker_rect.intersects(vital_rect.grow(CLEARANCE - EPSILON)), result.rects)
	add(result, "tracker_on_screen", h.get_viewport().get_visible_rect().encloses(tracker_rect), result.rects)
	for field: String in ["zone_label", "quest_label"]:
		var label: Label = h.get(field)
		var shape := shaped(label)
		result.labels[field] = shape
		if label.text.is_empty():
			add(result, "empty_tracker_hidden", not label.visible, shape)
			continue
		var bounds := to_rect(shape.cells)
		add(result, "tracker_full_text/" + field, shape.missing.is_empty() and shape.count > 0
			and not label.clip_text and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
			and label.get_visible_line_count() == label.get_line_count(), shape)
		add(result, "tracker_text_contained/" + field, label.get_global_rect().grow(EPSILON).encloses(bounds)
			and tracker_rect.grow(EPSILON).encloses(bounds), shape)
		add(result, "tracker_text_vitals_clear/" + field, not bounds.intersects(vital_rect.grow(CLEARANCE - EPSILON)), shape)
	if h.quest_label.visible:
		add(result, "tracker_rows_clear", not to_rect(result.labels.zone_label.cells).intersects(
			to_rect(result.labels.quest_label.cells).grow(1.0)), result.labels)
	for field: String in ["mob_name", "mob_level", "mob_fill", "boss_name", "boss_level", "boss_hp_num",
			"boss_fill", "boss_badge_root", "rival_name", "rival_fill"]:
		var control: Control = h.get(field)
		if not control.is_visible_in_tree():
			continue
		var bounds := control.get_global_rect()
		if control is Label:
			var shape := shaped(control as Label)
			result.labels[field] = shape
			bounds = to_rect(shape.cells)
		result.rects[field] = rect(bounds)
		add(result, "tracker_target_clear/" + field, not tracker_rect.intersects(bounds.grow(CLEARANCE - EPSILON)),
			{"tracker": rect(tracker_rect), "target": rect(bounds)})
		add(result, "target_vitals_clear/" + field, not vital_rect.intersects(bounds.grow(CLEARANCE - EPSILON)),
			{"vitals": rect(vital_rect), "target": rect(bounds)})
		add(result, "target_dossier_clear/" + field, not h.info_panel.get_global_rect().intersects(bounds.grow(CLEARANCE - EPSILON)),
			{"dossier": rect(h.info_panel.get_global_rect()), "target": rect(bounds)})
	var cast: Control = h.boss_cast_readout
	if is_instance_valid(cast) and cast.is_visible_in_tree():
		var cast_panel: Rect2 = cast.get_global_transform() * CastReadout.PANEL
		result.rects.cast_panel = rect(cast_panel)
		for obstacle in [tracker_rect, vital_rect, h.info_panel.get_global_rect()]:
			add(result, "cast_panel_clear/" + str(obstacle.position), not cast_panel.intersects(obstacle.grow(CLEARANCE - EPSILON)),
				{"cast_panel": rect(cast_panel), "obstacle": rect(obstacle)})
		for field: String in ["title", "instruction", "clock"]:
			var label: Label = cast.get(field)
			var shape := shaped(label)
			result.labels["cast_" + field] = shape
			add(result, "cast_full_text/" + field, shape.missing.is_empty() and shape.count > 0
				and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
				and cast_panel.grow(EPSILON).encloses(to_rect(shape.cells)), shape)
	return result


static func shaped(label: Label) -> Dictionary:
	var cells := Rect2()
	var missing: Array[int] = []
	var count := 0
	var digit_index := -1
	var baseline := 0.0
	var numeric_metrics := {}
	for index in label.text.length():
		var character := label.text.substr(index, 1)
		if character.strip_edges().is_empty():
			continue
		var cell := label.get_character_bounds(index)
		if not cell.has_area():
			missing.append(index)
			continue
		cells = cell if count == 0 else cells.merge(cell)
		count += 1
		if digit_index < 0 and character >= "0" and character <= "9":
			digit_index = index
			# Character bounds start at the WHOLE shaped line's top. A fallback
			# glyph such as the coin can raise its ascent above the primary font.
			# Match Label's draw baseline, including its minimum-font-height pad.
			var font := label.get_theme_font("font")
			var font_size := label.get_theme_font_size("font_size")
			var line := TextLine.new()
			line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			var added := line.add_string(label.text, font, font_size, label.language)
			var ascent := line.get_line_ascent()
			var descent := line.get_line_descent()
			var minimum_height := font.get_height(font_size)
			var padded_ascent := ascent + maxf(0.0, minimum_height - ascent - descent) * 0.5
			numeric_metrics = {"added": added, "single_line": label.get_line_count() == 1,
				"line_ascent": ascent, "line_descent": descent, "font_height": minimum_height,
				"padded_ascent": padded_ascent}
			baseline = (label.get_global_transform() * Vector2(cell.position.x,
				cell.position.y + padded_ascent)).y
	return {"text": label.text, "cells": rect(label.get_global_transform() * cells),
		"control": rect(label.get_global_rect()), "count": count, "missing": missing,
		"digit_index": digit_index, "numeric_baseline": baseline, "numeric_metrics": numeric_metrics,
		"font_size": label.get_theme_font_size("font_size"), "lines": label.get_line_count(),
		"visible_lines": label.get_visible_line_count()}


static func panel(h: Hud, property: String, anchor: Control) -> Control:
	for definition in h.get_property_list():
		if String(definition.name) == property and h.get(property) is Control:
			return h.get(property)
	# Baseline compatibility: locate the enclosing production backplate, not a
	# copied expected Rect2. The HP frame is smaller than the actual backplate.
	var found: Control = null
	for child in h.get_children():
		if child is Panel and child.get_global_rect().encloses(anchor.get_global_rect()):
			if found == null or child.size.x * child.size.y > found.size.x * found.size.y:
				found = child
	return found


static func apply_case(h: Hud, row: Dictionary) -> void:
	var gold_copy := String(row.gold)
	# The paired baseline has the coin inline; the revised HUD owns its glyph.
	# Resolve the optional field without referencing a property absent on base.
	for property in h.get_property_list():
		if String(property.name) == "gold_icon" and h.get("gold_icon") is Label:
			gold_copy = gold_copy.trim_prefix("◉ ")
			break
	h.gold_label.text = gold_copy
	h.cr_label.text = String(row.cr)
	h.res_label.text = String(row.res)
	h.res_label.scale = Vector2.ONE
	h._dossier_values = ""
	h._layout_dossier_stats()
	h.set_zone(String(row.zone))
	h.set_quest(String(row.quest))
	h.mob_name.text = "Unburied Walker — 100%"
	h.mob_level.text = "Lv 16"
	h.mob_box.visible = String(row.get("target", "mob")) == "mob"
	h.boss_box.visible = String(row.get("target", "mob")) == "boss"
	h.boss_name.text = "The Gate Warden"
	h.boss_level.text = "Lv 16"
	h.boss_hp_num.text = "191888 / 191888"
	h.rival_box.visible = String(row.get("target", "mob")) == "rival"
	h.rival_name.text = "Rival Warrior — 100%"


static func negative_controls(h: Hud) -> Dictionary:
	# Keep the actual resolved Controls while moving them. The old anonymous
	# backplate cannot be rediscovered from label enclosure after translation.
	var tracker := panel(h, "quest_panel", h.zone_label)
	var vitals := panel(h, "vitals_panel", h.hp_text)
	var resolved := {"tracker": tracker, "vitals": vitals}
	var initial := inspect(h, resolved)
	var cr_y := h.cr_label.position.y
	h.cr_label.position.y += 8.0
	var displaced := inspect(h, resolved)
	h.cr_label.position.y = cr_y
	var detected := false
	if tracker != null and vitals != null:
		var position := tracker.global_position
		tracker.global_position = vitals.global_position
		detected = failed(inspect(h, resolved), "tracker_vitals_clear")
		tracker.global_position = position
	return {"baseline_misalignment_detected": failed(displaced, "numeric_baselines"),
		"panel_overlap_detected": detected, "restored_geometry": initial == inspect(h, resolved)}


static func snapshot(h: Hud) -> Dictionary:
	var result := {"controls": [], "sprites": [], "dossier_values": h._dossier_values, "hud_visible": h.visible}
	stash_controls(h, result.controls)
	for field: String in ["res_orb_glow", "res_orb_core", "res_particles"]:
		var item: Node2D = h.get(field)
		result.sprites.append({"node": item, "position": item.position})
	# Older paired baselines have no tracker node. Preserve its complete
	# transient layout state when present; restoring Controls alone leaves the
	# last synthetic case cached for the next frame_pre_draw.
	for definition in h.get_property_list():
		if String(definition.name) != "tracker_clearance": continue
		var tracker: Node = h.get("tracker_clearance")
		if not is_instance_valid(tracker): break
		result["tracker_state"] = {"node": tracker}
		for field in ["base_positions", "offset_y", "release_in", "context", "no_fit"]:
			var value: Variant = tracker.get(field)
			result.tracker_state[field] = value.duplicate() if value is Array else value
		break
	return result


static func stash_controls(node: Node, rows: Array) -> void:
	if node is Control:
		var row := {"node": node, "position": node.position, "size": node.size,
			"scale": node.scale, "visible": node.visible}
		if node is Label:
			row.text = node.text
		rows.append(row)
	for child in node.get_children():
		stash_controls(child, rows)


static func restore(h: Hud, saved: Dictionary) -> void:
	# Text first: minimum-size updates must settle before restoring rectangles.
	for row in saved.controls:
		if row.has("text") and row.node.text != row.text:
			row.node.text = row.text
	for row in saved.controls:
		# Control.set_size clamps to its minimum even for an unchanged value.
		# Do not resize untouched hidden controls while restoring this fixture.
		if row.node.position != row.position:
			row.node.position = row.position
		if row.node.size != row.size:
			row.node.size = row.size
		if row.node.scale != row.scale:
			row.node.scale = row.scale
		if row.node.visible != row.visible:
			row.node.visible = row.visible
	for row in saved.sprites:
		row.node.position = row.position
	h._dossier_values = String(saved.dossier_values)
	h.visible = bool(saved.hud_visible)
	var tracker_state: Dictionary = saved.get("tracker_state", {})
	if not tracker_state.is_empty() and is_instance_valid(tracker_state.node):
		for field in ["base_positions", "offset_y", "release_in", "context", "no_fit"]:
			var value: Variant = tracker_state[field]
			tracker_state.node.set(field, value.duplicate() if value is Array else value)


static func suite(h: Hud) -> String:
	var saved := snapshot(h)
	h.visible = true
	var error := ""
	for row in CASES:
		apply_case(h, row)
		for check in inspect(h).checks:
			if not check.passed and error.is_empty():
				error = "HUD alignment %s/%s: %s" % [row.id, check.id, JSON.stringify(check.details)]
	apply_case(h, CASES[0])
	var negatives := negative_controls(h)
	for key in negatives:
		if not negatives[key] and error.is_empty():
			error = "HUD alignment negative control: " + String(key)
	restore(h, saved)
	var restored := snapshot(h)
	if restored != saved and error.is_empty():
		var changes: Array[String] = []
		for index in mini(saved.controls.size(), restored.controls.size()):
			var before: Dictionary = saved.controls[index]
			var after: Dictionary = restored.controls[index]
			for key in before:
				if before[key] != after.get(key):
					changes.append("%s %s: %s -> %s" % [before.node.get_path(), key, before[key], after.get(key)])
		error = "HUD alignment fixture did not restore its borrowed control geometry/text: " + str(changes)
	if error.is_empty(): error = ally_arrows(h)
	return error


static func add(result: Dictionary, id: String, passed: bool, details: Dictionary = {}) -> void:
	result.checks.append({"id": id, "passed": passed, "details": details})


static func failed(result: Dictionary, id: String) -> bool:
	for check in result.checks:
		if check.id == id:
			return not check.passed
	return false


static func rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


static func to_rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


## Quick-tier production arrow checks. Borrow live HUD controls synchronously,
## so no gameplay/touch processing runs against the synthetic roster or window.
## Solo never allocates the party UI or damage meter: whatever this builds is
## freed again, on the failure paths too.
static func ally_arrows(h: Hud) -> String:
	var had_party := h.party_root != null
	var had_meter := h.meter_root != null
	var hooked := RenderingServer.frame_pre_draw.is_connected(h._place_down_marks_clear)
	h._ensure_party_ui()
	h._ensure_meter_ui()
	var saved := snapshot(h)
	var g := h.game
	var window := h.get_window()
	var window_size := window.size
	var content_size := window.content_scale_size
	var players := g.players.duplicate()
	var old_touch: Node = g._touch_hud
	var touch_mode := h._touch_mode
	var settings := g.settings.duplicate(true)
	var names_alpha := h.party_names_alpha
	g.settings["touch_layout"] = {}
	var items: Array[Dictionary] = []
	for arrow in h.party_arrows:
		items.append(_stash_item(arrow, ["party_arrow_world_at", "party_arrow_urgent"]))
	for tag in h.party_names:
		items.append(_stash_item(tag, ["party_name_world_at", "party_name_no_fit", "fcol"]))
	var ally := Player.new()
	ally.peer_id = 987654
	var second := Player.new()
	second.peer_id = 987655
	g.players.assign([g.local_player, ally, second])
	var touch := TouchHud.new()
	touch.game = g
	g.add_child(touch)
	g._touch_hud = touch
	var error := _ally_arrow_checks(h, ally, second, touch)
	g.players.assign(players)
	g._touch_hud = old_touch
	touch.free()
	ally.free()
	second.free()
	g.settings = settings
	h.party_names_alpha = names_alpha
	window.size = window_size
	window.content_scale_size = content_size
	h.set_touch_mode(touch_mode)
	restore(h, saved)
	for row in items: _unstash_item(row)
	_drop_fixture_party_ui(h, had_party, had_meter, hooked)
	if error.is_empty():
		print("ok: ally arrows (8 directions + party-column aims x 3 live viewport sizes x desktop/touch x up/downed/ghost through the pre-draw pass, independent painted-HUD oracle incl. portrait/damage meter, name-tag avoidance, no stacking with rescue priority, name handoff at the live edge, nearest edge and no-fit)")
	return error


static func _stash_item(item: CanvasItem, metas: Array) -> Dictionary:
	var row := {"node": item, "visible": item.visible, "modulate": item.modulate, "metas": {}, "meta_keys": metas}
	if item is Node2D:
		row.transform = (item as Node2D).transform
	if item is Polygon2D:
		row.color = (item as Polygon2D).color
	if item is Label:
		row.font_override = item.has_theme_color_override("font_color")
		row.font_color = item.get_theme_color("font_color")
	for key in metas:
		if item.has_meta(key): row.metas[key] = item.get_meta(key)
	return row


static func _unstash_item(row: Dictionary) -> void:
	var item: CanvasItem = row.node
	item.visible = row.visible
	item.modulate = row.modulate
	if row.has("transform"): (item as Node2D).transform = row.transform
	if row.has("color"): (item as Polygon2D).color = row.color
	if row.has("font_override"):
		if row.font_override: item.add_theme_color_override("font_color", row.font_color)
		else: item.remove_theme_color_override("font_color")
	for key in row.meta_keys:
		if row.metas.has(key): item.set_meta(key, row.metas[key])
		elif item.has_meta(key): item.remove_meta(key)


## Free what the fixture allocated. The lazy party build queued a deferred
## pre-draw hook connection; a later deferred call undoes it in FIFO order.
static func _drop_fixture_party_ui(h: Hud, had_party: bool, had_meter: bool, hooked: bool) -> void:
	if not had_meter and is_instance_valid(h.meter_root):
		h.meter_root.queue_free()
		h.meter_root = null
		h.meter_rows.clear()
	if not had_party:
		# reset_party_ui also frees the meter; keep one that predates the fixture.
		var meter := h.meter_root
		var rows := h.meter_rows.duplicate()
		h.meter_root = null
		h.reset_party_ui()
		h.meter_root = meter
		h.meter_rows.assign(rows)
	if not hooked:
		var unhook := func() -> void:
			if is_instance_valid(h) and RenderingServer.frame_pre_draw.is_connected(h._place_down_marks_clear):
				RenderingServer.frame_pre_draw.disconnect(h._place_down_marks_clear)
		unhook.call_deferred()


static func _arrow_rect(arrow: Polygon2D) -> Rect2:
	var bounds := Rect2(arrow.global_transform * arrow.polygon[0], Vector2.ZERO)
	for point in arrow.polygon:
		bounds = bounds.expand(arrow.global_transform * point)
	return bounds


## Independent painted-HUD oracle: native rects of the HUD an edge arrow must
## never cover, walked here rather than read from the production reservation
## list the placement itself avoids.
static func _arrow_hud_rects(h: Hud, touch: TouchHud) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [h.avatar_root, h.vitals_panel, h.info_panel, h.minimap_root, h.quest_panel,
			h.zone_label, h.quest_label, h.wayfinder.quest_root, h.meter_root]:
		if is_instance_valid(node): _paint_walk(out, node)
	for slot in h.party_slots: _paint_walk(out, slot.root)
	for box in h.slot_boxes:
		for key in ["border", "bg", "icon", "key", "name", "cost"]:
			if box.has(key) and is_instance_valid(box[key]): _paint_walk(out, box[key])
	for box in h.buff_slots:
		for key in ["border", "icon", "time_bg", "time", "fill"]:
			if box.has(key) and is_instance_valid(box[key]): _paint_walk(out, box[key])
	for hint in h.hint_labels: _paint_walk(out, hint)
	for tag in h.party_names: _paint_walk(out, tag)
	if touch.visible:
		for button in touch._btns.values(): _paint_walk(out, button.panel)
		for control in [touch._joy_base, touch._joy_knob, touch._info]:
			if is_instance_valid(control): _paint_walk(out, control)
	return out


static func _paint_walk(out: Array[Rect2], node: Node) -> void:
	if node is CanvasItem and (not node.is_visible_in_tree() or node.modulate.a <= 0.01): return
	if node is Control and node.size.x > 0.0 and node.size.y > 0.0 and node.self_modulate.a > 0.01 \
			and not (node is Label and node.text.is_empty()):
		var rect: Rect2 = node.get_global_rect()
		if node is Label: rect = rect.grow(float(node.get_theme_constant("outline_size")))
		out.append(rect)
	for child in node.get_children(): _paint_walk(out, child)


## Check one arrow the real pre-draw placement put down, at its pulse peak.
static func _arrow_case(arrow: Polygon2D, target: Vector2, urgent: bool, view: Rect2,
		hud_rects: Array[Rect2], label: String) -> String:
	if not arrow.visible:
		return "ally arrow hidden despite a clear screen edge: " + label
	# Force the animation peak: coverage must hold at every pulse phase.
	if urgent: arrow.scale = Vector2.ONE * (1.0 + Balance.HUD_ALLY_ARROW_PULSE_SCALE)
	var bounds := _arrow_rect(arrow)
	if not view.encloses(bounds):
		return "ally arrow escaped live viewport: %s: %s" % [label, bounds]
	for rect in hud_rects:
		if bounds.intersects(rect):
			return "ally arrow overlaps visible HUD: %s: %s vs %s" % [label, bounds, rect]
	var pointing := Vector2.UP.rotated(arrow.rotation)
	var from_center := target - view.get_center()
	if pointing.dot((target - arrow.position).normalized()) < 0.999 \
			or (absf(from_center.x) > 1.0 and signf(pointing.x) != signf(from_center.x)) \
			or (absf(from_center.y) > 1.0 and signf(pointing.y) != signf(from_center.y)):
		return "displaced ally arrow lost the ally direction: " + label
	var edge := view.grow(-Balance.HUD_ALLY_ARROW_INSET)
	if not (is_equal_approx(arrow.position.x, edge.position.x) or is_equal_approx(arrow.position.x, edge.end.x) \
			or is_equal_approx(arrow.position.y, edge.position.y) or is_equal_approx(arrow.position.y, edge.end.y)):
		return "ally arrow did not use the live screen edge: " + label
	return ""


static func _ally_arrow_checks(h: Hud, ally: Player, second: Player, touch: TouchHud) -> String:
	h.visible = true
	h.party_root.show()
	for slot in h.party_slots:
		slot.root.show()
		slot.name.text = "A visible ally"
		slot.state.hide()
	for tag in h.party_names: tag.hide()
	# The co-op left column below the frames: a damage meter with one inked row.
	h.meter_root.show()
	var meter_row: Dictionary = h.meter_rows[0]
	(meter_row.root as Control).show()
	(meter_row.name as Label).text = "A visible ally"
	(meter_row.val as Label).text = "1.2k"
	if not h.avatar_root.is_visible_in_tree() or not h.meter_root.is_visible_in_tree():
		return "ally arrow fixture has no visible portrait/damage meter to avoid"
	var directions := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var inset := Balance.HUD_ALLY_ARROW_INSET
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(900, 900)]:
		h.get_window().size = size
		h.get_window().content_scale_size = size
		var view := h.get_viewport().get_visible_rect()
		if not view.size.is_equal_approx(Vector2(size)):
			return "ally arrow fixture did not change the live viewport: " + str(view)
		var center := view.get_center()
		var inverse: Transform2D = h.game.get_viewport().canvas_transform.affine_inverse()
		# Rays whose ideal edge point lands on each party card and in the gap
		# between the first two: the old placement drew right on the frames.
		var cards: Array[Rect2] = []
		for slot in h.party_slots:
			# The slot root is a size-zero group: merge the card's painted parts.
			var parts: Array[Rect2] = []
			_paint_walk(parts, slot.root)
			var card := Rect2()
			for part in parts: card = part if not card.has_area() else card.merge(part)
			cards.append(card)
		var column: Array[Vector2] = []
		for y in [cards[0].get_center().y, (cards[0].end.y + cards[1].position.y) * 0.5,
				cards[1].get_center().y, cards[2].get_center().y]:
			var aim := Vector2(view.position.x + inset, y)
			var hit := false
			for card in cards: hit = hit or card.intersects(Rect2(aim - Vector2(9, 9), Vector2(18, 18)))
			if not hit:
				return "party-column aim does not reach a party card at %s: %s" % [size, aim]
			column.append(center + (aim - center) * 3.0)
		for use_touch in [false, true]:
			h.set_touch_mode(use_touch)
			for hint in h.hint_labels: hint.visible = not use_touch
			touch.visible = use_touch
			touch._layout()
			# Exercise a painted floating joystick as well as the right buttons.
			touch._place_joystick(Vector2(80, size.y - 100), Vector2(80, size.y - 100))
			touch._joy_base.show()
			touch._joy_knob.show()
			var hud_rects := _arrow_hud_rects(h, touch)
			var present: Control = touch._btns.values()[0].panel if use_touch else h.hint_labels[0]
			if not present.is_visible_in_tree():
				return "ally arrow fixture has no visible hints/touch controls to avoid"
			var targets: Array[Vector2] = []
			# Aspect-scaled diagonals exit at the actual four corners.
			for direction in directions: targets.append(center + direction * view.size * 2.0)
			targets.append_array(column)
			for state in ["up", "downed", "ghost"]:
				for index in targets.size():
					var target := targets[index]
					var label := "%s/touch %s/%s/%s" % [size, use_touch, state, target]
					ally.global_position = inverse * target
					h._update_party_arrows([{"peer": ally.peer_id, "state": state, "cls": "warrior"}])
					h._place_party_overlays_clear()
					var arrow: Polygon2D = h.party_arrows[0]
					var error := _arrow_case(arrow, target, state != "up", view, hud_rects, label)
					if not error.is_empty(): return error
					# Everything above the column is HUD too: the slide stays on its edge.
					if index >= directions.size() and not is_equal_approx(arrow.position.x, view.position.x + inset):
						return "party-column arrow left the left edge: %s: %s" % [label, arrow.position]
			# Two allies in one direction: no stacking, and the downed one listed
			# second still claims the nearest spot.
			var shared := center + Vector2.RIGHT * view.size * 2.0
			ally.global_position = inverse * shared
			second.global_position = inverse * shared
			h._update_party_arrows([{"peer": second.peer_id, "state": "up", "cls": "mage"},
				{"peer": ally.peer_id, "state": "downed", "cls": "warrior"}])
			h._place_party_overlays_clear()
			var calm: Polygon2D = h.party_arrows[0]
			var rescue: Polygon2D = h.party_arrows[1]
			var shared_label := "%s/touch %s/shared" % [size, use_touch]
			var calm_error := _arrow_case(calm, shared, false, view, hud_rects, shared_label)
			if not calm_error.is_empty(): return calm_error
			var rescue_error := _arrow_case(rescue, shared, true, view, hud_rects, shared_label)
			if not rescue_error.is_empty(): return rescue_error
			if _arrow_rect(calm).intersects(_arrow_rect(rescue)):
				return "two allies in one direction stacked their arrows: " + shared_label
			var ideal := h._edge_point(center, shared - center, view.position + Vector2.ONE * inset, view.end - Vector2.ONE * inset)
			if rescue.position.distance_to(ideal) > calm.position.distance_to(ideal) + 0.01:
				return "downed ally's arrow lost the nearest spot to an upright ally: " + shared_label
			# An ally inside the enlarged live screen gets its name tag, not a stale 720p arrow.
			h.party_names_alpha = 0.85
			ally.global_position = inverse * (view.end - Vector2(20, 20))
			var edge_data := [{"peer": ally.peer_id, "state": "up", "cls": "warrior", "name": "Edge ally"}]
			h._update_party_arrows(edge_data)
			h._update_party_names(edge_data)
			if (h.party_arrows[0] as Polygon2D).visible:
				return "on-screen ally received an off-screen arrow"
			if not (h.party_names[0] as Label).visible:
				return "on-screen ally at the live screen edge got neither an arrow nor a name tag: %s/touch %s" % [size, use_touch]
			(h.party_names[0] as Label).hide()
	# The real pre-draw order at 720p: names are placed first, then an arrow
	# whose ideal edge spot sits on that final name tag slides clear of it.
	h.get_window().size = Vector2i(1280, 720)
	h.get_window().content_scale_size = Vector2i(1280, 720)
	h.set_touch_mode(false)
	for hint in h.hint_labels: hint.visible = true
	touch.visible = false
	var view := h.get_viewport().get_visible_rect()
	var center := view.get_center()
	var inverse: Transform2D = h.game.get_viewport().canvas_transform.affine_inverse()
	var spot := Vector2(view.position.x + inset, view.position.y + view.size.y * 0.75)
	var far := center + (spot - center) * 3.0
	ally.global_position = inverse * far
	second.global_position = inverse * (spot + Vector2(18, 54))  # head on the spot
	var both := [{"peer": second.peer_id, "state": "up", "cls": "mage", "name": "Named ally"},
		{"peer": ally.peer_id, "state": "up", "cls": "warrior", "name": "Far ally"}]
	h._update_party_names(both)
	h._update_party_arrows(both)
	h._place_party_overlays_clear()
	var tag: Label = h.party_names[0]
	var tag_rect := tag.get_global_rect().grow(float(tag.get_theme_constant("outline_size")))
	if not tag.visible or not tag_rect.intersects(Rect2(spot - Vector2(9, 9), Vector2(18, 18))):
		return "name-tag fixture did not put the tag on the arrow's ideal edge spot: %s" % tag_rect
	var named_arrow: Polygon2D = h.party_arrows[0]
	var named_error := _arrow_case(named_arrow, far, false, view, _arrow_hud_rects(h, touch), "720p/name tag")
	if not named_error.is_empty(): return named_error
	# No clear spot anywhere: the production placement hides the arrow.
	var full: Array[Rect2] = [view]
	h._place_party_arrows_clear(view, h.game.get_viewport().canvas_transform, full)
	if named_arrow.visible:
		return "ally arrow stayed visible with no clear edge spot"
	# Exact nearest-slide contract, and a genuinely full perimeter.
	view = Rect2(0, 0, 1280, 720)
	var local := Rect2(-14, -14, 28, 28)
	var obstacle := Rect2(0, 320, 100, 100)
	var blockers: Array[Rect2] = [obstacle]
	var result: Dictionary = h._party_arrow_clear_position(view, Vector2.LEFT, local, blockers)
	if not result.fits or not (result.position as Vector2).is_equal_approx(Vector2(42, 306)):
		return "ally arrow did not slide to the nearest clear point on its edge"
	blockers.assign([view])
	if h._party_arrow_clear_position(view, Vector2.LEFT, local, blockers).fits:
		return "ally arrow claimed a fit with every edge blocked"
	blockers.clear()
	for direction in directions:
		var expected := h._edge_point(view.get_center(), direction, Vector2(42, 42), Vector2(1238, 678))
		result = h._party_arrow_clear_position(view, direction, local, blockers)
		if not result.fits or not (result.position as Vector2).is_equal_approx(expected):
			return "unobstructed ally arrow changed its authored placement"
	return _ally_arrow_cost(h)


## Cost guard: placement runs per arrow on every online frame, and the shared
## solver is quadratic in the reservations it is handed. With each arrow's own
## edge blocked at its ideal spot (so every arrow searches), mid-screen
## reservations (world names, prompts, status marks) must neither move an arrow
## nor slow it down. The unfiltered search took about 75 ms on this layout.
static func _ally_arrow_cost(h: Hud) -> String:
	const DECOYS := 200
	const BUDGET_MS := 10.0  # three arrows, fastest of five runs
	var view := Rect2(0, 0, 1280, 720)
	var local := Rect2(-14, -14, 28, 28)
	# A top banner, a bottom bar, a left column and a corner map.
	var hud: Array[Rect2] = [Rect2(300, 0, 680, 70), Rect2(300, 650, 680, 70),
		Rect2(0, 100, 230, 500), Rect2(1050, 0, 230, 230)]
	var crowded: Array[Rect2] = []
	crowded.append_array(hud)
	var middle := view.grow(-120.0)
	for i in DECOYS:
		# Distinct x per rect, all well clear of every edge lane.
		crowded.append(Rect2(middle.position + Vector2(fmod(i * 53.0, middle.size.x - 20.0),
			fmod(i * 29.0, middle.size.y - 12.0)), Vector2(20, 12)))
	var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT]
	for direction in directions:
		var plain: Dictionary = h._party_arrow_clear_position(view, direction, local, hud)
		var busy: Dictionary = h._party_arrow_clear_position(view, direction, local, crowded)
		if not plain.fits or busy.fits != plain.fits or busy.position != plain.position:
			return "mid-screen reservations moved an ally arrow: %s: %s vs %s" % [direction, plain, busy]
	var fastest := INF
	for _run in 5:
		var began := Time.get_ticks_usec()
		for direction in directions: h._party_arrow_clear_position(view, direction, local, crowded)
		fastest = minf(fastest, (Time.get_ticks_usec() - began) / 1000.0)
	if fastest > BUDGET_MS:
		return "ally arrow placement slowed down with %d mid-screen reservations: %.2f ms for 3 arrows (budget %.1f)" % [DECOYS, fastest, BUDGET_MS]
	print("ok: ally arrow cost guard (%d mid-screen reservations: same spots, %.2f ms for 3 searching arrows)" % [DECOYS, fastest])
	return ""
