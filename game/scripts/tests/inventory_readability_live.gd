extends RefCounted
## Controlled factory loans, real GUI actions, and strict observations.
## DeepSeek proposed the scenarios; Codex replaced rejected non-executable drafts.
const GearCare := preload("res://scripts/gear_care.gd")
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const Geo := preload("res://scripts/tests/hud_alignment_geometry.gd")
const MaterialProbe := preload("res://scripts/tests/material_ui_live.gd")
const POCKETS := ["gold", "equipment", "backpack", "gem_bag", "materials", "consumables", "bags", "loose_bags", "potion_rotation"]
const FILTERS := ["All", "Weapons", "Helmets", "Armor", "Gloves", "Pants", "Boots", "Charms", "Gems", "Consumables", "Materials", "Bags"]
const VIEWS := ["00_empty_slots", "01_occupied_top", "02_occupied_bottom", "03_dense_grid_bottom", "04_filters_and_actions", "05_material_cancel", "06_material_remaining", "07_material_removed", "08_narrow_summary"]
const GALLERY := ["08_named_bag_card", "09_worn_card", "10_stats_paperdoll", "11_stats_detail"]
var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native = Native.new()
var art = MaterialProbe.new()
var rows: Array = []
var views: Array = []
var gestures: Array = []
var reach_runs: Array = []
var owned_pickups: Array = []
var timings: Array = []
var equipment_frames: Dictionary = {}

static func run(rig: ShotRig) -> Dictionary:
	var q := new()
	q.r = rig; q.g = rig.game; q.m = rig.game.menus; q.p = rig.game.local_player
	q.native.r = rig; q.native.g = q.g; q.native.m = q.m
	if not q._check("setup.isolated", q.g.no_saves and not q.g.net_online() and q.g.chapter_id == "capital"
			and not q.m.is_open() and not rig.get_tree().paused, "fresh solo capital, closed menus"):
		return q._report()
	# No ambient pickup callbacks can pay during the loans. A nonempty scene fails setup.
	var ambient: Array = []
	for n in q.g.get_children():
		if n is Pickup or n is Chest: ambient.append(n.get_instance_id())
	if not q._check("setup.no_ambient_rewards", ambient.is_empty(), ambient): return q._report()
	var saved: Dictionary = q._ledger()
	var drops: Array = q.g.dropped_loot.duplicate(true)
	var settings: Dictionary = q.g.settings.duplicate(true)
	var lang: String = Loc.lang
	var proc: bool = q.g.is_processing()
	var physics: bool = q.p.is_physics_processing()
	var emulate: bool = Input.emulate_mouse_from_touch
	var touch_from_mouse: bool = Input.emulate_touch_from_mouse
	var ui: Array = [q.m.inv_cat, q.m.inventory_order, q.m.inventory_notice]
	q.g.set_process(false); q.p.set_physics_process(false)
	Loc.lang = "en"; Input.emulate_mouse_from_touch = true
	# Desktop ScrollContainer panning needs host touch capability, as in equip_touch_live.
	# Raw ScreenTouch/ScreenDrag remain the asserted input; this is not a wheel fallback.
	if rig.flag("touch"): Input.emulate_touch_from_mouse = true
	q.g.settings["touch_controls"] = rig.flag("touch")
	q.g.refresh_touch_mode(); q.g._apply_touch_mode()
	q.m.inventory_order = "found"; q.m.inventory_notice = ""
	var error: String = await q._exercise()
	q._check("runtime.completed", error == "", error)
	# Inspect all produced rewards before removing only this run's witnessed nodes.
	var remaining: Array = q._pickups()
	q._check("cleanup.only_owned_pickups", remaining == q.owned_pickups, {"actual": remaining, "owned": q.owned_pickups})
	for id in q.owned_pickups:
		var node: Node = instance_from_id(int(id)) as Node
		if is_instance_valid(node): node.queue_free()
	await rig.frames(2)
	q._check("cleanup.pickups_removed", q._pickups().is_empty(), q._pickups())
	q.g.dropped_loot = drops
	for key in POCKETS: q.p.set(key, saved[key])
	q.g.mailbox = saved.mailbox; q.g.loot_rng.seed = int(saved.rng[0]); q.g.loot_rng.state = int(saved.rng[1])
	q._check("cleanup.ledger_restored", q._ledger() == saved, q._ledger())
	q.m.close()
	q.m.inv_cat = ui[0]; q.m.inventory_order = ui[1]; q.m.inventory_notice = ui[2]
	q.g.settings = settings; Loc.lang = lang; Input.emulate_mouse_from_touch = emulate
	Input.emulate_touch_from_mouse = touch_from_mouse
	q.g.refresh_touch_mode(); q.g._apply_touch_mode()
	q.g.set_process(proc); q.p.set_physics_process(physics)
	q._check("cleanup.modes", q.g.settings == settings and Loc.lang == lang
		and q.g.is_processing() == proc and q.p.is_physics_processing() == physics
		and Input.emulate_mouse_from_touch == emulate and Input.emulate_touch_from_mouse == touch_from_mouse
		and not q.m.is_open() and not rig.get_tree().paused)
	var expected_views: Array = VIEWS.duplicate()
	if rig.flag("gear-fidelity"): expected_views.append_array(GALLERY)
	q._check("captures.exact", q.views == expected_views, {"expected": expected_views, "actual": q.views})
	return q._report()

