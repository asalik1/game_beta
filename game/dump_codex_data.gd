extends SceneTree
## DEV DUMP (not part of the game): writes the codex's live data — the same
## tables scripts/ui/codex.gd reads — as JSON, so a layout mock can be built
## against REAL density (41 monsters, 21 bosses...) instead of lorem ipsum.
## Run: godot --headless --path game --script res://dump_codex_data.gd -- <out.json>


func _init() -> void:
	Story.load_content()
	var out := {}
	# Which zone/chapter first uses each enemy kind + each terrain.
	var used := {}
	var found_in := {}
	var chapter_of := {}
	for chid in Story.CHAPTER_LIST:
		var ch: Dictionary = Story.CHAPTER_LIST[chid]
		var fb := String(ch.get("final_boss", ""))
		if fb != "":
			used[fb] = true
			if not chapter_of.has(fb):
				chapter_of[fb] = String(chid)
		for zone in ch.get("zones", []):
			var tid := String(zone.get("terrain", ""))
			if tid != "" and not found_in.has(tid):
				found_in[tid] = {"zone": String(zone.get("name", "")), "chapter": String(chid)}
			var b := String(zone.get("boss", ""))
			if b != "":
				used[b] = true
				if not chapter_of.has(b):
					chapter_of[b] = String(chid)
			for e in zone.get("enemies", []):
				if e is Array and e.size() > 0:
					used[String(e[0])] = true
					if not chapter_of.has(String(e[0])):
						chapter_of[String(e[0])] = String(chid)
	var boss_kinds: Array = Menus.BOSS_KINDS
	var monsters: Array = []
	var bosses: Array = []
	for kind in Story.ALL_ENEMIES:
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if not used.has(kind) or st.get("placeholder", false):
			continue
		var is_boss: bool = kind in boss_kinds
		if not is_boss and st.get("xp", 0) <= 0 and st.get("gold", 0) <= 0:
			continue
		var live: Dictionary = Story.enemy_stats_at(kind, int(st.get("level", 1)))
		var traits: Array = []
		for tr in st.get("traits", []):
			var td: String = Enemy.TRAIT_DESC.get(String(tr), "")
			if td != "":
				traits.append(td)
		var mechs: Array = []
		for mech in st.get("mechanics", []):
			mechs.append({"name": String(mech.get("name", "")), "tell": String(mech.get("tell", "")), "counter": String(mech.get("counter", ""))})
		var rec := {
			"kind": String(kind), "name": String(st.get("name", kind)), "level": int(st.get("level", 1)),
			"hp": int(live["hp"]), "dmg": int(live["dmg"]), "spd": int(st.get("speed", 0)),
			"xp": int(live.get("xp", 0)), "gold": int(live.get("gold", 0)),
			"eva": float(live.get("eva", 0.0)), "ranged": bool(st.get("ranged", false)),
			"hp_g": float(st.get("hp_g", 0.1)), "dmg_g": float(st.get("dmg_g", 0.1)),
			"traits": traits, "mechanics": mechs, "chapter": String(chapter_of.get(kind, "")),
			"lore_need": Lore.threshold(String(kind)), "lore": Lore.entry(String(kind)),
			"sprite": String(st.get("sprite", "")),
		}
		if is_boss:
			bosses.append(rec)
		else:
			monsters.append(rec)
	out["monsters"] = monsters
	out["bosses"] = bosses

	# NPCs — same walk as codex._npcs.
	var seen := {}
	var npcs: Array = []
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			for npc in zone.get("npcs", []):
				if npc.get("placeholder", false):
					continue
				var spr := String(npc.get("sprite", ""))
				if spr == "" or seen.has(spr):
					continue
				var nm := UICodex._npc_name(npc)
				if nm == "" or nm == "Narrator":
					continue
				var quest := UICodex._gives_quest(String(npc.get("convo", "")))
				seen[spr] = true
				npcs.append({"name": nm, "sprite": spr, "role": UICodex._npc_role(spr, quest),
					"chapter": String(chid), "zone": String(zone.get("name", ""))})
	out["npcs"] = npcs

	# Terrains.
	var terrains: Array = []
	for id in Terrains.catalog_ids(false):
		var t: Dictionary = Terrains.DATA[id]
		var quirks: Array = []
		for p in t.get("patches", []):
			quirks.append(String(UICodex.PATCH_DESC.get(p["type"], "")))
		if t.get("event", "") != "":
			quirks.append(String(UICodex.EVENT_DESC.get(t["event"], "")))
		if t.get("mp_boost", false):
			quirks.append("Latent magic — your mana recovers much faster here")
		if t.has("river"):
			quirks.append("Rivers cross these lands — wading leaves you DAMP")
		var fi: Dictionary = found_in.get(id, {})
		terrains.append({"id": String(id), "name": String(t["name"]),
			"weather": String(UICodex.AMBIENT_DESC.get(t.get("ambient", ""), "still air")),
			"hazards": quirks, "zone": String(fi.get("zone", "")), "chapter": String(fi.get("chapter", ""))})
	out["terrains"] = terrains

	# Curios (quest items only — potions/relics have their own shelves in _curios).
	var curios: Array = []
	var qids: Array = Story.ALL_QUEST_ITEMS.keys()
	qids.sort()
	for qid in qids:
		var q: Dictionary = Story.ALL_QUEST_ITEMS[qid]
		if q.get("placeholder", false):
			continue
		curios.append({"id": String(qid), "name": String(q.get("name", qid)), "desc": String(q.get("desc", ""))})
	out["curios"] = curios

	# Gear: shapes per slot/class + uniques.
	var shapes: Array = []
	for slot in Items.SLOTS:
		var sl := String(slot)
		if sl == "weapon":
			for cls in Classes.CLASSES:
				for noun in Items.CLASS_WEAPONS.get(cls, []):
					shapes.append({"slot": sl, "name": String(noun), "cls": String(cls),
						"tag": String(Items.SHAPE_STYLE.get(noun, {}).get("tag", ""))})
		elif not Items.CLASS_GEAR.get("warrior", {}).get(sl, []).is_empty():
			for cls in Classes.CLASSES:
				for noun in Items.CLASS_GEAR.get(cls, {}).get(sl, []):
					shapes.append({"slot": sl, "name": String(noun), "cls": String(cls),
						"tag": String(Items.SHAPE_STYLE.get(noun, {}).get("tag", ""))})
		else:
			for noun in Items.SLOT_NAMES[sl]:
				shapes.append({"slot": sl, "name": String(noun), "cls": "",
					"tag": String(Items.SHAPE_STYLE.get(noun, {}).get("tag", ""))})
	out["shapes"] = shapes
	var uniques: Array = []
	for u in Items.UNIQUES:
		uniques.append({"name": String(u["name"]), "cls": String(u["cls"]), "slot": String(u["slot"]),
			"noun": String(u["noun"]), "grade": String(u["grade"]), "art": String(u.get("art", "")),
			"passive": String(u["passive"]),
			"passive_text": String(Items.PASSIVES.get(String(u.get("passive", "")), "")),
			"flavor": GearFlavor.of(u)})
	out["uniques"] = uniques
	var passives_seen := {}
	for u in uniques:
		passives_seen[u["passive"]] = true
	out["classes"] = Classes.CLASSES.keys()

	# Gems.
	var gems: Array = []
	for stat in Items.GEM_STATS:
		var g: Dictionary = Items.GEM_STATS[stat]
		gems.append({"stat": String(stat), "name": String(g["name"]), "color": (g["color"] as Color).to_html(false),
			"special": String(stat) in Balance.SPECIAL_GEM_STATS})
	out["gems"] = gems

	# Achievements + tracks.
	var achs: Array = []
	for id in Achievements.ORDER:
		var a: Dictionary = Achievements.DATA.get(id, {})
		achs.append({"id": String(id), "name": String(a.get("name", id)), "desc": String(a.get("desc", ""))})
	out["achievements"] = achs
	var tracks: Array = []
	for tid in Achievements.TRACKS:
		var tr: Dictionary = Achievements.TRACKS[tid]
		tracks.append({"id": String(tid), "name": String(tr["name"]), "how": String(tr["how"]), "tiers": tr["tiers"]})
	out["tracks"] = tracks

	var args := OS.get_cmdline_user_args()
	var path := "user://codex_dump.json" if args.is_empty() else String(args[0])

	# Icons: the exact textures the codex draws, saved as PNG beside the JSON
	# (a mock built on real sprites is a mock the owner can judge).
	var icon_dir := path.get_base_dir().path_join("codex_icons")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(icon_dir))
	var icon_count := 0
	for rec in monsters + bosses:
		var tex := UICodex._enemy_icon(String(rec["sprite"]))
		if tex != null:
			tex.get_image().save_png(icon_dir.path_join("enemy_%s.png" % rec["kind"]))
			icon_count += 1
	for rec in npcs:
		var t2 := Art.tex(String(rec["sprite"]))
		if t2 != null:
			var im: Image = t2.get_image()
			# Frame 0 of a strip: crop to the first square if the sheet is wider than tall.
			if im.get_width() > im.get_height():
				im = im.get_region(Rect2i(0, 0, im.get_height(), im.get_height()))
			im.save_png(icon_dir.path_join("npc_%s.png" % rec["sprite"]))
			icon_count += 1
	for u in Items.UNIQUES:
		if String(u["slot"]) != "weapon":
			continue
		var t3 := Art.codex_item_icon(String(u["slot"]), String(u["grade"]), String(u["noun"]), String(u.get("art", "")))
		if t3 != null:
			t3.get_image().save_png(icon_dir.path_join("unique_%s.png" % String(u.get("art", ""))))
			icon_count += 1
	for cls in Classes.CLASSES:
		for noun in Items.CLASS_WEAPONS.get(cls, []):
			for g in Items.GRADES:
				var t4 := Art.codex_item_icon("weapon", String(g), String(noun))
				if t4 != null:
					t4.get_image().save_png(icon_dir.path_join("shape_weapon_%s_%s.png" % [String(noun).to_lower().replace(" ", "_"), String(g)]))
					icon_count += 1
	for stat in Items.GEM_STATS:
		for lv in [1, 4, 7, 10]:
			var t5 := Art.gem_icon(Items.GEM_STATS[stat]["color"], lv)
			t5.get_image().save_png(icon_dir.path_join("gem_%s_lv%d.png" % [String(stat), lv]))
			icon_count += 1
	print("ICONS -> ", ProjectSettings.globalize_path(icon_dir), " count=", icon_count)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("CODEX DUMP -> ", ProjectSettings.globalize_path(path),
		"  monsters=%d bosses=%d npcs=%d terrains=%d curios=%d shapes=%d uniques=%d" % [
		monsters.size(), bosses.size(), npcs.size(), terrains.size(), curios.size(), shapes.size(), uniques.size()])
	quit(0)
