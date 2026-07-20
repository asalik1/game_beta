extends "res://scripts/player_combat.gd"
## PLAYER, layer 3 of 9 — the WARRIOR kit: dispatch + abilities.
## See player_core.gd for the chain layout.


func _use_warrior(slot: String, f: float) -> void:
	match slot:
		"a1":
			# Cleave cycles its cut: diagonal, crescent down, crescent up
			# (see _melee_arc variants).
			var v := cleave_seq
			cleave_seq = (cleave_seq + 1) % 3
			# Sync the cut to the swing's contact frame — the sword windup means
			# FX/damage on the input frame read ahead of the animation.
			await get_tree().create_timer(swing_delay(Balance.WARRIOR_SWING_DELAY)).timeout
			if dead or downed or ghost:
				return
			_melee_arc(ability_coeff("a1") * f, 96.0, "slash", {"stagger": 0.35, "knock": 330.0}, "swing", "sword", v)
			if skin == "dreadknight":
				# A physical soul-cut rides the contact frame, rather than a red base
				# slash: the harvested spirits make the Blood Oath readable at a glance.
				var cut_dir := aim_dir(220.0)
				var soul_cut := Sprite2D.new()
				soul_cut.texture = Art.tex("fx_dread_soulcut")
				soul_cut.position = cut_dir * 34.0
				soul_cut.rotation = cut_dir.angle()
				soul_cut.scale = Vector2(1.25, 1.25)
				soul_cut.z_index = 8
				add_child(soul_cut)
				var cut_tw := soul_cut.create_tween()
				cut_tw.tween_property(soul_cut, "position", cut_dir * 82.0, 0.13).set_trans(Tween.TRANS_CUBIC)
				cut_tw.parallel().tween_property(soul_cut, "scale", Vector2(1.5, 1.5), 0.13)
				cut_tw.tween_interval(0.045)
				cut_tw.tween_property(soul_cut, "position", cut_dir * 20.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				cut_tw.parallel().tween_property(soul_cut, "modulate:a", 0.0, 0.14)
				cut_tw.tween_callback(soul_cut.queue_free)
			elif skin == "stormforged":
				# The storm blade discharges through the contact lane.
				_storm_conduct(aim_dir(220.0))
			if _tfx.get("quake", 0):
				# Earth: a stone shockwave rolls down the lane.
				var qdir := aim_dir(220.0)
				var quake := Projectile.spawn(game, global_position + qdir * 26.0, qdir * 300.0, 0.0, true, "slash")
				quake.hit_player_mult = 0.7 * f
				quake.source_player = self
				quake.fx = _tfx.duplicate()
				quake.pierce = true
				quake.life = 0.5
				quake.modulate = Color(0.85, 0.65, 0.35)
			if _tfx.get("wave2", 0):
				# Fury: a second backhand swing follows — the mirrored cut.
				var f2 := f
				var v2 := 2 - v
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * f2, 96.0, "slash", {"stagger": 0.2}, "swing", "sword", v2))
			if s_passive() == "kingsblade":
				var wave := Projectile.spawn(game, global_position + aim_dir(220.0) * 30.0, aim_dir(220.0) * 400.0, 0.0, true, "slash")
				wave.hit_player_mult = 0.6 * f
				wave.source_player = self
				wave.fx = _tfx.duplicate()
				wave.pierce = true
				wave.life = 0.6
		"a2":
			# Charge: ram through everything in your path, stunning it.
			melee_swing = 0.16
			game.sfx("slam")
			var charge_from := global_position
			# The ram parks you in the boss's face — a landing i-frame so the
			# gap-close itself isn't punished (round 44).
			_dash_strike(170.0 * float(_tfx.get("dash_mult", 1.0)), ability_coeff("a2") * f,
				{"stun": rider("a2", "stun"), "knock": 220.0}, 0.0, rider("a2", "iframe"), true)
			var charge_col := _tcolor if _themed else Color(0.85, 0.85, 0.95)
			if skin == "dreadknight":
				# Dreadknight: the ram leaves a wake of dread — solid blood-dark
				# ghosts down the line (the Ronin afterimage language, bled red).
				charge_col = Color(0.62, 0.10, 0.14)
				_torn_banner_wake(charge_from, global_position)
			elif skin == "stormforged":
				# Stormforged: the charge IS the bolt — electric ghosts and a
				# crackle of storm-light snapping back along the path.
				charge_col = Color(0.45, 0.75, 1.00)
				_storm_charge_break(charge_from, global_position)
			_ring_fx(global_position, charge_col, 80.0)
			if _tfx.get("end_slam", 0):
				# Earth: the charge ends in a ground-shattering slam.
				game.shake(5.0)
				game.sfx("slam", 0.8)
				game.burst(global_position, _tcolor, 14)
				_ring_fx(global_position, _tcolor, 130.0)
				for e in _enemies_within(global_position, 120.0):
					hit_enemy(e, 0.7 * f, {"stun": 1.0, "aoe": true})
		"a3": _whirlwind(f)
		"ult":
			berserk_time = float(_tfx.get("berserk_dur", 8.0))
			berserk_bonus = float(_tfx.get("berserk_dmg", 0.4))
			if _tfx.has("berserk_heal"):
				hp = minf(max_hp, hp + max_hp * float(_tfx["berserk_heal"]))
			if _tfx.has("berserk_guard"):
				theme_guard_time = berserk_time
				theme_guard_amt = float(_tfx["berserk_guard"])
			if _tfx.get("awaken_slam", 0):
				# Earth: the roar itself is seismic.
				for e in _enemies_within(global_position, 150.0):
					hit_enemy(e, 0.8 * f, {"stun": 2.0, "aoe": true})
			# Skin presentation of the rage (Ronin pattern — same roar, its
			# own colour of fury): Dreadknight goes black-red with rising soul
			# wisps; Stormforged detonates in storm-light with sky-bolts.
			var rage_col := _tcolor if _themed else Color(1.0, 0.3, 0.2)
			var rage_flash := Color(1.0, 0.25, 0.15)
			var rage_text := Color(1, 0.4, 0.3)
			if skin == "dreadknight":
				rage_col = Color(0.72, 0.10, 0.16)
				rage_flash = Color(0.40, 0.02, 0.08)
				rage_text = Color(0.95, 0.28, 0.30)
				_soul_wisps(global_position, Color(0.85, 0.18, 0.22))
			elif skin == "stormforged":
				rage_col = Color(0.50, 0.78, 1.00)
				rage_flash = Color(0.35, 0.60, 1.00)
				rage_text = Color(0.62, 0.85, 1.00)
				# The storm turns inward and inhabits the armour; no enemy-facing
				# sky strikes, because this buff is empowerment rather than an AoE.
			# The two skins stage their ult above the body: an oath-standard unfurls
			# behind Dreadknight, while Stormforged opens the eye of the tempest.
			if skin == "dreadknight":
				_dread_oath_sequence()
			elif skin == "stormforged":
				_storm_acceptance_sequence()
			else:
				var brand := Sprite2D.new()
				brand.texture = Art.tex("fx_berserk_brand")
				brand.modulate = Color(rage_col, 0.9)
				brand.scale = Vector2(1.45, 1.45)
				brand.z_index = 7
				add_child(brand)
				var brand_tw := brand.create_tween()
				brand_tw.tween_property(brand, "scale", brand.scale * 1.28, 0.25)
				brand_tw.parallel().tween_property(brand, "modulate:a", 0.0, 0.38)
				brand_tw.tween_callback(brand.queue_free)
			_ring_fx(global_position, rage_col,
				(72.0 if skin in ["dreadknight", "stormforged"] else (150.0 if _tfx.get("awaken_slam", 0) else 110.0)))
			_ult_sfx()
			game.shake(6.0)
			game.hud.flash_screen(rage_flash, 0.22 if skin in ["dreadknight", "stormforged"] else 0.4, 0.4)
			if not skin in ["dreadknight", "stormforged"]:
				game.burst(global_position, rage_col, 20)
			game.spawn_text(global_position + Vector2(0, -60), "BERSERK!", rage_text)


