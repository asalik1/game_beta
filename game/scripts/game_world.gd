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

## Tear the world down and rebuild it from another chapter's data.
## Only ever called before play starts (chapter select) or on load —
## dynamic entities (chests, pickups, projectiles) don't exist then.
func switch_chapter(id: String, force := false) -> void:
	if not Story.CHAPTER_LIST.has(id) or (id == chapter_id and not force):
		return
	chapter_id = id
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
	_build_room(i)
	var first_visit: bool = not visited.get(i, false)
	visited[i] = true
	cur_room = i
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
	refresh_quest()
	_try_spawn_boss(i)
	last_room = i
	autosave()  # autosave on every room transition (DESIGN.md)

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
	_spawn_patches(i)
	zone_scenery[i] = []
	_spawn_scenery(i)
	_build_room_walls(i)

	# Data-driven NPCs (content modules + Chapter 1 props/shrines):
	# {"sprite": "villager", "x": 500, "y": 330, "prompt": "E — Talk",
	#  "convo": "some_convo_id"}
	for npc_def in zone.get("npcs", []):
		var convo_id: String = npc_def["convo"]
		_make_npc(npc_def["sprite"],
			room_pos(i, npc_def["x"], npc_def["y"]),
			npc_def.get("prompt", "E — Talk"), func() -> void:
				run_convo_id(convo_id))

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
		var elite_room := erng.randf() < Balance.ELITE_SOCIAL_ROOM_CHANCE
		if elite_room and not cleared.get(i, false):
			_spawn_elite_room(i, erng)
		elif not elite_room or cleared.get(i, false):
			_spawn_wanderer(i)

func _spawn_room_enemies(i: int) -> void:
	zone_alive[i] = 0
	var spawned: Array = []
	for spawn in zones[i].get("enemies", []):
		var lvl := int(spawn[4]) if spawn.size() > 4 else -1
		var e := Enemy.make(self, spawn[0], room_pos(i, spawn[1], spawn[2]), lvl)
		e.zone_idx = i
		e.pack_id = int(spawn[3]) if spawn.size() > 3 else 0
		zone_alive[i] = zone_alive.get(i, 0) + 1
		add_enemy(e)
		spawned.append(e)
	# Elite ambush (playtest round 6): seeded per character+room, some
	# combat rooms promote one pack member to a miniboss. Boss rooms
	# are exempt — those arenas stay as authored.
	if not spawned.is_empty() and String(zones[i].get("boss", "")) == "":
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed * 17 + i * 337 + chapter_id.hash() % 8837
		if rng.randf() < Balance.ELITE_COMBAT_AMBUSH_CHANCE:
			spawned[rng.randi_range(0, spawned.size() - 1)].promote_elite()

## A lone elite holds a small side room. Kind and level ride the
## nearest earlier combat room, one level above its toughest spawn —
## a miniboss that always fits the local power band.
func _spawn_elite_room(i: int, rng: RandomNumberGenerator) -> void:
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
	var e := Enemy.make(self, kind, room_center(i) + Vector2(0, -60), lvl + 1)
	e.zone_idx = i
	e.pack_id = 0
	e.promote_elite()
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

## Social rooms roll ONE wanderer from the pool, seeded per character —
## a replay meets different people (DESIGN.md room palette).
func _spawn_wanderer(i: int) -> void:
	if Story.WANDERERS.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
	var w: Dictionary = Story.WANDERERS[rng.randi_range(0, Story.WANDERERS.size() - 1)]
	var convo_id: String = w["convo"]
	var pos := room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-140.0, 140.0))
	_make_npc(w["sprite"], pos, w.get("prompt", "E — Talk"), func() -> void:
		run_convo_id(convo_id))

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
	spr.texture = Art.tex(sprite_name)
	spr.scale = Art.scale_for(spr.texture, 3.0)
	npc.add_child(spr)
	var prompt := Label.new()
	prompt.text = prompt_text
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
	for i in int(ceil(58.0 * area_frac)):
		var spr := Sprite2D.new()
		spr.texture = Art.tex(decor_list[rng.randi_range(0, decor_list.size() - 1)])
		spr.scale = Vector2(3, 3)
		spr.position = origin + Vector2(rng.randf_range(70.0, pw - 70.0), rng.randf_range(80.0, ph - 80.0))
		spr.z_index = -8
		world.add_child(spr)
		zone_scenery[zi].append(spr)

	# Colliding obstacles, kept off the road band and the door lanes.
	var obstacles: Array = terrain.get("obstacles", ["rock"])
	var placed: Array = []
	var max_x := pw - 760.0 if zones[zi].get("boss", "") != "" else pw - 90.0
	var count := int(ceil(float(terrain.get("count", 10)) * 2.2 * area_frac))
	for i in count:
		for attempt in 40:
			var pos := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, ph - 100.0))
			if pos.y > ph / 2.0 - 90.0 and pos.y < ph / 2.0 + 90.0:
				continue  # the road / east-west door lane stays open
			if absf(pos.x - pw / 2.0) < 130.0:
				continue  # the north-south door lane stays open
			var ok := true
			for other in placed:
				if pos.distance_to(other) < 85.0:
					ok = false
					break
			if ok:
				placed.append(pos)
				var body := _add_obstacle(obstacles[rng.randi_range(0, obstacles.size() - 1)], origin + pos)
				zone_scenery[zi].append(body)
				break

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
	body.add_child(spr)
	world.add_child(body)
	return body

