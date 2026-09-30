extends RefCounted
## One fixed-60-Hz rig: real room construction/preview/camera, controlled
## walking positions (combat and collision disabled) that change rooms only
## through the production boundary poll, then quick sections. The campaign
## is disposable; no state is borrowed from an earlier test.
class QuickSuite extends "res://scripts/autotest.gd":
	func _ready() -> void: pass

const Corridor := preload("res://scripts/camera_corridor.gd")
const Surface := preload("res://scripts/wall_surface.gd")
# Desktop, tall (4:3 tablet) and wide (19.5:9 phone, stretch "expand") canvases.
const CANVASES := [Vector2i(1280, 720), Vector2i(1280, 960), Vector2i(1560, 720)]
# A walk parallel to a doorway wall, this far inside it, crossing the lane.
const SIDE_DEPTH := 150.0
const SIDE_SPAN := 360.0
const SETTLE_FRAMES := 120

var g: Game
var r: ShotRig
var rows: Array[Dictionary] = []
var errors: Array[String] = []


static func run(rig: ShotRig) -> String:
	var probe := new()
	probe.r = rig
	var window := rig.get_window()
	var saved := [window.size, window.content_scale_size, window.content_scale_aspect]
	await rig.boot("warrior", "ch1", false)
	probe.g = rig.game
	await probe._exercise()
	window.content_scale_aspect = saved[2]
	window.content_scale_size = saved[1]
	window.size = saved[0]
	# All campaign mutations belong to this disposable world, including
	# newly built rooms, ambient emitters, title timers and visited flags.
	rig.game.free()
	rig.game = null
	rig.get_tree().paused = false
	await rig.frames(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir.path_join("transitions.json"), FileAccess.WRITE)
	if file == null:
		probe.errors.append("could not write transition frame recording")
	else:
		file.store_string(JSON.stringify({"rows": probe.rows, "errors": probe.errors}, "\t"))
		file.close()
	# One heavy run always yields both verdicts: the quick sections run even
	# after a failed walk (a quick failure quits with its own marker).
	var transition_error := "; ".join(probe.errors)
	if transition_error == "":
		print("CAMERA TRANSITIONS PASS: both axes/directions, three canvases, fresh lazy builds, sideways passes, teleport and chapter snap")
	else:
		print("CAMERA TRANSITIONS FAIL: " + transition_error)
	# Same pattern as ui_frame_live: one engine/lock, fresh suite campaign.
	var suite := QuickSuite.new()
	suite.quick = true
	suite.process_mode = Node.PROCESS_MODE_ALWAYS
	rig.add_child(suite)
	await suite._run_systems()
	if suite._failed: return "transition bundle quick systems failed"
	await suite._test_pause_menu()
	if suite._failed: return "transition bundle quick pause failed"
	suite.free()
	rig.get_tree().paused = false
	await rig.frames(3)
	print("CAMERA BUNDLE QUICK PASS (windowed quick systems/UI/pause)")
	if transition_error != "": return transition_error
	print("CAMERA TRANSITION BUNDLE PASS (windowed quick systems/UI/pause + transition rig)")
	return ""


func _freeze() -> void:
	g.set_process(false)
	g.local_player.set_physics_process(false)
	for actor in r.get_tree().get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	g.settings["combat_framing"] = false
	g.settings["camera_shake"] = 0.0
	g.settings["camera_lead"] = 1.0
	g.local_player.velocity = Vector2.ZERO
	g.request_pause(false)


