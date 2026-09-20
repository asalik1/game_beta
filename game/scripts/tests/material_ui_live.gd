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
const ALL_INVENTORY_GRADES := ["E", "D", "C", "B", "A"]
const UPPER_GRADES := ["C", "B", "A"]
# Preparation replaces this directive only after six real approvals validate.
const ALL_APPROVED_PNG := {
	"herb_f_wilted_sprig": "002cde309b10aaa2bb371ea8b8fc33dd2b31f6b8d8b1984555c8809b5f2184e7",
	"reagent_f_foul_residue": "616fe29b361901e9aa73fe5809ea2295e62d260a7541bbe7f5944273a5f9154c",
	"metal_f_rusted_scrap": "ef2d42a90dc14248726c771e4b4f4954ae251c20bf8028acd01184665eeaba31",
	"herb_e_common_weed": "b53be4ebf6967d3cd5956e82aa6dde9c341c75027ef8b26bfda1eaa570e62ebe",
	"herb_d_fresh_herb": "10f87dc1f86f9eee91b1b562b9b6a01cfd8fa0b654d833f75e50ddbf9a9acdbe",
	"reagent_e_crude_extract": "06b5fc7301307d2ecb7df18a21e1a99b9f62ce3558d2b61650d5d4d1595bb9a4",
	"reagent_d_clean_extract": "8947011c48a311a9f5fb600da47b587d3f9098aa149a8f919c322167d49e9446",
	"herb_c_verdant_herb": "f309c9fa0e738430f65d58ad416c7cd859b274de9dca3eeebc42aef05d630509",
	"reagent_c_potent_essence": "3912df756e18d0c0217809dc7b8522ad6d6277895cf0065d483f0401b361fcd1",
	"herb_b_rare_bloom": "e308703cdf00b9c98bcea6bbbb1f2d8bda515352ac68648989b19be83d7430df",
	"reagent_b_pure_essence": "5a08c056c7e724803c403ee29bef6ea6050e2e2e9670c62f4948aaee943fee01",
	"herb_a_pristine_bloom": "70b54a60718ec5e5a9d4cb5155f0fefe1554a6a8de3a9afede4d97b5e0be26cc",
	"reagent_a_radiant_essence": "7fbf3157d728fa37fe87a01dad2ce068a8674a62fa8ad5b1f5fb17b815723722"
}
const ALL_UPPER_IDS := ["herb_c_verdant_herb", "reagent_c_potent_essence", "herb_b_rare_bloom", "reagent_b_pure_essence", "herb_a_pristine_bloom", "reagent_a_radiant_essence"]
const ALL_WORLD_PNG := {
	"res://assets/icons/materials/bone_a_saintbone.png": "c5ab175ac72cdc6cb007254ae487ddc79e9c6d5ec8281447dd4c43d575202270",
	"res://assets/icons/materials/bone_b_blessed_relic.png": "e765b244902b048849a7357e4a2a84f141f97345da8ccdb79e542951eb6ecd3b",
	"res://assets/icons/materials/bone_c_runed_bone.png": "ffe1bc045406268841835893f399d64e6348c05c706cb69c604d38251e572b47",
	"res://assets/icons/materials/bone_d_whole_bone.png": "aa03cd8cdd2fb99ab179b4ef4fa795414187fdfb64eefca1f8cb18a703642f37",
	"res://assets/icons/materials/bone_e_bleached_bone.png": "27d4a336f473c74b703b5fdb71d971318787fd7e03f2e0529175d62f5b197430",
	"res://assets/icons/materials/bone_f_cracked_bone.png": "ef29ec3689021d682ab52ebd12de906238bd4c94902511e67b7d64533d16293d",
	"res://assets/icons/materials/bone_s_concordium_relic.png": "022d8298dfe3f5a0f1ffa5ac826cc27722d35359b5a846d77c2010dfb26434b0",
	"res://assets/icons/materials/cloth_a_gilded_weave.png": "9c640d6c3f97a28fa5a379c2184ffc041ec97a9b5e8db079eb894ca75c661ee1",
	"res://assets/icons/materials/cloth_b_fine_silk.png": "ea519dadd8e75522637e7cb268f1eade6abefc0f603ed8828981bd3d1c7da660",
	"res://assets/icons/materials/cloth_c_tanned_weave.png": "97618396513c7a6cd2371f7975db51f50184d50d7ccfe16ae2da09d4f13e1382",
	"res://assets/icons/materials/cloth_d_plain_bolt.png": "bf148755ab7c9803c4eb12246dc4b8db38be8e9f0bb6a2d99ef6e51b7d78a451",
	"res://assets/icons/materials/cloth_e_coarse_cloth.png": "28be9032911344b6f240209c96cd8a77043b87273ec9c6efa50ce59c98bc008b",
	"res://assets/icons/materials/cloth_f_frayed_scraps.png": "c387bf1cec13c64b01cdae55cf5644332503f955f1f72d60b1115e0695b634ad",
	"res://assets/icons/materials/cloth_s_moonweave.png": "d20adfc31fd05c3a6f627c2f72da11f96822079553d1ed7fedd9fd12bba1361f",
	"res://assets/icons/materials/herb_a_pristine_bloom.png": "6f55fe7419912aa788904e9519e461fb0fb6949039162b5b6d93695712e73888",
	"res://assets/icons/materials/herb_b_rare_bloom.png": "e3ce55a7064c41685e4ea6df7f7d7bc235d622b0da78b1f9ed8f266de27f8a18",
	"res://assets/icons/materials/herb_c_verdant_herb.png": "ee22d5d3ad241cd6384618ec89c9327fd2e614d109b526ce35e258afbb94dbcc",
	"res://assets/icons/materials/herb_d_fresh_herb.png": "401bc06f45c519dd25eec36b4687a278ec2dd57d42903c3e006ae13bd1113e44",
	"res://assets/icons/materials/herb_e_common_weed.png": "f0ab23216e0d3984f2322e302cc02a4361df890f76bb1c09c1937665dca0500d",
	"res://assets/icons/materials/herb_f_wilted_sprig.png": "0012cb7b74050be0079b831abe2c9e0b7bba92993a64be5b7ef409558d94c43c",
	"res://assets/icons/materials/herb_s_sunpetal.png": "743b4f82943c4c0c5ef796670dcec14dda06b8b7ee13a0624832829afc654dad",
	"res://assets/icons/materials/metal_a_mastercrafted_alloy.png": "7ae75b167fb5c062e13e61d5a47dafa77261b1dfbde4239bdb1beccbe46835c5",
	"res://assets/icons/materials/metal_b_fine_steel.png": "a462d8d9210cbcd78e247ba02d63308dc2a9db82e324c884d88056c4b6b99ad3",
	"res://assets/icons/materials/metal_c_tempered_steel.png": "6e2b77f5cab62c3592349e69900c7cca8b4afc1b549a1195034a52b1545867d8",
	"res://assets/icons/materials/metal_d_plain_ingot.png": "1c0bdf0f38f7a80c933840defbc76fa161a71466982daea8477231acc0a09534",
	"res://assets/icons/materials/metal_e_pitted_iron.png": "276c14fcc5ad0907f6bf394214ba893f509b2ec65423820f2f2c984bcbcafea6",
	"res://assets/icons/materials/metal_f_rusted_scrap.png": "e2c719a5de524494931b52e8f0c9d5548d1b19b4235bf2269c325b16f42c3db0",
	"res://assets/icons/materials/metal_s_starforged_ingot.png": "dd08a73c04d5bc04a1f84b04467de8e336e501a5edd090371bca862f17c98931",
	"res://assets/icons/materials/reagent_a_radiant_essence.png": "2ddebd1b798d67f662b15d19fa640648d65d9b228c628fd8d32bb7744a9687d5",
	"res://assets/icons/materials/reagent_b_pure_essence.png": "af888a4a6ad1ccbe9c4c1c3f575cd2c5ffdb14537440c1e1754fbf474fea57e0",
	"res://assets/icons/materials/reagent_c_potent_essence.png": "c5eebb4d7e15fb1a8f989071f3fa98360c2d5bb63580c3b1e2fb3cb3142370c8",
	"res://assets/icons/materials/reagent_d_clean_extract.png": "8495b2270de257ae8ab6b577b83d0455c9fa8974a24c01ff1179b2a09651c32d",
	"res://assets/icons/materials/reagent_e_crude_extract.png": "df13358abfdd58cf17a1161da87737deb65abcbc15e1e08f86d4dec0f08b6099",
	"res://assets/icons/materials/reagent_f_foul_residue.png": "02d2ddfa71a9d8f7a9d00143814c06ca10d27987a83309aa8cd3721b8bb2a076",
	"res://assets/icons/materials/reagent_s_quintessence.png": "02a7e9c2165c5cb0305d7c85798a9489c37a419f6310ef3d564bba3b3a4d0952"
}
const ALL_BASELINE_PRESENTATION := {
	"all_brewing.ui128.herb_C": "herb_c_verdant_herb",
	"all_brewing.inventory.herb_C.high_resolution": "herb_c_verdant_herb",
	"all_brewing.inventory.herb_C.linear_downsampling": "herb_c_verdant_herb",
	"all_brewing.alchemy.herb_C.high_resolution": "herb_c_verdant_herb",
	"all_brewing.alchemy.herb_C.linear_downsampling": "herb_c_verdant_herb",
	"all_brewing.ui128.reagent_C": "reagent_c_potent_essence",
	"all_brewing.inventory.reagent_C.high_resolution": "reagent_c_potent_essence",
	"all_brewing.inventory.reagent_C.linear_downsampling": "reagent_c_potent_essence",
	"all_brewing.alchemy.reagent_C.high_resolution": "reagent_c_potent_essence",
	"all_brewing.alchemy.reagent_C.linear_downsampling": "reagent_c_potent_essence",
	"all_brewing.ui128.herb_B": "herb_b_rare_bloom",
	"all_brewing.inventory.herb_B.high_resolution": "herb_b_rare_bloom",
	"all_brewing.inventory.herb_B.linear_downsampling": "herb_b_rare_bloom",
	"all_brewing.alchemy.herb_B.high_resolution": "herb_b_rare_bloom",
	"all_brewing.alchemy.herb_B.linear_downsampling": "herb_b_rare_bloom",
	"all_brewing.ui128.reagent_B": "reagent_b_pure_essence",
	"all_brewing.inventory.reagent_B.high_resolution": "reagent_b_pure_essence",
	"all_brewing.inventory.reagent_B.linear_downsampling": "reagent_b_pure_essence",
	"all_brewing.alchemy.reagent_B.high_resolution": "reagent_b_pure_essence",
	"all_brewing.alchemy.reagent_B.linear_downsampling": "reagent_b_pure_essence",
	"all_brewing.ui128.herb_A": "herb_a_pristine_bloom",
	"all_brewing.inventory.herb_A.high_resolution": "herb_a_pristine_bloom",
	"all_brewing.inventory.herb_A.linear_downsampling": "herb_a_pristine_bloom",
	"all_brewing.alchemy.herb_A.high_resolution": "herb_a_pristine_bloom",
	"all_brewing.alchemy.herb_A.linear_downsampling": "herb_a_pristine_bloom",
	"all_brewing.ui128.reagent_A": "reagent_a_radiant_essence",
	"all_brewing.inventory.reagent_A.high_resolution": "reagent_a_radiant_essence",
	"all_brewing.inventory.reagent_A.linear_downsampling": "reagent_a_radiant_essence",
	"all_brewing.alchemy.reagent_A.high_resolution": "reagent_a_radiant_essence",
	"all_brewing.alchemy.reagent_A.linear_downsampling": "reagent_a_radiant_essence"
}
const ALL_APPROVAL_CONTRACT_SHA256 := "ad86a32d398edc5244b507b042473bea92606fca6b61fe0f16f94a14ea812d94"
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
var all_sources_before := {}
var missing_upper := {}
var extra_captures: Array[String] = []
var all_matrix: Array[Dictionary] = []


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
	if r.flag("gear-pilots"):
		if not _check("gear_pilots.exclusive", not r.flag("baseline") and not r.flag("grade-pairs")
				and not r.flag("all-brewing") and not r.flag("world-prompts"), "two-pilot mode only"):
			return "gear-pilots conflicts with another mode"
		if not _gear_pilot_sources("before"): return "pilot asset approval failed"
	if r.flag("all-brewing") and not _check("mode.exclusive", not r.flag("grade-pairs"), "choose one optional ingredient mode"):
		return "--all-brewing and --grade-pairs are mutually exclusive"
	if r.flag("all-brewing"):
		var approval_error: String = _all_approval_check("before")
		if approval_error != "":
			return approval_error
		all_sources_before = _source_hashes()
		if not _check("all_brewing.source_map48", all_sources_before.size() == 48, all_sources_before.size()):
			return "material source map must contain35 world and13 approved UI entries"
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
	if r.flag("gear-pilots"): return await _gear_pilots()
	if r.flag("all-brewing"):
		var pair_error: String = await _grade_pairs()
		if pair_error != "":
			return pair_error
		return await _grade_pairs(ALL_INVENTORY_GRADES, UPPER_GRADES, "all_brewing", 9)
	if r.flag("grade-pairs"):
		return await _grade_pairs()
	return ""


