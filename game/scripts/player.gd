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
	theme_guard_time = maxf(0.0, theme_guard_time - delta)
	aegis_time = maxf(0.0, aegis_time - delta)
	pact_time = maxf(0.0, pact_time - delta)
	mp = minf(max_mp, mp + (6.0 if cls == "mage" else 4.0) * delta)
	# Melee risk compensation: class-passive HP regeneration. Longer
	# fights (2x TTK) can't ask melee to eat hits with no comeback.
	if regen_pct > 0.0 and not dead and hp > 0.0:
		hp = minf(max_hp, hp + max_hp * regen_pct * delta)
	anim_t += delta

	# Hex watch: cursed enemies EXPLODE on death (chains: a detonation
	# that kills another cursed enemy sets IT off next frame).
	if not hexed.is_empty():
		var booms: Array = []
		for e in hexed.keys():
			if not is_instance_valid(e):
				hexed.erase(e)  # despawned without dying — no detonation
				continue
			if e.dying or e.hp <= 0.0:
				booms.append(e.global_position)
				hexed.erase(e)
				continue
			hexed[e] -= delta
			if hexed[e] <= 0.0:
				if e.has_node("hex_rune"):
					e.get_node("hex_rune").queue_free()
				hexed.erase(e)
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
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	dir = dir.normalized()
	if dir != Vector2.ZERO:
		facing = dir
	var spd := speed * (1.25 if berserk_time > 0.0 else 1.0)
	if theme_speed_time > 0.0:
		spd *= 1.0 + theme_speed_amt
	spd *= hazard_speed  # ice patches boost, void rifts slow
	velocity = dir * spd + game.gust_vec  # sandstorm gusts shove everyone
	move_and_slide()

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

	# Buff aura pulse (berserk = red, Aegis = gold, Pact = crimson,
	# guard = blue).
	if berserk_time > 0.0 or theme_guard_time > 0.0 or aegis_time > 0.0 or pact_time > 0.0:
		aura.visible = true
		if berserk_time > 0.0:
			aura.modulate = Color(1.0, 0.25, 0.15, 0.7)
		elif aegis_time > 0.0:
			aura.modulate = Color(1.0, 0.85, 0.4, 0.65)
		elif pact_time > 0.0 and theme_guard_time <= 0.0:
			aura.modulate = Color(0.9, 0.15, 0.35, 0.55)
		else:
			aura.modulate = Color(0.4, 0.6, 1.0, 0.6)
		var pulse := 2.2 + sin(anim_t * 9.0) * 0.25
		aura.scale = Vector2(pulse, pulse)
	else:
		aura.visible = false
	# The rage is visible ON the hero, not just around them.
	if sprite:
		sprite.modulate = Color(1.45, 0.55, 0.5) if berserk_time > 0.0 else Color(1, 1, 1)


# ================================================================= abilities

func use_ability(slot: String) -> void:
	if dead or cds[slot] > 0.0:
		return
	var cost := ability_cost(slot)
	if mp < cost:
		return
	cds[slot] = ability_cd(slot)
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
			_dash_strike(170.0 * float(_tfx.get("dash_mult", 1.0)), 1.3 * f, {"stun": 1.3, "knock": 220.0})
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
			if _tfx.get("twin", 0):
				# Wind: split the bolt.
				_cast_bolt(aim_dir().rotated(0.09), 0.7 * f)
				_cast_bolt(aim_dir().rotated(-0.09), 0.7 * f)
			else:
				_cast_bolt(aim_dir(), 1.1 * f)
		["mage", "a2"]: _frost_nova(f)
		["mage", "a3"]: _blink()
		["mage", "ult"]: _meteor()
		["assassin", "a1"]: _melee_arc(0.8 * f, 84.0, "slash", {"stagger": 0.3, "knock": 260.0}, "stab", "stab")
		["assassin", "a2"]: _shadow_dash(f)
		["assassin", "a3"]: _fan_of_knives(f)
		["assassin", "ult"]: _death_mark()
		["paladin", "a1"]:
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
		["warlock", "a1"]: _cast_shadowbolt(aim_dir(), 1.0 * f)
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
	if attacker != null:
		var pen: float = attacker.physpen if dmg_type == "phys" else attacker.magpen
		var result: Dictionary = Stats.resolve(amount, dmg_type,
			attacker.crit, 1.5, pen, attacker.dex, res, eva, critres)
		if result["miss"]:
			game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
			game.sfx("blink")
			return
		amount = result["dmg"]
		was_crit = result["crit"]
	else:
		if randf() < Stats.eva_curve(eva):
			game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
			game.sfx("blink")
			return
		if dmg_type != "true":
			amount *= (1.0 - Stats.res_frac(res))
	hurt_cd = 0.6
	hp -= amount
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


func revive() -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
