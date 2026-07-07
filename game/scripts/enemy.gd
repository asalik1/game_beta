class_name Enemy extends CharacterBody2D
## A basic monster. Stats come from Story.ENEMIES, so one script
## covers wolves, spiders, cultists and skeletons.
## Supports status effects: stun, slow, burn, and vulnerability (Death Mark).

var game: Game
var kind := "wolf"
var display_name := "Monster"
var level := 1
var max_hp := 30.0
var hp := 30.0
var dmg := 8.0
var speed := 150.0
var xp_value := 12
var gold_value := 4
var ranged := false
# Combat substats (see Stats for the curves). ALL of them scale with
# level via the monster's attribute build (Story.enemy_stats_at).
var physres := 0.0
var magres := 0.0
var eva := 0.0
var critres := 0.0
var crit := 0.0     # chance this enemy's hits crit (x1.5, vs player critres)
var dex := 0.0      # shaves the player's evasion before the dodge roll
var physpen := 0.0  # eats player resistance (excess -> bonus damage)
var magpen := 0.0
var dmg_type := "phys"  # what this enemy's attacks count as

var elite := false     # miniboss variant: bigger, meaner, loot pinata, NO xp
var untargetable := false  # burrowed/submerged boss phase: no damage, no auto-aim
var aggro_range := 330.0
var attack_cd := 0.0
var windup := 0.0     # yellow-flash wind-up before a melee bite lands
var zone_idx := -1    # which room's clear-count this enemy belongs to
var pack_id := 0      # aggro group within the room (per-pack aggro)
var force_aggro := false  # pack woken: attack no matter the distance
var alerted := false  # has shown its "!" bubble
var hazard_speed := 1.0  # terrain patch effect (ice boosts, void slows)
# Animation seam (Track C): >1 when an _anim strip override is installed.
var anim_frames := 0
var anim_fps := 6.0
var anim_t := 0.0
# Walk/idle split: swap strips on movement when a _walk strip exists.
var _strip_idle := {}
var _strip_walk := {}
var _strip_walking := false
var art_scale := 1.0
var knock := Vector2.ZERO
var home := Vector2.ZERO
var sprite: Sprite2D
var hp_bar_bg: ColorRect
var hp_bar_fg: ColorRect
var face_left := false  # sprite art natively faces left (Crawl tiles)
var dying := false

# --- status effects ---
var stun_time := 0.0
var slow_time := 0.0
var slow_mult := 1.0
var burn_time := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var burn_color := Color(1.4, 0.8, 0.6)  # orange = fire, green = poison
var vuln_time := 0.0   # takes +50% damage while marked
var toxin := 0         # green-DoT stacks: deepen the burn TICK (die with it)
var brittle := 0       # ice stacks: ice hits bite harder per stack
var brittle_t := 0.0
var crush_t := 0.0     # recently displaced hard: void hits bite (crush window)


static func make(game_node: Node2D, enemy_kind: String, pos: Vector2, at_level := -1) -> Enemy:
	var e := Enemy.new()
	e._setup(game_node, enemy_kind, pos, at_level)
	return e


