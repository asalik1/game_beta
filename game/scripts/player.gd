class_name Player extends CharacterBody2D
## The hero. Class is chosen at the start (warrior/archer/mage/assassin);
## each class has 3 basic abilities + 1 ultimate, all keyboard-driven and
## AUTO-AIMED at the nearest enemy (no mouse needed in combat).
## Stats are recomputed from: class base + level + gear + skill tree + evolution.

var game: Node2D  # set by game.gd

# --- identity ---
var cls := "warrior"
var evolution := ""   # "" until evolved (see Classes.EVOLVE_LEVEL)

# --- progression ---
var level := 1
var xp := 0
var skill_points := 0
var learned := {}      # skill node id -> true
var pending_evolution := false
var gold := 30
var potions := 3

# --- gear ---
var equipment := {}    # slot -> item Dictionary
var backpack: Array = []
const BACKPACK_MAX := 15

# --- vitals ---
var max_hp := 100.0
var hp := 100.0
var max_mp := 50.0
var mp := 50.0
var dead := false

# --- derived stats (never write these directly; recalc() builds them) ---
var atk := 12.0
var speed := 250.0
var crit := 0.05
var crit_dmg := 1.5
var cdr := 0.0
var lifesteal := 0.0
var dr := 0.0
var dodge := 0.0
var gold_pct := 0.0

# --- combat state ---
var cds := {"a1": 0.0, "a2": 0.0, "a3": 0.0, "ult": 0.0}
var potion_cd := 0.0
var hurt_cd := 0.0
var berserk_time := 0.0        # warrior ult
var storm_time := 0.0          # archer ult
var storm_tick := 0.0
var tumble_speed_time := 0.0   # archer "Adrenaline" node
var phase_time := 0.0          # mage "Phase Shift" node
var facing := Vector2.RIGHT
var anim_t := 0.0

var sprite: Sprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13
	cs.shape = shape
	add_child(cs)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 20)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = Art.tex(Classes.CLASSES[cls]["sprite"])
	sprite.scale = Vector2(3, 3)
	add_child(sprite)
	recalc()
	hp = max_hp
	mp = max_mp


func set_class(id: String) -> void:
	cls = id
	if sprite:
		sprite.texture = Art.tex(Classes.CLASSES[cls]["sprite"])
	recalc()
	hp = max_hp
	mp = max_mp


# ================================================================== stats

func xp_needed() -> int:
	return 20 + level * 15


## Rebuild every derived stat. Call after any gear/skill/level change.
func recalc() -> void:
	var base: Dictionary = Classes.CLASSES[cls]
	var b := {"atk_flat": 0.0, "atk_pct": 0.0, "hp_flat": 0.0, "hp_pct": 0.0,
		"mp_flat": 0.0, "speed_pct": 0.0, "crit": 0.0, "crit_dmg": 0.0,
		"cdr": 0.0, "lifesteal": 0.0, "dr": 0.0, "gold_pct": 0.0, "dodge": 0.0}

	# Class passive (Warrior's plating, Archer's crit, Assassin's dodge...).
	var passive: Dictionary = base.get("passive", {})
	for stat in passive:
		if stat != "text":
			b[stat] = b.get(stat, 0.0) + passive[stat]

	for slot in equipment:
		var stats := Items.stats_of(equipment[slot])
		for stat in stats:
			b[stat] = b.get(stat, 0.0) + stats[stat]
	for id in learned:
		var node := Skills.get_node_data(cls, id)
		if node.is_empty():
			continue  # node belongs to a different class
		for stat in node.get("bonus", {}):
			b[stat] = b.get(stat, 0.0) + node["bonus"][stat]
		if evolution != "":
			var evo_b: Dictionary = node.get("evo_bonus", {}).get(evolution, {})
			for stat in evo_b:
				b[stat] = b.get(stat, 0.0) + evo_b[stat]
	if evolution != "":
		for stat in base["evolutions"][evolution]["bonus"]:
			b[stat] = b.get(stat, 0.0) + base["evolutions"][evolution]["bonus"][stat]

	var hp_frac := hp / max_hp if max_hp > 0 else 1.0
	var mp_frac := mp / max_mp if max_mp > 0 else 1.0
	max_hp = (base["hp"] + base["hp_lvl"] * (level - 1) + b["hp_flat"]) * (1.0 + b["hp_pct"])
	max_mp = base["mp"] + base["mp_lvl"] * (level - 1) + b["mp_flat"]
	atk = (base["atk"] + base["atk_lvl"] * (level - 1) + b["atk_flat"]) * (1.0 + b["atk_pct"])
	speed = base["speed"] * (1.0 + b["speed_pct"])
	crit = clampf(0.05 + b["crit"], 0.0, 0.9)
	crit_dmg = 1.5 + b["crit_dmg"]
	cdr = clampf(b["cdr"], 0.0, 0.45)
	lifesteal = b["lifesteal"]
	dr = clampf(b["dr"], 0.0, 0.65)
	dodge = clampf(b["dodge"], 0.0, 0.5)
	gold_pct = b["gold_pct"]
	hp = clampf(max_hp * hp_frac, 1.0, max_hp)
	mp = clampf(max_mp * mp_frac, 0.0, max_mp)


