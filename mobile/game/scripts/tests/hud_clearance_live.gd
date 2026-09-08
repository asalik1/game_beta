extends RefCounted
const Clearance := preload("res://scripts/ui/hud_clearance.gd")


static func fit(g: Game) -> String:
	var ui: Node = g.hud.clearance
	var wanted := Balance.HUD_INFO_COVER_ALPHA if ui.covered() else 1.0
	if not is_equal_approx(g.hud.info_panel.self_modulate.a, wanted):
		return "information opacity does not match actual body coverage"
	for control in [g.hud.hp_fill, g.hud.mp_fill, g.hud.xp_fill, g.hud.hp_text,
		g.hud.mail_btn, g.hud.quest_btn, g.hud.inv_btn, g.hud.codex_btn,
		g.hud.skills_btn, g.hud.settings_btn, g.hud.party_btn]:
		if not is_equal_approx(control.self_modulate.a, 1.0):
			return "HUD clearance dimmed a vital readout or utility button"
	for slot in g.hud.party_slots:
		if not is_equal_approx(slot.hp_bg.self_modulate.a, 1.0):
			return "HUD clearance dimmed party health"
	var notice: Control = g.hud.combat_feedback.notice_panel
	for slot in g.hud.buff_slots:
		if notice.get_global_rect().intersects(slot.border.get_global_rect()):
			return "ability notice overlaps the buff row"
	return ""


static func run(r: Node, enemy: Enemy, room: int) -> String:
	var g: Game = r.game
	var saved := {"settings": g.settings.duplicate(true), "color": g.hud.stats_label.modulate,
		"berserk": g.player.berserk_time, "grit": g.player.grit_stacks, "grit_time": g.player.grit_time}
	var error := await _checks(r, enemy, room)
	g.hud._close_hud_popover()
	g.menus.close()
	g.settings = saved.settings
	g.hud.stats_label.modulate = saved.color
	g.player.berserk_time = saved.berserk
	g.player.grit_stacks = saved.grit
	g.player.grit_time = saved.grit_time
	g.refresh_touch_mode()
	g._apply_touch_mode()
	if error == "":
		print("ok: HUD body overlap/recovery, target-only/touch views, menu/popover/setting restoration, preserved vital controls and color, foreign/retired/freed target guards, and notice/buff spacing")
	return error


static func _checks(r: Node, enemy: Enemy, room: int) -> String:
	var g: Game = r.game
	var p := g.player
	p.global_position = g.room_center(room)
	enemy.global_position = g.free_spawn_pos(p.global_position + Vector2(-430, -230), p.global_position)
	p.locked_target = enemy
	await r.get_tree().create_timer(1.0, true).timeout
	var panel := g.hud.info_panel.get_global_rect()
	if panel.intersects(Clearance.body_rect(p)) or not panel.intersects(Clearance.body_rect(enemy)):
		return "target-only fixture did not place the visible enemy under the information panel"
	await r._capture("07_target_visible_through_information", enemy)
	var error := fit(g)
	if error != "":
		return error
	# Changes of unrelated presentation tint must survive the alpha effect.
	var tint := Color(0.6, 0.7, 0.8, 0.9)
	g.hud.stats_label.modulate = tint
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	await r.get_tree().create_timer(0.5, true).timeout
	await r._capture("08_touch_target_visibility", enemy)
	if not g.hud.stats_label.modulate.is_equal_approx(tint):
		return "HUD clearance clobbered an existing information color effect"
	error = fit(g)
	if error != "":
		return error
	# A different game's actor or an old world's surviving child cannot dim
	# this reader. Restore borrowed actor ownership before yielding a frame.
	var foreign := Game.new()
	enemy.game = foreign
	var foreign_covered: bool = g.hud.clearance.covered()
	enemy.game = g
	foreign.free()
	if foreign_covered:
		return "another game's actor dimmed this reader's HUD"
	var retired := Node2D.new()
	g.add_child(retired)
	enemy.reparent(retired)
	var retired_covered: bool = g.hud.clearance.covered()
	enemy.reparent(g.world)
	retired.free()
	if retired_covered:
		return "a retired world's actor dimmed the current HUD"
	g.hud._open_hud_popover("Combat Rating", "Your power from equipment, attributes and skills.")
	await r.get_tree().create_timer(0.5, true).timeout
	if g.hud.clearance.enabled() or not is_equal_approx(g.hud.info_panel.self_modulate.a, 1.0):
		return "reading a HUD popover did not restore the information"
	await r._capture("09_read_information_popover", enemy)
	g.hud._close_hud_popover()
	preload("res://scripts/ui/comfort.gd").open(g.menus)
	await r.get_tree().create_timer(0.5, true).timeout
	await r._capture("10_comfort_control", enemy)
	if not is_equal_approx(g.hud.info_panel.self_modulate.a, 1.0):
		return "paused settings retained a faded information panel"
	g.menus.close()
	g.settings["hud_clearance"] = false
	await r.get_tree().create_timer(0.5, true).timeout
	error = fit(g)
	if error != "":
		return error
	await r._capture("11_setting_disabled", enemy)
	g.settings["hud_clearance"] = true
	await r.get_tree().create_timer(0.5, true).timeout
	error = fit(g)
	if error != "":
		return error
	# Keep the old pointers live through the fade tick; no stale typed cast.
	enemy.free()
	g.hud.clearance._process(0.5)
	if not is_equal_approx(g.hud.info_panel.self_modulate.a, 1.0):
		return "a freed target kept the HUD faded"
	p.locked_target = null
	g.hud.target_bar_unit = null
	g.settings["touch_controls"] = false
	g.refresh_touch_mode()
	g._apply_touch_mode()
	p.grit_stacks = 1
	p.grit_time = 7.0
	p.berserk_time = 8.0
	g.hud.combat_feedback.ability_notice("a3", "Not enough mana")
	await r.frames(3)
	await r._capture("12_notice_and_buff_icons_clear")
	error = fit(g)
	if error != "":
		return error
	return ""
