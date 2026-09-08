extends RefCounted
## A committed boss windup. Only the host may resolve or break it; mirrors
## interpolate its clock until a reliable state update arrives.

const MOVES := {
	"morwen": {"name": "Blight Rain", "action": "rain"},
	"vargoth": {"name": "Blade Storm", "action": "blade"},
	"choirmother": {"name": "Hymn of Hunger", "action": "cast"},
	"vess": {"name": "The Silence", "action": "wail"},
	"sleepkeeper": {"name": "Frost Hymnal", "action": "hymn"},
	"gardener": {"name": "Vine Lash", "action": "lash"},
}

var phase := ""
var kind := ""
var remaining := 0.0
var duration := 0.0
var goal := 0.0
var pressure := 0.0
var exposed := 0.0
var recovery := 0.0


func start(boss_kind: String, max_hp: float) -> bool:
	if phase != "" or not MOVES.has(boss_kind) or not is_finite(max_hp) or max_hp <= 0.0:
		return false
	kind = boss_kind
	phase = "windup"
	duration = Balance.BOSS_BREAK_WINDUP_EARLY if kind == "morwen" else Balance.BOSS_BREAK_WINDUP
	remaining = duration
	goal = maxf(1.0, max_hp * Balance.BOSS_BREAK_HP_FRACTION)
	pressure = 0.0
	return true


func hit(applied_damage: float, close: bool, periodic: bool) -> bool:
	if phase != "windup" or remaining <= 0.0 or not is_finite(applied_damage) or applied_damage <= 0.0:
		return false
	var weight: float = Balance.BOSS_BREAK_DOT_WEIGHT if periodic else (Balance.BOSS_BREAK_CLOSE_WEIGHT if close else 1.0)
	pressure = minf(goal, pressure + applied_damage * weight)
	if pressure < goal and not is_equal_approx(pressure, goal):
		return false
	pressure = goal
	phase = "broken"
	remaining = 0.0
	exposed = Balance.BOSS_BREAK_EXPOSED
	recovery = Balance.BOSS_BREAK_RECOVERY
	return true


func step(delta: float, authority := true) -> String:
	if not is_finite(delta) or delta <= 0.0:
		return ""
	if phase == "windup":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0 and authority:
			cancel()
			return "release"
	elif phase == "broken":
		recovery = maxf(0.0, recovery - delta)
		exposed = maxf(0.0, exposed - delta)
		if exposed <= 0.0 and authority:
			cancel()
			return "settled"
	return ""


func damage_multiplier() -> float:
	return Balance.BOSS_BREAK_DAMAGE_MULT if exposed > 0.0 else 1.0


func cancel() -> void:
	phase = ""
	kind = ""
	remaining = 0.0
	duration = 0.0
	goal = 0.0
	pressure = 0.0
	exposed = 0.0
	recovery = 0.0


func snapshot() -> Dictionary:
	return {"phase": phase, "kind": kind, "remaining": remaining, "duration": duration,
		"goal": goal, "pressure": pressure, "exposed": exposed, "recovery": recovery}


func apply_snapshot(data: Dictionary) -> bool:
	var next := String(data.get("phase", ""))
	if not next in ["", "windup", "broken"]:
		return false
	if next == "":
		cancel()
		return true
	if not MOVES.has(String(data.get("kind", ""))):
		return false
	for key in ["remaining", "duration", "goal", "pressure", "exposed", "recovery"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	if float(data.goal) < 1.0 or float(data.duration) <= 0.0 \
			or float(data.duration) > Balance.BOSS_BREAK_WINDUP_EARLY \
			or float(data.remaining) > float(data.duration) or float(data.pressure) > float(data.goal) \
			or float(data.exposed) > Balance.BOSS_BREAK_EXPOSED or float(data.recovery) > Balance.BOSS_BREAK_RECOVERY:
		return false
	for key in data:
		if key in ["phase", "kind", "remaining", "duration", "goal", "pressure", "exposed", "recovery"]:
			set(key, data[key])
	return true
