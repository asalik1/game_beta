extends RefCounted
## Read-only settled-frame measurements; native originals still decide visual quality.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const EPS := 0.5


static func inspect(m: Menus, footer: Label = null, result_label: Label = null,
		expected_result: String = "") -> Dictionary:
	var out := {"ok": false, "measurements": [], "violations": [], "skipped_hidden": 0,
		"limits": ["Label cells are shaped bounds, not raster ink or contrast.",
			"Button metrics are single-line measurements, not glyph/crop pixel proof.",
			"Button icons, tiled images, rotation/skew and nonidentity canvas require explicit review.",
			"No overlap, aesthetic, physical-device or input-delivery acceptance."]}
	if not is_instance_valid(m) or m.current != "professions" or not is_instance_valid(m.root):
		_issue(out, "setup.menu", "", "Expected live Professions root")
		return out
	var root: Control = m.root
	var shell: Rect2 = m._shell_rect
	var viewport := root.get_viewport().get_visible_rect()
	out.shell = Geometry.rect(shell)
	out.viewport = Geometry.rect(viewport)
	if not root.is_visible_in_tree() or not shell.has_area():
		_issue(out, "setup.visibility", "", "Root hidden or shell has no area")
	if not root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY):
		_issue(out, "setup.canvas", "", "Nonidentity canvas not supported by shaped-label coordinate contract")
	if is_instance_valid(footer) and not root.is_ancestor_of(footer):
		_issue(out, "setup.footer", "", "Exact footer must belong to current root")
		footer = null
	_walk(root, shell, viewport, footer, out)
	if not expected_result.is_empty():
		if not is_instance_valid(result_label) or not root.is_ancestor_of(result_label) \
				or not result_label.is_visible_in_tree():
			_issue(out, "result.missing", "", expected_result)
		elif result_label.text != expected_result:
			_issue(out, "result.copy", str(result_label.get_path()),
				{"expected": expected_result, "actual": result_label.text})
	out.ok = out.violations.is_empty()
	return out


static func _issue(out: Dictionary, id: String, path: String, details: Variant) -> void:
	out.violations.append({"id": id, "path": path, "details": details})


static func _alpha(item: CanvasItem) -> float:
	var alpha := item.self_modulate.a
	var node: Node = item
	while is_instance_valid(node):
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


static func _bounds(c: Control, bounds: Rect2, shell: Rect2, viewport: Rect2,
		out: Dictionary, kind := "control") -> void:
	var path := str(c.get_path())
	if not shell.grow(EPS).encloses(bounds):
		_issue(out, kind + ".outside_shell", path, Geometry.rect(bounds))
	if not viewport.grow(EPS).encloses(bounds):
		_issue(out, kind + ".outside_viewport", path, Geometry.rect(bounds))
	var node := c.get_parent()
	while is_instance_valid(node):
		var parent := node as Control
		if parent != null and parent.clip_contents and not parent.get_global_rect().grow(EPS).encloses(bounds):
			_issue(out, kind + ".ancestor_clip", path, str(parent.get_path()))
		node = node.get_parent()


static func _walk(node: Node, shell: Rect2, viewport: Rect2, footer: Label, out: Dictionary) -> void:
	var c := node as Control
	if c != null and (c is Label or c is Button or c is TextureRect):
		if not c.is_visible_in_tree():
			out.skipped_hidden += 1
		else:
			var path := str(c.get_path())
			var xf := c.get_global_transform()
			if absf(xf.x.y) > 0.00001 or absf(xf.y.x) > 0.00001:
				_issue(out, "control.transform_unverified", path, str(xf))
			_bounds(c, c.get_global_rect(), shell, viewport, out)
			if c is Label:
				_label(c as Label, footer, shell, viewport, out)
			elif c is Button:
				_button(c as Button, out)
			else:
				_texture(c as TextureRect, shell, viewport, out)
	for child in node.get_children():
		_walk(child, shell, viewport, footer, out)


static func _label(c: Label, footer: Label, shell: Rect2, viewport: Rect2, out: Dictionary) -> void:
	var path := str(c.get_path())
	var shape: Dictionary = Geometry.shaped(c)
	var cells: Rect2 = Geometry.to_rect(shape.cells)
	var alpha: float = _alpha(c) * c.get_theme_color("font_color").a
	out.measurements.append({"kind": "Label", "path": path, "shape": shape,
		"rect": Geometry.rect(c.get_global_rect()), "alpha": alpha, "footer_font_exception": c == footer})
	if c.text.strip_edges().is_empty():
		return
	if c != footer and c.get_theme_font_size("font_size") < 14:
		_issue(out, "label.small_font", path, shape.font_size)
	if alpha <= 0.0:
		_issue(out, "label.invisible_text", path, alpha)
	if int(shape.count) <= 0 or not shape.missing.is_empty() \
			or c.visible_ratio < 1.0 or c.max_lines_visible != -1 \
			or c.get_visible_line_count() != c.get_line_count():
		_issue(out, "label.incomplete_text", path, shape)
	if int(shape.count) > 0:
		if not c.get_global_rect().grow(EPS).encloses(cells):
			_issue(out, "label.cells_outside_control", path, Geometry.rect(cells))
		_bounds(c, cells, shell, viewport, out, "text")