func _grade_pairs(inventory_grades: Array = PAIR_GRADES, preview_grades: Array = PAIR_GRADES,
		prefix := "grade_pairs", first_capture := 6) -> String:
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
	var full_before: Dictionary = _full_browse_economy(alchemy) if r.flag("all-brewing") else {}
	var error: String = await _grade_pair_views(alchemy, inventory_grades, preview_grades, prefix, first_capture)
	# Release current callbacks before restoring their inspected inventory/view.
	m.close()
	p.materials = saved_materials
	if memory_present:
		m.set_meta("alchemy_view", saved_memory)
	elif m.has_meta("alchemy_view"):
		m.remove_meta("alchemy_view")
	Input.emulate_mouse_from_touch = saved_emulation
	for row in alchemy.rows:
		_check(prefix + "." + String(row.id), bool(row.passed), row.actual)
	_check(prefix + ".loan_restored", _economy() == before, ("four inspected stacks restored; no brew, purchase, claim or sale" if prefix == "grade_pairs" else "ten inspected stacks restored; no brew, purchase, claim or sale"))
	_check(prefix + ".files_unchanged", _source_hashes() == source_before, ("all35 legacy world PNGs and all seven UI file hashes unchanged during fixture" if not r.flag("all-brewing") else "all35 world and all13 UI file map entries unchanged"))
	if r.flag("all-brewing"):
		_check(prefix + ".full_loan_restored", _full_browse_economy(alchemy) == full_before,
			"full Alchemy economy, active profession and carried gear restored; no transaction")
		_check(prefix + ".view_restored", m.has_meta("alchemy_view") == memory_present
			and (not memory_present or m.get_meta("alchemy_view") == saved_memory), saved_memory)
		_check(prefix + ".touch_restored", Input.emulate_mouse_from_touch == saved_emulation, saved_emulation)
		_check(prefix + ".shell_closed", not m.is_open(), m.current)
	return error


