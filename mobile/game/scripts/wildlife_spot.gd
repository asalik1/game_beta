extends Node2D
const Wildlife := preload("res://scripts/wildlife.gd")
const Pet := preload("res://scripts/pet_visual.gd")
var game: Game
var zone := -1
var data: Dictionary
var prompt: Label
var caption: Label
var animals: Array[Sprite2D] = []
var explained := false
var rescuing := false
var elapsed := 0.0
var start_hp := 0.0
var age := 0.0
var _home_count := -1
var _home_pet := ""


static func install(g: Game, zi: int) -> Node2D:
	var entry: Dictionary = Wildlife.site(g, zi)
	if entry.is_empty():
		return null
	var spot := new()
	spot.game = g
	spot.zone = zi
	spot.data = entry
	spot.position = Wildlife.point(g, zi)
	g.world.add_child(spot)
	g.interactables.append({"node": spot, "prompt": spot.prompt, "action": spot.interact, "wildlife": true})
	g.zone_scenery[zi].append(spot)
	return spot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("wildlife_spots")
	if data.id == "home":
		var shelter := Sprite2D.new()
		shelter.texture = load("res://assets/sprites/sanctuary_shelter.png")
		shelter.scale = Vector2.ONE * Balance.SANCTUARY_WIDTH / shelter.texture.get_width()
		shelter.position = Vector2(0, -78)
		shelter.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(shelter)
	else:
		_add_pet(String(data.id), Vector2.ZERO)
	prompt = _label(-194 if data.id == "home" else -86, 14)
	prompt.visible = false
	caption = _label(-172 if data.id == "home" else -64, 12)
	_refresh()


func _label(y: float, size_px: int) -> Label:
	var l := Label.new()
	l.position = Vector2(-170, y)
	l.size = Vector2(340, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(l, size_px, 4)
	add_child(l)
	return l


func _add_pet(id: String, at: Vector2) -> void:
	var p := Pet.new()
	p.setup(id)
	p.position = at
	p.home = at
	add_child(p)
	animals.append(p)


func _refresh() -> void:
	if data.id == "home":
		var total := Wildlife.count(game)
		var companion: String = game.player.equipped_pet if game.has_local_player() else ""
		if total != _home_count or companion != _home_pet:
			_home_count = total
			_home_pet = companion
			for p in animals:
				p.queue_free()
			animals.clear()
			var n := 0
			for entry in Wildlife.SITES:
				if Wildlife.rescued(game, String(entry.id)) and String(entry.id) != companion:
					_add_pet(String(entry.id), Vector2((n % 3 - 1) * 64, (n / 3) * 44 + 28))
					n += 1
		caption.text = "Small Mercies · %d / %d safe" % [total, Wildlife.SITES.size()]
		prompt.text = game.touchify("E — Visit the sanctuary")
	else:
		var saved := Wildlife.rescued(game, String(data.id))
		caption.text = "A small life made it home" if saved else ("Steady hands… %d%%" % int(elapsed / Balance.WILDLIFE_RESCUE_SECONDS * 100) if rescuing else "A creature needs help")
		prompt.text = game.touchify("E — Remember this rescue" if saved else "E — Free the creature")
		for p in animals:
			p.visible = not saved


func blocked() -> bool:
	var p: Player = game.local_player
	return p == null or p.dead or p.downed or p.ghost or game.state != Game.ST_PLAYING \
		or game.cur_room != zone or game.input_overlay_up() \
		or p.global_position.distance_to(global_position) > Balance.INTERACT_RANGE or game._room_hot(zone)


func interact() -> void:
	if blocked():
		game.spawn_text(global_position + Vector2(0, -100), "Find a quiet moment nearby.", Color(0.95, 0.82, 0.6))
		return
	if data.id == "home" or Wildlife.rescued(game, String(data.id)):
		preload("res://scripts/ui/sanctuary.gd").open(game.menus)
		return
	if rescuing:
		return
	rescuing = true
	elapsed = 0.0
	start_hp = game.local_player.hp
	if not explained:
		explained = true
		game.hud.announce("A small life — " + String(data.text), Color(0.76, 0.9, 0.73), 3.0)


func _process(delta: float) -> void:
	if game.cur_room != zone:
		rescuing = false
		return
	age += delta
	if rescuing:
		if blocked() or game.local_player.hp < start_hp:
			rescuing = false
			elapsed = 0.0
		else:
			elapsed += delta
			if elapsed >= Balance.WILDLIFE_RESCUE_SECONDS:
				rescuing = false
				if Wildlife.claim(game, String(data.id)):
					game.sfx("potion")
					game.hud.announce("Rescued · " + String(Skins.find_pet(String(data.id)).name) + "\nA place is waiting at the sanctuary.", Color(0.76, 0.95, 0.74), 3.0)
	_refresh()
	caption.visible = game.has_local_player() and game.player.global_position.distance_to(global_position) < 240.0
	for i in animals.size():
		var p: Sprite2D = animals[i]
		var previous := p.position
		if data.id == "home":
			var travel := Balance.PET_HOME_TRAVEL_SECONDS
			var half_cycle := travel + Balance.PET_HOME_PAUSE_SECONDS
			var phase := fposmod(age + i * 1.9, half_cycle * 2.0)
			var weight := clampf(fmod(phase, half_cycle) / travel, 0.0, 1.0)
			var x := lerpf(-Balance.PET_HOME_DISTANCE, Balance.PET_HOME_DISTANCE, weight)
			if phase >= half_cycle:
				x = -x
			p.position = p.home + Vector2(x, 0)
		var velocity := (p.position - previous) / maxf(delta, 0.001)
		if absf(velocity.x) > Balance.PET_STOP_SPEED:
			p.flip_h = velocity.x < 0.0
		p.animate(delta, velocity.length() > Balance.PET_STOP_SPEED, velocity.length())
	queue_redraw()


func _draw() -> void:
	if data.id == "home":
		return
	var saved := Wildlife.rescued(game, String(data.id))
	draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 29, Color(0.11, 0.09, 0.07, 0.5), true, -1, true)
	draw_arc(Vector2.ZERO, 29, 0.2 if saved else 0.0, TAU - (1.1 if saved else 0.0), 36, Color(0.60, 0.45, 0.27), 3, true)
	draw_set_transform(Vector2.ZERO)
	if not saved:
		for i in [-1, 0, 1]:
			draw_polyline(PackedVector2Array([Vector2(i * 18, 7), Vector2(i * 15, -42), Vector2(i * 12, -50)]), Color(0.51, 0.48, 0.36), 2, true)
	if rescuing:
		draw_arc(Vector2(0, -20), 42, -PI * 0.5, -PI * 0.5 + TAU * clampf(elapsed / Balance.WILDLIFE_RESCUE_SECONDS, 0, 1), 40, Color(0.86, 0.97, 0.66), 3, true)


func _exit_tree() -> void:
	if is_instance_valid(game):
		for entry in game.interactables.duplicate():
			if entry.get("node") == self:
				game.interactables.erase(entry)


func _notification(what: int) -> void:
	# Solo overlays pause the world before its next process frame. The pause
	# notification still arrives, so interrupted work cannot resume invisibly.
	if what == NOTIFICATION_PAUSED:
		rescuing = false
		elapsed = 0.0
