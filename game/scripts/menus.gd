class_name Menus extends CanvasLayer
## All full-screen menus: class select, inventory, skill tree, merchant
## shop, evolution choice, and keybinding. One menu open at a time;
## opening a menu pauses the game.

var game: Node2D
var root: Control = null          # the currently open panel (null = closed)
var current := ""
var listening_action := ""        # keybind screen: waiting for a key press
var shop_zone := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


func is_open() -> bool:
	return root != null


func close() -> void:
	if root:
		root.queue_free()
		root = null
	listening_action = ""
	if current != "class_select":  # class select unpauses only after choosing
		get_tree().paused = false
	current = ""


# ------------------------------------------------------------ scaffolding ---

func _open(title: String, w := 960.0, h := 560.0) -> VBoxContainer:
	if root:
		root.queue_free()
	get_tree().paused = true
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var frame := ColorRect.new()
	frame.color = Color(0.9, 0.8, 0.5)
	frame.position = Vector2(640 - w / 2 - 3, 360 - h / 2 - 3)
	frame.size = Vector2(w + 6, h + 6)
	root.add_child(frame)
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.08, 0.13, 0.98)
	panel.position = Vector2(640 - w / 2, 360 - h / 2)
	panel.size = Vector2(w, h)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = panel.position + Vector2(24, 16)
	vbox.size = Vector2(w - 48, h - 32)
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 26)
	tl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vbox.add_child(tl)
	return vbox


