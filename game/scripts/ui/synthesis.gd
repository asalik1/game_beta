class_name UISynthesis
## The Synthesis bench (PROPOSALS/CONSUMABLE_GRADES.md §9) — Herbalist Kesh's
## Alchemy capstone. Learn the Alkahest Codex ONCE (~100k), then fuse a clean S +
## the laced A of a family into a Grand potion (a modest step above S, no
## drawback). Mirrors ui/professions.gd: a static builder over the Menus
## instance, opened from Kesh's gossip hub in Crownfall. All ACTIONS — learning
## the Codex, synthesising — gate on being AT Crownfall (chapter_id == "capital",
## the capital-is-the-shop law); the panel still SHOWS your progress anywhere.
##
## The logic lives in Professions (buy_codex / synth_blocked / synthesize) +
## balance.gd (knobs) + items.gd (make_grand_potion); this file is pure display +
## the click-throughs, so the loop is identical in and out of the panel.


## `msg`/`msg_color` show the last in-place action's result.
static func open(m: Menus, msg := "", msg_color := Color(0.8, 0.85, 1.0)) -> void:
	var g := m.game
	var p: Player = g.local_player
	var at_capital: bool = g.chapter_id == "capital"
	var vbox := m._open("Synthesis — the Alkahest Codex", 1040, 640, true)
	m.current = "synthesis"

	if msg != "":
		m._lbl(vbox, msg, 14, msg_color)
	_header(m, vbox, p, at_capital)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	_recipe_section(m, list, p, at_capital)

	m._lbl(vbox, "Your gold: %d   ·   synthesis fee %d gold per Grand" %
		[p.gold, int(Balance.SYNTHESIS_FEE)], 13, Color(1.0, 0.85, 0.35))
	m._hint(vbox)


## The Codex state + the learn-once purchase, and the at-Crownfall reminder.
static func _header(m: Menus, vbox: VBoxContainer, p: Player, at_capital: bool) -> void:
	if p.knows_alkahest:
		m._lbl(vbox, "The Alkahest Codex is yours. Bring a clean S bottle and its laced A twin — Kesh will draw off something greater than either.",
			15, Color(0.85, 1.0, 0.7))
	else:
		m._lbl(vbox, "The Alkahest Codex — the recovered formulary that marries a legend's clean half to the street's laced half. Learned once; then Kesh synthesises forever.",
			15, Color(0.95, 0.9, 0.6))
		var price := int(Balance.ALKAHEST_CODEX_PRICE)
		var can_buy := at_capital and p.gold >= price
		m._btn(vbox, "Learn the Alkahest Codex  —  %d gold" % price, _learn_cb(m),
			Color(1.0, 0.92, 0.66) if can_buy else Color(0.5, 0.5, 0.55), can_buy)
	if not at_capital:
		m._lbl(vbox, "The alembic is in Crownfall — travel to the capital (⌂) to learn the Codex or synthesise.",
			13, Color(1.0, 0.7, 0.5))


static func _learn_cb(m: Menus) -> Callable:
	return func() -> void:
		var p: Player = m.game.local_player
		var r := Professions.buy_codex(p)
		if not r["ok"]:
			open(m, String(r["reason"]), Color(1.0, 0.6, 0.5))
			return
		m.game.sfx("chest")
		m.game.autosave()
		open(m, "Learned the Alkahest Codex.   (-%d gold)" % int(r["cost"]), Color(0.6, 1.0, 0.6))


# ------------------------------------------------------------------ recipes ---

static func _recipe_section(m: Menus, list: VBoxContainer, p: Player, at_capital: bool) -> void:
	m._lbl(list, "— Recipes  (a clean S + the laced A + %d gold → a Grand potion) —" %
		int(Balance.SYNTHESIS_FEE), 15, Color(0.85, 0.8, 0.7))
	if not p.knows_alkahest:
		m._lbl(list, "   Learn the Codex above to unlock the recipes.", 13, Color(0.6, 0.6, 0.65))
		return
	for fs in Professions.synth_families():
		var grand := Items.make_grand_potion(fs)
		var gname := String(grand.get("name", ""))
		var sname := Items.potion_name(fs, "S", "accord")
		var aname := Items.potion_name(fs, "A", "black")
		var have_s := not p.find_potion_by(fs, "S", "accord").is_empty()
		var have_a := not p.find_potion_by(fs, "A", "black").is_empty()
		m._lbl(list, "%s  —  %s" % [gname, String(grand.get("desc", ""))], 13, Items.GRADE_COLOR["Grand"])
		var line := "   %s %s   +   %s %s" % [
			"✓" if have_s else "✗", sname, "✓" if have_a else "✗", aname]
		var blocked := Professions.synth_blocked(p, fs)
		if blocked == "" and at_capital:
			m._btn(list, "   Synthesise %s" % gname + "   —  " + line.strip_edges(),
				_synth_cb(m, fs), Items.GRADE_COLOR["Grand"])
		else:
			var why := blocked if blocked != "" else "at Crownfall only"
			m._lbl(list, "%s   ·   %s" % [line, why], 12, Color(0.6, 0.6, 0.66))


static func _synth_cb(m: Menus, fs: String) -> Callable:
	return func() -> void:
		var g := m.game
		var p: Player = g.local_player
		var r := Professions.synthesize(p, fs)
		if not r["ok"]:
			open(m, String(r["reason"]), Color(1.0, 0.6, 0.5))
			return
		var item: Dictionary = r["item"]
		var banked := p.add_consumable(item)
		if not banked:
			g.send_mail("Your synthesised potion",
				"The alembic was ready but your bag was full — the Grand potion waits here.",
				[{"kind": "potion", "potion": item}])
		g.sfx("chest")
		p.recalc()
		g.autosave()
		var mailed := "" if banked else "   (mailed — bag was full)"
		open(m, "Synthesised %s.   (-%d gold)%s" % [String(item.get("name", "")), int(r["fee"]), mailed],
			Color(1.0, 0.92, 0.6))
