class_name UIMailbox
## The mailbox (playtest round 8): "Dropped Loot" letters from chapter
## ends, plus dev/event gifts. Static builders taking the Menus
## instance, like ui/dev_panel.gd. Letters: claim moves loot into the
## bag (partial claims leave the rest); claimed letters stay until
## deleted; unclaimed ones expire after Balance.MAIL_EXPIRY_DAYS on the
## trusted clock.


static func open(m: Menus) -> void:
	m.game.prune_mail()
	var no_mail: bool = m.game.mailbox.is_empty()
	# Empty mailbox: a note-sized panel (audit: one sentence rattling in a
	# 560px hall) with ghost letters sketching what will arrive here.
	var vbox := m._open("Mailbox", 900, 300.0 if no_mail else 560.0, true)
	m.current = "mailbox"
	if no_mail:
		# Intentional empty state (visual-review P0, 2026-08-21): a centred
		# painted envelope + one clear line — NOT loading-skeleton ghost rows
		# (the old ghost rows read as a frozen loading state despite "no mail").
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(center)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		center.add_child(col)
		var mail_tex: Texture2D = Art.ui_icon("ui_mail")  # existing painted medallion — no new art
		if mail_tex != null:
			var icon := TextureRect.new()
			icon.texture = mail_tex
			icon.custom_minimum_size = Vector2(76, 76)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			icon.modulate = Color(1, 1, 1, 0.5)   # decorative, not interactive
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(icon)
		var head := m._lbl(col, "No mail yet", 18, Color(0.82, 0.72, 0.45))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := m._lbl(col, "Uncollected spoils and ground overflow are recovered here.", 13, Color(0.62, 0.64, 0.7))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.custom_minimum_size = Vector2(440, 0)
	else:
		m._lbl(vbox, "Unclaimed loot vanishes %d days after a letter is sent. Claimed letters stay until you delete them." % Balance.MAIL_EXPIRY_DAYS, 12, Color(0.55, 0.55, 0.6))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 4)
		scroll.add_child(list)
		# Newest first.
		for i in range(m.game.mailbox.size() - 1, -1, -1):
			var mail: Dictionary = m.game.mailbox[i]
			var n: int = mail["items"].size()
			var status: String = "%d item%s" % [n, "" if n == 1 else "s"] if n > 0 else "claimed"
			var tag := "" if mail["read"] else "● "
			var b := m._btn(list, "%s%s   —   %s   —   %s" % [tag, mail["subject"], status,
				Time.get_date_string_from_unix_time(int(mail["sent_at"]))],
				func() -> void: open_letter(m, mail),
				Color(1, 1, 1) if not mail["read"] else Color(0.7, 0.7, 0.75))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Long multi-boss subjects would otherwise grow the button past
			# the panel and spill off-screen — trim to width with an ellipsis.
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


