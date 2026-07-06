extends "res://scripts/tests/test_base.gd"
## TEST HARNESS, layer 2 of 4 — Chapter 1: the room graph, the darkwood
## walk, and the three story bosses.


## (1b) The Chapter 1 room graph: structural rules from DESIGN.md.
func _test_room_graph() -> void:
	var n := game.zone_count
	if n < 20 or n > 30:
		return _fail("chapter size out of bounds: %d rooms (want 20-30)" % n)
	if game.coord_to_room.size() != n:
		return _fail("room grid coords are not unique")
	# Reciprocity + valid neighbors (also enforced at load; verify).
	for i in n:
		for dir in game.rooms[i]["exits"].keys():
			var nb: int = game.neighbor(i, String(dir))
			if nb < 0:
				return _fail("room %d exit %s leads nowhere" % [i, dir])
			if not game.rooms[nb]["exits"].has(Game.OPP[dir]):
				return _fail("room %d exit %s not reciprocated by %d" % [i, dir, nb])
	# Reachability (locks ignored — they open in play).
	var seen := {0: true}
	var queue := [0]
	while not queue.is_empty():
		var cur: int = queue.pop_back()
		for dir in game.rooms[cur]["exits"].keys():
			var nb: int = game.neighbor(cur, String(dir))
			if nb >= 0 and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	if seen.size() != n:
		return _fail("unreachable rooms: %d of %d reached" % [seen.size(), n])
	# The critical path (village -> final boss) leaves 40-50% of rooms
	# as optional wings; assert at least a third are off it.
	var final_room := -1
	var final_kind := String(Story.chapter("ch1").get("final_boss", ""))
	for i in n:
		if String(game.zones[i].get("boss", "")) == final_kind:
			final_room = i
	if final_room < 0:
		return _fail("final boss room missing")
	var prev := {0: -1}
	var q2 := [0]
	while not q2.is_empty():
		var cur2: int = q2.pop_front()
		for dir in game.rooms[cur2]["exits"].keys():
			var nb2: int = game.neighbor(cur2, String(dir))
			if nb2 >= 0 and not prev.has(nb2):
				prev[nb2] = cur2
				q2.append(nb2)
	var path_len := 0
	var walk := final_room
	while walk != -1:
		path_len += 1
		walk = prev[walk]
	if n - path_len < int(n * 0.33):
		return _fail("too few side rooms: path %d of %d rooms" % [path_len, n])
	# The palette is present: every declared type appears.
	var have_types := {}
	for i in n:
		have_types[game.room_type(i)] = true
	for want in ["safe", "combat", "boss", "social", "resonance", "dead_end", "merchant"]:
		if not have_types.has(want):
			return _fail("room palette missing a '%s' room" % want)
	# Only the starting room is built at boot (rooms build lazily).
	if game.built.size() != 1 or not game.built.get(0, false):
		return _fail("rooms did not build lazily (%d built at boot)" % game.built.size())
	# Spine rooms stay adjacent in story order (the seeded walk is unbroken).
	var spine: Array = Story.chapter("ch1").get("spine", [])
	for k in range(1, spine.size()):
		if _dir_between(int(spine[k - 1]), int(spine[k])) == "":
			return _fail("spine break between rooms %d and %d" % [spine[k - 1], spine[k]])
	# Layouts are SEEDED: another seed lays another map, and the same
	# seed always lays the same one (saves must reload their world).
	var sig_a := _layout_sig()
	var seed_keep := game.wander_seed
	var differs := false
	for bump in [1, 2]:
		game.wander_seed = seed_keep + bump
		game.switch_chapter("ch1", true)
		if _layout_sig() != sig_a:
			differs = true
			break
	game.wander_seed = seed_keep
	game.switch_chapter("ch1", true)
	if not differs:
		return _fail("layout ignored the seed (every run identical)")
	if _layout_sig() != sig_a:
		return _fail("layout not deterministic for a seed")
	print("ok: room graph (%d rooms, %d on the boss path, seeded layout, lazy build)" % [n, path_len])

