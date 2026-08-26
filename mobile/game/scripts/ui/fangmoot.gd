class_name UIFangmoot
## Fangmoot — the tavern autobattler, the Carver's Circle screen.
## PROPOSALS/FANGMOOT.md §13. A static UI module in the ui/ pattern
## (ui/wardrobe.gd, ui/daily.gd): everything is rebuilt from m.fm_moot on each
## action, so `open(m)` is both the entry point and the refresh.
##
## m.fm_moot holds the active moot (session-lived); m.fm_host is its seam to the
## game. The pure sim/moot/bot never touch the engine — this file is the bridge.

const TOPBAR_H := 62.0
const ARENA_H := 420.0
# tray band = 720 - TOPBAR_H - ARENA_H = 238

const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.62, 0.64, 0.72)
const INK := Color(0.9, 0.92, 0.98)
const BITE_COL := Color(1.0, 0.55, 0.42)   # attack
const HIDE_COL := Color(0.55, 0.85, 1.0)   # health
const WIN_COL := Color(0.55, 1.0, 0.6)
const LOSS_COL := Color(1.0, 0.5, 0.5)

const TRIBE_COLOR := {
	"wild":   Color(0.86, 0.66, 0.36),
	"hollow": Color(0.70, 0.74, 0.80),
	"choir":  Color(0.62, 0.82, 0.44),
	"molten": Color(0.98, 0.52, 0.30),
	"still":  Color(0.55, 0.82, 0.98),
	"root":   Color(0.50, 0.80, 0.52),
	"storm":  Color(0.72, 0.58, 0.98),
}

# The genre-standard rarity ladder (grey→green→blue→purple→gold), one hue per
# tier, plus a mythic gold for Named pieces. Applied REDUNDANTLY on a card
# (frame + gem + bg tint) so rarity reads at a glance — the autobattler-shop
# convention (Hearthstone / The Bazaar).
const RARITY := {
	1: Color(0.68, 0.70, 0.76),   # common  · grey
	2: Color(0.42, 0.82, 0.46),   # uncommon · green
	3: Color(0.30, 0.62, 0.98),   # rare    · blue
	4: Color(0.72, 0.42, 0.96),   # epic    · purple
	5: Color(1.00, 0.60, 0.20),   # legend  · orange
	6: Color(1.00, 0.83, 0.36),   # mythic  · gold (Named)
}


static func _rarity_of(ct: String, id: String) -> Color:
	if ct == "named":
		return RARITY[6]
	if ct == "token":
		return RARITY.get(clampi(FangmootData.tier_of(id), 1, 5), RARITY[1])
	if ct == "charm":
		return Color(0.45, 0.86, 0.86)   # gems read teal
	return Color(0.92, 0.66, 0.34)       # brews read amber

const TRIG_TEXT := {
	"muster": "On muster", "bite": "Before it strikes", "hurt": "When hurt",
	"fall": "When it falls", "slay": "On a kill", "ally_falls": "When an ally falls",
	"ally_hurt": "When an ally is hurt", "ally_ahead_bites": "When the ally ahead strikes",
	"turn_end": "Each turn · permanent",
}

const TABLES := [
	{"id": "copper", "name": "Copper Table", "blurb": "Learn the moot. Fisher Dov and Digger Haim play here."},
	{"id": "silver", "name": "Silver Table", "blurb": "The Circle's regulars — the Choir, the smiths, the herbalists."},
	{"id": "gold", "name": "Gold Table", "blurb": "The Sable Court's stakes. Fenna, Callis, and Tove herself."},
]


static func open(m: Menus) -> void:
	if m.fm_host == null:
		m.fm_host = FangmootHostCrownless.new(m.game)
	if m.fm_moot != null and m.fm_moot.done:
		_result(m)
	elif m.fm_moot != null:
		_moot(m)
	else:
		_hub(m)


# ==================================================================== hub
# The tables read as a metal ladder — copper → silver → gold — so each carries
# its own colour and gilding, like a difficulty select.
const TABLE_METAL := {
	"copper": Color(0.82, 0.52, 0.34),
	"silver": Color(0.80, 0.84, 0.90),
	"gold":   Color(1.0, 0.85, 0.4),
}

