extends RefCounted
## Focused native UI probe. Progression is lent; allocation uses real GUI input.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const PLAYER_FIELDS := ["level", "xp", "skill_points", "unspent_attr", "attr_points", "tree_points",
	"talent_loadouts", "active_talent_loadout", "hp", "mp"]
const HUD_FIELDS := ["_dossier_detail_state", "_avatar_level_shown", "_last_level", "_xp_shown"]
const EXPECTED := ["attribute_only/readiness", "attribute_only/tooltip"]
var r: Node
var g: Game
var p: Player
var h: Hud
var reference := {}
var snapshots: Array[Dictionary] = []


static func run(rig: Node) -> String:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	probe.h = rig.game.hud
	var saved_player: Dictionary = rig._stash(probe.p, PLAYER_FIELDS)
	var saved_hud: Dictionary = rig._stash(probe.h, HUD_FIELDS)
	var saved_menu: Dictionary = rig._stash(probe.g.menus, ["_stat_flash"])
	var saved_visuals := {
		"xp_fill": rig._stash(probe.h.xp_fill, ["modulate"]),
		"stats_label": rig._stash(probe.h.stats_label, ["pivot_offset", "scale", "modulate"]),
		"avatar_level_badge": rig._stash(probe.h.avatar_level_badge, ["scale"])}
	var derived := {"max_hp": probe.p.max_hp, "max_mp": probe.p.max_mp, "atk": probe.p.atk, "speed": probe.p.speed}
	var flags: Dictionary = probe.g.flags.duplicate(true)
	var failures_before: int = rig.failures
	var findings_before: int = rig.findings.size()
	var error: String = await probe._exercise()
	await rig._close_overlay()
	# Also cover an early return after lending the level. Let the real 0.45s
	# avatar, 0.55s XP and 0.7s identity tweens finish before restoring nodes.
	await rig.sim_wait(0.9)
	probe._check("cleanup_flourish_finished", probe._flourish_idle())
	rig._restore(probe.p, saved_player)
	probe.p.recalc() # rebuild derived stats from the restored progression.
	probe.p.hp = float(saved_player.hp)
	probe.p.mp = float(saved_player.mp)
	rig._restore(probe.g.menus, saved_menu)
	# Regenerate the rendered baseline, then restore its exact memoized key.
	probe.h._dossier_detail_state = []
	probe.h.update_stats(probe.p)
	rig._restore(probe.h, saved_hud)
	for field in saved_visuals: rig._restore(probe.h.get(field), saved_visuals[field])
	await rig.frames(3)
	await RenderingServer.frame_post_draw
	var restored := true
	for key in PLAYER_FIELDS:
		if key in ["hp", "mp"]: continue # natural regeneration can advance after return.
		restored = restored and probe.p.get(key) == saved_player[key]
	rig._check("attribute_readiness/restored_progression", restored and probe.g.flags == flags,
		{"scope": "lent pools/allocations/loadouts and level restored; derived stats recalculated; no story flags changed"})
	var derived_match := true
	for key in derived: derived_match = derived_match and is_equal_approx(float(probe.p.get(key)), float(derived[key]))
	rig._check("attribute_readiness/restored_derived", derived_match, derived)
	rig._check("attribute_readiness/restored_cache", probe.h._dossier_detail_state == saved_hud._dossier_detail_state
		and probe.h._avatar_level_shown == int(saved_hud._avatar_level_shown)
		and probe.h._last_level == int(saved_hud._last_level)
		and is_equal_approx(probe.h._xp_shown, float(saved_hud._xp_shown))
		and probe.g.menus._stat_flash == saved_menu._stat_flash,
		{"before": saved_hud, "after": probe.h._dossier_detail_state,
		"last_level": probe.h._last_level, "xp_shown": probe.h._xp_shown})
	var visuals_match := true
	for field in saved_visuals:
		for key in saved_visuals[field]:
			visuals_match = visuals_match and probe.h.get(field).get(key) == saved_visuals[field][key]
	var xp_width: float = float(probe.h.xp_fill.get_meta("full_w")) * clampf(float(saved_hud._xp_shown), 0.0, 1.0)
	rig._check("attribute_readiness/restored_flourish_nodes", visuals_match
		and is_equal_approx(probe.h.xp_fill.size.x, xp_width),
		{"expected_xp_width": xp_width, "actual_xp_width": probe.h.xp_fill.size.x,
		"scope": "post-draw; original pivot/scale/modulation restored with no old tween left running"})
	var actual: Array[String] = []
	for i in range(findings_before, rig.findings.size()): actual.append(String(rig.findings[i].finding))
	var expected: Array[String] = []
	if rig.baseline:
		for id in EXPECTED: expected.append("attribute_readiness/" + id)
	rig._check("attribute_readiness/baseline_exact", actual == expected,
		{"expected": expected, "actual": actual})
	if not probe.snapshots.is_empty():
		rig.views[-1]["attribute_readiness_sequence"] = probe.snapshots
	if error != "": return error
	return "" if rig.failures == failures_before else "Attribute-readiness probe failed"


