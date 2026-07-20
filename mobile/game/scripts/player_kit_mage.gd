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
			var cast_delay := swing_delay(Balance.MAGE_BOLT_DELAY)
			var prelude_dir := aim_dir()
			var void_eyes: Array[Node2D] = []
			var crystal_focuses: Array[Node2D] = []
			if skin == "void_weaver":
				var eye_count := 2 if _tfx.get("twin", 0) else 1
				for i in eye_count:
					void_eyes.append(_spawn_void_cast_eye(prelude_dir, cast_delay))
			elif skin == "crystal_archmage":
				var crystal_count := 2 if _tfx.get("twin", 0) else 1
				for i in crystal_count:
					crystal_focuses.append(_spawn_crystal_cast_focus(prelude_dir, cast_delay))
			await get_tree().create_timer(cast_delay).timeout
			if dead or downed or ghost:
				for eye in void_eyes:
					_dismiss_void_eye(eye)
				for focus in crystal_focuses:
					_dismiss_crystal_focus(focus)
				return
			# Preserve the base spell's release-time targeting. The prelude may begin
			# earlier, but no skin is allowed to snapshot aim or alter behavior.
			var release_dir := aim_dir()
			if _tfx.get("twin", 0):
				# Wind: split the bolt.
				if skin == "void_weaver":
					_cast_void_eye_bolt(void_eyes[0], release_dir.rotated(0.09), 0.94 * f)
					_cast_void_eye_bolt(void_eyes[1], release_dir.rotated(-0.09), 0.94 * f)
				elif skin == "crystal_archmage":
					_cast_crystal_focus_bolt(crystal_focuses[0], release_dir.rotated(0.09), 0.94 * f)
					_cast_crystal_focus_bolt(crystal_focuses[1], release_dir.rotated(-0.09), 0.94 * f)
				else:
					_cast_bolt(release_dir.rotated(0.09), 0.94 * f)
					_cast_bolt(release_dir.rotated(-0.09), 0.94 * f)
			else:
				if skin == "void_weaver":
					_cast_void_eye_bolt(void_eyes[0], release_dir, ability_coeff("a1") * f)
				elif skin == "crystal_archmage":
					_cast_crystal_focus_bolt(crystal_focuses[0], release_dir, ability_coeff("a1") * f)
				else:
					_cast_bolt(release_dir, ability_coeff("a1") * f)
		"a2": _frost_nova(f)
		"a3": _blink()
		"ult": _meteor()


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	var bolt_col := _tcolor if _themed else Color(1.0, 0.6, 0.2)
	# Mage-skin bolts (Ronin pattern — the skin's magic wins over theme):
	# Void Weaver casts woven void; Crystal Archmage casts CRYSTAL — every
	# bolt flies as a lance of it, whatever the theme.
	if skin == "crystal_archmage":
		bolt_col = Color(0.80, 0.94, 1.00)
	_muzzle(dir, bolt_col)
	# Each identity owns a bolt silhouette: base flame dart, woven void spindle,
	# or hard crystal lance. Themes affect the muzzle and riders, not the body.
	var tex := "mage_firebolt"
	if skin == "crystal_archmage":
		tex = "mage_crystal_decree"
	elif _tfx.get("pierce", 0):
		tex = "icelance"
	var p := _proj(dir, mult, tex, 440.0 * float(_tfx.get("proj_speed", 1.0)))
	if skin == "crystal_archmage":
		_attach_crystal_prism_trail(p)
	_finish_mage_bolt(p, mult)


func _finish_mage_bolt(p: Projectile, mult: float) -> void:
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if _tfx.get("homing", 0):
		p.homing = true  # Wind firebolt SEEKS its mark — baseline wind behavior, no talent
	if bolt_bleed > 0.0 and ability_theme.get("a1", "") == "wind":
		# Wind Cuts (mage Wind talent): each bolt opens a bleed reckoned against
		# the WHOLE twin firebolt (both bolts, hence x2). One target just refreshes
		# a single wound (~+13% DPS); split the twin onto two foes and each bleeds
		# (~+26% total). Sized off atk here so ticks crit off the sheet like burn.
		p.fx["bleed"] = current_atk() * bolt_bleed * mult * 2.0


