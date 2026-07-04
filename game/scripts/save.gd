class_name SaveGame
## Save / load: one JSON file per character at user://save_<slot>.json.
## The game autosaves on story progress, zone changes and menu closes
## (see Game.autosave); there is no manual save button by design.
##
## Everything stored is already JSON-safe (items and gems are plain
## Dictionaries of strings/numbers). JSON turns ints into floats, so
## every read casts explicitly — never trust a loaded number's type.

const VERSION := 1
const MAX_SLOTS := 6


static func path(slot: int) -> String:
	return "user://save_%d.json" % slot


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


static func write(game: Game, slot: int) -> void:
	var p := game.player
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		# --- identity / progression ---
		"chapter": game.chapter_id,
		"cls": p.cls,
		"level": p.level, "xp": p.xp,
		"skill_points": p.skill_points, "tree_points": p.tree_points,
		"attr_points": p.attr_points, "unspent_attr": p.unspent_attr,
		"gold": p.gold, "potions": p.potions,
		"ability_theme": p.ability_theme,
		# --- Phase 1 story trackers (saved from day one) ---
		"resonance": p.resonance,
		"faction_standing": p.faction_standing,
		# --- gear ---
		"equipment": p.equipment, "backpack": p.backpack, "gem_bag": p.gem_bag,
		# --- vitals / place ---
		"hp": p.hp, "mp": p.mp,
		"pos": [p.global_position.x, p.global_position.y],
		# --- world / story ---
		"quest_key": game.quest_key,
		"talked_to_elder": game.talked_to_elder,
		"bosses_slain": game.boss_done.keys(),
		"flags": game.flags,
		"merchant_zones": game.merchant_zones,
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


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
		out.append({
			"slot": slot,
			"cls": String(d.get("cls", "warrior")),
			"level": int(d.get("level", 1)),
			"quest": String(d.get("quest_key", "talk")),
			"saved_at": int(d.get("saved_at", 0)),
		})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


static func next_free_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		if not exists(slot):
			return slot
	return MAX_SLOTS  # all full: reuse the last slot


## Restore a save onto a freshly built world. Order matters: level first
## (set_class derives theme unlocks from it), then class, then the
## overrides, then recalc, then the world reconciles.
static func apply(game: Game, data: Dictionary) -> void:
	var p := game.player
	p.level = int(data.get("level", 1))
	p.set_class(String(data.get("cls", "warrior")))
	p.xp = int(data.get("xp", 0))
	p.skill_points = int(data.get("skill_points", 0))
	p.tree_points = {}
	var tp: Dictionary = data.get("tree_points", {})
	for k in tp:
		p.tree_points[k] = int(tp[k])
	var ap: Dictionary = data.get("attr_points", {})
	for k in p.attr_points:
		p.attr_points[k] = int(ap.get(k, 0))
	p.unspent_attr = int(data.get("unspent_attr", 0))
	p.gold = int(data.get("gold", 0))
	p.potions = int(data.get("potions", 0))
	var themes: Dictionary = data.get("ability_theme", {})
	for k in p.ability_theme:
		p.ability_theme[k] = String(themes.get(k, p.ability_theme[k]))
	p.pending_theme_note = ""
	p.resonance = float(data.get("resonance", 0.0))
	var fs: Dictionary = data.get("faction_standing", {})
	for k in p.faction_standing:
		p.faction_standing[k] = int(fs.get(k, 0))

	p.equipment = {}
	var eq: Dictionary = data.get("equipment", {})
	for slot in eq:
		p.equipment[slot] = _fix_item(eq[slot])
	p.backpack = []
	for it in data.get("backpack", []):
		p.backpack.append(_fix_item(it))
	p.gem_bag = []
	for g in data.get("gem_bag", []):
		p.gem_bag.append(_fix_gem(g))

	p.recalc()
	p.hp = clampf(float(data.get("hp", p.max_hp)), 1.0, p.max_hp)
	p.mp = clampf(float(data.get("mp", p.max_mp)), 0.0, p.max_mp)
	var pos: Array = data.get("pos", [400.0, 360.0])
	var v := Vector2(float(pos[0]), float(pos[1]))
	p.global_position = game.clamp_to_zone(v, v)

	game.quest_key = String(data.get("quest_key", "talk"))
	game.talked_to_elder = bool(data.get("talked_to_elder", false))
	game.flags = data.get("flags", {})
	game.boss_done = {}
	for kind in data.get("bosses_slain", []):
		game.boss_done[String(kind)] = true
	# Wandering merchants that had arrived come back (village merchant
	# already exists from the world build — the spawn guard skips it).
	for z in data.get("merchant_zones", []):
		game._spawn_merchant(int(z))
	game.reconcile_after_load()


## JSON loads every number as float; re-cast the fields the game
## compares or indexes as ints.
static func _fix_item(it: Dictionary) -> Dictionary:
	it["plus"] = int(it.get("plus", 0))
	it["gem_slots"] = int(it.get("gem_slots", 0))
	var gems: Array = it.get("gems", [])
	for i in gems.size():
		gems[i] = _fix_gem(gems[i])
	return it


static func _fix_gem(g: Dictionary) -> Dictionary:
	g["lvl"] = int(g.get("lvl", 1))
	g["gem"] = true
	return g
