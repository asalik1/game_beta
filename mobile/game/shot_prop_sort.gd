extends ShotRig
## PROP-SORT PROOF rig (dev, temporary — 2026-08-28 statue/decor sort fix):
## spawns a mausoleum and a toadstool beside the hero and photographs her
## standing IN FRONT of and BEHIND each — proof that composite-structure parts
## now y-sort against the hero (the mausoleum statues' z=1 used to bury a hero
## standing plainly in front of them) and that solid decor reads as an object
## (covers her boots from the north, is covered from the south).
##   shot.bat prop_sort [--timeout=N]


func _ready() -> void:
	await boot("archer", "ch1")
	hide_hud()
	zoom(2.0)
	await sim_wait(0.5)
	var base: Vector2 = game.player.global_position + Vector2(0, -40)
	game._add_structure("mausoleum", base)
	game._add_obstacle("toadstool", base + Vector2(220, 30), 1.0)
	# Plainly IN FRONT of the right-hand statue (feet south of its painted
	# base, head overlapping its art): the statue must never cover her.
	game.player.global_position = base + Vector2(84, 42)
	await sim_wait(0.3)
	shot("statue_front")
	# BEHIND the statue: it covers her and the occlusion outline shows.
	game.player.global_position = base + Vector2(84, -20)
	await sim_wait(0.3)
	shot("statue_behind")
	# Toadstool from the south: the hero covers the cap...
	game.player.global_position = base + Vector2(220, 52)
	await sim_wait(0.3)
	shot("toadstool_front")
	# ...and from the north the cap covers her boots (was a floor sticker
	# that always rendered under her feet).
	game.player.global_position = base + Vector2(220, 8)
	await sim_wait(0.3)
	shot("toadstool_behind")
	finish()