static func _hub(m: Menus) -> void:
	var root := m._open_full()
	m.current = "fangmoot"
	# atmospheric backdrop: the arena floor + ring + drifting motes of the Circle's
	# hall, no fighters — the hub shares the moot's world, not a panel on black.
	_hub_backdrop(m, root)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 64)
	pad.add_theme_constant_override("margin_right", 64)
	pad.add_theme_constant_override("margin_top", 44)
	pad.add_theme_constant_override("margin_bottom", 40)
	root.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	# header: big wordmark + the way out on the right
	var hrow := HBoxContainer.new()
	v.add_child(hrow)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", -4)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(tcol)
	var tl := m._lbl(tcol, "FANGMOOT", 40, GOLD)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	UITheme.title(tl, 40)
	m._lbl(tcol, "The Carver's Circle", 16, Color(INK, 0.9)).autowrap_mode = TextServer.AUTOWRAP_OFF
	if m.fm_standalone:
		m._btn(hrow, "Quit", func() -> void: m.get_tree().quit(), LOSS_COL).custom_minimum_size = Vector2(96, 40)
	else:
		m._btn(hrow, "Leave the Circle", func() -> void: m.close(), Color(0.8, 0.82, 0.9)).custom_minimum_size = Vector2(160, 40)
	# gold underline
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 2)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(GOLD, 0.5)
	rule.add_theme_stylebox_override("panel", rsb)
	v.add_child(rule)

	var intro := m._lbl(v, "Carver Tove keeps the callers' board. Buy tokens of the beasts you have faced, line five up, and call the moot. Ten crests wins; four scars ends it.", 14, Color(INK, 0.82))
	intro.custom_minimum_size = Vector2(900, 0)

	# collection progress — a real filled bar, not a bare number
	var total := FangmootData.TOKENS.size() + FangmootData.NAMED.size()
	var have := 0
	for k in FangmootData.TOKENS:
		if m.fm_host.fieldable(k):
			have += 1
	for k in FangmootData.NAMED:
		if m.fm_host.fieldable(k):
			have += 1
	_collection_bar(m, v, have, total)

	m._lbl(v, "CHOOSE A TABLE", 13, Color(GOLD, 0.7)).autowrap_mode = TextServer.AUTOWRAP_OFF
	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 18)
	tables.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tables)
	for i in TABLES.size():
		_table_card(m, tables, TABLES[i], i)

	m._hint(v, "Pick a table to begin" if m.fm_standalone else "Pick a table to begin  ·  ESC to leave the Circle")


# The hub's living backdrop: an empty arena (floor, ring, drifting motes) of the
# Circle's stone hall, dimmed by a scrim so the menu text reads over it.
static func _hub_backdrop(m: Menus, root: Control) -> void:
	var size := Vector2(1280, 720)
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vpc)
	var vp := SubViewport.new()
	vp.size = Vector2i(size)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	var bg := UIFangmootArena.new()
	vp.add_child(bg)
	bg.setup(m.fm_host, "holy", size)
	bg.set_bands([], [])
	var scrim := Panel.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.03, 0.035, 0.055, 0.58)
	scrim.add_theme_stylebox_override("panel", ssb)
	root.add_child(scrim)