func _pick_void_eye_origin() -> Vector2:
	# Sample a ring around the caster and reject pockets already occupied by a
	# live Weaver-eye. The fallback is the clearest random pocket we inspected.
	var fallback := global_position + Vector2(52.0, -12.0)
	var best_clearance := -1.0
	for attempt in 14:
		var candidate := global_position + Vector2.from_angle(randf() * TAU) \
			* randf_range(46.0, 72.0)
		var clearance := 9999.0
		for node in get_tree().get_nodes_in_group("void_weaver_cast_eye"):
			if node is Node2D and is_instance_valid(node):
				clearance = minf(clearance, candidate.distance_to(node.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			fallback = candidate
		if clearance >= 52.0:
			return candidate
	return fallback


func _spawn_void_cast_eye(dir: Vector2, duration: float) -> Node2D:
	var eye := Node2D.new()
	eye.global_position = _pick_void_eye_origin()
	eye.add_to_group("void_weaver_cast_eye")
	game.add_child(eye)
	var spr := Sprite2D.new()
	spr.name = "Eye"
	spr.texture = Art.tex("fx/mage_void_cast_eye")
	spr.hframes = 8
	spr.frame = 0
	spr.position = Vector2(0, -30)
	spr.rotation = dir.angle()
	spr.scale = Vector2(0.58, 0.58)
	spr.modulate = Color(1.0, 1.0, 1.0, 0.96)
	spr.z_index = 10
	eye.add_child(spr)
	var form := spr.create_tween()
	var per := maxf(0.018, duration / 4.0)
	for frame in range(1, 5):
		form.tween_interval(per)
		form.tween_callback(spr.set_frame.bind(frame))
	return eye


func _cast_void_eye_bolt(eye: Node2D, intended_dir: Vector2, mult: float) -> Projectile:
	if eye == null or not is_instance_valid(eye):
		eye = _spawn_void_cast_eye(intended_dir, 0.0)
	var shot_dir := intended_dir.normalized()
	var eye_spr := eye.get_node_or_null("Eye") as Sprite2D
	game.sfx("fireball")
	var speed := 440.0 * float(_tfx.get("proj_speed", 1.0))
	# Physics are exactly base Firebolt: same player-relative muzzle, direction,
	# speed, life, collision and riders. Only the rendered container starts at
	# the eye and converges onto that unchanged trajectory.
	var p := _proj(shot_dir, mult, "mage_void_bullet", speed)
	_finish_mage_bolt(p, mult)
	var eye_center := eye.global_position + Vector2(0, -30)
	if eye_spr != null:
		eye_center = eye.to_global(eye_spr.position)
	var base_visual_origin := p.global_position + Vector2(0, -p.rise)
	var offset := eye_center - base_visual_origin
	var settle := clampf(offset.length() / maxf(speed, 1.0), 0.10, 0.22)
	p.set_visual_origin(eye_center, settle)
	if eye_spr != null:
		eye_spr.frame = 5
		var initial_visual_velocity := p.vel - offset / settle
		eye_spr.rotation = initial_visual_velocity.angle()
	p.visual_impact.connect(_dismiss_void_eye.bind(eye), CONNECT_ONE_SHOT)
	# Impact is the normal path, but room resets and projectile sweeps may free a
	# shot directly. Tree exit is unconditional; the eye's dismissal meta makes
	# both callbacks safely idempotent. The timer is a visual-only final fuse for
	# any future path that leaves a projectile alive with processing disabled.
	p.tree_exiting.connect(_dismiss_void_eye.bind(eye), CONNECT_ONE_SHOT)
	# Bind only the integer id to the long fuse. Capturing the eye object itself
	# makes Godot warn when normal impact cleanup frees it before this timer.
	get_tree().create_timer(p.life + 0.20).timeout.connect(
		_dismiss_void_eye_by_id.bind(eye.get_instance_id()), CONNECT_ONE_SHOT)
	return p


func _dismiss_void_eye_by_id(eye_id: int) -> void:
	var eye: Node2D = instance_from_id(eye_id) as Node2D
	if eye != null and is_instance_valid(eye):
		_dismiss_void_eye(eye)


func _dismiss_void_eye(eye: Node2D) -> void:
	if eye == null or not is_instance_valid(eye) or eye.get_meta("dismissing", false):
		return
	eye.set_meta("dismissing", true)
	var spr := eye.get_node_or_null("Eye") as Sprite2D
	if spr == null:
		eye.queue_free()
		return
	spr.frame = 6
	var close := spr.create_tween()
	close.tween_interval(0.045)
	close.tween_callback(spr.set_frame.bind(7))
	close.tween_property(spr, "modulate:a", 0.0, 0.12)
	close.tween_callback(eye.queue_free)


func _pick_crystal_focus_origin() -> Vector2:
	# The living Court chooses a clear pocket around its sovereign. Keep each
	# formation out of the others so Twin Firebolt reads as two judgments, not
	# one doubled sprite. Use an isolated RNG so cosmetic placement cannot
	# advance the gameplay random stream.
	var fallback := global_position + Vector2(50.0, -40.0)
	var best_clearance := -1.0
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.randomize()
	for attempt in 14:
		var candidate := global_position + Vector2.from_angle(visual_rng.randf() * TAU) \
			* visual_rng.randf_range(44.0, 68.0) + Vector2(0, -30)
		var clearance := 9999.0
		for node in get_tree().get_nodes_in_group("crystal_archmage_cast_focus"):
			if node is Node2D and is_instance_valid(node):
				clearance = minf(clearance, candidate.distance_to(node.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			fallback = candidate
		if clearance >= 46.0:
			return candidate
	return fallback


func _spawn_crystal_cast_focus(dir: Vector2, duration: float) -> Node2D:
	var focus := Node2D.new()
	focus.global_position = _pick_crystal_focus_origin()
	focus.add_to_group("crystal_archmage_cast_focus")
	game.add_child(focus)

	# The existing authored strip is the Court's full sentence: three separate
	# shards appear, click inward through a bright prism-spark, and lock into the
	# lance that will actually leave this exact point on the release frame.
	var spr := Sprite2D.new()
	spr.name = "Crystal"
	spr.texture = Art.tex("mage_crystal_decree")
	spr.hframes = 8
	spr.frame = 0
	spr.rotation = dir.angle()
	spr.scale = Vector2(0.46, 0.46)
	spr.modulate = Color(1.0, 1.0, 1.0, 0.96)
	spr.z_index = 10
	focus.add_child(spr)

	var aura := Sprite2D.new()
	aura.name = "Aura"
	aura.texture = Art.tex("glow")
	aura.scale = Vector2(0.58, 0.58)
	aura.modulate = Color(0.62, 0.88, 1.0, 0.16)
	aura.z_index = 9
	focus.add_child(aura)
	var pulse := aura.create_tween().set_loops()
	pulse.tween_property(aura, "modulate", Color(1.0, 0.54, 0.96, 0.30), 0.075)
	pulse.tween_property(aura, "modulate", Color(0.52, 0.94, 1.0, 0.16), 0.075)

	var form := spr.create_tween()
	var per := maxf(0.016, duration / 7.0)
	for frame in range(1, 8):
		form.tween_interval(per)
		form.tween_callback(spr.set_frame.bind(frame))
	return focus


func _cast_crystal_focus_bolt(focus: Node2D, intended_dir: Vector2,
		mult: float) -> Projectile:
	if focus == null or not is_instance_valid(focus):
		focus = _spawn_crystal_cast_focus(intended_dir, 0.0)
	var shot_dir := intended_dir.normalized()
	var crystal := focus.get_node_or_null("Crystal") as Sprite2D
	var crystal_center := focus.global_position
	if crystal != null:
		crystal.frame = 7
		crystal.rotation = shot_dir.angle()
		crystal_center = focus.to_global(crystal.position)

	game.sfx("fireball")
	var speed := 440.0 * float(_tfx.get("proj_speed", 1.0))
	# Exactly as with the Weaver eye, the projectile's physics still begins at
	# the base Firebolt muzzle. Only its rendered Court-lance begins at the
	# floating formation and folds onto the unchanged path.
	var p := _proj(shot_dir, mult, "mage_crystal_decree", speed, false)
	_finish_mage_bolt(p, mult)
	var base_visual_origin := p.global_position + Vector2(0, -p.rise)
	var offset := crystal_center - base_visual_origin
	var settle := clampf(offset.length() / maxf(speed, 1.0), 0.10, 0.22)
	p.set_visual_origin(crystal_center, settle)
	_attach_crystal_prism_trail(p)
	# Swap the assembled focus for the projectile on the same frame, making the
	# crystal itself launch rather than spawning a second bolt over it.
	if crystal != null:
		crystal.visible = false
	focus.remove_from_group("crystal_archmage_cast_focus")
	focus.queue_free()
	return p


func _attach_crystal_prism_trail(p: Projectile) -> void:
	var trail := ProjTrail.new()
	trail.proj = p
	trail.max_points = 15
	trail.width = 3.6
	trail.opacity = 0.90
	trail.draw_z = 8
	trail.segment_colors = [
		Color(1.0, 0.46, 0.92, 0.94),
		Color(1.0, 0.82, 0.34, 0.94),
		Color(0.38, 0.96, 1.0, 0.94),
		Color(0.62, 0.48, 1.0, 0.94),
	]
	trail.core_width = 0.72
	trail.core_opacity = 0.86
	trail.core_col = Color(0.96, 1.0, 1.0)
	game.add_child(trail)


func _dismiss_crystal_focus(focus: Node2D) -> void:
	if focus == null or not is_instance_valid(focus) or focus.get_meta("dismissing", false):
		return
	focus.set_meta("dismissing", true)
	focus.remove_from_group("crystal_archmage_cast_focus")
	var fade := focus.create_tween()
	fade.tween_property(focus, "scale", Vector2(0.35, 0.35), 0.10)
	fade.parallel().tween_property(focus, "modulate:a", 0.0, 0.10)
	fade.tween_callback(focus.queue_free)


## Play any generated eight-frame Mage strip. Frame ranges let Blink use the
## closing and opening halves separately while keeping one authored asset.
func _mage_sheet(tex_name: String, pos: Vector2, first: int, last: int,
		opts := {}) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = Art.tex(tex_name)
	spr.hframes = 8
	spr.frame = first
	var scl: float = opts.get("scale", 1.0)
	spr.scale = Vector2(scl, scl)
	spr.rotation = opts.get("rot", 0.0)
	spr.z_index = opts.get("z", 8)
	var alpha: float = opts.get("alpha", 1.0)
	spr.modulate = Color(1.0, 1.0, 1.0, alpha)
	var parent: Node = opts.get("parent", game)
	if parent == self:
		spr.position = pos
	else:
		spr.global_position = pos
	parent.add_child(spr)
	var frame_time: float = opts.get("frame_time", 0.045)
	var delay: float = opts.get("delay", 0.0)
	var hold: float = opts.get("hold", 0.0)
	var fade: float = opts.get("fade", 0.08)
	var step := 1 if last >= first else -1
	var frame := first + step
	var tw := spr.create_tween()
	if delay > 0.0:
		spr.modulate.a = 0.0
		tw.tween_interval(delay)
		tw.tween_property(spr, "modulate:a", alpha, 0.015)
	while (frame <= last if step > 0 else frame >= last):
		tw.tween_interval(frame_time)
		tw.tween_callback(spr.set_frame.bind(frame))
		frame += step
	if hold > 0.0:
		tw.tween_interval(hold)
	if fade > 0.0:
		tw.tween_property(spr, "modulate:a", 0.0, fade)
	tw.tween_callback(spr.queue_free)
	return spr


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
	# Skin novas ring in the skin's magic (skin wins over theme).
	if skin == "void_weaver":
		col = Color(0.60, 0.36, 0.96)
	elif skin == "crystal_archmage":
		col = Color(0.80, 0.94, 1.00)
	var inward: bool = _tfx.get("pull", 0)
	var fiery: bool = _tfx.get("no_knock", 0)
	if skin == "void_weaver":
		_void_weaver_nova_visual(radius, col)
		_apply_nova_gameplay(f, radius, inward, fiery)
		return
	elif skin == "crystal_archmage":
		_crystal_archmage_nova_visual(radius, col)
		_apply_nova_gameplay(f, radius, inward, fiery)
		return

	# Establish the cold with a hard ground mark before its shards move.
	var sigil := Sprite2D.new()
	sigil.texture = Art.tex("fx_frost_nova")
	sigil.modulate = Color(col, 0.9)
	sigil.scale = Vector2.ONE * (radius / 32.0)
	sigil.z_index = -4
	add_child(sigil)
	var sigil_tw := sigil.create_tween()
	sigil_tw.tween_property(sigil, "rotation", sigil.rotation - 0.3, 0.32)
	sigil_tw.parallel().tween_property(sigil, "modulate:a", 0.0, 0.5)
	sigil_tw.tween_callback(sigil.queue_free)

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

	_apply_nova_gameplay(f, radius, inward, fiery)


func _apply_nova_gameplay(f: float, radius: float, inward: bool, fiery: bool) -> void:
	# Mechanics remain shared and resolve on the original cast frame regardless
	# of how long a skin's presentation continues afterward.
	var eff := {"slow": 0.5, "slow_dur": 2.5, "aoe": true}
	if not (fiery or inward):
		eff["knock"] = 340.0
		eff["knock_no_boss"] = 1
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, ability_coeff("a2") * f, eff.duplicate())


func _void_weaver_nova_visual(radius: float, col: Color) -> void:
	# The authored strip performs the whole sentence: clockwise stitches appear,
	# the final knot closes, then the ring whips apart into needle-like strands.
	_mage_sheet("fx/mage_void_unravel", Vector2.ZERO, 0, 7, {
		"parent": self, "scale": 2.05 * radius / 160.0, "z": 8,
		"frame_time": 0.038, "fade": 0.10,
	})
	game.hud.flash_screen(Color(col, 1.0), 0.10, 0.20)


func _crystal_archmage_nova_visual(radius: float, col: Color) -> void:
	# A dense strict-overhead lotus forms radially beneath the sovereign rather
	# than being placed in front of her. The Archmage and dais render above its
	# ornate centre, while the final shard footprint stays inside the real nova
	# circle. Gameplay still resolves on the original cast frame.
	var lotus := Sprite2D.new()
	lotus.texture = Art.tex("fx/mage_crystal_lotus_nova")
	lotus.hframes = 8
	lotus.frame = 0
	lotus.global_position = global_position
	lotus.scale = Vector2.ONE * (radius / 90.0)
	lotus.modulate = Color(1.0, 1.0, 1.0, 0.98)
	lotus.z_index = -4
	game.add_child(lotus)

	# Five distinct assembly beats make the inner and outer petal rings readable;
	# frame 5 is the polished held flower, then 6/7 are authored shatter states.
	var bloom := lotus.create_tween()
	for frame in range(1, 6):
		bloom.tween_interval(0.030)
		bloom.tween_callback(lotus.set_frame.bind(frame))
	bloom.tween_interval(0.045)
	bloom.tween_callback(_crystal_lotus_shatter_beat.bind(col))
	bloom.tween_callback(lotus.set_frame.bind(6))
	bloom.tween_interval(0.060)
	bloom.tween_callback(lotus.set_frame.bind(7))
	bloom.tween_interval(0.090)
	bloom.tween_property(lotus, "modulate:a", 0.0, 0.16)
	bloom.tween_callback(lotus.queue_free)

	# A very soft reflected-light bed changes hue under the facets; the lotus
	# pixels provide the hard glints, while this supplies the floor reflection
	# requested without reverting to a generic visible nova ring.
	var reflection := Sprite2D.new()
	reflection.texture = Art.tex("glow")
	reflection.global_position = global_position
	reflection.scale = Vector2.ONE * (radius / 29.0)
	reflection.modulate = Color(col, 0.09)
	reflection.z_index = -5
	game.add_child(reflection)
	var reflected := reflection.create_tween()
	reflected.tween_property(reflection, "modulate", Color(0.92, 0.48, 1.0, 0.16), 0.13)
	reflected.tween_property(reflection, "modulate", Color(1.0, 0.82, 0.38, 0.12), 0.10)
	reflected.tween_property(reflection, "modulate:a", 0.0, 0.28)
	reflected.tween_callback(reflection.queue_free)


func _crystal_lotus_shatter_beat(col: Color) -> void:
	# Cosmetic punctuation only: damage/riders were already applied by the shared
	# Frost Nova path, preserving base timing, range and behavior for the skin.
	game.shake(3.0)
	game.hud.flash_screen(Color(col, 1.0), 0.08, 0.14)


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
	var finish := global_position
	if skin in ["void_weaver", "crystal_archmage"]:
		_mage_skin_blink_visual(start, finish)
	# Fire leaves a burning wake on the ground; Ice a frozen one.
	if skin == "" and _themed and (_tfx.has("dot") or _tfx.has("freeze_path")):
		_floor_streak(start, global_position, _tcolor)
	if blink_dr > 0.0:
		# Arcane Ward (round 45): Blink no longer erases a hit — it wraps
		# the mage in magic for a beat, CUTTING incoming damage while the
		# window holds. Forgives a misstep; doesn't undo it.
		dr_time = blink_dr_dur
		dr_amt = blink_dr
		game.sfx("ward", 1.0, 0.0, -3.0)
		game.spawn_text(global_position + Vector2(0, -52), "WARD", Color(0.6, 0.9, 1.0))


func _mage_skin_blink_visual(start: Vector2, finish: Vector2) -> void:
	if skin == "void_weaver":
		_void_weaver_blink_visual(start, finish)
		return
	_crystal_archmage_blink_visual(start, finish)


func _crystal_archmage_blink_visual(start: Vector2, _finish: Vector2) -> void:
	# Leave the exact live directional pose behind for the first instant, then
	# dissolve it through the authored crystal double. This removes the old
	# "facets close around an already absent body" pop at departure.
	var ghost := Sprite2D.new()
	if sprite != null and is_instance_valid(sprite):
		ghost.texture = sprite.texture
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.flip_h = sprite.flip_h
		ghost.offset = sprite.offset
		ghost.scale = sprite.scale
		ghost.modulate = sprite.modulate
		ghost.material = sprite.material
	ghost.global_position = start
	ghost.z_index = 9
	game.add_child(ghost)
	var ghost_fade := ghost.create_tween()
	ghost_fade.tween_interval(0.018)
	ghost_fade.tween_property(ghost, "modulate:a", 0.0, 0.070)
	ghost_fade.tween_callback(ghost.queue_free)

	var tex := "fx/mage_crystal_blink_shatter"
	var raised := Vector2(0, -50)
	# Departure loses body mass outward in four beats. Arrival is parented to the
	# real player, so continued movement cannot leave an invisible Mage walking
	# away from the reconstruction. The last crystal double holds its chest-wide
	# glint until the unchanged 0.145s reveal deadline, then fades behind her.
	_mage_sheet(tex, start + raised, 0, 3, {
		"scale": 0.64, "z": 10, "frame_time": 0.030, "fade": 0.045,
	})
	_mage_sheet(tex, raised, 4, 7, {
		"parent": self, "scale": 0.64, "z": 10, "frame_time": 0.030,
		"delay": 0.025, "hold": 0.030, "fade": 0.070,
	})
	if sprite != null and is_instance_valid(sprite):
		# player.gd owns modulate for hurt feedback, so visibility is the stable
		# disappearance gate while the crystal double carries her silhouette.
		sprite.visible = false
	if _skin_ambient != null and is_instance_valid(_skin_ambient):
		_skin_ambient.modulate.a = 0.0
	get_tree().create_timer(0.145).timeout.connect(func() -> void:
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = true
		if _skin_ambient != null and is_instance_valid(_skin_ambient):
			_skin_ambient.modulate.a = 1.0)


func _void_weaver_blink_visual(start: Vector2, finish: Vector2) -> void:
	# Mechanics move the body immediately, so leave a visual copy at departure
	# long enough for the first threads to visibly wrap it before the cocoon
	# contracts into nothing. Arrival reverses the same sheet around the hidden
	# real body and reveals it only as the final strands unwind.
	var ghost := Sprite2D.new()
	if sprite != null and is_instance_valid(sprite):
		ghost.texture = sprite.texture
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.flip_h = sprite.flip_h
		ghost.offset = sprite.offset
		ghost.scale = sprite.scale
		ghost.modulate = sprite.modulate
		ghost.material = sprite.material
	ghost.global_position = start
	ghost.z_index = 9
	game.add_child(ghost)
	var raised := Vector2(0, -42)
	_mage_sheet("fx/mage_void_thread_wrap", start + raised, 0, 7, {
		"scale": 0.56, "z": 10, "frame_time": 0.034, "fade": 0.05,
	})
	_mage_sheet("fx/mage_void_thread_wrap", finish + raised, 7, 0, {
		# Arrival is deliberately much snappier than departure. Blink movement is
		# already complete and input is live; a long hidden-body unwrap made a
		# moving mage appear invisible beside a cocoon left at the landing.
		"scale": 0.56, "z": 10, "frame_time": 0.018, "delay": 0.07,
		"fade": 0.05,
	})
	if sprite != null and is_instance_valid(sprite):
		# player.gd refreshes modulate for hurt feedback every frame, so alpha
		# cannot own this disappearance window. Visibility stays authoritative.
		sprite.visible = false
	if _skin_ambient != null and is_instance_valid(_skin_ambient):
		_skin_ambient.modulate.a = 0.0
	get_tree().create_timer(0.095).timeout.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free())
	# Reveal as soon as the destination cocoon starts opening. The remaining
	# frames play over the body as a presentation overlay, never as an input or
	# movement penalty tied to this skin.
	get_tree().create_timer(0.075).timeout.connect(func() -> void:
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = true
		if _skin_ambient != null and is_instance_valid(_skin_ambient):
			_skin_ambient.modulate.a = 1.0)


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
	# Skin comets: the Weaver calls down folded void; the Archmage a shard
	# of pure crystal (skin wins over theme, per the Ronin pattern).
	if skin == "void_weaver":
		col = Color(0.60, 0.36, 0.96)
	elif skin == "crystal_archmage":
		col = Color(0.78, 0.92, 1.00)
	if skin == "void_weaver":
		_void_weaver_ult_scene(pos, scale, on_land, fx_copy, col)
		return
	elif skin == "crystal_archmage":
		_crystal_archmage_ult_scene(pos, scale, on_land, fx_copy, col)
		return

	# Growing impact shadow on the ground — you can feel it coming.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.global_position = pos
	mark.modulate = Color(col, 0.5)
	mark.scale = Vector2(1, 1)
	mark.z_index = -6
	game.add_child(mark)
	var mark_tw := mark.create_tween()
	var base_radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
	var exact_mark_scale := base_radius / 32.0
	mark_tw.tween_property(mark, "scale", Vector2.ONE * exact_mark_scale, 0.62)

	# The base meteor itself: big, burning, with a particle trail. Skin scenes
	# returned above and never share this body or its impact language.
	var spr := Sprite2D.new()
	spr.texture = Art.tex("meteor_down")
	# This is the mage's signature impact: three times the former comet scale.
	spr.scale = Vector2(7.2, 7.2)
	spr.modulate = Art.hdr(col)
	# Vertical asset and vertical travel: the rock now falls straight down.
	spr.global_position = pos + Vector2(0, -460)
	spr.z_index = 30
	game.add_child(spr)
	# Brief world-space fire remnants mark the descent. They do not follow the
	# comet: each fades where it was shed, leaving a clean decaying light trail.
	for i in 5:
		get_tree().create_timer(0.09 * i).timeout.connect(func() -> void:
			if not is_instance_valid(spr):
				return
			var ember := Sprite2D.new()
			ember.texture = Art.tex("glow")
			ember.modulate = Art.hdr(Color(col, 0.72), 1.4)
			ember.global_position = spr.global_position + Vector2(0, -24)
			ember.scale = Vector2(0.34, 1.15)
			ember.z_index = 29
			game.add_child(ember)
			var ember_tw := ember.create_tween()
			ember_tw.tween_property(ember, "scale", Vector2(0.7, 2.8), 0.32)
			ember_tw.parallel().tween_property(ember, "modulate:a", 0.0, 0.38)
			ember_tw.tween_callback(ember.queue_free))
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
		var impact_flash := Color(1.0, 0.75, 0.4)
		var impact_pop := Color(1.0, 0.9, 0.5)
		game.hud.flash_screen(impact_flash, 0.55, 0.35)
		game.burst(pos, col, 30)
		game.burst(pos, impact_pop, 16)
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
			eff["true_frac"] = ability_true_frac("ult")  # Meteor: a quarter lands as true
			hit_enemy(e, ability_coeff("ult") * float(fx_copy.get("dmg_mult", 1.0)) * scale, eff)
		# on_land BEFORE the restore: Starfall's next comet snapshots _tfx in
		# its own _meteor_at, so the whole salvo inherits the ULT's payload.
		if on_land.is_valid():
			on_land.call()
		_tfx = saved
	)


func _mage_ult_mark(pos: Vector2, col: Color, radius: float) -> Sprite2D:
	# Retain a quiet hit-area telegraph for combat readability; the authored
	# sequence above it owns the fantasy and never changes the real radius.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.global_position = pos
	mark.modulate = Color(col, 0.30)
	mark.scale = Vector2(1.0, 1.0)
	mark.z_index = -6
	game.add_child(mark)
	var tw := mark.create_tween()
	# The procedural telegraph is exactly 64px wide: radius / 32 puts its rim
	# on the literal gameplay-radius boundary rather than merely near it.
	var exact_scale := radius / 32.0
	tw.tween_property(mark, "scale", Vector2.ONE * exact_scale, 0.62)
	return mark


func _void_weaver_ult_scene(pos: Vector2, hit_scale: float, on_land: Callable,
		fx_copy: Dictionary, col: Color) -> void:
	var radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
	var mark := _mage_ult_mark(pos, col, radius)
	mark.modulate = Color(0.58, 0.18, 0.94, 0.50)
	var floor_light := Sprite2D.new()
	floor_light.texture = Art.tex("glow")
	floor_light.global_position = pos
	var light_scale := radius / 24.0
	floor_light.scale = Vector2.ONE * light_scale * 0.50
	floor_light.modulate = Color(0.50, 0.10, 0.90, 0.22)
	floor_light.z_index = -5
	game.add_child(floor_light)
	var light_up := floor_light.create_tween()
	light_up.tween_property(floor_light, "scale", Vector2.ONE * light_scale, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	light_up.parallel().tween_property(floor_light, "modulate:a", 0.52, 0.26)
	light_up.tween_interval(0.22)
	light_up.tween_property(floor_light, "modulate:a", 0.0, 0.30)
	light_up.tween_callback(floor_light.queue_free)

	# One side-on strip only paints a wall across the far half of a top-down
	# circle. Lay five copies across circular chords instead: narrow at the back
	# and front, widest through the victim's feet. Together they fill the literal
	# telegraph footprint without changing the one real radius or damage query.
	var depth_bands := [-0.72, -0.36, 0.0, 0.36, 0.72]
	for band_index in depth_bands.size():
		_spawn_void_thread_band(pos, radius, depth_bands[band_index], band_index)
	get_tree().create_timer(0.62).timeout.connect(func() -> void:
		if is_instance_valid(mark):
			mark.queue_free()
		_resolve_mage_skin_ult(pos, hit_scale, on_land, fx_copy, col, "void"))


func _spawn_void_thread_band(center: Vector2, radius: float,
		depth_fraction: float, band_index: int) -> void:
	var chord_factor := sqrt(maxf(0.0, 1.0 - depth_fraction * depth_fraction))
	var diameter := radius * 2.0
	# At the ripping peak the authored visible field is ~224px wide inside its
	# 256px cell. Scale that content—not its transparent frame—to the circle's
	# exact chord at this depth.
	var scale_x := diameter * chord_factor / 224.0
	# Five full-height copies become an opaque curtain. Half-height bands still
	# rip well above combatants, but leave their separate ground origins readable.
	var scale_y := diameter / 256.0 * 0.52 * lerpf(0.82, 1.0, chord_factor)
	var ground := center + Vector2(0.0, depth_fraction * radius)
	var eruption := Sprite2D.new()
	eruption.texture = Art.tex("fx/mage_void_thread_eruption")
	eruption.hframes = 8
	eruption.frame = 0
	eruption.scale = Vector2(scale_x, scale_y)
	# Row 210 is the sheet's dense woven root line. Anchor that row—not the
	# transparent 256px cell edge—to this ground chord so threads visibly erupt
	# from beneath combatants instead of floating above their heads.
	eruption.global_position = ground + Vector2(0.0, -82.0 * scale_y)
	eruption.flip_h = band_index % 2 == 1
	var band_alpha := 0.78 if band_index == 2 else (0.62 if band_index in [1, 3] else 0.46)
	eruption.modulate = Color(1.0, 1.0, 1.0, band_alpha)
	eruption.z_index = -4
	game.add_child(eruption)
	var rip := eruption.create_tween()
	rip.tween_interval(0.30)
	rip.tween_callback(eruption.set_frame.bind(1))
	rip.tween_interval(0.07)
	rip.tween_callback(func() -> void:
		eruption.z_index = 11 + band_index
		eruption.frame = 2)
	for frame in [3, 4, 5]:
		rip.tween_interval(0.052)
		rip.tween_callback(eruption.set_frame.bind(frame))
	# Hold the ripping peak across the real 0.62s damage frame, then retract.
	rip.tween_interval(0.11)
	rip.tween_callback(eruption.set_frame.bind(6))
	rip.tween_interval(0.06)
	rip.tween_callback(eruption.set_frame.bind(7))
	rip.tween_property(eruption, "modulate:a", 0.0, 0.20)
	rip.tween_callback(eruption.queue_free)


func _crystal_archmage_ult_scene(pos: Vector2, hit_scale: float,
		on_land: Callable, fx_copy: Dictionary, col: Color) -> void:
	var radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
	var mark := _mage_ult_mark(pos, col, radius)
	var sequence := Sprite2D.new()
	sequence.texture = Art.tex("fx/mage_crystal_prism_lotus_ult")
	sequence.hframes = 8
	sequence.frame = 0
	sequence.global_position = pos
	# The fully opened lotus is about 156px across inside its frame. Scale that
	# authored footprint to the real diameter so its outer petals meet the exact
	# telegraph rim without inventing a second, cosmetic range.
	var scene_scale := radius / 78.0
	sequence.scale = Vector2.ONE * scene_scale
	sequence.z_index = 18
	game.add_child(sequence)
	var convene := sequence.create_tween()
	for beat in [
		[0.08, 1], # Four witnesses finish materializing.
		[0.11, 2], # The court begins its measured orbit.
		[0.11, 3], # Orbit accelerates.
		[0.12, 4], # All four prisms turn toward the condemned point.
		[0.10, 5], # Collision flash; this is anticipation, not the hit.
	]:
		convene.tween_interval(float(beat[0]))
		convene.tween_callback(sequence.set_frame.bind(int(beat[1])))
	# Keep Meteor's original 0.62s resolution exactly. The first fully formed
	# lotus is the judgment and therefore the only gameplay-impact frame.
	# Use the same explicit timer as the other skin instead of accumulating
	# presentation tween intervals: artwork can never move the damage deadline.
	get_tree().create_timer(0.62).timeout.connect(func() -> void:
		if not is_instance_valid(sequence):
			return
		if is_instance_valid(mark):
			mark.queue_free()
		sequence.frame = 6
		# The orbiting court remains readable above actors; its resulting sigil
		# belongs to the ground and cannot hide the condemned combatants.
		sequence.z_index = -4
		_resolve_mage_skin_ult(pos, hit_scale, on_land, fx_copy, col, "crystal")
		var dissolve := sequence.create_tween()
		# Hold the verdict long enough to read as a lotus on the impact itself;
		# only the later frame is the rapid refracted disintegration.
		dissolve.tween_interval(0.28)
		dissolve.tween_callback(sequence.set_frame.bind(7))
		dissolve.tween_property(sequence, "modulate:a", 0.0, 0.24)
		dissolve.tween_callback(sequence.queue_free))


func _resolve_mage_skin_ult(pos: Vector2, hit_scale: float, on_land: Callable,
		fx_copy: Dictionary, col: Color, kind: String) -> void:
	game.sfx("meteor")
	game.shake(14.0)
	if kind == "void":
		game.hud.flash_screen(Color(0.50, 0.20, 0.88), 0.18, 0.22)
	else:
		game.hud.flash_screen(Color(0.75, 0.90, 1.0), 0.27, 0.30)
	game.burst(pos, col, 10)
	var radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
	var saved := _tfx
	_tfx = fx_copy
	for e in _enemies_within(pos, radius):
		var eff := fx_copy.duplicate()
		eff["burn"] = current_atk() * 0.4 * float(fx_copy.get("burn_mult", 1.0)) * hit_scale
		eff["aoe"] = true
		if fx_copy.has("freeze"):
			eff["stun"] = float(fx_copy["freeze"])
		eff["true_frac"] = ability_true_frac("ult")
		hit_enemy(e, ability_coeff("ult") * float(fx_copy.get("dmg_mult", 1.0)) * hit_scale, eff)
	if on_land.is_valid():
		on_land.call()
	_tfx = saved