func _grade_pair_views(alchemy: AlchemyProof, inventory_grades: Array = PAIR_GRADES,
		preview_grades: Array = PAIR_GRADES, prefix := "grade_pairs", first_capture := 6) -> String:
	r.step("optional E/D material pairs: exact F controls and loaned preview inventory" if prefix == "grade_pairs" else "all brewing: approved identities and loaned C/B/A previews")
	for stem in F_APPROVED_PNG:
		var path := "res://assets/icons/materials_ui/" + String(stem) + ".png"
		if not _check(prefix + ".accepted_F." + String(stem), FileAccess.file_exists(path)
				and FileAccess.get_sha256(path) == F_APPROVED_PNG[stem], path):
			return "accepted F pilot PNG changed or missing"
	var pair_textures := {}
	for grade in inventory_grades:
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			var legacy: Texture2D = Art.material_icon(family, grade)
			var icon: Texture2D = Art.material_ui_icon(family, grade)
			if not _check(prefix + ".legacy32." + id, legacy != null and legacy.get_size() == Vector2(32, 32), id):
				return "legacy world texture changed size or is missing"
			if not _check(prefix + ".texture_available." + id, icon != null, id):
				return "UI resolver returned no icon"
			_check(prefix + ".ui128." + id, icon.get_size() == Vector2(128, 128), str(icon.get_size()), true)
			pair_textures[id] = icon
			p.materials.append(Items.make_material(family, grade, 7))
	var browse_before: Dictionary = alchemy._economy()
	var full_browse_before: Dictionary = _full_browse_economy(alchemy) if r.flag("all-brewing") else {}
	m.open_inventory("gear", "all")
	await r.frames(4)
	for grade in inventory_grades:
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			_surface(prefix + ".inventory." + id, m.root, pair_textures[id], true)
	for family in PILOTS:
		_surface(prefix + ".inventory.F_" + String(family), m.root, textures[family], true)
	_surface(prefix + ".inventory.potion", m.root, Art.consumable_icon(potion), true, false)
	if prefix == "all_brewing":
		_surface(prefix + ".inventory.metal_E_fallback", m.root, Art.material_icon("metal", "E"), true, false)
		_all_inventory_receipt(pair_textures)
	await _capture("%02d_%s_inventory" % [first_capture, prefix])
	# Public Professions entry and actual bench/recipe/grade clicks; no trade lock
	# or mastery loan is needed to inspect the art. Resource actions stay untouched.
	m.open_professions()
	await r.frames(3)
	if not await alchemy._named("ProfessionsAlchemy", g.touch_mode):
		return "actual Professions Alchemy entry unavailable"
	if not await alchemy._named("AlchemyShape_mana_instant", g.touch_mode):
		return "actual mana recipe row unavailable"
	var capture_index := first_capture + 1
	for grade in preview_grades:
		if not await alchemy._named("AlchemyGrade_" + String(grade), g.touch_mode):
			return "actual grade selector unavailable"
		var recipe: Dictionary = Alchemy.recipe("mana_instant", grade)
		_check(prefix + ".recipe." + String(grade), alchemy._view().get("shape") == "mana_instant"
			and alchemy._view().get("grade") == grade and alchemy._text("AlchemyProductName") == String(recipe.item.name), alchemy._text("AlchemyProductName"))
		for family in PAIR_FAMILIES:
			var id := String(family) + "_" + String(grade)
			var icon: Texture2D = pair_textures[id]
			_surface(prefix + ".alchemy." + id, m.root, icon, false)
			var control := _texture_control(m.root, icon, false)
			if _check(prefix + ".alchemy.control." + id, control != null, id):
				_check(prefix + ".alchemy32." + id, _icon_rect(control, icon).size.is_equal_approx(Vector2(32, 32)), str(_icon_rect(control, icon)))
				var label_text := "%s · %s grade" % [String(Items.MATERIALS[family][grade]), grade]
				var found := false
				for child in control.get_parent().get_children():
					if child is Label and child.text == label_text:
						found = child.get_visible_line_count() == child.get_line_count()
				_check(prefix + ".identity." + id, found, label_text)
			var need := int(recipe.herbs) if family == "herb" else int(recipe.reagents)
			_check(prefix + ".count." + id, alchemy._text("AlchemyIngredient_" + String(family)).contains("Have 7 / Need %d" % need), alchemy._text("AlchemyIngredient_" + String(family)))
		var bottle: Texture2D = Art.consumable_icon(recipe.item)
		_surface(prefix + ".alchemy.bottle_" + String(grade), m.root, bottle, false, false)
		var product := _texture_control(m.root, bottle, false)
		if _check(prefix + ".alchemy.product." + String(grade), product != null, recipe.item.name):
			_check(prefix + ".alchemy64." + String(grade), _icon_rect(product, bottle).size.is_equal_approx(Vector2(64, 64)), str(_icon_rect(product, bottle)))
		await alchemy._recipe_caption("mana_instant", grade)
		alchemy._layout(("material_pair_" if prefix == "grade_pairs" else "all_brewing_") + String(grade))
		if prefix == "grade_pairs":
			await alchemy._capture("%02d_grade_pair_%s_alchemy" % [capture_index, String(grade).to_lower()])
		else:
			_all_recipe_receipt(alchemy, grade, recipe)
			await _capture("%02d_all_brewing_%s_alchemy" % [capture_index, String(grade).to_lower()])
		capture_index += 1
	_check(prefix + ".browse_no_economy_changes", alchemy._economy() == browse_before, "gold, mastery, materials, potions, blueprints, mail and favor unchanged")
	if r.flag("all-brewing"):
		_check(prefix + ".full_browse_unchanged", _full_browse_economy(alchemy) == full_browse_before, "active profession and full economy unchanged while browsing")
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
		if name.contains("_all_brewing_"):
			extra_captures.append(name)
		r.shot(name, "controlled ingredient display loans only; no collection, mastery, trade or transaction claim" if r.flag("all-brewing") else "three-material art pilot; controlled resource and presentation fixtures; no collection proof")


