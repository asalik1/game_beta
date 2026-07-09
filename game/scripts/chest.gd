class_name Chest extends Area2D
## A loot chest lying in the world. Walk over it to open:
## you get one piece of gear (grade depends on the chest tier) plus some gold.

var tier := "wood"
var opened := false
var buried := false        # buried: invisible until the player comes near
var game: Game
var on_open := Callable()  # optional hook (dead-end caches set a flag)


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
	# DEFERRED: opening can spawn new Area2Ds (bag-full Pickup drops, cache
	# hooks) — doing that inside the physics flush is a Godot error
	# (area_set_shape_disabled: "Can't change this state while flushing queries").
	c.body_entered.connect(c._on_body_entered, CONNECT_DEFERRED)
	game_node.add_child(c)

	# Little "pop" when it lands.
	sprite.scale = Vector2(0.5, 0.5)
	var tween := c.create_tween()
	tween.tween_property(sprite, "scale", Vector2(3.4, 3.4), 0.15)
	tween.tween_property(sprite, "scale", Vector2(3, 3), 0.1)
	return c


## Bury the chest (hidden caches, exploration premium): invisible until
## the player wanders close, then it glints awake — the reward for
## walking the dead end nobody made you walk.
func bury() -> void:
	buried = true
	visible = false
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not buried:
		set_physics_process(false)
		return
	var p: Player = game.player
	if p != null and not p.dead \
			and global_position.distance_to(p.global_position) < 150.0:
		buried = false
		visible = true
		set_physics_process(false)
		game.sfx("ward", 0.85, 0.0, -6.0)
		game.burst(global_position, Color(1.0, 0.95, 0.6), 12)
		game.spawn_text(global_position + Vector2(0, -46), "Something glints...",
			Color(1.0, 0.95, 0.7))


func _on_body_entered(body: Node) -> void:
	if opened or buried or not body is Player:
		return
	opened = true
	game.sfx("chest")
	game.burst(global_position, Color(1.0, 0.85, 0.3), 14)
	if on_open.is_valid():
		on_open.call()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item := Items.roll_item(tier, rng, body.cls, game.loot_cap())
	game.give_loot({"kind": "item", "item": item}, global_position)
	game.loot_fanfare(item["grade"], global_position)  # rarity chime + beam
	var bonus_gold := rng.randi_range(3, 8) * (1 + ["wood", "silver", "gold"].find(tier))
	body.gain_gold(bonus_gold)
	game.hud.loot_banner(item, bonus_gold)

	# Chests can also hold loose gems (better chests, better odds).
	var gem_chance: float = {"wood": 0.25, "silver": 0.6, "gold": 1.0}[tier]
	if rng.randf() < gem_chance:
		var gem := Items.random_gem(rng, 1, Balance.special_gems_drop(game.chapter_id))
		if game.give_loot({"kind": "gem", "gem": gem}, global_position):
			game.spawn_text(body.global_position + Vector2(0, -66), "+ " + Items.gem_title(gem), Items.gem_color(gem))

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
