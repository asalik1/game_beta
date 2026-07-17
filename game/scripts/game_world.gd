extends "res://scripts/game_base.gd"
## GAME, layer 2 of 4 — the world: chapter/room graph generation, room
## building (walls, gates, scenery, NPCs), monster/merchant/elite
## spawning and terrain application. See game_base.gd for the layout.


## Open any built gate whose lock condition is now satisfied.
func _recheck_gates() -> void:
	for key in gates.keys():
		var parts: PackedStringArray = String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if _edge_unlocked(a, b):
			open_edge(a, b)


## MP (Wave-1 co-op fix): apply a host-fanned boss_done mark on a guest — record
## it, then reopen any built gate whose "boss" lock it just satisfied. A guest
## already standing in the arena has a built, locked gate (this opens it); a
## guest that builds the arena LATER never builds the gate at all (the gate-
## construction guard in _build_room_walls reads boss_done). Reached from
## net_session._rpc_boss_done — solo never sets a boss_done over the wire.
func net_apply_boss_done(kind: String) -> void:
	boss_done[kind] = true
	_recheck_gates()

## Tear the world down and rebuild it from another chapter's data.
## Only ever called before play starts (chapter select) or on load —
## dynamic entities (chests, pickups, projectiles) don't exist then.
func switch_chapter(id: String, force := false) -> void:
	# World teardown: forgotten ground loot mails itself first (round 8).
	flush_dropped_loot()
	if not (Story.CHAPTER_LIST.has(id) or Story.is_endgame(id)) or (id == chapter_id and not force):
		return
	chapter_id = id
	_quest_avail_cache = -1  # a new chapter offers a whole new set (⚑ shine memo)
	quest_marks.clear()      # the old world's ❢ nodes die with it
	# Potion investment (2026-07-09): stock is BOUGHT and carries across
	# chapters — no grants. The one exception: entering a teaching chapter
	# (ch1-3) hands ONE free health potion that EXPIRES on leaving it. The
	# absolute set below is grant + expiry in one move (revisits can never
	# stack freebies); loads overwrite it from the save right after this.
	player.potions_free = 1 if chapter_id in Balance.FREE_POTION_CHAPTERS else 0
	var chapter: Dictionary = Story.chapter(id)
	zones = chapter["zones"]
	zone_count = zones.size()

	if is_instance_valid(world):
		world.free()  # immediate: everything world-owned dies with it
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	move_child(world, player.get_index())  # draw under the hero again

	gates.clear()
	interactables.clear()
	zone_alive.clear()
	boss_spawned.clear()
	boss_done.clear()
	merchant_zones.clear()
	hazards.clear()
	zone_grounds.clear()
	zone_road_marks.clear()
	zone_scenery.clear()
	shop_stock.clear()
	built.clear()
	visited.clear()
	cleared.clear()
	door_seen.clear()
	bosses.clear()
	current_boss = null
	elder = null
	barrier_active = false
	talked_to_elder = false
	last_room = -1
	gust_vec = Vector2.ZERO
	terrain_by_zone.clear()
	for zone in zones:
		terrain_by_zone.append(zone.get("terrain", "village"))
	_prepare_rooms()
	_build_door_seals()
	quest_key = String(chapter.get("start_quest", "talk"))

	player.global_position = _start_pos()
	last_safe_room = maxi(0, room_at_pos(player.global_position))
	_enter_room(last_safe_room)
	ambient.color = Terrains.get_terrain(terrain_by_zone[cur_room])["tint"]
	refresh_quest()


# ------------------------------------------------------- the room graph ---

## Build the runtime graph meta (grid coords, exits, locks, scales)
## from the chapter's room dicts. Chapters authored WITHOUT coords are
## legacy west→east strips: they become a one-row chain, and all their
## authored positions rescale from the old 34x15 zone into the room.
func _prepare_rooms() -> void:
	rooms.clear()
	coord_to_room.clear()
	edge_locks.clear()
	# Chapters with a SPINE get a seeded procedural layout instead of
	# their authored coords — every run is a different map.
	var spine: Array = Story.chapter(chapter_id).get("spine", [])
	if not spine.is_empty():
		_generate_layout(spine)
		return
	var graph := false
	for zone in zones:
		if zone.has("coord"):
			graph = true
			break
	for i in zone_count:
		var zone: Dictionary = zones[i]
		var meta := {}
		var exits := {}
		if graph:
			var c: Array = zone.get("coord", [i, 0])
			meta["coord"] = Vector2i(int(c[0]), int(c[1]))
			meta["scale"] = Vector2.ONE
			var locks: Dictionary = zone.get("locks", {})
			for dir in zone.get("exits", []):
				exits[String(dir)] = String(locks.get(dir, ""))
		else:
			meta["coord"] = Vector2i(i, 0)
			meta["scale"] = Vector2(float(ROOM_W) / LEGACY_W, float(ROOM_H) / LEGACY_H)
			if i > 0:
				exits["W"] = ""
			if i < zone_count - 1:
				# Old strip gate rule: the way east opens when this zone's
				# boss dies or its gate_flag is set.
				var lock := ""
				if String(zone.get("boss", "")) != "":
					lock = "boss"
				elif String(zone.get("gate_flag", "")) != "":
					lock = "flag:" + String(zone["gate_flag"])
				exits["E"] = lock
		meta["exits"] = exits
		meta["origin"] = Vector2(meta["coord"].x * ROOM_W, meta["coord"].y * ROOM_H)
		rooms.append(meta)
		coord_to_room[meta["coord"]] = i
	# Exits are declared one-sided; imply the reciprocal, and register
	# each locked edge with the room that owns the lock condition.
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var nb := neighbor(i, dir)
			if nb < 0:
				push_warning("room %d: exit %s leads nowhere" % [i, dir])
				exits.erase(dir)
				continue
			var nexits: Dictionary = rooms[nb]["exits"]
			if not nexits.has(OPP[dir]):
				nexits[OPP[dir]] = ""
			var lock: String = exits[dir]
			if lock != "" and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}

## Seeded procedural layout (playtest round 3: "why is every run the
## same map?"). The spine (story-ordered boss path) walks the grid
## east with seeded N/S jogs — at most one vertical step per column,
## which makes the walk provably self-avoiding. Side rooms then attach
## to a seeded host of the SAME TERRAIN with a free edge (falling back
## to any placed room), so wings and dead ends land somewhere new each
## run. Pure function of wander_seed: saves reload the same world;
## replays and new characters roll a fresh one.
func _generate_layout(spine: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 31 + chapter_id.hash() % 100003
	var coord := {}                     # room idx -> Vector2i
	var room_exits: Array = []          # room idx -> {dir: lock}
	for i in zone_count:
		room_exits.append({})

	# --- the spine walk ---
	var at := Vector2i(0, 0)
	coord[int(spine[0])] = at
	var vertical_last := false
	for k in range(1, spine.size()):
		var dir := "E"
		if not vertical_last and rng.randf() < 0.45:
			dir = "N" if rng.randf() < 0.5 else "S"
		vertical_last = dir != "E"
		var prev := int(spine[k - 1])
		var cur := int(spine[k])
		at += Vector2i(DIRS[dir])
		coord[cur] = at
		room_exits[prev][dir] = String(zones[prev].get("lock_next", ""))
		room_exits[cur][OPP[dir]] = ""

	# --- side rooms attach to same-terrain hosts (then anyone) ---
	var placed: Array = spine.duplicate()
	var taken := {}
	for i in coord:
		taken[coord[i]] = true
	for i in zone_count:
		if coord.has(i):
			continue
		var cands: Array = []
		for pass_same in [true, false]:
			for p in placed:
				if pass_same and terrain_by_zone[int(p)] != terrain_by_zone[i]:
					continue
				for d in ["N", "S", "E", "W"]:
					if room_exits[int(p)].has(d):
						continue
					if not taken.has(coord[int(p)] + Vector2i(DIRS[d])):
						cands.append([int(p), d])
			if not cands.is_empty():
				break
		if cands.is_empty():
			push_warning("layout: no host found for room %d" % i)
			continue
		var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var host := int(pick[0])
		var host_dir := String(pick[1])
		coord[i] = coord[host] + Vector2i(DIRS[host_dir])
		taken[coord[i]] = true
		room_exits[host][host_dir] = ""
		room_exits[i][OPP[host_dir]] = ""
		placed.append(i)

	# --- write the runtime meta (same shape as the authored path) ---
	for i in zone_count:
		var meta := {"coord": coord[i], "scale": Vector2.ONE, "exits": room_exits[i],
			"origin": Vector2(coord[i].x * ROOM_W, coord[i].y * ROOM_H)}
		rooms.append(meta)
		coord_to_room[coord[i]] = i
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var lock := String(exits[dir])
			var nb := neighbor(i, String(dir))
			if lock != "" and nb >= 0 and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}

