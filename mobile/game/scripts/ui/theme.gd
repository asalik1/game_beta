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

## WORLD face (gameplay-polish 2026-08-18): damage numbers, floating combat
## labels, the target reticle, enemy-bar tags, zone banners. Outside feedback
## on the trailer read the engine-default sans over the world as "beta"; a
## face with a spine fixes more than any single art asset. First path that
## exists wins: Cinzel Bold (OFL, the inscriptional caps face — pending the
## owner's download approval); else a synthetic-BOLD variation of the engine
## default (FontVariation.embolden — heavier numbers with no new asset). NOT
## Pixelify: its "2" reads as "S" at 21px (rig 2026-08-18: "22" -> "SS").
const WORLD_FONT_PATHS: Array[String] = [
	"res://assets/fonts/Cinzel-Bold.ttf",       # static Bold from the fonts.google.com zip
	"res://assets/fonts/Cinzel-Variable.ttf",   # the variable file from github.com/google/fonts (Cinzel[wght].ttf, renamed; wght 700 applied)
]
const WORLD_FALLBACK_EMBOLDEN := 0.55
const VARIABLE_BOLD_WGHT := 700
## BODY face: HUD stat lines, dialogue, hints, menu text — a warm humanist
## text face that stays readable at 13-16px (Alegreya Sans, OFL, pending
## approval). Null when absent so the HUD keeps the engine default and
## nothing reflows unexpectedly. Bold sibling for emphasis rows.
const BODY_FONT_PATHS: Array[String] = ["res://assets/fonts/AlegreyaSans-Regular.ttf"]
const BODY_BOLD_FONT_PATHS: Array[String] = ["res://assets/fonts/AlegreyaSans-Bold.ttf"]
## HEADER face for chrome titles (title()/header(): zone banner, chapter card,
## menu titles). Cinzel only — NO Pixelify fallback: the 2026-08-02 HUD pass
## deliberately took the pixel face off the chrome, so absent Cinzel the
## headers keep the engine default exactly as that pass left them.
const HEADER_FONT_PATHS: Array[String] = [
	"res://assets/fonts/Cinzel-Bold.ttf", "res://assets/fonts/Cinzel-Variable.ttf",
]

# Shared palette — the parchment-gold chrome language of the cover.
const GOLD := Color(0.88, 0.67, 0.28)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.42)
const GOLD_DIM := Color(0.52, 0.43, 0.27)
const BRONZE := Color(0.36, 0.31, 0.24)
const PANEL_BG := Color(0.070, 0.047, 0.030, 0.985)
const SURFACE := Color(0.115, 0.079, 0.049, 0.96)
const SURFACE_RAISED := Color(0.170, 0.120, 0.074, 0.98)
const BORDER := Color(0.36, 0.27, 0.17, 0.72)
const TEXT_MUTED := Color(0.62, 0.65, 0.73)

# Protected source geometry, NOT appearance tuning: never scale these slices.
const FRAME_ROOT := "res://assets/ui/frame/"
const PANEL_SLICE := 16.0
const CARD_SLICE := 9.0
const TAB_SLICE := 5.0
const SLOT_SLICE := 6.0
const SLOT_SIZE := 48.0
const SLOT_WELL := 36
const DIVIDER_REGIONS := [Rect2(0, 0, 16, 32), Rect2(16, 0, 216, 32),
	Rect2(232, 0, 48, 32), Rect2(280, 0, 216, 32), Rect2(496, 0, 16, 32)]
const HEADER_RULE_FOOTPRINT := 2.0   # the pre-forge rule's height, kept for layout

static var _font: Font = null
static var _font_missing := false
static var _logo_font: Font = null
static var _logo_font_missing := false
static var _theme: Theme = null
static var _face_cache := {}   # "world"/"body"/"body_bold" -> Font or null (resolved once)
## Folder the builders read the frame kit from. Only tests repoint it (at a
## missing folder) to drive every builder down its flat fallback.
static var frame_root := FRAME_ROOT
static var _slot_rims := {}    # "<path>|<tint html>" -> rim-tinted slot texture


