extends RefCounted
## UI proof only: all resources and mastery are explicitly loaned fixtures.
## Save roundtrips, real collection and ENet ownership have separate coverage.
const Alchemy := preload("res://scripts/alchemy.gd")
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")

var r: ShotRig
var g: Game
var m: Menus
var p: Player
var native: NativeInput
var rows: Array[Dictionary] = []
var stale_signals := 0
var detail_frame_observations: Array[Dictionary] = []
var detail_touch_observations: Array[Dictionary] = []


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
	var language: String = Loc.lang
	var emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	Loc.lang = "en"
	proof._touch_mode(false)
	var error: String = await proof._run()
	proof._check("runtime.completed", error == "", error)
	proof.g.settings = settings
	Loc.lang = language
	Input.emulate_mouse_from_touch = emulation
	proof.g.refresh_touch_mode()
	proof.g._apply_touch_mode()
	proof.m.close()
	proof.g.hud.cancel_conversation()
	proof.g.request_pause(false)
	await rig.frames(3)
	proof._check("input.released", not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not Input.is_key_pressed(KEY_ESCAPE), "native presses released")
	return proof._report()


func _run() -> String:
	if not _check("fixture.isolated_capital", g.no_saves and not g.net_online()
			and g.chapter_id == "capital" and is_instance_valid(g.world), g.chapter_id):
		return "requires isolated no-saves Crownfall fixture"
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.dev_god = true
	p.profession = ""
	p.mastery = {}
	p.blueprints = []
	p.npc_favor = {}
	p.gold = 1000000
	p.backpack = []
	p.gem_bag = []
	p.loose_bags = []
	p.consumables = []
	p.materials = []
	g.mailbox = []
	if m.has_meta("alchemy_view"):
		m.remove_meta("alchemy_view")
	r.step("controlled fixture: fresh trade, no ingredients; actual Professions entry")
	g._hub_action("professions")
	await r.frames(3)
	if not await _named("ProfessionsAlchemy"):
		return "Professions brewing entry missing"
	_check("entry.no_trade_inspectable", m.current == "alchemy" and _disabled("AlchemyBrew")
		and _text("AlchemyResult").contains("active trade"), _text("AlchemyResult"))
	_layout("desktop_no_trade")
	await _capture("00_no_trade_inspectable")
	if not await _named("AlchemyReturn"):
		return "Alchemy return unavailable"
	var trade_before := _economy()
	if not await _named("ProfTrade_alchemist"):
		return "Alchemist trade preview unavailable"
	_check("trade.preview_read_only", _economy() == trade_before, "browsing cannot spend or choose a trade")
	if not await _named("ProfActivate"):
		return "actual first Alchemist lock unavailable"
	_check("trade.first_lock", p.profession == "alchemist" and Professions.points(p) == 0, p.profession)
	if not await _named("ProfessionsAlchemy"):
		return "entry after trade lock missing"
	await _named("AlchemyGrade_D")
	_check("novice.mastery_blocked", _disabled("AlchemyBrew") and _text("AlchemyResult").contains("mastery"), _text("AlchemyResult"))
	await _named("AlchemyGrade_F")
	_check("novice.ingredients_blocked", _disabled("AlchemyBrew") and _text("AlchemyIngredient_herb").contains("Short")
		and _text("AlchemyIngredient_reagent").contains("Short"), _text("AlchemyResult"))
	await _capture("01_insufficient_ingredients")
	_loan_materials(["F"])
	await _reenter()
	await _brew("novice_pack", false)
	_check("novice.mastery_earned", Professions.points(p, "alchemist") == int(Alchemy.recipe("health_instant", "F").mastery_gain), p.mastery)
	await _capture("02_novice_brewed")
	r.step("controlled fixture: master preview; all seven names and all39 clean grades")
	p.mastery["alchemist"] = int(Balance.MASTERY_THRESHOLDS.Master)
	_loan_materials(["F", "E", "D", "C", "B", "A"])
	await _reenter()
	var selection_before := _economy()
	var inspected := 0
	for raw in Alchemy.shapes():
		var shape := String(raw)
		if not await _named("AlchemyShape_" + shape):
			return "recipe rail missing " + shape
		for grade in Alchemy.grades(shape):
			await _named("AlchemyGrade_" + grade)
			var recipe: Dictionary = Alchemy.recipe(shape, grade)
			_check("preview.%s.%s" % [shape, grade], _text("AlchemyProductName") == String(recipe.item.name)
				and _text("AlchemyProductEffect") == String(recipe.item.desc), _text("AlchemyProductName"))
			_check("preview.costs.%s.%s" % [shape, grade],
				_text("AlchemyIngredient_herb").contains("Have %d / Need %d" % [p.material_count("herb", grade), int(recipe.herbs)])
				and _text("AlchemyIngredient_reagent").contains("Have %d / Need %d" % [p.material_count("reagent", grade), int(recipe.reagents)]),
				[_text("AlchemyIngredient_herb"), _text("AlchemyIngredient_reagent")])
			await _recipe_caption(shape, grade)
			inspected += 1
		_check("preview.no_S_Grand." + shape, _node("AlchemyGrade_S") == null and _node("AlchemyGrade_Grand") == null, shape)
	_check("preview.all39_read_only", inspected == 39 and _economy() == selection_before, inspected)
	_check("renewal.only_C_B_A", _node("AlchemyGrade_F") == null and _node("AlchemyGrade_E") == null
		and _node("AlchemyGrade_D") == null and _node("AlchemyGrade_C") != null, _view())
	_layout("desktop_renewal_A")
	await _capture("03_renewal_A_blueprint_unknown")
	await _detail_disclosure("renewal_unknown", false)
	await _blueprints()
	await _mail_and_retention()
	await _stale_input()
	await _touch_and_controller()
	return ""


