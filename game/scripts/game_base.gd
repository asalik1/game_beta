## GAME, layer 1 of 4 — state, flags, the conversation engine, room
## graph lookups/geometry, music/sfx/fx primitives and the autosave.
## The class is split across an inheritance chain so each file stays
## readable while code moves verbatim:
##   game_base.gd <- game_world.gd <- game_flow.gd <- game.gd (class_name Game)
extends Node2D
## The conductor. Builds the world as a ZONE GRAPH — rooms on a grid,
## connected N/S/E/W, built lazily on first entry — spawns the player,
## enemies, merchants and bosses, runs the story beats, and handles
## loot drops, death and victory.
##
## Rooms are the chapter's "zones" array (index = room id, still called
## zone_idx on enemies). Graph-authored rooms carry "coord"/"exits"
## (see Story.ZONES); legacy chapters without coords are auto-converted
## to a west→east chain and their positions rescaled to the room size.

const TILE := 48
const TILES_W := 44              # rooms grew: ~2 screens of walkable space
const TILES_H := 26
const ROOM_W := TILES_W * TILE   # 2112
const ROOM_H := TILES_H * TILE   # 1248
const ROOM_CENTER := Vector2(ROOM_W, ROOM_H) / 2.0
# Legacy zone-authoring space (Chapter 2 content modules): positions
# written for the old 34x15 strip get rescaled into the bigger rooms.
const LEGACY_W := 34 * TILE
const LEGACY_H := 15 * TILE
const DOOR_TILES := 3            # door gap width, in tiles
const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}

# Touchscreen mode: true on a mobile export or with the --touch dev arg. Base-layer
# flag (game/ is the source of truth); desktop stays false, so every touch-aware UI
# branch below collapses to the keyboard path with no per-platform fork.
var touch_mode: bool = OS.has_feature("mobile") or ("--touch" in OS.get_cmdline_user_args())
var _touch_hud: TouchHud = null   # on-screen controls, mounted by game._apply_touch_mode when touch_mode


## Recompute touch_mode from OS defaults + the persisted control-scheme setting
## (Settings > Controls: Keyboard / Touch). Called after settings load and on toggle.
func refresh_touch_mode() -> void:
	touch_mode = OS.has_feature("mobile") or ("--touch" in OS.get_cmdline_user_args()) or bool(settings.get("touch_controls", false))


## Rewrite keyboard prompts ("press E/Q/Space") into touch wording in player-facing
## strings when on a touchscreen — a no-op on desktop, so authored text keeps its
## keyboard phrasing on PC. Applied at display points (quest line, dialogue). Menu
## close-hints are handled separately in menus._hint.
func touchify(s: String) -> String:
	if gamepad != null and gamepad.active:
		for spec in [["E", "interact"], ["Q", "potion"], ["T", "skills"], ["Space", "interact"]]:
			s = _replace_key_prompt(s, "press " + spec[0], "press " + gamepad.label(spec[1]))
			s = _replace_key_prompt(s, "Press " + spec[0], "Press " + gamepad.label(spec[1]))
			s = _replace_key_prompt(s, "hold " + spec[0], "hold " + gamepad.label(spec[1]))
			s = _replace_key_prompt(s, "Hold " + spec[0], "Hold " + gamepad.label(spec[1]))
		return s.replace("E — ", gamepad.label("interact") + " — ")
	if not touch_mode:
		return s
	s = _replace_key_prompt(s, "Hold E", "Hold Act")
	s = _replace_key_prompt(s, "hold E", "hold Act")
	# Quest copy names the NPC with a gendered pronoun; keep the action copy
	# grammatical and match the touch HUD's actual interaction-button label.
	s = _replace_key_prompt(s, "walk up to her and press E", "walk up to her and tap Act")
	s = _replace_key_prompt(s, "walk up to him and press E", "walk up to him and tap Act")
	s = _replace_key_prompt(s, "and press E", "and tap Act")
	s = _replace_key_prompt(s, "press E", "tap")
	s = _replace_key_prompt(s, "press Q", "tap the potion button")
	s = _replace_key_prompt(s, "Press Q", "Tap the potion button")
	s = _replace_key_prompt(s, "press Space", "tap")
	s = _replace_key_prompt(s, "Press Space", "Tap")
	s = _replace_key_prompt(s, "press T", "tap Skills")
	s = _replace_key_prompt(s, "Press T", "Tap Skills")
	s = s.replace("E — ", "")   # NPC over-head prompts: "E — Talk" -> "Talk"
	return s


## These authored phrases contain literal words only. Match the complete key
## token: "press E" must not rewrite "press ESC", nor "T" inside "Tactics".
func _replace_key_prompt(s: String, prompt: String, replacement: String) -> String:
	if not s.contains(prompt):
		return s
	var pattern := RegEx.new()
	pattern.compile("\\b" + prompt + "\\b")
	return pattern.sub(s, replacement, true)


## Explicit UI-instruction copy. Dialogue deliberately does not use this:
## the word "click" can be story prose there rather than a pointer command.
func ui_copy(s: String) -> String:
	if not touch_mode:
		return s
	s = touchify(s)
	s = s.replace("press any key", "tap to continue")
	s = s.replace("Press any key", "Tap to continue")
	s = s.replace("Enter to begin", "Tap Begin to continue")
	s = s.replace("ESC to change class", "select Back to change class")
	s = s.replace("ESC to go back", "select Back to return")
	s = s.replace("ESC to cancel", "select Back to cancel")
	s = s.replace("Press to return", "Tap to return")
	s = s.replace("Click", "Tap")
	s = s.replace("click", "tap")
	return s


## A live binding on keyboard, the painted on-screen control on touch.
func control_hint(action: String, touch_label: String) -> String:
	if gamepad != null and gamepad.active:
		return "[%s]" % gamepad.label(action)
	if touch_mode:
		return touch_label
	return "[%s]" % OS.get_keycode_string(binds.get(action, KEY_NONE))
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}

# ------------------------------------------------------------- chapters ---
# The world is data: Story.CHAPTER_LIST[chapter_id] decides the rooms,
# starting quest and final boss. switch_chapter() rebuilds everything.
var chapter_id := "ch1"
var _pre_capital_chapter := ""  # chapter to return to when leaving Crownfall via the Story gate
var zones: Array = []            # this chapter's room dicts
var zone_count := 0
var rooms: Array = []            # runtime graph meta per room:
                                 # {coord: Vector2i, exits: {dir: lock}, scale: Vector2, origin: Vector2}
var coord_to_room := {}          # Vector2i -> room index
var world: Node2D = null         # every world node lives under here

const ST_PLAYING := 0
const ST_DEAD := 2
const ST_VICTORY := 3

# (Zone tint and weather now come from the terrain registry — terrains.gd.)

var state := ST_PLAYING
# --------------------------------------------------- player registry (MP) ---
# Phase 0 groundwork (MULTIPLAYER.md §6): the game tracks a REGISTRY of
# players. Solo holds exactly one entry — kept in sync by the `player`
# setter — so every registry query trivially returns THE player and
# behavior stays bit-identical by construction. `player` remains the
# legacy alias while call sites migrate deliberately.
# MP-07 (wave 4): the registry is the FULL session roster now. `player`/
# `local_player` remain YOUR OWN player — the setter registers-or-replaces
# your slot and never touches remote entries; remote peers' players come
# and go through register_remote_player()/unregister_player().
var players: Array[Player] = []   # every player in the session (solo: one)
var local_player: Player = null   # the player THIS machine controls
var player: Player:               # legacy alias — YOUR OWN player
	set(value):
		var old := local_player
		player = value
		local_player = value
		if value == null:
			# Dropping your player empties YOUR slot only; remote
			# entries (co-op) stay registered. Solo: players had just
			# that one entry, so this is the old players.clear().
			if old != null:
				players.erase(old)
			return
		var slot: int = players.find(old) if old != null else -1
		if slot >= 0:
			players[slot] = value
		else:
			players.append(value)
var hud: Hud
var menus: Menus
var gamepad: Node
var camera: Camera2D
var ambient: CanvasModulate
var glow_env: WorldEnvironment
var reticle: Sprite2D

# Rebindable keys. Movement is always WASD/arrows; ESC is fixed.
var binds := {
	"a1": KEY_J, "a2": KEY_K, "a3": KEY_L, "ult": KEY_U,
	"potion": KEY_Q, "interact": KEY_E, "inventory": KEY_I, "skills": KEY_T,
	"codex": KEY_C, "target": KEY_TAB, "map": KEY_M,
	"potion_next": KEY_R,  # cycles the Q-rotation (R only restarts at the victory screen)
}

var quest_key := "talk"
var talked_to_elder := false
var talk_cd := 0.0
var cur_room := 0                # the room YOUR player occupies (camera/music/ambience)
var last_room := -1              # previous frame's room (change detection)
# MP (MULTIPLAYER.md §4.3): the SIM gate — the union of every player's
# room, recomputed each frame from the registry. Solo it is exactly
# {cur_room}, so the enemy freeze rule stays bit-identical. Each instance
# computes its own union (it sees every player's position).
var active_rooms := {0: true}    # room idx -> true
var play_started := false

# ---------------------------------------------------------- room state ---
var built := {}                  # room idx -> true (world nodes exist)
var visited := {}                # room idx -> true (fog of war; saved)
var cleared := {}                # room idx -> true (packs dead; saved)
var door_seen := {}              # room idx -> true (its door was visible from
                                 # an adjacent visited room; boss marker on map)
var last_safe_room := 0          # death returns you here

var elder: Node2D
var pet_follower: Sprite2D = null  # Q16 cosmetic companion; lags the local player, rebuilt with the world
var remote_pet_followers: Dictionary = {}  # owner instance id -> {owner, visual}; replacement-safe
var interactables: Array = []    # [{node, prompt, action}]
var active_facing_interactable: Dictionary = {} # NPC temporarily turned toward the local player
var interact_in_range := false   # is the player next to any interactable? (touch Act-button gate)
var gates := {}                  # edge key "a_b" -> gate Node2D (locked edges only)
var zone_alive := {}             # room index -> monsters still alive
var boss_spawned := {}
var boss_done := {}
var bosses: Array = []           # every LIVE boss (endgame: up to 5 at once)
var current_boss: Boss = null    # the DISPLAYED boss: your target, else bosses[0]
var shop_stock := {}             # room index -> Array of items for sale
var shop_bags := {}              # room index -> Array of bags for sale (round 52)
# Capital bazaar (2026-07-25 rework): the plaza shop restocks at dawn instead
# of holding stock until bought out. Character-owned (rides the save) — the
# capital is this hero's home base, and the daily roll is theirs alone.
var capital_stock: Array = []
var capital_bags: Array = []
var capital_shop_day := -1       # daily_day_index() of the last restock
# Victory way-gates (2026-07-25 rework §6): the chapter-end choice moved off
# the blocking card into three world gates at the arena. True while they
# stand — advance/reprise accept it in place of ST_VICTORY.
var victory_gates_up := false

# Endgame modes (ACT2_DESIGN.md §II): the controller runs The Crucible / Waking
# Depths in one arena world. `endgame_active` fences campaign autosave off the
# arena chapter (rewards bank home via write_character_home only — see autosave)
# and lets the death flow settle the run instead of respawning (game_flow).
var endgame: Endgame = null
var endgame_active := false

# PvP duels (v1, 2026-08-01): pvp.gd runs a 1v1 in the throwaway pvp_arena
# world. `pvp_active` fences saves (autosave writes NOTHING — the duel has no
# stakes), map travel, the co-op wipe census and potions; the lethal-hit
# branch (player.gd) reports a FALL to the controller instead of downing.
# Typed Node so the base layer never depends on the derived controller class.
var pvp: Node = null
var pvp_active := false

# ------------------------------------------------------- fight report ---
# Benchmark instrument: boss fights are timed from FIRST BLOOD (either
# direction) to the roster emptying, and the kill prints a report —
# TTK, realized dps (boss HP pool / kill time), damage taken, potions,
# wipes. Wipes accumulate across retries and reset when a report lands.
var fight_active := false
var fight_time := 0.0            # live fight seconds (frame-accumulated)
var fight_dmg_taken := 0.0       # player HP actually lost during the fight
var fight_potions := 0
var fight_wipes := 0
var fight_pool := 0.0            # summed max HP of every boss that joined
var fight_names: Array = []      # roster, as "kind LvN" (log/benchmark line)
var fight_titles: Array = []     # roster, as display names (the victory letter)
var fight_kinds: Array = []      # roster, as raw kinds (personal-best records)
var fight_seen := {}             # boss instance id -> true (already pooled)
var last_fight_report := ""      # most recent report (tests / dev panel)

# ------------------------------------------------- party battle stats ---
# Per-player damage / healing / damage-taken meters (the CQ battle-stats
# pattern). DAMAGE is host-authoritative — every real hit lands through
# enemy.take_damage on the host, attributed via hit_src/stat_src — while
# HEAL and TAKEN accumulate on each player's OWNER (its machine runs
# gain_hp/take_damage) and ride the session's stat sync to the host.
# The host fans the merged table to guests ~1 Hz for the live meter.
# Solo: one bucket, peer 1 — the endgame results card reads it too.
var party_stats := {}   # peer id -> {name, cls, dmg, heal, taken} — RUN window
var fight_stats := {}   # same shape, boss-FIGHT window (fight_engage resets)
var party_stats_net := {}  # GUEST: the host's merged table (~1 Hz fan) — display copy

var shake_amt := 0.0
var _shake_kick := Vector2.ZERO  # directional camera kick along the last hit vector (P1)
var _hitstop_active := false      # a real-time freeze is running (solo only)
var _hitstop_end_ms := 0
var _hitstop_restore := 1.0       # the time_scale to return to (dev slow-mo aware)
var _cam_look := Vector2.ZERO   # eased look-ahead offset (camera feel, 2026-08-18)
var _cam_zoom_mult := 1.0       # eased combat zoom multiplier on the base zoom
var camera_framing: RefCounted = preload("res://scripts/camera_framing.gd").new()
var sounds: Dictionary = {}
var sound_pool: Array = []
# Pending cutoff fades, keyed by the pool player they were scheduled on. The
# pool is first-free round-robin, so a slot is recycled the instant its sound
# ends — reusing one must CANCEL its pending fade or the fade lands on the
# next, unrelated play (every boss roar shorter than the 2.5 s cutoff).
var sfx_cutoff_tweens: Dictionary = {}
# Variant groups are discovered from override names ending in `_vN`.
# Callers play the stable semantic key (for example `boss_fire_cast`), and
# this bank chooses a different installed take without immediately repeating.
var sound_groups: Dictionary = {}       # semantic key -> sorted stream keys
var sound_group_last: Dictionary = {}   # semantic key -> last chosen index
var sfx_rng := RandomNumberGenerator.new()
var loot_rng := RandomNumberGenerator.new()
var ambient_fx: CPUParticles2D = null
var ground_fog: Sprite2D = null        # the misty terrains' floor-fog quad (atmosphere pass 2026-08-19)
var npc_emote_t := 4.0
# Battle seals: while the current room is HOT (an aggroed pack or a live
# boss), every door of the room closes — no retreating mid-combat.
var door_seals: Array = []            # 4 pooled StaticBody2D, one per direction
var barrier_active := false

# ------------------------------------------------------ terrain system ---
var terrain_by_zone: Array = []       # terrain id per room
var zone_grounds := {}                # room idx -> ground Sprite2D (repaintable)
var zone_fields := {}                 # room idx -> GPU-tiled authored floor Polygon2D (native-res crisp base, see _apply_ground_field)
var zone_road_marks := {}             # room idx -> worn-road overlay Sprite2Ds (see _mark_roads)
var zone_scenery := {}                # room idx -> decor + obstacle nodes
var zone_canopy := {}                 # room idx -> foreground canopy strips (P3 overhang)
var zone_posts := {}                  # room idx -> wall pilasters / corner blocks (P5.1)
var zone_wall_sprites := {}           # room idx -> wall visual Sprite2Ds (retextured on terrain repaint)
var _wall_sink: Array = []            # _build_room_walls points this at the room's wall list while building
var hazards: Array = []               # active floor patches (lava/ice/...)
var terrain_event_t := 4.0            # countdown to the next terrain event
var hazard_tick := 0.0
var gust_vec := Vector2.ZERO          # sandstorm push applied to everyone
var gust_t := 0.0
# Rivers (Graphics & Ambience track): room idx -> {rect, bridge}. Built
# with the scenery from the terrain's "river" config; wading slows
# (Balance.RIVER_WADE_MULT), the bridge doesn't — a terrain mechanic.
var rivers := {}
var was_wading := false
# World-light scale for the room's terrain: PointLight2Ds are additive,
# so daylight zones run them near-zero and dark zones at full strength
# (set alongside the ambience in refresh_ambience).
var light_mult := 1.0
var _halo_pool: Sprite2D = null  # the hero's additive floor-glow (QA 5)

# ---------------------------------------------------------- persistence ---
var save_slot := -1                   # active save file (-1 = none yet)
var no_saves := false                 # autotest: never touch real save files
var restoring_save := false           # transient: room callbacks cannot write a half-restored world
var pending_tutorial := ""            # queued onboarding beat ("talents"/"gear"), drained in game.gd once no overlay is up (transient, not saved)
## DEDICATED SERVER (--server, MMO step A): this process is a headless world
## authority with NO local player — pure host, peers connect in. Every
## "host-personal" path (own loot share, own heals, HUD-driven story beats,
## the solo pause) gates on this or on has_local_player(). The world it runs
## persists to its own file (SaveGame.write_server_world — MMO step B), and
## its lobby never closes (drop-in joins are the point).
var dedicated := false
# MP-08 (§5.7): this machine is standing in ANOTHER player's world (a
# guest join built it from the host's snapshot). Autosaves then write
# ONLY the character block home — never this world's flags/rooms/seed.
# Deliberately OUTLIVES the session (a dropped connection must not flip
# the next autosave into a full write of the host's world); every path
# that starts an OWN world (reset_run_stats, load_save) clears it.
var guest_world := false
## MP-16: net_host_lost fires at most once per session (a guest returning to
## title on host loss). Reset when a fresh world snapshot rebuilds (a rejoin
## can lose its host anew) — net_session._rpc_world_snapshot.
var _host_lost_handled := false
var settings := {"music": 1.0, "sfx": 1.0, "fullscreen": false, "lang": "en", "touch_controls": false,
	"joystick_locked": false, "joystick_sensitivity": 1.0, "touch_layout": {},
	"camera_shake": 1.0, "camera_lead": 1.0, "impact_flashes": 1.0,
	"hit_stop": true, "damage_bearings": true, "combat_foliage": true, "combat_framing": true,
	"hud_clearance": true,
	"pad_deadzone": Balance.PAD_DEADZONE, "pad_cursor_speed": Balance.PAD_CURSOR_DEFAULT, "pad_labels": "auto"}
	# user://settings.json ("touch_layout": id -> [x,y] custom offset; "joystick_pos": [x,y] custom home)
var music_gain_db := -16.0            # base+tune of the current track
var flags := {}                       # persistent story flags (saved)
var quest_kills := {}                 # KILL-step progress: step flag -> kills so far (saved, chapter-wiped)
var _quest_avail_cache := -1          # any_quest_available memo: -1 dirty, 0 no, 1 yes (not saved)
var quest_marks: Array = []           # live ❢ giver markers: [{node, quests}] (rebuilt with the world)
var merchant_zones: Array = []        # rooms with a merchant present (saved)
var wander_seed := 0                  # per-character roll for seeded rooms (saved)
var cutscene: Cutscene = null         # active opening cinematic (if any)
var chapter_finale := preload("res://scripts/chapter_finale.gd").new()

# ------------------------------------------------------------ dev mode ---
var dev_mode := false                 # launched via dev_mode.bat (--dev)
var dev_god := false
var music_player: AudioStreamPlayer
var music_tracks: Dictionary = {}
var current_track := ""

# Ambient audio bed (per-biome loop under the music; Sfx.make_ambient).
var amb_player: AudioStreamPlayer
var amb_tracks: Dictionary = {}       # kind -> synthesized loop (lazy)
var current_amb := ""
const AMB_DB := -30.0                 # a bed, not a soundscape

var edge_locks := {}   # edge key -> {"lock": "boss"/"clear"/"flag:x", "own": room idx}

# --- mailbox (playtest round 8) ---
var mailbox: Array = []        # letters: {subject, body, items, sent_at, read}
var dropped_loot: Array = []   # ground-drop payloads awaiting pickup or flush
var clock_anchor := 0          # highest unix time ever seen (persisted, monotonic)

# --- daily login reward (trusted-clock day index; -1 = never claimed) ---
var daily_last_day := -1       # day index of the last claim
var daily_streak := 0          # consecutive-day claim count

# --- records & achievements (persisted) ---
var achievements := {}         # achievement id -> true (unlocked)
var boss_records := {}         # boss kind -> {"ttk": best secs, "dps": best, "kills": n}

# --- bounties (rotating objectives; persisted) ---
var bounties: Array = []       # active: {scope,type,target,progress,desc,gold,gems,gem_lvl,done}
var bounty_day := -1           # trusted-clock day the daily set was rolled
var bounty_week := -1          # trusted-clock week the weekly was rolled
var contracts: Array = []      # ward contracts (Q11): {ward,type,target,progress,desc,gold,done,claimed}
var contract_day := -1         # trusted-clock day the board was rolled
var contract_claims_day := 0   # claims used today (Balance.WARD_CONTRACT_DAILY_CAP)

# --- weekly vault (great-vault style; persisted) ---
var vault_week := -1           # trusted-clock week the current progress belongs to
var vault_progress := 0        # boss kills this week
var vault_claimed_week := -1   # week the vault was last claimed

# --- Renown supply cache (persisted): week THIS character last bought the
# Wardrobe's weekly consumable bundle (the wallet itself is account-wide
# meta — game_flow.renown()). ---
var renown_cache_week := -1

# --- Waking Incursion (ACT2_DESIGN; solo worlds for now) ---
# waking_week is WORLD state: the trusted-clock week THIS world's breach
# rooms were built for (-1 = none), armed in switch_chapter and restored
# by load_save BEFORE the rebuild — the wander_seed contract, because the
# breaches are room GEOGRAPHY and the graph must match the save. A stale
# week keeps the map but pays nothing (the weekly_fx precedent).
var waking_week := -1
var _waking_restore := -2      # transient load hand-off (-2 = arm normally)
# The kill ledger is the CHARACTER's (per-head faucet, like the vault):
# which breach echoes this hero banked this week.
var waking_kills_week := -1
var waking_kills: Array = []


## Has this character already banked this week's kill of `kind`? (Guards
## the breach spawn — a banked echo does not rise again this week.)
func waking_banked(kind: String) -> bool:
	return waking_kills_week == _week_index() and waking_kills.has(kind)

# Q15 Unlisted: which hidden bosses this RUN has already felled (world state,
# reset per chapter run, saved so a reload never re-raises a downed Unlisted).
var unlisted_banked: Array = []

## Has THIS run already downed the Unlisted `id`? (Guards its spawn + re-inject.)
func unlisted_banked_has(id: String) -> bool:
	return unlisted_banked.has(id)