static func _collection_bar(m: Menus, parent: Node, have: int, total: int) -> void:
	var pct := int(round(100.0 * have / maxf(1, total)))
	var card := UITheme.card(parent, GOLD, 10.0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var top := HBoxContainer.new()
	cv.add_child(top)
	var cl := m._lbl(top, "Your carvings", 14, GOLD)
	cl.autowrap_mode = TextServer.AUTOWRAP_OFF
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m._lbl(top, "%d / %d pieces  ·  %d%%" % [have, total, pct], 14, Color(INK, 0.9)).autowrap_mode = TextServer.AUTOWRAP_OFF
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.14, 0.95)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = GOLD
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	cv.add_child(bar)
	m._lbl(cv, "Face a beast in the world to carve its token.", 12, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF


static func _table_card(m: Menus, parent: Node, t: Dictionary, tier: int) -> void:
	var metal: Color = TABLE_METAL.get(String(t["id"]), GOLD)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.085, 0.12).lerp(metal, 0.05)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(metal, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	_gem(head, metal)
	var nm := m._lbl(head, String(t["name"]), 20, metal)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	UITheme.header(nm)
	var bl := m._lbl(col, String(t["blurb"]), 13, Color(INK, 0.78))
	bl.custom_minimum_size = Vector2(0, 0)
	# escalating stakes — copper one fang, silver two, gold three
	var stk := HBoxContainer.new()
	stk.add_theme_constant_override("separation", 6)
	col.add_child(stk)
	m._lbl(stk, "STAKES", 10, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF
	for p in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		var dsb := StyleBoxFlat.new()
		dsb.set_corner_radius_all(6)
		if p <= tier:
			dsb.bg_color = metal
			dsb.shadow_color = Color(metal.r, metal.g, metal.b, 0.5)
			dsb.shadow_size = 3
		else:
			dsb.bg_color = Color(0.16, 0.16, 0.20, 0.9)
			dsb.border_color = Color(metal, 0.35)
			dsb.set_border_width_all(1)
		dot.add_theme_stylebox_override("panel", dsb)
		stk.add_child(dot)
	# who you'll face at this table — previews the personas, fills the card
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	col.add_child(sep)
	m._lbl(col, "PLAYS HERE", 10, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF
	for cid in FangmootData.CALLERS:
		var caller: Dictionary = FangmootData.CALLERS[cid]
		if String(caller.get("table", "")) != String(t["id"]):
			continue
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 8)
		col.add_child(crow)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(metal, 0.85)
		dsb.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", dsb)
		var dwrap := CenterContainer.new()
		dwrap.custom_minimum_size = Vector2(12, 0)
		dwrap.add_child(dot)
		crow.add_child(dwrap)
		m._lbl(crow, String(caller.get("name", cid)), 12, Color(INK, 0.82)).autowrap_mode = TextServer.AUTOWRAP_OFF
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grow)
	var play := m._btn(col, "Call a moot", _start.bind(m, String(t["id"])), metal)
	play.custom_minimum_size = Vector2(0, 46)
	play.add_theme_font_size_override("font_size", 16)
	panel.mouse_entered.connect(_card_hover.bind(panel, sb, metal, true))
	panel.mouse_exited.connect(_card_hover.bind(panel, sb, metal, false))


# ================================================================== moot
static func _moot(m: Menus) -> void:
	var mo: FangmootMoot = m.fm_moot
	_ensure_opp(m)
	var root := m._open_full()
	m.current = "fangmoot"
	var arena := _mount_arena(m, root, mo.ground)
	arena.set_bands(mo.fight_band(), m.fm_opp)
	_full_topbar(m, root, mo, false)
	_tray_band(m, root, mo)
	_board_overlay(m, root, mo, arena)


# Mount the animated arena (ui/fangmoot_arena.gd) in a SubViewport filling the
# middle band. The container ignores the mouse so the board drop-zones on top of
# it stay hittable.
static func _mount_arena(m: Menus, root: Control, ground: String, height := ARENA_H) -> UIFangmootArena:
	var asize := Vector2(1280, height)
	var vpc := SubViewportContainer.new()
	vpc.position = Vector2(0, TOPBAR_H)
	vpc.size = asize
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vpc)
	var vp := SubViewport.new()
	vp.size = Vector2i(asize)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	var arena := UIFangmootArena.new()
	vp.add_child(arena)
	arena.setup(m.fm_host, ground, asize)
	return arena


# The opponent is fixed for the turn (so the preview you shop against is the one
# you fight); rebuilt only when the turn changes.
static func _ensure_opp(m: Menus) -> void:
	var mo: FangmootMoot = m.fm_moot
	if m.fm_opp_turn != mo.turn or m.fm_opp.is_empty():
		m.fm_opp = FangmootBot.build_warband(_persona(mo), mo.turn, mo.seed * 31 + mo.turn * 7 + 3, m.fm_host)
		m.fm_opp_turn = mo.turn


# ------------------------------------------------------------- top bar
static func _full_topbar(m: Menus, root: Control, mo: FangmootMoot, fighting: bool) -> void:
	var bar := Panel.new()
	bar.size = Vector2(1280, TOPBAR_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.98)
	sb.border_color = Color(GOLD, 0.32)
	sb.border_width_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(22, 8)
	row.size = Vector2(1236, TOPBAR_H - 14)
	row.add_theme_constant_override("separation", 26)
	bar.add_child(row)
	# title
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", -2)
	row.add_child(tcol)
	var tl := m._lbl(tcol, "FANGMOOT", 22, GOLD)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	UITheme.header(tl)
	var gname := String(FangmootData.GROUNDS.get(mo.ground, {}).get("name", mo.ground))
	m._lbl(tcol, "%s table · Turn %d · %s" % [mo.table.capitalize(), mo.turn, gname], 11, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF
	# crests + scars
	_pip_block(m, row, "CRESTS", int(Balance.FANGMOOT_CRESTS_WIN), mo.crests, GOLD)
	_pip_block(m, row, "SCARS", int(Balance.FANGMOOT_SCARS_OUT), mo.scars, LOSS_COL)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	# opponent — a framed round portrait beside the name (research: a metallic
	# ring portrait reads "finished" where a bare name reads "prototype")
	var opp := _persona(mo)
	var ocol := VBoxContainer.new()
	ocol.add_theme_constant_override("separation", -2)
	ocol.custom_minimum_size = Vector2(292, 0)
	ocol.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ocol)
	var onm := m._lbl(ocol, String(opp.get("name", "the caller")), 15, INK)
	onm.autowrap_mode = TextServer.AUTOWRAP_OFF
	onm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var q := m._lbl(ocol, "\"%s\"" % String(opp.get("voice", "")), 10, DIM)
	q.autowrap_mode = TextServer.AUTOWRAP_OFF
	q.clip_text = true
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_portrait_ring(row, String(opp.get("name", "?")), LOSS_COL)
	_badge(m, row, "%d fangs" % mo.fangs, GOLD)
	if fighting:
		m._btn(row, "%dx" % int(m.fm_speed), _cycle_speed.bind(m), INK).custom_minimum_size = Vector2(42, 30)
	m._btn(row, "Concede", _concede.bind(m), LOSS_COL).custom_minimum_size = Vector2(84, 30)


