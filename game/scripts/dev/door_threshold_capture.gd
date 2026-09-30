extends RefCounted
## One locked engine session: quick-tier contract, the reported door views of
## the booted chapter, then the existing real-input capgap rig by scene handoff.
##   shot.bat polish --door-thresholds --seed=42017 [--chapter=ch2]
## The visual sweep (shot_polish --tour --chapter=<ch> --seed=42017) never
## logged its wander_seed and the tree has moved since, so --seed alone does not
## rebuild its graph (Emberfall had no west door). Instead, walk seeds from the
## booted one (deterministic per --seed) to the first world in which EVERY
## reported door exists, and shoot each with the sweep's own framing, so it
## compares with visual-sweep/corpus/stills/ambient_<ch>/<room>_west|ndoor.png.
## No such world within SEED_SEARCH seeds FAILS; a view is never a sealed wall.
const Contract := preload("res://scripts/tests/test_door_threshold.gd")
const SEED_SEARCH := 400
const VIEWS := {
	"ch1": [["Emberfall Village", "W"], ["The Darkwood Road", "W"]],
	"ch2": [["The Greyrun Mills", "W"], ["The Greyrun Mills", "N"],
		["The Sporewood", "N"], ["The Null Bastion", "N"]],
}


static func run(rig: Node) -> String:
	var g: Game = rig.game
	var chapter := g.chapter_id
	if not VIEWS.has(chapter):
		return "no reported door views for chapter %s (use --chapter=ch1 or ch2)" % chapter
	var booted := g.wander_seed
	var error := Contract.run(rig)
	if error != "": return error
	var world_seed := -1
	for k in SEED_SEARCH:
		g.wander_seed = booted + k
		g.switch_chapter(chapter, true)
		await rig.frames(1)
		await rig.skip_dialogue()   # a rebuilt start room may open its entry lines
		if _doors_present(rig, g, chapter):
			world_seed = g.wander_seed
			break
	if world_seed < 0:
		return "no world within %d seeds of %d has every reported %s door" % [SEED_SEARCH, booted, chapter]
	rig.step("threshold world: wander_seed %d (booted %d)" % [world_seed, booted])
	await rig.frames(8)
	await rig.skip_dialogue()
	rig.hide_hud()
	rig.zoom(1.0)
	var shots := 0
	for view in VIEWS[chapter]:
		var name: String = view[0]
		var dir: String = view[1]
		var zi: int = rig._room_by_name(name)
		await rig._goto(zi)
		await rig.skip_dialogue()
		error = Contract.room(g, zi)
		if error != "": return name + ": " + error
		var rr := g.room_rect(zi)
		var pos := rr.position + Vector2(230.0, rr.size.y * 0.5)   # the sweep's west view
		if dir == "N": pos = g.door_pos(zi, "N") + Vector2(0, 150.0)  # the sweep's ndoor view
		g.player.global_position = pos
		g.camera.global_position = pos
		g.camera.reset_smoothing()
		g.camera.force_update_scroll()
		await rig.frames(4)
		rig.step("threshold %s %s: room=%s play=%s" % [name, dir, rr, g.play_rect(zi)])
		rig.shot("threshold_%s_%s" % [rig._slug(name), dir.to_lower()],
			"wander_seed %d; %s door present; room footprints clear" % [world_seed, dir])
		shots += 1
	print("DOOR THRESHOLD CAPTURES PASS: %d named %s door views; handing off to capgap" % [shots, chapter])
	var result: int = rig.get_tree().change_scene_to_file("res://shot_capgap.tscn")
	if result != OK: return "capgap scene handoff failed"
	return ""


static func _doors_present(rig: Node, g: Game, chapter: String) -> bool:
	for view in VIEWS[chapter]:
		var zi: int = rig._room_by_name(String(view[0]))
		if zi < 0 or not g.rooms[zi].exits.has(String(view[1])):
			return false
	return true
