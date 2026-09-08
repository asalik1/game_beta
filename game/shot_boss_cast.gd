extends ShotRig
## Live casts, real class abilities, and a two-peer ENet wire in ONE engine.
const Cast := preload("res://scripts/boss_cast.gd")
var fixture: Boss

class WireRoot extends Node:
	var peers := {}
	func is_online() -> bool:
		return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass


func _ready() -> void:
	await boot("warrior", "ch1", false)
	game.play_started = true
	game.hud.visible = true
	await _prepare()
	var error: String = preload("res://scripts/tests/test_boss_cast.gd").run(self)
	if error == "" and not flag("trials-only"):
		await sim_wait(1.6)
		error = await _live_contracts()
	if error == "" and not flag("trials-only"):
		error = await _wire_contracts()
	if error == "" and not flag("no-trials"):
		error = await _class_trials()
	if error != "":
		push_error(error)
		finish(1)
		return
	print("ok: live signature cancellation/release/pause, ENet cast replication, late joins and six class burst trials")
	finish()


func _prepare() -> void:
	var p: Player = game.local_player
	p.global_position = game.room_center(2)
	game._enter_room(2)
	await skip_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	game.settings["camera_shake"] = 0.0
	game.settings["hit_stop"] = false
	game.camera.position_smoothing_enabled = false
	apply_terrain("keep", 2)
	await sim_wait(4.0)
	# Terrain repaint rebuilds room actors. Clear that rebuilt fixture too.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	game.bosses.clear()
	game.current_boss = null
	game.zone_alive[2] = 0
	game.cleared[2] = true
	game.boss_spawned[2] = true
	for kind in Menus.BOSS_KINDS:
		game.hud._boss_splash_shown[String(Story.ALL_ENEMIES[kind].name)] = true
	p.set_physics_process(false)


func _boss(kind: String, level := 8) -> Boss:
	var p: Player = game.local_player
	var b := Boss.make_boss(game, kind, p.global_position + Vector2(240, -30), level)
	b.dmg = 0.0
	b.ability_cd = 1000.0
	b.special_cd = 1000.0
	b.ring_cd = 1000.0
	b.blink_cd = 1000.0
	game.hud._boss_splash_shown[b.display_name] = true
	game.world.add_child(b)
	game.bosses.append(b)
	game.current_boss = b
	p.locked_target = b
	b.set_physics_process(false)
	fixture = b
	return b


func _remove_boss(b: Boss) -> void:
	game.bosses.erase(b)
	game.current_boss = null
	game.local_player.locked_target = null
	b._cancel_signature()
	b.queue_free()
	game.cancel_ground_attacks()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()


func _live_contracts() -> String:
	step("casting, pressure and successful interruption")
	var p: Player = game.local_player
	var b := _boss("morwen")
	if not b._begin_signature():
		return "Morwen failed to start her signature"
	b.cast_window.remaining = 1.8
	await frames(3)
	shot("morwen_windup")
	b.hit_src = p
	b.take_damage(b.cast_window.goal * 0.65)
	await frames(3)
	shot("pressure_building")
	b.hit_src = p
	b.take_damage(b.cast_window.goal * 0.4)
	await frames(3)
	shot("cast_broken")
	if b.cast_window.phase != "broken" or not game._ground_attacks.is_empty():
		return "broken Blight Rain still authored its ground attacks"
	b.set_physics_process(true)
	await sim_wait(2.7)
	if b.cast_window.phase != "" or not game._ground_attacks.is_empty():
		return "broken cast released after its damage window ended"
	_remove_boss(b)
	await frames(2)
	step("pause freezes windup; unbroken cast releases the normal dodge exam")
	b = _boss("vargoth", 12)
	b._begin_signature()
	b.set_physics_process(true)
	get_tree().paused = true
	var frozen: float = b.cast_window.remaining
	await get_tree().create_timer(0.4, true).timeout
	if b.cast_window.remaining != frozen or not game._ground_attacks.is_empty():
		get_tree().paused = false
		return "signature clock or attack advanced through solo pause"
	get_tree().paused = false
	await sim_wait(frozen + 0.12)
	if game._ground_attacks.is_empty():
		return "unbroken Blade Storm failed to release its marked ground"
	shot("unbroken_blade_storm")
	# The sequence has real awaits: a reset must stop later swords too.
	b.reset_fight()
	b.set_physics_process(false)
	game.cancel_ground_attacks()
	await sim_wait(1.6)
	if not game._ground_attacks.is_empty():
		return "an old Blade Storm sequence resumed after fight reset"
	_remove_boss(b)
	await frames(2)
	step("healing hymn and every authored cast")
	b = _boss("choirmother", 15)
	b.hp = b.max_hp * 0.8
	b._begin_signature()
	var hurt: float = b.hp
	b.hit_src = p
	b.take_damage(b.cast_window.goal)
	var broken_hp: float = b.hp
	b.set_physics_process(true)
	await sim_wait(2.7)
	if b.hp > broken_hp or b.hp >= hurt:
		return "interrupting the healing hymn still healed its caster"
	b.set_physics_process(false)
	b._begin_signature()
	await frames(2)
	shot("healing_hymn")
	b.set_physics_process(true)
	await sim_wait(Balance.BOSS_BREAK_WINDUP + 0.08)
	if not is_equal_approx(b.hp, broken_hp + b.max_hp * 0.02):
		return "a completed healing hymn did not pay its authored heal"
	_remove_boss(b)
	await frames(2)
	for kind in ["vess", "sleepkeeper", "gardener"]:
		b = _boss(kind, 22)
		b._begin_signature()
		await frames(3)
		shot(kind + "_windup")
		b._cancel_signature()
		b.set_physics_process(true)
		# Death/inactive-room check before calling the base enemy simulation.
		b.dying = true
		b.cast_window.start(kind, b.max_hp)
		b._physics_process(0.01)
		if b.cast_window.phase != "":
			return "a dead boss kept an active cast"
		_remove_boss(b)
		await frames(2)
	b = _boss("morwen")
	b._begin_signature()
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	await frames(3)
	shot("touch_cast_readout")
	game.menus.open_pause()
	await frames(2)
	if game.hud.boss_cast_readout.visible:
		return "cast readout stayed over an open menu"
	game.menus.close()
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	_remove_boss(b)
	await frames(2)
	return ""


