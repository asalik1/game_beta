class_name Hud extends CanvasLayer
## Everything drawn on top of the world: health/mana/xp bars, gold, quest
## tracker, boss bar, the ability bar with cooldowns, loot banners,
## dialogue boxes, and pause / death / victory screens.

var game: Game

# bars
var hp_fill: ColorRect
var mp_fill: ColorRect
var xp_fill: ColorRect
var hp_text: Label              # current/max, right-aligned inside the bar
var mp_text: Label
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
var quest_btn: Button           # ! opens the Quest Log; shines when a reward waits
var quest_glow: Sprite2D        # red/orange pulse behind ! when the weekly vault is claimable
var quest_sparkles: Array = []  # twinkles around ! during the shine
var crucible_btn: Button        # 🔥 endgame — The Crucible; row under the mailbox, shown once Act 1 is cleared
var depths_btn: Button          # 🕯 endgame — The Waking Depths
var inv_btn: Button             # bag icon — opens the inventory
var codex_btn: Button           # book icon — opens the codex
var skills_btn: Button          # skill-tree icon — opens the talents/skill tree
var settings_btn: Button        # gear icon — opens the pause/ESC menu
var stash_btn: Button           # chest icon — opens the account stash

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

# click-to-reveal popover over the live HUD (the old hover tooltips, now
# clickable & opaque — dismiss by clicking anywhere off the box)
var hud_popover: Control = null

# corner minimap (top-right; rebuilt only when the charted world changes)
var minimap_root: Control
var minimap_cells: Control
var _minimap_sig := ""

# dialogue
var dialogue_box: Control
var dialogue_frame: ColorRect      # outer border — repositioned as the box grows
var dialogue_inner: ColorRect      # dark fill — ditto
var portrait_box: Control          # speaker portrait (right side of the box)
var portrait_rect: TextureRect
var _portrait_cache := {}          # speaker name -> sprite name ("" = none)
# choice dialogue (the branching-conversation engine lives in game.gd)
var choice_panel: Control
var choice_frame: ColorRect
var choice_inner: ColorRect
var choice_option_labels: Array = []
var choice_hover_rects: Array = []  # per-row mouse-hover highlight
var choices_active := false
var choice_count := 0
var choice_cb := Callable()
var speaker_label: Label
var text_label: Label
var hint_labels: Array = []     # hidden during cutscenes
var _touch_mode := false        # mobile: keyboard-only chrome stays hidden (touch_hud replaces it)
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

# downed/revive indicators (MP-12 §5.3). The local player's own DOWNED/GHOST
# banner + the over-head revive channel bar (the reviver/downed pair) live
# here; MP-14's party frames below carry the ALLY state read. Built lazily on
# the first online frame; solo never builds.
var down_banner: Label = null     # local player's own DOWNED/GHOST line
var down_marks: Array = []        # pooled overhead tags [{root,bg,fill,label}]

# MP-14 (§5.6): party frames — up to 3 compact ally bars in a left column
# under the player's own panel (name, class icon, HP, state marker), plus
# offscreen-ally edge arrows and name tags over on-screen remotes. Built
# lazily on the first online frame with >=2 players; freed on session end
# (reset_party_ui). Solo never allocates a node.
const PARTY_MAX := 3
const PARTY_FRAME_W := 214.0
const PARTY_FRAME_H := 42.0
## Per-class accent (arrow color, frame rail, name tag). No class color lives
## in Classes.CLASSES, so the party UI carries its own legible-at-a-glance set.
const CLASS_TINT := {
	"warrior": Color(0.88, 0.38, 0.32), "archer": Color(0.55, 0.86, 0.46),
	"mage": Color(0.45, 0.72, 1.0), "assassin": Color(0.72, 0.52, 1.0),
	"paladin": Color(1.0, 0.85, 0.45), "warlock": Color(0.82, 0.45, 1.0),
}
var party_root: Control = null    # holds the frames; freed on session end
var party_slots: Array = []       # [{root,accent,icon,name,hp_bg,hp_fill,hp_text,state,cls}]
var party_arrows: Array = []      # pooled Polygon2D edge arrows (offscreen allies)
var party_names: Array = []       # pooled Label name tags over on-screen remotes
## §5.6 dimmable knob: name-tag opacity (0.0 hides them, 1.0 full). A settings
## toggle can drive this; the default reads clearly without shouting.
var party_names_alpha := 0.85

# MP-13 (§5.4): read-only mirror of a chapter beat another player is driving.