## Current attack including temporary buffs (Berserk).
func current_atk() -> float:
	if berserk_time > 0.0:
		return atk * (1.65 if evolution == "warlord" else 1.4)
	return atk


func current_lifesteal() -> float:
	return lifesteal + (0.15 if berserk_time > 0.0 else 0.0)


# ==================================================================== gear

func add_item(item: Dictionary) -> bool:
	if backpack.size() >= BACKPACK_MAX:
		gold += maxi(1, Items.price(item) / 2)
		game.spawn_text(global_position + Vector2(0, -50), "Bag full! Sold for gold", Color(1, 0.9, 0.4))
		return false
	backpack.append(item)
	return true


func equip(item: Dictionary) -> void:
	backpack.erase(item)
	var slot: String = item["slot"]
	if equipment.has(slot):
		backpack.append(equipment[slot])
	equipment[slot] = item
	recalc()
	game.sfx("potion")


# =============================================================== progression

func gain_xp(amount: int) -> void:
	xp += amount
	game.spawn_text(global_position + Vector2(0, -56), "+%d XP" % amount, Color(1.0, 0.9, 0.4))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		recalc()
		hp = max_hp
		mp = max_mp
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -72), "LEVEL UP!  Lv %d  (+1 skill point, press T)" % level, Color(0.5, 0.9, 1.0))
		if level >= Classes.EVOLVE_LEVEL and evolution == "":
			# The menu opens from game._process once no dialogue is up.
			pending_evolution = true


## Has this skill node been learned? (behavior nodes are checked by id)
func has_mod(id: String) -> bool:
	return learned.has(id)


## Sum of all ability modifiers ("dmg" / "cd" / "mp") for one ability slot,
## from learned skill nodes and evolution-specific capstone effects.
func _amod(slot: String, field: String) -> float:
	var total := 0.0
	for id in learned:
		var node := Skills.get_node_data(cls, id)
		if node.is_empty():
			continue
		total += node.get("amod", {}).get(slot, {}).get(field, 0.0)
		if evolution != "":
			total += node.get("evo_amod", {}).get(evolution, {}).get(slot, {}).get(field, 0.0)
	return total


## Damage factor for one ability slot (1.0 = unmodified).
func dm(slot: String) -> float:
	return 1.0 + _amod(slot, "dmg")


