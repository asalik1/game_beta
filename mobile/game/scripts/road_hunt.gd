extends Node2D
## Optional host-owned road tracking. The quarry's actual death owns payment;
## missing/freed enemies, lost rooms and abandoned parties never imply victory.
const TRACKING := 0
const WARNING := 1
const FIGHTING := 2
const COMPLETE := 3
const CLOSED := 4
const KINDS := ["wolf", "blightwolf", "duneprowler"]
const TRACK := preload("res://assets/sprites/road_hunt_track.png")
const CLUES := ["Heavy tracks — One animal, favoring its left side. The marks turn across the road.",
	"A torn trail — Fresh claw marks. It has stopped running; the last sign leads to its cover."]
var game: Game
var zone := -1
var token := 0
var phase := TRACKING
var sign_index := 0
var points: Array[Vector2] = []
var origin := Vector2.ZERO
var quarry_point := Vector2.ZERO
var kind := "wolf"
var remaining := 0.0
var quarry: Variant
var signs: Array[Node2D] = []
var prompts: Array[Label] = []
var entries: Array[Dictionary] = []
var net_mirror := false
var status: Control
var clock := 0.0
var sync_time := 0.0
var world_id := 0
var chapter := ""
var seed := 0


static func find(g: Game, room: int) -> Node2D:
	for node in g.get_tree().get_nodes_in_group("road_hunts"):
		if node.game == g and node.zone == room and not node.is_queued_for_deletion():
			return node
	return null


static func active_in(g: Game) -> bool:
	for node in g.get_tree().get_nodes_in_group("road_hunts"):
		if node.game == g and node.phase < COMPLETE and not node.is_queued_for_deletion():
			return true
	return false


static func eligible(g: Game, room: int) -> bool:
	return Story.CHAPTER_LIST.has(g.chapter_id) and not g.pvp_active and not g.endgame_active \
		and room >= 0 and room < g.zones.size() and g.room_type(room) in ["social", "dead_end"]


static func quarry_kind(g: Game, room: int) -> String:
	var terrain := Terrains.get_terrain(String(g.terrain_by_zone[room]))
	return "duneprowler" if terrain.get("ground", "") == "sand" else ("wolf" if g.chapter_id == "ch1" else "blightwolf")


static func quarry_level(g: Game, room: int, enemy_kind: String) -> int:
	# Side rooms are appended after the spine, so array order is not progress.
	# Walk actual neighbors to find the nearest authored pack's power band.
	var floor_level := int(Story.ALL_ENEMIES.get(enemy_kind, {}).get("level", 1))
	var queue: Array[int] = [room]
	var visited := {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current) or current < 0 or current >= g.zones.size():
			continue
		visited[current] = true
		var packs: Array = g.zones[current].get("enemies", [])
		if not packs.is_empty():
			for spawn in packs:
				var native := int(Story.ALL_ENEMIES.get(String(spawn[0]), {}).get("level", 1))
				floor_level = maxi(floor_level, int(spawn[4]) if spawn.size() > 4 else native)
			break
		if current < g.rooms.size():
			for direction in g.rooms[current].get("exits", {}):
				queue.append(g.neighbor(current, String(direction)))
	return g.tiered_level(enemy_kind, floor_level + Balance.ROAD_HUNT_LEVEL_BONUS)


static func begin(g: Game, room: int, at: Vector2) -> Node2D:
	if g.net_guest() or not eligible(g, room) or active_in(g) or g._room_hot(room) or g.get_flag(g._road_flag(room), false) \
		or preload("res://scripts/encounter_context.gd").blocking_name(g, room) != "":
		return null
	var trail := new()
	trail.game = g
	trail.zone = room
	trail.token = Time.get_ticks_usec()
	trail.origin = at
	trail.kind = quarry_kind(g, room)
	var bounds := g.play_rect(room).grow(-Balance.ROAD_HUNT_INSET)
	var span := Vector2(minf(Balance.ROAD_HUNT_SPAN.x, bounds.size.x * 0.4), minf(Balance.ROAD_HUNT_SPAN.y, bounds.size.y * 0.4))
	var turn := -1.0 if (g.wander_seed + room) % 2 == 0 else 1.0
	for off in [Vector2(-span.x, -span.y), Vector2(span.x, -span.y * 0.35), Vector2(span.x * 0.55, span.y)]:
		var point: Vector2 = (g.room_center(room) + off * Vector2(turn, 1)).clamp(bounds.position, bounds.end)
		point = _place_sign(g, room, bounds, point, trail.points)
		if not point.is_finite():
			trail.free()
			return null  # no inaccessible track in an unusually crowded room
		trail.points.append(point)
	trail.quarry_point = g.free_spawn_pos(trail.points[-1] + Balance.ROAD_HUNT_QUARRY_OFFSET, trail.points[-1])
	g.world.add_child(trail)
	trail._broadcast()
	return trail


