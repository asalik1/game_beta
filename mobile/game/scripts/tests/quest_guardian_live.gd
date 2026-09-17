extends RefCounted
## Controlled reader metadata, not an earned room clear or a pocket journey.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const OWNED := ["cur_room", "zones", "zone_alive", "boss_done", "boss_spawned",
	"pocket_done", "flags", "quest_key", "quest_kills", "current_boss"]
const WATCH := ["contract_day", "contract_claims_day", "contracts", "bounties",
	"vault_week", "vault_progress", "vault_claimed_week", "chapter_id", "wander_seed"]
const HERO := ["level", "resonance", "faction_standing", "npc_favor", "tracked_quest", "hp", "mp", "gold", "xp"]
const EXPECTED := ["pending/text", "live/text", "named/text", "watch/rebuilt"]
const CLEAR := "Current room clear  ·  continue along the route"
const GUARDIAN := "Current room  ·  guardian remains"
var r: Node
var g: Game
var m: Menus
var native := Native.new()
var rows: Array[Dictionary] = []
var findings: Array[String] = []
var failures := 0
var views: Array[String] = []
var boss: Boss

static func run(rig: Node) -> Dictionary:
	var q := new()
	q.r = rig
	q.g = rig.game
	q.m = q.g.menus
	q.native.r = rig
	q.native.g = q.g
	q.native.m = q.m
	if not q.g.no_saves or q.g.net_online():
		return {"failures": 1, "error": "requires disposable offline no_saves Game"}
	var processing := [q.g.is_processing(), q.g.is_physics_processing(), q.g.player.is_physics_processing()]
	var game_mode := q.g.process_mode
	q.g.set_process(false)
	q.g.set_physics_process(false)
	q.g.player.set_physics_process(false)
	# Game's inherited world/player/loot actors stop, including direct children.
	# HUD and Menus explicitly process ALWAYS, so GUI input and BoardWatch stay live.
	q.g.process_mode = Node.PROCESS_MODE_DISABLED
	await rig.frames(2) # Drain already queued claims before the economy baseline.
	var keep := q._snapshot(q.g, OWNED)
	var hero := q._snapshot(q.g.player, HERO)
	var metadata := {}
	for key in ["journal_tab", "journal_ward", "journal_notice"]:
		metadata[key] = [q.m.has_meta(key), q.m.get_meta(key) if q.m.has_meta(key) else null]
	var lang := Loc.lang
	var emulate := Input.emulate_mouse_from_touch
	Loc.lang = "en"
	Input.emulate_mouse_from_touch = true
	var error := await q._exercise()
	if error != "": q._check("fixture/completed", false, error)
	# Cleanup never runs a boss death/reward callback or an unfinished reader callback.
	q.m.close()
	q.g.request_pause(false)
	q.g.current_boss = keep.current_boss
	if is_instance_valid(q.boss):
		q.boss.queue_free()
		q.boss = null
		await rig.frames(2)
	for key in keep: q.g.set(key, keep[key])
	q.g.player.tracked_quest = hero.tracked_quest
	for key in metadata:
		if metadata[key][0]: q.m.set_meta(key, metadata[key][1])
		elif q.m.has_meta(key): q.m.remove_meta(key)
	q._check("cleanup/owned", q._snapshot(q.g, OWNED) == keep and q._snapshot(q.g.player, HERO) == hero, {"game": q._changes(keep, q._snapshot(q.g, OWNED)), "hero": q._changes(hero, q._snapshot(q.g.player, HERO))})
	q._check("cleanup/reader", not q.m.is_open() and not q.g.get_tree().paused)
	q._check("input/released", not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	q.g.set_process(processing[0])
	q.g.set_physics_process(processing[1])
	q.g.player.set_physics_process(processing[2])
	q.g.process_mode = game_mode
	Loc.lang = lang
	Input.emulate_mouse_from_touch = emulate
	var actual := q.findings.duplicate()
	actual.sort()
	var expected: Array = EXPECTED.duplicate() if rig.flag("baseline") else []
	expected.sort()
	q._check("findings/exact", actual == expected, {"actual": actual, "expected": expected})
	var report := {"complete": q.failures == 0, "checks": q.rows, "findings": q.findings,
		"failures": q.failures, "error": error, "views": q.views,
		"input": {"mouse": q.native.mouse_clicks, "touch": q.native.touch_taps, "keys": q.native.key_taps},
		"scope": "Controlled authored Fangmaw metadata and frozen factory boss; inherited Game actors disabled and queued claims settled before owned/economy snapshots, with ALWAYS HUD/Menus/BoardWatch live. No world travel or earned clear. Molten Court metadata projected into that zone; ch1 never naturally injects a pocket. Host-rendered touch plus Escape close, no physical device/network claim."}
	var directory := ProjectSettings.globalize_path(rig.shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("receipt.json"), FileAccess.WRITE)
	if file == null:
		report.failures += 1
		report.complete = false
		report.error += " receipt could not be written"
	else:
		file.store_string(JSON.stringify(report, "  "))
	return report

func _exercise() -> String:
	var arena := -1
	var safe := -1
	for i in g.zones.size():
		var zone: Dictionary = g.zones[i]
		if String(zone.get("boss", "")) == "fangmaw" and String(zone.get("pocket", "")) == "" \
			and String(zone.get("unlisted", "")) == "" and String(zone.get("waking", "")) == "":
			arena = i
		if String(zone.get("boss", "")) == "" and String(zone.get("type", "")) == "safe":
			safe = i
	if arena < 0 or safe < 0: return "authored Fangmaw/safe zones missing"
	g.cur_room = arena
	g.zone_alive[arena] = 0
	g.boss_done.erase("fangmaw")
	g.boss_spawned.erase(arena)
	g.current_boss = null
	g.quest_key = "fangmaw"
	g.flags["sq_on_hunters_rounds"] = true
	g.flags["sq_paid_hunters_rounds"] = false
	g.refresh_contracts()
	g.refresh_bounties()
	if not await _case("pending", GUARDIAN, true): return "pending reader input failed"
	boss = Boss.make_boss(g, "fangmaw", g.player.global_position + Vector2(240, 0), -1)
	boss.zone_idx = arena
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	g.world.add_child(boss)
	boss.set_physics_process(false)
	g.current_boss = boss
	g.boss_spawned[arena] = true
	_check("live/actor", boss.is_in_group("enemies") and boss.hp > 0 and not boss.dying
		and boss.zone_idx == arena and int(g.zone_alive[arena]) == 0)
	if not await _case("live", GUARDIAN, true): return "live reader input failed"
	g.current_boss = null
	boss.queue_free()
	boss = null
	await r.frames(2)
	g.boss_done["fangmaw"] = true
	if not await _case("resolved", CLEAR): return "resolved reader input failed"
	g.boss_done.erase("fangmaw")
	g.zone_alive[arena] = 2
	if not await _case("ordinary", "Current room  ·  2 monsters remain"): return "ordinary reader input failed"
	g.cur_room = safe
	g.zone_alive[safe] = 0
	if not await _case("safe", CLEAR): return "safe reader input failed"
	var pocket: Dictionary = Pockets.entry("molten_court")
	if String(pocket.get("kind", "")) != "cinderhide": return "authored pocket kit changed"
	g.cur_room = arena
	g.zones[arena] = g.zones[arena].duplicate(true)
	g.zones[arena]["boss"] = String(pocket.kind)
	g.zones[arena]["pocket"] = "molten_court"
	g.zone_alive[arena] = 0
	g.boss_done["cinderhide"] = true
	g.pocket_done = false
	if not await _case("named", GUARDIAN, true, true): return "named reader input failed"
	var track := m.root.find_child("TrackQuest_hunters_rounds", true, false) as Button
	var scroll := m.root.find_child("JournalScroll", true, false) as ScrollContainer
	if track == null or scroll == null: return "authored quest/scroll missing"
	track.grab_focus()
	await r.frames(2)
	scroll.scroll_vertical = mini(32, maxi(0, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)))
	await r.frames(2)
	var offset := scroll.scroll_vertical
	_check("watch/scroll_setup", offset > 0, offset)
	var shell_id := m.root.get_instance_id()
	var before := _watch_state()
	g.pocket_done = true # The only mutation between the two independent snapshots.
	await r.sim_wait(Balance.ACTIVITY_BOARD_REFRESH * 2.0 + 0.1)
	_check("watch/scalar_only", before == _watch_state())
	_check("watch/rebuilt", m.root.get_instance_id() != shell_id, {}, true)
	var focus: Control = m.get_viewport().gui_get_focus_owner()
	scroll = m.root.find_child("JournalScroll", true, false) as ScrollContainer
	_check("watch/view", focus != null and String(focus.name) == "TrackQuest_hunters_rounds"
		and scroll != null and scroll.scroll_vertical == offset, {"offset": offset})
	var refreshed_text := _room_text()
	_check("watch/text", refreshed_text == CLEAR, refreshed_text)
	await _capture("watch_refreshed_scrolled")
	if not await _close(): return "watch reader did not close"
	if not await _case("reopened", CLEAR): return "reopen failed"
	return ""

