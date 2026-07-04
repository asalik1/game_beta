class_name Hud extends CanvasLayer
## Everything drawn on top of the world: health/mana/xp bars, gold, quest
## tracker, boss bar, the ability bar with cooldowns, loot banners,
## dialogue boxes, and pause / death / victory screens.

var game: Node2D

# bars
var hp_fill: ColorRect
var mp_fill: ColorRect
var xp_fill: ColorRect
var stats_label: Label
var gold_label: Label

# quest / zone
var zone_label: Label
var quest_label: Label
var title_label: Label
var subtitle_label: Label

# boss bar
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label

# ability bar
var slot_boxes: Array = []      # [{bg, cd, key, name}] for a1,a2,a3,ult,potion

# dialogue
var dialogue_box: Control
var speaker_label: Label
var text_label: Label
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_done: Callable
var dialogue_active := false

var overlay: ColorRect
var vignette: TextureRect
var flash_rect: ColorRect = null
var boss_base_name := ""
var paused_by_menu := false
var banner_y := 110.0

const BAR_W := 280.0
const SLOTS := ["a1", "a2", "a3", "ult", "potion"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	# Vignette (drawn under all UI, over the world). Pulses red at low HP.
	vignette = TextureRect.new()
	vignette.texture = Art.tex("vignette")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# ------------------------------------------------- player stat bars ---
	_panel(Vector2(14, 12), Vector2(BAR_W + 8, 66))
	hp_fill = _bar(Vector2(18, 16), Vector2(BAR_W, 20), Color(0.8, 0.2, 0.2))
	mp_fill = _bar(Vector2(18, 40), Vector2(BAR_W, 14), Color(0.25, 0.45, 0.9))
	xp_fill = _bar(Vector2(18, 58), Vector2(BAR_W, 8), Color(0.95, 0.8, 0.25))
	stats_label = _label(Vector2(18, 82), 15, Color(1, 1, 1))
	gold_label = _label(Vector2(18, 104), 15, Color(1.0, 0.85, 0.35))

	# ---------------------------------------------------- quest tracker ---
	zone_label = _label(Vector2(340, 12), 16, Color(0.95, 0.85, 0.5), 600, HORIZONTAL_ALIGNMENT_CENTER)
	quest_label = _label(Vector2(240, 36), 16, Color(1, 1, 1), 800, HORIZONTAL_ALIGNMENT_CENTER)

	# --------------------------------------------------------- boss bar ---
	boss_box = Control.new()
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_box)
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0, 0, 0, 0.6)
	boss_bg.position = Vector2(388, 86)
	boss_bg.size = Vector2(504, 20)
	boss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_bg)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.7, 0.12, 0.2)
	boss_fill.position = Vector2(390, 88)
	boss_fill.size = Vector2(500, 16)
	boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_fill)
	boss_name = Label.new()
	boss_name.position = Vector2(390, 62)
	boss_name.size = Vector2(500, 20)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 16)
	boss_name.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	_outline(boss_name)
	boss_box.add_child(boss_name)

	# ------------------------------------------------------ big titles ---
	title_label = _label(Vector2(0, 200), 44, Color(1, 1, 1), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label = _label(Vector2(0, 265), 20, Color(0.9, 0.9, 0.9), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	# --------------------------------------------------------- overlay ---
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	move_child(overlay, 1)  # above vignette, behind the labels

	# ------------------------------------------------------ ability bar ---
	_build_ability_bar()

	# ---------------------------------------------------- dialogue box ---
	dialogue_box = Control.new()
	dialogue_box.visible = false
	add_child(dialogue_box)
	var frame := ColorRect.new()
	frame.color = Color(0.9, 0.8, 0.5)
	frame.position = Vector2(138, 498)
	frame.size = Vector2(1004, 150)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.add_child(frame)
	var inner := ColorRect.new()
	inner.color = Color(0.08, 0.07, 0.12, 0.97)
	inner.position = Vector2(141, 501)
	inner.size = Vector2(998, 144)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.add_child(inner)
	speaker_label = Label.new()
	speaker_label.position = Vector2(168, 512)
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	dialogue_box.add_child(speaker_label)
	text_label = Label.new()
	text_label.position = Vector2(168, 542)
	text_label.size = Vector2(944, 90)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 19)
	dialogue_box.add_child(text_label)
	var dhint := Label.new()
	dhint.position = Vector2(1000, 618)
	dhint.text = "SPACE / click ▸"
	dhint.add_theme_font_size_override("font_size", 13)
	dhint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dialogue_box.add_child(dhint)

	# --------------------------------------------------- controls hint ---
	# Two short lines on the far left so they never collide with the
	# ability bar's labels in the bottom center.
	var controls := _label(Vector2(14, 682), 11, Color(0.7, 0.7, 0.7), 400)
	controls.text = "WASD move · TAB target · E talk"
	var controls2 := _label(Vector2(14, 698), 11, Color(0.7, 0.7, 0.7), 400)
	controls2.text = "I inventory · T skills · C codex · ESC menu"
	if game.dev_mode:
		var dev_l := _label(Vector2(1120, 12), 14, Color(1.0, 0.5, 0.4), 150, HORIZONTAL_ALIGNMENT_RIGHT)
		dev_l.text = "DEV (F1)"


const SLOT_SIZE := 60.0

func _build_ability_bar() -> void:
	var x := 640.0 - (5 * 70.0 - 10.0) / 2.0
	var y := 634.0
	for slot in SLOTS:
		var border := ColorRect.new()
		border.color = Color(0.35, 0.35, 0.4)
		border.position = Vector2(x - 3, y - 3)
		border.size = Vector2(SLOT_SIZE + 6, SLOT_SIZE + 6)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.09, 0.9)
		bg.position = Vector2(x, y)
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		# Ability glyph, tinted by the assigned theme's color.
		var icon := TextureRect.new()
		icon.position = Vector2(x + 8, y + 8)
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 16, SLOT_SIZE - 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		# Cooldown "shade" that drains from top to bottom as the ability recharges.
		var cd := ColorRect.new()
		cd.color = Color(0.25, 0.3, 0.45, 0.75)
		cd.position = Vector2(x, y)
		cd.size = Vector2(SLOT_SIZE, 0)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cd)
		# Big countdown number in the middle of the slot.
		var num := _label(Vector2(x, y + 14), 22, Color(1, 1, 1), SLOT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		var key := _label(Vector2(x + 4, y - 1), 12, Color(0.95, 0.85, 0.5), 50)
		var cost := _label(Vector2(x, y + SLOT_SIZE - 20), 12, Color(0.5, 0.7, 1.0), SLOT_SIZE - 5, HORIZONTAL_ALIGNMENT_RIGHT)
		var name_l := _label(Vector2(x - 8, y + SLOT_SIZE + 4), 12, Color(1, 1, 1), SLOT_SIZE + 16, HORIZONTAL_ALIGNMENT_CENTER)
		slot_boxes.append({"border": border, "bg": bg, "icon": icon, "cd": cd, "num": num,
			"key": key, "cost": cost, "name": name_l, "was_ready": true, "flash_ms": 0})
		x += 70.0


# ------------------------------------------------------------- helpers ---

func _panel(pos: Vector2, panel_size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.position = pos
	bg.size = panel_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _bar(pos: Vector2, bar_size: Vector2, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = pos
	bg.size = bar_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos + Vector2(2, 2)
	fill.size = bar_size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	fill.set_meta("full_w", bar_size.x - 4.0)
	return fill


func _label(pos: Vector2, font_size: int, color: Color, width := 500.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, font_size + 14)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_outline(l)
	add_child(l)
	return l


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)


func _set_fill(fill: ColorRect, fraction: float) -> void:
	fill.size.x = maxf(0.0, fill.get_meta("full_w") * clampf(fraction, 0.0, 1.0))


# ----------------------------------------------------------- API used by game

func update_stats(p: Player) -> void:
	# Low-HP warning: the screen edges pulse red below 30% health.
	var hp_frac := p.hp / p.max_hp
	if hp_frac < 0.3 and not p.dead:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		vignette.modulate = Color(1.0 + pulse * 0.6, 1.0 - pulse * 0.5, 1.0 - pulse * 0.5, 1.0 + pulse * 0.6)
	else:
		vignette.modulate = Color(1, 1, 1)
	_set_fill(hp_fill, hp_frac)
	_set_fill(mp_fill, p.mp / p.max_mp)
	_set_fill(xp_fill, float(p.xp) / float(p.xp_needed()))
	var cls_name: String = Classes.CLASSES[p.cls]["name"]
	var pts := "  (+%d pts, press T)" % p.skill_points if p.skill_points > 0 else ""
	stats_label.text = "%s  Lv %d   HP %d/%d   MP %d%s" % [cls_name, p.level, int(p.hp), int(p.max_hp), int(p.mp), pts]
	gold_label.text = "◉ %d gold    Potions [%s] x%d" % [p.gold, OS.get_keycode_string(game.binds["potion"]), p.potions]

	# Ability bar: cooldown shade + countdown number + affordability color.
	var now_ms := Time.get_ticks_msec()
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var box: Dictionary = slot_boxes[i]
		if slot == "potion":
			box["key"].text = OS.get_keycode_string(game.binds["potion"])
			box["name"].text = "Potion"
			box["num"].text = "x%d" % p.potions
			box["cd"].size.y = 0.0
			box["cost"].text = ""
			box["icon"].texture = Art.tex("potion")
			box["border"].color = Color(0.75, 0.35, 0.35) if p.potions > 0 else Color(0.3, 0.15, 0.15)
			continue
		var ab := Classes.ability(p.cls, slot)
		var theme := Classes.theme_by_id(p.cls, p.ability_theme.get(slot, ""))
		box["icon"].texture = Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot],
			theme.get("color", Color(0.85, 0.85, 0.92)))
		var cost := p.ability_cost(slot)
		box["key"].text = OS.get_keycode_string(game.binds[slot])
		box["name"].text = ab["name"]
		box["cost"].text = str(int(cost)) if cost > 0 else ""
		var remaining: float = p.cds[slot]
		var max_cd: float = p.ability_cd(slot)
		var frac: float = clampf(remaining / max_cd, 0.0, 1.0)
		box["cd"].size.y = SLOT_SIZE * frac
		var ready := remaining <= 0.0
		var can_afford: bool = p.mp >= cost

		# Countdown number (only while recharging, and only if it's readable).
		if not ready and remaining >= 0.15:
			box["num"].text = "%.1f" % remaining if remaining < 3.0 else str(int(ceil(remaining)))
		else:
			box["num"].text = ""

		# Flash white the instant an ability comes back up.
		if ready and not box["was_ready"]:
			box["flash_ms"] = now_ms + 300
		box["was_ready"] = ready

		if now_ms < box["flash_ms"]:
			box["border"].color = Color(1, 1, 1)
		elif not ready:
			box["border"].color = Color(0.28, 0.28, 0.33)
		elif not can_afford:
			box["border"].color = Color(0.3, 0.4, 0.8)   # ready but not enough mana
		elif slot == "ult":
			box["border"].color = Color(1.0, 0.65, 0.15)  # ultimate ready: orange
		else:
			box["border"].color = Color(0.85, 0.75, 0.35) # ready: gold


