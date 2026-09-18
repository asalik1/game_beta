extends RefCounted
## Candidate only: title Settings fixture, real Tab/Enter/wheel/click/tap.
## Native pointer entry and one unchanged slider endpoint click seed keyboard focus.
## Initial focus acquisition is setup, not a claimed keyboard-only entry behavior.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const TOGGLES := {"Hit-stop": "hit_stop", "Combat framing": "combat_framing", "Damage bearings": "damage_bearings", "Target visibility": "combat_foliage", "HUD visibility": "hud_clearance"}
var r: ShotRig
var g: Game
var m: Menus
var native := Native.new()
var focus_metrics := {} # Optional capture witnesses; default episode does not read/write this.

static func run(rig: ShotRig) -> Dictionary:
	var q := new()
	q.r = rig
	q.g = rig.game
	q.m = q.g.menus
	q.native.r = rig
	q.native.g = q.g
	q.native.m = q.m
	if not q.native._check("setup/isolated_title", q.g.no_saves and not q.g.net_online() and not q.g.play_started
			and DisplayServer.get_name() != "headless", "fresh title fixture; no character or resource loans; host-rendered input"):
		return q.native._report()
	var settings: Dictionary = q.g.settings.duplicate(true)
	var binds: Dictionary = q.g.binds.duplicate(true)
	var language := Loc.lang
	var mouse_emulation := Input.emulate_mouse_from_touch
	var touch_emulation := Input.emulate_touch_from_mouse
	Loc.lang = "en"
	var error := await q._run()
	q.native._check("runtime/completed", error.is_empty(), error)
	q.native._check("cleanup/binds", q.g.binds == binds, "checked before cleanup; no binding loans")
	q.m.close()
	q.g.request_pause(false)
	q.g.settings = settings.duplicate(true)
	Loc.lang = language
	Input.emulate_mouse_from_touch = mouse_emulation
	Input.emulate_touch_from_mouse = touch_emulation
	q.g.refresh_touch_mode()
	q.g._apply_touch_mode()
	await rig.frames(3)
	q.native._check("cleanup/settings", q.g.settings == settings, "fixture preferences restored after all per-case observations")
	q.native._check("cleanup/menu", not q.m.is_open() and not rig.get_tree().paused, q.m.current)
	q.native._check("input/released", not Input.is_key_pressed(KEY_TAB) and not Input.is_key_pressed(KEY_ENTER)
		and not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "all native edges released")
	return q.native._report()

func _run() -> String:
	for mode in ["keyboard", "mouse", "touch"]:
		_mode(mode == "touch")
		var error := await _case(mode, "HUD visibility", true)
		if not error.is_empty(): return error
	_mode(false)
	return await _case("upper_mouse", "Hit-stop", false)

func _mode(touch: bool) -> void:
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = touch
	g.settings["touch_controls"] = touch
	g.refresh_touch_mode()
	g._apply_touch_mode()

func _open() -> String:
	m.open_settings("title") # Controlled reader construction; entry uses actual input.
	await r.frames(3)
	var entry := native._find_button(m.root, "Combat & comfort")
	if entry == null or not await _wheel_to(entry) or not _visible(entry):
		return "Settings entry was not reachable with native pointer navigation"
	await native._mouse(entry.get_global_rect().get_center())
	await r.frames(3)
	if m.current != "comfort" or m.settings_return != "title": return "Comfort entry did not open"
	return ""

