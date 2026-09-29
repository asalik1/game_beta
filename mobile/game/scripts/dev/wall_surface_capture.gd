extends RefCounted
## One polish session: geometry regressions, ch1, small ch2, capital gates,
## and a live terrain repaint. No separate baseline engine or art mutation.
## Every shot is re-read: a patch left at the renderer's clear color means a
## cut in the wall mass opened onto nothing (an unbuilt room's doorway).
const Contract := preload("res://scripts/tests/test_wall_surface.gd")
# Clear-color samples (every 2nd pixel of every 2nd row) only count inside a
# horizontal run this long (16px): grey texels on shadows and pool rims match
# by chance (runs of 1-2), a void band or a one-row gap is one long run.
const VOID_RUN := 8


static func run(rig: Node) -> String:
	var error := Contract.run(rig)
	if error != "": return error
	# Existing corridor geometry regression also checks presentation headroom.
	error = preload("res://scripts/tests/test_camera_corridor.gd").run(rig)
	if error != "": return error
	for i in [2, 17, 20]:
		error = await _room(rig, i, "%02d" % i)
		if error != "": return error
	var g: Game = rig.game
	# Prove repaint does not reset cap shading or leave old faces behind.
	var old_terrain: String = g.terrain_by_zone[20]
	rig.apply_terrain("magma", 20)
	await rig.frames(3)
	error = Contract.run_room(g, 20)
	rig.shot("20_west_magma", "same wall fields after live terrain repaint")
	rig.apply_terrain(old_terrain, 20)
	await rig.frames(3)
	if error != "": return error
	g.switch_chapter("ch2", true)
	await rig.frames(10)
	await rig.skip_dialogue()
	var small := -1
	var area := INF
	for i in g.zone_count:
		if g.rooms[i]["exits"].has("N") and g.play_rect(i).get_area() < area:
			small = i
			area = g.play_rect(i).get_area()
	if small < 0: return "no small-room north torch fixture"
	if area >= g.room_rect(small).get_area(): return "small-room fixture has no inset"
	error = await _room(rig, small, "ch2_small_%02d" % small)
	if error != "": return error
	g.enter_capital()
	await rig.frames(10)
	await rig.skip_dialogue()
	var sanctum: int = rig._room_by_name("wayfinder_sanctum")
	if sanctum < 0: return "capital sanctum fixture missing"
	error = await _room(rig, sanctum, "capital_sealed")
	if error != "": return error
	# Isolated rig still restores progression after the unlocked comparison.
	var old_flags: Dictionary = g.flags.duplicate(true)
	g.set_flag("completed_ch7")
	g.switch_chapter("capital", true)
	await rig.frames(10)
	await rig.skip_dialogue()
	error = await _room(rig, sanctum, "capital_open")
	g.flags = old_flags
	if error != "": return error
	print("WALL SURFACE PASS: geometry, collision seams, door lanes, torch anchors, repaint, ch1/ch2/capital")
	return ""


static func _room(rig: Node, i: int, label: String) -> String:
	var g: Game = rig.game
	rig.step("wall surfaces " + label)
	await rig._goto(i)
	await rig.skip_dialogue()
	g.terrain_event_t = 10000.0
	g.hazard_tick = 10000.0
	rig.god_mode()
	rig.hide_hud()
	rig.zoom(float(rig.arg("zoom", "1.4")))
	var pr := g.play_rect(i)
	var full := g.room_rect(i)
	var error := Contract.run_room(g, i)
	if error != "": return error
	# The shared wall band seen from above: build the room to the south (as
	# play would) so its raised north face and mass sit under this room's
	# south wall, and hold it to the same no-overdraw contract.
	var below: int = g.neighbor(i, "S")
	if below >= 0 and not g.built.get(below, false):
		g._build_room(below)
		for n in rig.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(n) and n.get("zone_idx") == below:
				n.queue_free()
	if below >= 0:
		error = Contract.run_room(g, below)
		if error != "": return error
	# Keep the native camera and player alive; frame the same review subjects.
	for view in ["room", "wall", "west", "east", "south"]:
		match view:
			"room": g.player.global_position = pr.get_center()
			"wall": g.player.global_position = Vector2(full.get_center().x, pr.position.y + 190.0)
			"west": g.player.global_position = Vector2(pr.position.x + 230.0, full.get_center().y)
			"east": g.player.global_position = Vector2(pr.end.x - 230.0, full.get_center().y)
			"south": g.player.global_position = Vector2(full.get_center().x, pr.end.y - 190.0)
		g.camera.global_position = g.player.global_position
		await rig.sim_wait(0.5)
		var shot_name: String = label + "_" + String(view)
		var path: String = rig.shot(shot_name, "wall read / native camera / " + String(g.terrain_by_zone[i]))
		var voids := _void_samples(path)
		if voids != 0:
			return "%s shows the clear color (%d sampled px in runs)" % [shot_name, voids]
	return ""


## Samples in runs still at the renderer's clear color: nothing was drawn
## there. -1 when the shot cannot be re-read.
static func _void_samples(path: String) -> int:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return -1
	img.convert(Image.FORMAT_RGBA8)
	var clear := RenderingServer.get_default_clear_color()
	var data := img.get_data()
	var stride := img.get_width() * 4
	var count := 0
	for y in range(0, img.get_height(), 2):
		var run := 0
		for at in range(y * stride, (y + 1) * stride, 8):
			var near_clear := absi(data[at] - clear.r8) <= 1 and absi(data[at + 1] - clear.g8) <= 1
			if near_clear and absi(data[at + 2] - clear.b8) <= 1:
				run += 1
				continue
			if run >= VOID_RUN:
				count += run
			run = 0
		if run >= VOID_RUN:
			count += run
	return count
