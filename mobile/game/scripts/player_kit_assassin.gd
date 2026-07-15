extends "res://scripts/player_kit_mage.gd"
## PLAYER, layer 6 of 9 — the ASSASSIN kit: dispatch + abilities.
## (The dash-stab rider itself fires inside player_combat's _dash_strike,
## and _grant_stab_surge lives down there with it — calls flow
## derived→base.) See player_core.gd for the chain layout.


func _use_assassin(slot: String, f: float) -> void:
	match slot:
		"a1":
			# The quick-draw SWORD (round 30): longer reach, no slide —
			# the round-18 slide-step gave infinite mobility on a 0.3s
			# cadence and was quietly game-breaking. Mobility lives on
			# Shadow Dash now; the blade covers the distance instead.
			# Sync the cut to the lunge frame (round 50): the slash/hit lands
			# WITH the thrust, not on the input frame.
			await get_tree().create_timer(swing_delay(Balance.STAB_STRIKE_DELAY)).timeout
			if dead or downed or ghost:
				return
			var cut := _melee_arc(ability_coeff("a1") * f, 118.0, "slash", {"stagger": 0.3, "knock": 260.0}, "stab", "stab")
			if cut > 0:
				# Blood price, paid forward (round 25): dive in low, cut,
				# ult through the answer, heal it back through knives.
				_grant_stab_surge()
		"a2": _shadow_dash(f)
		"a3": _fan_of_knives(f)
		"ult": _death_mark()


func _shadow_dash(f := 1.0) -> void:
	# Excess cdr the dash's cd floor "eats" is redirected here — into the
	# dash-through HIT (never the surge) and a slightly snappier animation,
	# so an over-hasted assassin's spare cdr is never wasted (round 46).
	var eaten := _dash_cdr_conversion()
	melee_swing = 0.16 * (1.0 - minf(0.10, eaten * Balance.DASH_CDR_TO_ANIM))
	melee_style = "stab"
	melee_dir = dash_vec()  # the blade thrusts along the travel line, not just L/R
	# NO i-frame (round 43): a short-cd dash with immunity was too
	# abusable once the refund made it semi-spammable. The dodge is the
	# MOVEMENT itself; only the ult's all-in commit grants immunity.
	game.sfx("stab")
	var start := global_position
	# stab_rider passes the talent scale only — the depth-tiered damage
	# mult (near/far) is applied per victim inside _dash_strike. The eaten-cdr
	# bonus rides the HIT mult only, leaving the surge rider (stab_rider = f) clean.
	var dash_mult := ability_coeff("a2") * f * (1.0 + eaten * Balance.DASH_CDR_TO_DMG)
	if _tfx.has("kill_refund"):
		# Shadow phantom step: ARM the refund window BEFORE the strike, so a kill
		# from ANY source in the next PHANTOM_REFUND_WINDOW seconds refunds the
		# dash — the dash's own kill (caught during _dash_strike below) still
		# counts, but so does the Fan or ult-stab that usually does the killing.
		# The actual refund lands in hit_enemy. Still floored (DASH_CONNECT_FLOOR),
		# so room-chaining never strobes.
		dash_refund_t = Balance.PHANTOM_REFUND_WINDOW
		dash_refund_frac = float(_tfx["kill_refund"])
	_dash_strike(210.0 * float(_tfx.get("dash_mult", 1.0)), dash_mult, {"stagger": 0.4}, f, 0.0)
	if s_passive() == "mirrorstep":
		_mirrorstep_guard(start)
	if _tfx.get("trail_mist", 0):
		# Poison: the dash line blooms into a toxic wake.
		_mist((start + global_position) / 2.0, 110.0, 0.3, _tcolor, 2.5)
	if skin == "blade_dancer":
		# Golden Ronin: a gold after-image streaks along the dash line (solid tint —
		# a plain modulate can't read as gold).
		_afterimages(start, global_position, Color(1.0, 0.82, 0.32), 4, 0.028, 0.24, true)


## Excess cdr past Shadow Dash's cd floor isn't wasted — this returns the
## seconds of cooldown the floor "eats" on a connecting dash, which feed the
## dash-HIT damage and a snappier animation (round 46). Assassin-only.
func _dash_cdr_conversion() -> float:
	var base_cd: float = Classes.ability(cls, "a2")["cd"]
	var whiff := maxf(Balance.DASH_WHIFF_FLOOR, base_cd * (1.0 - cdr))
	var refund: float = Balance.DASH_REFUND + dash_refund
	var unfloored := whiff * (1.0 - refund)
	return maxf(0.0, Balance.DASH_CONNECT_FLOOR - unfloored)


