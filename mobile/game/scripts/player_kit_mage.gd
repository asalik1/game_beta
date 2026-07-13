extends "res://scripts/player_kit_archer.gd"
## PLAYER, layer 5 of 9 — the MAGE kit: dispatch + abilities.
## See player_core.gd for the chain layout.


func _use_mage(slot: String, f: float) -> void:
	match slot:
		"a1":
			# Round 45: Firebolt +25% — the glass cannon earns its damage
			# now that Blink no longer hands it a free negate (twin/splash
			# themes scale off this base, lifting Wind's ST and Fire's AoE).
			# Sync the bolt to the staff-thrust release, not the input frame —
			# the cast animation has a windup the FX was firing ahead of.
			await get_tree().create_timer(swing_delay(Balance.MAGE_BOLT_DELAY)).timeout
			if dead or downed or ghost:
				return
			if _tfx.get("twin", 0):
				# Wind: split the bolt.
				_cast_bolt(aim_dir().rotated(0.09), 0.94 * f)
				_cast_bolt(aim_dir().rotated(-0.09), 0.94 * f)
			else:
				_cast_bolt(aim_dir(), ability_coeff("a1") * f)
		"a2": _frost_nova(f)
		"a3": _blink()
		"ult": _meteor()


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	_muzzle(dir, _tcolor if _themed else Color(1.0, 0.6, 0.2))
	# The Ice variant flies as a crystal lance, not a ball of fire.
	var tex := "icelance" if _tfx.get("pierce", 0) else "fireball"
	var p := _proj(dir, mult, tex, 440.0 * float(_tfx.get("proj_speed", 1.0)))
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if _tfx.get("homing", 0):
		p.homing = true  # Wind firebolt SEEKS its mark — baseline wind behavior, no talent
	if bolt_bleed > 0.0 and ability_theme.get("a1", "") == "wind":
		# Wind Cuts (mage Wind talent): each bolt opens a bleed reckoned against
		# the WHOLE twin firebolt (both bolts, hence x2). One target just refreshes
		# a single wound (~+13% DPS); split the twin onto two foes and each bleeds
		# (~+26% total). Sized off atk here so ticks crit off the sheet like burn.
		p.fx["bleed"] = current_atk() * bolt_bleed * mult * 2.0


func _frost_nova(f := 1.0) -> void:
	if veil_shield > 0.0:
		# Permafrost (talent): the cast sheathes you in ice — a non-stacking
		# max-HP shield (Transfusion buffer rail; decays, never banks).
		shield = maxf(shield, max_hp * veil_shield)
	game.sfx("nova")
	game.shake(6.0)
	# The nova drinks the cold (round 23): restores 20% of MISSING
	# health and mana — the lower you run, the more it gives back. The
	# mage's short-range button carries UTILITY, not damage budget
	# (ranged kits can rarely connect close-range damage safely).
	var restore := rider("a2", "restore")
	gain_hp((max_hp - hp) * restore)  # nova drinks the cold — SHOW the mend
	if nova_regen > 0.0:
		# Rimeheart (mage talent): the cold keeps mending — a long, slow trickle
		# (recast RENEWS this window, never stacks the rate: spam ≠ more potency).
		nova_regen_time = 6.0
	mp = minf(max_mp, mp + (max_mp - mp) * restore)
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(0.45, 0.8, 1.0)
	var inward: bool = _tfx.get("pull", 0)
	var fiery: bool = _tfx.get("no_knock", 0)

	# Shockwave RING — expands for the blast, COLLAPSES for the implosion.
	var r_scale := radius / 24.0
	for delay in ([0.0, 0.07] if not inward else [0.0]):
		var ring := Sprite2D.new()
		ring.texture = Art.tex("ring")
		ring.modulate = Art.hdr(Color(col, 0.95))
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
		hit_enemy(e, ability_coeff("a2") * f, eff.duplicate())


func _blink() -> void:
	if veil_shield > 0.0:
		# Permafrost (talent): the cast sheathes you in ice — a non-stacking
		# max-HP shield (Transfusion buffer rail; decays, never banks).
		shield = maxf(shield, max_hp * veil_shield)
	var eff := {"aoe": true}
	if _tfx.has("freeze_path"):
		eff["stun"] = float(_tfx["freeze_path"])  # Frostwalk
	var start := global_position
	# Round 45: iframe cut 0.3->0.1 (like the archer roll) — a perfect-dodge
	# window, not a sloppy blink-through. Safety now rides the DR cloak below.
	_dash_strike(190.0 * float(_tfx.get("dash_mult", 1.0)), ability_coeff("a3"), eff, 0.0, rider("a3", "iframe"))
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
	spr.modulate = Art.hdr(col)  # the comet head burns past white — it blooms
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
		# The comet falls for 0.62s while the mage keeps casting — resolve the
		# impact with the CAST's payload snapshot, not whatever _tfx holds by
		# landing time (the Consecration save-restore idiom).
		var saved := _tfx
		_tfx = fx_copy
		for e in _enemies_within(pos, radius):
			var eff := fx_copy.duplicate()
			eff["burn"] = current_atk() * 0.4 * float(fx_copy.get("burn_mult", 1.0)) * scale
			eff["aoe"] = true
			if fx_copy.has("freeze"):
				eff["stun"] = float(fx_copy["freeze"])  # glacial comet
			hit_enemy(e, ability_coeff("ult") * float(fx_copy.get("dmg_mult", 1.0)) * scale, eff)
		# on_land BEFORE the restore: Starfall's next comet snapshots _tfx in
		# its own _meteor_at, so the whole salvo inherits the ULT's payload.
		if on_land.is_valid():
			on_land.call()
		_tfx = saved
	)
