extends "res://scripts/player_kit_assassin.gd"
## PLAYER, layer 7 of 9 — the PALADIN kit: dispatch + abilities.
## (_light_pillar/_smite_rip live here; player.gd's take_damage and the
## Dawnbreaker S-passive call DOWN into them, which the chain allows.)
## See player_core.gd for the chain layout.


func _use_paladin(slot: String, f: float) -> void:
	match slot:
		"a1":
			# Judgment CLOSES (round 22) — but the leap is a RIDER with its
			# own cooldown (round 48): the hammer swings every 0.5s, the leap
			# only arms every JUDGMENT_LEAP_CD. The old >95px gate blocked
			# point-blank spam but a RANGED pilot leapt (and i-framed) on
			# every cast — dash out, leap back, ~90% immunity. Now dodging a
			# telegraph is footwork; the leap is the once-in-a-while answer.
			var j_tgt := auto_aim(300.0)
			if j_tgt and judgment_leap_cd <= 0.0 \
					and global_position.distance_to(j_tgt.global_position) > 95.0:
				judgment_leap_cd = Balance.JUDGMENT_LEAP_CD
				var j_from := global_position
				global_position = game.clamp_to_zone(
					j_tgt.global_position + (global_position - j_tgt.global_position).normalized() * 58.0,
					j_tgt.global_position)
				_afterimages(j_from, global_position, Color(1.0, 0.9, 0.55), 3)
				game.sfx("slam", 1.4)
				# Landing i-frame rides the LEAP only (round 44) — and the
				# leap's own cd now caps it at once per 5s, the sanctioned
				# gap-closer pattern (same as warrior Charge).
				hurt_cd = maxf(hurt_cd, Balance.MELEE_DASH_IFRAME)
				hurt_was_heavy = true  # landing i-frame blocks heavy telegraph hits too
			var jeff := {"stagger": 0.3, "knock": 280.0}
			if s_passive() == "dawnbreaker":
				# A pillar of light falls with the hammer.
				jeff["splash"] = maxf(float(_tfx.get("splash", 0.0)), 0.5)
				jeff["burn"] = current_atk() * 0.3
				_light_pillar(global_position + aim_dir(220.0) * 70.0,
					_tcolor if _themed else Color(1.0, 0.95, 0.6))
			_melee_arc(1.0 * f, 92.0, "slash", jeff, "swing", "sword")
			# The hammer lands with weight: a golden shock at the impact.
			var jdir := aim_dir(220.0)
			_ring_fx(global_position + jdir * 58.0,
				_tcolor if _themed else Color(1.0, 0.9, 0.55), 34.0)
			if _tfx.get("wave2", 0):
				# Wrath: a burning backswing follows.
				var jf2 := f
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * jf2, 92.0, "slash", {"stagger": 0.2}, "swing", "sword"))
		"a2": _consecration(f)
		"a3": _aegis()
		"ult": _conviction_swap(f)


## A shaft of light stabs down from the sky and blooms where it lands.
## The Dawnbreaker pillar, Consecration's judgment on each victim.
func _light_pillar(pos: Vector2, col := Color(1.0, 0.95, 0.6), width := 0.9) -> void:
	var shaft := Sprite2D.new()
	shaft.texture = Art.tex("glow")
	shaft.modulate = Art.hdr(Color(col, 0.0))
	shaft.global_position = pos + Vector2(0, -120)
	shaft.scale = Vector2(width, 5.5)
	shaft.z_index = 8
	game.add_child(shaft)
	var tw := shaft.create_tween()
	tw.tween_property(shaft, "modulate:a", 0.85, 0.06)
	tw.parallel().tween_property(shaft, "global_position:y", pos.y - 95.0, 0.06)
	tw.tween_property(shaft, "modulate:a", 0.0, 0.24)
	tw.tween_callback(shaft.queue_free)
	_ring_fx(pos, col, 46.0 * width)
	game.burst(pos, col, 6)


