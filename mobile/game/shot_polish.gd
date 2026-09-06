extends ShotRig
## GAMEPLAY-POLISH review rig (2026-08-18). Frames the exact things the polish
## pass changed — floor feature scale, edged roads, wall faces + floor shadows,
## contact shadows, light pools, hit numbers / HP bars / reticle, HUD text —
## in the rooms the trailer footage was shot in, at the trailer zoom (1.4) and
## native (1.0). Never touches shots/cine (own dir: user://shots/polish).
##   shot.bat polish [--rooms=2,17,20] [--zoom=1.4] [--class=warrior] [--hud] [--timeout=180]
## Per room: "<room>_room" (hero mid-room with a wolf pack, three hits landed so
## numbers/bars/flash are live), "<room>_wall" (hero at the north wall: face,
## shadow, road arm, door torches). --hud adds a HUD-on shot per room.
##
## --gif: MOTION review instead of stills. Records frame SERIES (one PNG per
## engine frame) into user://shots/polish/gif_<beat>/ for a fixed set of beats
## — forest fight, keep fight, HUD fight, road walk, magma walk — with the
## packs LIVE and the hero driven through the real input path (injected WASD)
## + use_ability. Run it under `--fixed-fps 30` so the sim steps 1/30 s per
## frame no matter how long a PNG save takes (deterministic, smooth):
##   godot --audio-driver Dummy --fixed-fps 30 --path game res://shot_polish.tscn -- --gif [--class=mage] [--timeout=600]
## then tools/art/gif_from_frames.py stitches each folder into a GIF.
##
## --tour: the round-3 FLAG rooms as stills, any chapter, rooms by NAME:
##   shot.bat polish --tour --chapter=ch2 --names=the_greyrun_mills,the_sporewood [--zoom=1.0] [--gif]
## per room: "<slug>_centre" (the room as the player sees it: mill, pools,
## props), "<slug>_ndoor" (standing under the NORTH door: torch pair + inset —
## the "only stems" flag), "<slug>_west". --gif adds a 2.5 s frame series at
## the centre so prop loops (pools, furnaces, torches) can be watched at 1x.

var _mobs: Array = []
const GIF_FPS := 30
var _gif_dir := ""
var _gif_n := 0


