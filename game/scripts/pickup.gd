class_name Pickup extends Area2D
## A gold coin on the ground. Magnets toward the player when close.

var value := 3
var game: Game
var magnet := false


static func drop_gold(game_node: Node2D, amount: int, pos: Vector2) -> void:
	# Scatter a few coins around the death spot.
	var coins := clampi(amount / 3, 1, 5)
	for i in coins:
		var c := Pickup.new()
		c.game = game_node
		c.value = maxi(1, amount / coins)
		c.global_position = pos + Vector2(randf_range(-24, 24), randf_range(-18, 18))
		var sprite := Sprite2D.new()
		sprite.texture = Art.tex("coin")
		sprite.scale = Vector2(2.5, 2.5)
		c.add_child(sprite)
		c.collision_layer = 0
		c.collision_mask = 2
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 14
		cs.shape = shape
		c.add_child(cs)
		c.body_entered.connect(c._on_body_entered)
		c.z_index = 4
		game_node.add_child(c)
		# Coin hop.
		var tween := c.create_tween()
		tween.tween_property(sprite, "position:y", -8.0, 0.12)
		tween.tween_property(sprite, "position:y", 0.0, 0.15)


func _physics_process(delta: float) -> void:
	var p: Player = game.player
	if p == null or p.dead:
		return
	var d := global_position.distance_to(p.global_position)
	if d < 110.0:
		magnet = true
	if magnet:
		global_position = global_position.move_toward(p.global_position, (300.0 + (110.0 - minf(d, 110.0)) * 4.0) * delta)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.gain_gold(value)
		game.sfx("coin")
		queue_free()
