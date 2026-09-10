extends RefCounted
## Actual failed FileAccess open (directory at the owned .tmp path), not a
## substituted save method. All mutations/files belong to an isolated ShotRig.
const PlacementModes := preload("res://scripts/tests/save_feedback_modes.gd")
const TextGeometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const Alchemy := preload("res://scripts/alchemy.gd")
const SLOT := 97
const OTHER_SLOT := 98
const PLAYER_FIELDS := ["gold", "profession", "mastery", "materials", "consumables",
	"blueprints", "bags", "backpack", "gem_bag", "loose_bags", "npc_favor"]
const GAME_FIELDS := ["no_saves", "restoring_save", "save_slot", "guest_world",
	"play_started", "state", "pvp_active", "flags", "wander_seed", "mailbox", "settings", "clock_anchor"]

var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native: NativeInput
var rows: Array[Dictionary] = []
var keep := {}
var owns_tmp_directory := false


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func snapshot_files() -> Dictionary:
	var files := {}
	for base in ["user://meta.json", "user://settings.json", "user://keybinds.json", SaveGame.path(SLOT), SaveGame.path(OTHER_SLOT)]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = String(base) + String(suffix)
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
				return {}  # never remove or reuse a pre-existing directory
			files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return files


static func restore_files(files: Dictionary) -> bool:
	var ok := true
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				ok = false
			else:
				file.store_buffer(files[path])
				file.close()
	for path in files:
		var current: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		ok = current == files[path] and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)) and ok
	return ok


static func run(rig: ShotRig) -> Dictionary:
	var proof := new()
	proof.r = rig
	proof.g = rig.game
	proof.m = rig.game.menus
	proof.p = rig.game.local_player
	proof.native = NativeInput.new()
	proof.native.r = rig
	proof.native.g = proof.g
	proof.native.m = proof.m
	proof._snapshot()
	var error: String = await proof._run()
	proof._check("runtime.completed", error == "", error)
	proof.g.no_saves = true
	proof._unblock_tmp()
	proof._restore()
	return proof._report()


func _snapshot() -> void:
	keep.player = {}
	keep.game = {}
	for field in PLAYER_FIELDS:
		keep.player[field] = _copy(p.get(field))
	for field in GAME_FIELDS:
		keep.game[field] = _copy(g.get(field))
	keep.language = Loc.lang
	keep.emulation = Input.emulate_mouse_from_touch
	keep.view = _copy(m.get_meta("alchemy_view", {}))
	keep.had_view = m.has_meta("alchemy_view")


func _restore() -> void:
	if m.root != null:
		m.close()
	for field in PLAYER_FIELDS:
		p.set(field, _copy(keep.player[field]))
	for field in GAME_FIELDS:
		g.set(field, _copy(keep.game[field]))
	if keep.had_view:
		m.set_meta("alchemy_view", keep.view)
	elif m.has_meta("alchemy_view"):
		m.remove_meta("alchemy_view")
	Loc.lang = keep.language
	Input.emulate_mouse_from_touch = bool(keep.emulation)
	g.refresh_touch_mode()
	g._apply_touch_mode()
	g.request_pause(false)
	var feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	if feedback != null:
		feedback.queue_free()


