class_name Enemy extends CharacterBody2D
## A basic monster. Stats come from Story.ENEMIES, so one script
## covers wolves, spiders, cultists and skeletons.
## Supports status effects: stun, slow, burn, and vulnerability (Death Mark).

var game: Game
var kind := "wolf"
var display_name := "Monster"
var level := 1
var max_hp := 30.0
var hp := 30.0
var dmg := 8.0
var speed := 150.0
var xp_value := 12
var gold_value := 4
var ranged := false
# Combat substats (see Stats for the curves). ALL of them scale with
# level via the monster's attribute build (Story.enemy_stats_at).
var physres := 0.0
var magres := 0.0
# Flat, pen-proof damage reduction applied AFTER resists in take_damage —
# a hard armor wall no build shortcuts (Cinderhide's obsidian plating sets
# it to ~0.82; every other enemy leaves it 0.0). NOT the res/(res+120)
# curve: that saturates at 0.80 and penetration erodes it.
var plate_dr := 0.0
var eva := 0.0
var critres := 0.0
var crit := 0.0     # chance this enemy's hits crit (x1.5, vs player critres)
var dex := 0.0      # shaves the player's evasion before the dodge roll
var physpen := 0.0  # eats player resistance (excess -> bonus damage)
var magpen := 0.0
var dmg_type := "phys"  # what this enemy's attacks count as

var elite := false     # miniboss variant: bigger, meaner, loot pinata, NO xp
var untargetable := false  # burrowed/submerged boss phase: no damage, no auto-aim
var aggro_range := 330.0
var attack_cd := 0.0
var windup := 0.0     # yellow-flash wind-up before a melee bite lands
var zone_idx := -1    # which room's clear-count this enemy belongs to
var pack_id := 0      # aggro group within the room (per-pack aggro)
var force_aggro := false  # pack woken: attack no matter the distance
var alerted := false  # has shown its "!" bubble
var los_lost_t := 0.0    # seconds since we last had line-of-sight (leash timer)
var last_seen := Vector2.ZERO  # where the player was last visible (blind-chase point)
var hazard_speed := 1.0  # terrain patch effect (ice boosts, void slows)
# --- targeting seam (MP phase 0, MULTIPLAYER.md §5.2) ---
# AI reads its prey from a per-enemy TARGET resolved via game.pick_target()
# (v1: nearest living player) on a sticky cadence (Balance.MOB_RETARGET_EVERY,
# plus immediately when the target dies/frees) — never per-frame, so future
# packs won't oscillate between players. Solo: always the one player, so
# behavior is bit-identical with the old direct game.player reads.
var target: Player = null
var retarget_t := 0.0
# --- net mirror (MP-09) ---
# Solo stays inert by construction: net_id stays 0, net_mirror stays
# false, and every hook below is gated on them plus game.net_host() —
# zero new behavior offline.
var net_id := 0            # session-unique id the HOST stamps at spawn (0 = unannounced)
var net_mirror := false    # guest-side presentation clone: no AI, no damage, no collision
var net_target := Vector2.ZERO  # last snapshot position (mirrors chase it)
var net_walk := false      # last snapshot "moving" flag (drives the walk/idle strip)
# MP-10 combat tell (Wave-2 co-op fix #2): the host broadcasts each trait-window
# tint (bite windup, pounce crouch, guard, reflect) so a guest reads the same
# warning its sim aims — a mirror shows the tint for the window, then reverts to
# base_mod exactly like the host (a hit-flash may stomp it early on BOTH sides).
var _net_tell_t := 0.0     # mirror: seconds of tell tint left (drives the revert)
# MP-10: the striking PLAYER for the current take_damage call — hit_enemy
# sets it before every player hit, and the host's hit RPC sets the guest's
# shell. Captured-and-cleared at the top of take_damage; solo it always
# resolves to THE player, so reflect/counter/aggro reads are bit-identical.
var hit_src: Player = null
# MP-10: squelch the mirror status forward while apply_toxin calls
# apply_burn internally — one "toxin" event carries both to the host.
var _status_mute := false
# Animation seam (Track C): >1 when an _anim strip override is installed.
var anim_frames := 0
var anim_fps := 6.0
var anim_t := 0.0
# Walk/idle split: swap strips on movement when a _walk strip exists.
var _strip_idle := {}
var _strip_walk := {}
var _strip_walking := false
# One-shot ability strip (Track C round 3): plays through once on a boss
# cast, then reverts to idle/walk. Empty when nothing is playing.
var _strip_action := {}
var _action_t := 0.0
# 8-direction ability strip: when assets/sprites/<sprite>_<action>_<dir>.png
# exists, the facing is LOCKED at the moment the action fires (an attack
# shouldn't rotate mid-swing) and that direction's strip plays through.
var _action_dir := {}   # the dir set for the running action, {} if flat
var _sprite_key := ""   # stats["sprite"] kept for action-strip lookups
var _moving_anim := false  # hysteretic "moving" for walk/idle swap + bob
var _face_vx := 0.0        # low-passed velocity.x for jitter-free facing
var art_scale := 1.0
var knock := Vector2.ZERO
var home := Vector2.ZERO
var sprite: Sprite2D
# Resting body tint (def "tint" key, e.g. void_shade's value-floor lift —
# art audit 2026-07-10: the shade vanished on dark ground). Every place
# that used to reset the body to plain white must reset HERE instead, or
# a single hit flash strips the identity tint for good.
var base_mod := Color(1, 1, 1)
var hp_bar_bg: ColorRect
var hp_bar_fg: ColorRect
var hp_bar_cap: ColorRect  # 1px darker end-cap: the remaining-HP edge stays crisp
var face_left := false  # sprite art natively faces left (Crawl tiles)
# 8-DIRECTION render (art audit 2026-07-10 seam): populated only when
# assets/sprites/<sprite>_anim_<dir>.png exists. Empty for every
# single-facing mob, which keeps the flip path below untouched.
var _dir_idle := {}     # {DIR8 suffix: strip_info} for idle, or {}
var _dir_walk := {}     # {DIR8 suffix: strip_info} for walk, or {}
var _cur_dir := "s"     # current facing suffix while directional
var _body_cell := 0.0   # square idle/walk cell px; oversized ability strips scale off it
var hover_amp := 0.0    # >0 = levitate: idle/glide floats instead of grounding
var dying := false

# --- status effects ---
var stun_time := 0.0
var slow_time := 0.0
var slow_mult := 1.0
var burn_time := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var burn_color := Color(1.4, 0.8, 0.6)  # orange = fire, green = poison
var burn_src: Player = null   # who applied the burn (MP: ticks crit off THEIR sheet)
var bleed_time := 0.0  # Wind Cuts (mage): a red physical DoT, kept apart from burn
var bleed_dps := 0.0
var bleed_tick := 0.0
var bleed_src: Player = null  # who opened the wound (same source rule as burn)
var vuln_time := 0.0   # takes extra damage while marked
var vuln_mult := 1.5   # the marked multiplier (Death Mark default +50%; shadow's ult sets +40%)
var hobble_t := 0.0    # HOBBLED: a slow that failed on a CC-immune boss
                       # scuffs its footing — +HOBBLE_MULT damage taken
var toxin := 0         # green-DoT stacks: deepen the burn TICK (die with it)
var brittle := 0       # ice stacks: ice hits bite harder per stack
var brittle_t := 0.0
var crush_t := 0.0     # recently displaced hard: void hits bite (crush window)

# --- identity traits (data: kind's ENEMIES "traits"; tuning: Balance) ---
# The mob-mechanic vocabulary (2026-07-07 redesign): each is a real
# decision, not a stat check, and most reuse an existing system (root,
# status, hazards, shields, displacement). Behavior below; per-chapter
# escalation in the ENEMIES "traits" fields.
var traits := {}       # trait name -> true
var strafe_sign := 1.0 # skirmish: which way the retreat arcs (rolled at setup)
# pounce (overshoot gap-closer)
var pounce_cd := 0.0
var pounce_time := 0.0
var pounce_windup := 0.0
var pounce_dir := Vector2.ZERO
var pounce_whiff := 0.0   # >0 = it overshot; stunned-vulnerable window
# web (root shot), channel_heal, spawner, snare, reflect, counter cooldowns
var web_cd := 0.0
var channel_cd := 0.0
var channel_t := 0.0      # >0 = mid-heal-channel (stands still, breakable)
var channel_beam: Line2D = null
var spawn_cd := 0.0
var snare_cd := 0.0
var reflect_cd := 0.0
var reflect_t := 0.0      # >0 = shield up, damage bounces back
var counter_t := 0.0      # >0 = guard raised; hitting it staggers the player
var counter_cd := 0.0
var sow_t := 0.0          # hazard-trail drip throttle
var mob_blink_cd := 0.0
# baseline modifiers
var mend_rate := 0.0
var mend_fx_t := 0.0
var ward_broken := false  # warded: the guard has been shattered (stays down)
# tether (linked pair)
var tether_partner: Enemy = null
var tether_line: Line2D = null

