class_name UIJournal
## The Quest Log / journal. Static builder taking the Menus instance, like
## ui/mailbox.gd and ui/codex.gd. The game's live quest is a single active
## line (game.quest_key -> Story.ALL_QUESTS); this screen frames it with
## chapter boss progress, exploration, factions and Resonance so the
## player has one place to see "where am I and what's next".
## Reached from the HUD ⚑ (left of the quest tracker) and the pause menu.

const FACTION_NAME := {
	"accord": "The Accord", "cinderborn": "The Cinderborn",
	"wildfang": "The Wildfang", "choir": "The Hollow Choir",
}


static func open(m: Menus, tab := "log") -> void:
	var g := m.game
	g.refresh_bounties()  # make sure the day/week sets are current
	var vbox := m._open("Quest Log — %s" % String(Story.chapter(g.chapter_id)["name"]), 860, 640, true)
	m.current = "journal"

	# Tabs: the LIVE log | the story-so-far archive (past quests, re-readable).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	m._btn(tabs, "  Quest Log  ", func() -> void: m.open_journal("log"),
		Color(0.95, 0.85, 0.5) if tab == "log" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Story So Far  ", func() -> void: m.open_journal("story"),
		Color(0.95, 0.85, 0.5) if tab == "story" else Color(0.6, 0.6, 0.6))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	if tab == "story":
		_archive(m, list)
		m._hint(vbox, "ESC, ✕, or click anywhere outside to close")
		return

	# --- current objective ---
	m._lbl(list, "— CURRENT OBJECTIVE —", 16, Color(0.95, 0.85, 0.5))
	var obj := Story.quest_text(g.quest_key)
	var ol := m._lbl(list, "◆  " + (obj if obj != "" else "Explore."), 16, Color(1, 1, 1))
	ol.custom_minimum_size = Vector2(800, 0)
	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var zi: int = clampi(g.cur_room, 0, g.zone_count - 1)
	var left: int = g.zone_alive.get(zi, 0)
	if left > 0:
		m._lbl(list, "   This room: %d monster%s left to clear." % [left, "" if left == 1 else "s"],
			13, Color(0.8, 0.7, 0.5))

	_side_quests(m, list)
	_bounties(m, list)
	_vault(m, list)
	_weekly(m, list)

	# --- chapter boss checklist ---
	m._lbl(list, "— CHAPTER BOSSES —", 16, Color(1, 0.6, 0.6))
	var bosses := VBoxContainer.new()
	bosses.add_theme_constant_override("separation", 2)
	list.add_child(bosses)
	var seen := {}
	var any_boss := false
	for i in g.zone_count:
		var kind := String(g.zones[i].get("boss", ""))
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		any_boss = true
		var done: bool = g.boss_done.get(kind, false)
		var nm := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind))
		m._lbl(bosses, "%s  %s" % ["✓" if done else "○", nm],
			14, Color(0.6, 1.0, 0.6) if done else Color(0.85, 0.85, 0.9))
	if not any_boss:
		m._lbl(bosses, "None charted yet.", 13, Color(0.6, 0.62, 0.68))

	# --- exploration + resonance ---
	m._lbl(list, "— PROGRESS —", 16, Color(0.6, 0.9, 1.0))
	var visited := 0
	for i in g.zone_count:
		if g.visited.get(i, false):
			visited += 1
	m._lbl(list, "Rooms charted:  %d / %d" % [visited, g.zone_count], 14, Color(0.85, 0.88, 0.94))
	var res := int(g.player.resonance)
	var band := "Virtuous" if res > 20 else ("Tempted" if res < -20 else "Balanced")
	m._lbl(list, "Resonance:  %+d  (%s)" % [res, band], 14,
		Color(1.0, 0.85, 0.4) if res > 20 else (Color(0.7, 0.5, 0.95) if res < -20 else Color(0.85, 0.85, 0.9)))

	# --- factions ---
	m._lbl(list, "— STANDING —", 16, Color(0.8, 0.9, 0.7))
	for fid in g.player.faction_standing:
		var v: int = int(g.player.faction_standing[fid])
		if v == 0:
			continue
		var fname: String = FACTION_NAME.get(fid, String(fid).capitalize())
		m._lbl(list, "%s:  %+d" % [fname, v], 14,
			Color(0.7, 1.0, 0.7) if v > 0 else Color(1.0, 0.7, 0.6))
	var neutral := true
	for fid in g.player.faction_standing:
		if int(g.player.faction_standing[fid]) != 0:
			neutral = false
	if neutral:
		m._lbl(list, "No faction has taken your measure yet.", 13, Color(0.6, 0.62, 0.68))

	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


# -------------------------------------------------------- story so far ---
# The past-quests archive: every conversation this character has lived,
# bucketed under the quest that was live when it played (game.convo_log,
# recorded at the dialogue box so variants, beats and choices land exactly
# as seen), grouped by chapter, re-readable in full.

