class_name Enemy extends CharacterBody2D
## A basic monster. Stats come from Story.ENEMIES, so one script
## covers wolves, spiders, cultists and skeletons.
## Supports status effects: stun, slow, burn, and vulnerability (Death Mark).

var game: Node2D
var kind := "wolf"
var display_name := "Monster"
var max_hp := 30.0
var hp := 30.0
var dmg := 8.0
var speed := 150.0
var xp_value := 12
var gold_value := 4
var ranged := false
# Defensive stats (see Stats for the curves).
var physres := 0.0
var magres := 0.0
var eva := 0.0
var critres := 0.0
var dmg_type := "phys"  # what this enemy's attacks count as

var aggro_range := 330.0
var attack_cd := 0.0
var windup := 0.0     # yellow-flash wind-up before a melee bite lands
var zone_idx := -1    # which zone's clear-count this enemy belongs to
var force_aggro := false  # zone entered: everyone attacks
var alerted := false  # has shown its "!" bubble
var hazard_speed := 1.0  # terrain patch effect (ice boosts, void slows)
var knock := Vector2.ZERO
var home := Vector2.ZERO
var sprite: Sprite2D
var hp_bar_bg: ColorRect
var hp_bar_fg: ColorRect
var face_left := false  # sprite art natively faces left (Crawl tiles)
var dying := false
var anim_t := 0.0

# --- status effects ---
var stun_time := 0.0
var slow_time := 0.0
var slow_mult := 1.0
var burn_time := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var burn_color := Color(1.4, 0.8, 0.6)  # orange = fire, green = poison
var vuln_time := 0.0   # takes +50% damage while marked


static func make(game_node: Node2D, enemy_kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e._setup(game_node, enemy_kind, pos)
	return e


func _setup(game_node: Node2D, enemy_kind: String, pos: Vector2) -> void:
	game = game_node
	kind = enemy_kind
	var stats: Dictionary = Story.ENEMIES[enemy_kind]
	display_name = stats["name"]
	max_hp = stats["hp"]
	hp = max_hp
	dmg = stats["dmg"]
	speed = stats["speed"]
	xp_value = stats["xp"]
	gold_value = stats.get("gold", 4)
	ranged = stats["ranged"]
	physres = stats.get("physres", 0.0)
	magres = stats.get("magres", 0.0)
	eva = stats.get("eva", 0.0)
	critres = stats.get("critres", 0.0)
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
	sprite.texture = Art.tex(stats["sprite"])
	sprite.scale = Art.scale_for(sprite.texture, stats["scale"])
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


func _physics_process(delta: float) -> void:
	if dying:
		return
	anim_t += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)

	# --- status effects tick ---
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	vuln_time = maxf(0.0, vuln_time - delta)
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			take_damage(burn_dps * 0.5, Vector2.ZERO, false, true)
			if not dying:
				sprite.modulate = burn_color

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
				player.take_damage(dmg, dmg_type)
		velocity = knock
		move_and_slide()
		return

	var move := _think(delta)
	if slow_time > 0.0:
		move *= slow_mult
	move *= hazard_speed  # ice patches boost, void rifts slow

	velocity = move + knock + game.gust_vec
	move_and_slide()
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

	if ranged:
		if attack_cd <= 0.0:
			attack_cd = 1.9
			game.sfx("bolt")
			Projectile.spawn(game, global_position, to_player.normalized() * 300.0, dmg, false, "bolt")
		if dist < 200.0:
			return -to_player.normalized() * speed * 0.8
		elif dist > 300.0:
			return to_player.normalized() * speed
		return Vector2.ZERO
	else:
		if dist < 42.0:
			if attack_cd <= 0.0:
				attack_cd = 1.2
				windup = 0.3
				sprite.modulate = Color(2.0, 1.7, 0.5)  # "about to bite!" flash
			return Vector2.ZERO
		return to_player.normalized() * speed


func _drift_home() -> Vector2:
	var to_home := home - global_position
	if to_home.length() > 30.0:
		return to_home.normalized() * speed * 0.5
	return Vector2.ZERO


# ------------------------------------------------------------- statuses ---

func apply_stun(dur: float) -> void:
	# Bosses shrug off most of a stun so they can't be perma-locked.
	stun_time = maxf(stun_time, dur * (0.35 if self is Boss else 1.0))


func apply_burn(dps: float, dur: float, color := Color(1.4, 0.8, 0.6)) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, dur)
	burn_color = color


func apply_slow(mult: float, dur: float) -> void:
	slow_mult = minf(slow_mult, mult) if slow_time > 0.0 else mult
	slow_time = maxf(slow_time, dur)
	sprite.modulate = Color(0.6, 0.8, 1.3)


# --------------------------------------------------------------- damage ---

func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
	if dying:
		return
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