func _check_blueprint_contract(id: String) -> void:
	var title: Label = native._confirm_label("Learn blueprint?")
	var learn: Button = native._find_button(m.root, "Learn blueprint", true)
	var cancel: Button = native._find_button(m.root, "Cancel", true)
	_check("blueprint.contextual." + id, m.current == "confirm" and title != null
		and native._confirm_glyphs_complete(title) and learn != null and cancel != null
		and native._find_button(m.root, "Yes — do it", true) == null, "Learn blueprint? / Learn blueprint / Cancel")


func _blueprints() -> void:
	r.step("real blueprint gate: Cancel, Escape, X, outside and purchase")
	await _named("AlchemyGrade_B")
	for route in ["cancel", "escape", "x", "outside"]:
		var before := _economy()
		await _named("AlchemyLearnBlueprint")
		_check("blueprint.confirm." + route, m.current == "confirm", m.current)
		_check_blueprint_contract(route)
		await _exit(route)
		_check("blueprint.cancel." + route, m.current == "alchemy" and _economy() == before
			and String(_view().get("shape", "")) == "renewal" and String(_view().get("grade", "")) == "B", _view())
	await _named("AlchemyGrade_A")
	var before := _economy()
	var quote: Dictionary = Alchemy.quote(g, "renewal", "A", "blueprint")
	await _named("AlchemyLearnBlueprint")
	_check_blueprint_contract("purchase")
	await _capture("03b_renewal_A_blueprint_confirm")
	await _text_button("Learn blueprint")
	_check("blueprint.purchase_returns", m.current == "alchemy" and _text("AlchemyResult").begins_with("Learned "), _text("AlchemyResult"))
	_check("blueprint.purchase_exact", p.gold == int(before.gold) - int(quote.fee)
		and p.has_blueprint(Items.potion_blueprint_slot("renewal"), "A")
		and p.mastery == before.mastery and p.materials == before.materials
		and p.consumables == before.consumables and g.mailbox == before.mailbox
		and p.npc_favor == before.favor, {"gold": p.gold, "fee": quote.fee})
	_check("blueprint.learned_state", _node("AlchemyLearnBlueprint") == null
		and _text("AlchemyRequirements").contains("Blueprint known"), _text("AlchemyRequirements"))
	_layout("desktop_learned")
	await _capture("04_renewal_A_learned")


func _mail_and_retention() -> void:
	r.step("controlled full pack: mailed output and retained filter/scroll/focus")
	var filler: Dictionary = Alchemy.recipe("health_instant", "F").item
	while p.bag_used() < p.bag_capacity():
		p.consumables.append(filler.duplicate(true))
	_check("fixture.full_pack", p.bag_used() == p.bag_capacity(), [p.bag_used(), p.bag_capacity()])
	await _reenter()
	await _named("AlchemyFilter_ready")
	await _named("AlchemySources")
	await _scroll_down("AlchemyRecipeScroll", 7)
	await _scroll_down("AlchemyDetailScroll", 7)
	var rail: ScrollContainer = _node("AlchemyRecipeScroll") as ScrollContainer
	var details: ScrollContainer = _node("AlchemyDetailScroll") as ScrollContainer
	var expected_rail := rail.scroll_vertical
	var expected_detail := details.scroll_vertical
	_check("retention.scroll_exercised", expected_rail > 0 or expected_detail > 0, [expected_rail, expected_detail])
	await _brew("full_pack_mail", true)
	rail = _node("AlchemyRecipeScroll") as ScrollContainer
	details = _node("AlchemyDetailScroll") as ScrollContainer
	var focus: Control = m.get_viewport().gui_get_focus_owner()
	_check("retention.selection_filter", String(_view().get("shape", "")) == "renewal"
		and String(_view().get("grade", "")) == "A" and String(_view().get("filter", "")) == "ready", _view())
	_check("retention.scroll", absi(rail.scroll_vertical - expected_rail) <= 1
		and absi(details.scroll_vertical - expected_detail) <= 1, [rail.scroll_vertical, details.scroll_vertical, expected_rail, expected_detail])
	_check("retention.focus", is_instance_valid(focus) and focus.name == "AlchemyBrew", String(focus.name) if is_instance_valid(focus) else "none")
	_layout("desktop_mail")
	await _capture("05_full_pack_mailed")


