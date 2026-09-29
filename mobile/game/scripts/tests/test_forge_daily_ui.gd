extends RefCounted
## Private world and viewport: UI actions use production callbacks without
## borrowing campaign wallets, daily ledgers, RNG, favor, mail or save files.

class UIWorld extends Game:
	var floats: Array = []
	func _ready() -> void: pass
	func _meta_write() -> void: pass
	func spawn_text(_pos: Vector2, text: String, _color: Color, _hold := 0.0) -> void:
		floats.append(text)

class UIPlayer extends Player:
	func _ready() -> void: pass


static func run(t: Node) -> String:
	var paused := t.get_tree().paused
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	t.add_child(viewport)
	var g := UIWorld.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.no_saves = true
	g._meta_loaded = true
	g._meta = {}
	g.chapter_id = "capital"
	g.player = UIPlayer.new()
	g.player.game = g
	g.player.sprite = Sprite2D.new()
	g.player.add_child(g.player.sprite)
	g.add_child(g.player)
	viewport.add_child(g)
	g.menus = Menus.new()
	g.menus.game = g
	g.menus.shell_motion = false
	g.add_child(g.menus)
	g.play_started = true
	g.state = g.ST_PLAYING
	var error := await preload("res://scripts/tests/test_ui_frame.gd").run(g)
	if error == "":
		error = await _forge(g)
	if error == "":
		error = await _daily(g)
	if error == "":
		error = _mail(g)
	# Always restore tree state, even after an assertion returns early.
	viewport.free()
	t.get_tree().paused = paused
	if error == "":
		print("ok: forge exact shortfalls and single charges, daily keyboard claim/Close and fallen gating, HUD-envelope mail pointers")
	return error


static func _frames(g: Game) -> void:
	for _i in 3:
		await g.get_tree().process_frame


