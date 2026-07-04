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
var story_boss := false      # spawned by the zone flow (drives quests on death)


static func make_boss(game_node: Node2D, boss_kind: String, pos: Vector2, at_level := -1) -> Boss:
	var b := Boss.new()
	b._setup(game_node, boss_kind, pos, at_level)
	b.aggro_range = 900.0
	return b


## Hostile bolt that carries the boss's damage type and combat stats
## (crit/pen/dex) so it resolves against the player like any real hit.
func _bolt(velocity: Vector2, damage: float) -> void:
	var p := Projectile.spawn(game, global_position, velocity, damage, false, "bolt")
	p.hostile_type = dmg_type
	p.source_enemy = self


## Boss voice: uses the per-boss sound (roar_fangmaw = wolf howl,
## roar_morwen = spectral wail, roar_vargoth = giant) when present.
func roar() -> void:
	var key := "roar_" + kind
	# Long recordings (the real wolf howl) get faded after ~2.5s.
	game.sfx(key if game.sounds.has(key) else "roar", 1.0, 2.5)


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
	speed = _stats_for(kind)["speed"]  # (T4) content bosses resolve here too
	_reset_ch2_state()


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
		"stormwarden":  # (T4) Chapter 2 block at the end of this file
			return _stormwarden(player, to_player, dist)
		"choirmother":
			return _choirmother(player, to_player, dist)
		"nullwarden":
			return _nullwarden(player, to_player, dist)
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
			player.take_damage(dmg * 1.4, dmg_type, self)
		return charge_dir * 620.0

	if hp <= max_hp * 0.5 and not summoned:
		summoned = true
		roar()
		game.spawn_text(global_position + Vector2(0, -80), "Fangmaw calls the pack!", Color(1, 0.5, 0.4))
		for offset in [Vector2(-90, -50), Vector2(90, 50)]:
			var add := Enemy.make(game, "wolf", global_position + offset, level)
			add.xp_value = 0   # summons pay nothing: die-and-retry
			add.gold_value = 0  # must not farm the fight
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
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _pounce(player: Player) -> void:
	leaping = true
	roar()
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
	roar()
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
		roar()
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
			_bolt(aim.rotated(spread) * 320.0, dmg)

	# Full ring of bolts.
	if ring_cd <= 0.0:
		ring_cd = 7.0
		roar()
		for i in 12:
			var angle := TAU * i / 12.0
			_bolt(Vector2.RIGHT.rotated(angle) * 200.0, dmg)

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
		roar()
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
			_bolt(Vector2.RIGHT.rotated(angle) * 230.0, dmg * 0.7)

	if dist < 64.0:
		if attack_cd <= 0.0:
			attack_cd = 1.1
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _blade_storm() -> void:
	roar()
	var count := 6 if enraged else 4
	for i in count:
		if dying or not is_instance_valid(game.player) or game.player.dead:
			return
		game.telegraph(game.player.global_position, 85.0, 0.8, 30.0, {"sword": true})
		await get_tree().create_timer(0.45 if enraged else 0.6).timeout


func die() -> void:
	if dying:
		return
	if story_boss:
		# Zone-spawned bosses — chapter 1's trio AND content bosses
		# placed in zone data — drive quests/gates/epilogue.
		game.on_boss_died.call_deferred(kind, self)
	else:
		# ANY boss killed outside the story flow (dev panel, tests):
		# rewards only. No dialogue, no gates, no boss_done marks, no
		# chapter end (playtest round 7: a spare dev-spawned Vargoth
		# died in the village and "won" chapter 1).
		game.on_rogue_boss_died.call_deferred(kind, self)
	super.die()


# ========================================================== Chapter 2 ---
# (T4) Content-module bosses. Their data lives in content/ch2_bosses.gd
# (merged into Story.ALL_ENEMIES by the content registry); everything
# else rides the same telegraph/enrage architecture as Chapter 1.

const CH2 := preload("res://scripts/content/ch2_bosses.gd")

var pack_calls := 0         # stormwarden: pack summons fired (max 2)
var adds_called := false    # choirmother: the choir has answered
var core_exposed := false   # nullwarden: 50% armor-shed phase


func _reset_ch2_state() -> void:
	pack_calls = 0
	adds_called = false
	if core_exposed:
		core_exposed = false
		physres = float(_stats_for(kind).get("physres", 0.0))


