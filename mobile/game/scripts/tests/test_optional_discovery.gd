extends RefCounted
## Independent encounter records, fog and read-only map actions. No networking.
const Nav := preload("res://scripts/ui/navigation.gd")
const Rewards := preload("res://scripts/ui/activity_rewards.gd")
const STATE := ["chapter_id", "zones", "rooms", "coord_to_room", "zone_count",
	"terrain_by_zone", "cur_room", "visited", "door_seen", "cleared", "built",
	"zone_alive", "edge_locks", "boss_done", "pocket_done", "unlisted_banked",
	"waking_kills", "waking_kills_week", "barrier_active", "no_saves",
	"contracts", "contract_day", "contract_claims_day", "bounties", "bounty_day",
	"wander_seed", "state", "clock_anchor"]


static func run(t: Node) -> String:
	var fixture := Game.new()
	_fixture(fixture)
	var result := _state_contracts(fixture)
	fixture.free()
	if result != "":
		return result
	var g: Game = t.game
	var keep := {}
	for key in STATE:
		keep[key] = g.get(key)
	var paused := g.get_tree().paused
	var tab: Variant = g.menus.get_meta("journal_tab", "quests")
	var ward: Variant = g.menus.get_meta("journal_ward", "")
	var notice: Variant = g.menus.get_meta("journal_notice", "")
	var guide: Control = g.hud.wayfinder
	var keep_guide := {}
	for key in ["pinned_room", "pinned_path", "_context", "_route_block", "_room", "_clear_t", "_arrival_t", "_next_sample"]:
		var value: Variant = guide.get(key)
		keep_guide[key] = value.duplicate() if value is Array else value
	_fixture(g)
	g.no_saves = true
	# Menu entry may roll a day boundary. Isolate both original board arrays.
	g.contracts = g.contracts.duplicate(true)
	g.bounties = g.bounties.duplicate(true)
	guide.pinned_room = -1
	var empty_path: Array[int] = []
	guide.pinned_path = empty_path
	result = await _ui_contracts(g)
	g.menus.close()
	for key in STATE:
		g.set(key, keep[key])
	for key in keep_guide:
		guide.set(key, keep_guide[key])
	g.menus.set_meta("journal_tab", tab)
	g.menus.set_meta("journal_ward", ward)
	g.menus.set_meta("journal_notice", notice)
	g.get_tree().paused = paused
	if result == "":
		print("ok: charted independent guardian names/completion, Waking week, live readers, map inspection/focus and detached pocket isolation")
	return result


static func _fixture(g: Game) -> void:
	g.chapter_id = "ch4"
	g.zones = [
		{"name": "Known camp", "type": "safe", "enemies": []},
		{"name": "Campaign arena", "type": "boss", "boss": "cinderhide", "enemies": []},
		{"name": "The Molten Court", "type": "combat", "boss": "cinderhide", "pocket": "molten_court", "enemies": []},
		{"name": "Old Greymantle", "type": "combat", "boss": "fangmaw", "unlisted": "greymantle", "enemies": []},
		{"name": "Fangmaw arena", "type": "boss", "boss": "fangmaw", "enemies": []},
		{"name": "Known breach", "type": "combat", "boss": "cinderhide", "waking": "cinderhide", "enemies": []},
		{"name": "Unseen guardian room", "type": "boss", "boss": "sexton", "enemies": []}]
	g.rooms = []
	g.coord_to_room = {}
	g.terrain_by_zone = []
	var coords := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(99, 99), Vector2i(0, 1), Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, 0)]
	var exits := [{"E": "", "S": ""}, {"W": "", "E": "", "S": ""}, {}, {"N": ""}, {"W": "", "E": ""}, {"N": ""}, {"W": ""}]
	for i in coords.size():
		g.rooms.append({"coord": coords[i], "origin": Vector2(coords[i]) * Vector2(Game.ROOM_W, Game.ROOM_H), "scale": Vector2.ONE, "exits": exits[i]})
		g.coord_to_room[coords[i]] = i
		g.terrain_by_zone.append("village")
	g.zone_count = g.zones.size()
	g.cur_room = 0
	g.visited = {0: true, 1: true, 2: true, 3: true, 4: true, 5: true}
	g.door_seen = {6: true}
	g.built = {}
	g.cleared = {}
	g.zone_alive = {}
	g.edge_locks = {g._edge_key(0, 1): {"lock": "flag:optional_guardian_fixture", "own": 0}}
	g.boss_done = {"cinderhide": false, "fangmaw": false, "sexton": true}
	g.pocket_done = false
	g.unlisted_banked = []
	g.waking_kills = []
	g.waking_kills_week = g._week_index()
	g.barrier_active = false
	g.state = Game.ST_PLAYING