static func _button(c: Button, out: Dictionary) -> void:
	var path := str(c.get_path())
	var composite := _composite_labels(c, out) if c.text.strip_edges().is_empty() else {}
	var rect := c.get_global_rect()
	var font_size := c.get_theme_font_size("font_size")
	var text_size := c.get_theme_font("font").get_string_size(c.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var mode := c.get_draw_mode()
	var styles := {BaseButton.DRAW_NORMAL: "normal", BaseButton.DRAW_PRESSED: "pressed",
		BaseButton.DRAW_HOVER: "hover", BaseButton.DRAW_DISABLED: "disabled",
		BaseButton.DRAW_HOVER_PRESSED: "hover_pressed"}
	var colors := {BaseButton.DRAW_NORMAL: "font_focus_color" if c.has_focus() else "font_color",
		BaseButton.DRAW_PRESSED: "font_pressed_color", BaseButton.DRAW_HOVER: "font_hover_color",
		BaseButton.DRAW_DISABLED: "font_disabled_color", BaseButton.DRAW_HOVER_PRESSED: "font_hover_pressed_color"}
	var style_name: String = styles.get(mode, "normal")
	if not c.has_theme_stylebox(style_name): style_name = "pressed"
	var margins := Vector4.ZERO
	var names: Array = [style_name]
	if c.get_theme_constant("align_to_largest_stylebox") != 0:
		names = ["normal", "pressed", "hover", "disabled"]
	for name: String in names:
		var style := c.get_theme_stylebox(name)
		margins.x = maxf(margins.x, style.get_margin(SIDE_LEFT))
		margins.y = maxf(margins.y, style.get_margin(SIDE_TOP))
		margins.z = maxf(margins.z, style.get_margin(SIDE_RIGHT))
		margins.w = maxf(margins.w, style.get_margin(SIDE_BOTTOM))
	var inner := c.size - Vector2(margins.x + margins.z, margins.y + margins.w)
	var color_name: String = colors.get(mode, "font_color")
	if not c.has_theme_color(color_name): color_name = "font_color"
	var alpha: float = _alpha(c) * c.get_theme_color(color_name).a
	out.measurements.append({"kind": "Button", "path": path, "text": c.text,
		"rect": Geometry.rect(rect), "font_size": font_size, "disabled": c.disabled,
		"inner": [inner.x, inner.y], "unwrapped_text": [text_size.x, text_size.y],
		"alpha": alpha, "clip_text": c.clip_text, "overrun": c.text_overrun_behavior,
		"authored_composite": composite})
	if not c.text.strip_edges().is_empty() and font_size < 14:
		_issue(out, "button.small_font", path, font_size)
	if (c.text.strip_edges().is_empty() and not bool(composite.get("valid", false))) \
			or (not c.text.strip_edges().is_empty() and alpha <= 0.0):
		_issue(out, "button.blank_or_hidden_text", path, {"text": c.text, "alpha": alpha})
	if not c.disabled and (rect.size.x + EPS < 44.0 or rect.size.y + EPS < 44.0):
		_issue(out, "button.small_hit", path, Geometry.rect(rect))
	if c.icon != null or c.has_theme_icon("icon"):
		_issue(out, "button.icon_geometry_unverified", path, "Icon alignment/expansion requires separate native review")
	if c.text.strip_edges().is_empty():
		return  # Authored child Labels are shaped and measured independently by _walk.
	if c.is_layout_rtl() or c.autowrap_mode != TextServer.AUTOWRAP_OFF or c.text.contains("\n"):
		_issue(out, "button.text_geometry_unverified", path, "Collector supports single-line LTR buttons")
	elif text_size.x > inner.x + EPS or text_size.y > inner.y + EPS:
		_issue(out, "button.text_overflow", path, {"text": [text_size.x, text_size.y], "inner": [inner.x, inner.y]})


static func _composite_labels(button: Button, out: Dictionary) -> Dictionary:
	var labels: Array = []
	var valid := true
	for candidate in button.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label == null or not label.is_visible_in_tree() or label.text.strip_edges().is_empty():
			continue
		var shape: Dictionary = Geometry.shaped(label)
		var cells: Rect2 = Geometry.to_rect(shape.cells)
		var readable: bool = int(shape.count) > 0 and shape.missing.is_empty() \
			and label.visible_ratio >= 1.0 and label.max_lines_visible == -1 \
			and label.get_visible_line_count() == label.get_line_count() \
			and label.get_theme_font_size("font_size") >= 14 \
			and _alpha(label) * label.get_theme_color("font_color").a > 0.0 \
			and label.get_global_rect().grow(EPS).encloses(cells) \
			and button.get_global_rect().grow(EPS).encloses(cells)
		var pointer_clear := true
		var node: Node = label
		while node != button and is_instance_valid(node):
			var control := node as Control
			if control != null:
				if control.mouse_filter != Control.MOUSE_FILTER_IGNORE or control is BaseButton:
					pointer_clear = false
					_issue(out, "button.child_pointer_unverified", str(control.get_path()),
						{"button": str(button.get_path()), "mouse_filter": control.mouse_filter})
				if control.clip_contents and not control.get_global_rect().grow(EPS).encloses(cells):
					readable = false
			node = node.get_parent()
		labels.append({"path": str(label.get_path()), "text": label.text,
			"cells": Geometry.rect(cells), "readable": readable, "pointer_clear": pointer_clear})
		valid = valid and readable and pointer_clear
	return {"valid": valid and not labels.is_empty(), "labels": labels,
		"scope": "Visible authored child Labels; pointer forwarding unverified unless full chain IGNORE"}


static func _texture(c: TextureRect, shell: Rect2, viewport: Rect2, out: Dictionary) -> void:
	var path := str(c.get_path())
	var row := {"kind": "TextureRect", "path": path, "stretch": c.stretch_mode,
		"control": Geometry.rect(c.get_global_rect()), "alpha": _alpha(c)}
	out.measurements.append(row)
	if c.texture == null:
		_issue(out, "texture.missing", path, "Visible TextureRect has no texture")
		return
	# Procedural gradients are intentionally stretched rules, not raster artwork.
	# Their bounds and visibility remain measured; source-pixel fidelity does not apply.
	if c.texture is GradientTexture1D or c.texture is GradientTexture2D:
		row.procedural_gradient = true
		if _alpha(c) <= 0.0: _issue(out, "texture.invisible", path, row.alpha)
		return
	var native := c.texture.get_size()
	row.native = [native.x, native.y]
	if native.x <= 0.0 or native.y <= 0.0:
		_issue(out, "texture.empty", path, row.native)
		return
	if c.size.x <= 0.0 or c.size.y <= 0.0:
		_issue(out, "texture.no_area", path, Geometry.rect(c.get_global_rect()))
		return
	var size := c.size
	var offset := Vector2.ZERO
	var sampled := native
	match c.stretch_mode:
		TextureRect.STRETCH_KEEP: size = native
		TextureRect.STRETCH_KEEP_CENTERED:
			size = native
			offset = (c.size - size) * 0.5
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			# Godot4.4 TextureRect truncates fitted dimensions to integer pixels.
			size = Vector2(int(native.x * c.size.y / native.y), int(c.size.y))
			if size.x > c.size.x:
				size = Vector2(int(c.size.x), int(native.y * int(c.size.x) / native.x))
			if c.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				offset = (c.size - size) * 0.5
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			var ratio := maxf(c.size.x / native.x, c.size.y / native.y)
			if ratio <= 0.0: return
			sampled = c.size / ratio
			row.source_region = Geometry.rect(Rect2((native - sampled) * 0.5, sampled))
			if not sampled.is_equal_approx(native):
				_issue(out, "texture.cropped", path, row.source_region)
		TextureRect.STRETCH_TILE:
			_issue(out, "texture.tile_unverified", path, "Tiled illustration not supported")
			return
	var xf := c.get_global_transform()
	var drawn: Rect2 = xf * Rect2(offset, size)
	var ratios := Vector2(xf.x.length() * size.x / sampled.x, xf.y.length() * size.y / sampled.y)
	row.drawn = Geometry.rect(drawn)
	row.ratios = [ratios.x, ratios.y]
	if ratios.x > 0.5 + 0.000001 or ratios.y > 0.5 + 0.000001:
		_issue(out, "texture.insufficient_fidelity", path, row)
	if _alpha(c) <= 0.0: _issue(out, "texture.invisible", path, row.alpha)
	_bounds(c, drawn, shell, viewport, out, "texture")