# MP-13 (§5.4): read-only mirror of a chapter beat another player is driving.
# A compact top-center transcript — the initiator picks the choices, the rest
# of the party reads along. Built lazily on the first beat; solo never builds.
var mirror_box: Control = null
var mirror_frame: ColorRect = null
var mirror_inner: ColorRect = null
var mirror_header: Label = null
var mirror_speaker: Label = null
var mirror_text: Label = null
var mirror_options: Label = null

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
	hp_text = _bar_text(Vector2(18, 16), Vector2(BAR_W, 20), 12)
	mp_text = _bar_text(Vector2(18, 40), Vector2(BAR_W, 14), 10)
	stats_label = _label(Vector2(18, 82), 15, Color(1, 1, 1))
	gold_label = _label(Vector2(18, 104), 15, Color(1.0, 0.85, 0.35))
	cr_label = _label(Vector2(18, 126), 15, Color(0.65, 0.9, 1.0))
	cr_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cr_label.set_meta("tip", "Combat Rating — one number approximating your total power: gear and gems, level, attributes and skill tree combined.")
	_click_to_popover(cr_label, "Combat Rating")
	# Resonance: golden and sparkling when positive (shinier as it
	# climbs), black-on-pale when negative, pulses on every change.
	# Nudged right to seat the mood orb on its left.
	res_label = _label(Vector2(46, 147), 16, Color(0.75, 0.75, 0.8))
	res_label.pivot_offset = Vector2(0, 10)
	res_label.mouse_filter = Control.MOUSE_FILTER_PASS
	res_label.set_meta("tip", "Resonance — how your shard leans: Virtue (+) or Temptation (−). Major choices move it, and the world answers through dialogue and merchant haggling.")
	_click_to_popover(res_label, "Resonance")
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
	# menu — clickable on BOTH platforms. A red unread badge rides its corner.
	# Uses a DRAWN envelope (Art "mail"): the old ✉ glyph has no coverage in the
	# mobile pixel font, so it rendered as nothing on-device. A ui_mail.png pack
	# icon overrides it if one is ever dropped in.
	mail_btn = Button.new()
	mail_btn.flat = true
	var mail_tex: Texture2D = Art.ui_icon("ui_mail")  # pack art if present; else the drawn envelope
	mail_btn.icon = mail_tex if mail_tex != null else Art.tex("mail")
	mail_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mail_btn.tooltip_text = "Mailbox"
	mail_btn.position = Vector2(16, 186)
	mail_btn.size = Vector2(32, 30)
	mail_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_mailbox())
	add_child(mail_btn)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.86, 0.16, 0.16)
	badge_style.set_corner_radius_all(9)  # 18px box + r9 = a circle
	mail_badge = Panel.new()
	mail_badge.add_theme_stylebox_override("panel", badge_style)
	mail_badge.position = Vector2(40, 182)   # ride the top-right corner of the mail icon
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
	daily_glow.position = Vector2(168, 204)  # centered on the ★ (end of the icon row)
	daily_glow.modulate = Color(1.0, 0.85, 0.35, 0.0)
	daily_glow.visible = false
	add_child(daily_glow)
	daily_btn = Button.new()
	daily_btn.flat = true
	var daily_tex: Texture2D = Art.ui_icon("ui_daily")  # Raven gold star; glyph fallback
	if daily_tex != null:
		daily_btn.icon = daily_tex
		daily_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		daily_btn.text = "★"
		daily_btn.add_theme_font_size_override("font_size", 22)
		daily_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		daily_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	daily_btn.tooltip_text = "Daily reward ready!"
	daily_btn.position = Vector2(152, 185)  # end of the icon row: ✉ ! bag book ★
	daily_btn.size = Vector2(32, 30)
	daily_btn.visible = false
	daily_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_daily())
	add_child(daily_btn)

	# Endgame trials: a short row of mode icons DIRECTLY UNDER the mailbox, shown
	# once Act 1 is cleared (never buried in the pause menu). Like every HUD icon,
	# a click opens a backable screen — here a confirm with your record + the
	# rules — rather than tearing the world down on a stray click. Visibility is
	# toggled per-frame in update_stats (hidden during a run itself).
	crucible_btn = _endgame_icon("🔥", "The Crucible — Boss Rush", Vector2(16, 220), "crucible")
	depths_btn = _endgame_icon("🕯", "The Waking Depths — Marathon", Vector2(45, 220), "depths")

	# ---------------------------------------------------- quest tracker ---
	zone_label = _label(Vector2(340, 12), 16, Color(0.95, 0.85, 0.5), 600, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.title(zone_label, 17)  # the location name is a header
	quest_label = _label(Vector2(240, 36), 16, Color(1, 1, 1), 800, HORIZONTAL_ALIGNMENT_CENTER)
	# Icon row under Resonance: ✉ mail · ! quest · bag inventory · book codex · ★ daily.
	# The quest ! wears a red/orange SHINE (glow + twinkles) when a reward waits
	# to be claimed in the log (the weekly vault). Glow is added BEHIND the !.
	quest_glow = Sprite2D.new()
	quest_glow.texture = Art.tex("glow")
	quest_glow.position = Vector2(66, 202)  # centered on the !
	quest_glow.modulate = Color(1.0, 0.42, 0.18, 0.0)
	quest_glow.visible = false
	add_child(quest_glow)
	quest_btn = Button.new()
	quest_btn.flat = true
	var quest_tex: Texture2D = Art.ui_icon("ui_quest")  # Raven scroll; glyph fallback
	if quest_tex != null:
		quest_btn.icon = quest_tex
		quest_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		quest_btn.text = "!"
		quest_btn.add_theme_font_size_override("font_size", 24)
		quest_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		quest_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.75))
	quest_btn.tooltip_text = "Quest Log"
	quest_btn.position = Vector2(50, 185)
	quest_btn.size = Vector2(32, 30)
	quest_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_journal())
	add_child(quest_btn)
	# Twinkles around the ! (on top), lit only during the shine.
	for off: Vector2i in [Vector2i(-9, -7), Vector2i(11, -5), Vector2i(3, 11)]:
		var sp := Sprite2D.new()
		sp.texture = Art.tex("glow")
		sp.position = Vector2(66, 200) + Vector2(off)
		sp.scale = Vector2(0.1, 0.1)
		sp.modulate = Color(1.0, 0.95, 0.75, 0.0)
		sp.visible = false
		add_child(sp)
		quest_sparkles.append(sp)

	# Bag = inventory, Book = codex (small procedural icons, native size).
	inv_btn = Button.new()
	inv_btn.flat = true
	var bag_tex: Texture2D = Art.ui_icon("ui_bag")  # Raven pack art; procedural fallback
	inv_btn.icon = bag_tex if bag_tex != null else Art.tex("bag")
	inv_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_btn.tooltip_text = "Inventory"
	inv_btn.position = Vector2(84, 187)
	inv_btn.size = Vector2(32, 30)
	inv_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_inventory())
	add_child(inv_btn)
	codex_btn = Button.new()
	codex_btn.flat = true
	var book_tex: Texture2D = Art.ui_icon("ui_book")  # Raven pack art; procedural fallback
	codex_btn.icon = book_tex if book_tex != null else Art.tex("book")
	codex_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_btn.tooltip_text = "Codex"
	codex_btn.position = Vector2(118, 186)
	codex_btn.size = Vector2(32, 30)
	codex_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_codex())
	add_child(codex_btn)
	# Skill tree + menu(gear) icons — the two core screens that had no on-screen
	# entry (touch has no T / ESC key). Same row, clickable on BOTH platforms.
	# The gear opens the PAUSE menu (the ESC screen: resume / settings / keybinds
	# / save+quit), NOT the audio/controls sub-panel.
	skills_btn = Button.new()
	skills_btn.flat = true
	var skill_tex: Texture2D = Art.ui_icon("ui_skills")  # pack art if present; else drawn nodes
	skills_btn.icon = skill_tex if skill_tex != null else Art.tex("skills")
	skills_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_btn.tooltip_text = "Skill Tree"
	skills_btn.position = Vector2(186, 186)
	skills_btn.size = Vector2(32, 30)
	skills_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_skills())
	add_child(skills_btn)
	settings_btn = Button.new()
	settings_btn.flat = true
	var gear_tex: Texture2D = Art.ui_icon("ui_settings")  # pack art if present; else drawn cog
	settings_btn.icon = gear_tex if gear_tex != null else Art.tex("settings")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.tooltip_text = "Menu"
	settings_btn.position = Vector2(220, 186)
	settings_btn.size = Vector2(32, 30)
	settings_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_pause())
	add_child(settings_btn)
	# Stash (account storage) — moved off the pause menu onto the HUD row.
	stash_btn = Button.new()
	stash_btn.flat = true
	var stash_tex: Texture2D = Art.ui_icon("ui_stash")  # pack art if present; else drawn chest
	stash_btn.icon = stash_tex if stash_tex != null else Art.tex("stash")
	stash_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stash_btn.tooltip_text = "Stash (shared storage)"
	stash_btn.position = Vector2(254, 186)
	stash_btn.size = Vector2(32, 30)
	stash_btn.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open():
			game.menus.open_stash())
	add_child(stash_btn)

	# --------------------------------------------------------- boss bar ---
	boss_box = Control.new()
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_box)
	# Same framed treatment as the player bars (2px border, caps, quarter
	# ticks) — the boss's health speaks the HUD's one bar language.
	boss_fill = _bar(Vector2(390, 88), Vector2(500, 16), Color(0.7, 0.12, 0.2), boss_box)
	boss_name = Label.new()
	boss_name.position = Vector2(390, 60)
	boss_name.size = Vector2(500, 22)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(boss_name, 17)
	boss_name.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	_outline(boss_name)
	boss_box.add_child(boss_name)

	# ------------------------------------------------------ big titles ---
	title_label = _label(Vector2(0, 200), 44, Color(1, 1, 1), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	UITheme.title(title_label, 46)  # chapter/location card wears the display face
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
	# The box grows UPWARD from a fixed bottom edge (648, clearing the
	# quickbar): tall enough that a long paragraph (5-6 wrapped lines) fits
	# instead of clipping its last line against the bottom border.
	dialogue_frame = ColorRect.new()
	dialogue_frame.color = Color(0.9, 0.8, 0.5)
	dialogue_frame.position = Vector2(138, 448)
	dialogue_frame.size = Vector2(1004, 200)
	dialogue_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.add_child(dialogue_frame)
	dialogue_inner = ColorRect.new()
	dialogue_inner.color = Color(0.08, 0.07, 0.12, 0.97)
	dialogue_inner.position = Vector2(141, 451)
	dialogue_inner.size = Vector2(998, 194)
	dialogue_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.add_child(dialogue_inner)
	speaker_label = Label.new()
	speaker_label.position = Vector2(168, 462)
	UITheme.title(speaker_label, 19)  # speaker names in the display face
	speaker_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	dialogue_box.add_child(speaker_label)
	text_label = Label.new()
	text_label.position = Vector2(168, 492)
	text_label.size = Vector2(820, 148)  # leaves the portrait slot clear
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
	# decision; pick with the number keys or click a row (each label is a
	# full-width mouse target with the menus' hover tint).
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
		var hl := ColorRect.new()
		hl.color = Color(0.17, 0.17, 0.23, 0.95)  # menus.gd hover-bg idiom
		hl.visible = false
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice_panel.add_child(hl)
		choice_hover_rects.append(hl)
		var opt := Label.new()
		opt.add_theme_font_size_override("font_size", 17)
		opt.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
		# A long option used to run off the right edge; wrap it, and dialogue_choice
		# sizes each row to its wrapped height so wrapped rows don't overlap.
		opt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		opt.visible = false
		opt.mouse_filter = Control.MOUSE_FILTER_STOP
		opt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		opt.gui_input.connect(_on_choice_gui_input.bind(i))
		opt.mouse_entered.connect(_set_choice_hover.bind(i, true))
		opt.mouse_exited.connect(_set_choice_hover.bind(i, false))
		choice_panel.add_child(opt)
		choice_option_labels.append(opt)

	# --------------------------------------------------- controls hint ---
	# Two short lines on the far left so they never collide with the
	# ability bar's labels in the bottom center.
	var controls := _label(Vector2(14, 682), 11, Color(0.7, 0.7, 0.7), 400)
	controls.text = "WASD move · TAB lock · SPACE unlock · E talk · M map"
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
		_click_to_popover(border, "")
		add_child(border)
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.09, 0.9)
		bg.position = Vector2(x, y)
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		# Ability art, centred at its NATIVE 32x32 (2026-07-17). The old box was
		# SLOT_SIZE-16 = 44 — a 1.375x NEAREST magnification of 32px art, which
		# duplicates pixel rows unevenly (some 1px, some 2px) and made the whole
		# bar shimmer; the canvas_items stretch then multiplied it at 1080p. At
		# 32 the art draws 1:1 and only the global canvas scale touches it —
		# the same treatment every world sprite gets.
		var icon := TextureRect.new()
		icon.position = Vector2(x + (SLOT_SIZE - 32.0) / 2.0, y + (SLOT_SIZE - 32.0) / 2.0)
		icon.custom_minimum_size = Vector2(32, 32)
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

## Raven status-icon override per active-buff id (assets/icons/buff_*.png):
## damage / heal / armor / arcane-ward / lifesteal / mobility. A buff with no
## entry (e.g. Arrow Storm) keeps its tinted procedural ability glyph, and a
## missing/unimported PNG falls back to the same glyph — so the bar never
## renders blank.
const BUFF_ICONS := {
	"berserk": "buff_atk", "elixir": "buff_atk", "retri": "buff_atk",
	"holy": "buff_heal", "second_wind": "buff_heal",
	"grit": "buff_armor", "guard": "buff_armor",
	"ward": "buff_ward", "aegis": "buff_ward",
	"pact": "buff_blood", "surge": "buff_blood",
	"speed": "buff_speed", "dodge": "buff_speed", "haste": "buff_speed",
	"damp": "buff_damp",
}

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
		_click_to_popover(border, "")
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