## Mirrorstep (assassin S weapon): a dash through fire turns aside nearby
## hostile projectiles — lashing their shooters back — and opens a brief
## window of reduced AoE damage. Offense-dodge for the storm you can't outrun;
## it rewards READING the volley and dashing INTO it, not free immunity.
func _mirrorstep_guard(start: Vector2) -> void:
	dash_guard_time = 0.25  # brief AoE damage-reduction while the dash reads
	var mid := (start + global_position) / 2.0
	var reach := start.distance_to(global_position) / 2.0 + 150.0
	for node in get_tree().get_nodes_in_group("projectiles"):
		var p := node as Projectile
		if p == null or p.friendly or mid.distance_to(p.global_position) > reach:
			continue
		var shooter := p.source_enemy as Enemy
		if is_instance_valid(shooter) and not shooter.dying:
			game.burst(shooter.global_position, Color(0.7, 0.5, 1.0), 6)
			hit_enemy(shooter, 0.8, {"aoe": true})
		game.burst(p.global_position, Color(0.7, 0.5, 1.0), 5)
		if p.net_visual and p.net_id > 0 and game.net_guest():
			# MP-10: the REAL bolt lives on the host — consume it there too,
			# or the deflected shot still lands via the damage RPC.
			game.net_session().guest_consume_projectile(p.net_id)
		p.queue_free()


func _fan_of_knives(f := 1.0) -> void:
	# Sync to the THROW animation's release (round 50): the arm winds up first,
	# so the blades must leave the HAND, not the input frame — otherwise they
	# fly out before the assassin has thrown. Aim + surge lock at fire; the
	# knives spawn after the short wind-up.
	var dir := aim_dir()
	# The range damage is EARNED in close (round 37): thin chip on its
	# own, but the fan bites double while the stab surge runs.
	var surge_amp: float = Balance.KNIFE_SURGE_MULT if stab_ls_time > 0.0 else 1.0
	await get_tree().create_timer(swing_delay(Balance.KNIFE_THROW_RELEASE)).timeout
	if dead or downed or ghost:
		return  # went down mid-windup — no knives leave the hand
	if skin == "phantom":
		game.sfx("stab", 0.85, 0.0, -3.0)  # Phantom: the Stab SFX, a little deeper
	else:
		game.sfx("knife", 1.55)  # short and SHARP — a dart leaving fingers
	_muzzle(dir, _tcolor if _themed else Color(0.8, 0.85, 1.0))
	# Golden Ronin (skin "blade_dancer") hurls spinning shuriken with a fading
	# after-image; every other assassin throws the point-first kunai.
	var ronin := skin == "blade_dancer"
	var throw_tex := "shuriken" if ronin else "dart"
	if _tfx.get("bloom", 0):
		# Poison: ONE venom blade that detonates into a toxin cloud
		# (chip-tuned: knives spam at stab cadence since round 25).
		var p := _proj(dir, Balance.KNIFE_BLOOM_MULT * surge_amp * f, throw_tex, 660.0)
		p.spin = ronin
		p.life = 0.45
		p.scale = Vector2(1.5, 1.5)
		p.fx["bloom_mist"] = 1
		p.fx["bloom_color"] = _tcolor
		_knife_glow(p)
		return
	var count := int(_tfx.get("knives", 3))
	var step := float(_tfx.get("spread", 0.13))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), ability_coeff("a3") * surge_amp * f, throw_tex, 760.0)
		p.spin = ronin
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
		_knife_glow(p)


