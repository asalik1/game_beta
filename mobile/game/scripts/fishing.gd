extends RefCounted
## Personal catch-and-release fishing. No inventory, money or world claims:
## guests keep their own records, and another angler never empties a shoal.

const SPECIES := {
	"dace": {"name": "Greyrun Dace", "cell": Vector2i(0, 0), "size": Vector2(14, 31), "fight": 0.85,
		"color": Color(0.52, 0.83, 0.88), "lure": "fly", "water": "clear",
		"note": "Silver where the sun finds it, blue where it does not. Favours clear water and a reed fly."},
	"copperfin": {"name": "Copperfin", "cell": Vector2i(1, 0), "size": Vector2(24, 58), "fight": 1.0,
		"color": Color(0.94, 0.63, 0.37), "lure": "spinner", "water": "clear",
		"note": "A patient fish with an impatient temper. A copper spinner works well in clear water."},
	"eel": {"name": "Glass Eel", "cell": Vector2i(0, 1), "size": Vector2(38, 82), "fight": 1.1,
		"color": Color(0.76, 0.70, 0.95), "lure": "feather", "water": "dark",
		"note": "The river can be seen through its youngest scales. Favours dark marsh water and a moon feather."},
	"koi": {"name": "Crown Koi", "cell": Vector2i(1, 1), "size": Vector2(32, 70), "fight": 1.2,
		"color": Color(0.98, 0.83, 0.46), "lure": "feather", "water": "either",
		"note": "Kings minted coins in its likeness. The fish declined to notice. Rare in every river; try a moon feather."},
}
const ORDER := ["dace", "copperfin", "eel", "koi"]
const LURES := {"fly": "Reed fly", "spinner": "Copper spinner", "feather": "Moon feather"}

var rng := RandomNumberGenerator.new()
var state := "ready"
var species := "dace"
var age := 0.0
var bite_at := 0.0
var tension := 0.0
var progress := 0.0
var fight_time := 0.0
var phase_offset := 0.0
var clean_hook := false
var peak_tension := 0.0
var length_cm := 0.0
var claimed := false
var result_text := ""


