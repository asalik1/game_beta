class_name UITheme
## The global UI skin (theme pass, 2026-07-09). One place owns the look
## every menu screen inherits: the display font (Pixelify Sans, OFL —
## assets/fonts/), the shared panel chrome (gold border + bronze inner
## bevel + top sheen), and a code-built Theme resource that reskins the
## stock widgets (buttons, sliders, scrollbars) for every control under
## a menu root. Static module per the scripts/ui/ pattern.
##
## Usage: Menus._open() calls apply(root) + panel(...) + title(...);
## screens mark section headers with header(label); the HUD frames its
## bars with the shared palette constants.

const FONT_PATH := "res://assets/fonts/PixelifySans.ttf"
## The LOGO face — Cinzel Decorative (OFL), for the boot wordmark and NOTHING
## else (2026-07-17). Kept separate from FONT_PATH on purpose: a smooth
## inscriptional serif is right for one big word under the crown and wrong for
## the pixel chrome on every other screen, so this must not leak into
## title()/header(). See assets/fonts/CREDITS.txt.
const LOGO_FONT_PATH := "res://assets/fonts/CinzelDecorative-Bold.ttf"

# Shared palette — the parchment-gold chrome language of the cover.
const GOLD := Color(0.88, 0.67, 0.28)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.42)
const GOLD_DIM := Color(0.52, 0.43, 0.27)
const BRONZE := Color(0.36, 0.31, 0.24)
const PANEL_BG := Color(0.035, 0.042, 0.06, 0.985)
const SURFACE := Color(0.075, 0.085, 0.12, 0.96)
const SURFACE_RAISED := Color(0.105, 0.115, 0.16, 0.98)
const BORDER := Color(0.28, 0.30, 0.38, 0.72)
const TEXT_MUTED := Color(0.62, 0.65, 0.73)
const BAR_FRAME := Color(0.35, 0.37, 0.44)

static var _font: Font = null
static var _font_missing := false
static var _logo_font: Font = null
static var _logo_font_missing := false
static var _theme: Theme = null


## The display font for titles/headers ONLY (body text stays the default
## sans for readability). Null-safe: a missing TTF falls back to default.
static func display_font() -> Font:
	if _font == null and not _font_missing:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		else:
			_font_missing = true
	return _font


## The logo face, for the boot wordmark ONLY. Null-safe like display_font().
static func logo_font() -> Font:
	if _logo_font == null and not _logo_font_missing:
		if ResourceLoader.exists(LOGO_FONT_PATH):
			_logo_font = load(LOGO_FONT_PATH)
		else:
			_logo_font_missing = true
	return _logo_font


## Wordmark treatment — Cinzel at a logo size. Falls back to title() (Pixelify)
## if the TTF is absent, so the cover always draws something.
static func logo(l: Label, size := 0) -> Label:
	var f := logo_font()
	if f == null:
		return title(l, size)
	l.add_theme_font_override("font", f)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## Panel/screen title treatment: display font at a title size.
static func title(l: Label, size := 0) -> Label:
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## Section-header treatment: display font, keeps the label's size/color.
static func header(l: Label) -> Label:
	return title(l, 0)


## Attach the shared widget Theme to a menu root: every Button, HSlider
## and ScrollBar underneath inherits the skin with no per-screen code.
static func apply(c: Control) -> void:
	c.theme = _build()


## The dressed panel every menu screen sits in: near-black rounded rect,
## 2px gold border, a 1px bronze bevel line inset inside it, a soft
## top-edge sheen, and small gem-diamonds on the bottom corners (echoing
## the cover crown). Returns the outer Panel.
static func panel(parent: Control, pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.68)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 8)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	parent.add_child(p)

	# A short accent line gives the panel a clear top without boxing every edge.
	# ColorRect is deliberate: TextureRect enforces its generated texture's
	# minimum height and turned this three-pixel accent into a 64px banner.
	var accent := ColorRect.new()
	accent.color = Color(GOLD, 0.9)
	accent.position = Vector2(18, 0)
	accent.size = Vector2(minf(210.0, sz.x * 0.3), 3)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(accent)

	return p


## Title underline: gold fading out to the right (replaces the flat rule).
static func rule(parent: Node) -> Control:
	var r := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(GOLD, 0.62))
	g.add_point(0.24, Color(BORDER, 0.72))
	g.set_color(1, Color(BORDER, 0.12))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	r.texture = gt
	r.custom_minimum_size = Vector2(0, 2)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Shared content card. A narrow accent edge carries semantic color without
## outlining the whole card in it; this promotes the journal's strongest
## visual pattern to the rest of the interface.
static func card(parent: Node, accent := GOLD_DIM, padding := 12.0) -> PanelContainer:
	var card_box := PanelContainer.new()
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.border_color = Color(accent, 0.46)
	sb.border_width_left = 3
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(9)
	sb.content_margin_left = padding + 2.0
	sb.content_margin_right = padding
	sb.content_margin_top = padding - 2.0
	sb.content_margin_bottom = padding - 2.0
	card_box.add_theme_stylebox_override("panel", sb)
	parent.add_child(card_box)
	return card_box