# Q15 portal-stone pockets (DYNAMIC_WORLD §6) — an IN-GRAPH floating boss arena
# reached only by a portal stone's teleport and returned to the origin room on
# the boss's fall (decision #6: in-graph, co-op-safe, never a world swap).
var pocket_room := -1        # the injected arena's room index this run (-1 = none rolled)
var pocket_id := ""          # which pocket rolled (content/pockets.gd id)
var pocket_origin_offset := Vector2.ZERO  # relative to the source room, saved
var pocket_clock: Dictionary = {}  # latest host display clock, transient
var pocket_origin := -1      # the room to return to (set on entry; saved for a mid-pocket reload)
var pocket_done := false     # its boss felled this run (banks the reward once)
var _pocket_stone_placed := false  # transient: the stone has been dropped into a safe room this run

# --- chapter run stats (results card; persisted mid-run, reset per run) ---
var run_time := 0.0            # seconds in ST_PLAYING this chapter run
var run_deaths := 0
var run_elites := 0            # elite kills this run
var run_secrets := 0           # caches unearthed this run
var run_road_cards := 0        # Road Deck encounters drawn this run (drives the diminishing chance)
var run_xp := 0                # XP banked this run (after the replay ceiling)
var run_levels := 0            # levels gained this run
var xp_capped_noted := false   # the once-per-run "outgrown this road" note (not saved)

# --- weekly challenge (persisted) ---
var weekly_active := false     # the CURRENT run is this week's challenge
var weekly_week := -1          # week the active run belongs to
var weekly_claimed_week := -1  # week the completion reward was last paid
# NG+ difficulty tier THIS RUN launched at — a snapshot of the character's
# standing choice (player.run_tier), taken in switch_chapter. run_tier()
# reads THIS, never the live preference, so a mid-run picker flip can't
# mix spawn levels or launder records/unlocks; a change arms on the next
# chapter launch. World-saved (save.gd "run_tier_world").
var world_run_tier := 0

# --- codex completion + titles (persisted) ---
var kill_counts := {}          # enemy kind -> lifetime kills (this character)
var player_title := ""         # equipped title id ("" = none)
var fangmoot := {}             # Fangmoot state (tables_won, saved moot); FangmootHostCrownless owns the shape

# --- codex gallery + story archive (persisted) ---
var splashes_seen := {}        # splash sprite name -> true (gallery unlocks)
var convo_log := {}            # quest key -> {"chapter": chid, "lines": [[who, text], ...]}
var convo_log_order: Array = []  # quest keys in first-seen order (journal archive)

# --- elective risk events (curse state persists via flags) ---
var curse_pending := {}        # room idx -> true (accepted, payout on purge)

# --- account-wide stash (cross-character; user://stash.json) ---
var stash: Array = []          # storage payloads {kind: item/gem/stone, ...}
var _stash_loaded := false
const STASH_PATH := "user://stash.json"

# Gains measured by RMS against a 0.10 target (python soundfile pass,
# 2026-07-07) — the purchased Alkakrab packs master quieter than peak.
const MUSIC_TUNE := {
	"village": {"gain": 1.0},      # Cozy "Ancient Glow" (synth original
	                               # exported to the asset library +
	                               # kept in music.gd — delete to revert)
	"title": {"gain": 3.1},        # Flameheart "Hollow Throne"
	"roster": {"gain": 0.4},       # 55-OW "Hearthsong"
	"graveyard": {"gain": -2.1},   # Flameheart "The Endless Graveyard"
	"icefield": {"gain": 6.0},     # Flameheart "Beneath the Frozen Crypt"
	"magma": {"gain": 4.8},        # Flameheart "Ritual Under Ashen Skies"
	"desert": {"gain": 5.9},       # 55-OW "Westward Winds"
	"crystalline": {"gain": 0.8},  # Cozy "Veil of Echoes"
	"holy": {"gain": 6.0},         # Flameheart "The Forgotten Cathedral"
	"rainstorm": {"start": 30.0},  # storm fades in over ~30s (kept, CC0)
	"void": {"gain": 6.0},         # Flameheart "Vault of Eternal Night"
	"spore": {"gain": 6.0},        # Flameheart "The Hollow Feast"
	# Per-boss themes (2026-07-07): every declared boss_<kind> slot now
	# has a real track, lore-cast from the purchased packs. Boss target
	# RMS 0.12 (they should hit hotter than terrain beds).
	"boss_fangmaw": {"gain": 3.6},        # "The Nameless Hunger"
	"boss_morwen": {"gain": 6.0},         # "Harbinger of Plague"
	"boss_vargoth": {"gain": 4.1},        # "Shattered Crown"
	"boss_stormwarden": {"gain": 0.9},    # "Raised by The Storm"
	"boss_choirmother": {"gain": 6.0},    # "The Last Dirge"
	"boss_nullwarden": {"gain": 0.7},     # "The Iron Revenant"
	"boss_sexton": {"gain": 3.2},         # "Tomb of Echoes"
	"boss_vess": {"gain": 6.0},           # "Omen of Crows"
	"boss_varo": {"gain": 2.2},           # "Black Crowned Seraph"
	"boss_forgemistress": {"gain": 6.0},  # "Soulforged Chains"
	"boss_cinderhide": {"gain": 6.0},     # "Veins of the Underworld"
	"boss_ashpriest": {"gain": 6.0},      # "The Scorched Oracle"
	"boss_whitepelt": {"gain": 6.0},      # "Night's Devouring Maw"
	"boss_icebound": {"gain": 6.0},       # "Wounds of Eternity"
	"boss_sleepkeeper": {"gain": 1.5},    # "Veil of the Forgotten Ones"
	"boss_auroch": {"gain": 3.7},         # "The Eternal Maw"
	"boss_gardener": {"gain": 6.0},       # "The Cursed Grove"
	"boss_kaethra": {"gain": 6.0},        # "Crown of Rot"
	"boss_veyx": {"gain": 5.4},           # "Herald of Dread"
	"boss_echo": {"gain": 6.0},           # "Curse of the Hollow Star"
	"boss_cyrraeth": {"gain": 4.2},       # "Dead God's Whisper"
	# Multi-boss brawl tiers, escalating 2 -> world's end:
	"boss_x2": {"gain": 0.1},             # "With Fire And Sword"
	"boss_x3": {"gain": 1.1},             # "Clash of The Kings"
	"boss_x4": {"gain": 4.6},             # "Chains of the Damned"
	"boss_x5": {"gain": 6.0},             # "The Final Eclipse"
}
const MUSIC_DB := -16.0


# ---------------------------------------------- player queries (MP seam) ---
# Targeting/AI reads go through these instead of `game.player` so a
# second player is a registry entry, not a rewrite. With one registered
# player they all trivially return that player — solo is bit-identical.

## Does THIS machine drive a player body? False only on a dedicated
## server (--server) — solo, host and guest always have one. The guard
## for every host-personal path (own loot/heal/HUD beat/tithe).
func has_local_player() -> bool:
	return local_player != null and is_instance_valid(local_player)


## Nearest LIVING player to pos. Falls back to the nearest player
## regardless of death if none are alive (so callers that only check
## validity — not `dead` — keep their exact solo behavior). Returns
## null only when the registry is empty.
func nearest_player(pos: Vector2) -> Player:
	var best: Player = null
	var best_d := INF
	var best_any: Player = null
	var best_any_d := INF
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var d := pos.distance_squared_to(p.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = p
		# MP-12 (§5.3): DOWNED/GHOST players stop being valid prey — they
		# read as not-a-target WITHOUT reading as dead. When nobody stands,
		# the best_any fallback still returns a body (enemies menace the
		# fallen for the beat before the wipe fires). Solo: both flags are
		# always false, so no solo pick ever changes.
		if not p.dead and not p.downed and not p.ghost and d < best_d:
			best_d = d
			best = p
	return best if best != null else best_any


## Every registered player currently standing in room idx.
func players_in_room(idx: int) -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p != null and is_instance_valid(p) and room_at_pos(p.global_position) == idx:
			out.append(p)
	return out


func any_player_alive() -> bool:
	for p in players:
		if p != null and is_instance_valid(p) and not p.dead:
			return true
	return false


## THE targeting seam (MULTIPLAYER.md §5.2). v1 semantics: nearest living
## player to from_node. Enemies/bosses resolve their prey through this on
## a sticky ~1s cadence; taunts and threat tables slot in here later.
func pick_target(from_node: Node2D) -> Player:
	return nearest_player(from_node.global_position)


# ------------------------------------------------- session roster (MP-07) ---

## A remote peer's Player joins the registry and the tree. The node
## arrives configured (game/peer_id/authority set by net_session.gd);
## parenting + the roster slot happen here so every instance shares one
## spawn path. Replaces any stale entry with the same peer_id (rejoin).
func register_remote_player(p: Player) -> void:
	for i in players.size():
		var q := players[i]
		if q != null and is_instance_valid(q) and q != local_player \
				and q.peer_id == p.peer_id:
			_clear_remote_pet(q)
			q.queue_free()
			players[i] = p
			add_child(p)
			_refresh_active_rooms()
			return
	players.append(p)
	add_child(p)
	_refresh_active_rooms()


## Peer pid left the session: drop and free its player. Your own player
## never unregisters here (it isn't a remote entry on this machine).
func unregister_player(pid: int) -> void:
	for i in range(players.size() - 1, -1, -1):
		var q := players[i]
		if q == null or not is_instance_valid(q):
			players.remove_at(i)
			continue
		if q != local_player and q.peer_id == pid:
			_clear_remote_pet(q)
			players.remove_at(i)
			q.queue_free()
	_refresh_active_rooms()


func _clear_remote_pet(owner: Player) -> void:
	var key := owner.get_instance_id()
	if not remote_pet_followers.has(key):
		return
	var visual: Variant = remote_pet_followers[key].visual
	if is_instance_valid(visual):
		visual.queue_free()
	remote_pet_followers.erase(key)


## Recompute the sim gate (§4.3). Starts from cur_room — the local
## player's room by definition — so solo it is exactly {cur_room} and
## enemy.gd's freeze rule keeps its old behavior to the frame. Remote
## players' rooms union in on top; -1 (outside the graph) never counts.
func _refresh_active_rooms() -> void:
	active_rooms.clear()
	# DEDICATED: no local player pins a room — the gate is purely the union
	# of connected players' rooms, so an empty server idles every enemy.
	if not dedicated:
		active_rooms[cur_room] = true
	for p in players:
		if p == null or not is_instance_valid(p) or p == local_player:
			continue
		var r := room_at_pos(p.global_position)
		if r >= 0:
			active_rooms[r] = true


## Is a network session live? The autoload by PATH: the bare
## `NetworkManager` global does not exist under check_compile's
## --script mode (MP-05 finding — see net_manager.gd header).
func net_online() -> bool:
	var net: Node = get_node_or_null("/root/NetworkManager")
	return net != null and bool(net.is_online())


## Online AND not the authority: guests don't run the enemy sim — the
## host streams it and they render mirrors (MP-09). Branches on
## multiplayer.is_server(), never "am I the host player" (§3.1).
func net_guest() -> bool:
	return net_online() and not multiplayer.is_server()


## Online AND the authority: the host mirrors its simulation outward —
## enemy spawns/deaths, ~20 Hz state, ability one-shots, telegraphs
## (MP-09). Solo is offline, so this is false and every hook it gates
## stays inert.
func net_host() -> bool:
	return net_online() and multiplayer.is_server()


## The gameplay bridge (/root/NetworkManager/Session), or null when the
## autoload is absent (check_compile --script mode). Only dereference
## under a net_host()/net_guest() guard — those imply a live session.
func net_session() -> Node:
	var net: Node = get_node_or_null("/root/NetworkManager")
	return net.session if net != null else null


## THE pause seam (MULTIPLAYER.md §5.4). Every gameplay pause point —
## menus, dialogue, victory card, boot flow — routes through here instead
## of touching get_tree().paused directly. Solo semantics are exactly the
## old inline writes: boolean, last-writer-wins, no refcounting. Co-op
## branches HERE: a shared world never pauses, so in-session this becomes
## overlay-without-pause (menus/dialogue keep the world running).
func request_pause(on: bool) -> void:
	# MP (§5.4): a shared world never pauses — in a session, menus and
	# dialogue simply don't freeze the world (the full non-pausing
	# overlay UX is phase 3). Unpauses still apply; solo keeps the
	# exact old boolean writes.
	# MP-14 (§5.4): the ONE in-session exception is VICTORY — the chapter is
	# over, nothing left to simulate, so the results card may freeze every
	# machine (the host's continue unpauses the party). RPCs are event-driven,
	# not process-gated, so the advance/end handshake still flows while paused.
	# DEDICATED: the world authority NEVER pauses, victory included — its
	# auto-advance timer must keep ticking with nobody at the keyboard.
	if on and (dedicated or (net_online() and state != ST_VICTORY)):
		return
	get_tree().paused = on


## THE input gate that replaces the pause (§5.4): is an input-blocking overlay
## up — a menu, dialogue, a choice prompt or the chat line? In a session
## request_pause above no-ops, so this composite, not get_tree().paused, is what
## stops the world reading the local device. game.gd gates its interact/menu
## poll on it and zeroes the intents while it holds; player_core's per-physics-
## frame poll re-checks it (the physics frame runs AFTER that clear and used to
## re-fill the intents straight from the keyboard).
func input_overlay_up() -> bool:
	if hud == null or menus == null:
		return false
	return chapter_finale.active or hud.dialogue_active or hud.choices_active or hud.chat_active or menus.is_open()


## NG+ tier governing THIS run's spawns and drops (0 = Normal;
## Balance.TIER_NAMES). Reads the RUN-START snapshot (world_run_tier) —
## the character's standing choice (player.run_tier, picked in the replay
## chapter select) arms it on the next chapter launch. In co-op the
## HOST's tier briefs the party (net_session world snapshot + advance
## snap): every head fights, earns and records at the world's actual
## tier. Gates: the endgame modes own their own ladders and the weekly
## races a shared seed at parity — both force 0.
func run_tier() -> int:
	if player == null or endgame_active or weekly_active:
		return 0
	return world_run_tier


## The chapter id this run's DROPS pay from — the tier-shifted loot band
## (Balance.tier_chapter). Drop faucets (chests, boss gear, spoils, elite
## gems, bags, the gem gates) read this; the SHOP and GAMBLE stay keyed to
## the real chapter_id — they price off measured CHAPTER_ECON farm-cost,
## which a shifted id doesn't have (the fallthrough would sell S at
## commodity price), and the village doesn't get harder with the world.
## The tier's gold rate already makes buying cheaper in farm-minutes.
func loot_chapter() -> String:
	return Balance.tier_chapter(chapter_id, run_tier())


## An authored campaign spawn level, lifted by the run's NG+ tier (0 = as
## authored). `lvl` -1 means "kind base": resolve the anchor FIRST so the
## offset stacks on the authored level (the factory would clamp the
## sentinel up unshifted). Derived spawns — boss adds, summons — inherit
## their parent's already-lifted level and must NOT come through here
## (double-dip).
func tiered_level(kind: String, lvl: int) -> int:
	var off := Balance.tier_level_offset(run_tier())
	if off == 0:
		return lvl
	var base: int = lvl if lvl > 0 else int(Story.ALL_ENEMIES.get(kind, {}).get("level", 1))
	return base + off


## The best gear grade this chapter can drop (act gating, DESIGN.md):
## The best grade a GENERAL faucet (chest/shop/gamble/spoils) can yield this
## chapter — the ceiling of the chapter's general band table (2026-07-09),
## tier-shifted on NG+ runs like every drop faucet.
## Display/gating probes only; the drop channels roll the band directly
## (the gamble prices itself off the BOSS band now — see gamble_cost).
func loot_cap() -> String:
	return Balance.chapter_gear_ceiling(loot_chapter())

## (T7) Merchants read the shard: the steady get kinder prices, the
## tempted make the till nervous. Surfaced, never explained in numbers.
func band_price_mult() -> float:
	match Story.res_band(player.resonance):
		"steady": return 0.9
		"tempted": return 1.1
	return 1.0


# ------------------------------------------- capital rework: road prices ---

## The chapter whose loot bands + economy the CURRENT shop quotes. On the
## road that's the chapter you're standing in; the capital bazaar stocks and
## prices for the road AHEAD — the successor of the furthest campaign chapter
## this character has completed (their next destination).
func shop_chapter() -> String:
	if chapter_id != "capital":
		return chapter_id
	var best := "ch1"
	for cid in Story.CHAPTER_LIST:
		if get_flag("completed_" + String(cid), false):
			var nxt := Story.next_chapter(String(cid))
			best = nxt if nxt != "" else String(cid)
	return best

## The buy-price multiplier a merchant in THIS room quotes (2026-07-25,
## PROPOSALS/CAPITAL_REWORK.md §3). The capital bazaar and the endgame
## arenas (the Depths prep camp is its own designed economy) sell fair;
## every campaign-road merchant rolls a seeded bell-curve markup — stable
## for that merchant for the whole run, so it reads as a rate, not a bug.
func shop_markup(zone: int) -> float:
	if chapter_id == "capital" or endgame_active or not Story.CHAPTER_LIST.has(chapter_id):
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(wander_seed) * 31 + zone * 977 + chapter_id.hash() % 65536
	var markup := rng.randfn(Balance.ROAD_MARKUP_MEAN, Balance.ROAD_MARKUP_SD)
	var caravan_mult := Balance.CARAVAN_PRICE_MULT if preload("res://scripts/road_caravan.gd").supplied(self) else 1.0
	return (1.0 + clampf(markup, Balance.ROAD_MARKUP_MIN, Balance.ROAD_MARKUP_MAX)) * caravan_mult


# ------------------------------------------ capital rework: NPC favor ---
# v1 (Petra / the Lapidary): a per-character meter that climbs when you spend
# at that artisan's bench or turn in their intro quest. Tiers pay a VISIBLE
# bench discount (no silent effects). Gains read the shard: steady kinder,
# tempted warier — the same read the merchant's haggle already makes.

func favor_points(npc: String) -> int:
	if not has_local_player():
		return 0
	return int(player.npc_favor.get(npc, 0))


func favor_tier(npc: String) -> int:
	var pts := favor_points(npc)
	var tier := 0
	for i in Balance.FAVOR_TIERS.size():
		if pts >= int(Balance.FAVOR_TIERS[i]):
			tier = i
	return tier


func favor_tier_name(npc: String) -> String:
	return String(Balance.FAVOR_TIER_NAMES[favor_tier(npc)])


## The artisan's bench-cost multiplier for this patron (1.0 at Stranger).
func favor_price_mult(npc: String) -> float:
	return 1.0 - Balance.FAVOR_DISCOUNT_PER_TIER * float(favor_tier(npc))


## Shift a faction's standing on the LOCAL character (accord / cinderborn /
## wildfang / choir — the key is `cinderborn`, never `cinder`). One seam so
## quest rewards, convo forks and ward contracts all move standing the same
## way. Guarded like every other local-character write (dedicated has none).
func add_standing(faction: String, delta: int) -> void:
	if delta == 0 or not has_local_player():
		return
	player.faction_standing[faction] = int(player.faction_standing.get(faction, 0)) + delta


## Exact favor credit after this hero's shard read, shared by quotes and payout.
func favor_gain(points: int) -> int:
	if not has_local_player() or points <= 0:
		return 0
	var mult := 1.0
	match Story.res_band(player.resonance):
		"steady": mult = Balance.FAVOR_RES_STEADY_MULT
		"tempted": mult = Balance.FAVOR_RES_TEMPTED_MULT
	return maxi(1, int(round(float(points) * mult)))


## Add favor with the shard read applied; announces tier climbs. Favor is
## per-character (rides the save like resonance) and only ever climbs.
func favor_add(npc: String, points: int) -> void:
	var gain := favor_gain(points)
	if gain <= 0:
		return
	var before := favor_tier(npc)
	player.npc_favor[npc] = favor_points(npc) + gain
	if favor_tier(npc) > before and is_instance_valid(player):
		sfx("levelup")
		spawn_text(player.global_position + Vector2(0, -70),
			"%s now counts you a %s!" % [npc.capitalize(), favor_tier_name(npc)],
			Color(0.75, 0.95, 0.7), 3.0)


## Gold spent at a capital bench converts to favor (1 per FAVOR_GOLD_PER_POINT,
## fractional spends accumulate via a per-npc remainder).
func favor_spend(npc: String, gold_spent: int) -> void:
	if gold_spent <= 0 or chapter_id != "capital":
		return
	var carry_key := npc + "__carry"
	var carry: int = int(player.npc_favor.get(carry_key, 0)) + gold_spent
	var points := carry / Balance.FAVOR_GOLD_PER_POINT
	player.npc_favor[carry_key] = carry % Balance.FAVOR_GOLD_PER_POINT
	if points > 0:
		favor_add(npc, points)


## Gambling vendor price (2026-07-09 rework): the gamble is the PITY path —
## it rolls the chapter's BOSS band (the B/A pieces the general faucets
## can't reach), so it is priced against what it PAYS:
##   cost = sum_over_boss_band( weight_g x farm_price(g) ) x GAMBLE_DISCOUNT
## i.e. the boss table's real drop odds weight each grade's farm-cost
## (Items.shop_buy_price, the round-51 machinery), then the sight-unseen
## discount (0.8) and the resonance haggle. Reads as "a bit cheaper than
## farming that grade yourself". `tier` is legacy and ignored.
func gamble_cost(_tier: String = "") -> int:
	var w := Balance.boss_weights(chapter_id)
	var total := 0.0
	for v in w.values():
		total += float(v)
	var expected := 0.0
	for g in w:
		var probe := {"grade": String(g), "slot": "armor", "plus": 0}
		expected += (float(w[g]) / total) * float(Items.shop_buy_price(probe, chapter_id))
	return int(ceil(expected * Balance.GAMBLE_DISCOUNT * band_price_mult()))


## Spend gold on a random BOSS-band item, sight unseen. Returns the won
## item, or {} if you can't afford it or the bag is full (nothing charged).
func gamble(tier: String) -> Dictionary:
	var cost := gamble_cost(tier)
	if player.gold < cost or player.bag_used() >= player.bag_capacity():
		return {}
	player.gold -= cost
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var grade := Balance.roll_weighted_grade(Balance.boss_weights(chapter_id), rng)
	var won := Items.roll_gear_of_grade(grade, rng, player.cls, Story.act_of(chapter_id))
	player.add_item(won)
	return won

## Write the current character to its slot. Called on story progress,
## zone changes, menu closes and window close — never mid-death.
## Guesting in another world (MP-08, §5.7): only the character block
## travels home — the host's world must never colonize the guest's save.
func autosave() -> void:
	if no_saves or restoring_save:
		return
	# PVP (v1, 2026-08-01): the duel has NO stakes — nothing earned, nothing
	# risked, so nothing is written from an arena world. (A guest's session-end
	# character write in net_session_over stays the co-op safety it always was.)
	if pvp_active:
		return
	# DEDICATED (MMO step B): the server has no character — its save IS the
	# world. Every existing autosave call site (room clears, boss kills, flag
	# changes via story flow, WM_CLOSE) now persists the world file instead.
	if dedicated:
		if play_started and not no_saves:
			SaveGame.write_server_world(self)
		return
	# MP (Wave-1 co-op fix): a DOWNED/GHOST player (§5.3) sits at hp<=0 while
	# still ST_PLAYING — banking that state would load the hero clamped to 1 HP
	# (apply_character floors hp >= 1). Skip the write until they stand. Solo
	# never sets downed/ghost, so offline is unaffected.
	if save_slot > 0 and play_started and state == ST_PLAYING \
			and not player.dead and not player.downed and not player.ghost:
		if guest_world or endgame_active:
			# Endgame runs live in a throwaway arena world — bank only the
			# character (take-home gold/gear/records), never the arena's world
			# state, so the campaign position the save names stays untouched.
			SaveGame.write_character_home(self, save_slot)
		else:
			SaveGame.write(self, save_slot)

# ------------------------------------------------------------------ mailbox ---

## Cheat-resistant wall clock: never goes backwards, even when the OS
## clock does (players roll system time to farm timed rewards; rolling
## FORWARD only accelerates their own expiries — no gain). Never use
## raw OS time for rewards or expiry; always this.
func trusted_now() -> int:
	clock_anchor = maxi(clock_anchor, int(Time.get_unix_time_from_system()))
	return clock_anchor


## Deliver a letter. items = loot payloads ({"kind": "item"/"gem"/
## "stone", ...}); body may be "" ("Dropped Loot" letters have none).
## Also the dev/event gift API.
func send_mail(subject: String, body: String, items: Array) -> void:
	mailbox.append({"subject": subject, "body": body, "items": items,
		"sent_at": trusted_now(), "read": false})
	if play_started and is_instance_valid(player):
		sfx("chest")
		spawn_text(player.global_position + Vector2(0, -64),
			"NEW MAIL — see the pause menu", Color(0.8, 0.9, 1.0))


## Unclaimed letters expire after Balance.MAIL_EXPIRY_DAYS on the
## trusted clock; claimed ones stay until the player deletes them.
func prune_mail() -> void:
	var cutoff := trusted_now() - Balance.MAIL_EXPIRY_DAYS * 86400
	for m in mailbox.duplicate():
		if not m["items"].is_empty() and int(m["sent_at"]) < cutoff:
			mailbox.erase(m)


# ------------------------------------------------------- daily login reward ---

## Which calendar day it is on the trusted clock (integer day index).
func daily_day_index() -> int:
	return int(trusted_now() / 86400)


## True when a daily reward is waiting (a new day since the last claim).
func daily_available() -> bool:
	return daily_day_index() > daily_last_day


## The streak this claim WOULD land on (1 if fresh or a day was missed).
func daily_next_streak() -> int:
	return daily_streak + 1 if daily_day_index() == daily_last_day + 1 else 1


## The reward dict for a given streak position (the 7-day pattern repeats
## across a 28-day cycle, each week paying a little more — Balance.daily_reward_at).
func daily_reward_for(streak: int) -> Dictionary:
	return Balance.daily_reward_at(streak)


## Claim today's reward: advance the streak, grant the loot, persist.
## Returns human-readable lines of what was granted (for the panel/fx).
func claim_daily() -> Array:
	if not daily_available():
		return []
	daily_streak = daily_next_streak()
	daily_last_day = daily_day_index()
	if daily_streak >= 7:
		unlock_achievement("streak_7")
	var lines := _grant_daily_reward(daily_streak)
	if is_instance_valid(player):
		sfx("chest")
		spawn_text(player.global_position + Vector2(0, -70),
			"DAILY REWARD — Day %d streak!" % daily_streak, Color(1.0, 0.85, 0.4))
	autosave()
	return lines


## Hand over one day's reward. Gold scales with level; gems route through
## give_loot so a full bag drops them safely (never silently lost).
func _grant_daily_reward(streak: int) -> Array:
	var r := daily_reward_for(streak)
	var lines: Array = []
	if r.has("gold"):
		var g := int(float(r["gold"]) * Balance.daily_gold_mult(player.level))
		player.gold += g
		lines.append("%d gold" % g)
	if r.has("potions"):
		var pc := int(r["potions"])
		var got := 0
		for i in pc:
			# Graded bag items now (CONSUMABLE_GRADES): a low-grade clean Health
			# Potion per unit, routed through add_consumable (a full bag stops it).
			if player.add_consumable(Items.make_potion("health", "instant", "E", "accord")):
				got += 1
		if got > 0:
			lines.append("%d Health Potion%s" % [got, "" if got == 1 else "s"])
	if r.has("gems"):
		var gc := int(r["gems"])
		var lvl := int(r.get("gem_lvl", 1))
		for i in gc:
			give_loot({"kind": "gem", "gem": drop_gem(lvl)},
				player.global_position + Vector2(-30.0 + 30.0 * i, 40.0))
		lines.append("%d Lv%d gem%s" % [gc, lvl, "" if gc == 1 else "s"])
	if r.has("renown"):
		call("add_renown", int(r["renown"]))  # wallet lives in the game_flow layer
		lines.append("%d Renown" % int(r["renown"]))
	return lines


# ------------------------------------------------- records & achievements ---

## Log a boss clear: bump the kill count, keep the FASTEST time and the
## HIGHEST realized dps. Surfaced in the codex Records tab.
func record_boss(kind: String, ttk: float, dps: float) -> void:
	var r: Dictionary = boss_records.get(kind, {"ttk": 0.0, "dps": 0.0, "kills": 0})
	r["kills"] = int(r.get("kills", 0)) + 1
	if float(r.get("ttk", 0.0)) <= 0.0 or ttk < float(r["ttk"]):
		r["ttk"] = ttk
	if dps > float(r.get("dps", 0.0)):
		r["dps"] = dps
	boss_records[kind] = r


## Unlock an achievement (idempotent): toast it, chime, persist. Unknown
## ids and repeats are no-ops.
func unlock_achievement(id: String) -> void:
	if achievements.has(id) or not Achievements.DATA.has(id):
		return
	achievements[id] = true
	var a: Dictionary = Achievements.DATA[id]
	if is_instance_valid(hud):
		hud.achievement_toast(String(a["name"]), String(a["desc"]))
	sfx("levelup", 1.15)
	autosave()


## Total achievement points (titles hang on these — codex Records tab).
func achievement_points() -> int:
	var pts := 0
	for id in achievements:
		pts += int(Achievements.DATA.get(id, {}).get("pts", Achievements.DEFAULT_PTS))
	return pts


## One more of `kind` slain (codex completion). Shouts when the kill
## unearths the kind's lore entry.
func note_kill(kind: String) -> void:
	kill_counts[kind] = int(kill_counts.get(kind, 0)) + 1
	if int(kill_counts[kind]) == Lore.threshold(kind) and is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -92),
			"LORE UNEARTHED — see the Codex", Color(0.75, 0.9, 1.0), 3.0)
	call("check_track_achievements")  # kills + lore tiers (game_flow owns tracks)