func _ready() -> void:
	var cls := arg("class", "warrior")
	await boot(cls, arg("chapter", "ch1"))
	game.camera.position_smoothing_enabled = false
	game.npc_emote_t = 1.0e9
	hide_hud()   # --hud adds a HUD-on frame per room; the rest stay clean
	var z := float(arg("zoom", "1.4"))
	zoom(z)
	await sim_wait(1.5)   # title card clears
	if arg("menu", "") != "":
		# --menu=stats|bag|class: one shot of a menu screen (review pack, P7.E/F/G)
		game.hud.visible = true
		match arg("menu", ""):
			"stats": game.menus.open_inventory("stats")
			"bag": game.menus.open_inventory("gear")
			"class": game.menus.open_class_select()
			"title": game.menus.open_title()
			"roster": game.menus.open_slots()
			"skills": game.menus.open_skills()
			"pause": game.menus.open_pause()
			"shop": game.menus.open_shop(0)
			"codex": game.menus.open_codex("monsters")
			"map": game.menus.open_map()
			"settings": game.menus.open_settings()
			"wardrobe": game.menus.open_wardrobe()
			"professions": game.menus.open_professions()
		await sim_wait(1.2)
		shot("menu_" + arg("menu", ""), "menu " + arg("menu", ""))
		if arg("menu", "") == "class":
			game.menus._cs_preview(cls)   # the shots review the BOOTED class's stage
			await sim_wait(0.4)
			# hover the third ability card: the stage plays its clip
			game.menus._cs_show_ability(game.menus._cs_id, "ult")
			await sim_wait(0.35)
			shot("menu_class_ult", "ult clip on the stage")
			game.menus._cs_show_ability(game.menus._cs_id, "a1")
			await sim_wait(0.3)
			shot("menu_class_a1", "a1 (swing) clip on the stage — same body size as idle")
			game.menus._cs_set_mode("splash")
			await sim_wait(0.2)
			shot("menu_class_splash", "splash mode: the painting, head in frame")
		finish()
		return
	if flag("capital"):
		# The Wayfinder Sanctum's endgame gates: SEALED (fresh hero) vs OPEN
		# (chapter 7 cleared) — the owner's locked-state ruling made visible.
		game.enter_capital()
		await frames(10)
		await skip_dialogue()
		var wf := _room_by_name("wayfinder_sanctum")
		if wf >= 0:
			game.fast_travel(wf)
			await sim_wait(1.2)
			game.player.global_position = game.room_pos(wf, 1056, 800)
			game.camera.global_position = game.room_pos(wf, 1056, 560)
			await sim_wait(0.4)
			shot("capital_gates_sealed", "crucible + depths sealed (fresh hero)")
			game.set_flag("completed_ch7")
			game.switch_chapter("capital", true)
			await frames(10)
			await skip_dialogue()
			game.fast_travel(wf)
			await sim_wait(1.2)
			game.player.global_position = game.room_pos(wf, 1056, 800)
			game.camera.global_position = game.room_pos(wf, 1056, 560)
			await sim_wait(0.4)
			shot("capital_gates_open", "all three gates live (ch7 cleared)")
		var em := _room_by_name("the_emberward_gate")
		if em >= 0:
			game.fast_travel(em)
			await sim_wait(1.2)
			game.player.global_position = game.room_pos(em, 1056, 820)
			game.camera.global_position = game.room_pos(em, 1056, 600)
			await sim_wait(0.4)
			shot("capital_emberward_muster", "the muster point (no duplicate leave door)")
		finish()
		return
	if flag("review"):
		# --review: the owner review pack's in-world beats in one run — a chest
		# opening mid-burst, the boss bar dressed, the announcement plaque + feed.
		await _review_shots()
		finish()
		return
	if flag("tour"):
		await _tour()
		finish()
		return
	if flag("gif"):
		await _gif_pass(cls)
		finish()
		return
	var rooms := arg("rooms", "2,17,20").split(",", false)
	for rs in rooms:
		var room := int(rs)
		step("room %d" % room)
		await _goto(room)
		var rr := game.room_rect(room)
		var p := game.player
		# --- mid-room: pack + hits ---
		p.global_position = rr.position + Vector2(rr.size.x * 0.55, rr.size.y * 0.52)
		game.camera.global_position = p.global_position
		await frames(2)
		_pack(["wolf", "beastkin_raider", "blightwolf", "skeleton", "spider"], p.global_position)
		await sim_wait(0.6)
		if not flag("calm"):   # --calm: the pack just STANDS (readability shots, no numbers)
			for i in 3:
				for m in _mobs:
					if is_instance_valid(m):
						m.take_damage(randf_range(9.0, 60.0), Vector2.RIGHT, i == 2 and m == _mobs[0])
				await sim_wait(0.18)
		await sim_wait(0.12)
		shot("%02d_room" % room, "room=%d zoom=%.2f" % [room, z])
		if flag("hud"):
			game.hud.visible = true
			await frames(2)
			shot("%02d_room_hud" % room, "hud on")
			game.hud.visible = false
		_clear()
		# --- north wall: face + shadow + road + door torches ---
		p.global_position = rr.position + Vector2(rr.size.x * 0.5, 190.0)
		game.camera.global_position = p.global_position
		await sim_wait(0.4)
		shot("%02d_wall" % room, "north wall")
		# --- west wall + a corner ---
		p.global_position = rr.position + Vector2(230.0, rr.size.y * 0.5)
		game.camera.global_position = p.global_position
		await sim_wait(0.4)
		shot("%02d_west" % room, "west wall")
	# A magma room for the lava light pools (paint the current room).
	step("magma")
	var mr := int(rooms[0])
	await _goto(mr)
	apply_terrain("magma", mr)
	await sim_wait(0.6)
	var p2 := game.player
	var rr2 := game.room_rect(mr)
	p2.global_position = rr2.position + Vector2(rr2.size.x * 0.5, rr2.size.y * 0.5)
	game.camera.global_position = p2.global_position
	await sim_wait(0.4)
	shot("magma_room", "lava pools + glow")
	finish()


