extends RefCounted
## One immediate decision about the current target. IDs fit the three unused
## high bits of the existing enemy-state byte; packet size stays unchanged.

enum Cue { NONE, REFLECT, COUNTER, HEAL, POUNCE, EXPOSED, WARD, PLATE }

const TEXT := {
	Cue.REFLECT: "REFLECTING · Hold your fire",
	Cue.COUNTER: "COUNTER STANCE · Wait for an opening",
	Cue.HEAL: "HEALING ALLIES · Hit to interrupt",
	Cue.POUNCE: "POUNCING · Sidestep the leap",
	Cue.EXPOSED: "EXPOSED · Press the attack",
	Cue.WARD: "GUARDED · Break with a crit or status",
	Cue.PLATE: "OBSIDIAN PLATES · Lure onto hot ground",
}


static func code_for(e: Enemy) -> int:
	if e == null or not is_instance_valid(e) or e.dying or e.untargetable:
		return Cue.NONE
	if e.net_mirror:
		return e.net_combat_cue
	# The instruction that prevents self-harm wins over a damage opportunity.
	if e.reflect_t > 0.0:
		return Cue.REFLECT
	if e.counter_t > 0.0:
		return Cue.COUNTER
	if e.channel_t > 0.0:
		return Cue.HEAL
	if e.pounce_windup > 0.0:
		return Cue.POUNCE
	if e.plate_dr > 0.0:
		return Cue.PLATE
	if e is Boss and e.cast_window.exposed > 0.0:
		return Cue.EXPOSED
	if e.vuln_time > 0.0 or e.pounce_whiff > 0.0:
		return Cue.EXPOSED
	if e.traits.has("warded") and not e.ward_broken:
		return Cue.WARD
	return Cue.NONE


static func tint(code: int) -> Color:
	if code in [Cue.HEAL, Cue.EXPOSED]:
		return Color(0.60, 0.96, 0.75)
	if code in [Cue.REFLECT, Cue.COUNTER, Cue.POUNCE]:
		return Color(1.0, 0.65, 0.40)
	return Color(0.89, 0.80, 0.60)