func _wire_contracts() -> String:
	step("two real ENet peers, one engine, production cast RPC")
	var host_root := WireRoot.new()
	var guest_root := WireRoot.new()
	host_root.name = "CastHost"
	guest_root.name = "CastGuest"
	add_child(host_root)
	add_child(guest_root)
	var host_api := MultiplayerAPI.create_default_interface()
	var guest_api := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(host_api, host_root.get_path())
	get_tree().set_multiplayer(guest_api, guest_root.get_path())
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var result := server.create_server(0, 2)
	var error := ""
	if result != OK:
		error = "ENet cast fixture could not bind: %s" % result
	else:
		host_api.multiplayer_peer = server
		result = client.create_client("127.0.0.1", server.host.get_local_port())
		if result != OK:
			error = "ENet cast fixture could not connect: %s" % result
		else:
			guest_api.multiplayer_peer = client
	var host := WireSession.new()
	var guest := WireSession.new()
	host.name = "Session"
	guest.name = "Session"
	host.game = game
	guest.game = game
	guest.world_ready = true
	host_root.add_child(host)
	guest_root.add_child(guest)
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while (client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or host_api.get_peers().is_empty()) and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.02).timeout
		if client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or host_api.get_peers().is_empty():
			error = "ENet cast fixture timed out connecting"
	var b := _boss("morwen")
	b.net_mirror = true
	b.net_id = 901
	guest.net_enemies[901] = b
	if error == "":
		host_root.peers[guest_api.get_unique_id()] = {}
		error = await _wire_checks(host, guest, b)
	if error == "":
		error = await _wire_guest_hits(host, guest)
	guest.net_enemies.clear()
	client.close()
	server.close()
	host_api.multiplayer_peer = null
	guest_api.multiplayer_peer = null
	get_tree().set_multiplayer(null, host_root.get_path())
	get_tree().set_multiplayer(null, guest_root.get_path())
	host_root.queue_free()
	guest_root.queue_free()
	_remove_boss(b)
	await frames(2)
	return error


func _wire_checks(host: Node, guest: Node, mirror: Boss) -> String:
	var c := Cast.new()
	c.start("morwen", 10000.0)
	c.hit(c.goal * 0.35, false, false)
	host.host_boss_cast(901, c.snapshot())
	var deadline := Time.get_ticks_msec() + 2500
	while mirror.cast_window.phase != "windup" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	if mirror.cast_window.snapshot() != c.snapshot():
		return "production ENet cast RPC lost the start/progress state: expected=%s got=%s peers=%s/%s" % [c.snapshot(), mirror.cast_window.snapshot(), host.multiplayer.get_peers(), guest.multiplayer.get_peers()]
	c.hit(c.goal, true, false)
	host.host_boss_cast(901, c.snapshot())
	await sim_wait(0.15)
	if mirror.cast_window.phase != "broken" or mirror.cast_window.damage_multiplier() != Balance.BOSS_BREAK_DAMAGE_MULT:
		return "authoritative interrupt did not reach the guest"
	c.cancel()
	host.host_boss_cast(901, c.snapshot())
	await sim_wait(0.15)
	if mirror.cast_window.phase != "":
		return "cast reset did not reach the guest"
	# A late enemy spawn uses the actual production constructor + snapshot.
	c.start("vargoth", 20000.0)
	c.hit(200.0, false, false)
	var block := {"id": 902, "kind": "vargoth", "boss": true, "level": 12, "zone": -1,
		"pos": game.local_player.global_position + Vector2(350, 0), "hp": 0.8, "cast": c.snapshot()}
	host.rpc("_rpc_spawn_enemy", block)
	await sim_wait(0.2)
	var late: Boss = guest.net_enemies.get(902)
	if not is_instance_valid(late):
		return "late join did not construct the boss mirror"
	late.set_physics_process(false)
	var joined := late.cast_window.kind == "vargoth" and is_equal_approx(late.cast_window.pressure, 200.0)
	game.bosses.erase(late)
	late.queue_free()
	if not joined:
		return "late-join boss lost its in-progress signature"
	return ""


