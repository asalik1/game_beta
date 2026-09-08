extends RefCounted
## Keeps a tap alive across a physics tick or the last fraction of a cooldown.
## One pending press per slot; no repeat or queued sequence is manufactured.

var pending := {}


func press(slot: String, now: float) -> void:
	if slot in ["a1", "a2", "a3", "ult"]:
		pending[slot] = now + Balance.ABILITY_BUFFER_SECONDS


func has_press(slot: String, now: float) -> bool:
	if not pending.has(slot):
		return false
	if now >= float(pending[slot]):
		pending.erase(slot)
		return false
	return true


func consume(slot: String) -> void:
	pending.erase(slot)


func clear() -> void:
	pending.clear()