## Make room i the live room: build it on first entry, clamp the camera
## to it, wake the mood, autosave. Only the live room simulates.
func _enter_room(i: int) -> void:
	if i < 0 or i >= zone_count:
		return
	var prev := cur_room
	_build_room(i)
	var first_visit: bool = not visited.get(i, false)
	visited[i] = true
	cur_room = i
	_refresh_active_rooms()  # the sim gate follows atomically (MP §4.3)
	_calm_left_room(prev, i)
	if is_instance_valid(player):
		player.reset_room_potions()  # the loadout's per-room budget refills
	# Standing in a room, you can SEE its doors: neighbors go on the map
	# as stubs, and a seen boss door gets its marker.
	for dir in rooms[i]["exits"].keys():
		var nb := neighbor(i, dir)
		if nb >= 0:
			door_seen[nb] = true
	# Camera clamps to the PLAYABLE rect — small rooms read small, and
	# the empty margin outside their walls never shows.
	var r := play_rect(i)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	if room_safe(i):
		last_safe_room = i
	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var tween := create_tween()
	tween.tween_property(ambient, "color", terrain["tint"], 1.0)
	_setup_ambient_fx(terrain_by_zone[i])
	terrain_event_t = randf_range(2.5, 5.0)
	var room_boss: Boss = null
	var rogue_boss := false
	for b in _live_bosses():
		var live_b: Boss = b
		if live_b.zone_idx == i:
			room_boss = live_b
		elif live_b.zone_idx < 0:
			rogue_boss = true
	if room_boss != null:
		# Walking back into a live arena: the fight's bar + music resume.
		current_boss = room_boss
		set_music(_boss_music())
		hud.show_boss_bar(room_boss.display_name)
	elif not rogue_boss:
		set_music(terrain.get("music", "village"))
	if play_started and first_visit:
		hud.flash_title(zones[i]["name"])
		# The cursed chest's bargain is offered at the door, once,
		# while the pack still stands (playtest 2026-07-07).
		_offer_cursed_chest(i)
	refresh_quest()
	_try_spawn_boss(i)
	# Wave-1 co-op fix: a guest entering an already-cleared boss arena must find
	# its gate OPEN. The gate-construction guard skips building a gate for a
	# satisfied edge; this reopens one that a boss_done arrival satisfied AFTER
	# the gate was built. Guest-only — the host opens gates through its own
	# kill/clear/flag triggers, so solo/host paths run no extra recheck here
	# (offline is bit-identical).
	if net_guest():
		_recheck_gates()
	last_room = i
	autosave()  # autosave on every room transition (DESIGN.md)

## HOST (empty-room fix 2026-07-10): a room only builds + spawns on its LOCAL
## player's entry, so a room a GUEST walked into FIRST would sit empty — the
## host never populated it, so MP-09 had nothing to mirror and the guest saw
## a rendered but lifeless room. The host already tracks every guest's room in
## active_rooms; here it builds + arms any it hasn't yet, so the enemies (and
## a boss) spawn host-side and stream out. Runs off the host's per-frame after
## _refresh_active_rooms. No-op solo and on guests (net_host gate).
func _host_ensure_active_rooms() -> void:
	if not net_host():
		return
	for r in active_rooms:
		var i := int(r)
		if i < 0 or i >= zone_count or built.get(i, false):
			continue
		_build_room(i)            # walls/scenery + _spawn_room_enemies (host spawns)
		_try_spawn_boss(i, true)  # arm a boss room a guest reached ahead of the
		                          # host (force: ignore the host's cur_room guard)
	# Wave-1 co-op fix: a room freshly built here for an already-cleared boss
	# leaves its gate open via the construction guard; this reopens any that a
	# late boss_done arrival satisfied after the gate was built. Host-only path.
	_recheck_gates()

## Leaving a room calms whatever you didn't kill: its pack forgets you and
## returns to post, so re-entry reads clean instead of a cluster still
## camping the doorway. You only ever leave a LIVE room by dying or a
## scripted yank (recall is barred while sealed, the door-lock bars a walk-
## out) — death already de-aggros, this covers the rest. Re-entry wakes the
## pack fresh; killed-but-uncleared mobs respawn via _reset_room_enemies.
## Bosses and homeless spawns (zone_idx < 0) are left to death/reset.
func _calm_left_room(prev: int, now: int) -> void:
	if prev < 0 or prev == now:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying:
			continue
		if e.zone_idx == prev and (e.force_aggro or e.alerted):
			e.force_aggro = false
			e.alerted = false
			e.global_position = e.home

## Build a room's world nodes on first entry (rooms build lazily).
func _build_room(i: int) -> void:
	if built.get(i, false):
		return
	built[i] = true
	var zone: Dictionary = zones[i]
	var meta: Dictionary = rooms[i]
	var origin: Vector2 = meta["origin"]

	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var ground := Sprite2D.new()
	ground.texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
		i * 1000 + 7, meta["exits"].keys())
	ground.centered = false
	ground.position = origin
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	world.add_child(ground)
	zone_grounds[i] = ground
	_mark_roads(i)
	_spawn_patches(i)
	zone_scenery[i] = []
	_spawn_scenery(i)
	_build_room_walls(i)

	# Data-driven NPCs (content modules + Chapter 1 props/shrines):
	# {"sprite": "villager", "x": 500, "y": 330, "prompt": "E — Talk",
	#  "convo": "some_convo_id"}
	for npc_def in zone.get("npcs", []):
		# Conditional props: "req_wanderer" ties a prop to this run's
		# seeded wanderer rolls — e.g. the miller's hat only exists in
		# worlds that also rolled the boy who's missing it.
		if npc_def.has("req_wanderer") \
				and not _wanderer_rolled(String(npc_def["req_wanderer"])):
			continue
		# Placeholder NPCs (extracted art wired for review) only exist in the
		# dev launcher — a normal playthrough never sees them in the world.
		if npc_def.get("placeholder", false) and not dev_mode:
			continue
		var convo_id: String = npc_def["convo"]
		var npc_node := _make_npc(npc_def["sprite"],
			room_pos(i, npc_def["x"], npc_def["y"]),
			npc_def.get("prompt", "E — Talk"), func() -> void:
				run_convo_id(convo_id))
		_mark_quest_giver(npc_node, convo_id)

	# Elder Maren, the Chapter 1 quest giver in the village.
	if chapter_id == "ch1" and i == 0:
		elder = _make_npc("elder", origin + Vector2(660, 500), "E — Talk", func() -> void:
			if not talked_to_elder:
				talked_to_elder = true
				var after := func() -> void:
					set_flag("met_elder")  # unbars the village's east gate
					quest_key = "fangmaw"
					refresh_quest()
					autosave()
				if get_flag("opened_" + player.cls, false) and Story.ALL_CONVOS.has("maren_" + player.cls):
					run_convo_id("maren_" + player.cls, after)  # she read your opening choice
				else:
					hud.dialogue(Story.ALL_BEATS["elder"], after)
			else:
				hud.dialogue(Story.ALL_BEATS["elder_repeat"])
		)

	# Merchants: SAFE rooms with a merchant spot keep one from the start
	# (or one who already wandered in, restored from the save). Combat
	# rooms only get theirs through the post-clear arrival roll.
	if merchant_zones.has(i):
		_merchant_node(i)
	elif zone.has("merchant") and String(zone.get("boss", "")) == "" \
			and zone.get("enemies", []).is_empty():
		_spawn_merchant(i)

	# Room-type extras.
	var cache_tier := String(zone.get("cache", ""))
	if cache_tier != "" and not get_flag(_cache_flag(i), false):
		var cache_room := i
		var chest := Chest.drop(self, cache_tier, room_center(i) + Vector2(0, -140))
		chest.on_open = func() -> void:
			set_flag(_cache_flag(cache_room))  # once per character
			run_secrets += 1                   # results card: secrets found

	# Packs — skipped when the save already calls this room cleared.
	if not cleared.get(i, false):
		_spawn_room_enemies(i)
	else:
		zone_alive[i] = 0

	# Social rooms (after the pack pass, so zone_alive counts stick):
	# seeded per character, some hold a lone ELITE instead of a wanderer
	# — a miniboss beat between combat rooms (playtest round 6; later
	# chapters may spawn more than one). Once beaten, the room stays
	# quiet — a wanderer moves in on the next visit.
	if room_type(i) == "social":
		var erng := _social_rng(i)
		var elite_room := erng.randf() < Balance.ELITE_SOCIAL_ROOM_CHANCE * weekly_fx("elite")
		if elite_room and not cleared.get(i, false):
			_spawn_elite_room(i, erng)
		elif not elite_room or cleared.get(i, false):
			_spawn_wanderer(i)

	# Elective risk events (retention roadmap #4): seeded per character
	# like elites — a replay meets different temptations. Both are
	# walk-past-able; neither ever ambushes.
	_spawn_risk_events(i)

	# Hidden caches (exploration premium): some dead ends bury a chest
	# that only glints awake when the player wanders near.
	_spawn_hidden_cache(i)

