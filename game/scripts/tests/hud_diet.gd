extends RefCounted
## Used by the quick HUD tier and the native dossier bundle. All assertions
## use controlled state; the wrapper restores even when a check fails.
const Bodies := preload("res://scripts/ui/hud_clearance.gd")
const FAKE_BODY := Vector2(40, 88) # about one hero body at the default zoom


static func snapshot(g: Game) -> Dictionary:
	var h := g.hud
	var d: Node = h.diet
	var saved := {"alive": g.zone_alive.duplicate(true), "room": g.cur_room,
		"playing": g.play_started, "state": g.state, "pvp": g.pvp_active, "pvp_node": g.pvp,
		"barrier": g.barrier_active, "clearance_setting": g.settings.get("hud_clearance", true),
		"paused": g.get_tree().paused, "touch": h._touch_mode, "root": g.menus.root,
		"lines": h._log_lines, "visible": h.visible, "way_visible": h.wayfinder.visible,
		"shown": d.menu_shown, "row_alpha": d.menu_row.modulate.a,
		"menu_tween": d.menu_tween, "panel_tweens": d.panel_tweens.duplicate(),
		"covered": d.covered.duplicate(), "controls": [], "motions": []}
	if g.has_local_player(): saved["hero_position"] = g.local_player.global_position
	for control in d.buttons + d.panels:
		saved.controls.append([control, control.modulate, control.visible, control.mouse_filter, control.get_global_rect()])
	for motion in [d.menu_tween] + d.panel_tweens:
		if motion != null and motion.is_valid():
			saved.motions.append([motion, motion.is_running()])
			motion.pause()
	d.menu_tween = null
	d.panel_tweens.assign([null, null])
	h._log_lines = []
	return saved


static func restore(g: Game, saved: Dictionary) -> void:
	var h := g.hud
	var d: Node = h.diet
	for row in h._log_lines:
		var motion: Tween = row.get_meta("tween")
		if motion != null and motion.is_valid(): motion.kill()
		row.free()
	h._log_lines = saved.lines
	h._layout_log()
	for motion in [d.menu_tween] + d.panel_tweens:
		if motion != null and motion.is_valid(): motion.kill()
	d.menu_tween = saved.menu_tween
	d.panel_tweens.assign(saved.panel_tweens)
	d.covered.assign(saved.covered)
	d.menu_shown = saved.shown
	d.menu_row.modulate.a = saved.row_alpha
	for row in saved.controls:
		row[0].modulate = row[1]
		row[0].visible = row[2]
		row[0].mouse_filter = row[3]
	if saved.has("hero_position") and g.has_local_player(): g.local_player.global_position = saved.hero_position
	g.zone_alive = saved.alive
	g.cur_room = saved.room
	g.play_started = saved.playing
	g.state = saved.state
	g.pvp_active = saved.pvp
	g.pvp = saved.pvp_node
	g.barrier_active = saved.barrier
	g.settings["hud_clearance"] = saved.clearance_setting
	g.menus.root = saved.root
	h._touch_mode = saved.touch
	h.visible = saved.visible
	h.wayfinder.visible = saved.way_visible
	g.get_tree().paused = saved.paused
	for row in saved.motions:
		if row[1] and row[0].is_valid(): row[0].play()


static func settle(d: Node) -> void:
	for motion in [d.menu_tween] + d.panel_tweens:
		if motion != null and motion.is_valid(): motion.custom_step(1.0)


static func suite(g: Game) -> String:
	var saved := snapshot(g)
	var error := checks(g)
	for row in saved.controls:
		if row[0].get_global_rect() != row[4] and error == "": error = "HUD diet changed an authored rectangle"
	restore(g, saved)
	if error == "": print("ok: HUD diet dedup x2/x3 + currency totals, combat/hover/pause menu/dialogue pause/touch/duel, side fade by body/hysteresis both edges/input/geometry, live gate + HUD visibility off")
	return error


static func checks(g: Game) -> String:
	var h := g.hud
	var d: Node = h.diet
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.pvp_active = false
	g.barrier_active = true # the room's fight seal; Game refreshes it each frame
	g.menus.root = null
	g.get_tree().paused = false
	h._touch_mode = false
	h.visible = true
	h.wayfinder.visible = true
	d.menu_shown = true
	d.menu_row.modulate.a = 1.0
	d.covered.assign([false, false])
	for panel in d.panels: panel.modulate.a = 1.0
	var error := menu_checks(g)
	if error == "": error = panel_checks(g)
	if error == "": error = live_checks(g)
	if error == "": error = log_checks(h)
	return error


