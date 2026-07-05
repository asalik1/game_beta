class_name UIDevPanel
## The F1 debug panel (dev_mode.bat only), split out of menus.gd.
## Static builders: `m` owns the scaffolding and dev_boss_mode state.

## Debug panel (F1, only when launched via dev_mode.bat). Lets the
## tester change class/level/gear/terrain/bosses instantly instead of
## replaying from scratch.
static func open(m: Menus) -> void:
	var p: Player = m.game.player
	var vbox := m._open("DEV PANEL — room %d/%d: %s (%s)" % [m.game.cur_room, m.game.zone_count,
		m.game.zones[m.game.cur_room]["name"], m.game.terrain_by_zone[m.game.cur_room]], 1160, 660)
	m.current = "dev"

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# ------------------------------------------------------- character ---
	m._lbl(list, "CHARACTER", 16, Color(0.95, 0.85, 0.5))
	var row1 := _flow(list)
	m._btn(row1, ("■ God mode ON" if m.game.dev_god else "□ God mode off"), func() -> void:
		m.game.dev_god = not m.game.dev_god
		m.open_dev(), Color(0.5, 1.0, 0.5) if m.game.dev_god else Color(1, 1, 1))
	m._btn(row1, "+1 level", func() -> void:
		m.game.player.gain_xp(m.game.player.xp_needed())
		m.open_dev())
	m._btn(row1, "+5 levels", func() -> void:
		for i in 5:
			m.game.player.gain_xp(m.game.player.xp_needed())
		m.open_dev())
	m._btn(row1, "+500 gold", func() -> void:
		m.game.player.gold += 500
		m.open_dev())
	m._btn(row1, "+5 attr pts", func() -> void:
		m.game.player.unspent_attr += 5
		m.open_dev())
	m._btn(row1, "+5 skill pts", func() -> void:
		m.game.player.skill_points += 5
		m.open_dev())
	m._btn(row1, "Max potions", func() -> void:
		m.game.player.potions = 5
		m.open_dev())
	m._btn(row1, "Heal + reset CDs", func() -> void:
		m.game.player.hp = m.game.player.max_hp
		m.game.player.mp = m.game.player.max_mp
		for key in m.game.player.cds:
			m.game.player.cds[key] = 0.0
		m.open_dev())
	m._btn(row1, "Die (test death)", func() -> void:
		m.game.player.hp = 0.0
		m.game.player.dead = true
		m.game.on_player_died()
		m.close(), Color(1, 0.5, 0.5))
	# Class swap re-gears: the weapon takes the class's signature shape,
	# S pieces become the class legendaries (grade/+level/gems carry).
	var row2 := _flow(list)
	for id in Classes.CLASSES:
		var cid: String = id
		var cls_active: bool = m.game.player.cls == cid
		m._btn(row2, ("● " if cls_active else "") + "Class: " + Classes.CLASSES[id]["name"], func() -> void:
			m.game.player.set_class(cid)
			_regear_for_class(m)
			m.open_dev(), Color(0.5, 1.0, 0.5) if cls_active else Color(0.6, 0.9, 1.0))

	# ------------------------------------------------------------ items ---
	m._lbl(list, "ITEMS & GEMS", 16, Color(0.95, 0.85, 0.5))
	var row3 := _flow(list)
	for grade in ["C", "B", "A", "S"]:
		var g: String = grade
		m._btn(row3, "Equip full %s set" % g, func() -> void:
			_equip_set(m, g)
			m.open_dev(), Items.GRADE_COLOR[g])
	m._btn(row3, "Give 5 gems", func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 5:
			m.game.player.gem_bag.append(Items.random_gem(rng, 1))
		m.game.player.gem_bag.append(Items.random_gem(rng, 3))
		m.open_dev())
	m._btn(row3, "Give reset stone", func() -> void:
		m.game.player.add_consumable(Items.make_reset_stone())
		m.open_dev(), Color(0.6, 0.9, 1.0))
	m._btn(row3, "Bag +1 tier", func() -> void:
		var idx: int = Items.GRADES.find(String(m.game.player.bag["grade"]))
		if idx < Items.GRADES.size() - 1:
			m.game.player.acquire_bag(Items.make_bag(Items.GRADES[idx + 1]))
		m.open_dev(), Color(0.95, 0.85, 0.5))

	# ------------------------------------------------------------ world ---
	m._lbl(list, "WORLD (rooms of this chapter's graph)", 16, Color(0.95, 0.85, 0.5))
	var row4 := _flow(list)
	for zi in m.game.zone_count:
		var z: int = zi
		m._btn(row4, "%d %s" % [z, m.game.zones[z]["name"]], func() -> void:
			m.game.player.global_position = m.game.room_center(z)
			m.game._enter_room(z)
			m.close())
	var row4b := _flow(list)
	m._btn(row4b, "Clear room monsters", func() -> void:
		for node in m.get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and not (e is Boss) and e.zone_idx == m.game.cur_room:
				e.take_damage(9999999.0)
		m.open_dev())
	m._btn(row4b, "Reveal whole map", func() -> void:
		for zi2 in m.game.zone_count:
			m.game.visited[zi2] = true
			m.game.door_seen[zi2] = true
		m.open_map())
	m._btn(row4b, "Spawn elite (my Lv+1)", func() -> void:
		var e := Enemy.make(m.game, "wolf",
			m.game.player.global_position + Vector2(260, 0), m.game.player.level + 1)
		e.promote_elite()
		m.game.add_enemy(e)
		m.close(), Color(1.0, 0.8, 0.4))
	# Boss spawn level: story anchor, or pinned to your level (+10/+20
	# probes the no-downscale walls without hand-leveling first).
	var lrow := _flow(list)
	var lvl_lbl := m._lbl(lrow, "Spawn bosses at:", 14)
	lvl_lbl.custom_minimum_size = Vector2(130, 0)
	var modes := ["story Lv", "my Lv", "my Lv +10", "my Lv +20"]
	for i in modes.size():
		var mi: int = i
		m._btn(lrow, ("● " if m.dev_boss_mode == mi else "") + modes[mi], func() -> void:
			m.dev_boss_mode = mi
			m.open_dev(), Color(0.5, 1.0, 0.5) if m.dev_boss_mode == mi else Color(1, 1, 1))
	var row5 := _flow(list)
	for kind in m.BOSS_KINDS:
		var k: String = kind
		m._btn(row5, "Spawn " + k, func() -> void:
			# Spawns STACK — brawl-test up to 5 at once. The bar follows
			# your target; boss_x2..boss_x5 tracks play when installed.
			var b: Boss = Boss.make_boss(m.game, k,
				m.game.player.global_position + Vector2(320, 0), _boss_level(m))
			m.game.bosses.append(b)
			m.game.current_boss = b
			m.game.add_child(b)
			m.game.hud.show_boss_bar(Story.ALL_ENEMIES[k]["name"])
			m.game.set_music(m.game._boss_music())
			m.close(), Color(1, 0.6, 0.6))
	m._btn(row5, "Kill bosses", func() -> void:
		for b in m.game._live_bosses().duplicate():
			b.take_damage(9999999.0)
		m.open_dev())

	# ------------------------------------------------------------ audio ---
	m._lbl(list, "AUDIO (browse every track and sound in the game)", 16, Color(0.95, 0.85, 0.5))
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	list.add_child(arow)
	var ml := m._lbl(arow, "Music:", 14)
	ml.custom_minimum_size = Vector2(60, 0)
	var mopt := OptionButton.new()
	mopt.add_item("(silence)")
	var mkeys: Array = m.game.music_tracks.keys()
	mkeys.sort()
	for k in mkeys:
		mopt.add_item(k)
		if k == m.game.current_track:
			mopt.select(mopt.item_count - 1)
	mopt.item_selected.connect(func(idx: int) -> void:
		m.game.set_music("" if idx == 0 else mkeys[idx - 1])
	)
	arow.add_child(mopt)
	var sl := m._lbl(arow, "   Play SFX once:", 14)
	sl.custom_minimum_size = Vector2(140, 0)
	var sopt := OptionButton.new()
	sopt.add_item("(choose a sound)")
	var skeys: Array = m.game.sounds.keys()
	skeys.sort()
	for k in skeys:
		sopt.add_item(k)
	sopt.item_selected.connect(func(idx: int) -> void:
		if idx > 0:
			m.game.sfx(skeys[idx - 1])
	)
	arow.add_child(sopt)

	# --------------------------------------------------------- terrains ---
	m._lbl(list, "TERRAIN (applies to the room you're standing in)", 16, Color(0.95, 0.85, 0.5))
	var trow := _flow(list)
	for tid in Terrains.DATA:
		var t: String = tid
		var active: bool = m.game.terrain_by_zone[m.game.cur_room] == t
		m._btn(trow, ("● " if active else "") + Terrains.DATA[t]["name"], func() -> void:
			m.game.apply_terrain(m.game.cur_room, t)
			m.close(), Color(0.5, 1.0, 0.5) if active else Color(1, 1, 1))
	m._hint(vbox, "ESC / F1 to close")


