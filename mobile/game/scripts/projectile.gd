class_name Projectile extends Area2D
## A flying arrow / fireball / knife / shadow bolt.
## Friendly shots route their damage through the owning Player
## (so crit, lifesteal and burns apply); hostile shots hurt the player.

signal visual_impact

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
var anim_fps := 0.0            # authored projectile strips opt in per texture
var anim_first := 0
var anim_last := 0
var anim_clock := 0.0
var path_trail: Line2D = null
var path_core: Line2D = null
var path_start := Vector2.ZERO
var path_ready := false
var path_closing := false
var trail_max_points := 0
var trail_min_step := 1.5
var trail_fade_time := 0.11
var motion_profile := {}
var motion_particles: CPUParticles2D = null
var flight_phase := 0.0
var flight_wobble := Vector2.ZERO
var visual_impact_sent := false
var visual_offset := Vector2.ZERO
var visual_offset_start := Vector2.ZERO
var visual_offset_time := 0.0
var visual_offset_elapsed := 0.0
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
		# Offset is presentation-only and expressed in world pixels. Collision,
		# range and network flight remain on the projectile node itself.
		var base_offset := Vector2(
			visual_offset.x / maxf(0.05, scale.x),
			(visual_offset.y - rise) / maxf(0.05, scale.y))
		var wobble_offset := Vector2(
			flight_wobble.x / maxf(0.05, scale.x),
			flight_wobble.y / maxf(0.05, scale.y))
		_vis.position = base_offset + wobble_offset


## Begin the rendered shot somewhere other than its physics muzzle, then fold
## that offset back onto the unchanged base trajectory. Used by cosmetic skins
## whose projectile appears to leave a summoned focus rather than the caster.
func set_visual_origin(world_pos: Vector2, settle_time: float) -> void:
	visual_offset = world_pos - (global_position + Vector2(0, -rise))
	visual_offset_start = visual_offset
	visual_offset_time = maxf(0.001, settle_time)
	visual_offset_elapsed = 0.0
	_apply_rise()


func _advance_visual_offset(delta: float) -> void:
	if visual_offset_time <= 0.0:
		return
	visual_offset_elapsed += delta
	var weight := clampf(visual_offset_elapsed / visual_offset_time, 0.0, 1.0)
	visual_offset = visual_offset_start.lerp(Vector2.ZERO, weight)
	if weight >= 1.0:
		visual_offset = Vector2.ZERO
		visual_offset_time = 0.0
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
	"stormbolt": Color(0.65, 0.92, 1.0), "windslash": Color(0.55, 0.95, 1.0),
	"rotbolt": Color(0.45, 0.85, 0.25), "earthshard": Color(0.62, 0.42, 0.24),
	"metalshard": Color(0.72, 0.78, 0.9), "holybolt": Color(1.0, 0.88, 0.36),
	"griefwave": Color(0.72, 0.78, 1.0), "sigilbolt": Color(0.82, 0.68, 1.0),
	"shuriken": Color(1.0, 0.85, 0.4), "mage_firebolt": Color(1.0, 0.48, 0.12),
	"mage_void_bullet": Color(0.72, 0.28, 1.0),
	"mage_crystal_decree": Color(0.76, 0.94, 1.0),
	"warlock_shadowbolt": Color(0.68, 0.34, 0.98),
	"hellfire_brand_bolt": Color(1.0, 0.28, 0.06),
}

# Boss-only 64px art keeps the existing material language for glows, lights,
# sparks, trails and impacts without inheriting the legacy core sprite.
const BOSS_PROJECTILE_STYLE := {
	"fx_boss_fire_comet": "fireball",
	"fx_boss_frost_lance": "icelance",
	"fx_boss_storm_javelin": "stormbolt",
	"fx_boss_rot_spore": "rotbolt",
	"fx_boss_earth_fang": "earthshard",
	"fx_boss_metal_crownshard": "metalshard",
	"fx_varo_reliquary_bolt": "holybolt",
	"fx_vess_griefwave": "griefwave",
	"fx_sexton_sigilbolt": "sigilbolt",
	"fx_veyx_windslash": "windslash",
	"fx_echo_knife": "knife",
}