# Player-facing trait blurbs (codex reads this).
const TRAIT_DESC := {
	"pounce":  "Pounces — a telegraphed leap that OVERSHOOTS. Sidestep the crouch and it sails past, exposed.",
	"web":     "Webs — its shot ROOTS you for a beat. Watch for a pounce to follow.",
	"channel_heal": "Mends the faithful — heals allies only while CHANNELING (green beam, stands still). Interrupt it: hit it, or break line of sight.",
	"warded":  "Guarded — nibbling barely dents it; a REAL blow shatters the guard for good. A crit, a heavy hit, or any status (burn, stun, slow, expose) all crack it.",
	"bloat":   "Bloated — BURSTS into a lingering blight pool when slain. Kill it at range, or move.",
	"martyr":  "Martyr — its death-wail HEALS and enrages nearby allies. Kill it LAST, or alone.",
	"reflect": "Wardsmith — raises a shield that REFLECTS your damage back (telegraphed pulse). Pause your fire until it drops.",
	"sower":   "Sower — leaves a trail of burning ground as it moves. Don't chase through its wake.",
	"frost_aura": "Frostbound — a chilling aura DRAGS at your feet while you're near. Give it space.",
	"snare":   "Snares — marks the ground; caught in the open when it closes, you FREEZE.",
	"spawner": "Broodmother — sprouts fresh spawn until you cut her down.",
	"tether":  "Tethered — linked to its twin; the bond BURNS you, and one dies but the bond revives it unless BOTH fall together.",
	"blinker": "Blinks — flickers out of reach, then reappears on top of you. Un-targetable mid-blink.",
	"skirmish": "Skirmisher — retreats as fast as you advance, peppering you on the move. CORNER it against a wall, or answer in kind.",
	"counter": "Warder — raises a GUARD; strike it while raised and it staggers YOU. Wait the guard out.",
	"mend":    "Knits — slowly heals its own wounds; burst it down.",
	"frenzy":  "Frenzied — wounded, it strikes faster and harder.",
	"swift":   "Swift — quicker on its feet than its kin.",
}


static func make(game_node: Node2D, enemy_kind: String, pos: Vector2, at_level := -1) -> Enemy:
	var e := Enemy.new()
	e._setup(game_node, enemy_kind, pos, at_level)
	return e


func _ready() -> void:
	# MP-09: every enemy that enters the HOST's tree is announced to the
	# session HERE — one choke point under add_enemy, boss spawns, trait
	# summons and dev spawns alike (they all add_child eventually).
	# Mirrors and solo skip; net_id stays 0 offline.
	if not net_mirror and game != null and game.net_host():
		game.net_session().host_register_enemy(self)


func _setup(game_node: Node2D, enemy_kind: String, pos: Vector2, at_level := -1) -> void:
	game = game_node
	kind = enemy_kind
	var stats: Dictionary = _stats_for(enemy_kind)
	display_name = stats["name"]
	# Stats scale with the monster's LEVEL and its per-kind growth rates.
	# The listed level is a MINIMUM (no downscaling): asking for less
	# clamps UP — the monster arrives at its anchor, stats as-is.
	var want: int = at_level if at_level > 0 else int(stats.get("level", 1))
	var scaled := _stats_at(enemy_kind, want)
	level = scaled["level"]
	max_hp = scaled["hp"]
	hp = max_hp
	dmg = scaled["dmg"]
	speed = stats["speed"]
	xp_value = scaled["xp"]
	gold_value = scaled["gold"]
	ranged = stats["ranged"]
	physres = scaled["physres"]
	magres = scaled["magres"]
	eva = scaled["eva"]
	critres = scaled["critres"]
	crit = scaled["crit"]
	dex = scaled["dex"]
	physpen = scaled["physpen"]
	magpen = scaled["magpen"]
	dmg_type = stats.get("dmg_type", "phys")
	# Identity traits (2026-07-07 redesign): each kind's mechanic. Read
	# into a set; a few configure stats up front, most stagger their
	# first cooldown so a pack doesn't act in lockstep.
	for t in stats.get("traits", []):
		traits[String(t)] = true
	if traits.has("swift"):
		speed *= Balance.MOB_SWIFT_SPEED
	if traits.has("mend"):
		mend_rate = Balance.MOB_MEND_RATE
	strafe_sign = 1.0 if randf() < 0.5 else -1.0  # skirmish arc direction
	pounce_cd = randf_range(1.0, Balance.MOB_LUNGE_CD)
	web_cd = randf_range(1.5, Balance.MOB_WEB_CD)
	channel_cd = randf_range(1.0, Balance.MOB_CHANNEL_CD)
	spawn_cd = Balance.MOB_SPAWN_CD
	snare_cd = randf_range(2.0, Balance.MOB_SNARE_CD)
	reflect_cd = randf_range(2.5, Balance.MOB_REFLECT_CD)
	counter_cd = randf_range(1.5, Balance.MOB_COUNTER_CD)
	mob_blink_cd = randf_range(1.5, Balance.MOB_BLINK_CD)
	global_position = pos
	home = pos
	anim_t = randf() * 10.0
	add_to_group("enemies")

	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0 * stats["scale"] * 0.7
	cs.shape = shape
	add_child(cs)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(stats["scale"] * 0.75, stats["scale"] * 0.75)
	shadow.position = Vector2(0, 6.0 * stats["scale"])
	add_child(shadow)

	sprite = Sprite2D.new()
	art_scale = float(stats["scale"])
	_sprite_key = stats["sprite"]
	var anim := Art.anim_info(stats["sprite"])
	if anim.is_empty():
		sprite.texture = Art.tex(stats["sprite"])
		sprite.scale = Art.scale_for(sprite.texture, art_scale)
	else:
		# Animated override strip (Track C seam): same Sprite2D, hframes on.
		_strip_idle = anim
		_strip_walk = Art.walk_info(stats["sprite"])
		# 8-direction sets, if the art exists (else {} -> flip path stays).
		# A directional asset also ships flat _anim/_walk strips (a south
		# copy), so setup + the net mirror keep working on the flat strip.
		_dir_idle = Art.dir_set(String(stats["sprite"]) + "_anim")
		_dir_walk = Art.dir_set(String(stats["sprite"]) + "_walk")
		_apply_strip(anim)
	face_left = Art.faces_left(stats["sprite"])
	# Identity tint from the def ("tint" key): the resting body color all
	# flash resets return to (see base_mod above).
	var def_tint: Variant = stats.get("tint")
	if def_tint is Color:
		base_mod = def_tint
	sprite.modulate = base_mod
	add_child(sprite)

	# Tiny HP bar above the head, shown once the monster is damaged.
	# Near-opaque bg = a full 1px dark outline all round the 4px fill, so
	# the bar reads on ANY terrain (art audit 2026-07-10: the old 3px fill
	# in a 70%-alpha bg collapsed to a 1px sliver on bright ground).
	var bar_y: float = -8.0 * stats["scale"] - 8.0
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.04, 0.03, 0.04, 0.95)
	hp_bar_bg.position = Vector2(-16, bar_y - 1)
	hp_bar_bg.size = Vector2(32, 6)
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)
	hp_bar_fg = ColorRect.new()
	hp_bar_fg.color = Color(0.9, 0.25, 0.2)
	hp_bar_fg.position = Vector2(-15, bar_y)
	hp_bar_fg.size = Vector2(30, 4)
	hp_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_fg.visible = false
	add_child(hp_bar_fg)
	hp_bar_cap = ColorRect.new()
	hp_bar_cap.color = Color(0.5, 0.10, 0.08)
	hp_bar_cap.position = Vector2(-15 + 29, bar_y)
	hp_bar_cap.size = Vector2(1, 4)
	hp_bar_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_cap.visible = false
	add_child(hp_bar_cap)

	# Kill-priority mobs wear a colored RING underfoot — the same "this
	# one's special" language as the elite gold ring, so priority reads at
	# a glance (a child sprite survives the white damage flashes).
	# Green = channel-healer / martyr (support you focus); the ward
	# shimmer and reflect shield are drawn live in their own windows.
	var ring_col := Color(0, 0, 0, 0)
	if traits.has("channel_heal") or traits.has("martyr") or traits.has("spawner"):
		ring_col = Color(0.35, 1.0, 0.45, 0.85)   # green: support / brood
	if ring_col.a > 0.0:
		var ring := Sprite2D.new()
		ring.texture = Art.tex("ring")
		ring.modulate = ring_col
		ring.position = Vector2(0, 14)
		ring.scale = Vector2(1.5, 0.85)
		ring.z_index = -1
		add_child(ring)


## Stat lookup, overridable so chapter-content monsters (see Boss's
## Chapter 2 block + content/ch2_bosses.gd) can resolve outside
## Story.ENEMIES until T0's content registry lands.
func _stats_for(k: String) -> Dictionary:
	return Story.ALL_ENEMIES[k]  # base table + registered content modules


func _stats_at(k: String, lvl: int) -> Dictionary:
	return Story.enemy_stats_at(k, lvl)


## 2D facing vector for 8-direction art: toward the prey when engaged
## (target-first, like the flip logic), else the current movement. Near-
## still returns ZERO so an idle mob rests facing the camera (south).
func _facing_vec() -> Vector2:
	var tgt: Player = _get_target()
	if (alerted or force_aggro) and tgt != null and not tgt.dead:
		return tgt.global_position - global_position
	if velocity.length() > 20.0:
		return velocity
	return Vector2.ZERO


