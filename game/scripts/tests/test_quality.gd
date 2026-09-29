extends RefCounted


static func run(t: Node) -> String:
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


static func _ground_contracts(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	for safe in [false, true]:
		if safe:
			g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.22, 0)
		else:
			g.telegraph(p.global_position, 80, 0.22, 0)
		var attack: Node2D = g._ground_attacks.back()
		var clock: Node2D = attack.get_node("GroundTellClock")
		await t.get_tree().create_timer(0.06).timeout
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
		g.cancel_ground_attacks()
		await t.get_tree().process_frame
	# Cancel both attacks before their callbacks, including a falling sprite and
	# safe shelter. The stale callbacks must not apply their root to the hero.
	g.telegraph(p.global_position, 90, 0.15, 0, {"root": 2.0, "fireball": true})
	g.telegraph_safe([p.global_position + Vector2(400, 0)], 60, 0.15, 0, {"root": 2.0})
	g.cancel_ground_attacks()
	await t.get_tree().create_timer(0.25).timeout
	if p.rooted_time > 0.0 or not g._ground_attacks.is_empty():
		return "cancelled ground attack retained its visual or applied a status"
	if g.hud.danger_rect.modulate.a > 0.001:
		return "cancelled shelter left a danger wash behind"
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
	g.clear_damage_numbers()
	g.queue_free()
	await t.get_tree().process_frame
	if error == "":
		print("DAMAGE NUMBERS PASS: rapid totals, DoT cadence, rows clear the font, compaction, ally rows, cap, expiry, detach/room cleanup")
	return error


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
	var error := _live_damage_contracts(g, e)
	g.clear_damage_numbers(id)
	e.queue_free()
	await t.get_tree().process_frame
	if error == "":
		print("ok: live wolf hits, DoT ticks and the killing blow share one damage column")
	return error


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