# Ordinary ranged mobs no longer share the old pink `bolt`. Their basic shot
# carries the shooter's authored material language; bosses reuse their existing
# signature projectile art for the same reason.
const ENEMY_PROJECTILE_ART := {
	"cultist": "mob_blight_thorn",
	"stormcult": "mob_storm_fork",
	"beastkin_howler": "mob_howl_wave",
	"wildkin_ranger": "arrow_base",
	"null_acolyte": "mob_null_shard",
	"vale_mourner": "mob_grave_nail",
	"forge_acolyte": "mob_forge_brand",
	"hushcaller": "mob_hush_wave",
	"bloom_acolyte": "mob_bloom_seed",
	"static_caller": "mob_storm_fork",
	"plague_chanter": "mob_plague_spore",
	"pale_archivist": "mob_null_shard",
	"cataloguer": "mob_grave_nail",
	"morwen": "fx_boss_rot_spore",
	"choirmother": "fx_sexton_sigilbolt",
	"vess": "fx_vess_griefwave",
	"ashpriest": "fx_boss_fire_comet",
	"icebound": "fx_boss_frost_lance",
	"sleepkeeper": "fx_boss_frost_lance",
	"gardener": "fx_boss_rot_spore",
	"stormdrake_veyx": "fx_boss_storm_javelin",
	"stormmouth": "fx_boss_storm_javelin",
	"echo_clone": "fx_echo_knife",
}

const MOB_PROJECTILE_STYLE := {
	"mob_blight_thorn": "rotbolt",
	"mob_storm_fork": "stormbolt",
	"mob_howl_wave": "earthshard",
	"mob_null_shard": "shadowbolt",
	"mob_grave_nail": "sigilbolt",
	"mob_forge_brand": "fireball",
	"mob_hush_wave": "griefwave",
	"mob_bloom_seed": "rotbolt",
	"mob_plague_spore": "rotbolt",
}

const MOB_PROJECTILE_GLOW := {
	"mob_blight_thorn": Color(0.94, 0.60, 0.12),
	"mob_storm_fork": Color(0.54, 0.88, 1.0),
	"mob_howl_wave": Color(0.84, 0.66, 0.36),
	"mob_null_shard": Color(0.66, 0.24, 0.96),
	"mob_grave_nail": Color(0.76, 0.82, 0.88),
	"mob_forge_brand": Color(1.0, 0.34, 0.05),
	"mob_hush_wave": Color(0.68, 0.84, 0.98),
	"mob_bloom_seed": Color(0.82, 0.36, 0.48),
	"mob_plague_spore": Color(0.64, 0.72, 0.18),
}

