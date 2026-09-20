extends RefCounted
## QA-only domain oracle + candidate census for earned shortcut gates.
## Driven by `shot.bat wayfinder -- --shortcut-domain` (see PATCHES.md): the
## branch runs BEFORE boot, so no world, scene or save is ever touched — every
## graph comes from a disposable, unattached Game.new() pushed through the
## REAL generator (game_world._prepare_rooms) and the REAL installer
## (game_world._install_shortcut). No Python RNG mirror, no generator clone,
## no 200 world boots, no mutation of any shared suite Game.
##
## Frequency policy: observed counts are RECORDED in the receipt for the root
## to judge; a seed rolling no candidate is legal and is never asserted
## against a threshold. Each seed's checks close over that seed only (the raw
## candidate's held-last-candidate/used-last-seed mismatch cannot recur).
##
## Requires the reviewed production lane (scripts/shortcut_gate.gd + the
## Game.shortcut_edge/_install_shortcut hook). Absent lane = a clear failure
## line and finish(1), never a pretended pass.

const GATE_PATH := "res://scripts/shortcut_gate.gd"
const CHAPTER := "ch1"
const SEED_BASE := 1000       # census window SEED_BASE..SEED_BASE+SEED_COUNT-1 (disclosed, deterministic)
const SEED_COUNT := 200
const MIN_WALK := 3           # contract literal: original distance >= 3 (no QA Balance knob)
const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}


static func run(rig) -> void:
	var receipt := {
		"rig": "wayfinder --shortcut-domain", "chapter": CHAPTER,
		"seed_base": SEED_BASE, "seed_count": SEED_COUNT,
		"expected_conditions": [
			"shortcut_edge is {} or {a,b,far,flag,dist}",
			"selection is pure and deterministic (double select, zero graph mutation)",
			"install adds exactly one reciprocal exit pair + one flag lock on that edge",
			"original coords/scale/origin/exits/locks stay value-identical after install",
			"endpoints grid-adjacent, not originally linked, valid non-boss/non-special rooms",
			"at least one endpoint off the spine",
			"original BFS distance >= %d (independent BFS, not the selector's)" % MIN_WALK,
			"endpoints share a component with ALL authored locked edges removed",
			"far = deeper endpoint by original BFS from room 0",
			"re-running the original generator on the same seed reproduces the baseline",
			"a fresh install on the same seed chooses the same edge",
		],
		"checks": 0, "failures": [], "omissions": [], "seed_results": [],
		"candidate_seeds": 0, "empty_seeds": 0,
		"candidates": {}, "dist_histogram": {},
	}
	var failures: Array = receipt["failures"]
	if not ResourceLoader.exists(GATE_PATH):
		failures.append("production lane absent: %s not found (compile the reviewed production first)" % GATE_PATH)
	else:
		var probe := Game.new()
		var lane_ok: bool = ("shortcut_edge" in probe) and probe.has_method("_install_shortcut")
		probe.free()
		if not lane_ok:
			failures.append("production lane absent: Game.shortcut_edge/_install_shortcut missing (compile the reviewed production first)")
		else:
			_census(receipt)
			_synthetic_controls(receipt)
	_save(rig, receipt)
	print("SHORTCUT DOMAIN: %d checks, %d failures, %d/%d seeds rolled a candidate" % [
		int(receipt["checks"]), failures.size(), int(receipt["candidate_seeds"]), SEED_COUNT])
	for f in failures:
		push_error("shortcut-domain: " + String(f))
	rig.finish(1 if not failures.is_empty() else 0)


## An unattached graph fixture through the ACTUAL source. Weekly rewards and
## Waking Incursions are different systems: weekly_active does not alter this
## topology rule. This census covers fresh, non-Waking Chapter 1 layouts;
## explicit weekly mode equality is checked per seed. Waking-replay coverage
## still needs a separately disclosed fixture, not a false weekly exclusion.
static func _fixture(seed_v: int, install: bool) -> Game:
	var g := Game.new()
	g.chapter_id = CHAPTER
	g.wander_seed = seed_v
	var zones: Array = (Story.chapter(CHAPTER)["zones"] as Array).duplicate(true)
	if g.has_method("_unlisted_inject"):
		zones = g._unlisted_inject(zones, CHAPTER)
	if g.has_method("_pocket_inject"):
		zones = g._pocket_inject(zones, CHAPTER)
	g.zones = zones
	g.zone_count = zones.size()
	g.terrain_by_zone.clear()
	for zone in g.zones:
		g.terrain_by_zone.append((zone as Dictionary).get("terrain", "village"))
	g._prepare_rooms()
	if install:
		g._install_shortcut()
	return g


