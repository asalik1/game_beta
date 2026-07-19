class_name Projectile extends Area2D
## A flying arrow / fireball / knife / shadow bolt.
## Friendly shots route their damage through the owning Player
## (so crit, lifesteal and burns apply); hostile shots hurt the player.

var vel := Vector2.ZERO
var dmg := 10.0                # used by hostile (enemy) projectiles
var hostile_type := "magic"    # hostile: damage type (set from the shooter)
var source_enemy: Node = null  # hostile: shooter, for crit/pen/dex resolution
var root_dur := 0.0            # webber snare shot: roots the player on hit
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
var spin := true               # darts (assassin fan) fly POINT-FIRST instead
## Visual-only muzzle height: the sprite/glow/trail DRAW this many px above
## the physics position (hand height on the feet-anchored hero body), so an
## arrow leaves the bow instead of the hip. The flight line, collision and
## ground effects (bloom mist) stay on the origin plane — Y is a ground axis,
## so raising the physics position would change what the shot hits.
var rise := 0.0:
	set(v):
		rise = v
		_apply_rise()  # applied on assignment — callers stamp it right after spawn
var _vis: Node2D = null        # container for every visual child (set in spawn)


## The hand height is a SCREEN distance: divide out the root scale (venom
## blade 1.5x, net copies mirror the sender) so a scaled blade still leaves
## the hand, not above it. Re-applied per-frame — scale lands after rise.
func _apply_rise() -> void:
	if _vis != null:
		_vis.position.y = -rise / maxf(0.05, scale.y)
var homing := false            # Wind firebolt: friendly bolt curves to a target
# --- MP-10 (§4.1 projectile row: spawn event + local flight) ---
# net_visual: another peer's projectile flying HERE as pure presentation —
# no damage, no riders; it bursts on the bodies the real one would hit and
# dies (small divergence accepted). net_id: hostile shots get a session id
# so a guest's Mirrorstep can consume the REAL bolt host-side.
var net_visual := false
var net_id := 0
var _net_announced := false
var _already_hit := {}

