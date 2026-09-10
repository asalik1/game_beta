extends RefCounted
## Focused Settings geometry/input proof, composed with the existing menu probe.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")

var r: ShotRig
var g: Game
var m: Menus
var native: NativeInput


static func run(rig: ShotRig) -> Dictionary:
	var proof := new()
	proof.r = rig
	proof.g = rig.game
	proof.m = rig.game.menus
	proof.native = NativeInput.new()
	proof.native.r = rig
	proof.native.g = proof.g
	proof.native.m = proof.m
	var saved_settings: Dictionary = proof.g.settings.duplicate(true)
	var saved_binds: Dictionary = proof.g.binds.duplicate(true)
	var saved_language := Loc.lang
	var saved_emulation := Input.emulate_mouse_from_touch
	var saved_touch_emulation := Input.emulate_touch_from_mouse
	Input.emulate_mouse_from_touch = true
	Loc.lang = "en"
	var error: String = await proof._run()
	proof.native._check("settings_touch.completed", error == "", error)
	proof.native._check("settings_touch.binds_preserved", proof.g.binds == saved_binds, "capture was cancelled, never committed")
	proof.m.listening_action = ""
	proof.m.close()
	proof.g.settings = saved_settings
	proof.g.binds = saved_binds
	proof.g.apply_audio_settings()
	Loc.lang = saved_language
	Input.emulate_mouse_from_touch = saved_emulation
	Input.emulate_touch_from_mouse = saved_touch_emulation
	proof.g.refresh_touch_mode()
	proof.g._apply_touch_mode()
	await rig.frames(3)
	proof.native._check("settings_touch.input_released", not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "synthetic inputs released")
	return proof.native._report()


