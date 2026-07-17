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
const LONG_PRESS := 0.45                    # hold a button this long = show its info (instead of using it)
const TAP_PULSE := 0.12                     # how long a tap holds its intent flag true (so the sim polls it)
const INFO_LINGER := 2.4                    # how long the info card stays after the finger lifts
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
# Tap-vs-hold: a quick tap USES a button (fires on release); a long hold EXPLAINS
# it (shows an info card, no use). Firing is deferred to release for that split.
var _press_start := {}          # finger index -> press time (secs) for held buttons/lock
var _explained := {}            # finger index -> true once this press has shown its info
var _pulse := {}                # id -> secs remaining to hold its MobileInput flag true (a tap)
var _info: PanelContainer = null # the long-press info card
var _info_title: Label = null
var _info_body: Label = null
var _info_hide_t := 0.0         # linger countdown after the finger lifts


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
	# Variant glow behind the icon (ability slots only), tinted per frame by the
	# equipped theme — mirrors the desktop bar. Added before the icon so it sits
	# under it; the radial fades to transparent, so a square glow reads fine
	# inside the round panel.
	var glow: TextureRect = null
	if ABILITY_SLOTS.has(id):
		glow = TextureRect.new()
		glow.texture = Art.ability_glow()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = Vector2.ZERO
		glow.size = Vector2(diam, diam)
		pnl.add_child(glow)
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
	# Static content for the action buttons that have no per-frame icon: the lock
	# uses a drawn scope reticle (the ◎ glyph was thin + missing on mobile fonts);
	# interact + cycle carry short labels.
	match id:
		"lock": icon.texture = Art.tex("crosshair")
		"interact": lbl.text = "Act"
		"potion_next": lbl.text = "⟳"
	_btns[id] = {"panel": pnl, "icon": icon, "glow": glow, "label": lbl, "diam": diam, "center": Vector2.ZERO}


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
func _process(delta: float) -> void:
	# Any overlay (menu / dialogue / choice) shuts the controls down — the same
	# guard game.gd's tap-to-talk already uses (~L369). Solo got this for free:
	# all three call request_pause(true), and the pause stops this node. But §5.4
	# skips the pause in a SESSION, and nothing else gated us — the arc and the
	# joystick zone (the whole left half, under the overlay's dim on layer 20)
	# stayed live, so a drag inside a panel walked your hero mid-fight.
	# `menus` is null-checked on purpose: game.gd mounts this HUD (_apply_touch_mode,
	# ~L189) BEFORE it builds Menus (~L192). The layout editor closes the menu
	# before calling enter_edit_mode, so it still runs with nothing open.
	var on: bool = game != null and game.state == game.ST_PLAYING \
		and game.local_player != null and is_instance_valid(game.local_player) \
		and (game.menus == null or not game.menus.is_open()) \
		and (game.hud == null or not (game.hud.dialogue_active or game.hud.choices_active))
	if on != _enabled:
		_enabled = on
		visible = on
		if not on:
			_release_everything()
	if not _enabled:
		return
	# The Act (interact) button appears only when next to something to interact
	# with — permanently showing it was noise. Always shown in edit mode so it can
	# be repositioned.
	(_btns["interact"]["panel"] as Panel).visible = _edit_mode or (game != null and game.interact_in_range)
	# Same treatment for the ⟳ potion-swap button: hidden when there's nothing to
	# cycle to (a single loadout slot, or an all-Health plan).
	(_btns["potion_next"]["panel"] as Panel).visible = _edit_mode \
		or (game != null and game.local_player != null and game.local_player.potion_swap_useful())
	if _edit_mode:
		return
	_refresh_ability_icons()
	_update_holds(delta)


