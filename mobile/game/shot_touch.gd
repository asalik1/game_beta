extends Node
## TOUCH-HUD VERIFICATION RIG (mobile snapshot dev tool; not shipped).
## Boots the real game windowed WITH the touch HUD forced on, then drives the
## on-screen controls with synthesized touch events and asserts the §10 intent
## seam end-to-end: joystick → analog move → the player actually walks; an
## ability button → a real cast (goes on cooldown); the lock button → a target
## gets locked, and a swipe-off drops it. Saves viewport PNGs for the layout.
##
## Run:  tools\...console.exe --path mobile/game res://shot_touch.tscn -- --touch
## Output: user://shots/touch_*.png  +  a PASS/FAIL line per assertion.

var game: Game
var _fails := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % shot_name))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/%s.png" % shot_name))


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _find_touch_hud() -> TouchHud:
	for c in game.get_children():
		if c is TouchHud:
			return c
	return null


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class("assassin")
	await _frames(5)
	# Fast-forward the opening dialogue.
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	await _frames(5)

	# --- setup: survivable player + a durable dummy to lock/hit --------------
	game.player.max_hp = 99999.0
	game.player.hp = 99999.0
	var th := _find_touch_hud()
	_check(th != null, "TouchHud mounted under --touch")
	if th == null:
		print("TOUCH RIG DONE  (fails=%d)" % _fails)
		get_tree().quit(1)
		return
	_check(th._btns.size() == 8, "ability arc + action buttons built (got %d)" % th._btns.size())
	_check(th._enabled, "touch HUD enabled while playing")
	_shot("touch_rest")

	var vp := get_viewport().get_visible_rect().size

	# --- 1) joystick → analog move → the player walks ------------------------
	var jpos := Vector2(vp.x * 0.22, vp.y * 0.72)
	_touch(jpos, true)
	await _frames(1)
	# Partial tilt (~60% of the max radius) proves the vector stays ANALOG.
	var tilt := Vector2(TouchHud.JOY_MAX * 0.6, 0.0)
	_drag(jpos + tilt, tilt)
	await _frames(1)
	var mv: Vector2 = game.get_node("/root/MobileInput").move
	_check(mv.length() > 0.25 and mv.length() < 0.95, "joystick analog magnitude %.2f (not clamped to 1)" % mv.length())
	_check(mv.x > 0.5, "joystick points right (x=%.2f)" % mv.x)
	var start_pos: Vector2 = game.player.global_position
	await _frames(25)
	_shot("touch_joystick")
	var moved: float = game.player.global_position.distance_to(start_pos)
	_check(moved > 12.0, "player walked via joystick (%.1f px)" % moved)
	_touch(jpos + tilt, false)
	await _frames(2)
	var mv2: Vector2 = game.get_node("/root/MobileInput").move
	_check(mv2 == Vector2.ZERO, "joystick released → move zeroed")

	# --- 2) ability button → a real cast (goes on cooldown) ------------------
	game.player.cds["a1"] = 0.0
	game.player.mp = game.player.max_mp
	var a1c: Vector2 = th._btns["a1"]["center"]
	_touch(a1c, true)                      # hold the button down
	await _frames(6)
	_shot("touch_ability")
	_check(bool(game.get_node("/root/MobileInput").a1), "a1 button sets MobileInput.a1 while held")
	_check(game.player.cds["a1"] > 0.0, "a1 button fired a real cast (cd=%.2f)" % game.player.cds["a1"])
	_touch(a1c, false)
	await _frames(2)
	_check(not bool(game.get_node("/root/MobileInput").a1), "a1 released → flag cleared")

	# --- 3) lock button: tap = lock, hold+swipe-off = release ----------------
	var dummy := Enemy.make(game, "wolf", game.player.global_position + Vector2(120, 0))
	dummy.max_hp = 9999999.0
	dummy.hp = 9999999.0
	game.add_enemy(dummy)
	game.player.locked_target = null
	await _frames(3)
	var lc: Vector2 = th._btns["lock"]["center"]
	_touch(lc, true)                       # quick tap (no drag)
	await _frames(1)
	_touch(lc, false)
	await _frames(4)
	_check(is_instance_valid(game.player.locked_target), "lock button tap acquired a target")
	_shot("touch_lock")
	# Swipe-off release: press, drag well past the threshold, lift.
	_touch(lc, true)
	await _frames(1)
	_drag(lc + Vector2(0, -TouchHud.LOCK_SWIPE_OFF - 30.0), Vector2(0, -TouchHud.LOCK_SWIPE_OFF - 30.0))
	await _frames(1)
	_touch(lc + Vector2(0, -TouchHud.LOCK_SWIPE_OFF - 30.0), false)
	await _frames(4)
	_check(game.player.locked_target == null, "lock swipe-off released the target")

	print("TOUCH RIG DONE  (fails=%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
