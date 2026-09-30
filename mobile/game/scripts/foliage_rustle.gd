extends Area2D
## Local cosmetic contact sensor. Mirrored bodies retain layers 2/4, so guests
## see their movement without authority checks, velocity tests or new RPCs.
var game: Node
var wind: ShaderMaterial
var decay: Tween
var contact_radius := 0.0   # footprint radius in the art's own (unscaled) px
var footprint := 0.0        # the same footprint in world px, fixed once planted
## Widest planted footprint so far: pads strike_circle's room test so a plant
## just across a room edge still hears an impact that reaches it.
static var _reach := 0.0


static func understory(base: String) -> bool:
	return base.begins_with("bush") or base.begins_with("grass") \
		or base in ["flower", "cattail", "frost_reeds"]


static func attach(g: Node, visual: Node2D, size: Vector2) -> void:
	if visual is AnimatedSprite2D:
		visual.stop()
		visual.frame = 0
	var sensor := new()
	sensor.name = "FoliageRustle"
	sensor.game = g
	sensor.wind = Art.wind_material().duplicate()
	sensor.wind.set_shader_parameter("amp", 0.0)
	sensor.wind.set_shader_parameter("speed", Balance.FOLIAGE_RUSTLE_SPEED)
	visual.material = sensor.wind
	sensor.collision_layer = 0
	sensor.collision_mask = 2 | 4
	sensor.monitorable = false
	# Rooted ground footprint, scaled with the art (including mirrored variants).
	sensor.position.y = size.y * Balance.FOLIAGE_CONTACT_Y
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size.x * Balance.FOLIAGE_CONTACT_RADIUS
	sensor.contact_radius = circle.radius
	shape.shape = circle
	sensor.add_child(shape)
	sensor.body_entered.connect(sensor._brushed, CONNECT_DEFERRED)
	visual.add_child(sensor)


func _ready() -> void:
	if game == null:
		return
	footprint = contact_radius * absf(global_scale.x)
	_reach = maxf(_reach, footprint)
	# Scenery never moves once planted and rooms are never torn down, so one
	# world-wide list would grow with every room visited. Bucket each plant by
	# the room it stands in; an impact walks only the rooms it can reach.
	add_to_group(_bucket(game, int(game.room_at_pos(global_position))))


## Scoped to one game as well as one room: paired co-op rigs share a tree.
static func _bucket(g: Node, room: int) -> StringName:
	return StringName("foliage_rustle_%d_%d" % [g.get_instance_id(), room])


func _brushed(body) -> void:
	# Untyped on purpose: a deferred call can arrive after the body was freed.
	if not is_instance_valid(body):
		return
	if body is Player and body.game == game and not body.dead and not body.ghost:
		rustle()
	elif body is Enemy and body.game == game and not body.dying:
		rustle()


func rustle() -> void:
	if is_queued_for_deletion() or not is_visible_in_tree():
		return
	if decay != null:
		decay.kill()
	# Tune in screen/world px so high-resolution and legacy art sway equally.
	# Geometry only: no luminance/alpha pulse, and no accumulating amplitude.
	var amp := Balance.FOLIAGE_RUSTLE_AMPLITUDE / maxf(absf(global_scale.x), 0.001)
	wind.set_shader_parameter("amp", amp)
	# The sway runs on the shader's own clock, which keeps going under a solo
	# pause (menus, dialogue, choices). The decay must keep going too, or a
	# plant caught mid-rustle shakes on at that amplitude until the pause ends.
	decay = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	decay.tween_method(func(value: float): wind.set_shader_parameter("amp", value),
		amp, 0.0, Balance.FOLIAGE_RUSTLE_DECAY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func strike_circle(g: Node, center: Vector2, radius: float) -> void:
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	# Event-only work: the rooms whose cell the impact (plus the widest plant
	# footprint) can reach, and -1 for plants set down off the room graph.
	var box := Rect2(center, Vector2.ZERO).grow(radius + _reach)
	var rooms: Array[int] = [-1]
	for zi in g.rooms.size():
		if g.room_rect(zi).intersects(box):
			rooms.append(zi)
	var tree: SceneTree = g.get_tree()
	for room in rooms:
		for sensor in tree.get_nodes_in_group(_bucket(g, room)):
			if center.distance_to(sensor.global_position) <= radius + sensor.footprint:
				sensor.rustle()
