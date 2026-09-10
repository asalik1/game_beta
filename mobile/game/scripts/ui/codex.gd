class_name UICodex
## The codex screens, split out of menus.gd. Static builders: `m` owns the
## panel scaffolding (_open/_btn/_lbl/_hint) and the open/close state.
##
## LAYOUT (2026-08-15 rework — PROPOSALS/CODEX_LAYOUT/CODEX_LAYOUT.md): the
## three stacked tab rows are gone. A RAIL of grouped sections (always
## visible, with counts) sits on the left; a FILTER BAR (search + chips)
## replaces the sub-tabs; a COLLECTION shows a LEDGER of compact rows beside
## the DETAIL of the selected entry, and a reference PAGE (Field notes,
## Statuses, Co-op, Records, Gallery) is one reading column. Every legacy
## open_codex("<tab>") id still routes — see _resolve() — so call sites,
## BOSS_KINDS bucketing, the dev Transform buttons and the streamed builders
## are unchanged. Filters, search and the selected row are remembered per
## section for the session (reopening the book lands where you left it).

# ---------------------------------------------------------------- layout ---
const RAIL_W := 172.0
const LIST_W := 330.0
const ROW_H := 44.0
const DETAIL_W := 396.0   # wrap width for labels inside the detail column
const PAGE_W := 700.0     # wrap width for labels on a reading page
const MUTED := Color(0.64, 0.66, 0.72)
const GOLD_TXT := Color(0.95, 0.85, 0.5)
const ACC_MOB := Color(1.0, 0.82, 0.42)
const ACC_BOSS := Color(1.0, 0.45, 0.48)
const ACC_NPC := Color(0.45, 0.78, 1.0)
const ACC_GEAR := Color(0.66, 0.86, 0.56)
const ACC_INFO := Color(0.6, 0.9, 1.0)
const ACC_GOLD := Color(0.88, 0.67, 0.28)

## Rail order. kind: "list" = ledger + detail, "page" = one reading column.
## `dev` sections only appear from the dev launcher.
const SECTIONS := [
	{"id": "monsters", "grp": "Bestiary", "name": "Monsters", "kind": "list", "accent": ACC_MOB},
	{"id": "bosses", "grp": "Bestiary", "name": "Bosses", "kind": "list", "accent": ACC_BOSS},
	{"id": "npcs", "grp": "Bestiary", "name": "Folk", "kind": "list", "accent": ACC_NPC},
	{"id": "shapes", "grp": "Armory", "name": "Shapes", "kind": "list", "accent": ACC_GEAR},
	{"id": "uniques", "grp": "Armory", "name": "Uniques", "kind": "list", "accent": ACC_GEAR},
	{"id": "gems", "grp": "Armory", "name": "Gems", "kind": "page", "accent": ACC_INFO},
	{"id": "terrains", "grp": "World", "name": "Terrains", "kind": "list", "accent": ACC_GOLD},
	{"id": "curios", "grp": "World", "name": "Curios", "kind": "list", "accent": ACC_GOLD},
	{"id": "sanctuary", "grp": "World", "name": "Sanctuary", "kind": "page", "accent": Color(0.72, 0.91, 0.70)},
	{"id": "fishing", "grp": "World", "name": "Catch journal", "kind": "page", "accent": Color(0.57, 0.84, 0.80)},
	{"id": "records", "grp": "You", "name": "Records", "kind": "page", "accent": Color(1.0, 0.85, 0.4)},
	{"id": "gallery", "grp": "You", "name": "Gallery", "kind": "page", "accent": ACC_GOLD},
	{"id": "notes", "grp": "Reference", "name": "Field notes", "kind": "page", "accent": ACC_GOLD},
	{"id": "story", "grp": "Reference", "name": "Story so far", "kind": "page", "accent": Color(0.75, 0.6, 1.0)},
	{"id": "status", "grp": "Reference", "name": "Statuses", "kind": "page", "accent": ACC_INFO},
	{"id": "coop", "grp": "Reference", "name": "Co-op", "kind": "page", "accent": ACC_INFO},
	{"id": "future", "grp": "Future", "name": "Placeholders", "kind": "page", "dev": true, "accent": Color(0.7, 0.95, 0.85)},
]

## Field notes pages (chips) — the prose that used to head the monster and
## gear shelves, plus the old Gems/Bags/Rules gear sub-tabs.
const NOTE_PAGES := [["wayfinder", "Wayfinder"], ["activities", "Activities & rewards"], ["combat", "Combat"], ["controller", "Controller"], ["elites", "Elites & Temptations"], ["gear", "Gear rules"], ["gems", "Gem rules"], ["bags", "Bags & consumables"], ["fangmoot", "Fangmoot"]]
## Gallery shelves (chips) — Heroes / Monsters / Bosses / Folk of the Vale
## (mirrors the Bestiary rail's Monsters-before-Bosses order).
const GALLERY_SHELVES := [["heroes", "Heroes"], ["monsters", "Monsters"], ["bosses", "Bosses"], ["npcs", "Folk"]]

const SLOT_LABEL := {"weapon": "Weapons", "helmet": "Helmets", "armor": "Armor", "gloves": "Gloves",
	"pants": "Pants", "boots": "Boots", "charm": "Charms"}

## The dev-only Future shelf's categories (chips), in the old subtab order.
const FUTURE_CATS := [["future_terrains", "Terrains"], ["future_mobs", "Mobs"],
	["future_npcs", "NPCs"], ["future_relics", "Relics"]]

# ---------------------------------------------------- remembered UI state ---
static var _sec := "monsters"       # open section id
static var _filters := {}           # section id -> {chip key: value}
static var _query := ""             # search text of the open section
static var _selected := {}          # section id -> selected row key
static var _fold_open := false      # boss detail: Mechanics & Tells expanded
static var _ui := {}                # live nodes of the open panel (validated before use)


## `tab` "" = reopen where the reader left off (the C key / HUD button);
## any explicit tab id or boss kind routes as before.
static func open(m: Menus, tab := "", boss := "") -> void:
	# A new build cancels any still-streaming shelf from the previous tab.
	_build_gen += 1
	_resolve(m, tab, boss)
	var vbox := m._open("Codex", 1000, 620, true)
	m.current = "codex"
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	vbox.add_child(body)
	_rail(m, body)
	var content := VBoxContainer.new()
	content.name = "CodexContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	body.add_child(content)
	_ui = {"content": content}
	_build_content(m)
	m._hint(vbox, "ESC, ✕, click outside, or C to close")


## True while the codex search field owns keyboard focus — menus._input then
## lets every key but ESC fall through to it (the name_entry pattern) instead
## of treating the codex hotkey as "close".
static func search_focused() -> bool:
	var s: LineEdit = _ui.get("search")
	return s != null and is_instance_valid(s) and s.has_focus()


static func _section(id: String) -> Dictionary:
	for s in SECTIONS:
		if String(s["id"]) == id:
			return s
	return {}


## Map a legacy/new tab id (+ optional boss kind) onto the section, its
## remembered filters and selection. Bare ids keep what the reader left;
## suffixed ids ("gear_shapes_helmet", "future_mobs") set the filter.
static func _resolve(m: Menus, tab: String, boss: String) -> void:
	var was := _sec
	if boss != "" and Story.ALL_ENEMIES.has(boss):
		var bsec := "bosses" if boss in m.BOSS_KINDS else "monsters"
		_filters[bsec] = {}  # the routed entry must be visible whatever chip was left on
		_query = ""
		_selected[bsec] = boss
		_fold_open = true
		_sec = bsec
		return
	var t := tab if tab != "" else _sec  # bare open = where the reader left off
	if t == "gear":
		t = "gear_shapes"
	var sec := "monsters"
	if t.begins_with("gear_shapes"):
		sec = "shapes"
		var slot := t.trim_prefix("gear_shapes").trim_prefix("_")
		if slot in Items.SLOTS:
			_filters[sec] = {"slot": slot}
	elif t.begins_with("gear_uniques"):
		sec = "uniques"
		var uslot := t.trim_prefix("gear_uniques").trim_prefix("_")
		if uslot in Items.SLOTS:
			_filters[sec] = {"slot": uslot}
	elif t == "gear_gems":
		sec = "gems"
	elif t == "gear_bags":
		sec = "notes"
		_filters[sec] = {"page": "bags"}
	elif t == "gear_rules":
		sec = "notes"
		_filters[sec] = {"page": "gear"}
	elif t.begins_with("notes_"):
		sec = "notes"
		_filters[sec] = {"page": t.trim_prefix("notes_")}
	elif t.begins_with("gallery_"):
		sec = "gallery"
		_filters[sec] = {"shelf": t.trim_prefix("gallery_")}
	elif t.begins_with("future"):
		sec = "future"
		if t != "future":
			_filters[sec] = {"cat": t}
	elif not _section(t).is_empty():
		sec = t
	if sec != was:
		_query = ""
		_fold_open = false
	if not _filters.has(sec):
		_filters[sec] = _default_filters(sec)
	_sec = sec


static func _default_filters(sec: String) -> Dictionary:
	match sec:
		"shapes", "uniques":
			return {"slot": "weapon"}  # the Armory opens on weapons, as the old shelves did
		"future":
			return {"cat": "future_terrains"}
		"notes":
			return {"page": "elites"}
		"gallery":
			return {"shelf": "heroes"}
	return {}


# ------------------------------------------------------------------ rail ---
static func _rail(m: Menus, parent: Control) -> void:
	var sc := ScrollContainer.new()
	sc.name = "CodexRail"
	sc.custom_minimum_size = Vector2(RAIL_W, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	sc.add_child(col)
	var grp := ""
	for s in SECTIONS:
		var sd: Dictionary = s
		if sd.get("dev", false) and not m.game.dev_mode:
			continue
		if String(sd["grp"]) != grp:
			grp = String(sd["grp"])
			if col.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 3)
				col.add_child(gap)
			var gl := m._lbl(col, grp.to_upper(), 10, UITheme.GOLD_DIM)
			gl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_rail_button(m, col, sd)


static func _rail_button(m: Menus, col: VBoxContainer, s: Dictionary) -> Button:
	var id := String(s["id"])
	var active := id == _sec
	var accent: Color = s.get("accent", ACC_GOLD)
	var b := Button.new()
	b.name = "CodexRail_" + id
	b.text = String(s["name"])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28 if m.game.touch_mode else 25)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT if active else MUTED)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.11) if active else Color(0, 0, 0, 0)
	normal.border_color = Color(accent, 0.9) if active else Color(0, 0, 0, 0)
	normal.border_width_left = 3
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 9.0
	normal.content_margin_right = 34.0  # room for the count
	normal.content_margin_top = 2.0
	normal.content_margin_bottom = 2.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent, 0.16) if active else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	col.add_child(b)
	var n := _section_count(m, id)
	if n > 0:
		var cl := Label.new()
		cl.text = str(n)
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", UITheme.GOLD_DIM if active else Color(0.45, 0.48, 0.56))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		cl.offset_left = -44.0
		cl.offset_right = -6.0
		cl.offset_top = -9.0
		cl.offset_bottom = 9.0
		b.add_child(cl)
	b.pressed.connect(func() -> void:
		m.game.sfx("ui_click")
		m.open_codex(id))
	return b


## The rail badge: how many entries a collection holds (0 = no badge).
static func _section_count(m: Menus, id: String) -> int:
	match id:
		"monsters":
			return _bestiary_kinds(m, false).size()
		"bosses":
			return _bestiary_kinds(m, true).size()
		"npcs":
			return _npc_entries().size()
		"shapes":
			return _shape_entries().size()
		"uniques":
			return Items.UNIQUES.size()
		"gems":
			return Items.GEM_STATS.size()
		"terrains":
			return Terrains.catalog_ids(false).size()
		"curios":
			return _curio_entries().size()
		"status":
			return _status_effects().size()
		"gallery":
			return _gallery_entries(m).size()
	return 0


# --------------------------------------------------------------- content ---
static func _build_content(m: Menus) -> void:
	var content: VBoxContainer = _ui["content"]
	var sec := _section(_sec)
	var kind := String(sec["kind"])
	var bar := HBoxContainer.new()
	bar.name = "CodexBar"
	bar.add_theme_constant_override("separation", 10)
	content.add_child(bar)
	var title := m._lbl(bar, _page_title(), 16, GOLD_TXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	UITheme.header(title)
	_ui["title"] = title
	var count := m._lbl(bar, "", 12, MUTED)
	count.name = "CodexCount"
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ui["count"] = count
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	if kind == "list":
		var search := LineEdit.new()
		search.name = "CodexSearch"
		search.placeholder_text = "Search"
		search.text = _query
		search.custom_minimum_size = Vector2(180, 30)
		search.clear_button_enabled = true
		search.add_theme_font_size_override("font_size", 13)
		search.text_changed.connect(func(t: String) -> void:
			_query = t
			_rebuild_split(m))
		bar.add_child(search)
		_ui["search"] = search
	var chips := HFlowContainer.new()
	chips.name = "CodexChips"
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	content.add_child(chips)
	_ui["chips"] = chips
	_build_chips(m)
	var split := HBoxContainer.new()
	split.name = "CodexSplit"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	content.add_child(split)
	_ui["split"] = split
	_rebuild_split(m)


static func _page_title() -> String:
	var sec := _section(_sec)
	var f: Dictionary = _filters.get(_sec, {})
	match _sec:
		"npcs":
			return "Folk of the Vale"
		"gallery":
			return "Gallery · " + _pair_label(GALLERY_SHELVES, String(f.get("shelf", "heroes")))
		"notes":
			return "Field notes · " + _pair_label(NOTE_PAGES, String(f.get("page", "elites")))
		"coop":
			return "Playing together"
		"future":
			return "Future · placeholders"
	return String(sec["name"])


static func _pair_label(pairs: Array, key: String) -> String:
	for p in pairs:
		if String(p[0]) == key:
			return String(p[1])
	return key


## Chip = the tab pill, shrunk to a filter row.
static func _chip(m: Menus, parent: Control, text: String, active: bool, accent: Color, cb: Callable) -> Button:
	var b := m._btn(parent, text, cb, accent if active else MUTED)
	UITheme.tab(b, active, accent)
	# A finger needs more than a pointer: taller chips on touch.
	b.custom_minimum_size.y = 32.0 if m.game.touch_mode else 26.0
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	for st in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(String(st)) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 9.0
			sb.content_margin_right = 9.0
			sb.content_margin_top = 3.0
			sb.content_margin_bottom = 3.0
	return b


static func _build_chips(m: Menus) -> void:
	var chips: HFlowContainer = _ui.get("chips")
	if chips == null or not is_instance_valid(chips):
		return
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	var f: Dictionary = _filters.get(_sec, {})
	var first := true
	for g in _chip_groups(m):
		var gd: Dictionary = g
		if not first:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			chips.add_child(gap)
		first = false
		var key := String(gd["key"])
		var accent: Color = gd.get("accent", ACC_GOLD)
		var cur := String(f.get(key, ""))
		if String(gd.get("all", "")) != "":
			_chip(m, chips, String(gd["all"]), cur == "", accent, func() -> void: _set_filter(m, key, ""))
		for opt in gd["opts"]:
			var val := String(opt[0])
			_chip(m, chips, String(opt[1]), cur == val, accent, func() -> void: _set_filter(m, key, val))
	chips.visible = chips.get_child_count() > 0


static func _set_filter(m: Menus, key: String, val: String) -> void:
	var f: Dictionary = _filters.get(_sec, {})
	if val == "":
		f.erase(key)
	else:
		f[key] = val
	_filters[_sec] = f
	# Deferred: the pressed chip is being freed by the rebuild it asked for.
	UICodex._refresh.call_deferred(m)


static func _refresh(m: Menus) -> void:
	# A chip can change the page (Gallery shelf, Field notes page, Future
	# category) — the bar title follows it.
	var title: Label = _ui.get("title")
	if title != null and is_instance_valid(title):
		title.text = _page_title()
	_build_chips(m)
	_rebuild_split(m)


## Filter groups per section: {key, all (label of the "any" chip, "" = none),
## opts [[value, label]...], accent}. Chapter chips list only chapters that
## actually hold entries.
static func _chip_groups(m: Menus) -> Array:
	var sec := _section(_sec)
	var accent: Color = sec.get("accent", ACC_GOLD)
	match _sec:
		"monsters":
			return [_chapter_group(_bestiary_chapters(m, false), accent),
				{"key": "type", "all": "", "opts": [["melee", "Melee"], ["ranged", "Ranged"]], "accent": accent}]
		"bosses":
			return [_chapter_group(_bestiary_chapters(m, true), accent)]
		"npcs":
			var chs: Array = []
			for e in _npc_entries():
				if not (String(e["chapter"]) in chs):
					chs.append(String(e["chapter"]))
			return [_chapter_group(chs, accent),
				{"key": "q", "all": "", "opts": [["1", "Quest givers"]], "accent": accent}]
		"terrains":
			var found := _terrain_zones()
			var tchs: Array = []
			for id in Terrains.catalog_ids(false):
				var ch := String(found.get(id, {}).get("chapter", ""))
				if ch != "" and not (ch in tchs):
					tchs.append(ch)
			return [_chapter_group(tchs, accent),
				{"key": "hz", "all": "", "opts": [["1", "Hazardous"], ["0", "Safe"]], "accent": accent}]
		"curios":
			var cgroups: Array = [{"key": "kind", "all": "All", "opts": [["quest", "Quest items"],
				["draughts", "Draughts & tonics"], ["synthesis", "Synthesis"], ["relics", "Relics & landmarks"]], "accent": accent}]
			# Under Draughts the full 85-bottle ladder shows; family + lane chips narrow it.
			if String(_filters.get("curios", {}).get("kind", "")) == "draughts":
				cgroups.append({"key": "fam", "all": "All families", "opts": [["health", "Health"], ["mana", "Mana"],
					["might", "Might"], ["ward", "Warding"], ["renewal", "Renewal"]], "accent": accent})
				cgroups.append({"key": "lane", "all": "Both lanes", "opts": [["accord", "Accord"], ["black", "Black market"]], "accent": accent})
			return cgroups
		"shapes", "uniques":
			var slots: Array = []
			for slot in Items.SLOTS:
				slots.append([String(slot), String(SLOT_LABEL.get(slot, String(slot).capitalize()))])
			var classes: Array = []
			for cls in Classes.CLASSES:
				classes.append([String(cls), String(Classes.CLASSES[cls]["name"])])
			var groups := [{"key": "slot", "all": "All slots", "opts": slots, "accent": accent},
				{"key": "cls", "all": "Any class", "opts": classes, "accent": accent}]
			if _sec == "uniques":
				groups.append({"key": "grade", "all": "", "opts": [["A", "A"], ["S", "S"]], "accent": accent})
			return groups
		"gems":
			return [{"key": "kind", "all": "All", "opts": [["regular", "Regular"], ["special", "Special"]], "accent": accent}]
		"gallery":
			return [{"key": "shelf", "all": "", "opts": GALLERY_SHELVES.duplicate(), "accent": accent}]
		"notes":
			return [{"key": "page", "all": "", "opts": NOTE_PAGES.duplicate(), "accent": accent}]
		"future":
			return [{"key": "cat", "all": "", "opts": FUTURE_CATS.duplicate(), "accent": accent}]
	return []


static func _chapter_group(chapters: Array, accent: Color) -> Dictionary:
	# Story order, not first-seen order; interludes trail the campaign, so a
	# standalone world's rows are still reachable from a chip.
	var ordered: Array = []
	for chid in _codex_worlds():
		if String(chid) in chapters:
			ordered.append([String(chid), _chapter_label(String(chid))])
	return {"key": "ch", "all": "All", "opts": ordered, "accent": accent}


static func _chapter_label(chid: String) -> String:
	if chid == "":
		return "—"
	if chid.begins_with("ch") and chid.substr(2).is_valid_int():
		return "Ch " + chid.substr(2)
	var ch := Story.chapter(chid)
	return String(ch.get("name", chid)) if not ch.is_empty() else chid


static func _matches(text: String) -> bool:
	var q := _query.strip_edges().to_lower()
	return q == "" or text.to_lower().contains(q)


# ------------------------------------------------------- ledger + detail ---
static func _rebuild_split(m: Menus) -> void:
	_build_gen += 1  # a still-streaming ledger stops at its next frame
	var split: HBoxContainer = _ui.get("split")
	if split == null or not is_instance_valid(split):
		return
	for c in split.get_children():
		split.remove_child(c)
		c.queue_free()
	var sec := _section(_sec)
	if String(sec["kind"]) == "list":
		_build_list_and_detail(m, split)
	else:
		_build_page(m, split)


static func _build_list_and_detail(m: Menus, split: HBoxContainer) -> void:
	var rows := _rows(m)
	var total := _section_count(m, _sec)
	var count: Label = _ui.get("count")
	if count != null and is_instance_valid(count):
		count.text = ("%d of %d" % [rows.size(), total]) if rows.size() != total else ("%d entries" % total)
	var sel := String(_selected.get(_sec, ""))
	var found := false
	for r in rows:
		if String(r["key"]) == sel:
			found = true
			break
	if not found:
		sel = String(rows[0]["key"]) if not rows.is_empty() else ""
		_selected[_sec] = sel
	# The ledger.
	var lsc := ScrollContainer.new()
	lsc.name = "CodexLedger"
	lsc.custom_minimum_size = Vector2(LIST_W, 0)
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.follow_focus = true  # ↑/↓ walk the rows and the list keeps up
	split.add_child(lsc)
	var lcol := VBoxContainer.new()
	lcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lcol.add_theme_constant_override("separation", 0)
	lsc.add_child(lcol)
	_ui["ledger"] = lcol
	# The detail.
	var dsc := ScrollContainer.new()
	dsc.name = "CodexDetail"
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(dsc)
	var dcol := VBoxContainer.new()
	dcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dcol.add_theme_constant_override("separation", 8)
	dsc.add_child(dcol)
	_ui["detail"] = dcol
	if rows.is_empty():
		var e := m._lbl(lcol, "Nothing matches — clear a chip or the search.", 13, MUTED)
		e.custom_minimum_size = Vector2(LIST_W - 24, 0)
		return
	var jobs: Array = []
	for r in rows:
		var rd: Dictionary = r
		jobs.append(func() -> void:
			var b := _row_button(m, lcol, rd, String(rd["key"]) == sel)
			if String(rd["key"]) == sel:
				_scroll_to_card(m, b))
	_build_chunked(m, lcol, jobs, 24)
	_build_detail(m, dcol, sel)


static func _select(m: Menus, key: String) -> void:
	if String(_selected.get(_sec, "")) == key:
		return
	_selected[_sec] = key
	_fold_open = false
	var lcol: VBoxContainer = _ui.get("ledger")
	if lcol != null and is_instance_valid(lcol):
		for c in lcol.get_children():
			if c is Button and c.has_meta("row"):
				_style_row(c, String(c.get_meta("key")) == key, c.get_meta("row"))
	var dcol: VBoxContainer = _ui.get("detail")
	if dcol != null and is_instance_valid(dcol):
		for c in dcol.get_children():
			dcol.remove_child(c)
			c.queue_free()
		_build_detail(m, dcol, key)


static func _row_button(m: Menus, col: VBoxContainer, r: Dictionary, selected: bool) -> Button:
	var key := String(r["key"])
	var b := Button.new()
	b.name = ("CodexRow_" + key).validate_node_name()
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.focus_mode = Control.FOCUS_ALL  # arrows walk the ledger
	b.set_meta("key", key)
	b.set_meta("row", r)
	_style_row(b, selected, r)
	col.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8.0
	h.offset_right = -8.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	b.add_child(h)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = r.get("icon")
	if tex != null:
		ic.texture = tex
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if maxi(tex.get_width(), tex.get_height()) >= 96 \
			else CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(ic)
	var tb := VBoxContainer.new()
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb.add_theme_constant_override("separation", 0)
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tb)
	var nm := Label.new()
	nm.text = String(r["name"])
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_color", r.get("name_color", Color(0.92, 0.93, 0.98)))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb.add_child(nm)
	var sub_txt := String(r.get("sub", ""))
	if sub_txt != "":
		var sub := Label.new()
		sub.text = sub_txt
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", r.get("sub_color", MUTED))
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(sub)
	var tag_txt := String(r.get("tag", ""))
	if tag_txt != "":
		var tag := Label.new()
		tag.text = tag_txt
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.custom_minimum_size = Vector2(44, 0)
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", r.get("tag_color", Color(0.45, 0.48, 0.56)))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tag)
	b.pressed.connect(func() -> void: _select(m, key))
	b.focus_entered.connect(func() -> void: _select(m, key))
	return b


