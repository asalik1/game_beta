class_name UIMailbox
## The mailbox (playtest round 8): "Dropped Loot" letters from chapter
## ends, plus dev/event gifts. Static builders taking the Menus
## instance, like ui/dev_panel.gd. Letters: claim moves loot into the
## bag (partial claims leave the rest); claimed letters stay until
## deleted; unclaimed ones expire after Balance.MAIL_EXPIRY_DAYS on the
## trusted clock.


static func open(m: Menus) -> void:
	m.game.prune_mail()
	var vbox := m._open("Mailbox", 900, 560, true)
	m.current = "mailbox"
	if m.game.mailbox.is_empty():
		m._lbl(vbox, "No mail. Loot you leave on the ground arrives here when a chapter ends.", 14, Color(0.6, 0.62, 0.68))
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


static func open_letter(m: Menus, mail: Dictionary) -> void:
	mail["read"] = true
	var vbox := m._open(str(mail["subject"]), 900, 560, true)
	m.current = "mail_letter"
	m._lbl(vbox, "Sent " + Time.get_date_string_from_unix_time(int(mail["sent_at"])), 12, Color(0.55, 0.55, 0.6))
	if str(mail["body"]) != "":
		var body := m._lbl(vbox, str(mail["body"]), 14, Color(0.85, 0.85, 0.9))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var items: Array = mail["items"]
	if items.is_empty():
		m._lbl(vbox, "(claimed)", 13, Color(0.6, 0.62, 0.68))
	else:
		var grid := GridContainer.new()
		grid.columns = 11
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(grid)
		for pl in items:
			var payload: Dictionary = pl
			match str(payload.get("kind", "")):
				"item":
					var it: Dictionary = payload["item"]
					m._bag_slot(grid, Art.icon_for(it), "", Items.GRADE_COLOR[it["grade"]],
						func() -> void:
							m._open_detail_popover(Art.icon_for(it), Items.title(it),
								Items.GRADE_COLOR[it["grade"]], Items.describe(it), []))
				"gem":
					var g: Dictionary = payload["gem"]
					m._bag_slot(grid, Art.gem_icon(Items.gem_color(g), int(g.get("lvl", 1))), "",
						Items.gem_color(g),
						func() -> void:
							m._open_detail_popover(Art.gem_icon(Items.gem_color(g), int(g.get("lvl", 1))),
								Items.gem_title(g), Items.gem_color(g), Items.gem_title(g), []))
				_:
					var st: Dictionary = payload.get("stone", {})
					var ctex: ImageTexture = Art.consumable_icon(st)
					m._bag_slot(grid, ctex, "" if ctex != null else "⟲", Color(0.6, 0.9, 1.0),
						func() -> void:
							m._open_detail_popover(ctex, str(st.get("name", "Consumable")),
								Color(0.6, 0.9, 1.0), str(st.get("desc", "")), []))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	if not items.is_empty():
		m._btn(row, "  Claim all  ", func() -> void:
			_claim(m, mail), Color(0.6, 1.0, 0.6))
	var do_delete := func() -> void:
		m.game.mailbox.erase(mail)
		open(m)
	if items.is_empty():
		m._btn(row, "  Delete letter  ", do_delete, Color(1.0, 0.65, 0.55))
	else:
		m._btn(row, "  Delete letter  ", func() -> void:
			m.open_confirm("Delete this letter AND its unclaimed loot?", do_delete), Color(1.0, 0.65, 0.55))
	m._btn(row, "  ⇦ Back  ", func() -> void: open(m))
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


## Move as much loot as fits into the bag; the rest stays in the letter.
static func _claim(m: Menus, mail: Dictionary) -> void:
	var leftover: Array = []
	for pl in mail["items"]:
		if not m.game._try_receive(pl):
			leftover.append(pl)
	mail["items"] = leftover
	if leftover.is_empty():
		m.game.sfx("chest")
	else:
		m.game.spawn_text(m.game.player.global_position + Vector2(0, -50),
			"Bag full — the rest stayed in the letter", Color(1, 0.9, 0.4))
	open_letter(m, mail)