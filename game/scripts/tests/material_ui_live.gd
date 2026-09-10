extends RefCounted
## Native pilot display proof. Loaned inventory, one posed letter and factory
## pickups are controlled fixtures, not collection, crafting or award evidence.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const EncounterUI := preload("res://scripts/ui/encounter_status.gd")
const PILOTS := ["herb", "reagent", "metal"]
const AlchemyProof := preload("res://scripts/tests/alchemy_live.gd")
const Alchemy := preload("res://scripts/alchemy.gd")
const PAIR_GRADES := ["E", "D"]
const PAIR_FAMILIES := ["herb", "reagent"]
const F_APPROVED_PNG := {
	"herb_f_wilted_sprig": "002cde309b10aaa2bb371ea8b8fc33dd2b31f6b8d8b1984555c8809b5f2184e7",
	"reagent_f_foul_residue": "616fe29b361901e9aa73fe5809ea2295e62d260a7541bbe7f5944273a5f9154c",
	"metal_f_rusted_scrap": "ef2d42a90dc14248726c771e4b4f4954ae251c20bf8028acd01184665eeaba31",
}

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
	if r.flag("world-prompts"):
		var prompt_error: String = await _world_prompt_menus()
		if prompt_error != "":
			return prompt_error
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
	if r.flag("grade-pairs"):
		return await _grade_pairs()
	return ""


func _grade_pairs() -> String:
	# This optional pass begins only after every original F-pilot/world check.
	# Loan just four stacks, then restore on success and every early return.
	var saved_materials: Array = p.materials.duplicate(true)
	var memory_present := m.has_meta("alchemy_view")
	var saved_memory: Dictionary = m.get_meta("alchemy_view", {}).duplicate(true)
	var saved_emulation: bool = Input.emulate_mouse_from_touch
	var source_before := _source_hashes()
	var before := _economy()
	Input.emulate_mouse_from_touch = true
	var alchemy := AlchemyProof.new()
	alchemy.r = r
	alchemy.g = g
	alchemy.m = m
	alchemy.p = p
	alchemy.native = native
	var error: String = await _grade_pair_views(alchemy)
	# Release current callbacks before restoring their inspected inventory/view.
	m.close()
	p.materials = saved_materials
	if memory_present:
		m.set_meta("alchemy_view", saved_memory)
	elif m.has_meta("alchemy_view"):
		m.remove_meta("alchemy_view")
	Input.emulate_mouse_from_touch = saved_emulation
	for row in alchemy.rows:
		_check("grade_pairs." + String(row.id), bool(row.passed), row.actual)
	_check("grade_pairs.loan_restored", _economy() == before, "four inspected stacks restored; no brew, purchase, claim or sale")
	_check("grade_pairs.files_unchanged", _source_hashes() == source_before, "all35 legacy world PNGs and all seven UI file hashes unchanged during fixture")
	return error


