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
		"merchant_zones": game.merchant_zones,
		# Run stats describe THE RUN (this world's playthrough), not the
		# traveling character — §5.7's take-home list is XP/gold/gems/gear/
		# standings/resonance, so a solo results card never absorbs a co-op
		# session. weekly_active/weekly_week qualify the RUN as this week's
		# challenge (the per-character claim ledger lives above).
		"run_time": game.run_time, "run_deaths": game.run_deaths,
		"run_elites": game.run_elites, "run_secrets": game.run_secrets,
		"weekly_active": game.weekly_active, "weekly_week": game.weekly_week,
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
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## The CHARACTER section (§5.7): everything that travels WITH the player
## between worlds — identity, progression, gear, wallet, records,
## per-player reward faucets. Shared by write() (full save) and
## write_character_home() (guest autosave, MP-08).
static func _character_section(game: Game) -> Dictionary:
	var p := game.player
	return {
		# --- identity / progression ---
		"name": p.char_name,
		"cls": p.cls,
		"level": p.level, "xp": p.xp,
		"skill_points": p.skill_points, "tree_points": p.tree_points,
		"attr_points": p.attr_points, "unspent_attr": p.unspent_attr,
		"gold": p.gold, "potions": p.potions,
		# The expiring ch1-3 teaching potion rides the save WITH its chapter:
		# switch_chapter re-grants on load, then this overwrites (drunk stays
		# drunk; leaving the chapter zeroes it before any save can bank it).
		"potions_free": p.potions_free,
		"ability_theme": p.ability_theme,
		"chroma": p.chroma,
		"skin": p.skin,
		# Standings + resonance are PER-CHARACTER (§5.7): reputation and band
		# lean travel into a friend's world and come home with you.
		"resonance": p.resonance,
		"faction_standing": p.faction_standing,
		# --- gear ---
		"equipment": p.equipment, "backpack": p.backpack, "gem_bag": p.gem_bag,
		"bags": p.bags, "consumables": p.consumables,
		"potion_rotation": p.potion_rotation, "active_potion": p.active_potion,
		# Waking Depths: highest cleared checkpoint depth (re-entry point).
		"depths_checkpoint": p.depths_checkpoint,
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
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


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
		"merchant_zones": game.merchant_zones,
		"run_time": game.run_time, "run_deaths": game.run_deaths,
		"run_elites": game.run_elites, "run_secrets": game.run_secrets,
		# A server world is never the weekly-challenge run (that is a
		# per-player replay mode) — persisted false by construction.
		"weekly_active": false, "weekly_week": -1,
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
	var f := FileAccess.open(SERVER_WORLD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func exists_server_world() -> bool:
	return FileAccess.file_exists(SERVER_WORLD_PATH)


static func read_server_world() -> Dictionary:
	if not FileAccess.file_exists(SERVER_WORLD_PATH):
		return {}
	var f := FileAccess.open(SERVER_WORLD_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## Apply a server world file onto a freshly rebuilt world — the world half
## of apply(), player-free. The caller honors load_save's contract: set
## wander_seed and switch_chapter(chapter, true) BEFORE calling this.
static func apply_server_world(game: Game, data: Dictionary) -> void:
	var w := world_of(data)
	game.clock_anchor = maxi(game.clock_anchor, int(data.get("clock_anchor", 0)))
	game.quest_key = String(w.get("quest_key", "talk"))
	game.talked_to_elder = bool(w.get("talked_to_elder", false))
	game.flags = w.get("flags", {})
	game.run_time = float(w.get("run_time", 0.0))
	game.run_deaths = int(w.get("run_deaths", 0))
	game.run_elites = int(w.get("run_elites", 0))
	game.run_secrets = int(w.get("run_secrets", 0))
	game.boss_done = {}
	for kind in w.get("bosses_slain", []):
		game.boss_done[String(kind)] = true
	for r in w.get("visited_rooms", []):
		game.visited[int(r)] = true
	for r in w.get("cleared_rooms", []):
		game.cleared[int(r)] = true
	for r in w.get("door_seen", []):
		game.door_seen[int(r)] = true
	game.last_safe_room = clampi(int(w.get("last_safe_room", 0)), 0, game.zone_count - 1)
	for z in w.get("merchant_zones", []):
		game._spawn_merchant(int(z))
	# Stand the world at its last safe room: the join snapshot's spawn_room
	# is cur_room, so joiners arrive somewhere pacified.
	game._enter_room(game.last_safe_room)
	game.reconcile_after_load()


## Reads always return the v3 shape: legacy flat blobs are lifted in
## memory here (the file on disk stays as-is until the next autosave).
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return _migrate_v2(data) if data is Dictionary else {}


## Section accessors — the seam §5.7 builds on. Code outside save.gd
## reaches into a save dict through these, never by raw key.
static func character_of(data: Dictionary) -> Dictionary:
	var c: Dictionary = data.get("character", {})
	return c


static func world_of(data: Dictionary) -> Dictionary:
	var w: Dictionary = data.get("world", {})
	return w


# Where each v2 flat field lands in v3. "bag" is the round-52 legacy
# single-bag key (pre-`bags` saves) — routed so load_bags still sees it.
const _V2_CHARACTER_FIELDS := ["name", "cls", "level", "xp", "skill_points", "tree_points",
	"attr_points", "unspent_attr", "gold", "potions", "potions_free", "ability_theme", "chroma", "skin",
	"resonance", "faction_standing", "equipment", "backpack", "gem_bag", "bags", "bag",
	"consumables", "potion_rotation", "active_potion", "depths_checkpoint", "hp", "mp",
	"mailbox", "dropped_loot", "clock_anchor", "daily_last_day", "daily_streak",
	"achievements", "boss_records", "kill_counts", "player_title",
	"bounties", "bounty_day", "bounty_week",
	"vault_week", "vault_progress", "vault_claimed_week", "weekly_claimed_week"]
const _V2_WORLD_FIELDS := ["quest_key", "talked_to_elder", "flags", "merchant_zones",
	"run_time", "run_deaths", "run_elites", "run_secrets",
	"weekly_active", "weekly_week", "bosses_slain", "pos",
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
	if exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))


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
			"level": int(c.get("level", 1)),
			"quest": String(world_of(d).get("quest_key", "talk")),
			"saved_at": int(d.get("saved_at", 0)),
		})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


