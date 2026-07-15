class_name Player extends "res://scripts/player_kit_warlock.gd"
## PLAYER, layer 9 of 9 — the ability dispatcher, survival (potion,
## damage intake, death) and the per-frame driver. See player_core.gd
## for the chain layout.


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	# MP (wave 4): a remote peer's player is PRESENTATION ONLY on this
	# machine — position/facing/anim ride the 20 Hz sync; no input
	# polling, no survival sim (regen/DoT/cooldowns/potions), no ability
	# dispatch. (# MP: phase-2 moves the combat sim to the authority side.)
	if not is_locally_controlled():
		_remote_present(delta)
		return
	# Intents first (MP seam): poll the local device into the intents
	# fields, then everything below reads ONLY intents — same keys, same
	# frame, same order as the old inline Input reads. A remote player's
	# poll no-ops and the frame consumes whatever its RPCs delivered.
	_poll_local_intents()
	# Target-lock EDGES (set by UI events — hud.gd's Tab/Space now, the
	# mobile HUD button later): consume-then-clear, before anything below
	# reads locked_target, so this frame's orientation/aim/abilities already
	# see the new lock. cycle_target() stays the public API (autotest calls
	# it directly); this is just the device-agnostic way to reach it.
	if intent_lock:
		intent_lock = false
		cycle_target()
	if intent_lock_release:
		intent_lock_release = false
		if locked_target != null:
			locked_target = null
			game.sfx("talk")
	if strip_frames > 0:
		_advance_clip(delta)
	for key in cds:
		cds[key] = maxf(0.0, cds[key] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	potion_swap_cd = maxf(0.0, potion_swap_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	zeal_time = maxf(0.0, zeal_time - delta)   # paladin Zeal window
	deathmark_time = maxf(0.0, deathmark_time - delta)   # assassin Death Mark weave window
	theme_speed_time = maxf(0.0, theme_speed_time - delta)
	damp_time = maxf(0.0, damp_time - delta)
	elixir_time = maxf(0.0, elixir_time - delta)
	goldrush_time = maxf(0.0, goldrush_time - delta)
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
	dash_refund_t = maxf(0.0, dash_refund_t - delta)  # shadow phantom-step window
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
	if downed or ghost:
		# MP-12 (§5.3): down players crawl (ghosts drift); no aim, no
		# actions, no aura upkeep — the block below never runs while down.
		_down_tick(delta)
		return

	# ------------------------------------------------------------ movement
	var dir := _move_dir()
	if frozen_time > 0.0 or rooted_time > 0.0:
		dir = Vector2.ZERO  # crowd-controlled: the dodge is denied
	# ORIENTATION (left/right). A hard Tab-lock turns the hero to keep facing
	# its target; failing that, the STICKY SOFT TARGET does the same (this is
	# what lets you kite a mob onto your back without turning around). Either
	# way an overhead target (inside AIM_VERTICAL_CONE) leaves steering to A/D,
	# and with no target at all ONLY horizontal move input changes facing — pure
	# up/down never does. Movement stays free 2D; only the aim orientation is L/R.
	if locked_target != null and (not is_instance_valid(locked_target) \
			or locked_target.dying or locked_target.untargetable):
		locked_target = null  # the lock releases when its target dies
	_update_soft_target(dir)
	var os := _face_sign()
	if is_instance_valid(locked_target):
		var lx := locked_target.global_position.x - global_position.x
		var ly := locked_target.global_position.y - global_position.y
		if absf(lx) > absf(ly) * Balance.AIM_VERTICAL_CONE:
			os = signf(lx)
	elif is_instance_valid(soft_target):
		var sx := soft_target.global_position.x - global_position.x
		var sy := soft_target.global_position.y - global_position.y
		if absf(sx) > absf(sy) * Balance.AIM_VERTICAL_CONE:
			os = signf(sx)      # commit orientation to the soft target
		elif absf(dir.x) > Balance.FACE_DEADZONE:
			os = signf(dir.x)   # target overhead: let movement steer
	elif absf(dir.x) > Balance.FACE_DEADZONE:
		os = signf(dir.x)
	facing = Vector2(os, 0.0)
	var spd := speed * (1.25 if berserk_time > 0.0 else 1.0)
	if theme_speed_time > 0.0:
		spd *= 1.0 + theme_speed_amt
	if damp_time > 0.0:
		spd *= Balance.DAMP_SLOW_MULT  # Damp: river water clings, -20% move
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

	# Walk bob + face the hero's ORIENTATION. The sprite follows facing (set
	# above) — NOT whoever is nearest, which used to yank it around and fight
	# the player's aim. Left-facing art (Crawl sprites) flips the opposite way;
	# a directional aim pose sets its own facing, so don't fight it while it holds.
	look_sign = _face_sign()
	if not _dir_pose_active and not _loco_dir_on and not _action_dir_on:
		# An aimed dash pose (_aim_dash_pose) faces the TRAVEL side, which may
		# oppose the target-committed look_sign — hold its flip while it plays.
		# Directional locomotion / one-shot already chose a facing strip.
		var side := _clip_flip if _clip_flip != 0.0 else look_sign
		sprite.flip_h = (side > 0.0) if face_left else (side < 0.0)
	if _clip_flip != 0.0:
		# ...and hold its rotation: the dash art is spun along the travel
		# line (up/down = 90°, diagonals = 45°); the bob would fight it.
		sprite.rotation = _clip_rot
		sprite.position.y = 0.0
	elif dir != Vector2.ZERO:
		# Walk bob (up/down hop) removed — old artifact, no class needs it.
		sprite.position.y = 0.0
		# Phantom (assassin mythic) additionally GLIDES — no side-to-side sway.
		sprite.rotation = 0.0 if skin == "phantom" else sin(anim_t * 11.0) * 0.06
	else:
		sprite.position.y = 0.0
		sprite.rotation = 0.0

	# Held weapon follows the facing side, with a light idle sway.
	if weapon_spr and weapon_spr.visible:
		var side := look_sign
		var rs := Balance.CHAR_RENDER_SCALE  # held-weapon offsets track the enlarged body
		weapon_spr.position = Vector2(20.0 * rs * side, 8.0 * rs + sprite.position.y)
		weapon_spr.flip_h = side < 0.0
		if melee_swing > 0.0:
			melee_swing = maxf(0.0, melee_swing - delta)
			var prog := 1.0 - melee_swing / 0.16
			if melee_style == "stab":
				# Blade points along the stab line and lunges out-and-back.
				weapon_spr.rotation = melee_dir.angle() + PI / 2.0
				weapon_spr.position += melee_dir * sin(prog * PI) * 20.0 * rs
			else:
				weapon_spr.rotation = side * lerpf(-1.4, 0.9, melee_swing / 0.16)
		else:
			weapon_spr.rotation = side * (0.35 + sin(anim_t * 2.0) * 0.05)
		weapon_glow.position = weapon_spr.position

	# ------------------------------------------------------------- actions
	# Consumed from the intents polled at the top of this frame (MP seam) —
	# held-state presses, debounced by the cooldowns exactly as before.
	if intent_a1:
		use_ability("a1")
	if intent_a2:
		use_ability("a2")
	if intent_a3:
		use_ability("a3")
	if intent_ult:
		use_ability("ult")
	if intent_potion:
		drink_potion()
	if intent_potion_next and potion_swap_cd <= 0.0:
		potion_swap_cd = 0.3
		cycle_potion()
	_revive_channel_tick(delta)  # MP-12: hold INTERACT beside a downed ally

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
		var pulse := (2.2 + sin(anim_t * shimmer) * 0.25) * Balance.CHAR_RENDER_SCALE
		aura.scale = Vector2(pulse, pulse)
	else:
		aura.visible = false
	# The rage is visible ON the hero, not just around them.
	if sprite:
		sprite.modulate = Color(1.45, 0.55, 0.5) if berserk_time > 0.0 else Color(1, 1, 1)


# ================================================== remote presentation (MP)

## The whole per-frame life of a player another peer owns (wave 4):
## render ~NET_LERP_MS in the past between the two buffered snapshots
## (MULTIPLAYER.md §3.1) and mirror the local sprite driver's minimal
## states — walk vs idle via the clip machine when a sheet is installed,
## the walk bob otherwise, facing from the synced look side. Position is
## SET, never move_and_slide'd: the owner already resolved collisions.
func _remote_present(delta: float) -> void:
	anim_t += delta
	if not net_snaps.is_empty():
		var render_t := Time.get_ticks_msec() - NET_LERP_MS
		var a: Dictionary = net_snaps[0]
		var b: Dictionary = net_snaps[net_snaps.size() - 1]
		for i in range(net_snaps.size() - 1):
			var nxt: Dictionary = net_snaps[i + 1]
			if int(nxt["t"]) >= render_t:
				a = net_snaps[i]
				b = nxt
				break
		var ta := int(a["t"])
		var tb := int(b["t"])
		var f := 1.0
		if tb > ta:
			f = clampf(float(render_t - ta) / float(tb - ta), 0.0, 1.0)
		global_position = (a["pos"] as Vector2).lerp(b["pos"] as Vector2, f)
		velocity = (a["vel"] as Vector2).lerp(b["vel"] as Vector2, f)
		var look := float(b["look"])
		if look != 0.0:
			look_sign = signf(look)
			facing = Vector2(look_sign, 0.0)
	if downed or ghost:
		# MP-12: a down shell holds its prone/spectral pose (the bob/flip
		# below would fight it); mirror the owner's bleed-out clock locally
		# so the ring and HUD tag on THIS screen read right.
		if downed:
			down_t = maxf(0.0, down_t - delta)
		return
	if sprite == null or _clip_locked:
		return
	if strip_frames > 0:
		_advance_clip(delta)  # _loco_clip reads the synced velocity: walk vs idle
		if not _dir_pose_active and not _loco_dir_on and not _action_dir_on:
			sprite.flip_h = (look_sign > 0.0) if face_left else (look_sign < 0.0)
	else:
		# Static class art: mirror the local walk bob so a moving remote
		# doesn't glide like a statue.
		sprite.flip_h = (look_sign > 0.0) if face_left else (look_sign < 0.0)
		if velocity.length() > 20.0:
			sprite.position.y = 0.0   # walk bob removed (old artifact)
			sprite.rotation = sin(anim_t * 11.0) * 0.06
		else:
			sprite.position.y = 0.0
			sprite.rotation = 0.0


# ============================================================ crowd control

## FROZEN: can't move OR cast for `dur` (Serane's Flash Freeze, Halla's
## sleep). Dodging AND acting are denied — the punish for being caught in
## the open. A no-op if already frozen longer.
func apply_freeze(dur: float) -> void:
	if not is_locally_controlled():
		# MP-10: control on a shell rides to the owner (§4.1 damage row).
		if game != null and game.net_host():
			game.net_session().host_player_status(peer_id, "freeze", dur)
		return
	if dead:
		return
	frozen_time = maxf(frozen_time, dur)
	game.spawn_text(global_position + Vector2(0, -50), "FROZEN!", Color(0.6, 0.85, 1.0))
	game.burst(global_position, Color(0.7, 0.9, 1.0), 14)


## ROOTED: can't move for `dur`, but may still cast (Serane's Shatter
## Lance, ch6 vine roots). The kite is denied; the kit is not.
func apply_root(dur: float) -> void:
	if not is_locally_controlled():
		if game != null and game.net_host():
			game.net_session().host_player_status(peer_id, "root", dur)
		return
	if dead:
		return
	rooted_time = maxf(rooted_time, dur)
	game.spawn_text(global_position + Vector2(0, -50), "ROOTED!", Color(0.5, 0.8, 0.6))


## CHILLED: movement slowed to `mult` while inside a mob's frost aura.
## Refreshed every frame the aura holds you (mob frost_aura trait) — no
## text spam; the walking-through-molasses feel is the tell.
func apply_chill(mult: float, dur := 0.35) -> void:
	if not is_locally_controlled():
		if game != null and game.net_host():
			game.net_session().host_player_status(peer_id, "chill", mult, dur)
		return
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
	_loco_dir_frame()   # swap to the facing strip when 8-dir art exists
	strip_t += delta
	sprite.frame = int(strip_t * strip_fps) % strip_frames


## 8-direction locomotion: while the current loop clip has directional art,
## point the sprite at the strip matching the hero's movement facing (the
## art encodes the direction, so flip is suppressed). No-op — and _loco_dir_on
## stays false — when the clip has no directional set, keeping the flip path.
func _loco_dir_frame() -> void:
	var dset: Dictionary = _dir_loco.get(_clip, {})
	if dset.is_empty():
		_loco_dir_on = false
		return
	var vec := velocity if velocity.length() > 20.0 else Vector2.ZERO
	var nd: String = Art.dir8_suffix(vec) if vec != Vector2.ZERO else _loco_dir
	if nd != _loco_dir or not _loco_dir_on:
		_loco_dir = nd
		var info: Dictionary = dset[nd]
		strip_frames = int(info["frames"])
		strip_fps = float(info["fps"])
		sprite.texture = info["tex"]
		sprite.hframes = strip_frames
		sprite.scale = Vector2(_hero_scale, _hero_scale)
		sprite.offset = Vector2(0, _hero_offset_y)
	_loco_dir_on = true
	sprite.flip_h = false


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
	if dead or downed or ghost or cds[slot] > 0.0:
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
	# EXCEPTION: the awakened Nightfang (mirrorstep S weapon) DROPS the lockout
	# for the Death Mark window — Stab AND Fan weave for a huge burst in that short
	# 5s. Its 30s ult cd + the BiS/awakening gate keep the lifesteal loop contained.
	if cls == "assassin" and slot in ["a1", "a3"] \
			and not (deathmark_time > 0.0 and s_passive() == "mirrorstep"):
		var twin := "a3" if slot == "a1" else "a1"
		cds[twin] = maxf(cds[twin], cds[slot])
	mp -= cost
	# Animate this ability. Aim-critical slots (e.g. assassin Stab) show an
	# 8-way directional POSE pointing at the target; everything else fires a
	# one-shot swing clip. No-op if the class ships no matching art.
	var dir_pose: String = DIR_POSE.get(cls, {}).get(slot, "")
	_strike_clip = ""  # reset; set below to the clip this ability swings (skin FX-sync)
	if dir_pose == "" or not play_dir_anim(dir_pose, aim_dir()):
		var action_clip: String = ABILITY_CLIP.get(cls, {}).get(slot, "")
		if cls == "warrior" and berserk_time > 0.0 and action_clip in ["attack", "attack2"]:
			action_clip = "ult"  # berserk swings the RED blade, not the gold one
		# A dash's clip faces the TRAVEL direction, not the aimed target — a
		# north/south dash was rendering sideways toward a side target.
		if action_clip == "dash":
			action_face_hint = dash_vec()
		# The archer's toward-camera (south) bow draw holds the bow FLAT across
		# her body, so a due-south shot reads as aiming sideways, not down at the
		# target. Bias a near-straight-south aim onto the SE/SW sprite (bow angles
		# down toward the target); the arrow itself still flies at aim_dir().
		elif cls == "archer" and action_clip in ["attack", "attack2"]:
			var av := aim_dir()
			if Art.dir8_suffix(av) == "s":
				action_face_hint = Vector2(1.0 if av.x >= 0.0 else -1.0, 1.0)
		play_action(action_clip)
		if cls == "warrior" and action_clip == "ult":
			# Berserk swings the red-blade cleave (the ult clip) at Cleave's
			# rage cadence — 0.45s, less under cdr — but that clip is authored
			# for a slower 0.64s one-shot, so each swing was chopped before its
			# follow-through. Re-pace it to finish inside the real recast window
			# so the cleave reads as a full swing at any attack speed (the ult
			# ACTIVATION roar, on its 40s cd, stays at authored pace).
			fit_action_clip(cds[slot])
		_strike_clip = action_clip  # skin FX-sync: swing_delay() reads this
		action_face_hint = Vector2.ZERO
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

	# Data-driven flat base for this cast (ability `base` x level; 0 today).
	# Folded into every hit the cast lands (player_combat.hit_enemy).
	_cast_base = ability_base_flat(slot)

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
	if potion_cd > 0.0 or dead or downed or ghost:
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
	# Health drinks consume OWNED stock (2026-07-09 investment round):
	# bought potions, or the expiring ch1-3 teaching freebie — never free.
	if potion_count() <= 0 or hp >= max_hp:
		return
	potion_cd = 0.6
	spend_health_potion()
	room_potions["health"] = int(room_potions.get("health", 1)) - 1
	game.fight_note_potion()
	hp = minf(max_hp, hp + (max_hp - hp) * Balance.POTION_HEAL_FRAC * constancy_heal_mult())
	game.sfx("potion")
	game.spawn_text(global_position + Vector2(0, -40), "+HP", Color(0.4, 1.0, 0.4))
	if int(room_potions.get("health", 0)) <= 0:
		cycle_potion()


## attacker (optional Enemy/Boss): resolves the hit through the SAME
## combat math as player attacks (Stats.resolve) — the attacker's dex
## shaves our evasion, its pen eats our resistance, and it can crit
## against our critres. Attacker-less damage (telegraphs, hazards)
## keeps the plain eva-then-res path.
## `heavy` (2026-07-09): boss telegraph resolutions pass true. The chip gate
## below exists for READABILITY (throttles hits to ~1.6/s so you can tell what
## is killing you) — but a stray chip hit must never eat a telegraphed nuke's
## "get good" punish (known cheese: tank a graze, stand in Vess's wail free).
## So a HEAVY hit pierces a gate armed by chip damage; it is still blocked by
## a gate armed by another heavy hit (or a deliberate i-frame window), so two
## overlapping telegraphs can't double-tap someone instantly.
func take_damage(amount: float, dmg_type := "phys", attacker: Node = null, heavy := false) -> void:
	if dead:
		return
	if downed or ghost:
		# MP-12 (§5.3): a fallen body can't be struck again — the bleed-out
		# clock is the only threat. Gated before the shell-forward so bites
		# on a downed shell never even cross the wire.
		return
	if not is_locally_controlled():
		# MP-10 (§4.1 "host decides, owner applies"): a host-side hit on
		# this remote shell forwards to the OWNING peer, whose real
		# take_damage runs mitigation/dodge/hurt_cd (incl. heavy-pierce)
		# on the machine that owns the stats. attacker travels as its
		# net id — the owner re-resolves against its own mirror. On a
		# guest a shell hit stays inert (only the host decides).
		if game != null and game.net_host():
			var aid := 0
			if attacker is Enemy:
				aid = (attacker as Enemy).net_id
			game.net_session().host_player_hit(peer_id, amount, dmg_type, aid, heavy)
		return
	if hurt_cd > 0.0 and (hurt_was_heavy or not heavy):
		return
	if game.dev_god:
		# Dev god mode: ignore damage at the source. The per-frame HP restore in
		# game.gd can't save you from a lethal hit that triggers death the same
		# frame it lands — this does.
		return
	amount *= debuff_dmg_in   # endgame Depths +damage-taken debuff (1.0 off-run)
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
	hurt_was_heavy = heavy  # a heavy-armed window blocks even other heavies
	since_hurt = 0.0
	# MP-12 (§5.3, owner call 2026-07-10): a landed hit NO LONGER breaks a
	# revive channel — taking damage is the cost of the 3 s hold. Only a hard
	# CC (freeze) interrupts, handled in _revive_channel_tick.
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
			# MP-12 (§5.3): in an online session a lethal hit DOWNS you
			# instead of killing — 30 s bleed-out, crawl, teammate-revivable.
			# Solo keeps the exact death below; the wipe flow re-kills
			# through game_flow.net_wipe, never through here.
			if game != null and game.net_online():
				_enter_downed()
				return
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
	net_clear_down_local()  # MP-12: down/ghost/channel state dies with the respawn (solo no-op)
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
	hurt_was_heavy = true  # respawn grace blocks telegraphs too
	# Release the death clip's frozen last frame (the dissolve) and snap back to
	# the idle animation — otherwise you respawn stuck as the death-pile "speck".
	_clip_locked = false
	_dir_pose_active = false
	if _clips.has("idle"):
		_play_clip("idle", true)


# ================================================ downed / revive / ghost (MP-12)
# MULTIPLAYER.md §5.3 — every state below is online-session-only; solo
# never reaches any of it (take_damage branches on game.net_online()).
# OWNER-authoritative: only the owning machine runs the transitions and
# broadcasts them; shells apply the mirrored flags via net_set_down.

## OWNER: a lethal hit landed online — fall instead of dying. 30 s of
## bleed-out at crawl speed; abilities/potions/interact are gated at the
## intents poll (player_core) and take_damage ignores the fallen body.
func _enter_downed() -> void:
	downed = true
	ghost = false
	down_t = DOWN_BLEEDOUT
	being_revived_by = 0
	velocity = Vector2.ZERO
	locked_target = null
	_revive_interrupt(false)  # can't keep channeling an ally from the floor
	_refresh_down_visual()
	game.spawn_text(global_position + Vector2(0, -56), "DOWNED!", Color(1.0, 0.35, 0.3))
	game.sfx("pdie")
	game.hud.flash_screen(Color(0.7, 0.08, 0.06), 0.45, 0.5)
	if game.net_online():
		game.net_session().send_down_state(1)


## OWNER: the bleed-out expired — become a GHOST: spectral, immaterial to
## enemies, walk-speed drift, no interaction, until the host sees the
## active room cleared (net_session._host_down_sweep) and stands us up.
func _enter_ghost() -> void:
	downed = false
	ghost = true
	being_revived_by = 0
	_refresh_down_visual()
	game.spawn_text(global_position + Vector2(0, -56),
		"The flame gutters...", Color(0.6, 0.8, 1.0))
	game.sfx("blink", 0.7)
	if game.net_online():
		game.net_session().send_down_state(2)


## OWNER: stand back up at hp_frac of max (channel revive or ghost
## room-clear — both 30%, §5.3). Broadcasts the state; vitals follow.
func net_stand_up(hp_frac: float) -> void:
	if not downed and not ghost:
		return
	downed = false
	ghost = false
	being_revived_by = 0
	down_t = 0.0
	hp = maxf(1.0, max_hp * hp_frac)
	hurt_cd = 1.5
	hurt_was_heavy = true  # the same respawn grace revive() grants
	_refresh_down_visual()
	game.spawn_text(global_position + Vector2(0, -56), "BACK ON YOUR FEET", Color(0.5, 1.0, 0.6))
	game.burst(global_position, Color(0.5, 1.0, 0.6), 14)
	game.sfx("mend")
	if game.net_online():
		game.net_session().send_down_state(0)


## SHELL: mirror the owner's broadcast state (net_session._rpc_down_state).
func net_set_down(st: int) -> void:
	downed = st == 1
	ghost = st == 2
	if downed:
		down_t = DOWN_BLEEDOUT  # local mirror of the owner's clock (skew ~ one RPC)
	else:
		being_revived_by = 0
	if st == 0:
		dead = false  # standing up — the vitals broadcast confirms the bar
	_refresh_down_visual()


## Clear ALL down/revive state WITHOUT broadcasting — the wipe path
## (game_flow.net_wipe) re-kills through the solo flow and every machine
## already runs its own copy. Also the solo-revive safety reset.
func net_clear_down_local() -> void:
	downed = false
	ghost = false
	being_revived_by = 0
	down_t = 0.0
	revive_target = null
	revive_t = 0.0
	_refresh_down_visual()


## OWNER, per-frame while downed/ghost: tick the bleed-out clock and move
## — crawl at DOWN_CRAWL_MULT while downed, plain walk as a ghost. Shells
## never come here (_remote_present mirrors them).
func _down_tick(delta: float) -> void:
	anim_t += delta
	if downed:
		down_t -= delta
		if down_t <= 0.0:
			_enter_ghost()
			return
	var dir := _move_dir()
	velocity = dir * speed * (DOWN_CRAWL_MULT if downed else 1.0)
	move_and_slide()
	if dir.x != 0.0:
		look_sign = signf(dir.x)
		facing = Vector2(look_sign, 0.0)
		if sprite != null:
			sprite.flip_h = (look_sign > 0.0) if face_left else (look_sign < 0.0)
			if downed:
				# prone rotation follows the flip so the body drags feet-first
				sprite.rotation = (PI / 2.0) * (-1.0 if sprite.flip_h else 1.0)


## REVIVER, per-frame: hold INTERACT within REVIVE_REACH of a fallen ally to
## channel the 3 s revive (§5.3). The host arbitrates the claim (first channel
## wins; later hopefuls silently no-op); progress runs on THIS clock. A DOWNED
## or GHOSTED ally can be channeled (owner call 2026-07-10). Breaking the hold
## (release, move, range, or the ally standing) cancels quietly; a hard CC (a
## freeze) cancels loudly. Plain damage does NOT interrupt — taking hits is the
## cost of the hold.
func _revive_channel_tick(delta: float) -> void:
	if game == null or not game.net_online():
		return
	if revive_target != null:
		var q = revive_target
		if not is_instance_valid(q) or not (q.downed or q.ghost) or not intent_interact \
				or intent_move != Vector2.ZERO \
				or global_position.distance_to(q.global_position) > REVIVE_REACH * 1.35:
			_revive_interrupt(false)
			return
		if frozen_time > 0.0:
			# Only a hard CC breaks the channel. A freeze is a full lockout —
			# you can't hold the flame steady frozen solid. Root leaves you
			# planted but working, so it doesn't (matches apply_root's ethos).
			_revive_interrupt(true)
			return
		revive_t += delta
		if revive_t >= REVIVE_CHANNEL:
			var pid: int = q.peer_id
			revive_target = null
			revive_t = 0.0
			game.net_session().finish_revive(pid)
		return
	if not intent_interact or frozen_time > 0.0:
		return  # frozen solid can't START a channel either (hard CC lockout)
	var best = null
	var best_d: float = REVIVE_REACH
	for p in game.players:
		if p == null or not is_instance_valid(p) or p == self or not (p.downed or p.ghost):
			continue
		var d := global_position.distance_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	if best == null:
		return
	if best.being_revived_by != 0 and best.being_revived_by != peer_id:
		return  # someone else holds the channel — busy no-op (§5.3)
	var now := Time.get_ticks_msec()
	if now - _revive_req_ms < 400:
		return  # a grant is (maybe) in flight — don't spam the host
	_revive_req_ms = now
	game.net_session().request_revive(best.peer_id)


## REVIVER: drop the channel. `loud` marks a combat interrupt (a landed
## hit) — the quiet path covers deliberate releases and range breaks.
func _revive_interrupt(loud: bool) -> void:
	if revive_target == null:
		return
	var q = revive_target
	revive_target = null
	revive_t = 0.0
	if game != null and game.net_online() and q != null and is_instance_valid(q):
		game.net_session().cancel_revive(q.peer_id)
	if loud:
		game.spawn_text(global_position + Vector2(0, -56), "REVIVE INTERRUPTED", Color(1.0, 0.6, 0.4))
		game.sfx("hurt", 0.6)
