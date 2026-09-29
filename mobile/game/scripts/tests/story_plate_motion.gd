extends RefCounted
## Story plate camera (T49) on a deterministic tween clock with real paintings
## and a real HUD: an advance freezes the on-screen blend at its live poses,
## every dissolve (within a cue and across cues) starts in register with the
## plate beneath it, directed plates never expose an edge, the reading drift
## ends, and wide bars, SKIP and the guarded finish are unchanged.
## Systems/quick tier: autotest.gd runs suite(game) headless on every suite.
## Rendered: `shot.bat coop_closers --plate-motion --timeout=300` runs the same
## checks on the host reader and saves plate_<case>_before/_after shots.

## Painting-center registration tolerance (px) at a dissolve start. The old
## alternating recipe registered exactly; a covering clamp may shift a start.
const REGISTER_TOLERANCE := 2.0


static func suite(g: Game, rig: ShotRig = null) -> String:
	var tree := g.get_tree()
	var window := tree.root
	# The co-op rig renders its readers in SubViewports; the suite uses the window.
	var viewport := g.get_viewport() as SubViewport
	var saved := {"hud": g.hud, "mode": g.process_mode, "paused": tree.paused,
		"log": g.convo_log.duplicate(true), "order": g.convo_log_order.duplicate(),
		"window_size": window.size, "aspect": window.content_scale_aspect,
		"viewport_size": viewport.size if viewport != null else Vector2i.ZERO,
		"hud_visible": g.hud.visible}
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.hud.hide()
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.size = Vector2i(1600, 720)
	if viewport != null:
		viewport.size = Vector2i(1600, 720)
	var hud := Hud.new()
	hud.game = g
	g.hud = hud
	g.add_child(hud)
	hud.set_process(false)
	await _frames(tree, 2)
	var errors: Array[String] = []
	await _checks(g, hud, rig, errors)
	# Restore in the caller so every failed check goes through the same cleanup.
	hud.cancel_conversation()
	hud.free()
	g.hud = saved.hud
	g.hud.visible = saved.hud_visible
	g.convo_log = saved.log
	g.convo_log_order = saved.order
	tree.paused = saved.paused
	window.content_scale_aspect = saved.aspect
	window.size = saved.window_size
	if viewport != null:
		viewport.size = saved.viewport_size
	await _frames(tree, 2)
	g.process_mode = saved.mode
	if errors.is_empty():
		print("STORY PLATE MOTION PASS: early/mid-dissolve/long-hold advances keep the on-screen blend (poses + opacity), same-tick advances, registered dissolves within and across cues, 21 focal envelopes, unlisted defaults, bounded drift, wide bars, SKIP and guarded finish")
	return "; ".join(errors)


static func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.process_frame


static func _shot(rig: ShotRig, name: String) -> void:
	if rig != null:
		rig.shot(name)


static func _mount(g: Game, hud: Hud) -> Cutscene:
	var prior := g.get_tree().get_processed_tweens()
	var scene := Cutscene.new(g)
	hud.add_child(scene)
	hud.move_child(scene, hud.dialogue_box.get_index())
	for tween: Tween in g.get_tree().get_processed_tweens():
		if tween not in prior:
			tween.custom_step(1.0) # settle only this fixture's intro
	return scene


static func _step(scene: Cutscene, seconds: float) -> void:
	if not scene._sequence_tween.is_valid():
		return
	scene._sequence_tween.pause()
	while seconds > 0.0 and scene._sequence_tween.is_valid():
		var delta := minf(seconds, 0.02)
		scene._sequence_tween.custom_step(delta)
		seconds -= delta


## Where a plate currently draws its painting center, in art-stack space.
static func _center(plate: TextureRect) -> Vector2:
	return plate.get_transform() * (plate.size / 2.0)


static func _covers(scene: Cutscene, plate: TextureRect) -> bool:
	return plate.get_global_rect().grow(0.01).encloses(scene.art_stack.get_global_rect())


## Every plate that shows through (bottom to top) as [node, transform, alpha,
## visible weight]. Weight = own alpha times what the plates above leave open.
static func _on_screen(scene: Cutscene) -> Array:
	var shown := []
	var uncovered := 1.0
	var stack := scene.art_stack.get_children()
	for idx in range(stack.size() - 1, -1, -1):
		var plate: TextureRect = stack[idx]
		var weight := plate.modulate.a * uncovered
		if weight >= Balance.STORY_RETAIN_MIN_WEIGHT:
			shown.push_front([plate, plate.get_transform(), plate.modulate.a, weight])
		uncovered *= 1.0 - plate.modulate.a
	return shown