func _lbl(parent: Node, text: String, size := 15, color := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable, color := Color(1, 1, 1), enabled := true, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if icon:
		b.icon = icon
	if enabled:
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Row with a gear icon + colored text (for non-clickable item displays).
func _item_row(parent: Node, item: Dictionary, text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var icon := TextureRect.new()
	icon.texture = Art.icon_for(item)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	var l := _lbl(hbox, text, 14, Items.GRADE_COLOR[item["grade"]])
	# Wrapping labels inside an HBox collapse without a minimum width.
	l.custom_minimum_size = Vector2(320, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Hover tooltip comparing an item against what's equipped in its slot.
func _diff_tip(item: Dictionary) -> String:
	return Items.diff_text(item, game.player.equipment.get(item["slot"]))


func _hint(vbox: Node, text := "ESC to close") -> void:
	var l := _lbl(vbox, text, 13, Color(0.55, 0.55, 0.55))
	l.size_flags_vertical = Control.SIZE_SHRINK_END


# ------------------------------------------------------------ class select ---

func open_class_select() -> void:
	var vbox := _open("Choose your class", 1180, 620)
	current = "class_select"
	_lbl(vbox, "This choice defines your four abilities and your three THEMES — elemental playstyles that change how your abilities behave, unlocked as you level.", 15, Color(0.75, 0.75, 0.75))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var idx := 1
	for id in Classes.CLASSES:
		var c: Dictionary = Classes.CLASSES[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(272, 0)
		col.add_theme_constant_override("separation", 6)
		hbox.add_child(col)

		var icon := TextureRect.new()
		icon.texture = Art.tex(c["sprite"])
		icon.custom_minimum_size = Vector2(96, 96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		col.add_child(icon)

		_lbl(col, c["name"], 20, Color(0.95, 0.85, 0.5))
		_lbl(col, c["desc"], 13, Color(0.8, 0.8, 0.8))
		if c.has("passive"):
			_lbl(col, "★ " + c["passive"]["text"], 12, Color(0.5, 0.95, 0.8))
		var theme_names: Array = []
		for theme in Classes.THEMES[id]:
			theme_names.append(theme["name"])
		_lbl(col, "Themes: " + " / ".join(theme_names), 12, Color(0.7, 0.8, 0.95))
		for slot in ["a1", "a2", "a3", "ult"]:
			var ab: Dictionary = c["abilities"][slot]
			var tag: String = "ULT" if slot == "ult" else slot.to_upper()
			_lbl(col, "%s %s — %s" % [tag, ab["name"], ab["desc"]], 12, Color(0.65, 0.7, 0.8))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		_btn(col, "  Choose %s  (%d)" % [c["name"], idx], func() -> void: pick_class(id), Color(0.6, 1.0, 0.6))
		idx += 1


func pick_class(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.on_class_chosen(id)


# --------------------------------------------------------------- inventory ---

func open_inventory() -> void:
	var vbox := _open("Inventory — %d gold" % game.player.gold, 1120, 640)
	current = "inventory"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	left.add_theme_constant_override("separation", 6)
	hbox.add_child(left)
	_lbl(left, "EQUIPPED", 16, Color(0.95, 0.85, 0.5))
	_lbl(left, "(click an item to manage its gem sockets)", 12, Color(0.55, 0.55, 0.6))
	for slot in Items.SLOTS:
		if game.player.equipment.has(slot):
			var item: Dictionary = game.player.equipment[slot]
			var open_cb := func() -> void:
				open_item_panel(item)
			# Title on a fixed-width clipped button; stats wrap in a label
			# below it — long S-item text can no longer blow up the layout.
			var b := _btn(left, Items.title(item), open_cb, Items.GRADE_COLOR[item["grade"]], true, Art.icon_for(item))
			b.custom_minimum_size = Vector2(430, 0)
			b.clip_text = true
			b.tooltip_text = Items.describe(item) + "\n\nClick to view sockets and remove/insert gems"
			var dl := _lbl(left, Items.describe(item), 12, Color(Items.GRADE_COLOR[item["grade"]], 0.8))
			dl.custom_minimum_size = Vector2(430, 0)
		else:
			_lbl(left, "     %s — empty" % slot.capitalize(), 14, Color(0.45, 0.45, 0.45))
	_lbl(left, "YOUR STATS", 16, Color(0.95, 0.85, 0.5))
	_lbl(left, game.player.stat_sheet(), 13, Color(0.75, 0.78, 0.85))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)
	_lbl(right, "BACKPACK (%d/%d) — click an item to equip it" % [game.player.backpack.size(), Player.BACKPACK_MAX], 16, Color(0.95, 0.85, 0.5))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in game.player.backpack:
		var it: Dictionary = item
		var equip_cb := func() -> void:
			game.player.equip(it)
			open_inventory()  # refresh
		var b := _btn(list, "%s  %s" % [Items.title(it), Items.describe(it)],
			equip_cb, Items.GRADE_COLOR[it["grade"]], true, Art.icon_for(it))
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Items.describe(it) + "\n\nEQUIP — diff:\n" + _diff_tip(it)

	# ------------------------------------------------------------- gems ---
	_lbl(right, "GEM BAG (%d) — click an EQUIPPED item on the left to socket them" % game.player.gem_bag.size(), 15, Color(0.95, 0.85, 0.5))
	if game.player.gem_bag.is_empty():
		_lbl(right, "No loose gems. They drop from chests.", 12, Color(0.5, 0.5, 0.55))
	else:
		for key in _gem_groups():
			var group: Dictionary = _gem_groups()[key]
			var g: Dictionary = group["gem"]
			var count: int = group["count"]
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			right.add_child(line)
			var gl := _lbl(line, "%s  x%d" % [Items.gem_title(g), count], 13, Items.gem_color(g))
			# Wrapping labels inside an HBox collapse without a minimum width.
			gl.custom_minimum_size = Vector2(280, 0)
			if count >= 3 and g["lvl"] < Items.GEM_MAX_LEVEL:
				var synth_cb := func() -> void:
					game.player.synthesize(g["stat"], g["lvl"])
					open_inventory()
				_btn(line, "⚒ synthesize 3 → Lv%d" % (g["lvl"] + 1), synth_cb, Color(0.6, 0.9, 1.0))
	_hint(vbox, "ESC / I to close")


## Bag gems grouped by stat+level: key -> {gem, count}.
func _gem_groups() -> Dictionary:
	var groups := {}
	for gem in game.player.gem_bag:
		var key := "%s_%d" % [gem["stat"], gem["lvl"]]
		if not groups.has(key):
			groups[key] = {"gem": gem, "count": 0}
		groups[key]["count"] += 1
	return groups


## Item detail: full stats + per-socket gem management.
func open_item_panel(item: Dictionary) -> void:
	var p: Player = game.player
	var vbox := _open(Items.title(item), 900, 620)
	current = "item_panel"

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vbox.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Art.icon_for(item)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var d := _lbl(head, Items.describe(item), 14, Items.GRADE_COLOR[item["grade"]])
	d.custom_minimum_size = Vector2(760, 0)

	var slots: int = item.get("gem_slots", 0)
	var gems: Array = item.get("gems", [])
	_lbl(vbox, "GEM SOCKETS (%d/%d filled)" % [gems.size(), slots], 16, Color(0.95, 0.85, 0.5))
	if slots == 0:
		_lbl(vbox, "This item has no sockets — only B-grade gear and above can hold gems.", 13, Color(0.55, 0.55, 0.6))
	for i in slots:
		if i < gems.size():
			var g: Dictionary = gems[i]
			var idx := i
			var rm_cb := func() -> void:
				game.player.remove_gem(item, idx)
				open_item_panel(item)
			_btn(vbox, "Socket %d:  %s    — click to REMOVE (back to bag)" % [i + 1, Items.gem_title(g)],
				rm_cb, Items.gem_color(g))
		else:
			_lbl(vbox, "Socket %d:  (empty)" % (i + 1), 13, Color(0.55, 0.55, 0.6))

	if slots > gems.size():
		if p.gem_bag.is_empty():
			_lbl(vbox, "No gems in your bag to insert (they drop from chests).", 12, Color(0.5, 0.5, 0.55))
		else:
			_lbl(vbox, "INSERT FROM BAG:", 15, Color(0.95, 0.85, 0.5))
			for key in _gem_groups():
				var group: Dictionary = _gem_groups()[key]
				var g2: Dictionary = group["gem"]
				var ins_cb := func() -> void:
					game.player.embed_gem_into(item, g2)
					open_item_panel(item)
				_btn(vbox, "%s  x%d — insert" % [Items.gem_title(g2), group["count"]], ins_cb, Items.gem_color(g2))
	_hint(vbox, "ESC to go back to inventory")


# -------------------------------------------------------------- skill tree ---

## Which glyph represents a skill cell's effect.
func _cell_glyph(cell: Dictionary) -> String:
	if cell.has("amod"):
		for slot in cell["amod"]:
			if cell["amod"][slot].has("cd"):
				return "ic_cd"
		return "ab_slash"
	var bonus: Dictionary = cell.get("bonus", {})
	for stat in bonus:
		match stat:
			"crit", "crit_dmg": return "ic_crit"
			"hp_pct", "hp_flat": return "ic_hp"
			"mp_flat", "lifesteal": return "ic_mp"
			"speed_pct": return "ab_roll"
			"physres", "magres", "critres": return "ab_shield"
			"physpen", "magpen": return "ic_pen"
			"combo": return "ic_combo"
			"eva": return "ab_blink"
			"dex": return "ic_eye"
			"greed": return "ic_coin"
			"atk_pct": return "ab_slash"
	return "ic_crit"

func open_skills() -> void:
	var p: Player = game.player
	var vbox := _open("%s Skill Tree — %d point%s available" % [Classes.CLASSES[p.cls]["name"], p.skill_points, "" if p.skill_points == 1 else "s"], 1120, 640)
	current = "skills"
	_lbl(vbox, "Rows unlock as you level. Spend up to %d points per row, spread across its 3 columns (max %d per skill). Each column follows one of your themes." % [Skills.MAX_PER_ROW, Skills.MAX_PER_CELL], 13, Color(0.6, 0.62, 0.68))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Column headers = the class themes.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	list.add_child(head)
	var pad := _lbl(head, "", 13)
	pad.custom_minimum_size = Vector2(120, 0)
	for theme in Classes.THEMES[p.cls]:
		var h := _lbl(head, theme["name"].to_upper(), 15, theme["color"])
		h.custom_minimum_size = Vector2(288, 0)

	for r in Skills.TREES[p.cls].size():
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)
		list.add_child(row_box)
		var unlocked: bool = p.level >= Skills.ROW_LEVELS[r]
		var spent := Skills.points_in_row(p.cls, r, p.tree_points)
		var row_l := _lbl(row_box, "Lv.%d\n%d/%d pts" % [Skills.ROW_LEVELS[r], spent, Skills.MAX_PER_ROW], 13,
			Color(0.95, 0.85, 0.5) if unlocked else Color(0.4, 0.4, 0.45))
		row_l.custom_minimum_size = Vector2(120, 0)
		var col_idx := 0
		for cell in Skills.TREES[p.cls][r]:
			var cd: Dictionary = cell
			var theme_col: Color = Classes.THEMES[p.cls][col_idx]["color"]
			col_idx += 1
			var pts: int = p.tree_points.get(cd["id"], 0)
			var can: bool = p.skill_points > 0 and Skills.can_add(p.cls, cd["id"], p.tree_points, p.level)
			var color := Color(0.5, 1.0, 0.5) if pts > 0 else (Color(1, 1, 1) if can else Color(0.45, 0.45, 0.45))
			var add_cb := func() -> void:
				if game.player.add_tree_point(cd["id"]):
					open_skills()
			var b := _btn(row_box, "%s  [%d/%d]\n%s" % [cd["name"], pts, Skills.MAX_PER_CELL, cd["desc"]],
				add_cb, color, can or pts > 0,
				Art.glyph_tex(_cell_glyph(cd), theme_col if unlocked else Color(0.4, 0.4, 0.45)))
			b.custom_minimum_size = Vector2(288, 0)
			if not can:
				b.disabled = true

	# ------------------------------------------------- theme assignment ---
	var next_note := "" if p.themes_known >= 3 else " — next unlocks at Lv %d" % Classes.THEME_LEVELS[mini(p.themes_known, 2)]
	_lbl(vbox, "ABILITY VARIANTS — click an ability to choose its theme (%d/3 unlocked%s)" % [p.themes_known, next_note], 15, Color(0.95, 0.85, 0.5))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	vbox.add_child(trow)
	for slot in ["a1", "a2", "a3", "ult"]:
		var s: String = slot
		var theme := Classes.theme_by_id(p.cls, p.ability_theme.get(s, ""))
		var label: String = theme.get("name", "Base")
		var tcolor: Color = theme.get("color", Color(0.75, 0.75, 0.8))
		var pick_cb := func() -> void:
			open_theme_picker(s)
		_btn(trow, "%s: %s ▾" % [Classes.ability(p.cls, s)["name"], label], pick_cb,
			tcolor, p.themes_known > 0, Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][s], tcolor))
	_hint(vbox, "ESC / T to close — themes change how your abilities behave")


## Dedicated variant chooser: shows the base ability and every theme
## variant with its icon and exactly what it changes.
func open_theme_picker(slot: String) -> void:
	var p: Player = game.player
	var ab := Classes.ability(p.cls, slot)
	var vbox := _open("%s — choose a variant" % ab["name"], 940, 620)
	current = "theme_pick"

	var base_row := HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 12)
	vbox.add_child(base_row)
	var base_icon := TextureRect.new()
	base_icon.texture = Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot])
	base_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_row.add_child(base_icon)
	var base_l := _lbl(base_row, "BASE — %s" % ab["desc"], 14, Color(0.85, 0.85, 0.9))
	base_l.custom_minimum_size = Vector2(780, 0)

	var is_base: bool = p.ability_theme.get(slot, "") == ""
	var none_cb := func() -> void:
		game.player.set_ability_theme(slot, "")
		open_skills()
	_btn(vbox, ("●  " if is_base else "   ") + "Use BASE (no theme)", none_cb, Color(0.85, 0.85, 0.9),
		true, Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot]))

	for i in Classes.THEMES[p.cls].size():
		var theme: Dictionary = Classes.THEMES[p.cls][i]
		var unlocked: bool = i < p.themes_known
		var selected: bool = p.ability_theme.get(slot, "") == theme["id"]
		var tcolor: Color = theme["color"] if unlocked else Color(0.4, 0.4, 0.45)
		var pick := func() -> void:
			game.player.set_ability_theme(slot, theme["id"])
			open_skills()
		var title: String = ("●  " if selected else "   ") + theme["name"].to_upper()
		if not unlocked:
			title += "   (unlocks at Lv %d)" % Classes.THEME_LEVELS[i]
		_btn(vbox, title, pick, tcolor, unlocked,
			Art.glyph_tex(Art.ABILITY_GLYPH[p.cls][slot], tcolor))
		var d := _lbl(vbox, theme["desc"] + "\n" + Classes.fx_text(theme["fx"]), 12,
			Color(0.68, 0.7, 0.78) if unlocked else Color(0.45, 0.45, 0.5))
		d.custom_minimum_size = Vector2(860, 0)
	_hint(vbox, "ESC to go back to the skill tree")


