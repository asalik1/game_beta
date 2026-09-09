extends Node2D
## Host-owned work and combat. World trade benefit; no personal purse or XP.
const PREPARING := 0
const WORKING := 1
const COMPLETE := 2
const CLOSED := 3
const ART := preload("res://assets/sprites/road_caravan_cart.png")
const Hunt := preload("res://scripts/road_hunt.gd")
const Context := preload("res://scripts/encounter_context.gd")
var game: Game
var zone := -1
var token := 0
var revision := 0
var phase := PREPARING
var wave := 0
var tugs := 0
var integrity := Balance.CARAVAN_INTEGRITY
var remaining := 0.0
var pressure := 0
var enemies: Array[Enemy] = []
var pending_deaths: Array[int] = []
var arrival_points: Array[Vector2] = []
var kind := "wolf"
var level := 1
var net_mirror := false
var world_id := 0
var chapter := ""
var seed := 0
var clock := 0.0
var sync_time := 0.0
var next_tug := 0.0
var next_notice := 0.0
var handle: Node2D
var prompt: Label
var status: Control
var entry := {}
var mirror_foes := 0


static func benefit_flag(g: Game) -> String:
	return "road_caravan_%s_%d" % [g.chapter_id, g.wander_seed]


static func supplied(g: Game) -> bool:
	return Story.CHAPTER_LIST.has(g.chapter_id) and not g.endgame_active \
		and not g.pvp_active and g.get_flag(benefit_flag(g), false)


static func find(g: Game, room: int) -> Node2D:
	for cart in g.get_tree().get_nodes_in_group("road_caravans"):
		if cart.game == g and cart.zone == room and cart.valid_world():
			return cart
	return null


static func active_in(g: Game) -> bool:
	for cart in g.get_tree().get_nodes_in_group("road_caravans"):
		if cart.game == g and cart.active():
			return true
	return false


static func placement(g: Game, room: int) -> Vector2:
	var bounds := g.play_rect(room).grow(-Balance.CARAVAN_INSET)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return Vector2(INF, INF)
	# Try clear points around the middle, leaving the entrances open. The
	# handle and cart footprint must be usable, not just the anchor pixel.
	for ring in 4:
		for spoke in (1 if ring == 0 else 8):
			var point := (g.room_center(room) + Vector2.from_angle(TAU * spoke / 8.0) \
				* ring * Balance.CARAVAN_PLACEMENT_STEP).clamp(bounds.position, bounds.end)
			if _placement_clear(g, room, point):
				return point
	# Offset room floors can put the nominal center beside one edge. Search
	# the remaining safe interior when that small circle is crowded.
	var columns := maxi(1, ceili(bounds.size.x / Balance.CARAVAN_PLACEMENT_STEP))
	var rows := maxi(1, ceili(bounds.size.y / Balance.CARAVAN_PLACEMENT_STEP))
	for row in rows + 1:
		for column in columns + 1:
			var point := bounds.position + bounds.size * Vector2(float(column) / columns, float(row) / rows)
			if _placement_clear(g, room, point):
				return point
	return Vector2(INF, INF)


static func _placement_clear(g: Game, room: int, point: Vector2) -> bool:
	for interaction in g.interactables:
		var actor: Variant = interaction.get("node")
		if is_instance_valid(actor) and actor is Node2D and not actor.is_queued_for_deletion() \
			and float(interaction.get("reach", Balance.INTERACT_RANGE)) > 0.0 \
			and actor.global_position.distance_to(point + Balance.CARAVAN_HANDLE_OFFSET) < Balance.CARAVAN_INTERACTION_CLEARANCE:
			return false
	for offset in [Vector2.ZERO, Balance.CARAVAN_HANDLE_OFFSET,
		Vector2(-100, -50), Vector2(80, -50), Vector2(-100, 70), Vector2(80, 70)]:
		var sample: Vector2 = point + offset
		if g._pos_in_wall(sample) or g.free_spawn_pos(sample, g.room_center(room)).distance_to(sample) > 1.0:
			return false
	return true


