extends RefCounted
## Controlled display geometry; no live combat or replicated-target claim.
const Bounds := preload("res://scripts/ui/hud_clearance.gd")
const PanelFactory := preload("res://scripts/ui/encounter_status.gd")
const EXPECTED := ["hero_empty_margin", "wolf_outer_body", "dying_target", "outside_world", "foreign_game"]
var r: Node
var g: Game
var panel: Control
var wolf: Enemy
var rows: Array[Dictionary] = []
var findings: Array[String] = []
var failure := ""


static func run(rig: Node) -> String:
	var q := new()
	q.r = rig
	q.g = rig.readers[0]
	var h := q.g.hud
	var hero := q.g.local_player
	var old_target: CharacterBody2D = h.target_bar_unit
	var old_process := q.g.is_processing()
	var old_physics := hero.is_physics_processing()
	var old_world_mode := q.g.world.process_mode
	var old_dead := hero.dead
	var old_downed := hero.downed
	var old_ghost := hero.ghost
	var old_paused := rig.get_tree().paused
	var old_dir: String = rig.shot_dir
	rig.shot_dir = old_dir.path_join("clearance")
	rig._show(0)
	# Let the ordinary arrival title finish before freezing its update owner.
	await rig.get_tree().create_timer(4.0, true).timeout
	# Freeze the fixture's simulation/target-selection owner, not the HUD panel.
	q.g.set_process(false)
	hero.set_physics_process(false)
	q.g.world.process_mode = Node.PROCESS_MODE_DISABLED
	h.target_bar_unit = null
	q.panel = PanelFactory.make(h, "ClearanceProbe", Color(0.96, 0.81, 0.48))
	(q.panel.get_node("Title") as Label).text = "ENCOUNTER CLEARANCE PROBE"
	(q.panel.get_node("Detail") as Label).text = "Controlled actor geometry"
	(q.panel.get_node("Hint") as Label).text = "No combat or warning visibility claim"
	q.wolf = Enemy.make(q.g, "wolf", Vector2.ZERO, 2, 1.0)
	q.wolf.net_mirror = true # retain normal factory art; never register a QA enemy on ENet
	q.g.world.add_child(q.wolf)
	q.wolf.set_process(false)
	q.wolf.set_physics_process(false)
	await rig.frames(3)
	var error := await q._exercise()
	# Every exit restores simulation and references before deleting QA nodes.
	hero.dead = old_dead
	hero.downed = old_downed
	hero.ghost = old_ghost
	rig.get_tree().paused = old_paused
	h.target_bar_unit = old_target if is_instance_valid(old_target) else null
	if is_instance_valid(q.wolf): q.wolf.queue_free()
	if is_instance_valid(q.panel): q.panel.queue_free()
	q.g.world.process_mode = old_world_mode
	hero.set_physics_process(old_physics)
	q.g.set_process(old_process)
	await rig.frames(3)
	var expected: Array[String] = []
	if rig.flag("clearance-baseline"):
		for id in EXPECTED: expected.append(id)
	if q.findings != expected and error == "": error = "Unexpected clearance findings: " + str(q.findings)
	if q.failure != "" and error == "": error = q.failure
	var receipt := {"complete": error == "", "baseline": rig.flag("clearance-baseline"),
		"checks": q.rows, "findings": q.findings, "expected_findings": expected, "error": error,
		"scope": "Posed factory actors; Game process and world simulation held; production panel process remains live. Mirror flag only prevents QA spawn replication. Geometry proxy, not pixel silhouette, gameplay, network delivery, warning or prompt clearance.",
		"panel_sha256": FileAccess.get_sha256("res://scripts/ui/encounter_status.gd"),
		"helper_sha256": FileAccess.get_sha256("res://scripts/tests/encounter_clearance_live.gd")}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir.path_join("clearance.json"), FileAccess.WRITE)
	if file == null: error = "Could not write clearance receipt"
	else:
		file.store_string(JSON.stringify(receipt, "\t"))
		file.close()
	rig.shot_dir = old_dir
	return error


