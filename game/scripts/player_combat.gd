extends "res://scripts/player_core.gd"
## PLAYER, layer 2 of 4 — targeting, hit resolution, the shared
## combat juice, and the warrior/archer/mage/assassin ability funcs.
## See player_core.gd for the chain layout.


# ================================================================ targeting

func auto_aim(rng := 520.0) -> Enemy:
	if is_instance_valid(locked_target) and not locked_target.dying \
			and global_position.distance_to(locked_target.global_position) <= rng * 1.4:
		return locked_target
	locked_target = null
	var best: Enemy = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func cycle_target() -> void:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and global_position.distance_to(e.global_position) <= 560.0:
			list.append(e)
	if list.is_empty():
		locked_target = null
		return
	list.sort_custom(func(a, b) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var idx := list.find(locked_target)
	locked_target = list[(idx + 1) % list.size()]
	game.sfx("talk")


func aim_dir(rng := 520.0) -> Vector2:
	var target := auto_aim(rng)
	if target:
		return (target.global_position - global_position).normalized()
	return facing


# ================================================================= abilities

func hit_enemy(e: Enemy, mult: float, effects := {}) -> void:
	for key in _tfx:
		if not effects.has(key):
			effects[key] = _tfx[key]
	var dmg_type: String = effects.get("type", Classes.CLASSES[cls]["dmg_type"])
	var pen := 0.0
	var e_res := 0.0
	if dmg_type == "phys":
		pen = physpen
		e_res = e.physres
	elif dmg_type == "magic":
		pen = magpen
		e_res = e.magres

	var result := Stats.resolve(current_atk() * mult, dmg_type,
		crit + effects.get("crit_bonus", 0.0), crit_dmg, pen, dex, e_res, e.eva, e.critres)
	if result["miss"]:
		game.spawn_text(e.global_position + Vector2(0, -30), "MISS", Color(0.7, 0.7, 0.7))
		return
	var dmg: float = result["dmg"]
	var is_crit: bool = result["crit"]
	# Nightfang passive / Shadow opportunist: stunned or slowed prey always crits.
	if (s_passive() == "nightfang" or effects.get("opportunist", 0)) and dmg_type != "true" \
			and not is_crit and (e.stun_time > 0.0 or e.slow_time > 0.0):
		is_crit = true
		dmg *= crit_dmg
	# Hunt: a lined-up shot cannot fail to crit.
	if next_crit and dmg_type != "true":
		next_crit = false
		if not is_crit:
			is_crit = true
			dmg *= crit_dmg

	# ------------------------------------------------ theme / rider effects
	if effects.has("dot"):
		var dot_color := Color(0.5, 1.2, 0.5) if _tcolor.g > _tcolor.r else Color(1.4, 0.8, 0.6)
		e.apply_burn(current_atk() * effects["dot"], 3.0, dot_color)
	if effects.has("burn"):
		e.apply_burn(effects["burn"], 3.0)
	if s_passive() == "phoenix" and cls == "mage":
		pass  # phoenix burn rides on the projectile fx instead
	if effects.has("slow"):
		e.apply_slow(1.0 - effects["slow"] if effects["slow"] < 1.0 else 0.5, effects.get("slow_dur", 2.0))
	if effects.has("stun"):
		e.apply_stun(effects["stun"])
	if effects.has("stagger"):
		e.apply_stun(effects["stagger"])
	if effects.has("stun_chance") and randf() < effects["stun_chance"]:
		e.apply_stun(0.5)
	if effects.has("vuln") and randf() < effects["vuln"]:
		e.vuln_time = 3.0
		game.spawn_text(e.global_position + Vector2(0, -44), "EXPOSED", Color(1, 0.5, 0.3))
	if effects.has("heal"):
		hp = minf(max_hp, hp + max_hp * effects["heal"])

	# Lifesteal (AoE hits only steal a third).
	var ls := current_lifesteal() * (0.33 if effects.get("aoe", false) else 1.0)
	if ls > 0.0:
		hp = minf(max_hp, hp + dmg * ls)

	var dir := (e.global_position - global_position).normalized()
	e.take_damage(dmg, dir, is_crit)
	if effects.has("knock") and not e.dying:
		e.knock = dir * effects["knock"]
	if effects.has("pull") and not e.dying:
		e.knock = -dir * 380.0
	if effects.has("splash"):
		game.burst(e.global_position, _tcolor if _themed else Color(1.0, 0.6, 0.2), 8)
		for e2 in _enemies_within(e.global_position, 80.0):
			if e2 != e and not e2.dying:
				e2.take_damage(dmg * effects["splash"], (e2.global_position - e.global_position).normalized())
	# Echo: the hit strikes again at half strength.
	if effects.has("echo") and not effects.has("_echoed") and randf() < effects["echo"] and not e.dying:
		var again := effects.duplicate()
		again["_echoed"] = true
		hit_enemy(e, mult * 0.5, again)


func _enemies_within(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and center.distance_to(e.global_position) <= radius:
			out.append(e)
	return out


# ------------------------------------------------------ shared juice ---

## A shockwave ring at pos: expands outward, or collapses inward.
func _ring_fx(pos: Vector2, color: Color, radius: float, collapse := false) -> void:
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(color, 0.9)
	ring.global_position = pos
	ring.z_index = 7
	game.add_child(ring)
	var big := radius / 24.0
	ring.scale = Vector2(big, big) if collapse else Vector2(0.3, 0.3)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(0.3, 0.3) if collapse else Vector2(big, big), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if collapse else Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)


## Ghost copies of the hero along a dash path, fading in sequence.
func _afterimages(start: Vector2, end: Vector2, color: Color, count := 3) -> void:
	if sprite == null:
		return
	for i in count:
		var t := float(i + 1) / float(count + 1)
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.flip_h = sprite.flip_h
		ghost.scale = sprite.scale
		ghost.global_position = start.lerp(end, t) + sprite.position
		ghost.modulate = Color(color, 0.5)
		ghost.z_index = 5
		game.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.26)
		tw.tween_callback(ghost.queue_free)


