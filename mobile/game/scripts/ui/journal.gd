class_name UIJournal
## Player journal: four intent-based surfaces instead of one long mixed feed.
## Static module taking the Menus instance, like ui/mailbox.gd and ui/codex.gd.

const FACTION_NAME := {
	"accord": "The Accord", "cinderborn": "The Cinderborn",
	"wildfang": "The Wildfang", "choir": "The Hollow Choir",
}
const GOLD := Color(0.95, 0.85, 0.5)
const GREEN := Color(0.58, 1.0, 0.65)
const BLUE := Color(0.62, 0.86, 1.0)
const PURPLE := Color(0.86, 0.65, 1.0)
const MUTED := Color(0.63, 0.65, 0.72)
const BODY := Color(0.86, 0.88, 0.94)
const CARD_TEXT_WIDTH := 744.0


static func open(m: Menus, requested_tab := "") -> void:
	var g := m.game
	g.refresh_bounties()
	var tab := String(requested_tab)
	if tab == "log":
		tab = "quests" # Backward compatibility for old callers.
	if tab == "":
		tab = String(m.get_meta("journal_tab", "quests"))
	if not tab in ["quests", "activities", "progress", "story"]:
		tab = "quests"
	m.set_meta("journal_tab", tab)

	var vbox := m._open("Journal — %s" % String(Story.chapter(g.chapter_id)["name"]), 920, 650, true)
	m.current = "journal"
	_tabs(m, vbox, tab)
	_context_strip(m, vbox, tab)

	var scroll := ScrollContainer.new()
	scroll.name = "JournalScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "JournalContent"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	match tab:
		"activities":
			_activities(m, list)
		"progress":
			_progress_page(m, list)
		"story":
			_archive(m, list)
		_:
			_quests(m, list)
	m._hint(vbox, "1–4 switch sections  ·  ESC, ✕, or click outside to close")


static func _tabs(m: Menus, parent: VBoxContainer, active: String) -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "JournalTabs"
	tabs.add_theme_constant_override("separation", 7)
	parent.add_child(tabs)

	var active_side := _active_side_count(m.game)
	var nearby := _available_side_count(m.game)
	var bounty_done := 0
	for b in m.game.bounties:
		if bool(b.get("done", false)):
			bounty_done += 1
	var visited := _visited_count(m.game)
	var story_count: int = m.game.convo_log_order.size()
	var quest_suffix := str(1 + active_side)
	if nearby > 0:
		quest_suffix += " +%d" % nearby
	var key_prefix := ["", "", "", ""] if m.game.touch_mode else ["1  ", "2  ", "3  ", "4  "]
	var specs := [
		["quests", "%sQUESTS  ·  %s" % [key_prefix[0], quest_suffix], GOLD, KEY_1],
		["activities", "%sACTIVITIES  ·  %d/%d" % [key_prefix[1], bounty_done, m.game.bounties.size()], GREEN, KEY_2],
		["progress", "%sPROGRESS  ·  %d/%d" % [key_prefix[2], visited, m.game.zone_count], BLUE, KEY_3],
		["story", "%sSTORY  ·  %d" % [key_prefix[3], story_count], PURPLE, KEY_4],
	]
	for spec in specs:
		_nav_button(m, tabs, String(spec[0]), String(spec[1]), spec[2], int(spec[3]), active)


static func _nav_button(m: Menus, parent: HBoxContainer, id: String, text: String,
		color: Color, keycode: int, active: String) -> void:
	var b := m._btn(parent, text, func() -> void: m.open_journal(id),
		color if id == active else Color(0.72, 0.72, 0.76))
	b.name = "JournalTab_" + id
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 44)
	b.tooltip_text = "Open %s  [%d]" % [id.capitalize(), keycode - KEY_0]
	if not m.game.touch_mode:
		var shortcut := Shortcut.new()
		var key := InputEventKey.new()
		key.keycode = keycode as Key
		shortcut.events = [key]
		b.shortcut = shortcut
		b.shortcut_in_tooltip = false
	if id == active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(color, 0.13)
		sb.border_color = Color(color, 0.95)
		sb.border_width_bottom = 3
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", color)


