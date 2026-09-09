extends ShotRig
## Isolated UI fixture; actual Q/touch input spends the two chapter-three slots.
## Run separately: shot.bat potion_hud --timeout=240 [--touch]
## Stock/HP/room-plan setup is synthetic. Drinking, HUD processing and captures are real.
var checks: Array[Dictionary] = []
var views: Array[Dictionary] = []
var failures := 0
var touch_run := false
var mana_id := ""


func _ready() -> void:
	touch_run = flag("touch")
	# Keep separate mode artifacts even when the runner reuses its isolated HOME.
	shot_dir = shot_dir.path_join("touch" if touch_run else "desktop")
	await boot("warrior", "ch3", false)
	# Direct class selection can skip the name-confirmation completion seam.
	game.play_started = true
	game.menus.close()
	game.state = Game.ST_PLAYING
	game.hud.visible = true
	game.request_pause(false)
	game.settings["touch_controls"] = touch_run
	game.settings["touch_layout"] = {}
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.dev_god = false
	await skip_dialogue()
	await frames(6)
	await _wait_for_reveal("entry_reveal_settled")
	var p: Player = game.local_player
	_check("isolated_live_boot", game.no_saves and p != null and not get_tree().paused,
		{"no_saves": game.no_saves, "paused": get_tree().paused, "chapter": game.chapter_id})
	if p == null:
		_write_report()
		finish(1)
		return
	_check("safe_real_room", String(game.zones[game.cur_room].get("type", "")) == "safe",
		{"room": game.zones[game.cur_room].get("name", ""), "type": game.zones[game.cur_room].get("type", "")})
	_check("two_real_room_slots", p.potion_slot_cap() == 2)
	_check("default_q_binding", int(game.binds["potion"]) == KEY_Q)
	var default_tex: Texture2D = Art.tex("potion")
	_check("painted_default_128", default_tex != null and default_tex.get_size() == Vector2(128, 128))
	_check("shared_apprentice_cache", default_tex == Art.consumable_icon({"sprite": "consumables/apprentices_health_potion"}))
	_check("requested_control_mode", game.touch_mode == touch_run)
	if touch_run:
		_check("touch_controls_live", game._touch_hud != null and game._touch_hud._enabled and game._touch_hud.visible)
	# Four real S bags allow the 123-unit layout probe without an impossible bag.
	p.bags = [Items.make_bag("S"), Items.make_bag("S"), Items.make_bag("S"), Items.make_bag("S")]
	_stock(5)
	_health_plan()
	await _capture("01_health_stocked", 5, "health", 2)
	await _drink("first_health_drink", 4, 1)
	await _capture("02_health_after_drink", 4, "health", 1)
	await _drink("second_health_drink", 3, 0)
	await _capture("03_spent_room", 3, "health", 0)
	_stock(0)
	_health_plan()
	await _capture("04_health_empty", 0, "health", 2)
	_stock(5, 2)
	p.potion_rotation = [mana_id, "health"]
	p.active_potion = mana_id
	p.reset_room_potions()
	_check("different_mana_health_stock", p.potion_count() == 5 and p.consumable_count(mana_id) == 2)
	await _capture("05_mana_selected", 2, mana_id, 2)
	_stock(123)
	_health_plan()
	_check("legal_triple_digit_capacity", p.bag_used() <= p.bag_capacity() and p.bags.size() <= Balance.MAX_BAGS,
		{"used": p.bag_used(), "capacity": p.bag_capacity(), "bags": p.bags.size()})
	await _capture("06_health_triple_digit", 123, "health", 2)
	_key(false)
	_write_report()
	print("POTION HUD: %d checks, %d failures; %s input; stock fixtures, ordinary drink path" % [checks.size(), failures, "touch" if touch_run else "Q"])
	finish(1 if failures > 0 else 0)


func _stock(health: int, mana: int = 0) -> void:
	var p: Player = game.local_player
	p.consumables.clear()
	for i in health:
		p.consumables.append(Items.make_potion("health", "instant", "E", "accord"))
	var bottle := Items.make_potion("mana", "instant", "E", "accord")
	mana_id = String(bottle.get("id", ""))
	for i in mana:
		p.consumables.append(bottle.duplicate(true))


func _health_plan() -> void:
	var p: Player = game.local_player
	p.potion_rotation.clear()
	p.active_potion = "health"
	p.reset_room_potions()