## --review (2026-08-19): the in-world beats of the owner review pack.
func _review_shots() -> void:
	var i := 2
	await _goto(i)
	var rr := game.room_rect(i)
	var p := game.player
	p.global_position = rr.position + Vector2(rr.size.x * 0.5, rr.size.y * 0.55)
	game.camera.global_position = p.global_position
	game.hud.visible = true
	await sim_wait(0.3)
	# 1. a chest opening: drop a gold chest beside the hero, step onto it, shoot
	#    mid-burst (lid up, light blooming, sparkle fountain rising)
	step("chest open")
	var c: Chest = Chest.drop(game, "gold", p.global_position + Vector2(140, 0))
	await sim_wait(0.4)
	shot("review_chest_closed", "chest closed, telegraph halo")
	p.global_position = c.global_position
	await sim_wait(0.22)
	shot("review_chest_open", "chest opening: lid + burst + fountain")
	await sim_wait(1.2)
	shot("review_chest_held", "chest held open, loot banner")
	# 2. the boss bar with its badge + level + numbers (the real drawing code on
	#    a mock state — the live fight sets the same fields per frame)
	step("boss bar")
	# A REAL boss: the per-frame target tracker (game.gd → hud.track_target_bar)
	# hides the bar the moment nothing is targeted, so a bare show_boss_bar()
	# call vanished before the shot. current_boss is the tracker's fallback.
	var fm: Boss = Boss.make_boss(game, "fangmaw", p.global_position + Vector2(260, -40))
	game.bosses.append(fm)          # the same registration _spawn_boss does
	game.world.add_child(fm)
	fm.set_physics_process(false)
	fm.set_process(false)
	game.current_boss = fm
	game.hud.show_boss_bar(fm.display_name)   # (plays the splash intro first)
	await sim_wait(0.95)
	shot("review_boss_intro", "boss intro: splash + title plate (name, epithet, rules)")
	await sim_wait(2.4)
	fm.hp = fm.max_hp * 0.63
	await sim_wait(0.3)
	shot("review_boss_bar", "boss bar: badge + level + numbers")
	game.bosses.erase(fm)
	game.current_boss = null
	if is_instance_valid(fm):
		fm.queue_free()
	await frames(2)
	game.hud.hide_boss_bar()
	# 3. announcements + feed
	step("announce")
	game.hud.announce("LORE UNEARTHED — see the Codex", Color(0.75, 0.9, 1.0), 3.0)
	game.hud.log_event("+ Rusted Dagger", Items.GRADE_COLOR["D"])
	game.hud.log_event("+12 XP", Color(1.0, 0.9, 0.4))
	game.hud.log_event("+9 XP", Color(1.0, 0.9, 0.4))
	game.hud.log_event("+30 gold", Color(1.0, 0.84, 0.35), "gold")
	await sim_wait(0.75)
	shot("review_announce", "LORE UNEARTHED plaque + event feed")
	# 4. coins: spill a purse, shoot the scatter mid-arc then at rest
	step("coins")
	Pickup.drop_gold(game, 40, p.global_position + Vector2(-170, 40))
	await sim_wait(0.18)
	shot("review_coins_arc", "coins arcing out of the spill")
	await sim_wait(0.8)
	shot("review_coins_rest", "coins at rest: glow + glint")


func _goto(i: int) -> void:
	game.player.global_position = game.room_center(i)
	game._enter_room(i)
	await frames(10)
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	_mobs.clear()
	await frames(2)


## Rooms are addressed by SLUG (`the_sporewood`) so the name survives the
## .bat → .ps1 → godot argv hop without quoting games; the zone's own name is
## slugged the same way for the match.
func _room_by_name(nm: String) -> int:
	for i in game.zones.size():
		if _slug(String(game.zones[i].get("name", ""))) == _slug(nm):
			return i
	return -1


func _slug(nm: String) -> String:
	return nm.to_lower().replace(" ", "_").replace("'", "")


