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
				_afterimages(j_from, global_position, _pal_skin_col(Color(1.0, 0.9, 0.55)), 3)
				game.sfx("slam", 1.4)
				# Landing i-frame rides the LEAP only (round 44) — and the
				# leap's own cd now caps it at once per 5s, the sanctioned
				# gap-closer pattern (same as warrior Charge).
				hurt_cd = maxf(hurt_cd, Balance.MELEE_DASH_IFRAME)
				hurt_was_heavy = true  # landing i-frame blocks heavy telegraph hits too
			var jeff := {"stagger": 0.3, "knock": 280.0}
			var dawn := s_passive() == "dawnbreaker"
			if dawn:
				jeff["splash"] = maxf(float(_tfx.get("splash", 0.0)), 0.5)
				jeff["burn"] = current_atk() * 0.3
			# Sync the impact to the warhammer's slam: the heavy overhead swing
			# has a real windup, so the shock/pillar/hit land WITH the hammer,
			# not on the input frame (which read ahead of the animation).
			await get_tree().create_timer(swing_delay(Balance.PALADIN_SMITE_DELAY)).timeout
			if dead or downed or ghost:
				return
			if dawn:
				# A pillar of light falls with the hammer.
				_light_pillar(global_position + aim_dir(220.0) * 70.0,
					_tcolor if _themed else Color(1.0, 0.95, 0.6))
			# Holy Charge -> a heavier hammer: spend the banked overheal as bonus
			# smite damage folded into THIS Judgment (flat, so it crits/mitigates
			# like the swing). current_atk cancels — the smite lands as holy_charge*f.
			var jcoeff := ability_coeff("a1")
			if holy_charge > 0.0 and current_atk() > 0.0:
				jcoeff += holy_charge / current_atk()
				holy_charge = 0.0
				game.spawn_text(global_position + Vector2(0, -50), "SMITE", Color(1.0, 0.95, 0.6))
			_melee_arc(jcoeff * f, 92.0, "slash", jeff, "swing", "sword")
			# The hammer lands with weight: a golden shock at the impact.
			# Eclipse Knight's shock is the CORONA — a dark inner ring inside
			# the gold one (the eclipse read); the Arbiter's shock is cold.
			var jdir := aim_dir(220.0)
			var jcol := _tcolor if _themed else Color(1.0, 0.9, 0.55)
			jcol = _pal_skin_col(jcol)
			_ring_fx(global_position + jdir * 58.0, jcol, 34.0)
			if skin == "eclipse_knight":
				_ring_fx(global_position + jdir * 58.0, Color(0.30, 0.16, 0.45), 20.0)
			if skin == "eclipse_knight":
				_eclipse_judgment(global_position + jdir * 58.0)
			elif skin == "fallen_arbiter" and j_tgt != null and is_instance_valid(j_tgt):
				_staged_segment_ring(j_tgt, Vector2(0, -20), Color(0.92, 0.94, 1.0, 0.9), 34.0, 7, 0.035, 0.3, "slashline", true, true)
			if skin == "eclipse_knight" or skin == "fallen_arbiter":
				var judgment_seal := Sprite2D.new()
				judgment_seal.texture = Art.tex("fx_eclipse_corona" if skin == "eclipse_knight" else "fx_fallen_verdict")
				judgment_seal.global_position = global_position + jdir * 58.0
				judgment_seal.scale = Vector2(0.5, 0.5)
				judgment_seal.z_index = 7
				game.add_child(judgment_seal)
				var judgment_tw := judgment_seal.create_tween()
				judgment_tw.tween_property(judgment_seal, "scale", Vector2(1.05, 1.05), 0.18)
				judgment_tw.parallel().tween_property(judgment_seal, "modulate:a", 0.0, 0.24)
				judgment_tw.tween_callback(judgment_seal.queue_free)
			if _tfx.get("wave2", 0):
				# Wrath: a burning backswing follows.
				var jf2 := f
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * jf2, 92.0, "slash", {"stagger": 0.2}, "swing", "sword"))
		"a2": _consecration(f)
		"a3": _aegis()
		"ult": _conviction_swap(f)


