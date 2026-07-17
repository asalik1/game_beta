class_name Menus extends CanvasLayer
## All full-screen menus: class select, inventory, skill tree, merchant
## shop, evolution choice, and keybinding. One menu open at a time;
## opening a menu pauses the game.
##
## Menus are per-client UI (MULTIPLAYER.md §5.6): every player read in here
## is `game.local_player` — the character on THIS screen. Solo they are the
## same object; in co-op your inventory is never a teammate's.

# The lobby module (MP-08) is loaded by PATH, not class_name: adding a
# class_name would demand a --import pass, and the lobby ships mid-wave.
const UILobby := preload("res://scripts/ui/lobby.gd")
# The transport autoload's SCRIPT, for NET_VERSION only (the bare
# `NetworkManager` global doesn't exist under check_compile — MP-05).
const NetManager := preload("res://scripts/net/net_manager.gd")

var game: Game
var root: Control = null          # the currently open panel (null = closed)
var detail_popover: Control = null  # click-to-reveal item/gem/shop popover
var detail_return := ""             # screen the popover overlays (restored on close)
var _popover_box: PanelContainer = null  # the current popover's panel (for re-anchoring)
var current := ""
var _closable_now := false        # does the open panel have a ✕ / click-outside exit?
var listening_action := ""        # keybind screen: waiting for a key press
var shop_zone := -1
var shop_tab := "buy"             # shop: which full-width tab is showing (persists across refreshes)
var shop_junk_tier := "F"         # sell tab: floor grade the one-click junk-sell dumps (that grade and below)
var _smith_msg := ""              # smith: last upgrade result, shown once in the panel (no silent effects)
var _smith_msg_color := Color.WHITE
var _reforge_msg := ""            # reforge bench: last quench/craft result, shown in the item panel
var _reforge_msg_color := Color.WHITE
var inv_cat := "all"              # inventory: last bag category filter (survives item-panel rebuilds)
var title_stage := "cover"        # boot title: "cover" (splash) -> "slots" (roster)
var chapter_replay := false       # chapter select opened from the pause menu
var dev_boss_mode := 1            # dev panel boss spawn level: 0 story, 1 my Lv (default), 2 +10, 3 +20
var dev_boss_level_override := 0  # dev panel: exact level for NEW boss spawns (0 = off)
var dev_tab := "character"        # dev panel: which subtab is showing (persists across refreshes)
var lobby := {}                   # Play Together flow state (ui/lobby.gd): stage, picks, code, msg


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


func is_open() -> bool:
	return root != null


func close() -> void:
	if root:
		root.queue_free()
		root = null
	detail_popover = null
	listening_action = ""
	# Boot menus unpause only once the game actually starts. The lobby
	# (MP-08) is boot-context too until a session begins play.
	if not (current in ["class_select", "title"]) \
			and not (current == "chapter_select" and not chapter_replay) \
			and not (current == "lobby" and not game.play_started):
		game.request_pause(false)
	current = ""
	# Restore the HUD once the menu is gone — but only in actual play (boot
	# menus run over the cover, where the HUD should stay hidden).
	if game and game.hud:
		game.hud.visible = game.play_started
	game.talk_cd = maxf(game.talk_cd, 0.35)  # debounce the reopen hotkeys
	if game.play_started:
		game.autosave()  # menus are where gear/talents/purchases change


# ------------------------------------------------------------ scaffolding ---

## `closable` screens (inventory, pause, codex, quest log, mailbox) get a red
## ✕ in the panel's top-right AND close when you click the dimmed area outside
## the box — so ESC is no longer their only exit (and is retired for them).
func _open(title: String, w := 960.0, h := 560.0, closable := false) -> VBoxContainer:
	if root:
		root.queue_free()
	game.request_pause(true)
	_closable_now = closable  # so _hint tells the truth about the exits on touch
	# Drop any held touch input NOW: the touch HUD disables itself on its next
	# _process (it reads is_open()), and this closes that one-frame window — a
	# missed finger-release would leave the joystick "stuck held" and deaf to new
	# touches after the menu closes. Solo also freezes the HUD mid-gesture via the
	# pause; a session never pauses (§5.4), so the HUD's overlay gate is the one
	# thing stopping it there.
	if game._touch_hud != null:
		game._touch_hud._release_everything()
	# Hide the gameplay HUD while a menu is up: it sits on a lower CanvasLayer,
	# so the dim only fades it — the quest banner and quickbar still bleed
	# through behind the panel and crowd the title and both shop columns.
	if game and game.hud:
		game.hud.visible = false
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	detail_popover = null  # any popover was a child of the old root; drop the ref

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	if closable:
		# Click-off-the-box to close. The panel sits on top and absorbs its
		# own clicks, so only clicks in the surrounding dim reach here.
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				close())
	root.add_child(dim)

	# Boot menus (roster / chapter / class select before play starts):
	# keep the cover's night behind the panel instead of letting the
	# not-yet-a-game village and HUD peek through the dim.
	if not game.play_started:
		var night := ColorRect.new()
		night.color = Color(0.02, 0.015, 0.045)
		night.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(night)
		root.move_child(night, 0)

	# Dressed panel (theme pass): the shared chrome lives in UITheme —
	# gold border + bronze bevel + top sheen — and the root carries the
	# code-built widget Theme, so every Button/HSlider/ScrollBar on any
	# screen inherits the skin with no per-screen styling.
	UITheme.apply(root)
	UITheme.panel(root, Vector2(640 - w / 2 - 3, 360 - h / 2 - 3), Vector2(w + 6, h + 6))

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(640 - w / 2, 360 - h / 2) + Vector2(24, 16)
	vbox.size = Vector2(w - 48, h - 32)
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	var tl := Label.new()
	tl.text = title
	# Long titles (e.g. a multi-boss "Victory — ..." mail subject) must wrap,
	# not spill off-screen. A non-wrapping title also reports its full line as
	# minimum width, which inflates the whole VBox past the panel and makes the
	# body labels below it stop wrapping too — so autowrap here fixes both.
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.title(tl, 28)  # display font; ~26px optical in the pixel face
	tl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vbox.add_child(tl)
	UITheme.rule(vbox)  # header underline: gold, fading right

	if closable:
		# Red ✕ pinned to the panel's top-right corner (added last = on top).
		var xbtn := Button.new()
		xbtn.text = "✕"
		xbtn.flat = true
		xbtn.focus_mode = Control.FOCUS_NONE
		xbtn.add_theme_font_size_override("font_size", 22)
		xbtn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
		xbtn.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.75))
		xbtn.size = Vector2(36, 32)
		xbtn.position = Vector2(640 - w / 2 - 3 + w + 6 - 42, 360 - h / 2 - 3 + 8)
		xbtn.tooltip_text = "Close"
		xbtn.pressed.connect(func() -> void:
			game.sfx("ui_click")
			close())
		root.add_child(xbtn)
	# Under touch, let a finger-swipe on the content scroll (not just the scrollbar).
	# Deferred so it runs AFTER the caller fills this panel with its scroll content.
	call_deferred("_enable_all_touch_scroll", root)
	return vbox


## Touch has no drag-scroll by default: content Controls default to MOUSE_FILTER_STOP,
## which eats the swipe before the ScrollContainer sees it. Walk every ScrollContainer
## in a freshly built panel and set its content children to PASS so the drag propagates
## up (Godot cancels the child press once the scroll takes over). Touch mode only.
func _enable_all_touch_scroll(node: Node) -> void:
	if game == null or not game.touch_mode or node == null:
		return
	_scan_touch_scroll(node)


func _scan_touch_scroll(node: Node) -> void:
	if node is ScrollContainer:
		for child in node.get_children():
			if not (child is ScrollBar):
				_pass_filter(child)
	for c in node.get_children():
		_scan_touch_scroll(c)


func _pass_filter(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for c in node.get_children():
		_pass_filter(c)


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
		b.pressed.connect(func() -> void:
			if game:
				game.sfx("ui_click"))
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
	return Items.diff_text(item, game.local_player.equipment.get(item["slot"]), _awk(item))


## Is this item's class awakened (round 51b)? Governs whether a dormant
## legendary's passive reads as active or LOCKED in player-facing text.
func _awk(item: Dictionary) -> bool:
	return bool(game.get_flag("s_awakened_" + String(item.get("cls", "")), false))


func _hint(vbox: Node, text := "ESC to close") -> void:
	if game and game.touch_mode:
		# Keyboard close-hints (ESC / panel hotkeys) mean nothing on touch; keep any
		# info after the em-dash and swap the key list for the on-screen ways out.
		# Only promise ✕/outside when the panel actually HAS them — otherwise the
		# hint used to lie (keybinds had no exit yet still said "tap ✕ or outside").
		var dash := text.find("—")
		var extra: String = (" " + text.substr(dash)) if dash >= 0 else ""
		if _closable_now:
			text = "Tap ✕ or outside to close" + extra
		else:
			text = ("Use the Back button" + extra).strip_edges()
	var l := _lbl(vbox, text, 13, Color(0.55, 0.55, 0.55))
	l.size_flags_vertical = Control.SIZE_SHRINK_END


# ------------------------------------------------------------ title screen ---

## Boot stage 1 — the opening COVER (see ui/cover.gd). Always shown to
## real players, saves or none; any key/click advances to the roster.
## (Both stages report current == "title": one boot state, two looks.)
func open_title() -> void:
	if root:
		root.queue_free()
	game.request_pause(true)
	if game and game.hud:
		game.hud.visible = false
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	current = "title"
	title_stage = "cover"
	game.set_music("title")
	UICover.build(self, root)
	# The build mark (MULTIPLAYER.md §3.4): quiet, but readable enough that
	# "you're on 0.1.0, I'm on 0.1.1" is a glance, not a debugging session.
	var ver := Label.new()
	ver.text = "build %s" % NetManager.NET_VERSION
	ver.position = Vector2(10, 696)
	ver.size = Vector2(300, 20)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62, 0.8))
	ver.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	ver.add_theme_constant_override("outline_size", 4)
	root.add_child(ver)
	# MP-16: a mid-run host-loss reboots to here — surface the plain-words
	# notice once (staged on the NetworkManager autoload, which survived the
	# reload). Cleared on read, so it greets the player exactly once.
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and String(net.last_session_notice) != "":
		var note := Label.new()
		note.text = String(net.last_session_notice)
		net.last_session_notice = ""
		note.position = Vector2(0, 84)
		note.size = Vector2(1280, 44)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
		note.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		note.add_theme_constant_override("outline_size", 5)
		root.add_child(note)


