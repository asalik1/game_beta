extends CharacterBody2D
## PLAYER, layer 1 of 9 — state, stats, themes, gear/bag and
## progression. The class is split across an inheritance chain so each
## file stays readable while code and `self` semantics stay verbatim
## (calls flow derived→base; shared primitives live in player_combat):
##   player_core.gd <- player_combat.gd (targeting/hit/juice)
##     <- player_kit_warrior.gd <- player_kit_archer.gd
##     <- player_kit_mage.gd <- player_kit_assassin.gd
##     <- player_kit_paladin.gd <- player_kit_warlock.gd
##     <- player.gd (class_name Player: dispatch/survival/per-frame)
## The hero. Classes scale on a primary attribute (STR/AGI/INT), fight
## with 3 basics + 1 ultimate (keyboard, auto-aimed), and customize via:
##  - THEMES: each ability can be assigned any unlocked elemental theme,
##    which changes its behavior (poison DoTs, shadow crits, ice roots...)
##  - the row-based skill tree (see skills.gd)
##  - gear with gem sockets
## All combat math (crit curves, resistances, penetration, evasion,
## true damage) lives in stats.gd.

const SPEED_BASE_REF := 260.0

var game: Game  # set by game.gd

# --- identity ---
var cls := "warrior"
var ability_theme := {"a1": "", "a2": "", "a3": "", "ult": ""}
var themes_known := 0

# --- Phase 1 story trackers (persisted with the save from day one) ---
var resonance := 0.0     # -100 (Temptation) .. +100 (Virtue), per DESIGN.md
var faction_standing := {"accord": 0, "cinderborn": 0, "wildfang": 0, "choir": 0}


## Nudge Resonance. The world reacts through dialogue and haggle bands
## (Story.res_band); the Stats tab surfaces the number and a one-line
## explanation (playtest round 6: "I can't even SEE this stat").
func add_resonance(delta: float) -> void:
	resonance = clampf(resonance + delta, -100.0, 100.0)


## Conviction strength (0..1) behind the band leans: zero through the
## neutral band, wakes PAST the band line, full at ±100. All reads are
## live — no recalc involved.
func res_lean() -> float:
	return clampf((absf(resonance) - Balance.RES_LEAN_START)
		/ (Balance.RES_LEAN_FULL - Balance.RES_LEAN_START), 0.0, 1.0)


## Hunger (tempted lean): bonus damage vs wounded MOBS (never bosses).
func hunger_exec_bonus() -> float:
	return Balance.RES_HUNGER_EXEC_MAX * res_lean() if resonance < 0.0 else 0.0


## Hunger (tempted lean): kills drop a little extra gold.
func hunger_gold_mult() -> float:
	return 1.0 + (Balance.RES_HUNGER_GOLD_MAX * res_lean() if resonance < 0.0 else 0.0)


## Constancy (steady lean): health potions mend deeper.
func constancy_heal_mult() -> float:
	return 1.0 + (Balance.RES_CONSTANCY_HEAL_MAX * res_lean() if resonance > 0.0 else 0.0)

# --- progression ---
var level := 1
var xp := 0
var skill_points := 1    # points == level: the first lands at L1, tree fills at L40
var tree_points := {}    # skill cell id -> points (0..5)
# The four attributes convert at CLASS ratios (Classes.ATTR_SCALE);
# the substats convert 1:1 for everyone (Classes.SUBSTAT_SCALE).
var attr_points := {"STR": 0, "AGI": 0, "INT": 0, "VIT": 0,
	"PhysRes": 0, "MagRes": 0, "CritRes": 0, "DEX": 0, "PhysPen": 0, "MagPen": 0}
var unspent_attr := 0    # +1 per level, allocate in the skills menu
var gold := 15           # scarcity pass: merchants and haggling matter
# Health potions are an INVESTMENT (2026-07-09): `potions` is BOUGHT stock
# (merchant gold, carries across chapters, sellable) — a fresh run starts
# DRY. `potions_free` is the ONE teaching potion granted on entering ch1-3
# (Balance.FREE_POTION_CHAPTERS): it EXPIRES on leaving the chapter
# (switch_chapter sets it absolutely), is drunk FIRST, and never sells.
var potions := 0
var potions_free := 0

# --- gear ---
var equipment := {}      # slot -> item Dictionary
var backpack: Array = []
var gem_bag: Array = []  # loose gems
# The BAGS are carried capacity for everything not equipped: gear
# (backpack), gem STACKS and consumables share their pooled slots. The
# hero equips UP TO Balance.MAX_BAGS bags and capacity is the SUM of
# their slots (round 52). Bags drop act-tiered from bosses/elites and
# stock at merchants. Start with two F pouches (Balance.STARTER_BAGS).
var bags: Array = Items.starter_bags()
var consumables: Array = []   # reset stones etc. ({"kind": "stone", ...})
# Q-rotation (playtest 2026-07-07): Q drinks the ACTIVE potion; the
# potion_next bind cycles health + every slotted rotation potion you
# actually carry. Both persist in the save.
var potion_rotation: Array = []    # consumable ids slotted for rotation
var active_potion := "health"      # "health" or a Items.ROTATION_POTIONS id
var potion_swap_cd := 0.0          # debounce for the held cycle key

# --- vitals ---
var max_hp := 100.0
var hp := 100.0
var max_mp := 50.0
var mp := 50.0
var dead := false

# --- derived stats (recalc() builds these; never write directly) ---
var primary := 12.0      # STR / AGI / INT value
var atk := 12.0
var speed := 250.0
var crit := 0.05
var crit_dmg := 1.5
var cdr := 0.0
var lifesteal := 0.0
var regen_pct := 0.0     # % of max HP regenerated per second (melee passives)
var sw_regen := 0.0      # Second Wind: extra regen once untouched for sw_delay
var sw_delay := 0.0
var since_hurt := 999.0  # seconds since the player last TOOK damage
var flat_dr := 0.0      # plate classes: flat damage reduction AFTER resists
var stab_ls_time := 0.0  # assassin: lifesteal surge window from a connecting stab
var stab_ls_amt := 0.0   # surge size — scales with MISSING health at the cut
var blink_dr := 0.0      # Arcane Ward: DR fraction Blink grants (mage passive)
var blink_dr_dur := 0.0  # how long that DR window lasts after a Blink
var dr_time := 0.0       # while > 0, incoming non-true damage is cut by dr_amt
var dr_amt := 0.0        # active damage-reduction fraction (multiplicative)
# Talent capstone survivability (2026-07-09 dominated-cell rework): defense the
# tree SELLS instead of dead cd-micro — earned by playing the button, per the
# floor-compensation doctrine (drip/window, never a free negate).
var tumble_dr := 0.0     # archer Windrunner: DR window after a Tumble roll
var veil_shield := 0.0   # mage Permafrost: max-HP shield frac on Nova/Blink cast
var oath_shield := 0.0   # paladin Unwavering Conviction: shield frac on stance swap
var cast_haste_time := 0.0  # Wind ult tailwind window (Blink/Frost Nova cdr)
var cast_haste_cdr := 0.0   # + this cdr on Blink/Frost Nova while it holds
var dash_guard_time := 0.0  # assassin Mirrorstep: AoE damage softened while > 0
var chill_dmg := 0.0        # mage Killing Frost talent: +dmg vs slowed/frozen
var poison_dmg := 0.0       # archer Serpent's Due talent: +dmg vs DoT'd enemies
var bolt_bleed := 0.0       # mage Wind Cuts talent: wind firebolt opens a bleed (frac/pt)
var nova_regen := 0.0       # ability-granted HoT rate (/s): mage Rimeheart (Nova)
                            # and paladin Hallowed Ground (Consecration) share it
var nova_regen_time := 0.0  # active heal-over-time window (recast renews)
var dash_refund := 0.0      # assassin Exsanguinate talent: + to Shadow Dash refund
var execute_dmg := 0.0      # assassin Coup de Grâce talent: +dmg to sub-40% enemies
var curse_dr := 0.0         # warlock Doomward talent: DR while any enemy is cursed
var crush_amp := 0.0        # warlock Rupture talent: +dmg to displaced (crush) targets
var void_crit := 0.0        # warlock Nightfall talent: +crit to crushing (Void) abilities
var curse_spread := 0.0     # warlock Contagion talent: curse-jump chance on a cursed death
var transfusion := 0.0      # warlock Transfusion talent: lifesteal overheal -> shield (cap frac)
var lowhp_dmg := 0.0        # warlock Sacrificial Might talent: +dmg while below 50% HP
var shield := 0.0           # current absorb shield (Transfusion overheal buffer)
var last_rites := 0.0       # warlock Last Rites talent: >0 enables the cheat-death
var last_rites_cd := 0.0    # cooldown on the cheat-death (60s)
var grit_regen := 0.0       # warrior Grit: +regen per stack (passive-derived)
var grit_cap := 0.0         # warrior Grit: max stacks (passive + Deep Grit talent)
var grit_res := 0.0         # warrior Stonehide talent: +phys/mag res per Grit stack
var grit_stacks := 0        # warrior Grit: current stacks (built by TAKING hits)
var grit_time := 0.0        # Grit window — lapses (and stacks die) if unhit too long
var paladin_mode := "holy"  # paladin Conviction stance: "holy" | "retribution"
var judgment_leap_cd := 0.0 # Judgment's leap rider arms every JUDGMENT_LEAP_CD
# Heal feedback (round 44): discrete mends (bulwark/holy on-hit, nova,
# kit drains) accumulate here and surface as one throttled green tick +
# soft chime — so per-hit spam (whirlwind, chains) stays readable. Route
# silent heals through gain_hp(); continuous lifesteal/regen stay quiet.
var heal_accum := 0.0
var heal_fx_cd := 0.0
var physres := 0.0
var magres := 0.0
var critres := 0.0
var eva := 0.0
var dex := 0.0
var physpen := 0.0
var magpen := 0.0
var combo := 0.0
var greed := 0.0

