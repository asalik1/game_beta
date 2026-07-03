class_name Chest extends Area2D
## A loot chest lying in the world. Walk over it to open:
## you get one piece of gear (grade depends on the chest tier) plus some gold.

var tier := "wood"
var opened := false
var game: Node2D


static func drop(game_node: Node2D, chest_tier: String, pos: Vector2) -> Chest:
	var c := Chest.new()
	c.game = game_node
	c.tier = chest_tier
	c.global_position = pos

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2.2, 1.6)
	shadow.position = Vector2(0, 16)
	c.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(Items.CHEST_TIERS[chest_tier]["sprite"])
	sprite.scale = Vector2(3, 3)
	c.add_child(sprite)

	c.collision_layer = 0
	c.collision_mask = 2  # player
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26
	cs.shape = shape
	c.add_child(cs)
	c.body_entered.connect(c._on_body_entered)
	game_node.add_child(c)

	# Little "pop" when it lands.
	sprite.scale = Vector2(0.5, 0.5)
	var tween := c.create_tween()
	tween.tween_property(sprite, "scale", Vector2(3.4, 3.4), 0.15)
	tween.tween_property(sprite, "scale", Vector2(3, 3), 0.1)
	return c


func _on_body_entered(body: Node) -> void:
	if opened or not body is Player:
		return
	opened = true
	game.sfx("potion")
	game.burst(global_position, Color(1.0, 0.85, 0.3), 14)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item := Items.roll_item(tier, rng, body.cls)
	body.add_item(item)
	var bonus_gold := rng.randi_range(3, 8) * (1 + ["wood", "silver", "gold"].find(tier))
	body.gain_gold(bonus_gold)
	game.hud.loot_banner(item, bonus_gold)

	# Chests can also hold loose gems (better chests, better odds).
	var gem_chance: float = {"wood": 0.25, "silver": 0.6, "gold": 1.0}[tier]
	if rng.randf() < gem_chance:
		var gem := Items.random_gem(rng, 1)
		body.gem_bag.append(gem)
		game.spawn_text(body.global_position + Vector2(0, -66), "+ " + Items.gem_title(gem), Items.gem_color(gem))

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
