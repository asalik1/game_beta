extends RefCounted
## QA-only upkeep: choose existing visible controls; never grant/spend directly.


static func dismiss_teaching(r: Node) -> String:
	var g: Game = r.game
	await r.frames(3) # let the existing post-clear onboarding queue display
	if g.hud.dialogue_active:
		var lines: Array = g.hud.dialogue_lines
		if lines.size() != 1 or lines[0].size() < 2 or String(lines[0][0]) != "Elder Maren" \
				or not (String(lines[0][1]).begins_with("You're getting stronger.") \
				or String(lines[0][1]).begins_with("The fallen leave good gear behind.")):
			return "Unexpected post-clear dialogue; no teaching beat was assumed."
		await r._dialogue()
	if not g.menus.is_open(): return ""
	var current: String = g.menus.current
	if not ((current == "skills" and g.get_flag("tut_talents_done", false)) \
			or (current == "inventory" and g.get_flag("tut_gear_done", false))):
		return "Unexpected post-clear menu: " + current
	r._release()
	await r.native._key(KEY_ESCAPE)
	if g.menus.is_open(): return "Teaching screen did not close through Escape."
	r._mark("ordinary " + current + " teaching screen acknowledged; upkeep follows collection")
	return ""


static func run(r: Node, label: String) -> String:
	var g: Game = r.game
	var p: Player = r.p
	r._release()
	if g.menus.is_open() or g.hud.dialogue_active or g.hud.choices_active:
		return "Unexpected overlay before ordinary upkeep."
	var receipt := {"label": label, "before": r._hero(), "actions": [], "status": "started"}
	if not r.report.has("upkeep"): r.report["upkeep"] = []
	r.report.upkeep.append(receipt)
	r._write_report()
	if not p.backpack.is_empty():
		if not await open_menu(r, "inventory"):
			return _stop(r, receipt, "Real Inventory held key did not open Inventory.")
		if not await r.native._button("Auto-equip"):
			return _stop(r, receipt, "Real Inventory Auto-equip control unavailable.")
		receipt.actions.append({"action": "Inventory Auto-equip", "after": r._hero()})
		r._write_report()
		await r.native._key(KEY_ESCAPE)
		if g.menus.is_open(): return _stop(r, receipt, "Inventory did not close after Auto-equip.")
	if p.skill_points > 0 or p.unspent_attr > 0:
		if not await open_menu(r, "skills"):
			return _stop(r, receipt, "Real Skills held key did not open Skills.")
		# Fixed, declared policy: first legal talent in table order, then primary
		# attributes. Choice is independent of this run's seed, loot and outcomes.
		for _point in 64:
			if p.skill_points <= 0: break
			var chosen: Dictionary = {}
			for row in Skills.TREES[p.cls]:
				for cell in row:
					if chosen.is_empty() and Skills.can_add(p.cls, String(cell.id), p.tree_points, p.level):
						chosen = cell
			if chosen.is_empty(): break # retained unspent points, not an invented unlock
			var button: Button
			for raw in g.menus.root.find_children("*", "Button", true, false):
				if String(raw.text).begins_with(String(chosen.name) + "    "):
					button = raw as Button
			var unspent := p.skill_points
			var wanted := p.tree_points.duplicate(true)
			wanted[String(chosen.id)] = int(wanted.get(String(chosen.id), 0)) + 1
			if not await r._click(button): return _stop(r, receipt, "Exact live talent button unavailable: " + String(chosen.name))
			if p.skill_points != unspent - 1 or p.tree_points != wanted:
				return _stop(r, receipt, "Talent click did not spend exactly one available point.")
			receipt.actions.append({"action": "talent", "id": chosen.id, "after": r._hero()})
			r._write_report()
		if p.unspent_attr > 0:
			if not await r.native._button("ATTRIBUTES"):
				return _stop(r, receipt, "Real Attributes tab unavailable.")
			var primary := String(Classes.CLASSES[p.cls].primary)
			for _point in 64:
				if p.unspent_attr <= 0: break
				var plus: Button
				var matches := 0
				for raw in g.menus.root.find_children("*", "Button", true, false):
					if String(raw.text).strip_edges() != "+1": continue
					for text_node in raw.get_parent().find_children("*", "Label", true, false):
						if String(text_node.text) == primary + "  ★":
							plus = raw as Button
							matches += 1
				var unspent := p.unspent_attr
				var wanted := p.attr_points.duplicate(true)
				wanted[primary] = int(wanted.get(primary, 0)) + 1
				if matches != 1 or not await r._click(plus):
					return _stop(r, receipt, "Exact primary-attribute +1 control unavailable.")
				if p.unspent_attr != unspent - 1 or p.attr_points != wanted:
					return _stop(r, receipt, "Attribute click did not spend exactly one available point.")
				receipt.actions.append({"action": "attribute", "id": primary, "after": r._hero()})
				r._write_report()
		await r.native._key(KEY_ESCAPE)
		if g.menus.is_open(): return _stop(r, receipt, "Skills did not close after upkeep.")
	receipt.status = "complete"
	receipt["after"] = r._hero()
	r._write_report()
	return ""


static func _stop(r: Node, receipt: Dictionary, reason: String) -> String:
	r._release()
	receipt.status = "incomplete"
	receipt["reason"] = reason
	receipt["after"] = r._hero()
	r._write_report()
	return reason


## I/T open from Game._process held-state polling. A one-frame event tap can
## start after post-draw and release at the next process_frame BEFORE that poll.
## Keep one ordinary press down until the menu appears; the production debounce
## expires naturally. No direct menu open, state write, timer clear or key retry.
static func open_menu(r: Node, menu: String) -> bool:
	var g: Game = r.game
	var code: int = int(g.binds[menu])
	var receipt := {"expected": menu, "key": code, "before": _menu_state(g, code),
		"status": "pending", "started_msec": Time.get_ticks_msec()}
	if not r.report.has("menu_hotkeys"): r.report["menu_hotkeys"] = []
	r.report.menu_hotkeys.append(receipt)
	if g.menus.is_open() or g.hud.dialogue_active or g.hud.choices_active:
		receipt.status = "unexpected_overlay"
		r._write_report()
		return false
	r._press(code, true)
	receipt["pressed"] = _menu_state(g, code)
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		if g.menus.is_open() or g.hud.dialogue_active or g.hud.choices_active \
				or r.p.dead or r.p.downed or r.p.ghost:
			break
		await r.frames(1)
	receipt["observed"] = _menu_state(g, code)
	var opened: bool = g.menus.is_open() and g.menus.current == menu
	r._press(code, false) # guaranteed on success, timeout and unexpected overlay
	await r.frames(2)
	var settled: bool = opened and g.menus.is_open() and g.menus.current == menu \
		and not Input.is_key_pressed(code)
	receipt.status = "opened_and_released" if settled else "not_opened_or_not_retained"
	receipt["released"] = _menu_state(g, code)
	receipt["elapsed_msec"] = Time.get_ticks_msec() - int(receipt.started_msec)
	r._write_report()
	return settled


static func _menu_state(g: Game, code: int) -> Dictionary:
	return {"menu": g.menus.current, "open": g.menus.is_open(), "talk_cd": g.talk_cd,
		"overlay": g.input_overlay_up(), "paused": g.get_tree().paused,
		"state": g.state, "play_started": g.play_started, "key_down": Input.is_key_pressed(code),
		"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames()}