func _exercise() -> String:
	if not g.no_saves or g.net_online() or g.dev_god or p.dead or g.chapter_id != "ch1":
		return "Requires fresh isolated ch1 solo no-save UI fixture"
	if p.level != 1 or p.xp != 0 or p.skill_points != 1 or p.unspent_attr != 0 \
			or not p.tree_points.is_empty() or g.get_flag("cap_q_talent_on", false):
		return "Unexpected fresh progression or allocation side quest; do not overwrite newer character state"
	_check("fresh_xp_display", h._last_level == p.level and is_zero_approx(h._xp_shown),
		{"last_level": h._last_level, "xp_shown": h._xp_shown, "scope": "fresh XP0 fixture is already settled; restored easing value should remain stable"})
	for field in r.UTILITIES:
		var control: Control = h.get(field)
		reference[field] = control.get_global_rect()
	await _hud_state("01_talent_only", false)
	# One legal level-up-equivalent state, explicitly lent rather than earned.
	# Budget: birth talent1 + level talent1, and level attribute1. No XP grant,
	# achievement, world reward, side quest, potion or gear mutation is performed.
	p.level = 2
	p.xp = 0
	p.skill_points = 2
	p.unspent_attr = 1
	p.recalc()
	await r.sim_wait(1.0)
	_check("lent_level_flourish_finished", _flourish_idle(),
		{"scope": "normal level-up presentation allowed to finish; no tween suppression"})
	_check("lent_budget", p.talent_point_budget() == 2 and p.unspent_attr == 1
		and p.tree_points.is_empty(), _state())
	if not r.baseline:
		# Change only the lent unspent pool, then return it. Real allocation also
		# changes Combat Rating, which could conceal an incomplete detail cache key.
		var rating := p.combat_rating()
		p.unspent_attr = 0
		await r.frames(3)
		_check("attribute_only_cache_change", p.combat_rating() == rating
			and String(h.avatar_root.get_meta("tip", "")).contains("0 attribute points"), _state())
		p.unspent_attr = 1
		await r.frames(3)
		_check("attribute_only_cache_return", p.combat_rating() == rating
			and String(h.avatar_root.get_meta("tip", "")).contains("1 attribute point available"), _state())
	await _hud_state("02_both_pools", false)
	if not await _open_skills(): return "Skills control did not open"
	var cell: Dictionary = Skills.TREES[p.cls][0][0]
	for index in 2:
		var talent := _button(String(cell.name) + "    ", true)
		var before := _state()
		if not await _click(talent, "talent_%d" % index): return "Live legal talent button unavailable"
		_check("talent_exact_%d" % index, p.skill_points == int(before.skill_points) - 1
			and p.unspent_attr == int(before.unspent_attr) and p.attr_points == before.attr_points
			and int(p.tree_points.get(String(cell.id), 0)) == index + 1, _state())
	await r._menu_escape()
	_check("talent_menu_closed", not g.menus.is_open() and not r.get_tree().paused)
	await _hud_state("03_attribute_only", true)
	await _portrait()
	if not await _open_skills(): return "Skills could not reopen for remaining attribute"
	var tab := _button("ATTRIBUTES", false)
	if not await _click(tab, "attributes_tab"): return "Attributes tab unavailable"
	var primary := String(Classes.CLASSES[p.cls].primary)
	var plus := _attribute_button(primary)
	if not is_instance_valid(plus): return "Primary attribute +1 is not unique"
	await _show(plus)
	_check("allocator_enabled", not plus.disabled and p.unspent_attr == 1, _state())
	await _capture("05_attribute_allocator", {"primary": primary, "button": r._rect(plus.get_global_rect())})
	var before := _state()
	if not await _click(plus, "attribute_plus_one"): return "Attribute +1 click failed"
	var expected_attr: Dictionary = before.attr_points.duplicate(true)
	expected_attr[primary] = int(expected_attr.get(primary, 0)) + 1
	_check("attribute_exact", p.unspent_attr == 0 and p.attr_points == expected_attr
		and p.skill_points == int(before.skill_points) and p.tree_points == before.tree_points, _state())
	# The rebuilt disabled control must not spend again from an exhausted pool.
	var disabled := _attribute_button(primary)
	if not is_instance_valid(disabled): return "Rebuilt attribute +1 missing"
	await _show(disabled)
	_check("allocator_disabled", disabled.disabled)
	var exhausted := _state()
	await r._tap(disabled.get_global_rect().get_center())
	_check("empty_pool_no_double_spend", _state() == exhausted, _state())
	await r._menu_escape()
	_check("attribute_menu_closed", not g.menus.is_open() and not r.get_tree().paused)
	await _hud_state("06_all_spent", false)
	return ""