func _spawn_room_enemies(i: int) -> void:
	zone_alive[i] = 0
	if net_guest():
		return  # MP-09: guests never spawn enemies — the host owns the sim
		        # and its net_session spawn events + ~20 Hz state stream
		        # build the mirrors this room shows.
	var spawned: Array = []
	# +15% density (presence pass 2026-07-07): seeded per room so a save
	# reloads the same pack. Each authored spawn has a MOB_DENSITY_EXTRA
	# chance to bring a jittered twin — never on boss arenas.
	var drng := RandomNumberGenerator.new()
	drng.seed = wander_seed * 41 + i * 613 + chapter_id.hash() % 7919
	var densify: bool = String(zones[i].get("boss", "")) == ""
	for spawn in zones[i].get("enemies", []):
		var lvl := int(spawn[4]) if spawn.size() > 4 else -1
		var pack := int(spawn[3]) if spawn.size() > 3 else 0
		# Optional 6th param: AUTHORED XP for this spawn. Cross-chapter ranged
		# IMPORTS (2026-07-09 distribution pass) ride reward_m off a LOW base
		# level, overpaying 3-4x vs the chapter natives they stand beside —
		# this pins them back onto the chapter's authored XP budget.
		var xp_override := int(spawn[5]) if spawn.size() > 5 else -1
		var count := 1
		if densify and drng.randf() < Balance.MOB_DENSITY_EXTRA:
			count = 2
		for c in count:
			var jit := Vector2.ZERO if c == 0 else Vector2(drng.randf_range(-70, 70), drng.randf_range(-60, 60))
			var e := Enemy.make(self, spawn[0], room_pos(i, spawn[1], spawn[2]) + jit, lvl)
			e.zone_idx = i
			e.pack_id = pack
			if xp_override >= 0:
				e.xp_value = xp_override
			zone_alive[i] = zone_alive.get(i, 0) + 1
			add_enemy(e)
			spawned.append(e)
	# Tether pairing (mob mechanic): link tether mobs two-by-two so their
	# bond burns the player and one dying full-heals the twin (kill both
	# together). Odd one out simply loses the trait (no partner).
	var teth: Array = []
	for s in spawned:
		if (s as Enemy).traits.has("tether"):
			teth.append(s)
	for pi in range(0, teth.size() - 1, 2):
		var a := teth[pi] as Enemy
		var b := teth[pi + 1] as Enemy
		a.tether_partner = b
		b.tether_partner = a
	if teth.size() % 2 == 1:
		(teth[-1] as Enemy).traits.erase("tether")
	# Elite ambush (playtest round 6): seeded per character+room, some
	# combat rooms promote one pack member to a miniboss. Boss rooms
	# are exempt — those arenas stay as authored.
	if not spawned.is_empty() and String(zones[i].get("boss", "")) == "":
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed * 17 + i * 337 + chapter_id.hash() % 8837
		if rng.randf() < Balance.ELITE_COMBAT_AMBUSH_CHANCE * weekly_fx("elite"):
			spawned[rng.randi_range(0, spawned.size() - 1)].promote_elite()
	# An accepted curse outlives saves and death-resets: the flag re-arms
	# the pack's buff (and the payout) every time the room respawns.
	if get_flag(_curse_flag(i), false) and zone_alive.get(i, 0) > 0:
		curse_pending[i] = true
		_apply_room_curse(i)

## A lone elite holds a small side room. Kind and level ride the
## nearest earlier combat room, one level above its toughest spawn —
## a miniboss that always fits the local power band.
func _spawn_elite_room(i: int, rng: RandomNumberGenerator) -> void:
	if net_guest():
		return  # MP-09: enemies are host-side (mirrored via net_session)
	var kind := ""
	var lvl := 1
	for j in range(i - 1, -1, -1):
		var packs: Array = zones[j].get("enemies", [])
		if packs.is_empty():
			continue
		var pick: Array = packs[rng.randi_range(0, packs.size() - 1)]
		kind = String(pick[0])
		for s in packs:
			var sl := int(s[4]) if s.size() > 4 else int(Story.ALL_ENEMIES[s[0]]["level"])
			lvl = maxi(lvl, sl)
		break
	if kind == "":
		return
	var e := Enemy.make(self, kind, room_center(i) + Vector2(0, -60), lvl + Balance.ELITE_ROOM_LEVEL_BONUS)
	e.zone_idx = i
	e.pack_id = 0
	e.promote_elite()
	# The lone room guardian watches its whole (small) arena; pack-
	# promoted elites keep pack aggro so doorways never wake a room.
	e.aggro_range *= Balance.ELITE_AGGRO_MULT
	zone_alive[i] = zone_alive.get(i, 0) + 1
	add_enemy(e)

## The room you died in resets: its surviving packs despawn and respawn
## fresh (and calm) for the retry.
func _reset_room_enemies(i: int) -> void:
	if not built.get(i, false):
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss):
			e.remove_from_group("enemies")
			e.queue_free()
	_spawn_room_enemies(i)

## One pack member noticed you: the whole pack answers (per-pack aggro —
## rooms are too big for all-at-once).
func wake_pack(room: int, pack: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.zone_idx == room and e.pack_id == pack \
				and not e.force_aggro:
			e.force_aggro = true
			if not e.alerted:
				e.alerted = true
				emote(e, "!", 0.9)


## Any living member of this pack still standing? (The just-dead enemy is
## already out of the "enemies" group when on_enemy_died runs, so an emptied
## pack reads false — the pack-cascade trigger.)
func _pack_alive(room: int, pack: int) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.zone_idx == room and e.pack_id == pack:
			return true
	return false


## Wake the sleeping pack whose nearest member is closest to the player — the
## cascade after a wipe (game_flow.on_enemy_died). Same room only; packs
## already engaged are skipped. No-op if nothing's left to wake.
func _wake_nearest_pack(room: int) -> void:
	if not is_instance_valid(player):
		return
	var best_pack := -1
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.zone_idx != room or e.force_aggro or e.alerted:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best_pack = e.pack_id
	if best_pack >= 0:
		wake_pack(room, best_pack)

# ------------------------------------------------------- risk events ---

## Seeded elective risk (retention roadmap #4): a CURSED CHEST in some
## combat rooms — open it and the living pack grows crueler until the
## purge, THEN it pays (golden chest + gem) — and a GAMBLE SHRINE in
## some quiet rooms — feed it gold and it blesses or drinks deeper.
## Once per character per room; replays reroll with the seed.
## (The cursed chest moved to _offer_cursed_chest — playtest 2026-07-07:
## a chest that waits in the room forever gets claimed AFTER the pack
## dies, making the bargain free and the payout unreachable.)
func _spawn_risk_events(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 53 + i * 947 + chapter_id.hash() % 6659
	if room_type(i) in ["social", "dead_end"]:
		if rng.randf() < Balance.SHRINE_ROOM_CHANCE and not get_flag(_shrine_flag(i), false):
			_gamble_shrine_node(i, room_center(i)
				+ Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(-70.0, 70.0)))


## The cursed chest offers itself AT THE DOOR (playtest 2026-07-07): it
## materializes ahead of the player on their FIRST step into a blighted
## room and gives Balance.CURSE_OFFER_WINDOW seconds to decide, then
## withdraws. Accepting therefore always happens with the whole pack
## alive — no more clear-most-then-claim, and no more claiming after
## the purge already fired (which paid nothing). Same seeded roll as
## before, so the same rooms carry the bargain.
func _offer_cursed_chest(i: int) -> void:
	if room_type(i) != "combat" or String(zones[i].get("boss", "")) != "":
		return
	if get_flag(_curse_flag(i), false) or cleared.get(i, false) \
			or zone_alive.get(i, 0) <= 0 or not is_instance_valid(player):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 53 + i * 947 + chapter_id.hash() % 6659
	if rng.randf() >= Balance.CURSED_ROOM_CHANCE:
		return
	var toward: Vector2 = room_center(i) - player.global_position
	var dir := toward.normalized() if toward.length() > 1.0 else Vector2.RIGHT
	_cursed_chest_node(i, player.global_position + dir * 150.0)


## A buried chest in some dead ends (exploration premium): invisible
## until the player wanders within reach, then it glints awake. Only in
## dead ends WITHOUT an authored cache; once per character per room
## (flag wiped by replays, like caches). Counts as a secret.
func _spawn_hidden_cache(i: int) -> void:
	if room_type(i) != "dead_end" or String(zones[i].get("cache", "")) != "" \
			or get_flag(_hidden_flag(i), false):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 71 + i * 383 + chapter_id.hash() % 5581
	if rng.randf() >= Balance.HIDDEN_CACHE_CHANCE:
		return
	var room := i
	var tier := "gold" if rng.randf() < Balance.HIDDEN_CACHE_GOLD_TIER else "silver"
	var chest := Chest.drop(self, tier,
		room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-130.0, 130.0)))
	chest.bury()
	chest.on_open = func() -> void:
		set_flag(_hidden_flag(room))
		run_secrets += 1  # results card: the wanderer's premium


