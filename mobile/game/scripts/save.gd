class_name SaveGame
## Save / load: one JSON file per character at user://save_<slot>.json.
## The game autosaves on story progress, zone changes and menu closes
## (see Game.autosave); there is no manual save button by design.
##
## Everything stored is already JSON-safe (items and gems are plain
## Dictionaries of strings/numbers). JSON turns ints into floats, so
## every read casts explicitly — never trust a loaded number's type.
##
## v3 shape (MULTIPLAYER.md §2.2 blocker 5 + §5.7 — "host owns the
## world, guest brings their character"):
##   { version, saved_at, chapter,   # top-level metadata
##     character: { ... },           # everything that travels WITH the player
##     world:     { ... } }          # everything describing THIS run's world/story
## Same fields as v2, one nesting level deeper. read() lifts legacy flat
## blobs into this shape in memory (_migrate_v2); writes are always v3.

const VERSION := 3   # v3: character/world split. v2: the zone graph. v1: pre-graph.
# 20 slots: dev rosters (6 per press) live alongside real playthroughs
# without anyone juggling deletions. Only occupied slots render anywhere.
const MAX_SLOTS := 20


static func path(slot: int) -> String:
	return "user://save_%d.json" % slot


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## Crash-safe JSON write (CR-006). Every persistent JSON file in the game routes
## through here instead of opening the final path with FileAccess.WRITE (which
## truncates the live file BEFORE the new bytes are committed — a crash, power
## loss or disk-full mid-write then leaves an empty/half save). Instead:
##   1. serialize to a sibling ".tmp" and flush it,
##   2. re-read + parse the tmp to prove it is valid JSON,
##   3. roll the current file to ".bak" (last-known-good),
##   4. atomically rename tmp -> final.
## The worst interruption leaves a stale-but-whole file plus a recoverable .bak;
## read_json() below prefers the main file and falls back to the backup.
## Returns true only when the final file now holds the new content.
static func atomic_store(dst: String, text: String) -> bool:
	var dir := dst.get_base_dir()
	var base := dst.get_file()
	var tmp := dst + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("atomic_store: cannot open temp for %s" % dst)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Verify the temp parses before letting it replace the live file.
	var chk := FileAccess.open(tmp, FileAccess.READ)
	if chk == null:
		return false
	var parsed = JSON.parse_string(chk.get_as_text())
	chk.close()
	if not (parsed is Dictionary or parsed is Array):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		push_warning("atomic_store: temp did not round-trip for %s" % dst)
		return false
	var d := DirAccess.open(dir)
	if d == null:
		return false
	# rename() fails on Windows if the target exists, so the current file must
	# step aside first — which conveniently leaves it as the .bak.
	if FileAccess.file_exists(dst):
		if FileAccess.file_exists(dst + ".bak"):
			d.remove(base + ".bak")
		d.rename(base, base + ".bak")
	return d.rename(base + ".tmp", base) == OK


## Read + JSON-parse a file written by atomic_store, transparently recovering
## from its ".bak" if the main file is missing or corrupt (CR-006/CR-007).
## Returns {} when neither yields a Dictionary.
static func read_json(dst: String) -> Dictionary:
	for p in [dst, dst + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			return data
	return {}


static func write(game: Game, slot: int) -> void:
	var p := game.player
	# CHARACTER — travels with the player between worlds (§5.7).
	var character := _character_section(game)
	# WORLD — describes THIS run's world/story. A guest's own copy simply
	# goes unused while guesting, and never absorbs the host's (§5.7).
	var world := {
		"quest_key": game.quest_key,
		"talked_to_elder": game.talked_to_elder,
		"flags": game.flags,
		"quest_kills": game.quest_kills,   # KILL-step counters (world/run state, chapter-wiped)
		"merchant_zones": game.merchant_zones,
		# Run stats describe THE RUN (this world's playthrough), not the
		# traveling character — §5.7's take-home list is XP/gold/gems/gear/
		# standings/resonance, so a solo results card never absorbs a co-op
		# session. weekly_active/weekly_week qualify the RUN as this week's
		# challenge (the per-character claim ledger lives above).
		"run_time": game.run_time, "run_deaths": game.run_deaths,
		"run_elites": game.run_elites, "run_secrets": game.run_secrets,
		"run_xp": game.run_xp, "run_levels": game.run_levels,
		"weekly_active": game.weekly_active, "weekly_week": game.weekly_week,
		# The NG+ tier THIS run launched at (snapshot; the standing choice
		# rides the character as run_tier above).
		"run_tier_world": game.world_run_tier,
		# The Waking Incursion week THIS world's breach rooms were built
		# for (-1 = none) — geography, so load_save restores it BEFORE the
		# rebuild, exactly like wander_seed below.
		"waking_week": game.waking_week,
		# Slain bosses resolve THIS world's rooms and gates on load
		# (reconcile_after_load) — world state. PBs stay in character.
		"bosses_slain": game.boss_done.keys(),
		# pos pairs with cur_room/wander_seed: coordinates mean nothing in
		# another world's geometry, so a guest's position never writes home.
		"pos": [p.global_position.x, p.global_position.y],
		# --- the zone graph (v2) ---
		"cur_room": game.cur_room,
		"last_safe_room": game.last_safe_room,
		"visited_rooms": game.visited.keys(),
		"cleared_rooms": game.cleared.keys(),
		"door_seen": game.door_seen.keys(),
		"wander_seed": game.wander_seed,
	}
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		# chapter stays TOP-LEVEL metadata: it names which chapter BOTH
		# sections describe, and load_save reads it before either section
		# applies (it picks the world to build).
		"chapter": game.chapter_id,
		"character": character,
		"world": world,
	}
	atomic_store(path(slot), JSON.stringify(data))


