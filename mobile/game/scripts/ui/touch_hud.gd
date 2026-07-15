class_name TouchHud extends CanvasLayer
## On-screen touch controls for the mobile build (MULTIPLAYER.md §10, Wild Rift
## layout). Pure presentation: every widget writes an `intent_*` seam and NOTHING
## below it forks per platform —
##   • left floating joystick  → MobileInput.move        (analog)
##   • right ability arc a1/a2/a3/ult + potion + interact → MobileInput.<flag>
##   • target-lock button       → game.local_player.intent_lock / _release
##     (tap = lock/cycle, hold-and-swipe-off = drop the lock)
##
## Icons, cooldown dim, and mana affordability read the SAME sources the desktop
## ability bar uses (hud.gd:1226-1265) — Classes.ability / Art.glyph_tex /
## p.cds / p.ability_cd / p.ability_cost — so the arc tracks per-class abilities
## and cooldowns automatically, with zero duplicated kit knowledge.
##
## Built in code, mirroring hud.gd's programmatic style. game.gd adds it only on
## a mobile OS or with the `--touch` dev arg (so it's drivable with the mouse via
## emulate_touch_from_mouse on this desktop for verification).

var game                                   # the Game node (set by game.gd before add_child)

# --- layout tuning (viewport-space px; the project stretches 1280x720) --------
const SAFE_MARGIN := 30.0                  # crude inset; precise notch mapping is a later refinement
const JOY_MAX := 118.0                     # max knob travel from the touch origin
const JOY_DEAD := 0.20                     # inner deadzone (fraction of JOY_MAX)
const JOY_BASE_D := 236.0
const JOY_KNOB_D := 108.0
const BTN_D := 104.0                       # ability-button diameter
const BTN_SD := 80.0                       # secondary-button diameter
const LOCK_SWIPE_OFF := 66.0               # drag this far off the lock button = release, not lock
const ABILITY_SLOTS := ["a1", "a2", "a3", "ult"]

# id -> relative offset from the cluster origin (origin = centre of the a1
# button, bottom-right). Compact arc tuned for a right-thumb pivot: the four
# abilities fan up-left from a1, the three small utility buttons tuck just
# inside them. Kept clear of the top-of-screen HUD.
const BTN_LAYOUT := {
	"a1":          Vector2(0, 0),
	"a2":          Vector2(-112, -30),
	"a3":          Vector2(-88, -128),
	"ult":         Vector2(20, -146),
	"potion":      Vector2(-198, -72),
	"potion_next": Vector2(-238, -158),
	"interact":    Vector2(-180, -172),
	"lock":        Vector2(-70, -224),
}

# --- runtime state ------------------------------------------------------------
var _mi: Node                  # MobileInput autoload, reached by /root path (compile-gate trap)
var _enabled := false
var _btns := {}                # id -> {panel, icon, label, diam, center}
var _joy_base: Panel
var _joy_knob: Panel
var _move_touch := -1          # finger index driving the joystick (-1 = none)
var _joy_center := Vector2.ZERO
var _btn_touch := {}           # finger index -> button id (held ability/action buttons)
var _lock_idx := -1            # finger index on the lock button
var _lock_start := Vector2.ZERO
var _lock_moved := false
var _edit_mode := false         # layout-customization: drag buttons to rearrange
var _drag_id := ""              # button being dragged in edit mode
var _edit_ui: Control = null    # the Done/Reset banner overlay


func _ready() -> void:
	_mi = get_node("/root/MobileInput")
	# Strip the keyboard-only chrome the touch controls replace (desktop ability
	# bar + WASD/keys hint lines) so the phone screen isn't cluttered/misleading.
	if game != null and game.hud != null:
		game.hud.set_touch_mode(true)
	layer = 5   # above the desktop HUD's world overlays; corners don't collide with its top bar
	_joy_base = _circle(JOY_BASE_D, Color(0.10, 0.11, 0.16, 0.42), Color(0.65, 0.7, 0.85, 0.5), 4.0)
	_joy_knob = _circle(JOY_KNOB_D, Color(0.55, 0.62, 0.85, 0.6), Color(0.85, 0.9, 1.0, 0.8), 3.0)
	_joy_base.visible = false
	_joy_knob.visible = false
	add_child(_joy_base)
	add_child(_joy_knob)
	for id in BTN_LAYOUT.keys():
		_make_button(String(id))
	get_viewport().size_changed.connect(_layout)
	_layout()