## Final cooldown of an ability, after skill nodes, evolution and haste.
func ability_cd(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	var cd: float = ab["cd"] * (1.0 + _amod(slot, "cd"))
	if cls == "archer" and slot == "a1" and evolution == "ranger":
		cd *= 0.75
	if cls == "assassin" and slot == "a2" and evolution == "shadow":
		cd = minf(cd, 3.0)
	return maxf(0.1, cd * (1.0 - cdr))


func ability_cost(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	return maxf(0.0, ab["mp"] * (1.0 + _amod(slot, "mp")))


func learn_skill(id: String) -> bool:
	if skill_points <= 0 or not Skills.can_learn(cls, id, learned):
		return false
	skill_points -= 1
	learned[id] = true
	recalc()
	game.sfx("levelup")
	return true


func evolve(id: String) -> void:
	evolution = id
	recalc()
	hp = max_hp
	mp = max_mp
	game.sfx("victory")
	game.spawn_text(global_position + Vector2(0, -80), "EVOLVED: %s!" % Classes.CLASSES[cls]["evolutions"][id]["name"], Color(1, 0.85, 0.3))
	# Evolved heroes get a subtle aura tint.
	sprite.self_modulate = Color(1.15, 1.05, 1.15)


func gain_gold(amount: int) -> void:
	gold += int(amount * (1.0 + gold_pct))


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	for key in cds:
		cds[key] = maxf(0.0, cds[key] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	tumble_speed_time = maxf(0.0, tumble_speed_time - delta)
	phase_time = maxf(0.0, phase_time - delta)
	mp = minf(max_mp, mp + (6.0 if cls == "mage" else 4.0) * delta)
	anim_t += delta

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
	if tumble_speed_time > 0.0:
		spd *= 1.2
	velocity = dir * spd
	move_and_slide()

	# Walk bob + face the aim target (or move direction).
	var target := auto_aim()
	var look_x := target.global_position.x - global_position.x if target else facing.x
	if absf(look_x) > 2.0:
		sprite.flip_h = look_x < 0.0
	if dir != Vector2.ZERO:
		sprite.position.y = -absf(sin(anim_t * 11.0)) * 3.0
		sprite.rotation = sin(anim_t * 11.0) * 0.06
	else:
		sprite.position.y = 0.0
		sprite.rotation = 0.0

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


# ================================================================ targeting

## Nearest living enemy within range. This is the whole auto-aim system.
func auto_aim(rng := 520.0) -> Enemy:
	var best: Enemy = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func aim_dir(rng := 520.0) -> Vector2:
	var target := auto_aim(rng)
	if target:
		return (target.global_position - global_position).normalized()
	return facing


# ================================================================= abilities

func use_ability(slot: String) -> void:
	if dead or cds[slot] > 0.0:
		return
	var cost := ability_cost(slot)
	if mp < cost:
		return
	cds[slot] = ability_cd(slot)
	mp -= cost
	var f := dm(slot)  # damage factor from skill tree

	match [cls, slot]:
		["warrior", "a1"]:
			var reach := 96.0 * (1.4 if has_mod("wA1") else 1.0)
			var knock := 330.0 * (1.5 if has_mod("wA1") else 1.0)
			_melee_arc(1.0 * f, reach, "slash", {"stagger": 0.35, "knock": knock})
		["warrior", "a2"]: _shield_bash(f)
		["warrior", "a3"]: _whirlwind(f)
		["warrior", "ult"]:
			berserk_time = 12.0 if (has_mod("wC3") and evolution == "warlord") else 8.0
			game.sfx("roar")
			game.spawn_text(global_position + Vector2(0, -60), "BERSERK!", Color(1, 0.4, 0.3))
		["archer", "a1"]:
			_shoot(aim_dir(), 1.0 * f)
			if has_mod("aA1"):  # Split Shot
				_shoot(aim_dir().rotated(0.09), 0.5 * f)
		["archer", "a2"]: _multishot(f)
		["archer", "a3"]: _tumble()
		["archer", "ult"]:
			storm_time = 3.0
			game.sfx("roar")
			game.spawn_text(global_position + Vector2(0, -60), "ARROW STORM!", Color(0.6, 1, 0.6))
		["mage", "a1"]: _cast_bolt(aim_dir(), 1.1 * f)
		["mage", "a2"]: _frost_nova(f)
		["mage", "a3"]: _blink()
		["mage", "ult"]: _meteor()
		["assassin", "a1"]:
			_melee_arc(0.8 * f, 84.0, "slash", {"stagger": 0.3, "knock": 260.0})
			if has_mod("sA1"):  # Twin Blades
				_melee_arc(0.4 * f, 84.0, "slash", {"knock": 160.0})
		["assassin", "a2"]: _shadowstep(f)
		["assassin", "a3"]: _fan_of_knives(f)
		["assassin", "ult"]: _death_mark()


## Deal damage to one enemy, applying crit / lifesteal / pyromancer burn.
func hit_enemy(e: Enemy, mult: float, effects := {}) -> void:
	var dmg := current_atk() * mult
	var is_crit := randf() < crit
	if is_crit:
		dmg *= crit_dmg
	if evolution == "pyromancer":
		# Conflagration capstone makes every burn 50% stronger.
		e.apply_burn(current_atk() * (0.45 if has_mod("mA3") else 0.3), 3.0)
	if effects.has("burn"):
		e.apply_burn(effects["burn"], 3.0)
	if effects.has("stun"):
		e.apply_stun(effects["stun"])
	if effects.has("stagger"):
		e.apply_stun(effects["stagger"])
	if effects.has("slow"):
		e.apply_slow(effects["slow"], effects.get("slow_dur", 2.5))
	if current_lifesteal() > 0.0:
		hp = minf(max_hp, hp + dmg * current_lifesteal())
	var dir := (e.global_position - global_position).normalized()
	e.take_damage(dmg, dir, is_crit)
	if effects.has("knock") and not e.dying:
		e.knock = dir * effects["knock"]
	if effects.has("pull") and not e.dying:
		e.knock = -dir * 380.0  # Cyclone: drag them into the blender
	if effects.has("splash"):  # Fireburst: explosion around the target
		game.burst(e.global_position, Color(1.0, 0.6, 0.2), 8)
		for e2 in _enemies_within(e.global_position, 80.0):
			if e2 != e and not e2.dying:
				e2.take_damage(dmg * effects["splash"], (e2.global_position - e.global_position).normalized())


## Enemies inside an arc/circle in front of us (no physics queries needed).
func _enemies_within(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and center.distance_to(e.global_position) <= radius:
			out.append(e)
	return out


func _melee_arc(mult: float, reach: float, fx: String, effects := {}) -> void:
	game.sfx("slash")
	var dir := aim_dir(220.0)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(fx)
	spr.rotation = dir.angle()
	spr.scale = Vector2(2.8, 2.8) * (reach / 78.0)
	spr.position = dir * reach * 0.5
	spr.z_index = 6
	add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "modulate:a", 0.0, 0.14)
	tween.tween_callback(spr.queue_free)
	for e in _enemies_within(global_position + dir * reach * 0.55, reach * 0.55):
		hit_enemy(e, mult, effects)


func _shoot(dir: Vector2, mult: float, fx := {}) -> void:
	game.sfx("bolt")
	var p := Projectile.spawn(game, global_position + dir * 24.0, dir * 520.0, 0.0, true, "arrow")
	p.hit_player_mult = mult
	p.source_player = self
	p.fx = fx
	p.pierce = (evolution == "sniper")


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")
	var p := Projectile.spawn(game, global_position + dir * 24.0, dir * 440.0, 0.0, true, "fireball")
	p.hit_player_mult = mult
	p.source_player = self
	if has_mod("mA1"):  # Fireburst
		p.fx = {"splash": 0.5}


func _shield_bash(f := 1.0) -> void:
	game.sfx("slam")
	var dir := aim_dir(220.0)
	global_position += dir * 60.0
	var stun := 2.0 if evolution == "guardian" else 1.2
	var hit_list := _enemies_within(global_position + dir * 40.0, 52.0)
	for e in hit_list:
		hit_enemy(e, 1.2 * f, {"stun": stun})
	if has_mod("wB1"):  # Aftershock
		game.shake(4.0)
		for e2 in _enemies_within(global_position + dir * 40.0, 150.0):
			if not hit_list.has(e2):
				hit_enemy(e2, 0.7 * f)


func _whirlwind(f := 1.0) -> void:
	game.sfx("slash")
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Color(1, 1, 1, 0.8)
	spr.scale = Vector2(4.5, 4.5)
	add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "scale", Vector2(6, 6), 0.2)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, 0.2)
	tween.tween_callback(spr.queue_free)
	var eff := {"pull": true, "stagger": 0.3} if has_mod("wC1") else {"knock": 380.0, "stagger": 0.3}
	for e in _enemies_within(global_position, 115.0):
		hit_enemy(e, 0.9 * f, eff)


func _multishot(f := 1.0) -> void:
	game.sfx("bolt")
	var dir := aim_dir()
	var count := 5
	if evolution == "ranger":
		count += 2
	if has_mod("aB3"):  # Rain of Barbs
		count += 2 if evolution == "ranger" else 1
	var fx := {"slow": 0.65, "slow_dur": 2.0} if has_mod("aB1") else {}
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * 0.16
		_shoot(dir.rotated(spread), 0.7 * f, fx)


func _tumble() -> void:
	game.sfx("blink")
	hurt_cd = maxf(hurt_cd, 0.5)
	global_position = game.clamp_to_zone(global_position + facing * 130.0, global_position)
	if has_mod("aC1"):  # Quiver Roll: reset Multishot
		cds["a2"] = 0.0
	if has_mod("aC2"):  # Adrenaline
		tumble_speed_time = 3.0
	if has_mod("aC3") and evolution == "ranger":  # Windrunner
		_multishot(dm("a2"))


func _storm_strike() -> void:
	var targets := _enemies_within(global_position, 560.0)
	if targets.is_empty():
		return
	var e: Enemy = targets[randi() % targets.size()]
	game.sfx("bolt")
	game.burst(e.global_position, Color(0.7, 1.0, 0.7))
	hit_enemy(e, 0.8)


func _frost_nova(f := 1.0) -> void:
	game.sfx("blink")
	var radius := 125.0 * (1.4 if has_mod("mB2") else 1.0)
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Color(0.4, 0.7, 1.0, 0.9)
	spr.scale = Vector2(3, 3)
	add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "scale", Vector2(radius / 19.0, radius / 19.0), 0.25)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, 0.3)
	tween.tween_callback(spr.queue_free)
	var dur_mult := 2.0 if (has_mod("mB3") and evolution == "pyromancer") else 1.0
	var eff := {}
	if has_mod("mB1"):  # Deep Freeze: root instead of slow
		eff = {"stun": 1.2 * dur_mult}
	else:
		eff = {"slow": 0.5, "slow_dur": 2.5 * dur_mult}
	var hits := 0
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 0.8 * f, eff)
		hits += 1
	if has_mod("mB3") and evolution == "archmage":  # Absolute Zero refund
		mp = minf(max_mp, mp + 8.0 * hits)