func _check(id: String, ok: bool, actual: Variant, presentation := false) -> bool:
	rows.append({"id": id, "passed": ok, "presentation": presentation, "actual": actual})
	print("MATERIAL CHECK %s: %s %s" % [id, "PASS" if ok else ("FINDING" if _expected_finding(id, presentation) else "FAIL"), str(actual) if not ok else ""])
	return ok


func _report() -> Dictionary:
	if r.flag("all-brewing"):
		_all_approval_check("after")
		_check("all_brewing.sources_restored", not all_sources_before.is_empty()
			and _source_hashes() == all_sources_before, "exact before/after48-entry material source map")
	var result := {"checks": rows.size(), "passed": 0, "findings": 0, "failures": 0, "rows": rows,
		"geometry": geometry, "baseline": r.flag("baseline"), "grade_pairs": r.flag("grade-pairs"),
		"mouse_clicks": native.mouse_clicks, "touch_taps": native.touch_taps,
		"source_hashes": _source_hashes(),
		"scope": ("three F pilots plus four E/D herb/reagent UI siblings and real Alchemy previews; " if r.flag("grade-pairs") else "three F-grade UI pilots; ")
			+ "32px world control; controlled loans; no real collection, crafting, persistence or hardware claim"}
	if r.flag("all-brewing"):
		result["all_brewing"] = true
		result["selected_ids"] = ALL_APPROVED_PNG.keys()
		result["approval_contract_sha256"] = ALL_APPROVAL_CONTRACT_SHA256
		result["missing_upper_baseline"] = missing_upper.keys()
		result["extra_captures"] = extra_captures
		result["all_brewing_matrix"] = all_matrix
		result["actual_shots"] = r.shots_taken
		result["scope"] = "13 approved ingredient UI identities; original F/world and E/D views retained; C/B/A preview only; controlled no_saves capital stock, no trade/mastery/blueprint grant or transaction; no ordinary collection or hardware claim"
	if r.flag("gear-pilots"):
		result["gear_pilots"] = true
		result["pilot_png_sha256"] = {"bone": r.arg("bone-f-sha256"), "cloth": r.arg("cloth-f-sha256")}
		result["actual_shots"] = r.shots_taken
		result["scope"] = "Two new BoneF/ClothF UI pilots; original six views and13UI/35world byte controls; controlled stock/native mouse-or-touch browsing; no collection/craft/sell/drop/claim/persistence/hardware proof"
	for row in rows:
		if row.passed: result.passed += 1
		elif _expected_finding(String(row.id), bool(row.presentation)): result.findings += 1
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
			if (String(grade) == "F" and PILOTS.has(String(family))) or ((r.flag("grade-pairs") or r.flag("all-brewing")) and PAIR_GRADES.has(String(grade)) and PAIR_FAMILIES.has(String(family))) or (r.flag("all-brewing") and UPPER_GRADES.has(String(grade)) and PAIR_FAMILIES.has(String(family))):
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


