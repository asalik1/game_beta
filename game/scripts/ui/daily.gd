class_name UIDaily
## The daily-login reward screen. Static builders taking the Menus
## instance, like ui/mailbox.gd and ui/dev_panel.gd. One claim per
## calendar day on the trusted clock; consecutive days build a streak.
## Reached from the HUD ★ (shown only when a reward waits) and the pause
## menu. The reward table + claim logic live in Balance / game_base.


static func open(m: Menus) -> void:
	var g := m.game
	var vbox := m._open("Daily Reward", 780, 520)
	m.current = "daily"

	var avail: bool = g.daily_available()
	var next: int = g.daily_next_streak()
	if avail:
		m._lbl(vbox, "A new day. Claim to land on a Day %d streak." % next, 15, Color(0.92, 0.94, 1.0))
	else:
		m._lbl(vbox, "Already claimed today — current streak: Day %d. Come back tomorrow." % g.daily_streak,
			15, Color(0.72, 0.74, 0.8))

	# The 7-day track. The highlighted cell is the one this session lands
	# on: the next reward if unclaimed, else today's (already granted).
	var highlight: int = ((next - 1) if avail else (g.daily_streak - 1)) % Balance.DAILY_REWARDS.size()
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 6)
	vbox.add_child(track)
	for i in Balance.DAILY_REWARDS.size():
		_cell(m, track, i, i == highlight)

	m._lbl(vbox, "Miss a day and the streak resets to 1. Gold rewards scale with your level.",
		12, Color(0.55, 0.57, 0.63))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	if avail:
		m._btn(row, "   Claim reward   ", func() -> void:
			var lines: Array = g.claim_daily()
			_show_claimed(m, lines), Color(0.6, 1.0, 0.6))
	m._btn(row, "   Close   ", func() -> void: m.close())
	m._hint(vbox, "ESC to close")


## A short after-claim confirmation, then back to the (now-claimed) track.
static func _show_claimed(m: Menus, lines: Array) -> void:
	var vbox := m._open("Daily Reward — Claimed!", 780, 520)
	m.current = "daily"
	m._lbl(vbox, "Day %d streak. You received:" % m.game.daily_streak, 16, Color(1.0, 0.88, 0.45))
	if lines.is_empty():
		m._lbl(vbox, "(nothing?)", 14, Color(0.7, 0.7, 0.75))
	for line in lines:
		m._lbl(vbox, "  •  " + String(line), 15, Color(0.7, 1.0, 0.7))
	m._lbl(vbox, "Gems land in your bag (or the mailbox if it's full). See you tomorrow!",
		13, Color(0.6, 0.62, 0.68))
	var row := HBoxContainer.new()
	vbox.add_child(row)
	m._btn(row, "   Nice   ", func() -> void: m.close(), Color(0.6, 1.0, 0.6))
	m._hint(vbox, "ESC to close")


## One day-cell in the track: "Day N" over a short reward summary, tinted
## gold and marked when it's the active day.
static func _cell(m: Menus, track: HBoxContainer, i: int, active: bool) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(100, 0)
	cell.add_theme_constant_override("separation", 2)
	track.add_child(cell)
	var day := Label.new()
	day.text = ("▶ Day %d" % (i + 1)) if active else ("Day %d" % (i + 1))
	day.add_theme_font_size_override("font_size", 15 if active else 14)
	day.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if active else Color(0.65, 0.67, 0.72))
	day.custom_minimum_size = Vector2(100, 0)  # HBox children collapse without this
	cell.add_child(day)
	var rew := Label.new()
	rew.text = _reward_label(Balance.DAILY_REWARDS[i])
	rew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rew.add_theme_font_size_override("font_size", 12)
	rew.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0) if active else Color(0.6, 0.62, 0.68))
	rew.custom_minimum_size = Vector2(100, 0)
	cell.add_child(rew)


static func _reward_label(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("gold"):
		parts.append("%d gold" % int(r["gold"]))
	if r.has("gems"):
		parts.append("%d gem Lv%d" % [int(r["gems"]), int(r.get("gem_lvl", 1))])
	if r.has("potions"):
		parts.append("%d potion" % int(r["potions"]))
	return "\n".join(parts)
