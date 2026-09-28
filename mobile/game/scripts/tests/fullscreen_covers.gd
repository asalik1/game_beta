extends RefCounted
## Systems/quick regression: expand must not expose gameplay beyond a cover.
## A disposable HUD controls lazy FX preconditions without disturbing live tweens.

const BOSS_NAME := "Covers Probe the Ashen"
const BOSS_ART := "splash_ashpriest"
const PROBE_TEXT := "Dialogue layout probe."
const PROBE_OPTIONS := ["Take the left road.", "Take the right road."]


static func suite(game: Game) -> String:
	var tree := game.get_tree()
	var window := tree.root
	var kept_size := window.size
	var kept_aspect := window.content_scale_aspect
	var kept_mode := game.process_mode
	var kept_hud := game.hud
	# The choice probe goes through the real dialogue_choice, which archives
	# its line in the journal and pauses solo; both are put back below.
	var kept_convo_log: Dictionary = game.convo_log.duplicate(true)
	var kept_convo_order: Array = game.convo_log_order.duplicate()
	var kept_paused := tree.paused
	game.process_mode = Node.PROCESS_MODE_DISABLED
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.size = Vector2i(1560, 720)
	await tree.process_frame
	var hud := Hud.new()
	hud.game = game
	game.hud = hud
	game.add_child(hud)
	hud.set_process(false)
	hud.text_label.text = PROBE_TEXT
	hud._fit_dialogue_box()
	hud.danger_ramp(1.0)
	hud.flash_screen(Color.WHITE)
	var cinematic := Cutscene.new(game)
	hud.add_child(cinematic)
	hud.move_child(cinematic, hud.dialogue_box.get_index())
	# A real plate is larger than its authored display frame. Texture minimum
	# sizing must not silently enlarge it beyond the centered art stack.
	var plate := cinematic._make_frame(cinematic._frame_texture("chapters/opening_ch2_0"))
	cinematic.art_stack.add_child(plate)
	var errors: Array[String] = []
	_check(hud, cinematic, Vector2(1560, 720), errors)
	# Resize the SAME mounted controls, including returning to the desktop size.
	for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1600, 720),
			Vector2i(1280, 960), Vector2i(2400, 1080), Vector2i(1280, 720)]:
		window.size = dimensions
		await tree.process_frame
		var expected := Vector2(1600, 720) if dimensions == Vector2i(2400, 1080) else Vector2(dimensions)
		_check(hud, cinematic, expected, errors)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.size = Vector2i(2400, 1080)
	await tree.process_frame
	_check(hud, cinematic, Vector2(1280, 720), errors)
	hud.cancel_conversation()
	tree.paused = kept_paused
	# Leaving the opener ends cinematic mode, so the boss entrance plate may mount.
	cinematic.free()
	# The boss plate marks its art as seen; put the gallery memory back after.
	var had_seen := game.splashes_seen.has(BOSS_ART)
	var kept_meta: Dictionary = game._meta.duplicate(true)
	var kept_meta_loaded := game._meta_loaded
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(2400, 1080), Vector2i(1280, 960), Vector2i(1280, 720)]:
		window.size = dimensions
		await tree.process_frame
		var expected := Vector2(1600, 720) if dimensions == Vector2i(2400, 1080) else Vector2(dimensions)
		_check_boss_splash(hud, expected, errors)
	if not had_seen:
		game.splashes_seen.erase(BOSS_ART)
	game._meta = kept_meta
	game._meta_loaded = kept_meta_loaded
	# No assertion exits before restoring the borrowed window and game state.
	hud.free()
	game.hud = kept_hud
	game.convo_log = kept_convo_log
	game.convo_log_order = kept_convo_order
	tree.paused = kept_paused
	window.content_scale_aspect = kept_aspect
	window.size = kept_size
	await tree.process_frame
	game.process_mode = kept_mode
	return "full-screen covers: " + "; ".join(errors) if not errors.is_empty() else ""


