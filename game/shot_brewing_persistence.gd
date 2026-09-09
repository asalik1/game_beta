extends ShotRig
## The public runner owns one watchdog, capture namespace and completion marker.
const LivePair := preload("res://scripts/tests/brewing_persistence_live.gd")


func _ready() -> void:
	var live := LivePair.new()
	live.owner_rig = self
	live.rig_name = rig_name
	live.shot_dir = shot_dir
	add_child(live)
	var code: int = await live.run()
	game = live.game
	shot_dir = live.shot_dir
	finish(code)
