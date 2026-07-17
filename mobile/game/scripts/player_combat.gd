extends "res://scripts/player_core.gd"
## PLAYER, layer 2 of 9 — targeting, hit resolution, and the shared
## combat primitives/juice every class kit leans on (melee arcs,
## projectiles, dashes, mists, beams). Class kits live in
## player_kit_<class>.gd; see player_core.gd for the chain layout.


# ================================================= downed presentation (MP-12)

## The §5.3 bleed-out clock, drawn in the world: a red arc over the body
## that empties as down_t runs out (the HUD banner shows the number). The
## body reference stays untyped — Player is the END of this chain and a
## typed forward reference here would be cyclic.
class DownRing extends Node2D:
	var plr = null
	func _ready() -> void:
		z_index = 40
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if plr == null or not is_instance_valid(plr):
			return
		var frac: float = clampf(float(plr.down_t) / float(plr.DOWN_BLEEDOUT), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(0.08, 0.03, 0.03, 0.55), 5.0)
		if frac > 0.0:
			draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40,
				Color(1.0, 0.3, 0.25, 0.9), 3.0)


## A thin ARCED LINE (NOT a filled crescent): a gently-curved sliver a few px
## thick that tapers to sharp points AND fades to transparent at both ends.
## Big radius + small span = a shallow, long arc (almost a curved line). Drawn
## per-quad along the arc, alpha falling off toward the tips. Phantom's cut.
class SlashArc extends Node2D:
	var col := Color(0.34, 0.95, 0.80, 0.95)
	var radius := 90.0
	var span := 0.62     # half-angle — small span + big radius = a shallow arc
	var width := 2.4     # HALF-thickness of the line (thin); sin-tapers at tips
	func _draw() -> void:
		var steps := 24
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var a0 := lerpf(-span, span, t0)
			var a1 := lerpf(-span, span, t1)
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			var w0 := width * sin(PI * t0)   # thin band tapering to points at the tips
			var w1 := width * sin(PI * t1)
			var tm := (t0 + t1) * 0.5
			var f := col.a * pow(sin(PI * tm), 2.4)  # STRONG fade — the tips nearly vanish
			var c := Color(col.r, col.g, col.b, f)
			draw_colored_polygon(PackedVector2Array([
				d0 * (radius + w0), d1 * (radius + w1),
				d1 * (radius - w1), d0 * (radius - w0)]), c)


## A thin spectral DASH STREAK: seeded with the dash path ([0] = head at the
## dash's end, last = tail at the start), drawn as a miter-jointed ribbon that
## thins and fades toward the tail, then fades out entirely and frees itself.
## Only spawned by the Phantom's dash (see _dash_strike) — not on walking.
class PhantomTrail extends Node2D:
	var pts := PackedVector2Array()   # dash path, [0] = head (end), last = tail (start)
	func _ready() -> void:
		z_index = 2
		global_position = Vector2.ZERO
		var tw := create_tween()      # hold briefly, then fade the whole streak out + free
		tw.tween_interval(0.1)
		tw.tween_property(self, "modulate:a", 0.0, 0.32)
		tw.tween_callback(queue_free)
	func _draw() -> void:
		var n := pts.size()
		if n < 3:
			return
		var base_w := 2.0          # thin at the head; tapers to a point at the tail
		var base_a := 0.6
		# Per-point MITER normals (average of adjacent segment normals) so the
		# ribbon stays continuous through turns instead of folding into a chevron.
		var nrm := []
		nrm.resize(n)
		for i in n:
			var seg := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			var sl := seg.length()
			nrm[i] = Vector2(-seg.y, seg.x) / sl if sl > 0.001 else Vector2.ZERO
		for i in n - 1:
			var t0 := float(i) / float(n - 1)      # 0 = head (at Phantom), 1 = tail
			var t1 := float(i + 1) / float(n - 1)
			var w0 := base_w * (1.0 - t0)
			var w1 := base_w * (1.0 - t1)
			var a := base_a * pow(1.0 - (t0 + t1) * 0.5, 1.3)   # FADE OUT toward the tail
			draw_colored_polygon(PackedVector2Array([
				pts[i] + nrm[i] * w0, pts[i + 1] + nrm[i + 1] * w1,
				pts[i + 1] - nrm[i + 1] * w1, pts[i] - nrm[i] * w0]),
				Color(0.5, 1.0, 0.86, a))


## A short, thin spectral streak that FOLLOWS a flying projectile (Phantom's
## thrown knives): records the projectile's recent positions and draws a
## miter-jointed ribbon that thins + fades toward the tail — about half the
## dash streak's width and shorter. Retracts then frees when the knife is gone.
class ProjTrail extends Node2D:
	const MAXPTS := 8              # short (the dash streak is longer)
	var proj = null
	var col := Color(0.5, 1.0, 0.9)
	var pts := PackedVector2Array()
	func _ready() -> void:
		z_index = 2
		global_position = Vector2.ZERO
	func _process(_delta: float) -> void:
		if proj != null and is_instance_valid(proj):
			# A Projectile DRAWS above its physics position (muzzle rise) —
			# ride the drawn height. Plain sprites (ult ring knives) draw
			# where they are.
			pts.insert(0, proj._fx_pos() if proj is Projectile else proj.global_position)
			if pts.size() > MAXPTS:
				pts.resize(MAXPTS)
		elif pts.size() > 1:
			pts.remove_at(pts.size() - 1)   # knife gone: drain the streak, then vanish
		else:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var n := pts.size()
		if n < 3:
			return
		var base_w := 1.0          # ~half the dash streak's width
		var base_a := 0.55
		var nrm := []
		nrm.resize(n)
		for i in n:
			var seg := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			var sl := seg.length()
			nrm[i] = Vector2(-seg.y, seg.x) / sl if sl > 0.001 else Vector2.ZERO
		for i in n - 1:
			var t0 := float(i) / float(n - 1)
			var t1 := float(i + 1) / float(n - 1)
			var w0 := base_w * (1.0 - t0)
			var w1 := base_w * (1.0 - t1)
			var a := base_a * pow(1.0 - (t0 + t1) * 0.5, 1.3)
			draw_colored_polygon(PackedVector2Array([
				pts[i] + nrm[i] * w0, pts[i + 1] + nrm[i + 1] * w1,
				pts[i + 1] - nrm[i + 1] * w1, pts[i] - nrm[i] * w0]),
				Color(col.r, col.g, col.b, a))


## Golden Ronin's throwing-star after-image: drops fading, rotated ghost copies
## of the shuriken along its flight, each frozen at the star's spin angle of that
## instant, so a fast-spinning star smears into a trail of echoes. Pure FX; the
## ghosts parent to the game so they hang in place and fade as the star flies on.
## Frees itself once the star is gone (its last ghosts fade on their own tweens).
class ShurikenEcho extends Node2D:
	const SPAWN_DT := 0.028        # a ghost every ~28 ms
	const FADE := 0.20            # each ghost fades over 200 ms
	const START_A := 0.42
	var proj = null
	var tex: Texture2D = null
	var col := Color(1.0, 0.85, 0.4)
	var _t := 0.0
	func _process(delta: float) -> void:
		if proj == null or not is_instance_valid(proj):
			queue_free()          # ghosts already dropped fade on their own tweens
			return
		_t += delta
		while _t >= SPAWN_DT:
			_t -= SPAWN_DT
			_drop()
	func _drop() -> void:
		if proj.spr == null or not is_instance_valid(proj.spr):
			return
		var parent := get_parent()
		if parent == null:
			return
		var g := Sprite2D.new()
		g.texture = tex
		g.global_position = proj._fx_pos()  # the star DRAWS above its physics position
		g.rotation = proj.spr.rotation
		g.scale = proj.spr.scale
		g.z_index = 4             # just under the live star (projectile z_index 5)
		g.modulate = Color(col.r, col.g, col.b, START_A)
		parent.add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, FADE)
		tw.parallel().tween_property(g, "scale", g.scale * 0.7, FADE)
		tw.tween_callback(g.queue_free)


