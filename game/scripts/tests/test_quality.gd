extends RefCounted


static func run(t: Node) -> String:
	var weather_error: String = preload("res://scripts/tests/test_weather_depth.gd").run(t.game)
	if weather_error != "":
		return weather_error
	var rim_error := enemy_rims(t)
	if rim_error != "":
		return rim_error
	var g: Game = t.game
	var p: Player = g.local_player
	var saved := {"hp": p.hp, "root": p.rooted_time, "physics": p.is_physics_processing(),
		"terrain": g.terrain_event_t, "paused": t.get_tree().paused,
		"settings": g.settings.duplicate(true), "lock": p.locked_target}
	var enemies := {}
	for e in t.get_tree().get_nodes_in_group("enemies"):
		enemies[e] = e.is_physics_processing()
		e.set_physics_process(false)
	g.menus.close()
	p.set_physics_process(false)
	g.terrain_event_t = 10000.0
	p.rooted_time = 0.0
	var error := await damage_numbers(t)
	if error == "":
		error = await _live_damage_numbers(t)
	if error == "":
		error = await _ground_contracts(t)
	if error == "":
		error = _foliage_contracts(g)
	g.cancel_ground_attacks()
	t.get_tree().paused = saved["paused"]
	p.hp = saved["hp"]
	p.rooted_time = saved["root"]
	p.set_physics_process(saved["physics"])
	g.terrain_event_t = saved["terrain"]
	g.settings = saved["settings"]
	p.locked_target = saved["lock"] if is_instance_valid(saved["lock"]) else null
	for e in enemies:
		if is_instance_valid(e):
			e.set_physics_process(enemies[e])
	if error == "":
		print("ok: ground warnings pause/resume/cancel, guest effects cannot hurt, targeted foliage restores")
	return error


## Isolated production bodies; no AI, damage, network registration or timers.
## Old behavior fails at the first missing EnemyRim child, not a derived value.
static func enemy_rims(t: Node) -> String:
	var g: Game = t.game
	var terrain_before: Array = g.terrain_by_zone.duplicate()
	var window := t.get_tree().root
	var window_before := window.size
	var holder := Node2D.new()
	# In the tree for the per-frame path; disabled so no AI, physics or timers run.
	var live := Node2D.new()
	live.process_mode = Node.PROCESS_MODE_DISABLED
	t.add_child(live)
	var error := _enemy_rim_contracts(g, holder)
	if error == "":
		error = _enemy_rim_follow(g, live)
	# All failure paths restore the terrain and window and free every fixture.
	g.terrain_by_zone = terrain_before
	if window.size != window_before:
		window.size = window_before
	holder.free()
	live.free()
	if error == "":
		print("ENEMY RIM PASS: hostile/boss/decoy/mirror routing by the body's own room, friendly exclusions, room luminance, material composition, per-frame follow and window-stretch width")
	return error


## Two rooms other than the player's: the body's own floor, and one for a stale
## zone_idx. Fixtures give cur_room and the stale room the OPPOSITE floor, so
## only routing by the body's position passes.
static func _enemy_rim_rooms(g: Game) -> Array[int]:
	var rooms: Array[int] = []
	for i in g.terrain_by_zone.size():
		if i != g.cur_room and g.room_at_pos(g.room_center(i)) == i:
			rooms.append(i)
			if rooms.size() == 2:
				break
	return rooms


static func _enemy_rim_floor(g: Game, own: int, others: Array[int], terrain: String, dark: bool) -> void:
	g.terrain_by_zone[own] = terrain
	for i in others:
		if i >= 0 and i < g.terrain_by_zone.size():
			g.terrain_by_zone[i] = "capital_civic" if dark else "void"


