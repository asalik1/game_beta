extends "res://scripts/tests/guest_blink_enet_live.gd"
## Paired factory/spawn/state transport from the existing network rig.
const EXPECTED_BASELINE := ["full.mirror_fill", "full.mirror_cap",
	"repeat_full.mirror_fill", "repeat_full.mirror_cap"]
var healer: Enemy
var healer_mirror: Enemy
var death_capture := false


func run() -> int:
	shot_dir = shot_dir.path_join("healing")
	return await super.run()


func _episode() -> String:
	report["mode"] = "healing"
	report["baseline"] = flag("baseline")
	report["findings"] = []
	report["fixture"] = "Inherited paired ENet boot/admission, factory wolf and mirror, production state/death stream. Frozen actors; controlled host take_damage creates an initial 29% wound. A real Choir Cantor's production _heal_pulse heals through partial to full, without assigning target HP. Support timing is invoked directly, not autonomous AI or native combat input. Shared-tree groups isolate host recipient from guest mirrors. Death is a controlled lethal host hit; reward/balance/persistence/device behavior is not an acceptance claim."
	var error: String = await super._episode()
	var actual: Array = report.findings.duplicate()
	actual.sort()
	var expected: Array = EXPECTED_BASELINE.duplicate() if flag("baseline") else []
	expected.sort()
	_check(actual == expected, "healing: exact baseline findings " + str(actual))
	return error


func _expect(ok: bool, id: String) -> void:
	if not ok and flag("baseline") and EXPECTED_BASELINE.has(id):
		report.checks += 1
		report.findings.append(id)
		print("HEALING BASELINE: " + id)
	else:
		_check(ok, "healing: " + id)


func _bar(e: Enemy) -> Dictionary:
	return {"hp": e.hp, "max_hp": e.max_hp, "fraction": e.hp / e.max_hp,
		"fill": e.hp_bar_fg.size.x, "cap_x": e.hp_bar_cap.position.x,
		"bg_visible": e.hp_bar_bg.visible, "fg_visible": e.hp_bar_fg.visible,
		"cap_visible": e.hp_bar_cap.visible, "dying": e.dying,
		"position": _v(e.global_position), "net_id": e.net_id}


func _visible(row: Dictionary) -> bool:
	return row.bg_visible and row.fg_visible and row.cap_visible


func _hidden(row: Dictionary) -> bool:
	return not row.bg_visible and not row.fg_visible and not row.cap_visible


func _observe(id: String, visible: bool) -> bool:
	var wire_fraction := float(int(clampf(actor.hp / actor.max_hp, 0.0, 1.0) * 255.0)) / 255.0
	var converged := await _until(func() -> bool:
		return absf(mirror.hp / mirror.max_hp - wire_fraction) < 0.00001, 3.0)
	_check(converged, "healing: " + id + " exact quantized host state converged")
	var host := _bar(actor)
	var guest := _bar(mirror)
	report.cases.append({"id": id, "host": host, "mirror": guest, "wire_fraction": wire_fraction})
	for pair in [["host", host], ["mirror", guest]]:
		var role: String = pair[0]
		var row: Dictionary = pair[1]
		_check(_visible(row) if visible else _hidden(row), "healing: " + id + "." + role + " visibility")
		if visible:
			var width: float = Enemy.HP_BAR_W * float(row.fraction)
			_expect(is_equal_approx(float(row.fill), width), id + "." + role + "_fill")
			_expect(is_equal_approx(float(row.cap_x), -Enemy.HP_BAR_W * 0.5 + width - 1.0), id + "." + role + "_cap")
	return converged