static func _check(hud: Hud, cinematic: Cutscene, expected: Vector2, errors: Array[String]) -> void:
	var visible := hud.get_viewport().get_visible_rect()
	if not visible.size.is_equal_approx(expected):
		errors.append("fixture visible rect %s, expected %s" % [visible.size, expected])
		return
	_check_dialogue(hud, visible, errors)
	_check_log(hud, visible, "when opened", errors)
	var covers := {
		"death/fade overlay": hud.overlay,
		"splash scrim": hud.splash_scrim,
		"log click-eater": hud.log_panel.get_child(0),
		"danger rim": hud.danger_rect,
		"impact flash": hud.flash_rect,
		"cutscene root": cinematic,
		"cutscene backdrop": cinematic.get_child(0),
		"cutscene wash": cinematic.get_child(3),
		"cutscene vignette": cinematic.get_child(4),
		"cutscene fade": cinematic.fade_rect,
	}
	for label in covers:
		var cover: Control = covers[label]
		# Exact bounds also catch an oversized danger texture whose rim ends up offscreen.
		if not cover.get_global_rect().is_equal_approx(visible):
			errors.append("%s does not match the viewport at %s" % [label, expected])
	if hud.dialogue_box.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			or hud.log_panel.get_child(0).mouse_filter != Control.MOUSE_FILTER_STOP:
		errors.append("cover layout changed dialogue/log input handling")
	var art := cinematic.art_stack.get_global_rect()
	if art.size != Vector2(1280, 720) or cinematic.art_stack.scale != Vector2.ONE:
		errors.append("authored art was resized at %s" % expected)
	if art.get_center().distance_to(visible.get_center()) > 1.0:
		errors.append("authored art is not centered at %s" % expected)
	var plate: TextureRect = cinematic.art_stack.get_child(0)
	if plate.size != Vector2(1300, 732) or plate.pivot_offset != plate.size / 2.0:
		errors.append("source texture minimum overrode the authored plate frame")
	# The camera push overscans the plate; only the screen edge clipped it at 16:9.
	if not cinematic.art_stack.clip_contents:
		errors.append("plate overscan can spill into the dark bars at %s" % expected)
	var motes := cinematic.ash.get_parent() as Control
	if motes == null or motes == cinematic or not motes.clip_contents \
			or not motes.get_global_rect().is_equal_approx(art):
		errors.append("ash motes are not framed with the authored art at %s" % expected)
	# Square speaker art stays width-fit and top-aligned across the whole screen.
	var side := maxf(visible.size.x, visible.size.y)
	if not hud.splash_rect.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO, Vector2(side, side))):
		errors.append("speaker splash leaves part of the screen uncovered at %s" % expected)


## Preserve the authored desktop rectangles and translate the whole reader
## together on expand, including after repeated resizes back to desktop.
## Each size also raises a real decision (the ch2 opener ends on one) and
## leaves it up, so the next size checks that the options followed the resize.
static func _check_dialogue(hud: Hud, visible: Rect2, errors: Array[String]) -> void:
	if hud.log_panel.visible:
		_check_log(hud, visible, "after a resize", errors)
	if hud.choices_active:
		_check_choice(hud, visible, "after a resize", errors)
		hud.cancel_conversation()
	var shift := Vector2(visible.get_center().x - 640.0, 0.0)
	var authored := {
		hud.dialogue_frame: Vector2(138, 448),
		hud.dialogue_inner: Vector2(141, 451),
		hud.speaker_label: Vector2(168, 462),
		hud.text_label: Vector2(168, 492),
		hud.dialogue_hint: Vector2(856, 618),
		hud.portrait_box: Vector2.ZERO,
	}
	for control: Control in authored:
		if not control.global_position.is_equal_approx(authored[control] + shift):
			errors.append("dialogue %s lost its authored offset at %s" % [control.name, visible.size])
	if hud.dialogue_frame.size != Vector2(1004, 200) or hud.dialogue_inner.size != Vector2(998, 194):
		errors.append("dialogue panel dimensions changed at %s" % visible.size)
	var row_origin := Vector2(1136, 442) + shift - _reader_row_size(hud)
	if not hud.dlg_ctrl_row.global_position.is_equal_approx(row_origin):
		errors.append("LOG/SKIP/AUTO lost their dialogue alignment at %s" % visible.size)
	# A filled gold rect leaks through the inner panel in HDR linear blending.
	if not _gold_border_only(hud.dialogue_frame):
		errors.append("dialogue frame fills behind its translucent inner panel or lost its gold border")
	var kept_paused := hud.get_tree().paused
	hud.dialogue_choice("Narrator", PROBE_TEXT, PROBE_OPTIONS, Callable())
	hud.get_tree().paused = kept_paused
	_check_choice(hud, visible, "when raised", errors)