# Live motion is authored per MATERIAL, not merely recolored. Every profile
# keeps a short bounded world-space trail plus motes that remain where they
# were emitted; `wobble` moves only the rendered sprite, never its collision.
const MOB_MOTION := {
	"mob_blight_thorn": {
		"trail": Color(0.84, 0.54, 0.10, 0.90), "core": Color(1.0, 0.78, 0.24, 0.80),
		"width": 2.2, "core_width": 0.65, "points": 15, "step": 2.8,
		"wobble": 3.2, "freq": 16.0, "mote": Color(0.96, 0.70, 0.18, 0.92),
		"amount": 9, "mote_life": 0.30, "mote_speed": 20.0, "spread": 34.0,
		"glow_alpha": 0.48, "glow_scale": 0.70,
	},
	"mob_storm_fork": {
		"trail": Color(0.34, 0.74, 1.0, 0.92), "core": Color(0.92, 0.98, 1.0, 0.96),
		"width": 3.0, "core_width": 0.9, "points": 18, "step": 2.2,
		"wobble": 0.45, "freq": 31.0, "mote": Color(0.62, 0.90, 1.0, 0.92),
		"amount": 14, "mote_life": 0.22, "mote_speed": 28.0, "spread": 42.0,
		"pulse": true,
	},
	"mob_howl_wave": {
		"trail": Color(0.70, 0.52, 0.28, 0.66), "core": Color(0.92, 0.78, 0.48, 0.42),
		"width": 2.5, "core_width": 0.45, "points": 12, "step": 3.6,
		"wobble": 1.1, "freq": 9.0, "mote": Color(0.76, 0.62, 0.38, 0.72),
		"amount": 8, "mote_life": 0.34, "mote_speed": 24.0, "spread": 55.0,
	},
	"mob_null_shard": {
		"trail": Color(0.32, 0.08, 0.52, 0.84), "core": Color(0.74, 0.30, 1.0, 0.76),
		"width": 2.2, "core_width": 0.65, "points": 17, "step": 2.8,
		"wobble": 0.75, "freq": 13.0, "mote": Color(0.58, 0.22, 0.88, 0.84),
		"amount": 9, "mote_life": 0.36, "mote_speed": 16.0, "spread": 70.0,
	},
	"mob_grave_nail": {
		"trail": Color(0.68, 0.72, 0.78, 0.74), "core": Color(0.88, 0.94, 1.0, 0.52),
		"width": 1.55, "core_width": 0.40, "points": 13, "step": 3.4,
		"wobble": 0.55, "freq": 11.0, "mote": Color(0.80, 0.82, 0.86, 0.78),
		"amount": 7, "mote_life": 0.42, "mote_speed": 13.0, "spread": 80.0,
	},
	"mob_forge_brand": {
		"trail": Color(1.0, 0.30, 0.04, 0.82), "core": Color(1.0, 0.78, 0.24, 0.80),
		"width": 2.4, "core_width": 0.65, "points": 15, "step": 2.6,
		"wobble": 0.35, "freq": 18.0, "mote": Color(1.0, 0.42, 0.06, 0.90),
		"amount": 13, "mote_life": 0.34, "mote_speed": 34.0, "spread": 46.0,
		"pulse": true,
	},
	"mob_hush_wave": {
		"trail": Color(0.52, 0.70, 0.88, 0.70), "core": Color(0.84, 0.94, 1.0, 0.48),
		"width": 3.4, "core_width": 0.55, "points": 14, "step": 3.0,
		"wobble": 1.45, "freq": 7.5, "mote": Color(0.70, 0.84, 0.96, 0.70),
		"amount": 10, "mote_life": 0.46, "mote_speed": 15.0, "spread": 78.0,
	},
	"mob_bloom_seed": {
		"trail": Color(0.72, 0.26, 0.38, 0.78), "core": Color(0.94, 0.56, 0.62, 0.56),
		"width": 1.75, "core_width": 0.40, "points": 14, "step": 3.0,
		"wobble": 2.2, "freq": 12.0, "mote": Color(0.92, 0.42, 0.56, 0.88),
		"amount": 8, "mote_life": 0.44, "mote_speed": 17.0, "spread": 64.0,
	},
	"mob_plague_spore": {
		"trail": Color(0.54, 0.66, 0.14, 0.78), "core": Color(0.82, 0.88, 0.28, 0.54),
		"width": 2.0, "core_width": 0.45, "points": 13, "step": 3.1,
		"wobble": 1.55, "freq": 10.0, "mote": Color(0.72, 0.80, 0.20, 0.88),
		"amount": 11, "mote_life": 0.48, "mote_speed": 12.0, "spread": 92.0,
	},
}