## Drop an interactable from the prompt registry and the world.
func _remove_interactable(npc: Node2D) -> void:
	for it in interactables.duplicate():
		if it["node"] == npc:
			interactables.erase(it)
	npc.queue_free()


func _cursed_chest_node(i: int, pos: Vector2) -> void:
	var room := i
	var npc := _make_npc(String(Items.CHEST_TIERS["gold"]["sprite"]), pos,
		"E — The chest whispers", Callable())
	npc.modulate = Color(0.72, 0.5, 0.95)  # wrong-colored gold: clearly a bargain
	burst(pos, Color(0.7, 0.4, 1.0), 12)   # it ARRIVES — the window is open
	# Ten breaths to decide, then the bargain withdraws. The timer is a
	# CHILD of the chest: it pauses with the tree (menus don't eat the
	# window) and dies with the room (no lambda firing into a freed
	# world on chapter switches).
	var ticker := Timer.new()
	ticker.wait_time = Balance.CURSE_OFFER_WINDOW
	ticker.one_shot = true
	ticker.autostart = true
	npc.add_child(ticker)
	ticker.timeout.connect(func() -> void:
		if is_instance_valid(npc) and not get_flag(_curse_flag(room), false):
			burst(npc.global_position, Color(0.5, 0.3, 0.7), 10)
			sfx("gate", 0.7, 0.0, -6.0)
			_remove_interactable(npc))
	# The action needs the npc handle, so it's bound after creation.
	interactables[-1]["action"] = func() -> void:
		menus.open_confirm(
			"The chest whispers promises. Open it, and every monster in this room grows CRUELER (+%d%% damage, faster) until the room is purged — but the purge unlocks its hoard: a golden chest and a gem, guaranteed. Open it?"
				% int((Balance.CURSE_DMG_MULT - 1.0) * 100),
			func() -> void:
				set_flag(_curse_flag(room))
				curse_pending[room] = true
				_apply_room_curse(room)
				# Wave-1 co-op fix: the buff/tint lands only on the HOST's enemies,
				# but guests fight the SAME host-buffed pack — fan the visual so
				# their mirrors go violet and the party reads WHY it got crueler.
				if net_host():
					net_session().host_curse_applied(room)
				sfx("gate", 1.2)
				burst(npc.global_position, Color(0.7, 0.4, 1.0), 18)
				if is_instance_valid(player):
					spawn_text(player.global_position + Vector2(0, -78),
						"THE PACK STIRS, CRUELER — purge the room to claim the hoard",
						Color(0.85, 0.6, 1.0), 3.5)
				_remove_interactable(npc), func() -> void: pass)


## The accepted curse: every living pack member in the room hits harder
## and moves faster, wearing a violet cast so the bargain stays visible.
func _apply_room_curse(i: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying or e.zone_idx != i:
			continue
		if e.has_meta("cursed"):
			continue  # rebuilds re-arm the curse; never double-buff
		e.set_meta("cursed", true)
		e.dmg *= Balance.CURSE_DMG_MULT
		e.speed *= Balance.CURSE_SPEED_MULT
		e.modulate = e.modulate * Color(0.85, 0.65, 1.1)


func _gamble_shrine_node(i: int, pos: Vector2) -> void:
	var room := i
	var npc := _make_npc("pillar", pos, "E — Feed the shrine", Callable())
	npc.modulate = Color(0.85, 0.75, 1.05)
	interactables[-1]["action"] = func() -> void:
		var cost := shrine_cost()
		if player.gold < cost:
			spawn_text(player.global_position + Vector2(0, -56),
				"The shrine wants %d gold." % cost, Color(0.8, 0.75, 0.9))
			return
		menus.open_confirm(
			"The shrine hums with a borrowed hunger. Feed it %d gold? It may bless the offering... or drink deeper." % cost,
			func() -> void:
				set_flag(_shrine_flag(room))
				player.gold -= cost
				_shrine_outcome(cost)
				_remove_interactable(npc), func() -> void: pass)


## The gamble resolves — a true roll (loot_rng), not seeded: blessings
## outnumber banes, but the banes bite. Never lethal by design.
func _shrine_outcome(cost: int) -> void:
	var pos: Vector2 = player.global_position
	if loot_rng.randf() < Balance.SHRINE_BLESS_CHANCE:
		sfx("nova", 1.1)
		burst(pos, Color(1.0, 0.9, 0.5), 16)
		var roll := loot_rng.randf()
		if roll < 0.4 and Balance.regular_gems_drop(chapter_id):
			var gem := drop_gem(
				2 if loot_rng.randf() < Balance.gem_lv2_chance(player.level) else 1)
			if give_loot({"kind": "gem", "gem": gem}, pos + Vector2(0, 44)):
				spawn_text(pos + Vector2(0, -70), "+ " + Items.gem_title(gem), Items.gem_color(gem))
		elif roll < 0.7:
			var back := cost * 3
			player.gain_gold(back)
			spawn_text(pos + Vector2(0, -70), "The shrine returns THREEFOLD (+%d gold)" % back,
				Color(1.0, 0.85, 0.4))
		elif roll < 0.9:
			Chest.drop(self, "silver", clamp_to_zone(pos + Vector2(70, 0), pos))
			spawn_text(pos + Vector2(0, -70), "A gift surfaces...", Color(0.85, 0.88, 0.95))
		else:
			give_loot({"kind": "stone", "stone": Items.make_elixir_might()}, pos + Vector2(0, 44))
			spawn_text(pos + Vector2(0, -70), "+ Elixir of Might", Color(1.0, 0.7, 0.4))
	else:
		sfx("hurt", 0.8)
		hud.flash_screen(Color(0.6, 0.2, 0.5), 0.25, 0.3)
		if loot_rng.randf() < 0.6:
			player.hp = maxf(1.0, player.hp - player.max_hp * 0.3)
			spawn_text(pos + Vector2(0, -70), "The shrine drinks your BLOOD", Color(0.9, 0.4, 0.5))
		else:
			var more := mini(cost, player.gold)
			player.gold -= more
			spawn_text(pos + Vector2(0, -70), "The shrine drinks DEEPER (−%d gold)" % more,
				Color(0.9, 0.5, 0.6))


## Social rooms roll ONE wanderer from the pool, seeded per character —
## a replay meets different people (DESIGN.md room palette).
func _spawn_wanderer(i: int) -> void:
	var pool: Array = Story.wanderers_for(chapter_id)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
	var w: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var convo_id: String = w["convo"]
	var pos := room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-140.0, 140.0))
	var npc_node := _make_npc(w["sprite"], pos, w.get("prompt", "E — Talk"), func() -> void:
		run_convo_id(convo_id))
	_mark_quest_giver(npc_node, convo_id)

