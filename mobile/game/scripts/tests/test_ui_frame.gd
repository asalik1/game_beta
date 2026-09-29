extends RefCounted
## Runs inside forge/daily's private UIWorld in the quick UI smoke tier.

const MISSING_ROOT := "res://missing_forged_frame_test/"


static func run(g: Game) -> String:
	var cached := UITheme._theme
	var kit := UITheme.frame_root
	var codex_sec := UICodex._sec
	var root := Control.new()
	g.add_child(root)
	var error := await _checks(g, root)
	if error == "":
		# Second pass with the kit folder missing: every builder's flat fallback.
		UITheme.frame_root = MISSING_ROOT
		UITheme._theme = null
		error = await _fallback_checks(g, root)
	# Every exit path restores the kit folder, the cached theme and the rail.
	UITheme.frame_root = kit
	UICodex._sec = codex_sec
	root.free()
	UITheme._theme = cached
	if error == "": print("ok: forged theme textures, protected slices, per-builder flat fallback, compact tabs and codex rail, exact grade rims, flat tracks, five-piece divider and 2px shell header footprint")
	return error


static func _slice(style: StyleBox, file: String, margin: float) -> bool:
	if not style is StyleBoxTexture: return false
	if style.texture.resource_path != UITheme.FRAME_ROOT + file: return false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if style.get_texture_margin(side) != margin: return false
	return true


static func _margins(style: StyleBox) -> Array:
	return [style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom]


## The socket's rim carries exactly `tint` (its brightest rim pixel IS the
## tint, so a gold rim multiplied by blue fails) and the well is untouched art.
static func _rim_tint_error(style: StyleBox, tint: Color) -> String:
	if not style is StyleBoxTexture or style.get_meta("slot_tint", Color.TRANSPARENT) != tint:
		return "slot does not carry its canonical tint"
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if style.get_texture_margin(side) != UITheme.SLOT_SLICE: return "slot lost its protected 6px slice"
	var img: Image = style.texture.get_image()
	var art: Image = (load(UITheme.FRAME_ROOT + "slot.png") as Texture2D).get_image()
	if img == null or art == null or img.get_size() != art.get_size(): return "slot rim art missing"
	var peak := Color.BLACK
	var band := int(UITheme.SLOT_SLICE)
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if mini(mini(x, y), mini(img.get_width() - 1 - x, img.get_height() - 1 - y)) < band:
				if px.get_luminance() > peak.get_luminance(): peak = px
			elif px != art.get_pixel(x, y):
				return "slot tint leaked into the icon well at %d,%d" % [x, y]
	for channel in 3:
		if absf(peak[channel] - tint[channel]) > 2.0 / 255.0:
			return "slot rim hue drifted from its tint: %s vs %s" % [peak, tint]
	return ""