## Resolve the first present font in a path list; null if none ships. A
## VARIABLE font file ("[wght]" in the name) is wrapped in a FontVariation at
## the bold weight — the world/header faces are the bold cut.
static func _first_face(key: String, paths: Array[String]) -> Font:
	if _face_cache.has(key):
		return _face_cache[key]
	var f: Font = null
	for p in paths:
		if ResourceLoader.exists(p):
			f = load(p)
			if p.contains("[wght]") or p.contains("-Variable"):
				var fv := FontVariation.new()
				fv.base_font = f
				var wght_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
				fv.variation_opentype = {wght_tag: VARIABLE_BOLD_WGHT}
				f = fv
			break
	_face_cache[key] = f
	return f


## The world/combat face (see WORLD_FONT_PATHS): the shipped face if any,
## else an emboldened copy of the engine default. Never null.
static func world_font() -> Font:
	var f := _first_face("world", WORLD_FONT_PATHS)
	if f != null:
		return f
	if not _face_cache.has("world_fallback"):
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = WORLD_FALLBACK_EMBOLDEN
		_face_cache["world_fallback"] = fv
	return _face_cache["world_fallback"]


## The body face for HUD/menu text (see BODY_FONT_PATHS). Null when absent.
static func body_font() -> Font:
	return _first_face("body", BODY_FONT_PATHS)


static func body_bold_font() -> Font:
	return _first_face("body_bold", BODY_BOLD_FONT_PATHS)


## The chrome header face (see HEADER_FONT_PATHS). Null until Cinzel ships.
static func header_font() -> Font:
	return _first_face("header", HEADER_FONT_PATHS)


## World-text treatment: the world face (when present) at `size`, with a
## solid dark outline so it survives any floor. Returns the label.
static func world(l: Label, size := 0, outline := 4) -> Label:
	var f := world_font()
	if f != null:
		l.add_theme_font_override("font", f)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		l.add_theme_constant_override("outline_size", outline)
	return l


## Body-text treatment for a whole Control subtree: sets the theme's default
## font to the body face so every Label/Button under `root` reskins at once.
## No-op when no body face ships (the engine default stays, layouts unchanged).
static func apply_body(root: Control) -> void:
	var f := body_font()
	if f == null:
		return
	var t: Theme = root.theme if root.theme != null else Theme.new()
	t.default_font = f
	root.theme = t


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


## Panel/screen title treatment: the header face (when it ships — see
## HEADER_FONT_PATHS) at a title size; else just the size.
static func title(l: Label, size := 0) -> Label:
	var f := header_font()
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


## Shared forged panel; the original flat construction remains the fallback.
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
	var frame := frame_style(frame_root + "panel.png", PANEL_SLICE, sb)
	p.add_theme_stylebox_override("panel", frame)
	p.position = pos
	p.size = sz
	parent.add_child(p)

	if frame is StyleBoxFlat:
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


## Five atlas pieces preserve the boss and caps while only the rails stretch.
static func rule(parent: Node) -> Control:
	var texture := _frame_texture(frame_root + "divider.png")
	if texture == null:
		return _flat_rule(parent)
	var row := HBoxContainer.new()
	row.name = "ForgedDivider"
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = Balance.UI_FRAME_DIVIDER_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in DIVIDER_REGIONS.size():
		var region: Rect2 = DIVIDER_REGIONS[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		var piece := TextureRect.new()
		piece.texture = atlas
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_SCALE
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 1 or i == 3:
			piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			piece.custom_minimum_size.x = region.size.x * Balance.UI_FRAME_DIVIDER_HEIGHT / region.size.y
		row.add_child(piece)
	parent.add_child(row)
	return row


## Shell-title variant: the same forged divider, drawn centered over the old
## 2px rule's layout footprint so its boss rides in the title/content gaps
## instead of pushing every shell's content 14px down. The parent's separation
## must be at least half the divider height minus one (menus' shells use 10).
static func header_rule(parent: Node) -> Control:
	if _frame_texture(frame_root + "divider.png") == null:
		return _flat_rule(parent)
	var slot := Control.new()
	slot.name = "ForgedHeaderRule"
	slot.custom_minimum_size.y = HEADER_RULE_FOOTPRINT
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var row := rule(slot)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = 0.0
	row.offset_right = 0.0
	row.offset_top = -Balance.UI_FRAME_DIVIDER_HEIGHT * 0.5
	row.offset_bottom = Balance.UI_FRAME_DIVIDER_HEIGHT * 0.5
	return slot


## Original rule retained for absent frame art.
static func _flat_rule(parent: Node) -> Control:
	var r := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(GOLD, 0.62))
	g.set_color(1, Color(BORDER, 0.12))
	g.add_point(0.24, Color(BORDER, 0.72))
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