# --- input intents (multiplayer seam — MULTIPLAYER.md §6 phase 0) ---
# The simulation reads ONLY these fields; _poll_local_intents() fills them
# from the local device. Every legacy input site was a HELD-state
# Input.is_key_pressed poll (debounce lives in the cooldown timers: cds /
# potion_cd / potion_swap_cd / game.talk_cd), so plain booleans reproduce
# the semantics exactly. There is no mouse aim to capture: aim points come
# from locked_target/soft_target/facing — simulation state that intent_move
# (and the event-driven Tab lock) already drives. A remote peer's player
# returns is_locally_controlled() == false and gets these written by RPC;
# nothing below this layer knows the difference.
var intent_move := Vector2.ZERO   # normalized WASD/arrows vector
var intent_a1 := false            # ability keys, held state
var intent_a2 := false
var intent_a3 := false
var intent_ult := false
var intent_potion := false        # Q drink (potion_cd debounces)
var intent_potion_next := false   # R cycle (potion_swap_cd debounces)
var intent_interact := false      # E talk/open (game.talk_cd debounces)
# Target lock — EDGE intents, not held state: UI events set them (Tab/Space
# in hud.gd today; the mobile HUD lock button — tap to lock, hold-and-swipe-
# away to release — writes these same fields, MULTIPLAYER.md §10) and the
# player consumes-then-clears them in its physics step (≤1 frame, accepted).
# _poll_local_intents() deliberately leaves them alone: overwriting from
# device state each frame would eat the one-shot edge.
var intent_lock := false          # request: lock / cycle to the next target
var intent_lock_release := false  # request: drop the current hard lock


# --- multiplayer identity + remote presentation (MP-07, wave 4) ---
# All vars live in this base layer (chain rule). peer_id is the OWNING
# peer: 1 is the server/solo default; net_session.gd stamps every player
# with its owner when a session spawns it.
var peer_id := 1
# Wave-4 remotes are PRESENTATION: the owner broadcasts {pos, vel, look}
# at ~20 Hz (net_session.gd) and remotes render NET_LERP_MS in the past,
# lerping between the buffered snapshots (MULTIPLAYER.md §3.1).
const NET_LERP_MS := 120
var net_snaps: Array = []       # [{t, pos, vel, look}] arrival-stamped, newest last
var _net_mgr: Node = null       # cached transport autoload (by path — MP-05 gate trap)


## The remote-player seam: false for a player another peer owns — its
## intents never poll this device and player.gd's physics runs the
## presentation path only. Offline every player is yours (solo unchanged).
func is_locally_controlled() -> bool:
	if not is_inside_tree():
		return true
	if _net_mgr == null:
		_net_mgr = get_node_or_null("/root/NetworkManager")
	if _net_mgr == null or not bool(_net_mgr.is_online()):
		return true
	return peer_id == multiplayer.get_unique_id()


## Owner-side movement state arriving over the wire (net_session.gd's
## 20 Hz unreliable RPC). Arrival-stamped: the interpolation delay eats
## the jitter, so sender clocks never need aligning in wave 4.
func net_push_snapshot(pos: Vector2, vel: Vector2, look: float) -> void:
	net_snaps.append({"t": Time.get_ticks_msec(), "pos": pos, "vel": vel, "look": look})
	while net_snaps.size() > 4:
		net_snaps.pop_front()


# --- downed / revive / ghost (MP-12, MULTIPLAYER.md §5.3) ---
# ONLINE-SESSION-ONLY states — solo never sets any of these, so every
# `downed`/`ghost` check below the chain is a no-op offline. The OWNER's
# take_damage converts a lethal hit into DOWNED and broadcasts the state
# (net_session._rpc_down_state); shells mirror it for presentation and
# host-side AI reads (nearest_player skips downed prey).
#
# Taste defaults (MP-12 — candidates for a later balance.gd promotion;
# owner review in MP_TASKS PLAYTEST NOTES):
const DOWN_CRAWL_MULT := 0.35   # crawl speed while downed (fraction of move speed)
const DOWN_BLEEDOUT := 30.0     # s from downed to ghost
const REVIVE_REACH := 60.0      # px a reviver must stand within to channel
const REVIVE_CHANNEL := 3.0     # s of uninterrupted channel to revive
const REVIVE_HP_FRAC := 0.30    # revived / ghost-cleared players stand at this HP
var downed := false             # at 0 HP online: bleeding out, crawling, revivable
var ghost := false              # bleed-out expired: immaterial until the room clears
var down_t := 0.0               # bleed-out remaining (owner ticks; shells mirror it)
var being_revived_by := 0       # peer id channeling on this body (0 = none)
var revive_bar_ms := 0          # when that channel began (channel-bar presentation)
var revive_target = null        # reviver-side: the downed Player I'm channeling on
var revive_t := 0.0             # reviver-side channel progress (0..REVIVE_CHANNEL)
var _revive_req_ms := 0         # request throttle while the host's grant is in flight
var _down_ring: Node2D = null   # the bleed-out ring node (player_combat builds it)


## Fill the intents from the local device — same keys the old inline reads
## polled. Called at the top of the per-frame driver, AND as a refresh at
## the consumption sites that used to read Input live mid-frame (_move_dir,
## game.gd's interact check): held-state polling is idempotent within a
## frame, and the refresh keeps direct out-of-frame calls (autotest drives
## dashes/interact by synthesizing raw key events, then calling abilities
## between physics ticks) seeing exactly the live key state they always did.
func _poll_local_intents() -> void:
	if not is_locally_controlled():
		return  # remote: intents arrive by RPC, never from this device
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	intent_move = dir.normalized()
	var binds: Dictionary = game.binds
	intent_a1 = Input.is_key_pressed(binds["a1"])
	intent_a2 = Input.is_key_pressed(binds["a2"])
	intent_a3 = Input.is_key_pressed(binds["a3"])
	intent_ult = Input.is_key_pressed(binds["ult"])
	intent_potion = Input.is_key_pressed(binds["potion"])
	intent_potion_next = Input.is_key_pressed(binds.get("potion_next", KEY_R))
	intent_interact = Input.is_key_pressed(binds["interact"])
	if downed or ghost:
		# MP-12 (§5.3): while down, only movement remains — no abilities, no
		# potions, no interacting (being revived is passive). Zeroing at the
		# poll gates every consumer at once (game.gd's interact loop included).
		intent_a1 = false
		intent_a2 = false
		intent_a3 = false
		intent_ult = false
		intent_potion = false
		intent_potion_next = false
		intent_interact = false

# --- combat state ---
var cds := {"a1": 0.0, "a2": 0.0, "a3": 0.0, "ult": 0.0}
var potion_cd := 0.0
var hurt_cd := 0.0
var hurt_was_heavy := false    # the live hurt_cd window blocks HEAVY hits too: set by a landed
                               # heavy hit (boss telegraph) or a deliberate i-frame grant; a
                               # window armed by mere chip damage leaves this false, so a
                               # telegraph can pierce it (see player.gd take_damage)
var berserk_time := 0.0
var berserk_bonus := 0.4       # damage bonus while berserk (theme-tunable)
var next_crit := false         # Hunt: the next hit is a guaranteed crit
var hunt_rhythm := 0           # Hunt: Quick Shots fired since the last rhythm crit (Balance.HUNT_RHYTHM_SHOTS)
var dash_refund_t := 0.0       # Shadow phantom step: kill within this refunds the dash
var dash_refund_frac := 0.0    # ...how much of the dash cd a closing kill returns
var storm_time := 0.0
var storm_tick := 0.0
var storm_fx := {}
var theme_speed_time := 0.0
var theme_speed_amt := 0.0
var damp_time := 0.0     # Damp debuff: while > 0, move speed x Balance.DAMP_SLOW_MULT (river wading)
var wind_fx_t := 0.0     # throttle for the faint speed-buff wind trail
var elixir_time := 0.0   # Elixir of Might: +elixir_atk damage while > 0
var elixir_atk := 0.0
var goldrush_time := 0.0  # Gold Rush coin: greed surges while > 0 (run state, not saved)
var dodge_time := 0.0    # archer Tumble: temporary evasion window after the roll
var dodge_amt := 0.0     # +evasion CHANCE added while dodge_time > 0
var theme_guard_time := 0.0
var theme_guard_amt := 0.0
var hazard_speed := 1.0        # terrain patch effect (ice boosts, void slows)
# Crowd control the player can suffer (Act 1 ch5+ bosses). FROZEN =
# can't move OR cast (Serane's Flash Freeze, Halla's sleep); ROOTED =
# can't move but MAY still cast (Serane's Shatter Lance, ch6 roots).
var frozen_time := 0.0
var rooted_time := 0.0
var chill_time := 0.0          # mob frost-aura: movement slowed while > 0
var chill_mult := 1.0          # the active chill slow factor (rebuilt each frame)
var aegis_time := 0.0          # paladin Aegis: the shield is up
var aegis_amt := 110.0         # resistances granted while it holds
var aegis_reflect := 0.6       # smite multiplier on attackers
var aegis_proj_left := 0       # blocked projectiles answered this cast
var aegis_fx := {}             # theme payload captured at cast
var pact_time := 0.0           # warlock Dark Pact: lifesteal surge window
var pact_ls := 0.15
var hexed := {}                # warlock Hex: Enemy -> seconds left (explodes on death)
var hex_fx := {}               # theme payload captured when the curse landed
var wither := {}               # warlock: Enemy -> seconds of MAINTAINED hex uptime
                               # (stacks = uptime / Balance.WITHER_STACK_EVERY)