static func menu_checks(g: Game) -> String:
	var h := g.hud
	var d: Node = h.diet
	var away := Vector2(-1000, -1000)
	d.update_menu(away)
	settle(d)
	if not is_equal_approx(d.menu_row.modulate.a, Balance.HUD_MENU_HIDDEN_ALPHA): return "combat menu row did not hide"
	for button in d.buttons:
		if button.mouse_filter != Control.MOUSE_FILTER_IGNORE: return "hidden menu intercepted mouse"
	d.update_menu(h.avatar_root.get_global_rect().get_center())
	settle(d)
	if not is_equal_approx(d.menu_row.modulate.a, 1.0): return "portrait hover did not reveal menu"
	d.update_menu(h.inv_btn.get_global_rect().get_center())
	settle(d)
	if not d.menu_shown: return "moving to a shortcut dismissed the row"
	d.update_menu(away)
	settle(d)
	# A bare tree pause is a solo dialogue or choice beat. A session never
	# pauses for one, and the shortcuts refuse input under either overlay.
	g.get_tree().paused = true
	d.update_menu(away)
	settle(d)
	var dialogue_hidden: bool = is_equal_approx(d.menu_row.modulate.a, Balance.HUD_MENU_HIDDEN_ALPHA)
	g.get_tree().paused = false
	if not dialogue_hidden: return "solo dialogue pause revealed shortcuts that refuse input"
	# The pause menu: solo pauses the tree, a session keeps it running.
	for paused in [true, false]:
		d.update_menu(away)
		settle(d)
		var overlay := Control.new()
		g.menus.root = overlay
		g.get_tree().paused = paused
		d.update_menu(away)
		settle(d)
		var overlay_ok: bool = is_equal_approx(d.menu_row.modulate.a, 1.0)
		g.get_tree().paused = false
		g.menus.root = null
		overlay.free()
		if not overlay_ok: return "menu overlay did not reveal shortcuts (tree paused=%s)" % paused
	for menu_open in [false, true]:
		h._touch_mode = false
		d.update_menu(away)
		settle(d)
		h._touch_mode = true
		var touch_overlay := Control.new()
		if menu_open: g.menus.root = touch_overlay
		d.update_menu(away)
		settle(d)
		var touch_ok: bool = is_equal_approx(d.menu_row.modulate.a, 1.0)
		for button in d.buttons: touch_ok = touch_ok and button.mouse_filter == Control.MOUSE_FILTER_STOP
		g.menus.root = null
		touch_overlay.free()
		if not touch_ok: return "touch menu surface changed with unpaused overlay=%s" % menu_open
	h._touch_mode = false
	d.update_menu(away)
	settle(d)
	g.barrier_active = false
	d.update_menu(away)
	settle(d)
	if not is_equal_approx(d.menu_row.modulate.a, 1.0): return "out-of-combat menu did not restore"
	# A live duel round is combat in an unsealed arena room; its warmup is not.
	var old_pvp: Node = g.pvp
	var duel := preload("res://scripts/pvp.gd").new()
	duel.state = "fight"
	g.pvp = duel
	g.pvp_active = true
	d.update_menu(away)
	settle(d)
	var duel_hidden: bool = is_equal_approx(d.menu_row.modulate.a, Balance.HUD_MENU_HIDDEN_ALPHA)
	duel.state = "warmup"
	d.update_menu(away)
	settle(d)
	var warmup_shown: bool = is_equal_approx(d.menu_row.modulate.a, 1.0)
	g.pvp_active = false
	g.pvp = old_pvp
	duel.free()
	if not duel_hidden: return "live duel round did not hide the menu row"
	if not warmup_shown: return "duel warmup kept the menu row hidden"
	return ""


static func panel_checks(g: Game) -> String:
	var d: Node = g.hud.diet
	var release := Balance.HUD_SIDE_RELEASE_PX
	for panel in d.panels:
		panel.show()
		var rect: Rect2 = panel.get_global_rect()
		var filter: int = panel.mouse_filter
		var mid_y := rect.get_center().y - FAKE_BODY.y * 0.5
		# Entry needs the authored rect: a body only inside the release band stays clear.
		var band := Rect2(Vector2(rect.position.x - release * 0.5 - FAKE_BODY.x, mid_y), FAKE_BODY)
		d.update_panels(band, true)
		settle(d)
		if not is_equal_approx(panel.modulate.a, 1.0): return "side panel faded before the body reached it"
		# The reported miss: the origin (near the boots) sits below the bottom
		# edge while the head and torso are under the panel.
		var torso := Rect2(Vector2(rect.get_center().x - FAKE_BODY.x * 0.5, rect.end.y - FAKE_BODY.y * 0.6), FAKE_BODY)
		d.update_panels(torso, true)
		settle(d)
		if not is_equal_approx(panel.modulate.a, Balance.HUD_SIDE_COVER_ALPHA): return "side panel kept covering the hero's torso"
		d.update_panels(band, true)
		settle(d)
		if not is_equal_approx(panel.modulate.a, Balance.HUD_SIDE_COVER_ALPHA): return "panel flickered inside release margin"
		var clear := Rect2(Vector2(rect.position.x - release - 1.0 - FAKE_BODY.x, mid_y), FAKE_BODY)
		d.update_panels(clear, true)
		settle(d)
		if not is_equal_approx(panel.modulate.a, 1.0): return "panel did not restore outside release margin"
		d.update_panels(torso, true)
		d.update_panels(torso, false)
		settle(d)
		if not is_equal_approx(panel.modulate.a, 1.0): return "overlay retained faded side panel"
		if panel.mouse_filter != filter or panel.get_global_rect() != rect: return "side fade changed geometry/input"
	return ""