func _run() -> String:
	if not native._check("settings_touch.isolated", g.no_saves and not g.net_online(), "ShotRig solo fixture; isolated APPDATA required"):
		return "requires isolated solo Game"
	_mode(false)
	m.open_settings("title")
	await r.frames(3)
	await _measure("desktop.settings", false, 8 if OS.has_feature("mobile") else 9)
	await native._capture("settings_touch_00_desktop")
	m.open_keybinds()
	await r.frames(3)
	await _measure("desktop.keybinds", false, 13)
	_top()
	await native._capture("settings_touch_01_desktop_keybinds")
	if r.flag("desktop-comfort"):
		m.open_settings("title")
		await r.frames(3)
		if not await native._button("Combat & comfort"):
			return "desktop Comfort entry unavailable"
		if not native._check("desktop.comfort.open", not g.touch_mode and m.current == "comfort", m.current):
			return "desktop Comfort did not open"
		await _measure("desktop.comfort", false, 9)
		await native._capture("settings_touch_01b_desktop_comfort")
		if not await native._button("Back to settings"):
			return "desktop Comfort Back unavailable"
		native._check("desktop.comfort.back", m.current == "settings" and m.settings_return == "title", m.current)
	var capability_before := DisplayServer.is_touchscreen_available()
	var touch_emulation_before := Input.emulate_touch_from_mouse
	_mode(true)
	if not native._check("settings_touch.touch_capability", DisplayServer.is_touchscreen_available() and Input.emulate_mouse_from_touch and Input.emulate_touch_from_mouse,
		{"before_available": capability_before, "before_touch_from_mouse": touch_emulation_before, "after_available": DisplayServer.is_touchscreen_available(), "mouse_from_touch": Input.emulate_mouse_from_touch, "touch_from_mouse": Input.emulate_touch_from_mouse, "fixture": "desktop touch-capability emulation; not a physical touchscreen"}):
		return "touch ScrollContainer capability unavailable"
	# Only the music value is loaned for the target-edge input check.
	g.settings["music"] = 0.2
	m.open_settings("title")
	await r.frames(3)
	await _measure("touch.settings", true, 10 if OS.has_feature("mobile") else 11)
	_top()
	await native._capture("settings_touch_02_settings_top")
	var sliders := _sliders(m.root)
	if not native._check("touch.music_present", sliders.size() == 3, sliders.size()):
		return "expected music, SFX and joystick sliders"
	var music: HSlider = sliders[0]
	await _reveal(music)
	var music_rect := music.get_global_rect()
	# The point is inside a44px target and outside the old24px target.
	await native._touch(Vector2(music_rect.get_center().x, music_rect.get_center().y + 18.0))
	await r.frames(2)
	native._probe("touch.music_edge_input", is_equal_approx(float(g.settings.music), 0.5),
		{"value": g.settings.music, "rect": str(music_rect), "offset_y": 18.0})
	# Normalize the intentional slider edit before asserting scrolling/navigation
	# preservation. A baseline miss remains recorded above.
	g.settings["music"] = 0.2
	m.open_settings("title")
	await r.frames(3)
	var navigation_settings: Dictionary = g.settings.duplicate(true)
	await _drag_body("settings")
	_bottom()
	await native._capture("settings_touch_03_settings_bottom")
	for spec in [["Combat & comfort", "comfort", 9], ["Controller", "controller", 4]]:
		if not await _tap(String(spec[0])):
			return "touch child entry unavailable: " + String(spec[0])
		if not native._check("touch.opens." + String(spec[1]), m.current == spec[1], m.current):
			return "touch entry did not open its child"
		await _measure("touch." + String(spec[1]), true, int(spec[2]))
		await _drag_body(String(spec[1]))
		_bottom()
		await native._capture("settings_touch_04_" + String(spec[1]) + "_bottom")
		if not await _tap("Back to settings"):
			return "child Back unavailable"
		native._check("touch.back." + String(spec[1]), m.current == "settings" and m.settings_return == "title", m.current)
	# Touch Settings deliberately hides the keyboard entry. Direct opening here
	# is a layout fixture for an attached keyboard, not a new navigation claim.
	m.open_keybinds()
	await r.frames(3)
	await _measure("touch.keybinds", true, 13)
	_top()
	await native._capture("settings_touch_05_keybinds_top")
	await _drag_body("keybinds")
	_bottom()
	await native._capture("settings_touch_06_keybinds_bottom")
	if not await _tap("Switch target lock"):
		return "last keybind row unavailable"
	native._check("touch.last_binding_capture", m.listening_action == "target", m.listening_action)
	var listening := native._find_button(m.root, "Switch target lock")
	var capture_scroll := _scroll()
	var capture_visible := listening != null and capture_scroll != null \
		and capture_scroll.get_global_rect().grow(0.75).encloses(listening.get_global_rect())
	native._probe("touch.last_binding_capture_visible", capture_visible, "the selected last row must remain visible while listening")
	await native._key(KEY_ESCAPE)
	native._check("touch.capture_escape", m.current == "keybinds" and m.listening_action == "", m.current)
	if not await _tap("Back to settings"):
		return "keybind Back unavailable"
	native._check("touch.keybind_back", m.current == "settings" and m.settings_return == "title", m.current)
	if not await _tap("Back", true):
		return "Settings Back unavailable"
	native._check("touch.settings_back_roster", m.current == "title" and m.title_stage == "slots", m.current)
	native._check("touch.navigation_settings_preserved", g.settings == navigation_settings, "touch scrolls and navigation did not toggle or slide a setting")
	return ""


func _mode(touch: bool) -> void:
	if touch:
		# Godot's desktop ScrollContainer drag capability uses the opposite
		# emulation flag as well as the touch-to-mouse events sent by this rig.
		Input.emulate_mouse_from_touch = true
		Input.emulate_touch_from_mouse = true
	g.settings["touch_controls"] = touch
	g.refresh_touch_mode()
	g._apply_touch_mode()


