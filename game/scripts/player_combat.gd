extends "res://scripts/player_core.gd"
## PLAYER, layer 2 of 4 — targeting, hit resolution, the shared
## combat juice, and the warrior/archer/mage/assassin ability funcs.
## See player_core.gd for the chain layout.


# ================================================================ targeting

## Current movement input (WASD/arrows), normalized; ZERO when idle.
## Shared by the per-frame mover and abilities that step with you.
func _move_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	return dir.normalized()


func auto_aim(rng := 520.0) -> Enemy:
	if is_instance_valid(locked_target) and not locked_target.dying \
			and not locked_target.untargetable \
			and global_position.distance_to(locked_target.global_position) <= rng * 1.4:
		return locked_target
	locked_target = null
	var best: Enemy = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
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
		if e and not e.dying and not e.untargetable \
				and global_position.distance_to(e.global_position) <= 560.0:
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
	# Shadow opportunist: stunned or slowed prey always crits.
	if effects.get("opportunist", 0) and dmg_type != "true" \
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
	# DoTs resolve like hits — no hidden true damage: the tick rate is
	# mitigated by the target's res minus our pen, SNAPSHOT at
	# application (fast refresh cadences re-snapshot within a beat).
	# Mitigation relief only: no excess-pen flat bonus on ticks.
	var dot_mit := 1.0 - Stats.res_frac(maxf(0.0, e_res - pen))
	if effects.has("dot"):
		var dot_color := Color(0.5, 1.2, 0.5) if _tcolor.g > _tcolor.r else Color(1.4, 0.8, 0.6)
		var dot_dps: float = current_atk() * effects["dot"] * dot_mit
		if effects.get("toxin", 0):
			e.apply_toxin(dot_dps, 3.0, dot_color)
		else:
			e.apply_burn(dot_dps, 3.0, dot_color)
	if effects.has("burn"):
		e.apply_burn(float(effects["burn"]) * dot_mit, 3.0)
	if effects.has("slow"):
		e.apply_slow(1.0 - effects["slow"] if effects["slow"] < 1.0 else 0.5, effects.get("slow_dur", 2.0))
	if effects.has("stun"):
		_stun_or_concuss(e, effects["stun"])
	if effects.has("stagger"):
		_stun_or_concuss(e, effects["stagger"])
	if effects.has("stun_chance") and randf() < effects["stun_chance"]:
		_stun_or_concuss(e, 0.5)
	if effects.has("vuln") and randf() < effects["vuln"]:
		e.vuln_time = 3.0
		game.spawn_text(e.global_position + Vector2(0, -44), "EXPOSED", Color(1, 0.5, 0.3))
	if effects.has("heal"):
		gain_hp(max_hp * effects["heal"])  # bulwark ram / holy strike: SHOWS
	if effects.has("blood_amp"):
		# Blood theme (round 32): the cut bites harder the deeper YOU
		# bleed — missing health becomes DAMAGE (the base kit's surge
		# already turns it into lifesteal; blood doubles down on the edge).
		dmg *= 1.0 + effects["blood_amp"] * (1.0 - hp / max_hp)
	# Warlock wither: a maintained hex deepens — every hit bites harder
	# the longer the curse has held (only the warlock ever fills `wither`).
	if wither.has(e):
		dmg *= 1.0 + mini(int(float(wither[e]) / Balance.WITHER_STACK_EVERY),
			Balance.WITHER_MAX_STACKS) * Balance.WITHER_PER_STACK
	# Brittle (ice): cold cracks the target — this hit bites per existing
	# stack, then deepens the crack for the next one.
	if effects.get("brittle", 0):
		dmg *= 1.0 + e.brittle * Balance.BRITTLE_PER_STACK
		e.add_brittle()
	# Crush (void): gravity hurts — a target recently displaced hard
	# (shove, hard pull) takes the hit deeper.
	if effects.get("crush", 0) and e.crush_t > 0.0:
		dmg *= 1.0 + Balance.CRUSH_MULT
	# Killing Frost (mage Ice talent): bite harder into slowed or frozen prey.
	if chill_dmg > 0.0 and (e.slow_time > 0.0 or e.stun_time > 0.0):
		dmg *= 1.0 + chill_dmg
	# Serpent's Due (archer Venom talent): poisoned prey takes extra damage.
	if poison_dmg > 0.0 and e.burn_time > 0.0:
		dmg *= 1.0 + poison_dmg
	# Coup de Grâce (assassin talent): finish wounded prey faster.
	if execute_dmg > 0.0 and e.max_hp > 0.0 and e.hp < e.max_hp * 0.40:
		dmg *= 1.0 + execute_dmg

	# Lifesteal (AoE hits only steal a third).
	var ls := current_lifesteal() * (0.33 if effects.get("aoe", false) else 1.0)
	if ls > 0.0:
		hp = minf(max_hp, hp + dmg * ls)

	var dir := (e.global_position - global_position).normalized()
	e.take_damage(dmg, dir, is_crit)
	if effects.has("knock") and not e.dying \
			and not (effects.get("knock_no_boss", 0) and e is Boss):
		# knock_no_boss: the shove flings mobs but a boss holds its ground
		# (mage Frost Nova — the mage spaces with its feet, never by shoving
		# a boss; warlock Void is the deliberate exception and omits the flag).
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


