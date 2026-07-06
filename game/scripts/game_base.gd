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
var player: Player
var hud: Hud
var menus: Menus
var camera: Camera2D
var ambient: CanvasModulate
var reticle: Sprite2D
var reticle_label: Label

# Rebindable keys. Movement is always WASD/arrows; ESC is fixed.
var binds := {
	"a1": KEY_J, "a2": KEY_K, "a3": KEY_L, "ult": KEY_U,
	"potion": KEY_Q, "interact": KEY_E, "inventory": KEY_I, "skills": KEY_T,
	"codex": KEY_C, "target": KEY_TAB, "map": KEY_M,
}

var quest_key := "talk"
var talked_to_elder := false
var talk_cd := 0.0
var cur_room := 0                # the room the player occupies (only it simulates)
var last_room := -1              # previous frame's room (change detection)
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
var zone_scenery := {}                # room idx -> decor + obstacle nodes
var hazards: Array = []               # active floor patches (lava/ice/...)
var terrain_event_t := 4.0            # countdown to the next terrain event
var hazard_tick := 0.0
var gust_vec := Vector2.ZERO          # sandstorm push applied to everyone
var gust_t := 0.0

# ---------------------------------------------------------- persistence ---
var save_slot := -1                   # active save file (-1 = none yet)
var no_saves := false                 # autotest: never touch real save files
var settings := {"music": 1.0, "sfx": 1.0, "fullscreen": false}  # user://settings.json
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

const MUSIC_TUNE := {
	"icefield": {"gain": 14.0, "start": 10.0},  # whisper-quiet master
	"rainstorm": {"start": 30.0},               # storm fades in over ~30s
	"holy": {"gain": 4.0},
	"magma": {"gain": -4.0},
	"crystalline": {"gain": -3.0},
}
const MUSIC_DB := -16.0


## The best gear grade this chapter can drop (act gating, DESIGN.md):
## Act 1 caps at C, Act 2 at A — S-tier is endgame loot only.
func loot_cap() -> String:
	return String(Story.chapter(chapter_id).get("loot_cap", "S"))

## (T7) Merchants read the shard: the steady get kinder prices, the
## tempted make the till nervous. Surfaced, never explained in numbers.
func band_price_mult() -> float:
	match Story.res_band(player.resonance):
		"steady": return 0.9
		"tempted": return 1.1
	return 1.0

## Write the current character to its slot. Called on story progress,
## zone changes, menu closes and window close — never mid-death.
func autosave() -> void:
	if save_slot > 0 and play_started and state == ST_PLAYING and not player.dead:
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
			give_loot({"kind": "gem", "gem": Items.random_gem(loot_rng, lvl)},
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
		give_loot({"kind": "gem", "gem": Items.random_gem(loot_rng, int(b["gem_lvl"]))},
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
	give_loot({"kind": "gem", "gem": Items.random_gem(loot_rng, 2)}, player.global_position + Vector2(0, 44))
	sfx("chest")
	spawn_text(player.global_position + Vector2(0, -70), "WEEKLY VAULT CLAIMED!", Color(1.0, 0.85, 0.4), 4.0)
	autosave()
	return ["a golden chest", "a bright gem"]


## Give loot to the player — or drop it at `pos` when the bag is full.
## Ground drops are registered and flush into a "Dropped Loot" letter
## at chapter end: nothing is ever silently lost. Returns true when it
## went straight into the bag.
func give_loot(payload: Dictionary, pos: Vector2) -> bool:
	if _try_receive(payload):
		return true
	payload["pos"] = [pos.x, pos.y]
	dropped_loot.append(payload)
	Pickup.drop_loot(self, payload, pos)
	spawn_text(pos + Vector2(0, -44), "Bag full! Dropped", Color(1, 0.9, 0.4))
	return false


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

func set_flag(flag_name: String, value = true) -> void:
	flags[flag_name] = value
	# Flag-locked gates: any built gate whose flag just got set unlocks.
	# (Dynamic call: gates live a layer up in game_world.gd — the ONE
	# deliberate upward call in the chain.)
	if value:
		call("_recheck_gates")

func get_flag(flag_name: String, def = false):
	return flags.get(flag_name, def)

func run_convo_id(id: String, on_done := Callable()) -> void:
	run_convo(Story.ALL_CONVOS[id], on_done)

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
			var set_flags: Dictionary = c.get("flags", {})
			for fname in set_flags:
				set_flag(fname, set_flags[fname])  # via set_flag: gates react
			if c.has("quest"):
				quest_key = String(c["quest"])
				refresh_quest()
			_convo_node(convo, String(c.get("next", "")), on_done))

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
	var titles := " + ".join(fight_titles) if not fight_titles.is_empty() else roster
	send_mail("Victory — %s" % titles,
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

func _vol_db(linear: float) -> float:
	return -80.0 if linear <= 0.01 else linear_to_db(linear)


## Switch the background track with a quick fade.
## Per-track mix fixes for external recordings (measured RMS): dB gain
## evens out mastering differences, start skips long quiet intros
## (loops restart from the same offset via the stream's loop_offset).
func set_music(name: String) -> void:
	if name == current_track or music_player == null:
		return
	current_track = name
	var tune: Dictionary = MUSIC_TUNE.get(name, {})
	music_gain_db = MUSIC_DB + float(tune.get("gain", 0.0))
	var tween := create_tween()
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
func telegraph(pos: Vector2, radius: float, delay: float, damage: float, opts := {}) -> void:
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
	if is_instance_valid(player) and not player.dead \
			and player.global_position.distance_to(pos) <= radius + 8.0:
		player.take_damage(damage, "magic")


## INVERSE telegraph (safe-zone): after the delay the whole arena hits
## EXCEPT the marked circle(s) — stand inside one to live. Debuted by
## Vess (ch3); reused by Varo's tolls, then Serane / Ordo / Cyrraeth
## (see BOSSES.md toolbox). opts["decoys"]: extra positions drawn like
## safe circles but FLICKERING — lies that grant no safety (the steady
## circle is the truth).
func telegraph_safe(centers: Array, radius: float, delay: float, damage: float, opts := {}) -> void:
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

	await get_tree().create_timer(delay).timeout
	var any_alive := false
	for zone in zones:
		if is_instance_valid(zone):
			any_alive = true
			zone.queue_free()
	if not any_alive:
		return
	sfx("slam")
	shake(9.0)
	if not is_instance_valid(player) or player.dead:
		return
	for c in centers:
		var safe_at: Vector2 = c
		if player.global_position.distance_to(safe_at) <= radius + 8.0:
			burst(player.global_position, Color(0.6, 1.0, 0.75), 12)  # sheltered
			return
	burst(player.global_position, Color(1.0, 0.35, 0.2), 18)
	player.take_damage(damage, "magic")
	# Some inverse telegraphs don't just hurt — they FREEZE or ROOT the
	# player caught in the open (Serane's Flash Freeze, ch5+).
	if opts.has("freeze"):
		player.apply_freeze(float(opts["freeze"]))
	if opts.has("root"):
		player.apply_root(float(opts["root"]))

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
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	var tween := create_tween()
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(l, "position:y", l.position.y - 34.0, 0.9)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tween.tween_callback(l.queue_free)


# =================================================================== per-frame
