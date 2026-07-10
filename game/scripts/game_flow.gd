extends "res://scripts/game_world.gd"
## GAME, layer 3 of 4 — consequences: boss/enemy/player death flows,
## loot, chapter progression + meta unlocks, settings, and terrain
## events. See game_base.gd for the chain layout.


## Volume settings, persisted separately from saves (they're per-player,
## not per-character).
func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for key in settings:
			if not data.has(key):
				continue
			if settings[key] is String:
				settings[key] = String(data[key])
			elif settings[key] is bool:
				settings[key] = bool(data[key])
			else:
				settings[key] = clampf(float(data[key]), 0.0, 1.0)
	Loc.lang = String(settings.get("lang", "en"))

func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func apply_audio_settings() -> void:
	if music_player:
		music_player.volume_db = music_gain_db + _vol_db(float(settings["music"]))
	for sp in sound_pool:
		sp.volume_db = -8.0 + _vol_db(float(settings["sfx"]))
	if amb_player:
		amb_player.volume_db = AMB_DB + _vol_db(float(settings["sfx"]))

func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"]
		else DisplayServer.WINDOW_MODE_WINDOWED)

## Replay a chapter from its beginning: the CHARACTER survives (build,
## gear, Resonance, opening history); the chapter's story state resets.
func replay_chapter(id: String) -> void:
	_wipe_chapter_flags()
	for fac in player.faction_standing:
		player.faction_standing[fac] = 0
	wander_seed = randi() % 1000000  # replays meet a fresh set of rolled rooms
	weekly_active = false            # a fresh seed is never the weekly run
	reset_run_stats()
	switch_chapter(id, true)
	play_started = true
	request_pause(false)
	hud.visible = true  # the chapter-select menu hid it
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], String(Story.chapter(id)["name"]))
	autosave()


## Begin this week's challenge run: the WEEK'S fixed seed (everyone plays
## the same map), the week's modifier live, PB recorded on the clear.
## Mechanically a replay — standings reset, character rides along.
func start_weekly() -> void:
	var chid := weekly_chapter()
	if not chapter_available(chid, true):
		chid = "ch1"  # rotation picked a chapter this account hasn't opened
	_wipe_chapter_flags()
	for fac in player.faction_standing:
		player.faction_standing[fac] = 0
	weekly_active = true
	weekly_week = _week_index()
	wander_seed = weekly_seed()
	reset_run_stats()
	switch_chapter(chid, true)
	play_started = true
	request_pause(false)
	hud.visible = true  # the challenge menu hid it
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"],
		"WEEKLY CHALLENGE — %s" % String(weekly_mod()["name"]))
	autosave()

## Chapter PROGRESSION: the character who just won carries straight on
## into the next chapter — build, gear, Resonance, faction standings and
## choice history all intact. (Farming trips back go through
## replay_chapter, which resets standings; moving FORWARD keeps them.)
func advance_chapter() -> void:
	# MP-14 (§5.4): only the HOST drives the party forward; a guest's ENTER on
	# the victory card is inert (gated at the hud input layer, belt-and-braces
	# here — a guest never owns the chapter decision).
	if net_guest():
		return
	var next_ch := Story.next_chapter(chapter_id)
	if next_ch == "" or state != ST_VICTORY:
		return
	state = ST_PLAYING
	request_pause(false)
	hud.visible = true  # a victory/results menu may have hid it
	hud.overlay.color = Color(0, 0, 0, 0)
	hud.title_label.modulate.a = 0.0
	hud.subtitle_label.modulate.a = 0.0
	hud.hide_results()
	_wipe_chapter_flags()  # last chapter's story state retires; history stays
	weekly_active = false
	reset_run_stats()
	switch_chapter(next_ch, true)
	play_started = true
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], String(Story.chapter(next_ch)["name"]))
	# MP-14 (§5.4): the party follows through the SAME rebuild the join flow
	# uses — the host briefs each guest into the new chapter (its live character
	# rides along; only the world rebuilds). Remotes re-home to the new start so
	# they never linger in the freed world; the movement sync re-converges them.
	if net_host():
		for q in players:
			if q != null and is_instance_valid(q) and q != local_player:
				q.global_position = room_center(cur_room)
		net_session().host_advance_party()
	autosave()


# ------------------------------------------------- meta progression ---
# Account-wide unlocks that outlive characters (user://meta.json):
# finishing a chapter with ANY character opens the next one on the
# New Game chapter select.
const META_PATH := "user://meta.json"
# Layer-local state (read/written ONLY in this layer — the chain rule
# keeps cross-layer vars in game_base; private caches may live here).
var _meta: Dictionary = {}
var _meta_loaded := false

func _load_meta() -> void:
	if _meta_loaded:
		return
	_meta_loaded = true
	if no_saves or not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			_meta = data

func meta_unlock(chid: String) -> void:
	_load_meta()
	if bool(_meta.get("unlocked_" + chid, false)):
		return
	_meta["unlocked_" + chid] = true
	_meta_write()


func _meta_write() -> void:
	if no_saves:
		return  # tests never touch the real user files
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_meta))


## Chapter personal bests are ACCOUNT-wide (meta.json), keyed chapter ×
## class — exactly the shape a leaderboard row takes when multiplayer
## lands. Records the run, keeps best time + best grade, and reports
## which bests this run broke (the results card shouts them).
func record_chapter_result(res: Dictionary) -> Dictionary:
	_load_meta()
	var key := "pb_%s_%s" % [chapter_id, player.cls]
	var prev: Dictionary = _meta.get(key, {})
	var best := {"time": float(prev.get("time", 0.0)), "grade": String(prev.get("grade", "")),
		"runs": int(prev.get("runs", 0)) + 1}
	var out := {"new_time": false, "new_grade": false, "prev_time": best["time"],
		"first_run": int(prev.get("runs", 0)) == 0}
	if best["time"] <= 0.0 or float(res["time"]) < float(best["time"]):
		best["time"] = float(res["time"])
		out["new_time"] = true
	if Balance.grade_rank(String(res["grade"])) > Balance.grade_rank(String(best["grade"])):
		best["grade"] = String(res["grade"])
		out["new_grade"] = true
	_meta[key] = best
	_meta_write()
	return out


## This class's chapter PB, or {} (codex/journal display).
func chapter_pb(chid: String, cls: String) -> Dictionary:
	_load_meta()
	return _meta.get("pb_%s_%s" % [chid, cls], {})


## The account's best weekly-challenge clear for the CURRENT week, or {}.
func weekly_best() -> Dictionary:
	_load_meta()
	return _meta.get("wk_%d" % _week_index(), {})


