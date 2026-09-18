class_name Menus extends CanvasLayer
## Per-client full-screen menus. All player reads use `game.local_player`.

# Lobby remains path-loaded so it does not require class-name registration.
const UILobby := preload("res://scripts/ui/lobby.gd")
const UIFieldAtlas := preload("res://scripts/ui/field_atlas.gd")
const GearCare := preload("res://scripts/gear_care.gd")
const UIGearInspect := preload("res://scripts/ui/gear_inspect.gd")
# The transport autoload's SCRIPT, for NET_VERSION only (the bare
# `NetworkManager` global doesn't exist under check_compile — MP-05).
const NetManager := preload("res://scripts/net/net_manager.gd")

var game: Game
var root: Control = null          # the currently open panel (null = closed)
var detail_popover: Control = null  # click-to-reveal item/gem/shop popover
var detail_return := ""             # screen the popover overlays (restored on close)
var _popover_box: PanelContainer = null  # the current popover's panel (for re-anchoring)
var _shell_rect := Rect2()          # the open panel's frame — popovers stay inside it
var current := ""
var fm_moot: FangmootMoot = null            # the active Fangmoot moot (session-lived)
var fm_host: FangmootHost = null            # its seam (Crownless in-game, or standalone)
var fm_standalone := false                  # true when launched via --fangmoot (§18)
var fm_opp: Array = []                      # the previewed/fought opponent warband
var fm_opp_turn := -1                       # the turn fm_opp was built for
var fm_speed := 1.0                         # fight replay speed (1x / 2x)
var _closable_now := false        # does the open panel have a ✕ / click-outside exit?
var listening_action := ""        # keybind screen: waiting for a key press
var _confirm_cancel := Callable() # the current confirmation's return path
var shop_zone := -1
var shop_tab := "buy"             # shop: which full-width tab is showing (persists across refreshes)
var shop_junk_tier := "F"         # sell tab: floor grade the one-click junk-sell dumps (that grade and below)
var _smith_msg := ""              # smith: last upgrade result, shown once in the panel (no silent effects)
var _smith_msg_color := Color.WHITE
var _reforge_msg := ""            # reforge bench: last quench/craft result, shown in the item panel
var _reforge_msg_color := Color.WHITE
var inv_cat := "all"              # inventory: last bag category filter (survives item-panel rebuilds)
var inventory_order := "found"
var inventory_notice := ""
var title_stage := "cover"        # boot title: "cover" (splash) -> "slots" (roster)
var chapter_replay := false       # chapter select opened from the pause menu
var dev_boss_mode := 1            # dev panel boss spawn level: 0 story, 1 my Lv (default), 2 +10, 3 +20
var dev_boss_level_override := 0  # dev panel: exact level for NEW boss spawns (0 = off)
var dev_tab := "character"        # dev panel: which subtab is showing (persists across refreshes)
var dev_opener_class := ""        # dev panel: class lens used by the chapter-opener preview
var lobby := {}                   # Play Together flow state (ui/lobby.gd): stage, picks, code, msg
var _talent_renaming := false     # inline rename field for the active talent page
var _ability_preview_slot := ""   # card currently shown in the assignment detail panel
var _ability_preview_theme := ""  # specialization currently being inspected


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


func is_open() -> bool:
	return root != null


## Shell motion (POLISH_TASKS P2, 2026-08-18): screens ease in (fade + a
## 0.97→1 settle around the screen centre) and ease out instead of popping.
## Tweens run PAUSE-ALWAYS because a menu pauses the tree, and stay short so
## nothing waits on them: input is live the same frame.
const SHELL_IN := 0.13
const SHELL_OUT := 0.10
## Rigs and the headless suite shoot/measure a screen the frame it opens —
## they turn the motion off (ShotRig.boot does; headless never eases).
var shell_motion := true


func _shell_motion() -> bool:
	return shell_motion and DisplayServer.get_name() != "headless"


func close() -> void:
	_card_tap = {}
	if root:
		var old := root
		root = null
		if _shell_motion():
			# no clicks on the fading ghost, at any depth
			old.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
			old.pivot_offset = get_viewport().get_visible_rect().size * 0.5
			var tw := old.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(old, "modulate:a", 0.0, SHELL_OUT)
			tw.parallel().tween_property(old, "scale", Vector2(0.985, 0.985), SHELL_OUT) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(old.queue_free)
		else:
			old.queue_free()
	detail_popover = null
	listening_action = ""
	_confirm_cancel = Callable()
	# Boot menus unpause only once the game actually starts. The lobby
	# (MP-08) is boot-context too until a session begins play.
	if not (current in ["class_select", "title"]) \
			and not (current == "chapter_select" and not chapter_replay) \
			and not (current == "lobby" and not game.play_started):
		game.request_pause(false)
	current = ""
	# Boot menus keep the HUD hidden.
	if game and game.hud:
		game.hud.visible = game.play_started
	game.talk_cd = maxf(game.talk_cd, 0.35)  # debounce the reopen hotkeys
	if game.play_started:
		game.autosave()  # menus are where gear/talents/purchases change


# ------------------------------------------------------------ scaffolding ---

## World-owned interaction Labels are outside the HUD. Clear them before a
## solo menu pauses Game; its normal selector restores the nearest after close.
func _hide_world_interaction_prompts() -> void:
	for entry: Dictionary in game.interactables:
		var prompt: Variant = entry.get("prompt")
		if is_instance_valid(prompt) and prompt is CanvasItem:
			prompt.hide()


## Open a FULL-SCREEN shell (no centered panel) — for immersive screens like the
## Fangmoot moot that fill the frame edge to edge. Returns the root Control to
## build into; the caller owns the whole 1280x720 canvas.
func _open_full() -> Control:
	_card_tap = {}
	if root:
		root.queue_free()
	_hide_world_interaction_prompts()
	game.request_pause(true)
	_closable_now = false
	if game._touch_hud != null:
		game._touch_hud._release_everything()
	if game and game.hud:
		game.hud.visible = false
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	detail_popover = null
	_confirm_cancel = Callable()
	UITheme.apply(root)
	return root


## Open the shared modal shell. Closable screens expose ✕ and click-outside.
func _open(title: String, w := 960.0, h := 560.0, closable := false) -> VBoxContainer:
	_card_tap = {}
	# The shell ease plays only when a menu OPENS from gameplay. Rebuilding
	# while one is already up — spending a talent point re-runs open_skills,
	# buying re-runs open_shop, tab hops — must swap instantly: replaying the
	# fade+settle on every refresh read as UI flicker (owner regression flag
	# 2026-08-19).
	var was_open := root != null
	if root:
		root.queue_free()
	_hide_world_interaction_prompts()
	game.request_pause(true)
	_closable_now = closable  # so _hint tells the truth about the exits on touch
	# Release held touch input before the menu's overlay gate takes over.
	if game._touch_hud != null:
		game._touch_hud._release_everything()
	# Full-screen menus replace, rather than overlap, the gameplay HUD.
	if game and game.hud:
		game.hud.visible = false
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	detail_popover = null  # any popover was a child of the old root; drop the ref
	_confirm_cancel = Callable()
	var shell := root  # queued callbacks from a replaced shell cannot dismiss its successor
	# Ease the shell in: fade + a settle around the screen centre (P2).
	if _shell_motion() and not was_open:
		root.pivot_offset = get_viewport().get_visible_rect().size * 0.5
		root.modulate.a = 0.0
		root.scale = Vector2(0.97, 0.97)
		var tw_in := root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.tween_property(root, "modulate:a", 1.0, SHELL_IN)
		tw_in.parallel().tween_property(root, "scale", Vector2.ONE, SHELL_IN) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.012, 0.022, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	if closable:
		# A touch has one dismissal stream: its emulated mouse press, or the
		# raw touch when emulation is off. Otherwise it also dismisses the parent.
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if root != shell:
				return
			if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) \
					or (e is InputEventScreenTouch and e.pressed and not Input.emulate_mouse_from_touch):
				controller_back())
	root.add_child(dim)

	# Boot menus retain the cover's night background.
	if not game.play_started:
		var night := ColorRect.new()
		night.color = Color(0.02, 0.015, 0.045)
		night.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(night)
		root.move_child(night, 0)

	# UITheme owns the shell and all stock-widget styling.
	UITheme.apply(root)
	_shell_rect = Rect2(Vector2(640 - w / 2 - 3, 360 - h / 2 - 3), Vector2(w + 6, h + 6))
	UITheme.panel(root, _shell_rect.position, _shell_rect.size)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(640 - w / 2, 360 - h / 2) + Vector2(28, 20)
	vbox.size = Vector2(w - 56, h - 40)
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	var tl := Label.new()
	tl.text = title
	# Wrapped titles cannot inflate the panel's content width.
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.title(tl, 28)  # display font; ~26px optical in the pixel face
	tl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vbox.add_child(tl)
	UITheme.rule(vbox)  # header underline: gold, fading right

	if closable:
		# Close control is added last so it stays above the shell.
		var xbtn := Button.new()
		xbtn.text = "✕"
		xbtn.flat = true
		xbtn.focus_mode = Control.FOCUS_NONE
		xbtn.add_theme_font_size_override("font_size", 22)
		xbtn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
		xbtn.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.75))
		# A full touch target with the same optical center as the old close glyph.
		xbtn.size = Vector2(44, 44)
		xbtn.position = Vector2(640 - w / 2 - 3 + w + 6 - 46, 360 - h / 2 - 3 + 2)
		xbtn.tooltip_text = "Close"
		xbtn.pressed.connect(func() -> void:
			if root != shell:
				return
			game.sfx("ui_click")
			controller_back())
		root.add_child(xbtn)
	# Enable content drag after callers populate their scroll containers.
	call_deferred("_enable_all_touch_scroll", root)
	return vbox


## Let touch drags propagate from content controls to their ScrollContainer.
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
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 42)
	if enabled:
		b.pressed.connect(func() -> void:
			if game:
				game.sfx("ui_click"))
		b.pressed.connect(cb)
		# P2 press feel: a hand cursor and a 0.97 squeeze while held (theme
		# supplies the hover/pressed boxes; this is the motion on top).
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_press_squeeze(b)
	parent.add_child(b)
	return b


## Buttons squeeze slightly while held and spring back on release — pause-safe
## tweens (menus pause the tree). Pivot is centred lazily on first press so
## late layout can't leave it at the corner.
func _press_squeeze(b: Button) -> void:
	b.button_down.connect(func() -> void:
		if not _shell_motion():
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2(0.97, 0.97), 0.05).set_trans(Tween.TRANS_SINE))
	b.button_up.connect(func() -> void:
		if not _shell_motion():
			return
		var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2.ONE, 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func _tab(parent: Node, text: String, cb: Callable, active: bool,
		accent := UITheme.GOLD) -> Button:
	var color: Color = accent if active else Color(0.68, 0.70, 0.76)
	var b := _btn(parent, text, cb, color)
	UITheme.tab(b, active, accent)
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
	return Items.diff_text(item, game.local_player.equipment.get(item["slot"]))


## Match the keyboard toggle used by _input. Controller Back has its own
## live legend; its D-pad opening shortcut is not a menu-closing command.
func menu_key(action: String) -> String:
	var key := int(game.binds.get(action, KEY_M if action == "map" else KEY_NONE))
	return OS.get_keycode_string(key).to_upper()


func _hint(vbox: Node, text := "ESC to close", touch_text := "") -> void:
	if game and game.touch_mode:
		if touch_text != "":
			text = touch_text
		else:
		# Touch hints only promise exits the current shell actually provides.
			var dash := text.find("—")
			var extra: String = (" " + text.substr(dash)) if dash >= 0 else ""
			if _closable_now:
				text = "Tap ✕ or outside to close" + extra
			else:
				# Preserve useful instructions on non-closable screens.
				text = game.ui_copy(text)
	var l := _lbl(vbox, text, 13, Color(0.55, 0.55, 0.55))
	l.size_flags_vertical = Control.SIZE_SHRINK_END


# ------------------------------------------------------------ title screen ---

## Opening cover; input advances to the roster.
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
	var ver := Label.new()
	ver.text = "build %s" % NetManager.NET_VERSION
	ver.position = Vector2(10, 696)
	ver.size = Vector2(300, 20)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62, 0.8))
	ver.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	ver.add_theme_constant_override("outline_size", 4)
	root.add_child(ver)
	# Surface a host-loss notice once after returning here.
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


## Character roster and new-hero entry.
func open_slots() -> void:
	var saves: Array = SaveGame.list()
	# Content-sized up to the scrollable maximum.
	var slots_h := clampf(300.0 + saves.size() * 68.0 + (44.0 if game.dev_mode else 0.0), 380.0, 560.0)
	var vbox := _open("CROWNLESS — your heroes", 760, slots_h)
	current = "title"
	title_stage = "slots"
	game.set_music("roster")  # carries through chapter + class select

	var have_saves := not saves.is_empty()
	var roster_full := saves.size() >= SaveGame.MAX_SLOTS
	# A NEW hero always begins at Chapter 1 (owner ruling 2026-08-19: "new
	# characters always route to chapter 1, obviously") — straight to the class
	# pick, no chapter selector. Later chapters are the REPLAY picker's business
	# (pause menu, per-hero completed_ flags) and the co-op lobby's; the account-
	# wide meta unlocks still gate those. Tests + dev keep open_chapter_select().
	# At capacity the button is DISABLED and a note points at delete: creating
	# anyway would reuse an occupied slot and erase that hero (CR-001).
	if roster_full:
		_btn(vbox, "  ⚔  New Character  (roster full)  ", func() -> void: pass,
			Color(0.6, 0.62, 0.7), false)
		UITheme.header(_lbl(vbox, "All %d slots are full — delete a hero below to forge a new one." % SaveGame.MAX_SLOTS,
			13, Color(1.0, 0.7, 0.55)))
	else:
		_btn(vbox, "  ⚔  New Character  ", func() -> void: new_character(),
			Color(0.95, 0.85, 0.5))
	_btn(vbox, "  ❖  Play Together  ", func() -> void: open_lobby(),
		Color(0.6, 0.9, 1.0))
	UITheme.header(_lbl(vbox, "— CONTINUE —" if have_saves else "No heroes yet — forge your first.",
		15, Color(0.95, 0.85, 0.5) if have_saves else Color(0.6, 0.62, 0.7)))
	# The roster scrolls while footer actions stay fixed.
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
		# Normalize class portraits into the same nearest-filtered frame.
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
			# The hero's FACE (2026-08-19, the reference rosters): the class
			# painting's head-and-shoulders crop fills the frame — the tiny
			# whole-body sprite it replaces read as a debug thumbnail. The
			# sprite stays the fallback where a class has no painting.
			var port := TextureRect.new()
			port.set_anchors_preset(Control.PRESET_FULL_RECT)
			port.offset_left = 3
			port.offset_top = 3
			port.offset_right = -3
			port.offset_bottom = -3
			port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var splash_key := "class_splash_%s" % String(s["cls"])
			if Art.has_sprite(splash_key):
				var stex: Texture2D = Art.tex(splash_key)
				var ssz := Vector2(stex.get_width(), stex.get_height())
				var cr := _splash_face_crop(splash_key, stex)
				var at := AtlasTexture.new()
				at.atlas = stex
				at.region = Rect2(cr.position * ssz, cr.size * ssz)
				port.texture = at
				port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				port.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				# The paintings are dark-fantasy dark; a small lift keeps a 60 px
				# face readable in the list without flattening it.
				port.modulate = Color(1.14, 1.12, 1.08)
			else:
				port.texture = Art.tex(cls_info["sprite"])
				port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				port.modulate = Color(1.3, 1.28, 1.2)  # tonemap-dark sprites need the lift
			pframe.add_child(port)
		# Lead with the hero's name (account name for unnamed legacy saves) so
		# same-class, same-level heroes stay tellable apart. The ✎ renames.
		var dname := _hero_display_name(String(s.get("name", "")))
		var b := _btn(row, "  %s  —  %s Lv %d" % [dname, cname, s["level"]], resume, Color(0.6, 1.0, 0.6), true)
		b.custom_minimum_size = Vector2(360, 0)
		b.tooltip_text = Story.quest_text(s["quest"])
		var when := Time.get_datetime_string_from_unix_time(s["saved_at"]).replace("T", "  ")
		var wl := _lbl(row, when, 12, Color(0.55, 0.58, 0.66))
		wl.custom_minimum_size = Vector2(170, 0)
		var do_rename := func() -> void:
			open_rename(slot, String(s.get("name", "")))
		_btn(row, " ✎ ", do_rename, Color(0.7, 0.85, 1.0))
		var erase := func() -> void:
			SaveGame.delete(slot)
			open_slots()  # stay on the roster — empty is a valid state now
		_btn(row, " ✕ ", erase, Color(1, 0.5, 0.5))

	_btn(vbox, "  🔊  Settings  ", func() -> void: open_settings("title"), Color(0.8, 0.85, 0.9))
	_dev_roster_row(vbox)
	_hint(vbox, "Continue a saved hero, or forge a new one")


## Dev-only six-class benchmark roster shortcut.
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

## The in-game system menu.
func open_pause() -> void:
	var online: bool = game.net_online()
	var vbox := _open(("Online — " if online else "Paused — ") + String(Story.chapter(game.chapter_id)["name"]), 720, 650 if game.touch_mode else 570, true)
	current = "pause"
	var zi := clampi(game.cur_room, 0, game.zone_count - 1)
	_lbl(vbox, "%s, Level %d — %s" % [Classes.CLASSES[game.local_player.cls]["name"],
		game.local_player.level, game.zones[zi]["name"]], 14, Color(0.7, 0.72, 0.78))
	var resume := _btn(vbox, "Return to game" if online else "Resume game", func() -> void: close(),
		Color(0.58, 1.0, 0.68))
	resume.custom_minimum_size.y = 42
	_btn(vbox, "Combat report — recent damage & last fall", func() -> void:
		preload("res://scripts/ui/combat_report.gd").open(self), Color(0.95, 0.75, 0.60))
	_btn(vbox, "  🔊  " + Loc.t("settings"), func() -> void: open_settings(), Color(0.9, 0.9, 0.95))
	_btn(vbox, "  ◈  Wardrobe  (skins & pets, bought with Renown)",
		func() -> void: open_wardrobe(), Color(0.85, 0.7, 1.0))
	# Solo campaign travel to the capital.
	if not game.endgame_active and game.chapter_id != "capital" and not game.net_online():
		_btn(vbox, "  ⌂  Travel to Crownfall  (the Capital)", func() -> void:
			close()
			game.enter_capital(), Color(0.7, 0.9, 1.0))
	# Host-only removal remains behind a confirmation gate.
	if game.net_online() and game.net_host():
		var kick_sess: Node = get_node("/root/NetworkManager/Session")
		for pid_v in kick_sess.peer_chars:
			var pid: int = int(pid_v)
			if pid == 1:
				continue
			var pname := String(kick_sess.peer_chars[pid].get("name", "player"))
			var kick := func() -> void:
				open_confirm("Remove %s from the party? They keep everything they've earned — but the lobby is locked mid-run, so they can't rejoin until you host again." % pname,
					func() -> void:
						kick_sess.host_kick(pid)
						close())
			_btn(vbox, "  ✕  Remove %s from the party" % pname, kick, Color(1.0, 0.6, 0.55))
	if game.endgame_active:
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
	if game.touch_mode:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var actions := VBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(actions)
		for child in vbox.get_children():
			if child is Button:
				child.custom_minimum_size.y = 44
				child.reparent(actions)
	if online:
		# Read the result of _open/request_pause, including the victory exception.
		var state_hint := "World keeps running" if not get_tree().paused else "Game paused"
		_hint(vbox, "%s · ESC, ✕, or click outside to return" % state_hint,
			"%s · Tap ✕ or outside to return" % state_hint)
	else:
		_hint(vbox, "ESC, ✕, or click anywhere outside to resume")


## A single yes/cancel gate in front of destructive actions.
func open_confirm(msg: String, on_yes: Callable, on_cancel := Callable()) -> void:
	# Size to the message; dismissing the closable panel is cancellation.
	var est_lines: int = int(ceil(msg.length() / 46.0)) + msg.count("\n")
	var vbox := _open("Are you sure?", 680, clampf(300.0 + est_lines * 24.0, 320.0, 600.0), true)
	current = "confirm"
	_confirm_cancel = on_cancel
	var shell := root
	var l := _lbl(vbox, msg, 15, Color(0.9, 0.9, 0.9))
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := func() -> void:
		if root != shell:
			return
		close()
		on_yes.call()
	var no := func() -> void:
		if root == shell:
			controller_back()
	_btn(vbox, "  Yes — do it  ", yes, Color(1.0, 0.6, 0.5))
	_btn(vbox, "  Cancel  ", no, Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to cancel")


## Every cancellation gesture uses the caller's return path exactly once.
func _cancel_confirmation() -> void:
	var cancel := _confirm_cancel
	_confirm_cancel = Callable()
	if cancel.is_valid():
		close()
		cancel.call()
	else:
		open_pause()


## The Stranger's Wager (Q16 minigame): a hooded gambler's shell game. Three
## shells; one hides the pea (the caller rolls `winning` TRUE-random from
## loot_rng, so a reload can't scum it). Presented as a menu, so input is
## OVERLAY-gated — it pauses solo, and online the overlay state gates input,
## never the tree (co-op §5.4). Leaving before picking keeps your stake.
## on_pick(pick: int) fires with the chosen shell; the caller owns the payout.
func open_wager(stake: int, on_pick: Callable) -> void:
	var vbox := _open("The Stranger's Wager", 680, 390, true)
	current = "wager"
	var shell := root
	var l := _lbl(vbox, "A hooded figure crouches at a low fire, turning three walnut shells over the dirt. \"One hides the pea, traveler. %d gold says your eye isn't quick enough to follow it.\"" % stake, 15, Color(0.9, 0.88, 0.82))
	l.custom_minimum_size = Vector2(560, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	var labels := ["   Left shell   ", "   Middle shell   ", "   Right shell   "]
	for s in 3:
		var pick := s
		var shell_button := _btn(row, labels[s], func() -> void:
			if root != shell:
				return
			close()
			on_pick.call(pick), Color(0.95, 0.85, 0.5))
		shell_button.custom_minimum_size = Vector2(150, 72)
		shell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl(vbox, "One winning shell out of three. Win: +%d gold before bonuses. Lose: -%d gold." % [stake, stake], 15)
	var leave := _btn(vbox, "Leave — keep your stake", func() -> void:
		if root == shell:
			close())
	leave.custom_minimum_size.y = 44
	_hint(vbox, "Gold changes hands only when you pick a shell. Leaving costs nothing.")


## Live sound, display, language and input settings.
var settings_return := "pause"
func open_settings(from := "pause") -> void:
	listening_action = ""  # leaving Keybinds must end capture before the next key
	settings_return = from
	# Touch controls get a scrollable body; desktop keeps its compact layout.
	var vbox := _open("Settings", 700, 660 if game.touch_mode else 490, true)
	current = "settings"
	var body := _settings_body(vbox)
	for spec in [["Music volume", "music"], ["Sound effects", "sfx"]]:
		var key: String = spec[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
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
	_lbl(body, "Slide to 0 to mute. Changes save instantly.", 12, Color(0.55, 0.58, 0.66))
	var fs_btn := _btn(body, "  Fullscreen: %s  " % ("ON" if game.settings["fullscreen"] else "OFF"),
		func() -> void:
			game.settings["fullscreen"] = not game.settings["fullscreen"]
			game.apply_display_settings()
			game.save_settings()
			open_settings(settings_return), Color(0.9, 0.9, 0.95))
	fs_btn.tooltip_text = "Borderless fullscreen on your current monitor."
	var lang_btn := _btn(body, "  Language: %s  " % String(game.settings.get("lang", "en")).to_upper(),
		func() -> void:
			var langs := Loc.languages()
			var i := langs.find(Loc.lang)
			Loc.lang = String(langs[(i + 1) % langs.size()])
			game.settings["lang"] = Loc.lang
			game.save_settings()
			open_settings(settings_return), Color(0.9, 0.9, 0.95))
	lang_btn.tooltip_text = "Cycle UI language (localization foundation — most screens are English for now)."
	# Desktop can preview the touch control scheme.
	if not OS.has_feature("mobile"):
		var tc_btn := _btn(body, "  Controls: %s  " % ("TOUCH" if game.settings.get("touch_controls", false) else "KEYBOARD"),
			func() -> void:
				game.set_touch_controls(not bool(game.settings.get("touch_controls", false)))
				open_settings(settings_return), Color(0.9, 0.9, 0.95))
		tc_btn.tooltip_text = "Touch: on-screen joystick + buttons + click-to-talk. Keyboard shortcuts always stay valid."
	# Touch-only layout options.
	if game.touch_mode:
		var jl_btn := _btn(body, "  Joystick: %s  " % ("FIXED" if game.settings.get("joystick_locked", false) else "FLOATING"),
			func() -> void:
				game.settings["joystick_locked"] = not bool(game.settings.get("joystick_locked", false))
				game.save_settings()
				open_settings(settings_return), Color(0.9, 0.9, 0.95))
		jl_btn.tooltip_text = "Floating: the stick springs to wherever your thumb lands. Fixed: it stays at one spot."
		var sens_row := HBoxContainer.new()
		sens_row.add_theme_constant_override("separation", 14)
		body.add_child(sens_row)
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
		_lbl(body, "1.0× = drag to the edge for full speed; higher = full speed on a shorter drag. Drag the joystick in the button editor to move it.", 12, Color(0.55, 0.58, 0.66))
		_btn(body, "  Customize buttons…  ", func() -> void: _open_layout_editor(), Color(0.8, 0.95, 0.85))
	# Keyboard binding is irrelevant in touch mode.
	if not game.touch_mode:
		_btn(body, "  ⌨  " + Loc.t("keybinds") + "…", func() -> void: open_keybinds(), Color(0.9, 0.9, 0.95))
	_btn(body, "Controller…", func() -> void: preload("res://scripts/ui/controller_settings.gd").open(self), Color(0.75, 0.92, 0.86))
	_btn(body, "Combat & comfort…", func() -> void:
		preload("res://scripts/ui/comfort.gd").open(self), Color(0.8, 0.9, 1.0))
	_btn(vbox, "  Back  ", func() -> void: _settings_back(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "ESC to go back")
	_settings_touch_targets(vbox)


## Settings-family layouts share scrolling content and a pinned footer.
## Keep this scoped to these screens; the shared shell X has its own sizing.
func _settings_body(box: VBoxContainer, always_scroll := false) -> VBoxContainer:
	if not game.touch_mode and not always_scroll:
		return box
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body


func _settings_touch_targets(node: Node) -> void:
	if not game.touch_mode:
		return
	if node is BaseButton or node is HSlider:
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, 44.0)
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 44.0)
	if node is HBoxContainer:
		var slider_row := false
		for child in node.get_children():
			if child is HSlider:
				slider_row = true
		if slider_row:
			for child in node.get_children():
				if child is Label:
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for child in node.get_children():
		_settings_touch_targets(child)


func _settings_back() -> void:
	if settings_return == "title":
		open_slots()  # back to the roster, not the splash
	else:
		open_pause()


## Enter the touch HUD layout editor.
func _open_layout_editor() -> void:
	close()
	if game._touch_hud != null:
		game._touch_hud.enter_edit_mode()


# ---------------------------------------------------------- chapter select ---

# ------------------------------------------------------------ endgame trials ---

## Confirm-and-enter a mode from a Wayfinder Sanctum portal (Crownfall): a
## backable prompt carrying the mode's record + rules, so a stray press never
## tears the world down. (The HUD trial icons that also led here were removed
## 2026-08-15 — owner ruling: hardcore modes do not belong on the HUD.)
func confirm_endgame(mode: String) -> void:
	# MP: the trials are SOLO. endgame.start() tears down THIS machine's world
	# only (net_session has no endgame fan), so in-session entry desyncs every
	# machine. This is the player-facing gate; game_flow.enter_endgame carries
	# the hard backstop.
	if game.net_online():
		open_confirm("Endgame trials are SOLO for now — a shared arena needs its own netcode.\n\nLeave the co-op session first; the trials will be waiting.",
			func() -> void: close(),
			func() -> void: close())
		return
	var cls: String = game.local_player.cls
	var pb := game.endgame_pb(mode, cls)
	var mname := "The Crucible" if mode == "crucible" else "The Waking Depths"
	var rules := "Ten bosses back to back, each with an elite affix — HP and MP carry over between them. Bonus spoils at 3 / 6 / 10 kills." if mode == "crucible" \
		else "An endless descent where DEPTH IS THE MONSTERS' LEVEL — the ladder starts at 40, or at your deepest cleared checkpoint. A boss guards every 5th depth, a checkpoint boss every 10th; past 100 the dark only deepens. Rewards pay when you fall or cash out."
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
	var dep_sub := "An endless descent. A prep camp, then combat only: depth IS the monsters' level, a boss guards every 5th, a checkpoint boss every 10th — clear one and future runs start there. Affixes and pressure mount by band; past 100 the dark wears a harder name. How deep can you go?"
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
	# --- battle stats (run window; solo shows your own line) ---
	var stats: Dictionary = game.party_stats_view()
	if not stats.is_empty():
		_lbl(vbox, " ", 6)
		_lbl(vbox, "— BATTLE STATS —   damage · healed · taken", 14, Color(0.7, 0.95, 0.85))
		var rows: Array = stats.values()
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("dmg", 0.0)) > float(b.get("dmg", 0.0)))
		for r in rows:
			var nm := String(r.get("name", ""))
			if nm == "":
				nm = String(Classes.CLASSES.get(String(r.get("cls", "")), {}).get("name", "Ally"))
			_lbl(vbox, "%s   —   %s dmg   ·   %s healed   ·   %s taken" %
				[nm, game.fmt_meter(float(r.get("dmg", 0.0))),
				game.fmt_meter(float(r.get("heal", 0.0))),
				game.fmt_meter(float(r.get("taken", 0.0)))],
				13, Color(0.85, 0.88, 0.94))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	# A run ends back in CROWNFALL (owner 2026-08-19: dying in the Crucible /
	# Depths must not read "exit to title") — the gates live there, the spoils
	# mail is there, the next run starts there. Endgame runs are solo (the
	# arena swap refuses sessions), so the capital return needs no net path.
	_btn(vbox, "  Return to Crownfall  (spoils are in your mailbox)  ",
		func() -> void:
			game.endgame_active = false
			close()
			game.enter_capital()
			game.state = game.ST_PLAYING
			game.play_started = true
			game.request_pause(false)
			game.hud.visible = true, Color(0.6, 1.0, 0.6))
	_hint(vbox, "Your rewards are banked. Press to return.")


