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


static func open(m: Menus, requested_tab := "", requested_ward := "") -> void:
	var g := m.game
	g.refresh_bounties()
	g.refresh_contracts()
	var tab := String(requested_tab)
	if tab == "log":
		tab = "quests" # Backward compatibility for old callers.
	if tab == "":
		tab = String(m.get_meta("journal_tab", "quests"))
	if not tab in ["quests", "activities", "progress", "story"]:
		tab = "quests"
	var ward := String(requested_ward)
	if tab != "activities" or ward not in Balance.WARD_CONTRACT_WARDS:
		ward = ""
	m.set_meta("journal_tab", tab)
	m.set_meta("journal_ward", ward)

	var vbox := m._open("Journal — %s" % String(Story.chapter(g.chapter_id)["name"]), 920, 650, true)
	m.current = "journal"
	_tabs(m, vbox, tab)
	_context_strip(m, vbox, tab)
	if tab == "activities":
		_ward_selectors(m, vbox, ward)

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
			if ward != "":
				_contracts(m, list, ward)
			else:
				_activities(m, list)
		"progress":
			_progress_page(m, list)
		"story":
			_archive(m, list)
		_:
			_quests(m, list)
	m._hint(vbox, "1–4 switch sections  ·  ESC, ✕, or click outside to close")
	preload("res://scripts/ui/activity_rewards.gd").watch(m, tab, ward)


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
	var ready := m.game.activity_claims_ready()
	var activity_suffix := "%d ready" % ready if ready > 0 else "%d/%d" % [bounty_done, m.game.bounties.size()]
	var specs := [
		["quests", "%sQUESTS  ·  %s" % [key_prefix[0], quest_suffix], GOLD, KEY_1],
		["activities", "%sACTIVITIES  ·  %s" % [key_prefix[1], activity_suffix], GOLD if ready > 0 else GREEN, KEY_2],
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
			var ready := g.activity_claims_ready()
			text = "%d reward claim%s ready · Choose your ward rewards below" % [ready, "" if ready == 1 else "s"] if ready > 0 else "Bounties pay automatically · Ward rewards are claimed below"
			color = GOLD if ready > 0 else GREEN
			var ward := String(m.get_meta("journal_ward", ""))
			if ward != "":
				text = "%s ward board · Browse the wards to choose your rewards" % ward.capitalize()
			var notice := String(m.get_meta("journal_notice", ""))
			if notice != "":
				text = notice
				m.remove_meta("journal_notice")
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
	# Three scoped shelves (Q9): the chapter's own promises (with their
	# deadline), then persistent CAPITAL work and WIDER-WORLD threads that
	# survive chapter wipes and show wherever you are.
	_scoped_quest_section(m, list, "chapter", "SIDE QUESTS",
		"%d accepted promise%s", GREEN)
	_scoped_quest_section(m, list, "capital", "CAPITAL WORK",
		"%d job%s in Crownfall", Color(0.82, 0.86, 0.62))
	_scoped_quest_section(m, list, "world", "THE WIDER WORLD",
		"%d thread%s", Color(0.7, 0.85, 0.95))


## Render every accepted quest of one scope. Chapter quests filter on the
## current chapter and carry the deadline line; capital/world quests are
## visible everywhere and never expire.
static func _scoped_quest_section(m: Menus, list: VBoxContainer, scope: String,
		title: String, count_fmt: String, color: Color) -> void:
	var g := m.game
	var entries: Array = []
	for id in Story.ALL_SIDE_QUESTS:
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		if String(q.get("scope", "chapter")) != scope:
			continue
		if scope == "chapter" and String(q.get("chapter", "")) != g.chapter_id:
			continue
		if g.get_flag("sq_on_" + String(id), false):
			entries.append([String(id), q])
	if entries.is_empty():
		return
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		var ar := 2 if g.get_flag("sq_paid_" + String(a[0]), false) else (0 if g.player.tracked_quest == String(a[0]) else 1)
		var br := 2 if g.get_flag("sq_paid_" + String(b[0]), false) else (0 if g.player.tracked_quest == String(b[0]) else 1)
		return ar < br if ar != br else String(a[1].name) < String(b[1].name))
	_section(m, list, title, count_fmt % [
		entries.size(), "" if entries.size() == 1 else "s"], color)
	for entry in entries:
		_quest_card(m, list, entry[0], entry[1], scope == "chapter")