func _exercise() -> void:
	_freeze()
	await r.frames(1)
	if absf(r.get_process_delta_time() - 1.0 / 60.0) > 0.0001:
		errors.append("transition rig requires shot.bat --fixed-fps=60")
		return
	var last_source := -1
	for size in CANVASES:
		r.get_window().content_scale_size = size
		r.get_window().size = size
		await r.frames(3)
		if g.get_viewport_rect().size != Vector2(size):
			errors.append("canvas %s not applied: %s" % [size, g.get_viewport_rect().size])
			return
		# Fresh pairs per canvas: each canvas walks into an unbuilt room
		# (corridor preview, lazy build, first-visit card, ambient re-seed).
		for direction in ["S", "E"]:
			var pair := _fresh_pair(direction)
			if pair.is_empty():
				errors.append("no fresh unlocked %s corridor at %s" % [direction, size])
				return
			await _walk(pair[0], pair[1], direction, size, true)
			await _walk(pair[1], pair[0], "N" if direction == "S" else "W", size, false)
			await _sideways(pair[0], direction, size)
			last_source = pair[0]
		# Opposing doorways overlap in small rooms on wide and tall canvases.
		var through := _small_pass_through()
		if through.is_empty():
			print("CAMERA WALK note: ch1 has no unlocked small pass-through room")
		else:
			await _walk(through[0], through[1], through[2], size, false)
	# Explicit live teleport uses the default walked=false path, including
	# same-room short landings that a distance-only detector would miss.
	var p := g.local_player
	for distance in [80.0, 700.0]:
		p.global_position = p.global_position + Vector2(distance, 0) if distance < Balance.CAMERA_FRAME_TELEPORT \
			else g.room_center(last_source)
		g._enter_room(g.room_at_pos(p.global_position), true)
		_snap("teleport " + str(distance))
	# Actual chapter rebuild replaces the world. It must not inherit
	# a corridor pan even if the new room has the same numeric index.
	g.switch_chapter("ch2")
	_freeze()
	_snap("chapter load")


func _open(i: int, j: int, direction: String) -> bool:
	var opposite: String = {"N": "S", "S": "N", "E": "W", "W": "E"}[direction]
	return j >= 0 and g.rooms[i].exits.has(direction) and g.rooms[j].exits.has(opposite) \
		and g._edge_unlocked(i, j) and g.zones[i].get("boss", "") == "" and g.zones[j].get("boss", "") == ""


func _fresh_pair(direction: String) -> Array:
	for i in g.rooms.size():
		var j: int = g.neighbor(i, direction)
		if _open(i, j, direction) and not g.built.get(j, false):
			return [i, j]
	return []


## [start room, end room, direction] walking through a small room between
## two opposing doorways, or [] when the chapter has none.
func _small_pass_through() -> Array:
	for k in g.rooms.size():
		if not g.room_type(k) in Balance.SMALL_ROOM_TYPES:
			continue
		for axis in [["W", "E"], ["N", "S"]]:
			var a: int = g.neighbor(k, axis[0])
			var b: int = g.neighbor(k, axis[1])
			if a >= 0 and b >= 0 and _open(a, k, axis[1]) and _open(k, b, axis[1]):
				return [a, b, axis[1]]
	return []


func _snap(label: String) -> void:
	var immediate := g.camera.get_screen_center_position()
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	var remaining := immediate.distance_to(g.camera.get_screen_center_position())
	print("CAMERA SNAP %s: remaining=%.4f px" % [label, remaining])
	if remaining > 0.01: errors.append(label + " did not snap on arrival")


func _walk(source: int, target: int, direction: String, size: Vector2i, forward: bool) -> void:
	var label := "%s %s %d->%d" % [direction, size, source, target]
	var was_fresh: bool = not g.built.get(target, false)
	var result := await _path(label, source, g.room_center(source), g.room_center(target))
	if forward and not was_fresh: errors.append(label + " target was not fresh")
	if was_fresh and not result.saw_preview: errors.append(label + " fresh walk did not exercise preview")
	if result.crossed == 0 or g.cur_room != target or not g.built.get(target, false):
		errors.append(label + " did not build/enter target through the boundary poll")


## Walk parallel to the source's doorway wall, SIDE_DEPTH inside it, across
## the door lane: the doorway envelope opens and closes sideways.
func _sideways(source: int, direction: String, size: Vector2i) -> void:
	var play: Rect2 = g.play_rect(source)
	var lane: Vector2 = g.door_pos(source, direction)
	var start: Vector2
	var finish: Vector2
	if direction == "S":
		var y := play.end.y - SIDE_DEPTH
		start = Vector2(maxf(play.position.x + 52.0, lane.x - SIDE_SPAN), y)
		finish = Vector2(minf(play.end.x - 52.0, lane.x + SIDE_SPAN), y)
	else:
		var x := play.end.x - SIDE_DEPTH
		start = Vector2(x, maxf(play.position.y + 62.0, lane.y - SIDE_SPAN))
		finish = Vector2(x, minf(play.end.y - 62.0, lane.y + SIDE_SPAN))
	var label := "sideways %s %s room %d depth %d" % [direction, size, source, SIDE_DEPTH]
	var result := await _path(label, source, start, finish)
	if result.crossed != 0 or g.cur_room != source: errors.append(label + " left its room")


