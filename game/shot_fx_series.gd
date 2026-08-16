extends ShotRig
## FX TIME-SERIES rig (dev, temporary — 2026-08-15 FX pass): boots the real
## game, hides the HUD, fires ONE ability and photographs it at a list of
## sim-time offsets, so an effect's LIFETIME can be judged (arrival, peak,
## the lingering tail) — shot_kit's fixed beats miss a mist's fade or a
## meteor's peak. Branches per class:
##   assassin (poison theme): Shadow Dash Toxic Wake + Venom Bloom knife
##   archer   (venom theme):  Tumble toxin cloud
##   mage     (--theme=fire|ice|wind or base): Meteor landing
##   warrior  (--theme=earth): Shield Bash end-slam + Berserk seismic roar
## Run (muted, gated, watchdogged — the ShotRig worked example):
##   shot.bat fx_series [--class=mage] [--theme=ice] [--terrain=keep] [--skin=x]
##                      [--ability=<slot>] [--pin] [--hazards] [--timeout=N]
##   (by hand: godot --audio-driver Dummy --path game res://shot_fx_series.tscn -- ...)
## Output: user://shots/fx_series/<class>[-theme][-skin]_<tag>_<t*100>.png

var cls := "assassin"
var theme := ""
var terrain := ""
var skin := ""


func _tag() -> String:
	var tag := cls if theme == "" else "%s-%s" % [cls, theme]
	if skin != "":
		tag += "-" + skin
	return tag


func _fx_shot(nm: String) -> void:
	# The base line + which FX strips are on screen and at what frame.
	var fx_frames := []
	for c in game.get_children():
		if c is Sprite2D and c.hframes > 1 and c.texture != null:
			fx_frames.append("%d/%d" % [c.frame, c.hframes])
	shot("%s_%s" % [_tag(), nm], "fx=%s" % [fx_frames])


func _series(tag: String, times: Array) -> void:
	# Photograph an effect at SIMULATION-time offsets from now (seconds).
	# sim_wait_until keeps the offsets absolute from this origin (overshoot
	# carries); wall clock was the trap — see ShotRig TIME.
	sim_reset()
	for want in times:
		await sim_wait_until(float(want))
		_fx_shot("%s_%03d" % [tag, int(float(want) * 100.0)])


