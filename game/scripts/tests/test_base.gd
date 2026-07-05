extends Node
## TEST HARNESS, layer 1 of 4 — shared state and helpers for every
## test module. Chain: test_base.gd <- test_ch1.gd <- test_ch2.gd <-
## autotest.gd (the entry point the test scene loads).

var main_scene: PackedScene = null   # set once the game boots in _run_systems

var game: Game
var quick := false
var _failed := false


func _fail(msg: String) -> void:
	_failed = true
	push_error("AUTOTEST FAIL: " + msg)
	print("AUTOTEST FAIL: ", msg)
	get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _skip_dialogue() -> void:
	await _frames(3)
	var guard := 0
	while game.hud.dialogue_active and guard < 50:
		game.hud._advance_dialogue()
		await _frames(1)
		guard += 1


func _buff() -> void:
	game.player.max_hp = 50000.0
	game.player.hp = 50000.0


func _dummy(offset := Vector2(100, 0)) -> Enemy:
	var e := Enemy.make(game, "wolf", game.player.global_position + offset)
	game.add_enemy(e)
	return e


## Remove only the test DUMMIES (zone_idx -1), plus projectiles and
## lingering ult effects. Never touches the real room monsters.
func _clear_combat() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == -1:
			e.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	game.player.storm_time = 0.0
	game.player.berserk_time = 0.0


## Teleport into a room the way the game would enter it (builds it
## lazily, moves the camera clamp, marks it visited).
func _goto_room(i: int) -> void:
	game.player.global_position = game.room_center(i)
	game._enter_room(i)
	await _frames(3)


## Kill every living non-boss monster that belongs to room i.
func _kill_room(i: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss) and not e.dying:
			e.take_damage(9999999.0)
			await _frames(1)
	await _frames(10)


## All living non-boss monsters of room i.
func _room_mobs(i: int) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss) and not e.dying:
			out.append(e)
	return out


## Fingerprint of the current layout (room coords in index order).
func _layout_sig() -> String:
	var bits: Array = []
	for i in game.zone_count:
		bits.append(str(game.rooms[i]["coord"]))
	return ",".join(bits)


## The direction of the door in room a that leads to room b ("" = no
## such door). Layouts are SEEDED now — tests must never assume one.
func _dir_between(a: int, b: int) -> String:
	for d in game.rooms[a]["exits"].keys():
		if game.neighbor(a, String(d)) == b:
			return String(d)
	return ""


## The first interactable whose prompt matches, searched by prompt text.
func _find_action(prompt: String) -> Callable:
	for entry in game.interactables:
		if entry["prompt"].text == prompt:
			return entry["action"]
	return Callable()