static func open_letter(m: Menus, mail: Dictionary, notice := "") -> void:
	mail["read"] = true
	var items: Array = mail["items"]
	var height := 560.0 if items.size() > 12 or str(mail["body"]).length() > 240 else (320.0 if items.is_empty() else 420.0)
	var vbox := m._open(str(mail["subject"]), 900, height, true)
	m.current = "mail_letter"
	m._lbl(vbox, "Sent " + Time.get_date_string_from_unix_time(int(mail["sent_at"])), 12, Color(0.55, 0.55, 0.6))
	if str(mail["body"]) != "":
		var body := m._lbl(vbox, str(mail["body"]), 14, Color(0.85, 0.85, 0.9))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not items.is_empty():
		var capacity := m._lbl(vbox, "Pack: %d / %d slots · Items that do not fit stay in this letter." % [m.game.player.bag_used(), m.game.player.bag_capacity()], 13, Color(0.7, 0.74, 0.8))
		capacity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if notice != "":
		var feedback := m._lbl(vbox, notice, 13, Color(0.95, 0.82, 0.5))
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback.name = "MailClaimNotice"
	if items.is_empty():
		m._lbl(vbox, "(claimed)", 13, Color(0.6, 0.62, 0.68))
	else:
		var scroll := ScrollContainer.new()
		scroll.name = "MailAttachments"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 11
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		scroll.add_child(grid)
		scroll.resized.connect(func() -> void:
			grid.columns = maxi(1, int((scroll.size.x - 16.0) / 68.0)))
		for payload in items:
			var view := attachment_view(payload)
			var b := m._bag_slot(grid, view.icon, str(view.count) if int(view.count) > 1 else "", view.color,
				func() -> void:
					m._open_detail_popover(view.icon, view.title, view.color, view.description, []))
			b.custom_minimum_size = Vector2(64, 64)
			b.tooltip_text = String(view.title)
			b.set_meta("mail_kind", String(payload.get("kind", "")))
			b.set_meta("mail_count", int(view.count))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	if not items.is_empty():
		var claim := m._btn(row, "  Claim what fits  ", func() -> void:
			_claim(m, mail), Color(0.6, 1.0, 0.6))
		claim.name = "MailClaimAll"
	var do_delete := func() -> void:
		m.game.mailbox.erase(mail)
		open(m)
	# Cancelling the gate must come back to THIS letter — open_confirm falls
	# through to the pause menu when a caller supplies no on_cancel, and the
	# mailbox is never reached from there (wardrobe.gd passes its own the same way).
	var keep_letter := func() -> void:
		open_letter(m, mail)
	if items.is_empty():
		m._btn(row, "  Delete letter  ", do_delete, Color(1.0, 0.65, 0.55))
	else:
		m._btn(row, "  Delete letter  ", func() -> void:
			m.open_confirm("Delete this letter AND its unclaimed loot?", do_delete, keep_letter), Color(1.0, 0.65, 0.55))
	m._btn(row, "  ⇦ Back  ", func() -> void: open(m))
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


## Move as much loot as fits into the bag; the rest stays in the letter.
static func _claim(m: Menus, mail: Dictionary) -> void:
	var leftover: Array = []
	for pl in mail["items"]:
		if not m.game._try_receive(pl):
			leftover.append(pl)
	mail["items"] = leftover
	m.game.autosave()
	if leftover.is_empty():
		m.game.sfx("chest")
	var notice := "All contents claimed." if leftover.is_empty() else "The rest stayed here. Free pack space or use some of a full material stack, then claim again."
	open_letter(m, mail, notice)

## All six inventory payloads use the same art and names as the bag. Materials
## and potions used to fall through to a blank reset-stone icon in letters.
static func attachment_view(pl: Dictionary) -> Dictionary:
	var v := {"icon": null, "title": "Consumable", "description": "", "color": Color(0.6, 0.9, 1.0), "count": 1}
	match String(pl.get("kind", "")):
		"item":
			var it: Dictionary = pl.get("item", {})
			v.icon = Art.icon_for(it)
			v.title = Items.title(it)
			v.description = Items.describe(it)
			v.color = Items.GRADE_COLOR.get(it.get("grade", "F"), Color.WHITE)
		"gem":
			var gem: Dictionary = pl.get("gem", {})
			v.icon = Art.gem_icon(Items.gem_color(gem), int(gem.get("lvl", 1)))
			v.title = Items.gem_title(gem)
			v.description = v.title
			v.color = Items.gem_color(gem)
		"material":
			var family := String(pl.get("family", ""))
			var grade := String(pl.get("grade", "F"))
			var mat := Items.make_material(family, grade, int(pl.get("count", 1)))
			v.icon = Art.material_icon(family, grade)
			v.title = mat.name
			v.count = mat.count
			v.color = Items.GRADE_COLOR.get(grade, Color.WHITE)
			v.description = "%s-grade crafting material · %d units.\nClaim into your pack to use at a crafting station." % [grade, int(mat.count)]
		"bag":
			var grade := String(pl.get("grade", "F"))
			v.icon = Art.bag_icon(grade)
			v.title = Items.BAG_NAMES.get(grade, "Bag")
			v.color = Items.GRADE_COLOR.get(grade, Color.WHITE)
			v.description = "%s-grade bag · %d carry slots.\nClaim into your pack, then equip it." % [grade, int(Items.BAG_SLOTS.get(grade, 0))]
		"potion", "stone":
			var key := "potion" if String(pl.kind) == "potion" else "stone"
			var consumable: Dictionary = pl.get(key, {})
			v.icon = Art.consumable_icon(consumable)
			v.title = consumable.get("name", "Consumable")
			v.description = consumable.get("desc", "")
			v.color = Items.GRADE_COLOR.get(consumable.get("grade", ""), v.color)
	return v