## Start or replay a chapter from its beginning.
func open_chapter_select(replay := false) -> void:
	chapter_replay = replay
	var vbox := _open("Choose your chapter", 900, 540)
	current = "chapter_select"
	if replay:
		_lbl(vbox, "Return to any unlocked chapter with this character — farm, finish arcs, take other paths. Story progress there resets; your build, gear and Resonance travel with you.", 14, Color(0.75, 0.75, 0.75))
	else:
		_lbl(vbox, "One campaign, chapter by chapter: win a chapter and your hero journeys on to the next. Later chapters unlock once you've beaten the one before.", 14, Color(0.75, 0.75, 0.75))
	# The host's standing difficulty is snapshotted when the chapter starts.
	if replay and game.tier_unlocked(1) and (not game.net_online() or game.net_host()):
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 10)
		vbox.add_child(trow)
		var tlab := _lbl(trow, "Difficulty:", 15, Color(0.8, 0.8, 0.85))
		tlab.custom_minimum_size = Vector2(100, 0)
		for t in Balance.TIER_NAMES.size():
			var tier: int = t
			var open_t: bool = game.tier_unlocked(tier)
			var selected: bool = game.player.run_tier == tier
			var on_pick := func() -> void:
				game.player.run_tier = tier
				open_chapter_select(true)
			_btn(trow, "  %s%s%s  " % ["▶ " if selected else "", Balance.tier_name(tier),
					"" if open_t else " 🔒"], on_pick,
				Balance.tier_color(tier) if open_t else Color(0.5, 0.5, 0.55),
				open_t and not selected)
		var cur: int = game.player.run_tier
		var off := Balance.tier_level_offset(cur)
		var tdesc: String
		if off == 0:
			tdesc = "The world as authored — the campaign's own pacing and rewards."
		else:
			var shift: int = int(Balance.TIER_BAND_SHIFT[cur])
			var top_g := Balance.chapter_gear_ceiling(Balance.tier_chapter(Balance.TIER_FINALE_CH, cur))
			tdesc = "Every spawn +%d levels · loot bands +%d chapters (finale chests reach %s-grade) · no XP — the tier pays in gold rate, gem quality and gear." % [off, shift, top_g]
		if cur + 1 < Balance.TIER_NAMES.size() and not game.tier_unlocked(cur + 1):
			tdesc += "  Clear Chapter 7 at %s to unlock %s." % [Balance.tier_name(cur), Balance.tier_name(cur + 1)]
		var td := _lbl(vbox, tdesc, 13, Balance.tier_color(cur) if off > 0 else Color(0.65, 0.68, 0.78))
		td.custom_minimum_size = Vector2(800, 0)
	# A bottom fade marks overflow in the scrolling chapter list.
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
		# Each row shows the chapter's own authored teaser — locked ones too, so
		# they read as destinations, not duplicated disabled rows (visual-review
		# P0). The unlock rule is stated once in the intro above; the 🔒 on the
		# name marks the locked state by more than dimness alone.
		var sub_text: String = String(chapter.get("sub", ""))
		var sub_col := Color(0.65, 0.68, 0.78) if unlocked else Color(0.52, 0.54, 0.6)
		# Replay picker: print the XP ceiling on the door (REPLAY_XP.md §3) —
		# a cleared chapter pays XP until its reach level, then goes grey.
		if replay and unlocked and game.has_local_player():
			if game.get_flag("completed_" + pick_id, false):
				var reach := Balance.replay_xp_reach(Story.chapter_parity_level(pick_id))
				if game.player.run_tier > 0:
					sub_text += "   ·   no XP at this tier"
				elif game.player.level < reach:
					sub_text += "   ·   XP pays until Lv %d" % reach
				else:
					sub_text += "   ·   outgrown — no XP (Lv %d+)" % reach
					sub_col = Color(0.55, 0.57, 0.64)
			else:
				sub_text += "   ·   unfinished — full XP"
		var sub := _lbl(chlist, "        " + sub_text, 13, sub_col)
		sub.custom_minimum_size = Vector2(800, 0)
		idx += 1
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
	_hint(vbox, "Press the chapter's number, or click" + ("  ·  ESC to go back" if replay else ""),
		"Select an unlocked chapter" + ("  ·  close to return" if replay else ""))


func pick_chapter(id: String) -> void:
	if root:
		root.queue_free()
		root = null
	current = ""
	game.switch_chapter(id)  # no-op if it is already the built chapter
	open_class_select()


## New hero: Chapter 1, then the class pick. The one seam the roster's "New
## Character" button uses; the chapter selector is for replays/tests/dev.
func new_character() -> void:
	chapter_replay = false
	pick_chapter(String(Story.CHAPTER_LIST.keys()[0]))


# ------------------------------------------------------------ class select ---
# P7.G (2026-08-19; owner, after the reference class-select screens): "you
# choose a character icon and then you see the actual character … toggle
# between the splash art and the in-game model … and a showcase of the
# abilities, something players can interact with instead of a wall of text".
# So: a medallion RAIL of the six classes at the bottom; the pick fills the
# STAGE with the hero as they stand in the game (their live idle strip,
# breathing, big) with a Splash / Model toggle against the class painting; a
# right panel with name, role, passive, themes, difficulty pips; and an
# ABILITY SHOWCASE — four cards that PLAY the hero's own clip (swing / charge /
# cast / ult) on the stage when hovered or tapped, with the ability's text
# under them. Number keys preview, Enter (or the Choose plate) confirms;
# choose_class()/pick_class() keep their meaning for every caller and test.
var _cs_id := ""                       # the previewed class
var _cs_mode := "model"                # "model" | "splash"
var _cs_stage: Control = null
var _cs_model: AnimatedSprite2D = null
var _cs_model_glow: Sprite2D = null
var _cs_splash: TextureRect = null
var _cs_video: VideoStreamPlayer = null   # in-game ability demo (csdemo_<class>_<slot>.ogv)
var _cs_body_cache := {}   # "<class>|<clip>" -> (body_h, bottom_row) of the clip's first frame
var _cs_info: VBoxContainer = null
var _cs_detail: Label = null
var _cs_choose: Button = null
var _cs_rings: Dictionary = {}         # class id -> the medallion ring Panel (selected = gold)
var _cs_clips: Dictionary = {}         # the previewed class's hero clips
const CS_STAGE := Rect2(0, 0, 690, 430)
const CS_MODEL_H := 360.0              # px the hero's idle frame is shown at (capped at 3x)
const CS_MODEL_BODY_H := 300.0         # px the hero's BODY (first-frame alpha height) is shown at — every clip, same body size (owner flag 2026-08-19: the attack clip played smaller)
const CS_DIFFICULTY := {"warrior": 1, "paladin": 2, "archer": 2, "mage": 3, "warlock": 3, "assassin": 4}
const CS_ACTION_WORDS := ["Dash", "Leap", "Charge", "Step", "Blink", "Rush", "Lunge", "Bash", "Vault"]

func open_class_select() -> void:
	var vbox := _open("Choose your class", 1240, 716)
	current = "class_select"
	_lbl(vbox, "Pick a medallion to meet the class. The stage shows the hero as they stand in the game (or their painting); hover or tap an ability to watch it performed. Your class sets your four abilities and your three elemental THEMES.", 14, Color(0.75, 0.75, 0.75))
	var body := Control.new()
	body.custom_minimum_size = Vector2(1192, 580)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)
	# ---- the STAGE (left): glass panel, the model or the painting ----
	_cs_stage = Panel.new()
	_cs_stage.position = CS_STAGE.position
	_cs_stage.size = CS_STAGE.size
	_cs_stage.clip_contents = true
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.045, 0.045, 0.065, 0.92)
	ssb.border_color = Color(UITheme.BORDER, 0.9)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(10)
	_cs_stage.add_theme_stylebox_override("panel", ssb)
	body.add_child(_cs_stage)
	_cs_splash = TextureRect.new()
	# Explicit cover rect (set per class in _cs_preview → _cs_fit_splash): the
	# paintings are portrait, the stage is landscape, and KEEP_ASPECT_COVERED
	# crops from the CENTRE — which cut every hero's head off (owner flag
	# 2026-08-19). The rect is biased so the painting's face line sits in the
	# stage's upper third.
	_cs_splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cs_splash.stretch_mode = TextureRect.STRETCH_SCALE
	_cs_splash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cs_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cs_splash.visible = false
	_cs_stage.add_child(_cs_splash)
	_cs_model_glow = Sprite2D.new()          # a soft pool under the hero's feet
	_cs_model_glow.texture = Art.tex("glow")
	_cs_model_glow.modulate = Color(0.9, 0.8, 0.55, 0.28)
	_cs_model_glow.scale = Vector2(3.2, 1.1)
	_cs_model_glow.position = Vector2(CS_STAGE.size.x * 0.5, CS_STAGE.size.y - 48.0)
	_cs_stage.add_child(_cs_model_glow)
	_cs_model = AnimatedSprite2D.new()
	# LINEAR here, not the global NEAREST: the stage UPSCALES the ~180 px body
	# ~1.7x, and non-integer nearest gives uneven doubled pixels — the "class
	# sprites look lower quality" the owner saw beside the 2048 px paintings.
	# In-game rendering (a ~2x DOWNscale) keeps the global NEAREST crisp look.
	_cs_model.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_cs_model.position = Vector2(CS_STAGE.size.x * 0.5, CS_STAGE.size.y - 60.0)
	_cs_model.animation_finished.connect(_cs_clip_done)
	_cs_stage.add_child(_cs_model)
	# In-game ability DEMO (owner 2026-08-19: "an in game gif of the attack to
	# completion" — the bare body clips showed no FX): a pre-captured in-game
	# take (real projectiles / dashes / ults; shot_csdemo.gd → build_csdemo.py)
	# fills the stage while it plays, then the live model returns.
	_cs_video = VideoStreamPlayer.new()
	_cs_video.size = CS_STAGE.size - Vector2(2, 2)
	_cs_video.position = Vector2(1, 1)
	_cs_video.expand = true
	_cs_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cs_video.visible = false
	# hdr_2d runs the canvas in LINEAR light and the theora frame is uploaded
	# without an sRGB flag, so the video rendered near-BLACK (its sRGB values
	# got treated as linear). Lift it back with the inverse transfer curve.
	var vsh := Shader.new()
	vsh.code = """
shader_type canvas_item;
void fragment() {
	COLOR.rgb = pow(max(COLOR.rgb, vec3(0.0)), vec3(0.4545));
}
"""
	var vmat := ShaderMaterial.new()
	vmat.shader = vsh
	_cs_video.material = vmat
	_cs_video.finished.connect(func() -> void:
		if _cs_video != null and is_instance_valid(_cs_video):
			_cs_video.visible = false
			_cs_video.stop()
		_cs_set_mode(_cs_mode))
	_cs_stage.add_child(_cs_video)
	# Splash / Model toggle, top-right of the stage
	var tog := HBoxContainer.new()
	tog.position = Vector2(CS_STAGE.size.x - 190.0, 10.0)
	tog.add_theme_constant_override("separation", 6)
	_cs_stage.add_child(tog)
	_btn(tog, " Model ", func() -> void: _cs_set_mode("model"), Color(0.95, 0.85, 0.5))
	_btn(tog, " Splash ", func() -> void: _cs_set_mode("splash"), Color(0.8, 0.85, 0.95))
	# ---- the INFO panel (right) ----
	var info_clip := Control.new()          # the panel never grows past the stage's height
	info_clip.position = Vector2(712, 0)
	info_clip.size = Vector2(480, CS_STAGE.size.y)
	info_clip.clip_contents = true
	body.add_child(info_clip)
	_cs_info = VBoxContainer.new()
	_cs_info.position = Vector2.ZERO
	_cs_info.size = Vector2(480, CS_STAGE.size.y)
	_cs_info.add_theme_constant_override("separation", 6)
	info_clip.add_child(_cs_info)
	# ---- the RAIL (bottom): six medallions + the Choose plate ----
	var rail := HBoxContainer.new()
	rail.position = Vector2(0, 452)
	rail.add_theme_constant_override("separation", 18)
	body.add_child(rail)
	_cs_rings.clear()
	var idx := 1
	for id in Classes.CLASSES:
		rail.add_child(_cs_medallion(String(id), idx))
		idx += 1
	_cs_choose = _btn(body, "  Choose  ", func() -> void:
		if _cs_id != "":
			choose_class(_cs_id), Color(0.6, 1.0, 0.6))
	_cs_choose.position = Vector2(960, 460)     # right of the rail, under the info panel
	_cs_choose.custom_minimum_size = Vector2(224, 54)
	_cs_choose.add_theme_font_size_override("font_size", 20)
	_hint(vbox, "1–6 preview a class  ·  hover/tap an ability to watch it  ·  Enter or Choose to commit")
	_cs_preview(_cs_id if Classes.CLASSES.has(_cs_id) else String(Classes.CLASSES.keys()[0]))


## A class painting's FACE crop, normalized (origin, size): the HUD portrait's
## measured per-splash eye-line (Hud.AVATAR_FOCUS) so the roster, the class rail
## and the HUD all centre the same face; `scale` = crop side as a share of the
## painting's short edge (the HUD uses 0.28; menus a touch wider).
static func _splash_face_crop(key: String, tex: Texture2D, scale := 0.34) -> Rect2:
	var ssz := Vector2(tex.get_width(), tex.get_height())
	var side := minf(ssz.x, ssz.y) * scale
	var crop := Vector2(side / ssz.x, side / ssz.y)
	var focus: Vector2 = Hud.AVATAR_FOCUS.get(key, Hud.AVATAR_FACE_DEFAULT)
	var origin := focus - crop * Vector2(0.5, 0.32)
	origin.x = clampf(origin.x, 0.0, 1.0 - crop.x)
	origin.y = clampf(origin.y, 0.0, 1.0 - crop.y)
	return Rect2(origin, crop)


## One rail medallion: the class painting's face in a ring (gold when selected),
## the class name + its number key under it. Click = preview.
func _cs_medallion(id: String, num: int) -> Control:
	var c: Dictionary = Classes.CLASSES[id]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var ring := Panel.new()
	ring.custom_minimum_size = Vector2(72, 72)
	# A CIRCLE, not a stadium: the VBox used to stretch the ring to the label's
	# 120 px width, so the 36 px corner radius drew a pill with the 60 px face
	# sitting in its left half (owner flag 2026-08-19). Shrink-centre keeps it
	# 72×72 and the face fills it flush inside the border.
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.03, 0.03, 0.045, 0.98)
	rs.border_color = Color(UITheme.BRONZE, 0.9)
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(36)
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ring.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cs_preview(id))
	ring.mouse_entered.connect(func() -> void: _cs_ring_style(id, _cs_id == id, true))
	ring.mouse_exited.connect(func() -> void: _cs_ring_style(id, _cs_id == id, false))
	col.add_child(ring)
	var face := TextureRect.new()
	face.position = Vector2(4, 4)
	face.size = Vector2(64, 64)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 crop_uv = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float mask = 1.0 - smoothstep(0.475, 0.5, length(d));
	vec4 c = texture(TEXTURE, crop_uv.xy + UV * crop_uv.zw);
	COLOR = vec4(c.rgb, c.a * mask);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	face.material = mat
	var splash_key := "class_splash_%s" % id
	if Art.has_sprite(splash_key):
		var tex: Texture2D = Art.tex(splash_key)
		var cr := _splash_face_crop(splash_key, tex)
		mat.set_shader_parameter("crop_uv", Vector4(cr.position.x, cr.position.y, cr.size.x, cr.size.y))
		face.texture = tex
	else:
		face.texture = Art.tex(c["sprite"])
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.add_child(face)
	_cs_rings[id] = ring
	var nm := _lbl(col, "%s  (%d)" % [c["name"], num], 12, Color(0.85, 0.85, 0.9))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(120, 0)
	return col


func _cs_ring_style(id: String, selected: bool, hover: bool) -> void:
	var ring: Panel = _cs_rings.get(id)
	if ring == null or not is_instance_valid(ring):
		return
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.03, 0.03, 0.045, 0.98)
	rs.border_color = Color(0.98, 0.86, 0.5, 1.0) if selected else (Color(0.8, 0.74, 0.55, 0.95) if hover else Color(UITheme.BRONZE, 0.9))
	rs.set_border_width_all(4 if selected else 3)
	rs.set_corner_radius_all(36)
	ring.add_theme_stylebox_override("panel", rs)
	ring.scale = Vector2(1.08, 1.08) if selected else Vector2.ONE
	ring.pivot_offset = Vector2(36, 36)