## Hang a ❢ over an NPC who can still offer a side quest you haven't taken —
## the genre's "!" and the actual fix for walking past a giver and never
## learning the quest existed (the journal only ever tracked quests you'd
## already accepted). Silent if this convo offers nothing, or if the offer is
## already taken//paid, so the mark means exactly one thing: an unasked job.
## The node self-polls rather than snapshotting at spawn — the mark must clear
## the instant you say yes, and the NPC outlives the conversation.
func _mark_quest_giver(npc: Node2D, convo_id: String) -> void:
	var offered: Array = Story.quests_offered_by(convo_id)
	if offered.is_empty():
		return
	var mark := Label.new()
	mark.text = "❢"
	mark.position = Vector2(-40, -84)
	mark.size = Vector2(80, 22)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mark.add_theme_constant_override("outline_size", 5)
	npc.add_child(mark)
	# A slow bob so it reads as a marker, not scenery.
	var tw := mark.create_tween().set_loops()
	tw.tween_property(mark, "position:y", -90.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mark, "position:y", -84.0, 0.9).set_trans(Tween.TRANS_SINE)
	quest_marks.append({"node": mark, "quests": offered})
	refresh_quest_marks()  # a reloaded save may already hold this quest


## Re-read every ❢ against the flags. Cheap (a handful of marks, two flag
## lookups each), so it rides the same set_flag beat that accepts a quest.
func refresh_quest_marks() -> void:
	for mk in quest_marks.duplicate():
		var node: Label = mk["node"]
		if not is_instance_valid(node):
			quest_marks.erase(mk)
			continue
		var any := false
		for sqid in mk["quests"]:
			if side_quest_available(String(sqid)):
				any = true
				break
		node.visible = any


## Whether this run's seeded wanderer rolls put `convo_id` in SOME social
## room — mirrors _spawn_wanderer's roll exactly (same seed, same single
## randi call). Quest props declaring "req_wanderer" ride the same
## worlds their wanderer does.
func _wanderer_rolled(convo_id: String) -> bool:
	var pool: Array = Story.wanderers_for(chapter_id)
	if pool.is_empty():
		return false
	for i in zone_count:
		if room_type(i) != "social":
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
		var w: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		if String(w.get("convo", "")) == convo_id:
			return true
	return false

func _spawn_merchant(zi: int) -> void:
	if not zones[zi].has("merchant") or merchant_zones.has(zi):
		return
	merchant_zones.append(zi)
	if built.get(zi, false):
		_merchant_node(zi)

func _merchant_node(zi: int) -> void:
	var zone: Dictionary = zones[zi]
	if not zone.has("merchant"):
		return
	var pos := room_pos(zi, zone["merchant"][0], zone["merchant"][1])
	var zone_idx := zi
	_make_npc("merchant", pos, "E — Shop", func() -> void:
		menus.open_shop(zone_idx)
	)

## The post-boss arrival: a puff of travel dust and a sales pitch.
func _merchant_arrives(zi: int) -> void:
	if merchant_zones.has(zi) or not zones[zi].has("merchant"):
		return
	_spawn_merchant(zi)
	var pos := room_pos(zi, zones[zi]["merchant"][0], zones[zi]["merchant"][1])
	burst(pos, Color(0.9, 0.8, 0.5), 12)
	sfx("coin")
	spawn_text(pos + Vector2(0, -50), "A WANDERING MERCHANT ARRIVES!", Color(0.95, 0.85, 0.5))
	# Wave-1 co-op fix: the arrival roll is host-only (guests run no kill/clear
	# triggers), so fan it — guests spawn the same node + fanfare owner-side.
	# The guest's re-entry here no-ops the re-fan (net_host false) and can't
	# double the static safe-room merchant (merchant_zones/_spawn_merchant guard).
	if net_host():
		net_session().host_merchant_arrives(zi)

## Teleport to a visited safe room from the map screen. Walking through
## a LIVE room is content; re-walking a cleared one is not (DESIGN.md).
func fast_travel(i: int) -> void:
	if not travel_target(i) or state != ST_PLAYING or barrier_active \
			or hud.dialogue_active or player.dead:
		return
	sfx("blink")
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)
	player.global_position = room_center(i)
	_enter_room(i)
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)