func set_zone(text: String) -> void:
	zone_label.text = text


func set_quest(text: String) -> void:
	quest_label.text = "◆  " + text


func show_boss_bar(bname: String) -> void:
	boss_base_name = bname
	boss_name.text = bname
	boss_box.visible = true


func update_boss_bar(fraction: float) -> void:
	boss_fill.size.x = 500.0 * clampf(fraction, 0.0, 1.0)
	boss_name.text = "%s — %d%%" % [boss_base_name, int(ceil(clampf(fraction, 0.0, 1.0) * 100))]


func hide_boss_bar() -> void:
	boss_box.visible = false


func loot_banner(item: Dictionary, bonus_gold: int) -> void:
	var box := Control.new()
	box.position = Vector2(850, banner_y)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var icon := TextureRect.new()
	icon.texture = Art.icon_for(item)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var l := Label.new()
	l.position = Vector2(40, -2)
	l.size = Vector2(380, 44)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Items.GRADE_COLOR[item["grade"]])
	_outline(l)
	l.text = "+ %s  (+%d gold)\n   %s" % [Items.title(item), bonus_gold, Items.describe(item)]
	box.add_child(l)
	banner_y = 110.0 if banner_y > 260.0 else banner_y + 52.0
	var tween := box.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(box.queue_free)