static func _archive(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	if g.convo_log_order.is_empty():
		m._lbl(list, "Nothing is written yet — the road will fill these pages.",
			14, Color(0.6, 0.62, 0.68))
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
		m._lbl(list, "— %s —" % String(Story.chapter(String(chid))["name"]).to_upper(),
			16, Color(0.95, 0.85, 0.5))
		for key in keys:
			_archive_row(m, list, String(key))
	# Anything bucketed outside the campaign list (endgame trials, oddities).
	var leftovers: Array = []
	for key in g.convo_log_order:
		if not placed.has(key):
			leftovers.append(key)
	if not leftovers.is_empty():
		m._lbl(list, "— ELSEWHERE —", 16, Color(0.85, 0.6, 1.0))
		for key in leftovers:
			_archive_row(m, list, String(key))


static func _archive_row(m: Menus, list: VBoxContainer, key: String) -> void:
	var g := m.game
	var lines: Array = g.convo_log.get(key, {}).get("lines", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	list.add_child(row)
	m._btn(row, "  Read  ", func() -> void: _read(m, key), Color(0.8, 0.9, 1.0))
	var tl := m._lbl(row, "%s   ·  %d lines" % [_archive_title(key), lines.size()],
		14, Color(0.9, 0.88, 0.8))
	tl.custom_minimum_size = Vector2(620, 0)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## A bucket's heading: the quest objective that was live, or the roadside
## catch-all for talk between quests ("wanders_<chapter>" keys).
static func _archive_title(key: String) -> String:
	if key.begins_with("wanders_"):
		return "Wanderings — talk of the road"
	var t := Story.quest_text(key)
	return t if t != "" else key.capitalize()


## The transcript, exactly as it played: choices in green, the Narrator in
## dusk-blue, every named speaker in parchment gold.
static func _read(m: Menus, key: String) -> void:
	var title := _archive_title(key)
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
	for l in m.game.convo_log.get(key, {}).get("lines", []):
		var who := String(l[0])
		var text := String(l[1])
		var lbl: Label
		if who == "You":
			lbl = m._lbl(list, text, 14, Color(0.7, 1.0, 0.7))
		elif who == "" or who == "Narrator":
			lbl = m._lbl(list, text, 13, Color(0.72, 0.76, 0.92))
		else:
			lbl = m._lbl(list, "%s —  %s" % [who, text], 14, Color(0.92, 0.88, 0.72))
		lbl.custom_minimum_size = Vector2(830, 0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	vbox.add_child(row)
	m._btn(row, "  ← Back to the archive  ", func() -> void: m.open_journal("story"),
		Color(0.8, 0.9, 1.0))
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


## Active bounties with progress. Daily first, then weekly.
## Accepted side quests (Story.SIDE_QUESTS): step checklist while live,
## one green line once paid. Section hides until something is accepted —
## side quests are found, not assigned.
static func _side_quests(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	var entries: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		if String(q.get("chapter", "")) != g.chapter_id:
			continue
		if not g.get_flag("sq_on_" + String(id), false):
			continue
		entries.append([String(id), q])
	if not entries.is_empty():
		m._lbl(list, "— SIDE QUESTS —", 16, Color(0.7, 0.95, 0.7))
	for e in entries:
		var id: String = e[0]
		var q: Dictionary = e[1]
		var paid: bool = g.get_flag("sq_paid_" + id, false)
		m._lbl(list, ("✔  %s — complete" if paid else "⚑  %s") % String(q["name"]), 15,
			Color(0.55, 0.8, 0.55) if paid else Color(0.95, 0.95, 0.8))
		if paid:
			continue
		var dl := m._lbl(list, "   " + String(q.get("desc", "")), 12, Color(0.75, 0.75, 0.8))
		dl.custom_minimum_size = Vector2(780, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for step in q.get("steps", []):
			var done: bool = g.get_flag(String(step["flag"]), false)
			m._lbl(list, "   %s  %s" % ["✔" if done else "◇", String(step["text"])], 13,
				Color(0.55, 0.8, 0.55) if done else Color(0.9, 0.85, 0.7))
		# The DEADLINE, on every open promise. A quest that expires without a
		# visible clock is a feel-bad every time — this line is what earns
		# game_base._expire_side_quests the right to charge for it.
		m._lbl(list, "   ⧗  Expires when this chapter ends — finish it BEFORE the final boss, or the promise is broken.",
			12, Color(0.95, 0.7, 0.45))
	_available_quests(m, list)


## AVAILABLE: offered in this world, not yet taken. The journal used to list
## ONLY accepted quests, so a player who walked past a giver had no way to
## learn a quest existed at all — the log was a tracker with no discovery in
## it. Gated on side_quest_available (the giver must actually be present in
## THIS run), so it can never advertise a wanderer the seed never rolled.
static func _available_quests(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	var open: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		if g.side_quest_available(String(id)):
			open.append(Story.ALL_SIDE_QUESTS[id])
	if open.is_empty():
		return
	m._lbl(list, "— AVAILABLE —", 16, Color(0.95, 0.85, 0.5))
	m._lbl(list, "Someone in this chapter is still waiting to ask. Look for the ❢ over their head.",
		12, Color(0.7, 0.72, 0.78))
	for q in open:
		m._lbl(list, "❢  %s" % String(q["name"]), 15, Color(0.95, 0.9, 0.6))
		var dl := m._lbl(list, "   " + String(q.get("desc", "")), 12, Color(0.75, 0.75, 0.8))
		dl.custom_minimum_size = Vector2(780, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _bounties(m: Menus, list: VBoxContainer) -> void:
	m._lbl(list, "— BOUNTIES —", 16, Color(0.6, 1.0, 0.7))
	if m.game.bounties.is_empty():
		m._lbl(list, "No bounties active.", 13, Color(0.6, 0.62, 0.68))
		return
	for scope in ["daily", "weekly"]:
		for b in m.game.bounties:
			if String(b["scope"]) != scope:
				continue
			var done: bool = b["done"]
			var tag := "DAILY" if scope == "daily" else "WEEKLY"
			var reward := "%d gold" % int(b["gold"]) + ("  + gem" if int(b["gems"]) > 0 else "")
			var line := "%s  [%s]  %s  —  %d/%d   (%s)" % [
				"✓" if done else "○", tag, String(b["desc"]),
				int(b["progress"]), int(b["target"]), reward]
			m._lbl(list, line, 14, Color(0.6, 1.0, 0.6) if done else Color(0.85, 0.88, 0.94))


## The weekly vault: progress toward the guaranteed reward + claim button.
static func _vault(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	m._lbl(list, "— WEEKLY VAULT —", 16, Color(1.0, 0.85, 0.4))
	var prog: int = g.vault_progress if g._week_index() == g.vault_week else 0
	var goal: int = Balance.VAULT_BOSS_GOAL
	m._lbl(list, "Bosses this week:  %d / %d  →  a guaranteed golden chest" % [mini(prog, goal), goal],
		14, Color(0.9, 0.85, 0.7))
	if g.vault_ready():
		var row := HBoxContainer.new()
		list.add_child(row)
		m._btn(row, "   Claim vault reward   ", func() -> void:
			g.claim_vault()
			m.open_journal(), Color(1.0, 0.88, 0.45))
	elif g.vault_claimed_week == g._week_index():
		m._lbl(list, "Claimed this week. Resets next week.", 13, Color(0.6, 0.62, 0.68))


## The weekly challenge (retention roadmap #2): one fixed seed + one
## modifier per week, the same for every player. Starts a replay of the
## week's chapter; the clear pays once per week and keeps a weekly best.
static func _weekly(m: Menus, list: VBoxContainer) -> void:
	var g := m.game
	m._lbl(list, "— WEEKLY CHALLENGE —", 16, Color(0.85, 0.6, 1.0))
	var mod: Dictionary = g.weekly_mod()
	var chname := String(Story.chapter(g.weekly_chapter())["name"])
	var head := m._lbl(list, "%s  —  %s   (%s, fixed map for everyone this week)" %
		[String(mod["name"]), String(mod["desc"]), chname], 14, Color(0.9, 0.85, 1.0))
	head.custom_minimum_size = Vector2(800, 0)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var best: Dictionary = g.weekly_best()
	if not best.is_empty():
		var secs := int(float(best.get("time", 0.0)))
		m._lbl(list, "Your best this week:  %d:%02d  (%s, grade %s)" %
			[secs / 60, secs % 60, String(Classes.CLASSES.get(String(best.get("cls", "warrior")), {}).get("name", "?")),
			String(best.get("grade", "?"))], 14, Color(0.7, 1.0, 0.7))
	if g.weekly_claimed_week == g._week_index():
		m._lbl(list, "Reward claimed this week — the seed still races for a better time.",
			13, Color(0.6, 0.62, 0.68))
	if g.weekly_active and g.weekly_week == g._week_index():
		m._lbl(list, "◆ The challenge is LIVE — this run rides the week's modifier.",
			14, Color(1.0, 0.88, 0.45))
	else:
		var row := HBoxContainer.new()
		list.add_child(row)
		m._btn(row, "   Begin the weekly run   ", func() -> void:
			m.open_confirm(
				"Begin this week's challenge? It restarts %s from its beginning on the week's fixed map, with '%s' live (%s). Your character, gear and Resonance carry in — chapter story progress resets, like any replay." %
					[chname, String(mod["name"]), String(mod["desc"])],
				func() -> void: g.start_weekly()), Color(0.85, 0.7, 1.0))