## DoT rate mitigated by the target's res (class damage type) minus our
## pen — for dot sources OUTSIDE hit_enemy (the mist primitive, the
## poison Death Mark), which mirror the rider pipeline's snapshot rule.
func _dot_dps(e: Enemy, dps: float) -> float:
	var dmg_type: String = Classes.CLASSES[cls]["dmg_type"]
	var pen := physpen if dmg_type == "phys" else magpen
	var e_res := e.physres if dmg_type == "phys" else e.magres
	return dps * (1.0 - Stats.res_frac(maxf(0.0, e_res - pen)))


## Stun — or CONCUSSION: a CC-immune target (boss) takes the failed
## stun as bonus damage instead (duration x mult x ATK), so stun riders
## keep a boss-fight value without re-opening boss CC.
func _stun_or_concuss(e: Enemy, dur: float) -> void:
	if e is Boss:
		if not e.dying:
			e.take_damage(current_atk() * dur * Balance.CONCUSSION_MULT,
				(e.global_position - global_position).normalized())
	else:
		e.apply_stun(dur)


func _enemies_within(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and not e.untargetable \
				and center.distance_to(e.global_position) <= radius:
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


## A single faint gust streak, trailing BEHIND a speed-buffed run (round
## 44): the "this buff is live" tell for theme_speed. Kept very low-alpha
## and short — a whisper of wind, not a comet. `back` is the drift/lean
## direction (opposite travel).
func _wind_wisp(back: Vector2) -> void:
	var wisp := Sprite2D.new()
	wisp.texture = Art.tex("glow")
	wisp.modulate = Color(0.82, 0.94, 1.0, 0.13)  # pale, barely-there
	wisp.global_position = global_position + back * 16.0 + Vector2(0, -6)
	wisp.rotation = back.angle()
	wisp.scale = Vector2(1.3, 0.32)               # stretched along the gust
	wisp.z_index = -4                              # behind the hero
	game.add_child(wisp)
	var tw := wisp.create_tween()
	tw.tween_property(wisp, "global_position", wisp.global_position + back * 26.0, 0.4)
	tw.parallel().tween_property(wisp, "modulate:a", 0.0, 0.4)
	tw.tween_callback(wisp.queue_free)


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
func _melee_arc(mult: float, reach: float, fx_name: String, effects := {}, style := "swing", snd := "slash") -> int:
	game.sfx(snd)
	melee_swing = 0.16
	melee_style = style
	var dir := aim_dir(220.0)
	melee_dir = dir
	if style == "stab":
		# The stab IS a single solid blade sliver (player reference art,
		# round 33): a white line with needle-sharp ends, there for a
		# beat, then gone. No glow stack — SOLID and striking. White is
		# the base; theme variants only change the color.
		var blade := Sprite2D.new()
		blade.texture = Art.tex("slashline")
		blade.modulate = _tcolor if _themed else Color(1, 1, 1)
		blade.rotation = dir.angle()
		# y thinned twice on playtest feedback (1.5 → 0.8 → 0.5): a razor
		# line, not a bar.
		blade.scale = Vector2(reach / 80.0, 0.5)
		blade.position = dir * reach * 0.35
		blade.z_index = 7
		add_child(blade)
		var tw := blade.create_tween()
		tw.tween_property(blade, "position", dir * reach * 0.58, 0.06) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.06)  # hold solid — the reference pose
		tw.tween_property(blade, "modulate:a", 0.0, 0.07)
		tw.tween_callback(blade.queue_free)
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
	var hits := 0
	for e in _enemies_within(global_position + dir * reach * 0.55, reach * 0.55):
		hit_enemy(e, mult, effects.duplicate())
		hits += 1
	return hits


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
	_proj(dir, mult, "arrow", 520.0)


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	_muzzle(dir, _tcolor if _themed else Color(1.0, 0.6, 0.2))
	# The Ice variant flies as a crystal lance, not a ball of fire.
	var tex := "icelance" if _tfx.get("pierce", 0) else "fireball"
	var p := _proj(dir, mult, tex, 440.0 * float(_tfx.get("proj_speed", 1.0)))
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if bolt_homing > 0.0:
		p.homing = true  # Seeker Winds (mage Wind talent): the bolt curves to its mark


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