func _exercise() -> String:
	var hero := g.local_player
	var viewport := g.get_viewport_rect()
	var body := Bounds.body_rect(hero)
	if not _dimensions(hero, body): return "Hero geometry prerequisite failed"
	var legacy := _legacy(hero)
	var empty_margin := _separate(legacy, body, viewport)
	if not empty_margin.has_area(): return "No visible hero false-positive separation; fixture inconclusive"
	await _observe("hero_empty_margin", empty_margin, false, body, legacy)
	# Independently place the actor at an ordinary on-screen point. Do not scale art.
	wolf.global_position = wolf.get_canvas_transform().affine_inverse() * Vector2(940, 260)
	await r.frames(3)
	g.hud.target_bar_unit = wolf
	body = Bounds.body_rect(wolf)
	legacy = _legacy(wolf)
	if not _dimensions(wolf, body): return "Factory wolf geometry prerequisite failed"
	var outer := _separate(body, legacy, viewport, Bounds.body_rect(hero))
	if not outer.has_area(): return "No visible wolf false-negative separation; fixture inconclusive"
	await _observe("wolf_outer_body", outer, true, body, legacy)
	var overlap := Rect2(body.get_center() - panel.size * 0.5, panel.size)
	if overlap.intersects(Bounds.body_rect(hero)): return "Target control also covers hero; fixture inconclusive"
	await _observe("healthy_target_overlap", overlap, true, body, legacy)
	if r.flag("clearance-extra"):
		for state in ["downed", "ghost"]:
			hero.set(state, true)
			var fallen := Bounds.body_rect(hero, true)
			var policy_ok := not Bounds.body_rect(hero).has_area() and fallen.has_area()
			rows.append({"id": state + "_measurement_policy", "passed": policy_ok})
			if not policy_ok: failure = "Shared body measurement changed its default policy"
			g.hud.target_bar_unit = null
			await _observe(state + "_hero_stays_clear", Rect2(fallen.get_center() - panel.size * 0.5, panel.size), true, fallen, _legacy(hero))
			g.hud.target_bar_unit = wolf
			await _observe(state + "_hero_keeps_target_clearance", overlap, true, body, legacy)
			hero.set(state, false)
		wolf.untargetable = true
		await _observe("untargetable_target", overlap, false, Bounds.body_rect(wolf), legacy)
		wolf.untargetable = false
		r.get_tree().paused = true # controlled paused-tree clock, not a solo input claim
		await _observe("paused_target_overlap", overlap, true, body, legacy)
		rows.append({"id": "tree_remained_paused", "passed": r.get_tree().paused})
		if not r.get_tree().paused: failure = "Paused-tree control did not retain its state"
		r.get_tree().paused = false
	wolf.dying = true # lifecycle fixture; never kill/reward it
	await _observe("dying_target", overlap, false, Bounds.body_rect(wolf), legacy)
	wolf.dying = false
	wolf.reparent(g, true) # alive visible actor belonging to no current world
	await _observe("outside_world", overlap, false, Bounds.body_rect(wolf), legacy)
	wolf.reparent(g.world, true)
	wolf.game = r.readers[1] # stale foreign owner on the same visible factory actor
	await _observe("foreign_game", overlap, false, Bounds.body_rect(wolf), legacy)
	wolf.game = g
	wolf.hide()
	await _observe("hidden_target", overlap, false, Bounds.body_rect(wolf), legacy)
	wolf.show()
	g.hud.target_bar_unit = null
	body = Bounds.body_rect(hero)
	hero.dead = true
	await _observe("dead_hero_stays_clear", Rect2(body.get_center() - panel.size * 0.5, panel.size), true, body, _legacy(hero))
	hero.dead = false
	# Freed references must remain safe (existing production already guards this).
	g.hud.target_bar_unit = wolf
	wolf.queue_free()
	await r.frames(3)
	await _observe("freed_target", overlap, false, Rect2(), Rect2())
	g.hud.target_bar_unit = null
	g.menus.open_inventory("gear")
	if r.flag("clearance-extra"): r.get_tree().paused = true
	await r.frames(3)
	var hidden := not panel.visible
	rows.append({"id": "overlay_hides", "passed": hidden})
	if not hidden: failure = "Encounter panel did not hide behind actual menu"
	if r.flag("clearance-extra"):
		rows.append({"id": "overlay_tree_paused", "passed": r.get_tree().paused})
		if not r.get_tree().paused: failure = "Menu pause control did not retain its state"
		await r._capture("paused_menu_hides")
	g.menus.close()
	r.get_tree().paused = false
	# Copy policy remains unchanged throughout; no text hidden individually.
	var copy_ok := (panel.get_node("Title") as Label).text == "ENCOUNTER CLEARANCE PROBE" \
		and (panel.get_node("Detail") as Label).text == "Controlled actor geometry" \
		and (panel.get_node("Hint") as Label).text == "No combat or warning visibility claim"
	rows.append({"id": "copy_unchanged", "passed": copy_ok})
	if not copy_ok: failure = "Panel copy changed during clearance test"
	return ""