## Put a class on the stage: the model (live idle strip) + the info panel.
func _cs_preview(id: String) -> void:
	if not Classes.CLASSES.has(id) or current != "class_select":
		return
	var prev := _cs_id
	_cs_id = id
	if prev != "" and prev != id:
		_cs_ring_style(prev, false, false)
	_cs_ring_style(id, true, false)
	var c: Dictionary = Classes.CLASSES[id]
	game.sfx("ui_click")
	# the model
	_cs_clips = Art.hero_clips(String(c["sprite"]))
	_cs_play_clip("idle", true)
	# the painting
	var splash_key := "class_splash_%s" % id
	_cs_splash.texture = Art.tex(splash_key) if Art.has_sprite(splash_key) else null
	if _cs_splash.texture != null:
		_cs_fit_splash(splash_key, _cs_splash.texture)
	_cs_set_mode(_cs_mode)
	# the info panel
	for ch in _cs_info.get_children():
		ch.queue_free()
	var nm := _lbl(_cs_info, String(c["name"]).to_upper(), 30, Color(0.96, 0.86, 0.52))
	UITheme.title(nm, 30)
	_lbl(_cs_info, String(c["desc"]), 14, Color(0.85, 0.85, 0.88))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 14)
	_cs_info.add_child(meta)
	var kind := "Ranged" if String(c.get("dmg_type", "phys")) == "magic" or id == "archer" else "Melee"
	var tl := _lbl(meta, "Type  %s" % kind, 13, Color(0.72, 0.78, 0.9))
	tl.custom_minimum_size = Vector2(120, 0)      # HBox label-collapse trap
	var pips := ""
	var diff := int(CS_DIFFICULTY.get(id, 2))
	for k in 4:
		pips += "◆" if k < diff else "◇"
	var dl := _lbl(meta, "Difficulty  %s" % pips, 13, Color(0.95, 0.82, 0.45))
	dl.custom_minimum_size = Vector2(170, 0)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	_cs_info.add_child(chips)
	for theme in Classes.THEMES[id]:
		_chip_lbl(chips, String(theme["name"]))
	# the ABILITY SHOWCASE sits at a fixed height; the passive (long) comes last
	# and is trimmed so the cards never get pushed off the stage line.
	UITheme.header(_lbl(_cs_info, "ABILITIES  —  hover or tap to watch", 13, Color(0.95, 0.85, 0.5)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_cs_info.add_child(row)
	for slot in ["a1", "a2", "a3", "ult"]:
		row.add_child(_cs_ability_card(id, String(slot)))
	# FULL text, wrapped (owner flag 2026-08-19: it was trimmed with an ellipsis
	# AND the tooltip repeated the same words — redundant, with whitespace to
	# spare). _lbl autowraps; the panel has the height. (The old max_lines_visible
	# 1 px collapse was that property, not autowrap.)
	_cs_detail = _lbl(_cs_info, "", 12, Color(0.82, 0.86, 0.94))
	_cs_detail.custom_minimum_size = Vector2(470, 0)
	if c.has("passive"):
		var pl := _lbl(_cs_info, "★ " + String(c["passive"]["text"]), 12, Color(0.5, 0.95, 0.8))
		pl.custom_minimum_size = Vector2(470, 0)
	_cs_show_ability(id, "a1")
	if _cs_choose != null:
		_cs_choose.text = "  Choose  %s  " % String(c["name"])


## One ability card: icon plate + name + slot tag. Hover/tap plays the clip and
## writes the ability's text under the row.
func _cs_ability_card(id: String, slot: String) -> Control:
	var c: Dictionary = Classes.CLASSES[id]
	var ab: Dictionary = c["abilities"][slot]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.SURFACE, 0.95)
	sb.border_color = Color(UITheme.BORDER, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(112, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var icon := TextureRect.new()
	icon.texture = Art.ability_icon(id, slot)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var nm := _lbl(col, String(ab["name"]), 11, Color(0.92, 0.92, 0.98))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(100, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tag := _lbl(col, "ULT" if slot == "ult" else slot.to_upper(), 10, Color(0.62, 0.65, 0.73))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_mouse_recursive(col)
	card.mouse_entered.connect(func() -> void:
		sb.border_color = Color(0.95, 0.85, 0.5, 0.95)
		card.add_theme_stylebox_override("panel", sb)
		_cs_show_ability(id, slot))
	card.mouse_exited.connect(func() -> void:
		sb.border_color = Color(UITheme.BORDER, 0.9)
		card.add_theme_stylebox_override("panel", sb))
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cs_show_ability(id, slot))
	return card


## Play the hero's clip for an ability on the stage and write its text.
func _cs_show_ability(id: String, slot: String) -> void:
	if id != _cs_id or current != "class_select":
		return
	var ab: Dictionary = Classes.CLASSES[id]["abilities"][slot]
	if _cs_detail != null and is_instance_valid(_cs_detail):
		var text := "%s — %s" % [String(ab["name"]), String(ab["desc"])]
		var scaling: String = Classes.ability_scaling(id, slot)
		if scaling != "":
			text += "\n" + scaling
		_cs_detail.text = text
	# In-game demo video first (the full cast with its FX); body clip fallback.
	if _cs_play_demo(id, slot):
		return
	var clip := "ult" if slot == "ult" else ("attack" if slot == "a1" else "cast")
	for w in CS_ACTION_WORDS:
		if String(ab["name"]).contains(w):
			clip = "dash"
	if not _cs_clips.has(clip):
		clip = "attack" if _cs_clips.has("attack") else "idle"
	_cs_play_clip(clip, clip == "idle")


## Play the pre-captured in-game take for this class+slot on the stage, if it
## ships (assets/videos/csdemo_<class>_<slot>.ogv). Returns true when playing.
func _cs_play_demo(id: String, slot: String) -> bool:
	if _cs_video == null or not is_instance_valid(_cs_video) or _cs_mode != "model":
		return false
	# Headless (autotest opens this screen): no renderer, and the theora load
	# can HANG the process — the body-clip path is the safe one there.
	if DisplayServer.get_name() == "headless":
		return false
	var path := "res://assets/videos/csdemo_%s_%s.ogv" % [id, slot]
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return false
	var stream: VideoStream = load(path)
	if stream == null:
		return false
	_cs_video.stream = stream
	_cs_video.visible = true
	if _cs_model != null and is_instance_valid(_cs_model):
		_cs_model.visible = false
	if _cs_model_glow != null and is_instance_valid(_cs_model_glow):
		_cs_model_glow.visible = false
	if _cs_splash != null and is_instance_valid(_cs_splash):
		_cs_splash.visible = false
	_cs_video.play()
	return true


## Put a clip on the stage model: one-shot clips return to the idle when done.
func _cs_play_clip(clip: String, loop: bool) -> void:
	if _cs_model == null or not is_instance_valid(_cs_model):
		return
	if not _cs_clips.has(clip):
		_cs_model.visible = false
		return
	var info: Dictionary = _cs_clips[clip]
	var tex: Texture2D = info["tex"]
	var frames := int(info["frames"])
	var fsize: Vector2 = Vector2(info.get("frame_size", Vector2i(tex.get_height(), tex.get_height())))
	var sf := SpriteFrames.new()
	sf.add_animation("clip")
	sf.set_animation_loop("clip", loop)
	sf.set_animation_speed("clip", float(info.get("fps", 6.0)))
	for f in frames:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f * fsize.x, 0, fsize.x, fsize.y)
		sf.add_frame("clip", at)
	_cs_model.sprite_frames = sf
	# Scale by the BODY, not the cell (the same rule the game uses,
	# player_core._measure_hero_frame): an attack / ult strip can ship a taller
	# square cell to hold a sword arc, so a cell-fit scale shrank the hero mid
	# swing. Measure the first frame's alpha box once per clip: the body height
	# sets the scale, its bottom row sits on the stage's floor line.
	var body_h: float = fsize.y
	var bot: float = fsize.y
	var ck := "%s|%s" % [String(_cs_id), clip]
	if _cs_body_cache.has(ck):
		body_h = _cs_body_cache[ck].x
		bot = _cs_body_cache[ck].y
	else:
		var rect := Rect2i(0, 0, int(fsize.x), int(fsize.y))
		var raw: Dictionary = Art.hero_frame_bounds(info, rect)
		var used := Rect2i()
		if not raw.is_empty():
			used = raw["used"]
		else:
			var img: Image = tex.get_image()
			if img != null:
				var first := img.get_region(rect)
				used = first.get_used_rect()
		if used.size.y > 0:
			body_h = float(used.size.y)
			bot = float(used.end.y)
		_cs_body_cache[ck] = Vector2(body_h, bot)
	var s := minf(3.0, CS_MODEL_BODY_H / maxf(1.0, body_h))
	_cs_model.scale = Vector2(s, s)
	var floor_y: float = CS_STAGE.size.y - 60.0
	_cs_model.position = Vector2(CS_STAGE.size.x * 0.5, floor_y - (bot - fsize.y * 0.5) * s)
	_cs_model.visible = _cs_mode == "model"
	_cs_model.play("clip")


## Aspect-COVER the class painting over the stage with the crop biased so the
## painting's face line (Hud.AVATAR_FOCUS, the measured eye-line) lands around
## 28 % down the stage — the head stays in frame on every class, and a short
## painting still fills the panel.
func _cs_fit_splash(key: String, tex: Texture2D) -> void:
	var ts := Vector2(tex.get_width(), tex.get_height())
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var stage := CS_STAGE.size
	var k: float = maxf(stage.x / ts.x, stage.y / ts.y)
	var draw := ts * k
	var focus: Vector2 = Hud.AVATAR_FOCUS.get(key, Hud.AVATAR_FACE_DEFAULT)
	var overflow := draw - stage
	var off := Vector2(-overflow.x * 0.5, 0.0)
	# put the face line at 28 % of the stage height; clamp inside the painting
	off.y = -clampf(focus.y * draw.y - stage.y * 0.28, 0.0, maxf(0.0, overflow.y))
	_cs_splash.position = off
	_cs_splash.size = draw


func _cs_clip_done() -> void:
	if current == "class_select" and _cs_model != null and is_instance_valid(_cs_model) \
			and _cs_model.sprite_frames != null and not _cs_model.sprite_frames.get_animation_loop("clip"):
		_cs_play_clip("idle", true)


func _cs_set_mode(mode: String) -> void:
	_cs_mode = mode
	if _cs_splash == null or not is_instance_valid(_cs_splash):
		return
	# A mode change interrupts a playing ability demo (Splash wins immediately).
	if _cs_video != null and is_instance_valid(_cs_video) and _cs_video.visible:
		_cs_video.stop()
		_cs_video.visible = false
	var has_splash := _cs_splash.texture != null
	_cs_splash.visible = mode == "splash" and has_splash
	if _cs_model != null and is_instance_valid(_cs_model):
		_cs_model.visible = not _cs_splash.visible and _cs_model.sprite_frames != null
	if _cs_model_glow != null and is_instance_valid(_cs_model_glow):
		_cs_model_glow.visible = _cs_model.visible


## The previous card layout (kept for reference / a dev fallback; not wired).
func _open_class_cards() -> void:
	# The tallest class card determines the full-height selector.
	var vbox := _open("Choose your class", 1240, 716)
	current = "class_select"
	_lbl(vbox, "This choice sets your four abilities and your three elemental THEMES — playstyles that reshape those abilities as you level. Select any class to choose it.", 15, Color(0.75, 0.75, 0.75))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var count := Classes.CLASSES.size()
	var card_w := (1240.0 - 48.0 - 10.0 * (count - 1)) / count
	var dense := count > 4  # 6-class roster: tighter type, smaller icon

	var idx := 1
	for id in Classes.CLASSES:
		var c: Dictionary = Classes.CLASSES[id]
		# The full class card is one click target.
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

		# (2026-08-18 design pass, owner: "a polished modern game") — each card
		# leads with the class PAINTING (the codex splash, cropped to a header
		# band), the name in the header face, one line of role, the passive,
		# the three themes as chips and the four ability NAMES. The scaling and
		# rider maths that used to make the card a wall of text live in the
		# card's tooltip (hover) — nothing is lost, the page just breathes.
		var splash_tex: Texture2D = Art.tex("class_splash_%s" % id) \
			if Art.has_sprite("class_splash_%s" % id) else null
		if splash_tex != null:
			var art := TextureRect.new()
			art.texture = splash_tex
			art.custom_minimum_size = Vector2(0, 168 if dense else 210)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.clip_contents = true
			art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(art)
		else:
			var icon := TextureRect.new()
			icon.texture = Art.tex(c["sprite"])
			icon.custom_minimum_size = Vector2(96, 96)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			col.add_child(icon)
		# Number keys pick cards left-to-right.
		var nm := _lbl(col, "%s  (%d)" % [c["name"], idx], 19 if dense else 22, Color(0.95, 0.85, 0.5))
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		UITheme.title(nm, 19 if dense else 22)
		_lbl(col, c["desc"], 12 if dense else 13, Color(0.82, 0.82, 0.82))
		if c.has("passive"):
			_lbl(col, "★ " + c["passive"]["text"], 11 if dense else 12, Color(0.5, 0.95, 0.8))
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		col.add_child(chips)
		for theme in Classes.THEMES[id]:
			_chip_lbl(chips, String(theme["name"]))
		var tip := ""
		for slot in ["a1", "a2", "a3", "ult"]:
			var ab: Dictionary = c["abilities"][slot]
			var tag: String = "ULT" if slot == "ult" else slot.to_upper()
			_lbl(col, "%s  %s" % [tag, ab["name"]], 12 if dense else 13, Color(0.78, 0.82, 0.9))
			var scaling: String = Classes.ability_scaling(id, slot)
			var riders: String = Classes.ability_riders(id, slot)
			tip += "%s %s — %s" % [tag, ab["name"], ab["desc"]]
			if scaling != "":
				tip += "\n    " + scaling
			if riders != "":
				tip += "\n    " + riders
			tip += "\n"
		card.tooltip_text = tip.strip_edges()
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		# Child controls pass clicks to the card.
		_ignore_mouse_recursive(col)
		idx += 1


## A small rounded chip label (theme tags on the class cards).
func _chip_lbl(parent: Node, text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.SURFACE_RAISED, 0.9)
	sb.border_color = Color(UITheme.BORDER, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	pc.add_child(l)
	return pc


## Make class-card content transparent to pointer input.
func _ignore_mouse_recursive(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_recursive(ch)


## Chrome for one class-picker card.
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


## Funnel card and keyboard selection through the splash reveal.
func choose_class(id: String) -> void:
	if current != "class_select":
		return
	_show_class_splash(id)


## Reveal the chosen class, then continue to name entry.
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
	# Painterly splashes use linear filtering when scaled.
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

## Name the hero before entering the world.
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


## A roster/lobby hero's SHOWN name: its own name, or the account name when it
## was never named (legacy saves) — the same fallback co-op labels use, so a
## hero reads identically in the roster, the lobby and the battle meter.
func _hero_display_name(raw: String) -> String:
	var nm := raw.strip_edges()
	return nm if nm != "" else _default_char_name()


## Rename an existing hero from the roster: a one-field entry pre-filled with
## the current name, written straight back to the save (no load). Blank clears
## the name, falling the hero back to the account name. Returns to the roster.
func open_rename(slot: int, cur_name: String) -> void:
	var vbox := _open("Rename your hero", 640, 300)
	current = "rename"
	_lbl(vbox, "A new name for this hero — it's how friends find you in co-op. Leave it blank to fall back to your account name.",
		14, Color(0.75, 0.75, 0.75))
	var field := LineEdit.new()
	field.max_length = Balance.CHAR_NAME_MAX
	field.text = cur_name
	field.placeholder_text = _default_char_name()
	field.custom_minimum_size = Vector2(0, 40)
	field.add_theme_font_size_override("font_size", 18)
	vbox.add_child(field)
	field.grab_focus()
	field.select_all()
	var confirm := func() -> void:
		var nm := _sanitize_char_name(field.text)
		SaveGame.rename_character(slot, nm)
		# Keep the LIVE hero in step if the renamed slot is the one loaded.
		if is_instance_valid(game.player) and int(game.save_slot) == slot:
			game.player.char_name = nm
		game.sfx("equip")
		open_slots()
	field.text_submitted.connect(func(_t: String) -> void: confirm.call())
	_btn(vbox, "  Save name  ", func() -> void: confirm.call(), Color(0.6, 1.0, 0.6))
	_btn(vbox, "  Cancel  ", func() -> void: open_slots(), Color(0.8, 0.85, 0.9))
	_hint(vbox, "Enter to save · ESC to cancel")


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

## Per-room potion rotation editor.
## The potion loadout is the inventory's Potions tab (2026-08-15: it was a
## separate text screen — slot rows and "+ Slot / − Unslot" rows; now the room
## slots are TILES you fill by clicking a bottle, and the plan reads at a glance).
func open_potion_loadout() -> void:
	open_inventory("potions")


var _potion_msg := ""  # last refusal/notice, shown INSIDE the tab (never as world text behind the menu)


## The Potions tab body: room slots as tiles · your bottles as tiles · notes.
func _build_potion_tab(vbox: VBoxContainer, p: Player) -> void:
	var cyc: String = "the ⟳ button" if game.touch_mode \
		else "[%s]" % OS.get_keycode_string(game.binds.get("potion_next", KEY_R))
	var drink: String = "the potion button" if game.touch_mode \
		else "[%s]" % OS.get_keycode_string(game.binds.get("potion", KEY_Q))
	var cap: int = p.potion_slot_cap()
	var plan: Array = p.potion_loadout()
	var slot_h := HBoxContainer.new()
	slot_h.add_theme_constant_override("separation", 12)
	vbox.add_child(slot_h)
	var st := _lbl(slot_h, "ROOM SLOTS", 16, Color(0.95, 0.85, 0.5))
	UITheme.header(st)
	st.custom_minimum_size = Vector2(120, 0)
	var sub := _lbl(slot_h, "%d drink%s per room, refilled at every door. %s drinks the active bottle · %s cycles which is active. A slot you don't assign pours your cheapest Health Potion — or leave it empty." % [
		cap, "" if cap == 1 else "s", drink, cyc], 12, UITheme.TEXT_MUTED)
	sub.custom_minimum_size = Vector2(700, 0)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# --- the slot tiles. Three states, one click cycles them:
	#     bottle → default · default → empty · empty → default.
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	vbox.add_child(slots)
	var health_carried: int = p.potion_count()
	for i in cap:
		var pid: String = String(plan[i]) if i < plan.size() else "health"
		var empty: bool = pid == Player.LOADOUT_EMPTY
		var assigned: bool = not empty and pid != "health"
		var active: bool = pid == p.active_potion and p.potion_swap_useful()
		var tile := VBoxContainer.new()
		tile.custom_minimum_size = Vector2(120, 0)
		tile.add_theme_constant_override("separation", 3)
		slots.add_child(tile)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 72)
		b.focus_mode = Control.FOCUS_NONE
		var icon: Texture2D = null if empty or (pid == "health" and health_carried <= 0) else _potion_icon(pid)
		if icon != null:
			b.icon = icon
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 48)
		else:
			b.text = "—"
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_color_override("font_color", Color(0.4, 0.42, 0.5))
		var col: Color = Color(0.6, 0.85, 1.0) if assigned else (Color(0.5, 0.53, 0.62) if empty or health_carried <= 0 else Color(0.78, 0.42, 0.42))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.12, 0.92) if assigned else Color(0.06, 0.05, 0.06, 0.9)
		sb.border_color = Color(col, 0.95 if assigned else 0.5)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		if active:
			sb.border_color = Color(1.0, 0.85, 0.4)
			sb.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", sb)
		var sbh: StyleBoxFlat = sb.duplicate()
		sbh.bg_color = Color(0.17, 0.17, 0.23, 0.95)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var slot_i := i
		var title := ""
		if assigned:
			title = String(p.potion_display_name(pid))
			b.tooltip_text = "Slot %d — %s\nSelect to send this slot back to the default (Health)." % [i + 1, title]
			b.pressed.connect(func() -> void:
				game.local_player.loadout_set_empty(slot_i, false)
				open_inventory("potions"))
		elif empty:
			title = "Empty"
			b.tooltip_text = "Slot %d — left empty on purpose: pours nothing.\nSelect to restore the default (Health)." % (i + 1)
			b.pressed.connect(func() -> void:
				game.local_player.loadout_set_empty(slot_i, false)
				open_inventory("potions"))
		else:
			title = "Health" if health_carried > 0 else "Health (none carried)"
			b.tooltip_text = ("Slot %d — default: pours your cheapest Health Potion (%d carried).\nSelect to leave this slot EMPTY instead; select a bottle below to assign it." % [i + 1, health_carried]) if health_carried > 0 \
				else "Slot %d — default would pour a Health Potion, but you carry none: it pours nothing.\nSelect to mark it empty on purpose; select a bottle below to assign it." % (i + 1)
			b.pressed.connect(func() -> void:
				game.local_player.loadout_set_empty(slot_i, true)
				open_inventory("potions"))
		tile.add_child(b)
		var nm := _lbl(tile, ("▶ " if active else "") + title, 12, col)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(120, 0)
		var sl := _lbl(tile, "slot %d" % (i + 1), 10, Color(0.5, 0.53, 0.62))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.custom_minimum_size = Vector2(120, 0)
	if _potion_msg != "":
		var ml := _lbl(vbox, _potion_msg, 12, Color(1.0, 0.85, 0.5))
		ml.custom_minimum_size = Vector2(700, 0)
		_potion_msg = ""

	UITheme.rule(vbox)
	# --- your bottles: click one to fill the next free slot ---
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	vbox.add_child(bh)
	var bt := _lbl(bh, "YOUR BOTTLES", 16, Color(0.95, 0.85, 0.5))
	UITheme.header(bt)
	bt.custom_minimum_size = Vector2(130, 0)
	var free_slots: int = p.loadout_free_slots()
	var bsub := _lbl(bh, ("Select a bottle to put it in the next free slot (%d free). Health Potions in your bag: %d." % [free_slots, p.potion_count()]) if free_slots > 0
		else "Every slot holds a bottle — select a slot above to free it. Health Potions in your bag: %d." % p.potion_count(), 12, UITheme.TEXT_MUTED)
	bsub.custom_minimum_size = Vector2(640, 0)
	bsub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var owned_ids: Array = p.owned_potion_ids()
	if owned_ids.is_empty():
		var warn := _lbl(vbox, "No rotation bottles in your bag yet. Merchants sell Mana Potions, Elixirs of Might and Warding, Tonics and Draughts of Renewal (the Sable Court fence and road smugglers sell laced ones cheaper); assign the exact bottle here once you carry it.", 13, Color(0.7, 0.72, 0.8))
		warn.custom_minimum_size = Vector2(700, 0)
	else:
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		vbox.add_child(grid)
		for rid in owned_ids:
			var rid_c := String(rid)
			var owned := p.consumable_count(rid_c)
			if owned <= 0:
				continue
			var in_rot: int = p.potion_rotation.count(rid_c)
			var tile := VBoxContainer.new()
			tile.custom_minimum_size = Vector2(112, 0)
			tile.add_theme_constant_override("separation", 3)
			grid.add_child(tile)
			var b := Button.new()
			b.custom_minimum_size = Vector2(112, 64)
			b.focus_mode = Control.FOCUS_NONE
			var icon: Texture2D = _potion_icon(rid_c)
			if icon != null:
				b.icon = icon
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.add_theme_constant_override("icon_max_width", 40)
			var col := Color(0.6, 1.0, 0.8) if in_rot > 0 else Color(0.82, 0.9, 1.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.09, 0.09, 0.12, 0.92)
			sb.border_color = Color(col, 0.9)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			b.add_theme_stylebox_override("normal", sb)
			var sbh: StyleBoxFlat = sb.duplicate()
			sbh.bg_color = Color(0.17, 0.17, 0.23, 0.95)
			b.add_theme_stylebox_override("hover", sbh)
			b.add_theme_stylebox_override("pressed", sbh)
			b.tooltip_text = "%s\nown x%d%s\nSelect: assign to the next free slot" % [
				p.potion_display_name(rid_c), owned, ("  ·  in %d slot%s" % [in_rot, "" if in_rot == 1 else "s"]) if in_rot > 0 else ""]
			b.pressed.connect(func() -> void:
				if game.local_player.loadout_free_slots() <= 0:
					_potion_msg = "Every slot holds a bottle — select a slot above to free it first."
				else:
					game.local_player.loadout_add(rid_c)
				open_inventory("potions"))
			# Stack count badge.
			var badge := Label.new()
			badge.text = "x%d" % owned
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1, 1, 1))
			badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			badge.add_theme_constant_override("outline_size", 4)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.offset_left = -50
			badge.offset_top = -18
			badge.offset_right = -4
			badge.offset_bottom = -2
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(badge)
			tile.add_child(b)
			var nm := _lbl(tile, String(p.potion_display_name(rid_c)), 11, col)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.custom_minimum_size = Vector2(112, 0)
			if in_rot > 0:
				var rl := _lbl(tile, "in %d slot%s" % [in_rot, "" if in_rot == 1 else "s"], 10, Color(0.6, 1.0, 0.8))
				rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rl.custom_minimum_size = Vector2(112, 0)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vbox.add_child(foot)
	if not p.potion_rotation.is_empty():
		_btn(foot, "  ⟲  Reset every slot to the default (Health)  ", func() -> void:
			game.local_player.potion_rotation.clear()
			game.local_player.active_potion = "health"
			open_inventory("potions"), Color(0.6, 1.0, 0.8))
	var note := _lbl(vbox, "Slots hold TYPES: two slots of the same elixir mean two drinks of it per room. Assigned slots need a bottle in the bag when you drink — %s skips a slot you've run out of." % cyc, 12, Color(0.55, 0.57, 0.63))
	note.custom_minimum_size = Vector2(700, 0)


## The bottle art for a loadout id ("health" = the cheapest health potion you
## carry, else the generic potion icon).
func _potion_icon(pid: String) -> Texture2D:
	var p: Player = game.local_player
	if pid == "health":
		var nh: Dictionary = p.next_health_potion()
		if not nh.is_empty():
			return Art.consumable_icon(nh)
		return Art.consumable_icon(Items.make_potion("health", "instant", "E", "accord"))
	for c in p.consumables:
		if String(c.get("id", "")) == pid:
			return Art.consumable_icon(c)
	var t := Items.potion_by_id(pid)
	return Art.consumable_icon(t) if not t.is_empty() else null


# --------------------------------------------------------------- inventory ---