## Make a HUD control click-to-reveal: on a left click it opens the info
## stashed in its "tip" metadata (kept fresh every frame) as an opaque
## popover — the same click-to-reveal model the inventory uses. The text
## lives in meta rather than tooltip_text so there's no redundant hover.
## accept_event() stops the click also falling through to dialogue-advance.
## `title` may be "".
func _click_to_popover(c: Control, title: String) -> void:
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if game.menus.is_open():
				return
			_open_hud_popover(title, String(c.get_meta("tip", "")))
			c.accept_event())


## The live-HUD twin of Menus._open_detail_popover: an opaque box at the
## cursor with a transparent full-screen catcher behind it (click anywhere
## off the box to dismiss). Info-only, so no buttons; the game keeps running.
func _open_hud_popover(title: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	if hud_popover:
		hud_popover.queue_free()
	game.sfx("ui_click")
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_hud_popover())
	add_child(overlay)
	hud_popover = overlay

	var pop := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.13, 1.0)  # fully opaque
	sb.border_color = Color(0.9, 0.8, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pop.add_theme_stylebox_override("panel", sb)
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(pop)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pop.add_child(vbox)
	if title != "":
		var tl := Label.new()
		tl.text = title
		UITheme.title(tl, 19)
		tl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		vbox.add_child(tl)
	var il := Label.new()
	il.text = text
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.custom_minimum_size = Vector2(430, 0)
	il.add_theme_font_size_override("font_size", 14)
	il.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	vbox.add_child(il)

	pop.position = pop.get_global_mouse_position() + Vector2(14, 8)
	await get_tree().process_frame
	if not is_instance_valid(pop):
		return
	pop.reset_size()
	var sz := pop.size
	pop.position = Vector2(
		clampf(pop.position.x, 8.0, 1280.0 - sz.x - 8.0),
		clampf(pop.position.y, 8.0, 720.0 - sz.y - 8.0))


func _close_hud_popover() -> void:
	if hud_popover:
		hud_popover.queue_free()
		hud_popover = null


## Every player state worth a chip. Timed buffs carry "t" = seconds left;
## PERSISTENT states (paladin stance, warrior Grit, Second Wind) set t < 0
## — their chip holds a full bar with no countdown. Optional "text"
## replaces the countdown (Grit shows its stack count). "tip" feeds the
## hover tooltip and reads LIVE numbers off the player, so talents and
## gear are reflected truthfully. The glyph reuses an ability icon that
## fits the buff; colors echo the on-hero aura so the chip and the aura
## read as one language.
func _active_buffs() -> Array:
	var p: Player = game.local_player  # the HUD is per-client: MY buffs
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
	if p.goldrush_time > 0.0: out.append({"id": "goldrush", "glyph": "ic_coin", "color": Color(1.0, 0.85, 0.35), "t": p.goldrush_time,
		"tip": "GOLD RUSH — +%d%% Greed: bonus gold from every source, and chest odds tick up. Farm while it burns; another charged coin refreshes the window." % int(Balance.GOLDRUSH_GREED * 100.0)})
	if p.stab_ls_time > 0.0: out.append({"id": "surge", "glyph": "ab_dagger", "color": Color(0.95, 0.3, 0.35), "t": p.stab_ls_time,
		"tip": "Blood Surge — +%d%% lifesteal, and Fan of Knives bites TWICE as hard. A connecting Stab or Shadow Dash refreshes it." % int(p.stab_ls_amt * 100.0)})
	if p.dodge_time > 0.0: out.append({"id": "dodge", "glyph": "ab_roll", "color": Color(0.8, 0.95, 0.7), "t": p.dodge_time,
		"tip": "Nimble — +%d%% evasion while the roll's momentum carries." % int(p.dodge_amt * 100.0)})
	if p.storm_time > 0.0: out.append({"id": "storm", "glyph": "ab_rain", "color": Color(0.6, 1.0, 0.6), "t": p.storm_time,
		"tip": "Arrow Storm — arrows rain on every enemy near you."})
	if p.cast_haste_time > 0.0: out.append({"id": "haste", "glyph": "ab_flame", "color": Color(0.7, 0.95, 1.0), "t": p.cast_haste_time,
		"tip": "Tailwind — Blink & Frost Nova cool down %d%% faster." % int(p.cast_haste_cdr * 100.0)})
	# Debuff: wading a river leaves you Damp (slowed, lingers after you leave).
	if p.damp_time > 0.0: out.append({"id": "damp", "glyph": "ab_rain", "color": Color(0.42, 0.66, 0.95), "t": p.damp_time,
		"tip": "Damp — river water clings to you: -%d%% move speed. Refreshed while wading, fades %ds after you leave the water." % [
			int(round((1.0 - Balance.DAMP_SLOW_MULT) * 100.0)), int(Balance.DAMP_DURATION)]})
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
			slot["border"].set_meta("tip", "")
			continue
		var b: Dictionary = active[i]
		var col: Color = b["color"]
		var t: float = b["t"]
		_set_buff_slot_visible(slot, true)
		slot["border"].color = col
		slot["border"].set_meta("tip", _wrap_tip(String(b.get("tip", ""))))
		var glyph: String = String(b["glyph"])
		# Prefer a Raven status icon (assets/icons/buff_*.png) when this buff
		# maps to one; else the tinted procedural ability glyph. Cached per
		# slot on the resolved icon key, so we only rebuild when THIS slot's
		# icon actually changes rather than thrashing every frame.
		var raven: String = BUFF_ICONS.get(b["id"], "")
		var icon_key: String = raven if raven != "" else glyph
		if slot["glyph"] != icon_key:
			slot["glyph"] = icon_key
			var rpath := "res://assets/icons/%s.png" % raven
			if raven != "" and ResourceLoader.exists(rpath):
				slot["icon"].texture = load(rpath)   # Raven's own colors
			else:
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
	if game:
		# Click/tap the minimap to open the full map (both platforms; desktop keeps M too).
		minimap_root.mouse_filter = Control.MOUSE_FILTER_STOP
		minimap_root.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				game.menus.open_map())
	# Solid-enough panel + border so the map holds its shape on BLACK
	# ground too (QA finding 7: it dissolved over void terrain).
	var bg := Panel.new()
	var bgsb := StyleBoxFlat.new()
	bgsb.bg_color = Color(0.05, 0.05, 0.09, 0.88)
	bgsb.border_color = Color(0.9, 0.8, 0.5, 0.3)
	bgsb.set_border_width_all(1)
	bgsb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", bgsb)
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
	# The longest name+desc pairs already brush the 440px frame; anything
	# longer would spill past the gold border. Widen the panel to the line
	# (keeping it centered) instead of letting the label outgrow it.
	var line_w: float = nm.get_theme_font("font").get_string_size(
		nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	if line_w + 28.0 > panel.size.x:
		panel.size.x = line_w + 28.0
		panel.position.x = 640.0 - panel.size.x * 0.5
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


# ------------------------------------------------------------- helpers ---

## Mana prices can be fractional (Quick Shot costs 0.5) — int() would
## truncate those to a bogus "0", so keep one decimal when it matters.
static func _fmt_cost(cost: float) -> String:
	return str(int(roundf(cost))) if absf(cost - roundf(cost)) < 0.05 else "%.1f" % cost


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


## Framed resource bar (theme pass): 2px warm-metal border on a dark
## trough, end-cap lips, a segmentation tick every 25%. `parent` defaults
## to the HUD layer; the boss bar passes its own box.
func _bar(pos: Vector2, bar_size: Vector2, color: Color, parent: Node = null) -> ColorRect:
	var host: Node = parent if parent != null else self
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.border_color = Color(UITheme.BAR_FRAME, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = pos - Vector2(2, 2)
	frame.size = bar_size + Vector2(4, 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos + Vector2(1, 1)
	fill.size = bar_size - Vector2(2, 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fill)
	fill.set_meta("full_w", bar_size.x - 2.0)
	# End-cap lips: a faint light catch at each end of the trough.
	for cap_x: float in [pos.x + 1.0, pos.x + bar_size.x - 3.0]:
		var cap := ColorRect.new()
		cap.color = Color(1, 1, 1, 0.1)
		cap.position = Vector2(cap_x, pos.y + 1.0)
		cap.size = Vector2(2, bar_size.y - 2.0)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(cap)
	# Quarter ticks, drawn over the fill.
	for i: int in [1, 2, 3]:
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.45)
		tick.position = Vector2(pos.x + 1.0 + (bar_size.x - 2.0) * 0.25 * i, pos.y + 1.0)
		tick.size = Vector2(1, bar_size.y - 2.0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(tick)
	return fill


## Small current/max readout living INSIDE a bar, right-aligned.
func _bar_text(pos: Vector2, bar_size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(bar_size.x - 8.0, bar_size.y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


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


## Ability names sit in a 76px label on the bar's 70px slot pitch, and a
## Label's rect can't shrink below its text — so a long name ("Fan of
## Knives") widened the rect and piled into the neighbour slot's label.
## Step the font down until the name spans at most one slot pitch, and
## re-pin the rect to its build width so centering stays on the slot.
func _fit_name(l: Label) -> void:
	if String(l.get_meta("fit_txt", "")) == l.text:
		return
	l.set_meta("fit_txt", l.text)
	var f := l.get_theme_font("font")
	var s := 12
	while s > 8 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > SLOT_SIZE + 10.0:
		s -= 1
	l.add_theme_font_size_override("font_size", s)
	l.size = Vector2(SLOT_SIZE + 16.0, s + 14.0)


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)


func _set_fill(fill: ColorRect, fraction: float) -> void:
	fill.size.x = maxf(0.0, fill.get_meta("full_w") * clampf(fraction, 0.0, 1.0))


# ----------------------------------------------------------- API used by game

## One endgame-mode HUD icon: a flat glyph button that opens a confirm (your
## record + the rules) for `mode`, gated to safe moments. Returned so
## update_stats can toggle its visibility.
func _endgame_icon(glyph: String, tip: String, pos: Vector2, mode: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.text = glyph
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.position = pos
	b.size = Vector2(32, 30)
	b.visible = false
	b.pressed.connect(func() -> void:
		if game.play_started and not game.menus.is_open() and not game.endgame_active:
			game.menus.confirm_endgame(mode))
	add_child(b)
	return b


func update_stats(p: Player) -> void:
	# A menu opened (e.g. via hotkey) over an open HUD popover — dismiss it so
	# it doesn't linger behind the paused menu.
	if hud_popover and game.menus.is_open():
		_close_hud_popover()
	_update_down_ui(p)  # MP-12 §5.3: downed banner + overhead revive bars
	_update_party_ui(p)  # MP-14 §5.6: ally frames + offscreen arrows + name tags
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
	# Current/max lives INSIDE each bar now (theme pass) — the text line
	# under them keeps class, level and the skill-point nudge.
	stats_label.text = "%s  Lv %d%s" % [cls_name, p.level, pts]
	hp_text.text = "%d / %d" % [int(p.hp), int(p.max_hp)]
	if Classes.CLASSES[p.cls].get("manaless", false):
		# Manaless classes (assassin, round 31): no MP number, no blue bar.
		mp_text.text = ""
		_set_fill(mp_fill, 0.0)
	else:
		mp_text.text = "%d / %d" % [int(p.mp), int(p.max_mp)]
		_set_fill(mp_fill, p.mp / p.max_mp)
	gold_label.text = "◉ %d gold    Potions [%s] x%d" % [p.gold, OS.get_keycode_string(game.binds["potion"]), p.potion_count()]
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

	# Endgame trial icons: shown once Act 1 is cleared, hidden during a run.
	var eg_show: bool = game.play_started and not game.endgame_active and game.endgame_unlocked()
	crucible_btn.visible = eg_show
	depths_btn.visible = eg_show

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

	# Quest icon shine: a red/orange pulse + twinkles when the log is worth
	# opening — a claimable weekly vault, OR a side quest somebody in this
	# chapter is still waiting to offer (2026-07-17). The shine used to watch
	# the vault ALONE, which meant the one icon that says "there are quests"
	# stayed dark through a chapter full of unasked ones.
	var quest_ready := game.vault_ready() or game.any_quest_available()
	quest_glow.visible = quest_ready
	for spk in quest_sparkles:
		spk.visible = quest_ready
	if quest_ready:
		var qt := Time.get_ticks_msec() * 0.001
		var qpulse := 0.5 + 0.5 * sin(qt * 3.2)
		quest_btn.modulate = Color(1.0, 0.56, 0.38, 0.82 + 0.18 * qpulse)
		quest_glow.modulate = Color(1.0, 0.42, 0.18, 0.28 + 0.4 * qpulse)
		quest_glow.scale = Vector2.ONE * (0.55 + 0.18 * qpulse)
		for i in quest_sparkles.size():
			var spr: Sprite2D = quest_sparkles[i]
			var tw := 0.5 + 0.5 * sin(qt * 5.2 + i * 2.1)
			spr.modulate = Color(1.0, 0.95, 0.75, tw)
			spr.scale = Vector2.ONE * (0.07 + 0.06 * tw)
	else:
		quest_btn.modulate = Color(1, 1, 1, 1)

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
			box["cd"].size.y = 0.0
			box["cost"].text = ""
			# Per-room potion budget (2026-07-07 v2): the loadout's slots
			# for the CURRENT room; spent loadout = the slot reads locked.
			var left: int = p.room_potions_left()
			var active_left: int = int(p.room_potions.get(p.active_potion, 0))
			if p.active_potion == "health":
				box["name"].text = "Potion ▸%d" % active_left if left > 0 else "Spent"
				box["num"].text = "x%d" % p.potion_count()
				box["icon"].texture = Art.tex("potion")
				box["border"].color = (Color(0.75, 0.35, 0.35) if p.potion_count() > 0 else Color(0.3, 0.15, 0.15)) \
					if left > 0 else Color(0.18, 0.12, 0.12)
				box["border"].set_meta("tip", _wrap_tip(
					"Health Potion — mends 15%% of your MISSING health (x%d carried — bought from merchants, each takes a bag slot, so BAG SPACE is your only stock limit; the price grows with your LEVEL). ROOM BUDGET: %d of your %d loadout slots left — it refills next room. [%s] cycles the loadout; open the inventory and click a potion stack to plan it." % [
						p.potion_count(),
						left, p.potion_slot_cap(),
						OS.get_keycode_string(game.binds.get("potion_next", KEY_R))]))
			else:
				var cnt := p.consumable_count(p.active_potion)
				box["name"].text = ("%s ▸%d" % ["Mana" if p.active_potion == "mana_potion" else "Might", active_left]) if left > 0 else "Spent"
				box["num"].text = "x%d" % cnt
				var ic: Texture2D = Art.consumable_icon({"id": p.active_potion})
				box["icon"].texture = ic if ic != null else Art.tex("potion")
				box["border"].color = (Color(0.4, 0.6, 0.95) if cnt > 0 else Color(0.15, 0.2, 0.35)) \
					if left > 0 else Color(0.18, 0.12, 0.12)
				box["border"].set_meta("tip", _wrap_tip(
					"%s — slotted in your loadout (x%d carried). ROOM BUDGET: %d of %d slots left this room. [%s] cycles the loadout." % [
						p.potion_display_name(p.active_potion), cnt,
						left, p.potion_slot_cap(),
						OS.get_keycode_string(game.binds.get("potion_next", KEY_R))]))
			_fit_name(box["name"])
			continue
		var ab := Classes.ability(p.cls, slot)
		var theme := Classes.theme_by_id(p.cls, p.ability_theme.get(slot, ""))
		var tcol: Color = theme.get("color", Color(0.85, 0.85, 0.92))
		box["icon"].texture = Art.ability_icon(p.cls, slot, tcol)
		var cost := p.ability_cost(slot)
		box["key"].text = OS.get_keycode_string(game.binds[slot])
		box["name"].text = ab["name"]
		# Which THEME an ability is running is an at-a-glance read, and on the
		# procedural glyph the tint carried it. Hand-authored art is used
		# untinted (Art.ability_icon), so the color moves to the ability NAME —
		# the same place the skills menu already shows it (menus.gd _btn font).
		box["name"].add_theme_color_override("font_color",
			tcol if Art.has_ability_art(p.cls, slot) else Color(1, 1, 1))
		box["cost"].text = _fmt_cost(cost) if cost > 0 else ""
		# Paladin's ult is a STANCE SWAP, not a nuke — the slot itself reads out
		# the form you're in RIGHT NOW (Conviction toggles it), so you never have
		# to hunt the buff chip to know whether your blows mend or hit harder.
		if p.cls == "paladin" and slot == "ult":
			var holy: bool = p.paladin_mode == "holy"
			box["name"].text = "◆ HOLY" if holy else "◆ RETRI"
			var scol := Color(1.0, 0.92, 0.55) if holy else Color(1.0, 0.5, 0.28)
			box["name"].add_theme_color_override("font_color", scol)
			# The stance still reads off the NAME ("◆ HOLY" in gold) either way;
			# only the 2-color glyph gets the stance modulate, for the same
			# reason ability_icon() leaves hand art untinted.
			box["icon"].modulate = Color(1, 1, 1) if Art.has_ability_art(p.cls, slot) else scol
		elif box["icon"] != null:
			box["icon"].modulate = Color(1, 1, 1)
		_fit_name(box["name"])
		# Detail card: name/key/cost/cd, the ability's own words, then the
		# assigned theme's variant line — built from live values, so cd
		# talents and mana amods read truthfully.
		var tip := "%s  [%s]" % [String(ab["name"]), OS.get_keycode_string(game.binds[slot])]
		if cost > 0:
			tip += "  ·  %s mana" % _fmt_cost(cost)
		tip += "  ·  %.1fs cooldown" % p.ability_cd(slot)
		tip += "\n" + String(ab["desc"])
		var theme_id: String = p.ability_theme.get(slot, "")
		if theme_id != "":
			var vdesc := Classes.variant_desc(p.cls, slot, theme_id)
			if vdesc != "":
				tip += "\n★ %s: %s" % [String(theme.get("name", theme_id)), vdesc]
		box["border"].set_meta("tip", _wrap_tip(tip))
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
	quest_label.text = "◆  " + game.touchify(text)
	# The longest quest line + " — N monsters left" can exceed the 800px rect;
	# the rect grows RIGHT from x=240, drifting the line off the 640 center.
	# Re-clamp against the new text and re-pin the center.
	quest_label.size = Vector2(800, 30)
	quest_label.position.x = 640.0 - quest_label.size.x * 0.5


# ------------------------------------------ downed / revive UI (MP-12 §5.3) ---
# MINIMAL by charter: the local player's own DOWNED/GHOST banner with the
# bleed-out countdown, plus small overhead tags on downed bodies and the
# 3 s channel bar over BOTH heads of a revive. MP-14's party frames will
# absorb/expand these. Built lazily on the first online frame — solo
# never allocates a node.

func _ensure_down_ui() -> void:
	if down_banner != null:
		return
	down_banner = _label(Vector2(0, 330), 26, Color(1.0, 0.42, 0.36), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	down_banner.visible = false
	for i in 8:
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.visible = false
		add_child(root)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.6)
		bg.position = Vector2(-32, 12)
		bg.size = Vector2(64, 8)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(0.4, 1.0, 0.55, 0.95)
		fill.position = Vector2(-30, 14)
		fill.size = Vector2(0, 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)
		var lab := Label.new()
		lab.position = Vector2(-60, -8)
		lab.size = Vector2(120, 16)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lab.add_theme_constant_override("outline_size", 3)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lab)
		down_marks.append({"root": root, "bg": bg, "fill": fill, "label": lab})


## Per-frame from update_stats: p is the LOCAL player.
func _update_down_ui(p: Player) -> void:
	var online: bool = game.net_online()
	if not online and down_banner == null:
		return  # solo: nothing was ever built, nothing to hide
	_ensure_down_ui()
	if online and p.downed:
		var tail := "  (an ally can hold [%s] beside you)" \
			% OS.get_keycode_string(game.binds["interact"])
		if p.being_revived_by != 0:
			tail = "  — an ally is reviving you!"
		down_banner.text = "DOWNED — %d s%s" % [int(ceil(p.down_t)), tail]
		down_banner.visible = true
	elif online and p.ghost:
		down_banner.text = "GHOST — you return when the room is cleared"
		down_banner.visible = true
	else:
		down_banner.visible = false
	var used := 0
	if online:
		var xf: Transform2D = game.get_viewport().canvas_transform
		for q in game.players:
			if q == null or not is_instance_valid(q):
				continue
			if q.downed:
				var prog := -1.0
				if q.being_revived_by != 0:
					prog = _revive_progress(p, q)
				used = _place_down_mark(used, xf, q.global_position,
					"REVIVING" if prog >= 0.0 else "DOWNED %ds" % int(ceil(q.down_t)), prog)
			elif q.ghost:
				used = _place_down_mark(used, xf, q.global_position, "GHOST", -1.0)
		# §5.3: the channel bar shows over BOTH heads — the reviver's too.
		if p.revive_target != null and is_instance_valid(p.revive_target):
			used = _place_down_mark(used, xf, p.global_position, "REVIVING",
				clampf(p.revive_t / p.REVIVE_CHANNEL, 0.0, 1.0))
	for i in range(used, down_marks.size()):
		(down_marks[i]["root"] as Control).visible = false


## Channel progress 0..1: the exact clock when WE hold the channel, the
## broadcast start time otherwise (skew ~ one RPC — presentation only).
func _revive_progress(p: Player, q) -> float:
	if p.revive_target == q:
		return clampf(p.revive_t / p.REVIVE_CHANNEL, 0.0, 1.0)
	return clampf(float(Time.get_ticks_msec() - int(q.revive_bar_ms))
		/ (float(q.REVIVE_CHANNEL) * 1000.0), 0.0, 1.0)


func _place_down_mark(idx: int, xf: Transform2D, at: Vector2, text: String, prog: float) -> int:
	if idx >= down_marks.size():
		return idx
	var m: Dictionary = down_marks[idx]
	var root := m["root"] as Control
	root.visible = true
	root.position = xf * (at + Vector2(0, -74))
	(m["label"] as Label).text = text
	var show_bar: bool = prog >= 0.0
	(m["bg"] as ColorRect).visible = show_bar
	var fill := m["fill"] as ColorRect
	fill.visible = show_bar
	if show_bar:
		fill.size.x = 60.0 * clampf(prog, 0.0, 1.0)
	return idx + 1


# ------------------------------------------------------- party UI (MP-14 §5.6) ---
# Up to 3 compact ally frames (name, class icon, HP, state), offscreen-ally
# edge arrows, and dimmable name tags over on-screen remotes. Built lazily on
# the first online frame with a party; solo never allocates. The DATA MODEL
# (party_frame_data) is exposed so a test can drive vitals/downed and assert
# the frames' contents without reading pixels.

## The ally roster the party UI draws: ONE row per REMOTE player (never the
## local player — that's the main HUD). Read live off game.players each call,
## so it reflects vitals/downed the instant they change (net_test asserts here).
func party_frame_data() -> Array:
	var out: Array = []
	if game == null or not game.net_online():
		return out
	for q in game.players:
		if q == null or not is_instance_valid(q) or q == game.local_player:
			continue
		out.append({
			"peer": int(q.peer_id),
			"name": String(q.get_meta("net_name", "")),
			"cls": String(q.cls),
			"hp": float(q.hp), "max_hp": maxf(1.0, float(q.max_hp)),
			"state": _ally_state(q),
		})
	return out


## An ally's §5.3/§5.6 state marker: downed (bleeding out), ghost, dead, or up.
## (disconnected-grace is structurally a 5th state; it lands with MP-16's
## drop/rejoin — the frame renders "…" for it when that flag exists.)
func _ally_state(q) -> String:
	if q.downed:
		return "downed"
	if q.ghost:
		return "ghost"
	if q.dead:
		return "dead"
	return "up"


func _ally_by_peer(pid: int):
	for q in game.players:
		if q != null and is_instance_valid(q) and q != game.local_player and int(q.peer_id) == pid:
			return q
	return null


func _ensure_party_ui() -> void:
	if party_root != null:
		return
	party_root = Control.new()
	party_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(party_root)
	for i in PARTY_MAX:
		var y := 228.0 + i * (PARTY_FRAME_H + 6.0)
		party_slots.append(_build_party_frame(Vector2(12, y)))
	# Offscreen-ally arrows (pooled triangles) + on-screen name tags.
	for i in PARTY_MAX:
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(0, -11), Vector2(9, 7), Vector2(-9, 7)])
		arrow.visible = false
		add_child(arrow)
		party_arrows.append(arrow)
		var tag := Label.new()
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		tag.add_theme_constant_override("outline_size", 3)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.visible = false
		add_child(tag)
		party_names.append(tag)


func _build_party_frame(pos: Vector2) -> Dictionary:
	var root := Control.new()
	root.position = pos
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	party_root.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.09, 0.62)
	bg.size = Vector2(PARTY_FRAME_W, PARTY_FRAME_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var accent := ColorRect.new()  # class-colored left rail
	accent.size = Vector2(3, PARTY_FRAME_H)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(accent)
	var icon := TextureRect.new()
	icon.position = Vector2(7, 6)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var nm := Label.new()
	nm.position = Vector2(44, 2)
	nm.size = Vector2(PARTY_FRAME_W - 50, 16)
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	nm.add_theme_constant_override("outline_size", 3)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nm)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.position = Vector2(44, 22)
	hp_bg.size = Vector2(PARTY_FRAME_W - 52, 13)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.8, 0.25, 0.25)
	hp_fill.position = Vector2(45, 23)
	hp_fill.size = Vector2(PARTY_FRAME_W - 54, 11)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.set_meta("full_w", PARTY_FRAME_W - 54)
	root.add_child(hp_fill)
	var hp_text := Label.new()
	hp_text.position = Vector2(46, 21)
	hp_text.size = Vector2(PARTY_FRAME_W - 58, 13)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 10)
	hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_text.add_theme_constant_override("outline_size", 2)
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_text)
	var state := Label.new()  # replaces the name row when downed/ghost/dead
	state.position = Vector2(44, 2)
	state.size = Vector2(PARTY_FRAME_W - 50, 16)
	state.add_theme_font_size_override("font_size", 13)
	state.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	state.add_theme_constant_override("outline_size", 3)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.visible = false
	root.add_child(state)
	return {"root": root, "accent": accent, "icon": icon, "name": nm,
		"hp_bg": hp_bg, "hp_fill": hp_fill, "hp_text": hp_text, "state": state, "cls": ""}


