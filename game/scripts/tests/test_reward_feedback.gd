extends RefCounted


static func run(t: Node) -> String:
	var g: Game = t.game
	var h := g.hud
	var queue := h._ann_queue.duplicate(true)
	var active := h._ann_active
	var motion := h._ann_tween
	var lines := h._log_lines.duplicate()
	var started := g.play_started
	var dialogue := h.dialogue_active
	var old_xp := g.player.xp
	var run_xp := g.run_xp
	var capped := g.xp_capped_noted
	h._ann_queue = []
	h._ann_active = null
	h._ann_tween = null
	h._log_lines = []
	g.play_started = false
	h.dialogue_active = true
	var error := _checks(g)
	for row in h._log_lines:
		if is_instance_valid(row):
			var tw: Tween = row.get_meta("tween", null)
			if tw != null and tw.is_valid():
				tw.kill()
			row.free()
	h._log_lines = lines
	h._ann_queue = queue
	h._ann_active = active
	h._ann_tween = motion
	g.play_started = started
	h.dialogue_active = dialogue
	g.player.xp = old_xp
	g.run_xp = run_xp
	g.xp_capped_noted = capped
	if error == "":
		print("ok: achievement/quest queue sharing, earned-notice overflow, overlay log clocks, fixed-width feed and silent zero/negative XP")
	return error


static func _checks(g: Game) -> String:
	var h := g.hud
	h.achievement_toast("First Light", "A long description that must remain in the same reading position as the quest it completes.")
	h.achievement_toast("First Light", "A long description that must remain in the same reading position as the quest it completes.")
	if h._ann_queue.size() != 1 or h._ann_queue[0].kind != "achievement":
		return "achievement bypassed the queue or duplicated its pending notice"
	for i in 8:
		h.announce("A roadside discovery with deliberately long explanatory words that must fit its fixed feed column %d" % i, Color.WHITE)
	if h._ann_queue.size() != h.ANN_QUEUE_MAX:
		return "reward notice queue became unbounded"
	var kept := false
	for notice in h._ann_queue:
		kept = kept or String(notice.kind) == "achievement"
	if not kept:
		return "incidental notices discarded the earned achievement"
	h._tick_event_log()
	for row in h._log_lines:
		var tw: Tween = row.get_meta("tween")
		var label: Label = row.get_meta("label")
		if row.visible or tw.is_running():
			return "event feed stayed live under dialogue"
		if label.size.x > 400.0 or not label.clip_text:
			return "long event text escaped the fixed feed column"
	var amount_before := g.player.xp
	var feed_before := h._log_lines.size()
	g.player.gain_xp(0)
	g.player.gain_xp(-5)
	if g.player.xp != amount_before or h._log_lines.size() != feed_before:
		return "nonpositive XP changed progress or produced a reward popup"
	return ""