static func _enemy_rim_contracts(g: Game, holder: Node2D) -> String:
	var rim_script := preload("res://scripts/enemy_rim.gd")
	var rooms := _enemy_rim_rooms(g)
	if rooms.size() < 2:
		return "enemy rim fixtures need two rooms besides the current one"
	var own: int = rooms[0]
	var others: Array[int] = [rooms[1], g.cur_room]
	var at := g.room_center(own)
	var enemy := Enemy.make(null, "wolf", at, -1, 1.0)
	var boss := Boss.new()
	boss._setup(null, "fangmaw", at)
	var mirror := Enemy.make(null, "blightwolf", at, -1, 1.0)
	mirror.net_mirror = true
	# Echo's Unnaming copies share his art and size; a boss add in its own art does not.
	var echo := Boss.new()
	echo._setup(null, "unnamed_echo", at)
	var copy := Enemy.make(null, "echo_clone", at, -1, 1.0)
	var add := Enemy.make(null, "choir_censer", at, -1, 1.0)
	var hostiles: Array[Enemy] = [enemy, boss, mirror, echo, copy, add]
	for actor in hostiles:
		holder.add_child(actor)
		actor.game = g
		actor.zone_idx = rooms[1]  # deliberately stale: position's room must win
	for actor in hostiles:
		if not actor.sprite.has_node("EnemyRim"):
			return "hostile factory did not attach its rim: " + actor.kind
		var rim: Sprite2D = actor.sprite.get_node("EnemyRim")
		if not rim.material is ShaderMaterial or rim.material.shader != rim_script.RIM_SHADER:
			return "hostile has no enemy_rim shader material"
		var dark_strength := 0.0
		for terrain: String in ["keep", "crystal", "void", "capital_civic", "holy", "keep"]:
			var dark: bool = terrain in ["keep", "crystal", "void"]
			_enemy_rim_floor(g, own, others, terrain, dark)
			rim.sync()
			var actual: float = rim.material.get_shader_parameter("rim_strength")
			if dark:
				if actual < 0.3 or actual > 0.45:
					return "dark floor rim outside the subtle-light range (read the player's or a stale room?): " + terrain
				dark_strength = actual
			elif actual >= dark_strength * 0.15:
				return "bright floor did not suppress the hostile rim (read the player's or a stale room?): " + terrain
		# Existing body effects must survive both updates and material swaps.
		var effect := ShaderMaterial.new()
		effect.shader = preload("res://shaders/silhouette.gdshader")
		actor.sprite.material = effect
		actor.sprite.modulate = Color(3, 0.7, 0.4, 0.25)
		actor.sprite.self_modulate.a = 0.5
		actor.sprite.flip_h = true
		actor.sprite.frame = actor.sprite.hframes - 1
		actor.sprite.offset += Vector2(3, -4)
		rim.sync()
		if actor.sprite.material != effect or actor.sprite.modulate != Color(3, 0.7, 0.4, 0.25):
			return "rim overwrote a body material or hit/tell tint"
		if rim.texture != actor.sprite.texture or rim.frame != actor.sprite.frame \
				or rim.flip_h != actor.sprite.flip_h or rim.offset != actor.sprite.offset \
				or rim.self_modulate.a != 0.5 or rim.get_parent() != actor.sprite:
			return "rim lost the body's frame, transform inheritance or fade"
		actor.sprite.material = null
		rim.sync()
		if actor.sprite.material != null or rim.material == null:
			return "clearing a body effect removed the independent rim"
	var normal: float = enemy.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	var stronger: float = boss.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	if stronger <= normal or not is_equal_approx(stronger, normal * Balance.ENEMY_RIM_BOSS_MULT):
		return "boss did not receive the stronger rim"
	var guest_strength: float = mirror.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	if not is_equal_approx(guest_strength, normal):
		return "guest mirror did not receive the same floor response as the host"
	var real_echo: float = echo.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	var copy_echo: float = copy.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	if not is_equal_approx(real_echo, stronger) or not is_equal_approx(copy_echo, real_echo):
		return "Echo's Unnaming copies wear a different rim from the real Echo (it gives him away)"
	var add_strength: float = add.sprite.get_node("EnemyRim").material.get_shader_parameter("rim_strength")
	if not is_equal_approx(add_strength, normal):
		return "a boss add in its own art took the boss rim"
	# Every friendly joins the holder before any assertion, so every exit frees it.
	var dummy := Dummy.new()
	holder.add_child(dummy)
	dummy._setup(null, "skeleton", Vector2.ZERO)
	var bodies: Array[Sprite2D] = []
	# Node2D = the NPC factory's actor type (its art is a child Sprite2D).
	for friendly: Node2D in [dummy, Node2D.new(), Ambience.Critter.new(), Player.new(),
			preload("res://scripts/pet_visual.gd").new()]:
		if friendly.get_parent() == null:
			holder.add_child(friendly)
		var body := Sprite2D.new()
		friendly.add_child(body)
		bodies.append(body)
	for body in bodies:
		if rim_script.attach(body.get_parent(), body) != null or body.has_node("EnemyRim"):
			return "friendly entity acquired a hostile rim"
	if dummy.sprite.has_node("EnemyRim"):
		return "training dummy's production body acquired a hostile rim"
	# Luminance response must be monotone through its transition, not just
	# a terrain-name allowlist. These authored tints lie between dark and civic.
	if rim_script.strength("capital_wayfinder", false) < rim_script.strength("capital_civic", false):
		return "luminance response increased on a brighter floor"
	return ""


## The per-frame path through the rim's own _process (the engine's process
## notification), never sync() by hand. Headless keeps it off (a --server
## world draws nothing); a real window must keep it on.
static func _enemy_rim_follow(g: Game, live: Node2D) -> String:
	var rim_script := preload("res://scripts/enemy_rim.gd")
	var rooms := _enemy_rim_rooms(g)
	var wolf := Enemy.make(null, "wolf", g.room_center(rooms[0]), -1, 1.0)
	wolf.remove_from_group("enemies")  # unseen by room-clear, targeting and AI
	live.add_child(wolf)
	wolf.game = g
	var rim: Sprite2D = wolf.sprite.get_node("EnemyRim")
	if rim.is_processing() == Enemy._is_headless():
		return "rim per-frame follow runs headless, or is off in a real window"
	var player_room: Array[int] = [g.cur_room]
	_enemy_rim_floor(g, rooms[0], player_room, "capital_civic", false)
	g.terrain_by_zone[rooms[1]] = "void"
	rim.notification(Node.NOTIFICATION_PROCESS)
	var bright: float = rim.material.get_shader_parameter("rim_strength")
	# Headless has no real window: stretch the fixture canvas 1.5x (1080p).
	var window := wolf.get_tree().root
	if Enemy._is_headless():
		window.size = Vector2i(Vector2(window.content_scale_size) * 1.5)
	# Walk into the dark room, turn, step the animation and fade.
	wolf.global_position = g.room_center(rooms[1])
	wolf.sprite.flip_h = not wolf.sprite.flip_h
	wolf.sprite.frame = (wolf.sprite.frame + 1) % (wolf.sprite.hframes * wolf.sprite.vframes)
	wolf.sprite.self_modulate.a = 0.4
	rim.notification(Node.NOTIFICATION_PROCESS)
	if rim.flip_h != wolf.sprite.flip_h or rim.frame != wolf.sprite.frame \
			or not is_equal_approx(rim.self_modulate.a, 0.4):
		return "rim did not follow the body's turn, frame or fade on its own process step"
	var dark: float = rim.material.get_shader_parameter("rim_strength")
	if dark <= bright or not is_equal_approx(dark, rim_script.strength("void", false)):
		return "rim kept the old room's floor after the body walked into another room"
	var stretch: float = rim.get_viewport().get_final_transform().get_scale().y
	if Enemy._is_headless() and not is_equal_approx(stretch, 1.5):
		return "fixture window did not stretch the canvas (got %.3f)" % stretch
	var width: float = rim.material.get_shader_parameter("rim_offset_px")
	if not is_equal_approx(width, Balance.ENEMY_RIM_OFFSET_PX * stretch):
		return "rim width stayed in raw pixels instead of following the canvas stretch"
	# A hidden body (burrowed, dev-morph driver) skips the per-frame work.
	wolf.sprite.visible = false
	wolf.sprite.flip_h = not wolf.sprite.flip_h
	rim.notification(Node.NOTIFICATION_PROCESS)
	if rim.flip_h == wolf.sprite.flip_h:
		return "a hidden body still paid for the per-frame rim sync"
	return ""