static func _census(receipt: Dictionary) -> void:
	var failures: Array = receipt["failures"]
	for k in SEED_COUNT:
		var seed_v: int = SEED_BASE + k
		var g: Game = _fixture(seed_v, false)
		var err: String = _seed_checks(g, seed_v, receipt)
		g.free()  # unattached Node2D: free explicitly, on the failure path too
		if err != "":
			failures.append(err)
			if failures.size() >= 10:
				failures.append("census aborted after 10 failures (seeds %d..%d unexamined)" % [seed_v + 1, SEED_BASE + SEED_COUNT - 1])
				return


static func _seed_checks(g: Game, seed_v: int, receipt: Dictionary) -> String:
	receipt["checks"] = int(receipt["checks"]) + 1
	var gate: GDScript = load(GATE_PATH)
	var base := _snapshot(g)
	# Pure selection: the same answer twice, zero graph mutation.
	var pick1: Dictionary = gate.select(g)
	var pick2: Dictionary = gate.select(g)
	g.weekly_active = true
	var weekly_pick: Dictionary = gate.select(g)
	g.weekly_active = false
	if weekly_pick != pick1:
		return "seed %d: weekly mode changed the shortcut selection" % seed_v
	if pick1 != pick2:
		return "seed %d: select(g) is not deterministic" % seed_v
	if _snapshot(g) != base:
		return "seed %d: select(g) mutated the graph" % seed_v
	if not (g.shortcut_edge as Dictionary).is_empty():
		return "seed %d: the generator installed a shortcut before _install_shortcut" % seed_v
	g._install_shortcut()
	var edge: Dictionary = (g.shortcut_edge as Dictionary).duplicate(true)
	(receipt["seed_results"] as Array).append({"seed": seed_v, "edge": edge,
		"rooms": g.zone_count, "original_locks": (base["locks"] as Dictionary).size()})
	if edge.is_empty() != pick1.is_empty():
		return "seed %d: installer discarded or invented the selected edge" % seed_v
	if not edge.is_empty():
		for field in ["a", "b", "far", "dist"]:
			if edge.get(field) != pick1.get(field):
				return "seed %d: installer changed selected %s" % [seed_v, field]
	var err := _check_install(base, g, edge, seed_v)
	if err != "":
		return err
	# Fingerprint: a FRESH generator run on the same seed reproduces the
	# baseline by exact graph values, and a fresh install lands on the same edge.
	var g2: Game = _fixture(seed_v, false)
	var replay_same: bool = _snapshot(g2) == base
	g2._install_shortcut()
	var edge_same: bool = g2.shortcut_edge == edge
	g2.free()
	if not replay_same:
		return "seed %d: re-running the original generator drifted the baseline" % seed_v
	if not edge_same:
		return "seed %d: a fresh install chose a different shortcut" % seed_v
	# Census record — counts only, no threshold assert.
	if edge.is_empty():
		receipt["empty_seeds"] = int(receipt["empty_seeds"]) + 1
	else:
		receipt["candidate_seeds"] = int(receipt["candidate_seeds"]) + 1
		var pair_key := "%d-%d" % [int(edge["a"]), int(edge["b"])]
		var cands: Dictionary = receipt["candidates"]
		cands[pair_key] = int(cands.get(pair_key, 0)) + 1
		var hist: Dictionary = receipt["dist_histogram"]
		var dist_key := str(int(edge["dist"]))
		hist[dist_key] = int(hist.get(dist_key, 0)) + 1
	return ""


static func _snapshot(g: Game) -> Dictionary:
	var rooms := {}
	for i in g.zone_count:
		var meta: Dictionary = g.rooms[i]
		rooms[i] = {"coord": Vector2i(meta["coord"]), "scale": Vector2(meta["scale"]),
			"origin": Vector2(meta["origin"]), "exits": (meta["exits"] as Dictionary).duplicate(true)}
	return {"rooms": rooms, "coord_map": g.coord_to_room.duplicate(true),
		"locks": g.edge_locks.duplicate(true)}


