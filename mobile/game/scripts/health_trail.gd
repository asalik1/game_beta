extends RefCounted
## One target's lost-health trail. Changing targets or healing never fabricates
## damage; repeated hits refresh the reading time of the accumulated loss.

var target_id := 0
var shown := 1.0
var previous := 1.0
var hold := 0.0


func step(id: int, fraction: float, delta: float) -> float:
	fraction = clampf(fraction, 0.0, 1.0)
	if id != target_id or fraction > previous:
		shown = fraction
		hold = 0.0
	elif fraction < previous:
		hold = Balance.TARGET_DAMAGE_HOLD
	else:
		var drain_time := maxf(0.0, delta - hold)
		hold = maxf(0.0, hold - delta)
		shown = move_toward(shown, fraction, Balance.TARGET_DAMAGE_DRAIN * drain_time)
	target_id = id
	previous = fraction
	return shown