## Phantom ult presentation: a ring of 16 spectral knives around the marked
## target that CONVERGE on a schedule (each firing plays the knife sound). The
## ring follows the target as it moves; it hides AND pauses while the target is
## untargetable (invisible) so it can't be abused, resuming when it reappears.
## Pure FX — no collision (ignores terrain); the ult's damage lands elsewhere.
## Convergence ORDER (blades sit every 22.5°, i*TAU/16): cardinals N,E,S,W then
## diagonals NE,SE,SW,NW then the 8 in-between, one every STEP seconds.
class PhantomBladeStorm extends Node2D:
	const ORDER := [12, 0, 4, 8, 14, 2, 6, 10, 1, 3, 5, 7, 9, 11, 13, 15]
	const STEP := 0.25
	var game_ref = null
	var target = null
	var radius := 135.0
	var blades := []
	var flames := []
	var t := 0.0
	var fired := 0
	var linger := 0.6
	func _ready() -> void:
		z_index = 9
		for i in 16:
			var ang := TAU * float(i) / 16.0
			var spr := Sprite2D.new()
			spr.texture = Art.tex("dart")
			spr.modulate = Color(0.82, 0.95, 1.0)       # light ghost blade
			spr.position = Vector2.from_angle(ang) * radius
			spr.rotation = ang + PI                      # point inward, at the target
			# Fiery spectral aura: a hot blue-white core, and a FLAME tongue that
			# licks off the blade's tail (local -x, away from the target) — the
			# tongue flickers per-frame in _flicker so it reads as fire, not a disc.
			var core := Sprite2D.new()
			core.texture = Art.tex("glow")
			core.modulate = Art.hdr(Color(0.72, 0.95, 1.0, 0.85))  # hot blue-white heart
			core.scale = Vector2(0.24, 0.24)
			core.z_index = -1
			spr.add_child(core)
			var flame := Sprite2D.new()
			flame.texture = Art.tex("glow")
			flame.modulate = Art.hdr(Color(0.28, 0.78, 1.0, 0.6))  # spectral-blue flame
			flame.position = Vector2(-9, 0)             # streams off the tail
			flame.scale = Vector2(0.7, 0.28)
			flame.z_index = -2
			spr.add_child(flame)
			add_child(spr)
			blades.append(spr)
			flames.append(flame)
	func _process(delta: float) -> void:
		if target == null or not is_instance_valid(target) or target.dying:
			queue_free()
			return
		global_position = target.global_position          # follow the target
		if target.untargetable:                            # invisible: hide + PAUSE (not abusable)
			visible = false
			return
		visible = true
		t += delta
		_flicker()
		while fired < ORDER.size() and t >= float(fired) * STEP:
			_converge(ORDER[fired])
			fired += 1
		if fired >= ORDER.size():
			linger -= delta
			if linger <= 0.0:
				queue_free()
	func _flicker() -> void:
		# Each flame tongue wavers on its own phase (two beating sines) — an
		# uneven, living flame rather than a steady glow.
		for i in flames.size():
			var fl: Sprite2D = flames[i]
			if not is_instance_valid(fl):
				continue
			var ph := float(i) * 0.7
			var fk: float = absf(sin(t * 19.0 + ph) * sin(t * 7.7 + ph * 1.6))
			fl.scale = Vector2(0.58 + 0.42 * fk, 0.22 + 0.14 * fk)
			fl.position.x = -8.0 - 5.0 * fk             # the tongue leaps and shrinks
			fl.modulate.a = 0.42 + 0.4 * fk
	func _converge(idx: int) -> void:
		var spr: Sprite2D = blades[idx]
		if not is_instance_valid(spr):
			return
		if game_ref != null:
			game_ref.sfx("stab", 0.72, 0.0, -3.0)  # ult blades: a little deeper than the throw
			var tr := ProjTrail.new()          # spectral streak, same as the knife throw
			tr.proj = spr
			tr.col = Color(0.5, 1.0, 0.92)
			game_ref.add_child(tr)
		var tw := spr.create_tween()
		tw.tween_property(spr, "position", Vector2.ZERO, 0.16) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.16)
		tw.tween_callback(spr.queue_free)


## MP-12 (§5.3) presentation, shared by the owner and every shell: prone
## + drained while DOWNED (with the bleed-out ring), spectral + immaterial
## while a GHOST, defaults restored on standing. Solo never enters the
## down states, so the restore branch just re-asserts the _ready defaults.
func _refresh_down_visual() -> void:
	if sprite == null:
		return
	if downed or ghost:
		if _down_ring == null or not is_instance_valid(_down_ring):
			_down_ring = DownRing.new()
			_down_ring.plr = self
			add_child(_down_ring)
		_down_ring.visible = downed  # the ring IS the bleed-out clock; ghosts have none
	elif _down_ring != null:
		if is_instance_valid(_down_ring):
			_down_ring.queue_free()
		_down_ring = null
	if ghost:
		sprite.rotation = 0.0
		sprite.position.y = 0.0
		sprite.modulate = Color(0.6, 0.8, 1.0, 0.4)  # spectral, translucent
		collision_layer = 0      # immaterial: enemies/projectiles pass through
		collision_mask = 1       # walls still hold; enemies don't body-block a ghost
	elif downed:
		# Prone: the body tips over its feet; face keeps the crawl heading.
		sprite.rotation = (PI / 2.0) * (-1.0 if sprite.flip_h else 1.0)
		sprite.position.y = 0.0
		sprite.modulate = Color(0.7, 0.45, 0.45, 0.85)  # drained, bloodless
		collision_layer = 2
		collision_mask = 1 | 4
	else:
		sprite.rotation = 0.0
		sprite.modulate = Color(1, 1, 1)
		collision_layer = 2      # the _ready defaults, restored
		collision_mask = 1 | 4


# ================================================================ targeting

## Current movement INTENT (locally: WASD/arrows), normalized; ZERO when
## idle. Shared by the per-frame mover and abilities that step with you.
## Reads the intents layer (MP seam, player_core.gd) — the poll-through
## refresh keeps dashes cast between physics ticks (autotest, dev paths)
## on the same live key state the old inline Input reads saw; for a remote
## player the refresh no-ops and this returns the RPC-fed intent.

## Skin FX-sync: the per-class Balance delay consts (WARRIOR_SWING_DELAY, …)
## are tuned to the BASE class clips' contact frame. A skin's AI-generated
## swing lands its contact on a DIFFERENT frame, so return that skin clip's
## measured contact time instead — keeps the hit ON the swing. Falls back to
## base_delay with no skin, or when the skin has no entry for the clip the
## current ability is swinging (_strike_clip, set by use_ability). See
## Skins.SWING.
func swing_delay(base_delay: float) -> float:
	var base := base_delay
	if skin != "" and _strike_clip != "":
		var t: float = Skins.swing_time(cls, skin, _strike_clip)
		if t >= 0.0:
			base = t
	# A refitted clip (fit_action_clip) runs faster, so its contact frame
	# arrives sooner — pull the FX in by the same factor to stay on the swing.
	return base / _clip_haste


func _move_dir() -> Vector2:
	_poll_local_intents()
	return intent_move


## The direction a movement dash travels: the HELD move input (8-way), or
## straight along the facing when no key is down. Dashes follow your FEET,
## not your aim — orientation can stay committed to a target while the dash
## carries you any direction (player-reported: down+dash still fired sideways
## because facing is a purely horizontal vector).
func dash_vec() -> Vector2:
	var dir := _move_dir()
	return dir if dir != Vector2.ZERO else facing


