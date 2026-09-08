extends ShotRig
## Exercise the real boss factory, death signal and chapter-completion order.
var results := {}


func _ready() -> void:
	await boot("mage", "ch1", false)
	var error := await _checks()
	print("FIRST CONQUEST LIVE: ", JSON.stringify(results))
	if flag("diagnostic"):
		print("FIRST CONQUEST DIAGNOSTIC ONLY: inspect the report; assertions are bypassed")
		return finish()
	if error != "":
		push_error(error)
		shot("failed")
		return finish(1)
	print("ok: first conquest live: real final-boss death pays solo spoils before completion, replay remains single-claim and late-chapter package includes its gem")
	finish()


func _checks() -> String:
	game.player.set_physics_process(false)
	game.player.pending_theme_note = ""
	game.flags.erase("completed_ch1")
	game.flags.erase("first_clear_paid_ch1")
	game.mailbox = []
	game.terrain_event_t = 10000.0
	game.settings["camera_shake"] = 0.0
	var error := await _kill_final("first", 1)
	if flag("diagnostic"):
		return ""
	if error != "":
		return error
	await skip_dialogue()
	await sim_wait(0.6)
	if game.state != Game.ST_VICTORY:
		return "solo closer did not reach its victory card"
	shot("02_first_conquest_results")
	game.state = Game.ST_PLAYING
	game.request_pause(false)
	game.hud.hide_results()
	game.hud.overlay.color = Color.TRANSPARENT
	error = await _kill_final("replay", 1)
	if error != "":
		return error
	await skip_dialogue()
	await sim_wait(0.6)
	game.state = Game.ST_PLAYING
	game.request_pause(false)
	game.hud.hide_results()
	game.hud.overlay.color = Color.TRANSPARENT
	game.flags.erase("completed_ch4")
	game.flags.erase("first_clear_paid_ch4")
	game.switch_chapter("ch4", true)
	game.player.set_physics_process(false)
	await frames(4)
	await skip_dialogue()
	error = await _kill_final("late_chapter", 1)
	if error != "":
		return error
	await skip_dialogue()
	await sim_wait(0.6)
	game.state = Game.ST_PLAYING
	game.request_pause(false)
	game.hud.hide_results()
	game.hud.overlay.color = Color.TRANSPARENT
	game.menus.open_mailbox()
	await frames(3)
	shot("04_first_conquest_mailbox")
	return ""


func _kill_final(label: String, expected: int) -> String:
	var kind := String(Story.chapter(game.chapter_id).final_boss)
	var boss := Boss.make_boss(game, kind, game.player.global_position + Vector2(240, 0), 12)
	boss.story_boss = true
	boss.zone_idx = game.cur_room
	game.current_boss = boss
	game.bosses.append(boss)
	game.world.add_child(boss)
	boss.set_physics_process(false)
	await frames(2)
	boss.take_damage(9999999.0)
	await frames(6)
	var count := 0
	var package: Dictionary = {}
	for letter in game.mailbox:
		if String(letter.get("subject", "")) == "Spoils of " + String(Story.chapter(game.chapter_id).name):
			count += 1
			package = letter
	results[label] = {"spoils": count, "completed": game.get_flag("completed_" + game.chapter_id),
		"paid": game.get_flag("first_clear_paid_" + game.chapter_id)}
	shot("01_%s_final_boss_falls" % label)
	if count != expected or not game.get_flag("completed_" + game.chapter_id) or not game.get_flag("first_clear_paid_" + game.chapter_id):
		return label + " final-boss path did not pay exactly one durable first-clear package"
	var item_count := 2 if Balance.regular_gems_drop(game.loot_chapter()) else 1
	if package.get("items", []).size() != item_count:
		return label + " first-conquest package lost its chapter-specific contents"
	return ""
