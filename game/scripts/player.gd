class_name Player extends "res://scripts/player_kits.gd"
## PLAYER, layer 4 of 4 — the ability dispatcher, survival (potion,
## damage intake, death) and the per-frame driver. See player_core.gd
## for the chain layout.


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	for key in cds:
		cds[key] = maxf(0.0, cds[key] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	theme_speed_time = maxf(0.0, theme_speed_time - delta)
	elixir_time = maxf(0.0, elixir_time - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	frozen_time = maxf(0.0, frozen_time - delta)
	rooted_time = maxf(0.0, rooted_time - delta)
	theme_guard_time = maxf(0.0, theme_guard_time - delta)
	aegis_time = maxf(0.0, aegis_time - delta)
	pact_time = maxf(0.0, pact_time - delta)
	var mregen := 6.0 if cls == "mage" else 4.0
	if s_passive() == "wellspring":
		mregen *= 1.5  # mage S weapon: +50% mana regen — cast through the storm
	mp = minf(max_mp, mp + mregen * delta)
	# Melee risk compensation: class-passive HP regeneration. Longer
	# fights (2x TTK) can't ask melee to eat hits with no comeback.
	since_hurt += delta
	dr_time = maxf(0.0, dr_time - delta)
	cast_haste_time = maxf(0.0, cast_haste_time - delta)
	dash_guard_time = maxf(0.0, dash_guard_time - delta)
	if nova_regen_time > 0.0:
		nova_regen_time = maxf(0.0, nova_regen_time - delta)
		gain_hp(max_hp * nova_regen * delta)  # Rimeheart heal-over-time
	stab_ls_time = maxf(0.0, stab_ls_time - delta)
	# Heal tick: fold accumulated discrete mends into one soft green cue
	# (~3/s max) so bulwark/holy/nova/kit heals are SEEN, not silent.
	heal_fx_cd = maxf(0.0, heal_fx_cd - delta)
	if heal_accum >= 1.0 and heal_fx_cd <= 0.0:
		heal_fx_cd = 0.3
		game.spawn_text(global_position + Vector2(0, -46), "+%d" % int(heal_accum), Color(0.5, 1.0, 0.6))
		game.burst(global_position, Color(0.55, 1.0, 0.6), 5)
		game.sfx("mend", 1.0, 0.0, -5.0)
		heal_accum = 0.0
	# Second Wind (round 14): the no-lifesteal ranged kit's sustain —
	# stay untouched for sw_delay and recovery kicks in. Spacing skill
	# IS the heal; one connected hit resets the clock.
	var regen_now := regen_pct
	if sw_regen > 0.0 and since_hurt >= sw_delay:
		regen_now += sw_regen
	if regen_now > 0.0 and not dead and hp > 0.0:
		hp = minf(max_hp, hp + max_hp * regen_now * delta)
	anim_t += delta

	# Hex watch: cursed enemies EXPLODE on death (chains: a detonation
	# that kills another cursed enemy sets IT off next frame).
	if not hexed.is_empty():
		var booms: Array = []
		for e in hexed.keys():
			if not is_instance_valid(e):
				hexed.erase(e)  # despawned without dying — no detonation
				wither.erase(e)
				continue
			if e.dying or e.hp <= 0.0:
				booms.append(e.global_position)
				hexed.erase(e)
				wither.erase(e)
				continue
			hexed[e] -= delta
			if hexed[e] <= 0.0:
				if e.has_node("hex_rune"):
					e.get_node("hex_rune").queue_free()
				hexed.erase(e)
				wither.erase(e)  # a lapsed curse resets the ramp
				continue
			# Wither ramp: a MAINTAINED hex deepens with uptime — the
			# warlock's damage grows with fight length (see balance.gd).
			var w_before: int = mini(int(float(wither.get(e, 0.0)) / Balance.WITHER_STACK_EVERY),
				Balance.WITHER_MAX_STACKS)
			wither[e] = float(wither.get(e, 0.0)) + delta
			var w_now: int = mini(int(float(wither[e]) / Balance.WITHER_STACK_EVERY),
				Balance.WITHER_MAX_STACKS)
			if w_now > w_before:
				game.spawn_text(e.global_position + Vector2(0, -52),
					"WITHER x%d" % w_now, Color(0.8, 0.45, 1.0))
		for pos in booms:
			_hex_detonate(pos)

	if storm_time > 0.0:
		storm_time -= delta
		storm_tick -= delta
		if storm_tick <= 0.0:
			storm_tick = 0.15
			_storm_strike()

	if dead:
		velocity = Vector2.ZERO
		return

	# ------------------------------------------------------------ movement
	var dir := _move_dir()
	if frozen_time > 0.0 or rooted_time > 0.0:
		dir = Vector2.ZERO  # crowd-controlled: the dodge is denied
	if dir != Vector2.ZERO:
		facing = dir
	var spd := speed * (1.25 if berserk_time > 0.0 else 1.0)
	if theme_speed_time > 0.0:
		spd *= 1.0 + theme_speed_amt
	spd *= hazard_speed  # ice patches boost, void rifts slow
	velocity = dir * spd + game.gust_vec  # sandstorm gusts shove everyone
	move_and_slide()

	# Speed-buff wind trail: a very faint gust off the back while a theme
	# speed boost carries you — the only held buff without an aura tell.
	wind_fx_t = maxf(0.0, wind_fx_t - delta)
	if theme_speed_time > 0.0 and dir != Vector2.ZERO and wind_fx_t <= 0.0:
		wind_fx_t = 0.1
		_wind_wisp(-dir)

	# Walk bob + face the aim target (or move direction).
	# NOTE: movement facing is normalized (max 1.0) while target facing is
	# in pixels — the threshold must be small enough for BOTH.
	var target := auto_aim()
	var look_x := target.global_position.x - global_position.x if target else facing.x
	if absf(look_x) > 0.4:
		look_sign = signf(look_x)
		# Left-facing art (Crawl sprites) flips the opposite way.
		sprite.flip_h = (look_x > 0.0) if face_left else (look_x < 0.0)
	if dir != Vector2.ZERO:
		sprite.position.y = -absf(sin(anim_t * 11.0)) * 3.0
		sprite.rotation = sin(anim_t * 11.0) * 0.06
	else:
		sprite.position.y = 0.0
		sprite.rotation = 0.0

	# Held weapon follows the facing side, with a light idle sway.
	if weapon_spr and weapon_spr.visible:
		var side := look_sign
		weapon_spr.position = Vector2(20.0 * side, 8.0 + sprite.position.y)
		weapon_spr.flip_h = side < 0.0
		if melee_swing > 0.0:
			melee_swing = maxf(0.0, melee_swing - delta)
			var prog := 1.0 - melee_swing / 0.16
			if melee_style == "stab":
				# Blade points along the stab line and lunges out-and-back.
				weapon_spr.rotation = melee_dir.angle() + PI / 2.0
				weapon_spr.position += melee_dir * sin(prog * PI) * 20.0
			else:
				weapon_spr.rotation = side * lerpf(-1.4, 0.9, melee_swing / 0.16)
		else:
			weapon_spr.rotation = side * (0.35 + sin(anim_t * 2.0) * 0.05)
		weapon_glow.position = weapon_spr.position

	# ------------------------------------------------------------- actions
	var binds: Dictionary = game.binds
	if Input.is_key_pressed(binds["a1"]):
		use_ability("a1")
	if Input.is_key_pressed(binds["a2"]):
		use_ability("a2")
	if Input.is_key_pressed(binds["a3"]):
		use_ability("a3")
	if Input.is_key_pressed(binds["ult"]):
		use_ability("ult")
	if Input.is_key_pressed(binds["potion"]):
		drink_potion()

	sprite.modulate.a = 0.55 if hurt_cd > 0.0 else 1.0

	# Buff aura pulse — the persistent "this is active" tell for every held
	# buff (berserk = red, Aegis = gold, Ward = arcane cyan, blood surge =
	# crimson-red, Pact = crimson, guard = blue). Classes don't share these
	# so the colors never collide in play.
	if berserk_time > 0.0 or theme_guard_time > 0.0 or aegis_time > 0.0 \
			or pact_time > 0.0 or dr_time > 0.0 or stab_ls_time > 0.0:
		aura.visible = true
		var shimmer := 9.0
		if berserk_time > 0.0:
			aura.modulate = Color(1.0, 0.25, 0.15, 0.7)
		elif aegis_time > 0.0:
			aura.modulate = Color(1.0, 0.85, 0.4, 0.65)
		elif dr_time > 0.0:
			aura.modulate = Color(0.45, 0.85, 1.0, 0.6)  # arcane shield
			shimmer = 16.0                               # crystalline flicker
		elif stab_ls_time > 0.0:
			aura.modulate = Color(0.95, 0.25, 0.30, 0.5)  # blood surge
		elif pact_time > 0.0 and theme_guard_time <= 0.0:
			aura.modulate = Color(0.9, 0.15, 0.35, 0.55)
		else:
			aura.modulate = Color(0.4, 0.6, 1.0, 0.6)
		var pulse := 2.2 + sin(anim_t * shimmer) * 0.25
		aura.scale = Vector2(pulse, pulse)
	else:
		aura.visible = false
	# The rage is visible ON the hero, not just around them.
	if sprite:
		sprite.modulate = Color(1.45, 0.55, 0.5) if berserk_time > 0.0 else Color(1, 1, 1)


# ============================================================ crowd control

## FROZEN: can't move OR cast for `dur` (Serane's Flash Freeze, Halla's
## sleep). Dodging AND acting are denied — the punish for being caught in
## the open. A no-op if already frozen longer.
func apply_freeze(dur: float) -> void:
	if dead:
		return
	frozen_time = maxf(frozen_time, dur)
	game.spawn_text(global_position + Vector2(0, -50), "FROZEN!", Color(0.6, 0.85, 1.0))
	game.burst(global_position, Color(0.7, 0.9, 1.0), 14)


## ROOTED: can't move for `dur`, but may still cast (Serane's Shatter
## Lance, ch6 vine roots). The kite is denied; the kit is not.
func apply_root(dur: float) -> void:
	if dead:
		return
	rooted_time = maxf(rooted_time, dur)
	game.spawn_text(global_position + Vector2(0, -50), "ROOTED!", Color(0.5, 0.8, 0.6))


# ================================================================= abilities

func use_ability(slot: String) -> void:
	if dead or cds[slot] > 0.0:
		return
	if frozen_time > 0.0:
		return  # frozen solid: no casting until you thaw (rooted may still cast)
	var cost := ability_cost(slot)
	if mp < cost:
		return
	cds[slot] = ability_cd(slot)
	# Blade cadence (round 35): the assassin's two spammables share a
	# lockout — Stab and Fan of Knives can each be spammed, but never
	# WOVEN together. Point-blank stab+knives was double dps with ALL
	# of it feeding the surge lifesteal: an immortality loop.
	if cls == "assassin" and slot in ["a1", "a3"]:
		var twin := "a3" if slot == "a1" else "a1"
		cds[twin] = maxf(cds[twin], cds[slot])
	mp -= cost
	var f := dm(slot)

	# Theme payload for this cast (behavior modifiers + tint).
	_tfx = _theme_fx(slot).duplicate()
	_tcolor = _theme_color(slot)
	_themed = not _tfx.is_empty()
	f *= float(_tfx.get("dmg_mult", 1.0))
	if _tfx.has("speed_buff"):
		theme_speed_time = 2.5
		theme_speed_amt = _tfx["speed_buff"]
	if _tfx.has("guard_buff"):
		theme_guard_time = 2.5
		theme_guard_amt = _tfx["guard_buff"]

	# Weapon "punch" on any cast: the held weapon pops for a beat.
	if weapon_spr and weapon_spr.visible:
		var wp := weapon_spr.create_tween()
		wp.tween_property(weapon_spr, "scale", Vector2(3.0, 3.0), 0.06)
		wp.tween_property(weapon_spr, "scale", Vector2(2.4, 2.4), 0.10)

	match [cls, slot]:
		["warrior", "a1"]:
			_melee_arc(1.0 * f, 96.0, "slash", {"stagger": 0.35, "knock": 330.0}, "swing", "sword")
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
				# Fury: a second backhand swing follows.
				var f2 := f
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * f2, 96.0, "slash", {"stagger": 0.2}, "swing", "sword"))
			if s_passive() == "kingsblade":
				var wave := Projectile.spawn(game, global_position + aim_dir(220.0) * 30.0, aim_dir(220.0) * 400.0, 0.0, true, "slash")
				wave.hit_player_mult = 0.6 * f
				wave.source_player = self
				wave.fx = _tfx.duplicate()
				wave.pierce = true
				wave.life = 0.6
		["warrior", "a2"]:
			# Charge: ram through everything in your path, stunning it.
			melee_swing = 0.16
			game.sfx("slam")
			# The ram parks you in the boss's face — a landing i-frame so the
			# gap-close itself isn't punished (round 44).
			_dash_strike(170.0 * float(_tfx.get("dash_mult", 1.0)), 1.3 * f,
				{"stun": 1.3, "knock": 220.0}, 0.0, Balance.MELEE_DASH_IFRAME)
			_ring_fx(global_position, _tcolor if _themed else Color(0.85, 0.85, 0.95), 80.0)
			if _tfx.get("end_slam", 0):
				# Earth: the charge ends in a ground-shattering slam.
				game.shake(5.0)
				game.sfx("slam", 0.8)
				game.burst(global_position, _tcolor, 14)
				_ring_fx(global_position, _tcolor, 130.0)
				for e in _enemies_within(global_position, 120.0):
					hit_enemy(e, 0.7 * f, {"stun": 1.0, "aoe": true})
		["warrior", "a3"]: _whirlwind(f)
		["warrior", "ult"]:
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
		["archer", "a1"]: _shoot(aim_dir(), 0.85 * f)
		["archer", "a2"]: _multishot(f)
		["archer", "a3"]: _tumble()
		["archer", "ult"]:
			storm_time = 3.0
			storm_fx = _tfx.duplicate()
			_ult_sfx()
			_ring_fx(global_position, _tcolor if _themed else Color(0.6, 1.0, 0.6), 190.0)
			game.hud.flash_screen(Color(0.6, 1.0, 0.6), 0.3, 0.35)
			game.spawn_text(global_position + Vector2(0, -60), "ARROW STORM!", Color(0.6, 1, 0.6))
		["mage", "a1"]:
			# Round 45: Firebolt +25% — the glass cannon earns its damage
			# now that Blink no longer hands it a free negate (twin/splash
			# themes scale off this base, lifting Wind's ST and Fire's AoE).
			if _tfx.get("twin", 0):
				# Wind: split the bolt.
				_cast_bolt(aim_dir().rotated(0.09), 0.94 * f)
				_cast_bolt(aim_dir().rotated(-0.09), 0.94 * f)
			else:
				_cast_bolt(aim_dir(), 1.5 * f)
		["mage", "a2"]: _frost_nova(f)
		["mage", "a3"]: _blink()
		["mage", "ult"]: _meteor()
		["assassin", "a1"]:
			# The quick-draw SWORD (round 30): longer reach, no slide —
			# the round-18 slide-step gave infinite mobility on a 0.3s
			# cadence and was quietly game-breaking. Mobility lives on
			# Shadow Dash now; the blade covers the distance instead.
			var cut := _melee_arc(Balance.STAB_MULT * f, 118.0, "slash", {"stagger": 0.3, "knock": 260.0}, "stab", "stab")
			if cut > 0:
				# Blood price, paid forward (round 25): dive in low, cut,
				# ult through the answer, heal it back through knives.
				_grant_stab_surge()
		["assassin", "a2"]: _shadow_dash(f)
		["assassin", "a3"]: _fan_of_knives(f)
		["assassin", "ult"]: _death_mark()
		["paladin", "a1"]:
			# Judgment CLOSES (round 22): out of arm's reach, the paladin
			# leaps to the prey before the hammer falls — dodge the
			# telegraph, then leap straight back onto the boss.
			var j_tgt := auto_aim(300.0)
			if j_tgt and global_position.distance_to(j_tgt.global_position) > 95.0:
				var j_from := global_position
				global_position = game.clamp_to_zone(
					j_tgt.global_position + (global_position - j_tgt.global_position).normalized() * 58.0,
					j_tgt.global_position)
				_afterimages(j_from, global_position, Color(1.0, 0.9, 0.55), 3)
				game.sfx("slam", 1.4)
				# Landing i-frame — but ONLY on the leap (round 44): closing
				# the gap shouldn't feed you to the boss's swing. Gated on the
				# >95px leap, so Judgment spam in melee (no leap) never chains
				# immunity off a 0.5s cd.
				hurt_cd = maxf(hurt_cd, Balance.MELEE_DASH_IFRAME)
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
		["paladin", "a2"]: _consecration(f)
		["paladin", "a3"]: _aegis()
		["paladin", "ult"]: _chains_of_wrath(f)
		# Round 45: -10% on the spam bolt so the DoT class trails the pure
		# single-target burst classes (assassin/archer) on boss TTK — the
		# wither ramp still pays it back on longer fights.
		["warlock", "a1"]: _cast_shadowbolt(aim_dir(), 0.9 * f)
		["warlock", "a2"]: _hex(f)
		["warlock", "a3"]: _dark_pact(f)
		["warlock", "ult"]: _void_rift(f)

	# COMBO: chance the ability doesn't go on cooldown and refunds mana.
	if slot != "ult" and randf() < Stats.combo_curve(combo):
		cds[slot] = 0.0
		mp = minf(max_mp, mp + cost)
		game.spawn_text(global_position + Vector2(0, -66), "COMBO!", Color(0.5, 1.0, 1.0))


