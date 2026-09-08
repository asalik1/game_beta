extends Node
## Foliage softens; solid props mask a thin outline of the current target.

var game: Game
var _sample_in := 0.0
var _faded := {}
var _outlines := {}
var _target: Enemy
var _outline_material: ShaderMaterial


func _process(delta: float) -> void:
	_sample_in -= delta
	if _sample_in <= 0.0 or _current_target() != _target:
		_sample_in = Balance.COMBAT_FOLIAGE_SAMPLE_SECONDS
		_sample()
	for id in _faded.keys():
		var entry: Dictionary = _faded[id]
		var visual = entry.visual
		if not is_instance_valid(visual):
			_faded.erase(id)
			continue
		var wanted: float = entry.alpha * (Balance.COMBAT_FOLIAGE_ALPHA if entry.covered else 1.0)
		visual.self_modulate.a = move_toward(visual.self_modulate.a, wanted, delta * Balance.COMBAT_FOLIAGE_FADE_SPEED)
		if not entry.covered and is_equal_approx(visual.self_modulate.a, wanted):
			_faded.erase(id)
	if not is_instance_valid(_target) or not is_instance_valid(_target.sprite):
		return
	var source: Sprite2D = _target.sprite
	if _outline_material != null:
		# Enemy masters have different resolutions; a fixed texture-pixel edge
		# vanished on larger sheets. Hold the visible width through clip swaps.
		var source_scale := maxf(source.global_transform.x.length(), source.global_transform.y.length())
		_outline_material.set_shader_parameter("outline_width",
			Balance.TARGET_OCCLUSION_OUTLINE_WIDTH / maxf(source_scale, 0.001))
	for id in _outlines.keys():
		var outline = _outlines[id]
		if not is_instance_valid(outline):
			_outlines.erase(id)
			continue
		outline.texture = source.texture
		outline.hframes = source.hframes
		outline.vframes = source.vframes
		outline.frame = source.frame
		outline.centered = source.centered
		outline.offset = source.offset
		outline.flip_h = source.flip_h
		outline.flip_v = source.flip_v
		outline.global_transform = source.global_transform
		outline.modulate.a = source.modulate.a * source.self_modulate.a


func _current_target() -> Enemy:
	if game == null or not game.has_local_player() or not is_instance_valid(game.hud) \
		or not bool(game.settings.get("combat_foliage", true)):
		return null
	var p: Player = game.local_player
	var tracked = game.hud.target_bar_unit
	var target := tracked as Enemy if is_instance_valid(tracked) else null
	if game.state != Game.ST_PLAYING or p.dead or p.downed or p.ghost \
		or target == null or target.dying or target.untargetable or target.is_queued_for_deletion() \
		or not target.is_visible_in_tree() or not is_instance_valid(target.sprite) \
		or not target.sprite.is_visible_in_tree() \
		or p.global_position.distance_to(target.global_position) > Balance.COMBAT_FOLIAGE_RANGE:
		return null
	return target


func _sample() -> void:
	for entry in _faded.values():
		entry.covered = false
	_target = _current_target()
	var needed := {}
	if _target != null:
		var feet := _target.global_position
		var head := feet + Vector2(0, -60)
		if is_instance_valid(_target.hp_bar_fg):
			head.y = _target.hp_bar_fg.global_position.y + 12.0
		var middle := head.lerp(feet, 0.5)
		var probes := [head, middle, middle + Vector2(-18, 0), middle + Vector2(18, 0)]
		for candidate in get_tree().get_nodes_in_group("combat_foliage"):
			var visual := candidate as Node2D
			if _covers(visual, feet, head, middle, probes):
				var id := visual.get_instance_id()
				if not _faded.has(id):
					_faded[id] = {"visual": visual, "alpha": visual.self_modulate.a, "covered": true}
				_faded[id].covered = true
		for candidate in get_tree().get_nodes_in_group("structure_occluders"):
			var visual := candidate as Node2D
			if visual == null or visual.is_in_group("combat_foliage"):
				continue
			if _covers(visual, feet, head, middle, probes):
				var id := visual.get_instance_id()
				needed[id] = true
				if not is_instance_valid(_outlines.get(id)):
					_outlines[id] = _make_outline(visual)
	for id in _outlines.keys():
		var outline = _outlines[id]
		if not is_instance_valid(outline):
			_outlines.erase(id)
		elif not needed.has(id):
			_release_outline(outline)
			_outlines.erase(id)


func _covers(visual: Node2D, feet: Vector2, head: Vector2, middle: Vector2, probes: Array) -> bool:
	if visual == null or visual.is_queued_for_deletion() \
		or feet.y >= float(visual.get_meta("occlusion_sort_y", visual.global_position.y)):
		return false
	var radius := float(visual.get_meta("occlusion_radius", 0.0))
	var reach := radius + feet.distance_to(head)
	if (radius > 0.0 and middle.distance_squared_to(visual.global_position) > reach * reach) \
		or not visual.is_visible_in_tree():
		return false
	for point in probes:
		if game.local_player._visual_alpha_at(visual, point) >= Balance.PLAYER_OCCLUSION_ALPHA_THRESHOLD:
			return true
	return false


func _make_outline(occluder: Node2D) -> Sprite2D:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = load("res://shaders/occluded_outline.gdshader")
		_outline_material.set_shader_parameter("outline_color", Balance.TARGET_OCCLUSION_OUTLINE_COLOR)
	var outline := Sprite2D.new()
	outline.name = "TargetOcclusionOutline"
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	outline.material = _outline_material
	outline.add_to_group("occlusion_clip_outlines")
	occluder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	occluder.add_child(outline)
	return outline


func _release_outline(outline: Sprite2D) -> void:
	var occluder := outline.get_parent()
	outline.queue_free()
	if occluder is CanvasItem:
		for child in occluder.get_children():
			if child != outline and not child.is_queued_for_deletion() \
				and child.is_in_group("occlusion_clip_outlines"):
				return
		occluder.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED


func _exit_tree() -> void:
	for entry in _faded.values():
		var visual = entry.visual
		if is_instance_valid(visual):
			visual.self_modulate.a = entry.alpha
	_faded.clear()
	for outline in _outlines.values():
		if is_instance_valid(outline):
			_release_outline(outline)
	_outlines.clear()