func _ready() -> void:
	cls = arg("class", cls)
	theme = arg("theme", "")
	terrain = arg("terrain", "")
	skin = arg("skin", "")
	if theme == "":
		theme = {"assassin": "poison", "archer": "venom", "warrior": "earth"}.get(cls, "")
	elif theme == "none":
		theme = ""  # force the unthemed base kit
	await boot(cls, "ch1")
	var p := game.player
	if skin != "":
		p.skin = skin
		p.refresh_skin_sprite()
		await frames(2)
	if theme != "":
		p.themes_known = 3
		p.set_all_themes(theme)
	await get_tree().create_timer(1.0).timeout
	if terrain != "":
		apply_terrain(terrain)
	hide_hud()
	zoom(2.0)
	# Wait out the chapter title card so the frames are clean.
	step("title card")
	await get_tree().create_timer(3.0).timeout

	# A durable target to the right.
	var dummy := spawn_enemy("wolf", p.global_position + Vector2(150, 0))
	await frames(6)
	if flag("pin"):
		# Hold the dummy still so an impact lands ON it (layering proof:
		# actors must read through the effect, never be covered by it).
		dummy.set_physics_process(false)
	_fx_shot("idle")

	if flag("hazards"):
		# Hazard-pool pass: repaint the room through every patch-bearing terrain
		# and photograph the patches wide + close (the strips loop; two beats).
		dummy.queue_free()
		for t in ["magma", "ice", "bog", "holy", "void", "graveyard"]:
			step("hazards " + t)
			apply_terrain(t)
			await get_tree().create_timer(0.8).timeout
			zoom(0.9)
			await frames(3)
			_fx_shot("hz_%s_wide" % t)
			# Walk the hero onto the first patch of this room for the close-up.
			var near: Vector2 = p.global_position
			for h in game.hazards:
				if int(h["zone"]) == 0:
					near = h["pos"]
					break
			p.global_position = near + Vector2(40, 30)
			zoom(2.2)
			await get_tree().create_timer(0.3).timeout
			_fx_shot("hz_%s_close_a" % t)
			await get_tree().create_timer(0.35).timeout
			_fx_shot("hz_%s_close_b" % t)
		finish()
		return

	# --call=<method> fires ONE presentation helper directly on the hero with the
	# dummy as its argument (e.g. --call=_gilded_iai_strike) — isolates a skin
	# FX from its ability's timeline when a beat is hard to bracket.
	var direct := arg("call", "")
	if direct != "":
		step("call " + direct)
		p.call(direct, dummy)
		await _series(direct.trim_prefix("_"), [0.03, 0.1, 0.18, 0.26, 0.36, 0.5, 0.7])
		finish()
		return

	# --ability=<slot> picks a non-default branch (the ring replacements).
	var ability := arg("ability", "")
	if ability != "":
		# One ability, one series (the ring-replacement rigs: paladin a3 Aegis,
		# warlock a3 Dark Pact, archer ult Arrow Storm, warrior a3 Whirlwind).
		step("ability " + ability)
		p.facing = Vector2.RIGHT
		p.cds[ability] = 0.0
		p.mp = p.max_mp
		p.use_ability(ability)
		await _series(ability, [0.05, 0.15, 0.3, 0.5, 0.8, 1.2, 1.8, 2.5, 3.2])
		finish()
		return

	step("class branch " + cls)
	match cls:
		"assassin":
			# Toxic Wake: dash right through the dummy; the wake blooms on the line.
			p.facing = Vector2.RIGHT
			p.cds["a2"] = 0.0
			p.mp = p.max_mp
			p.use_ability("a2")
			await _series("wake", [0.05, 0.2, 0.5, 1.0, 1.6, 2.4, 3.0])
			await get_tree().create_timer(1.0).timeout
			# Venom Bloom: one knife at the dummy (re-seated 150px out).
			dummy.global_position = p.global_position + Vector2(-150, 0)
			await frames(3)
			p.facing = Vector2.LEFT
			p.cds["a3"] = 0.0
			p.mp = p.max_mp
			p.use_ability("a3")
			# The knife leaves after the throw wind-up + ~0.2s flight; bracket it.
			await _series("bloom", [0.25, 0.4, 0.55, 0.8, 1.2, 2.0, 3.0, 3.6])
		"archer":
			# Venom Tumble: the cloud drops where you leave.
			p.velocity = Vector2.LEFT * p.speed
			p.cds["a3"] = 0.0
			p.mp = p.max_mp
			p.use_ability("a3")
			await _series("tumble", [0.05, 0.3, 0.7, 1.4, 2.2, 3.0])
		"mage":
			# Meteor: falls 0.62s, then the landing strip (8 x 0.055s + hold).
			p.cds["ult"] = 0.0
			p.mp = p.max_mp
			p.use_ability("ult")
			await _series("meteor", [0.3, 0.64, 0.72, 0.8, 0.9, 1.0, 1.15, 1.4, 1.8, 2.3])
		"warrior":
			# Earth Shield Bash: the charge ends in the slam.
			p.facing = Vector2.RIGHT
			p.cds["a2"] = 0.0
			p.mp = p.max_mp
			p.use_ability("a2")
			await _series("bash", [0.05, 0.2, 0.3, 0.4, 0.55, 0.8, 1.2])
			await get_tree().create_timer(1.0).timeout
			# Berserk: the seismic roar.
			p.cds["ult"] = 0.0
			p.mp = p.max_mp
			p.use_ability("ult")
			await _series("roar", [0.05, 0.15, 0.25, 0.35, 0.5, 0.8, 1.2])
	finish()