func open_inventory(tab := "gear", cat := "all") -> void:
	inv_cat = cat  # remembered so an item-panel underlay rebuild keeps the filter
	var vbox := _open("Inventory — %d gold" % game.local_player.gold, 1120, 640, true)
	current = "inventory"

	# Gear management, character sheet, and potion planning.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_tab(tabs, "Gear", func() -> void: open_inventory("gear"), tab == "gear")
	_tab(tabs, "Stats", func() -> void: open_inventory("stats"), tab == "stats")
	_tab(tabs, "Potions", func() -> void: open_inventory("potions"), tab == "potions",
		Color(0.42, 0.84, 0.70))
	if tab == "stats":
		_build_stats_tab(vbox, game.local_player)
		return
	if tab == "potions":
		_build_potion_tab(vbox, game.local_player)
		_hint(vbox, "ESC, ✕, click outside, or %s to close" % menu_key("inventory"))
		return
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Both equipment and bag columns scroll independently.
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
	var eq_head := HBoxContainer.new()
	eq_head.add_theme_constant_override("separation", 10)
	left.add_child(eq_head)
	var eq_title := _lbl(eq_head, "EQUIPPED", 16, Color(0.95, 0.85, 0.5))
	UITheme.header(eq_title)
	eq_title.custom_minimum_size = Vector2(120, 0)
	var eq_hint := _lbl(eq_head, "select a piece for its card · sockets on the right", 12, UITheme.TEXT_MUTED)
	eq_hint.custom_minimum_size = Vector2(300, 0)
	eq_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# One card per slot, in the paper-doll order (2026-08-15 polish): icon
	# well · name + a quiet stat line · the sockets on the same row. Empty
	# slots keep their place as dimmed cards so the seven never shuffle.
	for slot in Items.SLOTS:
		_equipped_row(left, String(slot), cat)
	_lbl(left, "Full character sheet in the Stats tab.", 12, Color(0.55, 0.55, 0.6))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	# ------------------------------------------------------------- bag ---
	var p: Player = game.local_player
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	right.add_child(head)
	if inventory_notice != "":
		_lbl(right, inventory_notice, 13, Color(0.64, 0.95, 0.75))
		inventory_notice = ""
	var best_grade: String = String(p.bags[0].get("grade", "F")) if not p.bags.is_empty() else "F"
	for bb in p.bags:
		var bg: String = String(bb.get("grade", "F"))
		if Items.GRADES.find(bg) > Items.GRADES.find(best_grade):
			best_grade = bg
	var bh := _lbl(head, "BAG", 16, Items.GRADE_COLOR[best_grade])
	UITheme.header(bh)
	bh.custom_minimum_size = Vector2(44, 0)
	# Capacity as a bar + fraction — the number that decides whether loot
	# lands or mails (2026-08-15 polish); the bags themselves are the chips.
	var used_n: int = p.bag_used()
	var cap_n: int = p.bag_capacity()
	var cap_bar := Control.new()
	cap_bar.custom_minimum_size = Vector2(150, 10)
	cap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap_bar)
	var cap_bg := ColorRect.new()
	cap_bg.color = Color(0, 0, 0, 0.6)
	cap_bg.size = Vector2(150, 10)
	cap_bar.add_child(cap_bg)
	var cap_frac: float = clampf(float(used_n) / float(maxi(1, cap_n)), 0.0, 1.0)
	var cap_fill := ColorRect.new()
	cap_fill.color = Color(1.0, 0.45, 0.35) if cap_frac >= 0.95 else (Color(0.95, 0.8, 0.4) if cap_frac >= 0.8 else Color(0.55, 0.85, 0.65))
	cap_fill.position = Vector2(1, 1)
	cap_fill.size = Vector2(148.0 * cap_frac, 8)
	cap_bar.add_child(cap_fill)
	var cap_lbl := _lbl(head, "%d / %d slots" % [used_n, cap_n], 13,
		Color(1.0, 0.6, 0.5) if used_n >= cap_n else Color(0.85, 0.87, 0.92))
	cap_lbl.custom_minimum_size = Vector2(90, 0)
	cap_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bags_lbl := _lbl(head, "%d/%d bags" % [p.bags.size(), Balance.MAX_BAGS], 12, UITheme.TEXT_MUTED)
	bags_lbl.custom_minimum_size = Vector2(70, 0)
	bags_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Bag chips wrap so a full loadout never widens the panel.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(chips)
	for bi in p.bags.size():
		var bb2: Dictionary = p.bags[bi]
		var bidx := bi   # per-iteration copy for the drop closure
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
		chip.tooltip_text = "%s — %s-grade bag, %d slots. Drag a loose bag here to swap it in." % [String(bb2.get("name",
			Items.BAG_NAMES.get(bg2, "Bag"))), bg2, int(bb2.get("slots", 0))]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP  # the tooltip needs the hover
		# Each equipped chip is a drop target: drag a loose bag onto it to swap
		# it in (the displaced bag drops back into the pack — never sold).
		chip.set_drag_forwarding(Callable(),
			func(_pos: Vector2, data: Variant) -> bool:
				return data is Dictionary and String(data.get("kind", "")) == "loose_bag",
			func(_pos: Vector2, data: Variant) -> void:
				p.swap_loose_bag(int(data.get("idx", -1)), bidx)
				game.sfx("levelup")
				open_inventory("gear", cat))
		chips.add_child(chip)
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		chip.add_child(crow)
		var bic := TextureRect.new()
		bic.texture = Art.bag_icon(bg2)
		bic.custom_minimum_size = Vector2(16, 16)
		bic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bic.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let the chip own the drop hover
		crow.add_child(bic)
		var clbl := _lbl(crow, "%s · %d slots" % [bg2, int(bb2.get("slots", 0))], 12, Items.GRADE_COLOR[bg2])
		clbl.custom_minimum_size = Vector2(74, 0)  # HBox label-collapse trap
		clbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Category chips wrap instead of inflating the right column; the gem
	# bench action (Auto-synthesize) rides the same row, at its end.
	var catrow := HFlowContainer.new()
	catrow.add_theme_constant_override("h_separation", 6)
	catrow.add_theme_constant_override("v_separation", 6)
	right.add_child(catrow)
	for spec in [["all", "All"], ["weapon", "Weapons"], ["helmet", "Helmets"], ["armor", "Armor"],
			["gloves", "Gloves"], ["pants", "Pants"], ["boots", "Boots"], ["charm", "Charms"],
			["gems", "Gems"], ["consumables", "Consumables"], ["materials", "Materials"], ["bags", "Bags"]]:
		var cid: String = spec[0]
		var cb := _btn(catrow, spec[1], func() -> void: open_inventory("gear", cid),
			Color(0.95, 0.85, 0.5) if cat == cid else Color(0.64, 0.66, 0.72))
		UITheme.tab(cb, cat == cid)
		cb.custom_minimum_size.y = 28.0 if not game.touch_mode else 34.0
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 12)
		for st in ["normal", "hover", "pressed"]:
			var csb2 := cb.get_theme_stylebox(String(st)) as StyleBoxFlat
			if csb2 != null:
				csb2.content_margin_left = 9.0
				csb2.content_margin_right = 9.0
				csb2.content_margin_top = 3.0
				csb2.content_margin_bottom = 3.0
	if not p.gem_bag.is_empty():
		var auto_cb := func() -> void:
			var n: int = game.local_player.auto_synthesize()
			inventory_notice = "%d gem upgrade%s." % [n, "" if n == 1 else "s"] if n > 0 else "No available gem upgrades."
			open_inventory("gear", cat)
		var ab := _btn(catrow, "⚒ Auto-synthesize", auto_cb, Color(0.6, 0.9, 1.0))
		ab.add_theme_font_size_override("font_size", 12)
		ab.custom_minimum_size.y = 28.0 if not game.touch_mode else 34.0
		ab.tooltip_text = "Merge every 3-of-a-kind until nothing can be merged.\nIn Crownfall, equipped gems level up FIRST, using two matching\nbag gems, up to their gear grade's gem limit. On the road only\nthe bag merges — socketed work waits for the Lapidary."
	if not p.backpack.is_empty():
		var order_button := _btn(catrow, "Order: " + String({"found": "Found", "grade": "Grade", "slot": "Slot", "kept": "Kept first"}[inventory_order]), func() -> void:
			var orders := ["found", "grade", "slot", "kept"]
			inventory_order = orders[(orders.find(inventory_order) + 1) % orders.size()]
			open_inventory("gear", cat), Color(0.75, 0.85, 0.95))
		order_button.name = "GearOrder"
		order_button.add_theme_font_size_override("font_size", 12)
		order_button.custom_minimum_size.y = 34
		var equip_all_cb := func() -> void:
			var n: int = game.local_player.auto_equip()
			inventory_notice = "%d upgrade%s equipped." % [n, "" if n == 1 else "s"] if n > 0 else "No strict upgrades. Kept gear stays where you put it."
			open_inventory("gear", cat)
		var eb := _btn(catrow, "⚖ Auto-equip", equip_all_cb, Color(0.6, 1.0, 0.6))
		eb.add_theme_font_size_override("font_size", 12)
		eb.custom_minimum_size.y = 28.0 if not game.touch_mode else 34.0
		eb.tooltip_text = "Fill empty slots and take strict upgrades from the bag.\nKept gear stays where you put it. Socketed gems, unique passives\nand side-grades are protected by the comparison rules."

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
	# The whole bag area accepts a gem dragged out of an equipped socket.
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
	var show_mats: bool = cat == "all" or cat == "materials"
	var show_bags: bool = cat == "all" or cat == "bags"
	if show_gear:
		for item in GearCare.sorted(p.backpack, inventory_order):
			var it: Dictionary = item
			if cat != "all" and String(it["slot"]) != cat:
				continue
			var cell := _bag_slot(grid, Art.icon_for(it), "★" if GearCare.kept(it) else "", Items.GRADE_COLOR[it["grade"]],
				func() -> void: UIGearInspect.open(self, it, cat))
			cell.tooltip_text = Items.title(it) + (" · Kept" if GearCare.kept(it) else "") + "\n" + _diff_tip(it)
			cell.set_drag_forwarding(Callable(), sock_can, sock_drop)
	if show_cons:
		# Consumables stack by id for display; using one consumes one.
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
			# Quest keepsakes expose story text but no use/drop actions.
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
					var actions: Array = [["  Use  ", Color(0.6, 1.0, 0.8), use_cb]]
					if Items.is_rotation_potion(cid):
						info += "\n\nLoadout: %d of %d slots hold a bottle%s — the rest pour Health (or sit empty by choice). %s cycles potions in the field; the Potions tab shows the whole plan." % [
							p.potion_slot_cap() - p.loadout_free_slots(), p.potion_slot_cap(),
							("  (this: x%d)" % slotted) if slotted > 0 else "",
							game.control_hint("potion_next", "The ↻ button")]
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
						info, actions, GearFlavor.of(cc))).set_drag_forwarding(Callable(), sock_can, sock_drop)
	if show_gems:
		var groups := _gem_groups()
		for key in _sorted_gem_keys(groups):
			var group: Dictionary = groups[key]
			var g: Dictionary = group["gem"]
			var count: int = group["count"]
			var can_synth: bool = count >= 3 and g["lvl"] < Items.GEM_MAX_LEVEL
			var gem_cb := func() -> void:
				var info := "%s  x%d\n\n" % [Items.gem_title(g), count]
				var is_special: bool = String(g["stat"]) in Balance.SPECIAL_GEM_STATS
				info += ("A SPECIAL gem — uses a violet ★ socket on A/S gear, within its gem-level limit.  " if is_special else "A regular gem — uses a ◇ socket within the gear grade's gem-level limit.  ")
				if int(g["lvl"]) >= Items.GEM_MAX_LEVEL:
					info += "Maximum gem level — cannot be synthesized further."
				elif can_synth:
					info += "Synthesize combines three of these into one Lv%d gem." % (g["lvl"] + 1)
				else:
					info += "Gather three to synthesize a stronger one."
				var synth_cb := func() -> void:
					game.local_player.synthesize(g["stat"], g["lvl"])
					open_inventory("gear", cat)
				var drop_cb := func() -> void:
					game.local_player.gem_bag.erase(g)
					game.discard_to_ground({"kind": "gem", "gem": g})
					open_inventory("gear", cat)
				var actions: Array = []
				# The direct path (2026-08-15): every equipped piece with a free
				# matching socket is one press away — no dragging to find out.
				if game.chapter_id == "capital":
					var targets := 0
					for slot_key in Items.SLOTS:
						if not game.local_player.equipment.has(slot_key):
							continue
						var target: Dictionary = game.local_player.equipment[slot_key]
						if game.local_player.gem_socket_error(target, g) != "":
							continue
						targets += 1
						var sock_cb := func() -> void:
							game.local_player.embed_gem_into(target, g)
							open_item_panel(target, Vector2(-1, -1), "gems")
						actions.append(["  ◈  Socket into  %s  " % Items.title(target), Items.GRADE_COLOR[target["grade"]], sock_cb])
					if targets == 0:
						info += "\n\nNo equipped piece has a free %s socket for it right now." % ("★ special" if is_special else "◇")
				else:
					info += "\n\nSocketing is bench work at the Master Lapidary in Crownfall (pause menu → ⌂)."
				if can_synth:
					actions.append(["  ⚒  Synthesize  (3 → 1 Lv%d)  " % (g["lvl"] + 1), Color(0.6, 0.9, 1.0), synth_cb])
				actions.append(["  ✖  Drop one  (throw out, free a slot)  ", Color(1.0, 0.55, 0.45), drop_cb])
				_open_detail_popover(Art.gem_codex_icon(Items.gem_color(g), int(g["lvl"])), Items.gem_title(g), Items.gem_color(g), info, actions, GearFlavor.of(g))
			var gbtn := _bag_slot(grid, Art.gem_icon(Items.gem_color(g), int(g["lvl"])),
				("x%d" % count) if count > 1 else "", Items.gem_color(g), gem_cb)
			# Gem stacks accept gems dragged back out of equipment.
			var gem_drag := func(_pos: Vector2) -> Variant:
				gbtn.set_drag_preview(_drag_preview(Art.gem_icon(Items.gem_color(g), int(g["lvl"]))))
				return {"kind": "bag_gem", "gem": g}
			gbtn.set_drag_forwarding(gem_drag, sock_can, sock_drop)
	if show_mats:
		# Crafting materials stack by family and grade.
		for m in p.materials:
			var mm: Dictionary = m
			var mfam := String(mm.get("family", ""))
			var mgr := String(mm.get("grade", "F"))
			var mcount := int(mm.get("count", 1))
			var micon: Texture2D = Art.material_ui_icon(mfam, mgr)
			var mcol: Color = Items.GRADE_COLOR.get(mgr, Color(1, 1, 1))
			var mname := String(mm.get("name", ""))
			var mglyph: String = ("x%d" % mcount) if mcount > 1 else ""
			if micon == null and mglyph == "":
				mglyph = "◆"
			var material_button := _bag_slot(grid, micon, mglyph, mcol,
				func() -> void:
					var mval := maxi(1, int(Items.material_value(mgr) * Balance.MERCHANT_SELL_FRACTION))
					var info := "%s material · grade %s\n\nStacks in your bag (up to %d per slot). A crafting input for the professions bench — sell spares at any merchant for %d gold each." % [
						mfam.capitalize(), mgr, Items.MATERIAL_STACK_MAX, mval]
					var drop_cb := func() -> void:
						mm["count"] = int(mm.get("count", 1)) - 1
						if int(mm.get("count", 0)) <= 0:
							game.local_player.materials.erase(mm)
						game.discard_to_ground({"kind": "material", "family": mfam, "grade": mgr, "count": 1})
						open_inventory("gear", cat)
					var actions: Array = [["  ✖  Drop one  (throw out, free a slot)  ", Color(1.0, 0.55, 0.45), drop_cb]]
					_open_detail_popover(micon, "%s  x%d" % [mname, mcount], mcol, info, actions, GearFlavor.of(mm)))
			material_button.set_drag_forwarding(Callable(), sock_can, sock_drop)
			if micon != null and maxi(micon.get_width(), micon.get_height()) > 32:
				material_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if show_bags:
		# Loose (unequipped) bags: a cell you click to equip / swap / sell / drop,
		# and a drag SOURCE you can pull onto an equipped chip above to swap it in.
		for li in p.loose_bags.size():
			var lb: Dictionary = p.loose_bags[li]
			var lg := String(lb.get("grade", "F"))
			var lidx := li
			var lbtn: Button = _bag_slot(grid, Art.bag_icon(lg), "", Items.GRADE_COLOR.get(lg, Color(1, 1, 1)),
				func() -> void: _open_bag_popover(p, lidx, cat))
			lbtn.tooltip_text = "%s — %s-grade bag, %d slots (loose). Click to equip / sell; drag onto an equipped bag to swap." % [
				String(lb.get("name", Items.BAG_NAMES.get(lg, "Bag"))), lg, int(lb.get("slots", 0))]
			lbtn.set_drag_forwarding(
				func(_pos: Vector2) -> Variant:
					lbtn.set_drag_preview(_drag_preview(Art.bag_icon(lg)))
					return {"kind": "loose_bag", "idx": lidx},
				Callable(), Callable())
	# Only the All view represents free capacity.
	if cat == "all":
		for i in maxi(0, p.bag_capacity() - p.bag_used()):
			_bag_empty(grid).set_drag_forwarding(Callable(), sock_can, sock_drop)
		# P7.F (2026-08-19, the reference bag screens): capacity you could still
		# EARN shows as one row of LOCKED cells under the free ones — a bag slot
		# you haven't filled with a bag yet — so the pack reads as a grid with a
		# ceiling, not a list that happens to stop.
		if p.bags.size() < Balance.MAX_BAGS:
			for i in grid.columns:
				_bag_locked(grid, p.bags.size())
	_hint(vbox, "ESC, ✕, click outside, or %s to close" % menu_key("inventory"))


## One equipped-slot card of the inventory's left column: [icon well][name +
## quiet stat line][sockets]. The whole card opens the item's panel and takes a
## bag gem dropped anywhere on it (Crownfall); the socket squares stay their
## own precise targets. An empty slot is the same card, dimmed, so the seven
## never shuffle.
func _equipped_row(left: VBoxContainer, slot: String, cat: String) -> void:
	var p: Player = game.local_player
	var has: bool = p.equipment.has(slot)
	var item: Dictionary = p.equipment[slot] if has else {}
	var color: Color = Items.GRADE_COLOR[item["grade"]] if has else Color(0.4, 0.36, 0.26)
	var card := UITheme.card(left, color if has else Color(0.32, 0.30, 0.26), 8.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has else Control.CURSOR_ARROW
	if has:
		card.tooltip_text = "Select for the item card"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS  # clicks fall through to the card
	card.add_child(row)
	# Icon well.
	var well := Panel.new()
	well.custom_minimum_size = Vector2(46, 46)
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	wsb.border_color = Color(color, 0.85 if has else 0.6)
	wsb.set_border_width_all(2)
	wsb.set_corner_radius_all(4)
	well.add_theme_stylebox_override("panel", wsb)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(well)
	if has:
		var ic := TextureRect.new()
		ic.texture = Art.icon_for(item)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_top = 4
		ic.offset_right = -4
		ic.offset_bottom = -4
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(ic)
	else:
		var mono := Label.new()
		mono.text = slot.substr(0, 1).to_upper()
		mono.set_anchors_preset(Control.PRESET_FULL_RECT)
		mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.title(mono, 20)
		mono.add_theme_color_override("font_color", Color(0.42, 0.38, 0.28, 0.9))
		mono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(mono)
	# Name + stat line.
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var socket_n: int = int(item.get("gem_slots", 0)) if has else 0
	var text_w: float = 260.0 - (socket_n * 38.0 if has else 0.0)
	if has:
		var nm := _lbl(text, Items.title(item), 14, color)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size = Vector2(text_w, 0)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dl := _lbl(text, Items.describe(item, false), 11, Color(0.68, 0.7, 0.76))
		dl.custom_minimum_size = Vector2(text_w, 0)
		# (No overrun trim here: with autowrap it collapses the label's minimum
		# height to 1px and the line vanishes — Godot 4.4.)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var el := _lbl(text, "%s — empty" % slot.capitalize(), 13, Color(0.5, 0.5, 0.52))
		el.custom_minimum_size = Vector2(text_w, 0)
		el.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sockets, on the row's right — the whole card is also a drop target.
	if has:
		var open_cb := func() -> void:
			open_item_panel(item)
		var sockets: HBoxContainer = null
		if socket_n > 0:
			var refresh := func() -> void: open_inventory("gear", cat)
			var can_fn := func(_pos: Vector2, data: Variant) -> bool:
				return data is Dictionary and String(data.get("kind", "")) == "bag_gem" \
					and game.local_player.gem_socket_error(item, data["gem"]) == ""
			var drop_fn := func(_pos: Vector2, data: Variant) -> void:
				game.local_player.embed_gem_into(item, data["gem"])
				open_inventory("gear", cat)
			card.set_drag_forwarding(Callable(), can_fn, drop_fn)
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 4)
			srow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			srow.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(srow)
			_socket_row(srow, item, refresh)
			sockets = srow
		_wire_card_tap(card, sockets, open_cb)


## Claude-authored equipped-card gesture, revised by Codex after source review.
## Observe real touch contacts before GUI delivery. Once multiple fingers or
## a cancellation interrupt a gesture, no card can re-arm until all lift.
var _card_tap := {}
var _card_contacts := {}
var _card_touch_blocked := false


func _wire_card_tap(card: Control, sockets: Control, open_cb: Callable) -> void:
	var shell := root
	card.gui_input.connect(func(e: InputEvent) -> void:
		if root != shell or current != "inventory" or not is_instance_valid(shell) \
				or shell.is_queued_for_deletion() or card.is_queued_for_deletion():
			return
		# A real finger owns its raw stream, irrespective of mouse emulation.
		# A physical mouse keeps press-open; its generated touch is ignored too.
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var touch: bool = e is InputEventScreenTouch and e.pressed and not e.canceled
		var mouse: bool = e is InputEventMouseButton and e.pressed \
				and e.button_index == MOUSE_BUTTON_LEFT and not e.canceled
		if not touch and not mouse:
			return
		if sockets != null and not is_instance_valid(sockets):
			return
		var at: Vector2 = card.get_global_transform_with_canvas() * e.position
		if sockets != null and Rect2(Vector2.ZERO, sockets.size).has_point(
				sockets.get_global_transform_with_canvas().affine_inverse() * at):
			return  # do not consume: socket Buttons and scroll still own their input
		if _card_touch_blocked:
			return
		if mouse:
			if _card_contacts.is_empty():
				open_cb.call()
			return
		if _card_contacts.size() != 1 or not _card_contacts.has(e.index):
			return
		_card_tap = {"card": card, "sockets": sockets, "open_cb": open_cb,
			"shell": shell, "index": e.index, "from": at, "moved": false})


func _card_tap_observe(e: InputEvent) -> void:
	if not is_open():
		_card_tap = {}
		_card_contacts.clear()
		_card_touch_blocked = false
		return
	if e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventScreenTouch:
		if e.canceled:
			_card_tap = {}
			_card_touch_blocked = true
			# Godot reports canceled touches as released, even if their setter
			# originally requested pressed=true. Other held contacts stay blocked.
			_card_contacts.erase(e.index)
		elif e.pressed:
			if _card_contacts.has(e.index):
				_card_touch_blocked = true
			_card_contacts[e.index] = true
			if _card_contacts.size() > 1:
				_card_touch_blocked = true
			if _card_touch_blocked:
				_card_tap = {}
		else:
			var known: bool = _card_contacts.has(e.index)
			_card_contacts.erase(e.index)
			if known and not _card_touch_blocked and not _card_tap.is_empty() \
					and int(_card_tap.index) == e.index:
				_card_tap_release(e.position)
		if _card_contacts.is_empty():
			_card_touch_blocked = false
	elif e is InputEventScreenDrag:
		if not _card_tap.is_empty() and int(_card_tap.index) == e.index \
				and e.position.distance_to(_card_tap.from) > Balance.ATLAS_DRAG_THRESHOLD:
			_card_tap.moved = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		# A mixed mouse/finger gesture cannot complete an old finger tap.
		_card_tap = {}
		if not _card_contacts.is_empty():
			_card_touch_blocked = true


func _card_tap_release(at: Vector2) -> void:
	var rec: Dictionary = _card_tap
	_card_tap = {}
	if rec.moved or at.distance_to(rec.from) > Balance.ATLAS_DRAG_THRESHOLD:
		return
	# Variant references may point at freed Nodes. Check before a typed binding,
	# and reject a queued shell even before Godot frees its children.
	if not is_instance_valid(rec.get("shell")) or not is_instance_valid(rec.get("card")):
		return
	if rec.shell.is_queued_for_deletion() or rec.card.is_queued_for_deletion() \
			or root != rec.shell or current != "inventory":
		return
	var card: Control = rec.card
	if not card.is_visible_in_tree() or not rec.shell.is_ancestor_of(card):
		return
	if not Rect2(Vector2.ZERO, card.size).has_point(card.get_global_transform_with_canvas().affine_inverse() * at):
		return
	if rec.sockets != null:
		if not is_instance_valid(rec.sockets) or rec.sockets.is_queued_for_deletion():
			return
		var sockets: Control = rec.sockets
		if Rect2(Vector2.ZERO, sockets.size).has_point(sockets.get_global_transform_with_canvas().affine_inverse() * at):
			return
	rec.open_cb.call()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_card_tap = {}
		_card_contacts.clear()
		_card_touch_blocked = false


## One clickable bag slot. A stack count (gems, potions, materials) rides as
## a small badge in the corner instead of crowding the icon as button text.
func _bag_slot(grid: GridContainer, icon: Texture2D, glyph: String, color: Color,
		cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if glyph != "":  # icon + count: the count is a corner badge
			var badge := Label.new()
			badge.text = glyph.strip_edges()
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1, 1, 1))
			badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			badge.add_theme_constant_override("outline_size", 4)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.offset_left = -40
			badge.offset_top = -18
			badge.offset_right = -3
			badge.offset_bottom = -1
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(badge)
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
	if cb.is_valid():
		b.pressed.connect(cb)
	else:
		b.disabled = true
		b.add_theme_stylebox_override("disabled", sb)
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


## A LOCKED bag cell (P7.F): dimmer than an empty socket, a small lock glyph,
## a tooltip that says how to earn it. `bags_owned` decides the wording.
func _bag_locked(grid: GridContainer, bags_owned: int) -> Panel:
	var pnl := Panel.new()
	pnl.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, 0.9)
	sb.border_color = Color(0.22, 0.2, 0.16, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.tooltip_text = "Locked — bag slot %d of %d is empty. Find or buy a bag and equip it to open this row." % [
		bags_owned + 1, Balance.MAX_BAGS]
	# a small padlock drawn from shapes (no glyph dependency on the body font)
	var lc := Color(0.48, 0.44, 0.36, 0.85)
	var shackle := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0)
	ss.border_color = lc
	ss.set_border_width_all(2)
	ss.set_corner_radius_all(5)
	shackle.add_theme_stylebox_override("panel", ss)
	shackle.position = Vector2(19, 13)
	shackle.size = Vector2(10, 12)
	shackle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pnl.add_child(shackle)
	var lbody := ColorRect.new()
	lbody.color = lc
	lbody.position = Vector2(16, 22)
	lbody.size = Vector2(16, 12)
	lbody.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pnl.add_child(lbody)
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
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # clean downscale of 128px codex icons
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
	# Long equipped-item benches include their header and action rows too.
	# Reserve that chrome before capping the body, so the final buttons never
	# fall below the viewport when touch targets or a wrapped title grow.
	if scroll != null and pop.size.y > 704.0:
		scroll.custom_minimum_size.y = maxf(48.0, scroll.custom_minimum_size.y - (pop.size.y - 704.0))
		pop.reset_size()
	var sz := pop.size
	# Stay inside the open panel's frame (not just the screen) — a card that
	# hangs out of its window reads as a glitch; fall back to the screen when
	# the shell would be too small to hold it.
	var lo := Vector2(8.0, 8.0)
	var hi := Vector2(1280.0 - sz.x - 8.0, 720.0 - sz.y - 8.0)
	if _shell_rect.size.x > 0.0:
		var slo := _shell_rect.position + Vector2(10.0, 10.0)
		var shi := _shell_rect.end - sz - Vector2(10.0, 10.0)
		if shi.x >= slo.x:
			lo.x = slo.x
			hi.x = shi.x
		if shi.y >= slo.y:
			lo.y = slo.y
			hi.y = shi.y
	pop.position = Vector2(clampf(pop.position.x, lo.x, hi.x), clampf(pop.position.y, lo.y, hi.y))


## Cursor-anchored detail popover shared by bag, shop and equipment.
## Loose-bag detail popover (2026-08-17): equip into a free slot, or one-click
## replace the smallest equipped bag it beats when full, plus sell and drop.
## Dragging the cell onto a specific equipped chip handles replacing a chosen bag.
func _open_bag_popover(p: Player, idx: int, cat: String) -> void:
	if idx < 0 or idx >= p.loose_bags.size():
		return
	var lb: Dictionary = p.loose_bags[idx]
	var lg := String(lb.get("grade", "F"))
	var slots := int(lb.get("slots", 0))
	var col: Color = Items.GRADE_COLOR.get(lg, Color(1, 1, 1))
	var info := "%s-grade bag — %d carry slots.\n\nEquip it to add its slots to your capacity. When all %d bag slots are full, DRAG it onto an equipped bag to take that bag's place (the old bag drops back into your pack, never sold). Spare bags sell for %dg." % [
		lg, slots, Balance.MAX_BAGS, Balance.BAG_SELL_GOLD]
	var actions: Array = []
	if p.has_free_bag_slot():
		actions.append(["  ◈  Equip  (+%d slots)  " % slots, col, func() -> void:
			p.equip_loose_bag(idx)
			game.sfx("levelup")
			open_inventory("gear", cat)])
	else:
		var worst := 0
		for i in range(1, p.bags.size()):
			if int(p.bags[i].get("slots", 0)) < int(p.bags[worst].get("slots", 0)):
				worst = i
		if slots > int(p.bags[worst].get("slots", 0)):
			actions.append(["  ◈  Replace smallest (%s)  " % String(p.bags[worst].get("name", "bag")), col, func() -> void:
				p.swap_loose_bag(idx, worst)
				game.sfx("levelup")
				open_inventory("gear", cat)])
	actions.append(["  ⛃  Sell  (%d gold)  " % Balance.BAG_SELL_GOLD, Color(1.0, 0.9, 0.4), func() -> void:
		p.sell_loose_bag(idx)
		game.sfx("potion")
		open_inventory("gear", cat)])
	actions.append(["  ✖  Drop  (throw out)  ", Color(1.0, 0.55, 0.45), func() -> void:
		if idx >= 0 and idx < p.loose_bags.size():
			p.loose_bags.remove_at(idx)
			game.discard_to_ground({"kind": "bag", "grade": lg})
		open_inventory("gear", cat)])
	_open_detail_popover(Art.bag_icon(lg), String(lb.get("name", Items.BAG_NAMES.get(lg, "Bag"))), col, info, actions, GearFlavor.of(lb))


func _open_detail_popover(icon: Texture2D, title: String, title_color: Color,
		info: String, actions: Array, flavor := "") -> void:
	if not root:
		return
	var vbox := _popover_frame(title_color)
	var pop := _popover_box
	_popover_header(vbox, icon, title, title_color)
	var il := _lbl(vbox, info, 14, Color(0.85, 0.85, 0.92))
	il.custom_minimum_size = Vector2(320, 0)
	# Flavor: a quoted, dim parchment line under the stats (empty = hidden).
	if flavor != "":
		var fl := _lbl(vbox, "❝ %s ❞" % flavor, 13, Color(0.72, 0.68, 0.55))
		fl.custom_minimum_size = Vector2(320, 0)
	for a in actions:
		var acb: Callable = a[2]
		_btn(vbox, String(a[0]), acb, a[1])
	await _popover_settle(pop, Vector2(-1, -1))


## Dismiss the popover without rebuilding its underlay.
func _close_detail_popover() -> void:
	if detail_popover:
		detail_popover.queue_free()
		detail_popover = null
	if current == "detail":
		current = detail_return if detail_return != "" else "inventory"


## Stable gem order: stat name, then level descending.
func _sorted_gem_keys(groups: Dictionary) -> Array:
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b) -> bool:
		var ga: Dictionary = groups[a]["gem"]
		var gb: Dictionary = groups[b]["gem"]
		if ga["stat"] == gb["stat"]:
			return int(ga["lvl"]) > int(gb["lvl"])
		return String(ga["stat"]) < String(gb["stat"]))
	return keys