func _whirlwind(f := 1.0) -> void:
	game.sfx("sword")
	var radius := 115.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(1, 1, 1)
	# Skin cyclones carry the skin's colour over theme (Ronin pattern).
	if skin == "dreadknight":
		col = Color(0.85, 0.16, 0.20)
	elif skin == "stormforged":
		col = Color(0.52, 0.80, 1.00)
		# The spin whips up a static charge — one crackle arcing off the blades.
		var arc_a := global_position + Vector2.from_angle(randf_range(0.0, TAU)) * radius
		var arc_b := global_position + Vector2.from_angle(randf_range(0.0, TAU)) * radius
		_beam_fx(arc_a, arc_b, Color(0.70, 0.88, 1.0), 0.12)
	var inward: bool = _tfx.get("pull", 0)

	# Three blades sweep a full revolution around the hero (reversed
	# when Earth drags enemies in — the vortex visibly turns inward).
	var pivot := Node2D.new()
	pivot.z_index = 6
	add_child(pivot)
	for i in 3:
		var ang := TAU * i / 3.0
		var blade := Sprite2D.new()
		blade.texture = Art.tex("fx_dread_greatsword" if skin == "dreadknight" else "fx_whirl_blade")
		blade.modulate = Color.WHITE if skin == "dreadknight" else Color(col, 0.9)
		blade.rotation = ang
		# Dread greatswords enter the formation one-by-one; Storm blades
		# begin wide and dim, gathering charge during their first revolution.
		blade.position = Vector2.from_angle(ang) * radius * (1.18 if skin in ["dreadknight", "stormforged"] else 0.55)
		blade.scale = Vector2(1.18, 1.18) if skin == "dreadknight" else Vector2(1.45, 1.45)
		if skin in ["dreadknight", "stormforged"]:
			blade.modulate.a = 0.0
		pivot.add_child(blade)
		if skin in ["dreadknight", "stormforged"]:
			var enter := blade.create_tween()
			enter.tween_interval(0.075 * i)
			enter.tween_property(blade, "modulate:a", 0.95, 0.06)
			enter.parallel().tween_property(blade, "position", Vector2.from_angle(ang) * radius * 0.55, 0.14).set_trans(Tween.TRANS_CUBIC)
	var tw := pivot.create_tween()
	var spin_dur := 0.58 if skin == "stormforged" else (0.46 if skin == "dreadknight" else 0.32)
	tw.tween_property(pivot, "rotation", TAU * (-1.0 if inward else 1.0), spin_dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "modulate:a", 0.0, spin_dur + 0.05).set_delay(spin_dur * 0.55)
	tw.tween_callback(pivot.queue_free)
	if skin == "stormforged":
		get_tree().create_timer(0.27).timeout.connect(func() -> void:
			if dead:
				return
			_ring_fx(global_position, Color(0.68, 0.9, 1.0), radius)
			for i in 3:
				var a := TAU * float(i) / 3.0
				_beam_fx(global_position + Vector2.from_angle(a) * 24.0, global_position + Vector2.from_angle(a) * radius, Color(0.72, 0.92, 1.0), 0.12))
	_ring_fx(global_position, col, radius, inward)

	var eff := {"stagger": 0.3, "aoe": true}
	if not inward:  # Earth drags them in instead of flinging
		eff["knock"] = 380.0
	# Round 49 AoE pass: 0.9 -> 1.0 — the cyclone is the warrior's whole
	# pack answer and it trailed the field.
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, ability_coeff("a3") * f, eff.duplicate())