## --tour: stills (+ optional 2.5 s frame series) of named rooms — see header.
func _tour() -> void:
	var names := arg("names", "").split(",", false)
	if names.is_empty():
		step("--tour needs --names=Room A,Room B")
		return
	for raw in names:
		var nm := String(raw).strip_edges()
		var i := _room_by_name(nm)
		if i < 0:
			step("no room named '%s' in this chapter" % nm)
			continue
		step("tour " + nm)
		await _goto(i)
		# A room-entry dialogue pauses the tree: the still would carry the box and a
		# --gif series would record 75 identical frames (The Null Bastion, 2026-09-05).
		await skip_dialogue()
		if arg("paint", "") != "":       # --paint=<terrain>: repaint the toured room first (fog, walls…)
			apply_terrain(arg("paint", ""), i)
			await sim_wait(0.6)
		var rr := game.room_rect(i)
		var p := game.player
		var s := _slug(nm)
		if flag("noroads"):   # diagnostic: is that dark band the road quad?
			for rm in game.zone_road_marks.get(i, []):
				if is_instance_valid(rm):
					rm.visible = false
		# centre — the room as the player sees it (mill, pools, props)
		p.global_position = rr.position + rr.size * 0.5
		game.camera.global_position = p.global_position
		await sim_wait(0.8)
		shot("%s_centre" % s, nm)
		if flag("gif"):
			_gif_begin(s)
			await _gif_record(2.5)
		# under the NORTH door: torch pair + inset (the "only stems" flag)
		if game.rooms[i]["exits"].has("N"):
			p.global_position = game.door_pos(i, "N") + Vector2(0, 150.0)
			game.camera.global_position = p.global_position
			await sim_wait(0.4)
			var torches := []
			for n in game.world.get_children():
				if n is Sprite2D and n.z_index == 2 and n.hframes > 1 \
						and n.global_position.distance_to(game.door_pos(i, "N")) < 220.0:
					torches.append(n.global_position)
			var canopy_info := []
			for c in game.zone_canopy.get(i, []):
				if is_instance_valid(c):
					canopy_info.append([c.global_position, c.region_rect, c.visible, c.z_index])
			step("ndoor %s: room=%s play=%s door=%s cam_top=%d screen_c=%s torches=%s canopy=%s wall=%s" % [
				nm, game.room_rect(i), game.play_rect(i), game.door_pos(i, "N"),
				game.camera.limit_top, game.camera.get_screen_center_position(), torches,
				canopy_info, Terrains.wall_for(game.terrain_by_zone[i])])
			var posts: Array = game.zone_posts.get(i, [])
			var post_pos := []
			for pn in posts.slice(0, 6):
				if is_instance_valid(pn):
					post_pos.append([pn.global_position, pn.region_rect.size, pn.visible, pn.z_index, pn.texture != null])
			step("posts %s: n=%d first=%s" % [nm, posts.size(), post_pos])
			shot("%s_ndoor" % s, "north door")
		# west wall
		p.global_position = rr.position + Vector2(230.0, rr.size.y * 0.5)
		game.camera.global_position = p.global_position
		await sim_wait(0.4)
		shot("%s_west" % s, "west wall")


func _pack(kinds: Array, center: Vector2) -> void:
	var n := kinds.size()
	for i in n:
		var frac := (float(i) / float(maxi(n - 1, 1))) - 0.5
		var ang := deg_to_rad(frac * 120.0)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * (150.0 + float(i % 2) * 40.0)
		var e := spawn_enemy(String(kinds[i]), pos, true)
		if e != null and is_instance_valid(e):
			e.alerted = true
			# Frozen where they stand: an alerted pack dogpiles the hero within
			# a second and every hit number lands on ONE point (a rig artefact,
			# not the game) — held apart the numbers, bars and reticle read.
			e.set_physics_process(false)
			e.set_process(false)
			_mobs.append(e)


func _clear() -> void:
	for m in _mobs:
		if is_instance_valid(m):
			m.queue_free()
	_mobs.clear()


# ------------------------------------------------------------------ gif ----

## One PNG per engine frame into user://shots/polish/gif_<beat>/f_%04d.png.
func _gif_begin(beat: String) -> void:
	_gif_dir = ProjectSettings.globalize_path("%s/gif_%s" % [shot_dir, beat])
	DirAccess.make_dir_recursive_absolute(_gif_dir)
	var d := DirAccess.open(_gif_dir)
	if d != null:
		for f in d.get_files():
			if f.begins_with("f_"):
				d.remove(f)
	_gif_n = 0
	step("gif " + beat)


func _gif_cap() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/f_%04d.png" % [_gif_dir, _gif_n])
	_gif_n += 1


## Record `seconds` of frames (each engine frame = 1/30 s under --fixed-fps 30).
func _gif_record(seconds: float) -> void:
	for i in int(seconds * GIF_FPS):
		game.npc_emote_t = 1.0e9
		await get_tree().process_frame
		_gif_cap()


func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _press_dir(v: Vector2, pressed: Dictionary) -> void:
	var want := {}
	if v.y < -0.38: want[KEY_W] = true
	if v.y > 0.38:  want[KEY_S] = true
	if v.x < -0.38: want[KEY_A] = true
	if v.x > 0.38:  want[KEY_D] = true
	for k in pressed.keys():
		if not want.has(k):
			_key(k as Key, false)
			pressed.erase(k)
	for k in want.keys():
		if not pressed.has(k):
			_key(k as Key, true)
			pressed[k] = true


func _release(pressed: Dictionary) -> void:
	for k in pressed.keys():
		_key(k as Key, false)
	pressed.clear()


func _cast(slot: String) -> void:
	var p := game.player
	p.cds[slot] = 0.0
	p.mp = p.max_mp
	p.use_ability(slot)