## Deal damage to one enemy through the full stat pipeline.
## effects: stagger/stun/knock/pull/slow/burn (guaranteed), plus theme fx
## (dot/slow/stun_chance/echo/heal/vuln/crit_bonus/splash),
## "type": "true" for true damage, "aoe": lifesteal at 33%.


# ================================================================== survival

func drink_potion() -> void:
	if potion_cd > 0.0 or potions <= 0 or hp >= max_hp or dead:
		return
	potion_cd = 0.6
	potions -= 1
	game.fight_note_potion()
	hp = minf(max_hp, hp + max_hp * 0.6)
	game.sfx("potion")
	game.spawn_text(global_position + Vector2(0, -40), "+HP", Color(0.4, 1.0, 0.4))


## attacker (optional Enemy/Boss): resolves the hit through the SAME
## combat math as player attacks (Stats.resolve) — the attacker's dex
## shaves our evasion, its pen eats our resistance, and it can crit
## against our critres. Attacker-less damage (telegraphs, hazards)
## keeps the plain eva-then-res path.
func take_damage(amount: float, dmg_type := "phys", attacker: Node = null) -> void:
	if dead or hurt_cd > 0.0:
		return
	var res := physres if dmg_type == "phys" else magres
	if theme_guard_time > 0.0:
		res += theme_guard_amt
	if aegis_time > 0.0:
		res += aegis_amt
	var was_crit := false
	# Archer Tumble's post-roll nimbleness adds evasion CHANCE for a beat
	# (a soft cushion, not the old free negate). Bosses still shave it via
	# their DEX inside Stats.resolve, so accurate fights stay dangerous.
	var eff_eva := eva + (dodge_amt if dodge_time > 0.0 else 0.0)
	if attacker != null:
		var pen: float = attacker.physpen if dmg_type == "phys" else attacker.magpen
		var result: Dictionary = Stats.resolve(amount, dmg_type,
			attacker.crit, 1.5, pen, attacker.dex, res, eff_eva, critres)
		if result["miss"]:
			game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
			game.sfx("blink")
			return
		amount = result["dmg"]
		was_crit = result["crit"]
	else:
		if randf() < Stats.eva_curve(eff_eva):
			game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
			game.sfx("blink")
			return
		if dmg_type != "true":
			amount *= (1.0 - Stats.res_frac(res))
		if dash_guard_time > 0.0 and dmg_type != "true":
			# Mirrorstep (assassin S weapon): the un-dodgeable AoE (telegraphs,
			# hazards — the attacker-less path) is softened during the dash.
			amount *= 0.65
	hurt_cd = 0.6
	since_hurt = 0.0
	if dr_time > 0.0 and dmg_type != "true":
		# Arcane Ward (round 45): the mage's Blink cloak — a brief, strong
		# damage cut that SOFTENS a misstep instead of erasing it (the old
		# ward absorbed a whole hit). Skips true damage like plate DR.
		amount *= (1.0 - dr_amt)
	if flat_dr > 0.0 and dmg_type != "true":
		# Plate DR (round 21): flat, AFTER resists — immune to the res
		# curve's saturation, exclusive to the plate classes.
		amount *= (1.0 - flat_dr)
	hp -= amount
	game.fight_note_damage(amount, attacker)
	game.sfx("hurt")
	# Getting hit should FEEL like something went wrong: harder shake and
	# a red edge-flash, scaled a touch by how big the bite was.
	game.shake(9.0 if was_crit else 6.0)
	game.hud.flash_screen(Color(0.85, 0.1, 0.08),
		clampf(0.18 + amount / max_hp * 0.5, 0.18, 0.4), 0.3)
	if was_crit:
		game.spawn_text(global_position + Vector2(0, -40), "-%d CRIT!" % int(amount), Color(1.0, 0.5, 0.1))
	else:
		game.spawn_text(global_position + Vector2(0, -40), "-%d" % int(amount), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		game.on_player_died()
		return
	# Aegis redirect: while the shield is up, whoever strikes you is
	# smitten in return (everything in arm's reach pays for the blow).
	if aegis_time > 0.0:
		var near := _enemies_within(global_position, 100.0)
		if not near.is_empty():
			game.sfx("nova", 1.3)
			game.burst(global_position, Color(1.0, 0.9, 0.5), 10)
			_ring_fx(global_position, Color(1.0, 0.9, 0.5), 90.0)
			var saved := _tfx
			_tfx = aegis_fx
			for e in near:
				# The shield answers: light rips across the attacker.
				_smite_rip(e.global_position, Color(1.0, 0.92, 0.55))
				var eff := {"aoe": true}
				if aegis_fx.get("aegis_knock", 0):
					eff["knock"] = 320.0
				hit_enemy(e, aegis_reflect, eff)
			_tfx = saved
		elif attacker is Enemy and is_instance_valid(attacker) \
				and not (attacker as Enemy).dying and aegis_proj_left > 0:
			# The shield answers ARROWS too: a blocked projectile smites
			# its SOURCE at range — half strength, capped per cast.
			aegis_proj_left -= 1
			var shooter := attacker as Enemy
			game.sfx("nova", 1.3)
			_beam_fx(global_position, shooter.global_position, Color(1.0, 0.92, 0.55), 0.14)
			_smite_rip(shooter.global_position, Color(1.0, 0.92, 0.55))
			var saved_fx := _tfx
			_tfx = aegis_fx
			hit_enemy(shooter, aegis_reflect * Balance.AEGIS_PROJ_REFLECT, {"aoe": true})
			_tfx = saved_fx


func revive() -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