## Point the Sprite2D at an idle/walk strip (hframes + normalized scale).
func _apply_strip(info: Dictionary) -> void:
	sprite.texture = info["tex"]
	var frames := int(info["frames"])
	sprite.hframes = frames
	sprite.frame = 0
	anim_frames = frames
	# A square strip (idle/walk) DEFINES the body reference cell. An ability
	# strip may ship a LARGER cell (wider and/or taller) to fit a swung/raised
	# weapon that reaches past the idle silhouette — it still renders at the
	# SAME body scale off that reference (so the boss neither shrinks nor
	# clips), with the sprite re-anchored so the feet stay put.
	var cw := float(sprite.texture.get_width()) / maxf(1.0, float(frames))
	var chh := float(sprite.texture.get_height())
	if absf(chh - cw) < 1.0:
		_body_cell = cw
	var ref := _body_cell if _body_cell > 0.0 else cw
	var s := art_scale * 16.0 / ref
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(0, -(chh - ref) / 2.0)


## Play a one-shot ability strip once, then fall back to idle/walk. No-op
## unless the boss has an idle strip AND assets/sprites/<sprite>_<action>.png
## exists — so ability code can call it unconditionally and it lights up
## when the art lands. Re-triggering restarts the strip from frame 0.
func play_action(action: String) -> void:
	# MP-09: when hosting, the one-shot rides to every guest mirror as an
	# event RPC — wired at the DEFINITION so all ~91 boss call sites
	# broadcast for free. It precedes the art checks: both sides ship the
	# same assets, so each machine resolves the strip locally.
	if net_id > 0 and not net_mirror and game != null and game.net_host():
		game.net_session().host_enemy_action(net_id, action)
	if _strip_idle.is_empty():
		return
	# Try the exact action strip; a boss with only its ONE signature clip
	# installed routes every named move (slam/toll/bolt/...) to "<key>_ability"
	# so all ~90 call sites light up from a single generated gesture.
	if _try_action_strip(action):
		return
	_try_action_strip("ability")


## Point the one-shot strip at <key>_<action> if that art exists. Prefers
## the 8-direction set (facing locked at trigger); falls back to a flat
## strip (L/R flip). Returns true if a strip was found and started.
func _try_action_strip(action: String) -> bool:
	var dset := Art.dir_set("%s_%s" % [_sprite_key, action])
	if not dset.is_empty():
		_action_dir = dset
		var suf := Art.dir8_suffix(_facing_vec())
		_strip_action = dset[suf]
		_action_t = 0.0
		_apply_strip(_strip_action)
		sprite.flip_h = false
		return true
	var info := Art.action_info(_sprite_key, action)
	if info.is_empty():
		return false
	_strip_action = info
	_action_dir = {}
	_action_t = 0.0
	_apply_strip(info)
	return true


## Re-point this enemy at a DIFFERENT sprite key mid-fight (Saint Varo's
## throne -> standing phase-swap). Re-runs the same idle/walk/8-dir setup
## make() does, so the render path picks the new strips up on the next
## frame. Any in-flight ability strip is dropped so the new idle takes over.
func swap_sprite(new_key: String) -> void:
	if _sprite_key == new_key:
		return
	_sprite_key = new_key
	_strip_action = {}
	_action_dir = {}
	_strip_walking = false
	_cur_dir = "s"
	var anim := Art.anim_info(new_key)
	if anim.is_empty():
		_strip_idle = {}
		_strip_walk = {}
		_dir_idle = {}
		_dir_walk = {}
		sprite.texture = Art.tex(new_key)
		sprite.scale = Art.scale_for(sprite.texture, art_scale)
	else:
		_strip_idle = anim
		_strip_walk = Art.walk_info(new_key)
		_dir_idle = Art.dir_set(new_key + "_anim")
		_dir_walk = Art.dir_set(new_key + "_walk")
		_apply_strip(anim)
	face_left = Art.faces_left(new_key)


## Saint Varo's throne <-> standing phase-swap, driven purely off hp
## fraction so the host and every guest mirror flip at the SAME moment
## with no extra RPC. Throne (the seated skeletal saint) LEVITATES; at 25%
## he RISES for the first time in sixty years — swap to the standing body
## that walks, feet on the ground. One-way; once risen the guard is inert.
func _varo_phase_sprite() -> void:
	if _sprite_key != "saint_varo":
		return
	hover_amp = 7.0
	if hp <= max_hp * 0.25:
		swap_sprite("saint_varo_standing")
		hover_amp = 0.0


## Wave-2 co-op fix #2: broadcast a combat-tell tint to every guest mirror.
## The host already set sprite.modulate itself at the call site (bite windup,
## pounce crouch, guard, reflect); this fans the SAME color+window so a guest
## sees the warning before firing into a counter/reflect. No-op solo / on a
## mirror — wired exactly like play_action, so the tell rides for free.
func _net_tell(color: Color, dur: float) -> void:
	if net_id > 0 and not net_mirror and game != null and game.net_host():
		game.net_session().host_enemy_tell(net_id, color, dur)


## Return from a one-shot ability strip to idle (the walk swap re-evaluates
## next frame). Frame filtering keeps it out of the physics-flush path.
func _end_action() -> void:
	_strip_action = {}
	_action_dir = {}
	_action_t = 0.0
	_strip_walking = false
	_cur_dir = ""  # force the idle path to re-pick a directional strip next frame
	if not _strip_idle.is_empty():
		_apply_strip(_strip_idle)


func _physics_process(delta: float) -> void:
	if dying:
		return
	# Only occupied rooms simulate: monsters elsewhere stand frozen
	# (zone_idx -1 — test dummies, boss adds, event spawns — always runs).
	# MP §4.3: active_rooms is the union of every player's room — solo it
	# is exactly {cur_room}, so this is the old gate to the frame.
	if zone_idx >= 0 and not game.active_rooms.has(zone_idx):
		return
	# MP-09: mirrors are presentation clones — the sim lives on the host.
	# They chase the ~20 Hz snapshot and run the strip clock; nothing
	# below (AI, statuses, windups, contact damage) may run on one.
	if net_mirror:
		_net_mirror_tick(delta)
		return
	anim_t += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	# Sticky re-target (MP seam): re-pick the prey on a slow cadence;
	# _get_target() re-resolves immediately if it dies/frees in between.
	retarget_t -= delta
	if retarget_t <= 0.0:
		retarget_t = Balance.MOB_RETARGET_EVERY
		target = game.pick_target(self)
	if not traits.is_empty():
		_tick_traits(delta)

	# --- status effects tick ---
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	vuln_time = maxf(0.0, vuln_time - delta)
	if vuln_time <= 0.0:
		vuln_mult = 1.5   # reset to the default so a later Exposed doesn't inherit shadow's leaner amp
	hobble_t = maxf(0.0, hobble_t - delta)
	brittle_t = maxf(0.0, brittle_t - delta)
	if brittle_t <= 0.0:
		brittle = 0
	crush_t = maxf(0.0, crush_t - delta)
	# A shove/pull harder than ordinary hit-flinch opens a crush window.
	if knock.length() >= Balance.CRUSH_MIN_KNOCK:
		crush_t = Balance.CRUSH_WINDOW
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			var tick := burn_dps * 0.5
			# DoT ticks CRIT: rolled per tick on the SOURCE player's SHEET
			# crit (burn_src, captured when the burn was applied; solo
			# fallback: THE player — identical, there is only one), shaved
			# by this target's critres like any hit. Per-ability crit
			# bonuses never ride into ticks, and nothing snapshots — no
			# fishing for a locked-in crit burn.
			var src: Player = burn_src if burn_src != null and is_instance_valid(burn_src) else game.player
			if src != null and randf() < Stats.crit_curve(src.crit) * (1.0 - Stats.res_frac(critres * 6.0)):
				tick *= src.crit_dmg
			take_damage(tick, Vector2.ZERO, false, true)
			if not dying:
				sprite.modulate = burn_color
	else:
		toxin = 0  # the stack dies with the burn

	if bleed_time > 0.0:
		# Wind Cuts bleed — a red physical DoT, independent of burn so it
		# never reads as "on fire" and never collides with a burn tick.
		bleed_time -= delta
		bleed_tick -= delta
		if bleed_tick <= 0.0:
			bleed_tick = 0.5
			var btick := bleed_dps * 0.5
			var bsrc: Player = bleed_src if bleed_src != null and is_instance_valid(bleed_src) else game.player
			if bsrc != null and randf() < Stats.crit_curve(bsrc.crit) * (1.0 - Stats.res_frac(critres * 6.0)):
				btick *= bsrc.crit_dmg
			take_damage(btick, Vector2.ZERO, false, true)
			if not dying:
				sprite.modulate = Color(1.5, 0.35, 0.4)  # crimson wound flash

	if stun_time > 0.0:
		windup = 0.0
		sprite.modulate = base_mod
		velocity = knock
		move_and_slide()
		return

	# Bite wind-up: the monster flashes yellow, then snaps. Gives the
	# player a beat to dodge or knock it back — readable combat.
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			sprite.modulate = base_mod
			var player: Player = _get_target()
			if player and not player.dead and global_position.distance_to(player.global_position) < 64.0:
				player.take_damage(_hit_dmg(), dmg_type, self)
		velocity = knock
		move_and_slide()
		return

	var move := _think(delta)
	if slow_time > 0.0:
		move *= slow_mult
	move *= hazard_speed  # ice patches boost, void rifts slow

	velocity = move + knock + game.gust_vec
	move_and_slide()
	# Moving-for-animation is HYSTERETIC: post-slide velocity wedged against
	# a wall hovers right at the threshold, and a bare `> 20` there would
	# toggle the walk/idle swap + bob every frame (visible jitter). Latch
	# with a dead band instead.
	var spd := velocity.length()
	if _moving_anim and spd < 12.0:
		_moving_anim = false
	elif not _moving_anim and spd > 34.0:
		_moving_anim = true
	if not _strip_action.is_empty():
		# One-shot ability strip: play frames 0..N-1 once, then revert.
		_action_t += delta
		var idx := int(_action_t * anim_fps)
		if idx >= anim_frames:
			_end_action()
		else:
			sprite.frame = idx
	elif anim_frames > 1 or not _dir_idle.is_empty():
		# Walk/idle split. Single-facing art keeps the flip path; 8-direction
		# art also picks the strip by facing — and runs even for 1-frame idle
		# rotations (PixelLab's static rotations are one frame per direction).
		if _dir_idle.is_empty():
			if not _strip_walk.is_empty() and _moving_anim != _strip_walking:
				_strip_walking = _moving_anim
				_apply_strip(_strip_walk if _moving_anim else _strip_idle)
			if _moving_anim:
				anim_t += delta
			sprite.frame = int(anim_t * anim_fps) % anim_frames
		else:
			# Pick the strip for facing + walk state; swap only when one
			# changes (the frame clock keeps running — _apply_strip's frame=0
			# is overwritten on the next line).
			var nd := Art.dir8_suffix(_facing_vec())
			var dset: Dictionary = _dir_walk if (_moving_anim and not _dir_walk.is_empty()) else _dir_idle
			if nd != _cur_dir or _moving_anim != _strip_walking:
				_cur_dir = nd
				_strip_walking = _moving_anim
				_apply_strip(dset[nd])
			if _moving_anim:
				anim_t += delta
			sprite.frame = int(anim_t * anim_fps) % anim_frames
			sprite.flip_h = false
	# ORIENTATION mirrors the hero's target-first logic (player.gd): an
	# engaged enemy faces its PREY, not its slide/velocity — otherwise a
	# melee attacker that stops to swing (move == 0, e.g. Korrag) keeps
	# whatever way it last drifted and looks the wrong way mid-attack. Commit
	# to the player's horizontal side within the aim cone; fall back to a
	# LOW-PASSED velocity (jitter-free) when unaggroed or the target is
	# overhead. Left-facing art (Crawl sprites) flips the opposite way.
	_face_vx = lerpf(_face_vx, velocity.x, 0.2)
	var os := 0.0
	var tgt: Player = _get_target()
	if (alerted or force_aggro) and tgt != null and not tgt.dead:
		var tx := tgt.global_position.x - global_position.x
		var ty := tgt.global_position.y - global_position.y
		if absf(tx) > absf(ty) * Balance.AIM_VERTICAL_CONE:
			os = signf(tx)
	if os == 0.0 and absf(_face_vx) > 8.0:
		os = signf(_face_vx)
	# Directional locomotion encoded facing in its chosen strip (flip_h
	# false); apply the horizontal flip only for single-facing art, or
	# while a single-facing one-shot action strip is playing.
	if os != 0.0 and _action_dir.is_empty() and (_dir_idle.is_empty() or not _strip_action.is_empty()):
		sprite.flip_h = (os > 0.0) if face_left else (os < 0.0)
	# Little walk bob so they feel alive; hover_amp>0 levitates instead (Varo throne).
	if hover_amp > 0.0:
		sprite.position.y = -hover_amp + sin(anim_t * 2.2) * (hover_amp * 0.4)
	elif _moving_anim:
		sprite.position.y = -absf(sin(anim_t * 10.0)) * 2.5
	else:
		sprite.position.y = 0.0