func _flourish_idle() -> bool:
	return h.xp_fill.modulate == Color.WHITE and h.stats_label.modulate == Color.WHITE \
		and h.stats_label.scale == Vector2.ONE and h.avatar_level_badge.scale == Vector2.ONE


func _state() -> Dictionary:
	return {"level": p.level, "xp": p.xp, "skill_points": p.skill_points, "unspent_attr": p.unspent_attr,
		"tree_points": p.tree_points.duplicate(true), "attr_points": p.attr_points.duplicate(true),
		"talent_loadouts": p.talent_loadouts.duplicate(true), "active_talent_loadout": p.active_talent_loadout, "gold": p.gold,
		"badge_visible": h.skills_badge.is_visible_in_tree(), "badge_text": h.skills_badge_num.text,
		"tooltip": h.skills_btn.tooltip_text, "detail": String(h.avatar_root.get_meta("tip", ""))}


func _check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	r._check("attribute_readiness/" + id, ok, detail)


func _anticipated(id: String, ok: bool, detail: Dictionary) -> void:
	# This is the only use of the rig's baseline observation mechanism.
	# Existing geometry, menu access, text and allocation always remain strict.
	r._probe("attribute_readiness/" + id, ok, detail)


func _hud_state(id: String, attribute_only: bool) -> void:
	await r.frames(5)
	await RenderingServer.frame_post_draw
	var state := _state()
	var positive := p.skill_points + p.unspent_attr > 0
	if attribute_only:
		_anticipated("attribute_only/readiness", h.skills_badge.is_visible_in_tree(), state)
		_anticipated("attribute_only/tooltip", h.skills_btn.tooltip_text != "Skills · 0 points available"
			and h.skills_btn.tooltip_text.to_lower().contains("attribute")
			and h.skills_btn.tooltip_text.contains(str(p.unspent_attr)), state)
	else:
		_check(id + "/readiness", h.skills_badge.is_visible_in_tree() == positive, state)
	# Strict runs count all spendable points. Only the historical mixed-pool
	# baseline retains its old talent-only number, before the reproduced miss.
	if h.skills_badge.is_visible_in_tree():
		var count := h.skills_badge_num.text
		var expected: int = p.skill_points if r.baseline else p.skill_points + p.unspent_attr
		_check(id + "/count", count.is_valid_int() and int(count) == expected, state)
		if p.skill_points > 0 and p.unspent_attr > 0 and int(count) == p.skill_points + p.unspent_attr:
			var tooltip := h.skills_btn.tooltip_text.to_lower()
			_check(id + "/total_explained", tooltip.contains("attribute")
				and (tooltip.contains("talent") or tooltip.contains("skill"))
				and tooltip.contains(str(p.skill_points)) and tooltip.contains(str(p.unspent_attr)), state)
		var ink: Rect2 = r._ink_rect(h.skills_badge_num)
		var badge := h.skills_badge.get_global_rect()
		_check(id + "/badge_geometry", h.skills_btn.get_global_rect().has_point(badge.get_center())
			and h.info_panel.get_global_rect().encloses(badge) and badge.encloses(ink)
			and h.skills_badge_num.is_visible_in_tree(), {"badge": r._rect(badge), "ink": r._rect(ink)})
		for field in r.UTILITIES:
			var other: Control = h.get(field)
			if other != h.skills_btn and other.is_visible_in_tree():
				_check(id + "/badge_clear/" + String(field), not badge.intersects(other.get_global_rect()))
	for field in r.UTILITIES:
		var control: Control = h.get(field)
		_check(id + "/fixed_utility/" + String(field), control.get_global_rect().is_equal_approx(reference[field])
			and control.size.x >= 44.0 and control.size.y >= 44.0, {"rect": r._rect(control.get_global_rect())})
	var geometry := Geometry.inspect(h)
	for row in geometry.checks: _check(id + "/geometry/" + String(row.id), bool(row.passed), row.details)
	if not r.baseline:
		for kind in ["talent", "attribute"]:
			var points: int = p.skill_points if kind == "talent" else p.unspent_attr
			var phrase := "%d %s point%s" % [points, kind, "" if points == 1 else "s"]
			_check(id + "/copy/" + kind, String(state.tooltip).contains(phrase)
				and String(state.detail).contains(phrase), state)
	await _capture(id, {"state": state, "geometry": geometry})