static func _check_install(base: Dictionary, g: Game, edge: Dictionary, seed_v: int) -> String:
	var after := _snapshot(g)
	if after["coord_map"] != base["coord_map"]:
		return "seed %d: install changed the coord map" % seed_v
	if edge.is_empty():
		if after != base:
			return "seed %d: no shortcut recorded but the graph changed" % seed_v
		return ""
	for field in ["a", "b", "far", "flag", "dist"]:
		if not edge.has(field):
			return "seed %d: shortcut_edge is missing '%s'" % [seed_v, field]
	var a := int(edge["a"])
	var b := int(edge["b"])
	# Every original coord/scale/origin/exit/lock value-identical; the only
	# growth is one reciprocal exit pair on a/b plus one lock on that edge.
	var added: Array = []
	for i in (base["rooms"] as Dictionary):
		var br: Dictionary = base["rooms"][i]
		var ar: Dictionary = after["rooms"][i]
		for field in ["coord", "scale", "origin"]:
			if ar[field] != br[field]:
				return "seed %d: room %s %s drifted on install" % [seed_v, str(i), field]
		for d in (br["exits"] as Dictionary):
			if not (ar["exits"] as Dictionary).has(d) or ar["exits"][d] != br["exits"][d]:
				return "seed %d: original exit %s/%s changed" % [seed_v, str(i), String(d)]
		for d in (ar["exits"] as Dictionary):
			if not (br["exits"] as Dictionary).has(d):
				added.append(int(i))
	if added.size() != 2 or not added.has(a) or not added.has(b):
		return "seed %d: expected one reciprocal exit pair on %d/%d, saw new exits on %s" % [seed_v, a, b, str(added)]
	# Verify removals as well as edits/additions: iterating only AFTER keys
	# would miss an accidentally deleted original story lock.
	for lk in (base["locks"] as Dictionary):
		if not (after["locks"] as Dictionary).has(lk) or after["locks"][lk] != base["locks"][lk]:
			return "seed %d: original edge lock %s was removed or changed" % [seed_v, String(lk)]
	for endpoint in [a, b]:
		var other: int = b if endpoint == a else a
		for d in after["rooms"][endpoint]["exits"]:
			if base["rooms"][endpoint]["exits"].has(d):
				continue
			if g.neighbor(endpoint, String(d)) != other or after["rooms"][endpoint]["exits"][d] != "":
				return "seed %d: new endpoint exit does not lead to its paired endpoint" % seed_v
	var new_locks: Array = []
	for lk in (after["locks"] as Dictionary):
		if not (base["locks"] as Dictionary).has(lk):
			new_locks.append(String(lk))
		elif after["locks"][lk] != base["locks"][lk]:
			return "seed %d: original edge lock %s changed" % [seed_v, String(lk)]
	var edge_key := String(g._edge_key(a, b))
	if new_locks.size() != 1 or new_locks[0] != edge_key:
		return "seed %d: expected exactly the shortcut lock %s, saw %s" % [seed_v, edge_key, str(new_locks)]
	var flag_name := String(edge["flag"])
	if not flag_name.begins_with("shortcut_"):
		return "seed %d: flag '%s' is outside the shortcut_ namespace" % [seed_v, flag_name]
	var lock_entry: Dictionary = (after["locks"] as Dictionary)[edge_key]
	if String(lock_entry.get("lock", "")) != "flag:" + flag_name:
		return "seed %d: shortcut lock is '%s', not 'flag:%s'" % [seed_v, String(lock_entry.get("lock", "")), flag_name]
	# Contract predicates, all through an INDEPENDENT BFS over the baseline.
	var ca: Vector2i = Vector2i((base["rooms"] as Dictionary)[a]["coord"])
	var cb: Vector2i = Vector2i((base["rooms"] as Dictionary)[b]["coord"])
	if absi(ca.x - cb.x) + absi(ca.y - cb.y) != 1:
		return "seed %d: endpoints %d/%d are not grid-adjacent" % [seed_v, a, b]
	var adj := _adjacency(g, base, false)
	if (adj[a] as Array).has(b):
		return "seed %d: an original edge already linked %d/%d" % [seed_v, a, b]
	var depth := _bfs(adj, 0)
	if not depth.has(a) or not depth.has(b):
		return "seed %d: a shortcut endpoint is unreachable from room 0" % seed_v
	var dist_ab := int((_bfs(adj, a) as Dictionary).get(b, 1 << 30))
	if dist_ab < MIN_WALK:
		return "seed %d: original distance %d is under %d" % [seed_v, dist_ab, MIN_WALK]
	if int(edge["dist"]) != dist_ab:
		return "seed %d: recorded dist %d disagrees with independent BFS %d" % [seed_v, int(edge["dist"]), dist_ab]
	var cut := _adjacency(g, base, true)
	if int((_bfs(cut, a) as Dictionary).get(b, -1)) < 0:
		return "seed %d: endpoints split once authored locked edges are removed" % seed_v
	var spine: Array = Story.chapter(CHAPTER).get("spine", [])
	if spine.has(a) and spine.has(b):
		return "seed %d: both endpoints sit on the spine" % seed_v
	var far := int(edge["far"])
	if far != a and far != b:
		return "seed %d: far=%d is not an endpoint" % [seed_v, far]
	var da := int(depth[a])
	var db := int(depth[b])
	if far != (a if da > db else (b if db > da else maxi(a, b))):
		return "seed %d: far=%d is not the deeper endpoint (depths %d/%d)" % [seed_v, far, da, db]
	# Endpoint validity straight off the actual zone data (adapter-independent).
	for r in [a, b]:
		var zone: Dictionary = g.zones[int(r)]
		if ((base["rooms"] as Dictionary)[int(r)]["exits"] as Dictionary).is_empty():
			return "seed %d: endpoint %d had no original exits" % [seed_v, int(r)]
		if String(zone.get("boss", "")) != "":
			return "seed %d: endpoint %d is a boss room" % [seed_v, int(r)]
		if String(zone.get("pocket", "")) != "" or String(zone.get("waking", "")) != "" \
				or String(zone.get("unlisted", "")) != "":
			return "seed %d: endpoint %d is a pocket/waking/unlisted room" % [seed_v, int(r)]
	return ""


