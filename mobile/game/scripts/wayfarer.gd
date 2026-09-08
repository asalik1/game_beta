extends Node2D
## A host-owned road escort. Resolve is pressure, not an extra damage target:
## normal monsters fight the party; the traveler needs space and company.
const DONE := "escort_tovin_home"
const KEPT := "sq_kept_wayfarer"
const WAVES := [["wolf", "wolf"], ["wolf", "wolf", "spider"]]
var game: Game
var zone := -1
var phase := 0  # resting / walking / warning / fighting / home
var stage := 0
var resolve := Balance.ESCORT_RESOLVE
var remaining := 0.0
var waiting := false
var guarded := false
var pressure := 0
var moving := false
var age := 0.0
var sync_time := 0.0
var start := Vector2.ZERO
var goal := Vector2.ZERO
var arrival_points: Array[Vector2] = []
var enemies: Array[Enemy] = []
var body: Sprite2D
var prompt: Label
var caption: Label
var status: Control
var camp: Node2D
var _awarded := false
var _net_at := Vector2.ZERO
var _mark_anchor: Node2D


static func eligible(g: Game, zi: int) -> bool:
	return g.chapter_id == "ch1" and not g.pvp_active and not g.endgame_active and not g.weekly_active \
		and zi >= 0 and zi < g.zones.size() and String(g.zones[zi].name) == "Village Outskirts"


static func route(g: Game, zi: int) -> Array[Vector2]:
	var bounds := g.play_rect(zi).grow(-Balance.ESCORT_ROUTE_INSET)
	var center := g.room_center(zi)
	return [(center + Vector2(-Balance.ESCORT_ROUTE_HALF, Balance.ESCORT_ROUTE_Y)).clamp(bounds.position, bounds.end),
		(center + Vector2(Balance.ESCORT_ROUTE_HALF, Balance.ESCORT_ROUTE_Y)).clamp(bounds.position, bounds.end)]


static func install(g: Game, zi: int) -> Node2D:
	if not eligible(g, zi):
		return null
	var v := new()
	v.game = g
	v.zone = zi
	var points := route(g, zi)
	v.start = points[0]
	v.goal = points[1]
	if not g.net_guest() and g.get_flag(KEPT, false) and not g.get_flag(DONE, false):
		g.set_flag(DONE)
	v.phase = 4 if g.get_flag(DONE, false) else 0
	v.position = v.goal if v.phase == 4 else v.start
	g.world.add_child(v)
	g.zone_scenery[zi].append(v)
	return v


static func find(g: Game) -> Node2D:
	for v in g.get_tree().get_nodes_in_group("wayfarers"):
		if v.game == g and not v.is_queued_for_deletion():
			return v
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("wayfarers")
	add_to_group("optional_encounters")
	set_meta("encounter_title", "One More Mile")
	set_meta("quest_convo", "wayfarer_tovin")
	set_meta("quest_flag", DONE)
	body = Sprite2D.new()
	body.texture = load("res://assets/sprites/wayfarer_walk.png")
	body.hframes = maxi(1, body.texture.get_width() / body.texture.get_height())
	body.frame = 1
	body.scale = Art.scale_for_alpha_height(body.texture, Balance.ESCORT_BODY_HEIGHT, body.hframes)
	body.offset.y = -Art.alpha_feet_offset(body.texture, 1.0, body.hframes)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(body)
	if DisplayServer.get_name() != "headless":
		game.cast_shadow_for(self, body)
	prompt = _label(-122, 14)
	prompt.visible = false
	caption = _label(-101, 13)
	if is_instance_valid(game.hud):
		status = preload("res://scripts/ui/wayfarer.gd").status(game.hud)
	game.interactables.append({"node": self, "prompt": prompt, "action": interact})
	game._quest_avail_cache = -1
	_mark_anchor = Node2D.new()
	_mark_anchor.position.y = -56
	add_child(_mark_anchor)
	game._mark_quest_giver(_mark_anchor, "wayfarer_tovin")
	_net_at = global_position
	# The destination is a genuine campfire, with the established art/light seam.
	camp = game._add_building("camp_bonfire", goal + Vector2(74, -18))
	game.zone_scenery[zone].append(camp)
	_refresh()