func _open_skills() -> bool:
	var before := _state()
	await r._tap(h.skills_btn.get_global_rect().get_center())
	var opened := g.menus.is_open() and g.menus.current == "skills"
	_check("skills_access_%d" % snapshots.size(), opened and r.get_tree().paused,
		{"input": "ScreenTouch" if r.touch_run else "mouse", "menu": g.menus.current})
	var after := _state()
	var before_values := before.duplicate(true)
	var after_values := after.duplicate(true)
	# The normal full-screen menu hides the gameplay HUD. Visibility changes;
	# progression, tooltip/detail copy and the badge's authored count do not.
	before_values.erase("badge_visible")
	after_values.erase("badge_visible")
	_check("open_no_spend_%d" % snapshots.size(), after_values == before_values and not h.visible,
		{"before": before, "after": after, "hud_hidden_by_menu": not h.visible})
	return opened


func _portrait() -> void:
	var before := _state()
	await r._tap(h.avatar_root.get_global_rect().get_center())
	var opened := is_instance_valid(h.hud_popover)
	_check("portrait_access", opened)
	var copy := ""
	if opened:
		copy = r._popover_text(h.hud_popover)
		for raw in h.hud_popover.find_children("*", "Label", true, false):
			var label := raw as Label
			if not label.is_visible_in_tree() or label.text.is_empty(): continue
			var shape := Geometry.shaped(label)
			_check("portrait_full_text/" + String(label.name), shape.missing.is_empty() and shape.count > 0
				and not label.clip_text and label.visible_ratio >= 1.0
				and label.get_global_rect().grow(0.5).encloses(Geometry.to_rect(shape.cells))
				and g.get_viewport_rect().encloses(Geometry.to_rect(shape.cells)), shape)
		_check("portrait_existing_identity", copy.contains("Level 2") and copy.contains("Combat Rating"), {"copy": copy})
		if not r.baseline:
			_check("portrait_remaining_attribute", copy.contains("0 talent points")
				and copy.contains("1 attribute point available"), {"copy": copy})
	_check("portrait_no_spend", _state() == before)
	await _capture("04_attribute_detail", {"visible_copy": copy,
		"scope": "Missing attribute detail is observed, not a third baseline exemption; full existing text stays strict"})
	await r._close_overlay()


func _button(prefix: String, starts: bool) -> Button:
	var labels: Array[Label] = []
	var buttons: Array[Button] = []
	r._menu_controls(g.menus.root, labels, buttons)
	for button in buttons:
		var matches := button.text.begins_with(prefix) if starts else button.text.contains(prefix)
		if matches: return button
	return null


func _attribute_button(primary: String) -> Button:
	var found: Button
	var matches := 0
	for raw in g.menus.root.find_children("*", "Button", true, false):
		if String(raw.text).strip_edges() != "+1": continue
		for label in raw.get_parent().find_children("*", "Label", true, false):
			if String(label.text) == primary + "  ★":
				found = raw as Button
				matches += 1
	return found if matches == 1 else null


func _show(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: (parent as ScrollContainer).ensure_control_visible(control)
		parent = parent.get_parent()
	await r.frames(4)


func _click(button: Button, id: String) -> bool:
	if not is_instance_valid(button):
		_check(id + "/present", false)
		return false
	await _show(button)
	var visible := button.is_visible_in_tree() and not button.disabled
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			visible = visible and (parent as ScrollContainer).get_global_rect().grow(0.5).encloses(button.get_global_rect())
		parent = parent.get_parent()
	_check(id + "/clickable", visible and g.get_viewport_rect().encloses(button.get_global_rect()),
		{"text": button.text, "rect": r._rect(button.get_global_rect())})
	if not visible: return false
	await r._tap(button.get_global_rect().get_center())
	return true


func _capture(id: String, evidence: Dictionary) -> void:
	await r._capture(id, "Lent legal L2 pools in a fresh no-save hero; real allocation GUI, not earned progression; scroll positioning is setup", false)
	r.views[-1]["attribute_readiness"] = evidence
	snapshots.append({"id": id, "state": _state()})
	r._write_report()