## Baseline adjacency by coords+exits; cut_locked removes every edge whose
## key sits in the baseline lock table (the authored locks — the shortcut's
## own lock is never in the BASELINE table).
static func _adjacency(g: Game, base: Dictionary, cut_locked: bool) -> Dictionary:
	var coord_of := {}
	for i in (base["rooms"] as Dictionary):
		coord_of[Vector2i(base["rooms"][i]["coord"])] = int(i)
	var adj := {}
	for i in (base["rooms"] as Dictionary):
		adj[int(i)] = []
	for i in (base["rooms"] as Dictionary):
		for d in (base["rooms"][i]["exits"] as Dictionary):
			var nb_v: Variant = coord_of.get(Vector2i(base["rooms"][i]["coord"]) + Vector2i(DIRS[String(d)]), null)
			if nb_v == null:
				continue
			if cut_locked and (base["locks"] as Dictionary).has(String(g._edge_key(int(i), int(nb_v)))):
				continue
			(adj[int(i)] as Array).append(int(nb_v))
	return adj


static func _bfs(adj: Dictionary, start: int) -> Dictionary:
	var depth := {start: 0}
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size():
		var at: int = queue[cursor]
		cursor += 1
		for nb in (adj.get(at, []) as Array):
			if not depth.has(int(nb)):
				depth[int(nb)] = int(depth[at]) + 1
				queue.append(int(nb))
	return depth


