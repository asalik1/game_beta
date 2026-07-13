class_name Cutscene extends Control
## Full-screen staged vignettes played UNDER the dialogue box during
## story openings: pixel-art actors on a dark stage, animated per "cue"
## (Story.CONVOS nodes carry a "cue" key; Game._convo_node fires them).
## PROCESS_MODE_ALWAYS so the animation keeps moving while dialogue
## pauses the tree.

var game: Game
var stage: Node2D
var flash_rect: ColorRect


func _init(g: Node2D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.045, 0.035, 0.07)
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	stage = Node2D.new()
	add_child(stage)

	var vig := TextureRect.new()
	vig.texture = Art.tex("vignette")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.size = size
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0.0)
	flash_rect.size = size
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# Letterbox bars: it should FEEL like a film, not a paused game.
	for bar_y in [0.0, 668.0]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.position = Vector2(0, bar_y)
		bar.size = Vector2(1280, 52)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)


func _ready() -> void:
	game.hud.set_cinematic(true)


func _exit_tree() -> void:
	game.hud.set_cinematic(false)


# Every cue Story.CONVOS may reference (autotest validates against this).
const KNOWN_CUES := ["crown", "road", "aftermath", "camp", "camp_cold",
	"sickbed", "sickbed_wrong", "homestead", "severed", "hearing", "verdict",
	"tome", "tome_open", "fade"]


func cue(id: String) -> void:
	match id:
		"crown": _scene_crown()
		"road": _scene_road()
		"aftermath": _scene_aftermath()
		"camp": _scene_camp(false)
		"camp_cold": _scene_camp(true)
		"sickbed": _scene_sickbed(false)
		"sickbed_wrong": _scene_sickbed(true)
		"homestead": _scene_homestead(false)
		"severed": _scene_homestead(true)
		"hearing": _scene_hearing(false)
		"verdict": _scene_hearing(true)
		"tome": _scene_tome(false)
		"tome_open": _scene_tome(true)
		"fade": _fade_out()


## The sprite of whatever class the player picked.
func _hero_tex() -> String:
	return Classes.CLASSES[game.player.cls]["sprite"]


## Fade the picture away and free (the convo's on_done runs after).
func finish(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		queue_free()
		if cb.is_valid():
			cb.call())


# ------------------------------------------------------------- helpers ---

func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()
	stage.position = Vector2.ZERO


## An actor sprite. face_left is the DESIRED facing — Crawl override
## sprites natively face left, so the flip is corrected per sprite.
func _actor(tex_name: String, pos: Vector2, px_scale: float, face_left := false,
		tint := Color(1, 1, 1)) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex_name)
	s.scale = Art.scale_for(s.texture, px_scale)
	s.flip_h = face_left != Art.faces_left(tex_name)
	s.modulate = tint
	s.position = pos
	stage.add_child(s)
	return s


