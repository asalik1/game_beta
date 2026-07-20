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
			var cast_delay := swing_delay(Balance.WARLOCK_CAST_DELAY)
			var cast_eye: Node2D = null
			if skin == "eldritch_warlock":
				cast_eye = _spawn_eldritch_cast_eye(aim_dir(), cast_delay)
			await get_tree().create_timer(cast_delay).timeout
			if dead or downed or ghost:
				_dismiss_eldritch_cast_eye(cast_eye)
				return
			_cast_shadowbolt(aim_dir(), 1.0 * f, cast_eye)
		"a2": _hex(f)
		"a3": _dark_pact(f)
		"ult": _void_rift(f)


## Warlock skin signature colour (Ronin pattern — the skin's magic wins over
## theme): the Inquisitor's craft burns hellfire-orange; Arcane Warlock's
## existing kit seeps ichor-green; Eldritch Warlock owns woven violet.
func _wl_skin_col(base: Color) -> Color:
	if skin == "hellfire_inquisitor":
		return Color(1.00, 0.45, 0.12)
	if skin == "arcane_warlock":
		return Color(0.42, 0.90, 0.58)
	if skin == "eldritch_warlock":
		return Color(0.66, 0.24, 1.00)
	return base


func _cast_shadowbolt(dir: Vector2, mult: float, cast_eye: Node2D = null) -> void:
	if skin == "eldritch_warlock":
		_cast_eldritch_eye_bolt(cast_eye, dir, mult)
		return
	game.sfx("fireball", 0.7)  # deeper, hungrier whoosh than the mage's
	_muzzle(dir, _wl_skin_col(_tcolor if _themed else Color(0.75, 0.4, 1.0)))
	# Base is a hooked void-spear, Inquisitor throws a living coal, and Arcane
	# carries a curse-rune on the bolt itself — distinct shapes, not tints.
	var bolt_tex := "warlock_shadowbolt"
	if skin == "hellfire_inquisitor":
		bolt_tex = "hellfire_brand_bolt"
	elif skin == "arcane_warlock":
		bolt_tex = "warlock_eldritch_bolt"
		_arcane_bolt_eye(dir)
	var p := _proj(dir, mult, bolt_tex, 460.0)
	# Base curse bolts keep the active ability-variant tint; skin assets retain
	# their bespoke fire/ichor treatment below.
	p.modulate = Color.WHITE.lerp(_tcolor, 0.55) if skin == "" and _themed else Color.WHITE
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if skin == "hellfire_inquisitor":
		# The branded spear sheds a small trail of real embers that fade behind it.
		var tr := ProjTrail.new()
		tr.proj = p
		tr.col = Color(1.00, 0.45, 0.15)
		game.add_child(tr)
		var embers := CPUParticles2D.new()
		embers.amount = 14
		embers.lifetime = 0.32
		embers.local_coords = false
		embers.direction = Vector2.LEFT
		embers.spread = 22.0
		embers.initial_velocity_min = 24.0
		embers.initial_velocity_max = 52.0
		embers.gravity = Vector2.ZERO
		embers.scale_amount_min = 0.7
		embers.scale_amount_max = 1.5
		embers.color = Color(1.0, 0.26, 0.06, 0.78)
		p._vis.add_child(embers)
	elif skin == "arcane_warlock":
		# The living eye-bolt already owns the silhouette; only its ichor trail
		# is added at runtime.
		p.modulate = Color.WHITE
		var tr := ProjTrail.new()
		tr.proj = p
		tr.col = Color(0.35, 0.85, 0.55)
		game.add_child(tr)
		_living_tether(self, p, Color(0.36, 0.86, 0.56, 0.65), 0.48, true)