## The CHARACTER section (§5.7): everything that travels WITH the player
## between worlds — identity, progression, gear, wallet, records,
## per-player reward faucets. Shared by write() (full save) and
## write_character_home() (guest autosave, MP-08).
static func _character_section(game: Game) -> Dictionary:
	var p := game.player
	p.sync_active_talent_loadout()
	return {
		# --- identity / progression ---
		"name": p.char_name,
		"cls": p.cls,
		"level": p.level, "xp": p.xp,
		"skill_points": p.skill_points, "tree_points": p.tree_points,
		"talent_loadouts": p.talent_loadouts,
		"active_talent_loadout": p.active_talent_loadout,
		"attr_points": p.attr_points, "unspent_attr": p.unspent_attr,
		"gold": p.gold,
		# Health potions are graded bag items now (CONSUMABLE_GRADES) — they ride
		# the `consumables` array like any potion; the `potions`/`potions_free`
		# counters are RETIRED (no save-migration: old fields drop on load). The
		# ch1-3 teaching gift is a flagged Defective Health Potion that game_world
		# reconciles on chapter entry (re-granted, then never re-banked stale).
		"ability_theme": p.ability_theme,
		"chroma": p.chroma,
		"skin": p.skin,
		# Standings + resonance are PER-CHARACTER (§5.7): reputation and band
		# lean travel into a friend's world and come home with you.
		"resonance": p.resonance,
		"faction_standing": p.faction_standing,
		# Capital NPC favorability (2026-07-25 rework) — the city remembers
		# its patrons; rides the character like resonance does.
		"npc_favor": p.npc_favor,
		# The plaza bazaar's daily shelf (capital rework §3): what dawn rolled
		# and when — re-entering the city must NOT re-roll the day's stock.
		"capital_stock": game.capital_stock, "capital_bags": game.capital_bags,
		"capital_shop_day": game.capital_shop_day,
		# --- gear ---
		"equipment": p.equipment, "backpack": p.backpack, "gem_bag": p.gem_bag,
		"bags": p.bags, "loose_bags": p.loose_bags, "consumables": p.consumables, "materials": p.materials,
		"potion_rotation": p.potion_rotation, "active_potion": p.active_potion,
		# Waking Depths: highest cleared checkpoint depth (re-entry point).
		"depths_checkpoint": p.depths_checkpoint,
		# NG+ difficulty tier the campaign runs at (0 = Normal).
		"run_tier": p.run_tier,
		# Professions (crafting core): the locked trade, per-trade mastery (persists
		# across swaps), known generic blueprints, and the weekly swap-cost counter.
		"profession": p.profession, "mastery": p.mastery, "blueprints": p.blueprints,
		"swap_cost_step": p.swap_cost_step, "swap_week": p.swap_week,
		# The Alkahest Codex learn-once flag (CONSUMABLE_GRADES §9 synthesis capstone).
		"knows_alkahest": p.knows_alkahest,
		# --- vitals ---
		"hp": p.hp, "mp": p.mp,
		# Mailbox + dropped loot are CHARACTER-owned (§5.5 loot instancing:
		# every drop / forgotten-loot mail has exactly one owner). Dropped
		# ground positions are world coordinates, but the loss mode is benign
		# — flush_dropped_loot converts strays to positionless mail.
		"mailbox": game.mailbox, "dropped_loot": game.dropped_loot,
		# The trusted clock anchor fences THIS CHARACTER's daily/weekly/mail
		# timers against OS clock rollback — it guards character faucets, so
		# it rides with them (a live co-op session uses the host's clock).
		"clock_anchor": game.trusted_now(),
		"daily_last_day": game.daily_last_day, "daily_streak": game.daily_streak,
		# Records — achievements, titles, per-boss PBs, lifetime kill tallies
		# (codex lore thresholds) — are this hero's story, not this world's.
		"achievements": game.achievements.keys(), "boss_records": game.boss_records,
		"kill_counts": game.kill_counts, "player_title": game.player_title,
		# Gallery portraits met + the story-so-far archive (journal): this
		# hero's memory of faces and conversations, so it travels with them.
		"splashes_seen": game.splashes_seen.keys(),
		"convo_log": game.convo_log, "convo_log_order": game.convo_log_order,
		# Bounty board / vault / weekly-claim ledger: per-player reward
		# faucets (instanced per player in co-op — §5.5). The weekly RUN
		# marker itself is world state; only the claim ledger travels.
		"bounties": game.bounties, "bounty_day": game.bounty_day, "bounty_week": game.bounty_week,
		"vault_week": game.vault_week, "vault_progress": game.vault_progress,
		"vault_claimed_week": game.vault_claimed_week,
		"weekly_claimed_week": game.weekly_claimed_week,
		# Renown supply-cache ledger (the wallet itself is account meta).
		"renown_cache_week": game.renown_cache_week,
		# Waking Incursion kill ledger (per-head faucet, like the vault).
		"waking_kills_week": game.waking_kills_week,
		"waking_kills": game.waking_kills,
	}


