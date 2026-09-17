extends ShotRig
## Controlled damage/cast fixture; native menu input, not ordinary combat.
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const Report := preload("res://scripts/ui/combat_report.gd")
var rows: Array[Dictionary] = []
var native: NativeInput


func _ready() -> void:
	await boot("warrior", "ch1", false)
	native = NativeInput.new()
	native.r = self
	native.g = game
	native.m = game.menus
	if flag("lifetime"):
		shot_dir = shot_dir.path_join("lifetime")
		await preload("res://scripts/tests/ability_lifetime.gd").run(self)
	elif flag("effects"):
		shot_dir = shot_dir.path_join("effects")
		await preload("res://scripts/tests/ability_timer_effects.gd").run(self)
	else:
		await _checks()
	for row in native.rows:
		_check("native." + String(row.id), bool(row.passed), row)
	game.menus.close()
	game.request_pause(false)
	var failures := 0
	var findings := 0
	for row in rows:
		failures += int(row.status == "fail")
		findings += int(row.status == "baseline_finding")
	var report := {"baseline": flag("baseline"), "rows": rows, "failures": failures,
		"findings": findings, "key_taps": native.key_taps, "mouse_clicks": native.mouse_clicks,
		"touch_taps": native.touch_taps,
		"mode": "lifetime" if flag("lifetime") else "effects" if flag("effects") else "history",
		"scope": "Posed actors with borrowed kit state, direct production effect calls, world pause and optional real chapter replay. No ordinary class play, skin unlock, replication or physical-device claim." if flag("effects") or flag("lifetime") else "Posed frozen enemy, direct production damage/cast entry, real menu key/click input. No ordinary combat or physical-device claim."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write combat clock receipt")
		return finish(1)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("COMBAT CLOCKS: ", JSON.stringify(report))
	finish(1 if failures > 0 else 0)


func _check(id: String, ok: bool, detail: Variant, baseline_issue := false) -> void:
	var status := "pass" if ok else "baseline_finding" if baseline_issue and flag("baseline") else "fail"
	rows.append({"id": id, "status": status, "detail": detail})
	print("CLOCK CHECK ", id, ": ", status)


func _checks() -> void:
	game.settings["touch_controls"] = flag("touch")
	game.settings["menu_motion"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	game.terrain_event_t = 10000.0
	game.hazard_tick = 10000.0
	game.camera.position_smoothing_enabled = false
	var p: Player = game.player
	p.char_name = "The Uncrowned"
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	p.global_position = game.free_spawn_pos(game.room_center(game.cur_room), game.room_center(game.cur_room))
	await sim_wait(1.0)
	var enemy := spawn_enemy("wolf", p.global_position + Vector2(60, 0))
	enemy.set_physics_process(false)
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	p.locked_target = enemy
	p.eva = 0.0
	p.shield = 0.0
	p.hurt_cd = 0.0
	p.damage_memory.clear_recent()
	p.take_damage(15.0, "true", enemy)
	_check("recorded.one_hit", p.damage_memory.hits.size() == 1, p.damage_memory.hits.duplicate(true))
	step("solo pause preserves recent wounds")
	await native._key(KEY_ESCAPE)
	_check("solo.pause", game.menus.current == "pause" and get_tree().paused, game.menus.current)
	var before: Array = p.damage_memory.hits.duplicate(true)
	# This is deliberately wall time: the player spends longer than the entire
	# history window reading a paused menu, without advancing gameplay.
	await get_tree().create_timer(Balance.COMBAT_MEMORY_SECONDS + 0.3, true).timeout
	Report.open(game.menus, false)
	await frames(4)
	_check("solo.history_retained", p.damage_memory.hits == before, p.damage_memory.hits.duplicate(true), true)
	shot("01_recent_after_reading", "menu held beyond damage-history window")
	_check("input.close_report", await _button("Return to game"), "Combat report exit")
	_check("solo.resume", not get_tree().paused and not game.menus.is_open(), game.menus.current)
	step("cast contact stays on paused swing")
	p.cds["a1"] = 0.0
	p.mp = p.max_mp
	p.locked_target = enemy
	var hp_before := enemy.hp
	p.use_ability("a1")
	var cooldown := float(p.cds["a1"])
	# Opening synchronously pins the cast before its contact frame. Subsequent
	# resume uses the real menu button, while the cast itself is a direct fixture.
	game.menus.open_pause()
	var frame := p.sprite.frame
	await get_tree().create_timer(0.75, true).timeout
	_check("solo.cast_frozen", is_equal_approx(enemy.hp, hp_before), {"before": hp_before, "after": enemy.hp}, true)
	_check("solo.cooldown_frozen", is_equal_approx(float(p.cds["a1"]), cooldown), p.cds["a1"])
	_check("solo.animation_frozen", p.sprite.frame == frame, {"before": frame, "after": p.sprite.frame})
	shot("02_paused_swing", "enemy HP must remain unchanged behind solo menu")
	_check("input.resume_swing", await _button("Resume game"), "Pause menu exit")
	_check("solo.swing_world_resumed", not get_tree().paused and not game.menus.is_open(), game.menus.current)
	await sim_wait(0.6)
	_check("solo.cast_resumed", enemy.hp < hp_before, {"before": hp_before, "after": enemy.hp})
	var hp_after := enemy.hp
	await sim_wait(0.5)
	_check("solo.cast_once", is_equal_approx(enemy.hp, hp_after), enemy.hp)
	shot("03_resumed_contact")
	if not flag("baseline"):
		step("fall retains the pre-pause wound")
		p.hurt_cd = 0.0
		p.take_damage(p.max_hp * 2.0, "true", enemy, true)
		await sim_wait(Balance.DEATH_BEAT_SECS + 0.8)
		var fall_hits: Array = p.damage_memory.last_defeat.get("hits", [])
		_check("fall.previous_wound_retained", fall_hits.size() == 2 and is_equal_approx(float(fall_hits[0].amount), 15.0), fall_hits)
		_check("fall.recovered", not p.dead and p.hp > 0.0, p.hp)
		Report.open(game.menus, true)
		await frames(4)
		shot("04_last_fall")
		_check("input.close_fall", await _button("Return to game"), "Last fall exit")
		p.hurt_cd = 0.0
		p.take_damage(10.0, "true", null)
	step("active play expires recent history")
	await sim_wait(Balance.COMBAT_MEMORY_SECONDS + 0.3)
	Report.open(game.menus, false)
	await frames(4)
	_check("active.history_expires", p.damage_memory.hits.is_empty(), p.damage_memory.hits.duplicate(true))
	shot("05_recent_expired")
	if not flag("baseline"):
		_check("fall.snapshot_survives", p.damage_memory.last_defeat.get("hits", []).size() == 2, p.damage_memory.last_defeat)
		_check("input.close_empty", await _button("Return to game"), "Empty report exit")
		await _online(p)


func _button(label: String) -> bool:
	if not flag("touch"):
		return await native._button(label)
	var button: Button = native._find_button(game.menus.root, label)
	if button == null:
		return false
	await native._touch(button.get_global_rect().get_center())
	await frames(3)
	return true


func _online(p: Player) -> void:
	step("empty ENet host keeps online menu clocks running")
	# Real recovery frees temporary enemies, so this phase owns a fresh target.
	var enemy := spawn_enemy("wolf", p.global_position + Vector2(60, 0))
	enemy.set_physics_process(false)
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	_check("online.target_valid", is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), enemy.hp)
	var net: Node = get_node("/root/NetworkManager")
	if net.is_online():
		_check("online.isolated", false, "Refusing to replace an existing session")
		return
	var previous_peer: MultiplayerPeer = net.multiplayer.multiplayer_peer
	var saved := {"mode": net.mode, "session_code": net.session_code,
		"lobby_open": net.lobby_open, "_session_active": net._session_active}
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(0, 1)
	_check("online.enet_bound", error == OK, error)
	if error != OK:
		return
	net.multiplayer.multiplayer_peer = peer
	net.mode = preload("res://scripts/net/net_manager.gd").Mode.ENET_DIRECT
	net.session_code = "127.0.0.1:%d" % peer.get_host().get_local_port()
	net.lobby_open = false
	net._session_active = true
	p.hurt_cd = 0.0
	p.take_damage(10.0, "true", null)
	var clock_before: float = p.damage_memory.elapsed_seconds
	# Repositioning is controlled fixture setup after the real solo recovery.
	enemy.global_position = p.global_position + Vector2(60, 0)
	p.locked_target = enemy
	p.cds["a1"] = 0.0
	p.mp = p.max_mp
	var hp_before := enemy.hp
	p.use_ability("a1")
	game.menus.open_pause()
	await get_tree().create_timer(0.8, true).timeout
	_check("online.world_not_paused", not get_tree().paused and game.net_host() and net.peers.is_empty(), game.net_online())
	_check("online.clock_advances", p.damage_memory.elapsed_seconds > clock_before + 0.5, p.damage_memory.elapsed_seconds - clock_before)
	_check("online.committed_cast_resolves", enemy.hp < hp_before, {"before": hp_before, "after": enemy.hp})
	# The local finale guard already holds survival; history follows it too.
	game.chapter_finale.active = true
	var held: float = p.damage_memory.elapsed_seconds
	await get_tree().create_timer(0.3, true).timeout
	_check("finale.history_held", is_equal_approx(p.damage_memory.elapsed_seconds, held), p.damage_memory.elapsed_seconds - held)
	game.chapter_finale.active = false
	await get_tree().create_timer(Balance.COMBAT_MEMORY_SECONDS + 0.3, true).timeout
	Report.open(game.menus, false)
	await frames(4)
	_check("online.history_expires", p.damage_memory.hits.is_empty(), p.damage_memory.hits.duplicate(true))
	shot("06_online_history_expired", "real loopback host without guests; no replication claim")
	game.menus.close()
	net.multiplayer.multiplayer_peer = previous_peer
	peer.close()
	for key in saved:
		net.set(key, saved[key])
	enemy.queue_free()
	_check("online.cleaned_up", not net.is_online() and net.multiplayer.multiplayer_peer == previous_peer, net.is_online())