static func begin(g: Game, room: int) -> Node2D:
	if g.net_guest() or not Hunt.eligible(g, room) or supplied(g) or active_in(g) \
		or g._room_hot(room) or g.get_flag(g._road_flag(room), false) \
		or Context.blocking_name(g, room) != "":
		return null
	var point := placement(g, room)
	if not point.is_finite():
		return null
	var cart := new()
	cart.game = g
	cart.zone = room
	cart.token = Time.get_ticks_usec()
	cart.position = point
	cart.kind = Hunt.quarry_kind(g, room)
	cart.level = Hunt.quarry_level(g, room, cart.kind)
	g.world.add_child(cart)
	cart._prepare_wave()
	return cart


func _ready() -> void:
	world_id = game.world.get_instance_id()
	chapter = game.chapter_id
	seed = game.wander_seed
	add_to_group("road_caravans")
	add_to_group("optional_encounters")
	set_meta("encounter_title", "the stalled caravan")
	var body := Sprite2D.new()
	body.name = "CaravanBody"
	body.texture = ART
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.scale = Vector2.ONE * Balance.CARAVAN_ART_WIDTH / ART.get_width()
	body.position = (Vector2(0.5, 0.5) - Vector2(0.59, 0.76)) * Balance.CARAVAN_ART_WIDTH
	add_child(body)
	# The cart root owns its y-sort anchor; the art is raised above that base.
	body.set_meta("occlusion_sort_y", global_position.y)
	body.set_meta("occlusion_radius", (body.get_rect().size * body.scale).length() * 0.5)
	body.add_to_group("structure_occluders")
	handle = Node2D.new()
	handle.position = Balance.CARAVAN_HANDLE_OFFSET
	add_child(handle)
	prompt = Label.new()
	prompt.position = Vector2(-180, 26)
	prompt.size = Vector2(360, 26)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.z_index = 100
	UITheme.world(prompt, 14, 4)
	prompt.visible = false
	handle.add_child(prompt)
	entry = {"node": handle, "prompt": prompt, "reach": 0.0, "action": _interact}
	game.interactables.append(entry)
	if is_instance_valid(game.hud):
		status = preload("res://scripts/ui/road_caravan.gd").status(game.hud)
	_refresh()


func valid_world() -> bool:
	return is_instance_valid(game) and is_instance_valid(game.world) and not is_queued_for_deletion() \
		and game.world.get_instance_id() == world_id and game.chapter_id == chapter and game.wander_seed == seed


func active() -> bool:
	return phase < COMPLETE and valid_world()


func _interact() -> void:
	if not game.input_overlay_up():
		request(game.local_player)


func can_help(source: Player) -> bool:
	return valid_world() and phase == WORKING and not (net_mirror and not game.net_guest()) \
		and is_instance_valid(source) and not source.dead and not source.downed and not source.ghost \
		and game.state == Game.ST_PLAYING and game.room_at_pos(source.global_position) == zone \
		and source.global_position.distance_to(handle.global_position) <= Balance.CARAVAN_INTERACT_RANGE


func request(source: Player) -> bool:
	if not can_help(source):
		return false
	if game.net_guest():
		if source == game.local_player:
			game.net_session().request_road_caravan(zone, token)
		return false
	if tugs >= wave * Balance.CARAVAN_TUGS / Balance.CARAVAN_WAVES.size() or clock < next_tug:
		return false
	pressure = _pressure()
	if pressure > 0:
		if source == game.local_player and clock >= next_notice:
			next_notice = clock + Balance.CARAVAN_NOTICE_INTERVAL
			_announce("The load is under attack — Draw the creatures away before pulling.")
		return false
	next_tug = clock + Balance.CARAVAN_TUG_INTERVAL
	tugs += 1
	game.sfx("gate", 1.2)
	_advance()
	_broadcast()
	_refresh()
	return true


func _prepare_wave() -> void:
	wave += 1
	phase = PREPARING
	remaining = Balance.CARAVAN_WARNING_SECONDS
	arrival_points.clear()
	enemies.clear()
	pending_deaths.clear()
	var bounds := game.play_rect(zone).grow(-Balance.CARAVAN_SPAWN_INSET)
	for i in Balance.CARAVAN_WAVES[wave - 1]:
		var angle: float = -PI * 0.5 + i * TAU / Balance.CARAVAN_WAVES[wave - 1] + wave * 0.7
		var point := (global_position + Vector2.from_angle(angle) * Balance.CARAVAN_SPAWN_RADIUS).clamp(bounds.position, bounds.end)
		arrival_points.append(game.free_spawn_pos(point, global_position))
	_announce("A Wheel in the Mud — %s" % ("Keep them off the load. Pull at the shafts when it is clear." if wave == 1 else "Halfway free. More creatures are coming!"))
	_broadcast()
	_refresh()