func _label(y: float, pixels: int) -> Label:
	var label := Label.new()
	label.position = Vector2(-180, y)
	label.size = Vector2(360, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(label, pixels, 4)
	add_child(label)
	return label


func active() -> bool:
	return phase in [1, 2, 3]


func interact() -> void:
	if game.input_overlay_up():
		return
	if phase == 4 or (phase == 0 and not game.get_flag("sq_on_one_more_mile", false)):
		game.run_convo_id("wayfarer_tovin")
	else:
		preload("res://scripts/ui/wayfarer.gd").open(game.menus, self)


func request(source: Player, action: String) -> bool:
	if is_queued_for_deletion() or not eligible(game, zone) or not is_instance_valid(source) \
		or source.dead or source.downed or source.ghost or game.state != Game.ST_PLAYING \
		or game.room_at_pos(source.global_position) != zone \
		or source.global_position.distance_to(global_position) > Balance.INTERACT_RANGE \
		or not action in ["start", "wait", "follow", "stop"]:
		return false
	if action == "start" and not preload("res://scripts/encounter_context.gd").may_start(game, zone, source, self):
		return false
	if game.net_guest():
		if source == game.local_player:
			game.net_session().request_escort(action)
		return false
	if action == "start" and phase == 0 and not game._room_hot(zone):
		game.set_flag("sq_on_one_more_mile")
		phase = 1
		stage = 0
		resolve = Balance.ESCORT_RESOLVE
		waiting = false
		global_position = start
	elif action == "stop" and active():
		cancel("Tovin returns to the roadside — You can try the walk again.")
		return true
	elif action in ["wait", "follow"] and active():
		waiting = action == "wait"
	else:
		return false
	_broadcast()
	_refresh()
	return true


func progress() -> float:
	return clampf((global_position.x - start.x) / maxf(goal.x - start.x, 1.0), 0.0, 1.0)


func _prepare() -> void:
	phase = 2
	remaining = Balance.ESCORT_WARNING_SECONDS
	stage += 1
	arrival_points.clear()
	var bounds := game.play_rect(zone).grow(-Balance.ESCORT_ROUTE_INSET)
	for i in WAVES[stage - 1].size():
		var angle: float = -PI * 0.5 + i * PI / 3.0
		var p := (global_position + Vector2.from_angle(angle) * Balance.ESCORT_SPAWN_RADIUS).clamp(bounds.position, bounds.end)
		arrival_points.append(game.free_spawn_pos(p, global_position))
	game.hud.announce("Movement at the treeline — Stay with Tovin. The arrival marks give you time to prepare.", Color(1.0, 0.8, 0.45), 2.0)
	_broadcast()


func _spawn_wave() -> void:
	phase = 3
	for i in WAVES[stage - 1].size():
		var e := Enemy.make(game, WAVES[stage - 1][i], arrival_points[i], Balance.ESCORT_ENEMY_LEVEL)
		e.zone_idx = -1
		e.xp_value = 0
		e.gold_value = 0
		e.force_aggro = true
		e.set_meta("escort_spawn", true)
		game.add_enemy(e)
		enemies.append(e)
		game.burst(e.global_position, Color(0.76, 0.69, 0.43), 10)
	arrival_points.clear()
	_broadcast()


func _living() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and not e.dying and not e.is_queued_for_deletion():
			alive.append(e)
	return alive


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if phase != 4 and game.get_flag(DONE, false):
		phase = 4
		global_position = goal
		moving = false
	if phase == 4 and not _awarded:
		_awarded = true
		if game.has_local_player():
			game.unlock_achievement("road_company")
	if active() and not game.net_guest():
		var present := false
		guarded = false
		for p: Player in game.players:
			if is_instance_valid(p) and not p.dead and not p.downed and not p.ghost \
				and game.room_at_pos(p.global_position) == zone:
				present = true
				if p.global_position.distance_to(global_position) <= Balance.ESCORT_COMPANY_RANGE:
					guarded = true
		if not present or game.state != Game.ST_PLAYING:
			cancel("")
			return
		moving = false
		if phase == 1:
			if guarded and not waiting:
				global_position = global_position.move_toward(goal, Balance.ESCORT_WALK_SPEED * delta)
				moving = true
			if stage < WAVES.size() and progress() >= Balance.ESCORT_CHECKPOINTS[stage]:
				moving = false
				_prepare()
			elif global_position.distance_to(goal) <= 1.0 and stage == WAVES.size():
				complete()
		elif phase == 2:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				_spawn_wave()
		elif phase == 3:
			var living := _living()
			pressure = 0
			for e in living:
				if e.global_position.distance_to(global_position) <= Balance.ESCORT_PRESSURE_RANGE:
					pressure += 1
			resolve = maxf(0.0, resolve - delta * ((0.0 if guarded else Balance.ESCORT_ABSENT_DRAIN) \
				+ mini(pressure, Balance.ESCORT_PRESSURE_CAP) * Balance.ESCORT_ENEMY_DRAIN))
			if resolve <= 0.0:
				cancel("Tovin loses his nerve — Keep him company and keep the creatures away. He is safe at the roadside; you can try again.")
			elif living.is_empty():
				phase = 1
				resolve = minf(Balance.ESCORT_RESOLVE, resolve + Balance.ESCORT_STAGE_MEND)
				pressure = 0
				_broadcast()
		sync_time += delta
		if sync_time >= Balance.ESCORT_SYNC_SECONDS:
			sync_time = 0.0
			_broadcast()
	elif active() and game.net_guest():
		global_position = global_position.lerp(_net_at, 1.0 - exp(-Balance.ESCORT_NET_SMOOTH * delta))
	if moving:
		age += delta * Balance.ESCORT_WALK_FPS
		body.frame = int(age) % body.hframes
	else:
		age = 0.0
		body.frame = 1
	_refresh()
	queue_redraw()


func complete() -> void:
	if game.net_guest() or not active() or stage != WAVES.size() or not _living().is_empty() \
		or global_position.distance_to(goal) > 1.0:
		return
	phase = 4
	moving = false
	waiting = false
	global_position = goal
	_cleanup()
	game.set_flag(DONE)
	_broadcast()
	game.hud.announce("One more mile — Tovin has reached the fire. Speak with him before you go.", Color(0.81, 0.94, 0.71))
	game.autosave()


func cancel(message: String) -> void:
	if game.net_guest() or not active():
		return
	_cleanup()
	phase = 0
	stage = 0
	resolve = Balance.ESCORT_RESOLVE
	remaining = 0.0
	pressure = 0
	moving = false
	waiting = false
	global_position = start
	arrival_points.clear()
	_broadcast()
	_refresh()
	if message != "" and game.cur_room == zone:
		game.hud.announce(message, Color(1.0, 0.8, 0.45))


func _cleanup() -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.dying:
			e.remove_from_group("enemies")
			e.queue_free()
	enemies.clear()


func _broadcast() -> void:
	if game.net_host():
		game.net_session().host_escort_state(self)


func apply_state(next: int, checkpoint: int, nerve: float, timer: float, hold: bool, company: bool,
		threats: int, at: Vector2, walking: bool, points: Array) -> void:
	if not next in [0, 1, 2, 3, 4] or checkpoint < 0 or checkpoint > WAVES.size() \
		or not is_finite(nerve) or nerve < 0.0 or nerve > Balance.ESCORT_RESOLVE \
		or not is_finite(timer) or timer < 0.0 or timer > Balance.ESCORT_WARNING_SECONDS \
		or threats < 0 or threats > Balance.ESCORT_PRESSURE_CAP \
		or not at.is_finite() or absf(at.y - start.y) > 1.0 or at.x < start.x or at.x > goal.x \
		or points.size() > Balance.ESCORT_PRESSURE_CAP:
		return
	for p in points:
		if not p is Vector2 or not p.is_finite() or not game.play_rect(zone).has_point(p):
			return
	var snap := not active() or not next in [1, 2, 3]
	phase = next
	stage = checkpoint
	resolve = nerve
	remaining = timer
	waiting = hold
	guarded = company
	pressure = threats
	_net_at = at
	if snap or not game.net_guest():
		global_position = at
	moving = walking
	arrival_points.assign(points)
	_refresh()
	queue_redraw()


func _refresh() -> void:
	if not is_instance_valid(caption):
		return
	prompt.text = game.touchify("E — " + ("Talk by the fire" if phase == 4 else "Wait / follow / stop" if active() else "Talk to Tovin"))
	caption.text = "Tovin · home at last" if phase == 4 else "Tovin · a short road home"
	caption.visible = game.cur_room == zone and not game.input_overlay_up() and not active() \
		and game.has_local_player() and game.local_player.global_position.distance_to(global_position) < Balance.ESCORT_LABEL_RANGE
	# Near room edges the camera cannot center the actors. Keep their words
	# outside the fixed hero HUD and the encounter card beneath it.
	var screen := get_global_transform_with_canvas()
	var above := screen * Vector2(0, -122)
	var left_hud := above.x < 520.0 and above.y < (350.0 if active() else 230.0)
	var right_hud := above.x > game.get_viewport_rect().size.x - 380.0 and above.y < 400.0
	var below := above.y < Balance.ESCORT_LABEL_HUD_MARGIN or left_hud
	prompt.position.x = -430.0 if right_hud else -180.0
	caption.position.x = prompt.position.x
	prompt.position.y = 112.0 if below else -122.0
	caption.position.y = 138.0 if below else -101.0
	if is_instance_valid(_mark_anchor):
		_mark_anchor.position.y = 174.0 if below else -56.0
	if is_instance_valid(status):
		status.visible = active() and game.cur_room == zone and not game.input_overlay_up()
		status.get_node("Title").text = "ONE MORE MILE"
		status.get_node("Detail").text = "Road %d%%   ·   Resolve %d%%" % [roundi(progress() * 100), ceili(resolve)]
		status.get_node("Integrity").size.x = 280.0 * resolve / Balance.ESCORT_RESOLVE
		status.get_node("Hint").text = "Treeline movement · %.1fs" % remaining if phase == 2 else \
			"Keep the creatures away!" if phase == 3 and pressure > 0 else \
			"Return to Tovin!" if not guarded else "Defeat the pursuers" if phase == 3 else \
			"Holding · Speak to resume" if waiting else "Walk beside him toward the fire"


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 25, Color(0.04, 0.04, 0.04, 0.35), true, -1, true)
	draw_set_transform(Vector2.ZERO)
	if not active():
		return
	var color := Color(1.0, 0.4, 0.26, 0.8) if pressure > 0 else Color(0.77, 0.9, 0.63, 0.7)
	draw_arc(Vector2.ZERO, Balance.ESCORT_PRESSURE_RANGE, 0, TAU, 64, color, 2.0, true)
	var direction := (goal - global_position).normalized()
	if phase == 1:
		for i in 4:
			var p := direction * (55.0 + i * 30.0)
			draw_line(p + Vector2(-6, -6), p, color, 2.0, true)
			draw_line(p, p + Vector2(-6, 6), color, 2.0, true)
	for p in arrival_points:
		var local := p - global_position
		draw_arc(local, 32, 0, TAU, 32, Color(1.0, 0.55, 0.27, 0.9), 3.0, true)
		draw_line(local + Vector2(-9, -9), local + Vector2(9, 9), color, 2.0, true)
		draw_line(local + Vector2(9, -9), local + Vector2(-9, 9), color, 2.0, true)


func _exit_tree() -> void:
	_cleanup()
	if is_instance_valid(status):
		status.queue_free()
	if is_instance_valid(game):
		for entry in game.interactables.duplicate():
			if entry.get("node") == self:
				game.interactables.erase(entry)