static func next_free_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		if not exists(slot):
			return slot
	return MAX_SLOTS  # all full: reuse the last slot


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
	var bags_raw: Array = data.get("bags", [])
	if not bags_raw.is_empty():
		for bd in bags_raw:
			var b: Dictionary = bd
			b["slots"] = int(Items.BAG_SLOTS.get(String(b.get("grade", "F")), b.get("slots", 0)))
			out.append(b)
		return out
	var old_bag: Dictionary = data.get("bag", {})  # legacy single-bag save
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
	game.flags = w.get("flags", {})
	# Run stats ride the save so the results card spans sessions. They are
	# WORLD state (this run's card); only the weekly CLAIM ledger is the
	# character's (see write()).
	game.run_time = float(w.get("run_time", 0.0))
	game.run_deaths = int(w.get("run_deaths", 0))
	game.run_elites = int(w.get("run_elites", 0))
	game.run_secrets = int(w.get("run_secrets", 0))
	game.weekly_active = bool(w.get("weekly_active", false))
	game.weekly_week = int(w.get("weekly_week", -1))
	game.boss_done = {}
	for kind in w.get("bosses_slain", []):
		game.boss_done[String(kind)] = true
	game.wander_seed = int(w.get("wander_seed", 0))

	# --- room state (v2+). Pre-graph saves (v1) keep the character and
	# the story, but restart the chapter's GEOGRAPHY from its first room
	# — their positions were authored for a world that no longer exists.
	# (Post-migration every dict says version 3, so v1 is detected by the
	# absence of the room graph itself.)
	if w.has("visited_rooms"):
		for r in w.get("visited_rooms", []):
			game.visited[int(r)] = true
		for r in w.get("cleared_rooms", []):
			game.cleared[int(r)] = true
		for r in w.get("door_seen", []):
			game.door_seen[int(r)] = true
		game.last_safe_room = clampi(int(w.get("last_safe_room", 0)), 0, game.zone_count - 1)
		# Wandering merchants that had arrived come back (nodes appear
		# when their room builds).
		for z in w.get("merchant_zones", []):
			game._spawn_merchant(int(z))
		var cur: int = clampi(int(w.get("cur_room", 0)), 0, game.zone_count - 1)
		var pos: Array = w.get("pos", [400.0, 360.0])
		var anchor: Vector2 = game.room_center(cur)
		game._enter_room(cur)
		p.global_position = game.clamp_to_zone(Vector2(float(pos[0]), float(pos[1])), anchor)
	else:
		for z in w.get("merchant_zones", []):
			game._spawn_merchant(int(z))
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
	p.level = int(c.get("level", 1))
	p.set_class(String(c.get("cls", "warrior")))
	p.xp = int(c.get("xp", 0))
	p.skill_points = int(c.get("skill_points", 0))
	p.tree_points = {}
	var tp: Dictionary = c.get("tree_points", {})
	for k in tp:
		p.tree_points[k] = int(tp[k])
	var ap: Dictionary = c.get("attr_points", {})
	for k in p.attr_points:
		p.attr_points[k] = int(ap.get(k, 0))
	p.unspent_attr = int(c.get("unspent_attr", 0))
	p.gold = int(c.get("gold", 0))
	p.potions = int(c.get("potions", 0))
	p.potions_free = int(c.get("potions_free", 0))
	var themes: Dictionary = c.get("ability_theme", {})
	for k in p.ability_theme:
		p.ability_theme[k] = String(themes.get(k, p.ability_theme[k]))
	p.pending_theme_note = ""
	p.set_chroma(String(c.get("chroma", "")))
	p.set_skin(String(c.get("skin", "")))
	p.resonance = float(c.get("resonance", 0.0))
	var fs: Dictionary = c.get("faction_standing", {})
	for k in p.faction_standing:
		p.faction_standing[k] = int(fs.get(k, 0))

	p.equipment = {}
	var eq: Dictionary = c.get("equipment", {})
	for slot in eq:
		p.equipment[slot] = _fix_item(eq[slot])
	p.backpack = []
	for it in c.get("backpack", []):
		p.backpack.append(_fix_item(it))
	p.gem_bag = []
	for g in c.get("gem_bag", []):
		p.gem_bag.append(_fix_gem(g))
	p.bags = load_bags(c)
	p.consumables = c.get("consumables", [])
	p.potion_rotation = c.get("potion_rotation", [])
	p.active_potion = String(c.get("active_potion", "health"))
	p.depths_checkpoint = int(c.get("depths_checkpoint", 0))  # pre-restructure saves: no checkpoint yet

	p.recalc()
	p.hp = clampf(float(c.get("hp", p.max_hp)), 1.0, p.max_hp)
	p.mp = clampf(float(c.get("mp", p.max_mp)), 0.0, p.max_mp)

	# Mailbox (round 8). trusted_now() folds the saved anchor in, so the
	# clock stays monotonic across sessions even if the OS clock rolled.
	game.clock_anchor = maxi(game.clock_anchor, int(c.get("clock_anchor", 0)))
	game.daily_last_day = int(c.get("daily_last_day", -1))
	game.daily_streak = int(c.get("daily_streak", 0))
	game.achievements = {}
	for aid in c.get("achievements", []):
		game.achievements[String(aid)] = true
	game.splashes_seen = {}
	for sp in c.get("splashes_seen", []):
		game.splashes_seen[String(sp)] = true
	game.convo_log = {}
	var cl: Dictionary = c.get("convo_log", {})
	for ck in cl:
		var ce: Dictionary = cl[ck]
		var clines: Array = []
		for l in ce.get("lines", []):
			if l is Array and l.size() >= 2:
				clines.append([String(l[0]), String(l[1])])
		game.convo_log[String(ck)] = {"chapter": String(ce.get("chapter", "")), "lines": clines}
	game.convo_log_order = []
	for ck2 in c.get("convo_log_order", []):
		if game.convo_log.has(String(ck2)):
			game.convo_log_order.append(String(ck2))
	game.boss_records = {}
	var br: Dictionary = c.get("boss_records", {})
	for k in br:
		var r: Dictionary = br[k]
		game.boss_records[String(k)] = {
			"ttk": float(r.get("ttk", 0.0)), "dps": float(r.get("dps", 0.0)),
			"kills": int(r.get("kills", 0))}
	game.bounties = []
	for raw in c.get("bounties", []):
		var b: Dictionary = raw
		game.bounties.append({
			"scope": String(b.get("scope", "daily")), "type": String(b.get("type", "boss_kills")),
			"target": int(b.get("target", 1)), "progress": int(b.get("progress", 0)),
			"desc": String(b.get("desc", "")), "gold": int(b.get("gold", 0)),
			"gems": int(b.get("gems", 0)), "gem_lvl": int(b.get("gem_lvl", 1)),
			"done": bool(b.get("done", false))})
	game.bounty_day = int(c.get("bounty_day", -1))
	game.bounty_week = int(c.get("bounty_week", -1))
	game.vault_week = int(c.get("vault_week", -1))
	game.vault_progress = int(c.get("vault_progress", 0))
	game.vault_claimed_week = int(c.get("vault_claimed_week", -1))
	game.weekly_claimed_week = int(c.get("weekly_claimed_week", -1))
	game.kill_counts = {}
	var kc: Dictionary = c.get("kill_counts", {})
	for k in kc:
		game.kill_counts[String(k)] = int(kc[k])
	game.player_title = String(c.get("player_title", ""))
	if game.player_title != "" and not Achievements.TITLES.has(game.player_title):
		game.player_title = ""  # a retired title never wedges a save
	game.mailbox = c.get("mailbox", [])
	game.dropped_loot = c.get("dropped_loot", [])
	for mail in game.mailbox:
		mail["sent_at"] = int(mail.get("sent_at", 0))
		for pl in mail.get("items", []):
			_fix_payload(pl)
	for pl in game.dropped_loot:
		_fix_payload(pl)
	game.prune_mail()
	if spawn_ground_loot:
		for pl in game.dropped_loot:
			var pp: Array = pl.get("pos", [0, 0])
			Pickup.drop_loot(game, pl, Vector2(float(pp[0]), float(pp[1])))


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
