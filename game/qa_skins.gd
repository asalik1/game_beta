extends Node
## SKIN-COMPLETION QA (dev, temporary): boots the real game once per class,
## equips each of the class's skins (base then awakened where defined), and
## fires every ability slot — executing the skin-gated FX branches the
## suites never reach and forcing the awakened strip sets through the real
## render resolver. Pure exercise: pass = no SCRIPT ERROR in the log and
## every skin state resolves a live sprite texture.
## Run headless:  godot --headless --path game res://qa_skins.tscn

const CLASSES := ["warrior", "archer", "mage", "paladin", "warlock", "assassin"]
var fails := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var run_classes: Array = CLASSES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			var requested := arg.trim_prefix("--class=")
			run_classes = [requested] if requested in CLASSES else []
	for cls in run_classes:
		await _run_class(cls)
	if fails == 0:
		print("QA SKINS PASS")
	else:
		print("QA SKINS FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _run_class(cls: String) -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	var game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class(cls)
	await _frames(5)
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	var p = game.player
	p.max_hp = 999999.0
	p.hp = 999999.0
	p.mp = 9999.0
	await get_tree().create_timer(0.4).timeout
	# a target so aimed abilities (marks, judgments, rifts) have a victim
	var dummy = Enemy.make(game, "wolf", p.global_position + Vector2(0, -150))
	game.add_enemy(dummy)
	dummy.max_hp = 999999.0
	dummy.hp = 999999.0
	await _frames(4)
	if cls == "mage":
		await _assert_void_bolt_cosmetic_parity(p)
		await _assert_void_eye_spam_cleanup(p)
		await _assert_crystal_bolt_cosmetic_parity(p)
		await _assert_mage_ult_circle(p)
	elif cls == "archer":
		await _assert_archer_cosmetic_parity(p, dummy)
	elif cls == "assassin":
		await _assert_assassin_execution_timing(p, dummy)
	for entry in Skins.skins_for(cls):
		var states := [false]
		if entry.has("awakened_sprite"):
			states.append(true)
		for awakened in states:
			game.set_flag("s_awakened_" + cls, awakened)
			p.skin = entry["id"]
			p.refresh_skin_sprite()
			await _frames(3)
			var tag := "%s/%s%s" % [cls, entry["id"], "+awakened" if awakened else ""]
			if p.sprite == null or p.sprite.texture == null:
				print("QA FAIL: no sprite texture for ", tag)
				fails += 1
			for slot in ["a1", "a2", "a3", "ult"]:
				p.cds[slot] = 0.0
				p.use_ability(slot)
				# Swing/cast delays are wall-clock; skin ults resolve at 0.62s,
				# so keep their owners alive through impact and cleanup callbacks.
				await get_tree().create_timer(0.72).timeout
				if not is_instance_valid(dummy) or dummy.dying:
					dummy = Enemy.make(game, "wolf", p.global_position + Vector2(0, -150))
					game.add_enemy(dummy)
					dummy.max_hp = 999999.0
					dummy.hp = 999999.0
			print("qa ok: ", tag)
	game.set_flag("s_awakened_" + cls, false)
	game.queue_free()
	await _frames(6)


func _assert_void_bolt_cosmetic_parity(p: Player) -> void:
	# Regression guard for the skin contract: the eye may own the rendered
	# origin, but the real projectile must remain the base Firebolt in space.
	var dir := Vector2.RIGHT
	var speed := 440.0 * float(p._tfx.get("proj_speed", 1.0))
	var base: Projectile = p._proj(dir, 1.0, "mage_firebolt", speed)
	p._finish_mage_bolt(base, 1.0)
	var eye: Node2D = p._spawn_void_cast_eye(dir, 0.0)
	var void_bolt: Projectile = p._cast_void_eye_bolt(eye, dir, 1.0)
	var physics_match := base.global_position.is_equal_approx(void_bolt.global_position) \
		and base.vel.is_equal_approx(void_bolt.vel) \
		and is_equal_approx(base.life, void_bolt.life) \
		and base.collision_mask == void_bolt.collision_mask \
		and base.pierce == void_bolt.pierce \
		and base.homing == void_bolt.homing \
		and is_equal_approx(base.hit_player_mult, void_bolt.hit_player_mult) \
		and base.fx == void_bolt.fx
	var eye_spr := eye.get_node_or_null("Eye") as Sprite2D
	var eye_center := eye.to_global(eye_spr.position) if eye_spr != null else eye.global_position
	var visual_match := void_bolt._fx_pos().distance_to(eye_center) < 0.05
	if not physics_match or not visual_match:
		print("QA FAIL: Void Firebolt changed base physics or missed eye centre")
		fails += 1
	else:
		print("qa ok: mage/void_weaver cosmetic projectile parity")
	base.queue_free()
	void_bolt.queue_free()
	await _frames(2)
	if is_instance_valid(eye) and not eye.get_meta("dismissing", false):
		print("QA FAIL: Void Firebolt eye survived projectile tree exit")
		fails += 1
	else:
		print("qa ok: mage/void_weaver eye cleanup on projectile exit")


func _assert_void_eye_spam_cleanup(p: Player) -> void:
	var saved_skin := p.skin
	p.skin = "void_weaver"
	p.refresh_skin_sprite()
	for i in 8:
		p.cds["a1"] = 0.0
		p.mp = p.max_mp
		p.use_ability("a1")
		await get_tree().create_timer(0.13).timeout
	# Longer than base projectile life plus the eye's closing tween: even shots
	# that miss every body and wall must leave no orphaned focuses behind.
	await get_tree().create_timer(2.95).timeout
	var survivors := 0
	for eye in get_tree().get_nodes_in_group("void_weaver_cast_eye"):
		if is_instance_valid(eye):
			survivors += 1
	if survivors > 0:
		print("QA FAIL: %d Void Firebolt eye(s) survived spam cleanup" % survivors)
		fails += 1
	else:
		print("qa ok: mage/void_weaver repeated-cast eye cleanup")
	p.skin = saved_skin
	p.refresh_skin_sprite()


func _assert_crystal_bolt_cosmetic_parity(p: Player) -> void:
	# The Court may choose a floating visual origin, but the paid skin must keep
	# every gameplay-bearing property of the base Firebolt.
	var dir := Vector2.RIGHT
	var speed := 440.0 * float(p._tfx.get("proj_speed", 1.0))
	var base: Projectile = p._proj(dir, 1.0, "mage_firebolt", speed)
	p._finish_mage_bolt(base, 1.0)
	var focus: Node2D = p._spawn_crystal_cast_focus(dir, 0.0)
	var focus_center := focus.global_position
	var crystal_bolt: Projectile = p._cast_crystal_focus_bolt(focus, dir, 1.0)
	var physics_match := base.global_position.is_equal_approx(crystal_bolt.global_position) \
		and base.vel.is_equal_approx(crystal_bolt.vel) \
		and is_equal_approx(base.life, crystal_bolt.life) \
		and base.collision_mask == crystal_bolt.collision_mask \
		and base.pierce == crystal_bolt.pierce \
		and base.homing == crystal_bolt.homing \
		and is_equal_approx(base.hit_player_mult, crystal_bolt.hit_player_mult) \
		and base.fx == crystal_bolt.fx
	var visual_match := crystal_bolt._fx_pos().distance_to(focus_center) < 0.05
	if not physics_match or not visual_match:
		print("QA FAIL: Crystal Firebolt changed base physics or missed Court focus")
		fails += 1
	else:
		print("qa ok: mage/crystal_archmage cosmetic projectile parity")
	base.queue_free()
	crystal_bolt.queue_free()
	await _frames(2)
	var survivors := get_tree().get_nodes_in_group("crystal_archmage_cast_focus").size()
	if survivors > 0:
		print("QA FAIL: Crystal Firebolt left a Court focus behind")
		fails += 1
	else:
		print("qa ok: mage/crystal_archmage focus handoff cleanup")


func _assert_mage_ult_circle(p: Player) -> void:
	# The meteor collider queries a 150px radius. Its procedural telegraph is a
	# 64px circle (32px source radius), so a 150/32 uniform scale is exact.
	var radius := 150.0
	var mark: Sprite2D = p._mage_ult_mark(p.global_position, Color(0.6, 0.3, 1.0), radius)
	await get_tree().create_timer(0.64).timeout
	var expected := radius / 32.0
	if not is_equal_approx(mark.scale.x, expected) or not is_equal_approx(mark.scale.y, expected):
		print("QA FAIL: Mage ult telegraph does not match its circular hit radius")
		fails += 1
	else:
		print("qa ok: mage ult visual/hitbox circle parity")
	mark.queue_free()


func _assert_archer_cosmetic_parity(p: Player, dummy: Enemy) -> void:
	var saved_skin := p.skin
	var dir := Vector2.RIGHT
	var shots: Array[Projectile] = []
	for skin_id in ["", "frostfall_ranger", "voidwraith"]:
		p.skin = skin_id
		var shot: Projectile = p._proj(dir, 1.0, p._skin_arrow_tex(), 520.0)
		p._skin_arrow(shot)
		shots.append(shot)
	var base: Projectile = shots[0]
	var projectile_match := true
	for shot_index in range(1, shots.size()):
		var shot: Projectile = shots[shot_index]
		projectile_match = projectile_match \
			and base.global_position.is_equal_approx(shot.global_position) \
			and base.vel.is_equal_approx(shot.vel) \
			and is_equal_approx(base.life, shot.life) \
			and base.collision_mask == shot.collision_mask \
			and base.pierce == shot.pierce \
			and base.homing == shot.homing \
			and is_equal_approx(base.hit_player_mult, shot.hit_player_mult) \
			and base.fx == shot.fx
	if not projectile_match:
		print("QA FAIL: Archer skin arrow changed base projectile physics")
		fails += 1
	else:
		print("qa ok: archer skin projectile parity")
	for shot_node in shots:
		(shot_node as Projectile).queue_free()

	# Voidwraith's portal can outlive the movement, but the real relocation must
	# occur on the same synchronous frame and cover the same 130px base distance.
	p.skin = "voidwraith"
	p.refresh_skin_sprite()
	var origin := p.global_position
	var dvec: Vector2 = p.dash_vec()
	var expected_end: Vector2 = p.game.clamp_to_zone(origin + dvec * 130.0, origin)
	p._tumble()
	if not p.global_position.is_equal_approx(expected_end):
		print("QA FAIL: Voidwraith Tumble changed base relocation timing or distance")
		fails += 1
	else:
		print("qa ok: archer skin Tumble timing/distance parity")
	await get_tree().create_timer(0.25).timeout

	# Remove unrelated room enemies so focus selection has one deterministic
	# victim. Damage must land inside this call, not on a later tentacle frame.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != dummy and is_instance_valid(node):
			node.queue_free()
	await _frames(2)
	dummy.global_position = p.global_position + Vector2.RIGHT * 120.0
	dummy.hp = dummy.max_hp
	p.facing = Vector2.RIGHT
	p.storm_fx = {"focus": 1}
	var before := dummy.hp
	p._storm_strike()
	if not dummy.hp < before:
		print("QA FAIL: Voidwraith storm delayed or lost the base damage tick")
		fails += 1
	else:
		print("qa ok: archer skin storm targeting/hit-timing parity")
	p.skin = saved_skin
	p.refresh_skin_sprite()


func _assert_assassin_execution_timing(p: Player, dummy: Enemy) -> void:
	# All three executions must have delivered both shadow cuts and the final
	# stab by the shared ~0.32s frame. Crit is disabled so losses are comparable.
	var saved_skin := p.skin
	var saved_crit := p.crit
	var saved_tfx: Dictionary = p._tfx
	var origin := p.global_position
	p.crit = 0.0
	p._tfx = {}
	var losses: Array[float] = []
	for skin_id in ["", "phantom", "blade_dancer"]:
		p.skin = skin_id
		p.refresh_skin_sprite()
		p.global_position = origin
		dummy.global_position = origin + Vector2.RIGHT * 90.0
		dummy.hp = dummy.max_hp
		var before := dummy.hp
		p._death_mark_execution(dummy, 0.0)
		await get_tree().create_timer(0.37).timeout
		losses.append(before - dummy.hp)
		await get_tree().create_timer(0.10).timeout
	var timing_match := losses[0] > 0.0 \
		and is_equal_approx(losses[0], losses[1]) \
		and is_equal_approx(losses[0], losses[2])
	if not timing_match:
		print("QA FAIL: Assassin skin changed execution damage or final-hit timing: ", losses)
		fails += 1
	else:
		print("qa ok: assassin skin execution damage/timing parity")
	p.skin = saved_skin
	p.crit = saved_crit
	p._tfx = saved_tfx
	p.refresh_skin_sprite()
