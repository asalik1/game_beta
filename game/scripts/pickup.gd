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
var pickup_delay := 0.0  # discard-throw: ignore all claims until this elapses


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
		# Sparkle (visual pass): a tiny glint winks on its own beat — gold
		# on the ground CATCHES THE EYE. HDR so the wink blooms.
		var glint := Sprite2D.new()
		glint.texture = Art.tex("glow")
		glint.modulate = Art.hdr(Color(1.0, 0.95, 0.7, 0.0), 1.8)
		glint.position = Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 0.0))
		glint.scale = Vector2(0.16, 0.16)
		c.add_child(glint)
		var gt := c.create_tween().set_loops()
		gt.tween_interval(randf_range(0.5, 1.7))
		gt.tween_property(glint, "modulate:a", 0.9, 0.08)
		gt.tween_property(glint, "modulate:a", 0.0, 0.16)


## A loot payload ({"kind": "item"/"gem"/"stone", ...}) dropped where a
## full bag rejected it. The registry entry (game.dropped_loot) is the
## caller's job; this only builds the world node.
static func drop_loot(game_node: Node2D, payload: Dictionary, pos: Vector2) -> Pickup:
	var c := Pickup.new()
	c.game = game_node
	c.loot = payload
	c.add_to_group("loot_pickups")
	c.global_position = pos + Vector2(randf_range(-22, 22), randf_range(-16, 16))
	# Each kind builds its icon sprite + a tint; a shared shine (glow + bob +
	# winking glint) then makes ANY drop read as loot instead of scenery.
	var spr: Sprite2D = null
	var tint := Color(1, 1, 1)
	match str(payload.get("kind", "")):
		"item":
			tint = Items.GRADE_COLOR.get(payload["item"].get("grade", "F"), Color(1, 1, 1))
			spr = Sprite2D.new()
			spr.texture = Art.icon_for(payload["item"])
			spr.scale = Vector2(1.6, 1.6)
		"gem":
			# A real cut gem on the ground (was a text ◆ glyph). A Raven faceted
			# gem tinted by the gem's stat color reads as a proper jewel; fall
			# back to the procedural gem if the icon isn't present/imported yet.
			tint = Items.gem_color(payload["gem"])
			spr = Sprite2D.new()
			if ResourceLoader.exists("res://assets/icons/gem.png"):
				spr.texture = load("res://assets/icons/gem.png")
				spr.modulate = tint
			else:
				spr.texture = Art.gem_icon(tint, int(payload["gem"].get("lvl", 1)))
			spr.scale = Vector2(0.9, 0.9)
		_:
			# Consumable on the ground: real icon when one exists (mana
			# draught, elixir, scroll, stones), else the old ⟲ glyph.
			tint = Color(0.6, 0.9, 1.0)
			var ctex: ImageTexture = Art.consumable_icon(payload.get("stone", {}))
			if ctex != null:
				spr = Sprite2D.new()
				spr.texture = ctex
				spr.scale = Vector2(1.1, 1.1)
			else:
				c._glyph("⟲", tint)
	if spr != null:
		c.add_child(spr)
	c._body_setup()
	game_node.add_child(c)
	c._loot_shine(spr, tint)   # after add_child: tweens need the node in-tree
	return c


## Ground-loot eye-catch: a soft glow pooled under the drop so it lifts off the
## terrain, a slow bob, and a winking HDR glint that blooms — the same treatment
## the gold coins get. Without it a gem/gear on dirt reads as background.
## `spr` may be null (glyph fallback); then only the glow + glint are added.
func _loot_shine(spr: Sprite2D, tint: Color) -> void:
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	glow.modulate = Color(tint, 0.5)
	glow.scale = Vector2(1.2, 0.95)
	glow.z_index = -1
	add_child(glow)
	var glint := Sprite2D.new()
	glint.texture = Art.tex("glow")
	glint.modulate = Art.hdr(Color(1.0, 1.0, 0.95, 0.0), 1.8)
	glint.position = Vector2(randf_range(-4.0, 5.0), randf_range(-9.0, -2.0))
	glint.scale = Vector2(0.15, 0.15)
	add_child(glint)
	var gt := create_tween().set_loops()
	gt.tween_interval(randf_range(0.4, 1.6))
	gt.tween_property(glint, "modulate:a", 0.95, 0.08)
	gt.tween_property(glint, "modulate:a", 0.0, 0.18)
	if spr != null:
		var bob := spr.create_tween().set_loops()
		bob.tween_property(spr, "position:y", -4.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(spr, "position:y", 0.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	pickup_delay = maxf(0.0, pickup_delay - delta)
	var d := global_position.distance_to(p.global_position)
	if loot.is_empty():
		# Coin: magnet toward the player.
		if d < 110.0:
			magnet = true
		if magnet:
			global_position = global_position.move_toward(p.global_position,
				(300.0 + (110.0 - minf(d, 110.0)) * 4.0) * delta)
	elif d < 30.0 and retry_cd <= 0.0 and pickup_delay <= 0.0:
		# Loot: keep retrying while stood on — the player may have just
		# made bag room (body_entered alone fires only on ENTER). A freshly
		# DISCARDED drop stays put until its no-pickup window elapses.
		_try_claim(p)


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	if loot.is_empty():
		body.gain_gold(value)
		game.sfx("coin")
		queue_free()
	elif retry_cd <= 0.0 and pickup_delay <= 0.0:
		_try_claim(body)


func _try_claim(p: Player) -> void:
	if game._try_receive(loot):
		game.dropped_loot.erase(loot)
		# Gems get their own sparkle chime; everything else keeps the
		# potion-swig pickup sound.
		game.sfx("gem" if String(loot.get("kind", "")) == "gem" else "potion")
		queue_free()
	else:
		# SAY why it won't pick up (playtest: "unable to interact, idk") —
		# the silent 1.2s retry read as a bug, not a full bag.
		game.spawn_text(global_position + Vector2(0, -30), "BAG FULL", Color(1.0, 0.55, 0.4))
		retry_cd = 1.2