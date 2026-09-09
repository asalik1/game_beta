extends RefCounted
## Opt-in HUD dossier companion: actual GUI opens, read-only catalog inspection.
## Scroll placement is explicit QA setup; no buy/equip callback is invoked.
const MENU_COPY := "  ◈  Wardrobe  (skins & pets, bought with Renown)"
const RENOWN_COPY := "Earn Renown through activities and milestones. Spend it on skins, pets, or a weekly supply cache in the Wardrobe."
var r: Node
var g: Game


static func run(rig: Node) -> String:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	var saved_player: Dictionary = rig._stash(probe.g.local_player, ["skin", "chroma", "equipped_pet"])
	var saved_codex := {"sec": UICodex._sec, "filters": UICodex._filters,
		"query": UICodex._query, "selected": UICodex._selected,
		"fold_open": UICodex._fold_open, "ui": UICodex._ui}
	UICodex._filters = UICodex._filters.duplicate(true)
	UICodex._selected = UICodex._selected.duplicate(true)
	var before: Dictionary = probe._receipt()
	var error: String = await probe._run()
	rig._check("cosmetic_ui/no_purchase_or_equip", before == probe._receipt(),
		{"before": before, "after": probe._receipt()})
	await rig._close_overlay()
	# Cancel any streamed shelf before restoring the user's remembered choices.
	# Do not rewind the generation token and revive an obsolete async builder.
	UICodex._build_gen += 1
	UICodex._sec = String(saved_codex.sec)
	UICodex._filters = saved_codex.filters
	UICodex._query = String(saved_codex.query)
	UICodex._selected = saved_codex.selected
	UICodex._fold_open = bool(saved_codex.fold_open)
	UICodex._ui = saved_codex.ui
	rig._restore(probe.g.local_player, saved_player)
	rig._check("cosmetic_ui/remembered_choices_restored", UICodex._sec == saved_codex.sec
		and UICodex._filters == saved_codex.filters and UICodex._selected == saved_codex.selected
		and UICodex._query == saved_codex.query and UICodex._fold_open == saved_codex.fold_open)
	return error


func _run() -> String:
	if not g.no_saves or g.net_online():
		return "Cosmetic UI requires the isolated offline no_saves Game"
	await r._tap(g.hud.settings_btn.get_global_rect().get_center())
	if not _opened("pause", "menu_input"):
		return "HUD Menu input did not open the pause menu"
	var wardrobe: Button = _button("Wardrobe", false)
	if wardrobe == null:
		return "Missing Wardrobe menu action"
	await _show(wardrobe)
	r._probe("cosmetic_ui/menu_copy", wardrobe.text == MENU_COPY, {"text": wardrobe.text})
	_target("wardrobe_menu", wardrobe, g.touch_mode)
	await _capture("01_cosmetic_menu", {"wardrobe_text": wardrobe.text,
		"wardrobe_rect": r._rect(wardrobe.get_global_rect())})
	await r._tap(wardrobe.get_global_rect().get_center())
	if not _opened("wardrobe", "wardrobe_input"):
		return "Wardrobe menu action did not open the real catalog"
	var skin_heading: Label = _label("— SKINS —", false)
	var pet_heading: Label = _label("— COMPANIONS —", false)
	if skin_heading == null or pet_heading == null:
		return "Missing actual skin or companion section"
	var chroma_rows: Array[String] = []
	for label: Label in _labels():
		if label.text.to_lower().contains("chroma"):
			chroma_rows.append(label.text)
		for entry in Skins.chromas_for(g.local_player.cls):
			if label.text == String(entry.name) or label.text.begins_with(String(entry.name) + "   ←"):
				chroma_rows.append(label.text)
	r._probe("cosmetic_ui/no_chroma_rows", chroma_rows.is_empty(), {"found": chroma_rows})
	var skins: Array[String] = []
	for entry in Skins.skins_for(g.local_player.cls):
		var label: Label = _label(String(entry.name), false)
		r._check("cosmetic_ui/skin_row/" + String(entry.id), label != null)
		if label != null:
			skins.append(label.text)
	var pets: Array[Dictionary] = []
	var last_pet: Label
	var last_pet_row: Control
	for entry in Skins.pets():
		var label: Label = _label(String(entry.name), false)
		r._check("cosmetic_ui/pet_row/" + String(entry.id), label != null)
		if label == null:
			continue
		last_pet = label
		var row: Node = label.get_parent()
		while row != null and not (row is HBoxContainer):
			row = row.get_parent()
		last_pet_row = row as Control
		var action: Control = row.get_child(0) as Control if row != null and row.get_child_count() > 0 else null
		r._check("cosmetic_ui/pet_action_44/" + String(entry.id), action != null and action.size.y >= 44.0,
			{"height": action.size.y if action != null else 0.0})
		pets.append({"name": label.text, "action_rect": r._rect(action.get_global_rect()) if action != null else []})
	r._check("cosmetic_ui/current_offerings", not skins.is_empty() and pets.size() == Skins.pets().size())
	await _show(skin_heading)
	await _capture("02_wardrobe_skins", {"skin_rows": skins, "pet_rows": pets,
		"chroma_rows": chroma_rows, "inventory_scope": "instantiated catalog rows; clipped rows are not all claimed visible in this frame"})
	if last_pet == null or last_pet_row == null:
		return "No actual pet row to inspect"
	await _show(last_pet_row)
	r._check("cosmetic_ui/pet_name_on_screen", _on_screen(last_pet))
	var visible_action: Control = last_pet_row.get_child(0) as Control
	if visible_action == null:
		return "No actual companion action to measure"
	_target("visible_companion", visible_action, true)
	await _capture("03_wardrobe_companions", {"last_pet": last_pet.text,
		"name_rect": r._rect(last_pet.get_global_rect()), "action_rect": r._rect(visible_action.get_global_rect()),
		"scroll": "existing ScrollContainer ensure_control_visible; QA placement, not drag-input coverage"})
	await r._close_overlay() # setup reset; subsequent opens use real GUI events
	await r._tap(g.hud.codex_btn.get_global_rect().get_center())
	if not _opened("codex", "codex_input"):
		return "HUD Codex input did not open the book"
	var records: Button = g.menus.root.find_child("CodexRail_records", true, false) as Button
	if records == null:
		return "Missing actual Records rail action"
	await _show(records)
	var rail_rect: Array = r._rect(records.get_global_rect())
	_target("records_rail", records, false)
	await r._tap(records.get_global_rect().get_center())
	if not _opened("codex", "records_input") or UICodex._sec != "records":
		return "Actual Records rail input did not select Records"
	var description: Label
	for label: Label in _labels():
		if label.text.contains("weekly supply cache"):
			description = label
	var reopen: Button = _button("Open Wardrobe", true)
	if description == null or reopen == null:
		return "Missing actual Renown card and Wardrobe action"
	await _show(description)
	r._probe("cosmetic_ui/codex_renown_copy", description.text == RENOWN_COPY, {"text": description.text})
	r._check("cosmetic_ui/renown_copy_on_screen", _on_screen(description))
	await _capture("04_codex_renown", {"selected_section": UICodex._sec,
		"copy": description.text, "copy_rect": r._rect(description.get_global_rect()),
		"records_target_rect": rail_rect, "wardrobe_target_rect": r._rect(reopen.get_global_rect()),
		"target_scope": "existing Records rail is 25px desktop/28px touch; no rail redesign or universal 44px claim"})
	await _show(reopen)
	_target("codex_wardrobe", reopen, false)
	await r._tap(reopen.get_global_rect().get_center())
	if not _opened("wardrobe", "codex_wardrobe_input"):
		return "Actual Codex Wardrobe action did not open the catalog"
	return ""


