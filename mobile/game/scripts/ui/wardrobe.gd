class_name UIWardrobe
## The Wardrobe — the Renown store + cosmetic equip screen (DESIGN "Renown
## & the Wardrobe"). Static builders taking the Menus instance, like
## ui/daily.gd and ui/codex.gd. Chromas and elite/mythic skins are bought
## with Renown (account-wide collection, game_flow.owns_cosmetic); the
## EQUIPPED look stays per-character. Awakened skin forms are never sold
## here — they stay bound to the class's S-weapon awakening flag.
## Reached from the codex Records tab, the pause menu, and the capital's
## wardrobe desk (game_world._hub_action "wardrobe").


static func open(m: Menus) -> void:
	var g := m.game
	var p := g.player
	var vbox := m._open("Wardrobe — %s" % String(Classes.CLASSES[p.cls]["name"]), 940, 640, true)
	m.current = "wardrobe"

	# --- header: the wallet + where it comes from ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vbox.add_child(head)
	var bal := m._lbl(head, "◈  %d Renown" % g.renown(), 19, Balance.RENOWN_COLOR)
	bal.custom_minimum_size = Vector2(200, 0)
	var earn := m._lbl(head, "Earned from weeklies, the vault, bounties, dailies, record pushes and first NG+ tier clears — never from farming.",
		12, Color(0.6, 0.62, 0.68))
	earn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	earn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# --- the classic look (always owned) ---
	var classic_worn: bool = p.skin == "" and p.chroma == ""
	var crow := _row(list)
	_state_btn(m, crow, classic_worn, true, func() -> void:
		p.set_skin("")
		p.set_chroma("")
		g.autosave()
		open(m))
	var cname := m._lbl(crow, "Classic %s" % String(Classes.CLASSES[p.cls]["name"]) +
		("   ← worn" if classic_worn else ""), 14,
		Color(1.0, 0.88, 0.45) if classic_worn else Color(0.85, 0.88, 0.94))
	cname.custom_minimum_size = Vector2(300, 0)

	# --- chromas ---
	m._lbl(list, "— CHROMAS — recolors of your classic look —", 15, Color(0.7, 0.85, 1.0))
	for entry in Skins.chromas_for(p.cls):
		var ch: Dictionary = entry
		_chroma_row(m, list, String(ch["id"]), ch)

	# --- skins ---
	m._lbl(list, "— SKINS — full elite and mythic forms —", 15, Color(0.95, 0.85, 0.5))
	if Skins.skins_for(p.cls).is_empty():
		m._lbl(list, "No skins exist for this class yet.", 13, Color(0.55, 0.57, 0.63))
	for entry in Skins.skins_for(p.cls):
		var sk: Dictionary = entry
		_skin_row(m, list, String(sk["id"]), sk)

	# --- pets (Q16): cosmetic companions, class-agnostic, Renown-buyable ---
	m._lbl(list, "— COMPANIONS — a pet that follows your hero —", 15, Color(0.75, 0.95, 0.7))
	var none_row := _row(list)
	_state_btn(m, none_row, p.equipped_pet == "", true, func() -> void:
		p.set_pet("")
		g.autosave()
		open(m))
	m._lbl(none_row, "No companion" + ("   ← out" if p.equipped_pet == "" else ""), 14,
		Color(1.0, 0.88, 0.45) if p.equipped_pet == "" else Color(0.85, 0.88, 0.94)).custom_minimum_size = Vector2(240, 0)
	for entry in Skins.pets():
		_pet_row(m, list, String(entry["id"]), entry)

	# --- the weekly supply cache ---
	m._lbl(list, "— SUPPLY CACHE — once a week, per hero —", 15, Color(0.7, 1.0, 0.7))
	var krow := _row(list)
	if g.cache_available():
		var afford_k: bool = g.renown() >= Balance.RENOWN_CACHE_PRICE
		var kb := m._btn(krow, "  Buy  ◈ %d  " % Balance.RENOWN_CACHE_PRICE, func() -> void:
			if g.buy_weekly_cache():
				g.sfx("chest")
			open(m), Color(0.7, 1.0, 0.7))
		kb.disabled = not afford_k
		if not afford_k:
			kb.tooltip_text = "Not enough Renown"
	else:
		var wait := m._lbl(krow, "  Restocks next week  ", 13, Color(0.55, 0.57, 0.63))
		wait.custom_minimum_size = Vector2(160, 0)
	var kdesc := m._lbl(krow, "One of each utility consumable: mana draught, might elixir, ward elixir, renewal draught.",
		13, Color(0.8, 0.82, 0.88))
	kdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	m._hint(vbox, "Your collection is account-wide; what you wear is this hero's. ESC or ✕ to close")


