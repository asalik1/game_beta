extends SceneTree
## ASSET-GALLERY DUMP (dev tool) — the ENGINE half of `tools/art/asset_gallery.py`.
##
## Walks every data table the game actually renders from (classes, skins,
## enemies, terrains, zones, items, abilities, consumables, gems, FX) and
## writes ONE json describing every WIRED visual asset: its category, the
## key art.gd resolves, how many rooms reference it, and where its pixels
## come from. Procedural art (item icons, gems, ground tiles, ASCII-grid
## sprites, FX textures) has no file on disk, so those are RENDERED here
## through the real Art path and saved as PNGs; file-backed art is only
## POINTED AT, so the gallery always shows the live asset.
##
## The python driver owns file-family assembly (strips, 8-dir sets),
## image metrics, orphan detection, ratings and the HTML.
##
## Run (the driver does this for you):
##   godot --headless --path game --script res://asset_dump.gd -- <out_dir>

const DIR8 := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

# Names tex() builds procedurally through a match arm rather than a
# SPRITES grid — safe to render, invisible to Art.SPRITES.has().
const PROC_SPECIAL := [
	"slash", "shadow", "glow", "slashline", "lootbeam", "dangerrim", "ring",
	"vignette", "light", "white", "reticle", "telegraph", "bubble",
	"tree_green", "tree_autumn", "tree_teal", "tree_snow", "tree_spore",
	"bag", "book", "mail", "skills", "settings", "stash", "crosshair",
]

# FX/util textures wired by string literal in combat, projectile and HUD
# code rather than by any data table (art.gd resolves them all through
# tex(), so they belong in the gallery like everything else).
const FX_KEYS := [
	"slash", "slashline", "glow", "ring", "shadow", "lootbeam", "dangerrim",
	"vignette", "light", "reticle", "telegraph", "bubble", "white",
]

