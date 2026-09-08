extends Node2D
## A small, nonblocking bridge-side prop and animated shoal. Kept with the
## room's scenery so terrain repaint and chapter teardown remove it together.
const Fishing := preload("res://scripts/fishing.gd")
var game: Game
var zone := -1
var water_pos := Vector2.ZERO
var clock := 0.0
var prompt: Label


static func install(g: Game, zi: int, bridge: Rect2) -> Node2D:
	var spot := new()
	spot.game = g
	spot.zone = zi
	spot.position = Vector2(bridge.position.x + 26, bridge.end.y - 26)
	spot.water_pos = Vector2(bridge.get_center().x, bridge.end.y + 40) - spot.position
	g.world.add_child(spot)
	g.interactables.append({"node": spot, "prompt": spot.prompt,
		"action": spot.interact, "fishing": true})
	g.zone_scenery[zi].append(spot)
	return spot


func _ready() -> void:
	add_to_group("fishing_spots")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/fishing_nook.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * Balance.FISH_PROP_HEIGHT / sprite.texture.get_height()
	sprite.position = Vector2(0, -Balance.FISH_PROP_HEIGHT * 0.43)
	add_child(sprite)
	prompt = Label.new()
	prompt.text = game.touchify("E — Fish the river")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-120, -Balance.FISH_PROP_HEIGHT - 16)
	prompt.size = Vector2(240, 30)
	UITheme.world(prompt, 15, 4)
	prompt.visible = false
	add_child(prompt)


func _exit_tree() -> void:
	if not is_instance_valid(game):
		return
	for entry in game.interactables.duplicate():
		if entry.get("node") == self:
			game.interactables.erase(entry)


func interact() -> void:
	var reason := Fishing.blocked(game, self, zone)
	if reason != "":
		game.spawn_text(global_position + Vector2(0, -90), reason, Color(0.92, 0.83, 0.62))
		return
	preload("res://scripts/ui/fishing.gd").open(game.menus, self, zone)


func _process(delta: float) -> void:
	if game.cur_room != zone:
		return
	clock += delta
	queue_redraw()


func _draw() -> void:
	# A restrained ripple and three little moving silhouettes locate the
	# water without spawning particles, lights or a new simulation entity.
	for i in 3:
		var phase := fmod(clock * 0.35 + i / 3.0, 1.0)
		draw_set_transform(water_pos, 0, Vector2(1, 0.38))
		draw_arc(Vector2.ZERO, 10 + phase * 30, 0, TAU, 32,
			Color(0.69, 0.91, 0.88, (1.0 - phase) * 0.38), 1.4, true)
		draw_set_transform(Vector2.ZERO)
		var pos := water_pos + Vector2(sin(clock * 0.55 + i * 2.1) * 23, cos(clock * 0.7 + i * 2.1) * 9)
		draw_line(pos - Vector2(4, 1), pos + Vector2(5, -1), Color(0.12, 0.19, 0.19, 0.7), 3, true)