func _key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(down: bool) -> void:
	if game._touch_hud == null:
		return
	var panel: Panel = game._touch_hud._btns["potion"]["panel"]
	var event := InputEventScreenTouch.new()
	event.index = 41
	event.position = panel.get_global_rect().get_center()
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drink(label: String, expected_stock: int, expected_budget: int) -> void:
	step(label)
	var p: Player = game.local_player
	# Pump real frames after readback; do not let its long frame eat a touch pulse.
	await frames(6)
	var deadline := Time.get_ticks_msec() + 3000
	while p.potion_cd > 0.0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(label + "/ready", p.potion_cd <= 0.0 and not game.input_overlay_up())
	p.hp = p.max_hp * 0.35 # missing-health fixture, no direct drink/damage call
	var before_hp := p.hp
	var before_stock := p.potion_count()
	var before_budget := p.room_potions_left()
	if touch_run:
		_touch(true)
		_touch(false) # a tap, well below the long-press explanation threshold
	else:
		_key(true)
	deadline = Time.get_ticks_msec() + 2500
	while p.potion_count() == before_stock and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_key(false)
	await frames(3)
	_check(label + "/normal_drink", p.potion_count() == expected_stock and p.room_potions_left() == expected_budget
		and before_stock - p.potion_count() == 1 and before_budget - p.room_potions_left() == 1 and p.hp > before_hp,
		{"stock_before": before_stock, "stock_after": p.potion_count(), "budget_before": before_budget,
		"budget_after": p.room_potions_left(), "hp_before": before_hp, "hp_after": p.hp, "input": "touch_tap" if touch_run else "Q"})