## Live pack centroid (the hero's approach/kite target).
func _pack_centroid() -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for m in _mobs:
		if is_instance_valid(m) and not m.dying:
			c += m.global_position
			n += 1
	return c / float(n) if n > 0 else game.player.global_position + Vector2.RIGHT * 200.0


## A FIGHT beat: a live pack from the right, the hero (melee) wades in / (ranged)
## kites, basic every `a1_dt`, signature casts on `extras` [[t, slot], ...].
func _gif_fight(beat: String, room: int, cls: String, seconds: float) -> void:
	await _goto(room)
	var rr := game.room_rect(room)
	var p := game.player
	p.global_position = rr.position + Vector2(rr.size.x * 0.55, rr.size.y * 0.52)
	game.camera.global_position = p.global_position
	await frames(2)
	var kinds := ["wolf", "beastkin_raider", "blightwolf", "skeleton", "spider", "beastkin_howler"]
	for i in kinds.size():
		var frac := (float(i) / float(kinds.size() - 1)) - 0.5
		var ang := deg_to_rad(frac * 110.0)
		var pos: Vector2 = p.global_position + Vector2(cos(ang), sin(ang)) * (330.0 + float(i % 2) * 50.0)
		var e := spawn_enemy(String(kinds[i]), pos, true)
		if e != null and is_instance_valid(e):
			e.alerted = true
			_mobs.append(e)
	await frames(2)
	_gif_begin(beat)
	var melee := cls in ["warrior", "paladin"]
	var extras: Array = [[0.9, "a2"], [2.2, "a3"], [3.6, "a2"]] if melee \
		else [[0.8, "a2"], [1.9, "a3"], [3.3, "a2"]]
	var a1_dt := 0.32 if melee else 0.26
	var pressed := {}
	var last_a1 := -99.0
	var ei := 0
	var total := int(seconds * GIF_FPS)
	for f in total:
		var t := float(f) / float(GIF_FPS)
		var threat := _pack_centroid()
		var v := (threat - p.global_position) if melee else (p.global_position - threat)
		if v.length() < 1.0:
			v = Vector2.RIGHT
		v = v.normalized()
		# Melee: stop pressing once inside swing reach so the swing lands
		# instead of the hero shoving through the pack.
		if melee and p.global_position.distance_to(threat) < 70.0:
			_release(pressed)
		else:
			_press_dir(v, pressed)
		while ei < extras.size() and float(extras[ei][0]) <= t:
			_cast(String(extras[ei][1]))
			ei += 1
		if t - last_a1 >= a1_dt:
			_cast("a1")
			last_a1 = t
		game.npc_emote_t = 1.0e9
		await get_tree().process_frame
		_gif_cap()
	_release(pressed)
	_clear()


## A WALK beat: the hero walks `dir` for `seconds` from `start` (room-local).
func _gif_walk(beat: String, room: int, start: Vector2, dir: Vector2, seconds: float) -> void:
	await _goto(room)
	var rr := game.room_rect(room)
	var p := game.player
	p.global_position = rr.position + start
	game.camera.global_position = p.global_position
	await frames(2)
	_gif_begin(beat)
	var pressed := {}
	_press_dir(dir, pressed)
	await _gif_record(seconds)
	_release(pressed)


func _gif_pass(cls: String) -> void:
	game.camera.position_smoothing_enabled = true   # the real follow feel
	# 1. forest fight (Darkwood Road), 2. keep fight (Outer Bailey)
	await _gif_fight("forest_%s" % cls, 2, cls, 5.0)
	await _gif_fight("keep_%s" % cls, 17, cls, 5.0)
	# 3. the same forest fight with the HUD on
	game.hud.visible = true
	await _gif_fight("forest_hud_%s" % cls, 2, cls, 5.0)
	game.hud.visible = false
	# 4. road walk east along the Darkwood road (edged road, props, shadows, wear)
	var rr := game.room_rect(2)
	await _gif_walk("road_walk", 2, Vector2(rr.size.x * 0.18, rr.size.y * 0.5), Vector2.RIGHT, 4.5)
	# 5. magma: paint the room, walk past the lava pools (glow pulse)
	await _goto(2)
	apply_terrain("magma", 2)
	await sim_wait(0.5)
	await _gif_walk("magma_walk", 2, Vector2(rr.size.x * 0.2, rr.size.y * 0.5), Vector2.RIGHT, 4.5)
	# 6. north wall / door approach in the keep (face, shadow, torches)
	var kr := game.room_rect(17)
	await _gif_walk("keep_wall_walk", 17, Vector2(kr.size.x * 0.5, kr.size.y * 0.55), Vector2.UP, 3.5)
