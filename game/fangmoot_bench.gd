extends SceneTree
## Headless entry for the Fangmoot balance bench (fangmoot_bench.bat).
## Usage: fangmoot_bench.bat [--n=2000] [--table=silver] [--seed=12345]
## Self-contained on FangmootData/sim/moot/bot — no game boot needed.

func _initialize() -> void:
	var n := 2000
	var table := "silver"
	var seed := 12345
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--table="):
			table = a.substr(8)
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
	var t0 := Time.get_ticks_msec()
	print(FangmootBench.run(n, seed, table))
	print("\nbench wall: %.1fs  (%d moots)" % [(Time.get_ticks_msec() - t0) / 1000.0, n])
	quit(0)
