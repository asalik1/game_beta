extends RefCounted
## Optional layout coverage only. Keeps the original real save-fault proof intact.
## The base Fangmoot host cannot grant rewards or persist a profile. The final
## turn and HUD strings are posed; actual production builders do the rendering.
const Geometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const FM_FIELDS := ["fm_moot", "fm_host", "fm_standalone", "fm_opp", "fm_opp_turn", "fm_speed"]
const SCOPE := "real failed temp-file open; posed long HUD / fresh no-reward Fangmoot / final turn; no played match or campaign reward claim"

# Deliberately dynamic to avoid a cyclic preload of the calling proof script.
var proof: Variant
var r: ShotRig
var g: Game
var m: Menus
var keep := {}


static func run(owner: Variant) -> String:
	var test := new()
	test.proof = owner
	test.r = owner.r
	test.g = owner.g
	test.m = owner.m
	# Close the prior Alchemy page normally, before faulting the next save.
	test.m.close()
	await test.r.frames(3)
	test.keep.hud = Geometry.snapshot(test.g.hud)
	test.keep.paused = test.g.get_tree().paused
	test.keep.talk_cd = test.g.talk_cd
	test.keep.fm = {}
	for field in FM_FIELDS:
		test.keep.fm[field] = test.m.get(field)
	test.keep.economy = owner._economy()
	test.keep.home = SaveGame.world_of(SaveGame.read(owner.SLOT)).duplicate(true)
	var error: String = await test._run()
	# Always restore the optional state. The outer proof restores all fixture
	# player/game fields and the entry rig restores exact original file bytes.
	owner._unblock_tmp()
	if test.m.root != null:
		test.m.close()
	for field in FM_FIELDS:
		test.m.set(field, test.keep.fm[field])
	Geometry.restore(test.g.hud, test.keep.hud)
	test.g.talk_cd = float(test.keep.talk_cd)
	test.g.request_pause(bool(test.keep.paused))
	owner._check("placement.economy_unchanged", owner._economy() == test.keep.economy,
		"no-reward host and HUD copy fixture never change character economy")
	owner._check("placement.home_world_unchanged", SaveGame.world_of(SaveGame.read(owner.SLOT)) == test.keep.home,
		"same real character-home save path; entire saved home world stays exact")
	return error


