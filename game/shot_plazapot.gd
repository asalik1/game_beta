extends ShotRig
## Plaza pot check (owner flag 2026-08-21: "vase looks warped"). The plaza's
## two clay_pot furnishings were swapped to amphora (clay_pot's source art is
## warped; re-roll queued) — amphora needed its own furnishing registration or
## it lands at the 180px building default. Frame both spots at 2x to verify
## scale + art. Run:  shot.bat plazapot
func _ready() -> void:
	await boot("warrior", "ch1")
	hide_hud()
	step("enter_capital")
	game.enter_capital()
	await frames(6)
	await skip_dialogue()
	var plaza := -1
	for zi in game.zone_count:
		if "Plaza" in String(game.zones[zi].get("name", "")):
			plaza = zi
			break
	if plaza < 0:
		print("RIG FAIL: no Plaza room found")
		return finish(1)
	step("frame_pots")
	zoom(2.0)
	for spot in [[360.0, 985.0, "pot_west"], [1752.0, 985.0, "pot_east"]]:
		var world: Vector2 = game.room_pos(plaza, float(spot[0]), float(spot[1]))
		game.player.global_position = world + Vector2(60, 10)
		await sim_wait(0.4)
		shot(String(spot[2]))
	finish()
