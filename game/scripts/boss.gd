class_name Boss extends Enemy
## Boss monsters. Same body as a regular enemy, but with special
## attacks on timers and a big health bar. Three fights:
##   fangmaw  - dire wolf: telegraphed charge, summons wolves at 50% HP
##   morwen   - witch: bolt volleys, bolt rings, teleports away from you
##   vargoth  - skeleton king: shockwave slam, enrages below 30% HP

var ability_cd := 3.0        # main special attack timer
var ring_cd := 6.0           # morwen's / vargoth's radial attack timer
var blink_cd := 0.0
var special_cd := 2.2        # telegraphed signature move (pounce / rain / blades)
var leaping := false         # fangmaw mid-pounce
var summoned := false        # fangmaw's 50% wolves
var enraged := false         # vargoth's 30% enrage

# charge state (fangmaw)
var charging := false
var charge_dir := Vector2.ZERO
var charge_time := 0.0
var telegraphing := false


static func make_boss(game_node: Node2D, boss_kind: String, pos: Vector2) -> Boss:
	var b := Boss.new()
	b._setup(game_node, boss_kind, pos)
	b.aggro_range = 900.0
	return b


func reset_fight() -> void:
	# Called when the player dies: the boss walks back and heals up.
	hp = max_hp
	global_position = home
	charging = false
	telegraphing = false
	leaping = false
	ability_cd = 3.0
	special_cd = 3.0
	enraged = false
	stun_time = 0.0
	slow_time = 0.0
	burn_time = 0.0
	vuln_time = 0.0
	sprite.modulate = Color(1, 1, 1)
	speed = Story.ENEMIES[kind]["speed"]


func _think(delta: float) -> Vector2:
	var player: Player = game.player
	if player == null or player.dead:
		return _drift_home()
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	ability_cd = maxf(0.0, ability_cd - delta)
	ring_cd = maxf(0.0, ring_cd - delta)
	blink_cd = maxf(0.0, blink_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)

	match kind:
		"fangmaw":
			return _fangmaw(player, to_player, dist, delta)
		"morwen":
			return _morwen(player, to_player, dist)
		"vargoth":
			return _vargoth(player, to_player, dist)
	return Vector2.ZERO


# ------------------------------------------------------------- Fangmaw ---
func _fangmaw(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if leaping:
		return Vector2.ZERO
	# Signature: POUNCE — marks a danger circle on you, then crashes down.
	if special_cd <= 0.0 and not charging and not telegraphing and dist < 620.0:
		special_cd = 6.5
		_pounce(player)
		return Vector2.ZERO
	if charging:
		charge_time -= delta
		if charge_time <= 0.0:
			charging = false
		if dist < 70.0 and attack_cd <= 0.0:
			attack_cd = 0.8
			player.take_damage(dmg * 1.4)
		return charge_dir * 620.0

	if hp <= max_hp * 0.5 and not summoned:
		summoned = true
		game.sfx("roar")
		game.spawn_text(global_position + Vector2(0, -80), "Fangmaw calls the pack!", Color(1, 0.5, 0.4))
		for offset in [Vector2(-90, -50), Vector2(90, 50)]:
			var add := Enemy.make(game, "wolf", global_position + offset)
			add.force_aggro = true
			game.add_enemy(add)

	if ability_cd <= 0.0 and dist < 500.0 and not telegraphing:
		telegraphing = true
		_do_charge(to_player)
		return Vector2.ZERO
	if telegraphing:
		return Vector2.ZERO

	# Normal wolf behavior between charges.
	if dist < 60.0:
		if attack_cd <= 0.0:
			attack_cd = 1.0
			player.take_damage(dmg)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _pounce(player: Player) -> void:
	leaping = true
	game.sfx("roar")
	var target: Vector2 = player.global_position
	game.telegraph(target, 95.0, 0.85, dmg * 1.4)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: leaping = false)