# Glow tint per projectile type — bright and readable at a glance.
const GLOWS := {
	"fireball": Color(1.0, 0.55, 0.15), "bolt": Color(1.0, 0.35, 0.85),
	"arrow": Color(0.9, 1.0, 0.6), "arrow_base": Color(0.90, 0.78, 0.52),
	"arrow_frost": Color(0.55, 0.90, 1.0), "arrow_void": Color(0.62, 0.32, 0.95),
	"arrow_void_eye": Color(0.68, 0.36, 1.0),
	"knife": Color(0.8, 0.85, 1.0),
	"slash": Color(1.0, 0.9, 0.5), "icelance": Color(0.5, 0.9, 1.0),
	"shadowbolt": Color(0.7, 0.4, 1.0), "dart": Color(0.85, 0.92, 1.0),
	"shuriken": Color(1.0, 0.85, 0.4), "mage_firebolt": Color(1.0, 0.48, 0.12),
	"warlock_shadowbolt": Color(0.68, 0.34, 0.98),
	"hellfire_brand_bolt": Color(1.0, 0.28, 0.06),
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

	# Every visual child rides in _vis so `rise` can lift the drawn shot to
	# hand height without moving the physics body (see the var's comment).
	var vis := Node2D.new()
	p._vis = vis
	p.add_child(vis)

	# Soft glow behind the bullet so it pops against any background.
	# Magic bolts burn hotter.
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	var hot := tex_name in ["fireball", "icelance", "shadowbolt", "mage_firebolt", "warlock_shadowbolt", "hellfire_brand_bolt"]
	glow.modulate = Art.hdr(Color(p.glow_color, 0.8 if hot else 0.6))
	glow.scale = Vector2(1.35, 1.35) if hot else Vector2(1.0, 1.0)
	vis.add_child(glow)
	if hot:
		# Magic bolts CARRY light: walls and ground brighten as they pass
		# (scaled to the room's darkness — daylight mutes it).
		vis.add_child(Art.light(p.glow_color, 95.0, 0.85 * p.game.light_mult))

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
		var spark_col: Color = {
			"fireball": Color(1.0, 0.8, 0.3),
			"icelance": Color(0.75, 0.95, 1.0),
			"shadowbolt": Color(0.6, 0.3, 0.9),
			"mage_firebolt": Color(1.0, 0.64, 0.18),
			"warlock_shadowbolt": Color(0.65, 0.32, 0.95),
			"hellfire_brand_bolt": Color(1.0, 0.24, 0.06),
		}.get(tex_name, Color.WHITE)
		sparks.color = spark_col
		vis.add_child(sparks)

	# Arrows and knives streak: a thin motion trail behind the tip.
	# Knives read SHARP (round 26): longer, thinner streak, dimmer glow,
	# blade stretched along the flight line — a dart, not a glowstick.
	if tex_name in ["arrow", "arrow_base", "arrow_frost", "arrow_void", "knife"]:
		var trail := Sprite2D.new()
		trail.texture = Art.tex("glow")
		trail.modulate = Color(p.glow_color, 0.4 if tex_name.begins_with("arrow") else 0.5)
		trail.rotation = velocity.angle()
		trail.position = -velocity.normalized() * 15.0
		trail.scale = Vector2(1.6, 0.2) if tex_name.begins_with("arrow") else Vector2(2.6, 0.12)
		vis.add_child(trail)
	if tex_name == "knife":
		glow.modulate.a = 0.35
		glow.scale = Vector2(0.7, 0.7)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(tex_name)
	match tex_name:
		"arrow_base", "arrow_frost", "arrow_void", "arrow_void_eye":
			sprite.scale = Vector2.ONE
		"mage_firebolt", "warlock_shadowbolt":
			sprite.scale = Vector2(1.2, 1.2)
		"hellfire_brand_bolt":
			sprite.scale = Vector2(0.84, 0.84)  # 30% smaller than the caster bolts
		"knife": sprite.scale = Vector2(3.8, 2.1)
		"dart":
			# The assassin's thrown KUNAI (round 50): a sleek generated blade
			# (assets/sprites/dart.png, ~90px) flying point-first (rotation =
			# velocity.angle() below), tinted by the knife-throw variant via
			# p.modulate, with the kit's _knife_glow halo behind it.
			sprite.scale = Vector2(0.28, 0.28)
			glow.visible = false
		"shuriken":
			# Golden Ronin's throwing star (assets/sprites/shuriken.png, 64px):
			# spins on its own axis in flight (see _physics_process) and trails a
			# fading after-image (kit ShurikenEcho). Keeps a soft GOLD aura framing
			# the star (the glow sprite, gold-tinted via GLOWS) like the base kunai's
			# halo / Phantom's blue glow; _knife_glow adds a tighter gold core.
			sprite.scale = Vector2(0.4, 0.4)          # 20% smaller than before (0.5)
			glow.scale = Vector2(0.8, 0.8)
			glow.modulate = Art.hdr(Color(p.glow_color, 0.75))
		_: sprite.scale = Vector2(3, 3)
	sprite.rotation = velocity.angle()
	vis.add_child(sprite)
	p.spr = sprite

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9
	cs.shape = shape
	p.add_child(cs)

	p.collision_layer = 0
	# Layer bits: 1 = walls, 2 = player, 4 = enemies. MP-verified (phase 0):
	# every Player body sits on layer 2 (player_core.gd), so a hostile
	# shot's mask already collides with ANY number of player bodies — no
	# mask change needed for co-op — and _on_body_entered resolves hits by
	# CLASS (`body is Player`), never by identity against game.player.
	p.collision_mask = (1 | 4) if is_friendly else (1 | 2)
	game_node.add_child(p)
	return p


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not _net_announced:
		# MP-10: announce on the FIRST flight frame — spawn() returns
		# before callers set source/pierce/theme, so the event snapshot
		# waits one tick (16 ms; imperceptible on the copies).
		_net_announced = true
		_net_announce()
	if homing and friendly:
		_steer_home(delta)
	_apply_rise()
	global_position += vel * delta
	if spr and spin:
		if tex_kind == "knife":
			spr.rotation += 16.0 * delta   # thrown blades tumble end over end
		elif tex_kind == "shuriken":
			spr.rotation += 34.0 * delta   # a throwing star whirs fast on its axis
	life -= delta
	if life <= 0.0:
		_bloom()
		queue_free()


## MP-10: real projectiles fan out as spawn events; everyone else flies a
## visual copy (net_session._rpc_spawn_projectile). Only the OWNER of a
## friendly shot announces it (copies have no source and stay silent);
## hostile shots are host business. Offline: net_online is false — inert.
func _net_announce() -> void:
	if net_visual or game == null or not game.net_online():
		return
	if friendly:
		if source_player != null and is_instance_valid(source_player) \
				and source_player.is_locally_controlled():
			game.net_session().announce_projectile(self)
	elif game.net_host():
		game.net_session().announce_projectile(self)


## Curve toward the nearest live enemy, keeping speed — a gentle homing arc
## (baseline Wind firebolt behavior), so the twin Wind bolts converge on their mark.
func _steer_home(delta: float) -> void:
	var best: Node2D = null
	var best_d := 1.0e12
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.untargetable:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		var desired := (best.global_position - global_position).normalized() * vel.length()
		vel = vel.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))


