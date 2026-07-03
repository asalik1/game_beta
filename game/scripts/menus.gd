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
	icon.texture = Art.item_icon(item["slot"], item["grade"])
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	_lbl(hbox, text, 14, Items.GRADE_COLOR[item["grade"]])


## "(now: ...)" — what you currently have in that item's slot.
func _now_text(item: Dictionary) -> String:
	var eq = game.player.equipment.get(item["slot"])
	if eq == null:
		return "   (slot empty)"
	return "   (now: %s)" % Items.describe(eq)


func _hint(vbox: Node, text := "ESC to close") -> void:
	var l := _lbl(vbox, text, 13, Color(0.55, 0.55, 0.55))
	l.size_flags_vertical = Control.SIZE_SHRINK_END


# ------------------------------------------------------------ class select ---

func open_class_select() -> void:
	var vbox := _open("Choose your class", 1180, 620)
	current = "class_select"
	_lbl(vbox, "This choice defines your four abilities. At level %d you will evolve into one of two advanced forms." % Classes.EVOLVE_LEVEL, 15, Color(0.75, 0.75, 0.75))

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
	var vbox := _open("Inventory — %d gold" % game.player.gold)
	current = "inventory"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)
	_lbl(left, "EQUIPPED", 16, Color(0.95, 0.85, 0.5))
	for slot in Items.SLOTS:
		if game.player.equipment.has(slot):
			var item: Dictionary = game.player.equipment[slot]
			_item_row(left, item, "%s\n%s" % [Items.title(item), Items.describe(item)])
		else:
			_lbl(left, "     %s — empty" % slot.capitalize(), 14, Color(0.45, 0.45, 0.45))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)
	_lbl(right, "BACKPACK (%d/%d) — click an item to equip it" % [game.player.backpack.size(), Player.BACKPACK_MAX], 16, Color(0.95, 0.85, 0.5))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in game.player.backpack:
		var it: Dictionary = item
		var equip_cb := func() -> void:
			game.player.equip(it)
			open_inventory()  # refresh
		_btn(list, "%s  %s%s" % [Items.title(it), Items.describe(it), _now_text(it)],
			equip_cb, Items.GRADE_COLOR[it["grade"]], true, Art.item_icon(it["slot"], it["grade"]))
	_hint(vbox, "ESC / I to close")


# -------------------------------------------------------------- skill tree ---

func open_skills() -> void:
	var p: Player = game.player
	var vbox := _open("%s Skill Tree — %d point%s available" % [Classes.CLASSES[p.cls]["name"], p.skill_points, "" if p.skill_points == 1 else "s"], 1060, 600)
	current = "skills"
	var note := "One branch per ability. Bottom nodes (capstones) gain EXTRA effects from your level-%d evolution." % Classes.EVOLVE_LEVEL
	if p.evolution != "":
		note = "Capstone effects marked %s are active for you." % Classes.CLASSES[p.cls]["evolutions"][p.evolution]["name"].to_upper()
	_lbl(vbox, note, 13, Color(0.6, 0.62, 0.68))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	for slot in ["a1", "a2", "a3"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(320, 0)
		col.add_theme_constant_override("separation", 4)
		hbox.add_child(col)
		_lbl(col, Classes.ability(p.cls, slot)["name"].to_upper(), 17, Color(0.95, 0.85, 0.5))
		for node in Skills.TREES[p.cls][slot]:
			var nd: Dictionary = node
			var is_learned: bool = p.learned.has(nd["id"])
			var can: bool = Skills.can_learn(p.cls, nd["id"], p.learned) and p.skill_points > 0
			var color := Color(0.5, 1.0, 0.5) if is_learned else (Color(1, 1, 1) if can else Color(0.45, 0.45, 0.45))
			var learn_cb := func() -> void:
				if game.player.learn_skill(nd["id"]):
					open_skills()  # refresh
			_btn(col, ("✔ " if is_learned else "· ") + nd["name"], learn_cb, color, can)
			var desc := _lbl(col, nd["desc"], 12, Color(0.62, 0.65, 0.72) if not is_learned else Color(0.55, 0.8, 0.55))
			desc.custom_minimum_size = Vector2(320, 0)
	_hint(vbox, "ESC / T to close — earn points by leveling up")


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
			stock.append(Items.roll_item(tier, rng))
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
		_btn(buy, "%s  %s — %d gold\n%s" % [Items.title(it), Items.describe(it), cost, _now_text(it)],
			buy_item, Items.GRADE_COLOR[it["grade"]], p.gold >= cost, Art.item_icon(it["slot"], it["grade"]))

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
				do_upgrade, Color(0.6, 0.9, 1.0), p.gold >= cost, Art.item_icon(item["slot"], item["grade"]))

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
				p.backpack.erase(it)
				p.gain_gold(value)
				game.sfx("potion")
				open_shop(zone)
			_btn(list, "%s — sell for %d gold" % [Items.title(it), value],
				sell_one, Items.GRADE_COLOR[it["grade"]], true, Art.item_icon(it["slot"], it["grade"]))
		var sell_all := func() -> void:
			p.gain_gold(total)
			p.backpack.clear()
			game.sfx("potion")
			open_shop(zone)
		_btn(sell, "SELL ALL (%d items) — %d gold" % [p.backpack.size(), total],
			sell_all, Color(1.0, 0.9, 0.4))
	_hint(vbox)