## Per-frame from update_stats: p is the LOCAL player (unused here — the frames
## are the OTHER players). Solo / lone-online never allocates; a party of >=2
## builds once and draws.
func _update_party_ui(_p: Player) -> void:
	var online: bool = game.net_online()
	var data: Array = party_frame_data() if online else []
	if not online or data.is_empty():
		if party_root != null:
			_hide_party_ui()
		return
	_ensure_party_ui()
	party_root.visible = true
	for i in party_slots.size():
		var slot: Dictionary = party_slots[i]
		if i >= data.size():
			(slot["root"] as Control).visible = false
			continue
		var d: Dictionary = data[i]
		(slot["root"] as Control).visible = true
		var cls := String(d["cls"])
		(slot["accent"] as ColorRect).color = CLASS_TINT.get(cls, Color(0.6, 0.6, 0.65))
		if String(slot["cls"]) != cls:
			slot["cls"] = cls
			var sprite := String(Classes.CLASSES.get(cls, {}).get("sprite", ""))
			(slot["icon"] as TextureRect).texture = Art.tex(sprite) if sprite != "" else null
		var nm := String(d["name"])
		if nm == "":
			nm = "Ally %d" % int(d["peer"])
		var name_l := slot["name"] as Label
		name_l.text = nm
		name_l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.98))
		_set_fill(slot["hp_fill"], clampf(float(d["hp"]) / float(d["max_hp"]), 0.0, 1.0))
		(slot["hp_text"] as Label).text = "%d/%d" % [int(d["hp"]), int(d["max_hp"])]
		_apply_frame_state(slot, String(d["state"]), _ally_by_peer(int(d["peer"])))
	_update_party_arrows(data)
	_update_party_names(data)


