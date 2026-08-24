extends ShotRig
## Gem regen showcase (2026-08-21, owner fidelity ruling): the codex Gems page +
## a max-level gem detail popover now serve the 128px gem_codex_icon masters.
## Run:  shot.bat gems
func _ready() -> void:
	await boot("warrior", "ch1")
	hide_hud()
	game.menus.open_codex("gems")
	await frames(6)
	shot("01_codex_gems")
	game.menus.close()
	await frames(4)
	var g := Items.make_gem("magpen", 10)
	game.menus._open_detail_popover(Art.gem_codex_icon(Items.gem_color(g), 10),
		Items.gem_title(g), Items.gem_color(g),
		"A regular gem — any socket on C+ gear. Synthesize three into one Lv+1.",
		[], GearFlavor.of(g))
	await frames(6)
	shot("02_gem_popover")
	finish()