func _stale_input() -> void:
	r.step("held pointer stale quote; same-frame retired shell and duplicate callbacks")
	# Pause-free UI watcher sees a held mouse and must not replace the target.
	var brew := _node("AlchemyBrew") as Button
	if not _check("stale_quote.brew_available", brew != null and not brew.disabled, "Renewal A has fixture materials"):
		return
	var old_shell: Control = m.root
	var at := brew.get_global_rect().get_center()
	_pointer(true, at)
	await r.frames(1)
	p.mastery["alchemist"] = Professions.points(p, "alchemist") + 1
	var before := _economy()
	await r.sim_wait(Balance.ACTIVITY_BOARD_REFRESH + 0.1)
	_check("stale_quote.held_target_stable", m.root == old_shell, m.current)
	_pointer(false, at)
	native.mouse_clicks += 1
	await r.frames(4)
	_check("stale_quote.no_spend", _economy() == before and _text("AlchemyResult").contains("quote changed"), _text("AlchemyResult"))
	# Actual Back changes the shell synchronously. Emit the old signal ONLY in
	# this same frame while its queued node remains valid, never after an await.
	brew = _node("AlchemyBrew") as Button
	before = _economy()
	_escape_now()
	var destination: Control = m.root
	if _check("stale_shell.old_control_still_valid", is_instance_valid(brew), "same-frame queued Button"):
		brew.pressed.emit()
		stale_signals += 1
	_check("stale_shell.no_spend_or_reopen", m.current == "professions" and m.root == destination and _economy() == before, m.current)
	await r.frames(3)
	await _named("ProfessionsAlchemy")
	# One real native activation, followed by a duplicate signal on the retired
	# node before queue_free drains. The transaction must still occur only once.
	brew = _node("AlchemyBrew") as Button
	before = _economy()
	var quote: Dictionary = Alchemy.quote(g, "renewal", "A")
	at = brew.get_global_rect().get_center()
	_pointer(true, at)
	_pointer(false, at)
	native.mouse_clicks += 1
	if _check("duplicate.old_control_still_valid", is_instance_valid(brew), "same-frame queued Button"):
		brew.pressed.emit()
		brew.pressed.emit()
		stale_signals += 2
	await r.frames(3)
	_check("duplicate.exactly_one_brew", p.gold == int(before.gold) - int(quote.fee)
		and g.mailbox.size() == Array(before.mailbox).size() + 1
		and Professions.points(p, "alchemist") == int(before.mastery.get("alchemist", 0)) + int(quote.mastery_gain), _text("AlchemyResult"))
	await _named("AlchemyGrade_B")
	await _named("AlchemyLearnBlueprint")
	_check_blueprint_contract("stale")
	var yes: Button = native._find_button(m.root, "Learn blueprint", true)
	before = _economy()
	_escape_now()
	destination = m.root
	if _check("stale_confirm.yes_still_valid", is_instance_valid(yes), "same-frame queued Yes"):
		yes.pressed.emit()
		stale_signals += 1
	_check("stale_confirm.no_purchase", m.current == "alchemy" and m.root == destination and _economy() == before, m.current)
	await r.frames(3)
	# Idle quote refresh should preserve selection and explain the new shortage.
	p.materials = []
	await r.sim_wait(Balance.ACTIVITY_BOARD_REFRESH + 0.2)
	_check("watcher.no_stale_affordance", _disabled("AlchemyBrew") and _text("AlchemyIngredient_herb").contains("Short"), _text("AlchemyResult"))
	_loan_materials(["F", "E", "D", "C", "B", "A"])
	p.consumables = []
	await _reenter()


func _touch_and_controller() -> void:
	r.step("touch selection and dismissal; real gamepad Back")
	_touch_mode(true)
	await _reenter(true)
	await _named("AlchemyFilter_all", true)
	await _named("AlchemyShape_mana_tonic", true)
	await _named("AlchemyGrade_E", true)
	_check("touch.recipe_selected", _text("AlchemyProductName") == String(Alchemy.recipe("mana_tonic", "E").item.name), _text("AlchemyProductName"))
	_layout("touch_mana_tonic")
	await _capture("06_touch_mana_tonic")
	await _detail_disclosure("mana_E", true)
	await native._touch(Vector2(12, 12))
	await r.frames(4)
	_check("touch.outside_exact_parent", m.current == "professions", m.current)
	await _named("ProfessionsAlchemy", true)
	await native._joy_back()
	_check("controller.back_exact_parent", m.current == "professions", m.current)
	await _named("ProfessionsAlchemy", true)
	await _named("AlchemyGrade_B", true)
	var before := _economy()
	await _named("AlchemyLearnBlueprint", true)
	await native._joy_back()
	_check("controller.blueprint_cancel", m.current == "alchemy" and _economy() == before, m.current)
	await _named("AlchemyLearnBlueprint", true)
	await native._touch(Vector2(12, 12))
	await r.frames(4)
	_check("touch.blueprint_cancel_once", m.current == "alchemy" and _economy() == before, m.current)
	await native._key(KEY_ESCAPE)
	_check("escape.final_parent", m.current == "professions", m.current)


