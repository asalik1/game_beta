extends RefCounted
const Hunt := preload("res://scripts/road_hunt.gd")
const History := preload("res://scripts/character_history.gd")

class QuietHUD extends Hud:
	var notes: Array[String] = []
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func announce(text: String, _color: Color, _hold := 0.0, _kind := "") -> void: notes.append(text)

class QuietEnemy extends Enemy:
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class Fixture extends Game:
	var guest := false
	var blocked := false
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _recheck_gates() -> void: pass
	func _check_side_quests() -> void: pass
	func refresh_quest_marks() -> void: pass
	func room_type(_room: int) -> String: return "social"
	func room_center(_room: int) -> Vector2: return Vector2(1000, 800)
	func play_rect(_room: int) -> Rect2: return Rect2(0, 0, 2000, 1600)
	func room_at_pos(_pos: Vector2) -> int: return cur_room
	func free_spawn_pos(pos: Vector2, _anchor: Vector2) -> Vector2: return pos
	func _pos_in_wall(_pos: Vector2) -> bool: return blocked
	func net_guest() -> bool: return guest
	func net_online() -> bool: return false
	func spawn_text(_pos: Vector2, _text: String, _color: Color, _hold := 0.0) -> void: pass
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void: pass


static func run(t: Node) -> String:
	var g := Fixture.new()
	g.no_saves = true
	g.play_started = true
	g.chapter_id = "ch1"
	g.wander_seed = 12345
	g.cur_room = 0
	g.zones = [{"type": "social"}]
	g.terrain_by_zone = ["village"]
	t.add_child(g)
	g.world = Node2D.new()
	g.add_child(g.world)
	g.hud = QuietHUD.new()
	g.hud.game = g
	g.add_child(g.hud)
	g.menus = Menus.new()
	g.menus.game = g
	g.add_child(g.menus)
	var p := Player.new()
	p.game = g
	p.hp = 100
	p.max_hp = 100
	g.player = p
	g.players = [p]
	var error := _checks(g)
	g.player = null
	g.players = []
	p.free()
	g.free()
	if error == "":
		print("ok: road hunt ordered signs/reach/incapacity, bounded snapshots, blocked placement, death-only payment, personal saved receipt, purge/loot isolation, once-only rewards and abandonment cleanup")
	return error


