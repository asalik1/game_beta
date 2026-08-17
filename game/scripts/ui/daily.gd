class_name UIDaily
## The daily-login reward screen. Static builders taking the Menus
## instance, like ui/mailbox.gd and ui/dev_panel.gd. One claim per
## calendar day on the trusted clock; consecutive days build a streak.
## Reached from the HUD ★ (shown only when a reward waits) and the pause
## menu. The reward table + claim logic live in Balance / game_base.
##
## Dressed 2026-08-15 (owner: "kind of dull") and widened to the full
## FOUR-WEEK track 2026-08-16: 28 tiles, a row per week, each week's rewards
## a notch above the last (Balance.daily_reward_at). Every tile carries the
## reward's own art (coin, potion, gem, the gold chest on the week's jackpot
## day, ◈ Renown); the day you stand on is lit, the days behind you carry a
## ✓, and Claim is the one big gold button. Claim logic untouched.

const TILE_W := 96.0
const TILE_H := 88.0
const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.6, 0.62, 0.68)


## `just_claimed` holds the reward lines when we've just claimed in-place
## (single-screen flow: Claim refreshes THIS panel rather than pushing a
## second one).
static func open(m: Menus, just_claimed: Array = []) -> void:
	var g := m.game
	var vbox := m._open("Daily Reward", 800, 660, true)
	m.current = "daily"
	vbox.add_theme_constant_override("separation", 8)

	var avail: bool = g.daily_available()
	var next: int = g.daily_next_streak()
	# The day this session STANDS ON in the 28-day cycle: the next reward if
	# unclaimed, else today's (already granted). Days before it in the cycle
	# were claimed on the way here — a streak IS consecutive claims.
	var cycle_len: int = Balance.DAILY_CYCLE_DAYS
	var stand: int = ((next - 1) if avail else (g.daily_streak - 1)) % cycle_len
	var streak_now: int = next if avail else g.daily_streak

	# --- header: the claim receipt, or where the streak stands ---
	if not just_claimed.is_empty():
		# One-line receipt: what today paid, then the track shows the ✓.
		var rc := HBoxContainer.new()
		rc.add_theme_constant_override("separation", 18)
		UITheme.card(vbox, GOLD, 8.0).add_child(rc)
		var got := m._lbl(rc, "Day %d claimed" % g.daily_streak, 15, GOLD)
		UITheme.header(got)
		got.autowrap_mode = TextServer.AUTOWRAP_OFF
		got.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for line in just_claimed:
			var ll := m._lbl(rc, "✓  " + String(line), 14, Color(0.7, 1.0, 0.7))
			ll.autowrap_mode = TextServer.AUTOWRAP_OFF
			ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var foot := m._lbl(rc, "Gems land in your bag (or the mailbox if it's full). See you tomorrow.", 11, DIM)
		foot.autowrap_mode = TextServer.AUTOWRAP_OFF
		foot.clip_text = true
		foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		vbox.add_child(head)
		var streak_lbl := m._lbl(head, "Day %d" % streak_now, 24, GOLD)
		streak_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		UITheme.title(streak_lbl, 24)
		var what := m._lbl(head,
			("A new day — claim to land on a Day %d streak." % next) if avail
			else "Already claimed today. Come back tomorrow to keep the streak.",
			14, Color(0.92, 0.94, 1.0) if avail else Color(0.72, 0.74, 0.8))
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		what.custom_minimum_size = Vector2(560, 0)

	# --- the four-week track: a row per week, seven tiles each ---
	var weeks: int = cycle_len / Balance.DAILY_REWARDS.size()
	for w in weeks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)
		var wl := m._lbl(row, "WEEK %d" % (w + 1), 10, Color(GOLD, 0.7) if w == stand / Balance.DAILY_REWARDS.size() else Color(0.45, 0.48, 0.56))
		wl.autowrap_mode = TextServer.AUTOWRAP_OFF
		wl.custom_minimum_size = Vector2(46, 0)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for d in Balance.DAILY_REWARDS.size():
			var i: int = w * Balance.DAILY_REWARDS.size() + d
			var state := "future"
			if i < stand:
				state = "claimed"
			elif i == stand:
				state = "claimed_today" if not avail else "today"
			_tile(m, row, i, state)

	var note := m._lbl(vbox, "Miss a day and the streak resets to Day 1. Every week pays a notch more than the last; day 28 wraps back to week 1. Gold shown is scaled to your level (%d)." % g.player.level,
		11, Color(0.55, 0.57, 0.63))
	note.custom_minimum_size = Vector2(740, 0)

	# --- actions: TODAY's tile is the claim (select it); Close is the only button ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	if avail:
		var cue := m._lbl(row, "★  Select today's tile to claim it.", 14, GOLD)
		cue.autowrap_mode = TextServer.AUTOWRAP_OFF
		cue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m._btn(row, "   Close   ", func() -> void: m.close())
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


