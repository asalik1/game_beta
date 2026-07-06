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
	summoned = false  # fangmaw's 50% pack-call re-arms for the retry
	stun_time = 0.0
	slow_time = 0.0
	burn_time = 0.0
	vuln_time = 0.0
	sprite.modulate = Color(1, 1, 1)
	speed = _stats_for(kind)["speed"]  # (T4) content bosses resolve here too
	_reset_ch2_state()
	_reset_ch3_state()
	_reset_ch4_state()


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
		"sexton":  # Chapter 3 block (The Unburied Vale) at the end of this file
			return _sexton(player, to_player, dist, delta)
		"vess":
			return _vess(player, to_player, dist)
		"saint_varo":
			return _saint_varo(player, to_player, dist, delta)
		"forgemistress":  # Chapter 4 block (The Slagfields) at the end of this file
			return _forgemistress(player, to_player, dist, delta)
		"cinderhide":
			return _cinderhide(player, to_player, dist, delta)
		"ashpriest":
			return _ashpriest(player, to_player, dist, delta)
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
			attack_cd = 0.72
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
			attack_cd = 0.92
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _pounce(player: Player) -> void:
	leaping = true
	roar()
	var target: Vector2 = player.global_position
	game.telegraph(target, 95.0, 0.76, dmg * 1.4)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: leaping = false)


func _do_charge(_to_player: Vector2) -> void:
	# Telegraph: flash red for a moment, THEN charge at where the player is.
	sprite.modulate = Color(2.5, 0.6, 0.6)
	await get_tree().create_timer(0.58).timeout
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
			game.telegraph(player.global_position + offset, 75.0, 0.68 + i * 0.11, dmg * 1.3,
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
			attack_cd = 1.0
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _blade_storm() -> void:
	roar()
	var count := 6 if enraged else 4
	for i in count:
		if dying or not is_instance_valid(game.player) or game.player.dead:
			return
		game.telegraph(game.player.global_position, 85.0, 0.72, dmg * 1.3, {"sword": true})
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
	# (Ch3) The censers gutter out with their saint.
	for c in censers:
		if is_instance_valid(c):
			c.queue_free()
	# (Ch4) Slag pools / marching sons clean up with their master.
	_clear_boss_props()
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
		# Restore the LEVEL-SCALED armor, not the anchor value — a
		# Nightmare-tier warden must not reset into story-tier plating.
		physres = float(_stats_at(kind, level)["physres"])


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
				70.0, 0.55, dmg * 1.1, {"color": STORM})

	# Whip snap keeps mid-range honest.
	if ability_cd <= 0.0 and dist > 80.0 and dist < 260.0:
		ability_cd = 3.4
		game.telegraph(player.global_position, 75.0, 0.45, dmg * 1.2, {"color": STORM})

	if dist < 70.0:
		if attack_cd <= 0.0:
			attack_cd = 0.92
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _lightning_lash(player: Player) -> void:
	roar()
	var dir := (player.global_position - global_position).normalized()
	for i in 5:
		game.telegraph(global_position + dir * (120.0 + i * 95.0), 80.0,
			0.45 + i * 0.10, dmg * 1.4, {"color": Color(1.0, 0.95, 0.4, 0.6)})


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
		game.telegraph(player.global_position, 90.0, 0.62, dmg * 1.3, {"color": BLIGHT})
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
				0.58 + ring * 0.25, dmg * 1.25, {"color": Color(0.8, 0.4, 1.0, 0.55)})


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
				0.5 + i * 0.075, dmg * 1.3, {"color": CORE})

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
			attack_cd = 1.15
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
				68.0, 0.5 + col * 0.145, dmg * 1.35, {"color": Color(0.5, 0.9, 1.0, 0.55)})


# ========================================================== Chapter 3 ---
# The Unburied Vale (BOSSES.md). Data lives in content/ch3_bosses.gd;
# same telegraph/threshold architecture, two new primitives debut here:
# telegraph_safe (inverse safe-zone, game_base) and the burrow state
# (Enemy.untargetable). Placeholder sprites/music until assets land.