## A wall segment: collider + tiled wallblock visual.
func _wall(rect: Rect2) -> void:
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
	world.add_child(body)
	var spr := Sprite2D.new()
	spr.texture = Art.tex("wallblock")
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect.size / 3.0)
	spr.centered = false
	spr.position = rect.position
	spr.scale = Vector2(3, 3)
	spr.z_index = -5
	world.add_child(spr)

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
	# North/south walls (gap centered on x).
	for spec in [["N", r.position.y], ["S", r.end.y - TILE]]:
		var dir: String = spec[0]
		var y: float = spec[1]
		if exits.has(dir):
			var half := r.size.x / 2.0 - gap / 2.0
			_wall(Rect2(r.position.x, y, half, TILE))
			_wall(Rect2(r.position.x + r.size.x / 2.0 + gap / 2.0, y, half, TILE))
			_door_torches(door_pos(i, dir), false)
			if ins.y > 0.0:
				var cx := full.position.x + ROOM_W / 2.0
				var cy := full.position.y if dir == "N" else r.end.y
				_wall(Rect2(cx - gap / 2.0 - TILE, cy, TILE, ins.y))
				_wall(Rect2(cx + gap / 2.0, cy, TILE, ins.y))
		else:
			_wall(Rect2(r.position.x, y, r.size.x, TILE))
	# West/east walls (gap centered on y).
	for spec in [["W", r.position.x], ["E", r.end.x - TILE]]:
		var dir: String = spec[0]
		var x: float = spec[1]
		if exits.has(dir):
			var half := r.size.y / 2.0 - gap / 2.0
			_wall(Rect2(x, r.position.y, TILE, half))
			_wall(Rect2(x, r.position.y + r.size.y / 2.0 + gap / 2.0, TILE, half))
			_door_torches(door_pos(i, dir), true)
			if ins.x > 0.0:
				var cy2 := full.position.y + ROOM_H / 2.0
				var cx2 := full.position.x if dir == "W" else r.end.x
				_wall(Rect2(cx2, cy2 - gap / 2.0 - TILE, ins.x, TILE))
				_wall(Rect2(cx2, cy2 + gap / 2.0, ins.x, TILE))
		else:
			_wall(Rect2(x, r.position.y, TILE, r.size.y))
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
	var beat: Array = Story.ALL_BEATS.get("pre_" + kind, [])
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
	set_music(_boss_music())

func _try_spawn_boss(zi: int) -> void:
	if not built.get(zi, false) or zone_alive.get(zi, 0) > 0 or zi != cur_room:
		return
	var kind: String = zones[zi].get("boss", "")
	if kind == "" or boss_done.get(kind, false) or boss_spawned.get(zi, false):
		return
	_on_boss_trigger(zi)

func add_enemy(e: Enemy) -> void:
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
			entry["body"].position = door_pos(cur_room, String(dir)) \
				+ Vector2(DIRS[dir]) * (TILE * 0.9)
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
	_spawn_scenery(zi)  # tombstones, snowy pines, crystals...
	_spawn_patches(zi)
	# If the player is standing in this room, refresh mood immediately.
	if cur_room == zi:
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 0.6)
		_setup_ambient_fx(terrain_id)
		terrain_event_t = randf_range(2.0, 4.0)
		if not is_instance_valid(current_boss):
			set_music(terrain.get("music", "village"))

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