func _run() -> String:
	if not _check("fixture.isolated_solo_capital", g.no_saves and not g.net_online()
			and g.chapter_id == "capital" and m.root == null, "ShotRig no-save capital"):
		return "unexpected starting context"
	Loc.lang = "en"
	Input.emulate_mouse_from_touch = true
	g.settings["touch_controls"] = false
	g.refresh_touch_mode()
	g._apply_touch_mode()
	p.gold = 10000
	p.profession = "alchemist"
	p.mastery = {"alchemist": 0}
	p.npc_favor = {}
	p.materials = [Items.make_material("herb", "F", 10), Items.make_material("reagent", "F", 10)]
	p.consumables = []
	p.blueprints = []
	p.backpack = []
	p.gem_bag = []
	p.loose_bags = []
	p.bags = [{"slots": 20}]
	g.mailbox = []
	g.save_slot = SLOT
	g.guest_world = false
	g.restoring_save = false
	g.no_saves = false
	g.autosave()
	var first_bytes := FileAccess.get_file_as_bytes(SaveGame.path(SLOT))
	if not _check("fixture.initial_real_save", not first_bytes.is_empty() and _bank_matches(), "real complete character file"):
		return "could not establish a good save"
	_check("success.no_unsolicited_notice", _notice_text() == "", "successful first write allocates no visible notice")
	if not _block_tmp():
		return "could not establish real temp-path obstruction"
	r.step("real failed write while an actual Alchemy Brew settles")
	m.open_alchemy()
	await r.frames(3)
	var before := _economy()
	var quote: Dictionary = Alchemy.quote(g, "health_instant", "F")
	if not await _button("AlchemyBrew"):
		return "actual Brew button unavailable"
	_check("failed_save.transaction_not_rolled_back", p.gold == int(before.gold) - int(quote.fee)
		and p.material_count("herb", "F") == 10 - int(quote.herbs)
		and p.material_count("reagent", "F") == 10 - int(quote.reagents)
		and p.consumables.size() == 1 and p.consumables[0] == quote.item
		and Professions.points(p, "alchemist") == int(quote.mastery_gain), _economy())
	_check("failed_save.old_file_unchanged", FileAccess.get_file_as_bytes(SaveGame.path(SLOT)) == first_bytes,
		"cannot open .tmp directory for writing; prior complete file retained")
	_feedback("failed_save.warning_over_paused_alchemy", "Saving failed.")
	_geometry("failed_save.geometry")
	await _capture("01_failed_brew_menu")
	var first_feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	for _i in 3:
		g.autosave()
	_check("failed_save.coalesced", _notice_text() == "" if first_feedback == null else
		g.get_node_or_null("CharacterSaveFeedback") == first_feedback and _notice_text().begins_with("Saving failed."),
		"repeated actual attempts reuse one notice; no queued notification flood")
	if not _skip_checks(first_bytes):
		return "could not establish observable skip-gate controls"
	SaveGame.write(g, OTHER_SLOT)
	_check("other_slot.real_write", SaveGame.exists(OTHER_SLOT), "unrelated file control")
	_feedback("other_slot.cannot_clear_pending_failure", "Saving failed.")
	if not await _button("AlchemyReturn"):
		return "actual return button unavailable"
	await native._key(KEY_ESCAPE)
	await r.frames(3)
	_check("warning.input_and_navigation_unblocked", m.root == null and not g.get_tree().paused, "Back then Escape remain normal input")
	_feedback("failed_save.warning_in_world", "Saving failed.")
	await _capture("02_failed_save_world")
	if not _unblock_tmp():
		return "could not release owned temp-path obstruction"
	r.step("next normal menu-close autosave persists the whole transaction")
	m.open_pause()
	await r.frames(3)
	var recovery_earliest_ms := Time.get_ticks_msec()
	await native._key(KEY_ESCAPE)
	var recovery_latest_ms := Time.get_ticks_msec()
	await r.frames(3)
	_check("recovery.normal_save_banks_everything", m.root == null and _bank_matches()
		and FileAccess.get_file_as_bytes(SaveGame.path(SLOT)) != first_bytes, "same live recipe, costs and mastery; no second transaction")
	_feedback("recovery.after_actual_success", "Progress saved.")
	await _capture("03_save_recovered")
	await _monotonic_expiry(recovery_earliest_ms, recovery_latest_ms)
	var home := SaveGame.read(SLOT)
	var home_world := SaveGame.world_of(home).duplicate(true)
	var home_chapter := String(home.chapter)
	# Controlled guest-home routing, not a network join. Preserve the old home
	# world while changing the visiting world's flags/seed and local character.
	g.guest_world = true
	g.flags["save_feedback_foreign_world"] = true
	g.wander_seed += 17
	p.gold += 71
	var guest_bytes := FileAccess.get_file_as_bytes(SaveGame.path(SLOT))
	if not _block_tmp():
		return "could not establish guest-home write failure"
	g.autosave()
	await r.frames(2)
	_check("guest_failure.file_and_live_state", FileAccess.get_file_as_bytes(SaveGame.path(SLOT)) == guest_bytes
		and p.gold == int(SaveGame.character_of(home).gold) + 71, "failed character-home write leaves both states intact")
	_feedback("guest_failure.warning", "Saving failed.")
	m.open_alchemy()
	await r.frames(3)
	await _capture("04_guest_home_failure")
	if not _unblock_tmp():
		return "could not release guest obstruction"
	g.autosave()
	var after := SaveGame.read(SLOT)
	_check("guest_recovery.preserves_home_world", SaveGame.world_of(after) == home_world
		and String(after.chapter) == home_chapter and _bank_matches(), "live character saved; visiting flags/seed never colonize home")
	_feedback("guest_recovery.success", "Progress saved.")
	await _capture("05_guest_home_recovered")
	# Direct character-home callers (session end/endgame) bypass autosave gates.
	if not _block_tmp():
		return "could not establish direct-home failure"
	g.play_started = false
	SaveGame.write_character_home(g, SLOT)
	g.play_started = true
	_feedback("direct_home.failure_also_reported", "Saving failed.")
	if not _unblock_tmp():
		return "could not release direct-home obstruction"
	SaveGame.write_character_home(g, SLOT)
	_feedback("direct_home.recovery_also_reported", "Progress saved.")
	_check("direct_home.ownership_preserved", SaveGame.world_of(SaveGame.read(SLOT)) == home_world and _bank_matches(), "direct caller uses same non-granting feedback")
	# A real slot change retires the prior owner/file notice on its next frame.
	g.save_slot = OTHER_SLOT
	await r.frames(2)
	_check("slot_change.retires_notice", _notice_text() == "", "old active-file outcome does not follow a new slot")
	g.save_slot = SLOT
	if r.flag("placement-modes"):
		return await PlacementModes.run(self)
	return ""