func _case(occupied: bool) -> String:
	# Inherit the common episode's two-case dispatch without duplicating boot.
	if not occupied:
		return ""
	step("ordinary support healing through full health")
	var host: Game = readers[0]
	var guest: Game = readers[1]
	for reader in readers:
		reader.settings["hit_stop"] = false
		reader.player.global_position = actor_point - Vector2(120, 0)
		reader.player.velocity = Vector2.ZERO
		reader.player.clear_local_intents()
	# Separate real party bodies so remote nameplates do not cover the local hero.
	host.player.global_position += Vector2(0, 120)
	host.player.locked_target = actor
	guest.player.locked_target = mirror
	healer = Enemy.make(host, "stormcult", actor_point + Vector2(95, 0), 8, 1.0)
	healer.zone_idx = actor.zone_idx
	host.add_enemy(healer)
	healer.set_physics_process(false)
	if not await _until(func() -> bool:
		return is_instance_valid(wires[1].net_enemies.get(healer.net_id)), 3.0):
		return "Choir Cantor did not replicate"
	healer_mirror = wires[1].net_enemies[healer.net_id]
	# _heal_pulse iterates a SceneTree group; only authoritative recipient is in
	# that group, so the guest bar must be reached through the state stream.
	for e in [mirror, healer, healer_mirror]:
		e.remove_from_group("enemies")
		excluded_groups.append(e)
	actor.add_to_group("enemies")
	_check(healer.kind == "stormcult" and healer.traits.has("channel_heal")
		and healer.zone_idx == actor.zone_idx
		and healer.global_position.distance_to(actor.global_position) < Balance.MOB_HEAL_RADIUS,
		"healing: real nearby same-zone Choir Cantor with shipped support trait")
	_check(get_tree().get_nodes_in_group("enemies") == [actor], "healing: sole recipient is authoritative host actor")
	if not await _observe("pristine", false): return "pristine state timeout"
	_show(1)
	await _capture("healing_pristine_guest")
	actor.hit_src = host.player
	actor.take_damage(actor.max_hp * 0.29, Vector2.ZERO, false, true)
	_check(is_equal_approx(actor.hp / actor.max_hp, 0.71) and actor.received.size() == 1,
		"healing: controlled initial wound through actual host take_damage")
	if not await _observe("wounded", true): return "wound state timeout"
	for pulse in 3:
		var before := actor.hp
		healer._heal_pulse()
		var expected := minf(actor.max_hp, before + actor.max_hp * Balance.MOB_HEAL_FRAC)
		_check(is_equal_approx(actor.hp, expected) and actor.hp > before,
			"healing: production pulse %d exact positive heal" % (pulse + 1))
		var label := "full" if pulse == 2 else "partial_%d" % (pulse + 1)
		if not await _observe(label, true): return label + " state timeout"
		if pulse == 0:
			_show(1)
			await _capture("healing_partial_guest")
	_check(is_equal_approx(actor.hp, actor.max_hp) and is_equal_approx(mirror.hp, mirror.max_hp),
		"healing: real support reached exact full HP on both readers")
	for index in 2:
		_show(index)
		await _capture("healing_full_" + ("host" if index == 0 else "guest"))
	healer._heal_pulse()
	await _settle(0.4)
	if not await _observe("repeat_full", true): return "repeated full state timeout"
	_check(actor.received.size() == 1, "healing: all healing phases contain only the initial damage contact")
	_show(1)
	await _capture("healing_repeated_full_guest")
	actor.hit_src = host.player
	actor.take_damage(actor.max_hp * 0.20, Vector2.ZERO, false, true)
	_check(is_equal_approx(actor.hp / actor.max_hp, 0.80) and actor.received.size() == 2,
		"healing: later real wound after full healing")
	if not await _observe("wounded_again", true): return "later wound state timeout"
	await _capture("healing_wounded_again_guest")
	actor.hit_src = host.player
	actor.take_damage(actor.hp + 1.0, Vector2.ZERO, false, true)
	var dead_host := _bar(actor)
	_check(dead_host.dying and _hidden(dead_host), "healing: host death hides background/fill/cap")
	if not await _until(func() -> bool: return is_instance_valid(mirror) and mirror.dying, 2.0):
		return "death event did not reach still-live mirror node"
	var dead_guest := _bar(mirror)
	_check(_hidden(dead_guest), "healing: mirror death hides background/fill/cap")
	report.cases.append({"id": "death", "host": dead_host, "mirror": dead_guest})
	# Explicit stale-packet presenter control, separate from real death RPC.
	# Production state may still arrive after death; it must not reshow the bar.
	mirror.net_apply_state(mirror.net_target, false, false, 1.0)
	var after_late_state := _bar(mirror)
	_check(after_late_state.dying and _hidden(after_late_state), "healing: controlled late full state cannot resurrect death bar")
	report.cases.append({"id": "controlled_late_full_state_after_death", "mirror": after_late_state})
	death_capture = true
	await _capture("healing_death_guest")
	return ""


func _capture_bounds() -> Dictionary:
	# Parent assumes guest-only images; this helper also captures the host.
	var sprites: Array = [game.player.sprite]
	if not death_capture:
		var subject: Enemy = actor if game == readers[0] else mirror
		var support: Enemy = healer if game == readers[0] else healer_mirror
		if is_instance_valid(subject): sprites.append(subject.sprite)
		if is_instance_valid(support): sprites.append(support.sprite)
	var rows: Array = []
	var complete := true
	var screen: Rect2 = game.get_viewport().get_visible_rect()
	for sprite in sprites:
		var rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		var hits := _hud_visual_hits(rect)
		var visible: bool = sprite.is_visible_in_tree() and _canvas_alpha(sprite) >= 0.05
		complete = complete and visible and rect.has_area() and screen.grow(0.75).encloses(rect) and hits.is_empty()
		rows.append({"path": str(sprite.get_path()), "rect": str(rect), "visible": visible, "hud_hits": hits})
	return {"complete": complete, "subjects": rows, "death_actor_may_have_faded": death_capture,
		"role": "host" if game == readers[0] else "guest", "camera_override": false}


func shot(label: String, _extra: String = "") -> String:
	return super.shot(label, "controlled wounds/death and direct-timed real Choir Cantor healing over ENet; no ordinary AI/device claim")
