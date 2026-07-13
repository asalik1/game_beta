extends Node
## MOB-MECHANIC RIG (dev tool): boots the game and exercises the redesign
## mechanics so the tells read by LOOKING and the behaviors are confirmed
## at runtime (independent of the test suite). Run:
##   godot --path game res://shot_mobs.tscn

var game: Game
var fails: Array = []


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % nm))
	print("SHOT: ", ProjectSettings.globalize_path("user://shots/%s.png" % nm))


func _check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails.append(label)


func _ready() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class("warrior")
	await _frames(5)
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	game.player.max_hp = 999999.0
	game.player.hp = 999999.0
	await _frames(8)
	var base: Vector2 = game.player.global_position

	# --- WARDED: reduced damage until a status lands ---
	var husk := Enemy.make(game, "sun_bleached", base + Vector2(300, 0))
	game.add_enemy(husk)
	husk.hp = husk.max_hp
	husk.take_damage(100.0, Vector2.ZERO, false, true)
	var w_loss := husk.max_hp - husk.hp
	husk.hp = husk.max_hp
	husk.apply_burn(1.0, 3.0)
	husk.take_damage(100.0, Vector2.ZERO, false, true)
	var c_loss := husk.max_hp - husk.hp
	_check(c_loss > w_loss * 1.5, "warded ward drops under a status (%.0f -> %.0f)" % [w_loss, c_loss])

	# --- BLOAT: death leaves a hazard pool ---
	var hz0 := game.hazards.size()
	var bl := Enemy.make(game, "casket_creeper", base + Vector2(340, 0))
	game.add_enemy(bl); bl.zone_idx = 0
	bl.take_damage(9e9, Vector2.ZERO, false, true)
	await _frames(3)
	_check(game.hazards.size() > hz0, "bloat leaves a hazard pool")

	# --- MARTYR: death heals + enrages an ally ---
	var m := Enemy.make(game, "vale_mourner", base + Vector2(300, -40))
	var ally := Enemy.make(game, "gravewalker", base + Vector2(330, -40))
	game.add_enemy(m); game.add_enemy(ally)
	m.zone_idx = 0; ally.zone_idx = 0
	ally.hp = ally.max_hp * 0.3
	var ally_dmg0 := ally.dmg
	m.take_damage(9e9, Vector2.ZERO, false, true)
	await _frames(2)
	_check(ally.hp > ally.max_hp * 0.3 and ally.dmg > ally_dmg0, "martyr heals+enrages an ally")

	# --- WEB: rooting shot roots the player ---
	var spider := Enemy.make(game, "spider", base + Vector2(260, 0))
	game.player.rooted_time = 0.0
	spider._web_shot(Vector2.RIGHT)
	await _frames(3)  # projectile travels to the player at 300px/s? place close
	spider.global_position = base + Vector2(60, 0)
	spider._web_shot((base - spider.global_position).normalized())
	await get_tree().create_timer(0.4).timeout
	_check(game.player.rooted_time > 0.0, "web shot roots the player")

	# --- CHANNEL_HEAL: interrupt breaks the channel ---
	var healer := Enemy.make(game, "cultist", base + Vector2(300, 40))
	game.add_enemy(healer); healer.zone_idx = 0
	healer._begin_channel()
	_check(healer.channel_t > 0.0, "channel starts")
	healer.take_damage(1.0, Vector2.ZERO, false, true)
	_check(healer.channel_t <= 0.0, "channel breaks on damage")

	# --- REFLECT: shield window bounces damage back ---
	var smith := Enemy.make(game, "forge_acolyte", base + Vector2(320, -80))
	game.add_enemy(smith); smith.zone_idx = 0
	smith._raise_reflect()
	game.player.hp = game.player.max_hp
	game.player.hurt_cd = 0.0  # clear the prior web-hit i-frame
	var php0 := game.player.hp
	smith.take_damage(200.0, Vector2.ZERO, false, false)
	_check(game.player.hp < php0, "reflect bounces damage to the player")

	# --- COUNTER: hitting a raised guard staggers the player ---
	var sent := Enemy.make(game, "vow_sentinel", base + Vector2(340, -120))
	game.add_enemy(sent); sent.zone_idx = 0
	sent._raise_guard()
	game.player.rooted_time = 0.0
	sent.take_damage(50.0, Vector2.ZERO, false, false)
	_check(game.player.rooted_time > 0.0, "counter staggers the player who strikes the guard")

	# A visual lineup: forge shield up, healer beam, guard glow.
	var line := ["cinder_whelp", "forge_acolyte", "hushcaller", "root_shambler", "void_shade"]
	for i in line.size():
		var e := Enemy.make(game, line[i], base + Vector2(180 + i * 95, 80))
		game.add_enemy(e)
	await _frames(6)
	_shot("mobs_mechanics")

	print("MECHANIC CHECKS: %d fail(s) %s" % [fails.size(), str(fails)])
	get_tree().quit(1 if fails.size() > 0 else 0)