# -------------------------------------------------------------------- shop ---

func open_shop(zone: int) -> void:
	shop_zone = zone
	# Each merchant keeps their stock until you buy it out.
	if not game.shop_stock.has(zone):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var tier: String = ["wood", "silver", "silver", "gold"][zone]
		var stock: Array = []
		for i in 3:
			stock.append(Items.roll_item(tier, rng, game.player.cls))
		game.shop_stock[zone] = stock

	var p: Player = game.player
	var vbox := _open("Merchant — you have %d gold" % p.gold, 1120, 600)
	current = "shop"
	_lbl(vbox, "\"Ah, a customer! Dangerous roads make good business.\"", 14, Color(0.75, 0.7, 0.6))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 26)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# ------------------------------------------------------ BUY column ---
	var buy := VBoxContainer.new()
	buy.custom_minimum_size = Vector2(640, 0)
	buy.add_theme_constant_override("separation", 6)
	hbox.add_child(buy)
	_lbl(buy, "BUY", 16, Color(0.95, 0.85, 0.5))

	var buy_potion := func() -> void:
		if p.gold >= 25 and p.potions < 5:
			p.gold -= 25
			p.potions += 1
			game.sfx("potion")
		open_shop(zone)
	_btn(buy, "Health Potion — 25 gold  (you have %d, max 5)" % p.potions,
		buy_potion, Color(1.0, 0.5, 0.5), p.gold >= 25 and p.potions < 5)

	for item in game.shop_stock[zone]:
		var it: Dictionary = item
		var cost := Items.price(it) * 2
		var buy_item := func() -> void:
			if p.gold >= cost:
				p.gold -= cost
				game.shop_stock[zone].erase(it)
				p.add_item(it)
				game.sfx("potion")
			open_shop(zone)
		var bb := _btn(buy, "%s  %s — %d gold" % [Items.title(it), Items.describe(it), cost],
			buy_item, Items.GRADE_COLOR[it["grade"]], p.gold >= cost, Art.icon_for(it))
		bb.clip_text = true
		bb.custom_minimum_size = Vector2(640, 0)
		bb.tooltip_text = "%s — %d gold\n%s\n\nDiff vs equipped:\n%s" % [Items.title(it), cost, Items.describe(it), _diff_tip(it)]

	_lbl(buy, "UPGRADE", 16, Color(0.95, 0.85, 0.5))
	for slot in ["weapon", "armor"]:
		if p.equipment.has(slot):
			var item: Dictionary = p.equipment[slot]
			var cost := Items.upgrade_cost(item)
			var do_upgrade := func() -> void:
				if p.gold >= cost:
					p.gold -= cost
					item["plus"] += 1
					p.recalc()
					game.sfx("levelup")
				open_shop(zone)
			_btn(buy, "%s → +%d  (main stat +15%%) — %d gold" % [Items.title(item), item["plus"] + 1, cost],
				do_upgrade, Color(0.6, 0.9, 1.0), p.gold >= cost, Art.icon_for(item))

	# ----------------------------------------------------- SELL column ---
	var sell := VBoxContainer.new()
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell.add_theme_constant_override("separation", 6)
	hbox.add_child(sell)
	_lbl(sell, "SELL FROM BACKPACK", 16, Color(0.95, 0.85, 0.5))
	if p.backpack.is_empty():
		_lbl(sell, "Nothing to sell.", 13, Color(0.5, 0.5, 0.5))
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sell.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		var total := 0
		for item in p.backpack:
			var it: Dictionary = item
			var value := maxi(1, Items.price(it) / 2)
			total += value
			var sell_one := func() -> void:
				p.strip_gems(it)  # gems pop back into your bag
				p.backpack.erase(it)
				p.gain_gold(value)
				game.sfx("potion")
				open_shop(zone)
			var sb := _btn(list, "%s — sell for %d gold" % [Items.title(it), value],
				sell_one, Items.GRADE_COLOR[it["grade"]], true, Art.icon_for(it))
			sb.clip_text = true
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sell_all := func() -> void:
			for item in p.backpack:
				p.strip_gems(item)
			p.gain_gold(total)
			p.backpack.clear()
			game.sfx("potion")
			open_shop(zone)
		_btn(sell, "SELL ALL (%d items) — %d gold" % [p.backpack.size(), total],
			sell_all, Color(1.0, 0.9, 0.4))
	_hint(vbox)


