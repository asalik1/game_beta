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
var res_orb_glow: Sprite2D      # mood orb left of the number: gold fire..dark fire
var res_orb_core: Sprite2D      # pearl heart of the orb
var _last_resonance := -99999.0  # sentinel: no pulse on the first frame
var mail_btn: Button            # ✉ under Resonance — click to open the mailbox
var mail_badge: Panel           # red unread-count circle on the ✉
var mail_badge_num: Label
var daily_btn: Button           # ★ beside the ✉ — shown only when a daily waits
var daily_glow: Sprite2D        # pulsing shine behind the ★

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

# buff timer bar (active-effect row above the ability bar)
var buff_slots: Array = []      # pooled [{border,box,name,time,fill}] widgets
var _buff_peak := {}            # buff id -> peak seconds seen (for the drain fill)

# corner minimap (top-right; rebuilt only when the charted world changes)
var minimap_root: Control
var minimap_cells: Control
var _minimap_sig := ""

# dialogue
var dialogue_box: Control
var portrait_box: Control          # speaker portrait (right side of the box)
var portrait_rect: TextureRect
var _portrait_cache := {}          # speaker name -> sprite name ("" = none)
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
var results_box: Control = null   # chapter results card (victory screen)
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
	cr_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cr_label.tooltip_text = _wrap_tip("Combat Rating — one number approximating your total power: gear and gems, level, attributes and skill tree combined.")
	# Resonance: golden and sparkling when positive (shinier as it
	# climbs), black-on-pale when negative, pulses on every change.
	# Nudged right to seat the mood orb on its left.
	res_label = _label(Vector2(46, 147), 16, Color(0.75, 0.75, 0.8))
	res_label.pivot_offset = Vector2(0, 10)
	res_label.mouse_filter = Control.MOUSE_FILTER_PASS
	res_label.tooltip_text = _wrap_tip("Resonance — how your shard leans: Virtue (+) or Temptation (−). Major choices move it, and the world answers through dialogue and merchant haggling.")
	# Resonance mood orb: a glowing bead just left of the number — golden
	# fire when strongly Virtuous (+50), a dark flame when Tempted (-50),
	# a calm white pearl at neutral, gradients between. Two glow sprites
	# (outer aura + pearl heart) driven by _update_resonance_orb.
	res_orb_glow = Sprite2D.new()
	res_orb_glow.texture = Art.tex("glow")
	res_orb_glow.position = Vector2(30, 161)
	add_child(res_orb_glow)
	res_orb_core = Sprite2D.new()
	res_orb_core.texture = Art.tex("glow")
	res_orb_core.position = Vector2(30, 161)
	add_child(res_orb_core)
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

	# Mailbox shortcut: an envelope right under Resonance so letters (boss
	# victory reports, dropped-loot, gifts) are reachable without the pause
	# menu. A red unread badge rides its corner. Uses the ✉ glyph the pause
	# menu already shows — the "icon_mail" texture is chainmail ARMOR, not
	# an envelope.
	mail_btn = Button.new()
	mail_btn.flat = true
	mail_btn.text = "✉"
	mail_btn.tooltip_text = "Mailbox"
	mail_btn.add_theme_font_size_override("font_size", 22)
	mail_btn.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	mail_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	mail_btn.position = Vector2(16, 178)
	mail_btn.size = Vector2(34, 30)
	mail_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_mailbox())
	add_child(mail_btn)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.86, 0.16, 0.16)
	badge_style.set_corner_radius_all(9)  # 18px box + r9 = a circle
	mail_badge = Panel.new()
	mail_badge.add_theme_stylebox_override("panel", badge_style)
	mail_badge.position = Vector2(40, 174)
	mail_badge.size = Vector2(18, 18)
	mail_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mail_badge.visible = false
	add_child(mail_badge)
	mail_badge_num = Label.new()
	mail_badge_num.add_theme_font_size_override("font_size", 12)
	mail_badge_num.add_theme_color_override("font_color", Color(1, 1, 1))
	mail_badge_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mail_badge_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mail_badge_num.size = Vector2(18, 18)
	mail_badge_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mail_badge.add_child(mail_badge_num)

	# Daily-reward star: appears beside the ✉ only when a reward is waiting,
	# with a pulsing golden SHINE behind it to draw the eye. Click opens the
	# claim screen. The glow is added first so it sits BEHIND the star.
	daily_glow = Sprite2D.new()
	daily_glow.texture = Art.tex("glow")
	daily_glow.position = Vector2(68, 189)  # centered on the ★
	daily_glow.modulate = Color(1.0, 0.85, 0.35, 0.0)
	daily_glow.visible = false
	add_child(daily_glow)
	daily_btn = Button.new()
	daily_btn.flat = true
	daily_btn.text = "★"
	daily_btn.tooltip_text = "Daily reward ready!"
	daily_btn.add_theme_font_size_override("font_size", 22)
	daily_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	daily_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	daily_btn.position = Vector2(52, 173)  # nudged up to line up with the ✉
	daily_btn.size = Vector2(32, 30)
	daily_btn.visible = false
	daily_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_daily())
	add_child(daily_btn)

	# ---------------------------------------------------- quest tracker ---
	zone_label = _label(Vector2(340, 12), 16, Color(0.95, 0.85, 0.5), 600, HORIZONTAL_ALIGNMENT_CENTER)
	quest_label = _label(Vector2(240, 36), 16, Color(1, 1, 1), 800, HORIZONTAL_ALIGNMENT_CENTER)
	# ⚑ opens the Quest Log — sits just left of the objective line.
	var journal_btn := Button.new()
	journal_btn.flat = true
	journal_btn.text = "⚑"
	journal_btn.tooltip_text = "Quest Log"
	journal_btn.add_theme_font_size_override("font_size", 18)
	journal_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	journal_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.75))
	journal_btn.position = Vector2(210, 33)
	journal_btn.size = Vector2(28, 26)
	journal_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_journal())
	add_child(journal_btn)

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
	_build_buff_bar()
	_build_minimap()

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
	text_label.size = Vector2(820, 90)  # leaves the portrait slot clear
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 19)
	dialogue_box.add_child(text_label)
	var dhint := Label.new()
	dhint.position = Vector2(856, 618)
	dhint.text = "SPACE / click ▸"
	dhint.add_theme_font_size_override("font_size", 13)
	dhint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dialogue_box.add_child(dhint)

	# Speaker portrait (visual pass): the cast's face beside their words,
	# in a reserved slot on the box's right (Crawl art faces left — into
	# the text). Hidden for the Narrator and unknown speakers.
	portrait_box = Control.new()
	portrait_box.visible = false
	dialogue_box.add_child(portrait_box)
	var pframe := ColorRect.new()
	pframe.color = Color(0.9, 0.8, 0.5)
	pframe.position = Vector2(1002, 506)
	pframe.size = Vector2(134, 134)
	pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(pframe)
	var pinner := ColorRect.new()
	pinner.color = Color(0.1, 0.09, 0.15, 1.0)
	pinner.position = Vector2(1005, 509)
	pinner.size = Vector2(128, 128)
	pinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(pinner)
	portrait_rect = TextureRect.new()
	portrait_rect.position = Vector2(1011, 515)
	portrait_rect.size = Vector2(116, 116)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait_rect)

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
		# PASS (not IGNORE): the border is the slot's hover target — Godot's
		# built-in tooltip needs a non-ignoring control, and PASS still lets
		# the click fall through to _unhandled_input (dialogue advance).
		border.mouse_filter = Control.MOUSE_FILTER_PASS
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


