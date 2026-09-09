class_name Ambience
## AMBIENT LIFE (Graphics & Ambience track, DESIGN.md): movement that makes a
## place feel inhabited instead of composited. ZERO gameplay weight — no XP, no
## drops, no aggro, no collision.
##
## Two layers, both parked in zone_scenery so room rebuilds / terrain repaints
## free them with the decor:
##   CRITTERS — animated fauna (Codex frame strips, `critter_<kind>.png`): birds
##     and bats FLIT through the air (wings flapping), hawks/crows SOAR across the
##     sky, butterflies drift, dragonflies dart over water, wisps GLOW and bob,
##     void rubble FLOATs. Startle-prone kinds dart away when the player closes in.
##   ELEMENTAL FX — drifting ash + heat-haze (magma), fog banks (graveyard/void),
##     water plops + ripples (marsh/bog).
##
## populate(game, zi) is called from game_world._spawn_scenery. Every terrain
## gets SOME motion; boss arenas stay sterile (drama over life).


const STRIP_PATH := "res://assets/sprites/critter_%s.png"


## An animated critter strip -> [Texture2D, frame_count], or [] for the
## procedural fallback. Frames are square, laid out horizontally, so
## frame_count = width / height.
static func strip(kind: String) -> Array:
	var p := STRIP_PATH % kind
	if ResourceLoader.exists(p):
		var t: Texture2D = load(p)
		if t != null and t.get_height() > 0:
			return [t, maxi(1, t.get_width() / t.get_height())]
	return []


## A soft round glow texture (radial alpha falloff), white — tinted per use for
## wisps, fog banks and heat haze. Built once, shared.
static var _soft: ImageTexture = null
static func soft_tex() -> ImageTexture:
	if _soft != null:
		return _soft
	var s := 32
	var im := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a * a))
	_soft = ImageTexture.create_from_image(im)
	return _soft


