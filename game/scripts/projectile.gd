class_name Projectile extends Area2D
## A flying arrow / fireball / knife / shadow bolt.
## Friendly shots route their damage through the owning Player
## (so crit, lifesteal and burns apply); hostile shots hurt the player.

var vel := Vector2.ZERO
var dmg := 10.0                # used by hostile (enemy) projectiles
var hostile_type := "magic"    # hostile: damage type (set from the shooter)
var source_enemy: Node = null  # hostile: shooter, for crit/pen/dex resolution
var friendly := true
var life := 2.5
var pierce := false            # sniper arrows fly through enemies
var hit_player_mult := 0.0     # friendly: damage = player atk * this
var source_player: Player = null
var fx := {}                   # extra effects passed to hit_enemy (slow, splash...)
var game: Game
var glow_color := Color(1, 1, 1)
var tex_kind := ""
var spr: Sprite2D = null       # thrown knives spin in flight
var _already_hit := {}

# Glow tint per projectile type — bright and readable at a glance.
const GLOWS := {
	"fireball": Color(1.0, 0.55, 0.15), "bolt": Color(1.0, 0.35, 0.85),
	"arrow": Color(0.9, 1.0, 0.6), "knife": Color(0.8, 0.85, 1.0),
	"slash": Color(1.0, 0.9, 0.5), "icelance": Color(0.5, 0.9, 1.0),
	"shadowbolt": Color(0.7, 0.4, 1.0),
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
	p.tex_kind = tex_name
	p.glow_color = GLOWS.get(tex_name, Color(1, 1, 1))

	# Soft glow behind the bullet so it pops against any background.
	# Magic bolts burn hotter.
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	var hot := tex_name in ["fireball", "icelance", "shadowbolt"]
	glow.modulate = Color(p.glow_color, 0.8 if hot else 0.6)
	glow.scale = Vector2(1.35, 1.35) if hot else Vector2(1.0, 1.0)
	p.add_child(glow)

	# Fire magic trails sparks; ice trails frost; shadow trails void wisps.
	if hot:
		var sparks := CPUParticles2D.new()
		sparks.amount = 16
		sparks.lifetime = 0.4
		sparks.spread = 180.0
		sparks.initial_velocity_min = 15.0
		sparks.initial_velocity_max = 55.0
		sparks.gravity = Vector2.ZERO
		sparks.scale_amount_min = 1.2
		sparks.scale_amount_max = 2.8
		sparks.color = {
			"fireball": Color(1.0, 0.8, 0.3),
			"icelance": Color(0.75, 0.95, 1.0),
			"shadowbolt": Color(0.6, 0.3, 0.9),
		}[tex_name]
		p.add_child(sparks)

	# Arrows and knives streak: a thin motion trail behind the tip.
	if tex_name == "arrow" or tex_name == "knife":
		var trail := Sprite2D.new()
		trail.texture = Art.tex("glow")
		trail.modulate = Color(p.glow_color, 0.4)
		trail.rotation = velocity.angle()
		trail.position = -velocity.normalized() * 13.0
		trail.scale = Vector2(1.6, 0.2)
		p.add_child(trail)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(tex_name)
	sprite.scale = Vector2(3, 3)
	sprite.rotation = velocity.angle()
	p.add_child(sprite)
	p.spr = sprite

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
	if tex_kind == "knife" and spr:
		spr.rotation += 16.0 * delta  # thrown blades tumble end over end
	life -= delta
	if life <= 0.0:
		_bloom()
		queue_free()


## Venom Bloom: the projectile detonates into an expanding poison mist
## on its first hit or at the end of its flight.
func _bloom() -> void:
	if fx.get("bloom_mist", 0) and is_instance_valid(source_player):
		fx["bloom_mist"] = 0
		source_player._mist(global_position, 120.0, 0.4,
			fx.get("bloom_color", Color(0.45, 0.95, 0.3)), 3.0)


## A quick expanding shockwave where a magic bolt lands.
func _impact_ring() -> void:
	if not tex_kind in ["fireball", "icelance", "shadowbolt"]:
		return
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(glow_color, 0.9)
	ring.global_position = global_position
	ring.scale = Vector2(0.4, 0.4)
	ring.z_index = 8
	game.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale", Vector2(1.7, 1.7), 0.18)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.2)
	rt.tween_callback(ring.queue_free)


func _on_body_entered(body: Node) -> void:
	if friendly and body is Enemy:
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		game.burst(global_position, glow_color, 5)
		_impact_ring()
		if is_instance_valid(source_player):
			source_player.hit_enemy(body, hit_player_mult, fx)
			# Stormcaller passive: the arrow leaps to a second enemy.
			if fx.get("ric", 0) > 0:
				_ricochet(body)
		else:
			body.take_damage(dmg, vel.normalized())
		if not pierce:
			_bloom()
			queue_free()
	elif not friendly and body is Player:
		game.burst(global_position, glow_color, 5)
		var shooter: Node = source_enemy if is_instance_valid(source_enemy) else null
		body.take_damage(dmg, hostile_type, shooter)
		queue_free()
	elif body is StaticBody2D:
		game.burst(global_position, Color(glow_color, 0.5), 3)
		if friendly:
			_impact_ring()
			_bloom()
		queue_free()


func _ricochet(hit: Node) -> void:
	var best: Enemy = null
	var best_d := 260.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == hit or e.dying or e.untargetable:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var dir := (best.global_position - global_position).normalized()
	# The leap keeps the parent's look: arrows ricochet as arrows,
	# shadowbolts (Hollow Choir) split as shadowbolts.
	var p := Projectile.spawn(game, global_position + dir * 10.0, dir * 520.0, 0.0, true, tex_kind)
	p.modulate = modulate
	p.source_player = source_player
	p.hit_player_mult = hit_player_mult * 0.6
	p.fx = {"ric": fx.get("ric", 1) - 1}