static func texture(id: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/fishing_fish_atlas.png")
	var cell: Vector2i = SPECIES.get(id, SPECIES.dace).cell
	var half := atlas.atlas.get_size() * 0.5
	atlas.region = Rect2(Vector2(cell) * half, half)
	atlas.filter_clip = true
	return atlas


static func water_at(g: Game, zi: int) -> String:
	return "dark" if String(g.terrain_by_zone[zi]) in ["marsh", "bog"] else "clear"


static func weights(water: String, lure: String) -> Array[float]:
	var out: Array[float] = []
	for i in ORDER.size():
		var fish: Dictionary = SPECIES[ORDER[i]]
		var w: float = Balance.FISH_WEIGHTS[i]
		if fish.lure == lure:
			w *= Balance.FISH_LURE_WEIGHT
		if fish.water == water:
			w *= Balance.FISH_WATER_WEIGHT
		out.append(w)
	return out


func cast(water: String, lure: String) -> bool:
	if state in ["waiting", "bite", "reeling"] or not LURES.has(lure):
		return false
	var table := weights(water, lure)
	var total := 0.0
	for w in table:
		total += w
	var roll := rng.randf() * total
	species = ORDER[-1]
	for i in table.size():
		roll -= table[i]
		if roll <= 0.0:
			species = ORDER[i]
			break
	state = "waiting"
	age = 0.0
	bite_at = rng.randf_range(Balance.FISH_WAIT.x, Balance.FISH_WAIT.y)
	phase_offset = rng.randf_range(0.0, Balance.FISH_CALM * Balance.FISH_OPENING_PHASE_FRACTION)
	tension = Balance.FISH_START_TENSION
	progress = Balance.FISH_START_PROGRESS
	fight_time = 0.0
	clean_hook = false
	peak_tension = tension
	length_cm = 0.0
	claimed = false
	result_text = ""
	return true


func hook() -> void:
	if state == "waiting":
		_escape("Too soon. Let the float dip before you strike.")
	elif state == "bite":
		clean_hook = age <= Balance.FISH_CLEAN_HOOK
		state = "reeling"
		age = 0.0


func surge() -> bool:
	return fmod(fight_time + phase_offset, Balance.FISH_CALM + Balance.FISH_SURGE) >= Balance.FISH_CALM


func warning() -> bool:
	var phase := fmod(fight_time + phase_offset, Balance.FISH_CALM + Balance.FISH_SURGE)
	return phase >= Balance.FISH_CALM - Balance.FISH_WARNING and phase < Balance.FISH_CALM


func step(delta: float, held: bool) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	# Bound hitches and integrate small steps: low-FPS/mobile cannot jump
	# across the whole warning or lose a line from one stalled frame.
	var remaining := minf(delta, Balance.FISH_MAX_DELTA)
	while remaining > 0.00001:
		var dt := minf(remaining, Balance.FISH_STEP)
		_tick(dt, held)
		remaining -= dt


func _tick(dt: float, held: bool) -> void:
	age += dt
	match state:
		"waiting":
			if age >= bite_at:
				state = "bite"
				age = 0.0
		"bite":
			if age >= Balance.FISH_BITE_WINDOW:
				_escape("The float rises. This one slipped away.")
		"reeling":
			fight_time += dt
			var pulling := surge()
			var difficulty: float = SPECIES[species].fight
			if held:
				tension += dt * (Balance.FISH_STRAIN_SURGE if pulling else Balance.FISH_STRAIN_CALM) * difficulty
				progress += dt * (Balance.FISH_GAIN_SURGE if pulling else Balance.FISH_GAIN_CALM) / difficulty
			else:
				tension -= dt * Balance.FISH_RELAX
				progress -= dt * Balance.FISH_SLACK
			peak_tension = maxf(peak_tension, tension)
			tension = clampf(tension, 0.0, 1.0)
			progress = clampf(progress, 0.0, 1.0)
			if tension >= 1.0:
				_escape("The line snapped. Release while the fish surges.")
			elif progress >= 1.0:
				state = "landed"
				var bounds: Vector2 = SPECIES[species].size
				var quality := rng.randf_range(0.0, 1.0)
				if clean_hook and peak_tension < Balance.FISH_CLEAN_TENSION:
					quality = maxf(quality, Balance.FISH_CLEAN_SIZE_FLOOR)
				length_cm = snappedf(lerpf(bounds.x, bounds.y, quality), 0.1)
			elif fight_time >= Balance.FISH_FIGHT_LIMIT:
				_escape("The fish found the reeds. Keep reeling between surges.")


func _escape(message: String) -> void:
	state = "escaped"
	result_text = message


## A landed fish can be recorded only once, even if two input paths fire.
func claim(p: Player) -> Dictionary:
	if state != "landed" or claimed:
		return {}
	claimed = true
	var old: Dictionary = p.fishing_book.get(species, {})
	var first := old.is_empty()
	var record := length_cm > float(old.get("best", 0.0))
	p.fishing_book[species] = {"count": mini(1000000, int(old.get("count", 0)) + 1),
		"best": maxf(length_cm, float(old.get("best", 0.0)))}
	return {"first": first, "record": record, "species": species, "length": length_cm}


static func clean_book(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for id in ORDER:
		var row: Variant = raw.get(id)
		if not row is Dictionary:
			continue
		var count: Variant = row.get("count", 0)
		var best: Variant = row.get("best", 0.0)
		if not (count is int or count is float) or not (best is int or best is float):
			continue
		if not is_finite(float(count)) or not is_finite(float(best)) or float(count) < 1.0:
			continue
		var bounds: Vector2 = SPECIES[id].size
		out[id] = {"count": int(clampf(float(count), 1, 1000000)), "best": snappedf(clampf(float(best), bounds.x, bounds.y), 0.1)}
	return out


static func blocked(g: Game, spot: Node2D, zi: int) -> String:
	var p: Player = g.local_player
	if not is_instance_valid(spot) or p == null or p.dead or p.downed or p.ghost or g.state != g.ST_PLAYING:
		return "The river will wait until you return."
	if g.cur_room != zi or p.global_position.distance_to(spot.global_position) > Balance.INTERACT_RANGE:
		return "Return to the fishing nook to cast."
	for node in g.get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and not node.dying and not node.is_queued_for_deletion() \
				and node.global_position.distance_to(p.global_position) < Balance.FISH_SAFE_RADIUS:
			return "There are enemies too close. Find a quiet moment first."
	return ""