func _opened(expected: String, id: String) -> bool:
	var ok: bool = g.menus.is_open() and g.menus.current == expected
	r._check("cosmetic_ui/" + id, ok, {"menu": g.menus.current,
		"input": "ScreenTouch" if g.touch_mode else "mouse"})
	return ok


func _labels() -> Array[Label]:
	var labels: Array[Label] = []
	var buttons: Array[Button] = []
	r._menu_controls(g.menus.root, labels, buttons)
	return labels


func _label(text: String, exact: bool) -> Label:
	for label: Label in _labels():
		if label.text == text or (not exact and label.text.begins_with(text)):
			return label
	return null


func _button(text: String, exact: bool) -> Button:
	var labels: Array[Label] = []
	var buttons: Array[Button] = []
	r._menu_controls(g.menus.root, labels, buttons)
	for button: Button in buttons:
		if button.text.strip_edges() == text or (not exact and button.text.contains(text)):
			return button
	return null


func _show(control: Control) -> void:
	# Pure viewing setup. Actual open/navigation/return actions use paired input.
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
		parent = parent.get_parent()
	await r.frames(4)


func _on_screen(control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if not r.get_viewport().get_visible_rect().encloses(rect):
		return false
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer and not (parent as ScrollContainer).get_global_rect().grow(0.5).encloses(rect):
			return false
		parent = parent.get_parent()
	return true


func _target(id: String, control: Control, require_44: bool) -> void:
	r._check("cosmetic_ui/target/" + id, _on_screen(control) and (not require_44 or control.size.y >= 44.0),
		{"rect": r._rect(control.get_global_rect()), "requires44": require_44})


func _capture(id: String, details: Dictionary) -> void:
	await r._capture(id, "Actual GUI opens, read-only catalog; scroll positions are QA setup, no purchase/equip", false)
	r.views[-1]["cosmetic_ui"] = details
	r._write_report()


func _receipt() -> Dictionary:
	# Load the ordinary account view before snapshotting; outer dossier cleanup
	# already preserves the original meta object/loaded flag and JSON bytes.
	var renown: int = g.renown()
	return {"renown": renown, "meta": g._meta.duplicate(true), "skin": g.local_player.skin,
		"chroma": g.local_player.chroma, "pet": g.local_player.equipped_pet,
		"cache_week": g.renown_cache_week, "gold": g.local_player.gold}