func _run() -> String:
	r.step("optional save notice placement: long HUD and actual Fangmoot builders")
	var old_bytes := FileAccess.get_file_as_bytes(SaveGame.path(proof.SLOT))
	if not proof._block_tmp():
		return "placement obstruction could not be created"
	g.autosave()
	proof._feedback("placement.actual_failed_write", "Saving failed.")
	# Only display strings/target visibility are posed. Pausing prevents the
	# regular Game HUD refresh from immediately replacing this long-copy sample.
	g.request_pause(true)
	Geometry.apply_case(g.hud, Geometry.CASES[1])
	await r.frames(3)
	# Hud.set_quest adds its normal glyph and applies touch-aware copy.
	var shown_quest := "◆  " + g.touchify(String(Geometry.CASES[1].quest).strip_edges())
	proof._check("placement.long_hud_fixture", g.hud.boss_box.is_visible_in_tree()
		and g.hud.quest_label.text == shown_quest,
		"long objective and boss readout are posed; no actual boss/cast encounter")
	_world_clearance()
	await proof._capture("06_placement_long_hud", SCOPE)
	Geometry.restore(g.hud, keep.hud)

	m.fm_host = FangmootHost.new()
	m.fm_standalone = false
	m.fm_moot = null
	m.fm_opp = []
	m.fm_opp_turn = -1
	m.fm_speed = 1.0
	m.open_fangmoot()
	await r.frames(3)
	proof._check("placement.hub_actual_builder", m.current == "fangmoot" and _arena_container() == null
		and _has_hub_backdrop(), "actual hub has its zero-y backdrop, no positive-y arena")
	_menu_top("placement.hub_menu_strip")
	await proof._capture("07_placement_fangmoot_hub", SCOPE)

	# Same no-persistence setup seam as shot_fangmoot's terrain fixture. One
	# first legal token is sufficient; do not cherry-pick a winning team.
	m.fm_moot = FangmootMoot.new("copper", 903134, m.fm_host)
	m.fm_moot.begin_turn()
	for index in m.fm_moot.tray.size():
		var card: Dictionary = m.fm_moot.tray[index]
		if String(card.get("ctype", "")) in ["token", "named"] and m.fm_moot.can_buy(index):
			UIFangmoot._quick_buy(m, index)
			break
	if not proof._check("placement.fielded_real_token", m.fm_moot.board_count() > 0,
		"first legal tray token; no profile resources or chosen fight outcome"):
		return "fresh layout moot has no legal token"
	await r.frames(3)
	_arena_clearance("placement.board_arena", false)
	await proof._capture("08_placement_fangmoot_board", SCOPE)

	# Pose only the private test moot's turn. Production _call runs the real
	# simulation and advances past the cap, setting done before _fight_view.
	# No log keeps this placement probe short; it is not animation coverage.
	m.fm_moot.turn = int(Balance.FANGMOOT_MAX_TURNS)
	m.fm_moot.want_log = false
	UIFangmoot._call(m)
	var deadline := Time.get_ticks_msec() + 6000
	var continue_button: Button = null
	while Time.get_ticks_msec() < deadline:
		continue_button = proof.native._find_button(m.root, "Continue", true)
		if continue_button != null:
			break
		await g.get_tree().create_timer(0.05, true, false, true).timeout
	# Await the actual finished->Continue handoff before any menu replacement;
	# never free an arena with its replay coroutine still waiting on a timer.
	if not proof._check("placement.final_actual_handoff", continue_button != null
		and m.fm_moot.done and m.fm_moot.last_log.is_empty(),
		{"done": m.fm_moot.done, "turn": m.fm_moot.turn, "log_size": m.fm_moot.last_log.size(),
		"continue_visible": continue_button != null, "scope": "posed final turn; production _call and finished callback"}):
		return "final placement view did not reach its visible Continue handoff"
	_arena_clearance("placement.final_done_arena", true)
	await proof._capture("09_placement_fangmoot_final_failure", SCOPE)
	proof._check("placement.failed_writes_preserve_bytes",
		FileAccess.get_file_as_bytes(SaveGame.path(proof.SLOT)) == old_bytes,
		"every failed layout-stage attempt retains the last complete character file")
	var failed_rect := _notice_rect()
	if not proof._unblock_tmp():
		return "placement obstruction could not be removed"
	g.autosave()
	proof._feedback("placement.final_real_recovery", "Progress saved.")
	proof._check("placement.final_banked", proof._bank_matches(), "actual successful atomic character-home write")
	await r.frames(3)
	_arena_clearance("placement.final_done_recovery", true)
	_notice_check("placement.recovery_same_footprint", _notice_rect().is_equal_approx(failed_rect),
		{"warning": str(failed_rect), "recovery": str(_notice_rect())})
	await proof._capture("10_placement_fangmoot_final_recovery", SCOPE)
	if not await _click("Continue"):
		return "final Continue input failed"
	proof._check("placement.result_uses_normal_menu", m.current == "fangmoot"
		and m.fm_moot.done and _arena_container() == null, "actual result builder after real Continue mouse input")
	_menu_top("placement.result_menu_strip")
	proof._geometry("placement.result_transition.readability")
	proof._clearance("placement.result_transition.clearance")
	if not await _click("Back to the Circle"):
		return "Fangmoot result return input failed"
	if not await _click("Leave the Circle"):
		return "Fangmoot normal return input failed"
	proof._check("placement.return_world_input", m.root == null and not g.get_tree().paused,
		"actual result-to-hub-to-world buttons; notice remains input-transparent")
	proof._geometry("placement.return_world_transition.readability")
	proof._clearance("placement.return_world_transition.clearance")
	return ""