## GUEST autosave (MP-08, §5.7): while playing in ANOTHER world, only the
## character block writes home. The guest's own world section — and the
## chapter that names it — stay exactly as their last solo session left
## them; the host's flags/rooms/seed never colonize this file.
static func write_character_home(game: Game, slot: int) -> void:
	var data := read(slot)  # the home save, lifted to v3 in memory
	var out := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"chapter": String(data.get("chapter", "ch1")),
		"character": _character_section(game),
		"world": world_of(data),
	}
	atomic_store(path(slot), JSON.stringify(out))


# ------------------------------------------ dedicated server world (MMO B) ---
# The DEDICATED server (--server) owns a world with no character attached:
# its save is exactly the v3 `world` section a character save carries —
# same fields, same shape — minus the player-position pair (no host body),
# plus the server's own trusted-clock anchor. Kept format-compatible so a
# future account backend (MMO step C) lifts it unchanged.

const SERVER_WORLD_PATH := "user://server_world.json"

static func write_server_world(game: Game) -> void:
	var world := {
		"quest_key": game.quest_key,
		"talked_to_elder": game.talked_to_elder,
		"flags": game.flags,
		"quest_kills": game.quest_kills,
		"merchant_zones": game.merchant_zones,
		"run_time": game.run_time, "run_deaths": game.run_deaths,
		"run_elites": game.run_elites, "run_secrets": game.run_secrets,
		"run_xp": game.run_xp, "run_levels": game.run_levels,
		# A server world is never the weekly-challenge run (that is a
		# per-player replay mode) — persisted false by construction. The
		# NG+ tier: a DEDICATED server world runs Normal (no host character
		# owns a choice); a player-hosted world's tier lives in that
		# host's own save, not here.
		"weekly_active": false, "weekly_week": -1,
		"run_tier_world": 0,
		"bosses_slain": game.boss_done.keys(),
		"cur_room": game.cur_room,
		"last_safe_room": game.last_safe_room,
		"visited_rooms": game.visited.keys(),
		"cleared_rooms": game.cleared.keys(),
		"door_seen": game.door_seen.keys(),
		"wander_seed": game.wander_seed,
	}
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"chapter": game.chapter_id,
		# The server owns the session's trusted clock (§4.1 clock row);
		# persisting the anchor keeps it monotonic across restarts.
		"clock_anchor": game.trusted_now(),
		"world": world,
	}
	atomic_store(SERVER_WORLD_PATH, JSON.stringify(data))


static func exists_server_world() -> bool:
	return FileAccess.file_exists(SERVER_WORLD_PATH)


static func read_server_world() -> Dictionary:
	return read_json(SERVER_WORLD_PATH)  # main, then .bak (CR-006)


## Apply a server world file onto a freshly rebuilt world — the world half
## of apply(), player-free. The caller honors load_save's contract: set
## wander_seed and switch_chapter(chapter, true) BEFORE calling this.
static func apply_server_world(game: Game, data: Dictionary) -> void:
	var w := world_of(data)
	game.clock_anchor = maxi(game.clock_anchor, int(data.get("clock_anchor", 0)))
	game.quest_key = String(w.get("quest_key", "talk"))
	game.talked_to_elder = bool(w.get("talked_to_elder", false))
	game.flags = _as_dict(w.get("flags", {}))          # a non-dict flags blob can't poison the world
	game.quest_kills = _as_dict(w.get("quest_kills", {}))
	game.run_time = float(w.get("run_time", 0.0))
	game.run_deaths = int(w.get("run_deaths", 0))
	game.run_elites = int(w.get("run_elites", 0))
	game.run_secrets = int(w.get("run_secrets", 0))
	game.run_xp = int(w.get("run_xp", 0))
	game.run_levels = int(w.get("run_levels", 0))
	game.boss_done = {}
	for kind in _as_arr(w.get("bosses_slain", [])):
		game.boss_done[String(kind)] = true
	for r in _as_arr(w.get("visited_rooms", [])):
		game.visited[_as_int(r, 0)] = true
	for r in _as_arr(w.get("cleared_rooms", [])):
		game.cleared[_as_int(r, 0)] = true
	for r in _as_arr(w.get("door_seen", [])):
		game.door_seen[_as_int(r, 0)] = true
	game.last_safe_room = clampi(_as_int(w.get("last_safe_room", 0), 0), 0, game.zone_count - 1)
	for z in _as_arr(w.get("merchant_zones", [])):
		game._spawn_merchant(_as_int(z, 0))
	# Stand the world at its last safe room: the join snapshot's spawn_room
	# is cur_room, so joiners arrive somewhere pacified.
	game._enter_room(game.last_safe_room)
	game.reconcile_after_load()