func _prop(color: Color, pos: Vector2, sz: Vector2, rot := 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = sz
	r.pivot_offset = sz / 2.0
	r.rotation = rot
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(r)
	return r


func _glow(pos: Vector2, color: Color, scl: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Art.tex("glow")
	g.modulate = color
	g.position = pos
	g.scale = Vector2(scl, scl)
	stage.add_child(g)
	return g


func _flash(color: Color, alpha: float, dur := 0.45) -> void:
	flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)


func _shake(amount := 10.0) -> void:
	var tw := stage.create_tween()
	for i in 5:
		tw.tween_property(stage, "position",
			Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.04)
	tw.tween_property(stage, "position", Vector2.ZERO, 0.05)


## The moonlit road every outdoor beat shares: real pixel ground, a
## starfield, a treeline, a fence. The horizon sits high so the tableau
## stays visible above the dialogue AND the choice panel.
func _night_set(broken_fence := false) -> void:
	# Real generated terrain, moonlit — not a flat rectangle.
	var g := Sprite2D.new()
	g.texture = Art.ground("grass", "dirt", 28, 9, 11)
	g.centered = false
	g.position = Vector2(-40, 386)
	g.scale = Vector2(3, 3)
	g.modulate = Color(0.40, 0.44, 0.60)
	stage.add_child(g)
	# Sky: stars and a haloed moon.
	for i in 24:
		_glow(Vector2(randf_range(30.0, 1250.0), randf_range(70.0, 300.0)),
			Color(0.9, 0.95, 1.0, randf_range(0.15, 0.5)), randf_range(0.06, 0.15))
	_glow(Vector2(1070, 120), Color(0.85, 0.9, 1.0, 0.55), 3.6)
	_glow(Vector2(1070, 120), Color(0.96, 0.98, 1.0, 0.9), 1.1)
	# Treeline silhouettes along the horizon.
	for i in 6:
		var tr := Sprite2D.new()
		tr.texture = Art.tex("tree_green" if i % 2 == 0 else "tree_autumn")
		tr.position = Vector2(80.0 + i * 218.0 + randf_range(-40.0, 40.0),
			348.0 + randf_range(-10.0, 8.0))
		tr.scale = Art.scale_for(tr.texture, randf_range(4.5, 6.0))
		tr.modulate = Color(0.30, 0.34, 0.48)
		stage.add_child(tr)
	# The miller's fence along the road (smashed through in the aftermath).
	# It stands at the horizon line, BEHIND the action — actors play out
	# on the near side, never tangled in the rails.
	_fence(430.0, 1240.0, 350.0, 620.0 if broken_fence else -1.0,
		880.0 if broken_fence else -1.0)


## Fence posts + rails between from_x..to_x, with an optional wrecked gap.
func _fence(from_x: float, to_x: float, y: float, gap_from := -1.0, gap_to := -1.0) -> void:
	var wood := Color(0.32, 0.23, 0.12)
	var wood_dark := Color(0.26, 0.18, 0.10)
	var x := from_x
	while x < to_x:
		if gap_from < 0.0 or x < gap_from or x > gap_to:
			_prop(wood, Vector2(x, y), Vector2(10, 44))
		x += 82.0
	for rail_y in [y + 9.0, y + 26.0]:
		if gap_from < 0.0:
			_prop(wood_dark, Vector2(from_x, rail_y), Vector2(to_x - from_x, 7))
		else:
			_prop(wood_dark, Vector2(from_x, rail_y), Vector2(gap_from - from_x, 7))
			_prop(wood_dark, Vector2(gap_to, rail_y), Vector2(to_x - gap_to, 7))
	if gap_from >= 0.0:
		# The broken section: splintered posts knocked outward.
		_prop(wood, Vector2(gap_from + 24.0, y + 18.0), Vector2(10, 40), 1.1)
		_prop(wood, Vector2(gap_to - 40.0, y + 22.0), Vector2(10, 36), -1.3)


## Bren's cart — whole on the road, matchwood afterwards.
func _cart(pos: Vector2, smashed := false) -> void:
	var wood := Color(0.38, 0.27, 0.15)
	var dark := Color(0.28, 0.20, 0.11)
	if not smashed:
		_prop(wood, pos, Vector2(96, 32))
		_prop(dark, pos + Vector2(-12, 18), Vector2(20, 20), 0.78)
		_prop(dark, pos + Vector2(84, 18), Vector2(20, 20), 0.78)
		_prop(wood, pos + Vector2(90, -6), Vector2(46, 7), -0.35)
	else:
		for i in 6:
			_prop(wood if i % 2 == 0 else dark,
				pos + Vector2(randf_range(-60.0, 90.0), randf_range(-6.0, 30.0)),
				Vector2(randf_range(22.0, 44.0), 8), randf_range(-1.2, 1.2))
		_prop(dark, pos + Vector2(130, 16), Vector2(20, 20), 0.3)  # a wheel, rolled away


## A wound: red stain on the actor plus dripping blood.
func _bleed(actor: Sprite2D, local_pos: Vector2) -> void:
	var stain := Sprite2D.new()
	stain.texture = Art.tex("glow")
	stain.modulate = Color(0.75, 0.08, 0.08, 0.85)
	stain.position = local_pos
	stain.scale = Vector2(0.14, 0.14)
	actor.add_child(stain)
	var drips := CPUParticles2D.new()
	drips.amount = 5
	drips.lifetime = 0.7
	drips.position = local_pos
	drips.direction = Vector2(0, 1)
	drips.spread = 12.0
	drips.gravity = Vector2(0, 240)
	drips.initial_velocity_min = 4.0
	drips.initial_velocity_max = 14.0
	drips.scale_amount_min = 0.8
	drips.scale_amount_max = 1.4
	drips.color = Color(0.7, 0.06, 0.06)
	actor.add_child(drips)


# -------------------------------------------------------------- scenes ---

## The ruined throne hall: a shaft of light on the Ember Crown — and the
## hollow king rising out of the dark to take it back.
func _scene_crown() -> void:
	_clear()
	# Stone floor + receding pillar rows = an actual hall, not a void.
	var floor_spr := Sprite2D.new()
	floor_spr.texture = Art.ground("stone", "stone", 28, 9, 7)
	floor_spr.centered = false
	floor_spr.position = Vector2(-40, 356)
	floor_spr.scale = Vector2(3, 3)
	floor_spr.modulate = Color(0.42, 0.38, 0.52)
	stage.add_child(floor_spr)
	for i in 4:
		for side in [-1, 1]:
			var p := Sprite2D.new()
			p.texture = Art.tex("pillar")
			p.position = Vector2(640 + side * (170 + i * 128), 322 - i * 26)
			p.scale = Art.scale_for(p.texture, 7.5 - i * 1.1)
			p.modulate = Color(0.34, 0.30, 0.44).darkened(i * 0.14)
			stage.add_child(p)

	# A shaft of light falls on the crown; dust drifts through it.
	var shaft := _glow(Vector2(640, 230), Color(1.0, 0.93, 0.7, 0.16), 1.0)
	shaft.scale = Vector2(2.4, 9.5)
	var dust := CPUParticles2D.new()
	dust.amount = 14
	dust.lifetime = 2.2
	dust.position = Vector2(640, 250)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 60.0
	dust.direction = Vector2(0, 1)
	dust.spread = 20.0
	dust.gravity = Vector2(0, 8)
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 10.0
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.6
	dust.color = Color(1.0, 0.95, 0.75, 0.5)
	stage.add_child(dust)

	_prop(Color(0.24, 0.21, 0.30), Vector2(597, 402), Vector2(86, 120))
	_prop(Color(0.18, 0.15, 0.23), Vector2(583, 396), Vector2(114, 12))
	_prop(Color(0.16, 0.13, 0.21), Vector2(569, 518), Vector2(142, 18))
	var halo := _glow(Vector2(640, 366), Color(1.0, 0.8, 0.3, 0.55), 2.4)
	var pulse := halo.create_tween()
	pulse.set_loops()
	pulse.tween_property(halo, "scale", Vector2(3.1, 3.1), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(halo, "scale", Vector2(2.4, 2.4), 0.8).set_trans(Tween.TRANS_SINE)
	var crown := _actor("crown", Vector2(640, 366), 4.5)

	# The king rises out of the floor, wreathed in ash-smoke.
	var back := _glow(Vector2(640, 320), Color(0.35, 0.25, 0.55, 0.0), 9.0)
	var bt := back.create_tween()
	bt.tween_interval(0.7)
	bt.tween_property(back, "modulate:a", 0.4, 1.5)
	var king := _actor("king", Vector2(640, 680), 9.0, false, Color(0.24, 0.17, 0.30))
	var smoke := CPUParticles2D.new()
	smoke.amount = 22
	smoke.lifetime = 0.9
	smoke.position = Vector2(0, 40)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 40.0
	smoke.gravity = Vector2(0, -30)
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 30.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.5
	smoke.color = Color(0.18, 0.12, 0.24, 0.7)
	king.add_child(smoke)
	var tw := king.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(king, "position:y", 348.0, 1.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		game.sfx("roar_vargoth", 1.0, 2.5)
		_flash(Color(0.9, 0.2, 0.15), 0.4)
		_shake(12.0)
		# The hollow eyes catch fire...
		for off in [Vector2(-16, -52), Vector2(14, -52)]:
			var eye := _glow(Vector2(640, 348) + off, Color(1.0, 0.15, 0.1, 0.0), 0.35)
			var et := eye.create_tween()
			et.tween_property(eye, "modulate:a", 0.95, 0.4)
		# ...and the crown flies to his brow and goes DARK — stolen,
		# not vanished.
		if is_instance_valid(crown):
			var ct := crown.create_tween()
			ct.tween_property(crown, "position", Vector2(640, 292), 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			ct.parallel().tween_property(crown, "modulate", Color(0.55, 0.32, 0.25), 0.55)
		if is_instance_valid(halo):
			var gt := halo.create_tween()
			gt.tween_property(halo, "modulate:a", 0.0, 0.5)
		if is_instance_valid(shaft):
			var st := shaft.create_tween()
			st.tween_property(shaft, "modulate:a", 0.02, 0.8))


## The road: a wolf lunging at the miller, and you arriving at a run.
func _scene_road() -> void:
	_clear()
	_night_set()
	_cart(Vector2(700, 402))
	var bren := _actor("villager", Vector2(870, 391), 6.0)  # Bren, facing the wolf
	var panic := bren.create_tween()
	panic.set_loops()
	panic.tween_property(bren, "rotation", 0.07, 0.12)
	panic.tween_property(bren, "rotation", -0.05, 0.12)
	var wolf := _actor("wolf", Vector2(1130, 385), 6.5, true)
	for off in [Vector2(-9, -4), Vector2(-4, -4)]:  # blight-mad eyes
		var eye := Sprite2D.new()
		eye.texture = Art.tex("glow")
		eye.modulate = Color(1.0, 0.2, 0.1, 0.9)
		eye.position = off
		eye.scale = Vector2(0.04, 0.04)
		wolf.add_child(eye)
	var wt := wolf.create_tween()
	wt.set_loops()
	wt.tween_interval(0.35)
	wt.tween_property(wolf, "position", Vector2(975, 355), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wt.tween_property(wolf, "position", Vector2(1030, 385), 0.3)
	game.sfx("roar_fangmaw", 1.3, 1.2)
	var hero := _actor(_hero_tex(), Vector2(110, 378), 7.0)
	var ht := hero.create_tween()
	ht.tween_property(hero, "position:x", 620.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The blackout you don't remember — then what it left behind.
func _scene_aftermath() -> void:
	_clear()
	_flash(Color(1, 1, 1), 1.0, 0.6)
	_shake(16.0)
	game.sfx("sword")
	for i in 3:
		var rip := Sprite2D.new()
		rip.texture = Art.tex("glow")
		rip.modulate = Color(1.0, 0.9, 0.85, 0.9)
		rip.position = Vector2(640 + randf_range(-140, 140), 380 + randf_range(-90, 90))
		rip.rotation = randf_range(0.0, TAU)
		rip.scale = Vector2(14.0, 0.35)
		rip.z_index = 5
		stage.add_child(rip)
		var rt := rip.create_tween()
		rt.tween_interval(0.07 * i)
		rt.tween_property(rip, "scale:y", 0.05, 0.2)
		rt.parallel().tween_property(rip, "modulate:a", 0.0, 0.24)
		rt.tween_callback(rip.queue_free)

	_night_set(true)  # the fence now has a hole the shape of a fight
	_cart(Vector2(700, 402), true)
	# Gouges torn into the road.
	for i in 3:
		_prop(Color(0.10, 0.09, 0.07), Vector2(520.0 + i * 70.0, 400.0 + i * 14.0),
			Vector2(64, 6), randf_range(-0.25, 0.25))
	# The wolf, on its back, in a spreading pool.
	var pool := _glow(Vector2(640, 402), Color(0.45, 0.06, 0.06, 0.55), 1.2)
	var pt := pool.create_tween()
	pt.tween_property(pool, "scale", Vector2(2.8, 1.6), 2.5)
	var wolf := _actor("wolf", Vector2(640, 388), 6.5, false, Color(0.5, 0.33, 0.33))
	wolf.rotation = -PI / 2.0
	# You, breathing hard over it — knuckles split and dripping.
	var hero := _actor(_hero_tex(), Vector2(540, 372), 7.0)
	var breathe := hero.create_tween()
	breathe.set_loops()
	breathe.tween_property(hero, "scale:y", hero.scale.y * 1.05, 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(hero, "scale:y", hero.scale.y, 0.45).set_trans(Tween.TRANS_SINE)
	_bleed(hero, Vector2(7, 2))
	# Bren, backed against what's left of his fence, arm bleeding,
	# cradling it and shaking.
	var bren := _actor("villager", Vector2(985, 394), 6.0, true, Color(1.0, 0.88, 0.88))
	bren.rotation = 0.09  # hunched over the arm
	_bleed(bren, Vector2(-5, 0))
	var bren_pool := _glow(Vector2(985, 428), Color(0.45, 0.06, 0.06, 0.4), 0.5)
	var bpt := bren_pool.create_tween()
	bpt.tween_property(bren_pool, "scale", Vector2(1.1, 0.6), 3.0)
	var tremble := bren.create_tween()
	tremble.set_loops()
	tremble.tween_property(bren, "position:x", 988.0, 0.09)
	tremble.tween_property(bren, "position:x", 982.0, 0.09)


## A candlelit room: stone floor, dark wall, flickering warm light.
func _interior_set() -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = Art.ground("stone", "stone", 28, 9, 21)
	floor_spr.centered = false
	floor_spr.position = Vector2(-40, 356)
	floor_spr.scale = Vector2(3, 3)
	floor_spr.modulate = Color(0.55, 0.47, 0.40)
	stage.add_child(floor_spr)
	_prop(Color(0.14, 0.11, 0.10), Vector2(0, 52), Vector2(1280, 306))  # back wall
	for x in [230.0, 1050.0]:
		_prop(Color(0.30, 0.24, 0.16), Vector2(x - 4, 268), Vector2(8, 60))  # sconce post
		var c := _glow(Vector2(x, 258), Color(1.0, 0.72, 0.35, 0.55), 1.5)
		var t := c.create_tween()
		t.set_loops()
		t.tween_property(c, "modulate:a", 0.38, randf_range(0.35, 0.55))
		t.tween_property(c, "modulate:a", 0.55, randf_range(0.35, 0.55))


## Assassin: the carter's camp — warm before the theft, dead after it.
func _scene_camp(cold: bool) -> void:
	_clear()
	_night_set()
	# The campfire: stacked logs + (living or murdered) light.
	_prop(Color(0.30, 0.22, 0.12), Vector2(742, 416), Vector2(44, 9), 0.5)
	_prop(Color(0.26, 0.19, 0.11), Vector2(746, 418), Vector2(44, 9), -0.55)
	if not cold:
		var fire := _glow(Vector2(765, 405), Color(1.0, 0.62, 0.2, 0.8), 1.8)
		var ft := fire.create_tween()
		ft.set_loops()
		ft.tween_property(fire, "scale", Vector2(2.1, 2.1), 0.3)
		ft.tween_property(fire, "scale", Vector2(1.7, 1.7), 0.3)
		var embers := CPUParticles2D.new()
		embers.amount = 12
		embers.lifetime = 0.9
		embers.position = Vector2(765, 400)
		embers.direction = Vector2(0, -1)
		embers.spread = 25.0
		embers.gravity = Vector2(0, -40)
		embers.initial_velocity_min = 15.0
		embers.initial_velocity_max = 45.0
		embers.scale_amount_min = 1.0
		embers.scale_amount_max = 2.2
		embers.color = Color(1.0, 0.6, 0.2)
		stage.add_child(embers)
		# The carter asleep beside it; the hero creeping in from the dark.
		var carter := _actor("villager", Vector2(880, 408), 6.0, true)
		carter.rotation = -PI / 2.0
		var hero := _actor(_hero_tex(), Vector2(180, 392), 6.5, false, Color(0.55, 0.55, 0.7))
		var ht := hero.create_tween()
		ht.tween_property(hero, "position:x", 620.0, 2.2).set_trans(Tween.TRANS_SINE)
	else:
		_flash(Color(0.7, 1.0, 0.7), 0.5)
		# Frost where the fire was; grey smoke instead of embers.
		_glow(Vector2(765, 405), Color(0.6, 0.8, 1.0, 0.35), 1.6)
		var smoke := CPUParticles2D.new()
		smoke.amount = 8
		smoke.lifetime = 1.4
		smoke.position = Vector2(765, 400)
		smoke.direction = Vector2(0, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(0, -14)
		smoke.initial_velocity_min = 6.0
		smoke.initial_velocity_max = 14.0
		smoke.scale_amount_min = 1.6
		smoke.scale_amount_max = 3.0
		smoke.color = Color(0.55, 0.58, 0.62, 0.5)
		stage.add_child(smoke)
		# The carter — awake, grey, shivering. You, flask in hand.
		var carter := _actor("villager", Vector2(880, 396), 6.0, true, Color(0.75, 0.85, 1.0))
		var shiver := carter.create_tween()
		shiver.set_loops()
		shiver.tween_property(carter, "position:x", 883.0, 0.07)
		shiver.tween_property(carter, "position:x", 877.0, 0.07)
		var hero := _actor(_hero_tex(), Vector2(700, 388), 6.5)
		var flask := _glow(Vector2(730, 380), Color(0.5, 1.0, 0.5, 0.8), 0.3)
		var fk := flask.create_tween()
		fk.set_loops()
		fk.tween_property(flask, "modulate:a", 0.5, 0.4)
		fk.tween_property(flask, "modulate:a", 0.8, 0.4)


## Mage: the ferrier's boy — a warm heal that turns wrong.
func _scene_sickbed(wrong: bool) -> void:
	_clear()
	_interior_set()
	# The sickbed.
	_prop(Color(0.32, 0.24, 0.14), Vector2(690, 372), Vector2(150, 40))
	_prop(Color(0.55, 0.20, 0.18), Vector2(696, 366), Vector2(138, 18))   # blanket
	_prop(Color(0.85, 0.82, 0.75), Vector2(800, 360), Vector2(32, 14))    # pillow
	var boy := _actor("villager", Vector2(760, 352), 5.0, false,
		Color(0.75, 0.95, 0.8) if wrong else Color(1.05, 0.85, 0.8))
	boy.rotation = PI / 2.0  # head to the RIGHT, resting on the pillow
	# The mother, wringing her hands; you, hands over the bed.
	var mother := _actor("villager", Vector2(940, 382), 6.0, true)
	var worry := mother.create_tween()
	worry.set_loops()
	worry.tween_property(mother, "rotation", 0.05 if wrong else 0.02, 0.3)
	worry.tween_property(mother, "rotation", -0.05 if wrong else -0.02, 0.3)
	var hero := _actor(_hero_tex(), Vector2(600, 380), 6.5)
	if wrong:
		hero.rotation = -0.08  # recoiling from your own hands
		_flash(Color(0.5, 1.0, 0.5), 0.45)
		var mark := _glow(Vector2(760, 350), Color(0.5, 0.65, 0.5, 0.7), 0.5)
		var mt := mark.create_tween()
		mt.tween_property(mark, "scale", Vector2(0.9, 0.9), 2.0)
	var light := _glow(Vector2(745, 350),
		Color(0.45, 1.0, 0.45, 0.75) if wrong else Color(1.0, 0.85, 0.45, 0.7), 1.4)
	var lt := light.create_tween()
	lt.set_loops()
	lt.tween_property(light, "scale", Vector2(1.8, 1.8), 0.5).set_trans(Tween.TRANS_SINE)
	lt.tween_property(light, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_SINE)


## Archer: the boundary fence — and the visible thread between you,
## before and after the Ember cuts it.
func _scene_homestead(severed: bool) -> void:
	_clear()
	_night_set()
	var hero := _actor(_hero_tex(), Vector2(430, 388), 6.5)  # facing Ren (right)
	var ren := _actor("villager", Vector2(830, 391), 6.0, not severed)  # turns AWAY after
	if not severed:
		# The thread: a humming line of light between two brothers.
		var thread := _glow(Vector2(630, 368), Color(0.95, 0.9, 0.6, 0.7), 1.0)
		thread.scale = Vector2(5.6, 0.14)
		var tt := thread.create_tween()
		tt.set_loops()
		tt.tween_property(thread, "modulate:a", 0.45, 0.4).set_trans(Tween.TRANS_SINE)
		tt.tween_property(thread, "modulate:a", 0.7, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		_flash(Color(1.0, 0.95, 0.8), 0.5)
		game.sfx("bow", 0.7)  # a bowstring snap, pitched down
		# Two retracting stubs where the thread was.
		for setup in [[Vector2(500, 372), 460.0], [Vector2(770, 365), 810.0]]:
			var stub := _glow(setup[0], Color(0.95, 0.9, 0.6, 0.8), 1.0)
			stub.scale = Vector2(1.6, 0.12)
			var st := stub.create_tween()
			st.tween_property(stub, "position:x", setup[1], 0.35)
			st.parallel().tween_property(stub, "scale:x", 0.1, 0.35)
			st.parallel().tween_property(stub, "modulate:a", 0.0, 0.4)
			st.tween_callback(stub.queue_free)
		var step := hero.create_tween()
		step.tween_property(hero, "position:x", 400.0, 1.2).set_trans(Tween.TRANS_SINE)


## Paladin: the hearing — and, after the raid, the verdict with the
## burning hammer in your hand.
func _scene_hearing(after_raid: bool) -> void:
	_clear()
	_interior_set()
	# The arbiter presides from BEHIND the bench: the hero is drawn
	# first so the bench and ledgers occlude his lower half, with Osric
	# standing before the bench on the accused's side.
	var hero := _actor(_hero_tex(), Vector2(520, 344), 6.5)
	_prop(Color(0.30, 0.23, 0.13), Vector2(430, 384), Vector2(220, 16))
	_prop(Color(0.26, 0.19, 0.11), Vector2(446, 400), Vector2(14, 34))
	_prop(Color(0.26, 0.19, 0.11), Vector2(620, 400), Vector2(14, 34))
	_prop(Color(0.88, 0.85, 0.75), Vector2(470, 374), Vector2(38, 10))   # the ledgers
	_prop(Color(0.88, 0.85, 0.75), Vector2(516, 372), Vector2(38, 10), 0.06)
	var osric := _actor("villager", Vector2(800, 388), 6.0, true)
	if not after_raid:
		# Red firelight flickers through the doorway — the raid begins.
		var raidlight := _glow(Vector2(1210, 300), Color(1.0, 0.3, 0.15, 0.0), 4.0)
		var rt := raidlight.create_tween()
		rt.tween_interval(0.8)
		rt.set_loops()
		rt.tween_property(raidlight, "modulate:a", 0.5, 0.25)
		rt.tween_property(raidlight, "modulate:a", 0.15, 0.35)
		var rumble := create_tween()
		rumble.tween_interval(1.2)
		rumble.tween_callback(func() -> void:
			game.sfx("slam", 0.7)
			_shake(7.0))
	else:
		# The hammer, still burning, laid on the bench between you.
		_prop(Color(0.35, 0.26, 0.15), Vector2(560, 344), Vector2(9, 40), 0.5)
		_prop(Color(0.55, 0.52, 0.55), Vector2(576, 336), Vector2(26, 16), 0.5)
		var ember := _glow(Vector2(583, 344), Color(1.0, 0.75, 0.3, 0.7), 0.9)
		var et := ember.create_tween()
		et.set_loops()
		et.tween_property(ember, "scale", Vector2(1.15, 1.15), 0.4)
		et.tween_property(ember, "scale", Vector2(0.85, 0.85), 0.4)
		# The chain's pull: a golden ring tightening around you.
		var chain := Sprite2D.new()
		chain.texture = Art.tex("ring")
		chain.modulate = Color(1.0, 0.85, 0.4, 0.5)
		chain.position = Vector2(520, 352)
		chain.scale = Vector2(3.4, 3.4)
		stage.add_child(chain)
		var ct := chain.create_tween()
		ct.set_loops()
		ct.tween_property(chain, "scale", Vector2(2.6, 2.6), 0.9).set_trans(Tween.TRANS_SINE)
		ct.tween_property(chain, "scale", Vector2(3.4, 3.4), 0.9).set_trans(Tween.TRANS_SINE)
		osric.rotation = 0.35  # on his knees, pleading
		osric.position.y += 14.0


## Warlock: the rented room, the tome that wasn't there when you slept.
func _scene_tome(open_wide: bool) -> void:
	_clear()
	_interior_set()
	# The desk, the tome, the journal you don't remember keeping.
	_prop(Color(0.28, 0.21, 0.12), Vector2(560, 384), Vector2(190, 14))
	_prop(Color(0.24, 0.17, 0.10), Vector2(576, 398), Vector2(12, 34))
	_prop(Color(0.24, 0.17, 0.10), Vector2(716, 398), Vector2(12, 34))
	_prop(Color(0.30, 0.12, 0.30), Vector2(610, 366), Vector2(52, 18))    # the tome
	_prop(Color(0.85, 0.82, 0.72), Vector2(560, 370), Vector2(30, 8), -0.1)  # journal
	var hero := _actor(_hero_tex(), Vector2(480, 380), 6.5)
	var pulse := _glow(Vector2(636, 362),
		Color(0.7, 0.4, 1.0, 0.75 if open_wide else 0.45), 1.5 if open_wide else 0.8)
	var pt := pulse.create_tween()
	pt.set_loops()
	pt.tween_property(pulse, "scale", pulse.scale * 1.3, 0.5).set_trans(Tween.TRANS_SINE)
	pt.tween_property(pulse, "scale", pulse.scale, 0.5).set_trans(Tween.TRANS_SINE)
	var motes := CPUParticles2D.new()
	motes.amount = 16 if open_wide else 8
	motes.lifetime = 1.3
	motes.position = Vector2(636, 360)
	motes.direction = Vector2(0, -1)
	motes.spread = 30.0
	motes.gravity = Vector2(0, -20)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 24.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.2
	motes.color = Color(0.7, 0.45, 1.0, 0.8)
	stage.add_child(motes)
	if open_wide:
		_flash(Color(0.6, 0.35, 0.9), 0.35)
		hero.rotation = 0.06  # leaning in despite yourself
		# A shaft of void-light, and pages rising out of the tome.
		var shaft := _glow(Vector2(636, 250), Color(0.65, 0.4, 1.0, 0.18), 1.0)
		shaft.scale = Vector2(1.8, 8.0)
		for i in 3:
			var page := _prop(Color(0.9, 0.87, 0.78), Vector2(600.0 + i * 26.0, 350.0),
				Vector2(18, 24), randf_range(-0.4, 0.4))
			var pg := page.create_tween()
			pg.set_loops()
			pg.tween_property(page, "position:y", 260.0 - i * 18.0, randf_range(1.6, 2.4))
			pg.parallel().tween_property(page, "rotation", randf_range(-1.2, 1.2), 2.0)
			pg.tween_callback(func() -> void: page.position.y = 350.0)


func _fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.7)