var melee_swing := 0.0         # held-weapon attack animation timer
var melee_style := "swing"     # "swing" (arc) or "stab" (thrust)
var melee_dir := Vector2.RIGHT
var cleave_seq := 0            # warrior Cleave: cycles the swing-arc variant
var facing := Vector2.RIGHT
var look_sign := 1.0           # which way the hero visually faces (+1 right)
var face_left := false         # does the sprite's art natively face left?
var anim_t := 0.0
var locked_target: Enemy = null
var soft_target: Enemy = null   # sticky auto-target (no Tab-lock); see player_combat
var pending_theme_note := ""   # set when a new theme unlocks (game shows it)

# per-cast theme payload (set by use_ability, read by ability helpers)
var _tfx := {}
var _tcolor := Color(1, 1, 1)
var _themed := false

var sprite: Sprite2D
var weapon_spr: Sprite2D
var weapon_glow: Sprite2D
var aura: Sprite2D
# Animation seam (Track C): set when assets/sprites/<class>_anim.png
# exists — a horizontal strip animated via Sprite2D.hframes.
# (anim_t above is the walk-bob clock; strip_t is the frame clock.)
var strip_frames := 0
var strip_fps := 6.0
var strip_t := 0.0
# Clip state machine (round: Custom sheets — full per-class animation set).
# _clips: name -> {tex,frames,fps}. Locomotion (idle/walk/run) loops; action
# clips (attack/cast/dash/ult/death) play once then fall back to locomotion.
var _clips := {}
var _clip := ""                # current clip name
var _clip_loop := true         # locomotion loops; one-shot actions do not
var _clip_locked := false      # death latch: hold last frame, ignore everything
# Aimed dash pose (see player_combat._aim_dash_pose): while an off-axis dash's
# one-shot plays, the L/R art is flipped to the travel side and rotated the
# rest of the way. Both cleared by the next _play_clip.
var _clip_rot := 0.0           # rotation held on the sprite (0 on a flat dash)
var _clip_flip := 0.0          # facing side (±1) forced while it plays; 0 = follow look_sign
# 8-DIRECTION locomotion (art audit 2026-07-10 seam): populated per clip
# only when assets/sprites/<class>_<clipfile>_<dir>.png exists. Empty for
# every current class, which keeps the single-facing + flip path untouched.
var _dir_loco := {}            # {clip name: 8-dir strip set}, empty if none
var _loco_dir := "s"           # current facing suffix while directional
var _loco_dir_on := false      # is directional locomotion driving the sprite?
var _action_dir_on := false    # is a directional ONE-SHOT (locked facing) playing?
var halo: PointLight2D = null  # the hero's soft light (dark terrains only)

## Per-class ability-slot -> action clip. Slots with no matching clip (or a
## class with no sheet) simply skip the one-shot. Tunable — maps each kit's
## four abilities onto the animation rows the artist authored.
const ABILITY_CLIP := {
	# Mapped to each kit's ACTUAL abilities: movement dashes -> dash clip,
	# swings -> attack/attack2, casters' AoE/summons -> cast/ult. "" = no
	# one-shot (defensive/buff ability keeps the locomotion pose).
	"warrior":  {"a1": "attack", "a2": "dash",    "a3": "attack2", "ult": "ult"},     # Cleave / Shield Bash / Whirlwind / Berserk
	"archer":   {"a1": "attack", "a2": "attack2", "a3": "dash",    "ult": "cast"},    # Quick Shot / Multishot / Tumble / Arrow Storm
	"mage":     {"a1": "attack", "a2": "cast",    "a3": "dash",    "ult": "cast"},    # Firebolt / Frost Nova / Blink / Meteor
	"assassin": {"a1": "attack", "a2": "dash",    "a3": "attack2", "ult": "attack2"}, # Stab / Shadow Dash / Fan of Knives / Death Mark
	"paladin":  {"a1": "attack", "a2": "attack2", "a3": "",        "ult": ""},        # Judgment / Consecration / Aegis / Conviction
	"warlock":  {"a1": "attack", "a2": "ult",     "a3": "attack2", "ult": "cast"},    # Shadowbolt / Hex / Dark Pact / Void Rift
}


## Point the hero Sprite2D at the class art — the animated strip when
## one is installed, the static texture otherwise.
## The Custom clip frames pad headroom around a feet-aligned character, so
## on-screen size can't key off the frame box. Instead we MEASURE the idle
## body height and scale it to a constant target, then offset the sprite so
## the feet land on the shadow. Both are tunable by taste.
const HERO_TARGET_BODY := 52.0   # on-screen character body height, px
const HERO_FEET_ANCHOR := 22.0   # feet sit this far below the node origin (shadow ~+20)

var _hero_scale := 1.0
var _hero_offset_y := 0.0

# Directional attack POSES (round: assassin-directions sheet). Some abilities
# aim in any of 360°, which a flat left/right swing clip can't track — so those
# show an 8-way pose picked by aim instead. _dir_clips: pose name -> strip info;
# _dir_meta: pose name -> {scale, offset}. Active while _dir_pose_t > 0.
var _dir_clips := {}
var _dir_meta := {}
var _dir_pose_active := false
var _dir_pose_t := 0.0       # elapsed time in the current directional animation
var _dir_base := 0           # first strip frame of the chosen direction (dir * K)
var _dir_k := 1              # sub-frames per direction (windup, action, ...)
const DIR_ANIM_DUR := 0.22   # seconds to play one direction's sub-frames

## Ability slots that show a directional aim POSE instead of a swing clip.
const DIR_POSE := {
	"assassin": {"a1": "stab", "a3": "throw"},   # Stab / Fan of Knives — aim the strike at the target
}

func _apply_class_sprite() -> void:
	var art_name: String = Classes.CLASSES[cls]["sprite"]
	face_left = Art.faces_left(art_name)
	_clips = Art.hero_clips(art_name)
	_clip = ""
	_clip_loop = true
	_clip_locked = false
	strip_frames = 0
	sprite.hframes = 1
	sprite.frame = 0
	_dir_clips = Art.hero_dir_clips(art_name)
	# 8-direction locomotion sets (idle/walk/run/... = <class>_<file>_<dir>).
	# Empty for every current class; lights up when directional art lands.
	_dir_loco = {}
	for clip in Art.HERO_CLIP_FILES:
		var ds := Art.dir_set("%s_%s" % [art_name, Art.HERO_CLIP_FILES[clip]])
		if not ds.is_empty():
			_dir_loco[clip] = ds
	_loco_dir_on = false
	_dir_meta = {}
	_dir_pose_active = false
	_clip_rot = 0.0   # a held dash pose dies with the old class's sprite
	_clip_flip = 0.0
	sprite.rotation = 0.0
	if _clips.has("idle"):
		var m := _measure_hero_frame(_clips["idle"])
		_hero_scale = m["scale"]
		_hero_offset_y = m["offset"]
		for pose in _dir_clips:
			_dir_meta[pose] = _measure_hero_frame(_dir_clips[pose])
		_play_clip("idle", true)
	else:
		# No animation strips installed: legacy static override / grid.
		sprite.offset = Vector2.ZERO
		sprite.texture = Art.tex(art_name)
		sprite.scale = Art.scale_for(sprite.texture, 3.0)


## Read a strip's first frame alpha to find body height + feet row, and derive
## the sprite scale (body -> constant on-screen size) + vertical feet offset.
## Returned per strip so a different-sized strip (e.g. directional poses) still
## renders the body at the same size and its feet on the shadow.
func _measure_hero_frame(info: Dictionary) -> Dictionary:
	var img: Image = info["tex"].get_image()
	var frames := int(info["frames"])
	var fw := int(img.get_width() / max(1, frames))
	var fh := img.get_height()
	var top := fh
	var bot := 0
	for y in fh:
		for x in fw:
			if img.get_pixel(x, y).a > 0.15:
				if y < top:
					top = y
				if y > bot:
					bot = y
				break
	var body_h := maxi(1, bot - top)
	var sc := HERO_TARGET_BODY / float(body_h)
	return {"scale": sc, "offset": HERO_FEET_ANCHOR / sc - float(bot) + float(fh) / 2.0}


## Facing for a directional ONE-SHOT action (attack/dash/ult...), locked at
## the moment it fires: toward the aimed target, else the movement, else the
## committed horizontal look. Mirrors the enemy's target-first action facing.
## Lives in the base layer so _play_clip (base) can call it.
func _action_facing_vec() -> Vector2:
	var t: Enemy = locked_target if is_instance_valid(locked_target) else soft_target
	if is_instance_valid(t) and not t.dead:
		return t.global_position - global_position
	if velocity.length() > 20.0:
		return velocity
	return Vector2(look_sign, 0.0)


