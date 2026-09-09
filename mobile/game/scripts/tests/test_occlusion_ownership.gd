extends RefCounted
const Clarity := preload("res://scripts/ui/combat_foliage.gd")

static func run(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var keep := {"world": g.world, "position": p.global_position,
		"target": g.hud.target_bar_unit, "settings": g.settings.duplicate(true),
		"state": g.state, "dead": p.dead, "downed": p.downed, "ghost": p.ghost}
	var origin := Vector2(-14000, -14000)
	p.global_position = origin
	p.dead = false
	p.downed = false
	p.ghost = false
	g.state = Game.ST_PLAYING
	g.settings["combat_foliage"] = true
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	t.add_child(viewport)
	var foreign_world := Node2D.new()
	viewport.add_child(foreign_world)
	var own_body := g._add_obstacle("log", origin + Vector2(21, 16))
	var foreign_body := g._add_obstacle("log", origin + Vector2(21, 16))
	foreign_body.reparent(foreign_world)
	var own: Node2D
	var foreign: Node2D
	for child in own_body.get_children():
		if child.is_in_group("structure_occluders"):
			own = child
	for child in foreign_body.get_children():
		if child.is_in_group("structure_occluders"):
			foreign = child
	var enemy := Enemy.make(g, "beastkin_raider", origin, -1, 1.0)
	g.world.add_child(enemy)
	var foreign_enemy := Enemy.make(g, "beastkin_raider", origin, -1, 1.0)
	foreign_world.add_child(foreign_enemy)
	var replacement := Node2D.new()
	g.add_child(replacement)
	var clarity := Clarity.new()
	clarity.game = g
	clarity.process_mode = Node.PROCESS_MODE_DISABLED
	g.add_child(clarity)
	var error := _checks(g, clarity, own, foreign, enemy, foreign_enemy, replacement)
	# Restore every borrowed field before releasing nodes, even after failure.
	g.world = keep.world
	p.global_position = keep.position
	p.dead = keep.dead
	p.downed = keep.downed
	p.ghost = keep.ghost
	g.settings = keep.settings
	g.state = keep.state
	g.hud.target_bar_unit = keep.target if is_instance_valid(keep.target) else null
	clarity.free()
	enemy.free()
	own_body.free()
	viewport.free()
	replacement.free()
	p._refresh_occlusion_outline()
	if error == "":
		print("ok: hero/target masks belong to their current world, reject a second canvas and foreign target, and release a retained old world's silhouettes")
	return error

static func _checks(g: Game, clarity: Node, own: Node2D, foreign: Node2D,
		enemy: Enemy, foreign_enemy: Enemy, replacement: Node2D) -> String:
	if own == null or foreign == null or own.get_world_2d() == foreign.get_world_2d() or not foreign.is_visible_in_tree():
		return "occlusion ownership fixture has no distinct visible foreign canvas"
	g.hud.target_bar_unit = enemy
	g.player._refresh_occlusion_outline()
	clarity._process(0.11)
	var own_key := own.get_instance_id()
	var foreign_key := foreign.get_instance_id()
	if not g.player._occlusion_clips.has(own_key) or not clarity._outlines.has(own_key):
		return "the ownership fixture's actual log did not cover hero and target"
	if g.player._occlusion_clips.has(foreign_key) or clarity._outlines.has(foreign_key):
		return "another scene's log gained this world's hero or target outline"
	if foreign.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
		return "the reader changed another world's clipping mode"
	g.hud.target_bar_unit = foreign_enemy
	clarity._process(0.11)
	if not clarity._outlines.is_empty():
		return "an enemy in another world became this reader's visible target"
	g.hud.target_bar_unit = enemy
	clarity._process(0.11)
	# Old world nodes can remain alive until the deferred deletion boundary.
	# Keeping them here makes stale ownership observable without a freed value.
	g.world = replacement
	g.player._refresh_occlusion_outline()
	clarity._process(0.11)
	if g.player._occlusion_clips.has(own_key) or not clarity._outlines.is_empty():
		return "world replacement retained outlines in the old living scene"
	if own.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
		return "world replacement stranded the old prop's shared mask"
	return ""