## (7) Darkwood: lazy build on entry, calm packs, per-pack aggro, door
## seals while hot, clears; then the side rooms (cache, social, shrine).
func _test_graph_walk_darkwood() -> void:
	_buff()
	# Entering the Darkwood Road builds it and wakes NOBODY.
	if game.built.get(2, false):
		return _fail("room 2 built before anyone entered it")
	await _goto_room(2)
	if not game.built.get(2, false):
		return _fail("room 2 did not build on entry")
	var mobs := _room_mobs(2)
	if mobs.size() != 10:
		return _fail("Darkwood Road pack count wrong (%d)" % mobs.size())
	for e in mobs:
		if e.force_aggro or e.alerted:
			return _fail("entering a room should wake nobody (per-pack aggro)")
	# Purge rule: an uncleared room seals its doors the moment you step
	# in — living packs bar the way even before anything aggroes.
	if not game.barrier_active:
		return _fail("uncleared room did not seal its doors (purge rule)")
	# Wound one member of pack 0: its whole pack answers, pack 1 sleeps.
	var pack0_member: Enemy = null
	for e in mobs:
		if e.pack_id == 0:
			pack0_member = e
	pack0_member.take_damage(1.0)
	await _frames(3)
	for e in _room_mobs(2):
		if e.pack_id == 0 and not e.force_aggro:
			return _fail("pack 0 did not wake together")
		if e.pack_id == 1 and e.force_aggro:
			return _fail("pack 1 woke from across the room")
	if not game.barrier_active:
		return _fail("door seals did not close on an aggroed pack")
	# Clear the room: seals lift, the room stays cleared.
	await _kill_room(2)
	await _frames(5)
	if game.barrier_active:
		return _fail("door seals did not lift after the clear")
	if not game.cleared.get(2, false):
		return _fail("room 2 not marked cleared")
	print("ok: darkwood road (lazy build, per-pack aggro, door seals, clear)")

	# Doorway transit is REAL: physically WALK through a doorway (no
	# teleport) — proves the wall gap, the ground-art opening and the
	# room transition all line up, whatever direction the seeded layout
	# chose (playtest round 3 regression: N/S doors were painted shut).
	var walk_dir := ""
	var walk_target := -1
	for d in game.rooms[2]["exits"].keys():
		var cand := game.neighbor(2, String(d))
		if cand > 0 and not game.gates.has(game._edge_key(2, cand)):
			walk_dir = String(d)
			walk_target = cand
			break
	if walk_dir == "":
		return _fail("darkwood road has no open onward door")
	game.player.global_position = game.door_pos(2, walk_dir) \
		- Vector2(Game.DIRS[walk_dir]) * 70.0
	var walk_key: int = {"N": KEY_W, "S": KEY_S, "E": KEY_D, "W": KEY_A}[walk_dir]
	var w_down := InputEventKey.new()
	w_down.keycode = walk_key
	w_down.physical_keycode = walk_key
	w_down.pressed = true
	Input.parse_input_event(w_down)
	var walked := 0
	while game.cur_room != walk_target and walked < 240:
		await _frames(1)
		walked += 1
	var w_up := InputEventKey.new()
	w_up.keycode = walk_key
	w_up.physical_keycode = walk_key
	w_up.pressed = false
	Input.parse_input_event(w_up)
	if game.cur_room != walk_target:
		return _fail("could not WALK through the %s doorway (gap blocked?)" % walk_dir)
	print("ok: doorway walk-through (%s door is passable, not painted shut)" % walk_dir)

	# Side room: the Hollow Oak — a guarded cache, once per character.
	await _goto_room(3)
	await _kill_room(3)
	var bag_before := game.player.backpack.size()
	var gold_before := game.player.gold
	game.player.global_position = game.room_center(3) + Vector2(0, -140)
	await _frames(10)
	if game.player.backpack.size() <= bag_before and game.player.gold <= gold_before:
		return _fail("dead-end cache gave nothing")
	if not game.get_flag(game._cache_flag(3), false):
		return _fail("cache flag not set (would refarm on reload)")
	print("ok: dead-end cache (guarded, once per character)")

	# Side room: the social clearing rolls a wanderer from the pool —
	# or, seeded ~30% per character (round 6), a lone ELITE holds the
	# room instead. game.social_holds_elite says which, so the test
	# asserts the RIGHT outcome instead of guessing.
	await _goto_room(5)
	if game.social_holds_elite(5):
		var elite_found := false
		for node in get_tree().get_nodes_in_group("enemies"):
			var en := node as Enemy
			if en and not en.dying and en.zone_idx == 5 and en.elite:
				elite_found = true
		if not elite_found:
			return _fail("elite social room spawned no elite")
		await _kill_room(5)
		print("ok: social room (seeded ELITE ambush variant)")
	else:
		# Find the wanderer by POSITION in room 5, not a global interactables
		# delta: earlier seeded movement may have already built room 5, so its
		# NPC is already counted (a flaky size compare). Room 5 (Woodsman's
		# Clearing) has no merchant or authored NPC, so any interactable
		# inside its rect is the wanderer.
		var w_entry: Dictionary = {}
		for it in game.interactables:
			var node: Node2D = it.get("node")
			if is_instance_valid(node) and game.room_rect(5).has_point(node.global_position):
				w_entry = it
				break
		if w_entry.is_empty():
			return _fail("social room rolled no wanderer")
		w_entry["action"].call()
		await _frames(2)
		# A wanderer convo may OPEN on a choice node (tinker, orphan...)
		# — that's choices_active, not dialogue_active.
		if not game.hud.dialogue_active and not game.hud.choices_active:
			return _fail("wanderer had nothing to say")
		await _skip_dialogue()
		await _frames(2)
		if game.hud.choices_active:
			game.hud._choose(0)
			await _frames(2)
			await _skip_dialogue()
		print("ok: social room (pool wanderer talks)")

	# Side room: the Moonwell shrine moves Resonance between story beats.
	await _goto_room(8)
	var shrine := _find_action("E — The Moonwell")
	if not shrine.is_valid():
		return _fail("the Moonwell is missing")
	var res_b := game.player.resonance
	shrine.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("the shrine offered no choice")
	game.hud._choose(0)  # give freely: +8
	await _frames(2)
	await _skip_dialogue()
	if game.player.resonance <= res_b or not game.get_flag("moonwell_touched", false):
		return _fail("shrine choice did not move resonance")
	shrine.call()  # revisit: the pool is quiet now (variant short-circuit)
	await _frames(2)
	if game.hud.choices_active:
		return _fail("shrine re-offered its choice")
	await _skip_dialogue()
	print("ok: resonance shrine (+8, once)")

	# Fog of war: walked rooms are charted, the rest are not.
	for i in [0, 2, 3, 5, 8]:
		if not game.visited.get(i, false):
			return _fail("room %d missing from the map" % i)
	if game.visited.get(16, false) or game.built.get(16, false):
		return _fail("unexplored rooms leaked onto the map / got built")
	print("ok: fog of war (visited-only map state)")

