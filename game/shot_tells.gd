extends ShotRig
## BOSS TELL review rig (visual overhaul 2026-09-03). Fires one telegraph per
## Balance.BOSS_TELL row on an empty patch of floor and shoots it mid-fuse, so
## the whole vocabulary can be compared on one contact sheet — the answer to
## "boss attacks all look visually similar" has to be judged with eyes, and a
## real fight only ever shows one boss's tells at a time.
##
##   shot.bat tells                  # every styled boss, one frame each
##   shot.bat tells --shapes         # the six shapes at one colour instead
##   shot.bat tells --phase=0.85     # where in the fuse to shoot (default 0.6)
##
## Output: user://shots/tells/*.png

const FUSE := 2.4


func _ready() -> void:
	await boot("warrior", "ch1")
	hide_hud()
	zoom(1.0)
	var phase := float(arg("phase", "0.6"))
	# The camera follows the hero, so the tell has to land ON him — every tell
	# here carries damage 0, so standing in it is free.
	var centre: Vector2 = game.player.global_position + Vector2(0, -30)

	if flag("shapes"):
		var i := 0
		for shape: String in ["disc", "ring", "cone", "line", "cross", "square"]:
			_fire(centre, shape, Color(1.0, 0.45, 0.2, 0.55), Vector2(0.6, -0.8))
			await sim_wait(FUSE * phase)
			shot("shape_%d_%s" % [i, shape])
			await sim_wait(FUSE * (1.0 - phase) + 0.5)
			i += 1
		finish()
		return

	for kind: String in Balance.BOSS_TELL:
		var row: Dictionary = Balance.BOSS_TELL[kind]
		var c: Color = row["color"]
		_fire(centre, String(row.get("shape", "disc")),
			Color(c.r, c.g, c.b, 0.55), Vector2(0.35, -0.94),
			float(row.get("arc", 0.55)))
		await sim_wait(FUSE * phase)
		shot("tell_%s" % kind)
		await sim_wait(FUSE * (1.0 - phase) + 0.5)
	finish()


func _fire(pos: Vector2, shape: String, col: Color, dir: Vector2, arc := 0.55) -> void:
	last_step = "tell %s" % shape
	var opts := {"color": col, "shape": shape, "dir": dir.normalized(), "arc": arc}
	# damage 0: this is a look, not a fight.
	game.telegraph(pos, 150.0, FUSE, 0.0, opts)
