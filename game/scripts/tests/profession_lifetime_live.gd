extends RefCounted
## The current parent UI is sufficient: no Alchemy preload, invented Button,
## direct _lock/_craft/_buy factory call, old freed control, or real save write.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const CaptionGeometry := preload("res://scripts/tests/hud_alignment_geometry.gd")
const ACTIONS := ["lock", "craft", "learn"]
const RETIREMENTS := ["replaced_shell", "released_shell", "owner", "world", "seed",
	"chapter", "state", "not_started", "dead", "downed", "ghost", "zero_hp", "pvp", "dedicated"]
const PLAYER_FIELDS := ["gold", "profession", "mastery", "swap_week", "swap_cost_step",
	"blueprints", "materials", "backpack", "gem_bag", "bags", "loose_bags", "consumables",
	"npc_favor", "equipment", "hp", "mp", "max_hp", "max_mp", "dead", "downed", "ghost",
	"velocity", "pending_theme_note"]
const ECONOMY_FIELDS := ["gold", "profession", "mastery", "swap_week", "swap_cost_step",
	"blueprints", "materials", "backpack", "gem_bag", "bags", "loose_bags", "consumables", "npc_favor", "equipment"]
const GAME_FIELDS := ["chapter_id", "wander_seed", "state", "play_started", "pvp_active",
	"dedicated", "no_saves", "restoring_save", "save_slot", "guest_world", "dev_god",
	"flags", "mailbox", "settings", "clock_anchor", "talk_cd", "terrain_event_t", "_meta", "_meta_loaded"]

var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native: NativeInput
var keep := {}
var rows: Array[Dictionary] = []
var callback_probes := 0
var positive_actions := 0
var caption_probes := 0


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func snapshot_files() -> Dictionary:
	var files := {}
	for base in ["user://meta.json", "user://settings.json", "user://keybinds.json", SaveGame.path(97)]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = String(base) + String(suffix)
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
		ok = current == files[path] and ok
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
	if not proof._check("fixture.capital_no_saves", proof.g.no_saves and not proof.g.net_online()
			and proof.g.chapter_id == "capital" and is_instance_valid(proof.g.world)
			and proof.m.root == null, "requires isolated solo capital with no open shell"):
		return proof._report()
	proof._snapshot()
	var error: String = await proof._run()
	proof._check("runtime.completed", error == "", error)
	proof._check("coverage.complete", proof.callback_probes == 46 and proof.positive_actions == 7,
		{"retained_callbacks": proof.callback_probes, "positive_actions": proof.positive_actions})
	proof._check("coverage.caption_checks", proof.caption_probes == 7, proof.caption_probes)
	await proof._restore()
	return proof._report()


func _snapshot() -> void:
	keep = {"player": {}, "game": {}, "meta": {}, "world": g.world,
		"registry": g.players.duplicate(), "processing": g.is_processing(),
		"physics": p.is_physics_processing(), "paused": g.get_tree().paused,
		"shell_motion": m.shell_motion, "emulate_touch": Input.emulate_mouse_from_touch,
		"language": Loc.lang, "position": p.global_position, "rng": {}, "economy": _ledger(p)}
	for key in PLAYER_FIELDS:
		keep.player[key] = _copy(p.get(key))
	for key in GAME_FIELDS:
		keep.game[key] = _copy(g.get(key))
	for key in m.get_meta_list():
		keep.meta[key] = _copy(m.get_meta(key))
	for key in ["loot_rng", "sfx_rng", "_float_rng"]:
		var rng: RandomNumberGenerator = g.get(key)
		keep.rng[key] = [rng.seed, rng.state]
	g.set_process(false)
	p.set_physics_process(false)
	Loc.lang = "en"
	Input.emulate_mouse_from_touch = true


