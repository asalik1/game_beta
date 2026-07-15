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
	if not touch_mode:
		return s
	s = s.replace(" and press E", " and tap them")
	s = s.replace("press E", "tap")
	s = s.replace("press Q", "tap the potion button")
	s = s.replace("Press Q", "Tap the potion button")
	s = s.replace("press Space", "tap")
	s = s.replace("Press Space", "Tap")
	s = s.replace("E — ", "")   # NPC over-head prompts: "E — Talk" -> "Talk"
	return s
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}

# ------------------------------------------------------------- chapters ---
# The world is data: Story.CHAPTER_LIST[chapter_id] decides the rooms,
# starting quest and final boss. switch_chapter() rebuilds everything.
var chapter_id := "ch1"
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
var camera: Camera2D
var ambient: CanvasModulate
var glow_env: WorldEnvironment
var reticle: Sprite2D
var reticle_label: Label

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
var interactables: Array = []    # [{node, prompt, action}]
var gates := {}                  # edge key "a_b" -> gate Node2D (locked edges only)
var zone_alive := {}             # room index -> monsters still alive
var boss_spawned := {}
var boss_done := {}
var bosses: Array = []           # every LIVE boss (endgame: up to 5 at once)
var current_boss: Boss = null    # the DISPLAYED boss: your target, else bosses[0]
var shop_stock := {}             # room index -> Array of items for sale
var shop_bags := {}              # room index -> Array of bags for sale (round 52)

# Endgame modes (ACT2_DESIGN.md §II): the controller runs The Crucible / Waking
# Depths in one arena world. `endgame_active` fences campaign autosave off the
# arena chapter (rewards bank home via write_character_home only — see autosave)
# and lets the death flow settle the run instead of respawning (game_flow).
var endgame: Endgame = null
var endgame_active := false

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

var shake_amt := 0.0
var sounds: Dictionary = {}
var sound_pool: Array = []
var loot_rng := RandomNumberGenerator.new()
var ambient_fx: CPUParticles2D = null
var npc_emote_t := 4.0
# Battle seals: while the current room is HOT (an aggroed pack or a live
# boss), every door of the room closes — no retreating mid-combat.
var door_seals: Array = []            # 4 pooled StaticBody2D, one per direction
var barrier_active := false

# ------------------------------------------------------ terrain system ---
var terrain_by_zone: Array = []       # terrain id per room
var zone_grounds := {}                # room idx -> ground Sprite2D (repaintable)
var zone_road_marks := {}             # room idx -> worn-road overlay Sprite2Ds (see _mark_roads)
var zone_scenery := {}                # room idx -> decor + obstacle nodes
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
var settings := {"music": 1.0, "sfx": 1.0, "fullscreen": false, "lang": "en", "touch_controls": false}  # user://settings.json
var music_gain_db := -16.0            # base+tune of the current track
var flags := {}                       # persistent story flags (saved)
var merchant_zones: Array = []        # rooms with a merchant present (saved)
var wander_seed := 0                  # per-character roll for seeded rooms (saved)
var cutscene: Cutscene = null         # active opening cinematic (if any)

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

# --- weekly vault (great-vault style; persisted) ---
var vault_week := -1           # trusted-clock week the current progress belongs to
var vault_progress := 0        # boss kills this week
var vault_claimed_week := -1   # week the vault was last claimed

# --- chapter run stats (results card; persisted mid-run, reset per run) ---
var run_time := 0.0            # seconds in ST_PLAYING this chapter run
var run_deaths := 0
var run_elites := 0            # elite kills this run
var run_secrets := 0           # caches unearthed this run

# --- weekly challenge (persisted) ---
var weekly_active := false     # the CURRENT run is this week's challenge
var weekly_week := -1          # week the active run belongs to
var weekly_claimed_week := -1  # week the completion reward was last paid

