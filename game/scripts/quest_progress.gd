extends RefCounted
## The host owns quest work; guests receive a bounded display-only snapshot.
const History := preload("res://scripts/character_history.gd")


static func limits() -> Dictionary:
	Story.load_content()
	var result := {}
	for quest in Story.ALL_SIDE_QUESTS.values():
		for step in quest.get("steps", []):
			if String(step.get("kind", "")) != "kill":
				continue
			var key := String(step.get("flag", ""))
			if key == "" or key.length() > Balance.NET_MAX_FLAG_LEN or History.is_local(key):
				continue
			var target: int = maxi(1, int(step.get("count", 1)))
			if result.has(key) and int(result[key]) != target:
				return {}  # inconsistent authored bounds must not authorize wire data
			result[key] = target
	return result


static func key_ok(raw: Variant) -> bool:
	if not raw is String or raw.length() > Balance.NET_MAX_QUEST_LEN:
		return false
	Story.load_content()
	return raw == "" or Story.ALL_QUESTS.has(raw)


static func project_key(raw: Variant) -> String:
	return raw if key_ok(raw) else ""


static func project(raw: Dictionary) -> Dictionary:
	var allowed := limits()
	var result := {}
	for key in allowed:
		if not raw.has(key):
			continue
		var value: Variant = raw[key]
		var target: int = allowed[key]
		if value is int:
			result[key] = clampi(value, 0, target)
		elif value is float and is_finite(value) and value == floorf(value):
			# JSON saves restore integers as floats. Clamp BEFORE converting so
			# large legacy values cannot overflow; wire values below stay strict.
			result[key] = int(clampf(value, 0.0, float(target)))
		else:
			result[key] = 0
	return result


## Null means invalid; an empty Dictionary is a valid authoritative reset.
static func clean(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var allowed := limits()
	if raw.size() > allowed.size():
		return null
	var result := {}
	for key in raw:
		if not key is String or key == "" or key.length() > Balance.NET_MAX_FLAG_LEN \
				or not allowed.has(key):
			return null
		var value: Variant = raw[key]
		if not value is int or value < 0 or value > int(allowed[key]):
			return null
		result[key] = value
	return result


static func packet(g: Game) -> Dictionary:
	return {"chapter": g.chapter_id, "wander_seed": g.wander_seed,
		"quest_kills": project(g.quest_kills), "quest_key": project_key(g.quest_key)}


static func context_ok(g: Game, raw: Dictionary) -> bool:
	return raw.get("chapter") is String and raw.get("wander_seed") is int \
		and raw.chapter == g.chapter_id and raw.wander_seed == g.wander_seed


static func read(raw: Dictionary) -> Variant:
	var counts: Variant = clean(raw.get("quest_kills"))
	if counts == null or not key_ok(raw.get("quest_key")):
		return null
	return {"quest_kills": counts, "quest_key": raw.quest_key}
