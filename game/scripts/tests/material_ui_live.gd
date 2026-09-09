extends RefCounted
## Native pilot display proof. Loaned inventory, one posed letter and factory
## pickups are controlled fixtures, not collection, crafting or award evidence.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const EncounterUI := preload("res://scripts/ui/encounter_status.gd")
const PILOTS := ["herb", "reagent", "metal"]

var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native: NativeInput
var rows: Array[Dictionary] = []
var geometry: Array[Dictionary] = []
var textures := {}
var potion: Dictionary


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
	var settings: Dictionary = proof.g.settings.duplicate(true)
	var lang: String = Loc.lang
	var game_process := proof.g.is_processing()
	var physics := proof.p.is_physics_processing()
	Loc.lang = "en"
	proof.g.settings["touch_controls"] = rig.flag("touch")
	proof.g.refresh_touch_mode()
	proof.g._apply_touch_mode()
	var error: String = await proof._run()
	proof._check("runtime.completed", error == "", error)
	proof.m.close()
	proof.g.settings = settings
	Loc.lang = lang
	proof.g.refresh_touch_mode()
	proof.g._apply_touch_mode()
	proof.g.set_process(game_process)
	proof.p.set_physics_process(physics)
	return proof._report()


func _run() -> String:
	if not _check("fixture.no_saves_capital", g.no_saves and not g.net_online() and g.chapter_id == "capital", g.chapter_id):
		return "requires isolated native Crownfall fixture"
	g.play_started = true
	g.dev_god = true
	p.backpack = []
	p.gem_bag = []
	p.loose_bags = []
	p.materials = []
	p.gold = 321
	for family in PILOTS:
		p.materials.append(Items.make_material(family, "F", 7))
	# An unpiloted grade remains visible as a fallback control.
	p.materials.append(Items.make_material("metal", "E", 3))
	potion = Items.make_potion("health", "instant", "F", "accord")
	p.consumables = [potion]
	var payloads: Array = []
	for family in PILOTS:
		payloads.append({"kind": "material", "family": family, "grade": "F", "count": 7})
	payloads.append({"kind": "potion", "potion": potion.duplicate(true)})
	payloads.append({"kind": "material", "family": "metal", "grade": "E", "count": 3})
	g.mailbox = [{"subject": "Material art pilot — controlled fixture", "body": "Loaned materials beside the existing Health Potion. Review only; no collection or reward claim.",
		"items": payloads, "sent_at": g.trusted_now(), "read": false}]
	var before := _economy()
	for family in PILOTS:
		var legacy: Texture2D = Art.material_icon(family, "F")
		var ui: Dictionary = UIMailbox.attachment_view({"kind": "material", "family": family, "grade": "F", "count": 7})
		textures[family] = ui.icon
		_check("legacy32." + family, legacy != null and legacy.get_width() == 32 and legacy.get_height() == 32, family)
		_check("ui128." + family, ui.icon != null and ui.icon.get_width() == 128 and ui.icon.get_height() == 128,
			str(ui.icon.get_size()) if ui.icon != null else "missing", true)
		_check("mail_identity." + family, ui.count == 7 and ui.title == Items.MATERIALS[family].F, ui.title)
	var fallback: Dictionary = UIMailbox.attachment_view({"kind": "material", "family": "metal", "grade": "E", "count": 3})
	_check("unpiloted_fallback", fallback.icon == Art.material_icon("metal", "E") and fallback.icon.get_width() == 32, "Metal E keeps legacy texture instance")
	r.step("inventory: three material pilots, fallback and existing potion")
	m.open_inventory("gear", "all")
	await r.frames(4)
	for family in PILOTS:
		_surface("inventory." + family, m.root, textures[family], true)
	_surface("inventory.potion_reference", m.root, Art.consumable_icon(potion), true, false)
	await _capture("00_inventory_with_potion")
	var herb := _texture_control(m.root, textures.herb, true)
	if not await _click(herb, "inventory herb"):
		return "inventory herb slot unavailable"
	_check("inventory.detail_open", is_instance_valid(m.detail_popover), "actual slot click")
	_surface("inventory.herb_detail", m.detail_popover, textures.herb, false)
	await _capture("01_inventory_herb_detail")
	m.close()
	UIMailbox.open(m)
	await r.frames(3)
	var letter: Button = native._find_button(m.root, "Material art pilot")
	if not await _click(letter, "letter row"):
		return "fixture letter row unavailable"
	for family in PILOTS:
		_surface("mail." + family, m.root, textures[family], true)
	_surface("mail.potion_reference", m.root, Art.consumable_icon(potion), true, false)
	await _capture("02_mail_with_potion")
	var metal := _texture_control(m.root, textures.metal, true)
	if not await _click(metal, "mail metal"):
		return "mail material slot unavailable"
	_surface("mail.metal_detail", m.detail_popover, textures.metal, false)
	await _capture("03_mail_metal_detail")
	m.close()
	m.open_shop(g.cur_room, "buy")
	await r.frames(3)
	var sell: Button = native._find_button(m.root, "Sell", true)
	if not await _click(sell, "merchant Sell tab"):
		return "merchant Sell tab unavailable"
	var merchant_herb := _texture_control(m.root, textures.herb, false)
	if merchant_herb != null:
		await _reveal(merchant_herb)
	for family in PILOTS:
		_surface("merchant." + family, m.root, textures[family], false)
	_surface("merchant.potion_reference", m.root, Art.consumable_icon(potion), false, false)
	await _capture("04_merchant_sell_with_potion")
	_check("browse.no_economy_changes", _economy() == before, "no claim, sale, drop or brewing actions")
	await _pickups()
	_check("world.no_claim", _economy() == before, "posed factory pickups remain unclaimed")
	return ""


