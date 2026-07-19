extends "res://scripts/player_kit_warrior.gd"
## PLAYER, layer 4 of 9 — the ARCHER kit: dispatch + abilities.
## (_storm_strike is driven per-frame by player.gd while storm_time runs.)
## See player_core.gd for the chain layout.


func _use_archer(slot: String, f: float) -> void:
	match slot:
		"a1":
			_archer_draw_fx(false)
			# Loose on the bow's draw-release frame, not the input frame (the
			# draw-and-loose animation has a windup the arrow was firing ahead of).
			await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
			if dead or downed or ghost:
				return
			_hunt_rhythm_tick()
			_shoot(aim_dir(), ability_coeff("a1") * f)
		"a2": _multishot(f)
		"a3": _tumble()
		"ult":
			await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
			if dead or downed or ghost:
				return
			storm_time = 3.0
			storm_tick = 0.0
			storm_fx = _tfx.duplicate()
			_ult_sfx()
			# Skin storms announce in their element: Frostfall's sky goes pale
			# ice, Voidwraith's goes dark violet (Ronin pattern — colour only).
			var storm_call := _tcolor if _themed else Color(0.6, 1.0, 0.6)
			var storm_name := "ARROW STORM!"
			if skin == "frostfall_ranger":
				storm_call = Color(0.66, 0.90, 1.00)
				storm_name = "LANCE BLIZZARD!"
			elif skin == "voidwraith":
				storm_call = Color(0.55, 0.32, 0.90)
				storm_name = "VOID MAW!"
			# Elite and mythic Arrow Storms first call their own moon into view;
			# the same rain then keeps the locked gameplay hit timeline.
			if skin == "frostfall_ranger":
				_frostfall_blizzard_scene()
			elif skin == "voidwraith":
				_voidwraith_storm_scene()
			if skin == "":
				_ring_fx(global_position, storm_call, 190.0)
			game.hud.flash_screen(storm_call, 0.3, 0.35)
			game.spawn_text(global_position + Vector2(0, -60), storm_name, storm_call)


## Hunt rhythm (2026-07-09): the free +25% cap-exempt crit is gone — instead
## every Balance.HUNT_RHYTHM_SHOTS-th Quick Shot is a GUARANTEED crit (earned
## tempo; built crit gear still carries the other three arrows).
func _hunt_rhythm_tick() -> void:
	if ability_theme.get("a1", "") != "hunt":
		return
	hunt_rhythm += 1
	if hunt_rhythm >= Balance.HUNT_RHYTHM_SHOTS:
		hunt_rhythm = 0
		next_crit = true


func _shoot(dir: Vector2, mult: float) -> void:
	game.sfx("bow")
	var col: Color = _tcolor if _themed else Color(0.9, 1.0, 0.6)
	col = _skin_arrow_col(col)
	if next_crit:
		# The lethal arrow reads before it lands: a white-hot muzzle instead
		# of the theme tint (the hunt rhythm's 4th shot, or a lined-up shot).
		col = Color(1.0, 0.95, 0.75)
	_muzzle(dir, col)
	_skin_arrow(_proj(dir, mult, _skin_arrow_tex(), 520.0))


## Archer skin signature colour: Frostfall looses ice, Voidwraith looses
## void — over theme, like the assassin skins' knives (Ronin pattern).
func _skin_arrow_col(base: Color) -> Color:
	if skin == "frostfall_ranger":
		return Color(0.62, 0.88, 1.00)
	if skin == "voidwraith":
		return Color(0.62, 0.38, 0.95)
	return base


## Each ranger identity looses a distinct physical arrow: seasoned steel for
## base, a faceted ice shaft for Frostfall, and a barbed void head for
## Voidwraith.  Themes still colour the muzzle/impact, never the arrow body.
func _skin_arrow_tex() -> String:
	if skin == "frostfall_ranger":
		return "arrow_frost"
	if skin == "voidwraith":
		return "arrow_void_eye"
	return "arrow_base"