## Full character sheet with per-stat explanations.
## The inventory's Stats tab = THE character sheet (one component, shared with
## the Skills › Attributes tab so the two never drift — 2026-08-16: they were
## two hand-built lists, one of them a raw text blob).
func _build_stats_tab(vbox: VBoxContainer, p: Player) -> void:
	_paper_doll(vbox, p)   # P7.E: the hero + their seven pieces, above the ledger
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var tip := _lbl(list, "Select any stat to learn what it does. Points are spent in Skills › Attributes.", 12, UITheme.TEXT_MUTED)
	tip.custom_minimum_size = Vector2(700, 0)
	# Three columns of ledger lines (name left, value flush right) so the
	# sheet fills the panel with numbers instead of empty card, and reads
	# without a scroll: what you build · how you hit · how you last.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right", 14)  # clear of the scrollbar
	list.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	margin.add_child(cols)
	var by_title := {}
	for sec in _stat_sheet_data(p):
		by_title[String(sec["title"])] = sec
	var flash_keep := _stat_flash.duplicate()
	# Grouped so the three columns carry near-equal row counts, and each
	# column's LAST card stretches to the shared bottom line — three even
	# pillars, not three ragged stacks (owner 2026-08-16).
	for group in [["COMBAT", "UTILITY"], ["ATTRIBUTES", "FACTIONS"], ["DEFENSE", "SHARD"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		var picked: Array = []
		for t in group:
			if by_title.has(t):
				picked.append(by_title[t])
		_stat_flash = flash_keep.duplicate()
		_stat_sheet_build(col, picked, false)
		var last := col.get_child(col.get_child_count() - 1) as Control
		if last != null:
			last.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stat_flash = {}
	_hint(vbox, "ESC, ✕, click outside, or %s to close" % menu_key("inventory"))


## PAPER DOLL (P7.E, 2026-08-19; the reference bag/character screens): the
## hero as they stand in the game — their live idle strip, breathing — in a
## small glass stage, their name / class / level / Combat Rating beside it, and
## the seven equipped pieces as rarity-framed icon wells flanking the body
## (three left, four right). Click a well for the piece's card. Sits above the
## stat ledger so the sheet reads hero-first, numbers second.
const PD_H := 176.0
const PD_MODEL_H := 150.0
const PD_LEFT := ["weapon", "helmet", "armor"]
const PD_RIGHT := ["gloves", "pants", "boots", "charm"]
const PD_WELL_W := 44.0
const PD_WELL_LEFT_X := 18.0
const PD_WELL_RIGHT_X := 236.0
func _paper_doll(vbox: VBoxContainer, p: Player) -> void:
	var band := Control.new()
	band.custom_minimum_size = Vector2(0, PD_H)
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(band)
	# the stage
	var stage := Panel.new()
	stage.position = Vector2(0, 0)
	stage.size = Vector2(1080, PD_H)
	stage.clip_contents = true
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.045, 0.045, 0.065, 0.92)
	ssb.border_color = Color(UITheme.BORDER, 0.9)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(10)
	stage.add_theme_stylebox_override("panel", ssb)
	band.add_child(stage)
	# The model stands on the MIDLINE between the two well columns (left wells
	# 18..62, right wells 236..280 → 149); it used to sit at 210, visibly right
	# of centre (owner flag 2026-08-19).
	var model_x: float = (PD_WELL_LEFT_X + PD_WELL_W + PD_WELL_RIGHT_X) * 0.5
	var glow := Sprite2D.new()
	glow.texture = Art.tex("glow")
	glow.modulate = Color(0.9, 0.8, 0.55, 0.22)
	glow.scale = Vector2(1.9, 0.7)
	glow.position = Vector2(model_x, PD_H - 22)
	stage.add_child(glow)
	# The hero's actual art: the equipped skin's body when one is on, else the class body.
	var art_name: String = Classes.CLASSES[p.cls]["sprite"]
	var skin_art: String = Skins.skin_sprite(p.cls, p.skin)
	if skin_art != "":
		art_name = skin_art
	var clips: Dictionary = Art.hero_clips(art_name)
	if clips.has("idle"):
		var info: Dictionary = clips["idle"]
		var tex: Texture2D = info["tex"]
		var frames := int(info["frames"])
		var fsize: Vector2 = Vector2(info.get("frame_size", Vector2i(tex.get_height(), tex.get_height())))
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		sf.set_animation_loop("idle", true)
		sf.set_animation_speed("idle", float(info.get("fps", 6.0)))
		for f in frames:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * fsize.x, 0, fsize.x, fsize.y)
			sf.add_frame("idle", at)
		var model := AnimatedSprite2D.new()
		model.sprite_frames = sf
		# LINEAR: this preview scales the body off-integer (nearest = uneven
		# pixels up, dropped rows down) — same call as the class-select stage.
		model.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var s := minf(2.2, PD_MODEL_H / maxf(1.0, fsize.y))
		model.scale = Vector2(s, s)
		# Centre the BODY, not the cell: hero frames carry side padding, so the
		# alpha centroid of frame 0 is the x that must land on the midline.
		var body_dx := 0.0
		var raw: Dictionary = Art.hero_frame_bounds(info, Rect2i(0, 0, int(fsize.x), int(fsize.y))) \
			if fsize.x > 0 and fsize.y > 0 else {}
		var r0 := Rect2i()
		if not raw.is_empty():
			r0 = raw["used"]
		else:
			# AtlasTexture's zero-size axes mean the whole source axis. Retain
			# that original path for external/invalid-size preview descriptors.
			var f0 := AtlasTexture.new()
			f0.atlas = tex
			f0.region = Rect2(0, 0, fsize.x, fsize.y)
			var img0: Image = f0.get_image()
			if img0 != null:
				r0 = img0.get_used_rect()
		if r0.size.x > 0:
			body_dx = (r0.position.x + r0.size.x * 0.5) - fsize.x * 0.5
		model.position = Vector2(model_x - body_dx * s, PD_H - 30.0 - fsize.y * s * 0.5)
		stage.add_child(model)
		model.play("idle")
	# identity column right of the wells
	var ident := VBoxContainer.new()
	ident.position = Vector2(300, 14)
	ident.size = Vector2(220, PD_H - 28)
	ident.add_theme_constant_override("separation", 3)
	stage.add_child(ident)
	var hero_name := String(p.char_name).strip_edges()
	var nm := _lbl(ident, hero_name if hero_name != "" else String(Classes.CLASSES[p.cls]["name"]), 20, Color(0.96, 0.86, 0.52))
	UITheme.title(nm, 20)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(210, 0)
	_lbl(ident, "%s  ·  Lv %d" % [String(Classes.CLASSES[p.cls]["name"]), p.level], 13, Color(0.82, 0.84, 0.9))
	_lbl(ident, "Combat Rating  %d" % p.combat_rating(), 13, Color(0.72, 0.9, 1.0))
	_lbl(ident, "HP %d / %d     MP %d / %d" % [int(p.hp), int(p.max_hp), int(p.mp), int(p.max_mp)], 12, Color(0.85, 0.85, 0.9))
	var theme_names: Array = []
	for theme in Classes.THEMES[p.cls]:
		theme_names.append(String(theme["name"]))
	_lbl(ident, "Themes  " + " · ".join(theme_names), 11, UITheme.TEXT_MUTED)
	# ACTIVE ABILITIES (the reference's ability cards): four icon plates with
	# the ability's name and its cost line, right half of the band
	var abrow := HBoxContainer.new()
	abrow.position = Vector2(540, 18)
	abrow.add_theme_constant_override("separation", 10)
	stage.add_child(abrow)
	for slot in ["a1", "a2", "a3", "ult"]:
		var ab: Dictionary = Classes.CLASSES[p.cls]["abilities"][slot]
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(UITheme.SURFACE, 0.95)
		csb.border_color = Color(UITheme.BORDER, 0.9)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 8
		csb.content_margin_right = 8
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)
		card.custom_minimum_size = Vector2(122, PD_H - 36)
		card.tooltip_text = "%s — %s" % [String(ab["name"]), String(ab["desc"])]
		abrow.add_child(card)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Art.ability_icon(p.cls, String(slot))
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)
		var anm := _lbl(col, String(ab["name"]), 12, Color(0.94, 0.94, 0.98))
		anm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		anm.custom_minimum_size = Vector2(104, 0)
		anm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cost := "%s MP · CD %ss" % [Hud._fmt_cost(float(ab.get("mp", 0))), str(ab.get("cd", 0))]
		if Classes.CLASSES[p.cls].get("manaless", false):
			cost = "CD %ss" % str(ab.get("cd", 0))
		var cl := _lbl(col, cost, 10, UITheme.TEXT_MUTED)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.custom_minimum_size = Vector2(104, 0)
		_ignore_mouse_recursive(col)
	# the seven wells: three left of the body, four right (reference layout)
	var wells := {"left": Vector2(PD_WELL_LEFT_X, 16), "right": Vector2(PD_WELL_RIGHT_X, 10)}
	for side in ["left", "right"]:
		var slots: Array = PD_LEFT if side == "left" else PD_RIGHT
		var origin: Vector2 = wells[side]
		var step := (PD_H - 24.0) / float(slots.size())
		for k in slots.size():
			_pd_well(stage, String(slots[k]), p, origin + Vector2(0, step * k))
	# a bronze rule under the band so the ledger starts on a line
	var rule := ColorRect.new()
	rule.color = Color(UITheme.GOLD, 0.35)
	rule.position = Vector2(0, PD_H - 1)
	rule.size = Vector2(1080, 1)
	band.add_child(rule)


## One paper-doll well: a 44 px rarity-framed icon (or the slot's initial when
## empty); click = the piece's card (same popover the Gear tab opens).
func _pd_well(parent: Control, slot: String, p: Player, at: Vector2) -> void:
	var has: bool = p.equipment.has(slot)
	var item: Dictionary = p.equipment[slot] if has else {}
	var color: Color = Items.GRADE_COLOR[item["grade"]] if has else Color(0.4, 0.36, 0.26)
	var well := Panel.new()
	well.position = at
	well.size = Vector2(44, 44)
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	wsb.border_color = Color(color, 0.9 if has else 0.55)
	wsb.set_border_width_all(2)
	wsb.set_corner_radius_all(5)
	well.add_theme_stylebox_override("panel", wsb)
	well.tooltip_text = (Items.title(item) if has else "%s — empty" % slot.capitalize())
	well.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has else Control.CURSOR_ARROW
	parent.add_child(well)
	if has:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = Art.icon_for(item)
		ic.position = Vector2(4, 4)
		ic.size = Vector2(36, 36)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(ic)
		well.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_detail_popover(Art.icon_for(item), Items.title(item), color,
					Items.describe(item), [], GearFlavor.of(item)))
	else:
		var mono := Label.new()
		mono.text = slot.substr(0, 1).to_upper()
		mono.set_anchors_preset(Control.PRESET_FULL_RECT)
		mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mono.add_theme_font_size_override("font_size", 14)
		mono.add_theme_color_override("font_color", Color(0.45, 0.42, 0.36))
		mono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(mono)


## Snapshot of a sheet's values by row name — taken BEFORE a point is spent so
## the rebuilt sheet can flash exactly the numbers that moved.
var _stat_flash := {}
var _stat_pop_frame := -1  # frame a stat explainer last opened (touch + emulated click dedupe)


## Character sheet, one grouped card per section. `compact` = the narrower
## column beside the attribute allocator. Rows whose value differs from
## `_stat_flash` (a pre-spend snapshot) pulse green so a spent point is SEEN.
func _stat_sheet_build(list: VBoxContainer, sections: Array, compact: bool) -> void:
	for sec in sections:
		var sd: Dictionary = sec
		var head := _lbl(list, String(sd["title"]), 13 if compact else 15, Color(0.95, 0.85, 0.5))
		UITheme.header(head)
		var card := UITheme.card(list, Color(0.42, 0.45, 0.55), 8.0 if compact else 10.0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1 if compact else 2)
		card.add_child(col)
		for r in sd["rows"]:
			var rd: Array = r
			var nm := String(rd[0])
			var val := String(rd[1])
			var lbl := _stat_row(col, nm, val, String(rd[2]), rd[3] if rd.size() > 3 else Color(0.85, 0.85, 0.9), compact)
			if _stat_flash.has(nm) and String(_stat_flash[nm]) != val:
				# The number just moved: pulse it green, then settle.
				lbl.modulate = Color(0.55, 1.0, 0.6)
				var tw := create_tween()
				tw.tween_property(lbl, "modulate", Color(1, 1, 1), 0.9).set_ease(Tween.EASE_OUT)
		var note := String(sd.get("note", ""))
		if note != "":
			var nl := _lbl(col, note, 11 if compact else 12, Color(0.5, 1.0, 0.5))
			nl.custom_minimum_size = Vector2(300 if compact else 380, 0)
	_stat_flash = {}


## The sheet's data: [{title, rows: [[name, value, tip, color?]...], note?}]
## — everything the sheet shows, in display order, numbers pulled live.
func _stat_sheet_data(p: Player) -> Array:
	var out: Array = []
	var attr_rows: Array = []
	for attr in Classes.ATTR_NAMES:
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == attr
		attr_rows.append(["%s%s" % [attr, "  ★" if is_primary else ""], str(p.attr_total(attr)),
			Classes.attr_help(p.cls, attr),
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9)])
	out.append({"title": "ATTRIBUTES", "rows": attr_rows,
		"note": ("%d unspent point%s — allocate in Skills › Attributes" % [p.unspent_attr, "" if p.unspent_attr == 1 else "s"]) if p.unspent_attr > 0 else ""})
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
	out.append({"title": "COMBAT", "rows": rows})
	var rows2 := [
		["HP", "%d / %d" % [int(p.hp), int(p.max_hp)], "Your health. Dying returns you to the last safe room you visited — and the room you fell in resets."],
		["Mana", "%d / %d" % [int(p.mp), int(p.max_mp)], "Fuel for abilities. Regenerates over time (mages regenerate 50% faster)."],
		["Phys Res", str(int(p.physres)), "Reduces physical damage taken (diminishing returns — never reaches 100%)."],
		["Magic Res", str(int(p.magres)), "Reduces magic damage taken (diminishing returns). TRUE damage ignores all resistances."],
		["Crit Res", str(int(p.critres)), "Shaves the enemy's chance to critically hit you."],
		["Evasion", "%d%%" % int(Stats.eva_curve(p.eva) * 100), "Chance to fully dodge a hit. Countered by the attacker's DEX. Capped at %d%%." % int(Balance.CAP_EVA * 100)],
	]
	out.append({"title": "DEFENSE", "rows": rows2})
	var rows3 := [
		["Speed", str(int(p.speed)), "How fast you move. Ice patches boost it; void rifts slow it."],
		["Lifesteal", "%d%%" % int(p.lifesteal * 100), "Heals you for a share of damage dealt. AoE hits only steal a third."],
		["Greed", "%d%%" % int(Stats.greed_gold(p.current_greed()) * 100), "Bonus gold from every source. Every point also nudges chest drop rates. Strong diminishing returns past %d%%. Sourced only by GOLD RUSH coins — rare charged coins spilled by farm kills that surge it for a window." % int(Balance.CAP_GREED * 100)],
	]
	out.append({"title": "UTILITY", "rows": rows3})

	# Resonance number, band and sources.
	var res_band := String(Story.res_band(p.resonance))
	var res_word: String = {"steady": "Steady — the shard hums warm",
		"tempted": "Tempted — the shard whispers"}.get(res_band, "Quiet — the shard is undecided")
	var res_col: Color = {"steady": Color(0.6, 1.0, 0.6),
		"tempted": Color(1.0, 0.6, 0.6)}.get(res_band, Color(0.85, 0.85, 0.9))
	# Ledger values stay SHORT (the row is one line); the words live in the tip.
	var res_tip := "How the shard resonates with your CHOICES, from -100 (Temptation) to +100 (Virtue). Kindness, mercy and honest work raise it; cruelty, theft and grave-robbing lower it. The world reads it before you do: merchants price you 10% kinder when it's high and 10% warier when it's low, some dialogue options only open at certain bands, and NPCs react to what the shard says about you."
	var shard_rows: Array = [["Resonance", "%+d" % int(p.resonance), res_tip, res_col],
		["Shard mood", res_word.split(" — ")[0], res_tip + "\n\n" + res_word, res_col]]
	if p.res_lean() <= 0.0:
		shard_rows.append(["Shard lean", "none",
			"The shard is undecided. Commit past the band line (±25) and a lean wakes, growing to full strength at ±100. Virtue leans into CONSTANCY: health potions mend up to %d%% deeper. Temptation leans into HUNGER: up to +%d%% damage to wounded mobs (below %d%% HP — never bosses) and up to +%d%% gold from kills. Neither is the correct answer; staying undecided is the only way to get nothing." % [
				int(Balance.RES_CONSTANCY_HEAL_MAX * 100), int(Balance.RES_HUNGER_EXEC_MAX * 100),
				int(Balance.RES_HUNGER_EXEC_AT * 100), int(Balance.RES_HUNGER_GOLD_MAX * 100)]])
	elif p.resonance > 0.0:
		shard_rows.append(["Shard lean", "Constancy  +%d%% mend" % int((p.constancy_heal_mult() - 1.0) * 100.0),
			"The steady shard rewards the measured hand: health potions restore +%d%% more (grows with conviction — +%d%% at Virtue 100). Merchants already price the steady 10%% kinder." % [
				int((p.constancy_heal_mult() - 1.0) * 100.0), int(Balance.RES_CONSTANCY_HEAL_MAX * 100)], res_col])
	else:
		shard_rows.append(["Shard lean", "Hunger  +%d%% exec · +%d%% gold" % [
				int(p.hunger_exec_bonus() * 100.0), int((p.hunger_gold_mult() - 1.0) * 100.0)],
			"The tempted shard savors the finish: +%d%% damage to mobs below %d%% health (bosses are immune — earn those the honest way) and +%d%% gold from every kill (grows with conviction — full at Temptation -100)." % [
				int(p.hunger_exec_bonus() * 100.0), int(Balance.RES_HUNGER_EXEC_AT * 100),
				int((p.hunger_gold_mult() - 1.0) * 100.0)], res_col])
	out.append({"title": "SHARD", "rows": shard_rows})

	# (T5) Faction standing — who in Vaelscar trusts you, and how much.
	var factions := [
		["accord", "Ember Accord", "joined_accord", "Maren's loyalists: gather the shards, break the hollow throne for good."],
		["cinderborn", "Cinderborn", "joined_cinderborn", "Old-regime nobles: order needs a crown — find a worthy head for it."],
		["wildfang", "Wildfang Tribes", "", "Fangmaw's beastkin descendants. They remember who opens doors. (Not joinable.)"],
		["choir", "Hollow Choir", "", "Blight-plague survivors turned faithful. They do not recruit; they wait. (Not joinable.)"],
	]
	var fac_rows: Array = []
	for f in factions:
		var standing: int = int(p.faction_standing.get(f[0], 0))
		var joined: bool = f[2] != "" and game.get_flag(f[2], false)
		var val := "%s%d%s" % ["+" if standing > 0 else "", standing, "   ⚑ JOINED" if joined else ""]
		var col := Color(0.6, 1.0, 0.6) if standing > 0 else (Color(1.0, 0.6, 0.6) if standing < 0 else Color(0.85, 0.85, 0.9))
		fac_rows.append([f[1], val, f[3], col])
	out.append({"title": "FACTIONS", "rows": fac_rows})
	return out


## Row name -> value for every row of the sheet (the pre-spend snapshot).
func _stat_values(p: Player) -> Dictionary:
	var out := {}
	for sec in _stat_sheet_data(p):
		for r in sec["rows"]:
			out[String(r[0])] = String(r[1])
	return out


