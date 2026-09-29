extends Node
## Local presentation only. Never pauses the world or changes menu dispatch.
const Bodies := preload("res://scripts/ui/hud_clearance.gd")
var hud: Hud
var buttons: Array[Button] = []
var menu_row: Control
var panels: Array[Control] = []
var covered: Array[bool] = []
var panel_tweens: Array[Tween] = []
var menu_tween: Tween
var menu_shown := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	buttons.assign([hud.mail_btn, hud.quest_btn, hud.inv_btn, hud.codex_btn,
		hud.daily_btn, hud.skills_btn, hud.settings_btn])
	# A zero-origin alpha parent preserves every authored rectangle and lets
	# daily/quest pulses continue owning each button's individual tint.
	menu_row = Control.new()
	menu_row.name = "MenuRowFade"
	menu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(menu_row)
	for button in buttons: button.reparent(menu_row)
	panels.assign([hud.wayfinder.quest_root, hud.wayfinder.radar_root])
	for panel in panels:
		covered.append(false)
		panel_tweens.append(null)


func _process(_delta: float) -> void:
	update_menu(hud.info_panel.get_global_mouse_position())
	# The shared HUD visibility preference and its gates: play state, a live
	# local hero, no cinematic, overlay or popover.
	var active: bool = is_instance_valid(hud.clearance) and hud.clearance.enabled()
	var body: Rect2 = Bodies.body_rect(hud.game.local_player) if active else Rect2()
	update_panels(body, active)


func update_menu(pointer: Vector2) -> void:
	var g := hud.game
	# This rectangle includes the row: moving from the portrait to an icon
	# must not dismiss it. Geometry and the existing touch surfaces stay put.
	var block := hud.info_panel.get_global_rect().merge(hud.vitals_panel.get_global_rect())
	block = block.merge(hud.avatar_root.get_global_rect())
	# Game refreshes the room's fight seal each frame before its HUD child runs.
	var hot := g.play_started and g.state == Game.ST_PLAYING and g.barrier_active
	if g.pvp_active and is_instance_valid(g.pvp):
		hot = hot or g.pvp.combat_live()
	# Overlay state, not the tree pause: solo dialogue pauses the tree and a
	# session never does, and the pause menu is itself an open menu.
	var shown := hud._touch_mode or not hot or block.has_point(pointer) \
		or (is_instance_valid(g.menus) and g.menus.is_open())
	if shown == menu_shown:
		return
	menu_shown = shown
	if menu_tween != null and menu_tween.is_valid(): menu_tween.kill()
	menu_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	menu_tween.tween_property(menu_row, "modulate:a", 1.0 if shown else Balance.HUD_MENU_HIDDEN_ALPHA,
		Balance.HUD_MENU_FADE_SECONDS)
	for button in buttons:
		# Invisible mouse affordances must not eat a click meant for the world.
		# Keyboard/pad menus are dispatched independently by Game/Gamepad.
		button.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


## `body` is the hero's screen-space body proxy (Bodies.body_rect), not its
## origin: the origin sits near the boots, so a point test let a panel cover
## the head and torso. Entry needs the authored rect; release needs the margin.
func update_panels(body: Rect2, active: bool) -> void:
	for i in panels.size():
		var panel := panels[i]
		var rect := panel.get_global_rect()
		if covered[i]: rect = rect.grow(Balance.HUD_SIDE_RELEASE_PX)
		var cover := active and panel.is_visible_in_tree() and body.has_area() and rect.intersects(body)
		if cover == covered[i]: continue
		covered[i] = cover
		if panel_tweens[i] != null and panel_tweens[i].is_valid(): panel_tweens[i].kill()
		panel_tweens[i] = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		panel_tweens[i].tween_property(panel, "modulate:a", Balance.HUD_SIDE_COVER_ALPHA if cover else 1.0,
			Balance.HUD_SIDE_FADE_SECONDS)