## One day-tile of the track: DAY N over the reward's art, the amounts under
## it. `state`: "claimed" (behind you, ✓), "today" (lit, the one you claim),
## "claimed_today" (lit + ✓), "future" (quiet). `i` is the 0-based cycle day.
static func _tile(m: Menus, row: HBoxContainer, i: int, state: String) -> void:
	var r: Dictionary = m.game.daily_reward_for(i + 1)
	var jackpot: bool = (i % Balance.DAILY_REWARDS.size()) == Balance.DAILY_REWARDS.size() - 1
	var lit: bool = state == "today" or state == "claimed_today"
	var done: bool = state == "claimed" or state == "claimed_today"
	var accent: Color = GOLD if (lit or jackpot) else Color(0.42, 0.45, 0.55)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(TILE_W, TILE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.06, 0.96) if lit else (Color(0.09, 0.085, 0.07, 0.9) if jackpot else UITheme.SURFACE)
	sb.border_color = Color(accent, 0.95 if lit else 0.5)
	sb.set_border_width_all(2 if lit else 1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(4)
	if lit:
		sb.shadow_color = Color(1.0, 0.8, 0.3, 0.35)
		sb.shadow_size = 8
	box.add_theme_stylebox_override("panel", sb)
	if done and not lit:
		box.modulate = Color(0.72, 0.72, 0.72)
	row.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	box.add_child(col)

	# DAY N (✓ once claimed), with TODAY / JACKPOT as the tag.
	var day := Label.new()
	var tag := ("CLAIM" if state == "today" else ("TODAY" if lit else ("JACKPOT" if jackpot else "")))
	day.text = ("✓ " if done else "") + ("DAY %d" % (i + 1)) + ("  ·  " + tag if tag != "" else "")
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day.clip_text = true
	day.add_theme_font_size_override("font_size", 10)
	day.add_theme_color_override("font_color", GOLD if (lit or done or jackpot) else DIM)
	col.add_child(day)

	# The art: the reward's own picture in a 32px well, a glow behind today's.
	var well := Control.new()
	well.custom_minimum_size = Vector2(TILE_W - 8, 34)
	col.add_child(well)
	if lit:
		var glow := TextureRect.new()
		glow.texture = Art.tex("glow")
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.offset_left = -10
		glow.offset_right = 10
		glow.offset_top = -8
		glow.offset_bottom = 8
		glow.modulate = Color(1.0, 0.85, 0.4, 0.5)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(glow)
	var art := TextureRect.new()
	art.texture = _reward_art(r, jackpot)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 28
	art.offset_right = -28
	art.offset_top = 1
	art.offset_bottom = -1
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(art)
	if done and not lit:
		art.modulate = Color(0.75, 0.75, 0.75)

	# The amounts, one short line each; Renown in its violet.
	for part in _reward_parts(m, r):
		var pl := Label.new()
		pl.text = String(part[0])
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.clip_text = true
		pl.add_theme_font_size_override("font_size", 10)
		var pc: Color = part[1]
		pl.add_theme_color_override("font_color", pc if (lit or jackpot) else Color(pc, 0.78))
		col.add_child(pl)

	# TODAY, unclaimed: the tile itself is the claim — a transparent button
	# over it (brightens under the pointer, works for a finger tap too).
	if state == "today":
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.tooltip_text = "Claim today's reward"
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		var clear := StyleBoxFlat.new()
		clear.bg_color = Color(0, 0, 0, 0)
		clear.set_corner_radius_all(8)
		hit.add_theme_stylebox_override("normal", clear)
		var hov: StyleBoxFlat = clear.duplicate()
		hov.bg_color = Color(1.0, 0.9, 0.5, 0.12)
		hit.add_theme_stylebox_override("hover", hov)
		hit.add_theme_stylebox_override("pressed", hov)
		hit.add_theme_stylebox_override("focus", clear)
		hit.pressed.connect(func() -> void:
			m.game.sfx("ui_click")
			var lines: Array = m.game.claim_daily()
			open(m, lines))
		box.add_child(hit)


## The picture for a day's reward: the gold chest on the week's jackpot day,
## else the headline item — gem (its level's authored jewel), potion, or coins.
static func _reward_art(r: Dictionary, jackpot: bool) -> Texture2D:
	if jackpot:
		return Art.tex("chest_gold")
	if r.has("gems"):
		return Art.gem_icon(Color(1, 1, 1), int(r.get("gem_lvl", 1)))
	if r.has("potions"):
		var pot: Texture2D = Art.consumable_icon(Items.make_potion("health", "instant", "E", "accord"))
		if pot != null:
			return pot
	return _coin_pile_icon()


## Amount lines with their colours. Gold is shown level-scaled to match what
## claiming actually pays.
static func _reward_parts(m: Menus, r: Dictionary) -> Array:
	var parts: Array = []
	if r.has("gold"):
		parts.append(["%s gold" % _thousands(int(float(r["gold"]) * Balance.daily_gold_mult(m.game.player.level))), Color(1.0, 0.9, 0.55)])
	if r.has("gems"):
		parts.append(["%d gem Lv %d" % [int(r["gems"]), int(r.get("gem_lvl", 1))], Color(0.85, 0.9, 1.0)])
	if r.has("potions"):
		parts.append(["%d potion%s" % [int(r["potions"]), "" if int(r["potions"]) == 1 else "s"], Color(1.0, 0.7, 0.7)])
	if r.has("renown"):
		parts.append(["◈ %d Renown" % int(r["renown"]), Balance.RENOWN_COLOR])
	return parts


## Gold is shown level-scaled to match what claiming actually pays (kept for
## callers of the old summary format).
static func _reward_label(m: Menus, r: Dictionary) -> String:
	var out: Array = []
	for p in _reward_parts(m, r):
		out.append(String(p[0]))
	return "\n".join(out)


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


## A small pile of three gold coins for the gold days: the 8px pickup coin
## reads as a brown blob at tile size, so this is drawn at 24px — rimmed
## discs with a highlight — and shown NEAREST. Cached for the session.
static var _coin_pile: ImageTexture = null
static func _coin_pile_icon() -> ImageTexture:
	if _coin_pile != null:
		return _coin_pile
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	var rim := Color(0.55, 0.36, 0.09)
	var face := Color(0.98, 0.82, 0.30)
	var shine := Color(1.0, 0.95, 0.72)
	# Back coins first so the front one overlaps them.
	for c in [[6, 15], [17, 15], [12, 8]]:
		var cx: int = c[0]
		var cy: int = c[1]
		for y in range(-6, 7):
			for x in range(-6, 7):
				var d := x * x + y * y
				if d > 36:
					continue
				var px := cx + x
				var py := cy + y
				if px < 0 or py < 0 or px >= 24 or py >= 24:
					continue
				var col := face
				if d > 25:
					col = rim
				elif (x + 2) * (x + 2) + (y + 2) * (y + 2) <= 4:
					col = shine
				img.set_pixel(px, py, col)
	_coin_pile = ImageTexture.create_from_image(img)
	return _coin_pile
