extends "res://scripts/player_kit_warrior.gd"
## PLAYER, layer 4 of 9 — the ARCHER kit: dispatch + abilities.
## (_storm_strike is driven per-frame by player.gd while storm_time runs.)
## See player_core.gd for the chain layout.


func _use_archer(slot: String, f: float) -> void:
	match slot:
		"a1":
			# Loose on the bow's draw-release frame, not the input frame (the
			# draw-and-loose animation has a windup the arrow was firing ahead of).
			await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
			if dead or downed or ghost:
				return
			_hunt_rhythm_tick()
			_shoot(aim_dir(), ability_coeff("a1") * f)
		"a2": _multishot(f)
		"a3": _tumble()
		"ult":
			await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
			if dead or downed or ghost:
				return
			storm_time = 3.0
			storm_fx = _tfx.duplicate()
			_ult_sfx()
			# Skin storms announce in their element: Frostfall's sky goes pale
			# ice, Voidwraith's goes dark violet (Ronin pattern — colour only).
			var storm_call := _tcolor if _themed else Color(0.6, 1.0, 0.6)
			if skin == "frostfall_ranger":
				storm_call = Color(0.66, 0.90, 1.00)
			elif skin == "voidwraith":
				storm_call = Color(0.55, 0.32, 0.90)
			_ring_fx(global_position, storm_call, 190.0)
			game.hud.flash_screen(storm_call, 0.3, 0.35)
			game.spawn_text(global_position + Vector2(0, -60), "ARROW STORM!", storm_call)


## Hunt rhythm (2026-07-09): the free +25% cap-exempt crit is gone — instead
## every Balance.HUNT_RHYTHM_SHOTS-th Quick Shot is a GUARANTEED crit (earned
## tempo; built crit gear still carries the other three arrows).
func _hunt_rhythm_tick() -> void:
	if ability_theme.get("a1", "") != "hunt":
		return
	hunt_rhythm += 1
	if hunt_rhythm >= Balance.HUNT_RHYTHM_SHOTS:
		hunt_rhythm = 0
		next_crit = true


func _shoot(dir: Vector2, mult: float) -> void:
	game.sfx("bow")
	var col: Color = _tcolor if _themed else Color(0.9, 1.0, 0.6)
	col = _skin_arrow_col(col)
	if next_crit:
		# The lethal arrow reads before it lands: a white-hot muzzle instead
		# of the theme tint (the hunt rhythm's 4th shot, or a lined-up shot).
		col = Color(1.0, 0.95, 0.75)
	_muzzle(dir, col)
	_skin_arrow(_proj(dir, mult, _skin_arrow_tex(), 520.0))


## Archer skin signature colour: Frostfall looses ice, Voidwraith looses
## void — over theme, like the assassin skins' knives (Ronin pattern).
func _skin_arrow_col(base: Color) -> Color:
	if skin == "frostfall_ranger":
		return Color(0.62, 0.88, 1.00)
	if skin == "voidwraith":
		return Color(0.62, 0.38, 0.95)
	return base


## Each ranger identity looses a distinct physical arrow: seasoned steel for
## base, a faceted ice shaft for Frostfall, and a barbed void head for
## Voidwraith.  Themes still colour the muzzle/impact, never the arrow body.
func _skin_arrow_tex() -> String:
	if skin == "frostfall_ranger":
		return "arrow_frost"
	if skin == "voidwraith":
		return "arrow_void"
	return "arrow_base"


## Dress a loosed arrow in its skin: Frostfall's carry an ice-pale shaft and
## a frost glint riding behind the head; Voidwraith's fly dark with a violet
## void-streak trailing them (the Phantom knife-trail language).
func _skin_arrow(p: Projectile) -> void:
	# Base arrows still inherit the active ability-variant colour. Skin arrows
	# keep their authored material palette instead of being theme-recoloured.
	p.modulate = Color.WHITE.lerp(_tcolor, 0.55) if skin == "" and _themed else Color.WHITE
	if skin == "frostfall_ranger":
		var g := Sprite2D.new()
		g.texture = Art.tex("glow")
		g.modulate = Art.hdr(Color(0.60, 0.85, 1.0, 0.38))
		g.scale = Vector2(0.18, 0.18)
		g.z_index = -1
		p._vis.add_child(g)
	elif skin == "voidwraith":
		var tr := ProjTrail.new()
		tr.proj = p
		tr.col = Color(0.55, 0.30, 0.90)
		game.add_child(tr)


func _multishot(f := 1.0) -> void:
	# Loose the volley on the bow's draw-release frame, not the input frame.
	await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
	if dead or downed or ghost:
		return
	# ONE release sound for the whole volley — five overlapping copies of
	# the same sample phase into a nasty digital flanging artifact.
	# Pitched lower than Quick Shot so the two are distinguishable.
	game.sfx("slash", 0.85)
	var dir := aim_dir()
	_muzzle(dir, _skin_arrow_col(_tcolor if _themed else Color(0.9, 1.0, 0.6)))
	var count := int(_tfx.get("knives", 5))
	var step := 0.05 if _tfx.get("narrow", 0) else float(_tfx.get("spread", 0.16))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), ability_coeff("a2") * f, _skin_arrow_tex(), 520.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
		_skin_arrow(p)