const GRAVE := Color(0.6, 0.45, 0.3, 0.6)     # sexton's churned earth
const DIRGE := Color(0.75, 0.8, 1.0, 0.55)    # vess's grief-pale blue
const INCENSE := Color(1.0, 0.9, 0.6, 0.55)   # varo's censer gold

var burrowed := false        # sexton (later: the auroch) — underground phase
var corpses: Array = []      # sexton: where his summons fell (Vector2s)
var tracked_adds: Array = [] # sexton: live summons watched for death spots
var grave_t := 0.0           # sexton: next grave-spawn timer
var censers: Array = []      # varo: the burning censer adds
var censer_wave := 0         # varo: relights fired (60% / 30%)
var toll_count := 0          # varo: bell tolls rung (safe spots shrink)
var varo_setup := false      # varo: censers placed on first think
var heal_text_t := 0.0       # varo: throttle for the incense flavor text


func _reset_ch3_state() -> void:
	if burrowed:
		burrowed = false
		untargetable = false
		collision_layer = 4
		collision_mask = 1 | 2 | 4
		sprite.visible = true
	corpses.clear()
	tracked_adds.clear()
	grave_t = 0.0
	for c in censers:
		if is_instance_valid(c):
			c.queue_free()
	censers.clear()
	censer_wave = 0
	toll_count = 0
	varo_setup = false