func _class_trials() -> String:
	step("six class kits: basic pressure versus committed burst")
	var p: Player = game.local_player
	p.set_physics_process(true)
	var origin: Vector2 = game.room_center(2)
	for cls in ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]:
		if arg("class") != "" and cls != arg("class"):
			continue
		for mode in ["basic", "burst"]:
			seed(hash(cls + mode))
			p.global_position = origin
			p.level = 8
			p.set_class(cls)
			var rng := RandomNumberGenerator.new()
			rng.seed = 48815
			p.equipment = BenchBuild.equip_dict(cls, "", {"grade": "D", "gemlvl": 1, "plus": 0, "godroll": false}, rng)
			for key in p.attr_points:
				p.attr_points[key] = 0
			p.attr_points[String(Classes.CLASSES[cls].primary)] = 7
			p.recalc()
			_reset_probe_player(p)
			var b := _boss("morwen", 8)
			var melee: bool = cls in ["warrior", "assassin", "paladin"]
			b.global_position = p.global_position + Vector2(100 if melee else 280, 0)
			b.home = b.global_position
			p.facing = Vector2.RIGHT
			b._begin_signature()
			var elapsed := 0.0
			var best := 0.0
			var rotation: Array = {"warrior": ["ult", "a3", "a1"], "archer": ["ult", "a2", "a1"],
				"mage": ["ult", "a1"], "assassin": ["ult", "a1"], "paladin": ["ult", "a2", "a1"],
				"warlock": ["ult", "a2", "a1"]}[cls] if mode == "burst" else ["a1"]
			while elapsed < Balance.BOSS_BREAK_WINDUP_EARLY and b.cast_window.phase == "windup":
				for slot in rotation:
					p.use_ability(slot)
				await get_tree().physics_frame
				var dt := 1.0 / 60.0
				elapsed += dt
				best = maxf(best, b.cast_window.pressure / b.cast_window.goal)
				b.cast_window.step(dt)
			print("CAST TRIAL: %s/%s L8 D gear pressure=%.0f%% time=%.2fs atk=%.0f" % [cls, mode, best * 100.0, elapsed, p.atk])
			_remove_boss(b)
			_reset_probe_player(p)
			# The existing DPS bench uses the same five-second empty-field drain:
			# an old meteor, storm arrow or mist must not hit the next class's boss.
			await sim_wait(5.0)
			if mode == "burst" and best < 1.0:
				return "full %s burst could not meet the early cast threshold (%.0f%%)" % [cls, best * 100.0]
	return ""


func _reset_probe_player(p: Player) -> void:
	for key in p.cds:
		p.cds[key] = 0.0
	for key in ["berserk_time", "storm_time", "stab_ls_time", "pact_time", "theme_guard_time",
		"theme_speed_time", "aegis_time", "dr_time", "cast_haste_time", "nova_regen_time",
		"grit_stacks", "grit_time", "judgment_leap_cd", "deathmark_time", "zeal_time"]:
		p.set(key, 0.0)
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.next_crit = false
	p.hunt_rhythm = 0
	p.paladin_mode = "holy"
	p.hexed.clear()
	p.wither.clear()
	p.locked_target = null
	p.since_hurt = 999.0


func _wire_guest_hits(host: Node, guest: Node) -> String:
	var p: Player = game.local_player
	var peer := p.peer_id
	var stats: Dictionary = game.party_stats.duplicate(true)
	var fight: Dictionary = game.fight_stats.duplicate(true)
	p.peer_id = guest.multiplayer.get_unique_id()
	var real := _boss("morwen")
	host.net_enemies[903] = real
	real._begin_signature()
	var error: String = await _wire_hit_checks(guest, real)
	host.net_enemies.erase(903)
	_remove_boss(real)
	p.peer_id = peer
	game.party_stats = stats
	game.fight_stats = fight
	return error


func _wire_hit_checks(guest: Node, real: Boss) -> String:
	guest.guest_hit_enemy(903, real.cast_window.goal, Vector2.ZERO, false)
	var deadline := Time.get_ticks_msec() + 2500
	while real.cast_window.phase != "broken" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	if real.cast_window.phase != "broken":
		return "guest hit did not break host cast: state=%s hp=%s source=%s peers=%s" % [real.cast_window.snapshot(), real.hp, game.local_player.peer_id, guest.multiplayer.get_peers()]
	var hp_before := real.hp
	guest.guest_hit_enemy(903, 100.0, Vector2.ZERO, false)
	deadline = Time.get_ticks_msec() + 2500
	while real.hp == hp_before and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	if not is_equal_approx(hp_before - real.hp, 100.0 * Balance.BOSS_BREAK_DAMAGE_MULT):
		return "guest raw hit did not receive the exposed multiplier exactly once"
	return ""