# ------------------------------------------------------------------ building ---
func _circle(diam: float, fill: Color, border_col: Color, border_w: float) -> Panel:
	var pnl := Panel.new()
	pnl.size = Vector2(diam, diam)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # we hit-test manually in _input
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(diam / 2.0))
	sb.border_color = border_col
	sb.set_border_width_all(int(border_w))
	pnl.add_theme_stylebox_override("panel", sb)
	return pnl


func _make_button(id: String) -> void:
	var diam: float = BTN_D if ABILITY_SLOTS.has(id) else BTN_SD
	var pnl := _circle(diam, Color(0.06, 0.07, 0.11, 0.72), Color(0.5, 0.55, 0.7, 0.7), 3.0)
	add_child(pnl)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(diam * 0.18, diam * 0.18)
	icon.custom_minimum_size = Vector2(diam * 0.64, diam * 0.64)
	icon.size = icon.custom_minimum_size
	pnl.add_child(icon)
	# Centre label: cooldown countdown for abilities, x-count for potion, glyph
	# for the static action buttons (lock / interact / cycle).
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(diam, diam)
	lbl.add_theme_font_size_override("font_size", 22 if ABILITY_SLOTS.has(id) else 16)
	pnl.add_child(lbl)
	# Static glyphs for the action buttons that have no per-frame icon.
	match id:
		"lock": lbl.text = "◎"
		"interact": lbl.text = "USE"
		"potion_next": lbl.text = "⟳"
	_btns[id] = {"panel": pnl, "icon": icon, "label": lbl, "diam": diam, "center": Vector2.ZERO}


## Position every widget relative to the bottom-right cluster origin. Re-runs on
## viewport resize (rotation / different phone aspect ratios).
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var origin := Vector2(vp.x - SAFE_MARGIN - BTN_D / 2.0 - 8.0,
						   vp.y - SAFE_MARGIN - BTN_D / 2.0 - 8.0)
	var custom: Dictionary = game.settings.get("touch_layout", {}) if game != null else {}
	for id in _btns.keys():
		var b: Dictionary = _btns[id]
		var off: Vector2 = BTN_LAYOUT[id]
		if custom.has(id):
			var a: Array = custom[id]     # player-saved offset overrides the default
			off = Vector2(float(a[0]), float(a[1]))
		var c: Vector2 = origin + off
		b["center"] = c
		(b["panel"] as Panel).position = c - Vector2(b["diam"], b["diam"]) / 2.0
	if _edit_ui != null:
		_edit_ui.size = get_viewport().get_visible_rect().size


# --------------------------------------------------------------- per frame -----
func _process(_delta: float) -> void:
	var on: bool = game != null and game.state == game.ST_PLAYING \
		and game.local_player != null and is_instance_valid(game.local_player)
	if on != _enabled:
		_enabled = on
		visible = on
		if not on:
			_release_everything()
	if not _enabled:
		return
	_refresh_ability_icons()


## Mirror the desktop ability bar's per-frame icon/cooldown/affordability logic
## (hud.gd:1226-1265) onto the touch arc + potion button.
func _refresh_ability_icons() -> void:
	var p = game.local_player
	for slot in ABILITY_SLOTS:
		var b: Dictionary = _btns[slot]
		var theme: Dictionary = Classes.theme_by_id(p.cls, p.ability_theme.get(slot, ""))
		var icon_tex: Texture2D = Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot],
			theme.get("color", Color(0.85, 0.85, 0.92)))
		(b["icon"] as TextureRect).texture = icon_tex
		var remaining: float = p.cds[slot]
		var max_cd: float = p.ability_cd(slot)
		var cost: float = p.ability_cost(slot)
		var ready: bool = remaining <= 0.0
		var can_afford: bool = p.mp >= cost
		var lbl := b["label"] as Label
		var icon := b["icon"] as TextureRect
		if not ready:
			lbl.text = "%d" % ceil(remaining)
			icon.modulate = Color(0.4, 0.44, 0.55, 0.9)
		elif not can_afford:
			lbl.text = ""
			icon.modulate = Color(0.75, 0.5, 0.5, 0.9)
		else:
			lbl.text = ""
			icon.modulate = Color(1, 1, 1, 1)
	# Potion: icon + carried count (health uses the potion glyph; a slotted
	# elixir uses its consumable icon). ability-agnostic, so kept separate.
	var pb: Dictionary = _btns["potion"]
	var picon := pb["icon"] as TextureRect
	var plbl := pb["label"] as Label
	if p.active_potion == "health":
		picon.texture = Art.tex("potion")
	else:
		var ic: Texture2D = Art.consumable_icon({"id": p.active_potion})
		picon.texture = ic if ic != null else Art.tex("potion")
	var left: int = p.room_potions_left()
	plbl.text = "x%d" % p.potion_count() if left > 0 else "—"
	picon.modulate = Color(1, 1, 1, 1) if left > 0 else Color(0.4, 0.4, 0.4, 0.8)