## These checks are active only in --all-brewing. Their constants are emitted
## by the approval preparation gate, never filled with pending hashes.
func _all_approval_check(phase: String) -> String:
	if not _check("all_brewing.approval_set." + phase, ALL_APPROVED_PNG.size() == 13
			and ALL_WORLD_PNG.size() == 35 and ALL_UPPER_IDS.size() == 6,
			"generated exact13 approved UI identities and35 unchanged world controls"):
		return "invalid generated approval contract"
	for stem: String in ALL_APPROVED_PNG:
		var path := "res://assets/icons/materials_ui/" + stem + ".png"
		var exists := FileAccess.file_exists(path)
		var missing_allowed: bool = r.flag("baseline") and ALL_UPPER_IDS.has(stem) and not exists
		var actual := FileAccess.get_sha256(path) if exists else "not_installed"
		if not _check("all_brewing.approved_bytes." + phase + "." + stem,
				missing_allowed or actual == ALL_APPROVED_PNG[stem], actual):
			return "approved material PNG missing or changed: " + stem
		if phase == "before" and missing_allowed:
			missing_upper[stem] = true
	for path: String in ALL_WORLD_PNG:
		if not _check("all_brewing.world_bytes." + phase + "." + path.get_file(),
				FileAccess.file_exists(path) and FileAccess.get_sha256(path) == ALL_WORLD_PNG[path], path):
			return "legacy world PNG changed: " + path
	return ""