func _do_charge(_to_player: Vector2) -> void:
	# Telegraph: flash red for a moment, THEN charge at where the player is.
	sprite.modulate = Color(2.5, 0.6, 0.6)
	await get_tree().create_timer(0.65).timeout
	if dying or not is_instance_valid(game.player):
		telegraphing = false
		return
	sprite.modulate = Color(1, 1, 1)
	game.sfx("roar")
	charge_dir = (game.player.global_position - global_position).normalized()
	charging = true
	charge_time = 0.55
	telegraphing = false
	ability_cd = 4.0


# -------------------------------------------------------------- Morwen ---
func _morwen(player: Player, to_player: Vector2, dist: float) -> Vector2:
	# Signature: BLIGHT RAIN — poison zones bloom under and around you.
	if special_cd <= 0.0:
		special_cd = 8.0
		game.sfx("roar")
		for i in 4:
			var offset := Vector2.ZERO if i == 0 else Vector2(randf_range(-160, 160), randf_range(-120, 120))
			game.telegraph(player.global_position + offset, 75.0, 0.75 + i * 0.12, dmg * 1.3,
				{"color": Color(0.55, 1.0, 0.25, 0.55)})

	# Blink away when the knight gets close.
	if dist < 160.0 and blink_cd <= 0.0:
		blink_cd = 3.0
		game.sfx("blink")
		var away := -to_player.normalized().rotated(randf_range(-0.9, 0.9))
		global_position = game.clamp_to_zone(global_position + away * randf_range(280.0, 400.0), home)
		return Vector2.ZERO

	# 3-bolt spread.
	if ability_cd <= 0.0:
		ability_cd = 2.6
		game.sfx("bolt")
		var aim := to_player.normalized()
		for spread in [-0.25, 0.0, 0.25]:
			Projectile.spawn(game, global_position, aim.rotated(spread) * 320.0, dmg, false, "bolt")

	# Full ring of bolts.
	if ring_cd <= 0.0:
		ring_cd = 7.0
		game.sfx("roar")
		for i in 12:
			var angle := TAU * i / 12.0
			Projectile.spawn(game, global_position, Vector2.RIGHT.rotated(angle) * 200.0, dmg, false, "bolt")

	# Drift to keep a comfortable distance.
	if dist < 240.0:
		return -to_player.normalized() * speed
	elif dist > 340.0:
		return to_player.normalized() * speed
	return to_player.orthogonal().normalized() * speed * 0.5


# ------------------------------------------------------------- Vargoth ---
func _vargoth(player: Player, to_player: Vector2, dist: float) -> Vector2:
	if hp <= max_hp * 0.3 and not enraged:
		enraged = true
		sprite.modulate = Color(1.6, 0.55, 0.55)
		speed *= 1.5
		game.sfx("roar")
		game.spawn_text(global_position + Vector2(0, -90), "VARGOTH ENRAGES!", Color(1, 0.3, 0.3))

	# Signature: BLADE STORM — greatswords fall from the sky onto marked
	# ground, chasing the player's position. Dodge or take heavy damage.
	if special_cd <= 0.0 and dist < 560.0:
		special_cd = 6.0 if enraged else 9.0
		_blade_storm()

	# Shockwave slam: ring of slow bolts + screen shake.
	if ability_cd <= 0.0 and dist < 520.0:
		ability_cd = 3.4 if enraged else 5.0
		game.sfx("slam")
		game.shake(8.0)
		var count := 16
		for i in count:
			var angle := TAU * i / count
			Projectile.spawn(game, global_position, Vector2.RIGHT.rotated(angle) * 230.0, dmg * 0.7, false, "bolt")

	if dist < 64.0:
		if attack_cd <= 0.0:
			attack_cd = 1.1
			player.take_damage(dmg)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _blade_storm() -> void:
	game.sfx("roar")
	var count := 6 if enraged else 4
	for i in count:
		if dying or not is_instance_valid(game.player) or game.player.dead:
			return
		game.telegraph(game.player.global_position, 85.0, 0.8, 30.0, {"sword": true})
		await get_tree().create_timer(0.45 if enraged else 0.6).timeout


func die() -> void:
	if dying:
		return
	game.on_boss_died.call_deferred(kind)
	super.die()