## Point the hero Sprite2D at a clip. loop=false marks a one-shot action
## (attack/cast/dash/ult/death); the driver returns to locomotion when it ends.
func _play_clip(name: String, loop: bool) -> void:
	if not _clips.has(name):
		if name == "idle" or not _clips.has("idle"):
			return
		name = "idle"
		loop = true
	var info: Dictionary = _clips[name]
	_clip = name
	_clip_loop = loop
	# Any clip takeover releases special sprite states: a held dash pose
	# un-rotates, and an in-flight directional pose stops driving frames
	# (it doesn't own the strip on the sprite anymore).
	_clip_rot = 0.0
	_clip_flip = 0.0
	_dir_pose_active = false
	_loco_dir_on = false   # a clip change drops directional drive; the loco
	_action_dir_on = false # tail (loop) / the block below (one-shot) re-enable
	sprite.rotation = 0.0
	strip_frames = int(info["frames"])
	strip_fps = float(info["fps"])
	strip_t = 0.0
	sprite.texture = info["tex"]
	sprite.hframes = strip_frames
	sprite.frame = 0
	# 8-direction ONE-SHOT (attack/dash/ult/cast/death): lock facing now and
	# play that direction's strip. Locomotion clips get their facing per-frame
	# in _loco_dir_frame instead. No-op when the clip has no directional art.
	if not loop and _dir_loco.has(name):
		var suf: String = Art.dir8_suffix(_action_facing_vec())
		var dinfo: Dictionary = _dir_loco[name][suf]
		strip_frames = int(dinfo["frames"])
		strip_fps = float(dinfo["fps"])
		sprite.texture = dinfo["tex"]
		sprite.hframes = strip_frames
		sprite.flip_h = false
		_action_dir_on = true
	sprite.scale = Vector2(_hero_scale, _hero_scale)
	sprite.offset = Vector2(0, _hero_offset_y)


## Fire a one-shot action clip that returns to locomotion when it finishes.
## No-op while dead, with no sheet installed, or if the clip is absent.
func play_action(name: String) -> void:
	if _clip_locked or strip_frames == 0 or name == "":
		return
	if _clips.has(name):
		_play_clip(name, false)


## Play a DIRECTIONAL animation aimed by `dir`: an 8-way strip of K sub-frames
## per direction (windup -> action), picked by aim and played over DIR_ANIM_DUR,
## then back to locomotion. Returns true if it played. The art encodes its own
## facing, so the flip is suppressed while it runs.
func play_dir_anim(name: String, dir: Vector2) -> bool:
	if _clip_locked or not _dir_clips.has(name):
		return false
	var info: Dictionary = _dir_clips[name]
	var meta: Dictionary = _dir_meta.get(name, {"scale": _hero_scale, "offset": _hero_offset_y})
	var total := int(info["frames"])
	_dir_k = maxi(1, total / 8)
	_dir_base = _dir_index(dir) * _dir_k
	_dir_pose_active = true
	_dir_pose_t = 0.0
	_clip = "@dir"
	_clip_loop = false
	_clip_rot = 0.0       # the 8-way art encodes its own direction —
	_clip_flip = 0.0      # release any held dash rotation
	sprite.rotation = 0.0
	strip_frames = total
	sprite.texture = info["tex"]
	sprite.hframes = total
	sprite.frame = _dir_base
	sprite.flip_h = false
	sprite.scale = Vector2(meta["scale"], meta["scale"])
	sprite.offset = Vector2(0, meta["offset"])
	return true


## Aim vector -> frame in an 8-way pose strip ordered E,NE,N,NW,W,SW,S,SE.
func _dir_index(d: Vector2) -> int:
	if d == Vector2.ZERO:
		return 0
	var k := int(round(atan2(d.y, d.x) / (PI / 4.0)))   # -4..4 (screen: +y down)
	var lut := {0: 0, -1: 1, -2: 2, -3: 3, 4: 4, -4: 4, 3: 5, 2: 6, 1: 7}
	return lut.get(k, 0)


## Terminal death clip: play once, then hold the final frame forever.
func play_death_anim() -> void:
	if _clips.has("death"):
		_play_clip("death", false)
		_clip_locked = true


## Passive granted by an equipped S-grade weapon ("" if none). A DORMANT
## legendary (round 51b — looted/bought, passive_dormant) grants NOTHING until
## the class's awakening quest sets s_awakened_<cls>; this is the SINGLE gate —
## every kit/effect reads the passive through here. Legacy legendaries without
## the dormant marker (old saves, direct grants) stay active, ungrandfathered.
func s_passive() -> String:
	var w = equipment.get("weapon")
	if w == null or not w.has("passive"):
		return ""
	if w.get("passive_dormant", false) and not weapon_awakened(w):
		return ""
	return w["passive"]


## Is this S weapon's class awakened for this character? (persisted flag)
func weapon_awakened(w: Dictionary) -> bool:
	if game == null:
		return false
	return bool(game.get_flag("s_awakened_" + String(w.get("cls", cls)), false))


func _update_weapon_visual() -> void:
	if weapon_spr == null:
		return
	# The held-weapon icon no longer rides on the character sprite (taste pass
	# 2026-07-08): it cluttered the hero, and the S/A rarity glow read as an
	# orb stuck to the body. We still cache the texture so the melee arc's
	# leading blade can borrow the equipped weapon's look; it just never shows
	# as a persistent overlay.
	weapon_glow.visible = false
	var w = equipment.get("weapon")
	weapon_spr.texture = Art.weapon_tex(w.get("noun", "Blade"), w["grade"]) if w != null else null
	weapon_spr.visible = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13
	cs.shape = shape
	add_child(cs)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 20)
	add_child(shadow)

	# Buff aura: red while Berserk, blue while a guard buff is up.
	aura = Sprite2D.new()
	aura.texture = Art.tex("glow")
	aura.visible = false
	add_child(aura)

	sprite = Sprite2D.new()
	_apply_class_sprite()
	sprite.flip_h = face_left  # start facing right regardless of art
	add_child(sprite)

	# The shard-bearer sheds a faint warm light: invisible in daylight,
	# a small readable halo in dark-tinted terrains (void/grave/night).
	# Energy tracks the room's darkness (game.refresh_ambience).
	halo = Art.light(Color(1.0, 0.93, 0.8), 150.0, 0.0)
	halo.shadow_enabled = true  # walls occlude it (soft, dark-zone only)
	halo.shadow_color = Color(0, 0, 0, 0.35)
	halo.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(halo)

	weapon_spr = Sprite2D.new()
	weapon_spr.scale = Vector2(2.4, 2.4)
	weapon_spr.visible = false
	weapon_spr.z_index = 1
	add_child(weapon_spr)
	weapon_glow = Sprite2D.new()
	weapon_glow.texture = Art.tex("glow")
	weapon_glow.visible = false
	weapon_glow.scale = Vector2(1.1, 1.1)
	weapon_glow.z_index = 0
	add_child(weapon_glow)

	recalc()
	hp = max_hp
	mp = max_mp


func set_class(id: String) -> void:
	# Switching class REFUNDS all progression points instead of orphaning
	# them: spent tree points reference the OLD class's cells (they'd
	# silently stop existing), and attribute ratios differ per class.
	# Points respec, never vanish. (Save loading is unaffected: apply()
	# calls set_class on a fresh zero-point player, then sets the pools.)
	var refunded_skill := 0
	for tid in tree_points:
		refunded_skill += int(tree_points[tid])
	tree_points.clear()
	skill_points += refunded_skill
	var refunded_attr := 0
	for attr in attr_points:
		refunded_attr += int(attr_points[attr])
		attr_points[attr] = 0
	unspent_attr += refunded_attr
	cls = id
	ability_theme = {"a1": "", "a2": "", "a3": "", "ult": ""}
	hunt_rhythm = 0
	aegis_time = 0.0
	pact_time = 0.0
	paladin_mode = "holy"
	grit_stacks = 0
	grit_time = 0.0
	judgment_leap_cd = 0.0
	hexed.clear()
	wither.clear()
	themes_known = Classes.themes_unlocked(level)
	if themes_known > 0:
		var first: String = Classes.THEMES[cls][0]["id"]
		for slot in ability_theme:
			ability_theme[slot] = first
	if sprite:
		_apply_class_sprite()
		sprite.flip_h = face_left if look_sign > 0.0 else not face_left
	recalc()
	hp = max_hp
	mp = max_mp


# ================================================================== themes

func unlocked_theme_ids() -> Array:
	var out: Array = []
	for i in themes_known:
		out.append(Classes.THEMES[cls][i]["id"])
	return out


func set_ability_theme(slot: String, id: String) -> void:
	if id == "" or id in unlocked_theme_ids():
		ability_theme[slot] = id
		if slot == "a1":
			hunt_rhythm = 0  # hunt's rhythm counter never carries across a theme swap


## One click, one identity: assign a theme (or "" = base) to EVERY
## ability at once (round 18 QoL). Locked themes are refused per slot.
func set_all_themes(id: String) -> void:
	for slot in ability_theme:
		set_ability_theme(slot, id)


func _theme_fx(slot: String) -> Dictionary:
	var id: String = ability_theme.get(slot, "")
	if id == "":
		return {}
	# Per-ability variant package — each (ability, theme) pair is unique.
	return Classes.ability_fx(cls, slot, id)


func _theme_color(slot: String) -> Color:
	var id: String = ability_theme.get(slot, "")
	if id == "":
		return Color(1, 1, 1)
	return Classes.theme_by_id(cls, id).get("color", Color(1, 1, 1))


# ================================================================== stats

func xp_needed() -> int:
	# The curve assumes side rooms: skipping the optional wings of the
	# zone graph leaves you under-leveled for the boss doors (DESIGN.md).
	return Balance.XP_BASE + level * Balance.XP_PER_LEVEL