func _tumble() -> void:
	game.sfx("blink")
	# Round 45: the outright 0.5s negate on a 6s cd was too forgiving —
	# safety belongs to positioning, not a free button. The immunity is
	# now a split-second PERFECT-DODGE window (skill-timed against a hit),
	# and the roll leaves the archer NIMBLE — a soft evasion buff covers
	# the reposition so an average pilot still has margin, not a wall.
	hurt_cd = maxf(hurt_cd, 0.1)
	dodge_time = 1.25
	dodge_amt = 0.20
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
	# The nova drinks the cold (round 23): restores 20% of MISSING
	# health and mana — the lower you run, the more it gives back. The
	# mage's short-range button carries UTILITY, not damage budget
	# (ranged kits can rarely connect close-range damage safely).
	gain_hp((max_hp - hp) * 0.2)  # nova drinks the cold — SHOW the mend
	if nova_regen > 0.0:
		# Rimeheart (mage talent): the cold keeps mending — a long, slow trickle
		# (recast RENEWS this window, never stacks the rate: spam ≠ more potency).
		nova_regen_time = 6.0
	mp = minf(max_mp, mp + (max_mp - mp) * 0.2)
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
		eff["knock_no_boss"] = 1  # mobs fly; bosses never get shove-kited
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 1.4 * f, eff.duplicate())


## Dash `dist` pixels in the move direction, damaging every enemy along
## the path. Used by mage Blink and assassin Shadow Dash — and because
## it HITS things, ability themes fully apply to it. Returns kill count
## (Phantom step refunds cooldown on kills).
## A connecting stab's blood surge (round 25): lifesteal up for 4s,
## scaling with MISSING health — low health is a resource.
func _grant_stab_surge() -> void:
	# Announce it once when it FIRST lights (a refresh mid-surge is silent —
	# the stab cadence is 0.3s); the crimson aura carries the rest.
	if stab_ls_time <= 0.0:
		game.spawn_text(global_position + Vector2(0, -52), "BLOOD SURGE", Color(0.95, 0.35, 0.4))
	stab_ls_time = 4.0
	stab_ls_amt = Balance.SURGE_LS_FLOOR + Balance.SURGE_LS_SCALE * (1.0 - hp / max_hp)