# --- codex completion + titles (persisted) ---
var kill_counts := {}          # enemy kind -> lifetime kills (this character)
var player_title := ""         # equipped title id ("" = none)

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
			players.remove_at(i)
			q.queue_free()
	_refresh_active_rooms()


## Recompute the sim gate (§4.3). Starts from cur_room — the local
## player's room by definition — so solo it is exactly {cur_room} and
## enemy.gd's freeze rule keeps its old behavior to the frame. Remote
## players' rooms union in on top; -1 (outside the graph) never counts.
func _refresh_active_rooms() -> void:
	active_rooms.clear()
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
	if on and net_online() and state != ST_VICTORY:
		return
	get_tree().paused = on


## The best gear grade this chapter can drop (act gating, DESIGN.md):
## The best grade a GENERAL faucet (chest/shop/gamble/spoils) can yield this
## chapter — the ceiling of the chapter's general band table (2026-07-09).
## Display/gating probes only; the drop channels roll the band directly
## (the gamble prices itself off the BOSS band now — see gamble_cost).
func loot_cap() -> String:
	return Balance.chapter_gear_ceiling(chapter_id)

## (T7) Merchants read the shard: the steady get kinder prices, the
## tempted make the till nervous. Surfaced, never explained in numbers.
func band_price_mult() -> float:
	match Story.res_band(player.resonance):
		"steady": return 0.9
		"tempted": return 1.1
	return 1.0


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
	var won := Items.roll_gear_of_grade(grade, rng, player.cls)
	player.add_item(won)
	return won

## Write the current character to its slot. Called on story progress,
## zone changes, menu closes and window close — never mid-death.
## Guesting in another world (MP-08, §5.7): only the character block
## travels home — the host's world must never colonize the guest's save.
func autosave() -> void:
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


## The reward dict for a given streak position (cycles every 7 days).
func daily_reward_for(streak: int) -> Dictionary:
	return Balance.DAILY_REWARDS[(maxi(streak, 1) - 1) % Balance.DAILY_REWARDS.size()]


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
		player.potions = mini(player.potions + pc, Balance.POTION_MAX)
		lines.append("%d potion%s" % [pc, "" if pc == 1 else "s"])
	if r.has("gems"):
		var gc := int(r["gems"])
		var lvl := int(r.get("gem_lvl", 1))
		for i in gc:
			give_loot({"kind": "gem", "gem": drop_gem(lvl)},
				player.global_position + Vector2(-30.0 + 30.0 * i, 40.0))
		lines.append("%d Lv%d gem%s" % [gc, lvl, "" if gc == 1 else "s"])
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
	return {"time": run_time, "deaths": run_deaths, "elites": run_elites,
		"secrets": run_secrets, "explored": explored, "rooms": zone_count,
		"grade": grade}


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
			"gems": int(t.get("gems", 0)), "gem_lvl": int(t.get("gem_lvl", 1)), "done": false})


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
	var g := int(float(b["gold"]) * Balance.daily_gold_mult(player.level))
	player.gold += g
	var extra := ""
	for i in int(b["gems"]):
		give_loot({"kind": "gem", "gem": drop_gem(int(b["gem_lvl"]))},
			player.global_position + Vector2(-30.0 + 30.0 * i, 40.0))
		extra = " + gem"
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -78),
		"BOUNTY: %s  (+%d gold%s)" % [b["desc"], g, extra], Color(0.6, 1.0, 0.6), 4.0)


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
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -70), "WEEKLY VAULT CLAIMED!", Color(1.0, 0.85, 0.4), 4.0)
	autosave()
	return ["a golden chest", "a bright gem"]


# ----------------------------------------------------------- account stash ---