## The advance froze exactly `shown`: same nodes, order, pose and opacity, with
## only fresh plates (still fully transparent) stacked above them.
static func _check_frozen(scene: Cutscene, shown: Array, where: String,
		errors: Array[String]) -> void:
	var stack := scene.art_stack.get_children()
	if stack.size() < shown.size():
		errors.append(where + " dropped a painting that was on screen")
		return
	for idx in shown.size():
		var plate: TextureRect = stack[idx]
		var entry: Array = shown[idx]
		if plate != entry[0]:
			errors.append(where + " dropped or reordered a painting that was on screen")
			return
		if plate.modulate.a != entry[2]:
			errors.append(where + " popped a painting's opacity (%.3f -> %.3f)" % [entry[2], plate.modulate.a])
			return
		if not plate.get_transform().is_equal_approx(entry[1]):
			errors.append(where + " snapped a painting's framing")
			return
	for idx in range(shown.size(), stack.size()):
		if (stack[idx] as TextureRect).modulate.a != 0.0:
			errors.append(where + " showed the next painting before its dissolve")
			return


static func _checks(g: Game, hud: Hud, rig: ShotRig, errors: Array[String]) -> void:
	var tree := g.get_tree()
	var beat := Cutscene.FRAME_DISSOLVE + Cutscene.FRAME_HOLD * 2.0
	# Each case starts fresh; no section relies on an earlier case's art or clock.
	# [clock, plates on screen at that moment]
	var samples := {"early": [0.1, 1],
		"mid_dissolve": [beat + Cutscene.FRAME_DISSOLVE * 0.6, 2],
		"long_hold": [beat * 2.0 + Cutscene.FRAME_DISSOLVE + Cutscene.FRAME_HOLD + 12.0, 1]}
	for label in samples:
		var scene := _mount(g, hud)
		scene.cue("crown")
		_step(scene, samples[label][0])
		var shown := _on_screen(scene)
		if shown.size() != samples[label][1]:
			errors.append("%s: fixture expected %d visible plates, found %d" % [label, samples[label][1], shown.size()])
			scene.free()
			continue
		var dominant: TextureRect = null
		var dominant_weight := 0.0
		for entry: Array in shown:
			if entry[3] > dominant_weight:
				dominant = entry[0]
				dominant_weight = entry[3]
		await _frames(tree, 2)
		_shot(rig, "plate_%s_before" % label)
		scene.cue("road")
		scene._sequence_tween.pause()
		_check_frozen(scene, shown, label + ": advance", errors)
		var incoming: TextureRect = scene.art_stack.get_child(shown.size())
		if not _covers(scene, incoming):
			errors.append(label + ": next cue's first plate exposed an edge")
		# Early/mid poses sit inside the start envelope, so no clamp applies:
		# the next painting must dissolve in exact register with what is shown.
		if label != "long_hold" and _center(incoming).distance_to(_center(dominant)) > REGISTER_TOLERANCE:
			errors.append(label + ": next cue's plate dissolved in out of register")
		# Repeated input in the same tick must not select a queued discarded plate.
		scene.cue("sickbed")
		scene._sequence_tween.pause()
		_check_frozen(scene, shown, label + ": same-tick advance", errors)
		await _frames(tree, 2)
		_check_frozen(scene, shown, label + ": next rendered frame", errors)
		_check_bars(scene, errors)
		_shot(rig, "plate_%s_after" % label)
		scene.free()

	# In-sequence dissolves start in register (the old alternating recipe's end
	# pose == next start), so a scene two paintings share never doubles up.
	for cue_id in ["crown", "road", "camp", "sickbed", "homestead", "hearing", "tome", "shatter"]:
		var scene := _mount(g, hud)
		scene.cue(cue_id)
		var plates := scene.art_stack.get_children()
		if plates.size() < 2:
			errors.append(cue_id + ": expected a multi-plate sequence")
		for k in range(1, plates.size()):
			_step(scene, beat) # plate k starts to dissolve k beats in

			var under: TextureRect = plates[k - 1]
			var over: TextureRect = plates[k]
			if over.modulate.a > 0.05 or under.modulate.a < 1.0:
				errors.append("%s: dissolve %d clock drifted" % [cue_id, k])
			elif _center(under).distance_to(_center(over)) > REGISTER_TOLERANCE:
				errors.append("%s: plate %d dissolves in %.1fpx out of register" % [
					cue_id, k, _center(under).distance_to(_center(over))])
		scene.free()

	# Directed plates, each continuing from the previous plate's live pose,
	# never expose an edge (start, main move, reading drift, settled).
	var scene := _mount(g, hud)
	for plate in Cutscene.PLATE_MOTION:
		scene._play_sequence([plate])
		var frame: TextureRect = scene.art_stack.get_children().back()
		for seconds in [0.0, 1.0, 2.0, 12.0, 30.0]:
			_step(scene, seconds)
			if not _covers(scene, frame):
				errors.append(plate + ": directed camera exposed an edge")
	scene.free()

	# An unlisted plate keeps the old center pivot and horizontal recipe.
	scene = _mount(g, hud)
	scene.cue("shatter")
	var default_frame: TextureRect = scene.art_stack.get_child(0)
	var default_next: TextureRect = scene.art_stack.get_child(1)
	if default_frame.pivot_offset != default_frame.size / 2.0 or default_frame.position != Vector2(-17, -6) \
			or default_next.pivot_offset != default_next.size / 2.0 or default_next.position != Vector2(-3, -6):
		errors.append("unlisted plates lost their original framing defaults")
	_step(scene, Cutscene.FRAME_DISSOLVE + Cutscene.FRAME_HOLD)
	if not default_frame.scale.is_equal_approx(Cutscene.CAMERA_END_SCALE) \
			or not default_frame.position.is_equal_approx(Vector2(-3, -6)):
		errors.append("unlisted plate changed its initial timing/end pose")
	scene.free()

	# A closer reads three one-plate unlisted cues after long holds: each starts
	# in register with the drifted plate before it and keeps travelling.
	scene = _mount(g, hud)
	for cue_id in ["ch1_finish_warrior", "ch1_fall", "ch1_reflect_warrior"]:
		var before := _on_screen(scene)
		scene.cue(cue_id)
		var frame: TextureRect = scene.art_stack.get_children().back()
		var start := frame.position
		if not before.is_empty() and _center(frame).distance_to(_center(before.back()[0])) > REGISTER_TOLERANCE:
			errors.append(cue_id + ": unlisted plate started out of register across cues")
		_step(scene, 40.0)
		if not _covers(scene, frame) or frame.position.distance_to(start) < Cutscene.CAMERA_TRACK_X:
			errors.append(cue_id + ": unlisted plate stalled or exposed an edge across cues")
	scene.free()

	scene = _mount(g, hud)
	# Last available painting drifts even if a later optional painting is absent.
	scene._frame_cache["qa_missing"] = null
	scene._play_sequence(["opening_warrior_2", "qa_missing"])
	_step(scene, Cutscene.FRAME_DISSOLVE + Cutscene.FRAME_HOLD)
	var final_frame: TextureRect = scene.art_stack.get_child(0)
	var initial_hold_pose := final_frame.get_transform()
	_step(scene, Balance.STORY_READING_DRIFT_SECONDS / 2.0)
	if final_frame.get_transform().is_equal_approx(initial_hold_pose) \
			or final_frame.scale.x >= Balance.STORY_READING_END_SCALE.x:
		errors.append("reading hold stopped early or reached its endpoint too soon")
	_step(scene, Balance.STORY_READING_DRIFT_SECONDS)
	var end_pose := final_frame.get_transform()
	_step(scene, 100.0)
	if not final_frame.get_transform().is_equal_approx(end_pose) \
			or not final_frame.scale.is_equal_approx(Balance.STORY_READING_END_SCALE):
		errors.append("reading drift did not settle at its bounded endpoint")
	# Use the actual SKIP button and the guarded finish callback; a duplicate
	# finish must neither replace the callback nor release the input gate early.
	var completed := [0]
	hud.dialogue([["Narrator", "First page."], ["Narrator", "Final page."]],
		func() -> void: scene.finish(func() -> void: completed[0] += 1))
	var prior := g.get_tree().get_processed_tweens()
	hud.dlg_skip_btn.pressed.emit()
	scene.finish(func() -> void: completed[0] += 100)
	if hud.dialogue_active or not scene.finishing() or not hud.cinematic_finishing() or completed[0] != 0:
		errors.append("SKIP bypassed or failed to start the guarded finish")
	for tween: Tween in g.get_tree().get_processed_tweens():
		if tween not in prior:
			tween.custom_step(1.0)
	if completed[0] != 1 or not scene.is_queued_for_deletion():
		errors.append("finish did not hand off exactly once")
	scene.free()
	if hud._cinematic_mode or hud.cinematic_finishing():
		errors.append("finish left cinematic input ownership behind")


static func _check_bars(scene: Cutscene, errors: Array[String]) -> void:
	var visible := scene.get_viewport().get_visible_rect()
	var art := scene.art_stack.get_global_rect()
	var motes := scene.ash.get_parent() as Control
	if visible.size != Vector2(1600, 720) or art != Rect2(160, 0, 1280, 720) \
			or not scene.art_stack.clip_contents or not motes.clip_contents \
			or motes.get_global_rect() != art or not scene.get_global_rect().is_equal_approx(visible):
		errors.append("advance changed the centered widescreen art/bars/motes")
