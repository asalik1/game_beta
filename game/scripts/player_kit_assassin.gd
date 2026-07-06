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
			var cut := _melee_arc(Balance.STAB_MULT * f, 118.0, "slash", {"stagger": 0.3, "knock": 260.0}, "stab", "stab")
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
	melee_dir = facing
	# NO i-frame (round 43): a short-cd dash with immunity was too
	# abusable once the refund made it semi-spammable. The dodge is the
	# MOVEMENT itself; only the ult's all-in commit grants immunity.
	game.sfx("stab")
	var start := global_position
	# stab_rider passes the talent scale only — the depth-tiered damage
	# mult (near/far) is applied per victim inside _dash_strike. The eaten-cdr
	# bonus rides the HIT mult only, leaving the surge rider (stab_rider = f) clean.
	var dash_mult := 1.2 * f * (1.0 + eaten * Balance.DASH_CDR_TO_DMG)
	var kills := _dash_strike(210.0 * float(_tfx.get("dash_mult", 1.0)), dash_mult, {"stagger": 0.4}, f, 0.0)
	if s_passive() == "mirrorstep":
		_mirrorstep_guard(start)
	if _tfx.get("trail_mist", 0):
		# Poison: the dash line blooms into a toxic wake.
		_mist((start + global_position) / 2.0, 110.0, 0.3, _tcolor, 2.5)
	if kills > 0 and _tfx.has("kill_refund"):
		# Shadow: a kill refunds most of the cooldown — but still floored, so
		# even room-chaining never drops into sub-second strobe territory.
		cds["a2"] = maxf(Balance.DASH_CONNECT_FLOOR,
			cds["a2"] * (1.0 - float(_tfx["kill_refund"])))
		game.spawn_text(global_position + Vector2(0, -60), "PHANTOM", Color(0.7, 0.5, 1.0))


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
		p.queue_free()


func _fan_of_knives(f := 1.0) -> void:
	game.sfx("knife", 1.55)  # short and SHARP — a dart leaving fingers
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.8, 0.85, 1.0))
	# The range damage is EARNED in close (round 37): thin chip on its
	# own, but the fan bites double while the stab surge runs.
	var surge_amp: float = Balance.KNIFE_SURGE_MULT if stab_ls_time > 0.0 else 1.0
	if _tfx.get("bloom", 0):
		# Poison: ONE venom blade that detonates into a toxin cloud
		# (chip-tuned: knives spam at stab cadence since round 25).
		var p := _proj(dir, Balance.KNIFE_BLOOM_MULT * surge_amp * f, "dart", 660.0)
		p.spin = false
		p.life = 0.45
		p.scale = Vector2(1.5, 1.5)
		p.fx["bloom_mist"] = 1
		p.fx["bloom_color"] = _tcolor
		return
	var count := int(_tfx.get("knives", 3))
	var step := float(_tfx.get("spread", 0.13))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), Balance.KNIFE_MULT * surge_amp * f, "dart", 760.0)
		p.spin = false
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))


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
	game.hud.flash_screen(Color(0.35, 0.0, 0.1), 0.5, 0.8)
	game.burst(global_position, Color(0.5, 0.2, 0.5), 12)
	# Untouchable through the execution (round 18): longer than Shadow
	# Dash's 0.5s — commit to the kill, not to the chip damage.
	hurt_cd = maxf(hurt_cd, 0.8)
	target.vuln_time = 5.0
	_stun_or_concuss(target, 0.6)
	if _tfx.has("mark_dot"):
		# Poison: the mark itself rots the target (and stacks toxin).
		target.apply_toxin(_dot_dps(target, current_atk() * float(_tfx["mark_dot"])), 5.0, Color(0.5, 1.2, 0.5))
	game.spawn_text(target.global_position + Vector2(0, -60), "DEATH MARK", Color(1, 0.25, 0.3))
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
		stroke.modulate = Color(1.0, 0.2, 0.3, 0.95)
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


## The execution itself: two shadows converge through the prey in an
## X (a slash and a 0.7x true hit each), then the assassin blinks
## BEHIND it and lands the killing stab (1.3x true, via the real stab
## arc). Shadow theme: a survivor under 30% is finished on the spot.
func _death_mark_execution(target: Enemy, execute := 0.0) -> void:
	for diag in [Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
		if not is_instance_valid(target) or target.dying:
			return
		var tpos: Vector2 = target.global_position
		_shadow_ghost(tpos - diag * 150.0, tpos + diag * 150.0)
		_execution_slash(tpos, diag.angle())
		game.sfx("stab")
		game.shake(3.5)
		game.burst(tpos, Color(1.0, 0.2, 0.3), 10)
		hit_enemy(target, 0.7, {"type": "true"})
		await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(target) or target.dying:
		return
	# The real blade: appear on the FAR side of the prey and stab back
	# through it — the full stab visual, not a bolt-on flash.
	var from := global_position
	var behind := (target.global_position - from).normalized()
	global_position = game.clamp_to_zone(
		target.global_position + behind * 46.0, target.global_position)
	_afterimages(from, global_position, Color(0.6, 0.25, 0.6), 3)
	game.shake(6.0)
	_melee_arc(1.3, 118.0, "slash", {"type": "true"}, "stab", "stab")
	if execute > 0.0 and is_instance_valid(target) and not target.dying \
			and target.hp < target.max_hp * 0.3:
		game.spawn_text(target.global_position + Vector2(0, -70), "EXECUTED", Color(1, 0.15, 0.25))
		game.burst(target.global_position, Color(0.6, 0.2, 0.6), 16)
		hit_enemy(target, execute, {"type": "true"})