var out_dir := ""
var img_dir := ""
var records: Array = []
var by_id: Dictionary = {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else \
		ProjectSettings.globalize_path("user://asset_gallery")
	img_dir = out_dir + "/img"
	DirAccess.make_dir_recursive_absolute(img_dir)

	Story.load_content()

	_walk_classes()
	_walk_skins()
	_walk_enemies()
	_walk_world()
	_walk_wanderers()
	_walk_speakers()
	_walk_terrains()
	_walk_items()
	_walk_quest_items()
	_walk_abilities()
	_walk_projectiles()
	_walk_fx()
	_walk_ui()

	var payload := {
		"generated_by": "game/asset_dump.gd",
		"engine": Engine.get_version_info().get("string", ""),
		"count": records.size(),
		"assets": records,
	}
	var f := FileAccess.open(out_dir + "/wired_assets.json", FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s/wired_assets.json" % out_dir)
		quit(1)
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	print("ASSET DUMP: %d wired assets -> %s" % [records.size(), out_dir])
	quit(0)


# ------------------------------------------------------------- record ---

## Add (or extend) one asset family. `key` is the name art.gd resolves;
## everything else is metadata the gallery groups and sorts by.
func _add(cat: String, key: String, label: String, extra: Dictionary = {}) -> void:
	if key == "":
		return
	var id := "%s/%s" % [cat, key]
	if by_id.has(id):
		var prev: Dictionary = by_id[id]
		prev["exposure"] = int(prev["exposure"]) + int(extra.get("exposure", 0))
		for u in extra.get("used_in", []):
			if not prev["used_in"].has(u) and prev["used_in"].size() < 24:
				prev["used_in"].append(u)
		return
	var rec := {
		"id": id,
		"category": cat,
		"key": key,
		"label": label,
		"source": "",
		"src": "",
		"exposure": int(extra.get("exposure", 0)),
		"used_in": extra.get("used_in", []),
		"meta": extra.get("meta", {}),
		"notes": String(extra.get("note", "")),
	}
	if Art.has_sprite(key):
		rec["source"] = "sprite"
		rec["src"] = "game/assets/sprites/%s.png" % key
	elif ResourceLoader.exists("res://assets/icons/%s.png" % key):
		rec["source"] = "icon"
		rec["src"] = "game/assets/icons/%s.png" % key
	elif Art.SPRITES.has(key) or PROC_SPECIAL.has(key):
		rec["source"] = "procedural"
		rec["src"] = _dump(key, Art.tex(key))
	else:
		rec["source"] = "missing"
	records.append(rec)
	by_id[id] = rec


## Same, but the caller supplies the rendered texture (item icons, gems,
## ground tiles — art with no name art.gd could resolve on its own).
func _add_rendered(cat: String, key: String, label: String, tex: Texture2D,
		extra: Dictionary = {}) -> void:
	var id := "%s/%s" % [cat, key]
	if by_id.has(id):
		return
	var rec := {
		"id": id,
		"category": cat,
		"key": key,
		"label": label,
		"source": "rendered",
		"src": _dump(key, tex),
		"exposure": int(extra.get("exposure", 0)),
		"used_in": extra.get("used_in", []),
		"meta": extra.get("meta", {}),
		"notes": String(extra.get("note", "")),
	}
	if rec["src"] == "":
		rec["source"] = String(extra.get("source", "missing"))
	records.append(rec)
	by_id[id] = rec


## Save a texture into the gallery's img/ folder; returns the path the
## HTML should reference (relative to the gallery dir), "" on failure.
func _dump(key: String, tex: Texture2D) -> String:
	if tex == null:
		return ""
	var im := tex.get_image()
	if im == null or im.get_width() == 0:
		return ""
	var safe := key.replace("/", "__").replace(":", "_")
	var path := "%s/%s.png" % [img_dir, safe]
	if im.is_compressed():
		im = im.duplicate()
		im.decompress()
	if im.save_png(path) != OK:
		return ""
	return "img/%s.png" % safe


# -------------------------------------------------------- categories ---

func _walk_classes() -> void:
	for cls_key in Classes.CLASSES:
		var cls := String(cls_key)
		var c: Dictionary = Classes.CLASSES[cls]
		var sprite := String(c.get("sprite", cls))
		var clips: Dictionary = Art.hero_clips(sprite)
		var poses: Dictionary = Art.hero_dir_clips(sprite)
		_add("classes", sprite, String(c.get("name", cls)), {
			"exposure": 100,  # a playable class is on screen the whole run
			"used_in": ["playable class"],
			"meta": {
				"clips": clips.keys(),
				"dir_poses": poses.keys(),
				"primary": String(c.get("primary", "")),
				"dmg_type": String(c.get("dmg_type", "")),
			},
		})
		var splash := "class_splash_" + cls
		if Art.has_sprite(splash):
			_add("splash", splash, "%s — class splash" % c.get("name", cls),
				{"exposure": 12, "used_in": ["dialogue splash", "class select"]})


func _walk_skins() -> void:
	for cls_key in Skins.SKINS:
		var cls := String(cls_key)
		for entry in Skins.SKINS[cls]:
			var e: Dictionary = entry
			var tier := String(e.get("tier", "elite"))
			var base := String(e.get("sprite", ""))
			_add("skins", base, "%s (%s %s)" % [e.get("name", ""), cls, tier], {
				"exposure": 8,
				"used_in": ["wardrobe: " + cls],
				"meta": {"tier": tier, "class": cls, "skin_id": String(e.get("id", "")),
					"clips": Art.hero_clips(base).keys()},
			})
			if e.has("awakened_sprite"):
				var awk := String(e["awakened_sprite"])
				_add("skins", awk, "%s — Awakened (%s)" % [e.get("name", ""), cls], {
					"exposure": 4,
					"used_in": ["wardrobe: %s (awakened)" % cls],
					"meta": {"tier": tier, "class": cls, "awakened": true,
						"clips": Art.hero_clips(awk).keys()},
				})
			# Skin splash art (dialogue portrait when this skin is worn).
			for awake in [false, true]:
				var sp := Skins.skin_splash(cls, String(e.get("id", "")), awake)
				if sp != "" and Art.has_sprite(sp):
					_add("splash", sp, "%s splash%s" % [e.get("name", ""),
						" (awakened)" if awake else ""],
						{"exposure": 6, "used_in": ["dialogue splash"]})
		# Chroma recolors carry no art of their own — record the palette so
		# the gallery can still show (and rate) the colorway.
		for chroma in Skins.CHROMAS.get(cls, []):
			var ch: Dictionary = chroma
			_add_rendered("chromas", "chroma_%s_%s" % [cls, ch.get("id", "")],
				"%s — %s" % [cls.capitalize(), ch.get("name", "")], null, {
					"source": "palette",
					"exposure": 2,
					"used_in": ["wardrobe: " + cls],
					"meta": {"class": cls, "swatch": [
						ch["primary"].to_html(false), ch["trim"].to_html(false),
						ch["accent"].to_html(false)]},
				})


func _walk_enemies() -> void:
	for kind in Story.ALL_ENEMIES:
		var e: Dictionary = Story.ALL_ENEMIES[kind]
		var sprite := String(e.get("sprite", kind))
		var boss := bool(e.get("boss", false))
		var actions: Array = []
		for act in ["ability", "cast", "attack", "slam", "stab", "hit", "throne"]:
			if not Art.action_info(sprite, act).is_empty():
				actions.append(act)
		var anim: Dictionary = Art.anim_info(sprite)
		_add("bosses" if boss else "mobs", sprite, String(e.get("name", kind)), {
			"meta": {
				"kind": kind,
				"level": int(e.get("level", 1)),
				"scale": float(e.get("scale", 3.0)),
				"ranged": bool(e.get("ranged", false)),
				"placeholder": bool(e.get("placeholder", false)),
				"anim_frames": int(anim.get("frames", 0)),
				"walk_frames": int(Art.walk_info(sprite).get("frames", 0)),
				"dirs": Art.dir_set(sprite + "_anim").size(),
				"actions": actions,
			},
		})
		# Boss dialogue portrait / intro splash.
		var sp := "splash_" + sprite
		if Art.has_sprite(sp):
			_add("splash", sp, "%s — splash" % e.get("name", kind),
				{"exposure": 3, "used_in": ["boss intro" if boss else "dialogue"]})
		# ...and the one its NAME resolves to when it speaks (the dialogue
		# seam matches on the speaker string, not the sprite key).
		var named := _resolve_splash(_splash_slug(String(e.get("name", kind))))
		if named != "":
			_add("splash", named, "%s — splash" % e.get("name", kind),
				{"exposure": 3, "used_in": ["boss intro" if boss else "dialogue"]})


## Every chapter's authored rooms: which enemy kinds spawn, which NPC
## bodies stand there, which landmarks/backdrops/furnishings are placed.
## Room count per asset is the EXPOSURE number the report ranks by.
func _walk_world() -> void:
	var chapters: Array = Story.CHAPTER_LIST.keys()
	chapters.append("capital")
	for aid in Story.ENDGAME_ARENAS:
		chapters.append(aid)
	for chid in chapters:
		var ch: Dictionary = Story.chapter(String(chid))
		var chname := String(ch.get("name", chid))
		var zones: Array = ch.get("zones", [])
		for zi in zones.size():
			var z: Dictionary = zones[zi]
			var where := "%s / %s" % [chname, z.get("name", "room %d" % zi)]
			for ed in z.get("enemies", []):
				var kind := String((ed as Array)[0])
				_bump_enemy(kind, where)
			var bkind := String(z.get("boss", ""))
			if bkind != "":
				_bump_enemy(bkind, where)
			for npc in z.get("npcs", []):
				var n: Dictionary = npc
				var nsprite := String(n.get("sprite", ""))
				if nsprite == "":
					continue
				_add("npcs", nsprite, nsprite.capitalize().replace("_", " "), {
					"exposure": 1, "used_in": [where],
					"meta": {"placeholder": bool(n.get("placeholder", false))},
				})
				var nsp := "splash_" + nsprite
				if Art.has_sprite(nsp):
					_add("splash", nsp, "%s — splash" % nsprite,
						{"exposure": 1, "used_in": [where]})
			for group in ["landmarks", "backdrops", "furnishings"]:
				for item in z.get(group, []):
					var it: Dictionary = item
					_add_structure(String(it.get("name", "")), where, group)
			for group2 in ["obstacles", "decor", "accents", "buildings", "structures"]:
				for pname in z.get(group2, []):
					_add("props", String(pname),
						String(pname).capitalize().replace("_", " "),
						{"exposure": 1, "used_in": [where],
						 "meta": {"placement": group2}})


## Social wanderers: rolled per run, so they never appear in a zone's
## authored npc list — but their bodies are as shipped as any other NPC.
func _walk_wanderers() -> void:
	var pools: Array = [{"id": "ch1 (shared road pool)", "list": Story.WANDERERS}]
	for chid_key in Story.ALL_WANDERERS:
		pools.append({"id": String(chid_key), "list": Story.ALL_WANDERERS[chid_key]})
	for pool in pools:
		var p: Dictionary = pool
		for w in p["list"]:
			var wd: Dictionary = w
			var sprite := String(wd.get("sprite", ""))
			if sprite == "":
				continue
			_add("npcs", sprite, sprite.capitalize().replace("_", " "), {
				"exposure": 2, "used_in": ["wanderer: " + String(p["id"])],
				"meta": {"wanderer": true, "convo": String(wd.get("convo", ""))},
			})
			if Art.has_sprite("splash_" + sprite):
				_add("splash", "splash_" + sprite, "%s — splash" % sprite,
					{"exposure": 2, "used_in": ["wanderer dialogue"]})


## Dialogue splash art resolves from the SPEAKER NAME (hud._splash_for):
## the name is slugged and matched against splash_<slug>.png, longest run
## first. Replaying that rule here is the only way to know which splash
## files are actually reachable and which speakers have no face.
func _walk_speakers() -> void:
	var speakers := {}
	for cid_key in Story.ALL_CONVOS:
		for line in Story.ALL_CONVOS[cid_key]:
			if not (line is Array) or (line as Array).is_empty():
				continue
			var who := String((line as Array)[0])
			if who == "" or who.to_lower() == "narrator":
				continue
			if not speakers.has(who):
				speakers[who] = String(cid_key)
	var matched := {}
	for who_key in speakers:
		var who := String(who_key)
		var key := _resolve_splash(_splash_slug(who))
		if key == "":
			continue
		matched[key] = who
		_add("splash", key, "%s — splash" % who, {
			"exposure": 1, "used_in": ["speaks in: " + String(speakers[who])],
			"meta": {"speaker": who},
		})
	# Splash art exists for exactly one seam, so every splash_*.png shipped is
	# part of the catalogue — including the ones whose speaker string lives in
	# a beat, a boss title or an alias rather than a convo line.
	for f_name in _list_png("res://assets/sprites"):
		var f := String(f_name)
		if not f.begins_with("splash_"):
			continue
		_add("splash", f, f.trim_prefix("splash_").replace("_", " "), {
			"exposure": 1 if matched.has(f) else 0,
			"used_in": ["speaker: " + String(matched[f])] if matched.has(f) else [],
			"meta": {"speaker_matched": matched.has(f)},
			"note": "" if matched.has(f)
				else "no convo speaker resolves to this name — check the seam",
		})


## Speaker name -> filename slug (mirror of hud.gd _splash_slug).
func _splash_slug(s: String) -> String:
	var out := ""
	var prev_us := true
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
			prev_us = false
		elif not prev_us:
			out += "_"
			prev_us = true
	return out.trim_suffix("_")


## Longest-run splash lookup (mirror of hud.gd _resolve_splash).
func _resolve_splash(slug: String) -> String:
	if slug == "":
		return ""
	if Art.has_sprite("splash_" + slug):
		return "splash_" + slug
	var words := slug.split("_", false)
	for span in range(words.size() - 1, 0, -1):
		for start in range(0, words.size() - span + 1):
			var cand: String = "_".join(words.slice(start, start + span))
			if Art.has_sprite("splash_" + cand):
				return "splash_" + cand
	return ""


## Quest items and curios: bag icons + notable world props (codex Curios).
## Most are `placeholder` — art mined ahead of a home, dev-launcher only.
func _walk_quest_items() -> void:
	for qid_key in Story.ALL_QUEST_ITEMS:
		var q: Dictionary = Story.ALL_QUEST_ITEMS[qid_key]
		var icon := String(q.get("icon", ""))
		if icon == "":
			continue
		_add("quest_items", icon, String(q.get("name", qid_key)), {
			"exposure": 1, "used_in": ["quest item: " + String(qid_key)],
			"meta": {"grade": String(q.get("grade", "")),
				"placeholder": bool(q.get("placeholder", false))},
		})
	for rid_key in Story.ALL_RELICS:
		var r: Dictionary = Story.ALL_RELICS[rid_key]
		var sprite := String(r.get("sprite", ""))
		if sprite == "":
			continue
		_add("props", sprite, String(r.get("name", rid_key)), {
			"exposure": 1, "used_in": ["curio: " + String(rid_key)],
			"meta": {"relic": true, "group": String(r.get("group", "")),
				"placeholder": bool(r.get("placeholder", false))},
		})


## Every projectile body the combat code can spawn (player kits, mob shots,
## boss signature bolts). Style ids without art of their own are skipped —
## those draw as the shared glow/spark package, not a sprite.
func _walk_projectiles() -> void:
	var wanted := {}
	for k in Projectile.BOSS_PROJECTILE_STYLE:
		wanted[String(k)] = "boss signature shot"
	for k in Projectile.MOB_PROJECTILE_STYLE:
		wanted[String(k)] = "mob shot"
	for v in Projectile.ENEMY_PROJECTILE_ART.values():
		wanted[String(v)] = "enemy shot"
	for k in Projectile.GLOWS:
		if not wanted.has(String(k)):
			wanted[String(k)] = "projectile"
	for extra in ["arrow_base", "arrow_frost", "arrow_void", "arrow_void_eye",
			"knife", "shuriken", "dart", "choir_censer", "mage_firebolt",
			"mage_void_bullet", "mage_crystal_decree", "warlock_shadowbolt",
			"hellfire_brand_bolt"]:
		if not wanted.has(String(extra)):
			wanted[String(extra)] = "player projectile"
	for key_name in wanted:
		var key := String(key_name)
		if not (Art.has_sprite(key) or Art.SPRITES.has(key)):
			continue  # a style id, not an art key — drawn as glow + sparks
		_add("projectiles", key, key.replace("_", " "), {
			"exposure": 6, "used_in": [String(wanted[key])],
		})


func _bump_enemy(kind: String, where: String) -> void:
	var e: Dictionary = Story.ALL_ENEMIES.get(kind, {})
	if e.is_empty():
		return
	var sprite := String(e.get("sprite", kind))
	var cat := "bosses" if bool(e.get("boss", false)) else "mobs"
	_add(cat, sprite, String(e.get("name", kind)),
		{"exposure": 1, "used_in": [where]})


func _walk_terrains() -> void:
	for tid_key in Terrains.DATA:
		var tid := String(tid_key)
		var t: Dictionary = Terrains.DATA[tid]
		var ground := String(t.get("ground", "grass"))
		var path_kind := String(t.get("path", "dirt"))
		# The real room floor: 8x6 tiles through the live generator.
		var tex: ImageTexture = Art.ground(ground, path_kind, 8, 6, 1337, ["W", "E"])
		_add_rendered("terrains", "terrain_" + tid, String(t.get("name", tid)), tex, {
			"exposure": 1,
			"used_in": ["terrain: " + tid],
			"meta": {
				"ground": ground, "path": path_kind,
				"tint": (t.get("tint", Color.WHITE) as Color).to_html(false),
				"wall": Terrains.wall_for(tid),
				"music": String(t.get("music", "")),
				"ambient": String(t.get("ambient", "")),
				"event": String(t.get("event", "")),
				"placeholder": tid.begins_with("ph_"),
			},
		})
		# Wall tile for this biome (the most-repeated pixels in a room).
		_add("walls", Terrains.wall_for(tid), Terrains.wall_for(tid).capitalize().replace("_", " "),
			{"exposure": 1, "used_in": ["terrain: " + tid]})
		# ph_* terrains are mined-ahead placeholders, not shipped play — their
		# prop lists name art that may not exist yet, and that is by design.
		var ph := tid.begins_with("ph_")
		for group in ["obstacles", "decor", "accents", "buildings"]:
			for pname in t.get(group, []):
				_add("props", String(pname),
					String(pname).capitalize().replace("_", " "),
					{"exposure": 1, "used_in": ["terrain: " + tid],
					 "meta": {"placement": group, "placeholder_terrain": ph}})
		for sname2 in t.get("structures", []):
			_add_structure(String(sname2), "terrain: " + tid, "structures")
	# Ground TILESETS: a ground_<kind>.png override replaces the procedural
	# palette fill for every room painted with that floor.
	for gkind_key in Art.GROUND:
		var gkind := String(gkind_key)
		var users: Array = []
		for tid2_key in Terrains.DATA:
			var t2: Dictionary = Terrains.DATA[tid2_key]
			if String(t2.get("ground", "")) == gkind or String(t2.get("path", "")) == gkind:
				users.append(String(t2.get("name", tid2_key)))
		# A ground_<kind>.png override replaces the palette fill; without one
		# the tileset is generated. Either way, render what a floor of this
		# kind actually looks like.
		_add_rendered("terrains", "ground_" + gkind, "Ground tiles — %s" % gkind,
			Art.ground(gkind, gkind, 4, 3, 4242, []), {
				"exposure": users.size(), "used_in": users,
				"meta": {"kind": gkind, "hand_art": Art.has_sprite("ground_" + gkind)},
			})
	# Structures the terrain layer can place (colliders authored per name).
	for sname in Terrains.STRUCTURES:
		_add_structure(String(sname), "", "structure_def")


## A structure is a NAME, not an art key: Terrains.STRUCTURES remaps it to a
## sprite and hangs extra part/decal art off it (great_hearth ->
## capital_great_hearth + its parts). Record what actually draws.
func _add_structure(sname: String, where: String, group: String) -> void:
	if sname == "":
		return
	var def: Dictionary = Terrains.STRUCTURES.get(sname, {})
	var art := String(def.get("sprite", sname))
	var used: Array = [where] if where != "" else []
	_add("structures", art, sname.capitalize().replace("_", " "), {
		"exposure": 1 if where != "" else 0, "used_in": used,
		"meta": {"placement": group, "structure": sname,
			"parts": def.get("parts", []).size(),
			"decals": def.get("decals", []).size()},
	})
	for sub_group in ["parts", "decals"]:
		for piece in def.get(sub_group, []):
			var pd: Dictionary = piece
			_add("props", String(pd.get("sprite", "")),
				String(pd.get("sprite", "")).capitalize().replace("_", " "),
				{"exposure": 1 if where != "" else 0, "used_in": used,
				 "meta": {"placement": "%s of %s" % [sub_group, sname]}})


func _walk_items() -> void:
	# Gear icons: one card per SHAPE, with the full F..S grade ladder as
	# frames (the grade treatment is the art, not a separate asset).
	for slot_key in Art.GEAR_SHAPES:
		var slot := String(slot_key)
		var shapes: Dictionary = Art.GEAR_SHAPES[slot]
		for noun_key in shapes:
			var noun := String(noun_key)
			# Keyed by the SHAPE, not a synthetic id, so the shipped
			# w_blade.png / icon_armor.png family attaches to this card.
			var shape := String(shapes[noun])
			var id := shape
			if by_id.has("gear/" + id):
				continue
			var ladder: Array = []
			for grade_key in Items.GRADES:
				var grade := String(grade_key)
				var gtex: ImageTexture = Art.item_icon(slot, grade, noun)
				var p := _dump("%s_%s" % [id, grade], gtex)
				if p != "":
					ladder.append({"label": grade, "src": p})
			_add_rendered("gear", id, "%s (%s)" % [noun, slot],
				Art.item_icon(slot, "B", noun), {
					"exposure": 7,
					"used_in": ["bag / shop / ground drop"],
					"meta": {"slot": slot, "noun": noun,
						"shape": shape, "ladder": ladder},
				})
	# Held weapon sprites (drawn in the hero's hand, grade-tinted).
	for wnoun_key in Art.GEAR_SHAPES["weapon"]:
		var wnoun := String(wnoun_key)
		var wshape := String(Art.GEAR_SHAPES["weapon"][wnoun])
		_add_rendered("gear", "held_%s" % wshape, "%s — held" % wnoun,
			Art.weapon_tex(wnoun, "B"),
			{"exposure": 5, "used_in": ["equipped weapon"],
			 "meta": {"shape": wshape}})
	# Consumables.
	for cid_key in Art.CONSUMABLE_ICONS:
		var cid := String(cid_key)
		var icon_name := String(Art.CONSUMABLE_ICONS[cid])
		var ctex: ImageTexture = Art.consumable_icon({"id": cid})
		_add("consumables", icon_name, cid.capitalize().replace("_", " "), {
			"exposure": 3, "used_in": ["bag / shop / ground drop"],
			"meta": {"consumable_id": cid, "wired": ctex != null},
			"note": "" if ctex != null else "WIRED BUT NO ART — falls back to the glyph",
		})
	_add("consumables", "potion", "Health potion",
		{"exposure": 10, "used_in": ["HUD potion button", "ground drop"]})
	# Legacy neutral cut ladder plus every lore-authored stat+level family.
	for lvl in range(1, Items.GEM_MAX_LEVEL + 1):
		_add_rendered("gems", "gem_lv%d" % lvl, "Gem cut — Lv%d" % lvl,
			Art.gem_icon(Color(0.85, 0.85, 0.95), lvl),
			{"exposure": 2, "used_in": ["bag / socket UI"],
			 "meta": {"level": lvl}})
	for stat_key in Items.GEM_STATS:
		var stat := String(stat_key)
		var gs: Dictionary = Items.GEM_STATS[stat]
		var col: Color = gs.get("color", Color.WHITE)
		for lvl in range(1, Items.GEM_MAX_LEVEL + 1):
			_add_rendered("gems", "gem_%s_lv%d" % [stat, lvl],
				"%s — Lv%d" % [gs.get("name", stat), lvl],
				Art.gem_icon(col, lvl),
				{"exposure": 2, "used_in": ["bag / socket UI / ground drop"],
				 "meta": {"stat": stat, "level": lvl, "color": col.to_html(false)}})
	# Chests.
	for tier_key in Items.CHEST_TIERS:
		var tier := String(tier_key)
		var ct: Dictionary = Items.CHEST_TIERS[tier]
		_add("chests", String(ct.get("sprite", "")),
			"%s chest" % tier.capitalize(),
			{"exposure": 4, "used_in": ["room cache / boss reward"],
			 "meta": {"tier": tier}})
	for cgrade_key in Items.GRADES:
		var cgrade := String(cgrade_key)
		_add("chests", "chest_" + cgrade.to_lower(), "Chest — grade %s" % cgrade,
			{"exposure": 2, "used_in": ["loot chest (grade %s)" % cgrade]})
	_add("props", "coin", "Coin pickup",
		{"exposure": 20, "used_in": ["every gold drop"]})


func _walk_abilities() -> void:
	for cls_key in Classes.CLASSES:
		var cls := String(cls_key)
		for slot_name in ["a1", "a2", "a3", "ult"]:
			var slot := String(slot_name)
			var base := "ability_%s_%s" % [cls, slot]
			var has_art := Art.has_ability_art(cls, slot)
			_add_rendered("abilities", base,
				"%s — %s" % [cls.capitalize(), slot.to_upper()],
				Art.ability_icon(cls, slot), {
					"exposure": 30,
					"used_in": ["ability bar", "skill menu"],
					"meta": {"class": cls, "slot": slot,
						"hand_art": has_art,
						"glyph": String(Art.ABILITY_GLYPH[cls][slot])},
					"note": "" if has_art else "procedural glyph — no painted icon installed",
				})
			for theme in Classes.THEMES.get(cls, []):
				var th: Dictionary = theme
				var tid := String(th.get("id", ""))
				if not Art.has_ability_art(cls, slot, tid):
					continue
				_add_rendered("abilities", "%s_%s" % [base, tid],
					"%s — %s (%s)" % [cls.capitalize(), slot.to_upper(),
						th.get("name", tid)],
					Art.ability_art(cls, slot, tid), {
						"exposure": 8,
						"used_in": ["ability bar (theme)"],
						"meta": {"class": cls, "slot": slot, "theme": tid},
					})
	# Procedural UI glyph stencils (the fallback art for every icon seam).
	for gname_key in Art.GLYPHS:
		var gname := String(gname_key)
		_add_rendered("glyphs", gname, gname.replace("_", " "),
			Art.glyph_tex(gname),
			{"exposure": 1, "used_in": ["icon fallback"]})


func _walk_fx() -> void:
	for key_name in FX_KEYS:
		var key := String(key_name)
		_add("fx", key, key.capitalize().replace("_", " "),
			{"exposure": 15, "used_in": ["combat FX"]})
	# Everything shipped under assets/sprites/fx/.
	for f_name in _list_png("res://assets/sprites/fx"):
		var f := String(f_name)
		_add("fx", "fx/" + f, f.replace("_", " "),
			{"exposure": 5, "used_in": ["combat FX"]})


func _walk_ui() -> void:
	for key_name in ["bag", "book", "mail", "skills", "settings", "stash", "crosshair"]:
		var key := String(key_name)
		_add("ui", key, key.capitalize(),
			{"exposure": 40, "used_in": ["HUD button"]})
	_add_rendered("ui", "ability_glow", "Ability slot glow", Art.ability_glow(),
		{"exposure": 30, "used_in": ["ability bar"]})
	_add_rendered("ui", "ability_cooldown_mask", "Cooldown sweep mask",
		Art.ability_cooldown_mask(),
		{"exposure": 30, "used_in": ["ability bar"]})
	# Title-screen covers (scripts/ui/cover.gd rotates cover.png, cover_2..N).
	for i in range(1, 9):
		var ckey := "cover" if i == 1 else "cover_%d" % i
		if Art.has_sprite(ckey):
			_add("splash", ckey, "Title cover %d" % i,
				{"exposure": 5, "used_in": ["title screen"]})
	_add("gems", "gem", "Gem — shared base icon",
		{"exposure": 3, "used_in": ["ground drop", "socket UI"]})
	# Every procedural grid art.gd can draw. Ones no data table references are
	# still shipped art (and worth knowing about) — exposure says which.
	for gkey_name in Art.SPRITES:
		var gkey := String(gkey_name)
		if by_id.has("props/" + gkey):
			continue
		var claimed := false
		for cat in ["mobs", "bosses", "npcs", "structures", "walls", "fx",
				"projectiles", "chests", "ui", "gear", "classes"]:
			if by_id.has("%s/%s" % [cat, gkey]):
				claimed = true
				break
		if claimed:
			continue
		_add("props", gkey, gkey.capitalize().replace("_", " "), {
			"exposure": 0, "used_in": [],
			"meta": {"grid_only": true},
			"note": "procedural grid in art.gd that no data table references",
		})


## Base names (no extension) of the PNGs in a folder.
func _list_png(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(f.trim_suffix(".png"))
		elif f.ends_with(".png.import"):
			var b := f.trim_suffix(".png.import")
			if not out.has(b):
				out.append(b)
	return out