## Shared forged card with content kept inside the protected nine-pixel rim.
## `accent` only colors the flat fallback's narrow edge: the forged art is
## never recolored, so a meaning the accent carried (grade, faction) must also
## show in the card's content.
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
	var frame := frame_style(frame_root + "card.png", CARD_SLICE, sb)
	if frame is StyleBoxTexture:
		frame.content_margin_left = maxf(CARD_SLICE, sb.content_margin_left)
		frame.content_margin_right = maxf(CARD_SLICE, sb.content_margin_right)
		frame.content_margin_top = maxf(CARD_SLICE, sb.content_margin_top)
		frame.content_margin_bottom = maxf(CARD_SLICE, sb.content_margin_bottom)
	card_box.add_theme_stylebox_override("panel", frame)
	parent.add_child(card_box)
	return card_box


## Selected/unselected tab treatment shared by codex, inventory and shops.
## The active state reads from shape and fill, not color alone. As with
## card(), `accent` tints only the flat fallback; the forged tabs keep their art.
static func tab(button: Button, active: bool, accent := GOLD) -> Button:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size.y = Balance.UI_FRAME_TAB_HEIGHT
	var normal := _fallback_flat(Color(PANEL_BG, 0.72), Color(BORDER, 0.62), 1, 8)
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
	var path := frame_root + ("tab_active.png" if active else "tab_idle.png")
	var framed := frame_style(path, TAB_SLICE, normal)
	var hovered := frame_style(path, TAB_SLICE, hover)
	if framed is StyleBoxTexture:
		framed.modulate_color = Color.WHITE if active else Color(Balance.UI_FRAME_IDLE_LIFT, Balance.UI_FRAME_IDLE_LIFT, Balance.UI_FRAME_IDLE_LIFT)
		hovered.modulate_color = framed.modulate_color * Color(Balance.UI_FRAME_HOVER_LIFT, Balance.UI_FRAME_HOVER_LIFT, Balance.UI_FRAME_HOVER_LIFT, 1.0)
		for box in [framed, hovered]:
			box.content_margin_left = Balance.UI_FRAME_TAB_PAD_X
			box.content_margin_right = Balance.UI_FRAME_TAB_PAD_X
			# 25px codex rail leaves 15px for its shaped text, outside both rims.
			box.content_margin_top = TAB_SLICE
			box.content_margin_bottom = TAB_SLICE
	button.add_theme_stylebox_override("normal", framed)
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("pressed", hovered)
	return button


# --------------------------------------------------------- widget skin ---

## Missing paths resolve quietly; a failed load also keeps the old flat skin.
static func _frame_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func frame_style(path: String, slice_margin: float, fallback: StyleBoxFlat) -> StyleBox:
	var texture := _frame_texture(path)
	if texture == null:
		return fallback
	return _sliced(texture, slice_margin)


static func _sliced(texture: Texture2D, slice_margin: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, slice_margin)
		sb.set_content_margin(side, slice_margin)
	return sb


## Boot shells fade their panel without assuming which skin is available.
static func with_opacity(style: StyleBox, alpha: float) -> StyleBox:
	var copy: StyleBox = style.duplicate()
	if copy is StyleBoxTexture:
		copy.modulate_color.a = alpha
	elif copy is StyleBoxFlat:
		copy.bg_color.a = alpha
	return copy