## A glowing scorch/frost line left on the ground along a dash path.
func _floor_streak(start: Vector2, end: Vector2, color: Color) -> void:
	var streak := Sprite2D.new()
	streak.texture = Art.tex("glow")
	streak.modulate = Color(color, 0.5)
	streak.global_position = (start + end) / 2.0
	streak.rotation = (end - start).angle()
	streak.scale = Vector2(maxf(1.0, start.distance_to(end) / 40.0), 0.8)
	streak.z_index = -5
	game.add_child(streak)
	var tw := streak.create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, 1.1)
	tw.tween_callback(streak.queue_free)


## Release flash at the weapon: shots visibly leave YOU, not thin air.
func _muzzle(dir: Vector2, color: Color) -> void:
	var fl := Sprite2D.new()
	fl.texture = Art.tex("glow")
	fl.modulate = Color(color, 0.85)
	fl.position = dir * 26.0
	fl.scale = Vector2(0.5, 0.5)
	fl.z_index = 6
	add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "scale", Vector2(1.05, 1.05), 0.08)
	tw.parallel().tween_property(fl, "modulate:a", 0.0, 0.11)
	tw.tween_callback(fl.queue_free)


## Melee strike. style "swing" = crescent arc; "stab" = straight thrust
## (a piercing streak, and the held weapon lunges instead of swiping).
func _melee_arc(mult: float, reach: float, fx_name: String, effects := {}, style := "swing", snd := "slash") -> void:
	game.sfx(snd)
	melee_swing = 0.16
	melee_style = style
	var dir := aim_dir(220.0)
	melee_dir = dir
	if style == "stab":
		# Thrust streak: a stretched flash of light along the stab line,
		# with a white-hot core and an impact flash at the point.
		var streak := Sprite2D.new()
		streak.texture = Art.tex("glow")
		streak.modulate = Color(_tcolor if _themed else Color(1, 1, 1), 0.9)
		streak.rotation = dir.angle()
		streak.scale = Vector2(reach / 26.0, 0.45)
		streak.position = dir * reach * 0.55
		streak.z_index = 6
		add_child(streak)
		var tw := streak.create_tween()
		tw.tween_property(streak, "scale:y", 0.1, 0.12)
		tw.parallel().tween_property(streak, "modulate:a", 0.0, 0.12)
		tw.tween_callback(streak.queue_free)
		var core := Sprite2D.new()
		core.texture = Art.tex("glow")
		core.modulate = Color(1, 1, 1, 0.95)
		core.rotation = dir.angle()
		core.scale = Vector2(reach / 34.0, 0.16)
		core.position = dir * reach * 0.55
		core.z_index = 7
		add_child(core)
		var ct := core.create_tween()
		ct.tween_property(core, "scale:y", 0.04, 0.1)
		ct.parallel().tween_property(core, "modulate:a", 0.0, 0.1)
		ct.tween_callback(core.queue_free)
		var tip := Sprite2D.new()
		tip.texture = Art.tex("glow")
		tip.modulate = Color(_tcolor if _themed else Color(1, 1, 1), 0.9)
		tip.position = dir * reach
		tip.scale = Vector2(0.3, 0.3)
		tip.z_index = 7
		add_child(tip)
		var tt := tip.create_tween()
		tt.tween_property(tip, "scale", Vector2(1.1, 1.1), 0.11)
		tt.parallel().tween_property(tip, "modulate:a", 0.0, 0.12)
		tt.tween_callback(tip.queue_free)
	else:
		# The crescent SWEEPS across the arc instead of fading in place —
		# a pivot at the hero swings the blade sprite through ~100°.
		var pivot := Node2D.new()
		pivot.rotation = dir.angle() - 0.9
		pivot.z_index = 6
		add_child(pivot)
		var spr := Sprite2D.new()
		spr.texture = Art.tex(fx_name)
		spr.position = Vector2(reach * 0.5, 0)
		spr.scale = Vector2(2.8, 2.8) * (reach / 78.0)
		if _themed:
			spr.modulate = _tcolor
		pivot.add_child(spr)
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "rotation", dir.angle() + 0.9, 0.13) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(pivot, "modulate:a", 0.0, 0.17)
		tween.tween_callback(pivot.queue_free)
	for e in _enemies_within(global_position + dir * reach * 0.55, reach * 0.55):
		hit_enemy(e, mult, effects.duplicate())