## Rebuild every derived stat: class base + passive + gear (incl. gems)
## + skill tree points.
func recalc() -> void:
	var base: Dictionary = Classes.CLASSES[cls]
	var b := {"atk_flat": 0.0, "atk_pct": 0.0, "dmg_pct": 0.0, "hp_flat": 0.0, "hp_pct": 0.0,
		"STR": 0.0, "AGI": 0.0, "INT": 0.0, "VIT": 0.0,
		"mp_flat": 0.0, "speed_pct": 0.0, "crit": 0.0, "crit_dmg": 0.0,
		"cdr": 0.0, "lifesteal": 0.0, "regen_pct": 0.0, "sw_regen": 0.0, "sw_delay": 0.0,
		"blink_dr": 0.0, "blink_dr_dur": 0.0, "flat_dr": 0.0,
		"tumble_dr": 0.0, "veil_shield": 0.0, "oath_shield": 0.0,
		"chill_dmg": 0.0, "poison_dmg": 0.0, "bolt_bleed": 0.0, "nova_regen": 0.0,
		"dash_refund": 0.0, "execute_dmg": 0.0,
		"curse_dr": 0.0, "crush_amp": 0.0, "void_crit": 0.0,
		"curse_spread": 0.0, "transfusion": 0.0, "lowhp_dmg": 0.0, "last_rites": 0.0,
		"grit_regen": 0.0, "grit_cap": 0.0, "grit_res": 0.0,
		"physres": 0.0, "magres": 0.0,
		"critres": 0.0, "eva": 0.0, "dex": 0.0, "physpen": 0.0, "magpen": 0.0,
		"combo": 0.0, "greed": 0.0}

	var passive: Dictionary = base.get("passive", {})
	for stat in passive:
		# Numeric stats only: passives also carry "text" and flag keys
		# like "manaless" (bool + float = runtime error, round 31).
		if passive[stat] is float or passive[stat] is int:
			b[stat] = b.get(stat, 0.0) + passive[stat]
	for slot in equipment:
		var stats := Items.stats_of(equipment[slot])
		for stat in stats:
			b[stat] = b.get(stat, 0.0) + stats[stat]
	# Set bonus: 2/4 pieces of your class's S legendary set grant escalating
	# stat bonuses (Items.SET_BONUSES). Only S gear of your OWN class counts.
	var set_pieces := Items.count_set_pieces(equipment, cls)
	var set_data: Dictionary = Items.SET_BONUSES.get(cls, {})
	for tier in ["2", "4"]:
		if set_pieces >= int(tier) and set_data.has(tier):
			for stat in set_data[tier]:
				b[stat] = b.get(stat, 0.0) + set_data[tier][stat]
	for id in tree_points:
		var cell := Skills.find_cell(cls, id)
		if cell.is_empty():
			continue
		var pts: int = tree_points[id]
		for stat in cell.get("bonus", {}):
			b[stat] = b.get(stat, 0.0) + cell["bonus"][stat] * pts
	# Theme-granted PASSIVE stats (standing bonuses, not per-hit fx). Only combo
	# today — shadow's a1 grants +5% combo, a spammer boon. Per-hit theme fx
	# (crit_bonus, dot, slow...) are read contextually in hit_enemy, never here.
	for slot in ability_theme:
		var tfx: Dictionary = _theme_fx(slot)
		if tfx.has("combo"):
			b["combo"] = b.get("combo", 0.0) + float(tfx["combo"])
	# Allocated attribute points: the four attributes convert at CLASS
	# scaling ratios (an assassin gets far more from AGI than from STR);
	# substat points (PhysRes, DEX, pens...) convert 1:1 for everyone.
	var attr_scale: Dictionary = Classes.ATTR_SCALE[cls]
	for attr in attr_points:
		# Allocated points PLUS gear attribute mains (2026-07-06): every
		# piece guarantees the class primary; both convert identically.
		var pts: float = float(attr_points[attr]) + b.get(attr, 0.0)
		if pts <= 0.0:
			continue
		var conv: Dictionary = Classes.SUBSTAT_SCALE.get(attr, attr_scale.get(attr, {}))
		for stat in conv:
			b[stat] = b.get(stat, 0.0) + conv[stat] * pts

	var hp_frac := hp / max_hp if max_hp > 0 else 1.0
	var mp_frac := mp / max_mp if max_mp > 0 else 1.0
	# Primary attribute (STR/AGI/INT) drives attack and a little crit.
	primary = base["atk"] + base["atk_lvl"] * (level - 1)
	# dmg_pct (Sunstone special gem) is a universal damage increase — it adds
	# to atk_pct's multiplier, so a class of any crit level values it.
	atk = (primary + b["atk_flat"]) * (1.0 + b["atk_pct"] + b["dmg_pct"])
	max_hp = (base["hp"] + base["hp_lvl"] * (level - 1) + b["hp_flat"]) * (1.0 + b["hp_pct"])
	max_mp = base["mp"] + base["mp_lvl"] * (level - 1) + b["mp_flat"]
	# Movement speed is SOVEREIGN (player rule, 2026-07-06): no gear, gem
	# or talent may touch it — only terrain (hazard_speed) and abilities
	# (theme_speed). Dodging is life or death; speed stays authored.
	speed = base["speed"]
	crit = 0.05 + b["crit"] + primary * 0.0006
	crit_dmg = 1.5 + b["crit_dmg"]
	# Anti-degeneracy caps (player-designed, 2026-07-06): the special
	# stats are gem-only and SOFT-KNEE'd regardless of source — beyond
	# the cap every point pays ~1/10 (never a dead stop). Late game may
	# lift the caps a notch by level (L80+); deliberately not built yet.
	cdr = Balance.soft_cap(maxf(0.0, b["cdr"]), Balance.CAP_CDR)
	lifesteal = Balance.soft_cap(maxf(0.0, b["lifesteal"]), Balance.CAP_LIFESTEAL)
	regen_pct = b["regen_pct"]
	sw_regen = b["sw_regen"]
	sw_delay = b["sw_delay"]
	if s_passive() == "windward":
		# Archer S weapon: Second Wind kicks in after 1.5s untouched, not 3s —
		# the endgame sustain fix (bullet-hell has brief gaps, not long lulls).
		sw_delay = maxf(0.5, sw_delay - 1.5)
	blink_dr = b["blink_dr"]
	blink_dr_dur = b["blink_dr_dur"]
	tumble_dr = b["tumble_dr"]
	veil_shield = b["veil_shield"]
	oath_shield = b["oath_shield"]
	chill_dmg = b["chill_dmg"]
	poison_dmg = b["poison_dmg"]
	bolt_bleed = b["bolt_bleed"]
	nova_regen = b["nova_regen"]
	dash_refund = b["dash_refund"]
	execute_dmg = b["execute_dmg"]
	curse_dr = b["curse_dr"]
	crush_amp = b["crush_amp"]
	void_crit = b["void_crit"]
	curse_spread = b["curse_spread"]
	transfusion = b["transfusion"]
	lowhp_dmg = b["lowhp_dmg"]
	grit_regen = b["grit_regen"]
	grit_cap = b["grit_cap"]
	grit_res = b["grit_res"]
	last_rites = b["last_rites"]
	flat_dr = b["flat_dr"]
	physres = b["physres"]
	magres = b["magres"]
	critres = b["critres"]
	eva = b["eva"]
	dex = b["dex"]
	physpen = b["physpen"]
	magpen = b["magpen"]
	# Plate EARNED DR: warrior scales it on physres, paladin on magres — 0 with
	# no armor, up to PLATE_DR_MAX at PLATE_DR_FULL_RES. Res is set above, so this
	# rides the built (gear + kit) value.
	if cls == "warrior":
		flat_dr += Balance.PLATE_DR_MAX * minf(1.0, physres / Balance.PLATE_DR_FULL_RES)
	elif cls == "paladin":
		flat_dr += Balance.PLATE_DR_MAX * minf(1.0, magres / Balance.PLATE_DR_FULL_RES)
	combo = Balance.soft_cap(maxf(0.0, b["combo"]), Balance.CAP_COMBO)  # soft knee
	greed = b["greed"]
	hp = clampf(max_hp * hp_frac, 1.0, max_hp)
	mp = clampf(max_mp * mp_frac, 0.0, max_mp)


## Heal that SHOWS: raise HP and bank the real (clamped) amount for the
## throttled green tick in _physics_process. Use for discrete mends the
## player should SEE; continuous lifesteal/regen stay silent by design.
func gain_hp(amount: float) -> void:
	if amount <= 0.0 or dead:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	heal_accum += hp - before
	# Transfusion (warlock talent): healing wasted at full HP pools into a
	# temporary shield, HARD-CAPPED so it never stacks past the limit.
	if transfusion > 0.0:
		var overflow := amount - (hp - before)
		if overflow > 0.0:
			shield = minf(transfusion * max_hp, shield + overflow)