func _dash_strike(dist: float, mult: float, effects := {}, stab_rider := 0.0, iframe := 0.3) -> int:
	game.sfx("blink")
	var color := _tcolor if _themed else Color(0.6, 0.7, 1.0)
	var start := global_position
	global_position = game.clamp_to_zone(start + facing * dist, start)
	var end := global_position
	if iframe > 0.0:
		hurt_cd = maxf(hurt_cd, iframe)  # brief immunity while dashing
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
	var rider_hit := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		var lane := e.global_position.distance_to(closest)
		if lane <= 55.0:
			hit_enemy(e, mult, effects.duplicate())
			if stab_rider > 0.0:
				# First stroke on the victim: the dash blade itself
				# (round 36 — the pass-through finally LOOKS like a cut).
				_cut_flash(e.global_position, 0.65, _tcolor if _themed else Color(1, 1, 1))
			if e.dying or e.hp <= 0.0:
				kills += 1
		if stab_rider > 0.0 and lane <= 150.0 and not e.dying:
			# The dash carries the knife (rounds 26/29), and the knife
			# reaches FARTHER than the shoulder: a graze-pass NEXT to
			# the boss still lands the stab + blood surge — thread the
			# needle past the swing, cut, kite out already healing.
			# Round 32: the dash-stab gets BONUS range over the standing
			# stab (150px corridor vs 118px reach) — striking in stride
			# reaches deeper than planting your feet.
			# Round 40: the rider pays by DEPTH — inside the old 105px
			# corridor the cut lands full (1.0x); only the far bonus-
			# reach graze (105-150px) takes the discount. The surge is
			# identical at every depth.
			var rider_mult: float = (Balance.DASH_STAB_NEAR_MULT
				if lane <= Balance.DASH_STAB_NEAR_LANE else Balance.DASH_STAB_MULT)
			hit_enemy(e, rider_mult * stab_rider, {"stagger": 0.3})
			_grant_stab_surge()
			rider_hit = true
			# The rider's stroke, opposite diagonal: a graze shows ONE
			# cut; a full pass-through (lane + rider) crosses into an X.
			_cut_flash(e.global_position, -0.65, _tcolor if _themed else Color(1, 1, 1))
		if effects.get("graze_heal", 0) and lane > 55.0 and lane <= Balance.CHARGE_GRAZE_LANE and not e.dying:
			# Bulwark ram (round 44): the shield-charge mends on a NEAR
			# pass, not just a dead-center ram — like the assassin's safe-
			# range graze, charging PAST a boss (threading its swing) still
			# clips it for a lighter hit, and the heal rides that hit. A
			# direct ram (lane <= 55) already healed via the fx above.
			hit_enemy(e, mult * Balance.CHARGE_GRAZE_MULT, effects.duplicate())
			_cut_flash(e.global_position, 0.4, _tcolor if _themed else Color(0.7, 0.85, 1.0))
	if rider_hit:
		# The connect refunds the dash — the SKILL lever (round 46): a landed
		# cut claws the cd toward the connect floor (talent deepens the
		# refund); a whiff pays full, and gear cdr can't push below the floor.
		cds["a2"] = maxf(Balance.DASH_CONNECT_FLOOR,
			cds["a2"] * (1.0 - (Balance.DASH_REFUND + dash_refund)))
	return kills


## A single blade-sliver flash across a point — the universal "you
## were cut" mark (one diagonal per stroke; two strokes cross an X).
func _cut_flash(pos: Vector2, ang: float, color := Color(1, 1, 1)) -> void:
	var cut := Sprite2D.new()
	cut.texture = Art.tex("slashline")
	cut.modulate = color
	cut.global_position = pos
	cut.rotation = ang
	cut.scale = Vector2(1.1, 0.45)
	cut.z_index = 8
	game.add_child(cut)
	var tw := cut.create_tween()
	tw.tween_interval(0.08)
	tw.tween_property(cut, "modulate:a", 0.0, 0.1)
	tw.tween_callback(cut.queue_free)


func _blink() -> void:
	var eff := {"aoe": true}
	if _tfx.has("freeze_path"):
		eff["stun"] = float(_tfx["freeze_path"])  # Frostwalk
	var start := global_position
	# Round 45: iframe cut 0.3->0.1 (like the archer roll) — a perfect-dodge
	# window, not a sloppy blink-through. Safety now rides the DR cloak below.
	_dash_strike(190.0 * float(_tfx.get("dash_mult", 1.0)), 0.8, eff, 0.0, 0.1)
	# Fire leaves a burning wake on the ground; Ice a frozen one.
	if _themed and (_tfx.has("dot") or _tfx.has("freeze_path")):
		_floor_streak(start, global_position, _tcolor)
	if blink_dr > 0.0:
		# Arcane Ward (round 45): Blink no longer erases a hit — it wraps
		# the mage in magic for a beat, CUTTING incoming damage while the
		# window holds. Forgives a misstep; doesn't undo it.
		dr_time = blink_dr_dur
		dr_amt = blink_dr
		game.sfx("ward", 1.0, 0.0, -3.0)
		game.spawn_text(global_position + Vector2(0, -52), "WARD", Color(0.6, 0.9, 1.0))