static func _row(list: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	list.add_child(row)
	return row


## The leading action of a row: Wear / Doff for owned looks. `always_owned`
## is the classic look, which can only be worn (doffing it is meaningless).
static func _state_btn(m: Menus, row: HBoxContainer, worn: bool, always_owned: bool, on_wear: Callable) -> void:
	if worn and always_owned:
		var tag := m._lbl(row, "  Worn  ", 14, Color(1.0, 0.88, 0.45))
		tag.custom_minimum_size = Vector2(96, 0)
		return
	m._btn(row, "  Doff  " if worn else "  Wear  ", on_wear,
		Color(1.0, 0.88, 0.45) if worn else Color(0.8, 0.9, 1.0))


static func _chroma_row(m: Menus, list: VBoxContainer, id: String, ch: Dictionary) -> void:
	var g := m.game
	var p := g.player
	var row := _row(list)
	var owned: bool = g.owns_cosmetic("chroma", p.cls, id)
	var worn: bool = p.chroma == id
	if owned:
		_state_btn(m, row, worn, false, func() -> void:
			if worn:
				p.set_chroma("")
			else:
				p.set_skin("")  # chromas recolor the CLASSIC look
				p.set_chroma(id)
			g.autosave()
			open(m))
	else:
		_buy_btn(m, row, "chroma", id, ch)
	# The three gradient stops, shown as swatches.
	for stop in ["primary", "trim", "accent"]:
		var sw := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ch[stop]
		sb.set_corner_radius_all(3)
		sw.add_theme_stylebox_override("panel", sb)
		sw.custom_minimum_size = Vector2(18, 18)
		row.add_child(sw)
	var nm := m._lbl(row, String(ch["name"]) + ("   ← worn" if worn else ""), 14,
		Color(1.0, 0.88, 0.45) if worn else (Color(0.85, 0.88, 0.94) if owned else Color(0.62, 0.64, 0.7)))
	nm.custom_minimum_size = Vector2(260, 0)


static func _skin_row(m: Menus, list: VBoxContainer, id: String, sk: Dictionary) -> void:
	var g := m.game
	var p := g.player
	var row := _row(list)
	var owned: bool = g.owns_cosmetic("skin", p.cls, id)
	var worn: bool = p.skin == id
	if owned:
		_state_btn(m, row, worn, false, func() -> void:
			p.set_skin("" if worn else id)
			g.autosave()
			open(m))
	else:
		_buy_btn(m, row, "skin", id, sk)
	# (2026-07-27) Awakened forms retired — one look per skin, one thumb.
	var thumb: Texture2D = UICodex._gallery_thumb(Skins.skin_splash(p.cls, id))
	if thumb != null:
		var tr := TextureRect.new()
		tr.texture = thumb
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(72, 72)
		row.add_child(tr)
	var mythic: bool = String(sk.get("tier", "")) == "mythic"
	var chip := m._lbl(row, "MYTHIC" if mythic else "ELITE", 12,
		Balance.RENOWN_COLOR if mythic else Color(1.0, 0.85, 0.4))
	chip.custom_minimum_size = Vector2(64, 0)
	var nm := m._lbl(row, String(sk["name"]) +
		("   ← worn" if worn else ""), 14,
		Color(1.0, 0.88, 0.45) if worn else (Color(0.85, 0.88, 0.94) if owned else Color(0.62, 0.64, 0.7)))
	nm.custom_minimum_size = Vector2(300, 0)


## A companion (pet) row: class-agnostic (cls "all"), Renown-buyable, equip one
## at a time. Owning is account-wide; the equipped pet is per-hero.
static func _pet_row(m: Menus, list: VBoxContainer, id: String, pet: Dictionary) -> void:
	var g := m.game
	var p := g.player
	var row := _row(list)
	var owned: bool = g.owns_cosmetic("pet", "all", id)
	var worn: bool = p.equipped_pet == id
	if owned:
		_state_btn(m, row, worn, false, func() -> void:
			p.set_pet("" if worn else id)
			g.autosave()
			open(m))
	else:
		var price := Balance.renown_price("pet", String(pet.get("tier", "")))
		var afford: bool = g.renown() >= price
		var b := m._btn(row, "  Buy  ◈ %d  " % price, func() -> void:
			if g.buy_cosmetic("pet", "all", id):
				g.sfx("levelup")
			open(m), Color(0.7, 1.0, 0.7))
		b.disabled = not afford
		if not afford:
			b.tooltip_text = "Not enough Renown (you have %d)" % g.renown()
	var action := row.get_child(0) as Control
	action.custom_minimum_size = Vector2(110, 44)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var preview := preload("res://scripts/ui/companion_preview.gd").new()
	preview.setup(id, Vector2(64, 64))
	row.add_child(preview)
	var rare: bool = String(pet.get("tier", "")) == "rare"
	var chip := m._lbl(row, "RARE" if rare else "COMMON", 12,
		Balance.RENOWN_COLOR if rare else Color(0.72, 0.9, 0.72))
	chip.custom_minimum_size = Vector2(64, 0)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	var nm := m._lbl(words, String(pet["name"]) + ("   ← out" if worn else ""), 14,
		Color(1.0, 0.88, 0.45) if worn else (Color(0.85, 0.88, 0.94) if owned else Color(0.62, 0.64, 0.7)))
	nm.custom_minimum_size = Vector2(240, 0)
	nm.tooltip_text = String(pet.get("lore", "")) + "\nAlso earned by rescuing this creature. See Codex → Sanctuary."
	var lore := m._lbl(words, String(pet.get("lore", "")), 12, Color(0.65, 0.70, 0.72))
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size.x = 240


## The buy control for an unowned cosmetic: price + Buy (confirm-gated for
## skins — a mythic is a season of Renown; chromas buy instantly).
static func _buy_btn(m: Menus, row: HBoxContainer, kind: String, id: String, entry: Dictionary) -> void:
	var g := m.game
	var cls: String = g.player.cls
	var price := Balance.renown_price(kind, String(entry.get("tier", "")))
	var afford: bool = g.renown() >= price
	var do_buy := func() -> void:
		if g.buy_cosmetic(kind, cls, id):
			g.sfx("levelup")
		open(m)
	var b: Button
	if kind == "chroma":
		b = m._btn(row, "  Buy  ◈ %d  " % price, do_buy, Color(0.7, 1.0, 0.7))
	else:
		b = m._btn(row, "  Buy  ◈ %d  " % price, func() -> void:
			m.open_confirm("Buy the %s skin '%s' for %d Renown?" % [String(entry.get("tier", "elite")),
				String(entry["name"]), price], do_buy, func() -> void: open(m)), Color(0.7, 1.0, 0.7))
	b.disabled = not afford
	if not afford:
		b.tooltip_text = "Not enough Renown (you have %d)" % g.renown()