## Venom Bloom: the projectile detonates into an expanding poison mist
## on its first hit or at the end of its flight. Tick rate rides the fx
## payload (round 49 AoE pass) so the mist tunes independently.
func _bloom() -> void:
	if fx.get("bloom_mist", 0) and is_instance_valid(source_player):
		fx["bloom_mist"] = 0
		source_player._mist(global_position, 120.0, float(fx.get("bloom_dps", 0.4)),
			fx.get("bloom_color", Color(0.45, 0.95, 0.3)), 3.0)


## Where the shot is DRAWN (physics position lifted by the muzzle rise) —
## impact FX spawn here so the burst lands on the arrow, not below it.
func _fx_pos() -> Vector2:
	return global_position + Vector2(0, -rise)


## A quick expanding shockwave where a magic bolt lands.
## Darts get a smaller, snappier ring so fan-of-knives hits register
## even when the flight itself was too short to see (round 31).
func _impact_ring() -> void:
	if not tex_kind in ["fireball", "icelance", "shadowbolt", "dart"]:
		return
	var small := tex_kind == "dart"
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Art.hdr(Color(glow_color, 0.9))
	ring.global_position = _fx_pos()
	ring.scale = Vector2(0.25, 0.25) if small else Vector2(0.4, 0.4)
	ring.z_index = 8
	game.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale",
		Vector2(0.9, 0.9) if small else Vector2(1.7, 1.7), 0.13 if small else 0.18)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.15 if small else 0.2)
	rt.tween_callback(ring.queue_free)


