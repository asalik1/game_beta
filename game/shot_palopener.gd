extends ShotRig
## Paladin chapter-opener plate check: boots as paladin, plays the opening
## cinematic for a set of chapters, and screenshots the authored plate at each
## narrator beat so the reskinned paladin art can be eyeballed in-engine.
##   shot.bat palopener [--chapters=ch2,ch8,ch11] [--timeout=180]

func _ready() -> void:
	await boot("paladin", "ch1")
	var chapters := arg("chapters", "ch1,ch2,ch8,ch11").split(",", false)
	for chid in chapters:
		step("opener " + chid)
		# Force the cinematic to replay: clear the seen flag, switch chapter data.
		game.set_flag("saw_chapter_opening_" + chid, false)
		var convo_id := chid + "_opening_paladin"
		if not Story.ALL_CONVOS.has(convo_id):
			print("PALOPENER: no convo %s" % convo_id)
			continue
		game.run_cinematic_convo(convo_id, func() -> void: pass)
		# Step through the beats; the cue paints a plate on each narrator node.
		for beat in range(4):
			await sim_wait(0.9)
			shot("%s_beat%d" % [chid, beat])
			if game.hud.choices_active:
				game.hud._choose(0)
			elif game.hud.dialogue_active:
				game.hud._advance_dialogue()
			await frames(2)
		# Close out any lingering cutscene before the next chapter.
		var guard := 0
		while (game.hud.dialogue_active or game.hud.choices_active) and guard < 30:
			if game.hud.choices_active: game.hud._choose(0)
			else: game.hud._advance_dialogue()
			await frames(2); guard += 1
		await sim_wait(0.3)
	finish()
