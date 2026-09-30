extends Node2D
## A small, nonblocking bridge-side prop and animated shoal. Kept with the
## room's scenery so terrain repaint and chapter teardown remove it together.
const Fishing := preload("res://scripts/fishing.gd")
const ART := preload("res://assets/sprites/fishing_nook.png")
const LIFT := 0.43  # the nook art's centre sits this share of its height above the feet
var game: Game
var zone := -1
var water_pos := Vector2.ZERO
var clock := 0.0
var prompt: Label


static func install(g: Game, zi: int, bridge: Rect2) -> Node2D:
	var spot := new()
	spot.game = g
	spot.zone = zi
	spot.position = bank_point(g, zi, bridge)
	# The shoal ripples in the channel beside the nook, never on the planks.
	var water := Vector2(bridge.get_center().x, spot.position.y + 66.0)
	if bridge.grow(10.0).has_point(water):
		water.y = bridge.position.y - 40.0
	spot.water_pos = water - spot.position
	g.world.add_child(spot)
	g.interactables.append({"node": spot, "prompt": spot.prompt,
		"action": spot.interact, "fishing": true})
	g.zone_scenery[zi].append(spot)
	return spot


## The nook's bank spot: beside the bridge's west end, unless that is inside a
## door threshold (a near-wall river on the W/E lane). Then walk along the same
## bank, away from the lane (south first, then north), until the painted nook
## clears every threshold. If no bank point clears, keep the original spot.
static func bank_point(g: Game, zi: int, bridge: Rect2) -> Vector2:
	var start := Vector2(bridge.position.x + 26, bridge.end.y - 26)
	var thresholds := preload("res://scripts/door_threshold.gd").zones(g, zi)
	var bounds := g.play_rect(zi).grow(-Balance.FISH_BANK_MARGIN)
	for step in Balance.DOOR_THRESHOLD_PLACE_TRIES:
		for heading in ([1.0] if step == 0 else [1.0, -1.0]):
			var pos := start + Vector2(0, heading * step * Balance.DOOR_THRESHOLD_RELOCATE_STEP)
			if pos.y < bounds.position.y or pos.y > bounds.end.y:
				continue
			if not preload("res://scripts/door_threshold.gd").intersects(thresholds, footprint(pos)):
				return pos
	return start


## The painted nook exactly as _ready draws it (feet at the node), plus the
## shared art pad.
static func footprint(pos: Vector2) -> Rect2:
	var size := Vector2(float(ART.get_width()) / ART.get_height(), 1.0) * Balance.FISH_PROP_HEIGHT
	return Rect2(pos + Vector2(-size.x * 0.5, -size.y * (LIFT + 0.5)), size).grow(Balance.DOOR_THRESHOLD_ART_PAD)


func _ready() -> void:
	add_to_group("fishing_spots")
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * Balance.FISH_PROP_HEIGHT / sprite.texture.get_height()
	sprite.position = Vector2(0, -Balance.FISH_PROP_HEIGHT * LIFT)
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