func _spawn_wave() -> void:
	phase = WORKING
	remaining = 0.0
	for point in arrival_points:
		var enemy := Enemy.make(game, kind, point, level)
		enemy.zone_idx = -1
		enemy.xp_value = 0
		enemy.gold_value = 0
		enemy.force_aggro = true
		enemy.set_meta("road_caravan_owner", self)
		enemies.append(enemy)
		pending_deaths.append(enemy.get_instance_id())
		game.add_enemy(enemy)
	arrival_points.clear()
	_broadcast()


func enemy_fell(enemy: Enemy) -> void:
	if game.net_guest() or not active() or phase != WORKING or not enemy.dying \
		or not pending_deaths.has(enemy.get_instance_id()):
		return
	pending_deaths.erase(enemy.get_instance_id())
	_advance()
	_broadcast()


func _advance() -> void:
	if phase != WORKING or not pending_deaths.is_empty():
		return
	if tugs >= Balance.CARAVAN_TUGS:
		phase = COMPLETE
		remaining = Balance.CARAVAN_COMPLETE_HOLD
		game.set_flag(benefit_flag(game))
		game.set_flag(game._road_flag(zone))
		game.run_road_cards += 1
		_announce("The wheel is free — Road merchants offer 20% off equipment and supplies for this chapter's run.")
		game.autosave()
	elif wave < Balance.CARAVAN_WAVES.size() and tugs >= wave * Balance.CARAVAN_TUGS / Balance.CARAVAN_WAVES.size():
		_prepare_wave()


func _pressure() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dying and not enemy.is_queued_for_deletion() \
			and enemy.global_position.distance_to(global_position) <= Balance.CARAVAN_PRESSURE_RADIUS:
			count += 1
	return count


func _physics_process(delta: float) -> void:
	clock += delta
	if not valid_world() or (net_mirror and not game.net_guest()):
		queue_free()
		return
	if not game.net_guest():
		var present := false
		for source in game.players:
			if is_instance_valid(source) and not source.dead and not source.downed and not source.ghost \
				and game.room_at_pos(source.global_position) == zone:
				present = true
		if active() and (not present or game.state != Game.ST_PLAYING):
			cancel()
			return
		if phase == PREPARING:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				_spawn_wave()
		elif phase == WORKING:
			for id in pending_deaths:
				var enemy: Variant = instance_from_id(id)
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					cancel()  # removal is not a death; never settle a missing wave
					return
			pressure = _pressure()
			integrity = maxf(0.0, integrity - mini(pressure, Balance.CARAVAN_PRESSURE_CAP) * Balance.CARAVAN_PRESSURE_DRAIN * delta)
			if integrity <= 0.0:
				cancel("The load is lost — The trader retreats. No extra gold or standing is lost.")
				return
		elif phase == COMPLETE:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				cancel()
				return
		sync_time += delta
		if sync_time >= Balance.CARAVAN_SYNC_SECONDS:
			sync_time = 0.0
			_broadcast()
	_refresh()
	queue_redraw()


func cancel(message := "") -> void:
	if game.net_guest() or phase == CLOSED:
		return
	phase = CLOSED
	_cleanup_enemies()
	_broadcast()
	if message != "":
		_announce(message)
	queue_free()


func snapshot() -> Dictionary:
	return {"zone": zone, "token": token, "revision": revision, "phase": phase, "wave": wave,
		"tugs": tugs, "integrity": integrity, "remaining": remaining, "pressure": pressure,
		"at": global_position, "points": arrival_points.duplicate(), "kind": kind, "level": level,
		"foes": pending_deaths.size()}