static func hostile_art(enemy_kind: String) -> String:
	return String(ENEMY_PROJECTILE_ART.get(enemy_kind, "bolt"))


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
	var style_key: String = String(BOSS_PROJECTILE_STYLE.get(
		tex_name, MOB_PROJECTILE_STYLE.get(tex_name, tex_name)))
	var authored_mob := MOB_PROJECTILE_STYLE.has(tex_name)
	p.glow_color = MOB_PROJECTILE_GLOW.get(tex_name, GLOWS.get(style_key, Color(1, 1, 1)))

	# Every visual child rides in _vis so `rise` can lift the drawn shot to
	# hand height without moving the physics body (see the var's comment).
	var vis := Node2D.new()
	p._vis = vis
	p.add_child(vis)

	# Soft glow behind the bullet so it pops against any background.
	# Magic bolts burn hotter.
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	var hot := not authored_mob and style_key in ["fireball", "icelance", "shadowbolt", "stormbolt",
		"windslash", "rotbolt", "holybolt", "griefwave", "sigilbolt", "mage_firebolt",
		"mage_crystal_decree", "warlock_shadowbolt", "hellfire_brand_bolt"]
	glow.modulate = Art.hdr(Color(p.glow_color, 0.8 if hot else 0.6))
	glow.scale = Vector2(1.35, 1.35) if hot else Vector2(1.0, 1.0)
	if authored_mob:
		# A restrained backing glow keeps the MATERIAL silhouette legible;
		# particles/light would turn every distinct object back into an orb.
		var mob_motion: Dictionary = MOB_MOTION.get(tex_name, {})
		var mob_glow_alpha: float = float(mob_motion.get("glow_alpha", 0.40))
		var mob_glow_scale: float = float(mob_motion.get("glow_scale", 0.64))
		glow.modulate = Art.hdr(Color(p.glow_color, mob_glow_alpha), 1.1)
		glow.scale = Vector2.ONE * mob_glow_scale
	vis.add_child(glow)
	# A Court-lance begins beside the Archmage, where a 95px point light washes
	# her reflective body into a giant white bloom. Its sprite glow and authored
	# prism trail carry the flight cleanly without that generic caster washout.
	if hot and tex_name != "mage_crystal_decree":
		# Magic bolts CARRY light: walls and ground brighten as they pass
		# (scaled to the room's darkness — daylight mutes it).
		vis.add_child(Art.light(p.glow_color, 95.0, 0.85 * p.game.light_mult))

	# Fire magic trails sparks; ice trails frost; shadow trails void wisps.
	# Crystal Decree owns an authored multicolor ribbon. The generic magic-spark
	# emitter becomes oversized clutter while its visual origin folds in from a
	# floating Court focus, so let the crystal sheet and prism trail read cleanly.
	if hot and tex_name != "mage_crystal_decree":
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
			"stormbolt": Color(0.62, 0.9, 1.0),
			"windslash": Color(0.62, 1.0, 1.0),
			"rotbolt": Color(0.52, 0.9, 0.28),
			"holybolt": Color(1.0, 0.9, 0.42),
			"griefwave": Color(0.72, 0.82, 1.0),
			"sigilbolt": Color(0.86, 0.72, 1.0),
			"mage_firebolt": Color(1.0, 0.64, 0.18),
			"mage_crystal_decree": Color(0.78, 0.94, 1.0),
			"warlock_shadowbolt": Color(0.65, 0.32, 0.95),
			"hellfire_brand_bolt": Color(1.0, 0.24, 0.06),
		}.get(style_key, Color.WHITE)
		sparks.color = spark_col
		vis.add_child(sparks)

	# Arrows and knives streak: a thin motion trail behind the tip.
	# Knives read SHARP (round 26): longer, thinner streak, dimmer glow,
	# blade stretched along the flight line — a dart, not a glowstick.
	if style_key in ["arrow", "arrow_base", "arrow_frost", "arrow_void", "knife"]:
		var trail := Sprite2D.new()
		trail.texture = Art.tex("glow")
		trail.modulate = Color(p.glow_color, 0.4 if style_key.begins_with("arrow") else 0.5)
		trail.rotation = velocity.angle()
		trail.position = -velocity.normalized() * 15.0
		trail.scale = Vector2(1.6, 0.2) if style_key.begins_with("arrow") else Vector2(2.6, 0.12)
		vis.add_child(trail)
	if style_key == "knife":
		glow.modulate.a = 0.35
		glow.scale = Vector2(0.7, 0.7)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tex(tex_name)
	match tex_name:
		"arrow_base", "arrow_frost", "arrow_void", "arrow_void_eye":
			sprite.scale = Vector2.ONE
		"mage_firebolt", "warlock_shadowbolt":
			sprite.scale = Vector2(1.2, 1.2)
		"mage_void_bullet":
			# The Weaver-eye fires a compressed pin, never a hand-sized fireball.
			sprite.scale = Vector2(0.55, 0.55)
			glow.scale = Vector2(0.42, 0.42)
			glow.modulate = Art.hdr(Color(p.glow_color, 0.46), 1.15)
		"mage_crystal_decree":
			# The cast sheet assembles three shards; flight holds the locked verdict.
			sprite.hframes = 8
			sprite.frame = 7
			sprite.scale = Vector2(0.42, 0.42)
			glow.scale = Vector2(0.72, 0.72)
			glow.modulate.a = 0.62
		"hellfire_brand_bolt":
			sprite.scale = Vector2(0.84, 0.84)  # 30% smaller than the caster bolts
		"fx_boss_fire_comet":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_boss_frost_lance":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_boss_storm_javelin":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_boss_rot_spore":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_boss_earth_fang":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_boss_metal_crownshard":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_varo_reliquary_bolt":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_vess_griefwave":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_sexton_sigilbolt":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_veyx_windslash":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"fx_echo_knife":
			sprite.scale = Vector2.ONE * Balance.BOSS_PROJECTILE_ART_SCALE
		"knife": sprite.scale = Vector2(3.8, 2.1)
		"dart":
			# The assassin's thrown KUNAI (round 50): a sleek generated blade
			# (assets/sprites/dart.png, 64px tight-cropped) flying point-first
			# (rotation = velocity.angle() below), tinted by the knife-throw
			# variant via p.modulate, with the kit's _knife_glow halo behind it.
			# 0.4 holds the drawn length the 0.28 x 90px original established.
			sprite.scale = Vector2(0.4, 0.4)
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
	if authored_mob:
		sprite.scale = Vector2.ONE * Balance.MOB_PROJECTILE_ART_SCALE
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
	if tex_name in ["mage_void_bullet", "mage_crystal_decree"]:
		p._build_path_trail()
	elif authored_mob and DisplayServer.get_name() != "headless":
		# Headless test/dedicated processes have no rendered frame but would
		# still pay CPUParticles/Line2D simulation cost across whole chapters.
		p._build_mob_motion()
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
	_advance_visual_offset(delta)
	_tick_mob_motion(delta)
	_apply_rise()
	global_position += vel * delta
	_update_path_trail()
	if spr and anim_fps > 0.0 and anim_last >= anim_first:
		anim_clock += delta
		var count := anim_last - anim_first + 1
		spr.frame = anim_first + int(anim_clock * anim_fps) % count
	if spr and spin:
		if tex_kind == "knife":
			spr.rotation += 16.0 * delta   # thrown blades tumble end over end
		elif tex_kind == "shuriken":
			spr.rotation += 34.0 * delta   # a throwing star whirs fast on its axis
	life -= delta
	if life <= 0.0:
		_notify_visual_impact()
		_bloom()
		queue_free()