## MP-09: per-frame mirror upkeep — chase the last snapshot position
## (simple exponential smoothing; enemies tolerate far simpler
## interpolation than the player's two-snapshot buffer) and run the
## same strip playback the live path uses (one-shot action strips,
## walk/idle swap at the snapshot's walk flag, the little bob).
func _net_mirror_tick(delta: float) -> void:
	global_position = global_position.lerp(net_target, minf(1.0, delta * 10.0))
	if not _strip_action.is_empty():
		_action_t += delta
		var idx := int(_action_t * anim_fps)
		if idx >= anim_frames:
			_end_action()
		else:
			sprite.frame = idx
	elif anim_frames > 1:
		if not _strip_walk.is_empty() and net_walk != _strip_walking:
			_strip_walking = net_walk
			_apply_strip(_strip_walk if net_walk else _strip_idle)
		# The live path ticks anim_t once per frame plus once more while
		# moving — 1x idle, 2x walking. Same clock here.
		anim_t += delta * (2.0 if net_walk else 1.0)
		sprite.frame = int(anim_t * anim_fps) % anim_frames
	_varo_phase_sprite()  # guests flip throne->standing off replicated hp
	if hover_amp > 0.0:
		sprite.position.y = -hover_amp + sin(anim_t * 2.2) * (hover_amp * 0.4)
	elif net_walk:
		sprite.position.y = -absf(sin(anim_t * 10.0)) * 2.5
	else:
		sprite.position.y = 0.0
	# Wave-2 fix #2: hold a combat-tell tint for its window, then revert to
	# base_mod ONCE (no per-frame re-assert — matches the host, where the tint
	# is set once and a hit-flash may stomp it early). net_apply_tell set it.
	if _net_tell_t > 0.0:
		_net_tell_t = maxf(0.0, _net_tell_t - delta)
		if _net_tell_t <= 0.0 and sprite != null:
			sprite.modulate = base_mod
	# MP-10: tick the status BOOKKEEPING timers so the guest's own hit
	# math (marked_crit, Killing Frost, Serpent's Due, crush/rupture,
	# Enfeeble stacks) reads them exactly like solo. Pure timers — no DoT
	# damage, no juice: the host simulates the real statuses and its hp
	# truth arrives in the 20 Hz stream.
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	vuln_time = maxf(0.0, vuln_time - delta)
	if vuln_time <= 0.0:
		vuln_mult = 1.5
	hobble_t = maxf(0.0, hobble_t - delta)
	brittle_t = maxf(0.0, brittle_t - delta)
	if brittle_t <= 0.0:
		brittle = 0
	crush_t = maxf(0.0, crush_t - delta)
	burn_time = maxf(0.0, burn_time - delta)
	if burn_time <= 0.0:
		toxin = 0
	bleed_time = maxf(0.0, bleed_time - delta)


## MP-09: apply one host state sample to this MIRROR — position target,
## facing, walk flag, the hp fraction that drives the overhead bar, and
## (MP-10) the untargetable phase flag that gates guest auto-aim. Wave-2
## co-op fixes: `hidden` mirrors a burrowed/submerged boss going invisible
## (fix #1); `plated` carries the cinderhide plate wall so the guest's
## optimistic hit math matches the host's plated cut (fix #3).
func net_apply_state(pos: Vector2, flip: bool, walk: bool, hp_frac: float, untarget := false,
		hidden := false, plated := false) -> void:
	net_target = pos
	net_walk = walk
	untargetable = untarget
	if sprite != null:
		sprite.flip_h = flip
		# Wave-2 fix #1: a burrowed/submerged boss is hidden host-side; without
		# this the mirror stands visible in the open while the sim is underground.
		sprite.visible = not hidden
	net_set_plated(plated)  # Wave-2 fix #3: Boss overrides to raise/drop plate_dr
	hp = max_hp * clampf(hp_frac, 0.0, 1.0)
	if hp < max_hp and not dying and hp_bar_bg != null:
		hp_bar_bg.visible = true
		hp_bar_fg.visible = true
		_update_hp_fill()


## Wave-2 fix #2: apply a combat-tell tint to this MIRROR for `dur` seconds
## (the host set the same tint at its call site). Held once, reverted to
## base_mod on expiry in _net_mirror_tick — matching how the host holds it
## (a hit-flash tween may stomp it early on either side; that's consistent).
func net_apply_tell(color: Color, dur: float) -> void:
	_net_tell_t = maxf(_net_tell_t, dur)
	if sprite != null:
		sprite.modulate = color


## Wave-2 fix #3: the state packet's plated bit. Base enemies never plate
## (no-op); Boss overrides to set plate_dr to its own PLATE_DR wall so a
## guest mirror's optimistic damage math reads the plated cut like the host.
func net_set_plated(_on: bool) -> void:
	pass


## MP-09: the host said this mirror's original died — play the same die
## juice (sound, burst, fade) and free. No rewards, no death triggers:
## those ran on the host, and anything visual they cause (bloat's burst
## telegraph) arrives as its own event.
func net_mirror_die() -> void:
	if dying:
		return
	dying = true
	if not is_inside_tree():
		queue_free()  # killed before the deferred add landed — just vanish
		return
	collision_layer = 0
	collision_mask = 0
	if hp_bar_bg:
		hp_bar_bg.visible = false
		hp_bar_fg.visible = false
		hp_bar_cap.visible = false
	remove_from_group("enemies")
	game.sfx("edie")
	game.burst(global_position, Color(0.9, 0.3, 0.3))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.3, 0.35)
	tween.tween_callback(queue_free)


## The enemy's current prey (MP targeting seam). Re-resolves IMMEDIATELY
## when the target is gone or dead — the slow sticky cadence lives in
## _physics_process. Like game.nearest_player it falls back to a DEAD
## player when nobody is alive (callers keep their own `dead` checks,
## exactly as they did against game.player) and returns null only when
## no player is registered at all.
func _get_target() -> Player:
	if target == null or not is_instance_valid(target) or target.dead:
		target = game.pick_target(self)
		retarget_t = Balance.MOB_RETARGET_EVERY
	return target


