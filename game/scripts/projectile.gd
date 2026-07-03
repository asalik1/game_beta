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
var _already_hit := {}


static func spawn(game: Node2D, pos: Vector2, velocity: Vector2, damage: float, is_friendly: bool, tex_name: String) -> Projectile:
	var p := Projectile.new()
	p.vel = velocity
	p.dmg = damage
	p.friendly = is_friendly
	p.global_position = pos
	p.z_index = 5
	p.add_to_group("projectiles")

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
	game.add_child(p)
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
		if is_instance_valid(source_player):
			source_player.hit_enemy(body, hit_player_mult, fx)
		else:
			body.take_damage(dmg, vel.normalized())
		if not pierce:
			queue_free()
	elif not friendly and body is Player:
		body.take_damage(dmg)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