func _expected_finding(id: String, presentation: bool) -> bool:
	if not presentation or not r.flag("baseline"):
		return false
	if not r.flag("all-brewing"):
		return true # Preserve historical default and --grade-pairs baseline semantics.
	# Every key below names one specific new identity and presentation location.
	# Missing files alone may use legacy fallback. Installed wrong bytes, old
	# seven, geometry, input, labels, counts, prompt gates and cleanup stay strict.
	if not ALL_BASELINE_PRESENTATION.has(id):
		return false
	return missing_upper.has(String(ALL_BASELINE_PRESENTATION[id]))


func _full_browse_economy(alchemy: AlchemyProof) -> Dictionary:
	var result: Dictionary = alchemy._economy()
	result["profession"] = p.profession
	result["backpack"] = p.backpack.duplicate(true)
	result["gem_bag"] = p.gem_bag.duplicate(true)
	result["loose_bags"] = p.loose_bags.duplicate(true)
	return result


func _all_inventory_receipt(pair_textures: Dictionary) -> void:
	var observed_ids: Array[String] = []
	var controls: Array[int] = []
	var fully_visible := 0
	for stem: String in ALL_APPROVED_PNG:
		var fields := stem.split("_")
		var family: String = fields[0]
		var grade: String = fields[1].to_upper()
		var texture: Texture2D = textures[family] if grade == "F" else pair_textures[family + "_" + grade]
		var control := _texture_control(m.root, texture, true)
		if not _check("all_brewing.inventory_identity." + stem, control != null, stem):
			continue
		controls.append(control.get_instance_id())
		var matching_stacks := 0
		for material: Dictionary in p.materials:
			if material.get("family") == family and material.get("grade") == grade:
				matching_stacks += 1
				_check("all_brewing.inventory_stack." + stem, int(material.get("count", 0)) == 7
					and String(material.get("name")) == String(Items.MATERIALS[family][grade]), material)
		_check("all_brewing.inventory_one_stack." + stem, matching_stacks == 1, matching_stacks)
		var badge_ok := false
		for child in control.get_children():
			if child is Label and child.text == "x7" and child.is_visible_in_tree():
				badge_ok = child.get_visible_line_count() == child.get_line_count() \
					and control.get_global_rect().grow(0.75).encloses(child.get_global_rect())
		_check("all_brewing.inventory_badge." + stem, badge_ok, "actual x7 child label fits its slot")
		# _surface performs the stricter ancestor/shell-clipping checks above.
		observed_ids.append(stem)
		var surface_id := "all_brewing.inventory." + ("F_" + family if grade == "F" else family + "_" + grade)
		for row: Dictionary in rows:
			if row.id == surface_id + ".visible_contained" and bool(row.passed):
				fully_visible += 1
	var unique := {}
	for instance_id in controls:
		unique[instance_id] = true
	_check("all_brewing.inventory_distinct13", observed_ids.size() == 13 and unique.size() == 13,
		{"identities": observed_ids, "distinct_slot_controls": unique.size()})
	_check("all_brewing.inventory_full13", fully_visible == 13, fully_visible)
	all_matrix.append({"view": "09_all_brewing_inventory", "identities": observed_ids, "fully_visible": fully_visible,
		"geometry_claim": "each full icon is separately checked against all clipping ancestors and shell",
		"stock": "seven-count display loans; no earned collection or trade grant"})