static func _quest_card(m: Menus, list: VBoxContainer, id: String, q: Dictionary,
		show_deadline: bool) -> void:
	var g := m.game
	var paid: bool = g.get_flag("sq_paid_" + id, false)
	var card := _card(list, GREEN if paid else Color(0.75, 0.9, 0.6))
	_status_line(m, card, "✓  COMPLETE" if paid else "⚑  ACTIVE",
		"SIDE QUEST", GREEN if paid else Color(0.9, 0.88, 0.55))
	var name := m._lbl(card, String(q["name"]), 16, Color(0.84, 1.0, 0.82) if paid else Color.WHITE)
	_wrap(name)
	if paid:
		m._lbl(card, "Promise kept and reward collected.", 12, MUTED)
		return
	var desc := m._lbl(card, String(q.get("desc", "")), 13, BODY)
	_wrap(desc)
	var tracked: bool = g.player.tracked_quest == id
	var track_button := m._btn(card, "◆  Following this quest — stop tracking" if tracked else "◇  Track this quest", func() -> void:
		g.hud.wayfinder.track("" if tracked else id)
		m.open_journal("quests"), GOLD)
	track_button.name = "TrackQuest_" + id
	track_button.custom_minimum_size.y = 44
	var steps: Array = q.get("steps", [])
	var done_steps := 0
	for step in steps:
		if g.get_flag(String(step["flag"]), false):
			done_steps += 1
	_meter(m, card, done_steps, steps.size(), GREEN,
		"OBJECTIVES", "%d / %d" % [done_steps, steps.size()])
	for step in steps:
		var sflag := String(step["flag"])
		var done: bool = g.get_flag(sflag, false)
		var label := String(step["text"])
		# KILL steps show live progress (game_base.quest_kills) until done.
		if not done and String(step.get("kind", "flag")) == "kill":
			label += "  (%d / %d)" % [int(g.quest_kills.get(sflag, 0)),
				maxi(1, int(step.get("count", 1)))]
		var objective := m._lbl(card, "%s  %s" % ["✓" if done else "◇", label],
			13, GREEN if done else Color(0.9, 0.85, 0.7))
		_wrap(objective)
	var reward: Dictionary = q.get("reward", {})
	var rewards: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		rewards.append("%d gold" % int(ceil(float(reward.gold) * Balance.daily_gold_mult(g.player.level))))
	if reward.has("item"):
		rewards.append("equipment")
	if reward.has("gem"):
		rewards.append("a gem")
	if reward.has("keepsake"):
		rewards.append(String(reward.keepsake.get("name", "a keepsake")))
	if reward.has("kept"):
		rewards.append("a lasting promise")
	if not rewards.is_empty():
		var preview := m._lbl(card, "Reward · " + " + ".join(rewards), 12, GOLD)
		_wrap(preview)
	if show_deadline:
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

static func _ward_selectors(m: Menus, parent: VBoxContainer, selected: String) -> void:
	var row := HBoxContainer.new()
	row.name = "JournalWards"
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var wards: Array = [""]
	wards.append_array(Balance.WARD_CONTRACT_WARDS)
	for value in wards:
		var ward := String(value)
		var active := ward == selected
		var label := "All activities" if ward == "" else ward.capitalize()
		var button := m._btn(row, label, func() -> void:
			m.open_journal("activities", ward)
			var next := m.root.find_child("JournalWard_" + ("all" if ward == "" else ward), true, false) as Button
			if next != null:
				next.grab_focus(), GOLD if active else BODY)
		button.name = "JournalWard_" + ("all" if ward == "" else ward)
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = true
		button.button_pressed = active
		button.tooltip_text = "Show all activities" if ward == "" else "View %s contracts · browsing spends no daily choice" % ward.capitalize()