static func _style_row(b: Button, selected: bool, r: Dictionary) -> void:
	var accent: Color = r.get("accent", ACC_GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.09) if selected else Color(0, 0, 0, 0)
	normal.border_color = Color(accent, 0.95) if selected else Color(0.28, 0.30, 0.38, 0.18)
	normal.border_width_left = 3
	normal.border_width_bottom = 0 if selected else 1
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent, 0.14) if selected else Color(1, 1, 1, 0.035)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(accent, 0.55)
	focus.border_width_left = 3
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)


## Rows of the open collection: [{key, name, sub, tag, icon, accent, ...}].
static func _rows(m: Menus) -> Array:
	match _sec:
		"monsters":
			return _bestiary_rows(m, false)
		"bosses":
			return _bestiary_rows(m, true)
		"npcs":
			return _npc_rows(m)
		"terrains":
			return _terrain_rows(m)
		"curios":
			return _curio_rows(m)
		"shapes":
			return _shape_rows(m)
		"uniques":
			return _unique_rows(m)
	return []


static func _build_detail(m: Menus, dcol: VBoxContainer, key: String) -> void:
	if key == "":
		return
	match _sec:
		"monsters":
			_enemy_card(m, dcol, key, false, false, false, DETAIL_W)
		"bosses":
			_enemy_card(m, dcol, key, true, false, false, DETAIL_W)
		"npcs":
			_npc_detail(m, dcol, key)
		"terrains":
			var found := _terrain_zones()
			_terrain_card(m, dcol, key, String(found.get(key, {}).get("zone", "")), false, DETAIL_W)
		"curios":
			_curio_detail(m, dcol, key)
		"shapes":
			_shape_detail(m, dcol, key)
		"uniques":
			_unique_detail(m, dcol, key)


# ------------------------------------------------------------- bestiary ---
## Kinds the bestiary lists: placed in a zone (or a chapter's final boss),
## not placeholder, and — for mobs — worth XP or gold (boss-summon props are
## scenery). Table order.
static func _bestiary_kinds(m: Menus, bosses: bool) -> Array:
	var used := _used_enemy_kinds()
	var out: Array = []
	for kind in Story.ALL_ENEMIES:
		if (kind in m.BOSS_KINDS) != bosses:
			continue
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if not bosses and st.get("xp", 0) <= 0 and st.get("gold", 0) <= 0:
			continue
		if not used.has(kind) or st.get("placeholder", false):
			continue
		out.append(String(kind))
	return out


## kind -> the FIRST world that places it (zone spawn, zone boss or final boss).
static func _kind_chapters() -> Dictionary:
	var out := {}
	var worlds: Dictionary = _codex_worlds()
	for chid in worlds:
		var ch: Dictionary = worlds[chid]
		for zone in ch.get("zones", []):
			for e in zone.get("enemies", []):
				if e is Array and e.size() > 0 and not out.has(String(e[0])):
					out[String(e[0])] = String(chid)
			var b := String(zone.get("boss", ""))
			if b != "" and not out.has(b):
				out[b] = String(chid)
		var fb := String(ch.get("final_boss", ""))
		if fb != "" and not out.has(fb):
			out[fb] = String(chid)
	return out


static func _bestiary_chapters(m: Menus, bosses: bool) -> Array:
	var chap := _kind_chapters()
	var out: Array = []
	for kind in _bestiary_kinds(m, bosses):
		var ch := String(chap.get(kind, ""))
		if ch != "" and not (ch in out):
			out.append(ch)
	return out


static func _bestiary_rows(m: Menus, bosses: bool) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var chap := _kind_chapters()
	var order: Array = _codex_worlds().keys()
	var out: Array = []
	for kind in _bestiary_kinds(m, bosses):
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		var ch := String(chap.get(kind, ""))
		if f.has("ch") and ch != String(f["ch"]):
			continue
		if f.has("type") and (String(f["type"]) == "ranged") != bool(st["ranged"]):
			continue
		var nm := String(st["name"])
		if not _matches(nm):
			continue
		var sub := _chapter_label(ch) + " · " + ("Ranged caster" if st["ranged"] else "Melee")
		if bosses:
			var mechs: Array = st.get("mechanics", [])
			if not mechs.is_empty():
				sub += " · %d mechanics" % mechs.size()
		else:
			var kills: int = int(m.game.kill_counts.get(kind, 0))
			if kills < Lore.threshold(kind):
				sub += " · lore buried"
		out.append({"key": kind, "name": nm, "sub": sub, "tag": "Lv %d" % int(st.get("level", 1)),
			"tag_color": UITheme.GOLD_DIM, "icon": _enemy_icon(String(st["sprite"])),
			"name_color": Color(1, 0.6, 0.6) if bosses else Color(0.92, 0.93, 0.98),
			"accent": ACC_BOSS if bosses else ACC_MOB,
			"_ord": [order.find(ch) if order.has(ch) else 99, int(st.get("level", 1)), nm]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: Array = a["_ord"]
		var ob: Array = b["_ord"]
		if oa[0] != ob[0]:
			return oa[0] < ob[0]
		if oa[1] != ob[1]:
			return oa[1] < ob[1]
		return String(oa[2]) < String(ob[2]))
	return out


## One boxed card per monster/boss: icon, name, Lv, live stats, growth,
## projections, traits and lore — the DETAIL of a bestiary row (w =
## DETAIL_W) and the card the dev-only Future shelf lists (w = PAGE_W). A
## boss with authored `mechanics` grows an inline "Mechanics & Tells" fold
## (2026-08-15: no more separate detail screen + Back button).
## The codex is an ARCHIVE, not a scale chart (owner 2026-07-25): every
## portrait — wolf or god-king — is normalized to one box, so the shelf reads
## as a catalogue instead of a size comparison. Cropping is what makes that
## normalization honest: raw frames carry wildly different padding (a 224px
## boss square vs a tight 32px mob), and a multi-frame STRIP would otherwise
## squeeze all its frames into the box. Alpha threshold (not get_used_rect)
## so a stray 1-alpha pixel in a padded export can't defeat the crop.
## Cached per sprite for the session.
static func _enemy_card(m: Menus, list: VBoxContainer, kind: String, is_boss: bool, detail := false, placeholder := false, w := PAGE_W) -> PanelContainer:
	var st: Dictionary = Story.ALL_ENEMIES[kind]
	# Codex honesty: display what the fight actually deals/has
	# (TTK and damage multipliers included), not raw table rows.
	var live: Dictionary = Story.enemy_stats_at(kind, int(st.get("level", 1)))
	var chap := _kind_chapters()

	var box := UITheme.card(list, ACC_BOSS if is_boss else UITheme.GOLD_DIM, 12.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _enemy_icon(String(st["sprite"]))
	icon.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var text_w := w - ICON_BOX - 12.0

	var nm_txt: String = String(st["name"]) + ("   [placeholder]" if placeholder else "")
	var name_col: Color = Color(0.72, 0.68, 0.55) if placeholder else (Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
	var name_l := m._lbl(info, nm_txt, 16, name_col)
	name_l.custom_minimum_size = Vector2(text_w, 0)
	var meta := m._lbl(info, "Lv %d   ·   %s   ·   %s" % [int(st.get("level", 1)),
		_chapter_label(String(chap.get(kind, ""))), "Ranged caster" if st["ranged"] else "Melee"], 12, Color(0.6, 0.7, 0.85))
	meta.custom_minimum_size = Vector2(text_w, 0)

	# Aligned stat tiles (label over value) — five across fits the detail column.
	var stat_pairs: Array = [["HP", int(live["hp"])], ["DMG", int(live["dmg"])], ["SPD", int(st["speed"])],
			["XP", live["xp"]], ["Gold", live.get("gold", 0)]]
	# EVA rides along only when the kind HAS evasion (nearly all ship 0.0, and a
	# column of zeroes is noise). A foe you must answer with DEX can never be an
	# invisible wall — the codex never lies about the wall (Stats.resolve).
	var kind_eva: float = float(live.get("eva", 0.0))
	if kind_eva > 0.0:
		stat_pairs.append(["EVA", "%d%%" % int(kind_eva * 100.0)])
	var grid := GridContainer.new()
	# Five tiles fit the detail column; a sixth (EVA) wraps into two rows of three.
	grid.columns = 3 if stat_pairs.size() > 5 else 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	info.add_child(grid)
	for pair in stat_pairs:
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 0)
		tile.custom_minimum_size = Vector2(56, 0)
		grid.add_child(tile)
		var sl := m._lbl(tile, String(pair[0]).to_upper(), 10, Color(0.5, 0.53, 0.62))
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var sv := m._lbl(tile, str(pair[1]), 14, Color(0.9, 0.92, 0.98))
		sv.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Scaling: growth + projections, in two quiet sublines.
	var at25 := Story.enemy_stats_at(kind, 25)
	var at50 := Story.enemy_stats_at(kind, 50)
	var g1 := m._lbl(col, "Growth per level:   HP +%d%%   ·   DMG +%d%%" %
		[int(st.get("hp_g", 0.1) * 100), int(st.get("dmg_g", 0.1) * 100)], 12, Color(0.55, 0.65, 0.8))
	g1.custom_minimum_size = Vector2(w, 0)
	var g2 := m._lbl(col, "Projected:   Lv 25 → %d HP, %d DMG   ·   Lv 50 → %d HP, %d DMG" %
		[int(at25["hp"]), int(at25["dmg"]), int(at50["hp"]), int(at50["dmg"])], 12, Color(0.5, 0.55, 0.66))
	g2.custom_minimum_size = Vector2(w, 0)

	# Identity traits (2026-07-07): each kind's gimmick, so the
	# player learns the counter (kill the healer, dodge the pounce).
	for tr in st.get("traits", []):
		var td: String = Enemy.TRAIT_DESC.get(String(tr), "")
		if td != "":
			var tl := m._lbl(col, "◆ " + td, 12, Color(0.7, 0.85, 0.7))
			tl.custom_minimum_size = Vector2(w, 0)

	# Codex completion (retention roadmap #5): the kill tally, and
	# the lore this character has (or hasn't) earned the right to read.
	var kills: int = int(m.game.kill_counts.get(kind, 0))
	var need := Lore.threshold(kind)
	if kills >= need:
		var ll := m._lbl(col, "❝ %s ❞" % Lore.entry(kind), 13, Color(0.85, 0.78, 0.6))
		ll.custom_minimum_size = Vector2(w, 0)
	else:
		m._lbl(col, "Slain: %d / %d — its lore is still buried." % [kills, need],
			12, Color(0.5, 0.55, 0.66))

	# Bosses with authored mechanics: the Mechanics & Tells fold, right here.
	var mechs: Array = st.get("mechanics", []).duplicate(true)
	var cast_move: Dictionary = preload("res://scripts/boss_cast.gd").MOVES.get(kind, {})
	if is_boss and not cast_move.is_empty():
		mechs.push_front({"name": String(cast_move.name) + " — interrupt window",
			"tell": "Amber body brackets and an INTERRUPT bar. The white fuse counts down to the cast.",
			"counter": "Deal damage to fill the pressure bar before the fuse ends. Close hits contribute more; damage over time contributes less. A break cancels the cast and opens a brief +25% damage window. Otherwise dodge its normal ground warning."})
	if is_boss and not detail and not mechs.is_empty():
		var fold := VBoxContainer.new()
		fold.add_theme_constant_override("separation", 6)
		fold.visible = _fold_open
		var toggle := func() -> void:
			fold.visible = not fold.visible
			_fold_open = fold.visible
		var fb := m._btn(col, "", toggle, Color(1, 0.7, 0.7))
		fb.name = "CodexMechanicsFold"
		fb.focus_mode = Control.FOCUS_NONE
		var fold_lbl := func() -> void:
			fb.text = "  %s Mechanics & Tells  ·  %d  " % ["▾" if fold.visible else "▸", mechs.size()]
		fold_lbl.call()
		fb.pressed.connect(fold_lbl)
		col.add_child(fold)
		for mech in mechs:
			var mbox := VBoxContainer.new()
			mbox.add_theme_constant_override("separation", 3)
			UITheme.card(fold, ACC_BOSS, 10.0).add_child(mbox)
			m._lbl(mbox, "◆ " + String(mech.get("name", "")), 14, Color(1, 0.7, 0.7))
			var tl2 := m._lbl(mbox, "Tell — " + String(mech.get("tell", "")), 12, Color(0.85, 0.82, 0.7))
			tl2.custom_minimum_size = Vector2(w - 24, 0)
			var cl2 := m._lbl(mbox, "Counter — " + String(mech.get("counter", "")), 12, Color(0.7, 0.9, 0.7))
			cl2.custom_minimum_size = Vector2(w - 24, 0)

	# Dev launcher only: TRANSFORM — wear this creature over the hero to
	# road-test its walk/attack clips in place (dev_morph.gd drives the puppet;
	# the ability keys play the clips). The same card reverts.
	if m.game.dev_mode and m.game.player != null:
		var mk := String(kind)
		var cur: DevMorph = m.game.player.dev_morph
		if cur != null and cur.kind == mk:
			m._btn(col, "  ⟲ Revert transform  ", func() -> void:
				DevMorph.stop(m.game.player)
				m.close(), Color(0.7, 0.95, 0.85))
		else:
			m._btn(col, "  ⇄ Transform  ", func() -> void:
				DevMorph.start(m.game.player, mk)
				m.close(), Color(0.7, 0.95, 0.85))
	return box


# ----------------------------------------------------------------- folk ---
## Where a social-room wanderer is met: the roll picks a fresh room per run,
## so no single zone name is true for them.
const WANDER_WHERE := "a quiet room on the road"


## Fold one npc definition into the deduped cast (or let it upgrade the face
## already listed). Shared by the authored zone `npcs` arrays and the
## social-wanderer pools, which spawn through a different path entirely.
static func _add_npc_entry(seen: Dictionary, entries: Array, npc: Dictionary, chid: String, where: String) -> void:
	# Placeholder NPCs (extracted art wired for review) live on the
	# dev-only Future > NPCs shelf, never here.
	if npc.get("placeholder", false):
		return
	var spr: String = String(npc.get("sprite", ""))
	if spr == "":
		return
	var quest := _gives_quest(String(npc.get("convo", "")))
	if seen.has(spr):
		# Same face elsewhere can still upgrade its role line.
		if quest:
			seen[spr]["quest"] = true
		return
	var nm := _npc_name(npc)
	if nm == "" or nm == "Narrator":
		return  # narrator-voiced scenery: a lore read, not a person
	var e := {"name": nm, "sprite": spr, "quest": quest, "chapter": chid, "zone": where}
	seen[spr] = e
	entries.append(e)


## The speaking cast, deduped by sprite: [{name, sprite, quest, chapter, zone}].
## Same derivation the old NPC shelf used, plus where each was first met.
static func _npc_entries() -> Array:
	var seen := {}
	var entries: Array = []
	var any_merchant := false
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			if zone.has("merchant"):
				any_merchant = true
			for npc in zone.get("npcs", []):
				var nd: Dictionary = npc
				_add_npc_entry(seen, entries, nd, String(chid), String(zone.get("name", "")))
		# Social rooms roll ONE face from the chapter's wanderer pool instead
		# of an authored zone npc (game_world._spawn_wanderer), so none of
		# these people live in a zone's `npcs` array — quest givers among
		# them. Without this pass the codex lists not one of them.
		for w in Story.wanderers_for(String(chid)):
			var wd: Dictionary = w
			_add_npc_entry(seen, entries, wd, String(chid), WANDER_WHERE)
	# The merchant spawns from the zones' `merchant` spot, not an npcs list —
	# but they're absolutely someone you speak to.
	if any_merchant and not seen.has("merchant"):
		entries.append({"name": "Merchant", "sprite": "merchant", "quest": false, "chapter": "", "zone": "the road"})
	return entries


static func _npc_rows(_m: Menus) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var out: Array = []
	for e in _npc_entries():
		if f.has("ch") and String(e["chapter"]) != String(f["ch"]):
			continue
		var role := _npc_role(String(e["sprite"]), bool(e.get("quest", false)))
		if f.has("q") and not bool(e.get("quest", false)):
			continue
		if not _matches(String(e["name"]) + " " + role + " " + String(e["zone"])):
			continue
		out.append({"key": String(e["sprite"]), "name": String(e["name"]),
			"sub": role if role != "" else String(e["zone"]), "tag": _chapter_label(String(e["chapter"])),
			"icon": _enemy_icon(String(e["sprite"])), "accent": ACC_NPC})
	return out


static func _npc_detail(m: Menus, list: VBoxContainer, sprite: String) -> void:
	var e := {}
	for x in _npc_entries():
		if String(x["sprite"]) == sprite:
			e = x
			break
	if e.is_empty():
		return
	var box := UITheme.card(list, ACC_NPC, 12.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	# Framed pixel portrait, dialogue-box style: gold frame, dark well,
	# nearest-neighbor upscale so the sprite reads chunky, not smeared.
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(72, 72)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.1, 0.09, 0.15)
	fsb.border_color = Color(UITheme.GOLD, 0.75)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var icon := TextureRect.new()
	icon.texture = _enemy_icon(sprite)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var text_w := DETAIL_W - 72.0 - 14.0
	var nm2 := m._lbl(info, String(e["name"]), 16, Color(0.9, 0.92, 0.98))
	nm2.custom_minimum_size = Vector2(text_w, 0)
	var role := _npc_role(String(e["sprite"]), bool(e.get("quest", false)))
	if role != "":
		var rl := m._lbl(info, role, 13, Color(0.75, 0.7, 0.5))
		rl.custom_minimum_size = Vector2(text_w, 0)
	var where := String(e.get("zone", ""))
	var chl := _chapter_label(String(e.get("chapter", "")))
	if where != "":
		var wl := m._lbl(info, "First met in %s%s." % [where, "" if chl == "—" else " · " + chl], 12, MUTED)
		wl.custom_minimum_size = Vector2(text_w, 0)
	var bio: String = String(Story.NPC_LORE.get(sprite, "Someone you can hold a conversation with on the road. Talk to them again after a chapter beat, and the same face can carry a new errand."))
	var dl := m._lbl(info, bio, 12, Color(0.55, 0.58, 0.66))
	dl.custom_minimum_size = Vector2(text_w, 0)


# ------------------------------------------------------------- terrains ---
## terrain id -> {zone, chapter} of the FIRST zone that uses it.
static func _terrain_zones() -> Dictionary:
	var found_in := {}
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid]["zones"]:
			var tid := String(zone.get("terrain", ""))
			if tid != "" and not found_in.has(tid):
				found_in[tid] = {"zone": String(zone["name"]), "chapter": String(chid)}
	return found_in


static func _terrain_hazards(t: Dictionary) -> Array:
	var quirks: Array = []
	for p in t.get("patches", []):
		var d: String = PATCH_DESC.get(p["type"], "")
		if p.get("drift", false):
			d += " — and the clouds DRIFT, so keep moving"
		quirks.append(d)
	if t.get("event", "") != "":
		quirks.append(EVENT_DESC.get(t["event"], ""))
	if t.get("mp_boost", false):
		quirks.append("Latent magic — your mana recovers much faster here")
	if t.has("river"):
		quirks.append("Rivers cross these lands — wading leaves you DAMP (-%d%% move speed for %ds) and slows monsters; the bridge crosses dry" % [
			int(round((1.0 - Balance.DAMP_SLOW_MULT) * 100.0)), int(Balance.DAMP_DURATION)])
	return quirks


## A swatch of the terrain's ground: the procedural room surface at 8×8
## tiles (its top-left corner is pure ground; the middle carries the path
## plaza), cached by Art.ground itself. `crop` = the pure-ground 32px corner.
static func _terrain_swatch(id: String, crop: bool) -> Texture2D:
	var t: Dictionary = Terrains.DATA[id]
	var tex: Texture2D = Art.ground_preview(String(t.get("ground", "grass")), String(t.get("path", "dirt")), 8, 8, 7, [])
	if tex == null or not crop:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, 32, 32)
	return at


