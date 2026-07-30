class_name UIProfessions
## The Professions panel (PROPOSALS/PROFESSIONS.md §8): the locked trade + its
## mastery band and climb, known blueprints, and the craft bench. A static
## builder taking the Menus instance, like ui/daily.gd and ui/wardrobe.gd.
## Opened from a capital trainer station (game_world._hub_action "professions" /
## Smith Petra's gossip hub). All ACTIONS — locking a trade, crafting, buying a
## blueprint — gate on being AT Crownfall (chapter_id == "capital"), the
## capital-is-the-shop law; the panel still SHOWS your progress anywhere.
##
## The heavy lifting is in Professions (logic) + balance.gd (knobs); this file
## is pure display + the click-throughs. DEFERRED: gathering nodes, salvage, the
## consumable outputs (potions/bench-stones/bags) — gear crafting only.

const CRAFT_GRADES := ["F", "E", "D", "C", "B", "A"]  # S is drop-only (never craftable)


## `msg`/`msg_color` show the last in-place action's result; `slot` is unused
## for now (kept for a future focus, single-screen refresh flow).
static func open(m: Menus, msg := "", msg_color := Color(0.8, 0.85, 1.0), slot := "") -> void:
	var g := m.game
	var p: Player = g.local_player
	var at_capital: bool = g.chapter_id == "capital"
	var vbox := m._open("Professions — Craft, Mastery & Blueprints", 1060, 660, true)
	m.current = "professions"

	if msg != "":
		m._lbl(vbox, msg, 14, msg_color)
	_header(m, vbox, p, at_capital)

	# Scrolling body (the three sections can run tall; footer stays pinned).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	_trade_section(m, list, p, at_capital, slot)
	_craft_section(m, list, p, at_capital, slot)
	_blueprint_section(m, list, p, at_capital)

	m._lbl(vbox, "Your gold: %d" % p.gold, 13, Color(1.0, 0.85, 0.35))
	m._hint(vbox)


## Active trade, mastery band + climb, and the at-Crownfall reminder.
static func _header(m: Menus, vbox: VBoxContainer, p: Player, at_capital: bool) -> void:
	if p.profession == "":
		m._lbl(vbox, "No trade locked yet. Pick one below — your FIRST lock is free; switching later costs gold.",
			15, Color(1.0, 0.85, 0.5))
	else:
		m._lbl(vbox, "%s   —   %s   (crafts up to grade %s)" %
			[Professions.trade_name(p.profession), Professions.band(p), Professions.max_grade(p)],
			17, Color(0.95, 0.9, 0.6))
		var pts := Professions.points(p)
		var tonext := Balance.mastery_to_next(pts)
		if tonext > 0:
			m._lbl(vbox, "Mastery %d  •  %d more to the next band" % [pts, tonext], 13, Color(0.7, 0.85, 1.0))
		else:
			m._lbl(vbox, "Mastery %d  •  MASTER — the top band; grade-A crafting unlocked" % pts,
				13, Color(0.6, 1.0, 0.6))
	if not at_capital:
		m._lbl(vbox, "The benches are in Crownfall — travel to the capital (⌂) to lock a trade, craft, or learn blueprints.",
			13, Color(1.0, 0.7, 0.5))


# ------------------------------------------------------------- trade lock ---

static func _trade_section(m: Menus, list: VBoxContainer, p: Player, at_capital: bool, slot: String) -> void:
	m._lbl(list, "— Trade  (locked: one at a time; mastery persists across swaps) —", 15, Color(0.85, 0.8, 0.7))
	for t in Professions.trades():
		var label := "%s  [%s]" % [Professions.trade_name(t), ", ".join(Professions.slots_of(t))]
		if t == p.profession:
			m._lbl(list, "   ● %s — active" % label, 14, Color(0.6, 1.0, 0.6))
			continue
		var free_lock := p.profession == ""
		var cost := 0 if free_lock else Professions.swap_cost(p)
		var cost_txt := "free — first lock" if free_lock else "%d gold to swap" % cost
		var mpts := Professions.points(p, t)
		var kept := "" if mpts == 0 else "   (mastery %d kept)" % mpts
		var enabled := at_capital and (free_lock or p.gold >= cost)
		m._btn(list, "   Lock %s  —  %s%s" % [label, cost_txt, kept],
			_lock_cb(m, t, slot), Color(0.9, 0.85, 0.6) if enabled else Color(0.5, 0.5, 0.55), enabled)