## One clickable stat row with an explanation popover: name · value. The
## whole row is the target (it brightens under the pointer); no glyph.
## Returns the VALUE label (the sheet pulses it when a number moves).
func _stat_row(parent: Node, stat_name: String, value: String, tip: String, color := Color(0.85, 0.85, 0.9), compact := false) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Mouse click OR a finger tap (touch events are handled explicitly, not
	# only via mouse emulation) opens the explainer.
	row.gui_input.connect(func(e: InputEvent) -> void:
		var hit: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
		# A touch arrives twice (the touch + its emulated mouse click): one per frame.
		if hit and Engine.get_process_frames() != _stat_pop_frame:
			_stat_pop_frame = Engine.get_process_frames()
			row.accept_event()
			_open_detail_popover(null, stat_name, color, tip, []))
	parent.add_child(row)
	# Name takes the slack, value sits flush right — a ledger line, not a
	# left-heavy row trailing empty card.
	var n := _lbl(row, stat_name, 13 if compact else 14, color)
	n.custom_minimum_size = Vector2(120 if compact else 140, 0)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _lbl(row, value, 13 if compact else 14, Color(1, 1, 1))
	v.custom_minimum_size = Vector2(60, 0)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF  # a value is one line; it takes the width it needs
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hover = the row lifts a touch, so "select a stat" has a visible target.
	row.mouse_entered.connect(func() -> void: n.modulate = Color(1.25, 1.25, 1.2))
	row.mouse_exited.connect(func() -> void: n.modulate = Color(1, 1, 1))
	return v


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


## Equipped-item popover: Info, Gems and Reforge tabs plus Unequip.
func open_item_panel(item: Dictionary, at := Vector2(-1, -1), tab := "info") -> void:
	if not root:
		return
	# Preserve position across tab and item rebuilds.
	if at.x < 0.0 and is_instance_valid(_popover_box):
		at = _popover_box.position
	# Rebuild the inventory underlay so edits stay in sync.
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
	_btn(vbox, "★ Kept — unkeep" if GearCare.kept(item) else "Keep this piece", func() -> void:
		p.set_gear_kept(item, not GearCare.kept(item))
		open_item_panel(item, Vector2(-1, -1), tab), UITheme.GOLD_BRIGHT)

	var tabrow := HBoxContainer.new()
	tabrow.add_theme_constant_override("separation", 10)
	vbox.add_child(tabrow)
	var slots: int = item.get("gem_slots", 0)
	var gems_n: int = item.get("gems", []).size()
	for spec in [["info", "Info"], ["gems", "Gems %d/%d" % [gems_n, slots]], ["reforge", "Reforge"]]:
		var tid: String = spec[0]
		_btn(tabrow, "  %s  " % spec[1], func() -> void: open_item_panel(item, Vector2(-1, -1), tid),
			Color(0.95, 0.85, 0.5) if tab == tid else Color(0.6, 0.6, 0.6))

	var is_equipped: bool = is_same(p.equipment.get(String(item.get("slot", ""))), item)
	if is_equipped:
		var slot_id: String = String(item["slot"])
		var refusal := _lbl(vbox, "Bag full. Free a slot before unequipping this piece.", 14, Color(1, 0.7, 0.5))
		refusal.custom_minimum_size.x = 440
		refusal.visible = p.bag_used() >= p.bag_capacity()
		var unequip_cb := func() -> void:
			if not is_same(p.equipment.get(slot_id), item):
				refusal.text = "This piece is no longer equipped."
				refusal.show()
				return
			if game.local_player.unequip(slot_id):
				inventory_notice = "Moved " + Items.title(item) + " to your bag."
				open_inventory()
			else:
				refusal.show()
		_btn(vbox, "  ⇩  Unequip  (move to bag)  ", unequip_cb, Color(1.0, 0.8, 0.5), not refusal.visible)

	# Long tab content scrolls within the popover cap.
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
	var d := _lbl(body, Items.describe(item), 13, Color(Items.GRADE_COLOR[item["grade"]], 0.9))
	d.custom_minimum_size = Vector2(440, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Generic gear deliberately has no signature passive.
	if not item.has("passive") and String(item.get("slot", "")) in Items.SLOTS:
		var np := _lbl(body, "No signature passive — named uniques (rare drops, Act 2+) carry those.",
			12, Color(0.55, 0.55, 0.6))
		np.custom_minimum_size = Vector2(440, 0)
		np.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Named gear uniques contribute to their profile's 2/4/6 set tiers.
	var set_prof := Items.set_profile_of(item, String(item.get("cls", "")))
	if set_prof != "" and String(item.get("cls", "")) == p.cls:
		var set_cls := String(item["cls"])
		var worn_n: int = p.uniq_set_n(set_prof)
		_lbl(body, "SET: %s   (%d/6 pieces worn)" % [Items.uniq_set_name(set_cls, set_prof), worn_n],
			15, Color(1.0, 0.85, 0.4))
		for tier_n in [2, 4, 6]:
			var rec := Balance.uniq_set(set_cls, set_prof, "s%d" % int(tier_n))
			if rec.is_empty():
				continue
			var live: bool = worn_n >= int(tier_n)
			_lbl(body, "   %dpc %s  —  %s" % [int(tier_n), "✓ ACTIVE" if live else "inactive",
				Items.set_tier_text(rec)], 13, Color(0.6, 1.0, 0.6) if live else Color(0.6, 0.62, 0.68))


## Gems tab: socket targets and insert-from-bag list.
func _item_gems_tab(body: VBoxContainer, item: Dictionary) -> void:
	var p: Player = game.local_player
	# Sockets remain visible away from the Lapidary, with an explicit refusal.
	if game.chapter_id != "capital":
		_lbl(body, "THE LAPIDARY'S BENCHES", 16, Color(0.95, 0.85, 0.5))
		_lbl(body, "Socketing and unsocketing happen at the Master Lapidary on the Crownfall plaza.\nTravel there from the pause menu (⌂).", 13, Color(0.7, 0.72, 0.78))
		var srow0 := HBoxContainer.new()
		srow0.add_theme_constant_override("separation", 6)
		body.add_child(srow0)
		_socket_row(srow0, item, func() -> void: open_item_panel(item, Vector2(-1, -1), "gems"))
		return
	var slots: int = item.get("gem_slots", 0)
	var gems: Array = item.get("gems", [])
	if slots == 0:
		_lbl(body, "This item has no sockets — only C-grade gear and above can hold gems.", 13, Color(0.55, 0.55, 0.6))
		return
	_lbl(body, "The Lapidary counts you a %s." % game.favor_tier_name("lapidary"),
		12, Color(0.75, 0.95, 0.7))
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
	var slg := _lbl(srow, "◇ regular · ★ special\nselect a gem for its card · drag it out to unsocket", 11, Color(0.55, 0.58, 0.66))
	slg.custom_minimum_size = Vector2(200, 0)
	slg.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if slots > gems.size():
		if p.gem_bag.is_empty():
			_lbl(body, "No gems in your bag to socket (they drop from chests and elites).", 12, Color(0.5, 0.5, 0.55))
		else:
			_lbl(body, "FROM YOUR BAG — select a gem to socket it", 14, Color(0.95, 0.85, 0.5))
			# The gems as they look in the bag (2026-08-15: tiles, not text
			# rows). A gem this piece can't take stays visible but dimmed, its
			# reason on hover — refusals never leave the panel.
			var groups := _gem_groups()
			var igrid := GridContainer.new()
			igrid.columns = 8
			igrid.add_theme_constant_override("h_separation", 5)
			igrid.add_theme_constant_override("v_separation", 5)
			body.add_child(igrid)
			for key in _sorted_gem_keys(groups):
				var group: Dictionary = groups[key]
				var g2: Dictionary = group["gem"]
				var count2: int = int(group["count"])
				var err := game.local_player.gem_socket_error(item, g2)
				var ins_cb := func() -> void:
					if game.local_player.embed_gem_into(item, g2):
						open_item_panel(item, Vector2(-1, -1), "gems")
				var tile := _bag_slot(igrid, Art.gem_icon(Items.gem_color(g2), int(g2["lvl"])),
					("x%d" % count2) if count2 > 1 else "", Items.gem_color(g2), ins_cb if err == "" else Callable())
				if err == "":
					tile.tooltip_text = "%s  x%d\nSocket into %s" % [Items.gem_title(g2), count2, Items.title(item)]
				else:
					tile.tooltip_text = "%s  x%d\n%s" % [Items.gem_title(g2), count2, err]
					tile.modulate = Color(0.45, 0.45, 0.5)
					tile.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN


## Reforge tab: Crownfall smithing actions and visible favor discounts.
func _item_reforge_tab(body: VBoxContainer, item: Dictionary) -> void:
	var p: Player = game.local_player
	if game.chapter_id != "capital":
		_lbl(body, "THE ASHFIRE FORGE", 16, Color(0.95, 0.85, 0.5))
		_lbl(body, "Reforging is bench work — Smith Petra handles it at the Crownfall plaza.\nTravel there from the pause menu (⌂).", 13, Color(0.7, 0.72, 0.78))
		return
	var petra_mult: float = game.favor_price_mult("petra")
	_lbl(body, "PETRA'S BENCH (spend gold)", 16, Color(0.95, 0.85, 0.5))
	_lbl(body, "Petra counts you a %s%s" % [game.favor_tier_name("petra"),
		"" if petra_mult >= 1.0 else " — her rate is %d%% kinder for you." % int(round((1.0 - petra_mult) * 100.0))],
		12, Color(0.75, 0.95, 0.7))
	if _reforge_msg != "":
		_lbl(body, _reforge_msg, 12, _reforge_msg_color)
		_reforge_msg = ""
	# Smithing spend builds favor and progresses the intro deed.
	var petra_spend := func(amount: int) -> void:
		game.favor_spend("petra", amount)
		if game.get_flag("cap_q_forge_on", false) and not game.get_flag("cap_q_forge_done", false):
			game.set_flag("cap_q_forge_done")
	var subs2: Dictionary = item.get("subs", {})
	var rcls: String = String(item.get("cls", p.cls))
	if subs2.is_empty() and not Items.can_add_socket(item) and item.get("main", {}).is_empty():
		_lbl(body, "Nothing to reforge — no affixes to reroll or sockets to add.",
			12, Color(0.55, 0.55, 0.6))
	# Quench rerolls a stat's band and never regresses it.
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
		var qcost := int(ceil(Items.quench_cost(item, qs) * petra_mult))
		var at_max: bool = cur >= float(band[1]) - 0.01
		var q_cb := func() -> void:
			if game.local_player.gold >= qcost:
				game.local_player.gold -= qcost
				petra_spend.call(qcost)
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
	# Reforge one selected substat slot.
	var acost := int(ceil(Items.reforge_cost(item, "affix") * petra_mult))
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
				petra_spend.call(acost)
				var new_stat := Items.reforge_affix(item, rs, rcls, game.loot_rng)
				if new_stat != "":
					_reforge_msg = "Reforged %s → %s" % [Items.STAT_LABEL.get(rs, rs), Items.STAT_LABEL.get(new_stat, new_stat)]
					_reforge_msg_color = Color(1.0, 0.85, 0.5)
					game.sfx("equip")
				game.local_player.recalc()
				open_item_panel(item, Vector2(-1, -1), "reforge")
		_btn(body, "   Reforge %s → ?  —  %d gold" % [Items.STAT_LABEL.get(rs, rs), acost], rf_cb,
			Color(0.9, 0.82, 0.7) if p.gold >= acost else Color(0.5, 0.5, 0.55))
	# Transmute redirects the main-stat budget without changing its roll.
	if Items.can_transmute_main(item):
		var tcost := int(ceil(Items.transmute_cost(item) * petra_mult))
		var main_stat := String(item["main"].keys()[0])
		_lbl(body, "Transmute — convert the main attribute (keeps its roll):", 12, Color(0.85, 0.72, 1.0))
		for target in Items.transmute_targets(item):
			var tgt := String(target)
			var t_cb := func() -> void:
				if game.local_player.gold >= tcost:
					game.local_player.gold -= tcost
					petra_spend.call(tcost)
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
	# Socket cutting is a one-time, tier-scaled action.
	if Items.can_add_socket(item):
		# Socket-cutting is the LAPIDARY's trade — her favor rates this one.
		var ccost := int(ceil(Items.reforge_cost(item, "socket") * game.favor_price_mult("lapidary")))
		var sock_cb := func() -> void:
			if game.local_player.gold >= ccost:
				game.local_player.gold -= ccost
				game.favor_spend("lapidary", ccost)
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
		b.tooltip_text = "%s — in the %s\nSelect for its card · drag to the bag to unsocket." % [Items.gem_title(g), kind_txt]
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
	_open_detail_popover(Art.gem_codex_icon(Items.gem_color(g), int(g["lvl"])), Items.gem_title(g),
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
	var vbox := _open("%s — Skills & Loadouts" % Classes.CLASSES[p.cls]["name"], 1180, 660, true)
	current = "skills"

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_btn(tabs, "  TALENTS  ·  %d pts  " % p.skill_points, func() -> void: open_skills("talents"),
		Color(0.95, 0.85, 0.5) if tab == "talents" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  ABILITY ASSIGNMENTS  ", func() -> void: open_skills("abilities"),
		Color(0.95, 0.85, 0.5) if tab == "abilities" else Color(0.6, 0.6, 0.6))
	_btn(tabs, "  ATTRIBUTES  ·  %d pts  " % p.unspent_attr, func() -> void: open_skills("attributes"),
		Color(0.95, 0.85, 0.5) if tab == "attributes" else Color(0.6, 0.6, 0.6))

	if game.touch_mode:
		for button in tabs.get_children():
			button.custom_minimum_size = Vector2.ONE * Balance.SKILLS_TOUCH_TARGET

	if tab == "attributes":
		_build_attributes_tab(vbox, p)
	elif tab == "abilities":
		_build_ability_assignments_tab(vbox, p)
	else:
		_build_talent_loadouts_tab(vbox, p)


func _build_talent_loadouts_tab(vbox: VBoxContainer, p: Player) -> void:
	p.sync_active_talent_loadout()
	var profile_head := HBoxContainer.new()
	profile_head.add_theme_constant_override("separation", 8)
	vbox.add_child(profile_head)
	var section := UITheme.header(_lbl(profile_head, "TALENT LOADOUTS", 16, UITheme.GOLD_BRIGHT))
	section.custom_minimum_size = Vector2(168, 0)
	for i in Player.TALENT_LOADOUT_COUNT:
		var loadout_index: int = i
		var profile: Dictionary = p.talent_loadouts[i]
		var selected: bool = i == p.active_talent_loadout
		var tab_text := ("◆  " if selected else "") + String(profile["name"])
		var profile_button := _btn(profile_head, tab_text, func() -> void:
			game.local_player.switch_talent_loadout(loadout_index)
			_talent_renaming = false
			open_skills("talents"),
			UITheme.GOLD_BRIGHT if selected else Color(0.68, 0.68, 0.74))
		profile_button.custom_minimum_size = Vector2(142, 34)
		_profile_tab_style(profile_button, selected)

	if _talent_renaming:
		var name_edit := LineEdit.new()
		name_edit.text = String(p.talent_loadouts[p.active_talent_loadout]["name"])
		name_edit.max_length = 14
		name_edit.placeholder_text = "Loadout name"
		name_edit.custom_minimum_size = Vector2(150, 34)
		profile_head.add_child(name_edit)
		var commit_name := func() -> void:
			game.local_player.rename_talent_loadout(
				game.local_player.active_talent_loadout, name_edit.text)
			_talent_renaming = false
			open_skills("talents")
		name_edit.text_submitted.connect(func(_submitted: String) -> void: commit_name.call())
		_btn(profile_head, "SAVE", commit_name, Color(0.55, 1.0, 0.62))
		name_edit.call_deferred("grab_focus")
	else:
		_btn(profile_head, "✎  RENAME", func() -> void:
			_talent_renaming = true
			open_skills("talents"), Color(0.78, 0.8, 0.88))

	_lbl(vbox, "Each page remembers its own build. Switching pages redistributes the same %d-point character budget; it never creates extra points." % p.talent_point_budget(),
		12, Color(0.62, 0.64, 0.72))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	list.add_child(head)
	var pad := _lbl(head, "TIER", 12, Color(0.5, 0.5, 0.56))
	pad.custom_minimum_size = Vector2(112, 0)
	for theme in Classes.THEMES[p.cls]:
		var h := UITheme.header(_lbl(head, theme["name"].to_upper(), 14, theme["color"]))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.custom_minimum_size = Vector2(326, 0)

	for r in Skills.TREES[p.cls].size():
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 10)
		list.add_child(row_box)
		var unlocked: bool = Skills.row_open(p.cls, r, p.tree_points, p.level)
		var spent := Skills.points_in_row(p.cls, r, p.tree_points)
		var row_l := _lbl(row_box, "%s\n%s\n%d / %d" % [
			"STARTER" if r == 0 else "LEVEL %d" % Skills.ROW_LEVELS[r],
			"UNLOCKED" if unlocked else "LOCKED\n(or fill row above)",
			spent, Skills.MAX_PER_ROW], 12,
			Color(0.95, 0.85, 0.5) if unlocked else Color(0.4, 0.4, 0.45))
		row_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_l.custom_minimum_size = Vector2(112, 82)
		var col_idx := 0
		for cell in Skills.TREES[p.cls][r]:
			var cd: Dictionary = cell
			var theme_col: Color = Classes.THEMES[p.cls][col_idx]["color"]
			col_idx += 1
			var pts: int = p.tree_points.get(cd["id"], 0)
			var can: bool = p.skill_points > 0 and Skills.can_add(
				p.cls, cd["id"], p.tree_points, p.level)
			var color := Color(0.58, 1.0, 0.62) if pts > 0 else (
				Color(0.93, 0.93, 0.97) if can else Color(0.48, 0.48, 0.52))
			var add_cb := func() -> void:
				if game.local_player.add_tree_point(cd["id"]):
					open_skills("talents")
			var fallback := Art.glyph_tex(_cell_glyph(cd),
				theme_col if unlocked else Color(0.4, 0.4, 0.45))
			var b := _btn(row_box, "%s    %d/%d\n%s" % [
				cd["name"], pts, Skills.cell_max(cd), cd["desc"]],
				add_cb, color, can, _talent_icon(String(cd["id"]), fallback))
			b.custom_minimum_size = Vector2(326, 82)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_constant_override("icon_max_width", 64)
			_talent_card_style(b, theme_col, pts > 0, unlocked)
	_hint(vbox, "ESC / %s to close — first row is always open. Later rows open at their level or when the row above is full." % menu_key("skills"))


const ABILITY_CARD := 72.0  # a square the variant icon FILLS (icons are 64px art)


func _build_ability_assignments_tab(vbox: VBoxContainer, p: Player) -> void:
	var next_note := "" if p.themes_known >= 3 else " — next unlocks at Lv %d" % Classes.THEME_LEVELS[mini(p.themes_known, 2)]
	UITheme.header(_lbl(vbox, "ABILITY ASSIGNMENTS", 17, UITheme.GOLD_BRIGHT))
	_lbl(vbox, "Select an option to inspect it, then use ASSIGN. Every option keeps the base ability and changes its behavior. %d/3 specializations unlocked%s." % [
		p.themes_known, next_note], 12, Color(0.62, 0.64, 0.72))

	var slots := ["a1", "a2", "a3", "ult"]
	if not slots.has(_ability_preview_slot):
		_ability_preview_slot = "a1"
		_ability_preview_theme = String(p.ability_theme.get("a1", ""))
	var preview_theme_valid := _ability_preview_theme == ""
	for preview_theme in Classes.THEMES[p.cls]:
		if String(preview_theme["id"]) == _ability_preview_theme:
			preview_theme_valid = true
			break
	if not preview_theme_valid:
		_ability_preview_theme = String(p.ability_theme.get(_ability_preview_slot, ""))
	# 2026-08-16: matrix LEFT (compact option cards, one row per ability),
	# the inspected variant's full readout RIGHT (icon, text, numbers, ASSIGN)
	# — the old layout stacked a wide detail strip over a grid of near-empty
	# 220x78 cards and left a third of the panel blank.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	vbox.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160 + 4 * (ABILITY_CARD + 6), 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	left.add_child(header)
	var ability_head := UITheme.header(_lbl(header, "HOTBAR ABILITY", 11, Color(0.52, 0.52, 0.58)))
	ability_head.custom_minimum_size = Vector2(160, 0)
	var base_head := UITheme.header(_lbl(header, "BASE", 11, Color(0.78, 0.78, 0.84)))
	base_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_head.custom_minimum_size = Vector2(ABILITY_CARD, 0)
	base_head.autowrap_mode = TextServer.AUTOWRAP_OFF
	for theme in Classes.THEMES[p.cls]:
		var theme_head := UITheme.header(_lbl(header, theme["name"].to_upper(), 11, theme["color"]))
		theme_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		theme_head.custom_minimum_size = Vector2(ABILITY_CARD, 0)
		theme_head.autowrap_mode = TextServer.AUTOWRAP_OFF
		theme_head.clip_text = true

	var slot_labels := {"a1": "ABILITY 1", "a2": "ABILITY 2", "a3": "ABILITY 3", "ult": "ULTIMATE"}
	for slot in slots:
		var s: String = slot
		var ab: Dictionary = Classes.ability(p.cls, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		left.add_child(row)
		var name_col := VBoxContainer.new()
		name_col.custom_minimum_size = Vector2(160, 0)
		name_col.add_theme_constant_override("separation", 0)
		name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_col)
		var sl := _lbl(name_col, String(slot_labels[s]), 10, Color(0.52, 0.52, 0.58))
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var an := _lbl(name_col, String(ab["name"]), 14, Color(0.88, 0.86, 0.78))
		an.autowrap_mode = TextServer.AUTOWRAP_OFF

		var options: Array = [{"id": "", "name": "Base", "color": Color(0.78, 0.78, 0.84)}]
		options.append_array(Classes.THEMES[p.cls])
		for option_idx in options.size():
			var option: Dictionary = options[option_idx]
			var theme_id := String(option["id"])
			var selected: bool = String(p.ability_theme.get(s, "")) == theme_id
			var previewed: bool = _ability_preview_slot == s \
				and _ability_preview_theme == theme_id
			var unlocked: bool = option_idx == 0 or option_idx - 1 < p.themes_known
			var option_color: Color = option["color"] if unlocked else Color(0.38, 0.38, 0.43)
			var inspect_cb := func() -> void:
				_ability_preview_slot = s
				_ability_preview_theme = theme_id
				open_skills("abilities")
			# The column header names the spec — the card is the icon, CENTRED,
			# with its state as a corner badge: ✓ assigned · ◈ inspecting · 🔒
			# unopened. (An icon beside an empty text run sat flush left and
			# left the card's right half blank — owner 2026-08-16.)
			# A square card the icon FILLS — the border is the whole state
			# (thick + tinted = assigned, pale = inspecting, dim = locked); no
			# glyphs, nothing beside the icon (owner 2026-08-16).
			var option_button := _btn(row, "", inspect_cb, option_color, true,
				Art.ability_icon(p.cls, s, option_color, theme_id))
			option_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			option_button.expand_icon = true
			option_button.custom_minimum_size = Vector2(ABILITY_CARD, ABILITY_CARD)
			option_button.tooltip_text = "%s · %s%s" % [String(ab["name"]), String(option["name"]),
				"" if unlocked else "  (unlocks at Lv %d)" % Classes.THEME_LEVELS[option_idx - 1]]
			_assignment_card_style(option_button, option_color, selected, previewed)

	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	left.add_child(arow)
	var al := UITheme.header(_lbl(arow, "ASSIGN ALL", 11, Color(0.7, 0.72, 0.78)))
	al.custom_minimum_size = Vector2(160, 0)
	var base_all := _btn(arow, "BASE", func() -> void:
		game.local_player.set_all_themes("")
		open_skills("abilities"), Color(0.85, 0.85, 0.9))
	base_all.custom_minimum_size = Vector2(ABILITY_CARD, 0)
	base_all.alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_all.add_theme_font_size_override("font_size", 12)
	for i2 in Classes.THEMES[p.cls].size():
		var th: Dictionary = Classes.THEMES[p.cls][i2]
		var tid: String = th["id"]
		var t_unlocked: bool = i2 < p.themes_known
		var tb := _btn(arow, String(th["name"]), func() -> void:
			game.local_player.set_all_themes(tid)
			open_skills("abilities"),
			th["color"] if t_unlocked else Color(0.4, 0.4, 0.45), t_unlocked)
		tb.custom_minimum_size = Vector2(ABILITY_CARD, 0)
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_theme_font_size_override("font_size", 12)
		tb.clip_text = true
	var legend := _lbl(left, "Bright frame = assigned · pale frame = inspecting · dim = locked. Specializations open at Lv %d / %d / %d; every variant keeps the base ability and changes one facet of it." % [
		Classes.THEME_LEVELS[0], Classes.THEME_LEVELS[1], Classes.THEME_LEVELS[2]], 11, Color(0.52, 0.55, 0.65))
	legend.custom_minimum_size = Vector2(160 + 4 * (ABILITY_CARD + 6), 0)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)

	_build_ability_detail(body, p)
	_hint(vbox, "Select a card to inspect it, then ASSIGN")


## The inspected variant, in full: icon · ABILITY · SPEC · what it changes ·
## the numbers · what the base does · ASSIGN (or ASSIGNED / unlock level).
func _build_ability_detail(parent: Control, p: Player) -> void:
	var ab: Dictionary = Classes.ability(p.cls, _ability_preview_slot)
	var theme := Classes.theme_by_id(p.cls, _ability_preview_theme)
	var theme_name := String(theme.get("name", "Base"))
	var theme_color: Color = theme.get("color", Color(0.78, 0.78, 0.84))
	var theme_index := -1
	for i in Classes.THEMES[p.cls].size():
		if String(Classes.THEMES[p.cls][i]["id"]) == _ability_preview_theme:
			theme_index = i
			break
	var unlocked := _ability_preview_theme == "" or theme_index < p.themes_known
	var already_assigned := String(
		p.ability_theme.get(_ability_preview_slot, "")) == _ability_preview_theme

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(
		theme_color.r * 0.1, theme_color.g * 0.1, theme_color.b * 0.1, 0.94)
	panel_style.border_color = Color(theme_color, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var text_w := 1124.0 - (160.0 + 4.0 * (ABILITY_CARD + 6.0)) - 20.0 - 32.0  # the column the matrix leaves

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Art.ability_icon(p.cls, _ability_preview_slot, theme_color, _ability_preview_theme)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	var t1 := _lbl(titles, String(ab["name"]).to_upper(), 16, theme_color)
	t1.autowrap_mode = TextServer.AUTOWRAP_OFF
	UITheme.header(t1)
	var t2 := _lbl(titles, (theme_name.to_upper() + " variant") if _ability_preview_theme != "" else "BASE — as trained", 12,
		Color(0.72, 0.74, 0.82))
	t2.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not unlocked:
		var lk := _lbl(titles, "Unlocks at Lv %d" % Classes.THEME_LEVELS[theme_index], 11, Color(1.0, 0.7, 0.4))
		lk.autowrap_mode = TextServer.AUTOWRAP_OFF

	if _ability_preview_theme != "":
		var what := _lbl(col, Classes.variant_desc(p.cls, _ability_preview_slot, _ability_preview_theme), 13, Color(0.9, 0.9, 0.95))
		what.custom_minimum_size = Vector2(text_w, 0)
		var nums := _lbl(col, Classes.fx_text(Classes.ability_fx(p.cls, _ability_preview_slot, _ability_preview_theme), p.cls), 12, theme_color)
		nums.custom_minimum_size = Vector2(text_w, 0)
	var base_head := _lbl(col, "THE BASE ABILITY", 11, Color(0.52, 0.55, 0.65))
	base_head.autowrap_mode = TextServer.AUTOWRAP_OFF
	var base_txt := String(ab["desc"])
	var scaling: String = Classes.ability_scaling(p.cls, _ability_preview_slot)
	if scaling != "":
		base_txt += "\n[ %s ]" % scaling
	var riders: String = Classes.ability_riders(p.cls, _ability_preview_slot)
	if riders != "":
		base_txt += "\n[ %s ]" % riders
	var base_l := _lbl(col, base_txt, 12, Color(0.72, 0.74, 0.82))
	base_l.custom_minimum_size = Vector2(text_w, 0)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sp)
	var assign := _btn(col, "  ✓  ASSIGNED  " if already_assigned else (
		"  ASSIGN to %s  " % String(ab["name"]) if unlocked else "  LOCKED — Lv %d  " % Classes.THEME_LEVELS[maxi(theme_index, 0)]), func() -> void:
			game.local_player.set_ability_theme(_ability_preview_slot, _ability_preview_theme)
			open_skills("abilities"),
		theme_color if unlocked else Color(0.4, 0.4, 0.45),
		unlocked and not already_assigned)
	assign.custom_minimum_size = Vector2(0, 46)
	assign.alignment = HORIZONTAL_ALIGNMENT_CENTER
	assign.add_theme_font_size_override("font_size", 16)


func _profile_tab_style(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.18, 0.08, 0.92) if selected else Color(0.10, 0.09, 0.14, 0.72)
	normal.border_color = UITheme.GOLD_BRIGHT if selected else Color(UITheme.GOLD_DIM, 0.55)
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = UITheme.GOLD_BRIGHT
	hover.bg_color = Color(0.25, 0.2, 0.12, 0.95)
	button.add_theme_stylebox_override("hover", hover)


func _talent_icon(cell_id: String, fallback: Texture2D = null) -> Texture2D:
	var path := "res://assets/icons/talent_%s.png" % cell_id
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	return fallback


func _talent_card_style(button: Button, color: Color, invested: bool, unlocked: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.9)
	normal.border_color = Color(color, 0.95 if invested else 0.38)
	normal.set_border_width_all(2 if invested else 1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.96)
	hover.border_color = color
	button.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.07, 0.07, 0.09, 0.72)
	disabled.border_color = Color(color, 0.5 if invested else 0.2)
	if not unlocked:
		disabled.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	button.add_theme_stylebox_override("disabled", disabled)


func _assignment_card_style(button: Button, color: Color, selected: bool,
		previewed := false) -> void:
	var normal := StyleBoxFlat.new()
	# The frame IS the state: assigned = thick frame + tinted fill; inspecting
	# = pale frame; otherwise a faint outline. Icon fills the rest (2px inset).
	normal.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.95) if selected \
		else Color(color.r * 0.10, color.g * 0.10, color.b * 0.10, 0.9)
	normal.border_color = color if selected else (
		Color(0.95, 0.92, 0.75) if previewed else Color(color, 0.32))
	normal.set_border_width_all(3 if selected else (2 if previewed else 1))
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(2)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.96)
	hover.border_color = color
	button.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.05, 0.05, 0.07, 0.76)
	disabled.border_color = Color(0.26, 0.26, 0.3, 0.5)
	button.add_theme_stylebox_override("disabled", disabled)


## Attribute allocation: +1 point per level. The four attributes
## convert at CLASS scaling ratios; the substat rows convert 1:1 for
## every class (combo is deliberately not purchasable).
## Attributes = the ALLOCATOR (left: one card per attribute / substat with
## +1 · +5) beside THE character sheet (right: the same component the
## inventory Stats tab shows). Spend a point and the numbers it moved pulse
## green on the sheet — 2026-08-16, replacing the +1/+5 rows over a text blob.
func _build_attributes_tab(vbox: VBoxContainer, p: Player) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vbox.add_child(head)
	var unspent := _lbl(head, ("%d unspent" % p.unspent_attr) if p.unspent_attr > 0 else "All spent", 22,
		Color(0.5, 1.0, 0.5) if p.unspent_attr > 0 else Color(0.6, 0.6, 0.65))
	UITheme.title(unspent, 22)
	unspent.custom_minimum_size = Vector2(190, 0)
	var intro := _lbl(head, "Every level grants 1 attribute point. Attributes convert by class — ★ marks the one %s scales best with — or pour points straight into a substat. Select any stat on the sheet to learn what it does." % [
		Classes.CLASSES[p.cls]["name"]], 12, Color(0.6, 0.62, 0.68))
	intro.custom_minimum_size = Vector2(880, 0)
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	# --- left: the allocator ---
	var lscroll := ScrollContainer.new()
	lscroll.name = "AttributeAllocationScroll"
	lscroll.custom_minimum_size = Vector2(620, 0)
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	lscroll.add_child(list)
	UITheme.header(_lbl(list, "ATTRIBUTES", 14, Color(0.95, 0.85, 0.5)))
	for attr in Classes.ATTR_NAMES:
		var a: String = attr
		var is_primary: bool = Classes.CLASSES[p.cls]["primary"] == a
		_attr_card(list, p, a, is_primary,
			Color(0.95, 0.85, 0.5) if is_primary else Color(0.85, 0.85, 0.9),
			Classes.attr_text(p.cls, a), p.attr_total(a))
	UITheme.header(_lbl(list, "SUBSTATS", 14, Color(0.95, 0.85, 0.5)))
	for attr in Classes.SUBSTAT_NAMES:
		var a: String = attr
		_attr_card(list, p, a, false, Color(0.75, 0.8, 0.92), Classes.substat_text(a), -1)
	# --- right: the sheet ---
	var rscroll := ScrollContainer.new()
	rscroll.name = "AttributeSheetScroll"
	rscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(rscroll)
	var smargin := MarginContainer.new()
	smargin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smargin.add_theme_constant_override("margin_right", 12)  # clear of the scrollbar
	rscroll.add_child(smargin)
	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 5)
	smargin.add_child(sheet)
	_stat_sheet_build(sheet, _stat_sheet_data(p), true)
	_hint(vbox, "ESC / %s to close" % menu_key("skills"))