## Boot stage 2 — the character roster: continue a saved hero from its
## slot, or forge a new one (next free slot). This is the FIRST
## interactive screen; class select only appears for a new character.
func open_slots() -> void:
	var saves: Array = SaveGame.list()
	# Size the panel to its content (audit: 4 saves left the bottom ~45%
	# of a fixed 560 panel as dead black): chrome ≈ 300px (incl. the Play
	# Together row, MP-08) + ~68px a row, clamped to the old height so a
	# 20-slot roster still just scrolls.
	var slots_h := clampf(300.0 + saves.size() * 68.0 + (44.0 if game.dev_mode else 0.0), 380.0, 560.0)
	var vbox := _open("CROWNLESS — your heroes", 760, slots_h)
	current = "title"
	title_stage = "slots"
	game.set_music("roster")  # carries through chapter + class select

	var have_saves := not saves.is_empty()
	_btn(vbox, "  ⚔  New Character  ", func() -> void: open_chapter_select(),
		Color(0.95, 0.85, 0.5))
	# Co-op entry (MP-08, MULTIPLAYER.md §5.1): host or join with a code.
	_btn(vbox, "  ❖  Play Together  ", func() -> void: open_lobby(),
		Color(0.6, 0.9, 1.0))
	UITheme.header(_lbl(vbox, "— CONTINUE —" if have_saves else "No heroes yet — forge your first.",
		15, Color(0.95, 0.85, 0.5) if have_saves else Color(0.6, 0.62, 0.7)))
	# The save list SCROLLS (20 slots + a dev roster overflowed the fixed
	# panel — the bottom buttons must never leave the box).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var save_list := VBoxContainer.new()
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_list.add_theme_constant_override("separation", 4)
	scroll.add_child(save_list)
	for s in saves:
		var slot: int = s["slot"]
		var cls_info: Dictionary = Classes.CLASSES.get(s["cls"], {})
		var cname: String = cls_info.get("name", s["cls"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		save_list.add_child(row)
		var resume := func() -> void:
			if root:
				root.queue_free()
				root = null
			current = ""
			game.load_save(slot)
		# Class portrait at a UNIFORM size. Class sprites have varied native
		# dimensions, and a Button icon draws at NATIVE px — so a big sprite
		# (e.g. paladin) dwarfed a small one in the roster. A fixed-size
		# KEEP_ASPECT TextureRect (same as the class-select screen) fixes it.
		# Dressed 2026-07-10 (audit: "dark smudges"): a framed well, a bigger
		# NEAREST upscale so the pixels read, and a lift out of the murk.
		if cls_info.has("sprite"):
			var pframe := Panel.new()
			pframe.custom_minimum_size = Vector2(64, 64)
			var pfsb := StyleBoxFlat.new()
			pfsb.bg_color = Color(0.12, 0.11, 0.17)
			pfsb.border_color = Color(UITheme.GOLD_DIM, 0.8)
			pfsb.set_border_width_all(2)
			pfsb.set_corner_radius_all(4)
			pframe.add_theme_stylebox_override("panel", pfsb)
			pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pframe)
			var port := TextureRect.new()
			port.texture = Art.tex(cls_info["sprite"])
			# Anchored inset, not manual size: a plain assignment can be
			# stomped when the frame lays out — anchors always re-fit.
			port.set_anchors_preset(Control.PRESET_FULL_RECT)
			port.offset_left = 5
			port.offset_top = 5
			port.offset_right = -5
			port.offset_bottom = -5
			port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			port.modulate = Color(1.3, 1.28, 1.2)  # tonemap-dark sprites need the lift
			pframe.add_child(port)
		var b := _btn(row, "  %s — Lv %d" % [cname, s["level"]], resume, Color(0.6, 1.0, 0.6), true)
		b.custom_minimum_size = Vector2(360, 0)
		b.tooltip_text = Story.quest_text(s["quest"])
		var when := Time.get_datetime_string_from_unix_time(s["saved_at"]).replace("T", "  ")
		var wl := _lbl(row, when, 12, Color(0.55, 0.58, 0.66))
		wl.custom_minimum_size = Vector2(170, 0)
		var erase := func() -> void:
			SaveGame.delete(slot)
			open_slots()  # stay on the roster — empty is a valid state now
		_btn(row, " ✕ ", erase, Color(1, 0.5, 0.5))

	# No spacer: the scroll list absorbs the flexible space, pinning
	# these buttons inside the panel no matter how many saves exist.
	_btn(vbox, "  🔊  Settings  ", func() -> void: open_settings("title"), Color(0.8, 0.85, 0.9))
	_dev_roster_row(vbox)
	_hint(vbox, "Continue a saved hero, or forge a new one")


## Dev launcher row (dev_mode.bat only): batch-create the 6-class
## roster straight from the launcher screens — no need to enter a
## game and open F1 first. Opens a modal that picks a DPS-bench preset; each
## writes one save per class (free slots only, never overwrites), then back.
func _dev_roster_row(vbox: VBoxContainer) -> void:
	if not game.dev_mode:
		return
	_btn(vbox, "  🛠  DEV: Generate benchmark roster ▸  ", func() -> void:
		open_benchmark_roster(), Color(0.6, 0.9, 1.0))


## The benchmark-roster modal: pick a build preset (BenchBuild.PRESETS) and it
## rolls all six classes as that EXACT bench build into free save slots — the same
## builds the DPS bench runs. ESC / Back return to the slot list.
func open_benchmark_roster() -> void:
	var vbox := _open("Benchmark Roster", 760, 480, true)
	current = "benchmark_roster"
	var desc := _lbl(vbox, "Generate all six classes as an exact DPS-bench build — full gear, gems, +plus, talents and theme baked in. Free save slots only; existing saves are never touched.", 13, Color(0.7, 0.74, 0.86))
	desc.custom_minimum_size = Vector2(680, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in BenchBuild.PRESET_ORDER:
		var pkey := String(key)
		var cfg: Dictionary = BenchBuild.PRESETS[pkey]
		var label := "  %s  —  L%d · %s gear · Lv%d gems · +%d%s  " % [
			cfg["name"], cfg["level"], cfg["grade"], cfg["gemlvl"], cfg["plus"],
			"  ·  godroll" if cfg["godroll"] else ""]
		_btn(vbox, label, func() -> void:
			UIDevPanel.create_benchmark_roster(self, pkey)
			game.sfx("equip")
			open_slots(), Color(0.6, 0.9, 1.0))
	_btn(vbox, "  Back  ", func() -> void: open_slots(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back")


# ---------------------------------------------------------------- pause ---

## The system menu (ESC in-game): everything a session needs that isn't
## combat — resume, options, chapter control, and the exits.
func open_pause() -> void:
	var vbox := _open("Paused — " + String(Story.chapter(game.chapter_id)["name"]), 720, 460, true)
	current = "pause"
	var zi := clampi(game.cur_room, 0, game.zone_count - 1)
	_lbl(vbox, "%s, Level %d — %s" % [Classes.CLASSES[game.local_player.cls]["name"],
		game.local_player.level, game.zones[zi]["name"]], 14, Color(0.7, 0.72, 0.78))
	# Everything that has its own HUD icon (mail, daily, quest log, stash, endgame
	# trials) is NOT repeated here — this is now just settings + chapter/session
	# control + the exits. Resume is dropped too: ✕ / tap-outside / ESC already do it.
	# UI strings route through Loc.t (localization pass — a table swap, not a sweep).
	_btn(vbox, "  🔊  " + Loc.t("settings"), func() -> void: open_settings(), Color(0.9, 0.9, 0.95))
	if game.endgame_active:
		# In an endgame run: cash out (keep winnings) or abandon (forfeit).
		var cash := func() -> void:
			open_confirm("Cash out now? You keep everything you've earned this run and return to the title.",
				func() -> void:
					close()
					if game.endgame:
						game.endgame.cash_out())
		_btn(vbox, "  💰  Cash out & bank rewards", cash, Color(1.0, 0.85, 0.4))
	else:
		var restart := func() -> void:
			open_confirm("Restart '%s' from the beginning? Story progress in this chapter resets — your character, gear and Resonance stay." % Story.chapter(game.chapter_id)["name"],
				func() -> void: game.replay_chapter(game.chapter_id))
		_btn(vbox, "  ↺  Restart chapter  (keeps your character)", restart, Color(1.0, 0.8, 0.5))
		_btn(vbox, "  ⚑  Chapter select  (replay any chapter)", func() -> void: open_chapter_select(true), Color(1.0, 0.8, 0.5))
	var to_title := func() -> void:
		open_confirm("Exit to the title screen? Your progress is saved." +
			("\n\nThis ABANDONS the current endgame run — its rewards are forfeit." if game.endgame_active else ""),
			func() -> void: game.exit_to_title())
	_btn(vbox, "  ⇦  Exit to title  (switch character)", to_title, Color(1.0, 0.65, 0.55))
	var quit_game := func() -> void:
		game.autosave()
		get_tree().quit()
	_btn(vbox, "  ✕  Save and quit game", quit_game, Color(1.0, 0.55, 0.5))
	_hint(vbox, "ESC, ✕, or click anywhere outside to resume")


## A single yes/cancel gate in front of anything destructive. Pause-menu
## flows fall back there on cancel; world prompts (shrines, cursed
## chests) pass an on_cancel that just closes.
func open_confirm(msg: String, on_yes: Callable, on_cancel := Callable()) -> void:
	# Size to the message (the Crucible rules overflowed a fixed 320) + closable so the
	# ✕ / tap-outside the touch hint promises actually work (dismiss == cancel).
	var est_lines: int = int(ceil(msg.length() / 46.0)) + msg.count("\n")
	var vbox := _open("Are you sure?", 680, clampf(300.0 + est_lines * 24.0, 320.0, 600.0), true)
	current = "confirm"
	var l := _lbl(vbox, msg, 15, Color(0.9, 0.9, 0.9))
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := func() -> void:
		close()
		on_yes.call()
	var no := func() -> void:
		if on_cancel.is_valid():
			close()
			on_cancel.call()
		else:
			open_pause()
	_btn(vbox, "  Yes — do it  ", yes, Color(1.0, 0.6, 0.5))
	_btn(vbox, "  Cancel  ", no, Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to cancel")


## Sound + display options. Everything applies live and persists to
## user://settings.json. Reachable from the pause menu AND the title.
var settings_return := "pause"
func open_settings(from := "pause") -> void:
	settings_return = from
	var vbox := _open("Settings", 700, 520, true)
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
	# Language selector — cycles the Loc table (translation is a table swap).
	var lang_btn := _btn(vbox, "  Language: %s  " % String(game.settings.get("lang", "en")).to_upper(),
		func() -> void:
			var langs := Loc.languages()
			var i := langs.find(Loc.lang)
			Loc.lang = String(langs[(i + 1) % langs.size()])
			game.settings["lang"] = Loc.lang
			game.save_settings()
			open_settings(settings_return), Color(0.9, 0.9, 0.95))
	lang_btn.tooltip_text = "Cycle UI language (localization foundation — most screens are English for now)."
	# Control scheme (desktop only — mobile is always touch). Flips the on-screen
	# joystick + buttons + click-to-talk on; keyboard shortcuts stay valid either way.
	if not OS.has_feature("mobile"):
		var tc_btn := _btn(vbox, "  Controls: %s  " % ("TOUCH" if game.settings.get("touch_controls", false) else "KEYBOARD"),
			func() -> void:
				game.set_touch_controls(not bool(game.settings.get("touch_controls", false)))
				open_settings(settings_return), Color(0.9, 0.9, 0.95))
		tc_btn.tooltip_text = "Touch: on-screen joystick + buttons + click-to-talk. Keyboard shortcuts always stay valid."
	# Touch-layout options — shown whenever touch controls are active (mobile, or desktop
	# with the toggle on): joystick lock + a drag-to-rearrange button editor.
	if game.touch_mode:
		var jl_btn := _btn(vbox, "  Joystick: %s  " % ("FIXED" if game.settings.get("joystick_locked", false) else "FLOATING"),
			func() -> void:
				game.settings["joystick_locked"] = not bool(game.settings.get("joystick_locked", false))
				game.save_settings()
				open_settings(settings_return), Color(0.9, 0.9, 0.95))
		jl_btn.tooltip_text = "Floating: the stick springs to wherever your thumb lands. Fixed: it stays at one spot."
		# Sensitivity: multiplies the stick's post-deadzone travel, so a higher value
		# hits full speed on a shorter drag (calibrate to taste — 1.0× = raw stick).
		var sens_row := HBoxContainer.new()
		sens_row.add_theme_constant_override("separation", 14)
		vbox.add_child(sens_row)
		var sens_name := _lbl(sens_row, "Joystick sensitivity", 15)
		sens_name.custom_minimum_size = Vector2(180, 0)
		var sens_slider := HSlider.new()
		sens_slider.min_value = 1.0
		sens_slider.max_value = 3.0
		sens_slider.step = 0.1
		sens_slider.value = float(game.settings.get("joystick_sensitivity", 1.0))
		sens_slider.custom_minimum_size = Vector2(320, 24)
		sens_row.add_child(sens_slider)
		var sens_val := _lbl(sens_row, "%.1f×" % float(game.settings.get("joystick_sensitivity", 1.0)), 15, Color(0.95, 0.85, 0.5))
		sens_val.custom_minimum_size = Vector2(70, 0)
		sens_slider.value_changed.connect(func(v: float) -> void:
			game.settings["joystick_sensitivity"] = v
			game.save_settings()
			sens_val.text = "%.1f×" % v)
		_lbl(vbox, "1.0× = drag to the edge for full speed; higher = full speed on a shorter drag. Drag the joystick in the button editor to move it.", 12, Color(0.55, 0.58, 0.66))
		_btn(vbox, "  Customize buttons…  ", func() -> void: _open_layout_editor(), Color(0.8, 0.95, 0.85))
	# Keybinds live here now (moved out of the pause menu). Keyboard-only, so
	# they're hidden under touch controls — there are no keys to rebind on a phone.
	if not game.touch_mode:
		_btn(vbox, "  ⌨  " + Loc.t("keybinds") + "…", func() -> void: open_keybinds(), Color(0.9, 0.9, 0.95))
	_btn(vbox, "  Back  ", func() -> void: _settings_back(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back")


func _settings_back() -> void:
	if settings_return == "title":
		open_slots()  # back to the roster, not the splash
	else:
		open_pause()


## Close the menu and drop into the on-screen button-layout editor (touch HUD).
func _open_layout_editor() -> void:
	close()
	if game._touch_hud != null:
		game._touch_hud.enter_edit_mode()


# ---------------------------------------------------------- chapter select ---

# ------------------------------------------------------------ endgame trials ---

## Confirm-and-enter a mode from a HUD trial icon: a backable prompt carrying the
## mode's record + rules, so a stray click on the HUD never tears the world down.
func confirm_endgame(mode: String) -> void:
	var cls: String = game.local_player.cls
	var pb := game.endgame_pb(mode, cls)
	var mname := "The Crucible" if mode == "crucible" else "The Waking Depths"
	var rules := "Ten bosses back to back, each with an elite affix — HP and MP carry over between them. Bonus spoils at 3 / 6 / 10 kills." if mode == "crucible" \
		else "An endless descent: each room's mobs deepen a level and a boss guards every fourth. Rewards pay when you fall or cash out."
	var best := ""
	if not pb.is_empty():
		best = ("\n\nYour best: %d bosses." % int(pb.get("kills", 0))) if mode == "crucible" \
			else ("\n\nYour deepest: depth %d." % int(pb.get("depth", 0)))
	open_confirm("Enter %s?\n\n%s%s\n\nYour campaign is saved — you'll return to the title when the run ends." % [mname, rules, best],
		func() -> void: _start_endgame(mode),
		func() -> void: close())


## The endgame mode picker (ACT2_DESIGN.md §II) — reached from the pause menu
## once Act 1 is cleared. Two never-ending arena modes; picking one tears down
## the campaign world and drops the hero into the arena (game.enter_endgame).
func open_endgame_select() -> void:
	var vbox := _open("Endgame Trials", 860, 560, true)
	current = "endgame_select"
	_lbl(vbox, "Act 1 is behind you. These trials never end — push for the leaderboard, or cash out for the loot. They pay no XP; gold and mailed spoils are the prize, and a death still pays (at a tithe).", 14, Color(0.75, 0.75, 0.78))
	var cls: String = game.local_player.cls

	var cru_pb := game.endgame_pb("crucible", cls)
	var cru_sub := "Ten bosses back to back, each wearing an elite affix, scaled to you. HP and MP carry over — no healing between fights, so potions are your only sustain. Bonus spoils at 3 / 6 / 10 kills; the full clear pays a boss-band piece."
	if not cru_pb.is_empty():
		cru_sub += "\n★ Best: %d bosses" % int(cru_pb.get("kills", 0))
		if float(cru_pb.get("time", 0.0)) > 0.0:
			cru_sub += "   ·   fastest 10-clear %d:%02d" % [int(cru_pb["time"]) / 60, int(cru_pb["time"]) % 60]
	_endgame_card(vbox, "🔥  The Crucible", cru_sub, Color(1.0, 0.6, 0.45),
		func() -> void: _start_endgame("crucible"))

	var dep_pb := game.endgame_pb("depths", cls)
	var dep_sub := "An endless descent. A prep camp, then combat only: each room's mobs scale a level deeper, a boss guards every fourth room, and affixes and pressure mount the further you fall. How deep can you go?"
	if not dep_pb.is_empty():
		dep_sub += "\n★ Deepest: %d" % int(dep_pb.get("depth", 0))
	_endgame_card(vbox, "🕯  The Waking Depths", dep_sub, Color(0.72, 0.8, 1.0),
		func() -> void: _start_endgame("depths"))

	_hint(vbox, "Pick a trial, or ESC to go back")

## One mode card: a big colored launch button with its rules beneath.
func _endgame_card(parent: Node, title: String, sub: String, color: Color, cb: Callable) -> void:
	var b := _btn(parent, "  " + title + "  ", cb, color)
	b.add_theme_font_size_override("font_size", 20)
	var sl := _lbl(parent, sub, 13, Color(0.72, 0.74, 0.82))
	sl.custom_minimum_size = Vector2(800, 0)

func _start_endgame(mode: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.enter_endgame(mode)

## The settlement card shown when an endgame run ends (cash-out, death, or a full
## Crucible clear). Rewards are already banked/mailed by the controller; the only
## exit is back to the title.
func open_endgame_result(summary: Dictionary) -> void:
	var died: bool = summary.get("died", false)
	var completed: bool = summary.get("completed", false)
	var title := "RUN COMPLETE"
	var col := Color(1.0, 0.85, 0.35)
	if completed:
		title = "THE CRUCIBLE CONQUERED"
	elif died:
		title = "YOU FELL"
		col = Color(1.0, 0.6, 0.5)
	var vbox := _open(title, 720, 500)
	current = "endgame_result"
	_lbl(vbox, String(summary.get("name", "")), 18, col)
	if String(summary.get("mode", "")) == "crucible":
		_lbl(vbox, "Bosses slain:  %d / %d" % [int(summary.get("kills", 0)), Balance.CRUCIBLE_BOSSES], 15)
	else:
		_lbl(vbox, "Depth reached:  %d      bosses slain:  %d" % [int(summary.get("depth", 0)), int(summary.get("kills", 0))], 15)
	var rec: Dictionary = summary.get("record", {})
	if rec.get("new_kills", false) or rec.get("new_time", false) or rec.get("new_depth", false):
		_lbl(vbox, "★  NEW PERSONAL RECORD", 16, Color(0.6, 1.0, 0.7))
	_lbl(vbox, " ", 8)
	_lbl(vbox, "Gold banked:  %d%s" % [int(summary.get("gold", 0)),
		"   (death tithe applied)" if died else ""], 15, Color(1.0, 0.85, 0.4))
	var gems := int(summary.get("gems", 0))
	var gear := int(summary.get("gear", 0))
	if gems > 0 or gear > 0:
		_lbl(vbox, "Spoils mailed:  %d gem%s, %d gear piece%s" %
			[gems, "" if gems == 1 else "s", gear, "" if gear == 1 else "s"],
			14, Color(0.7, 0.9, 1.0))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	_btn(vbox, "  Return to title  (spoils are in your mailbox)  ",
		func() -> void: game.exit_to_title(), Color(0.6, 1.0, 0.6))
	_hint(vbox, "Your rewards are banked. Press to return.")


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
	# The list SCROLLS (QA finding 4: seven chapters overflowed the fixed
	# panel) — same pattern as the save roster. A holder Control wraps the
	# scroll so a bottom fade can float over it: the last row dissolves
	# instead of being guillotined mid-glyph at the viewport edge.
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(holder)
	var chscroll := ScrollContainer.new()
	chscroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	chscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(chscroll)
	var chlist := VBoxContainer.new()
	chlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chlist.add_theme_constant_override("separation", 4)
	chscroll.add_child(chlist)
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
		var b := _btn(chlist, "  %d.  %s%s  " % [idx, "" if unlocked else "🔒 ", chapter["name"]],
			pick, Color(0.95, 0.85, 0.5) if unlocked else Color(0.5, 0.5, 0.55), unlocked)
		b.add_theme_font_size_override("font_size", 18)
		var sub_text: String = String(chapter.get("sub", "")) if unlocked \
			else "Locked — finish the previous chapter to open this road."
		var sub := _lbl(chlist, "        " + sub_text, 13,
			Color(0.65, 0.68, 0.78) if unlocked else Color(0.5, 0.5, 0.55))
		sub.custom_minimum_size = Vector2(800, 0)
		idx += 1
	# The fade mask itself: panel-colored gradient pinned to the holder's
	# bottom edge, visible only while there is more list below the fold.
	var fade := TextureRect.new()
	var fg := Gradient.new()
	fg.set_color(0, Color(UITheme.PANEL_BG, 0.0))
	fg.set_color(1, Color(UITheme.PANEL_BG, 0.92))
	var fgt := GradientTexture2D.new()
	fgt.gradient = fg
	fgt.fill_from = Vector2(0, 0)
	fgt.fill_to = Vector2(0, 1)
	fade.texture = fgt
	fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -40
	fade.offset_right = -10  # keep the scrollbar out from under the veil
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fade)
	var vsb := chscroll.get_v_scroll_bar()
	var fade_upd := func() -> void:
		fade.visible = vsb.visible and (vsb.value + vsb.page < vsb.max_value - 1.0)
	vsb.value_changed.connect(func(_v: float) -> void: fade_upd.call())
	chscroll.resized.connect(fade_upd)
	fade_upd.call_deferred()
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
	# 708 tall: the tallest card (paladin's stance passive) sets the row's
	# MINIMUM height — a shorter panel can't clip it (a Control never shrinks
	# below its content). The WHOLE card is the button now (see the loop), so
	# nothing spills past the frame the way the old bottom "choose" buttons did.
	var vbox := _open("Choose your class", 1240, 716)
	current = "class_select"
	_lbl(vbox, "This choice sets your four abilities and your three elemental THEMES — playstyles that reshape those abilities as you level.  Click any class to choose it.", 15, Color(0.75, 0.75, 0.75))

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
		# The whole card IS the button (no bottom "choose" button that used to
		# spill below the frame): a PanelContainer that picks the class on click,
		# brightens + gains a gold rim on hover, and shows a pointing-hand cursor.
		# Its VBox and every label inside pass mouse events through (IGNORE) so a
		# click anywhere on the card reaches the panel.
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_w, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("panel", _class_card_style(false))
		card.mouse_entered.connect(func() -> void:
			card.add_theme_stylebox_override("panel", _class_card_style(true)))
		card.mouse_exited.connect(func() -> void:
			card.add_theme_stylebox_override("panel", _class_card_style(false)))
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				choose_class(id))
		hbox.add_child(card)

		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2 if dense else 6)
		card.add_child(col)

		# The name carries the number-key hint the old button used to ("(1)"):
		# keys 1–6 still pick left-to-right (see _input). Dense (6-class) roster
		# puts the icon and name on ONE row to reclaim height — the tallest card
		# (Paladin's long passive + 4 abilities) has to clear the 720px frame.
		if dense:
			var header := HBoxContainer.new()
			header.add_theme_constant_override("separation", 8)
			col.add_child(header)
			var icon := TextureRect.new()
			icon.texture = Art.tex(c["sprite"])
			icon.custom_minimum_size = Vector2(40, 40)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			header.add_child(icon)
			var nm := _lbl(header, "%s  (%d)" % [c["name"], idx], 18, Color(0.95, 0.85, 0.5))
			# A wrapping label inside an HBox with no min width collapses to one
			# char per line (CLAUDE.md trap) — the name is short, so don't wrap it.
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			var icon := TextureRect.new()
			icon.texture = Art.tex(c["sprite"])
			icon.custom_minimum_size = Vector2(96, 96)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			col.add_child(icon)
			_lbl(col, "%s  (%d)" % [c["name"], idx], 20, Color(0.95, 0.85, 0.5))
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
			var scaling: String = Classes.ability_scaling(id, slot)
			var riders: String = Classes.ability_riders(id, slot)
			# Dense roster shows ability names + the readout lines below; the full
			# prose now sits behind the whole-card pick (a click anywhere chooses
			# the class), so the old click-for-popover on ability lines is gone.
			var line: String = "%s %s" % [tag, ab["name"]] if dense else "%s %s — %s" % [tag, ab["name"], ab["desc"]]
			_lbl(col, line, 11 if dense else 12, Color(0.65, 0.7, 0.8))
			# Two readout lines under each ability (from its data): SCALING (type +
			# %ATK, green) and RIDERS (CC/buffs/sustain/debuffs, amber). The
			# tuning-transparency pair. Buffs with no damage show only riders.
			if scaling != "":
				_lbl(col, "    " + scaling, 10 if dense else 11, Color(0.58, 0.74, 0.66))
			if riders != "":
				_lbl(col, "    " + riders, 10 if dense else 11, Color(0.82, 0.72, 0.48))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		# Every widget passes clicks through to the card panel above (recurse so
		# the header row's icon + name don't swallow them either).
		_ignore_mouse_recursive(col)
		idx += 1


## Make every Control under `n` transparent to the mouse, so clicks fall
## through the card's content down to the PanelContainer that selects it.
func _ignore_mouse_recursive(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_recursive(ch)


## Chrome for one class-picker card: a faint panel that brightens and gains a
## gold rim on hover, so the whole card reads as one big button.
func _class_card_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.15, 0.55) if hover else Color(0.06, 0.06, 0.08, 0.30)
	sb.border_color = Color(0.95, 0.85, 0.5, 0.9) if hover else Color(0.42, 0.40, 0.34, 0.35)
	sb.set_border_width_all(2 if hover else 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## A class was picked — from a card click or a number key. Both funnel here so
## the splash reveal always plays. Guarded so a second click/key mid-reveal
## can't double-fire.
func choose_class(id: String) -> void:
	if current != "class_select":
		return
	_show_class_splash(id)


## The "you chose the <Class>" beat: the class's splash art rises out of black
## for ~1s, then name entry. Runs while the tree is paused — Menus is
## PROCESS_MODE_ALWAYS, so the fade tween and the hold timer still tick.
func _show_class_splash(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = "class_splash"
	game.request_pause(true)
	if game and game.hud:
		game.hud.visible = false
	game.sfx("ui_click")

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.03)  # deep black, matches the boot night
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var art := TextureRect.new()
	art.texture = Art.tex("class_splash_" + id)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Class splashes are PAINTERLY illustrations, not pixel art, and they are
	# always UPSCALED here: a square splash fits to height, so it's drawn 720px
	# tall in canvas space = 1080px on a 1080p screen, 1440p on 1440, 2160 on 4K.
	# The 768px splashes are therefore magnified 1.4x-2.8x. Under the project's
	# global NEAREST filter that magnification is a blocky stair-step — nearest
	# is right for pixel art and wrong for a painting. Per-node override; world
	# sprites keep NEAREST.
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(art)

	var c: Dictionary = Classes.CLASSES.get(id, {})
	var name_lbl := Label.new()
	name_lbl.text = String(c.get("name", "")).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 600)
	name_lbl.size = Vector2(1280, 90)
	UITheme.title(name_lbl, 48)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.86, 0.52))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 8)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# Rise out of black, hold, then step into naming.
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.15).timeout
	if current != "class_splash":
		return  # backed out or superseded during the hold
	open_name_entry(id)


func pick_class(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.on_class_chosen(id)


# ------------------------------------------------------------- name your hero ---

## Between the class pick and the world build: name the hero. Pre-filled with
## the OS account name (what co-op friends already recognize) so a player who
## just wants to start can hit Enter. The name rides the save (SaveGame) and
## becomes this character's co-op identity; blank stores "" so the live OS
## name answers instead. Direct pick_class() callers (tests, launchers) skip
## this and keep the empty-name fallback.
func open_name_entry(id: String) -> void:
	var vbox := _open("Name your hero", 640, 360)
	current = "name_entry"
	var c: Dictionary = Classes.CLASSES.get(id, {})
	_lbl(vbox, "Your %s needs a name — it's how friends will find you in co-op. Leave it as-is to keep your account name." % String(c.get("name", "hero")).to_lower(),
		14, Color(0.75, 0.75, 0.75))

	var field := LineEdit.new()
	field.max_length = Balance.CHAR_NAME_MAX
	field.text = _default_char_name()
	field.placeholder_text = "Hero"
	field.custom_minimum_size = Vector2(0, 40)
	field.add_theme_font_size_override("font_size", 18)
	vbox.add_child(field)
	field.grab_focus()
	field.select_all()

	var confirm := func() -> void: _confirm_name(id, field.text)
	field.text_submitted.connect(func(_t: String) -> void: confirm.call())
	_btn(vbox, "  Begin  ", func() -> void: confirm.call(), Color(0.6, 1.0, 0.6))
	_btn(vbox, "  Back  ", func() -> void: open_class_select(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "Enter to begin · ESC to change class")


## The name offered by default: the OS account name (co-op-recognizable),
## read through the network session's os_name(); "Hero" if it can't be read.
func _default_char_name() -> String:
	var sess: Node = game.get_node_or_null("/root/NetworkManager/Session")
	var nm := String(sess.os_name()) if sess != null else ""
	return nm if nm != "" else "Hero"


## Commit the typed name onto the fresh character (save.gd reads game.player),
## then run the normal class entry.
func _confirm_name(id: String, raw: String) -> void:
	game.player.char_name = _sanitize_char_name(raw)
	pick_class(id)


## One trimmed line, control characters stripped, capped at CHAR_NAME_MAX.
## Blank returns "" — the co-op name then falls back to the live OS name.
func _sanitize_char_name(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32:  # drop control chars; keep it one clean line
			out += ch
	return out.strip_edges().substr(0, Balance.CHAR_NAME_MAX).strip_edges()


# ----------------------------------------------------------- potion loadout ---

## The per-room potion ROTATION editor (reached from the inventory's "Potion
## Loadout" tab). Shows the room slots, lets you slot/unslot any owned elixir or
## mana potion, and — crucially — is visible and self-explaining even when you
## carry only Health (the old potion-popover path showed nothing then).
func open_potion_loadout() -> void:
	var p = game.local_player
	var vbox := _open("Potion Loadout", 760, 560, true)
	current = "potion_loadout"
	var cyc: String = "tap the ⟳ button" if game.touch_mode \
		else "[%s]" % OS.get_keycode_string(game.binds.get("potion_next", KEY_R))
	var intro := _lbl(vbox, "Your PER-ROOM potion budget. Every room refills these slots; each drink spends one, and any unassigned slot pours a Health potion. Slot an elixir or mana potion here to fold it into the rotation — %s cycles which one is active mid-fight." % cyc, 13, Color(0.72, 0.74, 0.82))
	intro.custom_minimum_size = Vector2(700, 0)

	var cap: int = p.potion_slot_cap()
	var plan: Array = p.potion_loadout()
	_lbl(vbox, "ROOM SLOTS  (%d):" % cap, 15, Color(0.95, 0.85, 0.5))
	for i in cap:
		var pid: String = String(plan[i]) if i < plan.size() else "health"
		var pname: String = "Health" if pid == "health" else String(p.potion_display_name(pid))
		_lbl(vbox, "   Slot %d  ▸  %s" % [i + 1, pname], 14,
			Color(0.78, 0.42, 0.42) if pid == "health" else Color(0.6, 0.85, 1.0))

	UITheme.rule(vbox)
	_lbl(vbox, "YOUR POTIONS:", 15, Color(0.95, 0.85, 0.5))
	var any_rot := false
	for rid in Items.ROTATION_POTIONS:
		var rid_c := String(rid)
		var owned := 0
		for c in p.consumables:
			if String(c.get("id", "")) == rid_c:
				owned += 1
		if owned <= 0:
			continue
		any_rot = true
		var in_rot: int = p.potion_rotation.count(rid_c)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var nl := _lbl(row, "%s  —  own x%d%s" % [String(p.potion_display_name(rid_c)), owned,
			("  ·  slotted x%d" % in_rot) if in_rot > 0 else ""], 14, Color(0.82, 0.9, 1.0))
		nl.custom_minimum_size = Vector2(300, 0)
		_btn(row, "  ＋ Slot  ", func() -> void:
			game.local_player.loadout_add(rid_c)
			open_potion_loadout(), Color(0.7, 0.9, 1.0))
		if in_rot > 0:
			_btn(row, "  － Unslot  ", func() -> void:
				game.local_player.loadout_remove(rid_c)
				open_potion_loadout(), Color(0.7, 0.82, 0.95))
	if not any_rot:
		var warn := _lbl(vbox, "You only carry Health potions right now — every slot pours Health, so there's nothing to rotate yet. Buy a Mana Draught or an Elixir of Might from an alchemist's shelf, then come back here to slot it. That's how a rotation is built.", 13, Color(1.0, 0.82, 0.5))
		warn.custom_minimum_size = Vector2(700, 0)
	if not p.potion_rotation.is_empty():
		_btn(vbox, "  ⟲  All slots back to Health  ", func() -> void:
			game.local_player.potion_rotation.clear()
			game.local_player.active_potion = "health"
			open_potion_loadout(), Color(0.6, 1.0, 0.8))
	_btn(vbox, "  ← Back to inventory  ", func() -> void: open_inventory("gear", inv_cat), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back")


# --------------------------------------------------------------- inventory ---

func open_inventory(tab := "gear", cat := "all") -> void:
	inv_cat = cat  # remembered so an item-panel underlay rebuild keeps the filter
	var vbox := _open("Inventory — %d gold" % game.local_player.gold, 1120, 640, true)
	current = "inventory"

	# Subtabs: gear management / full character sheet.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Gear  ", func() -> void: open_inventory("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Stats  ", func() -> void: open_inventory("stats"),
		Color(0.95, 0.85, 0.5) if tab == "stats" else Color(0.6, 0.6, 0.6))
	# Dedicated, always-visible entry to the per-room potion rotation editor —
	# the old only-path (tap a potion stack, actions hidden unless you own an
	# elixir) was undiscoverable.
	_btn(tabs, "  Potion Loadout  ", func() -> void: open_potion_loadout(), Color(0.7, 0.92, 0.85))
	if tab == "stats":
		_build_stats_tab(vbox, game.local_player)
		return
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# EQUIPPED runs long once every slot holds a socketed S-item (4 slots ×
	# title + wrapped stats + a 40px socket row easily exceeds the panel body),
	# and a container never shrinks a child below its min height — so the raw
	# VBox used to spill past the panel bottom. Scroll it, the same way the bag
	# grid on the right does, and the list stays inside the panel.
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(456, 0)  # 440 col + ~16 scrollbar
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left)
	UITheme.header(_lbl(left, "EQUIPPED", 16, Color(0.95, 0.85, 0.5)))
	_lbl(left, "(click an item for its detail popover)", 12, Color(0.55, 0.55, 0.6))
	for slot in Items.SLOTS:
		if game.local_player.equipment.has(slot):
			var item: Dictionary = game.local_player.equipment[slot]
			# The tabbed item panel: Info / Gems / Reforge, Unequip on top.
			var open_cb := func() -> void:
				open_item_panel(item)
			# Title on a fixed-width clipped button; stats wrap in a label
			# below it — long S-item text can no longer blow up the layout.
			var b := _btn(left, Items.title(item), open_cb, Items.GRADE_COLOR[item["grade"]], true, Art.icon_for(item))
			b.custom_minimum_size = Vector2(430, 0)
			b.clip_text = true
			var dl := _lbl(left, Items.describe(item, _awk(item), false), 12, Color(Items.GRADE_COLOR[item["grade"]], 0.8))
			dl.custom_minimum_size = Vector2(430, 0)
			# Real gem sockets (2026-07-09): the ◆◇ describe-glyphs became
			# squares — a bag gem drags straight onto them (or onto the title
			# button, a bigger target); a socketed gem drags back out.
			var islots: int = item.get("gem_slots", 0)
			if islots > 0:
				var refresh := func() -> void: open_inventory("gear", cat)
				var can_fn := func(_pos: Vector2, data: Variant) -> bool:
					return data is Dictionary and String(data.get("kind", "")) == "bag_gem" \
						and game.local_player.gem_socket_error(item, data["gem"]) == ""
				var drop_fn := func(_pos: Vector2, data: Variant) -> void:
					game.local_player.embed_gem_into(item, data["gem"])
					open_inventory("gear", cat)
				b.set_drag_forwarding(Callable(), can_fn, drop_fn)
				var srow := HBoxContainer.new()
				srow.add_theme_constant_override("separation", 4)
				left.add_child(srow)
				_socket_row(srow, item, refresh)
		else:
			# Framed silhouette for an empty gear slot: a socketed square
			# with the slot's monogram, so "nothing equipped HERE" reads as
			# a place, not a footnote.
			var erow := HBoxContainer.new()
			erow.add_theme_constant_override("separation", 10)
			left.add_child(erow)
			var esq := Panel.new()
			esq.custom_minimum_size = Vector2(40, 40)
			var esb := StyleBoxFlat.new()
			esb.bg_color = Color(0.05, 0.05, 0.07, 0.92)
			esb.border_color = Color(0.4, 0.34, 0.2, 0.85)
			esb.set_border_width_all(2)
			esb.set_corner_radius_all(4)
			esq.add_theme_stylebox_override("panel", esb)
			erow.add_child(esq)
			var mono := Label.new()
			mono.text = slot.substr(0, 1).to_upper()
			mono.set_anchors_preset(Control.PRESET_FULL_RECT)
			mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UITheme.title(mono, 20)
			mono.add_theme_color_override("font_color", Color(0.42, 0.38, 0.28, 0.9))
			esq.add_child(mono)
			var el := _lbl(erow, "%s — empty" % slot.capitalize(), 14, Color(0.5, 0.5, 0.52))
			el.custom_minimum_size = Vector2(280, 0)  # HBox label-collapse trap
			el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var p: Player = game.local_player
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	right.add_child(head)
	var best_grade: String = String(p.bags[0].get("grade", "F")) if not p.bags.is_empty() else "F"
	for bb in p.bags:
		var bg: String = String(bb.get("grade", "F"))
		if Items.GRADES.find(bg) > Items.GRADES.find(best_grade):
			best_grade = bg
	var bh := _lbl(head, "BAGS — %d/%d equipped  (%d/%d slots)" % [p.bags.size(), Balance.MAX_BAGS,
		p.bag_used(), p.bag_capacity()], 16, Items.GRADE_COLOR[best_grade])
	UITheme.header(bh)
	bh.custom_minimum_size = Vector2(360, 0)
	# Equipped-bag chips on their own row (the old raw "F·15 F·15" string
	# next to the header was a floating mystery): one framed chip per bag —
	# pouch icon + grade + slot count, the bag's name on hover. A FLOW container
	# (not a plain HBox) so a full loadout of bags WRAPS to new rows instead of
	# running off the right column and dragging the whole panel past its edge.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(chips)
	for bb2 in p.bags:
		var bg2: String = String(bb2.get("grade", "F"))
		var chip := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.09, 0.09, 0.12, 0.92)
		csb.border_color = Color(Items.GRADE_COLOR[bg2], 0.7)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(4)
		csb.content_margin_left = 7.0
		csb.content_margin_right = 9.0
		csb.content_margin_top = 2.0
		csb.content_margin_bottom = 2.0
		chip.add_theme_stylebox_override("panel", csb)
		chip.tooltip_text = "%s — %s-grade bag, %d slots" % [String(bb2.get("name",
			Items.BAG_NAMES.get(bg2, "Bag"))), bg2, int(bb2.get("slots", 0))]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP  # the tooltip needs the hover
		chips.add_child(chip)
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		chip.add_child(crow)
		var bic := TextureRect.new()
		bic.texture = Art.tex("bag")
		bic.custom_minimum_size = Vector2(16, 16)
		bic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		crow.add_child(bic)
		var clbl := _lbl(crow, "%s · %d slots" % [bg2, int(bb2.get("slots", 0))], 12, Items.GRADE_COLOR[bg2])
		clbl.custom_minimum_size = Vector2(74, 0)  # HBox label-collapse trap
		clbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Auto-synth sits on its OWN row: inline in the header its ~170px pushed the
	# BAGS+summary run past the right column, overflowing the panel edge.
	if not p.gem_bag.is_empty():
		var auto_cb := func() -> void:
			var n: int = game.local_player.auto_synthesize()
			game.spawn_text(game.local_player.global_position + Vector2(0, -60),
				"%d GEM UPGRADES" % n if n > 0 else "NOTHING TO MERGE", Color(0.6, 0.9, 1.0))
			open_inventory()
		var ab := _btn(right, "⚒ Auto-synthesize ALL", auto_cb, Color(0.6, 0.9, 1.0))
		ab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ab.tooltip_text = "Merge every 3-of-a-kind until nothing can be merged.\nGems socketed in your equipped gear level up FIRST\n(each uses two matching gems from the bag)."
	_lbl(right, "Click any bag item for its detail card — equip/use/synthesize or drop it there · DRAG a gem onto an equipped item (left) to socket it, or drag a socketed gem back here · every unit counts toward slots (stacks are display-only) · bags drop from bosses/elites & stock at merchants", 12, Color(0.55, 0.55, 0.6))

	# Bag category filter: All (default) + per-slot gear, gems, consumables.
	var catrow := HBoxContainer.new()
	catrow.add_theme_constant_override("separation", 6)
	right.add_child(catrow)
	for spec in [["all", "All"], ["weapon", "Weapons"], ["armor", "Armor"], ["boots", "Boots"],
			["charm", "Charms"], ["gems", "Gems"], ["consumables", "Consumables"]]:
		var cid: String = spec[0]
		var cb := _btn(catrow, spec[1], func() -> void: open_inventory("gear", cid),
			Color(0.95, 0.85, 0.5) if cat == cid else Color(0.6, 0.6, 0.6))
		cb.add_theme_font_size_override("font_size", 13)

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
	# The WHOLE bag area is a drop target for a gem dragged out of an equipped
	# item's socket: the scroll, the grid, every free square — and every filled
	# slot button too (buttons are MOUSE_FILTER_STOP, so a drop on one never
	# bubbles to the grid; without their own forwarding the release showed the
	# forbidden cursor and read as "drag doesn't work").
	var sock_can := func(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and String(data.get("kind", "")) == "socketed_gem"
	var sock_drop := func(_pos: Vector2, data: Variant) -> void:
		game.local_player.remove_gem(data["item"], int(data["idx"]))
		open_inventory("gear", cat)
	scroll.set_drag_forwarding(Callable(), sock_can, sock_drop)
	grid.set_drag_forwarding(Callable(), sock_can, sock_drop)
	right.set_drag_forwarding(Callable(), sock_can, sock_drop)
	var show_gear: bool = cat == "all" or cat in Items.SLOTS
	var show_gems: bool = cat == "all" or cat == "gems"
	var show_cons: bool = cat == "all" or cat == "consumables"
	if show_gear:
		for item in p.backpack:
			var it: Dictionary = item
			if cat != "all" and String(it["slot"]) != cat:
				continue
			_bag_slot(grid, Art.icon_for(it), "", Items.GRADE_COLOR[it["grade"]],
				func() -> void:
					var info := "%s\n\nCompared to what's equipped:\n%s" % [Items.describe(it, _awk(it)), _diff_tip(it)]
					var equip_cb := func() -> void:
						game.local_player.equip(it)
						open_inventory("gear", cat)
					var drop_cb := func() -> void:
						game.local_player.backpack.erase(it)
						game.discard_to_ground({"kind": "item", "item": it})
						open_inventory("gear", cat)
					var actions: Array = [
						["  ⚔  Equip  ", Color(0.6, 1.0, 0.6), equip_cb],
						["  ✖  Drop  (throw out, free a slot)  ", Color(1.0, 0.55, 0.45), drop_cb],
					]
					_open_detail_popover(Art.icon_for(it), Items.title(it), Items.GRADE_COLOR[it["grade"]], info, actions)).set_drag_forwarding(Callable(), sock_can, sock_drop)
	if show_cons:
		# Health potions (2026-07-09 v2): stored as a COUNTER
		# (potions/potions_free) but they occupy bag slots like any unit,
		# so they render here as VIRTUAL stack entries — bought stock and
		# the expiring chapter gift separately. Clicking one plans the
		# loadout, exactly what the HUD potion tooltip promises. No Use
		# (Q drinks via the room budget) and no Drop (sell spares at any
		# merchant instead).
		var pot_stacks: Array = []
		if p.potions > 0:
			pot_stacks.append([p.potions, "", Color(1.0, 0.5, 0.5),
				"Mends 15%% of your MISSING health. Drink with [%s] in the field (per-room budget); sell spare stock at any merchant. Each potion rides in your bags — one slot per potion." % OS.get_keycode_string(game.binds["potion"])])
		if p.potions_free > 0:
			pot_stacks.append([p.potions_free, " (chapter gift)", Color(1.0, 0.78, 0.45),
				"The chapter's free teaching potion — drunk FIRST, never sellable, and it EXPIRES the moment you leave this chapter. It still takes a bag slot while you hold it."])
		for ps in pot_stacks:
			var pn: int = ps[0]
			var psuf: String = ps[1]
			var pcol: Color = ps[2]
			var pdesc: String = ps[3]
			_bag_slot(grid, Art.tex("potion"), ("x%d" % pn) if pn > 1 else "", pcol,
				func() -> void:
					var info := pdesc
					# THE ROTATION HUB (2026-07-09): clicking the health potion is where
					# you PLAN the room loadout — slot-by-slot readout + an action per
					# ownable rotation type, so the editor exists even on a fresh
					# character (the old panel showed NO actions until the rotation was
					# already non-empty — exactly the "no way to set it up" report).
					var comp: Array = []
					for rid in p.potion_rotation:
						comp.append(p.potion_display_name(String(rid)))
					for _h in range(p.potion_slot_cap() - p.potion_rotation.size()):
						comp.append("Health")
					info += "\n\nROOM LOADOUT (%d slots): %s — unassigned slots drink as HEALTH. [%s] cycles in the field." % [
						p.potion_slot_cap(), " | ".join(comp),
						OS.get_keycode_string(game.binds.get("potion_next", KEY_R))]
					var actions: Array = []
					for rid in Items.ROTATION_POTIONS:
						var rid_c := String(rid)
						var owned := 0
						for c in p.consumables:
							if String(c.get("id", "")) == rid_c:
								owned += 1
						if owned <= 0:
							continue
						var in_rot: int = p.potion_rotation.count(rid_c)
						actions.append(["  ＋  Slot %s  (own x%d%s)  " % [p.potion_display_name(rid_c), owned,
								(", slotted x%d" % in_rot) if in_rot > 0 else ""], Color(0.7, 0.9, 1.0),
							func() -> void:
								game.local_player.loadout_add(rid_c)
								open_inventory("gear", cat)])
						if in_rot > 0:
							actions.append(["  －  Unslot %s  " % p.potion_display_name(rid_c), Color(0.7, 0.82, 0.95),
								func() -> void:
									game.local_player.loadout_remove(rid_c)
									open_inventory("gear", cat)])
					if not p.potion_rotation.is_empty():
						actions.append(["  ⟲  All slots back to health  ", Color(0.6, 1.0, 0.8),
							func() -> void:
								game.local_player.potion_rotation.clear()
								game.local_player.active_potion = "health"
								open_inventory("gear", cat)])
					_open_detail_popover(Art.tex("potion"), "Health Potion%s  x%d" % [psuf, pn],
						pcol, info, actions)).set_drag_forwarding(Callable(), sock_can, sock_drop)
		# Consumables STACK by id (playtest 2026-07-07): one slot per
		# type, count in the tooltip, click uses ONE.
		var cgroups := {}
		var corder: Array = []
		for c in p.consumables:
			var cc0: Dictionary = c
			var gid := String(cc0.get("id", cc0.get("name", "?")))
			if not cgroups.has(gid):
				cgroups[gid] = {"c": cc0, "count": 0}
				corder.append(gid)
			cgroups[gid]["count"] += 1
		for gid in corder:
			var cc: Dictionary = cgroups[gid]["c"]
			var count: int = cgroups[gid]["count"]
			var xn := "  x%d" % count if count > 1 else ""
			# Quest keepsakes ride the bag but have no use/drop — they exist
			# to be GIVEN (and vanish when the run ends). Click shows the
			# keepsake's story text; no action buttons.
			if String(cc.get("kind", "")) == "quest":
				_bag_slot(grid, null, "❦", Items.GRADE_COLOR[str(cc.get("grade", "B"))],
					func() -> void:
						_open_detail_popover(null, str(cc["name"]) + xn,
							Items.GRADE_COLOR[str(cc.get("grade", "B"))], str(cc.get("desc", "")), [])).set_drag_forwarding(Callable(), sock_can, sock_drop)
				continue
			var cicon: Texture2D = Art.consumable_icon(cc)
			var cid := String(gid)
			var slotted: int = p.potion_rotation.count(cid)
			_bag_slot(grid, cicon, "" if cicon != null else "⟲",
				Color(0.6, 1.0, 0.8) if slotted > 0 else Items.GRADE_COLOR[str(cc.get("grade", "B"))],
				func() -> void:
					var info := str(cc.get("desc", ""))
					var use_cb := func() -> void:
						game.local_player.use_consumable(cc)
						open_inventory("gear", cat)
					var drop_cb := func() -> void:
						game.local_player.consumables.erase(cc)
						game.discard_to_ground({"kind": "stone", "stone": cc})
						open_inventory("gear", cat)
					# No alembic here: U+2697 has no glyph coverage on mobile and
					# renders as tofu (dc673ab dropped it from the loadout tab —
					# this Use button carried the same codepoint and was missed).
					var actions: Array = [["  Use  ", Color(0.6, 1.0, 0.8), use_cb]]
					if cid in Items.ROTATION_POTIONS:
						# Loadout editing (per-room potion budget, 2026-07-07 v2).
						info += "\n\nLoadout: %d/%d slots assigned%s — unassigned slots drink as HEALTH. [%s] cycles potions in the field." % [
							p.potion_rotation.size(), p.potion_slot_cap(),
							("  (this: x%d)" % slotted) if slotted > 0 else "",
							OS.get_keycode_string(game.binds.get("potion_next", KEY_R))]
						var slot_cb := func() -> void:
							game.local_player.loadout_add(cid)
							open_inventory("gear", cat)
						var unslot_cb := func() -> void:
							game.local_player.loadout_remove(cid)
							open_inventory("gear", cat)
						actions.append(["  ＋  Add to room loadout  ", Color(0.7, 0.9, 1.0), slot_cb])
						if slotted > 0:
							actions.append(["  －  Remove from loadout  ", Color(0.7, 0.82, 0.95), unslot_cb])
					actions.append(["  ✖  Drop one  (throw out, free a slot)  ", Color(1.0, 0.55, 0.45), drop_cb])
					_open_detail_popover(cicon, str(cc["name"]) + xn,
						Color(0.6, 1.0, 0.8) if slotted > 0 else Items.GRADE_COLOR[str(cc.get("grade", "B"))],
						info, actions)).set_drag_forwarding(Callable(), sock_can, sock_drop)
	if show_gems:
		var groups := _gem_groups()
		for key in _sorted_gem_keys(groups):
			var group: Dictionary = groups[key]
			var g: Dictionary = group["gem"]
			var count: int = group["count"]
			var can_synth: bool = count >= 3 and g["lvl"] < Items.GEM_MAX_LEVEL
			var gem_cb := func() -> void:
				var info := "%s  x%d\n\n" % [Items.gem_title(g), count]
				if can_synth:
					info += "Synthesize combines three of these into one Lv%d gem." % (g["lvl"] + 1)
				else:
					info += "Socket it into an equipped item (click a piece of gear on the left), or gather three to synthesize a stronger one."
				var synth_cb := func() -> void:
					game.local_player.synthesize(g["stat"], g["lvl"])
					open_inventory("gear", cat)
				var drop_cb := func() -> void:
					game.local_player.gem_bag.erase(g)
					game.discard_to_ground({"kind": "gem", "gem": g})
					open_inventory("gear", cat)
				var actions: Array = []
				if can_synth:
					actions.append(["  ⚒  Synthesize  (3 → 1 Lv%d)  " % (g["lvl"] + 1), Color(0.6, 0.9, 1.0), synth_cb])
				actions.append(["  ✖  Drop one  (throw out, free a slot)  ", Color(1.0, 0.55, 0.45), drop_cb])
				_open_detail_popover(Art.gem_icon(Items.gem_color(g), int(g["lvl"])), Items.gem_title(g), Items.gem_color(g), info, actions)
			var gbtn := _bag_slot(grid, Art.gem_icon(Items.gem_color(g), int(g["lvl"])),
				("x%d" % count) if count > 1 else "", Items.gem_color(g), gem_cb)
			# Drag it straight onto an equipped item (left) to socket it — and
			# accept a socketed gem dropped back the other way (landing one on
			# its matching stack is the most natural target in the grid).
			var gem_drag := func(_pos: Vector2) -> Variant:
				gbtn.set_drag_preview(_drag_preview(Art.gem_icon(Items.gem_color(g), int(g["lvl"]))))
				return {"kind": "bag_gem", "gem": g}
			gbtn.set_drag_forwarding(gem_drag, sock_can, sock_drop)
	# Free-space squares only in the All view (a filtered view isn't the
	# whole bag, so padding it with empties would misrepresent capacity).
	if cat == "all":
		for i in maxi(0, p.bag_capacity() - p.bag_used()):
			_bag_empty(grid).set_drag_forwarding(Callable(), sock_can, sock_drop)
	_hint(vbox, "ESC, ✕, click outside, or I to close")


## One square bag slot: an item icon or a colored glyph, colored border,
## click action. No hover tooltip — clicking opens the detail popover.
func _bag_slot(grid: GridContainer, icon: Texture2D, glyph: String, color: Color,
		cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if glyph != "":  # icon + text together (gem stacks: icon + count)
			b.text = glyph
			b.add_theme_font_size_override("font_size", 13)
	else:
		b.text = glyph
		b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", color)
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


## A dark square: one free bag slot (returned so the inventory can make
## each a drop target for gems dragged out of sockets).
func _bag_empty(grid: GridContainer) -> Panel:
	var pnl := Panel.new()
	pnl.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.045, 0.065, 0.92)
	sb.border_color = Color(0.38, 0.32, 0.2, 0.9)  # visible socket, not a hairline
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	pnl.add_theme_stylebox_override("panel", sb)
	grid.add_child(pnl)
	return pnl


## Build the opaque popover shell over the current screen and return the
## VBox to fill. Frees any open popover first; a click landing on the
## transparent full-screen catcher behind it — i.e. anywhere off the box —
## dismisses it (no Close button, nothing dims: a popover, not a modal).
## `_popover_box` holds the panel so callers can re-anchor a rebuild.
func _popover_frame(title_color: Color) -> VBoxContainer:
	if detail_popover:
		detail_popover.queue_free()
	elif current != "detail":
		detail_return = current  # the screen we're floating over
	current = "detail"
	game.sfx("ui_click")

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_detail_popover())
	root.add_child(overlay)
	detail_popover = overlay

	# A PanelContainer hugs its content, so the popover is exactly as tall
	# as what's inside — no fixed card box.
	var pop := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.13, 1.0)  # fully opaque — no bleed-through
	sb.border_color = Color(title_color, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pop.add_theme_stylebox_override("panel", sb)
	pop.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the box don't dismiss
	overlay.add_child(pop)
	_popover_box = pop

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pop.add_child(vbox)
	return vbox


## Icon + title header row for a popover.
func _popover_header(vbox: VBoxContainer, icon: Texture2D, title: String, title_color: Color) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vbox.add_child(head)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(40, 40)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(ic)
	var tl := UITheme.title(_lbl(head, title, 18, title_color), 19)
	tl.custom_minimum_size = Vector2(300, 0)


## Place `pop` at `at` (or the cursor when at.x < 0), measure it once laid
## out, then nudge it fully on-screen. When a scroll+body are passed, cap the
## scroll height first so a tall bench scrolls instead of overflowing.
func _popover_settle(pop: PanelContainer, at: Vector2, scroll: ScrollContainer = null, body: Control = null) -> void:
	pop.position = at if at.x >= 0.0 else pop.get_global_mouse_position() + Vector2(14, 8)
	await get_tree().process_frame
	if not is_instance_valid(pop):
		return
	if scroll != null and body != null:
		scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, 500.0)
	pop.reset_size()
	var sz := pop.size
	pop.position = Vector2(
		clampf(pop.position.x, 8.0, 1280.0 - sz.x - 8.0),
		clampf(pop.position.y, 8.0, 720.0 - sz.y - 8.0))


## The simple popover: header, an info block, then flat action buttons.
## `actions` is a list of [label, color, Callable]. Cursor-anchored,
## auto-sized. Shared by inventory bags, the shop and equipped gear.
func _open_detail_popover(icon: Texture2D, title: String, title_color: Color,
		info: String, actions: Array) -> void:
	if not root:
		return
	var vbox := _popover_frame(title_color)
	var pop := _popover_box
	_popover_header(vbox, icon, title, title_color)
	var il := _lbl(vbox, info, 14, Color(0.85, 0.85, 0.92))
	il.custom_minimum_size = Vector2(320, 0)
	for a in actions:
		var acb: Callable = a[2]
		_btn(vbox, String(a[0]), acb, a[1])
	await _popover_settle(pop, Vector2(-1, -1))


## Dismiss the popover, leaving the screen it floats over (inventory or
## shop) intact underneath.
func _close_detail_popover() -> void:
	if detail_popover:
		detail_popover.queue_free()
		detail_popover = null
	if current == "detail":
		current = detail_return if detail_return != "" else "inventory"


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

	_lbl(list, "ATTRIBUTES  (click any stat to learn what it does)", 16, Color(0.95, 0.85, 0.5))
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
		["Evasion", "%d%%" % int(Stats.eva_curve(p.eva) * 100), "Chance to fully dodge a hit. Countered by the attacker's DEX. Capped at %d%%." % int(Balance.CAP_EVA * 100)],
	]
	for r in rows2:
		_stat_row(list, r[0], r[1], r[2])

	_lbl(list, "UTILITY", 16, Color(0.95, 0.85, 0.5))
	var rows3 := [
		["Speed", str(int(p.speed)), "How fast you move. Ice patches boost it; void rifts slow it."],
		["Lifesteal", "%d%%" % int(p.lifesteal * 100), "Heals you for a share of damage dealt. AoE hits only steal a third."],
		["Greed", "%d%%" % int(Stats.greed_gold(p.current_greed()) * 100), "Bonus gold from every source. Every point also nudges chest drop rates. Strong diminishing returns past %d%%. Sourced only by GOLD RUSH coins — rare charged coins spilled by farm kills that surge it for a window." % int(Balance.CAP_GREED * 100)],
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
	# Band leans (2026-07-09): the shard's conviction worn as NUMBERS
	# (player rule: never explain a stat only in prose).
	if p.res_lean() <= 0.0:
		_stat_row(list, "Shard lean", "none — the shard is undecided",
			"Commit past the band line (±25) and a lean wakes, growing to full strength at ±100. Virtue leans into CONSTANCY: health potions mend up to %d%% deeper. Temptation leans into HUNGER: up to +%d%% damage to wounded mobs (below %d%% HP — never bosses) and up to +%d%% gold from kills. Neither is the correct answer; staying undecided is the only way to get nothing." % [
				int(Balance.RES_CONSTANCY_HEAL_MAX * 100), int(Balance.RES_HUNGER_EXEC_MAX * 100),
				int(Balance.RES_HUNGER_EXEC_AT * 100), int(Balance.RES_HUNGER_GOLD_MAX * 100)])
	elif p.resonance > 0.0:
		_stat_row(list, "Shard lean", "Constancy — potions mend +%d%%" % int((p.constancy_heal_mult() - 1.0) * 100.0),
			"The steady shard rewards the measured hand: health potions restore +%d%% more (grows with conviction — +%d%% at Virtue 100). Merchants already price the steady 10%% kinder." % [
				int((p.constancy_heal_mult() - 1.0) * 100.0), int(Balance.RES_CONSTANCY_HEAL_MAX * 100)], res_col)
	else:
		_stat_row(list, "Shard lean", "Hunger — +%d%% vs wounded mobs, +%d%% kill gold" % [
				int(p.hunger_exec_bonus() * 100.0), int((p.hunger_gold_mult() - 1.0) * 100.0)],
			"The tempted shard savors the finish: +%d%% damage to mobs below %d%% health (bosses are immune — earn those the honest way) and +%d%% gold from every kill (grows with conviction — full at Temptation -100)." % [
				int(p.hunger_exec_bonus() * 100.0), int(Balance.RES_HUNGER_EXEC_AT * 100),
				int((p.hunger_gold_mult() - 1.0) * 100.0)], res_col)

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
	_hint(vbox, "ESC, ✕, click outside, or I to close")


## One stat line: name, value, and a 🛈 hint. Click the row to open the
## explanation as an opaque popover (hover still previews it too). Labels
## ignore the mouse so the click lands on the row itself.
func _stat_row(parent: Node, stat_name: String, value: String, tip: String, color := Color(0.85, 0.85, 0.9)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_detail_popover(null, stat_name, color, tip, []))
	parent.add_child(row)
	var n := _lbl(row, stat_name, 14, color)
	n.custom_minimum_size = Vector2(220, 0)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _lbl(row, value, 14, Color(1, 1, 1))
	v.custom_minimum_size = Vector2(160, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := _lbl(row, "🛈", 12, Color(0.5, 0.55, 0.65))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Bag gems grouped by stat+level: key -> {gem, count}.
func _gem_groups() -> Dictionary:
	var groups := {}
	for gem in game.local_player.gem_bag:
		var key := "%s_%d" % [gem["stat"], gem["lvl"]]
		if not groups.has(key):
			groups[key] = {"gem": gem, "count": 0}
		groups[key]["count"] += 1
	return groups


## Item detail: full stats + per-socket gem management.
## Format a {stat: value} bonus dict as "ATK +12%, PhysRes +20".
func _stat_bonus_text(d: Dictionary) -> String:
	var parts: Array = []
	for stat in d:
		var v: float = d[stat]
		if stat in Items.FLAT_STATS:
			parts.append("%s +%d" % [Items.STAT_LABEL.get(stat, stat), int(v)])
		else:
			parts.append("%s +%d%%" % [Items.STAT_LABEL.get(stat, stat), int(round(v * 100))])
	return ", ".join(parts)


## The equipped-item management popover — the same scrollable opaque
## click-off-to-close box as before, now with codex-style subtabs (2026-07-09)
## instead of one long stack: Info (stats + set bonuses) / Gems (REAL socket
## squares + insert list) / Reforge (the gold bench). Unequip rides above the
## tabs — it applies on every tab. `at` re-anchors a rebuild in place so
## socketing/reforging doesn't make the box hop to the cursor each time.
func open_item_panel(item: Dictionary, at := Vector2(-1, -1), tab := "info") -> void:
	if not root:
		return
	# Rebuild in place: a socket/reforge action (or a subtab click) replaces an
	# open popover — keep its spot so the box doesn't hop to the cursor.
	if at.x < 0.0 and is_instance_valid(_popover_box):
		at = _popover_box.position
	# The panel EDITS the item (sockets, reforges) while the inventory shows the
	# same item's stat line and socket row underneath — rebuild the underlay
	# first so both views agree ("Add gem socket" left the equipped column's
	# socket row a square short), then float the panel back on top.
	if current == "inventory" or (current == "detail" and detail_return == "inventory"):
		open_inventory("gear", inv_cat)
	var p: Player = game.local_player
	var color: Color = Items.GRADE_COLOR[item["grade"]]
	var vbox := _popover_frame(color)
	var pop := _popover_box
	# Drag a socketed gem OFF the box — anywhere into the dim — to unsocket it.
	var ov_can := func(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and String(data.get("kind", "")) == "socketed_gem"
	var ov_drop := func(_pos: Vector2, data: Variant) -> void:
		game.local_player.remove_gem(data["item"], int(data["idx"]))
		open_item_panel(item, Vector2(-1, -1), "gems")
	detail_popover.set_drag_forwarding(Callable(), ov_can, ov_drop)
	_popover_header(vbox, Art.icon_for(item), Items.title(item), color)

	var tabrow := HBoxContainer.new()
	tabrow.add_theme_constant_override("separation", 10)
	vbox.add_child(tabrow)
	var slots: int = item.get("gem_slots", 0)
	var gems_n: int = item.get("gems", []).size()
	for spec in [["info", "Info"], ["gems", "Gems %d/%d" % [gems_n, slots]], ["reforge", "Reforge"]]:
		var tid: String = spec[0]
		_btn(tabrow, "  %s  " % spec[1], func() -> void: open_item_panel(item, Vector2(-1, -1), tid),
			Color(0.95, 0.85, 0.5) if tab == tid else Color(0.6, 0.6, 0.6))

	# Equipped items can be UNEQUIPPED back to the bag (leaving the slot
	# empty) — not just swapped by equipping something else.
	var is_equipped: bool = p.equipment.get(String(item.get("slot", ""))) == item
	if is_equipped:
		var slot_id: String = String(item["slot"])
		var unequip_cb := func() -> void:
			if game.local_player.unequip(slot_id):
				open_inventory()
			else:
				game.spawn_text(game.local_player.global_position + Vector2(0, -50), "Bag full!", Color(1, 0.6, 0.4))
		_btn(vbox, "  ⇩  Unequip  (move to bag)  ", unequip_cb, Color(1.0, 0.8, 0.5))

	# The tab body scrolls, so a fully-socketed S item with a long insert
	# list can't overrun the box (_popover_settle caps the scroll height).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(452, 0)
	vbox.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(440, 0)
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)

	match tab:
		"gems": _item_gems_tab(body, item)
		"reforge": _item_reforge_tab(body, item)
		_: _item_info_tab(body, item)
	await _popover_settle(pop, at, scroll, body)


## Info tab: the full stat line + live set-bonus tiers.
func _item_info_tab(body: VBoxContainer, item: Dictionary) -> void:
	var p: Player = game.local_player
	var d := _lbl(body, Items.describe(item, _awk(item)), 13, Color(Items.GRADE_COLOR[item["grade"]], 0.9))
	d.custom_minimum_size = Vector2(440, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Set bonus panel (S legendaries): which tiers are live given what's worn.
	if String(item.get("grade", "")) == "S" and item.has("cls"):
		var sd: Dictionary = Items.SET_BONUSES.get(String(item["cls"]), {})
		if not sd.is_empty():
			var pieces := Items.count_set_pieces(p.equipment, String(item["cls"]))
			_lbl(body, "SET: %s   (%d/4 pieces worn)" % [sd.get("name", "Set"), pieces], 15, Color(1.0, 0.85, 0.4))
			for tier in ["2", "4"]:
				var live := pieces >= int(tier)
				_lbl(body, "   %spc %s  —  %s" % [tier, "✓ ACTIVE" if live else "inactive",
					_stat_bonus_text(sd[tier])], 13, Color(0.6, 1.0, 0.6) if live else Color(0.6, 0.62, 0.68))


## Gems tab: real socket squares (click a gem for its card, drag it out to
## unsocket, drop a bag gem onto an empty one), then the insert-from-bag list.
func _item_gems_tab(body: VBoxContainer, item: Dictionary) -> void:
	var p: Player = game.local_player
	var slots: int = item.get("gem_slots", 0)
	var gems: Array = item.get("gems", [])
	if slots == 0:
		_lbl(body, "This item has no sockets — only B-grade gear and above can hold gems.", 13, Color(0.55, 0.55, 0.6))
		return
	var spec_cap: int = Items.special_slots(String(item.get("grade", "")))
	if spec_cap > 0:
		var spec_names: Array = []
		for s in Balance.SPECIAL_GEM_STATS:
			spec_names.append(Items.STAT_LABEL.get(s, s))
		_lbl(body, "★ %d special slot (%s) + %d regular." % [
			spec_cap, "/".join(spec_names), slots - spec_cap], 12, SPECIAL_SOCKET_COLOR)
	var refresh := func() -> void: open_item_panel(item, Vector2(-1, -1), "gems")
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	body.add_child(srow)
	_socket_row(srow, item, refresh)
	_lbl(body, "Click a gem for its card · drag it off the box to unsocket it.", 12, Color(0.55, 0.58, 0.66))

	if slots > gems.size():
		if p.gem_bag.is_empty():
			_lbl(body, "No gems in your bag to insert (they drop from chests).", 12, Color(0.5, 0.5, 0.55))
		else:
			_lbl(body, "INSERT FROM BAG:", 15, Color(0.95, 0.85, 0.5))
			# Two-column gem grid straight in the scrolling body — no nested
			# scroll (that one collapsed to 0px and hid every insert button).
			var groups := _gem_groups()
			var igrid := GridContainer.new()
			igrid.columns = 1  # single column — the popover is narrower than the old panel
			igrid.add_theme_constant_override("h_separation", 12)
			igrid.add_theme_constant_override("v_separation", 4)
			igrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(igrid)
			for key in _sorted_gem_keys(groups):
				var group: Dictionary = groups[key]
				var g2: Dictionary = group["gem"]
				# Say IN-PANEL why a gem won't fit here (the old refusal floated
				# behind the menu as world text — read as "nothing happened").
				var err := game.local_player.gem_socket_error(item, g2)
				if err == "":
					var ins_cb := func() -> void:
						game.local_player.embed_gem_into(item, g2)
						open_item_panel(item, Vector2(-1, -1), "gems")
					var ib := _btn(igrid, "%s  x%d — insert" % [Items.gem_title(g2), group["count"]], ins_cb, Items.gem_color(g2))
					ib.clip_text = true
					ib.custom_minimum_size = Vector2(414, 0)
				else:
					var db := _btn(igrid, "%s  x%d — %s" % [Items.gem_title(g2), group["count"], err],
						Callable(), Color(0.5, 0.5, 0.55), false)
					db.clip_text = true
					db.custom_minimum_size = Vector2(414, 0)


## Reforge tab: gold-cost crafting on this item.
func _item_reforge_tab(body: VBoxContainer, item: Dictionary) -> void:
	var p: Player = game.local_player
	_lbl(body, "REFORGE BENCH (spend gold)", 16, Color(0.95, 0.85, 0.5))
	if _reforge_msg != "":
		_lbl(body, _reforge_msg, 12, _reforge_msg_color)
		_reforge_msg = ""
	var subs2: Dictionary = item.get("subs", {})
	# S-gear reforges within its own class; everything else uses the wearer's.
	var rcls: String = String(item.get("cls", p.cls))
	if subs2.is_empty() and not Items.can_add_socket(item) and item.get("main", {}).is_empty():
		_lbl(body, "Nothing to reforge — no affixes to reroll or sockets to add.",
			12, Color(0.55, 0.55, 0.6))
	# --- QUENCH: reroll a stat's band, keep the higher (never regresses) ---
	# Main stat first, then each rollable sub. plus scales the kept value later.
	var quench_stats: Array = item.get("main", {}).keys() + subs2.keys()
	var any_quench := false
	for stat in quench_stats:
		var qs := String(stat)
		if not Items.can_quench(item, qs):
			continue
		if not any_quench:
			_lbl(body, "Quench — reroll a stat's roll, keep the better result:", 12, Color(0.7, 0.85, 1.0))
			any_quench = true
		var store: Dictionary = item["main"] if item.get("main", {}).has(qs) else subs2
		var cur: float = float(store[qs])
		var band := Items.stat_band(item, qs)
		var qcost := Items.quench_cost(item, qs)
		var at_max: bool = cur >= float(band[1]) - 0.01
		var q_cb := func() -> void:
			if game.local_player.gold >= qcost:
				game.local_player.gold -= qcost
				var r := Items.quench_stat(item, qs, game.loot_rng)
				if bool(r["improved"]):
					_reforge_msg = "%s quenched: %s → %s  (max %s)" % [Items.STAT_LABEL.get(qs, qs),
						String.num(r["old"], 2), String.num(r["kept"], 2), String.num(r["max"], 2)]
					_reforge_msg_color = Color(0.5, 1.0, 0.5)
					game.sfx("ward")
				else:
					_reforge_msg = "%s: rolled %s, kept your %s" % [Items.STAT_LABEL.get(qs, qs),
						String.num(r["rolled"], 2), String.num(r["kept"], 2)]
					_reforge_msg_color = Color(0.85, 0.8, 0.6)
					game.sfx("equip")
				game.local_player.recalc()
				open_item_panel(item, Vector2(-1, -1), "reforge")
		if at_max:
			_lbl(body, "   %s: %s / %s — MAX ROLL" % [Items.STAT_LABEL.get(qs, qs),
				String.num(cur, 2), String.num(float(band[1]), 2)], 12, Color(0.6, 0.85, 0.6))
		else:
			_btn(body, "   Quench %s: %s / %s  —  %d gold" % [Items.STAT_LABEL.get(qs, qs),
				String.num(cur, 2), String.num(float(band[1]), 2), qcost], q_cb,
				Color(0.75, 0.85, 0.95) if p.gold >= qcost else Color(0.5, 0.5, 0.55))
	# --- Reforge: reroll ONE substat slot into a different affix (you pick which) ---
	var acost := Items.reforge_cost(item, "affix")
	var reforgeable := false
	for stat in subs2.keys():
		var rs := String(stat)
		if not Items.can_reforge_affix(item, rs):
			continue
		if not reforgeable:
			_lbl(body, "Reforge — reroll a substat into a different affix:", 12, Color(1.0, 0.8, 0.6))
			reforgeable = true
		var rf_cb := func() -> void:
			if game.local_player.gold >= acost:
				game.local_player.gold -= acost
				var new_stat := Items.reforge_affix(item, rs, rcls, game.loot_rng)
				if new_stat != "":
					_reforge_msg = "Reforged %s → %s" % [Items.STAT_LABEL.get(rs, rs), Items.STAT_LABEL.get(new_stat, new_stat)]
					_reforge_msg_color = Color(1.0, 0.85, 0.5)
					game.sfx("equip")
				game.local_player.recalc()
				open_item_panel(item, Vector2(-1, -1), "reforge")
		_btn(body, "   Reforge %s → ?  —  %d gold" % [Items.STAT_LABEL.get(rs, rs), acost], rf_cb,
			Color(0.9, 0.82, 0.7) if p.gold >= acost else Color(0.5, 0.5, 0.55))
	# --- Transmute main: point the rolled budget at another attribute ---
	# Keeps the roll, changes what it feeds — the bench half of an off-meta build.
	if Items.can_transmute_main(item):
		var tcost := Items.transmute_cost(item)
		var main_stat := String(item["main"].keys()[0])
		_lbl(body, "Transmute — convert the main attribute (keeps its roll):", 12, Color(0.85, 0.72, 1.0))
		for target in Items.transmute_targets(item):
			var tgt := String(target)
			var t_cb := func() -> void:
				if game.local_player.gold >= tcost:
					game.local_player.gold -= tcost
					var was := Items.transmute_main(item, tgt)
					if was != "":
						_reforge_msg = "Transmuted %s → %s (roll kept)" % [
							Items.STAT_LABEL.get(was, was), Items.STAT_LABEL.get(tgt, tgt)]
						_reforge_msg_color = Color(0.85, 0.72, 1.0)
						game.sfx("ward")
					game.local_player.recalc()
					open_item_panel(item, Vector2(-1, -1), "reforge")
			_btn(body, "   %s → %s  —  %d gold" % [Items.STAT_LABEL.get(main_stat, main_stat),
				Items.STAT_LABEL.get(tgt, tgt), tcost], t_cb,
				Color(0.85, 0.75, 0.95) if p.gold >= tcost else Color(0.5, 0.5, 0.55))
	# --- Add gem socket: ONE-TIME, steep, tier-scaled (Balance.ADD_SOCKET_COST) ---
	if Items.can_add_socket(item):
		var ccost := Items.reforge_cost(item, "socket")
		var sock_cb := func() -> void:
			if game.local_player.gold >= ccost:
				game.local_player.gold -= ccost
				Items.add_socket(item)
				game.local_player.recalc()
				game.sfx("chest")
				_reforge_msg = "Socket added — this is the only one this piece can take."
				_reforge_msg_color = Color(0.6, 1.0, 0.6)
				open_item_panel(item, Vector2(-1, -1), "reforge")
		_btn(body, "Add gem socket (one-time)  —  %d gold" % ccost, sock_cb,
			Color(0.6, 1.0, 0.6) if p.gold >= ccost else Color(0.5, 0.5, 0.55))
	_lbl(body, "Your gold: %d" % p.gold, 13, Color(1.0, 0.85, 0.35))


## The full socket row for an item: regular squares first, then the SPECIAL
## square(s) (A+ gear, one per item) marked in violet. The gems array is
## unordered — sockets are TYPED, not positional — so the row re-buckets
## what's socketed by type and remembers each gem's real array index.
func _socket_row(row: Control, item: Dictionary, refresh: Callable) -> void:
	var slots: int = item.get("gem_slots", 0)
	var spec_cap: int = Items.special_slots(String(item.get("grade", "")))
	var gems: Array = item.get("gems", [])
	var reg_idx: Array = []
	var spec_idx: Array = []
	for i in gems.size():
		if String(gems[i]["stat"]) in Balance.SPECIAL_GEM_STATS:
			spec_idx.append(i)
		else:
			reg_idx.append(i)
	for k in slots - spec_cap:
		_socket_square(row, item, int(reg_idx[k]) if k < reg_idx.size() else -1, false, refresh)
	for k in spec_cap:
		_socket_square(row, item, int(spec_idx[k]) if k < spec_idx.size() else -1, true, refresh)


const SPECIAL_SOCKET_COLOR := Color(0.78, 0.72, 0.98)  # violet — the A+ special slot

## One REAL gem-socket square (2026-07-09, replacing the ◆◇ glyphs): filled
## shows the actual gem — click for the same detail card a bag gem gets, drag
## it out to unsocket; empty is a drop target for a bag gem and clicks through
## to the item panel's Gems tab. `gem_idx` is the gem's index in item["gems"]
## (-1 = empty). A `special` square keeps a violet border whatever it holds,
## and only accepts special gems (regular squares refuse them right back).
func _socket_square(row: Control, item: Dictionary, gem_idx: int, special: bool, refresh: Callable) -> void:
	var gems: Array = item.get("gems", [])
	var filled: bool = gem_idx >= 0
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	# The border says what the SLOT is (violet = special), not what's in it —
	# the gem's own icon already carries its color.
	var col: Color = SPECIAL_SOCKET_COLOR if special \
		else (Items.gem_color(gems[gem_idx]) if filled else Color(0.4, 0.42, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.18, 0.92) if special else Color(0.09, 0.09, 0.12, 0.92)
	sb.border_color = Color(col, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.2, 0.17, 0.28, 0.95) if special else Color(0.17, 0.17, 0.23, 0.95)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	row.add_child(b)
	# Name the special stats from the data, not a hardcoded list — new special
	# gems (e.g. Tenacity, 2026-07-09) keep the tooltip honest for free.
	var spec_names: Array = []
	for s in Balance.SPECIAL_GEM_STATS:
		spec_names.append(Items.STAT_LABEL.get(s, s))
	var kind_txt := ("SPECIAL socket (%s only)" % "/".join(spec_names)) if special else "socket"
	if filled:
		var g: Dictionary = gems[gem_idx]
		b.icon = Art.gem_icon(Items.gem_color(g), int(g["lvl"]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = "%s — in the %s\nClick for its card · drag to the bag to unsocket." % [Items.gem_title(g), kind_txt]
		b.pressed.connect(func() -> void: _open_socketed_gem_popover(item, gem_idx, refresh))
		var drag_fn := func(_pos: Vector2) -> Variant:
			b.set_drag_preview(_drag_preview(Art.gem_icon(Items.gem_color(g), int(g["lvl"]))))
			return {"kind": "socketed_gem", "item": item, "idx": gem_idx}
		b.set_drag_forwarding(drag_fn, Callable(), Callable())
	else:
		b.text = "★" if special else "◇"
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color(SPECIAL_SOCKET_COLOR, 0.7) if special else Color(0.45, 0.48, 0.56))
		b.tooltip_text = "Empty %s — drag a matching gem from the bag onto it." % kind_txt
		b.pressed.connect(func() -> void: open_item_panel(item, Vector2(-1, -1), "gems"))
		var can_fn := func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary and String(data.get("kind", "")) == "bag_gem"):
				return false
			var g2: Dictionary = data["gem"]
			if (String(g2["stat"]) in Balance.SPECIAL_GEM_STATS) != special:
				return false  # the square's type must match the gem's
			return game.local_player.gem_socket_error(item, g2) == ""
		var drop_fn := func(_pos: Vector2, data: Variant) -> void:
			game.local_player.embed_gem_into(item, data["gem"])
			refresh.call()
		b.set_drag_forwarding(Callable(), can_fn, drop_fn)


## A socketed gem's detail card — the bag gem's popover, adapted: same
## header and info, with Remove (back to bag) in place of drop/synthesize.
func _open_socketed_gem_popover(item: Dictionary, idx: int, refresh: Callable) -> void:
	var gems: Array = item.get("gems", [])
	if idx < 0 or idx >= gems.size():
		return
	var g: Dictionary = gems[idx]
	var info := "Socketed in %s.\n\nRemove it and it returns to your bag\n(you can also just drag it there)." % Items.title(item)
	var remove_cb := func() -> void:
		game.local_player.remove_gem(item, idx)
		refresh.call()
	_open_detail_popover(Art.gem_icon(Items.gem_color(g), int(g["lvl"])), Items.gem_title(g),
		Items.gem_color(g), info, [["  ⇩  Remove  (back to bag)  ", Color(1.0, 0.8, 0.5), remove_cb]])


## A floating icon that follows the cursor during a gem drag.
func _drag_preview(icon: Texture2D) -> Control:
	var t := TextureRect.new()
	t.texture = icon
	t.custom_minimum_size = Vector2(40, 40)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


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
	var p: Player = game.local_player
	var vbox := _open("%s — %s" % [Classes.CLASSES[p.cls]["name"], "Skill Tree" if tab == "talents" else "Attributes"], 1120, 640, true)
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
		var h := UITheme.header(_lbl(head, theme["name"].to_upper(), 15, theme["color"]))
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
				if game.local_player.add_tree_point(cd["id"]):
					open_skills()
			var b := _btn(row_box, "%s  [%d/%d]\n%s" % [cd["name"], pts, Skills.cell_max(cd), cd["desc"]],
				add_cb, color, can or pts > 0,
				Art.glyph_tex(_cell_glyph(cd), theme_col if unlocked else Color(0.4, 0.4, 0.45)))
			b.custom_minimum_size = Vector2(288, 0)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD  # long talent descs wrap, not overflow
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
			tcolor, p.themes_known > 0, Art.ability_icon(p.cls, s, tcolor))
	# One-click loadouts: opt every ability into a single theme.
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 10)
	vbox.add_child(arow)
	var al := _lbl(arow, "All-in:", 14, Color(0.7, 0.72, 0.78))
	al.custom_minimum_size = Vector2(60, 0)
	_btn(arow, " Base ", func() -> void:
		game.local_player.set_all_themes("")
		open_skills(), Color(0.85, 0.85, 0.9), p.themes_known > 0)
	for i2 in Classes.THEMES[p.cls].size():
		var th: Dictionary = Classes.THEMES[p.cls][i2]
		var tid: String = th["id"]
		var t_unlocked: bool = i2 < p.themes_known
		_btn(arow, " %s " % th["name"], func() -> void:
			game.local_player.set_all_themes(tid)
			open_skills(), th["color"] if t_unlocked else Color(0.4, 0.4, 0.45), t_unlocked)
	_hint(vbox, "ESC / T to close — themes change how your abilities behave")


## Attribute allocation: +1 point per level. The four attributes
## convert at CLASS scaling ratios; the substat rows convert 1:1 for
## every class (combo is deliberately not purchasable).
func _build_attributes_tab(vbox: VBoxContainer, p: Player) -> void:
	_lbl(vbox, "Every level grants 1 attribute point. Attributes convert by class — %s scales best with %s — or pour points straight into a substat." % [Classes.CLASSES[p.cls]["name"], Classes.CLASSES[p.cls]["primary"]], 13, Color(0.6, 0.62, 0.68))
	_lbl(vbox, "Unspent: %d points" % p.unspent_attr, 18, Color(0.5, 1.0, 0.5) if p.unspent_attr > 0 else Color(0.6, 0.6, 0.65))
	# Rows + stat sheet scroll inside the panel (like the talents tab) — the
	# full list is taller than the panel, so without this the "YOUR STATS"
	# block spilled off the bottom edge onto the HUD.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for attr in Classes.ATTR_NAMES:
		var a: String = attr
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == a
		_attr_row(list, p, a, "%s  %d%s" % [a, p.attr_points[a], "  ★" if is_primary else ""],
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9),
			Classes.attr_text(p.cls, a))
	_lbl(list, "SUBSTATS", 15, Color(0.95, 0.85, 0.5))
	for attr in Classes.SUBSTAT_NAMES:
		var a: String = attr
		_attr_row(list, p, a, "%s  %d" % [a, p.attr_points[a]],
			Color(0.75, 0.8, 0.92), Classes.substat_text(a))
	_lbl(list, "YOUR STATS", 16, Color(0.95, 0.85, 0.5))
	_lbl(list, p.stat_sheet(), 13, Color(0.75, 0.78, 0.85))
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
		game.local_player.add_attr_points(a, 1)
		open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
	_btn(row, " +5 ", func() -> void:
		game.local_player.add_attr_points(a, 5)
		open_skills("attributes"), Color(0.5, 1.0, 0.5), p.unspent_attr > 0)
	var desc := _lbl(row, desc_text, 13, Color(0.68, 0.7, 0.78))
	desc.custom_minimum_size = Vector2(620, 0)


## Dedicated variant chooser: shows the base ability and every theme
## variant with its icon and exactly what it changes.
func open_theme_picker(slot: String) -> void:
	var p: Player = game.local_player
	var ab := Classes.ability(p.cls, slot)
	var vbox := _open("%s — choose a variant" % ab["name"], 940, 620, true)
	current = "theme_pick"

	# Every variant below INHERITS this base ability and changes one facet of it —
	# so the base is the option to read first.
	_lbl(vbox, "Each variant inherits this base ability and changes one facet of it. Pick Base to run it unthemed.",
		12, Color(0.62, 0.64, 0.72))

	var is_base: bool = p.ability_theme.get(slot, "") == ""
	var none_cb := func() -> void:
		game.local_player.set_ability_theme(slot, "")
		open_skills()
	_btn(vbox, ("●  " if is_base else "   ") + "Base", none_cb, Color(0.9, 0.9, 0.95),
		true, Art.ability_icon(p.cls, slot))
	# The base ability's full readout sits directly under its button — mirroring
	# the variant layout (option, then exactly what it does).
	var base_scaling: String = Classes.ability_scaling(p.cls, slot)
	var base_riders: String = Classes.ability_riders(p.cls, slot)
	var base_text: String = String(ab["desc"])
	if base_scaling != "":
		base_text += "\n[ %s ]" % base_scaling
	if base_riders != "":
		base_text += "\n[ %s ]" % base_riders
	var base_l := _lbl(vbox, base_text, 12, Color(0.72, 0.74, 0.82))
	base_l.custom_minimum_size = Vector2(860, 0)

	for i in Classes.THEMES[p.cls].size():
		var theme: Dictionary = Classes.THEMES[p.cls][i]
		var unlocked: bool = i < p.themes_known
		var selected: bool = p.ability_theme.get(slot, "") == theme["id"]
		var tcolor: Color = theme["color"] if unlocked else Color(0.4, 0.4, 0.45)
		var pick := func() -> void:
			game.local_player.set_ability_theme(slot, theme["id"])
			open_skills()
		var title: String = ("●  " if selected else "   ") + theme["name"].to_upper()
		if not unlocked:
			title += "   (unlocks at Lv %d)" % Classes.THEME_LEVELS[i]
		_btn(vbox, title, pick, tcolor, unlocked,
			Art.ability_icon(p.cls, slot, tcolor))
		# What this theme does to THIS ability — every pair is unique.
		var vdesc := Classes.variant_desc(p.cls, slot, theme["id"])
		var vfx := Classes.fx_text(Classes.ability_fx(p.cls, slot, theme["id"]), p.cls)
		var d := _lbl(vbox, vdesc + ("\n" + vfx if vfx != "" else ""), 12,
			Color(0.68, 0.7, 0.78) if unlocked else Color(0.45, 0.45, 0.5))
		d.custom_minimum_size = Vector2(860, 0)
	_btn(vbox, "  ← Back to skill tree  ", func() -> void: open_skills(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back to the skill tree")


# -------------------------------------------------------------------- shop ---

## `tab` empty = keep the current tab (so buy/sell actions refresh in place).
func open_shop(zone: int, tab := "") -> void:
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
		var stock_n: int = int(Balance.SHOP_STOCK_BY_TIER.get(tier, 3))
		# Round 51: stock grade follows the ACT appearance table (Items.
		# roll_shop_grade), clamped to loot_cap — not the old chest tiers.
		for i in stock_n:
			var sg := Items.roll_shop_grade(game.chapter_id, rng, game.loot_cap())
			stock.append(Items.roll_gear_of_grade(sg, rng, game.local_player.cls))
		game.shop_stock[zone] = stock
	# Bags on the shelf (round 52): 1 (Act 1) or 1-2 (Act 2/3) of a rollable
	# act tier — kept alongside gear stock until bought out.
	if not game.shop_bags.has(zone):
		var brng := RandomNumberGenerator.new()
		brng.randomize()
		var bact: int = Story.act_of(game.chapter_id)
		var bcount: Array = Balance.SHOP_BAG_COUNT.get(bact, [1, 1])
		var nbags: int = brng.randi_range(int(bcount[0]), int(bcount[1]))
		var bstock: Array = []
		for i in nbags:
			bstock.append(Items.make_bag(Balance.roll_bag_grade(game.chapter_id, brng)))
		game.shop_bags[zone] = bstock

	if tab == "":
		tab = shop_tab
	shop_tab = tab

	var p: Player = game.local_player
	var vbox := _open("Merchant — you have %d gold" % p.gold, 1120, 600, true)
	current = "shop"
	# (T7) The merchant reads the shard before quoting a price.
	match Story.res_band(p.resonance):
		"steady":
			_lbl(vbox, "\"For YOU? Fair rates, friend — the road speaks well of you.\"  (prices 10% kinder)", 14, Color(0.6, 0.9, 0.6))
		"tempted":
			_lbl(vbox, "\"Prices are... firm today. Nothing personal — the till gets nervous around your sort.\"  (prices 10% wary)", 14, Color(1.0, 0.65, 0.55))
		_:
			_lbl(vbox, "\"Ah, a customer! Dangerous roads make good business.\"", 14, Color(0.75, 0.7, 0.6))

	# Codex-style tabs: Buy / Sell, each a full-width view. They used to sit
	# side-by-side in two columns, which cramped both lists (2026-07-09).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  Buy  ", func() -> void: open_shop(zone, "buy"),
		Color(0.95, 0.85, 0.5) if tab == "buy" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  Sell  ", func() -> void: open_shop(zone, "sell"),
		Color(0.95, 0.85, 0.5) if tab == "sell" else Color(0.6, 0.6, 0.6))

	if tab == "sell":
		_shop_sell(vbox, zone, p)
	else:
		_shop_buy(vbox, zone, p)
	_hint(vbox)


## A 2-up card grid for a shelf of items. The old shop stacked every item as a
## full-width row, so a ~500px label sat in a ~1070px box and wasted the whole
## right half; two roomy columns halve that whitespace and read like the bag.
func _shop_grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


## One compact card in a _shop_grid: icon + grade-colored title over a detail/
## price line, boxed like a bag slot. `title`/`detail` render as two lines of
## the same grade color (matching the old single-color rows). Fills its column.
func _shop_card(grid: GridContainer, icon: Texture2D, title: String, detail: String,
		color: Color, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, detail] if detail != "" else title
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	b.add_theme_color_override("font_disabled_color", Color(color, 0.4))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 54)
	if icon != null:
		b.icon = icon
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	# Boxed like _bag_slot: grade border + dark fill, brighter border on hover.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.12, 0.92)
	sb.border_color = Color(color, 0.55 if enabled else 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.17, 0.17, 0.23, 0.95)
	sbh.border_color = Color(color, 0.9)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	if enabled:
		b.pressed.connect(func() -> void:
			if game:
				game.sfx("ui_click"))
		b.pressed.connect(cb)
	grid.add_child(b)
	return b


## Buy tab (full width): rolled gear + upgrades, consumables, then the
## miscellaneous shelf (gems, bags, gamble). Scrolls — the full shelf is
## taller than the panel and otherwise spills into the HUD/quickbar.
func _shop_buy(vbox: VBoxContainer, zone: int, p: Player) -> void:
	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(buy_scroll)
	var buy := VBoxContainer.new()
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_constant_override("separation", 6)
	buy_scroll.add_child(buy)

	var haggle: float = game.band_price_mult()
	# Round 51: gear buy = FARM-COST (Items.shop_buy_price), so buying never
	# beats farming. Consumables/health potion stay flat staples; the old
	# per-level ladder is retired.

	# ================================================================ GEAR ===
	# The headline purchase leads the column: rolled stock, then upgrades.
	_lbl(buy, "— Gear —", 13, Color(0.62, 0.64, 0.7))
	var gear_grid := _shop_grid(buy)
	for item in game.shop_stock[zone]:
		var it: Dictionary = item
		var cost := int(ceil(Items.shop_buy_price(it, game.chapter_id) * haggle))
		var can_afford: bool = p.gold >= cost
		# Click opens the same detail popover the bag uses — full breakdown +
		# "Compared to equipped" + a Buy button — instead of buying on contact.
		var open_cb := func() -> void:
			var info := "%d gold\n%s\n\nCompared to what's equipped:\n%s" % [cost, Items.describe(it, _awk(it)), _diff_tip(it)]
			var actions: Array = []
			if can_afford:
				var buy_cb := func() -> void:
					if p.bag_used() >= p.bag_capacity():
						game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
					else:
						p.gold -= cost
						game.shop_stock[zone].erase(it)
						p.add_item(it)
						game.sfx("potion")
					open_shop(zone)
				actions.append(["  🪙  Buy — %d gold  " % cost, Color(0.6, 1.0, 0.6), buy_cb])
			else:
				info += "\n\n(Not enough gold — %d short.)" % (cost - p.gold)
			_open_detail_popover(Art.icon_for(it), Items.title(it), Items.GRADE_COLOR[it["grade"]], info, actions)
		_shop_card(gear_grid, Art.icon_for(it), Items.title(it),
			"%s — %d gold" % [Items.describe(it, _awk(it)), cost],
			Items.GRADE_COLOR[it["grade"]], true, open_cb)
	_lbl(buy, "Upgrade equipped gear", 13, Color(0.6, 0.85, 1.0))
	if _smith_msg != "":
		_lbl(buy, _smith_msg, 12, _smith_msg_color)
		_smith_msg = ""
	var up_grid := _shop_grid(buy)
	for slot in ["weapon", "armor"]:
		if p.equipment.has(slot):
			var item: Dictionary = p.equipment[slot]
			if not Items.can_upgrade(item):
				_shop_card(up_grid, Art.icon_for(item), Items.title(item),
					"MAX +%d — fully upgraded" % int(item["plus"]),
					Color(0.72, 0.68, 0.5), false, func() -> void: pass)
				continue
			var cost := Items.upgrade_cost(item)
			var succ := Balance.upgrade_success(int(item["plus"]))
			var do_upgrade := func() -> void:
				if p.gold >= cost:
					p.gold -= cost
					if randf() < succ:
						item["plus"] = int(item["plus"]) + 1
						_smith_msg = "%s upgraded to +%d!" % [Items.title(item), int(item["plus"])]
						_smith_msg_color = Color(0.5, 1.0, 0.5)
						game.sfx("levelup")
					else:
						# Gold-only fail (2026-07-13): the attempt is spent, but the
						# item keeps its plus — no downgrade.
						_smith_msg = "Upgrade FAILED — %s held at +%d (gold spent)" % [Items.title(item), int(item["plus"])]
						_smith_msg_color = Color(1.0, 0.5, 0.4)
						game.sfx("hurt")
					p.recalc()
				open_shop(zone)
			_shop_card(up_grid, Art.icon_for(item), Items.title(item),
				"→ +%d  •  +%d%% all stats  •  %d%% success — %d gold" % [
					int(item["plus"]) + 1, int(round(Balance.UPGRADE_PCT_PER_PLUS * 100.0)),
					int(round(succ * 100.0)), cost],
				Color(0.6, 0.9, 1.0), p.gold >= cost, do_upgrade)

	# ========================================================= CONSUMABLES ===
	_lbl(buy, "— Consumables —", 13, Color(0.62, 0.64, 0.7))
	var cons_grid := _shop_grid(buy)
	# Potion price scales with the chapter (2026-07-09 investment round):
	# potions heal % HP, so their value — and price — grows with the game.
	var potion_cost := int(ceil(float(Balance.potion_price(game.local_player.level)) * haggle))
	var buy_potion := func() -> void:
		if p.gold >= potion_cost:
			# Potions occupy bag slots (2026-07-09 v2): BAG SPACE is the only
			# limit (no separate stock cap) — a full bag blocks the buy.
			if p.can_gain_potion():
				p.gold -= potion_cost
				p.potions += 1
				game.sfx("potion")
			else:
				game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
		open_shop(zone)
	var ptxt := "%d gold  (you have %d)" % [potion_cost, p.potion_count()]
	if not p.can_gain_potion():
		ptxt += "  — bag full"
	_shop_card(cons_grid, Art.tex("potion"), "Health Potion",
		ptxt, Color(1.0, 0.5, 0.5), p.gold >= potion_cost and p.can_gain_potion(), buy_potion)

	# Alchemist's shelf: utility consumables (bag items, used from inventory).
	for spec in [["mana_potion", Items.make_mana_potion()], ["elixir_might", Items.make_elixir_might()],
			["elixir_ward", Items.make_elixir_ward()], ["renewal_draught", Items.make_renewal_draught()],
			["recall_scroll", Items.make_recall_scroll()]]:
		var cid: String = spec[0]
		var made: Dictionary = spec[1]
		var ccost := int(ceil(float(Balance.consumable_price(cid, p.level)) * haggle))
		var buy_cons := func() -> void:
			if p.gold >= ccost:
				# Gold only moves when the item actually lands in the bag.
				if p.add_consumable(made.duplicate(true)):
					p.gold -= ccost
					game.sfx("potion")
				else:
					game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
			open_shop(zone)
		_shop_card(cons_grid, Art.consumable_icon(made), String(made["name"]),
			"%d gold   (%s)" % [ccost, made["desc"]],
			Items.GRADE_COLOR[made["grade"]], p.gold >= ccost, buy_cons)

	# ======================================================= MISCELLANEOUS ===
	_lbl(buy, "— Miscellaneous —", 13, Color(0.62, 0.64, 0.7))
	var misc_grid := _shop_grid(buy)
	# Gem shelf (round 51): buy loose gems at the act's level(s), random stat.
	# Farm-cost priced (Items.gem_buy_price) — a fraction of gear, scales by act.
	# Gated to ch4+ (2026-07-09): merchants don't stock gems before they drop.
	if Balance.regular_gems_drop(game.chapter_id):
		var gem_act: int = int(Balance.CHAPTER_ECON.get(game.chapter_id, {}).get("act", 1))
		var gem_range: Array = Balance.SHOP_GEM_RANGE.get(gem_act, [1, 1])
		for glvl in range(int(gem_range[0]), int(gem_range[1]) + 1):
			var gl := glvl
			var gprice := int(ceil(Items.gem_buy_price(gl, game.chapter_id) * haggle))
			var buy_gem := func() -> void:
				if p.gold >= gprice:
					if p.gain_gem(Items.random_gem(game.loot_rng, gl)):
						p.gold -= gprice
						game.sfx("chest")
					else:
						game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
				open_shop(zone)
			_shop_card(misc_grid, null, "💎 Gem — Lv%d" % gl, "random stat — %d gold" % gprice,
				Color(0.6, 0.9, 1.0), p.gold >= gprice, buy_gem)

	# Bag shelf (round 52): expand carry capacity. Capacity is QoL not power,
	# so bags are priced FAR below gear. Buying joins the equipped set (over
	# MAX_BAGS keeps the best via acquire_bag). Sells for only 1g, so buy >> sell.
	for bag_item in game.shop_bags[zone]:
		var bit: Dictionary = bag_item
		var bcost := int(ceil(float(Items.bag_buy_price(String(bit["grade"]))) * haggle))
		# Grey the buy when it can't raise capacity (round 52b): a full set of
		# bags all >= this one would just cash it for 1g — don't waste gold.
		var bimproves: bool = p.bag_would_improve(int(bit["slots"]))
		var buy_bag := func() -> void:
			if p.gold >= bcost and bimproves:
				p.gold -= bcost
				game.shop_bags[zone].erase(bit)
				p.acquire_bag(bit)
			open_shop(zone)
		var bdetail := "+%d slots — %d gold" % [int(bit["slots"]), bcost]
		if not bimproves:
			bdetail += "  (no gain — bags full & larger)"
		_shop_card(misc_grid, null, "🎒 %s" % String(bit["name"]), bdetail,
			Items.GRADE_COLOR[String(bit["grade"])], p.gold >= bcost and bimproves, buy_bag)

	# Gambling shelf (2026-07-09): the pity machine — rolls the chapter's
	# BOSS band at ~0.8x its expected farm cost (game.gamble_cost). The
	# legacy merchant tier is still passed but no longer shapes anything.
	var gamble_tier := String(game.zones[zone].get("shop_tier",
		["wood", "silver", "silver", "gold"][clampi(zone, 0, 3)]))
	var gcost := game.gamble_cost(gamble_tier)
	var gamble_cb := func() -> void:
		var won: Dictionary = game.gamble(gamble_tier)
		if won.is_empty():
			game.spawn_text(p.global_position + Vector2(0, -50),
				"Bag full!" if p.bag_used() >= p.bag_capacity() else "Not enough gold!", Color(1.0, 0.6, 0.5))
		else:
			game.sfx("chest")
			game.spawn_text(p.global_position + Vector2(0, -60), "GAMBLED: %s" % Items.title(won),
				Items.GRADE_COLOR[won["grade"]], 3.0)
		open_shop(zone)
	_shop_card(misc_grid, null, "🎲 Gamble — %d gold" % gcost,
		"a random BOSS-tier item for this chapter, sight unseen",
		Color(0.85, 0.6, 1.0), p.gold >= gcost, gamble_cb)


## Set the junk-sell floor grade and rebuild the sell tab so the chips + the
## "Sell ≤ X" button reflect the new floor. Kept a named method so the chip's
## callback stays a single-line lambda (a multi-statement one breaks the parse).
func _pick_junk_tier(g: String, zone: int) -> void:
	shop_junk_tier = g
	open_shop(zone, "sell")


## Sell tab: bulk actions (SELL ALL + junk-sell ≤ floor) lead, then gridded
## cards for gear, loose gems, merchant-stocked consumables + spare potions.
func _shop_sell(vbox: VBoxContainer, zone: int, p: Player) -> void:
	_lbl(vbox, "Buy-back is %d%% of market." % int(Balance.MERCHANT_SELL_FRACTION * 100),
		13, Color(0.7, 0.72, 0.78))

	# ---- bulk actions lead the tab (fixed above the scroll, always in reach) ----
	# gear sell values, computed up front so SELL ALL / junk-sell can headline.
	var gear_total := 0
	for item in p.backpack:
		gear_total += maxi(1, int(Items.price(item) * Balance.MERCHANT_SELL_FRACTION))
	if not p.backpack.is_empty():
		var sell_all := func() -> void:
			for item in p.backpack:
				p.strip_gems(item)
			p.gain_gold(gear_total)
			p.backpack.clear()
			game.sfx("potion")
			open_shop(zone)
		var allb := _btn(vbox, "⚑  SELL ALL GEAR (%d) — %d gold" % [p.backpack.size(), gear_total],
			sell_all, Color(1.0, 0.9, 0.4))
		allb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Junk-sell: pick a floor grade, then one click dumps that grade and every
		# grade below it — higher gear is never touched. The floor persists across
		# shop visits (shop_junk_tier). S is intentionally not offerable as a floor.
		var junk_idx := Items.GRADES.find(shop_junk_tier)
		var junk_total := 0
		var junk_n := 0
		for item in p.backpack:
			if Items.GRADES.find(String(item["grade"])) <= junk_idx:
				junk_n += 1
				junk_total += maxi(1, int(Items.price(item) * Balance.MERCHANT_SELL_FRACTION))
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 6)
		vbox.add_child(frow)
		var flbl := _lbl(frow, "Junk floor:", 13, Color(0.7, 0.72, 0.78))
		flbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for gr in ["F", "E", "D", "C", "B", "A"]:
			var g: String = gr
			var picked: bool = shop_junk_tier == g
			# Single-line lambda (via _pick_junk_tier) so the trailing color arg can
			# sit after it — a multi-statement lambda here would be a parse error.
			var chip := _btn(frow, " %s " % g, func() -> void: _pick_junk_tier(g, zone),
				Items.GRADE_COLOR[g] if picked else Color(0.5, 0.5, 0.55))
			chip.add_theme_font_size_override("font_size", 14)
		var sell_junk := func() -> void:
			for item in p.backpack.duplicate():  # erase-while-iterate: walk a copy
				if Items.GRADES.find(String(item["grade"])) <= junk_idx:
					p.strip_gems(item)
					p.backpack.erase(item)
			p.gain_gold(junk_total)
			game.sfx("potion")
			open_shop(zone)
		var junkb := _btn(frow, "🧹  Sell ≤ %s  (%d) — %d gold" % [shop_junk_tier, junk_n, junk_total],
			sell_junk, Color(0.95, 0.82, 0.5) if junk_n > 0 else Color(0.5, 0.5, 0.55), junk_n > 0)
		junkb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var sold_any := false

	# --- gear cards (click sells one; strips gems back into the bag first) ---
	if not p.backpack.is_empty():
		sold_any = true
		_lbl(list, "— Gear —", 13, Color(0.62, 0.64, 0.7))
		var gear_grid := _shop_grid(list)
		for item in p.backpack:
			var it: Dictionary = item
			var value := maxi(1, int(Items.price(it) * Balance.MERCHANT_SELL_FRACTION))
			var sell_one := func() -> void:
				p.strip_gems(it)  # gems pop back into your bag
				p.backpack.erase(it)
				p.gain_gold(value)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(gear_grid, Art.icon_for(it), Items.title(it),
				"sell for %d gold" % value, Items.GRADE_COLOR[it["grade"]], true, sell_one)

	# --- loose gems (priced on gem level, not player level) ---
	var gem_groups := _gem_groups()
	var gem_keys := _sorted_gem_keys(gem_groups)
	if not gem_keys.is_empty():
		sold_any = true
		_lbl(list, "— Gems —", 13, Color(0.62, 0.64, 0.7))
		var gem_grid := _shop_grid(list)
		for key in gem_keys:
			var g: Dictionary = gem_groups[key]["gem"]
			var gcount: int = gem_groups[key]["count"]
			var gval := maxi(1, int(Balance.gem_gold_value(int(g["lvl"])) * Balance.MERCHANT_SELL_FRACTION))
			var xn := "  (x%d)" % gcount if gcount > 1 else ""
			var sell_gem := func() -> void:
				p.gem_bag.erase(g)  # one of the interchangeable stack
				p.gain_gold(gval)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(gem_grid, Art.gem_icon(Items.gem_color(g), int(g["lvl"])),
				"%s%s" % [Items.gem_title(g), xn], "sell one for %d gold" % gval,
				Items.gem_color(g), true, sell_gem)

	# --- consumables: ONLY merchant-stocked ones (in CONSUMABLE_PRICES), plus
	# spare health potions. Quest keepsakes (kind "quest") and elite utility
	# (stone/tome) have no market price -> never sellable, so run-scoped quest
	# items can't be lost. ---
	var cg := {}
	var corder: Array = []
	for c in p.consumables:
		var cc0: Dictionary = c
		var gid := String(cc0.get("id", ""))
		if not Balance.CONSUMABLE_PRICES.has(gid):
			continue
		if not cg.has(gid):
			cg[gid] = {"c": cc0, "count": 0}
			corder.append(gid)
		cg[gid]["count"] += 1
	if not corder.is_empty() or p.potions > 0:
		sold_any = true
		_lbl(list, "— Consumables —", 13, Color(0.62, 0.64, 0.7))
		var cons_grid := _shop_grid(list)
		for gid in corder:
			var cc: Dictionary = cg[gid]["c"]
			var ccount: int = cg[gid]["count"]
			var cval := maxi(1, int(float(Balance.CONSUMABLE_PRICES[gid]) * Balance.MERCHANT_SELL_FRACTION))
			var xn2 := "  (x%d)" % ccount if ccount > 1 else ""
			var sell_cons := func() -> void:
				p.consumables.erase(cc)
				p.gain_gold(cval)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(cons_grid, Art.consumable_icon(cc), "%s%s" % [String(cc["name"]), xn2],
				"sell one for %d gold" % cval, Items.GRADE_COLOR[String(cc.get("grade", "C"))],
				true, sell_cons)

		# Spare health potions (the on-player counter). BOUGHT stock only
		# (potions_free — the expiring ch1-3 teaching potion — is never sellable),
		# and the sell basis stays the flat ch1 base price: chapter-scaled buy
		# prices must never open a haul-forward sell spiral.
		if p.potions > 0:
			var hval := maxi(1, int(float(Balance.POTION_PRICE) * Balance.MERCHANT_SELL_FRACTION))
			var sell_pot := func() -> void:
				if p.potions > 0:
					p.potions -= 1
					p.gain_gold(hval)
					game.sfx("potion")
				open_shop(zone)
			_shop_card(cons_grid, Art.tex("potion"), "Health Potion (x%d)" % p.potions,
				"sell one for %d gold" % hval, Color(1.0, 0.5, 0.5), true, sell_pot)

	if not sold_any:
		_lbl(list, "Nothing to sell.", 13, Color(0.5, 0.5, 0.5))


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
	var vbox := _open("Map — %s" % String(Story.chapter(game.chapter_id)["name"]), 1180, 640, true)
	current = "map"
	_lbl(vbox, "Rooms you have entered — click a lit safe camp to travel there. Notches on a room's edge are its doorways; stubs jut toward rooms you haven't explored.", 13, Color(0.7, 0.72, 0.78))

	var board := Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(1120, 440)
	vbox.add_child(board)
	# Chart backdrop (cartography pass 2026-07-10): a parchment-dark board
	# with a bronze inner rim — one visited room no longer floats in void.
	var bbg := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.115, 0.10, 0.072, 0.96)
	bsb.set_corner_radius_all(8)
	bsb.border_color = Color(0.9, 0.8, 0.5, 0.35)
	bsb.set_border_width_all(1)
	bbg.add_theme_stylebox_override("panel", bsb)
	bbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(bbg)
	var brim := Panel.new()
	var brsb := StyleBoxFlat.new()
	brsb.bg_color = Color(0, 0, 0, 0)
	brsb.border_color = Color(UITheme.BRONZE, 0.5)
	brsb.set_border_width_all(1)
	brsb.set_corner_radius_all(6)
	brim.add_theme_stylebox_override("panel", brsb)
	brim.set_anchors_preset(Control.PRESET_FULL_RECT)
	brim.offset_left = 4
	brim.offset_top = 4
	brim.offset_right = -4
	brim.offset_bottom = -4
	brim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(brim)

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

	# Cartographic chrome: a faint surveyor's grid aligned to the room
	# lattice, plus a compass rose in the corner — the chart reads as a
	# chart even when one room is all you've walked. Drawn, not noded:
	# a single ignore-mouse Control with a draw callback is the cheap way.
	var chrome := Control.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(chrome)
	var pitch := Vector2(cw + 10.0, ch + 10.0)
	var grid_org := org - Vector2(5.0, 5.0)
	chrome.draw.connect(func() -> void:
		var sz: Vector2 = chrome.size
		var gcol := Color(0.9, 0.8, 0.5, 0.055)
		var gx: float = fposmod(grid_org.x, pitch.x)
		while gx < sz.x - 6.0:
			if gx > 6.0:
				chrome.draw_line(Vector2(gx, 6.0), Vector2(gx, sz.y - 6.0), gcol, 1.0)
			gx += pitch.x
		var gy: float = fposmod(grid_org.y, pitch.y)
		while gy < sz.y - 6.0:
			if gy > 6.0:
				chrome.draw_line(Vector2(6.0, gy), Vector2(sz.x - 6.0, gy), gcol, 1.0)
			gy += pitch.y
		# Compass rose, top-right: two rings, a long N–S needle, a short
		# E–W one, and N in the display face. Quiet gold — chrome, not UI.
		var cpos := Vector2(sz.x - 58.0, 62.0)
		chrome.draw_arc(cpos, 30.0, 0.0, TAU, 48, Color(0.9, 0.8, 0.5, 0.30), 1.5)
		chrome.draw_arc(cpos, 22.0, 0.0, TAU, 40, Color(0.9, 0.8, 0.5, 0.14), 1.0)
		chrome.draw_colored_polygon(PackedVector2Array([cpos + Vector2(0, -26),
			cpos + Vector2(5, 0), cpos + Vector2(0, 26), cpos + Vector2(-5, 0)]),
			Color(0.9, 0.8, 0.5, 0.32))
		chrome.draw_colored_polygon(PackedVector2Array([cpos + Vector2(-26, 0),
			cpos + Vector2(0, 4), cpos + Vector2(26, 0), cpos + Vector2(0, -4)]),
			Color(0.9, 0.8, 0.5, 0.18))
		var cfont: Font = UITheme.display_font()
		if cfont == null:
			cfont = ThemeDB.fallback_font
		chrome.draw_string(cfont, cpos + Vector2(-5.0, -36.0), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.9, 0.8, 0.5, 0.65)))
	chrome.resized.connect(func() -> void: chrome.queue_redraw())

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
			var here := Panel.new()  # gold frame, breathing — YOU, alive
			var hsb := StyleBoxFlat.new()
			hsb.bg_color = Color(0, 0, 0, 0)
			hsb.border_color = Color(0.95, 0.85, 0.5)
			hsb.set_border_width_all(3)
			hsb.set_corner_radius_all(6)
			here.add_theme_stylebox_override("panel", hsb)
			here.position = p - Vector2(4, 4)
			here.size = Vector2(cw + 8, ch + 8)
			here.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board.add_child(here)
			var htw := here.create_tween().set_loops()
			htw.tween_property(here, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
			htw.tween_property(here, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

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
			var cell := Panel.new()  # rounded, terrain-tinted border
			var csb := StyleBoxFlat.new()
			csb.bg_color = MAP_TYPE_COLOR.get(t, Color(0.3, 0.3, 0.3))
			csb.set_corner_radius_all(4)
			var tint: Color = Terrains.get_terrain(game.terrain_by_zone[i])["tint"]
			csb.border_color = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7)
			csb.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", csb)
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
		# A quiet green check in the corner of every cleansed combat room.
		if game.cleared.get(i, false) and t in ["combat", "elite"] and i != game.cur_room:
			var done_l := _lbl(board, "✓", 12, Color(0.5, 0.95, 0.55))
			done_l.position = p + Vector2(cw - 14.0, ch - 18.0)
			done_l.size = Vector2(14, 16)
			done_l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Legend row — the minimap's own vocabulary (here/boss/cleared), with
	# the current room named on the ◆ chip.
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	vbox.add_child(legend)
	var here_l := _lbl(legend, "◆  %s — you are here" % game.zones[game.cur_room]["name"], 13, Color(0.95, 0.85, 0.5))
	here_l.custom_minimum_size = Vector2(340, 0)
	for spec in [["⌂  safe camp (lit = travel)", Color(0.62, 0.82, 0.62), 200.0],
			["☠  boss door", Color(1.0, 0.6, 0.62), 110.0], ["✓  cleared", Color(0.55, 0.9, 0.58), 95.0],
			["▫  doorway", Color(0.78, 0.74, 0.6), 95.0]]:
		var ll := _lbl(legend, String(spec[0]), 13, spec[1])
		ll.custom_minimum_size = Vector2(float(spec[2]), 0)  # HBox label-collapse trap
	_hint(vbox, "ESC / M to close" +
		("   ·   the doors are sealed mid-fight" if game.barrier_active else ""))


# ------------------------------------------------------------------- codex ---

const BOSS_KINDS := ["fangmaw", "morwen", "vargoth",
	"stormwarden", "choirmother", "nullwarden",  # (T4) ch2 content bosses
	"sexton", "vess", "saint_varo",  # ch3 Unburied Vale (BOSSES.md)
	"forgemistress", "cinderhide", "ashpriest",  # ch4 Slagfields (BOSSES.md)
	"whitepelt", "icebound", "sleepkeeper",  # ch5 Long Sleep (BOSSES.md)
	"auroch", "gardener", "curetwisted",  # ch6 Blooming Deep (BOSSES.md)
	"stormdrake_veyx", "unnamed_echo", "stormmouth",  # ch7 Breaking Sky — Act 1 finale (BOSSES.md)
	# Ninja Adventure sweep (2026-07-08): PLACEHOLDER bosses (pc_bosses.gd) —
	# dev-only (unplaced → codex hides them outside dev), spawnable from the
	# dev panel. Not yet assigned to any chapter.
	"cyclops", "tengu", "flame_giant", "great_spirit", "ooze", "kraken"]

## Codex screens live in ui/codex.gd. Passing a boss `kind` opens that
## boss's focused mechanics detail view instead of the tab list.
func open_codex(tab := "monsters", boss := "") -> void:
	UICodex.open(self, tab, boss)


## Play Together — the co-op lobby (MP-08) lives in ui/lobby.gd.
func open_lobby(stage := "menu") -> void:
	UILobby.open(self, stage)


# ---------------------------------------------------------------- dev mode ---

## The mailbox (dropped-loot letters, gifts) lives in ui/mailbox.gd.
func open_mailbox() -> void:
	UIMailbox.open(self)


## The daily-login reward screen lives in ui/daily.gd.
func open_daily() -> void:
	UIDaily.open(self)


## The quest log / journal lives in ui/journal.gd.
func open_journal() -> void:
	UIJournal.open(self)


## The account-wide stash lives in ui/stash.gd.
func open_stash() -> void:
	UIStash.open(self)


## Debug panel (F1, only when launched via dev_mode.bat) — ui/dev_panel.gd.
## `tab` empty keeps the current subtab (so in-panel refreshes stay put).
func open_dev(tab := "") -> void:
	UIDevPanel.open(self, tab)


# ---------------------------------------------------------------- keybinds ---

func open_keybinds() -> void:
	var vbox := _open("Keybinds — click an action, then press a key", 700, 560, true)
	current = "keybinds"
	var actions := {
		"a1": "Ability 1", "a2": "Ability 2", "a3": "Ability 3", "ult": "Ultimate",
		"potion": "Drink potion", "potion_next": "Cycle potion rotation",
		"interact": "Talk / interact",
		"inventory": "Inventory", "skills": "Skill tree", "codex": "Codex",
		"map": "Map", "target": "Switch target lock",
	}
	# The bind list SCROLLS. The panel's VBox is fixed-size and doesn't
	# clip, so 12 unscrolled rows pushed the footer hints straight through
	# the panel border onto the world (QA: keybinds overflow) — an
	# expand-fill scroll absorbs the excess and pins the footer inside.
	var kscroll := ScrollContainer.new()
	kscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(kscroll)
	var klist := VBoxContainer.new()
	klist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	klist.add_theme_constant_override("separation", 4)
	kscroll.add_child(klist)
	for action in actions:
		var act: String = action
		var key_name := OS.get_keycode_string(game.binds[act])
		var text: String = "%s    —    [ %s ]" % [actions[act], key_name]
		if listening_action == act:
			text = "%s    —    press any key..." % actions[act]
		var rebind_cb := func() -> void:
			listening_action = act
			open_keybinds()
		_btn(klist, text, rebind_cb, Color(1, 1, 0.6) if listening_action == act else Color(1, 1, 1))
	_lbl(vbox, "Movement is always WASD / arrows.", 13, Color(0.6, 0.6, 0.6))
	# Keybinds is a sub-screen of Settings now — Back returns there (the ✕ would
	# drop straight to the world instead).
	_btn(vbox, "  ← Back to settings  ", func() -> void: open_settings(settings_return), Color(0.8, 0.85, 0.9))
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

	# The cover (boot stage 1) advances on ANY key or click.
	if current == "title" and title_stage == "cover" \
			and ((event is InputEventKey and event.pressed and not event.echo)
			or (event is InputEventMouseButton and event.pressed)):
		open_slots()
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
				choose_class(ids[num])  # same splash reveal as a card click
				get_viewport().set_input_as_handled()
			return  # can't ESC out of class select
		if current == "name_entry":
			# ESC steps back to the class picker; every other key falls through
			# UNHANDLED so the focused name field receives the typing (the same
			# reason the dev-roster LineEdit works on the title screen below).
			if event.keycode == KEY_ESCAPE:
				open_class_select()
				get_viewport().set_input_as_handled()
			return
		if current in ["title", "class_select", "class_splash"] \
				or (current == "chapter_select" and not chapter_replay):
			return  # boot menus (incl. the class splash beat): no escaping into a paused void
		# ESC closes any open menu (alongside the on-screen ✕ + click-off);
		# the toggle hotkeys (I / C / M …) also close their own screen.
		if event.keycode == KEY_ESCAPE \
				or (current == "inventory" and event.keycode == game.binds["inventory"]) \
				or (current == "detail" and event.keycode == game.binds["inventory"]) \
				or (current == "skills" and event.keycode == game.binds["skills"]) \
				or (current == "codex" and event.keycode == game.binds["codex"]) \
				or (current == "map" and event.keycode == game.binds.get("map", KEY_M)) \
				or (current == "dev" and event.keycode == KEY_F1):
			if current == "detail":
				_close_detail_popover()  # dismiss the popover, stay on the screen beneath
			elif current == "theme_pick":
				open_skills()  # back to the tree, not out of the menu
			elif current == "lobby":
				UILobby.esc(self)  # one stage back / leave the lobby, never a void
			elif current == "settings":
				_settings_back()  # back to wherever settings was opened from
			elif current == "benchmark_roster":
				open_slots()  # dev roster modal → back to the slot list
			elif current == "confirm" \
					or (current == "chapter_select" and chapter_replay):
				open_pause()  # back to the system menu, not out of it
			else:
				close()
			get_viewport().set_input_as_handled()