func _proj(dir: Vector2, mult: float, tex: String, speed_px: float) -> Projectile:
	var p := Projectile.spawn(game, global_position + dir * 24.0, dir * speed_px, 0.0, true, tex)
	p.hit_player_mult = mult
	p.source_player = self
	p.fx = _tfx.duplicate()
	if _themed:
		p.modulate = Color(1, 1, 1).lerp(_tcolor, 0.55)
	return p


func _shoot(dir: Vector2, mult: float) -> void:
	game.sfx("bow")
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	var p := _proj(dir, mult, "arrow", 520.0)
	if s_passive() == "ricochet":
		p.fx["ric"] = 1


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	_muzzle(dir, _tcolor if _themed else Color(1.0, 0.6, 0.2))
	# The Ice variant flies as a crystal lance, not a ball of fire.
	var tex := "icelance" if _tfx.get("pierce", 0) else "fireball"
	var p := _proj(dir, mult, tex, 440.0 * float(_tfx.get("proj_speed", 1.0)))
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if s_passive() == "phoenix":
		p.fx["splash"] = maxf(p.fx.get("splash", 0.0), 0.5)
		p.fx["burn"] = current_atk() * 0.35


func _whirlwind(f := 1.0) -> void:
	game.sfx("sword")
	var radius := 115.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(1, 1, 1)
	var inward: bool = _tfx.get("pull", 0)

	# Three blades sweep a full revolution around the hero (reversed
	# when Earth drags enemies in — the vortex visibly turns inward).
	var pivot := Node2D.new()
	pivot.z_index = 6
	add_child(pivot)
	for i in 3:
		var ang := TAU * i / 3.0
		var blade := Sprite2D.new()
		blade.texture = Art.tex("slash")
		blade.modulate = Color(col, 0.9)
		blade.rotation = ang
		blade.position = Vector2.from_angle(ang) * radius * 0.55
		blade.scale = Vector2(2.6, 2.6)
		pivot.add_child(blade)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation", TAU * (-1.0 if inward else 1.0), 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "modulate:a", 0.0, 0.34)
	tw.tween_callback(pivot.queue_free)
	_ring_fx(global_position, col, radius, inward)

	var eff := {"stagger": 0.3, "aoe": true}
	if not inward:  # Earth drags them in instead of flinging
		eff["knock"] = 380.0
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 0.9 * f, eff.duplicate())


## Per-class ultimate activation sound, falling back to the generic one.
func _ult_sfx() -> void:
	var key := "ult_" + cls
	game.sfx(key if game.sounds.has(key) else "ult")