## Fold MP-12's ally state into the frame (the charter's "the FRAME shows the
## state"): downed shows the bleed-out countdown, ghost/dead dim the row. The
## state text takes the name row; the HP bar stays as the vitals read.
func _apply_frame_state(slot: Dictionary, st: String, q) -> void:
	var state_l := slot["state"] as Label
	var name_l := slot["name"] as Label
	var icon := slot["icon"] as TextureRect
	var hp_fill := slot["hp_fill"] as ColorRect
	match st:
		"downed":
			var secs: int = int(ceil(q.down_t)) if q != null else 0
			var tail := " — reviving" if (q != null and q.being_revived_by != 0) else ""
			state_l.text = "DOWNED %ds%s" % [secs, tail]
			state_l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
			hp_fill.color = Color(0.7, 0.2, 0.2)
			icon.modulate = Color(1, 1, 1, 0.5)
		"ghost":
			state_l.text = "GHOST"
			state_l.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
			hp_fill.color = Color(0.42, 0.55, 0.82)
			icon.modulate = Color(0.72, 0.82, 1.0, 0.55)
		"dead":
			state_l.text = "DEAD"
			state_l.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
			hp_fill.color = Color(0.4, 0.4, 0.45)
			icon.modulate = Color(1, 1, 1, 0.35)
		"disc":
			state_l.text = "disconnected…"
			state_l.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
			icon.modulate = Color(1, 1, 1, 0.4)
		_:
			hp_fill.color = Color(0.8, 0.25, 0.25)
			icon.modulate = Color(1, 1, 1, 1)
	var down: bool = st != "up"
	state_l.visible = down
	name_l.visible = not down


