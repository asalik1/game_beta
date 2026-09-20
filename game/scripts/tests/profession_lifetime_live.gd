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


func _tap_named(name: String) -> bool:
	var id := "browse.%s.%d" % [name, rows.size()]
	var button := m.root.find_child(name, true, false) as Button
	if not _check(id + ".target", button != null and button.is_visible_in_tree() and not button.disabled, name):
		return false
	var rect := button.get_global_rect()
	var visible := rect
	var ancestor := button.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is Control and ancestor.clip_contents:
			visible = visible.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	if not _check(id + ".contained", visible.grow(0.5).encloses(rect)
			and m._shell_rect.grow(0.5).encloses(rect)
			and m.get_viewport().get_visible_rect().encloses(rect), str(rect)):
		return false
	var before := _ledger(p)
	if g.touch_mode: await native._touch(rect.get_center())
	else: await native._mouse(rect.get_center())
	await r.frames(3)
	return _check(id + ".no_spend", _ledger(p) == before and m.current == "professions"
		and is_instance_valid(m.root) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), _summary(p))


func _redesign_controls() -> String:
	# Separate new UI guards; do not inflate the 46 callback / 7 positive counters.
	await _open_fixture()
	if not await _tap_named("ProfTrade_tailor"): return "inactive browse failed"
	var title := m.root.find_child("ProfTradeName", true, false) as Label
	await _capture("05_after_redesign_inactive")
	if not _check("redesign.inactive_browse", title != null and title.is_visible_in_tree()
			and title.text.contains(Professions.trade_name("tailor")) and p.profession == "alchemist", _summary(p)):
		return "inactive browse did not show Tailor without switching"

	await _open_fixture()
	p.materials = [Items.make_material("bone", "F", 2), Items.make_material("bone", "E", 3)]
	var craft := await _action("craft")
	if craft.is_empty(): return "exhausted craft fixture unavailable"
	var expected := _expected("craft", p)
	# take_material removes a drained stack. The original positive fixture's
	# oracle uses surviving stacks, so this local expectation removes zero only.
	var remaining: Array = []
	for material: Dictionary in expected.player.materials:
		if int(material.count) > 0: remaining.append(material)
	expected.player.materials = remaining
	_click_now(craft.button.get_global_rect().get_center())
	if not _check("redesign.exhausted.first_exact", _ledger(p) == expected, _summary(p)):
		return "exhausted craft first ledger mismatch"
	await r.frames(3)
	var before_repeat := _ledger(p)
	await native._key(KEY_ENTER)
	await r.frames(3)
	var recipe := m.root.find_child("ProfRecipeName", true, false) as Label
	await _capture("06_after_redesign_exhausted")
	if not _check("redesign.exhausted.repeat_safe", _ledger(p) == before_repeat
			and recipe != null and recipe.is_visible_in_tree()
			and recipe.text.to_lower().contains("charm") and recipe.text.contains("grade F"), _summary(p)):
		return "exhausted Enter changed selection or spent another affordable recipe"

	await _open_fixture()
	var learn := await _action("learn")
	if learn.is_empty(): return "known blueprint fixture unavailable"
	var expected_learn := _expected("learn", p)
	_click_now(learn.button.get_global_rect().get_center())
	if not _check("redesign.known.first_exact", _ledger(p) == expected_learn, _summary(p)):
		return "known blueprint first ledger mismatch"
	await r.frames(3)
	var before_known_repeat := _ledger(p)
	await native._key(KEY_ENTER)
	await r.frames(3)
	var action := m.root.find_child("ProfLearn", true, false) as Button
	var known := m.root.find_child("ProfKnown_B", true, false) as Label
	var known_visible: bool = known != null and known.is_visible_in_tree() and known.text.to_lower().contains("known")
	await _capture("07_after_redesign_known")
	if not _check("redesign.known.repeat_safe", _ledger(p) == before_known_repeat
			and p.has_blueprint("charm", "B") and known_visible
			and (action == null or action.disabled or not action.is_visible_in_tree()), _summary(p)):
		return "known Blueprint Enter spent again or lost known state"
	return ""


