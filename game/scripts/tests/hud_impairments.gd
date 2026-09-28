extends RefCounted
## Quick systems tier: real applications and physics clocks, then the actual
## pooled HUD controls. All borrowed state is restored on failure as well.
const EFFECTS := {"frozen": "frozen_time", "rooted": "rooted_time", "chilled": "chill_time"}
const BUFFS := ["berserk_time", "aegis_time", "dr_time", "pact_time",
	"theme_guard_time", "theme_speed_time", "elixir_time", "goldrush_time", "dodge_time"]
## Chips that hold their slot at the head of the row (Hud._active_buffs).
const PERSISTENT := ["ng_tier", "holy", "retri", "grit", "second_wind"]


static func suite(g: Game) -> String:
	var p: Player = g.local_player
	var saved := {}
	var fields: Array = EFFECTS.values() + BUFFS + ["chill_mult", "uniq_cc_mult", "uniq_armor", "dead",
		"grit_stacks", "grit_time"]
	for field in fields:
		saved[field] = p.get(field)
	var paused: bool = g.get_tree().paused
	var peaks: Dictionary = g.hud._buff_peak.duplicate(true)
	p.dead = false
	p.uniq_armor = []
	p.uniq_cc_mult = 0.5
	for field in EFFECTS.values():
		p.set(field, 0.0)
	p.chill_mult = 1.0
	# Nine ordinary buffs alone exceed the eight-slot row. No inherited buff
	# state or previous section's equipment can satisfy the overflow control.
	for field in BUFFS:
		p.set(field, 10.0)
	# One persistent chip on any class: impairments must queue behind it.
	p.grit_stacks = 1
	p.grit_time = 10.0
	g.get_tree().paused = false
	var error: String = await _checks(g, p)
	for field in fields:
		p.set(field, saved[field])
	g.get_tree().paused = paused
	g.hud._update_buffs()
	g.hud._buff_peak = peaks
	if error == "":
		print("ok: HUD impairments (real freeze/root/chill, reduced durations, countdown, refresh, expiry, full-row priority behind persistent chips, own art, casting detail)")
	return error


static func _checks(g: Game, p: Player) -> String:
	var h: Hud = g.hud
	for id in EFFECTS:
		if not _entry(h, id).is_empty():
			return "inactive impairment already has a chip: " + id
		# The chip has no name label, so its art alone must set it apart.
		for other in Hud.BUFF_ICONS:
			if other != id and Hud.BUFF_ICONS[other] == Hud.BUFF_ICONS[id]:
				return "impairment chip %s shares its icon with %s" % [id, other]
	p.apply_freeze(1.6)
	p.apply_root(2.0)
	p.apply_chill(0.6, 2.4)
	var expected := {"frozen": 0.8, "rooted": 1.0, "chilled": 1.2}
	if h._active_buffs().size() <= h.buff_slots.size():
		return "impairment overflow fixture did not fill the row"
	for id in EFFECTS:
		var error := _chip_error(h, p, id)
		if error != "":
			return error
		if not is_equal_approx(float(_entry(h, id).t), float(expected[id])):
			return "impairment chip ignored the actual reduced duration: " + id
	if "can still cast" not in String(_entry(h, "rooted").tip):
		return "Rooted chip does not explain casting is allowed"
	if "40%" not in String(_entry(h, "chilled").tip):
		return "Chilled chip does not show the actual slow amount"
	await g.get_tree().create_timer(0.25).timeout
	for id in EFFECTS:
		var error := _chip_error(h, p, id)
		if error != "":
			return error
		if float(_entry(h, id).t) >= float(expected[id]):
			return "impairment countdown did not advance: " + id
	# Refresh through the same gameplay entry points, including a stronger aura.
	p.apply_freeze(2.0)
	p.apply_root(2.4)
	p.apply_chill(0.4, 2.8)
	expected = {"frozen": 1.0, "rooted": 1.2, "chilled": 1.4}
	for id in EFFECTS:
		if not is_equal_approx(float(_entry(h, id).t), float(expected[id])):
			return "impairment chip did not refresh: " + id
	if "60%" not in String(_entry(h, "chilled").tip):
		return "Chilled detail retained the old slow amount"
	var expired := {}
	var deadline := Time.get_ticks_msec() + 4000
	while expired.size() < EFFECTS.size() and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.05).timeout
		h._update_buffs()
		for id in EFFECTS:
			if float(p.get(EFFECTS[id])) > 0.0:
				var error := _chip_error(h, p, id)
				if error != "":
					return error
				continue
			expired[id] = true
			if not _entry(h, id).is_empty() or h._buff_peak.has(id):
				return "expired impairment retained its chip or drain state: " + id
			for slot in h.buff_slots:
				if slot.border.visible and String(slot.border.get_meta("tip_raw", "")).begins_with(String(id).capitalize() + ":"):
					return "expired impairment is still painted: " + id
	if expired.size() != EFFECTS.size():
		return "impairment physics timers did not expire"
	return ""


static func _entry(h: Hud, id: String) -> Dictionary:
	for entry in h._active_buffs():
		if entry.id == id:
			return entry
	return {}


static func _chip_error(h: Hud, p: Player, id: String) -> String:
	h._update_buffs()
	var active: Array = h._active_buffs()
	var entry := _entry(h, id)
	if entry.is_empty():
		return "active impairment missing from HUD: " + id
	var index: int = active.find(entry)
	if index < 0 or index >= h.buff_slots.size():
		return "ordinary buffs crowded impairment out of the row: " + id
	if _entry(h, "grit").is_empty():
		return "persistent-chip fixture is missing from the row"
	for i in active.size():
		var other: String = String(active[i].id)
		if i < index and other not in PERSISTENT and not EFFECTS.has(other):
			return "ordinary buff %s sits ahead of impairment %s" % [other, id]
		if i > index and other in PERSISTENT:
			return "impairment %s pushed persistent chip %s down the row" % [id, other]
	if not is_equal_approx(float(entry.t), float(p.get(EFFECTS[id]))) or float(entry.t) <= 0.0:
		return "impairment chip has the wrong remaining time: " + id
	var slot: Dictionary = h.buff_slots[index]
	if not slot.border.visible or not slot.icon.visible or slot.icon.texture == null \
			or String(slot.border.get_meta("tip_raw", "")) != String(entry.tip):
		return "impairment chip is not painted with its icon and detail: " + id
	var time_text: String = "%.0f" % ceil(float(entry.t)) if float(entry.t) >= 1.0 else "%.1f" % float(entry.t)
	if not slot.time.visible or slot.time.text != time_text or slot.fill.size.x <= 0.0:
		return "impairment chip countdown or drain is missing: " + id
	return ""