## A wrapping button row: the dev panel used fixed HBox rows, which
## overflowed off the right edge (long room names) — a flow container
## wraps to the next line instead.
static func _flow(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row


## Dev: the level bosses spawn at, per the "Spawn bosses at" selector.
## -1 = the kind's story anchor (make_boss default); below-anchor asks
## clamp UP — a monster's listed level is its minimum.
static func _boss_level(m: Menus) -> int:
	match m.dev_boss_mode:
		1: return m.game.player.level
		2: return m.game.player.level + 10
		3: return m.game.player.level + 20
	return -1


## Dev: equip a fresh full set of `grade` gear in every slot — the
## weapon in the class's signature shape, S pieces as the class
## legendaries. Replaced items vanish; their gems return to the bag.
static func _equip_set(m: Menus, grade: String) -> void:
	var p: Player = m.game.player
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for slot in Items.SLOTS:
		var noun: String = Items.class_weapon_noun(p.cls) if slot == "weapon" else ""
		if p.equipment.has(slot):
			p.strip_gems(p.equipment[slot])
		p.equipment[slot] = Items.roll_item_of(slot, grade, rng, p.cls, noun)
	p.recalc()
	p._update_weapon_visual()
	m.game.sfx("equip")


## Dev: after a class swap, re-roll equipped gear into the new class's
## version — the weapon always (signature shape), other slots only at
## S grade (class legendaries); non-S armor is class-agnostic anyway.
## Grade, +level and socketed gems carry over.
static func _regear_for_class(m: Menus) -> void:
	var p: Player = m.game.player
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for slot in p.equipment.keys():
		var old: Dictionary = p.equipment[slot]
		if slot != "weapon" and str(old.get("grade", "")) != "S":
			continue
		var noun: String = Items.class_weapon_noun(p.cls) if slot == "weapon" else ""
		var item := Items.roll_item_of(slot, str(old["grade"]), rng, p.cls, noun)
		item["plus"] = old.get("plus", 0)
		item["gems"] = old.get("gems", [])
		p.equipment[slot] = item
	p.recalc()
	p._update_weapon_visual()
