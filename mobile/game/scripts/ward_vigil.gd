extends Node2D
## Host-owned optional defense. Ordinary enemies supply combat; the ward
## measures presence and pressure. No escort targeting or persistent timers.
const ID := "tower"
const DONE := "ward_tower_lit"
const KEPT := "sq_kept_ward_tower"
const WAVES := [["skeleton", "skeleton"], ["wolf", "wolf", "skeleton"], ["cultist", "skeleton", "skeleton"]]
var game: Game
var zone := -1
var phase := 0  # waiting / preparing / fighting / restored
var wave := 0
var integrity := Balance.VIGIL_INTEGRITY
var remaining := 0.0
var enemies: Array[Enemy] = []
var arrival_points: Array[Vector2] = []
var guarded := false
var pressure := 0
var prompt: Label
var caption: Label
var sprite: Sprite2D
var age := 0.0
var sync_time := 0.0
var _rewarded := false
var status: Control


static func eligible(g: Game, zi: int) -> bool:
	return g.chapter_id == "ch1" and not g.pvp_active and not g.endgame_active and not g.weekly_active \
		and zi >= 0 and zi < g.zones.size() and String(g.zones[zi].name) == "The Collapsed Tower"


static func point(g: Game, zi: int) -> Vector2:
	var bounds := g.play_rect(zi).grow(-Balance.VIGIL_CLEARANCE)
	return (g.room_center(zi) + Vector2(-360, 150)).clamp(bounds.position, bounds.end)


static func install(g: Game, zi: int) -> Node2D:
	if not eligible(g, zi):
		return null
	var v := new()
	v.game = g
	v.zone = zi
	v.position = point(g, zi)
	if not g.net_guest() and g.get_flag(KEPT, false) and not g.get_flag(DONE, false):
		g.set_flag(DONE)
	v.phase = 3 if g.get_flag(DONE, false) else 0
	g.world.add_child(v)
	g.zone_scenery[zi].append(v)
	return v


static func find(g: Game) -> Node2D:
	for v in g.get_tree().get_nodes_in_group("ward_vigils"):
		if v.game == g and not v.is_queued_for_deletion():
			return v
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("ward_vigils")
	add_to_group("optional_encounters")
	set_meta("encounter_title", "the tower's watch")
	set_meta("quest_flag", DONE)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/watch_brazier_anim.png")
	sprite.hframes = maxi(1, int(sprite.texture.get_width() / sprite.texture.get_height()))
	sprite.scale = Vector2.ONE * Balance.VIGIL_ART_HEIGHT / sprite.texture.get_height()
	sprite.position.y = -Balance.VIGIL_ART_HEIGHT * 0.4
	add_child(sprite)
	prompt = _label(-120, 14)
	prompt.visible = false
	caption = _label(-145, 13)
	if is_instance_valid(game.hud):
		status = preload("res://scripts/ui/ward_vigil.gd").status(game.hud)
	game.interactables.append({"node": self, "prompt": prompt, "action": interact})
	_refresh()