## A speaker's painted splash displayed in dialogue: the codex Gallery
## unlocks that portrait. Rides the next autosave (convo ends autosave).
## Mirrored into the ACCOUNT ledger too (owner 2026-07-25: the gallery
## celebrates the account, not one hero) — game_flow owns the meta file.
func note_splash_seen(sprite: String) -> void:
	if sprite != "":
		splashes_seen[sprite] = true
		call("meta_note_splash", sprite)


## Journal story archive: every dialogue line shown lands in the bucket of
## the quest that was live when it played, in order, exactly as the player
## saw it (variants and choices included). Repeated greetings archive once
## (exact who+text de-dup per bucket); a hard cap guards the save size.
const CONVO_LOG_MAX_LINES := 400

func log_story_line(who: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	var key := quest_key if quest_key != "" else "wanders_" + chapter_id
	if not convo_log.has(key):
		convo_log[key] = {"chapter": chapter_id, "lines": []}
		convo_log_order.append(key)
	var lines: Array = convo_log[key]["lines"]
	if lines.size() >= CONVO_LOG_MAX_LINES:
		return
	for l in lines:
		if String(l[0]) == who and String(l[1]) == text:
			return
	lines.append([who, text])


## How many lore entries this character has unearthed (Lorekeeper title).
func lore_unearthed() -> int:
	var n := 0
	for kind in kill_counts:
		if Story.ALL_ENEMIES.has(kind) and int(kill_counts[kind]) >= Lore.threshold(kind):
			n += 1
	return n


## Lifetime kills across every kind (Reaper title).
func total_kills() -> int:
	var n := 0
	for kind in kill_counts:
		n += int(kill_counts[kind])
	return n


## Can this character wear the title? (see Achievements.TITLES).
func title_available(id: String) -> bool:
	var t: Dictionary = Achievements.TITLES.get(id, {})
	if t.is_empty():
		return false
	if t.has("req_ach") and not achievements.has(String(t["req_ach"])):
		return false
	if achievement_points() < int(t.get("req_pts", 0)):
		return false
	if lore_unearthed() < int(t.get("req_lore", 0)):
		return false
	if total_kills() < int(t.get("req_kills", 0)):
		return false
	return true


# ---------------------------------------------------- chapter run tracking ---

## A fresh chapter run begins (new game, replay, advance): the results
## card's counters restart. Loading a save does NOT reset — the counters
## ride the save, so the card reflects the whole run across sessions.
func reset_run_stats() -> void:
	run_time = 0.0
	run_deaths = 0
	run_elites = 0
	run_secrets = 0
	run_road_cards = 0
	run_xp = 0
	run_levels = 0
	xp_capped_noted = false
	unlisted_banked.clear()   # Q15: a fresh run may meet its hidden bosses again
	pocket_done = false        # Q15: a fresh run may open its pocket again
	_pocket_stone_placed = false
	party_stats.clear()   # battle-stats meters restart with the run
	fight_stats.clear()
	party_stats_net.clear()
	curse_pending.clear()
	# A fresh run counter means THIS machine begins its own world (new
	# hero / replay / weekly / next chapter): full autosaves again (MP-08).
	guest_world = false


## The stats block the results card shows (and the grade is computed from).
func run_results() -> Dictionary:
	var explored := 0
	for i in zone_count:
		if visited.get(i, false):
			explored += 1
	var expect := maxi(1, int(ceil(zone_count * Balance.GRADE_HUNT_EXPECT)))
	var grade := Balance.chapter_grade(run_deaths,
		float(explored) / maxf(1.0, float(zone_count)),
		float(run_elites + run_secrets) / float(expect))
	# XP line (REPLAY_XP.md §3): what the run paid, and — on a replay past
	# its ceiling — the level the road stops paying at, so a zero reads as
	# "outgrown", never as "broken".
	var lv_now: int = player.level if is_instance_valid(player) else 0
	var xp_reach := -1
	if get_flag("completed_" + chapter_id, false):
		xp_reach = Balance.replay_xp_reach(Story.chapter_parity_level(chapter_id))
	return {"time": run_time, "deaths": run_deaths, "elites": run_elites,
		"secrets": run_secrets, "road": run_road_cards, "explored": explored, "rooms": zone_count,
		"grade": grade, "xp": run_xp, "lv_from": lv_now - run_levels, "lv_to": lv_now,
		"xp_reach": xp_reach}


# --------------------------------------------------------- weekly challenge ---

## This week's modifier — the same for every player (deterministic from
## the trusted-clock week, like bounties).
func weekly_mod() -> Dictionary:
	return Balance.WEEKLY_MODS[_week_index() % Balance.WEEKLY_MODS.size()]


## This week's fixed map seed: everyone runs the SAME layout this week.
func weekly_seed() -> int:
	return _week_index() * 77003 + 12345


## The chapter this week's challenge runs (rotates weekly through the list).
func weekly_chapter() -> String:
	var ids: Array = Story.CHAPTER_LIST.keys()
	return String(ids[_week_index() % ids.size()])


## A weekly modifier multiplier, 1.0 unless a challenge run is live (or the
## run outlived its week — stale runs keep the feel but never the reward).
func weekly_fx(key: String) -> float:
	if not weekly_active:
		return 1.0
	return float(weekly_mod().get(key, 1.0))


## Gold pickups route through this (weekly "gilded" modifier hook).
func gold_scaled(amount: int) -> int:
	return int(round(amount * weekly_fx("gold")))


# ------------------------------------------------------------ loot fanfare ---

## Every gear drop announces its rarity (retention roadmap #3): a
## per-grade chime always; from LOOT_BEAM_MIN_GRADE up, a grade-colored
## light beam rises at the drop. S-grade adds a screen flash — the
## jackpot is unmissable. FX only; the item itself already moved.
func loot_fanfare(grade: String, pos: Vector2) -> void:
	sfx(Items.loot_sound(grade))
	var rank := Items.GRADES.find(grade)
	if rank < Items.GRADES.find(Balance.LOOT_BEAM_MIN_GRADE):
		return
	var tint: Color = Items.GRADE_COLOR.get(grade, Color(1, 1, 1))
	var beam := Sprite2D.new()
	beam.texture = Art.tex("lootbeam")
	beam.centered = false
	beam.z_index = 6
	# The beam plants its BASE on the drop and grows with rarity.
	var grow := 1.0 + 0.45 * float(rank - Items.GRADES.find(Balance.LOOT_BEAM_MIN_GRADE))
	beam.scale = Vector2(1.6, 1.7 * grow)
	beam.position = pos - Vector2(16.0 * beam.scale.x, 180.0 * beam.scale.y)
	var hot := Art.hdr(tint)  # emissive: the beam blooms over the scene
	beam.modulate = Color(hot.r, hot.g, hot.b, 0.0)
	world.add_child(beam)
	# The drop LIGHTS the ground around it while the beam stands.
	var beam_light := Art.light(tint, 110.0, 1.0 * light_mult)
	beam_light.position = pos - beam.position  # beam origin is offset; re-anchor on the drop
	beam.add_child(beam_light)
	burst(pos, tint, 10 + 6 * rank)
	var tw := beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.95, 0.12)
	tw.tween_interval(Balance.LOOT_BEAM_TIME)
	tw.tween_property(beam, "modulate:a", 0.0, 0.5)
	tw.tween_callback(beam.queue_free)
	if grade == "S" and is_instance_valid(hud):
		hud.flash_screen(tint, 0.28, 0.4)
		shake(4.0)


# --------------------------------------------------------------- bounties ---

## Roll the daily set on a new day and the weekly on a new week — both
## DETERMINISTIC from the trusted clock, so relogging can't reroll for a
## kinder objective. Cheap no-op when nothing has rolled over; safe to
## call every frame.
func refresh_bounties() -> void:
	# no_saves = headless autotest: keep the roster empty so campaign-test
	# kills don't fire reward gems into other sections. The bounty test
	# drives _roll_bounties/bounty_progress directly instead.
	if not play_started or no_saves:
		return
	var day := daily_day_index()
	var week := int(day / 7)
	var changed := false
	if day != bounty_day or _bounty_count("daily") == 0:
		bounty_day = day
		_roll_bounties("daily", Balance.BOUNTY_DAILY_COUNT, day * 2 + 1)
		changed = true
	if week != bounty_week or _bounty_count("weekly") == 0:
		bounty_week = week
		_roll_bounties("weekly", Balance.BOUNTY_WEEKLY_COUNT, week * 7 + 3)
		changed = true
	if changed:
		autosave()


func _bounty_count(scope: String) -> int:
	var n := 0
	for b in bounties:
		if String(b["scope"]) == scope:
			n += 1
	return n


## Replace a scope's bounties with `count` fresh picks, seeded so the same
## day/week always yields the same objectives.
func _roll_bounties(scope: String, count: int, seed_val: int) -> void:
	var kept: Array = []
	for b in bounties:
		if String(b["scope"]) != scope:
			kept.append(b)
	bounties = kept
	var pool: Array = Balance.BOUNTY_POOL[scope]
	var idxs: Array = []
	for i in pool.size():
		idxs.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(idxs.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var tmp = idxs[i]; idxs[i] = idxs[j]; idxs[j] = tmp
	for k in mini(count, pool.size()):
		var t: Dictionary = pool[idxs[k]]
		bounties.append({"scope": scope, "type": String(t["type"]), "target": int(t["target"]),
			"progress": 0, "desc": String(t["desc"]), "gold": int(t.get("gold", 0)),
			"gems": int(t.get("gems", 0)), "gem_lvl": int(t.get("gem_lvl", 1)),
			"renown": int(t.get("renown", 0)), "done": false})


## Advance every active bounty of `type`; award and flag any that finish.
func bounty_progress(type: String, n := 1) -> void:
	var touched := false
	for b in bounties:
		if String(b["type"]) == type and not b["done"]:
			b["progress"] = mini(int(b["progress"]) + n, int(b["target"]))
			touched = true
			if int(b["progress"]) >= int(b["target"]):
				b["done"] = true
				_award_bounty(b)
	if touched:
		autosave()


## Bounty reward: gold (level-scaled) straight to the purse, gems via
## give_loot so a full bag never loses them. The player is always present
## when a bounty completes (it rides a kill/clear event).
func _award_bounty(b: Dictionary) -> void:
	var g := activity_gold(int(b["gold"]))
	player.gold += g
	var extra := ""
	for i in int(b["gems"]):
		give_loot({"kind": "gem", "gem": drop_gem(int(b["gem_lvl"]))},
			player.global_position + Vector2(-30.0 + 30.0 * i, 40.0))
		extra = " + gem"
	call("add_renown", int(b.get("renown", 0)))  # its own violet toast, stacked above
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -78),
		"BOUNTY: %s  (+%d gold%s)" % [b["desc"], g, extra], Color(0.6, 1.0, 0.6), 4.0)


# ---------------------------------------------------------- ward contracts ---
# The four capital ward desks' daily deed board (Q11). Rolls per ward per day;
# deeds auto-progress off the same kill/clear events as bounties; the player
# claims the reward in the journal, capped per character per day.

## Roll the day's board if the trusted-clock day has ticked over (or the board
## is empty). Seeded per ward per day so a relog can't reroll it (bounty law).
func refresh_contracts() -> void:
	if not play_started or no_saves:
		return
	var day := daily_day_index()
	if day == contract_day and not contracts.is_empty():
		return
	contract_day = day
	contract_claims_day = 0
	contracts = []
	for wi in Balance.WARD_CONTRACT_WARDS.size():
		_roll_contracts(String(Balance.WARD_CONTRACT_WARDS[wi]),
			Balance.WARD_CONTRACT_PER_WARD, day * 4 + wi * 101 + 7)
	autosave()


func _roll_contracts(ward: String, count: int, seed_val: int) -> void:
	var pool: Array = Balance.WARD_CONTRACT_POOL
	var idxs: Array = []
	for i in pool.size():
		idxs.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(idxs.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var tmp = idxs[i]; idxs[i] = idxs[j]; idxs[j] = tmp
	for k in mini(count, pool.size()):
		var t: Dictionary = pool[idxs[k]]
		contracts.append({"ward": ward, "type": String(t["type"]), "target": int(t["target"]),
			"progress": 0, "desc": String(t["desc"]), "gold": int(t.get("gold", 0)),
			"done": false, "claimed": false})


## A deed toward every active, unfinished ward contract of `type`. Marks the
## contract ready to claim at the target — it does NOT pay (the claim does, so
## the daily cap can gate WHICH deeds you cash). Host-authoritative like kills.
func contract_progress(type: String, n := 1, from_authority := false) -> void:
	if not has_local_player() or n <= 0 or (net_guest() and not from_authority):
		return
	refresh_contracts()
	var touched := false
	for c in contracts:
		if String(c["type"]) == type and not bool(c["done"]):
			c["progress"] = mini(int(c["progress"]) + n, int(c["target"]))
			touched = true
			if int(c["progress"]) >= int(c["target"]):
				c["done"] = true
				if is_instance_valid(player):
					spawn_text(player.global_position + Vector2(0, -84),
						"%s contract ready — claim it in the journal" %
						Balance.WARD_CONTRACT_WARD_NAME.get(String(c["ward"]), String(c["ward"])),
						Color(0.8, 0.9, 0.6), 2.4)
	if touched:
		autosave()


## Claim a completed contract's reward: gold (level-scaled), the ward faction's
## standing, and — where the ward hosts a trainer — that trainer's favor. Capped
## per character per day (Balance.WARD_CONTRACT_DAILY_CAP). Returns "" on success
## or a short failure reason the journal can show.
func claim_contract(c: Dictionary) -> String:
	if not has_local_player():
		return "no character"
	refresh_contracts()
	# A displayed card can outlive a day rollover or character reload. Value
	# equality also accepts detached copies, leaving the actual entry unpaid.
	var current := false
	for entry in contracts:
		if is_same(entry, c):
			current = true
			break
	if not current:
		return "contract expired — choose from today's board"
	if not bool(c.get("done", false)):
		return "not finished"
	if bool(c.get("claimed", false)):
		return "already claimed"
	if contract_claims_day >= Balance.WARD_CONTRACT_DAILY_CAP:
		return "daily cap reached — come back tomorrow"
	contract_claims_day += 1
	c["claimed"] = true
	var ward := String(c["ward"])
	var g := activity_gold(int(c["gold"]))
	player.gold += g
	add_standing(ward, Balance.WARD_CONTRACT_STANDING)
	var favor_extra := ""
	var fnpc := String(Balance.WARD_CONTRACT_FAVOR_NPC.get(ward, ""))
	if fnpc != "":
		favor_add(fnpc, Balance.WARD_CONTRACT_FAVOR)
		favor_extra = " + favor"
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -78),
		"%s CONTRACT  (+%d gold, +%d %s%s)" % [
			Balance.WARD_CONTRACT_WARD_NAME.get(ward, ward).to_upper(), g,
			Balance.WARD_CONTRACT_STANDING, ward.capitalize(), favor_extra],
		Color(0.7, 0.9, 0.6), 4.0)
	autosave()
	return ""


## Exact purse credit used by both rotating-activity cards and their payouts.
func activity_gold(base: int) -> int:
	return int(float(base) * Balance.daily_gold_mult(player.level)) if has_local_player() else 0


## Today's available choices, bounded by the character's remaining allowance.
func contracts_claimable() -> int:
	if contract_day != daily_day_index():
		return 0
	var n := 0
	for c in contracts:
		if bool(c.get("done", false)) and not bool(c.get("claimed", false)):
			n += 1
	return mini(n, maxi(0, Balance.WARD_CONTRACT_DAILY_CAP - contract_claims_day))


func activity_claims_ready() -> int:
	return contracts_claimable() + int(vault_ready())


# ----------------------------------------------------------- weekly vault ---

func _week_index() -> int:
	return int(daily_day_index() / 7)


## A boss fell: credit it to this week's vault (resetting on a new week),
## and shout once when it first unlocks.
func vault_note_boss() -> void:
	var week := _week_index()
	if week != vault_week:
		vault_week = week
		vault_progress = 0
	var was_ready := vault_ready()
	vault_progress += 1
	if vault_ready() and not was_ready and is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -92),
			"WEEKLY VAULT READY — open the Quest Log (⚑)", Color(1.0, 0.85, 0.4), 5.0)


## True when this week's kills hit the goal and it hasn't been claimed yet.
func vault_ready() -> bool:
	var week := _week_index()
	return vault_week == week and vault_progress >= Balance.VAULT_BOSS_GOAL \
		and vault_claimed_week != week


## Claim the weekly reward: a golden chest at your feet + a bright gem.
## Returns reward lines for the journal; empty if not ready.
func claim_vault() -> Array:
	if not vault_ready():
		return []
	vault_claimed_week = _week_index()
	Chest.drop(self, "gold", clamp_to_zone(player.global_position + Vector2(64, 0), player.global_position))
	give_loot({"kind": "gem", "gem": drop_gem(2)}, player.global_position + Vector2(0, 44))
	call("add_renown", Balance.RENOWN_VAULT)
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -70), "WEEKLY VAULT CLAIMED!", Color(1.0, 0.85, 0.4), 4.0)
	autosave()
	return ["a golden chest", "a bright gem", "%d Renown" % Balance.RENOWN_VAULT]


# ----------------------------------------------------------- account stash ---

