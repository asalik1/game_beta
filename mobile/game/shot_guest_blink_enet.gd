extends ShotRig
## One public watchdog/verdict; inherited paired boot lives in the adapter.
const Pair := preload("res://scripts/tests/guest_blink_enet_live.gd")
const Healing := preload("res://scripts/tests/guest_healing_live.gd")
const DeathMark := preload("res://scripts/tests/guest_deathmark_live.gd")

func _ready() -> void:
	var live = Healing.new() if flag("healing") else DeathMark.new() if flag("deathmark") else Pair.new()
	live.owner_rig = self
	live.rig_name = rig_name
	live.shot_dir = shot_dir
	add_child(live)
	var code: int = await live.run()
	game = null
	finish(code)
