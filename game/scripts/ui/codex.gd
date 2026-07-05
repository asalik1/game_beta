class_name UICodex
## The codex screens (monsters / gear / terrains), split out of
## menus.gd. Static builders: `m` owns the panel scaffolding
## (_open/_btn/_lbl/_hint) and the open/close state.

static func open(m: Menus, tab := "monsters") -> void:
	var vbox := m._open("Codex", 1000, 620)
	m.current = "codex"

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	m._btn(tabs, "  Monsters  ", func() -> void: m.open_codex("monsters"),
		Color(0.95, 0.85, 0.5) if tab == "monsters" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Gear  ", func() -> void: m.open_codex("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Terrains  ", func() -> void: m.open_codex("terrains"),
		Color(0.95, 0.85, 0.5) if tab == "terrains" else Color(0.6, 0.6, 0.6))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if tab == "monsters":
		_monsters(m, list)
	elif tab == "terrains":
		_terrains(m, list)
	else:
		_gear(m, list)
	m._hint(vbox, "ESC / C to close")


## Rounded, padded card panel — shared row container for codex galleries.
static func _card(parent: Container) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	return card


static func _monsters(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	for section in [false, true]:  # regular monsters first, then bosses
		m._lbl(list, "— BOSSES —" if section else "— MONSTERS —", 16, Color(1, 0.5, 0.5) if section else Color(0.95, 0.85, 0.5))
		for kind in Story.ALL_ENEMIES:
			var is_boss: bool = kind in m.BOSS_KINDS
			if is_boss != section:
				continue
			var st: Dictionary = Story.ALL_ENEMIES[kind]

			# One boxed card per monster.
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			_card(list).add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.tex(st["sprite"])
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 2)
			row.add_child(info)

			# Name .......................................... Lv badge
			var head := HBoxContainer.new()
			info.add_child(head)
			var name_l := m._lbl(head, st["name"], 16, Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
			name_l.custom_minimum_size = Vector2(560, 0)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lv_l := m._lbl(head, "Lv %d" % st.get("level", 1), 15, Color(0.95, 0.85, 0.5))
			lv_l.custom_minimum_size = Vector2(120, 0)
			lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

			# Aligned stat columns.
			var cols := HBoxContainer.new()
			info.add_child(cols)
			for pair in [["HP", int(st["hp"])], ["DMG", int(st["dmg"])], ["SPD", int(st["speed"])],
					["XP", st["xp"]], ["Gold", st.get("gold", 0)]]:
				var c := m._lbl(cols, "%s %s" % [pair[0], str(pair[1])], 13, Color(0.78, 0.8, 0.86))
				c.custom_minimum_size = Vector2(105, 0)
			var type_l := m._lbl(cols, "Ranged caster" if st["ranged"] else "Melee", 13, Color(0.6, 0.7, 0.85))
			type_l.custom_minimum_size = Vector2(130, 0)

			# Scaling: growth + projections, in two quiet sublines.
			var at25 := Story.enemy_stats_at(kind, 25)
			var at50 := Story.enemy_stats_at(kind, 50)
			var g1 := m._lbl(info, "Growth per level:   HP +%d%%   ·   DMG +%d%%" %
				[int(st.get("hp_g", 0.1) * 100), int(st.get("dmg_g", 0.1) * 100)], 12, Color(0.55, 0.65, 0.8))
			g1.custom_minimum_size = Vector2(700, 0)
			var g2 := m._lbl(info, "Projected:   Lv 25 → %d HP, %d DMG        Lv 50 → %d HP, %d DMG" %
				[int(at25["hp"]), int(at25["dmg"]), int(at50["hp"]), int(at50["dmg"])], 12, Color(0.5, 0.55, 0.66))
			g2.custom_minimum_size = Vector2(700, 0)


static func _terrains(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var patch_desc := {
		"lava": "Lava pools — the floor burns anyone standing in them, you AND monsters",
		"ice": "Sheet ice — slippery patches speed everyone up by 35%",
		"poison": "Poison pools — standing in them poisons you",
		"heal": "Blessed ground — standing in it slowly heals you",
		"slow": "Clinging murk — wading through slows you by 30%",
	}
	var event_desc := {
		"magma_rain": "Magma rain — molten rock crashes onto telegraphed spots and the floor collapses into lava",
		"grave_spawn": "Restless dead — zombies periodically claw out of the ground beside you",
		"gust": "Sandstorm gusts — sudden wind shoves everyone sideways",
		"lightning": "Lightning strikes — bolts hammer telegraphed spots around you",
		"shard": "Shard eruptions — crystal bursts explode at random spots",
	}
	var ambient_desc := {
		"leaves_green": "drifting green leaves", "leaves_autumn": "falling autumn leaves",
		"fireflies": "fireflies", "embers": "rising embers", "snow": "falling snow",
		"rain": "heavy rain", "sand": "blowing sand", "mist": "creeping mist",
		"twinkle": "twinkling lights", "motes": "drifting void motes",
		"sparkle": "golden sparkles", "spores": "floating spores",
	}
	# Which Chapter 1 zone (if any) uses each terrain.
	var found_in := {}
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid]["zones"]:
			if not found_in.has(zone.get("terrain", "")):
				found_in[zone.get("terrain", "")] = zone["name"]

	for id in Terrains.DATA:
		var t: Dictionary = Terrains.DATA[id]
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		_card(list).add_child(info)

		# Name ................................... where it appears
		var head := HBoxContainer.new()
		info.add_child(head)
		var name_l := m._lbl(head, t["name"], 16, Color(1, 1, 1))
		name_l.custom_minimum_size = Vector2(560, 0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where: String = found_in.get(id, "")
		var where_l := m._lbl(head, where if where != "" else "Beyond Chapter 1", 13,
			Color(0.95, 0.85, 0.5) if where != "" else Color(0.55, 0.58, 0.66))
		where_l.custom_minimum_size = Vector2(220, 0)
		where_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var amb: String = t.get("ambient", "")
		var w := m._lbl(info, "Weather:   " + String(ambient_desc.get(amb, "still air")),
			13, Color(0.7, 0.72, 0.78))
		w.custom_minimum_size = Vector2(700, 0)

		var quirks: Array = []
		for p in t.get("patches", []):
			var d: String = patch_desc.get(p["type"], "")
			if p.get("drift", false):
				d += " — and the clouds DRIFT, so keep moving"
			quirks.append(d)
		if t.get("event", "") != "":
			quirks.append(event_desc.get(t["event"], ""))
		if t.get("mp_boost", false):
			quirks.append("Latent magic — your mana recovers much faster here")
		if quirks.is_empty():
			quirks.append("No hazards — safe ground")
		for q in quirks:
			var ql := m._lbl(info, "◆ " + String(q), 13, Color(0.55, 0.65, 0.8))
			ql.custom_minimum_size = Vector2(700, 0)


static func _gear(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var slot_desc := {
		"weapon": "Main stat: ATK. Upgradeable at merchants.",
		"armor": "Main stat: HP. Upgradeable at merchants.",
		"boots": "Main stat: move speed.",
		"charm": "Main stat: cooldown reduction (Haste).",
	}

	# ------------------ visual gallery: every shape at every grade ------
	for slot in Items.SLOTS:
		m._lbl(list, "— %sS — %s" % [slot.to_upper(), slot_desc[slot]], 16, Color(0.95, 0.85, 0.5))
		for noun in Art.GEAR_SHAPES[slot]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_card(list).add_child(row)
			var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
			var name_l := m._lbl(row, "%s\n%s" % [noun, tag], 13, Color(0.85, 0.85, 0.9))
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
	m._lbl(list, "— EPIC UNIQUES (A) — found in silver and golden chests —", 16, Items.GRADE_COLOR["A"])
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_card(list).add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(slot, "A")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := m._lbl(row, "  ·  ".join(Items.A_NAMES[slot]), 13, Items.GRADE_COLOR["A"])
		l.custom_minimum_size = Vector2(780, 0)

	m._lbl(list, "— LEGENDARY (S) — class exclusive, golden chests only —", 16, Items.GRADE_COLOR["S"])
	for cls in Items.S_GEAR:
		# One card per class holding its four legendary pieces.
		var cls_box := VBoxContainer.new()
		cls_box.add_theme_constant_override("separation", 4)
		_card(list).add_child(cls_box)
		m._lbl(cls_box, Classes.CLASSES[cls]["name"].to_upper(), 14, Color(0.95, 0.85, 0.5))
		for slot in Items.SLOTS:
			var special: Dictionary = Items.S_GEAR[cls][slot]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			cls_box.add_child(row)
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
					var v: float = special["subs"][stat]
					if stat in Items.FLAT_STATS:
						bits.append("%s +%d" % [Items.STAT_LABEL[stat], int(v)])
					else:
						bits.append("%s +%d%%" % [Items.STAT_LABEL[stat], int(round(v * 100))])
				extra = "  (" + ", ".join(bits) + ")"
			var l := m._lbl(row, special["name"] + extra, 13, Items.GRADE_COLOR["S"])
			l.custom_minimum_size = Vector2(780, 0)

	# ------------------------------------------------- rules of thumb ---
	m._lbl(list, "— GRADES & CHESTS —", 16, Color(0.95, 0.85, 0.5))
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", 2)
	_card(list).add_child(rules)
	for g in Items.GRADES:
		var subs := maxi(0, (Items.GRADES.find(g) - 1) / 2)
		m._lbl(rules, "%s   %s   —   power ×%.2f, up to %d bonus stat%s" %
			[g, Items.GRADE_PREFIX[g], Items.GRADE_MULT[g], subs, "" if subs == 1 else "s"],
			14, Items.GRADE_COLOR[g])
	var chests := VBoxContainer.new()
	chests.add_theme_constant_override("separation", 2)
	_card(list).add_child(chests)
	m._lbl(chests, "Wooden chest — drops from monsters (common). Contains F to C gear.", 14, Color(0.8, 0.65, 0.45))
	m._lbl(chests, "Silver chest — drops from monsters (rare). Contains D to A gear.", 14, Color(0.8, 0.82, 0.9))
	m._lbl(chests, "Golden chest — every boss drops one. Contains B to S gear.", 14, Color(1.0, 0.85, 0.35))
	m._lbl(chests, "Bonus stats: ATK%, HP%, Crit, Haste, Speed, Lifesteal, Armor, Greed (gold).", 13, Color(0.7, 0.72, 0.78))