static func _ground_contracts(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var danger_error := await danger_rim(t)
	if danger_error != "":
		return danger_error
	# The real game's grade: every shelter ending below must hand it back.
	g.settings["impact_flashes"] = 1.0  # run() restores settings
	var env: Environment = g.glow_env.environment
	var grade := env.adjustment_saturation
	for safe in [false, true]:
		if safe:
			g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.22, 0)
		else:
			g.telegraph(p.global_position, 80, 0.22, 0)
		var attack: Node2D = g._ground_attacks.back()
		var clock: Node2D = attack.get_node("GroundTellClock")
		await t.get_tree().create_timer(0.06).timeout
		# SceneTree resumes timers BEFORE it steps tweens, so one long frame
		# (memory pressure) can end the wait above before the danger ramp's
		# first step. Resuming on the next frame start follows that frame's
		# tween step without advancing game time any further.
		await t.get_tree().process_frame
		if safe and env.adjustment_saturation >= grade:
			return "shelter fuse did not drain the real world saturation"
		t.get_tree().paused = true
		var progress: float = clock.progress
		var rim := g.hud.danger_rect.modulate.a if safe else 0.0
		await t.get_tree().create_timer(0.32, true).timeout
		if not is_instance_valid(clock) or not is_equal_approx(clock.progress, progress):
			return "ground warning advanced while the solo world was paused"
		if safe and not is_equal_approx(g.hud.danger_rect.modulate.a, rim):
			return "shelter's screen warning advanced while its ground fuse was paused"
		t.get_tree().paused = false
		await t.get_tree().create_timer(0.26).timeout
		if is_instance_valid(clock):
			return "ground warning failed to resolve after unpausing"
		if not is_equal_approx(env.adjustment_saturation, grade):
			return "resolved shelter fuse left the real world saturation drained"
		g.cancel_ground_attacks()
		await t.get_tree().process_frame
	# Cancel both attacks before their callbacks, including a falling sprite and
	# safe shelter. The stale callbacks must not apply their root to the hero.
	g.telegraph(p.global_position, 90, 0.15, 0, {"root": 2.0, "fireball": true})
	g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.15, 0, {"root": 2.0})
	await t.get_tree().create_timer(0.05).timeout
	g.cancel_ground_attacks()
	if not is_equal_approx(env.adjustment_saturation, grade):
		return "cancelled shelter fuse left the real world saturation drained"
	await t.get_tree().create_timer(0.2).timeout
	if p.rooted_time > 0.0 or not g._ground_attacks.is_empty():
		return "cancelled ground attack retained its visual or applied a status"
	if g.hud.danger_rect.modulate.a > 0.001:
		return "cancelled shelter left a danger wash behind"
	if not is_equal_approx(env.adjustment_saturation, grade):
		return "cancelled shelter fuse drained the real world saturation afterwards"
	# Mirrors must still show the marker but cannot apply local damage/statuses.
	var hp := p.hp
	g.telegraph(p.global_position, 90, 0.1, 9999, {"net_visual": true, "root": 2.0})
	await t.get_tree().create_timer(0.18).timeout
	g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.1, 9999, {"net_visual": true, "root": 2.0})
	await t.get_tree().create_timer(0.18).timeout
	if p.hp < hp or p.rooted_time > 0.0:
		return "visual-only guest ground attack applied local damage or control"
	return ""


static func _foliage_contracts(g: Game) -> String:
	var p: Player = g.local_player
	var e := Enemy.make(g, "wolf", p.global_position + Vector2(100, 0), -1, 1.0)
	g.world.add_child(e)
	e.set_physics_process(false)
	var saved_target = g.hud.target_bar_unit
	g.hud.target_bar_unit = e
	# Opaque test canopy: transforms/probes are real, independent of art luck.
	var pixels := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var leaf := Sprite2D.new()
	leaf.texture = ImageTexture.create_from_image(pixels)
	leaf.scale = Vector2(60, 60)
	leaf.position = e.global_position + Vector2(0, -30)
	leaf.set_meta("occlusion_sort_y", e.global_position.y + 120)
	leaf.set_meta("occlusion_radius", 180.0)
	leaf.add_to_group("combat_foliage")
	g.world.add_child(leaf)
	var clarity: Node = g.hud.combat_foliage
	g.settings["combat_foliage"] = true
	clarity._sample()
	clarity._process(0.3)
	var error := ""
	if leaf.self_modulate.a > Balance.COMBAT_FOLIAGE_ALPHA + 0.01:
		error = "foreground foliage still hides the target"
	g.settings["combat_foliage"] = false
	clarity._sample()
	clarity._process(0.3)
	if leaf.self_modulate.a < 0.99:
		error = "disabling combat foliage failed to restore its original alpha"
	g.settings["combat_foliage"] = true
	leaf.remove_from_group("combat_foliage")
	clarity._sample()
	clarity._process(0.3)
	if leaf.self_modulate.a < 0.99:
		error = "a non-foliage structure was made transparent"
	g.hud.target_bar_unit = saved_target if is_instance_valid(saved_target) else null
	leaf.queue_free()
	e.queue_free()
	return error


## A separate presentation fixture controls every precondition without borrowing
## the campaign's floating labels, room, RNG, damage or network state.
static func damage_numbers(t: Node) -> String:
	var g := preload("res://scripts/game_base.gd").new()
	t.add_child(g)
	var target := Node2D.new()
	g.add_child(target)
	var other := Node2D.new()
	g.add_child(other)
	var error := _damage_contracts(g, target, other)
	if error == "":
		g.clear_damage_numbers()
		error = _damage_merge_contracts(g)
	if error == "":
		g.clear_damage_numbers()
		var session := preload("res://scripts/net/net_session.gd").new()
		session.game = g
		error = _combat_text_contracts(g, target, session)
		session.free()
	g.clear_damage_numbers()
	g.queue_free()
	if error == "":
		error = _combat_text_wire(t)
	await t.get_tree().process_frame
	if error == "":
		print("DAMAGE NUMBERS PASS: rapid totals, DoT cadence, mixed combat words, announcements keep their plaque path, host fan-out ids + guest replay, opaque outlines, compaction, ally rows, number-only cap, expiry, detach/room cleanup")
	return error