## Dress a loosed arrow in its skin: Frostfall's carry an ice-pale shaft and
## a frost glint riding behind the head; Voidwraith's fly dark with a violet
## void-streak trailing them (the Phantom knife-trail language).
func _skin_arrow(p: Projectile) -> void:
	# Base arrows still inherit the active ability-variant colour. Skin arrows
	# keep their authored material palette instead of being theme-recoloured.
	p.modulate = Color.WHITE.lerp(_tcolor, 0.55) if skin == "" and _themed else Color.WHITE
	if skin == "frostfall_ranger":
		var g := Sprite2D.new()
		g.texture = Art.tex("glow")
		g.modulate = Art.hdr(Color(0.60, 0.85, 1.0, 0.38))
		g.scale = Vector2(0.18, 0.18)
		g.z_index = -1
		p._vis.add_child(g)
		var snow := CPUParticles2D.new()
		snow.amount = 10
		snow.lifetime = 0.24
		snow.local_coords = false
		snow.direction = Vector2.LEFT
		snow.spread = 20.0
		snow.initial_velocity_min = 18.0
		snow.initial_velocity_max = 42.0
		snow.gravity = Vector2(0, 18)
		snow.scale_amount_min = 0.7
		snow.scale_amount_max = 1.5
		snow.color = Color(0.82, 0.96, 1.0, 0.8)
		p._vis.add_child(snow)
	elif skin == "voidwraith":
		# Same fading ribbon mechanism as Phantom's knives, recoloured violet.
		# The authored projectile is only an eye-bearing arrowhead; the ribbon
		# supplies the supernatural shaft without duplicating another full arrow.
		# Scale only the authored head, never the projectile root/collision.
		p.spr.scale = Vector2(0.55, 0.55)  # another 10% smaller from the reviewed 0.61 size
		var tr := ProjTrail.new()
		tr.proj = p
		# Alpha was already nearly maxed; the faintness came from an LDR violet
		# sitting below the bloom threshold. Lift the actual ribbon colour into
		# emissive range and keep it immediately beneath the projectile.
		tr.col = Color(0.92, 0.48, 1.35, 1.0)
		tr.max_points = 14       # +15% persistence, rounded to whole sampled points
		tr.width = 2.05
		tr.opacity = 1.0
		tr.draw_z = 4
		tr.core_width = 1.1
		tr.core_opacity = 0.96
		tr.core_col = Color(1.25, 0.72, 1.65)
		game.add_child(tr)


func _multishot(f := 1.0) -> void:
	_archer_draw_fx(true)
	# Loose the volley on the bow's draw-release frame, not the input frame.
	await get_tree().create_timer(Balance.ARCHER_LOOSE_DELAY).timeout
	if dead or downed or ghost:
		return
	# ONE release sound for the whole volley — five overlapping copies of
	# the same sample phase into a nasty digital flanging artifact.
	# Pitched lower than Quick Shot so the two are distinguishable.
	game.sfx("slash", 0.85)
	var dir := aim_dir()
	_muzzle(dir, _skin_arrow_col(_tcolor if _themed else Color(0.9, 1.0, 0.6)))
	var count := int(_tfx.get("knives", 5))
	var step := 0.05 if _tfx.get("narrow", 0) else float(_tfx.get("spread", 0.16))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), ability_coeff("a2") * f, _skin_arrow_tex(), 520.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
		_skin_arrow(p)