const BUFF_SLOTS := 8
const BUFF_W := 48.0

## A pooled row of active-effect chips sitting just above the ability
## bar: a colored border, the buff's short name, its remaining seconds,
## and a draining fill. Hidden slots collapse; _update_buffs fills them
## left-to-right each frame.
func _build_buff_bar() -> void:
	var x0 := 470.0   # left edge of the ability bar
	var y := 590.0    # just above it (bar sits at y=634)
	for i in BUFF_SLOTS:
		var x := x0 + i * (BUFF_W + 6.0)
		var border := ColorRect.new()
		border.position = Vector2(x - 2, y - 2)
		border.size = Vector2(BUFF_W + 4, 40)
		# PASS: the chip's hover target for its tooltip (see ability bar note).
		border.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(border)
		var box := ColorRect.new()
		box.color = Color(0.06, 0.06, 0.10, 0.9)
		box.position = Vector2(x, y)
		box.size = Vector2(BUFF_W, 36)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var icon := TextureRect.new()
		icon.position = Vector2(x + 13, y + 1)
		icon.custom_minimum_size = Vector2(22, 22)
		icon.size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var time_l := _label(Vector2(x, y + 21), 14, Color(1, 1, 1), BUFF_W, HORIZONTAL_ALIGNMENT_CENTER)
		var fill := ColorRect.new()
		fill.position = Vector2(x, y + 33)
		fill.size = Vector2(BUFF_W, 3)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
		var slot := {"border": border, "box": box, "icon": icon, "time": time_l, "fill": fill, "glyph": ""}
		_set_buff_slot_visible(slot, false)
		buff_slots.append(slot)


func _set_buff_slot_visible(slot: Dictionary, vis: bool) -> void:
	slot["border"].visible = vis
	slot["box"].visible = vis
	slot["icon"].visible = vis
	slot["time"].visible = vis
	slot["fill"].visible = vis