## Load the account-wide stash once per session (from user://stash.json).
## It's shared across every character, so it lives outside the per-slot save.
func ensure_stash_loaded() -> void:
	if _stash_loaded:
		return
	_stash_loaded = true
	if no_saves:
		return
	# The stash is a top-level JSON Array — read the main file, falling back to
	# the atomic-write .bak if it's missing or corrupt (CR-006).
	for p in [STASH_PATH, STASH_PATH + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			for pl in data:
				SaveGame._fix_payload(pl)
				stash.append(pl)
			return


func save_stash() -> void:
	if no_saves:
		return  # tests never touch the real account file
	SaveGame.atomic_store(STASH_PATH, JSON.stringify(stash))


## Move a bag payload INTO the stash. False = stash full.
func stash_deposit(payload: Dictionary) -> bool:
	if stash.size() >= Balance.STASH_SLOTS:
		return false
	stash.append(payload)
	save_stash()
	return true


## Transfer only the exact owned bag entry represented by this UI action.
## Stale clicks cannot deposit a second copy after the first moved it.
func stash_deposit_from_bag(payload: Dictionary) -> bool:
	if not has_local_player():
		return false
	var pocket: Array
	var entry: Dictionary
	match String(payload.get("kind", "")):
		"item":
			pocket = local_player.backpack
			entry = payload.get("item", {})
		"gem":
			pocket = local_player.gem_bag
			entry = payload.get("gem", {})
		"stone":
			pocket = local_player.consumables
			entry = payload.get("stone", {})
			if String(entry.get("kind", "")) == "quest":
				return false
		_:
			return false
	var idx := preload("res://scripts/gear_care.gd").index_of(pocket, entry)
	if idx < 0 or not stash_deposit(payload):
		return false
	pocket.remove_at(idx)
	return true


## Move a stashed payload back into the bag. Revalidate ownership at click time.
func stash_withdraw(payload: Dictionary) -> bool:
	var idx := preload("res://scripts/gear_care.gd").index_of(stash, payload)
	if idx < 0 or not _try_receive(payload):
		return false
	stash.remove_at(idx)
	save_stash()
	return true


## Give loot to the player — or drop it at `pos` when the bag is full.
## Ground drops are registered and flush into a "Dropped Loot" letter
## at chapter end: nothing is ever silently lost. Returns true when it
## went straight into the bag.
func give_loot(payload: Dictionary, pos: Vector2) -> bool:
	if _try_receive(payload):
		return true
	pos = resolve_drop_pos(pos)  # never bury a drop inside a wall (loot has no magnet)
	payload["pos"] = [pos.x, pos.y]
	dropped_loot.append(payload)
	Pickup.drop_loot(self, payload, pos)
	spawn_text(pos + Vector2(0, -44), "No room — left on the ground", Color(1, 0.9, 0.4))
	return false


## A loot gem rolled for the CURRENT chapter: ch1-3 exclude the special
## off-build stats (Balance.special_gems_drop), ch4+ may roll them. Every
## in-world gem DROP routes through here so the early-game rule holds in one
## place; shop stock and dev tools roll specials directly.
func drop_gem(lvl: int) -> Dictionary:
	return Items.random_gem(loot_rng, lvl, Balance.special_gems_drop(loot_chapter()))


## Nudge a ground-drop OUT of walls/props so loot stays reachable. Boss loot
## offset toward a nearby wall used to land INSIDE it — unrecoverable, since
## loot pickups (unlike coins) have no magnet and need you within 30px. A
## blocked spot slides toward the player (a known-reachable point) until clear.
func resolve_drop_pos(pos: Vector2) -> Vector2:
	var anchor: Vector2 = player.global_position if is_instance_valid(player) else pos
	pos = clamp_to_zone(pos, anchor)
	if not _pos_in_wall(pos):
		return pos
	for t in [0.25, 0.5, 0.75, 1.0]:
		var p := pos.lerp(anchor, t)
		if not _pos_in_wall(p):
			return p
	return anchor


## Is this point inside a wall or solid prop? (collision layer 1 — the same
## layer walls/obstacles register on; loot/enemies/player don't.)
func _pos_in_wall(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return not space.intersect_point(q, 1).is_empty()


## Player-initiated DISCARD (round 52): fling a bag payload out to a short
## arc away with a brief no-pickup window, so a full bag can be cleared
## without the item instantly re-collecting. The CALLER has already removed
## it from the bag. Registered like any ground drop -> flushes to the
## mailbox at chapter end (never silently lost). Returns the spawned Pickup.
func discard_to_ground(payload: Dictionary) -> Pickup:
	var dir: Vector2 = player.facing if player.facing.length() > 0.1 else Vector2(player.look_sign, 0.0)
	var target: Vector2 = player.global_position + dir.normalized() * Balance.DISCARD_THROW_DIST
	payload["pos"] = [target.x, target.y]
	dropped_loot.append(payload)
	var pk := Pickup.drop_loot(self, payload, target)
	pk.pickup_delay = Balance.DISCARD_NO_PICKUP_TIME
	# Throw arc: start on the hero and sail out to where it lands.
	var landed: Vector2 = pk.global_position
	pk.global_position = player.global_position
	var tw := pk.create_tween()
	tw.tween_property(pk, "global_position", landed, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sfx("equip")
	spawn_text(player.global_position + Vector2(0, -44), "Discarded", Color(0.8, 0.8, 0.85))
	return pk


## Route a loot payload into the right bag pocket. False = no room.
func _try_receive(payload: Dictionary) -> bool:
	match str(payload.get("kind", "")):
		"item":
			return player.add_item(payload["item"])
		"gem":
			return player.gain_gem(payload["gem"])
		"stone":
			return player.add_consumable(payload["stone"])
		"potion":
			return player.add_consumable(payload["potion"])
		"material":
			return player.add_material(String(payload.get("family", "")),
				String(payload.get("grade", "")), int(payload.get("count", 1)))
		"bag":
			# A dropped/awarded bag lands LOOSE in the pack (never auto-equips);
			# a full pack refuses so give_loot drops it on the ground / mails it.
			return player.add_loose_bag(Items.make_bag(String(payload.get("grade", "F"))))
	return false


## A detached travel payload: strip geometry without mutating live pickups,
## caller snapshots or two independently earned equal-valued rewards.
func portable_dropped_loot() -> Array:
	var items := dropped_loot.duplicate(true)
	for pl in items:
		pl.erase("pos")
	return items


## Reserve before queue_free: a pending contact callback cannot also collect
## loot that has been mailed or replaced by a character restore.
func retire_dropped_loot() -> void:
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		if node is Pickup and node.game == self:
			node.claimed = true
			node.queue_free()


## Leaving a world or chapter mails remaining ground loot. Idempotent.
func flush_dropped_loot() -> void:
	if dropped_loot.is_empty():
		return
	var items := portable_dropped_loot()
	dropped_loot = []
	retire_dropped_loot()
	send_mail("Dropped Loot", "", items)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave()


# ======================================================= conversation engine
# Branching dialogue with choices, resonance/faction shifts and story
# flags. Data format documented at Story.CONVOS.

## MP-13 (§5.4): set true while applying a WORLD flag that ARRIVED from the
## session, so the apply doesn't bounce straight back out (loop guard).
var _net_flag_apply := false
## MP-13 (§5.4): true on the machine DRIVING a chapter-critical story beat —
## the HUD mirrors each dialogue line to the spectating party. Private
## overlays and solo play leave it false (no mirror traffic).
var beat_broadcasting := false

func set_flag(flag_name: String, value = true) -> void:
	flags[flag_name] = value
	# Accepting or finishing a quest IS a flag, so any flag change may have
	# changed what's on offer — drop the HUD shine's cache (any_quest_available).
	_quest_avail_cache = -1
	# Flag-locked gates: any built gate whose flag just got set unlocks.
	# (Dynamic call: gates live a layer up in game_world.gd — the ONE
	# deliberate upward call in the chain.)
	if value:
		call("_recheck_gates")
		_check_side_quests()
		# A ❢ must clear the instant you accept — and accepting is a flag.
		# (Dynamic call: the marks live a layer up in game_world, same
		# deliberate upward hop as _recheck_gates above.)
		call("refresh_quest_marks")
	# (2026-07-27) The s_awakened skin-refresh hook was removed with the
	# awakened-form retirement — a skin resolves to one base, always.
	# MP-13 (§5.4): WORLD flags are shared story state — quest progress,
	# opened ways, one-time reveals, pay-once desks, shrine/cache/curse
	# once-per-room marks. Route them through the host so every machine in
	# the session agrees; PER-CHARACTER flags stay local to their owner
	# (game_flow._flag_is_local: the same KEPT_* list that survives a
	# chapter wipe because it's character history). A flag applied FROM the
	# wire skips the re-route (loop guard). Offline: no session — nothing
	# routes, so solo is bit-identical.
	if not _net_flag_apply and net_online():
		var s: Node = net_session()
		if s != null and not bool(call("_flag_is_local", flag_name)):
			s.route_flag(flag_name, value)


## MP-13: apply a WORLD flag received from the session — the same local
## effects as a fresh set (gates react, side quests re-check) with the
## re-route suppressed so it can't echo back out. Idempotent (re-applying a
## set flag is a no-op for gates; sq_paid guards a second reward).
func net_apply_flag(flag_name: String, value) -> void:
	_net_flag_apply = true
	set_flag(flag_name, value)
	_net_flag_apply = false


## MP-13 (§5.4): a chapter-critical BEAT is a convo that advances the story
## quest — any node or choice carries a `quest` key. Beats gate on the party
## being present and mirror their lines to everyone; every other convo is a
## private overlay + a one-line toast. Conservative by design (only quest-
## advancing convos qualify), and reached from net_session.begin_convo.
func _convo_is_beat(convo: Dictionary) -> bool:
	for nid in convo.get("nodes", {}):
		var node: Dictionary = convo["nodes"][nid]
		if node.has("quest"):
			return true
		for c in node.get("choices", []):
			if c.has("quest"):
				return true
	return false


## Side quests are visible wrappers over flag chains (Story.SIDE_QUESTS):
## sq_on_<id> marks acceptance, each step completes when its flag lands,
## and the reward pays the moment the LAST step's flag is set — once per
## run (sq_paid_<id>; all three are ordinary flags, so saves carry them
## and the run-end wipe retires them together).
func _check_side_quests() -> void:
	for id in Story.ALL_SIDE_QUESTS:
		var sid := String(id)
		if not get_flag("sq_on_" + sid, false) or get_flag("sq_paid_" + sid, false):
			continue
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		var done := true
		for step in q.get("steps", []):
			if not get_flag(String(step["flag"]), false):
				done = false
				break
		if not done:
			continue
		flags["sq_paid_" + sid] = true  # direct: no gate/quest re-entry
		var reward: Dictionary = q.get("reward", {})
		var gold := int(ceil(float(reward.get("gold", 0)) * Balance.daily_gold_mult(player.level)))
		if gold > 0:
			player.gold += gold
		var standing: Dictionary = reward.get("standing", {})
		for fac in standing:
			player.faction_standing[fac] = int(player.faction_standing.get(fac, 0)) + int(standing[fac])
		# Beyond coins + standing (2026-08-17 quest-verb pass, PROPOSALS/
		# DYNAMIC_WORLD.md §3.2): a quest may also pay an ITEM (a chapter-band
		# gear roll for the wearer's class, like a chest), a GEM (chapter drop
		# level), and/or leave a persistent KEPT mark a later beat reads
		# (sq_kept_/chose_-prefixed, so it survives the chapter wipe and stays
		# per-character in co-op). Item/gem land on THIS machine's local player,
		# exactly like the gold above; the mark routes like any world/kept flag.
		var got_extra := ""
		if has_local_player():
			if reward.has("item"):
				var it: Dictionary = Items.roll_item(loot_chapter(), loot_rng, player.cls)
				if not it.is_empty():
					give_loot({"kind": "item", "item": it}, player.global_position)
					got_extra = "  + " + String(it.get("name", "gear"))
			if reward.has("gem"):
				var glvl := int(reward["gem"]) if not (reward["gem"] is bool) \
					else Balance.gem_drop_level(loot_chapter())
				var gem := drop_gem(glvl)
				give_loot({"kind": "gem", "gem": gem}, player.global_position)
				got_extra += "  + " + Items.gem_title(gem)
			# A cosmetic KEEPSAKE (identity, never power/currency): a chroma, skin
			# or title granted free to THIS class. grant_cosmetic is on the derived
			# layer, so reach it through call() from the base.
			if reward.has("keepsake"):
				var ks: Dictionary = reward["keepsake"]
				if bool(call("grant_cosmetic", String(ks.get("kind", "chroma")),
						player.cls, String(ks.get("id", "")))):
					got_extra += "  + " + String(ks.get("name", "a keepsake"))
		if reward.has("kept"):
			set_flag(String(reward["kept"]))  # persistent per-character mark
		sfx("levelup")
		spawn_text(player.global_position + Vector2(0, -70),
			"SIDE QUEST COMPLETE — %s%s%s" % [String(q["name"]),
				"  (+%d gold)" % gold if gold > 0 else "", got_extra],
			Color(1.0, 0.85, 0.35), 4.0)

## A kill toward any accepted, unfinished KILL-step quest (2026-08-17
## quest-verb pass): a step with `kind:"kill"` names a `target` enemy kind and
## a `count`; each matching kill bumps a run-scoped counter and, at the target,
## SETS the step flag — so the step stays an ordinary flag to _check_side_quests
## and the journal, the co-op flag-routing carries the completion, and the
## save/wipe treat it like any quest progress. Host-authoritative (like every
## spawn/kill credit) so a shared kill is counted once; the flag it sets routes
## to the party. Called from game_flow.on_enemy_died beside note_kill.
func quest_kill_note(kind: String) -> void:
	if net_guest():
		return  # the host owns the sim; guests only render its progress
	var changed := false
	for id in Story.ALL_SIDE_QUESTS:
		var sid := String(id)
		if not get_flag("sq_on_" + sid, false) or get_flag("sq_paid_" + sid, false):
			continue
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		for step in q.get("steps", []):
			if String(step.get("kind", "flag")) != "kill" or String(step.get("target", "")) != kind:
				continue
			var f := String(step["flag"])
			if get_flag(f, false):
				continue
			var need: int = maxi(1, int(step.get("count", 1)))
			var have := int(quest_kills.get(f, 0)) + 1
			quest_kills[f] = have
			changed = true
			if have >= need:
				set_flag(f)  # completes the step: routes, re-checks, clears the ❢
			elif is_instance_valid(player):
				spawn_text(player.global_position + Vector2(0, -84),
					"%s  (%d/%d)" % [String(step.get("text", "quarry")), have, need],
					Color(0.9, 0.85, 0.7), 1.6)
	if changed and net_host():
		# Partial kills do not author a main objective (private callbacks can).
		net_session().host_quest_progress(0, false, true)


## Settle every side quest ACCEPTED in this chapter and never finished.
## Called from the victory beat (game_flow): victory is the chapter's point of
## no return — the card only offers ENTER or R, so there is no walking back to
## finish anything — which makes it the last honest moment to charge for a
## broken promise, and it lands BEFORE _wipe_chapter_flags retires the sq_
## flags. Returns one line per broken promise for the victory card: the
## consequence is NEVER silent (Balance §quest abandonment explains the shape —
## this revokes what you were paid, it does not fine you for exploring).
func _expire_side_quests() -> Array:
	var broken: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		var sid := String(id)
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		# Unscoped (capital/world) quests are never charged for abandonment —
		# they have no chapter deadline to break.
		if not Story.quest_scoped(q) or String(q.get("chapter", "")) != chapter_id:
			continue
		if not get_flag("sq_on_" + sid, false) or get_flag("sq_paid_" + sid, false):
			continue
		var over: Dictionary = q.get("abandon", {})
		# 1. The pledge goes back — you were paid resonance for the promise.
		var pledge := float(get_flag("sq_pledge_" + sid, 0.0))
		var res_cost: float = float(over.get("resonance",
			-(pledge + Balance.QUEST_ABANDON_RESONANCE)))
		# DEDICATED: the world authority has no character to charge — the
		# roll-call text still builds (guests read it on their cards).
		if res_cost != 0.0 and has_local_player():
			player.add_resonance(res_cost)
		# 2. The people who asked notice — softly, and only if they exist.
		var standing: Dictionary = over.get("standing", _abandon_standing(q))
		if has_local_player():
			for fac in standing:
				player.faction_standing[fac] = int(player.faction_standing.get(fac, 0)) + int(standing[fac])
		var line := String(q.get("name", sid))
		if res_cost != 0.0:
			line += "  (%+d resonance)" % int(round(res_cost))
		broken.append(line)
	return broken


## What an abandoned quest costs in STANDING: a share of the reward its asker
## would have paid, lost instead of gained. A quest with no standing reward
## costs none — a stranger's errand has no faction to disappoint.
func _abandon_standing(q: Dictionary) -> Dictionary:
	var out := {}
	var reward: Dictionary = q.get("reward", {})
	var standing: Dictionary = reward.get("standing", {})
	for fac in standing:
		var lost := int(round(float(standing[fac]) * Balance.QUEST_ABANDON_STANDING_FRAC))
		if lost > 0:
			out[fac] = -lost
	return out


## Is ANY side quest still waiting to be offered in this chapter? The HUD
## polls this EVERY FRAME for the ⚑ shine, so the answer is cached:
## side_quest_available walks the zone table and re-rolls the wanderer seed,
## which is far too heavy per frame. -1 = dirty; set_flag dirties it (accepting
## a quest is a flag) and so does a chapter switch.
func any_quest_available() -> bool:
	if _quest_avail_cache < 0:
		_quest_avail_cache = 0
		for id in Story.ALL_SIDE_QUESTS:
			if side_quest_available(String(id)):
				_quest_avail_cache = 1
				break
	return _quest_avail_cache == 1


## Is this side quest OFFERABLE in the world right now — its giver actually
## present in THIS run — and not yet accepted or paid? The journal's AVAILABLE
## section and the NPC markers both read this, so neither can promise a quest
## whose giver never rolled (wanderer givers are seeded per run).
func side_quest_available(sqid: String) -> bool:
	var q: Dictionary = Story.ALL_SIDE_QUESTS.get(sqid, {})
	if q.is_empty():
		return false
	# Some personal stories finish for good even when chapter replay clears
	# their temporary acceptance/payment flags. Keep discovery honest.
	var completed_flag: String = q.get("completed_flag", "")
	if completed_flag != "" and get_flag(completed_flag, false):
		return false
	# Chapter quests only offer in their chapter; unscoped ones offer wherever
	# their giver is reachable (a capital NPC is only reachable in Crownfall).
	if Story.quest_scoped(q) and String(q.get("chapter", "")) != chapter_id:
		return false
	if get_flag("sq_on_" + sqid, false) or get_flag("sq_paid_" + sqid, false):
		return false
	# ANY giver being present is enough — several quests can be started more
	# than one way (heron_feather: the boy who asks, or just finding the hat).
	for giver in Story.quest_givers(sqid):
		if _convo_reachable(String(giver)):
			return true
	return false


## Whether a convo can be reached in this run: either it is bolted to one of
## the chapter's authored zone NPCs, or it is a wanderer this run's seed
## actually rolled into a social room.
func _convo_reachable(convo_id: String) -> bool:
	# Physical encounter actors carry the same profile metadata as authored
	# NPCs, even when no static NPC row spawns them.
	for entry in interactables:
		var actor = entry.get("node")
		if is_instance_valid(actor) and actor is Node2D and actor.is_visible_in_tree() \
			and String(actor.get_meta("quest_convo", "")) == convo_id:
			return true
	for z in zones:
		for npc_def in z.get("npcs", []):
			if String(npc_def.get("convo", "")) == convo_id:
				# Props riding a wanderer roll only exist where it rolled.
				if npc_def.has("req_wanderer"):
					return bool(call("_wanderer_rolled", String(npc_def["req_wanderer"])))
				return true
	return bool(call("_wanderer_rolled", convo_id))


func get_flag(flag_name: String, def = false):
	return flags.get(flag_name, def)

func run_convo_id(id: String, on_done := Callable()) -> void:
	var convo: Dictionary = Story.ALL_CONVOS[id]
	# Illustrated opt-in (2026-08-17 quest-illustration pass): a convo flagged
	# `"cinematic": true` plays through the storybook layer (Cutscene) exactly
	# like a chapter opener — each node's `"cue"` stages an authored plate.
	# This is the seam that lets a QUEST EVENT show opener-style art. Guard on
	# `cutscene == null` so run_cinematic_convo (which sets it, then re-enters
	# here) doesn't recurse; openers already own the layer when they call in.
	if cutscene == null and bool(convo.get("cinematic", false)):
		run_cinematic_convo(id, on_done)
		return
	# MP-13 (§5.4): in a co-op session, dialogue is a local overlay routed
	# through the etiquette layer — a per-NPC busy-lock, world-flag sync,
	# consequence toasts, and beat mirroring for the story-critical convos
	# (net_session.begin_convo). Offline (no session) it collapses to the
	# plain, unchanged run_convo path.
	if net_online():
		var s: Node = net_session()
		if s != null:
			s.begin_convo(id, convo, on_done)
			return
	run_convo(convo, on_done)


## Mount the illustrated storybook beneath the existing CQ dialogue chrome,
## run one authored conversation, then dissolve the art before continuing.
## Both the class prologue and chapter entries use this single seam.
func run_cinematic_convo(id: String, on_done := Callable()) -> void:
	if not Story.ALL_CONVOS.has(id):
		if on_done.is_valid():
			on_done.call()
		return
	cutscene = Cutscene.new(self)
	hud.add_child(cutscene)
	# Above gameplay HUD (bars/quest/abilities), beneath the CQ dialogue box.
	hud.move_child(cutscene, hud.dialogue_box.get_index())
	run_convo_id(id, func() -> void:
		if cutscene:
			var illustrated_entry := cutscene
			cutscene = null
			illustrated_entry.finish(on_done)
		elif on_done.is_valid():
			on_done.call())


## First-entry chapter opener. The persistent per-character marker means
## chapter select, NG+, and later replays never repeat a plate the hero saw.
## In co-op each client calls this locally after its own chapter rebuild.
func run_chapter_opener_if_needed(chapter_key: String,
		on_done := Callable()) -> void:
	if dedicated or not has_local_player():
		if on_done.is_valid():
			on_done.call()
		return
	var convo_id := chapter_key + "_opening_" + String(player.cls)
	var seen_flag := "saw_chapter_opening_" + chapter_key
	if get_flag(seen_flag, false) or not Story.ALL_CONVOS.has(convo_id):
		if on_done.is_valid():
			on_done.call()
		return
	set_flag(seen_flag)
	run_cinematic_convo(convo_id, on_done)


func run_convo(convo: Dictionary, on_done := Callable(), still_current := Callable()) -> void:
	_convo_node(convo, String(convo.get("start", "")), on_done, still_current)

func _convo_node(convo: Dictionary, node_id: String, on_done: Callable, still_current := Callable()) -> void:
	# Personal endings can be retired by a party world transition. Guard every
	# page, not just the final callback, so a retained input callback cannot
	# repaint old narration or apply a choice over the next chapter's opener.
	if still_current.is_valid() and not still_current.call():
		return
	var nodes: Dictionary = convo.get("nodes", {})
	if node_id == "" or not nodes.has(node_id):
		autosave()  # choices are story progress
		if on_done.is_valid():
			on_done.call()
		return
	var node: Dictionary = nodes[node_id]
	# A matched variant can override the text AND the path: a variant
	# with its own "next" makes the node linear (choices are skipped) —
	# the short-circuit for "we already had this conversation" greetings.
	var variant := _convo_variant(node)
	var cue_name: String = String(variant.get("cue", node.get("cue", "")))
	if cutscene and cue_name != "":
		cutscene.cue(cue_name)  # stage the variant's authored picture
	var who: String = node.get("who", "")
	var text: String = variant.get("text", node.get("text", ""))
	var next_id: String = String(variant.get("next", node.get("next", "")))
	var force_linear: bool = variant.has("next")
	if node.has("quest"):
		quest_key = String(node["quest"])
		refresh_quest()

	# Gate choices on flags / resonance band, then present or continue.
	var choices: Array = []
	for c in node.get("choices", []):
		if c.has("req_flag") and not flags.get(String(c["req_flag"]), false):
			continue
		if c.has("req_not_flag") and flags.get(String(c["req_not_flag"]), false):
			continue
		if c.has("req_band") and Story.res_band(player.resonance) != String(c["req_band"]):
			continue
		choices.append(c)
	if choices.is_empty() or force_linear:
		hud.dialogue([[who, text]], func() -> void:
			_convo_node(convo, next_id, on_done, still_current))
	else:
		var option_texts: Array = []
		for c in choices:
			option_texts.append(String(c["text"]))
		hud.dialogue_choice(who, text, option_texts, func(idx: int) -> void:
			if still_current.is_valid() and not still_current.call():
				return
			var c: Dictionary = choices[idx]
			var res_delta := float(c.get("resonance", 0.0))
			player.add_resonance(res_delta)
			if res_delta != 0.0:
				_resonance_reward(res_delta)
			var fac_shifts: Dictionary = c.get("faction", {})
			for fac in fac_shifts:
				add_standing(String(fac), int(fac_shifts[fac]))
			# Side-quest acceptance runs BEFORE the choice's flags land, so
			# a single choice can accept a quest and complete its first
			# step (or even the whole chain) in one breath. Quests bind to
			# their authored chapter — a wanderer repeating his ask in a
			# later chapter can't open an uncompletable job.
			if c.has("side_quest"):
				var sqid := String(c["side_quest"])
				var sq: Dictionary = Story.ALL_SIDE_QUESTS.get(sqid, {})
				# Unscoped (capital/world) quests accept anywhere; chapter quests
				# only in their own chapter (a wanderer repeating his ask later
				# can't open an uncompletable job).
				if not sq.is_empty() \
						and (not Story.quest_scoped(sq) or String(sq.get("chapter", chapter_id)) == chapter_id) \
						and not get_flag("sq_on_" + sqid, false):
					set_flag("sq_on_" + sqid)
					if has_local_player() and not preload("res://scripts/quest_guide.gd").active(self, player.tracked_quest):
						player.tracked_quest = sqid
					# What saying YES paid (Balance §quest abandonment): the
					# accept choice grants resonance for making the promise, so
					# record the pledge — leaving the chapter with the job
					# unfinished hands it straight back. Direct write like
					# sq_paid_: a derived record, not a gate.
					if res_delta != 0.0:
						flags["sq_pledge_" + sqid] = res_delta
					sfx("potion")
					spawn_text(player.global_position + Vector2(0, -70),
						"NEW SIDE QUEST — %s  (see the ⚑ journal)" % String(sq["name"]),
						Color(0.95, 0.85, 0.5), 4.0)
			var set_flags: Dictionary = c.get("flags", {})
			for fname in set_flags:
				set_flag(fname, set_flags[fname])  # via set_flag: gates react
			# Quest keepsakes: a choice may hand the player a bag rider
			# ("gain_item") or take one back ("lose_item"). Gains bypass
			# bag capacity — a promise never bounces off a full pack.
			if c.has("gain_item"):
				var qi := Items.make_quest_item(String(c["gain_item"]))
				if not qi.is_empty():
					player.consumables.append(qi)
					sfx("potion")
			if c.has("lose_item"):
				var lose_id := String(c["lose_item"])
				for qc in player.consumables.duplicate():
					if String(qc.get("id", "")) == lose_id:
						player.consumables.erase(qc)
						break
			# Worldly payment ("gold"): the Temptation-trade price tag — a
			# few coins for taking the low road. Authored amounts stay TINY
			# (<= ~2-3% of a chapter run; see Balance.CHAPTER_ECON) and every
			# paying choice is one-shot flag-gated: flavor money, never a
			# faucet. Dropped as coins so the usual pickup juice applies.
			if c.has("gold"):
				Pickup.drop_gold(self, int(c["gold"]),
					player.global_position + Vector2(randf_range(-26.0, 26.0), 42.0))
				sfx("coin")
			if c.has("quest"):
				quest_key = String(c["quest"])
				refresh_quest()
			# Capital gossip hubs (2026-07-25): a choice may open a game
			# surface ("hub_action": a game_world._hub_action ref). It fires
			# when the CHOSEN PATH ends, so any reply line reads before the
			# menu covers it. Local-only by construction — the callback runs
			# on the machine driving the convo (§5.4).
			var done_after := on_done
			if c.has("hub_action"):
				var act := String(c["hub_action"])
				done_after = func() -> void:
					call("_hub_action", act)
					if on_done.is_valid():
						on_done.call()
			# Illustrated beat ("scene": 2026-08-17 quest-illustration pass): after
			# this choice's whole path closes, play a cinematic convo — the quest's
			# moment reuses the opener storybook (run_cinematic_convo). The plate(s)
			# come from that convo's node cues; per-class art resolves automatically
			# (Cutscene._quest_frames). Local-only, like hub_action; chains any prior
			# done_after so hub_action + scene can coexist.
			if c.has("scene"):
				var scene_id := String(c["scene"])
				var chain := done_after
				done_after = func() -> void:
					run_cinematic_convo(scene_id, chain)
			# MP-13 (§5.4): resonance, standings, keepsakes and coins above all
			# hit `player` = local_player, so a GUEST's choice moves only the
			# guest — owner-side by construction (§5.4). The one SHARED
			# consequence is a world flag / side-quest accept, which already
			# routed through the host via set_flag; tell the OTHER players in
			# one terse line (private overlays only — a mirrored beat already
			# shows them every word).
			if net_online() and not beat_broadcasting:
				var s2: Node = net_session()
				if s2 != null:
					if c.has("side_quest"):
						var sq2: Dictionary = Story.ALL_SIDE_QUESTS.get(String(c["side_quest"]), {})
						if not sq2.is_empty():
							s2.convo_toast("accepted", String(sq2.get("name", "a quest")))
					elif _choice_sets_world_flag(c):
						s2.convo_toast("chose", String(c.get("text", "")))
			_convo_node(convo, String(c.get("next", "")), done_after, still_current))


## MP-13: does this choice set at least one WORLD flag (worth a toast to the
## party)? Per-character flags don't count — they change nobody else's world.
func _choice_sets_world_flag(c: Dictionary) -> bool:
	for fname in c.get("flags", {}):
		if not bool(call("_flag_is_local", String(fname))):
			return true
	return false

## A shard choice made in a quiet room pays a token reward either way
## — the shard reacts to CONVICTION, not virtue (playtest round 8:
## resonance choices should feel eventful). Combat/boss rooms pay
## nothing: no farming mid-fight decisions.
func _resonance_reward(delta: float) -> void:
	if room_type(clampi(cur_room, 0, zone_count - 1)) in ["combat", "boss"]:
		return
	var pos: Vector2 = player.global_position + Vector2(randf_range(-26.0, 26.0), 42.0)
	Pickup.drop_gold(self, Balance.RES_REWARD_GOLD_BASE
		+ int(absf(delta)) * Balance.RES_REWARD_GOLD_PER_POINT, pos)
	if absf(delta) >= Balance.RES_REWARD_CHEST_AT:
		Chest.drop(self, "silver" if absf(delta) >= Balance.RES_REWARD_SILVER_AT else "wood",
			pos + Vector2(54, 0))
	sfx("coin")


## The FIRST matching variant wins (resonance band or story flag);
## empty dict = use the node's own text/next.
func _convo_variant(node: Dictionary) -> Dictionary:
	for v in node.get("variants", []):
		if v.has("band") and Story.res_band(player.resonance) == String(v["band"]):
			return v
		if v.has("flag") and flags.get(String(v["flag"]), false):
			return v
	return {}


# ==================================================================== options

func save_binds() -> void:
	SaveGame.atomic_store("user://keybinds.json", JSON.stringify(binds))

func load_binds() -> void:
	var data := SaveGame.read_json("user://keybinds.json")  # main, then .bak (CR-006)
	if not data.is_empty():
		for action in binds:
			if data.has(action):
				binds[action] = int(data[action])


# ==================================================================== world

func _edge_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

func neighbor(i: int, dir: String) -> int:
	var c: Vector2i = rooms[i]["coord"]
	return int(coord_to_room.get(c + Vector2i(DIRS[dir]), -1))

func room_rect(i: int) -> Rect2:
	return Rect2(rooms[i]["origin"], Vector2(ROOM_W, ROOM_H))

# Small rooms (playtest round 6): every room still occupies one grid
# cell, but quiet rooms — a single NPC, a shrine, a lore dead end, an
# elite arena — shrink their walled playable area; short corridors
# connect the doorways to the cell edges.
func room_inset(i: int) -> Vector2:
	# Authored hubs can deliberately vary their spatial hierarchy: a plaza or
	# portal court uses the whole cell, while a single-service workshop or
	# quiet ward room closes its walls in around the player.  The grid cell
	# remains fixed (so adjacency/network coordinates never change); only the
	# playable rectangle shrinks, exactly like the existing small-room seam.
	# A scalar keeps rooms proportionate and authored positions are remapped by
	# room_pos().  Clamp defensively so malformed content cannot make a room
	# vanish or overlap the cell boundary.
	var authored_scale := clampf(float(zones[i].get("room_scale", 1.0)),
		Balance.AUTHORED_ROOM_SCALE_MIN, 1.0)
	if authored_scale < 1.0:
		return Vector2(ROOM_W, ROOM_H) * (1.0 - authored_scale) / 2.0
	if room_type(i) in Balance.SMALL_ROOM_TYPES:
		return Balance.SMALL_ROOM_INSET
	# Combat arenas vary on a bell curve so rooms aren't identical (extremes
	# rare). Boss arenas (tuned) + safe hubs (authored NPC/building layout)
	# stay full-size. Deterministic per room -> co-op-safe + stable on rebuild.
	if room_type(i) != "combat":
		return Vector2.ZERO
	var shrink := 1.0 - _room_size_factor(i)   # 0 .. ROOM_SIZE_VAR
	return Vector2(ROOM_W, ROOM_H) * shrink / 2.0


## Deterministic per-room size factor in [1 - ROOM_SIZE_VAR, 1.0]: an Irwin-Hall
## bell from three decorrelated hashes of the room index, so the CENTRE of the
## band is common and both a near-full and a notably-small arena are rare. No
## RNG object (called often) — cheap, and identical on every machine (co-op).
func _room_size_factor(i: int) -> float:
	var a := float((i * 73856093) & 1023) / 1023.0
	var b := float((i * 19349663) & 1023) / 1023.0
	var c := float((i * 83492791) & 1023) / 1023.0
	var bell := (a + b + c) / 3.0   # ~centred 0.5, extremes rare
	return (1.0 - Balance.ROOM_SIZE_VAR) + Balance.ROOM_SIZE_VAR * bell

## ASYMMETRIC insets (P5.2, 2026-08-19): room_inset() is the per-axis AVERAGE
## (so the play rect's SIZE is unchanged — every size test/knob still holds),
## and this is the TOP-LEFT share of it: the same total shrink split unevenly
## between the two sides of each axis, so a small room is no longer always a
## centred rectangle in its cell. The door lanes stay on the cell's centre
## lines (door_pos), so a room simply sits off-centre AROUND its doors — the
## corridors on the near side shorten, the far side lengthens. Authored-scale
## rooms (capital `room_scale`) stay symmetric: their compositions were placed
## and passability-audited that way. Hashed per room index — no RNG, identical
## on every machine (co-op) and on every rebuild.
func room_inset_lt(i: int) -> Vector2:
	var ins := room_inset(i)
	if ins == Vector2.ZERO or float(zones[i].get("room_scale", 1.0)) < 1.0:
		return ins
	var ax := float((i * 2654435761) & 1023) / 1023.0 * 2.0 - 1.0
	var ay := float((i * 1597334677 + 7919) & 1023) / 1023.0 * 2.0 - 1.0
	return Vector2(ins.x * (1.0 + Balance.ROOM_INSET_ASYM * ax),
		ins.y * (1.0 + Balance.ROOM_INSET_ASYM * ay))

## The bottom-right share (the rest of the shrink on each axis).
func room_inset_rb(i: int) -> Vector2:
	return room_inset(i) * 2.0 - room_inset_lt(i)

## The walled, walkable area of a room (equals room_rect for full-size
## rooms). Cameras, spawns and clamps all use THIS rect.
func play_rect(i: int) -> Rect2:
	var ins := room_inset(i)
	return Rect2(rooms[i]["origin"] + room_inset_lt(i), Vector2(ROOM_W, ROOM_H) - ins * 2.0)

## Room-local x/y of the door LANES (the cell's centre lines) inside the play
## rect — where the roads run and the door gaps sit. Equal to half the play
## rect only when the inset is symmetric.
func lane_local(i: int) -> Vector2:
	return Vector2(ROOM_W, ROOM_H) / 2.0 - room_inset_lt(i)

## CORNER BITES (P7.C, 2026-08-19; owner: "the room shape can also be
## asymmetric"). A combat room may have one or two corners carved away as
## SOLID wall blocks, so its footprint reads L- or T-shaped instead of a box.
## Returns the notch rects in WORLD space ([] for rooms left whole: boss,
## safe, authored-scale, non-combat). Hashed per room index — no RNG,
## identical on every machine and every rebuild. A notch never reaches a door
## lane (ROOM_NOTCH_LANE_CLEAR off the lane's gap), so corridors and the roads
## stay open; game_world builds them as walls (_build_room_walls), scenery,
## hazards and authored spawns avoid them (room_pos / reserved / _spawn_patches),
## and free_spawn_pos sees them as walls through physics.
func room_notches(i: int) -> Array:
	if room_type(i) != "combat" or String(zones[i].get("boss", "")) != "" \
			or float(zones[i].get("room_scale", 1.0)) < 1.0 or Balance.ROOM_NOTCH_CHANCE.is_empty():
		return []
	var h1 := float((i * 2246822519) & 1023) / 1023.0
	var h2 := float((i * 3266489917 + 311) & 1023) / 1023.0
	var h3 := float((i * 668265263 + 977) & 1023) / 1023.0
	var h4 := float((i * 374761393 + 1531) & 1023) / 1023.0
	# how many: cumulative chances [none, one, two]
	var count := 0
	var acc := 0.0
	for n in Balance.ROOM_NOTCH_CHANCE.size():
		acc += float(Balance.ROOM_NOTCH_CHANCE[n])
		if h1 < acc:
			count = n
			break
	if count <= 0:
		return []
	var r := play_rect(i)
	var lane := lane_local(i)
	var gap := DOOR_TILES * TILE
	var clear := Balance.ROOM_NOTCH_LANE_CLEAR
	var out: Array = []
	var first := int(h2 * 4.0) % 4           # 0 NW, 1 NE, 2 SW, 3 SE
	var corners := [first]
	if count >= 2:
		corners.append((first + 1 + int(h3 * 3.0) % 3) % 4)
	for k in corners.size():
		var corner: int = corners[k]
		var hw := h3 if k == 0 else h4
		var hh := h4 if k == 0 else h2
		var w := lerpf(Balance.ROOM_NOTCH_MIN.x, Balance.ROOM_NOTCH_MAX.x, hw)
		var hgt := lerpf(Balance.ROOM_NOTCH_MIN.y, Balance.ROOM_NOTCH_MAX.y, hh)
		var west: bool = corner in [0, 2]
		var north: bool = corner in [0, 1]
		# never into a door lane: cap the reach toward the lane
		var max_w: float = (lane.x - gap / 2.0 - clear) if west else (r.size.x - lane.x - gap / 2.0 - clear)
		var max_h: float = (lane.y - gap / 2.0 - clear) if north else (r.size.y - lane.y - gap / 2.0 - clear)
		w = minf(w, max_w)
		hgt = minf(hgt, max_h)
		if w < Balance.ROOM_NOTCH_MIN.x * 0.7 or hgt < Balance.ROOM_NOTCH_MIN.y * 0.7:
			continue
		var x := r.position.x if west else r.end.x - w
		var y := r.position.y if north else r.end.y - hgt
		out.append(Rect2(x, y, w, hgt))
	return out


## Push a point OUT of any corner bite (grown by `margin` so a body never
## stands half inside the block): to the nearest edge of the grown rect.
func notch_clear(i: int, p: Vector2, margin := 36.0) -> Vector2:
	for n in room_notches(i):
		var g: Rect2 = (n as Rect2).grow(margin)
		if not g.has_point(p):
			continue
		var dl := p.x - g.position.x
		var dr := g.end.x - p.x
		var dt := p.y - g.position.y
		var db := g.end.y - p.y
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			p.x = g.position.x - 1.0
		elif m == dr:
			p.x = g.end.x + 1.0
		elif m == dt:
			p.y = g.position.y - 1.0
		else:
			p.y = g.end.y + 1.0
	return p


## Map an authored in-room position into the playable rect — authored
## coordinates assume the full cell, so small rooms scale them down. A point
## that lands in a corner bite is pushed out of it (P7.C).
func room_pos(i: int, x: float, y: float) -> Vector2:
	var meta: Dictionary = rooms[i]
	var p: Vector2 = Vector2(x, y) * meta["scale"]
	var ins := room_inset(i)
	if ins != Vector2.ZERO:
		p = room_inset_lt(i) + p * (Vector2(ROOM_W, ROOM_H) - ins * 2.0) / Vector2(ROOM_W, ROOM_H)
	return notch_clear(i, meta["origin"] + p)

func room_center(i: int) -> Vector2:
	return rooms[i]["origin"] + Vector2(ROOM_W, ROOM_H) / 2.0

## Explicit player arrivals use Crown Plaza's authored clear approach.
## Keep geometric centers unchanged for rooms, roads, loot and encounters.
## This is a placement lookup, not a physics query: a chapter rebuild can
## call it before that room's scenery has entered the physics space.
func room_arrival_pos(i: int) -> Vector2:
	if chapter_id == "capital" and i == 0:
		return _start_pos()
	return room_center(i)

## The room whose grid cell contains pos (-1 = outside the graph).
func room_at_pos(pos: Vector2) -> int:
	var c := Vector2i(floori(pos.x / ROOM_W), floori(pos.y / ROOM_H))
	return int(coord_to_room.get(c, -1))

## World position of the door on room i's `dir` edge.
func door_pos(i: int, dir: String) -> Vector2:
	var r := room_rect(i)
	match dir:
		"N": return Vector2(r.position.x + ROOM_W / 2.0, r.position.y)
		"S": return Vector2(r.position.x + ROOM_W / 2.0, r.end.y)
		"E": return Vector2(r.end.x, r.position.y + ROOM_H / 2.0)
	return Vector2(r.position.x, r.position.y + ROOM_H / 2.0)  # W

## The declared room type ("combat"/"boss"/"safe" derived when absent).
func room_type(i: int) -> String:
	var zone: Dictionary = zones[i]
	var t := String(zone.get("type", ""))
	if t != "":
		return t
	if String(zone.get("boss", "")) != "":
		return "boss"
	if not zone.get("enemies", []).is_empty():
		return "combat"
	return "safe"

## Is this room fully pacified (no living packs, boss dead or none)?
func room_pacified(i: int) -> bool:
	if built.get(i, false):
		if zone_alive.get(i, 0) > 0:
			return false
	elif not cleared.get(i, false) and not zones[i].get("enemies", []).is_empty():
		return false
	var kind: String = zones[i].get("boss", "")
	return kind == "" or _boss_room_resolved(i)

## Death returns you to rooms like these; the map can travel to them.
func room_safe(i: int) -> bool:
	return room_type(i) != "combat" and room_type(i) != "boss" and room_pacified(i)


## Where a death drops you: the NEAREST pacified room to where you fell (BFS
## over the room graph), so a boss wipe leaves you just outside the arena you
## cleared to — not back at the last village 7 rooms away (2026-07-09). A
## CLEARED combat room counts (room_pacified), unlike room_safe/travel which
## still bar combat rooms by design. Falls back to last_safe_room, then 0.
func respawn_room(death_room: int) -> int:
	var seen := {death_room: true}
	var frontier: Array = [death_room]
	while not frontier.is_empty():
		var pacified: Array = frontier.filter(
			func(i: int) -> bool: return visited.get(i, false) and room_pacified(i))
		if not pacified.is_empty():
			# At the nearest distance with any pacified room, prefer a TRUE
			# safe pocket (camp/shrine) over a cleared battlefield.
			for i in pacified:
				if room_safe(i):
					return i
			return pacified[0]
		var next: Array = []
		for i in frontier:
			for dir in rooms[i]["exits"].keys():
				var nb := neighbor(i, dir)
				if nb >= 0 and not seen.has(nb):
					seen[nb] = true
					next.append(nb)
		frontier = next
	return last_safe_room

## Map fast-travel rule: visited safe pockets, plus boss arenas after
## the kill. Combat rooms are never travel targets (DESIGN.md).
## Charted for the map: a room the player has entered — OR any room of a
## standalone world (the capital), which is fully mapped from the first step.
func charted(i: int) -> bool:
	return Story.is_standalone(chapter_id) or visited.get(i, false)


func travel_target(i: int) -> bool:
	if i == cur_room:
		return false
	# No map-travel in a duel — teleporting out of (or into) the arena would
	# skip the gates that ARE the match structure. The controller moves bodies.
	if pvp_active:
		return false
	# In the capital every room is a safe fast-travel target (the whole city is
	# charted), so a click on the map walks you there — no "must visit first".
	if Story.is_standalone(chapter_id):
		return room_safe(i)
	if not visited.get(i, false):
		return false
	if room_type(i) == "boss":
		var kind: String = zones[i].get("boss", "")
		return kind != "" and boss_done.get(kind, false)
	return room_safe(i)

## Is a locked edge's condition met? (Unlocked edges return true.)
func _edge_unlocked(a: int, b: int) -> bool:
	var info: Dictionary = edge_locks.get(_edge_key(a, b), {})
	var lock := String(info.get("lock", ""))
	if lock == "":
		return true
	var own := int(info.get("own", a))
	if lock == "boss":
		var kind: String = zones[own].get("boss", "")
		return kind == "" or boss_done.get(kind, false)
	if lock == "clear":
		return room_pacified(own)
	if lock.begins_with("flag:"):
		return bool(get_flag(lock.substr(5), false))
	return true

## Where the player starts this chapter (start_pos is authored in the
## first room's local space).
func _start_pos() -> Vector2:
	var sp: Array = Story.chapter(chapter_id).get("start_pos", [280, 624])
	if rooms.is_empty():
		return Vector2(float(sp[0]), float(sp[1]))
	var meta: Dictionary = rooms[0]
	return meta["origin"] + Vector2(float(sp[0]), float(sp[1])) * meta["scale"]


# ------------------------------------------------ entering & building ---

func _cache_flag(i: int) -> String:
	return "cache_%s_%d" % [chapter_id, i]

# Risk-event once-per-run flags (wiped by replay's flag reset, like caches).
func _curse_flag(i: int) -> String:
	return "cursed_%s_%d" % [chapter_id, i]

func _shrine_flag(i: int) -> String:
	return "shrined_%s_%d" % [chapter_id, i]

func _hidden_flag(i: int) -> String:
	return "hidden_%s_%d" % [chapter_id, i]

## Road Deck (Q14): one card per character per room. Not a kept prefix, so a
## chapter wipe re-rolls the deck on replay — like cursed_/shrined_/hidden_.
func _road_flag(i: int) -> String:
	return "road_%s_%d" % [chapter_id, i]

## The gamble shrine's ask, scaled with level like the daily gold.
func shrine_cost() -> int:
	return int(ceil(Balance.SHRINE_COST_BASE * Balance.daily_gold_mult(player.level)))

## The seeded per-character roll for social room i. ONE place for the
## formula: the room build consumes it, and social_holds_elite lets
## the autotest predict the outcome instead of guessing.
func _social_rng(i: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 23 + i * 173 + chapter_id.hash() % 7717
	return rng

## Does social room i hold a lone elite instead of a wanderer?
func social_holds_elite(i: int) -> bool:
	return _social_rng(i).randf() < Balance.ELITE_SOCIAL_ROOM_CHANCE

## Every boss still standing (pruned of dead/freed ones).
func _live_bosses() -> Array:
	for i in range(bosses.size() - 1, -1, -1):
		if not is_instance_valid(bosses[i]) or bosses[i].dying:
			bosses.remove_at(i)
	return bosses

## Dev: wipe the instrument to a clean slate. Spawning or removing a boss
## from the F1 panel starts a fresh benchmark — no pool, roster, wipes or
## clock carried over from an abandoned fight. Without this, respawning a
## boss mid-benchmark leaked the old fight's state into the next report:
## an unkilled boss stayed active so its HP joined the new pool (doubling
## realized dps), and its wipes/damage-taken rode into a different boss's
## numbers. Benchmark data is only trustworthy from a clean start.
func fight_reset() -> void:
	fight_active = false
	fight_time = 0.0
	fight_dmg_taken = 0.0
	fight_potions = 0
	fight_wipes = 0
	fight_pool = 0.0
	fight_names.clear()
	fight_titles.clear()
	fight_kinds.clear()
	fight_seen.clear()


## First blood on a boss roster: start the clock, capture the field.
func fight_engage() -> void:
	fight_active = true
	fight_time = 0.0
	fight_dmg_taken = 0.0
	fight_potions = 0
	fight_pool = 0.0
	fight_names.clear()
	fight_titles.clear()
	fight_kinds.clear()
	fight_seen.clear()
	fight_stats.clear()  # fresh per-player battle-stats window for this fight
	for b in _live_bosses():
		fight_track(b)


# ------------------------------------------------- party battle stats ---

## The local hero's display name: its chosen character name, or the OS
## account name when it was left blank (unnamed legacy saves) — the exact
## fallback the HUD identity line and the lobby use, so a hero reads the
## same everywhere. "Hero" only if even the account name can't be read.
func local_display_name() -> String:
	if is_instance_valid(local_player):
		var cn := String(local_player.char_name).strip_edges()
		if cn != "":
			return cn
	var sess: Node = net_session()
	if sess != null:
		var osn := String(sess.os_name()).strip_edges()
		if osn != "":
			return osn
	return "Hero"


## The meter row for a player, created on first contribution. Name/class
## snapshot at that moment (a guest's shell carries its net_name meta; the
## local hero resolves through local_display_name so a blank char_name shows
## the account name, not the class fallback the meter would otherwise draw).
func _stat_bucket(store: Dictionary, p: Player) -> Dictionary:
	var pid := int(p.peer_id)
	if not store.has(pid):
		var nm := String(p.get_meta("net_name", ""))
		if nm == "" and is_instance_valid(local_player) and p == local_player:
			nm = local_display_name()
		store[pid] = {"name": nm, "cls": p.cls, "dmg": 0.0, "heal": 0.0, "taken": 0.0}
	return store[pid]


## Damage a player's blow actually APPLIED to an enemy (post-mitigation).
## Called from enemy.take_damage on the machine that applied it — the host
## in a session (guest hits arrive through the funnel RPC with their shell
## as striker), this machine solo. DoT ticks credit their source.
func stat_dmg(p: Player, amount: float) -> void:
	if p == null or not is_instance_valid(p) or amount <= 0.0:
		return
	_stat_bucket(party_stats, p)["dmg"] += amount
	if fight_active:
		_stat_bucket(fight_stats, p)["dmg"] += amount

## HP a player actually recovered (gain_hp, post-cap). Owner-side.
func stat_heal(p: Player, amount: float) -> void:
	if p == null or not is_instance_valid(p) or amount <= 0.0:
		return
	_stat_bucket(party_stats, p)["heal"] += amount
	if fight_active:
		_stat_bucket(fight_stats, p)["heal"] += amount

## HP a player actually lost to a hit (take_damage, post-mitigation). Owner-side.
func stat_taken(p: Player, amount: float) -> void:
	if p == null or not is_instance_valid(p) or amount <= 0.0:
		return
	_stat_bucket(party_stats, p)["taken"] += amount
	if fight_active:
		_stat_bucket(fight_stats, p)["taken"] += amount


## The table to DISPLAY: local truth everywhere except a guest in a
## session, who shows the host's merged fan (its own rows lag ~1 s).
func party_stats_view() -> Dictionary:
	if net_online() and not net_host() and not party_stats_net.is_empty():
		return party_stats_net
	return party_stats


## Meter number formatting: 12.4K / 1.2M — the bar labels stay short.
static func fmt_meter(v: float) -> String:
	if v >= 1_000_000.0:
		return "%.1fM" % (v / 1_000_000.0)
	if v >= 10_000.0:
		return "%.0fK" % (v / 1_000.0)
	if v >= 1_000.0:
		return "%.1fK" % (v / 1_000.0)
	return str(int(v))


## Pool a boss into the running fight (engage roster or a brawl
## reinforcement that spawned mid-fight).
func fight_track(b: Boss) -> void:
	var iid := b.get_instance_id()
	if fight_seen.has(iid):
		return
	fight_seen[iid] = true
	fight_pool += b.max_hp
	fight_names.append("%s Lv%d" % [b.kind, b.level])
	fight_titles.append(b.display_name)
	fight_kinds.append(b.kind)


## Player HP lost while a fight runs. A boss landing the FIRST hit of
## the fight engages it (telegraph/hazard damage carries no attacker
## and only counts once the fight is live).
func fight_note_damage(amount: float, attacker: Node) -> void:
	if not fight_active:
		if not (attacker is Boss) or _live_bosses().is_empty():
			return
		fight_engage()
	fight_dmg_taken += amount


func fight_note_potion() -> void:
	if fight_active:
		fight_potions += 1


## Player died mid-fight: bosses walk home and heal, the clock is void.
## The wipe survives into the retry's report.
func fight_wipe() -> void:
	if not fight_active:
		return
	fight_active = false
	fight_seen.clear()
	fight_wipes += 1


## The last boss fell: print the benchmark line and float it on screen.
func fight_report() -> void:
	if not fight_active:
		return
	fight_active = false
	fight_seen.clear()
	var secs := maxf(fight_time, 0.1)
	var mins := int(secs / 60.0)
	var roster := " + ".join(fight_names)
	var head := "FIGHT  %d:%02d — %s" % [mins, int(secs) % 60, roster]
	var mid := "%.0f dps vs %.0f boss HP" % [fight_pool / secs, fight_pool]
	var tail := "taken %.0f (%.1f/s) · potions %d · wipes %d" % [
		fight_dmg_taken, fight_dmg_taken / secs, fight_potions, fight_wipes]
	last_fight_report = head + "\n" + mid + "\n" + tail
	var who := "%s Lv%d" % [player.cls, player.level] if has_local_player() else "server"
	print("[fight] %s | %s | ttk %d:%02d | pool %.0f | dps %.1f | taken %.0f | potions %d | wipes %d" % [
		roster, who, mins, int(secs) % 60,
		fight_pool, fight_pool / secs, fight_dmg_taken, fight_potions, fight_wipes])
	fight_wipes = 0
	if is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -104), head, Color(0.95, 0.85, 0.5), 5.0)
		spawn_text(player.global_position + Vector2(0, -82), mid, Color(0.85, 0.9, 1.0), 5.0)
		spawn_text(player.global_position + Vector2(0, -60), tail, Color(0.85, 0.9, 1.0), 5.0)
	# The on-screen report fades in seconds (round 44) — mail a keepsake:
	# a victory letter carrying the same stat block, so the fight is on
	# record in the pause menu long after the numbers float away.
	var name_list: Array = fight_titles if not fight_titles.is_empty() else fight_names
	var titles := " + ".join(name_list)
	# Many-boss fights would make an unwieldy subject that overruns the
	# mailbox list and the letter window title — keep the subject to the
	# first couple of names; the body still names the whole roster.
	var subject := titles
	if name_list.size() > 2:
		subject = "%s + %s + %d more" % [name_list[0], name_list[1], name_list.size() - 2]
	# Party battle stats (host-side truth): a per-member damage breakdown
	# rides the victory letter whenever a session fight had 2+ contributors.
	var party_block := ""
	if net_online() and fight_stats.size() >= 2:
		var brows: Array = fight_stats.values()
		brows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("dmg", 0.0)) > float(b.get("dmg", 0.0)))
		party_block = "\n\nThe party's blades:"
		for r in brows:
			var pn := String(r.get("name", ""))
			if pn == "":
				pn = String(Classes.CLASSES.get(String(r.get("cls", "")), {}).get("name", "Ally"))
			party_block += "\n  %s — %s dmg (%.0f%%)" % [pn,
				fmt_meter(float(r.get("dmg", 0.0))),
				100.0 * float(r.get("dmg", 0.0)) / maxf(1.0, fight_pool)]
	send_mail("Victory — %s" % subject,
		"You brought down %s!\n\nThe record of the fight:\n\n%s%s" % [titles, last_fight_report, party_block], [])

	# Personal bests + achievements from the concluded fight. (dps here is
	# the encounter's realized dps; for solo story bosses it's exact.)
	var dps := fight_pool / secs
	for k in fight_kinds:
		record_boss(String(k), secs, dps)
	if not fight_kinds.is_empty():
		if fight_dmg_taken <= 0.0:
			unlock_achievement("flawless")
		if fight_potions <= 0:
			unlock_achievement("no_potion_boss")
		call("check_track_achievements")  # Bossbreaker tiers (game_flow owns tracks)


