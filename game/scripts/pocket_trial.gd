extends Node2D
## Painted portal + host-owned arena rule. The pocket remains after victory
## so the player can collect the chest and leave by choice.
var game: Game
var zone := -1
var arena := false
var phase := 0  # calm / warning / hot
var side := 0
var remaining := 0.0
var age := 0.0
var hit_clock := 0.0
var wire_clock := 0.0
var sprite: Sprite2D
var prompt: Label
var caption: Label
var panel: Control
var _had_company := false


static func source_room(g: Game) -> int:
	for zi in g.zones.size():
		if zi != g.pocket_room and g.room_type(zi) == "social":
			return zi
	return -1


static func eligible(g: Game, zi: int) -> bool:
	return g.pocket_room >= 0 and not Pockets.entry(g.pocket_id).is_empty() \
		and zi in [g.pocket_room, source_room(g)]


static func point(g: Game, zi: int) -> Vector2:
	var offset := Balance.POCKET_EXIT_OFFSET if zi == g.pocket_room else Balance.POCKET_STONE_OFFSET
	var bounds := g.play_rect(zi).grow(-Balance.POCKET_PORTAL_CLEARANCE)
	return (g.room_center(zi) + offset).clamp(bounds.position, bounds.end)


static func install(g: Game, zi: int) -> Node2D:
	if not eligible(g, zi):
		return null
	var trial := new()
	trial.game = g
	trial.zone = zi
	trial.arena = zi == g.pocket_room
	trial.position = point(g, zi)
	g.world.add_child(trial)
	g.zone_scenery[zi].append(trial)
	return trial


static func find(g: Game, zi: int) -> Node2D:
	for trial in g.get_tree().get_nodes_in_group("pocket_trials"):
		if trial.game == g and trial.zone == zi and not trial.is_queued_for_deletion():
			return trial
	return null


static func potions_locked(g: Game, p: Node2D) -> bool:
	return is_instance_valid(g) and is_instance_valid(p) and not g.pocket_done \
		and g.pocket_id == "still_larder" and g.pocket_room >= 0 \
		and g.room_at_pos(p.global_position) == g.pocket_room


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("pocket_trials")
	z_index = -6
	remaining = Balance.POCKET_PULSE_REST
	sprite = Sprite2D.new()
	sprite.z_index = 6
	var art := Art.anim_info("capital_portal_story")
	sprite.texture = art["tex"]
	sprite.hframes = int(art["frames"])  # rectangular portal cells use their static sibling
	sprite.scale = Art.scale_for_alpha_height(sprite.texture, Balance.POCKET_PORTAL_HEIGHT, sprite.hframes)
	sprite.offset.y = -Art.alpha_feet_offset(sprite.texture, 1.0, sprite.hframes)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	prompt = _label(-Balance.POCKET_PORTAL_HEIGHT - 31.0, 14)
	prompt.visible = false
	caption = _label(-Balance.POCKET_PORTAL_HEIGHT - 7.0, 13)
	game.interactables.append({"node": self, "prompt": prompt, "action": interact})
	if arena and is_instance_valid(game.hud):
		panel = preload("res://scripts/ui/pocket_trial.gd").status(game.hud)
	if arena and game.net_guest() and not game.pocket_clock.is_empty():
		apply_state(int(game.pocket_clock.phase), int(game.pocket_clock.side), float(game.pocket_clock.remaining))
	_refresh()


func _label(y: float, pixels: int) -> Label:
	var label := Label.new()
	label.z_index = 8
	label.position = Vector2(-240, y)
	label.size = Vector2(480, 25)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(label, pixels, 4)
	add_child(label)
	return label


func interact() -> void:
	if not game.input_overlay_up():
		preload("res://scripts/ui/pocket_trial.gd").open(game.menus, self)


func _living_here() -> bool:
	for p: Player in game.players:
		if is_instance_valid(p) and not p.dead and not p.downed and not p.ghost \
			and game.room_at_pos(p.global_position) == zone:
			return true
	return false


func reset_clock() -> void:
	phase = 0
	side = 0
	remaining = Balance.POCKET_PULSE_REST
	hit_clock = 0.0
	queue_redraw()


func hot_rect() -> Rect2:
	var bounds := game.play_rect(zone).grow(-Balance.POCKET_FLOOR_INSET)
	var width := (bounds.size.x - Balance.POCKET_COLD_SEAM) * 0.5
	if side == 0:
		return Rect2(bounds.position, Vector2(width, bounds.size.y))
	return Rect2(Vector2(bounds.end.x - width, bounds.position.y), Vector2(width, bounds.size.y))