# --------------------------------------------- Korrag, Stormwarden Broken ---
## Whip-range skirmisher. Calls wolf packs at 66%/33%; at 30% the storm
## breaks: he speeds up and stray lightning starts hammering around you.
func _stormwarden(player: Player, to_player: Vector2, dist: float) -> Vector2:
	const STORM := Color(1.0, 0.95, 0.4, 0.6)
	# The warden never hunts alone: whistle the pack in at 66% and 33%.
	if (pack_calls == 0 and hp <= max_hp * 0.66) \
			or (pack_calls == 1 and hp <= max_hp * 0.33):
		pack_calls += 1
		roar()
		game.spawn_text(global_position + Vector2(0, -84),
			"Korrag whistles the pack in!", Color(1.0, 0.8, 0.3))
		for offset in [Vector2(-100, -60), Vector2(100, 60)]:
			var add := Enemy.make(game, "wolf", global_position + offset, level)
			add.xp_value = 0
			add.gold_value = 0
			add.force_aggro = true
			game.add_enemy(add)

	if hp <= max_hp * 0.3 and not enraged:
		enraged = true
		sprite.modulate = Color(0.8, 0.9, 1.7)
		speed *= 1.35
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "THE STORM BREAKS!", Color(0.6, 0.8, 1.0))

	# Signature: LIGHTNING LASH — a line of strikes whipped through you.
	if special_cd <= 0.0 and dist < 640.0:
		special_cd = 5.0 if enraged else 7.5
		_lightning_lash(player)

	# Broken storm: stray bolts hammer the ground around the prey.
	if enraged and ring_cd <= 0.0:
		ring_cd = 4.0
		for i in 3:
			game.telegraph(player.global_position
				+ Vector2(randf_range(-140.0, 140.0), randf_range(-110.0, 110.0)),
				70.0, 0.6, dmg * 1.1, {"color": STORM})

	# Whip snap keeps mid-range honest.
	if ability_cd <= 0.0 and dist > 80.0 and dist < 260.0:
		ability_cd = 3.4
		game.telegraph(player.global_position, 75.0, 0.5, dmg * 1.2, {"color": STORM})

	if dist < 70.0:
		if attack_cd <= 0.0:
			attack_cd = 1.0
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _lightning_lash(player: Player) -> void:
	roar()
	var dir := (player.global_position - global_position).normalized()
	for i in 5:
		game.telegraph(global_position + dir * (120.0 + i * 95.0), 80.0,
			0.5 + i * 0.11, dmg * 1.4, {"color": Color(1.0, 0.95, 0.4, 0.6)})


# ---------------------------------------------------- The Choir Mother ---
## Ranged hymnist. Requiem rings ripple outward, verse volleys harry,
## the hymn of hunger marks you and FEEDS her; the choir answers at 60%.
## At 25% the crescendo: denser volleys and a faster liturgy.
func _choirmother(player: Player, to_player: Vector2, dist: float) -> Vector2:
	const BLIGHT := Color(0.8, 0.4, 1.0, 0.55)
	if hp <= max_hp * 0.25 and not enraged:
		enraged = true
		sprite.modulate = Color(1.5, 0.7, 1.5)
		speed *= 1.25
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "THE CHOIR CRESCENDOS!", Color(0.9, 0.5, 1.0))

	if hp <= max_hp * 0.6 and not adds_called:
		adds_called = true
		roar()
		game.spawn_text(global_position + Vector2(0, -84),
			"The choir answers her call!", Color(0.8, 0.5, 1.0))
		for offset in [Vector2(-110, -40), Vector2(110, 40)]:
			var add := Enemy.make(game, "cultist", global_position + offset, level)
			add.xp_value = 0
			add.gold_value = 0
			add.force_aggro = true
			game.add_enemy(add)

	# Signature: REQUIEM — three rings of blight ripple OUT from her.
	if special_cd <= 0.0:
		special_cd = 6.0 if enraged else 9.0
		_requiem()

	# Verse volley.
	if ability_cd <= 0.0:
		ability_cd = 2.2 if enraged else 3.0
		game.sfx("bolt")
		var aim := to_player.normalized()
		var spreads := [-0.36, -0.12, 0.12, 0.36] if enraged else [-0.22, 0.0, 0.22]
		for spread in spreads:
			_bolt(aim.rotated(spread) * 300.0, dmg)

	# Hymn of hunger: a marked strike — and the choir feeds her.
	if ring_cd <= 0.0:
		ring_cd = 8.0
		game.telegraph(player.global_position, 90.0, 0.7, dmg * 1.3, {"color": BLIGHT})
		hp = minf(max_hp, hp + max_hp * 0.02)
		game.spawn_text(global_position + Vector2(0, -70), "the choir feeds her", Color(0.8, 0.5, 1.0))

	# Blink away from blades, like her predecessor.
	if dist < 160.0 and blink_cd <= 0.0:
		blink_cd = 3.2
		game.sfx("blink")
		var away := -to_player.normalized().rotated(randf_range(-0.9, 0.9))
		global_position = game.clamp_to_zone(
			global_position + away * randf_range(280.0, 420.0), home)
		return Vector2.ZERO

	if dist < 250.0:
		return -to_player.normalized() * speed
	elif dist > 360.0:
		return to_player.normalized() * speed
	return to_player.orthogonal().normalized() * speed * 0.5


