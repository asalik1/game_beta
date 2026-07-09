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

# Shared palette — the parchment-gold chrome language of the cover.
const GOLD := Color(0.9, 0.8, 0.5)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.62)
const GOLD_DIM := Color(0.62, 0.53, 0.32)
const BRONZE := Color(0.45, 0.35, 0.18)
const PANEL_BG := Color(0.09, 0.08, 0.13, 0.98)
const BAR_FRAME := Color(0.52, 0.44, 0.26)

static var _font: Font = null
static var _font_missing := false
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


## Panel/screen title treatment: display font at a title size.
static func title(l: Label, size := 0) -> Label:
	var f := display_font()
	if f != null:
		l.add_theme_font_override("font", f)
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
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	parent.add_child(p)

	# Inner bevel: a quiet bronze line 4px inside the gold border.
	var bevel := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0)
	bsb.border_color = Color(BRONZE, 0.85)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(7)
	bevel.add_theme_stylebox_override("panel", bsb)
	bevel.position = Vector2(4, 4)
	bevel.size = sz - Vector2(8, 8)
	bevel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bevel)

	# Top-edge sheen: candlelight catching the frame's upper rim.
	var sheen := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.85, 0.55, 0.09))
	g.set_color(1, Color(0.95, 0.85, 0.55, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sheen.texture = gt
	sheen.position = Vector2(10, 3)
	sheen.size = Vector2(sz.x - 20, 44)
	sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheen.stretch_mode = TextureRect.STRETCH_SCALE
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sheen)

	# Corner gems on the bottom rim (top corners host the title and ✕).
	for cx: float in [14.0, sz.x - 22.0]:
		var dm := Label.new()
		dm.text = "◆"
		dm.position = Vector2(cx, sz.y - 22.0)
		dm.add_theme_font_size_override("font_size", 11)
		dm.add_theme_color_override("font_color", Color(GOLD_DIM, 0.8))
		dm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(dm)
	return p


## Title underline: gold fading out to the right (replaces the flat rule).
static func rule(parent: Node) -> Control:
	var r := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(GOLD, 0.55))
	g.set_color(1, Color(GOLD, 0.04))
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
	var bn := _flat(Color(0.13, 0.12, 0.17, 0.55), Color(0.55, 0.47, 0.28, 0.45), 1, 4)
	bn.content_margin_left = 10.0
	bn.content_margin_right = 10.0
	bn.content_margin_top = 3.0
	bn.content_margin_bottom = 3.0
	t.set_stylebox("normal", "Button", bn)
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color(0.20, 0.18, 0.25, 0.85)
	bh.border_color = Color(GOLD, 0.9)
	t.set_stylebox("hover", "Button", bh)
	var bp: StyleBoxFlat = bh.duplicate()
	bp.bg_color = Color(0.07, 0.06, 0.10, 0.9)
	t.set_stylebox("pressed", "Button", bp)
	var bd: StyleBoxFlat = bn.duplicate()
	bd.bg_color = Color(0.10, 0.10, 0.13, 0.3)
	bd.border_color = Color(0.32, 0.32, 0.36, 0.3)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

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