## Paladin skin signature light (Ronin pattern — the skin's light wins over
## theme): Eclipse Knight burns corona-gold with dark accents; the Fallen
## Arbiter's light has gone COLD — pale silver, no warmth left in it.
func _pal_skin_col(base: Color) -> Color:
	if skin == "eclipse_knight":
		return Color(1.00, 0.70, 0.25)
	if skin == "fallen_arbiter":
		return Color(0.90, 0.92, 1.00)
	return base


func _eclipse_judgment(pos: Vector2) -> void:
	var core := Sprite2D.new()
	core.texture = Art.tex("glow")
	core.global_position = pos
	core.modulate = Color(0.08, 0.03, 0.13, 0.88)
	core.scale = Vector2(1.2, 1.2)
	core.z_index = 7
	game.add_child(core)
	_staged_segment_ring(game, pos, Color(1.0, 0.72, 0.28, 0.94), 25.0, 2, 0.075, 0.18, "slashline", false, true)
	var tw := core.create_tween()
	tw.tween_interval(0.17)
	tw.tween_property(core, "scale", Vector2(0.35, 0.35), 0.12)
	tw.parallel().tween_property(core, "modulate:a", 0.0, 0.14)
	tw.tween_callback(core.queue_free)


func _eclipse_conviction_scene(targets: Array) -> void:
	var disc := Sprite2D.new()
	disc.texture = Art.tex("fx_eclipse_corona")
	disc.position = Vector2(0, -34)
	disc.scale = Vector2(0.18, 1.28)
	disc.modulate = Color(1, 1, 1, 0.0)
	disc.z_index = 8
	add_child(disc)
	var tw := disc.create_tween()
	tw.tween_property(disc, "modulate:a", 0.92, 0.07)
	tw.parallel().tween_property(disc, "scale:x", 1.28, 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.26)
	tw.tween_property(disc, "scale:y", 0.08, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(disc, "scale", Vector2(1.48, 1.48), 0.16).set_trans(Tween.TRANS_BACK)
	tw.tween_property(disc, "modulate:a", 0.0, 0.28)
	tw.tween_callback(disc.queue_free)
	for node in targets:
		var e := node as Enemy
		if e != null:
			_living_tether(e, self, Color(1.0, 0.68, 0.24, 0.82), 0.62, false)


func _arbiter_tribunal_scene(targets: Array) -> void:
	for node in targets:
		var e := node as Enemy
		if e == null:
			continue
		_staged_segment_ring(e, Vector2.ZERO, Color(0.92, 0.94, 1.0, 0.9), 38.0, 6, 0.035, 0.46, "slashline", true, true)
		_living_tether(e, self, Color(0.9, 0.93, 1.0, 0.86), 0.72, false)
	# The verdict blade is authored as three cold pieces that align before the
	# existing gameplay hammer resolves on the pile.
	for i in 3:
		var piece := Sprite2D.new()
		piece.texture = Art.tex("fx_hammer_fallen")
		piece.global_position = global_position + Vector2((i - 1) * 42.0, -230 - abs(i - 1) * 22.0)
		piece.modulate = Color(0.94, 0.96, 1.0, 0.0)
		piece.scale = Vector2(1.1, 1.1)
		piece.z_index = 29
		game.add_child(piece)
		var tw := piece.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(piece, "modulate:a", 0.78, 0.06)
		tw.parallel().tween_property(piece, "global_position:x", global_position.x, 0.2).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(0.1)
		tw.tween_property(piece, "modulate:a", 0.0, 0.12)
		tw.tween_callback(piece.queue_free)


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
	var col := _pal_skin_col(_tcolor if _themed else Color(1.0, 0.9, 0.5))
	var fx_copy := _tfx.duplicate()
	var fmul := f
	# Land the nova on the warhammer's slam frame, not the input frame.
	await get_tree().create_timer(swing_delay(Balance.PALADIN_SMITE_DELAY)).timeout
	if dead or downed or ghost:
		return
	var pos := global_position
	_consecration_pulse(pos, radius, ability_coeff("a2") * f, col, fx_copy)
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
	if skin == "eclipse_knight":
		_staged_segment_ring(game, pos, Color(1.0, 0.7, 0.25, 0.88), radius * 0.82, 10, 0.045, 0.36, "slashline", true, false)
	elif skin == "fallen_arbiter":
		_staged_segment_ring(game, pos, Color(0.92, 0.94, 1.0, 0.9), radius * 0.72, 8, 0.04, 0.42, "slashline", true, true)
	# Hallowed floor seal lingers a moment: sunfire for base, a bleeding corona
	# for Eclipse, and a frozen verdict sigil for the Fallen Arbiter.
	var floor_glow := Sprite2D.new()
	var ground_tex := "fx_consecration"
	if skin == "eclipse_knight":
		ground_tex = "fx_eclipse_corona"
	elif skin == "fallen_arbiter":
		ground_tex = "fx_fallen_verdict"
	floor_glow.texture = Art.tex(ground_tex)
	floor_glow.modulate = Color(col, 0.45)
	floor_glow.scale = Vector2.ONE * (radius / 32.0)
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
	if skin == "eclipse_knight":
		col = Color(0.55, 0.38, 0.85)  # the ward is the dark of the disc
	elif skin == "fallen_arbiter":
		col = Color(0.88, 0.92, 1.00)
	_ring_fx(global_position, col, 95.0)
	game.burst(global_position, col, 10)
	game.spawn_text(global_position + Vector2(0, -60), "AEGIS", col)
	# The ward is an actual shield crest, with four smaller plates orbiting it;
	# Eclipse carries a dark seal and the Fallen Arbiter a cold rune instead.
	var ward_tex := "fx_aegis"
	if skin == "eclipse_knight":
		ward_tex = "fx_eclipse_corona"
	elif skin == "fallen_arbiter":
		ward_tex = "fx_fallen_verdict"
	var ward := Sprite2D.new()
	ward.texture = Art.tex(ward_tex)
	# The ward is a translucent full-body barrier, lifted to the chest rather
	# than a small crest at the feet.
	ward.position = Vector2(0, -34)
	ward.modulate = Color(col, 0.68 if skin == "eclipse_knight" else 0.42)
	ward.scale = Vector2(2.15, 2.35) if ward_tex == "fx_aegis" else Vector2(1.7, 1.7)
	ward.z_index = 6
	add_child(ward)
	var ward_tw := ward.create_tween()
	ward_tw.tween_property(ward, "scale", ward.scale * 1.12, 0.22)
	get_tree().create_timer(aegis_time).timeout.connect(func() -> void:
		if is_instance_valid(ward):
			ward.queue_free())
	# Four physical ward plates orbit while the shield holds, then gutter out.
	var orbit := Node2D.new()
	# Center the orbit on the whole body, not the feet/torso origin.
	orbit.position = Vector2(0, -34)
	orbit.z_index = 6
	add_child(orbit)
	var orbit_tex := "fx_aegis"
	if skin == "eclipse_knight":
		orbit_tex = "fx_eclipse_corona"
	elif skin == "fallen_arbiter":
		orbit_tex = "fx_fallen_verdict"
	for i in 4:
		var mote := Sprite2D.new()
		mote.texture = Art.tex(orbit_tex)
		mote.modulate = Art.hdr(Color(col, 0.95), 1.45)
		var plate_ang := TAU * i / 4.0
		mote.position = Vector2.from_angle(plate_ang) * (108.0 if skin in ["eclipse_knight", "fallen_arbiter"] else 64.0)
		mote.scale = Vector2(0.30, 0.30) if orbit_tex == "fx_aegis" else Vector2(0.38, 0.38)
		if skin in ["eclipse_knight", "fallen_arbiter"]:
			mote.modulate.a = 0.0
		orbit.add_child(mote)
		if skin in ["eclipse_knight", "fallen_arbiter"]:
			var lock_tw := mote.create_tween()
			lock_tw.tween_interval(0.075 * i)
			lock_tw.tween_property(mote, "modulate:a", 0.95, 0.05)
			lock_tw.parallel().tween_property(mote, "position", Vector2.from_angle(plate_ang) * 64.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := orbit.create_tween()
	spin.set_loops()
	if skin in ["eclipse_knight", "fallen_arbiter"]:
		spin.tween_interval(0.34)
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
	if oath_shield > 0.0:
		# Unwavering Conviction (talent): the swap girds you in light — a
		# non-stacking max-HP shield; stance-dancing IS the defense.
		shield = maxf(shield, max_hp * oath_shield)
	if paladin_mode == "holy":
		paladin_mode = "retribution"
		zeal_time = Balance.PALADIN_ZEAL_DUR   # Zeal: the swap into wrath ignites a burst window
		game.spawn_text(global_position + Vector2(0, -64), "RETRIBUTION — ZEAL!", Color(1.0, 0.45, 0.25))
		game.hud.flash_screen(Color(1.0, 0.4, 0.15), 0.3, 0.3)
		# The wrath announces itself: chains drag the field in for the verdict.
		_chains_of_wrath(f * Balance.PALADIN_SWAP_CHAINS)
		# Chains' no-target early-out resets the ult cd to 1s (fine for the old
		# nuke, an exploit for a stance: swap-swap at range = free 10% heals
		# every ~2s). The SWAP always pays its full cooldown.
		cds["ult"] = maxf(cds["ult"], ability_cd("ult"))
	else:
		paladin_mode = "holy"
		zeal_time = 0.0   # Zeal is a Retribution burst — going defensive drops it
		game.sfx("mend", 1.0, 0.0, -2.0)
		# (Retribution's hot red flash stays UN-skinned — Zeal is a gameplay
		# read; only the holy side wears the skin's light.)
		var holy_col := _pal_skin_col(Color(1.0, 0.92, 0.55))
		game.spawn_text(global_position + Vector2(0, -64), "HOLY", holy_col)
		game.hud.flash_screen(_pal_skin_col(Color(1.0, 0.9, 0.5)), 0.25, 0.3)
		_ring_fx(global_position, holy_col, 130.0)
		game.burst(global_position, _pal_skin_col(Color(1.0, 0.95, 0.7)), 14)
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
	game.hud.flash_screen(_pal_skin_col(Color(1.0, 0.85, 0.4)), 0.4, 0.35)
	var col := _pal_skin_col(_tcolor if _themed else Color(1.0, 0.85, 0.45))
	if skin == "":
		_ring_fx(global_position, col, radius, true)
	game.spawn_text(global_position + Vector2(0, -64), "CHAINS OF WRATH", Color(1, 0.8, 0.4))
	if _tfx.has("chain_guard"):
		# Aegis: the chains anchor YOU.
		theme_guard_time = 3.0
		theme_guard_amt = float(_tfx["chain_guard"])
	var fx_copy := _tfx.duplicate()
	var heal_frac := float(_tfx.get("chain_heal", 0.0))
	var fmul := f
	if skin == "eclipse_knight":
		_eclipse_conviction_scene(targets)
	elif skin == "fallen_arbiter":
		_arbiter_tribunal_scene(targets)
	for node in targets:
		var e := node as Enemy
		_chain_link_fx(e.global_position, col)
		_stun_or_concuss(e, 1.2)
		var dir := (e.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var dest: Vector2 = game.clamp_to_zone(global_position + dir * 70.0, e.global_position)
		if e.net_mirror:
			# MP-10: the drag is world business — the host tweens its REAL
			# enemy to this dest; the mirror follows through the 20 Hz stream.
			game.net_session().guest_enemy_status(e.net_id, "drag", {"dest": dest, "dur": 0.28})
		else:
			var tw := e.create_tween()
			tw.tween_property(e, "global_position", dest, 0.28) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The hammer of verdict falls from the sky while the chains reel in.
	var hammer := Sprite2D.new()
	var hammer_tex := "fx_hammer_base"
	if skin == "eclipse_knight":
		hammer_tex = "fx_hammer_eclipse"
	elif skin == "fallen_arbiter":
		hammer_tex = "fx_hammer_fallen"
	hammer.texture = Art.tex(hammer_tex)
	# Base Verdict takes the active variant's holy hue; named skin hammers keep
	# their authored eclipse/cold-metal palettes.
	hammer.modulate = Color.WHITE.lerp(col, 0.45) if skin == "" and _themed else Color.WHITE
	hammer.scale = Vector2(3.2, 3.2)
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
		game.hud.flash_screen(_pal_skin_col(Color(1.0, 0.9, 0.5)), 0.35, 0.3)
		var verdict := Sprite2D.new()
		var verdict_tex := "fx_consecration"
		if skin == "eclipse_knight":
			verdict_tex = "fx_eclipse_corona"
		elif skin == "fallen_arbiter":
			verdict_tex = "fx_fallen_verdict"
		verdict.texture = Art.tex(verdict_tex)
		verdict.modulate = Color(col, 0.92)
		verdict.global_position = global_position
		verdict.scale = Vector2(1.8, 1.8) if skin in ["eclipse_knight", "fallen_arbiter"] else Vector2(4.7, 4.7)
		verdict.z_index = -4
		game.add_child(verdict)
		var verdict_tw := verdict.create_tween()
		verdict_tw.tween_property(verdict, "rotation", TAU * (1.0 if skin == "fallen_arbiter" else -1.0), 0.38)
		verdict_tw.parallel().tween_property(verdict, "modulate:a", 0.0, 0.48)
		verdict_tw.tween_callback(verdict.queue_free)
		_light_pillar(global_position, col, 1.4)
		game.burst(global_position, col, 24)
		game.burst(global_position, Color(1, 1, 1), 10)
		_ring_fx(global_position, col, 150.0)
		var saved := _tfx
		_tfx = fx_copy
		for e2 in _enemies_within(global_position, 150.0):
			_smite_rip(e2.global_position, col)
			hit_enemy(e2, ability_coeff("ult") * fmul, {"aoe": true, "stun": 0.5})
			if heal_frac > 0.0:
				gain_hp(max_hp * heal_frac)  # holy chains: each drag mends, SHOWN
		_tfx = saved)


## A taut chain of REAL links snapping from the hero to a tethered enemy,
## then reeling inward with the drag.
func _chain_link_fx(to: Vector2, col: Color) -> void:
	# The chain leaves the HANDS, not the hip — the node origin sits at hip
	# height on the feet-anchored body (same lift as the projectile muzzle).
	var hands := global_position + Vector2(0, -Balance.PROJ_MUZZLE_RISE)
	var span := to - hands
	var links := maxi(3, int(span.length() / 26.0))
	for i in links:
		var t := (i + 0.5) / float(links)
		var link := Sprite2D.new()
		link.texture = Art.tex("ring")
		link.modulate = Color(col, 0.95)
		link.global_position = hands + span * t
		link.rotation = span.angle()
		link.scale = Vector2(0.24, 0.15)  # a squashed ring reads as a link
		link.z_index = 7
		game.add_child(link)
		var tw := link.create_tween()
		# Links reel in with the catch, vanishing as they arrive.
		tw.tween_property(link, "global_position", hands + span * t * 0.2, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(link, "modulate:a", 0.0, 0.3)
		tw.tween_callback(link.queue_free)
	# The taut line itself flashes once as the chain snaps home.
	_beam_fx(hands, to, col, 0.14)