## Host fan-out carries the target's wire identity (an Enemy's net_id, a
## Player's peer_id), and a guest replays each payload into that target's own
## column. Private fixtures: net_host() is pinned, nothing touches a session.
static func _combat_text_wire(t: Node) -> String:
	var host := HostGame.new()
	var wire := WireProbe.new()
	host.wire = wire
	host.add_child(wire)
	t.add_child(host)
	var foe := QuietEnemy.new()
	foe.net_id = 71
	host.add_child(foe)
	var ally := QuietPlayer.new()
	ally.peer_id = 5
	host.add_child(ally)
	host.spawn_combat_text_all(foe, "GUARD", Color(0.7, 0.85, 1.0))
	host.spawn_combat_text_all(ally, "INTERCEPT THEM", Color(1.0, 0.5, 0.2))
	var error := ""
	if wire.sent.size() != 2 or wire.sent[0][4] != 71 or wire.sent[0][5] != 0 \
			or wire.sent[1][4] != 0 or wire.sent[1][5] != 5:
		error = "host combat-text fan-out lost the target's wire identity"
	elif not _column_has(host, foe, "GUARD") or not _column_has(host, ally, "INTERCEPT THEM"):
		error = "host combat-text fan-out skipped the host's own column"
	if error == "":
		var guest := preload("res://scripts/game_base.gd").new()
		t.add_child(guest)
		var session := preload("res://scripts/net/net_session.gd").new()
		session.game = guest
		var mirror := QuietEnemy.new()
		guest.add_child(mirror)
		session.net_enemies[71] = mirror
		var shell := QuietPlayer.new()
		shell.peer_id = 5
		guest.add_child(shell)
		guest.players.append(shell)
		for sent in wire.sent:
			session._present_spawn_text(sent[0], sent[1], sent[2], sent[3], sent[4], sent[5])
		if not _column_has(guest, mirror, "GUARD") or not _column_has(guest, shell, "INTERCEPT THEM"):
			error = "a guest did not replay host combat text into the target's column"
		guest.clear_damage_numbers()
		session.free()
		guest.queue_free()
	host.clear_damage_numbers()
	host.queue_free()
	return error


class WireProbe extends Node:
	var sent: Array = []
	func host_spawn_text(pos: Vector2, text: String, color: Color, hold: float, enemy_id := 0, player_id := 0) -> void:
		sent.append([pos, text, color, hold, enemy_id, player_id])


class HostGame extends "res://scripts/game_base.gd":
	var wire: Node
	func net_host() -> bool: return true
	func net_session() -> Node: return wire


class QuietEnemy extends Enemy:
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass


class QuietPlayer extends Player:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass


static func _column_row(col: Node, l: Label) -> bool:
	for entry in col.entries:
		if entry.label == l:
			return true
	return false


static func _column_has(g: Node, target: Node2D, text: String) -> bool:
	var col: Node = g._damage_columns.get(target.get_instance_id())
	if col == null:
		return false
	for entry in col.entries:
		if is_instance_valid(entry.label) and entry.label.text == text:
			return true
	return false


## The z a CanvasItem actually draws at: relative z accumulates up its parents.
static func _effective_z(item: CanvasItem) -> int:
	var z := item.z_index
	while item.z_as_relative and item.get_parent() is CanvasItem:
		item = item.get_parent()
		z += item.z_index
	return z


