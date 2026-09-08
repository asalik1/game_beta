extends RefCounted
const Wildlife := preload("res://scripts/wildlife.gd")
const Preview := preload("res://scripts/ui/companion_preview.gd")
const GREEN := Color(0.72, 0.91, 0.70)


static func open(m: Menus) -> void:
	var vbox := m._open("Small Mercies — the sanctuary", 900, 650, true)
	m.current = "sanctuary"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	page(m, list)


static func page(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	var heading := m._lbl(list, "%d / %d SMALL LIVES BROUGHT HOME" % [Wildlife.count(g), Wildlife.SITES.size()], 19, GREEN)
	UITheme.header(heading)
	_copy(m, list, "The road takes enough. Free stranded creatures with steady hands, then visit them at Stillwater Reach or Accord Commons in Crownfall. Rescues unlock their companions for your account. Each hero remembers their own rescues across chapters and co-op visits, including rescues made in a friend's world.")
	_copy(m, list, "Approach a trapped creature and interact, then stay close while you work. Movement out of reach, danger, injury or an open menu interrupts the rescue. Companions are cosmetic and can also be obtained with Renown in the Wardrobe.")
	_copy(m, list, "Friends see the companion you ask to follow, even when you change companions during a co-op visit.")
	for site in Wildlife.SITES:
		var id := String(site.id)
		var pet: Dictionary = Skins.find_pet(id)
		var saved := Wildlife.rescued(g, id)
		UITheme.rule(list)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var frame := Preview.new()
		frame.setup(id)
		frame.modulate = Color.WHITE if saved else Color(0.5, 0.55, 0.57)
		row.add_child(frame)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		m._lbl(words, ("✓  " if saved else "◇  ") + String(pet.name), 17, GREEN if saved else Color(0.86, 0.84, 0.77))
		_copy(m, words, String(pet.lore) if saved else String(site.hint))
		if saved:
			var worn: bool = g.player.equipped_pet == id
			var button := m._btn(words, "Return companion to the sanctuary" if worn else "Ask this companion to follow", func() -> void:
				if g.owns_cosmetic("pet", "all", id):
					g.player.set_pet("" if g.player.equipped_pet == id else id)
				open(m), GREEN)
			button.custom_minimum_size.y = 44


static func _copy(m: Menus, parent: Control, text: String) -> void:
	var l := m._lbl(parent, text, 14, Color(0.79, 0.83, 0.83))
	l.custom_minimum_size.x = 440
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