func _multishot(f := 1.0) -> void:
	# ONE release sound for the whole volley — five overlapping copies of
	# the same sample phase into a nasty digital flanging artifact.
	# Pitched lower than Quick Shot so the two are distinguishable.
	game.sfx("slash", 0.85)
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	var count := int(_tfx.get("knives", 5))
	var step := 0.05 if _tfx.get("narrow", 0) else float(_tfx.get("spread", 0.16))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), 0.55 * f, "arrow", 520.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
		if s_passive() == "ricochet":
			p.fx["ric"] = 1


func _tumble() -> void:
	game.sfx("blink")
	hurt_cd = maxf(hurt_cd, 0.5)
	var origin := global_position
	global_position = game.clamp_to_zone(global_position + facing * 130.0, global_position)
	# The roll reads as motion: ghost trail + kicked-up dust behind you.
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
	# An arrow visibly falls out of the sky onto the target.
	var arrow := Sprite2D.new()
	arrow.texture = Art.tex("arrow")
	arrow.rotation = PI / 2.0
	arrow.scale = Vector2(3, 3)
	arrow.global_position = e.global_position + Vector2(randf_range(-10, 10), -160)
	arrow.z_index = 30
	game.add_child(arrow)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position:y", e.global_position.y, 0.11)
	tween.tween_callback(arrow.queue_free)
	game.burst(e.global_position, Color(0.7, 1.0, 0.7))
	var storm_col := _theme_color("ult") if ability_theme.get("ult", "") != "" else Color(0.7, 1.0, 0.7)
	_ring_fx(e.global_position, storm_col, 42.0)
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	hit_enemy(e, 0.8, eff)


func _frost_nova(f := 1.0) -> void:
	game.sfx("nova")
	game.shake(6.0)
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(0.45, 0.8, 1.0)
	var inward: bool = _tfx.get("pull", 0)
	var fiery: bool = _tfx.get("no_knock", 0)

	# Shockwave RING — expands for the blast, COLLAPSES for the implosion.
	var r_scale := radius / 24.0
	for delay in ([0.0, 0.07] if not inward else [0.0]):
		var ring := Sprite2D.new()
		ring.texture = Art.tex("ring")
		ring.modulate = Color(col, 0.95)
		ring.z_index = 7
		add_child(ring)
		var tw := ring.create_tween()
		if delay > 0.0:
			ring.scale = Vector2(0.1, 0.1)
			tw.tween_interval(delay)
		if inward:
			ring.scale = Vector2(r_scale, r_scale)
			tw.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.26) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(ring, "scale", Vector2(r_scale * (1.0 - delay), r_scale * (1.0 - delay)), 0.26) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
		tw.tween_callback(ring.queue_free)

	# Radial shards: icicles fly OUT, embers for the flame ring, and the
	# implosion sucks them IN instead.
	for i in 10:
		var ang := TAU * i / 10.0 + randf_range(-0.15, 0.15)
		var shard := Sprite2D.new()
		shard.texture = Art.tex("fireball" if fiery else "icelance")
		shard.modulate = col
		shard.rotation = ang + (PI if inward else 0.0)
		shard.scale = Vector2(1.5, 1.5)
		shard.z_index = 7
		shard.position = Vector2.from_angle(ang) * (radius if inward else 6.0)
		add_child(shard)
		var st := shard.create_tween()
		st.tween_property(shard, "position",
			Vector2.ZERO if inward else Vector2.from_angle(ang) * radius, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if inward else Tween.EASE_OUT)
		st.parallel().tween_property(shard, "modulate:a", 0.0, 0.26)
		st.tween_callback(shard.queue_free)

	# Lingering ground frost / scorch where the blast happened.
	var floor_glow := Sprite2D.new()
	floor_glow.texture = Art.tex("glow")
	floor_glow.modulate = Color(col, 0.4)
	floor_glow.scale = Vector2(radius / 24.0, radius / 32.0)
	floor_glow.global_position = global_position
	floor_glow.z_index = -5
	game.add_child(floor_glow)
	var ft := floor_glow.create_tween()
	ft.tween_property(floor_glow, "modulate:a", 0.0, 0.9)
	ft.tween_callback(floor_glow.queue_free)

	game.hud.flash_screen(Color(col, 1.0), 0.2, 0.25)
	game.burst(global_position, col, 18)
	game.burst(global_position, Color(1, 1, 1), 8)

	# A real panic button: big damage, shove everything away, slow it.
	# (Fire ring burns instead of shoving; Wind implodes them INTO you.)
	var eff := {"slow": 0.5, "slow_dur": 2.5, "aoe": true}
	if not (fiery or inward):
		eff["knock"] = 340.0
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 1.4 * f, eff.duplicate())


