extends StaticBody2D
## Deliberate, single-use terrain weapons. State belongs to the host; the
## ordinary interact action, melee contact and real projectiles can prime one.
const TYPES := {
	"ember": {"name": "Ember Cask", "verb": "Light fuse", "frame": 0,
		"color": Color(1.0, 0.49, 0.22)},
	"rime": {"name": "Rimeheart", "verb": "Shatter", "frame": 1,
		"color": Color(0.42, 0.83, 1.0)},
}
var game: Game
var zone := -1
var slot := 0
var kind := "ember"
var key := ""
var phase := 0  # intact / primed / spent
var remaining := 0.0
var pop_age := -1.0
var prompt: Label
var caption: Label
var sprite: Sprite2D
var clock: Node2D


static func eligible(g: Game, zi: int) -> bool:
	if zi < 0 or zi >= g.zones.size() or g.pvp_active or g.endgame_active or g.weekly_active:
		return false
	var z: Dictionary = g.zones[zi]
	return not z.get("enemies", []).is_empty() and String(z.get("boss", "")) == "" \
		and not g.chapter_id in ["capital", "crucible", "depths"] \
		and not bool(z.get("reactive_terrain_off", false))


static func spawn_room(g: Game, zi: int, reserved: Array, placed: Array) -> void:
	if not eligible(g, zi):
		return
	var rect := g.play_rect(zi)
	var rng := RandomNumberGenerator.new()
	rng.seed = (g.chapter_id + ":terrain:" + str(zi)).hash()
	var tid: String = g.terrain_by_zone[zi]
	var cold := tid in ["ice", "crystal", "storm", "ph_frostmarch", "ph_crystalchasm"]
	var accepted: Array[Vector2] = []
	var packs: Array = g.zones[zi].get("enemies", [])
	for idx in Balance.REACTIVE_PER_ROOM:
		for attempt in Balance.REACTIVE_PLACE_TRIES:
			var local := Vector2(rng.randf_range(Balance.REACTIVE_MARGIN, rect.size.x - Balance.REACTIVE_MARGIN),
				rng.randf_range(Balance.REACTIVE_MARGIN, rect.size.y - Balance.REACTIVE_MARGIN))
			if attempt < Balance.REACTIVE_PACK_TRIES:
				var pack: Array = packs[int(idx * packs.size() / Balance.REACTIVE_PER_ROOM)]
				local = g.room_pos(zi, float(pack[1]), float(pack[2])) - rect.position \
					+ Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(Balance.REACTIVE_PACK_OFFSET.x, Balance.REACTIVE_PACK_OFFSET.y)
				if not Rect2(Vector2.ONE * Balance.REACTIVE_MARGIN, rect.size - Vector2.ONE * Balance.REACTIVE_MARGIN * 2).has_point(local):
					continue
			if g._reserved_blocks(reserved, local):
				continue
			var blocked := false
			for other: Vector2 in placed:
				if local.distance_to(other) < Balance.REACTIVE_CLEARANCE:
					blocked = true
			for other: Vector2 in accepted:
				if local.distance_to(other) < Balance.REACTIVE_PAIR_SPACING:
					blocked = true
			if blocked:
				continue
			accepted.append(local)
			placed.append(local)
			install(g, zi, idx, "rime" if cold else "ember", rect.position + local)
			break


static func install(g: Game, zi: int, index: int, type: String, pos: Vector2) -> StaticBody2D:
	var prop := new()
	prop.game = g
	prop.zone = zi
	prop.slot = index
	prop.kind = type
	prop.key = "reactive_%s_%d_%d" % [g.chapter_id, zi, index]
	prop.position = pos
	prop.phase = 2 if g.get_flag(prop.key, false) else 0
	g.world.add_child(prop)
	g.zone_scenery[zi].append(prop)
	return prop


static func find(g: Game, prop_key: String) -> StaticBody2D:
	for prop in g.get_tree().get_nodes_in_group("reactive_terrain"):
		if prop.game == g and prop.key == prop_key and not prop.is_queued_for_deletion():
			return prop
	return null


