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
				_afterimages(charge_from, global_position, Color(0.55, 0.07, 0.12), 4, 0.045, 0.30, true)
			elif skin == "stormforged":
				# Stormforged: the charge IS the bolt — electric ghosts and a
				# crackle of storm-light snapping back along the path.
				charge_col = Color(0.45, 0.75, 1.00)
				_afterimages(charge_from, global_position, Color(0.40, 0.70, 1.00), 4, 0.040, 0.26, true)
				_beam_fx(charge_from, global_position, Color(0.62, 0.85, 1.0), 0.13)
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
				for i in 3:
					var strike := global_position + Vector2(randf_range(-70, 70), randf_range(-40, 40))
					_beam_fx(strike + Vector2(randf_range(-40, 40), -320), strike, Color(0.72, 0.90, 1.0), 0.12)
			_ring_fx(global_position, rage_col,
				150.0 if _tfx.get("awaken_slam", 0) else 110.0)
			_ult_sfx()
			game.shake(6.0)
			game.hud.flash_screen(rage_flash, 0.4, 0.4)
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
	# Round 49 AoE pass: 0.9 -> 1.0 — the cyclone is the warrior's whole
	# pack answer and it trailed the field.
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, ability_coeff("a3") * f, eff.duplicate())


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
