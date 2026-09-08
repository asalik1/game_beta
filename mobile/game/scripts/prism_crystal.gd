extends Node2D
## Painted scenery becomes a projectile relay. No damage or ownership changes;
## the projectile itself keeps flying, with all its original payload intact.
var game: Game
var body: StaticBody2D
var center := Vector2(0, 10)
var radius := 0.0
var flash := 0.0
var guide := false
var guide_direction := Vector2.ZERO
var caption: Label
var tick := 0.0


static func eligible(g: Game, zi: int) -> bool:
	return preload("res://scripts/reactive_terrain.gd").eligible(g, zi)


static func install_room(g: Game, zi: int) -> void:
	if not eligible(g, zi):
		return
	for node in g.zone_scenery.get(zi, []):
		if node is StaticBody2D and Terrains.prop_base(String(node.get_meta("prop", ""))) in ["crystal_cluster", "crystal_spire"]:
			install(g, node)


static func install(g: Game, crystal: StaticBody2D) -> Node2D:
	if crystal.has_meta("prism_crystal"):
		return crystal.get_meta("prism_crystal")
	var prism := new()
	prism.game = g
	prism.body = crystal
	for node in crystal.get_children():
		if node is CollisionShape2D and node.shape is CircleShape2D:
			prism.center = node.position
			prism.radius = node.shape.radius
	crystal.set_meta("prism_crystal", prism)
	crystal.add_child(prism)
	return prism


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("prism_crystals")
	var readable := CanvasItemMaterial.new()
	readable.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = readable
	caption = Label.new()
	caption.text = "REFRACTING CRYSTAL\nShots bend toward nearby foes"
	caption.position = Vector2(-160, -150)
	caption.size = Vector2(320, 44)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.world(caption, 13, 4)
	caption.use_parent_material = true
	caption.add_theme_color_override("font_color", Color(0.7, 0.94, 1.0))
	caption.visible = false
	add_child(caption)
	queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()
	tick -= delta
	if tick > 0.0:
		return
	tick = Balance.PRISM_GUIDE_TICK
	guide = false
	var p: Player = game.local_player
	if is_instance_valid(p) and not game.input_overlay_up() and game.state == Game.ST_PLAYING \
			and p.global_position.distance_to(body.global_position) < Balance.PRISM_GUIDE_RANGE:
		guide = true
		var my_distance := p.global_position.distance_squared_to(body.global_position)
		for other in get_tree().get_nodes_in_group("prism_crystals"):
			if other != self and other.game == game and p.global_position.distance_squared_to(other.body.global_position) < my_distance:
				guide = false
				break
		if guide:
			var target := target_for(true, {}, Balance.PRISM_TARGET_RANGE)
			guide_direction = (target.global_position - world_center()).normalized() if target != null else Vector2.ZERO
	# If the crystal is above the hero, an above-art caption can land under
	# the fixed target health bar. Move it below the prop in that situation.
	var canvas := get_global_transform_with_canvas()
	var above: Vector2 = canvas * Vector2(-160, -150)
	caption.position = Vector2(-160, radius + 30.0) if above.y < 150.0 else Vector2(-160, -150)
	caption.visible = guide and (canvas * caption.position).y >= 150.0
	queue_redraw()


func world_center() -> Vector2:
	return body.to_global(center)


func target_for(friendly: bool, hit: Dictionary, reach: float) -> Node2D:
	var best: Node2D = null
	var best_distance := reach * reach
	var candidates: Array = get_tree().get_nodes_in_group("enemies") if friendly else game.players
	for node in candidates:
		if not is_instance_valid(node) or not node is Node2D or hit.has(node) or node.is_queued_for_deletion():
			continue
		if friendly:
			if not node is Enemy or node.game != game or node.dying or node.untargetable:
				continue
		elif not node is Player or node.dead or node.downed or node.ghost:
			continue
		var distance := world_center().distance_squared_to(node.global_position)
		if distance >= best_distance or distance < 1.0:
			continue
		var ray := PhysicsRayQueryParameters2D.create(world_center(), node.global_position, 1, [body.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		best_distance = distance
		best = node
	return best


func direction_for(p: Projectile) -> Vector2:
	var target := target_for(p.friendly, p._already_hit, minf(Balance.PRISM_TARGET_RANGE, p.life * p.vel.length()))
	if target != null:
		return (target.global_position - world_center()).normalized()
	# Without a visible foe, the crystal behaves as an ordinary angled facet.
	var normal := Vector2(1, 1 if int(body.global_position.x + body.global_position.y) % 2 == 0 else -1).normalized()
	return p.vel.normalized().bounce(normal)


func bank_flash() -> void:
	flash = Balance.PRISM_FLASH_SECONDS
	queue_redraw()


func _draw() -> void:
	var color := Color(0.38, 0.85, 1.0, 0.5)
	var r := radius + 5.0
	draw_arc(center, r, 0, TAU, 32, color, 1.5, true)
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * (r - 4.0), center + direction * (r + 4.0), color, 2.0, true)
	if flash > 0.0:
		var a := flash / Balance.PRISM_FLASH_SECONDS
		draw_arc(center, r + (1.0 - a) * 25.0, 0, TAU, 40, Color(0.6, 0.95, 1.0, a), 2.0, true)
	if guide and guide_direction != Vector2.ZERO:
		var incoming := (world_center() - game.local_player.global_position).normalized()
		draw_dashed_line(center - incoming * 85.0, center, Color(0.55, 0.85, 1.0, 0.5), 1.5, 8.0, true)
		var end := center + guide_direction * 110.0
		draw_dashed_line(center, end, Color(0.65, 0.95, 1.0, 0.8), 2.0, 8.0, true)
		draw_line(end, end - guide_direction.rotated(0.5) * 12.0, Color(0.65, 0.95, 1.0, 0.8), 2.0, true)
		draw_line(end, end - guide_direction.rotated(-0.5) * 12.0, Color(0.65, 0.95, 1.0, 0.8), 2.0, true)
