extends RefCounted
## DRAFT: party quest mirrors through the separate party_quests paired adapter.
## Compile/baseline not run; no protected road-hunt file is used or edited.
## --baseline records semantic failures without reporting a regression pass.
## The outer rig owns transports. Rebuilt worlds do not retain old Node ids.

const Recovery := preload("res://scripts/loot_recovery.gd")
const META_PATH := "user://meta.json"
const GAME_FIELDS := ["_meta", "_meta_loaded", "settings", "quest_key", "talked_to_elder", "flags", "quest_kills",
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
const WIRE_FIELDS := ["_beat_claims", "_convo_claims", "_spectate_initiator", "_active_convo_id", "last_snapshot", "last_award", "peer_chars", "world_ready",
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
				fatal = "party quest fixture must start before earned chest/coin drops exist"
		if not g.dropped_loot.is_empty():
			fatal = "party quest fixture must start without registered ground loot"
		if not r.wires[i].net_enemies.is_empty():
			fatal = "party quest fixture must start before original network enemies exist"
		keep.append(state)
	var rebuilt := false
	if fatal == "":
		for i in r.readers.size():
			var g: Game = r.readers[i]
			var character := SaveGame._character_section(g).duplicate(true)
			SaveGame.write(g, r.SLOT + 1 + i)
			var saved := SaveGame.read(r.SLOT + 1 + i)
			if saved.is_empty():
				fatal = "could not snapshot the party quest fixture's original world"
			else:
				saved["character"] = character
				keep[i].save = saved
	if fatal == "":
		rebuilt = true
		fatal = await _checks(r, report)
		if fatal != "":
			await r._capture("party_quest_fixture_failure")
	var cleanup := await _restore(r, keep, files, shown, paused, lobby_open, rebuilt)
	if cleanup != "":
		fatal = cleanup if fatal == "" else fatal + "; " + cleanup
	report["fatal"] = fatal
	report["restored"] = cleanup == ""
	report["status"] = "fixture_failed" if fatal != "" else "baseline_findings" if report.baseline and not report.findings.is_empty() else "baseline_no_findings" if report.baseline else "failed" if not report.findings.is_empty() else "passed"
	var output: String = r.shot_dir.path_join("party_quests.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		return "could not write party quest observations: " + fatal
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PARTY QUEST AUDIT: ", JSON.stringify(report))
	if fatal != "":
		return fatal
	if report.baseline:
		print("BASELINE ONLY: party quest findings=", report.findings.size(), "; no regression pass claimed")
		return ""
	if not report.findings.is_empty():
		return "; ".join(report.findings)
	print("ok: party quest counter/main brief, open journal and guest-driven beat authority")
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
			if not is_instance_valid(peer.node):
				continue  # the restored world retired the original remote shell
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


## Appended to the established snapshot/restore wrapper by prepare_native_draft.py.
## Baseline-safe: newly proposed methods are invoked dynamically, only if present.
const QUEST := "hunters_rounds"
const COUNTER := "hunter_pack_thinned"

class DriverRoot extends Node:
	var peers := {}
	func is_online() -> bool: return true

class DriverGame extends Game:
	func _ready() -> void: set_process(false)
	func net_online() -> bool: return true
	func refresh_quest() -> void: pass

class DriverSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass


static func _observe(report: Dictionary, id: String, good: bool, detail: Variant) -> void:
	report.observations[id] = {"pass": good, "detail": detail}
	if not good:
		report.findings.append(id)


static func _text(root: Node) -> String:
	if not is_instance_valid(root):
		return ""
	var lines: Array[String] = []
	for child in root.find_children("*", "Label", true, false):
		lines.append(child.text)
	return "\n".join(lines)


static func _wait(r: Node, seconds := 0.5) -> void:
	await r.get_tree().create_timer(seconds, true).timeout


static func _ledger(g: Game) -> Array:
	return [g.player.gold, g.player.xp, g.flags.duplicate(true),
		g.player.backpack.duplicate(true), g.player.gem_bag.duplicate(true),
		g.mailbox.duplicate(true), g.loot_rng.state, g.player.materials.duplicate(true),
		g.player.consumables.duplicate(true), g.player.faction_standing.duplicate(true),
		g.player.mastery.duplicate(true), g.player.blueprints.duplicate()]


static func _checks(r: Node, report: Dictionary) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var wire: Node = r.wires[0]
	var guest_wire: Node = r.wires[1]
	var pid: int = r.apis[1].get_unique_id()
	report["controlled_setup"] = "Two rendered chapter-1 Games reuse the appearance rig's paired boot through a separate adapter, without running appearance checks. Quest acceptance/landmarks and partial counters are explicitly seeded. Counter advance invokes production quest_kill_note, not simulated combat. Sibling beat driver is a lightweight third Game/socket with a manually seeded admitted live claim; no third rendered world or authored conversation is claimed."
	for g in [host, guest]:
		g.set_process(false)
		g.player.set_physics_process(false)
		g.no_saves = true
		g.flags = g.flags.duplicate(true)
		g.flags["sq_on_" + QUEST] = true
		g.flags.erase("sq_paid_" + QUEST)
		g.flags.erase(COUNTER)
		for step in Story.ALL_SIDE_QUESTS[QUEST].steps:
			if String(step.get("kind", "flag")) != "kill":
				g.flags[String(step.flag)] = true
		g._quest_avail_cache = -1
		g.player.tracked_quest = QUEST
		r.wires[r.readers.find(g)].set_physics_process(false)
	# Persist only the tracked choice into the existing guest home. Its world,
	# including its own main key/counters, must survive every brief and save.
	SaveGame.write_character_home(guest, r.SLOT)
	var home := SaveGame.world_of(SaveGame.read(r.SLOT)).duplicate(true)
	# Exercise normal guest autosave routing as well as the explicit home write.
	# The entry has already required an isolated directory and owns byte cleanup.
	guest.no_saves = false
	host.quest_kills = {COUNTER: 1}
	host.quest_key = "fangmaw"
	guest.quest_kills = {"guest_home_sentinel": 71}
	guest.quest_key = "talk"
	var previous_world: int = guest.world.get_instance_id()
	wire._send_snapshot(pid)
	# No await: change host state AFTER the sent brief but BEFORE join_ready.
	host.quest_kills = {COUNTER: 2}
	host.quest_key = "morwen"
	if not await r._until(func() -> bool: return guest.world.get_instance_id() != previous_world and guest_wire.world_ready, 15.0):
		return "party quest world rebrief never completed"
	await _wait(r)
	_observe(report, "late_join_ready_progress", guest.quest_kills == {COUNTER: 2}, guest.quest_kills.duplicate(true))
	_observe(report, "late_join_ready_main", guest.quest_key == "morwen", guest.quest_key)
	_observe(report, "initial_brief_fields", guest_wire.last_snapshot.get("quest_kills") == {COUNTER: 1}
		and guest_wire.last_snapshot.get("quest_key") == "fangmaw", guest_wire.last_snapshot.keys())
	r._show(1)
	guest.menus.open_journal("quests")
	await r._capture("quest_01_late_join_journal")
	var private_error := await _private_maren_probe(r, report)
	if private_error != "":
		return private_error
	# Isolate watcher/display findings from the missing baseline wire fields.
	# This corrective baseline fixture is explicitly recorded, not called sync.
	host.quest_kills = {COUNTER: 1}
	host.quest_key = "fangmaw"
	guest.quest_kills = {COUNTER: 1}
	guest.quest_key = "fangmaw"
	guest.menus.open_journal("quests")
	await r.frames(3)
	var scroll := guest.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	var track := guest.menus.root.find_child("TrackQuest_" + QUEST, true, false) as Button
	if scroll == null or track == null:
		return "controlled hunter quest card was missing from the journal"
	track.grab_focus()
	await r.frames(2)
	scroll.scroll_vertical = mini(160, int(maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)))
	var offset := scroll.scroll_vertical
	var shell_id: int = guest.menus.root.get_instance_id()
	var local_before := [host.quest_kills.duplicate(true), guest.quest_kills.duplicate(true), _ledger(host), _ledger(guest)]
	guest.quest_kill_note("wolf")
	await _wait(r)
	_observe(report, "guest_local_kill_is_read_only", [host.quest_kills, guest.quest_kills, _ledger(host), _ledger(guest)] == local_before,
		"guest quest_kill_note cannot advance either counter or pay either owner")
	host.quest_kill_note("wolf")
	await _wait(r)
	_observe(report, "live_counter_delivery", guest.quest_kills.get(COUNTER) == 2, guest.quest_kills.duplicate(true))
	if report.baseline:
		guest.quest_kills[COUNTER] = 2  # controlled watcher probe on known missing mirror
		await _wait(r)
	var next_scroll := guest.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	var focus: Control = guest.get_viewport().gui_get_focus_owner()
	_observe(report, "open_journal_partial_text", "(2 / 3)" in _text(guest.menus.root), _text(guest.menus.root))
	_observe(report, "watcher_rebuilt_on_change", guest.menus.root.get_instance_id() != shell_id,
		{"old": shell_id, "new": guest.menus.root.get_instance_id()})
	_observe(report, "watcher_kept_view", next_scroll != null and next_scroll.scroll_vertical == offset
		and focus != null and String(focus.name) == "TrackQuest_" + QUEST,
		{"scroll": next_scroll.scroll_vertical if next_scroll != null else -1, "expected": offset,
		"focus": String(focus.name) if focus != null else ""})
	await r._capture("quest_02_open_journal_live_count")
	guest.menus.close()
	guest.hud.wayfinder._sample_quest()
	_observe(report, "tracked_hud_count", "(2/3)" in guest.hud.wayfinder.quest_objective.text,
		guest.hud.wayfinder.quest_objective.text)
	await r._capture("quest_03_tracked_count")
	guest.settings = guest.settings.duplicate(true)
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	guest.menus.open_journal("quests")
	await r._capture("quest_04_touch_journal")
	var beat_error := await _beat_probe(r, report)
	if beat_error != "":
		return beat_error
	# Malformed authority data must leave both display fields and reward ledgers
	# untouched. New method is absent on baseline, so do not generate RPC errors.
	if wire.has_method("host_quest_progress"):
		var mirror_before := [guest.quest_kills.duplicate(true), guest.quest_key]
		var ledger_before := _ledger(guest)
		# Every packet carries a different valid companion field. Wrong-context
		# packets differ in BOTH fields, so accepting one cannot be invisible.
		# Observe each arrival before sending the next; no later packet can erase
		# a recorded failure. Reset only the posed display between independent cases.
		var cases := [
			{"id": "negative_count", "fields": {"quest_kills": {COUNTER: -1}}},
			{"id": "float_count", "fields": {"quest_kills": {COUNTER: 2.0}}},
			{"id": "nonboolean_counts_only", "fields": {"counts_only": 1}},
			{"id": "unknown_count", "fields": {"quest_kills": {"unknown": 1}}},
			{"id": "unknown_key", "fields": {"quest_key": "unknown"}},
			{"id": "wrong_seed", "fields": {"wander_seed": host.wander_seed + 1}},
			{"id": "wrong_chapter", "fields": {"chapter": "ch2"}}]
		var all_invalid_rejected := true
		for example in cases:
			guest.quest_kills = mirror_before[0].duplicate(true)
			guest.quest_key = mirror_before[1]
			var bad := {"chapter": host.chapter_id, "wander_seed": host.wander_seed,
				"quest_key": "vargoth", "quest_kills": {COUNTER: 0}}
			bad.merge(example.fields, true)
			wire.rpc_id(pid, "_rpc_quest_progress", bad)
			await _wait(r)
			var rejected: bool = [guest.quest_kills, guest.quest_key] == mirror_before and _ledger(guest) == ledger_before
			all_invalid_rejected = rejected and all_invalid_rejected
			_observe(report, "invalid_mirror_" + String(example.id), rejected,
				{"packet": bad, "expected": mirror_before, "actual": [guest.quest_kills.duplicate(true), guest.quest_key],
				"ledger_unchanged": _ledger(guest) == ledger_before, "display_reset_before_each": true})
		_observe(report, "invalid_mirror_is_atomic", all_invalid_rejected, "seven separately observed packets; every wrong-context payload differs from the retained display")
		wire.call("host_quest_progress")
		await _wait(r)
		var unchanged_shell: int = guest.menus.root.get_instance_id()
		wire.call("host_quest_progress")
		await _wait(r)
		_observe(report, "duplicate_no_rebuild_or_reward", guest.menus.root.get_instance_id() == unchanged_shell
			and _ledger(guest) == ledger_before, unchanged_shell)
	else:
		report.observations["invalid_mirror_is_atomic"] = {"covered": false, "reason": "new authority mirror does not exist on baseline"}
	# Existing flags still complete/pay the quest. The new state mirror does
	# not own this event, and repeated kill calls/payloads must not repay it.
	host.quest_kill_note("wolf")
	if not await r._until(func() -> bool: return host.get_flag("sq_paid_" + QUEST, false) and guest.get_flag("sq_paid_" + QUEST, false)):
		return "existing completion flag path did not settle the controlled quest"
	var settled := [_ledger(host), _ledger(guest)]
	host.quest_kill_note("wolf")
	if wire.has_method("host_quest_progress"):
		wire.call("host_quest_progress")
	await _wait(r)
	_observe(report, "completion_still_once", [_ledger(host), _ledger(guest)] == settled, host.quest_kills.duplicate(true))
	await r._capture("quest_05_completed_journal")
	var boss_error := await _boss_probe(r, report)
	if boss_error != "":
		return boss_error
	# Exercise the real travel receiver with the same seeded chapter and an
	# explicit empty table; the caller does not claim an authored chapter exit.
	host.quest_kills = {}
	host.quest_key = "vargoth"
	previous_world = guest.world.get_instance_id()
	wire.host_advance_party()
	if not await r._until(func() -> bool: return guest.world.get_instance_id() != previous_world, 15.0):
		return "same-seed party travel did not rebuild the guest"
	await _wait(r)
	_observe(report, "travel_replaces_empty_and_main", guest.quest_kills.is_empty() and guest.quest_key == "vargoth",
		{"counts": guest.quest_kills.duplicate(true), "key": guest.quest_key})
	guest.menus.close()
	guest.autosave()
	SaveGame.write_character_home(guest, r.SLOT)
	_observe(report, "guest_home_world_unchanged", SaveGame.world_of(SaveGame.read(r.SLOT)) == home,
		{"home_key": home.get("quest_key"), "home_counts": home.get("quest_kills", {})})
	return ""



## Controlled callback integration, not a keyboard/mouse dialogue playthrough.
## Use the actual live Maren entry, private claim, authored three-line conversation
## and its production after-callback; only setup acceptance/opening flags are posed.
static func _private_maren_probe(r: Node, report: Dictionary) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var guest_wire: Node = r.wires[1]
	var convo_id := "maren_" + guest.player.cls
	if guest.chapter_id != "ch1" or guest.player.cls != "mage" \
			or not is_instance_valid(guest.elder) or not Story.ALL_CONVOS.has(convo_id):
		return "private Maren control requires the real chapter-1 mage village entry"
	if guest._convo_is_beat(Story.ALL_CONVOS[convo_id]):
		return "authored Maren route changed to a shared beat; private-callback control is stale"
	var action := Callable()
	for entry in guest.interactables:
		if entry.get("node") == guest.elder:
			action = entry.get("action", Callable())
			break
	if not action.is_valid():
		return "live Maren entry has no callable production interaction"
	guest.menus.close()
	if guest.hud.dialogue_active or guest.hud.choices_active or guest_wire._active_convo_id != "":
		return "private Maren control requires a clear dialogue and claim before invoking the live entry"
	for g in [host, guest]:
		g.quest_key = "talk"
		g.quest_kills = {COUNTER: 1}
		g.flags.erase("met_elder")
	guest.talked_to_elder = false
	guest.flags["opened_mage"] = true
	guest.refresh_quest()
	action.call()
	if not await r._until(func() -> bool: return guest.hud.dialogue_active):
		return "actual private Maren claim did not reach its authored dialogue"
	if guest.beat_broadcasting or guest_wire._active_convo_id != convo_id:
		return "Maren control did not hold the expected private conversation claim"
	# Established ShotRig completion helper drives the production HUD callbacks.
	# It is explicitly not ordinary input or a manually invoked reward callback.
	await r.skip_dialogue(8)
	if guest.hud.dialogue_active or guest.hud.choices_active:
		return "private Maren authored dialogue did not finish within its bounded lines"
	if not await r._until(func() -> bool: return host.get_flag("met_elder", false) and not r.wires[0]._convo_claims.has(convo_id)):
		return "private Maren flag or claim release did not reach the host"
	if guest.quest_key != "fangmaw" or host.quest_key != "talk" or guest.beat_broadcasting:
		return "private Maren callback did not establish the source-predicted independent main keys"
	var ledger := [_ledger(host), _ledger(guest)]
	host.quest_kill_note("wolf")
	await _wait(r)
	_observe(report, "private_maren_main_survives_counter", guest.quest_key == "fangmaw"
		and host.quest_key == "talk", {"host_key": host.quest_key, "guest_key": guest.quest_key,
		"beat_broadcasting": guest.beat_broadcasting, "invoked_live_entry": true,
		"dialogue_completion": "bounded ShotRig.skip_dialogue; no ordinary-input claim"})
	_observe(report, "private_maren_counter_still_delivered", guest.quest_kills.get(COUNTER) == 2,
		guest.quest_kills.duplicate(true))
	_observe(report, "private_maren_counter_grants_nothing", [_ledger(host), _ledger(guest)] == ledger,
		"retained ledger starts after the real private callback; kill advances 1 to 2 below payout threshold")
	guest.menus.open_journal("quests")
	_observe(report, "private_maren_visible_main", Story.quest_text("fangmaw") in _text(guest.menus.root),
		_text(guest.menus.root))
	await r._capture("quest_01b_private_maren_after_counter")
	return ""

static func _beat_probe(r: Node, report: Dictionary) -> String:
	# A real third ENet peer drives the existing completion method, while the
	# original rendered guest is the sibling spectator under inspection.
	var root := DriverRoot.new()
	root.name = "QuestDriver"
	r.add_child(root)
	var api := MultiplayerAPI.create_default_interface()
	r.get_tree().set_multiplayer(api, root.get_path())
	var driver_game := DriverGame.new()
	driver_game.name = "Game"
	driver_game.chapter_id = r.readers[0].chapter_id
	driver_game.wander_seed = r.readers[0].wander_seed
	driver_game.play_started = true
	driver_game.quest_key = "morwen"
	root.add_child(driver_game)
	var driver := DriverSession.new()
	driver.name = "Session"
	driver.game = driver_game
	driver.world_ready = true
	root.add_child(driver)
	var transport := ENetMultiplayerPeer.new()
	var error := ""
	var driver_pid := 0
	if transport.create_client("127.0.0.1", r.transports[0].host.get_local_port()) != OK:
		error = "third quest driver could not connect"
	else:
		api.multiplayer_peer = transport
		if not await r._until(func() -> bool: return api.get_unique_id() > 1 and transport.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
			error = "third quest driver handshake timed out"
		else:
			driver_pid = api.get_unique_id()
			root.peers[1] = {}
			r.roots[0].peers[driver_pid] = {}
			r.wires[0].peer_chars[driver_pid] = {"name": "Quest driver", "cls": "mage", "level": 1}
			error = await _beat_checks(r, report, driver, driver_pid)
	# Every failure returns through cleanup; the outer wrapper restores claims,
	# ledgers, world/save state and the original two peers afterward.
	if driver_pid > 0:
		r.roots[0].peers.erase(driver_pid)
		r.wires[0].peer_chars.erase(driver_pid)
	transport.close()
	api.multiplayer_peer = null
	r.get_tree().set_multiplayer(null, root.get_path())
	root.queue_free()
	await r.frames(3)
	return error


static func _beat_checks(r: Node, report: Dictionary, driver: Node, pid: int) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var wire: Node = r.wires[0]
	var claim := "qa_party_quest_beat"
	host.quest_key = "fangmaw"
	guest.quest_key = "fangmaw"
	guest.menus.open_journal("quests")
	var before := [_ledger(host), _ledger(guest)]
	wire._convo_claims[claim] = pid
	wire._begin_beat_spectate(claim, pid)
	if not await r._until(func() -> bool: return r.wires[1]._spectate_initiator == pid):
		return "sibling guest never received beat-start authority"
	# Admission and a live claim still must not admit an unauthored main key.
	# Baseline accepts this; restore only the posed text before the ordering probe.
	driver.rpc_id(1, "_rpc_beat_quest", "qa_not_an_authored_quest")
	await _wait(r)
	_observe(report, "active_owner_unknown_key_rejected", host.quest_key == "fangmaw" and [_ledger(host), _ledger(guest)] == before,
		{"received_key": host.quest_key, "setup_reset_after_observation": true})
	host.quest_key = "fangmaw"
	guest.quest_key = "fangmaw"
	# Controlled overlap: the driver has already read an authored quest node,
	# but has not closed its final line. A real host progress call must update
	# counters while preserving that pending key. No authored dialogue/combat
	# playthrough is claimed by these explicit claim/key/count setup assignments.
	driver.game.quest_key = "morwen"
	driver.game.beat_broadcasting = true
	driver.game.quest_kills = {COUNTER: 1}
	driver._active_convo_id = claim
	host.quest_kills = {COUNTER: 1}
	guest.quest_kills = {COUNTER: 1}
	host.quest_kill_note("wolf")
	await _wait(r)
	_observe(report, "active_driver_keeps_authored_main", driver.game.quest_key == "morwen",
		{"host_key": host.quest_key, "driver_key": driver.game.quest_key, "beat_broadcasting": driver.game.beat_broadcasting})
	_observe(report, "active_driver_receives_live_counts", driver.game.quest_kills.get(COUNTER) == 2
		and guest.quest_kills.get(COUNTER) == 2, {"driver": driver.game.quest_kills.duplicate(true), "sibling": guest.quest_kills.duplicate(true)})
	_observe(report, "active_driver_progress_grants_nothing", [_ledger(host), _ledger(guest)] == before,
		"actual host quest_kill_note from posed 1 to 2; no completion threshold")
	driver._on_convo_ended(claim, true, Callable())
	if not await r._until(func() -> bool: return not wire._beat_claims.has(claim)):
		return "driver completion did not release its host claim"
	await _wait(r)
	_observe(report, "guest_beat_host_accepted", host.quest_key == "morwen", host.quest_key)
	_observe(report, "guest_beat_sibling_followed", guest.quest_key == "morwen"
		and r.wires[1]._spectate_initiator == 0, {"key": guest.quest_key, "spectator": r.wires[1]._spectate_initiator})
	_observe(report, "guest_beat_open_journal", Story.quest_text("morwen") in _text(guest.menus.root), _text(guest.menus.root))
	_observe(report, "beat_text_grants_nothing", [_ledger(host), _ledger(guest)] == before, "compared XP/gold/flags/inventory/mail/RNG")
	await r._capture("quest_06_guest_driven_beat_journal")
	driver.rpc_id(1, "_rpc_beat_quest", "vargoth")
	await _wait(r)
	_observe(report, "released_driver_rejected", host.quest_key == "morwen" and [_ledger(host), _ledger(guest)] == before, host.quest_key)
	# Keep a different owner in the active claim: being admitted is insufficient.
	wire._beat_claims[claim] = r.apis[1].get_unique_id()
	driver.rpc_id(1, "_rpc_beat_quest", "vargoth")
	await _wait(r)
	_observe(report, "nonowner_driver_rejected", host.quest_key == "morwen" and [_ledger(host), _ledger(guest)] == before, host.quest_key)
	wire._beat_claims.erase(claim)
	# The live-key guard must not suppress an explicit readiness rebrief.
	# This is the exact ready sender invoked directly, not a real world rebuild.
	if wire.has_method("host_quest_progress"):
		driver.game.beat_broadcasting = true
		driver.game.quest_key = "vargoth"
		var has_rebrief_argument := false
		for method in wire.get_method_list():
			if String(method.name) == "host_quest_progress":
				has_rebrief_argument = method.args.size() >= 2
		if has_rebrief_argument:
			wire.call("host_quest_progress", pid, true)
		else:
			wire.call("host_quest_progress", pid)  # original .17 draft diagnostic
		await _wait(r)
		_observe(report, "readiness_rebrief_replaces_active_key", driver.game.quest_key == host.quest_key
			and driver.game.quest_kills == host.quest_kills, {"driver_key": driver.game.quest_key, "host_key": host.quest_key,
			"explicit_rebrief_supported": has_rebrief_argument})
		driver.game.beat_broadcasting = false
	else:
		report.observations["readiness_rebrief_replaces_active_key"] = {"covered": false, "reason": "new authority mirror does not exist on baseline"}
	return ""


static func _boss_probe(r: Node, report: Dictionary) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	if is_instance_valid(host.current_boss) or not host.bosses.is_empty():
		return "boss quest probe requires the paired fixture's empty combat roster"
	var final_kind := String(Story.chapter(host.chapter_id).get("final_boss", ""))
	var samples: Array[Dictionary] = []
	for zi in host.zone_count:
		var kind := String(host.zones[zi].get("boss", ""))
		if kind != "" and kind != final_kind and samples.is_empty():
			samples.append({"kind": kind, "room": zi, "final": false})
	for zi in host.zone_count:
		if String(host.zones[zi].get("boss", "")) == final_kind and final_kind != "":
			samples.append({"kind": final_kind, "room": zi, "final": true})
			break
	if samples.size() != 2:
		return "paired chapter must expose an authored nonfinal and final boss"
	report["boss_setup"] = "Direct production on_boss_died calls with current_boss=null and cur_room set to each authored boss room. No Boss entity, damage, combat victory, authentic boss level or ordinary input is claimed. Normal fallback-level payouts run and are restored with the original fixture; they are not quest-mirror grants. Open journals hold the independent ending while wire/main text is observed; narration/finale is cancelled afterward."
	for sample in samples:
		var kind := String(sample.kind)
		if bool(host.boss_done.get(kind, false)) or bool(guest.boss_done.get(kind, false)):
			return "boss quest probe requires uncompleted posed boss: " + kind
		if host.chapter_finale.seen or guest.chapter_finale.seen:
			return "boss quest probe requires no previous pending finale"
		host.cur_room = int(sample.room)
		host.quest_key = kind
		guest.quest_key = kind
		host.menus.open_journal("quests")
		guest.menus.open_journal("quests")
		var before := {"host_gold": host.player.gold, "guest_gold": guest.player.gold,
			"host_mail": host.mailbox.size(), "guest_mail": guest.mailbox.size()}
		host.on_boss_died(kind)
		if not await r._until(func() -> bool: return bool(guest.boss_done.get(kind, false))):
			return "existing boss-done packet was not delivered for " + kind
		if bool(sample.final):
			if not await r._until(func() -> bool: return guest.chapter_finale.seen and guest.get_flag("completed_" + guest.chapter_id, false)):
				return "existing guest victory packet did not settle before finale cancellation"
		# The earlier reliable reward/victory handlers have arrived. Let their
		# deferred local awards settle before observing or cancelling narration.
		await _wait(r)
		var expected := ("done_" + host.chapter_id if Story.ALL_QUESTS.has("done_" + host.chapter_id) else "done") \
			if bool(sample.final) else host._next_quest_after(int(sample.room))
		var label := "final" if bool(sample.final) else "nonfinal"
		_observe(report, "boss_" + label + "_main_delivery", host.quest_key == expected and guest.quest_key == expected
			and bool(guest.boss_done.get(kind, false)), {"kind": kind, "posed_room": sample.room,
			"expected": expected, "host_key": host.quest_key, "guest_key": guest.quest_key,
			"existing_boss_done_delivered": guest.boss_done.get(kind, false), "before_payout": before,
			"after_payout": {"host_gold": host.player.gold, "guest_gold": guest.player.gold,
				"host_mail": host.mailbox.size(), "guest_mail": guest.mailbox.size()}})
		await r._capture("quest_07_boss_" + label + "_main")
		for g in [host, guest]:
			g.chapter_finale.cancel(g)
			g.hud.cancel_conversation()
			g.hud.hide_results()
			g.menus.close()
			g.state = Game.ST_PLAYING
			g.request_pause(false)
		await r.frames(3)
	return ""