## The fight's music. Multi-boss brawls use the boss_x2..boss_x5
## override tracks when present (drop them in assets/music/); until
## then, the first boss's own theme carries the fight.
func _boss_music() -> String:
	var live := _live_bosses()
	if live.is_empty():
		return Terrains.get_terrain(terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]).get("music", "village")
	var multi := "boss_x%d" % mini(live.size(), 5)
	if live.size() > 1 and music_tracks.has(multi):
		return multi
	return _boss_track(String(live[0].kind))


## A single boss's fight track. The enemy data is the source of truth:
## its declared `music`, else `music_fallback`, else the terrain track
## (never silence). A real boss_<kind>.wav dropped into assets/music/
## auto-adopts by matching the declared name. Bosses that declare no
## music key keep the legacy "boss_<kind>" default. This is the ONLY
## resolver both the story spawn and the dev roster hit — the content
## modules' own spawn() helpers are dev/selftest sugar.
func _boss_track(kind: String) -> String:
	var data: Dictionary = Story.ALL_ENEMIES.get(kind, {})
	var track: String = data.get("music", "boss_" + kind)
	if music_tracks.has(track):
		return track
	var fallback: String = data.get("music_fallback", "")
	if fallback != "" and music_tracks.has(fallback):
		return fallback
	return Terrains.get_terrain(terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]).get("music", "village")