func _setup(game_node: Node2D, enemy_kind: String, pos: Vector2, at_level := -1) -> void:
	game = game_node
	kind = enemy_kind
	var stats: Dictionary = _stats_for(enemy_kind)
	display_name = stats["name"]
	# Stats scale with the monster's LEVEL and its per-kind growth rates.
	# The listed level is a MINIMUM (no downscaling): asking for less
	# clamps UP — the monster arrives at its anchor, stats as-is.
	var want: int = at_level if at_level > 0 else int(stats.get("level", 1))
	var scaled := _stats_at(enemy_kind, want)
	level = scaled["level"]
	max_hp = scaled["hp"]
	hp = max_hp
	dmg = scaled["dmg"]
	speed = stats["speed"]
	xp_value = scaled["xp"]
	gold_value = scaled["gold"]
	ranged = stats["ranged"]
	physres = scaled["physres"]
	magres = scaled["magres"]
	eva = scaled["eva"]
	critres = scaled["critres"]
	crit = scaled["crit"]
	dex = scaled["dex"]
	physpen = scaled["physpen"]
	magpen = scaled["magpen"]
	dmg_type = stats.get("dmg_type", "phys")
	global_position = pos
	home = pos
	anim_t = randf() * 10.0
	add_to_group("enemies")

	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0 * stats["scale"] * 0.7
	cs.shape = shape
	add_child(cs)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(stats["scale"] * 0.75, stats["scale"] * 0.75)
	shadow.position = Vector2(0, 6.0 * stats["scale"])
	add_child(shadow)

	sprite = Sprite2D.new()
	art_scale = float(stats["scale"])
	var anim := Art.anim_info(stats["sprite"])
	if anim.is_empty():
		sprite.texture = Art.tex(stats["sprite"])
		sprite.scale = Art.scale_for(sprite.texture, art_scale)
	else:
		# Animated override strip (Track C seam): same Sprite2D, hframes on.
		_strip_idle = anim
		_strip_walk = Art.walk_info(stats["sprite"])
		_apply_strip(anim)
	face_left = Art.faces_left(stats["sprite"])
	add_child(sprite)

	# Tiny HP bar above the head, shown once the monster is damaged.
	var bar_y: float = -8.0 * stats["scale"] - 8.0
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0, 0, 0, 0.7)
	hp_bar_bg.position = Vector2(-16, bar_y)
	hp_bar_bg.size = Vector2(32, 5)
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)
	hp_bar_fg = ColorRect.new()
	hp_bar_fg.color = Color(0.9, 0.25, 0.2)
	hp_bar_fg.position = Vector2(-15, bar_y + 1)
	hp_bar_fg.size = Vector2(30, 3)
	hp_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_fg.visible = false
	add_child(hp_bar_fg)


## Stat lookup, overridable so chapter-content monsters (see Boss's
## Chapter 2 block + content/ch2_bosses.gd) can resolve outside
## Story.ENEMIES until T0's content registry lands.
func _stats_for(k: String) -> Dictionary:
	return Story.ALL_ENEMIES[k]  # base table + registered content modules


func _stats_at(k: String, lvl: int) -> Dictionary:
	return Story.enemy_stats_at(k, lvl)


## Point the Sprite2D at an idle/walk strip (hframes + normalized scale).
func _apply_strip(info: Dictionary) -> void:
	sprite.texture = info["tex"]
	var frames := int(info["frames"])
	sprite.hframes = frames
	sprite.frame = 0
	anim_frames = frames
	anim_fps = float(info["fps"])
	sprite.scale = Art.scale_for(sprite.texture, art_scale, frames)


