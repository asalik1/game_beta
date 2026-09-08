extends RefCounted
## Cosmetic identity only. Never transport ownership, account data or stats.


static func normalize(cls: String, raw: Variant) -> Dictionary:
	var out := {"skin": "", "pet": ""}
	if not raw is Dictionary:
		return out
	var skin_id: Variant = raw.get("skin", "")
	var pet_id: Variant = raw.get("pet", "")
	if skin_id is String:
		if cls == "warlock" and skin_id == "eldritch_herald":
			skin_id = "arcane_warlock"
		if not Skins.find_skin(cls, skin_id).is_empty():
			out.skin = skin_id
	if pet_id is String and not Skins.find_pet(pet_id).is_empty():
		out.pet = pet_id
	return out


static func from_player(p: Node) -> Dictionary:
	return normalize(String(p.cls), {"skin": p.skin, "pet": p.equipped_pet})


static func character(block: Dictionary) -> Dictionary:
	var out := block.duplicate()
	var cls: Variant = block.get("cls", "warrior")
	if not cls is String or not Classes.CLASSES.has(cls):
		cls = "warrior"
	out.cls = cls
	out.appearance = normalize(cls, block.get("appearance"))
	return out


static func apply_remote(g: Node, pid: int, raw: Variant) -> bool:
	if g == null or pid <= 0:
		return false
	for p in g.players:
		if not is_instance_valid(p) or p.is_queued_for_deletion() \
				or p == g.local_player or p.peer_id != pid:
			continue
		var value := normalize(String(p.cls), raw)
		if p.skin != value.skin:
			p.skin = value.skin
			p.refresh_skin_sprite()
		# Do not invoke unlock/purchase/save flows or refresh the LOCAL follower.
		p.equipped_pet = value.pet
		return true
	return false