func _build_mob_motion() -> void:
	motion_profile = MOB_MOTION.get(tex_kind, {})
	if motion_profile.is_empty():
		return
	trail_max_points = int(motion_profile.get("points", 12))
	trail_min_step = float(motion_profile.get("step", 3.0))
	trail_fade_time = float(motion_profile.get("mote_life", 0.32))

	var trail_color: Color = motion_profile.get("trail", glow_color)
	path_trail = Line2D.new()
	path_trail.width = float(motion_profile.get("width", 1.8))
	path_trail.z_index = 4
	path_trail.antialiased = true
	var trail_gradient := Gradient.new()
	trail_gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	trail_gradient.colors = PackedColorArray([
		Color(trail_color, 0.0),
		Color(trail_color, trail_color.a * 0.34),
		trail_color,
	])
	path_trail.gradient = trail_gradient
	game.add_child(path_trail)

	var core_width := float(motion_profile.get("core_width", 0.0))
	if core_width > 0.0:
		var core_color: Color = motion_profile.get("core", Color.WHITE)
		path_core = Line2D.new()
		path_core.width = core_width
		path_core.z_index = 4
		path_core.antialiased = true
		var core_gradient := Gradient.new()
		core_gradient.offsets = PackedFloat32Array([0.0, 0.70, 1.0])
		core_gradient.colors = PackedColorArray([
			Color(core_color, 0.0),
			Color(core_color, core_color.a * 0.26),
			core_color,
		])
		path_core.gradient = core_gradient
		game.add_child(path_core)

	# World-space motes remain behind after emission. Keeping them outside the
	# projectile node lets the last few finish naturally after impact.
	motion_particles = CPUParticles2D.new()
	motion_particles.amount = int(motion_profile.get("amount", 8))
	motion_particles.lifetime = float(motion_profile.get("mote_life", 0.32))
	motion_particles.randomness = 0.72
	motion_particles.local_coords = false
	motion_particles.direction = -vel.normalized()
	motion_particles.spread = float(motion_profile.get("spread", 60.0))
	motion_particles.initial_velocity_min = float(motion_profile.get("mote_speed", 16.0)) * 0.45
	motion_particles.initial_velocity_max = float(motion_profile.get("mote_speed", 16.0))
	motion_particles.gravity = Vector2.ZERO
	motion_particles.scale_amount_min = 0.045
	motion_particles.scale_amount_max = 0.13
	motion_particles.texture = Art.tex("glow")
	var mote_color: Color = motion_profile.get("mote", trail_color)
	var mote_gradient := Gradient.new()
	mote_gradient.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
	mote_gradient.colors = PackedColorArray([
		Color(mote_color, 0.0),
		mote_color,
		Color(mote_color, 0.0),
	])
	motion_particles.color_ramp = mote_gradient
	motion_particles.z_index = 4
	game.add_child(motion_particles)
	motion_particles.global_position = _fx_pos()