## A bright slash rips across a smitten enemy (Aegis retaliation).
func _smite_rip(pos: Vector2, col: Color) -> void:
	var rip := Sprite2D.new()
	rip.texture = Art.tex("glow")
	rip.modulate = Art.hdr(Color(col, 0.95))
	rip.global_position = pos
	rip.rotation = randf_range(0.0, TAU)
	rip.scale = Vector2(2.0, 0.13)
	rip.z_index = 8
	game.add_child(rip)
	var tw := rip.create_tween()
	tw.tween_property(rip, "scale:y", 0.03, 0.12)
	tw.parallel().tween_property(rip, "modulate:a", 0.0, 0.14)
	tw.tween_callback(rip.queue_free)


## Consecration: sanctify the ground where you stand — two waves of holy
## fire, and every enemy struck MENDS you (heal-on-hit is the identity).
func _consecration(f := 1.0) -> void:
	var radius := 150.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(1.0, 0.9, 0.5)
	var pos := global_position
	var fx_copy := _tfx.duplicate()
	var fmul := f
	_consecration_pulse(pos, radius, 0.9 * f, col, fx_copy)
	# The ground stays sanctified: a second wave erupts moments later.
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if dead:
			return
		var saved := _tfx
		_tfx = fx_copy
		_consecration_pulse(pos, radius, 0.7 * fmul, col, fx_copy)
		_tfx = saved)