static func _checks(g: Game) -> String:
	if Hunt.quarry_level(g, 0, "wolf") != 2:
		return "an empty starting road inherited the chapter finale's level"
	g.zones[0]["enemies"] = [["wolf", 0, 0, 0, 5], ["wolf", 0, 0, 0, 8]]
	var local_level := Hunt.quarry_level(g, 0, "wolf")
	g.zones[0].erase("enemies")
	if local_level != 8:
		return "quarry ignored its room's authored power band"
	var trail := Hunt.begin(g, 0, g.room_center(0))
	if trail == null or trail.points.size() != 3 or Hunt.begin(g, 0, g.room_center(0)) != null:
		return "road hunt missing its three signs or allowed parallel hunts"
	trail.set_physics_process(false)
	var raw: Dictionary = trail.snapshot()
	if Hunt.clean_snapshot(g, raw).is_empty():
		return "road hunt rejected its own snapshot"
	for field in ["zone", "token", "phase", "sign", "points", "origin", "quarry_point", "remaining"]:
		var malformed := raw.duplicate(true)
		malformed[field] = null
		if not Hunt.clean_snapshot(g, malformed).is_empty():
			return "road hunt accepted missing or mistyped " + field
	for bad in [{"phase": 99}, {"sign": -1}, {"zone": -1}, {"token": 0}, {"kind": "unknown"},
		{"points": [Vector2.ZERO]}, {"points": [Vector2(INF, 0), Vector2.ZERO, Vector2.ZERO]},
		{"quarry_point": Vector2(-900, 0)}, {"remaining": NAN}, {"remaining": 999.0}]:
		var malformed := raw.duplicate(true)
		malformed.merge(bad, true)
		if not Hunt.clean_snapshot(g, malformed).is_empty():
			return "road hunt accepted invalid bounds/state: " + str(bad)
	g.player.position = trail.points[0] + Vector2(300, 0)
	if trail.request(g.player, 0) or trail.request(null, 0):
		return "road hunt accepted an absent or distant tracker"
	g.player.position = trail.points[0]
	for state in ["dead", "downed", "ghost"]:
		g.player.set(state, true)
		var accepted: bool = trail.request(g.player, 0)
		g.player.set(state, false)
		if accepted:
			return "road hunt accepted an incapacitated tracker"
	if trail.request(g.player, 2) or not trail.request(g.player, 0) or trail.request(g.player, 0):
		return "road hunt accepted out-of-order/repeated signs or lost a valid inspection"
	if trail.entries[0].reach != 0.0 or trail.entries[1].reach != Balance.ROAD_HUNT_INTERACT_RANGE:
		return "a hidden sign still steals the interaction prompt"
	g.player.position = trail.points[1]
	if not trail.request(g.player, 1):
		return "second hunt sign could not be read"
	g.player.position = trail.points[2]
	if not trail.request(g.player, 2) or trail.phase != Hunt.WARNING or trail.request(g.player, 2):
		return "quarry flush has no warning or accepted a duplicate"
	var before := [g.player.gold, g.player.xp, g.run_road_cards, g.quest_kills.duplicate(), g.zone_alive.duplicate(), g.loot_rng.state]
	var enemy := QuietEnemy.new()
	g.world.add_child(enemy)
	enemy.set_meta("road_hunt_owner", trail)
	trail.quarry = enemy
	trail.phase = Hunt.FIGHTING
	g.on_enemy_died(enemy)
	if g.player.gold != before[0] or trail.phase != Hunt.FIGHTING:
		return "road hunt paid for an enemy that had not died"
	enemy.dying = true
	g.on_enemy_died(enemy)
	var expected := g.player.gold_yield(int(ceil(Balance.ROAD_HUNT_GOLD * Balance.daily_gold_mult(g.player.level))))
	if g.player.gold != before[0] + expected or trail.phase != Hunt.COMPLETE or g.run_road_cards != before[2] + 1:
		return "road hunt witnessed death did not pay/consume once"
	if [g.player.xp, g.quest_kills, g.zone_alive, g.loot_rng.state] != [before[1], before[3], before[4], before[5]]:
		return "road hunt changed campaign XP, purge, kill quests or loot RNG"
	if not g.get_flag(g._road_flag(0), false) or not g.get_flag(trail.receipt(), false) \
		or not History.is_local(trail.receipt()) or not History.is_saved(trail.receipt()) \
		or History.world_only(g.flags).has(trail.receipt()):
		return "road hunt lost completion or exposed its personal receipt as world state"
	g.player.downed = true
	var downed_paid: bool = trail.eligible_recipient(g.player)
	g.player.downed = false
	g.player.ghost = true
	var ghost_paid: bool = trail.eligible_recipient(g.player)
	g.player.ghost = false
	g.cur_room = 1
	var absent_paid: bool = trail.eligible_recipient(g.player)
	g.cur_room = 0
	if not downed_paid or ghost_paid or absent_paid:
		return "hunt reward eligibility lost a downed ally or paid an absent/ghost hero"
	g.on_enemy_died(enemy)
	if trail.reward() or g.player.gold != before[0] + expected or g.run_road_cards != before[2] + 1:
		return "road hunt repeat death/settlement paid twice"
	trail.free()
	g.flags.clear()  # only this isolated fixture's flags
	g.guest = true
	var late_block := raw.duplicate(true)
	late_block.phase = Hunt.COMPLETE
	late_block.sign = 2
	var late := Hunt.receive(g, late_block)
	if late == null or g.player.gold != before[0] + expected or g.get_flag(late.receipt(), false):
		return "a late completed snapshot paid historical rewards"
	late.free()
	var notes_before: int = g.hud.notes.size()
	var arriving := raw.duplicate(true)
	var reading := Hunt.receive(g, arriving)
	if g.hud.notes.size() != notes_before:
		return "joining an existing trail replayed an old discovery"
	arriving.sign = 1
	Hunt.receive(g, arriving)
	Hunt.receive(g, arriving)
	if g.hud.notes.size() != notes_before + 1 or g.hud.notes[-1] != Hunt.CLUES[0]:
		return "shared discovery was missed or replayed on a duplicate snapshot"
	arriving.sign = 2
	Hunt.receive(g, arriving)
	arriving.phase = Hunt.WARNING
	arriving.remaining = Balance.ROAD_HUNT_WARNING
	Hunt.receive(g, arriving)
	Hunt.receive(g, arriving)
	if g.hud.notes.size() != notes_before + 3 or not String(g.hud.notes[-1]).begins_with("The cover stirs"):
		return "guest missed the quarry warning or repeated it"
	Hunt.receive(g, raw)
	if g.hud.notes.size() != notes_before + 3:
		return "an old snapshot replayed hunt feedback"
	reading.free()
	g.guest = false
	var retry := Hunt.begin(g, 0, g.room_center(0))
	if retry == null or retry.points != raw.points:
		return "road hunt placement is not deterministic"
	retry.set_physics_process(false)
	var live := QuietEnemy.new()
	g.world.add_child(live)
	retry.quarry = live
	retry.phase = Hunt.FIGHTING
	g.cur_room = 1
	retry._physics_process(0.1)
	if not retry.is_queued_for_deletion() or not live.is_queued_for_deletion() or g.get_flag(g._road_flag(0), false):
		return "abandoning a hunt kept the quarry or claimed completion"
	retry.free()
	g.cur_room = 0
	g.blocked = true
	if Hunt.begin(g, 0, g.room_center(0)) != null:
		return "blocked hunt signs were placed inside terrain"
	g.blocked = false
	var stale := Hunt.begin(g, 0, g.room_center(0))
	stale.set_physics_process(false)
	g.player.position = stale.points[0]
	g.wander_seed += 1
	if stale.request(g.player, 0):
		return "a changed world accepted an old hunt interaction"
	stale.free()
	return ""