func _changed_trade_controls() -> String:
	# Same live shell/owner/world, but current active profession changes before
	# the real retained action. Distinct from the original 46 lifetime controls.
	for action in ["craft", "learn"]:
		await _open_fixture()
		var record := await _action(action)
		if record.is_empty(): return "changed-trade action unavailable"
		p.profession = "blacksmith"
		var before := _ledger(p)
		record.callback.call()  # No await between trade mutation and guarded action.
		var title := m.root.find_child("ProfTradeName", true, false) as Label
		if not _check("redesign.changed_trade.reject." + action, _ledger(p) == before
				and m.current == "professions" and title != null
				and title.text == Professions.trade_name("alchemist"), _summary(p)):
			return "current-shell trade change spent resources or lost selected trade"
		await r.frames(3)
	return ""


func _full_pack_mail() -> String:
	await _open_fixture()
	# Keep the 30-unit bone stack alive after paying two; draining a stack could
	# free a bag slot and would not exercise mail fallback.
	var spaces := p.bag_capacity() - p.bag_used()
	if not _check("redesign.mail.fixture_capacity", spaces >= 0, spaces):
		return "full-pack fixture over capacity"
	var filler := Items.make_potion("health", "instant", "F", "accord")
	for index in spaces: p.consumables.append(filler.duplicate(true))
	if not _check("redesign.mail.fixture_full", p.bag_used() == p.bag_capacity()
			and p.material_count("bone", "F") > int(Balance.CRAFT_MATERIAL_COST.F), _summary(p)):
		return "full-pack fixture not full with surviving material stack"
	var craft := await _action("craft")
	if craft.is_empty(): return "full-pack Craft unavailable"
	var expected := _expected("craft", p)
	var expected_item: Dictionary = expected.player.backpack.pop_back()
	var sent_after: int = g.trusted_now()
	_click_now(craft.button.get_global_rect().get_center())
	var sent_before: int = g.trusted_now()
	if not _check("redesign.mail.one_letter", g.mailbox.size() == 1, g.mailbox.size()):
		return "full-pack craft did not produce exactly one letter"
	var letter: Dictionary = g.mailbox[0]
	var stamp: int = int(letter.get("sent_at", -1))
	if not _check("redesign.mail.timestamp", stamp >= sent_after and stamp <= sent_before, stamp):
		return "full-pack letter timestamp outside action interval"
	expected.mail.append({"subject": "Your crafted gear",
		"body": "The bench was ready but your bag was full — the piece waits here.",
		"items": [{"kind": "item", "item": expected_item}], "sent_at": stamp, "read": false})
	if not _check("redesign.mail.exact", _ledger(p) == expected
			and p.bag_used() == p.bag_capacity(), _summary(p)):
		return "full-pack craft ledger or exact mailed payload mismatch"
	await r.frames(3)
	var notice := m.root.find_child("ProfResult", true, false) as Label
	await _capture("08_after_full_pack_mail")
	if not _check("redesign.mail.visible_result", notice != null and notice.is_visible_in_tree()
			and notice.text.contains("mailed") and notice.text.contains(Items.title(expected_item)),
			notice.text if notice != null else "missing"):
		return "full-pack result did not show crafted item and mailed destination"
	var shape: Dictionary = CaptionGeometry.shaped(notice)
	var cells: Rect2 = CaptionGeometry.to_rect(shape.cells)
	_check("redesign.mail.result_complete", shape.missing.is_empty() and int(shape.count) > 0
		and notice.visible_ratio >= 1.0 and notice.max_lines_visible == -1
		and notice.get_visible_line_count() == notice.get_line_count()
		and notice.get_global_rect().grow(0.5).encloses(cells)
		and m._shell_rect.grow(0.5).encloses(cells), shape)
	return ""