## Quest line + live "monsters left" counter for the player's room.
func refresh_quest() -> void:
	# The current pocket card owns its local rule/phase and exit instruction.
	# Keep the campaign state intact; ordinary room entry refreshes it again.
	if cur_room == pocket_room and pocket_room >= 0 and pocket_room < zones.size() \
			and not Pockets.entry(pocket_id).is_empty() \
			and String(zones[pocket_room].get("pocket", "")) == pocket_id:
		hud.set_quest("")
		return
	var text: String = Story.quest_text(quest_key).strip_edges()
	var zi: int = clampi(cur_room, 0, zone_count - 1)
	var left: int = zone_alive.get(zi, 0)
	if left > 0:
		# Sealed doors need a visible WHY: every ordinary room with living
		# packs keeps the same purge counter, even without campaign text.
		if text != "":
			text += "   —   "
		text += "%d monster%s left" % [left, "" if left == 1 else "s"]
	hud.set_quest(text)

## Clamp a position into the room that contains `anchor` (dashes, drops
## and boss blinks never leave the room they started in).
func clamp_to_zone(pos: Vector2, anchor: Vector2) -> Vector2:
	var zi := room_at_pos(anchor)
	if zi < 0:
		zi = clampi(cur_room, 0, zone_count - 1)
	var r := play_rect(zi)
	if not pos.is_finite():
		return r.get_center()   # clampf(nan) passes nan through; bound to the room instead
	return Vector2(
		clampf(pos.x, r.position.x + 80.0, r.end.x - 80.0),
		clampf(pos.y, r.position.y + 90.0, r.end.y - 90.0)
	)


## clamp_to_zone that also nudges the point OFF any wall/obstacle (physics mask
## 1) so a spawned boss / add / teleport doesn't land inside terrain. Spirals
## out through a few rings of angles; falls back to the clamped point if the
## room is too dense to find open floor.
func free_spawn_pos(pos: Vector2, anchor: Vector2) -> Vector2:
	var p := clamp_to_zone(pos, anchor)
	if not _pos_in_wall(p):
		return p
	for rad in [72.0, 130.0, 190.0, 260.0]:
		for i in 8:
			var cand := clamp_to_zone(pos + Vector2.from_angle(TAU * i / 8.0) * rad, anchor)
			if not _pos_in_wall(cand):
				return cand
	return p

func _vol_db(linear: float) -> float:
	return -80.0 if linear <= 0.01 else linear_to_db(linear)


## Switch the background track with a quick fade.
## Per-track mix fixes for external recordings (measured RMS): dB gain
## evens out mastering differences, start skips long quiet intros
## (loops restart from the same offset via the stream's loop_offset).
## A looping copy of a loaded sound for positional players (the shared
## sounds-dict stream must not be flipped to looping globally).
func game_stream(name: String) -> AudioStream:
	var s: AudioStream = sounds.get(name)
	if s == null:
		return null
	var copy: AudioStream = s.duplicate()
	if copy is AudioStreamMP3 or copy is AudioStreamOggVorbis:
		copy.loop = true
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return copy


# Footsteps (GameSounds cast): a soft step on a distance-ish cadence
# while the hero moves. Plate classes (warrior/paladin) clank.
var _foot_t := 0.0

func tick_footsteps(delta: float) -> void:
	if player == null or player.dead or not play_started:
		return
	if player.velocity.length() < 60.0:
		_foot_t = 0.12  # next step lands quickly when motion resumes
		return
	_foot_t -= delta
	if _foot_t > 0.0:
		return
	if player.skin == "phantom":
		# Phantom drifts — a soft airy swish REPLACES the footfall so he reads
		# as gliding, not stomping. Slow, even 1s cadence (a glide, not steps).
		_foot_t = 1.0
		sfx("glide", 1.0, 0.0, -18.0)
		return
	_foot_t = clampf(88.0 / maxf(player.velocity.length(), 1.0), 0.24, 0.42)
	var armor := player.cls in ["warrior", "paladin"]
	var key := "step_armor_%d" % (randi() % 3 + 1) if armor else "step_%d" % (randi() % 3 + 1)
	sfx(key, 1.0, 0.0, -8.0)  # quiet: felt more than heard


## A little grey scuff of dust — dashes, rolls, hard landings.
func dust(pos: Vector2, count := 5) -> void:
	for i in count:
		var puff := Sprite2D.new()
		puff.texture = Art.tex("glow")
		puff.modulate = Color(0.75, 0.72, 0.66, 0.5)
		puff.global_position = pos + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 8.0))
		puff.scale = Vector2(0.25, 0.25)
		puff.z_index = -4
		world.add_child(puff)
		var tw := puff.create_tween()
		tw.tween_property(puff, "scale", Vector2(0.55, 0.55), 0.35)
		tw.parallel().tween_property(puff, "global_position:y",
			puff.global_position.y - randf_range(4.0, 12.0), 0.35)
		tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.35)
		tw.tween_callback(puff.queue_free)


# Snow footprints (visual pass): fading tracks behind anyone crossing
# snow ground. Spacing-gated, so standing still leaves nothing.
var _step_pos := Vector2.ZERO

func track_footprints() -> void:
	if player == null or player.dead or zone_count == 0 or world == null:
		return
	var tid: String = terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]
	if String(Terrains.get_terrain(tid).get("ground", "")) != "snow":
		return
	var fp := player.global_position + Vector2(0, 18)
	if fp.distance_to(_step_pos) < 26.0 or player.velocity.length() < 20.0:
		return
	_step_pos = fp
	var print_spr := Sprite2D.new()
	print_spr.texture = Art.tex("shadow")
	print_spr.modulate = Color(0.25, 0.3, 0.42, 0.3)
	print_spr.global_position = fp
	print_spr.scale = Vector2(0.5, 0.32)
	print_spr.z_index = -9
	world.add_child(print_spr)
	var tw := print_spr.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(print_spr, "modulate:a", 0.0, 2.2)
	tw.tween_callback(print_spr.queue_free)


## A small water ripple at the feet of whatever is wading.
func _ripple(pos: Vector2) -> void:
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(0.8, 0.9, 0.95, 0.5)
	ring.global_position = pos
	ring.scale = Vector2(0.22, 0.12)  # squashed: a ripple, not a shockwave
	ring.z_index = -8
	world.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(0.7, 0.36), 0.5)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)


## Keep the ambient bed matched to the room the player stands in.
## Called every frame (string compare when nothing changed) so every
## path — room change, chapter switch, terrain repaint, load — is
## covered by one hook.
func refresh_ambience() -> void:
	if amb_player == null or zone_count == 0:
		return
	var tid: String = terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]
	# Scale world lights to the terrain's darkness: bright tints (village
	# daylight) mute them, dark tints (void, grave) run them full — keeps
	# additive lights from washing daylight scenes into bloom.
	var tint: Color = Terrains.get_terrain(tid)["tint"]
	var lum := (tint.r + tint.g + tint.b) / 3.0
	light_mult = clampf((1.05 - lum) * 2.2, 0.1, 1.0)
	if player != null and player.halo != null:
		player.halo.energy = 0.9 * light_mult  # QA 5: 0.45 read as nothing
		# QA 5, part two: 2D lights scale with surface albedo — void's
		# near-black ground reflects nothing, so an additive floor-pool
		# sprite carries the halo there. Attached from the game side
		# (ambience owns its alpha; player_core stays untouched).
		if _halo_pool == null or not is_instance_valid(_halo_pool):
			_halo_pool = Sprite2D.new()
			_halo_pool.texture = Art.tex("glow")
			_halo_pool.modulate = Color(1.0, 0.93, 0.8, 0.0)
			_halo_pool.scale = Vector2(3.2, 3.2)
			_halo_pool.z_index = -6
			player.add_child(_halo_pool)
		_halo_pool.modulate.a = 0.16 * light_mult
	var kind: String = Terrains.AMBIENT_LOOPS.get(tid, "")
	if kind == current_amb:
		return
	current_amb = kind
	if kind == "":
		amb_player.stop()
		return
	if not amb_tracks.has(kind):
		amb_tracks[kind] = Sfx.make_ambient(kind)
	amb_player.stream = amb_tracks[kind]
	amb_player.volume_db = AMB_DB  # SFX bus applies the volume slider
	amb_player.play()


func set_music(name: String) -> void:
	if name == current_track or music_player == null:
		return
	current_track = name
	var tune: Dictionary = MUSIC_TUNE.get(name, {})
	music_gain_db = MUSIC_DB + float(tune.get("gain", 0.0))
	var tween := create_tween()
	# The crossfade must run while the tree is paused (boot menus pause it).
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_player, "volume_db", -40.0 + _vol_db(float(settings["music"])), 0.4)
	tween.tween_callback(func() -> void:
		if name == "" or not music_tracks.has(name):
			music_player.stop()
			return
		music_player.stream = music_tracks[name]
		music_player.play(float(tune.get("start", 0.0)))
	)
	tween.tween_property(music_player, "volume_db", music_gain_db + _vol_db(float(settings["music"])), 0.6)

## Play a sound. pitch shifts the base pitch (still ±6% randomized);
## cutoff > 0 fades the sound out after that many seconds — lets long
## recordings (like a real wolf howl) play only their opening.
func _build_sound_groups() -> void:
	sound_groups.clear()
	sound_group_last.clear()
	sfx_rng.randomize()
	for raw_key in sounds.keys():
		var stream_key := String(raw_key)
		var marker := stream_key.rfind("_v")
		if marker <= 0:
			continue
		var suffix := stream_key.substr(marker + 2)
		if not suffix.is_valid_int():
			continue
		var group_key := stream_key.substr(0, marker)
		if not sound_groups.has(group_key):
			sound_groups[group_key] = []
		var group: Array = sound_groups[group_key]
		group.append(stream_key)
	for raw_group in sound_groups.values():
		var group: Array = raw_group
		group.sort()


func _sound_variant(name: String) -> String:
	if not sound_groups.has(name):
		return name
	var group: Array = sound_groups[name]
	if group.size() <= 1:
		return String(group[0]) if not group.is_empty() else name
	var last := int(sound_group_last.get(name, -1))
	if last < 0:
		var first := sfx_rng.randi_range(0, group.size() - 1)
		sound_group_last[name] = first
		return String(group[first])
	# Draw from N-1 slots, then skip over the previous index. This is a
	# shuffle-bag-sized guarantee: variety without mutating gameplay RNG.
	var pick := sfx_rng.randi_range(0, group.size() - 2)
	if pick >= last:
		pick += 1
	sound_group_last[name] = pick
	return String(group[pick])


func sfx(name: String, pitch := 1.0, cutoff := 0.0, vol_db := 0.0) -> void:
	var stream_key := _sound_variant(name)
	if not sounds.has(stream_key):
		return
	var chosen: AudioStreamPlayer = sound_pool[0]
	for sp in sound_pool:
		if not sp.playing:
			chosen = sp
			break
	# Taking the slot cancels any cutoff fade still pending on it: that fade
	# belongs to the play that scheduled it, not to the player. Without this
	# it ducks (and re-stamps the level of) whatever sound is here now.
	var pending: Tween = sfx_cutoff_tweens.get(chosen, null)
	if pending != null and pending.is_valid():
		pending.kill()
	sfx_cutoff_tweens.erase(chosen)
	# Small random pitch per play: kills the machine-gun sameness of
	# repeated samples and the phasing of near-simultaneous ones.
	# vol_db offsets the base level (e.g. quiet ambient stings).
	chosen.pitch_scale = pitch * randf_range(0.94, 1.06)
	chosen.volume_db = Balance.SFX_BASE_DB + vol_db
	chosen.stream = sounds[stream_key]
	chosen.play()
	if cutoff > 0.0:
		var tween := create_tween()
		sfx_cutoff_tweens[chosen] = tween
		tween.tween_interval(cutoff)
		tween.tween_property(chosen, "volume_db", Balance.SFX_CUTOFF_DUCK_DB, Balance.SFX_CUTOFF_FADE)
		tween.tween_callback(func() -> void:
			chosen.stop()
			sfx_cutoff_tweens.erase(chosen)
		)