## Reads always return the v3 shape: legacy flat blobs are lifted in
## memory here (the file on disk stays as-is until the next autosave).
static func read(slot: int) -> Dictionary:
	# read_json recovers from the .bak if an interrupted write left the main
	# file missing or corrupt (CR-006).
	var data := read_json(path(slot))
	return _migrate_v2(data) if not data.is_empty() else {}


## Section accessors — the seam §5.7 builds on. Code outside save.gd
## reaches into a save dict through these, never by raw key. A corrupt slot
## whose section isn't a Dictionary resolves to {} rather than script-erroring
## the roster (SaveGame.list scans EVERY slot, so one bad file must not break
## access to the others — CR-007).
static func character_of(data: Dictionary) -> Dictionary:
	return _as_dict(data.get("character", {}))


static func world_of(data: Dictionary) -> Dictionary:
	return _as_dict(data.get("world", {}))


# ---- defensive coercions for loaded JSON (CR-007) ----
# A syntactically valid but wrong-shaped save (hand-edited, partially migrated,
# or from a future format) must never hard-error a typed assignment or a
# for-loop. These narrow an untrusted value to the expected container/scalar.
static func _as_dict(v) -> Dictionary:
	return v if v is Dictionary else {}

static func _as_arr(v) -> Array:
	return v if v is Array else []

## A loaded value read as an int, tolerating JSON floats and numeric strings;
## containers/objects/garbage fall back to `dflt` instead of throwing on int().
static func _as_int(v, dflt: int) -> int:
	if v is int:
		return v
	if v is float and is_finite(v):
		return int(v)
	if v is bool:
		return 1 if v else 0
	if v is String and v.is_valid_int():
		return v.to_int()
	return dflt

## A loaded value read as a finite float; non-numeric/non-finite → `dflt`.
static func _as_float(v, dflt: float) -> float:
	if v is float:
		return v if is_finite(v) else dflt
	if v is int:
		return float(v)
	if v is String and v.is_valid_float():
		return v.to_float()
	return dflt


# Where each v2 flat field lands in v3. "bag" is the round-52 legacy
# single-bag key (pre-`bags` saves) — routed so load_bags still sees it.
const _V2_CHARACTER_FIELDS := ["name", "cls", "level", "xp", "skill_points", "tree_points",
	"attr_points", "unspent_attr", "gold", "ability_theme", "chroma", "skin",
	"resonance", "faction_standing", "equipment", "backpack", "gem_bag", "bags", "loose_bags", "bag",
	"consumables", "materials", "potion_rotation", "active_potion", "depths_checkpoint", "hp", "mp",
	"profession", "mastery", "blueprints", "swap_cost_step", "swap_week", "knows_alkahest",
	"mailbox", "dropped_loot", "clock_anchor", "daily_last_day", "daily_streak",
	"achievements", "boss_records", "kill_counts", "player_title",
	"bounties", "bounty_day", "bounty_week",
	"vault_week", "vault_progress", "vault_claimed_week", "weekly_claimed_week",
	"renown_cache_week", "waking_kills_week", "waking_kills"]
const _V2_WORLD_FIELDS := ["quest_key", "talked_to_elder", "flags", "quest_kills", "merchant_zones",
	"run_time", "run_deaths", "run_elites", "run_secrets",
	"weekly_active", "weekly_week", "waking_week", "bosses_slain", "pos",
	"cur_room", "last_safe_room", "visited_rooms", "cleared_rooms", "door_seen",
	"wander_seed"]


## Lift a legacy flat blob (v1/v2) into the v3 two-section shape, in
## memory only. NO field is ever dropped: keys the routing tables don't
## know stay top-level, exactly where v2 kept them (inert but preserved).
## Idempotent — v3 input returns unchanged.
static func _migrate_v2(d: Dictionary) -> Dictionary:
	if int(d.get("version", 1)) >= 3:
		return d
	var c := {}
	var w := {}
	var out := {}
	for k in d:
		if _V2_CHARACTER_FIELDS.has(k):
			c[k] = d[k]
		elif _V2_WORLD_FIELDS.has(k):
			w[k] = d[k]
		else:
			out[k] = d[k]  # version/saved_at/chapter + anything unrecognized
	out["character"] = c
	out["world"] = w
	out["version"] = 3  # stamped AFTER the copy loop so it wins over v1/v2
	return out