func _storm_conduct(dir: Vector2) -> void:
	# Three charge beads visibly run down the weapon before the forward leap.
	for i in 3:
		var bead := Sprite2D.new()
		bead.texture = Art.tex("glow")
		bead.modulate = Art.hdr(Color(0.72, 0.94, 1.0, 0.9))
		bead.position = dir * (12.0 + i * 7.0) + dir.orthogonal() * (i - 1) * 4.0
		bead.scale = Vector2(0.14, 0.14)
		bead.z_index = 9
		add_child(bead)
		var tw := bead.create_tween()
		tw.tween_interval(0.035 * i)
		tw.tween_property(bead, "position", dir * 72.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bead, "scale", Vector2(0.28, 0.28), 0.12)
		tw.tween_property(bead, "modulate:a", 0.0, 0.08)
		tw.tween_callback(bead.queue_free)
	get_tree().create_timer(0.11).timeout.connect(func() -> void:
		var contact := global_position + dir * 62.0
		_beam_fx(contact, contact + dir * 68.0, Color(0.72, 0.92, 1.0), 0.11))


func _torn_banner_wake(start: Vector2, finish: Vector2) -> void:
	for i in 4:
		var scrap := Sprite2D.new()
		scrap.texture = Art.tex("fx_dread_banner")
		scrap.global_position = start.lerp(finish, (float(i) + 0.35) / 4.4) + Vector2(0, -28)
		scrap.modulate = Color(0.65, 0.12, 0.17, 0.48)
		scrap.scale = Vector2(0.18, 0.42)
		scrap.z_index = 3
		game.add_child(scrap)
		var tw := scrap.create_tween()
		tw.tween_property(scrap, "rotation", (-0.28 if i % 2 == 0 else 0.28), 0.12)
		tw.tween_property(scrap, "rotation", (0.18 if i % 2 == 0 else -0.18), 0.13)
		tw.parallel().tween_property(scrap, "modulate:a", 0.0, 0.3)
		tw.tween_callback(scrap.queue_free)