func _skip_checks(bytes: PackedByteArray) -> bool:
	# The Brew changed live economy while its write failed. With the obstruction
	# temporarily removed, an incorrectly attempted write would now change the
	# complete file and recover the notice. The entire gate loop is synchronous:
	# no gameplay frame or unrelated writer runs in this unobstructed window.
	if not _check("skip.unsaved_economy_control", not _bank_matches()
			and FileAccess.get_file_as_bytes(SaveGame.path(SLOT)) == bytes,
			"actual brewed live economy differs from the retained complete save"):
		return false
	if not _unblock_tmp():
		return false
	for gate in ["no_saves", "restoring_save", "not_started", "state", "no_slot", "dead", "downed", "ghost", "pvp"]:
		match gate:
			"no_saves": g.no_saves = true
			"restoring_save": g.restoring_save = true
			"not_started": g.play_started = false
			"state": g.state = Game.ST_DEAD
			"no_slot": g.save_slot = -1
			"dead": p.dead = true
			"downed": p.downed = true
			"ghost": p.ghost = true
			"pvp": g.pvp_active = true
		g.autosave()
		# Restore before yielding; unrelated gameplay never runs in a posed state.
		g.no_saves = false
		g.restoring_save = false
		g.play_started = true
		g.state = Game.ST_PLAYING
		g.save_slot = SLOT
		p.dead = false
		p.downed = false
		p.ghost = false
		g.pvp_active = false
		_check("skip." + gate + ".file", FileAccess.get_file_as_bytes(SaveGame.path(SLOT)) == bytes, "skipped save is not reported as durable success")
		_feedback("skip." + gate + ".pending", "Saving failed.")
	# Continue the original failed-write sequence with the same owned fault.
	return _block_tmp()


func _block_tmp() -> bool:
	var path := ProjectSettings.globalize_path(SaveGame.path(SLOT) + ".tmp").replace("\\", "/")
	if not path.to_lower().contains("/save-feedback-candidate/") \
			or not path.ends_with("/save_97.json.tmp") or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return _check("fault.owned_path", false, "requires nonexistent exact isolated .tmp path")
	owns_tmp_directory = DirAccess.make_dir_absolute(path) == OK
	return _check("fault.real_directory", owns_tmp_directory and DirAccess.dir_exists_absolute(path), path)


func _unblock_tmp() -> bool:
	if not owns_tmp_directory:
		return true
	var path := ProjectSettings.globalize_path(SaveGame.path(SLOT) + ".tmp").replace("\\", "/")
	if not path.to_lower().contains("/save-feedback-candidate/") or not path.ends_with("/save_97.json.tmp"):
		return _check("fault.remove_scope", false, path)
	# Nonrecursive removal succeeds only for the exact empty directory we made.
	var removed := DirAccess.remove_absolute(path) == OK
	if removed:
		owns_tmp_directory = false
	return _check("fault.removed_owned_empty_directory", removed, path)