func _exercise() -> String:
	if not _check("setup.touch_capability", not g.touch_mode or DisplayServer.is_touchscreen_available(),
			{"touch_mode": g.touch_mode, "touchscreen": DisplayServer.is_touchscreen_available(),
			"touch_from_mouse": Input.emulate_touch_from_mouse, "mouse_from_touch": Input.emulate_mouse_from_touch}):
		return "Touch fixture requires host touchscreen capability"
	p.gold = 1234567  # Controlled display loan; existing POCKETS restore and ledger checks retain ownership.
	var rng := RandomNumberGenerator.new(); rng.seed = 20260920
	p.equipment = {}; p.backpack = []; p.gem_bag = []; p.consumables = []; p.materials = []; p.loose_bags = []
	p.bags = []; p.potion_rotation = []
	for i in Balance.MAX_BAGS: p.bags.append(Items.make_bag("S"))
	await _open("all")
	var money_title: Label = _label(m.root, "Inventory — 1,234,567 gold")
	_check("readability.gold.grouped", money_title != null and _visible(money_title),
		{"expected": "Inventory — 1,234,567 gold", "gold": p.gold})
	var previous_y := -INF
	for slot in Items.SLOTS:
		var label: Label = _label(m.root, String(slot).capitalize() + " — empty")
		if not _check("empty." + slot + ".present", label != null): return "missing empty equipment row"
		var card: Control = _panel(label)
		_check("empty." + slot + ".size_order", card != null and card.size.y >= (44.0 if g.touch_mode else 36.0)
			and card.global_position.y > previous_y, Geo.rect(card.get_global_rect()) if card != null else [])
		previous_y = card.global_position.y if card != null else previous_y
		if not await _reach(card): return "empty slot cannot be reached: " + slot
		_readability_label(label, "readability.empty." + slot, 14)
	await _open("all")
	await _capture(VIEWS[0])
	for i in Items.SLOTS.size():
		var slot: String = Items.SLOTS[i]
		p.equipment[slot] = Items.roll_item_of(slot, "F" if i % 2 == 0 else "S", rng, "warrior")
	# Controlled narrow summary: four stats and all three socket columns.
	p.equipment.weapon.main = {"atk_flat": 12.0}
	p.equipment.weapon.subs = {"crit": 0.12, "hp_flat": 1234.0, "physres": 24.0}
	p.equipment.weapon.gem_slots = 3
	p.equipment.weapon.gems = []
	p.equipment.weapon.passive = "kingsblade"
	await _open("all", true)
	await _capture(VIEWS[1])
	var primary: Color = Color.TRANSPARENT
	for slot in Items.SLOTS:
		var label: Label = _label(m.root, Items.title(p.equipment[slot]))
		if not _check("occupied." + slot + ".present", label != null): return "missing occupied row"
		var card: Control = _panel(label)
		if not _check("occupied." + slot + ".target", card != null and card.size.y >= (44.0 if g.touch_mode else 36.0)):
			return "occupied equipment row too short"
		if not await _reach(card): return "occupied slot cannot be reached: " + slot
		var color: Color = label.get_theme_color("font_color")
		if primary == Color.TRANSPARENT: primary = color
		_check("occupied." + slot + ".primary", color.is_equal_approx(primary) and _contrast(color) >= 4.5
			and label.get_theme_font_size("font_size") >= 14, {"color": str(color), "grade": p.equipment[slot].grade,
			"contrast": _contrast(color), "rect": Geo.rect(label.get_global_rect()), "text": label.text,
			"ellipsis_allowed": label.clip_text})
		_probe_equipped_icon(card, p.equipment[slot], "occupied." + slot)
		_readability_equipped(card, p.equipment[slot], "readability.equipped." + slot)
	await _capture(VIEWS[2])
	# Legal dense bag, with a real last cell that must become reachable by input.
	p.materials = [Items.make_material("bone", "F", 2)]
	p.gem_bag = [Items.make_gem("atk_flat", 1)]
	p.consumables = [Items.make_gift_health_potion()]
	while p.bag_used() < p.bag_capacity():
		var index: int = p.backpack.size()
		p.backpack.append(Items.roll_item_of(Items.SLOTS[index % 7], "F" if index % 2 == 0 else "S", rng, "warrior"))
	_check("setup.legal_capacity", p.bag_used() == p.bag_capacity(), {"used": p.bag_used(), "capacity": p.bag_capacity()})
	var dense: Dictionary = _ledger()
	await _open("all")
	var material: Button = _material()
	if not _check("grid.material_cell", material != null): return "material missing in dense grid"
	var grid: Node = material.get_parent()
	var last: Control = grid.get_child(grid.get_child_count() - 1) as Control
	var scroll: ScrollContainer = _scroll(last)
	if not _check("grid.requires_scroll", scroll != null and not _visible(last), Geo.rect(last.get_global_rect())):
		return "dense fixture does not require scrolling"
	if not await _reach(last): return "last grid cell unreachable"
	_check("grid.scroll_moved", scroll.scroll_vertical > 0 and _visible(last), {"offset": scroll.scroll_vertical, "last": Geo.rect(last.get_global_rect())})
	await _capture(VIEWS[3])
	await _open("all")
	var first: Dictionary = p.backpack[0]
	var second: Dictionary = p.backpack[1]
	for item in [first, second]:
		# Patched bag cells carry codex icons, so the old Art.icon_for texture
		# selector cannot find them; select by the tooltip's first (title) line.
		var cell: Button = _gear_button(m.root, item, false)
		if not _check("accent." + item.grade + ".cell", cell != null): return "grade cell missing"
		var style: StyleBoxFlat = cell.get_theme_stylebox("normal") as StyleBoxFlat
		_check("accent." + item.grade + ".preserved", style != null and style.border_color.is_equal_approx(Color(Items.GRADE_COLOR[item.grade], 0.9)))
	# Codex fidelity probes: backpack indices 0..6 (one per Items.SLOTS from the
	# roll cycle) plus the last GEAR cell — the grid's true last child is a
	# material and stays with the reach gesture above. inventory_order is forced
	# to "found" on the All view, so the first p.backpack.size() grid children
	# are gear; each probe still guards Button type and title before pixels.
	# Hidden cells keep full texture/geometry checks without a redundant scroll.
	var gear_grid: GridContainer = _grid()
	if not _check("grid.reacquired", gear_grid != null): return "bag grid unavailable"
	var probes: Array = []
	for i in mini(Items.SLOTS.size(), p.backpack.size()): probes.append(i)
	var last_gear: int = p.backpack.size() - 1
	if last_gear >= 0 and not probes.has(last_gear): probes.append(last_gear)
	for index in probes:
		var probe_error: String = _probe_gear_cell(gear_grid, int(index), p.backpack[int(index)])
		if probe_error != "": return probe_error
	if not await _click(native._find_button(m.root, "Materials", true), "filter.materials"): return "Materials unavailable"
	# Negative selector scans the LIVE rebuilt tree; the pre-click grid is freed.
	_check("filter.materials_hides_gear", _gear_button(m.root, first, false) == null and _material() != null)
	_check("filter.materials_no_spend", _ledger() == dense)
	if not await _click(native._find_button(m.root, "All", true), "filter.all"): return "All unavailable"
	_check("filter.all_restores_gear", _gear_button(m.root, first, false) != null)
	_check("filter.all_no_spend", _ledger() == dense)
	var filter_band := Rect2()
	for text in FILTERS:
		var button: Button = native._find_button(m.root, text, true)
		if not _check("filter." + text + ".present", button != null): return "filter missing"
		var rect: Rect2 = button.get_global_rect()
		_check("filter." + text + ".target", _visible(button) and m._shell_rect.grow(0.5).encloses(rect) and rect.size.y >= (44.0 if g.touch_mode else 28.0)
			and (not g.touch_mode or rect.size.x >= 44), Geo.rect(rect))
		filter_band = rect if not filter_band.has_area() else filter_band.merge(rect)
	for text in ["Auto-synthesize", "Order:", "Auto-equip"]:
		var button: Button = native._find_button(m.root, text)
		if not _check("action." + text + ".present", button != null): return "toolbar action missing"
		_check("action." + text + ".separate", _visible(button) and m._shell_rect.grow(0.5).encloses(button.get_global_rect()) and not filter_band.intersects(button.get_global_rect())
			and button.global_position.y >= filter_band.end.y, {"filter_band": Geo.rect(filter_band), "button": Geo.rect(button.get_global_rect())})
		_check("action." + text + ".target", button.size.y >= (44.0 if g.touch_mode else 28.0) and (not g.touch_mode or button.size.x >= 44))
	_readability_bag()
	await _capture(VIEWS[4])
	if not await _click(native._find_button(m.root, "Materials", true), "cancel.filter"): return "cancel filter failed"
	if not await _click(_material(), "cancel.material"): return "material open failed"
	if not _popover(2, "cancel"): return "material popover unavailable"
	await _capture(VIEWS[5])
	var cancel_before: Dictionary = _ledger()
	var cancel_drops: Array = g.dropped_loot.duplicate(true)
	# Overlay input, inside Inventory shell but outside the actual popover.
	var outside: Vector2 = m._shell_rect.position + Vector2(5, 5)
	if not _check("cancel.outside_point", not m._popover_box.get_global_rect().has_point(outside)): return "outside point covered"
	await _tap(outside)
	_check("cancel.dismissed", m.current == "inventory" and not is_instance_valid(m.detail_popover))
	_check("cancel.no_spend", _ledger() == cancel_before and g.dropped_loot == cancel_drops and _pickups().is_empty())
	for count in [2, 1]:
		if not await _click(_material(), "drop%d.material" % count): return "Drop material unreachable"
		if not _popover(count, "drop%d" % count): return "Drop detail missing"
		var before: Dictionary = _ledger()
		var expected: Dictionary = before.duplicate(true)
		expected.materials = [Items.make_material("bone", "F", 1)] if count == 2 else []
		var used: int = p.bag_used()
		var drops_before: Array = g.dropped_loot.duplicate(true)
		var nodes_before: Array = _pickups()
		if not await _click(native._find_button(m.detail_popover, "Drop one"), "drop%d.action" % count): return "Drop action unreachable"
		var now: Array = _pickups()
		var added: Array = []
		for id in now:
			if not nodes_before.has(id): added.append(id); owned_pickups.append(id)
		var payload_ok: bool = added.size() == 1 and g.dropped_loot.size() == drops_before.size() + 1
		if payload_ok:
			var node: Pickup = instance_from_id(int(added[0])) as Pickup
			var payload: Dictionary = g.dropped_loot.back()
			payload_ok = node != null and node.loot == payload and not node.claimed and payload.get("kind") == "material" \
				and payload.get("family") == "bone" and payload.get("grade") == "F" and int(payload.get("count", 0)) == 1
			for i in drops_before.size(): payload_ok = payload_ok and g.dropped_loot[i] == drops_before[i]
		_check("drop%d.exact_ledger" % count, _ledger() == expected, {"expected": expected, "actual": _ledger()})
		_check("drop%d.capacity" % count, p.bag_used() == used - (1 if count == 1 else 0), {"before": used, "after": p.bag_used()})
		_check("drop%d.actual_pickup" % count, payload_ok, {"ids": added, "dropped_loot": g.dropped_loot})
		_check("drop%d.menu_paused" % count, m.current == "inventory" and r.get_tree().paused)
		if count == 2:
			if not await _click(_material(), "remaining.detail"): return "remaining detail unavailable"
			_popover(1, "remaining")
			await _capture(VIEWS[6])
			await _tap(m._shell_rect.position + Vector2(5, 5))
		else: await _capture(VIEWS[7])
	await _narrow_summary()
	if r.flag("gear-fidelity"):
		var gallery_error: String = await _gallery(rng)
		if gallery_error != "": return gallery_error
	return ""

