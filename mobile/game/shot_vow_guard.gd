extends ShotRig
## Baseline observation only: ordinary keys, real guard AI and basic attacks.
## Actor writes belong to setup between attempts; combat only emits input.

const TEST_LEVEL := 38
const WORLD_SEED := 731027
const GEAR_SEED := 731031
const ENEMY_SEED := 731039
const ATTEMPT_LIMIT := 12.0
const ORBIT_RADIUS := 72.0
const ATTACK_REACH := 80.0
const REAR_DOT := -0.35
const CLEAR_RADIUS := 280.0
var held := {}
var subject: Enemy
var character := {}
var test_room := -1
var arena := Vector2.ZERO


func _ready() -> void:
	var cls := arg("class", "warrior")
	if cls not in ["warrior", "mage"]:
		push_error("vow_guard supports --class=warrior or --class=mage")
		return finish(1)
	await boot(cls, "ch7", false)
	var report := {"kind": "baseline_observations", "class": cls,
		"scope": "Solo basic-attack decision probe, not a full-build or mixed-pack balance claim",
		"combat_control": "Keyboard events only; no actor writes after enemy spawn",
		"observer_note": "Native screenshot readback can add overhead; traces include wall time and physics frame",
		"attempts": [], "errors": []}
	var error := await _setup(cls)
	if error == "":
		for policy in ["frontal", "wait", "flank"]:
			var observation := await _attempt(String(policy))
			report.attempts.append(observation)
			if String(observation.get("error", "")) != "":
				report.errors.append(observation.error)
			_retire_subject()
			await frames(3)
	else:
		report.errors.append(error)
	_release()
	_retire_subject()
	var comparison := {}
	for attempt in report.attempts:
		comparison[String(attempt.policy)] = {"outcome": attempt.outcome,
			"root_peak": attempt.max_root, "distance_walked": attempt.distance_walked,
			"basic_hit_during_first_guard": attempt.basic_hit_during_first_guard,
			"enemy_hp_removed": attempt.first_hit.get("enemy_hp_removed", 0.0)}
	report["comparison"] = comparison
	report["damage_comparison"] = "Applied damage observations only; differing roll timing is not an exact reduction-ratio test"
	report["status"] = "baseline_recorded" if report.errors.is_empty() else "fixture_incomplete"
	report["regression_pass_claimed"] = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var output := shot_dir.path_join(cls + "_baseline.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("could not write Vow Sentinel baseline report")
		return finish(1)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var summary := report.duplicate(true)
	for attempt in summary.attempts:
		attempt.erase("trace")
	print("VOW GUARD BASELINE: ", JSON.stringify(summary))
	print("BASELINE ONLY: ordinary-input observations; no flankable-guard regression pass claimed. Report: ", ProjectSettings.globalize_path(output))
	if not report.errors.is_empty():
		push_error("; ".join(report.errors))
	finish(0 if report.errors.is_empty() else 1)


func _on_watchdog() -> void:
	_release()
	super()


func _press(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _move(direction: Vector2) -> void:
	_press(KEY_A, direction.x < -0.3)
	_press(KEY_D, direction.x > 0.3)
	_press(KEY_W, direction.y < -0.3)
	_press(KEY_S, direction.y > 0.3)


func _release() -> void:
	for key in held.keys():
		_press(int(key), false)
	# Called only at boundaries or terminal cleanup, never inside an attempt.
	if is_instance_valid(game) and game.has_local_player():
		game.player.clear_local_intents()


func _retire_subject() -> void:
	if is_instance_valid(subject):
		subject.free()
	subject = null


func _setup(cls: String) -> String:
	var deadline := Time.get_ticks_msec() + 6000
	while not game.play_started and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.03, true).timeout
	if not game.play_started:
		return "Vow fixture did not reach gameplay"
	game.no_saves = true
	game.dev_god = false
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.settings["hit_stop"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	game.wander_seed = WORLD_SEED
	game.switch_chapter("ch7", true)
	for i in game.zones.size():
		if String(game.zones[i].get("name", "")) == "The Summit Camp":
			test_room = i
	if test_room < 0:
		return "real ch7 Summit Camp is missing"
	game.player.global_position = game.room_center(test_room)
	game._enter_room(test_room)
	await skip_dialogue()
	await frames(3)
	var space := game.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = CLEAR_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	var bounds := game.play_rect(test_room).grow(-CLEAR_RADIUS - 20.0)
	var found := false
	for row in 5:
		for column in 7:
			var candidate := bounds.position + bounds.size * Vector2((column + 0.5) / 7.0, (row + 0.5) / 5.0)
			query.transform = Transform2D(0.0, candidate)
			if space.intersect_shape(query, 1).is_empty():
				arena = candidate
				found = true
				break
		if found:
			break
	if not found:
		return "Summit Camp has no clear circle for a bounded solo guard probe"
	var p := game.player
	p.level = TEST_LEVEL
	p.set_class(cls)
	p.ability_theme = {"a1": "", "a2": "", "a3": "", "ult": ""}
	p.equipment = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = GEAR_SEED
	for slot in Items.SLOTS:
		p.equipment[slot] = Items.roll_item_of(String(slot), "B", rng, cls)
	p.backpack = []
	p.gem_bag = []
	p.bags = [Items.make_bag("F")]
	p.consumables = []
	p.materials = []
	p.loose_bags = []
	p.recalc()
	p.hp = p.max_hp
	p.mp = p.max_mp
	character = SaveGame._character_section(game).duplicate(true)
	return ""


func _prepare_attempt() -> void:
	_release()
	_retire_subject()
	SaveGame.apply_character(game, character, false)
	var p := game.player
	p.dead = false
	p.downed = false
	p.ghost = false
	p.hurt_cd = 0.0
	p.rooted_time = 0.0
	p.frozen_time = 0.0
	p.chill_time = 0.0
	p.velocity = Vector2.ZERO
	p.pending_theme_note = ""
	p.locked_target = null
	p.soft_target = null
	for slot in p.cds:
		p.cds[slot] = 0.0
	p.global_position = arena + Vector2(-220, 0)
	game.terrain_event_t = 10000.0
	game.zone_alive[test_room] = 1
	seed(ENEMY_SEED)
	subject = Enemy.make(game, "vow_sentinel", arena, TEST_LEVEL, 1.0)
	subject.zone_idx = test_room
	game.add_enemy(subject)
	# No actor state writes below this boundary until _attempt has returned.


func _point(value: Vector2) -> Array:
	return [value.x, value.y]


func _sample(begun: int, front: Vector2) -> Dictionary:
	var p := game.player
	var relative := p.global_position - subject.global_position
	var direction := relative.normalized() if relative.length_squared() > 0.0001 else Vector2.ZERO
	return {"seconds": (Time.get_ticks_msec() - begun) * 0.001,
		"physics_frame": Engine.get_physics_frames(), "hero": _point(p.global_position),
		"sentinel": _point(subject.global_position), "distance": relative.length(),
		"relative_to_original_front": direction.dot(front) if front != Vector2.ZERO else null,
		"displayed_face_vector": _point(subject._face_lp), "sprite_direction": subject._cur_dir,
		"sprite_flip": subject.sprite.flip_h, "guard": subject.counter_t,
		"guard_cooldown": subject.counter_cd, "enemy_hp": subject.hp,
		"hero_hp": p.hp, "root": p.rooted_time, "basic_cooldown": p.cds.a1,
		"hero_dead": p.dead, "hero_downed": p.downed}


func _attempt(policy: String) -> Dictionary:
	step("ordinary " + policy + " guard attempt")
	_prepare_attempt()
	var p := game.player
	var begun := Time.get_ticks_msec()
	var front := Vector2.ZERO
	var previous := _sample(begun, front)
	var data := {"policy": policy, "error": "", "trace": [previous],
		"setup": {"level": p.level, "world_seed": game.wander_seed,
			"gear_seed": GEAR_SEED, "enemy_seed": ENEMY_SEED,
			"equipment": p.equipment.duplicate(true),
			"themes": p.ability_theme.duplicate(), "tree_points": p.tree_points.duplicate(),
			"hero_hp": p.hp, "hero_max_hp": p.max_hp, "hero_speed": p.speed,
			"hero_atk": p.current_atk(), "enemy_hp": subject.hp, "enemy_damage": subject.dmg,
			"enemy_speed": subject.speed, "enemy_level": subject.level,
			"enemy_traits": subject.traits.duplicate(), "natural_initial_guard_cooldown": subject.counter_cd,
			"arena": _point(arena), "room": test_room, "god_mode": game.dev_god},
		"first_guard": {}, "first_hit": {}, "input_attack": {}, "max_root": 0.0,
		"distance_walked": 0.0, "guard_expired_before_attack": false}
	var guard_seen := false
	var guard_finished := false
	var attack_sent := false
	var attack_released := false
	var attack_time := 0
	var hit_time := 0
	var orbit_stage := 0
	var guard_shot := false
	var hit_shot := false
	var last_position := p.global_position
	while Time.get_ticks_msec() - begun < int(ATTEMPT_LIMIT * 1000.0):
		if not is_instance_valid(subject) or subject.dying:
			data.error = policy + ": Sentinel died before this one-strike observation finished"
			break
		var sample := _sample(begun, front)
		data.distance_walked += p.global_position.distance_to(last_position)
		last_position = p.global_position
		data.max_root = maxf(float(data.max_root), p.rooted_time)
		if not guard_seen and subject.counter_t > 0.0:
			guard_seen = true
			front = (p.global_position - subject.global_position).normalized()
			data.first_guard = sample.duplicate(true)
			data.first_guard["original_front"] = _point(front)
			data.first_guard["natural"] = true
		if guard_seen and not guard_finished and subject.counter_t <= 0.0:
			guard_finished = true
			data["first_guard_end"] = sample.duplicate(true)
			data.guard_expired_before_attack = not attack_sent
		if subject.hp < float(previous.enemy_hp) and data.first_hit.is_empty():
			hit_time = Time.get_ticks_msec()
			data.first_hit = {"before": previous.duplicate(true), "after": sample.duplicate(true),
				"enemy_hp_removed": float(previous.enemy_hp) - subject.hp,
				"hero_hp_change": p.hp - float(previous.hero_hp),
				"after_key_press": attack_sent}
		data.trace.append(sample)
		if p.dead or p.downed or game.dev_god:
			data.error = policy + ": hero fell or god mode became active before completion"
			break
		var offset := subject.global_position - p.global_position
		var distance := offset.length()
		var walk := Vector2.ZERO
		var press_attack := false
		if not guard_seen:
			walk = offset.normalized() if distance > ORBIT_RADIUS else Vector2.ZERO
		elif not attack_sent:
			if policy == "flank":
				var side := Vector2(-front.y, front.x)
				var side_point := subject.global_position + side * ORBIT_RADIUS
				if orbit_stage == 0 and p.global_position.distance_to(side_point) < 16.0:
					orbit_stage = 1
				var goal := side_point if orbit_stage == 0 else subject.global_position - front * ORBIT_RADIUS
				walk = (goal - p.global_position).normalized()
				press_attack = distance <= ATTACK_REACH and (-offset).normalized().dot(front) <= REAR_DOT
			elif policy == "frontal" or subject.counter_t <= 0.0:
				walk = offset.normalized() if distance > ATTACK_REACH else Vector2.ZERO
				press_attack = distance <= ATTACK_REACH
		if press_attack:
			walk = Vector2.ZERO
			attack_sent = true
			attack_time = Time.get_ticks_msec()
			data.input_attack = sample.duplicate(true)
			data.input_attack["key"] = int(game.binds.a1)
			data.input_attack["original_guard_still_active"] = not guard_finished and subject.counter_t > 0.0
			_press(int(game.binds.a1), true)
		_move(walk)
		if attack_sent and not attack_released and Time.get_ticks_msec() - attack_time >= 25:
			_press(int(game.binds.a1), false)
			attack_released = true
		if guard_seen and not guard_shot:
			guard_shot = true
			shot(p.cls + "_" + policy + "_01_natural_guard")
		if not data.first_hit.is_empty() and not hit_shot:
			hit_shot = true
			shot(p.cls + "_" + policy + "_02_basic_contact")
		if hit_time > 0 and Time.get_ticks_msec() - hit_time >= 220:
			break
		if attack_sent and data.first_hit.is_empty() and Time.get_ticks_msec() - attack_time > 2500:
			data.error = policy + ": ordinary basic input produced no observed hit"
			break
		previous = sample
		await get_tree().create_timer(0.016, true).timeout
	_move(Vector2.ZERO)
	_press(int(game.binds.a1), false)
	data["end"] = _sample(begun, front) if is_instance_valid(subject) else {}
	if data.error == "" and (not guard_seen or data.first_hit.is_empty()):
		data.error = policy + ": bounded attempt did not observe its natural guard and basic hit"
	var during_guard: bool = not data.first_hit.is_empty() and float(data.first_hit.before.guard) > 0.0
	data["outcome"] = "incomplete_no_observed_hit" if data.first_hit.is_empty() \
		else "guard_counter_and_root_observed" if float(data.max_root) > 0.0 \
		else "hit_during_guard_without_root" if during_guard else "hit_after_guard_or_window_missed"
	data["basic_hit_during_first_guard"] = during_guard and not bool(data.guard_expired_before_attack)
	shot(p.cls + "_" + policy + "_03_outcome")
	return data