func _measure(id: String, touch: bool, expected: int) -> void:
	r.step(id + " active content targets, captions and clip bounds")
	var controls: Array[Control] = []
	_collect(m.root, controls)
	var target_count := 0
	for i in controls.size():
		var control := controls[i]
		await _reveal(control)
		var rect := control.get_global_rect()
		var visible := rect.intersection(m.get_viewport().get_visible_rect()).intersection(m._shell_rect)
		var ancestor := control.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				visible = visible.intersection(ancestor.get_global_rect())
			if ancestor == m.root:
				break
			ancestor = ancestor.get_parent()
		var text := String(control.text) if control is Button or control is Label else String(control.name)
		var actual := {"text": text, "rect": str(rect), "visible": str(visible)}
		var label := id + ".%d" % i
		var contained := visible.has_area() and visible.grow(0.75).encloses(rect)
		# Only the existing Comfort footer hint is an expected desktop
		# overflow; all other desktop containment remains strict.
		if touch or (id == "desktop.comfort" and text == "ESC to return to settings"):
			native._probe(label + ".contained", contained, actual)
		else:
			native._check(label + ".contained", contained, actual)
		if control is Button or control is HSlider:
			target_count += 1
			if touch:
				native._probe(label + ".target44", rect.size.x >= 43.5 and rect.size.y >= 43.5, actual)
		if control is Button:
			var style := control.get_theme_stylebox("normal")
			var room := control.size - style.get_minimum_size()
			var text_size := control.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size"))
			native._check(label + ".caption", text_size.x <= room.x + 1.0 and text_size.y <= room.y + 1.0, actual)
	native._check(id + ".required_targets", target_count == expected, {"expected": expected, "actual": target_count})


func _collect(node: Node, controls: Array[Control]) -> void:
	# Shared shell X is separately owned and tested by the Alchemy integration.
	# Scrollbars are not content targets; this proof uses the full-body drag path.
	if node is Control and node.is_visible_in_tree() and (node is Button or node is HSlider or node is Label):
		if not (node is Button and (node.text == "✕" or node.disabled)):
			controls.append(node)
	for child in node.get_children():
		_collect(child, controls)


func _scroll() -> ScrollContainer:
	for node in m.root.find_children("*", "ScrollContainer", true, false):
		return node
	return null


func _sliders(node: Node) -> Array[HSlider]:
	var result: Array[HSlider] = []
	for child in node.find_children("*", "HSlider", true, false):
		result.append(child)
	return result


func _reveal(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await r.frames(1)
		ancestor = ancestor.get_parent()


func _top() -> void:
	var scroll := _scroll()
	if scroll != null:
		scroll.scroll_vertical = 0


func _bottom() -> void:
	var scroll := _scroll()
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _drag_body(id: String) -> void:
	var scroll := _scroll()
	if scroll == null:
		native._probe("touch.drag_body." + id, false, "no body scroll exists in this baseline panel")
		return
	scroll.scroll_vertical = 0
	await r.frames(3)
	var needed := scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 1.0
	if not needed:
		native._check("touch.drag_body." + id, true, "all body content fits; scrolling is unnecessary")
		return
	var trace := {"started": 0, "values": [], "available": DisplayServer.is_touchscreen_available(), "max": scroll.get_v_scroll_bar().max_value, "page": scroll.get_v_scroll_bar().page}
	var on_started := func() -> void: trace.started += 1
	scroll.scroll_started.connect(on_started)
	var rect := scroll.get_global_rect()
	trace["rect"] = str(rect)
	var start := Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.75)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = start
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await r.frames(1)
	var at := start
	for i in 6:
		var next := start - Vector2(0, (i + 1) * 24.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = next
		drag.relative = next - at
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		at = next
		await r.frames(1)
		trace["values"].append(scroll.scroll_vertical)
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await r.frames(3)
	scroll.scroll_started.disconnect(on_started)
	trace["scroll"] = scroll.scroll_vertical
	trace["input"] = "one native ScreenTouch/ScreenDrag/release gesture"
	native._check("touch.drag_body." + id, scroll.scroll_vertical > 0, trace)


func _tap(label: String, exact := false) -> bool:
	var button := native._find_button(m.root, label, exact)
	if not native._check("touch.button." + label, button != null, label):
		return false
	await _reveal(button)
	await native._touch(button.get_global_rect().get_center())
	await r.frames(3)
	return true
