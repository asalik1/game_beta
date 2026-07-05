class_name Hud extends CanvasLayer
## Everything drawn on top of the world: health/mana/xp bars, gold, quest
## tracker, boss bar, the ability bar with cooldowns, loot banners,
## dialogue boxes, and pause / death / victory screens.

var game: Game

# bars
var hp_fill: ColorRect
var mp_fill: ColorRect
var xp_fill: ColorRect
var stats_label: Label
var gold_label: Label
var cr_label: Label
var res_label: Label            # shard resonance, right under Combat Rating
var res_particles: CPUParticles2D
var _last_resonance := -99999.0  # sentinel: no pulse on the first frame

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
# choice dialogue (the branching-conversation engine lives in game.gd)
var choice_panel: Control
var choice_frame: ColorRect
var choice_inner: ColorRect
var choice_option_labels: Array = []
var choices_active := false
var choice_count := 0
var choice_cb := Callable()
var speaker_label: Label
var text_label: Label
var hint_labels: Array = []     # hidden during cutscenes
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_done: Callable
var dialogue_active := false

var overlay: ColorRect
var vignette: TextureRect
var flash_rect: ColorRect = null
var boss_base_name := ""
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
	cr_label = _label(Vector2(18, 126), 15, Color(0.65, 0.9, 1.0))
	# Resonance: golden and sparkling when positive (shinier as it
	# climbs), black-on-pale when negative, pulses on every change.
	res_label = _label(Vector2(18, 148), 15, Color(0.75, 0.75, 0.8))
	res_label.pivot_offset = Vector2(0, 10)
	res_particles = CPUParticles2D.new()
	res_particles.position = Vector2(88, 158)
	res_particles.amount = 6
	res_particles.lifetime = 0.9
	res_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	res_particles.emission_rect_extents = Vector2(78, 8)
	res_particles.direction = Vector2(0, -1)
	res_particles.spread = 20.0
	res_particles.initial_velocity_min = 5.0
	res_particles.initial_velocity_max = 16.0
	res_particles.gravity = Vector2(0, -12)
	res_particles.scale_amount_min = 1.0
	res_particles.scale_amount_max = 2.4
	res_particles.color = Color(1.0, 0.9, 0.45)
	res_particles.emitting = false
	add_child(res_particles)

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

	# ------------------------------------------- choice options panel ---
	# Sits directly above the dialogue box when a conversation offers a
	# decision; pick with the number keys.
	choice_panel = Control.new()
	choice_panel.visible = false
	add_child(choice_panel)
	choice_frame = ColorRect.new()
	choice_frame.color = Color(0.9, 0.8, 0.5)
	choice_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_panel.add_child(choice_frame)
	choice_inner = ColorRect.new()
	choice_inner.color = Color(0.10, 0.09, 0.15, 0.97)
	choice_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_panel.add_child(choice_inner)
	for i in 4:
		var opt := Label.new()
		opt.add_theme_font_size_override("font_size", 17)
		opt.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
		opt.visible = false
		choice_panel.add_child(opt)
		choice_option_labels.append(opt)

	# --------------------------------------------------- controls hint ---
	# Two short lines on the far left so they never collide with the
	# ability bar's labels in the bottom center.
	var controls := _label(Vector2(14, 682), 11, Color(0.7, 0.7, 0.7), 400)
	controls.text = "WASD move · TAB target · E talk · M map"
	var controls2 := _label(Vector2(14, 698), 11, Color(0.7, 0.7, 0.7), 400)
	controls2.text = "I inventory · T skills · C codex · ESC menu"
	hint_labels = [controls, controls2]
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
	_set_fill(xp_fill, float(p.xp) / float(p.xp_needed()))
	var cls_name: String = Classes.CLASSES[p.cls]["name"]
	var pts := "  (+%d pts, press T)" % p.skill_points if p.skill_points > 0 else ""
	if Classes.CLASSES[p.cls].get("manaless", false):
		# Manaless classes (assassin, round 31): no MP line, no blue bar.
		stats_label.text = "%s  Lv %d   HP %d/%d%s" % [cls_name, p.level, int(p.hp), int(p.max_hp), pts]
		_set_fill(mp_fill, 0.0)
	else:
		stats_label.text = "%s  Lv %d   HP %d/%d   MP %d/%d%s" % [cls_name, p.level, int(p.hp), int(p.max_hp), int(p.mp), int(p.max_mp), pts]
		_set_fill(mp_fill, p.mp / p.max_mp)
	gold_label.text = "◉ %d gold    Potions [%s] x%d" % [p.gold, OS.get_keycode_string(game.binds["potion"]), p.potions]
	cr_label.text = "Combat Rating: %d" % p.combat_rating()
	_update_resonance(p.resonance)

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
		# Readability: the mana price reads red the moment you can't pay it.
		box["cost"].add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.35) if p.mp < cost else Color(0.5, 0.7, 1.0))
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