## The real per-frame pass: shared HUD visibility gate, hero body proxy, overlays.
static func live_checks(g: Game) -> String:
	var h := g.hud
	var d: Node = h.diet
	if not g.has_local_player(): return "HUD diet live check needs a local hero"
	var panel: Control = h.wayfinder.quest_root
	panel.show()
	g.settings["hud_clearance"] = true
	if not h.clearance.enabled(): return "HUD diet live check: HUD visibility gate closed for a playing hero"
	var hero := g.local_player
	hero.global_position = hero.get_canvas_transform().affine_inverse() * panel.get_global_rect().get_center()
	d._process(0.0)
	settle(d)
	if not is_equal_approx(panel.modulate.a, Balance.HUD_SIDE_COVER_ALPHA): return "live pass did not fade the panel over the hero"
	var overlay := Control.new()
	g.menus.root = overlay
	d._process(0.0)
	settle(d)
	var overlay_clear: bool = is_equal_approx(panel.modulate.a, 1.0)
	g.menus.root = null
	overlay.free()
	if not overlay_clear: return "live pass kept the panel faded under a menu"
	d._process(0.0)
	settle(d)
	if not is_equal_approx(panel.modulate.a, Balance.HUD_SIDE_COVER_ALPHA): return "live pass did not fade again after the menu closed"
	g.settings["hud_clearance"] = false
	d._process(0.0)
	settle(d)
	if not is_equal_approx(panel.modulate.a, 1.0): return "panel faded with HUD visibility turned off"
	return ""


static func log_checks(h: Hud) -> String:
	h.log_event("THE BLIGHT BREAKS", Color.WHITE)
	var first: Control = h._log_lines[0]
	h.log_event("THE BLIGHT BREAKS", Color.WHITE)
	if h._log_lines.size() != 1 or first.get_meta("label").text != "THE BLIGHT BREAKS x2": return "log did not collapse x2 in place"
	h.log_event("THE BLIGHT BREAKS", Color.WHITE)
	if h._log_lines.size() != 1 or h._log_lines[0] != first or first.get_meta("label").text != "THE BLIGHT BREAKS x3": return "log did not update x3 in place"
	# A same-frame burst merges before the new row's slide-in ever steps.
	if not is_equal_approx(first.position.x, Hud.LOG_X) or not is_equal_approx(first.modulate.a, 1.0):
		return "collapsed log row stayed in its slide-in start"
	var fade: Tween = first.get_meta("tween")
	if fade == null or not fade.is_valid() or not fade.is_running(): return "collapsed log row lost its fade"
	h.log_event("Another event", Color.WHITE)
	h.log_event("THE BLIGHT BREAKS", Color.WHITE)
	if h._log_lines.size() != 3 or h._log_lines[-1].get_meta("label").text != "THE BLIGHT BREAKS": return "log merged nonconsecutive events"
	# Currency streams keep their running total, equal amounts included.
	h.log_event("+12 XP", Color.WHITE)
	h.log_event("+12 XP", Color.WHITE)
	if h._log_lines[-1].get_meta("label").text != "+24 XP": return "identical currency lines did not keep their total"
	h.log_event("+6 XP", Color.WHITE)
	if h._log_lines[-1].get_meta("label").text != "+30 XP": return "mixed currency total regressed"
	return ""