func _requiem() -> void:
	roar()
	for ring in 3:
		var radius := 130.0 + ring * 100.0
		var count := 8 + ring * 4
		for i in count:
			var ang := TAU * i / count + ring * 0.3
			game.telegraph(global_position + Vector2.from_angle(ang) * radius, 62.0,
				0.65 + ring * 0.28, dmg * 1.25, {"color": Color(0.8, 0.4, 1.0, 0.55)})


# ------------------------------------------ Warden Null, the Last Sentinel ---
## Slow juggernaut. Piston grids stamp the arena, beam spokes rake the
## lane, shockwave slams shove you off it. Sheds armor at 50% (faster,
## softer), overdrives at 25%.
func _nullwarden(player: Player, to_player: Vector2, dist: float) -> Vector2:
	const CORE := Color(0.5, 0.9, 1.0, 0.55)
	if hp <= max_hp * 0.5 and not core_exposed:
		core_exposed = true
		physres = maxf(10.0, physres - 30.0)
		speed *= 1.3
		sprite.modulate = Color(1.5, 1.0, 0.6)
		roar()
		game.spawn_text(global_position + Vector2(0, -90),
			"ARMOR SHED — THE CORE IS EXPOSED!", Color(1.0, 0.8, 0.3))

	if hp <= max_hp * 0.25 and not enraged:
		enraged = true
		sprite.modulate = Color(1.7, 0.7, 0.5)
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "OVERDRIVE ENGAGED!", Color(1.0, 0.4, 0.2))

	# Signature: PISTON PROTOCOL — a grid of slams stamps your ground.
	if special_cd <= 0.0 and dist < 620.0:
		special_cd = 5.5 if enraged else 8.5
		_piston_protocol(player)

	# Beam spoke: one long line straight down your lane.
	if ring_cd <= 0.0 and dist < 560.0:
		ring_cd = 4.5 if enraged else 7.0
		var dir := to_player.normalized()
		for i in 7:
			game.telegraph(global_position + dir * (110.0 + i * 90.0), 70.0,
				0.55 + i * 0.08, dmg * 1.3, {"color": CORE})

	# Shockwave slam.
	if ability_cd <= 0.0 and dist < 480.0:
		ability_cd = 3.0 if enraged else 4.8
		game.sfx("slam")
		game.shake(9.0)
		var count := 20 if enraged else 12
		for i in count:
			_bolt(Vector2.RIGHT.rotated(TAU * i / count) * 210.0, dmg * 0.7)

	if dist < 74.0:
		if attack_cd <= 0.0:
			attack_cd = 1.3
			player.take_damage(dmg * 1.2, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _piston_protocol(player: Player) -> void:
	roar()
	# A 4-column grid stamps across the player's ground, column by column.
	var base: Vector2 = player.global_position
	for col in 4:
		for row in 3:
			game.telegraph(base + Vector2((col - 1.5) * 130.0, (row - 1) * 120.0),
				68.0, 0.55 + col * 0.16, dmg * 1.35, {"color": Color(0.5, 0.9, 1.0, 0.55)})