## A weekly run just cleared its chapter: keep the week's fastest clear
## (account-wide) and pay the once-per-week completion reward. The run
## must still be inside its week — a stale seed races nobody.
func _finish_weekly(res: Dictionary) -> void:
	weekly_active = false
	if weekly_week != _week_index():
		spawn_text(player.global_position + Vector2(0, -70),
			"The week turned mid-run — no challenge credit.", Color(0.8, 0.8, 0.85), 4.0)
		return
	_load_meta()
	var wkey := "wk_%d" % weekly_week
	var prev: Dictionary = _meta.get(wkey, {})
	if float(prev.get("time", 0.0)) <= 0.0 or float(res["time"]) < float(prev.get("time", 0.0)):
		_meta[wkey] = {"time": float(res["time"]), "cls": player.cls,
			"grade": String(res["grade"])}
		_meta_write()
	if weekly_claimed_week != weekly_week:
		weekly_claimed_week = weekly_week
		var g := int(float(Balance.WEEKLY_REWARD_GOLD) * Balance.daily_gold_mult(player.level))
		player.gold += g
		for i in Balance.WEEKLY_REWARD_GEMS:
			give_loot({"kind": "gem", "gem": drop_gem(Balance.WEEKLY_REWARD_GEM_LVL)},
				player.global_position + Vector2(-30.0 + 30.0 * i, 40.0))
		sfx("chest")
		spawn_text(player.global_position + Vector2(0, -92),
			"WEEKLY CHALLENGE COMPLETE  (+%d gold, %d gems)" % [g, Balance.WEEKLY_REWARD_GEMS],
			Color(1.0, 0.85, 0.4), 5.0)

## Progression gating for the chapter select: the first chapter is
## always open; each later one opens once the previous is finished —
## by ANY character (meta unlock) for New Game, or by THIS character
## (its completed_ flag) when replaying.
func chapter_available(chid: String, replay := false) -> bool:
	var ids: Array = Story.CHAPTER_LIST.keys()
	var i := ids.find(chid)
	if i <= 0 or dev_mode:
		return true
	_load_meta()
	if bool(_meta.get("unlocked_" + chid, false)):
		return true
	return replay and get_flag("completed_" + String(ids[i - 1]), false)


# Character history that survives a chapter replay: which opening you
# played, what you chose in it, and which chapters you have finished.
# Everything else is story state.
# "s_awakened_" persists a class's legendary-passive awakening across chapters
# (round 51b) — it is earned once per character, like completed_.
const KEPT_FLAG_PREFIXES := ["opened_", "chose_", "completed_", "s_awakened_"]
const KEPT_FLAGS := ["owned_the_harm", "excused_the_harm", "walked_away",
	"gave_back", "kept_taking", "fled_theft", "told_truth", "hid_truth",
	"left_silent", "said_farewell", "cut_clean", "walked_silent",
	"delivered_verdict", "spared_guilty", "recused", "closed_tome",
	"borrowed_more", "burned_pages"]

func _wipe_chapter_flags() -> void:
	var kept := {}
	for fname in flags:
		var keep: bool = String(fname) in KEPT_FLAGS
		for pre in KEPT_FLAG_PREFIXES:
			if String(fname).begins_with(pre):
				keep = true
		if keep:
			kept[fname] = flags[fname]
	flags = kept
	# Quest keepsakes are run-scoped like the flags that earned them:
	# an undelivered hat does not outlive its world.
	for c in player.consumables.duplicate():
		if String(c.get("kind", "")) == "quest":
			player.consumables.erase(c)


## MP-13 (§5.4): is this a PER-CHARACTER flag — one that stays LOCAL to its
## owner in a co-op session — rather than shared WORLD state? The rule reuses
## the SAME list that already survives a chapter wipe (KEPT_FLAG_PREFIXES /
## KEPT_FLAGS): those flags describe the CHARACTER, not the host's world —
## which opening they played and chose (opened_/chose_ + the moral KEPT_FLAGS),
## their own chapter-completion credit (completed_), their legendary-passive
## awakening (s_awakened_<cls>). A guest setting one must never rewrite the
## host's (or a sibling guest's), so set_flag keeps them local. EVERY other
## flag is world state — quest progress, opened ways, one-time reveals, pay-
## once desks, shrine/cache/curse once-per-room marks — and routes through the
## host so the whole party agrees (game_base.set_flag). Dynamically reached
## from game_base via call() (the base layer can't see this derived const),
## the same idiom as _recheck_gates.
func _flag_is_local(flag_name: String) -> bool:
	if flag_name in KEPT_FLAGS:
		return true
	for pre in KEPT_FLAG_PREFIXES:
		if flag_name.begins_with(pre):
			return true
	return false


## Back to the title screen (character select). Progress is saved; the
## whole scene reboots so every system starts clean.
func exit_to_title() -> void:
	autosave()
	request_pause(false)
	get_tree().reload_current_scene()


## MP-16: a GUEST lost its host mid-run (host crash, kill, or ENet timeout —
## NOT the graceful victory-exit, where the guest reads its own results card).
## The character already autosaved in net_session._on_session_ended (with the
## §5.3 stand-up floor applied to any fallen body); here we tell the player in
## plain words and reboot to the title. Gated so it never fires on the host,
## in the lobby, on the victory card, or twice.
func net_host_lost(reason: String) -> void:
	if net_online():
		return  # still in a session — not a loss
	if not guest_world or not play_started:
		return  # the host's own close, or a lobby-time drop (lobby.gd owns that)
	if state == ST_VICTORY:
		return  # graceful victory-exit — the guest reads its own card
	if _host_lost_handled:
		return
	_host_lost_handled = true
	print("[mp] host lost (%s) — guest returning to the title" % reason)
	request_pause(false)
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null:
		net.last_session_notice = "The connection to the host was lost. Your hero is safe — its progress came home with you."
	# Real play: the Game IS the current scene, so reboot clean to the title
	# (the same reload exit_to_title uses; the notice, staged on the surviving
	# autoload, greets the player there). Under the net_test harness the Game is
	# a CHILD of the test node — reloading would restart the harness, so skip it;
	# the notice + the torn-down offline state is what that stage asserts.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


# =================================================================== keybinds

## Brawl bookkeeping shared by story and rogue boss deaths: drop the
## boss from the roster, retarget the bar, and restore the terrain
## music only when the LAST one falls — while the brawl continues the
## music stays where it peaked (playtest round 7: each kill in a x5
## dev brawl used to step the track down x5 -> x4 -> ...).
func _boss_roster_update(src: Boss) -> void:
	bosses.erase(src)
	if _live_bosses().is_empty():
		fight_report()
		current_boss = null
		hud.hide_boss_bar()
		set_music(Terrains.get_terrain(terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]).get("music", "village"))
	elif current_boss == src:
		current_boss = _live_bosses()[0]
		hud.show_boss_bar(current_boss.display_name)

## A boss killed OUTSIDE the story flow (dev panel spawns, tests):
## rewards and brawl bookkeeping only — no quests, no gates, no story
## dialogue, no boss_done marks, no chapter end.
func on_rogue_boss_died(kind: String, dead: Boss = null) -> void:
	var src: Boss = dead if is_instance_valid(dead) else current_boss
	var boss_pos: Vector2 = src.global_position if is_instance_valid(src) else player.global_position
	_boss_roster_update(src)
	# MP-12: a DOWNED/GHOST host skips the heal — the §5.3 paths (channel /
	# room-clear) own how a fallen body stands. Solo: flags always false.
	if not player.downed and not player.ghost:
		player.hp = player.max_hp
		player.mp = player.max_mp
	Chest.drop(self, "gold", clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos))
	Pickup.drop_gold(self, _kill_gold(Story.ALL_ENEMIES[kind].get("gold", 50)), boss_pos)
	# MP-11 (§5.5): the brawl pays every head — each guest gets its own
	# personal chest + pile (its machine spawns and collects them).
	# MP-12 fold-in (b): the boss-kill full heal reaches every head too.
	if net_host():
		net_session().host_full_heal()
		net_session().host_award_all([
			{"k": "chest", "tier": "gold", "at": clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos)},
			{"k": "gold", "n": int(Story.ALL_ENEMIES[kind].get("gold", 50)), "at": boss_pos}])