# --------------------------------- The Sexton, Gravedigger of the Vale ---
## Melee brute. Endless graves answer him (zero-reward shamblers), and
## any summon that dies near another corpse detonates both — kill the
## adds SPREAD OUT. Signature: SHOVELWORK — burrows, tears an eruption
## line at you, and surfaces out of it. No enrage; the arithmetic is
## the threat.
func _sexton(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if burrowed:
		return Vector2.ZERO
	_track_corpses()

	# The Vale answers: a shambler claws up near the prey, all fight.
	grave_t -= delta
	if grave_t <= 0.0:
		grave_t = 7.0
		var live := 0
		for a in tracked_adds:
			if is_instance_valid(a) and not a.dying:
				live += 1
		if live < 4:
			var at: Vector2 = game.clamp_to_zone(player.global_position
				+ Vector2.from_angle(randf() * TAU) * randf_range(140.0, 220.0), home)
			var add := Enemy.make(game, "zombie", at, level)
			add.xp_value = 0
			add.gold_value = 0
			add.force_aggro = true
			game.add_enemy(add)
			tracked_adds.append(add)
			game.burst(at, GRAVE, 12)

	# Signature: SHOVELWORK — under the dirt and up through your floor.
	if special_cd <= 0.0 and dist < 600.0:
		special_cd = 8.0
		_shovelwork(player)
		return Vector2.ZERO

	# Shovel swipe keeps mid-range honest.
	if ability_cd <= 0.0 and dist < 300.0:
		ability_cd = 4.0
		game.telegraph(player.global_position, 70.0, 0.5, dmg * 1.1, {"color": GRAVE})

	if dist < 64.0:
		if attack_cd <= 0.0:
			attack_cd = 1.0
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


## Watch the summons: when one dies, its resting spot becomes a corpse.
## A corpse falling within 180px of another detonates BOTH (telegraphed)
## — the positioning lesson the whole chapter is built on.
func _track_corpses() -> void:
	var still: Array = []
	for a in tracked_adds:
		if not is_instance_valid(a):
			continue  # freed before we saw it fall — no corpse to mark
		if not a.dying:
			still.append(a)
			continue
		var fell: Vector2 = a.global_position
		var chained := false
		for c in corpses:
			var rest: Vector2 = c
			if fell.distance_to(rest) <= 180.0:
				chained = true
				game.telegraph(fell, 85.0, 0.6, dmg * 1.3, {"color": Color(0.55, 0.9, 0.3, 0.6)})
				game.telegraph(rest, 85.0, 0.6, dmg * 1.3, {"color": Color(0.55, 0.9, 0.3, 0.6)})
				corpses.erase(rest)
				break
		if not chained:
			corpses.append(fell)
			if corpses.size() > 6:
				corpses.pop_front()
	tracked_adds = still


func _shovelwork(player: Player) -> void:
	burrowed = true
	untargetable = true
	collision_layer = 0
	collision_mask = 0
	sprite.visible = false
	game.sfx("slam")
	game.burst(global_position, GRAVE, 16)
	var from := global_position
	var dir := (player.global_position - from).normalized()
	var span := minf(from.distance_to(player.global_position), 480.0)
	var steps := 4
	for i in steps:
		game.telegraph(from + dir * span * float(i + 1) / float(steps), 75.0,
			0.35 + i * 0.14, dmg * 1.2, {"color": GRAVE})
	await get_tree().create_timer(1.1).timeout
	if dying or not burrowed:
		return  # killed mid-dig or the fight reset under us
	global_position = game.clamp_to_zone(from + dir * span, home)
	burrowed = false
	untargetable = false
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	sprite.visible = true
	game.burst(global_position, GRAVE, 20)
	roar()


# ------------------------------------- Vess the Unburied, First Widow ---
## Ranged banshee. Grief fans that ECHO from where she cast them, a
## Morwen-lineage blink, and the SILENCE: the whole arena screams except
## one quiet circle — stand in it. At 30% she KEENS: the silence gains
## a flickering decoy circle (the steady one is the truth).
func _vess(player: Player, to_player: Vector2, dist: float) -> Vector2:
	if hp <= max_hp * 0.3 and not enraged:
		enraged = true
		sprite.modulate = Color(0.8, 0.85, 1.6)
		speed *= 1.2
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "VESS KEENS!", Color(0.75, 0.8, 1.0))

	# Signature: THE SILENCE — find the quiet circle before the wail.
	if special_cd <= 0.0:
		special_cd = 7.0 if enraged else 9.0
		_silence(player)

	# Grief fan: 3 bolts now, and the memory of them 0.8s later.
	if ability_cd <= 0.0:
		ability_cd = 2.8
		_grief_fan(to_player.normalized())

	# Wail ring, slow and wide.
	if ring_cd <= 0.0:
		ring_cd = 8.0
		roar()
		for i in 12:
			_bolt(Vector2.RIGHT.rotated(TAU * i / 12.0) * 190.0, dmg)

	# Blink away from blades (her grief is Morwen's lineage).
	if dist < 160.0 and blink_cd <= 0.0:
		blink_cd = 3.0
		game.sfx("blink")
		var away := -to_player.normalized().rotated(randf_range(-0.9, 0.9))
		global_position = game.clamp_to_zone(
			global_position + away * randf_range(280.0, 400.0), home)
		return Vector2.ZERO

	if dist < 240.0:
		return -to_player.normalized() * speed
	elif dist > 340.0:
		return to_player.normalized() * speed
	return to_player.orthogonal().normalized() * speed * 0.5


func _silence(player: Player) -> void:
	roar()
	game.spawn_text(global_position + Vector2(0, -84), "FIND THE SILENCE!", DIRGE)
	var dir := Vector2.from_angle(randf() * TAU)
	var safe: Vector2 = game.clamp_to_zone(player.global_position + dir * 240.0, home)
	var opts := {"color": DIRGE}
	if enraged:
		opts["decoys"] = [game.clamp_to_zone(player.global_position - dir * 260.0, home)]
	game.telegraph_safe([safe], 110.0, 2.0, dmg * 2.0, opts)


func _grief_fan(aim: Vector2) -> void:
	game.sfx("bolt")
	var from := global_position
	for spread in [-0.22, 0.0, 0.22]:
		_bolt(aim.rotated(spread) * 320.0, dmg)
	await get_tree().create_timer(0.8).timeout
	if dying:
		return
	# The echo fires from where she CAST it — dodge the memory too.
	game.sfx("bolt")
	for spread in [-0.22, 0.0, 0.22]:
		var p := Projectile.spawn(game, from, aim.rotated(spread) * 320.0, dmg, false, "bolt")
		p.hostile_type = dmg_type
		p.source_enemy = self


