extends ShotRig
## Ordinary keyboard intents, starting gear/stats, real movement and damage.
## Setup places the hero at each sign; combat never calls use_ability/damage.
## Optional --terrain=graveyard changes only the existing floor material.
## This remains Village Outskirts combat with village mechanics/lighting, not ch3.
## --deathmark-observe adds a base Assassin ultimate-first, live-input sample.
const Hunt := preload("res://scripts/road_hunt.gd")
var held := {}
var terrain_setup: Dictionary = {}
var deathmark_observation: Dictionary = {}


func _ready() -> void:
	await boot(arg("class", "warrior"), "ch1", false)
	terrain_setup["boot_hero"] = _hero_receipt()
	var error := await _checks()
	_release()
	if error != "":
		await _capture("diagnostic")
		push_error(error)
		return finish(1)
	finish()


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
	if game != null and game.has_local_player():
		game.player.clear_local_intents()


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(label, "ordinary Village Outskirts combat; visual floor=" + arg("terrain", "original") + "; original village mechanics/lighting")


func _checks() -> String:
	var ready_by := Time.get_ticks_msec() + 6000
	while not game.play_started and Time.get_ticks_msec() < ready_by:
		await get_tree().create_timer(0.05, true).timeout
	if not game.play_started:
		return "combat fixture never reached gameplay"
	game.dev_god = false
	game.settings["camera_shake"] = 0.0
	game.settings["combat_framing"] = false
	game.camera.position_smoothing_enabled = false
	game.terrain_event_t = 10000.0
	var room := -1
	for i in game.zones.size():
		if String(game.zones[i].name) == "Village Outskirts":
			room = i
	if room < 0:
		return "combat fixture has no starting road"
	var p := game.player
	p.global_position = game.room_center(room)
	game._enter_room(room)
	await skip_dialogue()
	await frames(3)
	var floor_error := _prepare_floor(room)
	if floor_error != "":
		return floor_error
	var trail := Hunt.begin(game, room, p.global_position)
	if trail == null:
		return "combat fixture could not accept a village hunt"
	for i in 3:
		p.global_position = trail.points[i]
		if not trail.request(p, i):
			return "combat setup could not inspect its next sign"
		if i < 2:
			await sim_wait(4.0)  # normal reading time; let the discovery be seen
	p.global_position = game.free_spawn_pos(trail.quarry_point + Vector2(-260, 90), trail.quarry_point)
	await _capture("01_time_to_step_clear")
	while trail.phase == Hunt.WARNING:
		await get_tree().create_timer(0.05, true).timeout
	if trail.phase != Hunt.FIGHTING:
		return "ordinary hunt did not reach combat"
	var quarry: Enemy = trail.quarry
	terrain_setup["combat_start"] = {"hero": _hero_receipt(), "quarry_kind": quarry.kind,
		"quarry_hp": quarry.max_hp, "quarry_damage": quarry.dmg, "quarry_speed": quarry.speed,
		"quarry_traits": quarry.traits.duplicate(true), "field": _field_receipt(room)}
	if not _write_terrain_setup():
		return "could not record combat-start terrain setup"
	var hp_start := p.hp
	var hp_min := p.hp
	var enemy_hp := quarry.max_hp
	var money := p.gold
	var origin := p.global_position
	var traveled := 0.0
	var begun := Time.get_ticks_msec()
	var crouch_seen := false
	var fight_shown := false
	var max_seconds := 70.0
	var sample_at := 0.0
	var samples: Array[Dictionary] = []
	var observe := float(arg("observe", "0"))
	var hurt_shown := false
	print("HUNT COMBAT START: ", JSON.stringify({"kind": quarry.kind, "traits": quarry.traits,
		"damage": quarry.dmg, "speed": quarry.speed, "hero_speed": p.speed,
		"hero_position": str(p.global_position), "quarry_position": str(quarry.global_position)}))
	var deathmark_error := ""
	if flag("deathmark-observe"):
		deathmark_error = await _observe_deathmark(quarry, room)
		hp_min = minf(hp_min, float(deathmark_observation.get("hp_min", p.hp)))
		traveled += float(deathmark_observation.get("distance_traveled", 0.0))
		origin = p.global_position
	while is_instance_valid(trail) and trail.phase == Hunt.FIGHTING and not p.dead \
		and Time.get_ticks_msec() - begun < int(max_seconds * 1000.0):
		var elapsed := (Time.get_ticks_msec() - begun) / 1000.0
		var offset := quarry.global_position - p.global_position
		var distance := offset.length()
		var toward := offset.normalized()
		var side := Vector2(-toward.y, toward.x)
		var melee: bool = p.cls in ["warrior", "paladin", "assassin"]
		var preferred := 240.0 if elapsed < observe or not melee else 55.0
		var walk := toward if distance > preferred + 15.0 else -toward if distance < preferred - 20.0 else Vector2.ZERO
		if quarry.pounce_windup > 0.0 or quarry.pounce_time > 0.0:
			walk = side
		var safe := game.play_rect(room).grow(-80.0)
		if not safe.has_point(p.global_position + walk * 90.0):
			walk = (game.room_center(room) - p.global_position).normalized()
		_move(walk)
		_press(int(game.binds.a1), elapsed >= observe)
		_press(int(game.binds.a2), elapsed >= observe and distance < 190.0)
		_press(int(game.binds.a3), elapsed >= observe and distance < 180.0)
		_press(int(game.binds.ult), elapsed >= 10.0 and distance < 220.0)
		_press(int(game.binds.potion), p.hp < p.max_hp * 0.4)
		if elapsed >= sample_at:
			sample_at += 1.0
			var sample := {"seconds": elapsed, "hp": p.hp,
				"distance": distance, "quarry_hp": quarry.hp, "pounce": quarry.pounce_windup,
				"bite": quarry.windup, "hero": str(p.global_position), "quarry": str(quarry.global_position)}
			samples.append(sample)
			if flag("trace"):
				print("HUNT COMBAT SAMPLE: ", JSON.stringify(sample))
		if p.hp < hp_start and not hurt_shown:
			hurt_shown = true
			await _capture("first_incoming_hit")
		if quarry.pounce_windup > 0.0 and not crouch_seen:
			crouch_seen = true
			await _capture("02_read_the_pounce")
		if elapsed >= 8.0 and not fight_shown:
			fight_shown = true
			game.hud.wayfinder._sample()
			if game.hud.wayfinder._hot or game.hud.wayfinder.status_label.text.contains("Sanctuary"):
				return "the live quarry sealed its escape or was marked as a sanctuary"
			await _capture("03_starting_kit_in_combat")
		await get_tree().create_timer(0.05, true).timeout
		hp_min = minf(hp_min, p.hp)
		traveled += p.global_position.distance_to(origin)
		origin = p.global_position
	_release()
	var won: bool = is_instance_valid(trail) and trail.phase == Hunt.COMPLETE
	var report := {"class": p.cls, "hero_level": p.level, "god_mode": game.dev_god,
		"quarry_hp": enemy_hp, "seconds": (Time.get_ticks_msec() - begun) / 1000.0,
		"hp_start": hp_start, "hp_min": hp_min, "hp_end": p.hp,
		"distance_walked": traveled, "pounce_seen": crouch_seen, "won": won,
		"gold_earned": p.gold - money, "dead": p.dead,
		"quarry_hp_left": quarry.hp if is_instance_valid(quarry) else 0.0}
	await _capture("04_combat_outcome")
	var file := FileAccess.open(shot_dir.path_join("combat.json"), FileAccess.WRITE)
	if file != null:
		var detailed := report.duplicate(true)
		detailed["samples"] = samples
		detailed["terrain_setup"] = terrain_setup
		detailed["incoming_hit_capture"] = hurt_shown
		detailed["pounce_capture"] = crouch_seen
		detailed["combat_end_hero"] = _hero_receipt()
		detailed["combat_end_field"] = _field_receipt(room)
		if flag("deathmark-observe"):
			detailed["deathmark_observation"] = deathmark_observation
		file.store_string(JSON.stringify(detailed, "\t"))
		file.close()
	print("HUNT COMBAT: ", JSON.stringify(report))
	if not won:
		return "ordinary combat probe did not win; inspect its report before changing balance"
	if deathmark_error != "":
		return deathmark_error
	if game.dev_god or hp_start > 1000.0 or traveled < 100.0 or p.gold <= money:
		return "combat probe used inflated health, did not walk, or received no reward"
	print("ok: ordinary hunt combat won through keyboard movement and class-kit inputs with starting equipment, normal health and no injected combat damage")
	return ""