static func _pip_block(m: Menus, parent: Node, label: String, total: int, have: int, col: Color) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	parent.add_child(v)
	m._lbl(v, label, 9, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	for i in total:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(14, 14)
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(7)
		s.set_border_width_all(1)
		if i < have:
			# an earned crest reads as a struck coin: bright fill, lighter rim,
			# and a soft glow of its own colour (research: earned HUD icons glow)
			s.bg_color = col
			s.border_color = col.lightened(0.4)
			s.shadow_color = Color(col.r, col.g, col.b, 0.5)
			s.shadow_size = 4
		else:
			s.bg_color = Color(0.13, 0.13, 0.17, 0.9)
			s.border_color = Color(col, 0.35)
		p.add_theme_stylebox_override("panel", s)
		row.add_child(p)


static func _cycle_speed(m: Menus) -> void:
	m.fm_speed = 1.0 if m.fm_speed >= 2.0 else 2.0


# ---------------------------------------- board drop-zones (over the arena)
static func _board_overlay(m: Menus, root: Control, mo: FangmootMoot, arena: UIFangmootArena) -> void:
	# drop-zones are pinned to the arena's own slot positions (screen = arena-local
	# + the topbar offset), so they can never drift from where the tokens render.
	for i in mo.board.size():
		var lp: Vector2 = arena._slot_pos(0, i)
		_slot_zone(m, root, mo, i, Vector2(lp.x - 58, TOPBAR_H + lp.y - 80), Vector2(116, 150))

static func _slot_zone(m: Menus, root: Control, mo: FangmootMoot, i: int, pos: Vector2, size: Vector2) -> void:
	var z := Control.new()
	z.position = pos
	z.size = size
	z.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(z)
	var slot = mo.board[i]
	var can_fn := func(_p: Vector2, data: Variant) -> bool:
		return _slot_can(m, i, data)
	var drop_fn := func(_p: Vector2, data: Variant) -> void:
		_slot_drop(m, i, data)
	if slot != null:
		z.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		z.tooltip_text = "%s — drag to reorder or to the Sell bowl" % String(FangmootData.row(String(slot["kind"])).get("name", ""))
		var drag_fn := func(_p: Vector2) -> Variant:
			z.set_drag_preview(m._drag_preview(m.fm_host.portrait(String(mo.board[i]["kind"]))))
			return {"fm": "board", "idx": i}
		z.set_drag_forwarding(drag_fn, can_fn, drop_fn)
	else:
		z.set_drag_forwarding(Callable(), can_fn, drop_fn)


# -------------------------------------------------------------- the tray
static func _tray_band(m: Menus, root: Control, mo: FangmootMoot) -> void:
	var top := TOPBAR_H + ARENA_H
	var band := Panel.new()
	band.position = Vector2(0, top)
	band.size = Vector2(1280, 720 - top)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.085, 0.99)
	sb.border_color = Color(GOLD, 0.28)
	sb.border_width_top = 2
	band.add_theme_stylebox_override("panel", sb)
	root.add_child(band)
	# header
	var hdr := HBoxContainer.new()
	hdr.position = Vector2(20, 6)
	hdr.add_theme_constant_override("separation", 12)
	band.add_child(hdr)
	m._lbl(hdr, "THE CARVER'S TRAY", 12, GOLD).autowrap_mode = TextServer.AUTOWRAP_OFF
	m._lbl(hdr, "click a card to buy · drag onto a slot to place · a Named piece may appear from turn %d" % int(Balance.FANGMOOT_NAMED_TURN), 10, DIM).autowrap_mode = TextServer.AUTOWRAP_OFF
	# the cards, in a scroll that leaves the right column for the controls
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 28)
	scroll.size = Vector2(1024, band.size.y - 34)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	band.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	for i in mo.tray.size():
		_tray_card(m, row, mo, i)
	# right controls: Roll · Sell bowl · CALL THE MOOT (a clean vertical stack)
	var roll := m._btn(band, "Reroll  (%d fang)" % int(Balance.FANGMOOT_COST_ROLL), _roll.bind(m), INK, mo.fangs >= int(Balance.FANGMOOT_COST_ROLL))
	roll.position = Vector2(1058, 32)
	roll.size = Vector2(202, 34)
	roll.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_zone(m, band, mo, Vector2(1058, 72), Vector2(202, 34))
	var call := m._btn(band, "CALL THE MOOT", _call.bind(m), GOLD, mo.board_count() > 0)
	call.position = Vector2(1058, 114)
	call.size = Vector2(202, 100)
	call.alignment = HORIZONTAL_ALIGNMENT_CENTER
	call.add_theme_font_size_override("font_size", 20)