## Which way the hero is oriented: -1 left, +1 right. Facing is kept as a
## horizontal unit vector (see player.gd), so its x sign IS the orientation.
func _face_sign() -> float:
	return -1.0 if facing.x < 0.0 else 1.0


## Is a hard Tab-lock in force? A locked target overrides ALL targeting —
## every aimed and seeking ability homes to it, and the hero's orientation
## tracks it — until it dies (then per-frame clears the lock).
func _hard_lock(rng: float) -> Enemy:
	if is_instance_valid(locked_target) and not locked_target.dying \
			and not locked_target.untargetable \
			and global_position.distance_to(locked_target.global_position) <= rng * 1.4:
		return locked_target
	return null


## Target for SEEKING abilities (ults, sky-drops, marks): they can't be
## aimed, so they grab the BIGGEST THREAT — any boss outranks any mob, and
## within a tier the lowest-HP one wins (finish the wounded). A hard lock
## overrides this entirely.
func auto_aim(rng := 520.0) -> Enemy:
	var lock := _hard_lock(rng)
	if lock:
		return lock
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		if global_position.distance_to(e.global_position) > rng:
			continue
		if best == null or _outranks(e, best):
			best = e
	return best


func _outranks(e: Enemy, cur: Enemy) -> bool:
	var eb := e is Boss
	var cb := cur is Boss
	if eb != cb:
		return eb  # a boss always beats a mob
	return e.hp < cur.hp  # same tier: the more wounded one


## Target for AIMED attacks. Hard lock wins; otherwise the STICKY SOFT TARGET
## (maintained once per frame by _update_soft_target) if it's within this
## ability's reach — that's what makes your orientation and aim commit to one
## enemy across frames, so kiting it onto your blind side doesn't drop it.
## Only when there's no soft target in range do we fall back to the old
## nearest-on-the-facing-side pick (short-range abilities whose soft target
## is out of reach still hit whatever's actually in front of them).
func _aim_target(rng: float) -> Enemy:
	var lock := _hard_lock(rng)
	if lock:
		return lock
	if is_instance_valid(soft_target) and not soft_target.dying \
			and not soft_target.untargetable \
			and global_position.distance_to(soft_target.global_position) <= rng:
		return soft_target
	var side := _face_sign()
	var best: Enemy = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		var to := e.global_position - global_position
		var d := to.length()
		if d > best_d:
			continue
		var overhead := absf(to.x) <= absf(to.y) * Balance.AIM_VERTICAL_CONE
		if signf(to.x) == side or overhead:
			best = e
			best_d = d
	return best


## Maintain the sticky soft target — called once per physics frame from
## player.gd with the current move input. Rules: keep the current target while
## it's alive and inside SOFT_TARGET_KEEP; if the player is deliberately
## steering toward the far side AND a real enemy waits there, switch to it
## (else keep kiting the one behind you); otherwise (re)acquire the nearest
## within SOFT_TARGET_ACQUIRE, biased to the pressed side. A hard lock overrides
## everything downstream, so this can run harmlessly even while locked.
func _update_soft_target(move: Vector2) -> void:
	var keep := is_instance_valid(soft_target) and not soft_target.dying \
			and not soft_target.untargetable \
			and global_position.distance_to(soft_target.global_position) <= Balance.SOFT_TARGET_KEEP
	var want := signf(move.x)  # horizontal input this frame; 0 when none
	if keep and want != 0.0 and want != _side_of(soft_target):
		var alt := _nearest_enemy(Balance.SOFT_TARGET_ACQUIRE, want)
		if alt != null:
			soft_target = alt
		return
	if keep:
		return
	soft_target = _nearest_enemy(Balance.SOFT_TARGET_ACQUIRE, want)


## Which side an enemy sits on for orientation: -1/+1, or 0 when it's basically
## overhead (inside the vertical cone — no clear left/right).
func _side_of(e: Enemy) -> float:
	var to := e.global_position - global_position
	if absf(to.x) <= absf(to.y) * Balance.AIM_VERTICAL_CONE:
		return 0.0
	return signf(to.x)


## Nearest live enemy within `rng`. When `side` is non-zero, prefer that
## horizontal side and only fall back to the far side if that side is empty.
func _nearest_enemy(rng: float, side: float) -> Enemy:
	var best: Enemy = null
	var best_d := rng
	var far: Enemy = null
	var far_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		var d := global_position.distance_to(e.global_position)
		if d > rng:
			continue
		if side != 0.0 and _side_of(e) != side:
			if d < far_d:
				far = e
				far_d = d
			continue
		if d < best_d:
			best = e
			best_d = d
	return best if best != null else far


