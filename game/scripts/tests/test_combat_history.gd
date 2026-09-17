extends RefCounted
## Clock/domain checks; the native combat-history rig checks actual pause and
## online-menu processing. Explicit timestamps remain usable by existing tests.


static func run(_t: Node) -> String:
	var memory: RefCounted = preload("res://scripts/combat_memory.gd").new()
	memory.advance(0.25)
	memory.record(memory.elapsed_seconds, 20.0, 100.0, 100.0, "First wound", "phys", false)
	memory.advance(Balance.COMBAT_MEMORY_SECONDS)
	var entries: Array = memory.recent(memory.elapsed_seconds)
	if entries.size() != 1 or not is_equal_approx(float(entries[0]["time"]), 0.25):
		return "the inclusive gameplay-time window lost its oldest wound"
	# Reading never advances time. The returned rows cannot edit live history.
	entries[0]["amount"] = 999.0
	var reread: Array = memory.recent(memory.elapsed_seconds)
	if reread.size() != 1 or float(reread[0]["amount"]) != 20.0:
		return "reading a paused record mutated or aged its wounds"
	memory.record(memory.elapsed_seconds, 80.0, 80.0, 100.0, "Final blow", "magic", true)
	memory.fall(memory.elapsed_seconds, "Clock fixture")
	memory.advance(0.25)
	entries = memory.recent(memory.elapsed_seconds)
	if entries.size() != 1 or String(entries[0]["source"]) != "Final blow":
		return "resumed gameplay did not expire only the wound outside its window"
	var fall: Dictionary = memory.last_defeat
	var fall_hits: Array = fall["hits"]
	if fall_hits.size() != 2 or String(fall_hits[0]["source"]) != "First wound" \
			or not is_equal_approx(float(fall["time"]) - float(fall_hits[0]["time"]), Balance.COMBAT_MEMORY_SECONDS):
		return "later gameplay rewrote the final-blow history or its relative times"
	var before_clear: float = memory.elapsed_seconds
	memory.clear_recent()
	if not memory.recent(memory.elapsed_seconds).is_empty() \
			or memory.elapsed_seconds != before_clear or memory.last_defeat["hits"].size() != 2:
		return "recovery reset the history clock or erased the last fall"
	memory.advance(-1.0)
	if memory.elapsed_seconds != before_clear:
		return "a negative frame rewound the gameplay history clock"
	print("ok: combat history ages with gameplay, preserves inclusive boundaries and isolates fall snapshots")
	return ""
