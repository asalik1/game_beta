extends ShotRig
## Paladin hero splash check: boots as paladin and shows a hero-spoken dialogue
## line so the class splash (class_splash_paladin.png) renders full-bleed.
##   shot.bat palsplash [--timeout=120]

func _ready() -> void:
	await boot("paladin", "ch1")
	var convo := {"start": "a", "nodes": {"a": {
		"who": "You",
		"text": "For the bench, and for the ember. I will hear this to its end.",
		"next": "",
	}}}
	game.run_convo(convo)
	await sim_wait(0.7)
	shot("paladin_hero_splash")
	finish()
