extends ShotRig
## Controlled population/room views; no combat, rewards or art replacement.
const AmbientChecks := preload("res://scripts/tests/ambient_life_live.gd")


func _ready() -> void:
	await boot("mage", "ch1", false)
	var error: String
	if flag("weather-depth"):
		error = await preload("res://scripts/tests/weather_depth_live.gd").run(self)
	else:
		error = await AmbientChecks.run(self)
	if error != "":
		push_error(error)
		finish(1)
	else:
		finish()