## A soft variant-tinted glow riding a thrown kunai — poison green, blood
## red, shadow purple, etc. (default cold steel-blue when untuned). The halo
## sits BEHIND the blade (z −1) so the kunai silhouette stays legible over it.
## This is the code layer for "kunais glow by knife-throw variant" — the blade
## art is one sprite; the colour is a runtime tint, so no per-variant art.
func _knife_glow(p: Projectile) -> void:
	var col: Color = _tcolor if _themed else Color(0.70, 0.85, 1.0)
	if skin == "phantom":
		col = Color(0.45, 0.95, 1.0)          # glow: Phantom's spectral blue
		p.modulate = Color(0.80, 0.94, 0.98)  # lighter ghostly blade, matches his palette
		var tr := ProjTrail.new()             # a short spectral streak trailing each blade
		tr.proj = p
		tr.col = Color(0.5, 1.0, 0.92)
		game.add_child(tr)
	if skin == "blade_dancer":
		col = Color(1.0, 0.82, 0.35)          # halo: Golden Ronin's warm gold
		var echo := ShurikenEcho.new()        # spinning-star after-image
		echo.proj = p
		echo.tex = Art.tex("shuriken")
		echo.col = Color(1.0, 0.85, 0.45)
		game.add_child(echo)
	var g := Sprite2D.new()
	g.texture = Art.tex("glow")
	# Subtle aura BEHIND the blade — enough to tint the kunai by variant, not
	# so bright it blooms over the silhouette into a glowing line.
	g.modulate = Art.hdr(Color(col, 0.4))
	g.scale = Vector2(0.22, 0.22)
	g.z_index = -1
	p.add_child(g)


func _death_mark() -> void:
	var target := auto_aim()
	if target == null:
		cds["ult"] = 1.0
		return
	# EXECUTION (round 34, player-designed from the LoL reference): the
	# world darkens and the X mark is SET — the prey takes +50% damage
	# for 5s and wears a floating X. Two living shadows of the assassin
	# converge THROUGH it in an X, slashing, then the assassin himself
	# appears BEHIND it and drives the killing stab home.
	_ult_sfx()
	# The weave window (awakened Nightfang): for the mark's duration, Stab and Fan
	# of Knives lose their shared lockout and fire together — the ult IS the burst.
	deathmark_time = rider("ult", "amp_secs")
	var phantom := skin == "phantom"
	if phantom:
		# Phantom: a ghostly print of his splash art washes over the screen (in
		# place of the base ult's red flash) + a converging storm of 16 spectral
		# knives that rings the marked target (see PhantomBladeStorm). Behaviour
		# is unchanged — only the presentation reads spectral instead of bloody.
		# Bright maps (light backdrops) wash the wash out, so bump its opacity.
		var bright: bool = Terrains.get_terrain(game.terrain_by_zone[game.cur_room]).get("bright", false)
		var splash_op: float = Balance.PHANTOM_ULT_SPLASH_OPACITY_BRIGHT if bright else Balance.PHANTOM_ULT_SPLASH_OPACITY
		game.hud.flash_splash(Art.tex("phantom_splash"), splash_op, 0.85)
		var storm := PhantomBladeStorm.new()
		storm.target = target
		storm.game_ref = game
		game.add_child(storm)
	elif skin == "blade_dancer":
		# Golden Ronin: the world holds its breath — a soft gold wash as the mark
		# sets. No strike yet; the cut (Gilded Iai) lands on the killing stab.
		game.hud.flash_screen(Color(0.5, 0.4, 0.12), 0.32, 0.7)
		game.burst(global_position, Color(1.0, 0.85, 0.4), 12)
	else:
		game.hud.flash_screen(Color(0.35, 0.0, 0.1), 0.5, 0.8)
		game.burst(global_position, Color(0.5, 0.2, 0.5), 12)
		# The shadow LEFT BEHIND (Zed language): a dark echo holds the cast point.
		_cast_shadow(global_position)
	# Untouchable through the execution (round 18): commit to the kill.
	hurt_cd = maxf(hurt_cd, rider("ult", "iframe"))
	hurt_was_heavy = true  # untouchable means untouchable — heavy telegraphs too
	# The mark (+50%; apply_vuln is the MP-10 seam) + stun + optional poison — same.
	target.apply_vuln(rider("ult", "amp_secs"), 1.0 + float(_tfx.get("vuln", rider("ult", "amp"))))
	_stun_or_concuss(target, 0.6)
	if _tfx.has("mark_dot"):
		# Poison: the mark itself rots the target (and stacks toxin).
		target.apply_toxin(_dot_dps(target, current_atk() * float(_tfx["mark_dot"])), 5.0, Color(0.5, 1.2, 0.5), self)
	var mark_col: Color = Color(0.4, 0.72, 1.0) if phantom else \
		(Color(1.0, 0.82, 0.3) if skin == "blade_dancer" else Color(1, 0.25, 0.3))
	game.spawn_text(target.global_position + Vector2(0, -60), "DEATH MARK", mark_col)
	if not phantom:
		_mark_overhead_x(target)
	_death_mark_execution(target, float(_tfx.get("execute", 0.0)))