func _storm_charge_break(start: Vector2, finish: Vector2) -> void:
	sprite.modulate.a = 0.16
	var span := finish - start
	var prev := start
	for i in 4:
		var next := start.lerp(finish, float(i + 1) / 4.0) + span.normalized().orthogonal() * (7.0 if i % 2 == 0 else -7.0)
		_beam_fx(prev, next, Color(0.66, 0.9, 1.0), 0.16)
		prev = next
	game.burst(finish, Color(0.75, 0.94, 1.0), 10)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if not dead and sprite != null:
			sprite.modulate.a = 1.0
			game.burst(global_position, Color(0.55, 0.8, 1.0), 8))


func _dread_oath_sequence() -> void:
	var banner := Sprite2D.new()
	banner.texture = Art.tex("fx_dread_banner")
	banner.position = Vector2(-27, -56)
	banner.scale = Vector2(0.08, 1.55)
	# The source standard is deliberately black-red; lift its red material so
	# the unfurl remains legible against both grave ground and the dark armour.
	banner.modulate = Color(1.55, 0.68, 0.72, 0.0)
	banner.z_index = -1
	add_child(banner)
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 0.9, 0.08)
	tw.parallel().tween_property(banner, "scale:x", 1.55, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.78)
	tw.tween_property(banner, "modulate:a", 0.18, 0.32)
	tw.tween_callback(banner.queue_free)
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		for off in [-18.0, -6.0, 7.0, 19.0]:
			_beam_fx(global_position + Vector2(off, -70), global_position + Vector2(off * 0.35, -22), Color(0.74, 0.12, 0.18), 0.32))


func _storm_acceptance_sequence() -> void:
	var eye := Sprite2D.new()
	eye.texture = Art.tex("fx_storm_eye")
	eye.position = Vector2(0, -94)
	eye.scale = Vector2(0.18, 0.18)
	eye.modulate = Color(1, 1, 1, 0.0)
	eye.z_index = 8
	add_child(eye)
	var tw := eye.create_tween()
	tw.tween_property(eye, "modulate:a", 0.9, 0.08)
	tw.parallel().tween_property(eye, "scale", Vector2(1.8, 1.8), 0.22).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.48)
	tw.tween_property(eye, "position", Vector2(0, -24), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(eye, "scale", Vector2(0.18, 0.18), 0.18)
	tw.tween_callback(eye.queue_free)
	_staged_segment_ring(self, Vector2(0, -22), Color(0.66, 0.9, 1.0, 0.88), 76.0, 3, 0.12, 0.32, "slashline", true, true)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		_ring_fx(global_position, Color(0.62, 0.86, 1.0), 68.0)
		for i in 3:
			var a := TAU * float(i) / 3.0
			_beam_fx(global_position + Vector2.from_angle(a) * 62.0, global_position + Vector2(0, -18), Color(0.7, 0.92, 1.0), 0.2))


## Dreadknight's harvest read: slow soul-wisps rising off the ground around
## the knight (the warlock hex-wisp idiom, bled dread-red). Pure FX.
func _soul_wisps(pos: Vector2, col: Color) -> void:
	var wisps := CPUParticles2D.new()
	wisps.amount = 20
	wisps.lifetime = 1.0
	wisps.one_shot = true
	wisps.explosiveness = 0.5
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = 90.0
	wisps.direction = Vector2(0, -1)
	wisps.spread = 18.0
	wisps.gravity = Vector2(0, -80)
	wisps.initial_velocity_min = 20.0
	wisps.initial_velocity_max = 55.0
	wisps.scale_amount_min = 1.5
	wisps.scale_amount_max = 3.0
	wisps.color = Color(col, 0.85)
	wisps.global_position = pos
	game.add_child(wisps)
	get_tree().create_timer(1.5).timeout.connect(wisps.queue_free)