## One critter. mode drives the motion; the frame strip (if any) animates the
## wings continuously. home/span are seeded from the room's play rect.
class Critter extends Node2D:
	var game: Node2D
	var kind := "bird"
	var mode := "flit"            # flit / soar / glow / float / fog
	var home := Vector2.ZERO
	var span := Rect2()
	var tint := Color.WHITE
	var reactive := false         # dart away when the player closes in
	var fled := false
	var spr: Sprite2D
	var frames := 1
	var _ft := 0.0
	var _phase := 0.0
	var _soar_y := 0.0
	# Flock members share a soar direction + height band and a per-bird x-offset
	# so a murder/flock crosses the sky TOGETHER instead of as lone strays.
	var soar_dir := 0            # 0 = random each cross; ±1 = a fixed flock heading
	var soar_y0 := -1.0          # >=0 = a shared flock height band
	var soar_x_off := 0.0        # stagger down the flock line
	# Birds forage: they fly down, hop/peck/stand a while, then flush and take
	# off again (real birds are not permanently airborne). `grounded` swaps the
	# flap strip for a folded-wing PERCHED strip and slows the frame cycle.
	var grounded := false
	var no_land := Rect2()        # a river/water rect (world) birds must not forage on
	var no_land_circles: Array = []   # hazard pools (world): [{pos:Vector2, radius:float}]
	var _fly_tex: Texture2D = null
	var _fly_n := 1
	var _perch_tex: Texture2D = null
	var _perch_n := 1
	var wander_tw: Tween

	func _ready() -> void:
		z_index = {"soar": 16, "fog": -3, "glow": -5, "float": -5}.get(mode, -5)
		spr = Sprite2D.new()
		match mode:
			"glow", "fog":
				spr.texture = Ambience.soft_tex()
			"float":
				spr.texture = Art.tex("pebble")
			_:
				var s := Ambience.strip(kind)
				if not s.is_empty():
					_fly_tex = s[0]
					_fly_n = int(s[1])
					spr.texture = _fly_tex
					frames = _fly_n
					spr.hframes = frames
				else:
					spr.texture = Art.tex(kind)   # pre-Codex procedural look
				if kind == "bird":              # optional folded-wing ground pose
					var ps := Ambience.strip("bird_perched")
					if not ps.is_empty():
						_perch_tex = ps[0]
						_perch_n = int(ps[1])
		var sc := _scale()
		spr.scale = Vector2(sc, sc)
		spr.modulate = tint
		add_child(spr)
		# Ground critters (flitting birds, butterflies, rats) cast a small figure
		# too (owner flag 2026-08-19); soaring birds / glows / fog do not.
		if mode == "flit" and game != null and game.has_method("cast_shadow_for") \
				and DisplayServer.get_name() != "headless":
			game.cast_shadow_for(self, spr, 0.8)
		_ft = randf() * 8.0
		_phase = randf() * TAU
		match mode:
			"soar": _soar()
			"glow": _glow()
			"float": _float()
			"fog": _fog()
			_: _flit()

	func _scale() -> float:
		# 2026-08-25 fidelity pass: every critter strip re-authored at 2-4x its
		# old cell (hawk 64->256, crow/bird/bat 48->128, butterfly 48->96,
		# dragonfly 64->128); each scale divided by the same factor so the
		# ON-SCREEN size is unchanged (world px = cell * scale). Mirror any
		# change into tools/art/fidelity_audit.py CRITTER_SCALE.
		match kind:
			"butterfly": return 0.3
			"dragonfly": return 0.25
			"bat": return 0.2625
			"hawk": return 0.375
			"crow": return 0.375
			"wisp": return 1.1
			"fog": return 11.0
			"debris": return 1.3
			_: return 0.31875         # bird / dove

	func _fps() -> float:
		match kind:
			"butterfly": return 7.0
			"dragonfly": return 22.0
			"bat": return 16.0
			"hawk": return 5.0
			"crow": return 9.0
			_: return 11.0            # bird

	func _process(delta: float) -> void:
		if frames > 1:
			_ft += delta * (2.6 if grounded else _fps())   # slow peck/stand on the ground
			spr.frame = int(_ft) % frames
		if mode == "soar":
			position.y = _soar_y + sin(_phase + Time.get_ticks_msec() * 0.0016) \
				* (10.0 if kind == "hawk" else 6.0)
		elif mode == "glow":
			spr.modulate.a = 0.45 + 0.35 * (0.5 + 0.5 * sin(
				_phase + Time.get_ticks_msec() * 0.0022))
		elif mode == "float":
			spr.rotation += delta * 0.4
		if reactive and not fled and mode == "flit" and is_instance_valid(game.player):
			if global_position.distance_to(game.player.global_position) < 90.0:
				_flee()

	func _rand_home_target(rx: float, ry: float) -> Vector2:
		var t := home + Vector2(randf_range(-rx, rx), randf_range(-ry, ry))
		if span.size.x > 1.0:
			t.x = clampf(t.x, span.position.x + 40.0, span.end.x - 40.0)
			t.y = clampf(t.y, span.position.y + 40.0, span.end.y - 40.0)
		return t

	# --- flit: drift around home in the air, wings flapping ---
	func _flit() -> void:
		if not is_inside_tree() or grounded:
			return
		# Birds break off to forage on the ground now and then (real life).
		if kind == "bird" and _perch_tex != null and randf() < 0.30:
			_land()
			return
		var rx := 90.0
		var ry := 60.0
		var dur := randf_range(1.4, 2.6)
		match kind:
			"butterfly": rx = 70.0; ry = 46.0; dur = randf_range(1.6, 2.8)
			"dragonfly": rx = 130.0; ry = 42.0; dur = randf_range(0.45, 1.0)
			"bat": rx = 150.0; ry = 95.0; dur = randf_range(0.6, 1.2)
		var target := _rand_home_target(rx, ry)
		spr.flip_h = target.x < position.x
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", target, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if kind == "dragonfly":
			wander_tw.tween_interval(randf_range(0.2, 0.7))   # hover pause
		wander_tw.tween_callback(_flit)

	func _use_fly() -> void:
		if _fly_tex != null:
			spr.texture = _fly_tex
			frames = _fly_n
			spr.hframes = frames

	func _use_perch() -> void:
		if _perch_tex != null:
			spr.texture = _perch_tex
			frames = _perch_n
			spr.hframes = frames
			_ft = 0.0

	# A spot a foraging bird must NOT land on: the river, or any hazard pool. A
	# bird pecking in lava/poison makes no sense (owner 2026-08-17).
	func _on_water(p: Vector2) -> bool:
		if no_land.size.x > 0.0 and no_land.has_point(p):
			return true
		for hz in no_land_circles:
			if p.distance_to(hz["pos"]) < float(hz["radius"]):
				return true
		return false

	# --- land: glide down to a DRY ground spot near home, then forage. Birds do
	# not walk on water (owner 2026-08-17) — a spot over the river is rejected,
	# and if nowhere dry is near, the bird just keeps flying. ---
	func _land() -> void:
		var gp := _rand_home_target(80.0, 55.0)
		var tries := 0
		while _on_water(gp) and tries < 6:
			gp = _rand_home_target(100.0, 66.0)
			tries += 1
		if _on_water(gp):
			_flit()                     # nowhere dry nearby — stay airborne
			return
		spr.flip_h = gp.x < position.x
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", gp, randf_range(0.7, 1.1)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		wander_tw.tween_callback(_touchdown)

	func _touchdown() -> void:
		grounded = true
		home = position
		_use_perch()
		_forage(2 + (randi() % 4))

	# --- forage: little hops + peck/stand pauses, a few times, then take off ---
	func _forage(steps: int) -> void:
		if not is_inside_tree() or not grounded:
			return
		if steps <= 0:
			_takeoff()
			return
		var hop := position + Vector2(randf_range(-46.0, 46.0), randf_range(-14.0, 14.0))
		if span.size.x > 1.0:
			hop.x = clampf(hop.x, span.position.x + 40.0, span.end.x - 40.0)
			hop.y = clampf(hop.y, span.position.y + 40.0, span.end.y - 40.0)
		if _on_water(hop):
			hop = position          # a hop toward the water = stay put and peck
		spr.flip_h = hop.x < position.x
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", hop, randf_range(0.16, 0.28)) \
			.set_trans(Tween.TRANS_SINE)
		wander_tw.tween_interval(randf_range(0.5, 1.7))   # peck / stand still
		wander_tw.tween_callback(_forage.bind(steps - 1))

	func _takeoff() -> void:
		grounded = false
		_use_fly()
		var up := _rand_home_target(80.0, 45.0)
		up.y -= 60.0
		spr.flip_h = up.x < position.x
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", up, randf_range(0.6, 1.0)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wander_tw.tween_callback(_flit)

	# --- flee: startle-dart away from the player, then resume fliting nearby.
	# A foraging bird flushes: it swaps back to the flying strip and takes off. ---
	func _flee() -> void:
		fled = true
		if grounded:
			grounded = false
			_use_fly()
		if wander_tw:
			wander_tw.kill()
		var away := Vector2.UP
		if is_instance_valid(game.player):
			var d: Vector2 = global_position - game.player.global_position
			if d.length() > 1.0:
				away = d.normalized()
		var dest := position + away * 150.0 + Vector2(randf_range(-30.0, 30.0), -70.0)
		if span.size.x > 1.0:
			dest.x = clampf(dest.x, span.position.x + 40.0, span.end.x - 40.0)
			dest.y = clampf(dest.y, span.position.y + 40.0, span.end.y - 40.0)
		spr.flip_h = dest.x < position.x
		var tw := create_tween()
		tw.tween_property(self, "position", dest, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.7)
		tw.tween_callback(_unflee)

	func _unflee() -> void:
		fled = false
		home = position
		_flit()

	# --- soar: cross the sky edge to edge, high up, then a gap, then again ---
	func _soar() -> void:
		if not is_inside_tree():
			return
		var right := randf() < 0.5
		_soar_y = span.position.y + randf_range(24.0, span.size.y * 0.34)
		var startx := span.position.x - 90.0 if right else span.end.x + 90.0
		var endx := span.end.x + 90.0 if right else span.position.x - 90.0
		position = Vector2(startx, _soar_y)
		spr.flip_h = not right
		var speed := 150.0 if kind == "hawk" else 210.0
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position:x", endx,
			absf(endx - startx) / speed).set_trans(Tween.TRANS_LINEAR)
		wander_tw.tween_interval(randf_range(2.5, 6.5))   # empty-sky gap
		wander_tw.tween_callback(_soar)

	# --- glow: a wisp drifting slowly, breathing its light (pulse in _process) ---
	func _glow() -> void:
		if not is_inside_tree():
			return
		var target := _rand_home_target(70.0, 55.0)
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", target, randf_range(2.2, 3.6)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wander_tw.tween_callback(_glow)

	# --- float: void rubble drifting and slowly turning (rotation in _process) ---
	func _float() -> void:
		if not is_inside_tree():
			return
		var target := _rand_home_target(60.0, 50.0)
		wander_tw = create_tween()
		wander_tw.tween_property(self, "position", target, randf_range(3.0, 5.0)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wander_tw.tween_callback(_float)

	# --- fog: a soft bank sliding across the room, wrapping edge to edge ---
	func _fog() -> void:
		if not is_inside_tree():
			return
		spr.modulate.a = 0.0
		var right := randf() < 0.5
		var y := span.position.y + randf_range(60.0, span.size.y - 60.0)
		position = Vector2(span.position.x - 220.0 if right else span.end.x + 220.0, y)
		var endx := span.end.x + 220.0 if right else span.position.x - 220.0
		var dur := randf_range(14.0, 22.0)
		wander_tw = create_tween()
		wander_tw.tween_property(spr, "modulate:a", tint.a, dur * 0.3)
		wander_tw.parallel().tween_property(self, "position:x", endx, dur) \
			.set_trans(Tween.TRANS_LINEAR)
		wander_tw.tween_property(spr, "modulate:a", 0.0, dur * 0.25)
		wander_tw.tween_callback(_fog)


## An occasional water PLOP: a quick expanding ring on the room's river, as if a
## frog or fish broke the surface. No river ⇒ frees itself. Uses the soft glow
## ring so it needs no asset.
class Plop extends Node2D:
	var game: Node2D
	var zi := 0

	func _ready() -> void:
		z_index = -8
		_loop()

	func _loop() -> void:
		if not is_inside_tree():
			return
		var rivers: Dictionary = game.rivers
		if not rivers.has(zi):
			queue_free()   # no river rolled here
			return
		var rect: Rect2 = rivers[zi]["rect"]
		global_position = Vector2(
			rect.position.x + randf_range(0.15, 0.85) * rect.size.x,
			rect.position.y + randf_range(0.15, 0.85) * rect.size.y)
		var ring := Sprite2D.new()
		ring.texture = Ambience.soft_tex()
		ring.modulate = Color(0.85, 0.95, 1.0, 0.0)
		ring.scale = Vector2(0.6, 0.4)
		add_child(ring)
		var tw := create_tween()
		tw.tween_property(ring, "modulate:a", 0.5, 0.12)
		tw.parallel().tween_property(ring, "scale", Vector2(2.6, 1.7), 0.6)
		tw.tween_property(ring, "modulate:a", 0.0, 0.3)
		tw.tween_callback(ring.queue_free)
		tw.tween_interval(randf_range(1.6, 4.5))
		tw.tween_callback(_loop)


## A patch of water shimmer that lives ON the room's river (CC0 Ninja
## Adventure "Water Ripples", 4 frames). The river is created just AFTER
## us in game_world._spawn_scenery, so a ripple waits one frame for it to
## appear, seats itself on the water, then loops a slow fade-in / frame-
## step / fade-out and drifts to a fresh spot. A room with NO river ⇒ the
## ripple quietly frees itself. ZERO gameplay weight — pure surface life.
class Ripple extends Node2D:
	var game: Node2D
	var zi := 0
	var spr: Sprite2D
	var seated := false

	func _ready() -> void:
		# No asset (unimported/missing) ⇒ drop out rather than crash Art.tex
		# on the unknown "fx/..." key (see player_combat._fx_flash).
		if not ResourceLoader.exists("res://assets/sprites/fx/fx_ripple.png"):
			queue_free()
			return
		z_index = -8  # above the river water (-9), under decor and the bridge
		spr = Sprite2D.new()
		spr.texture = Art.tex("fx/fx_ripple")
		spr.hframes = 4
		spr.frame = 0
		spr.modulate = Color(0.82, 0.92, 1.0, 0.0)  # cool, invisible until seated
		add_child(spr)

	func _process(_delta: float) -> void:
		if seated or spr == null:  # spr null ⇒ _ready bailed (asset missing)
			return
		var rivers: Dictionary = game.rivers
		if not rivers.has(zi):
			queue_free()  # no river rolled in this room — nothing to shimmer on
			return
		seated = true
		_reseat()
		_loop()

	## Jump to a fresh random point within the river band.
	func _reseat() -> void:
		var rivers: Dictionary = game.rivers
		if not rivers.has(zi):
			return
		var rect: Rect2 = rivers[zi]["rect"]
		global_position = Vector2(
			rect.position.x + randf_range(0.12, 0.88) * rect.size.x,
			rect.position.y + randf_range(0.06, 0.94) * rect.size.y)
		spr.scale = Vector2(randf_range(2.0, 3.4), randf_range(2.0, 3.4))

	func _loop() -> void:
		if not is_inside_tree():
			return
		spr.frame = 0
		var per := randf_range(0.16, 0.26)
		var tw := spr.create_tween()
		tw.tween_property(spr, "modulate:a", randf_range(0.12, 0.22), per)
		for f in range(1, 4):
			tw.tween_callback(spr.set_frame.bind(f))
			tw.tween_interval(per)
		tw.tween_property(spr, "modulate:a", 0.0, per)
		tw.tween_interval(randf_range(0.7, 2.2))  # a lull between ripples
		tw.tween_callback(_reseat)
		tw.tween_callback(_loop)


## A drifting elemental particle field (ash, heat-haze). Built from a spec and
## parked in zone_scenery like every other ambience node.
static func fx_emitter(spec: Dictionary) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = soft_tex()
	e.amount = int(spec.get("amount", 12))
	e.lifetime = float(spec.get("life", 6.0))
	e.preprocess = 4.0
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(760, 340)
	e.z_index = int(spec.get("z", 11))
	e.color = spec.get("color", Color(1, 1, 1, 0.3))
	e.direction = spec.get("dir", Vector2(0, -1))
	e.spread = float(spec.get("spread", 20.0))
	e.gravity = spec.get("gravity", Vector2.ZERO)
	var vel: Array = spec.get("vel", [8.0, 20.0])
	e.initial_velocity_min = vel[0]
	e.initial_velocity_max = vel[1]
	var scl: Array = spec.get("scale", [1.5, 3.0])
	e.scale_amount_min = scl[0]
	e.scale_amount_max = scl[1]
	return e


## Roll this room's ambient life from its terrain. Boss arenas stay sterile.
##
## MIMIC NATURE (owner doctrine 2026-08-17 — "does it feel real enough?"):
## life comes in FLOCKS and CLUMPS, not lone strays sprinkled in. Social
## species (sparrows, butterflies, bats, crows, wisps) spawn as clustered
## groups; solitary ones (the hawk) fly alone. Density is a CURVE, not a
## constant — some rooms get a second group, some stay quiet. Birds also
## FORAGE: they land, hop/peck/stand, then flush (see Critter._land).
static func populate(game: Node2D, zi: int) -> Array:
	var out: Array = []
	var tid: String = game.terrain_by_zone[zi]
	var zone: Dictionary = game.zones[zi]
	if String(zone.get("boss", "")) != "":
		return out                       # boss rooms: no critters, no fog, no river life
	var pr: Rect2 = game.play_rect(zi)
	var area_fraction := clampf(pr.get_area() / float(game.room_rect(zi).get_area()), 0.0, 1.0)
	var density := area_fraction if tid in ["village", "darkwood"] \
		and area_fraction < Balance.AMBIENT_COMPACT_AREA_MAX else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + int(game.wander_seed)

	# --- helpers (all args explicit: GDScript lambdas don't apply defaults
	# through Callable.call, so every call passes the full signature) --------
	# SOLITARY single(s) at independent homes — the lone hawk, drifting rubble.
	var life := func(kind: String, n: int, mode: String, tint: Color, reactive: bool) -> void:
		for i in n:
			var c := Critter.new()
			c.game = game
			c.kind = kind
			c.mode = mode
			c.tint = tint
			c.reactive = reactive
			c.span = pr
			c.home = pr.position + Vector2(
				rng.randf_range(120.0, pr.size.x - 120.0),
				rng.randf_range(120.0, pr.size.y - 120.0))
			c.position = c.home
			game.world.add_child(c)
			out.append(c)
	# A FLOCK: lo..hi members clustered within `spread` of one shared centre, so
	# they read as a group foraging/drifting the same patch.
	# The river (grown a little) and every hazard pool are off-limits to foraging
	# birds — no walking on water, no pecking in lava/poison. Flying OVER is fine.
	var water: Rect2 = (game.rivers[zi]["rect"] as Rect2).grow(40.0) \
		if game.rivers.has(zi) else Rect2()
	var hazard_circles: Array = []
	for hz in game.hazards:
		if hz["zone"] == zi:
			hazard_circles.append({"pos": hz["pos"], "radius": float(hz["radius"]) + 26.0})
	var flock := func(kind: String, mode: String, tint: Color, reactive: bool, lo: int, hi: int, spread: float) -> void:
		var center := pr.position + Vector2(
			rng.randf_range(spread + 60.0, pr.size.x - spread - 60.0),
			rng.randf_range(spread + 60.0, pr.size.y - spread - 60.0))
		var rolled := rng.randi_range(lo, hi)
		var kept := mini(rolled, maxi(Balance.AMBIENT_FLOCK_MIN, roundi(rolled * density)))
		for i in rolled:
			# Consume every old placement roll, including omitted members, so
			# reducing this flock does not relocate the groups that follow.
			var home := center + Vector2(
				rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
			if i >= kept:
				continue
			var c := Critter.new()
			c.game = game
			c.kind = kind
			c.mode = mode
			c.tint = tint
			c.reactive = reactive
			c.span = pr
			if kind == "bird":
				c.no_land = water
				c.no_land_circles = hazard_circles
			c.home = home
			c.position = c.home
			game.world.add_child(c)
			out.append(c)
	# A SKY FLOCK: n birds sharing a heading + height band, staggered down a
	# line, so a flock/murder crosses TOGETHER instead of as lone strays.
	var soar_flock := func(kind: String, tint: Color, n: int) -> void:
		var dir := 1 if rng.randf() < 0.5 else -1
		var band := pr.position.y + rng.randf_range(24.0, pr.size.y * 0.3)
		var kept := mini(n, maxi(Balance.AMBIENT_FLOCK_MIN, roundi(n * density)))
		for i in n:
			var offset := float(i) * rng.randf_range(60.0, 110.0)
			if i >= kept:
				continue
			var c := Critter.new()
			c.game = game
			c.kind = kind
			c.mode = "soar"
			c.tint = tint
			c.span = pr
			c.soar_dir = dir
			c.soar_y0 = band
			c.soar_x_off = offset
			game.world.add_child(c)
			out.append(c)
	var fx := func(spec: Dictionary) -> void:
		var e := Ambience.fx_emitter(spec)
		game.add_child(e)
		out.append(e)

	var W := Color.WHITE
	match tid:
		"village", "darkwood":
			flock.call("bird", "flit", W, true, 4, 7, 95.0)                   # a sparrow flock (lands to forage)
			flock.call("butterfly", "flit", W, false, 3, 6, 80.0)            # a drift of butterflies
			soar_flock.call("bird", W, 2 + rng.randi_range(0, 2))            # a flock crossing the sky
			if rng.randf() < Balance.AMBIENT_SECOND_FLOCK_CHANCE * density:
				flock.call("bird", "flit", W, true, 2, 3, 70.0)             # sometimes a second small group
		"holy":
			flock.call("butterfly", "flit", W, false, 3, 6, 85.0)
			soar_flock.call("bird", Color(1.15, 1.12, 1.0), 2)              # a pair of doves
			flock.call("wisp", "glow", Color(1.0, 0.9, 0.55, 0.9), false, 3, 5, 95.0)  # motes of light
		"storm":
			soar_flock.call("bird", W, 3 + rng.randi_range(0, 3))           # birds scattering on the wind
		"marsh":
			flock.call("butterfly", "flit", W, false, 3, 5, 80.0)
			flock.call("dragonfly", "flit", W, true, 3, 6, 100.0)           # dragonflies over the water
			out.append_array(_water(game, zi))
		"bog":
			flock.call("butterfly", "flit", W, false, 2, 4, 75.0)
			flock.call("dragonfly", "flit", W, true, 3, 6, 100.0)
			flock.call("wisp", "glow", Color(0.55, 1.0, 0.6, 0.85), false, 2, 4, 90.0)  # will-o'-wisps
			out.append_array(_water(game, zi))
		"spore":
			flock.call("butterfly", "flit", W, false, 3, 5, 80.0)
			flock.call("wisp", "glow", Color(0.85, 0.5, 1.0, 0.85), false, 2, 4, 90.0)
		"crystal":
			flock.call("wisp", "glow", Color(0.5, 0.9, 1.0, 0.9), false, 4, 7, 115.0)
		"keep":
			flock.call("bat", "flit", W, true, 5, 9, 115.0)                  # a bat colony
			soar_flock.call("crow", W, 1 + rng.randi_range(0, 1))
		"graveyard":
			soar_flock.call("crow", W, 3 + rng.randi_range(0, 2))           # a murder of crows
			life.call("fog", 2, "fog", Color(0.82, 0.85, 0.9, 0.28), false)
		"desert":
			life.call("hawk", 1, "soar", W, false)                          # a lone hawk, circling
			if rng.randf() < 0.5:
				soar_flock.call("crow", W, 2 + rng.randi_range(0, 1))
		"magma":
			fx.call({"color": Color(0.55, 0.5, 0.5, 0.5), "dir": Vector2(0.3, 1),
				"gravity": Vector2(4, 14), "vel": [10.0, 26.0], "scale": [1.2, 2.4],
				"amount": 16, "life": 8.0, "z": 11})                          # drifting ash
			fx.call({"color": Color(1.0, 0.7, 0.4, 0.16), "dir": Vector2(0, -1),
				"gravity": Vector2(0, -22), "vel": [12.0, 30.0], "scale": [3.0, 6.0],
				"amount": 10, "life": 5.0, "z": 10, "spread": 12.0})          # heat haze
			flock.call("bat", "flit", Color(0.5, 0.35, 0.3), true, 2, 4, 90.0)  # ash-dark bats
		"ice":
			life.call("hawk", 1, "soar", Color(1.1, 1.12, 1.2), false)      # a lone hawk over the ice
			soar_flock.call("bird", Color(1.1, 1.14, 1.2), 2 + rng.randi_range(0, 2))
		"void":
			flock.call("wisp", "glow", Color(0.6, 0.4, 0.95, 0.85), false, 2, 4, 90.0)
			life.call("debris", 2, "float", Color(0.35, 0.3, 0.45), false)
			life.call("fog", 1, "fog", Color(0.35, 0.25, 0.5, 0.3), false)

	return out


## Rivers get ripples + the occasional plop, in any non-boss room (the river,
## if one rolled, spawns just after us; nodes with no river free themselves).
static func _water(game: Node2D, zi: int) -> Array:
	var out: Array = []
	for i in 6:
		var rp := Ripple.new()
		rp.game = game
		rp.zi = zi
		game.world.add_child(rp)
		out.append(rp)
	for i in 2:
		var pl := Plop.new()
		pl.game = game
		pl.zi = zi
		game.world.add_child(pl)
		out.append(pl)
	return out