func _observe(id: String, rect: Rect2, should_yield: bool, actual: Rect2, old: Rect2) -> void:
	panel.position = rect.position
	panel.show()
	# Start opposite the target value so a non-processing panel cannot pass.
	panel.modulate.a = 1.0 if should_yield else Balance.ENCOUNTER_COVER_ALPHA
	await r.get_tree().create_timer(0.3, true).timeout
	await RenderingServer.frame_post_draw
	var wanted := Balance.ENCOUNTER_COVER_ALPHA if should_yield else 1.0
	var passed := absf(panel.modulate.a - wanted) < 0.015
	rows.append({"id": id, "passed": passed, "expected_alpha": wanted, "actual_alpha": panel.modulate.a,
		"panel": _rect(panel.get_global_rect()), "body_proxy": _rect(actual), "old_fixed_box": _rect(old)})
	if not passed:
		if r.flag("clearance-baseline") and id in EXPECTED: findings.append(id)
		else: failure = "Unexpected encounter clearance: " + id
	await r._capture(id)


func _legacy(actor: Node2D) -> Rect2:
	return Rect2(actor.get_global_transform_with_canvas().origin + Vector2(-40, -110), Vector2(80, 130))


func _separate(hit: Rect2, miss: Rect2, viewport: Rect2, other := Rect2()) -> Rect2:
	# Require a meaningful fraction of the body proxy, not a thin padded edge.
	for y in range(16, int(viewport.size.y - panel.size.y - 16), 8):
		for x in range(16, int(viewport.size.x - panel.size.x - 16), 8):
			var test := Rect2(Vector2(x, y), panel.size)
			if test.intersection(hit).get_area() >= maxf(32.0, hit.get_area() * 0.1) and not test.intersects(miss.grow(4)) \
				and (not other.has_area() or not test.intersects(other.grow(4))): return test
	return Rect2()


func _dimensions(actor: Node2D, rect: Rect2) -> bool:
	var transform := actor.get_global_transform_with_canvas()
	var expected_height := 0.0
	var expected_width := 0.0
	if actor is Player:
		expected_height = Player.HERO_TARGET_BODY * Balance.CHAR_RENDER_SCALE * float(Balance.HERO_CLASS_SIZE[actor.cls])
		expected_width = expected_height * Balance.HUD_INFO_BODY_WIDTH
	else:
		var e := actor as Enemy
		var sprite_bounds: Rect2 = e.sprite.get_global_transform_with_canvas() * e.sprite.get_rect()
		expected_width = sprite_bounds.size.x / transform.x.length()
		var head := e.hp_bar_fg.position.y + Enemy.HP_BAR_GAP + e.sprite.position.y
		expected_height = maxf(head + 1, 6 * e.art_scale * e.render_mult) - head
	var expected_size := Vector2(expected_width * transform.x.length(), expected_height * transform.y.length())
	var passed := rect.has_area() and rect.size.distance_to(expected_size) < 0.5
	rows.append({"id": "dimensions/" + actor.get_class(), "passed": passed, "actual": str(rect.size),
		"expected_transformed_size": str(expected_size), "unrotated_fixture": is_zero_approx(transform.get_rotation())})
	return passed and is_zero_approx(transform.get_rotation())


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