func _click(text_value: String) -> bool:
	var button: Button = proof.native._find_button(m.root, text_value, true)
	if not proof._check("placement.input." + text_value, button != null, "real visible enabled Button"):
		return false
	await proof.native._mouse(button.get_global_rect().get_center())
	await r.frames(3)
	return true


func _notice_rect() -> Rect2:
	var feedback := g.get_node_or_null("CharacterSaveFeedback")
	var bar := feedback.find_child("SaveFeedbackBar", true, false) as Control if feedback != null else null
	return bar.get_global_rect() if bar != null else Rect2()


func _notice_check(id: String, passed: bool, detail: Variant) -> void:
	var absent := g.get_node_or_null("CharacterSaveFeedback") == null
	proof._check(id, not absent and passed, detail, absent)


func _world_clearance() -> void:
	var notice := _notice_rect()
	var tracker := g.hud.quest_panel.get_global_rect()
	var minimap := g.hud.minimap_root.get_global_rect()
	_notice_check("placement.world_tracker_minimap_gaps", notice.has_area()
		and notice.position.x >= tracker.end.x + 4.0 and notice.end.y <= minimap.position.y - 4.0,
		{"notice": str(notice), "tracker": str(tracker), "minimap": str(minimap)})


func _menu_top(id: String) -> void:
	var notice := _notice_rect()
	# The compact row must stay above normal 660px shell content (y>=27).
	_notice_check(id, notice.has_area() and notice.position.y >= 0.0 and notice.end.y <= 27.0,
		{"notice": str(notice), "current": m.current, "positive_y_arena": _arena_container() != null})


func _has_hub_backdrop() -> bool:
	for child in m.root.get_children():
		if child is SubViewportContainer and is_zero_approx(child.position.y):
			return true
	return false


func _arena_container() -> SubViewportContainer:
	if m.root != null:
		for child in m.root.get_children():
			if child is SubViewportContainer and child.position.y > 0.0:
				return child
	return null


func _arena_clearance(id: String, expect_done: bool) -> void:
	var container := _arena_container()
	var arena: UIFangmootArena = null
	var topbar: Panel = null
	if container != null:
		for viewport in container.get_children():
			for child in viewport.get_children():
				if child is UIFangmootArena:
					arena = child
	for child in m.root.get_children():
		if child is Panel and is_zero_approx(child.position.y) and child.size.y > 0:
			topbar = child
	if not proof._check(id + ".actual_view", m.current == "fangmoot" and container != null
		and arena != null and topbar != null and m.fm_moot.done == expect_done,
		{"current": m.current, "done": m.fm_moot.done, "expect_done": expect_done,
		"arena_container": str(container.get_global_rect()) if container != null else "missing"}):
		return
	var notice := _notice_rect()
	# Arena labels use SubViewport coordinates, unlike menu controls. Translate
	# the real reserved announcement bounds through its actual container/scale.
	# It is normally alpha-zero with this no-log fixture; this reserves its full
	# authored readout box and does not claim an actual ability banner occurred.
	var arena_viewport := arena.get_viewport()
	var ratio := container.size / Vector2(arena_viewport.get_visible_rect().size)
	var local := arena._banner.get_global_rect()
	var announcement := Rect2(container.global_position + local.position * ratio, local.size * ratio)
	var top := topbar.get_global_rect()
	_notice_check(id + ".topbar_and_announcement_clear", notice.has_area()
		and notice.position.y >= top.end.y + 0.5 and notice.end.y <= announcement.position.y - 0.5
		and container.get_global_rect().grow(0.5).encloses(notice),
		{"notice": str(notice), "topbar": str(top), "announcement_reserved_bounds": str(announcement),
		"announcement_alpha": arena._banner.modulate.a, "done": m.fm_moot.done})