# ------------------------------------------------------------------ input ------
func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _edit_mode:
			_drag_id = _button_at(e.position)   # grab an ability button to reposition
			if _drag_id == "" and _near_joystick(e.position):
				_drag_id = "__joy"              # grab the joystick base to move it
			if _drag_id != "":
				get_viewport().set_input_as_handled()
			return   # a miss lets the Done/Reset buttons receive the tap
		var id := _button_at(e.position)
		if id != "":
			if id == "lock":
				_lock_idx = e.index
				_lock_start = e.position
				_lock_moved = false
			else:
				_btn_touch[e.index] = id
				_mi.set(id, true)
				_press_fx(id, true)
			_mark_active()
			get_viewport().set_input_as_handled()
		elif _move_touch == -1 and _in_joystick_zone(e.position):
			_move_touch = e.index
			# Floating: the base springs to the thumb. Locked: fixed bottom-left base,
			# the touch just grabs the knob — persisted via the joystick_locked setting.
			if _joystick_locked():
				_joy_center = _joy_home()
				_place_joystick(_joy_center, _joy_center)
			else:
				_joy_center = e.position
				_place_joystick(e.position, e.position)
			_joy_base.visible = true
			_joy_knob.visible = true
			_mark_active()
			get_viewport().set_input_as_handled()
	else:
		if _edit_mode:
			if _drag_id != "":
				game.save_settings()   # persist the new position
				_drag_id = ""
				get_viewport().set_input_as_handled()
			return
		if e.index == _move_touch:
			_move_touch = -1
			_mi.move = Vector2.ZERO
			_joy_base.visible = false
			_joy_knob.visible = false
		if e.index == _lock_idx:
			# §10: a tap locks/cycles; a hold-then-swipe-off drops the lock.
			if _lock_moved:
				game.local_player.intent_lock_release = true
			else:
				game.local_player.intent_lock = true
			_lock_idx = -1
		if _btn_touch.has(e.index):
			var id: String = _btn_touch[e.index]
			_mi.set(id, false)
			_press_fx(id, false)
			_btn_touch.erase(e.index)
		_mark_active()


func _on_drag(e: InputEventScreenDrag) -> void:
	if _edit_mode:
		if _drag_id == "__joy":
			_move_joystick(e.position)
		elif _drag_id != "":
			_move_button(_drag_id, e.position)
		return
	if e.index == _move_touch:
		var off := e.position - _joy_center
		off = off.limit_length(JOY_MAX)
		_place_joystick(_joy_center, _joy_center + off)
		var mag := off.length() / JOY_MAX
		if mag < JOY_DEAD:
			_mi.move = Vector2.ZERO
		else:
			# Sensitivity lets the player reach full speed on a shorter drag: the
			# post-deadzone travel is multiplied, then clamped. 1.0 = raw stick
			# (edge = max); >1 maxes out early ("slight drag = full speed").
			var sens: float = float(game.settings.get("joystick_sensitivity", 1.0)) if game != null else 1.0
			var scaled := clampf((mag - JOY_DEAD) / (1.0 - JOY_DEAD), 0.0, 1.0)
			scaled = clampf(scaled * sens, 0.0, 1.0)
			_mi.move = off.normalized() * scaled
	elif e.index == _lock_idx:
		if e.position.distance_to(_lock_start) > LOCK_SWIPE_OFF:
			_lock_moved = true


# ------------------------------------------------------------------ helpers ----
## The button id whose circle contains `pos`, or "" — reverse iteration so the
## visually-topmost (last-added) button wins any overlap.
func _button_at(pos: Vector2) -> String:
	for id in _btns.keys():
		var b: Dictionary = _btns[id]
		if pos.distance_to(b["center"] as Vector2) <= (b["diam"] as float) / 2.0:
			return String(id)
	return ""