static func _lock_cb(m: Menus, trade: String, slot: String) -> Callable:
	return func() -> void:
		var p: Player = m.game.local_player
		var r := Professions.lock_trade(p, trade)
		if not r["ok"]:
			open(m, String(r["reason"]), Color(1.0, 0.6, 0.5), slot)
			return
		m.game.sfx("equip")
		m.game.autosave()
		var paid := "" if int(r["cost"]) == 0 else "   (-%d gold)" % int(r["cost"])
		open(m, "Locked %s.%s" % [Professions.trade_name(trade), paid], Color(0.6, 1.0, 0.6), slot)


# ------------------------------------------------------------------- craft ---

static func _craft_section(m: Menus, list: VBoxContainer, p: Player, at_capital: bool, slot: String) -> void:
	m._lbl(list, "— Craft  (spend materials + a gold fee → class-matched gear) —", 15, Color(0.85, 0.8, 0.7))
	if p.profession == "":
		m._lbl(list, "   Lock a trade to craft its slots.", 13, Color(0.6, 0.6, 0.65))
		return
	for cslot in Professions.active_slots(p):
		var fam := Balance.craft_material(cslot)
		m._lbl(list, "%s  —  made from %s" % [cslot.capitalize(), fam], 14, Color(0.8, 0.85, 0.95))
		for grade in CRAFT_GRADES:
			var need := int(Balance.CRAFT_MATERIAL_COST.get(grade, 0))
			var fee := int(Balance.CRAFT_GOLD_FEE.get(grade, 0))
			var have := p.material_count(fam, grade)
			var line := "%s  —  %d %s (grade %s) + %d gold   [have %d]" % [grade, need, fam, grade, fee, have]
			var blocked := Professions.craft_blocked(p, cslot, grade)
			if blocked == "" and at_capital:
				m._btn(list, "   Craft " + line, _craft_cb(m, cslot, grade, slot),
					Items.GRADE_COLOR.get(grade, Color(1, 1, 1)))
			else:
				var why := blocked if blocked != "" else "at Crownfall only"
				m._lbl(list, "   %s  —  %s" % [grade, why], 12, Color(0.55, 0.55, 0.6))


static func _craft_cb(m: Menus, cslot: String, grade: String, slot: String) -> Callable:
	return func() -> void:
		var g := m.game
		var p: Player = g.local_player
		var r := Professions.craft(p, cslot, grade, g.loot_rng)
		if not r["ok"]:
			open(m, String(r["reason"]), Color(1.0, 0.6, 0.5), slot)
			return
		var item: Dictionary = r["item"]
		var banked := p.add_item(item)
		if not banked:
			g.send_mail("Your crafted gear",
				"The bench was ready but your bag was full — the piece waits here.",
				[{"kind": "item", "item": item}])
		g.sfx("chest")
		p.recalc()
		g.autosave()
		var tag := "Promoted to a NAMED unique!  " if bool(r["promoted"]) else ""
		var mailed := "" if banked else "   (mailed — bag was full)"
		open(m, "%sCrafted %s  (+%d mastery)%s" % [tag, Items.title(item), int(r["mastery_gain"]), mailed],
			Color(1.0, 0.85, 0.4) if bool(r["promoted"]) else Color(0.7, 0.95, 0.7), slot)


# -------------------------------------------------------------- blueprints ---

static func _blueprint_section(m: Menus, list: VBoxContainer, p: Player, at_capital: bool) -> void:
	m._lbl(list, "— Blueprints  (generic B/A recipes; boss drops, or buy the deterministic price) —",
		15, Color(0.85, 0.8, 0.7))
	if p.profession == "":
		m._lbl(list, "   Lock a trade to learn its recipes.", 13, Color(0.6, 0.6, 0.65))
		return
	for bslot in Professions.active_slots(p):
		for grade in Items.BLUEPRINT_GRADES:
			var price := Balance.blueprint_price(bslot, grade)
			if p.has_blueprint(bslot, grade):
				m._lbl(list, "   ✓ Generic %s %s — known" % [grade, bslot.capitalize()], 12, Color(0.6, 0.9, 0.6))
			else:
				var enabled := at_capital and p.gold >= price
				m._btn(list, "   Learn Generic %s %s  —  %d gold" % [grade, bslot.capitalize(), price],
					_buy_cb(m, bslot, grade), Color(0.85, 0.8, 0.95) if enabled else Color(0.5, 0.5, 0.55), enabled)


static func _buy_cb(m: Menus, bslot: String, grade: String) -> Callable:
	return func() -> void:
		var p: Player = m.game.local_player
		var r := Professions.buy_blueprint(p, bslot, grade)
		if not r["ok"]:
			open(m, String(r["reason"]), Color(1.0, 0.6, 0.5))
			return
		m.game.sfx("chest")
		m.game.autosave()
		open(m, "Learned Generic %s %s.   (-%d gold)" % [grade, bslot.capitalize(), int(r["cost"])],
			Color(0.6, 1.0, 0.6))
