extends ShotRig
## Screenshot the ground FLOOR for a set of terrains, painted onto the room the
## hero is standing in, at NATIVE zoom (1.0) so the floor resolution reads
## honestly next to the crisp props/hero. Validates the authored ground_field
## pipeline (GPU-tiled crisp base + transparent-base detail + road band).
##   shot.bat floorfield --terrains=keep,graveyard,holy --timeout=120
## Default set covers a field kind (keep) and a still-procedural kind (graveyard)
## so both render paths are proven in one run.


func _ready() -> void:
	await boot("warrior", "ch1")
	hide_hud()
	zoom(1.0)
	var ids := arg("terrains", "keep,graveyard").split(",", false)
	var burst := int(arg("burst", "0"))   # >0: capture a frame series (for a motion GIF)
	for tid in ids:
		step("paint " + tid)
		apply_terrain(tid, game.cur_room)
		await sim_wait(0.5)
		if burst > 0:
			for i in burst:
				await sim_wait(0.09)
				shot("burst_%s_%02d" % [tid, i], "terrain=" + tid)
		else:
			shot("floor_" + tid, "terrain=" + tid)
	finish()