## Read the rendered live world; never force an ability, target, resource or
## landing. Sampling occurs after frame_post_draw and may follow collision
## recovery. A large jump with ultidle is observed teleport evidence only,
## NOT the instantaneous pre-depenetration position used by the geometry rig.
func _observe_deathmark(quarry: Enemy, room: int) -> String:
	var p := game.player
	deathmark_observation = {"activated": false, "teleport_observed": false,
		"outcome": "partial", "reason": "", "samples": [], "captures": [],
		"setup": _hero_receipt(), "wander_seed": game.wander_seed,
		"skin": p.skin, "themes": p.ability_theme.duplicate(true),
		"tree_points": p.tree_points.duplicate(true), "attributes": p.attr_points.duplicate(true),
		"quarry_id": quarry.get_instance_id(), "quarry_level": quarry.level,
		"quarry_traits": quarry.traits.duplicate(true), "hp_min": p.hp,
		"distance_traveled": 0.0,
		"scope": "Ultimate-first keyboard strategy against a live hunt; setup poses/terrain-event delay retained. Render-frame samples are not pre-depenetration physics proof. No injected combat damage or resource grants."}
	var error := ""
	if p.cls != "assassin" or p.skin != "" or String(p.ability_theme.ult) != "" \
			or game.dev_god or game.net_online() or not p.is_physics_processing() \
			or not quarry.is_physics_processing():
		error = "Death Mark observation requires unmodified base Assassin, live offline physics and god off"
	else:
		_release()
		await RenderingServer.frame_post_draw
		shot("deathmark_00_approach", "live ultimate-first hunt; before input")
		var begun := Time.get_ticks_msec()
		var clock_start: float = p.damage_memory.elapsed_seconds
		var activated_at := -1.0
		var previous := p.global_position
		var selected: CharacterBody2D = null
		var input_sent := false
		while Time.get_ticks_msec() - begun < 10000 and not p.dead:
			if not is_instance_valid(quarry) or quarry.dying:
				break
			var delta := quarry.global_position - p.global_position
			if activated_at < 0.0:
				var walk := delta.normalized() if delta.length() > 210.0 else Vector2.ZERO
				if not game.play_rect(room).grow(-80.0).has_point(p.global_position + walk * 90.0):
					walk = (game.room_center(room) - p.global_position).normalized()
				_move(walk)
				if delta.length() <= 220.0 and not input_sent:
					selected = p.auto_aim() # read the normal targeting result; do not assign it
					deathmark_observation["target_at_input"] = selected.get_instance_id() if is_instance_valid(selected) else 0
					deathmark_observation["input_key"] = int(game.binds.ult)
					_press(int(game.binds.ult), true)
					input_sent = true
			else:
				_move(Vector2.ZERO) # deliberate stillness during this single execution
				_press(int(game.binds.ult), false)
			_press(int(game.binds.potion), p.hp < p.max_hp * 0.4)
			await RenderingServer.frame_post_draw
			var elapsed: float = p.damage_memory.elapsed_seconds - clock_start
			if activated_at < 0.0 and p.deathmark_time > 0.0 and float(p.cds.ult) > 1.0:
				activated_at = elapsed
				deathmark_observation["activated"] = true
				deathmark_observation["activation_seconds"] = elapsed
			var jump := p.global_position.distance_to(previous)
			var row := {"seconds": elapsed, "frame": Engine.get_process_frames(),
				"physics_frame": Engine.get_physics_frames(), "hp": p.hp,
				"hero": [p.global_position.x, p.global_position.y], "clip": p._clip,
				"position_delta": jump, "ult_cd": p.cds.ult, "mark_seconds": p.deathmark_time,
				"quarry_alive": is_instance_valid(quarry) and not quarry.dying,
				"quarry_hp": quarry.hp if is_instance_valid(quarry) else 0.0,
				"quarry": [quarry.global_position.x, quarry.global_position.y] if is_instance_valid(quarry) else [],
				"selected_alive": is_instance_valid(selected) and not selected.dying,
				"selected_hp": selected.hp if is_instance_valid(selected) else 0.0,
				"selected": [selected.global_position.x, selected.global_position.y] if is_instance_valid(selected) else []}
			deathmark_observation.samples.append(row)
			deathmark_observation.hp_min = minf(float(deathmark_observation.hp_min), p.hp)
			deathmark_observation.distance_traveled = float(deathmark_observation.distance_traveled) + jump
			previous = p.global_position
			if activated_at >= 0.0 and deathmark_observation.captures.is_empty():
				shot("deathmark_01_convergence", "actual first sampled marked frame")
				deathmark_observation.captures.append({"name": "deathmark_01_convergence", "sample": row.duplicate(true)})
			if activated_at >= 0.0 and not bool(deathmark_observation.teleport_observed) \
					and p._clip == "ultidle" and jump > 24.0:
				deathmark_observation.teleport_observed = true
				deathmark_observation["teleport_sample"] = row.duplicate(true)
				shot("deathmark_02_landing_observed", "rendered jump with ultidle; not pre-depenetration proof")
				deathmark_observation.captures.append({"name": "deathmark_02_landing_observed", "sample": row.duplicate(true)})
			if activated_at >= 0.0 and elapsed - activated_at >= 1.0:
				break
		_release()
		await RenderingServer.frame_post_draw
		shot("deathmark_03_observation_end", "live sample outcome; normal combat resumes next")
		if not bool(deathmark_observation.activated):
			error = "Death Mark observation did not see successful activation"
		elif not bool(deathmark_observation.teleport_observed):
			error = "Death Mark activated but final teleport was not observed; inspect partial/aborted evidence"
		elif p.dead:
			error = "Assassin died during Death Mark observation"
	deathmark_observation.reason = error
	deathmark_observation.outcome = "observed" if error == "" else "partial"
	var file := FileAccess.open(shot_dir.path_join("deathmark.json"), FileAccess.WRITE)
	if file == null:
		return "Could not preserve Death Mark observation receipt"
	file.store_string(JSON.stringify(deathmark_observation, "\t"))
	file.close()
	return error