func _browse_lifetime_controls() -> String:
	# Ten controlled retirements of real browse signals, separate from the 46
	# transaction callbacks. Invalid identities never survive into a frame.
	for route in ["ProfTrade_tailor", "ProfTab_blueprints"]:
		for reason in ["owner", "world", "seed", "replaced_shell", "closed_shell"]:
			await _open_fixture()
			var id: String = "browse_lifetime." + route + "." + reason
			var button := m.root.find_child(route, true, false) as Button
			if not _check(id + ".control", button != null and button.is_visible_in_tree()
					and not button.disabled, route): return "browse control unavailable"
			var links := button.get_signal_connection_list("pressed")
			if not _check(id + ".connections", links.size() == 2, links.size()):
				return "browse signal layout changed"
			var callback: Callable = links[1].callable
			if not _check(id + ".callable", callback.is_valid(), route): return "browse callback invalid"
			var temporary: Node = null
			var owner: Player = p
			match reason:
				"owner":
					var replacement := Player.new()
					replacement.game = g
					replacement.process_mode = Node.PROCESS_MODE_DISABLED
					replacement.visible = false
					g.add_child(replacement)
					replacement.set_class(p.cls)
					_loan(replacement)
					g.player = replacement
					owner = replacement
					temporary = replacement
				"world":
					var replacement := Node2D.new()
					g.add_child(replacement)
					g.world = replacement
					temporary = replacement
				"seed": g.wander_seed += 1
				"replaced_shell": m.open_inventory()
				"closed_shell": m.close()
			var before := _ledger(owner)
			var original_before := _ledger(p)
			var destination: Control = m.root
			var destination_name := m.current
			callback.call()
			var rejected := _check(id + ".unchanged", _ledger(owner) == before
				and _ledger(p) == original_before and m.root == destination
				and m.current == destination_name, _summary(owner))
			g.player = p
			g.players = keep.registry.duplicate()
			g.world = keep.world
			g.wander_seed = int(keep.game.wander_seed)
			if temporary != null: temporary.queue_free()
			await r.frames(3)
			if not rejected: return "retired browse callback changed destination or economy"
	# Native browse starts the real deferred restore, then the destination is
	# replaced synchronously before its first await can resume. No focus loan.
	for replacement in [true, false]:
		await _open_fixture()
		var route := "ProfTrade_tailor" if replacement else "ProfTab_blueprints"
		var id := "deferred_focus." + ("inventory" if replacement else "closed")
		var button := m.root.find_child(route, true, false) as Button
		if not _check(id + ".control", button != null and button.is_visible_in_tree()
				and not button.disabled, route): return "deferred browse unavailable"
		var rect := button.get_global_rect()
		if not _check(id + ".click_inside", m._shell_rect.encloses(rect)
				and m.get_viewport().get_visible_rect().encloses(rect), str(rect)):
			return "deferred browse outside shell or viewport"
		var old_shell: Control = m.root
		var before := _ledger(p)
		_click_now(rect.get_center())
		if not _check(id + ".rebuilt", is_instance_valid(m.root) and m.root != old_shell, route):
			return "native browse did not rebuild the shell"
		var title := m.root.find_child("ProfTradeName", true, false) as Label
		var selected: bool = title != null and title.text == Professions.trade_name("tailor")
		if not replacement: selected = m.root.find_child("ProfLearn", true, false) != null
		if not _check(id + ".native_browse", selected
				and _ledger(p) == before, route): return "native browse did not rebuild requested view"
		var retired: WeakRef = weakref(m.root)
		if replacement: m.open_inventory()
		else: m.close()
		var destination: Control = m.root
		var destination_name := m.current
		await r.frames(4)
		var focus: Control = m.get_viewport().gui_get_focus_owner()
		var destination_focus := focus == null or (is_instance_valid(destination)
			and (focus == destination or destination.is_ancestor_of(focus)))
		if not _check(id + ".destination_kept", m.root == destination
				and m.current == destination_name and destination_name == ("inventory" if replacement else "")
				and _ledger(p) == before and retired.get_ref() == null and destination_focus,
				{"menu": m.current, "focus": str(focus.get_path()) if focus != null else "none",
				"retired_shell_released": retired.get_ref() == null}):
			return "retired deferred focus changed successor, focus or economy"
	return ""


