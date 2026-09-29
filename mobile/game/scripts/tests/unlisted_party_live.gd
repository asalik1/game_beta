extends RefCounted
## Real Unlisted death and snapshot parity in shot_road_hunt's two-game fixture.
## --baseline records semantic failures without reporting a regression pass.
## The outer rig owns transports. Rebuilt worlds do not retain old Node ids.

const Recovery := preload("res://scripts/loot_recovery.gd")
const META_PATH := "user://meta.json"
const GAME_FIELDS := ["_meta", "_meta_loaded", "settings", "flags", "quest_kills",
	"unlisted_banked", "bounties", "bounty_day", "bounty_week", "contracts",
	"contract_day", "contract_claims_day", "vault_week", "vault_progress",
	"vault_claimed_week", "clock_anchor", "waking_week", "_waking_restore",
	"waking_kills", "waking_kills_week", "weekly_active", "weekly_week",
	"weekly_claimed_week", "achievements", "kill_counts", "boss_records",
	"mailbox", "dropped_loot", "convo_log", "convo_log_order", "splashes_seen",
	"run_time", "run_deaths", "run_elites", "run_secrets", "run_road_cards",
	"run_xp", "run_levels", "xp_capped_noted", "party_stats", "fight_stats",
	"party_stats_net", "fight_active", "fight_time", "fight_dmg_taken",
	"fight_potions", "fight_wipes", "fight_pool", "fight_names", "fight_titles",
	"fight_kinds", "fight_seen", "pending_tutorial", "terrain_event_t",
	"save_slot", "no_saves", "restoring_save", "guest_world", "state",
	"dev_god", "_host_lost_handled", "daily_last_day", "daily_streak",
	"capital_stock", "capital_bags", "capital_shop_day", "player_title",
	"fangmoot", "renown_cache_week", "shop_stock", "shop_bags", "_quest_avail_cache"]
const WIRE_FIELDS := ["last_snapshot", "last_award", "peer_chars", "world_ready",
	"_net_id_counter", "_vitals_sent", "_vitals_accum", "_appearance_sent",
	"_appearance_accum", "_stats_accum"]