static func delete(slot: int) -> void:
	# Remove the main file AND its atomic-write sidecars (.bak/.tmp) so a deleted
	# hero can't resurrect from a stale backup (CR-006).
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Rename a hero in place: rewrite ONLY the character name onto an existing
## save, leaving world and the rest of the character block untouched. Reads
## through the v3 lift, so a legacy blob is renamed and re-stamped in its
## modern shape (lossless — _migrate_v2 preserves every field). No-ops on an
## empty/missing slot. The name arrives already sanitized (menus.gd).
static func rename_character(slot: int, new_name: String) -> void:
	var data := read(slot)
	if data.is_empty():
		return
	var c := character_of(data)
	c["name"] = new_name
	data["character"] = c
	atomic_store(path(slot), JSON.stringify(data))


## Every existing save, newest first: [{slot, cls, level, quest, saved_at}].
static func list() -> Array:
	var out: Array = []
	for slot in range(1, MAX_SLOTS + 1):
		var d := read(slot)
		if d.is_empty():
			continue
		var c := character_of(d)
		out.append({
			"slot": slot,
			"name": String(c.get("name", "")),
			"cls": String(c.get("cls", "warrior")),
			"level": _as_int(c.get("level", 1), 1),  # never int()-throw on a bad slot
			"quest": String(world_of(d).get("quest_key", "talk")),
			"saved_at": _as_int(d.get("saved_at", 0), 0),
		})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


## The lowest unoccupied slot, or -1 when the roster is full. -1 is an
## EXPLICIT "no free slot" — callers must not write over an existing save
## (CR-001: returning MAX_SLOTS here silently overwrote slot 20). The New
## Character UI blocks at capacity, so a real player never hits the -1 case.
static func next_free_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		if not exists(slot):
			return slot
	return -1  # all full — the caller must refuse, not reuse


## Load/migrate the equipped bags from a save dict (round 52) — the dict
## that HOLDS the bag keys (the character section in v3; tests hand flat
## dicts directly). New saves store a `bags` array. Migration (round 52b,
## pre-release — no live saves to protect): an OLD single `bag` dict is
## remapped by GRADE to the CURRENT BAG_SLOTS curve, discarding its
## inflated legacy slot count so old characters land on the new curve (an
## old F bag becomes a new F=10). Bags in a `bags` array are likewise
## re-derived from grade. Pre-bag saves fall back to the starter pouches.
## Split out so the migration is unit-testable without a full world apply().
static func load_bags(data: Dictionary) -> Array:
	var out: Array = []
	var bags_raw: Array = _as_arr(data.get("bags", []))
	if not bags_raw.is_empty():
		for bd in bags_raw:
			if not (bd is Dictionary):
				continue  # a non-dict bag entry just drops (CR-007)
			var b: Dictionary = bd
			b["slots"] = int(Items.BAG_SLOTS.get(String(b.get("grade", "F")), b.get("slots", 0)))
			out.append(b)
		if not out.is_empty():
			return out
	var old_bag: Dictionary = _as_dict(data.get("bag", {}))  # legacy single-bag save
	if old_bag.has("grade"):
		return [Items.make_bag(String(old_bag["grade"]))]  # remap grade -> new curve
	return Items.starter_bags()