func _action(action: String) -> Dictionary:
	var routes := {"lock": ["ProfTrade_blacksmith"],
		"craft": ["ProfTrade_alchemist", "ProfTab_craft", "ProfSlot_charm", "ProfGrade_F"],
		"learn": ["ProfTrade_alchemist", "ProfTab_blueprints", "ProfSlot_charm", "ProfBlueprintGrade_B"]}
	var names := {"lock": "ProfActivate", "craft": "ProfCraft", "learn": "ProfLearn"}
	if not routes.has(action): return {}
	for name: String in routes[action]:
		if not await _tap_named(name): return {}
	var button := m.root.find_child(String(names[action]), true, false) as Button
	if not _check("fixture.button.%s.%d" % [action, rows.size()], button != null
			and button.is_visible_in_tree() and not button.disabled, names[action]):
		return {}
	var rect := button.get_global_rect()
	if not _check("fixture.action_rect.%s.%d" % [action, rows.size()],
			m._shell_rect.grow(0.5).encloses(rect) and m.get_viewport().get_visible_rect().encloses(rect), str(rect)):
		return {}
	var links := button.get_signal_connection_list("pressed")
	if not _check("fixture.connections.%s.%d" % [action, rows.size()], links.size() == 2,
			{"text": button.text, "connections": links.size()}):
		return {}
	var retained: Callable = links[1].callable
	if not _check("fixture.callable.%s.%d" % [action, rows.size()], retained.is_valid(), button.text):
		return {}
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
			var record := await _action(action)
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
	var active := await _action("craft")
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
	var cross_error: String = await _cross_action()
	if cross_error != "": return cross_error
	var redesign_error: String = await _redesign_controls()
	if redesign_error != "": return redesign_error
	var trade_error: String = await _changed_trade_controls()
	if trade_error != "": return trade_error
	var mail_error: String = await _full_pack_mail()
	if mail_error != "": return mail_error
	return await _browse_lifetime_controls()


func _active_trade_caption(id: String) -> void:
	caption_probes += 1
	var trade_name := Professions.trade_name(p.profession)
	var title := m.root.find_child("ProfTradeName", true, false) as Label
	var rail := m.root.find_child("ProfTrade_" + p.profession, true, false) as Button
	var active: Array[Label] = []
	for candidate in m.root.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label != null and label.is_visible_in_tree() and label.text.ends_with(" · Active"):
			active.append(label)
	if not _check("caption.present." + id, title != null and rail != null and active.size() == 1,
			{"title": title != null, "rail": rail != null, "active_labels": active.size()}):
		return
	_check("caption.complete_text." + id, title.text == trade_name
		and active[0].text == trade_name + " · Active" and rail.is_ancestor_of(active[0]),
		{"title": title.text, "active": active[0].text, "trade": p.profession})
	for spec in [["title", title], ["active", active[0]]]:
		var label: Label = spec[1]
		var shape: Dictionary = CaptionGeometry.shaped(label)
		var bounds: Rect2 = CaptionGeometry.to_rect(shape.cells)
		var full: bool = shape.missing.is_empty() and int(shape.count) > 0 \
			and label.visible_ratio >= 1.0 and label.max_lines_visible == -1 \
			and label.lines_skipped == 0 and label.get_visible_line_count() == label.get_line_count()
		var contained: bool = label.get_global_rect().grow(0.5).encloses(bounds) \
			and m._shell_rect.grow(0.5).encloses(bounds) \
			and m.get_viewport().get_visible_rect().grow(0.5).encloses(bounds)
		if spec[0] == "active": contained = contained and rail.get_global_rect().grow(0.5).encloses(bounds)
		var ancestor := label.get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is Control and ancestor.clip_contents:
				contained = contained and ancestor.get_global_rect().grow(0.5).encloses(bounds)
			ancestor = ancestor.get_parent()
		_check("caption.readable.%s.%s" % [id, spec[0]], full and contained
			and label.is_visible_in_tree() and label.get_theme_font_size("font_size") >= 14,
			{"shape": shape, "full_text": full, "contained": contained})