## Spending rebuilds the sheet and highlights changed values. Keep both reading
## positions, but never restore into a different menu opened during layout.
func _refresh_attributes() -> void:
	var offsets: Dictionary = {}
	for id in ["AttributeAllocationScroll", "AttributeSheetScroll"]:
		var scroll := root.find_child(id, true, false) as ScrollContainer
		if scroll != null:
			offsets[id] = scroll.scroll_vertical
	open_skills("attributes")
	var shell := root
	await get_tree().process_frame
	if not is_instance_valid(shell) or root != shell:
		return
	for id in offsets:
		var scroll := shell.find_child(id, true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = int(offsets[id])


## One allocation card: name · points spent (· total for the four
## attributes) · what a point buys · +1 / +5. `total` < 0 = no total shown.
func _attr_card(list: VBoxContainer, p: Player, a: String, primary: bool, color: Color,
		desc_text: String, total: int) -> void:
	var card := UITheme.card(list, color if primary else Color(0.42, 0.45, 0.55), 8.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var name_col := VBoxContainer.new()
	name_col.custom_minimum_size = Vector2(150, 0)
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_col)
	var nm := _lbl(name_col, "%s%s" % [a, "  ★" if primary else ""], 17, color)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	var pts_txt := "%d point%s" % [int(p.attr_points[a]), "" if int(p.attr_points[a]) == 1 else "s"]
	if total >= 0:
		pts_txt += "  ·  %d total" % total
	var pts := _lbl(name_col, pts_txt, 11, Color(0.6, 0.63, 0.72))
	pts.autowrap_mode = TextServer.AUTOWRAP_OFF
	var desc := _lbl(row, desc_text, 12, Color(0.72, 0.74, 0.82))
	desc.custom_minimum_size = Vector2(300, 0)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var can: bool = p.unspent_attr > 0
	var spend := func(n: int) -> void:
		_stat_flash = _stat_values(game.local_player)  # remember the sheet, then move it
		game.local_player.add_attr_points(a, n)
		_refresh_attributes()
	var b1 := _btn(row, " +1 ", func() -> void: spend.call(1), Color(0.5, 1.0, 0.5), can)
	b1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b5 := _btn(row, " +5 ", func() -> void: spend.call(5), Color(0.5, 1.0, 0.5), can)  # add_attr_points clamps to what's unspent
	b5.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if game.touch_mode:
		for button in [b1, b5]:
			button.custom_minimum_size = Vector2.ONE * Balance.SKILLS_TOUCH_TARGET
	# (The ★ beside the name is the whole "your class scales best here" — no caption.)


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
			Art.ability_icon(p.cls, slot, tcolor, String(theme["id"])))
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
	var at_capital: bool = game.chapter_id == "capital"
	var price_ch := game.shop_chapter()
	if at_capital:
	# The Crown Bazaar shelf persists until the next trusted dawn.
		var today := game.daily_day_index()
		if game.capital_shop_day != today:
			game.capital_shop_day = today
			var crng := RandomNumberGenerator.new()
			crng.randomize()
			game.capital_stock = []
			for i in int(Balance.SHOP_STOCK_BY_TIER.get(Balance.CAPITAL_SHOP_TIER, 5)):
				var sg := Items.roll_shop_grade(price_ch, crng, game.loot_cap())
				game.capital_stock.append(Items.roll_gear_of_grade(sg, crng, game.local_player.cls, Story.act_of(price_ch)))
			var cact: int = Story.act_of(price_ch)
			var ccount: Array = Balance.SHOP_BAG_COUNT.get(cact, [1, 1])
			game.capital_bags = []
			for i in crng.randi_range(int(ccount[0]), int(ccount[1])):
				game.capital_bags.append(Items.make_bag(Balance.roll_bag_grade(price_ch, crng)))
		# Plaza and saved bazaar stock share the same array.
		game.shop_stock[zone] = game.capital_stock
		game.shop_bags[zone] = game.capital_bags
	# Road stock persists until bought out.
	if not game.shop_stock.has(zone):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var tier: String = String(game.zones[zone].get("shop_tier",
			["wood", "silver", "silver", "gold"][clampi(zone, 0, 3)]))
		var stock: Array = []
		var stock_n: int = int(Balance.SHOP_STOCK_BY_TIER.get(tier, 3))
		for i in stock_n:
			var sg := Items.roll_shop_grade(game.chapter_id, rng, game.loot_cap())
			stock.append(Items.roll_gear_of_grade(sg, rng, game.local_player.cls, Story.act_of(game.chapter_id)))
		game.shop_stock[zone] = stock
	# Bag stock uses the act's rollable tiers.
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
	var vbox := _open("The Crown Bazaar" if at_capital else "Merchant", 1120, 600, true)
	current = "shop"
	preload("res://scripts/ui/shop_prices.gd").watch(self, zone)
	# Merchant band (visual-review "item fantasy" pass, 2026-08-21): the trader
	# himself — waist-up crop of the painted merchant body — fronts the shop,
	# his resonance-voiced line reads as SPEECH beside him, and your gold is a
	# coin chip instead of a number buried in the title.
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 14)
	vbox.add_child(band)
	# Face crop of the painted splash (2026-08-21) — crisp at band size; the
	# same splash_merchant.png auto-lights the merchant in dialogue for free.
	var mtex: Texture2D = Art.tex("splash_merchant")
	if mtex != null:
		var pframe := PanelContainer.new()
		var pfsb := StyleBoxFlat.new()
		pfsb.bg_color = Color(0.07, 0.06, 0.05, 0.9)
		pfsb.border_color = Color(UITheme.BRONZE, 0.55)
		pfsb.set_border_width_all(1)
		pfsb.set_corner_radius_all(8)
		pfsb.set_content_margin_all(3)
		pframe.add_theme_stylebox_override("panel", pfsb)
		pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		band.add_child(pframe)
		var at := AtlasTexture.new()
		at.atlas = mtex
		at.region = Rect2(410, 30, 430, 430)   # face + scarf out of the 1254px splash
		var prect := TextureRect.new()
		prect.texture = at
		prect.custom_minimum_size = Vector2(78, 78)
		prect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pframe.add_child(prect)
	var bcol := VBoxContainer.new()
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bcol.add_theme_constant_override("separation", 3)
	band.add_child(bcol)
	match Story.res_band(p.resonance):
		"steady":
			_lbl(bcol, "\"For YOU? Fair rates, friend — the road speaks well of you.\"  (prices 10% kinder)", 15, Color(0.68, 0.9, 0.66))
		"tempted":
			_lbl(bcol, "\"Prices are... firm today. Nothing personal — the till gets nervous around your sort.\"  (prices 10% wary)", 15, Color(1.0, 0.7, 0.6))
		_:
			_lbl(bcol, "\"Ah, a customer! Dangerous roads make good business.\"", 15, Color(0.88, 0.82, 0.68))
	if at_capital:
		var left: int = maxi(0, (game.daily_day_index() + 1) * 86400 - game.trusted_now())
		_lbl(bcol, "Fresh stock at dawn — new shelf in %dh %02dm." % [left / 3600, (left % 3600) / 60],
			13, Color(0.85, 0.8, 0.55))
	elif preload("res://scripts/road_caravan.gd").supplied(game):
		_lbl(bcol, "Caravan supplied — equipment and supplies cost 20% less for this chapter's run.",
			13, Color(0.68, 0.9, 0.66))
	elif game.shop_markup(zone) > 1.0:
		# Road markup, named as trade talk in warm amber — not alarm red.
		_lbl(bcol, "Road stock costs +%d%% out here. The Crown Bazaar sells fair." %
			int(round((game.shop_markup(zone) - 1.0) * 100.0)), 13, Color(0.85, 0.72, 0.5))
	# Gold chip: the painterly coin + your purse, top-right of the band.
	var chip := PanelContainer.new()
	var chsb := StyleBoxFlat.new()
	chsb.bg_color = Color(0.10, 0.085, 0.06, 0.92)
	chsb.border_color = Color(UITheme.BRONZE, 0.4)
	chsb.set_border_width_all(1)
	chsb.set_corner_radius_all(14)
	chsb.content_margin_left = 12
	chsb.content_margin_right = 14
	chsb.content_margin_top = 5
	chsb.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", chsb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(chip)
	var chrow := HBoxContainer.new()
	chrow.add_theme_constant_override("separation", 7)
	chip.add_child(chrow)
	var cico := TextureRect.new()
	cico.texture = Art.tex("coin")
	cico.custom_minimum_size = Vector2(22, 22)
	cico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cico.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chrow.add_child(cico)
	var camt := _lbl(chrow, _fmt_gold(p.gold), 17, Color(0.96, 0.84, 0.44))
	camt.autowrap_mode = TextServer.AUTOWRAP_OFF   # HBox label-collapse trap
	camt.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Buy and Sell are separate full-width views.
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


## Shared laced-potion shelf for the capital fence and road smuggler.
func open_black_market(source := "fence") -> void:
	var p: Player = game.local_player
	var title := ("The Sable Court Fence — you have %d gold" if source == "fence"
		else "A Road Smuggler — you have %d gold") % p.gold
	var vbox := _open(title, 1120, 600, true)
	current = "black_market"
	if source == "fence":
		_lbl(vbox, "\"Under the counter, friend. Same kick as the Accord's finest, a third off the price. The rot in it? A rumour. Mostly.\"", 14, Color(0.78, 0.6, 0.66))
	else:
		_lbl(vbox, "\"Long way from a chartered shelf out here. I've the cheap bottles; you've the desperation. Fair trade.\"", 14, Color(0.78, 0.6, 0.66))
	_lbl(vbox, "Every laced bottle is cut with diluted blightwater — that's the discount, and that's the sting. No S here: legends can't be counterfeited.", 12, Color(0.62, 0.6, 0.66))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var buy := VBoxContainer.new()
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_constant_override("separation", 6)
	scroll.add_child(buy)
	_shop_shelf(buy, "Black Market  ·  laced, F→A", Color(0.78, 0.55, 0.62))
	var grid := _shop_grid(buy)
	# Reputation modifies the stored laced price; there is no road markup.
	var haggle: float = game.band_price_mult()
	for made_v in Items.black_market_stock():
		var made: Dictionary = made_v
		var bcost := int(ceil(float(made["price"]) * haggle))
		var buy_cb := func() -> void:
			if p.gold >= bcost:
				if p.add_consumable(made.duplicate(true)):
					p.gold -= bcost
					game.sfx("potion")
				else:
					game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
			open_black_market(source)
		_shop_card(grid, Art.consumable_icon(made), String(made["name"]),
			"%d gold   (%s)" % [bcost, made["desc"]],
			Items.GRADE_COLOR[made["grade"]], p.gold >= bcost, buy_cb)
	_hint(vbox)


## "12,450" — gold amounts read as money with thousands separators.
func _fmt_gold(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


## A shelf header: small-caps bronze label + a hairline rule running to the
## panel edge — a labelled shelf, not a dim "— Gear —" annotation (review P1).
func _shop_shelf(parent: Node, text: String, color := Color(0.85, 0.74, 0.48)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _lbl(row, text.to_upper(), 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF   # HBox label-collapse trap
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rule := ColorRect.new()
	rule.color = Color(color, 0.28)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)


## A two-column shelf grid.
func _shop_grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


## One item card in a shop grid. A STRUCTURED row — icon · (name + detail) ·
## price — so a shelf scans by column instead of reading like a stat spreadsheet
## (visual-review P1). The "N gold" token is auto-split out of `detail` (wherever
## the caller put it) and right-aligned in gold; it turns red when the player
## can't afford it. Clicks fall through the content layer to the button beneath.
func _shop_card(grid: GridContainer, icon: Texture2D, title: String, detail: String,
		color: Color, enabled: bool, cb: Callable) -> Button:
	# Pull the price into its own column so it stops hiding inside the stat line.
	var price_text := ""
	var affordable := true
	var re := RegEx.new()
	re.compile("([0-9][0-9,]*)\\s*gold\\b")
	var pm := re.search(detail)
	if pm != null:
		var num := int(pm.get_string(1).replace(",", ""))
		price_text = "%d g" % num
		if game != null and game.has_local_player() and not detail.begins_with("sell "):
			affordable = game.local_player.gold >= num
		detail = (detail.substr(0, pm.get_start()) + detail.substr(pm.get_end())).strip_edges()
		detail = detail.trim_prefix("—").trim_prefix("-").strip_edges()
		detail = detail.trim_suffix("—").trim_suffix("-").strip_edges()
		if detail == "()":
			detail = ""
	var b := Button.new()
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 60)
	# Content layer: laid out over the button, transparent to the mouse so the
	# whole card stays one click target.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if icon != null:
		# Icon rides in a dark inset SOCKET (the inventory-slot chrome) so even
		# a dark F-grade icon reads against the card's warmer surface.
		var well := PanelContainer.new()
		var wsb := StyleBoxFlat.new()
		wsb.bg_color = Color(0.045, 0.045, 0.055, 0.95)
		wsb.border_color = Color(UITheme.BRONZE, 0.3)
		wsb.set_border_width_all(1)
		wsb.set_corner_radius_all(5)
		wsb.set_content_margin_all(3)
		well.add_theme_stylebox_override("panel", wsb)
		well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(well)
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(42, 42)
		# One icon size per shelf whatever the source resolution (a 128px potion
		# bottle and a 32px gear icon both fit the box) — IGNORE_SIZE makes the
		# rect honour custom_minimum_size instead of the texture's native size.
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vb)
	var nm := _lbl(vb, title, 15, color if enabled else Color(color, 0.5))
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if detail != "":
		var dt := _lbl(vb, detail, 12, Color(0.74, 0.76, 0.82) if enabled else Color(0.58, 0.58, 0.64))
		dt.autowrap_mode = TextServer.AUTOWRAP_OFF
		dt.clip_text = true
		dt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if price_text != "":
		var pr := _lbl(row, price_text, 15, Color(0.96, 0.84, 0.44) if affordable else Color(0.86, 0.46, 0.42))
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.autowrap_mode = TextServer.AUTOWRAP_OFF
		pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.custom_minimum_size = Vector2(88, 0)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Card MATERIAL (review P1): a warm elevated leather surface with a neutral
	# bronze hairline — not a black box in a colored wireframe. The grade speaks
	# through a left accent bar (and the name's color), not a full outline.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.135, 0.115, 0.09, 0.96) if enabled else Color(0.10, 0.09, 0.075, 0.9)
	sb.border_color = Color(UITheme.BRONZE, 0.25 if enabled else 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.185, 0.16, 0.125, 0.97)
	sbh.border_color = Color(UITheme.BRONZE, 0.6)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var accent := ColorRect.new()
	accent.color = Color(color, 0.9 if enabled else 0.4)
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.offset_top = 4
	accent.offset_bottom = -4
	accent.offset_left = 0
	accent.offset_right = 4
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(accent)
	if enabled:
		b.pressed.connect(func() -> void:
			if game:
				game.sfx("ui_click"))
		b.pressed.connect(cb)
	grid.add_child(b)
	return b


## Scrollable Buy shelf.
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

	# One multiplier prices every shelf consistently.
	var haggle: float = game.band_price_mult() * game.shop_markup(zone)
	var price_ch := game.shop_chapter()
	# Gear uses farm-cost pricing; staple consumables remain flat.

	# ================================================================ GEAR ===
	_shop_shelf(buy, "Gear")
	var gear_grid := _shop_grid(buy)
	for item in game.shop_stock[zone]:
		var it: Dictionary = item
		var cost := int(ceil(Items.shop_buy_price(it, price_ch) * haggle))
		# Buying is confirmed from the shared detail popover.
		var open_cb := func() -> void:
			UIGearInspect.open(self, it, "all", zone)
		_shop_card(gear_grid, Art.icon_for(it), Items.title(it),
			"%s — %d gold" % [Items.describe(it), cost],
			Items.GRADE_COLOR[it["grade"]], true, open_cb)
	# Nothing equipped (a fresh hero) = no dangling empty "Upgrade" shelf.
	if not p.equipment.is_empty():
		_shop_shelf(buy, "Upgrade equipped gear", Color(0.6, 0.82, 0.95))
	if _smith_msg != "":
		_lbl(buy, _smith_msg, 12, _smith_msg_color)
		_smith_msg = ""
	var up_grid := _shop_grid(buy)
	for slot in Items.SLOTS:
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
						# A failed attempt spends gold but never downgrades the item.
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
	# The clean shelf stocks act-appropriate grades below S.
	var pot_act: int = Story.act_of(price_ch)
	var pot_shapes := [["health", "instant"], ["health", "tonic"], ["mana", "instant"],
		["mana", "tonic"], ["might", "buff"], ["ward", "buff"], ["renewal", "burst"]]
	_shop_shelf(buy, "Alchemist's Shelf  ·  Accord", Color(0.62, 0.8, 0.68))
	var acc_grid := _shop_grid(buy)
	for ps in pot_shapes:
		var fam: String = ps[0]
		var shp: String = ps[1]
		for gr in Balance.shop_potion_grades(pot_act):
			var made := Items.make_potion(fam, shp, String(gr), "accord")
			if made.is_empty():
				continue
			var pcost := int(ceil(float(made["price"]) * haggle))
			var buy_cb := func() -> void:
				if not preload("res://scripts/ui/shop_prices.gd").unchanged(self, zone, haggle):
					return
				if p.gold >= pcost:
					if p.add_consumable(made.duplicate(true)):
						p.gold -= pcost
						game.sfx("potion")
					else:
						game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
				open_shop(zone)
			_shop_card(acc_grid, Art.consumable_icon(made), String(made["name"]),
				"%d gold   (%s)" % [pcost, made["desc"]],
				Items.GRADE_COLOR[made["grade"]], p.gold >= pcost, buy_cb)
	var recall := Items.make_recall_scroll()
	var rcost := int(ceil(float(Balance.consumable_price("recall_scroll", p.level)) * haggle))
	var buy_recall := func() -> void:
		if not preload("res://scripts/ui/shop_prices.gd").unchanged(self, zone, haggle):
			return
		if p.gold >= rcost:
			if p.add_consumable(recall.duplicate(true)):
				p.gold -= rcost
				game.sfx("potion")
			else:
				game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
		open_shop(zone)
	_shop_card(acc_grid, Art.consumable_icon(recall), String(recall["name"]),
		"%d gold   (%s)" % [rcost, recall["desc"]], Items.GRADE_COLOR[recall["grade"]],
		p.gold >= rcost, buy_recall)
	# Laced potions remain exclusive to black-market vendors.

	# ======================================================= MISCELLANEOUS ===
	_shop_shelf(buy, "Miscellaneous")
	var misc_grid := _shop_grid(buy)
	# Loose gems appear only once their drops have entered the campaign.
	if Balance.regular_gems_drop(price_ch):
		var gem_act: int = int(Balance.CHAPTER_ECON.get(price_ch, {}).get("act", 1))
		var gem_range: Array = Balance.SHOP_GEM_RANGE.get(gem_act, [1, 1])
		for glvl in range(int(gem_range[0]), int(gem_range[1]) + 1):
			var gl := glvl
			var gprice := int(ceil(Items.gem_buy_price(gl, price_ch) * haggle))
			var buy_gem := func() -> void:
				if not preload("res://scripts/ui/shop_prices.gd").unchanged(self, zone, haggle):
					return
				if p.gold >= gprice:
					if p.gain_gem(Items.random_gem(game.loot_rng, gl)):
						p.gold -= gprice
						game.sfx("chest")
					else:
						game.spawn_text(p.global_position + Vector2(0, -50), "Bag full!", Color(1.0, 0.6, 0.5))
				open_shop(zone)
			_shop_card(misc_grid, null, "💎 Gem — Lv%d" % gl, "random stat — %d gold" % gprice,
				Color(0.6, 0.9, 1.0), p.gold >= gprice, buy_gem)

	# Bags are low-cost capacity upgrades; buy_install_bag equips it (swapping out
	# the smallest it beats when full — the displaced bag drops into your pack).
	for bag_item in game.shop_bags[zone]:
		var bit: Dictionary = bag_item
		var bcost := int(ceil(float(Items.bag_buy_price(String(bit["grade"]))) * haggle))
		# Disable bags that cannot improve total capacity.
		var bimproves: bool = p.bag_would_improve(int(bit["slots"]))
		var buy_bag := func() -> void:
			if not preload("res://scripts/ui/shop_prices.gd").unchanged(self, zone, haggle):
				return
			if p.gold >= bcost and bimproves:
				p.gold -= bcost
				game.shop_bags[zone].erase(bit)
				p.buy_install_bag(bit)
			open_shop(zone)
		var bdetail := "+%d slots — %d gold" % [int(bit["slots"]), bcost]
		if not bimproves:
			bdetail += "  (no gain — bags full & larger)"
		_shop_card(misc_grid, Art.bag_icon(String(bit["grade"])), String(bit["name"]), bdetail,
			Items.GRADE_COLOR[String(bit["grade"])], p.gold >= bcost and bimproves, buy_bag)

	# Gambling is a road-only boss-band pity roll.
	if game.chapter_id == "capital":
		return
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


## Set the junk-sell floor and rebuild the sell view.
func _pick_junk_tier(g: String, zone: int) -> void:
	shop_junk_tier = g
	open_shop(zone, "sell")