## Optional focused gallery (rig --gear-fidelity): one named unique loaned from
## the real Items.UNIQUES table, browsed read-only through bag card, worn card,
## Stats paperdoll and its detail. Fixture placement is direct and disclosed;
## no equip/spend ACTION runs and no stat recalc — HP/MP and sheet stay as-is.
func _gallery(rng: RandomNumberGenerator) -> String:
	var spec: Dictionary = {}
	for u in Items.UNIQUES:
		if String(u.get("cls", "")) == "warrior" and String(u.get("slot", "")) == "weapon" and String(u.get("art", "")) != "":
			spec = u
			break
	if not _check("gallery.unique_spec", not spec.is_empty(), spec): return "no warrior weapon unique with art"
	var unique: Dictionary = Items.make_unique(spec, rng)
	if not _check("gallery.unique_metadata", String(unique.get("name", "")) == String(spec.name)
			and String(unique.get("art", "")) == String(spec.art) and String(unique.get("art", "")) != ""
			and String(unique.get("slot", "")) == "weapon" and String(unique.get("grade", "")) == String(spec.grade),
			{"spec": spec, "item": {"name": unique.get("name", ""), "art": unique.get("art", ""),
			"grade": unique.get("grade", ""), "noun": unique.get("noun", "")}}):
		return "make_unique metadata mismatch"
	var expected: Texture2D = _codex_icon(unique)
	var explicit: Texture2D = Art.codex_item_icon("weapon", String(spec.grade), String(unique.get("noun", "")), String(spec.art))
	if not _check("gallery.codex_128", expected != null and expected.get_width() == 128 and expected.get_height() == 128
			and _same_pixels(expected, explicit), {"size": _tex_size(expected)}):
		return "unique codex icon invalid"
	var master_path: String = "res://assets/icons/codex/%s.png" % String(spec.art)
	# Compare the imported authored resource; Godot applies alpha-border fixup
	# during import, so raw PNG bytes are not the renderer's source pixels.
	var master_texture: Texture2D = load(master_path) if ResourceLoader.exists(master_path) else null
	var master: Image = master_texture.get_image() if master_texture != null else null
	var actual: Image = expected.get_image()
	if not _check("gallery.authored_master", master != null and actual != null
			and master.get_size() == Vector2i(128, 128) and actual.get_size() == master.get_size()
			and actual.get_format() == master.get_format() and actual.get_data() == master.get_data(), master_path):
		return "unique UI did not use its authored master"
	var family: Texture2D = Art.codex_item_icon("weapon", String(spec.grade), String(unique.get("noun", "")), "")
	if not _check("gallery.distinct_from_family", not _same_pixels(expected, family), String(spec.art)):
		return "unique fixture does not distinguish its own art from the family"
	var checkpoint: Dictionary = _ledger()
	var worn_before: Dictionary = p.equipment["weapon"]
	# Direct fixture placement, disclosed: the loan enters the bag without any
	# pickup, purchase, or reward path; the material's freed slot holds it.
	p.backpack.append(unique)
	await _open("all")
	var cell: Button = _gear_button(m.root, unique, false)
	if not _check("gallery.bag_cell", cell != null): return "unique bag cell not found"
	_check("gallery.bag_cell_pixels", _same_pixels(cell.icon, expected), {"actual": _tex_size(cell.icon)})
	if not await _click(cell, "gallery.bag_open"): return "unique bag card unreachable"
	if not _check("gallery.bag_card_open", is_instance_valid(m.detail_popover)
			and _label(m.detail_popover, Items.title(unique)) != null): return "unique bag card did not open"
	_probe_header(m.detail_popover, expected, "gallery.bag_header")
	await _capture(GALLERY[0])
	if not await _dismiss("gallery.bag_card"): return "bag card dismissal failed"
	# Scoped equipment assignment (no equip action). run() restores all pockets
	# from the pre-run ledger even if a later step aborts mid-loan.
	p.backpack.erase(unique)
	p.equipment["weapon"] = unique
	await _open("all")
	var label: Label = _label(m.root, Items.title(unique))
	if not _check("gallery.worn_row", label != null): return "worn unique row missing"
	var card: Control = _panel(label)
	if card == null or not await _reach(card): return "worn unique row unreachable"
	_probe_equipped_icon(card, unique, "gallery.worn")
	# The name label ignores mouse, so the tap lands on the card, not a socket.
	await _tap(label.get_global_rect().get_center())
	if not _check("gallery.worn_card_open", is_instance_valid(m.detail_popover)
			and _label(m.detail_popover, Items.title(unique)) != null): return "worn card did not open"
	_probe_header(m.detail_popover, expected, "gallery.worn_header")
	await _capture(GALLERY[1])
	if not await _dismiss("gallery.worn_card"): return "worn card dismissal failed"
	if not await _click(native._find_button(m.root, "Stats"), "gallery.stats_tab"): return "Stats tab unavailable"
	var well: Panel = _paperdoll_well(Items.title(unique))
	if not _check("gallery.paperdoll_well", well != null, Items.title(unique)): return "paperdoll well missing"
	var icon: TextureRect = null
	for child in well.get_children():
		if child is TextureRect: icon = child as TextureRect
	if not _check("gallery.paperdoll_icon", icon != null and icon.texture != null): return "paperdoll icon missing"
	_check("gallery.paperdoll_pixels", _same_pixels(icon.texture, expected), {"actual": _tex_size(icon.texture)})
	_check("gallery.paperdoll_linear", icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, {"filter": icon.texture_filter})
	_check("gallery.paperdoll_geometry_44_36", well.size.is_equal_approx(Vector2(44, 44))
		and icon.size.is_equal_approx(Vector2(36, 36)) and icon.position.is_equal_approx(Vector2(4, 4))
		and well.get_global_rect().grow(0.5).encloses(icon.get_global_rect()),
		{"well": Geo.rect(well.get_global_rect()), "icon": Geo.rect(icon.get_global_rect())})
	await _capture(GALLERY[2])
	await _tap(well.get_global_rect().get_center())
	if not _check("gallery.detail_open", is_instance_valid(m.detail_popover)
			and _label(m.detail_popover, Items.title(unique)) != null): return "paperdoll detail did not open"
	_probe_header(m.detail_popover, expected, "gallery.detail_header")
	await _capture(GALLERY[3])
	if not await _dismiss("gallery.detail"): return "detail dismissal failed"
	p.equipment["weapon"] = worn_before
	if not _check("gallery.loan_restored", _ledger() == checkpoint, {"gold": p.gold}): return "gallery loan not restored"
	return ""

