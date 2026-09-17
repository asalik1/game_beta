extends RefCounted
## Lent legal equipment; real inventory Auto-synthesize input. No earned-loot claim.
const EXPECTED := ["C/cap", "B/cap", "A/cap"]
var r: ShotRig
var g: Game
var p: Player
var baseline := false
var report := {"checks": [], "findings": [], "failures": [], "views": [], "complete": false}
var rng := RandomNumberGenerator.new()


static func run(rig: ShotRig) -> String:
	var t := new()
	t.r = rig
	t.g = rig.game
	t.p = rig.game.local_player
	t.baseline = rig.flag("baseline")
	if not t.g.no_saves or t.g.net_online() or t.g.chapter_id != "capital" or t.g.dev_god:
		return "Gem cap fixture requires isolated no-save solo capital, without god mode"
	var original_equipment: Dictionary = t.p.equipment
	var original_gems: Array = t.p.gem_bag
	var old_equipment: Dictionary = original_equipment.duplicate(true)
	var old_gems: Array = original_gems.duplicate(true)
	var player_fields := t._stash(t.p, ["consumables", "hp", "mp", "gold", "global_position"])
	var game_fields := t._stash(t.g, ["flags", "achievements", "_meta", "_meta_loaded", "quest_key",
		"_pre_capital_chapter", "play_started", "state"])
	var old_notice: String = t.g.menus.inventory_notice
	var old_physics: bool = t.p.is_physics_processing()
	var old_dir: String = rig.shot_dir
	rig.shot_dir = old_dir.path_join("synthesis_caps")
	t.rng.seed = 17092026
	t.report["scope"] = "Controlled fresh capital visit; generic legal gear/gems lent, real mouse or ScreenTouch synthesis clicks. No earned materials, combat, travel-input, save-persistence or physical-device claim. Road uses actual chapter rebuild; cleanup restores owned character fields, not old world node identity."
	t.p.set_physics_process(false)
	var error: String = await t._exercise()
	t.g.menus.close()
	t.g.request_pause(false)
	if t.g.chapter_id != "capital":
		t.g.switch_chapter("capital", true)
		await rig.frames(3)
		await rig.skip_dialogue()
	t.p.equipment = original_equipment
	t.p.gem_bag = original_gems
	t._restore(t.g, game_fields)
	t._restore(t.p, player_fields)
	t.p.recalc()
	t.p.hp = float(player_fields.hp)
	t.p.mp = float(player_fields.mp)
	t.p._update_weapon_visual()
	t.g.menus.inventory_notice = old_notice
	t.p.set_physics_process(old_physics)
	await rig.frames(3)
	t._check("cleanup/owned_inventory", is_same(t.p.equipment, original_equipment)
		and is_same(t.p.gem_bag, original_gems) and t.p.equipment == old_equipment and t.p.gem_bag == old_gems)
	t._check("cleanup/progression", t.g.flags == game_fields.flags and t.g.achievements == game_fields.achievements
		and t.p.gold == player_fields.gold and t.p.consumables == player_fields.consumables)
	var expected: Array = EXPECTED.duplicate() if t.baseline else []
	t._check("baseline/exact", t.report.findings == expected, {"expected": expected, "actual": t.report.findings})
	if error != "": t._check("fixture", false, {"error": error})
	t.report.complete = error == ""
	t.report["baseline"] = t.baseline
	t.report["input"] = "ScreenTouch" if t.g.touch_mode else "mouse"
	var output := ProjectSettings.globalize_path(rig.shot_dir.path_join("report.json"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: return "Cannot write gem cap receipt"
	file.store_string(JSON.stringify(t.report, "\t"))
	file.close()
	rig.shot_dir = old_dir
	print("GEM CAPS: ", output, " checks=", t.report.checks.size(), " findings=", t.report.findings.size(), " failures=", t.report.failures.size())
	return "" if t.report.complete and t.report.failures.is_empty() else "Gem synthesis cap probe failed"


func _exercise() -> String:
	_check("capital/actual_world", g.chapter_id == "capital" and g.world != null and g.play_started
		and g.state == Game.ST_PLAYING and not g.hud.dialogue_active and not g.hud.choices_active)
	for grade in ["C", "B", "A"]:
		var cap: int = Items.GEM_LEVEL_LIMIT[grade]
		var item := _seed(grade, cap, 2)
		if item.is_empty(): return "Could not prepare legal " + grade + " socket"
		await _open()
		if grade == "C" and not baseline:
			if not await _gear_card(item):
				await _capture("08_item_body_card_missing")
				return "Ordinary item-card input failed"
			await _capture("07_item_body_card")
			if not await _dismiss_card(): return "Item-card dismissal left inventory"
			if g.touch_mode:
				var emulation := Input.emulate_mouse_from_touch
				Input.emulate_mouse_from_touch = false
				var raw_opened := await _gear_card(item)
				Input.emulate_mouse_from_touch = emulation
				_check("touch/raw_body_fallback", raw_opened)
				if not raw_opened: return "Raw touch item-card fallback failed"
				if not await _dismiss_card(): return "Raw item-card dismissal left inventory"
		if grade == "C" and not baseline and g.touch_mode:
			if not await _socket_scroll(): return "Socket drag did not preserve inventory scrolling"
			await _open()
		if grade == "C": await _capture("01_C_before")
		var before := _state()
		if not await _click_auto(): return "Auto-synthesize button unavailable at " + grade
		var after := _state()
		var unchanged: bool = after.equipment == before.equipment and after.bag == before.bag and is_equal_approx(after.atk, before.atk)
		var illegal_equipment: Dictionary = before.equipment.duplicate(true)
		illegal_equipment.weapon.gems[0].lvl = cap + 1
		var old_result: bool = after.equipment == illegal_equipment and after.bag == {"magpen/1": 1} and after.atk > before.atk
		if baseline and not unchanged and old_result:
			report.findings.append(grade + "/cap")
		else:
			_check(grade + "/cap", unchanged, {"before": before, "after": after})
		_check(grade + "/exact_result", old_result if baseline else unchanged, {"before": before, "after": after})
		_check(grade + "/notice", _notice() == ("1 gem upgrade." if baseline else "No available gem upgrades."), {"notice": _notice()})
		if not await _socket_card():
			await _capture("07_socket_card_missing")
			return "Socketed gem detail unavailable"
		await _capture({"C": "02_C_after", "B": "03_B_after", "A": "04_A_after"}[grade])
		await _open()
		var repeat := _state()
		if not await _click_auto(): return "Repeat button unavailable"
		_check(grade + "/repeat", _state() == repeat)
		if grade == "A" and not baseline:
			if not await _empty_socket_card(): return "Empty socket did not open Gems"
			await _capture("08_empty_socket_gems")
	# Legal controls run on baseline and strict source.
	for spec in [["B", 2, 3], ["S", 9, 10]]:
		var item := _seed(String(spec[0]), int(spec[1]), 2)
		if item.is_empty(): return "Could not prepare below-cap control"
		await _open()
		var atk_before: float = p.atk
		if not await _click_auto(): return "Positive control button unavailable"
		_check(String(spec[0]) + "/positive", int(item.gems[0].lvl) == int(spec[2])
			and _count("atk_flat", int(spec[1])) == 0 and _count("magpen", 1) == 1 and p.atk > atk_before, _state())
		if spec[0] == "S": await _capture("05_S_legal_max")
	var maximum := _seed("S", 10, 2)
	if maximum.is_empty(): return "Could not prepare S10 control"
	await _open()
	var max_before := _state()
	if not await _click_auto(): return "Maximum control button unavailable"
	_check("S/max_unchanged", _state() == max_before)
	if not baseline:
		var max_card := await _max_bag_card()
		await _capture("09_max_bag_card")
		if not max_card: return "Maximum gem card promises another upgrade"
	# The old implementation would create further known crossings here. Keep
	# baseline's whitelist exactly the three isolated proofs above; these are
	# strict-only acceptance, not silently waived baseline observations.
	if not baseline:
		var capped := _seed("C", 2, 2)
		if capped.is_empty(): return "Mixed cap setup failed"
		var other := Items.roll_item_of("armor", "B", rng, p.cls)
		p.equipment["armor"] = other
		p.gem_bag.append(Items.make_gem("hp_flat", 2))
		if not p.embed_gem_into(other, p.gem_bag.back()): return "Mixed legal socket refused"
		for i in 2: p.gem_bag.append(Items.make_gem("hp_flat", 2))
		p.recalc()
		await _open()
		if not await _click_auto(): return "Mixed control button unavailable"
		_check("mixed/skip_capped", int(capped.gems[0].lvl) == 2 and int(other.gems[0].lvl) == 3
			and _count("atk_flat", 2) == 2 and _count("hp_flat", 2) == 0, _state())
		capped = _seed("C", 2, 3)
		if capped.is_empty(): return "Capped bag triple setup failed"
		await _open()
		if not await _click_auto(): return "Bag triple button unavailable"
		_check("bag/triple_beyond_vessel", int(capped.gems[0].lvl) == 2 and _count("atk_flat", 2) == 0
			and _count("atk_flat", 3) == 1 and _count("magpen", 1) == 1, _state())
	# Actual road world, not just a changed chapter label. Setup/travel is direct.
	var road_item := _seed("B", 2, 3)
	if road_item.is_empty(): return "Road setup failed"
	g.menus.close()
	g.request_pause(false)
	g.switch_chapter("ch1", true)
	await r.frames(4)
	await r.skip_dialogue()
	await _open()
	_check("road/actual_context", g.chapter_id == "ch1" and g.room_type(g.cur_room) == "safe")
	if not await _click_auto(): return "Road control button unavailable"
	_check("road/bag_only", int(road_item.gems[0].lvl) == 2 and _count("atk_flat", 2) == 0
		and _count("atk_flat", 3) == 1 and _count("magpen", 1) == 1, _state())
	await _capture("06_road_bag_only")
	return ""


func _seed(grade: String, level: int, matches: int) -> Dictionary:
	g.menus.close()
	g.request_pause(false)
	p.equipment = {}
	p.gem_bag = [Items.make_gem("magpen", 1)] # inert sentinel keeps the real button present
	var item := Items.roll_item_of("weapon", grade, rng, p.cls)
	p.equipment["weapon"] = item
	p.gem_bag.append(Items.make_gem("atk_flat", level))
	if not p.embed_gem_into(item, p.gem_bag.back()): return {}
	for i in matches: p.gem_bag.append(Items.make_gem("atk_flat", level))
	p.recalc()
	p._update_weapon_visual()
	_check(grade + str(level) + "/legal_setup", level <= int(Items.GEM_LEVEL_LIMIT[grade])
		and _count("atk_flat", level) == matches and item.gems.size() == 1
		and p.equip_error(item) == "", _state())
	return item


func _open() -> void:
	g.menus.open_inventory("gear", "gems")
	await r.frames(6)
	await RenderingServer.frame_post_draw


func _click_auto() -> bool:
	var button: Button = null
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var node := raw as Button
		if node.is_visible_in_tree() and node.text.contains("Auto-synthesize"):
			if button != null: return false
			button = node as Button
	if button == null or button.disabled: return false
	var rect := button.get_global_rect()
	if not g.get_viewport_rect().encloses(rect): return false
	await _tap(rect.get_center())
	return g.menus.current == "inventory"


func _socket_card() -> bool:
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.contains("Select for its card"):
			if not g.get_viewport_rect().encloses(button.get_global_rect()): return false
			at = button.get_global_rect().get_center()
			break
	if at.x < 0: return false
	var before := _state()
	# GUI input may rebuild the shell. Never resume an old control-array walk.
	await _tap(at)
	var found := false
	if is_instance_valid(g.menus.root):
		for candidate in g.menus.root.find_children("*", "Button", true, false):
			var action := candidate as Button
			if action.is_visible_in_tree() and action.text.contains("Remove  (back to bag)"): found = true
	if not report.has("socket_attempts"): report["socket_attempts"] = []
	report.socket_attempts.append({"input_at": str(at), "current": g.menus.current,
		"found": found, "before": before, "after": _state()})
	if found and _state() == before: return true
	return false


func _max_bag_card() -> bool:
	# Only the two lent Lv10 rubies have a stack badge in this bag.
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text == "x2" and label.get_parent() is Button:
			var button := label.get_parent() as Button
			if button.get_global_rect().position.x > 570.0:
				at = button.get_global_rect().get_center()
				break
	if at.x < 0: return false
	var before := _state()
	await _tap(at)
	var info := ""
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text.contains("A regular gem"):
			info = label.text
	var can_synthesize := false
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.text.contains("Synthesize  (3"):
			can_synthesize = true
	var good := g.menus.current == "detail" and _state() == before and not can_synthesize \
		and info.contains("Maximum gem level") and not info.contains("Gather three")
	_check("input/max_bag_card", good, {"info": info, "synthesize_action": can_synthesize})
	return good


func _empty_socket_card() -> bool:
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.begins_with("Empty "):
			at = button.get_global_rect().get_center()
			break
	if at.x < 0: return false
	var before := _state()
	await _tap(at)
	var found := false
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text.begins_with("The Lapidary counts you"): found = true
	var good := found and g.menus.current == "detail" and _state() == before
	_check("input/empty_socket_gems", good, {"found": found, "current": g.menus.current})
	return good


func _socket_scroll() -> bool:
	var socket: Button = null
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.contains("Select for its card"):
			socket = button
			break
	if socket == null: return false
	var parent: Node = socket.get_parent()
	while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
	if parent == null: return false
	var scroll := parent as ScrollContainer
	var offset := scroll.scroll_vertical
	var before := _state()
	var at := socket.get_global_rect().get_center()
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(1)
	for i in 4:
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = at - Vector2(0, 16); drag.relative = Vector2(0, -16)
		Input.parse_input_event(drag); Input.flush_buffered_events()
		at = drag.position
		await r.frames(1)
	event = InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
	await r.frames(4)
	var good := is_instance_valid(scroll) and g.menus.current == "inventory" \
		and not is_instance_valid(g.menus.detail_popover) and _state() == before
	var after: int = scroll.scroll_vertical if is_instance_valid(scroll) else -1
	good = good and after > offset
	_check("touch/socket_drag_scroll", good, {"before": offset, "after": after, "current": g.menus.current})
	return good


func _gear_card(item: Dictionary) -> bool:
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text == Items.title(item):
			at = label.get_global_rect().get_center()
			break
	if at.x < 0: return false
	var before := _state()
	await _tap(at)
	var found := false
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.text.contains("Unequip  (move to bag)"): found = true
	var good := found and g.menus.current == "detail" and _state() == before
	_check("input/item_body_card", good, {"at": str(at), "mouse_emulation": Input.emulate_mouse_from_touch,
		"current": g.menus.current, "found": found, "before": before, "after": _state()})
	return good


func _dismiss_card() -> bool:
	var before := _state()
	# Popovers follow the real OS cursor. Choose a blank underlay point that is
	# actually outside this card, rather than assuming a fixed popup position.
	var box: Rect2 = g.menus._popover_box.get_global_rect()
	var at := Vector2(-1, -1)
	for candidate in [Vector2(580, 600), Vector2(1100, 600), Vector2(580, 180), Vector2(1100, 180)]:
		if not box.has_point(candidate):
			at = candidate
			break
	if at.x < 0: return false
	await _tap(at)
	var good := g.menus.current == "inventory" and is_instance_valid(g.menus.root) \
		and not is_instance_valid(g.menus.detail_popover) and _state() == before
	_check("input/dismiss_once", good, {"at": str(at), "box": str(box), "current": g.menus.current})
	return good


func _tap(at: Vector2) -> void:
	if not g.touch_mode:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
	for down in [true, false]:
		if g.touch_mode:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = at
			event.pressed = down
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = at
			event.global_position = at
			event.pressed = down
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(2)
	await r.frames(4)


func _count(stat: String, level: int) -> int:
	var total := 0
	for gem in p.gem_bag:
		if gem.stat == stat and int(gem.lvl) == level: total += 1
	return total


func _state() -> Dictionary:
	var bag := {}
	for gem in p.gem_bag:
		var key := "%s/%d" % [gem.stat, int(gem.lvl)]
		bag[key] = int(bag.get(key, 0)) + 1
	return {"equipment": p.equipment.duplicate(true), "bag": bag, "atk": p.atk, "max_hp": p.max_hp}


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	report.views.append({"name": label, "path": r.shot(label), "state": _state(), "notice": _notice()})


func _notice() -> String:
	# open_inventory consumes inventory_notice into a real Label immediately.
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and (label.text.contains("gem upgrade") or label.text == "No matching gems to merge."):
			return label.text
	return ""


func _check(id: String, good: bool, data := {}) -> void:
	report.checks.append({"id": id, "ok": good, "data": data})
	if not good: report.failures.append(id)


func _stash(object: Object, fields: Array) -> Dictionary:
	var result := {}
	for key in fields:
		var value: Variant = object.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _restore(object: Object, values: Dictionary) -> void:
	for key in values: object.set(key, values[key])