static func _combat_text_contracts(g: Node, target: Node2D, session: Node) -> String:
	# Own precondition: _damage_contracts leaves a legacy numeric spawn_text
	# label ("99") in the density list; clear_damage_numbers only retires rows.
	for l in g._float_nums.duplicate():
		g._retire_float_num(l)
	var words := ["CRIT X5", "MISS", "WARD"]
	var colors := [Balance.DAMAGE_NUM_CRIT, Color(0.7, 0.7, 0.7), Color(0.6, 0.9, 1.0)]
	g.spawn_damage_number(target, 16)
	var col: Node = g._damage_columns[target.get_instance_id()]
	for i in words.size():
		g.spawn_combat_text(target, words[i], colors[i])
		if not _rows_clear(col):
			return "combat words overlap damage/each other on insertion"
	if col.entries.size() != 4:
		return "number + CRIT + MISS + WARD did not reserve four rows"
	# Sample a simultaneous shift before settlement, not just its end positions.
	for entry in col.entries:
		(entry.shift as Tween).custom_step(Balance.DAMAGE_NUM_SHIFT * 0.5)
	if not _rows_clear(col):
		return "mixed combat rows cross while shifting"
	_settle_damage(col)
	var expected := ["WARD", "MISS", "CRIT X5", "16"]
	for i in expected.size():
		var l: Label = col.entries[i].label
		if l.text != expected[i] or not is_equal_approx(l.position.y, -i * Balance.DAMAGE_NUM_ROW):
			return "mixed combat rows lost newest-first order"
		if l.z_as_relative or l.z_index != Balance.COMBAT_TEXT_Z:
			return "combat text does not own an absolute foreground layer"
		# The shared world treatment is a 4px ring at 0.92 alpha: rows get at
		# least the combat knob's ring, fully opaque.
		if l.get_theme_constant("outline_size") < Balance.COMBAT_TEXT_OUTLINE \
				or l.get_theme_color("font_outline_color") != Balance.COMBAT_TEXT_OUTLINE_COLOR:
			return "combat text lost its opaque dark outline"
		if l.get_theme_color("font_color").a != 1.0:
			return "local combat fill became translucent"
	var miss: Label = col.entries[1].label
	var old_life: Tween = col.entries[1].life
	g.spawn_combat_text(target, "MISS", colors[1])
	# kill() stops immediately; is_valid() only clears on SceneTree's next cleanup.
	if col.entries.size() != 4 or col.entries[1].label != miss \
			or old_life.is_running() or col.entries[1].life == old_life:
		return "repeated status did not reuse its row and replace its expiry"
	for i in words.size():
		if g._float_nums.has(col.entries[i].label):
			return "a combat word joined the number density cap"
	(col.entries[0].life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	_settle_damage(col)
	if col.entries.size() != 3 or col.entries[0].label != miss or not is_zero_approx(miss.position.y):
		return "status expiry failed to compact the shared column"
	col._process(Balance.DAMAGE_NUM_MERGE + 0.01)
	g.spawn_combat_text(target, "MISS", colors[1])
	if col.entries.size() != 4:
		return "status merged outside the column merge window"
	# Player damage is red, signed and opaque, and sums independently of healing.
	g.clear_damage_numbers()
	var red := Color(1.0, 0.35, 0.3, 0.3)
	g.spawn_combat_text(target, "-46", red)
	g.spawn_combat_text(target, "-15", red)
	g.spawn_combat_text(target, "+12", Color(0.5, 1.0, 0.6))
	g.spawn_combat_text(target, "-20 CRIT!", Color(1.0, 0.5, 0.1))
	g.spawn_combat_text(target, "GRIT x3", colors[2])
	col = g._damage_columns[target.get_instance_id()]
	_settle_damage(col)
	if not _rows_clear(col) or col.entries.size() != 4 or col.entries[3].label.text != "-61" \
			or col.entries[2].label.text != "+12" or col.entries[1].label.text != "-20 CRIT!":
		return "player hits/heals/status lost their signs, sums or spacing"
	if col.entries[3].label.get_theme_color("font_color") != g._floor_text_color(red):
		return "player damage lost its opaque red semantics"
	# A line that asks for reading time (hold > 0: "A DYING WAIL") keeps
	# spawn_text's announcement path and takes no row. This fixture has no HUD,
	# so the announcement lands as spawn_text's world-label fallback.
	g.clear_damage_numbers()
	var children := g.get_child_count()
	g.spawn_combat_text(target, "A DYING WAIL", colors[2], 2.0)
	if g._damage_columns.has(target.get_instance_id()):
		return "an announcement with reading time took a combat row"
	var announced: Node = null
	for i in range(children, g.get_child_count()):
		var child := g.get_child(i)
		if child is Label and child.text == "A DYING WAIL":
			announced = child
	if announced == null:
		return "an announcement with reading time was dropped"
	announced.free()
	# Replay the exact host wire payload through the guest presentation entry point.
	g.clear_damage_numbers()
	session.net_enemies[71] = target
	g.spawn_ally_damage(target, 16, false)
	for i in words.size():
		session._present_spawn_text(Vector2.ZERO, words[i], colors[i], 0.0, 71, 0)
	col = g._damage_columns[target.get_instance_id()]
	_settle_damage(col)
	if col.entries.size() != 4 or not _rows_clear(col):
		return "guest callouts did not join the ally damage column"
	for i in words.size():
		if col.entries[i].label.text != expected[i] or col.entries[i].label.get_theme_color("font_color") != g._floor_text_color(colors[2 - i]):
			return "guest combat word order/color differs from host presentation"
	session._present_spawn_text(Vector2.ZERO, "WARD", colors[2], 0.0, 999, 0)
	if col.entries.size() != 4 or g._damage_columns.size() != 1:
		return "late callout for a missing mirror spawned orphan combat text"
	# Legacy story/pickup messages must not reserve or evict combat rows.
	var floats_before: int = g._float_nums.size()
	g.spawn_text(Vector2.ZERO, "A quiet road.", Color.WHITE)
	g.spawn_text(Vector2.ZERO, "+ Bag", Color.WHITE)
	if g._float_nums.size() != floats_before or col.entries.size() != 4:
		return "narrative/pickup text entered the combat column"
	# Only numbers are capped. A burst past the cap evicts the oldest numbers
	# (the ally 16 first), never a live tell such as WARD.
	var tells: Array = []
	for i in words.size():
		tells.append(col.entries[i].label)
	for i in Balance.FLOAT_NUM_MAX + 3:
		g.spawn_damage_number(target, i + 1, true)
	if g._float_nums.size() != Balance.FLOAT_NUM_MAX:
		return "damage numbers bypassed the shared density cap"
	for tell in tells:
		if not is_instance_valid(tell) or tell.is_queued_for_deletion() or not _column_row(col, tell):
			return "a burst of numbers evicted a combat word before its life ended"
	if col.entries.size() != Balance.FLOAT_NUM_MAX + words.size():
		return "number eviction left the wrong rows in the column"
	for entry in col.entries.duplicate():
		(entry.life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	if not g._damage_columns.is_empty() or not g._float_nums.is_empty():
		return "combat labels outlived their final expiry"
	return ""


static func _settle_damage(column: Node) -> void:
	for entry in column.entries:
		if (entry.shift as Tween).is_valid():
			(entry.shift as Tween).custom_step(Balance.DAMAGE_NUM_SHIFT)
		if (entry.pop as Tween).is_valid():
			(entry.pop as Tween).custom_step(Balance.DAMAGE_NUM_POP_TIME)


## Rendered clearance, measured from the font rather than the row knob: the
## upper label's popped ink bottom (stylebox top + ascent + outline, scaled
## around its top edge) must stay above the next row's label top.
static func _row_clearance(l: Label) -> float:
	var f: Font = l.get_theme_font("font")
	var size: int = l.get_theme_font_size("font_size")
	var top := 0.0
	var box: StyleBox = l.get_theme_stylebox("normal")
	if box != null:
		top = box.get_margin(SIDE_TOP)
	return (top + f.get_ascent(size) + l.get_theme_constant("outline_size")) * Balance.DAMAGE_NUM_POP


static func _rows_clear(col: Node) -> bool:
	for i in range(1, col.entries.size()):
		var upper: Label = col.entries[i].label
		if col.entries[i - 1].label.position.y - upper.position.y < _row_clearance(upper):
			return false
	return true


static func _damage_contracts(g: Node, target: Node2D, other: Node2D) -> String:
	# N rapid hits, including a digit-width change, produce ONE running total.
	for amount in [28, 32, 16, 100]:
		g.spawn_damage_number(target, amount)
	var col: Node = g._damage_columns[target.get_instance_id()]
	_settle_damage(col)
	if col.entries.size() != 1 or g._float_nums.size() != 1 or col.entries[0].label.text != "176":
		return "rapid hits did not combine into exactly one 176 label"
	g.spawn_damage_number(other, 9)
	if g._damage_columns.size() != 2:
		return "distinct target instance IDs shared a damage column"
	# Same-frame crits stay separate; two tick kinds merge freely into one muted row.
	g.spawn_damage_number(target, 40, true)
	g.spawn_damage_number(target, 7, false, true)
	g.spawn_damage_number(target, 8, true, true)
	g.spawn_damage_number(target, 11, true)
	if not _rows_clear(col):
		return "same-frame hits overlapped before their row tweens settled"
	_settle_damage(col)
	if col.entries.size() != 4:
		return "crit/DoT merge policy produced the wrong number of rows"
	if not _rows_clear(col):
		return "the row pitch is too small for the outlined, popped digits above it"
	var total := 0
	for i in col.entries.size():
		var entry: Dictionary = col.entries[i]
		total += int(entry.total)
		var l: Label = entry.label
		if not is_equal_approx(l.position.y, -i * Balance.DAMAGE_NUM_ROW):
			return "new head did not push existing numbers up one row"
		if not is_equal_approx(l.position.x + l.size.x * 0.5, 0.0):
			return "a running total lost its centered column"
	if total != 242 or col.entries[1].label.text != "15":
		return "combined totals differ from submitted damage"
	if col.entries[0].label.get_theme_color("font_color") != Balance.DAMAGE_NUM_CRIT \
			or col.entries[1].label.get_theme_color("font_color") != Balance.DAMAGE_NUM_DOT \
			or col.entries[3].label.get_theme_color("font_color") != Balance.DAMAGE_NUM_NORMAL:
		return "damage kinds lost their fixed colors"
	if col.entries[1].label.get_theme_font_size("font_size") >= col.entries[3].label.get_theme_font_size("font_size"):
		return "DoT digits are not smaller than normal damage"
	# Expired merge window makes another head; this clock is entirely controlled.
	col._process(Balance.DAMAGE_NUM_MERGE + 0.01)
	g.spawn_damage_number(target, 3)
	if col.entries.size() != 5 or col.entries[0].total != 3:
		return "normal damage merged beyond the merge window"
	g.spawn_ally_damage(target, 4, false)
	_settle_damage(col)
	if col.entries.size() != 6 or col.entries[0].label.get_theme_color("font_color").a >= 1.0:
		return "ally numbers lost separate subordinate styling"
	# Expiry removes both the label and its target index, without deferred stale tweens.
	var other_col: Node = g._damage_columns[other.get_instance_id()]
	(other_col.entries[0].life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	if g._damage_columns.has(other.get_instance_id()):
		return "expired number retained its target index"
	# The same global cap includes legacy numeric spawn_text and target columns.
	for i in Balance.FLOAT_NUM_MAX + 3:
		g.spawn_damage_number(target, i + 1, true)
	g.spawn_text(Vector2.ZERO, "99", Color.WHITE)
	if g._float_nums.size() != Balance.FLOAT_NUM_MAX:
		return "damage numbers bypassed the global density cap"
	for l in g._float_nums:
		if not is_instance_valid(l) or l.is_queued_for_deletion():
			return "density cap retained a retired label"
	# A dying/queued target leaves its numbers where it fell to finish their fade.
	g.clear_damage_numbers()
	g.spawn_damage_number(other, 12)
	other_col = g._damage_columns[other.get_instance_id()]
	var fell: Vector2 = other_col.global_position
	other.position += Vector2(80, 0)
	other.queue_free()
	other_col._process(0.0)
	var last: Label = other_col.entries[0].label
	if not other_col.detached or not last.visible or last.is_queued_for_deletion() \
			or not is_equal_approx(other_col.global_position.x, fell.x):
		return "a dying target's numbers vanished or followed it instead of finishing where it fell"
	(other_col.entries[0].life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	if not g._damage_columns.is_empty():
		return "a detached column outlived its last number"
	g.spawn_damage_number(target, 13)
	col = g._damage_columns[target.get_instance_id()]
	g.cur_room += 1
	col._process(0.0)
	if not g._damage_columns.is_empty():
		return "room change retained target labels"
	return ""


const DOT_TICK := 0.5 # enemy.gd burn/bleed tick cadence


static func _damage_merge_contracts(g: Node) -> String:
	var target := Node2D.new()
	g.add_child(target)
	var other := Node2D.new()
	g.add_child(other)
	# DoT ticks at the real cadence build ONE running total; a crit tick stays in it.
	g.spawn_damage_number(target, 6, false, true)
	var col: Node = g._damage_columns[target.get_instance_id()]
	g.spawn_damage_number(other, 5)
	col._process(DOT_TICK)
	g.spawn_damage_number(target, 6, false, true)
	col._process(DOT_TICK)
	g.spawn_damage_number(target, 7, true, true)
	_settle_damage(col)
	if col.entries.size() != 1 or col.entries[0].label.text != "19":
		return "DoT ticks at the 0.5s cadence did not build one running total"
	# A live total moves to the back of the density-cap list: the cap evicts idle numbers first.
	if g._float_nums.back() != col.entries[0].label or g._float_nums.front() == col.entries[0].label:
		return "a merging running total kept its creation slot in the density cap"
	# Rows compact: when a newer row expires, the older running total settles back down.
	g.clear_damage_numbers()
	g.spawn_damage_number(target, 10)
	col = g._damage_columns[target.get_instance_id()]
	g.spawn_damage_number(target, 30, true)
	_settle_damage(col)
	var running: Label = col.entries[1].label
	if not is_equal_approx(running.position.y, -Balance.DAMAGE_NUM_ROW):
		return "a crit did not push the running total up one row"
	(col.entries[0].life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	_settle_damage(col)
	if col.entries.size() != 1 or col.entries[0].label != running or not is_equal_approx(running.position.y, 0.0):
		return "an older row stayed stranded high after the newer row expired"
	# An ally's blows share one quiet row (any crit marks it "!"), so a friend's
	# crits never keep shoving your own numbers up the screen.
	g.spawn_ally_damage(target, 5, false)
	g.spawn_ally_damage(target, 9, true)
	g.spawn_ally_damage(target, 4, true)
	_settle_damage(col)
	if col.entries.size() != 2 or not col.entries[0].ally or col.entries[0].label.text != "18!":
		return "an ally's crits opened extra rows instead of sharing one quiet row"
	var ally: Label = col.entries[0].label
	var tint: Color = ally.get_theme_color("font_color")
	if not is_equal_approx(tint.a, Balance.DAMAGE_NUM_ALLY_ALPHA) \
			or not Color(tint, 1.0).is_equal_approx(Color(Balance.DAMAGE_NUM_CRIT, 1.0)) \
			or ally.get_theme_font_size("font_size") != Balance.DAMAGE_NUM_ALLY_SIZE:
		return "an ally crit row lost its small, faded gold style"
	return ""


## The real Enemy wiring: direct hits, DoT ticks and the killing blow all land in
## the struck wolf's column (offline, every number is the local player's own).
static func _live_damage_numbers(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var e := Enemy.make(g, "wolf", p.global_position + Vector2(-140, 0), -1, 1.0)
	g.world.add_child(e)
	e.set_physics_process(false)
	e.max_hp = 10000.0
	e.hp = e.max_hp
	# The kill below stays presentation-only: no XP, gold, loot or kill credit.
	e.xp_value = 0
	e.gold_value = 0
	e.set_meta("ward_spawn", true)
	var id := e.get_instance_id()
	var error := _live_miss_contracts(g, p, e)
	g.clear_damage_numbers(id)
	if error == "":
		error = _live_damage_contracts(g, e)
	g.clear_damage_numbers(id)
	e.queue_free()
	await t.get_tree().process_frame
	if error == "":
		print("ok: live wolf hits, a real MISS beside its number above the HP bar and reticle, DoT ticks and the killing blow share one damage column")
	return error


## The sweep's "MISS behind 16": hit_enemy's real miss branch must land in the
## struck wolf's column as its own row beside the number, and every row must
## draw above the wolf's HP bar and the target reticle.
static func _live_miss_contracts(g: Game, p: Player, e: Enemy) -> String:
	var saved := {"dex": p.dex, "eva": e.eva}
	p.dex = 0.0  # DEX tier 0: an evade is a full miss, never a graze
	e.eva = 1000.0
	e.take_damage(16.0)
	# The evade roll is the hit's first global randf: pin a seed that evades.
	var hits := 0
	for candidate in range(256):
		if hits >= 8 or _column_has(g, e, "MISS"):
			break
		seed(candidate)
		if randf() >= Stats.eva_curve(e.eva):
			continue
		seed(candidate)
		hits += 1
		p.hit_enemy(e, 1.0, {"type": "phys"})
	randomize()  # global RNG has no snapshot API; leave later sections unseeded
	p.dex = saved["dex"]
	e.eva = saved["eva"]
	var col: Node = g._damage_columns.get(e.get_instance_id())
	if col == null or not _column_has(g, e, "MISS"):
		return "a real player miss never reached the struck wolf's damage column"
	_settle_damage(col)
	if col.entries[0].label.text != "MISS" or col.entries.size() < 2 or not _rows_clear(col):
		return "a real MISS overprinted the wolf's damage number"
	for entry in col.entries:
		var l: Label = entry.label
		for overlay in [e.hp_bar_bg, e.hp_bar_fg, e.hp_bar_cap, g.reticle]:
			if l.z_as_relative or l.z_index <= _effective_z(overlay):
				return "combat text draws beneath the wolf's HP bar or the target reticle"
	return ""


static func _live_damage_contracts(g: Game, e: Enemy) -> String:
	var hp := e.hp
	for amount in [28.0, 32.0, 16.0]:
		e.take_damage(amount)
	var col: Node = g._damage_columns.get(e.get_instance_id())
	if col == null or col.entries.size() != 1:
		return "live wolf hits did not share one running total"
	_settle_damage(col)
	var dealt := int(round(hp - e.hp))
	if col.entries[0].total != dealt or col.entries[0].label.text != str(dealt):
		return "the live wolf's running total differs from the damage it took"
	# Burn/bleed ticks: silent for gameplay, one muted running total across the cadence.
	e._take_dot_damage(9.0)
	col._process(DOT_TICK)
	e._take_dot_damage(9.0)
	_settle_damage(col)
	if col.entries.size() != 2 or col.entries[0].kind != "dot" or col.entries[0].label.text != "18" \
			or col.entries[0].label.get_theme_color("font_color") != Balance.DAMAGE_NUM_DOT:
		return "live DoT ticks did not build one muted running total"
	# The killing blow's number stays on screen where the wolf fell, then fades.
	e.hp = 5.0
	e.take_damage(40.0, Vector2.ZERO, true)
	if not e.dying:
		return "the lethal test hit did not kill the wolf"
	col = g._damage_columns.get(e.get_instance_id())
	if col == null or col.entries.size() != 3:
		return "the killing blow wiped the wolf's damage numbers"
	var kill: Label = col.entries[0].label
	if col.entries[0].total != 40 or kill.text != "40!" or not kill.visible or kill.is_queued_for_deletion():
		return "the killing blow's number was not shown"
	col._process(0.0)
	var fell: Vector2 = col.global_position
	e.global_position += Vector2(120, 0)
	col._process(0.0)
	if not col.detached or not is_equal_approx(col.global_position.x, fell.x):
		return "a dead wolf's numbers followed the corpse instead of staying where it fell"
	for entry in col.entries.duplicate():
		(entry.life as Tween).custom_step(Balance.DAMAGE_NUM_LIFE + 0.01)
	if g._damage_columns.has(e.get_instance_id()):
		return "a dead wolf's column outlived its numbers"
	return ""


## Shared by the quick safe-zone section and floorfield's one-run visual bundle.
## A disposable HUD/environment controls the starting grade and restores borrowed
## state even when a contract fails. No campaign loot/earlier-section dependency.
static func danger_rim(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	var saved := {"hud": g.hud, "env": g.glow_env.environment,
		"settings": g.settings.duplicate(true), "room": g.cur_room,
		"state": g.state, "dead": p.dead, "downed": p.downed, "ghost": p.ghost,
		"mode": g.process_mode, "paused": t.get_tree().paused}
	g.process_mode = Node.PROCESS_MODE_DISABLED
	t.get_tree().paused = false
	g.state = Game.ST_PLAYING
	p.dead = false
	p.downed = false
	p.ghost = false
	g.settings["impact_flashes"] = 1.0
	var env := Environment.new()
	env.adjustment_saturation = 0.93  # deliberately not WORLD_SATURATION
	env.adjustment_contrast = 1.0
	g.glow_env.environment = env
	var hud := Hud.new()
	hud.game = g
	g.hud = hud
	g.add_child(hud)
	hud.set_process(false)
	var error := await _danger_contracts(t, hud, env)
	hud.free()  # actual tree exit mid-fuse must restore the borrowed resource
	if not is_equal_approx(env.adjustment_saturation, 0.93):
		error = "HUD teardown left saturation drained"
	g.hud = saved["hud"]
	g.glow_env.environment = saved["env"]
	g.settings = saved["settings"]
	g.cur_room = saved["room"]
	g.state = saved["state"]
	p.dead = saved["dead"]
	p.downed = saved["downed"]
	p.ghost = saved["ghost"]
	g.process_mode = saved["mode"]
	t.get_tree().paused = saved["paused"]
	if error == "":
		print("DANGER RIM PASS: mask, pulse, comfort, pause, end/cancel, room/death/teardown restore")
	return error


static func _danger_contracts(t: Node, hud: Hud, env: Environment) -> String:
	var g: Game = t.game
	var mask := Art._make_dangerrim()
	# At 60% of a half-axis the old 45% square mask was already red.
	if mask.get_pixel(256, 90).a > 0.001 or mask.get_pixel(160, 90).a > 0.001:
		return "danger rim reaches into the readable centre"
	if mask.get_pixel(256, 144).a <= 0.0:
		return "danger rim is not elliptical"
	for ending in ["caught", "sheltered", "cancel", "room", "dead", "downed", "ghost", "victory"]:
		var interrupted: bool = ending not in ["caught", "sheltered"]
		hud.danger_ramp(0.2 if interrupted else 0.12)
		await t.get_tree().create_timer(0.08 if interrupted else 0.18).timeout
		if not interrupted:
			# SceneTree resumes timers BEFORE it steps tweens, so one long frame
			# can fire the wait above ahead of the ramp's final step. Poll the
			# wall clock until the fuse itself has finished (never await its
			# `finished`: it may already have fired and the await would hang).
			var deadline := Time.get_ticks_msec() + 1000
			while hud.danger_tw != null and hud.danger_tw.is_valid() and hud.danger_tw.is_running() \
					and Time.get_ticks_msec() < deadline:
				await t.get_tree().create_timer(0.02).timeout
		if env.adjustment_saturation >= 0.93:
			return "safe-zone fuse did not drain saturation: " + ending
		if not interrupted and not is_equal_approx(env.adjustment_saturation, Balance.DANGER_SATURATION):
			return "completed safe-zone fuse missed its saturation target"
		if hud.danger_rect.modulate.a > 0.55 or hud.danger_rect.modulate.r > 1.3:
			return "danger rim exceeded its alpha/HDR cap"
		if ending == "caught" or ending == "sheltered":
			hud.danger_end(ending == "sheltered")
		elif ending == "cancel":
			hud.danger_cancel()
		else:
			# Through real frames: only Hud._process notices these, so this
			# also proves the lifetime check is hooked into it.
			var room := g.cur_room
			if ending == "room": g.cur_room += 1
			if ending == "dead": g.local_player.dead = true
			if ending == "downed": g.local_player.downed = true
			if ending == "ghost": g.local_player.ghost = true
			if ending == "victory": g.state = Game.ST_VICTORY
			hud.set_process(true)
			# process_frame fires BEFORE the frame's _process: the second resume
			# guarantees one whole HUD process pass ran in between.
			await t.get_tree().process_frame
			await t.get_tree().process_frame
			hud.set_process(false)
			g.cur_room = room
			g.local_player.dead = false
			g.local_player.downed = false
			g.local_player.ghost = false
			g.state = Game.ST_PLAYING
		if not is_equal_approx(env.adjustment_saturation, 0.93):
			return "safe-zone saturation failed to restore: " + ending
		if interrupted:
			# Outlast the rest of the killed ramp: a stale tween would drain again.
			await t.get_tree().create_timer(0.2).timeout
			if not is_equal_approx(env.adjustment_saturation, 0.93):
				return "stale fuse drained saturation after " + ending
	# Live pause and replacement must preserve the captured original grade.
	hud.danger_ramp(0.2)
	await t.get_tree().create_timer(0.08).timeout
	t.get_tree().paused = true
	var grade := env.adjustment_saturation
	var alpha := hud.danger_rect.modulate.a
	await t.get_tree().create_timer(0.18, true).timeout
	if not is_equal_approx(env.adjustment_saturation, grade) or not is_equal_approx(hud.danger_rect.modulate.a, alpha):
		return "danger grade/pulse advanced while paused"
	t.get_tree().paused = false
	hud.danger_ramp(0.12)
	await t.get_tree().create_timer(0.18).timeout
	hud.danger_cancel()
	if not is_equal_approx(env.adjustment_saturation, 0.93):
		return "replacement fuse captured the already drained grade"
	# The pulse must read inside the shipped boss fuses (boss.gd: 2.0 and 2.2 s).
	# Walk the tween's own clock (elapsed 0..fuse) by hand, without wall-clock
	# races: the rim must visibly dip at least once at full comfort strength.
	# Impact flashes calm the pulse and the drain but never hide the warning.
	var dips := {}
	for fuse in [2.0, 2.2]:
		for strength in [1.0, 0.5, 0.0]:
			g.settings["impact_flashes"] = strength
			hud.danger_ramp(fuse)
			hud.danger_tw.pause()
			var high := 0.0
			var dip := 0.0
			var steps := ceili(fuse / 0.05)
			for i in steps + 1:
				hud._danger_step(minf(i * 0.05, fuse), fuse)
				var a := hud.danger_rect.modulate.a
				if a > Balance.DANGER_RIM_ALPHA + 0.001:
					return "danger rim exceeded its alpha cap"
				high = maxf(high, a)
				dip = maxf(dip, high - a)
			dips[strength] = dip
			var drained := lerpf(0.93, Balance.DANGER_SATURATION, strength)
			if not is_equal_approx(env.adjustment_saturation, drained):
				return "danger saturation ignored impact-flash comfort (%d%%)" % roundi(strength * 100)
			# The rim still reads near its cap by the fuse's end at every setting.
			if high < 0.45 or hud.danger_rect.modulate.a < 0.4:
				return "impact-flash comfort hid the safe-zone rim (%d%%, %.1f s)" % [roundi(strength * 100), fuse]
		# A visible breath (0.1 of alpha) at full strength, none at 0%.
		if dips[1.0] < 0.1:
			return "danger rim pulse is not visible within a %.1f s fuse" % fuse
		if dips[0.0] > 0.001 or not (dips[0.0] < dips[0.5] and dips[0.5] < dips[1.0]):
			return "impact-flash comfort did not calm the danger pulse"
	if Balance.DANGER_RIM_PULSE_SECONDS < 0.5:
		return "danger pulse is faster than a slow breath (strobe risk)"
	if not is_equal_approx(env.adjustment_contrast, 1.0):
		return "danger changed HDR2D contrast"
	g.settings["impact_flashes"] = 1.0
	hud._danger_step(1.0, 1.0)
	return ""  # caller frees this actively drained HUD to test teardown