func _retired(action: String, retirement: String) -> String:
	r.step("controlled retained %s callback after %s" % [action, retirement])
	await _open_fixture()
	var record := await _action(action)
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
	var record := await _action(action)
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
	r.step("native Learn after browsing retires a previously captured Craft callback")
	await _open_fixture()
	var craft := await _action("craft")
	if craft.is_empty(): return "cross-action native Craft unavailable"
	var old_craft: Callable = craft.callback
	var old_shell: WeakRef = weakref(craft.shell)
	craft.clear()  # Never carry an old Button/Control across native view replacement.
	var learn := await _action("learn")
	if learn.is_empty(): return "cross-action native Learn unavailable"
	var expected := _expected("learn", p)
	_click_now(learn.button.get_global_rect().get_center())
	if not _check("cross.first_learn_exact", _ledger(p) == expected, _summary(p)):
		return "cross-action Learn ledger mismatch"
	if not _check("cross.old_craft_callable", old_craft.is_valid() and old_shell.get_ref() == null,
			"old Craft shell released through native browse; only Callable retained"):
		return "cross-action retained Craft setup invalid"
	var destination: Control = m.root
	var before := _ledger(p)
	old_craft.call()
	callback_probes += 1
	_check("cross.second_action_rejected", _ledger(p) == before and m.root == destination
		and m.current == "professions", _summary(p), true)
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
		"fixture": "loaned capital resources; simulation frozen; actual native browsing/input, same-frame retirements and retained Craft Callable across tab replacement; no_saves; no actual online/travel/save or ordinary-click exploit claim"}
	for row in rows:
		if row.passed: result.passed += 1
		elif row.expected_baseline_finding: result.findings += 1
		else: result.failures += 1
	return result


## Fast art-direction pass before transaction acceptance. This deliberately
## records ordinary initial views only, with fixture loans and no spending.
static func preview(rig: ShotRig) -> Dictionary:
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
	var geometry_rows: Array = []
	var previews := [
		["alchemist", false, ["ProfGrade_A"], "master"],
		["alchemist", false, ["ProfGrade_F"], "ready"],
		["alchemist", false, ["ProfTab_blueprints", "ProfBlueprintGrade_B"], "blueprint"],
		["alchemist", false, ["ProfTrade_blacksmith"], "browse"],
		["blacksmith", false, [], "blacksmith"],
		["tailor", true, [], "tailor"],
		["", true, [], "novice"],
	]
	for spec in previews:
		await proof._open_fixture(bool(spec[1]))
		proof.p.profession = String(spec[0])
		proof.p.mastery = {"alchemist": 500, "blacksmith": 80, "tailor": 0}
		proof.m.open_professions()
		await rig.frames(5)
		var before := proof._ledger(proof.p)
		for control_name in spec[2]:
			var control := proof.m.root.find_child(String(control_name), true, false) as Button
			if not proof._check("preview.control." + String(spec[3]) + "." + String(control_name),
					control != null and not control.disabled, control_name):
				break
			if bool(spec[1]):
				await proof.native._touch(control.get_global_rect().get_center())
			else:
				await proof.native._mouse(control.get_global_rect().get_center())
			await rig.frames(4)
		proof._check("preview.open." + String(spec[3]), proof.m.current == "professions", String(spec[0]))
		proof._check("preview.no_spend." + String(spec[3]), proof._ledger(proof.p) == before, proof._summary(proof.p))
		var footer: Label = null
		for label in proof.m.root.find_children("*", "Label", true, false):
			if label.text == "ESC to close" or label.text == "Tap ✕ or outside to close":
				footer = label
		var geometry := preload("res://scripts/tests/professions_visual_geometry.gd").inspect(proof.m, footer)
		geometry_rows.append({"trade": spec[0], "touch": spec[1], "id": spec[3], "geometry": geometry})
		proof._check("preview.geometry." + String(spec[3]), bool(geometry.ok), geometry.violations)
		rig.shot("workshop_" + String(spec[3]),
			"Art-direction preview only; controlled mastery/resources and synthetic touch mode, no transaction acceptance")
	await proof._restore()
	var report := proof._report()
	report["geometry"] = geometry_rows
	report["scope"] = "Art-direction preview only. Seven controlled initial/browsed menu states; no transaction or visual acceptance until originals reviewed."
	return report