func _tumble() -> void:
	game.sfx("blink")
	# Round 45: the outright 0.5s negate on a 6s cd was too forgiving —
	# safety belongs to positioning, not a free button. The immunity is
	# now a split-second PERFECT-DODGE window (skill-timed against a hit),
	# and the roll leaves the archer NIMBLE — a soft evasion buff covers
	# the reposition so an average pilot still has margin, not a wall.
	hurt_cd = maxf(hurt_cd, 0.1)
	hurt_was_heavy = true  # the perfect-dodge window blocks heavy telegraph hits too
	dodge_time = rider("a3", "eva_secs")
	dodge_amt = rider("a3", "eva")
	if tumble_dr > 0.0:
		# Windrunner (talent): the landing steadies you — a DR window EARNED by
		# rolling, the archer's purchasable floor (same rail as Arcane Ward).
		dr_time = Balance.TUMBLE_DR_DUR
		dr_amt = tumble_dr
	var origin := global_position
	var dvec := dash_vec()
	global_position = game.clamp_to_zone(origin + dvec * 130.0, origin)
	_aim_dash_pose(dvec)  # before the trail below, so the ghosts copy the pose
	# The roll reads as motion: ghost trail + kicked-up dust behind you.
	# Skin rolls kick up their element instead of dust: Frostfall a puff of
	# rime, Voidwraith a swallow of dark (solid-tinted ghosts, Ronin-style).
	if skin == "frostfall_ranger":
		_afterimages(origin, global_position, Color(0.66, 0.90, 1.00), 2, 0.05, 0.28, true)
		game.burst(origin, Color(0.80, 0.94, 1.00), 6)
	elif skin == "voidwraith":
		_afterimages(origin, global_position, Color(0.36, 0.18, 0.55), 2, 0.05, 0.28, true)
		game.burst(origin, Color(0.50, 0.28, 0.80), 6)
		_ring_fx(origin, Color(0.50, 0.28, 0.80), 46.0, true)  # the dark swallows the spot
	else:
		_afterimages(origin, global_position, _tcolor if _themed else Color(0.9, 0.95, 1.0), 2)
		game.burst(origin, Color(0.75, 0.7, 0.6), 6)
	if _tfx.has("burst_origin"):
		# Storm: discharge where you left.
		game.sfx("nova", 1.2)
		game.burst(origin, _tcolor, 12)
		for e in _enemies_within(origin, 110.0):
			hit_enemy(e, float(_tfx["burst_origin"]), {"aoe": true})
	if _tfx.get("mist_origin", 0):
		# Venom: leave a toxin cloud behind.
		_mist(origin, 95.0, 0.35, _tcolor, 2.5)
	if _tfx.get("next_crit", 0):
		# Hunt: line up the next shot.
		next_crit = true
		game.spawn_text(global_position + Vector2(0, -60), "LINED UP", Color(1, 0.7, 0.3))


func _storm_strike() -> void:
	var e: Enemy = null
	if storm_fx.get("focus", 0):
		# Hunt: every arrow hunts YOUR target.
		e = auto_aim(560.0)
	else:
		var targets := _enemies_within(global_position, 560.0)
		if not targets.is_empty():
			e = targets[randi() % targets.size()]
	if e == null:
		return
	# Falling-arrow whoosh (deep-pitched), NOT the synth laser zap.
	game.sfx("knife", 0.75)
	var storm_col := _theme_color("ult") if ability_theme.get("ult", "") != "" else Color(0.7, 1.0, 0.7)
	# Skin rain: ice-shafted hail / dark void bolts (skin wins over theme).
	if skin == "frostfall_ranger":
		storm_col = Color(0.70, 0.90, 1.00)
	elif skin == "voidwraith":
		storm_col = Color(0.58, 0.34, 0.92)
	# An arrow visibly falls out of the sky onto the target.
	var arrow := Sprite2D.new()
	# Arrow Storm always uses the new physical arrow set; it never falls back
	# to the legacy procedural "arrow" glyph.
	arrow.texture = Art.tex(_skin_arrow_tex())
	arrow.modulate = Color.WHITE.lerp(_tcolor, 0.55) if skin == "" and _themed else Color.WHITE
	arrow.rotation = PI / 2.0
	arrow.scale = Vector2(2, 2)
	arrow.global_position = e.global_position + Vector2(randf_range(-10, 10), -160)
	arrow.z_index = 30
	game.add_child(arrow)
	# Sky arrows need the same tight glow as a Quick Shot — it rides BEHIND the
	# shaft and turns with the fall, so the impact read stays a real arrow.
	var arrow_glow := Sprite2D.new()
	arrow_glow.texture = Art.tex("glow")
	arrow_glow.modulate = Art.hdr(Color(storm_col, 0.78))
	arrow_glow.scale = Vector2(1.25, 0.48)
	arrow_glow.z_index = -1
	arrow.add_child(arrow_glow)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position:y", e.global_position.y, 0.11)
	tween.tween_callback(arrow.queue_free)
	game.burst(e.global_position, storm_col)
	_ring_fx(e.global_position, storm_col, 42.0)
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	# The storm rains for 3s while the archer keeps casting — resolve each
	# arrow with the ULT's payload snapshot, not whatever _tfx holds now
	# (the Consecration save-restore idiom).
	var saved := _tfx
	_tfx = storm_fx
	hit_enemy(e, ability_coeff("ult"), eff)
	_tfx = saved