func _restore() -> void:
	# Restore identity/context BEFORE closing any potentially invalid test view.
	g.player = p
	g.players = keep.registry.duplicate()
	g.world = keep.world
	g.no_saves = true
	g.dedicated = false
	m.shell_motion = false
	m.close()
	for key in GAME_FIELDS:
		g.set(key, _copy(keep.game[key]))
	for key in PLAYER_FIELDS:
		p.set(key, _copy(keep.player[key]))
	p.recalc()
	# ShotRig god mode can intentionally exceed the normal derived maxima.
	for key in ["hp", "mp", "max_hp", "max_mp"]:
		p.set(key, keep.player[key])
	p.global_position = keep.position
	for key in m.get_meta_list():
		m.remove_meta(key)
	for key in keep.meta:
		m.set_meta(key, _copy(keep.meta[key]))
	for key in keep.rng:
		var rng: RandomNumberGenerator = g.get(key)
		rng.seed = int(keep.rng[key][0])
		rng.state = int(keep.rng[key][1])
	m.shell_motion = bool(keep.shell_motion)
	Input.emulate_mouse_from_touch = bool(keep.emulate_touch)
	Loc.lang = String(keep.language)
	g.refresh_touch_mode()
	g._apply_touch_mode()
	await r.frames(3)
	_check("restore.owning_state", g.local_player == p and g.world == keep.world
		and g.players == keep.registry and _ledger(p) == keep.economy, _summary(p))
	_check("restore.input_released", not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not Input.is_key_pressed(KEY_ESCAPE), "no held pointer or key")
	g.set_process(bool(keep.processing))
	p.set_physics_process(bool(keep.physics))
	g.get_tree().paused = bool(keep.paused)


func _loan(owner: Player) -> void:
	owner.profession = "alchemist"
	owner.mastery = {"alchemist": 500}
	owner.swap_week = Professions.week_index(owner)
	owner.swap_cost_step = 0
	owner.gold = 1000000
	owner.blueprints = []
	owner.materials = []
	for family in ["bone", "cloth"]:
		owner.materials.append(Items.make_material(family, "F", 30))
	owner.backpack = []
	owner.gem_bag = []
	owner.loose_bags = []
	owner.consumables = []
	owner.bags = [Items.make_bag("A")]
	owner.npc_favor = {}
	owner.dead = false
	owner.downed = false
	owner.ghost = false
	owner.hp = owner.max_hp
	owner.mp = owner.max_mp


func _open_fixture(touch := false) -> void:
	g.player = p
	g.players = keep.registry.duplicate()
	g.world = keep.world
	for key in GAME_FIELDS:
		g.set(key, _copy(keep.game[key]))
	g.no_saves = true
	g.save_slot = -1
	g.guest_world = false
	g.chapter_id = "capital"
	g.state = Game.ST_PLAYING
	g.play_started = true
	g.pvp_active = false
	g.dedicated = false
	g.mailbox = []
	_loan(p)
	g.loot_rng.seed = 910091
	g.settings["touch_controls"] = touch
	g.refresh_touch_mode()
	g._apply_touch_mode()
	m.shell_motion = false
	m.open_professions()
	await r.frames(3)


func _action(action: String) -> Dictionary:
	var label := {"lock": "Lock Blacksmith", "craft": "Craft F", "learn": "Learn Generic B Charm"}
	var button: Button = native._find_button(m.root, String(label[action]))
	if not _check("fixture.button.%s.%d" % [action, rows.size()], button != null, label[action]):
		return {}
	var links := button.get_signal_connection_list("pressed")
	if not _check("fixture.connections.%s.%d" % [action, rows.size()], links.size() == 2,
			{"text": button.text, "connections": links.size()}):
		return {}
	var retained: Callable = links[1].callable
	if not _check("fixture.callable.%s.%d" % [action, rows.size()], retained.is_valid(), button.text):
		return {}
	# A name only on the native test instance; labels and callbacks are untouched.
	button.name = "QAProfession_" + action
	return {"button": button, "callback": retained, "shell": m.root, "label": button.text}