func _tumble() -> void:
	game.sfx("blink")
	# Round 45: the outright 0.5s negate on a 6s cd was too forgiving —
	# safety belongs to positioning, not a free button. The immunity is
	# now a split-second PERFECT-DODGE window (skill-timed against a hit),
	# and the roll leaves the archer NIMBLE — a soft evasion buff covers
	# the reposition so an average pilot still has margin, not a wall.
	hurt_cd = maxf(hurt_cd, 0.1)
	hurt_was_heavy = true  # the perfect-dodge window blocks heavy telegraph hits too
	dodge_time = rider("a3", "eva_secs")
	dodge_amt = rider("a3", "eva")
	if tumble_dr > 0.0:
		# Windrunner (talent): the landing steadies you — a DR window EARNED by
		# rolling, the archer's purchasable floor (same rail as Arcane Ward).
		dr_time = Balance.TUMBLE_DR_DUR
		dr_amt = tumble_dr
	var origin := global_position
	var dvec := dash_vec()
	if skin == "voidwraith":
		await _voidwraith_phase_tumble(origin, dvec)
	else:
		global_position = game.clamp_to_zone(origin + dvec * 130.0, origin)
		_aim_dash_pose(dvec)  # before the trail below, so the ghosts copy the pose
		if skin == "frostfall_ranger" and _action_dir_on:
			# PixelLab's eight dash sheets do not share the idle sheets' foot root.
			# Offset the one-shot by the measured final-frame delta so its handoff
			# to idle remains planted at the destination instead of side-stepping.
			sprite.offset += _frostfall_dash_anchor_fix(dvec)
	# The roll reads as motion: ghost trail + kicked-up dust behind you.
	# Skin rolls kick up their element instead of dust: Frostfall a puff of
	# rime, Voidwraith a swallow of dark (solid-tinted ghosts, Ronin-style).
	if skin == "frostfall_ranger":
		# The body moves normally; a single authored snowflake is what remains
		# behind. Hold one complete flake and fade it in place — cycling the full
		# strip here made its transitional poses look like horizontal movement.
		_frost_snowflake_fade(origin + Vector2(0, -10), game, 1.15, 0.0, 7, 0.30)
	elif skin == "voidwraith":
		pass  # departure/arrival portals and body visibility are sequenced above
	else:
		_afterimages(origin, global_position, _tcolor if _themed else Color(0.9, 0.95, 1.0), 2)
		game.burst(origin, Color(0.75, 0.7, 0.6), 6)
	if _tfx.has("burst_origin"):
		# Storm: discharge where you left.
		game.sfx("nova", 1.2)
		game.burst(origin, _tcolor, 12)
		for e in _enemies_within(origin, 110.0):
			hit_enemy(e, float(_tfx["burst_origin"]), {"aoe": true})
	if _tfx.get("mist_origin", 0):
		# Venom: leave a toxin cloud behind.
		_mist(origin, 95.0, 0.35, _tcolor, 2.5)
	if _tfx.get("next_crit", 0):
		# Hunt: line up the next shot.
		next_crit = true
		game.spawn_text(global_position + Vector2(0, -60), "LINED UP", Color(1, 0.7, 0.3))


## Source-pixel anchor corrections from each directional dash's final planted
## foot to the matching idle frame. Sprite2D applies these before hero scale.
func _frostfall_dash_anchor_fix(dvec: Vector2) -> Vector2:
	var offsets := {
		"e": Vector2(-10.0, 0.0), "ne": Vector2(30.0, 2.0),
		"n": Vector2(43.0, 1.0), "nw": Vector2(35.0, -4.0),
		"w": Vector2(23.0, 0.0), "sw": Vector2(47.0, 3.0),
		"s": Vector2(1.0, 0.0), "se": Vector2(14.0, 0.0),
	}
	return offsets.get(Art.dir8_suffix(dvec), Vector2.ZERO)


func _archer_draw_fx(volley: bool) -> void:
	if not skin in ["frostfall_ranger", "voidwraith"]:
		return
	var dir := aim_dir()
	if skin == "frostfall_ranger":
		# One complete radial snowflake opens around the bow, then shrinks and
		# fades in place. It never samples the old horizontal animation strip.
		_frost_snowflake_fade(dir * 27.0 + Vector2(0, -Balance.PROJ_MUZZLE_RISE),
			self, 1.15 if volley else 0.95, dir.angle(), 20, 0.24)
		return
	# Voidwraith needs no decorative arrowheads at the string. Those copies
	# survived beside/below the bow and read as duplicate projectiles; the real
	# eye-head plus its Phantom-style ribbon provides the complete cast read.