## Every player state worth a chip. Timed buffs carry "t" = seconds left;
## PERSISTENT states (paladin stance, warrior Grit, Second Wind) set t < 0
## — their chip holds a full bar with no countdown. Optional "text"
## replaces the countdown (Grit shows its stack count). "tip" feeds the
## hover tooltip and reads LIVE numbers off the player, so talents and
## gear are reflected truthfully. The glyph reuses an ability icon that
## fits the buff; colors echo the on-hero aura so the chip and the aura
## read as one language.
func _active_buffs() -> Array:
	var p: Player = game.player
	var out: Array = []
	# Persistent class states lead the row, so chips don't reshuffle as
	# timed buffs come and go around them.
	if p.cls == "paladin":
		if p.paladin_mode == "holy":
			out.append({"id": "holy", "glyph": "ab_sun", "color": Color(1.0, 0.92, 0.55), "t": -1.0,
				"tip": "HOLY stance — every blow you land mends %.0f%% max HP (a third on AoE), but you deal %d%% less damage. Conviction swaps stances." % [
					Balance.PALADIN_HOLY_MEND * 100.0, int(round((1.0 - Balance.PALADIN_HOLY_DMG) * 100.0))]})
		else:
			out.append({"id": "retri", "glyph": "ab_hammer", "color": Color(1.0, 0.45, 0.22), "t": -1.0,
				"tip": "RETRIBUTION stance — +%d%% damage, but your blows no longer mend you. Conviction swaps stances (returning to Holy mends %.0f%% max HP)." % [
					int(round((Balance.PALADIN_RETRI_DMG - 1.0) * 100.0)), Balance.PALADIN_SWAP_HEAL * 100.0]})
	if p.grit_stacks > 0:
		out.append({"id": "grit", "glyph": "ab_shield", "color": Color(1.0, 0.75, 0.35),
			"t": p.grit_time, "text": "x%d" % p.grit_stacks,
			"tip": "GRIT x%d — +%.1f%% max HP/s recovery. Every enemy blow taken adds a stack (max %d) and refreshes the window; stay unhit and the stacks lapse." % [
				p.grit_stacks, p.grit_regen * p.grit_stacks * 100.0, int(p.grit_cap)]})
	if p.sw_regen > 0.0 and not p.dead and p.since_hurt >= p.sw_delay:
		out.append({"id": "second_wind", "glyph": "ic_hp", "color": Color(0.55, 1.0, 0.65), "t": -1.0,
			"tip": "Second Wind — untouched for %.1fs: recovering +%.0f%% max HP/s. Taking a hit resets the clock." % [
				p.sw_delay, p.sw_regen * 100.0]})
	# Timed buffs.
	if p.berserk_time > 0.0: out.append({"id": "berserk", "glyph": "ab_fist", "color": Color(1.0, 0.3, 0.2), "t": p.berserk_time,
		"tip": "Berserk — +%d%% damage, +25%% move speed, +15%% lifesteal." % int(p.berserk_bonus * 100.0)})
	if p.aegis_time > 0.0: out.append({"id": "aegis", "glyph": "ab_shield", "color": Color(1.0, 0.85, 0.4), "t": p.aegis_time,
		"tip": "Aegis — +%d resistances, and attackers are smitten in return." % int(p.aegis_amt)})
	if p.dr_time > 0.0: out.append({"id": "ward", "glyph": "ab_blink", "color": Color(0.45, 0.85, 1.0), "t": p.dr_time,
		"tip": "Arcane Ward — incoming damage cut by %d%% (true damage pierces it)." % int(p.dr_amt * 100.0)})
	if p.pact_time > 0.0: out.append({"id": "pact", "glyph": "ab_pact", "color": Color(0.9, 0.2, 0.4), "t": p.pact_time,
		"tip": "Dark Pact — +%d%% lifesteal while the pact holds." % int(p.pact_ls * 100.0)})
	if p.theme_guard_time > 0.0: out.append({"id": "guard", "glyph": "ab_shield", "color": Color(0.45, 0.65, 1.0), "t": p.theme_guard_time,
		"tip": "Guard — +%d physical & magic resistance." % int(p.theme_guard_amt)})
	if p.theme_speed_time > 0.0: out.append({"id": "speed", "glyph": "ab_roll", "color": Color(0.6, 1.0, 0.85), "t": p.theme_speed_time,
		"tip": "Fleet — +%d%% move speed." % int(p.theme_speed_amt * 100.0)})
	if p.elixir_time > 0.0: out.append({"id": "elixir", "glyph": "ab_fist", "color": Color(1.0, 0.6, 0.3), "t": p.elixir_time,
		"tip": "Elixir of Might — +%d%% damage." % int(p.elixir_atk * 100.0)})
	if p.stab_ls_time > 0.0: out.append({"id": "surge", "glyph": "ab_dagger", "color": Color(0.95, 0.3, 0.35), "t": p.stab_ls_time,
		"tip": "Blood Surge — +%d%% lifesteal, and Fan of Knives bites TWICE as hard. A connecting Stab or Shadow Dash refreshes it." % int(p.stab_ls_amt * 100.0)})
	if p.dodge_time > 0.0: out.append({"id": "dodge", "glyph": "ab_roll", "color": Color(0.8, 0.95, 0.7), "t": p.dodge_time,
		"tip": "Nimble — +%d%% evasion while the roll's momentum carries." % int(p.dodge_amt * 100.0)})
	if p.storm_time > 0.0: out.append({"id": "storm", "glyph": "ab_rain", "color": Color(0.6, 1.0, 0.6), "t": p.storm_time,
		"tip": "Arrow Storm — arrows rain on every enemy near you."})
	if p.cast_haste_time > 0.0: out.append({"id": "haste", "glyph": "ab_flame", "color": Color(0.7, 0.95, 1.0), "t": p.cast_haste_time,
		"tip": "Tailwind — Blink & Frost Nova cool down %d%% faster." % int(p.cast_haste_cdr * 100.0)})
	return out