## The detail's PREVIEW: a whole room's worth of the terrain — 24×12 tiles of
## ground with the road running west→east — the way Art.ground paints it under
## the hero (owner 2026-08-15: a big picture, the text beneath). Cached by
## Art.ground; the terrain tint rides on the TextureRect so it reads as it
## does in the world.
const PREVIEW_TILES_W := 24
const PREVIEW_TILES_H := 12
static func _terrain_preview(id: String) -> Texture2D:
	var t: Dictionary = Terrains.DATA[id]
	return Art.ground_preview(String(t.get("ground", "grass")), String(t.get("path", "dirt")),
		PREVIEW_TILES_W, PREVIEW_TILES_H, 11, ["W", "E"])


static func _terrain_rows(_m: Menus) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var found := _terrain_zones()
	var out: Array = []
	for id in Terrains.catalog_ids(false):
		# Placeholder terrains (authored from the asset packs, unplaced) live
		# on the dev-only Future > Terrains shelf, never on the player list.
		var t: Dictionary = Terrains.DATA[id]
		var fi: Dictionary = found.get(id, {})
		var ch := String(fi.get("chapter", ""))
		if f.has("ch") and ch != String(f["ch"]):
			continue
		var hz := _terrain_hazards(t)
		if f.has("hz") and (String(f["hz"]) == "1") != (not hz.is_empty()):
			continue
		var nm := String(t["name"])
		var zone := String(fi.get("zone", ""))
		if not _matches(nm + " " + zone):
			continue
		out.append({"key": String(id), "name": nm,
			"sub": (zone if zone != "" else "Unassigned terrain") + " · " + String(AMBIENT_DESC.get(t.get("ambient", ""), "still air")),
			"tag": "hazard" if not hz.is_empty() else "safe",
			"tag_color": Color(1.0, 0.7, 0.5) if not hz.is_empty() else Color(0.45, 0.48, 0.56),
			"icon": _terrain_swatch(String(id), true), "accent": ACC_GOLD})
	return out