func _case(mode: String, caption: String, capture: bool) -> String:
	r.step("comfort retention " + mode)
	var initial: Dictionary = g.settings.duplicate(true)
	var error := await _open()
	if not error.is_empty(): return error
	var target := native._find_button(m.root, caption + ":")
	if target == null: return "Missing toggle: " + caption
	var reached := false
	if mode == "keyboard":
		error = await _seed_keyboard()
		if not error.is_empty(): return error
		var taps_before: int = native.key_taps
		reached = await _focus(target)
		reached = reached and native.key_taps > taps_before
	else: reached = await _wheel_to(target)
	if not native._check(mode + "/reachable", reached and _visible(target), _state(caption)):
		return "Native navigation could not reveal " + caption
	if not native._check(mode + "/navigation_preserved", g.settings == initial, {"before": initial, "after": g.settings.duplicate(true)}):
		return "Navigation changed a setting before the tested activation"
	for title in TOGGLES:
		var button := native._find_button(m.root, String(title) + ":")
		var text := "%s: %s" % [title, "ON" if bool(g.settings[TOGGLES[title]]) else "OFF"]
		native._check(mode + "/label/" + String(TOGGLES[title]), button != null and button.text == text
			and button.size.y >= 43.5 and not button.tooltip_text.is_empty()
			and button.get_theme_color("font_color") == UITheme.GOLD_BRIGHT, text)
	var point := target.get_global_rect().get_center() # Fixed for BOTH pointer activations.
	var before := _state(caption)
	if not native._check(mode + "/scroll_setup", int(before.scroll) > 0 if capture else int(before.scroll) == 0, before):
		return "Required native scroll state was not reached: " + mode
	if capture and r.flag("button-focus-visibility"):
		await _focus_capture(mode, "before", caption)
	if capture: await native._capture(mode + "_before")
	var key: String = TOGGLES[caption]
	var expected: Dictionary = initial.duplicate(true)
	expected[key] = not bool(initial[key])
	await _activate(mode, point)
	var first := _state(caption) # Reacquire current root; old controls may be freed.
	native._check(mode + "/first_exact", g.settings == expected, {"expected": expected, "observed": first})
	native._check(mode + "/first_label", String(first.label) == "%s: %s" % [caption, "ON" if bool(expected[key]) else "OFF"], first)
	native._check(mode + "/first_view", _stable(before, first), {"before": before, "after": first})
	if mode == "keyboard": native._check(mode + "/first_focus", bool(first.focused), first)
	# No focus, reveal or point repair occurs between these two activations.
	await _activate(mode, point)
	var second := _state(caption)
	native._check(mode + "/repeat_exact", g.settings == initial, {"expected": initial, "observed": second})
	native._check(mode + "/repeat_label", second.label == before.label, second)
	native._check(mode + "/repeat_view", _stable(before, second), {"before": before, "after": second})
	if mode == "keyboard": native._check(mode + "/repeat_focus", bool(second.focused), second)
	if capture and r.flag("button-focus-visibility"):
		await _focus_capture(mode, "after_repeat", caption)
	if capture: await native._capture(mode + "_after_repeat")
	await native._key(KEY_ESCAPE)
	native._check(mode + "/escape_footer", m.current == "settings" and m.settings_return == "title", m.current)
	# Baseline wrong-row side effects remain in the checks/receipt above. Reset
	# only this disposable case's preferences before constructing its successor.
	g.settings = initial.duplicate(true)
	return ""

func _seed_keyboard() -> String:
	# The fresh title fixture starts at the authored maximum. Clicking the
	# slider's right endpoint seeds real GUI focus without changing that value.
	# This happens ONCE before Tab traversal, never between tested activations.
	var slider := m.root.find_child("camera_shake", true, false) as HSlider
	var before: Dictionary = g.settings.duplicate(true)
	var ready: bool = slider != null and _visible(slider)
	if ready:
		ready = slider.min_value == 0.0 and slider.max_value == 1.0 and slider.value == 1.0 \
			and float(before.get("camera_shake", -1.0)) == 1.0
	if not native._check("keyboard/seed_prerequisite", ready, {"camera_shake": before.get("camera_shake"), "fresh_max_endpoint": true}):
		return "Fresh camera-shake endpoint is not available for native focus setup"
	var rect := slider.get_global_rect()
	var point := Vector2(rect.end.x - 1.0, rect.get_center().y)
	await native._mouse(point)
	var focused: bool = is_instance_valid(slider) and slider.has_focus() \
		and m.get_viewport().gui_get_focus_owner() == slider
	var preserved: bool = g.settings == before
	native._check("keyboard/seed_focus", focused, {"point": [point.x, point.y], "slider": "camera_shake", "menu": m.current})
	native._check("keyboard/seed_preserved", preserved, {"before": before, "after": g.settings.duplicate(true)})
	if not focused or not preserved: return "Native focus setup did not retain unchanged slider/settings"
	return ""

