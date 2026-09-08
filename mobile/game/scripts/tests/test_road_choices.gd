extends RefCounted

class Fixture extends Game:
	var guest := false
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _refresh_active_rooms() -> void: pass
	func _recheck_gates() -> void: pass
	func _check_side_quests() -> void: pass
	func refresh_quest_marks() -> void: pass
	func room_at_pos(_pos: Vector2) -> int: return cur_room
	func net_guest() -> bool: return guest
	func net_online() -> bool: return false
	func spawn_text(_pos: Vector2, _text: String, _color: Color, _hold := 0.0) -> void: pass
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void: pass


static func run(t: Node) -> String:
	var paused: bool = t.get_tree().paused
	var g := Fixture.new()
	g.no_saves = true
	g.play_started = true
	t.add_child(g)
	g.world = Node2D.new()
	g.add_child(g.world)
	var p := Player.new()
	p.game = g
	p.gold = 500
	p.hp = 50
	p.max_hp = 100
	g.player = p
	g.menus = Menus.new()
	g.menus.game = g
	g.add_child(g.menus)
	g.menus.shell_motion = false
	var error := _checks(g)
	g.menus.close()
	g.player = null
	p.free()
	g.free()
	t.get_tree().paused = paused
	if error == "":
		print("ok: road choices have explicit verbs and harmless leave/back; hold only their own offer; block duplicate, faded, freed, expired, dead, guest and changed-world decisions")
	return error


static func _actor(g: Game, room := 0) -> Node2D:
	var npc := Node2D.new()
	g.add_child(npc)
	npc.set_meta("road_context", {"chapter": g.chapter_id, "seed": g.wander_seed,
		"world": g.world.get_instance_id(), "room": room, "flag": g._road_flag(room)})
	var timer := Timer.new()
	timer.name = "RoadWindow"
	timer.one_shot = true
	timer.wait_time = Balance.ROAD_CARD_WINDOW
	npc.add_child(timer)
	return npc


static func _button(node: Node, text: String) -> Button:
	if node is Button and text in node.text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


static func _wallet(g: Game) -> Array:
	return [g.player.gold, g.player.hp, g.player.faction_standing.duplicate(true),
		g.flags.duplicate(true), g.run_road_cards]


static func _checks(g: Game) -> String:
	var npc: Variant = _actor(g)
	var before := _wallet(g)
	g._road_courier(0, npc)
	var rob := _button(g.menus.root, "Rob his satchel")
	if g.menus.current != "road_choice" or rob == null or _button(g.menus.root, "Cancel") != null:
		return "courier still uses an ambiguous confirmation/cancel action"
	g._road_expire(0, npc)
	if npc.is_queued_for_deletion() or npc.get_node("RoadWindow").is_stopped():
		return "reading the offer did not hold its timeout"
	var leave := _button(g.menus.root, "Leave")
	if leave == null:
		return "road choice has no explicit harmless leave"
	leave.pressed.emit()
	rob.pressed.emit()  # fading controls cannot execute their old consequence
	if g.menus.is_open() or _wallet(g) != before:
		return "leave or a fading road action changed the character"
	g._road_toll(0, npc)
	g.menus.controller_back()
	if g.menus.is_open() or _wallet(g) != before:
		return "road back navigation charged or punished the player"
	g._road_courier(0, npc)
	rob = _button(g.menus.root, "Rob his satchel")
	g._road_toll(0, npc)
	rob.pressed.emit()
	if g.menus.current != "road_choice" or _wallet(g) != before:
		return "a replaced decision executed or closed the current shell"
	g.menus.close()
	g.player.gold = 0
	g._road_courier(0, npc)
	if not _button(g.menus.root, "Buy treatment").disabled:
		return "unaffordable treatment is offered as available"
	g.menus.close()
	g.player.gold = 500
	# Direct legacy handlers must also reject repeats, not just UI buttons.
	g._road_toll_pay(0, npc, 100)
	if g.player.gold != 400 or g.player.hp != 75 or g.run_road_cards != 1:
		return "guarded toll changed the established payment/heal contract"
	before = _wallet(g)
	g._road_courier_rob(0, npc, 200)
	g._road_toll_pay(0, npc, 100)
	if _wallet(g) != before:
		return "a queued/resolved actor paid or charged twice"
	npc.free()
	g._road_courier_rob(0, npc, 200)
	if _wallet(g) != before:
		return "a freed bound actor changed the character"
	g.flags.clear()  # this is a fresh isolated Fixture, never the suite's game
	npc = _actor(g)
	before = _wallet(g)
	for state in ["dead", "downed", "ghost"]:
		g.player.set(state, true)
		g._road_courier_rob(0, npc, 200)
		g.player.set(state, false)
		if _wallet(g) != before:
			return "an incapacitated hero resolved a road choice: " + state
	g.guest = true
	g._road_courier_rob(0, npc, 200)
	g.guest = false
	g.cur_room = 1
	g._road_courier_rob(0, npc, 200)
	g.cur_room = 0
	g.chapter_id = "ch2"
	g._road_courier_rob(0, npc, 200)
	g.chapter_id = "ch1"
	g.wander_seed += 1
	g._road_courier_rob(0, npc, 200)
	g.wander_seed -= 1
	var old_world := g.world
	g.world = Node2D.new()
	g.add_child(g.world)
	g._road_courier_rob(0, npc, 200)
	g.world.free()
	g.world = old_world
	if _wallet(g) != before:
		return "a guest or a changed room/chapter/seed/world executed a stale choice"
	g._road_courier(0, npc)
	g.cur_room = 1
	g.menus.root.get_node("RoadChoiceLifetime")._process(0.0)
	g.cur_room = 0
	if g.menus.is_open() or _wallet(g) != before:
		return "leaving the offer's room did not close its decision harmlessly"
	g._road_wager(0, npc)
	if _button(g.menus.root, "Leave — keep your stake") == null:
		return "the shell game hides its harmless exit"
	g.menus.controller_back()
	if _wallet(g) != before:
		return "leaving the shell game forfeited its stake"
	g.menus._open("Unrelated menu", 640, 400, true)
	g.menus.current = "inventory"
	g._road_expire(0, npc)
	g._road_courier_rob(0, npc, 200)
	if not npc.is_queued_for_deletion() or _wallet(g) != before:
		return "an unrelated menu held the offer, or an expired offer still paid"
	return ""