# ------------------------------------------ Saint Varo the Unrotting ---
## Slow holy-horror juggernaut. Three censers ring the arena and their
## incense HEALS him — kill them (they relight at 60% and 30%). The
## TOLL: arena-wide bell strike except the marked shadows, and every
## toll cracks one — the shelter shrinks. At 25% he stands up for the
## first time in sixty years.
func _saint_varo(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if not varo_setup:
		varo_setup = true
		_spawn_censers()
		game.spawn_text(global_position + Vector2(0, -84), "The censers burn.", INCENSE)

	# Incense: while any censer lives, he mends. Snuff them out.
	var incense := false
	for c in censers:
		if is_instance_valid(c) and not c.dying:
			incense = true
			break
	if incense:
		hp = minf(max_hp, hp + max_hp * 0.015 * delta)
		heal_text_t -= delta
		if heal_text_t <= 0.0:
			heal_text_t = 3.0
			game.spawn_text(global_position + Vector2(0, -70), "the incense sustains him", INCENSE)

	# The congregation relights the censers at 60% and 30%.
	if censer_wave == 0 and hp <= max_hp * 0.6:
		censer_wave = 1
		_spawn_censers()
		game.spawn_text(global_position + Vector2(0, -84), "The congregation relights the censers!", INCENSE)
	elif censer_wave == 1 and hp <= max_hp * 0.3:
		censer_wave = 2
		_spawn_censers()
		game.spawn_text(global_position + Vector2(0, -84), "The congregation relights the censers!", INCENSE)

	if hp <= max_hp * 0.25 and not enraged:
		enraged = true
		speed *= 1.5
		sprite.modulate = Color(1.4, 1.3, 0.9)
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "SAINT VARO STANDS.", Color(1.0, 0.9, 0.5))

	# Signature: THE TOLL — shelter in a shadow; each toll cracks one.
	if special_cd <= 0.0 and dist < 640.0:
		special_cd = 6.0 if enraged else 9.0
		_toll()

	# Reliquary rain: falling blades chase the penitent.
	if ring_cd <= 0.0 and dist < 560.0:
		ring_cd = 7.0
		_reliquary_rain()

	# Reliquary slam: the Vargoth lineage, slower and heavier.
	if ability_cd <= 0.0 and dist < 500.0:
		ability_cd = 3.4 if enraged else 5.0
		game.sfx("slam")
		game.shake(8.0)
		for i in 14:
			_bolt(Vector2.RIGHT.rotated(TAU * i / 14.0) * 210.0, dmg * 0.7)

	if dist < 70.0:
		if attack_cd <= 0.0:
			attack_cd = 1.2
			player.take_damage(dmg * 1.2, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _spawn_censers() -> void:
	var live := 0
	for c in censers:
		if is_instance_valid(c) and not c.dying:
			live += 1
	var base_ang := randf() * TAU
	for i in maxi(0, 3 - live):
		var at: Vector2 = game.clamp_to_zone(home
			+ Vector2.from_angle(base_ang + TAU * i / 3.0) * 260.0, home)
		var cens := Enemy.make(game, "choir_censer", at, level)
		cens.xp_value = 0
		cens.gold_value = 0
		cens.attack_cd = 1.0e9   # scenery that bleeds: it never swings
		cens.aggro_range = 0.0   # and never alerts — kill it or don't
		game.add_enemy(cens)
		censers.append(cens)
		game.burst(at, INCENSE, 10)


func _toll() -> void:
	roar()
	game.spawn_text(global_position + Vector2(0, -84), "THE BELL TOLLS — STAND IN A SHADOW!", INCENSE)
	var count := maxi(1, 3 - toll_count)
	toll_count += 1
	var centers: Array = []
	var base_ang := randf() * TAU
	for i in count:
		centers.append(game.clamp_to_zone(global_position
			+ Vector2.from_angle(base_ang + TAU * i / float(count)) * 310.0, home))
	game.telegraph_safe(centers, 100.0, 2.2, dmg * 1.8, {"color": INCENSE})


func _reliquary_rain() -> void:
	for i in 3:
		if dying or not is_instance_valid(game.player) or game.player.dead:
			return
		game.telegraph(game.player.global_position, 85.0, 0.75, dmg * 1.3, {"sword": true})
		await get_tree().create_timer(0.55).timeout


# ========================================================== Chapter 4 ---
# The Slagfields (BOSSES.md). Data lives in content/ch4_bosses.gd. Three
# new primitives debut here per the toolbox: walk-to-point + intercept
# (Calda's quench, reused by Ordo's marching Sons), terrain-patch contact
# on a boss (Cinderhide's lava-melt), and rect/half-arena zones (Ordo's
# Verdict, reused by Cyrraeth). Placeholder sprites/music until assets land.

const FORGE := Color(1.0, 0.5, 0.15, 0.6)     # calda's forge-orange
const LAVA := Color(1.0, 0.35, 0.1, 0.5)      # cinderhide / ordo slag
const VERDICT := Color(1.0, 0.55, 0.2, 0.55)  # ordo's judgment

var boss_props: Array = []      # stationary visual props (slag pools) to free
var heat := 0.0                 # calda: 0..1 forge heat
var quenching := false          # calda: marching to a pool
var quench_target := Vector2.ZERO
var quench_stacks := 0          # calda: damage buff from clean quenches
var calda_setup := false
var plated := false             # cinderhide: obsidian plating up
var melt := 0.0                 # cinderhide: lava-contact meter
var plate_shed_t := 0.0         # cinderhide: seconds of exposed window left
var cinder_setup := false
var sons: Array = []            # ordo: marching ember adds
var sons_waves := 0             # ordo: relights fired (66% / 33%)
var verdict_speed := 1.0        # ordo: verdicts quicken as sons arrive
var ordo_setup := false


func _reset_ch4_state() -> void:
	_clear_boss_props()
	heat = 0.0
	quenching = false
	quench_stacks = 0
	calda_setup = false
	melt = 0.0
	plate_shed_t = 0.0
	if kind == "cinderhide":  # restore the honest base resists, not a melt value
		var base: Dictionary = _stats_at(kind, level)
		physres = float(base["physres"])
		magres = float(base["magres"])
	plated = false
	cinder_setup = false
	sons_waves = 0
	verdict_speed = 1.0
	ordo_setup = false


## Stationary props (Calda's pools) and marching adds (Ordo's Sons) die
## with their master or when the fight resets.
func _clear_boss_props() -> void:
	for p in boss_props:
		if is_instance_valid(p):
			p.queue_free()
	boss_props.clear()
	for s in sons:
		if is_instance_valid(s):
			s.queue_free()
	sons.clear()


## The arena rect for half/zone telegraphs — the room when placed in the
## world, a home-centred fallback for dev/selftest spawns.
func _arena_rect() -> Rect2:
	if zone_idx >= 0 and zone_idx < game.zone_count:
		return game.room_rect(zone_idx)
	return Rect2(home - Vector2(700, 500), Vector2(1400, 1000))


## Is the boss standing in a lava patch (its own vents, or the arena)?
func _on_lava() -> bool:
	for h in game.hazards:
		if String(h.get("type", "")) != "lava":
			continue
		var at: Vector2 = h.get("pos", Vector2.ZERO)
		if global_position.distance_to(at) <= float(h.get("radius", 0.0)):
			return true
	return false


# ------------------------------------------- Forgemistress Calda (L23) ---
## Melee skirmisher on a HEAT CLOCK: her weapon heats over ~12s (hits and
## telegraphs grow); she marches to a slag pool to QUENCH (reset heat +
## stacking damage buff). Body-block the pool and she quenches THROUGH you
## — the fight's hardest hit — and gains nothing.
func _forgemistress(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if not calda_setup:
		calda_setup = true
		_calda_pools()
		game.spawn_text(global_position + Vector2(0, -84), "The forge is cold — for now.", FORGE)

	if not quenching:
		heat = minf(1.0, heat + delta / 12.0)
	sprite.modulate = Color(1, 1, 1).lerp(Color(2.0, 0.9, 0.6), heat)

	# Signature: QUENCH — march to the nearest slag pool.
	if special_cd <= 0.0 and not quenching and boss_props.size() > 0:
		special_cd = 10.0
		quenching = true
		quench_target = _nearest_pool()
		roar()
		game.spawn_text(global_position + Vector2(0, -84), "Calda moves to quench!", FORGE)
	if quenching:
		if global_position.distance_to(quench_target) <= 60.0:
			quenching = false
			_do_quench(player)
			return Vector2.ZERO
		return (quench_target - global_position).normalized() * speed

	# Hammer lines: forge-orange lash telegraphs, wider when white-hot.
	if ability_cd <= 0.0 and dist < 520.0:
		ability_cd = 3.4
		var dir := to_player.normalized()
		var rad := 105.0 if heat >= 1.0 else 75.0
		for i in 4:
			game.telegraph(global_position + dir * (110.0 + i * 95.0), rad,
				0.45 + i * 0.10, dmg * (1.0 + 0.12 * quench_stacks) * 1.2, {"color": FORGE})

	if dist < 66.0:
		if attack_cd <= 0.0:
			attack_cd = 0.9
			var hit := dmg * (1.0 + 0.12 * quench_stacks) * (1.3 if heat >= 1.0 else 1.0)
			player.take_damage(hit, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _calda_pools() -> void:
	var base_ang := randf() * TAU
	for i in 3:
		var at: Vector2 = game.clamp_to_zone(home + Vector2.from_angle(base_ang + TAU * i / 3.0) * 300.0, home)
		var pool := Sprite2D.new()
		pool.texture = Art.tex("glow")
		pool.modulate = Color(1.0, 0.4, 0.1, 0.5)
		pool.global_position = at
		pool.scale = Vector2(4.6, 4.0)
		pool.z_index = -7
		game.world.add_child(pool)
		boss_props.append(pool)


func _nearest_pool() -> Vector2:
	var best := global_position
	var bd := 1.0e9
	for p in boss_props:
		if not is_instance_valid(p):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = p.global_position
	return best


func _do_quench(player: Player) -> void:
	if player.global_position.distance_to(quench_target) <= 120.0:
		# Body-blocked: she quenches THROUGH the player — no buff, but the
		# hardest hit in the fight lands where she meant the pool to be.
		game.spawn_text(quench_target + Vector2(0, -60), "QUENCHED THROUGH!", FORGE)
		game.telegraph(quench_target, 130.0, 0.5, dmg * 2.2, {"color": FORGE})
		heat = 0.0
	else:
		quench_stacks += 1
		heat = 0.0
		game.burst(quench_target, FORGE, 16)
		game.spawn_text(global_position + Vector2(0, -70),
			"Calda quenches — her edge sharpens (x%d)" % quench_stacks, FORGE)


# ------------------------------------------ Cinderhide the Unquenched (L25) ---
## Armored beast, near-immune while PLATED (physres/magres ~85). Lava is
## the answer: standing in it melts the plating (bait the Fangmaw-lineage
## charge across a pool it vented). At full melt the plates shed ~10s and
## the damage window opens — but a magma tantrum rides it. At 30% the
## plates stop regrowing and it enrages into a chase.
func _cinderhide(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if not cinder_setup:
		cinder_setup = true
		plated = true
		physres += 60.0
		magres += 60.0
		game.spawn_text(global_position + Vector2(0, -84), "Its obsidian hide is a meter thick.", LAVA)

	# Lava contact melts the plating.
	if _on_lava():
		melt += delta
		game.burst(global_position, LAVA, 2)
	else:
		melt = maxf(0.0, melt - delta * 0.4)
	if plated and melt >= 2.5:
		plated = false
		melt = 0.0
		plate_shed_t = 10.0
		physres = maxf(15.0, physres - 60.0)
		magres = maxf(15.0, magres - 60.0)
		sprite.modulate = Color(1.6, 0.8, 0.5)
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "THE PLATING SHEDS!", Color(1.0, 0.7, 0.3))
		_tantrum()
	if plate_shed_t > 0.0:
		plate_shed_t -= delta
		if plate_shed_t <= 0.0 and hp > max_hp * 0.3 and not enraged:
			plated = true
			physres += 60.0
			magres += 60.0
			sprite.modulate = Color(1, 1, 1)
			game.spawn_text(global_position + Vector2(0, -84), "The obsidian reforms.", LAVA)

	if hp <= max_hp * 0.3 and not enraged:
		enraged = true
		if plated:  # plates stop regrowing — the window stays open
			plated = false
			physres = maxf(15.0, physres - 60.0)
			magres = maxf(15.0, magres - 60.0)
		plate_shed_t = 0.0
		speed *= 1.35
		sprite.modulate = Color(1.7, 0.6, 0.4)
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "CINDERHIDE ENRAGES!", Color(1.0, 0.4, 0.2))

	if charging:
		charge_time -= delta
		if charge_time <= 0.0:
			charging = false
		if dist < 76.0 and attack_cd <= 0.0:
			attack_cd = 0.8
			player.take_damage(dmg * 1.3, dmg_type, self)
		return charge_dir * 600.0

	# Signature: VENT BREATH — a cone that lingers as the lava you lure it into.
	if special_cd <= 0.0 and dist < 560.0:
		special_cd = 7.0 if enraged else 9.5
		_vent_breath(player)
		return Vector2.ZERO

	# Charge (Fangmaw lineage): bait it across a pool to melt the plating.
	if ability_cd <= 0.0 and dist < 520.0 and not telegraphing:
		telegraphing = true
		_do_charge(to_player)
		return Vector2.ZERO
	if telegraphing:
		return Vector2.ZERO

	# Enraged: extra magma rain hammers the chase.
	if enraged and ring_cd <= 0.0:
		ring_cd = 3.5
		for i in 3:
			game.telegraph(player.global_position + Vector2(randf_range(-160, 160), randf_range(-130, 130)),
				75.0, 0.6, dmg * 1.1, {"color": LAVA})

	if dist < 72.0:
		if attack_cd <= 0.0:
			attack_cd = 1.0
			player.take_damage(dmg, dmg_type, self)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _vent_breath(player: Player) -> void:
	roar()
	game.spawn_text(global_position + Vector2(0, -84), "Vent breath!", LAVA)
	var dir := (player.global_position - global_position).normalized()
	for i in 4:
		var at: Vector2 = game.clamp_to_zone(
			global_position + dir.rotated(randf_range(-0.35, 0.35)) * (150.0 + i * 90.0), home)
		game.telegraph(at, 80.0, 0.5 + i * 0.1, dmg * 1.2, {"color": LAVA})
		game._add_hazard(game.cur_room, "lava", at, 70.0, 6.0)


func _tantrum() -> void:
	if not is_instance_valid(game.player):
		return
	for i in 5:
		game.telegraph(game.player.global_position + Vector2(randf_range(-180, 180), randf_range(-150, 150)),
			78.0, 0.7 + i * 0.05, dmg * 1.2, {"color": LAVA})


# ----------------------- Ashpriest Ordo, Voice of the Molten Judge (L28) ---
## Ranged herald. THE VERDICT judges one half of the arena (paired below
## 50%); at 66% / 33% four SONS march toward him — each arrival heals him
## and quickens his verdicts, so intercept them. At 20% the Judge attends
## and magma rain runs continuous.
func _ashpriest(player: Player, to_player: Vector2, dist: float, delta: float) -> Vector2:
	if not ordo_setup:
		ordo_setup = true
		game.spawn_text(global_position + Vector2(0, -84), "The sermon begins.", VERDICT)

	_march_sons(delta)

	if (sons_waves == 0 and hp <= max_hp * 0.66) or (sons_waves == 1 and hp <= max_hp * 0.33):
		sons_waves += 1
		_spawn_sons()

	if hp <= max_hp * 0.2 and not enraged:
		enraged = true
		sprite.modulate = Color(1.6, 0.7, 0.4)
		roar()
		game.spawn_text(global_position + Vector2(0, -90), "THE JUDGE ATTENDS.", Color(1.0, 0.5, 0.2))

	# Signature: THE VERDICT — half the arena is judged.
	if special_cd <= 0.0:
		special_cd = (5.0 if enraged else 7.5) / verdict_speed
		_verdict()

	if enraged and ring_cd <= 0.0:
		ring_cd = 3.0
		for i in 3:
			game.telegraph(player.global_position + Vector2(randf_range(-170, 170), randf_range(-140, 140)),
				76.0, 0.6, dmg, {"color": LAVA})

	# Brand volleys keep the range honest.
	if ability_cd <= 0.0:
		ability_cd = 2.6
		game.sfx("bolt")
		var aim := to_player.normalized()
		for spread in [-0.28, -0.09, 0.09, 0.28]:
			_bolt(aim.rotated(spread) * 300.0, dmg)

	if dist < 250.0:
		return -to_player.normalized() * speed
	elif dist > 380.0:
		return to_player.normalized() * speed
	return to_player.orthogonal().normalized() * speed * 0.5


## Ember Sons crawl toward Ordo; the player intercepts. Each arrival is
## consumed for an +8% heal and faster verdicts.
func _march_sons(delta: float) -> void:
	var still: Array = []
	for s in sons:
		if not is_instance_valid(s) or s.dying:
			continue
		var to: Vector2 = global_position - s.global_position
		if to.length() <= 90.0:
			hp = minf(max_hp, hp + max_hp * 0.08)
			verdict_speed = minf(2.5, verdict_speed + 0.15)
			game.spawn_text(global_position + Vector2(0, -70), "the Judge consumes a Son", VERDICT)
			s.queue_free()
			continue
		s.global_position += to.normalized() * 70.0 * delta
		still.append(s)
	sons = still


func _spawn_sons() -> void:
	roar()
	game.spawn_text(global_position + Vector2(0, -84), "SONS OF THE JUDGE — INTERCEPT THEM!", VERDICT)
	var rect := _arena_rect()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var corner: Vector2 = corners[i]
		var at: Vector2 = game.clamp_to_zone(corner.lerp(rect.get_center(), 0.2), home)
		var son := Enemy.make(game, "cultist", at, level)
		son.xp_value = 0
		son.gold_value = 0
		son.speed = 0.0        # driven manually toward Ordo (not the player)
		son.aggro_range = 0.0  # they ignore you; you choose to stop them
		game.add_enemy(son)
		sons.append(son)
		game.burst(at, VERDICT, 10)


func _verdict() -> void:
	roar()
	var rect := _arena_rect()
	var west := randf() < 0.5
	game.spawn_text(global_position + Vector2(0, -84),
		"GUILTY: THE %s" % ("WEST" if west else "EAST"), VERDICT)
	var pairs := 2 if hp <= max_hp * 0.5 else 1
	for p in pairs:
		_judge_half(rect, west if p == 0 else not west, 2.4 + p * 0.5)


## Tile telegraphs across the judged half — the other half is the shelter.
func _judge_half(rect: Rect2, west: bool, delay: float) -> void:
	var x0 := rect.position.x + (0.0 if west else rect.size.x * 0.5)
	var half_w := rect.size.x * 0.5
	for cx in 5:
		for cy in 4:
			var at := Vector2(x0 + (cx + 0.5) / 5.0 * half_w,
				rect.position.y + (cy + 0.5) / 4.0 * rect.size.y)
			game.telegraph(at, 92.0, delay, dmg * 1.2, {"color": VERDICT})