func _pick_eldritch_eye_origin() -> Vector2:
	# Cosmetic placement uses an isolated RNG so a paid skin never advances the
	# gameplay random stream. Reject pockets already occupied by another eye.
	var fallback := global_position + Vector2(52.0, -38.0)
	var best_clearance := -1.0
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.randomize()
	for attempt in 14:
		var candidate := global_position + Vector2.from_angle(visual_rng.randf() * TAU) \
			* visual_rng.randf_range(46.0, 72.0) + Vector2(0, -30.0)
		var clearance := 9999.0
		for node in get_tree().get_nodes_in_group("eldritch_warlock_cast_eye"):
			if node is Node2D and is_instance_valid(node):
				clearance = minf(clearance, candidate.distance_to(node.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			fallback = candidate
		if clearance >= 52.0:
			return candidate
	return fallback


func _spawn_eldritch_cast_eye(_dir: Vector2, duration: float) -> Node2D:
	var eye := Node2D.new()
	eye.global_position = _pick_eldritch_eye_origin()
	eye.add_to_group("eldritch_warlock_cast_eye")
	game.add_child(eye)
	var spr := Sprite2D.new()
	spr.name = "Eye"
	spr.texture = Art.tex("fx/warlock_eldritch_cast_eye")
	spr.hframes = 8
	spr.frame = 0
	spr.scale = Vector2(0.66, 0.66)
	spr.modulate = Color(1.0, 1.0, 1.0, 0.98)
	spr.z_index = 10
	eye.add_child(spr)
	# Frames 2-5 make the living pupil scan left, centre and right before firing.
	var form := spr.create_tween()
	var per := maxf(0.016, duration / 5.0)
	for frame in range(1, 6):
		form.tween_interval(per)
		form.tween_callback(spr.set_frame.bind(frame))
	return eye


func _cast_eldritch_eye_bolt(eye: Node2D, intended_dir: Vector2,
		mult: float) -> Projectile:
	if eye == null or not is_instance_valid(eye):
		eye = _spawn_eldritch_cast_eye(intended_dir, 0.0)
	var shot_dir := intended_dir.normalized()
	var eye_spr := eye.get_node_or_null("Eye") as Sprite2D
	var eye_center := eye.global_position
	if eye_spr != null:
		# Frame 6 contains a baked rightward streak; the real bullet/path is
		# runtime-directed, so fire from the centred charge frame instead.
		eye_spr.frame = 5
		eye_center = eye.to_global(eye_spr.position)
	game.sfx("fireball", 0.7)
	var p := _proj(shot_dir, mult, "mage_void_bullet", 460.0)
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	var base_visual_origin := p.global_position + Vector2(0, -p.rise)
	var offset := eye_center - base_visual_origin
	var settle := clampf(offset.length() / 460.0, 0.10, 0.22)
	# Physics remain the exact base Shadowbolt. Only its rendered origin folds
	# from the eye pupil onto that unchanged path.
	p.set_visual_origin(eye_center, settle)
	p.visual_impact.connect(_dismiss_eldritch_cast_eye.bind(eye), CONNECT_ONE_SHOT)
	p.tree_exiting.connect(_dismiss_eldritch_cast_eye.bind(eye), CONNECT_ONE_SHOT)
	get_tree().create_timer(p.life + 0.20).timeout.connect(
		_dismiss_eldritch_cast_eye_by_id.bind(eye.get_instance_id()), CONNECT_ONE_SHOT)
	return p


func _dismiss_eldritch_cast_eye_by_id(eye_id: int) -> void:
	var eye := instance_from_id(eye_id) as Node2D
	if eye != null and is_instance_valid(eye):
		_dismiss_eldritch_cast_eye(eye)


func _dismiss_eldritch_cast_eye(eye: Node2D) -> void:
	if eye == null or not is_instance_valid(eye) or eye.get_meta("dismissing", false):
		return
	eye.set_meta("dismissing", true)
	var spr := eye.get_node_or_null("Eye") as Sprite2D
	if spr == null:
		eye.queue_free()
		return
	spr.frame = 7
	var close := spr.create_tween()
	close.tween_property(spr, "modulate:a", 0.0, 0.11)
	close.tween_callback(eye.queue_free)


func _arcane_bolt_eye(dir: Vector2) -> void:
	var eye := Sprite2D.new()
	eye.texture = Art.tex("fx_eldritch_eye")
	eye.position = dir * 25.0
	eye.rotation = dir.angle()
	eye.scale = Vector2(0.42, 0.04)
	eye.modulate = Color(0.58, 1.0, 0.68, 0.88)
	eye.z_index = 8
	add_child(eye)
	var tw := eye.create_tween()
	tw.tween_property(eye, "scale:y", 0.42, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.08)
	tw.tween_property(eye, "scale:y", 0.03, 0.1)
	tw.parallel().tween_property(eye, "modulate:a", 0.0, 0.1)
	tw.tween_callback(eye.queue_free)


func _inquisitor_brand_stamp(e: Enemy) -> void:
	var brand := Sprite2D.new()
	brand.texture = Art.tex("fx_inquisition_brand")
	brand.position = Vector2(0, -28)
	brand.scale = Vector2(1.45, 1.45)
	brand.modulate = Color(1.0, 0.82, 0.5, 0.0)
	brand.z_index = 9
	e.add_child(brand)
	var tw := brand.create_tween()
	tw.tween_property(brand, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(brand, "scale", Vector2(0.48, 0.48), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.18)
	tw.tween_property(brand, "modulate", Color(0.28, 0.12, 0.08, 0.36), 0.28)
	tw.tween_callback(brand.queue_free)


func _arcane_eye_curse(e: Enemy) -> void:
	var eye := Sprite2D.new()
	eye.texture = Art.tex("fx_eldritch_eye")
	eye.position = Vector2(0, -34)
	eye.scale = Vector2(0.58, 0.04)
	eye.modulate = Color(0.5, 1.0, 0.65, 0.86)
	eye.z_index = 9
	e.add_child(eye)
	var tw := eye.create_tween()
	tw.tween_property(eye, "scale:y", 0.58, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.18)
	tw.tween_property(eye, "scale:y", 0.03, 0.09)
	tw.parallel().tween_property(eye, "modulate:a", 0.0, 0.11)
	tw.tween_callback(eye.queue_free)


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
	var hex_tex := "fx_hex_rune"
	if skin == "hellfire_inquisitor":
		hex_tex = "fx_inquisition_brand"
	elif skin == "arcane_warlock":
		hex_tex = "fx_eldritch_eye"
	var cast_rune := Sprite2D.new()
	cast_rune.texture = Art.tex(hex_tex)
	cast_rune.modulate = Art.hdr(Color(col, 1.0), 1.35)
	cast_rune.global_position = center
	cast_rune.scale = Vector2.ONE * (radius / 32.0)
	cast_rune.z_index = -4
	game.add_child(cast_rune)
	var cast_tw := cast_rune.create_tween()
	cast_tw.tween_property(cast_rune, "rotation", TAU * (1.0 if skin == "hellfire_inquisitor" else -1.0), 0.38)
	cast_tw.parallel().tween_property(cast_rune, "modulate:a", 0.0, 0.62)
	cast_tw.tween_callback(cast_rune.queue_free)
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
			if skin == "hellfire_inquisitor":
				_inquisitor_brand_stamp(e)
			elif skin == "arcane_warlock":
				_arcane_eye_curse(e)
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
	var mark_tex := "fx_hex_rune"
	if skin == "hellfire_inquisitor":
		mark_tex = "fx_inquisition_brand"
	elif skin == "arcane_warlock":
		mark_tex = "fx_eldritch_eye"
	elif skin == "eldritch_warlock":
		mark_tex = "fx/warlock_eldritch_curse_eye"
	rune.texture = Art.tex(mark_tex)
	rune.position = Vector2(0, -30)
	if skin == "eldritch_warlock":
		rune.hframes = 8
		rune.frame = 1
		rune.position = Vector2(0, -42)
		rune.scale = Vector2(0.52, 0.52)
		rune.z_index = 10
	else:
		rune.scale = Vector2(0.9, 0.9) if mark_tex == "fx_hex_rune" else Vector2(0.42, 0.42)
	e.add_child(rune)


## Visual-only curse beat. Enemy owns the authoritative 0.5s DoT clock and
## calls this after applying that unchanged tick; the watcher merely reacts.
func _eldritch_curse_tick(e: Enemy) -> void:
	if skin != "eldritch_warlock" or e == null or not is_instance_valid(e):
		return
	var watcher := e.get_node_or_null("hex_rune") as Sprite2D
	if watcher == null or watcher.texture != Art.tex("fx/warlock_eldritch_curse_eye"):
		return
	watcher.frame = 4
	var recoil := watcher.create_tween()
	recoil.tween_property(watcher, "scale", Vector2(0.58, 0.46), 0.035)
	recoil.tween_callback(watcher.set_frame.bind(5))
	recoil.tween_property(watcher, "scale", Vector2(0.52, 0.52), 0.075)
	var thread := Line2D.new()
	thread.width = 2.4
	thread.default_color = Color(0.72, 0.24, 1.0, 0.92)
	thread.z_index = 11
	thread.add_point(watcher.global_position)
	thread.add_point(e.global_position + Vector2(0, -7))
	game.add_child(thread)
	var core := Line2D.new()
	core.width = 0.75
	core.default_color = Color(0.96, 0.72, 1.0, 0.96)
	core.z_index = 12
	core.add_point(watcher.global_position)
	core.add_point(e.global_position + Vector2(0, -7))
	game.add_child(core)
	for line in [thread, core]:
		var fade: Tween = line.create_tween()
		fade.tween_property(line, "modulate:a", 0.0, 0.11)
		fade.tween_callback(line.queue_free)


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
	var pact_tex := "fx_dark_pact"
	if skin == "hellfire_inquisitor":
		pact_tex = "fx_inquisition_pyre"
	elif skin == "arcane_warlock":
		pact_tex = "fx_eldritch_eye"
	elif skin == "eldritch_warlock":
		pact_tex = "fx/mage_void_unravel"
	var seal := Sprite2D.new()
	seal.texture = Art.tex(pact_tex)
	seal.modulate = Color.WHITE if skin == "eldritch_warlock" else Color(col, 0.88)
	seal.scale = Vector2(5.2, 5.2)
	seal.z_index = -4
	if skin == "eldritch_warlock":
		seal.z_index = 8
	add_child(seal)
	if skin == "hellfire_inquisitor":
		seal.scale = Vector2(0.45, 0.45)
		_staged_segment_ring(self, Vector2.ZERO, Color(1.0, 0.44, 0.1, 0.86), 68.0, 6, 0.045, 0.28, "fx_inquisition_brand", true, true)
	elif skin == "arcane_warlock":
		seal.scale = Vector2(3.8, 0.18)
	elif skin == "eldritch_warlock":
		seal.hframes = 8
		seal.frame = 0
		seal.scale = Vector2.ONE * 2.18
	var seal_tw := seal.create_tween()
	if skin == "eldritch_warlock":
		for frame in range(1, 8):
			seal_tw.tween_interval(0.038)
			seal_tw.tween_callback(seal.set_frame.bind(frame))
		seal_tw.tween_property(seal, "modulate:a", 0.0, 0.10)
	elif skin == "hellfire_inquisitor":
		seal_tw.tween_property(seal, "scale", Vector2(4.4, 4.4), 0.18).set_trans(Tween.TRANS_BACK)
	elif skin == "arcane_warlock":
		seal_tw.tween_property(seal, "scale:y", 3.8, 0.18).set_trans(Tween.TRANS_BACK)
	if skin != "eldritch_warlock":
		seal_tw.tween_property(seal, "rotation", TAU * (-1.0 if skin == "arcane_warlock" else 1.0), 0.42)
		seal_tw.parallel().tween_property(seal, "modulate:a", 0.0, 0.58)
	seal_tw.tween_callback(seal.queue_free)
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
	if skin != "eldritch_warlock":
		_ring_fx(global_position, col, 170.0, true)
		game.burst(global_position, col, 18)
	# ...then the blast: dark rays lash outward from the pact's heart.
	for i in (0 if skin == "eldritch_warlock" else 8):
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


func _inquisition_rift_scene(pos: Vector2, radius: float) -> void:
	# Brands stamp the perimeter as an ordered interrogation circle. Heated
	# chain strokes then tighten from each brand into the pyre mouth.
	_staged_segment_ring(game, pos, Color(1.0, 0.44, 0.1, 0.92), radius * 0.72, 8, 0.075, 0.7, "fx_inquisition_brand", true, false)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		get_tree().create_timer(0.32 + 0.04 * i).timeout.connect(func() -> void:
			_beam_fx(pos + Vector2.from_angle(ang) * radius * 0.72, pos, Color(1.0, 0.34, 0.08), 0.32))


func _arcane_rift_open(mark: Sprite2D, pos: Vector2, radius: float) -> void:
	# Lid segments peel apart around the closed eye; the mark itself opens on
	# Y while these pieces hold the doorway's rim.
	mark.scale = Vector2(radius / 34.0, 0.06)
	_staged_segment_ring(game, pos, Color(0.4, 0.92, 0.6, 0.82), radius * 0.68, 6, 0.06, 0.72, "slashline", false, true)


func _eldritch_thread_rift_scene(pos: Vector2, radius: float) -> void:
	# Five circular chords fill the real Void Rift footprint. Their authored root
	# row is anchored to each ground chord, so the threads rise from beneath feet
	# rather than hovering over actors. This begins on the unchanged burst tick.
	var depth_bands := [-0.72, -0.36, 0.0, 0.36, 0.72]
	for band_index in depth_bands.size():
		var depth_fraction: float = depth_bands[band_index]
		var chord_factor := sqrt(maxf(0.0, 1.0 - depth_fraction * depth_fraction))
		var scale_x := radius * 2.0 * chord_factor / 224.0
		var scale_y := radius * 2.0 / 256.0 * 0.52 * lerpf(0.82, 1.0, chord_factor)
		var eruption := Sprite2D.new()
		eruption.texture = Art.tex("fx/mage_void_thread_eruption")
		eruption.hframes = 8
		eruption.frame = 2
		eruption.scale = Vector2(scale_x, scale_y)
		var ground := pos + Vector2(0.0, depth_fraction * radius)
		eruption.global_position = ground + Vector2(0.0, -82.0 * scale_y)
		eruption.flip_h = band_index % 2 == 1
		eruption.modulate = Color(1.0, 1.0, 1.0,
			0.82 if band_index == 2 else (0.68 if band_index in [1, 3] else 0.52))
		eruption.z_index = -3 + band_index
		game.add_child(eruption)
		var rip := eruption.create_tween()
		for frame in [3, 4, 5]:
			rip.tween_interval(0.052)
			rip.tween_callback(eruption.set_frame.bind(frame))
		rip.tween_interval(0.11)
		rip.tween_callback(eruption.set_frame.bind(6))
		rip.tween_interval(0.06)
		rip.tween_callback(eruption.set_frame.bind(7))
		rip.tween_property(eruption, "modulate:a", 0.0, 0.20)
		rip.tween_callback(eruption.queue_free)


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
	var rift_is_wide := skin == ""
	var rift_tex := "fx_void_rift"
	if skin == "hellfire_inquisitor":
		rift_tex = "fx_inquisition_pyre"
	elif skin == "arcane_warlock":
		rift_tex = "fx_eldritch_eye"
	elif skin == "eldritch_warlock":
		rift_tex = "telegraph"
	mark.texture = Art.tex(rift_tex)
	mark.modulate = Art.hdr(Color(col, 0.86), 1.3)
	mark.global_position = pos
	# The source rift is wide, so correct its aspect to the circular hit radius.
	mark.scale = Vector2(0.6, 0.96 if rift_is_wide else 0.6)
	mark.z_index = -6
	game.add_child(mark)
	if skin == "hellfire_inquisitor":
		_inquisition_rift_scene(pos, radius)
	elif skin == "arcane_warlock":
		_arcane_rift_open(mark, pos, radius)
	var mt := mark.create_tween()
	var mark_scale := Vector2.ONE * (radius / 32.0) if skin == "eldritch_warlock" else (Vector2(radius / 32.0, radius / 20.0) if rift_is_wide else (Vector2(1.85, 1.85) if skin == "hellfire_inquisitor" else Vector2(1.65, 1.65)))
	mt.tween_property(mark, "scale", mark_scale, 0.3)
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
	if skin == "eldritch_warlock":
		vortex.visible = false
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
	if skin == "eldritch_warlock":
		heart.visible = false
	var heart_tw := heart.create_tween()
	heart_tw.tween_property(heart, "scale", Vector2(3.2, 3.2), 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Four pull ticks, then the burst.
	var hard: bool = fx_copy.get("hard_pull", 0)
	for i in 4:
		await get_tree().create_timer(0.22).timeout
		if dead:
			break
		if skin == "":
			_ring_fx(pos, col, radius, true)
		for e in _enemies_within(pos, radius * 1.3):
			if skin == "arcane_warlock" and is_instance_valid(mark):
				_living_tether(mark, e, Color(0.36, 0.88, 0.58, 0.72), 0.3, true)
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
	if skin == "eldritch_warlock":
		_eldritch_thread_rift_scene(pos, radius)
	game.hud.flash_screen(Color(col, 1.0), 0.28 if skin == "arcane_warlock" else 0.5, 0.35)
	game.burst(pos, col, 26)
	game.burst(pos, Color(1, 1, 1), 10)
	if skin != "eldritch_warlock":
		_ring_fx(pos, col, radius * (0.46 if skin == "arcane_warlock" else (0.78 if skin == "hellfire_inquisitor" else 1.0)))
	if skin == "":
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
	for i in (0 if skin == "eldritch_warlock" else 10):
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
	scar.texture = Art.tex("fx_eldritch_eye" if skin == "arcane_warlock" else ("fx_inquisition_brand" if skin == "hellfire_inquisitor" else "glow"))
	scar.modulate = Color(col.r * 0.4, col.g * 0.25, col.b * 0.7, 0.5)
	scar.global_position = pos
	scar.scale = Vector2(radius / 26.0, radius / 26.0)
	scar.z_index = -5
	game.add_child(scar)
	var sct := scar.create_tween()
	if skin == "arcane_warlock":
		scar.scale = Vector2(radius / 34.0, radius / 34.0)
		for i in 3:
			sct.tween_property(scar, "scale:y", 0.08, 0.08)
			sct.tween_property(scar, "scale:y", radius / 34.0, 0.11)
		sct.tween_property(scar, "modulate:a", 0.0, 0.36)
	else:
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
