extends RefCounted
## Timers run on the real rendered SceneTree; actors are posed/frozen.
## This probes production effect entry points, not ordinary class play or art.

const EXPECTED_BASELINE := [
	"effects.mist.held", "effects.warrior.outrider.held",
	"effects.warrior.fury.held", "effects.warrior.aftershock.held",
	"effects.paladin.wrath.held", "effects.paladin.consecration.held",
	"effects.paladin.aegis_heal.held", "effects.paladin.chains.held",
	"effects.assassin.execution.held", "effects.warlock.rift.held",
	"effects.mage.void.held", "effects.mage.crystal.held",
	"effects.assassin.mark.held", "effects.paladin.aegis_ward.held",
	"effects.paladin.aegis_orbit.short_resume", "effects.archer.tentacles.held",
]

var r: Node
var g: Game
var p: Player
var origin := Vector2.ZERO
var saved := {}
var enemy_modes: Dictionary = {}


static func run(rig: Node) -> void:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	await probe._run()


func _run() -> void:
	r.step("posed production ability timers")
	_check("fresh_fixture", p.void_tentacles.is_empty() and p.aegis_time <= 0.0
		and p.storm_time <= 0.0, "dedicated fresh hero; no existing buffs/tentacles")
	if not p.void_tentacles.is_empty() or p.aegis_time > 0.0 or p.storm_time > 0.0:
		return
	for key in ["cls", "skin", "equipment", "_tfx", "_tcolor", "_themed",
			"_cast_base", "crit", "hp", "mp", "paladin_mode", "aegis_time",
			"storm_time", "uniq_t", "uniq_armor", "uniq_setn", "holy_charge",
			"next_crit", "global_position", "facing", "look_sign", "locked_target",
			"soft_target", "aegis_amt", "aegis_reflect", "aegis_proj_left", "aegis_fx",
			"storm_center", "void_storm_serial", "void_tentacle_cursor", "cleave_seq"]:
		var value: Variant = p.get(key)
		saved[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	saved["physics"] = p.is_physics_processing()
	saved["hit_stop"] = g.settings.get("hit_stop", true)
	saved["paused"] = g.get_tree().paused
	saved["hazard_tick"] = g.hazard_tick
	saved["terrain_event_t"] = g.terrain_event_t
	for n in g.get_tree().get_nodes_in_group("enemies"):
		enemy_modes[n.get_instance_id()] = n.is_physics_processing()
		n.set_physics_process(false)
	g.settings["hit_stop"] = false
	g.hazard_tick = 10000.0
	g.terrain_event_t = 10000.0
	p.set_physics_process(false)
	g.request_pause(false)
	origin = g.free_spawn_pos(g.room_center(g.cur_room), g.room_center(g.cur_room))
	# Settle the camera and arrival title before a paused first capture.
	p.global_position = origin
	g.camera.position_smoothing_enabled = false
	await r.sim_wait(3.0)
	await _mist()
	await _followup("warrior", "outrider")
	await _followup("warrior", "fury")
	await _aftershock()
	await _followup("paladin", "wrath")
	await _consecration()
	await _aegis()
	await _chains()
	await _execution()
	await _rift()
	await _meteor("void")
	await _meteor("crystal")
	await _mark()
	await _orbit()
	await _tentacles()
	var actual: Array[String] = []
	for row in r.rows:
		if String(row.id).begins_with("effects.") and row.status == "baseline_finding":
			actual.append(String(row.id))
	actual.sort()
	var expected: Array = EXPECTED_BASELINE.duplicate() if r.flag("baseline") else []
	expected.sort()
	_check("baseline_exact", actual == expected, {"actual": actual, "expected": expected})
	# Restore borrowed kit state and original actors' processing policy. This
	# dedicated fresh scene is discarded afterward, not resumed as a saved game.
	g.request_pause(false)
	for key in saved:
		if key not in ["physics", "hit_stop", "paused", "hazard_tick", "terrain_event_t"]:
			p.set(key, saved[key])
	p.set_physics_process(bool(saved.physics))
	g.settings["hit_stop"] = saved.hit_stop
	g.hazard_tick = saved.hazard_tick
	g.terrain_event_t = saved.terrain_event_t
	for instance_id in enemy_modes:
		if is_instance_id_valid(int(instance_id)):
			var old_actor: Node = instance_from_id(int(instance_id))
			old_actor.set_physics_process(bool(enemy_modes[instance_id]))
	g.request_pause(bool(saved.paused))
	_check("restored", p.cls == saved.cls and p.skin == saved.skin
		and p.is_physics_processing() == saved.physics, "borrowed kit/actor state restored")


func _check(id: String, ok: bool, detail: Variant, expected_old := false) -> void:
	r._check("effects." + id, ok, detail, expected_old)


func _setup(cls: String) -> Enemy:
	r.step("effect timer " + cls)
	p.cls = cls
	p.skin = ""
	p.equipment = saved.equipment.duplicate(true)
	if p.equipment.get("weapon") != null:
		p.equipment.weapon.erase("passive")
	p._tfx = {}
	p._themed = false
	p._tcolor = Color.WHITE
	p._cast_base = 0.0
	p.crit = 0.0
	p.uniq_t = {}
	p.uniq_armor = []
	p.uniq_setn = {}
	p.next_crit = false
	p.holy_charge = 0.0
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.paladin_mode = "retribution"
	p.aegis_time = 0.0
	p.storm_time = 0.0
	p.global_position = origin
	p.facing = Vector2.RIGHT
	p.look_sign = 1.0
	var e: Enemy = r.spawn_enemy("wolf", origin + Vector2(60, 0))
	e.set_physics_process(false)
	e.hp = 10000.0
	e.max_hp = 10000.0
	e.eva = 0.0
	e.critres = 0.0
	e.physres = 0.0
	e.magres = 0.0
	p.locked_target = e
	p.soft_target = e
	return e


func _retire(e: Enemy) -> void:
	p.locked_target = null
	p.soft_target = null
	if is_instance_valid(e):
		e.queue_free()
	await r.frames(2)
	# Let the previous cast's fading damage text/FX leave before the next hold.
	await _world_wait(1.2)


func _world_wait(seconds: float) -> void:
	await g.get_tree().create_timer(seconds, false).timeout


func _hold(id: String, observe: Callable, seconds: float, capture := "") -> Variant:
	var before: Variant = observe.call()
	g.request_pause(true)
	_check(id + ".paused", g.get_tree().paused, "solo SceneTree paused")
	# Ignore time_scale for QA observation only; production clocks retain it.
	await g.get_tree().create_timer(seconds, true, false, true).timeout
	var during: Variant = observe.call()
	_check(id + ".held", during == before, {"before": before, "during": during}, true)
	if capture != "":
		r.shot(capture, "controlled timer fixture; paused state, borrowed kit")
	g.request_pause(false)
	return before


func _first_hit(id: String, e: Enemy, before: float) -> bool:
	var end_ms := Time.get_ticks_msec() + 2500
	while e.hp >= before and Time.get_ticks_msec() < end_ms:
		await g.get_tree().process_frame
	var hit := e.hp < before
	_check(id + ".initial_contact", hit, {"before": before, "after": e.hp})
	return hit


func _settled_damage(id: String, e: Enemy, before: float, seconds: float) -> void:
	await _world_wait(seconds)
	_check(id + ".resolved", e.hp < before, {"before": before, "after": e.hp})
	var settled := e.hp
	await _world_wait(0.35)
	_check(id + ".settled", is_equal_approx(e.hp, settled), {"settled": settled, "later": e.hp})


func _mist() -> void:
	var e := _setup("assassin")
	var observe: Callable = func() -> int: return e.toxin
	p._mist(e.global_position, 90.0, 0.1, Color(0.4, 0.9, 0.4), 0.8)
	await _hold("mist", observe, 1.2, "effects_01_mist_held")
	await _world_wait(1.0)
	_check("mist.two_ticks", e.toxin == 2, e.toxin)
	await _world_wait(0.8)
	_check("mist.stops", e.toxin == 2, e.toxin)
	await _retire(e)


func _followup(cls: String, variant: String) -> void:
	var e := _setup(cls)
	var id := cls + "." + variant
	if variant == "outrider":
		var weapon: Dictionary = {} if p.equipment.get("weapon") == null else p.equipment.weapon.duplicate(true)
		weapon["passive"] = "outrider"
		p.equipment["weapon"] = weapon
		p.uniq_t["outrider"] = 2.0
	else:
		p._tfx = {"wave2": 1}
	var start := e.hp
	if cls == "warrior":
		p._use_warrior("a1", 1.0)
	else:
		p._use_paladin("a1", 1.0)
	if not await _first_hit(id, e, start):
		await _retire(e)
		return
	var contact := e.hp
	var observe: Callable = func() -> float: return e.hp
	await _hold(id, observe, 0.5)
	await _settled_damage(id, e, contact, 0.45)
	await _retire(e)


func _aftershock() -> void:
	var e := _setup("warrior")
	var weapon: Dictionary = {} if p.equipment.get("weapon") == null else p.equipment.weapon.duplicate(true)
	weapon["passive"] = "aftershock"
	p.equipment["weapon"] = weapon
	p._use_warrior("a3", 1.0)
	var initial := e.hp
	_check("warrior.aftershock.initial_contact", initial < e.max_hp, initial)
	var observe: Callable = func() -> float: return e.hp
	await _hold("warrior.aftershock", observe, 0.8)
	await _settled_damage("warrior.aftershock", e, initial, 0.75)
	await _retire(e)


func _consecration() -> void:
	var e := _setup("paladin")
	var initial := e.hp
	p._consecration(1.0)
	if not await _first_hit("paladin.consecration", e, initial):
		await _retire(e)
		return
	var contact := e.hp
	var observe: Callable = func() -> float: return e.hp
	await _hold("paladin.consecration", observe, 1.0)
	await _settled_damage("paladin.consecration", e, contact, 1.0)
	await _retire(e)


func _alive(ids: Array[int]) -> int:
	var count := 0
	for instance_id in ids:
		if is_instance_id_valid(instance_id):
			count += 1
	return count


func _aegis() -> void:
	var e := _setup("paladin")
	p.hp = p.max_hp * 0.4
	p._tfx = {"aegis_dur": 0.45, "aegis_heal": 0.10}
	var children_before: Array = p.get_children()
	p._aegis()
	var wards: Array[int] = []
	for child in p.get_children():
		if child not in children_before and child is Sprite2D and child.texture == Art.tex("fx_aegis"):
			wards.append(child.get_instance_id())
	_check("paladin.aegis_ward.created", wards.size() == 2, wards.size())
	var hp_before := p.hp
	var count_before := _alive(wards)
	g.request_pause(true)
	await g.get_tree().create_timer(0.8, true, false, true).timeout
	_check("paladin.aegis_heal.held", is_equal_approx(p.hp, hp_before), {"before": hp_before, "during": p.hp}, true)
	_check("paladin.aegis_ward.held", _alive(wards) == count_before, {"before": count_before, "during": _alive(wards)}, true)
	r.shot("effects_02_aegis_held", "borrowed Paladin kit on posed actor; world paused")
	g.request_pause(false)
	await _world_wait(0.8)
	_check("paladin.aegis_heal.once", is_equal_approx(p.hp, hp_before + p.max_hp * 0.1), p.hp)
	_check("paladin.aegis_ward.expired", _alive(wards) == 0, _alive(wards))
	await _world_wait(0.4)
	_check("paladin.aegis_heal.stops", is_equal_approx(p.hp, hp_before + p.max_hp * 0.1), p.hp)
	await _retire(e)


func _chains() -> void:
	var e := _setup("paladin")
	var initial := e.hp
	p._chains_of_wrath(1.0)
	var observe: Callable = func() -> float: return e.hp
	await _hold("paladin.chains", observe, 0.7)
	await _settled_damage("paladin.chains", e, initial, 0.65)
	await _retire(e)


func _execution() -> void:
	var e := _setup("assassin")
	p._death_mark_execution(e, 0.0)
	var first := e.hp
	var start := p.global_position
	_check("assassin.execution.initial_contact", first < e.max_hp, first)
	var observe: Callable = func() -> Dictionary: return {"hp": e.hp, "position": p.global_position}
	await _hold("assassin.execution", observe, 0.8)
	await _settled_damage("assassin.execution", e, first, 0.7)
	_check("assassin.execution.teleported", p.global_position.distance_to(start) > 10.0, {"from": start, "to": p.global_position})
	await _retire(e)


func _rift() -> void:
	var e := _setup("warlock")
	var initial := e.hp
	p._void_rift(1.0)
	var observe: Callable = func() -> float: return e.hp
	await _hold("warlock.rift", observe, 1.3)
	await _settled_damage("warlock.rift", e, initial, 1.3)
	await _retire(e)


func _meteor(kind: String) -> void:
	var e := _setup("mage")
	var landed := {"count": 0}
	var on_land: Callable = func() -> void: landed["count"] += 1
	var initial := e.hp
	if kind == "void":
		# Direct fixture for this callable skin-scene path; not an unlock/selector claim.
		p._void_weaver_ult_scene(e.global_position, 1.0, on_land, {}, Color(0.6, 0.3, 0.9))
	else:
		p._crystal_archmage_ult_scene(e.global_position, 1.0, on_land, {}, Color(0.8, 0.9, 1.0))
	var observe: Callable = func() -> Dictionary: return {"hp": e.hp, "landed": landed.count}
	await _hold("mage." + kind, observe, 1.0, "effects_03_crystal_held" if kind == "crystal" else "")
	await _settled_damage("mage." + kind, e, initial, 0.95)
	_check("mage." + kind + ".one_landing", landed.count == 1, landed.count)
	await _retire(e)


func _mark() -> void:
	var e := _setup("assassin")
	var children_before: Array = e.get_children()
	p._mark_overhead_x(e)
	var marks: Array[int] = []
	for child in e.get_children():
		if child not in children_before:
			marks.append(child.get_instance_id())
	_check("assassin.mark.created", marks.size() == 1, marks.size())
	var observe: Callable = func() -> int: return _alive(marks)
	await _hold("assassin.mark", observe, 5.4)
	await _world_wait(5.4)
	_check("assassin.mark.expired", _alive(marks) == 0, _alive(marks))
	await _retire(e)


func _orbit_alpha(instance_id: int) -> float:
	if not is_instance_id_valid(instance_id):
		return -1.0
	var orbit: Node2D = instance_from_id(instance_id)
	return orbit.modulate.a


func _orbit() -> void:
	var e := _setup("paladin")
	# Existing skin code only; no assets altered and actor physics stays disabled.
	p.skin = "eclipse_knight"
	p._tfx = {"aegis_dur": 0.65}
	var before: Array = p.get_children()
	p._aegis()
	var orbit_id := 0
	for child in p.get_children():
		if child not in before and child is Node2D and not child is Sprite2D and child.get_child_count() == 4:
			orbit_id = child.get_instance_id()
	_check("paladin.aegis_orbit.created", orbit_id != 0, orbit_id)
	if orbit_id == 0:
		await _world_wait(1.0)
		await _retire(e)
		return
	g.request_pause(true)
	await g.get_tree().create_timer(0.9, true, false, true).timeout
	# The old timer kills the orbit tween and schedules a paused fade; deletion
	# itself therefore happens shortly AFTER resume, not during the paused hold.
	g.request_pause(false)
	await _world_wait(0.08)
	var alpha := _orbit_alpha(orbit_id)
	_check("paladin.aegis_orbit.short_resume", is_equal_approx(alpha, 1.0), alpha, true)
	await _world_wait(1.2)
	_check("paladin.aegis_orbit.expired", not is_instance_id_valid(orbit_id), orbit_id)
	await _retire(e)


func _tentacles() -> void:
	var e := _setup("archer")
	p._voidwraith_storm_scene()
	await _world_wait(0.45) # present the roots before testing their lifetime
	_check("archer.tentacles.created", p.void_tentacles.size() == 8, p.void_tentacles.size())
	var observe: Callable = func() -> int: return p.void_tentacles.size()
	await _hold("archer.tentacles", observe, 3.5)
	await _world_wait(3.1)
	_check("archer.tentacles.expired", p.void_tentacles.is_empty(), p.void_tentacles.size())
	await _retire(e)