func _update_buffs() -> void:
	var active := _active_buffs()
	# Peak tracking gives each chip a drain bar without knowing its grant
	# duration: the fill is remaining / the longest we've seen it hold.
	# Persistent chips (t < 0) skip it and simply hold a full bar.
	var live := {}
	for b in active:
		if float(b["t"]) < 0.0:
			continue
		live[b["id"]] = true
		_buff_peak[b["id"]] = maxf(float(_buff_peak.get(b["id"], 0.0)), float(b["t"]))
	for id in _buff_peak.keys():
		if not live.has(id):
			_buff_peak.erase(id)
	for i in buff_slots.size():
		var slot: Dictionary = buff_slots[i]
		if i >= active.size():
			_set_buff_slot_visible(slot, false)
			slot["border"].tooltip_text = ""
			continue
		var b: Dictionary = active[i]
		var col: Color = b["color"]
		var t: float = b["t"]
		_set_buff_slot_visible(slot, true)
		slot["border"].color = col
		slot["border"].tooltip_text = _wrap_tip(String(b.get("tip", "")))
		var glyph: String = String(b["glyph"])
		# glyph_tex is cached per (name,tint); only rebuild when this slot's
		# icon actually changes, so we don't thrash the cache every frame.
		if slot["glyph"] != glyph:
			slot["glyph"] = glyph
			slot["icon"].texture = Art.glyph_tex(glyph, col.lightened(0.15))
		slot["fill"].color = col
		if t < 0.0:
			# Persistent state: no countdown, full bar; Grit-style chips show
			# their stack text instead.
			slot["time"].text = String(b.get("text", ""))
			slot["fill"].size.x = BUFF_W
		else:
			slot["time"].text = String(b["text"]) if b.has("text") \
				else ("%.0f" % ceil(t) if t >= 1.0 else "%.1f" % t)
			var peak: float = maxf(float(_buff_peak.get(b["id"], t)), 0.01)
			slot["fill"].size.x = BUFF_W * clampf(t / peak, 0.0, 1.0)


const MINIMAP_AREA := Vector2(182, 116)

## Persistent top-right minimap: the charted room graph in miniature, with
## the current room framed gold and seen-but-unentered boss doors pipped
## red. Built once; _update_minimap redraws only when the world changes.
func _build_minimap() -> void:
	minimap_root = Control.new()
	minimap_root.position = Vector2(1066, 84)
	minimap_root.size = Vector2(198, 170)
	minimap_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.visible = false
	add_child(minimap_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.09, 0.7)
	bg.size = Vector2(198, 170)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(bg)
	var title := Label.new()
	title.text = "MAP  (M)"
	title.position = Vector2(8, 3)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.77, 0.83))
	minimap_root.add_child(title)
	var legend := Label.new()
	legend.text = "◆ here   ☠ boss   ✓ cleared"
	legend.position = Vector2(8, 150)
	legend.add_theme_font_size_override("font_size", 10)
	legend.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(legend)
	minimap_cells = Control.new()
	minimap_cells.position = Vector2(8, 26)
	minimap_cells.size = MINIMAP_AREA
	minimap_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(minimap_cells)