## Grade/semantic socket: only slot.png's six-pixel rim takes the color, and
## it takes it exactly (a gold rim multiplied by blue reads olive). The well
## inside keeps the art's own interior, so icons sit on the same clear ground
## at every grade.
static func slot_style(color: Color, hovered := false) -> StyleBox:
	var fallback := _fallback_flat(SURFACE_RAISED if hovered else SURFACE, color, 2, 4)
	fallback.set_content_margin_all(SLOT_SLICE)
	var rim := _slot_rim(frame_root + "slot.png", color)
	if rim == null:
		return fallback
	var sb := _sliced(rim, SLOT_SLICE)
	if hovered:
		sb.modulate_color = Color(Balance.UI_FRAME_HOVER_LIFT, Balance.UI_FRAME_HOVER_LIFT, Balance.UI_FRAME_HOVER_LIFT)
	sb.set_meta("slot_tint", color)
	return sb


## slot.png with its rim band recolored, cached per tint. Each rim pixel keeps
## its brightness relative to the brightest rim pixel, so the forged relief
## survives while the hue is exactly `color`; the brightest pixel IS `color`.
static func _slot_rim(path: String, color: Color) -> Texture2D:
	var key := path + "|" + color.to_html()
	if _slot_rims.has(key):
		return _slot_rims[key]
	var texture := _frame_texture(path)
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null or source.is_empty():
		return null
	# A copy: the headless renderer hands back the image it keeps for the texture.
	var img: Image = source.duplicate()
	if img.is_compressed() and img.decompress() != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var band := int(SLOT_SLICE)
	var rim_px: Array[Vector2i] = []
	var peak := 0.0
	for y in img.get_height():
		for x in img.get_width():
			if mini(mini(x, y), mini(img.get_width() - 1 - x, img.get_height() - 1 - y)) < band:
				rim_px.append(Vector2i(x, y))
				peak = maxf(peak, img.get_pixelv(Vector2i(x, y)).get_luminance())
	if peak <= 0.0:
		return null
	for at in rim_px:
		var px := img.get_pixelv(at)
		var lit := px.get_luminance() / peak
		img.set_pixelv(at, Color(color.r * lit, color.g * lit, color.b * lit, px.a))
	var tinted := ImageTexture.create_from_image(img)
	_slot_rims[key] = tinted
	return tinted


static func inventory_title(item: Dictionary) -> String:
	return Items.title(item).trim_prefix("[%s] " % item["grade"])


## Framed widget chrome (buttons, text fields). Callers set content margins;
## slices remain exactly 9px. Slider and scrollbar parts stay flat: a 4-8px
## track cannot hold a 9px slice, and their fill/thumb read only by color.
static func _flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBox:
	var sb := frame_style(frame_root + "card.png", CARD_SLICE, _fallback_flat(bg, border, bw, radius))
	if sb is StyleBoxTexture:
		sb.set_content_margin_all(0)
	return sb