func _pickups() -> void:
	r.step("world control: unchanged32px pickups beside existing potion")
	m.close()
	g.hud.cancel_conversation()
	g.player.set_physics_process(false)
	g.set_process(false)
	g.camera.position_smoothing_enabled = false
	g.camera.zoom = Vector2.ONE
	var center := g.play_rect(g.cur_room).get_center()
	p.global_position = center + Vector2(-300, -150)
	g.camera.global_position = center
	g.camera.force_update_scroll()
	var drops: Array[Pickup] = []
	for i in PILOTS.size() + 1:
		var is_potion := i == PILOTS.size()
		var name := "Health Potion" if is_potion else String(Items.MATERIALS[String(PILOTS[i])].F)
		var payload: Dictionary = {"kind": "potion", "potion": potion.duplicate(true)} if is_potion \
			else {"kind": "material", "family": String(PILOTS[i]), "grade": "F", "count": 1}
		var texture: Texture2D = Art.consumable_icon(potion) if is_potion else Art.material_icon(String(PILOTS[i]), "F")
		var at := center + Vector2(-270 + i * 180, -10)
		var drop := Pickup.drop_loot(g, payload, at)
		drop.pickup_delay = 999.0
		drop.set_physics_process(false)
		drop.global_position = at # controlled row; not an ordinary scatter claim
		drops.append(drop)
		var sprite: Sprite2D = null
		for child in drop.get_children():
			if child is Sprite2D and child.texture == texture:
				sprite = child
		if _check("world.sprite." + name, sprite != null, "real Pickup.drop_loot sprite"):
			var width: float = sprite.get_rect().size.x * absf(sprite.scale.x)
			geometry.append({"surface": "world." + name, "source_px": str(texture.get_size()), "world_width": width, "scale": str(sprite.scale)})
			if not is_potion:
				_check("world.size_preserved." + name, is_equal_approx(width, 35.2) and texture.get_width() == 32, width)
		var label := Label.new()
		label.text = name
		label.position = Vector2(-85, 34)
		label.size.x = 170
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		drop.add_child(label)
	var panel := EncounterUI.make(g.hud, "MaterialWorldControl", UITheme.GOLD_BRIGHT)
	(panel.get_node("Title") as Label).text = "MATERIAL ART · WORLD CONTROL"
	(panel.get_node("Detail") as Label).text = "Posed drops · 32px material source"
	(panel.get_node("Hint") as Label).text = "No collection or award claim"
	await r.sim_wait(1.0)
	await _capture("05_world_pickups_size_control")
	panel.queue_free()
	for drop in drops:
		drop.queue_free()
	await r.frames(2)


func _surface(id: String, root: Node, texture: Texture2D, button: bool, pilot := true) -> void:
	var control := _texture_control(root, texture, button)
	if not _check(id + ".real_control", control != null, "texture used by actual screen"):
		return
	var rect := control.get_global_rect()
	var icon_rect := _icon_rect(control, texture)
	if not _check(id + ".icon_bounds", icon_rect.has_area(), "supported centered icon renderer with positive bounds"):
		return
	var visible := icon_rect
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible = visible.intersection(ancestor.get_global_rect())
		if ancestor == m.root:
			break
		ancestor = ancestor.get_parent()
	var screen := m.get_viewport().get_visible_rect()
	visible = visible.intersection(screen).intersection(m._shell_rect)
	# Require the whole fitted image, not a remaining sliver or the enclosing
	# merchant row button. Fractional layout rounding gets less than one pixel.
	_check(id + ".visible_contained", visible.has_area() and visible.grow(0.75).encloses(icon_rect),
		{"icon": str(icon_rect), "visible": str(visible), "tolerance_px": 0.75})
	var content := rect.size
	if control is Button:
		content -= control.get_theme_stylebox("normal").get_minimum_size()
	geometry.append({"surface": id, "texture_px": str(texture.get_size()), "control_rect": str(rect),
		"icon_rect": str(icon_rect), "visible_rect": str(visible),
		"visible_fraction": visible.get_area() / icon_rect.get_area(),
		"content_box": str(content), "texture_filter": control.texture_filter})
	if pilot:
		_check(id + ".high_resolution", texture.get_width() == 128 and texture.get_height() == 128, str(texture.get_size()), true)
		_check(id + ".linear_downsampling", control.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
			control.texture_filter, true)