func _economy() -> Dictionary:
	return {"gold": p.gold, "materials": p.materials.duplicate(true), "mastery": p.mastery.duplicate(true),
		"consumables": p.consumables.duplicate(true), "blueprints": p.blueprints.duplicate(), "mailbox": g.mailbox.duplicate(true)}


func _bank_matches() -> bool:
	var saved := SaveGame.character_of(SaveGame.read(SLOT))
	# The persistence boundary uses JSON numbers (floats), including nested
	# stacks/bottles/mastery. Exact live scalar transaction checks stay above.
	var current: Dictionary = JSON.parse_string(JSON.stringify(_economy()))
	for key in current:
		if not saved.has(key) or saved[key] != current[key]:
			return false
	return true


func _notice_text() -> String:
	var feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	if feedback == null:
		return ""
	var label := feedback.find_child("SaveFeedbackText", true, false) as Label
	return label.text if label != null and label.is_visible_in_tree() else ""


func _feedback(id: String, prefix: String) -> void:
	var text := _notice_text()
	var missing := g.get_node_or_null("CharacterSaveFeedback") == null
	_check(id, text.begins_with(prefix), text, missing)


func _geometry(id: String) -> void:
	var feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	if feedback == null:
		_check(id, false, "no failure notice", true)
		return
	var label := feedback.find_child("SaveFeedbackText", true, false) as Label
	var bar := feedback.find_child("SaveFeedbackBar", true, false) as Control
	if not _check(id + ".nodes", label != null and bar != null, "real rendered notice controls"):
		return
	var screen := Rect2(Vector2.ZERO, r.get_viewport().get_visible_rect().size)
	var shape := TextGeometry.shaped(label)
	var cells := TextGeometry.to_rect(shape.cells)
	var ignored := label.mouse_filter == Control.MOUSE_FILTER_IGNORE and bar.mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check(id + ".complete_readable", label.is_visible_in_tree() and int(shape.count) > 0
		and shape.missing.is_empty() and int(shape.font_size) >= 16
		and int(shape.lines) == int(shape.visible_lines)
		and label.visible_ratio == 1.0 and label.max_lines_visible == -1 and not label.clip_text
		and label.get_global_rect().grow(0.5).encloses(cells)
		and screen.encloses(bar.get_global_rect()) and bar.get_global_rect().grow(0.5).encloses(label.get_global_rect())
		and ignored, {"shape": shape, "bar": str(bar.get_global_rect())})


func _clearance(id: String) -> void:
	var feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	var bar := feedback.find_child("SaveFeedbackBar", true, false) as Control if feedback != null else null
	if bar == null:
		_check(id, false, "no failure/recovery notice", feedback == null)
		return
	var protected: Array[Control] = []
	if g.hud.visible:
		for field in ["vitals_panel", "avatar_root", "info_panel", "quest_panel", "hp_text", "mp_text",
			"zone_label", "quest_label", "boss_box", "mob_box", "rival_box", "boss_cast_readout", "minimap_root"]:
			var part: Node = g.hud.get(field)
			if is_instance_valid(part):
				_collect_protected(part, protected, false)
		if is_instance_valid(g.hud.wayfinder):
			var tracked: Node = g.hud.wayfinder.get("quest_root")
			if is_instance_valid(tracked):
				_collect_protected(tracked, protected, false)
	if m.root != null:
		_collect_protected(m.root, protected, true)
	var overlaps: Array[Dictionary] = []
	var menu_copy_overlaps: Array[Dictionary] = []
	var checked: Array[Dictionary] = []
	var notice := bar.get_global_rect()
	for control in protected:
		var bounds := control.get_global_rect()
		var row := {"path": str(control.get_path()), "rect": str(bounds)}
		checked.append(row)
		# Ignore only sub-pixel border contact; do not accept obscured text or hit areas.
		if notice.intersects(bounds.grow(-0.5)):
			if m.root != null and m.root.is_ancestor_of(control) and control is Label:
				menu_copy_overlaps.append(row)
			else:
				overlaps.append(row)
	_check(id, not checked.is_empty() and overlaps.is_empty(),
		{"notice": str(notice), "menu": m.current, "hud_visible": g.hud.visible,
		"protected": checked, "overlaps": overlaps, "menu_copy_overlaps": menu_copy_overlaps})