# ------------------------------------------------------------------- codex ---

const BOSS_KINDS := ["fangmaw", "morwen", "vargoth"]

func open_codex(tab := "monsters") -> void:
	var vbox := _open("Codex", 1000, 620)
	current = "codex"

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Monsters  ", func() -> void: open_codex("monsters"),
		Color(0.95, 0.85, 0.5) if tab == "monsters" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Gear  ", func() -> void: open_codex("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if tab == "monsters":
		_codex_monsters(list)
	else:
		_codex_gear(list)
	_hint(vbox, "ESC / C to close")


func _codex_monsters(list: VBoxContainer) -> void:
	for section in [false, true]:  # regular monsters first, then bosses
		_lbl(list, "— BOSSES —" if section else "— MONSTERS —", 16, Color(1, 0.5, 0.5) if section else Color(0.95, 0.85, 0.5))
		for kind in Story.ENEMIES:
			var is_boss: bool = kind in BOSS_KINDS
			if is_boss != section:
				continue
			var st: Dictionary = Story.ENEMIES[kind]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			list.add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.tex(st["sprite"])
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var name_l := _lbl(info, st["name"], 16, Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
			name_l.custom_minimum_size = Vector2(780, 0)
			var stats_l := _lbl(info, "HP %d   ·   Damage %d   ·   Speed %d   ·   XP %d   ·   Gold %d   ·   %s" %
				[int(st["hp"]), int(st["dmg"]), int(st["speed"]), st["xp"], st.get("gold", 0),
				"Ranged caster" if st["ranged"] else "Melee"], 13, Color(0.7, 0.72, 0.78))
			stats_l.custom_minimum_size = Vector2(780, 0)


func _codex_gear(list: VBoxContainer) -> void:
	var slot_desc := {
		"weapon": "Main stat: ATK. Upgradeable at merchants.",
		"armor": "Main stat: HP. Upgradeable at merchants.",
		"boots": "Main stat: move speed.",
		"charm": "Main stat: cooldown reduction (Haste).",
	}

	# ------------------ visual gallery: every shape at every grade ------
	for slot in Items.SLOTS:
		_lbl(list, "— %sS — %s" % [slot.to_upper(), slot_desc[slot]], 16, Color(0.95, 0.85, 0.5))
		for noun in Art.GEAR_SHAPES[slot]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)
			var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
			var name_l := _lbl(row, "%s\n%s" % [noun, tag], 13, Color(0.85, 0.85, 0.9))
			name_l.custom_minimum_size = Vector2(110, 34)
			for g in Items.GRADES:
				var cell := VBoxContainer.new()
				cell.custom_minimum_size = Vector2(48, 0)
				row.add_child(cell)
				var icon := TextureRect.new()
				icon.texture = Art.item_icon(slot, g, noun)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cell.add_child(icon)
				var gl := Label.new()
				gl.text = g
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				gl.add_theme_font_size_override("font_size", 12)
				gl.add_theme_color_override("font_color", Items.GRADE_COLOR[g])
				cell.add_child(gl)

	# --------------------------------------- named epics & legendaries --
	_lbl(list, "— EPIC UNIQUES (A) — found in silver and golden chests —", 16, Items.GRADE_COLOR["A"])
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(slot, "A")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := _lbl(row, "  ·  ".join(Items.A_NAMES[slot]), 13, Items.GRADE_COLOR["A"])
		l.custom_minimum_size = Vector2(780, 0)

	_lbl(list, "— LEGENDARY (S) — class exclusive, golden chests only —", 16, Items.GRADE_COLOR["S"])
	for cls in Items.S_GEAR:
		_lbl(list, Classes.CLASSES[cls]["name"].to_upper(), 14, Color(0.95, 0.85, 0.5))
		for slot in Items.SLOTS:
			var special: Dictionary = Items.S_GEAR[cls][slot]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			list.add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.item_icon(slot, "S", special.get("noun", ""))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var extra := ""
			if special.has("passive"):
				extra = "  ★ " + Items.PASSIVES[special["passive"]]
			elif special.has("subs"):
				var bits: Array = []
				for stat in special["subs"]:
					bits.append("%s +%d%%" % [Items.STAT_LABEL[stat], int(round(special["subs"][stat] * 100))])
				extra = "  (" + ", ".join(bits) + ")"
			var l := _lbl(row, special["name"] + extra, 13, Items.GRADE_COLOR["S"])
			l.custom_minimum_size = Vector2(780, 0)

	# ------------------------------------------------- rules of thumb ---
	_lbl(list, "— GRADES & CHESTS —", 16, Color(0.95, 0.85, 0.5))
	for g in Items.GRADES:
		var subs := maxi(0, (Items.GRADES.find(g) - 1) / 2)
		_lbl(list, "%s   %s   —   power ×%.2f, up to %d bonus stat%s" %
			[g, Items.GRADE_PREFIX[g], Items.GRADE_MULT[g], subs, "" if subs == 1 else "s"],
			14, Items.GRADE_COLOR[g])
	_lbl(list, "Wooden chest — drops from monsters (common). Contains F to C gear.", 14, Color(0.8, 0.65, 0.45))
	_lbl(list, "Silver chest — drops from monsters (rare). Contains D to A gear.", 14, Color(0.8, 0.82, 0.9))
	_lbl(list, "Golden chest — every boss drops one. Contains B to S gear.", 14, Color(1.0, 0.85, 0.35))
	_lbl(list, "Bonus stats: ATK%, HP%, Crit, Haste, Speed, Lifesteal, Armor, Greed (gold).", 13, Color(0.7, 0.72, 0.78))