## One padded radial snowflake that shrinks and disappears without stepping
## sideways through a source sheet. Used for the bow and dash cues; falling
## blizzard flakes deliberately retain their temporal animation.
func _frost_snowflake_fade(pos: Vector2, parent: Node, size: float, rot: float,
		z: int, duration: float) -> void:
	var flake := Sprite2D.new()
	flake.texture = Art.tex("fx/frost_snowflake_radial")
	flake.rotation = rot
	# The dedicated texture is authored at 128px with generous transparent
	# padding. Preserve the old visual footprint through one uniform scale.
	var display_size := size * 0.62
	flake.scale = Vector2(display_size, display_size)
	flake.modulate = Color(0.84, 0.96, 1.0, 0.92)
	flake.z_index = z
	if parent == self:
		flake.position = pos
	else:
		flake.global_position = pos
	parent.add_child(flake)
	var fade := flake.create_tween()
	fade.tween_property(flake, "scale", Vector2(display_size * 0.56, display_size * 0.56), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.parallel().tween_property(flake, "modulate:a", 0.0, duration)
	fade.tween_callback(flake.queue_free)


func _voidwraith_phase_tumble(origin: Vector2, dvec: Vector2) -> void:
	var destination := game.clamp_to_zone(origin + dvec * 130.0, origin)
	# The dash clip contributes only its departure frame. The portal ruptures
	# behind it while the body rapidly vanishes; no travelling body/afterimages.
	if strip_frames > 0:
		strip_t = 0.0
		sprite.frame = 0
	_fx_flash("void_eye_portal", origin + Vector2(0, -24), 8, {
		"scale": 1.12, "z": 9, "frame_time": 0.035, "fade": 0.08,
	})
	var vanish := sprite.create_tween()
	vanish.tween_property(sprite, "modulate:a", 0.0, 0.065)
	if weapon_spr != null:
		var weapon_out := weapon_spr.create_tween()
		weapon_out.tween_property(weapon_spr, "modulate:a", 0.0, 0.055)
	if _skin_ambient != null:
		var ambient_out := _skin_ambient.create_tween()
		ambient_out.tween_property(_skin_ambient, "modulate:a", 0.0, 0.055)
	await get_tree().create_timer(0.085).timeout
	global_position = destination
	_aim_dash_pose(dvec)
	# Destination begins closed, ruptures around the final dash frame, and the
	# body snaps back into visibility while the eye is fully open.
	if strip_frames > 0:
		strip_t = maxf(0.0, float(strip_frames - 1) / maxf(strip_fps, 1.0))
		sprite.frame = strip_frames - 1
	_fx_flash("void_eye_portal", destination + Vector2(0, -24), 8, {
		"scale": 1.12, "z": 9, "frame_time": 0.035, "fade": 0.08,
	})
	await get_tree().create_timer(0.09).timeout
	var appear := sprite.create_tween()
	appear.tween_property(sprite, "modulate:a", 1.0, 0.055)
	if weapon_spr != null:
		var weapon_in := weapon_spr.create_tween()
		weapon_in.tween_property(weapon_spr, "modulate:a", 1.0, 0.055)
	if _skin_ambient != null:
		var ambient_in := _skin_ambient.create_tween()
		ambient_in.tween_property(_skin_ambient, "modulate:a", 1.0, 0.055)


func _storm_target_center() -> Vector2:
	var targets: Array = _enemies_within(global_position, 560.0)
	if targets.is_empty():
		return global_position + facing * 150.0
	var total := Vector2.ZERO
	for enemy in targets:
		total += enemy.global_position
	return total / float(targets.size())


func _frostfall_blizzard_scene() -> void:
	storm_center = _storm_target_center()
	_frostfall_storm_field()
	# The cast immediately seeds the vertical whiteout. No moon/emblem appears
	# over the archer; the authored snowflake strip exists inside the weather.
	for i in Balance.FROSTFALL_ULT_PREFALL_FLAKES:
		get_tree().create_timer(0.035 * i).timeout.connect(_blizzard_prefall.bind(i))


func _frostfall_storm_field() -> void:
	# Circular ground-layer gradient; unlike a stretched texture it cannot read
	# as a vertical band. The low-energy light is the only upward fade.
	var field := FrostStormField.new()
	field.global_position = storm_center
	field.scale = Vector2(0.94, 0.94)
	field.modulate.a = 0.0
	field.z_index = -2
	game.add_child(field)
	var field_tween := field.create_tween()
	field_tween.tween_property(field, "modulate:a", 1.0, 0.18)
	field_tween.parallel().tween_property(field, "scale", Vector2.ONE, 0.24)
	field_tween.tween_interval(2.44)
	field_tween.tween_property(field, "modulate:a", 0.0, 0.30)
	field_tween.tween_callback(field.queue_free)

	var field_light := Art.light(Color(0.50, 0.84, 1.0), 245.0, 0.0)
	field_light.global_position = storm_center + Vector2(0, -26)
	game.add_child(field_light)
	var light_tween := field_light.create_tween()
	light_tween.tween_property(field_light, "energy", 0.12 * game.light_mult, 0.18)
	light_tween.tween_interval(2.48)
	light_tween.tween_property(field_light, "energy", 0.0, 0.26)
	light_tween.tween_callback(field_light.queue_free)


func _blizzard_prefall(index: int) -> void:
	if storm_time <= 0.0:
		return
	var spread := Vector2(randf_range(-170.0, 170.0), randf_range(-55.0, 70.0))
	_falling_blizzard_flake(storm_center + spread, index)


func _falling_blizzard_flake(ground: Vector2, phase: int) -> void:
	var flake := Sprite2D.new()
	flake.texture = Art.tex("fx/frost_snowflake_cast")
	flake.hframes = 8
	flake.frame = 2 + phase % 4
	flake.global_position = ground + Vector2(randf_range(-16.0, 16.0), randf_range(-205.0, -155.0))
	flake.rotation = randf_range(-0.45, 0.45)
	var size := randf_range(0.28, 0.54)
	flake.scale = Vector2(size, size)
	flake.modulate = Color(0.86, 0.97, 1.0, randf_range(0.58, 0.92))
	flake.z_index = 25
	game.add_child(flake)
	var fall := flake.create_tween()
	fall.tween_property(flake, "global_position", ground + Vector2(0, 18), randf_range(0.28, 0.40)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(flake, "rotation", flake.rotation + randf_range(-0.5, 0.5), 0.34)
	fall.tween_property(flake, "modulate:a", 0.0, 0.08)
	fall.tween_callback(flake.queue_free)
	var animate := flake.create_tween()
	for frame_index in [3, 4, 5, 6, 7]:
		animate.tween_interval(0.045)
		animate.tween_callback(flake.set_frame.bind(frame_index))


func _frost_lance_drop(ground: Vector2, primary: bool) -> void:
	var lance := Sprite2D.new()
	lance.texture = Art.tex("frost_ice_lance")
	lance.global_position = ground + Vector2(randf_range(-8.0, 8.0), -190.0)
	lance.scale = Vector2(1.05, 1.05) if primary else Vector2(0.72, 0.72)
	lance.modulate = Color(1, 1, 1, 1.0 if primary else 0.62)
	lance.z_index = 30 if primary else 21
	game.add_child(lance)
	var fall := lance.create_tween()
	fall.tween_property(lance, "global_position:y", ground.y, 0.13 if primary else 0.17) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(lance.queue_free)
	if primary:
		get_tree().create_timer(0.13).timeout.connect(func() -> void:
			_fx_flash("frost_snowflake_cast", ground, 8, {
				"scale": 0.58, "z": 24, "frame_time": 0.022, "fade": 0.06,
			})
			game.burst(ground, Color(0.76, 0.94, 1.0), 7))


func _voidwraith_storm_scene() -> void:
	storm_center = _storm_target_center()
	game.hud.flash_screen(Color(0.16, 0.06, 0.28), 0.22, 0.5)
	var portal := Sprite2D.new()
	portal.texture = Art.tex("fx/void_portal_ground")
	portal.hframes = 8
	portal.frame = 0
	portal.global_position = storm_center
	portal.scale = Vector2(2.45, 2.45)
	portal.modulate = Color(0.90, 0.76, 1.0, 0.94)
	# Ground-layer presentation: combatants remain readable over the aperture.
	portal.z_index = -2
	game.add_child(portal)
	var portal_eye := Sprite2D.new()
	portal_eye.texture = Art.tex("fx/void_portal_eye")
	portal_eye.hframes = 8
	portal_eye.frame = 0
	portal_eye.global_position = storm_center
	# Keep the eye dominant but inside the ring of tentacle roots. The previous
	# sclera covered those pivots, exposing every dark base/stem against white;
	# at this scale all eight roots land on the portal's own dark aperture.
	portal_eye.scale = Vector2(1.20, 1.20)
	portal_eye.modulate = Color(0.96, 0.82, 1.0, 0.0)
	# The eye is part of that ground aperture too. Only the independent
	# tentacles rise above mobs/bosses and strike through their silhouettes.
	portal_eye.z_index = -1
	game.add_child(portal_eye)

	# Eight independent roots, evenly spaced on the circular aperture. Each actor
	# owns its idle/attack playback and turns around its fixed root toward one
	# of the storm's victims; no monolithic tentacle painting and no stretching.
	for old_tentacle in void_tentacles:
		if is_instance_valid(old_tentacle):
			old_tentacle.queue_free()
	void_tentacles.clear()
	void_tentacle_cursor = 0
	void_target_cursor = 0
	var idle_tex := Art.tex("fx/void_tentacle_idle")
	var attack_tex := Art.tex("fx/void_tentacle_attack")
	var root_radius := 92.0
	for index in 8:
		var angle := -PI / 2.0 + TAU * float(index) / 8.0
		var tentacle := VoidTentacle.new()
		tentacle.global_position = storm_center + Vector2.from_angle(angle) * root_radius
		tentacle.z_index = 11 + int(roundf(sin(angle) * 2.0))
		game.add_child(tentacle)
		tentacle.setup(idle_tex, attack_tex, float(index) * 0.087, angle)
		tentacle.modulate.a = 0.0
		tentacle.scale = Vector2(0.28, 0.28)
		var emerge := tentacle.create_tween()
		emerge.tween_interval(float(index) * 0.028)
		emerge.tween_property(tentacle, "modulate:a", 1.0, 0.12)
		emerge.parallel().tween_property(tentacle, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		void_tentacles.append(tentacle)

	# Open, hold with a subtle two-frame pulse during all twenty hit beats,
	# then seal. Tentacles retract only after the last delayed contact lands.
	var portal_anim := portal.create_tween()
	for opening_frame in [1, 2, 3]:
		portal_anim.tween_interval(0.06)
		portal_anim.tween_callback(portal.set_frame.bind(opening_frame))
	for pulse in 13:
		portal_anim.tween_interval(0.20)
		portal_anim.tween_callback(portal.set_frame.bind(4 + pulse % 2))
	for closing_frame in [6, 7]:
		portal_anim.tween_interval(0.10)
		portal_anim.tween_callback(portal.set_frame.bind(closing_frame))
	portal_anim.tween_property(portal, "modulate:a", 0.0, 0.12)
	portal_anim.tween_callback(portal.queue_free)
	var eye_reveal := portal_eye.create_tween()
	eye_reveal.tween_interval(0.12)
	eye_reveal.tween_property(portal_eye, "modulate:a", 0.92, 0.14)
	var eye_anim := portal_eye.create_tween()
	eye_anim.tween_interval(0.18)
	# The iris searches the field left/up/right/down while the eight rooted
	# tentacles take turns striking. The eye body stays fixed and dominant.
	for gaze_frame in 16:
		eye_anim.tween_interval(0.16)
		eye_anim.tween_callback(portal_eye.set_frame.bind((gaze_frame + 1) % 8))
	eye_anim.tween_property(portal_eye, "modulate:a", 0.0, 0.12)
	eye_anim.tween_callback(portal_eye.queue_free)
	get_tree().create_timer(3.14).timeout.connect(_dismiss_void_tentacles)


func _dismiss_void_tentacles() -> void:
	for tentacle in void_tentacles:
		if not is_instance_valid(tentacle):
			continue
		var retract: Tween = tentacle.create_tween()
		retract.tween_property(tentacle, "scale", Vector2(0.20, 0.20), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		retract.parallel().tween_property(tentacle, "modulate:a", 0.0, 0.14)
		retract.tween_callback(tentacle.queue_free)
	void_tentacles.clear()


func _storm_strike() -> void:
	var e: Enemy = null
	if storm_fx.get("focus", 0):
		# Hunt: every arrow hunts YOUR target.
		e = auto_aim(560.0)
	else:
		var targets := _enemies_within(global_position, 560.0)
		if not targets.is_empty():
			e = targets[randi() % targets.size()]
	if e == null:
		return
	if skin == "frostfall_ranger":
		# One primary lance marks the unchanged gameplay hit. The remaining
		# lances and flakes are weather only, thickened into a real visual blizzard
		# without adding ticks, targets, damage, or extra impact bursts.
		game.sfx("knife", 0.82)
		_frost_lance_drop(e.global_position, true)
		for i in Balance.FROSTFALL_ULT_DECORATIVE_LANCES_PER_TICK:
			_frost_lance_drop(storm_center + Vector2(randf_range(-175.0, 175.0), randf_range(-70.0, 85.0)), false)
		for i in Balance.FROSTFALL_ULT_FLAKES_PER_TICK:
			_falling_blizzard_flake(storm_center + Vector2(randf_range(-185.0, 185.0), randf_range(-75.0, 90.0)), i)
		_apply_archer_storm_hit(e)
		return
	if skin == "voidwraith":
		# Cycle targets rather than randomly dog-piling one victim. The six
		# independently rooted actors take turns, so the full circle attacks all
		# enemies inside the same 560px Arrow Storm acquisition range.
		var void_targets := _enemies_within(global_position, 560.0)
		if void_targets.is_empty():
			return
		e = void_targets[void_target_cursor % void_targets.size()]
		void_target_cursor += 1
		game.sfx("stab", 0.72, 0.0, -4.0)
		if not void_tentacles.is_empty():
			var tentacle = void_tentacles[void_tentacle_cursor % void_tentacles.size()]
			void_tentacle_cursor += 1
			if is_instance_valid(tentacle):
				tentacle.strike(e, _void_tentacle_contact)
				return
		_void_tentacle_contact(e)
		return
	# Falling-arrow whoosh (deep-pitched), NOT the synth laser zap.
	game.sfx("knife", 0.75)
	var storm_col := _theme_color("ult") if ability_theme.get("ult", "") != "" else Color(0.7, 1.0, 0.7)
	# Skin rain: ice-shafted hail / dark void bolts (skin wins over theme).
	if skin == "frostfall_ranger":
		storm_col = Color(0.70, 0.90, 1.00)
	elif skin == "voidwraith":
		storm_col = Color(0.58, 0.34, 0.92)
	# An arrow visibly falls out of the sky onto the target.
	var arrow := Sprite2D.new()
	# Arrow Storm always uses the new physical arrow set; it never falls back
	# to the legacy procedural "arrow" glyph.
	arrow.texture = Art.tex(_skin_arrow_tex())
	arrow.modulate = Color.WHITE.lerp(_tcolor, 0.55) if skin == "" and _themed else Color.WHITE
	arrow.rotation = PI / 2.0
	arrow.scale = Vector2(2, 2)
	arrow.global_position = e.global_position + Vector2(randf_range(-10, 10), -160)
	arrow.z_index = 30
	game.add_child(arrow)
	# Sky arrows need the same tight glow as a Quick Shot — it rides BEHIND the
	# shaft and turns with the fall, so the impact read stays a real arrow.
	var arrow_glow := Sprite2D.new()
	arrow_glow.texture = Art.tex("glow")
	arrow_glow.modulate = Art.hdr(Color(storm_col, 0.78))
	arrow_glow.scale = Vector2(1.25, 0.48)
	arrow_glow.z_index = -1
	arrow.add_child(arrow_glow)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position:y", e.global_position.y, 0.11)
	tween.tween_callback(arrow.queue_free)
	game.burst(e.global_position, storm_col)
	_ring_fx(e.global_position, storm_col, 42.0)
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	# The storm rains for 3s while the archer keeps casting — resolve each
	# arrow with the ULT's payload snapshot, not whatever _tfx holds now
	# (the Consecration save-restore idiom).
	var saved := _tfx
	_tfx = storm_fx
	hit_enemy(e, ability_coeff("ult"), eff)
	_tfx = saved


func _apply_archer_storm_hit(enemy: Enemy) -> void:
	var effects := storm_fx.duplicate()
	effects["aoe"] = true
	var saved := _tfx
	_tfx = storm_fx
	hit_enemy(enemy, ability_coeff("ult"), effects)
	_tfx = saved


func _void_tentacle_contact(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	game.burst(enemy.global_position, Color(0.66, 0.36, 1.0), 7)
	_ring_fx(enemy.global_position, Color(0.48, 0.18, 0.78), 34.0)
	_apply_archer_storm_hit(enemy)