static func _place_sign(g: Game, room: int, bounds: Rect2, wanted: Vector2, used: Array[Vector2]) -> Vector2:
	# Keep a deterministic bend through the room, with nearby alternatives
	# when a cart, fence or rock occupies one of the preferred signs.
	for ring in 4:
		for spoke in 8:
			var offset := Vector2.from_angle(TAU * spoke / 8.0) * ring * Balance.ROAD_HUNT_SEARCH_STEP
			var candidate := g.free_spawn_pos((wanted + offset).clamp(bounds.position, bounds.end), g.room_center(room))
			if not bounds.has_point(candidate) or g._pos_in_wall(candidate):
				continue
			var close := false
			for point in used:
				if point.distance_to(candidate) < Balance.ROAD_HUNT_SIGN_SEPARATION:
					close = true
			if not close:
				return candidate
	return Vector2(INF, INF)


func _ready() -> void:
	world_id = game.world.get_instance_id()
	chapter = game.chapter_id
	seed = game.wander_seed
	add_to_group("road_hunts")
	add_to_group("optional_encounters")
	set_meta("encounter_title", "The Crooked Trail")
	z_index = -1  # floor signs sit below bodies, above ground art
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in points.size():
		var sign := Node2D.new()
		sign.position = points[i]
		add_child(sign)
		signs.append(sign)
		var prompt := Label.new()
		prompt.position = Vector2(-200, -62)
		prompt.size = Vector2(400, 28)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.z_index = 100
		UITheme.world(prompt, 15, 4)
		prompt.visible = false
		sign.add_child(prompt)
		prompts.append(prompt)
		var entry := {"node": sign, "prompt": prompt, "reach": 0.0, "action": _interact.bind(i)}
		entries.append(entry)
		game.interactables.append(entry)
	if is_instance_valid(game.hud):
		status = preload("res://scripts/ui/road_hunt.gd").status(game.hud)
	_refresh()


func valid_world() -> bool:
	return is_instance_valid(game) and is_instance_valid(game.world) and not is_queued_for_deletion() \
		and game.world.get_instance_id() == world_id and game.chapter_id == chapter and game.wander_seed == seed


func active() -> bool:
	return phase < COMPLETE and valid_world()


func _interact(index: int) -> void:
	if game.input_overlay_up():
		return
	request(game.local_player, index)


func request(source: Player, index: int) -> bool:
	if not valid_world() or phase != TRACKING or index != sign_index or not index in range(points.size()) \
		or (net_mirror and not game.net_guest()) \
		or not is_instance_valid(source) or source.dead or source.downed or source.ghost \
		or game.state != Game.ST_PLAYING or game.room_at_pos(source.global_position) != zone \
		or source.global_position.distance_to(points[index]) > Balance.ROAD_HUNT_INTERACT_RANGE:
		return false
	if game.net_guest():
		if source == game.local_player:
			game.net_session().request_road_hunt(zone, token, index)
		return false
	if index < points.size() - 1:
		sign_index += 1
		_announce(CLUES[index])
	else:
		phase = WARNING
		remaining = Balance.ROAD_HUNT_WARNING
		_announce("The cover stirs — The quarry is coming. Make room for its first rush.")
	_broadcast()
	_refresh()
	return true


func _spawn_quarry() -> void:
	phase = FIGHTING
	var at := quarry_point
	var level := quarry_level(game, zone, kind)
	var enemy := Enemy.make(game, kind, at, level)
	enemy.promote_elite()
	enemy.zone_idx = -1
	enemy.xp_value = 0
	enemy.gold_value = 0
	enemy.force_aggro = true
	enemy.set_meta("road_hunt_owner", self)
	quarry = enemy
	game.add_enemy(enemy)
	_broadcast()