func cycle_target() -> void:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and not e.untargetable \
				and global_position.distance_to(e.global_position) <= 560.0:
			list.append(e)
	if list.is_empty():
		locked_target = null
		return
	list.sort_custom(func(a, b) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var idx := list.find(locked_target)
	locked_target = list[(idx + 1) % list.size()]
	game.sfx("talk")


func aim_dir(rng := 520.0) -> Vector2:
	var target := _aim_target(rng)
	if target:
		return (target.global_position - global_position).normalized()
	return Vector2(_face_sign(), 0.0)  # nothing on your side: fire straight ahead


## The enemy your AIMED attacks would strike right now (facing-gated, or the
## hard-locked target) — drives the on-screen reticle so it always sits on
## what a basic attack hits, and hides when nothing is on your side.
func aim_focus(rng := 520.0) -> Enemy:
	return _aim_target(rng)


# ================================================================= abilities

## The data-driven damage knobs for one ability slot — the SINGLE SOURCE lives
## in Classes.CLASSES[cls].abilities[slot].dmg. `coeff` is the %ATK the kit hits
## for; `base` is the flat-per-level floor (0 today). Kits read the coeff from
## here so tuning an ability = editing one number that the tooltip also reads.
func ability_coeff(slot: String) -> float:
	return float(Classes.CLASSES[cls]["abilities"][slot].get("dmg", {}).get("coeff", 1.0))

## The ability's flat base damage at this level (base x level). Dormant (0) until
## a class is handed a floor; see _cast_base.
func ability_base_flat(slot: String) -> float:
	return float(Classes.CLASSES[cls]["abilities"][slot].get("dmg", {}).get("base", 0.0)) * float(level)

## The fraction of an ability's damage CONVERTED to true damage (ignores defenses,
## cannot crit). Single-sourced in the ability's dmg.true_frac; the kit passes it
## into hit_enemy via effects["true_frac"]. 0 for everything but Meteor today.
func ability_true_frac(slot: String) -> float:
	return float(Classes.CLASSES[cls]["abilities"][slot].get("dmg", {}).get("true_frac", 0.0))

## One numeric RIDER value (stun / iframe / dr / slow / heal…) from the ability's
## single-source `riders` data — the kit reads the mechanic from here so tuning
## the number moves both the effect AND the tooltip (Classes.ability_riders).
func rider(slot: String, key: String, default := 0.0) -> float:
	return float(Classes.CLASSES[cls]["abilities"][slot].get("riders", {}).get(key, default))


func hit_enemy(e: Enemy, mult: float, effects := {}) -> void:
	for key in _tfx:
		if not effects.has(key):
			effects[key] = _tfx[key]
	var dmg_type: String = effects.get("type", Classes.CLASSES[cls]["dmg_type"])
	var pen := 0.0
	var e_res := 0.0
	if dmg_type == "phys":
		pen = physpen
		e_res = e.physres
	elif dmg_type == "magic":
		pen = magpen
		e_res = e.magres

	# Theme crit bonuses (and theme-line talents like Nightfall) are
	# CAP-EXEMPT (player rule 2026-07-06): they ride above the 35% knee
	# at full value — the built stat knees, the themed edge never does.
	var crit_exempt: float = effects.get("crit_bonus", 0.0)
	if void_crit > 0.0 and effects.get("crush", 0):
		crit_exempt += void_crit  # Nightfall (warlock): Void's crushing line crits more
	# A fraction of some abilities is CONVERTED to true damage (single-sourced in the
	# ability's dmg.true_frac, passed in via effects, e.g. Meteor's 25%): that slice
	# ignores all defenses and cannot crit OR miss; the rest resolves normally.
	var true_frac: float = effects.get("true_frac", 0.0)
	var base_amt: float = current_atk() * mult + _cast_base
	var result := Stats.resolve(base_amt * (1.0 - true_frac), dmg_type,
		crit, crit_dmg, pen, dex, e_res, e.eva, e.critres, crit_exempt)
	if result["miss"] and true_frac <= 0.0:
		game.spawn_text(e.global_position + Vector2(0, -30), "MISS", Color(0.7, 0.7, 0.7))
		return
	# GRAZE: your DEX is closing on their evasion, so the dodge only clipped
	# you instead of erasing the hit. Called out loud — a half-damage number
	# with no cause reads as a bad roll, and this one is a BUILD state.
	if result.get("graze", false):
		game.spawn_text(e.global_position + Vector2(0, -30), "GRAZE", Color(0.8, 0.85, 0.5))
	var dmg: float = float(result["dmg"]) + base_amt * true_frac
	var is_crit: bool = result["crit"]
	# Shadow marked_crit: your MARKED / EXPOSED prey always crits. Keyed on
	# vuln_time (Death Mark, Exposed) — NOT stun/slow, which a boss converts to
	# concussion and never actually applies, so this fires on bosses too (the
	# old "stunned/slowed prey" opportunist was dead on every boss door).
	if effects.get("marked_crit", 0) and dmg_type != "true" \
			and not is_crit and e.vuln_time > 0.0:
		is_crit = true
		dmg *= crit_dmg
	# Hunt: a lined-up shot cannot fail to crit.
	if next_crit and dmg_type != "true":
		next_crit = false
		if not is_crit:
			is_crit = true
			dmg *= crit_dmg
	# Forced crit from the caller (Void Rift on a cursed victim): the kit gates the
	# CONDITION, this just guarantees the crit + its crit_dmg multiplier.
	if effects.get("force_crit", 0) and dmg_type != "true" and not is_crit:
		is_crit = true
		dmg *= crit_dmg

	# ------------------------------------------------ theme / rider effects
	# DoTs resolve like hits — no hidden true damage: the tick rate is
	# mitigated by the target's res minus our pen, SNAPSHOT at
	# application (fast refresh cadences re-snapshot within a beat).
	# Mitigation relief only: no excess-pen flat bonus on ticks.
	var dot_mit := 1.0 - Stats.res_frac(maxf(0.0, e_res - pen))
	if effects.has("dot"):
		var dot_color := Color(0.5, 1.2, 0.5) if _tcolor.g > _tcolor.r else Color(1.4, 0.8, 0.6)
		var dot_dps: float = current_atk() * effects["dot"] * dot_mit
		if effects.get("toxin", 0):
			e.apply_toxin(dot_dps, 3.0, dot_color, self)
		else:
			e.apply_burn(dot_dps, 3.0, dot_color, self)
	if effects.has("burn"):
		e.apply_burn(float(effects["burn"]) * dot_mit, 3.0, Color(1.4, 0.8, 0.6), self)
	if effects.has("bleed"):
		# Wind Cuts (mage): a 3s physical bleed, armor-mitigated and
		# refresh-don't-stack. effects["bleed"] is the pre-mit TOTAL wound;
		# spread it across the 3s window as dps.
		e.apply_bleed(float(effects["bleed"]) * dot_mit / 3.0, 3.0, self)
	if effects.has("slow"):
		e.apply_slow(1.0 - effects["slow"] if effects["slow"] < 1.0 else 0.5, effects.get("slow_dur", 2.0))
	if effects.has("stun"):
		_stun_or_concuss(e, effects["stun"])
	if effects.has("stagger"):
		_stun_or_concuss(e, effects["stagger"])
	if effects.has("stun_chance") and randf() < effects["stun_chance"]:
		_stun_or_concuss(e, 0.5)
	if effects.has("vuln") and randf() < effects["vuln"]:
		e.apply_vuln(3.0)  # MP-10 seam: a mirror forwards the mark to the host
		game.spawn_text(e.global_position + Vector2(0, -44), "EXPOSED", Color(1, 0.5, 0.3))
	if effects.has("heal"):
		gain_hp(max_hp * effects["heal"])  # bulwark ram / holy strike: SHOWS
	if effects.has("blood_amp"):
		# Blood theme (round 32): the cut bites harder the deeper YOU
		# bleed — missing health becomes DAMAGE (the base kit's surge
		# already turns it into lifesteal; blood doubles down on the edge).
		dmg *= 1.0 + effects["blood_amp"] * (1.0 - hp / max_hp)
	# Warlock wither: a maintained hex deepens — every hit bites harder
	# the longer the curse has held (only the warlock ever fills `wither`).
	if wither.has(e):
		dmg *= 1.0 + mini(int(float(wither[e]) / Balance.WITHER_STACK_EVERY),
			Balance.WITHER_MAX_STACKS) * Balance.WITHER_PER_STACK
	# Brittle (ice): cold cracks the target — this hit bites per existing
	# stack, then deepens the crack for the next one.
	if effects.get("brittle", 0):
		dmg *= 1.0 + e.brittle * Balance.BRITTLE_PER_STACK
		e.add_brittle()
	# Crush (void): gravity hurts — a target recently displaced hard
	# (shove, hard pull) takes the hit deeper.
	if effects.get("crush", 0) and e.crush_t > 0.0:
		dmg *= 1.0 + Balance.CRUSH_MULT
	# Rupture (warlock Void talent): anything you've displaced hard takes more
	# from EVERY hit — the payoff for choreographing shoves and pulls.
	if crush_amp > 0.0 and e.crush_t > 0.0:
		dmg *= 1.0 + crush_amp
	# Killing Frost (mage Ice talent): bite harder into slowed or frozen prey.
	if chill_dmg > 0.0 and (e.slow_time > 0.0 or e.stun_time > 0.0):
		dmg *= 1.0 + chill_dmg
	# Serpent's Due (archer Venom talent): poisoned prey takes extra damage.
	if poison_dmg > 0.0 and e.burn_time > 0.0:
		dmg *= 1.0 + poison_dmg
	# Coup de Grâce (assassin talent): finish wounded prey faster. Never bosses:
	# their execute windows are design-owned (Hunger below already excludes them),
	# and a plated cinderhide mirror can read <40% optimistically on a guest —
	# without this guard the execute would fire on a boss it never should (Wave-2
	# co-op fix #3a; the plate_dr mirror sync also stops the false <40% read).
	if execute_dmg > 0.0 and not (e is Boss) and e.max_hp > 0.0 and e.hp < e.max_hp * 0.40:
		dmg *= 1.0 + execute_dmg
	# Hunger (tempted resonance lean): the shard savors the finish — wounded
	# MOBS take extra. Never bosses (their execute windows stay design-owned),
	# and only prey that PAYS: boss summons / spawner sprouts / event mood
	# spawns all zero gold_value, so the hunger ignores them — a boss's adds
	# die at the fight's own pace.
	if not (e is Boss) and e.gold_value > 0 and e.max_hp > 0.0 \
			and e.hp < e.max_hp * Balance.RES_HUNGER_EXEC_AT:
		var hunger := hunger_exec_bonus()
		if hunger > 0.0:
			dmg *= 1.0 + hunger

	# Lifesteal (AoE hits only steal a third).
	var ls := current_lifesteal() * (0.33 if effects.get("aoe", false) else 1.0)
	if ls > 0.0:
		hp = minf(max_hp, hp + dmg * ls)
	# Holy stance (paladin Conviction, round 48): every righteous blow mends —
	# the stance IS the sustain (AoE hits mend at a third, like lifesteal).
	if cls == "paladin" and paladin_mode == "holy":
		gain_hp(max_hp * Balance.PALADIN_HOLY_MEND * (0.33 if effects.get("aoe", false) else 1.0))

	var dir := (e.global_position - global_position).normalized()
	e.hit_src = self  # MP-10: attribute the blow (reflect/counter/aggro; solo: THE player)
	e.take_damage(dmg, dir, is_crit)
	# Shadow phantom step: a dash armed a refund window — the kill that closes
	# it (usually the Fan or ult-stab, rarely the dash itself) slashes the dash
	# cd. One refund per window; a fresh dash re-arms it.
	if dash_refund_t > 0.0 and dash_refund_frac > 0.0 and (e.dying or e.hp <= 0.0):
		cds["a2"] = maxf(Balance.DASH_CONNECT_FLOOR, cds["a2"] * (1.0 - dash_refund_frac))
		dash_refund_t = 0.0
		dash_refund_frac = 0.0
		game.spawn_text(global_position + Vector2(0, -60), "PHANTOM", Color(0.7, 0.5, 1.0))
	# A Ninja-pack impact burst punctuates a CRIT (CC0) — elemental when
	# themed, a warm shockburst otherwise. Single-target only: AoE and echo
	# sub-hits stay quiet so a crowd hit doesn't turn to confetti.
	if is_crit and not effects.get("aoe", false) and not effects.get("_echoed", false):
		var icol := Color(1, 1, 1).lerp(_tcolor, 0.55) if _themed else Color(1.0, 0.72, 0.42)
		_fx_flash("fx_impact", e.global_position, 9, {
			"color": icol, "scale": 1.45, "z": 9, "frame_time": 0.03, "alpha": 0.95,
		})
	if effects.has("knock") and not e.dying \
			and not (effects.get("knock_no_boss", 0) and e is Boss):
		# knock_no_boss: the shove flings mobs but a boss holds its ground
		# (mage Frost Nova — the mage spaces with its feet, never by shoving
		# a boss; warlock Void is the deliberate exception and omits the flag).
		e.apply_knock(dir * effects["knock"])
	if effects.has("pull") and not e.dying:
		e.apply_knock(-dir * 380.0)
	if effects.has("shove") and not e.dying:
		# Void's light shove: opens the crush window every hit, but a boss is
		# barely moved (BOSS_SHOVE_FACTOR). The crush window is set DIRECTLY so
		# it fires regardless of how far the target actually slid.
		var sf: float = effects["shove"]
		e.apply_knock(dir * (sf * Balance.BOSS_SHOVE_FACTOR if e is Boss else sf), true)
	if effects.has("splash"):
		game.burst(e.global_position, _tcolor if _themed else Color(1.0, 0.6, 0.2), 8)
		for e2 in _enemies_within(e.global_position, 80.0):
			if e2 != e and not e2.dying:
				e2.hit_src = self
				e2.take_damage(dmg * effects["splash"], (e2.global_position - e.global_position).normalized())
	# Echo: the hit strikes again at half strength.
	if effects.has("echo") and not effects.has("_echoed") and randf() < effects["echo"] and not e.dying:
		var again := effects.duplicate()
		again["_echoed"] = true
		hit_enemy(e, mult * 0.5, again)


## DoT rate mitigated by the target's res (class damage type) minus our
## pen — for dot sources OUTSIDE hit_enemy (the mist primitive, the
## poison Death Mark), which mirror the rider pipeline's snapshot rule.
func _dot_dps(e: Enemy, dps: float) -> float:
	var dmg_type: String = Classes.CLASSES[cls]["dmg_type"]
	var pen := physpen if dmg_type == "phys" else magpen
	var e_res := e.physres if dmg_type == "phys" else e.magres
	return dps * (1.0 - Stats.res_frac(maxf(0.0, e_res - pen)))


## Stun — or CONCUSSION: a CC-immune target (boss) takes the failed
## stun as bonus damage instead (duration x mult x ATK), so stun riders
## keep a boss-fight value without re-opening boss CC.
func _stun_or_concuss(e: Enemy, dur: float) -> void:
	if e is Boss:
		if not e.dying:
			e.hit_src = self
			e.take_damage(current_atk() * dur * Balance.CONCUSSION_MULT,
				(e.global_position - global_position).normalized())
	else:
		e.apply_stun(dur)


func _enemies_within(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and not e.untargetable \
				and center.distance_to(e.global_position) <= radius:
			out.append(e)
	return out


# ------------------------------------------------------ shared juice ---

## A shockwave ring at pos: expands outward, or collapses inward.
func _ring_fx(pos: Vector2, color: Color, radius: float, collapse := false) -> void:
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Art.hdr(Color(color, 0.9))
	ring.global_position = pos
	ring.z_index = 7
	game.add_child(ring)
	var big := radius / 24.0
	ring.scale = Vector2(big, big) if collapse else Vector2(0.3, 0.3)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(0.3, 0.3) if collapse else Vector2(big, big), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if collapse else Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)


## Ghost copies of the hero along a dash path, fading in sequence.
## `stagger`/`fade` shape the read: quick+sparse = a blink, slow+dense =
## bulk in motion (the warrior's charge).
## Lazily-loaded tint shader for solid coloured after-images (see silhouette.gdshader).
static var _silhouette_shader: Shader = null
static func _get_silhouette_shader() -> Shader:
	if _silhouette_shader == null:
		_silhouette_shader = load("res://shaders/silhouette.gdshader")
	return _silhouette_shader


func _afterimages(start: Vector2, end: Vector2, color: Color, count := 3,
		stagger := 0.05, fade := 0.26, solid := false) -> void:
	if sprite == null:
		return
	for i in count:
		var t := float(i + 1) / float(count + 1)
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.hframes = sprite.hframes
		ghost.frame = sprite.frame
		ghost.flip_h = sprite.flip_h
		ghost.rotation = sprite.rotation  # an aimed dash pose carries into its trail
		ghost.scale = sprite.scale
		ghost.offset = sprite.offset      # match the hero's feet-anchor offset (else it sits low)
		ghost.global_position = start.lerp(end, t) + sprite.position
		if solid:
			# A luminance-shaded solid tint so a LIGHT colour (gold) actually reads
			# — a modulate multiply can only darken a textured sprite. modulate.a
			# still drives the fade.
			var mat := ShaderMaterial.new()
			mat.shader = _get_silhouette_shader()
			mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
			ghost.material = mat
			ghost.modulate = Color(1, 1, 1, 0.8)
		else:
			ghost.modulate = Color(color, 0.5)
		ghost.z_index = 5
		game.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_interval(stagger * i)
		tw.tween_property(ghost, "modulate:a", 0.0, fade)
		tw.tween_callback(ghost.queue_free)


## A glowing scorch/frost line left on the ground along a dash path.
func _floor_streak(start: Vector2, end: Vector2, color: Color) -> void:
	var streak := Sprite2D.new()
	streak.texture = Art.tex("glow")
	streak.modulate = Color(color, 0.5)
	streak.global_position = (start + end) / 2.0
	streak.rotation = (end - start).angle()
	streak.scale = Vector2(maxf(1.0, start.distance_to(end) / 40.0), 0.8)
	streak.z_index = -5
	game.add_child(streak)
	var tw := streak.create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, 1.1)
	tw.tween_callback(streak.queue_free)


