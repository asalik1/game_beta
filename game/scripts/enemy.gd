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

var aggro_range := 330.0
var attack_cd := 0.0
var knock := Vector2.ZERO
var home := Vector2.ZERO
var sprite: Sprite2D
var dying := false
var anim_t := 0.0

# --- status effects ---
var stun_time := 0.0
var slow_time := 0.0
var slow_mult := 1.0
var burn_time := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
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
	sprite.scale = Vector2(stats["scale"], stats["scale"])
	add_child(sprite)


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
				sprite.modulate = Color(1.4, 0.8, 0.6)

	if stun_time > 0.0:
		velocity = knock
		move_and_slide()
		return

	var move := _think(delta)
	if slow_time > 0.0:
		move *= slow_mult

	velocity = move + knock
	move_and_slide()
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0.0
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
	if dist > aggro_range:
		return _drift_home()

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
		if dist < 40.0:
			if attack_cd <= 0.0:
				attack_cd = 1.0
				player.take_damage(dmg)
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


func apply_burn(dps: float, dur: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, dur)


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
	if hp <= 0.0:
		die()


func die() -> void:
	dying = true
	collision_layer = 0
	collision_mask = 0
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