## Actual sources toggle and native scroll; fixture supplies resources only.
func _detail_disclosure(id: String, touch: bool) -> void:
	var before: Dictionary = _economy()
	var selection: Dictionary = _view().duplicate(true)
	# Both states get a real release-triggered first-draw observation, even if
	# this recipe was already settled in its collapsed state on entry.
	if not bool(_view().get("sources", false)):
		await _named("AlchemySources", touch)
	if not await _detail_toggle_frames(id + "_collapsed", touch, false): return
	_detail_metadata(id + ".collapsed")
	_detail_fixed_learning(id + ".collapsed", id == "renewal_unknown")
	await _detail_sources_contrast(id + ".collapsed")
	var scroll := _node("AlchemyDetailScroll") as ScrollContainer
	if not _check("detail." + id + ".scroll_identity", scroll != null, "remembered detail control retained"): return
	if not scroll.visible:
		var requirement := _node("AlchemyRequirements") as Label
		var fixed_note := _node("AlchemyLearnNote") as Label
		var last_metadata: Control = fixed_note if fixed_note != null else requirement
		var rule := _node("AlchemyIngredientRule") as Control
		var gap: float = rule.get_global_rect().position.y - last_metadata.get_global_rect().end.y
		_check("detail." + id + ".collapsed_compact", gap >= 4.0 and gap <= 24.0, gap)
	await _capture("07_detail_" + id + "_collapsed")
	if not await _detail_toggle_frames(id + "_expanded", touch, true): return
	_check("detail." + id + ".expanded", bool(_view().get("sources", false)), _view())
	_detail_metadata(id + ".expanded")
	_detail_fixed_learning(id + ".expanded", id == "renewal_unknown")
	await _detail_sources_contrast(id + ".expanded")
	# Toggling rebuilds the shell: reacquire every node after the native input.
	scroll = _node("AlchemyDetailScroll") as ScrollContainer
	var brew := _node("AlchemyBrew") as Button
	var tail := _node("AlchemySourceTail") as Label
	if not _check("detail." + id + ".nodes", scroll != null and scroll.visible and brew != null and tail != null, _view()): return
	var brew_rect: Rect2 = brew.get_global_rect()
	var fixed_learning: Dictionary = _detail_learning_rects()
	var optional_overflows: bool = scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 0.5
	if id == "renewal_unknown":
		_check("detail." + id + ".long_help_overflows", optional_overflows, scroll.get_v_scroll_bar().max_value)
	await _scroll_down("AlchemyDetailScroll", 12)
	_check("detail." + id + ".wheel_tail", _detail_tail_visible(tail, scroll), tail.text)
	_check("detail." + id + ".wheel_fixed_actions", brew.get_global_rect() == brew_rect and not scroll.is_ancestor_of(brew), str(brew_rect))
	_check("detail." + id + ".wheel_fixed_learning", _detail_learning_rects() == fixed_learning, {"before": fixed_learning, "after": _detail_learning_rects()})
	_detail_fixed_learning(id + ".wheel", id == "renewal_unknown")
	for index in 12: await native._wheel(MOUSE_BUTTON_WHEEL_UP, scroll.get_global_rect().get_center())
	_check("detail." + id + ".native_top", scroll.scroll_vertical == 0, scroll.scroll_vertical)
	var touch_before: int = scroll.scroll_vertical
	var previous_touch: bool = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var rect: Rect2 = scroll.get_global_rect()
	var start := Vector2(rect.get_center().x, rect.end.y - 8.0)
	var finish := Vector2(rect.get_center().x, rect.position.y + 8.0)
	var touch_peak: int = touch_before
	for index in 12:
		await native._confirm_touch_drag(start, finish)
		touch_peak = maxi(touch_peak, scroll.scroll_vertical)
	Input.emulate_touch_from_mouse = previous_touch
	var touch_evidence := {"id": id, "overflow": optional_overflows, "start": touch_before,
		"peak": touch_peak, "end": scroll.scroll_vertical, "tail_visible": _detail_tail_visible(tail, scroll),
		"scroll_proof": optional_overflows and touch_before == 0 and touch_peak > touch_before,
		"scope": "native overflowing touch scroll" if optional_overflows else "content fits; touch no-op is NOT scroll proof"}
	detail_touch_observations.append(touch_evidence)
	if optional_overflows:
		_check("detail." + id + ".touch_moves_from_top", touch_before == 0 and touch_peak > touch_before, touch_evidence)
	else:
		_check("detail." + id + ".touch_fit_no_scroll_claim", touch_before == 0 and touch_peak == 0 and scroll.scroll_vertical == 0, touch_evidence)
	_check("detail." + id + ".touch_tail", bool(touch_evidence.tail_visible), touch_evidence)
	_check("detail." + id + ".touch_fixed_actions", brew.get_global_rect() == brew_rect, str(brew.get_global_rect()))
	_check("detail." + id + ".touch_fixed_learning", _detail_learning_rects() == fixed_learning, {"before": fixed_learning, "after": _detail_learning_rects()})
	_detail_fixed_learning(id + ".touch", id == "renewal_unknown")
	_detail_metadata(id + ".scrolled")
	_layout("detail_" + id)
	await _capture("08_detail_" + id + "_expanded_tail")
	if not bool(selection.get("sources", false)):
		await _named("AlchemySources", touch)
	_check("detail." + id + ".read_only", _economy() == before
		and _view().get("shape") == selection.get("shape") and _view().get("grade") == selection.get("grade")
		and _view().get("sources") == selection.get("sources"), _view())


func _detail_learning_rects() -> Dictionary:
	var rects := {}
	for name in ["AlchemyLearnBlueprint", "AlchemyLearnNote"]:
		var node := _node(name) as Control
		if node != null:
			var rect: Rect2 = node.get_global_rect()
			rects[name] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return rects


func _detail_fixed_learning(id: String, expected: bool) -> void:
	var learn := _node("AlchemyLearnBlueprint") as Button
	var note := _node("AlchemyLearnNote") as Label
	var scroll := _node("AlchemyDetailScroll") as ScrollContainer
	var brew := _node("AlchemyBrew") as Button
	if not _check("detail." + id + ".learning_presence", (learn != null and note != null) if expected else (learn == null and note == null), _detail_learning_rects()): return
	if not expected: return
	var allowed: Rect2 = m._shell_rect.intersection(m.get_viewport().get_visible_rect())
	var ancestor: Node = learn.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	var rect: Rect2 = learn.get_global_rect()
	_check("detail." + id + ".learning_fixed", scroll != null and not scroll.is_ancestor_of(learn) and not scroll.is_ancestor_of(note)
		and brew != null and learn.get_parent() == brew.get_parent(), _detail_learning_rects())
	_check("detail." + id + ".learning_target44", learn.is_visible_in_tree() and rect.size.x >= 44.0 and rect.size.y >= 44.0
		and allowed.grow(0.5).encloses(rect), str(rect))
	_check("detail." + id + ".learning_note_glyphs", _detail_glyphs_visible(note, 2.0), note.text)


