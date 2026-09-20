extends RefCounted
## Shared observations in the existing native gem fixtures. No gameplay calls.
## Identify controls by ordered loan records / tooltip semantics before pixels;
## never search for a matching texture and then call that the expected control.
## Callers open the Gems filter and lend one socketed gem per item.

static func inspect(t, stage: String, item: Dictionary, picker := false) -> void:
	var m: Menus = t.g.menus
	var scope: Node = m.detail_popover if picker else m.root
	var prefix := "gem_art/" + stage
	t._check(prefix + "/scope", is_instance_valid(scope))
	if not is_instance_valid(scope): return
	var grids: Array[GridContainer] = []
	for raw in scope.find_children("*", "GridContainer", true, false):
		var grid := raw as GridContainer
		if not picker and is_instance_valid(m.detail_popover) and m.detail_popover.is_ancestor_of(grid): continue
		if grid.columns == (8 if picker else 11): grids.append(grid)
	t._check(prefix + "/unique_grid", grids.size() == 1, {"count": grids.size()})
	if grids.size() != 1: return
	var groups: Dictionary = m._gem_groups()
	var keys: Array = m._sorted_gem_keys(groups)
	var cells: Array[Button] = []
	for child in grids[0].get_children():
		if child is Button: cells.append(child)
	t._check(prefix + "/group_count", cells.size() == keys.size() and not cells.is_empty(),
		{"actual": cells.size(), "expected": keys.size()})
	if cells.size() != keys.size(): return
	for i in keys.size():
		var group: Dictionary = groups[keys[i]]
		var gem: Dictionary = group.gem
		var count: int = int(group.count)
		var button: Button = cells[i]
		var key := prefix + "/" + String(gem.stat) + "_" + str(gem.lvl)
		if picker:
			t._check(key + "/identity", button.tooltip_text.begins_with("%s  x%d\n" % [Items.gem_title(gem), count]))
			var err: String = t.p.gem_socket_error(item, gem)
			t._check(key + "/eligibility", button.disabled == (err != "")
				and (button.modulate == Color(0.45, 0.45, 0.5) if err != "" else button.modulate == Color.WHITE))
		var badges: Array[String] = []
		for child in button.get_children():
			if child is Label: badges.append(child.text)
		t._check(key + "/count_badge", badges == (["x%d" % count] if count > 1 else []), {"badges": badges})
		_cell(t, key, button, gem, 48.0)
	if picker: return
	for raw_gem in item.get("gems", []):
		var gem: Dictionary = raw_gem
		var buttons: Array[Button] = []
		for raw in scope.find_children("*", "Button", true, false):
			var b := raw as Button
			if is_instance_valid(m.detail_popover) and m.detail_popover.is_ancestor_of(b): continue
			if b.tooltip_text.begins_with(Items.gem_title(gem) + " — in the ") and b.tooltip_text.contains("Select for its card"):
				buttons.append(b)
		var key := prefix + "/socket_" + String(gem.stat) + "_" + str(gem.lvl)
		t._check(key + "/unique_identity", buttons.size() == 1, {"count": buttons.size()})
		if buttons.size() == 1: _cell(t, key, buttons[0], gem, 40.0)


static func _cell(t, key: String, button: Button, gem: Dictionary, side: float) -> void:
	t._check(key + "/geometry", button.custom_minimum_size.is_equal_approx(Vector2(side, side))
		and button.size.is_equal_approx(Vector2(side, side)), {"minimum": str(button.custom_minimum_size), "actual": str(button.size)})
	t._check(key + "/filter", button.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	var master: Image = Art._icon_override("codex/gem_%s_lv%d" % [gem.stat, int(gem.lvl)])
	t._check(key + "/master", master != null and master.get_size() == Vector2i(128, 128))
	if master == null: return
	var actual: Image = button.icon.get_image() if button.icon != null else null
	t._check(key + "/readback", actual != null)
	if actual == null: return
	actual.convert(Image.FORMAT_RGBA8)
	master = master.duplicate()
	master.convert(Image.FORMAT_RGBA8)
	t._check(key + "/exact_imported_master", actual.get_size() == master.get_size() and actual.get_data() == master.get_data(),
		{"stat": gem.stat, "level": gem.lvl, "dimensions": str(actual.get_size())})