## The floating X over a marked target's head: two crossed blade
## slivers riding the enemy (freed with it) for the mark's 5s window.
func _mark_overhead_x(target: Enemy) -> void:
	var x_mark := Node2D.new()
	x_mark.position = Vector2(0, -56)
	x_mark.z_index = 30
	for ang in [0.7, -0.7]:
		var stroke := Sprite2D.new()
		stroke.texture = Art.tex("slashline")
		stroke.modulate = Color(1.0, 0.82, 0.3, 0.95) if skin == "blade_dancer" else Color(1.0, 0.2, 0.3, 0.95)
		stroke.rotation = ang
		stroke.scale = Vector2(0.4, 0.5)
		x_mark.add_child(stroke)
	target.add_child(x_mark)
	var tw := x_mark.create_tween().set_loops(5)
	tw.tween_property(x_mark, "position:y", -62.0, 0.5)
	tw.tween_property(x_mark, "position:y", -56.0, 0.5)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(x_mark):
		x_mark.queue_free()


## The vanish-echo left at the cast point: a dark, still copy of the
## assassin's current pose that holds where he stood, then dissolves with a
## smoke puff. Pure FX — reuses his own sprite, no new art.
func _cast_shadow(at: Vector2) -> void:
	if sprite == null:
		return
	var echo := Sprite2D.new()
	echo.texture = sprite.texture
	echo.hframes = sprite.hframes
	echo.vframes = sprite.vframes
	echo.frame = sprite.frame
	echo.flip_h = sprite.flip_h
	echo.scale = sprite.scale
	echo.global_position = at + sprite.position
	echo.modulate = Color(0.16, 0.08, 0.26, 0.92)  # a shadow, not a man
	echo.z_index = 5
	game.add_child(echo)
	game.burst(at, Color(0.4, 0.15, 0.5), 8)
	var tw := echo.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(echo, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(echo, "scale", echo.scale * 0.92, 0.5)
	tw.tween_callback(echo.queue_free)


## A living-shadow copy of the assassin dashing along a line.
func _shadow_ghost(from: Vector2, to: Vector2) -> void:
	if sprite == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.flip_h = to.x < from.x
	ghost.scale = sprite.scale
	ghost.global_position = from + sprite.position
	ghost.modulate = Color(0.3, 0.12, 0.4, 0.9)  # a shadow, not a man
	ghost.z_index = 6
	game.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "global_position", to + sprite.position, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.12)
	tw.tween_callback(ghost.queue_free)


## One execution slash across a point: the stab's slashline, red
## stroke over a white-hot core.
func _execution_slash(pos: Vector2, ang: float) -> void:
	for layer in 2:
		var rip := Sprite2D.new()
		rip.texture = Art.tex("slashline")
		rip.modulate = Color(1.0, 0.25, 0.35, 1.0) if layer == 0 else Color(1, 1, 1, 1.0)
		rip.global_position = pos
		rip.rotation = ang
		rip.scale = Vector2(2.0, 0.9) if layer == 0 else Vector2(1.7, 0.45)
		rip.z_index = 8 + layer
		game.add_child(rip)
		var rt := rip.create_tween()
		rt.tween_interval(0.1 if layer == 0 else 0.08)
		rt.tween_property(rip, "modulate:a", 0.0, 0.12)
		rt.tween_callback(rip.queue_free)


