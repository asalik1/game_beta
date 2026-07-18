extends "res://scripts/player_kit_paladin.gd"
## PLAYER, layer 8 of 9 — the WARLOCK kit: dispatch + abilities.
## (The hex watch in player.gd's per-frame driver calls DOWN into
## _spread_curse/_hex_detonate.) See player_core.gd for the chain layout.


func _use_warlock(slot: String, f: float) -> void:
	match slot:
		# Round 45 taxed the spam bolt -10% so the DoT class trails the
		# burst classes on boss TTK; round 49's dps bench showed it trailing
		# EVERYWHERE by 25%+ — tax reverted, wither still owns the long game.
		"a1":
			# Loose the bolt on the hand-thrust frame, not the input frame.
			await get_tree().create_timer(swing_delay(Balance.WARLOCK_CAST_DELAY)).timeout
			if dead or downed or ghost:
				return
			_cast_shadowbolt(aim_dir(), 1.0 * f)
		"a2": _hex(f)
		"a3": _dark_pact(f)
		"ult": _void_rift(f)


## Warlock skin signature colour (Ronin pattern — the skin's magic wins over
## theme): the Inquisitor's craft burns hellfire-orange; the Herald's seeps
## abyssal ichor-green.
func _wl_skin_col(base: Color) -> Color:
	if skin == "hellfire_inquisitor":
		return Color(1.00, 0.45, 0.12)
	if skin == "eldritch_herald":
		return Color(0.42, 0.90, 0.58)
	return base


func _cast_shadowbolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball", 0.7)  # deeper, hungrier whoosh than the mage's
	_muzzle(dir, _wl_skin_col(_tcolor if _themed else Color(0.75, 0.4, 1.0)))
	var p := _proj(dir, mult, "shadowbolt", 460.0)
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if skin == "hellfire_inquisitor":
		# The bolt is a thrown coal: ember-hot shaft with a fire-streak tail.
		p.modulate = Color(1.00, 0.62, 0.30)
		var tr := ProjTrail.new()
		tr.proj = p
		tr.col = Color(1.00, 0.45, 0.15)
		game.add_child(tr)
	elif skin == "eldritch_herald":
		# The bolt drips: sickly green shaft, an ichor-streak trailing it.
		p.modulate = Color(0.55, 0.92, 0.66)
		var tr := ProjTrail.new()
		tr.proj = p
		tr.col = Color(0.35, 0.85, 0.55)
		game.add_child(tr)


## Hex: curse everything around your target — withered, EXPOSED, and
## primed to EXPLODE on death (the class identity).
func _hex(f := 1.0) -> void:
	# Land the curse on the sigil-projection frame, not the input frame.
	await get_tree().create_timer(swing_delay(Balance.WARLOCK_CAST_DELAY)).timeout
	if dead or downed or ghost:
		return
	game.sfx("gate", 1.6)
	var target := auto_aim()
	var center := target.global_position if target else global_position
	# Round 49 AoE pass: 140 -> 120 — the curse's whole-pack EXPOSE was
	# carrying every warlock variant's pack damage at once.
	var radius := 120.0
	var col := _wl_skin_col(_tcolor if _themed else Color(0.75, 0.4, 1.0))
	# The curse arrives: a collapsing ring — power drawn INTO the victims.
	_ring_fx(center, col, radius, true)
	game.burst(center, col, 12)
	# Void wisps seep up out of the cursed ground.
	var wisps := CPUParticles2D.new()
	wisps.amount = 24
	wisps.lifetime = 0.9
	wisps.one_shot = true
	wisps.explosiveness = 0.6
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = radius * 0.7
	wisps.direction = Vector2(0, -1)
	wisps.spread = 20.0
	wisps.gravity = Vector2(0, -70)
	wisps.initial_velocity_min = 15.0
	wisps.initial_velocity_max = 45.0
	wisps.scale_amount_min = 1.6
	wisps.scale_amount_max = 3.2
	wisps.color = Color(col, 0.9)
	wisps.global_position = center
	game.add_child(wisps)
	get_tree().create_timer(1.4).timeout.connect(wisps.queue_free)
	hex_fx = _tfx.duplicate()
	var eff := {"aoe": true, "vuln": 1.0}  # the curse always EXPOSES
	eff["dot"] = maxf(0.25, float(_tfx.get("dot", 0.0)))
	for e in _enemies_within(center, radius):
		# A dark tendril lashes from the curse's heart to each victim.
		_beam_fx(center, e.global_position, col, 0.16)
		hit_enemy(e, ability_coeff("a1") * f, eff.duplicate())
		if not e.dying:
			_hex_mark(e)