func _grade_pair_views(alchemy: AlchemyProof) -> String:
	r.step("optional E/D material pairs: exact F controls and loaned preview inventory")
	for stem in F_APPROVED_PNG:
		var path := "res://assets/icons/materials_ui/" + String(stem) + ".png"
		if not _check("grade_pairs.accepted_F." + String(stem), FileAccess.file_exists(path)
				and FileAccess.get_sha256(path) == F_APPROVED_PNG[stem], path):
			return "accepted F pilot PNG changed or missing"
	var pair_textures := {}
	for grade in PAIR_GRADES:
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			var legacy: Texture2D = Art.material_icon(family, grade)
			var icon: Texture2D = Art.material_ui_icon(family, grade)
			if not _check("grade_pairs.legacy32." + id, legacy != null and legacy.get_size() == Vector2(32, 32), id):
				return "legacy world texture changed size or is missing"
			if not _check("grade_pairs.texture_available." + id, icon != null, id):
				return "UI resolver returned no icon"
			_check("grade_pairs.ui128." + id, icon.get_size() == Vector2(128, 128), str(icon.get_size()), true)
			pair_textures[id] = icon
			p.materials.append(Items.make_material(family, grade, 7))
	var browse_before: Dictionary = alchemy._economy()
	m.open_inventory("gear", "all")
	await r.frames(4)
	for grade in PAIR_GRADES:
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			_surface("grade_pairs.inventory." + id, m.root, pair_textures[id], true)
	for family in PILOTS:
		_surface("grade_pairs.inventory.F_" + String(family), m.root, textures[family], true)
	_surface("grade_pairs.inventory.potion", m.root, Art.consumable_icon(potion), true, false)
	await _capture("06_grade_pairs_inventory")
	# Public Professions entry and actual bench/recipe/grade clicks; no trade lock
	# or mastery loan is needed to inspect the art. Resource actions stay untouched.
	m.open_professions()
	await r.frames(3)
	if not await alchemy._named("ProfessionsAlchemy", g.touch_mode):
		return "actual Professions Alchemy entry unavailable"
	if not await alchemy._named("AlchemyShape_mana_instant", g.touch_mode):
		return "actual mana recipe row unavailable"
	var capture_index := 7
	for grade in PAIR_GRADES:
		if not await alchemy._named("AlchemyGrade_" + String(grade), g.touch_mode):
			return "actual grade selector unavailable"
		var recipe: Dictionary = Alchemy.recipe("mana_instant", grade)
		_check("grade_pairs.recipe." + String(grade), alchemy._view().get("shape") == "mana_instant"
			and alchemy._view().get("grade") == grade and alchemy._text("AlchemyProductName") == String(recipe.item.name), alchemy._text("AlchemyProductName"))
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			var icon: Texture2D = pair_textures[id]
			_surface("grade_pairs.alchemy." + id, m.root, icon, false)
			var control := _texture_control(m.root, icon, false)
			if _check("grade_pairs.alchemy.control." + id, control != null, id):
				_check("grade_pairs.alchemy32." + id, _icon_rect(control, icon).size.is_equal_approx(Vector2(32, 32)), str(_icon_rect(control, icon)))
				var label_text := "%s · %s grade" % [String(Items.MATERIALS[family][grade]), grade]
				var found := false
				for child in control.get_parent().get_children():
					if child is Label and child.text == label_text:
						found = child.get_visible_line_count() == child.get_line_count()
				_check("grade_pairs.identity." + id, found, label_text)
			var need := int(recipe.herbs) if family == "herb" else int(recipe.reagents)
			_check("grade_pairs.count." + id, alchemy._text("AlchemyIngredient_" + String(family)).contains("Have 7 / Need %d" % need), alchemy._text("AlchemyIngredient_" + String(family)))
		var bottle: Texture2D = Art.consumable_icon(recipe.item)
		_surface("grade_pairs.alchemy.bottle_" + String(grade), m.root, bottle, false, false)
		var product := _texture_control(m.root, bottle, false)
		if _check("grade_pairs.alchemy.product." + String(grade), product != null, recipe.item.name):
			_check("grade_pairs.alchemy64." + String(grade), _icon_rect(product, bottle).size.is_equal_approx(Vector2(64, 64)), str(_icon_rect(product, bottle)))
		await alchemy._recipe_caption("mana_instant", grade)
		alchemy._layout("material_pair_" + String(grade))
		await alchemy._capture("%02d_grade_pair_%s_alchemy" % [capture_index, String(grade).to_lower()])
		capture_index += 1
	_check("grade_pairs.browse_no_economy_changes", alchemy._economy() == browse_before, "gold, mastery, materials, potions, blueprints, mail and favor unchanged")
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
		"geometry": geometry, "baseline": r.flag("baseline"), "grade_pairs": r.flag("grade-pairs"),
		"mouse_clicks": native.mouse_clicks, "touch_taps": native.touch_taps,
		"source_hashes": _source_hashes(),
		"scope": ("three F pilots plus four E/D herb/reagent UI siblings and real Alchemy previews; " if r.flag("grade-pairs") else "three F-grade UI pilots; ")
			+ "32px world control; controlled loans; no real collection, crafting, persistence or hardware claim"}
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
			if (String(grade) == "F" and PILOTS.has(String(family))) or (r.flag("grade-pairs") and PAIR_GRADES.has(String(grade)) and PAIR_FAMILIES.has(String(family))):
				var pilot := "res://assets/icons/materials_ui/" + stem + ".png"
				result[pilot] = FileAccess.get_sha256(pilot) if FileAccess.file_exists(pilot) else "not_installed"
	return result