func _reveal(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await r.frames(2)
		ancestor = ancestor.get_parent()


func _ledger(owner: Player) -> Dictionary:
	var character := {}
	for key in ECONOMY_FIELDS:
		character[key] = _copy(owner.get(key))
	return {"player": character, "mail": g.mailbox.duplicate(true), "flags": g.flags.duplicate(true),
		"loot": [g.loot_rng.seed, g.loot_rng.state]}


func _summary(owner: Player) -> Dictionary:
	return {"hero": owner.get_instance_id(), "gold": owner.gold, "trade": owner.profession,
		"mastery": owner.mastery.duplicate(true), "blueprints": owner.blueprints.duplicate(),
		"materials": owner.materials.duplicate(true), "pack": owner.backpack.size(),
		"mail": g.mailbox.size(), "root": m.root.get_instance_id() if is_instance_valid(m.root) else 0,
		"menu": m.current, "world": g.world.get_instance_id(), "seed": g.wander_seed,
		"loot_state": g.loot_rng.state}


func _expected(action: String, owner: Player) -> Dictionary:
	# Independent one-action expectation, using canonical costs and a detached
	# RNG for the deterministic F charm. No real core transaction pays a loan.
	var expected := _ledger(owner)
	var character: Dictionary = expected.player
	match action:
		"lock":
			character.gold = owner.gold - Professions.swap_cost(owner)
			character.profession = "blacksmith"
			character.swap_cost_step = owner.swap_cost_step + 1
			character.mastery["blacksmith"] = 0
		"learn":
			character.gold = owner.gold - Balance.blueprint_price("charm", "B")
			character.blueprints.append(Items.blueprint_key("charm", "B"))
		"craft":
			character.gold = owner.gold - int(Balance.CRAFT_GOLD_FEE.F)
			character.mastery["alchemist"] = Professions.points(owner) + int(Balance.CRAFT_MASTERY_BY_GRADE.F)
			for material in character.materials:
				if material.family == Balance.craft_material("charm") and material.grade == "F":
					material.count = int(material.count) - int(Balance.CRAFT_MATERIAL_COST.F)
			var rng := RandomNumberGenerator.new()
			rng.seed = g.loot_rng.seed
			rng.state = g.loot_rng.state
			character.backpack.append(Items.roll_item_of("charm", "F", rng, owner.cls, "", 0))
			expected.loot = [rng.seed, rng.state]
	return expected


func _run() -> String:
	r.step("controlled Professions loans; native valid actions")
	for touch in [false, true]:
		for action in ACTIONS:
			await _open_fixture(touch)
			var record := _action(action)
			if record.is_empty(): return "native action fixture unavailable"
			await _reveal(record.button)
			var expected := _expected(action, p)
			_check("positive.solo_menu_pauses.%s.%s" % [action, touch], g.get_tree().paused, m.current)
			if touch:
				await native._touch(record.button.get_global_rect().get_center())
			else:
				await native._mouse(record.button.get_global_rect().get_center())
			await r.frames(3)
			_check("positive.exact.%s.%s" % [action, touch], _ledger(p) == expected and m.current == "professions", _summary(p))
			positive_actions += 1
			_active_trade_caption("%s.%s" % [action, "touch" if touch else "mouse"])
			if action == "craft": await _capture("01_valid_craft_" + ("touch" if touch else "mouse"))
	# This is an unpaused-overlay fixture, not a live network/session claim.
	await _open_fixture()
	var active := _action("craft")
	if active.is_empty(): return "unpaused control unavailable"
	await _reveal(active.button)
	g.request_pause(false)
	var unpaused_expected := _expected("craft", p)
	await native._mouse(active.button.get_global_rect().get_center())
	await r.frames(3)
	_check("positive.unpaused_overlay", _ledger(p) == unpaused_expected, _summary(p))
	positive_actions += 1
	_active_trade_caption("craft.unpaused")
	for action in ACTIONS:
		for retirement in RETIREMENTS:
			var error: String = await _retired(action, retirement)
			if error != "": return error
	for action in ACTIONS:
		var error: String = await _duplicate(action)
		if error != "": return error
	return await _cross_action()


func _active_trade_caption(id: String) -> void:
	# Observe the freshly rebuilt real caption without resizing/revealing it.
	# The original 46 callback and seven positive ledgers remain independent.
	caption_probes += 1
	var captions: Array[Label] = []
	var pending: Array[Node] = [m.root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not is_instance_valid(node): continue
		for child in node.get_children(): pending.append(child)
		if node is Label and node.text.begins_with("● ") and node.text.ends_with(" — active"):
			captions.append(node)
	if not _check("caption.present." + id, captions.size() == 1, captions.size()):
		return
	var caption: Label = captions[0]
	var expected := "● %s  [%s] — active" % [Professions.trade_name(p.profession),
		", ".join(Professions.slots_of(p.profession))]
	_check("caption.complete_text." + id, caption.text == expected,
		{"actual": caption.text, "expected": expected})
	var row := caption.get_parent() as HBoxContainer
	var list: VBoxContainer = row.get_parent() as VBoxContainer if row != null else null
	var scroll: ScrollContainer = list.get_parent() as ScrollContainer if list != null else null
	if not _check("caption.row_structure." + id, row != null and list != null and scroll != null,
			"active caption in live trade HBox / list / ScrollContainer"):
		return
	var shape: Dictionary = CaptionGeometry.shaped(caption)
	var bounds: Rect2 = CaptionGeometry.to_rect(shape.cells)
	var lines: int = caption.get_line_count()
	var visible_lines: int = caption.get_visible_line_count()
	var full_text: bool = shape.missing.is_empty() and int(shape.count) > 0 \
		and caption.visible_ratio >= 1.0 and caption.max_lines_visible == -1 \
		and caption.lines_skipped == 0 and not caption.clip_text and visible_lines == lines
	var contained: bool = caption.get_global_rect().grow(1.0).encloses(bounds) \
		and row.get_global_rect().grow(1.0).encloses(bounds) \
		and list.get_global_rect().grow(1.0).encloses(bounds) \
		and scroll.get_global_rect().grow(1.0).encloses(bounds) \
		and m.get_viewport().get_visible_rect().grow(1.0).encloses(bounds)
	var readable: bool = full_text and contained and caption.is_visible_in_tree() \
		and lines >= 1 and lines <= 2 and caption.get_theme_font_size("font_size") >= 14
	# Narrow-width line stacking is the ONLY new baseline exception. Missing
	# captions, wrong text/structure, normal-width clipping and tiny text fail.
	var collapsed: bool = full_text and caption.is_visible_in_tree() and lines > 2 \
		and caption.get_theme_font_size("font_size") >= 14 \
		and caption.size.x < float(caption.get_theme_font_size("font_size")) * 2.0
	_check("caption.readable." + id, readable,
		{"shape": shape, "label": str(caption.get_global_rect()), "row": str(row.get_global_rect()),
		"list": str(list.get_global_rect()), "scroll": str(scroll.get_global_rect()),
		"visible_lines": visible_lines, "full_text": full_text, "contained": contained,
		"narrow_line_stack": collapsed}, collapsed)


func _retired(action: String, retirement: String) -> String:
	r.step("controlled retained %s callback after %s" % [action, retirement])
	await _open_fixture()
	var record := _action(action)
	if record.is_empty(): return "retained native action unavailable"
	await _reveal(record.button)
	var old_shell: WeakRef = weakref(record.shell)
	if action == "craft" and retirement == "replaced_shell":
		await _capture("02_live_parent_before_replacement")
	var temporary: Node = null
	var owner: Player = p
	match retirement:
		"replaced_shell": m.open_inventory()
		"released_shell":
			m.shell_motion = true
			m.close()
		"owner":
			var replacement := Player.new()
			replacement.game = g
			replacement.process_mode = Node.PROCESS_MODE_DISABLED
			replacement.visible = false
			g.add_child(replacement)
			replacement.set_class(p.cls)
			_loan(replacement)
			g.player = replacement  # actual alias setter updates local registry
			owner = replacement
			temporary = replacement
		"world":
			var replacement := Node2D.new()
			g.add_child(replacement)
			g.world = replacement
			temporary = replacement
		"seed": g.wander_seed += 1
		"chapter": g.chapter_id = "ch2"
		"state": g.state = Game.ST_DEAD
		"not_started": g.play_started = false
		"dead": p.dead = true
		"downed": p.downed = true
		"ghost": p.ghost = true
		"zero_hp": p.hp = 0.0
		"pvp": g.pvp_active = true
		"dedicated": g.dedicated = true
	# No await after replacement/context mutation until callback/assertions and
	# identity restoration. All old controls and temporary identities are live.
	var before := _ledger(owner)
	var old_owner_before := _ledger(p)
	var destination: Control = m.root
	var destination_name := m.current
	var context_before := _summary(owner)
	if not _check("lifetime.valid_old_control.%s.%s" % [action, retirement], is_instance_valid(record.button), record.label):
		return "old native control freed before controlled callback"
	record.callback.call()
	callback_probes += 1
	var after := _summary(owner)
	var rejected := _ledger(owner) == before and _ledger(p) == old_owner_before \
		and m.root == destination and m.current == destination_name
	_check("lifetime.reject.%s.%s" % [action, retirement], rejected,
		{"before": context_before, "after": after}, true)
	# Do not allow test-invalid identity/state to leak into a process frame.
	g.player = p
	g.players = keep.registry.duplicate()
	g.world = keep.world
	for key in ["chapter_id", "wander_seed", "state", "play_started", "pvp_active", "dedicated"]:
		g.set(key, _copy(keep.game[key]))
	p.dead = false
	p.downed = false
	p.ghost = false
	p.hp = p.max_hp
	if temporary != null: temporary.queue_free()
	if action == "craft" and retirement == "replaced_shell":
		await _capture("03_replacement_after_controlled_callback")
	# Release the current test view and let queue_free/tweens drain. We inspect
	# only the WeakRef afterward; never invoke any freed Button or its signal.
	m.close()
	await r.sim_wait(0.25)
	_check("lifetime.old_shell_released.%s.%s" % [action, retirement], old_shell.get_ref() == null, retirement)
	return ""


func _duplicate(action: String) -> String:
	r.step("real native activation then same-frame duplicate " + action)
	await _open_fixture()
	var record := _action(action)
	if record.is_empty(): return "duplicate action unavailable"
	await _reveal(record.button)
	var expected := _expected(action, p)
	_click_now(record.button.get_global_rect().get_center())
	_check("duplicate.first_exact." + action, _ledger(p) == expected, _summary(p))
	var destination: Control = m.root
	var before := _ledger(p)
	if not _check("duplicate.old_button_valid." + action, is_instance_valid(record.button), record.label):
		return "duplicate control already freed"
	record.callback.call()
	callback_probes += 1
	_check("duplicate.second_rejected." + action, _ledger(p) == before and m.root == destination
		and m.current == "professions", _summary(p), true)
	await r.frames(3)
	return ""


func _cross_action() -> String:
	r.step("one native Craft then old Learn from the same retired parent")
	await _open_fixture()
	var craft := _action("craft")
	var learn := _action("learn")
	if craft.is_empty() or learn.is_empty(): return "cross-action native controls unavailable"
	await _reveal(craft.button)
	var expected := _expected("craft", p)
	_click_now(craft.button.get_global_rect().get_center())
	_check("cross.first_craft_exact", _ledger(p) == expected, _summary(p))
	var destination: Control = m.root
	var before := _ledger(p)
	if not _check("cross.old_learn_valid", is_instance_valid(learn.button), learn.label):
		return "cross-action control already freed"
	learn.callback.call()
	callback_probes += 1
	_check("cross.second_action_rejected", _ledger(p) == before and m.root == destination,
		_summary(p), true)
	await r.frames(3)
	await _capture("04_after_cross_action_probe")
	return ""


func _click_now(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	native.mouse_clicks += 1


func _capture(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "controlled loans + retained native callbacks; no ordinary retired-panel click claim")


func _check(id: String, passed: bool, actual: Variant, known_lifetime := false) -> bool:
	var expected := not passed and known_lifetime and r.flag("baseline")
	rows.append({"id": id, "passed": passed, "expected_baseline_finding": expected, "actual": actual})
	print("PROFESSION CHECK %s: %s" % [id, "PASS" if passed else "BASELINE FINDING" if expected else "FAIL"])
	return passed


func _report() -> Dictionary:
	var result := {"baseline": r.flag("baseline"), "checks": rows.size(), "passed": 0,
		"failures": 0, "findings": 0, "rows": rows, "positive_actions": positive_actions,
		"retained_callbacks": callback_probes, "active_caption_probes": caption_probes,
		"mouse_clicks": native.mouse_clicks,
		"touch_taps": native.touch_taps,
		"fixture": "loaned capital resources; simulation frozen; actual native buttons/input and extracted same-frame callbacks; no_saves; no actual online/travel/save or ordinary-click exploit claim"}
	for row in rows:
		if row.passed: result.passed += 1
		elif row.expected_baseline_finding: result.findings += 1
		else: result.failures += 1
	return result