static func _sell_zone(m: Menus, parent: Node, mo: FangmootMoot, pos: Vector2, size: Vector2) -> void:
	var z := Panel.new()
	z.position = pos
	z.size = size
	z.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.09, 0.07, 0.85)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.75, 0.45, 0.35, 0.6)
	z.add_theme_stylebox_override("panel", sb)
	z.tooltip_text = "Drag a warband token here to sell it"
	parent.add_child(z)
	var l := Label.new()
	l.text = "Sell bowl"
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.88, 0.62, 0.52))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(l)
	var can_fn := func(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and String(data.get("fm", "")) == "board"
	var drop_fn := func(_p: Vector2, data: Variant) -> void:
		mo.sell(int(data.get("idx", 0)))
		open(m)
	z.set_drag_forwarding(Callable(), can_fn, drop_fn)


static func _tray_card(m: Menus, parent: Node, mo: FangmootMoot, idx: int) -> void:
	var card := mo.tray[idx] as Dictionary
	var ct := String(card["ctype"])
	var id := String(card["id"])
	var held := bool(card.get("frozen", false))
	var rare := _rarity_of(ct, id)
	var named := ct == "named"
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(168, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.process_mode = Node.PROCESS_MODE_ALWAYS   # so the hover tween runs under the menu pause
	# frame: dark body tinted a touch toward its rarity, rounded, rarity-tinted
	# border, and a real drop shadow — the depth cue that reads "card", not "box"
	# (§39e; autobattler shop convention).
	var sb := StyleBoxFlat.new()
	var body := Color(0.09, 0.095, 0.13).lerp(rare, 0.06)
	if held:
		body = body.lerp(Color(0.14, 0.20, 0.28), 0.5)
	sb.bg_color = body
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3 if named else 2)
	sb.border_color = Color(rare, 0.95 if named else 0.85)
	sb.shadow_color = Color(rare.r, rare.g, rare.b, 0.30) if named else Color(0, 0, 0, 0.55)
	sb.shadow_size = 7 if named else 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var cost := 0
	match ct:
		"named": cost = int(Balance.FANGMOOT_COST_NAMED)
		"token": cost = int(Balance.FANGMOOT_COST_TOKEN)
		"charm": cost = int(Balance.FANGMOOT_COST_CHARM)
		"brew": cost = int(Balance.FANGMOOT_COST_BREW)

	# top strip: a rarity gem + the type/rarity word, edge to edge (§39i)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(head)
	_gem(head, rare)
	var kind_txt := ""
	if named: kind_txt = "NAMED"
	elif ct == "token": kind_txt = "TIER %d" % FangmootData.tier_of(id)
	elif ct == "charm": kind_txt = "CHARM"
	else: kind_txt = "BREW"
	var klbl := m._lbl(head, kind_txt, 9, Color(rare, 0.95))
	klbl.autowrap_mode = TextServer.AUTOWRAP_OFF   # else the HBox collapses it to one char per line
	klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if ct == "token" or ct == "named":
		_sprite(m, v, id, 64)
		var nm := m._lbl(v, String(FangmootData.row(id).get("name", id)), 13, GOLD if named else INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(150, 0)
		var tribe := FangmootData.tribe_of(id)
		var tlbl := m._lbl(v, tribe.capitalize(), 10, Color(TRIBE_COLOR.get(tribe, DIM), 0.85))
		tlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var st := FangmootData.base_stats(id)
		_statline(m, v, st.x, st.y, 15)
		var ab: Dictionary = FangmootData.row(id).get("ability", {})
		if not ab.is_empty():
			var abl := m._lbl(v, String(ab.get("name", "")), 11, Color(0.82, 0.84, 0.9))
			abl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			abl.custom_minimum_size = Vector2(150, 0)
	else:
		var data: Dictionary = FangmootData.CHARMS.get(id, FangmootData.BREWS.get(id, {}))
		var nm2 := m._lbl(v, String(data.get("name", id)), 15, INK)
		nm2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm2.custom_minimum_size = Vector2(156, 0)
		var d := m._lbl(v, String(data.get("desc", "")), 12, Color(0.78, 0.8, 0.86))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size = Vector2(156, 0)

	# a full card, controls at the foot
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	_badge(m, foot, "%d fangs" % cost, GOLD)
	var frz := m._btn(foot, "Held" if held else "Hold", _freeze.bind(m, idx), Color(0.6, 0.82, 1.0) if held else Color(0.55, 0.6, 0.7))
	frz.custom_minimum_size = Vector2(48, 26)

	# is this card buyable right now? (fangs, board room, one-Named rule)
	var buyable := mo.fangs >= cost
	if ct == "token" or ct == "named":
		buyable = buyable and (_has_empty(mo) or _has_copy(mo, id))
		if ct == "named" and mo._has_named() and not _has_copy(mo, id):
			buyable = false
	else:
		buyable = buyable and mo.board_count() > 0

	# click the card to quick-buy · drag it onto a slot to place precisely (§39m)
	_ignore_mouse(v)
	frz.mouse_filter = Control.MOUSE_FILTER_STOP
	if buyable:
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_quick_buy(m, idx))
		var drag_fn := func(_pos: Vector2) -> Variant:
			panel.set_drag_preview(_drag_preview_for(m, ct, id))
			return {"fm": "tray", "idx": idx, "ct": ct, "kind": id}
		panel.set_drag_forwarding(drag_fn, Callable(), Callable())
		# hover-raise: the card lifts and its frame brightens under the cursor —
		# the "clickable vs premium" cue every autobattler shop uses.
		panel.mouse_entered.connect(_card_hover.bind(panel, sb, rare, true))
		panel.mouse_exited.connect(_card_hover.bind(panel, sb, rare, false))
	else:
		panel.modulate = Color(0.6, 0.6, 0.64)


# Lift + frame-brighten a shop card on hover (see _tray_card).
static func _card_hover(panel: PanelContainer, sb: StyleBoxFlat, rare: Color, on: bool) -> void:
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	sb.border_color = rare.lightened(0.35) if on else Color(rare, 0.9)
	sb.shadow_size = 11 if on else 5
	var tw := panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.10)