func _label(y: float, pixels: int) -> Label:
	var label := Label.new()
	label.position = Vector2(-220, y)
	label.size = Vector2(440, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(label, pixels, 4)
	add_child(label)
	return label


func active() -> bool:
	return phase in [1, 2]


func interact() -> void:
	if game.input_overlay_up():
		return
	if phase == 3:
		game.hud.announce("The tower answers — A steady light burns above the north road.", Color(1.0, 0.8, 0.45))
		return
	if phase == 0:
		preload("res://scripts/ui/ward_vigil.gd").open(game.menus, self)
	else:
		request(game.local_player, "stop")


func request(source: Player, action: String) -> bool:
	if is_queued_for_deletion() or not eligible(game, zone) or not is_instance_valid(source) or source.dead or source.downed or source.ghost \
		or game.state != Game.ST_PLAYING or game.room_at_pos(source.global_position) != zone \
		or source.global_position.distance_to(global_position) > Balance.VIGIL_INTERACT_RANGE \
		or not action in ["start", "stop"]:
		return false
	if action == "start" and not preload("res://scripts/encounter_context.gd").may_start(game, zone, source, self):
		return false
	if game.net_guest():
		if source == game.local_player:
			game.net_session().request_vigil(action)
		return false
	if action == "stop" and active():
		cancel("The ward is dark — You can stand its watch again when you are ready.")
		return true
	if action != "start" or phase != 0:
		return false
	if game._room_hot(zone):
		if source == game.local_player:
			game.hud.announce("Clear the tower first — The old ward needs a quiet moment to catch.", Color(1.0, 0.8, 0.45))
		return false
	integrity = Balance.VIGIL_INTEGRITY
	wave = 0
	_prepare_wave()
	return true


func _prepare_wave() -> void:
	wave += 1
	phase = 1
	remaining = Balance.VIGIL_PREPARE_SECONDS
	arrival_points.clear()
	var bounds := game.play_rect(zone).grow(-Balance.VIGIL_SPAWN_INSET)
	for i in WAVES[wave - 1].size():
		var angle: float = PI + float(i) * TAU / WAVES[wave - 1].size() + wave * 0.65
		var p := (global_position + Vector2.from_angle(angle) * Balance.VIGIL_SPAWN_RADIUS).clamp(bounds.position, bounds.end)
		arrival_points.append(game.free_spawn_pos(p, global_position))
	_broadcast()
	_refresh()


func _spawn_wave() -> void:
	phase = 2
	for i in WAVES[wave - 1].size():
		var kind: String = WAVES[wave - 1][i]
		var e := Enemy.make(game, kind, arrival_points[i], Balance.VIGIL_ENEMY_LEVEL)
		e.zone_idx = -1  # never alters the chapter's purge/reward counter
		e.xp_value = 0
		e.gold_value = 0
		e.force_aggro = true
		e.set_meta("ward_spawn", true)
		game.add_enemy(e)
		enemies.append(e)
		game.burst(e.global_position, Color(0.8, 0.6, 0.36), 10)
	arrival_points.clear()
	_broadcast()


func _living() -> Array[Enemy]:
	var living: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and not e.dying and not e.is_queued_for_deletion():
			living.append(e)
	return living


func _physics_process(delta: float) -> void:
	age += delta
	if phase != 3 and game.get_flag(DONE, false):
		phase = 3
	if phase == 3 and not _rewarded:
		_rewarded = true
		if game.has_local_player():
			game.set_flag(KEPT)
			game.unlock_achievement("lamplighter")
	if active() and not game.net_guest():
		var present := false
		guarded = false
		for p: Player in game.players:
			if is_instance_valid(p) and not p.dead and not p.downed and not p.ghost \
					and game.room_at_pos(p.global_position) == zone:
				present = true
				if p.global_position.distance_to(global_position) <= Balance.VIGIL_GUARD_RADIUS:
					guarded = true
		if not present or game.state != Game.ST_PLAYING:
			cancel("")
			return
		if phase == 1:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				_spawn_wave()
		else:
			var living := _living()
			pressure = 0
			for e in living:
				if e.global_position.distance_to(global_position) <= Balance.VIGIL_HEART_RADIUS:
					pressure += 1
			var drain := (0.0 if guarded else Balance.VIGIL_ABSENT_DRAIN) \
				+ mini(pressure, Balance.VIGIL_PRESSURE_CAP) * Balance.VIGIL_ENEMY_DRAIN
			integrity = maxf(0.0, integrity - drain * delta)
			if integrity <= 0.0:
				cancel("The ward gutters — Keep close and push the creatures away from its heart. You can try again.")
			elif living.is_empty():
				if wave >= WAVES.size():
					complete()
				else:
					integrity = minf(Balance.VIGIL_INTEGRITY, integrity + Balance.VIGIL_WAVE_MEND)
					_prepare_wave()
		sync_time += delta
		if sync_time >= Balance.VIGIL_SYNC_SECONDS:
			sync_time = 0.0
			_broadcast()
	_refresh()
	queue_redraw()


func _refresh() -> void:
	if not is_instance_valid(prompt):
		return
	prompt.text = game.touchify("E — " + ("Remember the watch" if phase == 3 else "Snuff the ward · stop" if active() else "Light the old ward"))
	prompt.position.y = 95 if active() else -120
	caption.visible = not active() and game.cur_room == zone and not game.input_overlay_up() \
		and game.has_local_player() and game.local_player.global_position.distance_to(global_position) < Balance.VIGIL_LABEL_RANGE
	if is_instance_valid(status):
		status.visible = active() and game.cur_room == zone and not game.input_overlay_up()
		status.get_node("Title").text = "THE TOWER'S WATCH"
		status.get_node("Detail").text = "Wave %d / %d     Ward %d%%" % [wave, WAVES.size(), ceili(integrity)]
		status.get_node("Integrity").size.x = 280.0 * integrity / Balance.VIGIL_INTEGRITY
		status.get_node("Hint").text = "Next arrivals · %.1fs" % remaining if phase == 1 else "Return to the amber ring!" if not guarded else "Keep them out of the heart!" if pressure > 0 else "Hold the ring · Defeat the wave"
	if active():
		caption.text = "WAVE %d / %d  ·  WARD %d%%" % [wave, WAVES.size(), ceili(integrity)]
		if phase == 1:
			caption.text += "  ·  %.1fs" % remaining
		elif not guarded:
			caption.text += "  ·  RETURN TO THE RING"
		elif pressure > 0:
			caption.text += "  ·  KEEP THEM BACK"
	else:
		caption.text = "A light on the road" if phase == 3 else "The old tower ward"
	sprite.frame = int(age * Balance.VIGIL_ANIM_FPS) % sprite.hframes if phase != 0 else 0
	sprite.modulate = Color.WHITE if phase != 0 else Color(0.3, 0.34, 0.4)


func complete() -> void:
	if game.net_guest() or not active():
		return
	phase = 3
	remaining = 0.0
	_cleanup_enemies()
	game.set_flag(DONE)
	_broadcast()
	game.hud.announce("The tower answers — Three waves held. The Lamplighter title is yours; Mara in Emberfall should hear of this.", Color(1.0, 0.8, 0.45))
	game.autosave()


func cancel(message: String) -> void:
	if game.net_guest() or not active():
		return
	phase = 0
	wave = 0
	remaining = 0.0
	integrity = Balance.VIGIL_INTEGRITY
	arrival_points.clear()
	_cleanup_enemies()
	_broadcast()
	if message != "" and game.has_local_player() and game.cur_room == zone:
		game.hud.announce(message, Color(1.0, 0.8, 0.45))
	_refresh()


func _cleanup_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.dying:
			e.remove_from_group("enemies")
			e.queue_free()
	enemies.clear()


func _broadcast() -> void:
	if game.net_host():
		game.net_session().host_vigil_state(self)


func apply_state(next: int, next_wave: int, hp: float, countdown: float, held: bool, threats: int, points: Array) -> void:
	if not next in [0, 1, 2, 3] or next_wave < 0 or next_wave > WAVES.size() \
		or not is_finite(hp) or hp < 0 or hp > Balance.VIGIL_INTEGRITY \
		or not is_finite(countdown) or countdown < 0 or countdown > Balance.VIGIL_PREPARE_SECONDS \
		or points.size() > Balance.VIGIL_PRESSURE_CAP or threats < 0 or threats > Balance.VIGIL_PRESSURE_CAP:
		return
	for p in points:
		if not p is Vector2 or not p.is_finite() or not game.play_rect(zone).has_point(p):
			return
	phase = next
	wave = next_wave
	integrity = hp
	remaining = countdown
	guarded = held
	pressure = threats
	arrival_points.assign(points)
	_refresh()
	queue_redraw()


func _exit_tree() -> void:
	_cleanup_enemies()
	if is_instance_valid(status):
		status.queue_free()
	if is_instance_valid(game):
		for entry in game.interactables.duplicate():
			if entry.get("node") == self:
				game.interactables.erase(entry)


func _draw() -> void:
	if not active():
		return
	var amber := Color(1.0, 0.77, 0.35)
	draw_arc(Vector2.ZERO, Balance.VIGIL_GUARD_RADIUS, 0, TAU, 72, Color(amber, 0.8), 3.0, true)
	draw_arc(Vector2.ZERO, Balance.VIGIL_HEART_RADIUS, 0, TAU, 64, Color(1.0, 0.35, 0.25, 0.75), 2.0, true)
	for i in 12:
		var dir := Vector2.from_angle(i * TAU / 12.0)
		draw_line(dir * (Balance.VIGIL_GUARD_RADIUS - 15), dir * (Balance.VIGIL_GUARD_RADIUS - 4), amber, 2.0, true)
	for p in arrival_points:
		var center: Vector2 = p - global_position
		draw_arc(center, 34, 0, TAU, 32, Color(1.0, 0.4, 0.25, 0.9), 3.0, true)
		draw_line(center + Vector2(-10, -10), center + Vector2(10, 10), amber, 2.0, true)
		draw_line(center + Vector2(10, -10), center + Vector2(-10, 10), amber, 2.0, true)
