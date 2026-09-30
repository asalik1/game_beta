extends RefCounted
## Boss walk-strip acceptance (T60). The systems tier calls run() in the quick
## and full suites: source feet-line and upper-body steps for Morwen and Korrag
## south (repaired by the art lane in 83be97f) plus the healthy Vargoth and
## Choirmother references. shot_boss_walk reuses measure()/check() on the real
## Enemy render path and adds a rendered feet-line check. Pure image math; it
## never touches campaign state.

const CASES := [
	["morwen", ""], ["vargoth", "e"], ["korrag", "s"], ["choirmother", "e"],
]
const ALPHA_SOLID := 8 # Same byte threshold as tools/art/verify_art.py.


## The strip the game plays for a case: Art.walk_info(key) when the direction
## is blank, else Art.dir_set(key + "_walk_codex")[direction].
static func strip_path(key: String, direction: String) -> String:
	if direction == "":
		return "res://assets/sprites/%s_walk.png" % key
	return "res://assets/sprites/%s_walk_codex_%s.png" % [key, direction]


static func run(_t: Node) -> String:
	for entry: Array in CASES:
		var key: String = entry[0]
		var path := strip_path(key, entry[1])
		# Load just this strip: Art.dir_set would pull all eight directions.
		if not ResourceLoader.exists(path):
			return "%s: walk strip %s is missing" % [key, path]
		var tex: Texture2D = load(path)
		var error := check(key, measure(tex))
		if error != "":
			return error
	print("ok: boss walk strips hold their feet line and upper body (Morwen, Vargoth E, Korrag S, Choirmother E)")
	return ""


static func measure(tex: Texture2D) -> Array:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var cell := img.get_height()
	var width := img.get_width()
	var out := []
	for f in int(width / cell):
		var sum_x := 0.0
		var sum_y := 0.0
		var count := 0
		var feet := -1
		var upper_x := 0.0
		var upper_y := 0.0
		var upper_count := 0
		# Everything outside the used rect is fully transparent, so scanning only
		# the rect gives identical metrics at a fraction of the per-pixel cost.
		var used := img.get_region(Rect2i(f * cell, 0, cell, cell)).get_used_rect()
		for y in range(used.position.y, used.end.y):
			var row := (y * width + f * cell) * 4 + 3
			for x in range(used.position.x, used.end.x):
				if data[row + x * 4] > ALPHA_SOLID:
					sum_x += x
					sum_y += y
					count += 1
					feet = y
					# Upper half excludes the alternating feet/cape mass that moves
					# the full silhouette's centroid even on Vargoth's stable torso.
					if y < cell / 2:
						upper_x += x
						upper_y += y
						upper_count += 1
		out.append({"cx": sum_x / max(1, count), "cy": sum_y / max(1, count),
			"upper_cx": upper_x / max(1, upper_count), "upper_cy": upper_y / max(1, upper_count),
			"upper_count": upper_count, "feet": feet, "cell": cell, "count": count})
	return out


static func check(label: String, metrics: Array) -> String:
	if metrics.size() < 2:
		return label + ": missing walk cycle"
	var feet_step := 0.0
	var center_step := 0.0
	for i in metrics.size():
		var a: Dictionary = metrics[i]
		var b: Dictionary = metrics[(i + 1) % metrics.size()]
		if int(a.count) == 0 or int(a.upper_count) == 0:
			return label + ": empty walk frame"
		feet_step = maxf(feet_step, absf(float(b.feet) - float(a.feet)) / float(a.cell))
		center_step = maxf(center_step, absf(float(b.upper_cx) - float(a.upper_cx)) / float(a.cell))
	print("WALK METRICS %s feet_step=%.6f center_step=%.6f" % [label, feet_step, center_step])
	if feet_step > Balance.BOSS_WALK_FEET_STEP_MAX:
		return "%s: feet-line step %.6f > %.6f" % [label, feet_step, Balance.BOSS_WALK_FEET_STEP_MAX]
	# Feet alone miss Morwen: her hem is pinned while her upper body hops.
	if center_step > Balance.BOSS_WALK_CENTER_STEP_MAX:
		return "%s: upper-body center step %.6f > %.6f" % [label, center_step, Balance.BOSS_WALK_CENTER_STEP_MAX]
	return ""