## Decide where to move this frame. Bosses override this.
func _think(delta: float) -> Vector2:
	var player: Player = _get_target()
	if player == null or player.dead:
		return _drift_home()

	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	# LINE OF SIGHT (2026-07-09): a mob can't pathfind, so it only wakes when
	# it can trace a clear line to you (ray gated behind the cheap range check
	# so far/idle mobs never cast). force_aggro (pack cascade, boss adds, dev)
	# skips sight entirely — it already knows.
	var can_see: bool = dist <= aggro_range * Balance.MOB_AGGRO_KEEP and _has_los(player)
	if not alerted and not force_aggro:
		if dist > aggro_range or not can_see:
			return _drift_home()
		alerted = true
		game.emote(self, "!", 0.9)
		# One noticed you — the whole pack answers (per-pack aggro).
		if zone_idx >= 0:
			game.wake_pack(zone_idx, pack_id)
	# LEASH: a woken mob that keeps sight commits; lose sight for
	# MOB_AGGRO_LEASH seconds and it gives up — first heading to where you
	# vanished (usually a doorway), then home. force_aggro never leashes.
	if not force_aggro:
		if can_see:
			los_lost_t = 0.0
			last_seen = player.global_position
		else:
			los_lost_t += delta
			if los_lost_t >= Balance.MOB_AGGRO_LEASH:
				alerted = false
				los_lost_t = 0.0
				return _drift_home()
			var to_seen := last_seen - global_position
			return Vector2.ZERO if to_seen.length() < 24.0 else to_seen.normalized() * speed

	# --- movement-overriding trait STATES (checked before normal AI) ---
	if pounce_windup > 0.0:
		return Vector2.ZERO                              # crouched, about to spring
	if pounce_time > 0.0:
		return pounce_dir * Balance.MOB_LUNGE_SPEED      # mid-pounce (may overshoot)
	if pounce_whiff > 0.0:
		return Vector2.ZERO                              # overshot: exposed, recovering
	if counter_t > 0.0:
		return Vector2.ZERO                              # guard raised: rooted, hit-it-and-suffer
	if channel_t > 0.0:
		return Vector2.ZERO                              # channeling a heal: stands still

	var frenzied := traits.has("frenzy") and hp < max_hp * Balance.MOB_FRENZY_HP
	var spd := speed * (Balance.MOB_FRENZY_SPEED if frenzied else 1.0)

	# Channel-healer: start a heal channel when a wounded ally is in range.
	if traits.has("channel_heal") and channel_cd <= 0.0 and _wounded_ally_near():
		_begin_channel()
		return Vector2.ZERO
	# Counter-warder: raise the guard when the player is close and pressing.
	if traits.has("counter") and counter_cd <= 0.0 and dist < 150.0:
		_raise_guard()
		return Vector2.ZERO
	# Blinker: flicker to the player's flank when off cooldown at range.
	if traits.has("blinker") and mob_blink_cd <= 0.0 and dist > 120.0 and dist < 460.0:
		_blink_to(player)
		return Vector2.ZERO

	if ranged:
		if attack_cd <= 0.0:
			attack_cd = 1.58
			game.sfx("bolt")
			var p := Projectile.spawn(game, global_position, to_player.normalized() * 420.0, _hit_dmg(), false, "bolt")
			p.hostile_type = dmg_type
			p.source_enemy = self
		# Snarer lobs a freeze-patch at the player's feet on its own cadence.
		if traits.has("snare") and snare_cd <= 0.0 and dist < 420.0:
			snare_cd = Balance.MOB_SNARE_CD
			_snare_patch(player.global_position)
		if traits.has("skirmish"):
			# Skirmisher: KITES for real — full-speed backpedal on a strafing
			# arc inside KEEP (a straight-line retreat is trivially chased;
			# the arc forces steering). Cornering it against a wall is the
			# earned counterplay; regular turret mobs keep the old shuffle.
			if dist < Balance.MOB_SKIRMISH_KEEP:
				var away := -to_player.normalized()
				var strafe := away.orthogonal() * strafe_sign * Balance.MOB_SKIRMISH_STRAFE
				return (away + strafe).normalized() * spd
			elif dist > Balance.MOB_SKIRMISH_FAR:
				return to_player.normalized() * spd
			return Vector2.ZERO
		if dist < 200.0:
			return -to_player.normalized() * spd * 0.8
		elif dist > 300.0:
			return to_player.normalized() * spd
		return Vector2.ZERO
	else:
		# Webber (melee too): fling a rooting shot from mid-range.
		if traits.has("web") and web_cd <= 0.0 and dist > 90.0 and dist < 420.0:
			web_cd = Balance.MOB_WEB_CD
			_web_shot(to_player.normalized())
		# Pounce: an OVERSHOOTING leap — sidestep the crouch and it sails past.
		if traits.has("pounce") and pounce_cd <= 0.0 and dist > 60.0 and dist < Balance.MOB_LUNGE_RANGE:
			pounce_cd = Balance.MOB_LUNGE_CD
			pounce_windup = Balance.MOB_LUNGE_WINDUP
			pounce_dir = to_player.normalized()
			sprite.modulate = Color(1.8, 0.7, 2.0)       # purple crouch = incoming pounce
			_net_tell(Color(1.8, 0.7, 2.0), Balance.MOB_LUNGE_WINDUP + Balance.MOB_LUNGE_TIME)
			return Vector2.ZERO
		if dist < 42.0:
			if attack_cd <= 0.0:
				attack_cd = 0.92
				windup = 0.27
				sprite.modulate = Color(2.0, 1.7, 0.5)   # "about to bite!" flash
				_net_tell(Color(2.0, 1.7, 0.5), 0.27)    # same window the host holds
			return Vector2.ZERO
		return to_player.normalized() * spd


func _drift_home() -> Vector2:
	var to_home := home - global_position
	if to_home.length() > 30.0:
		return to_home.normalized() * speed * 0.5
	return Vector2.ZERO