# --------------------------------------------------------------- evolution ---

func open_evolution() -> void:
	var cls: Dictionary = Classes.CLASSES[game.player.cls]
	var vbox := _open("EVOLUTION — your power awakens!", 860, 400)
	current = "evolution"
	_lbl(vbox, "Level %d reached. Choose the path of your %s — this is permanent." % [Classes.EVOLVE_LEVEL, cls["name"]], 15)
	for id in cls["evolutions"]:
		var evo: Dictionary = cls["evolutions"][id]
		var evo_id: String = id
		_btn(vbox, "%s\n      %s" % [evo["name"], evo["desc"]],
			func() -> void: pick_evolution(evo_id),
			Color(0.95, 0.85, 0.5))


func pick_evolution(id: String) -> void:
	close()
	game.player.evolve(id)


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
			row.add_child(info)
			_lbl(info, st["name"], 16, Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
			_lbl(info, "HP %d   ·   Damage %d   ·   Speed %d   ·   XP %d   ·   Gold %d   ·   %s" %
				[int(st["hp"]), int(st["dmg"]), int(st["speed"]), st["xp"], st.get("gold", 0),
				"Ranged caster" if st["ranged"] else "Melee"], 13, Color(0.7, 0.72, 0.78))


func _codex_gear(list: VBoxContainer) -> void:
	_lbl(list, "— EQUIPMENT SLOTS —", 16, Color(0.95, 0.85, 0.5))
	var slot_desc := {
		"weapon": "Main stat: ATK. Upgradeable at merchants.",
		"armor": "Main stat: HP. Upgradeable at merchants.",
		"boots": "Main stat: move speed.",
		"charm": "Main stat: cooldown reduction (Haste).",
	}
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(slot, "C")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		_lbl(row, "%s — %s" % [slot.capitalize(), slot_desc[slot]], 14)

	_lbl(list, "— GRADES —", 16, Color(0.95, 0.85, 0.5))
	for g in Items.GRADES:
		var subs := maxi(0, (Items.GRADES.find(g) - 1) / 2)
		_lbl(list, "%s   %s   —   power ×%.2f, up to %d bonus stat%s" %
			[g, Items.GRADE_PREFIX[g], Items.GRADE_MULT[g], subs, "" if subs == 1 else "s"],
			14, Items.GRADE_COLOR[g])

	_lbl(list, "— CHESTS —", 16, Color(0.95, 0.85, 0.5))
	_lbl(list, "Wooden chest — drops from monsters (common). Contains F to C gear.", 14, Color(0.8, 0.65, 0.45))
	_lbl(list, "Silver chest — drops from monsters (rare). Contains D to A gear.", 14, Color(0.8, 0.82, 0.9))
	_lbl(list, "Golden chest — every boss drops one. Contains B to S gear.", 14, Color(1.0, 0.85, 0.35))

	_lbl(list, "— POSSIBLE BONUS STATS —", 16, Color(0.95, 0.85, 0.5))
	_lbl(list, "ATK%, HP%, Crit chance, Haste (cooldowns), Move speed, Lifesteal, Armor (damage reduction), Greed (bonus gold)", 13, Color(0.7, 0.72, 0.78))


# ---------------------------------------------------------------- keybinds ---

func open_keybinds() -> void:
	var vbox := _open("Keybinds — click an action, then press a key", 700, 520)
	current = "keybinds"
	var actions := {
		"a1": "Ability 1", "a2": "Ability 2", "a3": "Ability 3", "ult": "Ultimate",
		"potion": "Drink potion", "interact": "Talk / interact",
		"inventory": "Inventory", "skills": "Skill tree", "codex": "Codex",
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
			if current != "evolution":  # must choose an evolution
				close()
				get_viewport().set_input_as_handled()
