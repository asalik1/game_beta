class_name Pickup extends Area2D
## Things lying on the ground. Two flavors:
##  - gold coins (magnet toward the player, instant)
##  - LOOT (bag-overflow drops: gear/gem/stone payloads). No magnet;
##    standing on one retries the claim, so a full bag leaves it put.
##    Unclaimed drops flush into the MAILBOX at chapter end
##    (game.flush_dropped_loot) — nothing is ever silently lost.
##
## MP-11 (§5.5): pickups are PERSONAL. In co-op every machine spawns its
## OWN copies (the host events kills out per player; each side rolls or
## applies its own share), so everything lying here belongs to the LOCAL
## player — collection is gated to it below. Solo is untouched: the one
## player IS the local player.

const COIN_W := 20.0            # rendered coin width (was the 8px glyph at 2.5x)
const GOLDRUSH_COIN_W := 34.0   # the charged coin, oversized so it reads as an EVENT

var value := 3
var game: Game
var magnet := false
var loot := {}        # empty = a gold coin; else a dropped-loot payload
var goldrush := false  # charged coin: surges greed on touch instead of paying
var retry_cd := 0.0   # full-bag claim retry throttle
var pickup_delay := 0.0  # discard-throw: ignore all claims until this elapses
var claimed := false   # queue_free is deferred; each reward can pay only once


# Coin presentation (P7.B, 2026-08-19; owner: "the coins don't look polished
# enough"). A coin is a SPINNING piece when `coin_anim.png` ships (a 6-frame
# turn with the highlight sweeping its face — the Art.anim_prop seam, same as
# any animated prop), else the static disc; it lands with a scatter ARC and two
# bounces instead of a hop, pools a soft gold glow on the ground, winks a glint,
# and on pickup bursts three chips toward the hero while the HUD gold line
# pulses. Presentation constants.
const COIN_ARC_H := 26.0          # px apex of the drop arc
const COIN_SCATTER := 34.0        # px lateral scatter from the death spot
const COIN_BOUNCE := 0.42         # second bounce = this share of the first
const COIN_GLOW_A := 0.40

## The coin's visual: the spin strip when installed, else the static disc.
static func _coin_visual(width: float) -> Node2D:
	var anim: AnimatedSprite2D = Art.anim_prop("coin")
	var vis: Node2D = anim
	var native := 16.0
	if anim != null:
		var sf: SpriteFrames = anim.sprite_frames
		if sf != null and sf.get_frame_count("default") > 0:
			native = float(sf.get_frame_texture("default", 0).get_width())
		anim.scale = Vector2.ONE * (width / maxf(1.0, native))
	else:
		var sprite := Sprite2D.new()
		sprite.texture = Art.tex("coin")
		# Width-normalized: the coin renders `width` world px whether the art is
		# the 8px procedural glyph or the painterly override (2026-08-18).
		sprite.scale = Art.scale_for(sprite.texture, width / 16.0)
		vis = sprite
	return vis