## A thin edge arrow per OFFSCREEN living ally, class-colored, pointing toward
## them from screen center — with a pulse when they're down/ghost (finding your
## downed friend is the #1 use). Cheap per-frame math (a viewport transform + a
## ray-to-rect clamp per ally).
func _update_party_arrows(data: Array) -> void:
	var xf: Transform2D = game.get_viewport().canvas_transform
	var center := Vector2(640, 360)
	var used := 0
	for d in data:
		if String(d["state"]) == "dead":
			continue  # a dead ally has no live position worth chasing
		var q = _ally_by_peer(int(d["peer"]))
		if q == null:
			continue
		var screen: Vector2 = xf * q.global_position
		if screen.x >= 0.0 and screen.x <= 1280.0 and screen.y >= 0.0 and screen.y <= 720.0:
			continue  # on-screen: the name tag covers it
		if used >= party_arrows.size():
			break
		var dir := screen - center
		if dir.length() < 1.0:
			continue
		var arrow := party_arrows[used] as Polygon2D
		arrow.position = _edge_point(center, dir, Vector2(42, 42), Vector2(1238, 678))
		arrow.rotation = dir.angle() + PI / 2.0  # the triangle points 'up' at 0
		var st := String(d["state"])
		var tint: Color = CLASS_TINT.get(String(d["cls"]), Color(0.7, 0.7, 0.75))
		if st == "downed" or st == "ghost":
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			arrow.color = Color(1.0, 0.4, 0.4) if st == "downed" else Color(0.6, 0.82, 1.0)
			arrow.modulate = Color(1, 1, 1, 0.5 + 0.5 * pulse)
			arrow.scale = Vector2.ONE * (1.0 + 0.28 * pulse)
		else:
			arrow.color = tint
			arrow.modulate = Color(1, 1, 1, 0.85)
			arrow.scale = Vector2.ONE
		arrow.visible = true
		used += 1
	for i in range(used, party_arrows.size()):
		(party_arrows[i] as Polygon2D).visible = false


## Where the ray center->dir exits the on-screen rect [minv, maxv].
func _edge_point(center: Vector2, dir: Vector2, minv: Vector2, maxv: Vector2) -> Vector2:
	var t := 1.0e20
	if dir.x > 0.001:
		t = minf(t, (maxv.x - center.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (minv.x - center.x) / dir.x)
	if dir.y > 0.001:
		t = minf(t, (maxv.y - center.y) / dir.y)
	elif dir.y < -0.001:
		t = minf(t, (minv.y - center.y) / dir.y)
	if t >= 1.0e20:
		t = 0.0
	return center + dir * t


## Small dimmable name tag over each ON-SCREEN remote (offscreen ones are the
## arrows' job). party_names_alpha is the §5.6 knob.
func _update_party_names(data: Array) -> void:
	var xf: Transform2D = game.get_viewport().canvas_transform
	var used := 0
	if party_names_alpha > 0.01:
		for d in data:
			if String(d["state"]) == "dead":
				continue
			var q = _ally_by_peer(int(d["peer"]))
			if q == null:
				continue
			var screen: Vector2 = xf * (q.global_position + Vector2(0, -54))
			if screen.x < 0.0 or screen.x > 1280.0 or screen.y < 0.0 or screen.y > 720.0:
				continue  # offscreen: the arrow points the way instead
			if used >= party_names.size():
				break
			var tag := party_names[used] as Label
			var nm := String(d["name"])
			if nm == "":
				nm = "Ally %d" % int(d["peer"])
			tag.text = nm
			tag.size = Vector2(160, 16)
			tag.position = screen - Vector2(80, 8)
			var tint: Color = CLASS_TINT.get(String(d["cls"]), Color(0.85, 0.85, 0.9))
			tag.add_theme_color_override("font_color", tint.lerp(Color(1, 1, 1), 0.4))
			tag.modulate = Color(1, 1, 1, party_names_alpha)
			tag.visible = true
			used += 1
	for i in range(used, party_names.size()):
		(party_names[i] as Label).visible = false


func _hide_party_ui() -> void:
	if party_root != null:
		party_root.visible = false
	for a in party_arrows:
		(a as Polygon2D).visible = false
	for n in party_names:
		(n as Label).visible = false


## Freed on session end (§5.6: solo never allocates; a closed session frees
## the frames). Called from net_session._on_session_ended.
func reset_party_ui() -> void:
	if party_root != null:
		party_root.queue_free()
		party_root = null
	party_slots.clear()
	for a in party_arrows:
		(a as Polygon2D).queue_free()
	party_arrows.clear()
	for n in party_names:
		(n as Label).queue_free()
	party_names.clear()


func show_boss_bar(bname: String) -> void:
	boss_base_name = bname
	boss_name.text = bname
	boss_box.visible = true


func update_boss_bar(fraction: float) -> void:
	_set_fill(boss_fill, fraction)
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
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Items.GRADE_COLOR[item["grade"]])
	_outline(l)
	# A legendary's describe line (stats + ★ passive) can run 150+ chars — a
	# single-line label grows to fit and sails off the right screen edge. Fold
	# it to the banner's width and let this banner take more vertical room.
	var body := _wrap_tip(Items.describe(item), 46).replace("\n", "\n   ")
	l.text = "+ %s  (+%d gold)\n   %s" % [Items.title(item), bonus_gold, body]
	var lines: int = l.text.count("\n") + 1
	l.size = Vector2(380, lines * 21.0 + 2.0)
	box.add_child(l)
	banner_y = 110.0 if banner_y > 260.0 else banner_y + maxf(52.0, lines * 21.0 + 10.0)
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


## Inverse-telegraph dread (readability pass, 2026-07-07): while a
## safe-zone mechanic is airborne the WHOLE arena is lethal — show it.
## A red wash builds over the window even if the player never sees the
## quiet circle; danger_end resolves it (soft green blink sheltered,
## hard red slam caught). Driven by game.telegraph_safe.
var danger_rect: TextureRect = null
var danger_tw: Tween = null

func danger_ramp(dur: float) -> void:
	if danger_rect == null:
		# An EDGE vignette, not a flat wash: the screen's rim floods red
		# while the center stays readable — danger you see in the corner
		# of your eye, which is exactly where this mechanic was dying.
		danger_rect = TextureRect.new()
		danger_rect.texture = Art.tex("dangerrim")
		danger_rect.size = Vector2(1280, 720)
		danger_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		danger_rect.stretch_mode = TextureRect.STRETCH_SCALE
		danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(danger_rect)
		move_child(danger_rect, 0)  # under every HUD element
	if danger_tw != null and danger_tw.is_valid():
		danger_tw.kill()
	danger_rect.modulate = Color(1.9, 0.25, 0.3, 0.0)  # HDR red rim
	danger_tw = create_tween()
	danger_tw.tween_property(danger_rect, "modulate:a", 0.9, dur)

func danger_end(sheltered: bool) -> void:
	if danger_rect == null:
		return
	if danger_tw != null and danger_tw.is_valid():
		danger_tw.kill()
	if sheltered:
		danger_rect.modulate = Color(0.5, 1.6, 0.7, minf(danger_rect.modulate.a, 0.5))
	danger_tw = create_tween()
	danger_tw.tween_property(danger_rect, "modulate:a", 0.0, 0.35)


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