func _blink_shock() -> void:
	game.burst(global_position, Color(0.6, 0.7, 1.0), 12)
	for e in _enemies_within(global_position, 85.0):
		hit_enemy(e, 0.8 * dm("a3"))


func _blink() -> void:
	game.sfx("blink")
	if has_mod("mC1"):  # Static Step: shock at departure...
		_blink_shock()
	else:
		game.burst(global_position, Color(0.6, 0.7, 1.0))
	var dist := 180.0 * (1.6 if has_mod("mC2") else 1.0)
	global_position = game.clamp_to_zone(global_position + facing * dist, global_position)
	if has_mod("mC1"):  # ...and arrival
		_blink_shock()
	if has_mod("mC3"):  # Phase Shift
		phase_time = 1.0


func _meteor() -> void:
	var target := auto_aim()
	var pos := target.global_position if target else global_position + facing * 150.0
	game.sfx("roar")
	# Falling meteor sprite, then boom.
	var spr := Sprite2D.new()
	spr.texture = Art.tex("fireball")
	spr.scale = Vector2(8, 8)
	spr.global_position = pos + Vector2(60, -320)
	spr.z_index = 30
	game.add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "global_position", pos, 0.55)
	tween.tween_callback(func() -> void:
		spr.queue_free()
		game.sfx("slam")
		game.shake(9.0)
		game.burst(pos, Color(1.0, 0.6, 0.2), 24)
		for e in _enemies_within(pos, 140.0):
			hit_enemy(e, 3.5, {"burn": current_atk() * 0.4})
	)