## A single faint gust streak, trailing BEHIND a speed-buffed run (round
## 44): the "this buff is live" tell for theme_speed. Kept very low-alpha
## and short — a whisper of wind, not a comet. `back` is the drift/lean
## direction (opposite travel).
func _wind_wisp(back: Vector2) -> void:
	var wisp := Sprite2D.new()
	wisp.texture = Art.tex("glow")
	wisp.modulate = Color(0.82, 0.94, 1.0, 0.13)  # pale, barely-there
	wisp.global_position = global_position + back * 16.0 + Vector2(0, -6)
	wisp.rotation = back.angle()
	wisp.scale = Vector2(1.3, 0.32)               # stretched along the gust
	wisp.z_index = -4                              # behind the hero
	game.add_child(wisp)
	var tw := wisp.create_tween()
	tw.tween_property(wisp, "global_position", wisp.global_position + back * 26.0, 0.4)
	tw.parallel().tween_property(wisp, "modulate:a", 0.0, 0.4)
	tw.tween_callback(wisp.queue_free)


## Animated Ninja-FX flash (CC0 Ninja Adventure pack): loads a horizontal
## frame strip from assets/sprites/fx/<name>.png, steps across its `frames`
## cells, then frees itself. World-space by default (parented to `game`);
## pass {"parent": self} for a flash that rides the hero, in which case
## `pos` is treated as a LOCAL offset. `opts` keys: color, alpha, scale,
## rot, flip_h, flip_v, z, frame_time, fade, parent.
func _fx_flash(name: String, pos: Vector2, frames: int, opts := {}) -> void:
	# Degrade gracefully if the pack asset isn't imported/present: Art.tex
	# would otherwise fall through to the procedural SPRITES table and
	# hard-error on an unknown "fx/..." key. No file ⇒ simply no flash.
	if not ResourceLoader.exists("res://assets/sprites/fx/%s.png" % name):
		return
	var spr := Sprite2D.new()
	spr.texture = Art.tex("fx/" + name)
	spr.hframes = frames
	spr.frame = 0
	var scl: float = opts.get("scale", 1.0)
	spr.scale = Vector2(scl, scl)
	spr.rotation = opts.get("rot", 0.0)
	spr.flip_h = opts.get("flip_h", false)
	spr.flip_v = opts.get("flip_v", false)
	spr.z_index = opts.get("z", 7)
	var col: Color = opts.get("color", Color(1, 1, 1))
	var alpha: float = opts.get("alpha", 1.0)
	spr.modulate = Color(col.r, col.g, col.b, alpha)
	var parent: Node = opts.get("parent", game)
	if parent == self:
		spr.position = pos
	else:
		spr.global_position = pos
	parent.add_child(spr)
	var per: float = opts.get("frame_time", 0.045)
	var fade: float = opts.get("fade", 0.09)
	# Step the strip frame-by-frame (bind snapshots each frame index), then
	# fade the last frame out. The tween lives on the sprite, so a freed
	# sprite (room rebuild, death) kills it cleanly.
	var tw := spr.create_tween()
	for f in range(1, frames):
		tw.tween_interval(per)
		tw.tween_callback(spr.set_frame.bind(f))
	tw.tween_interval(per)
	tw.tween_property(spr, "modulate:a", 0.0, fade)
	tw.tween_callback(spr.queue_free)