## Contagion (warlock talent): a cursed death seeds the curse onto one nearby
## un-cursed enemy — EXPOSED + explode-on-death + wither, no damage hit (so it
## carries the attrition engine into packs without touching single-target).
func _spread_curse(pos: Vector2) -> void:
	for e in _enemies_within(pos, 160.0):
		if hexed.has(e) or e.dying:
			continue
		e.apply_vuln(3.0)  # EXPOSED (MP-10 seam: mirrors forward the mark)
		_hex_mark(e)
		_beam_fx(pos, e.global_position, Color(0.8, 0.45, 1.0), 0.14)
		return


func _hex_mark(e: Enemy) -> void:
	hexed[e] = 8.0
	if e.has_node("hex_rune"):
		return
	var rune := Sprite2D.new()
	rune.name = "hex_rune"
	rune.texture = Art.glyph_tex("ab_hex", _wl_skin_col(Color(0.8, 0.45, 1.0)))
	rune.position = Vector2(0, -30)
	rune.scale = Vector2(0.9, 0.9)
	e.add_child(rune)


## A cursed enemy died: the hex detonates onto its neighbors.
func _hex_detonate(pos: Vector2) -> void:
	var col := _wl_skin_col(Color(0.8, 0.45, 1.0))
	game.sfx("nova", 0.65)
	game.burst(pos, col, 14)
	game.burst(pos, Color(1, 1, 1), 6)
	_ring_fx(pos, col, 110.0)
	# The soul tears open: a white-hot core swells and pops.
	var core := Sprite2D.new()
	core.texture = Art.tex("glow")
	core.modulate = Art.hdr(Color(0.95, 0.85, 1.0, 0.95))
	core.global_position = pos
	core.scale = Vector2(0.4, 0.4)
	core.z_index = 8
	game.add_child(core)
	var ct := core.create_tween()
	ct.tween_property(core, "scale", Vector2(2.6, 2.6), 0.16)
	ct.parallel().tween_property(core, "modulate:a", 0.0, 0.2)
	ct.tween_callback(core.queue_free)
	var mult := 1.1 * float(hex_fx.get("hex_boom", 1.0)) * dm("a2")
	var saved := _tfx
	_tfx = {}
	for e in _enemies_within(pos, 110.0):
		hit_enemy(e, mult, {"aoe": true})
	_tfx = saved
	if hex_fx.has("hex_heal"):
		# Pact: every cursed death feeds you.
		var frac: float = hex_fx["hex_heal"]
		hp = minf(max_hp, hp + max_hp * frac)
		game.spawn_text(global_position + Vector2(0, -50), "+%d" % int(max_hp * frac), Color(0.5, 1.0, 0.5))


