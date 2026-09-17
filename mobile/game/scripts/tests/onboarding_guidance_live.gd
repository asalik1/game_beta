extends RefCounted
## Controlled reader/callback fixture: lent legal pools, not an earned room clear.
const EXPECTED_LINE := "You can spend talent points in Skills, under Talents. Look under Attributes for your attribute points, too."
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const PLAYER_FIELDS := ["level", "xp", "skill_points", "unspent_attr", "attr_points", "tree_points", "talent_loadouts", "active_talent_loadout", "hp", "mp"]
var native := Native.new()
var rig: Node
var game: Game
var player: Player
var hud: Hud
var checks: Array[Dictionary] = []
var failures := 0
var views: Array[String] = []
var original_player: Dictionary = {}
var original_flags: Dictionary = {}
var original_physics := true
var original_pending := ""
var shot_dir := ""

static func run(rig: Node) -> String:
	var probe := new()
	probe.rig = rig
	probe.game = rig.game
	probe.player = rig.game.local_player
	probe.hud = rig.game.hud
	probe.native.r = rig
	probe.native.g = rig.game
	probe.native.m = rig.game.menus
	if not probe.game.no_saves or probe.game.net_online() or probe.game.chapter_id != "ch1":
		return "Requires fresh no-save offline ch1 fixture"
	probe._snapshot_original()
	probe.player.set_physics_process(false)
	probe.game.pending_tutorial = ""
	var err: String = await probe._exercise()
	probe._restore_after_run()
	var receipt: Dictionary = {
		"checks": probe.checks,
		"failures": probe.failures,
		"views": probe.views,
		"error": err,
		"complete": err == "" and probe.failures == 0,
		"input": "ScreenTouch" if rig.touch_run else "SPACE/mouse",
		"scope": "lent point pools 2t2a/1t1a/0t0a via controlled fixture; direct _run_tutorial_beat invocation; not a normal room clear; no_saves disposable offline process; host-rendered touch only"
	}
	var json_str := JSON.stringify(receipt, "  ")
	print("ONBOARDING GUIDANCE RECEIPT:\n" + json_str)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(probe.shot_dir))
	var file := FileAccess.open(probe.shot_dir.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: return "Cannot write onboarding guidance receipt"
	file.store_string(json_str)
	file.close()
	return err if err != "" else ("" if probe.failures == 0 else "Onboarding-guidance probe failed")

func _snapshot_original() -> void:
	shot_dir = rig.shot_dir
	original_physics = player.is_physics_processing()
	original_pending = game.pending_tutorial
	for field in PLAYER_FIELDS:
		var value: Variant = player.get(field)
		original_player[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	original_flags = game.flags.duplicate(true)

func _restore_after_run() -> void:
	hud.dialogue_done = Callable()
	if hud.dialogue_active: hud._advance_dialogue()
	game.menus.close()
	game.request_pause(false)
	for field in PLAYER_FIELDS:
		var value: Variant = original_player[field]
		player.set(field, value.duplicate(true) if value is Array or value is Dictionary else value)
	player.recalc()
	player.hp = float(original_player.hp)
	player.mp = float(original_player.mp)
	game.flags = original_flags.duplicate(true)
	game.pending_tutorial = original_pending
	player.set_physics_process(original_physics)
	var restored := game.flags == original_flags
	for field in PLAYER_FIELDS:
		restored = restored and player.get(field) == original_player[field]
	_check("cleanup/owned_progression", restored)
	_check("cleanup/reader_closed", not hud.dialogue_active and not game.menus.is_open())

func _exercise() -> String:
	var contexts: Array = [
		{"talent": 2, "attr": 2, "label": "2t2a"},
		{"talent": 1, "attr": 1, "label": "1t1a"},
		{"talent": 0, "attr": 0, "label": "0t0a"},
	]
	for ctx in contexts:
		var err: String = await _run_context(ctx)
		if err != "": return err
	return ""

func _run_context(ctx: Dictionary) -> String:
	var label: String = ctx.label
	var target_talent: int = ctx.talent
	var target_attr: int = ctx.attr
	player.level = 3
	player.xp = 0
	player.skill_points = 1 + 2 * Balance.SKILL_POINTS_PER_LEVEL
	player.unspent_attr = 0 + 2 * Balance.ATTR_POINTS_PER_LEVEL
	player.tree_points = {}
	for key in player.attr_points.keys(): player.attr_points[key] = 0
	player.talent_loadouts = original_player.talent_loadouts.duplicate(true)
	player.active_talent_loadout = 0
	player.sync_active_talent_loadout()
	player.recalc()
	while player.skill_points > target_talent:
		if not player.add_tree_point("w00"): return "Failed to spend talent point in context %s" % label
	while player.unspent_attr > target_attr:
		if not player.add_attr_points("STR", 1): return "Failed to spend attribute point in context %s" % label
	_check(label + "/legal_pools", player.skill_points == target_talent and player.unspent_attr == target_attr
		and int(player.tree_points.get("w00", 0)) + target_talent == 1 + 2 * Balance.SKILL_POINTS_PER_LEVEL
		and int(player.attr_points.STR) + target_attr == 2 * Balance.ATTR_POINTS_PER_LEVEL)
	game.flags.erase("tut_talents_done")
	var flags_before: Dictionary = game.flags.duplicate(true)
	game._run_tutorial_beat("talents")
	await rig.sim_wait(0.25)
	if not await _wait_for_dialogue_active_and_revealed(): return "Dialogue did not reveal in context %s" % label
	var shot_name: String = "dialogue_%s" % label
	await rig.frames(2)
	await RenderingServer.frame_post_draw
	rig.shot(shot_name)
	views.append(shot_dir.path_join(shot_name + ".png"))
	var actual_text: String = hud.text_label.text
	_check("onboarding_guidance/%s/copy" % label, actual_text == EXPECTED_LINE, {"actual": actual_text, "expected": EXPECTED_LINE})
	_check("onboarding_guidance/%s/visual" % label, _check_visual(), {})
	var flags_after: Dictionary = game.flags.duplicate(true)
	var expected_flags: Dictionary = flags_before.duplicate(true)
	expected_flags["tut_talents_done"] = true
	_check("onboarding_guidance/%s/flag" % label, flags_after == expected_flags, {"before": flags_before, "after": flags_after})
	_check("onboarding_guidance/%s/pools_unchanged" % label,
		player.skill_points == target_talent and player.unspent_attr == target_attr,
		{"skill_before": target_talent, "skill_after": player.skill_points,
		"attr_before": target_attr, "attr_after": player.unspent_attr})
	await _confirm()
	if not await _wait_for_menu_skills(): return "Skills panel did not open in context %s" % label
	var talents_label: Label = _find_label_with_text("TALENT LOADOUTS")
	_check("onboarding_guidance/%s/talents_visible" % label, talents_label != null and talents_label.is_visible_in_tree(), {"found": talents_label != null})
	_check(label + "/callback_keeps_pools", player.skill_points == target_talent and player.unspent_attr == target_attr)
	var skills_shot: String = "skills_%s" % label
	await rig.frames(4)
	await RenderingServer.frame_post_draw
	rig.shot(skills_shot)
	views.append(shot_dir.path_join(skills_shot + ".png"))
	if label == "2t2a":
		var attr_btn: Button = native._find_button(game.menus.root, "ATTRIBUTES")
		if attr_btn == null: return "Attributes button not found"
		await _tap(attr_btn.get_global_rect().get_center())
		await rig.frames(5)
		var guard := 0
		var attr_scroll: ScrollContainer = null
		while guard < 20:
			attr_scroll = game.menus.root.find_child("AttributeAllocationScroll", true, false) as ScrollContainer
			if attr_scroll and attr_scroll.is_visible_in_tree(): break
			await rig.frames(3)
			guard += 1
		if attr_scroll == null or not attr_scroll.is_visible_in_tree(): return "Attributes tab did not open"
		var attr_shot: String = "attributes_%s" % label
		await RenderingServer.frame_post_draw
		rig.shot(attr_shot)
		views.append(shot_dir.path_join(attr_shot + ".png"))
	game.menus.close()
	await rig.frames(2)
	return ""

func _wait_for_dialogue_active_and_revealed() -> bool:
	if not hud.dialogue_active: return false
	if not hud._reveal_complete(): await _confirm()
	var guard := 0
	while guard < 120:
		if hud.dialogue_active and hud._reveal_complete(): return true
		if not hud.dialogue_active: return false
		await rig.frames(3)
		guard += 1
	return false

func _wait_for_menu_skills() -> bool:
	var guard := 0
	while guard < 120:
		if game.menus.is_open() and game.menus.current == "skills": return true
		await rig.frames(3)
		guard += 1
	return false

func _check_visual() -> bool:
	var rect: Rect2 = hud.text_label.get_global_rect()
	var viewport_rect: Rect2 = rig.get_viewport().get_visible_rect()
	var inside: bool = rect.position.x >= 0 and rect.position.y >= 0 \
		and rect.position.x + rect.size.x <= viewport_rect.size.x \
		and rect.position.y + rect.size.y <= viewport_rect.size.y
	var complete: bool = hud.text_label.is_visible_in_tree() and hud.text_label.visible_ratio >= 1.0
	var line_count: int = hud.text_label.get_line_count()
	var line_height: int = hud.text_label.get_line_height()
	var text_fits: bool = line_count * line_height <= rect.size.y
	return inside and complete and text_fits and hud.dialogue_active and hud.dialogue_lines.size() == 1

func _confirm() -> void:
	if rig.touch_run:
		await native._touch(hud.dialogue_frame.get_global_rect().get_center())
	else:
		await native._key(KEY_SPACE)

func _tap(position: Vector2) -> void:
	if rig.touch_run:
		await native._touch(position)
	else:
		await native._mouse(position)

func _find_label_with_text(text: String) -> Label:
	for node in game.menus.root.find_children("*", "Label", true, false):
		var label := node as Label
		if label and label.text == text and label.is_visible_in_tree(): return label
	return null

func _check(id: String, ok: bool, extra: Dictionary = {}) -> void:
	checks.append({"id": id, "ok": ok, "extra": extra})
	if not ok: failures += 1

