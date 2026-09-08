extends RefCounted
## Personal discoveries travel in the character save; cosmetics belong to the account.
const SITES := [
	{"id": "spore_pup", "chapter": "ch1", "room": "The Hollow Oak", "hint": "Listen beneath the hollow oak in the Darkwood.", "text": "The little shambler has tangled itself in a root snare. It stops shaking when you kneel."},
	{"id": "hearth_hopper", "chapter": "ch1", "room": "The Drowned Chapel", "hint": "A small voice calls from the drowned chapel.", "text": "A frog is wedged beneath a rusted fish trap. The water keeps rising. You lift the iron gently."},
	{"id": "cinder_bat", "chapter": "ch1", "room": "The Collapsed Tower", "hint": "Search the fallen watchtower beyond the marsh.", "text": "The bat's wing is caught in old signal wire. You unwind sixty years of rust, one turn at a time."},
	{"id": "ash_crow", "chapter": "ch2", "room": "The Cold Waystation", "hint": "An abandoned waystation on the Ash Road holds a stranded traveller.", "text": "A crow has wound its foot in a courier's broken cord. It watches your hands, then offers you the knot."},
	{"id": "glimmerwing", "chapter": "ch2", "room": "The Drowned Race", "hint": "Look beside the drowned millrace on the Ash Road.", "text": "A dragonfly beats against an overturned glass jar. You turn the mouth toward the open air."},
	{"id": "pale_flutter", "chapter": "ch2", "room": "The Unbroken Font", "hint": "A quiet-winged creature waits near the unbroken font.", "text": "A pale moth has settled into a dry font and cannot climb its smooth lip. You lay a twig across the stone."},
]
const HOMES := ["Stillwater Reach", "Accord Commons"]


static func rescued(g: Game, id: String) -> bool:
	return g.has_local_player() and id in g.player.rescued_pets


## Only authored rescue ids, once each, in stable sanctuary order.
static func clean_rescues(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for entry in SITES:
			if String(entry.id) in raw:
				out.append(String(entry.id))
	return out


## Migration reads a saved HOME world, never the host's live flags or the
## account cosmetic ledger. Buying a pet is not rescuing it on this hero.
static func legacy_rescues(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Dictionary:
		for entry in SITES:
			var value = raw.get("sq_kept_rescue_" + String(entry.id), false)
			if value is bool and value:
				out.append(String(entry.id))
	return out


## Keep legacy story readers truthful without allowing host flags to masquerade
## as personal rescues. Direct assignment avoids quest/broadcast side effects.
static func sync_flags(g: Game) -> void:
	for entry in SITES:
		var key := "sq_kept_rescue_" + String(entry.id)
		if rescued(g, String(entry.id)):
			g.flags[key] = true
		else:
			g.flags.erase(key)


static func count(g: Game) -> int:
	var total := 0
	for site in SITES:
		if rescued(g, String(site.id)):
			total += 1
	return total


static func site(g: Game, zi: int) -> Dictionary:
	if g.pvp_active or g.endgame_active or zi < 0 or zi >= g.zones.size():
		return {}
	var room_name := String(g.zones[zi].get("name", ""))
	if HOMES.has(room_name):
		return {"id": "home"}
	for entry in SITES:
		if String(entry.chapter) == g.chapter_id and String(entry.room) == room_name:
			return entry
	return {}


static func point(g: Game, zi: int) -> Vector2:
	var center: Vector2 = g.room_center(zi)
	var bounds: Rect2 = g.play_rect(zi).grow(-180)
	for delta in [Vector2(300, 190), Vector2(-300, 190), Vector2(300, -190), Vector2(-300, -190), Vector2(0, 260)]:
		var p: Vector2 = (center + delta).clamp(bounds.position, bounds.end)
		if g.rivers.has(zi) and (g.rivers[zi].rect as Rect2).grow(150).has_point(p):
			continue
		var clear := true
		for h in g.hazards:
			if int(h.zone) == zi and p.distance_to(h.pos) < float(h.radius) + 150.0:
				clear = false
		for npc in g.zones[zi].get("npcs", []):
			if p.distance_to(g.room_pos(zi, float(npc.x), float(npc.y))) < 180:
				clear = false
		for landmark in g.zones[zi].get("landmarks", []):
			if p.distance_to(g.room_pos(zi, float(landmark.x), float(landmark.y))) < float(landmark.get("clearance", 180)) + 100:
				clear = false
		if clear:
			return p
	return center + Vector2(0, 260)


static func claim(g: Game, id: String) -> bool:
	if not g.has_local_player() or rescued(g, id) or clean_rescues([id]).is_empty():
		return false
	g.player.rescued_pets.append(id)  # reserve before flags, grants or autosave
	g.set_flag("sq_kept_rescue_" + id)
	g.grant_cosmetic("pet", "all", id)
	if g.player.equipped_pet == "":
		g.player.set_pet(id)
	g.autosave()
	return true