## Sample the real normal-fill pixels after moving the pointer off the tab.
## Contrast uses the native normal font color, not a source-constant equality.
func _detail_sources_contrast(id: String) -> void:
	var button := _node("AlchemySources") as Button
	if not _check("detail." + id + ".sources_contrast_control", button != null, "actual Sources tab"): return
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 100)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await r.frames(2)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(button):
		_check("detail." + id + ".sources_normal_contrast", false, "shell replaced during measurement")
		return
	var image: Image = r.capture_image()
	var rect: Rect2 = button.get_global_rect()
	var viewport: Rect2 = m.get_viewport().get_visible_rect()
	var sample := Vector2(rect.position.x + 18.0, rect.get_center().y)
	var pixel := Vector2i(roundi((sample.x - viewport.position.x) * image.get_width() / viewport.size.x), roundi((sample.y - viewport.position.y) * image.get_height() / viewport.size.y))
	var background: Color = image.get_pixelv(pixel)
	var foreground: Color = button.get_theme_color("font_color")
	var bg_luminance: float = background.srgb_to_linear().get_luminance()
	var fg_luminance: float = foreground.srgb_to_linear().get_luminance()
	var ratio: float = (maxf(bg_luminance, fg_luminance) + 0.05) / (minf(bg_luminance, fg_luminance) + 0.05)
	_check("detail." + id + ".sources_normal_contrast", button.get_draw_mode() == BaseButton.DRAW_NORMAL and foreground.a >= 0.999 and ratio >= 4.5,
		{"ratio": ratio, "minimum": 4.5, "normal_font": str(foreground), "rendered_background": str(background), "sample_pixel": str(pixel),
		"draw_mode": button.get_draw_mode(), "scope": "normal font against actual interior normal-fill pixel; original review still required"})


## First-draw continuity after native release; originals still require review.
## Press may occupy an old frame; observe immediately after native release.
func _detail_toggle_frames(id: String, touch: bool, expanded: bool) -> bool:
	var preparation: Dictionary = await _detail_prepare_selected()
	if not _check("detail.frames." + id + ".selected_precondition", bool(preparation.visible), preparation): return false
	var expected := {}
	var button := _node("AlchemySources") as Button
	if not _check("detail.frames." + id + ".button", button != null and not button.disabled, "actual sources control"): return false
	await _reveal(button)
	var at: Vector2 = button.get_global_rect().get_center()
	var old_root_id: int = m.root.get_instance_id()
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await r.frames(1)
		expected = _detail_continuity()
		event = InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		native.touch_taps += 1
	else:
		_pointer(true, at)
		await r.frames(1)
		expected = _detail_continuity()
		_pointer(false, at)
		native.mouse_clicks += 1
	await RenderingServer.frame_post_draw
	var first: Dictionary = _detail_frame_geometry()
	first.continuity = _detail_continuity()
	var first_path := "" if r.flag("no-capture") else r.shot("09_detail_" + id + "_first_draw", "first observed native draw after sources release; geometry not yet accepted")
	if not _check("detail.frames." + id + ".native_replaced", m.current == "alchemy" and is_instance_valid(m.root) and m.root.get_instance_id() != old_root_id
		and bool(_view().get("sources", false)) == expanded, first): return false
	var observed_root_id: int = m.root.get_instance_id()
	await r.frames(4)
	await RenderingServer.frame_post_draw
	var settled: Dictionary = _detail_frame_geometry()
	settled.continuity = _detail_continuity()
	var settled_path := "" if r.flag("no-capture") else r.shot("09_detail_" + id + "_settled", "settled native disclosure; compare exact first-draw geometry/original")
	var delta := 0.0
	for name in first.rects:
		if not settled.rects.has(name): continue
		for component in 4:
			delta = maxf(delta, absf(float(first.rects[name][component]) - float(settled.rects[name][component])))
	var observation := {"id": id, "first": first, "settled": settled, "max_rect_delta_px": delta,
		"geometry_changed": first.rects != settled.rects, "first_original": first_path,
		"settled_original": settled_path, "expected_before_release": expected, "selection_preparation": preparation,
		"acceptance": "strict native continuity checks; original-image review remains required"}
	detail_frame_observations.append(observation)
	for phase in ["first", "settled"]:
		var actual: Dictionary = first.continuity if phase == "first" else settled.continuity
		_check("detail.frames." + id + "." + phase + ".selection", actual.shape == expected.shape and actual.grade == expected.grade
			and actual.filter == expected.filter, actual)
		_check("detail.frames." + id + "." + phase + ".rail_scroll", actual.rail_scroll == expected.rail_scroll, {"expected": expected, "actual": actual})
		_check("detail.frames." + id + "." + phase + ".focus", not String(expected.focus).is_empty() and actual.focus == expected.focus, {"expected": expected.focus, "actual": actual.focus})
		_check("detail.frames." + id + "." + phase + ".selected_caption", bool(expected.caption_visible) and bool(actual.caption_visible), actual)
		_check("detail.frames." + id + "." + phase + ".detail_top", actual.detail_scroll == 0, actual.detail_scroll)
	_check("detail.frames." + id + ".rect_stable", delta <= 0.5 and first.visible == settled.visible, observation)
	_check("detail.frames." + id + ".caption_stable", first.continuity.caption_rect == settled.continuity.caption_rect, observation)
	return _check("detail.frames." + id + ".observed", is_instance_valid(m.root) and m.root.get_instance_id() == observed_root_id
		and first.process_frame < settled.process_frame and not first.rects.is_empty()
		and first.rects.keys() == settled.rects.keys(), observation)


## The selected caption is a native-shaped font envelope, not its card border.
## Wheel input establishes a visible precondition without setting scroll values.
func _detail_prepare_selected() -> Dictionary:
	var initial: Dictionary = _detail_continuity()
	var current: Dictionary = initial
	var taps := 0
	for attempt in 12:
		if bool(current.caption_visible): break
		var rail := _node("AlchemyRecipeScroll") as ScrollContainer
		var selected := _node("AlchemyShape_" + String(_view().get("shape", ""))) as Button
		if rail == null or selected == null: break
		var direction := MOUSE_BUTTON_WHEEL_DOWN if selected.get_global_rect().get_center().y > rail.get_global_rect().get_center().y else MOUSE_BUTTON_WHEEL_UP
		await native._wheel(direction, rail.get_global_rect().get_center())
		taps += 1
		current = _detail_continuity()
	return {"initial": initial, "after_native_wheel": current, "wheel_taps": taps, "visible": current.caption_visible}