func current_atk() -> float:
	var a := atk
	if berserk_time > 0.0:
		a *= 1.0 + berserk_bonus
	if elixir_time > 0.0:
		a *= 1.0 + elixir_atk  # Elixir of Might
	if lowhp_dmg > 0.0 and hp < max_hp * 0.5:
		a *= 1.0 + lowhp_dmg   # Sacrificial Might (warlock): blood-price aggression
	if cls == "paladin":
		# Conviction stance: Holy trades damage for mending, Retribution the
		# reverse — sustain and damage are never simultaneous (round 48).
		a *= Balance.PALADIN_HOLY_DMG if paladin_mode == "holy" else Balance.PALADIN_RETRI_DMG
	if cls == "warrior" or cls == "paladin":
		# PLATE res→damage: the plate classes' damage-scaling axis — over-stacked
		# resistance (past the survival knee) answers as a little damage, their
		# identity mirror to crit's crit_dmg. LOG curve (2026-07-09): diminishing
		# returns so endgame res can't buy top-chart DPS — it lifts the low-res
		# FLOOR, then flattens hard (linear+cap let it snowball to +19% at L100).
		a *= 1.0 + minf(Balance.PLATE_RES_DMG_CAP,
			Balance.PLATE_RES_DMG_LOG * log(1.0 + (physres + magres) * Balance.PLATE_RES_DMG_K))
	return a


func current_lifesteal() -> float:
	# Surges ADD to the stat (an assassin with 2% lifesteal proccing a
	# 26% surge drains at 28%) — and the TOTAL rides the same soft knee
	# as the stat, so temp windows can't smuggle past the cap either.
	return Balance.soft_cap(lifesteal + (0.15 if berserk_time > 0.0 else 0.0)
		+ (pact_ls if pact_time > 0.0 else 0.0)
		+ (stab_ls_amt if stab_ls_time > 0.0 else 0.0), Balance.CAP_LIFESTEAL)


## An attribute's TOTAL: everyone has a base of 5, allocation adds to it,
## and the class primary also carries the class's natural level growth.
func attr_total(attr: String) -> int:
	var total: int = 5 + attr_points.get(attr, 0)
	if Classes.CLASSES[cls]["primary"] == attr:
		total += int(primary)
	return total


## Summary block (attributes tab / quick views).
func stat_sheet() -> String:
	var unspent := "  (%d unspent — press T)" % unspent_attr if unspent_attr > 0 else ""
	return "STR %d  AGI %d  INT %d  VIT %d%s\nATK %d (%s)\nCrit %d%% (x%.1f)   Combo %d%%\nPhysRes %d   MagRes %d   CritRes %d\nEVA %d%%   DEX %d\nPen %d phys / %d mag\nHaste %d%%   Speed %d   Lifesteal %d%%   Greed %d%%" % [
		attr_total("STR"), attr_total("AGI"), attr_total("INT"), attr_total("VIT"), unspent,
		int(atk), Classes.CLASSES[cls]["dmg_type"],
		int(Stats.crit_curve(crit) * 100), crit_dmg, int(Stats.combo_curve(combo) * 100),
		int(physres), int(magres), int(critres),
		int(Stats.eva_curve(eva) * 100), int(dex),
		int(physpen), int(magpen),
		int(cdr * 100), int(speed), int(lifesteal * 100), int(Stats.greed_gold(current_greed()) * 100)]


# ==================================================================== gear

func bag_capacity() -> int:
	var total := 0
	for b in bags:
		total += int(b.get("slots", 0))
	return total


func consumable_count(id: String) -> int:
	var n := 0
	for c in consumables:
		if String(c.get("id", "")) == id:
			n += 1
	return n


# Capacity counts UNITS, not kinds (round 52b): every gear item, every
# gem, and every consumable UNIT eats one bag slot. Stacking is purely a
# DISPLAY convenience (the inventory groups "Mana Potion x12"), but all 12
# count here — 20 potions really is 20 slots. 2026-07-09 v2: HEALTH
# potions joined the count — `potions`/`potions_free` stay counters
# internally (save format unchanged), but every owned potion occupies a
# slot like any other consumable unit (bag tiers grew +5 to compensate).
func bag_used() -> int:
	return backpack.size() + gem_bag.size() + consumables.size() + potion_count()


# Bag-full adds return false with NO side effects — the caller decides
# what happens (game.give_loot drops it on the ground; the shop refuses
# the sale). Nothing is ever silently sold (playtest round 8).

func add_item(item: Dictionary) -> bool:
	if bag_used() >= bag_capacity():
		return false
	backpack.append(item)
	if String(item.get("grade", "")) == "S":
		game.unlock_achievement("s_gear")
	return true


## Loose gem pickup (chests, elites). Every gem UNIT costs a slot now
## (round 52b — capacity counts units, not kinds), so a full bag refuses
## the pickup and the caller drops/mails it. Internal gem machinery
## (synthesize, socket removal, sell-stripping) still appends directly and
## bypasses capacity so it never jams.
func gain_gem(gem: Dictionary) -> bool:
	if bag_used() >= bag_capacity():
		return false
	gem_bag.append(gem)
	if int(gem.get("lvl", 1)) >= Items.GEM_MAX_LEVEL:
		game.unlock_achievement("gem_max")
	return true


func add_consumable(c: Dictionary) -> bool:
	# Every consumable UNIT eats a slot (round 52b): a full bag refuses.
	if bag_used() >= bag_capacity():
		return false
	consumables.append(c)
	return true


# ------------------------------------------------------ potion loadout ---
# Playtest 2026-07-07 v2: potions are budgeted PER ROOM. The loadout is
# an ordered plan of chapter-band-capped slots (Balance.potion_slots);
# each slot holds a potion TYPE, duplicates welcome (3x health IS a plan).
# potion_rotation stores only the ASSIGNED slots — every unassigned slot
# defaults to health, so an untouched loadout is pure health potions.
# Entering a room refills the budget (room_potions, unsaved); each drink
# spends a slot; spent loadout = Q locked until the next room. Planning
# is the skill.

var room_potions := {}   # potion type -> uses left THIS room (unsaved)


func potion_slot_cap() -> int:
	return Balance.potion_slots(game.chapter_id)


## Total drinkable health-potion stock: bought potions + the expiring
## ch1-3 teaching freebie (potions_free).
func potion_count() -> int:
	return potions + potions_free


## Merchant buy guard: bought stock is capped (POTION_MAX) and every
## potion occupies a bag slot (2026-07-09 v2) — a full bag refuses the
## sale, same rule as gear/gems/consumables. No side effects; the shop
## shows the standard "Bag full!" feedback.
func can_gain_potion() -> bool:
	return potions < Balance.POTION_MAX and bag_used() < bag_capacity()


## Consume one health potion from stock — the EXPIRING freebie first (it
## dies with the chapter anyway; bought stock is the investment that keeps).
func spend_health_potion() -> void:
	if potions_free > 0:
		potions_free -= 1
	elif potions > 0:
		potions -= 1


## The full plan: assigned slots (clamped to cap) + health-fill.
func potion_loadout() -> Array:
	var cap := potion_slot_cap()
	var out: Array = []
	for id in potion_rotation:
		if out.size() >= cap:
			break
		out.append(String(id))
	while out.size() < cap:
		out.append("health")
	return out


## Room entry: the budget refills from the plan (game_world calls this
## on every room transition; death respawns cross a room, so they too).
func reset_room_potions() -> void:
	room_potions = {}
	for id in potion_loadout():
		room_potions[id] = int(room_potions.get(id, 0)) + 1
	if int(room_potions.get(active_potion, 0)) <= 0:
		active_potion = String(potion_loadout()[0])


func room_potions_left() -> int:
	var n := 0
	for id in room_potions:
		n += int(room_potions[id])
	return n


## Cycle Q among the types still budgeted THIS room (and stocked).
func cycle_potion() -> void:
	var types: Array = []
	for id in potion_loadout():
		if not types.has(id):
			types.append(id)
	if types.is_empty():
		return
	var at := maxi(types.find(active_potion), 0)
	for step in range(1, types.size() + 1):
		var cand: String = types[(at + step) % types.size()]
		if int(room_potions.get(cand, 0)) <= 0:
			continue
		if cand != "health" and consumable_count(cand) <= 0:
			continue
		if cand == active_potion:
			return  # nothing else available to swap to
		active_potion = cand
		game.sfx("ui_click")
		game.spawn_text(global_position + Vector2(0, -52),
			"POTION: %s  (%d use%s left this room)" % [potion_display_name(cand),
				int(room_potions[cand]), "" if int(room_potions[cand]) == 1 else "s"],
			Color(0.7, 0.9, 1.0))
		return


## Inventory loadout editing: SHIFT-click adds one slot of this type,
## CTRL-click removes one. Health fills whatever is left unassigned —
## so "planning health" (the bag's Health Potion entry, 2026-07-09 v2)
## frees the NEWEST assigned slot back to the health fill.
func loadout_add(id: String) -> void:
	if id == "health":
		if potion_rotation.is_empty():
			game.spawn_text(global_position + Vector2(0, -52),
				"Loadout is already pure health", Color(0.7, 0.9, 1.0))
			return
		var freed: String = String(potion_rotation.pop_back())
		if active_potion == freed and not potion_rotation.has(freed):
			active_potion = "health"
		game.sfx("ui_click")
		return
	if not (id in Items.ROTATION_POTIONS):
		return
	if potion_rotation.size() >= potion_slot_cap():
		game.spawn_text(global_position + Vector2(0, -52),
			"Loadout full — %d slot%s this chapter (CTRL-click removes)" % [potion_slot_cap(),
				"" if potion_slot_cap() == 1 else "s"], Color(1.0, 0.7, 0.4))
		return
	potion_rotation.append(id)
	game.sfx("ui_click")


func loadout_remove(id: String) -> void:
	if potion_rotation.has(id):
		potion_rotation.erase(id)
		if active_potion == id and not potion_rotation.has(id):
			active_potion = "health"
		game.sfx("ui_click")