## Independent literal controls. The production signature is pinned, so a
## changed arity is a compile/setup failure, never an accepted omission.
static func _synthetic_controls(receipt: Dictionary) -> void:
	var failures: Array = receipt["failures"]
	var gate: GDScript = load(GATE_PATH)
	receipt["checks"] = int(receipt["checks"]) + 4
	# Square loop 0-(0,0) 1-(1,0) 2-(1,1) 3-(0,1), edges 0-1-2-3: the missing
	# 0-3 edge closes the loop at original distance 3; 3 is off-spine and
	# deeper (depth 3), so far must be 3.
	var coords := {0: Vector2i(0, 0), 1: Vector2i(1, 0), 2: Vector2i(1, 1), 3: Vector2i(0, 1)}
	var exits := {0: ["E"], 1: ["W", "S"], 2: ["N", "W"], 3: ["E"]}
	var valid := {0: true, 1: true, 2: true, 3: true}
	var pick: Dictionary = gate.select_graph(coords, exits, {}, {0: true}, valid)
	if int(pick.get("a", -1)) != 0 or int(pick.get("b", -1)) != 3 \
			or int(pick.get("dist", -1)) != 3 or int(pick.get("far", -1)) != 3:
		failures.append("synthetic square loop: expected a=0 b=3 dist=3 far=3, got %s" % str(pick))
	# Locking the mid-path edge 1-2 splits the lock-cut components: reject.
	pick = gate.select_graph(coords, exits, {"1_2": true}, {0: true}, valid)
	if not pick.is_empty():
		failures.append("synthetic locked-cut: expected no candidate, got %s" % str(pick))
	# Every room on the spine: a pure spine bypass must be refused.
	pick = gate.select_graph(coords, exits, {}, {0: true, 1: true, 2: true, 3: true}, valid)
	if not pick.is_empty():
		failures.append("synthetic all-spine: expected no candidate, got %s" % str(pick))
	# An invalid endpoint (how the adapter marks boss/pocket/waking/unlisted
	# rooms) removes the only candidate: reject.
	pick = gate.select_graph(coords, exits, {}, {0: true}, {0: true, 1: true, 2: true, 3: false})
	if not pick.is_empty():
		failures.append("synthetic invalid-endpoint: expected no candidate, got %s" % str(pick))
	# Exercise the actual adapter, then actual navigation/death recovery,
	# on this known literal square instead of cloning production predicates.
	var g := Game.new()
	g.chapter_id = CHAPTER
	g.zone_count = 4
	g.zones = [{}, {}, {"type": "combat", "enemies": ["wolf"]},
		{"type": "combat", "enemies": ["wolf"]}]
	for i in 4:
		var room_exits := {}
		for d in exits[i]: room_exits[d] = ""
		g.rooms.append({"coord": coords[i], "scale": Vector2.ONE,
			"origin": Vector2(coords[i]) * Vector2(g.ROOM_W, g.ROOM_H), "exits": room_exits})
		g.coord_to_room[coords[i]] = i
	receipt["checks"] = int(receipt["checks"]) + 7
	if not gate.valid_room(g, 3): failures.append("adapter: ordinary combat room rejected")
	for marker in ["boss", "pocket", "waking", "unlisted"]:
		g.zones[3][marker] = "qa_reserved"
		if gate.valid_room(g, 3): failures.append("adapter: nonempty %s did not exclude endpoint" % marker)
		g.zones[3].erase(marker)
	var original_exits: Dictionary = g.rooms[3]["exits"]
	g.rooms[3]["exits"] = {}
	if gate.valid_room(g, 3): failures.append("adapter: unplaced/no-exit endpoint accepted")
	g.rooms[3]["exits"] = original_exits
	g._install_shortcut()
	if g.shortcut_edge.is_empty():
		failures.append("literal square installation failed")
	else:
		receipt["checks"] = int(receipt["checks"]) + 5
		var key := String(g.shortcut_edge["flag"])
		g.visited = {0: true, 1: true, 2: true, 3: true}
		g.cleared = {2: true}
		var nav: GDScript = load("res://scripts/ui/navigation.gd")
		if nav.route(g, 0, 3) != [0, 1, 2, 3]: failures.append("closed shortcut changed the ordinary route")
		if g.respawn_room(3) != 2: failures.append("closed shortcut changed nearest death recovery")
		g.flags[key] = true # structural flag loan; no claimed earned interaction
		if nav.route(g, 0, 3) != [0, 3]: failures.append("opened shortcut did not shorten the route")
		if g.respawn_room(3) != 0: failures.append("opened shortcut did not expose nearer safe recovery")
		g.flags["completed_ch1"] = true
		g._wipe_chapter_flags()
		if g.flags.has(key) or not bool(g.flags.get("completed_ch1", false)):
			failures.append("replay did not clear shortcut while retaining character history")
	g.free()



static func _save(rig, receipt: Dictionary) -> void:
	var dir := String(rig.shot_dir) + "/shortcut_domain"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(dir + "/receipt.json", FileAccess.WRITE)
	if file == null:
		(receipt["failures"] as Array).append("could not write receipt.json under " + dir)
		return
	file.store_string(JSON.stringify(receipt, "  "))
	file.close()
	print("SHORTCUT DOMAIN RECEIPT: " + ProjectSettings.globalize_path(dir + "/receipt.json"))