## Restore a save onto a freshly built world. Order matters: the whole
## character first (level before class — set_class derives theme unlocks
## from it — then overrides, then recalc), then the world section, then
## the world reconciles.
static func apply(game: Game, data: Dictionary) -> void:
	data = _migrate_v2(data)  # read() already migrates; this guards raw callers
	var w := world_of(data)
	var p := game.player
	apply_character(game, character_of(data), true)

	game.quest_key = String(w.get("quest_key", "talk"))
	game.talked_to_elder = bool(w.get("talked_to_elder", false))
	game.flags = _as_dict(w.get("flags", {}))          # a non-dict flags blob can't poison the world
	game.quest_kills = _as_dict(w.get("quest_kills", {}))
	# Run stats ride the save so the results card spans sessions. They are
	# WORLD state (this run's card); only the weekly CLAIM ledger is the
	# character's (see write()).
	game.run_time = float(w.get("run_time", 0.0))
	game.run_deaths = int(w.get("run_deaths", 0))
	game.run_elites = int(w.get("run_elites", 0))
	game.run_secrets = int(w.get("run_secrets", 0))
	game.run_xp = int(w.get("run_xp", 0))
	game.run_levels = int(w.get("run_levels", 0))
	game.weekly_active = bool(w.get("weekly_active", false))
	game.weekly_week = int(w.get("weekly_week", -1))
	game.waking_week = int(w.get("waking_week", -1))
	game.world_run_tier = clampi(int(w.get("run_tier_world", 0)), 0, Balance.TIER_NAMES.size() - 1)
	game.boss_done = {}
	for kind in _as_arr(w.get("bosses_slain", [])):
		game.boss_done[String(kind)] = true
	game.wander_seed = int(w.get("wander_seed", 0))

	# --- room state (v2+). Pre-graph saves (v1) keep the character and
	# the story, but restart the chapter's GEOGRAPHY from its first room
	# — their positions were authored for a world that no longer exists.
	# (Post-migration every dict says version 3, so v1 is detected by the
	# absence of the room graph itself.)
	if w.has("visited_rooms"):
		for r in _as_arr(w.get("visited_rooms", [])):
			game.visited[_as_int(r, 0)] = true
		for r in _as_arr(w.get("cleared_rooms", [])):
			game.cleared[_as_int(r, 0)] = true
		for r in _as_arr(w.get("door_seen", [])):
			game.door_seen[_as_int(r, 0)] = true
		game.last_safe_room = clampi(_as_int(w.get("last_safe_room", 0), 0), 0, game.zone_count - 1)
		# Wandering merchants that had arrived come back (nodes appear
		# when their room builds).
		for z in _as_arr(w.get("merchant_zones", [])):
			game._spawn_merchant(_as_int(z, 0))
		var cur: int = clampi(_as_int(w.get("cur_room", 0), 0), 0, game.zone_count - 1)
		# pos: guard length AND element type — a short/garbage array must not
		# throw on pos[0]/pos[1] (CR-007). Missing/bad axes fall back to spawn.
		var pos: Array = _as_arr(w.get("pos", []))
		var px := _as_float(pos[0], 400.0) if pos.size() > 0 else 400.0
		var py := _as_float(pos[1], 360.0) if pos.size() > 1 else 360.0
		var anchor: Vector2 = game.room_center(cur)
		game._enter_room(cur)
		p.global_position = game.clamp_to_zone(Vector2(px, py), anchor)
	else:
		for z in _as_arr(w.get("merchant_zones", [])):
			game._spawn_merchant(_as_int(z, 0))
		p.global_position = game._start_pos()
		game._enter_room(game.room_at_pos(p.global_position))
	game.reconcile_after_load()