func potion_display_name(id: String) -> String:
	if id == "health":
		return "Health Potion"
	for c in consumables:
		if String(c.get("id", "")) == id:
			return String(c["name"])
	match id:
		"mana_potion": return "Mana Draught"
		"elixir_might": return "Elixir of Might"
	return id


## Use a consumable from the bag (the bag UI calls this).
func use_consumable(c: Dictionary) -> void:
	if not consumables.has(c):
		return
	match str(c.get("id", "")):
		"reset_stone":
			var refunded := 0
			for attr in attr_points:
				refunded += int(attr_points[attr])
				attr_points[attr] = 0
			unspent_attr += refunded
			consumables.erase(c)
			recalc()
			game.sfx("levelup")
			game.spawn_text(global_position + Vector2(0, -56),
				"TALENTS RESET — %d points refunded (press T)" % refunded, Color(0.6, 0.9, 1.0))
		"tree_tome":
			var back := 0
			for id in tree_points:
				back += int(tree_points[id])
			tree_points.clear()
			skill_points += back
			consumables.erase(c)
			recalc()
			game.sfx("levelup")
			game.spawn_text(global_position + Vector2(0, -56),
				"SKILL TREE RESET — %d points refunded (press T)" % back, Color(0.6, 0.9, 1.0))
		"mana_potion":
			mp = minf(max_mp, mp + (max_mp - mp) * Balance.MANA_POTION_FRAC)
			consumables.erase(c)
			game.sfx("potion", 1.3)
			game.spawn_text(global_position + Vector2(0, -56), "MANA RESTORED", Color(0.5, 0.7, 1.0))
		"elixir_might":
			elixir_time = Balance.ELIXIR_MIGHT_DUR
			elixir_atk = Balance.ELIXIR_MIGHT_AMT
			consumables.erase(c)
			game.sfx("potion", 0.85)
			game.spawn_text(global_position + Vector2(0, -56), "MIGHT!", Color(1.0, 0.6, 0.3))
		"elixir_ward":
			dr_time = Balance.ELIXIR_WARD_DUR
			dr_amt = Balance.ELIXIR_WARD_AMT
			consumables.erase(c)
			game.sfx("potion", 0.75)
			game.spawn_text(global_position + Vector2(0, -56), "WARDED!", Color(0.5, 0.8, 1.0))
		"renewal_draught":
			if potion_cd > 0.0:
				return  # shares the drink cooldown — no chain-chugging past the gate
			potion_cd = 0.6
			gain_hp(max_hp * Balance.RENEWAL_HEAL_FRAC)
			consumables.erase(c)
			game.sfx("potion", 1.15)
			game.spawn_text(global_position + Vector2(0, -56), "RENEWED", Color(0.5, 1.0, 0.6))
		"recall_scroll":
			if game.recall_to_safe():
				consumables.erase(c)
				game.sfx("blink")


## A looted/bought bag joins the equipped set (capacity grows). A SIXTH
## bag auto-keeps the best Balance.MAX_BAGS by slot count; the worst is
## removed and cashes for a flat 1g (round 52; preserves the round-51
## anti-exploit — spare bags are never worth more than 1g). Returns true
## when the incoming bag was KEPT, false when it was the spare cashed out.
func acquire_bag(b: Dictionary) -> bool:
	bags.append(b)
	if bags.size() <= Balance.MAX_BAGS:
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -56),
			"BAG ADDED: %s (+%d slots) — %d/%d bags, %d total" % [b["name"], int(b["slots"]),
				bags.size(), Balance.MAX_BAGS, bag_capacity()], Color(0.95, 0.85, 0.5))
		return true
	# Over the cap: keep the best MAX_BAGS by slots, cash the smallest at 1g.
	var worst := 0
	for i in range(1, bags.size()):
		if int(bags[i].get("slots", 0)) < int(bags[worst].get("slots", 0)):
			worst = i
	var dropped: Dictionary = bags[worst]
	bags.remove_at(worst)
	gold += Balance.BAG_SELL_GOLD
	if dropped == b:
		# The incoming bag was the worst — nothing gained.
		game.spawn_text(global_position + Vector2(0, -50), "Spare bag — %dg" % Balance.BAG_SELL_GOLD, Color(1, 0.9, 0.4))
		return false
	game.sfx("levelup")
	game.spawn_text(global_position + Vector2(0, -56),
		"BAG UPGRADED: %s — best %d kept, spare +%dg (%d total)" % [b["name"],
			Balance.MAX_BAGS, Balance.BAG_SELL_GOLD, bag_capacity()], Color(0.95, 0.85, 0.5))
	return true


## Would acquiring a bag of this slot size actually raise capacity? False
## only when the set is already full (MAX_BAGS) AND every equipped bag is
## >= this one — acquire_bag would then just cash it for 1g. The shop uses
## this to GREY the buy so gold isn't wasted (round 52b).
func bag_would_improve(slots: int) -> bool:
	if bags.size() < Balance.MAX_BAGS:
		return true
	for b in bags:
		if int(b.get("slots", 0)) < slots:
			return true
	return false


func equip(item: Dictionary) -> void:
	# Class lock (player rule, 2026-07-06): a mage cannot wear an
	# assassin's boots. Unclassed items (legacy saves, dev tools) pass.
	var item_cls := String(item.get("cls", ""))
	if item_cls != "" and item_cls != cls:
		game.spawn_text(global_position + Vector2(0, -56),
			"%s gear — not yours to wear." % item_cls.capitalize(), Color(1.0, 0.7, 0.5))
		return
	var slot: String = item["slot"]
	# One special gem per STAT across your whole loadout (2026-07-08): refuse
	# to equip an item whose special gem duplicates one already worn elsewhere.
	for g in item.get("gems", []):
		var st := String(g["stat"])
		if st in Balance.SPECIAL_GEM_STATS and _special_in_other_slots(st, slot):
			game.spawn_text(global_position + Vector2(0, -56),
				"Already wearing a %s gem — one per stat." % Items.STAT_LABEL.get(st, st),
				Color(1.0, 0.7, 0.5))
			return
	backpack.erase(item)
	if equipment.has(slot):
		backpack.append(equipment[slot])
	equipment[slot] = item
	recalc()
	_update_weapon_visual()
	game.sfx("equip")


## Is a special gem of `stat` already socketed in an EQUIPPED item that isn't
## the one in `except_slot`? The per-character special-gem limit's core check.
func _special_in_other_slots(stat: String, except_slot: String) -> bool:
	for slot in equipment:
		if slot == except_slot:
			continue
		for g in equipment[slot].get("gems", []):
			if String(g["stat"]) == stat:
				return true
	return false