static func _fallback_flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
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
	# Body face for every menu label/button when one ships (see BODY_FONT_PATHS).
	var bf := body_font()
	if bf != null:
		t.default_font = bf

	# --- Buttons: real bordered chrome with a hover state. The SEMANTIC
	# font colors (green resume / red quit / grade colors) stay untouched —
	# they're per-button overrides; this is just the box under them.
	var bn := _flat(Color(SURFACE, 0.88), Color(BORDER, 0.72), 1, 8)
	bn.content_margin_left = 12.0
	bn.content_margin_right = 12.0
	bn.content_margin_top = CARD_SLICE if bn is StyleBoxTexture else 6.0
	bn.content_margin_bottom = CARD_SLICE if bn is StyleBoxTexture else 6.0
	t.set_stylebox("normal", "Button", bn)
	var bh := _widget_state(bn, SURFACE_RAISED, Color(GOLD, 0.72), Balance.UI_FRAME_HOVER_LIFT)
	t.set_stylebox("hover", "Button", bh)
	# Pressed is also a toggle's SELECTED look (journal ward filters): it must
	# read brighter than an idle button, as the flat skin's gold rim did.
	var bp := _widget_state(bh, PANEL_BG, Color(GOLD, 0.72), Balance.UI_FRAME_PRESSED_LIFT)
	t.set_stylebox("pressed", "Button", bp)
	var bd := _widget_state(bn, Color(PANEL_BG, 0.46), Color(BORDER, 0.32), Balance.UI_FRAME_DISABLED_SHADE)
	t.set_stylebox("disabled", "Button", bd)
	# Focus overlays the existing chrome without changing its fill or layout.
	# Local Atlas and Codex focus styles retain their own overrides.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD_BRIGHT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	focus.set_content_margin_all(0)
	t.set_stylebox("focus", "Button", focus)

	# Text fields share the same neutral surface and use the accent only while
	# focused, keeping name entry and chat consistent with menu controls.
	var field := _flat(PANEL_BG, BORDER, 1, 8)
	field.content_margin_left = 12.0
	field.content_margin_right = 12.0
	field.content_margin_top = CARD_SLICE if field is StyleBoxTexture else 8.0
	field.content_margin_bottom = CARD_SLICE if field is StyleBoxTexture else 8.0
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, field)
		var field_focus := _widget_state(field, PANEL_BG, Color(GOLD, 0.86), Balance.UI_FRAME_HOVER_LIFT)
		t.set_stylebox("focus", cls, field_focus)

	# --- HSlider: dark groove, gold fill, diamond grabber. Flat on purpose (see
	# _flat): the fill is told from the groove by color alone.
	var groove := _fallback_flat(PANEL_BG, Color(0.4, 0.35, 0.22, 0.8), 1, 2)
	groove.content_margin_top = 4.0
	groove.content_margin_bottom = 4.0
	t.set_stylebox("slider", "HSlider", groove)
	var area := _fallback_flat(Color(0.85, 0.72, 0.38), Color(0.85, 0.72, 0.38), 0, 2)
	t.set_stylebox("grabber_area", "HSlider", area)
	var area_hi := _fallback_flat(GOLD_BRIGHT, GOLD_BRIGHT, 0, 2)
	t.set_stylebox("grabber_area_highlight", "HSlider", area_hi)
	var grb := _diamond(15, Color(0.85, 0.72, 0.38), Color(0.24, 0.18, 0.08))
	var grb_hi := _diamond(15, GOLD_BRIGHT, Color(0.35, 0.27, 0.1))
	t.set_icon("grabber", "HSlider", grb)
	t.set_icon("grabber_highlight", "HSlider", grb_hi)
	t.set_icon("grabber_disabled", "HSlider", _diamond(15, Color(0.35, 0.33, 0.3), Color(0.18, 0.17, 0.15)))

	# --- ScrollBars: thin dark track, gold-dim thumb that wakes on hover. Flat
	# on purpose (see _flat): the thumb is told from the track by color alone.
	for cls in ["VScrollBar", "HScrollBar"]:
		var track := _fallback_flat(Color(PANEL_BG, 0.85), Color(0.3, 0.27, 0.2, 0.5), 1, 3)
		track.set_content_margin_all(2.0)
		t.set_stylebox("scroll", cls, track)
		t.set_stylebox("scroll_focus", cls, track.duplicate())
		var thumb := _fallback_flat(Color(GOLD_DIM, 0.75), Color(GOLD_DIM, 0.75), 0, 3)
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


## State changes support both the forged art and the unchanged flat fallback.
static func _widget_state(base: StyleBox, bg: Color, border: Color, brightness: float) -> StyleBox:
	var sb: StyleBox = base.duplicate()
	if sb is StyleBoxFlat:
		sb.bg_color = bg
		sb.border_color = border
	elif sb is StyleBoxTexture:
		sb.modulate_color = Color(brightness, brightness, brightness, 1.0)
	return sb