func _capture(label: String, expected_count: int, active: String, budget: int) -> void:
	step(label)
	await frames(5)
	await _wait_for_reveal(label + "/reveal_settled")
	await RenderingServer.frame_post_draw
	var p: Player = game.local_player
	var box: Dictionary = game.hud.slot_boxes[4]
	var desktop_num: Label = box["num"]
	var desktop_icon: TextureRect = box["icon"]
	var panel: Control = box["border"]
	var num: Label = desktop_num
	var icon: TextureRect = desktop_icon
	if touch_run and game._touch_hud != null:
		var touch_box: Dictionary = game._touch_hud._btns["potion"]
		panel = touch_box["panel"]
		num = touch_box["label"]
		icon = touch_box["icon"]
	var expected_icon: Texture2D = Art.tex("potion") if active == "health" else Art.consumable_icon({"id": active})
	var expected_label := "—" if touch_run and budget == 0 else "x%d" % expected_count
	var actual_count: int = p.potion_count() if p.active_potion == "health" else p.consumable_count(p.active_potion)
	_check(label + "/state", p.active_potion == active and actual_count == expected_count and p.room_potions_left() == budget)
	_check(label + "/carried_label", num.text == expected_label, {"actual": num.text, "expected": expected_label})
	_check(label + "/active_icon", expected_icon != null and icon.texture == expected_icon)
	_check(label + "/visible_control", panel.is_visible_in_tree() and num.is_visible_in_tree() and icon.is_visible_in_tree())
	_check(label + "/desktop_visibility", desktop_num.is_visible_in_tree() == (not touch_run) and desktop_icon.is_visible_in_tree() == (not touch_run))
	var font_size := num.get_theme_font_size("font_size")
	var font: Font = num.get_theme_font("font")
	var text_size := font.get_string_size(num.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var panel_rect := panel.get_global_rect()
	var label_rect := num.get_global_rect()
	_check(label + "/label_inside_button", panel_rect.grow(0.5).encloses(label_rect), {"button": str(panel_rect), "label": str(label_rect)})
	_check(label + "/text_fits", text_size.x <= num.size.x and text_size.y <= num.size.y,
		{"text_size": str(text_size), "label_size": str(num.size), "font_size": font_size})
	_check(label + "/corner_count", num.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		and label_rect.position.y > panel_rect.get_center().y and font_size == (16 if touch_run else 15))
	_check(label + "/linear_texture", icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	# Ability countdowns retain their central 22px presentation and real controls.
	var ability_num: Label = game.hud.slot_boxes[0]["num"]
	if touch_run and game._touch_hud != null:
		ability_num = game._touch_hud._btns["a1"]["label"]
	_check(label + "/ability_countdown_unchanged", ability_num.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and ability_num.get_theme_font_size("font_size") == 22)
	if not touch_run:
		_check(label + "/room_status", String(box["name"].text) == "Spent" if budget == 0 else String(box["name"].text).contains("▸"))
	var path := shot(label)
	views.append({"view": label, "path": path, "active": p.active_potion, "carried": actual_count,
		"health_carried": p.potion_count(), "budget": p.room_potions.duplicate(), "text": num.text,
		"button": str(panel_rect), "label": str(label_rect), "text_size": str(text_size),
		"texture_size": str(icon.texture.get_size()) if icon.texture != null else "null",
		"presentation": _reveal_state(),
		"process_frame": Engine.get_process_frames(), "mode": "touch" if touch_run else "desktop"})
	# Native-size derivative of the QA framebuffer only; never resize or alter art.
	var image := capture_image()
	var crop_rect := Rect2i(panel_rect.grow(14)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if crop_rect.has_area():
		var crop_path := ProjectSettings.globalize_path(shot_dir.path_join(label + "_button.png"))
		image.get_region(crop_rect).save_png(crop_path)
		views[-1]["native_crop"] = crop_path
	var hud_rect := panel_rect
	for slot in ["a1", "a2", "a3", "ult"]:
		if touch_run and game._touch_hud != null:
			hud_rect = hud_rect.merge((game._touch_hud._btns[slot]["panel"] as Control).get_global_rect())
		else:
			var ability: Dictionary = game.hud.slot_boxes[game.hud.SLOTS.find(slot)]
			hud_rect = hud_rect.merge((ability["border"] as Control).get_global_rect())
			hud_rect = hud_rect.merge((ability["name"] as Control).get_global_rect())
	var hud_crop := Rect2i(hud_rect.grow(14)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if hud_crop.has_area():
		var hud_path := ProjectSettings.globalize_path(shot_dir.path_join(label + "_hud.png"))
		image.get_region(hud_crop).save_png(hud_path)
		views[-1]["native_hud"] = hud_path
	_write_report()


func _reveal_state() -> Dictionary:
	var cinematic_children := 0
	for child in game.hud.get_children():
		if child is Cutscene:
			cinematic_children += 1
	return {"cinematic_children": cinematic_children, "cinematic_mode": game.hud._cinematic_mode,
		"cutscene_active": game.cutscene != null, "dialogue": game.hud.dialogue_active,
		"choices": game.hud.choices_active, "overlay_alpha": game.hud.overlay.color.a,
		"title_alpha": game.hud.title_label.modulate.a, "subtitle_alpha": game.hud.subtitle_label.modulate.a}


func _reveal_pending() -> bool:
	# run_cinematic_convo clears game.cutscene before Cutscene.finish's 0.46s
	# dissolve invokes the normal begin callback, which then starts flash_title.
	# The remaining HUD child/mode closes that gap; alpha alone can be clear
	# while the chapter title has not started yet. Never force visual state.
	if game.cutscene != null or game.hud._cinematic_mode \
			or game.hud.dialogue_active or game.hud.choices_active:
		return true
	for child in game.hud.get_children():
		if child is Cutscene:
			return true
	return game.hud.overlay.color.a > 0.001 or game.hud.title_label.modulate.a > 0.01 \
		or game.hud.subtitle_label.modulate.a > 0.01


func _wait_for_reveal(label: String) -> void:
	# Pump actual frames until the pending opener AND its title are gone. A
	# short stable run also crosses the queue_free / tween callback frame seam.
	var deadline := Time.get_ticks_msec() + 8000
	var settled_frames := 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		settled_frames = 0 if _reveal_pending() else settled_frames + 1
		if settled_frames >= 3:
			break
	_check(label, settled_frames >= 3, _reveal_state())


func _check(label: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"check": label, "passed": passed, "details": details})
	if not passed:
		failures += 1
		print("POTION HUD CHECK FAILED: ", label, " ", JSON.stringify(details))


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		print("POTION HUD REPORT WRITE FAILED: ", FileAccess.get_open_error())
		failures += 1
		return
	file.store_string(JSON.stringify({"mode": "touch" if touch_run else "desktop", "no_saves": game.no_saves,
		"fixture": "real Items and chapter-three plan; stock/HP setup; normal Q/touch health drinks",
		"renderer": RenderingServer.get_current_rendering_method(), "failures": failures, "checks": checks, "views": views}, "\t"))
	file.close()