func flash_title(text: String, sub := "", hold := 1.6) -> void:
	title_label.text = text
	subtitle_label.text = sub
	var tween := create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(hold)
	tween.tween_property(title_label, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.6)


func show_end_screen(text: String, sub: String, color: Color) -> void:
	overlay.color = Color(0, 0, 0, 0.75)
	title_label.add_theme_color_override("font_color", color)
	title_label.text = text
	subtitle_label.text = sub
	title_label.modulate.a = 1.0
	subtitle_label.modulate.a = 1.0


func dim(amount: float) -> void:
	overlay.color = Color(0, 0, 0, amount)


## One-frame impact flash over the whole screen (ults, meteor strikes).
func flash_screen(color: Color, strength := 0.4, dur := 0.3) -> void:
	if flash_rect == null:
		flash_rect = ColorRect.new()
		flash_rect.size = Vector2(1280, 720)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash_rect)
	flash_rect.color = Color(color.r, color.g, color.b, strength)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, dur)


# --------------------------------------------------------------- dialogue

func dialogue(lines: Array, on_done := Callable()) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_done = on_done
	dialogue_active = true
	get_tree().paused = true
	dialogue_box.visible = true
	_show_line()


func _show_line() -> void:
	var line: Array = dialogue_lines[dialogue_index]
	speaker_label.text = line[0]
	text_label.text = line[1]
	game.sfx("talk")