static func _state_contracts(g: Game) -> String:
	var expected := ["", "Cinderhide the Unquenched", "The Molten Court", "Old Greymantle", "Fangmaw the Ravener", "Waking echo · Cinderhide the Unquenched"]
	for i in expected.size():
		if g._boss_room_name(i) != expected[i]:
			return "guardian room identity lost its named encounter or explicit Waking echo"
	for i in [-1, g.zone_count]:
		if g._boss_room_name(i) != "" or g._boss_room_resolved(i):
			return "invalid guardian index disclosed an identity or completion"
	for campaign in [false, true]:
		g.boss_done["cinderhide"] = campaign
		g.boss_done["fangmaw"] = campaign
		for named in [false, true]:
			g.pocket_done = named
			g.unlisted_banked = ["greymantle"] if named else []
			g.waking_kills = ["cinderhide"] if named else []
			for i in [1, 2, 3, 4, 5]:
				var done: bool = campaign if i in [1, 4] else named
				if g._boss_room_resolved(i) != done or g.room_pacified(i) != done:
					return "room completion/pacification was inherited from a reused boss kind"
	g.waking_kills_week = g._week_index() - 1
	if g._boss_room_resolved(5) or not g._boss_room_resolved(1):
		return "old Waking week remained defeated or reset the campaign guardian"
	g.built[2] = true
	g.zone_alive[2] = 1
	if g.room_pacified(2):
		return "named completion ignored living room enemies"
	if Nav.chart_rooms(g).has(2) or Nav.chart_rooms(g, 2) != [2] or not Nav.route(g, 0, 2).is_empty():
		return "guardian map inspection joined a detached pocket to the mainland"
	if Nav.chart_rooms(g, 6) != Nav.chart_rooms(g) or not Nav.route(g, 0, 1).is_empty():
		return "viewing anchor admitted an unseen room or bypassed a story lock"
	if g.travel_target(2) or g.travel_target(3) or g.travel_target(5):
		return "optional combat rooms became fast-travel targets"
	return ""


static func _frames(g: Game, count := 4) -> void:
	for _i in count:
		await g.get_tree().process_frame


static func _text(root: Node, name: String) -> String:
	var label := root.find_child(name, true, false) as Label
	return label.text if label != null else ""


