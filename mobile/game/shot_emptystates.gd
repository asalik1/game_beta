extends ShotRig
## Empty/locked-state capture (visual-review P0 fixes, 2026-08-21): boots a
## fresh Chapter 1 warrior — with no_saves the mailbox and account stash are
## empty and only the start room is charted — then photographs each menu the
## review flagged as a "beta cue", so the rebuilt empty states can be eyeballed
## without a play session. Run:  shot.bat emptystates
func _ready() -> void:
	await boot("warrior", "ch1")
	await frames(6)

	step("mailbox_empty")
	game.menus.open_mailbox()
	await frames(6)
	shot("01_mailbox_empty")
	game.menus.close()
	await frames(3)

	step("chapter_select")
	game.menus.open_chapter_select()
	await frames(6)
	shot("02_chapter_select_locked")
	game.menus.close()
	await frames(3)

	step("map_early")
	game.menus.open_map()
	await frames(6)
	shot("03_map_early")
	game.menus.close()
	await frames(3)

	step("stash_empty")
	game.menus.open_stash()
	await frames(6)
	shot("04_stash_empty")
	game.menus.close()
	await frames(3)

	# Some gold so the shop shows a MIX of affordable (gold price) and
	# unaffordable (red price) rows — the restructured card + price column.
	step("shop_buy")
	game.player.gold = 3000
	game.menus.open_shop(game.cur_room)
	await frames(8)
	shot("05_shop_buy")
	game.menus.close()
	await frames(3)

	finish()