## A full-screen splash wash (Phantom ult): a transparent print of a splash
## art covers the screen at `opacity`, then fades out over `dur` — the image
## counterpart of flash_screen's colour wash. A blue-tint floor fills the WHOLE
## viewport under it: the art is near-transparent at low opacity, so the tint
## shows through its dark areas AND fills any space its aspect leaves, so the
## wash reaches edge-to-edge with no game world peeking past the print.
func flash_splash(tex: Texture2D, opacity := 0.1, dur := 0.85,
		tint := Color(0.12, 0.4, 1.0)) -> void:
	if tex == null:
		return
	var fill := ColorRect.new()
	fill.color = Color(tint.r, tint.g, tint.b, opacity)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1, 1, 1, opacity)
	add_child(rect)
	var tween := create_tween()
	tween.parallel().tween_property(fill, "color:a", 0.0, dur)
	tween.parallel().tween_property(rect, "modulate:a", 0.0, dur)
	tween.chain().tween_callback(func() -> void:
		fill.queue_free()
		rect.queue_free())


# --------------------------------------------------------------- dialogue

func dialogue(lines: Array, on_done := Callable()) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_done = on_done
	dialogue_active = true
	game.request_pause(true)
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
	# Morwen and Korrag wear their OWN authored sheets. They used to point at
	# "witch" and at stormwarden.png — and stormwarden.png is VEYX's body,
	# so the ch2 boss spoke with the ch7 boss's face.
	["bren", "villager"], ["morwen", "morwen"], ["witch", "witch"],
	["choir mother", "choirmother"], ["pilgrim", "choirmother"],
	["korrag", "korrag"], ["beastkin", "beastkin"], ["scout", "beastkin"],
	["elder", "elder"], ["king", "king"],
	# The class-opening speakers (QA finding 3: four openings had no
	# portraits). The Tome stays faceless on purpose — it's a book.
	["carter", "villager"], ["the mother", "villager"], ["ren", "villager"],
	["osric", "villager"],
]


func _portrait_for(who: String) -> String:
	if _portrait_cache.has(who):
		return _portrait_cache[who]
	var found := ""
	var low := who.to_lower()
	if low in ["you", "hero"]:
		# Dialogue is a local overlay (MULTIPLAYER.md §5.4): "you" is the
		# player reading it on THIS screen.
		found = String(Classes.CLASSES[game.local_player.cls]["sprite"])
	if found == "" and low != "narrator":
		for pair in PORTRAIT_CAST:
			if low.contains(String(pair[0])):
				found = pair[1]
				break
		if found == "":
			# Any named monster/boss lends its sprite — WHOLE-WORD matches
			# only (QA finding 2: "Ren" landed on "the Unchained CurRENt").
			# Every word of the speaker must appear as a word of the name.
			var low_words := _name_words(low)
			for kind in Story.ALL_ENEMIES:
				var st: Dictionary = Story.ALL_ENEMIES[kind]
				var ewords := _name_words(String(st.get("name", "")))
				if ewords.is_empty() or low_words.is_empty():
					continue
				var all_in := true
				for w in low_words:
					if not w in ewords:
						all_in = false
						break
				if all_in:
					found = String(st.get("sprite", ""))
					break
	_portrait_cache[who] = found
	return found


## Lowercased words of a display name, punctuation stripped —
## "Korrag, Stormwarden Broken" -> [korrag, stormwarden, broken].
func _name_words(s: String) -> Array:
	var clean := ""
	for ch in s.to_lower():
		clean += ch if (ch >= "a" and ch <= "z") else " "
	return Array(clean.split(" ", false))


func _set_portrait(who: String) -> void:
	var sprite_name := _portrait_for(who)
	portrait_box.visible = sprite_name != ""
	if sprite_name != "":
		portrait_rect.texture = Art.tex(sprite_name)


# The dialogue box hangs from a fixed BOTTOM edge and grows UPWARD to fit its
# line, so a long paragraph can't spill past the bottom border (the box used to
# be a static 200px and 6+ wrapped lines clipped through it). These anchor the
# layout to that fixed bottom; see the dialogue box built in _build().
const DIALOG_BOX_BOTTOM := 648.0   # outer frame bottom edge (fixed)
const DIALOG_TEXT_BOTTOM := 640.0  # text_label bottom edge (fixed)
const DIALOG_TEXT_MIN_H := 148.0   # original text capacity — box never shrinks below it
const DIALOG_SPEAKER_GAP := 30.0   # speaker name sits this far above the text top
const DIALOG_HEADER := 44.0        # frame top sits this far above the text top

## Fit the box to whatever text_label currently holds: keep the bottom pinned
## and push the top up as far as the wrapped text needs (never higher than the
## original box). Returns the frame's top y so a choice panel can stack above
## the ACTUAL top rather than the old fixed one. Both callers set the text first.
func _fit_dialogue_box() -> float:
	# get_line_count() forces the label to (re)shape, so the wrapped line count is
	# accurate right after assigning .text as long as the label is in the tree (it
	# is). All lines share one font, so height = lines * per-line height.
	var wrapped_h := text_label.get_line_count() * text_label.get_line_height()
	var text_h: float = max(float(wrapped_h), DIALOG_TEXT_MIN_H)
	var text_top := DIALOG_TEXT_BOTTOM - text_h
	text_label.position.y = text_top
	text_label.size.y = text_h
	speaker_label.position.y = text_top - DIALOG_SPEAKER_GAP
	var frame_top := text_top - DIALOG_HEADER
	dialogue_frame.position.y = frame_top
	dialogue_frame.size.y = DIALOG_BOX_BOTTOM - frame_top
	dialogue_inner.position.y = frame_top + 3.0
	dialogue_inner.size.y = (DIALOG_BOX_BOTTOM - 3.0) - (frame_top + 3.0)
	return frame_top


func _show_line() -> void:
	var line: Array = dialogue_lines[dialogue_index]
	speaker_label.text = line[0]
	text_label.text = game.touchify(line[1])
	_fit_dialogue_box()
	_set_portrait(String(line[0]))
	game.sfx("talk")
	# MP-13 (§5.4): when THIS machine drives a chapter beat, mirror the line
	# to the spectating party (read-only). Inert offline / for private convos.
	if game.beat_broadcasting:
		var s: Node = game.net_session()
		if s != null:
			s.beat_line(String(line[0]), String(line[1]), [])


func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		dialogue_active = false
		dialogue_box.visible = false
		game.request_pause(false)
		if dialogue_done.is_valid():
			dialogue_done.call()
	else:
		_show_line()


## Cinematic mode: the few HUD bits a cutscene can't cover get hidden.
## MOBILE (touch_hud.gd calls this on mount): hide the keyboard-only HUD chrome
## the on-screen controls replace — the bottom ability bar (its icons/cooldowns
## live on the touch arc now) and the WASD/keys hint lines. Kept cinematic-safe
## via _touch_mode so a cutscene end can't re-show the hints on a phone.
func set_touch_mode(on: bool) -> void:
	_touch_mode = on
	for l in hint_labels:
		l.visible = not on
	for box in slot_boxes:
		for k in ["border", "bg", "icon", "cd", "num", "key", "cost", "name"]:
			if box.get(k) != null:
				box[k].visible = not on


func set_cinematic(on: bool) -> void:
	for l in hint_labels:
		l.visible = (not on) and not _touch_mode


# ------------------------------------------- beat mirror (MP-13, §5.4)
# A spectator's read-only view of a chapter beat another player drives —
# the same speaker/text the initiator reads, options shown but not clickable.
# Built lazily; solo and private overlays never touch it.

func _ensure_mirror() -> void:
	if mirror_box != null:
		return
	mirror_box = Control.new()
	mirror_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mirror_box)
	mirror_frame = ColorRect.new()
	mirror_frame.color = Color(0.55, 0.5, 0.75)  # a cooler frame than your own gold box
	mirror_frame.position = Vector2(340, 150)
	mirror_frame.size = Vector2(600, 132)
	mirror_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_box.add_child(mirror_frame)
	mirror_inner = ColorRect.new()
	mirror_inner.color = Color(0.08, 0.07, 0.12, 0.94)
	mirror_inner.position = Vector2(343, 153)
	mirror_inner.size = Vector2(594, 126)
	mirror_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_box.add_child(mirror_inner)
	mirror_header = Label.new()
	mirror_header.position = Vector2(356, 158)
	mirror_header.add_theme_font_size_override("font_size", 12)
	mirror_header.add_theme_color_override("font_color", Color(0.72, 0.72, 0.88))
	mirror_box.add_child(mirror_header)
	mirror_speaker = Label.new()
	mirror_speaker.position = Vector2(356, 176)
	UITheme.title(mirror_speaker, 16)
	mirror_speaker.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	mirror_box.add_child(mirror_speaker)
	mirror_text = Label.new()
	mirror_text.position = Vector2(356, 200)
	mirror_text.size = Vector2(568, 48)
	mirror_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Safety rail only (never a design behavior): a beat that trips the
	# ellipsis should be edited shorter, not scrolled.
	mirror_text.max_lines_visible = 8
	mirror_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mirror_text.add_theme_font_size_override("font_size", 14)
	mirror_box.add_child(mirror_text)
	mirror_options = Label.new()
	mirror_options.position = Vector2(356, 252)
	mirror_options.size = Vector2(568, 22)
	mirror_options.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mirror_options.max_lines_visible = 3
	mirror_options.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mirror_options.add_theme_font_size_override("font_size", 12)
	mirror_options.add_theme_color_override("font_color", Color(0.62, 0.67, 0.82))
	mirror_box.add_child(mirror_options)
	mirror_box.visible = false