static func strike_circle(g: Game, source: Player, center: Vector2, radius: float) -> void:
	for prop in g.get_tree().get_nodes_in_group("reactive_terrain"):
		if prop.game == g and prop.phase == 0 and center.distance_to(prop.global_position) <= radius:
			prop.request_prime(source, "strike")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var readable := CanvasItemMaterial.new()
	readable.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = readable
	add_to_group("reactive_terrain")
	set_meta("reactive_terrain", true)
	collision_layer = 1 if phase == 0 else 0
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Balance.REACTIVE_COLLIDER
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/reactive_terrain_atlas.png")
	sprite.hframes = 2
	sprite.frame = int(TYPES[kind].frame)
	sprite.use_parent_material = true
	sprite.modulate = Color(1.15, 1.15, 1.15)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * Balance.REACTIVE_ART_HEIGHT / sprite.texture.get_height()
	sprite.position.y = -Balance.REACTIVE_ART_HEIGHT * 0.42
	sprite.visible = phase != 2
	add_child(sprite)
	prompt = Label.new()
	prompt.text = game.touchify("E — " + String(TYPES[kind].verb))
	prompt.position = Vector2(-150, -110)
	prompt.size = Vector2(300, 24)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(prompt, 15, 4)
	prompt.use_parent_material = true
	prompt.visible = false
	add_child(prompt)
	caption = Label.new()
	caption.position = Vector2(-150, -86)
	caption.size = Vector2(300, 24)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(caption, 13, 4)
	caption.use_parent_material = true
	caption.add_theme_color_override("font_color", TYPES[kind].color)
	add_child(caption)
	if phase == 0:
		game.interactables.append({"node": self, "prompt": prompt, "action": interact,
			"reach": Balance.REACTIVE_INTERACT_RANGE})
	queue_redraw()


func _remove_interaction() -> void:
	for entry in game.interactables.duplicate():
		if entry.get("node") == self:
			game.interactables.erase(entry)
	if is_instance_valid(prompt):
		prompt.visible = false


func _exit_tree() -> void:
	if is_instance_valid(game):
		_remove_interaction()


func interact() -> void:
	if not game.input_overlay_up():
		request_prime(game.local_player, "interact")


func request_prime(source: Player, mode: String) -> bool:
	if phase != 0 or not is_instance_valid(source) or source.dead or source.downed or source.ghost \
		or game.state != Game.ST_PLAYING or game.room_at_pos(source.global_position) != zone:
		return false
	var reach := Balance.REACTIVE_INTERACT_RANGE if mode == "interact" else Balance.REACTIVE_SHOT_RANGE
	if source.global_position.distance_to(global_position) > reach:
		return false
	if game.net_guest():
		if source == game.local_player:
			game.net_session().request_terrain_prime(key, mode)
		return false
	return prime()


func prime() -> bool:
	if phase != 0 or game.net_guest() or is_queued_for_deletion():
		return false
	# Reserve before effects, chains or another player's request can re-enter.
	game.set_flag(key, true)
	apply_state(1, Balance.REACTIVE_FUSE)
	if game.net_host():
		game.net_session().host_terrain_state(self)
	return true


func apply_state(next: int, fuse: float, quiet := false) -> void:
	if next < 1 or next > 2 or not is_finite(fuse) or fuse < 0.0 or fuse > Balance.REACTIVE_FUSE:
		return
	# A reserved shell from the join snapshot may still have a live host fuse.
	if phase == 2 and pop_age < 0.0 and next == 1 and game.net_guest():
		phase = 0
		sprite.visible = true
		collision_layer = 1
	if next < phase or next < 1 or next > 2 or not is_finite(fuse):
		return
	if next == phase:
		if phase == 1:
			remaining = minf(remaining, clampf(fuse, 0.0, Balance.REACTIVE_FUSE))
		return
	phase = next
	remaining = clampf(fuse, 0.0, Balance.REACTIVE_FUSE)
	_remove_interaction()
	if phase == 1:
		clock = preload("res://scripts/ground_tell.gd").new()
		clock.radius = Balance.REACTIVE_RADIUS
		clock.tint = TYPES[kind].color
		add_child(clock)
		if not quiet:
			game.sfx("fireball" if kind == "ember" else "nova", 0.75)
	else:
		set_deferred("collision_layer", 0)
		sprite.visible = false
		if is_instance_valid(clock):
			clock.queue_free()
		clock = null
		pop_age = Balance.REACTIVE_POP_TIME if quiet else 0.0
		if not quiet:
			game.burst(global_position + Vector2(0, -14), TYPES[kind].color, 20)
			game.sfx("gate" if kind == "ember" else "nova", 0.9)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if phase != 1 and game.cur_room != zone:
		caption.visible = false
		return
	if phase == 1:
		# A deserted/reset encounter cannot fire a delayed blast into a return.
		if not game.net_guest():
			var occupied := false
			for p: Player in game.players:
				if is_instance_valid(p) and not p.dead and not p.downed and not p.ghost \
					and game.room_at_pos(p.global_position) == zone:
					occupied = true
			if not occupied or game.state != Game.ST_PLAYING:
				apply_state(2, 0.0)
				if game.net_host():
					game.net_session().host_terrain_state(self)
				return
		remaining = maxf(0.0, remaining - delta)
		if is_instance_valid(clock):
			clock.progress = 1.0 - remaining / Balance.REACTIVE_FUSE
		if remaining <= 0.0 and not game.net_guest():
			detonate()
	if pop_age >= 0.0:
		pop_age += delta
	var near := game.has_local_player() and game.local_player.global_position.distance_to(global_position) < Balance.REACTIVE_LABEL_RANGE
	if near and phase == 0:
		prompt.text = game.touchify("E — " + String(TYPES[kind].verb))
	caption.visible = near and phase != 2 and not game.input_overlay_up()
	caption.text = ("BLAST — MOVE!  %.1f" % remaining if kind == "ember" else "FROST — MOVE!  %.1f" % remaining) if phase == 1 else String(TYPES[kind].name)
	queue_redraw()


