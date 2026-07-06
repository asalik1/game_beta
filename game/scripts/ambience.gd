class_name Ambience
## AMBIENT LIFE (Graphics & Ambience track, DESIGN.md): critters that
## make places feel inhabited instead of composited. ZERO gameplay
## weight — no XP, no drops, no aggro, no collision. Scenery that
## reacts: birds scatter when the player walks up, crows lift off
## tombstones, butterflies just drift.
##
## populate(game, zi) is called from game_world._spawn_scenery; the
## returned nodes are parked in zone_scenery so room rebuilds and
## terrain repaints free them with the rest of the decor.


## One critter: a sprite that putters around its home point on tweens.
## Birds/crows flee (fly off and despawn) when the player closes in.
class Critter extends Node2D:
	var game: Node2D
	var kind := "bird"           # bird / crow / butterfly
	var home := Vector2.ZERO
	var fled := false
	var spr: Sprite2D
	var wander_tw: Tween

	func _ready() -> void:
		z_index = -7  # ground level: under actors, over the ground litter
		spr = Sprite2D.new()
		spr.texture = Art.tex(kind)
		spr.scale = Vector2(2.4, 2.4) if kind != "butterfly" else Vector2(2.0, 2.0)
		add_child(spr)
		_wander()

	func _wander() -> void:
		if fled or not is_inside_tree():
			return
		wander_tw = create_tween()
		if kind == "butterfly":
			# An endless lazy drift around home — never lands, never reacts.
			var target := home + Vector2(randf_range(-90.0, 90.0), randf_range(-60.0, 60.0))
			spr.flip_h = target.x < position.x
			wander_tw.tween_property(self, "position", target, randf_range(1.6, 2.8)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			wander_tw.tween_callback(_wander)
			return
		# Ground bird: a couple of hops, peck at the dirt, look around.
		var hops := 1 + randi() % 3
		var from := position
		for i in hops:
			var target := home + Vector2(randf_range(-70.0, 70.0), randf_range(-40.0, 40.0))
			if i == 0:
				spr.flip_h = target.x < from.x
			wander_tw.tween_property(self, "position", target, 0.22).set_trans(Tween.TRANS_SINE)
			wander_tw.tween_interval(0.1)
		for i in 2:  # peck-peck
			wander_tw.tween_property(spr, "scale:y", spr.scale.y * 0.7, 0.09)
			wander_tw.tween_property(spr, "scale:y", spr.scale.y, 0.09)
		wander_tw.tween_interval(randf_range(0.8, 2.4))
		wander_tw.tween_callback(_wander)

	func _process(_delta: float) -> void:
		if fled or kind == "butterfly":
			return
		var p: Node2D = game.player
		if p and global_position.distance_to(p.global_position) < 95.0:
			_flee()

	func _flee() -> void:
		fled = true
		if wander_tw:
			wander_tw.kill()
		var away := Vector2.RIGHT
		if game.player:
			var d: Vector2 = global_position - game.player.global_position
			if d.length() > 1.0:
				away = d.normalized()
		var dest := position + away * 280.0 + Vector2(randf_range(-40.0, 40.0), -420.0)
		spr.flip_h = dest.x < position.x
		# Wing flutter while it climbs out of the scene.
		var flap := create_tween().set_loops()
		flap.tween_property(spr, "scale:y", spr.scale.y * 0.55, 0.07)
		flap.tween_property(spr, "scale:y", spr.scale.y, 0.07)
		var tw := create_tween()
		tw.tween_property(self, "position", dest, 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(spr, "modulate:a", 0.0, 1.0)
		tw.tween_callback(queue_free)


## Roll this room's critters from its terrain. Only rooms that are safe
## at BUILD time (no authored pack, no boss) get ground birds — a combat
## room's birds would be dead the moment the seals dropped anyway.
static func populate(game: Node2D, zi: int) -> Array:
	var out: Array = []
	var tid: String = game.terrain_by_zone[zi]
	var zone: Dictionary = game.zones[zi]
	var enemies: Array = zone.get("enemies", [])
	var safe: bool = String(zone.get("boss", "")) == "" and enemies.is_empty()
	var pr: Rect2 = game.play_rect(zi)
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + int(game.wander_seed)

	var spawn := func(kind: String, n: int) -> void:
		for i in n:
			var c := Critter.new()
			c.game = game
			c.kind = kind
			c.home = pr.position + Vector2(
				rng.randf_range(120.0, pr.size.x - 120.0),
				rng.randf_range(120.0, pr.size.y - 120.0))
			c.position = c.home
			game.world.add_child(c)
			out.append(c)

	if safe and tid in ["village", "darkwood", "storm", "holy"]:
		spawn.call("bird", 3 + rng.randi_range(0, 2))
	if tid in ["village", "darkwood", "holy", "marsh", "spore"]:
		spawn.call("butterfly", 2 + rng.randi_range(0, 2))
	if tid in ["graveyard", "desert"]:
		spawn.call("crow", 2 + rng.randi_range(0, 1))
	return out
