extends ShotRig
## Idle-breath verification (owner flag 2026-08-21: "archer floats — coded bob").
## The breath was reworked from a whole-sprite y-bob to a feet-pinned vertical
## scale. This rig boots the ARCHER, stands her idle, and photographs six
## phases across one ~1.33s breath cycle; the analyzer diffs the frames — the
## changing region must sit in the upper body, the feet line must be static.
## Run:  shot.bat breath
func _ready() -> void:
	await boot("archer", "ch1")
	hide_hud()
	zoom(2.0)
	await sim_wait(0.6)   # settle: any spawn/walk clip ends, idle loop holds
	step("breath_series")
	sim_reset()
	for i in 6:
		await sim_wait_until(0.22 * (i + 1))
		shot("breath_%d" % i)
	finish()