func _path(label: String, source: int, start: Vector2, finish: Vector2) -> Dictionary:
	r.step("camera walk " + label)
	var p := g.local_player
	var axis: Vector2 = (finish - start).normalized()
	p.global_position = start
	p.velocity = Vector2.ZERO
	g._enter_room(source)
	await r.skip_dialogue()
	_freeze()
	g._tick_camera(0.0)
	g.camera.reset_smoothing()
	await r.frames(2)
	var previous := g.camera.get_screen_center_position()
	var previous_delta := 0.0
	var maximum := 0.0
	var change := 0.0
	var handoff_max := 0.0
	var saw_preview := false
	var crossed := 0
	var samples: Array[Dictionary] = []
	var frames := ceili(start.distance_to(finish) / (p.speed / 60.0))
	for frame in frames + SETTLE_FRAMES:
		var delta := r.get_process_delta_time()
		if absf(delta - 1.0 / 60.0) > 0.0001:
			errors.append("transition rig requires shot.bat --fixed-fps=60")
			return {"crossed": crossed, "saw_preview": saw_preview}
		p.global_position = p.global_position.move_toward(finish, p.speed * delta)
		p.velocity = axis * p.speed if p.global_position != finish else Vector2.ZERO
		# The room being left must not hold the walk in as a hot room.
		g.zone_alive[g.cur_room] = 0
		var before := g.cur_room
		g._poll_room_boundary()
		if g.cur_room != before:
			_freeze()
			crossed += 1
		g._tick_camera(delta)
		saw_preview = saw_preview or g.world.get_node_or_null("CorridorPreview") != null
		await RenderingServer.frame_post_draw
		var center := g.camera.get_screen_center_position()
		var distance := previous.distance_to(center)
		maximum = maxf(maximum, distance)
		if frame > 0: change = maxf(change, absf(distance - previous_delta))
		var boundary: int = g.room_at_pos(p.global_position)
		if g.room_at_pos(p.global_position + axis * p.speed) != boundary \
				or g.room_at_pos(p.global_position - axis * p.speed) != boundary:
			handoff_max = maxf(handoff_max, distance)
		samples.append({"frame": frame, "room": g.cur_room, "hero": [p.global_position.x, p.global_position.y],
			"center": [center.x, center.y], "delta": distance,
			"limits": [g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom]})
		previous = center
		previous_delta = distance
		await r.get_tree().process_frame
	print("CAMERA WALK %s: expected=%.3f max=%.3f handoff=%.3f change=%.3f px/frame crossed=%d preview=%s" % [
		label, p.speed / 60.0, maximum, handoff_max, change, crossed, saw_preview])
	if maximum > Balance.CAMERA_TRANSITION_MAX_PAN_SPEED / 60.0:
		errors.append("%s camera jumped %.3f px" % [label, maximum])
	var settled := g.camera.get_screen_center_position()
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	if settled.distance_to(g.camera.get_screen_center_position()) > 1.0:
		errors.append(label + " camera did not settle")
	# Eased limits must land exactly on the pose's own doorway bounds, and
	# approach scenery must not outlive them.
	var wanted := {}
	var bounds: Rect2 = Surface.view_bounds(g, g.cur_room,
		Corridor.effective_bounds(g, p, g.play_rect(g.cur_room), wanted))
	if wanted.is_empty() and g.world.get_node_or_null("CorridorPreview") != null:
		errors.append(label + " preview outlived its settled limits")
	var limits := [g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom]
	if limits != [int(bounds.position.x), ceili(bounds.position.y), int(bounds.end.x), int(bounds.end.y)]:
		errors.append("%s limits %s did not settle on %s" % [label, limits, bounds])
	rows.append({"walk": label, "max_delta": maximum, "handoff_max": handoff_max, "max_change": change,
		"expected_pan": p.speed / 60.0, "samples": samples})
	return {"crossed": crossed, "saw_preview": saw_preview}