func enemy_fell(enemy: Enemy) -> void:
	if game.net_guest() or not valid_world() or phase != FIGHTING \
		or enemy != quarry or not enemy.dying:
		return
	phase = COMPLETE  # consume before any callback/reward can re-enter
	remaining = Balance.ROAD_HUNT_COMPLETE_HOLD
	game.set_flag(game._road_flag(zone))
	game.run_road_cards += 1
	_broadcast()
	if game.net_host():
		game.net_session().host_road_hunt_reward(self)
	if eligible_recipient(game.local_player):
		reward()
	game.autosave()
	_refresh()


func eligible_recipient(source: Player) -> bool:
	return is_instance_valid(source) and not source.dead and not source.ghost \
		and game.room_at_pos(source.global_position) == zone


func receipt() -> String:
	return "sq_kept_road_hunt_%s_%d_%d" % [chapter, seed, zone]


func reward() -> bool:
	if not valid_world() or phase != COMPLETE or not game.has_local_player() or game.get_flag(receipt(), false):
		return false
	game.set_flag(receipt())  # character history; never imported from the host
	var gold := int(ceil(Balance.ROAD_HUNT_GOLD * Balance.daily_gold_mult(game.player.level)))
	var paid := game.player.gold_yield(gold)
	game.player.gain_gold(gold)
	game.sfx("coin")
	_announce("The Crooked Trail — Quarry felled. The hunter's purse adds %d gold." % paid)
	game.autosave()
	return true


func cancel() -> void:
	if game.net_guest() or phase == CLOSED:
		return
	phase = CLOSED
	_cleanup_quarry()
	_broadcast()
	queue_free()


func _physics_process(delta: float) -> void:
	clock += delta
	if not valid_world() or (net_mirror and not game.net_guest()):
		queue_free()
		return
	if not game.net_guest():
		var present := false
		for source in game.players:
			if eligible_recipient(source) and not source.downed:
				present = true
		if (not present or game.state != Game.ST_PLAYING) and phase < COMPLETE:
			cancel()
			return
		if phase == WARNING:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				_spawn_quarry()
		elif phase == FIGHTING and (not is_instance_valid(quarry) or quarry.is_queued_for_deletion()):
			cancel()  # deletion is not a witnessed kill
			return
		elif phase == COMPLETE:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				cancel()
				return
		sync_time += delta
		if sync_time >= Balance.ROAD_HUNT_SYNC_SECONDS:
			sync_time = 0.0
			_broadcast()
	_refresh()
	queue_redraw()


func snapshot() -> Dictionary:
	return {"zone": zone, "token": token, "phase": phase, "sign": sign_index,
		"points": points, "origin": origin, "quarry_point": quarry_point, "kind": kind, "remaining": remaining}


static func clean_snapshot(g: Game, raw: Dictionary) -> Dictionary:
	for key in ["zone", "token", "phase", "sign"]:
		if not raw.get(key) is int:
			return {}
	if not eligible(g, raw.zone) or raw.token <= 0 or not raw.phase in range(CLOSED + 1) \
		or not raw.sign in range(3) or not raw.get("kind") in KINDS \
		or not raw.get("points") is Array or raw.points.size() != 3 \
		or not raw.get("origin") is Vector2 or not raw.origin.is_finite() \
		or not raw.get("quarry_point") is Vector2 or not raw.quarry_point.is_finite() \
		or not (raw.get("remaining") is float or raw.get("remaining") is int):
		return {}
	var bounds := g.play_rect(raw.zone)
	if not bounds.has_point(raw.origin) or not bounds.has_point(raw.quarry_point) or not is_finite(float(raw.remaining)) \
		or raw.remaining < 0.0 or raw.remaining > Balance.ROAD_HUNT_COMPLETE_HOLD:
		return {}
	if (raw.phase in [WARNING, FIGHTING, COMPLETE] and raw.sign != 2) \
		or (raw.phase == WARNING and raw.remaining > Balance.ROAD_HUNT_WARNING) \
		or (raw.phase in [TRACKING, FIGHTING] and raw.remaining != 0.0):
		return {}
	for point in raw.points:
		if not point is Vector2 or not point.is_finite() or not bounds.has_point(point):
			return {}
	return raw.duplicate(true)