## Camera shake. `amount` = the random jitter (existing beats), `dir` + `kick`
## = a DIRECTIONAL push of `kick` px along the hit vector that decays
## exponentially (Balance.HIT_SHAKE_KICK_DECAY) — the P1 hit-feedback stack
## reads the direction of a blow, not just its size.
func shake(amount: float, dir := Vector2.ZERO, kick := 0.0) -> void:
	shake_amt = maxf(shake_amt, amount)
	if kick > 0.0 and dir != Vector2.ZERO:
		_shake_kick += dir.normalized() * kick


## HIT-STOP: freeze the world for `sec` of REAL time (Engine.time_scale 0,
## restored to whatever it was — dev slow-mo included). Presentation only:
## SOLO only (a shared world never stalls, §5.4 — co-op keeps the sprite juice
## and skips this), never headless (the suite would only slow down), never
## under a pause. Overlapping stops extend, they don't stack.
func hit_stop(sec: float) -> void:
	if sec <= 0.0 or get_tree().paused or not bool(settings.get("hit_stop", true)):
		return
	if net_online() or DisplayServer.get_name() == "headless":
		return
	var end_ms := Time.get_ticks_msec() + int(sec * 1000.0)
	if _hitstop_active:
		_hitstop_end_ms = maxi(_hitstop_end_ms, end_ms)
		return
	_hitstop_active = true
	_hitstop_end_ms = end_ms
	_hitstop_restore = Engine.time_scale
	Engine.time_scale = 0.0
	_hitstop_run()


func _hitstop_run() -> void:
	while Time.get_ticks_msec() < _hitstop_end_ms:
		# real-time timer: process_always, not physics, IGNORES time_scale
		await get_tree().create_timer(0.004, true, false, true).timeout
		if not is_inside_tree():
			return
	Engine.time_scale = _hitstop_restore
	_hitstop_active = false


## Impact SPARKS at the contact point: a few bright chips flung AWAY from the
## striker along `dir`, tinted by the hit (white-hot core over the theme colour),
## short-lived, under gravity. The middle beat of the P1 stack; a crit throws
## more and faster.
func impact(pos: Vector2, dir: Vector2, color: Color, is_crit := false) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -10)
	p.amount = int(round(Balance.HIT_SPARKS * (1.8 if is_crit else 1.0)))
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.26
	p.texture = Art.tex("spark")
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = 48.0
	p.initial_velocity_min = 140.0 if not is_crit else 190.0
	p.initial_velocity_max = 260.0 if not is_crit else 340.0
	p.gravity = Vector2(0, 520)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.0 if not is_crit else 1.3
	p.color = Color(1, 1, 1).lerp(color, 0.45)
	p.color_ramp = null
	p.z_index = 15
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## Telegraphed ground attack: a danger zone appears, pulses for `delay`
## seconds, then erupts — heavy damage if the player is still inside.
## opts may add a falling object with:
##   {"falling_sprite": String, "falling_scale": float, "falling_end_y": float}
## The old {"sword": true} and {"fireball": true} forms remain compatible for
## non-boss callers, but bosses name their own sprite so signature weapons do
## not silently bleed from one encounter into another.
## A world position sheltered by any LIVE SafeDome? (Ground warded by an
## airborne safe-spot exam — see SafeDome above.)
func _sheltered(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("safe_domes"):
		var dome := node as SafeDome
		if dome and dome.shelters(pos):
			return true
	return false


## ------------------------------------------------- tell shape vocabulary ---
## A telegraph's per-boss ACCENT, drawn INSIDE the danger disc.
##
## The disc itself is never replaced: it is the truth about where the damage
## lands, and every one of the 47 boss sites was tuned against it. A cone or a
## bar that also became the HIT SHAPE would quietly shrink a boss's danger area
## to a fraction of the circle — a balance nerf smuggled in under a visual pass.
## So the fill/rim disc stays exactly as it was, and the shape adds a figure on
## top of it: the boss is identifiable at a glance, the dodge is unchanged.
##
##   ring    a bright band inside the rim — bells, wails, novas
##   cone    a wedge from the centre along opts.dir (arc = half-angle) — claws, breath
##   line    a bar across the disc along opts.dir — lashes, charges, beams
##   cross   two crossed bars — sigil slams
##   square  an inscribed plot outline — grave work, slabs, ice floors
##
## Everything is a Polygon2D/Line2D at white, tinted by the parent's modulate,
## so ONE fuse tween drives the whole thing and the co-op mirror needs no new
## plumbing (opts stay Vector2/float/String, which the telegraph RPC serialises).
func _tell_accent(shape: String, radius: float, opts: Dictionary) -> Node2D:
	var root := Node2D.new()
	var d: Vector2 = opts.get("dir", Vector2.RIGHT)
	if not d.is_finite() or d == Vector2.ZERO:
		d = Vector2.RIGHT
	d = d.normalized()
	var arc := float(opts.get("arc", 0.55))
	# Every accent is clamped INSIDE the disc: an accent poking past the rim
	# would promise danger where none lands (the inverse lie).
	var r := radius * 0.82
	var width := minf(float(opts.get("width", maxf(20.0, radius * 0.30))), radius * 0.7)
	var pts := PackedVector2Array()
	match shape:
		"ring":
			var inner: float = r * 0.66
			var steps := 30
			for i in steps + 1:
				var a: float = TAU * float(i) / float(steps)
				pts.append(Vector2(cos(a), sin(a)) * r)
			for i in steps + 1:
				var a2: float = TAU * float(steps - i) / float(steps)
				pts.append(Vector2(cos(a2), sin(a2)) * inner)
		"cone":
			pts.append(Vector2.ZERO)
			var steps2 := 16
			for i in steps2 + 1:
				var a3: float = d.angle() - arc + 2.0 * arc * float(i) / float(steps2)
				pts.append(Vector2(cos(a3), sin(a3)) * r)
		"line":
			var n := d.orthogonal() * (width * 0.5)
			pts = PackedVector2Array([-d * r - n, d * r - n, d * r + n, -d * r + n])
		"cross":
			var n2 := d.orthogonal() * (width * 0.4)
			var m := d * (width * 0.4)
			var e := d * r
			var f := d.orthogonal() * r
			pts = PackedVector2Array([
				-e - n2, -m - n2, -m - f, m - f, m - n2, e - n2,
				e + n2, m + n2, m + f, -m + f, -m + n2, -e + n2])
		_:  # square: the largest axis-aligned plot inside the circle
			var s := r * 0.72
			pts = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s),
				Vector2(s, s), Vector2(-s, s)])
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(1, 1, 1, 0.34)
	root.add_child(fill)
	var rim_w := maxf(2.0, radius * 0.04)
	if shape == "ring":
		# Two separate circles, NOT one closed polyline around the annulus: a
		# single line has to travel between the outer and inner rings and draws
		# that journey as a radial seam across the band.
		for rr: float in [r, r * 0.66]:
			var circle := Line2D.new()
			var cp := PackedVector2Array()
			for i in 31:
				var ca: float = TAU * float(i) / 30.0
				cp.append(Vector2(cos(ca), sin(ca)) * rr)
			circle.points = cp
			circle.closed = true
			circle.width = rim_w
			circle.default_color = Color(1, 1, 1, 0.9)
			circle.joint_mode = Line2D.LINE_JOINT_ROUND
			root.add_child(circle)
		return root
	var rim := Line2D.new()
	rim.points = pts
	rim.closed = true
	rim.width = rim_w
	rim.default_color = Color(1, 1, 1, 0.9)
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(rim)
	return root


var _ground_attacks: Array = []


func _new_ground_attack() -> Node2D:
	var attack := Node2D.new()
	attack.name = "GroundAttack"
	attack.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(attack)
	_ground_attacks.append(attack)
	attack.tree_exiting.connect(func() -> void: _ground_attacks.erase(attack))
	return attack


## Warning, falling art and shelter all belong to the encounter that made them.
## A chapter rebuild or wipe cancels the attack before its delayed damage lands.
func cancel_ground_attacks() -> void:
	for attack in _ground_attacks.duplicate():
		if is_instance_valid(attack):
			attack.queue_free()
	_ground_attacks.clear()
	if is_instance_valid(hud):
		hud.danger_cancel()


func _ground_clock(attack: Node2D, pos: Vector2, radius: float, delay: float,
		tint: Color, safe := false, decoy := false) -> Node2D:
	var clock := preload("res://scripts/ground_tell.gd").new()
	clock.position = pos
	clock.radius = radius
	clock.tint = tint
	clock.safe = safe
	clock.decoy = decoy
	attack.add_child(clock)
	clock.create_tween().tween_property(clock, "progress", 1.0, maxf(0.001, delay))
	return clock


func _ground_linger(attack: Node2D, duration: float) -> void:
	var tw := attack.create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(attack.queue_free)


func telegraph(pos: Vector2, radius: float, delay: float, damage: float, opts := {}) -> void:
	# Shelter wards the GROUND (player rule 2026-07-09): a danger telegraph
	# that would land inside a live shelter never forms — Varo's reliquary
	# swords were falling INTO his own Toll shadows, making the compliant
	# stand a chip-death. The dome eats the sky as well as the bullets.
	if _sheltered(pos):
		return
	var attack := _new_ground_attack()
	# MP-09: the host mirrors every tell to guests as a VISUAL-ONLY event —
	# co-op dodging needs a guest to see exactly what the host sees,
	# including tells the boss aims at THE GUEST (pick_target already
	# targets any player). One hook here rides under every call site
	# (bosses, mob traits, bloat bursts). Solo: net_host() is false.
	if net_host():
		net_session().host_telegraph(pos, radius, delay, opts)
	# SHAPE VOCABULARY (2026-09-03). Every one of the 47 boss tell sites used to
	# draw the same rimmed disc, differing only in tint and radius — the reason
	# "boss attacks all look visually similar". opts["shape"] picks the ground
	# figure; "disc" (the default) shares the same analytic fill and comet
	# clock as mob traits and bloat bursts. The accent is DECORATION drawn
	# inside the disc: the hit test below stays a plain radius check on the
	# FULL disc (see `_tell_accent`'s header). Do not "fix" it into a shaped
	# test — a cone or bar hit shape would silently shrink all 47 boss danger
	# areas, and every site was tuned against the circle.
	var tint: Color = opts.get("color", Color(1.0, 0.2, 0.15, 0.55))
	var shape := String(opts.get("shape", "disc"))
	var zone := preload("res://scripts/ground_tell.gd").make_fill(radius)
	zone.global_position = pos
	zone.modulate = tint
	zone.z_index = -6
	attack.add_child(zone)
	var clock := _ground_clock(attack, pos, radius, delay, tint)
	if shape != "disc":
		# The accent remains a SIBLING: its radius and the fill's local
		# geometry are both already expressed in world pixels.
		var accent := _tell_accent(shape, radius, opts)
		accent.global_position = pos
		accent.modulate = tint
		accent.z_index = -5   # over the disc, still under the actors
		attack.add_child(accent)
		var apulse := accent.create_tween()
		apulse.tween_property(accent, "modulate:a", tint.a, maxf(0.06, delay * 0.72)) \
			.from(tint.a * 0.20)
		apulse.tween_property(accent, "modulate:a", minf(1.0, tint.a * 1.8), 0.14)
		# Hold to the pop, then go with the disc — an accent that faded early
		# would tell the player the danger had passed.
		apulse.tween_interval(maxf(0.0, delay - maxf(0.06, delay * 0.72) - 0.14))
		apulse.tween_callback(accent.queue_free)
	# FUSE-READABLE FILL: the old loop pulsed 0.18s on/off no matter how long
	# the fuse was, so a 0.35s crack and a 2.9s verdict read identically. Ramp
	# the fill over the fuse instead (time-to-pop is now visible), then snap
	# twice at the end. One-shot and delay-bounded, so it cannot drift.
	var pulse := zone.create_tween()
	pulse.tween_property(zone, "modulate:a", tint.a, maxf(0.06, delay * 0.72)) \
		.from(tint.a * 0.34)
	pulse.tween_property(zone, "modulate:a", tint.a * 0.5, 0.09)
	pulse.tween_property(zone, "modulate:a", minf(1.0, tint.a * 1.7), 0.09)
	pulse.tween_property(zone, "modulate:a", tint.a * 0.6, 0.08)

	var falling: Sprite2D = null
	var falling_trail: CPUParticles2D = null
	var falling_key: String = String(opts.get("falling_sprite", ""))
	if falling_key.is_empty() and opts.get("fireball", false):
		falling_key = "fireball"
	elif falling_key.is_empty() and opts.get("sword", false):
		falling_key = "greatsword"
	if not falling_key.is_empty():
		falling = Sprite2D.new()
		falling.texture = Art.tex(falling_key)
		var default_scale := Balance.FALLING_FIREBALL_SCALE if falling_key == "fireball" \
			else (Balance.FALLING_LEGACY_SWORD_SCALE if falling_key == "greatsword" else 1.0)
		var falling_scale: float = float(opts.get("falling_scale", default_scale))
		falling.scale = Vector2(falling_scale, falling_scale)
		if falling_key == "fireball":
			falling.modulate = Color(1.0, 0.55, 0.2)
			# Projectile art is authored pointing right. Sky hazards fall down,
			# so rotate the comet head into its travel direction.
			falling.rotation = PI / 2.0
		falling.global_position = pos + Vector2(0, -420)
		falling.z_index = Balance.FALLING_OBJECT_Z_INDEX
		attack.add_child(falling)
		if falling_key == "fireball":
			# World-space particles remain behind as the emitter descends;
			# parenting them to the rotated sprite would turn the plume sideways.
			falling_trail = CPUParticles2D.new()
			falling_trail.amount = Balance.FALLING_FIREBALL_TRAIL_AMOUNT
			falling_trail.lifetime = Balance.FALLING_FIREBALL_TRAIL_LIFETIME
			falling_trail.local_coords = false
			falling_trail.direction = Vector2.UP
			falling_trail.spread = 18.0
			falling_trail.gravity = Vector2(0.0, -24.0)
			falling_trail.initial_velocity_min = Balance.FALLING_FIREBALL_TRAIL_SPEED.x
			falling_trail.initial_velocity_max = Balance.FALLING_FIREBALL_TRAIL_SPEED.y
			falling_trail.scale_amount_min = Balance.FALLING_FIREBALL_TRAIL_SCALE.x
			falling_trail.scale_amount_max = Balance.FALLING_FIREBALL_TRAIL_SCALE.y
			var fire_ramp := Gradient.new()
			fire_ramp.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
			fire_ramp.colors = PackedColorArray([
				Color(1.0, 0.94, 0.52, 0.95),
				Color(1.0, 0.29, 0.04, 0.72),
				Color(0.22, 0.05, 0.02, 0.0),
			])
			falling_trail.color_ramp = fire_ramp
			falling_trail.global_position = falling.global_position
			falling_trail.z_index = Balance.FALLING_OBJECT_Z_INDEX - 1
			attack.add_child(falling_trail)
			falling_trail.emitting = true
		var fall := falling.create_tween()
		var falling_end_y: float = float(opts.get("falling_end_y",
			Balance.FALLING_OBJECT_DEFAULT_END_Y))
		var falling_target := pos + Vector2(0, falling_end_y)
		fall.tween_property(falling, "global_position", falling_target, delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if falling_trail != null:
			var trail_fall := falling_trail.create_tween()
			trail_fall.tween_property(falling_trail, "global_position",
				falling_target, delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(attack) or attack.is_queued_for_deletion() or not is_instance_valid(zone):
		return
	zone.queue_free()
	clock.queue_free()
	_ground_linger(attack, maxf(Balance.FALLING_OBJECT_FADE, Balance.FALLING_FIREBALL_TRAIL_LIFETIME) + Balance.GROUND_ATTACK_EFFECT_PADDING)
	var impact_sfx := String(opts.get("impact_sfx", "slam"))
	if not impact_sfx.is_empty():
		sfx(impact_sfx)
	shake(6.0)
	burst(pos, opts.get("color", Color(1.0, 0.35, 0.2)), 18)
	if falling and is_instance_valid(falling):
		var sink := falling.create_tween()
		sink.tween_property(falling, "modulate:a", 0.0, Balance.FALLING_OBJECT_FADE)
		sink.tween_callback(falling.queue_free)
	if falling_trail and is_instance_valid(falling_trail):
		falling_trail.emitting = false
		var trail_linger := falling_trail.create_tween()
		trail_linger.tween_interval(Balance.FALLING_FIREBALL_TRAIL_LIFETIME)
		trail_linger.tween_callback(falling_trail.queue_free)
	if opts.get("net_visual", false):
		return  # MP-09: a mirror of the danger, not the danger — damage and
		        # riders stay host-side (guest hits arrive via MP-10's RPC)
	# MP-10: the eruption examines EVERY registered player (solo: the one
	# entry — checks identical to the old single read). A remote shell's
	# take_damage/riders forward to the owning peer (§4.1 damage row).
	for pl in players:
		if pl == null or not is_instance_valid(pl) or pl.dead:
			continue
		if pl.global_position.distance_to(pos) > radius + 8.0:
			continue
		if _sheltered(pl.global_position):
			# (A player standing INSIDE a live shelter is immune to the rim
			# of an overlapping tell — safe means safe, damage and riders.)
			continue
		# HEAVY: a telegraphed nuke pierces a chip-armed hurt_cd gate — a stray
		# graze must never eat the punish for standing in the circle.
		pl.take_damage(damage, "magic", null, true)
		# Riders (mob snare patch): a caught player can also be frozen/rooted.
		if opts.has("freeze"):
			pl.apply_freeze(float(opts["freeze"]))
		if opts.has("root"):
			pl.apply_root(float(opts["root"]))


## INVERSE telegraph (safe-zone): after the delay the whole arena hits
## EXCEPT the marked circle(s) — stand inside one to live. Debuted by
## Vess (ch3); reused by Varo's tolls, then Serane / Ordo / Cyrraeth
## (see BOSSES.md toolbox). opts["decoys"]: extra positions drawn like
## safe circles but FLICKERING — lies that grant no safety (the steady
## circle is the truth).
## INVERSE telegraph: the whole arena is lethal EXCEPT the given circles.
## Readability pass (2026-07-07, playtest: "I didn't see anything — I
## dodged everything I could see"): an inverse telegraph draws only the
## SAFETY, so an unseen circle used to look like a safe room for `delay`
## seconds, then a x2 hit from nowhere. Now the DANGER is shown too:
## a screen-edge dread ramp builds over the window (hud.danger_ramp), a
## SHELTER DOME (player rule 2026-07-09): while a safe-spot exam is airborne,
## its REAL shelters consume hostile projectiles at the rim — reaching the
## shelter means SAFE, not "safe from the nuke but shredded by the stray
## bolts that followed you in" (which also broke archer Second Wind mid-exam,
## turning the compliant play into chip death). Decoys never shield: a lie
## gives no shelter. Lives for the fuse + a beat, so the resolving wave's
## in-flight stragglers die at the rim too.
class SafeDome extends Node2D:
	var centers: Array = []
	var dome_radius := 100.0
	var life := 2.5
	var tint := Color(0.5, 1.0, 0.7)
	var game_ref: Node2D = null

	func _ready() -> void:
		add_to_group("safe_domes")

	## Is a world position inside one of this dome's shelters?
	func shelters(pos: Vector2) -> bool:
		for c in centers:
			if pos.distance_to(c) <= dome_radius:
				return true
		return false

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		for node in get_tree().get_nodes_in_group("projectiles"):
			var p := node as Projectile
			if p == null or p.friendly:
				continue
			for c in centers:
				if p.global_position.distance_to(c) <= dome_radius:
					if game_ref:
						game_ref.burst(p.global_position, tint, 4)
					p.queue_free()
					break


## light BEACON rises from every circle so it reads over scenery clutter
## and from off-screen edges, and callers can pass a player-anchored
## "callout" + a rising "sfx" whose swell IS the audible timer.
## Shared by every safe-spot fight (Vess / Varo / Serane / Cyrraeth).
func telegraph_safe(centers: Array, radius: float, delay: float, damage: float, opts := {}) -> void:
	var attack := _new_ground_attack()
	# MP-09: mirror the safe-spot exam to guests — circles, beacons, decoys
	# and the dread ramp all render there (visual-only; the wail's damage
	# stays host business until MP-10). Same hook shape as telegraph().
	if net_host():
		net_session().host_telegraph_safe(centers, radius, delay, opts)
	if opts.has("callout") and is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -84), String(opts["callout"]),
			opts.get("color", Color(0.5, 1.0, 0.7)))
	if opts.has("sfx"):
		sfx(String(opts["sfx"]))
	if is_instance_valid(hud):
		hud.danger_ramp(delay)
	var zones: Array = []
	for c in centers:
		var zone := preload("res://scripts/ground_tell.gd").make_fill(radius)
		zone.global_position = c
		zone.modulate = opts.get("color", Color(0.5, 1.0, 0.7, 0.5))
		zone.z_index = -6
		attack.add_child(zone)
		zones.append(zone)
		zones.append(_ground_clock(attack, c, radius, delay, opts.get("color", Color(0.5, 1.0, 0.7)), true))
		var pulse := zone.create_tween()
		pulse.set_loops()
		pulse.tween_property(zone, "modulate:a", 0.75, 0.22)
		pulse.tween_property(zone, "modulate:a", 0.4, 0.22)
		var beacon := _safe_beacon(c, opts.get("color", Color(0.5, 1.0, 0.7)), false)
		beacon.reparent(attack)
		zones.append(beacon)
	# The dome shields only the REAL centers, for the fuse + a linger beat.
	var dome := SafeDome.new()
	dome.centers = centers.duplicate()
	dome.dome_radius = radius
	dome.life = delay + Balance.SAFE_SHELTER_LINGER
	dome.tint = opts.get("color", Color(0.5, 1.0, 0.7))
	dome.game_ref = self
	attack.add_child(dome)
	var decoys: Array = opts.get("decoys", [])
	for c in decoys:
		var lie := preload("res://scripts/ground_tell.gd").make_fill(radius)
		lie.global_position = c
		lie.modulate = opts.get("color", Color(0.5, 1.0, 0.7, 0.5))
		lie.z_index = -6
		attack.add_child(lie)
		zones.append(lie)
		zones.append(_ground_clock(attack, c, radius, delay, opts.get("color", Color(0.5, 1.0, 0.7)), true, true))
		var flicker := lie.create_tween()
		flicker.set_loops()
		flicker.tween_property(lie, "modulate:a", 0.15, 0.07)
		flicker.tween_property(lie, "modulate:a", 0.7, 0.09)
		# The decoy's beacon flickers with the same lie — the tell stays
		# consistent across both reads (circle AND pillar).
		var beacon := _safe_beacon(c, opts.get("color", Color(0.5, 1.0, 0.7)), true)
		beacon.reparent(attack)
		zones.append(beacon)

	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(attack) or attack.is_queued_for_deletion():
		return
	_ground_linger(attack, Balance.SAFE_SHELTER_LINGER)
	var any_alive := false
	for zone in zones:
		if is_instance_valid(zone):
			any_alive = true
			zone.queue_free()
	if not any_alive:
		if is_instance_valid(hud):
			hud.danger_end(true)
		return
	var impact_sfx := String(opts.get("impact_sfx", "slam"))
	if not impact_sfx.is_empty():
		sfx(impact_sfx)
	shake(9.0)
	# The LOCAL player's verdict drives THIS machine's HUD dread ramp and
	# shelter burst — exactly the old single-player reads.
	var sheltered := true
	if is_instance_valid(player) and not player.dead:
		sheltered = _safe_at(centers, radius, player.global_position)
	if is_instance_valid(hud):
		hud.danger_end(sheltered)
	if sheltered and is_instance_valid(player) and not player.dead:
		burst(player.global_position, Color(0.6, 1.0, 0.75), 12)  # sheltered
	if opts.get("net_visual", false):
		return  # MP-09: visual-only mirror — caught-in-the-open damage,
		        # freeze and root resolve on the host (MP-10's player-damage
		        # seam carries a caught guest's share to its owner)
	# MP-10: the wail examines EVERY registered player (solo: the one
	# entry — same checks as the old single read). Shells forward (§4.1).
	for pl in players:
		if pl == null or not is_instance_valid(pl) or pl.dead:
			continue
		if _safe_at(centers, radius, pl.global_position):
			continue
		burst(pl.global_position, Color(1.0, 0.35, 0.2), 18)
		# HEAVY: the arena-wide blast pierces a chip-armed hurt_cd gate (the
		# known cheese: tank a graze right before Vess's wail, eat it free).
		pl.take_damage(damage, "magic", null, true)
		# Some inverse telegraphs don't just hurt — they FREEZE or ROOT the
		# player caught in the open (Serane's Flash Freeze, ch5+).
		if opts.has("freeze"):
			pl.apply_freeze(float(opts["freeze"]))
		if opts.has("root"):
			pl.apply_root(float(opts["root"]))


