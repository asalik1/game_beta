class_name FangmootCodes
extends RefCounted
## Warband <-> shareable "FM1-" string. PROPOSALS/FANGMOOT.md §11.
## A warband slot is {kind, copies, charm}. The code carries token ids (as
## indices into a stable table), copy counts, charms, order, turn and seed.
## Tampered / malformed codes are rejected (return {}), never crash.

const PREFIX := "FM1-"

static func _ids() -> Array:
	# stable combined id order: tokens then Named
	return FangmootData.TOKENS.keys() + FangmootData.NAMED.keys()

static func encode(band: Array, turn: int, seed: int) -> String:
	var ids := _ids()
	var charms: Array = FangmootData.CHARM_ORDER
	var parts: Array = []
	for slot in band:
		if slot == null:
			continue
		var ki := ids.find(String(slot.get("kind", "")))
		if ki < 0:
			continue
		var ci := charms.find(String(slot.get("charm", "")))
		parts.append("%d,%d,%d" % [ki, int(slot.get("copies", 1)), ci])
	var payload := "%d|%d|%s" % [turn, seed, ";".join(parts)]
	return PREFIX + Marshalls.utf8_to_base64(payload)

static func decode(code: String) -> Dictionary:
	if not code.begins_with(PREFIX):
		return {}
	var b64 := code.substr(PREFIX.length())
	var payload := Marshalls.base64_to_utf8(b64)
	if payload == "":
		return {}
	var head := payload.split("|")
	if head.size() != 3:
		return {}
	if not (head[0].is_valid_int() and head[1].is_valid_int()):
		return {}
	var ids := _ids()
	var charms: Array = FangmootData.CHARM_ORDER
	var band: Array = []
	if head[2] != "":
		for chunk in head[2].split(";"):
			var f := chunk.split(",")
			if f.size() != 3:
				return {}
			if not (f[0].is_valid_int() and f[1].is_valid_int() and f[2].is_valid_int()):
				return {}
			var ki := int(f[0])
			var ci := int(f[2])
			if ki < 0 or ki >= ids.size():
				return {}
			var charm := ""
			if ci >= 0 and ci < charms.size():
				charm = String(charms[ci])
			band.append({"kind": String(ids[ki]), "copies": clampi(int(f[1]), 1, 6), "charm": charm})
	return {"turn": int(head[0]), "seed": int(head[1]), "band": band}