func _update_minimap() -> void:
	if not game.play_started or game.rooms.is_empty():
		minimap_root.visible = false
		return
	minimap_root.visible = true
	# Cheap change-detection: only the counts that alter the drawing.
	var sig := "%d|%d|%d|%d" % [game.cur_room, game.visited.size(),
		game.door_seen.size(), game.boss_done.size()]
	if sig == _minimap_sig:
		return
	_minimap_sig = sig
	for c in minimap_cells.get_children():
		minimap_cells.remove_child(c)
		c.queue_free()

	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-(1 << 20), -(1 << 20))
	var have := false
	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		have = true
		var c: Vector2i = game.rooms[i]["coord"]
		min_c = Vector2i(mini(min_c.x, c.x - 1), mini(min_c.y, c.y - 1))
		max_c = Vector2i(maxi(max_c.x, c.x + 1), maxi(max_c.y, c.y + 1))
	if not have:
		return
	var cols := max_c.x - min_c.x + 1
	var rows := max_c.y - min_c.y + 1
	var gap := 3.0
	var cw := clampf((MINIMAP_AREA.x - (cols - 1) * gap) / cols, 6.0, 22.0)
	var ch := clampf((MINIMAP_AREA.y - (rows - 1) * gap) / rows, 5.0, 18.0)
	var org := Vector2(maxf(0.0, (MINIMAP_AREA.x - cols * (cw + gap)) / 2.0),
		maxf(0.0, (MINIMAP_AREA.y - rows * (ch + gap)) / 2.0))
	var cell_pos := func(c: Vector2i) -> Vector2:
		return org + Vector2((c.x - min_c.x) * (cw + gap), (c.y - min_c.y) * (ch + gap))

	# Links + seen-boss-door pips, under the room cells.
	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		var p: Vector2 = cell_pos.call(game.rooms[i]["coord"])
		for dir in game.rooms[i]["exits"].keys():
			var nb: int = game.neighbor(i, String(dir))
			if nb < 0:
				continue
			var delta: Vector2i = Game.DIRS[dir]
			var mid := p + Vector2(cw / 2.0, ch / 2.0)
			var nb_vis: bool = game.visited.get(nb, false)
			var to := mid + Vector2(delta.x * (cw + gap), delta.y * (ch + gap)) * 0.5 * (1.0 if nb_vis else 0.6)
			var link := ColorRect.new()
			link.color = Color(0.5, 0.47, 0.4, 0.9) if nb_vis else Color(0.4, 0.38, 0.34, 0.8)
			link.position = Vector2(minf(mid.x, to.x) - 1.0, minf(mid.y, to.y) - 1.0)
			link.size = Vector2(absf(to.x - mid.x) + 2.0, absf(to.y - mid.y) + 2.0)
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			minimap_cells.add_child(link)
			if not nb_vis and game.room_type(nb) == "boss" and game.door_seen.get(nb, false):
				var pip := ColorRect.new()
				pip.color = Color(1.0, 0.5, 0.55)
				pip.position = to - Vector2(2, 2)
				pip.size = Vector2(4, 4)
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				minimap_cells.add_child(pip)

	# Room cells (current room framed gold; cleared boss rooms tinted green).
	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		var p: Vector2 = cell_pos.call(game.rooms[i]["coord"])
		var t: String = game.room_type(i)
		if i == game.cur_room:
			var hl := ColorRect.new()
			hl.color = Color(0.95, 0.85, 0.5)
			hl.position = p - Vector2(2, 2)
			hl.size = Vector2(cw + 4, ch + 4)
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			minimap_cells.add_child(hl)
		var col: Color = Menus.MAP_TYPE_COLOR.get(t, Color(0.3, 0.3, 0.3))
		if t == "boss":
			var kind := String(game.zones[i].get("boss", ""))
			if kind != "" and game.boss_done.get(kind, false):
				col = col.lerp(Color(0.3, 0.55, 0.35), 0.55)
		var cell := ColorRect.new()
		cell.color = col.lightened(0.15) if i == game.cur_room else col
		cell.position = p
		cell.size = Vector2(cw, ch)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap_cells.add_child(cell)

		# Room-type marker. Boss/current/cleared markers always show; the
		# quieter room-type glyphs only when the cell is big enough to read.
		var icon_text := String(Menus.MAP_TYPE_ICON.get(t, ""))
		if t == "boss":
			var bk := String(game.zones[i].get("boss", ""))
			icon_text = "✓" if (bk != "" and game.boss_done.get(bk, false)) else "☠"
		if i == game.cur_room:
			icon_text = "◆"
		if icon_text != "" and (cw >= 12.0 or icon_text in ["◆", "☠", "✓"]):
			var il := Label.new()
			il.text = icon_text
			il.position = p
			il.size = Vector2(cw, ch)
			il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			il.add_theme_font_size_override("font_size", int(clampf(minf(cw, ch) * 0.82, 8.0, 15.0)))
			il.add_theme_color_override("font_color",
				Color(0.12, 0.09, 0.05) if i == game.cur_room else Color(0.95, 0.92, 0.8))
			il.mouse_filter = Control.MOUSE_FILTER_IGNORE
			minimap_cells.add_child(il)


