class_name Projectile extends Area2D
## A flying arrow / fireball / knife / shadow bolt.
## Friendly shots route their damage through the owning Player
## (so crit, lifesteal and burns apply); hostile shots hurt the player.

var vel := Vector2.ZERO
var dmg := 10.0                # used by hostile (enemy) projectiles
var friendly := true
var life := 2.5
var pierce := false            # sniper arrows fly through enemies
var hit_player_mult := 0.0     # friendly: damage = player atk * this
var source_player: Player = null
var fx := {}                   # extra effects passed to hit_enemy (slow, splash...)
var game: Node2D
var glow_color := Color(1, 1, 1)
var _already_hit := {}

# Glow tint per projectile type — bright and readable at a glance.
const GLOWS := {
	"fireball": Color(1.0, 0.55, 0.15), "bolt": Color(1.0, 0.35, 0.85),
	"arrow": Color(0.9, 1.0, 0.6), "knife": Color(0.8, 0.85, 1.0),
	"slash": Color(1.0, 0.9, 0.5),
}


static func spawn(game_node: Node2D, pos: Vector2, velocity: Vector2, damage: float, is_friendly: bool, tex_name: String) -> Projectile:
	var p := Projectile.new()
	p.game = game_node
	p.vel = velocity
	p.dmg = damage
	p.friendly = is_friendly
	p.global_position = pos
	p.z_index = 5
	p.add_to_group("projectiles")
	p.glow_color = GLOWS.get(tex_name, Color(1, 1, 1))

	# Soft glow behind the bullet so it pops against any background.
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	glow.modulate = Color(p.glow_color, 0.6)
	glow.scale = Vector2(1.0, 1.0)
	p.add_child(glow)

	# Fire magic leaves a trail of sparks as it flies.
	if tex_name == "fireball":
		var sparks := CPUParticles2D.new()
		sparks.amount = 12
		sparks.lifetime = 0.35
		sparks.spread = 180.0
		sparks.initial_velocity_min = 15.0
		sparks.initial_velocity_max = 45.0
		sparks.gravity = Vector2.ZERO
		sparks.scale_amount_min = 1.2
		sparks.scale_amount_max = 2.6
		sparks.color = Color(1.0, 0.8, 0.3)
		p.add_child(sparks)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(tex_name)
	sprite.scale = Vector2(3, 3)
	sprite.rotation = velocity.angle()
	p.add_child(sprite)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9
	cs.shape = shape
	p.add_child(cs)

	p.collision_layer = 0
	# Layer bits: 1 = walls, 2 = player, 4 = enemies.
	p.collision_mask = (1 | 4) if is_friendly else (1 | 2)
	game_node.add_child(p)
	return p


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if friendly and body is Enemy:
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		game.burst(global_position, glow_color, 5)
		if is_instance_valid(source_player):
			source_player.hit_enemy(body, hit_player_mult, fx)
			# Stormcaller passive: the arrow leaps to a second enemy.
			if fx.get("ric", 0) > 0:
				_ricochet(body)
		else:
			body.take_damage(dmg, vel.normalized())
		if not pierce:
			queue_free()
	elif not friendly and body is Player:
		game.burst(global_position, glow_color, 5)
		body.take_damage(dmg, "magic")
		queue_free()
	elif body is StaticBody2D:
		game.burst(global_position, Color(glow_color, 0.5), 3)
		queue_free()


func _ricochet(hit: Node) -> void:
	var best: Enemy = null
	var best_d := 260.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == hit or e.dying:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var dir := (best.global_position - global_position).normalized()
	var p := Projectile.spawn(game, global_position + dir * 10.0, dir * 520.0, 0.0, true, "arrow")
	p.source_player = source_player
	p.hit_player_mult = hit_player_mult * 0.6
	p.fx = {"ric": fx.get("ric", 1) - 1}
