extends SceneTree
## COMPILE GATE — run before any test suite. Loads every script and
## fails fast on parse errors. This must stay DEPENDENCY-FREE (no
## class_name references): when game.gd or menus.gd breaks, the test
## suite's own script fails to compile and the engine idles forever —
## the "suite hung for 16 minutes" failure mode. This catches it in
## seconds, printing Godot's actual parse error.
##
## Extra scripts OUTSIDE res://scripts (a shot rig in the project root) can be
## appended as user args: `--script res://check_compile.gd -- res://shot_x.gd`
## (shot.bat does this — a rig with a parse error opens a window that idles
## forever, the same trap).

func _init() -> void:
	var bad := 0
	var total := 0
	var paths := _gather("res://scripts")
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".gd"):
			paths.append(a)
	for path in paths:
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