## Optional menu-visibility follow-up. The existing rig entered Crownfall and
## settled normally; require a real selected world prompt, never force one on.
func _world_prompt_menus() -> String:
	var prior_host: FangmootHost = m.fm_host
	var prior_moot: FangmootMoot = m.fm_moot
	var prior_standalone: bool = m.fm_standalone
	var emulation: bool = Input.emulate_mouse_from_touch
	var pad_state := {}
	for field in ["active", "focused", "device", "rearm", "buttons", "axes", "_triggers"]:
		var value: Variant = g.gamepad.get(field)
		pad_state[field] = value.duplicate(true) if value is Dictionary else value
	var before := _economy()
	Input.emulate_mouse_from_touch = true
	var error: String = await _world_prompt_views()
	m.close()
	m.fm_host = prior_host
	m.fm_moot = prior_moot
	m.fm_standalone = prior_standalone
	Input.emulate_mouse_from_touch = emulation
	g.gamepad._set_active(bool(pad_state.active))
	for field in pad_state:
		g.gamepad.set(field, pad_state[field])
	_check("world_prompts.economy_unchanged", _economy() == before,
		"existing controlled inventory/letter; no Act, purchase, claim or match")
	return error


func _world_prompt_views() -> String:
	r.step("optional actual menu visibility: existing Crownfall interaction prompt")
	if not _check("world_prompts.ready", not m.is_open() and not g.get_tree().paused
			and g.is_processing() and g.state == Game.ST_PLAYING
			and not g.input_overlay_up(), "normal no-overlay Crownfall selector must be running"):
		return "world-prompt fixture not ready after normal capital boot"
	await r.frames(3)
	var selected: Array[int] = _visible_world_prompts()
	if not _check("world_prompts.positive", selected.size() == 1 and g.interact_in_range,
			{"visible_prompt_ids": selected, "scope": "normal current selector; no posed visibility or body/camera mutation"}):
		return "normal Crownfall arrival did not expose one real prompt"
	var overlay_flags := [g.hud.dialogue_active, g.hud.choices_active, g.hud.chat_active]
	for route in ["keyboard", "touch", "controller"]:
		if route == "controller":
			# Build the actual full-screen hub with its existing non-granting host.
			# No table, match, purchase or result is entered.
			m.fm_host = FangmootHost.new()
			m.fm_moot = null
			m.fm_standalone = false
			m.open_fangmoot()
		else:
			m.open_inventory("gear", "all")
		var menu := "fangmoot" if route == "controller" else "inventory"
		if not _check("world_prompts.actual_menu." + route, m.current == menu
				and m.is_open() and g.input_overlay_up(), m.current):
			return "actual menu builder did not open for " + route
		# Immediate assertion matters: solo pause prevents another Game tick.
		_check("world_prompts.hidden_on_open." + route, _visible_world_prompts().is_empty(),
			_visible_world_prompts(), true)
		await r.frames(3)
		_check("world_prompts.hidden_while_open." + route, _visible_world_prompts().is_empty(),
			_visible_world_prompts(), true)
		if route == "keyboard":
			await _capture("prompt_inventory_open")
		if route == "touch":
			await native._touch(Vector2(12, 12))
		elif route == "controller":
			await native._joy_back()
		else:
			await native._key(KEY_ESCAPE)
		await r.frames(3)
		if not _check("world_prompts.actual_close." + route,
				not m.is_open() and not g.get_tree().paused, "real " + route + " dismissal"):
			return "native close failed for " + route
		if not _check("world_prompts.restored_on_tick." + route,
				_visible_world_prompts() == selected and g.interact_in_range,
				{"before": selected, "after": _visible_world_prompts()}):
			return "normal selector did not restore the same nearby prompt"
		_check("world_prompts.dialogue_chat_unchanged." + route,
			[g.hud.dialogue_active, g.hud.choices_active, g.hud.chat_active] == overlay_flags,
			"menu opening/closing did not start or cancel dialogue, choices or chat")
	await _capture("prompt_restored_world")
	return ""


func _visible_world_prompts() -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in g.interactables:
		var prompt: Variant = entry.get("prompt")
		if is_instance_valid(prompt) and prompt is CanvasItem and prompt.is_visible_in_tree():
			result.append(prompt.get_instance_id())
	return result