## (7b) Fangmaw's Hollow: adds first, then the pre-boss beat, an
## act-scaled boss, the barred east door, and boss loot.
func _test_fangmaw() -> void:
	_buff()
	await _goto_room(7)  # Deep Darkwood first: SEE the boss door
	if not game.door_seen.get(9, false):
		return _fail("boss door not marked seen from the room next door")
	await _goto_room(9)
	if game._edge_unlocked(9, 10):
		return _fail("the road past Fangmaw should be barred")
	await _kill_room(9)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for fangmaw did not open after clearing")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss):
		return _fail("fangmaw did not spawn")
	if game.current_boss.level != 5:
		return _fail("fangmaw not act-scaled (level %d)" % game.current_boss.level)
	print("ok: room cleared -> fangmaw spawned (Lv %d)" % game.current_boss.level)

	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	var gold_before := game.player.gold
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("post-boss dialogue for fangmaw did not open")
	await _skip_dialogue()
	await _frames(5)
	if not game._edge_unlocked(9, 10):
		return _fail("fangmaw's death did not unbar the way onward")
	if game.barrier_active:
		return _fail("door seals did not lift after fangmaw died")
	# Walk onto the drop pile: the gold coins magnet in.
	game.player.global_position = game.room_center(9) + Vector2(ROOM_HALF_X, 0)
	await _frames(30)
	if game.player.gold <= gold_before:
		return _fail("fangmaw dropped no gold")
	print("ok: fangmaw killed + loot (gate opened)")


const ROOM_HALF_X := 620.0  # boss arena drop pile sits east of center

