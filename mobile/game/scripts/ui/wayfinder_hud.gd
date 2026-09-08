extends Control
## The local player's tactical map and run-local route pin. Presentation only:
## never opens doors, reveals rooms, moves a player or writes a campaign flag.

const Guide := preload("res://scripts/quest_guide.gd")
const Nav := preload("res://scripts/ui/navigation.gd")
const MAP_POS := Vector2(1066, 84)
const MAP_SIZE := Vector2(198, 170)
const FIELD := Rect2(13, 30, 172, 94)
const INK := Color(0.024, 0.037, 0.05, 0.97)
const BLUE := Color(0.47, 0.78, 0.91)

var game: Game
var radar_root: Control
var map_title: Label
var status_label: Label
var detail_label: Label
var pinned_room := -1
var pinned_path: Array[int] = []
var quest_root: Control
var quest_title: Label
var quest_objective: Label
var quest_location: Label
var quest_target: Dictionary = {}
var _objective_flag := ""
var _tracked_id := ""
var _context := ""
var _next_sample := 0.0
var _enemies: Array[Enemy] = []
var _chests: Array[Chest] = []
var _people: Array[Vector2] = []
var _room := -1
var _peak := 0
var _last_count := 0
var _clear_t := 0.0
var _arrival_t := 0.0
var _hot := false
var _engaged := false  # danger presentation can outlive/unseal combat doors
var _boss := false
var _boss_pending := false
var _route_block := ""
var _frame_style: StyleBoxFlat


func _ready() -> void:
	name = "Wayfinder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = INK
	_frame_style.border_color = Color(0.44, 0.37, 0.23, 0.8)
	_frame_style.set_border_width_all(1)
	_frame_style.set_corner_radius_all(9)
	radar_root = Control.new()
	radar_root.name = "TacticalMap"
	radar_root.position = MAP_POS
	radar_root.size = MAP_SIZE
	radar_root.mouse_filter = Control.MOUSE_FILTER_STOP
	radar_root.tooltip_text = "Field atlas · plan a route"
	add_child(radar_root)
	radar_root.draw.connect(_draw_radar)
	radar_root.gui_input.connect(_map_input)
	map_title = _label(radar_root, Vector2(12, 5), Vector2(164, 20), 12, UITheme.GOLD_BRIGHT)
	map_title.name = "MinimapTitle"
	map_title.text = "MAP  (M)"
	var font: Font = UITheme.header_font()
	if font != null:
		map_title.add_theme_font_override("font", font)
	status_label = _label(radar_root, Vector2(12, 130), Vector2(174, 17), 12, Nav.SAFE)
	detail_label = _label(radar_root, Vector2(12, 147), Vector2(174, 18), 12, UITheme.TEXT_MUTED)
	quest_root = Control.new()
	quest_root.name = "TrackedQuest"
	quest_root.position = Vector2(1024, 264)
	quest_root.size = Vector2(240, 128)
	quest_root.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_root.tooltip_text = "Open the quest journal"
	quest_root.gui_input.connect(_quest_input)
	quest_root.draw.connect(func() -> void: quest_root.draw_style_box(_frame_style, Rect2(Vector2.ZERO, quest_root.size)))
	add_child(quest_root)
	quest_title = _label(quest_root, Vector2(12, 8), Vector2(216, 20), 13, UITheme.GOLD_BRIGHT)
	quest_objective = _label(quest_root, Vector2(12, 32), Vector2(216, 66), 13, Color(0.88, 0.90, 0.86))
	quest_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_objective.max_lines_visible = 3
	quest_location = _label(quest_root, Vector2(12, 104), Vector2(216, 19), 12, BLUE)
	quest_root.hide()


