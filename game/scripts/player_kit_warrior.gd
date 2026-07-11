extends "res://scripts/player_combat.gd"
## PLAYER, layer 3 of 9 — the WARRIOR kit: dispatch + abilities.
## See player_core.gd for the chain layout.


func _use_warrior(slot: String, f: float) -> void:
	match slot:
		"a1":
			# Cleave cycles its cut: diagonal, crescent down, crescent up —
			# a blade leads each arc (see _melee_arc variants).
			var v := cleave_seq
			cleave_seq = (cleave_seq + 1) % 3
			# Sync the cut to the swing's contact frame — the sword windup means
			# FX/damage on the input frame read ahead of the animation.
			await get_tree().create_timer(Balance.WARRIOR_SWING_DELAY).timeout
			if dead or downed or ghost:
				return
			_melee_arc(1.0 * f, 96.0, "slash", {"stagger": 0.35, "knock": 330.0}, "swing", "sword", v)
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
			# The ram parks you in the boss's face — a landing i-frame so the
			# gap-close itself isn't punished (round 44).
			_dash_strike(170.0 * float(_tfx.get("dash_mult", 1.0)), 1.3 * f,
				{"stun": 1.3, "knock": 220.0}, 0.0, Balance.MELEE_DASH_IFRAME, true)
			_ring_fx(global_position, _tcolor if _themed else Color(0.85, 0.85, 0.95), 80.0)
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
			_ring_fx(global_position, _tcolor if _themed else Color(1.0, 0.3, 0.2),
				150.0 if _tfx.get("awaken_slam", 0) else 110.0)
			_ult_sfx()
			game.shake(6.0)
			game.hud.flash_screen(Color(1.0, 0.25, 0.15), 0.4, 0.4)
			game.burst(global_position, Color(1.0, 0.3, 0.2), 20)
			game.spawn_text(global_position + Vector2(0, -60), "BERSERK!", Color(1, 0.4, 0.3))


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
	# Round 49 AoE pass: 0.9 -> 1.0 — the cyclone is the warrior's whole
	# pack answer and it trailed the field.
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 1.0 * f, eff.duplicate())
