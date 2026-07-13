class_name Chest extends Area2D
## A loot chest lying in the world. Walk over it to open: you get one piece
## of gear plus some gold.
##
## GRADE-TELEGRAPHED (2026-07-10): the gear grade is rolled when the chest
## DROPS, not when it opens, and the chest wears that grade's art
## (assets/sprites/chest_<f..s>.png) — so spotting a B-chest across a ch7
## room is a loot moment before you ever touch it. The roll itself is
## unchanged (same chapter band, same slot weighting): only the moment of
## rolling moved. `tier` still sets the gold bonus and gem odds.

var tier := "wood"
var grade := "F"           # rolled at drop; the sprite shows it
var opened := false
var buried := false        # buried: invisible until the player comes near
var game: Game
var on_open := Callable()  # optional hook (dead-end caches set a flag)


static func drop(game_node: Node2D, chest_tier: String, pos: Vector2) -> Chest:
	var c := Chest.new()
	c.game = game_node
	c.tier = chest_tier
	c.global_position = pos
	var grade_rng := RandomNumberGenerator.new()
	grade_rng.randomize()
	c.grade = Balance.roll_weighted_grade(
		Balance.gear_weights(String(game_node.chapter_id)), grade_rng)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2.2, 1.6)
	shadow.position = Vector2(0, 16)
	c.add_child(shadow)

	# The TELL: B-grade and better wear a grade-coloured halo, so a rich
	# chest is legible from across the room (the loot moment). Scaled by
	# terrain luminance like every other light — additive glow blows out
	# daylight scenes otherwise.
	if Items.GRADES.find(c.grade) >= Items.GRADES.find("B"):
		var halo := Sprite2D.new()
		halo.texture = Art.tex("glow")
		var gc: Color = Items.GRADE_COLOR[c.grade]
		halo.modulate = Art.hdr(Color(gc.r, gc.g, gc.b, Balance.CHEST_HALO_ALPHA))
		halo.scale = Vector2(1.35, 1.35)
		halo.z_index = -1
		c.add_child(halo)
		var pulse := c.create_tween().set_loops()
		pulse.tween_property(halo, "scale", Vector2(1.55, 1.55), 0.9)
		pulse.tween_property(halo, "scale", Vector2(1.35, 1.35), 0.9)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex("chest_" + c.grade.to_lower())
	# A light wash of the grade colour on top of the authored material, so
	# F..C (four wooden boxes) still separate at a glance. Same colour
	# language the item names and gem icons already speak.
	sprite.modulate = Color(1, 1, 1).lerp(
		Items.GRADE_COLOR[c.grade], Balance.CHEST_GRADE_TINT)
	# Grade chests are authored at ~32px; scale_for normalizes any source
	# size back to the on-screen footprint the 16px tier art had.
	var base_scale := Art.scale_for(sprite.texture, Balance.CHEST_SCALE_16PX)
	sprite.scale = base_scale
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
	sprite.scale = base_scale * 0.17
	var tween := c.create_tween()
	tween.tween_property(sprite, "scale", base_scale * 1.13, 0.15)
	tween.tween_property(sprite, "scale", base_scale, 0.1)
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
	# The grade was rolled (and shown) at drop time — honour it, don't re-roll.
	# Same distribution as the old roll_chapter_gear path: chapter band, then
	# _roll_slot. The chest never lies about what it holds.
	var item := Items.roll_gear_of_grade(grade, rng, body.cls)
	game.give_loot({"kind": "item", "item": item}, global_position)
	game.loot_fanfare(item["grade"], global_position)  # rarity chime + beam
	var bonus_gold := rng.randi_range(3, 8) * (1 + ["wood", "silver", "gold"].find(tier))
	body.gain_gold(bonus_gold)
	game.hud.loot_banner(item, bonus_gold)

	# Chests can also hold loose gems (better chests, better odds) — but only
	# once regular gems are dropping (ch4+); ch1-3 chests are gear + gold only.
	var gem_chance: float = {"wood": 0.25, "silver": 0.6, "gold": 1.0}[tier]
	if Balance.regular_gems_drop(game.chapter_id) and rng.randf() < gem_chance:
		var gem := Items.random_gem(rng, 1, Balance.special_gems_drop(game.chapter_id))
		if game.give_loot({"kind": "gem", "gem": gem}, global_position):
			game.spawn_text(body.global_position + Vector2(0, -66), "+ " + Items.gem_title(gem), Items.gem_color(gem))

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