## Deliberately avoid ShotRig.apply_terrain: its Game helper rebuilds rivers,
## hazards, scenery/colliders, wall dressing, ambience and event timers.
## This synchronous existing-polygon update uses the normal field renderer;
## no terrain table mutation, gameplay RNG, node replacement or combat call.
func _prepare_floor(room: int) -> String:
	var requested := arg("terrain", "")
	terrain_setup["requested_visual_terrain"] = requested
	terrain_setup["room"] = room
	terrain_setup["room_name"] = String(game.zones[room].name)
	terrain_setup["mechanical_terrain"] = String(game.terrain_by_zone[room])
	terrain_setup["original_field"] = _field_receipt(room)
	terrain_setup["original_hero"] = _hero_receipt()
	terrain_setup["fixture"] = "Village Outskirts starting-kit keyboard hunt; setup teleports to signs. Optional floor-only transplant retains village lighting, roads, detail overlay, hazards, scenery, quarry selection and physics. Not actual ch3 quest play."
	if requested == "":
		return "" if _write_terrain_setup() else "could not record original combat setup"
	if requested != "graveyard":
		return "optional combat floor supports only --terrain=graveyard"
	var existing: Polygon2D = game.zone_fields.get(room) as Polygon2D
	var desired: Texture2D = Art.ground_field("gravedirt")
	if not is_instance_valid(existing) or existing.texture == null or desired == null:
		return "floor-only combat requires an existing field polygon and installed grave-earth texture"
	if not desired.resource_path.ends_with("ground_field_gravedirt_painterly.png"):
		return "installed painterly gravedirt is absent; no substitute material will be invented"
	if game.dev_god or not game.no_saves or game.net_online() or not game.player.is_physics_processing():
		return "floor-only combat requires ordinary live physics, god off and isolated offline no_saves"
	var original_polygon := existing.get_instance_id()
	var before := _mechanics_receipt(room)
	game._apply_ground_field(room, Terrains.get_terrain(requested))
	var after := _mechanics_receipt(room)
	terrain_setup["mechanics_before"] = before
	terrain_setup["mechanics_after"] = after
	terrain_setup["mechanics_unchanged"] = before == after
	terrain_setup["rendered_field"] = _field_receipt(room)
	if not _write_terrain_setup():
		return "could not record floor-transplant setup"
	if before != after:
		return "floor-only transplant changed synchronous gameplay state"
	if (game.zone_fields.get(room) as Polygon2D) != existing or existing.get_instance_id() != original_polygon \
			or existing.texture != desired:
		return "floor-only transplant replaced its polygon or failed actual texture identity"
	var period := Art.ground_field_period("gravedirt")
	var density := float(desired.get_width()) / period
	if period != 512.0 or existing.uv.size() != existing.polygon.size():
		return "grave-earth combat field period/UV count does not match the installed material contract"
	for index in existing.polygon.size():
		if not existing.uv[index].is_equal_approx(existing.polygon[index] * density):
			return "grave-earth combat field UVs do not use the normal source/world period"
	print("HUNT COMBAT FLOOR: real Village Outskirts hunt over installed grave-earth; village mechanics/lighting retained")
	return ""