static func _ui_contracts(g: Game) -> String:
	var m := g.menus
	m.open_journal("progress")
	await _frames(g)
	if m.root.find_children("JournalGuardian_*", "Label", true, false).size() != 5 \
			or _text(m.root, "JournalGuardiansSummary") != "0 of 5 charted guardians defeated" \
			or m.root.find_child("JournalGuardian_6", true, false) != null:
		return "Progress disclosed an uncharted guardian or counted kinds instead of charted rooms"
	var map_button := m.root.find_child("JournalGuardianMap_2", true, false) as Button
	if map_button == null or map_button.custom_minimum_size.y < 44:
		return "charted guardian has no accessible map action"
	var visited := g.visited.duplicate()
	var marks := g.boss_done.duplicate()
	map_button.pressed.emit()
	await _frames(g)
	var atlas: Control = m.root.find_child("FieldAtlas", true, false)
	if atlas == null or atlas.selected != 2 or atlas._rooms != [2] \
			or g.cur_room != 0 or g.visited != visited or g.boss_done != marks or g.hud.wayfinder.pinned_room != -1:
		return "Show on map did not inspect only the known pocket without changing gameplay"
	if not (atlas.find_child("PinRoute", true, false) as Button).disabled or not (atlas.find_child("Travel", true, false) as Button).disabled:
		return "detached pocket inspection allowed routing or travel"
	if _text(atlas, "AtlasGuardianState") != "Guardian · The Molten Court":
		return "atlas guardian used the campaign kit identity"
	# An optional-only bank change must refresh an already-open atlas, retaining
	# its detached component, zoom/pan, action focus and details scroll.
	(atlas.find_child("AtlasNext", true, false) as Button).grab_focus()
	atlas._zoom = 1.2
	atlas._pan = Vector2(8, 5)
	var detail := atlas.find_child("AtlasDetailScroll", true, false) as ScrollContainer
	detail.scroll_vertical = 20
	var offset := detail.scroll_vertical
	g.pocket_done = true
	await g.get_tree().create_timer(0.7, true).timeout
	var focus := g.get_viewport().gui_get_focus_owner()
	if atlas.selected != 2 or atlas._rooms != [2] or atlas._zoom != 1.2 or atlas._pan != Vector2(8, 5) \
			or detail.scroll_vertical != offset or focus == null or focus.name != "AtlasNext" \
			or _text(atlas, "AtlasGuardianState") != "Defeated · The Molten Court":
		return "open atlas did not refresh optional completion while keeping its reader context"
	(atlas.find_child("AtlasYourPosition", true, false) as Button).pressed.emit()
	await _frames(g)
	if atlas.selected != 0 or atlas._rooms.has(2) or g.cur_room != 0:
		return "Your position failed to restore the current-area chart"
	atlas.select_room(2)
	g.boss_done["cinderhide"] = true
	g.boss_done["fangmaw"] = true
	if Nav.main_trail(g) != 6:
		return "main-trail fixture did not expose its uncharted connected frontier"
	(atlas.find_child("AtlasMainTrail", true, false) as Button).pressed.emit()
	await _frames(g)
	if atlas.selected != 6 or atlas._rooms.has(2) or _text(atlas, "AtlasGuardianState") != "" or g.visited.has(6):
		return "Main trail from a pocket view failed to inspect its frontier without revealing it"
	g.boss_done = marks.duplicate()
	atlas.select_room(1)
	if (atlas.find_child("PinRoute", true, false) as Button).disabled or Nav.first_lock(g, atlas._route) == "":
		return "map inspection lost the existing sealed-story route explanation"
	# Waking's own bank and its week are independent from the base boss.
	atlas.select_room(5)
	g.waking_kills = ["cinderhide"]
	await g.get_tree().create_timer(0.7, true).timeout
	if _text(atlas, "AtlasGuardianState") != "Defeated · Waking echo · Cinderhide the Unquenched":
		return "open atlas failed to show the named Waking completion"
	g.waking_kills_week -= 1
	await g.get_tree().create_timer(0.7, true).timeout
	if _text(atlas, "AtlasGuardianState") != "Guardian · Waking echo · Cinderhide the Unquenched":
		return "open atlas retained a previous week's Waking completion"
	m.open_journal("progress")
	await _frames(g)
	(m.root.find_child("JournalGuardianMap_3", true, false) as Button).grab_focus()
	var scroll := m.root.find_child("JournalScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 60
	offset = scroll.scroll_vertical
	var old_shell := m.root.get_instance_id()
	g.unlisted_banked = ["greymantle"]
	await g.get_tree().create_timer(0.7, true).timeout
	focus = g.get_viewport().gui_get_focus_owner()
	scroll = m.root.find_child("JournalScroll", true, false) as ScrollContainer
	if m.root.get_instance_id() == old_shell or focus == null or focus.name != "JournalGuardianMap_3" \
			or scroll.scroll_vertical != offset or not _text(m.root, "JournalGuardian_3").begins_with("✓") \
			or _text(m.root, "JournalGuardiansSummary") != "2 of 5 charted guardians defeated":
		return "open Progress failed to refresh optional-only progress while retaining focus and scroll"
	# Discovery updates the rendered count; a completion mark alone did not.
	g.visited = g.visited.duplicate()
	g.visited[6] = true
	await g.get_tree().create_timer(0.7, true).timeout
	if _text(m.root, "JournalGuardiansSummary") != "3 of 6 charted guardians defeated":
		return "newly charted guardian did not join Progress independently"
	var stale := m.root.find_child("JournalGuardianMap_2", true, false) as Button
	var stale_shell := m.root
	g.wander_seed += 1
	stale.pressed.emit()
	if m.current != "journal" or m.root != stale_shell:
		return "a retained guardian map callback crossed into a new run context"
	# Optional state must not spuriously rebuild a selected ward board.
	m.open_journal("activities", "accord")
	await _frames(g)
	old_shell = m.root.get_instance_id()
	var signature := Rewards._signature(g)
	g.pocket_done = false
	g.unlisted_banked = []
	await g.get_tree().create_timer(0.7, true).timeout
	if Rewards._signature(g) != signature or m.root.get_instance_id() != old_shell or m.get_meta("journal_ward") != "accord":
		return "guardian watcher dependencies changed an unrelated selected ward board"
	return ""
