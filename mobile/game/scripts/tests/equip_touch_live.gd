extends RefCounted
const GemArtProbe = preload("res://scripts/tests/gem_ui_art_probe.gd")
## Equipped-card TAP vs DRAG probe: Claude v2 plus Codex source-review corrections (2026-09-17).
## Lent legal gear; real viewport ScreenTouch/ScreenDrag + mouse input against
## the inventory's equipped item card. No earned-loot claim. Install at:
## game/scripts/tests/equip_touch_live.gd — invoked via shot_gems.gd
## --equip-touch [--baseline].
const EXPECTED := ["body_drag/opened"]
var r: ShotRig
var g: Game
var p: Player
var baseline := false
var report := {"checks": [], "findings": [], "failures": [], "views": [], "complete": false}
var rng := RandomNumberGenerator.new()


static func run(rig: ShotRig) -> String:
	var t := new()
	t.r = rig
	t.g = rig.game
	t.p = rig.game.local_player
	t.baseline = rig.flag("baseline")
	if not t.g.no_saves or t.g.net_online() or t.g.chapter_id != "capital" or t.g.dev_god:
		return "Equip touch fixture requires isolated no-save solo capital, without god mode"
	var original_equipment: Dictionary = t.p.equipment
	var original_gems: Array = t.p.gem_bag
	var old_equipment: Dictionary = original_equipment.duplicate(true)
	var old_gems: Array = original_gems.duplicate(true)
	var player_fields := t._stash(t.p, ["consumables", "hp", "mp", "gold", "global_position"])
	var game_fields := t._stash(t.g, ["flags", "achievements", "_meta", "_meta_loaded", "quest_key", "play_started", "state"])
	var old_touch: bool = t.g.touch_mode
	var old_emulation: bool = Input.emulate_mouse_from_touch
	var old_touch_from_mouse: bool = Input.emulate_touch_from_mouse
	var old_notice: String = t.g.menus.inventory_notice
	var old_physics: bool = t.p.is_physics_processing()
	var old_dir: String = rig.shot_dir
	rig.shot_dir = old_dir.path_join("equip_touch")
	t.rng.seed = 17092026
	t.report["scope"] = "Controlled capital visit; one legal B weapon with an added regular socket lent (rolled and reforged via Items.can_add_socket/add_socket, not earned), plus legal production-rolled supporting gear lent into the six remaining slots (controlled loans, each asserted equip_error-legal) so the compacted no-empty-slot column still exceeds one page. Real ScreenTouch/ScreenDrag and mouse events through the viewport; the production gesture code is never called directly. touch_mode, emulate_mouse_from_touch and emulate_touch_from_mouse are forced for the touch scenarios (host touchscreen capability via emulate_touch_from_mouse) and restored after. The shell-replacement scenario rebuilds the inventory programmatically between press and release, standing in for any external refresh; no physical-device or visual-acceptance claim."
	# Host drag capability: ScrollContainer touch panning needs a touchscreen;
	# emulate_touch_from_mouse provides one on desktop (skills_touch_live's
	# established pattern). Merely forcing g.touch_mode does not.
	Input.emulate_touch_from_mouse = true
	t.p.set_physics_process(false)
	var error: String = await t._exercise()
	Input.emulate_mouse_from_touch = old_emulation
	Input.emulate_touch_from_mouse = old_touch_from_mouse
	t.g.touch_mode = old_touch
	t.g.menus.close()
	t.g.request_pause(false)
	t.p.equipment = original_equipment
	t.p.gem_bag = original_gems
	t._restore(t.g, game_fields)
	t._restore(t.p, player_fields)
	t.p.recalc()
	t.p.hp = float(player_fields.hp)
	t.p.mp = float(player_fields.mp)
	t.p._update_weapon_visual()
	t.g.menus.inventory_notice = old_notice
	t.p.set_physics_process(old_physics)
	await rig.frames(3)
	t._check("cleanup/owned_inventory", is_same(t.p.equipment, original_equipment)
		and is_same(t.p.gem_bag, original_gems) and t.p.equipment == old_equipment and t.p.gem_bag == old_gems)
	t._check("cleanup/progression", t.g.flags == game_fields.flags and t.g.achievements == game_fields.achievements
		and t.g._meta == game_fields._meta and t.g._meta_loaded == game_fields._meta_loaded
		and t.p.gold == player_fields.gold and t.p.consumables == player_fields.consumables)
	t._check("cleanup/input_mode", t.g.touch_mode == old_touch
		and Input.emulate_mouse_from_touch == old_emulation
		and Input.emulate_touch_from_mouse == old_touch_from_mouse)
	var expected: Array = EXPECTED.duplicate() if t.baseline else []
	t._check("baseline/exact", t.report.findings == expected, {"expected": expected, "actual": t.report.findings})
	if error != "": t._check("fixture", false, {"error": error})
	t.report.complete = error == ""
	t.report["baseline"] = t.baseline
	var output := ProjectSettings.globalize_path(rig.shot_dir.path_join("report.json"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: return "Cannot write equip touch receipt"
	file.store_string(JSON.stringify(t.report, "\t"))
	file.close()
	rig.shot_dir = old_dir
	print("EQUIP TOUCH: ", output, " checks=", t.report.checks.size(), " findings=", t.report.findings.size(), " failures=", t.report.failures.size())
	return "" if t.report.complete and t.report.failures.is_empty() else "Equipped-card touch probe failed"


func _exercise() -> String:
	_check("capital/actual_world", g.chapter_id == "capital" and g.world != null and g.play_started
		and g.state == Game.ST_PLAYING and not g.hud.dialogue_active and not g.hud.choices_active)
	if not DisplayServer.is_touchscreen_available():
		return "Host reports no touchscreen despite emulate_touch_from_mouse"
	var item := _seed()
	if item.is_empty(): return "Could not prepare legal 2-socket weapon"
	g.touch_mode = true
	Input.emulate_mouse_from_touch = true  # production mobile default
	await _open()
	if _body_point(item).x < 0: return "Equipped card body label not on screen"
	var scroll := _scroll_of(item)
	if scroll == null: return "Equipped card has no ScrollContainer ancestor"
	# Positive scroll range is a hard setup gate — the drag control is
	# meaningless without it, and the offset requirement is never waived.
	if scroll.get_v_scroll_bar() == null \
			or scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page:
		return "Inventory column has no scroll range for the drag control"
	_check("setup/scrollable", true,
		{"max": scroll.get_v_scroll_bar().max_value, "page": scroll.get_v_scroll_bar().page})
	if not baseline: GemArtProbe.inspect(self, "touch_stack", item)
	# 1) Short body tap opens the item panel ONCE (emulated-mouse stream).
	if not await _tap_opens(item, "tap/body_emulated"): return "Body tap (mouse emulation) did not open the item panel once"
	await _capture("01_tap_open")
	if not await _dismiss_card(): return "Item panel did not dismiss back to inventory"
	# 2) Raw-touch fallback tap (emulation off). The popover overlay handles
	# MouseButton only, so emulation is restored BEFORE dismissing (the same
	# order gem_synthesis_caps_live uses).
	Input.emulate_mouse_from_touch = false
	var raw_opened := await _tap_opens(item, "tap/body_raw")
	Input.emulate_mouse_from_touch = true
	if not raw_opened: return "Body tap (raw touch) did not open the item panel once"
	if not await _dismiss_card(): return "Raw item panel did not dismiss back to inventory"
	# 3) THE DEFECT PROBE: a vertical drag starting on the card body must scroll
	# the list without opening Info or touching gear. Baseline whitelists the
	# anticipated open (findings) but stays strict on any gear mutation.
	await _drag_probe(item)
	await _capture("02_after_body_drag")
	# 4) Socket regressions (checkpoint behavior must survive the fix).
	await _open()
	if not await _socket_card(): return "Filled socket detail unavailable"
	await _capture("03_socket_card")
	await _open()
	if not await _empty_socket_card(): return "Empty socket did not open Gems content"
	# The empty-socket detail popover is still open here and would intercept
	# input — reopen the inventory before the actual socket drag.
	await _open()
	if not await _socket_scroll(): return "Socket drag did not preserve inventory scrolling"
	# 5) Strict-only gesture edges (on unfixed source these would merely
	# re-observe open-on-press; baseline whitelists body_drag/opened only).
	if not baseline:
		await _gesture_edges(item)
		# Cancellation, production emulation ON: the raw stream of finger 0
		# carries `canceled` to the armed record.
		await _open()
		var before := _state()
		var at := _body_point(item)
		_touch(0, at, true)
		await r.frames(2)
		_touch_canceled(0, at)
		await r.frames(3)
		_check("cancel/no_open", g.menus.current == "inventory"
			and not is_instance_valid(g.menus.detail_popover) and _state() == before,
			{"current": g.menus.current})
		# Multi-pointer, production emulation ON, second finger OFF-card and
		# elsewhere on screen: any other finger voids the tap.
		await _open()
		before = _state()
		at = _body_point(item)
		_touch(0, at, true)
		await r.frames(1)
		_touch(1, Vector2(1200, 650), true)
		await r.frames(1)
		_touch(1, Vector2(1200, 650), false)
		await r.frames(1)
		_touch(0, at, false)
		await r.frames(3)
		_check("multi/no_open", g.menus.current == "inventory"
			and not is_instance_valid(g.menus.detail_popover) and _state() == before,
			{"current": g.menus.current})
		# Shell replaced between press and release, SAME FRAME: the old card is
		# still alive (its shell only queued for deletion), so this exercises
		# the root-identity guard, not just is_instance_valid. Controlled
		# programmatic rebuild stands in for any external refresh.
		await _open()
		at = _body_point(item)
		_touch(0, at, true)
		g.menus.open_inventory("gear", "gems")
		var before_same := _state()
		_touch(0, at, false)
		await r.frames(3)
		_check("shell/same_frame_release_inert", g.menus.current == "inventory"
			and not is_instance_valid(g.menus.detail_popover) and _state() == before_same,
			{"current": g.menus.current})
		# And the freed-card variant: release only after the old shell is gone.
		await _open()
		at = _body_point(item)
		_touch(0, at, true)
		await r.frames(1)
		g.menus.open_inventory("gear", "gems")
		await r.frames(3)
		var before_freed := _state()
		_touch(0, at, false)
		await r.frames(3)
		_check("shell/freed_release_inert", g.menus.current == "inventory"
			and not is_instance_valid(g.menus.detail_popover) and _state() == before_freed,
			{"current": g.menus.current})
		await _capture("04_after_stale_release")
	# 6) Desktop mouse click still opens (press path unchanged off touch).
	g.touch_mode = false
	Input.emulate_touch_from_mouse = false # ordinary desktop; mixed mode is tested separately
	Input.emulate_mouse_from_touch = false
	await _open()
	var desktop_opened := await _tap_opens(item, "desktop/click")
	Input.emulate_mouse_from_touch = true
	if not desktop_opened: return "Desktop click did not open the item panel once"
	if not await _dismiss_card(): return "Desktop item panel did not dismiss"
	g.touch_mode = true
	Input.emulate_touch_from_mouse = true
	return ""


func _gesture_edges(item: Dictionary) -> void:
	# Real nonzero primary IDs, both emulation settings, both release orders.
	# Both pointers start ON the same body: a canceled gesture cannot re-arm
	# from the second GUI press after global observation invalidated it.
	for emulate in [true, false]:
		Input.emulate_mouse_from_touch = emulate
		for primary_first in [true, false]:
			await _open()
			var shell: Control = g.menus.root
			var before := _state()
			var at := _body_point(item)
			var second := at + Vector2(12, 0)
			var id := "multi/emulation_%s/primary_first_%s" % [emulate, primary_first]
			_touch(3, at, true)
			await r.frames(1)
			_touch(7, second, true)
			await r.frames(1)
			_check(id + "/held", _inert(shell, before))
			_touch(3 if primary_first else 7, at if primary_first else second, false)
			await r.frames(1)
			_check(id + "/one_left", _inert(shell, before))
			_touch(7 if primary_first else 3, second if primary_first else at, false)
			await r.frames(3)
			_check(id + "/all_lifted", _inert(shell, before))
		# An unknown canceled event is already released in Godot. It cannot
		# open a card or poison the next genuinely fresh nonzero-ID gesture.
		await _open()
		var shell: Control = g.menus.root
		var before := _state()
		var at := _body_point(item)
		_touch_canceled(3, at, true)
		await r.frames(1)
		_check("cancel/unknown_inert_%s" % emulate, _inert(shell, before))
		var fresh: bool = await _tap_opens(item, "tap/fresh_after_cancel_%s" % emulate, 7)
		Input.emulate_mouse_from_touch = true
		if fresh:
			_check("tap/fresh_dismiss_%s" % emulate, await _dismiss_card())
		# Cancel a REAL held primary while another REAL contact remains.
		# That remaining finger must not become a new card tap on release.
		Input.emulate_mouse_from_touch = emulate
		await _open()
		shell = g.menus.root
		before = _state()
		at = _body_point(item)
		_touch(3, at, true)
		await r.frames(1)
		_touch(7, at + Vector2(12, 0), true)
		await r.frames(1)
		_touch_canceled(3, at)
		await r.frames(1)
		_check("cancel/other_held_%s" % emulate, _inert(shell, before))
		_touch(7, at + Vector2(12, 0), false)
		await r.frames(3)
		_check("cancel/all_lifted_%s" % emulate, _inert(shell, before))
		var recovered: bool = await _tap_opens(item, "tap/nonzero_recovered_%s" % emulate, 3)
		# Overlay dismissal is MouseButton-only; restore emulation first.
		Input.emulate_mouse_from_touch = true
		if recovered:
			_check("tap/nonzero_dismiss_%s" % emulate, await _dismiss_card())
	# Physical mouse remains usable with the touch layout and BOTH emulation
	# flags enabled. Generated touch must not suppress or duplicate its open.
	if await _tap_opens(item, "mouse/touch_layout", 0, true):
		_check("mouse/touch_layout_dismiss", await _dismiss_card())


func _inert(shell: Variant, before: Dictionary) -> bool:
	return is_instance_valid(shell) and g.menus.root == shell and g.menus.current == "inventory" \
		and not is_instance_valid(g.menus.detail_popover) and _state() == before


func _seed() -> Dictionary:
	g.menus.close()
	g.request_pause(false)
	p.equipment = {}
	p.gem_bag = [Items.make_gem("magpen", 1)]  # inert sentinel keeps gem UI present
	var item := Items.roll_item_of("weapon", "B", rng, p.cls)
	# Lent reforged gear: B rolls exactly one socket; a legal extra socket
	# supplies an empty regular control beside the filled regular socket.
	if not Items.can_add_socket(item): return {}
	Items.add_socket(item)
	if int(item.get("gem_slots", 0)) != 2: return {}
	p.equipment["weapon"] = item
	p.gem_bag.append(Items.make_gem("atk_flat", 2))
	if not p.embed_gem_into(item, p.gem_bag.back()): return {}
	# Compact empty rows now fit without scrolling. Fill the other slots with
	# legal controlled loans so real equipped-card drags still have overflow.
	# run() restores the original equipment dictionary on every exit.
	var support_errors := {}
	for slot: String in Items.SLOTS:
		if slot == "weapon": continue
		var support: Dictionary = Items.roll_item_of(slot, "B", rng, p.cls)
		if support.is_empty(): return {}
		var err: String = p.equip_error(support)
		if err != "": support_errors[slot] = err
		p.equipment[slot] = support
	var supports_legal: bool = support_errors.is_empty() and p.equipment.size() == 7
	_check("setup/support_legal", supports_legal,
		{"errors": support_errors, "slots": p.equipment.keys()})
	if not supports_legal: return {}
	for i in 18: p.gem_bag.append(Items.make_gem("hp_flat", 1))  # scroll range
	p.recalc()
	p._update_weapon_visual()
	_check("setup/legal_gear", p.equip_error(item) == "" and item.gems.size() == 1
		and int(item.get("gem_slots", 0)) >= 2, _state())
	return item


func _open() -> void:
	g.menus.open_inventory("gear", "gems")
	await r.frames(6)
	await RenderingServer.frame_post_draw


func _body_point(item: Dictionary) -> Vector2:
	# The item's name label center: on the card body, left of the socket HBox.
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text == Items.title(item):
			if not g.get_viewport_rect().encloses(label.get_global_rect()): return Vector2(-1, -1)
			return label.get_global_rect().get_center()
	return Vector2(-1, -1)


func _scroll_of(item: Dictionary) -> ScrollContainer:
	for raw in g.menus.root.find_children("*", "Label", true, false):
		var label := raw as Label
		if label.is_visible_in_tree() and label.text == Items.title(item):
			var parent: Node = label.get_parent()
			while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
			return parent as ScrollContainer
	return null


func _tap_opens(item: Dictionary, id: String, pointer := 0, mouse := false) -> bool:
	await _open()
	var at := _body_point(item)
	if at.x < 0: return false
	var before := _state()
	var added: Array[int] = []
	var observe := func(child: Node) -> void:
		if child is Control: added.append(child.get_instance_id())
	g.menus.child_entered_tree.connect(observe)
	await _tap(at, pointer, mouse)
	g.menus.child_entered_tree.disconnect(observe)
	# Current open_item_panel rebuilds the direct menu shell once. Count actual
	# additions too: two opens may leave only one surviving Unequip button.
	# Opens ONCE: exactly one item panel (one Unequip action), not stacked.
	var unequips := 0
	if is_instance_valid(g.menus.root):
		for raw in g.menus.root.find_children("*", "Button", true, false):
			var button := raw as Button
			if button.is_visible_in_tree() and button.text.contains("Unequip  (move to bag)"): unequips += 1
	var good := unequips == 1 and added.size() == 1 and g.menus.current == "detail" and _state() == before
	_check(id, good, {"at": str(at), "mouse_emulation": Input.emulate_mouse_from_touch,
		"touch_mode": g.touch_mode, "pointer": pointer, "physical_mouse": mouse or not g.touch_mode,
		"mouse_override": mouse, "touch_from_mouse": Input.emulate_touch_from_mouse,
		"current": g.menus.current, "unequips": unequips, "new_shells": added.size()})
	return good


func _drag_probe(item: Dictionary) -> void:
	await _open()
	var at := _body_point(item)
	var scroll := _scroll_of(item)
	var offset: int = scroll.scroll_vertical if scroll != null else -1
	var before := _state()
	var shell: Control = g.menus.root
	_touch(0, at, true)
	await r.frames(1)
	var opened: bool = g.menus.current != "inventory" or g.menus.root != shell
	for i in 4:
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = at - Vector2(0, 16); drag.relative = Vector2(0, -16)
		Input.parse_input_event(drag); Input.flush_buffered_events()
		at = drag.position
		await r.frames(1)
	_touch(0, at, false)
	await r.frames(4)
	opened = opened or g.menus.current != "inventory" or g.menus.root != shell \
		or is_instance_valid(g.menus.detail_popover)
	if baseline and opened and _state() == before:
		report.findings.append("body_drag/opened")  # the one anticipated defect
		return
	var after: int = scroll.scroll_vertical if is_instance_valid(scroll) else -1
	_check("body_drag/no_open", not opened, {"current": g.menus.current})
	_check("body_drag/scrolled", after > offset, {"before": offset, "after": after})
	_check("body_drag/unchanged", _state() == before, {"before": before, "after": _state()})


func _socket_card() -> bool:
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.contains("Select for its card"):
			if not g.get_viewport_rect().encloses(button.get_global_rect()): return false
			at = button.get_global_rect().get_center()
			break
	if at.x < 0: return false
	var before := _state()
	await _tap(at)
	var found := false
	if is_instance_valid(g.menus.root):
		for candidate in g.menus.root.find_children("*", "Button", true, false):
			var action := candidate as Button
			if action.is_visible_in_tree() and action.text.contains("Remove  (back to bag)"): found = true
	var good := found and _state() == before
	_check("socket/filled_card", good, {"at": str(at), "found": found, "current": g.menus.current})
	return good


func _empty_socket_card() -> bool:
	var at := Vector2(-1, -1)
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.begins_with("Empty "):
			at = button.get_global_rect().get_center()
			break
	if at.x < 0: return false
	var before := _state()
	await _tap(at)
	# Distinguish the GEMS detail from a wrong item-Info open: the capital
	# empty-socket page leads with the Lapidary line (the same source-proven
	# indicator gem_synthesis_caps_live asserts). Equipped-item header keeps
	# its one Unequip action on every tab; that action alone is not an Info test.
	var gems_content := false
	var unequips := 0
	if is_instance_valid(g.menus.root):
		for raw in g.menus.root.find_children("*", "Label", true, false):
			var label := raw as Label
			if label.is_visible_in_tree() and label.text.begins_with("The Lapidary counts you"): gems_content = true
		for raw in g.menus.root.find_children("*", "Button", true, false):
			var button := raw as Button
			if button.is_visible_in_tree() and button.text.contains("Unequip  (move to bag)"): unequips += 1
	await _capture("04_empty_socket_gems")
	var good := gems_content and unequips == 1 and g.menus.current == "detail" and _state() == before
	_check("socket/empty_card_gems", good, {"at": str(at), "gems_content": gems_content,
		"unequips": unequips, "current": g.menus.current})
	return good


func _socket_scroll() -> bool:
	var socket: Button = null
	for raw in g.menus.root.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.is_visible_in_tree() and button.tooltip_text.contains("Select for its card"):
			socket = button
			break
	if socket == null: return false
	var parent: Node = socket.get_parent()
	while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
	if parent == null: return false
	var scroll := parent as ScrollContainer
	var offset := scroll.scroll_vertical
	var before := _state()
	var at := socket.get_global_rect().get_center()
	_touch(0, at, true)
	await r.frames(1)
	for i in 4:
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = at - Vector2(0, 16); drag.relative = Vector2(0, -16)
		Input.parse_input_event(drag); Input.flush_buffered_events()
		at = drag.position
		await r.frames(1)
	_touch(0, at, false)
	await r.frames(4)
	var good := is_instance_valid(scroll) and g.menus.current == "inventory" \
		and not is_instance_valid(g.menus.detail_popover) and _state() == before
	var after: int = scroll.scroll_vertical if is_instance_valid(scroll) else -1
	good = good and after > offset
	_check("socket/drag_scroll", good, {"before": offset, "after": after, "current": g.menus.current})
	return good


func _dismiss_card() -> bool:
	# MouseButton-only overlay: callers restore mouse emulation before this.
	var before := _state()
	var box: Rect2 = g.menus._popover_box.get_global_rect()
	var at := Vector2(-1, -1)
	for candidate in [Vector2(580, 600), Vector2(1100, 600), Vector2(580, 180), Vector2(1100, 180)]:
		if not box.has_point(candidate):
			at = candidate
			break
	if at.x < 0: return false
	await _tap(at)
	return g.menus.current == "inventory" and is_instance_valid(g.menus.root) \
		and not is_instance_valid(g.menus.detail_popover) and _state() == before


func _touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch_canceled(index: int, at: Vector2, down := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	event.canceled = true
	var observed := {"requested_pressed": down, "pressed_getter": event.pressed,
		"is_pressed": event.is_pressed(), "canceled": event.canceled,
		"contacts_before": g.menus._card_contacts.keys()}
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	observed["contacts_after"] = g.menus._card_contacts.keys()
	observed["blocked_after"] = g.menus._card_touch_blocked
	if not report.has("cancel_inputs"): report["cancel_inputs"] = []
	report.cancel_inputs.append(observed)


func _tap(at: Vector2, pointer := 0, mouse := false) -> void:
	var use_touch: bool = g.touch_mode and not mouse
	if not use_touch:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
	for down in [true, false]:
		if use_touch:
			_touch(pointer, at, down)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = at
			event.global_position = at
			event.pressed = down
			Input.parse_input_event(event)
			Input.flush_buffered_events()
		await r.frames(2)
	await r.frames(4)


func _state() -> Dictionary:
	var bag := {}
	for gem in p.gem_bag:
		var key := "%s/%d" % [gem.stat, int(gem.lvl)]
		bag[key] = int(bag.get(key, 0)) + 1
	return {"equipment": p.equipment.duplicate(true), "bag": bag, "atk": p.atk, "max_hp": p.max_hp}


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	report.views.append({"name": label, "path": r.shot(label), "state": _state()})


func _check(id: String, good: bool, data := {}) -> void:
	report.checks.append({"id": id, "ok": good, "data": data})
	if not good: report.failures.append(id)


func _stash(object: Object, fields: Array) -> Dictionary:
	var result := {}
	for key in fields:
		var value: Variant = object.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _restore(object: Object, values: Dictionary) -> void:
	for key in values: object.set(key, values[key])
