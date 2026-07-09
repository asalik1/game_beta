class_name UICodex
## The codex screens (monsters / gear / terrains), split out of
## menus.gd. Static builders: `m` owns the panel scaffolding
## (_open/_btn/_lbl/_hint) and the open/close state.

static func open(m: Menus, tab := "monsters", boss := "") -> void:
	# A boss kind routes to its focused mechanics detail view (not a tab).
	if boss != "" and Story.ALL_ENEMIES.has(boss):
		_boss_detail(m, boss)
		return

	var vbox := m._open("Codex", 1000, 620, true)
	m.current = "codex"

	# Bestiary (Monsters / Bosses / NPCs) shares one top-level tab; the other
	# codex screens stay top-level. `in_bestiary` keeps the parent lit.
	var in_bestiary: bool = tab in ["monsters", "bosses", "npcs"]

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	m._btn(tabs, "  Bestiary  ", func() -> void: m.open_codex("monsters"),
		Color(0.95, 0.85, 0.5) if in_bestiary else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Gear  ", func() -> void: m.open_codex("gear"),
		Color(0.95, 0.85, 0.5) if tab == "gear" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Terrains  ", func() -> void: m.open_codex("terrains"),
		Color(0.95, 0.85, 0.5) if tab == "terrains" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Status  ", func() -> void: m.open_codex("status"),
		Color(0.95, 0.85, 0.5) if tab == "status" else Color(0.6, 0.6, 0.6))
	m._btn(tabs, "  Records  ", func() -> void: m.open_codex("records"),
		Color(0.95, 0.85, 0.5) if tab == "records" else Color(0.6, 0.6, 0.6))

	# Bestiary subtabs — Monsters / Bosses / NPCs under the one parent tab.
	if in_bestiary:
		var subs := HBoxContainer.new()
		subs.add_theme_constant_override("separation", 10)
		vbox.add_child(subs)
		m._btn(subs, "  Monsters  ", func() -> void: m.open_codex("monsters"),
			Color(1.0, 0.9, 0.6) if tab == "monsters" else Color(0.55, 0.55, 0.58))
		m._btn(subs, "  Bosses  ", func() -> void: m.open_codex("bosses"),
			Color(1.0, 0.7, 0.7) if tab == "bosses" else Color(0.55, 0.55, 0.58))
		m._btn(subs, "  NPCs  ", func() -> void: m.open_codex("npcs"),
			Color(0.7, 0.9, 1.0) if tab == "npcs" else Color(0.55, 0.55, 0.58))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if tab == "monsters":
		_monsters(m, list)
	elif tab == "bosses":
		_bosses(m, list)
	elif tab == "npcs":
		_npcs(m, list)
	elif tab == "terrains":
		_terrains(m, list)
	elif tab == "status":
		_statuses(m, list)
	elif tab == "records":
		_records(m, list)
	else:
		_gear(m, list)
	m._hint(vbox, "Click ✕, click outside, or press C to close")


## Rounded, padded card panel — shared row container for codex galleries.
static func _card(parent: Container) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	return card