static func receive(g: Game, raw: Dictionary) -> Node2D:
	var block := clean_snapshot(g, raw)
	if block.is_empty():
		return null
	var trail := find(g, block.zone)
	if trail != null and trail.token > block.token:
		return trail
	if trail != null and trail.token != block.token:
		trail.queue_free()
		trail = null
	if block.phase == CLOSED:
		if trail != null:
			trail.queue_free()
		return null
	var initial := trail == null
	if initial:
		trail = new()
		trail.game = g
		trail.zone = block.zone
		trail.token = block.token
		trail.points.assign(block.points)
		trail.origin = block.origin
		trail.quarry_point = block.quarry_point
		trail.net_mirror = true
		trail.kind = block.kind
		trail.phase = block.phase
		trail.sign_index = block.sign
		g.world.add_child(trail)
	# Reliable ordered snapshots may be repeated, but cannot rewind a trail.
	if block.phase >= trail.phase and block.sign >= trail.sign_index:
		var prior_phase: int = trail.phase
		var prior_sign: int = trail.sign_index
		trail.phase = block.phase
		trail.sign_index = block.sign
		trail.remaining = float(block.remaining)
		trail._refresh()
		if not initial:
			if trail.phase == TRACKING and trail.sign_index > prior_sign:
				trail._announce(CLUES[trail.sign_index - 1])
			elif trail.phase == WARNING and prior_phase == TRACKING:
				trail._announce("The cover stirs — The quarry is coming. Make room for its first rush.")
	return trail


func _broadcast() -> void:
	if game.net_host():
		game.net_session().host_road_hunt_state(self)


func _announce(text: String) -> void:
	if game.has_local_player() and game.cur_room == zone:
		game.hud.announce(text, UITheme.GOLD_BRIGHT)


func _refresh() -> void:
	for i in signs.size():
		signs[i].visible = phase == TRACKING and i == sign_index
		entries[i]["reach"] = Balance.ROAD_HUNT_INTERACT_RANGE if signs[i].visible else 0.0
		prompts[i].text = game.touchify("E — Read the tracks" if i < points.size() - 1 else "E — Flush the quarry")
	if is_instance_valid(status):
		preload("res://scripts/ui/road_hunt.gd").refresh(status, self)


func _cleanup_quarry() -> void:
	if is_instance_valid(quarry) and not quarry.dying:
		quarry.remove_from_group("enemies")
		quarry.queue_free()
	quarry = null


func _exit_tree() -> void:
	_cleanup_quarry()
	if is_instance_valid(status):
		status.queue_free()
	if is_instance_valid(game):
		for entry in game.interactables.duplicate():
			if entry.get("node") in signs:
				game.interactables.erase(entry)


func _draw() -> void:
	if points.is_empty() or phase >= COMPLETE:
		return
	var at := points[sign_index]
	var start := origin if sign_index == 0 else points[sign_index - 1]
	var color := Color(0.94, 0.80, 0.48, 0.75)
	if phase == TRACKING:
		var steps := maxi(2, int(start.distance_to(at) / Balance.ROAD_HUNT_TRACK_GAP))
		var direction := (at - start).angle()
		for i in range(1, steps + 1):
			var point := start.lerp(at, float(i) / steps) + Vector2.from_angle(direction + PI * 0.5) * (7 if i % 2 == 0 else -7)
			draw_set_transform(point, direction + PI * 0.5, Vector2.ONE)
			var extent := Vector2.ONE * Balance.ROAD_HUNT_TRACK_SIZE
			draw_texture_rect(TRACK, Rect2(-extent * 0.5, extent), false, Color(1, 1, 1, 0.9))
			draw_set_transform(Vector2.ZERO)
		draw_arc(at, 30, 0, TAU, 40, color, 2.0, true)
		draw_arc(at, 35, -PI * 0.25, PI * 0.75, 24, Color(color, 0.3), 1.0, true)
	elif phase == WARNING:
		var radius := 36 + 18 * (1.0 - remaining / Balance.ROAD_HUNT_WARNING)
		draw_arc(quarry_point, radius, 0, TAU, 48, Color(1.0, 0.48, 0.3, 0.9), 3, true)