## Dash `dist` pixels in the move direction, damaging every enemy along
## the path. Used by mage Blink and assassin Shadow Dash — and because
## it HITS things, ability themes fully apply to it. Returns kill count
## (Phantom step refunds cooldown on kills).
func _dash_strike(dist: float, mult: float, effects := {}) -> int:
	game.sfx("blink")
	var color := _tcolor if _themed else Color(0.6, 0.7, 1.0)
	var start := global_position
	global_position = game.clamp_to_zone(start + facing * dist, start)
	var end := global_position
	hurt_cd = maxf(hurt_cd, 0.3)  # brief immunity while dashing
	game.burst(start, color, 8)
	game.burst(end, color, 8)
	_afterimages(start, end, color)

	# Light trail between the two points.
	var mid := (start + end) / 2.0
	var trail := Sprite2D.new()
	trail.texture = Art.tex("glow")
	trail.modulate = Color(color, 0.7)
	trail.global_position = mid
	trail.rotation = (end - start).angle()
	trail.scale = Vector2(maxf(1.0, start.distance_to(end) / 44.0), 1.1)
	trail.z_index = 6
	game.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.25)
	tween.tween_callback(trail.queue_free)

	var kills := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		if e.global_position.distance_to(closest) <= 55.0:
			hit_enemy(e, mult, effects.duplicate())
			if e.dying or e.hp <= 0.0:
				kills += 1
	return kills


func _blink() -> void:
	var eff := {"aoe": true}
	if _tfx.has("freeze_path"):
		eff["stun"] = float(_tfx["freeze_path"])  # Frostwalk
	var start := global_position
	_dash_strike(190.0 * float(_tfx.get("dash_mult", 1.0)), 0.8, eff)
	# Fire leaves a burning wake on the ground; Ice a frozen one.
	if _themed and (_tfx.has("dot") or _tfx.has("freeze_path")):
		_floor_streak(start, global_position, _tcolor)


func _meteor() -> void:
	_ult_sfx()
	# Starfall (wind): several smaller comets across several targets.
	var count := int(_tfx.get("meteors", 1))
	var spots: Array = []
	if count > 1:
		for e in _enemies_within(global_position, 560.0):
			spots.append(e.global_position)
			if spots.size() >= count:
				break
	if spots.is_empty():
		var target := auto_aim()
		spots.append(target.global_position if target else global_position + facing * 150.0)
	for pos in spots:
		_meteor_at(pos)


func _meteor_at(pos: Vector2) -> void:
	var fx_copy := _tfx.duplicate()
	var col := _tcolor if _themed else Color(1.0, 0.6, 0.2)

	# Growing impact shadow on the ground — you can feel it coming.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.global_position = pos
	mark.modulate = Color(col, 0.5)
	mark.scale = Vector2(1, 1)
	mark.z_index = -6
	game.add_child(mark)
	var mark_tw := mark.create_tween()
	mark_tw.tween_property(mark, "scale", Vector2(4.6, 4.6), 0.62)

	# The meteor itself: big, burning, with a particle trail.
	var spr := Sprite2D.new()
	spr.texture = Art.tex("fireball")
	spr.scale = Vector2(11, 11)
	spr.modulate = col
	spr.global_position = pos + Vector2(90, -460)
	spr.z_index = 30
	game.add_child(spr)
	var trail := CPUParticles2D.new()
	trail.amount = 26
	trail.lifetime = 0.5
	trail.spread = 20.0
	trail.direction = Vector2(-0.2, -1)
	trail.initial_velocity_min = 60.0
	trail.initial_velocity_max = 140.0
	trail.scale_amount_min = 2.5
	trail.scale_amount_max = 5.0
	trail.color = col
	spr.add_child(trail)

	var tween := spr.create_tween()
	tween.tween_property(spr, "global_position", pos, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		spr.queue_free()
		if is_instance_valid(mark):
			mark.queue_free()
		game.sfx("meteor")
		game.shake(14.0)
		game.hud.flash_screen(Color(1.0, 0.75, 0.4), 0.55, 0.35)
		game.burst(pos, col, 30)
		game.burst(pos, Color(1.0, 0.9, 0.5), 16)
		_ring_fx(pos, col, 150.0 * float(fx_copy.get("radius_mult", 1.0)))
		# Scorched ground lingers for a moment.
		var scorch := Sprite2D.new()
		scorch.texture = Art.tex("glow")
		scorch.modulate = Color(col, 0.6)
		scorch.global_position = pos
		scorch.scale = Vector2(4.2, 4.2)
		scorch.z_index = -5
		game.add_child(scorch)
		var s_tw := scorch.create_tween()
		s_tw.tween_property(scorch, "modulate:a", 0.0, 1.3)
		s_tw.tween_callback(scorch.queue_free)
		var radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
		for e in _enemies_within(pos, radius):
			var eff := fx_copy.duplicate()
			eff["burn"] = current_atk() * 0.4 * float(fx_copy.get("burn_mult", 1.0))
			eff["aoe"] = true
			if fx_copy.has("freeze"):
				eff["stun"] = float(fx_copy["freeze"])  # glacial comet
			hit_enemy(e, 3.5 * float(fx_copy.get("dmg_mult", 1.0)), eff)
	)


