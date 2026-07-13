extends SceneTree
## COMPILE GATE — run before any test suite. Loads every script and
## fails fast on parse errors. This must stay DEPENDENCY-FREE (no
## class_name references): when game.gd or menus.gd breaks, the test
## suite's own script fails to compile and the engine idles forever —
## the "suite hung for 16 minutes" failure mode. This catches it in
## seconds, printing Godot's actual parse error.

func _init() -> void:
	var bad := 0
	var total := 0
	for path in _gather("res://scripts"):
		total += 1
		var sc = load(path)
		if sc == null or not (sc as GDScript).can_instantiate():
			print("COMPILE FAIL: ", path)
			bad += 1
	if bad == 0:
		print("COMPILE OK (%d scripts)" % total)
	else:
		print("COMPILE GATE: %d broken script(s) — fix before running the suite." % bad)
	quit(1 if bad > 0 else 0)


func _gather(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	for d in dir.get_directories():
		out += _gather(dir_path + "/" + d)
	return out