## One terrain card: name + where-it-appears, weather line, hazard/quirk
## lines. The DETAIL of a Terrains row (w = DETAIL_W) and the card the
## dev-only Future shelf lists (w = PAGE_W) — `ph` adds the [placeholder]
## tag, a dev-panel hint and the prop roster.
static func _terrain_card(m: Menus, list: VBoxContainer, id: String, where: String, ph: bool, w := PAGE_W) -> void:
	var t: Dictionary = Terrains.DATA[id]
	var box := UITheme.card(list, UITheme.GOLD_DIM, 12.0)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	box.add_child(info)
	# The picture first — a room of this ground with its road, framed like a
	# window onto the zone — then the words beneath it.
	var pw := minf(w, float(PREVIEW_TILES_W * 16))
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.03, 0.03, 0.05)
	fsb.border_color = Color(UITheme.GOLD_DIM, 0.8)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(6)
	fsb.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(pw + 8, pw * PREVIEW_TILES_H / PREVIEW_TILES_W + 8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(frame)
	var sw := TextureRect.new()
	sw.texture = _terrain_preview(id)
	sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sw.modulate = t.get("tint", Color(1, 1, 1))  # the world's own light on it
	frame.add_child(sw)
	var text_w := w

	var name_l := m._lbl(info, String(t["name"]) + ("   [placeholder]" if ph else ""), 16, Color(0.72, 0.68, 0.55) if ph else Color(1, 1, 1))
	name_l.custom_minimum_size = Vector2(text_w, 0)
	var where_txt: String = where
	if where_txt == "":
		where_txt = "Dev panel only" if ph else "Unassigned terrain"
	var found := _terrain_zones()
	var chl := _chapter_label(String(found.get(id, {}).get("chapter", "")))
	var where_l := m._lbl(info, where_txt + ("" if chl == "—" or where == "" else "   ·   " + chl), 13,
		Color(0.95, 0.85, 0.5) if where != "" else Color(0.55, 0.58, 0.66))
	where_l.custom_minimum_size = Vector2(text_w, 0)

	# Authored atmosphere line (Terrains.TERRAIN_LORE) — the world's own voice on
	# the place, above the mechanical weather/hazard read.
	var lore: String = Terrains.TERRAIN_LORE.get(id, "")
	if lore != "":
		var ll := m._lbl(info, lore, 12, Color(0.66, 0.62, 0.72))
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(text_w, 0)

	var amb: String = t.get("ambient", "")
	var wl := m._lbl(info, "Weather:   " + String(AMBIENT_DESC.get(amb, "still air")),
		13, Color(0.7, 0.72, 0.78))
	wl.custom_minimum_size = Vector2(text_w, 0)

	var quirks := _terrain_hazards(t)
	if quirks.is_empty():
		quirks.append("No hazards — safe ground")
	for q in quirks:
		var ql := m._lbl(info, "◆ " + String(q), 13, Color(0.55, 0.65, 0.8))
		ql.custom_minimum_size = Vector2(text_w, 0)

	# The Future shelf also lists the prop kit so the owner can judge the set.
	if ph:
		var parts: Array = []
		for pool in [["fill", "obstacles"], ["decor", "decor"], ["accents", "accents"]]:
			var names: Array = _uniq(t.get(pool[1], []))
			if not names.is_empty():
				parts.append("%s: %s" % [pool[0], ", ".join(names)])
		var rl := m._lbl(info, "Props —  " + "   ·   ".join(parts), 12, Color(0.6, 0.66, 0.63))
		rl.custom_minimum_size = Vector2(text_w, 0)


# --------------------------------------------------------------- curios ---
## Player-facing curio entries — SHIPPED content only (placeholders live on
## the dev-only Future shelf): quest items, the representative draught shelf,
## the synthesis capstone and shipped relics. [{key, kind, name, desc, sprite, tex}]
static func _curio_entries() -> Array:
	var out: Array = []
	var ids: Array = Story.ALL_QUEST_ITEMS.keys()
	ids.sort()
	for id in ids:
		var q: Dictionary = Story.ALL_QUEST_ITEMS[id]
		if q.get("placeholder", false):
			continue
		out.append({"key": "q:" + String(id), "kind": "quest", "name": String(q.get("name", id)),
			"desc": String(q.get("desc", "")), "sprite": String(q.get("icon", "")), "tex": null})
	# Graded potions (CONSUMABLE_GRADES) run F→S in two lanes — the Accord (clean)
	# and the Black Market (laced, cut with blightwater). The FULL ladder: all 85
	# bottles in Items.potion_specs order (family → shape → lane → grade), so the
	# shelf reads as the grouped matrix; the fam/lane chips narrow it further.
	for spec in Items.potion_specs():
		var pot := Items.make_potion(String(spec["family"]), String(spec["shape"]),
			String(spec["grade"]), String(spec["lane"]))
		if pot.is_empty():
			continue
		# consumable_icon, NOT icon_for — potion/stone items carry no gear slot.
		# "lore" = the authored GearFlavor line (effect stays in "desc").
		out.append({"key": "p:" + String(pot["id"]), "kind": "draughts", "name": String(pot["name"]),
			"desc": String(pot.get("desc", "")), "sprite": "", "tex": Art.consumable_icon(pot),
			"lore": GearFlavor.of(pot),
			"family": String(spec["family"]), "shape": String(spec["shape"]),
			"lane": String(spec["lane"]), "grade": String(spec["grade"])})
	# The Recall scroll rides the draught shelf as the lone utility bottle.
	var recall := Items.make_recall_scroll()
	out.append({"key": "p:recall", "kind": "draughts", "name": String(recall["name"]),
		"desc": String(recall.get("desc", "")), "sprite": "", "tex": Art.consumable_icon(recall),
		"lore": GearFlavor.of(recall)})
	# The synthesis capstone (CONSUMABLE_GRADES §9): the Alkahest Codex + the
	# Grand potions Kesh mints from it (a clean S + a laced A → a modest step
	# above S, no drawback). Synthesis-only — never sold. A representative shelf.
	var codex_synth := [
		Items.make_alkahest_codex(),
		Items.make_grand_potion("health_instant"),
		Items.make_grand_potion("mana_instant"),
		Items.make_grand_potion("might"),
		Items.make_grand_potion("ward"),
		Items.make_grand_potion("renewal"),
	]
	var si := 0
	for item in codex_synth:
		out.append({"key": "s:%d" % si, "kind": "synthesis", "name": String(item["name"]),
			"desc": String(item.get("desc", "")), "sprite": "", "tex": Art.consumable_icon(item),
			"lore": GearFlavor.of(item)})
		si += 1
	# Relic entries carry an optional "group" (armory/supplies live in the
	# Future tab until promoted); the player shelf shows SHIPPED relics only.
	var rids: Array = Story.ALL_RELICS.keys()
	rids.sort()
	for id in rids:
		var r: Dictionary = Story.ALL_RELICS[id]
		if r.get("placeholder", false) or String(r.get("group", "")) != "":
			continue
		out.append({"key": "r:" + String(id), "kind": "relics", "name": String(r.get("name", id)),
			"desc": String(r.get("lore", "")), "sprite": String(r.get("sprite", "")), "tex": null})
	return out


const CURIO_KIND_LABEL := {"quest": "Quest item", "draughts": "Draught", "synthesis": "Synthesis", "relics": "Relic"}


static func _curio_icon(e: Dictionary) -> Texture2D:
	var tex: Texture2D = e.get("tex")
	if tex != null:
		return tex
	var spr := String(e.get("sprite", ""))
	return Art.tex(spr) if spr != "" else null


static func _curio_rows(_m: Menus) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var kind_f := String(f.get("kind", ""))
	var out: Array = []
	for e in _curio_entries():
		var ek := String(e["kind"])
		if kind_f != "" and ek != kind_f:
			continue
		# Family / lane chips narrow the draught ladder (shown only under Draughts).
		if kind_f == "draughts":
			if f.has("fam") and String(e.get("family", "")) != String(f["fam"]):
				continue
			if f.has("lane") and String(e.get("lane", "")) != String(f["lane"]):
				continue
		if not _matches(String(e["name"]) + " " + String(e["desc"]) + " " + String(e.get("lore", ""))):
			continue
		var row := {"key": String(e["key"]), "name": String(e["name"]), "sub": _curio_sub(e),
			"tag": String(CURIO_KIND_LABEL.get(ek, "")), "icon": _curio_icon(e), "accent": ACC_GOLD}
		# Draughts scan by tier: a grade-colored letter replaces the generic tag.
		var g := String(e.get("grade", ""))
		if ek == "draughts" and g != "" and Items.GRADE_COLOR.has(g):
			row["tag"] = g
			row["tag_color"] = Items.GRADE_COLOR[g]
			row["name_color"] = Items.GRADE_COLOR[g]
		out.append(row)
	return out


## Row subtitle: draughts show their group coordinate (family · shape · lane) so
## the ladder reads as the grouped matrix; everything else shows its blurb.
static func _curio_sub(e: Dictionary) -> String:
	if String(e.get("kind", "")) != "draughts":
		return String(e.get("desc", ""))
	var fam := String(e.get("family", ""))
	if fam == "":
		return String(e.get("desc", ""))   # the Recall scroll — no family coordinate
	var lane_l := "Black market" if String(e.get("lane", "")) == "black" else "Accord"
	var fam_l: String = {"health": "Health", "mana": "Mana", "might": "Might",
		"ward": "Warding", "renewal": "Renewal"}.get(fam, fam.capitalize())
	if fam == "health" or fam == "mana":
		return "%s · %s · %s" % [fam_l, String(e.get("shape", "")).capitalize(), lane_l]
	return "%s · %s" % [fam_l, lane_l]


static func _curio_detail(m: Menus, list: VBoxContainer, key: String) -> void:
	for e in _curio_entries():
		if String(e["key"]) == key:
			var tex: Texture2D = e.get("tex")
			_curio_card(m, list, String(e["name"]), String(e["desc"]), String(e.get("sprite", "")), false, tex, DETAIL_W - 62.0)
			# The authored flavor line (draughts/synthesis carry it separately from
			# their mechanical effect; relics fold lore into desc, so skip there).
			var flav := String(e.get("lore", ""))
			if flav != "":
				var fl := m._lbl(list, flav, 12, Color(0.66, 0.62, 0.72))
				fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				fl.custom_minimum_size = Vector2(DETAIL_W, 0)
			var kl := m._lbl(list, {"quest": "Keepsakes and story tokens ride in your bag until their moment comes.",
				"draughts": "Graded F→S in two lanes: the Accord (clean, chartered) and the Black Market (laced, cheaper, with a sting). Bags & consumables in Field notes has the rules.",
				"synthesis": "Synthesis-only — never sold. Kesh mints the Grand potions from the Alkahest Codex: a clean S + a laced A → a step above S, no drawback.",
				"relics": "A shipped relic or landmark of the world."}.get(String(e["kind"]), ""), 12, MUTED)
			kl.custom_minimum_size = Vector2(DETAIL_W, 0)
			return


# --------------------------------------------------------------- armory ---
## Every rollable shape: [{slot, noun, cls}] in class/table order. Weapons
## and the class-migrated slots group by class; a shared slot lists flat.
static func _shape_entries() -> Array:
	var out: Array = []
	for slot in Items.SLOTS:
		var sl := String(slot)
		if sl == "weapon":
			for cls in Classes.CLASSES:
				for noun in Items.CLASS_WEAPONS.get(cls, []):
					out.append({"slot": sl, "noun": String(noun), "cls": String(cls)})
		elif not Items.CLASS_GEAR.get("warrior", {}).get(sl, []).is_empty():
			for cls in Classes.CLASSES:
				for noun in Items.CLASS_GEAR.get(cls, {}).get(sl, []):
					out.append({"slot": sl, "noun": String(noun), "cls": String(cls)})
		else:
			for noun in Items.SLOT_NAMES[sl]:
				out.append({"slot": sl, "noun": String(noun), "cls": ""})
	return out


static func _class_name(cls: String) -> String:
	return String(Classes.CLASSES[cls]["name"]) if Classes.CLASSES.has(cls) else "Shared"


static func _shape_rows(_m: Menus) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var out: Array = []
	for e in _shape_entries():
		if f.has("slot") and String(e["slot"]) != String(f["slot"]):
			continue
		if f.has("cls") and String(e["cls"]) != String(f["cls"]):
			continue
		var noun := String(e["noun"])
		var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
		if not _matches(noun + " " + tag):
			continue
		out.append({"key": String(e["slot"]) + "|" + noun, "name": noun,
			"sub": tag + " · " + String(e["slot"]).capitalize(),
			"tag": _class_name(String(e["cls"])), "icon": Art.codex_item_icon(String(e["slot"]), "S", noun),
			"accent": ACC_GEAR})
	return out


static func _shape_detail(m: Menus, list: VBoxContainer, key: String) -> void:
	var parts := key.split("|", true, 1)
	if parts.size() != 2:
		return
	var slot := String(parts[0])
	var noun := String(parts[1])
	var cls := ""
	for e in _shape_entries():
		if String(e["slot"]) == slot and String(e["noun"]) == noun:
			cls = String(e["cls"])
			break
	var slot_desc := {
		"weapon": "Main: your class attribute (largest budget). Upgradeable at merchants.",
		"helmet": "Main: your class attribute (solid budget).",
		"armor": "Main: your class attribute. Upgradeable at merchants.",
		"gloves": "Main: your class attribute (smallest budget).",
		"pants": "Main: your class attribute (solid budget).",
		"boots": "Main: your class attribute (small budget).",
		"charm": "Main: your class attribute.",
	}
	var box := UITheme.card(list, ACC_GEAR, 12.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
	var nm := m._lbl(col, noun, 16, Color(0.92, 0.93, 0.98))
	nm.custom_minimum_size = Vector2(DETAIL_W, 0)
	var meta := m._lbl(col, "%s   ·   %s   ·   leans %s" % [slot.capitalize(), _class_name(cls), tag], 12, Color(0.6, 0.7, 0.85))
	meta.custom_minimum_size = Vector2(DETAIL_W, 0)
	# The F→S ladder: this shape at every grade.
	var ladder := HBoxContainer.new()
	ladder.add_theme_constant_override("separation", 6)
	col.add_child(ladder)
	for g in Items.GRADES:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(50, 0)
		cell.add_theme_constant_override("separation", 1)
		ladder.add_child(cell)
		var icon := TextureRect.new()
		icon.texture = Art.codex_item_icon(slot, g, noun)
		# A 32px icon shown at 1:1 in a small cell reads as a sliver — a thin
		# weapon vanishes. Upscale to a legible box, NEAREST so the pixels
		# stay crisp instead of blurring.
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if icon.texture.get_width() >= 64 \
			else CanvasItem.TEXTURE_FILTER_NEAREST
		cell.add_child(icon)
		var gl := Label.new()
		gl.text = g
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.add_theme_font_size_override("font_size", 12)
		gl.add_theme_color_override("font_color", Items.GRADE_COLOR[g])
		cell.add_child(gl)
	var sd := m._lbl(col, String(slot_desc.get(slot, "")), 12, Color(0.7, 0.72, 0.78))
	sd.custom_minimum_size = Vector2(DETAIL_W, 0)
	var lean := m._lbl(col, "A shape leans a roll; it never grants a stat. Its tag names the substats that are more LIKELY to roll and roll BIGGER when they land — one stat %.2f×, two %.2f× each, three %.2f× each. Field notes › Gear rules has the whole of it." % [Items.SHAPE_BIAS_ONE, Items.SHAPE_BIAS_TWO, Items.SHAPE_BIAS_THREE], 12, Color(0.6, 0.62, 0.7))
	lean.custom_minimum_size = Vector2(DETAIL_W, 0)
	# Flavor: a quoted, dim parchment line under the ladder (empty = none).
	var flav := GearFlavor.of({"noun": noun})
	if flav != "":
		var fl := m._lbl(col, "❝ %s ❞" % flav, 12, Color(0.72, 0.68, 0.55))
		fl.custom_minimum_size = Vector2(DETAIL_W, 0)


static func _unique_rows(_m: Menus) -> Array:
	var f: Dictionary = _filters.get(_sec, {})
	var out: Array = []
	for u in Items.UNIQUES:
		if f.has("slot") and String(u["slot"]) != String(f["slot"]):
			continue
		if f.has("cls") and String(u["cls"]) != String(f["cls"]):
			continue
		if f.has("grade") and String(u["grade"]) != String(f["grade"]):
			continue
		var passive := String(Items.PASSIVES.get(String(u.get("passive", "")), ""))
		if not _matches(String(u["name"]) + " " + String(u["noun"]) + " " + passive):
			continue
		var grade := String(u["grade"])
		out.append({"key": String(u["name"]), "name": String(u["name"]),
			"sub": "%s · %s · %s" % [String(u["noun"]), _class_name(String(u["cls"])), String(u["slot"]).capitalize()],
			"tag": grade, "tag_color": Items.GRADE_COLOR[grade], "name_color": Items.GRADE_COLOR[grade],
			"icon": Art.codex_item_icon(String(u["slot"]), grade, String(u["noun"]), String(u.get("art", ""))),
			"accent": ACC_GEAR})
	return out


static func _unique_detail(m: Menus, list: VBoxContainer, name: String) -> void:
	var u := {}
	for x in Items.UNIQUES:
		if String(x["name"]) == name:
			u = x
			break
	if u.is_empty():
		return
	var grade := String(u["grade"])
	var color: Color = Items.GRADE_COLOR[grade]
	var card := UITheme.card(list, color, 12.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var uicon := TextureRect.new()
	uicon.texture = Art.codex_item_icon(String(u["slot"]), grade,
		String(u["noun"]), String(u["art"]))
	uicon.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	uicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	uicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	uicon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if uicon.texture.get_width() >= 64 \
		else CanvasItem.TEXTURE_FILTER_NEAREST
	uicon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(uicon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var text_w := DETAIL_W - ICON_BOX - 12.0
	var name_l := m._lbl(info, String(u["name"]), 15, color)
	name_l.custom_minimum_size = Vector2(text_w, 0)
	var meta := m._lbl(info, "%s GRADE  •  %s  •  %s %s" % [grade, String(u["noun"]).to_upper(),
		_class_name(String(u["cls"])).to_upper(), String(u["slot"]).to_upper()], 10, Color(0.60, 0.63, 0.70))
	meta.custom_minimum_size = Vector2(text_w, 0)
	var passive := m._lbl(info, String(Items.PASSIVES.get(
		String(u.get("passive", "")), "Signature passive — in design")),
		12, Color(0.86, 0.88, 0.94))
	passive.custom_minimum_size = Vector2(text_w, 0)
	var flavor := GearFlavor.of(u)
	if flavor != "":
		var flavor_l := m._lbl(info, flavor, 11, Color(0.67, 0.65, 0.58))
		flavor_l.custom_minimum_size = Vector2(text_w, 0)
	var ul := m._lbl(list, "A unique is a generic-grade piece that also carries a signature PASSIVE — that passive is the whole difference, and uniques drop more rarely to match. Its own name, its own art, live the moment you equip it. Named A pieces surface in Act 2, named S in Act 3.", 12, MUTED)
	ul.custom_minimum_size = Vector2(DETAIL_W, 0)


# ---------------------------------------------------------------- pages ---
static func _build_page(m: Menus, split: HBoxContainer) -> void:
	var count: Label = _ui.get("count")
	var sc := ScrollContainer.new()
	sc.name = "CodexDetail"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	_ui["detail"] = list
	var f: Dictionary = _filters.get(_sec, {})
	var ctext := ""
	match _sec:
		"gems":
			ctext = "%d families" % Items.GEM_STATS.size()
			_gems_page(m, list)
		"status":
			ctext = "%d effects" % _status_effects().size()
			_statuses(m, list)
		"coop":
			_coop(m, list)
		"story":
			# The story archive is the Journal's (one builder, one source of
			# truth): every conversation, choice and roadside talk as it was
			# actually played, chapter by chapter, with a transcript reader.
			# Owner asked (2026-08-15) for "a story section in the codex" —
			# re-PLAYING an opening scene would need a sandbox for its choices,
			# flags and rewards; re-READING it needs nothing but this shelf.
			ctext = "%d recorded" % m.game.convo_log_order.size()
			UIJournal._archive(m, list)
		"records":
			_records(m, list)
		"sanctuary":
			preload("res://scripts/ui/sanctuary.gd").page(m, list)
		"fishing":
			preload("res://scripts/ui/fishing.gd").journal(m, list)
		"gallery":
			_gallery(m, list, "gallery_" + String(f.get("shelf", "heroes")))
		"notes":
			match String(f.get("page", "elites")):
				"wayfinder":
					_notes_wayfinder(m, list)
				"activities":
					preload("res://scripts/ui/activity_rewards.gd").notes(m, list)
				"combat":
					_notes_combat(m, list)
				"controller":
					m._lbl(list, "PLAY WITH A CONTROLLER", 22, UITheme.GOLD_BRIGHT)
					m._lbl(list, "Left stick moves your hero, with gentle tilt for walking. The triggers and shoulder buttons use your four equipped abilities: RT basic, LT second, RB third, LB ultimate. The ability bar shows the current button labels.", 16)
					m._lbl(list, "A interacts and confirms; X drinks the selected potion; Y cycles potions. R3 locks or cycles a target. Flick the right stick toward a target to choose it, then release before another flick. B releases the lock. D-pad up opens the map, left the bag, right skills, and down the Codex. Menu pauses; L3 opens party chat in co-op.", 16)
					m._lbl(list, "Menus: left stick moves the cursor, D-pad snaps between visible controls, A selects or holds a drag, and right stick scrolls. Place the cursor over the atlas to zoom with the right stick. Focus a text field and press X for an on-screen keyboard; its Done button sends party chat. B goes back.", 16)
					m._lbl(list, "Fishing: RT casts, strikes and holds the reel. Release it when the fish surges. Use the cursor to pick lures and visit the catch journal.", 16)
					m._lbl(list, "Settings → Controller adjusts deadzone, cursor speed and Xbox / PlayStation labels. Keyboard and touch remain available: use either to switch prompts. After closing an overlay, release held controls before returning to combat.", 16)
				"gear":
					_notes_gear(m, list)
				"gems":
					_notes_gems(m, list)
				"bags":
					_gear_bags(m, list)
				"fangmoot":
					_notes_fangmoot(m, list)
				_:
					_notes_elites(m, list)
		"future":
			_future(m, list, String(f.get("cat", "future_terrains")))
	if count != null and is_instance_valid(count):
		count.text = ctext


## GEMS — the fourteen families as their authored icons at Lv 1 / 4 / 7 / 10
## (the rough / cut / fine / perfected bands) with the Lv1→Lv10 value each
## family pays. Rules live under Field notes › Gem rules.
static func _gems_page(m: Menus, list: VBoxContainer) -> void:
	var f: Dictionary = _filters.get(_sec, {})
	var intro := m._lbl(list, "Each gem grants ONE stat and deepens with its level, up to Lv %d — socket into C+ gear (C:%d · B:%d · A:%d · S:%d sockets). Bands: rough 1-3 · cut 4-6 · fine 7-9 · perfected 10." %
		[Items.GEM_MAX_LEVEL, int(Items.GEM_SLOTS["C"]), int(Items.GEM_SLOTS["B"]), int(Items.GEM_SLOTS["A"]), int(Items.GEM_SLOTS["S"])], 13, Color(0.7, 0.72, 0.78))
	intro.custom_minimum_size = Vector2(PAGE_W, 0)
	var gems_box := VBoxContainer.new()
	gems_box.add_theme_constant_override("separation", 3)
	_card(list).add_child(gems_box)
	for stat in Items.GEM_STATS:
		var special: bool = stat in Balance.SPECIAL_GEM_STATS
		if f.has("kind") and (String(f["kind"]) == "special") != special:
			continue
		var info: Dictionary = Items.GEM_STATS[stat]
		var is_flat: bool = stat in Items.FLAT_STATS
		var v1: float = Items.gem_value(Items.make_gem(stat, 1))
		var vmax: float = Items.gem_value(Items.make_gem(stat, Items.GEM_MAX_LEVEL))
		var v1_txt: String = "+%d" % int(v1) if is_flat else "+%d%%" % int(round(v1 * 100))
		var vmax_txt: String = "+%d" % int(vmax) if is_flat else "+%d%%" % int(round(vmax * 100))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		gems_box.add_child(row)
		var ladder := HBoxContainer.new()
		ladder.add_theme_constant_override("separation", 2)
		ladder.custom_minimum_size = Vector2(4 * 30, 0)
		row.add_child(ladder)
		for lv in [1, 4, 7, 10]:
			var gi := TextureRect.new()
			gi.texture = Art.gem_codex_icon(info["color"], lv)   # 128px master
			gi.custom_minimum_size = Vector2(28, 28)
			gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # clean 128->28 downscale
			gi.tooltip_text = "%s Lv %d" % [String(info["name"]), lv]
			ladder.add_child(gi)
		var name_l := m._lbl(row, String(info["name"]), 13, info["color"])
		name_l.custom_minimum_size = Vector2(120, 0)
		var stat_l := m._lbl(row, Items.STAT_LABEL[stat], 13, Color(0.85, 0.85, 0.9))
		stat_l.custom_minimum_size = Vector2(100, 0)
		var val_l := m._lbl(row, "Lv1 %s   ·   Lv%d %s" % [v1_txt, Items.GEM_MAX_LEVEL, vmax_txt],
			13, Color(0.7, 0.72, 0.78))
		val_l.custom_minimum_size = Vector2(190, 0)
		var kind_l := m._lbl(row, "special socket" if special else "regular", 12,
			Color(0.78, 0.72, 0.98) if special else Color(0.5, 0.53, 0.62))
		kind_l.custom_minimum_size = Vector2(100, 0)
		# Authored flavor beneath the row (the perfected-band line reads as the
		# family's realized identity; GearFlavor keys every gem × band).
		var gflav := GearFlavor.of(Items.make_gem(stat, Items.GEM_MAX_LEVEL))
		if gflav != "":
			var gfl := m._lbl(gems_box, gflav, 11, Color(0.58, 0.56, 0.64))
			gfl.custom_minimum_size = Vector2(PAGE_W - 24, 0)
			gfl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot := m._lbl(list, "Synthesis, socket rules and the special-gem gate: Field notes › Gem rules.", 12, MUTED)
	foot.custom_minimum_size = Vector2(PAGE_W, 0)


## FIELD NOTES › Wayfinder — exploration and navigation controls.
static func _notes_wayfinder(m: Menus, list: VBoxContainer) -> void:
	UITheme.header(m._lbl(list, "— THE WAYFINDER —", 18, ACC_GOLD))
	for pair in [
		["Read the room", "The corner map shows your facing, red enemies, blue people and allies, gold chest diamonds, and the room's doorways. The pale rectangle is the floor currently on your screen. Buried treasure remains hidden until you uncover it."],
		["Finish the encounter", "The threat count and slim progress bar track the current encounter. Red doors are sealed. When the room is secured, the map turns green and tells you if revealed chests still wait to be collected."],
		["Chart your own course", "Open the map to use the field atlas. Select an explored room or a visible unexplored passage, then choose Set route. The gold path stays inside your charted territory; it cannot reveal a shortcut through the unknown. Drag to pan and use the zoom controls to inspect a crowded chart."],
		["Remember a guardian", "Journal → Progress records guardians only in rooms you have charted. Named pocket guardians, the Unlisted and Waking echoes keep their own victories, even when they resemble a guardian on the main road. Show on map inspects that recorded place; Your position returns the atlas to your current area. Viewing a place does not set a route or grant travel. Detached pockets still use their portal stones."],
		["Follow the bearing", "After you close the atlas, the map names your destination and a gold bearing points toward the next doorway. Its number counts the passages remaining. Guidance waits during combat, respects sealed story gates, and clears when you arrive. Pins belong to this chapter and run."],
		["Keep a promise in sight", "Accepting your first side quest tracks it automatically. In the Journal, Track this quest selects another. A compact card follows its next objective and guides you through charted rooms to the person, prop or surviving quarry. A gold diamond marks the objective within the area. Unexplored locations stay hidden. Setting a manual atlas route stops quest guidance; you can resume it in the Journal."],
		["The road remembers", "The Hunter’s Rounds leave crossed trail signs at the ravine, chapel and tower. A Flame at the Window leaves a burning pine light; paying Osla’s debt leaves a blue ribbon at the Hollow Oak. These marks return with your kept promises."],
		["Return to safety", "Select a visited sanctuary or a defeated boss arena, then choose Travel. Travel remains sealed during encounters. Crownfall retains its detailed city map and service directory."],
	]:
		UITheme.header(m._lbl(list, String(pair[0]), 16, ACC_GOLD))
		var text := m._lbl(list, String(pair[1]), 16, Color(0.78, 0.8, 0.86))
		text.custom_minimum_size.x = PAGE_W


## FIELD NOTES › Elites & Temptations — the copy that used to sit above the
## monster shelf (round 6 elites + the elective risk events).
static func _notes_combat(m: Menus, list: VBoxContainer) -> void:
	for pair in [
		["Walk the last mile", "Tovin waits in Village Outskirts. Accept his promise, then speak again to begin an optional escort to the fire. Stay near him to move; ask him to wait or follow when you need space. Two groups of pursuers show arrival marks before appearing. Keep creatures outside his circle and stay nearby to preserve his resolve. If it breaks, he retreats safely and you can retry. Reach the fire for the Road Companion title, then speak to him to leave a lasting mark in your story. Escort creatures pay no loot or XP. In co-op, the party shares his position, orders and resolve; menus do not pause danger."],
		["Stand the tower's watch", "The Collapsed Tower has an old ward brazier. Clear its residents, then interact to begin an optional three-wave defense. Stay inside the broad amber ring: an unattended ward loses strength. Creatures in its small red circle also drain it. Defeat each wave; brief pauses mend some ward strength and mark the next arrivals. Snuff the brazier to stop and retry. Holding all three waves earns the Lamplighter title; tell Mara in Emberfall what happened. The flame and her promise survive in your story. Vigil creatures pay no loot or XP. In co-op, everyone shares one ward, and a menu does not pause the fight."],
		["A tap is a commitment", "A quick ability tap is remembered briefly, including just before its cooldown ends. Holding a key still repeats at the normal cadence. Menus, dialogue, defeat and focus loss cancel pending attacks. On touch, tap to cast or hold to read the ability card."],
		["Land on clear ground", "Shield Bash, Shadow Dash, Blink and Tumble follow your movement input. With no movement input, they go where you face. An occupied destination shortens the movement to clear ground along that approach. Shield Bash, Shadow Dash and Blink keep their intended strike reach; base Tumble has no damage strike. A clear destination still lets these abilities cross intervening scenery."],
		["Read your opponent", "The current target's health bar calls out openings and dangerous stances. Hold fire against reflection or a counter, interrupt a healer, and attack an exposed enemy. These cues describe the enemy's current state; the marked ground still shows where an attack will land."],
		["Break a signature cast", "Amber brackets and an INTERRUPT bar mark selected boss casts. Fill the broad pressure bar with damage before the thin white fuse expires. Hits from within 190 units build 50% more pressure; periodic damage contributes 40%. A break cancels that cast, briefly stops the boss, and lets everyone deal 25% more damage for 2.5 seconds. Ordinary stuns still cannot stun a boss. Unbroken casts retain their normal dodge warning. In co-op, pressure is shared and scales with the boss's party health."],
		["Know what hit you", "A short arc beside your hero points toward an attacker whose blow landed. A double amber arc marks a heavy hit. A rejected cast tells you whether you need mana, time to recover, or time to thaw."],
		["Learn from a fall", "Pause and open Combat report to inspect the final blows of your last fall, or the most recent damage. It records health lost after shields and mitigation, never overkill. Recovery keeps this record for the current character session. Environmental damage may not have a named attacker."],
		["Read the ground", "A bright rim fills clockwise toward impact. Its outer edge marks the affected ground throughout the warning. Green inward arrows identify a shelter; false shelters still flicker. In solo play, pausing freezes both the warning and the attack."],
		["Turn the terrain against a pack", "Red-X Ember Casks and diamond-marked Rimehearts are single-use terrain weapons. Interact, land a melee swing, or hit one with a projectile to prime it. Enemy shots can prime them too. The marked circle fills for 1.5 seconds before bursting: move outside it. Casks damage nearby monsters; Rimehearts deal less damage but slow them for 3 seconds. Both hurt heroes caught inside. A burst primes nearby marked objects, each with its own full warning. Used objects stay spent for this chapter visit, including saves and co-op. Bosses are unaffected; ordinary scenery never explodes."],
		["Bank a shot through crystal", "Crystal clusters and spires marked with a blue ring bend incoming projectiles toward the nearest visible foe. Enemy bolts bend toward heroes too: a crystal can turn a missed shot back into danger. A nearby guide shows the outgoing path for your attacks. Shots keep their original damage, effects and remaining range; each can bank off two different crystals. With no visible target, the shot reflects off a diagonal facet. This works in ordinary combat rooms, outside boss arenas, PvP and endgame challenges."],
		["Make the feedback yours", "Settings › Combat & comfort adjusts camera shake, camera lead, screen flashes, impact pauses, damage bearings, combat framing and target visibility. Combat framing eases the view toward your current target and widens it for distant opponents; close fights retain the usual scale. Set Camera lead to zero to keep the hero centered, or switch Combat framing off for movement lead alone. Target visibility fades trees covering your current enemy and traces a thin amber silhouette where solid props hide it. Cover still blocks movement and attacks normally. The gold trail on an enemy's health bar briefly shows the damage you just dealt. Changes apply immediately."],
	]:
		UITheme.header(m._lbl(list, String(pair[0]), 17, ACC_GOLD))
		var text := m._lbl(list, String(pair[1]), 16, Color(0.78, 0.8, 0.86))
		text.custom_minimum_size.x = PAGE_W


static func _notes_elites(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	# Elites — the roaming miniboss variant (round 6).
	UITheme.header(m._lbl(list, "— ELITES —", 16, Color(1.0, 0.8, 0.3)))
	var ecard := VBoxContainer.new()
	ecard.add_theme_constant_override("separation", 2)
	_card(list).add_child(ecard)
	for line in [
		"Any monster can be promoted to an ELITE: ~4× health, 1.5× damage, extra resistances, a bigger sprite and a gold ring underfoot — a miniboss, not a mob.",
		"Where: some quiet side rooms hold a lone elite instead of a wanderer (rolled per character), and combat rooms sometimes hide one in a pack. Later chapters may field several at once.",
		"Why fight them: elites pay NO experience — they are pure loot. Triple gold, a guaranteed gem, a guaranteed silver/golden chest, and they are the only source of Stones of Unlearning and bigger BAGS (see Field notes › Bags)."]:
		var el := m._lbl(ecard, String(line), 13, Color(0.78, 0.8, 0.86))
		el.custom_minimum_size = Vector2(PAGE_W, 0)
	# Temptations — the elective risk events (retention roadmap #4).
	UITheme.header(m._lbl(list, "— TEMPTATIONS —", 16, Color(0.85, 0.6, 1.0)))
	var tcard := VBoxContainer.new()
	tcard.add_theme_constant_override("separation", 2)
	_card(list).add_child(tcard)
	for tline in [
		"CURSED CHEST — a wrong-colored chest that materializes just inside some blighted rooms as you arrive, and withdraws after %d seconds if you leave it be. Open it and the whole pack grows crueler (+%d%% damage, faster) until the purge — then it pays: a golden chest and a guaranteed gem. Decline freely; it never ambushes." % [int(Balance.CURSE_OFFER_WINDOW), int((Balance.CURSE_DMG_MULT - 1.0) * 100)],
		"GAMBLE SHRINE — a humming shrine in some quiet rooms. Feed it gold once and it blesses the offering (a gem, threefold gold, a chest, an elixir)... or drinks deeper (blood or more coin). The odds favor the bold — barely.",
		"Both are rolled per character, like elites — a replay meets different temptations.",
		"And keep your eyes open in dead ends: not everything glints until you're near it."]:
		var tl := m._lbl(tcard, String(tline), 13, Color(0.78, 0.8, 0.86))
		tl.custom_minimum_size = Vector2(PAGE_W, 0)
	# The Road Deck — safe-room encounter cards (Q14).
	UITheme.header(m._lbl(list, "— ON THE ROAD —", 16, Color(0.7, 0.85, 1.0)))
	var rcard := VBoxContainer.new()
	rcard.add_theme_constant_override("separation", 2)
	_card(list).add_child(rcard)
	for rline in RoadDeck.field_notes():
		var rl := m._lbl(rcard, String(rline), 13, Color(0.78, 0.8, 0.86))
		rl.custom_minimum_size = Vector2(PAGE_W, 0)
	# The Unlisted — rare hidden bosses (Q15).
	UITheme.header(m._lbl(list, "— THE UNLISTED —", 16, Color(0.95, 0.55, 0.5)))
	var ucard := VBoxContainer.new()
	ucard.add_theme_constant_override("separation", 2)
	_card(list).add_child(ucard)
	for uline in [
		"Some things are not on any bestiary the crown keeps. Rarely — and only past the first chapter — a room holds a boss that shouldn't be there: a foe grown out of an old grudge, wearing the elite marks of a real threat. It is never on the map until you walk in, and something always warns you first if you're listening.",
		"They fight down the same rules as any boss and give a hidden-boss's due — a bright gem, the crown's regard, and whatever a grudge that size is carrying. Rolled per character; most runs meet none. Kill it or don't; it was never expecting you either."]:
		var ul := m._lbl(ucard, String(uline), 13, Color(0.78, 0.8, 0.86))
		ul.custom_minimum_size = Vector2(PAGE_W, 0)
	# Portal stones -> pockets (Q15).
	UITheme.header(m._lbl(list, "— PORTAL STONES —", 16, Color(0.7, 0.85, 1.0)))
	var pcard := VBoxContainer.new()
	pcard.add_theme_constant_override("separation", 2)
	_card(list).add_child(pcard)
	for pline in [
		"Now and then a stone in a quiet room hums with a cold light — a door into a POCKET, a small sealed place that is not on any map: a lone arena, one boss that shouldn't be anywhere, and a way back to exactly where you were standing.",
		"Step through if you like. The entry stone and the exit remain available, including after victory. Collect your chest, gem and the crown's regard, then leave when ready. Retreat is free; an empty arena resets its guardian. A completed guardian stays down this run, independently of its campaign counterpart.",
		"The Molten Court heats alternating halves of its floor: gold borders give three seconds of warning. The other half and the center seam remain cold; lure the guardian across hot stone to melt its plates. These optional guardians pay no XP. The Still Larder seals bottles until victory; neither the belt nor the bag spends a bottle or a planned drink while sealed. Class healing still works.",
		"Party members can enter and return individually. The host owns the arena clock and victory; everyone present earns a personal reward once. A late arrival sees the current trial and an open way home."]:
		var pl := m._lbl(pcard, String(pline), 13, Color(0.78, 0.8, 0.86))
		pl.custom_minimum_size = Vector2(PAGE_W, 0)


## FIELD NOTES › Fangmoot — the tavern autobattler's rules in plain words.
## Reached from Carver Tove's table in Fangmoot Circle (Crownfall).
static func _notes_fangmoot(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	UITheme.header(m._lbl(list, "— THE MOOT —", 16, Color(1.0, 0.85, 0.4)))
	var mc := VBoxContainer.new()
	mc.add_theme_constant_override("separation", 2)
	_card(list).add_child(mc)
	for line in [
		"A Wildfang game of carved tokens, played at Carver Tove's table. Each turn you spend %d fangs at the tray: a token costs %d, a charm %d, a brew %d, a reroll %d. Unspent fangs vanish." % [int(Balance.FANGMOOT_FANGS), int(Balance.FANGMOOT_COST_TOKEN), int(Balance.FANGMOOT_COST_CHARM), int(Balance.FANGMOOT_COST_BREW), int(Balance.FANGMOOT_COST_ROLL)],
		"Line up to five tokens and call the moot; the fight plays itself, front against front. Win %d crests and the moot is yours; take %d scars and it ends. Turns 1 and 2 are sparring — a loss there leaves no scar." % [int(Balance.FANGMOOT_CRESTS_WIN), int(Balance.FANGMOOT_SCARS_OUT)],
		"You may only field what you have FACED. Common pieces are always on the tray; a beast's token unlocks the first time you kill it, and a Named (boss) piece the first time you fell it.",
		"Buy a second copy of a token to bond it — stronger, and it levels at 3 and 6 copies. A charm (a gem) is a permanent held item; a brew is a one-shot. Named pieces cost %d and only one may stand in a warband." % int(Balance.FANGMOOT_COST_NAMED)]:
		var el := m._lbl(mc, String(line), 13, Color(0.8, 0.82, 0.88))
		el.custom_minimum_size = Vector2(PAGE_W, 0)
	UITheme.header(m._lbl(list, "— THE STAKES —", 16, Color(0.85, 0.6, 1.0)))
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 2)
	_card(list).add_child(sc)
	for line in [
		"Two stats, plain as bone: BITE is what a token deals, HIDE is how much it can take. Seven tribes — Wild, Hollow, Choir, Molten, Still, Root, Storm — and each token's trick is its trait in the world: bloat, martyr, frost, ward, rot, and the rest.",
		"Nothing you win at the moot is power — no gold, no gear, ever. The table pays Renown (daily-capped), titles, and a shelf of trophies. It is played for the game of it."]:
		var sl := m._lbl(sc, String(line), 13, Color(0.8, 0.82, 0.88))
		sl.custom_minimum_size = Vector2(PAGE_W, 0)


## FIELD NOTES › Gear rules — the shape and unique explainers that used to
## head their shelves, then the grades / chests / drop-band / cap rules.
static func _notes_gear(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	UITheme.header(m._lbl(list, "COMPARE, KEEP AND SORT", 17, ACC_GEAR))
	var care := m._lbl(list, "Select a piece in your bag or on a merchant's shelf to compare its stats with the same equipped slot. Green and red changes include upgrades and gems; signature passives remain separate. Keep a favourite to protect it from sales, dropping and Auto-equip. Kept pieces carry a star and stay kept when you save. Order the bag by grade, slot or kept pieces to find what you need.", 16, Color(0.78, 0.8, 0.86))
	care.custom_minimum_size.x = PAGE_W
	# What a shape TAG means (2026-07-26). It used to mean "grants these stats"; a
	# shape now only LEANS the roll, so the gallery needs saying out loud or
	# the tags read as promises the item never makes.
	m._lbl(list, "— SHAPES — a shape leans a roll; it never grants a stat —", 16, GOLD_TXT)
	var shape_desc := VBoxContainer.new()
	shape_desc.add_theme_constant_override("separation", 2)
	_card(list).add_child(shape_desc)
	for line in [
		"The tag beside each shape names its signature stats. Those are more LIKELY to be rolled, and roll BIGGER when they land.",
		"BREADTH COSTS DEPTH. A shape that leans on ONE stat leans hardest — %.2fx. Two stats get %.2fx each, three get %.2fx each. Every shape spends the same total; the specialist just spends it all in one place." % [Items.SHAPE_BIAS_ONE, Items.SHAPE_BIAS_TWO, Items.SHAPE_BIAS_THREE],
		"That bigger roll raises the CEILING too — quenching a Fang's crit at the bench climbs toward a number a Claymore's crit can never reach. Chase a stat on the shape that leans into it.",
		"Nothing is promised. A Fang that rolls three defensive substats is simply a poor Fang; the reforge bench is your way out of it. A shape's main-stat budget (a Claymore's heft, a Shuriken's lightness) is the part that never rolls.",
	]:
		var sl_l := m._lbl(shape_desc, String(line), 13, Color(0.8, 0.82, 0.88))
		sl_l.custom_minimum_size = Vector2(PAGE_W, 0)
	m._lbl(list, "— NAMED UNIQUES — one-off pieces, each its own forging —", 16, Color(1.0, 0.72, 0.45))
	var ud := m._lbl(list, "A unique is a generic-grade piece that also carries a signature PASSIVE — that passive is the whole difference, and uniques drop more rarely to match. Its own name, its own art, live the moment you equip it. Named A pieces surface in Act 2, named S in Act 3.",
		13, Color(0.8, 0.82, 0.88))
	ud.custom_minimum_size = Vector2(PAGE_W, 0)
	_gear_rules(m, list)


## FIELD NOTES › Gem rules — sockets, synthesis, the special-gem gate.
static func _notes_gems(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	m._lbl(list, "— GEMS — socket into C+ gear (C:%d · B:%d · A:%d · S:%d sockets) —" %
		[int(Items.GEM_SLOTS["C"]), int(Items.GEM_SLOTS["B"]), int(Items.GEM_SLOTS["A"]), int(Items.GEM_SLOTS["S"])],
		16, ACC_INFO)
	var gem_intro := VBoxContainer.new()
	gem_intro.add_theme_constant_override("separation", 2)
	_card(list).add_child(gem_intro)
	for line3 in [
		"Each gem grants ONE stat and deepens with its level, up to Lv %d. Only C-grade gear and above has sockets — the same chapter gems begin to drop." % Items.GEM_MAX_LEVEL,
		"Synthesis: fuse 3 gems of the SAME kind and level into one of the next level (select them in the bag) — duplicates are never wasted. Gems stack in the bag, one slot per kind+level.",
		"SPECIAL gems — Haste, Lifesteal, Combo, Tenacity, Damage — begin dropping in Chapter 6 (alongside the A-grade gear that carries the only special slot). They are the ONLY way to build those stats: at most one special gem per item, and their totals soft-cap at %d%% Haste / %d%% Lifesteal / %d%% Combo (beyond, a point pays about a tenth)." %
			[int(Balance.CAP_CDR * 100), int(Balance.CAP_LIFESTEAL * 100), int(Balance.CAP_COMBO * 100)],
		"A vessel holds what it can bear: C gear sockets gems up to Lv%d, B up to Lv%d, A up to Lv%d, S up to Lv%d — deep gems need endgame gear." %
			[int(Items.GEM_LEVEL_LIMIT["C"]), int(Items.GEM_LEVEL_LIMIT["B"]), int(Items.GEM_LEVEL_LIMIT["A"]), int(Items.GEM_LEVEL_LIMIT["S"])],
		"Merchants sell loose gems (at the act's level) and buy your spares back — but the buy price is a pity option: farming gems is always cheaper."]:
		var gil := m._lbl(gem_intro, String(line3), 13, Color(0.7, 0.72, 0.78))
		gil.custom_minimum_size = Vector2(PAGE_W, 0)
	var foot := m._lbl(list, "The families themselves — every icon, every value — are under Armory › Gems.", 12, MUTED)
	foot.custom_minimum_size = Vector2(PAGE_W, 0)


## Status effects: name, colour, description lines. Numbers pull live from
## Balance so the codex can never drift from the actual combat tuning.
static func _status_effects() -> Array:
	return [
		["Stun", Color(1.0, 0.85, 0.4), [
			"The target can't move or act for a moment.",
			"Bosses are CC-immune: a stun that would hit them lands as CONCUSSION instead — bonus damage of duration × ATK × %d%%, so stun-themed abilities keep their value in boss fights." % int(Balance.CONCUSSION_MULT * 100)]],
		["Slow", Color(0.5, 0.65, 1.0), [
			"Movement speed is cut for a duration (clinging murk −30%, void rifts drag). CC-immune bosses ignore it."]],
		["Burn", Color(1.4, 0.7, 0.5), [
			"Fire damage over time, an orange flicker. Burns do NOT stack — only the strongest active burn applies (lava pools, ignite effects)."]],
		["Poison", Color(0.5, 0.9, 0.5), [
			"The green damage-over-time — the ONE exception to the no-stack rule. Each application adds a stack (up to %d) that deepens the tick by %d%%; the stacks expire together when the DoT runs out." % [Balance.TOXIN_MAX_STACKS, int(Balance.TOXIN_PER_STACK * 100)]]],
		["Expose (Vulnerable)", Color(0.85, 0.5, 0.95), [
			"A marked target takes +50% damage while the mark holds (~3s). The assassin's Death Mark ult stretches it to 5s of true-damage setup."]],
		["Silence", Color(0.75, 0.8, 1.0), [
			"An INVERSE telegraph (debuts against Vess in Chapter 3): the whole arena screams lethal except one quiet safe circle — find it and stand INSIDE before the wail lands, the opposite of a normal red danger-zone."]],
		["Evasion & DEX", Color(0.8, 0.85, 0.5), [
			"An evasive foe rolls its EVASION against every hit you throw. Your DEX doesn't shave that roll — it decides what a successful dodge COSTS you, in three fixed steps. This is a build state, not luck: read it, then answer it.",
			"Below %d%% of the DEX their evasion asks — the dodge is a clean MISS, for nothing. At %d%% or better — it only GRAZES, and still pays %d%% of the damage. At full parity or above — their evasion is CANCELLED and never rolls at all." % [int(Balance.DEX_GRAZE_RATIO * 100), int(Balance.DEX_GRAZE_RATIO * 100), int(Balance.GRAZE_DAMAGE * 100)],
			"Parity is evasion × %d DEX: a %d%%-evasion foe asks %d. Amber gems and DEX substats buy it — and TRUE damage skips the question entirely, evasion and all. Little in the campaign evades; the endgame's SLIPPERY affix is what this is for, so carry Amber when you see it, not always." % [int(1.0 / Balance.DEX_PER_EVA), int(float(Balance.AFFIXES["slippery"]["eva_add"]) * 100.0), int(float(Balance.AFFIXES["slippery"]["eva_add"]) / Balance.DEX_PER_EVA)]]],
	]


static func _statuses(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var intro := m._lbl(list,
		"What you inflict on enemies (most ride your talent-themed abilities) — and, in hazard terrain, suffer yourself.",
		13, Color(0.7, 0.72, 0.78))
	intro.custom_minimum_size = Vector2(PAGE_W, 0)
	for e in _status_effects():
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		_card(list).add_child(info)
		m._lbl(info, String(e[0]), 15, e[1])
		for line in e[2]:
			var dl := m._lbl(info, String(line), 13, Color(0.78, 0.8, 0.86))
			dl.custom_minimum_size = Vector2(PAGE_W, 0)


static func _card(parent: Container) -> PanelContainer:
	return UITheme.card(parent, Color(0.42, 0.45, 0.55), 12.0)


## ------------------------------------------------------ streamed shelves ---
## The heavy shelves (bestiary, gear galleries, portraits) used to build every
## card inside the open() frame — hundreds of icon decodes in one go, so the
## panel froze on first open. They now STREAM: the first chunk builds
## synchronously (the panel opens already showing content), the rest lands a
## few cards per frame. Each open() bumps the generation so a still-streaming
## shelf from the previous tab stops at its next frame instead of building
## into a dead panel; the freed-list check covers closes from outside.
static var _build_gen := 0

static func _build_chunked(m: Menus, list: VBoxContainer, jobs: Array, per_frame := 6) -> void:
	var gen := _build_gen
	for start in range(0, jobs.size(), per_frame):
		if start > 0:
			await m.get_tree().process_frame
			if gen != _build_gen or not is_instance_valid(list):
				return
		for i in range(start, mini(start + per_frame, jobs.size())):
			(jobs[i] as Callable).call()


## The enemy kind the hero currently wears via the dev Transform ("" = none).
static func _morph_kind(m: Menus) -> String:
	if not m.game.dev_mode or m.game.player == null:
		return ""
	var cur: DevMorph = m.game.player.dev_morph
	if cur == null or not is_instance_valid(cur):
		return ""
	return String(cur.kind)


## Jump a freshly built bestiary shelf to `card` — reopening the codex while
## transformed (to switch or revert) used to mean hand-scrolling the whole
## shelf back to the active mob every time.
static func _scroll_to_card(m: Menus, card: Control) -> void:
	await m.get_tree().process_frame  # container layout settles a frame later
	if not is_instance_valid(card) or not card.is_inside_tree():
		return
	var y := 0.0
	var c: Control = card
	while c.get_parent() != null and not (c.get_parent() is ScrollContainer):
		y += c.position.y
		c = c.get_parent() as Control
		if c == null:
			return
	var sc := c.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = maxi(0, int(y) - 10)

## Every world whose contents the codex catalogues: the campaign chapters PLUS
## the standalone side-chapters (Q13 interludes) content modules register in
## Story.STANDALONE_WORLDS, which are deliberately kept OUT of CHAPTER_LIST so
## chapter select / advance_chapter never see them. A shelf built from
## CHAPTER_LIST alone silently drops their content — the Moonfen's First Howl
## is a boss the player can kill and never find in the codex. Chapters first,
## so story order still sorts the shelves.
static func _codex_worlds() -> Dictionary:
	Story.load_content()  # idempotent; STANDALONE_WORLDS is module-registered
	var out: Dictionary = Story.CHAPTER_LIST.duplicate()
	out.merge(Story.STANDALONE_WORLDS)
	return out


## Enemy kinds actually placed in the world: any zone's `enemies` spawns or
## `boss`, plus each chapter's `final_boss`. Everything else in ALL_ENEMIES is
## extracted-but-unplaced — off the bestiary, on the dev-only Future shelf.
static func _used_enemy_kinds() -> Dictionary:
	var used := {}
	var worlds: Dictionary = _codex_worlds()
	for chid in worlds:
		var ch: Dictionary = worlds[chid]
		var fb := String(ch.get("final_boss", ""))
		if fb != "":
			used[fb] = true
		for zone in ch.get("zones", []):
			var b := String(zone.get("boss", ""))
			if b != "":
				used[b] = true
			for e in zone.get("enemies", []):
				if e is Array and e.size() > 0:
					used[String(e[0])] = true
	return used


## Role labels by sprite id — LABELS, not lore: the sprite id and the convo
## data are the source (elder/sentry/merchant art, faction recruiters,
## quest-carrying convos). Anything unmapped simply shows no role line.
const NPC_ROLES := {
	"elder": "Village elder",
	"sentry": "Village guard",
	"villager": "Villager",
	"merchant": "Merchant — buys and sells",
	"warden": "Faction contact — the Accord",
	"envoy": "Faction contact — the Cinderborn",
	"choirmother": "Choir cantor",
	"cultist": "Devotee",
	"beastkin": "Beastkin",
	"beastkin_caged": "Beastkin captive",
	"aldric": "Knight",
	"scholar_ivo": "Chronicler of the Deeps",
}


## Does this convo hand out a quest anywhere (node or choice)? The one
## fully data-derived role signal — quest keys ride the convo tables.
static func _gives_quest(convo: String) -> bool:
	if convo == "" or not Story.ALL_CONVOS.has(convo):
		return false
	var nodes: Dictionary = Story.ALL_CONVOS[convo].get("nodes", {})
	for nid in nodes:
		var nd: Dictionary = nodes[nid]
		if String(nd.get("quest", "")) != "":
			return true
		for ch in nd.get("choices", []):
			if String(ch.get("quest", "")) != "":
				return true
	return false


## One role line per NPC: sprite-derived base + "quest giver" when any of
## its convos sets a quest. "" = no line (unmapped placeholder art).
static func _npc_role(spr: String, gives_quest: bool) -> String:
	var bits: Array = []
	var base := String(NPC_ROLES.get(spr, ""))
	if base != "":
		bits.append(base)
	if gives_quest:
		bits.append("Quest giver" if base == "" else "quest giver")
	return " · ".join(bits)


## Best display name for an npc entry: the speaker of its convo, else the
## talk prompt without its "E — " lead, else the sprite id.
static func _npc_name(npc: Dictionary) -> String:
	var convo: String = String(npc.get("convo", ""))
	if convo != "" and Story.ALL_CONVOS.has(convo):
		var c: Dictionary = Story.ALL_CONVOS[convo]
		var start: String = String(c.get("start", ""))
		var nodes: Dictionary = c.get("nodes", {})
		if nodes.has(start):
			var who: String = String(nodes[start].get("who", ""))
			if who != "":
				return who
	var prompt: String = String(npc.get("prompt", ""))
	for lead in ["E — ", "E - "]:
		if prompt.begins_with(lead):
			return prompt.substr(lead.length()).strip_edges()
	return prompt if prompt != "" else String(npc.get("sprite", ""))


static var _enemy_icons := {}
const ICON_ALPHA := 0.08
const ICON_BOX := 64.0   # the one bestiary portrait size, every entry
const ICON_SCAN := 48    # bounds-scan proxy edge — sub-pixel precision buys nothing at 64px

static func _enemy_icon(sprite: String) -> Texture2D:
	if _enemy_icons.has(sprite):
		return _enemy_icons[sprite]
	var tex: Texture2D = Art.tex(sprite)
	var out: Texture2D = tex
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			# Art.tex(sprite) is the single-frame static portrait. Animation
			# lives in a separate <sprite>_anim.png strip, so dividing this
			# texture by the animation's frame count scans only an empty sliver
			# of padded boss exports.
			var fw: int = img.get_width()
			var fh: int = img.get_height()
			# Bounds-scan a ≤ICON_SCAN proxy, not the full frame: get_pixel over
			# a 224px boss square is tens of ms of script per sprite, and a whole
			# shelf of first-open scans froze the panel. Bilinear downscale
			# AVERAGES alpha, so an isolated stray pixel dims further below the
			# threshold (the anti-stray intent survives) while contiguous figure
			# edges stay above it. Bounds map back with a one-proxy-pixel pad,
			# which also absorbs the resize rounding.
			var scan: Image = img
			if maxi(fw, fh) > ICON_SCAN:
				scan = img.duplicate()
				var k: float = float(ICON_SCAN) / float(maxi(fw, fh))
				scan.resize(maxi(1, int(fw * k)), maxi(1, int(fh * k)),
					Image.INTERPOLATE_BILINEAR)
			var sw: int = scan.get_width()
			var sh: int = scan.get_height()
			var pad: int = 0 if scan == img else 1
			var x0 := sw
			var y0 := sh
			var x1 := -1
			var y1 := -1
			for y in sh:
				for x in sw:
					if scan.get_pixel(x, y).a > ICON_ALPHA:
						x0 = mini(x0, x)
						y0 = mini(y0, y)
						x1 = maxi(x1, x)
						y1 = maxi(y1, y)
			if x1 >= x0 and y1 >= y0:
				var mx: float = float(fw) / float(sw)
				var my: float = float(fh) / float(sh)
				var rx0: int = clampi(int(floor((x0 - pad) * mx)), 0, fw - 1)
				var ry0: int = clampi(int(floor((y0 - pad) * my)), 0, fh - 1)
				var rx1: int = clampi(int(ceil((x1 + 1 + pad) * mx)) - 1, 0, fw - 1)
				var ry1: int = clampi(int(ceil((y1 + 1 + pad) * my)) - 1, 0, fh - 1)
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2(rx0, ry0), Vector2(rx1 - rx0 + 1, ry1 - ry0 + 1))
				out = at
	_enemy_icons[sprite] = out
	return out


const PATCH_DESC := {
	"lava": "Lava pools — the floor burns anyone standing in them, you AND monsters",
	"ice": "Sheet ice — slippery patches speed everyone up by 35%",
	"poison": "Poison pools — standing in them poisons you",
	"heal": "Blessed ground — standing in it slowly heals you",
	"slow": "Clinging murk — wading through slows you by 30%",
}
const EVENT_DESC := {
	"magma_rain": "Magma rain — molten rock crashes onto telegraphed spots and the floor collapses into lava",
	"grave_spawn": "Restless dead — zombies periodically claw out of the ground beside you",
	"gust": "Sandstorm gusts — sudden wind shoves everyone sideways",
	"lightning": "Lightning strikes — bolts hammer telegraphed spots around you",
	"shard": "Shard eruptions — crystal bursts explode at random spots",
}
const AMBIENT_DESC := {
	"leaves_green": "drifting green leaves", "leaves_autumn": "falling autumn leaves",
	"fireflies": "fireflies", "embers": "rising embers", "snow": "falling snow",
	"rain": "heavy rain", "sand": "blowing sand", "mist": "creeping mist",
	"twinkle": "twinkling lights", "motes": "drifting void motes",
	"sparkle": "golden sparkles", "spores": "floating spores",
}


## Co-op page (MP-08 stub, expanded MP-15: the boss fight contract +
## the §5.3 downed/revive rules — written to the MULTIPLAYER.md blueprint
## that MP-12 implements). Numbers pull from live tables where they
## exist so the page can never drift from the actual netcode/tuning.
static func _coop(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	UITheme.header(m._lbl(list, "— PLAYING TOGETHER —", 16, Color(0.6, 0.9, 1.0)))
	var net_script := load("res://scripts/net/net_manager.gd")
	var entries := [
		["Lobby codes", Color(0.95, 0.85, 0.5),
			"From the title screen choose PLAY TOGETHER. The host picks a hero and a chapter and receives a lobby CODE; friends choose Join, type the code, and bring a hero from their own roster. Up to four heroes walk the host's world. Joins close when a chapter run begins — but stay OPEN while the party stands in Crownfall, the Capital (see below)."],
		["Crownfall is the party town", Color(0.7, 0.9, 1.0),
			"Travel to the Capital from the pause menu, then OPEN YOUR GATES at the Ashen Tankard — the session raises around the world you're standing in, and friends join the plaza beside you. Shop, talk, sort your bags; joining stays open the whole time. When it's time, the leader uses the PORTAL in the Wayfinder Sanctum: the pick (chapter and difficulty tier) goes to the party as a ready check, and everyone sets out together — the gates sealing behind you until you ride home."],
		["The road rises to meet you", Color(1.0, 0.7, 0.7),
			"Monsters grow tougher for every extra hero in the party — more health, a little more bite. A party of one plays exactly the solo game. The HOST's difficulty tier (Nightmare / Torment) sets the whole party's world — the tier chip on everyone's buff bar says so, and every head earns its unlocks and records at the tier actually fought."],
		["Bosses fight the whole party", Color(1.0, 0.6, 0.4),
			"A boss keeps its signature move trained on whoever it's hunting — but its floor pressure (rains, strays, eruptions underfoot) seeks out the REST of the party in turn. Nobody stands in guaranteed safety: keep your feet moving even when it isn't looking at you."],
		["Falling, and getting up", Color(0.7, 1.0, 0.8),
			"Hit zero among friends and you fall DOWNED instead of dead: 30 seconds of crawling while you bleed out. Any teammate can kneel beside you for 3 seconds (a hit interrupts them) to lift you back up at 30% health; bleed out fully and you ghost until the room is cleared. Only the WHOLE party falling ends the run — the usual death price, paid together."],
		["Loot is personal", Color(0.6, 1.0, 0.6),
			"Every drop, coin and gem you see is YOURS — each player is rolled their own rewards, nothing is split and nothing can be sniped. Guests take home everything their character earns; the world and its story stay the host's."],
		["Your history comes home", Color(0.95, 0.85, 0.5),
			"Your opening choices, city relationships, kept promises, rescued companions and chapter completion belong to your hero. Joining a friend preserves that history, and new personal accomplishments come home with you. Your first conquest of each chapter pays its spoils once, regardless of whether the host has cleared it before. Ordinary chapter quest progress, rooms and opened routes remain in their own world."],
		["Your chapter ending", Color(0.7, 0.9, 1.0),
			"Each hero sees their own class's illustrated chapter ending and reads at their own pace. Your rewards, chapter credit and records are banked before the ending; reading does not add to your recorded clear time."],
		["Familiar faces and small company", Color(0.72, 0.91, 0.70),
			"Friends see your equipped skin and companion, including changes you make during the session. Your companion follows you through travel and returns when you stand again after ghosting. These are cosmetic choices; your collection and each hero's selections remain your own."],
		["Travelling together", Color(0.7, 0.9, 1.0),
			"The Party HUD button stays visible for the whole session — even when you are its only member. Use it to reopen the roster, copy the join code, or manage the party after closing the panel; closing the panel never ends the session. Open party chat with ENTER on keyboard or Say on touch. Entering content is a PROPOSAL: the host names the chapter — and its difficulty tier — and everyone selects Ready; one decline cancels the check and names who declined. After a victory, WAY-GATES rise beside the fallen boss — Crownfall, a fresh pass, or the road on — and the leader's pick at a gate goes to the party as the same ready check, no codes re-read. The host can also remove a member (the ✕ in the party panel, or the pause menu mid-run)."],
		["The battle meter", Color(0.95, 0.6, 0.25),
			"In a party, a compact DAMAGE meter sits under the ally frames — everyone's damage this run, live. Boss victory letters carry the party's per-member breakdown, and endgame results tally damage, healing and damage taken for the whole crew."],
		["The Proving Grounds (PvP)", Color(1.0, 0.62, 0.55),
			"DUEL A RIVAL from Play Together: you receive a code, your rival joins it, and both of you are thrown into a three-room arena — sealed gatehouses either side of a proving floor whose terrain rerolls every round. A countdown, then the gates open and blades cross; each fall resets the round behind fresh gates. First to 3 falls loses. For now the duel is honor only: no spoils, no losses, and potions stay corked at the gate."],
		["One build, one road", Color(0.85, 0.6, 1.0),
			"Both games must run the SAME build to connect — yours is printed on the title screen (build %s). A mismatch is refused with both versions named, so you'll know exactly who updates." % String(net_script.NET_VERSION)],
	]
	for e in entries:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 3)
		_card(list).add_child(card)
		m._lbl(card, String(e[0]), 15, e[1])
		var dl := m._lbl(card, String(e[2]), 13, Color(0.78, 0.8, 0.86))
		dl.custom_minimum_size = Vector2(PAGE_W, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _records(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)

	# --- achievements ---
	# The header counts the FEAT list below (ORDER); record-track tier
	# medals live in their own card and count their own stars. Points are
	# global — feats and tiers both pay into the one pool titles read.
	var unlocked := 0
	for id in Achievements.ORDER:
		if m.game.achievements.has(id):
			unlocked += 1
	m._lbl(list, "— ACHIEVEMENTS —   %d / %d   ·   %d points" %
		[unlocked, Achievements.ORDER.size(), m.game.achievement_points()], 16, Color(1.0, 0.85, 0.4))
	var ach := VBoxContainer.new()
	ach.add_theme_constant_override("separation", 3)
	_card(list).add_child(ach)
	for id in Achievements.ORDER:
		var a: Dictionary = Achievements.DATA[id]
		var got: bool = m.game.achievements.has(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		ach.add_child(row)
		# Unearned entries keep the medal — dimmed to a silhouette — plus a
		# live progress fraction where the data exists: the list should pull
		# you forward, not read as a wall of em-dashes. (Display only; no
		# unlock logic here.)
		var mark := m._lbl(row, "★", 15, Color(1.0, 0.85, 0.4) if got else Color(0.38, 0.38, 0.46))
		mark.custom_minimum_size = Vector2(28, 0)
		var nm := m._lbl(row, String(a["name"]), 14, Color(1.0, 0.88, 0.45) if got else Color(0.6, 0.62, 0.68))
		nm.custom_minimum_size = Vector2(200, 0)
		var ds := m._lbl(row, String(a["desc"]), 13, Color(0.8, 0.82, 0.88) if got else Color(0.5, 0.52, 0.58))
		ds.custom_minimum_size = Vector2(350, 0)
		var prog := "" if got else _ach_progress(m, String(id))
		if prog != "":
			var pl := m._lbl(row, prog, 13, Color(0.75, 0.7, 0.5))
			pl.custom_minimum_size = Vector2(120, 0)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- record tracks: tiered lifetime tallies, a medal per crossed tier ---
	m._lbl(list, "— RECORD TRACKS —   lifetime tallies · a medal per tier", 16, Color(0.7, 0.95, 0.85))
	var tracks := VBoxContainer.new()
	tracks.add_theme_constant_override("separation", 6)
	_card(list).add_child(tracks)
	for track in Achievements.TRACK_ORDER:
		var t: Dictionary = Achievements.TRACKS[track]
		var tiers: Array = t["tiers"]
		var v: int = m.game.track_value(String(track))
		var done := 0
		for i in tiers.size():
			if m.game.achievements.has("%s_%d" % [track, i + 1]):
				done += 1
		var mastered: bool = done >= tiers.size()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		tracks.add_child(row)
		var stars := ""
		for i in tiers.size():
			stars += "★" if i < done else "☆"
		var sl := m._lbl(row, stars, 14, Color(1.0, 0.85, 0.4) if done > 0 else Color(0.45, 0.45, 0.52))
		sl.custom_minimum_size = Vector2(64, 0)
		var nm := m._lbl(row, String(t["name"]), 14,
			Color(1.0, 0.88, 0.45) if mastered else Color(0.85, 0.88, 0.94))
		nm.custom_minimum_size = Vector2(150, 0)
		# Bar toward the NEXT tier (a full gold bar once mastered).
		var prev_th: int = 0 if done == 0 else int(tiers[done - 1])
		var next_th: int = int(tiers[mini(done, tiers.size() - 1)])
		var frac := 1.0
		if not mastered:
			frac = clampf(float(v - prev_th) / float(maxi(1, next_th - prev_th)), 0.0, 1.0)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(160, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var bbg := ColorRect.new()
		bbg.color = Color(0, 0, 0, 0.55)
		bbg.size = Vector2(160, 12)
		bar.add_child(bbg)
		var fill := ColorRect.new()
		fill.color = Color(1.0, 0.85, 0.4) if mastered else Color(0.55, 0.9, 0.7)
		fill.position = Vector2(1, 1)
		fill.size = Vector2(158.0 * frac, 10)
		bar.add_child(fill)
		var cnt_text := "%d — MASTERED" % v if mastered else "%d / %d" % [v, next_th]
		var cnt := m._lbl(row, cnt_text, 13,
			Color(1.0, 0.88, 0.45) if mastered else Color(0.8, 0.82, 0.88))
		cnt.custom_minimum_size = Vector2(130, 0)
		var how := m._lbl(row, String(t["how"]), 12, Color(0.6, 0.62, 0.7))
		how.custom_minimum_size = Vector2(190, 0)

	# --- NG+ difficulty tiers (DESIGN "Difficulty tiers / NG+") — numbers
	# pull live from Balance so the card can never drift from the tuning.
	m._lbl(list, "— DIFFICULTY TIERS — replay the campaign harder, for richer loot —", 16, Color(0.72, 0.45, 1.0))
	var tcard := VBoxContainer.new()
	tcard.add_theme_constant_override("separation", 3)
	_card(list).add_child(tcard)
	for tier in Balance.TIER_NAMES.size():
		var open_t: bool = m.game.tier_unlocked(tier)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 10)
		tcard.add_child(trow)
		var tnm := m._lbl(trow, ("" if open_t else "🔒 ") + Balance.tier_name(tier), 14,
			Balance.tier_color(tier) if open_t else Color(0.5, 0.5, 0.55))
		tnm.custom_minimum_size = Vector2(150, 0)
		var tdesc: String
		if tier == 0:
			tdesc = "The campaign as authored."
		else:
			tdesc = "Every spawn +%d levels · loot bands +%d chapters · no XP" % [
				Balance.tier_level_offset(tier), int(Balance.TIER_BAND_SHIFT[tier])]
		var tds := m._lbl(trow, tdesc, 13, Color(0.78, 0.8, 0.86) if open_t else Color(0.55, 0.57, 0.63))
		tds.custom_minimum_size = Vector2(340, 0)
		if not open_t:
			var thw := m._lbl(trow, "Clear Chapter 7 at %s." % Balance.tier_name(tier - 1), 12, Color(0.6, 0.62, 0.7))
			thw.custom_minimum_size = Vector2(240, 0)
	var tfoot := m._lbl(tcard, "Pick the tier in the replay chapter select (pause → Chapter select). Each tier keeps its own chapter bests below.", 12, Color(0.6, 0.62, 0.7))
	tfoot.custom_minimum_size = Vector2(PAGE_W, 0)
	tfoot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- boss personal bests ---
	m._lbl(list, "— BOSS RECORDS —   fastest clear · best dps · kills", 16, Color(1, 0.6, 0.6))
	_records_bosses_and_rest(m, list)


## Live progress toward an unearned achievement, read from the same state
## the unlock triggers watch (boss_done, gold, level, streak, gem levels).
## "" = binary feat with nothing to count — the dimmed medal stands alone.
static func _ach_progress(m: Menus, id: String) -> String:
	match id:
		"boss_hunter":
			return "%d / 9 bosses" % mini(m.game.boss_done.size(), 9)
		"wealthy":
			return "%d / 5,000 g" % mini(m.game.player.gold, 5000)
		"level_20":
			return "Lv %d / 20" % mini(m.game.player.level, 20)
		"level_40":
			return "Lv %d / 40" % mini(m.game.player.level, 40)
		"streak_7":
			return "day %d / 7" % mini(m.game.daily_streak, 7)
		"gem_max":
			var hi := 0
			for gm in m.game.player.gem_bag:
				hi = maxi(hi, int(gm.get("lvl", 1)))
			for it in m.game.player.equipment.values():
				for sg in it.get("gems", []):
					hi = maxi(hi, int(sg.get("lvl", 1)))
			return "" if hi <= 0 else "gem Lv %d / %d" % [mini(hi, Items.GEM_MAX_LEVEL), Items.GEM_MAX_LEVEL]
	return ""


## Continuation of _records below the achievements card (split so the
## progress helper can sit beside the code that calls it).
static func _records_bosses_and_rest(m: Menus, list: VBoxContainer) -> void:
	var recs := VBoxContainer.new()
	recs.add_theme_constant_override("separation", 3)
	_card(list).add_child(recs)
	var any := false
	for kind in Story.ALL_ENEMIES:
		if not (kind in m.BOSS_KINDS) or not m.game.boss_records.has(kind):
			continue
		any = true
		var r: Dictionary = m.game.boss_records[kind]
		var secs: float = float(r.get("ttk", 0.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		recs.add_child(row)
		var nm := m._lbl(row, String(Story.ALL_ENEMIES[kind].get("name", kind)), 14, Color(1, 0.75, 0.75))
		nm.custom_minimum_size = Vector2(300, 0)
		var t := m._lbl(row, "%d:%02d" % [int(secs / 60.0), int(secs) % 60], 14, Color(0.7, 1.0, 0.7))
		t.custom_minimum_size = Vector2(90, 0)
		var d := m._lbl(row, "%d dps" % int(r.get("dps", 0.0)), 14, Color(0.85, 0.9, 1.0))
		d.custom_minimum_size = Vector2(140, 0)
		var k := m._lbl(row, "×%d" % int(r.get("kills", 0)), 14, Color(0.8, 0.82, 0.88))
		k.custom_minimum_size = Vector2(80, 0)
	if not any:
		m._lbl(recs, "No bosses felled yet. Their fastest clears will be recorded here.", 13, Color(0.6, 0.62, 0.68))

	# --- chapter personal bests (account-wide, this class) ---
	m._lbl(list, "— CHAPTER BESTS — %s, account-wide —" %
		String(Classes.CLASSES[m.game.player.cls]["name"]), 16, Color(0.6, 0.9, 1.0))
	var pbs := VBoxContainer.new()
	pbs.add_theme_constant_override("separation", 3)
	_card(list).add_child(pbs)
	var any_pb := false
	for chid in Story.CHAPTER_LIST:
		# One row per TIER with a mark (NG+ tracks are separate races —
		# a Torment best never stomps, or hides behind, the Normal one).
		for tier in Balance.TIER_NAMES.size():
			var pb: Dictionary = m.game.chapter_pb(String(chid), m.game.player.cls, tier)
			if pb.is_empty():
				continue
			any_pb = true
			var secs := int(float(pb.get("time", 0.0)))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			pbs.add_child(row)
			var nm_text := String(Story.chapter(String(chid))["name"])
			if tier > 0:
				nm_text += "  ·  " + Balance.tier_name(tier)
			var nm := m._lbl(row, nm_text, 14,
				Balance.tier_color(tier) if tier > 0 else Color(0.85, 0.9, 1.0))
			nm.custom_minimum_size = Vector2(300, 0)
			var t := m._lbl(row, "%d:%02d" % [secs / 60, secs % 60], 14, Color(0.7, 1.0, 0.7))
			t.custom_minimum_size = Vector2(90, 0)
			var gr := String(pb.get("grade", "D"))
			var g := m._lbl(row, "grade %s" % gr, 14, Items.GRADE_COLOR.get(gr, Color(1, 1, 1)))
			g.custom_minimum_size = Vector2(120, 0)
			var runs := m._lbl(row, "×%d runs" % int(pb.get("runs", 1)), 14, Color(0.8, 0.82, 0.88))
			runs.custom_minimum_size = Vector2(100, 0)
			# Normal replays pay XP up to the chapter's reach level (REPLAY_XP.md);
			# tiers never do — so the cell only exists on the Normal row.
			if tier == 0:
				var reach := Balance.replay_xp_reach(Story.chapter_parity_level(String(chid)))
				var grey: bool = m.game.player.level >= reach
				var xl := m._lbl(row, "outgrown (Lv %d)" % reach if grey else "XP to Lv %d" % reach, 14,
					Color(0.55, 0.57, 0.64) if grey else Color(1.0, 0.9, 0.5))
				xl.custom_minimum_size = Vector2(130, 0)
	if not any_pb:
		m._lbl(pbs, "Clear a chapter to set its first mark — time and grade are kept per class.",
			13, Color(0.6, 0.62, 0.68))

	# --- endgame trials (account-wide, this class) — the leaderboard brags ---
	if m.game.endgame_unlocked():
		m._lbl(list, "— ENDGAME TRIALS — %s, account-wide —" %
			String(Classes.CLASSES[m.game.player.cls]["name"]), 16, Color(1.0, 0.62, 0.5))
		var eg := VBoxContainer.new()
		eg.add_theme_constant_override("separation", 3)
		_card(list).add_child(eg)
		var cru: Dictionary = m.game.endgame_pb("crucible", m.game.player.cls)
		var cru_row := HBoxContainer.new()
		cru_row.add_theme_constant_override("separation", 10)
		eg.add_child(cru_row)
		var cn := m._lbl(cru_row, "🔥 The Crucible", 14, Color(1.0, 0.75, 0.62))
		cn.custom_minimum_size = Vector2(300, 0)
		if cru.is_empty():
			var cnr := m._lbl(cru_row, "no run yet", 14, Color(0.6, 0.62, 0.68))
			cnr.custom_minimum_size = Vector2(170, 0)
		else:
			var ck := m._lbl(cru_row, "best %d / %d bosses" % [int(cru.get("kills", 0)), Balance.CRUCIBLE_BOSSES], 14, Color(0.7, 1.0, 0.7))
			ck.custom_minimum_size = Vector2(170, 0)
			var ctime := int(float(cru.get("time", 0.0)))
			if ctime > 0:
				var ct := m._lbl(cru_row, "fastest clear %d:%02d" % [ctime / 60, ctime % 60], 14, Color(0.85, 0.9, 1.0))
				ct.custom_minimum_size = Vector2(200, 0)
		var dep: Dictionary = m.game.endgame_pb("depths", m.game.player.cls)
		var dep_row := HBoxContainer.new()
		dep_row.add_theme_constant_override("separation", 10)
		eg.add_child(dep_row)
		var dn := m._lbl(dep_row, "🕯 The Waking Depths", 14, Color(0.78, 0.82, 1.0))
		dn.custom_minimum_size = Vector2(300, 0)
		if dep.is_empty():
			var dnr := m._lbl(dep_row, "no run yet", 14, Color(0.6, 0.62, 0.68))
			dnr.custom_minimum_size = Vector2(170, 0)
		else:
			var dd := m._lbl(dep_row, "deepest %d" % int(dep.get("depth", 0)), 14, Color(0.7, 1.0, 0.7))
			dd.custom_minimum_size = Vector2(170, 0)

	# --- titles (worn beside the class name on the HUD) ---
	m._lbl(list, "— TITLES — earned by points, feats, lore and slaughter —", 16, Color(0.85, 0.6, 1.0))
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 3)
	_card(list).add_child(tbox)
	for tid in Achievements.TITLE_ORDER:
		var t2: Dictionary = Achievements.TITLES[tid]
		var can: bool = m.game.title_available(tid)
		var worn: bool = m.game.player_title == tid
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		tbox.add_child(row2)
		if can:
			var wear_id := String(tid)
			m._btn(row2, "  Doff  " if worn else "  Wear  ", func() -> void:
				m.game.player_title = "" if worn else wear_id
				m.game.autosave()
				m.open_codex("records"), Color(1.0, 0.88, 0.45) if worn else Color(0.8, 0.9, 1.0))
		else:
			var lock := m._lbl(row2, "  🔒  ", 14, Color(0.5, 0.5, 0.55))
			lock.custom_minimum_size = Vector2(64, 0)
		var nm2 := m._lbl(row2, String(t2["name"]) + ("   ← worn" if worn else ""), 14,
			Color(1.0, 0.88, 0.45) if worn else (Color(0.85, 0.88, 0.94) if can else Color(0.55, 0.57, 0.63)))
		nm2.custom_minimum_size = Vector2(280, 0)
		var how := m._lbl(row2, String(t2["how"]), 13,
			Color(0.8, 0.82, 0.88) if can else Color(0.5, 0.52, 0.58))
		how.custom_minimum_size = Vector2(380, 0)

	# --- Renown (the identity ledger's spendable cousin lives one door over) ---
	m._lbl(list, "— RENOWN — the event currency, spent in the Wardrobe —", 16, Balance.RENOWN_COLOR)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 4)
	_card(list).add_child(rbox)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 12)
	rbox.add_child(rrow)
	var rbal := m._lbl(rrow, "◈  %d Renown" % m.game.renown(), 16, Balance.RENOWN_COLOR)
	rbal.custom_minimum_size = Vector2(180, 0)
	m._btn(rrow, "  Open Wardrobe  ", func() -> void: m.open_wardrobe(), Color(0.85, 0.7, 1.0))
	var rdesc := m._lbl(rbox, "Earn Renown through activities and milestones. Spend it on skins, pets, or a weekly supply cache in the Wardrobe.",
		13, Color(0.8, 0.82, 0.88))
	rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rdesc.custom_minimum_size = Vector2(PAGE_W, 0)


## RULES shelf — grades, chests, drop bands, the stat-source rules and soft caps.
static func _gear_rules(m: Menus, list: VBoxContainer) -> void:
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
	m._lbl(chests, "Wooden chest — drops from monsters (common). A slim chance of a loose gem inside.", 14, Color(0.8, 0.65, 0.45))
	m._lbl(chests, "Silver chest — drops from monsters (rare) and elites. Better odds of a gem.", 14, Color(0.8, 0.82, 0.9))
	m._lbl(chests, "Golden chest — every boss drops one, and it always holds a gem (from Chapter 4 on, once gems drop).", 14, Color(1.0, 0.85, 0.35))
	var bossdrop := m._lbl(chests, "GEAR grade tracks the CHAPTER, not the chest color: each chapter drops a sliding BAND of tiers — Ch1 is F only, climbing to B by Ch5, A by Ch6, S by Ch12. Chests, shops and spoils roll the low-to-mid of that band; every boss additionally has about a 1-in-3 chance to drop a gear piece — and a bag — at the chapter's TOP tier. Top-tier gear is farmed, not bought.", 13, Color(0.85, 0.75, 0.55))
	bossdrop.custom_minimum_size = Vector2(PAGE_W, 0)
	bossdrop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var shoprule := m._lbl(chests, "SHOPPING: the Crown Bazaar in Crownfall is the fair-priced shop, restocked fresh at dawn for the road ahead. Chapters no longer open with a merchant — camps and wanderers found MID-run sell at ROAD PRICES (+10-20%, posted on the sign). Reforging and gem work are bench trades in the capital: Smith Petra and the Master Lapidary, whose rates soften as your favor with them grows.", 13, Color(0.7, 0.9, 1.0))
	shoprule.custom_minimum_size = Vector2(PAGE_W, 0)
	shoprule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m._lbl(chests, "Every piece is CLASS-LOCKED and guarantees your class attribute as its main (STR/AGI/INT). Bonus stats: ATK%, HP%, Crit, CritDmg, VIT, EVA, DEX, Pen, Resists, MP.", 13, Color(0.7, 0.72, 0.78))
	var resv := m._lbl(chests, "Haste, Lifesteal, Combo, Tenacity and Damage NEVER roll on gear — they are GEM-only (see below), and each item holds at most ONE such gem. Greed comes from neither gear nor gems. MOVEMENT SPEED is on no item and no gem: only terrain and abilities touch it." , 13, Color(0.85, 0.75, 0.55))
	resv.custom_minimum_size = Vector2(PAGE_W, 0)
	resv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var caps := m._lbl(chests, "STAT CAPS (soft — beyond each cap a point pays about a tenth, never nothing; Crit alone diminishes gentler, about a fifth): Crit %d%% · Evasion %d%% · Haste %d%% · Lifesteal %d%% · Combo %d%% · Greed %d%% · damage reduction from resistances %d%%. Ults ignore Haste entirely." %
		[int(Balance.CAP_CRIT * 100), int(Balance.CAP_EVA * 100), int(Balance.CAP_CDR * 100),
		int(Balance.CAP_LIFESTEAL * 100), int(Balance.CAP_COMBO * 100), int(Balance.CAP_GREED * 100),
		int(Balance.CAP_RES_FRAC * 100)], 13, Color(0.85, 0.75, 0.55))
	caps.custom_minimum_size = Vector2(PAGE_W, 0)
	caps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## BAGS shelf — bag capacity/stacking and the consumable list.
static func _gear_bags(m: Menus, list: VBoxContainer) -> void:
	# ------------------------------------------------- bags & consumables ---
	m._lbl(list, "— BAGS — carry up to 5 stacking bags; everything shares their slots —", 16, Color(0.95, 0.85, 0.5))
	var bags := VBoxContainer.new()
	bags.add_theme_constant_override("separation", 2)
	_card(list).add_child(bags)
	for g2 in Items.GRADES:
		m._lbl(bags, "%s   %s — %d slots" % [g2, Items.BAG_NAMES[g2], int(Items.BAG_SLOTS[g2])], 14, Items.GRADE_COLOR[g2])
		# The authored flavor line under each tier (bags resolve by name in GearFlavor).
		var bflav := GearFlavor.of(Items.make_bag(g2))
		if bflav != "":
			var bfl := m._lbl(bags, bflav, 12, Color(0.62, 0.6, 0.7))
			bfl.custom_minimum_size = Vector2(PAGE_W - 24, 0)
			bfl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for line2 in [
		"Gear, gems, consumables — and your HEALTH POTIONS — all share your bags' slots, and EVERY unit counts: 20 potions take 20 slots (they only STACK for display). Equip up to %d bags at once — total capacity is the SUM of their slots (F pouch 15 … S hold 45). You start with two Frayed Pouches." % Balance.MAX_BAGS,
		"Bags drop from BOSSES and elites and merchants stock them too. A found bag goes into your pack as a loose item: equip it yourself, keep a spare, or sell it. Equipping another bag with all %d slots occupied offers a swap; nothing is automatically sold." % Balance.MAX_BAGS,
		"Full bag? Select loose gear, a gem, or a consumable and DROP it to free a slot. New loot drops at your feet instead of vanishing. Ground overflow arrives in your MAILBOX (pause menu) when you leave the world or chapter. A guest's home save keeps that overflow as mail, including after a lost connection. Joining another world also mails drops left in your home world immediately. Ordinary solo saves keep local drops on the ground.",
		"Unopened combat chests and loose coins are saved too. When you resume or leave that world, a Recovered Spoils letter holds the exact chest contents and recovered gold goes straight to your purse. Hidden caches still require discovery. Unclaimed letters expire after %d days." % Balance.MAIL_EXPIRY_DAYS]:
		var bl := m._lbl(bags, String(line2), 13, Color(0.7, 0.72, 0.78))
		bl.custom_minimum_size = Vector2(PAGE_W, 0)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	m._lbl(list, "— CONSUMABLES —", 16, Color(0.6, 0.9, 1.0))
	var cons := VBoxContainer.new()
	cons.add_theme_constant_override("separation", 2)
	_card(list).add_child(cons)
	var cl := m._lbl(cons, "⟲ Stone of Unlearning — crush it (select it in the bag) to refund EVERY allocated talent point, attributes and substats alike, for reallocation. Elite drop (~1 in 3).", 13, Color(0.7, 0.72, 0.78))
	cl.custom_minimum_size = Vector2(PAGE_W, 0)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tl := m._lbl(cons, "⟲ Palimpsest of the Path — crush it to refund EVERY spent skill point and pick a new path down the tree. Elite drop, rarer than the Stone.", 13, Color(0.7, 0.72, 0.78))
	tl.custom_minimum_size = Vector2(PAGE_W, 0)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# No alchemical bullets (U+1F70x): that block is rarer than the U+2697
	# alembic dc673ab already proved renders as tofu on mobile, so these six
	# were the same bug one screen over. Names carry the list on their own.
	for util in [
		"Clean Accord potions come in grades F–S. Merchants sell F–A; S bottles are found as loot. Laced Black Market bottles cost less but carry a drawback. Buy them from the fence in Crownfall's Sable Court or a road smuggler. Their effects and prices scale by grade.",
		"BREWING: Visit Herbalist Kesh in Crownfall, open Professions, then choose Alchemy — browse & brew. With Alchemist active, brew clean F–A bottles from carried herbs and reagents of the bottle's exact grade, plus the displayed fee. Mastery unlocks higher grades; Draught of Renewal starts at C. Brewing raises Alchemist mastery, and changing trades keeps your progress.",
		"POTION BLUEPRINTS: F–C recipes need no blueprint. B and A each require a learned blueprint for that potion and enough Alchemist mastery. Bosses can drop recipes, or you can buy the exact one at the Alchemy bench. A blueprint is learned when acquired; learning one gives neither a bottle nor mastery. Potion recipes are separate from the gear blueprints in Professions.",
		"INGREDIENTS: Plant and fungal creatures in Sporewood and the Blooming Deep can drop F/E herbs; their elites can drop E/D. Beasts, humanoids and void creatures can drop reagents at those same grades. Boss supply chests can hold both ingredients, including C/B stock. Carry the exact grade shown by the recipe, and claim ingredients from mail before brewing.",
		"A-GRADE INGREDIENTS: Look to NG+ boss supplies: they can first contain A stock from Chapter 4 in NG+1, and from Chapter 1 in NG+2. The first journey's creature drops and supply chests do not provide A ingredients. You can learn an A recipe before its ingredients become available.",
		"GRAND POTIONS: Kesh's separate synthesis bench uses the Alkahest Codex. Bring a clean S bottle and its laced A counterpart to make a Grand potion. Ordinary brewing makes clean F–A bottles; it does not make laced, S or Grand potions.",
		"Health — a POTION restores a % of your MISSING health instantly; a TONIC restores the same total slower and cheaper (it drips over a grade-scaled window). The generic Health slot auto-pours your cheapest one; Chapters 1-3 gift a single Defective Health Potion that EXPIRES on leaving.",
		"Mana — a POTION restores a % of MISSING mana instantly; a TONIC restores a bigger total over time.",
		"Elixir of Might — a timed +damage window: pop it into the kill shot, not the whole fight.",
		"Elixir of Warding — a timed −incoming-damage window: quaff it just before a telegraphed blow.",
		"Draught of Renewal — instantly restore a % of your MAXIMUM health, the premium life-spike (C→S).",
		"Scroll of Recall — whisk yourself back to the last safe room (not in combat). Bought from merchants."]:
		var ul := m._lbl(cons, String(util), 13, Color(0.7, 0.72, 0.78))
		ul.custom_minimum_size = Vector2(PAGE_W, 0)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## The FUTURE shelf (dev launcher only): every placeholder in the project,
## one subtab per category — paintable terrains, salvaged mobs, quest-item
## curios, the themed armory, profession supplies, and world relics — plus
## the unplaced bestiary (mobs and bosses in no zone) and the review NPCs.
## This is the owner's review board: promote an entry by dropping its
## placeholder flag (or placing it in a zone) and giving it a real home.
static func _future(m: Menus, list: VBoxContainer, tab: String) -> void:
	if tab == "future_terrains":
		UITheme.header(m._lbl(list, "— PLACEHOLDER TERRAINS — paint any room via the dev panel —", 16, Color(0.7, 0.95, 0.85)))
		var tids: Array = Terrains.catalog_ids()
		tids.sort()
		var shown := 0
		for tid in tids:
			if not Terrains.DATA[tid].get("placeholder", false):
				continue
			_terrain_card(m, list, String(tid), "", true)
			shown += 1
		_none_waiting(m, list, shown)
	elif tab == "future_mobs":
		UITheme.header(m._lbl(list, "— SALVAGED MOBS — spawnable via the dev panel —", 16, Color(0.7, 0.95, 0.85)))
		_future_enemies(m, list, false)
	elif tab == "future_bosses":
		UITheme.header(m._lbl(list, "— PLACEHOLDER BOSSES — spawnable via the dev panel; no mechanics yet —", 16, Color(0.95, 0.7, 0.7)))
		_future_enemies(m, list, true)
	elif tab == "future_npcs":
		UITheme.header(m._lbl(list, "— PLACEHOLDER NPCS — wired into Maren's Camp for review —", 16, Color(0.7, 0.9, 1.0)))
		_future_npcs(m, list)
	elif tab == "future_items":
		UITheme.header(m._lbl(list, "— PLACEHOLDER QUEST ITEMS —", 16, Color(0.7, 0.95, 0.85)))
		_future_gallery(m, list, Story.ALL_QUEST_ITEMS, "", "icon", "desc")
	elif tab == "future_armory":
		UITheme.header(m._lbl(list, "— PLACEHOLDER ARMORY — themed pack weapons awaiting itemization —", 16, Color(0.95, 0.7, 0.6)))
		_future_gallery(m, list, Story.ALL_RELICS, "armory", "sprite", "lore")
	elif tab == "future_supplies":
		UITheme.header(m._lbl(list, "— TOOLS & MATERIALS — the professions seed —", 16, Color(0.75, 0.9, 0.7)))
		_future_gallery(m, list, Story.ALL_RELICS, "supplies", "sprite", "lore")
	elif tab == "future_provisions":
		UITheme.header(m._lbl(list, "— PROVISIONS — food, the future cooking consumables —", 16, Color(0.95, 0.85, 0.6)))
		_future_gallery(m, list, Story.ALL_RELICS, "provisions", "sprite", "lore")
	elif tab == "future_alchemy":
		UITheme.header(m._lbl(list, "— ALCHEMICAL ODDITIES — unused concept art —", 16, Color(0.95, 0.6, 0.65)))
		_future_gallery(m, list, Story.ALL_RELICS, "alchemy", "sprite", "lore")
	elif tab == "future_critters":
		UITheme.header(m._lbl(list, "— CRITTERS — livestock & wildlife for the living world —", 16, Color(0.85, 0.9, 0.6)))
		_future_gallery(m, list, Story.ALL_RELICS, "critters", "sprite", "lore")
	else:  # future_relics
		UITheme.header(m._lbl(list, "— PLACEHOLDER RELICS & LANDMARKS —", 16, Color(0.8, 0.75, 0.95)))
		_future_gallery(m, list, Story.ALL_RELICS, "", "sprite", "lore")


## Relic groups that own a dedicated Future subtab. The Relics shelf is the
## catch-all for every OTHER group (and the ungrouped) — a newly minted
## group lands there visibly instead of going invisible everywhere.
const FUTURE_GROUP_TABS := []


## One Future gallery: placeholder-flagged entries of `table` whose "group"
## matches (group "" = the catch-all above), rendered as curio cards.
static func _future_gallery(m: Menus, list: VBoxContainer, table: Dictionary, group: String, art_key: String, text_key: String) -> void:
	var ids: Array = table.keys()
	ids.sort()
	var jobs: Array = []
	for id in ids:
		var e: Dictionary = table[id]
		if not e.get("placeholder", false):
			continue
		var g: String = String(e.get("group", ""))
		if group == "":
			if g in FUTURE_GROUP_TABS:
				continue
		elif g != group:
			continue
		var nm := String(e.get("name", id))
		var dsc := String(e.get(text_key, ""))
		var art := String(e.get(art_key, ""))
		jobs.append(func() -> void: _curio_card(m, list, nm, dsc, art, true))
	_none_waiting(m, list, jobs.size())
	_build_chunked(m, list, jobs)


## Future bestiary shelves: every enemy of the bucket (mob / boss, split by
## the same BOSS_KINDS list the bestiary buckets by) that is placeholder-
## flagged OR placed in no zone — the same derivation the bestiary hides by,
## so nothing can fall between the two lists. Zero-reward boss-summon props
## (censers, roots, rods) are scenery, not candidates.
static func _future_enemies(m: Menus, list: VBoxContainer, bosses: bool) -> void:
	var used := _used_enemy_kinds()
	var kinds: Array = Story.ALL_ENEMIES.keys()
	kinds.sort()
	var morph := _morph_kind(m)
	var jobs: Array = []
	for kind in kinds:
		if (kind in m.BOSS_KINDS) != bosses:
			continue
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if st.get("xp", 0) <= 0 and st.get("gold", 0) <= 0:
			continue
		if used.has(kind) and not st.get("placeholder", false):
			continue
		var fk := String(kind)
		jobs.append(func() -> void:
			var card := _enemy_card(m, list, fk, bosses, false, true)
			if fk == morph:
				_scroll_to_card(m, card))
	_none_waiting(m, list, jobs.size())
	_build_chunked(m, list, jobs)


## Future NPC shelf: zone npc entries flagged `placeholder: true`, deduped
## by sprite, with the clean name (no "(placeholder)" suffix — the card tag
## already says it). The convo's review note, if any, rides along as the
## description.
static func _future_npcs(m: Menus, list: VBoxContainer) -> void:
	var seen := {}
	var jobs: Array = []
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			for npc in zone.get("npcs", []):
				if not npc.get("placeholder", false):
					continue
				var spr: String = String(npc.get("sprite", ""))
				if spr == "" or seen.has(spr):
					continue
				seen[spr] = true
				var nm: String = _npc_name(npc).replace(" (placeholder)", "")
				var desc := "Mined NPC art awaiting a role."
				var convo: String = String(npc.get("convo", ""))
				if convo != "" and Story.ALL_CONVOS.has(convo):
					var c: Dictionary = Story.ALL_CONVOS[convo]
					var nodes: Dictionary = c.get("nodes", {})
					var text: String = String(nodes.get(String(c.get("start", "")), {}).get("text", ""))
					# The convo text is boilerplate-in-brackets + optional note.
					var cut: int = text.find("]")
					if cut >= 0 and cut + 1 < text.length():
						var note: String = text.substr(cut + 1).strip_edges()
						if note != "":
							desc = note
				jobs.append(func() -> void: _curio_card(m, list, nm, desc, spr, true))
	_none_waiting(m, list, jobs.size())
	_build_chunked(m, list, jobs)


## Shared empty-state line for the Future shelves.
static func _none_waiting(m: Menus, list: VBoxContainer, shown: int) -> void:
	if shown == 0:
		m._lbl(list, "Nothing waiting in this category.", 13, Color(0.55, 0.55, 0.6))


## Unique names of a pool list (weighted lists repeat entries).
static func _uniq(pool: Array) -> Array:
	var seen := {}
	var out: Array = []
	for n in pool:
		if not seen.has(n):
			seen[n] = true
			out.append(String(n))
	return out


## One curio row: pixel icon (sprite key, or a prebuilt item texture) +
## name + flavor line. Small art renders NEAREST so it stays crisp.
static func _curio_card(m: Menus, list: VBoxContainer, name: String, desc: String, sprite: String, placeholder := false, tex: ImageTexture = null, w := 620.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card(list).add_child(row)
	var icon := TextureRect.new()
	if tex != null:
		icon.texture = tex
	elif sprite != "":
		icon.texture = Art.tex(sprite)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Painted high-resolution curios should downsample smoothly. Keep the
	# intentional tiny Raven/pixel placeholders crisp until they are replaced.
	var authored_size := 0
	if icon.texture != null:
		authored_size = maxi(icon.texture.get_width(), icon.texture.get_height())
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if authored_size >= 64 else CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var nm_txt := name + ("   [placeholder]" if placeholder else "")
	m._lbl(info, nm_txt, 16, Color(0.72, 0.68, 0.55) if placeholder else Color(0.92, 0.92, 0.98))
	if desc != "":
		var d := m._lbl(info, desc, 13, Color(0.66, 0.66, 0.72))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(w, 0)


# ------------------------------------------------------------------ gallery ---
# The portrait gallery: every painted splash installed in the build,
# silhouetted until this character has MET its bearer in dialogue
# (game.splashes_seen, marked by hud._set_splash). Heroes = the class
# splashes; Bosses = splashes matching a BOSS_KINDS enemy name; Folk = the
# rest of the cast. Click an unlocked portrait for the full painting.
# Decorated duplicates of one character (splash_fangmaw +
# splash_fangmaw_the_ravener) merge into a single entry — seen if EITHER
# was seen — mirroring hud._resolve_splash word-run matching.

static var _gallery_cache: Array = []  # built once per session; files never change mid-run
static var _thumbs := {}               # sprite -> downscaled ImageTexture (memory guard)


static func _gallery(m: Menus, list: VBoxContainer, tab: String) -> void:
	# Fold the live hero's memory + identity into the account ledger, then
	# write every unlock the union derives (kills, ownership) back into it —
	# so what one character earned stays lit for every other (2026-07-25).
	m.game.call("meta_fold_gallery")
	var bucket := tab.trim_prefix("gallery_")
	var entries: Array = []
	var seen_n := 0
	for e in _gallery_entries(m):
		if String(e["bucket"]) != bucket:
			continue
		if _gallery_seen(m, e):
			seen_n += 1
			m.game.call("meta_note_splash", String(e["sprite"]))
		entries.append(e)
	var shelf: String = {"heroes": "HEROES", "monsters": "MONSTERS", "bosses": "BOSSES", "npcs": "FOLK OF THE VALE"}.get(bucket, "PORTRAITS")
	m._lbl(list, "— %s —   met %d / %d" % [shelf, seen_n, entries.size()], 16, Color(0.95, 0.85, 0.5))
	m._lbl(list, "Painted key art unlocks as you MEET its bearer in conversation. Select a portrait to see the full painting.",
		12, Color(0.7, 0.72, 0.78))
	if entries.is_empty():
		m._lbl(list, "Nothing hangs on this shelf yet.", 13, Color(0.6, 0.62, 0.68))
		return
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	list.add_child(grid)
	# First-open thumbnail decodes are the whole cost of this shelf — stream
	# the cells a few per frame instead of decoding every splash in one go.
	var jobs: Array = []
	for e in entries:
		var ee: Dictionary = e
		jobs.append(func() -> void: _gallery_cell(m, grid, ee, tab))
	_build_chunked(m, list, jobs, 3)


## One portrait cell of the gallery grid (streamed via _build_chunked).
static func _gallery_cell(m: Menus, grid: GridContainer, e: Dictionary, back_tab: String) -> void:
	var unlocked := _gallery_seen(m, e)
	var sprite := String(e["sprite"])
	var disp := String(e["name"])
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	grid.add_child(cell)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(140, 105)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = _gallery_thumb(sprite)
	if unlocked:
		tr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tr.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index == MOUSE_BUTTON_LEFT:
				_portrait_view(m, sprite, disp, back_tab))
	else:
		# Silhouette: the shape teases, the face stays earned.
		tr.modulate = Color(0.05, 0.05, 0.08)
	cell.add_child(tr)
	var nm := m._lbl(cell, disp if unlocked else "???", 13,
		Color(0.92, 0.92, 0.98) if unlocked else Color(0.5, 0.52, 0.58))
	nm.custom_minimum_size = Vector2(140, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## The full painting, one click deep. Back returns to the shelf it came from.
static func _portrait_view(m: Menus, sprite: String, disp: String, back_tab: String) -> void:
	_build_gen += 1  # cancel a still-streaming shelf behind the painting
	var vbox := m._open(disp, 980, 640, true)
	m.current = "codex"
	var tr := TextureRect.new()
	tr.texture = Art.tex(sprite)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tr)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	m._btn(row, "  Back to the gallery  ", func() -> void: m.open_codex(back_tab),
		Color(0.8, 0.9, 1.0))
	m._hint(vbox, "ESC, X, or click outside to close")


## Downscaled thumbnail, cached per session — the shelf never decodes the
## full paintings (a hundred full-size splashes would eat hundreds of MB;
## the viewer loads full art one portrait at a time via Art.tex).
static func _gallery_thumb(sprite: String) -> Texture2D:
	if _thumbs.has(sprite):
		return _thumbs[sprite]
	var tex: Texture2D = null
	var res := ResourceLoader.load("res://assets/sprites/%s.png" % sprite, "",
		ResourceLoader.CACHE_MODE_IGNORE)
	if res is Texture2D:
		var img: Image = (res as Texture2D).get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var w := img.get_width()
			if w > 220:
				img.resize(220, int(float(img.get_height()) * 220.0 / float(w)),
					Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
	_thumbs[sprite] = tex
	return tex


static func _gallery_seen(m: Menus, e: Dictionary) -> bool:
	# Union of THIS hero's memory and the account ledger (owner 2026-07-25:
	# the gallery spans every character you own).
	var g = m.game
	if g.splashes_seen.has(String(e["sprite"])) \
			or bool(g.call("meta_gallery_seen", String(e["sprite"]))):
		return true
	for aka in e.get("aka", []):
		if g.splashes_seen.has(String(aka)) \
				or bool(g.call("meta_gallery_seen", String(aka))):
			return true
	# Fought = met: a boss this hero has KILLED hangs its painting even if it
	# never spoke (Fangmaw). kill_counts is the lifetime per-kind ledger.
	if String(e.get("kind", "")) != "" \
			and int(g.kill_counts.get(String(e["kind"]), 0)) > 0:
		return true
	# Owning a look hangs its painting (wardrobe purchases are account meta).
	# (2026-07-27) Awakened forms retired — ownership alone hangs it now.
	if String(e.get("skin_cls", "")) != "":
		if bool(g.owns_cosmetic("skin", String(e["skin_cls"]), String(e["skin_id"]))):
			return true
	return false


## Build the shelf inventory: scan installed splash_*.png / class_splash_*
## sprites, merge decorated duplicates, resolve display names against the
## cast (Story.ALL_ENEMIES) and bucket into heroes / bosses / npcs.
static func _gallery_entries(m: Menus) -> Array:
	if not _gallery_cache.is_empty():
		return _gallery_cache
	var names: Array = []
	var dir := DirAccess.open("res://assets/sprites")
	if dir != null:
		for f in dir.get_files():
			var fname := String(f)
			if fname.ends_with(".import") or fname.ends_with(".remap"):
				fname = fname.get_basename()  # exported builds list the stubs
			if not fname.ends_with(".png"):
				continue
			var base := fname.trim_suffix(".png")
			if (base.begins_with("splash_") or base.begins_with("class_splash_")) \
					and not names.has(base):
				names.append(base)

	# The cast by name-slug: display names + boss bucketing + the enemy KIND
	# (kill_counts is keyed by kind — fought counts as met, owner 2026-07-25).
	var cast_by_slug := {}
	var kind_by_slug := {}
	var boss_slugs := {}
	for kind in Story.ALL_ENEMIES:
		var nm := String(Story.ALL_ENEMIES[kind].get("name", kind))
		var sl := _gallery_slug(nm)
		cast_by_slug[sl] = nm
		kind_by_slug[sl] = String(kind)
		if kind in m.BOSS_KINDS:
			boss_slugs[sl] = true

	# Heroes first (fixed shelf: base classes, then skin forms), then the
	# world cast. Skin portraits (splash_skin_<cls>_<skin>[_awakened], the
	# Skins.skin_splash key) never enter the word-run merge below — each
	# form is its own painting, so awakened art can't fold into its base.
	var out: Array = []
	var world: Array = []
	for base in names:
		if base.begins_with("class_splash_"):
			var cls := String(base).trim_prefix("class_splash_")
			var cname := String(Classes.CLASSES.get(cls, {}).get("name", cls.capitalize()))
			out.append({"sprite": base, "aka": [], "name": cname,
				"bucket": "heroes", "sort": "0_" + cname})
		elif base.begins_with("splash_skin_"):
			var se := _gallery_skin_entry(String(base))
			if not se.is_empty():
				out.append(se)
		else:
			world.append(base)

	# Merge decorated duplicates: a shorter slug folds into the longest
	# entry that contains its words as a contiguous run (or its compact
	# spelling, "choirmother" inside "the_choir_mother"). Longest names
	# first so the decorated painting is the one that hangs.
	world.sort_custom(func(a: String, b: String) -> bool:
		return a.split("_").size() > b.split("_").size())
	var merged: Array = []
	for base in world:
		var slug := String(base).trim_prefix("splash_")
		var words := slug.split("_", false)
		var host: Dictionary = {}
		for entry in merged:
			var ewords: PackedStringArray = String(entry["slug"]).split("_", false)
			if _gallery_word_run(words, ewords) \
					or (slug.replace("_", "").length() >= 5
						and String(entry["slug"]).replace("_", "").contains(slug.replace("_", ""))):
				host = entry
				break
		if host.is_empty():
			merged.append({"sprite": base, "slug": slug, "aka": []})
		else:
			(host["aka"] as Array).append(base)

	for entry in merged:
		var slug := String(entry["slug"])
		var disp: String = cast_by_slug.get(slug, "")
		var ekind: String = kind_by_slug.get(slug, "")
		var is_boss: bool = boss_slugs.has(slug)
		if disp == "":
			# The aka slugs may carry the cast match ("vargoth" merged under
			# a decorated file) — check them before falling back to a
			# title-cased filename.
			for aka in entry["aka"]:
				var aslug := String(aka).trim_prefix("splash_")
				if cast_by_slug.has(aslug):
					disp = String(cast_by_slug[aslug])
					ekind = String(kind_by_slug.get(aslug, ekind))
					is_boss = is_boss or boss_slugs.has(aslug)
					break
		if disp == "":
			disp = slug.capitalize()
		# Three-way bucket: a boss shelves under Bosses; a splash whose name
		# resolves to a non-boss enemy KIND (ekind != "") is a Monster; anyone
		# left — the speaking cast with no enemy form — is Folk. (A creature
		# that is both a mob and a townsperson, the cultist, shelves as a
		# Monster: its enemy kind wins.)
		var gbucket := "npcs"
		if is_boss:
			gbucket = "bosses"
		elif ekind != "":
			gbucket = "monsters"
		out.append({"sprite": String(entry["sprite"]), "aka": entry["aka"],
			"name": disp, "kind": ekind,
			"bucket": gbucket, "sort": disp})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("sort", a["name"])) < String(b.get("sort", b["name"])))
	_gallery_cache = out
	return out


## A skin portrait entry: class parsed off the filename, display name from
## the skins registry ("Stormforged — Awakened  (Warrior)"). Skins shelve
## AFTER the base classes, grouped by class, base form before awakened.
## Carries skin_cls/skin_id so OWNING the look hangs its painting (account
## meta — owner 2026-07-25: the gallery spans your whole roster).
static func _gallery_skin_entry(base: String) -> Dictionary:
	# (2026-07-27) Resolve the file to the skin that CLAIMS it via
	# Skins.skin_splash — per-skin `splash` overrides (the two Phantom forms)
	# make filename-derivation lie, and a splash NO skin claims (the retired
	# placeholder awakened forms — art kept on disk per the never-delete rule)
	# hangs nowhere. Returns {} for unclaimed files; the caller skips those.
	for cls in Skins.SKINS:
		for sk in Skins.skins_for(String(cls)):
			var sid := String(sk["id"])
			if Skins.skin_splash(String(cls), sid) == base:
				var nm := String(sk.get("name", sid.capitalize()))
				nm += "  (%s)" % String(Classes.CLASSES.get(cls, {}).get("name", String(cls).capitalize()))
				return {"sprite": base, "aka": [], "name": nm, "bucket": "heroes",
					"skin_cls": String(cls), "skin_id": sid,
					"sort": "1_%s_%s" % [cls, sid]}
	return {}


## Are the shorter slug words a contiguous run inside the longer ones?
## ("vargoth" in "king_vargoth_the_hollow" — hud._resolve_splash rule.)
static func _gallery_word_run(short_w: PackedStringArray, long_w: PackedStringArray) -> bool:
	var span := short_w.size()
	if span == 0 or span >= long_w.size():
		return false
	for start in range(0, long_w.size() - span + 1):
		var okay := true
		for i in span:
			if long_w[start + i] != short_w[i]:
				okay = false
				break
		if okay:
			return true
	return false


## Speaker/enemy name -> filename slug (hud._splash_slug rule, static).
static func _gallery_slug(s: String) -> String:
	var out := ""
	var prev_us := true
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
			prev_us = false
		elif not prev_us:
			out += "_"
			prev_us = true
	return out.trim_suffix("_")