func _detail_continuity() -> Dictionary:
	var view: Dictionary = _view()
	var rail := _node("AlchemyRecipeScroll") as ScrollContainer
	var detail := _node("AlchemyDetailScroll") as ScrollContainer
	var focus: Control = m.get_viewport().gui_get_focus_owner()
	var selected := _node("AlchemyShape_" + String(view.get("shape", ""))) as Button
	var result := {"shape": view.get("shape", ""), "grade": view.get("grade", ""), "filter": view.get("filter", ""),
		"rail_scroll": rail.scroll_vertical if rail != null else -1, "detail_scroll": detail.scroll_vertical if detail != null else -1,
		"focus": String(focus.name) if is_instance_valid(focus) and is_instance_valid(m.root) and m.root.is_ancestor_of(focus) else "",
		"caption_visible": false, "caption_rect": [], "clip_rect": [], "caption_text": "",
		"bounds_scope": "native TextParagraph font envelope; conservative text extent, not pixel-ink or card-border bounds"}
	if selected == null or not selected.is_visible_in_tree(): return result
	var metrics: Dictionary = _caption_metrics(selected, "normal")
	if not metrics.has("text_rect"): return result
	var local: Array = metrics.text_rect
	var rect: Rect2 = selected.get_global_transform_with_canvas() * Rect2(float(local[0]), float(local[1]), float(local[2]), float(local[3]))
	var allowed: Rect2 = m._shell_rect.intersection(m.get_viewport().get_visible_rect())
	var ancestor: Node = selected.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	result.caption_rect = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	result.clip_rect = [allowed.position.x, allowed.position.y, allowed.size.x, allowed.size.y]
	result.caption_text = selected.text
	result.caption_visible = bool(metrics.fits) and rect.has_area() and allowed.grow(0.5).encloses(rect)
	return result


func _detail_frame_geometry() -> Dictionary:
	if not is_instance_valid(m.root):
		return {"process_frame": Engine.get_process_frames(), "root_instance": 0, "rects": {}, "visible": {}, "essential_glyphs": {}}
	var rects := {}
	var visible := {}
	var glyphs := {}
	for name in ["AlchemyProductName", "AlchemyProductEffect", "AlchemyRequirements", "AlchemyDetailScroll",
			"AlchemyIngredientRule", "AlchemyIngredient_herb", "AlchemyFee", "AlchemyBrew", "AlchemyResult",
			"AlchemyLearnBlueprint", "AlchemyLearnNote"]:
		var control := _node(name) as Control
		if control == null: continue
		var rect: Rect2 = control.get_global_rect()
		rects[name] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		visible[name] = control.is_visible_in_tree()
		if name in ["AlchemyProductName", "AlchemyProductEffect", "AlchemyRequirements", "AlchemyLearnNote"]:
			glyphs[name] = _detail_glyphs_visible(control as Label, 2.0)
	return {"process_frame": Engine.get_process_frames(), "root_instance": m.root.get_instance_id(),
		"root_alpha": m.root.modulate.a, "root_scale": str(m.root.scale), "sources": _view().get("sources"),
		"shape": _view().get("shape"), "grade": _view().get("grade"), "rects": rects, "visible": visible, "essential_glyphs": glyphs}


func _detail_clip_bounds(label: Label) -> Rect2:
	var allowed: Rect2 = m._shell_rect.intersection(m.get_viewport().get_visible_rect())
	var ancestor: Node = label.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: allowed = allowed.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return allowed


func _detail_tail_visible(label: Label, scroll: ScrollContainer) -> bool:
	if not native._confirm_glyphs_complete(label): return false
	var local: Rect2 = label.get_character_bounds(label.text.length() - 1)
	var glyph: Rect2 = label.get_global_transform_with_canvas() * local
	var visible: Rect2 = _detail_clip_bounds(label).intersection(scroll.get_global_rect())
	return label.is_visible_in_tree() and visible.has_area() and local.has_area() and visible.grow(0.5).encloses(glyph) and visible.end.y - glyph.end.y >= 2.0


func _detail_metadata(id: String) -> void:
	for name in ["AlchemyProductName", "AlchemyProductEffect", "AlchemyRequirements"]:
		var label := _node(name) as Label
		_check("detail." + id + ".glyphs." + name, label != null and _detail_glyphs_visible(label, 2.0), name)


## Shaped ink bounds are measured against actual clipping ancestors, not just
## Label line count. Clearance applies at the viewport edge, not inside glyphs.
func _detail_glyphs_visible(label: Label, clearance: float) -> bool:
	if not label.is_visible_in_tree() or not native._confirm_glyphs_complete(label): return false
	var allowed: Rect2 = _detail_clip_bounds(label)
	if not allowed.has_area(): return false
	for index in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty(): continue
		var glyph: Rect2 = label.get_global_transform_with_canvas() * label.get_character_bounds(index)
		if not allowed.grow(0.5).encloses(glyph) or allowed.end.y - glyph.end.y < clearance: return false
	return true


