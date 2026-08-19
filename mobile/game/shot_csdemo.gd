extends ShotRig
## CLASS-SELECT ABILITY DEMOS (owner request 2026-08-19: "when clicking on the
## animation it shows an in game gif of the attack anim to completion instead").
## For each ability slot of --class=<id>: cast the REAL ability at an immortal
## dummy pack through player.use_ability (projectiles fly, dashes travel, ults
## roar — all the FX the stage's bare body clips could not show) and grab every
## 2nd frame (~30 fps) for the slot's capture window. Frames land under
## user://shots/csdemo/<class>_<slot>/f###.png; tools/art/build_csdemo.py
## encodes them into assets/videos/csdemo_<class>_<slot>.ogv for the stage.
##
## Framing: camera smoothing off, look-ahead/combat-zoom neutralized by writing
## the camera every frame; the hero starts on the room centre, dummies to the
## RIGHT (the class-select stage faces right). Crop happens in the encoder
## (CROP_* here are just printed for it): full 1280x720 frames are saved.

const SLOTS := ["a1", "a2", "a3", "ult"]
# Per-slot capture seconds (from the cast press). Ults linger; basics are quick.
const CAP_SECS := {"a1": 1.6, "a2": 2.0, "a3": 2.0, "ult": 2.6}
const PRE_ROLL := 0.25       # idle beat before the press, so the cast READS
# Run through `shot.bat csdemo --fixed-fps=30 …`: each rendered frame advances
# the sim EXACTLY 1/30 s (the viewport readback makes wall-clock frames ~7 fps,
# which under-sampled the takes), so capturing every frame = a true 30 fps video.
const EVERY_N_FRAMES := 1

var _cls := "warrior"


func _ready() -> void:
	_cls = arg("class", "warrior")
	await boot(_cls, "ch1")
	game.camera.position_smoothing_enabled = false
	game.npc_emote_t = 1.0e9
	hide_hud()
	zoom(1.55)
	await sim_wait(1.6)   # title card clears
	var p := game.player
	p.level = 40          # every ability at full rank; ult unlocked
	p.mp = 9999.0
	p.max_mp = 9999.0
	var rr := game.room_rect(2)
	await _goto_room2()
	for slot in SLOTS:
		step("capture %s %s" % [_cls, slot])
		await _capture_slot(String(slot), rr)
	finish()


func _goto_room2() -> void:
	game.player.global_position = game.room_center(2)
	game._enter_room(2)
	await frames(10)
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	await frames(2)


func _capture_slot(slot: String, rr: Rect2) -> void:
	var p := game.player
	# Reset the board: hero at a fixed spot, fresh dummy pack to the right.
	var origin := rr.position + Vector2(rr.size.x * 0.42, rr.size.y * 0.55)
	p.global_position = origin
	p.velocity = Vector2.ZERO
	for key in p.cds:
		p.cds[key] = 0.0
	p.mp = 9999.0
	var dummies: Array = []
	for i in 3:
		var e := spawn_enemy("wolf", origin + Vector2(240.0 + 70.0 * i, -40.0 + 45.0 * i), true)
		if e != null:
			e.alerted = true
			e.set_physics_process(false)   # they stand and take it
			dummies.append(e)
	# Aim at the pack: the player's aim resolves from the nearest enemy.
	await frames(4)
	# Fixed camera on the midpoint between hero and pack for the whole take —
	# a dash moves the hero THROUGH the frame instead of dragging the world.
	var cam_pos := origin + Vector2(150, -20)
	game.camera.global_position = cam_pos
	var dir := ProjectSettings.globalize_path("%s/%s_%s" % [shot_dir, _cls, slot])
	DirAccess.make_dir_recursive_absolute(dir)
	# pre-roll idle
	var idx := 0
	idx = await _grab_span(PRE_ROLL, dir, idx, cam_pos)
	# the cast
	p.use_ability(slot)
	idx = await _grab_span(float(CAP_SECS.get(slot, 2.0)), dir, idx, cam_pos)
	print("CSDEMO: %s_%s frames=%d dir=%s" % [_cls, slot, idx, dir])
	shots_taken += 1
	for e in dummies:
		if is_instance_valid(e):
			e.queue_free()
	# let lingering FX (hazards, beams) die before the next slot resets
	await sim_wait(1.2)
	for n in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(n):
			n.queue_free()


## Capture `secs` of frames (every EVERY_N_FRAMES render frames), pinning the
## camera each frame (combat zoom / look-ahead would re-frame mid-take).
func _grab_span(secs: float, dir: String, idx: int, cam_pos: Vector2) -> int:
	var t := 0.0
	var n := 0
	while t < secs:
		game.camera.global_position = cam_pos
		game.camera.zoom = Vector2(1.55, 1.55)
		await RenderingServer.frame_post_draw
		t += get_process_delta_time()
		n += 1
		if n % EVERY_N_FRAMES != 0:
			continue
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/f%03d.png" % [dir, idx])
		idx += 1
	return idx