## A gold banner sliding in at the top when an achievement unlocks; holds
## a few seconds, then fades. Stacks downward if several land together.
func achievement_toast(name: String, desc: String) -> void:
	var stacked := get_tree().get_nodes_in_group("ach_toast").size()
	var panel := Panel.new()
	panel.add_to_group("ach_toast")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.05, 0.95)
	sb.border_color = Color(1.0, 0.85, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(440, 58)
	# Below the boss bar (which sits ~y86-130, center) so a mid-fight unlock
	# never covers the boss's health.
	panel.position = Vector2(640 - 220, 138 + stacked * 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "★  Achievement Unlocked"
	title.position = Vector2(14, 6)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	panel.add_child(title)
	var nm := Label.new()
	nm.text = name + " — " + desc
	nm.position = Vector2(14, 26)
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(nm)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


# ------------------------------------------------------------- helpers ---

## Godot's default tooltip label never wraps, so a paragraph-long ability
## desc would stretch one line across the screen — fold it by words here.
static func _wrap_tip(text: String, width := 56) -> String:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			if line != "" and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		out.append(line)
	return "\n".join(out)


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
	if game.player_title != "" and Achievements.TITLES.has(game.player_title):
		# The worn title rides the class name (codex Records tab to change).
		cls_name += ", %s" % String(Achievements.TITLES[game.player_title]["name"])
	var pts := "  (+%d pts, press T)" % p.skill_points if p.skill_points > 0 else ""
	if Classes.CLASSES[p.cls].get("manaless", false):
		# Manaless classes (assassin, round 31): no MP line, no blue bar.
		stats_label.text = "%s  Lv %d   HP %d/%d%s" % [cls_name, p.level, int(p.hp), int(p.max_hp), pts]
		_set_fill(mp_fill, 0.0)
	else:
		stats_label.text = "%s  Lv %d   HP %d/%d   MP %d/%d%s" % [cls_name, p.level, int(p.hp), int(p.max_hp), int(p.mp), int(p.max_mp), pts]
		_set_fill(mp_fill, p.mp / p.max_mp)
	gold_label.text = "◉ %d gold    Potions [%s] x%d" % [p.gold, OS.get_keycode_string(game.binds["potion"]), p.potions]
	if p.gold >= 5000:
		game.unlock_achievement("wealthy")  # idempotent: fires once
	cr_label.text = "Combat Rating: %d" % p.combat_rating()
	_update_resonance(p.resonance)

	# Unread-mail badge: red circle with the count (9+ past nine).
	var unread := 0
	for m in game.mailbox:
		if not m["read"]:
			unread += 1
	mail_badge.visible = unread > 0
	if unread > 0:
		mail_badge_num.text = str(unread) if unread < 10 else "9+"

	# Daily star: visible only when a reward waits, with a pulsing golden
	# shine behind it to catch the eye.
	daily_btn.visible = game.daily_available()
	daily_glow.visible = daily_btn.visible
	if daily_btn.visible:
		var t := Time.get_ticks_msec() * 0.001
		var pulse := 0.5 + 0.5 * sin(t * 3.6)
		daily_btn.modulate = Color(1.0, 1.0, 1.0, 0.75 + 0.25 * pulse)
		# Shine: the glow breathes in size and brightness under the star.
		daily_glow.modulate = Color(1.0, 0.88, 0.4, 0.25 + 0.4 * pulse)
		daily_glow.scale = Vector2.ONE * (0.5 + 0.16 * pulse)

	_update_buffs()
	_update_minimap()
	game.refresh_bounties()  # rolls the daily/weekly sets when the clock ticks over

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
			box["border"].tooltip_text = _wrap_tip(
				"Health Potion — drink to mend 60%% of your max HP (x%d carried, max %d). Boss kills restock you up to %d." % [
					p.potions, Balance.POTION_MAX, Balance.BOSS_KILL_POTION_FLOOR])
			continue
		var ab := Classes.ability(p.cls, slot)
		var theme := Classes.theme_by_id(p.cls, p.ability_theme.get(slot, ""))
		box["icon"].texture = Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot],
			theme.get("color", Color(0.85, 0.85, 0.92)))
		var cost := p.ability_cost(slot)
		box["key"].text = OS.get_keycode_string(game.binds[slot])
		box["name"].text = ab["name"]
		box["cost"].text = str(int(cost)) if cost > 0 else ""
		# Hover card: name/key/cost/cd, the ability's own words, then the
		# assigned theme's variant line — built from live values, so cd
		# talents and mana amods read truthfully.
		var tip := "%s  [%s]" % [String(ab["name"]), OS.get_keycode_string(game.binds[slot])]
		if cost > 0:
			tip += "  ·  %d mana" % int(cost)
		tip += "  ·  %.1fs cooldown" % p.ability_cd(slot)
		tip += "\n" + String(ab["desc"])
		var theme_id: String = p.ability_theme.get(slot, "")
		if theme_id != "":
			var vdesc := Classes.variant_desc(p.cls, slot, theme_id)
			if vdesc != "":
				tip += "\n★ %s: %s" % [String(theme.get("name", theme_id)), vdesc]
		box["border"].tooltip_text = _wrap_tip(tip)
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