func _label(parent: Control, at: Vector2, extent: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = at
	l.size = extent
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	var font: Font = UITheme.body_font()
	if font != null:
		l.add_theme_font_override("font", font)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _map_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	if pressed and game.play_started and game.state == Game.ST_PLAYING \
			and not game.input_overlay_up():
		game.menus.open_map()
		radar_root.accept_event()


func clear_pin() -> void:
	pinned_room = -1
	pinned_path.clear()
	_route_block = ""
	_next_sample = 0.0


func pin(room: int) -> bool:
	if not Nav.known(game, room) or room == game.cur_room or game.pvp_active or game.endgame_active:
		return false
	var path: Array[int] = Nav.route(game, game.cur_room, room)
	if path.is_empty():
		path = Nav.route(game, game.cur_room, room, true)
	if path.is_empty():
		return false
	track("")
	_context = context_key()
	pinned_room = room
	pinned_path = path
	_next_sample = 0.0
	_arrival_t = 0.0
	return true


func context_key() -> String:
	return "%s:%d:%d" % [game.chapter_id, game.wander_seed, game.world.get_instance_id() if is_instance_valid(game.world) else 0]


func sync() -> void:
	# Called by the existing HUD update hook. Route selection belongs to the
	# atlas while this display is hidden; live sampling resumes after it closes.
	visible = game.play_started and not game.rooms.is_empty() and game.state == Game.ST_PLAYING \
		and not game.input_overlay_up() and is_instance_valid(game.local_player) and not game.local_player.dead
	map_title.text = "MAP" if game.touch_mode else "MAP  " + game.control_hint("map", "Map")


func _process(delta: float) -> void:
	if game == null or radar_root == null:
		return
	sync()
	if _context != context_key():
		_context = context_key()
		clear_pin()
		_room = -1
		_clear_t = 0.0
		_arrival_t = 0.0
	if not visible:
		return
	_clear_t = maxf(0.0, _clear_t - delta)
	_arrival_t = maxf(0.0, _arrival_t - delta)
	_next_sample -= delta
	if _next_sample <= 0.0:
		_next_sample = Balance.WAYFINDER_SAMPLE_SECONDS
		_sample()
	radar_root.queue_redraw()
	queue_redraw()


func _sample() -> void:
	if game.rooms.is_empty():
		return
	var zi := game.cur_room
	_enemies = Nav.room_enemies(game, zi)
	_chests = Nav.room_chests(game, zi)
	_people.clear()
	for entry in game.interactables:
		# Removed NPCs can remain in an interaction entry until the room cleans
		# it up. Check the Variant before assigning a typed object reference.
		var candidate = entry.get("node")
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var node: Node2D = candidate
		if node.is_visible_in_tree() and game.room_at_pos(node.global_position) == zi:
			_people.append(node.global_position)
	_hot = game._room_hot(zi)
	_engaged = _hot or not _enemies.is_empty() or preload("res://scripts/encounter_context.gd").blocking_name(game, zi) != ""
	_boss = false
	var guardian := String(game.zones[zi].get("boss", ""))
	_boss_pending = guardian != "" and not game.boss_done.get(guardian, false)
	for e in _enemies:
		if e is Boss:
			_boss = true
	var count := _enemies.size()
	if zi != _room:
		_room = zi
		_peak = count
		_last_count = count
		_clear_t = 0.0
	_peak = maxi(_peak, count)
	if _last_count > 0 and count == 0 and not _engaged and not _boss_pending:
		_clear_t = Balance.WAYFINDER_CLEAR_SECONDS
	_last_count = count
	_sample_quest()
	if pinned_room == zi:
		clear_pin()
		_arrival_t = Balance.WAYFINDER_ARRIVAL_SECONDS
	elif pinned_room >= 0:
		pinned_path = Nav.route(game, zi, pinned_room)
		if pinned_path.is_empty():
			pinned_path = Nav.route(game, zi, pinned_room, true)
		_route_block = Nav.first_lock(game, pinned_path)
		if pinned_path.is_empty():
			clear_pin()
	_refresh_copy()
	_next_sample = Balance.WAYFINDER_SAMPLE_SECONDS


func _refresh_copy() -> void:
	status_label.modulate = Color.WHITE
	status_label.add_theme_color_override("font_color", Nav.DANGER if _engaged else Nav.SAFE)
	if _boss:
		status_label.text = "☠  Guardian engaged"
	elif _engaged:
		status_label.text = "◆  Encounter underway" if _enemies.is_empty() else \
			"⚔  %d threat%s remain%s" % [_enemies.size(), "" if _enemies.size() == 1 else "s", "s" if _enemies.size() == 1 else ""]
	elif _boss_pending:
		status_label.text = "☠  Guardian awaits"
		status_label.add_theme_color_override("font_color", Nav.DANGER)
	elif _clear_t > 0.0:
		status_label.text = "✓  AREA SECURED"
		status_label.modulate.a = 0.8 + 0.2 * sin(_clear_t * 4.0)
	elif _arrival_t > 0.0:
		status_label.text = "◆  Destination reached"
	elif pinned_room >= 0:
		status_label.text = "◆  " + Nav.room_name(game, pinned_room)
		status_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	else:
		status_label.text = "⌂  Sanctuary" if game.room_safe(_room) else "✓  Doors unsealed"
	if not _chests.is_empty():
		detail_label.text = "◇  %d chest%s to collect" % [_chests.size(), "" if _chests.size() == 1 else "s"]
		detail_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	elif _engaged or _boss_pending:
		detail_label.text = "Red: foes  ·  blue: people"
		detail_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	elif pinned_path.size() > 1:
		if _route_block != "":
			detail_label.text = "Route sealed · see atlas"
		else:
			var dir: String = Nav.direction(game, _room, pinned_path[1])
			detail_label.text = "%s  ·  %d passage%s away" % [dir, pinned_path.size() - 1, "" if pinned_path.size() == 2 else "s"]
		detail_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	else:
		detail_label.text = "Open the atlas to set a route"
		detail_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	status_label.tooltip_text = status_label.text


func _map_point(world_pos: Vector2) -> Vector2:
	var r := game.play_rect(_room)
	var uv := (world_pos - r.position) / r.size
	return FIELD.position + Vector2(clampf(uv.x, 0, 1), clampf(uv.y, 0, 1)) * FIELD.size


func _draw_radar() -> void:
	var c := radar_root
	c.draw_style_box(_frame_style, Rect2(Vector2.ZERO, MAP_SIZE))
	c.draw_line(Vector2(12, 25), Vector2(186, 25), Color(UITheme.GOLD, 0.32))
	if _room < 0 or _room >= game.rooms.size():
		return
	var tint: Color = Terrains.get_terrain(game.terrain_by_zone[_room])["tint"]
	c.draw_rect(FIELD, Color(tint.r * 0.075, tint.g * 0.1, tint.b * 0.105, 1))
	for x in range(1, 6):
		var at := FIELD.position + Vector2(FIELD.size.x * x / 6.0, 0)
		c.draw_line(at, at + Vector2(0, FIELD.size.y), Color(0.5, 0.62, 0.67, 0.07))
	for y in range(1, 4):
		var at := FIELD.position + Vector2(0, FIELD.size.y * y / 4.0)
		c.draw_line(at, at + Vector2(FIELD.size.x, 0), Color(0.5, 0.62, 0.67, 0.07))
	c.draw_rect(FIELD, Color(0.4, 0.54, 0.57, 0.3), false, 1)
	# Camera footprint: the small map gives context beyond the visible floor.
	var xf := game.get_viewport().get_canvas_transform().affine_inverse()
	var view := game.get_viewport().get_visible_rect()
	var a := _map_point(xf * view.position)
	var b := _map_point(xf * view.end)
	c.draw_rect(Rect2(a, b - a), Color(0.56, 0.7, 0.75, 0.075))
	c.draw_rect(Rect2(a, b - a), Color(0.56, 0.7, 0.75, 0.24), false)
	for dir in game.rooms[_room]["exits"]:
		var nb: int = game.neighbor(_room, String(dir))
		if nb < 0:
			continue
		var p := _map_point(game.door_pos(_room, String(dir)))
		var closed := _hot or not game._edge_unlocked(_room, nb)
		var color := Nav.DANGER if closed else UITheme.GOLD_BRIGHT
		var next := pinned_path.size() > 1 and pinned_path[1] == nb
		if next:
			c.draw_circle(p, 7, Color(color, 0.15), true, -1, true)
		var sz := Vector2(10, 4) if dir in ["N", "S"] else Vector2(4, 10)
		c.draw_rect(Rect2(p - sz * 0.5, sz), color)
	for p in _people:
		c.draw_circle(_map_point(p), 2.5, BLUE, true, -1, true)
	for chest in _chests:
		if is_instance_valid(chest) and not chest.opened:
			_diamond(c, _map_point(chest.global_position), 3.5, UITheme.GOLD_BRIGHT)
	for e in _enemies:
		if not is_instance_valid(e) or e.dying or not e.is_visible_in_tree():
			continue
		var p := _map_point(e.global_position)
		if e is Boss or e.elite:
			_diamond(c, p, 4, Nav.DANGER)
		else:
			c.draw_circle(p, 2.2, Nav.DANGER, true, -1, true)
	if not quest_target.is_empty() and int(quest_target.room) == _room:
		var qpoint := _map_point(quest_target.point)
		c.draw_circle(qpoint, 7, INK, true, -1, true)
		_diamond(c, qpoint, 4.5, UITheme.GOLD_BRIGHT)
	for p in game.players:
		if is_instance_valid(p) and p != game.local_player and game.room_at_pos(p.global_position) == _room:
			_diamond(c, _map_point(p.global_position), 3, BLUE)
	if is_instance_valid(game.local_player):
		var p := _map_point(game.local_player.global_position)
		var f := game.local_player.facing.normalized()
		if f.is_zero_approx():
			f = Vector2.DOWN
		var side := f.orthogonal()
		c.draw_circle(p, 7, Color(UITheme.GOLD_BRIGHT, 0.1), true, -1, true)
		c.draw_colored_polygon(PackedVector2Array([p + f * 5.5, p - f * 3.5 + side * 3.5, p - f * 2, p - f * 3.5 - side * 3.5]), Color(1, 0.94, 0.73))
	# Encounter progress is local to this visit; its peak includes reinforcements.
	if _peak > 0:
		var fraction := 1.0 - float(_enemies.size()) / _peak
		c.draw_rect(Rect2(13, 126, 172, 2), Color(Nav.DANGER, 0.22))
		c.draw_rect(Rect2(13, 126, 172 * clampf(fraction, 0, 1), 2), Nav.DANGER if _engaged else Nav.SAFE)


func _diamond(c: Control, p: Vector2, r: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)


func _draw() -> void:
	if visible and not _hot and not _boss_pending and not quest_target.is_empty() and int(quest_target.room) == game.cur_room:
		var at: Vector2 = game.get_viewport().get_canvas_transform() * (quest_target.point + Vector2(0, -64))
		if Rect2(80, 100, 936, 430).has_point(at):
			draw_circle(at, 12, INK, true, -1, true)
			_diamond(self, at, 7, UITheme.GOLD_BRIGHT)
	if not visible or pinned_path.size() < 2 or _hot or _boss_pending or _room != game.cur_room:
		return
	var next := pinned_path[1]
	if not game._edge_unlocked(_room, next):
		return
	var dir: String = Nav.direction(game, _room, next)
	if dir == "":
		return
	var door := game.door_pos(_room, dir)
	var r := game.play_rect(_room).grow(-Balance.WAYFINDER_DOOR_INSET)
	door = door.clamp(r.position, r.end)
	var xf := game.get_viewport().get_canvas_transform()
	var target := xf * door
	var center := xf * game.local_player.global_position
	var delta := target - center
	if delta.length() < Balance.WAYFINDER_GUIDE_HIDE_DISTANCE:
		return
	# Keep the bearing clear of the HUD, ability bar and touch-control zones.
	var safe := Rect2(380, 174, 630, 326)
	var p := target.clamp(safe.position, safe.end)
	var f := delta.normalized()
	var side := f.orthogonal()
	var beat := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.003)
	draw_circle(p, 18, Color(0.025, 0.035, 0.05, 0.88), true, -1, true)
	draw_arc(p, 18, 0, TAU, 40, Color(UITheme.GOLD, 0.7), 1, true)
	draw_polyline(PackedVector2Array([p - f * 4 + side * 6, p + f * 4, p - f * 4 - side * 6]), Color(UITheme.GOLD_BRIGHT, beat), 2.0, true)
	var text := "%s · %d" % [dir, pinned_path.size() - 1]
	var font: Font = UITheme.body_bold_font()
	if font == null:
		font = ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var pos := p + Vector2(-width * 0.5, 36)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.01, 0.015, 0.02))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.GOLD_BRIGHT)