func _hero_receipt() -> Dictionary:
	var p := game.player
	return {"class": p.cls, "level": p.level, "hp": p.hp, "max_hp": p.max_hp,
		"mp": p.mp, "max_mp": p.max_mp, "attack": p.atk, "speed": p.speed,
		"gold": p.gold, "xp": p.xp, "equipment": p.equipment.duplicate(true),
		"room_potions": p.room_potions.duplicate(true), "position": [p.global_position.x, p.global_position.y],
		"god_mode": game.dev_god, "physics_active": p.is_physics_processing(), "process_active": p.is_processing()}


func _mechanics_receipt(room: int) -> Dictionary:
	var bodies: Array[Dictionary] = []
	for node in game.world.find_children("*", "CollisionObject2D", true, false):
		var body := node as CollisionObject2D
		bodies.append({"id": body.get_instance_id(), "transform": body.global_transform,
			"layer": body.collision_layer, "mask": body.collision_mask})
	var enemies: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null:
			enemies.append({"id": enemy.get_instance_id(), "kind": enemy.kind, "hp": enemy.hp,
				"position": enemy.global_position, "physics": enemy.is_physics_processing()})
	var detail: Sprite2D = game.zone_grounds.get(room) as Sprite2D
	return {"hero": _hero_receipt(), "terrain_by_zone": game.terrain_by_zone.duplicate(true),
		"room_zone": game.zones[room].duplicate(true), "hazards": game.hazards.duplicate(true),
		"rivers": game.rivers.duplicate(true), "terrain_event_t": game.terrain_event_t, "hazard_tick": game.hazard_tick,
		"play_rect": game.play_rect(room), "ambient": game.ambient.color,
		"quarry_kind": Hunt.quarry_kind(game, room),
		"bodies": bodies, "enemies": enemies, "scenery_ids": _node_ids(game.zone_scenery.get(room, [])),
		"road_ids": _node_ids(game.zone_road_marks.get(room, [])),
		"detail_node_id": detail.get_instance_id() if is_instance_valid(detail) else 0,
		"detail_texture_id": detail.texture.get_instance_id() if is_instance_valid(detail) and detail.texture != null else 0}