func _tick_mob_motion(delta: float) -> void:
	if motion_profile.is_empty():
		return
	flight_phase += delta * float(motion_profile.get("freq", 10.0))
	var flight_dir := vel.normalized()
	flight_wobble = flight_dir.orthogonal() \
		* sin(flight_phase) * float(motion_profile.get("wobble", 0.0))
	if spr != null and is_instance_valid(spr):
		var bend := 0.0
		if tex_kind == "mob_blight_thorn":
			bend = cos(flight_phase * 0.82) * 0.105
		elif tex_kind in ["mob_bloom_seed", "mob_plague_spore", "mob_hush_wave"]:
			bend = cos(flight_phase * 0.72) * 0.045
		spr.rotation = flight_dir.angle() + bend
		if bool(motion_profile.get("pulse", false)):
			var pulse := 1.0 + 0.16 * sin(flight_phase)
			spr.modulate = Color(pulse, pulse, pulse, 1.0)
	if motion_particles != null and is_instance_valid(motion_particles):
		motion_particles.global_position = _fx_pos()
		motion_particles.direction = -flight_dir


## Eye and Court bolts leave one continuous authored path from their floating
## cast focus to the live projectile. Contact collapses the whole path at once
## instead of draining a short ribbon segment-by-segment.
func _build_path_trail() -> void:
	path_trail = Line2D.new()
	path_trail.width = 3.2 if tex_kind == "mage_crystal_decree" else 2.5
	path_trail.default_color = Color(1.0, 1.0, 1.0, 0.84) \
		if tex_kind == "mage_crystal_decree" else Color(0.54, 0.16, 0.92, 0.78)
	if tex_kind == "mage_crystal_decree":
		var prism := Gradient.new()
		prism.offsets = PackedFloat32Array([0.0, 0.34, 0.68, 1.0])
		prism.colors = PackedColorArray([
			Color(1.0, 0.46, 0.92, 0.88), Color(1.0, 0.82, 0.34, 0.88),
			Color(0.38, 0.96, 1.0, 0.88), Color(0.62, 0.48, 1.0, 0.88),
		])
		path_trail.gradient = prism
	path_trail.z_index = 4
	game.add_child(path_trail)
	path_core = Line2D.new()
	path_core.width = 0.75 if tex_kind == "mage_crystal_decree" else 0.85
	path_core.default_color = Color(0.96, 1.0, 1.0, 0.90) \
		if tex_kind == "mage_crystal_decree" else Color(0.92, 0.64, 1.0, 0.90)
	path_core.z_index = 4
	game.add_child(path_core)


func _update_path_trail() -> void:
	if path_closing or path_trail == null or not is_instance_valid(path_trail):
		return
	var at := _fx_pos()
	if not path_ready:
		path_ready = true
		path_start = at
		path_trail.add_point(at)
		if path_core != null and is_instance_valid(path_core):
			path_core.add_point(at)
		return
	# Preserve each bend made by homing variants. A two-point chord erased the
	# actual travelled route as soon as the needle curved toward its target.
	var last := path_trail.points[path_trail.points.size() - 1]
	if last.distance_to(at) >= trail_min_step:
		if tex_kind == "mage_void_bullet" and spr != null and is_instance_valid(spr):
			spr.rotation = (at - last).angle()
		path_trail.add_point(at)
		if path_core != null and is_instance_valid(path_core):
			path_core.add_point(at)
		if trail_max_points > 0:
			while path_trail.points.size() > trail_max_points:
				path_trail.remove_point(0)
			if path_core != null and is_instance_valid(path_core):
				while path_core.points.size() > trail_max_points:
					path_core.remove_point(0)


