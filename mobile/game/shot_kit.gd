extends Node
## FX CAMERA RIG (dev tool, not part of the game): boots the real game
## windowed, plays a class through its abilities, and saves viewport
## PNGs at animation peaks — so ability FX can be judged by LOOKING.
## Run:  godot --path game res://shot_kit.tscn
## Output: user://shots/*.png  (printed absolute path at the end)

var game: Game
var shot_prefix := ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var full_name := "%s_%s" % [shot_prefix, shot_name] if shot_prefix != "" else shot_name
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % full_name))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/%s.png" % full_name))


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	# Class under the lens: --class=<name> after "--" (default assassin).
	# The a1/a2/a3/ult sequence below fires generically for any kit; shot
	# names stay assassin-flavored — judge by looking, as always.
	var cls := "assassin"
	var skin := ""
	var terrain := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			cls = arg.trim_prefix("--class=")
		elif arg.begins_with("--skin="):
			skin = arg.trim_prefix("--skin=")
		elif arg.begins_with("--terrain="):
			# Repaint the shooting room — judge FX under a dark tint
			# (voidstone, gravedirt) as well as village daylight.
			terrain = arg.trim_prefix("--terrain=")
	shot_prefix = "%s_%s_%s" % [cls, skin if skin != "" else "base", terrain if terrain != "" else "default"]
	game.menus.pick_class(cls)
	await _frames(5)
	if skin != "":
		game.player.skin = skin
		game.player.refresh_skin_sprite()
		await _frames(2)
	if game.hud.dialogue_active or game.hud.choices_active:
		_shot("dialogue_portrait")  # speaker portrait beside the words
	# Fast-forward the opening (grabbing one NAMED-speaker frame for the
	# portrait check on the way through).
	var guard := 0
	var took_speaker := false
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if not took_speaker and game.hud.portrait_box.visible:
			took_speaker = true
			_shot("dialogue_speaker")
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.player.max_hp = 99999.0
	game.player.hp = 99999.0
	game.player.themes_known = 3
	var dummy := Enemy.make(game, "wolf", game.player.global_position + Vector2(110, 0))
	dummy.max_hp = 9999999.0
	dummy.hp = 9999999.0
	game.add_enemy(dummy)
	if terrain != "":
		game.apply_terrain(0, terrain)
		game.ambient.color = Terrains.get_terrain(terrain)["tint"]
	# One wide establishing shot first — rivers, critters and scenery
	# live out of the close-up lens's reach.
	game.camera.zoom = Vector2(0.75, 0.75)
	await _frames(12)
	_shot("terrain_wide")
	# Second wide frame ~half a sway period later: diffing the two proves
	# the foliage wind shader actually moves (a still can't).
	await get_tree().create_timer(0.55).timeout
	_shot("terrain_wide2")
	var critters := 0
	for n in game.zone_scenery.get(game.cur_room, []):
		if is_instance_valid(n) and n.get("kind") != null:
			critters += 1
	print("CRITTERS in room: ", critters, "  RIVER: ", game.rivers.has(game.cur_room))
	# Close-up lens: FX are unjudgeable at full zoom-out.
	game.camera.zoom = Vector2(2.4, 2.4)
	await _frames(8)

	# STAB mid-lunge (swing anim is 0.16s ~= 10 frames).
	if cls == "archer":
		# Give the delayed release enough flight line to expose its skin trail.
		dummy.global_position = game.player.global_position + Vector2(300, 0)
		await _frames(3)
	game.player.cds["a1"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a1")
	if cls == "archer":
		# Archer releases after an authored bow windup. Bracket the arrow in
		# flight so skin trails are visible instead of photographing empty air.
		await get_tree().create_timer(0.14).timeout
	else:
		await _frames(2)
	_shot("stab_early")
	await _frames(3)
	_shot("stab_mid")
	if cls == "archer" and skin == "frostfall_ranger":
		# The dummy is 300px out: catch the small contact snowflake immediately
		# after the delayed arrow reaches it, before its 0.25s fade completes.
		await _frames(14)
		_shot("frost_impact")
		await _frames(26)
	elif cls == "archer" and skin == "voidwraith":
		# Its bow release is delayed; the generic early frames mostly catch the
		# draw. Wait into the real flight so ribbon brightness/length are visible.
		await _frames(6)
		_shot("void_trail_flight")
		await _frames(34)
	else:
		await _frames(40)

	# FAN OF KNIVES: darts mid-flight — push the dummy out to real
	# chip range so the flight is actually visible before impact.
	dummy.global_position = game.player.global_position + Vector2(300, 0)
	await _frames(3)
	game.player.cds["a3"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a3")
	await _frames(3)
	_shot("knives_early")
	await _frames(4)
	_shot("knives_flight")
	if cls == "archer" and skin == "frostfall_ranger":
		# The generated 8-way dash sheets have direction-specific foot anchors.
		# Bracket the final dash frame and idle handoff so a landing snap cannot
		# hide between the generic early-flight and next-ability captures.
		await _frames(24)
		_shot("frost_dash_landing")
		await _frames(8)
		_shot("frost_dash_idle_handoff")
		await _frames(8)
	else:
		await _frames(40)
	dummy.global_position = game.player.global_position + Vector2(110, 0)
	await _frames(3)

	# SHADOW DASH straight through the dummy: full pass-through should
	# cross two cut strokes into an X on the victim (round 36).
	game.player.facing = Vector2.RIGHT
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(2)
	_shot("dash_x")
	await _frames(30)
	dummy.global_position = game.player.global_position + Vector2(110, 0)
	await _frames(3)

	# ULT: Death Mark — blink-in, then rapid shots through the flurry
	# (frame rate varies between runs; bracket the rip window).
	# Void Maw is a multi-actor field: only now surround its centre with enough
	# durable targets to judge all eight roots without crowding the arrow capture.
	if cls == "archer" and skin == "voidwraith":
		for offset in [Vector2(72, -82), Vector2(150, -88), Vector2(235, -42),
			Vector2(238, 64), Vector2(154, 92)]:
			var extra := Enemy.make(game, "wolf", game.player.global_position + offset)
			extra.max_hp = 9999999.0
			extra.hp = 9999999.0
			game.add_enemy(extra)
	game.player.cds["ult"] = 0.0
	# Each class reaches this point after three different resource spends.
	# Refill explicitly so low-capacity kits (Warrior is exactly 40/40) do
	# not turn an ult capture into a silent cast-rejected screenshot.
	game.player.mp = game.player.max_mp
	game.player.use_ability("ult")
	await get_tree().create_timer(0.06).timeout
	_shot("ult_declaration")
	await get_tree().create_timer(0.24).timeout
	_shot("ult_midbeat")
	await get_tree().create_timer(0.34).timeout
	_shot("ult_payoff")
	await get_tree().create_timer(0.50).timeout
	_shot("ult_aftermath")
	await _frames(30)

	# --- visual-pass extras -------------------------------------------
	game.hud.boss_banner("KORRAG, STORMWARDEN BROKEN")
	await _frames(14)
	_shot("boss_banner")
	await get_tree().create_timer(2.4).timeout
	if terrain != "":
		# Park ~120px SOUTH of the north wall (QA finding 6: parking AT
		# the wall clamps the camera and pushes both off-frame) — the
		# halo's wall shadow stays fully visible.
		game.player.global_position = game.rooms[0]["origin"] + Vector2(700.0, 270.0)
		await _frames(10)
		_shot("wall_shadow")
	game.menus.open_inventory()
	await _frames(6)
	_shot("ui_inventory")
	game.menus.open_map()
	await _frames(6)
	_shot("ui_map")
	game.menus.close()
	print("RIG DONE")
	get_tree().quit(0)