func _make_npc(sprite_name: String, pos: Vector2, prompt_text: String, action: Callable) -> Node2D:
	var npc := Node2D.new()
	npc.position = pos
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 20)
	npc.add_child(shadow)
	var spr := Sprite2D.new()
	var anim := Art.anim_info(sprite_name)
	if anim.is_empty():
		spr.texture = Art.tex(sprite_name)
		spr.scale = Art.scale_for(spr.texture, 3.0)
	else:
		# NPCs breathe too (animation seam): slow frame flip on a tween,
		# random phase so a crowd never inhales in unison.
		spr.texture = anim["tex"]
		var frames := int(anim["frames"])
		spr.hframes = frames
		spr.scale = Art.scale_for(spr.texture, 3.0, frames)
		var tw := spr.create_tween().set_loops()
		tw.tween_interval(randf_range(0.1, 0.8))
		tw.tween_callback(func() -> void: spr.frame = (spr.frame + 1) % frames)
		tw.tween_interval(0.45)
	npc.add_child(spr)
	if sprite_name == "mill":
		# The mill's chimney breathes a thin smoke plume (visual pass) —
		# somebody still lives behind that blue door.
		var smoke := CPUParticles2D.new()
		smoke.amount = 10
		smoke.lifetime = 3.5
		smoke.preprocess = 3.5
		smoke.position = Vector2(8, -float(spr.texture.get_height()) * spr.scale.y * 0.5 - 4.0)
		smoke.direction = Vector2(0.25, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(6, -16)
		smoke.initial_velocity_min = 8.0
		smoke.initial_velocity_max = 18.0
		smoke.scale_amount_min = 1.6
		smoke.scale_amount_max = 3.2
		smoke.color = Color(0.75, 0.74, 0.7, 0.35)
		npc.add_child(smoke)
	var prompt := Label.new()
	prompt.text = touchify(prompt_text)
	prompt.position = Vector2(-40, -58)
	prompt.size = Vector2(96, 20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.visible = false
	npc.add_child(prompt)
	world.add_child(npc)
	interactables.append({"node": npc, "prompt": prompt, "action": action})
	return npc

## (Re)build a room's decor + obstacles from its TERRAIN — tombstones in
## the graveyard, snowy pines on the ice, crystals in the caverns...
func _spawn_scenery(zi: int) -> void:
	for node in zone_scenery.get(zi, []):
		if is_instance_valid(node):
			node.queue_free()
	zone_scenery[zi] = []
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var pr := play_rect(zi)
	var origin: Vector2 = pr.position
	var pw := pr.size.x
	var ph := pr.size.y
	var area_frac := (pw * ph) / float(ROOM_W * ROOM_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 77 + terrain_by_zone[zi].hash() % 1000

	# Non-colliding ground decor (density scaled to the room's area —
	# small rooms get proportionally less).
	var decor_list: Array = terrain.get("decor", ["pebble"])
	for i in int(ceil(Balance.SCENERY_DECOR_BASE * area_frac)):
		var decor_name: String = decor_list[rng.randi_range(0, decor_list.size() - 1)]
		var spr := Sprite2D.new()
		spr.texture = Art.tex(decor_name)
		spr.scale = Vector2(3, 3)
		spr.position = origin + Vector2(rng.randf_range(70.0, pw - 70.0), rng.randf_range(80.0, ph - 80.0))
		spr.z_index = -8
		if decor_name in ["flower", "mushroom"]:
			spr.material = Art.wind_material()  # soft stems nod in the wind
		world.add_child(spr)
		zone_scenery[zi].append(spr)

	# Colliding obstacles, kept off the road band and the door lanes.
	var obstacles: Array = terrain.get("obstacles", ["rock"])
	var placed: Array = []
	var max_x := pw - 760.0 if zones[zi].get("boss", "") != "" else pw - 90.0

	# Buildings first (visual pass): a few homes make the village a
	# village. Seeded like everything else; obstacles keep clear of them.
	for bname in terrain.get("buildings", []):
		for attempt in 60:
			var bpos := Vector2(rng.randf_range(200.0, max_x - 160.0), rng.randf_range(170.0, ph - 180.0))
			if absf(bpos.y - ph / 2.0) < 160.0 or absf(bpos.x - pw / 2.0) < 190.0:
				continue  # the road and door lanes stay open
			var bok := true
			for other in placed:
				if bpos.distance_to(other) < 260.0:
					bok = false
					break
			if bok:
				placed.append(bpos)
				zone_scenery[zi].append(_add_building(String(bname), origin + bpos))
				break
	var count := int(ceil(float(terrain.get("count", 10)) * Balance.SCENERY_OBSTACLE_MULT * area_frac))
	for i in count:
		for attempt in Balance.SCENERY_PLACE_TRIES:
			var pos := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, ph - 100.0))
			if pos.y > ph / 2.0 - 90.0 and pos.y < ph / 2.0 + 90.0:
				continue  # the road / east-west door lane stays open
			if absf(pos.x - pw / 2.0) < 130.0:
				continue  # the north-south door lane stays open
			var ok := true
			for other in placed:
				if pos.distance_to(other) < Balance.SCENERY_MIN_SPACING:
					ok = false
					break
			if ok:
				placed.append(pos)
				var body := _add_obstacle(obstacles[rng.randi_range(0, obstacles.size() - 1)], origin + pos)
				zone_scenery[zi].append(body)
				break

	# Ambient critters (birds/crows/butterflies) live with the scenery:
	# room rebuilds and terrain repaints sweep them up too.
	for critter in Ambience.populate(self, zi):
		zone_scenery[zi].append(critter)

	# ---- the river (the Greyrun and its cousins) ------------------
	# Terrain-configured, seeded per room; skips boss arenas. Wading
	# slows everyone; the bridge carries the road across dry.
	rivers.erase(zi)
	var river_cfg: Dictionary = terrain.get("river", {})
	if not river_cfg.is_empty() and String(zones[zi].get("boss", "")) == "":
		var rrng := RandomNumberGenerator.new()
		rrng.seed = zi * 131 + terrain_by_zone[zi].hash() % 100000
		if rrng.randf() < float(river_cfg.get("chance", 0.5)):
			# Keep the channel clear of the N/S door lane at room center.
			var fx_pos := rrng.randf_range(0.18, 0.40) if rrng.randf() < 0.5 \
				else rrng.randf_range(0.60, 0.82)
			var wpx := rrng.randf_range(120.0, 170.0)
			var rect := Rect2(origin.x + pw * fx_pos - wpx / 2.0, origin.y, wpx, ph)
			var bridge := Rect2(rect.position.x - 14.0, origin.y + ph / 2.0 - 84.0,
				wpx + 28.0, 168.0)
			var water := Sprite2D.new()
			water.texture = Art.tex("white")
			water.centered = false
			water.position = rect.position
			water.scale = rect.size / 8.0  # white tex is 8x8
			water.z_index = -9             # over the ground, under decor
			water.material = Art.water_material(river_cfg.get("color", Color(0.1, 0.2, 0.2, 0.8)))
			world.add_child(water)
			zone_scenery[zi].append(water)
			var plank := Sprite2D.new()
			plank.texture = Art.tex("bridge")
			plank.centered = false
			plank.position = bridge.position
			plank.scale = bridge.size / plank.texture.get_size()  # fit any-res bridge art to the span
			plank.z_index = -8
			world.add_child(plank)
			zone_scenery[zi].append(plank)
			rivers[zi] = {"rect": rect, "bridge": bridge}

## A building: base-anchored (y-sort lets the player walk behind the
## roof), footprint collider, chimney smoke on the cottages.
func _add_building(sprite_name: String, pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos  # the base line is the sort anchor
	body.collision_layer = 1
	body.collision_mask = 0
	var spr := Sprite2D.new()
	spr.texture = Art.tex(sprite_name)
	# Houses dwarf a person: ~120px on screen (the old 24px grid at 5x).
	# Normalized by texture width so a higher-res override PNG lands at
	# the SAME footprint, just denser — 24px grids at 5x read as flat
	# cartoon blocks next to 30px pack characters at 3x.
	var target_w := 120.0 if sprite_name.begins_with("cottage") else 108.0
	var bscale := target_w / maxf(1.0, float(spr.texture.get_width()))
	spr.scale = Vector2(bscale, bscale)
	# Seeded mirroring: half the houses face the other way (free variety).
	spr.flip_h = (int(pos.x) + int(pos.y)) % 2 == 1
	var hpx := float(spr.texture.get_height()) * bscale
	var wpx := float(spr.texture.get_width()) * bscale
	spr.position = Vector2(0, -hpx * 0.5 + 12.0)
	body.add_child(spr)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(wpx * 0.62, 34.0)
	cs.position = Vector2(0, -8.0)
	cs.shape = shape
	body.add_child(cs)
	if sprite_name.begins_with("cottage"):
		# The hearth CRACKLES as you walk past (first positional audio).
		var fire := AudioStreamPlayer2D.new()
		var fstream: AudioStream = game_stream("campfire")
		if fstream:
			fire.stream = fstream
			fire.max_distance = 340.0
			fire.attenuation = 1.6
			fire.volume_db = -6.0
			fire.autoplay = true
			body.add_child(fire)
		var smoke := CPUParticles2D.new()
		smoke.amount = 8
		smoke.lifetime = 3.5
		smoke.preprocess = 3.5
		# The chimney sits ~66% across the art; mirrored houses mirror it.
		smoke.position = Vector2(wpx * 0.16 * (-1.0 if spr.flip_h else 1.0), -hpx + 8.0)
		smoke.direction = Vector2(0.25, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(6, -16)
		smoke.initial_velocity_min = 8.0
		smoke.initial_velocity_max = 18.0
		smoke.scale_amount_min = 1.6
		smoke.scale_amount_max = 3.2
		smoke.color = Color(0.75, 0.74, 0.7, 0.35)
		body.add_child(smoke)
	world.add_child(body)
	return body


func _add_obstacle(sprite_name: String, pos: Vector2) -> StaticBody2D:
	var is_tree := sprite_name.begins_with("tree")
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0 if is_tree else 11.0
	cs.shape = shape
	cs.position = Vector2(0, 10)
	body.add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(4, 2.4) if is_tree else Vector2(3, 2)
	shadow.position = Vector2(0, 38 if is_tree else 22)
	body.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(sprite_name)
	spr.scale = Vector2(3, 3)
	if is_tree:
		spr.position = Vector2(0, -18)  # trunk base sits at the body origin
		spr.material = Art.wind_material()  # canopy sways in the wind
	body.add_child(spr)
	world.add_child(body)
	return body

## A wall segment: collider + tiled wall visual. `wall_tex` is the terrain's
## seamless 16px wall tile (Terrains.wall_for); defaults to the stone block.
func _wall(rect: Rect2, wall_tex := "wallblock") -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.add_child(cs)
	# Walls block LIGHT too (visual pass): the player's halo throws real
	# shadows in dark terrains. Additive lights make this free-subtle in
	# daylight (light_mult ~0 there anyway).
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var hx := rect.size.x / 2.0
	var hy := rect.size.y / 2.0
	poly.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, hy), Vector2(-hx, hy)])
	occ.occluder = poly
	body.add_child(occ)
	world.add_child(body)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(wall_tex)
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect.size / 3.0)
	spr.centered = false
	spr.position = rect.position
	spr.scale = Vector2(3, 3)
	spr.z_index = -5
	world.add_child(spr)
	_wall_sink.append(spr)  # tracked so a terrain repaint can retexture it live

