extends ShotRig
## One public watchdog/verdict; inherited paired boot lives in the adapter.
const Pair := preload("res://scripts/tests/guest_blink_enet_live.gd")

func _ready() -> void:
	var live := Pair.new()
	live.owner_rig = self
	live.rig_name = rig_name
	live.shot_dir = shot_dir
	add_child(live)
	var code: int = await live.run()
	game = null
	finish(code)