## Release flash at the weapon: shots visibly leave YOU, not thin air.
func _muzzle(dir: Vector2, color: Color) -> void:
	var fl := Sprite2D.new()
	fl.texture = Art.tex("glow")
	fl.modulate = Art.hdr(Color(color, 0.85))
	fl.position = dir * 26.0 + Vector2(0, -Balance.PROJ_MUZZLE_RISE)
	fl.scale = Vector2(0.5, 0.5)
	fl.z_index = 6
	add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "scale", Vector2(1.05, 1.05), 0.08)
	tw.parallel().tween_property(fl, "modulate:a", 0.0, 0.11)
	tw.tween_callback(fl.queue_free)


## Melee strike. style "swing" = crescent arc; "stab" = straight thrust
## (a piercing streak, and the held weapon lunges instead of swiping).
## `variant` picks the swing's sweep path (-1 = classic fixed fan;
## 0 diagonal / 1 crescent-down / 2 crescent-up — the warrior cycles
## these so Cleave reads as swordplay, not a repeated air-swipe), and
## variants lead the arc with a blade sprite (the equipped weapon's own
## icon when one is held). Hit logic is untouched — visual only.
func _melee_arc(mult: float, reach: float, fx_name: String, effects := {}, style := "swing", snd := "slash", variant := -1) -> int:
	# Phantom's cut is a clean, sharp, fading spectral slash (sound + visual).
	game.sfx("phantom_slash" if skin == "phantom" else snd)
	melee_swing = 0.16
	melee_style = style
	var dir := aim_dir(220.0)
	melee_dir = dir
	# Base slash colour: theme tint if themed, else RED while berserk (so the
	# crescent matches the rage), else plain white.
	var slash_col := _tcolor if _themed else (Color(1.0, 0.3, 0.2) if berserk_time > 0.0 else Color(1, 1, 1))
	if style == "stab":
		# Dagger SLASH (round 50): a fast crescent that sweeps an arc OUT from
		# the blade tip, riding the striking dagger — the assassin cuts, he
		# doesn't fence with a floating sliver. White base; theme tints it.
		if skin == "phantom":
			# Phantom: a CLEAN teal crescent with sharp pointed tips (drawn, not a
			# soft sprite) that swells slightly and DISSOLVES like a spectre's cut.
			var arc := SlashArc.new()
			arc.col = Color(0.20, 1.0, 0.90, 1.0)  # sharp, vivid spectral cyan-teal
			arc.radius = reach * 0.85    # big radius = shallow curve, but centred BEHIND...
			arc.span = 0.6
			arc.width = 2.6              # extremely thin line
			arc.rotation = dir.angle()   # local +x = strike direction
			arc.position = dir * (-reach * 0.4)  # ...so the belly sits close, not far out front
			arc.z_index = 8
			arc.scale = Vector2(0.9, 0.9)
			add_child(arc)
			var at := arc.create_tween()
			at.tween_property(arc, "scale", Vector2(1.18, 1.18), 0.11) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			at.parallel().tween_property(arc, "modulate:a", 0.0, 0.3)
			at.tween_callback(arc.queue_free)
		elif skin == "blade_dancer":
			# Golden Ronin: a faint gold glint-arc rides the stab — the same clean
			# drawn crescent as Phantom's, warm gold and low-alpha (a glint, not a
			# spectre's slash).
			var garc := SlashArc.new()
			garc.col = Color(1.0, 0.84, 0.38, 0.7)   # warm gold, faint
			garc.radius = reach * 0.85
			garc.span = 0.5
			garc.width = 2.2
			garc.rotation = dir.angle()
			garc.position = dir * (-reach * 0.4)
			garc.z_index = 8
			garc.scale = Vector2(0.85, 0.85)
			add_child(garc)
			var gat := garc.create_tween()
			gat.tween_property(garc, "scale", Vector2(1.12, 1.12), 0.1) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			gat.parallel().tween_property(garc, "modulate:a", 0.0, 0.24)
			gat.tween_callback(garc.queue_free)
		else:
			var pivot := Node2D.new()
			pivot.rotation = dir.angle() - 0.85  # wind the arc back...
			pivot.z_index = 8
			add_child(pivot)
			var cres := Sprite2D.new()
			cres.texture = Art.tex("slash")
			cres.position = Vector2(reach * 0.42, 0)  # crescent out at the blade tip
			cres.scale = Vector2(2.2, 2.2) * (reach / 118.0)
			cres.modulate = slash_col
			pivot.add_child(cres)
			# The Ninja-pack drawn cut flashes along the arc (CC0), tinted to match.
			_fx_flash("fx_slash", global_position + dir * reach * 0.46, 4, {
				"color": slash_col, "rot": dir.angle(),
				"scale": 1.9 * (reach / 118.0), "z": 9, "frame_time": 0.026, "alpha": 0.95,
			})
			var tw := pivot.create_tween()
			tw.tween_property(pivot, "rotation", dir.angle() + 0.85, 0.1) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # ...and cut through
			tw.parallel().tween_property(pivot, "modulate:a", 0.0, 0.13)
			tw.tween_callback(pivot.queue_free)
	else:
		# The crescent SWEEPS across the arc instead of fading in place —
		# a pivot at the hero swings the blade sprite through ~100°.
		# Variant sweeps keep the strike centered on `dir` but change the
		# path: diagonal cut, overhead crescent down, rising crescent up.
		var from := -0.9
		var to := 0.9
		match variant:
			0: from = -1.7; to = 0.55
			1: from = -0.8; to = 1.25
			2: from = 0.8; to = -1.25
		var pivot := Node2D.new()
		pivot.rotation = dir.angle() + from
		pivot.z_index = 6
		add_child(pivot)
		var spr := Sprite2D.new()
		spr.texture = Art.tex(fx_name)
		spr.position = Vector2(reach * 0.5, 0)
		spr.scale = Vector2(2.8, 2.8) * (reach / 78.0)
		spr.flip_v = to < from  # rising cut: the crescent's belly flips with it
		spr.modulate = slash_col
		pivot.add_child(spr)
		# A Ninja-pack slash crescent flashes along the strike (CC0), tinted
		# to the swing colour — the drawn "cut" riding on top of the sweep.
		_fx_flash("fx_slash", global_position + dir * reach * 0.52, 4, {
			"color": slash_col, "rot": dir.angle(),
			"scale": 2.4 * (reach / 78.0), "z": 8, "frame_time": 0.032,
			"alpha": 0.9, "flip_v": to < from,
		})
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "rotation", dir.angle() + to, 0.13) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(pivot, "modulate:a", 0.0, 0.17)
		tween.tween_callback(pivot.queue_free)
	var hits := 0
	for e in _enemies_within(global_position + dir * reach * 0.55, reach * 0.55):
		hit_enemy(e, mult, effects.duplicate())
		hits += 1
	return hits