func on_boss_died(kind: String, dead: Boss = null) -> void:
	boss_done[kind] = true
	note_kill(kind)
	unlock_achievement("first_boss")
	if boss_done.size() >= 9:
		unlock_achievement("boss_hunter")
	bounty_progress("boss_kills")
	vault_note_boss()
	var src: Boss = dead if is_instance_valid(dead) else current_boss
	var boss_pos: Vector2 = src.global_position if is_instance_valid(src) else player.global_position
	var mzi: int = clampi(src.zone_idx if is_instance_valid(src) else cur_room, 0, zone_count - 1)
	_boss_roster_update(src)
	# MP-12: a DOWNED/GHOST host skips the heal (see on_rogue_boss_died).
	if not player.downed and not player.ghost:
		player.hp = player.max_hp
		player.mp = player.max_mp
	# (No potion restock — 2026-07-09 investment round: stock is bought.)

	# Bosses always drop a golden chest + a pile of gold.
	Chest.drop(self, "gold", clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos))
	Pickup.drop_gold(self, _kill_gold(Story.ALL_ENEMIES[kind].get("gold", 50)), boss_pos)

	# Boss gems (round 44): first clear of the chapter = 3 guaranteed
	# gems per boss (this runs BEFORE completed_<ch> is set below, so
	# the first run's final boss still counts). Replays roll a per-kill
	# chance scaling with the boss's level — 1/25 early, sure at L40+.
	var boss_lv: int = src.level if is_instance_valid(src) else 1
	var first_clear: bool = not flags.get("completed_" + chapter_id, false)
	var gem_count := 0
	if Balance.regular_gems_drop(chapter_id):   # ch1-3 bosses drop no gems (gear only)
		if first_clear:
			gem_count = Balance.BOSS_GEMS_FIRST_CLEAR
		elif loot_rng.randf() < Balance.boss_gem_chance(boss_lv):
			gem_count = 1
	# First-clear catch-up bundle rolls one level richer than the act floor.
	var boss_gem_lvl := Balance.gem_drop_level(chapter_id) + (Balance.BOSS_FIRST_CLEAR_GEM_BONUS if first_clear else 0)
	for gi in gem_count:
		var boss_gem := drop_gem(boss_gem_lvl)
		if give_loot({"kind": "gem", "gem": boss_gem}, boss_pos + Vector2(-34.0 + 34.0 * gi, 30)):
			spawn_text(boss_pos + Vector2(0, -70 - 20 * gi),
				"+ " + Items.gem_title(boss_gem), Items.gem_color(boss_gem))

	# Boss GEAR channel (round 51): a NEW drop on top of gems/gold/spoils.
	# Grade from the act table (Act1 ch1-6 B@1/3; ch7 +A@1/10; Act2/3 richer).
	var ggrade := Items.roll_boss_gear_grade(chapter_id, loot_rng)
	if ggrade != "":
		var gear := Items.roll_gear_of_grade(ggrade, loot_rng, player.cls)
		if give_loot({"kind": "item", "item": gear}, boss_pos + Vector2(40, 30)):
			spawn_text(boss_pos + Vector2(0, -92), "+ " + Items.title(gear), Items.GRADE_COLOR[ggrade])
	# Bags: a SEPARATE, rarer roll (round 51b) — inventory expansion, not every
	# run. Chance is per-act (Balance.bag_drop_chance); the GRADE follows the
	# chapter's boss band (2026-07-09); over MAX_BAGS keeps the best set.
	var bag_act: int = Story.act_of(chapter_id)
	if loot_rng.randf() < Balance.bag_drop_chance(bag_act):
		player.acquire_bag(Items.make_bag(Balance.roll_bag_grade(chapter_id, loot_rng)))

	# MP-11 (§5.5): the same boss pays every head. One personal package
	# per guest — host-rolled (loot_rng, one full roll sequence per player,
	# so heads are independent), applied on the OWNER's machine through its
	# own award paths (bag-or-ground, mail, wallet). The host's own share
	# stayed inline above; bounty/vault credit fans with it.
	# MP-12 fold-in (b): the boss-kill full heal fans with the package.
	if net_host():
		net_session().host_full_heal()
		net_session().host_boss_kill(kind, boss_pos, boss_lv, first_clear)

	# Now that the room is safe, a wandering merchant MAY set up camp.
	if loot_rng.randf() < 0.65 and not merchant_zones.has(mzi):
		call_deferred("_merchant_arrives", mzi)

	# Boss rooms may also carry a clear_flag (arc/act progress markers).
	var boss_cflag := String(zones[mzi].get("clear_flag", ""))
	if boss_cflag != "":
		set_flag(boss_cflag)

	# Chapter-driven progression: the final boss ends the chapter; any
	# other boss opens the gate out of its zone and points the quest at
	# the next boss down the road.
	if kind == String(Story.chapter(chapter_id).get("final_boss", "")):
		flush_dropped_loot()  # forgotten ground loot mails itself (round 8)
		# MP-11 (§5.5): chapter end is per head too — every guest flushes
		# ITS OWN ground strays into ITS OWN mailbox (character-owned, rides
		# their save home), and a first clear pays each guest the same
		# legible beat, rolled and mailed on their machine.
		# MP-12 fold-in (c): the victory card below is HOST-only until MP-14
		# syncs results (request_pause no-ops online, so the guests' worlds
		# keep running and nothing can soft-lock them) — guests get the beat
		# as a toast through the award machinery for now.
		# MP-14 (§5.4): the real synced victory card fans from end_it below
		# (host_victory) — no placeholder toast. Loot flush + first clear still
		# fan here (reward beat, not UI).
		if net_host():
			net_session().host_chapter_end(first_clear, boss_lv)
		quest_key = "done_" + chapter_id if Story.ALL_QUESTS.has("done_" + chapter_id) else "done"
		refresh_quest()
		# Progression: this character has finished the chapter (kept across
		# replays), and the NEXT chapter unlocks account-wide.
		set_flag("completed_" + chapter_id, true)
		unlock_achievement("clear_" + chapter_id)
		if first_clear:
			_first_clear_reward(boss_lv)
		var next_ch := Story.next_chapter(chapter_id)
		if next_ch != "":
			meta_unlock(next_ch)
		# Chapter-specific epilogue beat and victory card, with the
		# Chapter 1 texts as the fallback.
		var band := Story.res_band(player.resonance)
		var epilogue: Array = Story.beat_for("epilogue_" + chapter_id, band, flags)
		if epilogue.is_empty():
			epilogue = Story.beat_for("epilogue", band, flags)
		var vtext: String
		if next_ch != "":
			# Mid-campaign victory: the road goes on.
			vtext = String(Story.chapter(chapter_id).get("victory_text",
				"The Ember Crown is reclaimed. But the shards are still out there — and years from now, they will wake."))
			vtext += "\n\nENTER — journey on to %s        ·        R — start over" \
				% String(Story.chapter(next_ch)["name"])
		else:
			vtext = String(Story.chapter(chapter_id).get("victory_text",
				"Thanks for playing!\nPress R to play again."))
		var end_it := func() -> void:
			state = ST_VICTORY
			set_music("")
			sfx("victory")
			# Results card + personal bests (retention roadmap #1): grade the
			# run, keep account-wide chapter × class bests, shout new ones.
			var res := run_results()
			if weekly_active:
				_finish_weekly(res)
			var pb := record_chapter_result(res)
			hud.show_end_screen("VICTORY", vtext, Color(1.0, 0.85, 0.35))
			hud.show_results(res, pb)
			# MP-14 (§5.4): the party sees the card at the same moment. Each
			# guest runs net_victory — its OWN run stats + its OWN chapter
			# credit / weekly reward, applied owner-side (§5.7). Fan BEFORE the
			# pause so the reliable RPC is queued while the sim is still live.
			if net_host():
				net_session().host_victory(vtext, next_ch != "")
			request_pause(true)
		if epilogue.is_empty():
			end_it.call()
		else:
			hud.dialogue(epilogue, end_it)
	else:
		quest_key = _next_quest_after(mzi)
		var beat: Array = Story.beat_for("post_" + kind,
			Story.res_band(player.resonance), flags)
		var proceed := func() -> void:
			_recheck_gates()  # "boss" locks on this arena's edges open
			refresh_quest()
		if beat.is_empty():
			proceed.call()
		else:
			hud.dialogue(beat, proceed)
	autosave()