func _case(id: String, expected: String, known := false, keep_open := false) -> bool:
	if not await _open(): return false
	var text := _room_text()
	_check(id + "/text", text == expected, {"actual": text, "expected": expected}, known and text == CLEAR)
	await _capture(id)
	if keep_open: return true
	return await _close()

func _open() -> bool:
	var button: Button = g.hud.quest_btn
	if not button.is_visible_in_tree(): return false
	await _tap(button)
	await r.frames(3)
	if m.current != "journal" or not is_instance_valid(m.root): return false
	if String(m.get_meta("journal_tab", "")) != "quests":
		var tab := m.root.find_child("JournalTab_quests", true, false) as Button
		if tab == null: return false
		await _tap(tab)
		await r.frames(3)
	return m.current == "journal" and String(m.get_meta("journal_tab", "")) == "quests"

func _close() -> bool:
	await native._key(KEY_ESCAPE)
	await r.frames(2)
	return not m.is_open()

func _tap(button: Button) -> void:
	if r.flag("touch"): await native._touch(button.get_global_rect().get_center())
	else: await native._mouse(button.get_global_rect().get_center())

func _room_text() -> String:
	var texts: Array[String] = []
	for node in m.root.find_children("*", "Label", true, false):
		if String(node.text).begins_with("Current room"): texts.append(String(node.text))
	_check("room/unique", texts.size() == 1, texts)
	return texts[0] if texts.size() == 1 else ""

func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	views.append(r.shot(id))

func _snapshot(object: Object, fields: Array) -> Dictionary:
	var result := {}
	for key in fields:
		var value: Variant = object.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _watch_state() -> Dictionary:
	var state := _snapshot(g, OWNED + WATCH)
	state.erase("pocket_done")
	state["hero"] = _snapshot(g.player, HERO)
	return state

func _check(id: String, ok: bool, detail: Variant = {}, known := false) -> void:
	var finding: bool = not ok and known and id in EXPECTED and r.flag("baseline")
	rows.append({"id": id, "ok": ok, "finding": finding, "detail": detail})
	if finding: findings.append(id)
	elif not ok: failures += 1


func _changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in before:
		if before[key] != after[key]: result[key] = {"before": before[key], "after": after[key]}
	return result