static func _checks(g: Game, root: Control) -> String:
	var fallback := UITheme._fallback_flat(UITheme.PANEL_BG, UITheme.BORDER, 2, 8)
	fallback.content_margin_left = 17
	var missing := UITheme.frame_style("res://missing_forged_frame_test.png", 16, fallback)
	if not missing is StyleBoxFlat or missing != fallback or missing.content_margin_left != 17 \
			or missing.bg_color != UITheme.PANEL_BG or missing.border_width_left != 2:
		return "missing frame did not retain the original flat construction"
	var panel := UITheme.panel(root, Vector2.ZERO, Vector2(480, 320))
	if not _slice(panel.get_theme_stylebox("panel"), "panel.png", 16): return "panel lost its protected 16px slice"
	var original := panel.get_theme_stylebox("panel")
	var glass := UITheme.with_opacity(original, Balance.BOOT_PANEL_ALPHA)
	if not glass is StyleBoxTexture or not is_equal_approx(glass.modulate_color.a, Balance.BOOT_PANEL_ALPHA) \
			or original.modulate_color.a != 1.0 or not _slice(glass, "panel.png", 16):
		return "boot glass cannot fade a textured panel independently"
	var flat_glass := UITheme.with_opacity(fallback, Balance.BOOT_PANEL_ALPHA)
	if not flat_glass is StyleBoxFlat or not is_equal_approx(flat_glass.bg_color.a, Balance.BOOT_PANEL_ALPHA) \
			or fallback.bg_color != UITheme.PANEL_BG:
		return "boot glass lost its flat fallback or mutated the original"
	var card := UITheme.card(root, UITheme.GOLD, 4)
	var card_style := card.get_theme_stylebox("panel")
	if not _slice(card_style, "card.png", 9): return "card lost its protected 9px slice"
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if card_style.get_content_margin(side) < 9: return "compact card content overlaps its rim"
	var trade_card := preload("res://scripts/ui/professions.gd")._detail_card(root, UITheme.GOLD)
	if not _slice(trade_card.get_theme_stylebox("panel"), "card.png", 9): return "profession detail stripped the forged card"
	UITheme._theme = null
	UITheme.apply(root)
	var t: Theme = root.theme
	for spec in [["Button", "normal"], ["Button", "hover"], ["Button", "pressed"], ["Button", "disabled"],
			["LineEdit", "normal"], ["TextEdit", "focus"]]:
		if not _slice(t.get_stylebox(spec[1], spec[0]), "card.png", 9): return "widget still flat: " + str(spec)
	var bn := t.get_stylebox("normal", "Button")
	if _margins(bn) != [12.0, 9.0, 12.0, 9.0]: return "button text can sit on the card rim: " + str(_margins(bn))
	# Pressed doubles as a toggle's selected look (journal ward filters).
	if t.get_stylebox("pressed", "Button").modulate_color.v <= bn.modulate_color.v:
		return "pressed/selected button reads dimmer than an idle one"
	# Thin tracks stay flat: their fill and thumb are told apart by color alone.
	for part in [["HSlider", "slider", "grabber_area"], ["HSlider", "slider", "grabber_area_highlight"],
			["VScrollBar", "scroll", "grabber"], ["HScrollBar", "scroll", "grabber"]]:
		var track := t.get_stylebox(part[1], part[0]) as StyleBoxFlat
		var fill := t.get_stylebox(part[2], part[0]) as StyleBoxFlat
		if track == null or fill == null: return "thin track part is not a flat color style: " + str(part)
		if fill.bg_color.get_luminance() - track.bg_color.get_luminance() < 0.25:
			return "fill/thumb cannot be told from its track: " + str(part)
	for height in [25, 26, 28, 32, 44]:
		for active in [false, true]:
			var button := Button.new()
			root.add_child(button)
			button.text = "Gear"
			button.add_theme_font_size_override("font_size", 12)
			UITheme.tab(button, active)
			button.custom_minimum_size = Vector2(160, height)
			button.size = button.custom_minimum_size
			for state in ["normal", "hover", "pressed"]:
				var style := button.get_theme_stylebox(state)
				if not _slice(style, "tab_active.png" if active else "tab_idle.png", 5): return "tab slice/state art changed"
				if style.content_margin_top != 5 or style.content_margin_bottom != 5: return "tab text overlaps the five-pixel rims"
				var text_height := button.get_theme_font("font").get_height(12)
				if text_height > height - style.get_minimum_size().y: return "compact tab label does not fit between rims"
	# The codex rail is the tightest tab user: its real 13px, 25px config.
	var col := VBoxContainer.new()
	root.add_child(col)
	for active in [false, true]:
		UICodex._sec = "frame_probe" if active else ""
		var rail := UICodex._rail_button(g.menus, col, {"id": "frame_probe", "name": "Curiosities"})
		await g.get_tree().process_frame
		var rail_style := rail.get_theme_stylebox("normal")
		if not _slice(rail_style, "tab_active.png" if active else "tab_idle.png", 5): return "codex rail lost its tab art"
		if _margins(rail_style) != [Balance.UI_FRAME_TAB_PAD_X, 5.0, 34.0, 5.0]:
			return "codex rail text can sit on its rims or under its count: " + str(_margins(rail_style))
		if rail.get_minimum_size().y > rail.custom_minimum_size.y:
			return "codex rail label needs %s, more than its %dpx row" % [rail.get_minimum_size().y, int(rail.custom_minimum_size.y)]
	var grid := GridContainer.new()
	root.add_child(grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	for grade in Items.GRADES:
		var item := Items.roll_item_of("weapon", grade, rng, "warrior")
		var before := item.duplicate(true)
		if UITheme.inventory_title(item).begins_with("[") or item != before: return "inventory name retained grade prefix or mutated item"
		var slot := g.menus._bag_slot(grid, g.menus._gear_codex_icon(item), "", Items.GRADE_COLOR[grade], func() -> void: pass)
		var style := slot.get_theme_stylebox("normal")
		var tint_error := _rim_tint_error(style, Items.GRADE_COLOR[grade])
		if tint_error != "": return grade + ": " + tint_error
		if style.get_minimum_size() != Vector2(12, 12) or slot.get_theme_constant("icon_max_width") != 36:
			return "48px slot no longer leaves a clear 36px icon well"
		if slot.modulate != Color.WHITE: return "slot tint leaked onto its icon"
	var socket_error := _rim_tint_error(g.menus._bag_empty(grid).get_theme_stylebox("panel"), UITheme.GOLD_DIM)
	if socket_error != "": return "empty socket: " + socket_error
	var divider := UITheme.rule(root)
	if not divider is HBoxContainer or divider.get_child_count() != 5: return "divider is not a five-part composite"
	for width in [160, 800]:
		divider.size = Vector2(width, Balance.UI_FRAME_DIVIDER_HEIGHT)
		await g.get_tree().process_frame
		await g.get_tree().process_frame
		for i in 5:
			var piece := divider.get_child(i) as TextureRect
			if piece == null or not piece.texture is AtlasTexture: return "divider part lacks an atlas region"
			if piece.texture.region != UITheme.DIVIDER_REGIONS[i]: return "divider atlas region changed"
			if i in [0, 2, 4] and not is_equal_approx(piece.size.x, piece.custom_minimum_size.x):
				return "divider stretched a cap or its center boss"
	# Shell titles: the same divider drawn over the old 2px footprint, centered.
	var header := UITheme.header_rule(root)
	header.size = Vector2(600, UITheme.HEADER_RULE_FOOTPRINT)
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	var drawn: Control = header.get_child(0) as Control if header.get_child_count() == 1 else null
	if header.get_combined_minimum_size().y != UITheme.HEADER_RULE_FOOTPRINT or drawn == null \
			or drawn.name != "ForgedDivider" or drawn.get_child_count() != 5:
		return "shell header rule grew past the old 2px footprint or lost its divider"
	if not is_equal_approx(drawn.size.y, Balance.UI_FRAME_DIVIDER_HEIGHT) or not is_equal_approx(drawn.size.x, 600.0) \
			or not is_equal_approx(drawn.position.y + drawn.size.y * 0.5, UITheme.HEADER_RULE_FOOTPRINT * 0.5):
		return "shell header divider is not drawn full-size and centered on its footprint: " + str(drawn.get_rect())
	return ""


## Kit folder missing: each builder must hand back the pre-forge construction.
static func _fallback_checks(g: Game, root: Control) -> String:
	var panel := UITheme.panel(root, Vector2.ZERO, Vector2(480, 320))
	var ps := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if ps == null or ps.bg_color != UITheme.PANEL_BG or ps.border_color != UITheme.BORDER or ps.border_width_top != 1 \
			or ps.corner_radius_top_left != 14 or ps.shadow_size != 22 or panel.get_child_count() != 1 \
			or not panel.get_child(0) is ColorRect:
		return "fallback panel is not the flat panel with its accent line"
	var card := UITheme.card(root, UITheme.GOLD, 4)
	var cs := card.get_theme_stylebox("panel") as StyleBoxFlat
	if cs == null or cs.border_color != Color(UITheme.GOLD, 0.46) or cs.border_width_left != 3 or cs.border_width_top != 1 \
			or _margins(cs) != [6.0, 2.0, 4.0, 2.0]:
		return "fallback card lost its accent edge or compact padding"
	for active in [false, true]:
		var button := Button.new()
		root.add_child(button)
		UITheme.tab(button, active, UITheme.GOLD)
		var ts := button.get_theme_stylebox("normal") as StyleBoxFlat
		if ts == null or _margins(ts) != [13.0, 6.0, 13.0, 6.0] or ts.border_width_bottom != (3 if active else 1):
			return "fallback tab is not the flat tab"
	var rule := UITheme.rule(root)
	if not rule is TextureRect or not rule.texture is GradientTexture2D or rule.custom_minimum_size.y != 2:
		return "fallback divider is not the gradient rule"
	var header := UITheme.header_rule(root)
	if not header is TextureRect or not header.texture is GradientTexture2D or header.custom_minimum_size.y != 2:
		return "fallback shell header is not the gradient rule"
	UITheme.apply(root)
	var t: Theme = root.theme
	for spec in [["Button", "normal"], ["Button", "hover"], ["Button", "pressed"], ["Button", "disabled"],
			["LineEdit", "normal"], ["HSlider", "slider"], ["VScrollBar", "grabber"]]:
		if not t.get_stylebox(spec[1], spec[0]) is StyleBoxFlat: return "fallback widget is not flat: " + str(spec)
	if _margins(t.get_stylebox("normal", "Button")) != [12.0, 6.0, 12.0, 6.0]: return "fallback button padding changed"
	if _margins(t.get_stylebox("normal", "LineEdit")) != [12.0, 8.0, 12.0, 8.0]: return "fallback field padding changed"
	var slot := UITheme.slot_style(Items.GRADE_COLOR["C"]) as StyleBoxFlat
	if slot == null or slot.border_color != Items.GRADE_COLOR["C"] or slot.border_width_left != 2:
		return "fallback slot is not a flat grade border"
	var col := VBoxContainer.new()
	root.add_child(col)
	UICodex._sec = ""
	var rail := UICodex._rail_button(g.menus, col, {"id": "frame_probe", "name": "Curiosities"})
	var rs := rail.get_theme_stylebox("normal") as StyleBoxFlat
	if rs == null or rs.bg_color.a != 0.0 or rs.border_width_left != 3 or _margins(rs) != [9.0, 2.0, 34.0, 2.0] \
			or rail.custom_minimum_size.y != (28 if g.touch_mode else 25):
		return "fallback codex rail is not the slim transparent rail"
	var chip := UICodex._chip(g.menus, col, "Weapons", true, UITheme.GOLD, func() -> void: pass)
	if _margins(chip.get_theme_stylebox("normal")) != [9.0, 3.0, 9.0, 3.0]: return "fallback codex chip padding changed"
	await g.get_tree().process_frame
	return ""