func _all_recipe_receipt(alchemy: AlchemyProof, grade: String, recipe: Dictionary) -> void:
	var expected: Dictionary = Alchemy.quote(g, "mana_instant", grade)
	_check("all_brewing.requirements." + grade,
		alchemy._text("AlchemyRequirements").contains("Grade " + grade)
		and (not Items.BLUEPRINT_GRADES.has(grade)
			or alchemy._text("AlchemyRequirements").contains("Blueprint known" if bool(expected.blueprint_known) else "Blueprint not learned")),
		alchemy._text("AlchemyRequirements"))
	_check("all_brewing.brew_gate." + grade, alchemy._disabled("AlchemyBrew") == (not bool(expected.allowed)),
		{"disabled": alchemy._disabled("AlchemyBrew"), "allowed": expected.allowed, "reason": expected.reason})
	all_matrix.append({"grade": grade, "shape": "mana_instant", "product": recipe.item.name,
		"herb": Items.MATERIALS.herb[grade], "reagent": Items.MATERIALS.reagent[grade],
		"herbs_need": recipe.herbs, "reagents_need": recipe.reagents, "have_each": 7,
		"requirements": alchemy._text("AlchemyRequirements"), "allowed": expected.allowed,
		"blocked_reason": expected.reason, "active_profession": p.profession,
		"blueprint_known": expected.blueprint_known, "inspection_only": true})


# Optional two-pilot extension; original six views/modes are unchanged.
func _gear_pilot_sources(phase: String) -> bool:
	var ok := true
	for stem: String in ALL_APPROVED_PNG:
		ok = _check("gear_pilots." + phase + ".old_ui." + stem,
			FileAccess.get_sha256("res://assets/icons/materials_ui/" + stem + ".png") == ALL_APPROVED_PNG[stem], stem) and ok
	for path: String in ALL_WORLD_PNG:
		ok = _check("gear_pilots." + phase + ".world." + path.get_file(),
			FileAccess.get_sha256(path) == ALL_WORLD_PNG[path], path) and ok
	for family: String in ["bone", "cloth"]:
		var stem := Items.material_stem(family, "F", Items.MATERIALS[family].F)
		var path := "res://assets/icons/materials_ui/" + stem + ".png"
		var expected: String = r.arg(family + "-f-sha256")
		var valid := expected.length() == 64
		for character in expected: valid = valid and "0123456789abcdef".contains(character)
		if not _check("gear_pilots." + phase + ".approved_file." + family, valid
				and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected, expected):
			ok = false
			continue
		# Raw PNG approval is distinct from Godot's imported alpha processing.
		var source: Image = Image.load_from_file(path)
		var imported: Texture2D = load(path) as Texture2D
		var texture: Texture2D = Art.material_ui_icon(family, "F")
		if not _check("gear_pilots." + phase + ".loaded." + family,
				source != null and imported != null and texture != null, family):
			ok = false
			continue
		var expected_image: Image = imported.get_image()
		var sampled: Image = texture.get_image()
		if not _check("gear_pilots." + phase + ".sampled." + family,
				expected_image != null and sampled != null, family):
			ok = false
			continue
		source.convert(Image.FORMAT_RGBA8)
		expected_image.convert(Image.FORMAT_RGBA8)
		sampled.convert(Image.FORMAT_RGBA8)
		ok = _check("gear_pilots." + phase + ".raw_source_size." + family,
			source.get_size() == Vector2i(128, 128), str(source.get_size())) and ok
		ok = _check("gear_pilots." + phase + ".pixel_identity." + family,
			expected_image.get_size() == Vector2i(128, 128) and sampled.get_size() == expected_image.get_size()
			and sampled.get_data() == expected_image.get_data() and Art.material_ui_icon(family, "F") == texture,
			{"imported_px": str(expected_image.get_size()), "sampled_px": str(sampled.get_size())}) and ok
		var bytes: PackedByteArray = source.get_data()
		var clear := 0
		var body := 0
		for index in range(3, bytes.size(), 4):
			clear += int(bytes[index] == 0)
			body += int(bytes[index] > 128)
		ok = _check("gear_pilots." + phase + ".alpha." + family, clear > 0 and body > 0,
			{"clear_pixels": clear, "body_pixels": body}) and ok
	return ok


func _gear_pilot_ledger() -> Dictionary:
	var result := {}
	for key in ["gold", "profession", "mastery", "materials", "backpack", "gem_bag", "consumables",
			"blueprints", "npc_favor", "bags", "loose_bags", "equipment"]:
		var value: Variant = p.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	result["mailbox"] = g.mailbox.duplicate(true)
	result["loot"] = [g.loot_rng.seed, g.loot_rng.state]
	return result


func _gear_pilots() -> String:
	var saved := _gear_pilot_ledger()
	var emulation := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	for family in ["bone", "cloth"]:
		p.materials.append(Items.make_material(family, "F", 7))
	g.mailbox = [{"subject": "Gear material pilots", "body": "Controlled art inspection; no collection or claim.",
		"read": true, "sent_at": g.trusted_now(), "items": [
			{"kind": "material", "family": "bone", "grade": "F", "count": 7},
			{"kind": "material", "family": "cloth", "grade": "F", "count": 7}]}]
	var before := _gear_pilot_ledger()
	var error: String = await _gear_pilot_views()
	_check("gear_pilots.browse_unchanged", _gear_pilot_ledger() == before,
		"full character pockets, mailbox and loot RNG unchanged before restoration")
	m.close()
	for key in saved:
		if key not in ["mailbox", "loot"]: p.set(key, saved[key])
	g.mailbox = saved.mailbox
	g.loot_rng.seed = int(saved.loot[0])
	g.loot_rng.state = int(saved.loot[1])
	Input.emulate_mouse_from_touch = emulation
	_check("gear_pilots.restored", _gear_pilot_ledger() == saved, "fixture loans restored after success or returned failure")
	if not _gear_pilot_sources("after") and error == "": error = "pilot sources changed"
	return error


