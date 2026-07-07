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
	_section(m, list, "CHARACTER")
	var row1 := _flow(list)
	m._btn(row1, ("■ God mode ON" if m.game.dev_god else "□ God mode off"), func() -> void:
		m.game.dev_god = not m.game.dev_god
		m.open_dev(), Color(0.5, 1.0, 0.5) if m.game.dev_god else Color(1, 1, 1))
	m._btn(row1, "Max potions", func() -> void:
		m.game.player.potions = Balance.POTION_MAX
		m.open_dev())
	m._btn(row1, "Heal + reset CDs", func() -> void:
		m.game.player.hp = m.game.player.max_hp
		m.game.player.mp = m.game.player.max_mp
		for key in m.game.player.cds:
			m.game.player.cds[key] = 0.0
		m.open_dev())
	# Unlimited respecs, no consumable needed (the stone/tome buttons
	# below still exist to test the REAL flow).
	m._btn(row1, "Refund talents", func() -> void:
		var p2: Player = m.game.player
		var back := 0
		for attr in p2.attr_points:
			back += int(p2.attr_points[attr])
			p2.attr_points[attr] = 0
		p2.unspent_attr += back
		p2.recalc()
		m.open_dev(), Color(0.6, 0.9, 1.0))
	m._btn(row1, "Refund skill tree", func() -> void:
		var p2: Player = m.game.player
		var back := 0
		for id2 in p2.tree_points:
			back += int(p2.tree_points[id2])
		p2.tree_points.clear()
		p2.skill_points += back
		p2.recalc()
		m.open_dev(), Color(0.6, 0.9, 1.0))
	m._btn(row1, "Die (test death)", func() -> void:
		m.game.player.hp = 0.0
		m.game.player.dead = true
		m.game.on_player_died()
		m.close(), Color(1, 0.5, 0.5))
	# Quantity row: type the amount, hit the button (playtest: +1/+5
	# buttons were tedious — "+99 levels if I want to").
	var rowq := _flow(list)
	_qty_btn(m, rowq, "1", "+ levels", func(n: int) -> void:
		var p2: Player = m.game.player
		for i in n:
			if p2.level >= Balance.LEVEL_CAP:
				break
			p2.gain_xp(p2.xp_needed() - p2.xp)
		m.open_dev())
	_qty_btn(m, rowq, "40", "Set level (rebirth: refunds all points)", func(n: int) -> void:
		_set_level(m, n)
		m.open_dev())
	_qty_btn(m, rowq, "500", "+ gold", func(n: int) -> void:
		m.game.player.gold += n
		m.open_dev())
	_qty_btn(m, rowq, "5", "+ attr pts", func(n: int) -> void:
		m.game.player.unspent_attr += n
		m.open_dev())
	_qty_btn(m, rowq, "5", "+ skill pts", func(n: int) -> void:
		m.game.player.skill_points += n
		m.open_dev())
	# Class swap re-gears: the weapon takes the class's signature shape,
	# S pieces become the class legendaries (grade/+level/gems carry).
	# set_class refunds all spent talent/tree points (they respec, never
	# vanish — old-class tree cells don't exist for the new class).
	var row2 := _flow(list)
	for id in Classes.CLASSES:
		var cid: String = id
		var cls_active: bool = m.game.player.cls == cid
		m._btn(row2, ("● " if cls_active else "") + "Class: " + Classes.CLASSES[id]["name"], func() -> void:
			m.game.player.set_class(cid)
			_regear_for_class(m)
			m.open_dev(), Color(0.5, 1.0, 0.5) if cls_active else Color(0.6, 0.9, 1.0))

	# ------------------------------------------------- last fight report ---
	# The benchmark line the last boss roster printed (TTK / dps / damage
	# taken / potions / wipes). On screen it floats for 5s then fades;
	# here it stays put, and every kill also mails it as a victory letter.
	_section(m, list, "LAST BOSS FIGHT")
	var report: String = m.game.last_fight_report
	var rlbl := m._lbl(list, report if report != "" else "No fight recorded yet — the report lands when a boss roster falls.",
		14, Color(0.85, 0.9, 1.0) if report != "" else Color(0.6, 0.62, 0.68))
	rlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --------------------------------------------- progression & economy ---
	# Levers for the account/progression systems (dailies, bounties, vault,
	# achievements, records) and the economy (consumables, gambling) so they
	# can be exercised without waiting on the clock or grinding the trigger.
	_section(m, list, "PROGRESSION & ECONOMY")
	var mrow := _flow(list)
	m._btn(mrow, "Daily: make claimable", func() -> void:
		m.game.daily_last_day = -1
		m.open_dev(), Color(1.0, 0.88, 0.45))
	m._btn(mrow, "Daily: +1 streak", func() -> void:
		m.game.daily_streak += 1
		m.open_dev(), Color(1.0, 0.88, 0.45))
	m._btn(mrow, "Bounties: (re)roll", func() -> void:
		m.game.bounties = []
		m.game.bounty_day = -1
		m.game.bounty_week = -1
		m.game.refresh_bounties()
		m.open_dev(), Color(0.6, 1.0, 0.7))
	m._btn(mrow, "Bounties: complete all", func() -> void:
		for b in m.game.bounties:
			m.game.bounty_progress(String(b["type"]), int(b["target"]))
		m.open_dev(), Color(0.6, 1.0, 0.7))
	m._btn(mrow, "Vault: make ready", func() -> void:
		m.game.vault_week = m.game._week_index()
		m.game.vault_progress = Balance.VAULT_BOSS_GOAL
		m.game.vault_claimed_week = -1
		m.game.spawn_text(m.game.player.global_position + Vector2(0, -60), "vault ready", Color(1, 0.85, 0.4))
		m.open_dev(), Color(1.0, 0.85, 0.4))

	var mrow2 := _flow(list)
	m._btn(mrow2, "Unlock ALL achievements", func() -> void:
		for id in Achievements.DATA:
			m.game.unlock_achievement(String(id))
		m.open_dev(), Color(1.0, 0.85, 0.4))
	m._btn(mrow2, "Reset achievements", func() -> void:
		m.game.achievements.clear()
		m.open_dev())
	m._btn(mrow2, "Add sample boss records", func() -> void:
		m.game.record_boss("fangmaw", 42.0, 1800.0)
		m.game.record_boss("vargoth", 88.0, 2400.0)
		m.open_dev(), Color(1.0, 0.6, 0.6))
	m._btn(mrow2, "Give utility consumables", func() -> void:
		m.game.player.add_consumable(Items.make_mana_potion())
		m.game.player.add_consumable(Items.make_elixir_might())
		m.game.player.add_consumable(Items.make_recall_scroll())
		m.open_dev(), Color(0.6, 0.9, 1.0))
	m._btn(mrow2, "Gamble x5 (silver)", func() -> void:
		m.game.player.gold += 5000
		for i in 5:
			m.game.gamble("silver")
		m.open_dev(), Color(0.85, 0.6, 1.0))

	# Jump straight into the feature screens (reforge lives inside an item's
	# panel; equip a set below and open the bag to reach it).
	var mrow3 := _flow(list)
	m._btn(mrow3, "→ Open Stash", func() -> void: m.game.menus.open_stash(), Color(0.9, 0.9, 0.95))
	m._btn(mrow3, "→ Open Quest Log", func() -> void: m.game.menus.open_journal(), Color(0.9, 0.9, 0.95))
	m._btn(mrow3, "→ Open Daily", func() -> void:
		m.game.daily_last_day = -1
		m.game.menus.open_daily(), Color(1.0, 0.88, 0.45))
	m._btn(mrow3, "→ Open Bag (gems/reforge)", func() -> void: m.game.menus.open_inventory(), Color(0.9, 0.9, 0.95))

	# ------------------------------------------------------------ items ---
	_section(m, list, "ITEMS & GEMS")
	var row3 := _flow(list)
	for grade in ["C", "B", "A", "S"]:
		var g: String = grade
		m._btn(row3, "Equip full %s set" % g, func() -> void:
			_equip_set(m, g)
			m.open_dev(), Items.GRADE_COLOR[g])
	# Gems by the crate: count box + level box + button.
	var gem_n := _qty_box(row3, "10")
	var gem_lv := _qty_box(row3, "1")
	m._btn(row3, "← give N gems of Lv", func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var n := clampi(int(gem_n.text) if gem_n.text.is_valid_int() else 10, 1, 2000)
		var lv := clampi(int(gem_lv.text) if gem_lv.text.is_valid_int() else 1, 1, Items.GEM_MAX_LEVEL)
		for i in n:
			m.game.player.gem_bag.append(Items.random_gem(rng, lv))
		m.open_dev())
	m._btn(row3, "Give reset stone", func() -> void:
		m.game.player.add_consumable(Items.make_reset_stone())
		m.open_dev(), Color(0.6, 0.9, 1.0))
	m._btn(row3, "Give respec tome", func() -> void:
		m.game.player.add_consumable(Items.make_respec_tome())
		m.open_dev(), Color(0.6, 0.9, 1.0))
	# Awaken toggle (round 51b): flip the current class's legendary-passive
	# awakening flag so dropped/bought S weapons wake up, for testing before
	# the awakening quests exist.
	var awk_cls: String = m.game.player.cls
	var awk_on: bool = bool(m.game.get_flag("s_awakened_" + awk_cls, false))
	m._btn(row3, ("■ S passive AWAKENED" if awk_on else "□ Awaken S passive (this class)"), func() -> void:
		m.game.set_flag("s_awakened_" + awk_cls, not awk_on)
		m.game.player.recalc()
		m.open_dev(), Color(1.0, 0.85, 0.35))
	m._btn(row3, "Send gift mail", func() -> void:
		var grng := RandomNumberGenerator.new()
		grng.randomize()
		m.game.send_mail("A Gift from the Devs", "Thanks for playing the event!",
			[{"kind": "item", "item": Items.roll_item_of(Items.SLOTS[grng.randi_range(0, 3)], "A", grng, m.game.player.cls)},
			{"kind": "gem", "gem": Items.random_gem(grng, 2)}])
		m.open_dev(), Color(0.8, 0.9, 1.0))
	m._btn(row3, "Age mail +31d", func() -> void:
		for mail in m.game.mailbox:
			mail["sent_at"] = int(mail["sent_at"]) - 31 * 86400
		m.game.prune_mail()
		m.open_dev(), Color(0.8, 0.9, 1.0))
	m._btn(row3, "Bag +1 tier", func() -> void:
		var idx: int = Items.GRADES.find(String(m.game.player.bag["grade"]))
		if idx < Items.GRADES.size() - 1:
			m.game.player.acquire_bag(Items.make_bag(Items.GRADES[idx + 1]))
		m.open_dev(), Color(0.95, 0.85, 0.5))
	for grade2 in Items.GRADES:
		var bg: String = grade2
		var bag_active: bool = String(m.game.player.bag["grade"]) == bg
		m._btn(row3, ("● " if bag_active else "") + "Bag %s" % bg, func() -> void:
			m.game.player.bag = Items.make_bag(bg)  # direct set — downgrades allowed for capacity testing
			m.open_dev(), Items.GRADE_COLOR[bg])

	# ------------------------------------------------------------ world ---
	_section(m, list, "WORLD (rooms of this chapter's graph)")
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
	m._btn(row4b, "Spawn test dummy", func() -> void:
		# Immortal DPS target: hit it and the floating readout tallies
		# realized dps / peak / crit, resetting after 5s untouched.
		m.game.add_enemy(Dummy.spawn_dummy(m.game, m.game.player.global_position + Vector2(200, 0)))
		m.close(), Color(0.85, 0.9, 0.5))
	m._btn(row4b, "Remove dummies", func() -> void:
		for node in m.get_tree().get_nodes_in_group("enemies"):
			if node is Dummy:
				node.remove_from_group("enemies")
				node.queue_free()
		m.open_dev(), Color(0.85, 0.9, 0.5))
	m._btn(row4b, "Spawn elite (my Lv+1)", func() -> void:
		var e := Enemy.make(m.game, "wolf",
			m.game.player.global_position + Vector2(260, 0), m.game.player.level + 1)
		e.promote_elite()
		m.game.add_enemy(e)
		m.close(), Color(1.0, 0.8, 0.4))
	m._btn(row4b, "Spawn 3 elites", func() -> void:
		var kinds := ["wolf", "spider", "skeleton"]
		for i in 3:
			var e3 := Enemy.make(m.game, kinds[i],
				m.game.player.global_position + Vector2(240 + i * 80, -70 + i * 70),
				m.game.player.level + 1)
			e3.promote_elite()
			m.game.add_enemy(e3)
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
	# Exact-level override: types like "100" — wins over the buttons
	# while non-empty, for NEW spawns only.
	var ovr := LineEdit.new()
	ovr.placeholder_text = "exact Lv"
	ovr.custom_minimum_size = Vector2(96, 0)
	ovr.max_length = 3
	if m.dev_boss_level_override > 0:
		ovr.text = str(m.dev_boss_level_override)
	ovr.text_changed.connect(func(t: String) -> void:
		m.dev_boss_level_override = clampi(int(t), 0, Balance.LEVEL_CAP) if t.is_valid_int() else 0)
	lrow.add_child(ovr)
	var ovr_note := m._lbl(lrow, "← override wins while set (new spawns only)", 12, Color(0.55, 0.58, 0.66))
	ovr_note.custom_minimum_size = Vector2(330, 0)  # labels in box containers collapse without this
	var row5 := _flow(list)
	for kind in m.BOSS_KINDS:
		var k: String = kind
		m._btn(row5, "Spawn " + k, func() -> void:
			# A fresh spawn is a fresh benchmark: clear any leftover fight
			# state (an abandoned boss's pool/wipes/clock) so this roster's
			# report is trustworthy. (Stacking a brawl? Spawn them all in
			# one breath BEFORE first blood — engage snapshots the field.)
			m.game.fight_reset()
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
		# Removal, not a real kill: reset first so the death doesn't fire a
		# junk near-zero-TTK report, and no state lingers for the next spawn.
		m.game.fight_reset()
		for b in m.game._live_bosses().duplicate():
			b.untargetable = false  # dev kill pierces burrow/submerge phases
			b.take_damage(9999999.0)
		m.open_dev())

	# ------------------------------------------------------------ audio ---
	_section(m, list, "AUDIO (browse every track and sound in the game)")
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

	# Audition the PURCHASED libraries in-game (tools/audio_library +
	# tools/audio_sfx — gitignored). Searchable, grouped by source pack:
	# type to filter, click to hear, note the name, tell the installer.
	_library_browser(m, list, "MUSIC LIBRARY", _library_tracks(),
		func(e: Dictionary) -> void:
			var ogg := AudioStreamOggVorbis.load_from_file(String(e["path"]))
			if ogg:
				ogg.loop = true
				m.game.current_track = "(library) " + String(e["label"])
				m.game.music_player.stream = ogg
				m.game.music_player.volume_db = m.game.MUSIC_DB \
					+ m.game._vol_db(float(m.game.settings["music"]))
				m.game.music_player.play())
	_library_browser(m, list, "SFX LIBRARY",
		_library_files("res://../tools/audio_sfx", [".wav", ".ogg", ".mp3"]),
		func(e: Dictionary) -> void:
			var stream := _load_stream(String(e["path"]))
			if stream:
				var sp := AudioStreamPlayer.new()
				sp.stream = stream
				sp.volume_db = -8.0 + m.game._vol_db(float(m.game.settings["sfx"]))
				sp.process_mode = Node.PROCESS_MODE_ALWAYS
				m.game.add_child(sp)
				sp.finished.connect(sp.queue_free)
				sp.play())

	# --------------------------------------------------------- terrains ---
	_section(m, list, "TERRAIN (applies to the room you're standing in)")
	var trow := _flow(list)
	for tid in Terrains.DATA:
		var t: String = tid
		var active: bool = m.game.terrain_by_zone[m.game.cur_room] == t
		m._btn(trow, ("● " if active else "") + Terrains.DATA[t]["name"], func() -> void:
			m.game.apply_terrain(m.game.cur_room, t)
			m.close(), Color(0.5, 1.0, 0.5) if active else Color(1, 1, 1))
	m._hint(vbox, "ESC / F1 to close")


## Every matching file under a library dir (recursive). Each entry:
## group = top-level source folder ("Miscellaneous" for root strays),
## label = the rest of the path. Empty when the library isn't built on
## this machine (gitignored — see the asset-library workflow).
static func _library_files(res_dir: String, exts: Array) -> Array:
	var out: Array = []
	var root := ProjectSettings.globalize_path(res_dir)
	if not DirAccess.dir_exists_absolute(root):
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			var full := dir_path + "/" + f
			if d.current_is_dir() and not f.begins_with("."):
				stack.append(full)
			else:
				for ext in exts:
					if f.to_lower().ends_with(String(ext)):
						var rel := full.trim_prefix(root + "/")
						var group := "Miscellaneous"
						var label := rel.get_basename()
						if rel.contains("/"):
							group = rel.split("/")[0]
							label = rel.substr(group.length() + 1).get_basename()
						out.append({"path": full, "group": group, "label": label})
						break
			f = d.get_next()
		d.list_dir_end()
	out.sort_custom(func(a, b) -> bool:
		if a["group"] == b["group"]:
			return String(a["label"]) < String(b["label"])
		return String(a["group"]) < String(b["group"]))
	return out


## A searchable, source-grouped audition list: a filter box over an
## ItemList with gold group headers. Click a row to hear it.
static func _library_browser(m: Menus, list: VBoxContainer, title: String,
		files: Array, on_pick: Callable) -> void:
	if files.is_empty():
		return
	m._lbl(list, "%s — %d files, type to filter:" % [title, files.size()],
		13, Color(0.7, 0.75, 0.85))
	var search := LineEdit.new()
	search.placeholder_text = "search…"
	list.add_child(search)
	var il := ItemList.new()
	il.custom_minimum_size = Vector2(0, 170)
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(il)
	var row_meta: Array = []  # ItemList row -> file entry (null = header)
	var rebuild := func(filter: String) -> void:
		il.clear()
		row_meta.clear()
		var f := filter.strip_edges().to_lower()
		var current_group := ""
		for e in files:
			if f != "" and not String(e["label"]).to_lower().contains(f) \
					and not String(e["group"]).to_lower().contains(f):
				continue
			if e["group"] != current_group:
				current_group = e["group"]
				var gi := il.add_item("— %s —" % current_group, null, false)
				il.set_item_disabled(gi, true)
				il.set_item_custom_fg_color(gi, Color(0.95, 0.85, 0.5))
				row_meta.append(null)
			il.add_item("    " + String(e["label"]))
			row_meta.append(e)
	rebuild.call("")
	search.text_changed.connect(func(t: String) -> void: rebuild.call(t))
	il.item_selected.connect(func(idx: int) -> void:
		if idx < row_meta.size() and row_meta[idx] != null:
			on_pick.call(row_meta[idx]))


static func _library_tracks() -> Array:
	return _library_files("res://../tools/audio_library", [".ogg"])


## Load any audio file by extension (the game.gd loader patterns).
static func _load_stream(path: String) -> AudioStream:
	var low := path.to_lower()
	if low.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if low.ends_with(".wav"):
		return Sfx.load_wav(path)
	if low.ends_with(".mp3"):
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		return mp3 if not mp3.data.is_empty() else null
	return null


## A section header with a thin gold divider above it, so the long flat
## scroll reads as distinct blocks instead of one wall of buttons.
static func _section(m: Menus, list: VBoxContainer, title: String) -> void:
	var div := ColorRect.new()
	div.color = Color(0.95, 0.85, 0.5, 0.28)
	div.custom_minimum_size = Vector2(0, 2)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(div)
	m._lbl(list, title, 17, Color(0.98, 0.88, 0.55))


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


## A small numeric input box for quantity rows.
static func _qty_box(row: Control, def: String) -> LineEdit:
	var box := LineEdit.new()
	box.text = def
	box.custom_minimum_size = Vector2(64, 0)
	box.max_length = 6
	row.add_child(box)
	return box


## [amount box][button] pair: the button parses its own box and calls
## fn(n). Every "+X" dev action takes a typed amount (+99 levels,
## +2000 gems — absurd amounts are the point of a dev panel).
static func _qty_btn(m: Menus, row: Control, def: String, label: String, fn: Callable, color := Color(1, 1, 1)) -> void:
	var box := _qty_box(row, def)
	m._btn(row, label, func() -> void:
		var fallback := int(def)
		var n := clampi(int(box.text) if box.text.is_valid_int() else fallback, 1, 999999)
		fn.call(n), color)


## Dev: set the EXACT level — a rebirth. Level and xp reset, every
## talent/tree point refunds (set_class does that) and the pools are
## re-granted at the per-level rates, ready to hand-allocate.
static func _set_level(m: Menus, target: int) -> void:
	var p: Player = m.game.player
	p.level = clampi(target, 1, Balance.LEVEL_CAP)
	p.xp = 0
	p.set_class(p.cls)  # refunds points, re-derives themes for the new level
	p.skill_points = (p.level - 1) * Balance.SKILL_POINTS_PER_LEVEL
	p.unspent_attr = (p.level - 1) * Balance.ATTR_POINTS_PER_LEVEL
	p.recalc()
	p.hp = p.max_hp
	p.mp = p.max_mp
	m.game.spawn_text(p.global_position + Vector2(0, -56),
		"REBIRTH — Lv %d, %d skill + %d attr points to allocate" % [p.level, p.skill_points, p.unspent_attr],
		Color(0.5, 0.9, 1.0))


## Write one fresh save per class (chapter 1, given level, all points
## banked, no gear) — ALWAYS all six, every press. Free slots only
## (existing saves are never touched); with 20 slots that's three full
## rosters before anything needs deleting. Returns how many were
## created (short only when the slots genuinely run out). Lives here
## with the other dev tools, but the BUTTON is on the launcher screens
## (Menus._dev_roster_row) — no need to enter a game first.
static func create_roster(m: Menus, lvl: int) -> int:
	if m.game.no_saves:
		return 0  # test runs must never write real save files
	var made := 0
	var slot := 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for cid in Classes.CLASSES:
		while slot <= SaveGame.MAX_SLOTS and SaveGame.exists(slot):
			slot += 1
		if slot > SaveGame.MAX_SLOTS:
			break
		var data := {
			"version": SaveGame.VERSION,
			"saved_at": Time.get_unix_time_from_system(),
			"chapter": "ch1",
			"cls": cid,
			"level": lvl, "xp": 0,
			"skill_points": (lvl - 1) * Balance.SKILL_POINTS_PER_LEVEL,
			"unspent_attr": (lvl - 1) * Balance.ATTR_POINTS_PER_LEVEL,
			"tree_points": {}, "attr_points": {},
			"gold": 2000, "potions": 3,
			"quest_key": "talk",
			"wander_seed": rng.randi(),
		}
		var f := FileAccess.open(SaveGame.path(slot), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(data))
			made += 1
		slot += 1
	return made


## Dev: the level bosses spawn at, per the "Spawn bosses at" selector.
## -1 = the kind's story anchor (make_boss default); below-anchor asks
## clamp UP — a monster's listed level is its minimum.
static func _boss_level(m: Menus) -> int:
	# The override field wins while set: spawn ANY boss at an exact
	# level (e.g. Fangmaw at 100 vs an endgame build). New spawns only —
	# bosses already in the arena keep the level they spawned with.
	if m.dev_boss_level_override > 0:
		return m.dev_boss_level_override
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
