class_name UIDaily
## The daily-login reward screen. Static builders taking the Menus
## instance, like ui/mailbox.gd and ui/dev_panel.gd. One claim per
## calendar day on the trusted clock; consecutive days build a streak.
## Reached from the HUD ★ (shown only when a reward waits) and the pause
## menu. The reward table + claim logic live in Balance / game_base.
##
## Dressed 2026-08-15 (owner: "kind of dull"): the seven days are TILES with
## the reward's own art (coin, potion, gem, the gold chest on the jackpot
## day, ◈ Renown), the day you stand on is lit with a glow, the days behind
## you carry a ✓, and Claim is the one big gold button. Claim logic untouched.

const TILE_W := 96.0
const TILE_H := 168.0
const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.6, 0.62, 0.68)


## `just_claimed` holds the reward lines when we've just claimed in-place
## (single-screen flow: Claim refreshes THIS panel rather than pushing a
## second one).
static func open(m: Menus, just_claimed: Array = []) -> void:
	var g := m.game
	var vbox := m._open("Daily Reward", 780, 540, true)
	m.current = "daily"
	vbox.add_theme_constant_override("separation", 12)

	var avail: bool = g.daily_available()
	var next: int = g.daily_next_streak()
	# The day this session STANDS ON in the 7-day cycle: the next reward if
	# unclaimed, else today's (already granted). Days before it in the cycle
	# were claimed on the way here — a streak IS consecutive claims.
	var cycle_len: int = Balance.DAILY_REWARDS.size()
	var stand: int = ((next - 1) if avail else (g.daily_streak - 1)) % cycle_len
	var streak_now: int = next if avail else g.daily_streak

	# --- header: the claim receipt, or where the streak stands ---
	if not just_claimed.is_empty():
		var rc := VBoxContainer.new()
		rc.add_theme_constant_override("separation", 3)
		UITheme.card(vbox, GOLD, 12.0).add_child(rc)
		var got := m._lbl(rc, "Claimed — Day %d streak.  You received:" % g.daily_streak, 16, GOLD)
		UITheme.header(got)
		var line_row := HBoxContainer.new()
		line_row.add_theme_constant_override("separation", 22)
		rc.add_child(line_row)
		for line in just_claimed:
			var ll := m._lbl(line_row, "✓  " + String(line), 15, Color(0.7, 1.0, 0.7))
			ll.autowrap_mode = TextServer.AUTOWRAP_OFF
		var foot := m._lbl(rc, "Gems land in your bag (or the mailbox if it's full). See you tomorrow.",
			12, DIM)
		foot.custom_minimum_size = Vector2(700, 0)
	else:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		vbox.add_child(head)
		var streak_lbl := m._lbl(head, "Day %d" % streak_now, 26, GOLD)
		streak_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		UITheme.title(streak_lbl, 26)
		var what := m._lbl(head,
			("A new day — claim to land on a Day %d streak." % next) if avail
			else "Already claimed today. Come back tomorrow to keep the streak.",
			15, Color(0.92, 0.94, 1.0) if avail else Color(0.72, 0.74, 0.8))
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		what.custom_minimum_size = Vector2(560, 0)

	# --- the seven-day track ---
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 6)
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(track)
	for i in cycle_len:
		var state := "future"
		if i < stand:
			state = "claimed"
		elif i == stand:
			state = "claimed_today" if not avail else "today"
		_tile(m, track, i, state)

	var note := m._lbl(vbox, "Miss a day and the streak resets to Day 1. Gold shown is scaled to your level (%d); Day 7 is the jackpot, then the cycle begins again." % g.player.level,
		12, Color(0.55, 0.57, 0.63))
	note.custom_minimum_size = Vector2(700, 0)

	# --- actions ---
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	if avail:
		var claim_cb := func() -> void:
			var lines: Array = g.claim_daily()
			open(m, lines)
		var claim := m._btn(row, "", claim_cb, Color(0.12, 0.09, 0.02))
		claim.text = "   ★  Claim today's reward   "
		claim.custom_minimum_size = Vector2(300, 44)
		claim.alignment = HORIZONTAL_ALIGNMENT_CENTER
		claim.add_theme_font_size_override("font_size", 17)
		claim.add_theme_color_override("font_hover_color", Color(0.2, 0.15, 0.05))
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.95, 0.78, 0.32)
		csb.border_color = Color(1.0, 0.9, 0.6)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_top = 8.0
		csb.content_margin_bottom = 8.0
		claim.add_theme_stylebox_override("normal", csb)
		var csh: StyleBoxFlat = csb.duplicate()
		csh.bg_color = Color(1.0, 0.86, 0.42)
		claim.add_theme_stylebox_override("hover", csh)
		claim.add_theme_stylebox_override("pressed", csh)
	m._btn(row, "   Close   ", func() -> void: m.close())
	m._hint(vbox, "ESC, ✕, or click anywhere outside to close")