static func _button(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if String(child.text).strip_edges().begins_with(prefix):
			return child as Button
	return null


static func _has_text(node: Node, expected: String) -> bool:
	for child in node.find_children("*", "Label", true, false):
		if expected in String(child.text):
			return true
	return false


static func _forge(g: Game) -> String:
	var m := g.menus
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	for kind in ["quench", "reforge", "transmute", "socket"]:
		var item := Items.roll_item_of("weapon", "A", rng, "warrior")
		item.subs = {"crit": 0.01}
		var stat := String(item.main.keys()[0])
		item.main[stat] = Items.stat_band(item, stat)[0]
		var prefix := ""
		var cost := 0
		# Pin each precondition; never inherit favor or gold from another case.
		g.player.npc_favor = {}
		match kind:
			"quench":
				prefix = "Quench " + String(Items.STAT_LABEL.get(stat, stat))
				cost = Items.quench_cost(item, stat)
			"reforge":
				prefix = "Reforge "
				cost = Items.reforge_cost(item, "affix")
			"transmute":
				prefix = String(Items.STAT_LABEL.get(stat, stat)) + " → "
				cost = Items.transmute_cost(item)
			"socket":
				prefix = "Add gem socket"
				cost = Items.reforge_cost(item, "socket")
		var before := item.duplicate(true)
		for stale_wallet in [false, true]:
			g.player.gold = cost if stale_wallet else cost - 60
			m._open("Forge QA", 800, 660)
			m.open_item_panel(item, Vector2(-1, -1), "reforge")
			await _frames(g)
			var action := _button(m.detail_popover, prefix)
			if action == null or action.disabled:
				return kind + " missing explainable forge action"
			if not stale_wallet and "need 60 more gold" not in action.text:
				return kind + " did not show its exact shortfall beside the price"
			g.player.gold = cost - 60
			var favor := g.player.npc_favor.duplicate(true)
			var flags := g.flags.duplicate(true)
			var rng_state := g.loot_rng.state
			action.pressed.emit()
			await _frames(g)
			var expected := "Need %s gold, you have %s." % [m._fmt_gold(cost), m._fmt_gold(cost - 60)]
			if not _has_text(m.detail_popover, expected):
				return kind + " refused without exact cost/current-wallet message: " + expected
			if g.player.gold != cost - 60 or item != before or g.player.npc_favor != favor \
					or g.flags != flags or g.loot_rng.state != rng_state:
				return kind + " refusal changed gold, item, favor, quest or RNG"
		# A previously unaffordable button must also accept a newly funded wallet.
		var accepted := _button(m.detail_popover, prefix)
		g.player.gold = cost + 73
		accepted.pressed.emit()
		await _frames(g)
		if g.player.gold != 73:
			return kind + " did not charge exactly once on acceptance"
		if kind != "quench" and item == before:
			return kind + " charged without performing the action"
	return ""


static func _action(g: Game, action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		g.get_viewport().push_input(event)
		await g.get_tree().process_frame


static func _daily(g: Game) -> String:
	var m := g.menus
	g.daily_last_day = g.daily_day_index() - 1
	g.daily_streak = 0
	g.player.gold = 0
	# Touch keeps its pointer-only behavior: no keyboard focus ring on open.
	var was_touch := g.touch_mode
	g.touch_mode = true
	m.open_daily()
	await _frames(g)
	var touch_owner := m.root.get_viewport().gui_get_focus_owner()
	g.touch_mode = was_touch
	if touch_owner != null and m.root.is_ancestor_of(touch_owner):
		return "daily screen grabbed keyboard focus in touch mode"
	m.close()
	await _frames(g)
	m.open_daily()
	await _frames(g)
	var claim := m.root.find_child("DailyClaim", true, false) as Button
	var close := m.root.find_child("DailyClose", true, false) as Button
	if claim == null or close == null or not claim.has_focus() or claim.focus_mode != Control.FOCUS_ALL:
		return "daily claim is not the initial keyboard focus"
	var focus := claim.get_theme_stylebox("focus") as StyleBoxFlat
	if focus == null or focus.draw_center or focus.border_color != UITheme.GOLD_BRIGHT \
			or focus.border_width_top <= 0:
		return "daily claim lacks the UI family's visible focus outline"
	await _action(g, "ui_focus_next")
	if not close.has_focus():
		return "Tab from daily claim did not reach Close"
	await _action(g, "ui_focus_next")
	if not claim.has_focus():
		return "Tab from Close did not reach daily claim"
	await _action(g, "ui_focus_prev")
	if not close.has_focus():
		return "reverse Tab from daily claim did not reach Close"
	await _action(g, "ui_focus_prev")
	await _action(g, "ui_accept")
	await _frames(g)
	var reward_gold := int(float(g.daily_reward_for(1).gold) * Balance.daily_gold_mult(g.player.level))
	if g.daily_available() or g.daily_streak != 1 or g.player.gold != reward_gold \
			or not _has_text(m.root, "Day 1 claimed"):
		return "keyboard accept did not claim exactly one daily reward with receipt"
	close = m.root.find_child("DailyClose", true, false) as Button
	if close == null or not close.has_focus() or m.root.find_child("DailyClaim", true, false) != null:
		return "daily receipt did not hand focus to Close"
	# Refresh the already-claimed screen, then exercise both fallen gates.
	m.open_daily()
	await _frames(g)
	close = m.root.find_child("DailyClose", true, false) as Button
	if close == null or not close.has_focus():
		return "already-claimed daily screen did not focus Close"
	for fallen in ["downed", "ghost"]:
		g.daily_last_day = g.daily_day_index() - 1
		g.player.set(fallen, true)
		m.open_daily()
		await _frames(g)
		close = m.root.find_child("DailyClose", true, false) as Button
		if m.root.find_child("DailyClaim", true, false) != null or close == null or not close.has_focus():
			return "fallen daily screen exposed claim or stranded keyboard focus"
		g.player.set(fallen, false)
	# Accept on Close must dismiss, without making another claim.
	await _action(g, "ui_accept")
	if m.is_open() or g.player.gold != reward_gold:
		return "keyboard Close did not dismiss without another reward"
	return ""


static func _mail(g: UIWorld) -> String:
	g.floats = []
	g.send_mail("QA letter", "Mail pointer check", [])
	if g.floats != ["New mail! Open the envelope on your HUD."]:
		return "mail float did not point at the HUD envelope: " + str(g.floats)
	var body := g.menus._open("Bag notes QA", 800, 660)
	UICodex._gear_bags(g.menus, body)
	if not _has_text(body, "Mailbox (the envelope on your HUD)") or _has_text(body, "pause menu"):
		return "codex bag notes did not point at the HUD envelope"
	return ""