## Perimeter walls for one room, with door gaps on its open edges, and
## a gate body on any locked edge that isn't already satisfied.
## Small rooms build their walls at the inset playable rect and add
## short corridor walls from each doorway out to the cell edge.
func _build_room_walls(i: int) -> void:
	var r := play_rect(i)
	var full := room_rect(i)
	var ins := room_inset(i)
	var exits: Dictionary = rooms[i]["exits"]
	var gap := DOOR_TILES * TILE
	# Terrain-aware wall tile (2026-07-08): stone keep, wood village, mossy
	# forest/marsh, volcanic magma, ice, graveyard, sandstone — else stone.
	# Track the wall sprites so apply_terrain can retexture them live.
	var wt: String = Terrains.wall_for(terrain_by_zone[i])
	zone_wall_sprites[i] = []
	_wall_sink = zone_wall_sprites[i]
	# North/south walls (gap centered on x).
	for spec in [["N", r.position.y], ["S", r.end.y - TILE]]:
		var dir: String = spec[0]
		var y: float = spec[1]
		if exits.has(dir):
			var half := r.size.x / 2.0 - gap / 2.0
			_wall(Rect2(r.position.x, y, half, TILE), wt)
			_wall(Rect2(r.position.x + r.size.x / 2.0 + gap / 2.0, y, half, TILE), wt)
			_door_torches(door_pos(i, dir), false)
			if ins.y > 0.0:
				var cx := full.position.x + ROOM_W / 2.0
				var cy := full.position.y if dir == "N" else r.end.y
				_wall(Rect2(cx - gap / 2.0 - TILE, cy, TILE, ins.y), wt)
				_wall(Rect2(cx + gap / 2.0, cy, TILE, ins.y), wt)
		else:
			_wall(Rect2(r.position.x, y, r.size.x, TILE), wt)
	# West/east walls (gap centered on y).
	for spec in [["W", r.position.x], ["E", r.end.x - TILE]]:
		var dir: String = spec[0]
		var x: float = spec[1]
		if exits.has(dir):
			var half := r.size.y / 2.0 - gap / 2.0
			_wall(Rect2(x, r.position.y, TILE, half), wt)
			_wall(Rect2(x, r.position.y + r.size.y / 2.0 + gap / 2.0, TILE, half), wt)
			_door_torches(door_pos(i, dir), true)
			if ins.x > 0.0:
				var cy2 := full.position.y + ROOM_H / 2.0
				var cx2 := full.position.x if dir == "W" else r.end.x
				_wall(Rect2(cx2, cy2 - gap / 2.0 - TILE, ins.x, TILE), wt)
				_wall(Rect2(cx2, cy2 + gap / 2.0, ins.x, TILE), wt)
		else:
			_wall(Rect2(x, r.position.y, TILE, r.size.y), wt)
	# Locked edges get a gate — built once per edge, by whichever room
	# builds first, and only while the lock is still unmet.
	for dir in exits.keys():
		var nb := neighbor(i, dir)
		if nb < 0:
			continue
		var key := _edge_key(i, nb)
		if edge_locks.has(key) and not gates.has(key) and not _edge_unlocked(i, nb):
			gates[key] = _build_gate(i, String(dir))

## Flickering torches flank each doorway.
func _door_torches(pos: Vector2, vertical: bool) -> void:
	var span := DOOR_TILES * TILE / 2.0 + 26.0
	for side in [-1, 1]:
		var off := Vector2(0, side * span) if vertical else Vector2(side * span, 0)
		var torch := Sprite2D.new()
		torch.texture = Art.tex("torch")
		torch.scale = Vector2(3, 3)
		torch.position = pos + off
		torch.z_index = 2
		world.add_child(torch)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.6, 0.2, 0.5)
		glow.position = torch.position + Vector2(0, -12)
		glow.scale = Vector2(2.5, 2.5)
		glow.z_index = 1
		world.add_child(glow)
		var tween := glow.create_tween()
		tween.set_loops()
		tween.tween_property(glow, "scale", Vector2(3.1, 3.1), 0.5 + randf() * 0.3)
		tween.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.5 + randf() * 0.3)

## A gate barring the doorway on room i's `dir` edge.
func _build_gate(i: int, dir: String) -> Node2D:
	var vertical := dir in ["E", "W"]  # the barred passage runs east-west
	var gate := StaticBody2D.new()
	gate.position = door_pos(i, dir)
	gate.collision_layer = 1
	gate.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE * 2.2, DOOR_TILES * TILE) if vertical \
		else Vector2(DOOR_TILES * TILE, TILE * 2.2)
	cs.shape = shape
	gate.add_child(cs)
	for row in DOOR_TILES:
		var spr := Sprite2D.new()
		spr.texture = Art.tex("gate")
		spr.scale = Vector2(3, 3)
		var off := (row - 1) * TILE
		spr.position = Vector2(0, off) if vertical else Vector2(off, 0)
		gate.add_child(spr)
	world.add_child(gate)
	return gate

## Open a (possibly gated) edge between two rooms.
func open_edge(a: int, b: int) -> void:
	var key := _edge_key(a, b)
	if not gates.has(key):
		return
	var gate: Node2D = gates[key]
	gates.erase(key)
	if gate == null or not is_instance_valid(gate):
		return
	sfx("gate")
	gate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(gate, "modulate:a", 0.0, 0.8)
	tween.tween_callback(gate.queue_free)

## Legacy helper: open the gate on room zi's EAST edge (old strip rule).
func open_gate(zi: int) -> void:
	var nb := neighbor(zi, "E")
	if nb >= 0:
		open_edge(zi, nb)

## Battle seals: the 4 pooled door-blockers that close the current
## room's exits while a fight is live (rebuilt with the world).
func _build_door_seals() -> void:
	door_seals.clear()
	for i in 4:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0)
		cs.shape = shape
		body.add_child(cs)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.25, 0.2, 0.55)
		glow.scale = Vector2(1.4, 3.6)
		glow.z_index = 4
		body.add_child(glow)
		body.position = Vector2(-4000, -4000)  # parked (inactive)
		world.add_child(body)
		door_seals.append({"body": body, "shape": shape, "glow": glow})


# ==================================================================== bosses

func _on_boss_trigger(zi: int) -> void:
	if boss_spawned.get(zi, false):
		return
	var kind: String = zones[zi]["boss"]
	if boss_done.get(kind, false):
		return
	boss_spawned[zi] = true
	var beat: Array = Story.beat_for("pre_" + kind,
		Story.res_band(player.resonance), flags)
	if beat.is_empty():
		_spawn_boss(zi, kind)
	else:
		hud.dialogue(beat, func() -> void:
			_spawn_boss(zi, kind)
		)

func _spawn_boss(zi: int, kind: String) -> void:
	shake(6.0)
	# Rooms may spawn a boss off its "story" level (Act pacing).
	current_boss = Boss.make_boss(self, kind,
		rooms[zi]["origin"] + Vector2(ROOM_W - 420.0, ROOM_H / 2.0),
		int(zones[zi].get("boss_level", -1)))
	current_boss.story_boss = true  # its death advances the chapter
	current_boss.zone_idx = zi
	bosses.append(current_boss)
	world.add_child(current_boss)
	current_boss.roar()
	hud.show_boss_bar(Story.ALL_ENEMIES[kind]["name"])
	hud.boss_banner(Story.ALL_ENEMIES[kind]["name"])  # the name SLAMS in
	set_music(_boss_music())

func _try_spawn_boss(zi: int, force := false) -> void:
	if net_guest():
		return  # MP-09: bosses are host-side too (mirrored via net_session,
		        # boss bar included)
	# MP (Wave-1 co-op fix): `force` arms a boss room a GUEST reached ahead of
	# the host — _host_ensure_active_rooms populates such rooms, but the normal
	# `zi != cur_room` guard (the host stands elsewhere) would leave the arena
	# unarmed until the host walked in. Force skips ONLY that guard; every other
	# precondition (built, room purged, not already done/spawned) still holds.
	# Local entry passes force=false, so solo/normal behavior is unchanged.
	if not built.get(zi, false) or zone_alive.get(zi, 0) > 0 or (zi != cur_room and not force):
		return
	var kind: String = zones[zi].get("boss", "")
	if kind == "" or boss_done.get(kind, false) or boss_spawned.get(zi, false):
		return
	_on_boss_trigger(zi)

func add_enemy(e: Enemy) -> void:
	var party: int = players.size()
	if party > 1:
		# Co-op party scaling (MULTIPLAYER.md §5.2) rides every spawn exactly
		# like weekly_fx below; solo (party of 1) skips this block entirely.
		e.max_hp *= Balance.party_hp(party)
		e.hp = e.max_hp
		e.dmg *= Balance.party_dmg(party)
	if weekly_active:
		# The week's modifier rides every spawn (weekly challenge run).
		e.max_hp *= weekly_fx("hp")
		e.hp = e.max_hp
		e.dmg *= weekly_fx("dmg")
		e.speed *= weekly_fx("speed")
	world.add_child(e)


# ============================================================ death / respawn

## Is the current room HOT — ANY living pack, or a live boss that is in
## this room (or a homeless dev spawn)? Hot rooms seal their doors: the
## room must be PURGED before you move on (playtest round 2 — aggro
## stays per-pack, but no running past content).
func _room_hot(i: int) -> bool:
	for b in _live_bosses():
		if b.zone_idx == i or b.zone_idx < 0:
			return true
	if net_guest():
		# Guests never run _spawn_room_enemies, so zone_alive stays 0 — count
		# the HOST's live mirror enemies in the room instead, so a guest is
		# sealed into a combat room exactly as the host is (MP door-seal parity
		# 2026-07-10). Brief gap on first entry until the mirrors stream in.
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e != null and not (e is Boss) and not e.dying and e.zone_idx == i:
				return true
		return false
	return zone_alive.get(i, 0) > 0

