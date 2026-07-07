extends "res://scripts/tests/test_ch1.gd"
## TEST HARNESS, layer 3 of 4 — Chapter 2 content, the pause menu, and
## the cross-cutting feature tests (elites/bags/small rooms).


## (T1) Maren's camp hub: briefing reads the common opening flags, sets
## the quest + gate flag, and short-circuits on repeat visits.
func _test_ch2_hub() -> void:
	# Runs right after section 14: a ch2 warrior standing in the camp.
	if not game.get_flag("chose_virtue", false):
		return _fail("opening did not set the common chose_virtue flag")
	var maren_action := _find_action("E — Maren")
	if not maren_action.is_valid():
		return _fail("Maren NPC missing from the camp")
	maren_action.call()
	await _frames(2)
	if not game.hud.dialogue_active:
		return _fail("Maren briefing did not open")
	if not ("chose BACK" in game.hud.text_label.text):
		return _fail("Maren did not read the opening choice (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()  # m1 + m2 -> m3 presents the choices
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Maren briefing offered no choices")
	game.hud._choose(0)  # "point me east"
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("ch2_briefed", false) or game.quest_key != "ch2_act1":
		return _fail("briefing did not set flag/quest (quest=%s)" % game.quest_key)
	if not game._edge_unlocked(0, 1):
		return _fail("the briefing flag did not unbar the camp's east road")
	# Repeat visit: the variant-next short-circuit, no choices re-offered.
	maren_action.call()
	await _frames(2)
	if not game.hud.dialogue_active or not ("East, shard-bearer" in game.hud.text_label.text):
		return _fail("repeat Maren visit did not short-circuit")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		return _fail("repeat Maren visit re-offered the briefing choices")
	print("ok: T1 hub (Maren briefing reads flags, quest set, short-circuit)")

## (T5) Faction arcs: joining is exclusive, standings shift, the ambient
## factions keep score without recruiting.
func _test_ch2_factions() -> void:
	var acts := {}
	for entry in game.interactables:
		acts[entry["prompt"].text] = entry["action"]
	for needed in ["E — Accord", "E — Cinderborn", "E — The Cage", "E — Pilgrim"]:
		if not acts.has(needed):
			return _fail("faction NPC '%s' missing from the camp" % needed)

	# Join the Accord.
	var accord_before: int = game.player.faction_standing["accord"]
	acts["E — Accord"].call()
	await _frames(2)
	await _skip_dialogue()  # the pitch
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Accord recruiter offered no choices")
	game.hud._choose(0)  # join
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("joined_accord", false) or not game.get_flag("faction_chosen", false):
		return _fail("joining the Accord did not set its flags")
	if game.player.faction_standing["accord"] != accord_before + 20:
		return _fail("Accord standing wrong (%d)" % game.player.faction_standing["accord"])
	if game.player.faction_standing["cinderborn"] != -10:
		return _fail("joining Accord should cost Cinderborn standing")
	if game.quest_key != "ch2_accord1":
		return _fail("Accord arc quest not set (got %s)" % game.quest_key)

	# The rival now brushes you off — and offers NO join.
	acts["E — Cinderborn"].call()
	await _frames(2)
	if not ("got to you first" in game.hud.text_label.text):
		return _fail("Cinderborn did not react to the Accord join")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		return _fail("Cinderborn still offered choices after exclusivity")

	# Wildfang: free the caged scout.
	var wf_before: int = game.player.faction_standing["wildfang"]
	acts["E — The Cage"].call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("cage encounter offered no choices")
	game.hud._choose(0)  # open the cage
	await _frames(2)
	await _skip_dialogue()
	if game.player.faction_standing["wildfang"] != wf_before + 10:
		return _fail("freeing the scout did not raise Wildfang standing")
	acts["E — The Cage"].call()
	await _frames(2)
	if not ("empty" in game.hud.text_label.text):
		return _fail("cage encounter did not resolve permanently")
	await _skip_dialogue()

	# Choir: hear the litany.
	var ch_before: int = game.player.faction_standing["choir"]
	acts["E — Pilgrim"].call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("pilgrim offered no choices")
	game.hud._choose(0)  # listen
	await _frames(2)
	await _skip_dialogue()
	if game.player.faction_standing["choir"] != ch_before + 6:
		return _fail("the litany did not raise Choir standing")
	print("ok: T5 factions (exclusive join, standings, ambient Wildfang/Choir)")

## (T6) Aldric: hub-and-spokes lore, act-progress gate, the buried truth.
func _test_ch2_aldric() -> void:
	var aldric := _find_action("E — Ser Aldric")
	if not aldric.is_valid():
		return _fail("Aldric missing from the camp")
	aldric.call()
	await _frames(2)
	await _skip_dialogue()  # greeting -> the question hub
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Aldric offered no questions")
	# ch2_briefed is set, blight_scouted is NOT: expect 3 options
	# (cost question, crown question, leave) — the secret stays hidden.
	if game.hud.choice_count != 3:
		return _fail("Aldric question count wrong pre-act (%d)" % game.hud.choice_count)
	game.hud._choose(0)  # what did it cost
	await _frames(2)
	await _skip_dialogue()  # part 1 -> back at the hub
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("Aldric hub did not loop back after an answer")
	game.hud._choose(2)  # leave
	await _frames(2)
	await _skip_dialogue()
	# Act progress (T2 will set this in play): the secret unlocks.
	game.set_flag("blight_scouted")
	aldric.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choice_count != 4:
		return _fail("Aldric secret did not unlock with act progress (%d)" % game.hud.choice_count)
	game.hud._choose(2)  # what he never told Maren
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.get_flag("aldric_truth", false):
		return _fail("hearing the secret did not set aldric_truth")
	if game.hud.choices_active:
		game.hud._choose(game.hud.choice_count - 1)  # leave
		await _frames(2)
		await _skip_dialogue()
	game.flags.erase("blight_scouted")  # leave T2's flag pristine
	print("ok: T6 Aldric (question hub, act gate, the truth)")

## (T2) Act 1: four rooms east of the camp, arc flags, act-scaled
## bosses, quest chain — now walked through the graph.
func _test_ch2_act1() -> void:
	if game.zone_count < 5:
		return _fail("act 1 zones did not append (zones=%d)" % game.zone_count)
	_buff()
	if not game._edge_unlocked(0, 1):
		return _fail("camp gate should already be open (briefing flag)")
	await _goto_room(1)

	# Sera's blue door + the fallen courier.
	var mill := _find_action("E — The Mill")
	var courier := _find_action("E — A Fallen Courier")
	if not mill.is_valid() or not courier.is_valid():
		return _fail("Greyrun landmarks missing")
	mill.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if not game.get_flag("mill_seen", false):
		return _fail("the blue door went unrecorded")
	courier.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("courier offered no choices")
	game.hud._choose(0)  # accord member: 'pocket the seal' (Vessa option hidden)
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("relic_recovered", false):
		return _fail("courier seal not recovered")

	# Clear the Mills: bossless clear sets blight_scouted + opens the way.
	await _kill_room(1)
	if not game.get_flag("blight_scouted", false):
		return _fail("clearing the Mills did not set blight_scouted")
	if not game._edge_unlocked(1, 2):
		return _fail("Mills gate did not open on clear")

	# The Howling Fields: warband falls, the Stormwarden comes act-scaled.
	await _goto_room(2)
	await _kill_room(2)
	var guard := 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "stormwarden":
		return _fail("Stormwarden did not spawn after the Fields cleared")
	if game.current_boss.level != 8:
		return _fail("Stormwarden not act-scaled (level %d)" % game.current_boss.level)
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	if game.hud.dialogue_active:
		await _skip_dialogue()
	await _frames(5)
	if game.quest_key != "choirmother":
		return _fail("quest did not advance past the Stormwarden (got %s)" % game.quest_key)
	if not game._edge_unlocked(2, 3):
		return _fail("Fields gate did not open")

	# Sporewood clear, then Choir's Hollow and its Mother end the act.
	await _goto_room(3)
	await _kill_room(3)
	if not game.get_flag("sporewood_cleared", false) or not game._edge_unlocked(3, 4):
		return _fail("Sporewood clear did not open the way")
	await _goto_room(4)
	await _kill_room(4)
	guard = 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "choirmother":
		return _fail("Choir Mother did not spawn")
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	if game.hud.dialogue_active:
		await _skip_dialogue()
	await _frames(5)
	if not game.get_flag("act1_complete", false):
		return _fail("act 1 completion flag not set")
	if game.quest_key != "nullwarden":
		return _fail("quest did not point into Act 2 (got %s)" % game.quest_key)
	print("ok: T2 act 1 (Mills/Fields/Sporewood/Hollow, scaled bosses, arc flags)")

## (T3) Act 2: four crossings, the scholar, and the chapter's end.
func _test_ch2_act2() -> void:
	if game.zone_count != 10:
		return _fail("act 2 zones did not append (zones=%d)" % game.zone_count)
	_buff()
	# The four bossless crossings: clear each, its way east must open.
	for zi in [5, 6, 7, 8]:
		await _goto_room(zi)
		await _kill_room(zi)
		if not game._edge_unlocked(zi, zi + 1):
			return _fail("room %d gate did not open on clear" % zi)
	# The scholar in the Deeps.
	var scholar := _find_action("E — A Scholar")
	if not scholar.is_valid():
		return _fail("the scholar is missing from the Deeps")
	scholar.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("the scholar offered no question")
	game.hud._choose(0)
	await _frames(2)
	await _skip_dialogue()
	if not game.get_flag("scholar_met", false):
		return _fail("scholar_met flag not set")
	# The Null Bastion: clear it, the Warden comes act-scaled, chapter ends.
	await _goto_room(9)
	await _kill_room(9)
	var guard := 0
	while not is_instance_valid(game.current_boss) and guard < 200:
		await _frames(5)
		guard += 5
		if game.hud.dialogue_active:
			await _skip_dialogue()
	if not is_instance_valid(game.current_boss) or game.current_boss.kind != "nullwarden":
		return _fail("Warden Null did not spawn")
	if game.current_boss.level != 16:
		return _fail("Warden Null not act-scaled (level %d)" % game.current_boss.level)
	game.current_boss.take_damage(99999999.0)
	await _frames(10)
	var vguard := 0
	while game.state != Game.ST_VICTORY and vguard < 200:
		if game.hud.dialogue_active:
			await _skip_dialogue()
		await _frames(5)
		vguard += 5
	if game.state != Game.ST_VICTORY:
		return _fail("chapter 2 did not reach victory")
	if game.quest_key != "done_ch2":
		return _fail("chapter done quest wrong (got %s)" % game.quest_key)
	# Restore a playable state for the tests that follow this hook.
	get_tree().paused = false
	game.state = Game.ST_PLAYING
	await _goto_room(0)
	await _frames(5)
	print("ok: T3 act 2 (crossings, scholar, Warden Null ends the chapter)")

## (T7) Resonance surfaces: merchants haggle by band, NPCs read you.
func _test_ch2_resonance() -> void:
	var res_keep := game.player.resonance
	game.player.resonance = -40.0
	if absf(game.band_price_mult() - 1.1) > 0.001:
		return _fail("tempted haggle mult wrong")
	game.player.resonance = 40.0
	if absf(game.band_price_mult() - 0.9) > 0.001:
		return _fail("steady haggle mult wrong")
	game.player.resonance = 0.0
	if absf(game.band_price_mult() - 1.0) > 0.001:
		return _fail("neutral haggle mult wrong")
	# The tempted shop greeting builds without breaking anything.
	game.player.resonance = -40.0
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open():
		return _fail("shop did not open for a tempted bearer")
	game.menus.close()
	await _frames(1)
	# NPCs read the band: the sentry steps back from the tempted...
	var sentry := _find_action("E — Talk")
	if not sentry.is_valid():
		return _fail("sentry missing for the band test")
	sentry.call()
	await _frames(2)
	if not ("further off" in game.hud.text_label.text):
		return _fail("sentry did not react to the tempted band")
	await _skip_dialogue()
	# ...and Aldric hears the shard leaning in.
	var aldric := _find_action("E — Ser Aldric")
	if aldric.is_valid():
		aldric.call()
	await _frames(2)
	if not ("almost hear it" in game.hud.text_label.text):
		return _fail("Aldric did not react to the tempted band")
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(game.hud.choice_count - 1)  # leave
		await _frames(2)
		await _skip_dialogue()
	game.player.resonance = res_keep
	print("ok: T7 resonance surfacing (haggle bands, NPCs read the shard)")

## System menu: pause opens/resumes, audio settings apply, and a chapter
## replay wipes the story while keeping the character.
func _test_pause_menu() -> void:
	# A single real ESC press must open the system menu (regression: a
	# legacy HUD overlay used to eat the first press).
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	var esc_up := InputEventKey.new()
	esc_up.keycode = KEY_ESCAPE
	esc_up.physical_keycode = KEY_ESCAPE
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	if not (game.menus.is_open() and game.menus.current == "pause"):
		return _fail("one ESC press did not open the pause menu (got '%s')" % game.menus.current)
	if not get_tree().paused:
		return _fail("pause menu did not pause the game")
	game.menus.close()
	await _frames(1)
	if get_tree().paused:
		return _fail("closing the pause menu did not resume")
	# Audio settings apply to the live players.
	var music_keep: float = game.settings["music"]
	var sfx_keep: float = game.settings["sfx"]
	game.settings["music"] = 0.5
	game.settings["sfx"] = 0.0
	game.apply_audio_settings()
	if absf(game.music_player.volume_db - (game.music_gain_db + linear_to_db(0.5))) > 0.5:
		return _fail("music volume not applied (%.1f dB)" % game.music_player.volume_db)
	if game.sound_pool[0].volume_db > -80.0:
		return _fail("sfx mute not applied")
	game.settings["music"] = music_keep
	game.settings["sfx"] = sfx_keep
	game.apply_audio_settings()
	# Chapter replay: story state resets, the character does not.
	var lvl: int = game.player.level
	var res: float = game.player.resonance
	var seed_before: int = game.wander_seed
	game.set_flag("blight_scouted")
	game.replay_chapter("ch2")
	await _frames(5)
	if game.get_flag("blight_scouted", false):
		return _fail("chapter replay kept story flags")
	if not game.get_flag("chose_virtue", false):
		return _fail("chapter replay wiped the character's opening history")
	if game.player.level != lvl or game.player.resonance != res:
		return _fail("chapter replay touched the character build")
	if game.quest_key != "ch2_start" or game.zone_count != 10:
		return _fail("chapter replay world wrong (quest=%s zones=%d)" % [game.quest_key, game.zone_count])
	if game.player.faction_standing["accord"] != 0 or game.get_flag("joined_accord", false):
		return _fail("chapter replay should reset faction commitments")
	if not quick and game.wander_seed == seed_before:
		return _fail("chapter replay did not re-roll the seeded rooms")
	if game.visited.size() != 1 or not game.visited.get(0, false):
		return _fail("chapter replay did not reset the charted map")
	print("ok: pause menu (pause/resume, audio settings, chapter replay)")

## (T4) Chapter 2 bosses: spawn, signature move, enrage threshold, and a
## story-neutral death for each content boss (the module's own kill-flow
## selftest — runs in the ch2 hub the previous section booted into).
func _test_ch2_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch2_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		# quit(1) lands at frame end; never resume, or _run would print
		# AUTOTEST PASS and quit(0) over the failure.
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch2 bosses (spawn / signature / enrage / story-neutral death) — stormwarden, choirmother, nullwarden")

## Chapter PROGRESSION: a ch1 victory carries the character into ch2
## (build/gold intact, world rebuilt, unpaused), the completion flag
## survives, and the finished chapter stays available for farming.
func _test_chapter_progression() -> void:
	game.replay_chapter("ch1")
	await _frames(10)
	if game.chapter_id != "ch1":
		return _fail("could not return to ch1 for the progression test")
	var lvl: int = game.player.level
	var gold: int = game.player.gold
	# Simulate the ch1 victory card, then press on.
	game.state = Game.ST_VICTORY
	get_tree().paused = true
	game.set_flag("completed_ch1", true)
	game.advance_chapter()
	await _frames(10)
	if game.chapter_id != "ch2":
		return _fail("advance_chapter did not carry on to ch2")
	if game.state != Game.ST_PLAYING or get_tree().paused:
		return _fail("advance_chapter left the game frozen")
	if game.player.level != lvl or game.player.gold != gold:
		return _fail("progression did not keep the character (Lv %d -> %d)" % [lvl, game.player.level])
	if not game.get_flag("completed_ch1", false):
		return _fail("chapter completion flag was wiped by the advance")
	if not game.chapter_available("ch2", true):
		return _fail("finished chapter did not unlock ch2 for this character")
	if game.quest_key != "ch2_start":
		return _fail("ch2 did not start its quest chain (got %s)" % game.quest_key)
	print("ok: chapter progression (victory carries the hero into ch2; ch1 stays farmable)")

# ---- CORE: elites, bags, reset stones, small rooms (round 6) ------------
func _test_elites_bags_smallrooms() -> void:
	# Snapshot shared state (restore, never clear — later sections
	# reuse this game).
	var keep_bag: Dictionary = game.player.bag
	var keep_gold: int = game.player.gold
	var keep_unspent: int = game.player.unspent_attr
	var keep_attr: Dictionary = game.player.attr_points.duplicate()
	var keep_consumables: Array = game.player.consumables.duplicate()

	# Elites: much tougher, zero XP, guaranteed gem on death.
	game.player.bag = Items.make_bag("S")  # room for the guaranteed gem
	var base_mob := _dummy(Vector2(150, 70))
	var e := _dummy(Vector2(200, 70))
	e.promote_elite()
	# The gem GUARANTEE starts at ELITE_GEM_SURE_LEVEL (2026-07-07 trim:
	# below it the gem is a chance) — test the guaranteed tier.
	e.level = Balance.ELITE_GEM_SURE_LEVEL
	if e.max_hp <= base_mob.max_hp * 2.0 or e.dmg <= base_mob.dmg:
		return _fail("elite is not meaningfully tougher than its kind")
	if e.xp_value != 0:
		return _fail("elite must pay ZERO xp (fixed chapter totals)")
	var gems_before: int = game.player.gem_bag.size()
	var xp_mark: int = game.player.xp + game.player.level * 100000
	e.take_damage(99999999.0)
	await _frames(3)
	if game.player.gem_bag.size() != gems_before + 1:
		return _fail("elite death did not guarantee a gem")
	if game.player.xp + game.player.level * 100000 != xp_mark:
		return _fail("elite death paid xp")
	base_mob.take_damage(99999999.0)
	await _frames(2)
	# The elite's guaranteed chest must not linger where later movement
	# tests could open it (it would skew their exact gem counts).
	for node in game.get_children():
		if node is Chest:
			node.queue_free()
	await _frames(1)

	# Reset stone: zero every allocation, refund every point.
	game.player.unspent_attr += 2
	game.player.add_attr_points("STR", 1)
	game.player.add_attr_points("PhysRes", 1)
	var stone := Items.make_reset_stone()
	# Count-based consumption check: the elite above may have dropped
	# its own stone, and Dictionary equality is by VALUE in Godot 4 —
	# has(stone) would match the twin.
	var stones_before: int = game.player.consumables.size()
	game.player.consumables.append(stone)
	var unspent_before: int = game.player.unspent_attr
	game.player.use_consumable(stone)
	if int(game.player.attr_points["STR"]) != 0 or int(game.player.attr_points["PhysRes"]) != 0:
		return _fail("reset stone did not zero allocations")
	if game.player.unspent_attr < unspent_before + 2:
		return _fail("reset stone did not refund the points")
	if game.player.consumables.size() != stones_before:
		return _fail("reset stone was not consumed")

	# Bags: bigger upgrades in place, smaller converts to gold.
	game.player.bag = Items.make_bag("F")
	if not game.player.acquire_bag(Items.make_bag("C")):
		return _fail("bigger bag should upgrade in place")
	if game.player.bag_capacity() != int(Items.BAG_SLOTS["C"]):
		return _fail("bag capacity did not follow the upgrade")
	var gold_before: int = game.player.gold
	if game.player.acquire_bag(Items.make_bag("F")):
		return _fail("smaller bag must never replace a bigger one")
	if game.player.gold <= gold_before:
		return _fail("spare bag should convert to gold")

	# Gem stacking (round 7): same stat+level shares ONE bag slot.
	var used_before: int = game.player.bag_used()
	game.player.gem_bag.append(Items.make_gem("crit", 1))
	var used_one: int = game.player.bag_used()
	game.player.gem_bag.append(Items.make_gem("crit", 1))
	if game.player.bag_used() != used_one:
		return _fail("same-kind gems must stack into one bag slot")
	if used_one > used_before + 1:
		return _fail("a new gem stack should cost exactly one slot")
	game.player._take_from_bag("crit", 1, 2)  # restore

	# Small rooms: quiet room types play smaller than their grid cell.
	var checked := 0
	for i in game.zone_count:
		if game.room_type(i) in ["social", "dead_end", "resonance", "merchant"]:
			if game.play_rect(i).size.x >= float(Game.ROOM_W) \
					or game.play_rect(i).size.y >= float(Game.ROOM_H):
				return _fail("small room type did not shrink its play rect (room %d)" % i)
			checked += 1
		elif game.room_type(i) in ["combat", "boss"]:
			if game.play_rect(i).size != Vector2(Game.ROOM_W, Game.ROOM_H):
				return _fail("combat/boss room %d lost its full size" % i)
	if checked == 0:
		return _fail("no small-room types found in this chapter")

	# Restore.
	game.player.bag = keep_bag
	game.player.gold = keep_gold
	game.player.unspent_attr = keep_unspent
	for k in keep_attr:
		game.player.attr_points[k] = keep_attr[k]
	game.player.consumables = keep_consumables
	game.player.recalc()
	print("ok: elites (no-xp loot pinata) + reset stone + bag tiers + small rooms")