## Move an equipped item back to the bag, leaving the slot empty. False =
## no such item equipped, or the bag is full (the item stays worn).
func unequip(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	if bag_used() >= bag_capacity():
		return false
	backpack.append(equipment[slot])
	equipment.erase(slot)
	recalc()
	_update_weapon_visual()
	game.sfx("equip")
	return true


## Pull all gems out of an item back into the gem bag (used when selling).
func strip_gems(item: Dictionary) -> void:
	for gem in item.get("gems", []):
		gem_bag.append(gem)
	item["gems"] = []


## Why this gem can't socket into this item — "" means it CAN. Centralizes
## the TYPED-SLOT rules (2026-07-08) so the inventory can EXPLAIN a refusal
## right on the gem's row instead of failing silently: A+ gear has ONE
## special-only slot + regular slots; B and below are regular-only. Special
## gems (Haste/CDR/Combo/Lifesteal/Tenacity/Dmg%) go ONLY in the special slot,
## regular gems only in regular slots — and specials are limited to ONE of
## each stat across your whole equipped loadout. Can't stack, can't skip.
func gem_socket_error(item: Dictionary, gem: Dictionary) -> String:
	if item.get("gems", []).size() >= int(item.get("gem_slots", 0)):
		return "No open sockets."
	# A vessel holds what it can bear: B ≤ Lv3, A ≤ Lv6, S ≤ Lv10.
	var lvl_lim: int = Items.GEM_LEVEL_LIMIT.get(String(item.get("grade", "")), 0)
	if int(gem["lvl"]) > lvl_lim:
		return "%s gear holds gems up to Lv%d." % [String(item.get("grade", "?")), lvl_lim]
	# Typed-slot capacity: count what's already socketed by type.
	var grade := String(item.get("grade", ""))
	var spec_cap: int = Items.special_slots(grade)
	var reg_cap: int = int(item.get("gem_slots", 0)) - spec_cap
	var spec_used := 0
	var reg_used := 0
	for g in item.get("gems", []):
		if String(g["stat"]) in Balance.SPECIAL_GEM_STATS:
			spec_used += 1
		else:
			reg_used += 1
	var stat := String(gem["stat"])
	if stat in Balance.SPECIAL_GEM_STATS:
		if spec_cap <= 0:
			return "Needs an A+ special slot."
		if spec_used >= spec_cap:
			return "Special slot already filled."
		# One of each special stat across the whole equipped loadout.
		var dup := _special_in_other_slots(stat, String(item.get("slot", "")))
		if not dup:
			for socketed in item.get("gems", []):
				if String(socketed["stat"]) == stat:
					dup = true
					break
		if dup:
			return "Already wearing a %s gem." % Items.STAT_LABEL.get(stat, stat)
	elif reg_used >= reg_cap:
		return "No regular slot free (special-only)."
	return ""


## Socket a specific gem into a specific item (the player chooses both).
func embed_gem_into(item: Dictionary, gem: Dictionary) -> bool:
	# Feedback used to float in the WORLD as spawn_text — HIDDEN behind the
	# open inventory, so a refusal read as "nothing happened" until you closed
	# the menu. The inventory now reads gem_socket_error() directly and shows
	# the reason IN-PANEL; this world text is only for non-menu callers.
	var err := gem_socket_error(item, gem)
	if err != "":
		game.spawn_text(global_position + Vector2(0, -56), err, Color(1.0, 0.7, 0.5))
		return false
	item["gems"].append(gem)
	gem_bag.erase(gem)
	recalc()
	game.sfx("levelup")
	return true


## Pop one gem out of an item's socket back into the bag.
func remove_gem(item: Dictionary, index: int) -> void:
	var gems: Array = item.get("gems", [])
	if index < 0 or index >= gems.size():
		return
	gem_bag.append(gems[index])
	gems.remove_at(index)
	recalc()
	game.sfx("potion")


## One click, zero tedium: repeatedly synthesize everything possible.
## Socketed gems on equipped gear are upgraded FIRST (a socketed gem +
## two matching bag gems levels up in place), then the bag combines
## 3-of-a-kind until nothing can be merged any more. Returns the number
## of upgrades performed.
func auto_synthesize() -> int:
	var upgrades := 0
	while true:
		# Equipped gems always get first pick of the bag — even of gems
		# the bag itself just merged into existence.
		if _upgrade_equipped_once():
			upgrades += 1
			continue
		if _bag_merge_once():
			upgrades += 1
			continue
		break
	if upgrades > 0:
		recalc()
		game.sfx("levelup")
	return upgrades


## Level up ONE socketed gem in place (eats two matching bag gems).
func _upgrade_equipped_once() -> bool:
	for slot in equipment:
		for gem in equipment[slot].get("gems", []):
			if gem["lvl"] < Items.GEM_MAX_LEVEL and _take_from_bag(gem["stat"], gem["lvl"], 2):
				gem["lvl"] += 1
				if gem["lvl"] >= Items.GEM_MAX_LEVEL:
					game.unlock_achievement("gem_max")
				return true
	return false


## Merge ONE 3-of-a-kind in the bag, lowest levels first.
func _bag_merge_once() -> bool:
	for lvl in range(1, Items.GEM_MAX_LEVEL):
		for stat in Items.GEM_STATS:
			if synthesize(stat, lvl, true):
				return true
	return false


## Remove `count` bag gems matching stat+level. All or nothing.
func _take_from_bag(stat: String, lvl: int, count: int) -> bool:
	var found: Array = []
	for gem in gem_bag:
		if gem["stat"] == stat and gem["lvl"] == lvl:
			found.append(gem)
			if found.size() == count:
				break
	if found.size() < count:
		return false
	for gem in found:
		gem_bag.erase(gem)
	return true


## 3 gems of the same stat & level -> 1 gem of the next level.
## quiet: skip the sound (auto-synthesize merges dozens in one frame —
## overlapping copies of the same sample phase into digital mush).
func synthesize(stat: String, lvl: int, quiet := false) -> bool:
	if lvl >= Items.GEM_MAX_LEVEL:
		return false
	if not _take_from_bag(stat, lvl, 3):
		return false
	gem_bag.append(Items.make_gem(stat, lvl + 1))
	if lvl + 1 >= Items.GEM_MAX_LEVEL:
		game.unlock_achievement("gem_max")
	if not quiet:
		game.sfx("levelup")
	return true


# =============================================================== progression

func gain_xp(amount: int) -> void:
	# A finished chapter pays NO XP on replays — farm gold and gear,
	# never levels (playtest round 3: "clear ch1 2000 times, come out
	# max level"). Dev mode keeps its level buttons for testing.
	if game.get_flag("completed_" + game.chapter_id, false) and not game.dev_mode:
		return
	xp += amount
	game.spawn_text(global_position + Vector2(0, -56), "+%d XP" % amount, Color(1.0, 0.9, 0.4))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += Balance.SKILL_POINTS_PER_LEVEL
		unspent_attr += Balance.ATTR_POINTS_PER_LEVEL
		recalc()
		_check_level_achievements()
		# NO free full heal on level-up (round 10): early levels come
		# fast, and the resets made potions — and merchants — pointless.
		# recalc() keeps your hp/mp FRACTION as the pools grow.
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -72), "LEVEL UP!  Lv %d  (+1 skill, +1 attribute point — press T)" % level, Color(0.5, 0.9, 1.0))
		var unlocked := Classes.themes_unlocked(level)
		if unlocked > themes_known:
			themes_known = unlocked
			var theme: Dictionary = Classes.THEMES[cls][unlocked - 1]
			pending_theme_note = theme["name"]
			if unlocked == 1:
				for slot in ability_theme:
					ability_theme[slot] = theme["id"]


## Level milestones (checked after any level-up).
func _check_level_achievements() -> void:
	if level >= 20:
		game.unlock_achievement("level_20")
	if level >= 40:
		game.unlock_achievement("level_40")


## Spend unallocated attribute points (STR/AGI/INT/VIT).
func add_attr_points(attr: String, n: int) -> bool:
	if unspent_attr <= 0 or not attr_points.has(attr):
		return false
	var spend := mini(n, unspent_attr)
	attr_points[attr] += spend
	unspent_attr -= spend
	recalc()
	game.sfx("levelup")
	return true


## One number that approximates total power (gear + gems + level +
## attributes + tree). Shown under the gold display.
func combat_rating() -> int:
	var crit_eff := Stats.crit_curve(crit)
	var offense := atk * (1.0 + crit_eff * (crit_dmg - 1.0)) * 3.0
	offense *= 1.0 + (physpen + magpen) * 0.01
	offense *= 1.0 + Stats.combo_curve(combo) * 0.5
	offense *= 1.0 + cdr * 0.6
	var defense := max_hp * 0.35 + (physres + magres) * 1.2 + critres * 0.8
	defense *= 1.0 + Stats.eva_curve(eva) * 0.8
	var utility := max_mp * 0.3 + speed * 0.2 + lifesteal * 250.0 + dex * 1.0
	return int(round(offense + defense + utility))


func add_tree_point(id: String) -> bool:
	if skill_points <= 0 or not Skills.can_add(cls, id, tree_points, level):
		return false
	skill_points -= 1
	tree_points[id] = tree_points.get(id, 0) + 1
	recalc()
	game.sfx("levelup")
	return true


## Sum of ability modifiers for one slot from tree points.
func _amod(slot: String, field: String) -> float:
	var total := 0.0
	for id in tree_points:
		var cell := Skills.find_cell(cls, id)
		if cell.is_empty():
			continue
		total += cell.get("amod", {}).get(slot, {}).get(field, 0.0) * tree_points[id]
	return total


func dm(slot: String) -> float:
	return 1.0 + _amod(slot, "dmg")


func ability_cd(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	if slot == "ult":
		# ULTS ignore haste, EVERY class (player rule 2026-07-06: there's
		# a reason they're called ults). Authored ult-cd TALENTS still
		# apply — those are design-owned, not stat-stacking. The assassin's
		# Death Mark stays FULLY fixed, talents included (round 38).
		if cls == "assassin":
			return float(ab["cd"])
		return maxf(0.1, ab["cd"] * (1.0 + _amod(slot, "cd")))
	if cls == "assassin" and slot == "a2":
		# Shadow Dash: this is the WHIFF cd — floored so gear cdr can't push
		# it below DASH_WHIFF_FLOOR. A connecting refund (in _dash_strike)
		# claws it down to the tighter connect floor; excess cdr converts to
		# dash-hit power instead. No cd amod — Exsanguinate feeds the refund.
		return maxf(Balance.DASH_WHIFF_FLOOR, ab["cd"] * (1.0 - cdr))
	var base_cd: float = ab["cd"]
	if cls == "warrior" and slot == "a1" and berserk_time > 0.0:
		# Berserk hands Cleave its old cadence back (round 49): the taxed
		# authored cd applies only while the rage sleeps.
		base_cd = Balance.BERSERK_CLEAVE_CD
	var cd: float = base_cd * (1.0 + _amod(slot, "cd"))
	if cast_haste_time > 0.0 and (slot == "a2" or slot == "a3"):
		# Wind ult TAILWIND: Blink and Frost Nova cool down quicker for the
		# window — mobility and the heal come back sooner for tight rotations.
		cd *= 1.0 - cast_haste_cdr
	if s_passive() == "wellspring" and (slot == "a2" or slot == "a3"):
		cd *= 0.92  # mage S weapon: Frost Nova & Blink cool down 8% faster
	cd = cd * (1.0 - cdr)
	if cls == "warrior" and slot == "a1" and berserk_time <= 0.0:
		# Cleave has a HARD cd floor cdr can't pierce — plate hits hard, not fast,
		# so stacked endgame cdr/haste can't spin the basic into a caster's
		# cadence. Only Berserk (which sets base_cd to the tighter BERSERK value
		# above, bypassing this branch) drops it below the floor — the burst
		# window is where the fast blade lives.
		cd = maxf(Balance.CLEAVE_FLOOR_CD, cd)
	return maxf(0.1, cd)


func ability_cost(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	return maxf(0.0, ab["mp"] * (1.0 + _amod(slot, "mp")))


## Greed as consumed: the built stat plus a live Gold Rush surge. Since
## the greed gem retired (2026-07-09) the surge is greed's only source.
func current_greed() -> float:
	return greed + (Balance.GOLDRUSH_GREED if goldrush_time > 0.0 else 0.0)


func gain_gold(amount: int) -> void:
	gold += int(amount * (1.0 + Stats.greed_gold(current_greed())))