## Clear line to the player? A ray per offset against the WALL layer ONLY
## (layer 1 — the player is layer 2 and enemies layer 4, so neither blocks
## sight). Three rays (center + two flanks) keep a mob from "losing" you at a
## doorway edge. Runs in _physics_process — the query-safe window.
func _has_los(player: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var to := player.global_position - global_position
	var perp := Vector2(-to.y, to.x)
	if perp.length() > 0.01:
		perp = perp.normalized() * 16.0
	for off in [Vector2.ZERO, perp, -perp]:
		var q := PhysicsRayQueryParameters2D.create(
			global_position, player.global_position + off, 1)
		if space.intersect_ray(q).is_empty():
			return true
	return false


# ---------------------------------------------------------------- traits ---

## Dynamic hazard drop (MP-10): the ONE door for hazards the combat sim
## writes mid-fight (sower trails, bloat pools, every boss slag/ice/
## poison patch) — paints locally exactly like the old direct call, and
## when hosting fans the same patch to guests so each machine's own
## _apply_hazards ticks its own player (owner applies; §4.1). World-gen
## hazards are seed-pure and never come through here.
func _hazard(zi: int, type: String, pos: Vector2, radius: float, dur: float, drift := Vector2.ZERO) -> void:
	game._add_hazard(zi, type, pos, radius, dur, drift)
	if net_id > 0 and not net_mirror and game.net_host():
		game.net_session().host_hazard(zi, type, pos, radius, dur, drift)


## Contact/bolt damage for this hit — frenzy quickens AND hardens the
## wounded (2026-07-07 identity pass).
func _hit_dmg() -> float:
	if traits.has("frenzy") and hp < max_hp * Balance.MOB_FRENZY_HP:
		return dmg * Balance.MOB_FRENZY_DMG
	return dmg


## Per-frame trait upkeep (only runs in the occupied room). Ticks every
## trait's timers and fires the passive/aura ones; the movement traits
## (pounce/blink/channel) resolve their motion in _think.
func _tick_traits(delta: float) -> void:
	if mend_rate > 0.0 and hp < max_hp and not dying:
		hp = minf(max_hp, hp + max_hp * mend_rate * delta)
		refresh_hp_bar()
		mend_fx_t -= delta
		if mend_fx_t <= 0.0:
			mend_fx_t = 1.1
			game.burst(global_position + Vector2(0, -6), Color(0.4, 1.0, 0.5), 4)
	# --- pounce: windup -> dash -> whiff/vulnerable if it overshot ---
	if traits.has("pounce"):
		pounce_cd = maxf(0.0, pounce_cd - delta)
		if pounce_windup > 0.0:
			pounce_windup -= delta
			if pounce_windup <= 0.0:
				pounce_time = Balance.MOB_LUNGE_TIME
				game.sfx("blink", 0.7)
		if pounce_time > 0.0:
			pounce_time -= delta
			var prey: Player = _get_target()
			if pounce_time <= 0.0 and is_instance_valid(prey):
				# Landed: if the prey is NOT here, it overshot — expose it.
				if global_position.distance_to(prey.global_position) > 96.0:
					pounce_whiff = Balance.MOB_POUNCE_WHIFF
					sprite.modulate = Color(1.6, 1.6, 0.5)  # dazed-yellow: punish me
		pounce_whiff = maxf(0.0, pounce_whiff - delta)
	# --- cooldown-only ticks for the on-demand traits ---
	if traits.has("web"):     web_cd = maxf(0.0, web_cd - delta)
	if traits.has("snare"):   snare_cd = maxf(0.0, snare_cd - delta)
	if traits.has("blinker"): mob_blink_cd = maxf(0.0, mob_blink_cd - delta)
	if traits.has("counter"):
		counter_cd = maxf(0.0, counter_cd - delta)
		if counter_t > 0.0:
			counter_t -= delta
			if counter_t <= 0.0:
				sprite.modulate = base_mod
	# --- channel_heal: stand-still cast, breaks on damage (take_damage) ---
	if traits.has("channel_heal"):
		channel_cd = maxf(0.0, channel_cd - delta)
		if channel_t > 0.0:
			channel_t -= delta
			# (The beam points at a wounded ALLY; the player check was only
			# a liveness guard — the target seam keeps it identical.)
			if is_instance_valid(channel_beam) and is_instance_valid(_get_target()):
				channel_beam.points = [Vector2.ZERO, to_local(_channel_target())]
			if channel_t <= 0.0:
				_finish_channel()
	# --- reflect: telegraphed shield window on a cadence ---
	if traits.has("reflect"):
		reflect_cd = maxf(0.0, reflect_cd - delta)
		if reflect_t > 0.0:
			reflect_t -= delta
			if reflect_t <= 0.0:
				sprite.modulate = base_mod
		elif reflect_cd <= 0.0:
			_raise_reflect()
	# --- frost aura: chills EVERY player in radius (ch5) ---
	# Wave-2 co-op fix #4: an aura is positional, not single-target — sweep all
	# live players within MOB_AURA_RADIUS (apply_chill forwards to a remote owner
	# on its own, so no net plumbing). Solo = one player = bit-identical.
	if traits.has("frost_aura"):
		for pl in game.players:
			if pl == null or not is_instance_valid(pl) or pl.dead:
				continue
			if global_position.distance_to(pl.global_position) < Balance.MOB_AURA_RADIUS:
				pl.apply_chill(Balance.MOB_FROST_SLOW)
	# --- sower: drip a burning trail as it moves (ch4) ---
	if traits.has("sower") and velocity.length() > 30.0:
		sow_t -= delta
		if sow_t <= 0.0:
			sow_t = Balance.MOB_SOW_EVERY
			if zone_idx >= 0:
				_hazard(zone_idx, "lava", global_position, 46.0, Balance.MOB_SOW_LIFE)
	# --- spawner: sprout a weak add until killed (ch6) ---
	if traits.has("spawner"):
		spawn_cd = maxf(0.0, spawn_cd - delta)
		if spawn_cd <= 0.0 and _my_spawn_count() < Balance.MOB_SPAWN_CAP:
			spawn_cd = Balance.MOB_SPAWN_CD
			_spawn_add()
	# --- tether: the bond burns the player who crosses it (ch6) ---
	if traits.has("tether"):
		_tick_tether()


# ---- channel_heal (interruptible support) ----

func _wounded_ally_near() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or e.dying or e is Boss or e.zone_idx != zone_idx:
			continue
		if e.hp < e.max_hp * 0.95 \
				and global_position.distance_to(e.global_position) <= Balance.MOB_HEAL_RADIUS:
			return true
	return false

func _channel_target() -> Vector2:
	var best: Enemy = null
	var bd := Balance.MOB_HEAL_RADIUS
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or e.dying or e is Boss or e.zone_idx != zone_idx:
			continue
		var d := global_position.distance_to(e.global_position)
		if e.hp < e.max_hp * 0.95 and d < bd:
			bd = d; best = e
	return best.global_position if best else global_position

func _begin_channel() -> void:
	channel_t = Balance.MOB_CHANNEL_TIME
	game.spawn_text(global_position + Vector2(0, -64), "channeling...", Color(0.5, 1.0, 0.6))
	channel_beam = Line2D.new()
	channel_beam.width = 4.0
	channel_beam.default_color = Color(0.4, 1.0, 0.5, 0.7)
	channel_beam.z_index = 3
	add_child(channel_beam)

func _finish_channel() -> void:
	channel_cd = Balance.MOB_CHANNEL_CD
	if is_instance_valid(channel_beam):
		channel_beam.queue_free()
	_heal_pulse()

## Damage interrupts the channel (called from take_damage).
func _break_channel() -> void:
	if channel_t <= 0.0:
		return
	channel_t = 0.0
	channel_cd = Balance.MOB_CHANNEL_CD * 0.6  # a short punish, then it may retry
	if is_instance_valid(channel_beam):
		channel_beam.queue_free()
	game.spawn_text(global_position + Vector2(0, -64), "INTERRUPTED", Color(1.0, 0.7, 0.4))


## The heal itself: mend nearby wounded allies (same room) and self.
func _heal_pulse() -> void:
	var healed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or e.dying or e is Boss or e.zone_idx != zone_idx:
			continue
		if global_position.distance_to(e.global_position) > Balance.MOB_HEAL_RADIUS:
			continue
		if e.hp < e.max_hp:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * Balance.MOB_HEAL_FRAC)
			e.refresh_hp_bar()
			game.burst(e.global_position + Vector2(0, -6), Color(0.4, 1.0, 0.5), 6)
			healed = true
	if hp < max_hp:
		hp = minf(max_hp, hp + max_hp * Balance.MOB_HEAL_FRAC)
		refresh_hp_bar()
		healed = true
	if healed:
		game.sfx("mend", 0.85)
		game.burst(global_position, Color(0.5, 1.0, 0.6), 14)


# ---- web / snare / reflect / counter / blink ----

func _web_shot(aim: Vector2) -> void:
	game.sfx("bolt", 0.7)
	var p := Projectile.spawn(game, global_position, aim * 300.0, dmg * 0.4, false, "bolt")
	p.hostile_type = dmg_type
	p.source_enemy = self
	p.root_dur = Balance.MOB_WEB_ROOT
	p.glow_color = Color(0.6, 0.9, 0.6)

func _snare_patch(at: Vector2) -> void:
	# A telegraphed frost patch: caught standing in it when it arms, you
	# FREEZE. A normal danger circle (not inverse) with a freeze rider.
	game.telegraph(at, 84.0, 1.1, dmg * 0.6,
		{"color": Color(0.6, 0.85, 1.0, 0.6), "freeze": Balance.MOB_SNARE_FREEZE})

func _raise_guard() -> void:
	counter_t = Balance.MOB_COUNTER_TIME
	counter_cd = Balance.MOB_COUNTER_CD
	sprite.modulate = Color(0.7, 0.9, 1.6)  # blue guard glow
	_net_tell(Color(0.7, 0.9, 1.6), Balance.MOB_COUNTER_TIME)  # fix #2: the counter tell
	# The warn text is a punish tell — a guest firing into a raised guard gets
	# staggered, so it must read it too (spawn_text_all no-ops solo).
	game.spawn_text_all(global_position + Vector2(0, -60), "GUARD", Color(0.7, 0.85, 1.0))

func _raise_reflect() -> void:
	reflect_t = Balance.MOB_REFLECT_TIME
	reflect_cd = Balance.MOB_REFLECT_CD
	sprite.modulate = Color(1.5, 1.2, 0.6)  # amber forge-shield
	_net_tell(Color(1.5, 1.2, 0.6), Balance.MOB_REFLECT_TIME)  # fix #2: the reflect tell
	# The warn text is a punish tell (a guest's shot bounces back) — fan it.
	game.spawn_text_all(global_position + Vector2(0, -60), "WARDED", Color(1.0, 0.85, 0.4))
	game.burst(global_position, Color(1.0, 0.8, 0.4), 12)

func _blink_to(player: Player) -> void:
	mob_blink_cd = Balance.MOB_BLINK_CD
	untargetable = true
	game.sfx("blink", 1.1)
	game.burst(global_position, Color(0.6, 0.55, 1.0), 12)
	var behind: Vector2 = player.global_position \
		- (player.global_position - global_position).normalized() * 70.0
	global_position = game.clamp_to_zone(behind, player.global_position) \
		if game.has_method("clamp_to_zone") else behind
	game.burst(global_position, Color(0.6, 0.55, 1.0), 12)
	# reappear targetable a beat later
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if is_instance_valid(self):
			untargetable = false)


# ---- spawner / tether ----

func _my_spawn_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.has_meta("spawned_by") and e.get_meta("spawned_by") == get_instance_id():
			n += 1
	return n

func _spawn_add() -> void:
	var pos := global_position + Vector2(randf_range(-60, 60), randf_range(-50, 50))
	var add := Enemy.make(game, kind, game.clamp_to_zone(pos, global_position) \
		if game.has_method("clamp_to_zone") else pos, maxi(1, level - 2))
	add.zone_idx = zone_idx
	add.pack_id = pack_id
	add.set_meta("spawned_by", get_instance_id())
	# the spawn is a weakling: no traits, small, no reward inflation
	add.traits = {}
	add.max_hp *= 0.4; add.hp = add.max_hp
	add.dmg *= 0.6
	add.xp_value = 0; add.gold_value = 0
	add.sprite.scale *= 0.8
	if zone_idx >= 0:
		game.zone_alive[zone_idx] = game.zone_alive.get(zone_idx, 0) + 1
	game.add_enemy(add)
	game.spawn_text(global_position + Vector2(0, -60), "a spawn crawls forth", Color(0.6, 0.9, 0.5))