static func _context_strip(m: Menus, parent: VBoxContainer, tab: String) -> void:
	var g := m.game
	var text := ""
	var color := MUTED
	match tab:
		"quests":
			var room_left: int = g.zone_alive.get(clampi(g.cur_room, 0, g.zone_count - 1), 0)
			text = "ACTIVE PATH  •  %d side quest%s  •  %d nearby  •  %d enem%s in this room" % [
				_active_side_count(g), "" if _active_side_count(g) == 1 else "s",
				_available_side_count(g), room_left, "y" if room_left == 1 else "ies"]
			color = GOLD
		"activities":
			text = "ROTATING ACTIVITIES  •  rewards are granted automatically when bounties complete"
			if g.vault_ready():
				text += "  •  VAULT REWARD READY"
				color = GOLD
			else:
				color = GREEN
		"progress":
			text = "CHAPTER OVERVIEW  •  route, bosses, Resonance, and faction standing"
			color = BLUE
		"story":
			text = "YOUR ARCHIVE  •  replay every conversation and choice recorded on this character"
			color = PURPLE
	var strip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07)
	sb.border_color = Color(color, 0.28)
	sb.border_width_left = 3
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	strip.add_theme_stylebox_override("panel", sb)
	parent.add_child(strip)
	var label := m._lbl(strip, text, 12, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# -------------------------------------------------------------- QUESTS ---

static func _quests(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "MAIN QUEST", "Your immediate path", GOLD)
	var main := _card(list, GOLD)
	var obj := g.touchify(Story.quest_text(g.quest_key))
	_status_line(m, main, "◆  IN PROGRESS", "STORY", GOLD)
	var title := m._lbl(main, obj if obj != "" else "Explore.", 18, Color.WHITE)
	_wrap(title)
	var zi: int = clampi(g.cur_room, 0, g.zone_count - 1)
	var left: int = g.zone_alive.get(zi, 0)
	if left > 0:
		m._lbl(main, "Current room  ·  %d monster%s remain" % [left, "" if left == 1 else "s"],
			13, Color(0.88, 0.72, 0.48))
	else:
		m._lbl(main, "Current room clear  ·  continue along the route", 13, GREEN)
	_side_quests(m, list)
	_available_quests(m, list)


static func _side_quests(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	var entries: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		if String(q.get("chapter", "")) == g.chapter_id \
				and g.get_flag("sq_on_" + String(id), false):
			entries.append([String(id), q])
	if entries.is_empty():
		return
	_section(m, list, "SIDE QUESTS", "%d accepted promise%s" % [
		entries.size(), "" if entries.size() == 1 else "s"], GREEN)
	for entry in entries:
		var id: String = entry[0]
		var q: Dictionary = entry[1]
		var paid: bool = g.get_flag("sq_paid_" + id, false)
		var card := _card(list, GREEN if paid else Color(0.75, 0.9, 0.6))
		_status_line(m, card, "✓  COMPLETE" if paid else "⚑  ACTIVE",
			"SIDE QUEST", GREEN if paid else Color(0.9, 0.88, 0.55))
		var name := m._lbl(card, String(q["name"]), 16, Color(0.84, 1.0, 0.82) if paid else Color.WHITE)
		_wrap(name)
		if paid:
			m._lbl(card, "Promise kept and reward collected.", 12, MUTED)
			continue
		var desc := m._lbl(card, String(q.get("desc", "")), 13, BODY)
		_wrap(desc)
		var steps: Array = q.get("steps", [])
		var done_steps := 0
		for step in steps:
			if g.get_flag(String(step["flag"]), false):
				done_steps += 1
		_meter(m, card, done_steps, steps.size(), GREEN,
			"OBJECTIVES", "%d / %d" % [done_steps, steps.size()])
		for step in steps:
			var done: bool = g.get_flag(String(step["flag"]), false)
			m._lbl(card, "%s  %s" % ["✓" if done else "◇", String(step["text"])],
				13, GREEN if done else Color(0.9, 0.85, 0.7))
		m._lbl(card, "⌛  Chapter deadline  ·  finish before the final boss",
			12, Color(0.98, 0.7, 0.42))


static func _available_quests(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	var open_quests: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		if g.side_quest_available(String(id)):
			open_quests.append(Story.ALL_SIDE_QUESTS[id])
	if open_quests.is_empty():
		return
	_section(m, list, "NEARBY OPPORTUNITIES", "Not accepted yet", Color(0.95, 0.75, 0.38))
	for q in open_quests:
		var card := _card(list, Color(0.95, 0.75, 0.38))
		_status_line(m, card, "❢  AVAILABLE", "LOOK FOR THE MARKED LOCAL", Color(0.95, 0.78, 0.4))
		var name := m._lbl(card, String(q["name"]), 16, Color.WHITE)
		_wrap(name)
		var desc := m._lbl(card, String(q.get("desc", "")), 13, BODY)
		_wrap(desc)


# ---------------------------------------------------------- ACTIVITIES ---

static func _activities(m: Menus, list: VBoxContainer) -> void:
	_bounties(m, list)
	_vault(m, list)
	_weekly(m, list)
	_waking(m, list)


static func _bounties(m: Menus, list: VBoxContainer) -> void:
	_section(m, list, "BOUNTIES", "Automatic rewards · daily and weekly rotations", GREEN)
	if m.game.bounties.is_empty():
		var empty := _card(list, MUTED)
		m._lbl(empty, "No bounties active.", 14, MUTED)
		return
	for scope in ["daily", "weekly"]:
		var scope_entries: Array = []
		for b in m.game.bounties:
			if String(b["scope"]) == scope:
				scope_entries.append(b)
		if scope_entries.is_empty():
			continue
		var scope_name := "DAILY" if scope == "daily" else "WEEKLY"
		for b in scope_entries:
			var done: bool = bool(b["done"])
			var card := _card(list, GREEN if done else (BLUE if scope == "daily" else PURPLE))
			_status_line(m, card, "✓  COMPLETE" if done else "○  %s BOUNTY" % scope_name,
				"REWARD PAID" if done else "IN PROGRESS", GREEN if done else BODY)
			var title := m._lbl(card, String(b["desc"]), 15, Color.WHITE)
			_wrap(title)
			_meter(m, card, int(b["progress"]), int(b["target"]),
				GREEN if done else (BLUE if scope == "daily" else PURPLE),
				"PROGRESS", "%d / %d" % [int(b["progress"]), int(b["target"])])
			var reward := "%d gold" % int(b["gold"])
			if int(b["gems"]) > 0:
				reward += "  + 1 gem"
			if int(b.get("renown", 0)) > 0:
				reward += "  + ◈%d Renown" % int(b["renown"])
			m._lbl(card, "Reward  ·  " + reward, 12, Color(0.9, 0.82, 0.58))


static func _vault(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "WEEKLY VAULT", "A guaranteed high-value reward", GOLD)
	var ready: bool = g.vault_ready()
	var claimed: bool = g.vault_claimed_week == g._week_index()
	var card := _card(list, GOLD if ready else Color(0.76, 0.65, 0.38))
	_status_line(m, card, "◆  REWARD READY" if ready else ("✓  CLAIMED" if claimed else "◇  BUILDING"),
		"WEEKLY", GOLD if ready else (GREEN if claimed else BODY))
	var prog: int = g.vault_progress if g._week_index() == g.vault_week else 0
	var goal: int = Balance.VAULT_BOSS_GOAL
	_meter(m, card, mini(prog, goal), goal, GOLD, "BOSSES DEFEATED",
		"%d / %d" % [mini(prog, goal), goal])
	m._lbl(card, "Golden chest  +  ◈%d Renown" % Balance.RENOWN_VAULT, 13, Color(0.95, 0.86, 0.58))
	if ready:
		var claim := m._btn(card, "  ◆  CLAIM VAULT REWARD  ", func() -> void:
			g.claim_vault()
			m.open_journal("activities"), GOLD)
		claim.alignment = HORIZONTAL_ALIGNMENT_CENTER
		claim.custom_minimum_size = Vector2(0, 44)
	elif claimed:
		m._lbl(card, "Collected for this rotation · returns next week.", 12, MUTED)
	else:
		m._lbl(card, "%d more boss%s to unlock." % [
			maxi(0, goal - prog), "" if goal - prog == 1 else "es"], 12, MUTED)


static func _weekly(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "WEEKLY CHALLENGE", "Fixed map · shared rules · personal best", PURPLE)
	var mod: Dictionary = g.weekly_mod()
	var chname := String(Story.chapter(g.weekly_chapter())["name"])
	var live: bool = g.weekly_active and g.weekly_week == g._week_index()
	var card := _card(list, PURPLE)
	_status_line(m, card, "◆  LIVE RUN" if live else "◇  AVAILABLE", chname.to_upper(), PURPLE)
	var title := m._lbl(card, String(mod["name"]), 17, Color.WHITE)
	_wrap(title)
	var desc := m._lbl(card, String(mod["desc"]), 13, BODY)
	_wrap(desc)
	m._lbl(card, "Same seed for every player this week.", 12, MUTED)
	var best: Dictionary = g.weekly_best()
	if not best.is_empty():
		var secs := int(float(best.get("time", 0.0)))
		m._lbl(card, "Personal best  ·  %d:%02d  ·  %s  ·  grade %s" % [
			secs / 60, secs % 60,
			String(Classes.CLASSES.get(String(best.get("cls", "warrior")), {}).get("name", "?")),
			String(best.get("grade", "?"))], 13, GREEN)
	if g.weekly_claimed_week == g._week_index():
		m._lbl(card, "Weekly reward collected · keep racing to improve your time.", 12, MUTED)
	else:
		m._lbl(card, "First clear pays gold, gems, and ◈%d Renown." % Balance.RENOWN_WEEKLY,
			12, Color(0.9, 0.82, 0.58))
	if not live:
		var start := m._btn(card, "  BEGIN WEEKLY RUN  →  ", func() -> void:
			m.open_confirm(
				"Begin this week's challenge? It restarts %s from its beginning on the week's fixed map, with '%s' live (%s). Your character, gear and Resonance carry in — chapter story progress resets, like any replay." %
					[chname, String(mod["name"]), String(mod["desc"])],
				func() -> void: g.start_weekly()), PURPLE)
		start.alignment = HORIZONTAL_ALIGNMENT_CENTER
		start.custom_minimum_size = Vector2(0, 44)


static func _waking(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "THE WAKING", "Weekly incursion", BLUE)
	var wk_ch := g.weekly_chapter()
	var chname := String(Story.chapter(wk_ch)["name"])
	var can_wake: bool = g.get_flag("completed_" + wk_ch, false) \
		and not Story.chapter(wk_ch).get("spine", []).is_empty()
	var banked: int = g.waking_kills.size() if g.waking_kills_week == g._week_index() else 0
	var card := _card(list, BLUE if can_wake else MUTED)
	_status_line(m, card, "◆  OPEN" if can_wake else "◇  LOCKED", chname.to_upper(),
		BLUE if can_wake else MUTED)
	if can_wake:
		var desc := m._lbl(card,
			"Three breach rooms branch off the chapter spine. Hunt the echoes solo.",
			13, BODY)
		_wrap(desc)
		_meter(m, card, banked, Balance.WAKING_ROOMS, BLUE, "BREACHES SEALED",
			"%d / %d" % [banked, Balance.WAKING_ROOMS])
		m._lbl(card, "Each breach pays a bright gem + gold; seal all for the Waking Chest + ◈%d Renown." %
			Balance.RENOWN_WAKING, 12, Color(0.82, 0.9, 1.0))
	else:
		var lock_text := m._lbl(card, "Clear %s to open its breaches." % chname, 13, MUTED)
		_wrap(lock_text)


# ------------------------------------------------------------ PROGRESS ---

static func _progress_page(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "CHAPTER ROUTE", "What you have charted and conquered", BLUE)
	var route := _card(list, BLUE)
	var visited := _visited_count(g)
	_meter(m, route, visited, g.zone_count, BLUE, "ROOMS CHARTED",
		"%d / %d" % [visited, g.zone_count])
	m._lbl(route, "Current position  ·  room %d of %d" % [
		clampi(g.cur_room + 1, 1, g.zone_count), g.zone_count], 13, BODY)

	_section(m, list, "CHAPTER BOSSES", "Unique encounters on this route", Color(1.0, 0.62, 0.62))
	var bosses := _card(list, Color(1.0, 0.62, 0.62))
	var seen := {}
	var any_boss := false
	var boss_total := 0
	var boss_done := 0
	for i in g.zone_count:
		var kind := String(g.zones[i].get("boss", ""))
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		any_boss = true
		boss_total += 1
		var done: bool = g.boss_done.get(kind, false)
		if done:
			boss_done += 1
		var nm := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind))
		m._lbl(bosses, "%s  %s" % ["✓" if done else "○", nm],
			14, GREEN if done else BODY)
	if any_boss:
		_meter(m, bosses, boss_done, boss_total, Color(1.0, 0.62, 0.62),
			"BOSSES DEFEATED", "%d / %d" % [boss_done, boss_total])
	else:
		m._lbl(bosses, "None charted yet.", 13, MUTED)

	_section(m, list, "CHARACTER PATH", "Consequences carried by this character", PURPLE)
	var path := _card(list, PURPLE)
	var res := int(g.player.resonance)
	var band := "Virtuous" if res > 20 else ("Tempted" if res < -20 else "Balanced")
	_status_line(m, path, "RESONANCE", "%+d  ·  %s" % [res, band],
		Color(1.0, 0.85, 0.4) if res > 20 else (PURPLE if res < -20 else BODY))
	var any_standing := false
	for fid in g.player.faction_standing:
		var value: int = int(g.player.faction_standing[fid])
		if value == 0:
			continue
		any_standing = true
		var fname: String = FACTION_NAME.get(fid, String(fid).capitalize())
		m._lbl(path, "%s   %+d" % [fname, value], 14,
			GREEN if value > 0 else Color(1.0, 0.68, 0.58))
	if not any_standing:
		m._lbl(path, "No faction has taken your measure yet.", 13, MUTED)


# --------------------------------------------------------- STORY ARCHIVE ---

static func _archive(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	_section(m, list, "STORY SO FAR", "Re-read dialogue, choices, and roadside conversations", PURPLE)
	if g.convo_log_order.is_empty():
		var empty := _card(list, MUTED)
		m._lbl(empty, "Nothing is written yet.", 15, BODY)
		m._lbl(empty, "The road will fill these pages as you speak, choose, and remember.",
			13, MUTED)
		return
	var placed := {}
	for chid in Story.CHAPTER_LIST:
		var keys: Array = []
		for key in g.convo_log_order:
			if String(g.convo_log.get(key, {}).get("chapter", "")) == String(chid):
				keys.append(key)
				placed[key] = true
		if keys.is_empty():
			continue
		_section(m, list, String(Story.chapter(String(chid))["name"]).to_upper(),
			"%d entr%s" % [keys.size(), "y" if keys.size() == 1 else "ies"], GOLD)
		for key in keys:
			_archive_row(m, list, String(key))
	var leftovers: Array = []
	for key in g.convo_log_order:
		if not placed.has(key):
			leftovers.append(key)
	if not leftovers.is_empty():
		_section(m, list, "ELSEWHERE", "%d entr%s" % [
			leftovers.size(), "y" if leftovers.size() == 1 else "ies"], PURPLE)
		for key in leftovers:
			_archive_row(m, list, String(key))


static func _archive_row(m: Menus, list: VBoxContainer, key: String) -> void:
	var lines: Array = m.game.convo_log.get(key, {}).get("lines", [])
	var card := _card(list, PURPLE)
	_status_line(m, card, "RECORDED", "%d lines" % lines.size(), PURPLE)
	var title := m._lbl(card, m.game.touchify(_archive_title(key)), 15, Color.WHITE)
	_wrap(title)
	var read := m._btn(card, "  READ TRANSCRIPT  →  ", func() -> void: _read(m, key), BLUE)
	read.alignment = HORIZONTAL_ALIGNMENT_CENTER
	read.custom_minimum_size = Vector2(0, 44)


static func _archive_title(key: String) -> String:
	if key.begins_with("wanders_"):
		return "Wanderings — talk of the road"
	var text := Story.quest_text(key)
	return text if text != "" else key.capitalize()


static func _read(m: Menus, key: String) -> void:
	var title := m.game.touchify(_archive_title(key))
	if title.length() > 64:
		title = title.substr(0, 61) + "..."
	var vbox := m._open("Story — %s" % title, 900, 640, true)
	m.current = "journal"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for line in m.game.convo_log.get(key, {}).get("lines", []):
		var who := String(line[0])
		var text := m.game.touchify(String(line[1]))
		var label: Label
		if who == "You":
			label = m._lbl(list, text, 14, GREEN)
		elif who == "" or who == "Narrator":
			label = m._lbl(list, text, 13, Color(0.72, 0.76, 0.92))
		else:
			label = m._lbl(list, "%s —  %s" % [who, text], 14, Color(0.92, 0.88, 0.72))
		label.custom_minimum_size = Vector2(830, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := m._btn(vbox, "  ←  BACK TO STORY ARCHIVE  ", func() -> void:
		m.open_journal("story"), BLUE)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(0, 44)
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


# ------------------------------------------------------------- UI HELPERS ---

static func _section(m: Menus, parent: VBoxContainer, title: String,
		subtitle: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var heading := m._lbl(row, title, 15, color)
	UITheme.header(heading)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.custom_minimum_size = Vector2(280, 0)
	var note := m._lbl(row, subtitle, 12, MUTED)
	note.custom_minimum_size = Vector2(430, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func _card(parent: VBoxContainer, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.16, 0.78)
	sb.border_color = Color(accent, 0.42)
	sb.border_width_left = 3
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 13
	sb.content_margin_right = 13
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box


static func _status_line(m: Menus, parent: VBoxContainer, left: String,
		right: String, color: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var status := m._lbl(row, left, 11, color)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size = Vector2(360, 0)
	var tag := m._lbl(row, right, 11, MUTED)
	tag.custom_minimum_size = Vector2(260, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


static func _meter(m: Menus, parent: VBoxContainer, value: int, maximum: int,
		color: Color, left: String, right: String) -> void:
	var labels := HBoxContainer.new()
	parent.add_child(labels)
	var label := m._lbl(labels, left, 11, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(360, 0)
	var count := m._lbl(labels, right, 11, color)
	count.custom_minimum_size = Vector2(140, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar := ProgressBar.new()
	bar.name = "JournalMeter"
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = maxi(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.custom_minimum_size = Vector2(0, 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.035, 0.055, 0.95)
	bg.border_color = Color(color, 0.28)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(color, 0.86)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)


static func _wrap(label: Label) -> void:
	label.custom_minimum_size = Vector2(CARD_TEXT_WIDTH, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _active_side_count(g: Game) -> int:
	var count := 0
	for id in Story.ALL_SIDE_QUESTS:
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		if String(q.get("chapter", "")) == g.chapter_id \
				and g.get_flag("sq_on_" + String(id), false) \
				and not g.get_flag("sq_paid_" + String(id), false):
			count += 1
	return count


static func _available_side_count(g: Game) -> int:
	var count := 0
	for id in Story.ALL_SIDE_QUESTS:
		if g.side_quest_available(String(id)):
			count += 1
	return count


static func _visited_count(g: Game) -> int:
	var count := 0
	for i in g.zone_count:
		if g.visited.get(i, false):
			count += 1
	return count
