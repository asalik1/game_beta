extends Control
## A chart you can act on: select first, inspect, then pin a route or travel.
## Native Controls keep every action keyboard-focusable and thumb-sized.

const Nav := preload("res://scripts/ui/navigation.gd")
const INK := Color(0.16, 0.20, 0.23)
const PAPER := Color(0.80, 0.86, 0.88)
const MUTED := Color(0.76, 0.80, 0.85)
const SIDE_WIDTH := 296.0

var menus: Menus
var game: Game
var chart: Control
var details: VBoxContainer
var actions: VBoxContainer
var summary: Label
var selected := -1
var _rooms: Array[int] = []
var _positions := {}
var _route: Array[int] = []
var _zoom := 1.0
var _pan := Vector2.ZERO
var _drag_start := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _dragging := false
var _moved := false
var _touch_id := -1
var _hover := -1
var _next_refresh := 0.0
var _signature := ""
var _context := ""
var _pitch := Vector2(112, 90)
var _origin := Vector2.ZERO
var _min_coord := Vector2i.ZERO
var _max_coord := Vector2i.ZERO
var _message := ""


static func open(m: Menus) -> void:
	var box := m._open("Field atlas", 1200, 660, true)
	m.current = "map"
	var atlas: Control = load("res://scripts/ui/field_atlas.gd").new()
	atlas.menus = m
	atlas.game = m.game
	atlas.name = "FieldAtlas"
	atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	atlas.custom_minimum_size = Vector2(1120, 498)
	box.add_child(atlas)
	m._hint(box, "Select a room · drag to pan · scroll to zoom · %s to return" % m.game.control_hint("map", "Map"), "Select a room · drag to pan · use + / − to zoom")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context = game.hud.wayfinder.context_key()
	selected = game.hud.wayfinder.pinned_room if game.hud.wayfinder.pinned_room >= 0 else game.cur_room
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var chapter: Dictionary = Story.chapter(game.chapter_id)
	var name_label := _label(header, String(chapter.get("name", "The journey")), 18, UITheme.GOLD_BRIGHT)
	name_label.custom_minimum_size.x = 340
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font: Font = UITheme.header_font()
	if font != null:
		name_label.add_theme_font_override("font", font)
	summary = _label(header, "", 14, PAPER)
	summary.custom_minimum_size.x = 270
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var chart_frame := PanelContainer.new()
	chart_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_frame.custom_minimum_size = Vector2(760, 442)
	chart_frame.add_theme_stylebox_override("panel", _style(INK, Color(UITheme.GOLD, 0.35)))
	body.add_child(chart_frame)
	chart = Control.new()
	chart.name = "Chart"
	chart.clip_contents = true
	chart.mouse_filter = Control.MOUSE_FILTER_STOP
	chart.mouse_default_cursor_shape = Control.CURSOR_DRAG
	chart_frame.add_child(chart)
	chart.draw.connect(_draw_chart)
	chart.gui_input.connect(_chart_input)
	chart.resized.connect(func() -> void: _layout_chart())
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(14, 12)
	toolbar.add_theme_constant_override("separation", 6)
	chart.add_child(toolbar)
	for spec in [["−", -1], ["+", 1], ["Recenter", 0]]:
		var value := int(spec[1])
		var button := menus._btn(toolbar, String(spec[0]), func() -> void:
			if value == 0:
				_zoom = 1.0
				_pan = Vector2.ZERO
				_layout_chart()
			else:
				_zoom_at(pow(Balance.ATLAS_ZOOM_STEP, value), chart.size * 0.5))
		button.custom_minimum_size = Vector2(46 if value != 0 else 100, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = "Zoom out" if value < 0 else ("Zoom in" if value > 0 else "Fit the explored map")
	var trail := menus._btn(toolbar, "Main trail", func() -> void:
		var target: int = Nav.main_trail(game)
		if target >= 0:
			select_room(target)
		else:
			_message = "Explore a new passage to chart the road ahead."
			_show_details(), UITheme.GOLD_BRIGHT)
	trail.custom_minimum_size = Vector2(112, 44)
	trail.alignment = HORIZONTAL_ALIGNMENT_CENTER
	trail.tooltip_text = "Select the next known step on the main road"
	var legend := _label(chart, "◆ You    ◇ Route    ? Unexplored    ━ Sealed", 12, PAPER)
	legend.size = Vector2(560, 22)
	legend.autowrap_mode = TextServer.AUTOWRAP_OFF
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.position = Vector2(16, -28)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(SIDE_WIDTH + 16, 442)
	sidebar.add_theme_stylebox_override("panel", _style(Color(0.18, 0.21, 0.25), Color(UITheme.GOLD, 0.32)))
	body.add_child(sidebar)
	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 18)
	sidebar.add_child(margin)
	var sidebar_column := VBoxContainer.new()
	sidebar_column.add_theme_constant_override("separation", 12)
	margin.add_child(sidebar_column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_column.add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	scroll.add_child(details)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	sidebar_column.add_child(actions)
	_refresh(true)


func _style(fill: Color, line: Color, radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb


func _label(parent: Node, text: String, fs: int, color: Color) -> Label:
	var l := menus._lbl(parent, text, fs, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = UITheme.body_font()
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _process(delta: float) -> void:
	# Menu roots fade out before being freed. An outgoing atlas must never
	# close or rebuild the new menu that has already replaced it.
	if menus.current != "map" or menus.root == null or not menus.root.is_ancestor_of(self):
		set_process(false)
		return
	_next_refresh -= delta
	if _next_refresh > 0.0:
		return
	_next_refresh = Balance.WAYFINDER_SAMPLE_SECONDS
	# A chapter switch can arrive over the network while the atlas is open.
	if _context != game.hud.wayfinder.context_key():
		menus.close()
		return
	_refresh()


func _refresh(force := false) -> void:
	var sig := "%d|%s|%s|%s|%s|%s|%d|%s" % [game.cur_room, game.visited.hash(),
		game.door_seen.hash(), game.cleared.hash(), game.boss_done.hash(), game.flags.hash(),
		game.hud.wayfinder.pinned_room, game.barrier_active]
	if sig == _signature and not force:
		return
	_signature = sig
	_rooms = Nav.chart_rooms(game)
	if not _rooms.has(selected):
		selected = game.cur_room
	var explored := 0
	var secured := 0
	for room in _rooms:
		if game.charted(room):
			explored += 1
			if game.room_pacified(room):
				secured += 1
	summary.text = "%02d CHARTED   /   %02d SECURED" % [explored, secured]
	_layout_chart()
	_show_details()


func _layout_chart() -> void:
	if chart == null or _rooms.is_empty():
		return
	_min_coord = game.rooms[_rooms[0]]["coord"]
	_max_coord = _min_coord
	for room in _rooms:
		var coord: Vector2i = game.rooms[room]["coord"]
		_min_coord = Vector2i(mini(_min_coord.x, coord.x), mini(_min_coord.y, coord.y))
		_max_coord = Vector2i(maxi(_max_coord.x, coord.x), maxi(_max_coord.y, coord.y))
	var span := Vector2(_max_coord - _min_coord) + Vector2.ONE
	var space := (chart.size - Vector2(110, 136)).max(Vector2(100, 100))
	var step := minf(124.0, minf(space.x / span.x, space.y / span.y))
	_pitch = Vector2.ONE * maxf(22.0, step) * _zoom
	var middle := Vector2(_min_coord + _max_coord) * 0.5
	_origin = chart.size * 0.5 + Vector2(0, 10) - middle * _pitch + _pan
	_positions.clear()
	for room in _rooms:
		_positions[room] = _origin + Vector2(game.rooms[room]["coord"]) * _pitch
	_update_route()
	chart.queue_redraw()


func _update_route() -> void:
	_route = Nav.route(game, game.cur_room, selected)
	if _route.is_empty():
		_route = Nav.route(game, game.cur_room, selected, true)


func select_room(room: int) -> void:
	if not _rooms.has(room):
		return
	selected = room
	_message = ""
	_update_route()
	_show_details()
	chart.queue_redraw()


func _show_details() -> void:
	for container in [details, actions]:
		for c in container.get_children():
			container.remove_child(c)
			c.queue_free()
	var charted: bool = game.charted(selected)
	var color: Color = Nav.room_color(game, selected)
	var tag := "EXPLORED TERRITORY" if charted else "AT THE EDGE OF YOUR MAP"
	_label(details, tag, 11, UITheme.GOLD_BRIGHT)
	var name_label := _label(details, Nav.room_name(game, selected), 23, Color(0.94, 0.91, 0.8))
	name_label.custom_minimum_size.x = SIDE_WIDTH - 36
	var font: Font = UITheme.header_font()
	if font != null:
		name_label.add_theme_font_override("font", font)
	var type_name := String(Nav.TYPE_NAMES.get(game.room_type(selected), "Passage")) if charted else "Beyond this doorway"
	_label(details, Nav.glyph(game, selected) + "   " + type_name, 16, color)
	UITheme.rule(details)
	if charted:
		var terrain: Dictionary = Terrains.get_terrain(game.terrain_by_zone[selected])
		_label(details, String(terrain.get("name", "The wilds")), 14, PAPER)
		var kind := String(game.zones[selected].get("boss", ""))
		if kind != "":
			var boss_name := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind.capitalize()))
			_label(details, ("Defeated · " if game.boss_done.get(kind, false) else "Guardian · ") + boss_name, 15, color)
	var service := _label(details, Nav.services(game, selected), 16, Color(0.72, 0.76, 0.79))
	service.custom_minimum_size.x = SIDE_WIDTH - 36
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	details.add_child(gap)
	_label(details, "YOUR ROUTE", 11, UITheme.GOLD_BRIGHT)
	var blocked: String = Nav.first_lock(game, _route)
	var here := selected == game.cur_room
	var message := "You are here. Select a room on the chart to plan your next move."
	if not here:
		if _route.is_empty():
			message = "No charted passage connects to this destination."
		elif blocked != "":
			message = blocked
		else:
			var hops := _route.size() - 1
			message = "%d passage%s away · %s first" % [hops, "" if hops == 1 else "s", _direction_name(Nav.direction(game, game.cur_room, _route[1]))]
			if game.barrier_active:
				message += "\nClear this encounter to follow your route."
	var route_copy := _label(details, _message if _message != "" else message, 15, MUTED)
	route_copy.custom_minimum_size.x = SIDE_WIDTH - 36
	var pinned: bool = game.hud.wayfinder.pinned_room == selected
	var pin_button := menus._btn(actions, "Remove route" if pinned else "◆  Set route", _pin_selected,
		UITheme.GOLD_BRIGHT, pinned or (not here and not _route.is_empty() and not game.pvp_active and not game.endgame_active))
	pin_button.name = "PinRoute"
	pin_button.custom_minimum_size.y = 44
	pin_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var travel_ok: bool = game.travel_target(selected) and not game.barrier_active \
		and game.state == Game.ST_PLAYING and not game.local_player.dead and not game.local_player.downed
	var travel_button := menus._btn(actions, "Travel to sanctuary" if game.room_type(selected) != "boss" else "Travel to cleared arena", _travel_selected, Nav.SAFE, travel_ok)
	travel_button.name = "Travel"
	travel_button.custom_minimum_size.y = 44
	travel_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not travel_ok and not here:
		var why := "Travel unlocks at visited sanctuaries and defeated boss arenas."
		if game.barrier_active:
			why = "Fast travel is sealed during an encounter."
		_label(details, why, 12, MUTED)
	# A single-focus button makes keyboard selection possible without needing
	# a mouse to select a hand-drawn map cell.
	var known_row := HBoxContainer.new()
	known_row.add_theme_constant_override("separation", 6)
	actions.add_child(known_row)
	for step in [-1, 1]:
		var move := int(step)
		var b := menus._btn(known_row, "‹ Previous" if move < 0 else "Next ›", func() -> void:
			var idx: int = _rooms.find(selected)
			select_room(_rooms[posmod(idx + move, _rooms.size())]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(118, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _pin_selected() -> void:
	if game.hud.wayfinder.pinned_room == selected:
		game.hud.wayfinder.track("")
		_message = "Route removed."
	elif game.hud.wayfinder.pin(selected):
		_message = "Route set. A gold bearing will guide you to the next doorway."
	else:
		_message = "This route is no longer available."
	_refresh(true)


func _travel_selected() -> void:
	# The shared world can change while this panel is open. Revalidate at use.
	if not game.travel_target(selected) or game._room_hot(game.cur_room) \
			or game.state != Game.ST_PLAYING or game.local_player.dead or game.local_player.downed:
		_message = "Travel is currently sealed. Finish the encounter first."
		_refresh(true)
		return
	var destination := selected
	menus.close()
	game.fast_travel(destination)


func _direction_name(dir: String) -> String:
	return String({"N": "north", "E": "east", "S": "south", "W": "west"}.get(dir, "onward"))


func _zoom_at(factor: float, point: Vector2) -> void:
	var old := _zoom
	_zoom = clampf(_zoom * factor, Balance.ATLAS_MIN_ZOOM, Balance.ATLAS_MAX_ZOOM)
	var center := chart.size * 0.5 + Vector2(0, 10)
	_pan = point - center - (point - center - _pan) * (_zoom / old)
	_clamp_pan()
	_layout_chart()


func _clamp_pan() -> void:
	var max_pan := chart.size * _zoom
	_pan = _pan.clamp(-max_pan, max_pan)


func _hit(point: Vector2) -> int:
	var extent := clampf(_pitch.x * 0.56, 28.0, 58.0)
	for room in _rooms:
		if Rect2(_positions[room] - Vector2.ONE * extent * 0.5, Vector2.ONE * extent).has_point(point):
			return room
	return -1


func _chart_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
			_zoom_at(Balance.ATLAS_ZOOM_STEP if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / Balance.ATLAS_ZOOM_STEP, e.position)
			chart.accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT and _touch_id < 0:
			if e.pressed:
				_begin_drag(e.position)
			else:
				_end_drag(e.position)
			chart.accept_event()
	elif e is InputEventMouseMotion and _touch_id < 0:
		if _dragging:
			_drag(e.position)
		else:
			_hover = _hit(e.position)
			chart.tooltip_text = Nav.room_name(game, _hover) if _hover >= 0 else ""
			chart.queue_redraw()
	elif e is InputEventScreenTouch:
		if e.pressed and _touch_id < 0:
			_touch_id = e.index
			_begin_drag(e.position)
		elif not e.pressed and e.index == _touch_id:
			_end_drag(e.position)
			_touch_id = -1
		chart.accept_event()
	elif e is InputEventScreenDrag and e.index == _touch_id:
		_drag(e.position)
		chart.accept_event()


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	_moved = false
	_drag_start = point
	_drag_last = point


func _drag(point: Vector2) -> void:
	if point.distance_to(_drag_start) > Balance.ATLAS_DRAG_THRESHOLD:
		_moved = true
	if _moved:
		_pan += point - _drag_last
		_clamp_pan()
		_layout_chart()
	_drag_last = point


func _end_drag(point: Vector2) -> void:
	if _dragging and not _moved:
		var room := _hit(point)
		if room >= 0:
			select_room(room)
	_dragging = false


func _draw_chart() -> void:
	var c := chart
	var sz := c.size
	var font: Font = UITheme.body_font()
	if font == null:
		font = ThemeDB.fallback_font
	var symbols := ThemeDB.fallback_font
	# Quiet survey lines, fixed to the chart instead of moving beneath it.
	for x in range(0, int(sz.x), 28):
		c.draw_line(Vector2(x, 0), Vector2(x, sz.y), Color(PAPER, 0.025))
	for y in range(0, int(sz.y), 28):
		c.draw_line(Vector2(0, y), Vector2(sz.x, y), Color(PAPER, 0.025))
	# An engraved compass anchors a sparse early-game chart.
	var rose := Vector2(sz.x - 55, 58)
	c.draw_arc(rose, 24, 0, TAU, 48, Color(UITheme.GOLD, 0.22), 1, true)
	c.draw_line(rose - Vector2(0, 30), rose + Vector2(0, 30), Color(UITheme.GOLD, 0.42), 1, true)
	c.draw_line(rose - Vector2(30, 0), rose + Vector2(30, 0), Color(UITheme.GOLD, 0.22), 1, true)
	c.draw_colored_polygon(PackedVector2Array([rose + Vector2(0, -23), rose + Vector2(4, 2), rose + Vector2(0, -3), rose + Vector2(-4, 2)]), Color(UITheme.GOLD, 0.65))
	c.draw_string(font, rose + Vector2(-4, -35), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD_BRIGHT)
	# Connections are drawn once under cells. Routes use the same graph search
	# as the live guide, including explicitly marked story locks.
	for room in _rooms:
		var p: Vector2 = _positions[room]
		for dir in game.rooms[room]["exits"]:
			var nb: int = game.neighbor(room, String(dir))
			if not _positions.has(nb) or nb < room:
				continue
			var q: Vector2 = _positions[nb]
			var route_index: int = _route.find(room)
			var in_route := route_index >= 0 and ((route_index > 0 and _route[route_index - 1] == nb) \
				or (route_index + 1 < _route.size() and _route[route_index + 1] == nb))
			var unknown: bool = not game.charted(room) or not game.charted(nb)
			var locked: bool = not game._edge_unlocked(room, nb)
			var col := UITheme.GOLD_BRIGHT if in_route else Color(PAPER, 0.35)
			if in_route:
				c.draw_line(p, q, Color(UITheme.GOLD, 0.08), 10, true)
			if unknown:
				c.draw_dashed_line(p, q, col, 2, 5, true)
			else:
				c.draw_line(p, q, col, 2 if in_route else 1, true)
			if locked:
				var mid := (p + q) * 0.5
				var normal := (q - p).normalized().orthogonal()
				c.draw_circle(mid, 7, INK, true, -1, true)
				c.draw_line(mid - normal * 5, mid + normal * 5, Nav.DANGER, 3, true)
	for room in _rooms:
		var p: Vector2 = _positions[room]
		var extent := clampf(_pitch.x * 0.5, 22.0, 50.0)
		var box := Rect2(p - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)
		var col: Color = Nav.room_color(game, room)
		var active := room == selected
		var here := room == game.cur_room
		var known: bool = game.charted(room)
		var fill := Color(0.26, 0.34, 0.37) if known else Color(0.20, 0.25, 0.30)
		if active or room == _hover:
			fill = fill.lightened(0.06)
		if here or active:
			c.draw_style_box(_style(Color(UITheme.GOLD, 0.04), Color(UITheme.GOLD_BRIGHT, 0.7), 7), box.grow(5))
		c.draw_style_box(_style(fill, Color(col, 0.7 if known else 0.35), 5), box)
		var mark: String = "◆" if here else Nav.glyph(game, room)
		var glyph_size := int(clampf(extent * 0.44, 12, 22))
		var width := symbols.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		c.draw_string(symbols, p + Vector2(-width * 0.5, glyph_size * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, UITheme.GOLD_BRIGHT if here else col)
		if room == game.hud.wayfinder.pinned_room:
			c.draw_circle(box.end + Vector2(-1, -1), 5, INK, true, -1, true)
			c.draw_circle(box.end + Vector2(-1, -1), 3, UITheme.GOLD_BRIGHT, true, -1, true)
		if _pitch.x >= 80:
			var room_label := "You are here" if here else Nav.room_name(game, room)
			var max_width := _pitch.x - 8
			while font.get_string_size(room_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > max_width and room_label.length() > 4:
				room_label = room_label.left(room_label.length() - 2).rstrip("…") + "…"
			var tw := font.get_string_size(room_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var at := p + Vector2(-tw * 0.5, extent * 0.5 + 21)
			c.draw_string_outline(font, at, room_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, INK)
			c.draw_string(font, at, room_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD_BRIGHT if here else PAPER)