func apply_state(next: int, warm_side: int, seconds: float) -> bool:
	if not next in [0, 1, 2] or not warm_side in [0, 1] or not is_finite(seconds) \
		or seconds < 0.0 or seconds > maxf(Balance.POCKET_PULSE_REST, maxf(Balance.POCKET_PULSE_WARNING, Balance.POCKET_PULSE_HEAT)):
		return false
	phase = next
	side = warm_side
	remaining = seconds
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	age += delta
	sprite.frame = int(age * Balance.POCKET_PORTAL_FPS) % sprite.hframes
	if arena and not game.net_guest():
		var present := _living_here() and game.state == Game.ST_PLAYING
		if not present and _had_company and not game.pocket_done:
			for boss: Boss in game._live_bosses():
				if boss.zone_idx == zone:
					boss.reset_fight()
		_had_company = present
		if game.pocket_done or not present:
			reset_clock()
		elif game.pocket_id == "molten_court":
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				if phase == 0:
					phase = 1
					remaining = Balance.POCKET_PULSE_WARNING
				elif phase == 1:
					phase = 2
					remaining = Balance.POCKET_PULSE_HEAT
					hit_clock = 0.0
				else:
					phase = 0
					remaining = Balance.POCKET_PULSE_REST
					side = 1 - side
			if phase == 2:
				hit_clock -= delta
				if hit_clock <= 0.0:
					hit_clock = Balance.POCKET_PULSE_TICK
					_heat_tick()
		wire_clock -= delta
		if wire_clock <= 0.0 and game.net_host() and present and not game.pocket_done and game.pocket_id == "molten_court":
			wire_clock = Balance.POCKET_WIRE_INTERVAL
			game.net_session().host_pocket_state(self)
	elif arena and game.net_guest():
		remaining = maxf(0.0, remaining - delta)  # display only; never advances phase/damage
	_refresh()
	queue_redraw()


func _heat_tick() -> void:
	if game.net_guest() or game.pocket_done or phase != 2:
		return
	for p: Player in game.players:
		if is_instance_valid(p) and not p.dead and not p.downed and not p.ghost \
			and game.room_at_pos(p.global_position) == zone and hot_rect().has_point(p.global_position):
			p.take_damage(p.max_hp * Balance.POCKET_PULSE_DAMAGE, "magic")


func _refresh() -> void:
	if not is_instance_valid(prompt):
		return
	prompt.text = game.touchify("E — " + ("Return through the stone" if arena else "Step through the portal"))
	caption.text = "The way home stays open" if arena else String(Pockets.entry(game.pocket_id).get("name", "A hidden place"))
	caption.visible = game.cur_room == zone and not game.input_overlay_up() and game.has_local_player() \
		and game.local_player.global_position.distance_to(global_position) < Balance.POCKET_LABEL_RANGE
	if is_instance_valid(panel):
		panel.visible = game.cur_room == zone and not game.input_overlay_up()
		panel.get_node("Title").text = "POCKET SPOILS" if game.pocket_done else \
			"TRIAL RULE" if game.pocket_id == "still_larder" else "FLOOR HAZARD"
		panel.get_node("Detail").text = "Victory · Collect your spoils" if game.pocket_done else \
			"Bottles sealed · Class healing works" if game.pocket_id == "still_larder" else \
			"Hot stone · %.1fs" % remaining if phase == 2 else \
			"Floor heating · %.1fs" % remaining if phase == 1 else "Floor quiet · %.1fs" % remaining
		panel.get_node("Hint").text = "Use the exit stone when ready" if game.pocket_done else \
			"Exit stone offers a free retreat" if game.pocket_id == "still_larder" else \
			"Lure the guardian across hot stone" if phase == 2 else "Keep to the cold half or center seam"


func _draw() -> void:
	if not arena or game.pocket_done or game.pocket_id != "molten_court" or phase == 0:
		return
	var rect := hot_rect()
	rect.position -= global_position
	var rim := Color(1.0, 0.43, 0.18, 0.9) if phase == 2 else Color(1.0, 0.74, 0.3, 0.85)
	draw_rect(rect, Color(rim, 0.16 if phase == 2 else 0.08), true)
	draw_rect(rect, rim, false, 3.0)
	# Slow, steady heat marks, with no flashes or screen-wide postprocessing.
	for i in range(1, 9):
		var y := rect.position.y + rect.size.y * float(i) / 10.0
		draw_line(Vector2(rect.position.x + 12.0, y), Vector2(rect.end.x - 12.0, y), Color(rim, 0.16), 2.0)


func _exit_tree() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(game):
		for entry in game.interactables.duplicate():
			if entry.get("node") == self:
				game.interactables.erase(entry)