func _collect_protected(node: Node, out: Array[Control], menu: bool) -> void:
	# SubViewport controls have their own coordinate system. Fangmoot arena
	# announcement bounds are explicitly translated by the optional mode probe.
	if node is SubViewport:
		return
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node is Control and node.modulate.a * node.self_modulate.a > 0.01:
		var readable := node is Label or node is BaseButton or node is LineEdit or node is TextEdit or node is Range
		if (not menu or readable) and node.get_global_rect().has_area() and not out.has(node):
			out.append(node)
	for child in node.get_children():
		_collect_protected(child, out, menu)


func _monotonic_expiry(earliest_ms: int, latest_ms: int) -> void:
	var feedback: Node = g.get_node_or_null("CharacterSaveFeedback")
	if feedback == null:
		_check("recovery.monotonic_visible_window", false, "no recovery notice", true)
		_check("recovery.notice_expires", _notice_text() == "", "baseline has no notice to time")
		return
	# The successful write happens inside the native Escape dispatch interval.
	# This independent window does not read the presenter's private deadline.
	# Timers explicitly ignore simulation time and continue while paused.
	var early_bound := earliest_ms + 3800
	var late_bound := latest_ms + 4300
	var start_ms := Time.get_ticks_msec()
	var held := _notice_text() == "Progress saved."
	m.open_pause()
	await r.frames(2)
	var paused := g.get_tree().paused and m.current == "pause"
	while Time.get_ticks_msec() < early_bound:
		held = held and _notice_text() == "Progress saved."
		await g.get_tree().create_timer(0.05, true, false, true).timeout
	var last_visible_ms := Time.get_ticks_msec()
	while _notice_text() != "" and Time.get_ticks_msec() < late_bound:
		last_visible_ms = Time.get_ticks_msec()
		await g.get_tree().create_timer(0.05, true, false, true).timeout
	var observed_ms := Time.get_ticks_msec()
	var details := {"save_dispatch_earliest_ms": earliest_ms, "save_dispatch_latest_ms": latest_ms,
		"poll_started_ms": start_ms, "last_visible_ms": last_visible_ms, "observed_ms": observed_ms,
		"early_bound_ms": early_bound, "late_bound_ms": late_bound, "paused": paused,
		"menu_retained": m.current == "pause", "clock": "Time.get_ticks_msec; timers ignore_time_scale"}
	_check("recovery.monotonic_visible_window", start_ms < early_bound and held and paused, details)
	_check("recovery.notice_expires", _notice_text() == "" and observed_ms <= late_bound + 150
		and g.get_tree().paused and m.current == "pause", details)
	m.close()
	await r.frames(2)



func _button(name: String) -> bool:
	var button := m.root.find_child(name, true, false) as Button if m.root != null else null
	if not _check("input." + name, button != null and not button.disabled, name):
		return false
	await native._mouse(button.get_global_rect().get_center())
	await r.frames(3)
	return true


func _capture(name: String, extra_scope := "") -> void:
	await r.frames(3)
	_geometry("capture." + name + ".readability")
	_clearance("capture." + name + ".clearance")
	if not r.flag("no-capture"):
		var scope := "controlled directory obstruction; real Alchemy input and save methods; guest-home flag is posed"
		r.shot(name, scope if extra_scope.is_empty() else extra_scope)


func _check(id: String, passed: bool, detail: Variant, known_missing_feedback := false) -> bool:
	var expected := not passed and known_missing_feedback and r.flag("baseline")
	rows.append({"id": id, "passed": passed, "expected_baseline_finding": expected, "detail": detail})
	return passed or expected


func _report() -> Dictionary:
	var passed := 0
	var findings := 0
	var failures := 0
	for row in rows:
		if row.passed:
			passed += 1
		elif row.expected_baseline_finding:
			findings += 1
		else:
			failures += 1
	return {"checks": rows.size(), "passed": passed, "findings": findings, "failures": failures,
		"placement_modes": r.flag("placement-modes"),
		"baseline": r.flag("baseline"), "rows": rows, "mouse_clicks": native.mouse_clicks,
		"key_taps": native.key_taps, "owned_tmp_directory_remaining": owns_tmp_directory,
		"qualification": "Fixture stock/mastery/gold and guest_world flag; actual Alchemy GUI click, actual FileAccess failure and normal save recovery. No disk-full, rename-fault, ENet join or application-exit protection claim. Optional placement-modes uses posed HUD strings, a no-reward Fangmoot host and a posed final turn with real builders; no played-match claim."}
