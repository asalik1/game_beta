extends RefCounted
## Earned shortcut gates (DESIGN.md "zone graph": branches/loops are allowed;
## _generate_layout builds a tree). AFTER a chapter's seeded graph is FULLY
## written, at most one physically-adjacent room pair with no edge may gain a
## flag-locked passage: the player walks the ordinary long way to its far
## side, pacifies that room, and works the latch (shortcut_latch.gd).
## Selection is a PURE FUNCTION of the finished graph — no RNG object, no
## seed consumption, no reshuffle when nothing qualifies — so every machine
## and every reload of the same wander_seed agrees, and the original rooms,
## exits and locks are never altered here (game_world._install_shortcut does
## the one write, through the existing edge-lock machinery).

const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1),
	"E": Vector2i(1, 0), "W": Vector2i(-1, 0)}


## Chapter 1 campaign layouts, including weekly Chapter 1: never endgame,
## standalone, or PvP worlds (none are in CHAPTER_LIST), and never the legacy
## authored strips — a chapter qualifies only through its procedural spine.
static func eligible(g) -> bool:
	return Balance.SHORTCUT_CHAPTERS.has(g.chapter_id) \
		and Story.CHAPTER_LIST.has(g.chapter_id) \
		and not Story.chapter(g.chapter_id).get("spine", []).is_empty()


## A room that may anchor a shortcut: placed with real edges (floating Q15
## pockets and the unplaced-room parking backstop both carry EMPTY exits),
## not a boss arena, not an injected special room (waking breach / unlisted).
static func valid_room(g, i: int) -> bool:
	if i < 0 or i >= g.rooms.size() or i >= g.zones.size():
		return false
	if (g.rooms[i]["exits"] as Dictionary).is_empty():
		return false
	var zone: Dictionary = g.zones[i]
	if String(zone.get("pocket", "")) != "" or String(zone.get("waking", "")) != "" \
			or String(zone.get("unlisted", "")) != "":
		return false
	return String(zone.get("boss", "")) == "" and g.room_type(i) != "boss"


## Adapter: read the live graph into plain data, then rank. Read-only.
static func select(g) -> Dictionary:
	if not eligible(g):
		return {}
	var coords := {}
	var exits := {}
	var valid := {}
	for i in g.zone_count:
		coords[i] = Vector2i(g.rooms[i]["coord"])
		exits[i] = (g.rooms[i]["exits"] as Dictionary).keys()
		valid[i] = valid_room(g, i)
	var locked := {}
	for key in g.edge_locks:
		locked[String(key)] = true
	var spine := {}
	for v in Story.chapter(g.chapter_id).get("spine", []):
		spine[int(v)] = true
	return select_graph(coords, exits, locked, spine, valid)


## Pure ranking over a plain graph description (QA feeds mutated copies in as
## negative controls). Returns {} or {"a","b","far","dist"}: `far` is the
## latch side — the DEEPER endpoint by BFS depth from the chapter start
## (room 0, _start_pos) on the ORIGINAL graph; a depth tie breaks to the
## HIGHER room index. That is the documented far-side convention.
## Contract enforced here:
##  - endpoints physically adjacent on the grid, NO existing edge between them;
##  - both endpoints valid (see valid_room via `valid`), reachable from start;
##  - never spine-to-spine (at least one side room);
##  - endpoints in the SAME component once EVERY locked edge is removed
##    (satisfied or not) — a shortcut never bypasses a story/boss/clear lock;
##  - original walk between them >= Balance.SHORTCUT_MIN_WALK edges;
##  - deterministic ranking: greatest saved walk, then lowest (a, b).
static func select_graph(coords: Dictionary, exits: Dictionary, locked: Dictionary,
		spine: Dictionary, valid: Dictionary) -> Dictionary:
	var coord_to := {}
	for i in coords:
		coord_to[coords[i]] = int(i)
	# The original adjacency (locks included: they open in ordinary play) and
	# the lock-CUT adjacency (every authored locked edge removed).
	var adj := {}
	var adj_cut := {}
	for i in coords:
		adj[int(i)] = []
		adj_cut[int(i)] = []
	for i in coords:
		for d in exits[i]:
			var nb_v: Variant = coord_to.get(Vector2i(coords[i]) + Vector2i(DIRS[String(d)]), null)
			if nb_v == null:
				continue
			var nb := int(nb_v)
			(adj[int(i)] as Array).append(nb)
			if not locked.has(_key(int(i), nb)):
				(adj_cut[int(i)] as Array).append(nb)
	var depth := _bfs(adj, 0)
	var comp := _components(adj_cut)
	var best := {}
	for i in coords:
		var a := int(i)
		if not bool(valid.get(a, false)) or not depth.has(a):
			continue
		for d in ["E", "S"]:   # scan each unordered pair exactly once
			var nb_v: Variant = coord_to.get(Vector2i(coords[a]) + Vector2i(DIRS[d]), null)
			if nb_v == null:
				continue
			var b := int(nb_v)
			if not bool(valid.get(b, false)) or not depth.has(b):
				continue
			if (adj[a] as Array).has(b):
				continue   # an edge already exists here
			if spine.has(a) and spine.has(b):
				continue   # never a pure spine bypass
			if int(comp.get(a, -1)) != int(comp.get(b, -2)):
				continue   # joining them would cross an authored lock
			var dist := _pair_dist(adj, a, b)
			if dist < Balance.SHORTCUT_MIN_WALK:
				continue   # no real walking saved
			var cand := {"a": a, "b": b, "dist": dist}
			if best.is_empty() or _better(cand, best):
				best = cand
	if best.is_empty():
		return {}
	var a2 := int(best["a"])
	var b2 := int(best["b"])
	var da := int(depth[a2])
	var db := int(depth[b2])
	best["far"] = b2 if db > da or (db == da and b2 > a2) else a2
	return best


## Run-scoped WORLD flag: saves reload it with the same seeded world; the
## replay flag wipe closes the passage again. Deliberately NOT a
## CharacterHistory KEPT prefix (`opened_` is kept personal history — using
## it would colonize guest home saves and survive replay), and NOT
## cache_/hidden_/shrined_ local, so co-op routes it through the host.
static func flag_name(chapter: String, a: int, b: int) -> String:
	return "shortcut_%s_%d_%d" % [chapter, mini(a, b), maxi(a, b)]


static func _key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]


static func _better(cand: Dictionary, best: Dictionary) -> bool:
	if int(cand["dist"]) != int(best["dist"]):
		return int(cand["dist"]) > int(best["dist"])
	if int(cand["a"]) != int(best["a"]):
		return int(cand["a"]) < int(best["a"])
	return int(cand["b"]) < int(best["b"])


static func _bfs(adj: Dictionary, start: int) -> Dictionary:
	var depth := {start: 0}
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		for nb in adj.get(at, []):
			if not depth.has(int(nb)):
				depth[int(nb)] = int(depth[at]) + 1
				queue.append(int(nb))
	return depth


static func _pair_dist(adj: Dictionary, a: int, b: int) -> int:
	var d := _bfs(adj, a)
	return int(d.get(b, 1 << 30))


static func _components(adj: Dictionary) -> Dictionary:
	var comp := {}
	var next := 0
	for i in adj:
		if comp.has(int(i)):
			continue
		var queue: Array[int] = [int(i)]
		comp[int(i)] = next
		var cursor := 0
		while cursor < queue.size():
			var at := queue[cursor]
			cursor += 1
			for nb in adj[at]:
				if not comp.has(int(nb)):
					comp[int(nb)] = next
					queue.append(int(nb))
		next += 1
	return comp