func _activate(mode: String, point: Vector2) -> void:
	if mode == "keyboard": await native._key(KEY_ENTER)
	elif mode == "touch": await native._touch(point)
	else: await native._mouse(point)
	await r.frames(3)

func _focus(target: Control) -> bool:
	for attempt in 24:
		if target.has_focus():
			await r.frames(3)
			return true
		await native._key(KEY_TAB)
	return target.has_focus()

func _wheel_to(target: Control) -> bool:
	for attempt in 24:
		if _visible(target): return true
		var scroll := m.root.find_child("SettingsContentScroll", true, false) as ScrollContainer
		if scroll == null: return false
		var rect := scroll.get_global_rect()
		var direction := MOUSE_BUTTON_WHEEL_DOWN if target.get_global_rect().get_center().y > rect.get_center().y else MOUSE_BUTTON_WHEEL_UP
		await native._wheel(direction, Vector2(rect.end.x - 3.0, rect.get_center().y))
	return _visible(target)

func _visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var rect := control.get_global_rect()
	var visible := rect.intersection(m.get_viewport().get_visible_rect()).intersection(m._shell_rect)
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is Control and ancestor.clip_contents: visible = visible.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return visible.has_area() and visible.grow(0.5).encloses(rect)

func _state(caption: String) -> Dictionary:
	var target := native._find_button(m.root, caption + ":")
	var scroll: ScrollContainer = null
	if is_instance_valid(m.root): scroll = m.root.find_child("SettingsContentScroll", true, false) as ScrollContainer
	var result := {"settings": g.settings.duplicate(true), "menu": m.current, "present": target != null,
		"label": "", "focused": false, "visible": false, "rect": [], "scroll": -1}
	if scroll != null: result.scroll = scroll.scroll_vertical
	if target != null:
		var rect := target.get_global_rect()
		result.label = target.text
		result.focused = target.has_focus()
		result.visible = _visible(target)
		result.rect = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return result

func _stable(before: Dictionary, after: Dictionary) -> bool:
	if not bool(after.visible) or after.scroll != before.scroll or after.rect.size() != 4: return false
	for i in 4:
		if absf(float(after.rect[i]) - float(before.rect[i])) > 0.5: return false
	return true