func _tick_tether() -> void:
	if not is_instance_valid(tether_partner) or tether_partner.dying:
		if is_instance_valid(tether_line):
			tether_line.queue_free()
		return
	if tether_line == null:
		tether_line = Line2D.new()
		tether_line.width = 5.0
		tether_line.default_color = Color(0.5, 0.9, 0.4, 0.6)
		tether_line.z_index = 2
		add_child(tether_line)
	tether_line.points = [Vector2.ZERO, to_local(tether_partner.global_position)]
	# The bond BURNS every player who stands across it (segment proximity).
	# Wave-2 co-op fix #5: the bond is a WALL, not a heat-seeker — test EVERY
	# live player against the burning segment (take_damage already forwards to a
	# remote owner). Solo = one player = bit-identical.
	for pl in game.players:
		if pl == null or not is_instance_valid(pl) or pl.dead:
			continue
		var d := _dist_to_segment(pl.global_position, global_position, tether_partner.global_position)
		if d < 34.0:
			pl.take_damage(dmg * 0.5, dmg_type, self)

static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---- martyr (death buff) ----

## On death, a green wail heals nearby allies and enrages them (a lasting
## +dmg, applied by lifting their frenzy floor via a marker). Kill it LAST.
func _martyr_wail() -> void:
	game.burst(global_position, Color(0.4, 1.0, 0.5), 22)
	game.sfx("mend", 1.0)
	game.spawn_text(global_position + Vector2(0, -60), "A DYING WAIL", Color(0.6, 1.0, 0.6), 2.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or e.dying or e is Boss or e.zone_idx != zone_idx:
			continue
		if global_position.distance_to(e.global_position) > Balance.MOB_HEAL_RADIUS:
			continue
		e.hp = minf(e.max_hp, e.hp + e.max_hp * Balance.MOB_MARTYR_HEAL)
		e.refresh_hp_bar()
		e.dmg *= Balance.MOB_MARTYR_RAGE   # a permanent rage on the survivors
		e.sprite.modulate = Color(1.5, 0.7, 0.7)
		game.burst(e.global_position, Color(1.0, 0.5, 0.5), 8)


## Keep the overhead HP bar honest after a heal (it normally only
## updates on damage).
func refresh_hp_bar() -> void:
	if hp_bar_fg and hp_bar_fg.visible:
		_update_hp_fill()


## Fill width + the 1px darker end-cap riding its right edge (the cap
## keeps the remaining-HP boundary crisp against any ground).
func _update_hp_fill() -> void:
	var w: float = 30.0 * clampf(hp / max_hp, 0.0, 1.0)
	hp_bar_fg.size.x = w
	hp_bar_cap.visible = hp_bar_fg.visible and w >= 2.0
	hp_bar_cap.position.x = -15.0 + w - 1.0


## Promote this monster to an ELITE — the between-boss miniboss beat
## (playtest round 6). Bigger and meaner than its kind, pays NO XP
## (the chapter XP total stays fixed) but its death rolls the good-loot
## table: guaranteed gem, guaranteed chest, reset stones and bags
## (game.on_enemy_died). Later chapters may promote several at once.
func promote_elite() -> void:
	if elite:
		return
	elite = true
	display_name = "Elite " + display_name
	max_hp *= Balance.ELITE_HP_MULT
	hp = max_hp
	dmg *= Balance.ELITE_DMG_MULT
	physres += Balance.ELITE_RES_BONUS
	magres += Balance.ELITE_RES_BONUS
	critres += Balance.ELITE_CRITRES_BONUS
	xp_value = 0  # elites never pay XP (fixed chapter totals)
	gold_value *= Balance.ELITE_GOLD_MULT
	sprite.scale *= Balance.ELITE_SPRITE_MULT
	# A gold ring underfoot marks the rank at a glance (body tints reset
	# on damage flashes, so a child sprite is the durable marker).
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(1.0, 0.8, 0.3, 0.75)
	ring.position = Vector2(0, 14)
	ring.scale = Vector2(1.5, 0.85)
	ring.z_index = -1
	add_child(ring)
	# MP-09: post-spawn promotions (the room-ambush roll promotes AFTER
	# add_enemy) reach mirrors as their own event; pre-spawn promotions
	# ride the spawn event's elite flag instead (net_id is still 0 here).
	if net_id > 0 and not net_mirror and game != null and game.net_host():
		game.net_session().host_enemy_elite(net_id)


# ------------------------------------------------------------- statuses ---

func apply_stun(dur: float) -> void:
	_mirror_status("stun", {"dur": dur})
	# CC belongs to mobs and elites: bosses are outright IMMUNE (was a
	# 35% duration tax — short enough to read as a bug at boss doors,
	# long enough to tax every stun-themed variant's damage budget).
	# Boss kits that stun the boss ON PURPOSE (wall-slam vuln windows)
	# must write stun_time directly.
	if self is Boss:
		return
	stun_time = maxf(stun_time, dur)


## MP-10: a guest's rider on a MIRROR ships to the host, which re-applies
## it through the real apply_* path with the guest's shell as source. The
## caller's local field writes still run afterwards — display bookkeeping
## the guest's own hit math reads (ticked down in _net_mirror_tick).
func _mirror_status(kind: String, data: Dictionary) -> void:
	if not net_mirror or _status_mute or net_id <= 0:
		return
	if game == null or not game.net_guest():
		return
	game.net_session().guest_enemy_status(net_id, kind, data)


## `src` (MP phase 0): the player who applied the DoT — ticks crit off
## THEIR sheet. Callers that don't pass it yet fall back to game.player
## at tick time (solo: identical, there is only one player).
func apply_burn(dps: float, dur: float, color := Color(1.4, 0.8, 0.6), src: Player = null) -> void:
	_mirror_status("burn", {"dps": dps, "dur": dur, "color": color})
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, dur)
	burn_color = color
	if src != null:
		burn_src = src


## Wind Cuts (mage) bleed — a red physical DoT that REFRESHES, never stacks
## (keeps the stronger dps and the longer window, exactly like burn).
func apply_bleed(dps: float, dur: float, src: Player = null) -> void:
	_mirror_status("bleed", {"dps": dps, "dur": dur})
	bleed_dps = maxf(bleed_dps, dps)
	bleed_time = maxf(bleed_time, dur)
	if src != null:
		bleed_src = src


## Green-theme DoT (poison/venom): the exception to the no-stack burn
## rule — each application adds a toxin stack that deepens the TICK.
## Fast cadences ramp fast; the stack dies when the burn runs out.
func apply_toxin(dps: float, dur: float, color := Color(0.5, 1.2, 0.5), src: Player = null) -> void:
	_mirror_status("toxin", {"dps": dps, "dur": dur, "color": color})
	toxin = mini(toxin + 1, Balance.TOXIN_MAX_STACKS)
	_status_mute = true  # one "toxin" event carries the burn too (host restacks)
	apply_burn(dps * (1.0 + toxin * Balance.TOXIN_PER_STACK), dur, color, src)
	_status_mute = false


## Ice hits crack the target: brittle stacks amplify ICE damage only
## (theme-internal — see Balance.BRITTLE_PER_STACK).
func add_brittle() -> void:
	_mirror_status("brittle", {})
	brittle = mini(brittle + 1, Balance.BRITTLE_MAX_STACKS)
	brittle_t = Balance.BRITTLE_DUR


## EXPOSED / Death Mark (MP-10 seam): the direct vuln_time writes now
## have one door, so a mirror target forwards the mark to the host.
## mult < 0 keeps the current amp (plain Expose); Death Mark passes its own.
func apply_vuln(dur: float, mult := -1.0) -> void:
	_mirror_status("vuln", {"dur": dur, "mult": mult})
	vuln_time = dur
	if mult > 0.0:
		vuln_mult = mult


## Player-driven displacement (MP-10 seam): every knock/pull/shove goes
## through here — a mirror forwards it so the HOST's enemy actually moves
## (and its crush window opens for real). The local crush bookkeeping
## still sets: the guest's own crush/rupture hit math reads it.
func apply_knock(vec: Vector2, crush := false) -> void:
	_mirror_status("knock", {"v": vec, "crush": crush})
	if not net_mirror:
		knock = vec  # a mirror's position belongs to the snapshot stream
	if crush:
		crush_t = Balance.CRUSH_WINDOW


func apply_slow(mult: float, dur: float) -> void:
	_mirror_status("slow", {"mult": mult, "dur": dur})
	if self is Boss:
		# CC-immune, same rule as stuns — but a failed slow HOBBLES
		# (round 49d, the concussion move for slows): the boss shrugs
		# off the crawl, yet its footing is scuffed — it takes
		# +HOBBLE_MULT damage from the player while the mark holds.
		if hobble_t <= 0.0:
			game.spawn_text(global_position + Vector2(0, -44), "HOBBLED", Color(0.55, 0.95, 0.75))
		hobble_t = maxf(hobble_t, Balance.HOBBLE_DUR)
		return
	slow_mult = minf(slow_mult, mult) if slow_time > 0.0 else mult
	slow_time = maxf(slow_time, dur)
	sprite.modulate = Color(0.6, 0.8, 1.3)


# --------------------------------------------------------------- damage ---