func _consecration_pulse(pos: Vector2, radius: float, mult: float, col: Color, fx: Dictionary) -> void:
	game.sfx("nova", 0.75)
	_ring_fx(pos, col, radius)
	game.burst(pos, col, 12)
	# Hallowed floor glow that lingers a moment.
	var floor_glow := Sprite2D.new()
	floor_glow.texture = Art.tex("glow")
	floor_glow.modulate = Color(col, 0.45)
	floor_glow.scale = Vector2(radius / 24.0, radius / 32.0)
	floor_glow.global_position = pos
	floor_glow.z_index = -5
	game.add_child(floor_glow)
	var ft := floor_glow.create_tween()
	ft.tween_property(floor_glow, "modulate:a", 0.0, 0.8)
	ft.tween_callback(floor_glow.queue_free)
	# Rising motes of light.
	var motes := CPUParticles2D.new()
	motes.amount = 18
	motes.lifetime = 0.7
	motes.one_shot = true
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector2(0, -1)
	motes.spread = 15.0
	motes.gravity = Vector2(0, -60)
	motes.initial_velocity_min = 20.0
	motes.initial_velocity_max = 60.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.0
	motes.color = Color(col, 0.9)
	motes.global_position = pos
	game.add_child(motes)
	get_tree().create_timer(1.2).timeout.connect(motes.queue_free)

	# A halo of light shards sweeps around the sanctified ring.
	var halo := Node2D.new()
	halo.global_position = pos
	halo.z_index = 5
	game.add_child(halo)
	for i in 8:
		var shard := Sprite2D.new()
		shard.texture = Art.tex("glow")
		shard.modulate = Art.hdr(Color(col, 0.75))
		shard.position = Vector2.from_angle(TAU * i / 8.0) * radius * 0.85
		shard.rotation = TAU * i / 8.0 + PI / 2.0
		shard.scale = Vector2(0.9, 0.26)
		halo.add_child(shard)
	var ht := halo.create_tween()
	ht.tween_property(halo, "rotation", TAU * 0.4, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ht.parallel().tween_property(halo, "modulate:a", 0.0, 0.6)
	ht.tween_callback(halo.queue_free)

	var eff := {"aoe": true}
	eff["heal"] = maxf(0.025, float(fx.get("heal", 0.0)))
	if fx.get("pull", 0):
		eff["pull"] = 1
	for e in _enemies_within(pos, radius):
		# Judgment answers each sinner personally: a small light shaft.
		_light_pillar(e.global_position, col, 0.5)
		hit_enemy(e, mult, eff.duplicate())


## Aegis: raise the shield — massive resistances for a beat, and whoever
## strikes you is smitten in return (see take_damage).
func _aegis() -> void:
	game.sfx("equip")
	aegis_time = float(_tfx.get("aegis_dur", 2.5))
	aegis_amt = float(_tfx.get("aegis_amt", 110.0))
	aegis_reflect = float(_tfx.get("aegis_reflect", 0.6))
	aegis_proj_left = Balance.AEGIS_PROJ_CAP  # arrows answered per cast
	aegis_fx = _tfx.duplicate()
	var col := _tcolor if _themed else Color(0.7, 0.85, 1.0)
	_ring_fx(global_position, col, 95.0)
	game.burst(global_position, col, 10)
	game.spawn_text(global_position + Vector2(0, -60), "AEGIS", col)
	# The ward is VISIBLE: four motes of light orbit the hero while the
	# shield holds, then gutter out.
	var orbit := Node2D.new()
	orbit.z_index = 6
	add_child(orbit)
	for i in 4:
		var mote := Sprite2D.new()
		mote.texture = Art.tex("glow")
		mote.modulate = Art.hdr(Color(col, 0.85), 1.6)  # gentle: they orbit for seconds
		mote.position = Vector2.from_angle(TAU * i / 4.0) * 34.0
		mote.scale = Vector2(0.42, 0.42)
		orbit.add_child(mote)
	var spin := orbit.create_tween()
	spin.set_loops()
	spin.tween_property(orbit, "rotation", TAU, 1.1).as_relative()
	get_tree().create_timer(aegis_time).timeout.connect(func() -> void:
		if is_instance_valid(orbit):
			spin.kill()
			var fade := orbit.create_tween()
			fade.tween_property(orbit, "modulate:a", 0.0, 0.25)
			fade.tween_callback(orbit.queue_free))
	if _tfx.has("aegis_heal"):
		# Holy: lowering the shield releases the blessing.
		var frac: float = _tfx["aegis_heal"]
		get_tree().create_timer(aegis_time).timeout.connect(func() -> void:
			if not dead:
				hp = minf(max_hp, hp + max_hp * frac)
				game.sfx("potion")
				game.burst(global_position, Color(1.0, 0.95, 0.6), 12)
				game.spawn_text(global_position + Vector2(0, -50), "+%d" % int(max_hp * frac), Color(0.5, 1.0, 0.5)))


## Conviction (round 48): the paladin's "ult" is a STANCE SWAP, not a nuke —
## Holy (blows mend, -20% dmg) <-> Retribution (+25% dmg, no mending). Each
## swap is a cast with impact: entering Retribution drags the field to the
## hammer (the old Chains, scaled down); returning to Holy releases a
## blessing. The 8s cd kills flicker-toggling for double-dipped swap effects.
func _conviction_swap(f := 1.0) -> void:
	if paladin_mode == "holy":
		paladin_mode = "retribution"
		game.spawn_text(global_position + Vector2(0, -64), "RETRIBUTION", Color(1.0, 0.45, 0.25))
		game.hud.flash_screen(Color(1.0, 0.4, 0.15), 0.3, 0.3)
		# The wrath announces itself: chains drag the field in for the verdict.
		_chains_of_wrath(f * Balance.PALADIN_SWAP_CHAINS)
		# Chains' no-target early-out resets the ult cd to 1s (fine for the old
		# nuke, an exploit for a stance: swap-swap at range = free 10% heals
		# every ~2s). The SWAP always pays its full cooldown.
		cds["ult"] = maxf(cds["ult"], ability_cd("ult"))
	else:
		paladin_mode = "holy"
		game.sfx("mend", 1.0, 0.0, -2.0)
		game.spawn_text(global_position + Vector2(0, -64), "HOLY", Color(1.0, 0.92, 0.55))
		game.hud.flash_screen(Color(1.0, 0.9, 0.5), 0.25, 0.3)
		_ring_fx(global_position, Color(1.0, 0.92, 0.55), 130.0)
		game.burst(global_position, Color(1.0, 0.95, 0.7), 14)
		# The blessing: a burst of mending and a brief guard to cover the
		# retreat into the defensive stance.
		gain_hp(max_hp * Balance.PALADIN_SWAP_HEAL)
		theme_guard_time = 2.5
		theme_guard_amt = 60.0


## Chains of Wrath: tether every nearby enemy, DRAG them to the hammer,
## then the verdict lands on the pile. Since round 48 this is the impact
## of the Retribution swap, not a standalone ult.
func _chains_of_wrath(f := 1.0) -> void:
	var radius := 320.0 * float(_tfx.get("radius_mult", 1.0))
	# Only chain enemies in YOUR room — the drag tweens straight through
	# geometry, so a mob on the far side of a wall used to get yanked into it
	# (then wedge against the wall trying to reach you). Same-room keeps the
	# pull honest.
	var my_room := game.room_at_pos(global_position)
	var targets := _enemies_within(global_position, radius).filter(
		func(e: Node) -> bool: return game.room_at_pos((e as Node2D).global_position) == my_room)
	if targets.is_empty():
		cds["ult"] = 1.0
		return
	_ult_sfx()
	game.shake(7.0)
	game.hud.flash_screen(Color(1.0, 0.85, 0.4), 0.4, 0.35)
	var col := _tcolor if _themed else Color(1.0, 0.85, 0.45)
	_ring_fx(global_position, col, radius, true)
	game.spawn_text(global_position + Vector2(0, -64), "CHAINS OF WRATH", Color(1, 0.8, 0.4))
	if _tfx.has("chain_guard"):
		# Aegis: the chains anchor YOU.
		theme_guard_time = 3.0
		theme_guard_amt = float(_tfx["chain_guard"])
	var fx_copy := _tfx.duplicate()
	var heal_frac := float(_tfx.get("chain_heal", 0.0))
	var fmul := f
	for node in targets:
		var e := node as Enemy
		_chain_link_fx(e.global_position, col)
		_stun_or_concuss(e, 1.2)
		var dir := (e.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var dest: Vector2 = game.clamp_to_zone(global_position + dir * 70.0, e.global_position)
		var tw := e.create_tween()
		tw.tween_property(e, "global_position", dest, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The hammer of verdict falls from the sky while the chains reel in.
	var hammer := Sprite2D.new()
	hammer.texture = Art.tex("w_hammer")
	hammer.modulate = Color(1.0, 0.95, 0.7)
	hammer.scale = Vector2(7, 7)
	hammer.global_position = global_position + Vector2(0, -320)
	hammer.z_index = 30
	game.add_child(hammer)
	var htw := hammer.create_tween()
	htw.tween_property(hammer, "global_position", global_position + Vector2(0, -18), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The verdict lands once the drag finishes.
	get_tree().create_timer(0.34).timeout.connect(func() -> void:
		if is_instance_valid(hammer):
			hammer.queue_free()
		if dead:
			return
		game.sfx("slam")
		game.shake(9.0)
		game.hud.flash_screen(Color(1.0, 0.9, 0.5), 0.35, 0.3)
		_light_pillar(global_position, col, 1.4)
		game.burst(global_position, col, 24)
		game.burst(global_position, Color(1, 1, 1), 10)
		_ring_fx(global_position, col, 150.0)
		var saved := _tfx
		_tfx = fx_copy
		for e2 in _enemies_within(global_position, 150.0):
			_smite_rip(e2.global_position, col)
			hit_enemy(e2, 2.2 * fmul, {"aoe": true, "stun": 0.5})
			if heal_frac > 0.0:
				gain_hp(max_hp * heal_frac)  # holy chains: each drag mends, SHOWN
		_tfx = saved)


## A taut chain of REAL links snapping from the hero to a tethered enemy,
## then reeling inward with the drag.
func _chain_link_fx(to: Vector2, col: Color) -> void:
	var span := to - global_position
	var links := maxi(3, int(span.length() / 26.0))
	for i in links:
		var t := (i + 0.5) / float(links)
		var link := Sprite2D.new()
		link.texture = Art.tex("ring")
		link.modulate = Color(col, 0.95)
		link.global_position = global_position + span * t
		link.rotation = span.angle()
		link.scale = Vector2(0.24, 0.15)  # a squashed ring reads as a link
		link.z_index = 7
		game.add_child(link)
		var tw := link.create_tween()
		# Links reel in with the catch, vanishing as they arrive.
		tw.tween_property(link, "global_position", global_position + span * t * 0.2, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(link, "modulate:a", 0.0, 0.3)
		tw.tween_callback(link.queue_free)
	# The taut line itself flashes once as the chain snaps home.
	_beam_fx(global_position, to, col, 0.14)