## Size the frame to its content. The text label autowraps in a fixed
## 568px column, and a wrapped Label's rect grows DOWN to its min height
## — a paragraph-long beat used to spill straight past the fixed 132px
## frame bottom (and a long 3-choice summary past its single row). Measure
## the wrapped line counts, stack text → options, and pull the frame down
## around them; short beats land on the same compact box as before.
func _mirror_layout() -> void:
	var f: Font = mirror_text.get_theme_font("font")
	var text_h := 24.0
	if mirror_text.text != "":
		var lh: float = f.get_height(14) + 3.0   # +line spacing
		var lines: int = maxi(1, int(roundf(
			f.get_multiline_string_size(mirror_text.text, HORIZONTAL_ALIGNMENT_LEFT,
				568.0, 14, mirror_text.max_lines_visible).y / f.get_height(14))))
		text_h = lines * lh
	mirror_text.size = Vector2(568, text_h)
	var opt_y := 200.0 + text_h + 6.0
	var opt_h := 0.0
	if mirror_options.text != "":
		var olh: float = f.get_height(12) + 3.0
		var olines: int = maxi(1, int(roundf(
			f.get_multiline_string_size(mirror_options.text, HORIZONTAL_ALIGNMENT_LEFT,
				568.0, 12, mirror_options.max_lines_visible).y / f.get_height(12))))
		opt_h = olines * olh
	mirror_options.position.y = opt_y
	mirror_options.size = Vector2(568, maxf(opt_h, 22.0))
	var bottom := opt_y + opt_h + 8.0
	mirror_frame.size.y = bottom - 150.0 + 3.0
	mirror_inner.size.y = mirror_frame.size.y - 6.0


## A beat began — someone else is speaking. Open the read-only transcript.
func mirror_begin(initiator: String) -> void:
	_ensure_mirror()
	mirror_header.text = "▸ %s is speaking with someone…" % initiator
	mirror_speaker.text = ""
	mirror_text.text = ""
	mirror_options.text = ""
	_mirror_layout()
	mirror_box.visible = true


## The current beat line (and any options, shown read-only).
func mirror_line(speaker: String, text: String, options: Array) -> void:
	_ensure_mirror()
	mirror_speaker.text = speaker
	mirror_text.text = text
	if options.is_empty():
		mirror_options.text = ""
	else:
		var parts: Array = []
		for o in options:
			parts.append(String(o))
		mirror_options.text = "deciding:  " + "   ·   ".join(parts)
	_mirror_layout()
	mirror_box.visible = true


## The beat ended — close the transcript.
func mirror_end() -> void:
	if mirror_box != null:
		mirror_box.visible = false


## A dialogue line that ends in a DECISION: the text shows in the normal
## box, the options stack above it, and the number keys or a click choose.
func dialogue_choice(who: String, text: String, options: Array, cb: Callable) -> void:
	game.request_pause(true)
	dialogue_box.visible = true
	speaker_label.text = who
	text_label.text = text
	var box_top := _fit_dialogue_box()
	_set_portrait(who)
	game.sfx("talk")
	# MP-13 (§5.4): mirror the decision to spectators of a driven beat (they
	# see the prompt and options read-only; the initiator makes the call).
	if game.beat_broadcasting:
		var s: Node = game.net_session()
		if s != null:
			s.beat_line(who, text, options)
	choice_cb = cb
	choice_count = options.size()
	choices_active = true

	# Options wrap now, so each row is as tall as its wrapped text. Set the text +
	# width and MEASURE every row first (get_line_count forces a reshape), total
	# the panel height, then stack the rows so a 2-line option can't overlap the
	# next. ROW_W is the label width inside the fixed 1004 frame.
	const ROW_W := 965.0
	const PANEL_PAD := 8.0   # top & bottom padding inside the frame
	const ROW_GAP := 6.0     # gap between option rows
	var row_h: Array = []
	var total := PANEL_PAD * 2.0
	for i in choice_option_labels.size():
		var opt: Label = choice_option_labels[i]
		if i < choice_count:
			opt.text = "%d.  %s" % [i + 1, options[i]]
			opt.size.x = ROW_W
			var rh: float = maxf(opt.get_line_count() * opt.get_line_height(), 22.0)
			row_h.append(rh)
			total += rh + (ROW_GAP if i > 0 else 0.0)
		else:
			row_h.append(0.0)

	var panel_top := box_top - 6 - total  # 6px above the (possibly grown) box top
	choice_frame.position = Vector2(138, panel_top)
	choice_frame.size = Vector2(1004, total)
	choice_inner.position = choice_frame.position + Vector2(3, 3)
	choice_inner.size = choice_frame.size - Vector2(6, 6)
	var y := panel_top + PANEL_PAD
	for i in choice_option_labels.size():
		var opt: Label = choice_option_labels[i]
		var hl: ColorRect = choice_hover_rects[i]
		opt.visible = i < choice_count
		hl.visible = false  # fresh panel: no stale hover from the last decision
		opt.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
		if i < choice_count:
			var rh: float = row_h[i]
			# Full-width click target for the row (the wrapped label IS the target).
			opt.position = Vector2(168, y)
			opt.size = Vector2(ROW_W, rh)
			hl.position = Vector2(choice_inner.position.x, y - 2.0)
			hl.size = Vector2(choice_inner.size.x, rh + 4.0)
			y += rh + ROW_GAP
	choice_panel.visible = true


func _choose(idx: int) -> void:
	if not choices_active or idx < 0 or idx >= choice_count:
		return
	choices_active = false
	choice_panel.visible = false
	dialogue_box.visible = false
	game.request_pause(false)
	game.sfx("talk")
	var cb := choice_cb
	choice_cb = Callable()
	if cb.is_valid():
		cb.call(idx)  # the convo engine re-opens the box synchronously


## Mouse path onto the SAME _choose(idx) the number keys use. Marked
## handled so the click can't fall through to _unhandled_input and
## double-advance the dialogue the callback just re-opened.
func _on_choice_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_choose(idx)


## Hover feedback matching the menus' idiom: lighter row bg + the warm
## gold font_hover_color the shop buttons wear.
func _set_choice_hover(idx: int, on: bool) -> void:
	if idx < choice_hover_rects.size():
		choice_hover_rects[idx].visible = on and choices_active
	if idx < choice_option_labels.size():
		choice_option_labels[idx].add_theme_color_override("font_color",
			Color(1, 0.95, 0.7) if on else Color(0.92, 0.9, 0.8))


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
			# SPACE during play drops a Tab target-lock (confirm is a no-op
			# here — it only advances dialogue, which isn't active). The key
			# only SETS the release intent — the player consumes the edge in
			# its physics step (device-agnostic seam: the mobile HUD lock
			# button writes the same field, MULTIPLAYER.md §10).
			if event.keycode == KEY_SPACE and game.state == game.ST_PLAYING \
					and not dialogue_active and game.local_player.locked_target != null:
				game.local_player.intent_lock_release = true
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_on_escape()
		elif event.keycode == KEY_R and game.state == game.ST_VICTORY:
			# MP-14 (§5.4/§5.7): in a session, restarting ENDS the run — the
			# host tells the party to autosave + drop out; both sides leave the
			# session gracefully before the local scene reloads.
			if game.net_online():
				if game.net_host():
					game.net_session().host_end_session()
				var net := game.get_node_or_null("/root/NetworkManager")
				if net != null and net.is_online():
					net.leave()
			game.request_pause(false)
			get_tree().reload_current_scene()
		elif event.keycode == game.binds.get("target", KEY_TAB) \
				and game.state == game.ST_PLAYING and not dialogue_active:
			# Tab SETS the lock/cycle intent; the player consumes the edge
			# in its physics step (≤1 frame later — accepted). Mobile taps
			# the HUD lock button into this same field.
			game.local_player.intent_lock = true
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
	# Keep the popover's lean numbers live (refresh only when the value
	# moves — no per-frame string building).
	if _last_resonance <= -99998.0 or absf(res - _last_resonance) >= 0.5:
		res_label.set_meta("tip", _res_tip())
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


## The shard popover, with the live band lean spelled out in numbers
## (player rule: a mechanic the HUD wears must show its numbers).
func _res_tip() -> String:
	var base := "Resonance — how your shard leans: Virtue (+) or Temptation (−). Major choices move it, and the world answers through dialogue and merchant haggling."
	var p: Player = game.local_player  # per-client tooltip: MY shard
	if p == null or p.res_lean() <= 0.0:
		return base + "\nCommit past ±25 and a lean wakes: Virtue mends (potions heal deeper), Temptation hunts (bonus damage to wounded mobs, bonus kill gold)."
	if p.resonance > 0.0:
		return base + "\nConstancy: health potions mend +%d%% deeper." % int((p.constancy_heal_mult() - 1.0) * 100.0)
	return base + "\nHunger: +%d%% damage to wounded mobs, +%d%% gold from kills." % [
		int(p.hunger_exec_bonus() * 100.0), int((p.hunger_gold_mult() - 1.0) * 100.0)]


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