func _node_ids(nodes: Array) -> Array:
	var ids: Array = []
	for node in nodes:
		if is_instance_valid(node):
			ids.append(node.get_instance_id())
	return ids


func _field_receipt(room: int) -> Dictionary:
	var field: Polygon2D = game.zone_fields.get(room) as Polygon2D
	if not is_instance_valid(field) or field.texture == null:
		return {}
	var tex := field.texture
	var is_grave := tex == Art.ground_field("gravedirt")
	var mechanical := Terrains.get_terrain(String(game.terrain_by_zone[room]))
	var kind := "gravedirt" if is_grave else String(mechanical["ground"])
	return {"polygon_id": field.get_instance_id(), "resource_path": tex.resource_path,
		"source_file_sha256": FileAccess.get_sha256(tex.resource_path),
		"dimensions": [tex.get_width(), tex.get_height()], "world_period": Art.ground_field_period(kind),
		"rendered_texture_is_gravedirt_lookup": is_grave,
		"rendered_texture_is_recorded_lookup": tex == Art.ground_field(kind),
		"field_kind": kind, "texture_filter": field.texture_filter, "self_modulate": field.self_modulate,
		"ambient": game.ambient.color, "mechanical_terrain": String(game.terrain_by_zone[room])}


func _write_terrain_setup() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("terrain_setup.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(terrain_setup, "\t"))
	file.close()
	return true