## The first conquest of a chapter pays a LEGIBLE beat (reward
## calibration, 2026-07-06): gold in hand (~15-25% of the run's own
## take, level-scaled) plus a mailed spoils package — one act-cap gear
## roll and a Lv2 gem. Once per character per chapter; after this,
## replays are the farm loop and pay as themselves.
func _first_clear_reward(boss_lv: int) -> void:
	var g := int(Balance.FIRST_CLEAR_GOLD * Balance.daily_gold_mult(boss_lv))
	player.gold += g
	var spoils := Items.roll_chapter_gear(chapter_id, loot_rng, player.cls)
	var spoil_rewards: Array = [{"kind": "item", "item": spoils}]
	if Balance.regular_gems_drop(chapter_id):   # ch1-3 spoils are gear + gold only
		spoil_rewards.append({"kind": "gem", "gem": drop_gem(
			Balance.gem_drop_level(chapter_id) + Balance.BOSS_FIRST_CLEAR_GEM_BONUS)})
	send_mail("Spoils of %s" % String(Story.chapter(chapter_id)["name"]),
		"The chapter is conquered. These spoils are yours by right — and the road behind you stays open for the farming.",
		spoil_rewards)
	spawn_text(player.global_position + Vector2(0, -106),
		"CHAPTER CONQUERED  +%d gold — spoils in your mailbox" % g,
		Color(1.0, 0.85, 0.4), 5.0)


## The quest key after clearing zone zi: the next boss down the road,
## or the chapter's own "done" text if it has one.
func _next_quest_after(zi: int) -> String:
	for z in range(zi + 1, zone_count):
		var kind := String(zones[z].get("boss", ""))
		if kind != "" and not boss_done.get(kind, false):
			return kind
	return "done_" + chapter_id if Story.ALL_QUESTS.has("done_" + chapter_id) else "done"

## Hunger (tempted resonance lean): kills pay a little extra gold —
## applied where kill gold is ROLLED (greed applies later, at pickup).
func _kill_gold(base: int) -> int:
	return int(base * player.hunger_gold_mult()) if is_instance_valid(player) else base

func on_enemy_died(e: Enemy) -> void:
	if e is Boss:
		return  # boss drops are handled in on_boss_died
	Pickup.drop_gold(self, _kill_gold(e.gold_value), e.global_position)
	if e.xp_value > 0 or e.gold_value > 0 or e.elite:
		note_kill(e.kind)  # codex completion (scenery props and event mood spawns don't count)
	if e.elite and is_instance_valid(player):
		run_elites += 1
		bounty_progress("elite_kills")
		# Elite loot pinata (playtest round 6): a guaranteed gem, a
		# guaranteed good chest, and the elite-exclusive economy —
		# talent reset stones and bigger bags. XP is zero by design
		# (chapter totals stay fixed). Early-game trim (2026-07-07):
		# the gem guarantee starts at ELITE_GEM_SURE_LEVEL — below it
		# the gem is a chance, so chapter-1 bags stop drowning in gems
		# nobody can socket yet.
		if Balance.regular_gems_drop(chapter_id) and (e.level >= Balance.ELITE_GEM_SURE_LEVEL \
				or loot_rng.randf() < Balance.ELITE_GEM_EARLY_CHANCE):
			var gem := drop_gem(Balance.gem_drop_level(chapter_id))
			if give_loot({"kind": "gem", "gem": gem}, e.global_position):
				spawn_text(e.global_position + Vector2(0, -70), "+ " + Items.gem_title(gem), Items.gem_color(gem))
		Chest.drop(self, "gold" if loot_rng.randf() < Balance.ELITE_GOLD_CHEST_CHANCE else "silver",
			e.global_position + Vector2(44, 0))
		if loot_rng.randf() < Balance.ELITE_STONE_CHANCE:
			if give_loot({"kind": "stone", "stone": Items.make_reset_stone()}, e.global_position + Vector2(-36, 8)):
				spawn_text(e.global_position + Vector2(0, -92), "+ Stone of Unlearning", Color(0.6, 0.9, 1.0))
		elif loot_rng.randf() < Balance.ELITE_TOME_CHANCE:
			if give_loot({"kind": "stone", "stone": Items.make_respec_tome()}, e.global_position + Vector2(-36, 8)):
				spawn_text(e.global_position + Vector2(0, -92), "+ Palimpsest of the Path", Color(0.6, 0.9, 1.0))
		elif loot_rng.randf() < Balance.ELITE_BAG_CHANCE:
			# 2026-07-09: bag grade follows the chapter's boss table (like boss bags).
			player.acquire_bag(Items.make_bag(Balance.roll_bag_grade(chapter_id, loot_rng)))
		# MP-11 (§5.5): the pinata pays every head — a personal, host-rolled
		# package per guest (roll_elite_pack mirrors the block above; keep
		# them in step) + their own elite bounty credit.
		if net_host():
			net_session().host_elite_kill(e)
	else:
		# Chance-based chest drops (Greed nudges the odds up from its first point).
		var bonus := Stats.greed_loot(player.current_greed()) if is_instance_valid(player) else 0.0
		var roll := loot_rng.randf()
		if roll < Balance.MOB_SILVER_CHEST_CHANCE + bonus * 0.3:
			Chest.drop(self, "silver", e.global_position)
		elif roll < Balance.MOB_WOOD_CHEST_CHANCE + bonus:
			Chest.drop(self, "wood", e.global_position)
		# Gold Rush: rarely, a PAYING trash kill spills a charged coin — grab
		# it and greed surges for a window. The farm loop's slot-machine beat
		# (summons/mood spawns pay nothing and can never spill one).
		if e.gold_value > 0 and loot_rng.randf() < Balance.GOLDRUSH_DROP_CHANCE:
			Pickup.drop_goldrush(self, e.global_position + Vector2(0, 26))
		# MP-11 (§5.5): the same trash kill pays every head — each guest gets
		# a personal kill event: the BASE pile (their machine applies its own
		# Hunger/weekly/greed), their own chest-chance roll (it reads THEIR
		# greed, so it must roll owner-side — mob_kill_share mirrors the
		# block above; keep them in step), and a host-rolled Gold Rush coin.
		if net_host():
			net_session().host_mob_kill(e)

	# Room clear tracking: the boss only appears once its room is purged.
	if e.zone_idx >= 0:
		zone_alive[e.zone_idx] = maxi(0, zone_alive.get(e.zone_idx, 0) - 1)
		# Pack cascade (2026-07-09): a wiped pack makes the next-nearest
		# sleeping pack in the room aware — it comes to you, so a big arena
		# doesn't turn into stragger-hunting. No-op once the room is clear.
		if not _pack_alive(e.zone_idx, e.pack_id):
			_wake_nearest_pack(e.zone_idx)
		refresh_quest()
		if zone_alive[e.zone_idx] == 0:
			cleared[e.zone_idx] = true  # stays cleared for the run (saved)
			if curse_pending.has(e.zone_idx):
				curse_pending.erase(e.zone_idx)
				_curse_payout(e.zone_idx)
			bounty_progress("rooms_cleared")
			if net_host():
				net_session().host_party_credit("room")  # MP-11: guests' boards advance too
			_try_spawn_boss(e.zone_idx)
			_recheck_gates()  # "clear" locks on this room's edges open
			if zones[e.zone_idx].get("boss", "") == "":
				# Bossless rooms: clearing IS the objective ("clear_flag"),
				# and the wandering merchant may arrive.
				if e.zone_idx == cur_room:
					_purge_fx()  # the blight recedes; the door seals lift
				var cflag := String(zones[e.zone_idx].get("clear_flag", ""))
				if cflag != "":
					set_flag(cflag)
				if loot_rng.randf() < 0.65 and not merchant_zones.has(e.zone_idx):
					call_deferred("_merchant_arrives", e.zone_idx)
				if e.zone_idx == cur_room and room_safe(cur_room):
					last_safe_room = cur_room
			autosave()