## Inside any of a safe-spot exam's true shelters? (Same +8 px rim grace
## as the old inline check.)
func _safe_at(centers: Array, radius: float, pos: Vector2) -> bool:
	for c in centers:
		if pos.distance_to(c) <= radius + 8.0:
			return true
	return false


## A soft light pillar rising from a safe circle: readable over ground
## clutter and from screen edges where a flat disc vanishes. HDR so it
## blooms; the decoy's pillar flickers with its lie.
func _safe_beacon(pos: Vector2, tint: Color, flicker: bool) -> Sprite2D:
	var beam := Sprite2D.new()
	beam.texture = Art.tex("lootbeam")
	beam.centered = false
	beam.z_index = 5
	beam.scale = Vector2(1.1, 1.35)
	beam.position = pos - Vector2(16.0 * beam.scale.x, 180.0 * beam.scale.y)
	beam.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	add_child(beam)
	var tw := beam.create_tween()
	if flicker:
		tw.set_loops()
		tw.tween_property(beam, "modulate:a", 0.2, 0.07)
		tw.tween_property(beam, "modulate:a", 0.8, 0.09)
	else:
		tw.tween_property(beam, "modulate:a", 0.85, 0.25)
	return beam

# Idle-chatter symbols by resonance band (round 8): the steady get
# hearts and song, the tempted get sidelong wariness — the world reads
# the shard before anyone says a word.
const IDLE_EMOTES := {
	"steady": ["♥", "♪", "♥", "…"],
	"tempted": ["…", "?", "!", "…"],
	"neutral": ["♪", "…", "?", "♥"],
}


## The symbol an idling NPC floats at the player, per the current band.
func idle_emote_symbol() -> String:
	var pool: Array = IDLE_EMOTES.get(String(Story.res_band(player.resonance)), IDLE_EMOTES["neutral"])
	return pool[randi() % pool.size()]


## Floating emote bubble above a character ("!", "♪", "…", "?").
var _alert_emote_ms := 0  # throttle timestamp for the enemy "!" alert bubble


## Throttled enemy "!" alert bubble (visual-review P1): when several enemies
## gain sight of the player in the same instant, one "!" says "danger" and the
## rest are visual noise stacked over the pack. Show at most one every
## Balance.ALERT_EMOTE_GAP seconds; suppressed mobs still alert and aggro, they
## just skip the redundant bubble.
func alert_emote(target: Node2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _alert_emote_ms < int(Balance.ALERT_EMOTE_GAP * 1000.0):
		return
	_alert_emote_ms = now
	emote(target, "!", 0.9)


func emote(target: Node2D, symbol: String, dur := 1.4) -> void:
	if not is_instance_valid(target):
		return
	var box := Node2D.new()
	box.position = Vector2(10, -46)
	box.z_index = 30
	var spr := Sprite2D.new()
	spr.texture = Art.tex("bubble")
	spr.scale = Vector2(0.8, 0.8)  # 42x39 source; same footprint as the old 14x13 art.
	box.add_child(spr)
	var l := Label.new()
	l.text = symbol
	# Centered on the BALLOON part of the bubble art (rows 0-9 of 13;
	# the tail hangs below) — glyphs used to ride the top edge, clipped.
	l.position = Vector2(-14, -16)
	l.size = Vector2(28, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.08, 0.06, 0.1))
	box.add_child(l)
	target.add_child(box)
	box.scale = Vector2(0.3, 0.3)
	var tween := box.create_tween()
	tween.tween_property(box, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(dur)
	tween.tween_property(box, "modulate:a", 0.0, 0.25)
	tween.tween_callback(box.queue_free)


var ambient_above := true

## Quick burst of particles (deaths, blinks, chest opens, meteors...).
func burst(pos: Vector2, color: Color, count := 10) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	# Soft chips instead of the engine's default 1px squares scaled 2-4x (P1):
	# the same footprint (12px chip x 0.2-0.4 = 2.5-5px), no more hard squares.
	p.texture = Art.tex("spark")
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.42
	p.color = color
	p.z_index = 15
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# World-space event text must survive the darkest ground (art audit
# 2026-07-10: Ordo's translucent VERDICT orange rendered "The sermon
# begins." as illegible near-black mush on keep brown). Every caller
# benefits: fills below this luminance get lifted toward a readable
# version of THEMSELVES — hue kept, value floored, never neon.
const TEXT_LUM_FLOOR := 0.45
# Saturated hues clip before reaching the floor (pure red tops out at
# 0.21) — the remainder of the climb leans toward warm parchment.
const TEXT_LIFT_PARCHMENT := Color(0.94, 0.87, 0.70)


## Legibility floor for spawn_text fills: opaque alpha (translucent fill
## over the opaque black outline reads as burnt-dark text) + a luminance
## floor that keeps the caller's hue.
func _floor_text_color(color: Color) -> Color:
	var c := Color(color.r, color.g, color.b, 1.0)
	var lum: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	if lum >= TEXT_LUM_FLOOR:
		return c
	# Scale the channels first — an exact hue-preserving lift.
	if lum > 0.001:
		var k: float = TEXT_LUM_FLOOR / lum
		c = Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0)
	else:
		c = Color(TEXT_LUM_FLOOR, TEXT_LUM_FLOOR, TEXT_LUM_FLOOR, 1.0)
	# Channel clipping can leave saturated hues short of the floor —
	# finish the climb toward parchment, keeping the color's lean.
	var got: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	if got < TEXT_LUM_FLOOR:
		var parch_lum: float = 0.2126 * TEXT_LIFT_PARCHMENT.r \
			+ 0.7152 * TEXT_LIFT_PARCHMENT.g + 0.0722 * TEXT_LIFT_PARCHMENT.b
		c = c.lerp(TEXT_LIFT_PARCHMENT, (TEXT_LUM_FLOOR - got) / maxf(0.05, parch_lum - got))
		c.a = 1.0
	return c


# Floating-text presentation (gameplay-polish 2026-08-18; presentation
# constants, not tuning). Outside readers called the old numbers "beta": the
# engine-default face at 15px, every hit the same size, all spawning on one
# point so a flurry stacked into a grey pile ("14 15 15 16 20! 22!"). Now:
# the world face (UITheme.world), a scale-pop on spawn, an eased rise with a
# small sideways lean so consecutive hits fan out, a fade over the last part
# of the rise, and crits a size up. Words (status callouts, telegraph lines)
# keep the calmer straight rise so they stay readable.
const FLOAT_NUM_SIZE := 21          # a hit number ("47")
const FLOAT_NUM_SIZE_CRIT := 27     # a crit ("128!")
const FLOAT_LABEL_SIZE := 16        # a short callout ("WARD SHATTERED!")
const FLOAT_LABEL_SIZE_LONG := 14   # a telegraph line ("FLASH FREEZE — FIND A VENT!")
const FLOAT_NUM_SPREAD := 16.0      # ± px sideways lean per number
const FLOAT_NUM_RISE := 46.0
const FLOAT_NUM_LIFE := 0.85
# Density cap (visual-review P1): at max pack size a burst of hits can bury the
# enemies under numbers. Keep at most this many floating numbers alive at once —
# high enough that normal fights never notice, low enough to stay legible in an
# AoE storm. Only bites past ~this-many hits inside one FLOAT_NUM_LIFE window.
const FLOAT_NUM_MAX := 22
var _float_nums: Array = []          # live floating-number labels, oldest first
var _float_rng := RandomNumberGenerator.new()   # its own stream: never perturbs game RNG


## 0 = words, 1 = a number ("47", "+12", "-9"), 2 = a crit ("128!", "-40 CRIT!").
func _float_kind(text: String) -> int:
	var t := text.strip_edges()
	var crit := t.ends_with("!")
	if crit:
		t = t.trim_suffix("!").trim_suffix(" CRIT").strip_edges()
	if t.begins_with("+") or t.begins_with("-"):
		t = t.substr(1)
	if t.is_valid_int():
		return 2 if crit else 1
	return 0


## hold: seconds the text sits still before the float-and-fade (the
## fight report needs reading time; combat numbers leave it at 0).
## Retire a floating number: drop it from the live list and free it. Bound as
## a number's tween-end callback so the density-cap list never keeps stale refs.
func _retire_float_num(l: Node) -> void:
	_float_nums.erase(l)
	if is_instance_valid(l):
		l.queue_free()


func spawn_text(pos: Vector2, text: String, color: Color, hold := 0.0) -> void:
	var kind := _float_kind(text)
	# P7.A (2026-08-19): a line that asked for READING time is an announcement
	# (discovery, unlock, victory, quest) — it gets the HUD plaque + the event
	# log instead of a flat world label. Numbers, crits and quick callouts keep
	# floating at their world point; pickups float AND log.
	if kind == 0 and hud != null and is_instance_valid(hud):
		if hold > 0.0:
			hud.announce(text, color, hold)
			return
		if text.begins_with("+"):   # "+ Rusted Dagger", "+12 XP", "+ Bag"
			hud.log_event(text, color)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsize := FLOAT_LABEL_SIZE
	var outline := 4
	if kind == 2:
		fsize = FLOAT_NUM_SIZE_CRIT
		outline = 5
	elif kind == 1:
		fsize = FLOAT_NUM_SIZE
		outline = 5
	elif text.length() > 18:
		fsize = FLOAT_LABEL_SIZE_LONG
	UITheme.world(l, fsize, outline)
	l.add_theme_color_override("font_color", _floor_text_color(color))
	# Size the rect to the STRING (font metrics are available off-tree once
	# the overrides are set) so the centring and the pop pivot are exact — a
	# fixed 140px box mis-centred long telegraph lines and clamped short ones.
	var font: Font = l.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var ssz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	l.size = Vector2(ssz.x + outline * 2.0 + 6.0, ssz.y + 6.0)
	var lean := 0.0
	if kind > 0:
		lean = _float_rng.randf_range(-FLOAT_NUM_SPREAD, FLOAT_NUM_SPREAD)
	l.position = pos + Vector2(-l.size.x * 0.5 + lean, -l.size.y * 0.5)
	l.pivot_offset = l.size * 0.5
	add_child(l)
	if kind > 0:
		# Density cap (visual-review P1): retire the oldest number so a burst of
		# hits stays legible instead of burying the pack under digits.
		_float_nums.append(l)
		while _float_nums.size() > FLOAT_NUM_MAX:
			var oldest: Node = _float_nums.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
	var tween := l.create_tween()   # label-bound: dies cleanly if retired early
	if kind > 0:
		l.scale = Vector2(1.5, 1.5) if kind == 2 else Vector2(1.28, 1.28)
		tween.tween_property(l, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var rise := FLOAT_NUM_RISE * (1.2 if kind == 2 else 1.0)
		var to := l.position + Vector2(lean * 0.6, -rise)
		tween.parallel().tween_property(l, "position", to, FLOAT_NUM_LIFE) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(l, "modulate:a", 0.0, FLOAT_NUM_LIFE * 0.45) \
			.set_delay(FLOAT_NUM_LIFE * 0.55)
	else:
		if hold > 0.0:
			tween.tween_interval(hold)
		tween.tween_property(l, "position:y", l.position.y - 34.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	if kind > 0:
		tween.tween_callback(_retire_float_num.bind(l))
	else:
		tween.tween_callback(l.queue_free)


## FOOT DUST (life pass 2026-08-19): a tiny puff of floor-coloured dust at a
## running foot — a few soft chips that drift up and fade. Tinted from the
## current room's ground palette so it is sand on sand, loam on grass, ash on
## magma. Cheap one-shot particles; callers throttle by FOOT_DUST_PERIOD.
func foot_dust(pos: Vector2) -> void:
	if Balance.FOOT_DUST_N <= 0:
		return
	var col := Color(0.55, 0.5, 0.42)
	var zi := room_at_pos(pos)
	if zi >= 0 and zi < zone_count:
		var gk := String(Terrains.get_terrain(terrain_by_zone[zi]).get("ground", ""))
		if Art.GROUND.has(gk):
			var gc: Color = Art.GROUND[gk][1]
			col = gc.lightened(0.25)
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = Balance.FOOT_DUST_N
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	p.texture = Art.tex("glow")
	p.color = Color(col.r, col.g, col.b, Balance.FOOT_DUST_A)
	p.z_index = 3
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## CAST SHADOW for a LIVING body (owner flag 2026-08-19: "npcs / characters /
## mobs / bosses should also cast a shadow — the circle under the feet is
## lazy"). A Sprite2D that MIRRORS its source sprite every frame (texture,
## strip cell, frame, flip, offset, scale, alpha) and draws it flipped,
## sheared toward the lower-right and squashed flat, anchored on the source's
## feet line — the same light as the props' cast shadows (CAST_SHADOW_*). The
## contact ellipse stays (it grounds the feet); this adds the figure.
class CastShadow extends Sprite2D:
	var src: Sprite2D = null
	var alpha := 0.3
	var strength := 1.0   # per-body multiplier (bosses / big bodies tone it down)
	# frame-0 alpha bottom per texture (px from the cell top). The FRAME bottom
	# is the wrong feet line: hero/NPC cells carry padding below the boots, and
	# that padding became a visible GAP between body and shadow (owner flag
	# 2026-08-19: "the archer looks like it's floating", "the elder woman's
	# shadow is way detached").
	static var _feet_cache := {}

	func _ready() -> void:
		centered = true
		z_index = -1
		set_meta("cast_shadow", true)
		set_process(true)
		_sync()

	func _process(_dt: float) -> void:
		_sync()

	static func _art_feet(tex: Texture2D, hf: int, vf: int) -> float:
		var key: int = tex.get_rid().get_id()
		if _feet_cache.has(key):
			return _feet_cache[key]
		var ch: int = tex.get_height() / maxi(1, vf)
		var bot := float(ch)
		var img: Image = tex.get_image()
		if img != null:
			var cw: int = img.get_width() / maxi(1, hf)
			var used: Rect2i = img.get_region(Rect2i(0, 0, cw, ch)).get_used_rect()
			if used.size.y > 0:
				bot = float(used.end.y)
		_feet_cache[key] = bot
		return bot

	func _sync() -> void:
		if src == null or not is_instance_valid(src) or src.texture == null:
			visible = false
			return
		visible = src.visible
		if not visible:
			return
		texture = src.texture
		hframes = src.hframes
		vframes = src.vframes
		frame = mini(src.frame, maxi(0, hframes * vframes - 1))
		flip_h = src.flip_h
		flip_v = src.flip_v
		offset = src.offset
		centered = src.centered
		rotation = src.rotation
		var k: float = Balance.CAST_SHADOW_SKEW
		skew = -k
		var sy: float = absf(src.scale.y) * Balance.CAST_SHADOW_SQUASH
		scale = Vector2(src.scale.x, -sy)
		var cell_h: float = float(src.texture.get_height()) / float(maxi(1, src.vframes))
		# e = the art's FEET row in the sprite's local space (offset included):
		# the flipped copy is placed so that row lands exactly on the source's
		# feet, and projects away from there — no gap, no overlap.
		var bot: float = _art_feet(src.texture, src.hframes, src.vframes)
		var e: float = bot - (cell_h * 0.5 if src.centered else 0.0) + src.offset.y
		var feet_y: float = src.position.y + e * absf(src.scale.y)
		position = Vector2(src.position.x, feet_y) + Vector2(e * sy * sin(k), e * sy * cos(k))
		modulate = Color(0, 0, 0, alpha * strength * src.modulate.a * src.self_modulate.a)
		# never the source's material: the hero's occlusion-outline / a skin's
		# hue shader would draw on the shadow (the shadow is the silhouette only)


## Attach a CastShadow that follows `src` (a child of the same parent as src,
## drawn under it). Returns null when cast shadows are off or headless.
func cast_shadow_for(parent: Node, src: Sprite2D, strength := 1.0) -> Node2D:
	if Balance.CAST_SHADOW_A <= 0.0 or src == null:
		return null
	var cs := CastShadow.new()
	cs.src = src
	cs.alpha = Balance.CAST_SHADOW_A
	cs.strength = strength
	parent.add_child(cs)
	# under the source sprite: move right before it in the sibling order too,
	# so two z 0 sprites never race on draw order
	var idx := src.get_index()
	if cs.get_parent() == src.get_parent() and idx > 0:
		parent.move_child(cs, idx)
	return cs


## REMAINS STAIN (life pass 2026-08-19): a kill leaves a soft dark blotch on
## the floor in the creature's own palette that fades over DEATH_STAIN_LIFE —
## the room remembers the fight for a while instead of every body poofing
## away clean. Two soft stamps (a body and a smaller splash offset along the
## hit line), z just above the floor wear, below every actor; never in
## headless runs; capped so a long grind cannot pile up sprites.
var _stain_roots: Array[Node2D] = []

func death_stain(pos: Vector2, color: Color, dir: Vector2 = Vector2.ZERO) -> void:
	if Balance.DEATH_STAIN_A <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var tex: Texture2D = Art.tex("softshadow")
	if tex == null:
		return
	var tint := color.darkened(0.55)
	tint.a = Balance.DEATH_STAIN_A
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 7.0 + pos.y * 13.0)
	var root := Node2D.new()
	root.position = pos
	root.z_index = -8
	root.z_as_relative = false
	for k in 2:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = tint if k == 0 else Color(tint.r, tint.g, tint.b, tint.a * 0.7)
		var w: float = rng.randf_range(26.0, 38.0) if k == 0 else rng.randf_range(12.0, 18.0)
		var ts := tex.get_size()
		s.scale = Vector2(w / maxf(1.0, ts.x), (w * rng.randf_range(0.55, 0.8)) / maxf(1.0, ts.y))
		s.rotation = rng.randf_range(-0.5, 0.5)
		if k == 1:
			var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
			s.position = d * rng.randf_range(14.0, 24.0)
		root.add_child(s)
	add_child(root)
	_stain_roots.append(root)
	while _stain_roots.size() > Balance.DEATH_STAIN_MAX:
		var old: Node2D = _stain_roots.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := root.create_tween()
	tw.tween_interval(Balance.DEATH_STAIN_LIFE * 0.6)
	tw.tween_property(root, "modulate:a", 0.0, Balance.DEATH_STAIN_LIFE * 0.4)
	tw.tween_callback(func() -> void:
		_stain_roots.erase(root)
		if is_instance_valid(root):
			root.queue_free())


## Wave-2 co-op fix #8: a floating banner shown on EVERY machine, not just the
## caller's. Boss readability callouts — enrage, intercept orders, verdicts,
## warn tells — are host-simulated on a guest, so a plain spawn_text stays home;
## this renders locally AND (when hosting) fans the same text to every guest at
## the same world point. Solo/offline is exactly spawn_text (net_host() false).
func spawn_text_all(pos: Vector2, text: String, color: Color, hold := 0.0) -> void:
	spawn_text(pos, text, color, hold)
	if net_host():
		net_session().host_spawn_text(pos, text, color, hold)


## MP-14 (§5.6): an ALLY's hit number — deliberately smaller and dimmer than
## your own (spawn_text), so a friend fighting beside you reads as background
## chatter and your own big numbers stay legible. Fanned by the host to the
## non-attacking party members (net_session.host_fan_damage). World-space, like
## spawn_text, so it rises off the enemy it landed on.
func spawn_ally_damage(pos: Vector2, amount: int, crit: bool) -> void:
	var l := Label.new()
	l.text = "%d!" % amount if crit else str(amount)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 19  # under your own numbers (z 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.world(l, 14, 3)   # same face as your own numbers, two sizes down
	# A cool, dim tint marks it as someone else's damage; crits warm slightly.
	var col := Color(1.0, 0.72, 0.45, 0.8) if crit else Color(0.78, 0.86, 0.95, 0.72)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	var lean := _float_rng.randf_range(-FLOAT_NUM_SPREAD * 0.6, FLOAT_NUM_SPREAD * 0.6)
	l.size = Vector2(100, 20)
	l.position = pos + Vector2(-50 + lean, -8)
	add_child(l)
	var tween := create_tween()
	tween.tween_property(l, "position:y", l.position.y - 26.0, 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.75)
	tween.tween_callback(l.queue_free)


# =================================================================== per-frame


## A guardian's recorded identity belongs to this encounter, not its reused kit.
## Callers must apply their own charted-room check before revealing this name.
func _boss_room_name(zi: int) -> String:
	if zi < 0 or zi >= zones.size():
		return ""
	var zone: Dictionary = zones[zi]
	var kind := String(zone.get("boss", ""))
	if kind == "":
		return ""
	var base_name := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind.capitalize()))
	var pocket := String(zone.get("pocket", ""))
	if pocket != "":
		return String(Pockets.entry(pocket).get("name", base_name))
	var unlisted := String(zone.get("unlisted", ""))
	if unlisted != "":
		return String(Unlisted.entry(unlisted).get("name", base_name))
	if String(zone.get("waking", "")) != "":
		return "Waking echo · " + base_name
	return base_name


## Named encounters own completion independently from their reused boss kit.
func _boss_room_resolved(zi: int) -> bool:
	if zi < 0 or zi >= zones.size():
		return false
	var zone: Dictionary = zones[zi]
	var kind := String(zone.get("boss", ""))
	if String(zone.get("pocket", "")) != "":
		return pocket_done
	if String(zone.get("unlisted", "")) != "":
		return unlisted_banked_has(String(zone["unlisted"]))
	if String(zone.get("waking", "")) != "":
		return waking_banked(kind)
	return kind != "" and bool(boss_done.get(kind, false))


## Legacy pocket cells lived at (9000,9000): migrate saved hero/drop positions
## when loading that old layout into the nearby floating cell.
func pocket_position_legacy(at: Vector2) -> Vector2:
	if pocket_room < 0 or pocket_room >= rooms.size():
		return at
	var old := Vector2(9000.0 * ROOM_W, 9000.0 * ROOM_H)
	if Rect2(old, Vector2(ROOM_W, ROOM_H)).has_point(at):
		return rooms[pocket_room]["origin"] + at - old
	return at
