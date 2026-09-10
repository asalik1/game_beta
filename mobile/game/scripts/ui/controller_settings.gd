extends RefCounted
## Illustrated, live control reference. Vector artwork stays crisp at UI scale.


static func open(m: Menus) -> void:
	var box := m._open("Controller", 940, 650, true)
	m.current = "controller"
	var body := m._settings_body(box)
	var status := m._lbl(body, "Press a button or tilt a stick to check your controller.", 14, UITheme.TEXT_MUTED)
	var diagram := Control.new()
	diagram.custom_minimum_size = Vector2(820, 238)
	body.add_child(diagram)
	diagram.draw.connect(func() -> void: _draw(diagram, m.game))
	var pulse := Timer.new()
	pulse.wait_time = 0.1
	pulse.autostart = true
	diagram.add_child(pulse)
	pulse.timeout.connect(func() -> void:
		var pad: Node = m.game.gamepad
		var device_name := Input.get_joy_name(pad.device) if pad.device >= 0 else ""
		status.text = (device_name if device_name != "" else "Controller input active") if pad.device >= 0 else "Connect a controller, then press any button. Keyboard and touch stay available."
		diagram.queue_redraw())
	for spec in [["Stick deadzone", "pad_deadzone", Balance.PAD_DEADZONE_MIN, Balance.PAD_DEADZONE_MAX],
		["Menu cursor speed", "pad_cursor_speed", 0.0, 1.0]]:
		var key: String = spec[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		m._lbl(row, spec[0], 16).custom_minimum_size.x = 195
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = float(spec[2])
		slider.max_value = float(spec[3])
		slider.step = 0.01
		slider.value = float(m.game.settings[key])
		slider.custom_minimum_size = Vector2(450, 32)
		row.add_child(slider)
		var value := m._lbl(row, "%d%%" % roundi(slider.value * 100), 16, UITheme.GOLD_BRIGHT)
		value.custom_minimum_size.x = 60
		slider.value_changed.connect(func(v: float) -> void:
			m.game.settings[key] = v
			value.text = "%d%%" % roundi(v * 100)
			m.game.save_settings())
	m._btn(body, "Button labels: %s" % String(m.game.settings.pad_labels).capitalize(), func() -> void:
		var schemes := ["auto", "xbox", "playstation"]
		m.game.settings.pad_labels = schemes[(schemes.find(m.game.settings.pad_labels) + 1) % schemes.size()]
		m.game.save_settings()
		open(m))
	m._lbl(body, "In menus: left stick moves the cursor; D-pad snaps; hold Confirm to drag; right stick scrolls. Focus a text field and press %s for the on-screen keyboard." % m.game.gamepad.label("potion"), 14, UITheme.TEXT_MUTED)
	m._lbl(body, "Right-stick flicks select a target in that direction. Release the stick before the next flick. Releasing the lock restores automatic targeting.", 14, UITheme.TEXT_MUTED)
	m._btn(box, "Back to settings", func() -> void: m.open_settings(m.settings_return))
	m._hint(box, "ESC to return to settings")
	m._settings_touch_targets(box)


static func _draw(c: Control, g: Game) -> void:
	var pad: Node = g.gamepad
	var font := ThemeDB.fallback_font
	var gold := Color(0.91, 0.79, 0.48)
	var ink := Color(0.075, 0.105, 0.13)
	var body := PackedVector2Array([Vector2(333, 55), Vector2(480, 55), Vector2(523, 90), Vector2(548, 180), Vector2(525, 206), Vector2(485, 159), Vector2(330, 159), Vector2(289, 206), Vector2(266, 180), Vector2(292, 90)])
	c.draw_colored_polygon(body, ink)
	var rim := body.duplicate()
	rim.append(body[0])
	c.draw_polyline(rim, Color(gold, 0.55), 2, true)
	for spec in [["ult", Vector2(302, 28), "left"], ["a2", Vector2(352, 5), "left"], ["a1", Vector2(435, 5), "right"], ["a3", Vector2(485, 28), "right"]]:
		var slot: String = spec[0]
		var pos: Vector2 = spec[1]
		var color := Color(0.49, 0.93, 0.78) if pad.held(slot) else gold
		c.draw_style_box(_box(ink, color), Rect2(pos, Vector2(38, 24)))
		c.draw_string(font, pos + Vector2(8, 17), pad.label(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		var ability: String = Classes.CLASSES[g.local_player.cls].abilities[slot].name if g.local_player != null else slot
		var x := 14.0 if spec[2] == "left" else 568.0
		var y := 24.0 if slot in ["a1", "a2"] else 55.0
		c.draw_string(font, Vector2(x, y), "%s  •  %s" % [pad.label(slot), ability], HORIZONTAL_ALIGNMENT_LEFT, 245, 16, color)
	for spec in [[Vector2(333, 101), false], [Vector2(449, 136), true]]:
		var pos: Vector2 = spec[0]
		c.draw_circle(pos, 25, Color(0.16, 0.21, 0.24))
		c.draw_arc(pos, 25, 0, TAU, 40, Color(gold, 0.65), 1.5, true)
		c.draw_circle(pos + pad.stick(spec[1]) * 10, 14, Color(0.38, 0.55, 0.55))
	for spec in [["interact", Vector2(493, 111)], ["cancel", Vector2(517, 87)], ["potion", Vector2(469, 87)], ["potion_next", Vector2(493, 63)]]:
		c.draw_circle(spec[1], 10, Color(0.2, 0.29, 0.3))
		c.draw_string(font, spec[1] + Vector2(-5, 5), pad.label(spec[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)
	c.draw_rect(Rect2(361, 118, 14, 44), Color(0.3, 0.4, 0.42))
	c.draw_rect(Rect2(346, 133, 44, 14), Color(0.3, 0.4, 0.42))
	for spec in [[Vector2(14, 102), "Left stick   Move / walk"], [Vector2(14, 136), "D-pad   Map / bag / skills / codex"], [Vector2(14, 170), "R3   Lock / cycle target"], [Vector2(568, 102), "%s   Interact / confirm" % pad.label("interact")], [Vector2(568, 136), "%s   Potion     %s   Next potion" % [pad.label("potion"), pad.label("potion_next")]], [Vector2(568, 170), "%s   Release lock / back" % pad.label("cancel")]]:
		c.draw_string(font, spec[0], spec[1], HORIZONTAL_ALIGNMENT_LEFT, 255, 15, Color(0.78, 0.84, 0.85))
	c.draw_string(font, Vector2(350, 228), "%s  •  Pause" % pad.label("pause"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)


static func _box(fill: Color, rim: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