func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
	# MP-10: capture-and-clear the striking player FIRST, so no early
	# return leaks it into an unrelated later hit. hit_enemy sets it for
	# every player hit; the host's hit RPC sets the attacking guest's
	# shell. Solo it is always THE player — reads below are bit-identical.
	var striker: Player = hit_src if hit_src != null and is_instance_valid(hit_src) else null
	hit_src = null
	if net_mirror:
		# MP-10: a guest's hit — optimistic local juice + the funnel RPC
		# (MP-09 dropped it silently; mirror hp truth still rides the sync).
		_net_mirror_hit(amount, from_dir, is_crit, silent)
		return
	if dying or untargetable:
		return
	# Wounding one pack member wakes its whole pack (ranged openers too).
	if zone_idx >= 0 and not force_aggro:
		game.wake_pack(zone_idx, pack_id)
	# MP-10: damage TURNS the victim — it hunts its attacker for at least
	# one sticky retarget window. Solo: the attacker IS the only player,
	# so this re-picks the same prey (bit-identical).
	if striker != null and not striker.dead:
		target = striker
		retarget_t = Balance.MOB_RETARGET_EVERY
	if vuln_time > 0.0:
		amount *= vuln_mult
	if hobble_t > 0.0:
		amount *= 1.0 + Balance.HOBBLE_MULT  # scuffed footing: every hit bites
	# --- trait damage modifiers ---
	# WARDED: a guard you must SHATTER, not nibble through. A real blow
	# breaks it for good — a crit, a heavy single hit, OR any status
	# (control builds keep their shortcut). No build is walled: everyone
	# lands one of those. The shattering blow itself connects at full.
	if traits.has("warded") and not ward_broken:
		var afflicted := burn_time > 0.0 or stun_time > 0.0 or slow_time > 0.0 or vuln_time > 0.0
		if is_crit or afflicted or amount >= max_hp * Balance.MOB_WARD_BREAK_HIT:
			ward_broken = true
			if not silent:
				game.spawn_text(global_position + Vector2(0, -44), "WARD SHATTERED!", Color(1.0, 0.85, 0.4))
				game.burst(global_position, Color(1.0, 0.85, 0.4), 16)
		else:
			amount *= 1.0 - Balance.MOB_WARD_DR
			if not silent:
				game.spawn_text(global_position + Vector2(0, -44), "guarded", Color(0.7, 0.8, 1.0))
	# POUNCE whiff: an overshot pouncer is exposed — punish it.
	if pounce_whiff > 0.0:
		amount *= 1.0 + Balance.MOB_POUNCE_PUNISH
	# REFLECT: while the forge-shield holds, bounce a share back at the
	# ATTACKING player (MP-10: hit_src carries it; solo fallback is the
	# resolved target — THE player, exactly the old read).
	if striker == null:
		striker = _get_target()
	if reflect_t > 0.0 and not silent and is_instance_valid(striker):
		striker.take_damage(amount * Balance.MOB_REFLECT_FRAC, dmg_type, self)
		game.burst(global_position, Color(1.0, 0.8, 0.4), 8)
	# COUNTER: struck while its guard is raised, it staggers YOU — the
	# attacker (same striker resolution as REFLECT above).
	if counter_t > 0.0 and not silent and is_instance_valid(striker):
		var pushback := (striker.global_position - global_position).normalized()
		striker.take_damage(dmg * 0.5, dmg_type, self)
		striker.apply_root(Balance.MOB_COUNTER_STAGGER)
		amount *= 0.3  # the blow mostly rang off the guard
		counter_t = 0.0
		sprite.modulate = base_mod
	# CHANNEL_HEAL breaks on damage.
	if channel_t > 0.0:
		_break_channel()
	# Flat plate wall (Cinderhide): a pen-proof cut on EVERYTHING that lands
	# — resolved player hits, DoTs, true damage — so the plated phase is a
	# real wall the lava-melt must open, not a resist a DPS build outscales.
	if plate_dr > 0.0:
		amount *= 1.0 - plate_dr
	hp -= amount
	knock = from_dir * (220.0 if is_crit else 160.0)
	if not silent:
		game.sfx("ehit", 1.0, 0.0, 4.0)  # +4dB: the Punch source runs quiet
		if is_crit:
			game.spawn_text(global_position + Vector2(0, -34), "%d!" % int(amount), Color(1.0, 0.55, 0.1))
		else:
			game.spawn_text(global_position + Vector2(0, -30), str(int(amount)), Color(1, 1, 1))
		# MP-14 (§5.6): the host is authority for every hit it applies (its own
		# blow AND a guest's — both land here). Fan the number to the party
		# members who did NOT strike, who show it small. net_host() gates it, so
		# solo/offline is untouched; the shell above already showed its own big.
		if game.net_host():
			game.net_session().host_fan_damage(net_id, int(amount), is_crit, striker)
		sprite.modulate = Color(3, 3, 3)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", base_mod, 0.15)
	# Show and update the overhead HP bar once damaged.
	if hp_bar_bg and hp < max_hp and not dying:
		hp_bar_bg.visible = true
		hp_bar_fg.visible = true
		_update_hp_fill()
	if hp <= 0.0:
		die()


## MP-10, GUEST: a local player hit landed on this MIRROR. Play the solo
## juice OPTIMISTICALLY (number, flash, bar, predicted hp — trusted
## client) and ship the hit to the host, which re-resolves take_damage's
## internal multipliers (vuln/ward/plate/pounce) against authoritative
## state. The RAW amount travels; the local copies below only shape the
## DISPLAYED number off this guest's own bookkeeping. The 20 Hz stream
## re-asserts true hp; the kill event owns death. SILENT hits (hazard
## ticks, dev sweeps) are host business — a guest's own copy of a lava
## patch must not double-bill the host through the funnel.
func _net_mirror_hit(amount: float, from_dir: Vector2, is_crit: bool, silent: bool) -> void:
	if dying or untargetable or silent:
		return
	if game != null and game.net_guest():
		game.net_session().guest_hit_enemy(net_id, amount, from_dir, is_crit)
	var shown := amount
	if vuln_time > 0.0:
		shown *= vuln_mult
	if hobble_t > 0.0:
		shown *= 1.0 + Balance.HOBBLE_MULT
	if plate_dr > 0.0:
		shown *= 1.0 - plate_dr
	hp -= shown  # optimistic (kill-window reads: executes, dash refunds)
	game.sfx("ehit", 1.0, 0.0, 4.0)
	if is_crit:
		game.spawn_text(global_position + Vector2(0, -34), "%d!" % int(shown), Color(1.0, 0.55, 0.1))
	else:
		game.spawn_text(global_position + Vector2(0, -30), str(int(shown)), Color(1, 1, 1))
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	if hp_bar_bg and hp < max_hp:
		hp_bar_bg.visible = true
		hp_bar_fg.visible = true
		_update_hp_fill()


func die() -> void:
	dying = true
	# MP-09: the host fans the death out — guest mirrors play the die
	# juice and free (rewards, quests and death triggers stay host-side).
	if net_id > 0 and not net_mirror and game.net_host():
		game.net_session().host_enemy_died(net_id)
	collision_layer = 0
	collision_mask = 0
	if hp_bar_bg:
		hp_bar_bg.visible = false
		hp_bar_fg.visible = false
		hp_bar_cap.visible = false
	remove_from_group("enemies")
	game.sfx("edie")
	game.burst(global_position, Color(0.9, 0.3, 0.3))
	# --- death-trigger traits (ch3+) ---
	# BLOAT: bursts into a lingering blight pool — kill it at range.
	if traits.has("bloat") and zone_idx >= 0:
		game.telegraph(global_position, 70.0, 0.4, 0.0, {"color": Color(0.5, 0.9, 0.4, 0.5)})
		_hazard.call_deferred(zone_idx, "poison", global_position, 70.0, Balance.MOB_BLOAT_LIFE)
		game.burst(global_position, Color(0.5, 0.95, 0.4), 20)
		game.sfx("nova", 0.7)
	# MARTYR: its death-wail heals AND enrages nearby allies.
	if traits.has("martyr"):
		_martyr_wail()
	# TETHER: one falls, but the bond pours its strength into the twin —
	# the survivor heals to FULL. You must burst BOTH down together.
	if is_instance_valid(tether_line):
		tether_line.queue_free()
	if traits.has("tether") and is_instance_valid(tether_partner) and not tether_partner.dying:
		var tp := tether_partner
		tp.hp = tp.max_hp
		tp.refresh_hp_bar()
		tp.sprite.modulate = Color(0.6, 1.4, 0.5)
		game.spawn_text(tp.global_position + Vector2(0, -60),
			"THE BOND RESTORES IT", Color(0.5, 1.0, 0.5), 2.5)
		game.burst(tp.global_position, Color(0.5, 1.0, 0.5), 18)
		game.sfx("mend", 0.7)
	# Reward attribution, not targeting: co-op awards FULL XP to every
	# party member in the active room set (MULTIPLAYER.md §5.5). The host
	# keeps its solo award below; MP-10 fans the same amount to guests.
	if is_instance_valid(game.player):
		game.player.gain_xp(xp_value)
	if net_id > 0 and not net_mirror and game.net_host():
		game.net_session().host_award_xp(xp_value)
	# Deferred: loot spawns collision objects, which is not allowed
	# in the middle of a physics callback (e.g. a projectile hit).
	game.on_enemy_died.call_deferred(self)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.3, 0.35)
	tween.tween_callback(queue_free)