func _meteor() -> void:
	_ult_sfx()
	var count := int(_tfx.get("meteors", 1))
	if count <= 1:
		# Fire / Ice: a single meteor on the aimed target.
		var target := auto_aim()
		_meteor_at(target.global_position if target else global_position + facing * 150.0)
	else:
		# Starfall (wind): comets fall in SEQUENCE on the lowest-health
		# priority. Stacked hits on one target diminish, but a target's DEATH
		# hands the next comet a fresh priority at FULL power (execute and
		# cascade) — it concentrates where Fire's Meteor spreads and burns.
		_starfall_comet(count, float(_tfx.get("stack_falloff", 0.4)), null, 0)
	# Wind ult TAILWIND: Blink and Frost Nova cool down quicker for a window —
	# tempo for tight rotations (Fire's Meteor still out-bursts and AoE-burns).
	if _tfx.has("haste_dur"):
		cast_haste_cdr = float(_tfx.get("haste_cdr", 0.0))
		cast_haste_time = float(_tfx.get("haste_dur", 5.0))
		game.spawn_text(global_position + Vector2(0, -60), "TAILWIND", Color(0.7, 1.0, 0.75))


## One comet of a Starfall, recursing through the previous comet's fall:
## seek the lowest-health target, diminish a repeat hit on the SAME target,
## but reset to FULL when the priority changes — a kill cascades the salvo
## onward at full power onto the next threat.
func _starfall_comet(remaining: int, falloff: float, last: Enemy, stack: int) -> void:
	if remaining <= 0 or dead:
		return
	var tgt := _lowest_hp_enemy(560.0)
	var scale := 1.0
	var pos: Vector2
	if tgt != null:
		if tgt == last:
			stack += 1
		else:
			stack = 0  # fresh priority (or cascade off a kill): full power
		scale = pow(falloff, stack)
		pos = tgt.global_position
	else:
		var a := auto_aim()
		pos = a.global_position if a else global_position + facing * 150.0
	_meteor_at(pos, scale, func() -> void:
		_starfall_comet(remaining - 1, falloff, tgt, stack))


## The lowest-health live enemy within range — Starfall's priority pick.
func _lowest_hp_enemy(radius: float) -> Enemy:
	var best: Enemy = null
	for e in _enemies_within(global_position, radius):
		if best == null or e.hp < best.hp:
			best = e
	return best


## `scale` diminishes a comet's damage (Starfall stacks on one target).
## `on_land` fires after the comet resolves — Starfall chains its next comet
## from here, so a kill is already registered when the next target is picked.
func _meteor_at(pos: Vector2, scale := 1.0, on_land := Callable()) -> void:
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
			eff["burn"] = current_atk() * 0.4 * float(fx_copy.get("burn_mult", 1.0)) * scale
			eff["aoe"] = true
			if fx_copy.has("freeze"):
				eff["stun"] = float(fx_copy["freeze"])  # glacial comet
			hit_enemy(e, 3.5 * float(fx_copy.get("dmg_mult", 1.0)) * scale, eff)
		if on_land.is_valid():
			on_land.call()
	)


func _shadow_dash(f := 1.0) -> void:
	# Excess cdr the dash's cd floor "eats" is redirected here — into the
	# dash-through HIT (never the surge) and a slightly snappier animation,
	# so an over-hasted assassin's spare cdr is never wasted (round 46).
	var eaten := _dash_cdr_conversion()
	melee_swing = 0.16 * (1.0 - minf(0.10, eaten * Balance.DASH_CDR_TO_ANIM))
	melee_style = "stab"
	melee_dir = facing
	# NO i-frame (round 43): a short-cd dash with immunity was too
	# abusable once the refund made it semi-spammable. The dodge is the
	# MOVEMENT itself; only the ult's all-in commit grants immunity.
	game.sfx("stab")
	var start := global_position
	# stab_rider passes the talent scale only — the depth-tiered damage
	# mult (near/far) is applied per victim inside _dash_strike. The eaten-cdr
	# bonus rides the HIT mult only, leaving the surge rider (stab_rider = f) clean.
	var dash_mult := 1.2 * f * (1.0 + eaten * Balance.DASH_CDR_TO_DMG)
	var kills := _dash_strike(210.0 * float(_tfx.get("dash_mult", 1.0)), dash_mult, {"stagger": 0.4}, f, 0.0)
	if s_passive() == "mirrorstep":
		_mirrorstep_guard(start)
	if _tfx.get("trail_mist", 0):
		# Poison: the dash line blooms into a toxic wake.
		_mist((start + global_position) / 2.0, 110.0, 0.3, _tcolor, 2.5)
	if kills > 0 and _tfx.has("kill_refund"):
		# Shadow: a kill refunds most of the cooldown — but still floored, so
		# even room-chaining never drops into sub-second strobe territory.
		cds["a2"] = maxf(Balance.DASH_CONNECT_FLOOR,
			cds["a2"] * (1.0 - float(_tfx["kill_refund"])))
		game.spawn_text(global_position + Vector2(0, -60), "PHANTOM", Color(0.7, 0.5, 1.0))