## Codex fidelity for one indexed bag gear cell. Hidden cells are probed too:
## geometry and textures are laid out regardless of the scroll offset, and the
## dense last-cell gesture already proved reachability once.
func _probe_gear_cell(grid: GridContainer, index: int, item: Dictionary) -> String:
	var tag: String = "bag.gear%d" % index
	var meta: Dictionary = {"slot": item.get("slot", ""), "grade": item.get("grade", ""),
		"noun": item.get("noun", ""), "art": item.get("art", "")}
	if not _check(tag + ".button", is_instance_valid(grid) and index >= 0 and index < grid.get_child_count()
			and grid.get_child(index) is Button, {"index": index, "meta": meta}):
		return "gear cell missing at index %d" % index
	var cell: Button = grid.get_child(index) as Button
	var line: String = _title_line(item)
	if not _check(tag + ".title_guard", cell.tooltip_text.get_slice("\n", 0) == line,
			{"expected": line, "tooltip": cell.tooltip_text}):
		return "gear cell identity mismatch at index %d" % index
	var expected: Texture2D = _codex_icon(item)
	_check(tag + ".codex_128", expected != null and expected.get_width() == 128 and expected.get_height() == 128,
		{"size": _tex_size(expected), "meta": meta})
	_check(tag + ".icon_pixels", _same_pixels(cell.icon, expected),
		{"actual": _tex_size(cell.icon), "expected": _tex_size(expected), "meta": meta})
	_check(tag + ".filter_linear", cell.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, {"filter": cell.texture_filter})
	var rect: Rect2 = cell.get_global_rect()
	_check(tag + ".cell_48", cell.custom_minimum_size == Vector2(48, 48)
		and is_equal_approx(rect.size.x, 48.0) and is_equal_approx(rect.size.y, 48.0),
		{"rect": Geo.rect(rect), "visible": _visible(cell)})
	var world: Texture2D = Art.icon_for(item)
	_check(tag + ".world_resolver", world != null and world.get_width() == world.get_height()
		and (world.get_width() == 32 or world.get_width() == 42) and not _same_pixels(world, expected),
		{"world": _tex_size(world), "meta": meta})
	return ""