## Mirror the desktop ability bar's per-frame icon/cooldown/affordability logic
## (hud.gd:1226-1265) onto the touch arc + potion button.
func _refresh_ability_icons() -> void:
	var p = game.local_player
	for slot in ABILITY_SLOTS:
		var b: Dictionary = _btns[slot]
		var theme: Dictionary = Classes.theme_by_id(p.cls, p.ability_theme.get(slot, ""))
		var tcol: Color = theme.get("color", Color(0.85, 0.85, 0.92))
		var icon_tex: Texture2D = Art.ability_icon(p.cls, slot, tcol)
		(b["icon"] as TextureRect).texture = icon_tex
		# Variant glow: theme colour when equipped, dim neutral when bare.
		if b["glow"] != null:
			(b["glow"] as TextureRect).modulate = tcol if not theme.is_empty() else Color(0.42, 0.46, 0.6, 0.55)
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
			# Firing is DEFERRED to release so a long hold can be told from a tap
			# (hold shows the info card instead of using the button).
			_press_start[e.index] = _now()
			if id == "lock":
				_lock_idx = e.index
				_lock_start = e.position
				_lock_moved = false
			else:
				_btn_touch[e.index] = id
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
			# §10: a tap locks/cycles; a hold-then-swipe-off drops the lock; a long
			# hold (no swipe) showed the info card, so it neither locks nor releases.
			if _explained.has(e.index):
				pass
			elif _lock_moved:
				game.local_player.intent_lock_release = true
			else:
				game.local_player.intent_lock = true
			_lock_idx = -1
		if _btn_touch.has(e.index):
			var id: String = _btn_touch[e.index]
			# A tap fires now (one short intent pulse); a long hold only explained.
			if not _explained.has(e.index):
				_mi.set(id, true)
				_pulse[id] = TAP_PULSE
			_press_fx(id, false)
			_btn_touch.erase(e.index)
		_press_start.erase(e.index)
		_explained.erase(e.index)
		if _btn_touch.is_empty() and _lock_idx == -1 and _info != null and _info.visible:
			_info_hide_t = INFO_LINGER   # let the card linger so it can be read
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
		if not (b["panel"] as Panel).visible:
			continue   # a hidden button (Act when out of range) isn't tappable
		if pos.distance_to(b["center"] as Vector2) <= (b["diam"] as float) / 2.0:
			return String(id)
	return ""


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Per-frame: promote long holds to an info card, expire tap pulses, fade the card.
func _update_holds(delta: float) -> void:
	var t := _now()
	# A button held past LONG_PRESS shows its info instead of using it on release.
	for idx in _btn_touch:
		if not _explained.has(idx) and t - float(_press_start.get(idx, t)) >= LONG_PRESS:
			_explained[idx] = true
			_explain(String(_btn_touch[idx]))
	if _lock_idx != -1 and not _lock_moved and not _explained.has(_lock_idx) \
			and t - float(_press_start.get(_lock_idx, t)) >= LONG_PRESS:
		_explained[_lock_idx] = true
		_explain("lock")
	# Tap pulses: hold each tapped intent true a few frames, then drop it (the sim
	# is cooldown-gated, so this fires exactly once).
	for id in _pulse.keys():
		_pulse[id] = float(_pulse[id]) - delta
		if float(_pulse[id]) <= 0.0:
			_mi.set(id, false)
			_pulse.erase(id)
	# Info card fade once no finger is holding it.
	if _info != null and _info.visible and _btn_touch.is_empty() and _lock_idx == -1:
		_info_hide_t -= delta
		if _info_hide_t <= 0.0:
			_info.visible = false


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
	_press_start.clear()
	_explained.clear()
	_pulse.clear()
	if _info != null:
		_info.visible = false
	if _joy_base != null:
		_joy_base.visible = false
		_joy_knob.visible = false
	for id in _btns.keys():
		_press_fx(String(id), false)


# --------------------------------------------------------- long-press info ----
## Build the info card lazily (top-centre, out of the thumb clusters).
func _build_info() -> void:
	_info = PanelContainer.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.96)
	sb.border_color = Color(0.85, 0.75, 0.5, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_info.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(vb)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 20)
	_info_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	_info_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_info_title)
	_info_body = Label.new()
	_info_body.add_theme_font_size_override("font_size", 15)
	_info_body.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(500, 0)
	_info_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_info_body)
	_info.visible = false
	add_child(_info)


func _show_info(title: String, body: String) -> void:
	if _info == null:
		_build_info()
	_info_title.text = title
	_info_body.text = body
	_info.visible = true
	var vp := get_viewport().get_visible_rect().size
	_info.position = Vector2(vp.x * 0.5 - 266.0, vp.y * 0.07)  # ~532px card, centred
	_info_hide_t = INFO_LINGER


## What each button does — abilities read the live kit/variant data (same source
## as the desktop tooltip); the utility buttons carry hand-written blurbs.
func _explain(id: String) -> void:
	if game == null or game.local_player == null:
		return
	var p = game.local_player
	var title := ""
	var body := ""
	match id:
		"a1", "a2", "a3", "ult":
			var ab: Dictionary = Classes.ability(p.cls, id)
			title = String(ab.get("name", id.to_upper()))
			body = String(ab.get("desc", ""))
			var theme_id: String = String(p.ability_theme.get(id, ""))
			if theme_id != "":
				var vd := Classes.variant_desc(p.cls, id, theme_id)
				if vd != "":
					body = vd
			var sc := Classes.ability_scaling(p.cls, id)
			var ri := Classes.ability_riders(p.cls, id)
			if sc != "":
				body += "\n[ %s ]" % sc
			if ri != "":
				body += "\n[ %s ]" % ri
			var cd: float = p.ability_cd(id)
			body += "\nCost %d MP · %s cooldown" % [int(p.ability_cost(id)),
				("%.1fs" % cd) if cd > 0.0 else "no"]
		"potion":
			title = "Drink potion"
			body = "Quaff your ACTIVE potion — a health draught, or the elixir/mana you've slotted. Uses are budgeted per room, and health draughts spend your OWNED stock (bought, or the ch1-3 freebie) — never free."
		"potion_next":
			title = "Cycle potion"
			body = "Switch which potion the drink button uses, among the types slotted in your rotation. Does nothing if you only carry health potions."
		"interact":
			title = "Act"
			body = "Talk to an NPC, open a chest, or use whatever you're next to. (You can also just tap the target directly.)"
		"lock":
			title = "Target lock"
			body = "Tap to lock onto / cycle the nearest enemy so your aim and abilities focus it. Hold and swipe your thumb off the button to release the lock."
	_show_info(title, body)
	game.sfx("ui_click")


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