## Optional focused-style evidence layered on the existing six original captures.
## No clicks, focus repair, setting writes, or reveal repair are added here.
func _focus_capture(mode: String, stage: String, caption: String) -> void:
	var target: Button = native._find_button(m.root, caption + ":")
	var prefix := "focus/" + mode + "/" + stage
	if target == null:
		native._check(prefix + "/target", false, "Existing capture target disappeared")
		return
	if mode == "keyboard":
		var prior_owner: Control = m.get_viewport().gui_get_focus_owner()
		# Disclosed mouse-only motion to the title lane removes hover ambiguity.
		var point: Vector2 = m._shell_rect.position + Vector2(m._shell_rect.size.x * 0.5, 24.0)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await r.frames(3)
		var owner: Control = m.get_viewport().gui_get_focus_owner()
		var mouse: Vector2 = target.get_global_mouse_position()
		native._check(prefix + "/owner", prior_owner == target and owner == target and target.has_focus(),
			{"target": str(target.get_path()), "owner": str(owner.get_path()) if owner != null else "", "preserved": prior_owner == owner})
		native._check(prefix + "/nonhover", m._shell_rect.has_point(point)
			and not target.get_global_rect().has_point(mouse) and not target.is_hovered(),
			{"requested_title_motion": [point.x, point.y], "mouse": [mouse.x, mouse.y], "hovered": target.is_hovered()})
		native._check(prefix + "/visible", _visible(target), _state(caption))
		var style: StyleBox = target.get_theme_stylebox("focus")
		var flat := style as StyleBoxFlat
		var normal := target.get_theme_stylebox("normal") as StyleBoxFlat
		var outline_ok := flat != null and normal != null
		if outline_ok:
			outline_ok = not flat.draw_center and flat.border_color == UITheme.GOLD_BRIGHT
			outline_ok = outline_ok and [flat.border_width_left, flat.border_width_top, flat.border_width_right, flat.border_width_bottom] == [2, 2, 2, 2]
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				outline_ok = outline_ok and flat.get_content_margin(side) == 0.0
			outline_ok = outline_ok and [flat.corner_radius_top_left, flat.corner_radius_top_right, flat.corner_radius_bottom_left, flat.corner_radius_bottom_right] == [normal.corner_radius_top_left, normal.corner_radius_top_right, normal.corner_radius_bottom_left, normal.corner_radius_bottom_right]
			outline_ok = outline_ok and flat.get_minimum_size() == Vector2.ZERO
		native._check(prefix + "/outline", outline_ok, _style_metrics(style))
	var metrics := {}
	for title: String in TOGGLES:
		var button: Button = native._find_button(m.root, title + ":")
		if button == null: continue
		metrics[title] = _button_metrics(button)
	var coherent: bool = metrics.size() == TOGGLES.size()
	if stage == "before":
		focus_metrics[mode] = metrics.duplicate(true)
	else:
		coherent = coherent and focus_metrics.has(mode) and metrics == focus_metrics[mode]
	native._check(prefix + "/metrics", coherent,
		{"buttons": metrics, "same_as_before": stage == "before" or metrics == focus_metrics.get(mode, {}),
		"scope": "Actual layout and resolved non-focus style metrics; cross-run baseline/fixed comparison still required."})

func _button_metrics(button: Button) -> Dictionary:
	var rect: Rect2 = button.get_global_rect()
	var font: Font = button.get_theme_font("font")
	var styles := {}
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		styles[state] = _style_metrics(button.get_theme_stylebox(state))
	var colors := {}
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_outline_color"]:
		colors[state] = _focus_plain(button.get_theme_color(state))
	return {"text": button.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"minimum": _focus_plain(button.get_minimum_size()), "combined_minimum": _focus_plain(button.get_combined_minimum_size()),
		"custom_minimum": _focus_plain(button.custom_minimum_size), "font_path": font.resource_path,
		"font_class": font.get_class(), "font_size": button.get_theme_font_size("font_size"), "colors": colors,
		"styles": styles, "clip_text": button.clip_text, "text_overrun": button.text_overrun_behavior,
		"alignment": button.alignment, "focus_mode": button.focus_mode, "disabled": button.disabled,
		"icon_path": button.icon.resource_path if button.icon != null else "", "visible": _visible(button)}

func _style_metrics(style: StyleBox) -> Dictionary:
	var values := {"class": style.get_class(), "minimum": _focus_plain(style.get_minimum_size()), "content_margins": []}
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		values.content_margins.append(style.get_content_margin(side))
	if style is StyleBoxFlat:
		for key: String in ["bg_color", "border_color", "draw_center", "border_blend", "anti_aliasing", "anti_aliasing_size",
			"border_width_left", "border_width_top", "border_width_right", "border_width_bottom",
			"corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right",
			"expand_margin_left", "expand_margin_top", "expand_margin_right", "expand_margin_bottom",
			"shadow_color", "shadow_size", "shadow_offset", "skew", "corner_detail"]:
			values[key] = _focus_plain(style.get(key))
	return values

func _focus_plain(value: Variant) -> Variant:
	if value is Color: return [value.r, value.g, value.b, value.a]
	if value is Vector2: return [value.x, value.y]
	return value