## BOSS TITLE CARD (visual pass): the name SLAMS in red — scale punch,
## fast in, a beat, gone. Rides the big title labels; restores their
## default white afterwards so zone titles stay unaffected.
func boss_banner(boss_name: String) -> void:
	title_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26))
	title_label.text = boss_name
	subtitle_label.text = ""
	title_label.pivot_offset = Vector2(640, 22)
	title_label.scale = Vector2(1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: game.shake(8.0))
	tween.tween_interval(1.5)
	tween.tween_property(title_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		title_label.add_theme_color_override("font_color", Color(1, 1, 1))
		title_label.scale = Vector2.ONE)


func flash_title(text: String, sub := "", hold := 1.6) -> void:
	title_label.text = text
	subtitle_label.text = sub
	# Every arrival (boot, load, replay, next chapter) fades in from
	# black instead of cutting — the title rises out of the dark.
	overlay.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.55)
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.4)
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


## The chapter results card (retention roadmap #1): the run's numbers, a
## big grade letter, and NEW BEST callouts. Rides the victory screen —
## the process_mode override keeps it visible through the pause.
func show_results(res: Dictionary, pb: Dictionary) -> void:
	hide_results()
	results_box = Control.new()
	results_box.position = Vector2(400, 386)
	results_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(results_box)

	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.05, 0.09, 0.85)
	panel.position = Vector2(0, 0)
	panel.size = Vector2(480, 232)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_box.add_child(panel)

	# The grade, big, in its gear-grade color (shared rarity language).
	var grade := String(res.get("grade", "D"))
	var gl := Label.new()
	gl.text = grade
	gl.position = Vector2(354, 34)
	gl.size = Vector2(100, 130)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.add_theme_font_size_override("font_size", 104)
	gl.add_theme_color_override("font_color", Items.GRADE_COLOR.get(grade, Color(1, 1, 1)))
	_outline(gl)
	results_box.add_child(gl)
	var gt := Label.new()
	gt.text = "GRADE"
	gt.position = Vector2(354, 156)
	gt.size = Vector2(100, 20)
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt.add_theme_font_size_override("font_size", 13)
	gt.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	results_box.add_child(gt)

	var secs := int(res.get("time", 0.0))
	var time_note := ""
	if bool(pb.get("new_time", false)) and not bool(pb.get("first_run", false)):
		time_note = "  ★ NEW BEST"
	elif float(pb.get("prev_time", 0.0)) > 0.0 and not bool(pb.get("new_time", false)):
		time_note = "   (best %d:%02d)" % [int(pb["prev_time"]) / 60, int(pb["prev_time"]) % 60]
	var rows: Array = [
		["Time", "%d:%02d%s" % [secs / 60, secs % 60, time_note],
			Color(1.0, 0.88, 0.45) if bool(pb.get("new_time", false)) else Color(0.9, 0.92, 0.98)],
		["Deaths", str(int(res.get("deaths", 0))),
			Color(0.6, 1.0, 0.6) if int(res.get("deaths", 0)) == 0 else Color(1.0, 0.65, 0.55)],
		["Elites slain", str(int(res.get("elites", 0))), Color(0.9, 0.92, 0.98)],
		["Secrets found", str(int(res.get("secrets", 0))), Color(0.9, 0.92, 0.98)],
		["Rooms charted", "%d / %d" % [int(res.get("explored", 0)), int(res.get("rooms", 1))],
			Color(0.9, 0.92, 0.98)],
	]
	var y := 26.0
	for row in rows:
		var k := Label.new()
		k.text = String(row[0])
		k.position = Vector2(28, y)
		k.add_theme_font_size_override("font_size", 16)
		k.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		_outline(k)
		results_box.add_child(k)
		var v := Label.new()
		v.text = String(row[1])
		v.position = Vector2(160, y)
		v.add_theme_font_size_override("font_size", 16)
		v.add_theme_color_override("font_color", row[2])
		_outline(v)
		results_box.add_child(v)
		y += 30.0
	if bool(pb.get("new_grade", false)) and not bool(pb.get("first_run", false)):
		var ng := Label.new()
		ng.text = "★ BEST GRADE YET"
		ng.position = Vector2(342, 186)
		ng.add_theme_font_size_override("font_size", 13)
		ng.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_outline(ng)
		results_box.add_child(ng)
	# Pop-in: the card lands with a little weight.
	results_box.scale = Vector2(0.85, 0.85)
	results_box.pivot_offset = Vector2(240, 116)
	results_box.modulate.a = 0.0
	var tw := results_box.create_tween()
	tw.tween_property(results_box, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(results_box, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_results() -> void:
	if is_instance_valid(results_box):
		results_box.queue_free()
	results_box = null


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


# The recurring cast by name fragment (checked in order, lowercase);
# anyone else falls back to a Story.ALL_ENEMIES display-name scan, so
# every boss gets a portrait for free. "" = no portrait (Narrator).
const PORTRAIT_CAST := [
	["maren", "elder"], ["aldric", "aldric"], ["vargoth", "king"],
	["warden null", "nullwarden"], ["callis", "warden"], ["vessa", "envoy"],
	["envoy", "envoy"], ["merchant", "merchant"], ["piet", "sentry"],
	["sentry", "sentry"], ["sera", "villager"], ["villager", "villager"],
	["bren", "villager"], ["morwen", "witch"], ["witch", "witch"],
	["choir mother", "choirmother"], ["pilgrim", "choirmother"],
	["korrag", "stormwarden"], ["beastkin", "beastkin"], ["scout", "beastkin"],
	["elder", "elder"], ["king", "king"],
]


func _portrait_for(who: String) -> String:
	if _portrait_cache.has(who):
		return _portrait_cache[who]
	var found := ""
	var low := who.to_lower()
	if low in ["you", "hero"]:
		found = String(Classes.CLASSES[game.player.cls]["sprite"])
	if found == "" and low != "narrator":
		for pair in PORTRAIT_CAST:
			if low.contains(String(pair[0])):
				found = pair[1]
				break
		if found == "":
			# Any named monster/boss whose codex name contains the speaker
			# (or vice versa) lends its sprite.
			for kind in Story.ALL_ENEMIES:
				var st: Dictionary = Story.ALL_ENEMIES[kind]
				var ename := String(st.get("name", "")).to_lower()
				if ename != "" and (ename.contains(low) or low.contains(ename)):
					found = String(st.get("sprite", ""))
					break
	_portrait_cache[who] = found
	return found


func _set_portrait(who: String) -> void:
	var sprite_name := _portrait_for(who)
	portrait_box.visible = sprite_name != ""
	if sprite_name != "":
		portrait_rect.texture = Art.tex(sprite_name)


func _show_line() -> void:
	var line: Array = dialogue_lines[dialogue_index]
	speaker_label.text = line[0]
	text_label.text = line[1]
	_set_portrait(String(line[0]))
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
	_set_portrait(who)
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
	_update_resonance_orb(res)
	# Continuous shimmer so the number itself glimmers, not just on change.
	var shimmer := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	if res > 0.0:
		var shine := clampf(res / 100.0, 0.0, 1.0)
		var gold := Color(0.84, 0.7, 0.32).lerp(Color(1.0, 0.96, 0.6), shine)
		res_label.add_theme_color_override("font_color", gold.lerp(Color(1.0, 1.0, 0.85), shimmer * 0.45))
		res_label.add_theme_color_override("font_outline_color", Color(0.28, 0.16, 0.02))
		res_label.add_theme_constant_override("outline_size", 3)
		var want := clampi(4 + int(res / 7.0), 4, 20)
		if res_particles.amount != want:
			res_particles.amount = want
		res_particles.emitting = true
	elif res < 0.0:
		res_label.add_theme_color_override("font_color", Color(0.05, 0.04, 0.07))
		# The dark shimmer breathes in the outline — an unsettled violet.
		res_label.add_theme_color_override("font_outline_color",
			Color(0.5, 0.42, 0.62, 0.75).lerp(Color(0.78, 0.55, 0.98, 0.8), shimmer))
		res_label.add_theme_constant_override("outline_size", 3)
		res_particles.emitting = false
	else:
		res_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.88))
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


