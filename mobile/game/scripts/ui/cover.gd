class_name UICover
## The opening COVER (boot stage 1, Graphics & Ambience track): a
## full-screen title card shown before anything interactive. Any key or
## click advances to the character roster (menus.open_slots).
##
## Procedural set by default — night sky, rising embers, the Ember
## Crown floating in a bloom halo, the four founders' Embers circling
## it. Drop assets/sprites/cover.png to replace the whole set with
## hand-made art; the wordmark and the key prompt are drawn on top of
## either set. Static module per the scripts/ui/ pattern.
##
## The wordmark is ENGINE-drawn on both paths (2026-07-17). It used to be
## baked into cover.png, which cost twice: image generators mangle
## letterforms, and text is the element that reads worst when the art is
## magnified — the old cover carried only 320x180 of real information, so
## the logo was the first thing to fall apart. A vector font re-renders
## crisp at every resolution forever and costs nothing to retitle.


const COVER_MAX := 8      # cover.png + cover_2..cover_8
const COVER_HOLD := 10.0  # seconds a cover is held before the next fades in
const COVER_FADE := 1.4   # crossfade length


## Every hand-made cover, in order: cover.png, then cover_2.png, cover_3.png…
## stopping at the first gap. PROBED, never directory-scanned — an exported
## .pck has no loose files to walk, and .import'd PNGs land as .ctex, so
## DirAccess would come back empty in a real build and silently drop the art.
static func _covers() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if ResourceLoader.exists("res://assets/sprites/cover.png"):
		out.append(load("res://assets/sprites/cover.png"))
	for i in range(2, COVER_MAX + 1):
		var p := "res://assets/sprites/cover_%d.png" % i
		if not ResourceLoader.exists(p):
			break  # contiguous: a gap ends the set
		out.append(load(p))
	return out


## Crossfade the cover every COVER_HOLD seconds. Two layers: `back` holds what
## you see, `front` fades the next one in on top, then back takes it and front
## snaps invisible — so N covers need exactly 2 nodes and one looping tween.
static func _cycle(root: Control, back: TextureRect, covers: Array[Texture2D]) -> void:
	var front := TextureRect.new()
	front.texture = back.texture
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.expand_mode = back.expand_mode
	front.stretch_mode = back.stretch_mode
	front.texture_filter = back.texture_filter
	front.modulate.a = 0.0
	root.add_child(front)

	var tw := front.create_tween().set_loops()
	for i in covers.size():
		var nxt: Texture2D = covers[(i + 1) % covers.size()]
		tw.tween_interval(COVER_HOLD)
		tw.tween_callback(func() -> void: front.texture = nxt)
		tw.tween_property(front, "modulate:a", 1.0, COVER_FADE)
		tw.tween_callback(func() -> void: back.texture = nxt)
		tw.tween_property(front, "modulate:a", 0.0, 0.0)