## Joystick may start only in the lower-left, clear of the desktop HUD's top bar.
func _in_joystick_zone(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	return pos.x < vp.x * 0.5 and pos.y > vp.y * 0.30


func _place_joystick(base_c: Vector2, knob_c: Vector2) -> void:
	_joy_base.position = base_c - _joy_base.size / 2.0
	_joy_knob.position = knob_c - _joy_knob.size / 2.0


func _press_fx(id: String, down: bool) -> void:
	var pnl := (_btns[id] as Dictionary)["panel"] as Panel
	pnl.modulate = Color(1.4, 1.4, 1.5) if down else Color(1, 1, 1)


func _mark_active() -> void:
	_mi.active = _move_touch != -1 or not _btn_touch.is_empty()


## Drop every held touch (focus loss / gameplay pause) so nothing sticks on.
func _release_everything() -> void:
	if _mi != null:
		_mi.clear_held()
	_move_touch = -1
	_lock_idx = -1
	_btn_touch.clear()
	if _joy_base != null:
		_joy_base.visible = false
		_joy_knob.visible = false
	for id in _btns.keys():
		_press_fx(String(id), false)


# ------------------------------------------------------ layout customization ---
func _joystick_locked() -> bool:
	return game != null and bool(game.settings.get("joystick_locked", false))


func _joy_home() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	# Player-dragged home (set in the layout editor) wins; else a bottom-left anchor.
	var jp = game.settings.get("joystick_pos", null) if game != null else null
	if jp is Array and (jp as Array).size() == 2:
		return Vector2(float(jp[0]), float(jp[1]))
	return Vector2(vp.x * 0.16, vp.y * 0.72)   # fixed bottom-left anchor when locked


## Enter layout-customization: buttons become draggable; a Done/Reset banner appears.
## Called from Settings > Customize Buttons (which closes the menu first).
func enter_edit_mode() -> void:
	_edit_mode = true
	_release_everything()
	_enabled = true
	visible = true
	# Show the joystick at its home so it can be dragged like the buttons.
	_joy_center = _joy_home()
	_place_joystick(_joy_center, _joy_center)
	_joy_base.visible = true
	_joy_knob.visible = true
	if _edit_ui == null:
		_build_edit_ui()
	_edit_ui.visible = true


func exit_edit_mode() -> void:
	_edit_mode = false
	_drag_id = ""
	_joy_base.visible = false   # the edit-mode preview; play hides it until a touch
	_joy_knob.visible = false
	if _edit_ui != null:
		_edit_ui.visible = false
	if game != null:
		game.save_settings()


func _reset_layout() -> void:
	if game != null:
		game.settings["touch_layout"] = {}
		game.settings.erase("joystick_pos")   # back to the default bottom-left home
		game.save_settings()
	_layout()
	# Re-show the joystick preview at the restored default home.
	_joy_center = _joy_home()
	_place_joystick(_joy_center, _joy_center)


## Drag a button to a new spot; store its offset relative to the cluster origin.
func _move_button(id: String, pos: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var origin := Vector2(vp.x - SAFE_MARGIN - BTN_D / 2.0 - 8.0, vp.y - SAFE_MARGIN - BTN_D / 2.0 - 8.0)
	var off := pos - origin
	var b: Dictionary = _btns[id]
	b["center"] = origin + off
	(b["panel"] as Panel).position = (origin + off) - Vector2(b["diam"], b["diam"]) / 2.0
	var custom: Dictionary = game.settings.get("touch_layout", {})
	custom[id] = [off.x, off.y]
	game.settings["touch_layout"] = custom


## Is `pos` on the joystick base? (edit mode only — used to grab it for a move.)
func _near_joystick(pos: Vector2) -> bool:
	return _joy_base != null and _joy_base.visible \
		and pos.distance_to(_joy_center) <= JOY_BASE_D / 2.0


## Drag the joystick's home position in edit mode; saved so a locked stick spawns
## there and a floating one springs from there (persisted as joystick_pos).
func _move_joystick(pos: Vector2) -> void:
	_joy_center = pos
	_place_joystick(pos, pos)
	if game != null:
		game.settings["joystick_pos"] = [pos.x, pos.y]


func _build_edit_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	_edit_ui = Control.new()
	_edit_ui.size = vp
	_edit_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edit_ui)
	var banner := Label.new()
	banner.text = "Drag the buttons or the joystick to rearrange your layout"
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	banner.position = Vector2(vp.x * 0.5 - 260.0, 22.0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_ui.add_child(banner)
	var done := Button.new()
	done.text = "  Done  "
	done.add_theme_font_size_override("font_size", 18)
	done.position = Vector2(vp.x * 0.5 - 110.0, 56.0)
	done.pressed.connect(exit_edit_mode)
	_edit_ui.add_child(done)
	var reset := Button.new()
	reset.text = "  Reset  "
	reset.add_theme_font_size_override("font_size", 18)
	reset.position = Vector2(vp.x * 0.5 + 30.0, 56.0)
	reset.pressed.connect(_reset_layout)
	_edit_ui.add_child(reset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_everything()
