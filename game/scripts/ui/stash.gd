class_name UIStash
## The account-wide STASH: cross-character long-term storage. Static
## builder taking the Menus instance, like ui/mailbox.gd. Two columns —
## your BAG on the left (click to deposit), the STASH on the right (click
## to withdraw). Backed by game.stash (user://stash.json), shared by every
## character on this machine.


static func open(m: Menus) -> void:
	var g := m.game
	g.ensure_stash_loaded()
	var p := g.player
	var vbox := m._open("Stash — account storage  (%d / %d used)" % [g.stash.size(), Balance.STASH_SLOTS], 1040, 640)
	m.current = "stash"
	m._lbl(vbox, "Shared across ALL your characters. Click an entry to move it between your BAG and the STASH.",
		13, Color(0.7, 0.72, 0.78))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	_column(m, cols, "◀  YOUR BAG  (click to deposit)", _bag_entries(p), func(pl: Dictionary) -> void:
		if g.stash_deposit(pl):
			_remove_from_bag(p, pl)
			g.sfx("equip")
		else:
			g.spawn_text(p.global_position + Vector2(0, -50), "Stash full!", Color(1, 0.6, 0.4))
		open(m))

	_column(m, cols, "STASH  (click to withdraw)  ▶", g.stash.duplicate(), func(pl: Dictionary) -> void:
		if g.stash_withdraw(pl):
			g.sfx("equip")
		else:
			g.spawn_text(p.global_position + Vector2(0, -50), "Bag full — free a slot first", Color(1, 0.6, 0.4))
		open(m))

	m._hint(vbox, "ESC to close")


static func _column(m: Menus, parent: HBoxContainer, title: String, entries: Array, cb: Callable) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	m._lbl(box, title, 15, Color(0.95, 0.85, 0.5))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	if entries.is_empty():
		m._lbl(list, "(empty)", 13, Color(0.55, 0.55, 0.6))
		return
	for pl in entries:
		var payload: Dictionary = pl
		var b := m._btn(list, _entry_label(payload), func() -> void: cb.call(payload), _entry_color(payload))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true


static func _bag_entries(p: Player) -> Array:
	var out: Array = []
	for it in p.backpack:
		out.append({"kind": "item", "item": it})
	for gm in p.gem_bag:
		out.append({"kind": "gem", "gem": gm})
	for st in p.consumables:
		out.append({"kind": "stone", "stone": st})
	return out


static func _remove_from_bag(p: Player, pl: Dictionary) -> void:
	match String(pl.get("kind", "")):
		"item": p.backpack.erase(pl["item"])
		"gem": p.gem_bag.erase(pl["gem"])
		"stone": p.consumables.erase(pl["stone"])


static func _entry_label(pl: Dictionary) -> String:
	match String(pl.get("kind", "")):
		"item": return Items.title(pl["item"])
		"gem": return Items.gem_title(pl["gem"])
		"stone": return String(pl.get("stone", {}).get("name", "Consumable"))
	return "?"


static func _entry_color(pl: Dictionary) -> Color:
	match String(pl.get("kind", "")):
		"item": return Items.GRADE_COLOR[pl["item"]["grade"]]
		"gem": return Items.gem_color(pl["gem"])
	return Color(0.6, 0.9, 1.0)