func _proj(dir: Vector2, mult: float, tex: String, speed_px: float) -> Projectile:
	var p := Projectile.spawn(game, global_position + dir * 24.0, dir * speed_px, 0.0, true, tex)
	# Draw the shot at hand height (visual only — the flight line stays on the
	# origin plane): the node origin sits at hip height on the feet-anchored
	# body, and an arrow spawned there leaves ~26px below the drawn bow.
	p.rise = Balance.PROJ_MUZZLE_RISE
	p.hit_player_mult = mult
	p.source_player = self
	p.fx = _tfx.duplicate()
	if _themed:
		p.modulate = Color(1, 1, 1).lerp(_tcolor, 0.55)
	# Caster tell: a Ninja-pack summoning ring blooms at the hands on a
	# magic-damage cast (CC0), tinted to the theme (or a cool arcane blue).
	if Classes.CLASSES[cls]["dmg_type"] == "magic":
		_fx_flash("fx_circle", global_position + dir * 18.0
				+ Vector2(0, 2 - Balance.PROJ_MUZZLE_RISE), 4, {
			"color": _tcolor if _themed else Color(0.62, 0.76, 1.0),
			"scale": 1.5, "z": 3, "frame_time": 0.05, "alpha": 0.85,
		})
	return p


## Per-class ultimate activation sound, falling back to the generic one.
func _ult_sfx() -> void:
	var key := "ult_" + cls
	game.sfx(key if game.sounds.has(key) else "ult")


## A thin beam of light/darkness between two points, fading fast
## (hex tendrils, chain snaps, quick magical connections).
func _beam_fx(from: Vector2, to: Vector2, col: Color, width := 0.18) -> void:
	var seg := Sprite2D.new()
	seg.texture = Art.tex("glow")
	seg.modulate = Art.hdr(Color(col, 0.85))
	seg.global_position = (from + to) / 2.0
	seg.rotation = (to - from).angle()
	seg.scale = Vector2(maxf(0.5, from.distance_to(to) / 44.0), width)
	seg.z_index = 7
	game.add_child(seg)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale:y", 0.03, 0.22)
	tw.parallel().tween_property(seg, "modulate:a", 0.0, 0.24)
	tw.tween_callback(seg.queue_free)


## Dash `dist` pixels in the move direction, damaging every enemy along
## the path. Used by mage Blink, assassin Shadow Dash and the warrior's
## Shield Bash — and because it HITS things, ability themes fully apply
## to it. Returns kill count (Phantom step refunds cooldown on kills).
## A connecting stab's blood surge (round 25): lifesteal up for 4s,
## scaling with MISSING health — low health is a resource.
## (_grant_stab_surge lives HERE, not in the assassin layer: _dash_strike
## fires it for the dash-stab rider, and calls only flow derived→base.)
func _grant_stab_surge() -> void:
	# Announce it once when it FIRST lights (a refresh mid-surge is silent —
	# the stab cadence is 0.3s); the crimson aura carries the rest.
	if stab_ls_time <= 0.0:
		game.spawn_text(global_position + Vector2(0, -52), "BLOOD SURGE", Color(0.95, 0.35, 0.4))
	stab_ls_time = 4.0
	stab_ls_amt = Balance.SURGE_LS_FLOOR + Balance.SURGE_LS_SCALE * (1.0 - hp / max_hp)


## Aim the PLAYING dash clip along the travel line. The sheets only author a
## left/right dash, so an off-axis dash flips the art to the horizontal side
## of travel and ROTATES it the rest of the way: straight up/down spins the
## L/R art 90° (up-while-facing-left = 90° clockwise, up-while-facing-right =
## 90° counter-clockwise — angle_to encodes exactly that), diagonals 45°. A
## pure-vertical dash keeps whichever way the hero already faced. The held
## pose is released by the next _play_clip (player.gd bob gate holds it).
func _aim_dash_pose(dvec: Vector2) -> void:
	if strip_frames == 0 or _clip_loop or _dir_pose_active or _action_dir_on or dvec == Vector2.ZERO:
		return  # no sheet / no one-shot playing / 8-way pose or directional
		        # dash strip already owns the facing (rotating it would mangle it)
	var side := signf(dvec.x) if dvec.x != 0.0 else _face_sign()
	_clip_flip = side
	_clip_rot = Vector2(side, 0.0).angle_to(dvec)
	sprite.flip_h = (side > 0.0) if face_left else (side < 0.0)
	sprite.rotation = _clip_rot
	sprite.position.y = 0.0