## Restore ONLY the character section onto the live game — the §5.7 seam
## MP-08's guest join runs: a joiner loads its own hero into the host's
## world without touching a single world field. Solo apply() calls this
## too, so the two paths can never drift. spawn_ground_loot=false skips
## re-dropping saved ground loot (its positions belong to the character's
## HOME geometry — while guesting they wait for the mailbox flush).
static func apply_character(game: Game, c: Dictionary, spawn_ground_loot := true) -> void:
	var p := game.player
	p.char_name = String(c.get("name", ""))
	p.level = maxi(1, _as_int(c.get("level", 1), 1))
	p.set_class(String(c.get("cls", "warrior")))
	p.xp = int(c.get("xp", 0))
	p.skill_points = int(c.get("skill_points", 0))
	# Every container below is read defensively (CR-007): a wrong-typed field in
	# a hand-edited or partly-migrated save falls back to empty instead of
	# hard-erroring a typed assignment or a for-loop mid-load.
	p.tree_points = {}
	var tp := _as_dict(c.get("tree_points", {}))
	for k in tp:
		p.tree_points[k] = _as_int(tp[k], 0)
	var saved_loadouts: Array = _as_arr(c.get("talent_loadouts", []))
	p.load_talent_loadouts(saved_loadouts, int(c.get("active_talent_loadout", 0)))
	var ap := _as_dict(c.get("attr_points", {}))
	for k in p.attr_points:
		p.attr_points[k] = _as_int(ap.get(k, 0), 0)
	p.unspent_attr = int(c.get("unspent_attr", 0))
	p.gold = int(c.get("gold", 0))
	var themes := _as_dict(c.get("ability_theme", {}))
	for k in p.ability_theme:
		p.ability_theme[k] = String(themes.get(k, p.ability_theme[k]))
	p.pending_theme_note = ""
	p.set_chroma(String(c.get("chroma", "")))
	p.set_skin(String(c.get("skin", "")))
	p.resonance = float(c.get("resonance", 0.0))
	var fs := _as_dict(c.get("faction_standing", {}))
	for k in p.faction_standing:
		p.faction_standing[k] = _as_int(fs.get(k, 0), 0)
	p.npc_favor = {}
	var nf := _as_dict(c.get("npc_favor", {}))
	for k in nf:
		p.npc_favor[String(k)] = _as_int(nf[k], 0)

	p.equipment = {}
	var eq := _as_dict(c.get("equipment", {}))
	for slot in eq:
		if eq[slot] is Dictionary:
			p.equipment[slot] = _fix_item(eq[slot])
	p.backpack = []
	for it in _as_arr(c.get("backpack", [])):
		if it is Dictionary:
			p.backpack.append(_fix_item(it))
	p.gem_bag = []
	for g in _as_arr(c.get("gem_bag", [])):
		if g is Dictionary:
			p.gem_bag.append(_fix_gem(g))
	p.bags = load_bags(c)
	# Loose (unequipped) bags round-trip through make_bag so name/slots stay
	# current; an entry with no grade simply drops (no-save-migration rule).
	p.loose_bags = []
	for lb in _as_arr(c.get("loose_bags", [])):
		var lg := String((lb as Dictionary).get("grade", "")) if lb is Dictionary else ""
		if lg != "" and Items.BAG_NAMES.has(lg):
			p.loose_bags.append(Items.make_bag(lg))
	# Graded potions round-trip through make_potion so their effect params /
	# sprite / price stay current; a family/grade/lane that no longer exists
	# simply drops (no-save-migration rule). Stones/scrolls/quest items pass
	# through untouched. The ch1-3 gift flag is preserved (game_world reconciles).
	p.consumables = []
	for rawc in _as_arr(c.get("consumables", [])):
		if not (rawc is Dictionary):
			continue
		var cc: Dictionary = rawc
		if String(cc.get("kind", "")) == "potion":
			var np := Items.make_potion(String(cc.get("family", "")), String(cc.get("shape", "")),
				String(cc.get("grade", "")), String(cc.get("lane", "")))
			if not np.is_empty():
				if bool(cc.get("gift", false)):
					np["gift"] = true
				p.consumables.append(np)
		else:
			p.consumables.append(cc)
	# Materials round-trip: rebuild each stack through make_material so the
	# name/sprite are always current, and any family/grade that no longer
	# exists simply drops (no-save-migration rule — old ids die on load).
	p.materials = []
	for rawm in _as_arr(c.get("materials", [])):
		if not (rawm is Dictionary):
			continue
		var m: Dictionary = rawm
		var fam := String(m.get("family", ""))
		var gr := String(m.get("grade", ""))
		var cnt := int(m.get("count", 1))
		if cnt > 0 and Items.MATERIALS.has(fam) and Items.MATERIALS[fam].has(gr):
			p.materials.append(Items.make_material(fam, gr, cnt))
	p.potion_rotation = _as_arr(c.get("potion_rotation", []))
	p.active_potion = String(c.get("active_potion", "health"))
	p.depths_checkpoint = int(c.get("depths_checkpoint", 0))  # pre-restructure saves: no checkpoint yet
	p.run_tier = clampi(int(c.get("run_tier", 0)), 0, Balance.TIER_NAMES.size() - 1)  # pre-tier saves: Normal
	# Professions (pre-professions saves: no trade — start unlocked, mastery empty).
	p.profession = String(c.get("profession", ""))
	if not Balance.PROFESSION_TRADES.has(p.profession):
		p.profession = ""  # a retired/unknown trade id just dies on load (no-migration rule)
	p.mastery = {}
	var mastery_raw := _as_dict(c.get("mastery", {}))
	for t in mastery_raw:
		if Balance.PROFESSION_TRADES.has(String(t)):
			p.mastery[String(t)] = _as_int(mastery_raw[t], 0)
	p.blueprints = []
	for key in _as_arr(c.get("blueprints", [])):
		if String(key) not in p.blueprints:
			p.blueprints.append(String(key))
	p.swap_cost_step = maxi(0, int(c.get("swap_cost_step", 0)))
	p.swap_week = int(c.get("swap_week", -1))
	# The Alkahest Codex learn-once flag (pre-§9 saves: unlearned, no-migration).
	p.knows_alkahest = bool(c.get("knows_alkahest", false))

	p.recalc()
	p.hp = clampf(_as_float(c.get("hp", p.max_hp), p.max_hp), 1.0, p.max_hp)
	p.mp = clampf(_as_float(c.get("mp", p.max_mp), p.max_mp), 0.0, p.max_mp)

	# Mailbox (round 8). trusted_now() folds the saved anchor in, so the
	# clock stays monotonic across sessions even if the OS clock rolled.
	game.clock_anchor = maxi(game.clock_anchor, int(c.get("clock_anchor", 0)))
	game.daily_last_day = int(c.get("daily_last_day", -1))
	game.daily_streak = int(c.get("daily_streak", 0))
	game.capital_stock = []
	for it in _as_arr(c.get("capital_stock", [])):
		if it is Dictionary:
			game.capital_stock.append(_fix_item(it))
	game.capital_bags = _as_arr(c.get("capital_bags", []))
	game.capital_shop_day = int(c.get("capital_shop_day", -1))
	game.achievements = {}
	for aid in _as_arr(c.get("achievements", [])):
		game.achievements[String(aid)] = true
	game.splashes_seen = {}
	for sp in _as_arr(c.get("splashes_seen", [])):
		game.splashes_seen[String(sp)] = true
	game.convo_log = {}
	var cl := _as_dict(c.get("convo_log", {}))
	for ck in cl:
		var ce := _as_dict(cl[ck])
		var clines: Array = []
		for l in _as_arr(ce.get("lines", [])):
			if l is Array and l.size() >= 2:
				clines.append([String(l[0]), String(l[1])])
		game.convo_log[String(ck)] = {"chapter": String(ce.get("chapter", "")), "lines": clines}
	game.convo_log_order = []
	for ck2 in _as_arr(c.get("convo_log_order", [])):
		if game.convo_log.has(String(ck2)):
			game.convo_log_order.append(String(ck2))
	game.boss_records = {}
	var br := _as_dict(c.get("boss_records", {}))
	for k in br:
		var r := _as_dict(br[k])
		game.boss_records[String(k)] = {
			"ttk": float(r.get("ttk", 0.0)), "dps": float(r.get("dps", 0.0)),
			"kills": int(r.get("kills", 0))}
	game.bounties = []
	for raw in _as_arr(c.get("bounties", [])):
		if not (raw is Dictionary):
			continue
		var b: Dictionary = raw
		game.bounties.append({
			"scope": String(b.get("scope", "daily")), "type": String(b.get("type", "boss_kills")),
			"target": int(b.get("target", 1)), "progress": int(b.get("progress", 0)),
			"desc": String(b.get("desc", "")), "gold": int(b.get("gold", 0)),
			"gems": int(b.get("gems", 0)), "gem_lvl": int(b.get("gem_lvl", 1)),
			"renown": int(b.get("renown", 0)),
			"done": bool(b.get("done", false))})
	game.bounty_day = int(c.get("bounty_day", -1))
	game.bounty_week = int(c.get("bounty_week", -1))
	game.vault_week = int(c.get("vault_week", -1))
	game.vault_progress = int(c.get("vault_progress", 0))
	game.vault_claimed_week = int(c.get("vault_claimed_week", -1))
	game.weekly_claimed_week = int(c.get("weekly_claimed_week", -1))
	game.renown_cache_week = int(c.get("renown_cache_week", -1))
	game.waking_kills_week = int(c.get("waking_kills_week", -1))
	game.waking_kills = []
	for wk in _as_arr(c.get("waking_kills", [])):
		game.waking_kills.append(String(wk))
	game.kill_counts = {}
	var kc := _as_dict(c.get("kill_counts", {}))
	for k in kc:
		game.kill_counts[String(k)] = _as_int(kc[k], 0)
	game.player_title = String(c.get("player_title", ""))
	if game.player_title != "" and not Achievements.TITLES.has(game.player_title):
		game.player_title = ""  # a retired title never wedges a save
	# Mailbox / ground loot: drop any non-dict entry rather than error on it.
	game.mailbox = []
	for mail in _as_arr(c.get("mailbox", [])):
		if mail is Dictionary:
			game.mailbox.append(mail)
	game.dropped_loot = []
	for pl in _as_arr(c.get("dropped_loot", [])):
		if pl is Dictionary:
			game.dropped_loot.append(pl)
	for mail in game.mailbox:
		mail["sent_at"] = int(mail.get("sent_at", 0))
		for pl in _as_arr(mail.get("items", [])):
			if pl is Dictionary:
				_fix_payload(pl)
	for pl in game.dropped_loot:
		_fix_payload(pl)
	game.prune_mail()
	if spawn_ground_loot:
		for pl in game.dropped_loot:
			var pp: Array = _as_arr(pl.get("pos", []))
			var lx := _as_float(pp[0], 0.0) if pp.size() > 0 else 0.0
			var ly := _as_float(pp[1], 0.0) if pp.size() > 1 else 0.0
			Pickup.drop_loot(game, pl, Vector2(lx, ly))


