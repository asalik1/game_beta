extends Node
## PHANTOM identity shot rig (dev, temporary): boots the real game as the
## assassin, equips the UNAWAKENED Phantom mythic, and screenshots every
## identity layer in play: settled-dark idle + soul-mist wisps, the walking
## ghost trail, the spectral-charge brightening ramp, the dash streak, the
## teal stab crescent, the charged kunai fan, and the Death Mark blade storm.
## Drives REAL key input (parse_input_event) so SkinAmbient sees genuine
## velocity — no clip-machine shortcuts.
## Run windowed:  godot --path game res://shot_phantom_id.tscn

var game: Game


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("user://shots/phantom_id")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s.png" % [dir, nm])
	var charge := "?"
	if game.player._skin_ambient != null and is_instance_valid(game.player._skin_ambient):
		charge = "%.2f" % float(game.player._skin_ambient.get("charge"))
	print("SHOT: %s/%s.png (charge %s)" % [dir, nm, charge])


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


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
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active: game.hud._choose(0)
		else: game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	var p := game.player
	p.max_hp = 999999.0; p.hp = 999999.0
	p.mp = 9999.0
	p.skin = "phantom"
	p.refresh_skin_sprite()
	await get_tree().create_timer(1.0).timeout
	game.hud.visible = false
	game.camera.zoom = Vector2(1.25, 1.25)

	# 1) settled idle: charge 0 -> 40% dark dip, soul-mist wisps at the feet
	#    (cadence 0.9-1.5s, so two shots catch at least one wisp mid-rise).
	await get_tree().create_timer(1.6).timeout
	_shot("idle_settled_mist_a")
	await get_tree().create_timer(1.1).timeout
	_shot("idle_settled_mist_b")

	# 2) walk: ghost after-images every 0.14s + the spectral charge ramping
	#    (4.2s of motion to full). Alternate directions to stay inside the room.
	_key(KEY_D, true)
	await get_tree().create_timer(1.2).timeout
	_shot("walk_ghosts_early")
	_key(KEY_D, false); _key(KEY_S, true)
	await get_tree().create_timer(1.6).timeout
	_shot("walk_charging_mid")
	_key(KEY_S, false); _key(KEY_A, true)
	await get_tree().create_timer(1.8).timeout
	_shot("walk_fully_charged")

	# 3) dash while charged: the thin spectral streak along the dash line.
	p.cds["a2"] = 0.0
	p.use_ability("a2")
	await _frames(3)
	_shot("dash_streak")
	_key(KEY_A, false)
	await get_tree().create_timer(0.4).timeout

	# a target for the aimed abilities
	var dummy := Enemy.make(game, "wolf", p.global_position + Vector2(0, -160))
	game.add_enemy(dummy)
	dummy.max_hp = 999999.0; dummy.hp = 999999.0
	await _frames(6)

	# 4) stab: the clean teal SlashArc crescent (fires STAB_STRIKE_DELAY late).
	p.cds["a1"] = 0.0
	p.use_ability("a1")
	await get_tree().create_timer(Balance.STAB_STRIKE_DELAY + 0.05).timeout
	_shot("stab_crescent")
	await get_tree().create_timer(0.5).timeout

	# 5) fan of knives while still part-charged: ghostly kunai + spectral
	#    streak + solid teal ghost-echoes shed in flight.
	p.cds["a3"] = 0.0
	p.use_ability("a3")
	await get_tree().create_timer(Balance.KNIFE_THROW_RELEASE + 0.08).timeout
	_shot("fan_knives_a")
	await _frames(6)
	_shot("fan_knives_b")
	await get_tree().create_timer(0.6).timeout

	# 6) ult: splash-art screen wash (HUD layer - re-show it) + the 16-blade
	#    spectral storm converging on the mark over ~4s.
	game.hud.visible = true
	p.cds["ult"] = 0.0
	p.use_ability("ult")
	await get_tree().create_timer(0.3).timeout
	_shot("ult_splash_ring")
	await get_tree().create_timer(1.2).timeout
	_shot("ult_storm_converging")
	await get_tree().create_timer(2.0).timeout
	_shot("ult_storm_late")

	print("PHANTOM ID SHOTS DONE")
	get_tree().quit(0)