func _physics_process(delta: float) -> void:
	if dying:
		return
	# Only the occupied room simulates: monsters elsewhere stand frozen
	# (zone_idx -1 — test dummies, boss adds, event spawns — always runs).
	if zone_idx >= 0 and game.cur_room != zone_idx:
		return
	anim_t += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)

	# --- status effects tick ---
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	vuln_time = maxf(0.0, vuln_time - delta)
	brittle_t = maxf(0.0, brittle_t - delta)
	if brittle_t <= 0.0:
		brittle = 0
	crush_t = maxf(0.0, crush_t - delta)
	# A shove/pull harder than ordinary hit-flinch opens a crush window.
	if knock.length() >= Balance.CRUSH_MIN_KNOCK:
		crush_t = Balance.CRUSH_WINDOW
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			var tick := burn_dps * 0.5
			# DoT ticks CRIT: rolled per tick on the player's SHEET crit
			# (burns carry no source ref — single-player, so the player
			# is the source), shaved by this target's critres like any
			# hit. Per-ability crit bonuses never ride into ticks, and
			# nothing snapshots — no fishing for a locked-in crit burn.
			var src: Player = game.player
			if src != null and randf() < Stats.crit_curve(src.crit) * (1.0 - Stats.res_frac(critres * 6.0)):
				tick *= src.crit_dmg
			take_damage(tick, Vector2.ZERO, false, true)
			if not dying:
				sprite.modulate = burn_color
	else:
		toxin = 0  # the stack dies with the burn

	if stun_time > 0.0:
		windup = 0.0
		sprite.modulate = Color(1, 1, 1)
		velocity = knock
		move_and_slide()
		return

	# Bite wind-up: the monster flashes yellow, then snaps. Gives the
	# player a beat to dodge or knock it back — readable combat.
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			sprite.modulate = Color(1, 1, 1)
			var player: Player = game.player
			if player and not player.dead and global_position.distance_to(player.global_position) < 64.0:
				player.take_damage(dmg, dmg_type, self)
		velocity = knock
		move_and_slide()
		return

	var move := _think(delta)
	if slow_time > 0.0:
		move *= slow_mult
	move *= hazard_speed  # ice patches boost, void rifts slow

	velocity = move + knock + game.gust_vec
	move_and_slide()
	if anim_frames > 1:
		# Walk/idle split: real walk frames while moving when the strip
		# exists, else idle at double-time (the shared anim_t clock
		# already ticked once this frame).
		var moving := velocity.length() > 20.0
		if not _strip_walk.is_empty() and moving != _strip_walking:
			_strip_walking = moving
			_apply_strip(_strip_walk if moving else _strip_idle)
		if moving:
			anim_t += delta
		sprite.frame = int(anim_t * anim_fps) % anim_frames
	if absf(velocity.x) > 5.0:
		# Left-facing art (Crawl sprites) flips the opposite way.
		sprite.flip_h = (velocity.x > 0.0) if face_left else (velocity.x < 0.0)
	# Little walk bob so they feel alive.
	if velocity.length() > 20.0:
		sprite.position.y = -absf(sin(anim_t * 10.0)) * 2.5
	else:
		sprite.position.y = 0.0


## Decide where to move this frame. Bosses override this.
func _think(_delta: float) -> Vector2:
	var player: Player = game.player
	if player == null or player.dead:
		return _drift_home()

	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	if dist > aggro_range and not force_aggro:
		return _drift_home()
	if not alerted:
		alerted = true
		game.emote(self, "!", 0.9)
		# One noticed you — the whole pack answers (per-pack aggro).
		if zone_idx >= 0:
			game.wake_pack(zone_idx, pack_id)

	if ranged:
		if attack_cd <= 0.0:
			attack_cd = 1.58
			game.sfx("bolt")
			# Playtest round 2: bolts fly noticeably faster — walking
			# lazily out of their path stops being free.
			var p := Projectile.spawn(game, global_position, to_player.normalized() * 420.0, dmg, false, "bolt")
			p.hostile_type = dmg_type
			p.source_enemy = self
		if dist < 200.0:
			return -to_player.normalized() * speed * 0.8
		elif dist > 300.0:
			return to_player.normalized() * speed
		return Vector2.ZERO
	else:
		if dist < 42.0:
			if attack_cd <= 0.0:
				attack_cd = 0.92
				windup = 0.27
				sprite.modulate = Color(2.0, 1.7, 0.5)  # "about to bite!" flash
			return Vector2.ZERO
		return to_player.normalized() * speed


func _drift_home() -> Vector2:
	var to_home := home - global_position
	if to_home.length() > 30.0:
		return to_home.normalized() * speed * 0.5
	return Vector2.ZERO


## Promote this monster to an ELITE — the between-boss miniboss beat
## (playtest round 6). Bigger and meaner than its kind, pays NO XP
## (the chapter XP total stays fixed) but its death rolls the good-loot
## table: guaranteed gem, guaranteed chest, reset stones and bags
## (game.on_enemy_died). Later chapters may promote several at once.
func promote_elite() -> void:
	if elite:
		return
	elite = true
	display_name = "Elite " + display_name
	max_hp *= Balance.ELITE_HP_MULT
	hp = max_hp
	dmg *= Balance.ELITE_DMG_MULT
	physres += Balance.ELITE_RES_BONUS
	magres += Balance.ELITE_RES_BONUS
	critres += Balance.ELITE_CRITRES_BONUS
	xp_value = 0  # elites never pay XP (fixed chapter totals)
	gold_value *= Balance.ELITE_GOLD_MULT
	sprite.scale *= Balance.ELITE_SPRITE_MULT
	# A gold ring underfoot marks the rank at a glance (body tints reset
	# on damage flashes, so a child sprite is the durable marker).
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(1.0, 0.8, 0.3, 0.75)
	ring.position = Vector2(0, 14)
	ring.scale = Vector2(1.5, 0.85)
	ring.z_index = -1
	add_child(ring)