## JSON loads every number as float; re-cast the fields the game
## compares or indexes as ints. Also the stat-doctrine migration
## (2026-07-06): banned stats — movement speed and the gem-only
## specials — are stripped from legacy gear on load (legacy ATK/HP
## mains still count; socketed gems are the sanctioned carrier).
static func _fix_item(it: Dictionary) -> Dictionary:
	it["plus"] = int(it.get("plus", 0))
	it["gem_slots"] = int(it.get("gem_slots", 0))
	for banned in ["speed_pct", "cdr", "lifesteal", "combo", "greed", "crit_dmg", "flat_dr"]:
		it.get("subs", {}).erase(banned)
		it.get("main", {}).erase(banned)
	var gems: Array = it.get("gems", [])
	for i in gems.size():
		gems[i] = _fix_gem(gems[i])
	return it


static func _fix_gem(g: Dictionary) -> Dictionary:
	g["lvl"] = int(g.get("lvl", 1))
	g["gem"] = true
	return g


## Loot payloads ride saves inside mail and ground drops; their inner
## items/gems need the same int re-casts as the bag (JSON -> floats).
static func _fix_payload(pl: Dictionary) -> void:
	if pl.has("item"):
		pl["item"] = _fix_item(pl["item"])
	if pl.has("gem"):
		pl["gem"] = _fix_gem(pl["gem"])