static func _activities(m: Menus, list: VBoxContainer) -> void:
	var ready_contracts := m.game.contracts_claimable() > 0
	if ready_contracts:
		_contracts(m, list)
	if m.game.vault_ready():
		_vault(m, list)
	var wildlife := preload("res://scripts/wildlife.gd")
	_section(m, list, "SMALL MERCIES", "%d / %d creatures rescued" % [wildlife.count(m.game), wildlife.SITES.size()], GREEN)
	var sanctuary_button := m._btn(list, "Visit the sanctuary collection", func() -> void: preload("res://scripts/ui/sanctuary.gd").open(m), GREEN)
	sanctuary_button.custom_minimum_size.y = 44
	if not ready_contracts:
		_contracts(m, list)
	_bounties(m, list)
	if not m.game.vault_ready():
		_vault(m, list)
	_weekly(m, list)
	_waking(m, list)


## Ward contracts (Q11): the capital's daily deed board. Deeds auto-progress off
## the same events as bounties; the reward is CLAIMED here, capped per day.
static func _contracts(m: Menus, list: VBoxContainer, selected_ward := "") -> void:
	var g := m.game
	if g.contracts.is_empty() and selected_ward == "":
		return
	var heading := m._lbl(list, "WARD CONTRACTS" if selected_ward == "" else "%s CONTRACTS" % String(selected_ward).to_upper(), 18, GOLD)
	heading.name = "JournalWardHeading"
	var left := maxi(0, Balance.WARD_CONTRACT_DAILY_CAP - g.contract_claims_day)
	var allowance := m._lbl(list, "%d of %d daily choices remaining across all wards · This hero" % [left, Balance.WARD_CONTRACT_DAILY_CAP], 13, GREEN if left > 0 else MUTED)
	allowance.name = "JournalWardAllowance"
	var help := m._lbl(list, "No acceptance needed · Deeds progress as you play · Unclaimed rewards expire daily", 12, MUTED)
	help.name = "JournalWardHelp"
	if selected_ward != "" and g.has_local_player():
		var standing := "%s standing: %d" % [String(selected_ward).capitalize(), int(g.player.faction_standing.get(selected_ward, 0))]
		var npc := String(Balance.WARD_CONTRACT_FAVOR_NPC.get(selected_ward, ""))
		if npc != "":
			standing += "  ·  %s favor: %d (%s)" % [npc.capitalize(), g.favor_points(npc), g.favor_tier_name(npc)]
		var status := m._lbl(list, standing, 13, BODY)
		status.name = "JournalWardStanding"
	var shown := 0
	# Ready choices lead; ward order stays familiar within each group.
	for state in ["ready", "unfinished", "claimed"]:
		for ward in Balance.WARD_CONTRACT_WARDS:
			if selected_ward != "" and String(ward) != selected_ward:
				continue
			for c in g.contracts:
				var bucket := "claimed" if bool(c.get("claimed", false)) else "ready" if bool(c.get("done", false)) else "unfinished"
				if String(c.ward) == String(ward) and bucket == state:
					_contract_card(m, list, c, selected_ward)
					shown += 1
	if shown == 0:
		m._lbl(list, "No contracts on this ward's current board. Browse another ward or return to All activities.", 14, MUTED)