## Golden Ronin ult payoff — the "one cut" (Gilded Iai): a single massive gold
## cross-slash over the prey (two slashline strokes crossing in an X, gold over a
## white-hot core), a gold screen-flash, and a scatter of drifting gold glints.
## Pure spectacle; the damage rides the real stab arc that fires right after.
func _gilded_iai_strike(target) -> void:
	if not is_instance_valid(target):
		return
	var tpos: Vector2 = target.global_position
	game.sfx("slash")  # the crisp cut lands
	game.hud.flash_screen(Color(1.0, 0.82, 0.32), 0.55, 0.5)
	game.shake(8.0)
	game.burst(tpos, Color(1.0, 0.86, 0.42), 18)
	# Two big gold strokes cross in an X through the prey — the drawn cut, popping
	# from small to full so it reads as one decisive slash landing.
	for ang in [0.72, -0.72]:
		for layer in 2:
			var rip := Sprite2D.new()
			rip.texture = Art.tex("slashline")
			rip.modulate = Art.hdr(Color(1.0, 0.84, 0.38, 1.0)) if layer == 0 else Color(1.0, 1.0, 0.92, 1.0)
			rip.global_position = tpos
			rip.rotation = ang
			rip.scale = Vector2(1.4, 0.5) if layer == 0 else Vector2(1.2, 0.28)
			rip.z_index = 20 + layer
			game.add_child(rip)
			var rt := rip.create_tween()
			rt.tween_property(rip, "scale",
				Vector2(3.6, 1.0) if layer == 0 else Vector2(3.2, 0.62), 0.13) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			rt.parallel().tween_property(rip, "modulate:a", 0.0, 0.32)
			rt.tween_callback(rip.queue_free)
	# Falling gold glints — petals of light drifting down around the prey.
	for i in 10:
		var gl := Sprite2D.new()
		gl.texture = Art.tex("glow")
		gl.global_position = tpos + Vector2(randf_range(-58, 58), randf_range(-72, -8))
		gl.modulate = Art.hdr(Color(1.0, 0.86, 0.42, 0.9))
		gl.scale = Vector2(0.11, 0.11)
		gl.z_index = 19
		game.add_child(gl)
		var gt := gl.create_tween()
		gt.tween_property(gl, "global_position:y",
			gl.global_position.y + randf_range(48, 88), randf_range(0.5, 0.9)) \
			.set_trans(Tween.TRANS_SINE)
		gt.parallel().tween_property(gl, "modulate:a", 0.0, randf_range(0.5, 0.9))
		gt.tween_callback(gl.queue_free)


## The execution itself: two shadows converge through the prey in an
## X (a slash and a 0.7x true hit each), then the assassin blinks
## BEHIND it and lands the killing stab (1.3x true, via the real stab
## arc). Shadow theme: a survivor under 30% is finished on the spot.
func _death_mark_execution(target: Enemy, execute := 0.0) -> void:
	var phantom := skin == "phantom"
	for diag in [Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
		if not is_instance_valid(target) or target.dying:
			return
		var tpos: Vector2 = target.global_position
		if phantom:
			pass  # the blade storm plays the spectacle around the damage
		elif skin == "blade_dancer":
			# Golden Ronin: the stillness — a faint gold glint gathers on the prey;
			# no strike yet (the Gilded Iai one-cut lands on the killing stab below).
			game.burst(tpos, Color(1.0, 0.85, 0.4), 5)
			game.shake(1.2)
		else:
			# Zed shadows converge in an X.
			_shadow_ghost(tpos - diag * 150.0, tpos + diag * 150.0)
			_execution_slash(tpos, diag.angle())
			game.sfx("stab")
			game.shake(3.5)
			game.burst(tpos, Color(1.0, 0.2, 0.3), 10)
		hit_enemy(target, 0.7, {"type": "true"})  # DAMAGE — identical for both
		await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(target) or target.dying:
		return
	# The real blade: appear on the FAR side of the prey and stab back through
	# it — identical behaviour for both skins (teleport + killing stab arc).
	# Phantom only recolours the reappear blink to spectral blue; its stab arc
	# is already the ghostly one (see _melee_arc's skin check), and the blade
	# storm plays around all of this as the added spectacle.
	var from := global_position
	var behind := (target.global_position - from).normalized()
	global_position = game.clamp_to_zone(
		target.global_position + behind * 46.0, target.global_position)
	# Reappear stance (Zed language): he materializes behind the prey already
	# in the wide blades-out pose, then drives the killing stab home.
	play_action("ultidle")
	var blink_col: Color = Color(0.4, 0.72, 1.0) if phantom else \
		(Color(1.0, 0.82, 0.35) if skin == "blade_dancer" else Color(0.6, 0.25, 0.6))
	_afterimages(from, global_position, blink_col, 3, 0.05, 0.26, skin == "blade_dancer")
	game.shake(6.0)
	if skin == "blade_dancer":
		# Gilded Iai: a held beat behind the prey, then the one cut lands.
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(target) and not target.dying:
			_gilded_iai_strike(target)
	_melee_arc(ability_coeff("ult"), 118.0, "slash", {"type": "true"}, "stab", "stab")
	if execute > 0.0 and is_instance_valid(target) and not target.dying \
			and target.hp < target.max_hp * 0.3:
		game.spawn_text(target.global_position + Vector2(0, -70), "EXECUTED", Color(1, 0.15, 0.25))
		game.burst(target.global_position, Color(0.6, 0.2, 0.6), 16)
		hit_enemy(target, execute, {"type": "true"})