## A cursed room's pack is purged: the chest honors its bargain — a
## golden chest and a guaranteed gem at the room's heart (risk events,
## retention roadmap #4).
func _curse_payout(zi: int) -> void:
	var pos := room_center(zi) + Vector2(0, -60)
	Chest.drop(self, "gold", pos)
	if Balance.regular_gems_drop(chapter_id):   # gem reward only once gems drop (ch4+)
		var gem := drop_gem(
			2 if loot_rng.randf() < Balance.gem_lv2_chance(player.level) else 1)
		if give_loot({"kind": "gem", "gem": gem}, pos + Vector2(44, 24)):
			spawn_text(pos + Vector2(0, -40), "+ " + Items.gem_title(gem), Items.gem_color(gem))
	sfx("nova", 0.8)
	if is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -78),
			"THE CURSE LIFTS — its hoard is yours", Color(0.8, 0.6, 1.0), 3.5)
	# MP-11 (§5.5): the party shared the crueler pack, so the bargain pays
	# every head — a personal golden chest + gem roll per guest.
	if net_host():
		net_session().host_curse_payout(zi)


# ==================================================== MP-11 loot instancing
# §5.5: every reward faucet pays PER HEAD — the host triggers, each
# machine spawns/collects its own copy. The helpers below are the two
# halves of the personal-event machinery (net_session.gd carries them):
#   roll_*_pack — HOST-side: one player's share, rolled from loot_rng
#     (a full independent roll sequence per player). Mirrors of the solo
#     blocks above — when a solo faucet is tuned, tune its pack twin.
#   apply_award_events / mob_kill_share — OWNER-side: land the share
#     through the normal award paths (give_loot bag-or-ground + the
#     owner's dropped_loot/mail registry, acquire_bag, Chest/Pickup
#     spawns, own Hunger/greed/weekly multipliers). Solo never runs any
#     of this — the solo paths above are untouched.
#
# Award event schema (one Array of these per package, RPC-safe types):
#   {"k": "gold",  "n": base_amount, "at": Vector2}   # pre-multiplier base
#   {"k": "chest", "tier": "wood|silver|gold", "at": Vector2}
#   {"k": "gem",   "gem": {...}, "at": Vector2, "ty": text_y_offset}
#   {"k": "item",  "item": {...}, "at": Vector2}
#   {"k": "stone", "stone": {...}, "at": Vector2}     # text = "+ <name>"
#   {"k": "bag",   "grade": "F".."S"}
#   {"k": "sfx",   "id": "...", "vol": 1.0}
#   {"k": "toast", "text": "...", "color": Color, "dur": 0.0}

## OWNER-side: apply a personally-rolled award package. Called deferred
## (RPC contexts spawn Area2Ds — the flush-guard rule, CLAUDE.md).
func apply_award_events(events: Array) -> void:
	for raw in events:
		var ev: Dictionary = raw
		var at: Vector2 = ev.get("at", player.global_position)
		match String(ev.get("k", "")):
			"gold":
				Pickup.drop_gold(self, _kill_gold(int(ev.get("n", 0))), at)
			"chest":
				Chest.drop(self, String(ev.get("tier", "wood")), at)
			"gem":
				var gem: Dictionary = ev.get("gem", {})
				if give_loot({"kind": "gem", "gem": gem}, at):
					spawn_text(at + Vector2(0, float(ev.get("ty", -70))),
						"+ " + Items.gem_title(gem), Items.gem_color(gem))
			"item":
				var it: Dictionary = ev.get("item", {})
				if give_loot({"kind": "item", "item": it}, at):
					spawn_text(at + Vector2(0, -92), "+ " + Items.title(it),
						Items.GRADE_COLOR.get(String(it.get("grade", "F")), Color(1, 1, 1)))
			"stone":
				var st: Dictionary = ev.get("stone", {})
				if give_loot({"kind": "stone", "stone": st}, at):
					spawn_text(at + Vector2(0, -92), "+ " + String(st.get("name", "Stone")),
						Color(0.6, 0.9, 1.0))
			"bag":
				player.acquire_bag(Items.make_bag(String(ev.get("grade", "F"))))
			"sfx":
				sfx(String(ev.get("id", "chest")), float(ev.get("vol", 1.0)))
			"toast":
				if is_instance_valid(player):
					spawn_text(player.global_position + Vector2(0, -78),
						String(ev.get("text", "")), ev.get("color", Color(1, 1, 1)),
						float(ev.get("dur", 0.0)))


## OWNER-side: this machine's PERSONAL share of a party trash kill —
## the mirror of on_enemy_died's non-elite block (keep them in step).
## The pile applies the owner's own Hunger (+weekly gild at drop_gold,
## greed at pickup); the chest chance reads the OWNER's greed — the one
## roll that cannot happen host-side (greed is never synced); the Gold
## Rush coin was host-rolled per player (goldrush). Called deferred.
func mob_kill_share(pos: Vector2, base_gold: int, goldrush: bool) -> void:
	Pickup.drop_gold(self, _kill_gold(base_gold), pos)
	var bonus := Stats.greed_loot(player.current_greed()) if is_instance_valid(player) else 0.0
	var roll := loot_rng.randf()
	if roll < Balance.MOB_SILVER_CHEST_CHANCE + bonus * 0.3:
		Chest.drop(self, "silver", pos)
	elif roll < Balance.MOB_WOOD_CHEST_CHANCE + bonus:
		Chest.drop(self, "wood", pos)
	if goldrush:
		Pickup.drop_goldrush(self, pos + Vector2(0, 26))