func _gear_pilot_click(control: Control, id: String) -> bool:
	if not _check("gear_pilots.input." + id, is_instance_valid(control), id): return false
	await _reveal(control)
	var rect := control.get_global_rect()
	if not _check("gear_pilots.target." + id, control.is_visible_in_tree()
			and not (control is BaseButton and control.disabled)
			and m._shell_rect.encloses(rect) and m.get_viewport().get_visible_rect().encloses(rect), str(rect)): return false
	if g.touch_mode: await native._touch(rect.get_center())
	else: await native._mouse(rect.get_center())
	await r.frames(3)
	return true


func _gear_pilot_shot(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "Bone F and Cloth F UI art only; loaned stock, native browsing, no payment/claim/drop or collection proof")


func _gear_pilot_views() -> String:
	m.open_inventory("gear", "all")
	await r.frames(3)
	for family in ["bone", "cloth"]:
		_surface("gear_pilots.inventory." + family, m.root, Art.material_ui_icon(family, "F"), true)
	await _gear_pilot_shot("06_gear_pilot_inventory")
	for family in ["bone", "cloth"]:
		m.open_inventory("gear", "all")
		await r.frames(3)
		var texture: Texture2D = Art.material_ui_icon(family, "F")
		if not await _gear_pilot_click(_texture_control(m.root, texture, true), "inventory_" + family): return "pilot slot unavailable"
		if not _check("gear_pilots.detail_open." + family, is_instance_valid(m.detail_popover), family): return "pilot detail failed"
		_surface("gear_pilots.detail." + family, m.detail_popover, texture, false)
		await _gear_pilot_shot("07_gear_pilot_detail_" + family)
	UIMailbox.open(m)
	await r.frames(3)
	if not await _gear_pilot_click(native._find_button(m.root, "Gear material pilots"), "letter"): return "pilot letter unavailable"
	for family in ["bone", "cloth"]:
		_surface("gear_pilots.mail." + family, m.root, Art.material_ui_icon(family, "F"), true)
	await _gear_pilot_shot("08_gear_pilot_mail")
	for family in ["bone", "cloth"]:
		var texture: Texture2D = Art.material_ui_icon(family, "F")
		if not await _gear_pilot_click(_texture_control(m.root, texture, true), "mail_" + family): return "pilot mail slot unavailable"
		if not _check("gear_pilots.mail_detail_open." + family, is_instance_valid(m.detail_popover), family): return "mail detail failed"
		_surface("gear_pilots.mail_detail." + family, m.detail_popover, texture, false)
		await _gear_pilot_shot("09_gear_pilot_mail_detail_" + family)
		m._close_detail_popover()
		await r.frames(2)
	m.open_shop(g.cur_room, "buy")
	await r.frames(3)
	if not await _gear_pilot_click(native._find_button(m.root, "Sell", true), "sell_tab"): return "merchant tab unavailable"
	for family in ["bone", "cloth"]:
		var texture: Texture2D = Art.material_ui_icon(family, "F")
		var control := _texture_control(m.root, texture, false)
		if not _check("gear_pilots.merchant_control." + family, is_instance_valid(control), family): return "merchant pilot missing"
		await _reveal(control)
		_surface("gear_pilots.merchant." + family, m.root, texture, false)
		await _gear_pilot_shot("10_gear_pilot_merchant_" + family)
	for family in ["bone", "cloth"]:
		m.open_professions()
		await r.frames(3)
		var trade := "alchemist" if family == "bone" else "tailor"
		var slot := "charm" if family == "bone" else "armor"
		for name: String in ["ProfTrade_" + trade, "ProfTab_craft", "ProfSlot_" + slot, "ProfGrade_F"]:
			if not await _gear_pilot_click(m.root.find_child(name, true, false) as Control, name): return "workshop navigation unavailable"
		_surface("gear_pilots.workshop." + family, m.root, Art.material_ui_icon(family, "F"), false)
		var title := m.root.find_child("ProfRecipeName", true, false) as Label
		var counts := m.root.find_child("ProfIngredient", true, false) as Label
		_check("gear_pilots.workshop_identity." + family, title != null and title.text == slot.capitalize() + " — grade F"
			and counts != null and counts.text == "Have 7 / Need %d" % int(Balance.CRAFT_MATERIAL_COST.F), family)
		await _gear_pilot_shot("11_gear_pilot_workshop_" + family)
	return ""