## Load the account-wide stash once per session (from user://stash.json).
## It's shared across every character, so it lives outside the per-slot save.
func ensure_stash_loaded() -> void:
	if _stash_loaded:
		return
	_stash_loaded = true
	if no_saves or not FileAccess.file_exists(STASH_PATH):
		return
	var f := FileAccess.open(STASH_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		for pl in data:
			SaveGame._fix_payload(pl)
			stash.append(pl)


func save_stash() -> void:
	if no_saves:
		return  # tests never touch the real account file
	var f := FileAccess.open(STASH_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(stash))


## Move a bag payload INTO the stash. False = stash full.
func stash_deposit(payload: Dictionary) -> bool:
	if stash.size() >= Balance.STASH_SLOTS:
		return false
	stash.append(payload)
	save_stash()
	return true


## Move a stashed payload back into the bag. False = bag full (stays put).
func stash_withdraw(payload: Dictionary) -> bool:
	if not _try_receive(payload):
		return false
	stash.erase(payload)
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
	spawn_text(pos + Vector2(0, -44), "Bag full! Dropped", Color(1, 0.9, 0.4))
	return false


## A loot gem rolled for the CURRENT chapter: ch1-3 exclude the special
## off-build stats (Balance.special_gems_drop), ch4+ may roll them. Every
## in-world gem DROP routes through here so the early-game rule holds in one
## place; shop stock and dev tools roll specials directly.
func drop_gem(lvl: int) -> Dictionary:
	return Items.random_gem(loot_rng, lvl, Balance.special_gems_drop(chapter_id))


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
	return false


## Chapter end (victory, replay, advance): whatever still lies on the
## ground mails itself — subject "Dropped Loot", no body. Idempotent.
func flush_dropped_loot() -> void:
	if dropped_loot.is_empty():
		return
	var items := dropped_loot.duplicate()
	for pl in items:
		pl.erase("pos")
	dropped_loot = []
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		node.queue_free()
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
	# Flag-locked gates: any built gate whose flag just got set unlocks.
	# (Dynamic call: gates live a layer up in game_world.gd — the ONE
	# deliberate upward call in the chain.)
	if value:
		call("_recheck_gates")
		_check_side_quests()
	# An S-weapon awakening evolves a mythic skin to its awakened form (Phantom
	# blue -> teal Nightfang). Refresh the sprite on ANY change of the owning
	# class's awakening flag so it flips the instant the class awakens — and
	# reverts cleanly if a dev toggle clears it. Covers the quest, the dev-panel
	# toggle, and any other path. Only the owning class reacts.
	if player != null and flag_name == "s_awakened_" + String(player.cls):
		player.refresh_skin_sprite()
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
		sfx("levelup")
		spawn_text(player.global_position + Vector2(0, -70),
			"SIDE QUEST COMPLETE — %s%s" % [String(q["name"]),
				"  (+%d gold)" % gold if gold > 0 else ""],
			Color(1.0, 0.85, 0.35), 4.0)

func get_flag(flag_name: String, def = false):
	return flags.get(flag_name, def)

func run_convo_id(id: String, on_done := Callable()) -> void:
	var convo: Dictionary = Story.ALL_CONVOS[id]
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

func run_convo(convo: Dictionary, on_done := Callable()) -> void:
	_convo_node(convo, String(convo.get("start", "")), on_done)

func _convo_node(convo: Dictionary, node_id: String, on_done: Callable) -> void:
	var nodes: Dictionary = convo.get("nodes", {})
	if node_id == "" or not nodes.has(node_id):
		autosave()  # choices are story progress
		if on_done.is_valid():
			on_done.call()
		return
	var node: Dictionary = nodes[node_id]
	if cutscene and node.has("cue"):
		cutscene.cue(String(node["cue"]))  # stage the picture for this beat
	var who: String = node.get("who", "")
	# A matched variant can override the text AND the path: a variant
	# with its own "next" makes the node linear (choices are skipped) —
	# the short-circuit for "we already had this conversation" greetings.
	var variant := _convo_variant(node)
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
			_convo_node(convo, next_id, on_done))
	else:
		var option_texts: Array = []
		for c in choices:
			option_texts.append(String(c["text"]))
		hud.dialogue_choice(who, text, option_texts, func(idx: int) -> void:
			var c: Dictionary = choices[idx]
			var res_delta := float(c.get("resonance", 0.0))
			player.add_resonance(res_delta)
			if res_delta != 0.0:
				_resonance_reward(res_delta)
			var fac_shifts: Dictionary = c.get("faction", {})
			for fac in fac_shifts:
				player.faction_standing[fac] = int(player.faction_standing.get(fac, 0)) + int(fac_shifts[fac])
			# Side-quest acceptance runs BEFORE the choice's flags land, so
			# a single choice can accept a quest and complete its first
			# step (or even the whole chain) in one breath. Quests bind to
			# their authored chapter — a wanderer repeating his ask in a
			# later chapter can't open an uncompletable job.
			if c.has("side_quest"):
				var sqid := String(c["side_quest"])
				var sq: Dictionary = Story.ALL_SIDE_QUESTS.get(sqid, {})
				if not sq.is_empty() and String(sq.get("chapter", chapter_id)) == chapter_id \
						and not get_flag("sq_on_" + sqid, false):
					set_flag("sq_on_" + sqid)
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
			_convo_node(convo, String(c.get("next", "")), on_done))


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
	var f := FileAccess.open("user://keybinds.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(binds))

func load_binds() -> void:
	if not FileAccess.file_exists("user://keybinds.json"):
		return
	var f := FileAccess.open("user://keybinds.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
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
	if room_type(i) in Balance.SMALL_ROOM_TYPES:
		return Balance.SMALL_ROOM_INSET
	return Vector2.ZERO

## The walled, walkable area of a room (equals room_rect for full-size
## rooms). Cameras, spawns and clamps all use THIS rect.
func play_rect(i: int) -> Rect2:
	var ins := room_inset(i)
	return Rect2(rooms[i]["origin"] + ins, Vector2(ROOM_W, ROOM_H) - ins * 2.0)

## Map an authored in-room position into the playable rect — authored
## coordinates assume the full cell, so small rooms scale them down.
func room_pos(i: int, x: float, y: float) -> Vector2:
	var meta: Dictionary = rooms[i]
	var p: Vector2 = Vector2(x, y) * meta["scale"]
	var ins := room_inset(i)
	if ins != Vector2.ZERO:
		p = ins + p * (Vector2(ROOM_W, ROOM_H) - ins * 2.0) / Vector2(ROOM_W, ROOM_H)
	return meta["origin"] + p

func room_center(i: int) -> Vector2:
	return rooms[i]["origin"] + Vector2(ROOM_W, ROOM_H) / 2.0

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
	return kind == "" or boss_done.get(kind, false)

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
func travel_target(i: int) -> bool:
	if not visited.get(i, false) or i == cur_room:
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
	for b in _live_bosses():
		fight_track(b)


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
	print("[fight] %s | %s Lv%d | ttk %d:%02d | pool %.0f | dps %.1f | taken %.0f | potions %d | wipes %d" % [
		roster, player.cls, player.level, mins, int(secs) % 60,
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
	send_mail("Victory — %s" % subject,
		"You brought down %s!\n\nThe record of the fight:\n\n%s" % [titles, last_fight_report], [])

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
	var text: String = Story.quest_text(quest_key)
	var zi: int = clampi(cur_room, 0, zone_count - 1)
	var left: int = zone_alive.get(zi, 0)
	if left > 0:
		# Sealed doors need a visible WHY: every room with living packs
		# shows its purge counter, not just boss arenas.
		text += "   —   %d monster%s left" % [left, "" if left == 1 else "s"]
	hud.set_quest(text)

## Clamp a position into the room that contains `anchor` (dashes, drops
## and boss blinks never leave the room they started in).
func clamp_to_zone(pos: Vector2, anchor: Vector2) -> Vector2:
	var zi := room_at_pos(anchor)
	if zi < 0:
		zi = clampi(cur_room, 0, zone_count - 1)
	var r := play_rect(zi)
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
	amb_player.volume_db = AMB_DB + _vol_db(float(settings["sfx"]))
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
func sfx(name: String, pitch := 1.0, cutoff := 0.0, vol_db := 0.0) -> void:
	if not sounds.has(name):
		return
	var chosen: AudioStreamPlayer = sound_pool[0]
	for sp in sound_pool:
		if not sp.playing:
			chosen = sp
			break
	# Small random pitch per play: kills the machine-gun sameness of
	# repeated samples and the phasing of near-simultaneous ones.
	# vol_db offsets the base level (e.g. quiet ambient stings).
	chosen.pitch_scale = pitch * randf_range(0.94, 1.06)
	chosen.volume_db = -8.0 + vol_db
	chosen.stream = sounds[name]
	chosen.play()
	if cutoff > 0.0:
		var this_stream: AudioStream = chosen.stream
		var tween := create_tween()
		tween.tween_interval(cutoff)
		tween.tween_property(chosen, "volume_db", -40.0, 0.4)
		tween.tween_callback(func() -> void:
			if chosen.stream == this_stream:
				chosen.stop()
			chosen.volume_db = -8.0
		)

func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)

## Telegraphed ground attack: a danger zone appears, pulses for `delay`
## seconds, then erupts — heavy damage if the player is still inside.
## opts: {"color": Color, "sword": true} (sword = a blade falls from the sky).
## A world position sheltered by any LIVE SafeDome? (Ground warded by an
## airborne safe-spot exam — see SafeDome above.)
func _sheltered(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("safe_domes"):
		var dome := node as SafeDome
		if dome and dome.shelters(pos):
			return true
	return false


func telegraph(pos: Vector2, radius: float, delay: float, damage: float, opts := {}) -> void:
	# Shelter wards the GROUND (player rule 2026-07-09): a danger telegraph
	# that would land inside a live shelter never forms — Varo's reliquary
	# swords were falling INTO his own Toll shadows, making the compliant
	# stand a chip-death. The dome eats the sky as well as the bullets.
	if _sheltered(pos):
		return
	# MP-09: the host mirrors every tell to guests as a VISUAL-ONLY event —
	# co-op dodging needs a guest to see exactly what the host sees,
	# including tells the boss aims at THE GUEST (pick_target already
	# targets any player). One hook here rides under every call site
	# (bosses, mob traits, bloat bursts). Solo: net_host() is false.
	if net_host():
		net_session().host_telegraph(pos, radius, delay, opts)
	var zone := Sprite2D.new()
	zone.texture = Art.tex("telegraph")
	zone.global_position = pos
	zone.scale = Vector2(radius / 32.0, radius / 32.0)
	zone.modulate = opts.get("color", Color(1.0, 0.2, 0.15, 0.55))
	zone.z_index = -6
	add_child(zone)
	var pulse := zone.create_tween()
	pulse.set_loops()
	pulse.tween_property(zone, "modulate:a", 0.85, 0.18)
	pulse.tween_property(zone, "modulate:a", 0.45, 0.18)

	var sword: Sprite2D = null
	if opts.get("sword", false) or opts.get("fireball", false):
		sword = Sprite2D.new()
		sword.texture = Art.tex("fireball" if opts.get("fireball", false) else "greatsword")
		sword.scale = Vector2(6, 6) if opts.get("fireball", false) else Vector2(4.5, 4.5)
		if opts.get("fireball", false):
			sword.modulate = Color(1.0, 0.55, 0.2)
		sword.global_position = pos + Vector2(0, -420)
		sword.z_index = 30
		add_child(sword)
		var fall := sword.create_tween()
		fall.tween_property(sword, "global_position", pos + Vector2(0, -20), delay).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(zone):
		return
	zone.queue_free()
	sfx("slam")
	shake(6.0)
	burst(pos, opts.get("color", Color(1.0, 0.35, 0.2)), 18)
	if sword and is_instance_valid(sword):
		var sink := sword.create_tween()
		sink.tween_property(sword, "modulate:a", 0.0, 0.35)
		sink.tween_callback(sword.queue_free)
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
		var zone := Sprite2D.new()
		zone.texture = Art.tex("telegraph")
		zone.global_position = c
		zone.scale = Vector2(radius / 32.0, radius / 32.0)
		zone.modulate = opts.get("color", Color(0.5, 1.0, 0.7, 0.5))
		zone.z_index = -6
		add_child(zone)
		zones.append(zone)
		var pulse := zone.create_tween()
		pulse.set_loops()
		pulse.tween_property(zone, "modulate:a", 0.75, 0.22)
		pulse.tween_property(zone, "modulate:a", 0.4, 0.22)
		zones.append(_safe_beacon(c, opts.get("color", Color(0.5, 1.0, 0.7)), false))
	# The dome shields only the REAL centers, for the fuse + a linger beat.
	var dome := SafeDome.new()
	dome.centers = centers.duplicate()
	dome.dome_radius = radius
	dome.life = delay + 0.5
	dome.tint = opts.get("color", Color(0.5, 1.0, 0.7))
	dome.game_ref = self
	add_child(dome)
	var decoys: Array = opts.get("decoys", [])
	for c in decoys:
		var lie := Sprite2D.new()
		lie.texture = Art.tex("telegraph")
		lie.global_position = c
		lie.scale = Vector2(radius / 32.0, radius / 32.0)
		lie.modulate = opts.get("color", Color(0.5, 1.0, 0.7, 0.5))
		lie.z_index = -6
		add_child(lie)
		zones.append(lie)
		var flicker := lie.create_tween()
		flicker.set_loops()
		flicker.tween_property(lie, "modulate:a", 0.15, 0.07)
		flicker.tween_property(lie, "modulate:a", 0.7, 0.09)
		# The decoy's beacon flickers with the same lie — the tell stays
		# consistent across both reads (circle AND pillar).
		zones.append(_safe_beacon(c, opts.get("color", Color(0.5, 1.0, 0.7)), true))

	await get_tree().create_timer(delay).timeout
	var any_alive := false
	for zone in zones:
		if is_instance_valid(zone):
			any_alive = true
			zone.queue_free()
	if not any_alive:
		if is_instance_valid(hud):
			hud.danger_end(true)
		return
	sfx("slam")
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
func emote(target: Node2D, symbol: String, dur := 1.4) -> void:
	if not is_instance_valid(target):
		return
	var box := Node2D.new()
	box.position = Vector2(10, -46)
	box.z_index = 30
	var spr := Sprite2D.new()
	spr.texture = Art.tex("bubble")
	spr.scale = Vector2(2.4, 2.4)
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
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
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


## hold: seconds the text sits still before the float-and-fade (the
## fight report needs reading time; combat numbers leave it at 0).
func spawn_text(pos: Vector2, text: String, color: Color, hold := 0.0) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-70, -10)
	l.size = Vector2(140, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", _floor_text_color(color))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	var tween := create_tween()
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(l, "position:y", l.position.y - 34.0, 0.9)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tween.tween_callback(l.queue_free)


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
	l.position = pos + Vector2(-50, -6)
	l.size = Vector2(100, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 19  # under your own numbers (z 20)
	l.add_theme_font_size_override("font_size", 11)
	# A cool, dim tint marks it as someone else's damage; crits warm slightly.
	var col := Color(1.0, 0.72, 0.45, 0.8) if crit else Color(0.78, 0.86, 0.95, 0.72)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	var tween := create_tween()
	tween.tween_property(l, "position:y", l.position.y - 24.0, 0.75)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.75)
	tween.tween_callback(l.queue_free)


# =================================================================== per-frame