## Open the actual backlog and leave it up across the next viewport resize.
## Its shade stays full-screen while all five authored controls move together.
static func _check_log(hud: Hud, visible: Rect2, when: String, errors: Array[String]) -> void:
	if not hud.log_panel.visible:
		hud.dlg_log_btn.pressed.emit()
	if not hud.log_panel.visible:
		errors.append("LOG did not open the backlog")
	var frame: Control = hud.log_panel.get_child(1)
	var inner: ColorRect = hud.log_panel.get_child(2)
	var title: Label = hud.log_panel.get_child(3)
	var close: Button = hud.log_panel.get_child(4)
	var scroll: ScrollContainer = hud.log_list.get_parent()
	var shift := Vector2(visible.get_center().x - 640.0, 0.0)
	var authored := {
		frame: Vector2(238, 96), inner: Vector2(241, 99),
		title: Vector2(262, 110), close: Vector2(956, 108), scroll: Vector2(262, 146),
	}
	for control: Control in authored:
		if not control.global_position.is_equal_approx(authored[control] + shift):
			errors.append("backlog %s lost its authored offset %s at %s" % [control.name, when, visible.size])
	if not is_equal_approx(frame.get_global_rect().get_center().x, visible.get_center().x):
		errors.append("backlog is not centered %s at %s" % [when, visible.size])
	if frame.size != Vector2(804, 470) or inner.size != Vector2(798, 464) \
			or scroll.size != Vector2(760, 404):
		errors.append("backlog dimensions changed at %s" % visible.size)
	if not _gold_border_only(frame):
		errors.append("backlog frame fills behind its translucent inner panel or lost its gold border")
	if frame.mouse_filter != Control.MOUSE_FILTER_STOP or inner.mouse_filter != Control.MOUSE_FILTER_STOP \
			or inner.color != Color(0.07, 0.06, 0.11, 0.98):
		errors.append("backlog panel changed its fill or click blocking")
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
			or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO \
			or hud.log_list.get_child_count() == 0:
		errors.append("backlog lost its scrolling content")


## The options panel stacks directly on the box: same left edge and width,
## rows and hover strips inside it, and LOG/SKIP/AUTO above it at the box's right.
static func _check_choice(hud: Hud, visible: Rect2, when: String, errors: Array[String]) -> void:
	var box := hud.dialogue_frame.get_global_rect()
	var panel := hud.choice_frame.get_global_rect()
	var inner := hud.choice_inner.get_global_rect()
	var aligned := hud.choice_panel.visible and hud.choice_count == PROBE_OPTIONS.size() \
		and is_equal_approx(panel.position.x, box.position.x) and is_equal_approx(panel.size.x, box.size.x) \
		and panel.end.y < box.position.y
	for i in hud.choice_count:
		var option: Label = hud.choice_option_labels[i]
		var hover: ColorRect = hud.choice_hover_rects[i]
		aligned = aligned and is_equal_approx(option.global_position.x, box.position.x + 30.0) \
			and is_equal_approx(hover.global_position.x, inner.position.x) \
			and is_equal_approx(hover.size.x, inner.size.x) \
			and inner.grow(0.5).encloses(option.get_global_rect())
	if not aligned:
		errors.append("choice options are not lined up with the dialogue box %s at %s" % [when, visible.size])
	var row_size := _reader_row_size(hud)
	var row_origin := Vector2(box.end.x - 6.0 - row_size.x, panel.position.y - 6.0 - row_size.y)
	if not hud.dlg_ctrl_row.global_position.is_equal_approx(row_origin):
		errors.append("LOG/SKIP/AUTO are not above the choice options %s at %s" % [when, visible.size])
	if not _gold_border_only(hud.choice_frame):
		errors.append("choice frame fills behind its translucent inner panel or lost its gold border")