# ---------------------------------------------------------------- keybinds ---

func open_keybinds() -> void:
	var vbox := _open("Keybinds — click an action, then press a key", 700, 520)
	current = "keybinds"
	var actions := {
		"a1": "Ability 1", "a2": "Ability 2", "a3": "Ability 3", "ult": "Ultimate",
		"potion": "Drink potion", "interact": "Talk / interact",
		"inventory": "Inventory", "skills": "Skill tree", "codex": "Codex",
		"target": "Switch target lock",
	}
	for action in actions:
		var act: String = action
		var key_name := OS.get_keycode_string(game.binds[act])
		var text: String = "%s    —    [ %s ]" % [actions[act], key_name]
		if listening_action == act:
			text = "%s    —    press any key..." % actions[act]
		var rebind_cb := func() -> void:
			listening_action = act
			open_keybinds()
		_btn(vbox, text, rebind_cb, Color(1, 1, 0.6) if listening_action == act else Color(1, 1, 1))
	_lbl(vbox, "Movement is always WASD / arrows. ESC closes menus.", 13, Color(0.6, 0.6, 0.6))
	_hint(vbox)


# ------------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	# Keybind capture takes priority over everything.
	if listening_action != "" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			game.binds[listening_action] = event.keycode
			game.save_binds()
		listening_action = ""
		open_keybinds()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if current == "class_select":
			var ids: Array = Classes.CLASSES.keys()
			var num: int = event.keycode - KEY_1
			if num >= 0 and num < ids.size():
				pick_class(ids[num])
				get_viewport().set_input_as_handled()
			return  # can't ESC out of class select
		if event.keycode == KEY_ESCAPE \
				or (current == "inventory" and event.keycode == game.binds["inventory"]) \
				or (current == "skills" and event.keycode == game.binds["skills"]) \
				or (current == "codex" and event.keycode == game.binds["codex"]):
			if current == "theme_pick":
				open_skills()  # back to the tree, not out of the menu
			elif current == "item_panel":
				open_inventory()  # back to the bag
			else:
				close()
			get_viewport().set_input_as_handled()