## Frostfall arrows leave one small complete crystal at every enemy contact.
## It fades in place rather than replaying the cast strip's transitional poses.
func _frost_arrow_impact() -> void:
	if tex_kind != "arrow_frost":
		return
	var flake := Sprite2D.new()
	flake.texture = Art.tex("fx/frost_snowflake_radial")
	flake.global_position = _fx_pos()
	flake.rotation = randf_range(-0.35, 0.35)
	flake.scale = Vector2(0.18, 0.18)
	flake.modulate = Color(0.82, 0.96, 1.0, 0.88)
	flake.z_index = 9
	game.add_child(flake)
	var fade := flake.create_tween()
	fade.tween_property(flake, "scale", Vector2(0.10, 0.10), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.parallel().tween_property(flake, "modulate:a", 0.0, 0.35)
	fade.tween_callback(flake.queue_free)


func _on_body_entered(body: Node) -> void:
	if net_visual:
		# MP-10 visual copy: burst where the real one bites, never damage
		# (the real hit arrives as its own RPC on the authority's side).
		if friendly and body is Enemy:
			if _already_hit.has(body):
				return
			_already_hit[body] = true
			game.burst(_fx_pos(), glow_color, 5)
			_frost_arrow_impact()
			_impact_ring()
			if not pierce:
				queue_free()
		elif not friendly and body is Player:
			game.burst(_fx_pos(), glow_color, 5)
			queue_free()
		elif body is StaticBody2D:
			game.burst(_fx_pos(), Color(glow_color, 0.5), 3)
			queue_free()
		return
	if friendly and body is Enemy:
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		game.burst(_fx_pos(), glow_color, 5)
		_frost_arrow_impact()
		_impact_ring()
		if is_instance_valid(source_player):
			# Resolve with the payload SNAPSHOT this shot was fired with (fx,
			# copied from _tfx at spawn) — never with whatever the player has
			# cast SINCE: hit_enemy merges the player's live _tfx into the
			# effects, and a shot in flight outlives its cast (the same
			# save-restore idiom as Consecration's second pulse).
			var saved_tfx: Dictionary = source_player._tfx
			source_player._tfx = {}
			source_player.hit_enemy(body, hit_player_mult, fx)
			# Stormcaller passive: the arrow leaps to a second enemy.
			if fx.get("ric", 0) > 0:
				_ricochet(body)
			source_player._tfx = saved_tfx
		else:
			body.take_damage(dmg, vel.normalized())
		# pierce_cap (round 49 AoE pass): a capped pierce stops after N
		# bodies — the mid-tier coverage tool between "one hit" and
		# "threads the whole pack" (blood knives, void bolts, venom arrows).
		var cap := int(fx.get("pierce_cap", 0))
		if not pierce or (cap > 0 and _already_hit.size() >= cap):
			_bloom()
			queue_free()
	elif not friendly and body is Player:
		game.burst(_fx_pos(), glow_color, 5)
		var shooter: Node = source_enemy if is_instance_valid(source_enemy) else null
		body.take_damage(dmg, hostile_type, shooter)
		# Webber's snare shot (mob mechanic): roots the player on hit —
		# the dodge is denied for a beat so an ally's pounce can land.
		if root_dur > 0.0 and body.has_method("apply_root"):
			body.apply_root(root_dur)
		queue_free()
	elif body is StaticBody2D:
		game.burst(_fx_pos(), Color(glow_color, 0.5), 3)
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
		# Round 49 (Storm's single-target floor): with nobody to leap to,
		# the charge GROUNDS through the same body — a reduced return
		# strike, so the fork isn't a dead rider at boss doors. Packs
		# still get the full leap; direct hit is safe here (no Area2D
		# spawned inside the physics flush).
		var back := float(fx.get("ric_back", 0.0))
		if back > 0.0 and is_instance_valid(source_player) \
				and is_instance_valid(hit) and hit is Enemy and not (hit as Enemy).dying:
			var saved_tfx: Dictionary = source_player._tfx
			source_player._tfx = {}
			source_player._beam_fx(global_position + Vector2(20, -26), hit.global_position, glow_color, 0.12)
			source_player.hit_enemy(hit, hit_player_mult * back, {"aoe": true})
			source_player._tfx = saved_tfx
		return
	var dir := (best.global_position - global_position).normalized()
	# DEFERRED: _ricochet runs inside body_entered (the physics flush) — spawning
	# the new Area2D there is a Godot error (area_set_shape_disabled). The parent
	# projectile may be queue_freed by then, but it still exists at deferred time.
	_spawn_ricochet.call_deferred(dir)


func _spawn_ricochet(dir: Vector2) -> void:
	# The leap keeps the parent's look: arrows ricochet as arrows,
	# shadowbolts (Hollow Choir) split as shadowbolts.
	var p := Projectile.spawn(game, global_position + dir * 10.0, dir * 520.0, 0.0, true, tex_kind)
	p.rise = rise  # the leap keeps flying at the parent's drawn height
	p.modulate = modulate
	p.source_player = source_player
	p.hit_player_mult = hit_player_mult * 0.6
	p.fx = {"ric": fx.get("ric", 1) - 1}
