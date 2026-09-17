extends RefCounted

## Claude-authored regression; Codex adds explicit fallback/side/lock controls
## and validates saved references before typed restoration.
## Sticky soft-target commitment (player_combat._update_soft_target).
## Scenario 1 is the regression baseline for the far-side-fallback hop:
## steering toward an EMPTY side while two chasers press the other side must
## keep the committed target ("else keep kiting the one behind you").
## Scenarios 2-4 pin the behaviors a fix must NOT change: the deliberate
## steered-side switch, same-side keep hysteresis, and idle acquisition.
##
## Synchronous fixture (test_target_visibility idiom): no frame advances while
## the shared hero is borrowed; probes live far from authored room scatter so
## no real enemy sits inside SOFT_TARGET_ACQUIRE of the origin. Drives the same
## `_update_soft_target(move)` entry player.gd feeds with intent_move each
## physics frame — the defect lives entirely inside that pure function.


static func run(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var saved := {"position": p.global_position, "soft": p.soft_target,
		"locked": p.locked_target}
	var origin := Vector2(-14600, -14600)
	p.global_position = origin
	p.locked_target = null
	# Two chasers on the LEFT: the sticky target is the FARTHER one (KEEP
	# hysteresis holds a first-acquired enemy while a nearer one closes in).
	var committed := Enemy.make(g, "wolf", origin + Vector2(-320, 0), -1, 1.0)
	g.world.add_child(committed)
	var near_chaser := Enemy.make(g, "wolf", origin + Vector2(-140, 0), -1, 1.0)
	g.world.add_child(near_chaser)
	# A RIGHT-side enemy, parked outside ACQUIRE until scenario 2 needs it.
	var right_enemy := Enemy.make(g, "wolf", origin + Vector2(5000, 0), -1, 1.0)
	g.world.add_child(right_enemy)
	var error := _checks(p, origin, committed, near_chaser, right_enemy)
	for e in [committed, near_chaser, right_enemy]:
		if is_instance_valid(e):
			e.free()
	p.global_position = saved.position
	p.soft_target = saved.soft if is_instance_valid(saved.soft) else null
	p.locked_target = saved.locked if is_instance_valid(saved.locked) else null
	if error == "":
		print("ok: kiting away holds the committed soft target; a real steered-side enemy still takes the switch, same-side keep and idle acquisition unchanged")
	return error


static func _checks(p: Player, origin: Vector2, committed: Enemy,
		near_chaser: Enemy, right_enemy: Enemy) -> String:
	# --- 1. Regression baseline: steer toward the EMPTY right side. ---------
	# Unfixed code: _nearest_enemy(ACQUIRE, +1) finds nothing on the right and
	# returns its far-side fallback (near_chaser) -> the commitment hops.
	p.soft_target = committed
	p._update_soft_target(Vector2(1, 0))
	if p.soft_target != committed:
		return "kiting toward an empty side hopped the sticky target to an off-side enemy"

	# --- 2. Deliberate steer: a real enemy waits on the steered side. -------
	right_enemy.global_position = origin + Vector2(260, 0)
	p._update_soft_target(Vector2(1, 0))
	if p.soft_target != right_enemy:
		return "steering toward a waiting enemy no longer switches the soft target"

	# --- 3. Keep hysteresis: steering toward the current target's own side
	# must hold it even with a nearer enemy on that side. --------------------
	p.soft_target = committed
	p._update_soft_target(Vector2(-1, 0))
	if p.soft_target != committed:
		return "same-side steering broke the keep hysteresis"

	# --- 4. Acquisition: no commitment, no steer -> nearest, unchanged. -----
	p.soft_target = null
	p._update_soft_target(Vector2.ZERO)
	if p.soft_target != near_chaser:
		return "idle acquisition no longer picks the nearest enemy"

	# Keep acquisition's off-side fallback even while steering into empty space.
	right_enemy.global_position = origin + Vector2(5000, 0)
	p.soft_target = null
	p._update_soft_target(Vector2.RIGHT)
	if p.soft_target != near_chaser:
		return "empty-side initial acquisition lost its nearest fallback"

	# Mirrored retreat: the rule must not depend on world left/right.
	committed.global_position = origin + Vector2(320, 0)
	near_chaser.global_position = origin + Vector2(140, 0)
	p.soft_target = committed
	p._update_soft_target(Vector2.LEFT)
	if p.soft_target != committed:
		return "leftward retreat broke the mirrored sticky commitment"
	committed.global_position = origin + Vector2(-320, 0)
	near_chaser.global_position = origin + Vector2(-140, 0)

	# An overhead fallback is not on the explicitly steered horizontal side.
	near_chaser.global_position = origin + Vector2(0, -140)
	p.soft_target = committed
	p._update_soft_target(Vector2.RIGHT)
	if p.soft_target != committed:
		return "empty-side steering switched to an overhead fallback"
	near_chaser.global_position = origin + Vector2(-140, 0)

	# A hard lock still overrides the soft choice at the actual aim seam.
	p.locked_target = near_chaser
	if p._aim_target(Balance.SOFT_TARGET_ACQUIRE) != near_chaser:
		return "hard lock stopped overriding the sticky soft target"
	p.locked_target = null
	right_enemy.global_position = origin + Vector2(260, 0)

	# A dead commitment must still drop and re-acquire (KEEP gate, not ours,
	# but it guards the fix from over-holding an invalid target).
	p.soft_target = committed
	committed.dying = true
	p._update_soft_target(Vector2(1, 0))
	committed.dying = false
	if p.soft_target == committed:
		return "a dying enemy kept the soft-target commitment"
	return ""
