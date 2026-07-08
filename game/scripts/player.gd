class_name Player extends "res://scripts/player_kit_warlock.gd"
## PLAYER, layer 9 of 9 — the ability dispatcher, survival (potion,
## damage intake, death) and the per-frame driver. See player_core.gd
## for the chain layout.


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	if strip_frames > 0:
		_advance_clip(delta)
	for key in cds:
		cds[key] = maxf(0.0, cds[key] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	potion_swap_cd = maxf(0.0, potion_swap_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	theme_speed_time = maxf(0.0, theme_speed_time - delta)
	elixir_time = maxf(0.0, elixir_time - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	frozen_time = maxf(0.0, frozen_time - delta)
	rooted_time = maxf(0.0, rooted_time - delta)
	chill_time = maxf(0.0, chill_time - delta)
	if chill_time <= 0.0:
		chill_mult = 1.0
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
	last_rites_cd = maxf(0.0, last_rites_cd - delta)
	judgment_leap_cd = maxf(0.0, judgment_leap_cd - delta)
	# Grit (warrior, round 48): the stacks live only while the grind does —
	# go unhit for the window and they die. Kiting starves the juggernaut.
	if grit_time > 0.0:
		grit_time = maxf(0.0, grit_time - delta)
		if grit_time <= 0.0:
			grit_stacks = 0
	if shield > 0.0:
		shield = maxf(0.0, shield - max_hp * 0.05 * delta)  # Transfusion buffer fades
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
	if grit_stacks > 0:
		regen_now += grit_regen * grit_stacks  # Grit: the beating IS the mending
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
				if curse_spread > 0.0 and randf() < minf(1.0, curse_spread):
					_spread_curse(e.global_position)  # Contagion: the curse leaps onward
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
	if chill_time > 0.0:
		spd *= chill_mult  # a mob's frost aura drags at your feet
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
		# Left-facing art (Crawl sprites) flips the opposite way. A directional
		# aim pose sets its own facing, so don't fight it while it holds.
		if not _dir_pose_active:
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
	if Input.is_key_pressed(binds.get("potion_next", KEY_R)) and potion_swap_cd <= 0.0:
		potion_swap_cd = 0.3
		cycle_potion()

	sprite.modulate.a = 0.55 if hurt_cd > 0.0 else 1.0

	# Buff aura pulse — the persistent "this is active" tell for every held
	# buff (berserk = red, Aegis = gold, Ward = arcane cyan, blood surge =
	# crimson-red, Pact = crimson, guard = blue). Classes don't share these
	# so the colors never collide in play.
	if berserk_time > 0.0 or theme_guard_time > 0.0 or aegis_time > 0.0 \
			or pact_time > 0.0 or dr_time > 0.0 or stab_ls_time > 0.0 \
			or (cls == "paladin" and paladin_mode == "retribution"):
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
		elif theme_guard_time > 0.0:
			aura.modulate = Color(0.4, 0.6, 1.0, 0.6)
		else:
			# Retribution stance: a held STATE, not a timer — it keeps its
			# ember-orange tell until the paladin swaps back to Holy (the
			# timed buffs above outrank it while they run).
			aura.modulate = Color(1.0, 0.45, 0.22, 0.5)
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


## CHILLED: movement slowed to `mult` while inside a mob's frost aura.
## Refreshed every frame the aura holds you (mob frost_aura trait) — no
## text spam; the walking-through-molasses feel is the tell.
func apply_chill(mult: float, dur := 0.35) -> void:
	if dead:
		return
	chill_mult = minf(chill_mult, mult) if chill_time > 0.0 else mult
	chill_time = maxf(chill_time, dur)


# ================================================================= abilities

# -------------------------------------------------- clip state machine ---
# Locomotion (idle/walk/run) loops; a one-shot action clip plays through once
# then hands back to locomotion; death latches the final frame. Called every
# physics frame whenever a class sheet is installed (strip_frames > 0).
func _advance_clip(delta: float) -> void:
	if _clip_locked:
		strip_t += delta
		sprite.frame = mini(strip_frames - 1, int(strip_t * strip_fps))
		return
	if _dir_pose_active:
		# Directional animation: play this direction's K sub-frames (windup ->
		# action) over DIR_ANIM_DUR, then drop back to locomotion. Only this
		# direction's frames advance — the aim was locked in at cast time.
		_dir_pose_t += delta
		var sub := int(_dir_pose_t / DIR_ANIM_DUR * float(_dir_k))
		if sub < _dir_k:
			sprite.frame = _dir_base + sub
			return
		_dir_pose_active = false
		_clip = ""
		_clip_loop = true
	if not _clip_loop:
		# One-shot action: play forward until it runs out, then fall through.
		strip_t += delta
		var f := int(strip_t * strip_fps)
		if f < strip_frames:
			sprite.frame = f
			return
	var loco := _loco_clip()
	if loco != _clip or not _clip_loop:
		_play_clip(loco, true)
	strip_t += delta
	sprite.frame = int(strip_t * strip_fps) % strip_frames


## Which looping clip fits the current movement: run while a speed buff or
## berserk carries you, walk on foot, berserk-idle when standing enraged.
func _loco_clip() -> String:
	if velocity.length() <= 20.0:
		if berserk_time > 0.0 and _clips.has("ultidle"):
			return "ultidle"
		return "idle"
	if (theme_speed_time > 0.0 or berserk_time > 0.0) and _clips.has("run"):
		return "run"
	if _clips.has("walk"):
		return "walk"
	return "idle"


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
	# Animate this ability. Aim-critical slots (e.g. assassin Stab) show an
	# 8-way directional POSE pointing at the target; everything else fires a
	# one-shot swing clip. No-op if the class ships no matching art.
	var dir_pose: String = DIR_POSE.get(cls, {}).get(slot, "")
	if dir_pose == "" or not play_dir_anim(dir_pose, aim_dir()):
		var action_clip: String = ABILITY_CLIP.get(cls, {}).get(slot, "")
		if cls == "warrior" and berserk_time > 0.0 and action_clip in ["attack", "attack2"]:
			action_clip = "ult"  # berserk swings the RED blade, not the gold one
		play_action(action_clip)
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

	# Per-class kit dispatch — each class's four abilities (and their
	# helpers) live in their own scripts/player_kit_<class>.gd layer.
	match cls:
		"warrior": _use_warrior(slot, f)
		"archer": _use_archer(slot, f)
		"mage": _use_mage(slot, f)
		"assassin": _use_assassin(slot, f)
		"paladin": _use_paladin(slot, f)
		"warlock": _use_warlock(slot, f)

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
	if potion_cd > 0.0 or dead:
		return
	# Per-room budget (playtest 2026-07-07 v2): every drink spends a
	# loadout slot; a spent loadout locks Q until the next room.
	if room_potions_left() <= 0:
		potion_cd = 0.6
		game.spawn_text(global_position + Vector2(0, -40),
			"No potions left this room", Color(0.85, 0.7, 0.5))
		return
	if int(room_potions.get(active_potion, 0)) <= 0:
		cycle_potion()  # active type spent: fall to the next budgeted one
		return
	# Rotation potions route through the same bag effects as clicking
	# them in the inventory.
	if active_potion != "health":
		if active_potion == "mana_potion" and mp >= max_mp - 0.5:
			return  # never chug mana at full — held Q would drain the stack
		if active_potion == "elixir_might" and elixir_time > 1.0:
			return  # elixir already running: don't burn a second vial
		for c in consumables:
			if String(c.get("id", "")) == active_potion:
				potion_cd = 0.6
				room_potions[active_potion] = int(room_potions[active_potion]) - 1
				use_consumable(c)
				if int(room_potions.get(active_potion, 0)) <= 0 \
						or consumable_count(active_potion) <= 0:
					cycle_potion()  # slot spent or stock dry: next potion
				return
		potion_cd = 0.6
		cycle_potion()  # nothing left of this type — swap instead of sulking
		return
	if potions <= 0 or hp >= max_hp:
		return
	potion_cd = 0.6
	potions -= 1
	room_potions["health"] = int(room_potions.get("health", 1)) - 1
	game.fight_note_potion()
	hp = minf(max_hp, hp + max_hp * 0.6)
	game.sfx("potion")
	game.spawn_text(global_position + Vector2(0, -40), "+HP", Color(0.4, 1.0, 0.4))
	if int(room_potions.get("health", 0)) <= 0:
		cycle_potion()


## attacker (optional Enemy/Boss): resolves the hit through the SAME
## combat math as player attacks (Stats.resolve) — the attacker's dex
## shaves our evasion, its pen eats our resistance, and it can crit
## against our critres. Attacker-less damage (telegraphs, hazards)
## keeps the plain eva-then-res path.
func take_damage(amount: float, dmg_type := "phys", attacker: Node = null) -> void:
	if dead or hurt_cd > 0.0:
		return
	if game.dev_god:
		# Dev god mode: ignore damage at the source. The per-frame HP restore in
		# game.gd can't save you from a lethal hit that triggers death the same
		# frame it lands — this does.
		return
	if attacker is Enemy and (attacker as Enemy).toxin > 0:
		# ENFEEBLE (round 49e; split 49f): YOUR toxin on the attacker turns
		# its rot into your survival — class-flavored, scaled by live stacks
		# (see Balance). The assassin SLIPS the blow (evasion, on top of base
		# Elusive — a second independent roll); the archer SHRUGS it (a flat
		# damage cushion). Toxin is poison/venom-only, so this can't be
		# borrowed by another build.
		var tox_frac := float(mini((attacker as Enemy).toxin, Balance.TOXIN_MAX_STACKS)) \
			/ float(Balance.TOXIN_MAX_STACKS)
		if cls == "assassin":
			if randf() < Balance.ENFEEBLE_ASSASSIN_EVA * tox_frac:
				game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.55, 1.0, 0.6))
				game.sfx("blink")
				return
		else:
			amount *= 1.0 - Balance.ENFEEBLE_ARCHER_DR * tox_frac
	var res := physres if dmg_type == "phys" else magres
	if theme_guard_time > 0.0:
		res += theme_guard_amt
	if aegis_time > 0.0:
		res += aegis_amt
	if grit_res > 0.0 and grit_stacks > 0:
		# Stonehide (warrior talent): the beating hardens him — res scales
		# with Grit stacks, and dies with them when he kites away.
		res += grit_res * grit_stacks
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
	if curse_dr > 0.0 and dmg_type != "true" and not hexed.is_empty():
		# Doomward (warlock talent): maintaining a curse wards YOU as well.
		amount *= (1.0 - curse_dr)
	if shield > 0.0:
		# Transfusion shield eats the blow first (any damage type).
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if grit_regen > 0.0 and attacker != null:
		# Grit (warrior, round 48): every ENEMY blow taken stokes recovery —
		# stacks cap and refresh the window. Attacker-less damage (hazards,
		# telegraphs) builds nothing: no camping a campfire to farm stacks.
		# hurt_cd already throttles hits to ~1.6/s, so the ramp is rate-limited.
		if grit_stacks < int(grit_cap):
			grit_stacks += 1
			game.spawn_text(global_position + Vector2(0, -56), "GRIT x%d" % grit_stacks,
				Color(1.0, 0.75, 0.35))
		grit_time = 6.0
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
		if last_rites > 0.0 and last_rites_cd <= 0.0:
			# Last Rites (warlock talent): the pact refuses death, once a minute —
			# survive at 5% max HP per point invested (up to 25% at 5).
			hp = max_hp * 0.05 * last_rites
			last_rites_cd = 60.0
			game.spawn_text(global_position + Vector2(0, -60), "LAST RITES", Color(0.85, 0.35, 1.0))
			game.burst(global_position, Color(0.7, 0.2, 1.0), 22)
			game.hud.flash_screen(Color(0.5, 0.1, 0.7), 0.5, 0.5)
		else:
			hp = 0.0
			dead = true
			play_death_anim()
			game.on_player_died()
			return
	# Aegis redirect: while the shield is up, whoever strikes you is
	# smitten in return (everything in arm's reach pays for the blow).
	if aegis_time > 0.0:
		var near := _enemies_within(global_position, 100.0)
		if not near.is_empty():
			game.sfx("parry")  # steel answers steel (GameSounds cast)
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