# ------------------------------------------------------------- statuses ---

func apply_stun(dur: float) -> void:
	# CC belongs to mobs and elites: bosses are outright IMMUNE (was a
	# 35% duration tax — short enough to read as a bug at boss doors,
	# long enough to tax every stun-themed variant's damage budget).
	# Boss kits that stun the boss ON PURPOSE (wall-slam vuln windows)
	# must write stun_time directly.
	if self is Boss:
		return
	stun_time = maxf(stun_time, dur)


func apply_burn(dps: float, dur: float, color := Color(1.4, 0.8, 0.6)) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, dur)
	burn_color = color


## Green-theme DoT (poison/venom): the exception to the no-stack burn
## rule — each application adds a toxin stack that deepens the TICK.
## Fast cadences ramp fast; the stack dies when the burn runs out.
func apply_toxin(dps: float, dur: float, color := Color(0.5, 1.2, 0.5)) -> void:
	toxin = mini(toxin + 1, Balance.TOXIN_MAX_STACKS)
	apply_burn(dps * (1.0 + toxin * Balance.TOXIN_PER_STACK), dur, color)


## Ice hits crack the target: brittle stacks amplify ICE damage only
## (theme-internal — see Balance.BRITTLE_PER_STACK).
func add_brittle() -> void:
	brittle = mini(brittle + 1, Balance.BRITTLE_MAX_STACKS)
	brittle_t = Balance.BRITTLE_DUR


func apply_slow(mult: float, dur: float) -> void:
	if self is Boss:
		return  # CC-immune, same rule as stuns
	slow_mult = minf(slow_mult, mult) if slow_time > 0.0 else mult
	slow_time = maxf(slow_time, dur)
	sprite.modulate = Color(0.6, 0.8, 1.3)


# --------------------------------------------------------------- damage ---

func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
	if dying or untargetable:
		return
	# Wounding one pack member wakes its whole pack (ranged openers too).
	if zone_idx >= 0 and not force_aggro:
		game.wake_pack(zone_idx, pack_id)
	if vuln_time > 0.0:
		amount *= 1.5
	hp -= amount
	knock = from_dir * (220.0 if is_crit else 160.0)
	if not silent:
		game.sfx("ehit")
		if is_crit:
			game.spawn_text(global_position + Vector2(0, -34), "%d!" % int(amount), Color(1.0, 0.55, 0.1))
		else:
			game.spawn_text(global_position + Vector2(0, -30), str(int(amount)), Color(1, 1, 1))
		sprite.modulate = Color(3, 3, 3)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	# Show and update the overhead HP bar once damaged.
	if hp_bar_bg and hp < max_hp and not dying:
		hp_bar_bg.visible = true
		hp_bar_fg.visible = true
		hp_bar_fg.size.x = 30.0 * clampf(hp / max_hp, 0.0, 1.0)
	if hp <= 0.0:
		die()


func die() -> void:
	dying = true
	collision_layer = 0
	collision_mask = 0
	if hp_bar_bg:
		hp_bar_bg.visible = false
		hp_bar_fg.visible = false
	remove_from_group("enemies")
	game.sfx("edie")
	game.burst(global_position, Color(0.9, 0.3, 0.3))
	if is_instance_valid(game.player):
		game.player.gain_xp(xp_value)
	# Deferred: loot spawns collision objects, which is not allowed
	# in the middle of a physics callback (e.g. a projectile hit).
	game.on_enemy_died.call_deferred(self)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.3, 0.35)
	tween.tween_callback(queue_free)