func detonate() -> void:
	if phase != 1 or game.net_guest() or is_queued_for_deletion():
		return
	apply_state(2, 0.0)
	if game.net_host():
		game.net_session().host_terrain_state(self)
	# The room test prevents a blast leaking through a sealed arena boundary.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.game != game or e.dying or e.untargetable or e is Boss \
			or game.room_at_pos(e.global_position) != zone \
			or global_position.distance_to(e.global_position) > Balance.REACTIVE_RADIUS:
			continue
		var fraction := Balance.REACTIVE_EMBER_DAMAGE if kind == "ember" else Balance.REACTIVE_RIME_DAMAGE
		e.hit_src = null
		e.stat_src = null
		e.take_damage(e.max_hp * fraction, (e.global_position - global_position).normalized())
		if kind == "rime" and not e.dying:
			e.apply_slow(Balance.REACTIVE_CHILL_MULT, Balance.REACTIVE_CHILL_DURATION)
	for p: Player in game.players:
		if not is_instance_valid(p) or p.dead or p.downed or p.ghost \
			or game.room_at_pos(p.global_position) != zone \
			or global_position.distance_to(p.global_position) > Balance.REACTIVE_RADIUS:
			continue
		p.take_damage(p.max_hp * Balance.REACTIVE_PLAYER_DAMAGE, "magic")
		if kind == "rime":
			p.apply_chill(Balance.REACTIVE_CHILL_MULT, Balance.REACTIVE_CHILL_DURATION)
	# Each link starts a fresh full warning. No instantaneous chain kills.
	for prop in get_tree().get_nodes_in_group("reactive_terrain"):
		if prop != self and prop.game == game and prop.zone == zone \
			and global_position.distance_to(prop.global_position) <= Balance.REACTIVE_RADIUS:
			prop.prime()


func _draw() -> void:
	var col: Color = TYPES[kind].color
	if phase == 2:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 31, Color(0.025, 0.03, 0.04, 0.55))
		for i in 6:
			var at := Vector2.from_angle(i * TAU / 6) * 20
			draw_line(at, at + Vector2(6, -4), Color(col.darkened(0.65), 0.8), 4, true)
		draw_set_transform(Vector2.ZERO)
		if pop_age >= 0.0 and pop_age < Balance.REACTIVE_POP_TIME:
			var t := pop_age / Balance.REACTIVE_POP_TIME
			draw_circle(Vector2.ZERO, Balance.REACTIVE_RADIUS, Color(col, (1.0 - t) * 0.12))
			draw_arc(Vector2.ZERO, Balance.REACTIVE_RADIUS * sqrt(t), 0, TAU, 80, Color(col, 1.0 - t), 4, true)
	else:
		draw_arc(Vector2.ZERO, 27, 0, TAU, 40, Color(0.02, 0.025, 0.035, 0.85), 5, true)
		for i in 4:
			draw_arc(Vector2.ZERO, 27, i * PI * 0.5 + 0.12, i * PI * 0.5 + 0.95, 12, Color(col, 0.85), 2, true)
		if phase == 0 and is_instance_valid(prompt) and prompt.visible:
			draw_arc(Vector2.ZERO, Balance.REACTIVE_RADIUS, 0, TAU, 80, Color(col, 0.28), 1.5, true)
