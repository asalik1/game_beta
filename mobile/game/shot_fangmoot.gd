extends ShotRig
## Fangmoot UI shot rig: boot the game, open the Carver's Circle, play a moot,
## and screenshot the hub / shop / animated arena. Run: shot.bat fangmoot
## Windowed + muted (shot.bat injects --audio-driver Dummy).

func _ready() -> void:
	await boot("warrior", "ch1")
	# Shoot the STANDALONE experience (§18): the self-contained host, full roster,
	# Quit button, no campaign underneath.
	game.menus.fm_standalone = true
	game.menus.fm_host = FangmootHostStandalone.new()

	step("open hub")
	game.menus.open_fangmoot()
	await frames(5)
	shot("1_hub")

	step("start moot")
	UIFangmoot._start(game.menus, "silver")
	await frames(5)
	shot("2_shop_empty")

	step("buy tokens")
	var mo: FangmootMoot = game.menus.fm_moot
	_buy_some(mo)
	UIFangmoot.open(game.menus)
	await frames(5)
	shot("3_shop_filled")

	step("call moot")
	UIFangmoot._call(game.menus)
	await frames(6)
	shot("4_arena_start")
	await sim_wait(1.4)
	shot("5_arena_mid")
	await sim_wait(7.0)
	shot("6_arena_end")

	finish()


func _buy_some(mo: FangmootMoot) -> void:
	# exercise the real click-to-buy path (rebuilds the UI each time)
	var guard := 20
	while guard > 0 and mo.board_count() < 2:
		guard -= 1
		var idx := -1
		for i in mo.tray.size():
			var ct := String(mo.tray[i]["ctype"])
			if (ct == "token" or ct == "named") and mo.can_buy(i) and _empty(mo):
				idx = i
				break
		if idx < 0:
			break
		UIFangmoot._quick_buy(game.menus, idx)


func _empty(mo: FangmootMoot) -> bool:
	for s in mo.board.size():
		if mo.board[s] == null:
			return true
	return false