static func drop_gold(game_node: Node2D, amount: int, pos: Vector2) -> void:
	# Scatter a few coins around the death spot.
	amount = (game_node as Game).gold_scaled(amount)  # weekly "gilded" hook
	if amount <= 0:
		return
	var coins := clampi(amount / 3, 1, 5)
	for i in coins:
		var c := Pickup.new()
		c.game = game_node
		c.value = amount / coins + int(i < amount % coins)
		# The coin is SPAWNED at the death spot and ARCS out to its rest point
		# (tweened below), so the scatter reads as a spill, not a teleport.
		var rest := pos + Vector2(randf_range(-COIN_SCATTER, COIN_SCATTER), randf_range(-18, 18))
		c.global_position = pos
		var sprite := _coin_visual(COIN_W)
		c.add_child(sprite)
		# soft gold pool under the coin — lifts it off a dark floor
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.82, 0.4, COIN_GLOW_A)
		glow.scale = Vector2(0.55, 0.4)
		glow.position = Vector2(0, 4)
		glow.z_index = -1
		c.add_child(glow)
		c._body_setup()
		game_node.add_child(c)
		# Drop arc: the body slides to its rest point while the visual hops an
		# arc and bounces twice (position.y of the visual, body stays grounded).
		var arc := c.create_tween()
		arc.tween_property(c, "global_position", rest, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var hop := c.create_tween()
		hop.tween_property(sprite, "position:y", -COIN_ARC_H, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(sprite, "position:y", 0.0, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hop.tween_property(sprite, "position:y", -COIN_ARC_H * COIN_BOUNCE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(sprite, "position:y", 0.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hop.tween_property(sprite, "position:y", -COIN_ARC_H * COIN_BOUNCE * 0.35, 0.07)
		hop.tween_property(sprite, "position:y", 0.0, 0.07)
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


## GOLD RUSH charged coin (2026-07-09): a rare trash spill. Touching it
## surges Greed for a window (Balance.GOLDRUSH_*) instead of paying gold —
## auto-triggers, never enters the bag. Oversized + hot glow so it reads
## as an EVENT, not another coin; magnets like one (loot stays empty).
static func drop_goldrush(game_node: Node2D, pos: Vector2) -> void:
	var c := Pickup.new()
	c.game = game_node
	c.goldrush = true
	c.global_position = pos
	var sprite := _coin_visual(GOLDRUSH_COIN_W)
	sprite.modulate = Art.hdr(Color(1.0, 0.9, 0.5), 1.5)
	c.add_child(sprite)
	c._body_setup()
	game_node.add_child(c)
	c._loot_shine(sprite, Color(1.0, 0.85, 0.35))


## Consumable icons are authored LARGE — up to Art.CONSUMABLE_ICON_MAX (128px)
## for the bag/HUD, where a Control downsizes them to its rect. On the world
## floor the sprite is drawn at raw texture size, so a 128px bottle at a fixed
## 1.1x rendered ~3x an item drop (owner: "potion dropped and rendered HUGE").
## Normalize any authored consumable so its longest side reads ~item-drop size.
const _WORLD_CONSUMABLE_PX := 48.0
static func _world_consumable_scale(tex: Texture2D) -> Vector2:
	var mx := float(maxi(tex.get_width(), tex.get_height()))
	var s := _WORLD_CONSUMABLE_PX / maxf(mx, 1.0)
	return Vector2(s, s)


## A loot payload ({"kind": "item"/"gem"/"stone", ...}) dropped where a
## full bag rejected it. The registry entry (game.dropped_loot) is the
## caller's job; this only builds the world node.
static func drop_loot(game_node: Node2D, payload: Dictionary, pos: Vector2) -> Pickup:
	var c := Pickup.new()
	c.game = game_node
	c.loot = payload
	c.add_to_group("loot_pickups")
	c.global_position = (game_node as Game).resolve_drop_pos(pos + Vector2(randf_range(-22, 22), randf_range(-16, 16)))
	payload["pos"] = [c.global_position.x, c.global_position.y]
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
			# The same lore-authored stat+level stone used by the bag/socket UI.
			# Art.gem_icon retains the old shared/tinted cut as missing-art fallback.
			tint = Items.gem_color(payload["gem"])
			spr = Sprite2D.new()
			spr.texture = Art.gem_icon(tint, int(payload["gem"].get("lvl", 1)))
			spr.scale = Vector2(0.9, 0.9)
		"material":
			# Bag-overflow crafting material: its authored 32px icon, grade-tinted.
			tint = Items.GRADE_COLOR.get(String(payload.get("grade", "F")), Color(1, 1, 1))
			var mtex: ImageTexture = Art.material_icon(String(payload.get("family", "")),
				String(payload.get("grade", "")))
			if mtex != null:
				spr = Sprite2D.new()
				spr.texture = mtex
				spr.scale = Vector2(1.1, 1.1)
			else:
				c._glyph("◆", tint)
		"potion":
			# Bag-overflow graded potion (supply-chest drop): its authored bottle,
			# grade-tinted (falls back to the alembic glyph if the sprite is absent).
			var pot: Dictionary = payload.get("potion", {})
			tint = Items.GRADE_COLOR.get(String(pot.get("grade", "F")), Color(0.7, 0.95, 0.8))
			var ptex: ImageTexture = Art.consumable_icon(pot)
			if ptex != null:
				spr = Sprite2D.new()
				spr.texture = ptex
				spr.scale = _world_consumable_scale(ptex)
			else:
				c._glyph("⚗", tint)
		"bag":
			# A dropped bag (pack was full on award): its grade-tinted bag art,
			# collected off the ground like any other item.
			tint = Items.GRADE_COLOR.get(String(payload.get("grade", "F")), Color(1, 1, 1))
			var btex: ImageTexture = Art.bag_icon(String(payload.get("grade", "F")))
			if btex != null:
				spr = Sprite2D.new()
				spr.texture = btex
				spr.scale = Vector2(1.3, 1.3)
			else:
				c._glyph("▣", tint)
		_:
			# Consumable on the ground: real icon when one exists (mana
			# draught, elixir, scroll, stones), else the old ⟲ glyph.
			tint = Color(0.6, 0.9, 1.0)
			var ctex: ImageTexture = Art.consumable_icon(payload.get("stone", {}))
			if ctex != null:
				spr = Sprite2D.new()
				spr.texture = ctex
				spr.scale = _world_consumable_scale(ctex)
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
func _loot_shine(spr: Node2D, tint: Color) -> void:
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
	body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
	z_index = 4


func _physics_process(delta: float) -> void:
	var p: Player = game.player
	if claimed or p == null or p.dead or p.downed or p.ghost:
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
	# MP-11 (§5.5): only the LOCAL player collects — a remote's shell
	# gliding over your pile must never eat it. Solo: the one body IS
	# game.local_player, so this line never fires.
	if body != game.local_player:
		return
	if claimed or body.dead or body.downed or body.ghost:
		return
	if goldrush:
		claimed = true
		body.goldrush_time = Balance.GOLDRUSH_DUR  # refresh, never stack
		game.spawn_text(global_position + Vector2(0, -44), "GOLD RUSH!", Color(1.0, 0.85, 0.3))
		game.burst(global_position, Color(1.0, 0.85, 0.35), 14)
		game.sfx("gem")
		queue_free()
	elif loot.is_empty():
		claimed = true
		body.gain_gold(value)
		game.hud.log_event("+%d gold" % body.gold_yield(value), Color(1.0, 0.84, 0.35), "gold")  # P7.A feed (coalesces)
		game.hud.pulse_gold()                                                   # the counter ticks
		game.burst(global_position, Color(1.0, 0.85, 0.4), 3)                   # three chips fly
		game.sfx("coin")
		queue_free()
	elif retry_cd <= 0.0 and pickup_delay <= 0.0:
		_try_claim(body)


func _try_claim(p: Player) -> void:
	if claimed or p != game.local_player or p.dead or p.downed or p.ghost:
		return
	if game._try_receive(loot):
		claimed = true
		var idx := preload("res://scripts/gear_care.gd").index_of(game.dropped_loot, loot)
		if idx >= 0:
			game.dropped_loot.remove_at(idx)
		# Gems get their own sparkle chime; everything else keeps the
		# potion-swig pickup sound.
		game.sfx("gem" if String(loot.get("kind", "")) == "gem" else "potion")
		queue_free()
	else:
		# SAY why it won't pick up (playtest: "unable to interact, idk") —
		# the silent 1.2s retry read as a bug, not a full bag.
		game.spawn_text(global_position + Vector2(0, -30), "PACK OR STACK FULL", Color(1.0, 0.55, 0.4))
		retry_cd = 1.2