## Equipped-row fidelity. The TextureRect is selected by the 46px icon well,
## NOT by texture size — an unpatched 32/42 world texture is still found and
## its actual dimensions become the recorded old-art diagnostic.
func _probe_equipped_icon(card: Control, item: Dictionary, prefix: String) -> void:
	var meta: Dictionary = {"slot": item.get("slot", ""), "grade": item.get("grade", ""),
		"noun": item.get("noun", ""), "art": item.get("art", "")}
	var icon: TextureRect = _equipped_icon(card)
	if not _check(prefix + ".well_icon", icon != null and icon.texture != null, meta): return
	var expected: Texture2D = _codex_icon(item)
	_check(prefix + ".codex_128", expected != null and expected.get_width() == 128 and expected.get_height() == 128,
		{"size": _tex_size(expected), "meta": meta})
	_check(prefix + ".icon_pixels", _same_pixels(icon.texture, expected),
		{"actual": _tex_size(icon.texture), "expected": _tex_size(expected), "meta": meta})
	_check(prefix + ".filter_linear", icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, {"filter": icon.texture_filter})
	var well: Control = icon.get_parent() as Control
	var well_rect: Rect2 = well.get_global_rect()
	var icon_rect: Rect2 = icon.get_global_rect()
	_check(prefix + ".geometry_46_38", is_equal_approx(well_rect.size.x, 46.0) and is_equal_approx(well_rect.size.y, 46.0)
		and is_equal_approx(icon_rect.size.x, 38.0) and is_equal_approx(icon_rect.size.y, 38.0)
		and well_rect.grow(0.5).encloses(icon_rect),
		{"well": Geo.rect(well_rect), "icon": Geo.rect(icon_rect)})
	var world: Texture2D = Art.icon_for(item)
	_check(prefix + ".world_resolver", world != null and world.get_width() == world.get_height()
		and (world.get_width() == 32 or world.get_width() == 42),
		{"world": _tex_size(world), "meta": meta})

## Popover header icon: 40px, LINEAR, codex pixels.
func _probe_header(root: Node, expected: Texture2D, prefix: String) -> void:
	var icon: TextureRect = _header_icon(root)
	if not _check(prefix + ".present", icon != null and icon.texture != null): return
	_check(prefix + ".pixels", _same_pixels(icon.texture, expected), {"actual": _tex_size(icon.texture)})
	_check(prefix + ".linear", icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, {"filter": icon.texture_filter})
	_check(prefix + ".geometry_40", icon.size.is_equal_approx(Vector2(40, 40)), Geo.rect(icon.get_global_rect()))

func _dismiss(prefix: String) -> bool:
	var outside: Vector2 = m._shell_rect.position + Vector2(5, 5)
	if not _check(prefix + ".outside_point", is_instance_valid(m._popover_box)
			and not m._popover_box.get_global_rect().has_point(outside),
			Geo.rect(m._popover_box.get_global_rect()) if is_instance_valid(m._popover_box) else []):
		return false
	await _tap(outside)
	return _check(prefix + ".dismissed", not is_instance_valid(m.detail_popover))

func _popover(count: int, prefix: String) -> bool:
	if not _check(prefix + ".open", is_instance_valid(m.detail_popover) and is_instance_valid(m._popover_box)): return false
	var title: String = "%s  x%d" % [Items.MATERIALS.bone.F, count]
	var label: Label = _label(m.detail_popover, title)
	if not _check(prefix + ".title", label != null): return false
	var shape: Dictionary = Geo.shaped(label)
	_check(prefix + ".full_text", shape.missing.is_empty() and int(shape.count) > 0
		and label.get_global_rect().grow(0.5).encloses(Geo.to_rect(shape.cells)) and _visible(label)
		and label.get_visible_line_count() == label.get_line_count(), shape)
	_check(prefix + ".primary", _contrast(label.get_theme_color("font_color")) >= 4.5,
		{"color": str(label.get_theme_color("font_color")), "contrast": _contrast(label.get_theme_color("font_color"))})
	var text: String = "Drop places one unit on the ground. The slot is freed only after the last unit leaves this stack."
	var prose: Label = null
	for node in m.detail_popover.find_children("*", "Label", true, false):
		if node.text.contains(text): prose = node
	_check(prefix + ".honest_copy", prose != null)
	if prose != null:
		var body: Dictionary = Geo.shaped(prose)
		_check(prefix + ".copy_contained", body.missing.is_empty() and int(body.count) > 0
			and _visible(prose) and prose.get_global_rect().grow(0.5).encloses(Geo.to_rect(body.cells)), body)
	_check(prefix + ".viewport", _visible(m._popover_box), Geo.rect(m._popover_box.get_global_rect()))
	return true

func _open(category: String, observe_equipment: bool = false) -> void:
	var start: int = Time.get_ticks_usec()
	m.open_inventory("gear", category)
	var dispatched: int = Time.get_ticks_usec()
	if observe_equipment:
		await RenderingServer.frame_post_draw
		equipment_frames.first = _readability_frame()
	await r.frames(4)
	if observe_equipment:
		await RenderingServer.frame_post_draw
		equipment_frames.settled = _readability_frame()
		_readability_frame_checks(equipment_frames.first, equipment_frames.settled)
	# Diagnostic samples only — no invented thresholds; root holds the baseline.
	timings.append({"category": category, "bag_count": p.bag_used(), "gear_count": p.backpack.size(),
		"dispatch_usec": dispatched - start, "settled_usec": Time.get_ticks_usec() - start})

func _material() -> Button:
	return art._texture_control(m.root, Art.material_ui_icon("bone", "F"), true) as Button

## Mirrors the production _gear_codex_icon exactly: all four resolver args,
## read-only on the dictionary — dropping the art key or noun would reroute a
## named piece onto its grade family and hide exactly the bug hunted here.
func _codex_icon(item: Dictionary) -> Texture2D:
	return Art.codex_item_icon(String(item.get("slot", "")), String(item.get("grade", "F")),
		String(item.get("noun", "")), String(item.get("art", "")))

func _title_line(item: Dictionary) -> String:
	return Items.title(item) + (" · Kept" if GearCare.kept(item) else "")

## Live-tree gear button selector: first tooltip line is title (+ Kept flag);
## optional byte-equal icon pixels. Never holds refs across a rebuild — the
## codex cache (256 entries) also makes texture-reference matching unreliable.
func _gear_button(root: Node, item: Dictionary, require_pixels: bool) -> Button:
	var line: String = _title_line(item)
	var expected: Texture2D = _codex_icon(item)
	for node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or button.tooltip_text.get_slice("\n", 0) != line: continue
		if require_pixels and not _same_pixels(button.icon, expected): continue
		return button
	return null

