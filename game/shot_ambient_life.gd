extends ShotRig
## Controlled population/room views; no combat, rewards or art replacement.
const AmbientChecks := preload("res://scripts/tests/ambient_life_live.gd")


func _ready() -> void:
	await boot("mage", "ch1", false)
	var error: String = await AmbientChecks.run(self)
	if error != "":
		push_error(error)
		finish(1)
	else:
		finish()
