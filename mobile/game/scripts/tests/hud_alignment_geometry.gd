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