## Cinematic mode: the few HUD bits a cutscene can't cover get hidden.
func set_cinematic(on: bool) -> void:
	for l in hint_labels:
		l.visible = not on


## A dialogue line that ends in a DECISION: the text shows in the normal
## box, the options stack above it, and the number keys choose.
func dialogue_choice(who: String, text: String, options: Array, cb: Callable) -> void:
	get_tree().paused = true
	dialogue_box.visible = true
	speaker_label.text = who
	text_label.text = text
	game.sfx("talk")
	choice_cb = cb
	choice_count = options.size()
	choices_active = true
	var h := choice_count * 30 + 16
	choice_frame.position = Vector2(138, 492 - h)
	choice_frame.size = Vector2(1004, h)
	choice_inner.position = choice_frame.position + Vector2(3, 3)
	choice_inner.size = choice_frame.size - Vector2(6, 6)
	for i in choice_option_labels.size():
		var opt: Label = choice_option_labels[i]
		opt.visible = i < choice_count
		if i < choice_count:
			opt.text = "%d.  %s" % [i + 1, options[i]]
			opt.position = Vector2(168, 492 - h + 10 + i * 30)
	choice_panel.visible = true


func _choose(idx: int) -> void:
	if not choices_active or idx < 0 or idx >= choice_count:
		return
	choices_active = false
	choice_panel.visible = false
	dialogue_box.visible = false
	get_tree().paused = false
	game.sfx("talk")
	var cb := choice_cb
	choice_cb = Callable()
	if cb.is_valid():
		cb.call(idx)  # the convo engine re-opens the box synchronously


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if game.menus and game.menus.is_open():
		return  # menus layer handles its own input

	# A decision on screen swallows everything except its number keys.
	if choices_active:
		if event is InputEventKey and event.pressed and not event.echo:
			_choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		return

	var pressed_confirm := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E] \
				and game.state == game.ST_VICTORY \
				and Story.next_chapter(game.chapter_id) != "":
			# Mid-campaign victory card: carry this character onward.
			game.advance_chapter()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			pressed_confirm = true
		elif event.keycode == KEY_ESCAPE:
			_on_escape()
		elif event.keycode == KEY_R and game.state == game.ST_VICTORY:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == game.binds.get("target", KEY_TAB) \
				and game.state == game.ST_PLAYING and not dialogue_active:
			game.player.cycle_target()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1 and game.dev_mode and not dialogue_active:
			game.menus.open_dev()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_confirm = true

	if pressed_confirm and dialogue_active:
		_advance_dialogue()
		get_viewport().set_input_as_handled()


## ESC opens the system menu (menus.gd owns closing it again).
func _on_escape() -> void:
	if dialogue_active or choices_active or not game.play_started \
			or game.state != game.ST_PLAYING or game.menus.is_open():
		return
	game.menus.open_pause()
	get_viewport().set_input_as_handled()


## The shard's mood, worn on the HUD (round 8): gold that gets shinier
## and busier with sparkles as Resonance climbs; ink-black when it
## falls. Any change pulses the label — bright for gains, violet for
## losses.
func _update_resonance(res: float) -> void:
	res_label.text = "Resonance: %+d" % int(res) if int(res) != 0 else "Resonance: 0"
	if res > 0.0:
		var shine := clampf(res / 100.0, 0.0, 1.0)
		res_label.add_theme_color_override("font_color",
			Color(0.84, 0.7, 0.32).lerp(Color(1.0, 0.96, 0.6), shine))
		res_label.add_theme_color_override("font_outline_color", Color(0.25, 0.18, 0.02))
		res_label.add_theme_constant_override("outline_size", 3)
		var want := clampi(4 + int(res / 7.0), 4, 20)
		if res_particles.amount != want:
			res_particles.amount = want
		res_particles.emitting = true
	elif res < 0.0:
		res_label.add_theme_color_override("font_color", Color(0.05, 0.04, 0.07))
		res_label.add_theme_color_override("font_outline_color", Color(0.6, 0.6, 0.65, 0.7))
		res_label.add_theme_constant_override("outline_size", 3)
		res_particles.emitting = false
	else:
		res_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		res_label.add_theme_constant_override("outline_size", 0)
		res_particles.emitting = false
	if _last_resonance <= -99998.0:
		_last_resonance = res  # first frame / fresh load: no pulse
		return
	if absf(res - _last_resonance) >= 0.5:
		res_label.scale = Vector2(1.5, 1.5)
		res_label.modulate = Color(2.2, 2.0, 1.2) if res > _last_resonance else Color(0.55, 0.35, 0.8)
		var tw := create_tween()
		tw.tween_property(res_label, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(res_label, "modulate", Color(1, 1, 1), 0.6)
	_last_resonance = res