func _fade_path_trail() -> void:
	if path_closing:
		return
	path_closing = true
	for line in [path_trail, path_core]:
		if line != null and is_instance_valid(line):
			var fade: Tween = line.create_tween()
			fade.tween_property(line, "modulate:a", 0.0, trail_fade_time)
			fade.tween_callback(line.queue_free)
	if motion_particles != null and is_instance_valid(motion_particles):
		motion_particles.emitting = false
		var particles := motion_particles
		var settle: Tween = particles.create_tween()
		settle.tween_interval(particles.lifetime)
		settle.tween_callback(particles.queue_free)
	path_trail = null
	path_core = null
	motion_particles = null


func _notify_visual_impact() -> void:
	if visual_impact_sent:
		return
	visual_impact_sent = true
	visual_impact.emit()
	_fade_path_trail()


func _exit_tree() -> void:
	_fade_path_trail()


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
	return global_position + Vector2(0, -rise) + visual_offset + flight_wobble


## A quick expanding shockwave where a magic bolt lands.
## Darts get a smaller, snappier ring so fan-of-knives hits register
## even when the flight itself was too short to see (round 31).
func _impact_ring() -> void:
	var style_key: String = String(BOSS_PROJECTILE_STYLE.get(tex_kind, tex_kind))
	if not style_key in ["fireball", "icelance", "shadowbolt", "stormbolt",
		"windslash", "rotbolt", "earthshard", "metalshard", "holybolt",
		"griefwave", "sigilbolt", "dart"]:
		return
	var small := style_key == "dart"
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


## Skin-owned Mage projectile contacts. These are deliberately geometric and
## brief: the projectile sheet carries the flight identity, while contact
## completes its story without falling back to the shared magic ring.
func _mage_skin_impact() -> void:
	if tex_kind != "mage_crystal_decree":
		return
	var at := _fx_pos()
	# A precise six-sided crack reads as a sentence stamped into the target.
	for i in 6:
		var edge := Line2D.new()
		var ang := TAU * float(i) / 6.0
		var inner := at + Vector2.from_angle(ang) * 5.0
		var elbow := at + Vector2.from_angle(ang + (0.16 if i % 2 == 0 else -0.16)) * 16.0
		var outer := at + Vector2.from_angle(ang) * 28.0
		edge.points = PackedVector2Array([inner, elbow, outer])
		edge.width = 1.5
		edge.default_color = Color(0.82, 0.96, 1.0, 0.9)
		edge.z_index = 9
		game.add_child(edge)
		var fade_edge := edge.create_tween()
		fade_edge.tween_interval(0.06)
		fade_edge.tween_property(edge, "modulate:a", 0.0, 0.18)
		fade_edge.tween_callback(edge.queue_free)


func _on_body_entered(body: Node) -> void:
	if net_visual:
		# MP-10 visual copy: burst where the real one bites, never damage
		# (the real hit arrives as its own RPC on the authority's side).
		if friendly and body is Enemy:
			if _already_hit.has(body):
				return
			_already_hit[body] = true
			_notify_visual_impact()
			game.burst(_fx_pos(), glow_color, 5)
			_frost_arrow_impact()
			_mage_skin_impact()
			_impact_ring()
			if not pierce:
				queue_free()
		elif not friendly and body is Player:
			_notify_visual_impact()
			game.burst(_fx_pos(), glow_color, 5)
			queue_free()
		elif body is StaticBody2D:
			_notify_visual_impact()
			game.burst(_fx_pos(), Color(glow_color, 0.5), 3)
			queue_free()
		return
	if friendly and body is Enemy:
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		_notify_visual_impact()
		game.burst(_fx_pos(), glow_color, 5)
		_frost_arrow_impact()
		_mage_skin_impact()
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
		_notify_visual_impact()
		game.burst(_fx_pos(), glow_color, 5)
		var shooter: Node = source_enemy if is_instance_valid(source_enemy) else null
		body.take_damage(dmg, hostile_type, shooter)
		# Webber's snare shot (mob mechanic): roots the player on hit —
		# the dodge is denied for a beat so an ally's pounce can land.
		if root_dur > 0.0 and body.has_method("apply_root"):
			body.apply_root(root_dur)
		queue_free()
	elif body is StaticBody2D:
		_notify_visual_impact()
		game.burst(_fx_pos(), Color(glow_color, 0.5), 3)
		if friendly:
			_mage_skin_impact()
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