func _brew(id: String, expect_mail: bool) -> void:
	var state := _view()
	var shape := String(state.get("shape", "health_instant"))
	var grade := String(state.get("grade", "F"))
	var quote: Dictionary = Alchemy.quote(g, shape, grade)
	var before := _economy()
	var herbs := p.material_count("herb", grade)
	var reagents := p.material_count("reagent", grade)
	if not _check(id + ".allowed", bool(quote.allowed), quote.reason):
		return
	await _named("AlchemyBrew")
	_check(id + ".stays_alchemy", m.current == "alchemy", m.current)
	_check(id + ".exact_cost_and_mastery", p.gold == int(before.gold) - int(quote.fee)
		and p.material_count("herb", grade) == herbs - int(quote.herbs)
		and p.material_count("reagent", grade) == reagents - int(quote.reagents)
		and Professions.points(p, "alchemist") == int(before.mastery.get("alchemist", 0)) + int(quote.mastery_gain), _text("AlchemyResult"))
	if expect_mail:
		var last: Dictionary = g.mailbox.back() if not g.mailbox.is_empty() else {}
		_check(id + ".one_exact_mail", g.mailbox.size() == Array(before.mailbox).size() + 1
			and last.get("items", []) == [{"kind": "potion", "potion": quote.item}]
			and p.consumables == before.consumables and _text("AlchemyResult").contains("Sent to your mailbox"), last)
	else:
		_check(id + ".one_exact_pack_item", p.consumables.size() == Array(before.consumables).size() + 1
			and p.consumables.back() == quote.item and g.mailbox == before.mailbox
			and _text("AlchemyResult").contains("Added to your pack"), _text("AlchemyResult"))


func _loan_materials(grades: Array) -> void:
	# Controlled loan, not an award/drop/ordinary collection demonstration.
	p.materials = []
	for grade in grades:
		for family in ["herb", "reagent"]:
			p.materials.append(Items.make_material(family, String(grade), Items.MATERIAL_STACK_MAX))
	print("ALCHEMY FIXTURE LOAN: %d exact-grade material stacks; no collection claim" % p.materials.size())


func _reenter(touch := false) -> void:
	# Reopen fixture parent when loaned resources changed. Entry itself is input.
	m.open_professions()
	await r.frames(3)
	await _named("ProfessionsAlchemy", touch)


func _named(name: String, touch := false) -> bool:
	var button := _node(name) as Button
	if not _check("input." + name + ".%d" % rows.size(), button != null and not button.disabled, name):
		return false
	await _reveal(button)
	if touch:
		await native._touch(button.get_global_rect().get_center())
	else:
		await native._mouse(button.get_global_rect().get_center())
	await r.frames(3)
	return true


func _text_button(label: String) -> bool:
	var button: Button = native._find_button(m.root, label)
	if not _check("input.text.%d" % rows.size(), button != null, label):
		return false
	await _reveal(button)
	await native._mouse(button.get_global_rect().get_center())
	await r.frames(3)
	return true