## HOST-side: one player's share of a boss kill — the mirror of
## on_boss_died's drop block (keep them in step). first_clear is the
## HOST's chapter state: the trigger is shared, the payout per head
## (§5.5). `cls` is the receiving player's class (gear rolls their kit).
func roll_boss_pack(kind: String, boss_pos: Vector2, boss_lv: int,
		first_clear: bool, cls: String) -> Array:
	var evs: Array = [
		{"k": "chest", "tier": "gold", "at": clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos)},
		{"k": "gold", "n": int(Story.ALL_ENEMIES[kind].get("gold", 50)), "at": boss_pos},
	]
	var gem_count := 0
	if Balance.regular_gems_drop(chapter_id):
		if first_clear:
			gem_count = Balance.BOSS_GEMS_FIRST_CLEAR
		elif loot_rng.randf() < Balance.boss_gem_chance(boss_lv):
			gem_count = 1
	var gem_lvl := Balance.gem_drop_level(chapter_id) + (Balance.BOSS_FIRST_CLEAR_GEM_BONUS if first_clear else 0)
	for gi in gem_count:
		evs.append({"k": "gem", "gem": drop_gem(gem_lvl),
			"at": boss_pos + Vector2(-34.0 + 34.0 * gi, 30), "ty": -70 - 20 * gi})
	var ggrade := Items.roll_boss_gear_grade(chapter_id, loot_rng)
	if ggrade != "":
		evs.append({"k": "item", "item": Items.roll_gear_of_grade(ggrade, loot_rng, cls),
			"at": boss_pos + Vector2(40, 30)})
	if loot_rng.randf() < Balance.bag_drop_chance(Story.act_of(chapter_id)):
		evs.append({"k": "bag", "grade": Balance.roll_bag_grade(chapter_id, loot_rng)})
	return evs


## HOST-side: one player's share of an elite kill — the mirror of
## on_enemy_died's elite block (keep them in step). Gold rides along
## (the base; the owner multiplies).
func roll_elite_pack(e: Enemy) -> Array:
	var pos := e.global_position
	var evs: Array = [{"k": "gold", "n": e.gold_value, "at": pos}]
	if Balance.regular_gems_drop(chapter_id) and (e.level >= Balance.ELITE_GEM_SURE_LEVEL \
			or loot_rng.randf() < Balance.ELITE_GEM_EARLY_CHANCE):
		evs.append({"k": "gem", "gem": drop_gem(Balance.gem_drop_level(chapter_id)),
			"at": pos, "ty": -70})
	evs.append({"k": "chest",
		"tier": "gold" if loot_rng.randf() < Balance.ELITE_GOLD_CHEST_CHANCE else "silver",
		"at": pos + Vector2(44, 0)})
	if loot_rng.randf() < Balance.ELITE_STONE_CHANCE:
		evs.append({"k": "stone", "stone": Items.make_reset_stone(), "at": pos + Vector2(-36, 8)})
	elif loot_rng.randf() < Balance.ELITE_TOME_CHANCE:
		evs.append({"k": "stone", "stone": Items.make_respec_tome(), "at": pos + Vector2(-36, 8)})
	elif loot_rng.randf() < Balance.ELITE_BAG_CHANCE:
		evs.append({"k": "bag", "grade": Balance.roll_bag_grade(chapter_id, loot_rng)})
	return evs


## HOST-side: one player's share of a curse payout — the mirror of
## _curse_payout above (keep them in step). `level` is the receiving
## player's own level (the Lv2-gem odds scale off the head it pays).
func roll_curse_pack(zi: int, level: int) -> Array:
	var pos := room_center(zi) + Vector2(0, -60)
	var evs: Array = [{"k": "chest", "tier": "gold", "at": pos}]
	if Balance.regular_gems_drop(chapter_id):
		evs.append({"k": "gem",
			"gem": drop_gem(2 if loot_rng.randf() < Balance.gem_lv2_chance(level) else 1),
			"at": pos + Vector2(44, 24), "ty": -40})
	evs.append({"k": "sfx", "id": "nova", "vol": 0.8})
	evs.append({"k": "toast", "text": "THE CURSE LIFTS — its hoard is yours",
		"color": Color(0.8, 0.6, 1.0), "dur": 3.5})
	return evs


## The room's last pack falls: a brief green cleansing pulse — the
## blight recedes — as the door seals lift (purge rule, DESIGN.md).
func _purge_fx() -> void:
	hud.flash_screen(Color(0.3, 0.85, 0.4), 0.32, 0.55)
	# A low, soft sting — noticeable, never loud (playtest round 3).
	sfx("nova", 0.65, 0.0, -9.0)
	shake(3.0)
	if is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -70),
			"THE BLIGHT RECEDES", Color(0.55, 0.95, 0.6))
		burst(player.global_position + Vector2(0, -20), Color(0.5, 0.9, 0.55), 16)

## Death: back to the last safe room with gear/gold/XP intact; the room
## you died in resets. No corpse runs — the penalty is the walk.
##
## Structured as an explicit state machine (MULTIPLAYER.md §5.3): solo runs
## begin → the same 2.0s death beat → respawn, rhythm unchanged. Co-op
## inserts its downed/revive/wipe logic BETWEEN _death_begin and
## _death_respawn — a wipe replays this exact sequence as "a party of N
## wiping", keeping one death code path.
func on_player_died() -> void:
	if state != ST_PLAYING:
		return
	var p: Player = player  # solo: THE player (co-op: the one who fell)
	var death_room := cur_room
	_death_begin(p)
	await get_tree().create_timer(2.0).timeout
	_death_respawn(p, death_room)


## Death phase 1 — the fall: freeze play (ST_DEAD), pay the tithe, mourn.
func _death_begin(p: Player) -> void:
	state = ST_DEAD
	run_deaths += 1
	fight_wipe()
	sfx("pdie")
	# Death tithe (2026-07-09): a slice of CARRIED gold stays where you fell —
	# without it death is free and every boss is beatable by pure attrition.
	# Respawn location, boss reset and the HP/MP restore stay untouched.
	var tithe: int = int(float(p.gold) * Balance.DEATH_GOLD_TITHE)
	if tithe > 0:
		p.gold = maxi(p.gold - tithe, 0)
		spawn_text(p.global_position + Vector2(0, -64), "-%d gold" % tithe,
			Color(1.0, 0.84, 0.35))
	hud.dim(0.55)
	hud.flash_title("YOU DIED", "The flame endures...", 1.0)
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()


