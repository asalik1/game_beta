class_name PvpArena
## THE PROVING GROUNDS — the PvP duel arena world (PvP v1, owner spec 2026-08-01).
##
## A throwaway 3-room chapter the duel controller (pvp.gd) plays out in:
##   room 0  West Gatehouse — the HOST's corner, sealed behind a gate
##   room 1  The Proving Grounds — the arena; its terrain REROLLS every round
##           (host names the terrain; _spawn_scenery/_spawn_patches are seeded
##           by (zone, terrain) alone, so both machines rebuild identically)
##   room 2  East Gatehouse — the GUEST's corner, sealed behind a gate
##
## Kept OUT of CHAPTER_LIST (the ENDGAME_ARENAS pattern): Story.chapter()
## resolves it by id and Story.is_pvp() marks it so flows can branch. Every
## room is type "safe" with no authored packs — the only Enemy that ever
## stands here is each machine's invisible PvP proxy (pvp_proxy.gd).
##
## The "flag:pvp_gates" locks are DELIBERATELY never satisfied by story flow:
## the duel controller opens the gates with open_edge on the fight signal and
## re-seals them with _build_gate on every round reset. The flag itself is
## only flipped locally by the controller so rebuilt rooms stay consistent.

const CHAPTER := {
	"name": "The Proving Grounds",
	"sub": "Two heroes. Three rooms. First to three falls loses.",
	"pvp": true,
	"zones": [
		{
			"name": "West Gatehouse", "terrain": "keep", "type": "safe",
			"coord": [0, 0], "exits": ["E"], "locks": {"E": "flag:pvp_gates"},
			"room_scale": 0.62,
		},
		{
			"name": "The Proving Grounds", "terrain": "keep", "type": "safe",
			"coord": [1, 0],
		},
		{
			"name": "East Gatehouse", "terrain": "keep", "type": "safe",
			"coord": [2, 0], "exits": ["W"], "locks": {"W": "flag:pvp_gates"},
			"room_scale": 0.62,
		},
	],
	"start_quest": "",
	"final_boss": "",
	"start_pos": [1056, 624],  # room 0's cell center — the host's gatehouse
}


## Structural integrity (autotest hook): the duel controller hard-assumes this
## exact 3-room west-arena-east shape, so drift here must fail loudly.
static func selftest() -> String:
	var zones: Array = CHAPTER["zones"]
	if zones.size() != 3:
		return "expected exactly 3 zones, got %d" % zones.size()
	for i in zones.size():
		var z: Dictionary = zones[i]
		if String(z.get("type", "")) != "safe":
			return "zone %d must be type safe (no authored packs)" % i
		if z.has("enemies") or z.has("boss"):
			return "zone %d authors spawns — the proxy is the only enemy here" % i
		if not Terrains.DATA.has(String(z.get("terrain", ""))):
			return "zone %d names unknown terrain %s" % [i, String(z.get("terrain", ""))]
		var want_coord: Array = [i, 0]
		if z.get("coord", []) != want_coord:
			return "zone %d coord drifted (want %s)" % [i, str(want_coord)]
	if String(zones[0].get("locks", {}).get("E", "")) != "flag:pvp_gates" \
			or String(zones[2].get("locks", {}).get("W", "")) != "flag:pvp_gates":
		return "gatehouse locks must both be flag:pvp_gates"
	if not (zones[1].get("locks", {}) as Dictionary).is_empty():
		return "the arena authors no locks (reciprocal exits are implied)"
	for t in Balance.PVP_TERRAINS:
		if not Terrains.DATA.has(String(t)):
			return "PVP_TERRAINS names unknown terrain %s" % String(t)
	return ""
