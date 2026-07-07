extends "res://scripts/player_core.gd"
## PLAYER, layer 2 of 9 — targeting, hit resolution, and the shared
## combat primitives/juice every class kit leans on (melee arcs,
## projectiles, dashes, mists, beams). Class kits live in
## player_kit_<class>.gd; see player_core.gd for the chain layout.


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

	# Theme crit bonuses (and theme-line talents like Nightfall) are
	# CAP-EXEMPT (player rule 2026-07-06): they ride above the 35% knee
	# at full value — the built stat knees, the themed edge never does.
	var crit_exempt: float = effects.get("crit_bonus", 0.0)
	if void_crit > 0.0 and effects.get("crush", 0):
		crit_exempt += void_crit  # Nightfall (warlock): Void's crushing line crits more
	var result := Stats.resolve(current_atk() * mult, dmg_type,
		crit, crit_dmg, pen, dex, e_res, e.eva, e.critres, crit_exempt)
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
	# Rupture (warlock Void talent): anything you've displaced hard takes more
	# from EVERY hit — the payoff for choreographing shoves and pulls.
	if crush_amp > 0.0 and e.crush_t > 0.0:
		dmg *= 1.0 + crush_amp
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
	# Holy stance (paladin Conviction, round 48): every righteous blow mends —
	# the stance IS the sustain (AoE hits mend at a third, like lifesteal).
	if cls == "paladin" and paladin_mode == "holy":
		gain_hp(max_hp * Balance.PALADIN_HOLY_MEND * (0.33 if effects.get("aoe", false) else 1.0))

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
	if effects.has("shove") and not e.dying:
		# Void's light shove: opens the crush window every hit, but a boss is
		# barely moved (BOSS_SHOVE_FACTOR). The crush window is set DIRECTLY so
		# it fires regardless of how far the target actually slid.
		var sf: float = effects["shove"]
		e.knock = dir * (sf * Balance.BOSS_SHOVE_FACTOR if e is Boss else sf)
		e.crush_t = Balance.CRUSH_WINDOW
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
	ring.modulate = Art.hdr(Color(color, 0.9))
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
	fl.modulate = Art.hdr(Color(color, 0.85))
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


## Per-class ultimate activation sound, falling back to the generic one.
func _ult_sfx() -> void:
	var key := "ult_" + cls
	game.sfx(key if game.sounds.has(key) else "ult")


## A thin beam of light/darkness between two points, fading fast
## (hex tendrils, chain snaps, quick magical connections).
func _beam_fx(from: Vector2, to: Vector2, col: Color, width := 0.18) -> void:
	var seg := Sprite2D.new()
	seg.texture = Art.tex("glow")
	seg.modulate = Art.hdr(Color(col, 0.85))
	seg.global_position = (from + to) / 2.0
	seg.rotation = (to - from).angle()
	seg.scale = Vector2(maxf(0.5, from.distance_to(to) / 44.0), width)
	seg.z_index = 7
	game.add_child(seg)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale:y", 0.03, 0.22)
	tw.parallel().tween_property(seg, "modulate:a", 0.0, 0.24)
	tw.tween_callback(seg.queue_free)


## Dash `dist` pixels in the move direction, damaging every enemy along
## the path. Used by mage Blink, assassin Shadow Dash and the warrior's
## Shield Bash — and because it HITS things, ability themes fully apply
## to it. Returns kill count (Phantom step refunds cooldown on kills).
## A connecting stab's blood surge (round 25): lifesteal up for 4s,
## scaling with MISSING health — low health is a resource.
## (_grant_stab_surge lives HERE, not in the assassin layer: _dash_strike
## fires it for the dash-stab rider, and calls only flow derived→base.)
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
	game.dust(start + Vector2(0, 14), 4)  # kicked-up dust where you left
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