## Death phase 2 — the return: the world calms down (bosses walk home,
## the death room resets, nothing follows you), then p revives at the
## nearest pacified room and play resumes. forced_room (MP-12): a wipe
## respawns GUESTS at the HOST's respawn-room decision — their own
## cleared/zone_alive maps are mirrors, not truth. Solo callers omit it.
func _death_respawn(p: Player, death_room: int, forced_room := -1) -> void:
	for b in _live_bosses().duplicate():
		var live_b: Boss = b
		if live_b.zone_idx < 0:
			# Rogue bosses (dev-panel spawns — no home arena) don't
			# survive your death: they'd chase and attack across rooms.
			bosses.erase(live_b)
			live_b.remove_from_group("enemies")
			live_b.queue_free()
			if current_boss == live_b:
				current_boss = null
		else:
			live_b.reset_fight()  # walks home and heals; the arena waits
	if is_instance_valid(current_boss):
		hud.update_boss_bar(1.0)
	if not cleared.get(death_room, false):
		_reset_room_enemies(death_room)
	# Nothing follows you home from a death: homeless spawns (boss adds,
	# terrain-event zombies — zone_idx -1, they never freeze with a room)
	# despawn outright, and every other survivor calms down and returns
	# to its post instead of camping your respawn.
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying:
			continue
		if e.zone_idx < 0:
			e.remove_from_group("enemies")
			e.queue_free()
		elif e.force_aggro or e.alerted:
			e.force_aggro = false
			e.alerted = false
			e.global_position = e.home

	# Respawn at the nearest pacified room to where you fell — a cleared
	# combat room counts, so a boss wipe no longer marches you back through
	# the whole chapter (2026-07-09).
	var rr := forced_room if forced_room >= 0 else respawn_room(death_room)
	p.global_position = room_center(rr)
	p.revive()
	_enter_room(rr)
	# No boss serenades your respawn: unless the boss is HERE (it never
	# is — you respawn in a safe room), the bar hides and the room's own
	# music takes over. The arena boss keeps waiting where it lives.
	if not is_instance_valid(current_boss) or current_boss.zone_idx != cur_room:
		hud.hide_boss_bar()
		set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.dim(0.0)
	state = ST_PLAYING


## MP-12 (§5.3): ALL players down — the WIPE. The host detected it
## (net_session._check_wipe) and broadcast the room decision; every
## machine now replays the solo death flow for its OWN player: the tithe
## + 2.0 s beat of _death_begin, then _death_respawn at the HOST's
## respawn room. The host's copy resets the death room and bosses exactly
## like solo; a guest's copy resets its mirror world the way a guest
## death always has (net_session's ST_DEAD watcher asks the host for an
## enemy resync on recovery). One death code path — a wipe IS "a party
## of N dying at once", and a party of 1 online collapses to solo.
func net_wipe(death_room: int, safe_room: int) -> void:
	if state != ST_PLAYING:
		return
	var p: Player = local_player
	if p == null or not is_instance_valid(p):
		return
	# The fall is now a death: drop the §5.3 detour state on EVERY player
	# object — owners never broadcast an "up" through a wipe, so shells
	# must shed their downed/ghost flags here (vitals re-truth the bars).
	for q in players:
		if q != null and is_instance_valid(q):
			q.net_clear_down_local()
	p.hp = 0.0
	p.dead = true
	p.play_death_anim()
	_death_begin(p)
	await get_tree().create_timer(2.0).timeout
	_death_respawn(p, death_room, safe_room)


## MP-14 (§5.4/§5.7), GUEST: the host's final boss fell — show the SAME
## results card the host does, from THIS machine's own run + character. The
## guest applies its own chapter-completion credit (a KEPT/character flag that
## rides its save home), unlocks its own next chapter in its own meta.json,
## and claims its own weekly reward — all owner-side, exactly as a solo clear
## would. The first-clear beat + loot flush already fanned via host_chapter_end.
func net_victory(vtext: String, has_next: bool) -> void:
	if state == ST_VICTORY:
		return  # idempotent — one card per clear
	# Character credit FIRST, while still ST_PLAYING so autosave persists it
	# (autosave gates on ST_PLAYING; write_character_home carries the flag home).
	var res := run_results()
	if weekly_active:
		_finish_weekly(res)  # per-player: reads THIS guest's level/records
	var pb := record_chapter_result(res)
	set_flag("completed_" + chapter_id, true)  # KEPT flag: local, rides home
	unlock_achievement("clear_" + chapter_id)
	if has_next:
		var next_ch := Story.next_chapter(chapter_id)
		if next_ch != "":
			meta_unlock(next_ch)  # this guest's OWN next-chapter unlock
	autosave()  # ST_PLAYING still — the completion credit writes home now
	state = ST_VICTORY
	set_music("")
	sfx("victory")
	hud.show_end_screen("VICTORY", vtext, Color(1.0, 0.85, 0.35))
	hud.show_results(res, pb)
	request_pause(true)  # allowed in-session during ST_VICTORY (game_base)


## MP-14 (§5.4), GUEST: the host advanced — follow into the next chapter
## through the SAME switch_chapter rebuild the join snapshot uses, but keep
## the LIVE, progressed character (no save re-apply). The guest's own kept
## flags survive the wipe; only the old chapter's world state retires.
func net_advance(snap: Dictionary) -> void:
	state = ST_PLAYING
	hud.hide_results()
	hud.overlay.color = Color(0, 0, 0, 0)
	hud.title_label.modulate.a = 0.0
	hud.subtitle_label.modulate.a = 0.0
	_wipe_chapter_flags()  # this guest keeps its character flags; world retires
	wander_seed = int(snap.get("wander_seed", wander_seed))  # the host's map
	reset_run_stats()
	guest_world = true  # STILL a guest (reset_run_stats cleared it)
	switch_chapter(String(snap.get("chapter", chapter_id)), true)
	# weekly state rides the brief (set AFTER switch — its callers, not it,
	# clear the flag), mirroring the join snapshot.
	weekly_active = bool(snap.get("weekly_active", false))
	weekly_week = int(snap.get("weekly_week", weekly_week))
	# Re-home the remote shells to the shared start so they never linger in the
	# freed world; the movement sync re-converges them within a tick.
	for q in players:
		if q != null and is_instance_valid(q) and q != local_player:
			q.global_position = room_center(cur_room)
	play_started = true
	request_pause(false)
	hud.visible = true
	net_session()._gate_existing_chests()  # the rebuilt world's chests are ours
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], String(Story.chapter(chapter_id)["name"]))
	autosave()


## MP-14 (§5.7), GUEST: the host ended the run (replay / title) rather than
## advancing — autosave the character home and drop out of the session
## gracefully (the transport leave frees mirrors; net returns to the title).
func net_session_over() -> void:
	# Persist the character before the session tears down (autosave gates on
	# ST_PLAYING; if the guest is on the victory card, write home directly).
	if guest_world and save_slot > 0:
		SaveGame.write_character_home(self, save_slot)
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and bool(net.is_online()):
		net.leave()


## Scroll of Recall: whisk the LIVING player back to the last safe room.
## Refused while a room is HOT (doors sealed mid-combat) — returns false so
## the scroll isn't consumed. Returns true on a successful recall.
func recall_to_safe() -> bool:
	if barrier_active:
		spawn_text(player.global_position + Vector2(0, -56), "Can't recall in combat!", Color(1.0, 0.6, 0.4))
		return false
	player.global_position = room_center(last_safe_room)
	_enter_room(last_safe_room)
	burst(player.global_position, Color(0.6, 0.9, 1.0), 14)
	spawn_text(player.global_position + Vector2(0, -56), "RECALLED to safety", Color(0.6, 0.9, 1.0))
	return true