## Excess cdr past Shadow Dash's cd floor isn't wasted — this returns the
## seconds of cooldown the floor "eats" on a connecting dash, which feed the
## dash-HIT damage and a snappier animation (round 46). Assassin-only.
func _dash_cdr_conversion() -> float:
	var base_cd: float = Classes.ability(cls, "a2")["cd"]
	var whiff := maxf(Balance.DASH_WHIFF_FLOOR, base_cd * (1.0 - cdr))
	var refund: float = Balance.DASH_REFUND + dash_refund
	var unfloored := whiff * (1.0 - refund)
	return maxf(0.0, Balance.DASH_CONNECT_FLOOR - unfloored)


## Mirrorstep (assassin S weapon): a dash through fire turns aside nearby
## hostile projectiles — lashing their shooters back — and opens a brief
## window of reduced AoE damage. Offense-dodge for the storm you can't outrun;
## it rewards READING the volley and dashing INTO it, not free immunity.
func _mirrorstep_guard(start: Vector2) -> void:
	dash_guard_time = 0.25  # brief AoE damage-reduction while the dash reads
	var mid := (start + global_position) / 2.0
	var reach := start.distance_to(global_position) / 2.0 + 150.0
	for node in get_tree().get_nodes_in_group("projectiles"):
		var p := node as Projectile
		if p == null or p.friendly or mid.distance_to(p.global_position) > reach:
			continue
		var shooter := p.source_enemy as Enemy
		if is_instance_valid(shooter) and not shooter.dying:
			game.burst(shooter.global_position, Color(0.7, 0.5, 1.0), 6)
			hit_enemy(shooter, 0.8, {"aoe": true})
		game.burst(p.global_position, Color(0.7, 0.5, 1.0), 5)
		p.queue_free()


func _fan_of_knives(f := 1.0) -> void:
	game.sfx("knife", 1.55)  # short and SHARP — a dart leaving fingers
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.8, 0.85, 1.0))
	# The range damage is EARNED in close (round 37): thin chip on its
	# own, but the fan bites double while the stab surge runs.
	var surge_amp: float = Balance.KNIFE_SURGE_MULT if stab_ls_time > 0.0 else 1.0
	if _tfx.get("bloom", 0):
		# Poison: ONE venom blade that detonates into a toxin cloud
		# (chip-tuned: knives spam at stab cadence since round 25).
		var p := _proj(dir, Balance.KNIFE_BLOOM_MULT * surge_amp * f, "dart", 660.0)
		p.spin = false
		p.life = 0.45
		p.scale = Vector2(1.5, 1.5)
		p.fx["bloom_mist"] = 1
		p.fx["bloom_color"] = _tcolor
		return
	var count := int(_tfx.get("knives", 3))
	var step := float(_tfx.get("spread", 0.13))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), Balance.KNIFE_MULT * surge_amp * f, "dart", 760.0)
		p.spin = false
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
			# The mist IS the poison primitive: its ticks stack toxin.
			e.apply_toxin(_dot_dps(e, current_atk() * dps_mult), 1.2, Color(color, 1.0))
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
	# EXECUTION (round 34, player-designed from the LoL reference): the
	# world darkens and the X mark is SET — the prey takes +50% damage
	# for 5s and wears a floating X. Two living shadows of the assassin
	# converge THROUGH it in an X, slashing, then the assassin himself
	# appears BEHIND it and drives the killing stab home.
	_ult_sfx()
	game.hud.flash_screen(Color(0.35, 0.0, 0.1), 0.5, 0.8)
	game.burst(global_position, Color(0.5, 0.2, 0.5), 12)
	# Untouchable through the execution (round 18): longer than Shadow
	# Dash's 0.5s — commit to the kill, not to the chip damage.
	hurt_cd = maxf(hurt_cd, 0.8)
	target.vuln_time = 5.0
	_stun_or_concuss(target, 0.6)
	if _tfx.has("mark_dot"):
		# Poison: the mark itself rots the target (and stacks toxin).
		target.apply_toxin(_dot_dps(target, current_atk() * float(_tfx["mark_dot"])), 5.0, Color(0.5, 1.2, 0.5))
	game.spawn_text(target.global_position + Vector2(0, -60), "DEATH MARK", Color(1, 0.25, 0.3))
	_mark_overhead_x(target)
	_death_mark_execution(target, float(_tfx.get("execute", 0.0)))


