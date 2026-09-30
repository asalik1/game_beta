extends RefCounted
## shot.bat polish --canopy-overlap --seed=53029 --timeout=240 --no-import
## One session: exact outgoing strip settings, the production fix, and the
## wall contract. Before/after use the same planted props and camera anchors.
## The "top" view loans the camera's top limit so the whole strip (its top
## edge and the crowns crossing it) is in frame, as in the owner's north-door
## screenshot, and measures the rendered top edge: hard before, feathered after.
const Contract := preload("res://scripts/tests/test_wall_surface.gd")
# Rendered strip opacity in its rows 1-3 over that of its opaque body rows.
# The outgoing hard edge reads ~1; the 18px feather reads a few percent.
const HARD_EDGE_MIN := 0.7
const SOFT_EDGE_MAX := 0.4
const TOP_VIEW_ABOVE := 200.0   # screen px shown above the strip's top edge
const MIN_SAMPLES := 100        # fewer readable pixels = no verdict (NAN), never a pass


static func run(rig: Node) -> String:
	await rig._goto(2)
	await rig.skip_dialogue()
	var g: Game = rig.game
	var old_terrain: String = g.terrain_by_zone[2]
	var old_ambient: Color = g.ambient.color
	rig.apply_terrain("darkwood", 2)
	await rig.frames(3)
	var pr := g.play_rect(2)
	var lane_x := g.door_pos(2, "N").x
	var planted: Array[Node2D] = []
	# Deliberate north AND side-wall overlaps; no reliance on random scatter.
	for pos: Vector2 in [Vector2(lane_x - 310, pr.position.y + 100),
			Vector2(lane_x + 310, pr.position.y + 100),
			Vector2(pr.position.x + 75, pr.position.y + 150),
			Vector2(pr.end.x - 75, pr.position.y + 150)]:
		planted.append(g._add_obstacle("tree_autumn", pos, 1.0))
	for spec in [["castle_banner", Vector2(lane_x - 520, pr.position.y + 60)],
			["castle_statue", Vector2(lane_x + 520, pr.position.y + 60)]]:
		planted.append(g._add_obstacle(spec[0], spec[1], 1.0))
	# Exercise the backdrop factory with a tall tree, too (not only scatter).
	planted.append(g._add_backdrop("tree_autumn", Vector2(pr.position.x + 300, pr.position.y + 80), 230.0))
	var old_paused: bool = rig.get_tree().paused
	var old_position := g.player.global_position
	var old_camera := g.camera.global_position
	var old_zoom := g.camera.zoom
	var old_limit_top := g.camera.limit_top
	rig.get_tree().paused = true
	rig.zoom(1.0)
	var error := await _compare(rig, pr, lane_x)
	# Restore even on a failed check, before returning to the caller.
	for node in planted:
		node.free()
	g.player.global_position = old_position
	g.camera.limit_top = old_limit_top
	g.camera.global_position = old_camera
	g.camera.zoom = old_zoom
	g.camera.force_update_scroll()
	rig.get_tree().paused = old_paused
	rig.apply_terrain(old_terrain, 2)
	g.ambient.color = old_ambient
	if error == "": error = Contract.run(rig)
	if error == "":
		await rig._goto(17)
		await rig.skip_dialogue()
		error = Contract.run_room(g, 17)
		g.player.global_position = g.play_rect(17).position + Vector2(250, 180)
		g.camera.global_position = g.player.global_position
		await rig.frames(3)
		rig.shot("canopy_masonry_control", "unchanged dark wall mass without a foliage strip")
	if error == "": print("CANOPY OVERLAP PASS: old settings rejected; soft rendered top edge, unit-scale fringe, rooted props, stacked headroom and masonry")
	return error


static func _compare(rig: Node, pr: Rect2, lane_x: float) -> String:
	var g: Game = rig.game
	var error := Contract.canopy_overlap(g, 2)
	if error != "": return error
	var saved: Array[Dictionary] = []
	for strip: Sprite2D in g.zone_canopy[2]:
		saved.append({"node": strip, "region": strip.region_rect, "scale": strip.scale,
			"z": strip.z_index, "material": strip.material})
	# Independent negative controls: the outgoing z=20 order must fail, and so
	# must a squashed strip (a 0.75 vertical scale flattened the fringe once).
	var first: Sprite2D = saved[0].node
	first.z_index = 20
	var order_error := Contract.canopy_overlap(g, 2)
	first.z_index = saved[0].z
	first.scale = Vector2(1.0, 0.75)
	var squash_error := Contract.canopy_overlap(g, 2)
	first.scale = saved[0].scale
	if order_error == "" or squash_error == "": return "old canopy order or a squashed strip escaped regression"
	print("ok: negative controls rejected: %s; %s" % [order_error, squash_error])
	for state in ["before", "after"]:
		for row in saved:
			var strip: Sprite2D = row.node
			strip.region_rect = row.region
			strip.scale = row.scale
			strip.z_index = row.z
			strip.material = row.material
			if state == "before":
				# Outgoing implementation at this lane's parent commit, kept
				# entirely in the rig: no runtime compatibility switch.
				strip.region_rect.size.y = minf(96.0, strip.texture.get_height())
				strip.scale = Vector2.ONE
				strip.z_index = 20
				strip.material = null
		for view in ["north", "west", "east"]:
			var x: float = lane_x
			if view == "west": x = pr.position.x + 230.0
			if view == "east": x = pr.end.x - 230.0
			g.player.global_position = Vector2(x, pr.position.y + 130.0)
			g.camera.global_position = g.player.global_position
			g.camera.force_update_scroll()
			await rig.frames(3)
			rig.shot("canopy_%s_%s" % [view, state], "same rooted trees, banner, statue, backdrop tree; " + state)
		var edge: float = await _top_view(rig, pr, lane_x, state)
		print("canopy top edge %s: rendered top/body opacity ratio %.3f" % [state, edge])
		if state == "before" and not edge > HARD_EDGE_MIN:
			error = "top-edge probe cannot see the outgoing hard edge (%.3f)" % edge
		if state == "after" and not edge < SOFT_EDGE_MAX:
			error = "wall foliage still renders a hard top edge (%.3f)" % edge
		if error != "": break
	for row in saved:
		var strip: Sprite2D = row.node
		strip.region_rect = row.region
		strip.scale = row.scale
		strip.z_index = row.z
		strip.material = row.material
	if error == "": error = Contract.canopy_overlap(g, 2)
	if error == "": error = Contract.run_room(g, 2)
	return error