# =============================================================== actions
static func _start(m: Menus, table: String) -> void:
	m.fm_moot = FangmootMoot.new(table, int(Time.get_ticks_usec() & 0x7fffffff), m.fm_host)
	m.fm_moot.begin_turn()
	open(m)

# Click a tray card: buy into the sensible slot (bond a copy, else first empty;
# a charm/brew lands on the front token, or all for the Carver's Meal).
static func _quick_buy(m: Menus, idx: int) -> void:
	var mo: FangmootMoot = m.fm_moot
	if idx < 0 or idx >= mo.tray.size():
		return
	var ct := String(mo.tray[idx]["ctype"])
	var id := String(mo.tray[idx]["id"])
	match ct:
		"token", "named":
			var slot := _copy_slot(mo, id)
			if slot < 0:
				slot = _empty_slot(mo)
			if slot >= 0:
				mo.buy_token(idx, slot)
		"charm":
			var s := _front_board_slot(mo)
			if s >= 0:
				mo.buy_charm(idx, s)
		"brew":
			if id == "carvers_meal":
				mo.buy_brew(idx, -1)
			else:
				var s := _front_board_slot(mo)
				if s >= 0:
					mo.buy_brew(idx, s)
	open(m)

# Can `data` be dropped onto board slot `i`?
static func _slot_can(m: Menus, i: int, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var mo: FangmootMoot = m.fm_moot
	var src := String(data.get("fm", ""))
	if src == "board":
		return int(data.get("idx", -1)) != i
	if src == "tray":
		var idx := int(data.get("idx", -1))
		if idx < 0 or idx >= mo.tray.size() or not mo.can_buy(idx):
			return false
		var ct := String(data.get("ct", ""))
		var slot = mo.board[i]
		match ct:
			"token", "named":
				if ct == "named" and mo._has_named() and (slot == null or String(slot["kind"]) != String(data.get("kind", ""))):
					return false
				return slot == null or String(slot["kind"]) == String(data.get("kind", ""))
			"charm":
				return slot != null
			"brew":
				var brew: Dictionary = FangmootData.BREWS.get(String(data.get("kind", "")), {})
				if String(brew.get("effect", {}).get("scope", "one")) == "all":
					return mo.board_count() > 0
				return slot != null
	return false

# Resolve a drop onto board slot `i`.
static func _slot_drop(m: Menus, i: int, data: Variant) -> void:
	var mo: FangmootMoot = m.fm_moot
	var src := String(data.get("fm", ""))
	if src == "board":
		mo.move(int(data.get("idx", 0)), i)
	elif src == "tray":
		var idx := int(data.get("idx", 0))
		match String(data.get("ct", "")):
			"token", "named": mo.buy_token(idx, i)
			"charm": mo.buy_charm(idx, i)
			"brew": mo.buy_brew(idx, i)
	open(m)

static func _roll(m: Menus) -> void:
	m.fm_moot.roll()
	open(m)

static func _freeze(m: Menus, idx: int) -> void:
	m.fm_moot.toggle_freeze(idx)
	open(m)

static func _concede(m: Menus) -> void:
	m.fm_moot.scars = int(Balance.FANGMOOT_SCARS_OUT)
	m.fm_moot.done = true
	m.fm_moot.outcome = "loss"
	open(m)

static func _call(m: Menus) -> void:
	var mo: FangmootMoot = m.fm_moot
	if mo.board_count() == 0:
		return
	_ensure_opp(m)
	mo.call_moot(m.fm_opp)
	m.fm_opp_turn = -1   # a fresh caller next turn
	_fight_view(m)


# --------------------------------------------------------- opponent pick
static func _persona(mo: FangmootMoot) -> Dictionary:
	var pool: Array = []
	for id in FangmootData.CALLERS:
		if String(FangmootData.CALLERS[id]["table"]) == mo.table:
			pool.append(FangmootData.CALLERS[id])
	if pool.is_empty():
		pool = FangmootData.CALLERS.values()
	var idx := (mo.turn * 2654435761) % pool.size()
	return pool[idx]


# ============================================================ the fight
# The same full-screen view; the moot is called, the arena plays the fight log,
# and Continue advances to the next shop turn (or the result).
static func _fight_view(m: Menus) -> void:
	var mo: FangmootMoot = m.fm_moot
	var root := m._open_full()
	m.current = "fangmoot"
	# during the fight the arena takes the whole screen below the top bar — the
	# game fills the frame, no dead band (§39h). A slim result bar overlays the foot.
	const BAR_H := 72.0
	var ah := 720.0 - TOPBAR_H
	var arena := _mount_arena(m, root, mo.ground, ah)
	arena.set_bands(mo.last_band, mo.last_opp)
	_full_topbar(m, root, mo, true)
	var band := Panel.new()
	band.position = Vector2(0, 720 - BAR_H)
	band.size = Vector2(1280, BAR_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.08, 0.86)
	sb.border_color = Color(GOLD, 0.30)
	sb.border_width_top = 2
	band.add_theme_stylebox_override("panel", sb)
	root.add_child(band)
	var banner := Label.new()
	banner.text = "the tokens fight it out…"
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", Color(GOLD, 0.85))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.position = Vector2(300, 0)
	banner.size = Vector2(680, BAR_H)
	band.add_child(banner)
	var cont := m._btn(band, "Continue", func() -> void: open(m), GOLD)
	cont.size = Vector2(168, 44)
	cont.position = Vector2(1080, (BAR_H - 44) * 0.5)
	cont.add_theme_font_size_override("font_size", 17)
	cont.visible = false
	arena.finished.connect(_arena_done.bind(banner, cont, mo.last_result))
	arena.play(mo.last_log, m.fm_speed)


static func _arena_done(banner: Label, cont: Button, result: String) -> void:
	if is_instance_valid(banner):
		if result == "a":
			banner.text = "You win the round — a crest."
			banner.add_theme_color_override("font_color", WIN_COL)
		elif result == "b":
			banner.text = "The caller takes the round — a scar."
			banner.add_theme_color_override("font_color", LOSS_COL)
		else:
			banner.text = "A draw. Neither mark is made."
	if is_instance_valid(cont):
		cont.visible = true


# ================================================================ result
static func _result(m: Menus) -> void:
	var mo: FangmootMoot = m.fm_moot
	# grant the reward once
	if not mo.rewarded:
		mo.rewarded = true
		_grant_reward(m, mo)
	var vbox := m._open("The Moot Is Called", 720, 520, true)
	m.current = "fangmoot"
	vbox.add_theme_constant_override("separation", 12)

	var won := mo.outcome == "win"
	var head := m._lbl(vbox, "You won the moot" if won else "The moot ends", 26, WIN_COL if won else LOSS_COL)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(head, 26)

	var summary := m._lbl(vbox, "%d crests · %d scars · %d turns on %s" % [
		mo.crests, mo.scars, mo.turn - 1, String(FangmootData.GROUNDS.get(mo.ground, {}).get("name", mo.ground))], 14, INK)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var card := UITheme.card(vbox, GOLD, 12.0)
	var msg := "Carver Tove nods. \"You called that well.\"" if won else "Carver Tove gathers the tokens. \"Come back and try again.\""
	m._lbl(card, msg, 14, DIM).custom_minimum_size = Vector2(660, 0)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	vbox.add_child(bar)
	m._btn(bar, "  Play again  ", func() -> void:
		var t := mo.table
		m.fm_moot = null
		_start(m, t), GOLD).custom_minimum_size = Vector2(160, 46)
	m._btn(bar, "  Back to the Circle  ", func() -> void:
		m.fm_moot = null
		open(m), INK).custom_minimum_size = Vector2(180, 46)

	m._hint(vbox, "ESC or ✕ to leave")


static func _grant_reward(m: Menus, mo: FangmootMoot) -> void:
	if mo.outcome != "win":
		return
	# one-time table-first bonus, tracked in the persisted fangmoot state
	var st := m.fm_host.load_state()
	var won_tables: Array = st.get("tables_won", [])
	if not (mo.table in won_tables):
		won_tables.append(mo.table)
		st["tables_won"] = won_tables
		m.fm_host.save_state(st)
		var first: Dictionary = Balance.RENOWN_FANGMOOT_TABLE_FIRST
		m.fm_host.reward("renown", int(first.get(mo.table, 10)))


# ================================================================ shared
static func _sprite(m: Menus, parent: Node, kind: String, px: int) -> void:
	var tr := TextureRect.new()
	tr.texture = m.fm_host.portrait(kind)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(tr)

# BITE / HIDE as the codex's label-over-value stat tiles (one component per
# number, §39n) — attack orange, health blue, no glyphs. Returns the HIDE value
# label so the arena can tick it down during the replay.
static func _statline(m: Menus, parent: Node, bite: int, hide: int, val_size := 17) -> Label:
	var g := HBoxContainer.new()
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	g.add_theme_constant_override("separation", 20)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(g)
	_stat_tile(m, g, "BITE", bite, BITE_COL, val_size)
	return _stat_tile(m, g, "HIDE", hide, HIDE_COL, val_size)

static func _stat_tile(m: Menus, parent: Node, label: String, value: int, col: Color, val_size: int) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	parent.add_child(v)
	var lbl := m._lbl(v, label, 9, Color(col, 0.55))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var val := m._lbl(v, str(value), val_size, col)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	return val

# A small rounded marker (level / charm) sharing the chip visual language (§39e).
static func _badge(m: Menus, parent: Node, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	l.add_theme_stylebox_override("normal", sb)
	parent.add_child(l)

## A framed round opponent portrait: a metallic ring around a tinted disc that
## carries the caller's initial. Cheap "finished" cue for the top bar.
static func _portrait_ring(parent: Node, name: String, tint: Color) -> void:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(40, 40)
	var ring := Panel.new()
	ring.custom_minimum_size = Vector2(38, 38)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.10, 0.12).lerp(tint, 0.25)
	s.set_corner_radius_all(19)
	s.set_border_width_all(2)
	s.border_color = GOLD                  # the metallic ring
	s.shadow_color = Color(tint.r, tint.g, tint.b, 0.35)
	s.shadow_size = 5
	ring.add_theme_stylebox_override("panel", s)
	var initial := Label.new()
	initial.text = name.substr(0, 1).to_upper()
	initial.add_theme_font_size_override("font_size", 18)
	initial.add_theme_color_override("font_color", Color(GOLD, 0.95))
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(initial)
	wrap.add_child(ring)
	parent.add_child(wrap)

## A small glowing rarity gem — the redundant rarity cue beside a card's kind label.
static func _gem(parent: Node, col: Color) -> void:
	var g := Panel.new()
	g.custom_minimum_size = Vector2(9, 9)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(5)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.5)
	sb.shadow_size = 4
	g.add_theme_stylebox_override("panel", sb)
	parent.add_child(g)