func _shadowstep(f := 1.0) -> void:
	var target := auto_aim()
	if target == null:
		cds["a2"] = 0.5  # refund most of the cooldown if there was no target
		return
	game.sfx("blink")
	game.burst(global_position, Color(0.5, 0.4, 0.7))
	var behind := (global_position - target.global_position).normalized() * -46.0
	global_position = target.global_position + behind
	var mult := 1.5 * f
	if has_mod("sB3") and target.hp < target.max_hp * 0.35:  # Executioner
		mult *= 1.6
	var eff := {"stun": 1.0} if has_mod("sB1") else {"stagger": 0.5}
	hit_enemy(target, mult, eff)


func _fan_of_knives(f := 1.0) -> void:
	game.sfx("slash")
	var dir := aim_dir()
	var count := 5 if has_mod("sC3") else 3
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * 0.13
		var p := Projectile.spawn(game, global_position + dir * 22.0, dir.rotated(spread) * 560.0, 0.0, true, "knife")
		p.hit_player_mult = 0.7 * f
		p.source_player = self
		p.pierce = has_mod("sC1")


func _death_mark() -> void:
	var target := auto_aim()
	if target == null:
		cds["ult"] = 1.0
		return
	game.sfx("roar")
	game.burst(target.global_position, Color(1.0, 0.2, 0.3), 20)
	target.vuln_time = 5.0
	hit_enemy(target, 2.0)
	game.spawn_text(target.global_position + Vector2(0, -50), "MARKED", Color(1, 0.3, 0.3))


# ================================================================== survival

func drink_potion() -> void:
	if potion_cd > 0.0 or potions <= 0 or hp >= max_hp or dead:
		return
	potion_cd = 0.6
	potions -= 1
	hp = minf(max_hp, hp + max_hp * 0.6)
	game.sfx("potion")
	game.spawn_text(global_position + Vector2(0, -40), "+HP", Color(0.4, 1.0, 0.4))


func take_damage(amount: float) -> void:
	if dead or hurt_cd > 0.0:
		return
	var eff_dodge := minf(0.9, dodge + (0.5 if phase_time > 0.0 else 0.0))
	if eff_dodge > 0.0 and randf() < eff_dodge:
		game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
		game.sfx("blink")
		return
	hurt_cd = 0.6
	amount *= (1.0 - dr)
	hp -= amount
	game.sfx("hurt")
	game.shake(4.0)
	game.spawn_text(global_position + Vector2(0, -40), "-%d" % int(amount), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		game.on_player_died()


func revive() -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
