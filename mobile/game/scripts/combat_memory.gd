extends RefCounted
## A bounded, character-local account of landed damage. No enemy references are
## retained: the attacker may have despawned by the time the player reads it.

var hits: Array[Dictionary] = []
var last_defeat := {}


func record(now: float, amount: float, hp_before: float, max_hp: float,
		source: String, damage_type: String, heavy: bool) -> void:
	_prune(now)
	var lost := minf(maxf(amount, 0.0), maxf(hp_before, 0.0))
	if lost <= 0.0:
		return
	hits.append({"time": now, "amount": lost, "source": source,
		"type": damage_type, "heavy": heavy, "hp": maxf(0.0, hp_before - lost),
		"max_hp": max_hp})
	while hits.size() > Balance.COMBAT_MEMORY_MAX_HITS:
		hits.pop_front()


func _prune(now: float) -> void:
	while not hits.is_empty() and now - float(hits[0]["time"]) > Balance.COMBAT_MEMORY_SECONDS:
		hits.pop_front()


func recent(now: float) -> Array[Dictionary]:
	_prune(now)
	return hits.duplicate(true)


func fall(now: float, place: String) -> void:
	last_defeat = {"time": now, "place": place, "hits": recent(now)}


func clear_recent() -> void:
	hits.clear()


static func source_name(attacker: Node, damage_type: String) -> String:
	if is_instance_valid(attacker):
		if attacker is Enemy:
			return attacker.display_name
		if attacker is Player:
			return attacker.char_name if attacker.char_name != "" else Classes.CLASSES[attacker.cls]["name"]
	return "Magic or environmental damage" if damage_type == "magic" else "Environmental damage"