static func _monsters(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	# Elites — the roaming miniboss variant (round 6).
	m._lbl(list, "— ELITES —", 16, Color(1.0, 0.8, 0.3))
	var ecard := VBoxContainer.new()
	ecard.add_theme_constant_override("separation", 2)
	_card(list).add_child(ecard)
	for line in [
		"Any monster can be promoted to an ELITE: ~4× health, 1.5× damage, extra resistances, a bigger sprite and a gold ring underfoot — a miniboss, not a mob.",
		"Where: some quiet side rooms hold a lone elite instead of a wanderer (rolled per character), and combat rooms sometimes hide one in a pack. Later chapters may field several at once.",
		"Why fight them: elites pay NO experience — they are pure loot. Triple gold, a guaranteed gem, a guaranteed silver/golden chest, and they are the only source of Stones of Unlearning and bigger BAGS (see the Gear tab)."]:
		var el := m._lbl(ecard, String(line), 13, Color(0.78, 0.8, 0.86))
		el.custom_minimum_size = Vector2(880, 0)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Temptations — the elective risk events (retention roadmap #4).
	m._lbl(list, "— TEMPTATIONS —", 16, Color(0.85, 0.6, 1.0))
	var tcard := VBoxContainer.new()
	tcard.add_theme_constant_override("separation", 2)
	_card(list).add_child(tcard)
	for tline in [
		"CURSED CHEST — a wrong-colored chest that materializes just inside some blighted rooms as you arrive, and withdraws after %d seconds if you leave it be. Open it and the whole pack grows crueler (+%d%% damage, faster) until the purge — then it pays: a golden chest and a guaranteed gem. Decline freely; it never ambushes." % [int(Balance.CURSE_OFFER_WINDOW), int((Balance.CURSE_DMG_MULT - 1.0) * 100)],
		"GAMBLE SHRINE — a humming shrine in some quiet rooms. Feed it gold once and it blesses the offering (a gem, threefold gold, a chest, an elixir)... or drinks deeper (blood or more coin). The odds favor the bold — barely.",
		"Both are rolled per character, like elites — a replay meets different temptations.",
		"And keep your eyes open in dead ends: not everything glints until you're near it."]:
		var tl := m._lbl(tcard, String(tline), 13, Color(0.78, 0.8, 0.86))
		tl.custom_minimum_size = Vector2(880, 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Bosses moved to their own subtab (2026-07-08); this subtab keeps the
	# Elites/Temptations copy above plus the regular-mob bestiary.
	# Only mobs actually placed in a room show outside dev mode; extracted-
	# but-unplaced ones appear in the dev launcher only, tagged [placeholder].
	var used := _used_enemy_kinds()
	var dev: bool = m.game.dev_mode
	m._lbl(list, "— MONSTERS —", 16, Color(0.95, 0.85, 0.5))
	for kind in Story.ALL_ENEMIES:
		if kind in m.BOSS_KINDS:
			continue
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		# Boss-summon props (censers, roots, rods) are zero-reward
		# scenery-with-hp, not catalogue monsters — skip them.
		if st.get("xp", 0) <= 0 and st.get("gold", 0) <= 0:
			continue
		var unplaced: bool = not used.has(kind)
		if unplaced and not dev:
			continue
		_enemy_card(m, list, kind, false, false, unplaced)


## Bosses subtab: just the boss cards (each links to its mechanics detail).
## Same used-filter as monsters — an unplaced boss is dev-only, tagged.
static func _bosses(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var used := _used_enemy_kinds()
	var dev: bool = m.game.dev_mode
	m._lbl(list, "— BOSSES —", 16, Color(1, 0.5, 0.5))
	for kind in Story.ALL_ENEMIES:
		if not (kind in m.BOSS_KINDS):
			continue
		var unplaced: bool = not used.has(kind)
		if unplaced and not dev:
			continue
		_enemy_card(m, list, kind, true, false, unplaced)


## Enemy kinds actually placed in the world: any zone's `enemies` spawns or
## `boss`, plus each chapter's `final_boss`. Everything else in ALL_ENEMIES is
## extracted-but-unplaced — hidden from the codex outside dev mode.
static func _used_enemy_kinds() -> Dictionary:
	var used := {}
	for chid in Story.CHAPTER_LIST:
		var ch: Dictionary = Story.CHAPTER_LIST[chid]
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


## NPCs subtab (2026-07-08): everyone with a talk prompt, gathered from every
## chapter's zone npc lists (base ZONES + content modules). Names only for
## now — roles/lore land later. Deduped by sprite so each distinct NPC face
## (incl. the placeholder extraction set) shows once for review.
static func _npcs(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	m._lbl(list, "— NPCS —", 16, Color(0.6, 0.9, 1.0))
	var intro := m._lbl(list, "Everyone you can speak to. Names only for now — roles and lore come later.", 13, Color(0.7, 0.72, 0.78))
	intro.custom_minimum_size = Vector2(880, 0)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Placeholder NPCs (extracted art wired for review, `placeholder: true` in
	# their zone entry) are dev-launcher only, and tagged [placeholder] there.
	var dev: bool = m.game.dev_mode
	var seen := {}
	var entries: Array = []
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			for npc in zone.get("npcs", []):
				var ph: bool = npc.get("placeholder", false)
				if ph and not dev:
					continue
				var spr: String = String(npc.get("sprite", ""))
				if spr == "" or seen.has(spr):
					continue
				seen[spr] = true
				entries.append({"name": _npc_name(npc), "sprite": spr, "placeholder": ph})
	if entries.is_empty():
		m._lbl(list, "No NPCs catalogued.", 13, Color(0.6, 0.62, 0.68))
		return
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	_card(list).add_child(card)
	for e in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.tex(String(e["sprite"]))
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var nm_txt: String = String(e["name"]) + ("   [placeholder]" if e.get("placeholder", false) else "")
		var nm := m._lbl(row, nm_txt, 15, Color(0.72, 0.68, 0.55) if e.get("placeholder", false) else Color(0.9, 0.92, 0.98))
		nm.custom_minimum_size = Vector2(820, 0)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER


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


## One boxed card per monster/boss: icon, name, Lv, live stats, growth,
## projections, traits and lore. Shared by the bestiary list and the boss
## detail view. In the LIST, a boss with authored `mechanics` also grows a
## "▸ Mechanics & Tells" button that opens its focused detail; in the
## DETAIL view (`detail = true`) that button is suppressed (already there).
static func _enemy_card(m: Menus, list: VBoxContainer, kind: String, is_boss: bool, detail := false, placeholder := false) -> void:
	var st: Dictionary = Story.ALL_ENEMIES[kind]
	# Codex honesty: display what the fight actually deals/has
	# (TTK and damage multipliers included), not raw table rows.
	var live: Dictionary = Story.enemy_stats_at(kind, int(st.get("level", 1)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card(list).add_child(row)
	var icon := TextureRect.new()
	icon.texture = Art.tex(st["sprite"])
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	# Name .......................................... Lv badge
	var head := HBoxContainer.new()
	info.add_child(head)
	var nm_txt: String = String(st["name"]) + ("   [placeholder]" if placeholder else "")
	var name_col: Color = Color(0.72, 0.68, 0.55) if placeholder else (Color(1, 0.6, 0.6) if is_boss else Color(1, 1, 1))
	var name_l := m._lbl(head, nm_txt, 16, name_col)
	name_l.custom_minimum_size = Vector2(560, 0)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv_l := m._lbl(head, "Lv %d" % st.get("level", 1), 15, Color(0.95, 0.85, 0.5))
	lv_l.custom_minimum_size = Vector2(120, 0)
	lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Aligned stat columns.
	var cols := HBoxContainer.new()
	info.add_child(cols)
	for pair in [["HP", int(live["hp"])], ["DMG", int(live["dmg"])], ["SPD", int(st["speed"])],
			["XP", live["xp"]], ["Gold", live.get("gold", 0)]]:
		var c := m._lbl(cols, "%s %s" % [pair[0], str(pair[1])], 13, Color(0.78, 0.8, 0.86))
		c.custom_minimum_size = Vector2(105, 0)
	var type_l := m._lbl(cols, "Ranged caster" if st["ranged"] else "Melee", 13, Color(0.6, 0.7, 0.85))
	type_l.custom_minimum_size = Vector2(130, 0)

	# Scaling: growth + projections, in two quiet sublines.
	var at25 := Story.enemy_stats_at(kind, 25)
	var at50 := Story.enemy_stats_at(kind, 50)
	var g1 := m._lbl(info, "Growth per level:   HP +%d%%   ·   DMG +%d%%" %
		[int(st.get("hp_g", 0.1) * 100), int(st.get("dmg_g", 0.1) * 100)], 12, Color(0.55, 0.65, 0.8))
	g1.custom_minimum_size = Vector2(700, 0)
	var g2 := m._lbl(info, "Projected:   Lv 25 → %d HP, %d DMG        Lv 50 → %d HP, %d DMG" %
		[int(at25["hp"]), int(at25["dmg"]), int(at50["hp"]), int(at50["dmg"])], 12, Color(0.5, 0.55, 0.66))
	g2.custom_minimum_size = Vector2(700, 0)

	# Identity traits (2026-07-07): each kind's gimmick, so the
	# player learns the counter (kill the healer, dodge the pounce).
	for tr in st.get("traits", []):
		var td: String = Enemy.TRAIT_DESC.get(String(tr), "")
		if td != "":
			var tl := m._lbl(info, "◆ " + td, 12, Color(0.7, 0.85, 0.7))
			tl.custom_minimum_size = Vector2(700, 0)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Codex completion (retention roadmap #5): the kill tally, and
	# the lore this character has (or hasn't) earned the right to read.
	var kills: int = int(m.game.kill_counts.get(kind, 0))
	var need := Lore.threshold(kind)
	if kills >= need:
		var ll := m._lbl(info, "❝ %s ❞" % Lore.entry(kind), 13, Color(0.85, 0.78, 0.6))
		ll.custom_minimum_size = Vector2(700, 0)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		m._lbl(info, "Slain: %d / %d — its lore is still buried." % [kills, need],
			12, Color(0.5, 0.55, 0.66))

	# Bosses with authored mechanics get a jump-off to their detail view.
	var mechs: Array = st.get("mechanics", [])
	if is_boss and not detail and not mechs.is_empty():
		var bk := String(kind)
		m._btn(info, "  ▸ Mechanics & Tells  ",
			func() -> void: m.open_codex("bosses", bk), Color(1, 0.7, 0.7))


## Focused boss detail: the summary card, then each authored mechanic as
## its own mini-card (name heading, the TELL you'll see, the green COUNTER).
## Reached from the bestiary's boss cards; BACK returns to that list.
static func _boss_detail(m: Menus, kind: String) -> void:
	var st: Dictionary = Story.ALL_ENEMIES[kind]
	var vbox := m._open(String(st.get("name", kind)), 1000, 620, true)
	m.current = "codex"

	m._btn(vbox, "  ‹ Back to Bosses  ",
		func() -> void: m.open_codex("bosses"), Color(0.95, 0.85, 0.5))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	_enemy_card(m, list, kind, true, true)

	var mechs: Array = st.get("mechanics", [])
	if mechs.is_empty():
		m._lbl(list, "No mechanics catalogued for this foe yet.", 13, Color(0.6, 0.62, 0.68))
	else:
		m._lbl(list, "— MECHANICS & TELLS —", 16, Color(1, 0.5, 0.5))
		for mech in mechs:
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 3)
			_card(list).add_child(box)
			m._lbl(box, "◆ " + String(mech.get("name", "")), 15, Color(1, 0.7, 0.7))
			var tl := m._lbl(box, "Tell — " + String(mech.get("tell", "")), 13, Color(0.85, 0.82, 0.7))
			tl.custom_minimum_size = Vector2(880, 0)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var cl := m._lbl(box, "Counter — " + String(mech.get("counter", "")), 13, Color(0.7, 0.9, 0.7))
			cl.custom_minimum_size = Vector2(880, 0)
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	m._hint(vbox, "Click ✕, click outside, or press C to close")


static func _terrains(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var patch_desc := {
		"lava": "Lava pools — the floor burns anyone standing in them, you AND monsters",
		"ice": "Sheet ice — slippery patches speed everyone up by 35%",
		"poison": "Poison pools — standing in them poisons you",
		"heal": "Blessed ground — standing in it slowly heals you",
		"slow": "Clinging murk — wading through slows you by 30%",
	}
	var event_desc := {
		"magma_rain": "Magma rain — molten rock crashes onto telegraphed spots and the floor collapses into lava",
		"grave_spawn": "Restless dead — zombies periodically claw out of the ground beside you",
		"gust": "Sandstorm gusts — sudden wind shoves everyone sideways",
		"lightning": "Lightning strikes — bolts hammer telegraphed spots around you",
		"shard": "Shard eruptions — crystal bursts explode at random spots",
	}
	var ambient_desc := {
		"leaves_green": "drifting green leaves", "leaves_autumn": "falling autumn leaves",
		"fireflies": "fireflies", "embers": "rising embers", "snow": "falling snow",
		"rain": "heavy rain", "sand": "blowing sand", "mist": "creeping mist",
		"twinkle": "twinkling lights", "motes": "drifting void motes",
		"sparkle": "golden sparkles", "spores": "floating spores",
	}
	# Which Chapter 1 zone (if any) uses each terrain.
	var found_in := {}
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid]["zones"]:
			if not found_in.has(zone.get("terrain", "")):
				found_in[zone.get("terrain", "")] = zone["name"]

	var dev: bool = m.game.dev_mode
	for id in Terrains.DATA:
		var t: Dictionary = Terrains.DATA[id]
		# Placeholder terrains (authored from the asset packs for review) are
		# dev-launcher only, tagged [placeholder] there. The dev panel can
		# still paint any room with them regardless.
		var ph: bool = t.get("placeholder", false)
		if ph and not dev:
			continue
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		_card(list).add_child(info)

		# Name ................................... where it appears
		var head := HBoxContainer.new()
		info.add_child(head)
		var name_l := m._lbl(head, String(t["name"]) + ("   [placeholder]" if ph else ""), 16, Color(0.72, 0.68, 0.55) if ph else Color(1, 1, 1))
		name_l.custom_minimum_size = Vector2(560, 0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where: String = found_in.get(id, "")
		var where_l := m._lbl(head, where if where != "" else "Beyond Chapter 1", 13,
			Color(0.95, 0.85, 0.5) if where != "" else Color(0.55, 0.58, 0.66))
		where_l.custom_minimum_size = Vector2(220, 0)
		where_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var amb: String = t.get("ambient", "")
		var w := m._lbl(info, "Weather:   " + String(ambient_desc.get(amb, "still air")),
			13, Color(0.7, 0.72, 0.78))
		w.custom_minimum_size = Vector2(700, 0)

		var quirks: Array = []
		for p in t.get("patches", []):
			var d: String = patch_desc.get(p["type"], "")
			if p.get("drift", false):
				d += " — and the clouds DRIFT, so keep moving"
			quirks.append(d)
		if t.get("event", "") != "":
			quirks.append(event_desc.get(t["event"], ""))
		if t.get("mp_boost", false):
			quirks.append("Latent magic — your mana recovers much faster here")
		if t.has("river"):
			quirks.append("Rivers cross these lands — wading leaves you DAMP (-%d%% move speed for %ds) and slows monsters; the bridge crosses dry" % [
				int(round((1.0 - Balance.DAMP_SLOW_MULT) * 100.0)), int(Balance.DAMP_DURATION)])
		if quirks.is_empty():
			quirks.append("No hazards — safe ground")
		for q in quirks:
			var ql := m._lbl(info, "◆ " + String(q), 13, Color(0.55, 0.65, 0.8))
			ql.custom_minimum_size = Vector2(700, 0)


static func _statuses(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	m._lbl(list, "— STATUS EFFECTS —", 16, Color(0.6, 0.9, 1.0))
	var intro := m._lbl(list,
		"What you inflict on enemies (most ride your talent-themed abilities) — and, in hazard terrain, suffer yourself.",
		13, Color(0.7, 0.72, 0.78))
	intro.custom_minimum_size = Vector2(880, 0)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# name, colour, description lines. Numbers pull live from Balance so
	# the codex can never drift from the actual combat tuning.
	var effects := [
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
	]
	for e in effects:
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		_card(list).add_child(info)
		m._lbl(info, String(e[0]), 15, e[1])
		for line in e[2]:
			var dl := m._lbl(info, String(line), 13, Color(0.78, 0.8, 0.86))
			dl.custom_minimum_size = Vector2(880, 0)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Records tab: achievements (unlocked/locked) + boss personal bests.
static func _records(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)

	# --- achievements ---
	var unlocked := 0
	for id in Achievements.DATA:
		if m.game.achievements.has(id):
			unlocked += 1
	m._lbl(list, "— ACHIEVEMENTS —   %d / %d   ·   %d points" %
		[unlocked, Achievements.DATA.size(), m.game.achievement_points()], 16, Color(1.0, 0.85, 0.4))
	var ach := VBoxContainer.new()
	ach.add_theme_constant_override("separation", 3)
	_card(list).add_child(ach)
	for id in Achievements.ORDER:
		var a: Dictionary = Achievements.DATA[id]
		var got: bool = m.game.achievements.has(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		ach.add_child(row)
		var mark := m._lbl(row, "✓" if got else "—", 15, Color(0.55, 1.0, 0.55) if got else Color(0.5, 0.5, 0.55))
		mark.custom_minimum_size = Vector2(28, 0)
		var nm := m._lbl(row, String(a["name"]), 14, Color(1.0, 0.88, 0.45) if got else Color(0.6, 0.62, 0.68))
		nm.custom_minimum_size = Vector2(220, 0)
		var ds := m._lbl(row, String(a["desc"]), 13, Color(0.8, 0.82, 0.88) if got else Color(0.5, 0.52, 0.58))
		ds.custom_minimum_size = Vector2(560, 0)

	# --- boss personal bests ---
	m._lbl(list, "— BOSS RECORDS —   fastest clear · best dps · kills", 16, Color(1, 0.6, 0.6))
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
		var pb: Dictionary = m.game.chapter_pb(String(chid), m.game.player.cls)
		if pb.is_empty():
			continue
		any_pb = true
		var secs := int(float(pb.get("time", 0.0)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pbs.add_child(row)
		var nm := m._lbl(row, String(Story.chapter(String(chid))["name"]), 14, Color(0.85, 0.9, 1.0))
		nm.custom_minimum_size = Vector2(300, 0)
		var t := m._lbl(row, "%d:%02d" % [secs / 60, secs % 60], 14, Color(0.7, 1.0, 0.7))
		t.custom_minimum_size = Vector2(90, 0)
		var gr := String(pb.get("grade", "D"))
		var g := m._lbl(row, "grade %s" % gr, 14, Items.GRADE_COLOR.get(gr, Color(1, 1, 1)))
		g.custom_minimum_size = Vector2(120, 0)
		var runs := m._lbl(row, "×%d runs" % int(pb.get("runs", 1)), 14, Color(0.8, 0.82, 0.88))
		runs.custom_minimum_size = Vector2(100, 0)
	if not any_pb:
		m._lbl(pbs, "Clear a chapter to set its first mark — time and grade are kept per class.",
			13, Color(0.6, 0.62, 0.68))

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
		how.custom_minimum_size = Vector2(480, 0)


static func _gear(m: Menus, list: VBoxContainer) -> void:
	list.add_theme_constant_override("separation", 8)
	var slot_desc := {
		"weapon": "Main: your class attribute (largest budget). Upgradeable at merchants.",
		"armor": "Main: your class attribute. Upgradeable at merchants.",
		"boots": "Main: your class attribute (smallest budget).",
		"charm": "Main: your class attribute.",
	}

	# ------------------ visual gallery: every shape at every grade ------
	for slot in Items.SLOTS:
		m._lbl(list, "— %sS — %s" % [slot.to_upper(), slot_desc[slot]], 16, Color(0.95, 0.85, 0.5))
		for noun in Art.GEAR_SHAPES[slot]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_card(list).add_child(row)
			var tag: String = Items.SHAPE_STYLE.get(noun, {}).get("tag", "")
			var name_l := m._lbl(row, "%s\n%s" % [noun, tag], 13, Color(0.85, 0.85, 0.9))
			name_l.custom_minimum_size = Vector2(110, 34)
			for g in Items.GRADES:
				var cell := VBoxContainer.new()
				cell.custom_minimum_size = Vector2(48, 0)
				row.add_child(cell)
				var icon := TextureRect.new()
				icon.texture = Art.item_icon(slot, g, noun)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cell.add_child(icon)
				var gl := Label.new()
				gl.text = g
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				gl.add_theme_font_size_override("font_size", 12)
				gl.add_theme_color_override("font_color", Items.GRADE_COLOR[g])
				cell.add_child(gl)

	# --------------------------------------- named epics & legendaries --
	m._lbl(list, "— EPIC UNIQUES (A) — found in silver and golden chests —", 16, Items.GRADE_COLOR["A"])
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_card(list).add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(slot, "A")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := m._lbl(row, "  ·  ".join(Items.A_NAMES[slot]), 13, Items.GRADE_COLOR["A"])
		l.custom_minimum_size = Vector2(780, 0)

	m._lbl(list, "— LEGENDARY (S) — class exclusive, golden chests only —", 16, Items.GRADE_COLOR["S"])
	var awk := m._lbl(list, "A found or bought legendary keeps its name and top stats, but its signature PASSIVE sleeps — complete your class's short AWAKENING quest to wake it. Once awakened, every legendary of that class you carry is active.", 13, Color(0.85, 0.75, 0.55))
	awk.custom_minimum_size = Vector2(880, 0)
	awk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for cls in Items.S_GEAR:
		# One card per class holding its four legendary pieces.
		var cls_box := VBoxContainer.new()
		cls_box.add_theme_constant_override("separation", 4)
		_card(list).add_child(cls_box)
		m._lbl(cls_box, Classes.CLASSES[cls]["name"].to_upper(), 14, Color(0.95, 0.85, 0.5))
		for slot in Items.SLOTS:
			var special: Dictionary = Items.S_GEAR[cls][slot]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			cls_box.add_child(row)
			var icon := TextureRect.new()
			icon.texture = Art.item_icon(slot, "S", special.get("noun", ""))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var extra := ""
			if special.has("passive"):
				extra = "  ★ " + Items.PASSIVES[special["passive"]] + "  (DORMANT until you awaken it)"
			elif special.has("subs"):
				var bits: Array = []
				for stat in special["subs"]:
					var v: float = special["subs"][stat]
					if stat in Items.FLAT_STATS:
						bits.append("%s +%d" % [Items.STAT_LABEL[stat], int(v)])
					else:
						bits.append("%s +%d%%" % [Items.STAT_LABEL[stat], int(round(v * 100))])
				extra = "  (" + ", ".join(bits) + ")"
			var l := m._lbl(row, special["name"] + extra, 13, Items.GRADE_COLOR["S"])
			l.custom_minimum_size = Vector2(780, 0)

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
	m._lbl(chests, "Wooden chest — drops from monsters (common). Contains F to C gear.", 14, Color(0.8, 0.65, 0.45))
	m._lbl(chests, "Silver chest — drops from monsters (rare). Contains D to A gear.", 14, Color(0.8, 0.82, 0.9))
	m._lbl(chests, "Golden chest — every boss drops one. Contains B to S gear.", 14, Color(1.0, 0.85, 0.35))
	var bossdrop := m._lbl(chests, "Boss GEAR — every boss also has a chance to drop a piece of gear AND a bag, on top of its chest and gems. In Act 1 that piece is B-grade (about 1 in 3 per boss); only the FINAL chapter's bosses can drop an A. A-grade and up is farmed, not bought.", 13, Color(0.85, 0.75, 0.55))
	bossdrop.custom_minimum_size = Vector2(880, 0)
	bossdrop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m._lbl(chests, "Every piece is CLASS-LOCKED and guarantees your class attribute as its main (STR/AGI/INT). Bonus stats: ATK%, HP%, Crit, CritDmg, VIT, EVA, DEX, Pen, Resists, MP.", 13, Color(0.7, 0.72, 0.78))
	var resv := m._lbl(chests, "Haste, Lifesteal, Combo and Greed NEVER roll on gear — they are GEM-only (see below), and each item holds at most ONE such gem. MOVEMENT SPEED is on no item and no gem: only terrain and abilities touch it." , 13, Color(0.85, 0.75, 0.55))
	resv.custom_minimum_size = Vector2(880, 0)
	resv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var caps := m._lbl(chests, "STAT CAPS (soft — beyond each cap a point pays about a tenth, never nothing; Crit alone diminishes gentler, about a fifth): Crit %d%% · Evasion %d%% · Haste %d%% · Lifesteal %d%% · Combo %d%% · Greed %d%% · damage reduction from resistances %d%%. Ults ignore Haste entirely." %
		[int(Balance.CAP_CRIT * 100), int(Balance.CAP_EVA * 100), int(Balance.CAP_CDR * 100),
		int(Balance.CAP_LIFESTEAL * 100), int(Balance.CAP_COMBO * 100), int(Balance.CAP_GREED * 100),
		int(Balance.CAP_RES_FRAC * 100)], 13, Color(0.85, 0.75, 0.55))
	caps.custom_minimum_size = Vector2(880, 0)
	caps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ------------------------------------------------------------ gems ---
	m._lbl(list, "— GEMS — socket into B+ gear (B:%d · A:%d · S:%d sockets) —" %
		[int(Items.GEM_SLOTS["B"]), int(Items.GEM_SLOTS["A"]), int(Items.GEM_SLOTS["S"])],
		16, Color(0.6, 0.9, 1.0))
	var gem_intro := VBoxContainer.new()
	gem_intro.add_theme_constant_override("separation", 2)
	_card(list).add_child(gem_intro)
	for line3 in [
		"Each gem grants ONE stat and deepens with its level, up to Lv %d. Only B-grade gear and above has sockets." % Items.GEM_MAX_LEVEL,
		"Synthesis: fuse 3 gems of the SAME kind and level into one of the next level (click them in the bag) — duplicates are never wasted. Gems stack in the bag, one slot per kind+level.",
		"SPECIAL gems — Haste, Lifesteal, Combo, Greed — are the ONLY way to build those stats: at most one special gem per item, and their totals soft-cap at %d%% Haste / %d%% Lifesteal / %d%% Combo (beyond, a point pays about a tenth)." %
			[int(Balance.CAP_CDR * 100), int(Balance.CAP_LIFESTEAL * 100), int(Balance.CAP_COMBO * 100)],
		"A vessel holds what it can bear: B gear sockets gems up to Lv%d, A up to Lv%d, S up to Lv%d — deep gems need endgame gear." %
			[int(Items.GEM_LEVEL_LIMIT["B"]), int(Items.GEM_LEVEL_LIMIT["A"]), int(Items.GEM_LEVEL_LIMIT["S"])],
		"Merchants sell loose gems (at the act's level) and buy your spares back — but the buy price is a pity option: farming gems is always cheaper."]:
		var gil := m._lbl(gem_intro, String(line3), 13, Color(0.7, 0.72, 0.78))
		gil.custom_minimum_size = Vector2(880, 0)
		gil.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var gems_box := VBoxContainer.new()
	gems_box.add_theme_constant_override("separation", 3)
	_card(list).add_child(gems_box)
	for stat in Items.GEM_STATS:
		var info: Dictionary = Items.GEM_STATS[stat]
		var is_flat: bool = stat in Items.FLAT_STATS
		var v1: float = Items.gem_value(Items.make_gem(stat, 1))
		var vmax: float = Items.gem_value(Items.make_gem(stat, Items.GEM_MAX_LEVEL))
		var v1_txt: String = "+%d" % int(v1) if is_flat else "+%d%%" % int(round(v1 * 100))
		var vmax_txt: String = "+%d" % int(vmax) if is_flat else "+%d%%" % int(round(vmax * 100))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		gems_box.add_child(row)
		var sw := ColorRect.new()
		sw.color = info["color"]
		sw.custom_minimum_size = Vector2(16, 16)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var name_l := m._lbl(row, String(info["name"]), 13, info["color"])
		name_l.custom_minimum_size = Vector2(150, 0)
		var stat_l := m._lbl(row, Items.STAT_LABEL[stat], 13, Color(0.85, 0.85, 0.9))
		stat_l.custom_minimum_size = Vector2(120, 0)
		var val_l := m._lbl(row, "Lv1 %s   ·   Lv%d %s" % [v1_txt, Items.GEM_MAX_LEVEL, vmax_txt],
			13, Color(0.7, 0.72, 0.78))
		val_l.custom_minimum_size = Vector2(300, 0)

	# ------------------------------------------------- bags & consumables ---
	m._lbl(list, "— BAGS — carry up to 5 stacking bags; everything shares their slots —", 16, Color(0.95, 0.85, 0.5))
	var bags := VBoxContainer.new()
	bags.add_theme_constant_override("separation", 2)
	_card(list).add_child(bags)
	for g2 in Items.GRADES:
		m._lbl(bags, "%s   %s — %d slots" % [g2, Items.BAG_NAMES[g2], int(Items.BAG_SLOTS[g2])], 14, Items.GRADE_COLOR[g2])
	for line2 in [
		"Gear, gems and consumables all share your bags' slots — and EVERY unit counts: 20 potions take 20 slots (they only STACK for display). Equip up to %d bags at once — total capacity is the SUM of their slots (F pouch 10 … S hold 40). You start with two Frayed Pouches." % Balance.MAX_BAGS,
		"Bags drop from BOSSES and elites (tier scales with the act) and merchants stock them too — but a good bag costs real gold. Pick up one past your %d and your SMALLEST is cashed for %dg — the best %d are always kept." % [Balance.MAX_BAGS, Balance.BAG_SELL_GOLD, Balance.MAX_BAGS],
		"Full bag? Click any loose gear, gem, or consumable to open its detail card and DROP it — fling it out to free a slot. New loot drops at your feet instead of vanishing — anything left on the ground arrives in your MAILBOX (pause menu) when the chapter ends. Unclaimed letters expire after %d days." % Balance.MAIL_EXPIRY_DAYS]:
		var bl := m._lbl(bags, String(line2), 13, Color(0.7, 0.72, 0.78))
		bl.custom_minimum_size = Vector2(880, 0)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	m._lbl(list, "— CONSUMABLES —", 16, Color(0.6, 0.9, 1.0))
	var cons := VBoxContainer.new()
	cons.add_theme_constant_override("separation", 2)
	_card(list).add_child(cons)
	var cl := m._lbl(cons, "⟲ Stone of Unlearning — crush it (click it in the bag) to refund EVERY allocated talent point, attributes and substats alike, for reallocation. Elite drop (~1 in 3).", 13, Color(0.7, 0.72, 0.78))
	cl.custom_minimum_size = Vector2(880, 0)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tl := m._lbl(cons, "⟲ Palimpsest of the Path — crush it to refund EVERY spent skill point and pick a new path down the tree. Elite drop, rarer than the Stone.", 13, Color(0.7, 0.72, 0.78))
	tl.custom_minimum_size = Vector2(880, 0)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for util in [
		"🜁 Mana Draught — restore %d%% of your maximum mana. Bought from merchants." % int(Balance.MANA_POTION_FRAC * 100),
		"🜂 Elixir of Might — +%d%% damage for %ds. Pop it before a boss. Bought from merchants." % [int(Balance.ELIXIR_MIGHT_AMT * 100), int(Balance.ELIXIR_MIGHT_DUR)],
		"🜄 Elixir of Warding — cut incoming damage by %d%% for %ds. Bought from merchants." % [int(Balance.ELIXIR_WARD_AMT * 100), int(Balance.ELIXIR_WARD_DUR)],
		"🜔 Draught of Renewal — instantly restore %d%% of maximum health (stocks past the 5-potion cap). Bought from merchants." % int(Balance.RENEWAL_HEAL_FRAC * 100),
		"🜃 Scroll of Recall — whisk yourself back to the last safe room (not in combat). Bought from merchants."]:
		var ul := m._lbl(cons, String(util), 13, Color(0.7, 0.72, 0.78))
		ul.custom_minimum_size = Vector2(880, 0)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