## Seal or lift the current room's door seals based on its fight state.
func _update_barrier() -> void:
	var want := _room_hot(cur_room)
	if want and not barrier_active:
		sfx("gate")
	barrier_active = want
	var idx := 0
	if want:
		var pulse := 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
		for dir in rooms[cur_room]["exits"].keys():
			if idx >= door_seals.size():
				break
			var entry: Dictionary = door_seals[idx]
			idx += 1
			var vertical: bool = dir in ["E", "W"]
			entry["shape"].size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0) if vertical \
				else Vector2(DOOR_TILES * TILE + 24.0, TILE * 1.4)
			entry["glow"].scale = Vector2(1.4, 3.6) if vertical else Vector2(3.6, 1.4)
			entry["glow"].modulate.a = pulse
			# Seals sit a step OUTSIDE the room (into the doorway
			# corridor) so one never spawns on top of a player who just
			# walked in — they pass it, then it bars the way back.
			var spos: Vector2 = door_pos(cur_room, String(dir)) \
				+ Vector2(DIRS[dir]) * (TILE * 0.9)
			# ...and never arms INTO the player (playtest 2026-07-07:
			# crossing the line slowly caught the body inside the
			# freshly-armed seal — seconds of grinding to depenetrate).
			# The seal waits, parked, until the player steps clear.
			if is_instance_valid(player) \
					and player.global_position.distance_to(spos) < TILE * 2.4:
				entry["body"].position = Vector2(-4000, -4000)
				continue
			entry["body"].position = spos
	for j in range(idx, door_seals.size()):
		door_seals[j]["body"].position = Vector2(-4000, -4000)

## Weather particles driven by the terrain's ambient preset.
func _setup_ambient_fx(terrain_id: String) -> void:
	if is_instance_valid(ambient_fx):
		ambient_fx.queue_free()
	var spec: Dictionary = Terrains.AMBIENTS.get(
		Terrains.get_terrain(terrain_id).get("ambient", "leaves_green"), {})
	if spec.is_empty():
		ambient_fx = null
		return
	ambient_fx = CPUParticles2D.new()
	ambient_fx.amount = spec["amount"]
	ambient_fx.lifetime = 9.0
	ambient_fx.preprocess = 6.0
	ambient_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient_above = spec["above"]
	ambient_fx.emission_rect_extents = Vector2(760, 60) if ambient_above else Vector2(760, 340)
	ambient_fx.spread = 30.0
	ambient_fx.z_index = 12
	ambient_fx.color = spec["color"]
	ambient_fx.direction = spec["dir"]
	ambient_fx.gravity = spec["gravity"]
	ambient_fx.initial_velocity_min = spec["vel"][0]
	ambient_fx.initial_velocity_max = spec["vel"][1]
	ambient_fx.scale_amount_min = spec["scale"][0]
	ambient_fx.scale_amount_max = spec["scale"][1]
	add_child(ambient_fx)


# ================================================================= terrain

## Repaint a room with a different terrain (look + mechanics). Live —
## this is how dev mode lets you audition every terrain instantly.
func apply_terrain(zi: int, terrain_id: String) -> void:
	terrain_by_zone[zi] = terrain_id
	if not built.get(zi, false):
		return  # unbuilt rooms pick the new terrain up at build time
	var terrain := Terrains.get_terrain(terrain_id)
	if is_instance_valid(zone_grounds.get(zi)):
		zone_grounds[zi].texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
			zi * 1000 + 7, rooms[zi]["exits"].keys())
	_mark_roads(zi)
	_spawn_scenery(zi)  # tombstones, snowy pines, crystals...
	_spawn_patches(zi)
	# Retexture the room's walls to this terrain's tile (colliders unchanged,
	# so no rebuild — just swap the visual). Lets the dev terrain-paint preview
	# walls too, not just ground/props.
	var wt: String = Terrains.wall_for(terrain_id)
	for s in zone_wall_sprites.get(zi, []):
		if is_instance_valid(s):
			s.texture = Art.tex(wt)
	# If the player is standing in this room, refresh mood immediately.
	if cur_room == zi:
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 0.6)
		_setup_ambient_fx(terrain_id)
		terrain_event_t = randf_range(2.0, 4.0)
		if not is_instance_valid(current_boss):
			set_music(terrain.get("music", "village"))

## The road arms Art.ground paints (center plaza -> each REAL doorway)
## are invisible on terrains whose path kind IS their ground kind (keep,
## holy, void, ice...): only the 1px light-catch rim survives, and on
## stone it reads as dashed debug rectangles (art audit 2026-07-10).
## The road is a real navigation marker — door-honest since playtest
## round 3 — so it stays; this lays a faint worn-traffic band over the
## same geometry so the rim reads as the edge of an intentional walkway.
## Geometry mirrors Art.ground's arm rects (16px ground space at 3x).
func _mark_roads(zi: int) -> void:
	for s in zone_road_marks.get(zi, []):
		if is_instance_valid(s):
			s.queue_free()
	zone_road_marks[zi] = []
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var gk := String(terrain["ground"])
	if String(terrain["path"]) != gk or not Art.GROUND.has(gk):
		return  # contrasting path kinds already read as a road
	# Worn tone: dark floors polish LIGHTER underfoot, light floors tread
	# DARKER — both at a whisper (presentation constants, not tuning).
	var base_c: Color = Art.GROUND[gk][0]
	var lum: float = 0.2126 * base_c.r + 0.7152 * base_c.g + 0.0722 * base_c.b
	var worn := Color(1, 1, 1, 0.075) if lum < 0.45 else Color(0, 0, 0, 0.10)
	# Art.ground's arm rects, scaled to world px (16px ground tile * 3 = TILE).
	var path_top := float((TILES_H / 2 - 1) * TILE - 24)
	var band := 3.0 * TILE
	var vleft := float(ROOM_W / 2 - 72)
	var arms: Array = [Rect2(vleft, path_top, band, band)]  # central plaza
	var exits: Array = rooms[zi]["exits"].keys()
	if "W" in exits:
		arms.append(Rect2(0, path_top, vleft, band))
	if "E" in exits:
		arms.append(Rect2(vleft + band, path_top, ROOM_W - vleft - band, band))
	if "N" in exits:  # vertical arms stop at the painted top/bottom wall row
		arms.append(Rect2(vleft, TILE, band, path_top - TILE))
	if "S" in exits:
		arms.append(Rect2(vleft, path_top + band, band, ROOM_H - path_top - band - TILE))
	var origin: Vector2 = rooms[zi]["origin"]
	for arm in arms:
		var r: Rect2 = arm
		var s := Sprite2D.new()
		s.texture = Art.tex("white")
		s.centered = false
		s.position = origin + r.position
		s.scale = r.size / 8.0  # white tex is 8x8
		s.modulate = worn
		s.z_index = -10  # same layer as the ground, added after -> on top
		world.add_child(s)
		zone_road_marks[zi].append(s)


## (Re)roll a room's static hazard patches from its terrain spec.
func _spawn_patches(zi: int) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i]["zone"] == zi:
			if is_instance_valid(hazards[i]["sprite"]):
				hazards[i]["sprite"].queue_free()
			hazards.remove_at(i)
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var origin: Vector2 = rooms[zi]["origin"]
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + terrain_by_zone[zi].hash()
	for spec in terrain.get("patches", []):
		# Patch counts were tuned for the old strip; rooms are ~2.2x the area.
		for i in int(ceil(float(spec["count"]) * 2.0)):
			var pos := origin + Vector2(rng.randf_range(120.0, ROOM_W - 120.0), rng.randf_range(120.0, ROOM_H - 120.0))
			var radius := rng.randf_range(spec["radius"][0], spec["radius"][1])
			var drift := Vector2.ZERO
			if spec.get("drift", false):
				drift = Vector2(rng.randf_range(-20, 20), rng.randf_range(-14, 14))
			_add_hazard(zi, spec["type"], pos, radius, -1.0, drift)

## Add a floor hazard (until < 0 = permanent, else expires at that time).
func _add_hazard(zi: int, type: String, pos: Vector2, radius: float, duration := -1.0, drift := Vector2.ZERO) -> void:
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Terrains.PATCH_COLOR.get(type, Color(1, 1, 1, 0.4))
	spr.global_position = pos
	spr.scale = Vector2(radius / 22.0, radius / 26.0)
	spr.z_index = -7
	world.add_child(spr)
	hazards.append({"zone": zi, "type": type, "pos": pos, "radius": radius,
		"until": (Time.get_ticks_msec() / 1000.0 + duration) if duration > 0.0 else -1.0,
		"drift": drift, "sprite": spr})