static func build(m: Menus, root: Control) -> void:
	root.process_mode = Node.PROCESS_MODE_ALWAYS  # tweens run while paused

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Hand-made cover art overrides the whole procedural set.
	var covers := _covers()
	if not covers.is_empty():
		var ctex: Texture2D = covers[0]
		if ctex != null:
			var tr := TextureRect.new()
			tr.texture = ctex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			# The cover is drawn into the 1280x720 canvas rect, then the
			# canvas_items stretch scales that to the real window — so a cover
			# authored ABOVE 720p is net-DOWNSCALED on any sub-4K display
			# (a 3840x2160 cover lands at 0.5x on 1080p, 0.667x on 1440p).
			# The project filters NEAREST globally (pixel art wants that on the
			# UPSCALE side), but nearest DOWNSCALING decimates — it drops whole
			# pixels and shreds thin detail like the wordmark's edges (the same
			# failure that fragmented the hero sword blade). This is a per-node
			# override: full-screen chrome that shrinks, not a world sprite that
			# grows, so it does NOT touch the crisp look anywhere else.
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			root.add_child(tr)
			if covers.size() > 1:
				_cycle(root, tr, covers)
			_wordmark(root)
			_prompt(root)
			return

	# ---- procedural set -------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260706
	for i in 44:  # star field; a third of them twinkle
		var star := ColorRect.new()
		star.color = Color(1, 1, 1, rng.randf_range(0.2, 0.75))
		star.position = Vector2(rng.randf_range(10.0, 1268.0), rng.randf_range(8.0, 390.0))
		star.size = Vector2.ONE * (2.0 if rng.randf() < 0.8 else 3.0)
		root.add_child(star)
		if rng.randf() < 0.33:
			var stw := star.create_tween().set_loops()
			stw.tween_property(star, "modulate:a", 0.15, rng.randf_range(0.8, 1.8))
			stw.tween_property(star, "modulate:a", 1.0, rng.randf_range(0.8, 1.8))

	# Embers rise off the bottom of the frame, pre-warmed so the very
	# first frame already lives.
	var embers := CPUParticles2D.new()
	embers.amount = 42
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(660, 8)
	embers.position = Vector2(640, 740)
	embers.direction = Vector2(0, -1)
	embers.spread = 12.0
	embers.gravity = Vector2(0, -14)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 90.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.0
	embers.color = Color(1.0, 0.55, 0.2, 0.85)
	root.add_child(embers)

	# The Ember Crown, floating in a bloom halo (Forward+ glow).
	var halo := Sprite2D.new()
	halo.texture = Art.tex("glow")
	halo.modulate = Art.hdr(Color(1.0, 0.75, 0.3, 0.5), 1.8)
	halo.position = Vector2(640, 250)
	halo.scale = Vector2(7.0, 7.0)
	root.add_child(halo)
	var crown := Sprite2D.new()
	crown.texture = Art.tex("crown")
	crown.position = Vector2(640, 248)
	crown.scale = Art.scale_for(crown.texture, 8.0)
	root.add_child(crown)
	var bob := crown.create_tween().set_loops()
	bob.tween_property(crown, "position:y", 258.0, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(crown, "position:y", 248.0, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := halo.create_tween().set_loops()
	pulse.tween_property(halo, "scale", Vector2(7.8, 7.8), 2.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(halo, "scale", Vector2(7.0, 7.0), 2.2).set_trans(Tween.TRANS_SINE)

	# The four founders' Embers, circling what broke them.
	var orbit := Node2D.new()
	orbit.position = Vector2(640, 252)
	root.add_child(orbit)
	var ember_cols := [Color(1.0, 0.42, 0.25), Color(0.5, 1.0, 0.5),
		Color(0.5, 0.7, 1.0), Color(0.8, 0.5, 1.0)]
	for i in 4:
		var mote := Sprite2D.new()
		mote.texture = Art.tex("glow")
		mote.modulate = Art.hdr(Color(ember_cols[i], 0.8), 1.6)
		mote.position = Vector2.from_angle(TAU * i / 4.0) * 120.0
		mote.scale = Vector2(0.6, 0.6)
		orbit.add_child(mote)
	var spin := orbit.create_tween().set_loops()
	spin.tween_property(orbit, "rotation", TAU, 14.0).as_relative()

	_wordmark(root)
	_prompt(root)


## CROWNLESS / The Hollow King — drawn on BOTH the procedural set and the
## hand-made cover, in the display face, as vector text: crisp at any window
## size, and the one element a generated PNG reliably gets wrong.
##
## The kingdom in the fiction is still EMBERFALL and always will be (story.gd,
## terrains.gd) — only the GAME is Crownless (2026-07-17). The title names the
## question the whole story argues about (Accord: break the throne / Cinderborn:
## a crown is a tool), not the setting it argues in.
static func _wordmark(root: Control) -> void:
	var title := Label.new()
	title.text = "CROWNLESS"
	title.position = Vector2(0, 396)
	title.size = Vector2(1280, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.logo(title, 84)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	title.add_theme_constant_override("outline_size", 12)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "The Hollow King"
	sub.position = Vector2(0, 508)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.logo(sub, 21)
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	sub.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	sub.add_theme_constant_override("outline_size", 6)
	root.add_child(sub)


## The blinking "press any key" line — drawn on both procedural and
## hand-made covers.
static func _prompt(root: Control) -> void:
	var p := Label.new()
	p.text = "—  press any key  —"
	p.position = Vector2(0, 636)
	p.size = Vector2(1280, 30)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_font_size_override("font_size", 16)
	p.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	p.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	p.add_theme_constant_override("outline_size", 6)
	root.add_child(p)
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "modulate:a", 0.25, 0.9)
	tw.tween_property(p, "modulate:a", 1.0, 0.9)