func _grid() -> GridContainer:
	var material: Button = _material()
	if material == null: return null
	return material.get_parent() as GridContainer

func _equipped_icon(card: Control) -> TextureRect:
	for node in card.find_children("*", "Panel", true, false):
		var well: Panel = node as Panel
		if well == null or not well.custom_minimum_size.is_equal_approx(Vector2(46, 46)): continue
		for child in well.get_children():
			if child is TextureRect: return child as TextureRect
	return null

func _header_icon(root: Node) -> TextureRect:
	for node in root.find_children("*", "TextureRect", true, false):
		var rect: TextureRect = node as TextureRect
		if rect != null and rect.custom_minimum_size.is_equal_approx(Vector2(40, 40)): return rect
	return null

func _paperdoll_well(title: String) -> Panel:
	for node in m.root.find_children("*", "Panel", true, false):
		var well: Panel = node as Panel
		if well != null and well.tooltip_text == title: return well
	return null

## Byte equality of actual pixel data, guarded by dimensions and format. Both
## sides come from live textures, never cached references.
func _same_pixels(a: Texture2D, b: Texture2D) -> bool:
	if a == null or b == null: return false
	if a == b: return true
	var ia: Image = a.get_image()
	var ib: Image = b.get_image()
	if ia == null or ib == null: return false
	if ia.get_width() != ib.get_width() or ia.get_height() != ib.get_height() or ia.get_format() != ib.get_format(): return false
	return ia.get_data() == ib.get_data()

func _tex_size(texture: Texture2D) -> Array:
	return [texture.get_width(), texture.get_height()] if texture != null else [0, 0]