## One day-tile of the track: DAY N over the reward's art, the amounts under
## it. `state`: "claimed" (behind you, ✓), "today" (lit, the one you claim),
## "claimed_today" (lit + ✓), "future" (quiet).
static func _tile(m: Menus, track: HBoxContainer, i: int, state: String) -> void:
	var r: Dictionary = Balance.DAILY_REWARDS[i]
	var jackpot: bool = i == Balance.DAILY_REWARDS.size() - 1
	var lit: bool = state == "today" or state == "claimed_today"
	var done: bool = state == "claimed" or state == "claimed_today"
	var accent: Color = GOLD if (lit or jackpot) else Color(0.42, 0.45, 0.55)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(TILE_W, TILE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.06, 0.96) if lit else (Color(0.09, 0.085, 0.07, 0.9) if jackpot else UITheme.SURFACE)
	sb.border_color = Color(accent, 0.95 if lit else 0.5)
	sb.set_border_width_all(2 if lit else 1)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(6)
	if lit:
		sb.shadow_color = Color(1.0, 0.8, 0.3, 0.35)
		sb.shadow_size = 10
	box.add_theme_stylebox_override("panel", sb)
	if done and not lit:
		box.modulate = Color(0.72, 0.72, 0.72)
	track.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(col)

	# DAY N (and ✓ once claimed).
	var day := Label.new()
	day.text = ("✓ DAY %d" if done else "DAY %d") % (i + 1)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day.add_theme_font_size_override("font_size", 12)
	day.add_theme_color_override("font_color", GOLD if (lit or done) else DIM)
	col.add_child(day)
	if lit or jackpot:
		var tag := Label.new()
		tag.text = ("TODAY" if lit else "JACKPOT") if not (lit and jackpot) else "TODAY · JACKPOT"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75) if lit else Color(GOLD, 0.8))
		col.add_child(tag)

	# The art: the reward's own picture in a 56px well, a glow behind today's.
	var well := Control.new()
	well.custom_minimum_size = Vector2(TILE_W - 12, 60)
	col.add_child(well)
	if lit:
		var glow := TextureRect.new()
		glow.texture = Art.tex("glow")
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.offset_left = -12
		glow.offset_right = 12
		glow.offset_top = -10
		glow.offset_bottom = 10
		glow.modulate = Color(1.0, 0.85, 0.4, 0.5)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(glow)
	var art := TextureRect.new()
	art.texture = _reward_art(r, jackpot)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 14
	art.offset_right = -14
	art.offset_top = 2
	art.offset_bottom = -2
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(art)
	if done and not lit:
		art.modulate = Color(0.75, 0.75, 0.75)

	# The amounts, one line each; Renown in its violet.
	for part in _reward_parts(m, r):
		var pl := Label.new()
		pl.text = String(part[0])
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size = Vector2(TILE_W - 12, 0)
		pl.add_theme_font_size_override("font_size", 12)
		var pc: Color = part[1]
		pl.add_theme_color_override("font_color", pc if (lit or jackpot) else Color(pc, 0.78))
		col.add_child(pl)


## The picture for a day's reward: the gold chest on the jackpot day, else the
## headline item — gem (its level's authored jewel), potion, or the coin.
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


static var _coin_pile: ImageTexture = null

## A small pile of three gold coins: the 8px pickup coin reads as a brown
## blob at tile size, so this is drawn at 24px — rimmed discs with a
## highlight — and shown NEAREST. Built once.
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


## Amount lines with their colours. Gold is shown level-scaled to match what
## claiming actually pays.
static func _reward_parts(m: Menus, r: Dictionary) -> Array:
	var parts: Array = []
	if r.has("gold"):
		parts.append(["%s gold" % _thousands(int(float(r["gold"]) * Balance.daily_gold_mult(m.game.player.level))), Color(1.0, 0.9, 0.55)])
	if r.has("gems"):
		parts.append(["%d gem · Lv %d" % [int(r["gems"]), int(r.get("gem_lvl", 1))], Color(0.85, 0.9, 1.0)])
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
