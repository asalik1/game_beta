extends RefCounted
## In-process dedicated authority regression: real spawn/death/flag/gate paths,
## isolated world and no transport. Run by the quick suite's systems tier.

class Fixture extends Game:
	var guest := false
	var host := false  # only for the per-frame host room pass (a server is the host)
	var session: Node = null
	var quest_refreshes := 0
	var completion_toasts := 0
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func net_guest() -> bool: return guest
	func net_host() -> bool: return host
	func net_session() -> Node: return session
	func net_online() -> bool: return false
	func refresh_quest_marks() -> void: pass
	func refresh_quest() -> void: quest_refreshes += 1
	func spawn_text(_pos: Vector2, text: String, _color: Color, _hold := 0.0) -> void:
		if text.begins_with("SIDE QUEST COMPLETE"):
			completion_toasts += 1
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void: pass

class QuietHud extends Hud:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func show_boss_bar(_bname: String) -> void: pass
	func hide_boss_bar() -> void: pass
	func boss_banner(_bname: String) -> void: pass
	func achievement_toast(_name: String, _desc: String) -> void: pass
	# Keep Hud.dialogue itself: dedicated beats must resolve immediately.

## The two session hooks the host room pass reaches when it raises a boss.
class SessionStub extends Node:
	var intros := 0
	func host_boss_intro(_kind: String) -> void: intros += 1
	func host_register_enemy(_e: Node) -> void: pass


static func run(t: Node) -> String:
	var paused: bool = t.get_tree().paused
	var g := Fixture.new()
	g.no_saves = true
	g.dedicated = true
	g.play_started = true
	t.add_child(g)
	g.world = Node2D.new()
	g.world.process_mode = Node.PROCESS_MODE_DISABLED  # no AI during controlled kills
	g.add_child(g.world)
	g.hud = QuietHud.new()
	g.hud.game = g
	g.add_child(g.hud)
	g.zones = Story.chapter("ch1")["zones"].duplicate(true)
	g.zone_count = g.zones.size()
	for z in g.zones:
		g.terrain_by_zone.append(z.get("terrain", "village"))
	g._prepare_rooms()
	var error: String = await _boss_checks(g)
	var quest_error := _quest_checks(g)
	if quest_error != "":
		error += ("; " if error != "" else "") + quest_error
	g.free()  # all state belongs to the fixture, including failure paths
	t.get_tree().paused = paused
	if error == "":
		print("ok: dedicated pack clear raises Fangmaw, an empty-arena clear raises him on re-entry, death opens his gate, force arms an empty arena, and player-less quests settle once")
	return error


static func _boss_checks(g: Fixture) -> String:
	var zi := -1
	for i in g.zone_count:
		if g.zones[i].get("boss", "") == "fangmaw":
			zi = i
	if zi < 0 or zi == g.cur_room or g.has_local_player():
		return "dedicated boss fixture lacks its remote arena or has a local player"
	var pack: Array = g.zones[zi].get("enemies", [])
	if pack.size() != 3:
		return "Fangmaw fixture must exercise his three-wolf pack"
	g.active_rooms = {zi: true}
	g.zone_alive[zi] = pack.size()
	g.built[zi] = true
	g.merchant_zones.append(zi)  # exclude unrelated random merchant arrivals
	var edge := ""
	for key in g.edge_locks:
		if g.edge_locks[key].get("own", -1) == zi and g.edge_locks[key].get("lock", "") == "boss":
			edge = key
	if edge == "":
		return "Fangmaw fixture has no boss-locked exit"
	var gate := StaticBody2D.new()
	g.world.add_child(gate)
	g.gates[edge] = gate
	g._try_spawn_boss(zi)
	if g.boss_spawned.get(zi, false):
		return "dedicated arena spawned its boss before the pack died"
	for row in pack:
		var wolf := Enemy.make(g, String(row[0]), g.room_center(zi), int(row[4]))
		wolf.zone_idx = zi
		wolf.force_aggro = true  # do not wake packs belonging to the suite's world
		g.add_enemy(wolf)
		wolf.take_damage(wolf.max_hp * 100.0)
	await g.get_tree().create_timer(0.1).timeout  # deferred death consequences
	var boss: Boss = g.current_boss
	if not is_instance_valid(boss) or boss.kind != "fangmaw" or boss.zone_idx != zi \
			or g.zone_alive.get(zi, -1) != 0 or not g.cleared.get(zi, false):
		return "dedicated pack clear did not raise Fangmaw outside cur_room"
	if not g.gates.has(edge):
		return "pack clear opened Fangmaw's exit before his death"
	g._try_spawn_boss(zi)
	if g.bosses.size() != 1:
		return "dedicated arena raised a duplicate story boss"
	var refreshes := g.quest_refreshes
	boss.force_aggro = true
	boss.take_damage(boss.max_hp * 100.0)
	await g.get_tree().create_timer(0.1).timeout
	if not g.boss_done.get("fangmaw", false) or g.gates.has(edge) \
			or g.quest_refreshes <= refreshes:
		return "dedicated boss death did not finish the post-beat gate/quest continuation"
	g._try_spawn_boss(zi)
	if not g.bosses.is_empty():
		return "a completed dedicated story boss respawned"
	var reentry_error: String = await _reentry_checks(g, zi, pack, edge)
	if reentry_error != "":
		return reentry_error

	# Fresh empty arena: retain the normal guards and the existing force path.
	g.boss_done.erase("fangmaw")
	g.boss_spawned.erase(zi)
	g.active_rooms = {}
	g._try_spawn_boss(zi)
	if g.boss_spawned.get(zi, false):
		return "an unoccupied dedicated arena armed without force"
	g.active_rooms[zi] = true
	g.dedicated = false
	g._try_spawn_boss(zi)
	g.dedicated = true
	if g.boss_spawned.get(zi, false):
		return "the dedicated occupancy exception changed the listen/solo room guard"
	g.guest = true
	g._try_spawn_boss(zi, true)
	g.guest = false
	if g.boss_spawned.get(zi, false):
		return "a guest armed an authoritative boss"
	g.built[zi] = false
	g._try_spawn_boss(zi, true)
	g.built[zi] = true
	if g.boss_spawned.get(zi, false):
		return "force armed an unbuilt arena"
	g.active_rooms = {}
	g._try_spawn_boss(zi, true)
	if not is_instance_valid(g.current_boss) or g.current_boss.zone_idx != zi:
		return "dedicated forced empty-arena spawn failed without a local player"
	return ""