## The mood orb: colour lerps pearl -> gold (Virtue) or pearl -> dark
## flame (Temptation), maxing out by |50|. The glow FLICKERS harder the
## further from neutral — a calm pearl at 0, live fire at the extremes.
func _update_resonance_orb(res: float) -> void:
	var pearl := Color(0.90, 0.93, 1.0)
	var col: Color
	if res >= 0.0:
		col = pearl.lerp(Color(1.0, 0.72, 0.15), clampf(res / 50.0, 0.0, 1.0))    # golden fire
	else:
		col = pearl.lerp(Color(0.34, 0.06, 0.42), clampf(-res / 50.0, 0.0, 1.0))  # dark flame
	var mag := clampf(absf(res) / 50.0, 0.0, 1.0)   # 0 neutral .. 1 extreme
	var t := Time.get_ticks_msec() * 0.001
	# Flame flicker: a slow breath everyone shares, plus fast jitter that
	# only wakes up as the shard's mood intensifies.
	var flick := 1.0 + sin(t * 6.5) * 0.05 + mag * (sin(t * 17.0) * 0.06 + sin(t * 29.0) * 0.04)
	res_orb_glow.modulate = Color(col, 0.5 + 0.28 * mag)
	res_orb_glow.scale = Vector2.ONE * (0.42 + 0.16 * mag) * flick
	# Pearl heart: bright core, tinted only slightly toward the mood.
	res_orb_core.modulate = Color(col.lerp(Color(1, 1, 1), 0.7), 0.85)
	res_orb_core.scale = Vector2.ONE * 0.22 * (1.0 + 0.06 * mag * sin(t * 15.0))