func _icon_rect(control: Control, texture: Texture2D) -> Rect2:
	# These actual screens use empty centered, expanding bag Button icons or
	# KEEP_ASPECT_CENTERED TextureRects. Reject a changed renderer contract.
	var box := Rect2(Vector2.ZERO, control.size)
	var max_width := 0.0
	if control is Button:
		if not control.expand_icon or control.text != "" or control.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			return Rect2()
		var style := control.get_theme_stylebox("normal")
		box.position = style.get_offset()
		box.size -= style.get_minimum_size()
		max_width = float(control.get_theme_constant("icon_max_width"))
	elif not control is TextureRect or control.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		return Rect2()
	var source := texture.get_size()
	if not box.has_area() or source.x <= 0.0 or source.y <= 0.0:
		return Rect2()
	var fit := minf(box.size.x / source.x, box.size.y / source.y)
	if max_width > 0.0:
		fit = minf(fit, max_width / source.x)
	var image_size := source * fit
	return control.get_global_transform() * Rect2(box.position + (box.size - image_size) * 0.5, image_size)


func _texture_control(root: Node, texture: Texture2D, want_button: bool) -> Control:
	if not is_instance_valid(root) or texture == null:
		return null
	if want_button and root is Button and root.icon == texture and root.is_visible_in_tree():
		return root
	if not want_button and root is TextureRect and root.texture == texture and root.is_visible_in_tree():
		return root
	for child in root.get_children():
		var found := _texture_control(child, texture, want_button)
		if found != null:
			return found
	return null


func _click(control: Control, name: String) -> bool:
	if not _check("input." + name, control != null, name):
		return false
	await _reveal(control)
	await native._mouse(control.get_global_rect().get_center())
	await r.frames(3)
	return true


func _reveal(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await r.frames(2)
		ancestor = ancestor.get_parent()


func _economy() -> Dictionary:
	return {"gold": p.gold, "materials": p.materials.duplicate(true), "potions": p.consumables.duplicate(true),
		"mail_items": g.mailbox[0].items.duplicate(true)}


func _capture(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "three-material art pilot; controlled resource and presentation fixtures; no collection proof")


func _check(id: String, ok: bool, actual: Variant, presentation := false) -> bool:
	rows.append({"id": id, "passed": ok, "presentation": presentation, "actual": actual})
	print("MATERIAL CHECK %s: %s %s" % [id, "PASS" if ok else ("FINDING" if presentation and r.flag("baseline") else "FAIL"), str(actual) if not ok else ""])
	return ok


func _report() -> Dictionary:
	var result := {"checks": rows.size(), "passed": 0, "findings": 0, "failures": 0, "rows": rows,
		"geometry": geometry, "baseline": r.flag("baseline"), "mouse_clicks": native.mouse_clicks,
		"source_hashes": _source_hashes(),
		"scope": "three F-grade UI pilots;32px world control; controlled fixtures; no real collection, crafting or persistence claim"}
	for row in rows:
		if row.passed: result.passed += 1
		elif row.presentation and r.flag("baseline"): result.findings += 1
		else: result.failures += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(r.shot_dir))
	var file := FileAccess.open(r.shot_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t"))
	else:
		result.failures += 1
		print("MATERIAL CHECK report.write: FAIL")
	return result


func _source_hashes() -> Dictionary:
	var result := {}
	for family in Items.MATERIALS:
		for grade in Items.MATERIALS[family]:
			var stem := Items.material_stem(String(family), String(grade), String(Items.MATERIALS[family][grade]))
			var path := "res://assets/icons/materials/" + stem + ".png"
			result[path] = FileAccess.get_sha256(path)
			if String(grade) == "F" and PILOTS.has(String(family)):
				var pilot := "res://assets/icons/materials_ui/" + stem + ".png"
				result[pilot] = FileAccess.get_sha256(pilot) if FileAccess.file_exists(pilot) else "not_installed"
	return result
