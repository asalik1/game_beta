extends ShotRig
## Scholar Ivo (ch2 Crystal Deeps) — in-world sprite + codex Folk entry.
##   shot.bat ivo [--timeout=120] [--zoom=2.0]
## Warps into the Deeps room, stands the hero beside Ivo at his authored spot
## and shoots him on the crystal floor (the read that matters: body height vs
## the hero, colour against the crystal ground), then opens the codex Folk
## section on his row so the ledger icon + detail portrait are checked too.

const ROOM := "The Crystal Deeps"


func _ready() -> void:
	await boot("warrior", "ch2")
	hide_hud()
	var zi := -1
	for i in game.zones.size():
		if String(game.zones[i].get("name", "")) == ROOM:
			zi = i
			break
	if zi < 0:
		print("IVO RIG: room '%s' not found in ch2 zones" % ROOM)
		finish(1)
		return
	step("enter " + ROOM)
	game._enter_room(zi)
	await frames(3)
	# Ivo's authored spot is (1030, 250) in room space; the hero stands a body
	# to his left so the two heights read side by side.
	var ivo_pos: Vector2 = game.room_pos(zi, 1030, 250)
	game.player.global_position = ivo_pos + Vector2(-90, 10)
	game.player.velocity = Vector2.ZERO
	game.camera.global_position = ivo_pos
	zoom(float(arg("zoom", "2.0")))
	await sim_wait(0.6)
	shot("ivo_deeps", "room=%d" % zi)
	zoom(4.0)
	await sim_wait(0.3)
	shot("ivo_deeps_close", "room=%d" % zi)
	zoom(2.0)
	# Codex: Folk section, Ivo's row selected.
	step("codex folk")
	game.hud.visible = true
	UICodex._filters["npcs"] = {}
	UICodex._selected["npcs"] = "scholar_ivo"
	game.menus.open_codex("npcs")
	await sim_wait(0.8)
	shot("codex_folk_ivo")
	game.menus.close()
	await frames(2)
	# Dialogue: talk to him so the splash / portrait fallback shows.
	step("talk")
	game.run_convo_id("ch2_scholar")
	await sim_wait(0.6)
	shot("ivo_dialogue")
	finish()