## Sell tab: bulk actions followed by item cards.
func _shop_sell(vbox: VBoxContainer, zone: int, p: Player) -> void:
	_lbl(vbox, "Buy-back is %d%% of market. ★ Kept gear is never sold; unkeep it in your inventory first." % int(Balance.MERCHANT_SELL_FRACTION * 100),
		13, Color(0.7, 0.72, 0.78))

	# Keep bulk actions fixed above the scrolling stock.
	var gear_total := 0
	var sellable := GearCare.sellable(p.backpack)
	for item in sellable:
		gear_total += GearCare.sale_value(item)
	if not p.backpack.is_empty():
		var sell_all := func() -> void:
			p.sell_gear(sellable)
			open_shop(zone)
		var allb := _btn(vbox, "Sell unkept gear (%d) — %d gold" % [sellable.size(), p.gold_yield(gear_total)],
			sell_all, Color(1.0, 0.9, 0.4), not sellable.is_empty())
		allb.name = "SellUnkeptGear"
		allb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Junk-sell includes the selected grade and below, never S.
		var junk := GearCare.sellable(p.backpack, shop_junk_tier)
		var junk_total := 0
		var junk_n := 0
		for item in junk:
			junk_n += 1
			junk_total += GearCare.sale_value(item)
		var frow := HBoxContainer.new()
		frow.name = "ShopJunkFloorRow"
		frow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frow.add_theme_constant_override("separation", 6)
		vbox.add_child(frow)
		var flbl := _lbl(frow, "Junk floor:", 13, Color(0.7, 0.72, 0.78))
		# Explicit widths avoid the HBox label-collapse trap.
		flbl.custom_minimum_size = Vector2(88, 0)
		flbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for gr in ["F", "E", "D", "C", "B", "A"]:
			var g: String = gr
			var picked: bool = shop_junk_tier == g
			var chip := _btn(frow, " %s " % g, func() -> void: _pick_junk_tier(g, zone),
				Items.GRADE_COLOR[g] if picked else Color(0.5, 0.5, 0.55))
			chip.add_theme_font_size_override("font_size", 14)
		var sell_junk := func() -> void:
			p.sell_gear(junk)
			open_shop(zone)
		var junkb := _btn(frow, "🧹  Sell ≤ %s  (%d) — %d gold" % [shop_junk_tier, junk_n, p.gold_yield(junk_total)],
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

	# --- gear cards ---
	if not p.backpack.is_empty():
		sold_any = true
		_shop_shelf(list, "Gear")
		var gear_grid := _shop_grid(list)
		for item in p.backpack:
			var it: Dictionary = item
			var value := maxi(1, int(Items.price(it) * Balance.MERCHANT_SELL_FRACTION))
			var sell_one := func() -> void:
				p.sell_gear([it])
				open_shop(zone)
			_shop_card(gear_grid, Art.icon_for(it), Items.title(it),
				"★ Kept · protected" if GearCare.kept(it) else "sell for %d gold" % p.gold_yield(value),
				Items.GRADE_COLOR[it["grade"]], not GearCare.kept(it), sell_one)

	# --- loose gems ---
	var gem_groups := _gem_groups()
	var gem_keys := _sorted_gem_keys(gem_groups)
	if not gem_keys.is_empty():
		sold_any = true
		_shop_shelf(list, "Gems")
		var gem_grid := _shop_grid(list)
		for key in gem_keys:
			var g: Dictionary = gem_groups[key]["gem"]
			var gcount: int = gem_groups[key]["count"]
			var gval := maxi(1, int(Balance.gem_gold_value(int(g["lvl"])) * Balance.MERCHANT_SELL_FRACTION))
			var xn := "  (x%d)" % gcount if gcount > 1 else ""
			var sell_gem := func() -> void:
				var live := GearCare.index_of(p.gem_bag, g)
				if live < 0:
					return
				p.gem_bag.remove_at(live)
				p.gain_gold(gval)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(gem_grid, Art.gem_icon(Items.gem_color(g), int(g["lvl"])),
				"%s%s" % [Items.gem_title(g), xn], "sell one for %d gold" % p.gold_yield(gval),
				Items.gem_color(g), true, sell_gem)

	# --- marketable consumables; quest/utility items never appear here ---
	var cg := {}
	var corder: Array = []
	for c in p.consumables:
		var cc0: Dictionary = c
		var gid := String(cc0.get("id", ""))
		var is_pot := String(cc0.get("kind", "")) == "potion"
		if is_pot and bool(cc0.get("gift", false)):
			continue  # the ch1-3 teaching gift never sells
		if is_pot and bool(cc0.get("no_sell", false)):
			continue  # synthesised Grand potions are never sold (CONSUMABLE_GRADES §9)
		if not is_pot and not Balance.CONSUMABLE_PRICES.has(gid):
			continue
		if not cg.has(gid):
			cg[gid] = {"c": cc0, "count": 0}
			corder.append(gid)
		cg[gid]["count"] += 1
	if not corder.is_empty():
		sold_any = true
		_shop_shelf(list, "Consumables")
		var cons_grid := _shop_grid(list)
		for gid in corder:
			var cc: Dictionary = cg[gid]["c"]
			var ccount: int = cg[gid]["count"]
			var base_val: int = int(cc.get("price", 0)) if String(cc.get("kind", "")) == "potion" \
				else int(Balance.CONSUMABLE_PRICES.get(gid, 0))
			var cval := maxi(1, int(float(base_val) * Balance.MERCHANT_SELL_FRACTION))
			var xn2 := "  (x%d)" % ccount if ccount > 1 else ""
			var sell_cons := func() -> void:
				var live := GearCare.index_of(p.consumables, cc)
				if live < 0:
					return
				p.consumables.remove_at(live)
				p.gain_gold(cval)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(cons_grid, Art.consumable_icon(cc), "%s%s" % [String(cc["name"]), xn2],
				"sell one for %d gold" % p.gold_yield(cval), Items.GRADE_COLOR[String(cc.get("grade", "C"))],
				true, sell_cons)

	# --- materials: click sells one unit from the stack ---
	if not p.materials.is_empty():
		sold_any = true
		_shop_shelf(list, "Materials")
		var mat_grid := _shop_grid(list)
		for m in p.materials:
			var mm: Dictionary = m
			var mgr := String(mm.get("grade", "F"))
			var mcount := int(mm.get("count", 1))
			var mval := maxi(1, int(Items.material_value(mgr) * Balance.MERCHANT_SELL_FRACTION))
			var xn3 := "  (x%d)" % mcount if mcount > 1 else ""
			var sell_mat := func() -> void:
				if GearCare.index_of(p.materials, mm) < 0 or int(mm.get("count", 0)) <= 0:
					return
				mm["count"] = int(mm.get("count", 1)) - 1
				if int(mm.get("count", 0)) <= 0:
					p.materials.erase(mm)
				p.gain_gold(mval)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(mat_grid, Art.material_ui_icon(String(mm.get("family", "")), mgr),
				"%s%s" % [String(mm.get("name", "")), xn3], "sell one for %d gold" % p.gold_yield(mval),
				Items.GRADE_COLOR.get(mgr, Color(1, 1, 1)), true, sell_mat)

	# --- loose bags: sell spare capacity for its (currently trivial) resale ---
	# BAG_SELL_GOLD is pinned at 1g for now (anti-farm); see the knob's TODO.
	if not p.loose_bags.is_empty():
		sold_any = true
		_shop_shelf(list, "Bags")
		var bag_grid := _shop_grid(list)
		for bli in p.loose_bags.size():
			var lb: Dictionary = p.loose_bags[bli]
			var lgr := String(lb.get("grade", "F"))
			var sell_bag := func() -> void:
				var live := GearCare.index_of(p.loose_bags, lb)
				if live < 0:
					return
				p.sell_loose_bag(live)
				game.sfx("potion")
				open_shop(zone)
			_shop_card(bag_grid, Art.bag_icon(lgr),
				"%s (%d slots)" % [String(lb.get("name", Items.BAG_NAMES.get(lgr, "Bag"))), int(lb.get("slots", 0))],
				"sell for %d gold" % Balance.BAG_SELL_GOLD, Items.GRADE_COLOR.get(lgr, Color(1, 1, 1)), true, sell_bag)

	if not sold_any:
		_lbl(list, "Nothing to sell.", 13, Color(0.5, 0.5, 0.5))


# --------------------------------------------------------------- map (M) ---

# Only visited rooms render; unexplored exits appear as stubs.
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

# Crownfall uses district color rather than room-type color.
const DISTRICT_COLOR := {
	"heart":    Color(0.72, 0.42, 0.18), "craft":  Color(0.52, 0.31, 0.16),
	"civic":    Color(0.24, 0.35, 0.45), "approach": Color(0.30, 0.34, 0.40),
	"accord":   Color(0.52, 0.40, 0.15), "cinder": Color(0.50, 0.21, 0.25),
	"wild":     Color(0.27, 0.41, 0.23), "choir":  Color(0.39, 0.30, 0.49),
	"outer":    Color(0.27, 0.27, 0.31),
}
const DISTRICT_NAME := {
	"heart": "The Heart", "craft": "Artisans", "civic": "Crown Core",
	"approach": "Emberward", "accord": "The Accord", "cinder": "Cinderborn",
	"wild": "Wildfang", "choir": "Hollow Choir", "outer": "Ramparts",
}


func open_map() -> void:
	if Story.is_standalone(game.chapter_id):
		_open_capital_map()
		return
	UIFieldAtlas.open(self)


## Short service copy for the capital map and its hover directory. Only active,
## player-facing interactions are listed — decorative residents and planned
## crafting stations do not pretend to be usable services.
func _capital_zone_services(zone: Dictionary) -> String:
	var services: Array[String] = []
	if zone.has("merchant"):
		services.append("MERCHANT")
	var actions: Array[String] = []
	for npc_def in zone.get("npcs", []):
		var npc: Dictionary = npc_def
		var action := String(npc.get("action", ""))
		if action != "" and action not in actions:
			actions.append(action)
	for landmark in zone.get("landmarks", []):
		for use in landmark.get("uses", []):
			var action := String(use.get("ref", ""))
			if String(use.get("type", "")) == "action" and action != "" and action not in actions:
				actions.append(action)
	var names := {"vault": "STASH", "codex": "CODEX", "daily": "DAILY REWARD",
		"map": "CITY MAP", "mail": "MAILBOX", "journal": "JOURNAL",
		"records": "RECORDS", "guild": "GUILD", "skills": "SKILLS", "gear": "GEAR",
		"wardrobe": "WARDROBE", "forge": "FORGE", "lapidary": "LAPIDARY",
		"drill": "TRAINING", "potions": "POTIONS", "fangmoot": "FANGMOOT",
		"professions": "PROFESSIONS", "synthesis": "SYNTHESIS", "blackmarket": "BLACK MARKET",
		"portal_story": "STORY", "portal_crucible": "CRUCIBLE",
		"portal_depths": "DEPTHS", "portal_moonfen": "MOONFEN"}
	for action in actions:
		var label := String(names.get(action, ""))
		if action.begins_with("ward_contract_") and action.trim_prefix("ward_contract_") in Balance.WARD_CONTRACT_WARDS:
			label = "WARD CONTRACTS"
		if label != "" and label not in services:
			services.append(label)
	return "  ·  ".join(services)


## Crownfall's own map: the whole city, always charted. The panel is deliberately
## kept inside the project's 1280×720 logical viewport (the old 760px panel
## clipped above and below it), while room labels have hard bounds at every
## canvas scale. The right rail is a useful city directory, not another legend.
func _open_capital_map() -> void:
	var vbox := _open("Crownfall — Capital Directory", 1216, 672, true)
	current = "map"

	# One bounded instruction strip. Each HBox label gets a minimum width so it
	# cannot collapse into one-character columns on narrow physical displays.
	var intro_panel := PanelContainer.new()
	var intro_sb := StyleBoxFlat.new()
	intro_sb.bg_color = Color(0.16, 0.145, 0.11, 0.92)
	intro_sb.border_color = Color(UITheme.BRONZE, 0.52)
	intro_sb.set_border_width_all(1)
	intro_sb.set_corner_radius_all(5)
	intro_sb.content_margin_left = 12
	intro_sb.content_margin_right = 12
	intro_sb.content_margin_top = 5
	intro_sb.content_margin_bottom = 5
	intro_panel.add_theme_stylebox_override("panel", intro_sb)
	intro_panel.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(intro_panel)
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 16)
	intro_panel.add_child(intro)
	var instruction := _lbl(intro, "SELECT A DESTINATION TO FAST TRAVEL", 12, Color(0.92, 0.84, 0.60))
	instruction.autowrap_mode = TextServer.AUTOWRAP_OFF
	instruction.custom_minimum_size = Vector2(360, 18)
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var marks := _lbl(intro, "★  ARRIVAL   ◆  GATEWAYS   ●  DAILY CONTRACT", 11, Color(0.72, 0.76, 0.82))
	marks.autowrap_mode = TextServer.AUTOWRAP_OFF
	marks.custom_minimum_size = Vector2(350, 18)
	marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	marks.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.custom_minimum_size = Vector2(0, 458)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Map frame and fixed inner chart. The logical canvas scales down as one unit
	# on smaller windows, so fixed inner bounds preserve both overview and touch
	# targets without spawning a horizontal scrollbar.
	var map_frame := PanelContainer.new()
	map_frame.custom_minimum_size = Vector2(896, 458)
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_sb := StyleBoxFlat.new()
	map_sb.bg_color = Color(0.085, 0.076, 0.058, 0.98)
	map_sb.border_color = Color(0.82, 0.70, 0.42, 0.48)
	map_sb.set_border_width_all(1)
	map_sb.set_corner_radius_all(7)
	map_frame.add_theme_stylebox_override("panel", map_sb)
	content.add_child(map_frame)
	var map_center := CenterContainer.new()
	map_frame.add_child(map_center)
	var board := Control.new()
	board.name = "CapitalMapBoard"
	board.custom_minimum_size = Vector2(890, 452)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board.clip_contents = true
	map_center.add_child(board)

	# Quiet cartographic grid, title, and compass. Drawn as one control so the
	# Clickable room controls remain the only substantial node cost.
	var chrome := Control.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(chrome)
	chrome.draw.connect(func() -> void:
		var sz: Vector2 = chrome.size
		for gx in range(18, int(sz.x), 36):
			chrome.draw_line(Vector2(gx, 24), Vector2(gx, sz.y - 12), Color(0.86, 0.77, 0.55, 0.035), 1.0)
		for gy in range(28, int(sz.y), 32):
			chrome.draw_line(Vector2(10, gy), Vector2(sz.x - 10, gy), Color(0.86, 0.77, 0.55, 0.035), 1.0)
		var compass_pos := Vector2(sz.x - 23.0, 21.0)
		chrome.draw_arc(compass_pos, 11.0, 0.0, TAU, 24, Color(0.9, 0.8, 0.5, 0.35), 1.0)
		chrome.draw_line(compass_pos + Vector2(0, 8), compass_pos + Vector2(0, -9), Color(0.9, 0.8, 0.5, 0.58), 1.5)
		chrome.draw_line(compass_pos + Vector2(-6, 0), compass_pos + Vector2(6, 0), Color(0.9, 0.8, 0.5, 0.28), 1.0))
	chrome.resized.connect(func() -> void: chrome.queue_redraw())
	var chart_title := _lbl(board, "THE CROWN WARDS  ·  %d DESTINATIONS" % game.zone_count, 10, Color(0.72, 0.65, 0.48, 0.78))
	chart_title.position = Vector2(13, 5)
	chart_title.size = Vector2(310, 16)
	chart_title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Exact city extent — unlike the old map, no phantom row/column is added on
	# every side. That reclaimed space makes even three-line names readable.
	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-(1 << 20), -(1 << 20))
	for i in game.zone_count:
		var c: Vector2i = game.rooms[i]["coord"]
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var cols := max_c.x - min_c.x + 1
	var rows := max_c.y - min_c.y + 1
	var map_w := 890.0
	var map_h := 452.0
	var gap := 5.0
	var side_pad := 16.0
	var top_pad := 27.0
	var bottom_pad := 14.0
	var cw: float = (map_w - side_pad * 2.0 - float(cols - 1) * gap) / float(cols)
	var ch: float = (map_h - top_pad - bottom_pad - float(rows - 1) * gap) / float(rows)
	var org := Vector2(side_pad, top_pad)
	var cell_pos := func(c: Vector2i) -> Vector2:
		return org + Vector2((c.x - min_c.x) * (cw + gap), (c.y - min_c.y) * (ch + gap))

	# Streets first, with a darker under-stroke and warm paving above it.
	for i in game.zone_count:
		var p: Vector2 = cell_pos.call(game.rooms[i]["coord"])
		for dir in game.rooms[i]["exits"].keys():
			var nb: int = game.neighbor(i, String(dir))
			if nb < 0 or nb < i:
				continue
			var delta: Vector2i = Game.DIRS[dir]
			var mid := p + Vector2(cw / 2.0, ch / 2.0)
			var to := mid + Vector2(delta.x * (cw + gap), delta.y * (ch + gap))
			for road_spec in [[7.0, Color(0.035, 0.03, 0.024, 0.95)], [3.0, Color(0.64, 0.56, 0.40, 0.62)]]:
				var thick: float = float(road_spec[0])
				var link := ColorRect.new()
				link.color = road_spec[1]
				link.position = Vector2(minf(mid.x, to.x) - thick / 2.0, minf(mid.y, to.y) - thick / 2.0)
				link.size = Vector2(absf(to.x - mid.x) + thick, absf(to.y - mid.y) + thick)
				link.mouse_filter = Control.MOUSE_FILTER_IGNORE
				board.add_child(link)

	# Collect active services for the directory while building room controls.
	var service_rooms := {}
	var daily_count := 0
	for i in game.zone_count:
		var zone: Dictionary = game.zones[i]
		if zone.has("merchant"):
			service_rooms["merchant"] = i
		if String(zone.get("mark", "")) == "●":
			daily_count += 1
		for npc_def in zone.get("npcs", []):
			var npc: Dictionary = npc_def
			var action := String(npc.get("action", ""))
			if action.begins_with("portal_"):
				if not service_rooms.has("portals"):   # first wins: the Wayfinder's THREE gates, never a later single door
					service_rooms["portals"] = i
			elif action != "" and not service_rooms.has(action):
				service_rooms[action] = i
		# Crownfall's accessible facades now own their services directly. Keep
		# the directory derived from those typed landmark stations too; looking
		# only at NPC actions made the city map forget every building except the
		# one remaining clerk.
		for landmark_def in zone.get("landmarks", []):
			var landmark: Dictionary = landmark_def
			for use_def in landmark.get("uses", []):
				var landmark_use: Dictionary = use_def
				if String(landmark_use.get("type", "")) != "action":
					continue
				var landmark_action := String(landmark_use.get("ref", ""))
				if landmark_action.begins_with("portal_"):
					if not service_rooms.has("portals"):   # first wins (Wayfinder Sanctum)
						service_rooms["portals"] = i
				elif landmark_action != "" and not service_rooms.has(landmark_action):
					service_rooms[landmark_action] = i

	# Room cells: ward color, bounded name, service mark, and an unmistakable
	# current-location frame. Every label is clipped inside its own cell.
	for i in game.zone_count:
		var c: Vector2i = game.rooms[i]["coord"]
		var p: Vector2 = cell_pos.call(c)
		var zone: Dictionary = game.zones[i]
		var dist := String(zone.get("district", "civic"))
		var col: Color = DISTRICT_COLOR.get(dist, Color(0.3, 0.3, 0.34))
		var is_here: bool = i == game.cur_room
		var travel: bool = game.travel_target(i) and not is_here
		var services := _capital_zone_services(zone)

		var cell: Control = Button.new() if travel else Panel.new()
		cell.position = p
		cell.size = Vector2(cw, ch)
		cell.z_index = 2
		cell.clip_contents = true
		var district_text := String(DISTRICT_NAME.get(dist, dist))
		cell.tooltip_text = "%s\n%s%s\n%s" % [String(zone["name"]), district_text,
			("  ·  " + services) if services != "" else "",
			"Select to fast travel" if travel else "You are here"]
		var csb := StyleBoxFlat.new()
		csb.bg_color = col.lightened(0.09) if is_here else Color(col, 0.94)
		csb.set_corner_radius_all(4)
		csb.border_color = Color(1.0, 0.85, 0.45) if is_here else col.lightened(0.30)
		csb.set_border_width_all(3 if is_here else 1)
		if cell is Button:
			var room_idx: int = i
			var bh: StyleBoxFlat = csb.duplicate()
			bh.bg_color = col.lightened(0.20)
			bh.border_color = Color(0.98, 0.86, 0.52, 0.88)
			var bp: StyleBoxFlat = bh.duplicate()
			bp.bg_color = col.lightened(0.08)
			(cell as Button).focus_mode = Control.FOCUS_NONE
			(cell as Button).add_theme_stylebox_override("normal", csb)
			(cell as Button).add_theme_stylebox_override("hover", bh)
			(cell as Button).add_theme_stylebox_override("pressed", bp)
			(cell as Button).pressed.connect(func() -> void:
				close()
				game.fast_travel(room_idx))
		else:
			(cell as Panel).add_theme_stylebox_override("panel", csb)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
		board.add_child(cell)

		var nm := String(zone["name"])
		if nm.begins_with("The "):
			nm = nm.substr(4)
		# Configure this Label before it enters the tree. _lbl() intentionally
		# enables wrapping before add_child; at width zero Godot then caches a
		# hundreds-of-pixels-tall minimum for long room names. That was the
		# original capital-map overflow, even when `size` was assigned later.
		var nlbl := Label.new()
		nlbl.text = nm
		nlbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nlbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nlbl.clip_text = true
		nlbl.add_theme_font_size_override("font_size", 10)
		nlbl.add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.82) if is_here else Color(0.93, 0.91, 0.85))
		nlbl.position = p + Vector2(4, (ch - 17.0) / 2.0)
		nlbl.size = Vector2(cw - 8, 17)
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nlbl.z_index = 4
		nlbl.add_theme_color_override("font_shadow_color", Color(0.015, 0.012, 0.01, 0.95))
		nlbl.add_theme_constant_override("shadow_offset_x", 1)
		nlbl.add_theme_constant_override("shadow_offset_y", 1)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(nlbl)

		var mk := String(zone.get("mark", ""))
		if mk != "":
			var mcol := Color(1.0, 0.86, 0.47) if mk in ["◆", "★"] else Color(1.0, 0.72, 0.38)
			var ml := _lbl(board, mk, 11, mcol)
			ml.position = p + Vector2(3, -1)
			ml.size = Vector2(14, 14)
			ml.z_index = 5
			ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_here:
			var here := _lbl(board, "HERE", 8, Color(1.0, 0.88, 0.52))
			here.position = p + Vector2(cw - 27, -1)
			here.size = Vector2(25, 13)
			here.z_index = 5
			here.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			here.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Service rail: a current-location card, then direct travel to every active
	# civic utility. The list uses short single-line labels and full tooltips.
	var directory := PanelContainer.new()
	directory.name = "CapitalServiceDirectory"
	directory.custom_minimum_size = Vector2(260, 458)
	directory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dir_sb := StyleBoxFlat.new()
	dir_sb.bg_color = Color(0.105, 0.10, 0.095, 0.98)
	dir_sb.border_color = Color(UITheme.BRONZE, 0.55)
	dir_sb.set_border_width_all(1)
	dir_sb.set_corner_radius_all(7)
	dir_sb.content_margin_left = 12
	dir_sb.content_margin_right = 12
	dir_sb.content_margin_top = 11
	dir_sb.content_margin_bottom = 10
	directory.add_theme_stylebox_override("panel", dir_sb)
	content.add_child(directory)
	var dir_box := VBoxContainer.new()
	dir_box.add_theme_constant_override("separation", 7)
	directory.add_child(dir_box)
	var dir_head := _lbl(dir_box, "CITY DIRECTORY", 14, Color(0.95, 0.84, 0.53))
	UITheme.header(dir_head)

	var current_zone: Dictionary = game.zones[game.cur_room]
	var current_dist := String(current_zone.get("district", "civic"))
	var here_panel := PanelContainer.new()
	var here_sb := StyleBoxFlat.new()
	here_sb.bg_color = Color(DISTRICT_COLOR.get(current_dist, Color(0.3, 0.3, 0.34)), 0.50)
	here_sb.border_color = Color(0.95, 0.84, 0.48, 0.72)
	here_sb.set_border_width_all(1)
	here_sb.set_corner_radius_all(5)
	here_sb.content_margin_left = 9
	here_sb.content_margin_right = 9
	here_sb.content_margin_top = 6
	here_sb.content_margin_bottom = 6
	here_panel.add_theme_stylebox_override("panel", here_sb)
	here_panel.custom_minimum_size = Vector2(0, 56)
	dir_box.add_child(here_panel)
	var here_box := VBoxContainer.new()
	here_box.add_theme_constant_override("separation", 1)
	here_panel.add_child(here_box)
	var here_kicker := _lbl(here_box, "YOU ARE HERE  ·  %s" % String(DISTRICT_NAME.get(current_dist, current_dist)).to_upper(),
		9, Color(0.86, 0.78, 0.58))
	here_kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	here_kicker.custom_minimum_size = Vector2(0, 14)
	here_kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var here_name := _lbl(here_box, String(current_zone["name"]), 13, Color(1.0, 0.96, 0.84))
	here_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	here_name.custom_minimum_size = Vector2(0, 19)
	here_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_lbl(dir_box, "ACTIVE SERVICES", 10, Color(0.61, 0.65, 0.72))
	var directory_specs := [
		["portals", "◆  GATEWAYS", "Story, Crucible, and Depths portals"],
		["gear", "▣  ARTISANS  ·  GEAR / STASH", "Gearwork and your account-wide stash"],
		["codex", "◈  ARCHIVE  ·  CODEX / RECORDS", "Codex, quest journal, and combat records"],
		["guild", "⚑  CHARTERED HALL  ·  GUILD", "Guild and social services"],
		["merchant", "⚖  BAZAAR  ·  MARKET / DAILY", "Merchant, daily reward, and mailbox"],
		["skills", "✦  PROVING GROUNDS  ·  SKILLS", "Talents, attributes, and training"],
		["map", "⌖  CROWN PLAZA  ·  CITY MAP", "The city's arrival point and map table"],
	]
	for spec in directory_specs:
		var key := String(spec[0])
		var room_idx: int = int(service_rooms.get(key, -1))
		if room_idx < 0:
			continue
		var b := Button.new()
		b.text = String(spec[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color(0.88, 0.88, 0.84))
		var at_service: bool = room_idx == game.cur_room
		b.disabled = at_service
		b.tooltip_text = "%s\n%s\n%s" % [String(game.zones[room_idx]["name"]), String(spec[2]),
			"You are here" if at_service else "Select to fast travel"]
		if not at_service:
			b.pressed.connect(func() -> void:
				game.sfx("ui_click")
				close()
				game.fast_travel(room_idx))
		dir_box.add_child(b)
	var quest_rule := HSeparator.new()
	quest_rule.add_theme_constant_override("separation", 5)
	dir_box.add_child(quest_rule)
	var quests := _lbl(dir_box, "●  %d DAILY CONTRACTS" % daily_count, 11, Color(0.95, 0.69, 0.40))
	quests.tooltip_text = "Faction quest-givers are marked ● on the ward map."
	var rail_hint := _lbl(dir_box, "Select any destination to travel.", 10, Color(0.56, 0.59, 0.64))
	rail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# Ward legend. Explicit chip widths prevent the classic HBox label-collapse
	# failure while keeping all eight wards on one readable line.
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 9)
	vbox.add_child(legend)
	var used_districts := {}
	for zone_def in game.zones:
		var zone: Dictionary = zone_def
		used_districts[String(zone.get("district", "civic"))] = true
	for dk in ["heart", "craft", "civic", "approach", "accord", "cinder", "wild", "choir", "outer"]:
		if not used_districts.has(dk):
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		legend.add_child(chip)
		var sw := Panel.new()
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = DISTRICT_COLOR[dk]
		ssb.border_color = Color(DISTRICT_COLOR[dk], 1.0).lightened(0.30)
		ssb.set_border_width_all(1)
		ssb.set_corner_radius_all(2)
		sw.add_theme_stylebox_override("panel", ssb)
		sw.custom_minimum_size = Vector2(11, 11)
		chip.add_child(sw)
		var district_label := _lbl(chip, String(DISTRICT_NAME[dk]).replace("The ", ""), 10, Color(0.72, 0.75, 0.79))
		district_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		district_label.custom_minimum_size = Vector2(39 + district_label.text.length() * 3.8, 16)
		district_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint(vbox, "ESC / %s to close" % menu_key("map"))


# ------------------------------------------------------------------- codex ---

const BOSS_KINDS := ["fangmaw", "morwen", "vargoth",
	"stormwarden", "choirmother", "nullwarden",  # (T4) ch2 content bosses
	"sexton", "vess", "saint_varo",  # ch3 Unburied Vale (BOSSES.md)
	"forgemistress", "cinderhide", "ashpriest",  # ch4 Slagfields (BOSSES.md)
	"whitepelt", "icebound", "sleepkeeper",  # ch5 Long Sleep (BOSSES.md)
	"auroch", "gardener", "curetwisted",  # ch6 Blooming Deep (BOSSES.md)
	"stormdrake_veyx", "unnamed_echo", "stormmouth",  # ch7 Breaking Sky — Act 1 finale (BOSSES.md)
	"first_howl"]  # (Q13 I2) The Moonfen interlude — the band-read boss

## Codex screens live in ui/codex.gd. Passing a boss `kind` opens that
## boss's focused mechanics detail view instead of the tab list.
## `tab` "" reopens the codex where the reader left it (C key / HUD button);
## an explicit tab id or boss kind routes there (UICodex._resolve).
func open_codex(tab := "", boss := "") -> void:
	UICodex.open(self, tab, boss)


## Play Together — the co-op lobby (MP-08) lives in ui/lobby.gd.
func open_lobby(stage := "menu") -> void:
	UILobby.open(self, stage)


## Reopen the party that persists behind a closed lobby panel. The HUD calls
## this in live play; role routing keeps host controls away from guests.
func open_party() -> void:
	var net: Node = get_node_or_null("/root/NetworkManager")
	if not game.play_started or net == null or not net.is_online():
		return
	open_lobby("host_lobby" if net.is_host() else "guest_lobby")


# ---------------------------------------------------------------- dev mode ---

## The mailbox (dropped-loot letters, gifts) lives in ui/mailbox.gd.
func open_mailbox() -> void:
	UIMailbox.open(self)


## The daily-login reward screen lives in ui/daily.gd.
func open_daily() -> void:
	UIDaily.open(self)


## The quest log / journal lives in ui/journal.gd.
func open_journal(tab := "", ward := "") -> void:
	UIJournal.open(self, tab, ward)


## The account-wide stash lives in ui/stash.gd.
func open_stash() -> void:
	UIStash.open(self)


## The Wardrobe (Renown cosmetics store + equip) lives in ui/wardrobe.gd.
func open_wardrobe() -> void:
	UIWardrobe.open(self)


## The Professions panel (trade lock, mastery, blueprints, craft bench) lives in
## ui/professions.gd. Opened from a capital trainer station (game_world hub).
func open_professions() -> void:
	UIProfessions.open(self)


## Clean potion recipes at the Alchemist bench.
func open_alchemy() -> void:
	preload("res://scripts/ui/alchemy.gd").open(self)


## The Synthesis bench (Alkahest Codex + Grand potions) lives in ui/synthesis.gd.
## Opened from Herbalist Kesh's gossip hub in Crownfall (game_world hub action).
func open_synthesis() -> void:
	UISynthesis.open(self)


## Fangmoot — the tavern autobattler (ui/fangmoot.gd). Opened from Carver Tove's
## table in Fangmoot Circle (game_world hub action "fangmoot").
func open_fangmoot() -> void:
	UIFangmoot.open(self)


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
	kscroll.follow_focus = game.touch_mode
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
		var binding := _btn(klist, text, rebind_cb, Color(1, 1, 0.6) if listening_action == act else Color(1, 1, 1))
		if game.touch_mode and listening_action == act:
			binding.grab_focus()
			kscroll.call_deferred("ensure_control_visible", binding)
	_lbl(vbox, "Movement is always WASD / arrows.", 13, Color(0.6, 0.6, 0.6))
	# The explicit Back leaves this screen even while a binding is being captured.
	_btn(vbox, "  ← Back to settings  ", func() -> void: open_settings(settings_return), Color(0.8, 0.85, 0.9))
	_hint(vbox)
	_settings_touch_targets(vbox)


# ------------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
	_card_tap_observe(event)
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
				_cs_preview(ids[num])   # P7.G: number keys PREVIEW; Enter / Choose commits
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _cs_id != "":
				choose_class(_cs_id)
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
		if current == "rename":
			# ESC returns to the roster; every other key falls through UNHANDLED
			# so the focused name field keeps the typing (same as name_entry).
			if event.keycode == KEY_ESCAPE:
				open_slots()
				get_viewport().set_input_as_handled()
			return
		var focus := get_viewport().gui_get_focus_owner()
		if (focus is LineEdit or focus is TextEdit) and bool(focus.get("editable")) \
				and focus.is_visible_in_tree() and not focus.is_queued_for_deletion() \
				and root.is_ancestor_of(focus):
			# The current editor owns typing, including remapped menu hotkeys.
			# Escape still follows the same back path as every other device.
			if event.keycode == KEY_ESCAPE:
				controller_back()
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
			controller_back()
			get_viewport().set_input_as_handled()


## Shared back navigation for Escape and gamepad; boot never unpauses into a void.
func controller_back() -> void:
	if listening_action != "":
		listening_action = ""
		open_keybinds()
		return
	if current in ["name_entry", "rename"]:
		if current == "name_entry":
			open_class_select()
		else:
			open_slots()
		return
	if current in ["title", "class_select", "class_splash"] or (current == "chapter_select" and not chapter_replay):
		return
	if current == "detail":
		_close_detail_popover()  # dismiss the popover, stay on the screen beneath
	elif current == "theme_pick":
		open_skills()  # back to the tree, not out of the menu
	elif current == "lobby":
		UILobby.esc(self)  # one stage back / leave the lobby, never a void
	elif current == "settings":
		_settings_back()  # back to wherever settings was opened from
	elif current in ["comfort", "controller", "keybinds"]:
		open_settings(settings_return)
	elif current == "alchemy":
		preload("res://scripts/ui/alchemy.gd").back(self)
	elif current == "combat_report":
		open_pause()
	elif current == "benchmark_roster":
		open_slots()  # dev roster modal → back to the slot list
	elif current == "confirm":
		_cancel_confirmation()
	elif current == "chapter_select" and chapter_replay:
		open_pause()  # back to the system menu, not out of it
	else:
		close()