## The floating X over a marked target's head: two crossed blade
## slivers riding the enemy (freed with it) for the mark's 5s window.
func _mark_overhead_x(target: Enemy) -> void:
	var x_mark := Node2D.new()
	x_mark.position = Vector2(0, -56)
	x_mark.z_index = 30
	for ang in [0.7, -0.7]:
		var stroke := Sprite2D.new()
		stroke.texture = Art.tex("slashline")
		stroke.modulate = Color(1.0, 0.2, 0.3, 0.95)
		stroke.rotation = ang
		stroke.scale = Vector2(0.4, 0.5)
		x_mark.add_child(stroke)
	target.add_child(x_mark)
	var tw := x_mark.create_tween().set_loops(5)
	tw.tween_property(x_mark, "position:y", -62.0, 0.5)
	tw.tween_property(x_mark, "position:y", -56.0, 0.5)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(x_mark):
		x_mark.queue_free()


## A living-shadow copy of the assassin dashing along a line.
func _shadow_ghost(from: Vector2, to: Vector2) -> void:
	if sprite == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.flip_h = to.x < from.x
	ghost.scale = sprite.scale
	ghost.global_position = from + sprite.position
	ghost.modulate = Color(0.3, 0.12, 0.4, 0.9)  # a shadow, not a man
	ghost.z_index = 6
	game.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "global_position", to + sprite.position, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.12)
	tw.tween_callback(ghost.queue_free)


## One execution slash across a point: the stab's slashline, red
## stroke over a white-hot core.
func _execution_slash(pos: Vector2, ang: float) -> void:
	for layer in 2:
		var rip := Sprite2D.new()
		rip.texture = Art.tex("slashline")
		rip.modulate = Color(1.0, 0.25, 0.35, 1.0) if layer == 0 else Color(1, 1, 1, 1.0)
		rip.global_position = pos
		rip.rotation = ang
		rip.scale = Vector2(2.0, 0.9) if layer == 0 else Vector2(1.7, 0.45)
		rip.z_index = 8 + layer
		game.add_child(rip)
		var rt := rip.create_tween()
		rt.tween_interval(0.1 if layer == 0 else 0.08)
		rt.tween_property(rip, "modulate:a", 0.0, 0.12)
		rt.tween_callback(rip.queue_free)


## The execution itself: two shadows converge through the prey in an
## X (a slash and a 0.7x true hit each), then the assassin blinks
## BEHIND it and lands the killing stab (1.3x true, via the real stab
## arc). Shadow theme: a survivor under 30% is finished on the spot.
func _death_mark_execution(target: Enemy, execute := 0.0) -> void:
	for diag in [Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
		if not is_instance_valid(target) or target.dying:
			return
		var tpos: Vector2 = target.global_position
		_shadow_ghost(tpos - diag * 150.0, tpos + diag * 150.0)
		_execution_slash(tpos, diag.angle())
		game.sfx("stab")
		game.shake(3.5)
		game.burst(tpos, Color(1.0, 0.2, 0.3), 10)
		hit_enemy(target, 0.7, {"type": "true"})
		await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(target) or target.dying:
		return
	# The real blade: appear on the FAR side of the prey and stab back
	# through it — the full stab visual, not a bolt-on flash.
	var from := global_position
	var behind := (target.global_position - from).normalized()
	global_position = game.clamp_to_zone(
		target.global_position + behind * 46.0, target.global_position)
	_afterimages(from, global_position, Color(0.6, 0.25, 0.6), 3)
	game.shake(6.0)
	_melee_arc(1.3, 118.0, "slash", {"type": "true"}, "stab", "stab")
	if execute > 0.0 and is_instance_valid(target) and not target.dying \
			and target.hp < target.max_hp * 0.3:
		game.spawn_text(target.global_position + Vector2(0, -70), "EXECUTED", Color(1, 0.15, 0.25))
		game.burst(target.global_position, Color(0.6, 0.2, 0.6), 16)
		hit_enemy(target, execute, {"type": "true"})