# ================================================================== helpers

## Timed terrain happenings (magma rain, zombies, gusts, lightning...).
func run_terrain_event(ev: String) -> void:
	# MP-12 fold-in (a): terrain weather is WORLD simulation — in a session
	# only the HOST rolls it; its tells reach guests as the telegraph events
	# game_base already broadcasts plus the hazard event below (a guest
	# rolling its own would double the weather and desync the ground truth).
	# Solo: net_guest() is false, nothing changes. Aiming events at guest
	# positions (a guest alone in a lava room) is MP-15's terrain sweep.
	if net_guest():
		return
	var zi := cur_room
	match ev:
		"magma_rain":
			# Magma falls from the sky — sometimes the floor collapses
			# into a lingering lava pool instead.
			if randf() < 0.3:
				var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-200, 200), randf_range(-150, 150)), player.global_position)
				telegraph(pos, 75.0, 1.3, 10.0, {"color": Color(1.0, 0.35, 0.1, 0.5)})
				_add_hazard.call_deferred(zi, "lava", pos, 70.0, 22.0)
				# MP-10 hazard-event pattern: guests paint the same pool and
				# their own _apply_hazards ticks their own player (§4.1).
				if net_host():
					net_session().host_hazard(zi, "lava", pos, 70.0, 22.0)
			else:
				for i in randi_range(1, 2):
					var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-260, 260), randf_range(-180, 180)), player.global_position)
					telegraph(pos, 65.0, 1.0, 16.0, {"color": Color(1.0, 0.35, 0.1, 0.55), "fireball": true})
		"grave_spawn":
			if zone_alive.get(zi, 0) > 0 or is_instance_valid(current_boss):
				var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-220, 220), randf_range(-160, 160)), player.global_position)
				burst(pos, Color(0.5, 0.45, 0.35), 12)
				sfx("gate", 1.4)
				var z := Enemy.make(self, "zombie", pos, player.level)  # scales with you
				z.xp_value = 0   # event spawns are mood, not a farm —
				z.gold_value = 0  # chapter XP/gold stays a fixed total
				z.force_aggro = true
				add_enemy(z)
				emote(z, "!", 0.8)
		"gust":
			gust_vec = Vector2.RIGHT.rotated(randf() * TAU) * 220.0
			gust_t = 1.8
			sfx("blink", 0.6)
			burst(player.global_position + gust_vec.normalized() * -80.0, Color(0.85, 0.72, 0.45), 16)
		"lightning":
			var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-160, 160), randf_range(-120, 120)), player.global_position)
			telegraph(pos, 60.0, 0.55, 24.0, {"color": Color(0.7, 0.85, 1.0, 0.6)})
			hud.flash_screen(Color(0.8, 0.9, 1.0), 0.25, 0.2)
		"shard":
			var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-200, 200), randf_range(-150, 150)), player.global_position)
			telegraph(pos, 55.0, 0.7, 14.0, {"color": Color(0.5, 0.85, 1.0, 0.55)})
			sfx("nova", 1.3)

## Apply floor-patch effects to the player and enemies (ticked at 2.5Hz).
func _apply_hazards() -> void:
	player.hazard_speed = 1.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e:
			e.hazard_speed = 1.0
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		if h["until"] > 0.0 and now > h["until"]:
			if is_instance_valid(h["sprite"]):
				h["sprite"].queue_free()
			hazards.remove_at(i)
			continue
		if h["drift"] != Vector2.ZERO:  # wandering spore clouds
			h["pos"] += h["drift"] * 0.4
			var hr := room_rect(int(h["zone"]))
			if h["pos"].x < hr.position.x + 100 or h["pos"].x > hr.end.x - 100:
				h["drift"].x *= -1.0
			if h["pos"].y < hr.position.y + 110 or h["pos"].y > hr.end.y - 110:
				h["drift"].y *= -1.0
			if is_instance_valid(h["sprite"]):
				h["sprite"].global_position = h["pos"]
		# Player effects. MP-12: a DOWNED/GHOST body is past hazard reach —
		# take_damage would no-op anyway, and the heal patch must not lift
		# a fallen player above 0 (the §5.3 paths own standing up).
		if not player.dead and not player.downed and not player.ghost \
				and player.global_position.distance_to(h["pos"]) <= h["radius"]:
			match h["type"]:
				"lava":
					player.take_damage(12.0, "magic")
				"churned":  # Sexton's grave-earth: imposed floor, phys, boss-only
					player.take_damage(9.0, "phys")
				"poison":
					player.take_damage(6.0, "true")
				"ice":
					player.hazard_speed = 1.35
				"slow":
					player.hazard_speed = 0.7
				"heal":
					if player.hp < player.max_hp:
						player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.02)
		# Enemies share physical patches (ice, slow, lava).
		if h["type"] in ["ice", "slow", "lava"]:
			for node in get_tree().get_nodes_in_group("enemies"):
				var e := node as Enemy
				if e == null or e.dying or e.global_position.distance_to(h["pos"]) > h["radius"]:
					continue
				match h["type"]:
					"ice":
						e.hazard_speed = 1.35
					"slow":
						e.hazard_speed = 0.75
					"lava":
						e.take_damage(5.0, Vector2.ZERO, false, true)

	# River wading (terrain mechanic, codex'd): everyone in the water
	# slows unless they're on the bridge. Entry splashes; wading ripples.
	var rv: Dictionary = rivers.get(cur_room, {})
	var wading := false
	if not rv.is_empty():
		var rect: Rect2 = rv["rect"]
		var bridge: Rect2 = rv["bridge"]
		if not player.dead and rect.has_point(player.global_position) \
				and not bridge.has_point(player.global_position):
			wading = true
			player.damp_time = Balance.DAMP_DURATION  # Damp: refreshes while wading, lingers after
			if not was_wading:
				sfx("splash")
				burst(player.global_position + Vector2(0, 14), Color(0.75, 0.85, 0.9), 8)
			elif randf() < 0.45:
				_ripple(player.global_position + Vector2(0, 14))
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and not e.dying and rect.has_point(e.global_position) \
					and not bridge.has_point(e.global_position):
				e.hazard_speed = minf(e.hazard_speed, Balance.RIVER_WADE_MULT)
	was_wading = wading

	# Grass rustle (visual pass): brushing past swaying decor (the wind
	# material marks it; water/planks are non-centered and skipped) kicks
	# a few leaves loose. Per-plant cooldown keeps it a whisper.
	if not player.dead and player.velocity.length() > 30.0:
		var scenery: Array = zone_scenery.get(cur_room, [])
		for i in range(scenery.size() - 1, -1, -1):
			# Ambience nodes free themselves (fled birds, riverless ripples)
			# while this cached list still holds them — prune, never cast.
			if not is_instance_valid(scenery[i]):
				scenery.remove_at(i)
				continue
			var ds := scenery[i] as Sprite2D
			if ds == null or ds.material == null or not ds.centered:
				continue
			if ds.global_position.distance_to(player.global_position) > 30.0:
				continue
			if Time.get_ticks_msec() < int(ds.get_meta("rustle_at", 0)):
				continue
			ds.set_meta("rustle_at", Time.get_ticks_msec() + 1200)
			burst(ds.global_position + Vector2(0, -6), Color(0.55, 0.8, 0.4), 3)