func _quest_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if pressed and not game.input_overlay_up():
		game.menus.open_journal("quests")
		quest_root.accept_event()


func track(id: String) -> void:
	if not game.has_local_player():
		return
	game.player.tracked_quest = id if Guide.active(game, id) else ""
	quest_target = {}
	_tracked_id = ""
	_objective_flag = ""
	clear_pin()


func _sample_quest() -> void:
	var id: String = game.player.tracked_quest
	var objective: Dictionary = Guide.step(game, id)
	quest_root.visible = not objective.is_empty() and not game.pvp_active and not game.endgame_active
	if objective.is_empty():
		if _tracked_id != "":
			clear_pin()
		_tracked_id = ""
		_objective_flag = ""
		quest_target = {}
		return
	var flag_name := String(objective.flag)
	if _tracked_id == id and _objective_flag != "" and _objective_flag != flag_name:
		game.hud.announce("Objective complete · " + String(Story.ALL_SIDE_QUESTS[id].name), Nav.SAFE, 2.0)
	_tracked_id = id
	_objective_flag = flag_name
	quest_title.text = "◆  " + String(Story.ALL_SIDE_QUESTS[id].name)
	quest_objective.text = Guide.describe(game, objective)
	quest_target = Guide.destination(game, objective)
	if quest_target.is_empty():
		clear_pin()
		quest_location.text = "Explore to locate the objective"
	elif int(quest_target.room) == game.cur_room:
		clear_pin()
		quest_location.text = "◆  Objective in this area"
	else:
		pinned_room = int(quest_target.room)
		pinned_path.assign(quest_target.path)
		quest_location.text = "↗  " + Nav.room_name(game, pinned_room)
	quest_root.tooltip_text = quest_title.text + "\n" + quest_objective.text + "\nOpen the quest journal"