## Dark Pact: pay in blood for a soul-drain blast, then drink it back
## through a lifesteal surge.
func _dark_pact(f := 1.0) -> void:
	var cost_frac := float(_tfx.get("pact_cost", 0.12))
	var sacrifice := max_hp * cost_frac
	if hp <= sacrifice + 1.0:
		cds["a3"] = 0.5  # you cannot pay in blood you don't have
		return
	hp -= sacrifice
	game.spawn_text(global_position + Vector2(0, -44), "-%d" % int(sacrifice), Color(1.0, 0.3, 0.4))
	pact_time = 5.0
	pact_ls = float(_tfx.get("pact_ls", 0.15))
	# The pact's rays take the skin's craft; the BLOOD price particles below
	# stay blood-red — the cost is the cost, whoever pays it.
	var col := _wl_skin_col(_tcolor if _themed else Color(1.0, 0.3, 0.45))
	game.sfx("nova", 0.6)
	game.shake(5.0)
	game.hud.flash_screen(Color(0.6, 0.05, 0.15), 0.35, 0.3)
	# The price is PAID on screen: blood streams INTO the caster...
	var blood := CPUParticles2D.new()
	blood.amount = 26
	blood.lifetime = 0.4
	blood.one_shot = true
	blood.explosiveness = 0.9
	blood.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	blood.emission_sphere_radius = 90.0
	blood.gravity = Vector2.ZERO
	blood.radial_accel_min = -900.0
	blood.radial_accel_max = -600.0
	blood.scale_amount_min = 1.4
	blood.scale_amount_max = 2.6
	blood.color = Color(0.9, 0.15, 0.25)
	add_child(blood)
	get_tree().create_timer(0.8).timeout.connect(blood.queue_free)
	_ring_fx(global_position, col, 170.0, true)
	game.burst(global_position, col, 18)
	# ...then the blast: dark rays lash outward from the pact's heart.
	for i in 8:
		var ang := TAU * i / 8.0 + randf_range(-0.1, 0.1)
		var ray := Sprite2D.new()
		ray.texture = Art.tex("glow")
		ray.modulate = Art.hdr(Color(col, 0.85))
		ray.rotation = ang
		ray.position = Vector2.from_angle(ang) * 60.0
		ray.scale = Vector2(0.4, 0.22)
		ray.z_index = 7
		add_child(ray)
		var rt := ray.create_tween()
		rt.tween_property(ray, "position", Vector2.from_angle(ang) * 165.0, 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(ray, "scale:x", 2.6, 0.2)
		rt.parallel().tween_property(ray, "modulate:a", 0.0, 0.26)
		rt.tween_callback(ray.queue_free)
	game.spawn_text(global_position + Vector2(0, -64), "DARK PACT", col)
	var eff := {"aoe": true}
	if _tfx.get("pull", 0):
		eff["pull"] = 1
	for e in _enemies_within(global_position, 170.0):
		hit_enemy(e, ability_coeff("a2") * f, eff.duplicate())


## Void Rift: a rift tears open under the target, drags everything
## inward for a breath, then BURSTS — the delay IS the ability.
func _void_rift(f := 1.0) -> void:
	_ult_sfx()
	var target := auto_aim()
	var pos: Vector2 = target.global_position if target else global_position + facing * 180.0
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _wl_skin_col(_tcolor if _themed else Color(0.55, 0.45, 1.0))
	var fx_copy := _tfx.duplicate()
	var fmul := f
	# Read at CAST time: the burst lands seconds later, and the class may have
	# moved on by then (only warlock's ult carries a dmg block at all).
	var crit_cursed: bool = bool(Classes.CLASSES[cls]["abilities"]["ult"].get("dmg", {}).get("crit_cursed", false))
	# The growing maw on the ground — you can feel it coming.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.modulate = Color(col, 0.55)
	mark.global_position = pos
	mark.scale = Vector2(0.6, 0.6)
	mark.z_index = -6
	game.add_child(mark)
	var mt := mark.create_tween()
	mt.tween_property(mark, "scale", Vector2(radius / 32.0, radius / 32.0), 0.3)
	# Indrawn particles: the rift visibly EATS light.
	var indraw := CPUParticles2D.new()
	indraw.amount = 30
	indraw.lifetime = 0.5
	indraw.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	indraw.emission_sphere_radius = radius
	indraw.radial_accel_min = -700.0
	indraw.radial_accel_max = -500.0
	indraw.gravity = Vector2.ZERO
	indraw.scale_amount_min = 1.4
	indraw.scale_amount_max = 2.6
	indraw.color = Color(col, 0.9)
	indraw.global_position = pos
	game.add_child(indraw)
	# The vortex itself: dark blades wheeling INWARD over a swelling
	# void heart — the rift is a thing on the field, not a decal.
	var vortex := Node2D.new()
	vortex.global_position = pos
	vortex.z_index = 5
	game.add_child(vortex)
	for i in 3:
		var ang := TAU * i / 3.0
		var blade := Sprite2D.new()
		blade.texture = Art.tex("slash")
		blade.modulate = Color(col, 0.85)
		blade.rotation = ang + PI
		blade.position = Vector2.from_angle(ang) * radius * 0.45
		blade.scale = Vector2(2.3, 2.3)
		vortex.add_child(blade)
	var vt := vortex.create_tween()
	vt.set_loops()
	vt.tween_property(vortex, "rotation", -TAU, 0.8).as_relative()
	var heart := Sprite2D.new()
	heart.texture = Art.tex("glow")
	heart.modulate = Color(col.r * 0.35, col.g * 0.2, col.b * 0.6, 0.85)
	heart.global_position = pos
	heart.scale = Vector2(0.6, 0.6)
	heart.z_index = 6
	game.add_child(heart)
	var heart_tw := heart.create_tween()
	heart_tw.tween_property(heart, "scale", Vector2(3.2, 3.2), 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Four pull ticks, then the burst.
	var hard: bool = fx_copy.get("hard_pull", 0)
	for i in 4:
		await get_tree().create_timer(0.22).timeout
		if dead:
			break
		_ring_fx(pos, col, radius, true)
		for e in _enemies_within(pos, radius * 1.3):
			var to_rift: Vector2 = pos - e.global_position
			if to_rift.length() > 20.0:
				# apply_knock (MP-10 seam): a mirror ships the pull to the host
				e.apply_knock(to_rift.normalized() * (520.0 if hard else 300.0))
	if is_instance_valid(mark):
		mark.queue_free()
	if is_instance_valid(vortex):
		vortex.queue_free()
	if is_instance_valid(heart):
		heart.queue_free()
	indraw.emitting = false
	get_tree().create_timer(0.8).timeout.connect(indraw.queue_free)
	if dead:
		return
	game.sfx("meteor")
	game.shake(12.0)
	game.hud.flash_screen(Color(col, 1.0), 0.5, 0.35)
	game.burst(pos, col, 26)
	game.burst(pos, Color(1, 1, 1), 10)
	_ring_fx(pos, col, radius)
	_ring_fx(pos, Color(1, 1, 1), radius * 0.6)
	# The collapse blows back out: void rays and a popping white core.
	var vcore := Sprite2D.new()
	vcore.texture = Art.tex("glow")
	vcore.modulate = Art.hdr(Color(0.95, 0.9, 1.0, 0.95))
	vcore.global_position = pos
	vcore.scale = Vector2(0.5, 0.5)
	vcore.z_index = 8
	game.add_child(vcore)
	var vct := vcore.create_tween()
	vct.tween_property(vcore, "scale", Vector2(3.4, 3.4), 0.18)
	vct.parallel().tween_property(vcore, "modulate:a", 0.0, 0.22)
	vct.tween_callback(vcore.queue_free)
	for i in 10:
		var rang := TAU * i / 10.0 + randf_range(-0.12, 0.12)
		var ray := Sprite2D.new()
		ray.texture = Art.tex("glow")
		ray.modulate = Art.hdr(Color(col, 0.9))
		ray.rotation = rang
		ray.global_position = pos + Vector2.from_angle(rang) * 30.0
		ray.scale = Vector2(0.5, 0.2)
		ray.z_index = 7
		game.add_child(ray)
		var rt := ray.create_tween()
		rt.tween_property(ray, "global_position", pos + Vector2.from_angle(rang) * radius, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(ray, "scale:x", 2.4, 0.22)
		rt.parallel().tween_property(ray, "modulate:a", 0.0, 0.26)
		rt.tween_callback(ray.queue_free)
	# Scarred space lingers where the rift fed.
	var scar := Sprite2D.new()
	scar.texture = Art.tex("glow")
	scar.modulate = Color(col.r * 0.4, col.g * 0.25, col.b * 0.7, 0.5)
	scar.global_position = pos
	scar.scale = Vector2(radius / 26.0, radius / 34.0)
	scar.z_index = -5
	game.add_child(scar)
	var sct := scar.create_tween()
	sct.tween_property(scar, "modulate:a", 0.0, 1.2)
	sct.tween_callback(scar.queue_free)
	var heal_frac := float(fx_copy.get("rift_heal", 0.0))
	var saved := _tfx
	_tfx = fx_copy
	for e in _enemies_within(pos, radius):
		var eff := {"aoe": true}
		if crit_cursed and hexed.has(e):
			eff["force_crit"] = 1   # Void Rift always crits a cursed victim (single-sourced flag)
		hit_enemy(e, ability_coeff("ult") * fmul, eff)
		if heal_frac > 0.0:
			gain_hp(max_hp * heal_frac)  # pact rift: each caught soul mends, SHOWN
	_tfx = saved
	if s_passive() == "voidmaw":
		_voidmaw_wave()


## Voidmaw (warlock S weapon): once the rift resolves, a dark curse-wave
## rolls off the warlock — SHOVING nearby enemies away (harder the closer)
## and cursing the whole room. The endgame answer to being swarmed: a mob
## storm becomes breathing room AND fuel for the curse engine at once.
func _voidmaw_wave() -> void:
	game.sfx("gate", 1.1)
	var col := Color(0.6, 0.28, 0.95)
	_ring_fx(global_position, col, 340.0)
	game.burst(global_position, col, 20)
	hex_fx = _tfx.duplicate()
	var max_reach := 720.0
	var eff := {"aoe": true, "vuln": 1.0, "dot": 0.30}
	for e in _enemies_within(global_position, max_reach):
		var away: Vector2 = e.global_position - global_position
		var dist := away.length()
		if dist > 12.0:
			var push := clampf(1.0 - dist / max_reach, 0.15, 1.0)  # closer = harder
			e.apply_knock(away.normalized() * 640.0 * push)
		_beam_fx(global_position, e.global_position, col, 0.14)
		hit_enemy(e, 0.4, eff.duplicate())   # Voidmaw S-passive wave — NOT the ult burst
		if not e.dying:
			_hex_mark(e)
