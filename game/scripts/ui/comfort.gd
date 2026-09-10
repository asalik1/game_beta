extends RefCounted


static func open(m: Menus) -> void:
	var box := m._open("Combat & comfort", 800, 660, true)
	m.current = "comfort"
	# The full feedback list also exceeds the desktop shell's content height.
	var body := m._settings_body(box, true)
	m._lbl(body, "Tune the feedback to suit you. Changes take effect immediately.", 16, UITheme.TEXT_MUTED)
	for spec in [["Camera shake", "camera_shake", "Impact shake and directional kicks."],
		["Camera lead", "camera_lead", "How far the camera looks ahead of your movement."],
		["Impact flashes", "impact_flashes", "Full-screen colour and splash washes from hits and abilities."]]:
		var key := String(spec[1])
		UITheme.rule(body)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var title := m._lbl(row, String(spec[0]), 17)
		title.custom_minimum_size.x = 180
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = float(m.game.settings[key])
		slider.custom_minimum_size = Vector2(330, 34)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var value := m._lbl(row, "%d%%" % roundi(slider.value * 100), 17, UITheme.GOLD_BRIGHT)
		value.custom_minimum_size.x = 74
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		slider.value_changed.connect(func(v: float) -> void:
			m.game.settings[key] = v
			value.text = "%d%%" % roundi(v * 100)
			m.game.save_settings())
		m._lbl(body, String(spec[2]), 13, UITheme.TEXT_MUTED)
	UITheme.rule(body)
	for spec in [["Hit-stop", "hit_stop", "Brief impact pauses in solo combat."],
		["Combat framing", "combat_framing", "Ease the camera toward your target and widen the view for distant opponents."],
		["Damage bearings", "damage_bearings", "A small arc shows the direction of a landed hit."],
		["Target visibility", "combat_foliage", "Soften covering trees and trace your target behind solid props."],
		["HUD visibility", "hud_clearance", "Fade secondary information when it covers you or your target. Health and controls stay visible."]]:
		var key := String(spec[1])
		var button := m._btn(body, "%s: %s" % [spec[0], "ON" if m.game.settings[key] else "OFF"], func() -> void:
			m.game.settings[key] = not bool(m.game.settings[key])
			m.game.save_settings()
			open(m), UITheme.GOLD_BRIGHT)
		button.custom_minimum_size.y = 44
		button.tooltip_text = String(spec[2])
	m._btn(box, "Back to settings", func() -> void: m.open_settings(m.settings_return))
	m._hint(box, "ESC to return to settings")
	m._settings_touch_targets(box)