func _shadow_dash(f := 1.0) -> void:
	melee_swing = 0.16
	melee_style = "stab"
	melee_dir = facing
	game.sfx("stab")
	var start := global_position
	var kills := _dash_strike(210.0 * float(_tfx.get("dash_mult", 1.0)), 1.2 * f, {"stagger": 0.4})
	if _tfx.get("trail_mist", 0):
		# Poison: the dash line blooms into a toxic wake.
		_mist((start + global_position) / 2.0, 110.0, 0.3, _tcolor, 2.5)
	if kills > 0 and _tfx.has("kill_refund"):
		# Shadow: a kill refunds most of the cooldown.
		cds["a2"] *= 1.0 - float(_tfx["kill_refund"])
		game.spawn_text(global_position + Vector2(0, -60), "PHANTOM", Color(0.7, 0.5, 1.0))


func _fan_of_knives(f := 1.0) -> void:
	game.sfx("knife", 1.25)  # lighter/faster than the archer sounds
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.8, 0.85, 1.0))
	if _tfx.get("bloom", 0):
		# Poison: ONE heavy venom blade that detonates into a toxin cloud
		# (on its first hit, or at the end of its flight).
		var p := _proj(dir, 1.0 * f, "knife", 500.0)
		p.scale = Vector2(1.5, 1.5)
		p.life = 0.55
		p.fx["bloom_mist"] = 1
		p.fx["bloom_color"] = _tcolor
		return
	var count := int(_tfx.get("knives", 3))
	var step := float(_tfx.get("spread", 0.13))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), 0.7 * f, "knife", 560.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))


## An expanding cloud that ticks poison on everything inside — the mist
## primitive behind Venom Bloom, Toxic Wake and the archer's toxin cloud.
## Not a flat glow: a ROILING mass of drifting blobs, rising toxic motes,
## a burst ring on arrival, and venom bubbles on everything it eats.
func _mist(pos: Vector2, radius: float, dps_mult: float, color: Color, dur := 2.5) -> void:
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 4
	game.add_child(root)
	_ring_fx(pos, color, radius)
	game.burst(pos, color, 10)

	# Overlapping blobs, each swelling to its own size and slowly churning
	# around the center — the cloud visibly boils instead of sitting still.
	for i in 6:
		var blob := Sprite2D.new()
		blob.texture = Art.tex("glow")
		var shade := randf_range(0.55, 1.0)
		blob.modulate = Color(color.r * shade, color.g * shade, color.b * shade, 0.0)
		var off := Vector2.from_angle(TAU * i / 6.0 + randf_range(-0.4, 0.4)) \
			* randf_range(radius * 0.15, radius * 0.45)
		blob.position = off
		blob.scale = Vector2(0.6, 0.6)
		root.add_child(blob)
		var grow := blob.create_tween()
		grow.tween_property(blob, "modulate:a", randf_range(0.4, 0.6), 0.35)
		var target := randf_range(radius / 30.0, radius / 20.0)
		grow.parallel().tween_property(blob, "scale", Vector2(target, target), 0.5)
		var churn := blob.create_tween()
		churn.set_loops()
		churn.tween_property(blob, "position", off.rotated(0.9), randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)
		churn.tween_property(blob, "position", off, randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)

	# Toxic motes bubbling up out of the whole area for the cloud's life.
	var motes := CPUParticles2D.new()
	motes.amount = 30
	motes.lifetime = 1.1
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector2(0, -1)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -26)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 28.0
	motes.scale_amount_min = 1.6
	motes.scale_amount_max = 3.4
	motes.color = Color(color, 0.85)
	root.add_child(motes)

	var ticks := int(dur / 0.4)
	for i in ticks:
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(root):
			return
		if dead:
			root.queue_free()
			return
		for e in _enemies_within(pos, radius):
			e.apply_burn(current_atk() * dps_mult, 1.2, Color(color, 1.0))
			game.burst(e.global_position + Vector2(0, -10), color, 4)  # venom bubbles
	motes.emitting = false
	var fade := root.create_tween()
	fade.tween_property(root, "modulate:a", 0.0, 0.6)
	fade.tween_callback(root.queue_free)


