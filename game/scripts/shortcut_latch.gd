extends Node2D
## Far-side latch; all successful solo/host/guest openings share one validator.
## The existing interaction pipeline supplies keyboard, pad and touch intents.
var game: Game
var zone := -1
var world_owner: Node2D
var world_seed := 0
var flag_name := ""
var prompt: Label
var winch_sprite: Sprite2D
var opened := false


static func find(g: Game, include_opened: bool = false) -> Node2D:
	if not is_instance_valid(g) or not is_instance_valid(g.world):
		return null
	for node in g.world.get_children():
		if node.get_script() == load("res://scripts/shortcut_latch.gd") \
				and not node.is_queued_for_deletion() and node.world_owner == g.world \
				and (include_opened or not node.opened):
			return node
	return null


static func install(g: Game, zi: int) -> Node2D:
	var existing := find(g, true)
	if existing != null:
		return existing
	if g.shortcut_edge.is_empty() or zi != int(g.shortcut_edge["far"]):
		return null
	var key := String(g.shortcut_edge["flag"])
	var latch := new()
	latch.game = g
	latch.zone = zi
	latch.world_owner = g.world
	latch.world_seed = g.wander_seed
	latch.flag_name = key
	latch.position = point(g, zi)
	g.world.add_child(latch)
	# A world mechanism, like its gate, survives terrain-only scenery repaints.
	if not latch.opened:
		g.interactables.append({"node": latch, "prompt": latch.prompt, "action": latch.interact})
	return latch


## Shared with scenery reservations before the room's props are placed.
static func point(g: Game, zi: int) -> Vector2:
	var a := int(g.shortcut_edge["a"])
	var b := int(g.shortcut_edge["b"])
	var other := a if zi == b else b
	var dir := ""
	for d in ["N", "E", "S", "W"]:
		if g.neighbor(zi, String(d)) == other:
			dir = String(d)
			break
	if dir == "":
		return Vector2.ZERO
	var inward := -Vector2(Vector2i(g.DIRS[dir]))
	# Gates share the full-cell boundary. Put the latch INSIDE the playable
	# room, not beside an inset corridor (whose lateral wall is solid).
	var approach: Vector2 = g.door_pos(zi, dir)
	var room: Rect2 = g.play_rect(zi)
	if dir in ["E", "W"]:
		approach.x = room.end.x if dir == "E" else room.position.x
	else:
		approach.y = room.end.y if dir == "S" else room.position.y
	# Both side-door winches stand south of their lane. A north-side west
	# winch would sit under the player's portrait, quick bar and party frame.
	var side: float = -1.0 if dir == "W" else 1.0
	return approach + inward * Balance.SHORTCUT_LATCH_INSET.x \
		+ inward.orthogonal() * Balance.SHORTCUT_LATCH_INSET.y * side


## Actor and world identity are re-resolved at the authoritative moment. A
## remote party member is not blocked by the HOST's private reading overlay.
static func request_open(g: Game, actor: Player, key: String, seed_value: int) -> bool:
	if not is_instance_valid(g) or g.net_guest() or seed_value != g.wander_seed:
		return false
	var latch := find(g)
	if latch == null or latch.flag_name != key or latch.blocked(actor) != "":
		return false
	g.set_flag(key, true)
	g.autosave() # persist the earned world state through the ordinary save policy
	latch._mark_open()
	return true


func _ready() -> void:
	# A supported winch beside the path. Sprite and ground collision share the
	# stone footing; the upright does not make a tall invisible collision box.
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Balance.SHORTCUT_WINCH_FOOTPRINT / Vector2(20, 9)
	shadow.position = Vector2(0, Balance.SHORTCUT_WINCH_FOOTPRINT.y * 0.2)
	add_child(shadow)
	var winch := Sprite2D.new()
	winch_sprite = winch
	winch.texture = Art.tex("shortcut_winch")
	winch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	winch.scale = Vector2.ONE * (Balance.SHORTCUT_WINCH_CANVAS / float(winch.texture.get_width()))
	winch.position = Balance.SHORTCUT_WINCH_OFFSET
	add_child(winch)
	var base := StaticBody2D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Balance.SHORTCUT_WINCH_FOOTPRINT
	var collider := CollisionShape2D.new()
	collider.shape = shape
	base.add_child(collider)
	add_child(base)
	prompt = Label.new()
	var copy := "E — Open shortcut"
	prompt.set_meta("interaction_authored_copy", copy)
	prompt.text = game.interaction_copy(copy)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(prompt, 15, 4)
	game._size_factory_prompt(prompt)
	prompt.position = Vector2(-prompt.size.x * 0.5, Balance.SHORTCUT_WINCH_PROMPT_Y)
	prompt.set_meta("landmark_prompt_anchor", prompt.position)
	prompt.set_meta("shortcut_prompt", true)
	prompt.z_index = Balance.INTERACT_PROMPT_Z
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	add_child(prompt)
	if bool(game.get_flag(flag_name, false)):
		_mark_open()


