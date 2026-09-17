extends RefCounted
## Loaned stock and room allowances; actual R/touch selection, no direct cycling.
const Native := preload("res://scripts/tests/menu_navigation_live.gd")
const OWNED := ["consumables", "potion_rotation", "room_potions", "active_potion",
	"potion_cd", "potion_swap_cd", "hp", "mp"]
var r: Node
var g: Game
var p: Player
var native := Native.new()
var rows: Array[Dictionary] = []
var views: Array[String] = []
var failures := 0
var findings := 0
var mana_id := ""

static func run(rig: Node) -> String:
	var q := new()
	q.r = rig
	q.g = rig.game
	q.p = rig.game.local_player
	q.native.r = rig
	q.native.g = q.g
	q.native.m = q.g.menus
	if not q.g.no_saves or q.g.net_online() or q.g.dev_god:
		return "cycle-stock requires disposable offline no-god fixture"
	var keep := q._snapshot(OWNED)
	var economy := [q.p.gold, q.p.xp]
	var emulate := Input.emulate_mouse_from_touch
	var old_dir: String = rig.shot_dir
	rig.shot_dir = old_dir.path_join("cycle_stock")
	Input.emulate_mouse_from_touch = true
	var error := await q._exercise()
	if error != "": q._check("exercise/completed", false, error)
	# Let the released touch pulse and normal swap debounce expire before restore.
	await rig.sim_wait(0.4)
	for key in keep: q.p.set(key, keep[key])
	Input.emulate_mouse_from_touch = emulate
	q._check("cleanup/owned", q._snapshot(OWNED) == keep and [q.p.gold, q.p.xp] == economy)
	q._check("input/released", not Input.is_key_pressed(KEY_R))
	q._check("baseline/exact", q.findings == (1 if rig.flag("baseline") else 0), q.findings)
	var report := {"complete": q.failures == 0, "failures": q.failures, "findings": q.findings,
		"checks": q.rows, "views": q.views, "error": error,
		"input": {"keys": q.native.key_taps, "touch": q.native.touch_taps},
		"scope": "Legal two-slot ch3 plan and loaned Items stock/full HP/MP; normal R or ScreenTouch selection. No drinking, earned gathering, physical-device or network claim."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rig.shot_dir))
	var file := FileAccess.open(rig.shot_dir.path_join("acceptance.json"), FileAccess.WRITE)
	rig.shot_dir = old_dir
	if file == null: return "Cannot write cycle-stock receipt"
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return "" if q.failures == 0 else "Cycle-stock fixture failed: %d" % q.failures

func _exercise() -> String:
	if p.potion_slot_cap() != 2 or String(g.zones[g.cur_room].get("type", "")) != "safe":
		return "requires the existing chapter-three safe-room fixture"
	if r.touch_run and (not is_instance_valid(g._touch_hud) or not g._touch_hud._btns.has("potion_next")):
		return "touch cycle control missing"
	if int(g.binds.get("potion_next", 0)) != KEY_R: return "requires default R binding"
	var mana: Dictionary = Items.make_potion("mana", "instant", "E", "accord")
	mana_id = String(mana.get("id", ""))
	if mana_id == "" or not Items.is_rotation_potion(mana_id): return "mana factory ID missing"
	p.hp = p.max_hp
	p.mp = p.max_mp
	# id, Health stock, Mana stock, Health budget, initial selection, expected selection
	var cases := [
		["emptyhealth", 0, 1, 1, mana_id, mana_id],
		["stockedhealth", 1, 1, 1, mana_id, "health"],
		["spenthealth", 1, 1, 0, mana_id, mana_id],
		["dryspecific", 1, 0, 1, "health", "health"],
		["bothdry", 0, 0, 1, "health", "health"]]
	for i in cases.size():
		var error := await _case(cases[i], i < 4, mana)
		if error != "": return error
	return ""

func _case(spec: Array, capture: bool, mana: Dictionary) -> String:
	await r.sim_wait(0.4)
	var deadline := Time.get_ticks_msec() + 2000
	while p.potion_swap_cd > 0.0 and Time.get_ticks_msec() < deadline:
		await r.get_tree().process_frame
	if p.potion_swap_cd > 0.0 or not _live(): return "cycle input not ready/live"
	p.consumables = []
	for i in int(spec[1]): p.consumables.append(Items.make_potion("health", "instant", "E", "accord"))
	for i in int(spec[2]): p.consumables.append(mana.duplicate(true))
	p.potion_rotation = [mana_id, "health"]
	p.room_potions = {mana_id: 1, "health": int(spec[3])}
	p.active_potion = String(spec[4])
	# Let ordinary TouchHud/Hud processing observe the new plan before input.
	await r.frames(2)
	if not _live() or p.potion_swap_cd > 0.0: return "cycle input changed while setup settled"
	_check(String(spec[0]) + "/legal_capacity", p.bag_used() <= p.bag_capacity())
	var before := _snapshot(["consumables", "potion_rotation", "room_potions", "hp", "mp", "gold", "xp"])
	var witness := {"peak": 0.0}
	var observe := func() -> void: witness.peak = maxf(float(witness.peak), p.potion_swap_cd)
	r.get_tree().physics_frame.connect(observe)
	if r.touch_run:
		var button := g._touch_hud._btns["potion_next"]["panel"] as Control
		if not button.is_visible_in_tree():
			r.get_tree().physics_frame.disconnect(observe)
			return "touch cycle control hidden"
		await native._touch(button.get_global_rect().get_center())
	else:
		await native._key(KEY_R)
	deadline = Time.get_ticks_msec() + 600
	while float(witness.peak) <= 0.0 and p.potion_swap_cd <= 0.0 and Time.get_ticks_msec() < deadline:
		await r.get_tree().process_frame
	witness.peak = maxf(float(witness.peak), p.potion_swap_cd)
	r.get_tree().physics_frame.disconnect(observe)
	var id := String(spec[0])
	_check(id + "/input_delivered", float(witness.peak) > 0.0 and _live(), witness)
	_check(id + "/unchanged", before == _snapshot(before.keys()))
	var actual := p.active_potion
	var known: bool = id == "emptyhealth" and actual == "health" and r.flag("baseline")
	_check(id + "/selection", actual == String(spec[5]), {"actual": actual, "expected": spec[5]}, known)
	await r.frames(3)
	await RenderingServer.frame_post_draw
	var box: Dictionary = g._touch_hud._btns["potion"] if r.touch_run else g.hud.slot_boxes[4]
	var number := box["label" if r.touch_run else "num"] as Label
	var icon := box["icon"] as TextureRect
	var count := p.potion_count() if actual == "health" else p.consumable_count(actual)
	var texture: Texture2D = Art.tex("potion") if actual == "health" else Art.consumable_icon({"id": actual})
	_check(id + "/hud", number.is_visible_in_tree() and icon.is_visible_in_tree()
		and number.text == "x%d" % count and icon.texture == texture,
		{"active": actual, "count": count, "label": number.text})
	if capture: views.append(r.shot(id))
	return ""

func _live() -> bool:
	return not r.get_tree().paused and p.is_physics_processing() and g.is_processing() \
		and not g.input_overlay_up() and not p.dead and not p.downed and not p.ghost

func _snapshot(fields: Array) -> Dictionary:
	var out := {}
	for key in fields:
		var value: Variant = p.get(key)
		out[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return out

func _check(id: String, ok: bool, detail: Variant = {}, known := false) -> void:
	var finding: bool = not ok and known
	rows.append({"id": id, "ok": ok, "finding": finding, "detail": detail})
	if finding: findings += 1
	elif not ok: failures += 1