func _death_mark() -> void:
	var target := auto_aim()
	if target == null:
		cds["ult"] = 1.0
		return
	# EXECUTION: the world darkens, you appear on top of the target,
	# a giant death mark rises, then a 3-hit true-damage flurry lands.
	_ult_sfx()
	game.hud.flash_screen(Color(0.35, 0.0, 0.1), 0.5, 0.45)
	game.burst(global_position, Color(0.5, 0.2, 0.5), 12)
	var dir := (target.global_position - global_position).normalized()
	global_position = game.clamp_to_zone(target.global_position + dir * 42.0, target.global_position)
	target.vuln_time = 5.0
	target.apply_stun(0.6)
	if _tfx.has("mark_dot"):
		# Poison: the mark itself rots the target.
		target.apply_burn(current_atk() * float(_tfx["mark_dot"]), 5.0, Color(0.5, 1.2, 0.5))
	game.spawn_text(target.global_position + Vector2(0, -60), "DEATH MARK", Color(1, 0.25, 0.3))

	var skull := Sprite2D.new()
	skull.texture = Art.glyph_tex("ab_skull", Color(1.0, 0.25, 0.35))
	skull.scale = Vector2(3.5, 3.5)
	skull.global_position = target.global_position + Vector2(0, -40)
	skull.z_index = 30
	game.add_child(skull)
	var tween := skull.create_tween()
	tween.tween_property(skull, "global_position:y", skull.global_position.y - 46.0, 0.7)
	tween.parallel().tween_property(skull, "modulate:a", 0.0, 0.7)
	tween.tween_callback(skull.queue_free)

	_death_mark_flurry(target, float(_tfx.get("flurry_heal", 0.0)), float(_tfx.get("execute", 0.0)))


func _death_mark_flurry(target: Enemy, flurry_heal := 0.0, execute := 0.0) -> void:
	for i in 3:
		if not is_instance_valid(target) or target.dying:
			return
		melee_swing = 0.16
		melee_style = "stab"
		game.sfx("stab")
		game.shake(3.5)
		game.burst(target.global_position, Color(1.0, 0.2, 0.3), 10)
		# A visible slash rips across the target with every hit.
		var rip := Sprite2D.new()
		rip.texture = Art.tex("glow")
		rip.modulate = Color(1.0, 0.35, 0.45, 0.95)
		rip.global_position = target.global_position
		rip.rotation = randf_range(0.0, TAU)
		rip.scale = Vector2(2.4, 0.14)
		rip.z_index = 8
		game.add_child(rip)
		var rt := rip.create_tween()
		rt.tween_property(rip, "scale:y", 0.03, 0.12)
		rt.parallel().tween_property(rip, "modulate:a", 0.0, 0.14)
		rt.tween_callback(rip.queue_free)
		hit_enemy(target, 0.7 if i < 2 else 1.3, {"type": "true"})
		if flurry_heal > 0.0:
			hp = minf(max_hp, hp + max_hp * flurry_heal)  # Blood: the flurry feeds
		await get_tree().create_timer(0.09).timeout
	# Shadow: if they survived under 30%, the executioner finishes it.
	if execute > 0.0 and is_instance_valid(target) and not target.dying \
			and target.hp < target.max_hp * 0.3:
		game.shake(6.0)
		game.spawn_text(target.global_position + Vector2(0, -70), "EXECUTED", Color(1, 0.15, 0.25))
		game.burst(target.global_position, Color(0.6, 0.2, 0.6), 16)
		hit_enemy(target, execute, {"type": "true"})