func _mark_open() -> void:
	# The gate clears, but its grounded winch remains a landmark on return.
	# It no longer participates in interaction selection or blocks another prompt.
	opened = true
	prompt.visible = false
	for entry in game.interactables.duplicate():
		if entry.get("node") == self:
			game.interactables.erase(entry)


## Called by the existing pre-draw landmark hook after the final HUD transform.
## Keep a complete prompt near its mechanism without covering HUD or bodies.
func position_prompt() -> void:
	if opened or not prompt.is_visible_in_tree() or game.input_overlay_up() \
			or not game.has_local_player() or not is_instance_valid(game.hud) \
			or not is_instance_valid(game.hud.tracker_clearance):
		return
	var bounds: Rect2 = prompt.get_global_transform_with_canvas() * game.interaction_prompt_bounds(prompt)
	var body: Rect2 = winch_sprite.get_global_transform_with_canvas() * winch_sprite.get_rect()
	var hero: Rect2 = preload("res://scripts/ui/hud_clearance.gd").body_rect(game.local_player)
	var blockers: Array[Rect2] = game.hud.tracker_clearance.prompt_blockers()
	blockers.append(body)
	if hero.has_area(): blockers.append(hero)
	var gap: float = Balance.PROP_PROMPT_HUD_GAP
	var candidates: Array[Vector2] = [bounds.position,
		Vector2(body.end.x + gap, body.get_center().y - bounds.size.y * 0.5),
		Vector2(body.position.x - gap - bounds.size.x, body.get_center().y - bounds.size.y * 0.5),
		Vector2(body.get_center().x - bounds.size.x * 0.5, body.end.y + gap),
		Vector2(body.get_center().x - bounds.size.x * 0.5, minf(body.position.y, hero.position.y) - gap - bounds.size.y)]
	for candidate in candidates:
		var rect := Rect2(candidate, bounds.size)
		if not get_viewport_rect().grow(-gap).encloses(rect): continue
		var clear := true
		for blocker in blockers:
			if rect.intersects(blocker.grow(gap)):
				clear = false
				break
		if clear:
			prompt.position += get_global_transform_with_canvas().affine_inverse().basis_xform(candidate - bounds.position)
			return
	# No-fit fallback preserves the complete authored prompt, never hides it.


func _exit_tree() -> void:
	if not is_instance_valid(game):
		return
	for entry in game.interactables.duplicate():
		if entry.get("node") == self:
			game.interactables.erase(entry)


func _process(_delta: float) -> void:
	if not is_instance_valid(game) or game.world != world_owner \
			or game.wander_seed != world_seed:
		queue_free()
	elif not opened and bool(game.get_flag(flag_name, false)):
		_mark_open()


func blocked(actor: Player) -> String:
	if not is_instance_valid(game) or is_queued_for_deletion() \
			or not is_instance_valid(world_owner) or world_owner.is_queued_for_deletion() \
			or game.world != world_owner or get_parent() != world_owner \
			or game.wander_seed != world_seed or game.state != game.ST_PLAYING or not game.play_started:
		return "This mechanism is no longer here."
	var edge: Dictionary = game.shortcut_edge
	if edge.is_empty() or String(edge.get("flag", "")) != flag_name \
			or int(edge.get("far", -1)) != zone or bool(game.get_flag(flag_name, false)) \
			or not game._shortcut_closed(int(edge["a"]), int(edge["b"])):
		return "The way is already open."
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() \
			or not game.players.has(actor) or actor.dead or actor.downed or actor.ghost or actor.hp <= 0.0:
		return "No hand to work it."
	if actor == game.local_player and game.input_overlay_up():
		return "Finish reading first."
	if not actor.global_position.is_finite() or game.room_at_pos(actor.global_position) != zone \
			or actor.global_position.distance_to(global_position) >= Balance.INTERACT_RANGE:
		return "Stand beside the far-side latch."
	if not game.room_pacified(zone):
		return "Secure this room first."
	return ""


func interact() -> void:
	if not is_instance_valid(game):
		return
	var reason := blocked(game.local_player)
	if reason != "":
		game.spawn_text(global_position + Vector2(0, -70), reason, Color(0.92, 0.83, 0.62))
		return
	if game.net_guest():
		game.net_session().request_shortcut_open(flag_name)
	else:
		request_open(game, game.local_player, flag_name, world_seed)