## The whole strip in frame: top limit loaned above the strip (the room camera
## clamps at the wall-mass lip, below the strip's top edge). After the natural
## shot, a flat card is slipped directly under the strips and the frame is read
## four times (light/dark card, strips shown/hidden). Per pixel,
## 1 - (shown_light - shown_dark) / (hidden_light - hidden_dark) is the strip's
## rendered opacity, whatever the wall behind it or a crown in front of it
## (fully covered pixels divide by ~0 and are skipped). Returns the mean
## opacity of the top rows over that of the opaque body rows (NAN if unread).
static func _top_view(rig: Node, pr: Rect2, lane_x: float, state: String) -> float:
	var g: Game = rig.game
	var strips: Array = g.zone_canopy[2]
	var top: float = (strips[0] as Sprite2D).global_position.y
	var old_limit := g.camera.limit_top
	# The strip hangs above the room's usual camera top (the wall-mass lip), as
	# in the north-door lane where the corridor camera lifts that limit.
	g.camera.limit_top = mini(old_limit, floori(top - TOP_VIEW_ABOVE))
	g.player.global_position = Vector2(lane_x, pr.position.y + 130.0)
	g.camera.global_position = Vector2(lane_x, top - TOP_VIEW_ABOVE + g.get_viewport_rect().size.y * 0.5)
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	await rig.frames(3)
	rig.shot("canopy_top_%s" % state, "whole strip in frame (loaned top limit): band top edge and crowns across it; " + state)
	var card := Polygon2D.new()
	card.polygon = PackedVector2Array([Vector2(pr.position.x - 400, top - 400), Vector2(pr.end.x + 400, top - 400),
		Vector2(pr.end.x + 400, top + 400), Vector2(pr.position.x - 400, top + 400)])
	card.z_index = Balance.WALL_CANOPY_Z - 1
	card.z_as_relative = false
	g.world.add_child(card)
	var reads := {}
	for tone in ["light", "dark"]:
		card.color = Color(0.8, 0.8, 0.8) if tone == "light" else Color.BLACK
		for shown in [true, false]:
			for strip: Sprite2D in strips:
				strip.visible = shown
			await rig.frames(3)
			reads["%s_%s" % [tone, shown]] = rig.capture_image()
	for strip: Sprite2D in strips:
		strip.visible = true
	card.free()
	# Map strip pixels to the screen while the camera still frames the reads.
	var edge := _opacity(reads, strips, [1.5, 2.5, 3.5])
	var body := _opacity(reads, strips, [24.5, 28.5, 32.5, 36.5, 40.5])
	g.camera.limit_top = old_limit
	g.camera.force_update_scroll()
	await rig.frames(2)
	return edge / body if body > 0.0 else NAN


## Mean rendered strip opacity over the strips' interior columns (span-end
## feathers excluded) at the given local rows, mapped to screen pixels.
static func _opacity(reads: Dictionary, strips: Array, rows: Array) -> float:
	var shown_light: Image = reads["light_true"]
	var shown_dark: Image = reads["dark_true"]
	var hidden_light: Image = reads["light_false"]
	var hidden_dark: Image = reads["dark_false"]
	var bounds := Rect2i(Vector2i.ZERO, shown_light.get_size())
	var margin := Balance.WALL_CANOPY_FEATHER + 4.0
	var total := 0.0
	var count := 0
	var covered := 0
	var outside := 0
	for strip: Sprite2D in strips:
		var xform := strip.get_global_transform_with_canvas()
		for ly: float in rows:
			var lx := margin
			while lx < strip.region_rect.size.x - margin:
				var at := Vector2i(xform * Vector2(lx, ly))
				lx += 2.0
				if not bounds.has_point(at):
					outside += 1
					continue
				var card_span := _sum(hidden_light.get_pixelv(at).srgb_to_linear()) \
					- _sum(hidden_dark.get_pixelv(at).srgb_to_linear())
				if card_span < 0.05:
					covered += 1
					continue   # a crown or prop fully covers the strip here
				var through := _sum(shown_light.get_pixelv(at).srgb_to_linear()) \
					- _sum(shown_dark.get_pixelv(at).srgb_to_linear())
				total += clampf(1.0 - through / card_span, 0.0, 1.0)
				count += 1
	print("canopy opacity rows %s: %d read, %d covered, %d off screen, mean %.3f" % [
		str(rows), count, covered, outside, total / maxf(1.0, float(count))])
	return total / float(count) if count >= MIN_SAMPLES else NAN


static func _sum(c: Color) -> float:
	return c.r + c.g + c.b