## `heavy` sells mass instead of speed: a denser, slower-fading ghost
## trail + landing dust/shake (the warrior's charge — an armored wall
## arriving, not an assassin's blink; same instant mechanics).
func _dash_strike(dist: float, mult: float, effects := {}, stab_rider := 0.0, iframe := 0.3, heavy := false) -> int:
	# Phantom's dash gets its own re-skinnable whoosh (assets/sounds/dash.*);
	# every other class keeps the shared blink whoosh.
	game.sfx("dash" if skin == "phantom" else "blink")
	var color := _tcolor if _themed else Color(0.6, 0.7, 1.0)
	var start := global_position
	var dvec := dash_vec()
	global_position = game.clamp_to_zone(start + dvec * dist, start)
	_aim_dash_pose(dvec)  # before the ghost trail below, so the afterimages copy the pose
	var end := global_position
	if skin == "phantom":
		# A thin spectral streak along the dash path — fades out and self-frees.
		var trail := PhantomTrail.new()
		var tsteps := 10
		for ti in tsteps + 1:
			trail.pts.append(end.lerp(start, float(ti) / tsteps) + Vector2(0.0, -22.0))
		game.add_child(trail)
	if iframe > 0.0:
		hurt_cd = maxf(hurt_cd, iframe)  # brief immunity while dashing
		hurt_was_heavy = true  # a deliberate i-frame blocks heavy telegraph hits too
	game.burst(start, color, 8)
	game.burst(end, color, 8)
	game.dust(start + Vector2(0, 14), 4)  # kicked-up dust where you left
	if heavy:
		_afterimages(start, end, color, 7, 0.085, 0.40)
		game.dust(end + Vector2(0, 14), 6)  # the landing hits like a wall
		game.shake(2.5)
	else:
		_afterimages(start, end, color)

	# Light trail between the two points.
	var mid := (start + end) / 2.0
	var trail := Sprite2D.new()
	trail.texture = Art.tex("glow")
	trail.modulate = Color(color, 0.7)
	trail.global_position = mid
	trail.rotation = (end - start).angle()
	trail.scale = Vector2(maxf(1.0, start.distance_to(end) / 44.0), 1.1)
	trail.z_index = 6
	game.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.25)
	tween.tween_callback(trail.queue_free)

	var kills := 0
	var rider_hit := false
	var rider_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		var lane := e.global_position.distance_to(closest)
		if lane <= 55.0:
			hit_enemy(e, mult, effects.duplicate())
			if stab_rider > 0.0:
				# First stroke on the victim: the dash blade itself
				# (round 36 — the pass-through finally LOOKS like a cut).
				_cut_flash(e.global_position, 0.65, _tcolor if _themed else Color(1, 1, 1))
			if e.dying or e.hp <= 0.0:
				kills += 1
		if stab_rider > 0.0 and lane <= 150.0 and not e.dying \
				and rider_count < Balance.DASH_RIDER_CAP:
			# Round 49 AoE pass: the rider lands on at most DASH_RIDER_CAP
			# victims per pass — a dash through a PACK was paying the full
			# stab on every body in the corridor. Boss doors never notice.
			# The dash carries the knife (rounds 26/29), and the knife
			# reaches FARTHER than the shoulder: a graze-pass NEXT to
			# the boss still lands the stab + blood surge — thread the
			# needle past the swing, cut, kite out already healing.
			# Round 32: the dash-stab gets BONUS range over the standing
			# stab (150px corridor vs 118px reach) — striking in stride
			# reaches deeper than planting your feet.
			# Round 40: the rider pays by DEPTH — inside the old 105px
			# corridor the cut lands full (1.0x); only the far bonus-
			# reach graze (105-150px) takes the discount. The surge is
			# identical at every depth.
			var rider_mult: float = (Balance.DASH_STAB_NEAR_MULT
				if lane <= Balance.DASH_STAB_NEAR_LANE else Balance.DASH_STAB_MULT)
			hit_enemy(e, rider_mult * stab_rider, {"stagger": 0.3})
			_grant_stab_surge()
			rider_hit = true
			rider_count += 1
			# The rider's stroke, opposite diagonal: a graze shows ONE
			# cut; a full pass-through (lane + rider) crosses into an X.
			_cut_flash(e.global_position, -0.65, _tcolor if _themed else Color(1, 1, 1))
		if effects.get("graze_heal", 0) and lane > 55.0 and lane <= Balance.CHARGE_GRAZE_LANE and not e.dying:
			# Bulwark ram (round 44): the shield-charge mends on a NEAR
			# pass, not just a dead-center ram — like the assassin's safe-
			# range graze, charging PAST a boss (threading its swing) still
			# clips it for a lighter hit, and the heal rides that hit. A
			# direct ram (lane <= 55) already healed via the fx above.
			hit_enemy(e, mult * Balance.CHARGE_GRAZE_MULT, effects.duplicate())
			_cut_flash(e.global_position, 0.4, _tcolor if _themed else Color(0.7, 0.85, 1.0))
	if rider_hit:
		# The connect refunds the dash — the SKILL lever (round 46): a landed
		# cut claws the cd toward the connect floor (talent deepens the
		# refund); a whiff pays full, and gear cdr can't push below the floor.
		cds["a2"] = maxf(Balance.DASH_CONNECT_FLOOR,
			cds["a2"] * (1.0 - (Balance.DASH_REFUND + dash_refund)))
	return kills


## A single blade-sliver flash across a point — the universal "you
## were cut" mark (one diagonal per stroke; two strokes cross an X).
func _cut_flash(pos: Vector2, ang: float, color := Color(1, 1, 1)) -> void:
	var cut := Sprite2D.new()
	cut.texture = Art.tex("slashline")
	cut.modulate = color
	cut.global_position = pos
	cut.rotation = ang
	cut.scale = Vector2(1.1, 0.45)
	cut.z_index = 8
	game.add_child(cut)
	var tw := cut.create_tween()
	tw.tween_interval(0.08)
	tw.tween_property(cut, "modulate:a", 0.0, 0.1)
	tw.tween_callback(cut.queue_free)


## An expanding cloud that ticks poison on everything inside — the mist
## primitive behind Venom Bloom, Toxic Wake and the archer's toxin cloud.
## Not a flat glow: a ROILING mass of drifting blobs, rising toxic motes,
## a burst ring on arrival, and venom bubbles on everything it eats.
func _mist(pos: Vector2, radius: float, dps_mult: float, color: Color, dur := 2.5) -> void:
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 4
	game.add_child(root)
	_ring_fx(pos, color, radius)
	game.burst(pos, color, 10)

	# Overlapping blobs, each swelling to its own size and slowly churning
	# around the center — the cloud visibly boils instead of sitting still.
	for i in 6:
		var blob := Sprite2D.new()
		blob.texture = Art.tex("glow")
		var shade := randf_range(0.55, 1.0)
		blob.modulate = Color(color.r * shade, color.g * shade, color.b * shade, 0.0)
		var off := Vector2.from_angle(TAU * i / 6.0 + randf_range(-0.4, 0.4)) \
			* randf_range(radius * 0.15, radius * 0.45)
		blob.position = off
		blob.scale = Vector2(0.6, 0.6)
		root.add_child(blob)
		var grow := blob.create_tween()
		grow.tween_property(blob, "modulate:a", randf_range(0.4, 0.6), 0.35)
		var target := randf_range(radius / 30.0, radius / 20.0)
		grow.parallel().tween_property(blob, "scale", Vector2(target, target), 0.5)
		var churn := blob.create_tween()
		churn.set_loops()
		churn.tween_property(blob, "position", off.rotated(0.9), randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)
		churn.tween_property(blob, "position", off, randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)

	# Toxic motes bubbling up out of the whole area for the cloud's life.
	var motes := CPUParticles2D.new()
	motes.amount = 30
	motes.lifetime = 1.1
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector2(0, -1)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -26)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 28.0
	motes.scale_amount_min = 1.6
	motes.scale_amount_max = 3.4
	motes.color = Color(color, 0.85)
	root.add_child(motes)

	var ticks := int(dur / 0.4)
	for i in ticks:
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(root):
			return
		if dead:
			root.queue_free()
			return
		for e in _enemies_within(pos, radius):
			# The mist IS the poison primitive: its ticks stack toxin.
			e.apply_toxin(_dot_dps(e, current_atk() * dps_mult), 1.2, Color(color, 1.0), self)
			game.burst(e.global_position + Vector2(0, -10), color, 4)  # venom bubbles
	motes.emitting = false
	var fade := root.create_tween()
	fade.tween_property(root, "modulate:a", 0.0, 0.6)
	fade.tween_callback(root.queue_free)