func _reveal(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != m.root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await r.frames(2)
		ancestor = ancestor.get_parent()


func _scroll_down(name: String, taps: int) -> void:
	var scroll := _node(name) as ScrollContainer
	if scroll == null:
		_check("input.scroll." + name, false, "missing")
		return
	for i in taps:
		await native._wheel(MOUSE_BUTTON_WHEEL_DOWN, scroll.get_global_rect().get_center())


func _exit(route: String) -> void:
	match route:
		"cancel": await _text_button("Cancel")
		"escape": await native._key(KEY_ESCAPE)
		"x": await _text_button("✕")
		"outside": await native._mouse(Vector2(12, 12))
	await r.frames(3)


func _pointer(down: bool, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _escape_now() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	native.key_taps += 1


func _touch_mode(enabled: bool) -> void:
	g.settings["touch_controls"] = enabled
	g.refresh_touch_mode()
	g._apply_touch_mode()


func _node(name: String) -> Node:
	return m.root.find_child(name, true, false) if is_instance_valid(m.root) else null


func _text(name: String) -> String:
	var label := _node(name) as Label
	return label.text if label != null else ""


func _disabled(name: String) -> bool:
	var button := _node(name) as BaseButton
	return button != null and button.disabled


func _view() -> Dictionary:
	return m.get_meta("alchemy_view", {}).duplicate(true)


func _economy() -> Dictionary:
	return {"gold": p.gold, "mastery": p.mastery.duplicate(true), "materials": p.materials.duplicate(true),
		"consumables": p.consumables.duplicate(true), "blueprints": p.blueprints.duplicate(true),
		"mailbox": g.mailbox.duplicate(true), "favor": p.npc_favor.duplicate(true)}


func _layout(id: String) -> void:
	var escaped: Array[Dictionary] = []
	var tiny: Array[Dictionary] = []
	var cut_text: Array[Dictionary] = []
	var nodes: Array[Node] = [m.root]
	var screen := Rect2(Vector2.ZERO, m.get_viewport().get_visible_rect().size)
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children():
			nodes.append(child)
		if not (node is Button or node is Label) or not node.is_visible_in_tree():
			continue
		var control := node as Control
		var full := control.get_global_rect()
		var visible := full
		var ancestor: Node = control.get_parent()
		while ancestor != null and ancestor != m.root:
			if ancestor is Control and ancestor.clip_contents:
				visible = visible.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if not visible.has_area():
			continue
		if not m._shell_rect.grow(2).encloses(visible) or not screen.grow(1).encloses(visible):
			escaped.append({"name": node.name, "text": node.text, "rect": str(visible)})
		if node is Button and not node.disabled and (full.size.x < 43.5 or full.size.y < 43.5):
			tiny.append({"name": node.name, "text": node.text, "size": str(full.size)})
		if node is Button and String(node.name).begins_with("AlchemyShape_"):
			for style in ["normal", "hover", "pressed"]:
				var caption := _caption_metrics(node as Button, style)
				if not bool(caption.fits):
					cut_text.append(caption)
		if node is Label and node.get_visible_line_count() < node.get_line_count():
			cut_text.append({"name": node.name, "text": node.text, "lines": node.get_line_count(), "visible": node.get_visible_line_count()})
		if node is Label and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = node.get_theme_font("font")
			var size: int = node.get_theme_font_size("font_size")
			for line in String(node.text).split("\n"):
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > control.size.x + 2:
					cut_text.append({"name": node.name, "text": line, "width": control.size.x})
	_check("layout.contained." + id, escaped.is_empty(), escaped)
	_check("layout.active_targets44." + id, tiny.is_empty(), tiny)
	_check("layout.text." + id, cut_text.is_empty(), cut_text)
	_detail_metadata("layout_" + id)


func _capture(name: String) -> void:
	await r.frames(3)
	if not r.flag("no-capture"):
		r.shot(name, "controlled fixture resources/mastery; native UI; no_saves; no ordinary collection claim")


func _check(id: String, passed: bool, actual: Variant) -> bool:
	rows.append({"id": id, "passed": passed, "actual": actual})
	print("ALCHEMY CHECK %s: %s %s" % [id, "PASS" if passed else "FAIL", str(actual) if not passed else ""])
	return passed


func _report() -> Dictionary:
	var result := {"checks": rows.size(), "passed": 0, "failures": 0, "rows": rows,
		"mouse_clicks": native.mouse_clicks, "touch_taps": native.touch_taps, "key_taps": native.key_taps,
		"wheel_taps": native.wheel_taps, "gamepad_taps": native.gamepad_taps, "stale_signal_probes": stale_signals,
		"fixture": "loaned gold/materials/mastery; no_saves solo; no ordinary collection/save/ENet claim",
		"detail_frame_observations": detail_frame_observations, "detail_touch_observations": detail_touch_observations,
		"detail_layout_acceptance": "pending native first-draw/settled review; passing functional checks alone do not approve movement"}
	for row in rows:
		if row.passed:
			result.passed += 1
		else:
			result.failures += 1
	var directory: String = ProjectSettings.globalize_path(r.shot_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var output := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	if output == null:
		result.failures += 1
		print("ALCHEMY CHECK report.write: FAIL")
	else:
		output.store_string(JSON.stringify(result, "\t"))
	return result


func _recipe_caption(shape: String, grade: String) -> void:
	var button := _node("AlchemyShape_" + shape) as Button
	if not _check("caption.selected.%s.%s" % [shape, grade], button != null, shape):
		return
	await _reveal(button)
	for style in ["normal", "hover", "pressed"]:
		var metrics := _caption_metrics(button, style)
		_check("caption.fit.%s.%s.%s" % [shape, grade, style], bool(metrics.fits), metrics)
	if shape == "health_instant" and grade == "F":
		# A measurement sentinel using this real button's font/icon. It does not
		# resize the widget or claim that a deliberately clipped UI was rendered.
		var narrow := _caption_metrics(button, "normal", Vector2(44, button.size.y))
		_check("caption.sentinel_rejects_narrow_bounds", not bool(narrow.fits), narrow)


## Bounded to this UI's English, unwrapped, clipped recipe rail Buttons.
## Shape the full caption with Godot, then measure available text space after
## actual style margins and the expanded/capped icon. Never mutate the widget.
func _caption_metrics(button: Button, style_name: String, size_hint := Vector2(-1, -1)) -> Dictionary:
	if button.autowrap_mode != TextServer.AUTOWRAP_OFF or not button.clip_text \
			or button.icon_alignment != HORIZONTAL_ALIGNMENT_LEFT \
			or button.vertical_icon_alignment != VERTICAL_ALIGNMENT_CENTER:
		return {"fits": false, "name": button.name, "reason": "recipe caption layout changed; update bounded checker"}
	var size := button.size if size_hint.x < 0 else size_hint
	var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	var margins := [0.0, 0.0, 0.0, 0.0]
	var styles: Array = [style_name]
	if button.get_theme_constant("align_to_largest_stylebox") != 0:
		styles = ["normal", "hover", "pressed", "disabled", "hover_pressed"]
	for state in styles:
		if not button.has_theme_stylebox(String(state)):
			continue
		var box: StyleBox = button.get_theme_stylebox(String(state))
		for i in 4:
			margins[i] = maxf(float(margins[i]), box.get_margin(sides[i]))
	var available := size - Vector2(float(margins[0]) + float(margins[2]), float(margins[1]) + float(margins[3]))
	var icon_width := 0.0
	if button.icon != null:
		var icon_size: Vector2 = button.icon.get_size()
		icon_width = icon_size.x
		if button.expand_icon:
			icon_width = minf(available.x, icon_size.x * available.y / maxf(1.0, icon_size.y))
		var cap: int = button.get_theme_constant("icon_max_width")
		if cap > 0: icon_width = minf(icon_width, cap)
		icon_width = roundf(maxf(0.0, icon_width))
		available.x -= icon_width + maxi(0, button.get_theme_constant("h_separation"))
	var text := TextParagraph.new()
	text.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_TRIM_EDGE_SPACES
	text.direction = TextServer.DIRECTION_LTR
	text.line_spacing = button.get_theme_constant("line_spacing")
	text.width = -1.0
	text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	text.add_string(button.text, button.get_theme_font("font"), button.get_theme_font_size("font_size"), "en")
	var required: Vector2 = text.get_size()
	var text_left: float = float(margins[0]) + icon_width + (maxi(0, button.get_theme_constant("h_separation")) if button.icon != null else 0)
	var text_top: float = float(margins[1]) + (available.y - required.y) * 0.5
	return {"text_rect": [text_left, text_top, required.x, required.y],"fits": required.x <= available.x + 2.0 and required.y <= available.y + 2.0,
		"name": button.name, "text": button.text, "style": style_name,
		"required": str(required), "available": str(available), "icon_width": icon_width,
		"lines": text.get_line_count(), "button_size": str(size)}