const PLAYER_FIELDS := ["char_name", "cls", "level", "xp", "skill_points",
	"tree_points", "talent_loadouts", "active_talent_loadout", "attr_points",
	"unspent_attr", "gold", "ability_theme", "chroma", "skin", "equipped_pet",
	"rescued_pets", "resonance", "faction_standing", "npc_favor", "equipment",
	"backpack", "gem_bag", "bags", "loose_bags", "consumables", "materials",
	"potion_rotation", "active_potion", "depths_checkpoint", "run_tier",
	"profession", "mastery", "blueprints", "fishing_book", "tracked_quest",
	"swap_cost_step", "swap_week", "knows_alkahest", "hp", "mp", "cds",
	"hurt_cd", "pending_theme_note", "room_potions", "dead", "downed",
	"ghost", "velocity", "net_snaps"]


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func _wire(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


static func run(r: Node) -> String:
	var files := {}
	for base in [SaveGame.path(r.SLOT), SaveGame.path(r.SLOT + 1), SaveGame.path(r.SLOT + 2), META_PATH]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = String(base) + String(suffix)
			files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var keep: Array[Dictionary] = []
	var shown: Game = r.game
	var paused: bool = r.get_tree().paused
	var lobby_open: bool = r.get_node("/root/NetworkManager").lobby_open
	var report := {"baseline": r.flag("baseline"), "findings": [], "observations": {},
		"account_scope": "Independent Game meta caches; only the guest writes the shared isolated meta.json. This is not two physical account files."}
	var fatal := ""
	for i in r.readers.size():
		var g: Game = r.readers[i]
		var state := {"game": {}, "wire": {}, "player": {}, "meta": {},
			"processing": g.is_processing(), "physics": g.player.is_physics_processing(),
			"wire_physics": r.wires[i].is_physics_processing(), "online": r.roots[i].online,
			"position": g.player.global_position, "save": {}, "rng": {}, "peers": []}
		for key in GAME_FIELDS:
			state.game[key] = _copy(g.get(key))
		for key in PLAYER_FIELDS:
			state.player[key] = _copy(g.player.get(key))
		for key in WIRE_FIELDS:
			state.wire[key] = _copy(r.wires[i].get(key))
		for key in g.menus.get_meta_list():
			state.meta[key] = _copy(g.menus.get_meta(key))
		for key in ["loot_rng", "sfx_rng", "_float_rng"]:
			var rng: RandomNumberGenerator = g.get(key)
			state.rng[key] = [rng.seed, rng.state]
		for p in g.players:
			if p != g.local_player and is_instance_valid(p):
				state.peers.append({"node": p, "position": p.global_position,
					"level": p.level, "hp": p.hp, "mp": p.mp, "snaps": p.net_snaps.duplicate(true)})
		# The road fixture stops before its quarry/rewards. Reject a different
		# entry point rather than destroy a caller's live unopened reward Nodes.
		for node in g.get_children():
			if Recovery.earned_chest(g, node) or Recovery.earned_coin(g, node):
				fatal = "Unlisted fixture must start before earned chest/coin drops exist"
		if not g.dropped_loot.is_empty():
			fatal = "Unlisted fixture must start without registered ground loot"
		if not r.wires[i].net_enemies.is_empty():
			fatal = "Unlisted fixture must start before original network enemies exist"
		keep.append(state)
	var rebuilt := false
	if fatal == "":
		for i in r.readers.size():
			var g: Game = r.readers[i]
			var character := SaveGame._character_section(g).duplicate(true)
			SaveGame.write(g, r.SLOT + 1 + i)
			var saved := SaveGame.read(r.SLOT + 1 + i)
			if saved.is_empty():
				fatal = "could not snapshot the Unlisted fixture's original world"
			else:
				saved["character"] = character
				keep[i].save = saved
	if fatal == "":
		rebuilt = true
		fatal = await _checks(r, report)
		if fatal != "":
			await r._capture("unlisted_party_failure")
	var cleanup := await _restore(r, keep, files, shown, paused, lobby_open, rebuilt)
	if cleanup != "":
		fatal = cleanup if fatal == "" else fatal + "; " + cleanup
	report["fatal"] = fatal
	report["restored"] = cleanup == ""
	report["status"] = "fixture_failed" if fatal != "" else "baseline_findings" if report.baseline and not report.findings.is_empty() else "baseline_no_findings" if report.baseline else "failed" if not report.findings.is_empty() else "passed"
	var output: String = r.shot_dir.path_join("unlisted_party.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		return "could not write Unlisted party observations: " + fatal
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("UNLISTED PARTY AUDIT: ", JSON.stringify(report))
	if fatal != "":
		return fatal
	if report.baseline:
		print("BASELINE ONLY: Unlisted party findings=", report.findings.size(), "; no regression pass claimed")
		return ""
	if not report.findings.is_empty():
		return "; ".join(report.findings)
	print("ok: real Unlisted guest premium/world completion, exact guest home/account ownership and authoritative snapshot replacement")
	return ""


static func _restore(r: Node, keep: Array[Dictionary], files: Dictionary,
		shown: Game, paused: bool, lobby_open: bool, rebuilt: bool) -> String:
	# Stop new packets and owner writes before deferred drops/world teardown.
	for i in r.readers.size():
		var g: Game = r.readers[i]
		g.no_saves = true
		g.restoring_save = true
		g.set_process(false)
		g.player.set_physics_process(false)
		r.wires[i].set_physics_process(false)
		r.wires[i].world_ready = false
		r.roots[i].online = false
		g.menus.close()
		g.chapter_finale.cancel(g)
	r.get_tree().paused = false
	await r.frames(3)
	for i in r.readers.size():
		var g: Game = r.readers[i]
		if rebuilt and not keep[i].save.is_empty():
			Recovery.retire_live(g)
			g.retire_dropped_loot()
			g.dropped_loot = []
			var saved: Dictionary = keep[i].save
			var world := SaveGame.world_of(saved)
			g.wander_seed = int(world.wander_seed)
			g.unlisted_banked = _copy(keep[i].game.unlisted_banked)
			g.flags = SaveGame.flags_of(saved).duplicate(true)
			g._waking_restore = int(world.get("waking_week", -1))
			g.switch_chapter(String(saved.chapter), true)
			SaveGame.apply(g, saved)
			# The old world/mirror Nodes have retired; never retain invalid refs.
			r.wires[i].net_enemies.clear()
		for key in GAME_FIELDS:
			if key not in ["no_saves", "restoring_save"]:
				g.set(key, _copy(keep[i].game[key]))
		for key in PLAYER_FIELDS:
			g.player.set(key, _copy(keep[i].player[key]))
		g.player.global_position = keep[i].position
		for peer in keep[i].peers:
			var p: Player = peer.node
			if is_instance_valid(p):
				p.level = peer.level
				p.recalc()
				p.hp = peer.hp
				p.mp = peer.mp
				p.global_position = peer.position
				p.net_snaps = peer.snaps
		for key in g.menus.get_meta_list():
			g.menus.remove_meta(key)
		for key in keep[i].meta:
			g.menus.set_meta(key, _copy(keep[i].meta[key]))
		g.refresh_touch_mode()
		g._apply_touch_mode()
	await r.frames(3)
	# Restore RNG only after save-apply/loot rebuilds have finished sampling it.
	for i in r.readers.size():
		var g: Game = r.readers[i]
		for key in keep[i].rng:
			var rng: RandomNumberGenerator = g.get(key)
			rng.seed = int(keep[i].rng[key][0])
			rng.state = int(keep[i].rng[key][1])
	var errors: Array[String] = []
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				errors.append("could not remove fixture file " + String(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				errors.append("could not restore fixture file " + String(path))
			else:
				file.store_buffer(files[path])
				file.close()
				if FileAccess.get_file_as_bytes(path) != files[path]:
					errors.append("fixture file bytes changed after restoration: " + String(path))
	# No awaits after restoring live writers; the outer rig owns final teardown.
	for i in r.readers.size():
		var g: Game = r.readers[i]
		# Child HUD clocks can read trusted_now during the final cleanup frames.
		# Reapply the captured data after those frames, before writers resume.
		for key in GAME_FIELDS:
			if key not in ["no_saves", "restoring_save"]:
				g.set(key, _copy(keep[i].game[key]))
		for key in PLAYER_FIELDS:
			g.player.set(key, _copy(keep[i].player[key]))
		for key in WIRE_FIELDS:
			r.wires[i].set(key, _copy(keep[i].wire[key]))
		g.no_saves = keep[i].game.no_saves
		g.restoring_save = keep[i].game.restoring_save
		g.set_process(keep[i].processing)
		g.player.set_physics_process(keep[i].physics)
		r.roots[i].online = keep[i].online
		r.wires[i].set_physics_process(keep[i].wire_physics)
		if g == shown:
			r._show(i)
	r.get_node("/root/NetworkManager").lobby_open = lobby_open
	r.get_tree().paused = paused
	return "; ".join(errors)


static func _prepare_rewards(g: Game) -> void:
	# Each Game represents an owner. Only the guest has saves enabled; its
	# account write is real but shares this process's isolated user:// directory.
	g._meta = g._meta.duplicate(true)
	g._meta["renown"] = 100
	g._meta["renown_hint"] = true
	g._meta_loaded = true
	g.player.faction_standing = g.player.faction_standing.duplicate(true)
	g.player.faction_standing["wildfang"] = 0
	g.player.bags = [Items.make_bag("F")]
	g.player.backpack = []
	g.player.gem_bag = []
	g.player.consumables = []
	g.player.materials = []
	g.player.loose_bags = []
	g.bounties = []
	g._roll_bounties("daily", Balance.BOUNTY_DAILY_COUNT, 84)
	g._roll_bounties("weekly", Balance.BOUNTY_WEEKLY_COUNT, 84)
	for entry in g.bounties:
		entry.done = true
		entry.progress = entry.target
	g.bounty_day = g.daily_day_index()
	g.bounty_week = g._week_index()
	g.vault_claimed_week = g._week_index()
	g._meta_write()
	g.autosave()


static func _room(g: Game, id: String) -> int:
	for i in g.zones.size():
		if String(g.zones[i].get("unlisted", "")) == id:
			return i
	return -1


static func _boss(g: Game, room: int) -> Boss:
	for candidate in g.bosses:
		if is_instance_valid(candidate) and not candidate.dying and candidate.zone_idx == room:
			return candidate
	return null


static func _premium(g: Game) -> Dictionary:
	var ground_gems := 0
	for payload in g.dropped_loot:
		ground_gems += int(String(payload.get("kind", "")) == "gem")
	return {"bank": g.unlisted_banked.duplicate(), "renown": g.renown(),
		"wildfang": int(g.player.faction_standing.get("wildfang", 0)),
		"bag_gems": g.player.gem_bag.size(), "ground_gems": ground_gems}


static func _owner(g: Game) -> Dictionary:
	return {"gold": g.player.gold, "renown": g.renown(),
		"gems": g.player.gem_bag.duplicate(true), "standing": g.player.faction_standing.duplicate(true),
		"mail": g.mailbox.duplicate(true), "drops": g.dropped_loot.duplicate(true)}


static func _rebrief(r: Node) -> bool:
	var g: Game = r.readers[1]
	var prior := g.world.get_instance_id()
	r.wires[0]._send_snapshot(r.apis[1].get_unique_id())
	var ready: bool = await r._until(func() -> bool:
		return g.world.get_instance_id() != prior and r.wires[1].world_ready and g.guest_world, 15.0)
	if ready:
		g.player.set_physics_process(false)
		g.terrain_event_t = 10000.0
		await r.frames(6)
	return ready


static func _checks(r: Node, report: Dictionary) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var home := SaveGame.world_of(SaveGame.read(r.SLOT)).duplicate(true)
	var seed_value := -1
	for candidate_seed in 160:
		host.wander_seed = candidate_seed
		for zone in host._unlisted_inject(Story.chapter("ch3").zones, "ch3"):
			if String(zone.get("unlisted", "")) == "greymantle":
				seed_value = candidate_seed
				break
		if seed_value >= 0:
			break
	if seed_value < 0:
		return "no generated ch3 Greymantle in the bounded seed sweep"
	for g in [host, guest]:
		g.menus.close()
		g.settings = g.settings.duplicate(true)
		g.settings["camera_shake"] = 0.0
		g.settings["combat_framing"] = false
		g.settings["hit_stop"] = false
		g.dev_god = true
		g.terrain_event_t = 10000.0
		g.unlisted_banked = []
	host.wander_seed = seed_value
	host.switch_chapter("ch3", true)
	host.player.set_physics_process(false)
	r._show(0)
	await r.skip_dialogue()
	if not await _rebrief(r):
		return "Unlisted host world did not reach the admitted guest"
	var room := _room(host, "greymantle")
	if room < 0 or _room(guest, "greymantle") != room:
		return "the seeded Unlisted room differs across the actual worlds"
	for i in 2:
		var g: Game = r.readers[i]
		r._show(i)
		await r.skip_dialogue()
		g.player.set_physics_process(false)
		g.terrain_event_t = 10000.0
		_prepare_rewards(g)
		g.player.global_position = g.room_center(room) + Vector2(-180, 140)
		g._enter_room(room)
		var local_boss := _boss(g, room)
		if local_boss != null:
			local_boss.set_physics_process(false)
	var pid: int = r.apis[1].get_unique_id()
	if not await r._until(func() -> bool:
		var shell: Player = r._shell(0, pid)
		return shell != null and host.room_at_pos(shell.global_position) == room and _boss(guest, room) != null, 12.0):
		return "present guest position or real Unlisted boss mirror never reached ENet"
	var boss := _boss(host, room)
	if boss == null or boss.unlisted_id != "greymantle" or boss.story_boss \
		or boss.display_name != String(Unlisted.entry("greymantle").name):
		return "the host did not build the actual named Unlisted guardian"
	boss.set_physics_process(false)
	var mirror := _boss(guest, room)
	mirror.set_physics_process(false)
	var before_host := _premium(host)
	var before_guest := _premium(guest)
	var before_story := [host.boss_done.duplicate(true), guest.boss_done.duplicate(true)]
	var guest_gold := guest.player.gold
	r.wires[1].last_award = []
	report.observations["encounter"] = {"seed": seed_value, "chapter": "ch3", "room": room,
		"id": boss.unlisted_id, "host_name": boss.display_name, "guest_name": mirror.display_name,
		"host_present": host.room_at_pos(host.player.global_position) == room,
		"guest_present_on_host": host.room_at_pos(r._shell(0, pid).global_position) == room}
	r._show(0)
	await r._capture("unlisted_party_01_host_real_guardian")
	r._show(1)
	await r._capture("unlisted_party_02_guest_real_mirror")
	boss.take_damage(boss.max_hp * 100.0, Vector2.RIGHT, false, true)
	if not await r._until(func() -> bool: return host.unlisted_banked_has("greymantle"), 8.0):
		return "actual Unlisted death did not settle on its authoritative host"
	await r.get_tree().create_timer(0.7, true).timeout
	var after_host := _premium(host)
	var after_guest := _premium(guest)
	report.observations["live_death"] = {"host_before": before_host, "host_after": after_host,
		"guest_before": before_guest, "guest_after": after_guest,
		"guest_generic_award": r.wires[1].last_award.duplicate(true),
		"guest_gold_delta": guest.player.gold - guest_gold}
	if int(after_host.renown) - int(before_host.renown) != Balance.RENOWN_UNLISTED \
		or int(after_host.wildfang) - int(before_host.wildfang) != Balance.UNLISTED_GREY_WILDFANG \
		or int(after_host.bag_gems) + int(after_host.ground_gems) != 1:
		return "Unlisted baseline lost the host's established exact premium positive control"
	if r.wires[1].last_award.is_empty():
		return "actual death delivered no generic award positive control to the guest"
	if not guest.unlisted_banked_has("greymantle"):
		report.findings.append("present guest received no live Unlisted world completion")
	if int(after_guest.renown) - int(before_guest.renown) != Balance.RENOWN_UNLISTED:
		report.findings.append("present guest received no exact Unlisted Renown premium")
	if int(after_guest.wildfang) - int(before_guest.wildfang) != Balance.UNLISTED_GREY_WILDFANG:
		report.findings.append("present guest received no exact Greymantle Wildfang standing")
	if int(after_guest.bag_gems) + int(after_guest.ground_gems) != 1:
		report.findings.append("present guest received no single guaranteed Unlisted gem")
	if [host.boss_done, guest.boss_done] != before_story:
		return "the Unlisted death changed an ordinary campaign boss completion"
	guest.autosave()
	var saved := SaveGame.read(r.SLOT)
	var character := SaveGame.character_of(saved)
	if SaveGame.world_of(saved) != home:
		return "Unlisted guest reward changed its saved home world"
	if _wire(character.get("faction_standing", {})) != _wire(guest.player.faction_standing) \
		or _wire(character.get("gem_bag", [])) != _wire(guest.player.gem_bag):
		return "guest save did not retain its exact standing and bag gem state"
	var account := SaveGame.read_json(META_PATH)
	if int(account.get("renown", -1)) != guest.renown():
		return "guest's isolated account file disagrees with its own Renown cache"
	report.observations["guest_save"] = {"home_unchanged": true, "account_renown": account.get("renown"),
		"saved_standing": character.get("faction_standing"), "saved_gems": character.get("gem_bag")}
	r._show(0)
	await r._capture("unlisted_party_03_host_settlement")
	r._show(1)
	await r._capture("unlisted_party_04_guest_settlement")
	# Recover the already-earned generic chest/pile before comparing rejoin
	# rewards; ordinary loot recovery is not a retroactive Unlisted premium.
	Recovery.recover_live(guest)
	guest.flush_dropped_loot()
	guest.autosave()
	await r.frames(3)
	var own_before := _owner(guest)
	guest.unlisted_banked = [] # Controlled fresh-reader world-state precondition.
	if not await _rebrief(r):
		return "completed Unlisted world rebrief failed"
	var completed_bank := guest.unlisted_banked.duplicate()
	if not guest.unlisted_banked_has("greymantle"):
		report.findings.append("completed-world snapshot omitted the host's Unlisted bank")
	if _wire(_owner(guest)) != _wire(own_before):
		return "completed-world snapshot replayed or lost personal rewards"
	report.observations["completed_snapshot"] = {"host_bank": host.unlisted_banked.duplicate(),
		"guest_bank": completed_bank, "snapshot_has_bank": r.wires[1].last_snapshot.has("unlisted_banked"),
		"owner_rewards_unchanged": true}
	await r._capture("unlisted_party_05_completed_world_rebrief")
	# A genuinely rebuilt fresh run must replace an old local completion list.
	# Keeping a valid prior-world id here detects merge/omission, not fake credit.
	host.reset_run_stats()
	host.wander_seed = seed_value
	host.switch_chapter("ch3", true)
	host.player.set_physics_process(false)
	host.terrain_event_t = 10000.0
	guest.unlisted_banked = ["greymantle"]
	if not await _rebrief(r):
		return "fresh Unlisted world rebrief failed"
	if not guest.unlisted_banked.is_empty():
		report.findings.append("fresh-world snapshot retained the guest's stale Unlisted bank")
	if SaveGame.world_of(SaveGame.read(r.SLOT)) != home:
		return "Unlisted world rebrief changed the guest's saved home world"
	report.observations["fresh_snapshot"] = {"host_bank": host.unlisted_banked.duplicate(),
		"guest_bank": guest.unlisted_banked.duplicate(), "home_unchanged": true}
	await r._capture("unlisted_party_06_fresh_world_rebrief")
	return ""