func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		dialogue_active = false
		dialogue_box.visible = false
		get_tree().paused = false
		if dialogue_done.is_valid():
			dialogue_done.call()
	else:
		_show_line()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if game.menus and game.menus.is_open():
		return  # menus layer handles its own input

	var pressed_confirm := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			pressed_confirm = true
		elif event.keycode == KEY_ESCAPE:
			_on_escape()
		elif event.keycode == KEY_B and paused_by_menu:
			_close_pause()
			game.menus.open_keybinds()
		elif event.keycode == KEY_R and game.state == game.ST_VICTORY:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == game.binds.get("target", KEY_TAB) \
				and game.state == game.ST_PLAYING and not dialogue_active and not paused_by_menu:
			game.player.cycle_target()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1 and game.dev_mode and not dialogue_active and not paused_by_menu:
			game.menus.open_dev()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_confirm = true

	if pressed_confirm and dialogue_active:
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func _on_escape() -> void:
	if dialogue_active or game.state != game.ST_PLAYING:
		return
	if paused_by_menu:
		_close_pause()
	else:
		paused_by_menu = true
		get_tree().paused = true
		dim(0.5)
		title_label.add_theme_color_override("font_color", Color(1, 1, 1))
		title_label.text = "PAUSED"
		subtitle_label.text = "ESC resume  ·  B keybinds"
		title_label.modulate.a = 1.0
		subtitle_label.modulate.a = 1.0


func _close_pause() -> void:
	paused_by_menu = false
	get_tree().paused = false
	dim(0.0)
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
