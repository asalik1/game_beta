extends RefCounted
## Fresh controlled fixture: real chapter replay, retained Player, new world.
## Direct ability calls and posed enemies; no menu navigation or balance claim.

var r: Node
var g: Game
var p: Player


static func run(rig: Node) -> void:
	var probe := new()
	probe.r = rig
	probe.g = rig.game
	probe.p = rig.game.local_player
	await probe._run()


func _run() -> void:
	g.settings["hit_stop"] = false
	g.camera.position_smoothing_enabled = false
	p.set_physics_process(false)
	await _case("windup", "a1", "")
	await _case("aftershock", "a3", "aftershock")
	await _aegis_travel()
	var actual: Array[String] = []
	for row in r.rows:
		if row.status == "baseline_finding":
			actual.append(String(row.id))
	actual.sort()
	var expected: Array = ["lifetime.aftershock.old_cast_cancelled", "lifetime.windup.old_cast_cancelled", "lifetime.windup.payload_preserved"] if r.flag("baseline") else []
	_check("baseline_exact", actual == expected, {"actual": actual, "expected": expected})
	_check("no_saves", g.no_saves, "isolated fixture never saves the borrowed build")


func _check(id: String, ok: bool, detail: Variant, expected_old := false) -> void:
	r._check("lifetime." + id, ok, detail, expected_old)


func _freeze() -> void:
	g.hazard_tick = 10000.0
	g.terrain_event_t = 10000.0
	for e in g.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	p.global_position = g.free_spawn_pos(g.room_center(g.cur_room), g.room_center(g.cur_room))


func _target() -> Enemy:
	var e: Enemy = r.spawn_enemy("wolf", p.global_position + Vector2(60, 0))
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


func _case(id: String, slot: String, passive: String) -> void:
	r.step("pending " + id + " across real chapter replay")
	_freeze()
	p.cls = "warrior"
	p.skin = ""
	p._tfx = {}
	p._cast_base = 0.0
	p.crit = 0.0
	p.uniq_t = {}
	var equipment: Dictionary = p.equipment.duplicate(true)
	var weapon: Dictionary = {} if equipment.get("weapon") == null else equipment.weapon.duplicate(true)
	weapon.erase("passive")
	if passive != "":
		weapon["passive"] = passive
	equipment["weapon"] = weapon
	p.equipment = equipment
	var old_enemy := _target()
	var old_world := g.world.get_instance_id()
	var player_id := p.get_instance_id()
	p._use_warrior(slot, 1.0)
	var contact := old_enemy.hp
	g.menus.open_pause()
	_check(id + ".paused", g.get_tree().paused, "synchronous pause before pending contact")
	await g.get_tree().create_timer(0.9, true, false, true).timeout
	_check(id + ".held_before_replay", is_equal_approx(old_enemy.hp, contact), old_enemy.hp)
	g.menus.close()
	g.replay_chapter("ch1")
	_check(id + ".world_replaced", g.world.get_instance_id() != old_world and g.local_player.get_instance_id() == player_id,
		"production replay replaced world and retained Player")
	_check(id + ".old_target_gone", not is_instance_valid(old_enemy), "previous world's target was freed")
	_freeze()
	var fresh := _target()
	var before := fresh.hp
	var sentinel := {"lifetime_probe": 41}
	if id == "windup":
		p._tfx = sentinel.duplicate()
	await r.skip_dialogue()
	g.request_pause(false)
	await g.get_tree().create_timer(1.0, false).timeout
	_check(id + ".old_cast_cancelled", is_equal_approx(fresh.hp, before), {"before": before, "after": fresh.hp}, true)
	if id == "windup":
		_check(id + ".payload_preserved", p._tfx == sentinel, p._tfx.duplicate(), true)
	await r.frames(3)
	r.shot("lifetime_" + id, "fresh-world target after paused old-world cast; direct chapter replay")
	# A new cast belongs to the new world and must still work.
	p._tfx = {}
	var control_start := fresh.hp
	p._use_warrior(slot, 1.0)
	await g.get_tree().create_timer(0.9, false).timeout
	_check(id + ".new_cast_works", fresh.hp < control_start, {"before": control_start, "after": fresh.hp})
	p.locked_target = null
	p.soft_target = null
	fresh.queue_free()
	await r.frames(2)


func _aegis_travel() -> void:
	r.step("personal Aegis blessing survives world travel")
	_freeze()
	p.hp = p.max_hp * 0.4
	p._tfx = {"aegis_dur": 1.0, "aegis_heal": 0.10}
	p._aegis()
	g.request_pause(true)
	var hp_before := p.hp
	await g.get_tree().create_timer(1.2, true, false, true).timeout
	_check("aegis.held", is_equal_approx(p.hp, hp_before), p.hp)
	var world_before := g.world.get_instance_id()
	g.switch_chapter("capital", true)
	_check("aegis.personal_buff_retained", g.world.get_instance_id() != world_before
		and p.aegis_time > 0.0 and is_equal_approx(p.hp, hp_before), p.aegis_time)
	_freeze()
	g.request_pause(false)
	await g.get_tree().create_timer(1.3, false).timeout
	_check("aegis.blessing_once", is_equal_approx(p.hp, hp_before + p.max_hp * 0.1), p.hp)
	await g.get_tree().create_timer(0.5, false).timeout
	_check("aegis.no_duplicate", is_equal_approx(p.hp, hp_before + p.max_hp * 0.1), p.hp)