static func _ability_text(ab: Dictionary) -> String:
	return String(TRIG_TEXT.get(String(ab.get("trig", "")), ""))

# Make a card's inner content transparent to the mouse so the card panel itself
# receives the click/drag (the interactive button re-enables itself after).
static func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)

static func _drag_preview_for(m: Menus, ct: String, id: String) -> Control:
	if ct == "token" or ct == "named":
		return m._drag_preview(m.fm_host.portrait(id))
	var data: Dictionary = FangmootData.CHARMS.get(id, FangmootData.BREWS.get(id, {}))
	var l := Label.new()
	l.text = String(data.get("name", id))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GOLD)
	return l

static func _front_board_slot(mo: FangmootMoot) -> int:
	for i in mo.board.size():
		if mo.board[i] != null:
			return i
	return -1

static func _has_empty(mo: FangmootMoot) -> bool:
	return _empty_slot(mo) >= 0

static func _empty_slot(mo: FangmootMoot) -> int:
	for i in mo.board.size():
		if mo.board[i] == null:
			return i
	return -1

static func _has_copy(mo: FangmootMoot, kind: String) -> bool:
	return _copy_slot(mo, kind) >= 0

static func _copy_slot(mo: FangmootMoot, kind: String) -> int:
	for i in mo.board.size():
		if mo.board[i] != null and String(mo.board[i]["kind"]) == kind:
			return i
	return -1