## (7c) Marsh: the merchant camp, fast travel from the map, and death →
## last safe room with the death room resetting.
func _test_marsh_death_and_travel() -> void:
	_buff()
	# Stilt Camp: a merchant-typed safe pocket with silver stock.
	await _goto_room(11)
	var shop := _find_action("E — Shop")
	if not shop.is_valid():
		return _fail("stilt camp merchant missing")
	game.menus.open_shop(11)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[11].size() != 3:
		return _fail("stilt camp shop did not stock")
	game.menus.close()
	await _frames(2)
	if game.last_safe_room != 11:
		return _fail("safe room tracking missed the stilt camp (got %d)" % game.last_safe_room)

	# Fast travel: merchant camp -> village and back (visited safe rooms).
	if not game.travel_target(0):
		return _fail("village should be a travel target")
	if game.travel_target(2):
		return _fail("combat rooms must never be travel targets")
	game.fast_travel(0)
	await _frames(3)
	if game.cur_room != 0:
		return _fail("fast travel to the village failed")
	game.fast_travel(11)
	await _frames(3)
	if game.cur_room != 11:
		return _fail("fast travel back to the stilt camp failed")
	print("ok: fast travel (village <-> stilt camp; combat rooms excluded)")

	# Death: wound a pack in the Marsh Gate, die, wake up at the camp,
	# and the marsh room resets behind you.
	await _goto_room(10)
	var marsh_mobs := _room_mobs(10)
	if marsh_mobs.size() != 10:
		return _fail("marsh gate pack count wrong (%d)" % marsh_mobs.size())
	marsh_mobs[0].take_damage(1.0)
	await _frames(3)
	if not game.barrier_active:
		return _fail("marsh fight did not seal the doors")
	game.player.hurt_cd = 0.0
	game.player.max_hp = 100.0
	game.player.hp = 1.0
	game.player.eva = 0.0
	game.player.take_damage(999999.0, "true")
	if not game.player.dead:
		return _fail("player did not die")
	var guard := 0
	while game.player.dead and guard < 400:
		await _frames(5)
		guard += 1
	if game.player.dead:
		return _fail("player did not respawn")
	if game.cur_room != 11:
		return _fail("death did not return to the last safe room (got %d)" % game.cur_room)
	# The death room reset: full pack, everyone calm again.
	var reset_mobs := _room_mobs(10)
	if reset_mobs.size() != 10:
		return _fail("death room did not respawn its packs (%d)" % reset_mobs.size())
	for e in reset_mobs:
		if e.force_aggro or e.alerted:
			return _fail("respawned packs should wake calm")
	_buff()
	print("ok: death -> last safe room + death room reset")

## (8) Morwen's Bower.
func _test_morwen() -> void:
	_buff()
	await _goto_room(16)
	await _kill_room(16)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for morwen did not open")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "morwen":
		return _fail("morwen did not spawn")
	if game.current_boss.level != 8:
		return _fail("morwen not act-scaled (level %d)" % game.current_boss.level)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("post-boss dialogue for morwen did not open")
	await _skip_dialogue()
	await _frames(5)
	if not game._edge_unlocked(16, 17):
		return _fail("morwen's death did not unbar the way onward")
	print("ok: morwen killed (Lv 8, gate opened)")

## (9-10) The Hollow Throne: enrage, death/boss-reset, victory.
func _test_vargoth_victory() -> void:
	_buff()
	await _goto_room(24)
	await _kill_room(24)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("pre-boss dialogue for vargoth did not open")
	await _skip_dialogue()
	await _frames(5)
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "vargoth":
		return _fail("vargoth did not spawn")
	if game.current_boss.level != 12:
		return _fail("vargoth not act-scaled (level %d)" % game.current_boss.level)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(200)
	game.current_boss.take_damage(game.current_boss.hp - game.current_boss.max_hp * 0.2)
	await _frames(40)
	if not game.current_boss.enraged:
		return _fail("vargoth did not enrage")
	print("ok: vargoth enrage")
	# Die to him: the fight resets, the hero wakes at the last safe camp.
	game.player.hurt_cd = 0.0
	game.player.max_hp = 100.0
	game.player.hp = 1.0
	game.player.eva = 0.0
	game.player.take_damage(999999.0, "true")
	if not game.player.dead:
		return _fail("player did not die")
	await _frames(20)
	var guard := 0
	while game.player.dead and guard < 400:
		await _frames(5)
		guard += 1
	if game.player.dead:
		return _fail("player did not respawn")
	if game.current_boss.hp < game.current_boss.max_hp:
		return _fail("boss did not reset after player death")
	if not game.room_safe(game.cur_room):
		return _fail("death respawn landed somewhere unsafe (room %d)" % game.cur_room)
	print("ok: death, respawn at safe room, boss reset")
	_buff()
	await _goto_room(24)
	game.player.global_position = game.current_boss.global_position + Vector2(-180, 0)
	await _frames(10)
	game.current_boss.take_damage(999999.0)
	await _frames(5)
	game.player.pending_theme_note = ""
	if not game.hud.dialogue_active:
		return _fail("epilogue did not open after vargoth")
	await _skip_dialogue()
	await _frames(10)
	if game.state != Game.ST_VICTORY:
		return _fail("no victory state after final boss")
	print("ok: vargoth killed + victory screen")