## Selected/unselected tab treatment shared by codex, inventory and shops.
## The active state reads from shape and fill, not color alone.
static func tab(button: Button, active: bool, accent := GOLD) -> Button:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size.y = 38.0
	var normal := _flat(Color(0.05, 0.06, 0.085, 0.72), Color(BORDER, 0.62), 1, 8)
	normal.content_margin_left = 13.0
	normal.content_margin_right = 13.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	if active:
		normal.bg_color = Color(accent, 0.13)
		normal.border_color = Color(accent, 0.82)
		normal.border_width_bottom = 3
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent, 0.18 if active else 0.10)
	hover.border_color = Color(accent, 0.92)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


# --------------------------------------------------------- widget skin ---

static func _flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


## A small diamond grabber texture (sliders): gold fill, dark edge.
static func _diamond(px: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	for y in px:
		for x in px:
			var d := absf(x - c) + absf(y - c)
			if d <= c - 2.0:
				img.set_pixel(x, y, fill)
			elif d <= c:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


static func _build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()

	# --- Buttons: real bordered chrome with a hover state. The SEMANTIC
	# font colors (green resume / red quit / grade colors) stay untouched —
	# they're per-button overrides; this is just the box under them.
	var bn := _flat(Color(0.065, 0.075, 0.105, 0.88), Color(BORDER, 0.72), 1, 8)
	bn.content_margin_left = 12.0
	bn.content_margin_right = 12.0
	bn.content_margin_top = 6.0
	bn.content_margin_bottom = 6.0
	t.set_stylebox("normal", "Button", bn)
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = SURFACE_RAISED
	bh.border_color = Color(GOLD, 0.72)
	t.set_stylebox("hover", "Button", bh)
	var bp: StyleBoxFlat = bh.duplicate()
	bp.bg_color = Color(0.045, 0.05, 0.075, 0.98)
	t.set_stylebox("pressed", "Button", bp)
	var bd: StyleBoxFlat = bn.duplicate()
	bd.bg_color = Color(0.06, 0.065, 0.085, 0.46)
	bd.border_color = Color(BORDER, 0.32)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	# Text fields share the same neutral surface and use the accent only while
	# focused, keeping name entry and chat consistent with menu controls.
	var field := _flat(Color(0.035, 0.042, 0.062, 0.96), BORDER, 1, 8)
	field.content_margin_left = 12.0
	field.content_margin_right = 12.0
	field.content_margin_top = 8.0
	field.content_margin_bottom = 8.0
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, field)
		var field_focus: StyleBoxFlat = field.duplicate()
		field_focus.border_color = Color(GOLD, 0.86)
		t.set_stylebox("focus", cls, field_focus)

	# --- HSlider: dark groove, gold fill, diamond grabber.
	var groove := _flat(Color(0.05, 0.05, 0.08, 0.95), Color(0.4, 0.35, 0.22, 0.8), 1, 2)
	groove.content_margin_top = 4.0
	groove.content_margin_bottom = 4.0
	t.set_stylebox("slider", "HSlider", groove)
	var area := _flat(Color(0.85, 0.72, 0.38), Color(0.85, 0.72, 0.38), 0, 2)
	t.set_stylebox("grabber_area", "HSlider", area)
	var area_hi := _flat(GOLD_BRIGHT, GOLD_BRIGHT, 0, 2)
	t.set_stylebox("grabber_area_highlight", "HSlider", area_hi)
	var grb := _diamond(15, Color(0.85, 0.72, 0.38), Color(0.24, 0.18, 0.08))
	var grb_hi := _diamond(15, GOLD_BRIGHT, Color(0.35, 0.27, 0.1))
	t.set_icon("grabber", "HSlider", grb)
	t.set_icon("grabber_highlight", "HSlider", grb_hi)
	t.set_icon("grabber_disabled", "HSlider", _diamond(15, Color(0.35, 0.33, 0.3), Color(0.18, 0.17, 0.15)))

	# --- ScrollBars: thin dark track, gold-dim thumb that wakes on hover.
	for cls in ["VScrollBar", "HScrollBar"]:
		var track := _flat(Color(0.04, 0.04, 0.07, 0.85), Color(0.3, 0.27, 0.2, 0.5), 1, 3)
		track.set_content_margin_all(2.0)
		t.set_stylebox("scroll", cls, track)
		t.set_stylebox("scroll_focus", cls, track.duplicate())
		var thumb := _flat(Color(GOLD_DIM, 0.75), Color(GOLD_DIM, 0.75), 0, 3)
		thumb.set_content_margin_all(3.0)
		t.set_stylebox("grabber", cls, thumb)
		var thumb_hi: StyleBoxFlat = thumb.duplicate()
		thumb_hi.bg_color = Color(GOLD, 0.95)
		t.set_stylebox("grabber_highlight", cls, thumb_hi)
		var thumb_pr: StyleBoxFlat = thumb.duplicate()
		thumb_pr.bg_color = GOLD_BRIGHT
		t.set_stylebox("grabber_pressed", cls, thumb_pr)

	_theme = t
	return t
