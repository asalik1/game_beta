extends "res://scripts/player_combat.gd"
## PLAYER, layer 3 of 4 — the paladin and warlock kits (they lean on
## layer 2's hit_enemy/_enemies_within/juice helpers). See
## player_core.gd for the chain layout.


# ============================================================ paladin kit

## A shaft of light stabs down from the sky and blooms where it lands.
## The Dawnbreaker pillar, Consecration's judgment on each victim.
func _light_pillar(pos: Vector2, col := Color(1.0, 0.95, 0.6), width := 0.9) -> void:
	var shaft := Sprite2D.new()
	shaft.texture = Art.tex("glow")
	shaft.modulate = Color(col, 0.0)
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
	rip.modulate = Color(col, 0.95)
	rip.global_position = pos
	rip.rotation = randf_range(0.0, TAU)
	rip.scale = Vector2(2.0, 0.13)
	rip.z_index = 8
	game.add_child(rip)
	var tw := rip.create_tween()
	tw.tween_property(rip, "scale:y", 0.03, 0.12)
	tw.parallel().tween_property(rip, "modulate:a", 0.0, 0.14)
	tw.tween_callback(rip.queue_free)


## A thin beam of light/darkness between two points, fading fast
## (hex tendrils, quick magical connections).
func _beam_fx(from: Vector2, to: Vector2, col: Color, width := 0.18) -> void:
	var seg := Sprite2D.new()
	seg.texture = Art.tex("glow")
	seg.modulate = Color(col, 0.85)
	seg.global_position = (from + to) / 2.0
	seg.rotation = (to - from).angle()
	seg.scale = Vector2(maxf(0.5, from.distance_to(to) / 44.0), width)
	seg.z_index = 7
	game.add_child(seg)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale:y", 0.03, 0.22)
	tw.parallel().tween_property(seg, "modulate:a", 0.0, 0.24)
	tw.tween_callback(seg.queue_free)


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
		shard.modulate = Color(col, 0.75)
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
		mote.modulate = Color(col, 0.85)
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


## Chains of Wrath: tether every nearby enemy, DRAG them to the hammer,
## then the verdict lands on the pile.
func _chains_of_wrath(f := 1.0) -> void:
	var radius := 320.0 * float(_tfx.get("radius_mult", 1.0))
	var targets := _enemies_within(global_position, radius)
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
		e.apply_stun(1.2)
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
				hp = minf(max_hp, hp + max_hp * heal_frac)
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


# ============================================================ warlock kit

func _cast_shadowbolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball", 0.7)  # deeper, hungrier whoosh than the mage's
	_muzzle(dir, _tcolor if _themed else Color(0.75, 0.4, 1.0))
	var p := _proj(dir, mult, "shadowbolt", 460.0)
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if s_passive() == "hollowchoir":
		p.fx["ric"] = 1  # the choir answers: a second bolt leaps onward


## Hex: curse everything around your target — withered, EXPOSED, and
## primed to EXPLODE on death (the class identity).
func _hex(f := 1.0) -> void:
	game.sfx("gate", 1.6)
	var target := auto_aim()
	var center := target.global_position if target else global_position
	var radius := 140.0
	var col := _tcolor if _themed else Color(0.75, 0.4, 1.0)
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
		hit_enemy(e, 0.5 * f, eff.duplicate())
		if not e.dying:
			_hex_mark(e)


func _hex_mark(e: Enemy) -> void:
	hexed[e] = 8.0
	if e.has_node("hex_rune"):
		return
	var rune := Sprite2D.new()
	rune.name = "hex_rune"
	rune.texture = Art.glyph_tex("ab_hex", Color(0.8, 0.45, 1.0))
	rune.position = Vector2(0, -30)
	rune.scale = Vector2(0.9, 0.9)
	e.add_child(rune)


## A cursed enemy died: the hex detonates onto its neighbors.
func _hex_detonate(pos: Vector2) -> void:
	var col := Color(0.8, 0.45, 1.0)
	game.sfx("nova", 0.65)
	game.burst(pos, col, 14)
	game.burst(pos, Color(1, 1, 1), 6)
	_ring_fx(pos, col, 110.0)
	# The soul tears open: a white-hot core swells and pops.
	var core := Sprite2D.new()
	core.texture = Art.tex("glow")
	core.modulate = Color(0.95, 0.85, 1.0, 0.95)
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
	var col := _tcolor if _themed else Color(1.0, 0.3, 0.45)
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
		ray.modulate = Color(col, 0.85)
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
		hit_enemy(e, 1.5 * f, eff.duplicate())


## Void Rift: a rift tears open under the target, drags everything
## inward for a breath, then BURSTS — the delay IS the ability.
func _void_rift(f := 1.0) -> void:
	_ult_sfx()
	var target := auto_aim()
	var pos: Vector2 = target.global_position if target else global_position + facing * 180.0
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(0.55, 0.45, 1.0)
	var fx_copy := _tfx.duplicate()
	var fmul := f
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
				e.knock = to_rift.normalized() * (520.0 if hard else 300.0)
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
	vcore.modulate = Color(0.95, 0.9, 1.0, 0.95)
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
		ray.modulate = Color(col, 0.9)
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
		hit_enemy(e, 3.0 * fmul, {"aoe": true})
		if heal_frac > 0.0:
			hp = minf(max_hp, hp + max_hp * heal_frac)
	_tfx = saved