static func _contract_card(m: Menus, list: VBoxContainer, c: Dictionary, selected_ward := "") -> void:
	var g := m.game
	var ward := String(c.ward)
	var wname := String(Balance.WARD_CONTRACT_WARD_NAME.get(ward, ward))
	var claimed := bool(c.get("claimed", false))
	var done := bool(c.get("done", false))
	var can_claim := g.contract_claims_day < Balance.WARD_CONTRACT_DAILY_CAP
	var color := GREEN if claimed else GOLD if done and can_claim else BODY
	var card := _card(list, color)
	card.name = "ContractCard_" + ward + "_" + String(c.type)
	_status_line(m, card, "✓  CLAIMED" if claimed else ("◆  READY TO CLAIM" if can_claim else "DAILY ALLOWANCE USED") if done else "○  IN PROGRESS", wname.to_upper(), color)
	var title := m._lbl(card, String(c.desc), 15, Color.WHITE)
	_wrap(title)
	_meter(m, card, int(c.progress), int(c.target), GREEN if done else Color(0.7, 0.78, 0.6),
		"PROGRESS", "%d / %d" % [int(c.progress), int(c.target)])
	m._lbl(card, "Reward  ·  %d gold  + %d %s standing%s" % [g.activity_gold(int(c.gold)),
		Balance.WARD_CONTRACT_STANDING, wname, "  + %d Kesh favor" % g.favor_gain(Balance.WARD_CONTRACT_FAVOR) if Balance.WARD_CONTRACT_FAVOR_NPC.has(ward) else ""], 12, Color(0.9, 0.82, 0.58))
	if done and not claimed:
		var claim := m._btn(card, "  ◆  CLAIM  " if can_claim else "  Today's choices are used · new board tomorrow  ", func() -> void:
			var reason := g.claim_contract(c)
			m.set_meta("journal_notice", reason)
			preload("res://scripts/ui/activity_rewards.gd").reopen(m, "activities", selected_ward), GREEN if can_claim else MUTED, can_claim)
		claim.name = "ContractClaim_" + ward + "_" + String(c.type)
		claim.custom_minimum_size.y = 44


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
			var reward := "%d gold" % m.game.activity_gold(int(b["gold"]))
			if int(b["gems"]) > 0:
				reward += "  + %d gem%s" % [int(b["gems"]), "" if int(b["gems"]) == 1 else "s"]
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
	m._lbl(card, "Golden chest  + bright gem  +  ◈%d Renown" % Balance.RENOWN_VAULT, 13, Color(0.95, 0.86, 0.58))
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

	_section(m, list, "CHARTED GUARDIANS", "Encounters recorded in rooms you have entered", Color(1.0, 0.62, 0.62))
	var bosses := _card(list, Color(1.0, 0.62, 0.62))
	var boss_total := 0
	var boss_done := 0
	for i in g.zone_count:
		var kind := String(g.zones[i].get("boss", ""))
		if kind == "" or not g.charted(i):
			continue
		boss_total += 1
		var done := g._boss_room_resolved(i)
		if done:
			boss_done += 1
		_guardian_row(m, bosses, i, done)
	var total := m._lbl(bosses, "%d of %d charted guardians defeated" % [boss_done, boss_total], 13, BODY)
	total.name = "JournalGuardiansSummary"
	if boss_total > 0:
		_meter(m, bosses, boss_done, boss_total, Color(1.0, 0.62, 0.62),
			"CHARTED GUARDIANS DEFEATED", "%d / %d" % [boss_done, boss_total])
	else:
		m._lbl(bosses, "No guardian rooms charted yet. Explore to record the encounters you find.", 13, MUTED)

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


static func _guardian_row(m: Menus, parent: VBoxContainer, room: int, done: bool) -> void:
	var g := m.game
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := m._lbl(copy, "%s  %s" % ["✓" if done else "○", g._boss_room_name(room)], 14, GREEN if done else BODY)
	title.name = "JournalGuardian_%d" % room
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var zone: Dictionary = g.zones[room]
	var family := "Main road"
	if String(zone.get("pocket", "")) != "":
		family = "Pocket encounter"
	elif String(zone.get("unlisted", "")) != "":
		family = "The Unlisted"
	elif String(zone.get("waking", "")) != "":
		family = "Waking breach"
	m._lbl(copy, "%s · %s · Room %d" % ["Defeated" if done else "Awaiting victory", family, room + 1], 12, MUTED)
	var context: String = g.hud.wayfinder.context_key()
	var shell := m.root
	var button := m._btn(row, "Show on map", func() -> void:
		if not is_instance_valid(shell) or m.root != shell or context != g.hud.wayfinder.context_key():
			return
		if room < 0 or room >= g.zones.size() or not g.charted(room):
			return
		m.open_map()
		var atlas := m.root.find_child("FieldAtlas", true, false)
		if atlas != null:
			atlas.select_room(room), BLUE)
	button.name = "JournalGuardianMap_%d" % room
	button.custom_minimum_size = Vector2(156, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "Inspect this charted room without moving or setting a route"


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
