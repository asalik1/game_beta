class_name Menus extends CanvasLayer
## All full-screen menus: class select, inventory, skill tree, merchant
## shop, evolution choice, and keybinding. One menu open at a time;
## opening a menu pauses the game.

var game: Game
var root: Control = null          # the currently open panel (null = closed)
var current := ""
var listening_action := ""        # keybind screen: waiting for a key press
var shop_zone := -1
var chapter_replay := false       # chapter select opened from the pause menu
var dev_boss_mode := 1            # dev panel boss spawn level: 0 story, 1 my Lv (default), 2 +10, 3 +20
var dev_boss_level_override := 0  # dev panel: exact level for NEW boss spawns (0 = off)


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
	# Boot menus unpause only once the game actually starts.
	if not (current in ["class_select", "title"]) \
			and not (current == "chapter_select" and not chapter_replay):
		get_tree().paused = false
	current = ""
	game.talk_cd = maxf(game.talk_cd, 0.35)  # debounce the reopen hotkeys
	if game.play_started:
		game.autosave()  # menus are where gear/talents/purchases change


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


# ------------------------------------------------------------ title screen ---

## Shown at boot when saves exist: continue a character or start fresh.
func open_title() -> void:
	var vbox := _open("EMBERFALL", 760, 560)
	current = "title"
	_lbl(vbox, "Chapter 1: The Hollow King", 15, Color(0.75, 0.75, 0.75))

	_lbl(vbox, "— CONTINUE —", 15, Color(0.95, 0.85, 0.5))
	# The save list SCROLLS (20 slots + a dev roster overflowed the fixed
	# panel — the bottom buttons must never leave the box).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var saves := VBoxContainer.new()
	saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves.add_theme_constant_override("separation", 4)
	scroll.add_child(saves)
	for s in SaveGame.list():
		var slot: int = s["slot"]
		var cls_info: Dictionary = Classes.CLASSES.get(s["cls"], {})
		var cname: String = cls_info.get("name", s["cls"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		saves.add_child(row)
		var icon: Texture2D = Art.tex(cls_info["sprite"]) if cls_info.has("sprite") else null
		var resume := func() -> void:
			if root:
				root.queue_free()
				root = null
			current = ""
			game.load_save(slot)
		var b := _btn(row, "  %s — Lv %d" % [cname, s["level"]], resume, Color(0.6, 1.0, 0.6), true, icon)
		b.custom_minimum_size = Vector2(360, 0)
		b.tooltip_text = Story.quest_text(s["quest"])
		var when := Time.get_datetime_string_from_unix_time(s["saved_at"]).replace("T", "  ")
		var wl := _lbl(row, when, 12, Color(0.55, 0.58, 0.66))
		wl.custom_minimum_size = Vector2(170, 0)
		var erase := func() -> void:
			SaveGame.delete(slot)
			if SaveGame.list().is_empty():
				open_class_select()
			else:
				open_title()
		_btn(row, " ✕ ", erase, Color(1, 0.5, 0.5))

	# No spacer: the scroll list absorbs the flexible space, pinning
	# these buttons inside the panel no matter how many saves exist.
	_btn(vbox, "  ⚔  New Game  ", func() -> void: open_chapter_select(), Color(0.95, 0.85, 0.5))
	_btn(vbox, "  🔊  Settings  ", func() -> void: open_settings("title"), Color(0.8, 0.85, 0.9))
	_dev_roster_row(vbox)
	_hint(vbox, "Continue a saved hero, or forge a new one")


## Dev launcher row (dev_mode.bat only): batch-create the 6-class
## roster straight from the launcher screens — no need to enter a
## game and open F1 first. Level box → one save per class, free
## slots only (never overwrites), then back to the title list.
func _dev_roster_row(vbox: VBoxContainer) -> void:
	if not game.dev_mode:
		return
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	vbox.add_child(drow)
	var lvl_box := LineEdit.new()
	lvl_box.text = "40"
	lvl_box.max_length = 3
	lvl_box.custom_minimum_size = Vector2(64, 0)
	drow.add_child(lvl_box)
	_btn(drow, "  🛠  DEV: create roster — all 6 classes at this level  ", func() -> void:
		var lvl := clampi(int(lvl_box.text) if lvl_box.text.is_valid_int() else 40, 1, Balance.LEVEL_CAP)
		UIDevPanel.create_roster(self, lvl)
		open_title(), Color(0.6, 0.9, 1.0))


# ---------------------------------------------------------------- pause ---

## The system menu (ESC in-game): everything a session needs that isn't
## combat — resume, options, chapter control, and the exits.
func open_pause() -> void:
	var vbox := _open("Paused — " + String(Story.chapter(game.chapter_id)["name"]), 720, 600)
	current = "pause"
	var zi := clampi(game.cur_room, 0, game.zone_count - 1)
	_lbl(vbox, "%s, Level %d — %s" % [Classes.CLASSES[game.player.cls]["name"],
		game.player.level, game.zones[zi]["name"]], 14, Color(0.7, 0.72, 0.78))
	_btn(vbox, "  ▶  Resume", func() -> void: close(), Color(0.6, 1.0, 0.6))
	_btn(vbox, "  🔊  Settings (sound)", func() -> void: open_settings(), Color(0.9, 0.9, 0.95))
	_btn(vbox, "  ⌨  Keybinds", func() -> void: open_keybinds(), Color(0.9, 0.9, 0.95))
	var unread := 0
	for mail in game.mailbox:
		if not mail["read"]:
			unread += 1
	_btn(vbox, "  ✉  Mailbox" + ("  (%d new)" % unread if unread > 0 else ""),
		func() -> void: open_mailbox(), Color(0.8, 0.9, 1.0) if unread > 0 else Color(0.9, 0.9, 0.95))
	var restart := func() -> void:
		open_confirm("Restart '%s' from the beginning? Story progress in this chapter resets — your character, gear and Resonance stay." % Story.chapter(game.chapter_id)["name"],
			func() -> void: game.replay_chapter(game.chapter_id))
	_btn(vbox, "  ↺  Restart chapter  (keeps your character)", restart, Color(1.0, 0.8, 0.5))
	_btn(vbox, "  ⚑  Chapter select  (replay any chapter)", func() -> void: open_chapter_select(true), Color(1.0, 0.8, 0.5))
	var to_title := func() -> void:
		open_confirm("Exit to the title screen? Your progress is saved.",
			func() -> void: game.exit_to_title())
	_btn(vbox, "  ⇦  Exit to title  (switch character)", to_title, Color(1.0, 0.65, 0.55))
	var quit_game := func() -> void:
		game.autosave()
		get_tree().quit()
	_btn(vbox, "  ✕  Save and quit game", quit_game, Color(1.0, 0.55, 0.5))
	_hint(vbox, "ESC to resume")


## A single yes/cancel gate in front of anything destructive.
func open_confirm(msg: String, on_yes: Callable) -> void:
	var vbox := _open("Are you sure?", 680, 320)
	current = "confirm"
	var l := _lbl(vbox, msg, 15, Color(0.9, 0.9, 0.9))
	l.custom_minimum_size = Vector2(600, 0)
	var yes := func() -> void:
		close()
		on_yes.call()
	_btn(vbox, "  Yes — do it  ", yes, Color(1.0, 0.6, 0.5))
	_btn(vbox, "  Cancel  ", func() -> void: open_pause(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to cancel")


## Sound + display options. Everything applies live and persists to
## user://settings.json. Reachable from the pause menu AND the title.
var settings_return := "pause"
func open_settings(from := "pause") -> void:
	settings_return = from
	var vbox := _open("Settings", 700, 440)
	current = "settings"
	for spec in [["Music volume", "music"], ["Sound effects", "sfx"]]:
		var key: String = spec[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		vbox.add_child(row)
		var name_l := _lbl(row, spec[0], 15)
		name_l.custom_minimum_size = Vector2(180, 0)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(game.settings[key])
		slider.custom_minimum_size = Vector2(320, 24)
		row.add_child(slider)
		var pct := _lbl(row, "%d%%" % int(float(game.settings[key]) * 100), 15, Color(0.95, 0.85, 0.5))
		pct.custom_minimum_size = Vector2(70, 0)
		slider.value_changed.connect(func(v: float) -> void:
			game.settings[key] = v
			game.apply_audio_settings()
			game.save_settings()
			pct.text = "%d%%" % int(v * 100)
			if key == "sfx":
				game.sfx("coin"))  # audible preview at the new level
	_lbl(vbox, "Slide to 0 to mute. Changes save instantly.", 12, Color(0.55, 0.58, 0.66))
	var fs_btn := _btn(vbox, "  Fullscreen: %s  " % ("ON" if game.settings["fullscreen"] else "OFF"),
		func() -> void:
			game.settings["fullscreen"] = not game.settings["fullscreen"]
			game.apply_display_settings()
			game.save_settings()
			open_settings(settings_return), Color(0.9, 0.9, 0.95))
	fs_btn.tooltip_text = "Borderless fullscreen on your current monitor."
	_btn(vbox, "  Back  ", func() -> void: _settings_back(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back")


func _settings_back() -> void:
	if settings_return == "title":
		open_title()
	else:
		open_pause()


# ---------------------------------------------------------- chapter select ---

## New game step one — or, from the pause menu (replay=true), jump an
## EXISTING character into any chapter from its beginning.
func open_chapter_select(replay := false) -> void:
	chapter_replay = replay
	var vbox := _open("Choose your chapter", 900, 540)
	current = "chapter_select"
	if replay:
		_lbl(vbox, "Return to any unlocked chapter with this character — farm, finish arcs, take other paths. Story progress there resets; your build, gear and Resonance travel with you.", 14, Color(0.75, 0.75, 0.75))
	else:
		_lbl(vbox, "One campaign, chapter by chapter: win a chapter and your hero journeys on to the next. Later chapters unlock once you've beaten the one before.", 14, Color(0.75, 0.75, 0.75))
	var idx := 1
	for chid in Story.CHAPTER_LIST:
		var chapter: Dictionary = Story.CHAPTER_LIST[chid]
		var pick_id: String = chid
		var unlocked: bool = game.chapter_available(chid, replay)
		var pick := func() -> void:
			if chapter_replay:
				if root:
					root.queue_free()
					root = null
				current = ""
				game.replay_chapter(pick_id)
			else:
				pick_chapter(pick_id)
		var b := _btn(vbox, "  %d.  %s%s  " % [idx, "" if unlocked else "🔒 ", chapter["name"]],
			pick, Color(0.95, 0.85, 0.5) if unlocked else Color(0.5, 0.5, 0.55), unlocked)
		b.add_theme_font_size_override("font_size", 18)
		var sub_text: String = String(chapter.get("sub", "")) if unlocked \
			else "Locked — finish the previous chapter to open this road."
		var sub := _lbl(vbox, "        " + sub_text, 13,
			Color(0.65, 0.68, 0.78) if unlocked else Color(0.5, 0.5, 0.55))
		sub.custom_minimum_size = Vector2(800, 0)
		idx += 1
	if not replay:
		_dev_roster_row(vbox)
	_hint(vbox, "Press the chapter's number, or click" + ("  ·  ESC to go back" if replay else ""))


func pick_chapter(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.switch_chapter(id)  # no-op if it is already the built chapter
	open_class_select()


# ------------------------------------------------------------ class select ---

func open_class_select() -> void:
	var vbox := _open("Choose your class", 1240, 660)
	current = "class_select"
	_lbl(vbox, "This choice defines your four abilities and your three THEMES — elemental playstyles that change how your abilities behave, unlocked as you level.", 15, Color(0.75, 0.75, 0.75))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Cards share the row equally, however many classes exist.
	var count := Classes.CLASSES.size()
	var card_w := (1240.0 - 48.0 - 10.0 * (count - 1)) / count
	var dense := count > 4  # 6-class roster: tighter type, smaller icon

	var idx := 1
	for id in Classes.CLASSES:
		var c: Dictionary = Classes.CLASSES[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(card_w, 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4 if dense else 6)
		hbox.add_child(col)

		var icon := TextureRect.new()
		icon.texture = Art.tex(c["sprite"])
		var icon_px := 72.0 if dense else 96.0
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		col.add_child(icon)

		_lbl(col, c["name"], 18 if dense else 20, Color(0.95, 0.85, 0.5))
		_lbl(col, c["desc"], 12 if dense else 13, Color(0.8, 0.8, 0.8))
		if c.has("passive"):
			_lbl(col, "★ " + c["passive"]["text"], 11 if dense else 12, Color(0.5, 0.95, 0.8))
		var theme_names: Array = []
		for theme in Classes.THEMES[id]:
			theme_names.append(theme["name"])
		_lbl(col, "Themes: " + " / ".join(theme_names), 11 if dense else 12, Color(0.7, 0.8, 0.95))
		for slot in ["a1", "a2", "a3", "ult"]:
			var ab: Dictionary = c["abilities"][slot]
			var tag: String = "ULT" if slot == "ult" else slot.to_upper()
			# Dense roster: ability names only — full text lives one hover away.
			var line: String = "%s %s" % [tag, ab["name"]] if dense else "%s %s — %s" % [tag, ab["name"], ab["desc"]]
			var l := _lbl(col, line, 11 if dense else 12, Color(0.65, 0.7, 0.8))
			if dense:
				l.tooltip_text = ab["desc"]
				l.mouse_filter = Control.MOUSE_FILTER_STOP
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		_btn(col, "  %s  (%d)" % [c["name"], idx], func() -> void: pick_class(id), Color(0.6, 1.0, 0.6))
		idx += 1


func pick_class(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.on_class_chosen(id)


# --------------------------------------------------------------- inventory ---

func open_inventory(tab := "gear") -> void:
	var vbox := _open("Inventory — %d gold" % game.player.gold, 1120, 640)
	current = "inventory"

	# Subtabs: gear management / full character sheet.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Gear  ", func() -> void: open_inventory("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Stats  ", func() -> void: open_inventory("stats"),
		Color(0.95, 0.85, 0.5) if tab == "stats" else Color(0.6, 0.6, 0.6))
	if tab == "stats":
		_build_stats_tab(vbox, game.player)
		return
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
	_lbl(left, "(full character sheet in the Stats tab)", 12, Color(0.55, 0.55, 0.6))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	# ------------------------------------------------------------- bag ---
	# One WoW-style slot grid for EVERYTHING carried: gear, gems
	# (stacked by kind for display; each gem still owns a slot) and
	# consumables, plus dark squares for the free space. Capacity comes
	# from the equipped bag; bigger bags drop from elites.
	var p: Player = game.player
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	right.add_child(head)
	var bh := _lbl(head, "BAG — [%s] %s  (%d/%d)" % [p.bag["grade"], p.bag["name"],
		p.bag_used(), p.bag_capacity()], 16, Items.GRADE_COLOR[p.bag["grade"]])
	bh.custom_minimum_size = Vector2(360, 0)
	if not p.gem_bag.is_empty():
		var auto_cb := func() -> void:
			var n: int = game.player.auto_synthesize()
			game.spawn_text(game.player.global_position + Vector2(0, -60),
				"%d GEM UPGRADES" % n if n > 0 else "NOTHING TO MERGE", Color(0.6, 0.9, 1.0))
			open_inventory()
		var ab := _btn(head, "⚒ Auto-synthesize ALL", auto_cb, Color(0.6, 0.9, 1.0))
		ab.tooltip_text = "Merge every 3-of-a-kind until nothing can be merged.\nGems socketed in your equipped gear level up FIRST\n(each uses two matching gems from the bag)."
	_lbl(right, "Gear: click to equip · gems: socket via an EQUIPPED item, click a x3 stack to synthesize · bigger bags drop from ELITES", 12, Color(0.55, 0.55, 0.6))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for item in p.backpack:
		var it: Dictionary = item
		_bag_slot(grid, Art.icon_for(it), "", Items.GRADE_COLOR[it["grade"]],
			"%s\n%s\n\nCLICK TO EQUIP — diff:\n%s" % [Items.title(it), Items.describe(it), _diff_tip(it)],
			func() -> void:
				game.player.equip(it)
				open_inventory())
	for c in p.consumables:
		var cc: Dictionary = c
		_bag_slot(grid, null, "⟲", Items.GRADE_COLOR[str(cc.get("grade", "B"))],
			"%s\n%s\n\nCLICK TO USE" % [str(cc["name"]), str(cc.get("desc", ""))],
			func() -> void:
				game.player.use_consumable(cc)
				open_inventory())
	var groups := _gem_groups()
	for key in _sorted_gem_keys(groups):
		var group: Dictionary = groups[key]
		var g: Dictionary = group["gem"]
		var count: int = group["count"]
		var tip := "%s  x%d" % [Items.gem_title(g), count]
		var gem_cb := func() -> void: pass
		if count >= 3 and g["lvl"] < Items.GEM_MAX_LEVEL:
			tip += "\n\nCLICK: synthesize three into one Lv%d" % (g["lvl"] + 1)
			gem_cb = func() -> void:
				game.player.synthesize(g["stat"], g["lvl"])
				open_inventory()
		else:
			tip += "\n\nSocket it: click an EQUIPPED item on the left"
		_bag_slot(grid, null, ("◆%d" % count) if count > 1 else "◆", Items.gem_color(g), tip, gem_cb)
	for i in maxi(0, p.bag_capacity() - p.bag_used()):
		_bag_empty(grid)
	_hint(vbox, "ESC / I to close")


## One square bag slot: an item icon or a colored glyph, colored border,
## hover tooltip, click action.
func _bag_slot(grid: GridContainer, icon: Texture2D, glyph: String, color: Color,
		tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.text = glyph
		b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", color)
	b.tooltip_text = tip
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.12, 0.92)
	sb.border_color = Color(color, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.17, 0.17, 0.23, 0.95)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.pressed.connect(cb)
	grid.add_child(b)
	return b


## A dark square: one free bag slot.
func _bag_empty(grid: GridContainer) -> void:
	var pnl := Panel.new()
	pnl.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.7)
	sb.border_color = Color(0.25, 0.25, 0.3, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	pnl.add_theme_stylebox_override("panel", sb)
	grid.add_child(pnl)


## Gem-group keys ordered by stat name, then level descending —
## a stable, scannable order no matter what the bag looks like.
func _sorted_gem_keys(groups: Dictionary) -> Array:
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b) -> bool:
		var ga: Dictionary = groups[a]["gem"]
		var gb: Dictionary = groups[b]["gem"]
		if ga["stat"] == gb["stat"]:
			return int(ga["lvl"]) > int(gb["lvl"])
		return String(ga["stat"]) < String(gb["stat"]))
	return keys


## Full character sheet: every stat on its own row, with a hover tooltip
## explaining what it does — so players learn what to invest in.
func _build_stats_tab(vbox: VBoxContainer, p: Player) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	_lbl(list, "ATTRIBUTES  (hover any stat to learn what it does)", 16, Color(0.95, 0.85, 0.5))
	for attr in Classes.ATTR_NAMES:
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == attr
		_stat_row(list, "%s%s" % [attr, "  ★" if is_primary else ""], str(p.attr_total(attr)),
			Classes.attr_help(p.cls, attr),
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9))
	if p.unspent_attr > 0:
		_lbl(list, "     %d unspent points — allocate in the skill menu (T)" % p.unspent_attr, 13, Color(0.5, 1.0, 0.5))

	_lbl(list, "COMBAT", 16, Color(0.95, 0.85, 0.5))
	var rows := [
		["Combat Rating", str(p.combat_rating()), "Your whole build boiled down to one power number: attack, crits, penetration, defenses, mobility — everything counts."],
		["ATK (%s)" % Classes.CLASSES[p.cls]["dmg_type"], str(int(p.atk)), "Base damage of all your abilities. Your class deals %s damage." % Classes.CLASSES[p.cls]["dmg_type"]],
		["Crit chance", "%d%%" % int(Stats.crit_curve(p.crit) * 100), "Chance a hit deals bonus damage. Diminishing returns past 70%. DoTs and TRUE damage never crit."],
		["Crit damage", "x%.2f" % p.crit_dmg, "How hard your critical hits land."],
		["Combo", "%d%%" % int(Stats.combo_curve(p.combo) * 100), "Chance an ability skips its cooldown AND refunds mana (capped at 60%). Ultimates excluded."],
		["Phys Pen", str(int(p.physpen)), "Ignores enemy physical resistance. Any EXCESS beyond their resistance becomes bonus damage."],
		["Magic Pen", str(int(p.magpen)), "Ignores enemy magic resistance. Any EXCESS beyond their resistance becomes bonus damage."],
		["DEX", str(int(p.dex)), "Hit rate: reduces the enemy's chance to EVADE your attacks. Only matters against evasive enemies (spiders, witches)."],
		["Haste", "%d%%" % int(p.cdr * 100), "Reduces all ability cooldowns."],
	]
	for r in rows:
		_stat_row(list, r[0], r[1], r[2])

	_lbl(list, "DEFENSE", 16, Color(0.95, 0.85, 0.5))
	var rows2 := [
		["HP", "%d / %d" % [int(p.hp), int(p.max_hp)], "Your health. Dying returns you to the last safe room you visited — and the room you fell in resets."],
		["Mana", "%d / %d" % [int(p.mp), int(p.max_mp)], "Fuel for abilities. Regenerates over time (mages regenerate 50% faster)."],
		["Phys Res", str(int(p.physres)), "Reduces physical damage taken (diminishing returns — never reaches 100%)."],
		["Magic Res", str(int(p.magres)), "Reduces magic damage taken (diminishing returns). TRUE damage ignores all resistances."],
		["Crit Res", str(int(p.critres)), "Shaves the enemy's chance to critically hit you."],
		["Evasion", "%d%%" % int(Stats.eva_curve(p.eva) * 100), "Chance to fully dodge a hit. Countered by the attacker's DEX. Capped at 60%."],
	]
	for r in rows2:
		_stat_row(list, r[0], r[1], r[2])

	_lbl(list, "UTILITY", 16, Color(0.95, 0.85, 0.5))
	var rows3 := [
		["Speed", str(int(p.speed)), "How fast you move. Ice patches boost it; void rifts slow it."],
		["Lifesteal", "%d%%" % int(p.lifesteal * 100), "Heals you for a share of damage dealt. AoE hits only steal a third."],
		["Greed", "%d%%" % int(Stats.greed_gold(p.greed) * 100), "Bonus gold from every source. Above 30% it also nudges chest drop rates. Strong diminishing returns past 50%."],
	]
	for r in rows3:
		_stat_row(list, r[0], r[1], r[2])

	# The shard's opinion of you — surfaced here after playtest round 6
	# ("I can't even SEE this stat"): the number, its band, and what
	# actually moves it.
	_lbl(list, "SHARD", 16, Color(0.95, 0.85, 0.5))
	var res_band := String(Story.res_band(p.resonance))
	var res_word: String = {"steady": "Steady — the shard hums warm",
		"tempted": "Tempted — the shard whispers"}.get(res_band, "Quiet — the shard is undecided")
	var res_col: Color = {"steady": Color(0.6, 1.0, 0.6),
		"tempted": Color(1.0, 0.6, 0.6)}.get(res_band, Color(0.85, 0.85, 0.9))
	_stat_row(list, "Resonance", "%+d   (%s)" % [int(p.resonance), res_word],
		"How the shard resonates with your CHOICES, from -100 (Temptation) to +100 (Virtue). Kindness, mercy and honest work raise it; cruelty, theft and grave-robbing lower it. The world reads it before you do: merchants price you 10% kinder when it's high and 10% warier when it's low, some dialogue options only open at certain bands, and NPCs react to what the shard says about you.", res_col)

	# (T5) Faction standing — who in Vaelscar trusts you, and how much.
	_lbl(list, "FACTIONS", 16, Color(0.95, 0.85, 0.5))
	var factions := [
		["accord", "Ember Accord", "joined_accord", "Maren's loyalists: gather the shards, break the hollow throne for good."],
		["cinderborn", "Cinderborn", "joined_cinderborn", "Old-regime nobles: order needs a crown — find a worthy head for it."],
		["wildfang", "Wildfang Tribes", "", "Fangmaw's beastkin descendants. They remember who opens doors. (Not joinable.)"],
		["choir", "Hollow Choir", "", "Blight-plague survivors turned faithful. They do not recruit; they wait. (Not joinable.)"],
	]
	for f in factions:
		var standing: int = int(p.faction_standing.get(f[0], 0))
		var joined: bool = f[2] != "" and game.get_flag(f[2], false)
		var val := "%s%d%s" % ["+" if standing > 0 else "", standing, "   ⚑ JOINED" if joined else ""]
		var col := Color(0.6, 1.0, 0.6) if standing > 0 else (Color(1.0, 0.6, 0.6) if standing < 0 else Color(0.85, 0.85, 0.9))
		_stat_row(list, f[1], val, f[3], col)
	_hint(vbox, "ESC / I to close")


## One stat line: name, value, and a hover tooltip that explains it.
func _stat_row(parent: Node, stat_name: String, value: String, tip: String, color := Color(0.85, 0.85, 0.9)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = tip
	parent.add_child(row)
	var n := _lbl(row, stat_name, 14, color)
	n.custom_minimum_size = Vector2(220, 0)
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	n.tooltip_text = tip
	var v := _lbl(row, value, 14, Color(1, 1, 1))
	v.custom_minimum_size = Vector2(160, 0)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.tooltip_text = tip
	var hint := _lbl(row, "🛈", 12, Color(0.5, 0.55, 0.65))
	hint.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.tooltip_text = tip


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
			# Scrollable two-column grid — big bags stay inside the panel.
			var groups := _gem_groups()
			var iscroll := ScrollContainer.new()
			iscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			iscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(iscroll)
			var igrid := GridContainer.new()
			igrid.columns = 2
			igrid.add_theme_constant_override("h_separation", 12)
			igrid.add_theme_constant_override("v_separation", 4)
			igrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			iscroll.add_child(igrid)
			for key in _sorted_gem_keys(groups):
				var group: Dictionary = groups[key]
				var g2: Dictionary = group["gem"]
				var ins_cb := func() -> void:
					game.player.embed_gem_into(item, g2)
					open_item_panel(item)
				var ib := _btn(igrid, "%s  x%d — insert" % [Items.gem_title(g2), group["count"]], ins_cb, Items.gem_color(g2))
				ib.clip_text = true
				ib.custom_minimum_size = Vector2(400, 0)
				ib.tooltip_text = "%s  x%d" % [Items.gem_title(g2), group["count"]]
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

func open_skills(tab := "talents") -> void:
	var p: Player = game.player
	var vbox := _open("%s — %s" % [Classes.CLASSES[p.cls]["name"], "Skill Tree" if tab == "talents" else "Attributes"], 1120, 640)
	current = "skills"

	# Subtabs: talents / attribute allocation.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Talents (%d pts)  " % p.skill_points, func() -> void: open_skills("talents"),
		Color(0.95, 0.85, 0.5) if tab == "talents" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Attributes (%d pts)  " % p.unspent_attr, func() -> void: open_skills("attributes"),
		Color(0.95, 0.85, 0.5) if tab == "attributes" else Color(0.6, 0.6, 0.6))

	if tab == "attributes":
		_build_attributes_tab(vbox, p)
		return

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
	# One-click loadouts: opt every ability into a single theme.
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 10)
	vbox.add_child(arow)
	var al := _lbl(arow, "All-in:", 14, Color(0.7, 0.72, 0.78))
	al.custom_minimum_size = Vector2(60, 0)
	_btn(arow, " Base ", func() -> void:
		game.player.set_all_themes("")
		open_skills(), Color(0.85, 0.85, 0.9), p.themes_known > 0)
	for i2 in Classes.THEMES[p.cls].size():
		var th: Dictionary = Classes.THEMES[p.cls][i2]
		var tid: String = th["id"]
		var t_unlocked: bool = i2 < p.themes_known
		_btn(arow, " %s " % th["name"], func() -> void:
			game.player.set_all_themes(tid)
			open_skills(), th["color"] if t_unlocked else Color(0.4, 0.4, 0.45), t_unlocked)
	_hint(vbox, "ESC / T to close — themes change how your abilities behave")


## Attribute allocation: +1 point per level. The four attributes
## convert at CLASS scaling ratios; the substat rows convert 1:1 for
## every class (combo is deliberately not purchasable).
func _build_attributes_tab(vbox: VBoxContainer, p: Player) -> void:
	_lbl(vbox, "Every level grants 1 attribute point. Attributes convert by class — %s scales best with %s — or pour points straight into a substat." % [Classes.CLASSES[p.cls]["name"], Classes.CLASSES[p.cls]["primary"]], 13, Color(0.6, 0.62, 0.68))
	_lbl(vbox, "Unspent: %d points" % p.unspent_attr, 18, Color(0.5, 1.0, 0.5) if p.unspent_attr > 0 else Color(0.6, 0.6, 0.65))
	for attr in Classes.ATTR_NAMES:
		var a: String = attr
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == a
		_attr_row(vbox, p, a, "%s  %d%s" % [a, p.attr_points[a], "  ★" if is_primary else ""],
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9),
			Classes.attr_text(p.cls, a))
	_lbl(vbox, "SUBSTATS", 15, Color(0.95, 0.85, 0.5))
	for attr in Classes.SUBSTAT_NAMES:
		var a: String = attr
		_attr_row(vbox, p, a, "%s  %d" % [a, p.attr_points[a]],
			Color(0.75, 0.8, 0.92), Classes.substat_text(a))
	_lbl(vbox, "YOUR STATS", 16, Color(0.95, 0.85, 0.5))
	_lbl(vbox, p.stat_sheet(), 13, Color(0.75, 0.78, 0.85))
	_hint(vbox, "ESC / T to close")


## One allocation row: name + points, +1/+5 spend buttons, description.
func _attr_row(vbox: VBoxContainer, p: Player, a: String, label: String,
		color: Color, desc_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	var name_l := _lbl(row, label, 17, color)
	name_l.custom_minimum_size = Vector2(140, 0)
	_btn(row, " +1 ", func() -> void:
		game.player.add_attr_points(a, 1)
		open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
	_btn(row, " +5 ", func() -> void:
		game.player.add_attr_points(a, 5)
		open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
	var desc := _lbl(row, desc_text, 13, Color(0.68, 0.7, 0.78))
	desc.custom_minimum_size = Vector2(620, 0)


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
		# What this theme does to THIS ability — every pair is unique.
		var vdesc := Classes.variant_desc(p.cls, slot, theme["id"])
		var vfx := Classes.fx_text(Classes.ability_fx(p.cls, slot, theme["id"]))
		var d := _lbl(vbox, vdesc + ("\n" + vfx if vfx != "" else ""), 12,
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
		# Rooms may declare their stock tier; otherwise it climbs with
		# how deep the room sits (works for any chapter).
		var tier: String = String(game.zones[zone].get("shop_tier",
			["wood", "silver", "silver", "gold"][clampi(zone, 0, 3)]))
		var stock: Array = []
		for i in 3:
			stock.append(Items.roll_item(tier, rng, game.player.cls, game.loot_cap()))
		game.shop_stock[zone] = stock

	var p: Player = game.player
	var vbox := _open("Merchant — you have %d gold" % p.gold, 1120, 600)
	current = "shop"
	# (T7) The merchant reads the shard before quoting a price.
	match Story.res_band(p.resonance):
		"steady":
			_lbl(vbox, "\"For YOU? Fair rates, friend — the road speaks well of you.\"  (prices 10% kinder)", 14, Color(0.6, 0.9, 0.6))
		"tempted":
			_lbl(vbox, "\"Prices are... firm today. Nothing personal — the till gets nervous around your sort.\"  (prices 10% wary)", 14, Color(1.0, 0.65, 0.55))
		_:
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

	var haggle: float = game.band_price_mult()
	var potion_cost := int(ceil(25.0 * haggle))
	var buy_potion := func() -> void:
		if p.gold >= potion_cost and p.potions < Balance.POTION_MAX:
			p.gold -= potion_cost
			p.potions += 1
			game.sfx("potion")
		open_shop(zone)
	_btn(buy, "Health Potion — %d gold  (you have %d, max 5)" % [potion_cost, p.potions],
		buy_potion, Color(1.0, 0.5, 0.5), p.gold >= potion_cost and p.potions < Balance.POTION_MAX)

	for item in game.shop_stock[zone]:
		var it: Dictionary = item
		var cost := int(ceil(Items.price(it) * 2 * haggle))
		var buy_item := func() -> void:
			if p.gold >= cost:
				if p.bag_used() >= p.bag_capacity():
					game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
				else:
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


# --------------------------------------------------------------- map (M) ---

# Fog-of-war rules (DESIGN.md): only VISITED rooms render. Unexplored
# exits off visited rooms show as stubs — you can see THAT there's
# somewhere left to go without being shown what's there. A boss door
# gets its marker only once it has been seen. Fast travel goes to
# visited safe rooms; combat rooms are never travel targets.
const MAP_TYPE_COLOR := {
	"safe": Color(0.30, 0.45, 0.30), "merchant": Color(0.32, 0.44, 0.34),
	"social": Color(0.30, 0.42, 0.38), "resonance": Color(0.30, 0.36, 0.50),
	"dead_end": Color(0.34, 0.34, 0.38), "combat": Color(0.42, 0.30, 0.28),
	"boss": Color(0.38, 0.26, 0.40),
}
const MAP_TYPE_ICON := {
	"safe": "⌂", "merchant": "⚖", "social": "…", "resonance": "✦",
	"dead_end": "", "combat": "", "boss": "☠",
}


func open_map() -> void:
	var vbox := _open("Map — %s" % String(Story.chapter(game.chapter_id)["name"]), 1180, 640)
	current = "map"
	_lbl(vbox, "Rooms you have entered. ◆ you are here · ☠ a boss door you've seen · lit rooms are safe camps — click one to travel there. Notches on a room's edge are its doorways; stubs jut toward rooms you haven't explored.", 13, Color(0.7, 0.72, 0.78))

	var board := Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(1120, 440)
	vbox.add_child(board)

	# Extent: visited rooms plus one cell of breathing room for stubs.
	var have_any := false
	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-(1 << 20), -(1 << 20))
	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		have_any = true
		var c: Vector2i = game.rooms[i]["coord"]
		min_c = Vector2i(mini(min_c.x, c.x - 1), mini(min_c.y, c.y - 1))
		max_c = Vector2i(maxi(max_c.x, c.x + 1), maxi(max_c.y, c.y + 1))
	if not have_any:
		_lbl(vbox, "Nothing charted yet.", 14)
		_hint(vbox, "ESC / M to close")
		return
	var cols := max_c.x - min_c.x + 1
	var rows := max_c.y - min_c.y + 1
	var cw := clampf((1120.0 - (cols - 1) * 10.0) / cols, 34.0, 120.0)
	var ch := clampf((430.0 - (rows - 1) * 10.0) / rows, 26.0, 84.0)
	var org := Vector2(maxf(0.0, (1120.0 - cols * (cw + 10.0)) / 2.0),
		maxf(0.0, (430.0 - rows * (ch + 10.0)) / 2.0))
	var cell_pos := func(c: Vector2i) -> Vector2:
		return org + Vector2((c.x - min_c.x) * (cw + 10.0), (c.y - min_c.y) * (ch + 10.0))

	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		var c: Vector2i = game.rooms[i]["coord"]
		var p: Vector2 = cell_pos.call(c)

		# Connections + unexplored-exit stubs (drawn under the cells).
		for dir in game.rooms[i]["exits"].keys():
			var nb: int = game.neighbor(i, String(dir))
			if nb < 0:
				continue
			var delta: Vector2i = Game.DIRS[dir]
			var mid := p + Vector2(cw / 2.0, ch / 2.0)
			var full := Vector2(delta.x * (cw + 10.0), delta.y * (ch + 10.0))
			var nb_visited: bool = game.visited.get(nb, false)
			var link := ColorRect.new()
			link.color = Color(0.55, 0.5, 0.4) if nb_visited else Color(0.4, 0.38, 0.34)
			var reach := 1.0 if nb_visited else 0.62  # stub: juts toward the unknown
			var to := mid + full * 0.5 * reach
			var thick := 5.0
			link.position = Vector2(minf(mid.x, to.x) - thick / 2.0, minf(mid.y, to.y) - thick / 2.0)
			link.size = Vector2(absf(to.x - mid.x) + thick, absf(to.y - mid.y) + thick)
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board.add_child(link)
			# A seen-but-unentered BOSS door earns its skull early.
			if not nb_visited and game.room_type(nb) == "boss" and game.door_seen.get(nb, false):
				var skull := _lbl(board, "☠", 15, Color(1.0, 0.55, 0.6))
				skull.position = to - Vector2(7, 12)
				skull.size = Vector2(20, 20)

	for i in game.zone_count:
		if not game.visited.get(i, false):
			continue
		var c: Vector2i = game.rooms[i]["coord"]
		var p: Vector2 = cell_pos.call(c)
		var t: String = game.room_type(i)
		var can_travel: bool = game.travel_target(i) and not game.barrier_active

		if i == game.cur_room:
			var here := ColorRect.new()  # gold frame around the current room
			here.color = Color(0.95, 0.85, 0.5)
			here.position = p - Vector2(3, 3)
			here.size = Vector2(cw + 6, ch + 6)
			here.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board.add_child(here)

		if can_travel:
			var room_idx: int = i
			var b := Button.new()
			b.position = p
			b.size = Vector2(cw, ch)
			b.tooltip_text = "%s — travel here" % game.zones[i]["name"]
			var sb := StyleBoxFlat.new()
			sb.bg_color = MAP_TYPE_COLOR.get(t, Color(0.3, 0.3, 0.3)).lightened(0.18)
			sb.set_corner_radius_all(4)
			b.add_theme_stylebox_override("normal", sb)
			var sbh: StyleBoxFlat = sb.duplicate()
			sbh.bg_color = sb.bg_color.lightened(0.2)
			b.add_theme_stylebox_override("hover", sbh)
			b.pressed.connect(func() -> void:
				close()
				game.fast_travel(room_idx))
			board.add_child(b)
		else:
			var cell := ColorRect.new()
			cell.color = MAP_TYPE_COLOR.get(t, Color(0.3, 0.3, 0.3))
			cell.position = p
			cell.size = Vector2(cw, ch)
			cell.tooltip_text = String(game.zones[i]["name"])
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			board.add_child(cell)

		# Doorway notches: every exit of a visited room gets a bright pip
		# on that edge of its cell — clear the room, glance at the map,
		# and you KNOW which walls have doors (playtest round 3).
		for dir in game.rooms[i]["exits"].keys():
			var pip := ColorRect.new()
			pip.color = Color(0.95, 0.85, 0.5) if i == game.cur_room else Color(0.78, 0.74, 0.6)
			var horiz: bool = String(dir) in ["N", "S"]
			pip.size = Vector2(12, 4) if horiz else Vector2(4, 12)
			match String(dir):
				"N": pip.position = p + Vector2(cw / 2.0 - 6.0, -1.0)
				"S": pip.position = p + Vector2(cw / 2.0 - 6.0, ch - 3.0)
				"W": pip.position = p + Vector2(-1.0, ch / 2.0 - 6.0)
				"E": pip.position = p + Vector2(cw - 3.0, ch / 2.0 - 6.0)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board.add_child(pip)

		var icon_text: String = MAP_TYPE_ICON.get(t, "")
		if t == "boss":
			var kind := String(game.zones[i].get("boss", ""))
			if kind != "" and game.boss_done.get(kind, false):
				icon_text = "✓"
		if i == game.cur_room:
			icon_text = "◆"
		if icon_text != "":
			var il := _lbl(board, icon_text, 15, Color(0.95, 0.92, 0.8))
			il.position = p + Vector2(0, ch / 2.0 - 11.0)
			il.size = Vector2(cw, 22)
			il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			il.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lbl(vbox, "◆ %s%s" % [game.zones[game.cur_room]["name"],
		"   —   the doors are sealed mid-fight" if game.barrier_active else ""],
		14, Color(0.95, 0.85, 0.5))
	_hint(vbox, "ESC / M to close")


# ------------------------------------------------------------------- codex ---

const BOSS_KINDS := ["fangmaw", "morwen", "vargoth",
	"stormwarden", "choirmother", "nullwarden",  # (T4) ch2 content bosses
	"sexton", "vess", "saint_varo"]  # ch3 Unburied Vale (BOSSES.md)

## Codex screens live in ui/codex.gd.
func open_codex(tab := "monsters") -> void:
	UICodex.open(self, tab)


# ---------------------------------------------------------------- dev mode ---

## The mailbox (dropped-loot letters, gifts) lives in ui/mailbox.gd.
func open_mailbox() -> void:
	UIMailbox.open(self)


## Debug panel (F1, only when launched via dev_mode.bat) — ui/dev_panel.gd.
func open_dev() -> void:
	UIDevPanel.open(self)


# ---------------------------------------------------------------- keybinds ---

func open_keybinds() -> void:
	var vbox := _open("Keybinds — click an action, then press a key", 700, 520)
	current = "keybinds"
	var actions := {
		"a1": "Ability 1", "a2": "Ability 2", "a3": "Ability 3", "ult": "Ultimate",
		"potion": "Drink potion", "interact": "Talk / interact",
		"inventory": "Inventory", "skills": "Skill tree", "codex": "Codex",
		"map": "Map", "target": "Switch target lock",
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
		if current == "chapter_select":
			var chids: Array = Story.CHAPTER_LIST.keys()
			var chnum: int = event.keycode - KEY_1
			if chnum >= 0 and chnum < chids.size() \
					and game.chapter_available(String(chids[chnum]), chapter_replay):
				if chapter_replay:
					var chid: String = chids[chnum]
					if root:
						root.queue_free()
						root = null
					current = ""
					game.replay_chapter(chid)
				else:
					pick_chapter(chids[chnum])
				get_viewport().set_input_as_handled()
				return
		if current == "class_select":
			var ids: Array = Classes.CLASSES.keys()
			var num: int = event.keycode - KEY_1
			if num >= 0 and num < ids.size():
				pick_class(ids[num])
				get_viewport().set_input_as_handled()
			return  # can't ESC out of class select
		if current in ["title", "class_select"] \
				or (current == "chapter_select" and not chapter_replay):
			return  # boot menus: no escaping into a paused void
		if event.keycode == KEY_ESCAPE \
				or (current == "inventory" and event.keycode == game.binds["inventory"]) \
				or (current == "skills" and event.keycode == game.binds["skills"]) \
				or (current == "codex" and event.keycode == game.binds["codex"]) \
				or (current == "map" and event.keycode == game.binds.get("map", KEY_M)) \
				or (current == "dev" and event.keycode == KEY_F1):
			if current == "theme_pick":
				open_skills()  # back to the tree, not out of the menu
			elif current == "item_panel":
				open_inventory()  # back to the bag
			elif current == "settings":
				_settings_back()  # back to wherever settings was opened from
			elif current == "confirm" \
					or (current == "chapter_select" and chapter_replay):
				open_pause()  # back to the system menu, not out of it
			else:
				close()
			get_viewport().set_input_as_handled()