static func run(rig: Node) -> String:
	var g: Game = rig.game
	var h := g.hud
	var d: Node = h.diet
	var error := suite(g)
	if error != "": return error
	var saved := snapshot(g)
	var position := g.local_player.global_position
	var texts: Array[String] = [h.wayfinder.quest_title.text, h.wayfinder.quest_objective.text, h.wayfinder.quest_location.text]
	var processing := [d.is_processing(), h.wayfinder.is_processing()]
	var old_lines: Array = []
	for row in saved.lines:
		var motion: Tween = row.get_meta("tween")
		old_lines.append([row, row.visible, motion.is_running()])
		motion.pause()
		row.hide()
	d.set_process(false)
	h.wayfinder.set_process(false)
	g.zone_alive[g.cur_room] = 1
	g.barrier_active = true
	h._touch_mode = false
	h.wayfinder.show()
	h.wayfinder.quest_root.show()
	# The wayfinder's tracked-quest panel. The escort's own ONE MORE MILE card
	# is an EncounterPanel that already yields over bodies (encounter_status.gd).
	h.wayfinder.quest_title.text = "◆  Tracked quest"
	h.wayfinder.quest_objective.text = "Follow the road to the next refuge."
	h.wayfinder.quest_location.text = "Wayfinder tracked-quest fixture"
	for i in 3: h.log_event("THE BLIGHT BREAKS", Color.WHITE)
	settle_log(h)
	var away := Vector2(-1000, -1000)
	g.get_tree().paused = false
	d.update_menu(away)
	settle(d)
	g.get_tree().paused = true # freeze the posed world, not the visibility signal
	await rig._capture("diet_01_combat", "Controlled hot-room signal; hidden shortcuts and deduplicated x3 log", false)
	rig._check("diet/combat_alpha", is_equal_approx(d.menu_row.modulate.a, Balance.HUD_MENU_HIDDEN_ALPHA))
	g.get_tree().paused = false
	d.update_menu(h.avatar_root.get_global_rect().get_center())
	settle(d)
	g.get_tree().paused = true
	await rig._capture("diet_02_hover", "Same hot-room fixture with pointer inside portrait block", false)
	rig._check("diet/hover_alpha", is_equal_approx(d.menu_row.modulate.a, 1.0))
	g.get_tree().paused = false
	d.update_menu(away)
	g.get_tree().paused = true
	var panel: Control = h.wayfinder.quest_root
	var rect := panel.get_global_rect()
	# The reported miss: origin below the bottom edge, head and torso under it.
	var origin := Vector2(rect.get_center().x, rect.end.y + Balance.HUD_SIDE_RELEASE_PX)
	g.local_player.global_position = g.local_player.get_canvas_transform().affine_inverse() * origin
	var body := Bodies.body_rect(g.local_player)
	d.update_panels(body, true)
	settle(d)
	await rig._capture("diet_03_objective_overlap", "Hero origin below the tracked-quest panel, torso under it; panel alpha yields, hit rectangle retained", false)
	rig._check("diet/objective_alpha", is_equal_approx(panel.modulate.a, Balance.HUD_SIDE_COVER_ALPHA))
	var hero_origin := g.local_player.get_global_transform_with_canvas().origin
	rig._check("diet/torso_under_objective", rect.intersects(body) and not rect.has_point(hero_origin))
	# Dispatch through the existing keyboard/pad handlers while alpha is zero.
	# This exercises their real menu gates without requiring physical hardware.
	var talk_cd := g.talk_cd
	var pad_state := [g.gamepad.active, g.gamepad.focused, g.gamepad.rearm]
	g.get_tree().paused = false
	g.talk_cd = 0.0
	rig._check("diet/keyboard_hidden_precondition", is_equal_approx(d.menu_row.modulate.a, Balance.HUD_MENU_HIDDEN_ALPHA))
	var opened := g._menu_shortcut_event(int(g.binds.inventory))
	rig._check("diet/keyboard_inventory", opened and g.menus.is_open())
	g.menus.close()
	g.gamepad.active = true
	g.gamepad.focused = true
	g.gamepad.rearm = false
	g.gamepad._button(JOY_BUTTON_DPAD_LEFT, true)
	rig._check("diet/pad_inventory", g.menus.is_open())
	g.menus.close()
	g.gamepad.active = pad_state[0]
	g.gamepad.focused = pad_state[1]
	g.gamepad.rearm = pad_state[2]
	g.talk_cd = talk_cd
	g.local_player.global_position = position
	h.wayfinder.quest_title.text = texts[0]
	h.wayfinder.quest_objective.text = texts[1]
	h.wayfinder.quest_location.text = texts[2]
	restore(g, saved)
	d.set_process(processing[0])
	h.wayfinder.set_process(processing[1])
	for row in old_lines:
		row[0].visible = row[1]
		if row[2]: row[0].get_meta("tween").play()
	if rig.failures > 0: return "HUD diet native checks failed"
	print("HUD DIET PASS: quick-tier module, keyboard/pad dispatch and three native states")
	return ""


static func settle_log(h: Hud) -> void:
	for row in h._log_lines:
		var motion: Tween = row.get_meta("tween")
		motion.custom_step(0.3)