func _label(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node.text == text: return node as Label
	return null

func _panel(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node != null:
		if node is PanelContainer: return node as Control
		node = node.get_parent()
	return null

func _scroll(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: return node as ScrollContainer
		node = node.get_parent()
	return null

func _visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var rect: Rect2 = control.get_global_rect()
	var clip: Rect2 = r.get_viewport().get_visible_rect()
	var node: Node = control.get_parent()
	while node != null:
		if node is Control and node.clip_contents: clip = clip.intersection(node.get_global_rect())
		node = node.get_parent()
	return rect.has_area() and clip.grow(0.5).encloses(rect)

func _reach(control: Control) -> bool:
	if not is_instance_valid(control): return false
	if _visible(control): return true
	var scroll: ScrollContainer = _scroll(control)
	if not is_instance_valid(scroll) or scroll.size.y < 48: return false
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var page: float = bar.page
	var span: float = maxf(0.0, bar.max_value - bar.min_value - page)
	if page <= 0.0 or span <= 0.0: return false
	# Godot wheel input advances page/8. Derive a full-range budget instead of
	# assuming 36 events can reach the bottom of a 450-cell factory fixture.
	# Touch gets a conservative half-drag estimate; neither path writes scroll.
	var step_size: float = minf(192.0, scroll.size.y * 0.6) * 0.5 if g.touch_mode else page / 8.0
	var budget: int = clampi(ceili(span / maxf(1.0, step_size)) * 2 + 8, 8, 512)
	var started: int = Time.get_ticks_msec()
	var stalled: int = 0
	var observation: Dictionary = {"touch": g.touch_mode, "page": page, "span": span,
		"estimated_step": step_size, "budget": budget, "attempts": 0, "elapsed_ms": 0,
		"reason": "budget_exhausted", "visible": false}
	reach_runs.append(observation)
	for attempt in budget:
		observation.elapsed_ms = Time.get_ticks_msec() - started
		if not is_instance_valid(control) or not is_instance_valid(scroll):
			observation.reason = "control_replaced"
			return false
		if _visible(control):
			observation.reason = "visible"; observation.visible = true
			return true
		if int(observation.elapsed_ms) >= 30000:
			observation.reason = "time_limit"
			return false
		var before: int = scroll.scroll_vertical
		var box: Rect2 = scroll.get_global_rect()
		var up: bool = control.global_position.y < box.position.y
		if g.touch_mode:
			var distance: float = minf(192.0, box.size.y * 0.6)
			var at: Vector2 = Vector2(box.position.x + 8, box.position.y + box.size.y * (0.2 if up else 0.8))
			var event := InputEventScreenTouch.new()
			event.index = 0; event.position = at; event.pressed = true
			Input.parse_input_event(event); Input.flush_buffered_events()
			await r.frames(1)
			for step in 8:
				var drag := InputEventScreenDrag.new()
				drag.index = 0; drag.relative = Vector2(0, distance / 8.0 * (1 if up else -1)); drag.position = at + drag.relative
				Input.parse_input_event(drag); Input.flush_buffered_events(); at = drag.position
				await r.frames(1)
			event = InputEventScreenTouch.new(); event.index = 0; event.position = at; event.pressed = false
			Input.parse_input_event(event); Input.flush_buffered_events()
			await r.frames(4)
		else: await native._wheel(MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, box.get_center())
		observation.attempts = attempt + 1
		observation.elapsed_ms = Time.get_ticks_msec() - started
		if not is_instance_valid(control) or not is_instance_valid(scroll):
			observation.reason = "control_replaced"
			return false
		var progress: int = (before - scroll.scroll_vertical) if up else (scroll.scroll_vertical - before)
		stalled = stalled + 1 if progress <= 0 else 0
		gestures.append({"touch": g.touch_mode, "before": before, "after": scroll.scroll_vertical,
			"progress": progress, "target": Geo.rect(control.get_global_rect())})
		if _visible(control):
			observation.reason = "visible"; observation.visible = true
			return true
		if stalled >= 3:
			observation.reason = "three_nonprogress_events"
			return false
	return false

func _click(button: Button, id: String) -> bool:
	if not _check(id + ".enabled", is_instance_valid(button) and not button.disabled): return false
	if not _check(id + ".reachable", await _reach(button)): return false
	await _tap(button.get_global_rect().get_center())
	return true

func _tap(at: Vector2) -> void:
	if g.touch_mode: await native._touch(at)
	else: await native._mouse(at)
	await r.frames(4)

func _capture(id: String) -> void:
	await r.frames(2)
	await RenderingServer.frame_post_draw
	r.shot(id)
	views.append(id)

func _ledger() -> Dictionary:
	var result := {}
	for key in POCKETS:
		var value: Variant = p.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	result.mailbox = g.mailbox.duplicate(true); result.rng = [g.loot_rng.seed, g.loot_rng.state]
	return result

func _pickups() -> Array:
	var ids: Array = []
	for node in g.get_children():
		if node is Pickup and not node.is_queued_for_deletion(): ids.append(node.get_instance_id())
	return ids

func _contrast(color: Color) -> float:
	var light: Color = color.srgb_to_linear()
	var dark: Color = Color(0.10, 0.09, 0.13).srgb_to_linear()
	return (light.get_luminance() + 0.05) / (dark.get_luminance() + 0.05)

func _check(id: String, ok: bool, actual: Variant = null) -> bool:
	rows.append({"id": id, "passed": ok, "actual": actual})
	return ok

## Actual DeepSeek draft, independently corrected: TextLine.add_string is bool,
## summaries wrap, repeated bag chips must be distinct, and reached rows are
## inspected before another native gesture moves them outside the viewport.
func _readability_label(label: Label, prefix: String, floor_px: int, full: bool = true) -> void:
	if not _check(prefix + ".present", is_instance_valid(label)): return
	_check(prefix + ".font", label.get_theme_font_size("font_size") >= floor_px,
		{"text": label.text, "actual": label.get_theme_font_size("font_size"), "minimum": floor_px})
	_check(prefix + ".visible", _visible(label), Geo.rect(label.get_global_rect()))
	if not full: return  # Names retain exact data but authored visual ellipsis is allowed.
	var shape: Dictionary = Geo.shaped(label)
	_check(prefix + ".complete", not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
		and label.visible_ratio >= 1.0 and label.max_lines_visible == -1
		and label.get_line_count() == label.get_visible_line_count()
		and shape.missing.is_empty() and int(shape.count) > 0, shape)
	_check(prefix + ".cells", label.get_global_rect().grow(0.5).encloses(Geo.to_rect(shape.cells)), shape)

func _readability_equipped(card: Control, item: Dictionary, prefix: String) -> void:
	var expected: String = Items.describe(item, false, true)
	var summary: Label = _label(card, expected)
	# Keep the native geometry oracle usable against the old ordinary-space UI.
	if summary == null: summary = _label(card, Items.describe(item, false))
	var name_label: Label = _label(card, Items.title(item))
	_readability_label(name_label, prefix + ".name", 16, false)
	_readability_label(summary, prefix + ".summary", 14)
	_check(prefix + ".exact_summary", summary != null and summary.text == expected,
		{"expected": expected, "actual": summary.text if summary != null else ""})
	if summary == null or name_label == null: return
	var shape: Dictionary = Geo.shaped(summary)
	_summary_tokens(summary, item, prefix)
	var cells: Rect2 = Geo.to_rect(shape.cells)
	var card_rect: Rect2 = card.get_global_rect()
	_check(prefix + ".summary_in_card", card_rect.grow(0.5).encloses(cells), {"card": Geo.rect(card_rect), "cells": shape.cells})
	_check(prefix + ".name_summary_clear", not name_label.get_global_rect().intersects(cells),
		{"name": Geo.rect(name_label.get_global_rect()), "summary": shape.cells})
	var sockets: Array = card.find_children("*", "Button", true, false)
	_check(prefix + ".socket_count", sockets.size() == int(item.get("gem_slots", 0)),
		{"expected": item.get("gem_slots", 0), "actual": sockets.size()})
	for i in sockets.size():
		var socket: Button = sockets[i] as Button
		var rect: Rect2 = socket.get_global_rect()
		_check(prefix + ".socket%d_attached" % i, _visible(socket) and card_rect.grow(0.5).encloses(rect)
			and not rect.intersects(cells) and not rect.intersects(name_label.get_global_rect()),
			{"socket": Geo.rect(rect), "card": Geo.rect(card_rect), "summary": shape.cells,
			"name": Geo.rect(name_label.get_global_rect())})
	var icon: TextureRect = _equipped_icon(card)
	_check(prefix + ".icon_clear", icon != null and not icon.get_global_rect().intersects(cells)
		and not icon.get_global_rect().intersects(name_label.get_global_rect()),
		{"icon": Geo.rect(icon.get_global_rect()) if icon != null else [], "summary": shape.cells})

func _readability_button(button: Button, prefix: String) -> void:
	if not _check(prefix + ".present", is_instance_valid(button)): return
	var font_px: int = button.get_theme_font_size("font_size")
	var line := TextLine.new()
	line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var added: bool = line.add_string(button.text, button.get_theme_font("font"), font_px, button.language)
	var style: StyleBox = button.get_theme_stylebox("normal")
	var margins := Vector2(style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
		style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))
	var need: Vector2 = line.get_size() + margins
	_check(prefix + ".font", font_px >= 14, {"text": button.text, "actual": font_px, "minimum": 14})
	_check(prefix + ".native_text_fits", added and not button.text.is_empty() and button.icon == null
		and button.size.x + 0.5 >= need.x and button.size.y + 0.5 >= need.y and _visible(button),
		{"text": button.text, "native_need": [need.x, need.y], "rect": Geo.rect(button.get_global_rect()),
		"added": added, "font": font_px})

## Desktop can allocate extra width. Exercise the production row at its
## authored minimum separately, keeping the ordinary full-screen checks intact.
func _narrow_summary() -> void:
	await _open("all")
	var fixture := VBoxContainer.new()
	fixture.position = m._shell_rect.position + Vector2(580, 160)
	m.root.add_child(fixture)
	m._equipped_row(fixture, "weapon", "all")
	await r.frames(4)
	var card := fixture.get_child(0) as Control
	_readability_equipped(card, p.equipment.weapon, "readability.narrow")
	await _capture(VIEWS[8])
	fixture.free()

## Glyph cells, not string formatting, prove each stat/value occupies one line.
func _summary_tokens(summary: Label, item: Dictionary, prefix: String) -> void:
	var plain := summary.text.replace("\u00a0", " ")
	var stats_text := Items.describe(item, false).split("  ")[0]
	var offset := 0
	for token: String in stats_text.split(", "):
		var start := plain.find(token, offset)
		var top := -INF
		var together := start >= 0
		if start >= 0:
			for index in range(start, start + token.length()):
				if plain.substr(index, 1) == " ": continue
				var cell := summary.get_character_bounds(index)
				if top == -INF: top = cell.position.y
				together = together and cell.has_area() and is_equal_approx(cell.position.y, top)
			offset = start + token.length()
		_check(prefix + ".token." + token, together, {"token": token, "shape": Geo.shaped(summary)})
	_check(prefix + ".plain_copy_preserved", plain == Items.describe(item, false))
	if item.has("passive"):
		var star := plain.find("\u2605 ")
		_check(prefix + ".passive_marker_bound", star >= 0 and is_equal_approx(
			summary.get_character_bounds(star).position.y, summary.get_character_bounds(star + 2).position.y))
	if prefix == "readability.narrow":
		_check(prefix + ".narrow_wrap_fixture", int(item.gem_slots) == 3 and Items.stats_of(item).size() >= 4
			and summary.get_line_count() > 1 and summary.size.x <= 146.0, Geo.shaped(summary))
		# Paired native negative control: the same width/font with old spaces
		# must split HP from its value, so this fixture cannot pass vacuously.
		var old := Label.new()
		old.text = Items.describe(item, false)
		old.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		old.add_theme_font_override("font", summary.get_theme_font("font"))
		old.add_theme_font_size_override("font_size", summary.get_theme_font_size("font_size"))
		old.visible = false
		summary.add_child(old)
		old.size = Vector2(summary.size.x, 0.0)
		old.size.y = old.get_minimum_size().y
		var hp := old.text.find("HP +")
		_check(prefix + ".old_spaces_split_control", hp >= 0 and not is_equal_approx(
			old.get_character_bounds(hp).position.y, old.get_character_bounds(hp + 3).position.y), Geo.shaped(old))
		old.free()

func _readability_bag() -> void:
	_readability_label(_label(m.root, "%d / %d slots" % [p.bag_used(), p.bag_capacity()]), "readability.bag.capacity", 14)
	_readability_label(_label(m.root, "%d/%d bags" % [p.bags.size(), Balance.MAX_BAGS]), "readability.bag.count", 14)
	var used: Array = []
	for i in p.bags.size():
		var bag: Dictionary = p.bags[i]
		var expected: String = "%s · %d slots" % [String(bag.get("grade", "F")), int(bag.get("slots", 0))]
		var found: Label = null
		for node in m.root.find_children("*", "Label", true, false):
			if node.text == expected and not used.has(node.get_instance_id()):
				found = node as Label
				break
		if found != null: used.append(found.get_instance_id())
		_readability_label(found, "readability.bag.chip%d" % i, 14)
		var chip: Control = _panel(found) if found != null else null
		_check("readability.bag.chip%d.touch_target" % i, chip != null and (not g.touch_mode
			or (chip.size.x >= 44.0 and chip.size.y >= 44.0)),
			{"touch": g.touch_mode, "rect": Geo.rect(chip.get_global_rect()) if chip != null else []})
	_check("readability.bag.distinct_chips", used.size() == p.bags.size(), {"ids": used, "expected": p.bags.size()})
	for text in FILTERS:
		_readability_button(native._find_button(m.root, text, true), "readability.filter." + text)
	for text in ["Auto-synthesize", "Order:", "Auto-equip"]:
		_readability_button(native._find_button(m.root, text), "readability.action." + text)

## First post-draw and settled observations of the SAME occupied shell. Local
## rectangles exclude the existing outer shell-entry scale animation. Offscreen
## rows are layout observations here; _readability_equipped proves viewport and
## clipping-ancestor clearance only after the existing real input reaches them.
func _readability_frame() -> Dictionary:
	var result := {}
	for slot in Items.SLOTS:
		var item: Dictionary = p.equipment[slot]
		var title: Label = _label(m.root, Items.title(item))
		if title == null: result[slot] = {"missing": "title"}; continue
		var card: Control = _panel(title)
		var summary: Label = _label(card, Items.describe(item, false, true)) if card != null else null
		if card == null or summary == null: result[slot] = {"missing": "card_or_summary"}; continue
		result[slot] = {"card": Geo.rect(Rect2(card.position, card.size)),
			"name": Geo.rect(Rect2(title.position, title.size)), "text": summary.text,
			"summary": Geo.rect(Rect2(summary.position, summary.size)),
			"font": summary.get_theme_font_size("font_size"), "lines": summary.get_line_count(),
			"visible_lines": summary.get_visible_line_count(), "shape": Geo.shaped(summary)}
	return result

func _readability_frame_checks(first: Dictionary, settled: Dictionary) -> void:
	for slot in Items.SLOTS:
		var a: Dictionary = first.get(slot, {})
		var b: Dictionary = settled.get(slot, {})
		var complete: bool = not a.has("missing") and not b.has("missing") and a.has("card") and b.has("card")
		_check("readability.frame." + slot + ".present", complete, {"first": a, "settled": b})
		if not complete: continue
		_check("readability.frame." + slot + ".stable", a.card == b.card and a.name == b.name
			and a.summary == b.summary and a.text == b.text and a.font == b.font and a.lines == b.lines,
			{"first": a, "settled": b})
		for phase in ["first", "settled"]:
			var obs: Dictionary = a if phase == "first" else b
			var shape: Dictionary = obs.shape
			_check("readability.frame." + slot + "." + phase + "_complete", shape.missing.is_empty()
				and int(shape.count) > 0 and int(obs.lines) == int(obs.visible_lines)
				and Geo.to_rect(shape.control).grow(0.5).encloses(Geo.to_rect(shape.cells)), obs)

func _report() -> Dictionary:
	var failures := 0
	for row in rows:
		if not bool(row.passed): failures += 1
	var result := {"checks": rows.size(), "passed": rows.size() - failures, "findings": 0, "failures": failures,
		"rows": rows, "shots": views, "gestures": gestures, "reach_runs": reach_runs, "mouse_clicks": native.mouse_clicks, "touch_taps": native.touch_taps,
		"timings": timings, "equipment_frames": equipment_frames,
		"scope": "Isolated factory loans; native GUI and scroll events; two real single-unit material discards. Codex icon fidelity by byte-equal pixels against the live four-arg resolver at exact 46/38, 48, 44/36 and 40 px geometry; world-resolver dims witnessed as 32 or 42, not asserted uniform. Optional gear-fidelity gallery loans one named unique for card/worn/paperdoll views via native input with disclosed direct equipment assignment, restored. _open dispatch/settled timings recorded without thresholds. Host touch capability is explicitly enabled for --touch and restored; raw touch gestures, no physical device, controller, socket drag/drop, crafting, sale, save, merchant/world/held renderer, whole-art-corpus, or ordinary-progression acceptance. Equipped names may retain authored ellipsis; selected material detail full text checked. Geometry supports original-image review, never replaces it."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir + "/report.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	else: result.failures += 1; push_error("Inventory readability report could not be written")
	return result
