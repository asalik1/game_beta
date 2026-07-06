extends "res://scripts/player_kit_warrior.gd"
## PLAYER, layer 4 of 9 — the ARCHER kit: dispatch + abilities.
## (_storm_strike is driven per-frame by player.gd while storm_time runs.)
## See player_core.gd for the chain layout.


func _use_archer(slot: String, f: float) -> void:
	match slot:
		"a1": _shoot(aim_dir(), 0.85 * f)
		"a2": _multishot(f)
		"a3": _tumble()
		"ult":
			storm_time = 3.0
			storm_fx = _tfx.duplicate()
			_ult_sfx()
			_ring_fx(global_position, _tcolor if _themed else Color(0.6, 1.0, 0.6), 190.0)
			game.hud.flash_screen(Color(0.6, 1.0, 0.6), 0.3, 0.35)
			game.spawn_text(global_position + Vector2(0, -60), "ARROW STORM!", Color(0.6, 1, 0.6))


func _shoot(dir: Vector2, mult: float) -> void:
	game.sfx("bow")
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	_proj(dir, mult, "arrow", 520.0)


func _multishot(f := 1.0) -> void:
	# ONE release sound for the whole volley — five overlapping copies of
	# the same sample phase into a nasty digital flanging artifact.
	# Pitched lower than Quick Shot so the two are distinguishable.
	game.sfx("slash", 0.85)
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	var count := int(_tfx.get("knives", 5))
	var step := 0.05 if _tfx.get("narrow", 0) else float(_tfx.get("spread", 0.16))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), 0.55 * f, "arrow", 520.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))


func _tumble() -> void:
	game.sfx("blink")
	# Round 45: the outright 0.5s negate on a 6s cd was too forgiving —
	# safety belongs to positioning, not a free button. The immunity is
	# now a split-second PERFECT-DODGE window (skill-timed against a hit),
	# and the roll leaves the archer NIMBLE — a soft evasion buff covers
	# the reposition so an average pilot still has margin, not a wall.
	hurt_cd = maxf(hurt_cd, 0.1)
	dodge_time = 1.25
	dodge_amt = 0.20
	var origin := global_position
	global_position = game.clamp_to_zone(global_position + facing * 130.0, global_position)
	# The roll reads as motion: ghost trail + kicked-up dust behind you.
	_afterimages(origin, global_position, _tcolor if _themed else Color(0.9, 0.95, 1.0), 2)
	game.burst(origin, Color(0.75, 0.7, 0.6), 6)
	if _tfx.has("burst_origin"):
		# Storm: discharge where you left.
		game.sfx("nova", 1.2)
		game.burst(origin, _tcolor, 12)
		for e in _enemies_within(origin, 110.0):
			hit_enemy(e, float(_tfx["burst_origin"]), {"aoe": true})
	if _tfx.get("mist_origin", 0):
		# Venom: leave a toxin cloud behind.
		_mist(origin, 95.0, 0.35, _tcolor, 2.5)
	if _tfx.get("next_crit", 0):
		# Hunt: line up the next shot.
		next_crit = true
		game.spawn_text(global_position + Vector2(0, -60), "LINED UP", Color(1, 0.7, 0.3))


func _storm_strike() -> void:
	var e: Enemy = null
	if storm_fx.get("focus", 0):
		# Hunt: every arrow hunts YOUR target.
		e = auto_aim(560.0)
	else:
		var targets := _enemies_within(global_position, 560.0)
		if not targets.is_empty():
			e = targets[randi() % targets.size()]
	if e == null:
		return
	# Falling-arrow whoosh (deep-pitched), NOT the synth laser zap.
	game.sfx("knife", 0.75)
	# An arrow visibly falls out of the sky onto the target.
	var arrow := Sprite2D.new()
	arrow.texture = Art.tex("arrow")
	arrow.rotation = PI / 2.0
	arrow.scale = Vector2(3, 3)
	arrow.global_position = e.global_position + Vector2(randf_range(-10, 10), -160)
	arrow.z_index = 30
	game.add_child(arrow)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position:y", e.global_position.y, 0.11)
	tween.tween_callback(arrow.queue_free)
	game.burst(e.global_position, Color(0.7, 1.0, 0.7))
	var storm_col := _theme_color("ult") if ability_theme.get("ult", "") != "" else Color(0.7, 1.0, 0.7)
	_ring_fx(e.global_position, storm_col, 42.0)
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	# The storm rains for 3s while the archer keeps casting — resolve each
	# arrow with the ULT's payload snapshot, not whatever _tfx holds now
	# (the Consecration save-restore idiom).
	var saved := _tfx
	_tfx = storm_fx
	hit_enemy(e, 0.8, eff)
	_tfx = saved