static func clean_snapshot(g: Game, raw: Dictionary) -> Dictionary:
	for key in ["zone", "token", "revision", "phase", "wave", "tugs", "pressure", "level", "foes"]:
		if not raw.get(key) is int:
			return {}
	for key in ["integrity", "remaining"]:
		if not (raw.get(key) is float or raw.get(key) is int) or not is_finite(float(raw[key])):
			return {}
	if not Hunt.eligible(g, raw.zone) or raw.token <= 0 or raw.revision < 0 \
		or not raw.phase in range(CLOSED + 1) or not raw.wave in range(1, Balance.CARAVAN_WAVES.size() + 1) \
		or not raw.tugs in range(Balance.CARAVAN_TUGS + 1) or not raw.kind in Hunt.KINDS \
		or raw.level < 1 or raw.level > Balance.NET_LEVEL_CAP or not raw.pressure in range(4) or not raw.foes in range(4) \
		or raw.integrity < 0.0 or raw.integrity > Balance.CARAVAN_INTEGRITY \
		or raw.remaining < 0.0 or raw.remaining > Balance.CARAVAN_COMPLETE_HOLD \
		or not raw.get("at") is Vector2 or not raw.at.is_finite() or not g.play_rect(raw.zone).has_point(raw.at) \
		or not raw.get("points") is Array or raw.points.size() > 3:
		return {}
	if raw.phase == PREPARING and (raw.remaining > Balance.CARAVAN_WARNING_SECONDS \
		or raw.points.size() != Balance.CARAVAN_WAVES[raw.wave - 1] or raw.foes != 0):
		return {}
	if raw.phase == WORKING and (raw.remaining != 0.0 or not raw.points.is_empty()):
		return {}
	if raw.phase == COMPLETE and (raw.tugs != Balance.CARAVAN_TUGS or raw.foes != 0):
		return {}
	for point in raw.points:
		if not point is Vector2 or not point.is_finite() or not g.play_rect(raw.zone).has_point(point):
			return {}
	return raw.duplicate(true)


static func receive(g: Game, raw: Dictionary) -> Node2D:
	var block := clean_snapshot(g, raw)
	if block.is_empty():
		return null
	var cart := find(g, block.zone)
	if cart != null and (cart.token > block.token or (cart.token == block.token and cart.revision >= block.revision)):
		return cart
	if cart != null and cart.token != block.token:
		cart.queue_free()
		cart = null
	if block.phase == CLOSED:
		if cart != null:
			cart.queue_free()
		return null
	var initial := cart == null
	if initial:
		cart = new()
		cart.game = g
		cart.zone = block.zone
		cart.token = block.token
		cart.position = block.at
		cart.net_mirror = true
		g.world.add_child(cart)
	var prior_wave: int = cart.wave
	var prior_phase: int = cart.phase
	for field in ["revision", "phase", "wave", "tugs", "integrity", "remaining", "pressure", "kind", "level"]:
		cart.set(field, block[field])
	cart.arrival_points.assign(block.points)
	cart.mirror_foes = block.foes
	cart._refresh()
	if not initial:
		if cart.phase == PREPARING and cart.wave > prior_wave:
			cart._announce("Halfway free — More creatures are coming!")
		elif cart.phase == COMPLETE and prior_phase != COMPLETE:
			cart._announce("The wheel is free — Road merchants offer 20% off equipment and supplies for this chapter's run.")
	return cart


func _broadcast() -> void:
	revision += 1
	if game.net_host():
		game.net_session().host_road_caravan_state(self)


func _announce(message: String) -> void:
	if game.has_local_player() and game.cur_room == zone:
		game.hud.announce(message, UITheme.GOLD_BRIGHT)


func _refresh() -> void:
	entry["reach"] = Balance.CARAVAN_INTERACT_RANGE if phase == WORKING else 0.0
	prompt.text = game.touchify("Hold E — Pull the cart") if pressure == 0 else "Drive them off the load"
	if is_instance_valid(status):
		preload("res://scripts/ui/road_caravan.gd").refresh(status, self)


func _cleanup_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dying:
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	enemies.clear()
	pending_deaths.clear()


func _exit_tree() -> void:
	_cleanup_enemies()
	if is_instance_valid(status):
		status.queue_free()
	if is_instance_valid(game):
		game.interactables.erase(entry)


func _draw() -> void:
	if phase == PREPARING:
		for point in arrival_points:
			draw_arc(to_local(point), 38, 0, TAU, 36, Color(1.0, 0.48, 0.3, 0.9), 3.0, true)
	elif phase == WORKING:
		var color := Color(1.0, 0.45, 0.3, 0.8) if pressure > 0 else Color(0.72, 0.92, 0.74, 0.6)
		draw_arc(Balance.CARAVAN_HANDLE_OFFSET, 27, 0, TAU, 36, color, 2.0, true)
