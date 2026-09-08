extends RefCounted

const Clarity := preload("res://scripts/ui/combat_foliage.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var saved := {"position": p.global_position, "target": g.hud.target_bar_unit,
		"settings": g.settings.duplicate(true), "state": g.state,
		"dead": p.dead, "downed": p.downed, "ghost": p.ghost}
	# Synchronous fixture: no frame advances while the shared hero is borrowed.
	# Use the actual log and enemy art, away from authored room scatter.
	var origin := Vector2(-14000, -14000)
	p.global_position = origin
	p.dead = false
	p.downed = false
	p.ghost = false
	g.state = Game.ST_PLAYING
	g.settings["combat_foliage"] = true
	var body := g._add_obstacle("log", origin + Vector2(21, 16))
	var visual: Node2D
	for child in body.get_children():
		if child.is_in_group("structure_occluders"):
			visual = child
	var e := Enemy.make(g, "beastkin_raider", origin, -1, 1.0)
	g.world.add_child(e)
	var other := Enemy.make(g, "wolf", origin, -1, 1.0)
	g.world.add_child(other)
	var clarity := Clarity.new()
	clarity.game = g
	clarity.process_mode = Node.PROCESS_MODE_DISABLED
	g.add_child(clarity)
	g.hud.target_bar_unit = e
	var error := _checks(g, clarity, visual, e, other)
	# Always restore, including every early return inside _checks.
	clarity.free()
	if is_instance_valid(body):
		body.free()
	if is_instance_valid(e):
		e.free()
	if is_instance_valid(other):
		other.free()
	p.global_position = saved.position
	p.dead = saved.dead
	p.downed = saved.downed
	p.ghost = saved.ghost
	g.settings = saved.settings
	g.state = saved.state
	g.hud.target_bar_unit = saved.target if is_instance_valid(saved.target) else null
	p._refresh_occlusion_outline()
	if error == "":
		print("ok: target silhouettes follow real art behind opaque logs, reject ineligible targets, restore masks with shared hero owners, and clear on teardown")
	return error


static func _checks(g: Game, clarity: Node, visual: Node2D, e: Enemy, other: Enemy) -> String:
	if visual == null:
		return "authored log has no structure occluder"
	clarity._process(0.11)
	var key := visual.get_instance_id()
	var outline = clarity._outlines.get(key)
	if not is_instance_valid(outline):
		return "real log hides the raider without a clipped target silhouette"
	if not is_equal_approx(visual.self_modulate.a, 1.0) \
		or visual.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW \
		or outline.get_parent() != visual:
		return "target visibility changed a solid prop instead of clipping to its art"
	# Sample cadence must not freeze source frames or transforms between probes.
	e.sprite.frame = mini(1, e.sprite.hframes * e.sprite.vframes - 1)
	e.sprite.flip_h = not e.sprite.flip_h
	e.sprite.flip_v = true
	e.sprite.offset += Vector2(2, -1)
	e.sprite.position += Vector2(1, -2)
	e.sprite.self_modulate.a = 0.8
	clarity._process(0.001)
	if outline.texture != e.sprite.texture or outline.frame != e.sprite.frame \
		or outline.hframes != e.sprite.hframes or outline.vframes != e.sprite.vframes \
		or outline.flip_h != e.sprite.flip_h or outline.flip_v != e.sprite.flip_v \
		or outline.offset != e.sprite.offset or not outline.global_transform.is_equal_approx(e.sprite.global_transform) \
		or not is_equal_approx(outline.modulate.a, e.sprite.modulate.a * e.sprite.self_modulate.a):
		return "target silhouette froze or diverged from the current animated sprite"
	var width: float = outline.material.get_shader_parameter("outline_width")
	var scale: float = maxf(e.sprite.global_transform.x.length(), e.sprite.global_transform.y.length())
	if not is_equal_approx(width * scale, Balance.TARGET_OCCLUSION_OUTLINE_WIDTH):
		return "target edge thickness depends on source-art resolution"
	g.hud.target_bar_unit = other
	clarity._process(0.001)
	outline = clarity._outlines.get(key)
	if not is_instance_valid(outline) or outline.texture != other.sprite.texture:
		return "switching target retained the previous enemy's silhouette"
	g.hud.target_bar_unit = e
	# Every eligibility transition must clear immediately, before the next sample.
	for condition in ["dying", "untargetable", "hidden", "sprite_hidden", "range", "disabled", "hero_dead", "lost"]:
		clarity._process(0.11)
		if not clarity._outlines.has(key):
			return "re-enabling target visibility failed before " + condition
		match condition:
			"dying": e.dying = true
			"untargetable": e.untargetable = true
			"hidden": e.visible = false
			"sprite_hidden": e.sprite.visible = false
			"range": g.player.global_position.x += Balance.COMBAT_FOLIAGE_RANGE + 100.0
			"disabled": g.settings["combat_foliage"] = false
			"hero_dead": g.player.dead = true
			"lost": g.hud.target_bar_unit = null
		clarity._process(0.001)
		if not clarity._outlines.is_empty():
			return "ineligible target kept an outline: " + condition
		e.dying = false
		e.untargetable = false
		e.visible = true
		e.sprite.visible = true
		g.player.global_position = e.global_position
		g.settings["combat_foliage"] = true
		g.player.dead = false
		g.hud.target_bar_unit = e
	# Losing alpha coverage alone must remove it at the next coverage sample.
	e.global_position.x += 350.0
	clarity._process(0.11)
	if not clarity._outlines.is_empty():
		return "uncovered target received a global silhouette"
	e.global_position.x -= 350.0
	# A hero and target can own clips in the same log. Deferred queue_free
	# children must not keep the mask enabled after BOTH owners leave this frame.
	for target_first in [true, false]:
		g.player.global_position = e.global_position
		g.player._refresh_occlusion_outline()
		clarity._process(0.11)
		if not g.player._occlusion_clips.has(key) or not clarity._outlines.has(key):
			return "shared authored log did not cover both hero and current target"
		if target_first:
			g.hud.target_bar_unit = null
			clarity._process(0.001)
		else:
			g.player.global_position.x += 350.0
			g.player._refresh_occlusion_outline()
		if visual.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW:
			return "first departing owner removed another actor's clip mask"
		if target_first:
			g.player.global_position.x += 350.0
			g.player._refresh_occlusion_outline()
		else:
			g.hud.target_bar_unit = null
			clarity._process(0.001)
		if visual.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
			return "last departing owner left a stale clip mask"
		g.hud.target_bar_unit = e
		g.player.global_position = e.global_position
	clarity._process(0.11)
	e.queue_free()
	clarity._process(0.001)
	if not clarity._outlines.is_empty():
		return "queued enemy retained a target silhouette"
	g.hud.target_bar_unit = other
	clarity._process(0.11)
	visual.free()
	clarity._process(0.11)
	if not clarity._outlines.is_empty():
		return "world repaint left a stale target silhouette reference"
	# Repaint can immediately replace a destroyed prop. Leaving the HUD must
	# also release children owned by world nodes, not just its own children.
	var replacement := g._add_obstacle("log", other.global_position + Vector2(21, 16))
	clarity._process(0.11)
	var replacement_visual: Node2D
	for child in replacement.get_children():
		if child.is_in_group("structure_occluders"):
			replacement_visual = child
	var error := ""
	if clarity._outlines.is_empty():
		error = "rebuilt prop failed to regain its target silhouette"
	clarity._exit_tree()
	if replacement_visual.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
		error = "HUD teardown left a frozen target silhouette"
	replacement.free()
	return error