## The pack dies while nobody stands in the arena (a guest struck the last wolf
## from across the door line, or a hazard ticked it down). Nothing may arm then;
## Fangmaw must rise once a guest walks back in, through the server's per-frame
## host room pass, and his death must still open the exit. Leaves the arena as
## the caller had it: Fangmaw done, no live boss, the exit open.
static func _reentry_checks(g: Fixture, zi: int, pack: Array, edge: String) -> String:
	g.boss_done.erase("fangmaw")
	g.boss_spawned.erase(zi)
	g.cleared.erase(zi)
	g.active_rooms = {}
	g.zone_alive[zi] = pack.size()
	var gate := StaticBody2D.new()
	g.world.add_child(gate)
	g.gates[edge] = gate
	for row in pack:
		var wolf := Enemy.make(g, String(row[0]), g.room_center(zi), int(row[4]))
		wolf.zone_idx = zi
		wolf.force_aggro = true
		g.add_enemy(wolf)
		wolf.take_damage(wolf.max_hp * 100.0)
	await g.get_tree().create_timer(0.1).timeout
	if g.zone_alive.get(zi, -1) != 0 or not g.cleared.get(zi, false):
		return "an unoccupied dedicated arena did not register its pack clear"
	if g.boss_spawned.get(zi, false) or not g.bosses.is_empty():
		return "an unoccupied dedicated arena raised its boss with nobody inside"
	var stub := SessionStub.new()
	g.add_child(stub)  # freed with the fixture
	g.session = stub
	g.active_rooms = {zi: true}
	g.host = true
	# Listen host parity: its pass never re-arms a built room (the host's own
	# _enter_room does that), so only the dedicated branch may raise him.
	g.dedicated = false
	g._host_ensure_active_rooms()
	g.dedicated = true
	var listen_armed: bool = g.boss_spawned.get(zi, false)
	g._host_ensure_active_rooms()
	g._host_ensure_active_rooms()  # a later frame must not raise a second boss
	g.host = false
	g.session = null
	if listen_armed:
		return "the listen host room pass re-armed a built arena"
	var boss: Boss = g.current_boss
	if not is_instance_valid(boss) or boss.kind != "fangmaw" or boss.zone_idx != zi \
			or g.bosses.size() != 1:
		return "Fangmaw never rose when a guest walked back into his cleared arena"
	if stub.intros != 1:
		return "Fangmaw's intro fanned %d times on re-entry, expected once" % stub.intros
	if not g.gates.has(edge):
		return "re-entry opened Fangmaw's exit before his death"
	boss.force_aggro = true
	boss.take_damage(boss.max_hp * 100.0)
	await g.get_tree().create_timer(0.1).timeout
	if not g.boss_done.get("fangmaw", false) or g.gates.has(edge) or not g.bosses.is_empty():
		return "Fangmaw raised on re-entry did not open his exit when he died"
	return ""


static func _quest_checks(g: Fixture) -> String:
	# All real definitions, fresh flags: no inherited campaign progress. The
	# network apply entry must return normally and clear its routing guard too.
	g.flags = {}
	for id in Story.ALL_SIDE_QUESTS:
		var q: Dictionary = Story.ALL_SIDE_QUESTS[id]
		g.net_apply_flag("sq_on_" + String(id), true)
		for step in q.get("steps", []):
			g.net_apply_flag(String(step["flag"]), true)
		if not g.get_flag("sq_paid_" + String(id), false) or g._net_flag_apply:
			return "dedicated quest failed to settle: " + String(id)
		var kept: String = q.get("reward", {}).get("kept", "")
		if kept != "" and not g.get_flag(kept, false):
			return "dedicated quest lost its kept mark: " + String(id)
	var settled := g.flags.duplicate(true)
	g._check_side_quests()
	if g.flags != settled or g.completion_toasts != 0:
		return "dedicated quest settlement repeated or tried to present a personal payout"
	return ""
