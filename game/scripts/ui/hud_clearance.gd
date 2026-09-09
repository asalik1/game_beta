extends Node
## Let the world show through secondary information when it covers a body.
## Vital bars and every utility/action button keep their ordinary presentation.
var hud: Hud
var parts: Array[CanvasItem] = []
var original_alpha: Array[float] = []
var alpha := 1.0
var release_in := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for part in [hud.info_panel, hud.stats_label, hud.gold_icon, hud.gold_label, hud.cr_chip,
		hud.cr_label, hud.res_chip, hud.res_label, hud.res_orb_glow,
		hud.res_orb_core, hud.res_particles]:
		if is_instance_valid(part):
			parts.append(part)
			original_alpha.append(part.self_modulate.a)


static func body_rect(actor: Variant) -> Rect2:
	if not is_instance_valid(actor) or not actor is Node2D \
		or actor.is_queued_for_deletion() or not actor.is_visible_in_tree():
		return Rect2()
	var body := Rect2()
	if actor is Player:
		if actor.dead or actor.downed or actor.ghost:
			return Rect2()
		# Heroes render at a class-specific body height, with their painted
		# boots BELOW the physics origin. A generic -110px head fades too early.
		var height: float = Player.HERO_TARGET_BODY * Balance.CHAR_RENDER_SCALE \
			* float(Balance.HERO_CLASS_SIZE.get(actor.cls, 1.0))
		var width: float = height * Balance.HUD_INFO_BODY_WIDTH
		body = Rect2(-width * 0.5, Player.HERO_FEET_ANCHOR - height, width, height)
	elif actor is Enemy:
		if actor.dying or actor.untargetable or not is_instance_valid(actor.sprite) \
			or not actor.sprite.is_visible_in_tree() or not is_instance_valid(actor.hp_bar_fg):
			return Rect2()
		# Enemy.make already measures the painted head for its health bar.
		# Reuse it and the existing ground offset; no new texture/image caches.
		var head: float = actor.hp_bar_fg.position.y + Enemy.HP_BAR_GAP + actor.sprite.position.y
		var feet: float = maxf(head + 1.0, 6.0 * actor.art_scale * actor.render_mult)
		var cell: Rect2 = actor.sprite.get_rect()
		var width: float = cell.size.x * absf(actor.sprite.scale.x)
		body = Rect2(actor.sprite.position.x - width * 0.5, head, width, feet - head)
	else:
		return Rect2()
	var transform: Transform2D = actor.get_global_transform_with_canvas()
	var bounds := Rect2(transform * body.position, Vector2.ZERO)
	for point in [Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]:
		bounds = bounds.expand(transform * point)
	return bounds


func enabled() -> bool:
	if not is_instance_valid(hud) or not is_instance_valid(hud.game):
		return false
	var g := hud.game
	return bool(g.settings.get("hud_clearance", true)) and g.play_started \
		and g.state == Game.ST_PLAYING and g.has_local_player() \
		and not g.local_player.dead and not g.local_player.downed and not g.local_player.ghost \
		and not hud._cinematic_mode and not g.input_overlay_up() \
		and not is_instance_valid(hud.hud_popover)


func covered() -> bool:
	if not enabled():
		return false
	var panel := hud.info_panel.get_global_rect()
	for actor in [hud.game.local_player, hud.target_bar_unit]:
		if not is_instance_valid(actor) or not (actor is Player or actor is Enemy) \
			or actor.game != hud.game:
			continue
		if actor is Enemy and (not is_instance_valid(hud.game.world) \
			or not hud.game.world.is_ancestor_of(actor)):
			continue
		var body := body_rect(actor)
		if body.has_area() and panel.intersects(body):
			return true
	return false


func _process(delta: float) -> void:
	if not enabled():
		release_in = 0.0
	elif covered():
		release_in = Balance.HUD_INFO_COVER_RELEASE
	else:
		release_in = maxf(0.0, release_in - delta)
	var wanted := Balance.HUD_INFO_COVER_ALPHA if release_in > 0.0 else 1.0
	alpha = move_toward(alpha, wanted, delta * Balance.HUD_INFO_COVER_FADE_SPEED)
	for i in parts.size():
		if is_instance_valid(parts[i]):
			parts[i].self_modulate.a = original_alpha[i] * alpha


func _exit_tree() -> void:
	for i in parts.size():
		if is_instance_valid(parts[i]):
			parts[i].self_modulate.a = original_alpha[i]