static func _reader_row_size(hud: Hud) -> Vector2:
	var row_size := Vector2.ZERO
	for button: Button in [hud.dlg_log_btn, hud.dlg_skip_btn, hud.dlg_auto_btn]:
		row_size = row_size.max(button.position + button.size)
	return row_size


## The authored 3px gold outline with nothing drawn behind the inner panel.
static func _gold_border_only(frame: Control) -> bool:
	if not frame is Panel:
		return false
	var border := frame.get_theme_stylebox("panel") as StyleBoxFlat
	return border != null and not border.draw_center and border.border_color == Color(0.9, 0.8, 0.5) \
		and border.border_width_left == 3 and border.border_width_top == 3 \
		and border.border_width_right == 3 and border.border_width_bottom == 3


## The boss entrance plate covers the screen too: its art, foot shade and
## title must follow the visible screen, not the 16:9 design frame.
static func _check_boss_splash(hud: Hud, expected: Vector2, errors: Array[String]) -> void:
	var visible := hud.get_viewport().get_visible_rect()
	if not visible.size.is_equal_approx(expected):
		errors.append("fixture visible rect %s, expected %s" % [visible.size, expected])
		return
	if not Art.has_sprite(BOSS_ART):
		errors.append("boss splash fixture art %s is missing" % BOSS_ART)
		return
	hud._boss_splash_shown.erase(BOSS_NAME)
	hud._splash_cache[BOSS_NAME] = BOSS_ART
	hud._boss_splash_intro(BOSS_NAME)
	var layer := hud._boss_splash_layer
	if not is_instance_valid(layer):
		errors.append("boss splash did not mount at %s" % expected)
		return
	var art: TextureRect = layer.get_child(0)
	var foot: TextureRect = layer.get_child(2)
	var title: Label = layer.get_child(3)
	var rule: ColorRect = layer.get_child(4)
	var epithet: Label = layer.get_child(6)
	# Half a pixel of slack: an exact cover scale can round a hair under the edge.
	if not layer.get_global_rect().is_equal_approx(visible) \
			or not Rect2(art.position, art.size).grow(0.5).encloses(visible):
		errors.append("boss splash art leaves part of the screen uncovered at %s" % expected)
	if not Rect2(foot.position, foot.size).end.is_equal_approx(visible.end) \
			or not is_equal_approx(foot.size.x, visible.size.x) or foot.position.x != 0.0:
		errors.append("boss splash foot shade is not full width at the bottom at %s" % expected)
	if title.position.x != 0.0 or not is_equal_approx(title.size.x, visible.size.x) \
			or epithet.position.x != 0.0 or not is_equal_approx(epithet.size.x, visible.size.x) \
			or not is_equal_approx(rule.position.x, visible.size.x * 0.5):
		errors.append("boss splash title is not centered at %s" % expected)
	if not is_equal_approx(visible.size.y - title.position.y, 720.0 - 548.0):
		errors.append("boss splash title lost its spacing from the bottom at %s" % expected)
	layer.free()
	hud._boss_splash_layer = null
