extends RefCounted
## Read-only exploration queries shared by the field atlas and the live map.
## A route may END at a visible doorway, but cannot pass through unknown rooms.

const TYPE_NAMES := {
	"safe": "Sanctuary", "combat": "Battlefield", "boss": "Boss arena",
	"elite": "Elite encounter", "merchant": "Trading post", "social": "Wayside",
	"resonance": "Resonance shrine", "dead_end": "Hidden recess",
}
const TYPE_GLYPHS := {
	"safe": "⌂", "combat": "⚔", "boss": "☠", "elite": "⚔",
	"merchant": "◈", "social": "♧", "resonance": "✧", "dead_end": "◇",
}
const SAFE := Color(0.62, 0.88, 0.77)
const DANGER := Color(0.96, 0.62, 0.56)
const UNKNOWN := Color(0.66, 0.72, 0.78)


static func known(g: Game, room: int) -> bool:
	if room < 0 or room >= g.rooms.size():
		return false
	if g.charted(room):
		return true
	if not g.door_seen.get(room, false):
		return false
	for dir in g.rooms[room]["exits"]:
		var nb: int = g.neighbor(room, String(dir))
		if nb >= 0 and g.charted(nb):
			return true
	return false


static func room_name(g: Game, room: int) -> String:
	if not known(g, room):
		return "Uncharted"
	if not g.charted(room):
		return "Unexplored boss door" if g.room_type(room) == "boss" else "Unexplored passage"
	return String(g.zones[room]["name"])


static func room_color(g: Game, room: int) -> Color:
	if not g.charted(room):
		return DANGER if g.room_type(room) == "boss" else UNKNOWN
	if g.room_pacified(room):
		return SAFE
	return DANGER if g.room_type(room) in ["boss", "elite"] else UITheme.GOLD_BRIGHT


static func glyph(g: Game, room: int) -> String:
	if not g.charted(room):
		return "☠" if g.room_type(room) == "boss" else "?"
	if g.room_type(room) == "boss" and g.room_pacified(room):
		return "✓"
	return String(TYPE_GLYPHS.get(g.room_type(room), "◇"))


static func route(g: Game, start: int, goal: int, include_locked := false) -> Array[int]:
	var empty: Array[int] = []
	if not known(g, start) or not known(g, goal):
		return empty
	var queue: Array[int] = [start]
	var parents := {start: -1}
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		if at == goal:
			var path: Array[int] = []
			while at >= 0:
				path.push_front(at)
				at = int(parents[at])
			return path
		if not g.charted(at):
			continue
		for dir in ["N", "E", "S", "W"]:
			if not g.rooms[at]["exits"].has(dir):
				continue
			var nb: int = g.neighbor(at, dir)
			if nb < 0 or parents.has(nb) or not known(g, nb):
				continue
			if not include_locked and not g._edge_unlocked(at, nb):
				continue
			parents[nb] = at
			queue.append(nb)
	return empty


static func direction(g: Game, a: int, b: int) -> String:
	for dir in g.rooms[a]["exits"]:
		if g.neighbor(a, String(dir)) == b:
			return String(dir)
	return ""


static func lock_reason(g: Game, a: int, b: int) -> String:
	var info: Dictionary = g.edge_locks.get(g._edge_key(a, b), {})
	var lock := String(info.get("lock", ""))
	match lock:
		"boss": return "Defeat the guardian to open this passage."
		"clear": return "Clear the encounter to open this passage."
	return "Continue the story to open this passage."


static func first_lock(g: Game, path: Array[int]) -> String:
	for k in range(1, path.size()):
		if not g._edge_unlocked(path[k - 1], path[k]):
			return lock_reason(g, path[k - 1], path[k])
	return ""


static func room_enemies(g: Game, room: int) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node in g.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.is_queued_for_deletion():
			continue
		if e.zone_idx == room or (e.zone_idx < 0 and g.room_at_pos(e.global_position) == room):
			out.append(e)
	return out


static func room_chests(g: Game, room: int) -> Array[Chest]:
	var out: Array[Chest] = []
	for node in g.get_tree().get_nodes_in_group("wayfinder_chests"):
		var chest := node as Chest
		if chest != null and not chest.opened and not chest.buried \
				and not chest.is_queued_for_deletion() and chest.is_visible_in_tree() \
				and g.room_at_pos(chest.global_position) == room:
			out.append(chest)
	return out


## Keep teleported pocket arenas out of the mainland extent. Their authored
## coordinates are thousands of cells away; fitting both makes a map disappear.
static func chart_rooms(g: Game) -> Array[int]:
	var out: Array[int] = []
	if g.rooms.is_empty():
		return out
	var queue: Array[int] = [g.cur_room]
	var seen := {g.cur_room: true}
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		out.append(at)
		if not g.charted(at):
			continue
		for dir in g.rooms[at]["exits"]:
			var nb: int = g.neighbor(at, String(dir))
			if nb >= 0 and not seen.has(nb) and known(g, nb):
				seen[nb] = true
				queue.append(nb)
	return out


static func services(g: Game, room: int) -> String:
	if not g.charted(room):
		return "Step through this doorway to chart what lies beyond."
	var z: Dictionary = g.zones[room]
	var lines: Array[String] = []
	if preload("res://scripts/ward_vigil.gd").eligible(g, room):
		lines.append("The old tower ward · optional three-wave defense")
	if not preload("res://scripts/wildlife.gd").site(g, room).is_empty():
		lines.append("Small Mercies · animal sanctuary" if preload("res://scripts/wildlife.gd").site(g, room).id == "home" else "Wildlife · a small life on the road")
	if z.has("merchant") or g.room_type(room) == "merchant":
		lines.append("Merchant · equipment and supplies")
	if g.room_type(room) == "resonance":
		lines.append("Shrine · an offering and a choice")
	if g.room_type(room) == "social":
		lines.append("Wayside · people and chance encounters")
	if z.has("cache"):
		lines.append("Cache claimed" if g.get_flag(g._cache_flag(room), false) else "A cache waits here")
	if g.room_safe(room):
		lines.append("Sanctuary · a place to regroup")
	if lines.is_empty():
		lines.append("A passage through " + String(Terrains.get_terrain(g.terrain_by_zone[room]).get("name", "the wilds")) + ".")
	return "\n".join(lines)


## The next charted step on the chapter's main road. No unseen coordinates or
## boss names escape this query; only rooms already admitted by the fog rules.
static func main_trail(g: Game) -> int:
	var spine: Array = Story.chapter(g.chapter_id).get("spine", [])
	for value in spine:
		var room := int(value)
		if room == g.cur_room or not known(g, room):
			continue
		var boss := String(g.zones[room].get("boss", ""))
		var unfinished: bool = not g.charted(room) or (boss != "" and not g.boss_done.get(boss, false))
		if unfinished and not route(g, g.cur_room, room, true).is_empty():
			return room
	return -1
