class_name Pickup extends Area2D
## Things lying on the ground. Two flavors:
##  - gold coins (magnet toward the player, instant)
##  - LOOT (bag-overflow drops: gear/gem/stone payloads). No magnet;
##    standing on one retries the claim, so a full bag leaves it put.
##    Unclaimed drops flush into the MAILBOX at chapter end
##    (game.flush_dropped_loot) — nothing is ever silently lost.

var value := 3
var game: Game
var magnet := false
var loot := {}        # empty = a gold coin; else a dropped-loot payload
var retry_cd := 0.0   # full-bag claim retry throttle


static func drop_gold(game_node: Node2D, amount: int, pos: Vector2) -> void:
	# Scatter a few coins around the death spot.
	amount = (game_node as Game).gold_scaled(amount)  # weekly "gilded" hook
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
		c._body_setup()
		game_node.add_child(c)
		# Coin hop.
		var tween := c.create_tween()
		tween.tween_property(sprite, "position:y", -8.0, 0.12)
		tween.tween_property(sprite, "position:y", 0.0, 0.15)


## A loot payload ({"kind": "item"/"gem"/"stone", ...}) dropped where a
## full bag rejected it. The registry entry (game.dropped_loot) is the
## caller's job; this only builds the world node.
static func drop_loot(game_node: Node2D, payload: Dictionary, pos: Vector2) -> Pickup:
	var c := Pickup.new()
	c.game = game_node
	c.loot = payload
	c.add_to_group("loot_pickups")
	c.global_position = pos + Vector2(randf_range(-22, 22), randf_range(-16, 16))
	match str(payload.get("kind", "")):
		"item":
			var spr := Sprite2D.new()
			spr.texture = Art.icon_for(payload["item"])
			spr.scale = Vector2(1.6, 1.6)
			c.add_child(spr)
		"gem":
			c._glyph("◆", Items.gem_color(payload["gem"]))
		_:
			c._glyph("⟲", Color(0.6, 0.9, 1.0))
	c._body_setup()
	game_node.add_child(c)
	return c


func _glyph(ch: String, color: Color) -> void:
	var l := Label.new()
	l.text = ch
	l.position = Vector2(-9, -15)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)


func _body_setup() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	z_index = 4


func _physics_process(delta: float) -> void:
	var p: Player = game.player
	if p == null or p.dead:
		return
	retry_cd = maxf(0.0, retry_cd - delta)
	var d := global_position.distance_to(p.global_position)
	if loot.is_empty():
		# Coin: magnet toward the player.
		if d < 110.0:
			magnet = true
		if magnet:
			global_position = global_position.move_toward(p.global_position,
				(300.0 + (110.0 - minf(d, 110.0)) * 4.0) * delta)
	elif d < 30.0 and retry_cd <= 0.0:
		# Loot: keep retrying while stood on — the player may have just
		# made bag room (body_entered alone fires only on ENTER).
		_try_claim(p)


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	if loot.is_empty():
		body.gain_gold(value)
		game.sfx("coin")
		queue_free()
	elif retry_cd <= 0.0:
		_try_claim(body)


func _try_claim(p: Player) -> void:
	if game._try_receive(loot):
		game.dropped_loot.erase(loot)
		game.sfx("potion")
		queue_free()
	else:
		retry_cd = 1.2